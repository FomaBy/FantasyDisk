"""Regression guard for dangling skill/agent references (FAN-3450).

An active routing surface (`AGENTS.md`, `.claude/skills/*/SKILL.md`,
`skills/codex/*/SKILL.md`, `skills/scheduled-tasks/*/SKILL.md`,
`docs/process/*.md`) that names a skill in backticks must name one that
actually exists. This guards against the class of bug that shipped
`fantasydisk-animation-director` after the skill was renamed to
`fantasydisk-pixellab-animation-integrator`, silently misrouting the next
agent that reads onboarding.
"""

import sys
import unittest
from contextlib import contextmanager
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tools import check_skill_references as checker  # noqa: E402


@contextmanager
def scratch_surface(content):
    """A throwaway file inside ROOT, since the checker resolves paths under ROOT."""
    path = ROOT / "tests" / "_scratch_skill_reference_check.md"
    path.write_text(content, encoding="utf-8")
    try:
        yield path.relative_to(ROOT).as_posix()
    finally:
        path.unlink(missing_ok=True)


class SkillReferenceCheckerTest(unittest.TestCase):
    def test_repo_has_no_dangling_active_references(self):
        dangling = checker.find_dangling_references()
        self.assertEqual(
            dangling,
            [],
            f"dangling active skill/agent references: {dangling}",
        )

    def test_flags_a_synthetic_broken_reference(self):
        with scratch_surface("Animation/rigs: `fantasydisk-does-not-exist`.\n") as rel:
            dangling = checker.find_dangling_references(
                surfaces=[rel], known_names=checker.known_skill_names()
            )
        self.assertEqual(len(dangling), 1)
        self.assertEqual(dangling[0][2], "fantasydisk-does-not-exist")

    def test_passes_a_known_skill_reference(self):
        with scratch_surface(
            "Animation/rigs: `fantasydisk-pixellab-animation-integrator`.\n"
        ) as rel:
            dangling = checker.find_dangling_references(
                surfaces=[rel], known_names=checker.known_skill_names()
            )
        self.assertEqual(dangling, [])

    def test_allowlisted_historical_reference_is_not_flagged(self):
        """CHANGELOG.md keeps the retired `fantasydisk-animation-director`
        name as history and must stay green even though the skill is gone."""
        text = (checker.ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
        self.assertIn("fantasydisk-animation-director", text)
        self.assertTrue(checker.is_historical("CHANGELOG.md"))
        dangling = checker.find_dangling_references(
            surfaces=["CHANGELOG.md"], known_names=checker.known_skill_names()
        )
        self.assertEqual(dangling, [])

    def test_default_surfaces_include_the_actual_onboarding_files(self):
        self.assertIn(".claude/skills/fantasydisk-onboarding/SKILL.md", checker.ACTIVE_SURFACES)
        self.assertIn(".claude/skills/add-character/SKILL.md", checker.ACTIVE_SURFACES)


if __name__ == "__main__":
    unittest.main()
