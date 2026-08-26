#!/usr/bin/env python3
"""Fail closed on a dangling skill/agent reference in an active routing surface.

An active surface (onboarding, `AGENTS.md`, skill routing docs) that names a
skill/agent in backticks (e.g. `` `fantasydisk-animation-director` ``) must
name one that actually exists under `.claude/skills/`, `skills/codex/` or
`skills/scheduled-tasks/`. A renamed or retired skill silently orphans that
reference and misroutes the next agent that reads it (FAN-3450).

Historical/evidence documents (CHANGELOG, docs/tasks/*, docs/design mirrors)
are allowed to keep dead names as record of what happened; they are exempted
via ``HISTORICAL_ALLOWLIST`` instead of being scanned at all.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Surfaces a fresh agent actually reads to pick a skill/agent to route to.
ACTIVE_SURFACES = [
    "AGENTS.md",
    "README.md",
    *sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / ".claude/skills").glob("*/SKILL.md")),
    *sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / "skills/codex").glob("*/SKILL.md")),
    *sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / "skills/scheduled-tasks").glob("*/SKILL.md")),
    *sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / "docs/process").glob("*.md")),
]

# Historical/evidence documents: dead skill names there are record, not routing.
# `jira_sync.md` / `task_board.md` are the legacy-banner docs from the Jira ->
# Multica cutover (see tests/test_multica_cutover_onboarding.py): both are
# closed-task logs and archive helper notes, not live skill routing.
HISTORICAL_ALLOWLIST = [
    "CHANGELOG.md",
    "docs/process/jira_sync.md",
    "docs/process/task_board.md",
]
HISTORICAL_GLOBS = [
    "docs/tasks/**/*.md",
    "docs/design/**/*.md",
]

# Backtick token that looks like a skill/agent slug: lowercase words joined by
# hyphens, at least one hyphen (excludes plain code identifiers like `AGENTS.md`).
SKILL_TOKEN_RE = re.compile(r"`([a-z][a-z0-9]*(?:-[a-z0-9]+)+)`")

# Non-skill slugs that legitimately match the token shape (script/file names).
NOT_A_SKILL = {
    "multica-workspace-governance",
    "ponytail",
    "receiving-code-review",
    "systematic-debugging",
    "test-driven-development",
    "using-git-worktrees",
    "verification-before-completion",
    "context-efficient-agent-workflow",
    "godot-gdscript",
    "dev-runtime-health",
}


def known_skill_names() -> set[str]:
    names = set()
    for skill_md in (
        list((ROOT / ".claude/skills").glob("*/SKILL.md"))
        + list((ROOT / "skills/codex").glob("*/SKILL.md"))
        + list((ROOT / "skills/scheduled-tasks").glob("*/SKILL.md"))
    ):
        for line in skill_md.read_text(encoding="utf-8").splitlines():
            if line.startswith("name:"):
                names.add(line.split(":", 1)[1].strip())
                break
    return names


def is_historical(rel_path: str) -> bool:
    if rel_path in HISTORICAL_ALLOWLIST:
        return True
    for pattern in HISTORICAL_GLOBS:
        if Path(rel_path).as_posix() in {
            p.relative_to(ROOT).as_posix() for p in ROOT.glob(pattern)
        }:
            return True
    return False


def find_dangling_references(surfaces=None, known_names=None):
    """Return a list of (path, line_no, token) for dangling skill references."""
    surfaces = ACTIVE_SURFACES if surfaces is None else surfaces
    known_names = known_skill_names() if known_names is None else known_names
    dangling = []
    for rel in surfaces:
        path = ROOT / rel
        if not path.is_file() or is_historical(rel):
            continue
        for line_no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            for token in SKILL_TOKEN_RE.findall(line):
                if token in NOT_A_SKILL or not token.startswith(
                    ("fantasydisk-", "add-character", "jira-", "perenos-chata")
                ):
                    continue
                if token not in known_names:
                    dangling.append((rel, line_no, token))
    return dangling


def main() -> int:
    dangling = find_dangling_references()
    if dangling:
        print("Dangling skill/agent references found:")
        for rel, line_no, token in dangling:
            print(f"  {rel}:{line_no}: `{token}` does not match any installed skill")
        return 1
    print("No dangling skill/agent references in active surfaces.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
