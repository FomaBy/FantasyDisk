"""Live proof that nested test directories are collected and executed.

This suite lives one level below ``tests/`` on purpose: a flat runner never
reaches it.  ``tests/test_quality_tools.py`` asserts that every discovered
Python test file is covered by a discovery root, so losing the recursion also
fails the gate instead of silently skipping this file.
"""
from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _load_quality_gate():
    spec = importlib.util.spec_from_file_location(
        "quality_gate_nested_contract", ROOT / "tools" / "quality_gate.py"
    )
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class NestedDiscoveryContractTests(unittest.TestCase):
    def test_this_directory_is_a_discovery_root(self) -> None:
        quality = _load_quality_gate()
        here = Path(__file__).resolve().parent
        self.assertNotEqual(here, quality.TEST_DIR)
        self.assertIn(here, quality.python_unit_discovery_roots())

    def test_this_file_is_discovered(self) -> None:
        quality = _load_quality_gate()
        self.assertIn(Path(__file__).resolve(), quality.discover_python_tests())


if __name__ == "__main__":
    unittest.main()
