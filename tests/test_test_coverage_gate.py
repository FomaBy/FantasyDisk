from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools" / "test_coverage_gate.py"


class TestCoverageGateTests(unittest.TestCase):
    def test_regression_below_the_baseline_fails(self) -> None:
        with tempfile.TemporaryDirectory(prefix="test-coverage-gate-") as scratch:
            workspace = Path(scratch)
            tests = workspace / "tests"
            tests.mkdir()
            (tests / "only_test.gd").write_text("extends SceneTree\n", encoding="utf-8")
            (tests / "test_only.py").write_text("import unittest\n", encoding="utf-8")
            baseline = workspace / "baseline.json"
            baseline.write_text(
                json.dumps(
                    {
                        "schema_version": 1,
                        "groups": {
                            "godot": {"minimum_test_files": 2},
                            "python": {"minimum_test_files": 1},
                        },
                    }
                ),
                encoding="utf-8",
            )

            result = subprocess.run(
                [
                    sys.executable,
                    str(TOOL),
                    "--root",
                    str(workspace),
                    "--baseline",
                    str(baseline),
                ],
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
            )

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("godot", result.stderr)
        self.assertIn("below baseline", result.stderr)

    def test_baseline_reports_equal_test_surface_as_passing(self) -> None:
        with tempfile.TemporaryDirectory(prefix="test-coverage-gate-") as scratch:
            report = Path(scratch) / "report.json"
            markdown = Path(scratch) / "report.md"
            result = subprocess.run(
                [
                    sys.executable,
                    str(TOOL),
                    "--json-report",
                    str(report),
                    "--markdown-report",
                    str(markdown),
                ],
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
            )
            payload = json.loads(report.read_text(encoding="utf-8"))
            markdown_text = markdown.read_text(encoding="utf-8")

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(payload["status"], "passed")
        self.assertIn("vendor", payload["excluded_path_parts"])
        self.assertIn("Test coverage surface report", markdown_text)


if __name__ == "__main__":
    unittest.main()
