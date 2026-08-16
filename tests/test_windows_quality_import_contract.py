"""FAN-2648: native-Windows import-prepass command and completion contract.

``Godot 4.7 --headless --import --quit`` reproducibly crashes with
``0xc0000005`` on the native Windows runtime, while ``--import`` alone
completes the import cache and exits cleanly.  These contracts pin the
Windows prepass command construction (no crashing flag pair, gated
lifecycle, trailing cache validation) and its fail-closed completion
semantics.  They are pure and mocked, so every host certifies them.
"""
from __future__ import annotations

import contextlib
import importlib.util
import io
import os
import sys
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
# A Windows access violation surfaces as this unsigned process exit code.
WINDOWS_ACCESS_VIOLATION = 0xC0000005


def _load_quality_gate():
    spec = importlib.util.spec_from_file_location(
        "quality_gate_windows_import_contract", ROOT / "tools" / "quality_gate.py"
    )
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class WindowsImportCommandContractTests(unittest.TestCase):
    """The Windows prepass must never rebuild the crashing flag pair."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.quality = _load_quality_gate()

    def test_windows_import_step_uses_supported_lifecycle(self) -> None:
        commands = self.quality._import_prepass_commands("nt")
        self.assertEqual(len(commands), 2)
        import_step, validate_step = commands
        self.assertEqual(import_step[:2], [sys.executable, str(self.quality.GODOT_GATE)])
        self.assertIn("--headless", import_step)
        self.assertIn("--import", import_step)
        self.assertNotIn("--quit", import_step)
        self.assertNotIn("--ensure-import-cache", import_step)
        self.assertEqual(validate_step[:2], [sys.executable, str(self.quality.GODOT_GATE)])
        self.assertIn("--ensure-import-cache", validate_step)
        # With `--import` present godot_gate would skip its cache check and
        # rubber-stamp an incomplete import, so the validation step bans it.
        self.assertNotIn("--import", validate_step)

    def test_no_host_command_carries_the_crashing_flag_pair(self) -> None:
        for host in ("nt", "posix"):
            for command in self.quality._import_prepass_commands(host):
                with self.subTest(host=host, command=command):
                    self.assertNotIn("--quit", command)

    def test_posix_prepass_command_is_unchanged(self) -> None:
        self.assertEqual(
            self.quality._import_prepass_commands("posix"),
            [[
                sys.executable,
                str(self.quality.GODOT_GATE),
                "--headless",
                "--path",
                str(self.quality.ROOT),
                "--ensure-import-cache",
            ]],
        )


class WindowsImportCompletionContractTests(unittest.TestCase):
    """Crash, timeout or incomplete cache must stay terminal failures."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.quality = _load_quality_gate()

    def _run_import(self, step_results: list[tuple[int, str, bool]]):
        with mock.patch.object(
            self.quality,
            "_import_prepass_commands",
            return_value=[["step-import"], ["step-validate"]],
        ):
            with mock.patch.object(
                self.quality, "_run_captured", side_effect=step_results
            ) as run_captured:
                with contextlib.redirect_stdout(io.StringIO()):
                    with contextlib.redirect_stderr(io.StringIO()):
                        result = self.quality.run_godot_import(30.0)
        return result, run_captured

    def test_clean_import_and_complete_cache_pass(self) -> None:
        result, run_captured = self._run_import([(0, "", False), (0, "", False)])
        self.assertEqual(result["status"], "passed")
        self.assertEqual(result["exit_code"], 0)
        self.assertFalse(result["timed_out"])
        self.assertEqual(run_captured.call_count, 2)
        self.assertEqual(run_captured.call_args_list[0].args[0], ["step-import"])
        self.assertEqual(run_captured.call_args_list[1].args[0], ["step-validate"])

    def test_access_violation_fails_closed_and_stops(self) -> None:
        result, run_captured = self._run_import(
            [(WINDOWS_ACCESS_VIOLATION, "crash", False)]
        )
        self.assertEqual(result["status"], "failed")
        self.assertEqual(result["exit_code"], WINDOWS_ACCESS_VIOLATION)
        # A crashed import is terminal: the validation step must never run.
        self.assertEqual(run_captured.call_count, 1)

    def test_import_timeout_fails_closed(self) -> None:
        result, run_captured = self._run_import([(124, "", True)])
        self.assertEqual(result["status"], "failed")
        self.assertTrue(result["timed_out"])
        self.assertEqual(run_captured.call_count, 1)

    def test_captured_output_survives_utf8_engine_text_on_any_locale(self) -> None:
        # Godot prints UTF-8 (Cyrillic import progress on a Russian host).
        # Locale-codec strict decoding used to kill the capture thread on the
        # first such byte pair, truncating the output that the push_error and
        # fatal-diagnostic verdicts read.  The marker after the Cyrillic line
        # proves capture continues past it.
        exit_code, output, timed_out = self.quality._run_captured(
            [
                sys.executable,
                "-c",
                "import sys;"
                " sys.stdout.buffer.write("
                "'Инициализация проекта\\n'.encode('utf-8'));"
                " sys.stdout.buffer.write(b'MARKER-AFTER-UTF8\\n');"
                " sys.stdout.buffer.flush()",
            ],
            os.environ.copy(),
            120.0,
        )
        self.assertEqual(exit_code, 0, output)
        self.assertFalse(timed_out)
        self.assertIn("MARKER-AFTER-UTF8", output)

    def test_incomplete_cache_validation_fails_closed(self) -> None:
        missing = self.quality.IMPORT_CACHE_MISSING_MESSAGE
        result, _run_captured = self._run_import(
            [(0, "", False), (1, f"{missing}\n", False)]
        )
        self.assertEqual(result["status"], "failed")
        self.assertEqual(result["exit_code"], 1)


if __name__ == "__main__":
    unittest.main()
