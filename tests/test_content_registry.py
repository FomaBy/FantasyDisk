"""FAN-3913: content registry index/section contract and negative controls.

The real repository is checked once, so the split registry itself has to stay
consistent.  Every failure mode is proved on a small fixture repository built
from the same shapes the real registry uses: an index that lists sections, one
section file per owner, and canonical class/actor id registries under ``data``.
"""
from __future__ import annotations

import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHECKER = ROOT / "tools" / "check_content_registry.py"

_spec = importlib.util.spec_from_file_location("check_content_registry", CHECKER)
check_content_registry = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(check_content_registry)

INDEX = """# Fixture Content Registry

## Разделы Реестра

| Раздел | Файл |
| --- | --- |
| Персонажи | [`content/characters.md`](content/characters.md) |
| Стандартные Монстры | [`content/enemies.md`](content/enemies.md) |
| Звуковые Ассеты | [`content/audio.md`](content/audio.md) |
"""

CHARACTERS = """<!-- content-registry-section -->

# Fixture — Персонажи

## Персонажи

<!-- canonical-ids: class -->

| ID | Игровое имя |
| --- | --- |
| `berserk` | Берсерк |
| `knight` | Рыцарь |
"""

ENEMIES = """<!-- content-registry-section -->

# Fixture — Монстры

## Стандартные Монстры

<!-- canonical-ids: actor -->

| ID | Игровое имя |
| --- | --- |
| `rift_cutter` | Рубака Разлома |
"""

AUDIO = """<!-- content-registry-section -->

# Fixture — Звук

## Звуковые Ассеты

| ID | Файл |
| --- | --- |
| `hit` | `assets/audio/hit.wav` |
"""


class ContentRegistryFixture(unittest.TestCase):
    """A minimal but structurally real registry that each control mutates."""

    def setUp(self) -> None:
        self._temp = tempfile.TemporaryDirectory()
        self.addCleanup(self._temp.cleanup)
        self.root = Path(self._temp.name)
        self.content = self.root / "docs/design/content"
        self.content.mkdir(parents=True)
        self.index = self.root / "docs/design/content_registry.md"
        self.write(self.index, INDEX)
        self.write(self.content / "characters.md", CHARACTERS)
        self.write(self.content / "enemies.md", ENEMIES)
        self.write(self.content / "audio.md", AUDIO)
        for class_id in ("berserk", "knight"):
            (self.root / "data/ultimates/classes" / class_id).mkdir(parents=True)
        actors = self.root / "data/animation/enemy"
        actors.mkdir(parents=True)
        self.write(actors / "rift_cutter.json", "{}\n")

    @staticmethod
    def write(path: Path, text: str) -> None:
        path.write_text(text, encoding="utf-8")

    def errors(self) -> list[str]:
        return check_content_registry.registry_errors(self.root)

    def assertOneError(self, fragment: str) -> None:
        errors = self.errors()
        self.assertEqual(len(errors), 1, errors)
        self.assertIn(fragment, errors[0])


class RealRepositoryTest(unittest.TestCase):
    def test_split_registry_is_consistent(self) -> None:
        self.assertEqual(check_content_registry.registry_errors(ROOT), [])

    def test_cli_passes_on_the_real_repository(self) -> None:
        result = subprocess.run(
            [sys.executable, str(CHECKER), "--root", str(ROOT)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Content registry passed", result.stdout)

    def test_index_routes_every_section_to_an_existing_file(self) -> None:
        listed, errors = check_content_registry.parse_index(
            (ROOT / check_content_registry.INDEX_PATH).read_text(encoding="utf-8")
        )
        self.assertEqual(errors, [])
        self.assertGreater(len(listed), 1)
        for title, relative in listed.items():
            with self.subTest(section=title):
                self.assertTrue((ROOT / relative).is_file(), relative)


class IndexStructureTest(ContentRegistryFixture):
    def test_fixture_is_clean(self) -> None:
        self.assertEqual(self.errors(), [])

    def test_missing_index_fails_closed(self) -> None:
        self.index.unlink()
        self.assertOneError("compatibility index is missing")

    def test_missing_section_table_fails_closed(self) -> None:
        # An unreadable index lists nothing, so every real section is reported
        # as unlisted too; the unreadable index has to lead that list.
        self.write(self.index, "# Fixture Content Registry\n")
        self.assertIn("section table '## Разделы Реестра' is missing", self.errors()[0])

    def test_renamed_table_columns_fail_closed(self) -> None:
        self.write(self.index, INDEX.replace("| Раздел | Файл |", "| Section | File |"))
        self.assertIn("must open with", self.errors()[0])

    def test_unreadable_row_is_reported(self) -> None:
        self.write(self.index, INDEX.replace(
            "| Звуковые Ассеты | [`content/audio.md`](content/audio.md) |",
            "| Звуковые Ассеты | content/audio.md |",
        ))
        errors = self.errors()
        self.assertTrue(any("cannot read section row" in error for error in errors), errors)

    def test_link_label_must_match_its_target(self) -> None:
        self.write(self.index, INDEX.replace(
            "[`content/audio.md`](content/audio.md)",
            "[`content/sound.md`](content/audio.md)",
        ))
        errors = self.errors()
        self.assertTrue(any("but links to" in error for error in errors), errors)

    def test_link_outside_the_content_directory_is_rejected(self) -> None:
        self.write(self.index, INDEX.replace(
            "[`content/audio.md`](content/audio.md)",
            "[`systems/audio.md`](systems/audio.md)",
        ))
        errors = self.errors()
        self.assertTrue(any("links outside" in error for error in errors), errors)

    def test_duplicate_row_is_rejected(self) -> None:
        self.write(self.index, INDEX + "| Персонажи | [`content/audio.md`](content/audio.md) |\n")
        errors = self.errors()
        self.assertTrue(any("listed more than once" in error for error in errors), errors)

    def test_index_may_not_keep_a_registry_section(self) -> None:
        self.write(self.index, INDEX + "\n## Магазинные Предметы\n\nтекст\n")
        self.assertOneError("keeps registry section 'Магазинные Предметы'")


class SectionOwnershipTest(ContentRegistryFixture):
    def test_section_missing_from_the_index_is_reported(self) -> None:
        self.write(self.content / "audio.md", AUDIO + "\n## Музыка\n\nтекст\n")
        self.assertOneError("section 'Музыка' is not listed")

    def test_listed_section_absent_from_its_file_is_reported(self) -> None:
        self.write(self.content / "audio.md", AUDIO.replace(
            "## Звуковые Ассеты", "## Звук И Музыка"
        ))
        errors = self.errors()
        self.assertEqual(len(errors), 2, errors)
        self.assertTrue(any("'Звук И Музыка' is not listed" in error for error in errors), errors)
        self.assertTrue(any("which does not hold it" in error for error in errors), errors)

    def test_section_listed_against_the_wrong_file_is_reported(self) -> None:
        self.write(self.index, INDEX.replace(
            "| Звуковые Ассеты | [`content/audio.md`](content/audio.md) |",
            "| Звуковые Ассеты | [`content/enemies.md`](content/enemies.md) |",
        ))
        errors = self.errors()
        self.assertTrue(any("but lives in" in error for error in errors), errors)

    def test_one_section_may_not_live_in_two_files(self) -> None:
        self.write(self.content / "audio.md", AUDIO.replace(
            "## Звуковые Ассеты", "## Стандартные Монстры"
        ))
        errors = self.errors()
        self.assertTrue(any("also exists in" in error for error in errors), errors)

    def test_marked_file_absent_from_the_index_is_reported(self) -> None:
        self.write(self.content / "shop.md", "<!-- content-registry-section -->\n\n# Fixture\n")
        self.assertOneError("registry section file absent from")

    def test_unmarked_neighbour_file_is_not_registry_content(self) -> None:
        self.write(
            self.content / "ultimate_feature_list_evidence.md",
            "# Evidence\n\n## Стандартные Монстры\n\n| ID |\n| --- |\n| `unknown_actor` |\n",
        )
        self.assertEqual(self.errors(), [])


class CanonicalIdTest(ContentRegistryFixture):
    def test_duplicate_id_inside_one_block_is_reported(self) -> None:
        self.write(self.content / "audio.md", AUDIO + "| `hit` | `assets/audio/hit2.wav` |\n")
        self.assertOneError("duplicate canonical id 'hit'")

    def test_the_same_id_in_two_blocks_stays_legal(self) -> None:
        self.write(self.content / "audio.md", AUDIO + "\n### Дополнительно\n\n"
                   "| ID | Файл |\n| --- | --- |\n| `hit` | `assets/audio/hit2.wav` |\n")
        self.assertEqual(self.errors(), [])

    def test_unknown_class_id_is_reported(self) -> None:
        self.write(self.content / "characters.md", CHARACTERS + "| `paladin` | Паладин |\n")
        self.assertOneError("unknown class id 'paladin'")

    def test_malformed_class_ids_are_rejected_in_canonical_columns(self) -> None:
        for identifier in ("PALADIN", "paladin-x", "paladin.x"):
            with self.subTest(identifier=identifier):
                self.write(
                    self.content / "characters.md",
                    CHARACTERS + f"| `{identifier}` | Паладин |\n",
                )
                errors = self.errors()
                self.assertTrue(
                    any(f"invalid canonical id '{identifier}'" in error for error in errors),
                    errors,
                )
                self.assertTrue(
                    any(f"unknown class id '{identifier}'" in error for error in errors),
                    errors,
                )

    def test_repeated_malformed_class_id_is_not_dropped(self) -> None:
        self.write(
            self.content / "characters.md",
            CHARACTERS + "| `PALADIN` | Паладин |\n| `PALADIN` | Паладин |\n",
        )
        errors = self.errors()
        self.assertTrue(any("invalid canonical id 'PALADIN'" in error for error in errors), errors)
        self.assertTrue(any("duplicate canonical id 'PALADIN'" in error for error in errors), errors)
        self.assertTrue(any("unknown class id 'PALADIN'" in error for error in errors), errors)

    def test_unknown_actor_id_is_reported(self) -> None:
        self.write(self.content / "enemies.md", ENEMIES + "| `rift_kutter` | Опечатка |\n")
        self.assertOneError("unknown actor id 'rift_kutter'")

    def test_undeclared_block_is_not_checked_against_a_registry(self) -> None:
        self.write(self.content / "audio.md", AUDIO + "| `no_such_actor` | `assets/audio/x.wav` |\n")
        self.assertEqual(self.errors(), [])

    def test_unknown_id_domain_is_reported(self) -> None:
        self.write(self.content / "audio.md", AUDIO.replace(
            "## Звуковые Ассеты\n", "## Звуковые Ассеты\n\n<!-- canonical-ids: sound -->\n"
        ))
        self.assertOneError("unknown canonical id domain 'sound'")

    def test_two_id_domains_in_one_block_are_reported(self) -> None:
        self.write(self.content / "characters.md", CHARACTERS.replace(
            "<!-- canonical-ids: class -->",
            "<!-- canonical-ids: class -->\n<!-- canonical-ids: actor -->",
        ))
        errors = self.errors()
        self.assertTrue(any("canonical id domain twice" in error for error in errors), errors)

    def test_id_domain_outside_a_section_is_reported(self) -> None:
        self.write(self.content / "audio.md", AUDIO.replace(
            "# Fixture — Звук", "<!-- canonical-ids: actor -->\n\n# Fixture — Звук"
        ))
        self.assertOneError("canonical id domain declared outside a section")

    def test_empty_canonical_registry_fails_closed(self) -> None:
        (self.root / "data/ultimates/classes/berserk").rmdir()
        (self.root / "data/ultimates/classes/knight").rmdir()
        errors = self.errors()
        self.assertTrue(any("registry classes is empty" in error for error in errors), errors)


class CliTest(ContentRegistryFixture):
    def test_cli_reports_every_error_and_fails(self) -> None:
        self.write(self.content / "audio.md", AUDIO + "| `hit` | `assets/audio/hit2.wav` |\n")
        result = subprocess.run(
            [sys.executable, str(CHECKER), "--root", str(self.root)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("FAIL: ", result.stderr)
        self.assertIn("duplicate canonical id 'hit'", result.stderr)
        self.assertIn("1 error(s)", result.stderr)


if __name__ == "__main__":
    unittest.main()
