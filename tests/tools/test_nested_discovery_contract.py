"""Live proof that each nested test file has exactly one discovery root.

This suite lives one level below ``tests/`` on purpose: a flat runner never
reaches it.  The contract below counts only roots from which ``unittest`` can
descend through package directories, so both skipped and duplicate collection
fail the gate instead of silently accepting this file.
"""
from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _reaches_test_file(discovery_root: Path, test_file: Path) -> bool:
    """Whether ``unittest discover -s discovery_root`` can reach ``test_file``."""
    try:
        nested_parts = test_file.parent.relative_to(discovery_root).parts
    except ValueError:
        return False

    directory = discovery_root
    for part in nested_parts:
        directory = directory / part
        if not (directory / "__init__.py").is_file():
            return False
    return test_file.is_file()


def _load_quality_gate():
    spec = importlib.util.spec_from_file_location(
        "quality_gate_nested_contract", ROOT / "tools" / "quality_gate.py"
    )
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class NestedDiscoveryContractTests(unittest.TestCase):
    def test_this_file_has_exactly_one_discovery_root(self) -> None:
        quality = _load_quality_gate()
        test_file = Path(__file__).resolve()
        covering_roots = [
            root
            for root in quality.python_unit_discovery_roots()
            if _reaches_test_file(root, test_file)
        ]
        self.assertEqual(
            1,
            len(covering_roots),
            f"expected exactly one discovery root to reach {test_file}, got {covering_roots}",
        )

    def test_this_file_is_discovered(self) -> None:
        quality = _load_quality_gate()
        self.assertIn(Path(__file__).resolve(), quality.discover_python_tests())


if __name__ == "__main__":
    unittest.main()
