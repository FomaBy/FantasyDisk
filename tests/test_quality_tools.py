from __future__ import annotations

import importlib.util
import base64
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]


def _load_module(name: str, relative_path: str):
    spec = importlib.util.spec_from_file_location(name, ROOT / relative_path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class GodotGateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.gate = _load_module("godot_gate_tested", "tools/godot_gate.py")

    def test_project_path_variants(self) -> None:
        self.assertEqual(self.gate._project_path(["--headless", "--path", "/game"]), "/game")
        self.assertEqual(self.gate._project_path(["--path=/other"]), "/other")
        self.assertEqual(self.gate._project_path([]), ".")

    def test_godot_environment_precedence(self) -> None:
        with mock.patch.dict(os.environ, {"GODOT_BIN": "/custom/godot", "GODOT": "/ignored"}, clear=False):
            with mock.patch.object(self.gate.shutil, "which", return_value=None):
                self.assertEqual(self.gate._resolve_godot(), "/custom/godot")

    def test_slot_lock_is_nonblocking(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "slot.lock"
            first = self.gate._SlotLock(path)
            second = self.gate._SlotLock(path)
            self.assertTrue(first.try_acquire())
            try:
                self.assertFalse(second.try_acquire())
            finally:
                first.release()
                second.release()
            self.assertTrue(second.try_acquire())
            second.release()

    def test_godot_process_timeout_is_terminal(self) -> None:
        with mock.patch.dict(os.environ, {"FSD_GODOT_RUN_TIMEOUT": "0.05"}, clear=False):
            code = self.gate._run_godot(
                [sys.executable, "-c", "import time; time.sleep(5)"]
            )
        self.assertEqual(code, 124)


class QualityGateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.quality = _load_module("quality_gate_tested", "tools/quality_gate.py")

    def test_discovers_direct_and_inherited_suites(self) -> None:
        names = {path.name for path in self.quality.discover_godot_tests()}
        self.assertGreaterEqual(len(names), 233)
        self.assertIn("runtime_smoke_test.gd", names)
        self.assertIn("gamepad_full_flow_smoke_test.gd", names)
        self.assertIn("runtime_smoke_ui_test.gd", names)

    def test_full_filter_and_skip_umbrella(self) -> None:
        selected = self.quality.select_godot_tests(
            "full", ["runtime_smoke"], "origin/dev", True
        )
        names = {path.stem for path in selected}
        self.assertNotIn("runtime_smoke_test", names)
        self.assertIn("runtime_smoke_ui_test", names)
        self.assertIn("runtime_smoke_combat_test", names)

    def test_secret_scanner_rejects_runtime_builtin(self) -> None:
        source = (ROOT / "scripts" / "feedback_reporter.gd").read_text(encoding="utf-8")
        forbidden_marker = "BUILTIN_WEBHOOK_" + "B64_PARTS"
        self.assertNotIn(forbidden_marker, source)
        self.assertEqual(self.quality._scan_client_secrets(), [])

    def test_secret_scanner_rejects_raw_and_renamed_base64_mutations(self) -> None:
        webhook = "https://discord.com/api/webhooks/123456789012345678/abcdefghijklmnopqrstuvwxyz_123456"
        raw_errors = self.quality._source_secret_errors("scripts/mutant.gd", webhook)
        self.assertTrue(raw_errors)
        encoded = base64.b64encode(webhook.encode("utf-8")).decode("ascii")
        split = [encoded[:31], encoded[31:67], encoded[67:]]
        mutant = "const RENAMED_PARTS = [%s]" % ", ".join(repr(part) for part in split)
        encoded_errors = self.quality._source_secret_errors("scripts/mutant.gd", mutant)
        self.assertTrue(encoded_errors)

    def test_windows_export_contract_is_present(self) -> None:
        self.assertEqual(self.quality._windows_export_config_errors(), [])

    def test_process_group_timeout_is_terminal(self) -> None:
        code, _output, timed_out = self.quality._run_captured(
            [sys.executable, "-c", "import time; time.sleep(5)"],
            os.environ.copy(),
            0.05,
        )
        self.assertTrue(timed_out)
        self.assertEqual(code, 124)

    def test_changed_profile_selects_changed_and_untracked_tests_with_runtime_fallback(self) -> None:
        changed = {
            "tests/weapon_integrity_test.gd",
            "tests/new_untracked_regression_test.gd",
            "scripts/unmapped_runtime_component.gd",
        }
        with mock.patch.object(self.quality, "_git_changed_paths", return_value=changed):
            selected = self.quality.select_godot_tests(
                "changed", [], "origin/dev", False
            )
        names = {path.stem for path in selected}
        self.assertIn("weapon_integrity_test", names)
        self.assertIn("runtime_smoke_test", names)


if __name__ == "__main__":
    unittest.main()
