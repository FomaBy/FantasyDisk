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


@contextmanager
def temporary_surface(rel_path, content):
    """Create a disposable fixture at a path covered by a classification rule."""
    path = ROOT / rel_path
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    try:
        yield rel_path
    finally:
        path.unlink(missing_ok=True)


@contextmanager
def mutate_surface(rel_path, needle, replacement):
    """Temporarily break a real repository fixture and restore it afterwards."""
    path = ROOT / rel_path
    original = path.read_text(encoding="utf-8")
    if needle not in original:
        raise AssertionError(f"fixture does not contain expected text: {needle!r}")
    path.write_text(original.replace(needle, replacement, 1), encoding="utf-8")
    try:
        yield rel_path
    finally:
        path.write_text(original, encoding="utf-8")


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

    def test_default_surfaces_include_active_design_references(self):
        active_reference = "docs/design/references/character_animation_style_sheet_0_1_5.md"
        self.assertIn(active_reference, checker.ACTIVE_SURFACES)

    def test_real_animator_handoff_fixture_fails_closed_when_mutated(self):
        active_reference = "docs/design/references/character_animation_style_sheet_0_1_5.md"
        with mutate_surface(
            active_reference,
            "`fantasydisk-pixellab-animation-integrator`",
            "`fantasydisk-does-not-exist`",
        ):
            dangling = checker.find_dangling_references()
        self.assertTrue(
            any(
                rel == active_reference and token == "fantasydisk-does-not-exist"
                for rel, _line_no, token in dangling
            ),
            f"mutated active handoff was not rejected: {dangling}",
        )

    def test_precise_historical_design_evidence_remains_exempt(self):
        historical_reference = "docs/design/previews/_scratch_historical_skill_reference.md"
        with temporary_surface(
            historical_reference,
            "Retired evidence: `fantasydisk-does-not-exist`.\n",
        ):
            self.assertTrue(checker.is_historical(historical_reference))
            dangling = checker.find_dangling_references(surfaces=[historical_reference])
        self.assertEqual(dangling, [])


if __name__ == "__main__":
    unittest.main()
