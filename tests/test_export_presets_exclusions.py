"""FAN-3973: the release export must carry game content only.

The 0.3.1 Windows Setup shipped ``evidence/p3-object-budget-rework/**``
(1,233 files, ~294 MiB), ``skills/**/*.json`` and the stray root
``before_/after_berserk_648p.png`` textures because neither export preset
excluded them and ``evidence/`` had no ``.gdignore``. Both presets must keep
excluding every non-game location, and the editor must never import the
evidence/skills trees in the first place.
"""
from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPORT_PRESETS = ROOT / "export_presets.cfg"

PRESET_NAMES = ("macOS", "Windows Desktop")
REQUIRED_EXCLUSIONS = (
    ".godot/*",
    "docs/*",
    "tools/*",
    "tests/*",
    "evidence/*",
    "skills/*",
    "before_berserk_648p.png",
    "after_berserk_648p.png",
)
GDIGNORE_DIRECTORIES = ("evidence", "skills")


def _preset_blocks(text: str) -> dict[str, str]:
    blocks: dict[str, str] = {}
    for match in re.finditer(r"\[preset\.(\d+)\]\n(.*?)(?=\n\[preset\.|\Z)", text, re.S):
        body = match.group(2)
        name = re.search(r'^name="([^"]*)"', body, re.M)
        if name:
            blocks[name.group(1)] = body
    return blocks


def _exclude_filter(block: str) -> list[str]:
    match = re.search(r'^exclude_filter="([^"]*)"', block, re.M)
    if not match:
        return []
    return [fragment.strip() for fragment in match.group(1).split(",") if fragment.strip()]


class ExportPresetExclusionsTest(unittest.TestCase):
    def setUp(self) -> None:
        self.presets = _preset_blocks(EXPORT_PRESETS.read_text(encoding="utf-8"))

    def test_both_presets_exist(self) -> None:
        for name in PRESET_NAMES:
            self.assertIn(name, self.presets, f"export_presets.cfg: preset {name!r} is missing")

    def test_both_presets_exclude_every_non_game_location(self) -> None:
        for name in PRESET_NAMES:
            fragments = _exclude_filter(self.presets.get(name, ""))
            for required in REQUIRED_EXCLUSIONS:
                self.assertIn(
                    required,
                    fragments,
                    f"export_presets.cfg {name} preset: exclude_filter must contain {required!r}",
                )

    def test_presets_share_one_exclusion_list(self) -> None:
        filters = {name: _exclude_filter(self.presets.get(name, "")) for name in PRESET_NAMES}
        self.assertEqual(
            filters["macOS"],
            filters["Windows Desktop"],
            "macOS and Windows Desktop presets must exclude the same paths",
        )

    def test_non_game_trees_are_gdignored(self) -> None:
        for directory in GDIGNORE_DIRECTORIES:
            marker = ROOT / directory / ".gdignore"
            self.assertTrue(marker.is_file(), f"{directory}/.gdignore must exist so the editor never imports it")

    def test_stray_root_textures_are_not_game_resources(self) -> None:
        # The exclusions above name concrete files; if those files are ever
        # removed from the repository the fragments are harmless but stale.
        # Any other root-level texture would ship again, so there must be none.
        for path in ROOT.iterdir():
            if path.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp"}:
                self.assertIn(
                    path.name,
                    REQUIRED_EXCLUSIONS,
                    f"root texture {path.name} is not excluded from the export",
                )


if __name__ == "__main__":
    unittest.main()
