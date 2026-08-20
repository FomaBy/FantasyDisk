from __future__ import annotations

import contextlib
import importlib.util
import base64
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / ".github" / "workflows" / "quality.yml"


def _pinned_engine_build_id() -> str:
    """The exact engine build CI certifies with, read from the single pin."""
    match = re.search(
        r'^\s*GODOT_BUILD_ID:\s*"([^"]+)"',
        WORKFLOW.read_text(encoding="utf-8"),
        re.MULTILINE,
    )
    assert match is not None, "GODOT_BUILD_ID pin missing from quality.yml"
    return match.group(1)


# FAN-1700: verbatim shapes captured from Godot 4.7 headless runs on origin/dev.
# A suite announces its own failure with `push_error()`, which prints an
# `ERROR:` line plus an `at: push_error (` frame; the engine prints `ERROR:`
# lines of its own that mean nothing for the verdict.
BENIGN_ENGINE_OUTPUT = """Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org
ERROR: Parameter "t" is null.
   at: texture_2d_get (./servers/rendering/dummy/storage/texture_storage.h:110)
   GDScript backtrace (most recent call first):
       [0] _test_hero_select_radar_no_overlap_layouts (res://tests/runtime_smoke_test.gd:7412)
ERROR: Error calling deferred method: 'RefCounted(ui_screens.gd)::_hide_shop_gold_tooltip_if_inactive': Cannot convert argument 1 from Object to Object.
   at: _call_function (core/object/message_queue.cpp:220)
Runtime smoke test passed.
"""
REPORTED_FAILURE_OUTPUT = """Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org
ERROR: Expected secret boss flow to unlock after the final act (FAN-1700 demo).
   at: push_error (core/variant/variant_utility.cpp:1023)
   GDScript backtrace (most recent call first):
       [0] _fail (res://tests/runtime_smoke_test.gd:9203)
       [1] _test_secret_boss_after_final_act_flow (res://tests/runtime_smoke_test.gd:9186)
Runtime smoke test passed.
"""


def _gdscript_func_body(source: str, name: str) -> str:
    lines = source.splitlines()
    starts = [index for index, line in enumerate(lines) if line.startswith(f"func {name}(")]
    assert len(starts) == 1, f"expected exactly one func {name}(), found {len(starts)}"
    body: list[str] = []
    for line in lines[starts[0] + 1:]:
        if line and not line.startswith((" ", "\t")):
            break
        body.append(line)
    return "\n".join(body)


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

    def _captured_shell_exclusive_flag(self, shell: str, command: str) -> str:
        """Run one shell call with a fake Godot launcher and capture its env."""
        with tempfile.TemporaryDirectory(prefix="quality-shell-gate-") as scratch:
            scratch_path = Path(scratch)
            fake_bin = scratch_path / "bin"
            fake_bin.mkdir()
            captured = scratch_path / "exclusive.txt"
            fake_python = fake_bin / "python3"
            fake_python.write_text(
                "#!/bin/sh\nprintf '%s' \"${FSD_GODOT_EXCLUSIVE-__unset__}\" "
                '> "$FSD_CAPTURE"\n',
                encoding="utf-8",
            )
            fake_python.chmod(0o755)
            environment = os.environ | {
                "FSD_GODOT_EXCLUSIVE": "1",
                "FSD_CAPTURE": str(captured),
                "GODOT_PATH": "/mock/Godot",
                "PATH": f"{fake_bin}{os.pathsep}{os.environ['PATH']}",
                "WORKTREE_DIR": str(scratch_path),
            }
            completed = subprocess.run(
                [shell, "-c", command],
                cwd=ROOT,
                env=environment,
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr)
            self.assertTrue(captured.exists(), completed.stderr)
            return captured.read_text(encoding="utf-8")

    def _use_synthetic_tree(self, stack: contextlib.ExitStack, files: dict[str, str]) -> Path:
        root = Path(stack.enter_context(tempfile.TemporaryDirectory(prefix="quality-tree-")))
        for relative, content in files.items():
            path = root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")
        stack.enter_context(mock.patch.object(self.quality, "ROOT", root))
        stack.enter_context(mock.patch.object(self.quality, "TEST_DIR", root / "tests"))
        return root

    def test_discovers_nested_godot_suites(self) -> None:
        with contextlib.ExitStack() as stack:
            self._use_synthetic_tree(stack, {
                "tests/flat_test.gd": "extends SceneTree\n",
                "tests/ultimates/registry_contract_test.gd": "extends SceneTree\n",
                "tests/ultimates/registry_validator_test.gd":
                    'extends "res://tests/ultimates/registry_contract_test.gd"\n',
                "tests/ultimates/notes.md": "not a suite\n",
            })
            discovered = {
                path.name for path in self.quality.discover_godot_tests()
            }
            selected = {
                path.name
                for path in self.quality.select_godot_tests("full", [], "origin/dev", False)
            }
        self.assertEqual(
            discovered,
            {"flat_test.gd", "registry_contract_test.gd", "registry_validator_test.gd"},
        )
        self.assertEqual(discovered, selected)

    def test_nested_suite_runs_from_its_own_resource_path(self) -> None:
        nested = ROOT / "tests" / "ultimates" / "registry_contract_test.gd"
        self.assertEqual(
            self.quality.script_resource_path(nested),
            "res://tests/ultimates/registry_contract_test.gd",
        )
        with mock.patch.object(
            self.quality, "_run_captured", return_value=(0, "", False)
        ) as run_captured:
            outcome = self.quality.run_godot_test(nested, 1.0)
        self.assertEqual(outcome["script"], "res://tests/ultimates/registry_contract_test.gd")
        self.assertIn(
            "res://tests/ultimates/registry_contract_test.gd", run_captured.call_args.args[0]
        )

    def test_import_prepass_runs_once_before_equal_per_suite_budgets(self) -> None:
        selected = [
            ROOT / "tests" / "a5_balance_report_integrity_test.gd",
            ROOT / "tests" / "runtime_smoke_test.gd",
        ]
        events: list[tuple[str, float]] = []

        def import_prepass(timeout: float) -> dict:
            events.append(("import", timeout))
            return {"name": "godot-import-cache", "status": "passed", "duration_seconds": 1.0}

        def godot_test(path: Path, timeout: float) -> dict:
            events.append((path.stem, timeout))
            return {"name": path.stem, "status": "passed", "duration_seconds": 1.0}

        with tempfile.TemporaryDirectory(prefix="quality-import-report-") as scratch:
            report = Path(scratch) / "report.json"
            with mock.patch.object(self.quality, "select_godot_tests", return_value=selected):
                with mock.patch.object(self.quality, "_worktree_status", return_value=[]):
                    with mock.patch.object(
                        self.quality, "run_godot_import", side_effect=import_prepass
                    ) as run_import:
                        with mock.patch.object(
                            self.quality, "run_godot_test", side_effect=godot_test
                        ):
                            code = self.quality.main([
                                "--profile",
                                "changed",
                                "--skip-static",
                                "--test-timeout",
                                "17",
                                "--import-timeout",
                                "23",
                                "--report",
                                str(report),
                            ])
            payload = json.loads(report.read_text(encoding="utf-8"))

        self.assertEqual(code, 0)
        run_import.assert_called_once_with(23.0)
        self.assertEqual(
            events,
            [
                ("import", 23.0),
                ("a5_balance_report_integrity_test", 17.0),
                ("runtime_smoke_test", 17.0),
            ],
        )
        self.assertEqual(payload["godot_test_timeout_seconds"], 17.0)
        self.assertEqual(payload["godot_import_timeout_seconds"], 23.0)
        self.assertEqual(payload["godot_import_prepass"]["status"], "passed")

    def test_import_timeout_reads_its_environment_override(self) -> None:
        with mock.patch.dict(os.environ, {"FSD_GODOT_IMPORT_TIMEOUT": "321"}, clear=False):
            args = self.quality._parse_args([])
        self.assertEqual(args.import_timeout, 321.0)

    def test_import_prepass_routes_through_godot_gate(self) -> None:
        with mock.patch.dict(
            os.environ, {"FSD_GODOT_EXCLUSIVE": "1"}, clear=False
        ):
            with mock.patch.object(
                self.quality, "_run_captured", return_value=(0, "", False)
            ) as run_captured:
                result = self.quality.run_godot_import(12.0)
        self.assertEqual(result["status"], "passed")
        command = run_captured.call_args.args[0]
        self.assertEqual(command[:2], [sys.executable, str(self.quality.GODOT_GATE)])
        self.assertIn("--ensure-import-cache", command)
        self.assertEqual(
            run_captured.call_args.args[1]["FSD_GODOT_EXCLUSIVE"],
            "",
        )

    def test_only_timing_sensitive_suites_request_machine_exclusive(self) -> None:
        expected_exclusive = {
            "res://tests/berserk_dps_runaway_gate.gd",
            "res://tests/live_balance_simulation_test.gd",
            "res://tests/pool_dot_runaway_gate.gd",
        }
        self.assertEqual(
            self.quality.TIMING_SENSITIVE_GODOT_SCRIPTS,
            expected_exclusive,
        )
        discovered = {
            self.quality.script_resource_path(path)
            for path in self.quality.discover_godot_tests()
        }
        self.assertTrue(
            expected_exclusive <= discovered,
            "each timing-sensitive resource must exist at its classified path",
        )
        cases = {
            ROOT / script.removeprefix("res://"): "1"
            for script in expected_exclusive
        }
        cases[ROOT / "tests" / "runtime_smoke_test.gd"] = ""
        with mock.patch.dict(
            os.environ, {"FSD_GODOT_EXCLUSIVE": "1"}, clear=False
        ):
            for path, expected in cases.items():
                with self.subTest(path=path.name):
                    with mock.patch.object(
                        self.quality, "_run_captured", return_value=(0, "", False)
                    ) as run_captured:
                        result = self.quality.run_godot_test(path, 1.0)
                    self.assertEqual(result["status"], "passed")
                    self.assertEqual(
                        run_captured.call_args.args[1]["FSD_GODOT_EXCLUSIVE"],
                        expected,
                    )

    def test_balance_runner_marks_only_live_timing_measurements_exclusive(self) -> None:
        source = (ROOT / "tools" / "run_balance_validation.sh").read_text(
            encoding="utf-8"
        )
        calls = [
            line.strip()
            for line in source.splitlines()
            if line.lstrip().startswith("run_gate ")
        ]
        timing_calls = [
            line for line in calls if line.startswith("run_gate --timing-sensitive ")
        ]
        self.assertEqual(len(timing_calls), 4)
        required_scripts = {
            "res://tests/live_balance_simulation_test.gd",
            "res://tests/berserk_dps_runaway_gate.gd",
            "res://tests/pool_dot_runaway_gate.gd",
            "res://tools/character_balance_csv.gd",
        }
        self.assertEqual(
            {
                script
                for script in required_scripts
                if any(script in line for line in timing_calls)
            },
            required_scripts,
        )
        sensitive_calls = [
            line
            for line in calls
            if any(script in line for script in required_scripts)
        ]
        self.assertEqual(sensitive_calls, timing_calls)
        live_csv_call = next(
            line
            for line in timing_calls
            if "res://tools/character_balance_csv.gd" in line
        )
        self.assertIn("--mode=live", live_csv_call)
        ordinary_calls = [line for line in calls if line not in timing_calls]
        self.assertTrue(ordinary_calls)
        self.assertFalse(
            any("--timing-sensitive" in line for line in ordinary_calls)
        )
        self.assertIn(
            'if [ "${1:-}" = "--timing-sensitive" ]; then\n'
            "\t\ttiming_sensitive=1",
            source,
        )
        self.assertIn(
            "if [ $timing_sensitive -eq 1 ]; then\n"
            "\t\tgate_env=(env FSD_GODOT_EXCLUSIVE=1)",
            source,
        )
        self.assertIn("gate_env=(env FSD_GODOT_EXCLUSIVE=1)", source)
        self.assertIn("gate_env=(env FSD_GODOT_EXCLUSIVE=)", source)
        self.assertEqual(
            source.count('"${gate_env[@]}" python3 tools/godot_gate.py'),
            2,
            "only run_gate uses gate_env; the import pre-pass owns its scrub inline",
        )

    @unittest.skipUnless(shutil.which("bash"), "bash is not available on this host")
    def test_balance_import_prepass_scrubs_inherited_exclusive_flag(self) -> None:
        source = (ROOT / "tools" / "run_balance_validation.sh").read_text(
            encoding="utf-8"
        )
        match = re.search(
            r"^.*python3 tools/godot_gate\.py --headless --path \. --import.*$",
            source,
            re.MULTILINE,
        )
        self.assertIsNotNone(match)
        assert match is not None
        command = match.group(0).split(" >", 1)[0]
        # The extracted call-site is plain POSIX, so it runs under bash rather
        # than the script's own zsh shebang, which CI runners do not carry.
        self.assertEqual(self._captured_shell_exclusive_flag("bash", command), "")

        # Mutation proof: removing this call-site scrub exposes the parent's flag.
        unsanitized = command.replace("env FSD_GODOT_EXCLUSIVE= ", "", 1)
        with self.assertRaises(AssertionError):
            self.assertEqual(self._captured_shell_exclusive_flag("bash", unsanitized), "")

    @unittest.skipUnless(shutil.which("bash"), "bash is not available on this host")
    def test_release_godot_helper_scrubs_inherited_exclusive_flag(self) -> None:
        source = (ROOT / "tools" / "build_release.sh").read_text(encoding="utf-8")
        match = re.search(
            r"^run_godot\(\) \{\n.*?^\}", source, re.MULTILINE | re.DOTALL
        )
        self.assertIsNotNone(match)
        assert match is not None
        command = f"{match.group(0)}\nrun_godot --headless --import --path ."
        self.assertEqual(self._captured_shell_exclusive_flag("bash", command), "")

        # Mutation proof: removing this helper scrub exposes the parent's flag.
        unsanitized = command.replace("env FSD_GODOT_EXCLUSIVE= ", "", 1)
        with self.assertRaises(AssertionError):
            self.assertEqual(self._captured_shell_exclusive_flag("bash", unsanitized), "")

    def test_ambiguous_test_names_across_directories_are_rejected(self) -> None:
        with contextlib.ExitStack() as stack:
            self._use_synthetic_tree(stack, {
                "tests/registry_contract_test.gd": "extends SceneTree\n",
                "tests/ultimates/registry_contract_test.gd": "extends SceneTree\n",
            })
            with self.assertRaises(RuntimeError) as raised:
                self.quality.select_godot_tests("full", [], "origin/dev", False)
        self.assertIn("registry_contract_test", str(raised.exception))

    def test_real_assassin_and_berserk_suites_are_unique_and_selected_once(self) -> None:
        expected = {
            ROOT / "tests" / "ultimates" / "assassin_balance_test.gd",
            ROOT / "tests" / "ultimates" / "mechanics" / "assassin_mechanics_balance_test.gd",
            ROOT / "tests" / "ultimates" / "berserk_balance_test.gd",
            ROOT / "tests" / "ultimates" / "mechanics" / "berserk_mechanics_balance_test.gd",
        }
        discovered = self.quality.discover_godot_tests()
        self.assertTrue(expected <= set(discovered))
        self.assertEqual(len(discovered), len({path.stem for path in discovered}))

        for changed_path, expected_path in (
            (
                "tests/ultimates/mechanics/assassin_mechanics_balance_test.gd",
                ROOT / "tests" / "ultimates" / "mechanics" / "assassin_mechanics_balance_test.gd",
            ),
            (
                "tests/ultimates/mechanics/berserk_mechanics_balance_test.gd",
                ROOT / "tests" / "ultimates" / "mechanics" / "berserk_mechanics_balance_test.gd",
            ),
        ):
            with self.subTest(changed_path=changed_path), mock.patch.object(
                self.quality, "_git_changed_paths", return_value={changed_path}
            ):
                changed_selected = self.quality.select_godot_tests(
                    "changed", [], "base", False
                )
            self.assertEqual(
                [path for path in changed_selected if path in expected],
                [expected_path],
            )
            self.assertEqual(
                self.quality.select_godot_tests(
                    "full", [expected_path.stem], "origin/dev", False
                ),
                [expected_path],
            )

    def test_python_discovery_covers_nested_directories(self) -> None:
        with contextlib.ExitStack() as stack:
            self._use_synthetic_tree(stack, {
                "tests/test_flat.py": "",
                "tests/ultimates/test_registry.py": "",
            })
            commands = dict(self.quality.python_unit_commands())
        self.assertEqual(set(commands), {"python-unit", "python-unit:tests/ultimates"})
        self.assertEqual(commands["python-unit"][-3:], ["tests", "-p", "test_*.py"])
        self.assertEqual(
            commands["python-unit:tests/ultimates"][-3:],
            ["tests/ultimates", "-p", "test_*.py"],
        )

    def test_package_subdirectory_is_not_discovered_twice(self) -> None:
        with contextlib.ExitStack() as stack:
            self._use_synthetic_tree(stack, {
                "tests/test_flat.py": "",
                "tests/package/__init__.py": "",
                "tests/package/test_inside_package.py": "",
                "tests/plain/test_outside_package.py": "",
            })
            commands = dict(self.quality.python_unit_commands())
        # `unittest discover -s tests` already descends into importable
        # packages; only the non-package directory needs its own root.
        self.assertEqual(set(commands), {"python-unit", "python-unit:tests/plain"})

    def test_every_repository_python_test_belongs_to_one_discovery_root(self) -> None:
        roots = self.quality.python_unit_discovery_roots()
        discovered = self.quality.discover_python_tests()
        self.assertTrue(discovered)
        for path in discovered:
            covering = [
                root for root in roots
                if self.quality._package_chain_reaches(root, path.parent)
            ]
            self.assertEqual(len(covering), 1, f"{path} covered by {covering}")
        nested = [path for path in discovered if path.parent != self.quality.TEST_DIR]
        self.assertTrue(nested, "repository must keep a nested suite guarding recursion")

    def test_nested_python_tests_actually_execute(self) -> None:
        with contextlib.ExitStack() as stack:
            root = self._use_synthetic_tree(stack, {
                "tests/ultimates/test_registry.py": (
                    "import unittest\n\n\n"
                    "class NestedTests(unittest.TestCase):\n"
                    "    def test_nested_suite_runs(self) -> None:\n"
                    "        self.assertTrue(True)\n"
                ),
            })
            command = self.quality.python_unit_commands()[0][1]
            completed = subprocess.run(
                command, cwd=root, text=True, check=False,
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            )
        self.assertEqual(completed.returncode, 0, completed.stdout)
        self.assertIn("test_nested_suite_runs", completed.stdout)
        self.assertIn("Ran 1 test", completed.stdout)

    def test_missing_python_tests_fail_closed_through_cli(self) -> None:
        # The guarantee is CLI-observable: a tree that still carries Godot
        # suites but no Python suite must exit 1 through `main()`, before any
        # static command runs.  Asserting an internal helper's return value
        # instead would pass even if `main()` stopped checking at all.
        with contextlib.ExitStack() as stack:
            tree = Path(stack.enter_context(
                tempfile.TemporaryDirectory(prefix="quality-godot-only-")
            ))
            (tree / "tests").mkdir()
            (tree / "tests" / "godot_only_test.gd").write_text(
                "extends SceneTree\n", encoding="utf-8"
            )
            report = tree / "report.json"
            stack.enter_context(mock.patch.object(self.quality, "TEST_DIR", tree / "tests"))
            code = self.quality.main(["--static-only", "--report", str(report)])
            payload = json.loads(report.read_text(encoding="utf-8"))
        self.assertEqual(code, 1)
        self.assertEqual(payload["status"], "failed")
        self.assertEqual(payload["discovered_godot_tests"], 1)
        self.assertEqual(payload["discovered_python_tests"], 0)
        discovery = next(
            item for item in payload["static_checks"] if item["name"] == "test-discovery"
        )
        self.assertEqual(discovery["status"], "failed")
        self.assertEqual(discovery["errors"], ["no Python tests discovered under tests/"])
        # The missing Python half alone is terminal, so the discovery verdict is
        # the only static check the run may report.
        self.assertEqual(
            [item["name"] for item in payload["static_checks"]], ["test-discovery"]
        )

    def test_zero_executed_python_tests_fail_closed(self) -> None:
        # A collected-but-empty suite is the other half of the guarantee, and it
        # cannot be spotted by the exit code: `unittest` reports "Ran 0 tests"
        # and still exits 0, so only the executed count fails the check.
        for name in dict(self.quality.python_unit_commands()):
            empty = self.quality._run_command(
                name,
                [sys.executable, "-c", "print('Ran 0 tests in 0.000s')"],
                10.0,
                expect_tests=True,
            )
            self.assertEqual(empty["exit_code"], 0)
            self.assertEqual(empty["executed_tests"], 0)
            self.assertEqual(empty["status"], "failed")
            self.assertEqual(empty["errors"], [f"{name} executed 0 tests"])

        populated = self.quality._run_command(
            "python-unit",
            [sys.executable, "-c", "print('Ran 4 tests in 0.010s')"],
            10.0,
            expect_tests=True,
        )
        self.assertEqual(populated["executed_tests"], 4)
        self.assertEqual(populated["status"], "passed")

    def _assert_python_unit_commands_are_guarded(
        self,
        files: dict[str, str],
        expected_names: set[str],
    ) -> None:
        with contextlib.ExitStack() as stack:
            self._use_synthetic_tree(stack, files)
            stack.enter_context(mock.patch.object(
                self.quality, "_scan_client_secrets", return_value=[]
            ))
            stack.enter_context(mock.patch.object(
                self.quality, "_windows_export_config_errors", return_value=[]
            ))
            with mock.patch.object(
                self.quality,
                "_run_command",
                return_value={"name": "stub", "status": "passed"},
            ) as run_command:
                self.quality.run_static_checks(False, 1.0, "origin/dev", 1.0)
            expected_commands = dict(self.quality.python_unit_commands())

        guarded = {
            call.args[0]: (call.args[1], call.kwargs.get("expect_tests"))
            for call in run_command.call_args_list
            if call.args[0].startswith("python-unit")
        }
        self.assertEqual(set(expected_commands), expected_names)
        self.assertEqual(set(guarded), set(expected_commands))
        self.assertEqual(
            {name: command for name, (command, _) in guarded.items()},
            expected_commands,
        )
        self.assertEqual(
            {name: expect_tests for name, (_, expect_tests) in guarded.items()},
            {name: True for name in expected_commands},
        )

    def test_every_python_unit_command_is_guarded_by_executed_count(self) -> None:
        # A fully package-backed tree needs only the root discovery command;
        # a non-package child needs its own command.  Both contracts must keep
        # every emitted command behind the executed-test count guard.
        topologies = {
            "root_only": (
                {
                    "tests/test_root.py": "",
                    "tests/tools/__init__.py": "",
                    "tests/tools/test_nested.py": "",
                },
                {"python-unit"},
            ),
            "root_and_nested": (
                {
                    "tests/test_root.py": "",
                    "tests/tools/test_nested.py": "",
                },
                {"python-unit", "python-unit:tests/tools"},
            ),
        }
        for topology, (files, expected_names) in topologies.items():
            with self.subTest(topology=topology):
                self._assert_python_unit_commands_are_guarded(files, expected_names)

    def test_empty_godot_selection_is_reported_as_failure(self) -> None:
        with tempfile.TemporaryDirectory(prefix="quality-empty-selection-") as scratch:
            report = Path(scratch) / "quality_gate_report.json"
            code = self.quality.main([
                "--profile", "full",
                "--skip-static",
                "--report", str(report),
                "no_such_suite_matches_this_filter",
            ])
            payload = json.loads(report.read_text(encoding="utf-8"))
        self.assertEqual(code, 1)
        self.assertEqual(payload["status"], "failed")
        self.assertEqual(payload["selected_godot_tests"], 0)
        discovery = next(
            item for item in payload["static_checks"] if item["name"] == "test-discovery"
        )
        self.assertEqual(discovery["status"], "failed")

    def test_static_profile_fails_closed_when_nothing_is_discovered(self) -> None:
        with contextlib.ExitStack() as stack:
            empty = Path(stack.enter_context(tempfile.TemporaryDirectory(prefix="quality-empty-")))
            report = empty / "report.json"
            stack.enter_context(mock.patch.object(self.quality, "TEST_DIR", empty / "tests"))
            code = self.quality.main(["--static-only", "--report", str(report)])
            payload = json.loads(report.read_text(encoding="utf-8"))
        self.assertEqual(code, 1)
        self.assertEqual(payload["status"], "failed")
        self.assertEqual(payload["discovered_godot_tests"], 0)
        self.assertEqual(payload["discovered_python_tests"], 0)
        discovery = next(
            item for item in payload["static_checks"] if item["name"] == "test-discovery"
        )
        self.assertEqual(discovery["status"], "failed")
        self.assertEqual(len(discovery["errors"]), 2)

    def test_list_mode_fails_closed_on_empty_selection(self) -> None:
        self.assertEqual(
            self.quality.main(["--profile", "full", "--list", "no_such_suite_filter"]), 1
        )
        self.assertEqual(self.quality.main(["--profile", "full", "--list"]), 0)

    def test_discovers_direct_and_inherited_suites(self) -> None:
        names = {path.name for path in self.quality.discover_godot_tests()}
        self.assertGreaterEqual(len(names), 233)
        self.assertIn("runtime_smoke_test.gd", names)
        self.assertIn("gamepad_full_flow_smoke_test.gd", names)
        self.assertIn("runtime_smoke_ui_test.gd", names)

    def test_static_profile_selects_no_godot_tests(self) -> None:
        # The static profile is the engine-free compatibility profile, so it is
        # only ever safe where no Godot toolchain exists.  A trigger that is
        # supposed to gate gameplay must use a profile that executes suites.
        self.assertEqual(
            self.quality.select_godot_tests("static", [], "origin/dev", False), []
        )

    def test_changed_profile_selects_core_and_diff_driven_suites(self) -> None:
        with mock.patch.object(
            self.quality, "_git_changed_paths", return_value={"scripts/enemy.gd"}
        ):
            names = {
                path.stem
                for path in self.quality.select_godot_tests("changed", [], "base", False)
            }
        self.assertLessEqual(self.quality.CORE_CHANGED_TESTS, names)
        self.assertIn("enemy_separation_behavior_test", names)
        self.assertIn(self.quality.RUNTIME_SMOKE, names)

    def test_changed_profile_selects_typography_inventory_suite_for_scanned_paths(self) -> None:
        cases = {
            "scripts/ui/ultimate_hud/ultimate_hud_widget.gd": True,
            "scenes/hud.tscn": True,
            "resources/ui.tres": True,
            "resources/ui.theme": True,
            "scripts/dev_console.gd": False,
            "scripts/ui/semantic_typography.gd": False,
            "docs/process/code_quality_and_performance.md": False,
        }
        for changed_path, expected in cases.items():
            with self.subTest(changed_path=changed_path), mock.patch.object(
                self.quality, "_git_changed_paths", return_value={changed_path}
            ):
                names = {
                    path.stem
                    for path in self.quality.select_godot_tests("changed", [], "base", False)
                }
            self.assertEqual(
                self.quality.TYPOGRAPHY_INVENTORY_TEST in names,
                expected,
            )

    def test_ultimate_executor_contract_paths_select_all_contract_regressions(self) -> None:
        expected = {
            "controller_runtime_test",
            "controller_player_integration_test",
            "executor_contract_audit_test",
        }
        for changed_path in (
            "scripts/ultimates/controller/ultimate_controller.gd",
            "scripts/ultimates/executors/ultimate_executor_library.gd",
        ):
            with self.subTest(changed_path=changed_path), mock.patch.object(
                self.quality, "_git_changed_paths", return_value={changed_path}
            ):
                names = {
                    path.stem
                    for path in self.quality.select_godot_tests("changed", [], "base", False)
                }
            self.assertLessEqual(expected, names)

    def test_offensive_cadence_and_balance_paths_select_focused_regressions(self) -> None:
        cases = {
            "scripts/attribute_contract.gd": {
                "attribute_ui_matrix_fan1927_test",
                "offensive_scaling_contract_test",
                "engineer_kit_test",
                "chemist_kit_test",
            },
            "scripts/stat_formulas.gd": {
                "stat_formulas_smoke_test",
                "damage_type_isolation_test",
                "offensive_scaling_contract_test",
            },
            "scripts/player.gd": {
                "attribute_consumability_fan1887_test",
                "engineer_kit_test",
                "chemist_kit_test",
                "pool_dot_runaway_gate",
            },
            "scripts/class_weapon.gd": {
                "engineer_kit_test",
                "chemist_kit_test",
                "persistent_hazard_contract_test",
                "pool_dot_runaway_gate",
            },
            "scripts/sentry_turret.gd": {"engineer_kit_test"},
            "scripts/status_effects.gd": {
                "chemist_kit_test",
                "persistent_hazard_contract_test",
                "pool_dot_runaway_gate",
            },
            "scripts/progression_data.gd": {
                "attribute_consumability_fan1887_test",
                "offensive_scaling_contract_test",
                "class_damage_table_3variants_test",
                "pool_dot_runaway_gate",
            },
            "scripts/progression_data_balance.gd": {
                "offensive_scaling_contract_test",
                "class_damage_table_3variants_test",
                "global_damage_balance_smoke_test",
            },
            "scripts/progression_data_weapons.gd": {
                "offensive_scaling_contract_test",
                "engineer_kit_test",
                "chemist_kit_test",
                "class_damage_table_3variants_test",
            },
            "scripts/meta_progression_tree_data.gd": {
                "offensive_scaling_contract_test"
            },
        }
        for changed_path, expected in cases.items():
            with self.subTest(changed_path=changed_path), mock.patch.object(
                self.quality, "_git_changed_paths", return_value={changed_path}
            ):
                names = {
                    path.stem
                    for path in self.quality.select_godot_tests("changed", [], "base", False)
                }
            self.assertLessEqual(expected, names)

    def test_defensive_paths_select_complete_unique_contract_group(self) -> None:
        expected = self.quality.DEFENSIVE_CONTRACT_TESTS
        self.assertEqual(expected, {
            "assassin_kit_test",
            "defensive_attribute_contract_fan1895_test",
            "robot_kit_test",
            "thief_kit_test",
        })
        synthetic_suites = [
            ROOT / "tests" / f"{name}.gd"
            for name in expected
        ]
        for changed_path in (
            "scripts/player.gd",
            "scripts/progression_data.gd",
            "scripts/progression_data_balance.gd",
        ):
            with self.subTest(changed_path=changed_path), mock.patch.object(
                self.quality, "discover_godot_tests", return_value=synthetic_suites
            ), mock.patch.object(
                self.quality, "_git_changed_paths", return_value={changed_path}
            ):
                selected_names = [
                    path.stem
                    for path in self.quality.select_godot_tests("changed", [], "base", False)
                ]
            self.assertEqual(selected_names, sorted(expected))
            self.assertEqual(len(selected_names), len(set(selected_names)))

    def test_class_package_paths_select_player_integration_regression(self) -> None:
        # A ready-package rollout under the class data/executor trees changes
        # Player-visible routing, so the certifying changed profile must select
        # the Player integration regression and the tracked-tween wall-time
        # completion/recast/cancel regression, alongside the package contracts.
        expected = self.quality.ULTIMATE_PACKAGE_CONTRACT_TESTS | {
            "controller_player_integration_test",
            "tracked_tween_natural_completion_test",
        }
        self.assertEqual(self.quality.ULTIMATE_CLASS_PACKAGE_TESTS, expected)
        for changed_path in (
            "data/ultimates/classes/biologist/biologist_spore_lens.json",
            "scripts/ultimates/classes/biologist/biologist_symbiote_seed.gd",
        ):
            with self.subTest(changed_path=changed_path), mock.patch.object(
                self.quality, "_git_changed_paths", return_value={changed_path}
            ):
                names = {
                    path.stem
                    for path in self.quality.select_godot_tests("changed", [], "base", False)
                }
            self.assertLessEqual(expected, names)
            self.assertIn("tracked_tween_natural_completion_test", names)

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

    def test_python_discovery_watchdog_allows_progress_and_kills_hang(self) -> None:
        with contextlib.ExitStack() as stack:
            cache = stack.enter_context(
                tempfile.TemporaryDirectory(prefix="quality-python-cache-")
            )
            tree = Path(stack.enter_context(
                tempfile.TemporaryDirectory(prefix="quality-python-discovery-")
            ))
            test_dir = tree / "tests"
            test_dir.mkdir()
            (test_dir / "test_progress.py").write_text(
                "import unittest\n\n\n"
                "class ProgressTests(unittest.TestCase):\n"
                "    def test_reports_progress(self) -> None:\n"
                "        print('discovery progress', flush=True)\n"
                "        self.assertTrue(True)\n",
                encoding="utf-8",
            )
            env = os.environ.copy()
            env["PYTHONPYCACHEPREFIX"] = cache
            env["QUALITY_WATCHDOG_TREE"] = str(tree)
            runner = (
                "import os, unittest; "
                "os.chdir(os.environ['QUALITY_WATCHDOG_TREE']); "
                "unittest.main(module=None, argv=["
                "'unittest', 'discover', '-v', '-s', 'tests', "
                "'-p', 'test_progress.py'])"
            )
            bounded_code, bounded_output, bounded_timeout = self.quality._run_captured(
                [
                    sys.executable,
                    "-u",
                    "-c",
                    runner,
                ],
                env,
                10.0,
                idle_timeout=1.0,
            )
        self.assertEqual(bounded_code, 0, bounded_output)
        self.assertFalse(bounded_timeout)
        self.assertIn("Ran ", bounded_output)

        hang_code, _hang_output, hang_timeout = self.quality._run_captured(
            [sys.executable, "-c", "import time; time.sleep(5)"],
            os.environ.copy(),
            5.0,
            idle_timeout=0.05,
        )
        self.assertTrue(hang_timeout)
        self.assertEqual(hang_code, 124)

    def test_watchdog_kills_pipe_holding_descendant_after_parent_exit(self) -> None:
        with tempfile.TemporaryDirectory(prefix="quality-descendant-") as scratch:
            marker = Path(scratch) / "descendant-survived"
            env = os.environ.copy()
            env["QUALITY_DESCENDANT_MARKER"] = str(marker)
            env["QUALITY_DESCENDANT_CODE"] = (
                "import os,time; time.sleep(2.0); "
                "open(os.environ['QUALITY_DESCENDANT_MARKER'], 'w').write('alive')"
            )
            parent = (
                "import os,subprocess,sys; "
                "child=subprocess.Popen([sys.executable, '-c', "
                "os.environ['QUALITY_DESCENDANT_CODE']]); "
                "print(f'parent-done child={child.pid}', flush=True)"
            )
            code, output, timed_out = self.quality._run_captured(
                [sys.executable, "-u", "-c", parent],
                env,
                0.5,
                idle_timeout=0.2,
            )
            child_match = re.search(r"child=(\d+)", output)
            self.assertIsNotNone(child_match, output)
            child_pid = int(child_match.group(1))

            def child_is_alive() -> bool:
                if os.name != "nt":
                    try:
                        os.kill(child_pid, 0)
                    except ProcessLookupError:
                        return False
                    except PermissionError:
                        return True
                    return True

                import ctypes
                from ctypes import wintypes

                kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
                kernel32.OpenProcess.argtypes = [
                    wintypes.DWORD,
                    wintypes.BOOL,
                    wintypes.DWORD,
                ]
                kernel32.OpenProcess.restype = wintypes.HANDLE
                kernel32.GetExitCodeProcess.argtypes = [
                    wintypes.HANDLE,
                    ctypes.POINTER(wintypes.DWORD),
                ]
                kernel32.GetExitCodeProcess.restype = wintypes.BOOL
                kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
                kernel32.CloseHandle.restype = wintypes.BOOL
                handle = kernel32.OpenProcess(0x1000, False, child_pid)
                if not handle:
                    return False
                exit_code = wintypes.DWORD()
                active = kernel32.GetExitCodeProcess(handle, ctypes.byref(exit_code))
                kernel32.CloseHandle(handle)
                return not active or exit_code.value == 259

            deadline = time.monotonic() + 1.0
            while child_is_alive() and time.monotonic() < deadline:
                time.sleep(0.01)
            descendant_survived = marker.exists()
            descendant_alive = child_is_alive()
            reader_alive = any(
                thread.name == "quality-output-reader" and thread.is_alive()
                for thread in self.quality.threading.enumerate()
            )

        self.assertEqual(code, 124)
        self.assertTrue(timed_out)
        self.assertIn("parent-done", output)
        self.assertFalse(descendant_survived)
        self.assertFalse(descendant_alive)
        self.assertFalse(reader_alive)

    def test_watchdog_accepts_parent_exit_after_descendant_closes_stdout(self) -> None:
        with tempfile.TemporaryDirectory(prefix="quality-descendant-control-") as scratch:
            env = os.environ.copy()
            env["QUALITY_DESCENDANT_CODE"] = (
                "import sys,time; sys.stdout.close(); sys.stderr.close(); time.sleep(0.05)"
            )
            parent = (
                "import os,subprocess,sys; "
                "subprocess.Popen([sys.executable, '-c', os.environ['QUALITY_DESCENDANT_CODE']]); "
                "print('parent-done', flush=True)"
            )
            code, output, timed_out = self.quality._run_captured(
                [sys.executable, "-u", "-c", parent],
                env,
                0.5,
                idle_timeout=0.2,
            )

        self.assertEqual(code, 0, output)
        self.assertIn("parent-done", output)
        self.assertFalse(timed_out)

    def test_python_unit_command_keeps_full_discovery(self) -> None:
        with mock.patch.object(
            self.quality,
            "_run_command",
            return_value={"name": "stub", "status": "passed"},
        ) as run_command:
            self.quality.run_static_checks(False, 1.0, "origin/dev", 1.0)
        python_command = next(
            call.args[1]
            for call in run_command.call_args_list
            if call.args[0] == "python-unit"
        )
        self.assertIn("discover", python_command)
        self.assertIn("-s", python_command)
        self.assertIn("tests", python_command)
        self.assertIn("-p", python_command)
        self.assertIn("test_*.py", python_command)

    def test_static_command_routes_python_cache_outside_checkout(self) -> None:
        with mock.patch.object(
            self.quality, "_run_captured", return_value=(0, "", False)
        ) as run_captured:
            result = self.quality._run_command("probe", [sys.executable, "--version"], 1.0)
        self.assertEqual(result["status"], "passed")
        cache_path = Path(run_captured.call_args.args[1]["PYTHONPYCACHEPREFIX"])
        self.assertFalse(cache_path.exists())

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

    def test_feedback_reporter_change_selects_lifecycle_regression(self) -> None:
        with mock.patch.object(
            self.quality,
            "_git_changed_paths",
            return_value={"scripts/feedback_reporter.gd"},
        ):
            selected = self.quality.select_godot_tests(
                "changed", [], "origin/dev", False
            )
        names = {path.stem for path in selected}
        self.assertIn("feedback_request_lifecycle_test", names)
        self.assertIn("feedback_relay_contract_test", names)
        self.assertIn("feedback_retry_policy_test", names)
        self.assertIn("feedback_webhook_config_test", names)

    def test_range_check_catches_whitespace_before_clean_head(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            subprocess.run(["git", "init", "-q"], cwd=repo, check=True)
            subprocess.run(["git", "config", "user.name", "Quality Test"], cwd=repo, check=True)
            subprocess.run(["git", "config", "user.email", "quality@example.invalid"], cwd=repo, check=True)
            (repo / "sample.txt").write_text("clean\n", encoding="utf-8")
            subprocess.run(["git", "add", "sample.txt"], cwd=repo, check=True)
            subprocess.run(["git", "commit", "-q", "-m", "base"], cwd=repo, check=True)
            base = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip()

            (repo / "sample.txt").write_text("bad trailing space \n", encoding="utf-8")
            subprocess.run(["git", "add", "sample.txt"], cwd=repo, check=True)
            index_check = subprocess.run(
                self.quality._index_check_command(), cwd=repo, check=False,
                text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            )
            self.assertNotEqual(index_check.returncode, 0)
            self.assertIn("trailing whitespace", index_check.stdout)
            subprocess.run(["git", "commit", "-q", "-m", "bad middle"], cwd=repo, check=True)
            (repo / "clean-head.txt").write_text("clean head\n", encoding="utf-8")
            subprocess.run(["git", "add", "clean-head.txt"], cwd=repo, check=True)
            subprocess.run(["git", "commit", "-q", "-m", "clean head"], cwd=repo, check=True)

            head_only = subprocess.run(
                ["git", "show", "--check", "--format=", "HEAD"], cwd=repo, check=False
            )
            range_check = subprocess.run(
                self.quality._range_check_command(base), cwd=repo, check=False,
                text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            )
            self.assertEqual(head_only.returncode, 0)
            self.assertNotEqual(range_check.returncode, 0)
            self.assertIn("trailing whitespace", range_check.stdout)

    def test_dirty_worktree_cannot_be_certifying(self) -> None:
        args = self.quality._parse_args(["--profile", "changed"])
        self.assertTrue(self.quality._is_certifying(args, [], True))
        self.assertFalse(self.quality._is_certifying(args, ["M  scripts/example.gd"], True))
        self.assertFalse(self.quality._is_certifying(args, ["?? tests/new_test.gd"], True))

    def test_nonintegration_changed_ref_is_partial_and_recorded(self) -> None:
        args = self.quality._parse_args([
            "--profile", "changed", "--changed-ref", "HEAD^",
        ])
        changed_base_sha = self.quality._resolved_commit(args.changed_ref)
        self.assertFalse(
            self.quality._is_certifying(
                args, [], args.changed_ref == self.quality.INTEGRATION_CHANGED_REF
            )
        )

        selected = [ROOT / "tests" / "runtime_smoke_test.gd"]
        static_result = {"name": "mock-static", "status": "passed", "executed_tests": 1}
        import_result = {"name": "godot-import-cache", "status": "passed"}
        godot_result = {
            "name": "runtime_smoke_test",
            "script": "res://tests/runtime_smoke_test.gd",
            "status": "passed",
        }
        with tempfile.TemporaryDirectory(prefix="quality-changed-ref-report-") as scratch:
            report = Path(scratch) / "report.json"
            with mock.patch.object(self.quality, "select_godot_tests", return_value=selected):
                with mock.patch.object(self.quality, "_worktree_status", return_value=[]):
                    with mock.patch.object(self.quality, "run_static_checks", return_value=[static_result]):
                        with mock.patch.object(
                            self.quality, "run_godot_import", return_value=import_result
                        ):
                            with mock.patch.object(
                                self.quality, "run_godot_test", return_value=godot_result
                            ):
                                code = self.quality.main([
                                    "--profile", "changed", "--changed-ref", "HEAD^",
                                    "--report", str(report),
                                ])
            payload = json.loads(report.read_text(encoding="utf-8"))

        self.assertEqual(code, 0)
        self.assertEqual(payload["status"], "partial_pass")
        self.assertFalse(payload["certifying"])
        self.assertEqual(payload["changed_ref"], "HEAD^")
        self.assertEqual(payload["changed_base_sha"], changed_base_sha)

    def test_reported_failure_is_red_even_when_the_process_exits_zero(self) -> None:
        # FAN-1700: `SceneTree.quit()` is deferred, so a `_fail()` that is not
        # followed by `return` lets the suite run on and reach its success
        # `quit()`, which overwrites the requested exit code 1 with 0.  The
        # verdict therefore may not rest on the exit code: the suite already
        # announced the failure through `push_error()`, and that announcement is
        # what has to be terminal.  Real captured shape, exit code and success
        # line included, so the case is exactly the false green from the field.
        with mock.patch.object(
            self.quality, "_run_captured", return_value=(0, REPORTED_FAILURE_OUTPUT, False)
        ):
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                outcome = self.quality.run_godot_test(
                    ROOT / "tests" / "runtime_smoke_test.gd", 10.0
                )
        self.assertEqual(outcome["exit_code"], 0)
        self.assertFalse(outcome["timed_out"])
        self.assertEqual(outcome["status"], "failed")
        self.assertEqual(outcome["fatal_diagnostic"], "push_error")

    def test_benign_engine_errors_do_not_turn_a_green_suite_red(self) -> None:
        # The other half of the guarantee: the signal must discriminate.  Green
        # suites do print bare `ERROR:` lines from the headless renderer and the
        # deferred-call queue (measured on origin/dev: 3 of 259 green suites,
        # 0 of them with a `push_error` frame), so matching `ERROR:` itself
        # would paint them red.  Only the `at: push_error (` frame — emitted
        # solely for a script-level `push_error()` call — may fail a suite.
        self.assertEqual(self.quality.fatal_output_signal(BENIGN_ENGINE_OUTPUT), "")
        self.assertEqual(self.quality.fatal_output_signal(REPORTED_FAILURE_OUTPUT), "push_error")
        # The pre-existing engine-level diagnostics keep their own names.
        self.assertEqual(
            self.quality.fatal_output_signal("SCRIPT ERROR: Parse Error: x\n"), "SCRIPT ERROR"
        )
        with mock.patch.object(
            self.quality, "_run_captured", return_value=(0, BENIGN_ENGINE_OUTPUT, False)
        ):
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                outcome = self.quality.run_godot_test(
                    ROOT / "tests" / "runtime_smoke_test.gd", 10.0
                )
        self.assertEqual(outcome["status"], "passed")
        self.assertEqual(outcome["fatal_diagnostic"], "")

    def test_failure_fixtures_carry_the_pinned_engine_banner(self) -> None:
        # FAN-1718: the fixtures above are frozen literals, so nothing else
        # ties them to the engine build CI actually certifies with.  Whoever
        # moves GODOT_BUILD_ID in quality.yml must recapture (or consciously
        # re-own) the fixture shapes; this check refuses to let the pin move
        # alone, so the fixtures cannot rot into describing an engine the
        # gate no longer runs.
        banner = f"Godot Engine v{_pinned_engine_build_id()} - https://godotengine.org"
        for name, fixture in (
            ("BENIGN_ENGINE_OUTPUT", BENIGN_ENGINE_OUTPUT),
            ("REPORTED_FAILURE_OUTPUT", REPORTED_FAILURE_OUTPUT),
        ):
            self.assertEqual(fixture.splitlines()[0], banner, name)

    def test_umbrella_cannot_print_passed_after_reporting_a_failure(self) -> None:
        # The suite side of the same contract: the success exit re-asserts a
        # failure that `_fail()` already recorded, instead of letting the
        # deferred `quit(1)` be overwritten by the final `quit()`.
        source = (ROOT / "tests" / "runtime_smoke_test.gd").read_text(encoding="utf-8")
        fail_body = _gdscript_func_body(source, "_fail")
        self.assertIn("_failure_reported = true", fail_body)
        self.assertLess(
            fail_body.index("_failure_reported = true"),
            fail_body.index("push_error("),
            "the failure flag must be set before anything that can itself fail",
        )
        finish_body = _gdscript_func_body(source, "_finish")
        guard = finish_body.index("if _failure_reported:")
        self.assertLess(guard, finish_body.index("print("))
        self.assertLess(finish_body.index("quit(1)"), finish_body.index("print("))
        # The success message may only leave the suite through that guard.
        self.assertIn('_finish("Runtime smoke test passed.")', source)
        self.assertNotIn('print("Runtime smoke test passed.")', source)


class LiveEngineSignatureTests(unittest.TestCase):
    """FAN-1718: prove the pinned engine still prints the frame the detector reads.

    The FAN-1700 regression tests above feed ``run_godot_test`` frozen string
    literals, so they stay green forever even after the real engine stops
    printing ``at: push_error (`` — and the failure detector would silently
    degrade back to exit codes.  These probes run the actual engine on a
    minimal throwaway project and read its output through the production
    classifier, so the signature cannot rot unnoticed anywhere an engine
    exists.  Candidate CI always exports GODOT_BIN (asserted in
    test_quality_workflow.py), so there the probes always execute; a machine
    without any engine skips with an explicit reason, while an advertised but
    broken GODOT_BIN fails loudly instead of demoting itself to a skip.
    """

    @classmethod
    def setUpClass(cls) -> None:
        cls.quality = _load_module("quality_gate_live_probe", "tools/quality_gate.py")
        scratch = tempfile.TemporaryDirectory(prefix="fsd-signature-probe-")
        cls.addClassCleanup(scratch.cleanup)
        cls.probe_root = Path(scratch.name)

        env = cls.quality._godot_environment(cls.probe_root / "resolve-home")
        binary = (env.get("GODOT_BIN") or env.get("GODOT") or "").strip()
        expanded = os.path.expanduser(binary)
        resolved = (shutil.which(expanded) or expanded) if binary else ""
        usable = bool(resolved) and Path(resolved).is_file() and os.access(resolved, os.X_OK)
        if not usable:
            advertised = (os.environ.get("GODOT_BIN") or os.environ.get("GODOT") or "").strip()
            if advertised:
                raise AssertionError(
                    f"GODOT_BIN/GODOT advertises {advertised!r} but it is not an"
                    " executable file; an advertised engine must never demote"
                    " the live signature probe to a skip"
                )
            raise unittest.SkipTest(
                "no Godot engine found (GODOT_BIN/GODOT unset, none on PATH or"
                " in the conventional macOS location): the live push_error"
                " signature probe needs an engine binary; CI candidate jobs"
                " always export GODOT_BIN, so the probe always runs there"
            )

        project = cls.probe_root / "project"
        project.mkdir()
        (project / "project.godot").write_text(
            'config_version=5\n\n[application]\n\nconfig/name="FAN-1718 signature probe"\n',
            encoding="utf-8",
        )
        (project / "probe_push_error.gd").write_text(
            "extends SceneTree\n\n\nfunc _init() -> void:\n"
            '\tpush_error("FAN-1718 live signature probe failure")\n\tquit()\n',
            encoding="utf-8",
        )
        (project / "probe_clean.gd").write_text(
            "extends SceneTree\n\n\nfunc _init() -> void:\n"
            '\tprint("FAN-1718 live signature probe clean")\n\tquit()\n',
            encoding="utf-8",
        )

    def _run_probe(self, script_name: str) -> tuple[int, str]:
        user_data = Path(tempfile.mkdtemp(prefix="probe-user-", dir=self.probe_root))
        env = self.quality._godot_environment(user_data)
        # The probe project is empty and short-lived; a private semaphore
        # directory keeps it from queueing behind long-running game suites,
        # which the python-unit idle watchdog would misread as a hang.
        env["FSD_GODOT_SEM_DIR"] = str(self.probe_root / "sem")
        env["FSD_GODOT_RUN_TIMEOUT"] = "180"
        command = [
            sys.executable,
            str(ROOT / "tools" / "godot_gate.py"),
            "--headless",
            "--path",
            str(self.probe_root / "project"),
            "--script",
            f"res://{script_name}",
        ]
        exit_code, output, timed_out = self.quality._run_captured(command, env, 240.0)
        self.assertFalse(timed_out, output)
        return exit_code, output

    def test_live_engine_reports_push_error_with_the_pinned_frame(self) -> None:
        exit_code, output = self._run_probe("probe_push_error.gd")
        # The suite leaves through its own quit(), so the exit code stays 0 —
        # exactly the false-green shape whose only surviving evidence is the
        # frame below.  The message marker proves push_error() really ran.
        self.assertEqual(exit_code, 0, output)
        self.assertIn("FAN-1718 live signature probe failure", output)
        self.assertIsNotNone(self.quality.PUSH_ERROR_FRAME_RE.search(output), output)
        self.assertEqual(self.quality.fatal_output_signal(output), "push_error", output)

    def test_live_engine_clean_run_carries_no_failure_signal(self) -> None:
        exit_code, output = self._run_probe("probe_clean.gd")
        self.assertEqual(exit_code, 0, output)
        # The marker proves the script executed: an empty or crashed run
        # would otherwise satisfy "no failure signal" tautologically.
        self.assertIn("FAN-1718 live signature probe clean", output)
        self.assertIsNone(self.quality.PUSH_ERROR_FRAME_RE.search(output), output)
        self.assertEqual(self.quality.fatal_output_signal(output), "", output)


if __name__ == "__main__":
    unittest.main()
