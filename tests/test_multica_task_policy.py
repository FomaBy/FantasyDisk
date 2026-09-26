#!/usr/bin/env python3
"""Guard the authoritative Multica cutover in active agent documentation."""

from __future__ import annotations

import unittest
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
CANONICAL_AUTHORITY_ID = "dispatcher-authority:v1:4874c472-e690-4801-ab62-2608175d5251"
CANONICAL_AUTHORITY_REVISION = "2026-08-25T08:48:36Z"
AUTHORITY_DOC = "docs/process/dispatcher-authority.md"
ACTIVE_POLICY_FILES = (
    "AGENTS.md",
    "README.md",
    ".claude/skills/fantasydisk-onboarding/SKILL.md",
    "docs/process/ai_agent_memorandum.md",
    "docs/process/agent_role_boundaries_and_handoffs.md",
    "docs/process/dispatcher-authority.md",
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
    "claim-first",
    "eligible unassigned",
    "multica-pull",
    "successfully claimed",
    "успешно claimed",
    "qa сам находит",
    "qa выбирает",
    "каждый тикет несет лейбл",
)


class MulticaTaskPolicyTest(unittest.TestCase):
    def test_dispatcher_contract_matches_canonical_authority_and_fails_closed(self) -> None:
        validator = ROOT / "tools/validate_dispatcher_contract.py"
        result = subprocess.run(
            [sys.executable, str(validator), str(ROOT)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn(CANONICAL_AUTHORITY_ID, result.stdout)
        self.assertIn(CANONICAL_AUTHORITY_REVISION, result.stdout)

        with tempfile.TemporaryDirectory(prefix="fantasydisk-dispatcher-contract-") as temp:
            copy = Path(temp) / "repo"
            shutil.copytree(
                ROOT,
                copy,
                ignore=shutil.ignore_patterns(".git", ".godot", "build", "__pycache__"),
            )
            authority = copy / "docs/process/dispatcher-authority.md"
            authority_text = authority.read_text(encoding="utf-8")
            authority.write_text(
                authority_text.replace(
                    CANONICAL_AUTHORITY_REVISION, "2099-01-01T00:00:00Z"
                ),
                encoding="utf-8",
            )
            drift = subprocess.run(
                [sys.executable, str(copy / "tools/validate_dispatcher_contract.py"), str(copy)],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertNotEqual(0, drift.returncode)
            self.assertIn("authority revision drift", drift.stderr)

            authority.write_text(authority_text, encoding="utf-8")
            conflict = copy / "skills/codex/fantasydisk-agent-dispatcher/references/conflicting-rule.md"
            conflict.write_text(
                "A q" + "wen-only runnable rule must be rejected.\n",
                encoding="utf-8",
            )
            rejected = subprocess.run(
                [sys.executable, str(copy / "tools/validate_dispatcher_contract.py"), str(copy)],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertNotEqual(0, rejected.returncode)
            self.assertIn("runnable legacy marker", rejected.stderr)

    def test_active_policy_is_multica_first(self) -> None:
        for relative in ACTIVE_POLICY_FILES:
            content = (ROOT / relative).read_text(encoding="utf-8")
            with self.subTest(path=relative):
                self.assertIn("Multica", content)
                for phrase in BANNED_LIVE_JIRA_PHRASES:
                    self.assertNotIn(phrase, content)

    def test_canonical_project_and_lifecycle_are_pinned(self) -> None:
        workflow = (ROOT / "docs/process/multica_workflow.md").read_text(
            encoding="utf-8"
        )
        self.assertIn("2ac963eb-b644-4540-8042-a1a4508f1a65", workflow)
        self.assertIn("canonical dispatcher", workflow.casefold())
        self.assertIn(AUTHORITY_DOC, workflow)
        self.assertIn("dispatch_ready", workflow)
        self.assertIn("unassigned", workflow)
        for status in (
            "backlog",
            "todo",
            "in_progress",
            "in_review",
            "blocked",
            "done",
        ):
            self.assertIn(f"`{status}`", workflow)
        self.assertIn("waiting_on", workflow)
        self.assertIn("Blockers and recovery", workflow)
        self.assertNotIn("qa_claim_mode=autonomous_unassigned", workflow)

        memo = (ROOT / "docs/process/ai_agent_memorandum.md").read_text(
            encoding="utf-8"
        )
        self.assertIn("Direct user-control work", memo)
        self.assertIn("manual-ownership", memo)

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
