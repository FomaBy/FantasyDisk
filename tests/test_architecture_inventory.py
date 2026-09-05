from __future__ import annotations

import json
import subprocess
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import architecture_inventory as inventory


class ArchitectureInventoryTest(unittest.TestCase):
    def test_current_facades_have_reproducible_inventory(self):
        result = inventory.build_inventory(ROOT)

        self.assertEqual(result["audit_baseline_sha"], inventory.AUDIT_BASELINE_SHA)
        self.assertIn("Resolve each facade", result["method"])
        facades = {item["name"]: item for item in result["facades"]}
        self.assertEqual(set(facades), {"ui_screens", "class_weapon"})
        self.assertEqual(facades["ui_screens"]["module_count"], 29)
        self.assertEqual(facades["class_weapon"]["module_count"], 20)
        for facade in facades.values():
            self.assertGreater(facade["line_count"], 0)
            self.assertEqual(len(facade["modules"]), facade["module_count"])
            self.assertEqual(len(facade["dependency_edges"]), facade["module_count"])
            self.assertEqual(
                facade["line_count"],
                sum(module["line_count"] for module in facade["modules"]),
            )
            self.assertEqual(facade["modules"][-1]["path"], facade["facade"])
            self.assertEqual(facade["dependency_edges"][0]["from"], facade["facade"])

    def test_cli_serializes_same_inventory(self):
        result = subprocess.run(
            [sys.executable, "tools/architecture_inventory.py", "--root", str(ROOT)],
            cwd=ROOT,
            check=False,
            capture_output=True,
            text=True,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), inventory.build_inventory(ROOT))


if __name__ == "__main__":
    unittest.main()
