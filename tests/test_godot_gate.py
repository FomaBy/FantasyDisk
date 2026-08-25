import contextlib
import importlib.util
import io
import os
import subprocess
import sys
import tempfile
import threading
import time
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

    @staticmethod
    def _timed_command(log_path: Path, label: str, duration: float) -> str:
        return (
            "import time; "
            f"log_path = {str(log_path)!r}; label = {label!r}; "
            "log = open(log_path, 'a', encoding='utf-8'); "
            "log.write(f'{label} start {time.time_ns()}\\n'); log.flush(); log.close(); "
            f"time.sleep({duration}); "
            "log = open(log_path, 'a', encoding='utf-8'); "
            "log.write(f'{label} end {time.time_ns()}\\n'); log.flush(); log.close()"
        )

    @staticmethod
    def _read_intervals(log_path: Path) -> dict[str, dict[str, int]]:
        intervals: dict[str, dict[str, int]] = {}
        for line in log_path.read_text(encoding="utf-8").splitlines():
            label, event, timestamp = line.split()
            intervals.setdefault(label, {})[event] = int(timestamp)
        return intervals

    def _wait_for_event(self, log_path: Path, label: str, event: str) -> None:
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if log_path.exists():
                intervals = self._read_intervals(log_path)
                if event in intervals.get(label, {}):
                    return
            time.sleep(0.02)
        self.fail(f"timed out waiting for {label} {event}")

    @staticmethod
    def _gate_environment(tmpdir: Path, sem_dir: Path, **updates: str) -> dict[str, str]:
        # sem_dir is mandatory: without an explicit override a child falls back to
        # the machine-wide default and contends with unrelated gated Godot runs.
        env = os.environ.copy()
        env.pop("FSD_GODOT_EXCLUSIVE", None)
        env.pop("FSD_GODOT_BYPASS_ON_TIMEOUT", None)
        env.pop("FSD_GODOT_RUN_TIMEOUT", None)
        env.update(
            {
                "TMPDIR": str(tmpdir),
                "FSD_GODOT_SEM_DIR": str(sem_dir),
                "GODOT_BIN": sys.executable,
                "FSD_GODOT_MAXWAIT": "10",
                "FSD_GODOT_SLOTS": "1",
                **updates,
            }
        )
        return env

    @staticmethod
    def _start_gate(env: dict[str, str], command: str) -> subprocess.Popen[bytes]:
        return subprocess.Popen(
            [sys.executable, str(MODULE_PATH), "-c", command],
            env=env,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
        )

    @staticmethod
    def _wait_for_gate(process: subprocess.Popen[bytes]) -> tuple[int, str]:
        code = process.wait(15)
        assert process.stderr is not None
        stderr = process.stderr.read().decode()
        process.stderr.close()
        return code, stderr

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

    def test_default_semaphore_dir_ignores_task_tmpdir_and_override_wins(self):
        with tempfile.TemporaryDirectory() as first_tmp, tempfile.TemporaryDirectory() as second_tmp:
            with mock.patch.dict(
                os.environ,
                {"TMPDIR": first_tmp, "FSD_GODOT_SEM_DIR": ""},
                clear=False,
            ):
                first = self.module._semaphore_dir()
            with mock.patch.dict(
                os.environ,
                {"TMPDIR": second_tmp, "FSD_GODOT_SEM_DIR": ""},
                clear=False,
            ):
                second = self.module._semaphore_dir()
            self.assertEqual(first, second)

            override = Path(first_tmp) / "custom-semaphore"
            with mock.patch.dict(
                os.environ,
                {"TMPDIR": second_tmp, "FSD_GODOT_SEM_DIR": str(override)},
                clear=False,
            ):
                self.assertEqual(self.module._semaphore_dir(), override)

    def test_separate_task_tmpdirs_share_one_slot_without_godot(self):
        with tempfile.TemporaryDirectory() as root:
            root_path = Path(root)
            log_path = root_path / "intervals.log"
            sem_dir = root_path / "semaphore"
            first_env = self._gate_environment(root_path / "task-one", sem_dir)
            second_env = self._gate_environment(root_path / "task-two", sem_dir)
            first = self._start_gate(
                first_env,
                self._timed_command(log_path, "first", 0.5),
            )
            second = None
            try:
                self._wait_for_event(log_path, "first", "start")
                second = self._start_gate(
                    second_env,
                    self._timed_command(log_path, "second", 0.1),
                )
                first_code, first_stderr = self._wait_for_gate(first)
                second_code, second_stderr = self._wait_for_gate(second)
                self.assertEqual(first_code, 0, first_stderr)
                self.assertEqual(second_code, 0, second_stderr)
            finally:
                if first.poll() is None:
                    first.kill()
                    first.wait()
                if second is not None and second.poll() is None:
                    second.kill()
                    second.wait()
            intervals = self._read_intervals(log_path)
            self.assertLessEqual(intervals["first"]["end"], intervals["second"]["start"])

    def test_exclusive_run_blocks_runs_with_other_slot_counts(self):
        with tempfile.TemporaryDirectory() as root:
            root_path = Path(root)
            log_path = root_path / "intervals.log"
            sem_dir = root_path / "semaphore"
            normal = self._start_gate(
                self._gate_environment(
                    root_path / "normal", sem_dir, FSD_GODOT_SLOTS="3"
                ),
                self._timed_command(log_path, "normal", 0.5),
            )
            exclusive = None
            try:
                self._wait_for_event(log_path, "normal", "start")
                exclusive = self._start_gate(
                    self._gate_environment(
                        root_path / "exclusive",
                        sem_dir,
                        FSD_GODOT_EXCLUSIVE="1",
                    ),
                    self._timed_command(log_path, "exclusive", 0.1),
                )
                normal_code, normal_stderr = self._wait_for_gate(normal)
                exclusive_code, exclusive_stderr = self._wait_for_gate(exclusive)
                self.assertEqual(normal_code, 0, normal_stderr)
                self.assertEqual(exclusive_code, 0, exclusive_stderr)
            finally:
                if normal.poll() is None:
                    normal.kill()
                    normal.wait()
                if exclusive is not None and exclusive.poll() is None:
                    exclusive.kill()
                    exclusive.wait()
            intervals = self._read_intervals(log_path)
            self.assertLessEqual(intervals["normal"]["end"], intervals["exclusive"]["start"])

    def test_killed_slot_owner_does_not_block_next_gate_run(self):
        with tempfile.TemporaryDirectory() as tmp:
            sem_dir = Path(tmp) / "semaphore"
            sem_dir.mkdir()
            holder_code = (
                "import runpy, sys, time; "
                "module = runpy.run_path(sys.argv[1]); "
                "lock = module['_SlotLock'](module['Path'](sys.argv[2]) / 'slot0.lock'); "
                "assert lock.try_acquire(); print('locked', flush=True); time.sleep(60)"
            )
            holder = subprocess.Popen(
                [sys.executable, "-c", holder_code, str(MODULE_PATH), str(sem_dir)],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
            )
            try:
                assert holder.stdout is not None
                self.assertEqual(holder.stdout.readline().strip(), "locked")
                holder.kill()
                holder.wait(10)
                completed = subprocess.run(
                    [sys.executable, str(MODULE_PATH), "-c", "pass"],
                    env=self._gate_environment(Path(tmp), sem_dir),
                    capture_output=True,
                    timeout=15,
                )
                self.assertEqual(completed.returncode, 0, completed.stderr.decode())
            finally:
                if holder.poll() is None:
                    holder.kill()
                    holder.wait()
                if holder.stdout is not None:
                    holder.stdout.close()

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
        with tempfile.TemporaryDirectory() as tmp:
            with mock.patch.dict(
                os.environ,
                {
                    "FSD_GODOT_SEM_DIR": tmp,
                    "FSD_GODOT_SLOTS": "1",
                    "FSD_GODOT_MAXWAIT": "0",
                },
                clear=False,
            ):
                with mock.patch.object(self.module, "_resolve_godot", return_value=""):
                    self.assertEqual(self.module.main([]), 127)

    def test_import_prepass_does_not_enable_fatal_output_detection(self):
        # Contain the real pre-pass announcement: the literal line is a counted
        # log contract (exactly one cold emission), so a leak from this suite
        # would double it in every certifying run.
        captured_stderr = io.StringIO()
        with mock.patch.object(self.module, "_needs_import_cache", side_effect=[True, False]):
            with mock.patch.object(self.module, "_run_godot", return_value=0) as run:
                with contextlib.redirect_stderr(captured_stderr):
                    self.assertEqual(
                        self.module._ensure_import_cache(["--path", "/repo"], "/godot"),
                        0,
                    )
        self.assertEqual(run.call_args_list[0], mock.call(
            ["/godot", "--headless", "--path", "/repo", "--import", "--quit"]
        ))
        self.assertIn(
            "godot_gate: import cache missing, running headless import first",
            captured_stderr.getvalue(),
        )

    def test_import_cache_requires_the_player_texture_artifacts(self):
        """A stray import must not let a clean checkout skip its real import."""
        with tempfile.TemporaryDirectory() as tmp:
            project = Path(tmp)
            imported = project / ".godot" / "imported"
            imported.mkdir(parents=True)
            (project / ".godot" / "global_script_class_cache.cfg").touch()
            (imported / "unrelated.ctex").touch()
            self.assertTrue(
                self.module._needs_import_cache(["--path", str(project)], require_script=False)
            )

    def test_import_prepass_rechecks_artifacts_and_loads_player(self):
        with mock.patch.object(self.module, "_needs_import_cache", side_effect=[True, False]):
            with mock.patch.object(self.module, "_run_godot", side_effect=[0, 0]) as run:
                self.assertEqual(
                    self.module._ensure_import_cache(["--path", "/repo"], "/godot"),
                    0,
                )
        self.assertEqual(
            run.call_args_list,
            [
                mock.call(["/godot", "--headless", "--path", "/repo", "--import", "--quit"]),
                mock.call(
                    [
                        "/godot", "--headless", "--path", "/repo", "--script",
                        "res://tests/import_cache_player_load_test.gd",
                    ],
                    fail_on_fatal_output=True,
                ),
            ],
        )

    def test_forced_import_check_still_loads_player_when_cache_is_complete(self):
        with mock.patch.object(self.module, "_needs_import_cache", return_value=False):
            with mock.patch.object(self.module, "_run_godot", return_value=0) as run:
                self.assertEqual(
                    self.module._ensure_import_cache(
                        ["--path", "/repo"], "/godot", force=True
                    ),
                    0,
                )
        run.assert_called_once_with(
            [
                "/godot", "--headless", "--path", "/repo", "--script",
                "res://tests/import_cache_player_load_test.gd",
            ],
            fail_on_fatal_output=True,
        )

    def test_ensure_import_cache_only_skips_the_requested_godot_command(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = {
                "FSD_GODOT_SEM_DIR": tmp,
                "FSD_GODOT_SLOTS": "1",
                "FSD_GODOT_MAXWAIT": "0",
            }
            with mock.patch.dict(os.environ, env, clear=False):
                with mock.patch.object(
                    self.module, "_resolve_godot", return_value=sys.executable
                ):
                    with mock.patch.object(
                        self.module, "_ensure_import_cache", return_value=0
                    ) as ensure_import:
                        with mock.patch.object(self.module, "_run_godot") as run:
                            self.assertEqual(
                                self.module.main([
                                    "--headless",
                                    "--path",
                                    "/repo",
                                    "--ensure-import-cache",
                                ]),
                                0,
                            )
        ensure_import.assert_called_once_with(
            ["--headless", "--path", "/repo"], sys.executable, force=True
        )
        run.assert_not_called()

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
