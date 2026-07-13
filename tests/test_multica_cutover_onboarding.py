"""Regression guard for the FantasyDisk Jira -> Multica cutover (FAN-1044).

After the 2026-07-13 cutover, Multica (project FantasyDisk, FAN-* issues, driven
via the ``multica`` CLI) is the single authoritative task/status/owner source. A
new agent -- Codex or Claude -- landing on any active onboarding or worker surface
must be pointed at Multica and must NOT be handed a mechanism or directive that
drives Jira as the live tracker.

This test fails closed: if someone re-introduces a Jira claim/sync helper or an
"authoritative Jira" directive into an active surface, or drops the Multica
authority signal, the quality gate goes red. Legacy Jira remains a read-only
historical archive; historical evidence and provenance IDs are intentionally
preserved and are NOT flagged here.
"""

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

# Surfaces a fresh agent actually reads to learn "where does work live and how do
# I take/close it". Every one of these must be Multica-authoritative and free of
# active Jira-directing mechanisms. Codex and Claude surfaces are both covered.
ACTIVE_SURFACES = [
    "AGENTS.md",
    "README.md",
    "scripts/onboard.sh",
    ".claude/skills/fantasydisk-onboarding/SKILL.md",
    ".claude/skills/add-character/SKILL.md",
    "skills/scheduled-tasks/fantasydisk-backend-developer/SKILL.md",
    "skills/codex/fantasydisk-agent-dispatcher/SKILL.md",
    "skills/codex/fantasydisk-agent-dispatcher/references/backend-loop.md",
    "skills/codex/fantasydisk-agent-dispatcher/references/qa-loop.md",
    "skills/codex/fantasydisk-agent-dispatcher/references/design-loop.md",
    "skills/codex/fantasydisk-agent-dispatcher/references/animator-loop.md",
    "skills/codex/fantasydisk-agent-dispatcher/references/dispatcher-heartbeat.md",
    "docs/process/ai_agent_memorandum.md",
]

# Legacy Jira helper scripts / mechanisms. An active surface that invokes any of
# these is directing an agent into Jira -- forbidden after cutover. (Bare
# "jira_sync" is intentionally excluded so an active surface may still *name*
# jira_sync.md / jira_sync_map.json when explicitly labelling them archive-only.)
FORBIDDEN_HELPERS = [
    "jira_next_task",
    "jira_board_sync",
    "jira_qa_next",
    "jira_qa_helper",
    "jira_release_stuck",
]

# Positive "Jira is the live tracker" directives the cutover removed. These only
# ever appear as active instructions, never as historical/legacy framing.
FORBIDDEN_DIRECTIVES = [
    "jira-first",
    "jira-pull",
    "берутся из jira",
    "берётся из jira",
    "jira является единым",
    "jira является authoritative",
    "claim в jira",
]

# The canonical Multica target recorded at cutover.
CANONICAL_PROJECT_ID = "2ac963eb-b644-4540-8042-a1a4508f1a65"
CUTOVER_DOC = "docs/process/jira_to_multica_cutover.md"

# Docs that stay in the repo as historical Jira reference. They must carry an
# unmistakable legacy/archive banner near the top so their preserved bodies are
# never mistaken for live instructions.
LEGACY_BANNER_DOCS = [
    "docs/process/jira_sync.md",
    "docs/process/task_board.md",
]
LEGACY_MARKERS = ("legacy", "read-only", "archive", "archive-only", "superseded")


def read(rel_path):
    return (ROOT / rel_path).read_text(encoding="utf-8")


class CutoverOnboardingTest(unittest.TestCase):
    def test_cutover_record_exists_and_pins_canonical_facts(self):
        """The cutover record must fix date, approver, and canonical project."""
        path = ROOT / CUTOVER_DOC
        self.assertTrue(path.is_file(), f"missing cutover record: {CUTOVER_DOC}")
        text = path.read_text(encoding="utf-8")
        for needle in ("2026-07-13", "Sergey Fomin", CANONICAL_PROJECT_ID, "FantasyDisk", "FAN-"):
            self.assertIn(needle, text, f"cutover record missing {needle!r}")

    def test_active_surfaces_exist(self):
        for rel in ACTIVE_SURFACES:
            self.assertTrue((ROOT / rel).is_file(), f"active surface missing: {rel}")

    def test_no_active_surface_invokes_a_jira_helper(self):
        """No onboarding/worker surface may hand an agent a Jira claim/sync tool."""
        for rel in ACTIVE_SURFACES:
            lowered = read(rel).lower()
            for helper in FORBIDDEN_HELPERS:
                self.assertNotIn(
                    helper,
                    lowered,
                    f"{rel} still invokes legacy Jira helper {helper!r}; "
                    f"use the `multica` CLI instead",
                )

    def test_no_active_surface_directs_into_jira(self):
        """No active surface may assert Jira as the live/authoritative tracker."""
        for rel in ACTIVE_SURFACES:
            lowered = read(rel).lower()
            for phrase in FORBIDDEN_DIRECTIVES:
                self.assertNotIn(
                    phrase,
                    lowered,
                    f"{rel} still directs agents into Jira via {phrase!r}",
                )

    def test_active_surfaces_name_multica_as_authoritative(self):
        """Every active surface must positively point at the Multica tracker."""
        signals = ("fan-", "multica issue", "`multica`", "multica cli", "проект `fantasydisk`")
        for rel in ACTIVE_SURFACES:
            lowered = read(rel).lower()
            self.assertIn("multica", lowered, f"{rel} never mentions Multica")
            self.assertTrue(
                any(sig in lowered for sig in signals),
                f"{rel} mentions Multica but gives no concrete tracker signal "
                f"(expected one of {signals})",
            )

    def test_legacy_docs_carry_archive_banner(self):
        """jira_sync.md / task_board.md must be fenced behind a legacy banner."""
        for rel in LEGACY_BANNER_DOCS:
            head = "\n".join(read(rel).splitlines()[:16]).lower()
            self.assertTrue(
                any(marker in head for marker in LEGACY_MARKERS),
                f"{rel} lacks a LEGACY/archive banner in its header",
            )
            self.assertIn(
                "multica",
                head,
                f"{rel} header must name Multica as the live source of truth",
            )

    def test_onboard_banner_is_multica_only(self):
        """The one-line onboarding banner must state the Multica-only rule."""
        text = read("scripts/onboard.sh").lower()
        self.assertIn("multica-only rule", text)
        self.assertNotIn("jira-only rule", text)


if __name__ == "__main__":
    unittest.main()
