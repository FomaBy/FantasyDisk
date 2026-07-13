#!/usr/bin/env python3
"""Guard the authoritative Multica cutover in active agent documentation."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ACTIVE_POLICY_FILES = (
    "AGENTS.md",
    "README.md",
    ".claude/skills/fantasydisk-onboarding/SKILL.md",
    "docs/process/ai_agent_memorandum.md",
    "docs/process/agent_role_boundaries_and_handoffs.md",
    "docs/process/multica_workflow.md",
    "docs/process/pm_workflow.md",
    "docs/process/qa_protocol.md",
    "docs/process/release_versioning.md",
    "docs/process/task_routing_guide.md",
    "docs/process/versioning_and_branching.md",
    "scripts/onboard.sh",
    "skills/codex/perenos-chata/SKILL.md",
    "skills/scheduled-tasks/fantasydisk-backend-developer/SKILL.md",
)

BANNED_LIVE_JIRA_PHRASES = (
    "tools/jira_next_task.py --role",
    "Jira-first",
    "Use Jira as the only source",
    "Источник задач — JIRA",
    "Источник правды — Jira",
    "Jira is mandatory and authoritative",
    "Jira является единым authoritative",
    "сначала Jira issue",
)


class MulticaTaskPolicyTest(unittest.TestCase):
    def test_active_policy_is_multica_first(self) -> None:
        for relative in ACTIVE_POLICY_FILES:
            content = (ROOT / relative).read_text(encoding="utf-8")
            with self.subTest(path=relative):
                self.assertIn("Multica", content)
                for phrase in BANNED_LIVE_JIRA_PHRASES:
                    self.assertNotIn(phrase, content)

    def test_canonical_ids_and_lifecycle_are_pinned(self) -> None:
        workflow = (ROOT / "docs/process/multica_workflow.md").read_text(
            encoding="utf-8"
        )
        self.assertIn("2ac963eb-b644-4540-8042-a1a4508f1a65", workflow)
        self.assertIn("4eccbced-60b5-4e7a-87fd-d9f3699d3bed", workflow)
        self.assertIn("e2e1c89f-587d-4a2d-bbaa-ce9b5dea908d", workflow)
        for status in ("todo", "in_progress", "in_review", "done"):
            self.assertIn(f"`{status}`", workflow)

    def test_legacy_jira_doc_cannot_look_current(self) -> None:
        opening = "\n".join(
            (ROOT / "docs/process/jira_sync.md")
            .read_text(encoding="utf-8")
            .splitlines()[:14]
        )
        self.assertIn("superseded", opening.lower())
        self.assertIn("2026-07-13", opening)
        self.assertIn("multica_workflow.md", opening)


if __name__ == "__main__":
    unittest.main()
