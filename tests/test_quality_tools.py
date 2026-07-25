from __future__ import annotations

import contextlib
import importlib.util
import base64
import json
import os
import subprocess
import sys
import tempfile
import time
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

    def test_ambiguous_test_names_across_directories_are_rejected(self) -> None:
        with contextlib.ExitStack() as stack:
            self._use_synthetic_tree(stack, {
                "tests/registry_contract_test.gd": "extends SceneTree\n",
                "tests/ultimates/registry_contract_test.gd": "extends SceneTree\n",
            })
            with self.assertRaises(RuntimeError) as raised:
                self.quality.select_godot_tests("full", [], "origin/dev", False)
        self.assertIn("registry_contract_test", str(raised.exception))

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

    def test_every_python_unit_command_is_guarded_by_executed_count(self) -> None:
        # The guard has to cover every name the gate actually emits —
        # `python-unit` for tests/ plus `python-unit:<path>` for each nested
        # discovery root — otherwise a nested suite could collect nothing and
        # still report green.
        with mock.patch.object(
            self.quality,
            "_run_command",
            return_value={"name": "stub", "status": "passed"},
        ) as run_command:
            self.quality.run_static_checks(False, 1.0, "origin/dev", 1.0)
        guarded = {
            call.args[0]: call.kwargs.get("expect_tests")
            for call in run_command.call_args_list
            if call.args[0].startswith("python-unit")
        }
        expected = set(dict(self.quality.python_unit_commands()))
        self.assertEqual(set(guarded), expected)
        self.assertTrue(any(name.startswith("python-unit:") for name in expected))
        self.assertTrue(all(guarded.values()), guarded)

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
        with tempfile.TemporaryDirectory(prefix="quality-python-cache-") as cache:
            env = os.environ.copy()
            env["PYTHONPYCACHEPREFIX"] = cache
            bounded_code, bounded_output, bounded_timeout = self.quality._run_captured(
                [
                    sys.executable,
                    "-u",
                    "-m",
                    "unittest",
                    "discover",
                    "-v",
                    "-s",
                    "tests",
                    "-p",
                    "test_godot_gate.py",
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
                "subprocess.Popen([sys.executable, '-c', os.environ['QUALITY_DESCENDANT_CODE']]); "
                "print('parent-done', flush=True)"
            )
            started = time.monotonic()
            code, output, timed_out = self.quality._run_captured(
                [sys.executable, "-u", "-c", parent],
                env,
                0.5,
                idle_timeout=0.2,
            )
            elapsed = time.monotonic() - started
            descendant_survived = marker.exists()

        self.assertEqual(code, 124)
        self.assertTrue(timed_out)
        self.assertIn("parent-done", output)
        self.assertLess(elapsed, 1.25)
        self.assertFalse(descendant_survived)

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
        self.assertTrue(self.quality._is_certifying(args, []))
        self.assertFalse(self.quality._is_certifying(args, ["M  scripts/example.gd"]))
        self.assertFalse(self.quality._is_certifying(args, ["?? tests/new_test.gd"]))


if __name__ == "__main__":
    unittest.main()
