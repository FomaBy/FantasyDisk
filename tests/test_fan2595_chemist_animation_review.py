from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools" / "build_fan2595_chemist_animation_review.py"


class ChemistAnimationReviewTests(unittest.TestCase):
    def test_committed_review_sheets_live_in_the_lfs_reference_pack(self) -> None:
        evidence_dir = ROOT / "docs" / "design" / "reference-assets-lfs" / "FAN-2595-chemist"
        legacy_dir = ROOT / "docs" / "design" / "previews"
        names = [
            "fan2595_chemist_8dir_contact.png",
            *[f"fan2595_chemist_row_{direction}.png" for direction in (
                "south",
                "south_east",
                "east",
                "north_east",
                "north",
                "north_west",
                "west",
                "south_west",
            )],
        ]

        self.assertTrue(all((evidence_dir / name).is_file() for name in names))
        self.assertTrue(all(not (legacy_dir / name).exists() for name in names))

    def _run_tool(self, root: Path, output_dir: Path) -> subprocess.CompletedProcess[str]:
        report = output_dir / "audit.json"
        return subprocess.run(
            [
                sys.executable,
                str(TOOL),
                "--root",
                str(root),
                "--output-dir",
                str(output_dir),
                "--report",
                str(report),
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

    def test_current_pack_passes_and_writes_all_direction_sheets(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output_dir = Path(temporary)
            result = self._run_tool(ROOT, output_dir)

            self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
            report = json.loads((output_dir / "audit.json").read_text(encoding="utf-8"))
            self.assertEqual(report["verdict"], "PASS")
            self.assertEqual(report["direction_count"], 8)
            self.assertEqual(report["source_frame_count"], 56)
            self.assertEqual(report["runtime_frame_count"], 56)
            self.assertEqual(report["mirror_pair_count"], 0)
            self.assertEqual(report["spriteframes"]["animation_count"], 27)
            self.assertEqual(report["spriteframes"]["body_attack_animations"], [])
            self.assertEqual(
                len(list(output_dir.glob("fan2595_chemist_row_*.png"))),
                8,
            )
            self.assertTrue((output_dir / "fan2595_chemist_8dir_contact.png").is_file())

    def test_mirrored_source_frame_fails_the_audit(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            test_root = Path(temporary) / "repo"
            source = ROOT / "assets" / "sprites" / "characters" / "pixellab" / "chemist"
            runtime = ROOT / "assets" / "sprites" / "characters" / "full_frame" / "chemist_pixellab"
            for relative in (
                Path("assets/sprites/characters/pixellab/chemist"),
                Path("assets/sprites/characters/full_frame/chemist_pixellab"),
            ):
                shutil.copytree(ROOT / relative, test_root / relative)
            for relative in (
                Path("assets/sprites/characters/chemist_spriteframes.tres"),
                Path("scripts/progression_data_characters.gd"),
            ):
                destination = test_root / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / relative, destination)

            mirrored = Image.open(source / "chemist_move_west_03.png").convert("RGBA")
            mirrored.transpose(Image.Transpose.FLIP_LEFT_RIGHT).save(
                test_root
                / "assets/sprites/characters/pixellab/chemist/chemist_move_east_03.png"
            )

            output_dir = Path(temporary) / "evidence"
            result = self._run_tool(test_root, output_dir)

            self.assertEqual(result.returncode, 1, result.stdout)
            report = json.loads((output_dir / "audit.json").read_text(encoding="utf-8"))
            self.assertEqual(report["verdict"], "FAIL")
            self.assertEqual(report["mirror_pair_count"], 1)
            self.assertEqual(
                report["mirror_pairs"][0]["source"],
                "chemist_move_east_03.png",
            )


if __name__ == "__main__":
    unittest.main()
