import contextlib
import importlib.util
import io
import os
import sys
import tempfile
import threading
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools" / "godot_gate.py"
QUALITY_MODULE_PATH = ROOT / "tools" / "quality_gate.py"


def load_module():
    spec = importlib.util.spec_from_file_location("godot_gate_under_test", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class GodotGateTest(unittest.TestCase):
    def setUp(self):
        self.module = load_module()

    def test_project_path_forms(self):
        self.assertEqual(self.module._project_path(["--path", "/repo", "--headless"]), "/repo")
        self.assertEqual(self.module._project_path(["--path=/other"]), "/other")
        self.assertEqual(self.module._project_path([]), ".")

    def test_lock_exclusion_and_release_on_current_platform(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "slot.lock"
            first = path.open("a+b")
            second = path.open("a+b")
            try:
                self.module._prepare_lock_file(first)
                self.module._prepare_lock_file(second)
                self.assertTrue(self.module._try_lock(first))
                self.assertFalse(self.module._try_lock(second))
                self.module._unlock(first)
                self.assertTrue(self.module._try_lock(second))
                self.module._unlock(second)
            finally:
                first.close()
                second.close()

    def test_disposable_parse_error_is_fail_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            script = Path(tmp) / "parse_error.gd"
            script.write_text(
                "extends SceneTree\n\nfunc _init() -> void:\n\tvar broken :=\n",
                encoding="utf-8",
            )
            stub = (
                "import pathlib, sys; "
                "source = pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'); "
                "assert 'var broken :=' in source; "
                "sys.stderr.write('SCRIPT ERROR: Parse Error: expected expression\\n"
                "ERROR: Failed to load script res://parse_error.gd with error Parse error\\n')"
            )
            with mock.patch.dict(
                os.environ, {"FSD_GODOT_RUN_TIMEOUT": "10"}, clear=False
            ):
                with contextlib.redirect_stdout(io.StringIO()):
                    code = self.module._run_godot(
                        [sys.executable, "-c", stub, str(script)],
                        fail_on_fatal_output=True,
                    )
        self.assertEqual(code, 3)

    def test_exact_fatal_literals_return_diagnostic_exit(self):
        stub = (
            "import sys; sys.stderr.write(sys.argv[1]); "
            "raise SystemExit(int(sys.argv[2]))"
        )
        cases = (
            ("SCRIPT ERROR", "SCRIPT ERROR: Parse Error\n"),
            ("FATAL", "fatal: engine failure\n"),
            ("Failed to load script", "ERROR: Failed to load script res://bad.gd\n"),
        )
        for name, output in cases:
            with self.subTest(name=name):
                with contextlib.redirect_stdout(io.StringIO()):
                    code = self.module._run_godot(
                        [sys.executable, "-c", stub, output, "0"],
                        fail_on_fatal_output=True,
                    )
                self.assertEqual(code, 3)

    def test_nonfatal_process_exit_status_is_preserved(self):
        with contextlib.redirect_stdout(io.StringIO()):
            code = self.module._run_godot(
                [sys.executable, "-c", "raise SystemExit(19)"],
                fail_on_fatal_output=True,
            )
        self.assertEqual(code, 19)

    def test_reserved_configuration_and_missing_binary_codes_are_preserved(self):
        with mock.patch.dict(
            os.environ, {"FSD_GODOT_RUN_TIMEOUT": "invalid"}, clear=False
        ):
            self.assertEqual(self.module._run_godot([sys.executable]), 2)
        with mock.patch.dict(
            os.environ,
            {
                "FSD_GODOT_SLOTS": "1",
                "FSD_GODOT_MAXWAIT": "0",
            },
            clear=False,
        ):
            with mock.patch.object(self.module, "_resolve_godot", return_value=""):
                self.assertEqual(self.module.main([]), 127)

    def test_import_prepass_does_not_enable_fatal_output_detection(self):
        with mock.patch.object(self.module, "_needs_import_cache", return_value=True):
            with mock.patch.object(self.module, "_run_godot", return_value=0) as run:
                self.assertEqual(
                    self.module._ensure_import_cache(["--path", "/repo"], "/godot"),
                    0,
                )
        run.assert_called_once_with(
            ["/godot", "--headless", "--path", "/repo", "--import", "--quit"]
        )

    def test_normal_and_bypass_execution_enable_fatal_output_detection(self):
        with tempfile.TemporaryDirectory() as tmp:
            common_env = {
                "FSD_GODOT_SEM_DIR": tmp,
                "FSD_GODOT_SLOTS": "1",
                "FSD_GODOT_MAXWAIT": "0",
                "FSD_GODOT_BYPASS_ON_TIMEOUT": "",
            }
            with mock.patch.dict(os.environ, common_env, clear=False):
                with mock.patch.object(
                    self.module, "_resolve_godot", return_value=sys.executable
                ):
                    with mock.patch.object(
                        self.module, "_ensure_import_cache", return_value=0
                    ):
                        with mock.patch.object(
                            self.module, "_run_godot", return_value=3
                        ) as run:
                            self.assertEqual(self.module.main(["--headless"]), 3)
            run.assert_called_once_with(
                [sys.executable, "--headless"],
                fail_on_fatal_output=True,
            )

            bypass_env = dict(common_env)
            bypass_env["FSD_GODOT_BYPASS_ON_TIMEOUT"] = "1"
            with mock.patch.dict(os.environ, bypass_env, clear=False):
                with mock.patch.object(
                    self.module, "_resolve_godot", return_value=sys.executable
                ):
                    with mock.patch.object(
                        self.module._SlotLock, "try_acquire", return_value=False
                    ):
                        with mock.patch.object(
                            self.module.time,
                            "monotonic",
                            side_effect=[10.0, 11.0],
                        ):
                            with mock.patch.object(
                                self.module, "_ensure_import_cache", return_value=0
                            ):
                                with mock.patch.object(
                                    self.module, "_run_godot", return_value=3
                                ) as run:
                                    self.assertEqual(
                                        self.module.main(["--headless"]),
                                        3,
                                    )
            run.assert_called_once_with(
                [sys.executable, "--headless"],
                fail_on_fatal_output=True,
            )

    def test_megabyte_output_is_streamed_without_deadlock(self):
        output_size = 1024 * 1024
        stub = (
            "import sys, time; "
            "sys.stdout.write('live output started\\n'); sys.stdout.flush(); "
            "time.sleep(0.2); "
            f"sys.stdout.write('x' * {output_size}); "
            "sys.stdout.write('\\nSCRIPT ERROR: late parse failure\\n')"
        )
        output_started = threading.Event()

        class LiveOutput(io.StringIO):
            def write(self, value):
                written = super().write(value)
                if "live output started" in value:
                    output_started.set()
                return written

        live_output = LiveOutput()
        result = []

        def run():
            result.append(
                self.module._run_godot(
                    [sys.executable, "-c", stub],
                    fail_on_fatal_output=True,
                )
            )

        with contextlib.redirect_stdout(live_output):
            runner = threading.Thread(target=run)
            runner.start()
            self.assertTrue(output_started.wait(5), "early output was not streamed live")
            self.assertTrue(runner.is_alive(), "output arrived only after process completion")
            runner.join(10)
        self.assertFalse(runner.is_alive(), "large captured output deadlocked the runner")
        self.assertEqual(result, [3])
        self.assertGreaterEqual(len(live_output.getvalue()), output_size)
        self.assertIn("SCRIPT ERROR: late parse failure", live_output.getvalue())

    def test_quality_gate_imports_the_shared_fatal_pattern(self):
        spec = importlib.util.spec_from_file_location(
            "quality_gate_shared_pattern_test", QUALITY_MODULE_PATH
        )
        quality = importlib.util.module_from_spec(spec)
        assert spec.loader is not None
        spec.loader.exec_module(quality)
        self.assertEqual(
            quality.FATAL_OUTPUT_RE.pattern,
            self.module.FATAL_OUTPUT_RE.pattern,
        )
        declaration = 're.compile(r"\\bSCRIPT ERROR\\b|\\bFATAL\\b"'
        sources = (
            MODULE_PATH.read_text(encoding="utf-8"),
            QUALITY_MODULE_PATH.read_text(encoding="utf-8"),
        )
        self.assertEqual(sum(source.count(declaration) for source in sources), 1)


if __name__ == "__main__":
    unittest.main()
