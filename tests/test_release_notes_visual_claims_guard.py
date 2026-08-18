from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GUARD_PATH = ROOT / "tools" / "release_notes_visual_claims_guard.py"
SPEC = importlib.util.spec_from_file_location("release_notes_visual_claims_guard_tested", GUARD_PATH)
guard = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(guard)

UNBACKED_CLAIM = """\
## [0.9.9] — 2026-01-01

### Главное

- **Главное:** ультимейт получил свою раскадровку и уникальные визуальные
  эффекты для каждого оружия.

## [0.9.8] — 2025-12-01
"""

BACKED_CLAIM = """\
## [0.9.9] — 2026-01-01

### Главное

- **Главное:** ультимейт получил свою раскадровку и уникальные визуальные
  эффекты для каждого оружия (FAN-9001, живой QA прошла: QA PASSED).

## [0.9.8] — 2025-12-01
"""

KNOWN_LIMITATION_DISCLOSURE = """\
## [0.9.9] — 2026-01-01

### Главное

- **Главное:** ультимейт принадлежит оружию.

### Известные ограничения

- Визуал ультимейтов пока общий для класса, а не собственный для оружия:
  часть сцен не содержит рисующих узлов вместо авторской раскадровки.

## [0.9.8] — 2025-12-01
"""

FUNCTIONAL_EFFECT_CLEANUP = """\
## [0.9.9] — 2026-01-01

### Главное

- **Главное:** ульты честно завершают свои эффекты и больше не копят заряд
  между боями сверх правил.

## [0.9.8] — 2025-12-01
"""


class ReleaseNotesVisualClaimsGuardTests(unittest.TestCase):
    def test_shipped_changelog_has_no_unbacked_visual_claims(self) -> None:
        changelog_text = guard.CHANGELOG_PATH.read_text(encoding="utf-8")
        for version in ("0.3.0", "0.2.4", "0.2.1", "0.1.7"):
            with self.subTest(version=version):
                self.assertEqual(
                    guard.unbacked_visual_claims(changelog_text, version), []
                )

    def test_unbacked_own_storyboard_claim_fails_closed(self) -> None:
        violations = guard.unbacked_visual_claims(UNBACKED_CLAIM, "0.9.9")
        self.assertEqual(len(violations), 1)
        self.assertIn("раскадровку", violations[0])

    def test_claim_backed_by_a_qa_card_reference_passes(self) -> None:
        self.assertEqual(guard.unbacked_visual_claims(BACKED_CLAIM, "0.9.9"), [])

    def test_known_limitations_disclosure_is_exempt(self) -> None:
        self.assertEqual(
            guard.unbacked_visual_claims(KNOWN_LIMITATION_DISCLOSURE, "0.9.9"), []
        )

    def test_functional_effect_cleanup_is_not_a_visual_claim(self) -> None:
        self.assertEqual(
            guard.unbacked_visual_claims(FUNCTIONAL_EFFECT_CLEANUP, "0.9.9"), []
        )

    def test_missing_version_section_is_not_a_violation(self) -> None:
        self.assertEqual(guard.unbacked_visual_claims(UNBACKED_CLAIM, "0.0.1"), [])

    def test_cli_exits_nonzero_on_unbacked_claim(self) -> None:
        import subprocess
        import sys
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            changelog = Path(tmp) / "CHANGELOG.md"
            changelog.write_text(UNBACKED_CLAIM, encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(GUARD_PATH), "--version", "0.9.9", "--changelog", str(changelog)],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 2)

    def test_cli_exits_zero_on_backed_claim(self) -> None:
        import subprocess
        import sys
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            changelog = Path(tmp) / "CHANGELOG.md"
            changelog.write_text(BACKED_CLAIM, encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(GUARD_PATH), "--version", "0.9.9", "--changelog", str(changelog)],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
