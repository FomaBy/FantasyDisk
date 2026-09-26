#!/usr/bin/env python3
"""Reject release-notes claims of per-item visual work (own storyboard/effects)
that carry no reference to a passed live-QA card (FAN-XXXX + QA).

FAN-2993: 0.3.0 shipped "each weapon's ultimate has its own storyboard and
effects" while 18/51 ultimate scenes had no drawing nodes and a shared tick
handler flattened every ultimate to three shapes. The claim was never checked
against a live QA pass. This gate fails closed on the same pattern next time.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from release_version_contract import is_valid_release_version

CHANGELOG_PATH = TOOLS_DIR.parent / "CHANGELOG.md"

# A claim that an item has its *own/unique/individual* storyboard, VFX,
# particles, or visual effects is the exact shape of the false 0.3.0 claim.
# Bare "эффект" is excluded — it's routinely used for gameplay status effects
# ("завершают свои эффекты" = cleanup, not visuals) and would false-positive.
# Only "визуальные эффекты" counts as the visual-effects claim.
POSSESSIVE = r"(?:сво[а-я]*|собственн[а-я]*|уникальн[а-я]*|индивидуальн[а-я]*)"
CLAIM_RE = re.compile(
    rf"{POSSESSIVE}\s+\S*\s*(?:раскадров[а-я]*|vfx|партикл[а-я]*|particle[a-z]*)"
    rf"|{POSSESSIVE}\s+визуальн[а-я]*\s+эффект[а-я]*",
    re.IGNORECASE,
)
QA_REF_RE = re.compile(r"FAN-\d+.{0,120}?QA|QA.{0,120}?FAN-\d+", re.IGNORECASE | re.DOTALL)

# "Known limitations" is where the project honestly names unfinished visuals
# (see FAN-2993's own Известные ограничения entry) — that is disclosure, not
# the affirmative claim this gate polices.
EXEMPT_SUBSECTION = "известные ограничения"


def _version_section(changelog_text: str, version: str) -> str:
    heading_re = re.compile(rf"^## \[{re.escape(version)}\][^\n]*$", re.MULTILINE)
    match = heading_re.search(changelog_text)
    if match is None:
        return ""
    start = match.end()
    next_heading = re.search(r"^## \[", changelog_text[start:], re.MULTILINE)
    end = start + next_heading.start() if next_heading else len(changelog_text)
    return changelog_text[start:end]


def _bullets_outside_exempt_subsections(section_text: str) -> list[str]:
    exempt = False
    bullets: list[str] = []
    current: list[str] = []

    def flush() -> None:
        if current and not exempt:
            bullets.append(" ".join(current))
        current.clear()

    for line in section_text.splitlines():
        heading = re.match(r"^### (.+)$", line.strip())
        if heading:
            flush()
            exempt = heading.group(1).strip().lower() == EXEMPT_SUBSECTION
            continue
        if line.startswith("- "):
            flush()
            current.append(line[2:].strip())
        elif current and line.startswith("  "):
            current.append(line.strip())
        else:
            flush()
    flush()
    return bullets


def unbacked_visual_claims(changelog_text: str, version: str) -> list[str]:
    section = _version_section(changelog_text, version)
    return [
        bullet
        for bullet in _bullets_outside_exempt_subsections(section)
        if CLAIM_RE.search(bullet) and not QA_REF_RE.search(bullet)
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--changelog", type=Path, default=CHANGELOG_PATH)
    args = parser.parse_args()
    if not is_valid_release_version(args.version):
        parser.error("--version must be a canonical release version")

    changelog_text = args.changelog.read_text(encoding="utf-8")
    violations = unbacked_visual_claims(changelog_text, args.version)
    if violations:
        print(
            f"ERROR: {args.changelog} claims per-item visual work for "
            f"{args.version} without a passed live-QA card reference (FAN-XXXX + QA):"
        )
        for bullet in violations:
            print(f"    {bullet}")
        return 2

    print(f"OK: {args.version} release notes carry no unbacked visual claims")
    return 0


if __name__ == "__main__":
    sys.exit(main())
