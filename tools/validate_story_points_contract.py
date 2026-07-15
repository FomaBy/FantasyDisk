#!/usr/bin/env python3
"""Reject incompatible CUE rubrics in FantasyDisk process materials."""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CANONICAL_DOCUMENTS = (
    Path("docs/process/story_points.md"),
    Path("docs/process/multica_story_points_instruction.md"),
    Path("docs/process/pm_workflow.md"),
    Path("docs/process/multica_workflow.md"),
    Path("skills/codex/fantasydisk-agent-dispatcher/SKILL.md"),
)
REQUIRED_MARKERS = (
    "1, 2, 3, 5, 8, 13",
    "SP:<N>",
    "story_points",
    "estimation_model",
)
FORMULA_RE = re.compile(r"\bC\s*\+\s*U\s*\+\s*E\b")
PER_FACTOR_SCORE_RE = re.compile(
    r"(?:кажд\w*|each)\s+(?:фактор|factor).{0,100}?\b(?:от|from)\s*1\s*(?:до|to)\s*5\b",
    re.IGNORECASE | re.DOTALL,
)


def validate(path: Path) -> list[str]:
    try:
        source = path.read_text(encoding="utf-8")
    except OSError as exc:
        return [f"cannot read {path}: {exc}"]

    errors = [f"{path}: missing {marker!r}" for marker in REQUIRED_MARKERS if marker not in source]
    if not (
        "не складывается по формуле" in source
        or "does not sum by formula" in source
    ):
        errors.append(f"{path}: missing integral CUE/no-formula rule")
    if FORMULA_RE.search(source):
        errors.append(f"{path}: forbidden C + U + E conversion formula")
    if PER_FACTOR_SCORE_RE.search(source):
        errors.append(f"{path}: forbidden per-factor 1-to-5 CUE rubric")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--document",
        action="append",
        type=Path,
        help="validate one additional document instead of the canonical set",
    )
    args = parser.parse_args(argv)
    documents = args.document or [ROOT / path for path in CANONICAL_DOCUMENTS]
    errors = [error for document in documents for error in validate(document)]
    if errors:
        print("story-points contract failed:", file=sys.stderr)
        print("\n".join(f"- {error}" for error in errors), file=sys.stderr)
        return 1
    print(f"story-points contract passed: {len(documents)} document(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
