"""Contract tests for the FAN-3308 visual regression gate.

Everything here runs without Godot and without a display, so the dedicated CI
job can certify the gate's comparison maths, its baseline-write safety and its
negative probe on a headless Linux runner even though capturing pixels needs a
windowed session.
"""
from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import visual_gate  # noqa: E402

MANIFEST = json.loads((ROOT / "tests" / "visual_regression" / "manifest.json").read_text(encoding="utf-8"))
CERTIFIED = str(MANIFEST["capture"]["certified_platform"])
CAPTURE_SCRIPT = ROOT / "tests" / "visual_regression" / "capture.gd"


def solid(size=(64, 64), color=(20, 40, 60)) -> Image.Image:
    return Image.new("RGB", size, color)


class CompareTests(unittest.TestCase):
    def test_identical_images_have_no_difference(self):
        outcome = visual_gate.compare(solid(), solid(), tolerance=0)
        self.assertEqual(outcome["diff_ratio"], 0.0)
        self.assertEqual(outcome["differing_pixels"], 0)
        self.assertFalse(outcome["size_mismatch"])

    def test_delta_below_tolerance_is_not_counted(self):
        # A four-step channel drift is renderer noise, not a visual regression.
        outcome = visual_gate.compare(solid(), solid(color=(24, 44, 64)), tolerance=8)
        self.assertEqual(outcome["differing_pixels"], 0)
        self.assertEqual(outcome["max_channel_delta"], 4)

    def test_delta_above_tolerance_is_counted(self):
        outcome = visual_gate.compare(solid(), solid(color=(120, 40, 60)), tolerance=8)
        self.assertEqual(outcome["diff_ratio"], 1.0)

    def test_visible_block_is_measured_by_area(self):
        mutated = solid()
        ImageDraw.Draw(mutated).rectangle([0, 0, 31, 31], fill=(255, 0, 255))
        outcome = visual_gate.compare(solid(), mutated, tolerance=8)
        # A 32x32 block of a 64x64 image is exactly a quarter of the pixels.
        self.assertAlmostEqual(outcome["diff_ratio"], 0.25, places=6)

    def test_size_mismatch_fails_closed(self):
        outcome = visual_gate.compare(solid(), solid(size=(64, 32)), tolerance=8)
        self.assertTrue(outcome["size_mismatch"])
        self.assertEqual(outcome["diff_ratio"], 1.0)


class ManifestTests(unittest.TestCase):
    def test_case_count_is_within_the_required_band(self):
        self.assertTrue(visual_gate.MIN_CASES <= len(MANIFEST["cases"]) <= visual_gate.MAX_CASES)

    def test_required_coverage_is_present(self):
        kinds = [case["kind"] for case in MANIFEST["cases"]]
        self.assertGreaterEqual(kinds.count("ultimate_v2"), 3)
        self.assertGreaterEqual(kinds.count("flipbook"), 2)
        self.assertIn("main_menu", kinds)
        self.assertIn("hud_widget", kinds)

    def test_case_ids_are_unique(self):
        ids = [case["id"] for case in MANIFEST["cases"]]
        self.assertEqual(len(ids), len(set(ids)))

    def test_every_referenced_resource_exists(self):
        for case in MANIFEST["cases"]:
            for field in ("scene", "pack"):
                if field in case:
                    self.assertTrue(
                        visual_gate.res_to_path(case[field]).exists(),
                        f"{case['id']}: missing {case[field]}",
                    )

    def test_run_inputs_are_pinned(self):
        capture = MANIFEST["capture"]
        for key in ("godot_build_id", "renderer", "locale", "seed", "settle_frames"):
            self.assertIn(key, capture, f"capture.{key} must be pinned")

    def test_validate_only_accepts_the_committed_baselines(self):
        status = visual_gate.main(["--validate-only", "--require-baselines", "--platform", CERTIFIED])
        self.assertEqual(status, visual_gate.EXIT_OK)


class BaselineSafetyTests(unittest.TestCase):
    def _baseline_state(self) -> dict[str, str]:
        directory = visual_gate.baseline_dir(CERTIFIED)
        return {
            path.name: visual_gate.sha256_file(path)
            for path in sorted(directory.rglob("*"))
            if path.is_file()
        }

    def test_update_without_review_marker_is_refused(self):
        before = self._baseline_state()
        status = visual_gate.main(["--update-baselines", "--platform", CERTIFIED])
        self.assertEqual(status, visual_gate.EXIT_ERROR)
        self.assertEqual(before, self._baseline_state(), "refused update must not touch baselines")

    def test_every_baseline_carries_a_recorded_review_marker(self):
        index = visual_gate.read_index(CERTIFIED)
        for case in MANIFEST["cases"]:
            entry = index.get(case["id"])
            self.assertIsNotNone(entry, f"{case['id']}: no index entry")
            self.assertTrue(str(entry["review"]).strip(), f"{case['id']}: empty review marker")

    def test_recorded_hashes_match_the_committed_pixels(self):
        index = visual_gate.read_index(CERTIFIED)
        directory = visual_gate.baseline_dir(CERTIFIED)
        for case in MANIFEST["cases"]:
            image = directory / f"{case['id']}.png"
            self.assertEqual(index[case["id"]]["sha256"], visual_gate.sha256_file(image))


class NegativeProbeTests(unittest.TestCase):
    def test_probe_detects_a_visible_mutation_and_leaves_the_checkout_alone(self):
        directory = visual_gate.baseline_dir(CERTIFIED)
        before = {
            path: visual_gate.sha256_file(path)
            for path in sorted(directory.rglob("*"))
            if path.is_file()
        }
        status = visual_gate.main(["--negative-probe", "--platform", CERTIFIED])
        # EXIT_FAILED is the contract: the probe proves the gate rejects a
        # visibly mutated frame, so a passing probe is a non-zero exit.
        self.assertEqual(status, visual_gate.EXIT_FAILED)
        after = {
            path: visual_gate.sha256_file(path)
            for path in sorted(directory.rglob("*"))
            if path.is_file()
        }
        self.assertEqual(before, after, "negative probe must not modify the checkout")


class CaptureScriptTests(unittest.TestCase):
    def test_capture_refuses_headless(self):
        # The dummy rasterizer reads back empty images; capturing there would
        # silently certify blank baselines.
        source = CAPTURE_SCRIPT.read_text(encoding="utf-8")
        self.assertIn('DisplayServer.get_name() == "headless"', source)

    def test_capture_script_has_its_uid_sidecar(self):
        self.assertTrue(Path(f"{CAPTURE_SCRIPT}.uid").is_file())


if __name__ == "__main__":
    unittest.main()
