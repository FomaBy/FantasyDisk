"""``typography_inventory.py --check`` compares up to entry line numbers.

Fingerprints exclude line numbers by contract, yet the check used to compare
the rendered JSON byte for byte, so any edit above a font override in
``player.gd`` reported the inventory as stale and blocked unrelated
candidates (the inventory lives in the docs domain, so refreshing it in a
core change trips the ownership guard).  A changed or removed typography
site must still fail closed.
"""
from __future__ import annotations

import importlib.util
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def _load_tool():
    spec = importlib.util.spec_from_file_location(
        "typography_inventory_check_contract", ROOT / "tools" / "typography_inventory.py"
    )
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def _entry(line: int, fingerprint: str = "0123456789abcdef", source: str = "label.add_theme_font_size_override(\"font_size\", 18)") -> dict:
    return {
        "path": "scripts/ui/screens/hud.gd",
        "function": "_create_hud",
        "line": line,
        "fingerprint": fingerprint,
        "source": source,
        "kind": "theme_override",
        "role": "hud",
        "status": "mapped",
    }


def _document(entries: list[dict]) -> dict:
    return {"schema": 3, "entries": entries, "counts": {"total": len(entries)}}


class TypographyInventoryCheckTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tool = _load_tool()

    def _rendered(self, document: dict) -> str:
        return json.dumps(document, ensure_ascii=False, indent=2) + "\n"

    def test_line_movement_alone_keeps_the_inventory_current(self) -> None:
        committed = self._rendered(_document([_entry(2956)]))
        generated = _document([_entry(2962)])
        self.assertTrue(self.tool.is_current(committed, generated))

    def test_changed_site_is_stale(self) -> None:
        committed = self._rendered(_document([_entry(10)]))
        generated = _document([_entry(10, fingerprint="fedcba9876543210", source="label.add_theme_font_size_override(\"font_size\", 24)")])
        self.assertFalse(self.tool.is_current(committed, generated))

    def test_removed_site_is_stale(self) -> None:
        committed = self._rendered(_document([_entry(10), _entry(20, fingerprint="1111111111111111")]))
        generated = _document([_entry(10)])
        self.assertFalse(self.tool.is_current(committed, generated))

    def test_missing_or_invalid_committed_inventory_is_stale(self) -> None:
        generated = _document([_entry(10)])
        self.assertFalse(self.tool.is_current(None, generated))
        self.assertFalse(self.tool.is_current("{not json", generated))


if __name__ == "__main__":
    unittest.main()
