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


if __name__ == "__main__":
    unittest.main()
