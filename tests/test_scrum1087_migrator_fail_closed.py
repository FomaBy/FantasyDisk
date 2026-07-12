#!/usr/bin/env python3
"""Negative regression coverage for SCRUM-1087's fingerprint gate."""

from __future__ import annotations

import copy
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import migrate_scrum1073_typography as migrator  # noqa: E402


PATH = "scripts/example.gd"
FUNCTION = "_build_label"
KIND = "theme_override"
EXACT_SOURCE = (
    'label.add_theme_font_size_override("font_size", '
    "SemanticTypography.resolve_fixed(SemanticTypography.ROLE_ACTION, 16, "
    "SemanticTypography.role_min(SemanticTypography.ROLE_ACTION), "
    "SemanticTypography.role_max(SemanticTypography.ROLE_ACTION)))"
)


def _raw_entry(source: str, ordinal: int = 0) -> dict:
    return {
        "fingerprint": migrator._fingerprint(PATH, FUNCTION, source, ordinal),
        "path": PATH,
        "function": FUNCTION,
        "line": 10,
        "kind": KIND,
        "source": source,
    }


def _reviewed_entry(source: str = EXACT_SOURCE, ordinal: int = 0) -> dict:
    entry = _raw_entry(source, ordinal)
    entry.update({
        "role": "action",
        "status": "mapped",
        "mapping_mode": "semantic_native",
        "effective_min": 16,
        "effective_max": 16,
        "mapping_source": "reviewed_manifest",
    })
    return entry


class ExactLiveSnapshotTest(unittest.TestCase):
    def setUp(self) -> None:
        self.existing = {
            "schema": 3,
            "migration_task": "SCRUM-1073",
            "entries": [_reviewed_entry()],
            "migrations": [],
        }

    def test_exact_snapshot_passes(self) -> None:
        candidate, changed = migrator._reconcile_token_equivalent_fingerprints(
            self.existing, [_raw_entry(EXACT_SOURCE)]
        )
        self.assertFalse(changed)
        self.assertEqual(
            self.existing["entries"][0]["fingerprint"],
            candidate["entries"][0]["fingerprint"],
        )

    def test_spoofed_fingerprint_cannot_hide_identity_drift(self) -> None:
        live = _raw_entry('label.add_theme_font_size_override("font_size", 1)')
        live["fingerprint"] = self.existing["entries"][0]["fingerprint"]
        with self.assertRaisesRegex(SystemExit, "not token-equivalent"):
            migrator._reconcile_token_equivalent_fingerprints(self.existing, [live])

    def test_reordered_exact_fingerprints_fail(self) -> None:
        second_source = EXACT_SOURCE.replace("label.", "other_label.")
        existing = copy.deepcopy(self.existing)
        existing["entries"].append(_reviewed_entry(second_source, 0))
        live = [_raw_entry(second_source), _raw_entry(EXACT_SOURCE)]
        with self.assertRaisesRegex(SystemExit, "not token-equivalent"):
            migrator._reconcile_token_equivalent_fingerprints(existing, live)

    def test_tokenizer_ignores_outer_whitespace_but_preserves_string_contents(self) -> None:
        reformatted = EXACT_SOURCE.replace(
            "add_theme_font_size_override(", "add_theme_font_size_override( ", 1
        )
        self.assertEqual(
            migrator._gdscript_expression_tokens(EXACT_SOURCE),
            migrator._gdscript_expression_tokens(reformatted),
        )
        string_changed = EXACT_SOURCE.replace('"font_size"', '"font size"')
        self.assertNotEqual(
            migrator._gdscript_expression_tokens(EXACT_SOURCE),
            migrator._gdscript_expression_tokens(string_changed),
        )

    def test_tokenizer_preserves_adjacency_sensitive_gdscript_forms(self) -> None:
        adjacency_cases = [
            ("1e-3", "1e - 3"),
            (".5", ". 5"),
            ('&"StringName"', '& "StringName"'),
            ('^"NodePath"', '^ "NodePath"'),
            ("$Node/Child", "$ Node/Child"),
            ('$"Node/Child"', '$ "Node/Child"'),
            ("%UniqueNode", "% UniqueNode"),
            ("@export", "@ export"),
            ("value:=1", "value: =1"),
        ]
        for compact, spaced in adjacency_cases:
            with self.subTest(compact=compact):
                self.assertNotEqual(
                    migrator._gdscript_expression_tokens(compact),
                    migrator._gdscript_expression_tokens(spaced),
                )


class MainFailClosedTest(unittest.TestCase):
    DRIFT_CASES = {
        "numeric_literal": EXACT_SOURCE.replace(", 16,", ", 17,"),
        "font_size_one": 'label.add_theme_font_size_override("font_size", 1)',
        "missing_role_literal": (
            'label.add_theme_font_size_override("font_size", '
            'SemanticTypography.resolve_fixed("action", 16))'
        ),
        "removed_resolver": 'label.add_theme_font_size_override("font_size", 16)',
        "changed_resolver": EXACT_SOURCE.replace("resolve_fixed", "clamp_to_role", 1),
        "changed_control": EXACT_SOURCE.replace("label.", "other_label.", 1),
        "changed_call": EXACT_SOURCE.replace(
            'label.add_theme_font_size_override("font_size", ', "label.set_font_size("
        ),
        "changed_role": EXACT_SOURCE.replace("ROLE_ACTION", "ROLE_BODY"),
    }

    def _run_main(self, manifest_path: Path, current: list[dict]) -> int:
        with (
            mock.patch.object(migrator, "MANIFEST", manifest_path),
            mock.patch.object(migrator.inventory, "collect_raw", return_value=current),
            mock.patch.object(migrator.inventory, "validate", return_value=[]),
        ):
            return migrator.main()

    def test_exact_main_path_passes_without_rewriting_manifest(self) -> None:
        with tempfile.TemporaryDirectory(prefix="scrum1087-") as temp_dir:
            manifest = Path(temp_dir) / "typography_inventory.json"
            original = json.dumps({
                "schema": 3,
                "migration_task": "SCRUM-1073",
                "entries": [_reviewed_entry()],
                "migrations": [],
            }, ensure_ascii=False, indent=2).encode("utf-8") + b"\n"
            manifest.write_bytes(original)
            self.assertEqual(0, self._run_main(manifest, [_raw_entry(EXACT_SOURCE)]))
            self.assertEqual(original, manifest.read_bytes())

    def test_every_unknown_fingerprint_drift_fails_and_manifest_is_unchanged(self) -> None:
        for case, source in self.DRIFT_CASES.items():
            with self.subTest(case=case), tempfile.TemporaryDirectory(prefix="scrum1087-") as temp_dir:
                manifest = Path(temp_dir) / "typography_inventory.json"
                original = json.dumps({
                    "schema": 3,
                    "migration_task": "SCRUM-1073",
                    "entries": [_reviewed_entry()],
                    "migrations": [],
                }, ensure_ascii=False, indent=2).encode("utf-8") + b"\n"
                manifest.write_bytes(original)
                with self.assertRaisesRegex(SystemExit, "refusing to rewrite"):
                    self._run_main(manifest, [_raw_entry(source)])
                self.assertEqual(original, manifest.read_bytes(), case)

    def test_spaced_exponent_cannot_reconcile_or_rewrite_manifest(self) -> None:
        reviewed_source = EXACT_SOURCE.replace(", 16,", ", 1e-3,")
        split_exponent = reviewed_source.replace("1e-3", "1e - 3")
        with tempfile.TemporaryDirectory(prefix="scrum1087-") as temp_dir:
            manifest = Path(temp_dir) / "typography_inventory.json"
            original = json.dumps({
                "schema": 3,
                "migration_task": "SCRUM-1073",
                "entries": [_reviewed_entry(reviewed_source)],
                "migrations": [],
            }, ensure_ascii=False, indent=2).encode("utf-8") + b"\n"
            manifest.write_bytes(original)
            with self.assertRaisesRegex(SystemExit, "refusing to rewrite"):
                self._run_main(manifest, [_raw_entry(split_exponent)])
            self.assertEqual(original, manifest.read_bytes())

    def test_whitespace_only_reflow_preserves_review_and_updates_migration_fingerprint(self) -> None:
        whitespace_source = EXACT_SOURCE.replace(
            "add_theme_font_size_override(", "add_theme_font_size_override( ", 1
        )
        old_fingerprint = _raw_entry(EXACT_SOURCE)["fingerprint"]
        new_fingerprint = _raw_entry(whitespace_source)["fingerprint"]
        self.assertNotEqual(old_fingerprint, new_fingerprint)
        with tempfile.TemporaryDirectory(prefix="scrum1087-") as temp_dir:
            manifest = Path(temp_dir) / "typography_inventory.json"
            original_document = {
                "schema": 3,
                "migration_task": "SCRUM-1073",
                "entries": [_reviewed_entry()],
                "migrations": [{
                    "original_fingerprint": "original-site",
                    "replacement_fingerprint": old_fingerprint,
                    "disposition": "migrated_semantic_band",
                }],
            }
            original = json.dumps(original_document, ensure_ascii=False, indent=2).encode("utf-8") + b"\n"
            manifest.write_bytes(original)
            self.assertEqual(0, self._run_main(manifest, [_raw_entry(whitespace_source)]))
            updated = json.loads(manifest.read_text(encoding="utf-8"))
            self.assertNotEqual(original, manifest.read_bytes())
            self.assertEqual(new_fingerprint, updated["entries"][0]["fingerprint"])
            self.assertEqual("action", updated["entries"][0]["role"])
            self.assertEqual("mapped", updated["entries"][0]["status"])
            self.assertEqual(new_fingerprint, updated["migrations"][0]["replacement_fingerprint"])


if __name__ == "__main__":
    unittest.main()
