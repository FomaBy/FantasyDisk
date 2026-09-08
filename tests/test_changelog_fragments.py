from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ASSEMBLER_PATH = ROOT / "tools" / "assemble_changelog.py"
SPEC = importlib.util.spec_from_file_location("assemble_changelog_tested", ASSEMBLER_PATH)
assembler = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = assembler
SPEC.loader.exec_module(assembler)


def changelog_template() -> str:
    return """\
# Changelog

## [0.9.9] — 2026-01-01

<!-- BEGIN GENERATED CHANGELOG FRAGMENTS -->
<!-- END GENERATED CHANGELOG FRAGMENTS -->

### Existing notes

- This prose remains untouched.
"""


class ChangelogFragmentTests(unittest.TestCase):
    def write_fragment(self, directory: Path, name: str, text: str) -> None:
        directory.mkdir(parents=True, exist_ok=True)
        (directory / name).write_text(text, encoding="utf-8")

    def test_shipped_fragments_match_the_canonical_changelog(self) -> None:
        changelog = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
        assembled = assembler.assemble_changelog(changelog, ROOT / "changelog.d")
        self.assertEqual(assembled, changelog)
        self.assertIn("FAN-3903", assembled)
        self.assertIn("FAN-3904", assembled)
        self.assertIn("FAN-3912", assembled)
        self.assertNotIn("FAN-3905", assembled)

    def test_repeated_assembly_is_byte_deterministic(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            fragments = Path(tmp) / "fragments"
            self.write_fragment(
                fragments,
                "FAN-100.md",
                "### Tools\n\n- Entry one.\n",
            )
            self.write_fragment(
                fragments,
                "FAN-2.md",
                "### Tools\n\n- Entry two.\n",
            )
            first = assembler.assemble_changelog(changelog_template(), fragments)
            second = assembler.assemble_changelog(first, fragments)

        self.assertEqual(first.encode("utf-8"), second.encode("utf-8"))
        self.assertLess(first.index("Entry two."), first.index("Entry one."))

    def test_malformed_fragment_fails_with_its_filename(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            fragments = Path(tmp) / "fragments"
            self.write_fragment(fragments, "FAN-100.md", "- Missing the required heading.\n")

            with self.assertRaisesRegex(
                assembler.FragmentError,
                r"FAN-100\.md: must start with a level-three section heading",
            ):
                assembler.assemble_changelog(changelog_template(), fragments)

    def test_duplicate_fragment_content_fails_with_both_sources(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            fragments = Path(tmp) / "fragments"
            fragment = "### Tools\n\n- This entry is duplicated.\n"
            self.write_fragment(fragments, "FAN-100.md", fragment)
            self.write_fragment(fragments, "FAN-101.md", fragment)

            with self.assertRaisesRegex(
                assembler.FragmentError,
                r"FAN-101\.md: duplicates fragment content from FAN-100\.md",
            ):
                assembler.assemble_changelog(changelog_template(), fragments)

    def test_cli_writes_then_detects_a_stale_canonical_region(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            fragments = root / "fragments"
            changelog = root / "CHANGELOG.md"
            self.write_fragment(fragments, "FAN-100.md", "### Tools\n\n- Initial entry.\n")
            changelog.write_text(changelog_template(), encoding="utf-8")

            self.assertEqual(
                assembler.main(
                    ["--fragments", str(fragments), "--changelog", str(changelog), "--write"]
                ),
                0,
            )
            self.assertEqual(
                assembler.main(["--fragments", str(fragments), "--changelog", str(changelog)]),
                0,
            )
            self.write_fragment(fragments, "FAN-100.md", "### Tools\n\n- Changed entry.\n")
            self.assertEqual(
                assembler.main(["--fragments", str(fragments), "--changelog", str(changelog)]),
                2,
            )


if __name__ == "__main__":
    unittest.main()
