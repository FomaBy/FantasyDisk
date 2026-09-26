"""Keep every presentation capture suite guarded against the headless renderer.

FAN-3391: `sniper_contact_sheet.gd` shipped without the guard its fifteen
siblings carry, so the dummy rasterizer handed it an empty SubViewport readback
and the suite failed the quality gate on `dev` for every candidate.  The gate
runs headless, so an unguarded capture suite is always red there.
"""
from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PRESENTATION = ROOT / "tests" / "ultimates" / "presentation"
VIEWPORT_READBACK = "get_texture().get_image()"
HEADLESS_GUARD = 'DisplayServer.get_name() == "headless"'


class HeadlessCaptureGuardTests(unittest.TestCase):
    def _unguarded_scripts(self, root: Path, pattern: str = "*.gd"):
        readback: list[str] = []
        unguarded: list[str] = []
        for script in sorted(root.rglob(pattern)):
            source = script.read_text(encoding="utf-8")
            if VIEWPORT_READBACK not in source:
                continue
            readback.append(script.name)
            if HEADLESS_GUARD not in source:
                try:
                    label = script.relative_to(ROOT).as_posix()
                except ValueError:
                    label = script.as_posix()
                unguarded.append(label)
        return readback, unguarded

    def test_every_viewport_readback_suite_guards_headless(self):
        readback: list[str] = []
        unguarded: list[str] = []
        for script in sorted(PRESENTATION.glob("*.gd")):
            source = script.read_text(encoding="utf-8")
            if VIEWPORT_READBACK not in source:
                continue
            readback.append(script.name)
            if HEADLESS_GUARD not in source:
                unguarded.append(script.relative_to(ROOT).as_posix())
        # An empty scan would certify as green without reading a single suite.
        self.assertIn("sniper_contact_sheet.gd", readback)
        self.assertEqual(unguarded, [])

    def test_guard_detector_actually_catches_unguarded_fixture(self):
        # Failure case (FAN-3934): the CI contract must fail for a suite that
        # performs a viewport readback without any headless guard — exactly the
        # shape of the engineer suite at failed run 34429832208.
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            fixture_root = Path(tmp)
            (fixture_root / "bad_capture.gd").write_text(
                "extends SceneTree\n"
                "func _run() -> void:\n"
                "\tvar image := root.get_texture().get_image()\n",
                encoding="utf-8",
            )
            readback, unguarded = self._unguarded_scripts(fixture_root)
            self.assertIn("bad_capture.gd", readback)
            self.assertEqual(unguarded, [str(Path(tmp) / "bad_capture.gd")])

    def test_guarded_fixture_passes_detector(self):
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            fixture_root = Path(tmp)
            (fixture_root / "good_capture.gd").write_text(
                "extends SceneTree\n"
                "func _run() -> void:\n"
                f'\tif {HEADLESS_GUARD}:\n'
                "\t\treturn\n"
                "\tvar image := root.get_texture().get_image()\n",
                encoding="utf-8",
            )
            readback, unguarded = self._unguarded_scripts(fixture_root)
            self.assertIn("good_capture.gd", readback)
            self.assertEqual(unguarded, [])


if __name__ == "__main__":
    unittest.main()
