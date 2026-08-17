from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
GUARD_PATH = ROOT / "tools" / "release_scope_guard.py"
SPEC = importlib.util.spec_from_file_location("release_scope_guard_tested", GUARD_PATH)
guard = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(guard)

ASSET_ENTRY = {
    "id": "polish-assets",
    "introduced_in": "0.3.1",
    "path": "assets/ui/polish",
}
FLAG_ENTRY = {
    "id": "polish-flag",
    "introduced_in": "0.3.1",
    "project_setting": "fantasydisk/polish_enabled",
}


def manifest(*entries: dict) -> dict:
    return {"schema": guard.MANIFEST_SCHEMA, "entries": list(entries)}


class ReleaseScopeManifestTests(unittest.TestCase):
    def test_shipped_manifest_satisfies_the_contract(self) -> None:
        shipped = json.loads(guard.MANIFEST_PATH.read_text(encoding="utf-8"))
        self.assertEqual(guard.manifest_errors(shipped), [])

    def test_malformed_entries_fail_closed(self) -> None:
        cases = {
            "bad-version": {"id": "a", "introduced_in": "0.3", "path": "x"},
            "no-target": {"id": "a", "introduced_in": "0.3.1"},
            "two-targets": {
                "id": "a",
                "introduced_in": "0.3.1",
                "path": "x",
                "project_setting": "y",
            },
            "traversal": {"id": "a", "introduced_in": "0.3.1", "path": "../x"},
            "absolute": {"id": "a", "introduced_in": "0.3.1", "path": "/x"},
            "unknown-key": {
                "id": "a",
                "introduced_in": "0.3.1",
                "path": "x",
                "intruduced_in": "0.3.1",
            },
            "empty-id": {"id": "", "introduced_in": "0.3.1", "path": "x"},
        }
        for name, entry in cases.items():
            with self.subTest(name):
                self.assertNotEqual(guard.manifest_errors(manifest(entry)), [])

    def test_duplicate_ids_and_wrong_schema_fail_closed(self) -> None:
        self.assertNotEqual(
            guard.manifest_errors(manifest(ASSET_ENTRY, dict(ASSET_ENTRY, path="other"))),
            [],
        )
        self.assertNotEqual(
            guard.manifest_errors({"schema": 999, "entries": []}), []
        )
        self.assertNotEqual(guard.manifest_errors({"schema": 1}), [])


class ReleaseScopeViolationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)

    def write_project(self, *settings: str) -> None:
        lines = ["[application]", 'config/version="0.3.0"', *settings]
        (self.root / "project.godot").write_text(
            "\n".join(lines) + "\n", encoding="utf-8"
        )

    def test_later_asset_is_rejected_from_an_earlier_build(self) -> None:
        self.write_project()
        (self.root / "assets" / "ui" / "polish").mkdir(parents=True)
        for version in ("0.3.0", "0.3.0.1"):
            with self.subTest(version):
                violations = guard.scope_violations(
                    manifest(ASSET_ENTRY), self.root, version
                )
                self.assertEqual(len(violations), 1, violations)
                self.assertIn("assets/ui/polish", violations[0])

    def test_later_asset_is_allowed_from_its_own_release_onwards(self) -> None:
        self.write_project()
        (self.root / "assets" / "ui" / "polish").mkdir(parents=True)
        for version in ("0.3.1", "0.3.2", "0.4.0"):
            with self.subTest(version):
                self.assertEqual(
                    guard.scope_violations(manifest(ASSET_ENTRY), self.root, version), []
                )

    def test_absent_later_content_is_not_a_violation(self) -> None:
        self.write_project()
        self.assertEqual(
            guard.scope_violations(manifest(ASSET_ENTRY, FLAG_ENTRY), self.root, "0.3.0"),
            [],
        )

    def test_later_feature_flag_is_rejected_from_an_earlier_build(self) -> None:
        self.write_project("fantasydisk/polish_enabled=true")
        violations = guard.scope_violations(manifest(FLAG_ENTRY), self.root, "0.3.0")
        self.assertEqual(len(violations), 1, violations)
        self.assertIn("fantasydisk/polish_enabled", violations[0])
        self.assertEqual(
            guard.scope_violations(manifest(FLAG_ENTRY), self.root, "0.3.1"), []
        )

    def test_commented_out_feature_flag_is_not_a_violation(self) -> None:
        self.write_project(";fantasydisk/polish_enabled=true")
        self.assertEqual(
            guard.scope_violations(manifest(FLAG_ENTRY), self.root, "0.3.0"), []
        )


class ReleaseScopeGuardCliTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / "project.godot").write_text(
            '[application]\nconfig/version="0.3.0"\n', encoding="utf-8"
        )
        self.manifest_path = self.root / "manifest.json"

    def run_guard(self, version: str) -> subprocess.CompletedProcess:
        return subprocess.run(
            [
                sys.executable,
                str(GUARD_PATH),
                "--version",
                version,
                "--root",
                str(self.root),
                "--manifest",
                str(self.manifest_path),
            ],
            capture_output=True,
            text=True,
        )

    def test_cli_exit_codes_match_the_verdict(self) -> None:
        self.manifest_path.write_text(json.dumps(manifest(ASSET_ENTRY)), encoding="utf-8")
        self.assertEqual(self.run_guard("0.3.0").returncode, 0)

        (self.root / "assets" / "ui" / "polish").mkdir(parents=True)
        blocked = self.run_guard("0.3.0")
        self.assertEqual(blocked.returncode, 2)
        self.assertIn("polish-assets", blocked.stdout)
        self.assertEqual(self.run_guard("0.3.1").returncode, 0)

    def test_cli_rejects_a_malformed_manifest_and_a_malformed_version(self) -> None:
        self.manifest_path.write_text("{ not json", encoding="utf-8")
        self.assertNotEqual(self.run_guard("0.3.0").returncode, 0)

        self.manifest_path.write_text(json.dumps(manifest(ASSET_ENTRY)), encoding="utf-8")
        self.assertNotEqual(self.run_guard("0.3").returncode, 0)


if __name__ == "__main__":
    unittest.main()
