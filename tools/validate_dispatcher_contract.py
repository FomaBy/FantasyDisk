#!/usr/bin/env python3
"""Validate FantasyDisk's active dispatcher surfaces against one authority."""

from __future__ import annotations

import re
import sys
from pathlib import Path


CANONICAL_AUTHORITY_ID = "dispatcher-authority:v1:4874c472-e690-4801-ab62-2608175d5251"
CANONICAL_AUTHORITY_REVISION = "2026-08-25T08:48:36Z"
AUTHORITY_DOC = Path("docs/process/dispatcher-authority.md")

AUTHORITY_LINK_SURFACES = (
    "AGENTS.md",
    "docs/process/agent_role_boundaries_and_handoffs.md",
    "docs/process/ai_agent_memorandum.md",
    "docs/process/context_engineering.md",
    "docs/process/multica_workflow.md",
    "docs/process/pm_workflow.md",
    "docs/process/qa_protocol.md",
    "docs/process/task_routing_guide.md",
    "skills/codex/fantasydisk-agent-dispatcher/SKILL.md",
    "skills/codex/fantasydisk-agent-dispatcher/agents/openai.yaml",
    "skills/codex/fantasydisk-agent-dispatcher/references/qa-loop.md",
    "skills/scheduled-tasks/fantasydisk-backend-developer/SKILL.md",
    "tests/test_multica_cutover_onboarding.py",
    "tests/test_multica_task_policy.py",
)

HISTORICAL_DOCS = (
    "docs/process/jira_sync.md",
    "docs/process/task_board.md",
)
HISTORICAL_MARKERS = ("historical", "legacy", "read-only", "archive", "superseded")
_LEGACY_PROVIDER = "q" + "wen"
_LEGACY_DISPATCHER = "legacy " + "dispatcher"
FORBIDDEN_ACTIVE_MARKERS = (_LEGACY_PROVIDER, _LEGACY_DISPATCHER)


def _active_surface_paths(root: Path) -> tuple[Path, ...]:
    paths = {root / "AGENTS.md"} if (root / "AGENTS.md").is_file() else set()
    for directory in (".claude", "scripts", "skills/codex", "skills/scheduled-tasks"):
        directory_path = root / directory
        if directory_path.is_dir():
            paths.update(path for path in directory_path.rglob("*") if path.is_file())
    process_path = root / "docs/process"
    if process_path.is_dir():
        paths.update(process_path.glob("*.md"))
    tests_path = root / "tests"
    if tests_path.is_dir():
        paths.update(tests_path.glob("test_multica_*.py"))
    return tuple(sorted(paths))


def _authority_field(text: str, label: str) -> str | None:
    match = re.search(rf"^{re.escape(label)}:\s+`([^`]+)`$", text, re.MULTILINE)
    return match.group(1) if match else None


def validate(root: Path) -> list[str]:
    errors: list[str] = []
    authority_path = root / AUTHORITY_DOC
    if not authority_path.is_file():
        return [f"missing authority record: {AUTHORITY_DOC}"]

    authority_text = authority_path.read_text(encoding="utf-8")
    authority_id = _authority_field(authority_text, "Authority ID")
    authority_revision = _authority_field(authority_text, "Authority revision")
    if authority_id != CANONICAL_AUTHORITY_ID:
        errors.append(f"authority ID drift: {authority_id!r}")
    if authority_revision != CANONICAL_AUTHORITY_REVISION:
        errors.append(f"authority revision drift: {authority_revision!r}")

    for relative in AUTHORITY_LINK_SURFACES:
        path = root / relative
        if not path.is_file():
            errors.append(f"missing active dispatcher surface: {relative}")
            continue
        text = path.read_text(encoding="utf-8")
        if "dispatcher-authority.md" not in text:
            errors.append(f"{relative} does not link the canonical authority record")

    historical = {root / relative for relative in HISTORICAL_DOCS}
    for path in historical:
        if not path.is_file():
            errors.append(f"missing historical document: {path.relative_to(root)}")
            continue
        head = "\n".join(path.read_text(encoding="utf-8").splitlines()[:16]).casefold()
        if not any(marker in head for marker in HISTORICAL_MARKERS):
            errors.append(f"{path.relative_to(root)} is not marked historical")

    for path in _active_surface_paths(root):
        if path in historical or path == authority_path:
            continue
        text = path.read_text(encoding="utf-8").casefold()
        for marker in FORBIDDEN_ACTIVE_MARKERS:
            if marker in text:
                errors.append(f"runnable legacy marker {marker!r} in {path.relative_to(root)}")

    return errors


def main(argv: list[str]) -> int:
    root = Path(argv[1]).resolve() if len(argv) > 1 else Path(__file__).resolve().parents[1]
    errors = validate(root)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print(f"canonical authority: {CANONICAL_AUTHORITY_ID}@{CANONICAL_AUTHORITY_REVISION}")
    print("dispatcher contract: valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
