from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TEMPLATE = ROOT / "docs/design/templates/release_notes"
RENDER = TEMPLATE / "render_release_notes.py"
CONTROLS = TEMPLATE / "controls"


class ReleaseNotesTemplateTest(unittest.TestCase):
    def run_case(self, tmp_path: Path, case: str) -> dict:
        output = tmp_path / case
        result = subprocess.run(
            [sys.executable, str(RENDER), "--case", case, "--content", str(CONTROLS / f"{case}.json"), "--output-dir", str(output)],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads((output / "fit_report.json").read_text(encoding="utf-8"))
        self.assertTrue(report["ok"])
        return report


    def test_all_control_sets_use_the_same_fit_workflow(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            for case in ("short", "boundary", "overflow"):
                report = self.run_case(Path(temp_dir), case)
                self.assertEqual(report["planning_gate"], {"decision": "ready_for_image", "ok": True, "report": "ui_plan.report.json"})
                self.assertEqual(report["publishable_image"], "final/final.png")
                self.assertEqual(report["publishable_image_count"], 1)
                self.assertEqual(len(list((Path(temp_dir) / case / "final").glob("*.png"))), 1)
                self.assertTrue(report["render"]["ok"])
                for zone in report["render"]["zones"]:
                    self.assertTrue(zone["ok"])
                    bbox = zone.get("text_bbox")
                    self.assertIsNotNone(bbox)
                    x, y, w, h = zone["rect"]
                    bx, by, bw, bh = bbox
                    self.assertTrue(x <= bx <= bx + bw <= x + w)
                    self.assertTrue(y <= by <= by + bh <= y + h)


    def test_template_profile_layout_and_svg_share_five_zones(self) -> None:
        profile = json.loads((TEMPLATE / "export_profile.json").read_text(encoding="utf-8"))
        layout = json.loads((TEMPLATE / "layout.json").read_text(encoding="utf-8"))
        svg = (TEMPLATE / "source_template.svg").read_text(encoding="utf-8")
        profile_ids = [zone["id"] for zone in profile["zones"]]
        self.assertEqual(profile_ids, ["game_title", "version", "release_date", "key_changes", "fixed_bugs"])
        self.assertEqual([zone["id"] for zone in layout["zones"]], profile_ids)
        layout_by_id = {zone["id"]: zone for zone in layout["zones"]}
        for zone in profile["zones"]:
            self.assertEqual([layout_by_id[zone["id"]][key] for key in ("x", "y", "w", "h")], zone["rect"])
        for zone_id in profile_ids:
            self.assertIn(f'data-zone-id="{zone_id}"', svg)


    def test_overflow_case_is_shortened_before_render(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            report = self.run_case(Path(temp_dir), "overflow")
        self.assertIn("Ещё", report["content"]["key_changes"])
        self.assertIn("Ещё", report["content"]["fixed_bugs"])
        self.assertLessEqual(len(report["content"]["key_changes"].splitlines()), 6)
        self.assertLessEqual(len(report["content"]["fixed_bugs"].splitlines()), 6)


if __name__ == "__main__":
    unittest.main()
