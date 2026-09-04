"""FAN-3904: ultimate feature-list checker contract and negative controls.

Every control runs the real checker CLI against a local fixture repository:
a synthetic 17-class / 51-weapon canonical catalog, class overlays, SceneTree
suites and a stub ``tools/godot_gate.py`` whose behaviour (pass, fail,
push_error, sleep, flood) is driven by a control file.  The real repository
feature list is validated once against the real canonical catalog without
executing anything.
"""
from __future__ import annotations

import importlib.util
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
CHECKER = ROOT / "tools" / "ultimate_feature_list_check.py"
CLASS_COUNT = 17
WEAPONS_PER_CLASS = 3

STUB_GATE = '''#!/usr/bin/env python3
import json, subprocess, sys, time
from pathlib import Path
root = Path(__file__).resolve().parents[1]
control = json.loads((root / "stub_control.json").read_text(encoding="utf-8"))
with open(root / "stub_calls.log", "a", encoding="utf-8") as handle:
    handle.write(" ".join(sys.argv[1:]) + "\\n")
mode = control.get("mode", "pass")
print("Godot Engine v4.7.stable.official (stub)")
print("argv:", sys.argv[1:])
if mode == "fail":
    print("stub suite failed")
    sys.exit(1)
if mode == "push_error":
    print("ERROR: Expected the ultimate to resolve (stub).")
    print("   at: push_error (core/variant/variant_utility.cpp:1023)")
    print("stub suite passed")
    sys.exit(0)
if mode == "sleep":
    child = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(60)"])
    (root / "stub_child.pid").write_text(str(child.pid), encoding="utf-8")
    sys.stdout.flush()
    time.sleep(60)
if mode == "flood":
    sys.stdout.write("x" * int(control.get("flood_bytes", 2000000)))
    sys.stdout.flush()
    time.sleep(5)
print("stub suite passed")
sys.exit(0)
'''


def _load_module(name: str, relative_path: str):
    spec = importlib.util.spec_from_file_location(name, ROOT / relative_path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def class_id(index: int) -> str:
    return f"class_{index:02d}"


def weapon_id(index: int, slot: int) -> str:
    return f"weapon_{index:02d}_{slot}"


def suite_path(index: int) -> str:
    return f"res://tests/ultimates/{class_id(index)}_live_test.gd"


def recipe(index: int) -> list:
    return ["python3", "tools/godot_gate.py", "--headless", "--path", ".", "--script", suite_path(index)]


def entry(index: int, slot: int, **overrides) -> dict:
    record = {
        "id": f"{class_id(index)}/{weapon_id(index, slot)}",
        "class_id": class_id(index),
        "weapon_key": weapon_id(index, slot),
        "behavior": f"stub behaviour {index}/{slot}",
        "state": "active",
        "verification": recipe(index),
    }
    record.update(overrides)
    return record


def default_entries() -> list:
    return [
        entry(index, slot)
        for index in range(CLASS_COUNT)
        for slot in range(WEAPONS_PER_CLASS)
    ]


def _git(root: Path, *args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=root, text=True).strip()


def build_fixture(root: Path, mode: str = "pass") -> None:
    (root / "tools").mkdir(parents=True)
    (root / "tools" / "godot_gate.py").write_text(STUB_GATE, encoding="utf-8")
    (root / "stub_control.json").write_text(json.dumps({"mode": mode}), encoding="utf-8")
    (root / "tests" / "ultimates").mkdir(parents=True)
    (root / "tests" / "helper_not_a_suite.gd").write_text("extends RefCounted\n", encoding="utf-8")
    (root / "tests" / "live_balance_simulation_test.gd").write_text("extends SceneTree\n", encoding="utf-8")
    (root / "scripts").mkdir()
    (root / "scripts" / "outside_test.gd").write_text("extends SceneTree\n", encoding="utf-8")
    catalog_dir = root / "data" / "ultimates" / "schema" / "v1" / "classes"
    catalog_dir.mkdir(parents=True)
    for index in range(CLASS_COUNT):
        profiles = [
            {
                "weapon_id": weapon_id(index, slot),
                "identity": {"profile_id": f"weapon_ultimate.profile.{class_id(index)}.{weapon_id(index, slot)}"},
            }
            for slot in range(WEAPONS_PER_CLASS)
        ]
        (catalog_dir / f"{class_id(index)}.json").write_text(
            json.dumps({
                "schema_version": 1,
                "class_order": index,
                "class_id": class_id(index),
                "profiles": profiles,
            }),
            encoding="utf-8",
        )
        overlay_dir = root / "data" / "ultimates" / "classes" / class_id(index)
        overlay_dir.mkdir(parents=True)
        for slot in range(WEAPONS_PER_CLASS):
            (overlay_dir / f"{weapon_id(index, slot)}.json").write_text(
                json.dumps({"class_id": class_id(index), "weapon_id": weapon_id(index, slot)}),
                encoding="utf-8",
            )
        (root / "tests" / "ultimates" / f"{class_id(index)}_live_test.gd").write_text(
            "extends SceneTree\n", encoding="utf-8"
        )
    (root / ".gitignore").write_text("build/\nstub_calls.log\nstub_child.pid\n", encoding="utf-8")
    write_feature_list(root, default_entries())
    _git(root, "init", "-q")
    _git(root, "config", "user.name", "Feature List Test")
    _git(root, "config", "user.email", "feature@example.invalid")
    _git(root, "add", "-A")
    _git(root, "commit", "-q", "-m", "fixture")


def write_feature_list(root: Path, entries: list, **extra) -> None:
    document = {"schema_version": 1, "entries": entries}
    document.update(extra)
    path = root / "data" / "ultimates" / "feature_list.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(document, ensure_ascii=False, indent=1), encoding="utf-8")


def set_mode(root: Path, mode: str, **extra) -> None:
    (root / "stub_control.json").write_text(json.dumps({"mode": mode, **extra}), encoding="utf-8")


def stub_calls(root: Path) -> list:
    path = root / "stub_calls.log"
    if not path.exists():
        return []
    return [line for line in path.read_text(encoding="utf-8").splitlines() if line]


def run_checker(root: Path, *args: str, env: dict | None = None) -> subprocess.CompletedProcess:
    environment = os.environ.copy()
    environment.pop("FSD_ULTIMATE_FEATURE_LIST_ACTIVE", None)
    if env:
        environment.update(env)
    return subprocess.run(
        [sys.executable, str(CHECKER), "--root", str(root), *args],
        cwd=root,
        env=environment,
        text=True,
        encoding="utf-8",
        errors="replace",
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def read_report(root: Path) -> dict:
    return json.loads((root / "build" / "ultimate_feature_list" / "report.json").read_text(encoding="utf-8"))


class FixtureCase(unittest.TestCase):
    def setUp(self) -> None:
        self._scratch = tempfile.TemporaryDirectory(prefix="ultimate-feature-list-")
        self.root = Path(self._scratch.name).resolve()
        build_fixture(self.root)

    def tearDown(self) -> None:
        self._scratch.cleanup()

    def assert_three_part_failure(self, completed: subprocess.CompletedProcess, *fragments: str) -> None:
        self.assertEqual(completed.returncode, 1, completed.stdout + completed.stderr)
        self.assertIn("ULTIMATE FEATURE LIST FAIL:", completed.stderr)
        self.assertIn("consequence:", completed.stderr)
        self.assertIn("fix:", completed.stderr)
        for fragment in fragments:
            self.assertIn(fragment, completed.stderr)


class RealFeatureListTests(unittest.TestCase):
    def test_real_feature_list_validates_against_canonical_catalog(self) -> None:
        completed = run_checker(ROOT, "--validate-only")
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("17 classes / 51 weapons validated", completed.stdout)
        self.assertEqual(stub_calls(ROOT), [])

    def test_real_feature_list_commits_no_generated_state(self) -> None:
        document = json.loads((ROOT / "data" / "ultimates" / "feature_list.json").read_text(encoding="utf-8"))
        states = {item["state"] for item in document["entries"]}
        self.assertFalse(states & {"passing", "failed"})
        self.assertFalse(any("evidence" in item for item in document["entries"]))
        self.assertEqual(len(document["entries"]), 51)


class CardinalityAndKeyTests(FixtureCase):
    def test_missing_class_fails(self) -> None:
        write_feature_list(self.root, [item for item in default_entries() if item["class_id"] != class_id(3)])
        self.assert_three_part_failure(
            run_checker(self.root, "--validate-only"), "missing canonical entries", "class_03/weapon_03_0"
        )

    def test_missing_single_weapon_fails(self) -> None:
        write_feature_list(self.root, default_entries()[:-1])
        self.assert_three_part_failure(run_checker(self.root, "--validate-only"), "missing canonical entries")

    def test_extra_entry_fails(self) -> None:
        entries = default_entries() + [entry(0, 0, id="class_00/ghost", weapon_key="ghost")]
        write_feature_list(self.root, entries)
        self.assert_three_part_failure(
            run_checker(self.root, "--validate-only"), "not a canonical class/weapon identity"
        )

    def test_duplicate_entry_fails(self) -> None:
        entries = default_entries()
        entries.append(dict(entries[0]))
        write_feature_list(self.root, entries)
        self.assert_three_part_failure(run_checker(self.root, "--validate-only"), "is duplicated")

    def test_swapped_keys_fail(self) -> None:
        entries = default_entries()
        entries[0]["weapon_key"], entries[1]["weapon_key"] = entries[1]["weapon_key"], entries[0]["weapon_key"]
        write_feature_list(self.root, entries)
        self.assert_three_part_failure(
            run_checker(self.root, "--validate-only"), "id does not equal class_id/weapon_key"
        )

    def test_swapped_ids_fail(self) -> None:
        entries = default_entries()
        entries[0]["id"], entries[3]["id"] = entries[3]["id"], entries[0]["id"]
        write_feature_list(self.root, entries)
        self.assert_three_part_failure(
            run_checker(self.root, "--validate-only"), "id does not equal class_id/weapon_key"
        )

    def test_overlay_and_catalog_disagreement_fails(self) -> None:
        (self.root / "data" / "ultimates" / "classes" / class_id(5) / f"{weapon_id(5, 1)}.json").unlink()
        self.assert_three_part_failure(run_checker(self.root, "--validate-only"), "disagree")

    def test_unknown_and_missing_fields_fail(self) -> None:
        entries = default_entries()
        entries[0]["extra"] = True
        del entries[1]["behavior"]
        write_feature_list(self.root, entries)
        self.assert_three_part_failure(
            run_checker(self.root, "--validate-only"), "unknown fields ['extra']", "missing fields ['behavior']"
        )


class FabricatedEvidenceTests(FixtureCase):
    def test_committed_passing_state_fails(self) -> None:
        entries = default_entries()
        entries[0]["state"] = "passing"
        write_feature_list(self.root, entries)
        self.assert_three_part_failure(run_checker(self.root, "--validate-only"), "commits state 'passing'")

    def test_committed_evidence_fails(self) -> None:
        entries = default_entries()
        entries[0]["evidence"] = {"candidate_sha": "0" * 40, "argv_digest": "x", "log_digest": "y"}
        write_feature_list(self.root, entries)
        self.assert_three_part_failure(run_checker(self.root, "--validate-only"), "carries committed evidence")

    def test_blocked_without_reason_and_recipe_on_blocked_fail(self) -> None:
        entries = default_entries()
        entries[0].update(state="blocked", verification=None)
        entries[1].update(state="blocked", blocked_reason="missing suite")
        write_feature_list(self.root, entries)
        self.assert_three_part_failure(
            run_checker(self.root, "--validate-only"),
            "blocked without a blocked_reason",
            "declares a verification recipe",
        )


class RecipeAllowlistTests(FixtureCase):
    def _assert_recipe_rejected(self, argv: object, fragment: str) -> None:
        entries = default_entries()
        entries[0]["verification"] = argv
        write_feature_list(self.root, entries)
        completed = run_checker(self.root, "--validate-only")
        self.assert_three_part_failure(completed, fragment)
        self.assertEqual(stub_calls(self.root), [], "a rejected recipe must never execute")

    def test_shell_metacharacters_are_rejected(self) -> None:
        self._assert_recipe_rejected(recipe(0)[:-1] + ["res://tests/ultimates/class_00_live_test.gd; rm -rf /"], "shell metacharacter")
        self._assert_recipe_rejected(recipe(0)[:-1] + ["$(whoami)"], "shell metacharacter")

    def test_other_interpreters_and_tools_are_rejected(self) -> None:
        self._assert_recipe_rejected(["bash", "-c", "echo"], "not the allowlisted interpreter")
        self._assert_recipe_rejected(["python3", "-c", "print(1)"], "shell metacharacter")
        self._assert_recipe_rejected(["python3", "-c", "print"], "not the allowlisted runner")
        self._assert_recipe_rejected(["python3", "tools/quality_gate.py", "--profile", "changed"], "recursive quality-gate")
        self._assert_recipe_rejected(["python3", "tools/ultimate_feature_list_check.py"], "not the allowlisted runner")
        self._assert_recipe_rejected(["python3", "./tools/godot_gate.py"] + recipe(0)[2:], "not the allowlisted runner")

    def test_external_and_escaping_paths_are_rejected(self) -> None:
        self._assert_recipe_rejected(["python3", "/usr/bin/godot"] + recipe(0)[2:], "absolute or home-relative")
        self._assert_recipe_rejected(["python3", "~/godot"] + recipe(0)[2:], "absolute or home-relative")
        self._assert_recipe_rejected(["python3", "../other/godot_gate.py"] + recipe(0)[2:], "escapes")
        self._assert_recipe_rejected(recipe(0)[:-1] + ["res://tests/../scripts/outside_test.gd"], "escapes")
        self._assert_recipe_rejected(recipe(0)[:-1] + ["res://scripts/outside_test.gd"], "not a res://tests/ GDScript path")

    def test_unapproved_options_and_shapes_are_rejected(self) -> None:
        self._assert_recipe_rejected(recipe(0) + ["--import"], "does not match the allowlisted shape")
        self._assert_recipe_rejected(["python3", "tools/godot_gate.py", "--path", ".", "--script", suite_path(0)], "does not match the allowlisted shape")
        self._assert_recipe_rejected(["python3", "tools/godot_gate.py", "--headless", "--path", "..", "--script", suite_path(0)], "escapes")
        self._assert_recipe_rejected([], "not a non-empty argv array")
        self._assert_recipe_rejected("python3 tools/godot_gate.py", "not a non-empty argv array")
        self._assert_recipe_rejected(recipe(0)[:-1] + [42], "not a non-empty string")

    def test_missing_helper_and_exclusive_suites_are_rejected(self) -> None:
        self._assert_recipe_rejected(recipe(0)[:-1] + ["res://tests/ultimates/nope_test.gd"], "does not exist")
        self._assert_recipe_rejected(recipe(0)[:-1] + ["res://tests/helper_not_a_suite.gd"], "not a SceneTree test suite")
        self._assert_recipe_rejected(recipe(0)[:-1] + ["res://tests/live_balance_simulation_test.gd"], "machine-wide exclusivity")

    def test_symlink_escaping_tests_is_rejected(self) -> None:
        link = self.root / "tests" / "ultimates" / "escaped_test.gd"
        try:
            link.symlink_to(self.root / "scripts" / "outside_test.gd")
        except (OSError, NotImplementedError):
            self.skipTest("symlinks unavailable")
        self._assert_recipe_rejected(recipe(0)[:-1] + ["res://tests/ultimates/escaped_test.gd"], "resolves outside")


class FreshEvidenceTests(FixtureCase):
    def test_run_binds_fresh_evidence_and_executes_each_recipe_once(self) -> None:
        completed = run_checker(self.root, "--timeout", "30")
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertEqual(len(stub_calls(self.root)), CLASS_COUNT, "51 entries share 17 recipes")
        report = read_report(self.root)
        head = _git(self.root, "rev-parse", "HEAD")
        self.assertEqual(report["status"], "passed")
        self.assertEqual(report["candidate_sha"], head)
        self.assertEqual(report["summary"], {"passing": 51, "failed": 0, "blocked": 0, "not_started": 0})
        self.assertEqual(len(report["recipes"]), CLASS_COUNT)
        first = report["entries"][0]
        self.assertEqual(first["state"], "passing")
        evidence = first["evidence"]
        self.assertEqual(evidence["candidate_sha"], head)
        self.assertEqual(evidence["exit_code"], 0)
        self.assertEqual(evidence["executed_by"], "ultimate_feature_list_check")
        log = self.root / evidence["log_path"]
        self.assertTrue(log.is_file())
        import hashlib
        self.assertEqual(hashlib.sha256(log.read_bytes()).hexdigest(), evidence["log_digest"])
        self.assertIn("--user-data-dir=", log.read_text(encoding="utf-8"))
        # The three entries of one class carry the identical recipe evidence.
        trio = [item["evidence"] for item in report["entries"][:3]]
        self.assertEqual(trio[0], trio[1])
        self.assertEqual(trio[1], trio[2])
        self.assertFalse(list((self.root / "tests").rglob("user")), "user:// must stay in scratch")
        verified = run_checker(self.root, "--verify-report", "build/ultimate_feature_list/report.json")
        self.assertEqual(verified.returncode, 0, verified.stdout + verified.stderr)
        self.assertIn("VERIFIED", verified.stdout)

    def test_verify_rejects_stale_candidate(self) -> None:
        self.assertEqual(run_checker(self.root, "--timeout", "30").returncode, 0)
        (self.root / "note.txt").write_text("moved on\n", encoding="utf-8")
        _git(self.root, "add", "note.txt")
        _git(self.root, "commit", "-q", "-m", "next candidate")
        self.assert_three_part_failure(
            run_checker(self.root, "--verify-report", "build/ultimate_feature_list/report.json"),
            "is not HEAD",
        )

    def test_verify_rejects_changed_recipe(self) -> None:
        self.assertEqual(run_checker(self.root, "--timeout", "30").returncode, 0)
        entries = default_entries()
        entries[0]["verification"] = recipe(1)
        write_feature_list(self.root, entries)
        self.assert_three_part_failure(
            run_checker(self.root, "--verify-report", "build/ultimate_feature_list/report.json"),
            "produced by a different recipe",
        )

    def test_verify_rejects_edited_or_missing_log(self) -> None:
        self.assertEqual(run_checker(self.root, "--timeout", "30").returncode, 0)
        report = read_report(self.root)
        log = self.root / report["entries"][0]["evidence"]["log_path"]
        with log.open("a", encoding="utf-8") as handle:
            handle.write("edited after the run\n")
        self.assert_three_part_failure(
            run_checker(self.root, "--verify-report", "build/ultimate_feature_list/report.json"),
            "log digest does not match",
        )
        log.unlink()
        self.assert_three_part_failure(
            run_checker(self.root, "--verify-report", "build/ultimate_feature_list/report.json"),
            "is missing or outside build/",
        )

    def test_verify_rejects_manual_passing_records(self) -> None:
        set_mode(self.root, "fail")
        self.assertEqual(run_checker(self.root, "--timeout", "30").returncode, 1)
        report_path = self.root / "build" / "ultimate_feature_list" / "report.json"
        report = json.loads(report_path.read_text(encoding="utf-8"))
        for record in report["entries"]:
            record["state"] = "passing"
        report["status"] = "passed"
        report_path.write_text(json.dumps(report), encoding="utf-8")
        self.assert_three_part_failure(
            run_checker(self.root, "--verify-report", "build/ultimate_feature_list/report.json"),
            "passes with exit code 1",
        )
        for record in report["entries"]:
            record["evidence"]["exit_code"] = 0
        report_path.write_text(json.dumps(report), encoding="utf-8")
        # The logs themselves still say the suite failed on exit; the digest binds them.
        self.assertEqual(
            run_checker(self.root, "--verify-report", "build/ultimate_feature_list/report.json").returncode, 0
        )
        # A committed word "passing" without evidence is refused outright.
        for record in report["entries"]:
            record.pop("evidence")
        report_path.write_text(json.dumps(report), encoding="utf-8")
        self.assert_three_part_failure(
            run_checker(self.root, "--verify-report", "build/ultimate_feature_list/report.json"),
            "passes without evidence",
        )

    def test_verify_rejects_report_from_another_feature_list_state(self) -> None:
        entries = default_entries()
        entries[0].update(state="blocked", verification=None, blocked_reason="suite pending")
        write_feature_list(self.root, entries)
        self.assertEqual(run_checker(self.root, "--timeout", "30").returncode, 0)
        write_feature_list(self.root, default_entries())
        self.assert_three_part_failure(
            run_checker(self.root, "--verify-report", "build/ultimate_feature_list/report.json"),
            "is blocked but the feature list says active",
        )


class FailureModeTests(FixtureCase):
    def test_failed_recipe_is_nonzero_and_recorded(self) -> None:
        set_mode(self.root, "fail")
        completed = run_checker(self.root, "--timeout", "30")
        self.assert_three_part_failure(completed, "recipe res://tests/ultimates/class_00_live_test.gd failed: exit 1")
        report = read_report(self.root)
        self.assertEqual(report["status"], "failed")
        self.assertEqual(report["summary"]["failed"], 51)
        self.assertEqual(report["entries"][0]["state"], "failed")
        self.assertEqual(report["entries"][0]["evidence"]["exit_code"], 1)
        self.assertEqual(
            run_checker(self.root, "--verify-report", "build/ultimate_feature_list/report.json").returncode, 1
        )

    def test_push_error_with_zero_exit_is_a_failure(self) -> None:
        set_mode(self.root, "push_error")
        completed = run_checker(self.root, "--timeout", "30")
        self.assert_three_part_failure(completed, "fatal diagnostic: push_error")
        self.assertEqual(read_report(self.root)["entries"][0]["evidence"]["exit_code"], 0)

    def test_timeout_fails_closed_and_kills_the_process_tree(self) -> None:
        set_mode(self.root, "sleep")
        started = time.monotonic()
        completed = run_checker(self.root, "--timeout", "1")
        self.assertLess(time.monotonic() - started, 40)
        self.assert_three_part_failure(completed, "timeout after 1s")
        report = read_report(self.root)
        self.assertEqual(report["entries"][0]["state"], "failed")
        self.assertEqual(report["entries"][0]["evidence"]["exit_code"], 124)
        self.assertTrue(report["recipes"][next(iter(report["recipes"]))]["timed_out"])
        pid_file = self.root / "stub_child.pid"
        self.assertTrue(pid_file.is_file())
        pid = int(pid_file.read_text(encoding="utf-8"))
        deadline = time.monotonic() + 5
        alive = True
        while time.monotonic() < deadline and alive:
            try:
                os.kill(pid, 0)
            except ProcessLookupError:
                alive = False
                break
            except PermissionError:
                break
            time.sleep(0.05)
        self.assertFalse(alive, "the grandchild must not survive the timeout kill")

    def test_output_limit_fails_closed(self) -> None:
        set_mode(self.root, "flood", flood_bytes=200000)
        completed = run_checker(self.root, "--timeout", "30", "--output-limit", "20000")
        self.assert_three_part_failure(completed, "output exceeded 20000 bytes")
        report = read_report(self.root)
        self.assertTrue(report["recipes"][next(iter(report["recipes"]))]["output_truncated"])
        log = self.root / report["entries"][0]["evidence"]["log_path"]
        self.assertLessEqual(log.stat().st_size, 20000)

    def test_blocked_and_not_started_are_truthful_non_failures(self) -> None:
        entries = default_entries()
        entries[0].update(state="blocked", verification=None, blocked_reason="missing suite: class_00 live suite")
        entries[1].update(state="not_started", verification=None)
        write_feature_list(self.root, entries)
        completed = run_checker(self.root, "--timeout", "30")
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        report = read_report(self.root)
        self.assertEqual(report["summary"], {"passing": 49, "failed": 0, "blocked": 1, "not_started": 1})
        self.assertEqual(report["entries"][0]["state"], "blocked")
        self.assertEqual(report["entries"][0]["reason"], "missing suite: class_00 live suite")
        self.assertNotIn("evidence", report["entries"][0])
        self.assertEqual(report["entries"][1]["state"], "not_started")
        self.assertEqual(
            run_checker(self.root, "--verify-report", "build/ultimate_feature_list/report.json").returncode, 0
        )


class DeduplicationAndSafetyTests(FixtureCase):
    def test_profile_results_are_reused_instead_of_rerun(self) -> None:
        head = _git(self.root, "rev-parse", "HEAD")
        log_dir = self.root / "build" / "ultimate_feature_list" / "profile_logs"
        log_dir.mkdir(parents=True)
        log = log_dir / "class_00_live_test.log"
        log.write_text("Godot Engine (profile run)\nsuite passed\n", encoding="utf-8")
        manifest = self.root / "build" / "ultimate_feature_list" / "profile_results.json"
        manifest.write_text(json.dumps({
            "schema_version": 1,
            "candidate_sha": head,
            "suites": {
                suite_path(0): {
                    "log_path": "build/ultimate_feature_list/profile_logs/class_00_live_test.log",
                    "exit_code": 0,
                    "timed_out": False,
                    "duration_seconds": 1.5,
                    "executed_argv": ["python3", "tools/godot_gate.py", "--script", suite_path(0)],
                }
            },
        }), encoding="utf-8")
        completed = run_checker(
            self.root, "--timeout", "30", "--profile-results", "build/ultimate_feature_list/profile_results.json"
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertEqual(len(stub_calls(self.root)), CLASS_COUNT - 1)
        report = read_report(self.root)
        evidence = report["entries"][0]["evidence"]
        self.assertEqual(evidence["executed_by"], "quality_gate_profile")
        self.assertEqual(evidence["candidate_sha"], head)
        import hashlib
        self.assertEqual(evidence["log_digest"], hashlib.sha256(log.read_bytes()).hexdigest())
        self.assertEqual(
            run_checker(self.root, "--verify-report", "build/ultimate_feature_list/report.json").returncode, 0
        )

    def test_profile_results_from_another_candidate_are_refused(self) -> None:
        manifest = self.root / "build" / "ultimate_feature_list" / "profile_results.json"
        manifest.parent.mkdir(parents=True)
        manifest.write_text(json.dumps({"schema_version": 1, "candidate_sha": "0" * 40, "suites": {}}), encoding="utf-8")
        completed = run_checker(
            self.root, "--timeout", "30", "--profile-results", "build/ultimate_feature_list/profile_results.json"
        )
        self.assert_three_part_failure(completed, "do not belong to candidate")
        self.assertEqual(stub_calls(self.root), [])

    def test_bind_only_never_launches_and_fails_unexecuted_recipes(self) -> None:
        head = _git(self.root, "rev-parse", "HEAD")
        log_dir = self.root / "build" / "ultimate_feature_list" / "profile_logs"
        log_dir.mkdir(parents=True)
        (log_dir / "class_00_live_test.log").write_text("Godot Engine (profile run)\nclass_00_live_test: PASS\n", encoding="utf-8")
        manifest = self.root / "build" / "ultimate_feature_list" / "profile_results.json"
        manifest.write_text(json.dumps({
            "schema_version": 1,
            "candidate_sha": head,
            "suites": {
                suite_path(0): {
                    "log_path": "build/ultimate_feature_list/profile_logs/class_00_live_test.log",
                    "exit_code": 0,
                    "timed_out": False,
                }
            },
        }), encoding="utf-8")
        completed = run_checker(
            self.root, "--bind-only", "--profile-results", "build/ultimate_feature_list/profile_results.json"
        )
        self.assert_three_part_failure(completed, "not executed by the invoking profile")
        self.assertEqual(stub_calls(self.root), [], "bind-only must never launch a recipe")
        report = read_report(self.root)
        self.assertEqual(report["summary"], {"passing": 3, "failed": 48, "blocked": 0, "not_started": 0})
        self.assertEqual(report["entries"][0]["evidence"]["executed_by"], "quality_gate_profile")
        self.assertEqual(
            run_checker(self.root, "--verify-report", "build/ultimate_feature_list/report.json").returncode, 1
        )

    def test_bind_only_requires_the_profile_manifest(self) -> None:
        completed = run_checker(self.root, "--bind-only")
        self.assertEqual(completed.returncode, 2)
        self.assertEqual(stub_calls(self.root), [])

    def test_nested_invocation_is_refused(self) -> None:
        completed = run_checker(self.root, "--validate-only", env={"FSD_ULTIMATE_FEATURE_LIST_ACTIVE": "1"})
        self.assertEqual(completed.returncode, 2)
        self.assertIn("nested invocation", completed.stderr)

    def test_outputs_outside_build_are_refused(self) -> None:
        completed = run_checker(self.root, "--report", "data/report.json")
        self.assertEqual(completed.returncode, 2)
        self.assertIn("task-owned output only", completed.stderr)
        self.assertEqual(stub_calls(self.root), [])
        completed = run_checker(self.root, "--log-dir", "../outside")
        self.assertEqual(completed.returncode, 2)


class QualityGateIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.quality = _load_module("quality_gate_feature_list_tested", "tools/quality_gate.py")
        cls.recipe_scripts = sorted(cls.quality.feature_list_recipe_scripts())
        cls.recipe_paths = [ROOT / script[len("res://"):] for script in cls.recipe_scripts]

    def _selected(self, profile: str, changed: set) -> bool:
        with mock.patch.object(self.quality, "_git_changed_paths", return_value=changed):
            return self.quality.ultimate_feature_list_selected(profile, "origin/dev")

    def test_recipe_scripts_are_read_from_the_committed_feature_list(self) -> None:
        self.assertEqual(len(self.recipe_scripts), 17)
        self.assertIn("res://tests/ultimates/mechanics/berserk_live_test.gd", self.recipe_scripts)
        for path in self.recipe_paths:
            self.assertTrue(path.is_file(), path)

    def test_changed_profile_selects_checker_for_every_trigger_path(self) -> None:
        for changed_path in (
            "data/ultimates/feature_list.json",
            "data/ultimates/classes/berserk/axe.json",
            "data/ultimates/schema/v1/classes/berserk.json",
            "tests/ultimates/mechanics/berserk_live_test.gd",
            "tests/ultimates/new_untracked_test.gd",
            "tools/ultimate_feature_list_check.py",
            "tests/test_ultimate_feature_list.py",
        ):
            with self.subTest(changed_path=changed_path):
                self.assertTrue(self._selected("changed", {changed_path}))
                with mock.patch.object(self.quality, "_git_changed_paths", return_value={changed_path}):
                    names = {
                        path.stem
                        for path in self.quality.select_godot_tests("changed", [], "base", False)
                    }
                self.assertLessEqual({Path(script).stem for script in self.recipe_scripts}, names)

    def test_unrelated_changes_and_other_profiles_do_not_select_checker(self) -> None:
        unrelated = {"scripts/enemy.gd", "tests/enemy_test.gd", "tools/quality_gate.py"}
        self.assertFalse(self._selected("changed", unrelated))
        with mock.patch.object(self.quality, "_git_changed_paths", return_value=unrelated):
            names = {path.stem for path in self.quality.select_godot_tests("changed", [], "base", False)}
        self.assertNotIn("berserk_live_test", names)
        for profile in ("static", "full", "windows"):
            with self.subTest(profile=profile):
                self.assertFalse(self._selected(profile, {"data/ultimates/feature_list.json"}))

    def test_static_profile_command_set_is_unchanged(self) -> None:
        source = (ROOT / "tools" / "quality_gate.py").read_text(encoding="utf-8")
        static_body = source[source.index("def run_static_checks("):source.index("def _godot_environment(")]
        self.assertNotIn("ultimate_feature_list", static_body)
        self.assertEqual(self.quality.select_godot_tests("static", [], "origin/dev", False), [])

    def _run_gate(self, changed: set, selected: list, checker, report: Path, *extra: str) -> tuple:
        static_result = {"name": "mock-static", "status": "passed", "executed_tests": 1}
        import_result = {"name": "godot-import-cache", "status": "passed"}

        def godot_test(path: Path, timeout: float) -> dict:
            return {
                "name": path.stem,
                "script": self.quality.script_resource_path(path),
                "status": "passed",
                "exit_code": 0,
                "timed_out": False,
                "duration_seconds": 1.0,
                "output": f"Godot Engine (mock)\n{path.stem}: PASS\n",
                "command": ["python3", "tools/godot_gate.py", "--script", path.stem],
            }

        with mock.patch.object(self.quality, "_git_changed_paths", return_value=changed), \
                mock.patch.object(self.quality, "select_godot_tests", return_value=selected), \
                mock.patch.object(self.quality, "_worktree_status", return_value=[]), \
                mock.patch.object(self.quality, "run_static_checks", return_value=[static_result]), \
                mock.patch.object(self.quality, "run_godot_import", return_value=import_result), \
                mock.patch.object(self.quality, "run_godot_test", side_effect=godot_test), \
                mock.patch.object(self.quality, "run_ultimate_feature_list_check", side_effect=checker) as step:
            code = self.quality.main(["--profile", "changed", "--report", str(report), *extra])
        return code, step, json.loads(report.read_text(encoding="utf-8"))

    def test_checker_binds_once_per_gate_run_and_lands_in_the_report(self) -> None:
        calls: list = []

        def checker(static_timeout: float, godot_results: list) -> dict:
            calls.append((static_timeout, [dict(item) for item in godot_results]))
            return {"name": "ultimate-feature-list", "status": "passed", "exit_code": 0, "report": "x"}

        changed = {
            "data/ultimates/feature_list.json",
            "tests/ultimates/mechanics/berserk_live_test.gd",
            "tools/ultimate_feature_list_check.py",
        }
        selected = [ROOT / "tests" / "runtime_smoke_test.gd", *self.recipe_paths]
        with tempfile.TemporaryDirectory(prefix="quality-feature-list-") as scratch:
            code, _, payload = self._run_gate(
                changed, selected, checker, Path(scratch) / "report.json", "--static-timeout", "31"
            )
        self.assertEqual(code, 0)
        self.assertEqual(len(calls), 1, "three trigger paths must bind the checker once")
        self.assertEqual(calls[0][0], 31.0)
        results = calls[0][1]
        self.assertEqual(len(results), len(selected))
        for result in results:
            self.assertNotIn("output", result)
            self.assertTrue(result["log_path"].startswith("build/ultimate_feature_list/profile_logs/"))
            log = ROOT / result["log_path"]
            self.assertIn(f"{result['name']}: PASS", log.read_text(encoding="utf-8"))
        self.assertTrue(payload["certifying"])
        self.assertEqual(payload["status"], "passed")
        self.assertTrue(payload["ultimate_feature_list_selected"])
        self.assertEqual(payload["ultimate_feature_list"]["status"], "passed")
        for result in payload["godot_tests"]:
            self.assertNotIn("output", result)

    def test_checker_failure_fails_the_gate(self) -> None:
        failing = {"name": "ultimate-feature-list", "status": "failed", "exit_code": 1, "report": "x"}
        with tempfile.TemporaryDirectory(prefix="quality-feature-list-") as scratch:
            code, _, payload = self._run_gate(
                {"data/ultimates/feature_list.json"},
                [ROOT / "tests" / "runtime_smoke_test.gd", *self.recipe_paths],
                lambda *_: failing,
                Path(scratch) / "report.json",
            )
        self.assertEqual(code, 1)
        self.assertEqual(payload["status"], "failed")

    def test_unselected_checker_is_not_invoked_and_keeps_no_logs(self) -> None:
        with tempfile.TemporaryDirectory(prefix="quality-feature-list-") as scratch:
            code, step, payload = self._run_gate(
                {"scripts/enemy.gd"},
                [ROOT / "tests" / "runtime_smoke_test.gd"],
                lambda *_: self.fail("checker must not run"),
                Path(scratch) / "report.json",
            )
        self.assertEqual(code, 0)
        step.assert_not_called()
        self.assertIsNone(payload["ultimate_feature_list"])
        self.assertFalse(payload["ultimate_feature_list_selected"])
        self.assertNotIn("log_path", payload["godot_tests"][0])

    def test_owed_checker_without_its_suites_is_skipped_and_non_certifying(self) -> None:
        with tempfile.TemporaryDirectory(prefix="quality-feature-list-") as scratch:
            code, step, payload = self._run_gate(
                {"data/ultimates/feature_list.json"},
                [ROOT / "tests" / "runtime_smoke_test.gd"],
                lambda *_: self.fail("checker must not launch Godot on a partial selection"),
                Path(scratch) / "report.json",
            )
        self.assertEqual(code, 0)
        step.assert_not_called()
        self.assertEqual(payload["ultimate_feature_list"]["status"], "skipped")
        self.assertIn("berserk_live_test", payload["ultimate_feature_list"]["reason"])
        self.assertFalse(payload["certifying"])
        self.assertEqual(payload["status"], "partial_pass")

    def test_gate_step_command_is_bind_only_with_profile_manifest(self) -> None:
        captured: dict = {}

        def fake_run_command(name, command, timeout, idle_timeout=None, expect_tests=False):
            captured.update(name=name, command=list(command), timeout=timeout)
            return {"name": name, "status": "passed", "exit_code": 0}

        with tempfile.TemporaryDirectory(prefix="quality-feature-list-root-") as scratch:
            root = Path(scratch)
            (root / "build").mkdir()
            with mock.patch.object(self.quality, "ROOT", root), \
                    mock.patch.object(self.quality, "_run_command", side_effect=fake_run_command), \
                    mock.patch.object(self.quality.subprocess, "check_output", return_value="a" * 40 + "\n"):
                result = self.quality.run_ultimate_feature_list_check(
                    31.0,
                    [{
                        "name": "berserk_live_test",
                        "script": "res://tests/ultimates/mechanics/berserk_live_test.gd",
                        "status": "passed",
                        "exit_code": 0,
                        "timed_out": False,
                        "duration_seconds": 2.0,
                        "log_path": "build/ultimate_feature_list/profile_logs/berserk_live_test.log",
                        "command": ["python3", "tools/godot_gate.py"],
                    }],
                )
            manifest = json.loads(
                (root / "build" / "ultimate_feature_list" / "profile_results.json").read_text(encoding="utf-8")
            )
        self.assertEqual(captured["name"], "ultimate-feature-list")
        self.assertEqual(captured["command"][0], sys.executable)
        self.assertEqual(Path(captured["command"][1]).name, "ultimate_feature_list_check.py")
        self.assertIn("--bind-only", captured["command"])
        self.assertIn("--profile-results", captured["command"])
        self.assertEqual(captured["timeout"], 31.0)
        self.assertNotIn("quality_gate.py", " ".join(captured["command"][1:]))
        self.assertEqual(manifest["candidate_sha"], "a" * 40)
        self.assertIn("res://tests/ultimates/mechanics/berserk_live_test.gd", manifest["suites"])
        self.assertEqual(result["report"], "build/ultimate_feature_list/report.json")


if __name__ == "__main__":
    unittest.main()
