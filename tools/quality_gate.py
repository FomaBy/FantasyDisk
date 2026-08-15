#!/usr/bin/env python3
"""One cross-platform quality entry point for FantasyDisk.

The runner discovers both direct ``extends SceneTree`` tests and inherited test
suites, isolates ``user://`` per process, and routes every Godot invocation
through ``tools/godot_gate.py``.  It intentionally runs synchronously so a
Multica task cannot finish before validation has completed.

Timing-sensitive live-balance and runaway suites request machine-wide
exclusivity for their individual Godot process.  The import pre-pass and every
ordinary suite explicitly remain non-exclusive, so the quality gate as a whole
is never serialized behind one nested lease.

Discovery is recursive over ``tests/``: Godot suites and Python suites in nested
directories (``tests/ultimates/**``) are part of every profile.  An empty test
set is a gate failure, never a pass — a silently skipped suite must never read
as green.  A suite that announced a failure is held to the same rule: the
verdict reads the failure diagnostic in the captured output, so it does not
depend on a process exit code that deferred-``quit`` ordering can overwrite.
"""
from __future__ import annotations

import argparse
import base64
import binascii
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path
from typing import Iterable, Sequence

try:
    from tools.godot_gate import FATAL_OUTPUT_RE, IMPORT_CACHE_MISSING_MESSAGE
except ModuleNotFoundError:
    from godot_gate import FATAL_OUTPUT_RE, IMPORT_CACHE_MISSING_MESSAGE

ROOT = Path(__file__).resolve().parents[1]
TEST_DIR = ROOT / "tests"
GODOT_GATE = ROOT / "tools" / "godot_gate.py"
RUNTIME_SMOKE = "runtime_smoke_test"
TIMING_SENSITIVE_GODOT_SCRIPTS = frozenset({
    "res://tests/berserk_dps_runaway_gate.gd",
    "res://tests/live_balance_simulation_test.gd",
    "res://tests/pool_dot_runaway_gate.gd",
})
EXTENDS_RE = re.compile(
    r'^\s*extends\s+(?:SceneTree|["\']res://tests/[^"\']+\.gd["\'])\s*(?:#.*)?$',
    re.MULTILINE,
)
REAL_DISCORD_WEBHOOK_RE = re.compile(
    r"https://(?:discord(?:app)?\.com)/api/webhooks/[0-9]{15,}/[A-Za-z0-9_-]{20,}"
)
BASE64_LITERAL_RE = re.compile(r'["\']([A-Za-z0-9+/]{20,}={0,2})["\']')
INTEGRATION_CHANGED_REF = "origin/dev"
# FAN-1700: a GDScript suite reports its own failure through ``push_error()``,
# which Godot prints as ``ERROR: <message>`` plus an ``at: push_error (...)``
# frame.  The bare ``ERROR:`` line is indistinguishable from benign engine
# noise, but that frame is emitted only for a script-level ``push_error`` call,
# so it is the discriminating signal.  Without it a reported failure survives
# only as the process exit code, and a deferred ``SceneTree.quit(1)`` that a
# later ``quit()`` overwrites reads as a green suite.
PUSH_ERROR_FRAME_RE = re.compile(r"^[ \t]*at: push_error \(", re.MULTILINE)
RAN_TESTS_RE = re.compile(r"^Ran (\d+) tests? in ", re.MULTILINE)
PYTHON_TEST_PATTERN = "test_*.py"
_WINDOWS_JOB_RUNNER_ARG = "--_quality-gate-windows-job-runner"
_WINDOWS_JOB_HANDLE_ENV = "_QUALITY_GATE_WINDOWS_JOB_HANDLE"
_WINDOWS_CLEANUP_TIMEOUT = 5.0

CORE_CHANGED_TESTS = {
    "combat_target_query_cache_test",
    "runtime_smoke_combat_test",
    "runtime_smoke_ui_test",
    "weapon_ultimate_contact_sheet_beats_test",
    "weapon_ultimate_timing_distinctness_test",
}
TYPOGRAPHY_INVENTORY_TEST = "semantic_typography_scrum1061_test"
TYPOGRAPHY_INVENTORY_SKIP = {
    "scripts/dev_console.gd",
    "scripts/ui/semantic_typography.gd",
}
TYPOGRAPHY_INVENTORY_RESOURCE_SUFFIXES = {".tscn", ".tres", ".theme"}
ULTIMATE_EXECUTOR_CONTRACT_TESTS = {
    "controller_runtime_test",
    "controller_player_integration_test",
    "executor_contract_audit_test",
    "executor_primitives_test",
    "registry_package_discovery_test",
}
ULTIMATE_PACKAGE_CONTRACT_TESTS = {
    "executor_primitives_test",
    "registry_contract_test",
    "registry_package_discovery_test",
}
# A class-package rollout changes Player-visible routing, so it must also
# re-prove the Player integration regression and the tracked-tween wall-time
# completion/recast/cancel regression, not just the package contracts.
ULTIMATE_CLASS_PACKAGE_TESTS = ULTIMATE_PACKAGE_CONTRACT_TESTS | {
    "controller_player_integration_test",
    "tracked_tween_natural_completion_test",
}
OFFENSIVE_CONTRACT_TESTS = {
    "attribute_consumability_fan1887_test",
    "attribute_ui_matrix_fan1927_test",
    "damage_type_isolation_test",
    "offensive_scaling_contract_test",
    "stat_formulas_smoke_test",
}
CADENCE_STATUS_CONTRACT_TESTS = {
    "chemist_kit_test",
    "engineer_kit_test",
    "persistent_hazard_contract_test",
    "pool_dot_runaway_gate",
}
BALANCE_CONTRACT_TESTS = {
    "balance_harness_test",
    "class_damage_table_3variants_test",
    "global_damage_balance_smoke_test",
}
DEFENSIVE_CONTRACT_TESTS = {
    "assassin_kit_test",
    "defensive_attribute_contract_fan1895_test",
    "robot_kit_test",
    "thief_kit_test",
}
PATH_TEST_RULES = {
    "scripts/attribute_contract.gd": OFFENSIVE_CONTRACT_TESTS | CADENCE_STATUS_CONTRACT_TESTS,
    # FAN-2179: berserk_rage_trait_test охраняет rage-слой Берсерка — формулу
    # (progression_data.gd), данные CLASS_TRAITS (progression_data_characters.gd),
    # runtime-множитель и ульта-эхо (player.gd), точку применения _rolled_damage
    # (berserk_weapon.gd). До этого тест исполнялся только full-профилем.
    "scripts/berserk_weapon.gd": {"berserk_rage_trait_test"},
    "scripts/class_weapon.gd": CADENCE_STATUS_CONTRACT_TESTS | {"coverage_cap_gate"},
    "scripts/meta_progression_tree_data.gd": {"offensive_scaling_contract_test"},
    "scripts/player.gd": OFFENSIVE_CONTRACT_TESTS | CADENCE_STATUS_CONTRACT_TESTS | DEFENSIVE_CONTRACT_TESTS | {"berserk_rage_trait_test"},
    "scripts/progression_data.gd": OFFENSIVE_CONTRACT_TESTS | CADENCE_STATUS_CONTRACT_TESTS | BALANCE_CONTRACT_TESTS | DEFENSIVE_CONTRACT_TESTS | {"berserk_rage_trait_test"},
    "scripts/progression_data_characters.gd": {"berserk_rage_trait_test"},
    "scripts/progression_data_balance.gd": OFFENSIVE_CONTRACT_TESTS | BALANCE_CONTRACT_TESTS | DEFENSIVE_CONTRACT_TESTS,
    "scripts/progression_data_content.gd": {"offensive_scaling_contract_test"},
    "scripts/progression_data_weapons.gd": {"offensive_scaling_contract_test"} | CADENCE_STATUS_CONTRACT_TESTS | BALANCE_CONTRACT_TESTS,
    "scripts/sentry_turret.gd": {"engineer_kit_test"},
    "scripts/stat_formulas.gd": OFFENSIVE_CONTRACT_TESTS,
    "scripts/status_effects.gd": {"chemist_kit_test", "persistent_hazard_contract_test", "pool_dot_runaway_gate"},
    "scripts/enemy.gd": {"enemy_separation_behavior_test"},
    "scripts/threat_indicators.gd": {"hot_path_cache_test"},
    "scripts/feedback_reporter.gd": {
        "feedback_request_lifecycle_test",
        "feedback_relay_contract_test",
        "feedback_privacy_contract_test",
        "feedback_privacy_ui_test",
        "feedback_retry_policy_test",
        "feedback_webhook_config_test",
    },
    "scripts/ui_screens.gd": {"feedback_privacy_ui_test"},
    "scripts/ui/feedback_overlay.gd": {"feedback_privacy_ui_test"},
    "scripts/ultimates/controller/ultimate_controller.gd": ULTIMATE_EXECUTOR_CONTRACT_TESTS,
    "scripts/ultimates/controller/ultimate_activation.gd": ULTIMATE_EXECUTOR_CONTRACT_TESTS,
    "scripts/ultimates/controller/ultimate_damage_result.gd": ULTIMATE_EXECUTOR_CONTRACT_TESTS,
    "scripts/ultimates/controller/ultimate_player_host.gd": ULTIMATE_EXECUTOR_CONTRACT_TESTS,
    "scripts/ultimates/executors/ultimate_control_executor.gd": ULTIMATE_EXECUTOR_CONTRACT_TESTS,
    "scripts/ultimates/executors/ultimate_executor_library.gd": ULTIMATE_EXECUTOR_CONTRACT_TESTS,
    "scripts/ultimates/executors/ultimate_targeting_primitives.gd": ULTIMATE_EXECUTOR_CONTRACT_TESTS,
    "scripts/ultimates/registry/weapon_ultimate_package_discovery.gd": ULTIMATE_PACKAGE_CONTRACT_TESTS,
    "scripts/ultimates/registry/weapon_ultimate_registry.gd": ULTIMATE_PACKAGE_CONTRACT_TESTS,
    "scripts/ultimates/registry/weapon_ultimate_resolver.gd": ULTIMATE_PACKAGE_CONTRACT_TESTS,
    "scripts/ultimates/schema/weapon_ultimate_schema.gd": ULTIMATE_PACKAGE_CONTRACT_TESTS,
    "data/ultimates/schema/v1/weapon_ultimate_profile.schema.json": ULTIMATE_PACKAGE_CONTRACT_TESTS,
    "tests/feedback_webhook_config_test.gd": {"feedback_webhook_config_test"},
}
DEFAULT_STATIC_TEST_TIMEOUT = 1200.0
DEFAULT_PYTHON_UNIT_IDLE_TIMEOUT = 60.0
DEFAULT_GODOT_IMPORT_TIMEOUT = 1200.0


def discover_godot_tests() -> list[Path]:
    tests: list[Path] = []
    for path in sorted(TEST_DIR.rglob("*.gd")):
        try:
            source = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        if EXTENDS_RE.search(source):
            tests.append(path)
    return tests


def script_resource_path(path: Path) -> str:
    """``res://`` path of a discovered suite, including nested directories."""
    return f"res://{path.relative_to(ROOT).as_posix()}"


def _index_by_name(discovered: Sequence[Path]) -> dict[str, Path]:
    # Selection is name-based (filters, changed-path rules), so two suites that
    # share a stem across directories would silently shadow each other.  Refuse
    # the run instead of guessing which one the caller meant.
    by_name: dict[str, Path] = {}
    collisions: dict[str, list[Path]] = {}
    for path in discovered:
        previous = by_name.get(path.stem)
        if previous is None:
            by_name[path.stem] = path
            continue
        collisions.setdefault(path.stem, [previous]).append(path)
    if collisions:
        details = "; ".join(
            f"{stem} -> " + ", ".join(item.relative_to(ROOT).as_posix() for item in paths)
            for stem, paths in sorted(collisions.items())
        )
        raise RuntimeError(f"ambiguous Godot test names across directories: {details}")
    return by_name


def discover_python_tests() -> list[Path]:
    return sorted(path for path in TEST_DIR.rglob(PYTHON_TEST_PATTERN) if path.is_file())


def _package_chain_reaches(root: Path, directory: Path) -> bool:
    """Whether ``unittest discover -s root`` descends all the way to *directory*."""
    if root == directory:
        return True
    try:
        parts = directory.relative_to(root).parts
    except ValueError:
        return False
    current = root
    for part in parts:
        current = current / part
        if not (current / "__init__.py").is_file():
            return False
    return True


def python_unit_discovery_roots() -> list[Path]:
    """Directories that need their own ``unittest discover`` invocation.

    ``unittest`` refuses to descend into directories that are not importable
    packages, so a single run rooted at ``tests`` silently ignores nested
    suites.  Package subdirectories stay with their parent root so no suite is
    collected twice.
    """
    roots: list[Path] = []
    for directory in sorted({path.parent for path in discover_python_tests()}):
        if any(_package_chain_reaches(root, directory) for root in roots):
            continue
        roots.append(directory)
    return roots


def python_unit_commands() -> list[tuple[str, list[str]]]:
    commands: list[tuple[str, list[str]]] = []
    for directory in python_unit_discovery_roots():
        relative = directory.relative_to(ROOT).as_posix()
        name = "python-unit" if directory == TEST_DIR else f"python-unit:{relative}"
        commands.append((
            name,
            [
                sys.executable,
                "-u",
                "-m",
                "unittest",
                "discover",
                "-v",
                "-s",
                relative,
                "-p",
                PYTHON_TEST_PATTERN,
            ],
        ))
    return commands


def _git_changed_paths(ref: str) -> set[str]:
    result = subprocess.run(
        ["git", "diff", "--name-only", ref, "--"],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"git diff failed for {ref}")
    changed = {line.strip() for line in result.stdout.splitlines() if line.strip()}
    untracked = subprocess.run(
        ["git", "ls-files", "--others", "--exclude-standard"],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if untracked.returncode != 0:
        raise RuntimeError(untracked.stderr.strip() or "git untracked-file discovery failed")
    changed.update(line.strip() for line in untracked.stdout.splitlines() if line.strip())
    return changed


def _resolved_commit(ref: str) -> str:
    result = subprocess.run(
        ["git", "rev-parse", "--verify", f"{ref}^{{commit}}"],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"git rev-parse failed for {ref}")
    return result.stdout.strip()


def _affects_typography_inventory(path: str) -> bool:
    path_parts = Path(path).parts
    if path.startswith("scripts/"):
        return (
            path.endswith(".gd")
            and path not in TYPOGRAPHY_INVENTORY_SKIP
            and "/dev/" not in path
        )
    return (
        Path(path).suffix in TYPOGRAPHY_INVENTORY_RESOURCE_SUFFIXES
        and ".godot" not in path_parts
        and "build" not in path_parts
    )


def select_godot_tests(
    profile: str,
    filters: Sequence[str],
    changed_ref: str,
    skip_umbrella: bool,
) -> list[Path]:
    if profile == "static":
        return []
    by_name = _index_by_name(discover_godot_tests())

    if profile in {"full", "windows"}:
        selected_names = set(by_name)
    else:
        selected_names = set(CORE_CHANGED_TESTS)
        for changed_path in _git_changed_paths(changed_ref):
            selected_names.update(PATH_TEST_RULES.get(changed_path, set()))
            if changed_path.startswith((
                "data/ultimates/classes/",
                "scripts/ultimates/classes/",
            )):
                selected_names.update(ULTIMATE_CLASS_PACKAGE_TESTS)
            if _affects_typography_inventory(changed_path):
                selected_names.add(TYPOGRAPHY_INVENTORY_TEST)
            if changed_path.startswith("tests/") and changed_path.endswith(".gd"):
                selected_names.add(Path(changed_path).stem)
            if changed_path.startswith(("scripts/", "scenes/")) or changed_path in {
                "project.godot", "export_presets.cfg"
            }:
                selected_names.add(RUNTIME_SMOKE)

    if skip_umbrella:
        selected_names.discard(RUNTIME_SMOKE)
    if filters:
        selected_names = {
            name for name in selected_names
            if any(pattern.lower() in name.lower() for pattern in filters)
        }
    return [by_name[name] for name in sorted(selected_names) if name in by_name]


def _run_command(
    name: str,
    command: Sequence[str],
    timeout: float,
    idle_timeout: float | None = None,
    expect_tests: bool = False,
) -> dict:
    started = time.monotonic()
    # Python unittest/compileall commands otherwise create __pycache__ inside
    # the checkout, making the gate fail its own clean-worktree certification.
    with tempfile.TemporaryDirectory(prefix="fsd-python-cache-") as python_cache:
        env = os.environ.copy()
        env["PYTHONPYCACHEPREFIX"] = python_cache
        exit_code, output, timed_out = _run_captured(
            command, env, timeout, idle_timeout=idle_timeout
        )
    if output:
        print(output, end="" if output.endswith("\n") else "\n", flush=True)
    result = {
        "name": name,
        "status": "passed" if exit_code == 0 and not timed_out else "failed",
        "exit_code": exit_code,
        "timed_out": timed_out,
        "duration_seconds": round(time.monotonic() - started, 3),
    }
    if expect_tests:
        # `unittest` reports "Ran 0 tests" with exit code 0, which would let a
        # suite that was never collected certify as green.  Only the trailing
        # summary counts: nested runners echo their own totals into this output.
        counts = RAN_TESTS_RE.findall(output)
        executed = int(counts[-1]) if counts else 0
        result["executed_tests"] = executed
        if result["status"] == "passed" and executed == 0:
            result["status"] = "failed"
            result["errors"] = [f"{name} executed 0 tests"]
            print(f"EMPTY TEST SET: {name} executed 0 tests", file=sys.stderr, flush=True)
    return result


def _decoded_base64_candidates(source: str) -> Iterable[str]:
    literals = BASE64_LITERAL_RE.findall(source)
    # A credential may be split into chunks specifically to avoid raw scanners.
    # Try every short consecutive sequence as well as each standalone literal.
    for start in range(len(literals)):
        combined = ""
        for index in range(start, min(start + 8, len(literals))):
            combined += literals[index]
            padded = combined + "=" * (-len(combined) % 4)
            try:
                decoded = base64.b64decode(padded, validate=True).decode("utf-8")
            except (binascii.Error, UnicodeDecodeError):
                continue
            yield decoded


def _source_secret_errors(rel: str, source: str) -> list[str]:
    errors: list[str] = []
    if REAL_DISCORD_WEBHOOK_RE.search(source):
        errors.append(f"raw Discord webhook credential in {rel}")
    if any(REAL_DISCORD_WEBHOOK_RE.search(decoded) for decoded in _decoded_base64_candidates(source)):
        errors.append(f"Base64-obfuscated Discord webhook credential in {rel}")
    return errors


def _scan_client_secrets() -> list[str]:
    errors: list[str] = []
    # Player sources plus server-side service sources: a credential may live in
    # server secret storage, never in either side of the repository.
    roots = [ROOT / "scripts", ROOT / "scenes", ROOT / "services"]
    files: list[Path] = [ROOT / "project.godot", ROOT / "export_presets.cfg"]
    for directory in roots:
        files.extend(path for path in directory.rglob("*") if path.is_file())
    for path in files:
        try:
            source = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        rel = path.relative_to(ROOT).as_posix()
        errors.extend(_source_secret_errors(rel, source))
    return errors


def _windows_export_config_errors() -> list[str]:
    source = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
    required = {
        'name="Windows Desktop"': "Windows Desktop export preset",
        'binary_format/embed_pck=true': "embedded PCK",
        'texture_format/s3tc_bptc=true': "S3TC/BPTC texture support",
        'binary_format/architecture="x86_64"': "x86_64 architecture",
    }
    return [f"missing {label} in export_presets.cfg" for marker, label in required.items() if marker not in source]


def _range_check_command(changed_ref: str) -> list[str]:
    return ["git", "diff", "--check", f"{changed_ref}...HEAD"]


def _index_check_command() -> list[str]:
    return ["git", "diff", "--cached", "--check"]


def _worktree_status() -> list[str]:
    result = subprocess.run(
        ["git", "status", "--porcelain=v1", "--untracked-files=all"],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "git worktree status failed")
    return [line for line in result.stdout.splitlines() if line]


def _is_certifying(
    args: argparse.Namespace,
    worktree_status: Sequence[str],
    changed_ref_is_integration_base: bool,
) -> bool:
    return not (
        args.filters
        or args.skip_static
        or args.skip_godot
        or args.skip_umbrella
        or args.shard_count != 1
        or worktree_status
        or not changed_ref_is_integration_base
    )


def run_static_checks(
    fail_fast: bool,
    timeout: float,
    changed_ref: str,
    python_unit_idle_timeout: float = DEFAULT_PYTHON_UNIT_IDLE_TIMEOUT,
) -> list[dict]:
    python_commands = python_unit_commands()
    commands: list[tuple[str, list[str]]] = [
        ("repository-invariants", [sys.executable, "tools/quality_static_guard.py"]),
        *python_commands,
        ("python-syntax", [sys.executable, "-m", "compileall", "-q", "tools", "tests"]),
        ("asset-audit", [sys.executable, "tools/test_audit_unused_assets.py"]),
        ("constellation-validator", [sys.executable, "tools/test_validate_scrum1067_constellation_spec.py"]),
        ("runtime-manifest-validator", [sys.executable, "tools/test_validate_scrum1068_runtime_manifest.py"]),
        ("git-diff-check", ["git", "diff", "--check"]),
        ("git-index-check", _index_check_command()),
        ("git-head-check", ["git", "show", "--check", "--format=", "HEAD"]),
        ("git-range-check", _range_check_command(changed_ref)),
    ]
    shell_scripts = sorted((ROOT / "tools").glob("*.sh")) + sorted((ROOT / "scripts").glob("*.sh"))
    if shell_scripts:
        commands.append(("shell-syntax", ["bash", "-n", *[str(path) for path in shell_scripts]]))

    # An empty Python set is fail-closed in `main()`, never here.  `main()`
    # discovers the same files (`python_tests = discover_python_tests()`),
    # records `no Python tests discovered under tests/` for an empty result
    # (`if not python_tests: discovery_errors.append(...)`) and then skips this
    # function outright (`[] if (args.skip_static or discovery_errors) else
    # run_static_checks(...)`).  `python_commands` is empty exactly when
    # `discover_python_tests()` is, so a guard here could not run from any CLI
    # invocation — the observable contract belongs to `test-discovery` and is
    # covered by `test_missing_python_tests_fail_closed_through_cli`.
    results: list[dict] = []
    for name, command in commands:
        print(f"STATIC {name}", flush=True)
        is_python_unit = name.startswith("python-unit")
        outcome = _run_command(
            name,
            command,
            timeout,
            idle_timeout=python_unit_idle_timeout if is_python_unit else None,
            expect_tests=is_python_unit,
        )
        results.append(outcome)
        if outcome["status"] == "failed" and fail_fast:
            return results

    secret_errors = _scan_client_secrets()
    for error in secret_errors:
        print(f"SECRET FAIL: {error}", file=sys.stderr)
    results.append({
        "name": "client-secret-scan",
        "status": "failed" if secret_errors else "passed",
        "exit_code": 1 if secret_errors else 0,
        "duration_seconds": 0.0,
        "errors": secret_errors,
    })
    windows_errors = _windows_export_config_errors()
    for error in windows_errors:
        print(f"WINDOWS EXPORT FAIL: {error}", file=sys.stderr)
    results.append({
        "name": "windows-export-config",
        "status": "failed" if windows_errors else "passed",
        "exit_code": 1 if windows_errors else 0,
        "duration_seconds": 0.0,
        "errors": windows_errors,
    })
    return results


def _godot_environment(
    user_data: Path,
    *,
    exclusive: bool = False,
) -> dict[str, str]:
    env = os.environ.copy()
    # Resolve before overriding HOME: the conventional macOS binary lives under
    # the real user's Downloads directory, while each test gets a scratch HOME.
    if not env.get("GODOT_BIN") and not env.get("GODOT"):
        candidates = [shutil.which("godot4"), shutil.which("godot")]
        if sys.platform == "darwin":
            candidates.insert(0, str(Path.home() / "Downloads/Godot.app/Contents/MacOS/Godot"))
        for candidate in candidates:
            if candidate and Path(candidate).is_file() and os.access(candidate, os.X_OK):
                env["GODOT_BIN"] = candidate
                break
    env["HOME"] = str(user_data)
    env["XDG_DATA_HOME"] = str(user_data)
    env["APPDATA"] = str(user_data)
    env["LOCALAPPDATA"] = str(user_data)
    # Callers own the timing classification.  Setting an explicit empty value
    # keeps imports and ordinary suites non-exclusive even if the parent shell
    # happens to export FSD_GODOT_EXCLUSIVE=1.
    env["FSD_GODOT_EXCLUSIVE"] = "1" if exclusive else ""
    return env


def _create_windows_job() -> int:
    import ctypes
    from ctypes import wintypes

    class _IoCounters(ctypes.Structure):
        _fields_ = [
            (name, ctypes.c_ulonglong)
            for name in (
                "ReadOperationCount",
                "WriteOperationCount",
                "OtherOperationCount",
                "ReadTransferCount",
                "WriteTransferCount",
                "OtherTransferCount",
            )
        ]

    class _BasicLimitInformation(ctypes.Structure):
        _fields_ = [
            ("PerProcessUserTimeLimit", ctypes.c_longlong),
            ("PerJobUserTimeLimit", ctypes.c_longlong),
            ("LimitFlags", wintypes.DWORD),
            ("MinimumWorkingSetSize", ctypes.c_size_t),
            ("MaximumWorkingSetSize", ctypes.c_size_t),
            ("ActiveProcessLimit", wintypes.DWORD),
            ("Affinity", ctypes.c_size_t),
            ("PriorityClass", wintypes.DWORD),
            ("SchedulingClass", wintypes.DWORD),
        ]

    class _ExtendedLimitInformation(ctypes.Structure):
        _fields_ = [
            ("BasicLimitInformation", _BasicLimitInformation),
            ("IoInfo", _IoCounters),
            ("ProcessMemoryLimit", ctypes.c_size_t),
            ("JobMemoryLimit", ctypes.c_size_t),
            ("PeakProcessMemoryUsed", ctypes.c_size_t),
            ("PeakJobMemoryUsed", ctypes.c_size_t),
        ]

    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.CreateJobObjectW.argtypes = [wintypes.LPVOID, wintypes.LPCWSTR]
    kernel32.CreateJobObjectW.restype = wintypes.HANDLE
    kernel32.SetInformationJobObject.argtypes = [
        wintypes.HANDLE,
        ctypes.c_int,
        wintypes.LPVOID,
        wintypes.DWORD,
    ]
    kernel32.SetInformationJobObject.restype = wintypes.BOOL
    kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
    kernel32.CloseHandle.restype = wintypes.BOOL

    job = kernel32.CreateJobObjectW(None, None)
    if not job:
        raise ctypes.WinError(ctypes.get_last_error())
    limits = _ExtendedLimitInformation()
    limits.BasicLimitInformation.LimitFlags = 0x00002000  # KILL_ON_JOB_CLOSE
    if not kernel32.SetInformationJobObject(
        job, 9, ctypes.byref(limits), ctypes.sizeof(limits)
    ):
        error = ctypes.WinError(ctypes.get_last_error())
        kernel32.CloseHandle(job)
        raise error
    return int(job)


def _close_windows_handle(handle: int) -> None:
    import ctypes
    from ctypes import wintypes

    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
    kernel32.CloseHandle.restype = wintypes.BOOL
    if not kernel32.CloseHandle(handle):
        raise ctypes.WinError(ctypes.get_last_error())


def _run_in_windows_job(command: Sequence[str]) -> int:
    import ctypes
    from ctypes import wintypes

    raw_handle = os.environ.pop(_WINDOWS_JOB_HANDLE_ENV, "")
    try:
        job = int(raw_handle)
    except ValueError:
        print("quality_gate: missing Windows job handle", file=sys.stderr, flush=True)
        return 125

    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.GetCurrentProcess.restype = wintypes.HANDLE
    kernel32.AssignProcessToJobObject.argtypes = [wintypes.HANDLE, wintypes.HANDLE]
    kernel32.AssignProcessToJobObject.restype = wintypes.BOOL
    if not kernel32.AssignProcessToJobObject(job, kernel32.GetCurrentProcess()):
        error = ctypes.WinError(ctypes.get_last_error())
        _close_windows_handle(job)
        print(
            f"quality_gate: Windows job assignment failed: {error}",
            file=sys.stderr,
            flush=True,
        )
        return 125
    _close_windows_handle(job)

    try:
        return subprocess.call(command, cwd=ROOT)
    except OSError as error:
        print(f"quality_gate: command launch failed: {error}", file=sys.stderr, flush=True)
        return 125


def _terminate_process(
    process: subprocess.Popen[str], windows_job: int | None = None
) -> None:
    try:
        if os.name == "nt":
            # Popen.kill uses the retained process handle, not a recyclable PID.
            if process.poll() is None:
                process.kill()
            if windows_job is not None:
                import ctypes
                from ctypes import wintypes

                kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
                kernel32.TerminateJobObject.argtypes = [wintypes.HANDLE, wintypes.UINT]
                kernel32.TerminateJobObject.restype = wintypes.BOOL
                if not kernel32.TerminateJobObject(windows_job, 124):
                    raise ctypes.WinError(ctypes.get_last_error())
        else:
            os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        # The direct process may have exited while its inherited stdout is
        # still draining.  The reader lifecycle below remains authoritative.
        pass


def _run_captured(
    command: Sequence[str],
    env: dict[str, str],
    timeout: float,
    *,
    idle_timeout: float | None = None,
) -> tuple[int, str, bool]:
    kwargs: dict = {
        "cwd": ROOT,
        "env": env,
        # FAN-2648: decode like godot_gate does.  Godot always emits UTF-8,
        # while text=True decodes with the locale codec in strict mode: on a
        # non-UTF-8 Windows locale (cp1251) the first Cyrillic byte pair kills
        # the drain thread with UnicodeDecodeError and silently truncates the
        # captured output that the push_error/fatal verdicts read.
        "encoding": "utf-8",
        "errors": "replace",
        "stdout": subprocess.PIPE,
        "stderr": subprocess.STDOUT,
    }
    windows_job: int | None = None
    launch_command = command
    if os.name == "nt":
        windows_job = _create_windows_job()
        runner_env = env.copy()
        runner_env[_WINDOWS_JOB_HANDLE_ENV] = str(windows_job)
        startupinfo = subprocess.STARTUPINFO()
        startupinfo.lpAttributeList = {"handle_list": [windows_job]}
        kwargs.update({
            "env": runner_env,
            "startupinfo": startupinfo,
            "close_fds": True,
            "creationflags": subprocess.CREATE_NEW_PROCESS_GROUP,
        })
        launch_command = [
            sys.executable,
            str(Path(__file__).resolve()),
            _WINDOWS_JOB_RUNNER_ARG,
            *command,
        ]
        os.set_handle_inheritable(windows_job, True)
    else:
        kwargs["start_new_session"] = True
    try:
        try:
            process = subprocess.Popen(launch_command, **kwargs)
        finally:
            if windows_job is not None:
                os.set_handle_inheritable(windows_job, False)
    except BaseException:
        if windows_job is not None:
            _close_windows_handle(windows_job)
        raise

    if idle_timeout is None and os.name != "nt":
        try:
            output, _ = process.communicate(timeout=timeout)
            return process.returncode, output, False
        except subprocess.TimeoutExpired:
            _terminate_process(process)
            output, _ = process.communicate()
            return 124, output, True

    try:
        output_parts: list[str] = []
        reader_done = threading.Event()
        started = time.monotonic()
        last_output_at = [started]

        def drain_output() -> None:
            assert process.stdout is not None
            try:
                while True:
                    chunk = process.stdout.readline()
                    if not chunk:
                        return
                    output_parts.append(chunk)
                    last_output_at[0] = time.monotonic()
            except (OSError, ValueError):
                pass
            finally:
                reader_done.set()

        reader = threading.Thread(
            target=drain_output, name="quality-output-reader", daemon=True
        )
        reader.start()
        timed_out = False
        while process.poll() is None or not reader_done.is_set():
            now = time.monotonic()
            if now - started >= timeout or (
                idle_timeout is not None and now - last_output_at[0] >= idle_timeout
            ):
                timed_out = True
                break
            time.sleep(0.01)

        if timed_out:
            _terminate_process(process, windows_job)
        try:
            process.wait(timeout=_WINDOWS_CLEANUP_TIMEOUT if os.name == "nt" else None)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=_WINDOWS_CLEANUP_TIMEOUT)
        # Never close a buffered stream while another thread may be in readline().
        # A timed-out process group is killed above; its inherited descriptors then
        # reach EOF and let the reader finish cleanly.
        reader.join(timeout=_WINDOWS_CLEANUP_TIMEOUT if os.name == "nt" else None)
        if reader.is_alive():
            if process.stdout is not None:
                process.stdout.close()
            reader.join(timeout=_WINDOWS_CLEANUP_TIMEOUT)
            if reader.is_alive():
                raise RuntimeError("Windows job cleanup did not close the capture reader")
        if process.stdout is not None:
            process.stdout.close()
        return (124 if timed_out else process.returncode), "".join(output_parts), timed_out
    finally:
        if windows_job is not None:
            _close_windows_handle(windows_job)


def fatal_output_signal(output: str) -> str:
    """Name the diagnostic that proves a Godot suite reported a failure.

    A suite must not be able to end green after it has announced a failure, so
    detection may not depend on the process exit code alone: ``SceneTree.quit``
    is deferred, and a later success ``quit()`` overwrites an already requested
    ``quit(1)``.  Every failure path in ``tests/`` announces itself through
    ``push_error()`` first, and that call is what this reads.  Returns an empty
    string when the output carries no failure diagnostic.
    """
    match = FATAL_OUTPUT_RE.search(output)
    if match is not None:
        return match.group(0)
    if PUSH_ERROR_FRAME_RE.search(output) is not None:
        return "push_error"
    return ""


def _import_prepass_commands(host_os: str | None = None) -> list[list[str]]:
    """Ordered gated commands that warm and then validate the import cache."""
    ensure = [
        sys.executable,
        str(GODOT_GATE),
        "--headless",
        "--path",
        str(ROOT),
        "--ensure-import-cache",
    ]
    if (os.name if host_os is None else host_os) != "nt":
        return [ensure]
    # FAN-2648: `--ensure-import-cache` imports via `--import --quit`, and that
    # flag pair reproducibly crashes Godot 4.7 with 0xc0000005 on the native
    # Windows runtime, while `--import` alone completes the import and exits
    # cleanly.  Import through the gate passthrough first; the trailing ensure
    # call then only proves the cache is complete without relaunching Godot.
    # The ensure step must not carry `--import` itself, or godot_gate would
    # skip its cache check and rubber-stamp an incomplete import.
    return [
        [
            sys.executable,
            str(GODOT_GATE),
            "--headless",
            "--path",
            str(ROOT),
            "--import",
        ],
        ensure,
    ]


def run_godot_import(timeout: float) -> dict:
    """Warm the shared project import cache without spending a suite's budget."""
    started = time.monotonic()
    exit_code, output, timed_out = 0, "", False
    with tempfile.TemporaryDirectory(prefix="fsd-import-") as scratch:
        user_data = Path(scratch).resolve()
        environment = _godot_environment(user_data, exclusive=False)
        for command in _import_prepass_commands():
            # Every step shares one bounded budget; a crash, nonzero exit or
            # timeout is terminal and must not reach the next step.
            budget = timeout - (time.monotonic() - started)
            exit_code, step_output, timed_out = _run_captured(
                command,
                environment,
                max(budget, 0.0),
            )
            output += step_output
            if exit_code != 0 or timed_out:
                break
    if IMPORT_CACHE_MISSING_MESSAGE in output:
        print(IMPORT_CACHE_MISSING_MESSAGE, flush=True)
    passed = exit_code == 0 and not timed_out
    if passed:
        print("PASS  Godot import cache pre-pass", flush=True)
    else:
        reason = f"exit {exit_code}"
        if timed_out:
            reason += f", timeout after {timeout:.0f}s"
        print(f"FAIL  Godot import cache pre-pass ({reason})", file=sys.stderr, flush=True)
        print(output[-12000:], file=sys.stderr)
    return {
        "name": "godot-import-cache",
        "status": "passed" if passed else "failed",
        "exit_code": exit_code,
        "timed_out": timed_out,
        "duration_seconds": round(time.monotonic() - started, 3),
    }


def run_godot_test(path: Path, timeout: float) -> dict:
    started = time.monotonic()
    name = path.stem
    script = script_resource_path(path)
    exclusive = script in TIMING_SENSITIVE_GODOT_SCRIPTS
    with tempfile.TemporaryDirectory(prefix=f"fsd-{name}-") as scratch:
        user_data = Path(scratch).resolve()
        command = [
            sys.executable,
            str(GODOT_GATE),
            "--headless",
            "--path",
            str(ROOT),
            "--script",
            script,
            "--",
            f"--user-data-dir={user_data}",
        ]
        exit_code, output, timed_out = _run_captured(
            command,
            _godot_environment(user_data, exclusive=exclusive),
            timeout,
        )
    diagnostic = fatal_output_signal(output)
    passed = exit_code == 0 and not diagnostic and not timed_out
    if passed:
        print(f"PASS  {name}", flush=True)
    else:
        reason = f"exit {exit_code}"
        if timed_out:
            reason += f", timeout after {timeout:.0f}s"
        if diagnostic:
            reason += f", fatal diagnostic: {diagnostic}"
        print(f"FAIL  {name} ({reason})", file=sys.stderr, flush=True)
        print(output[-12000:], file=sys.stderr)
    return {
        "name": name,
        "script": script,
        "status": "passed" if passed else "failed",
        "exit_code": exit_code,
        "timed_out": timed_out,
        "fatal_diagnostic": diagnostic,
        "duration_seconds": round(time.monotonic() - started, 3),
    }


def _write_report(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def _report_payload(
    *,
    selected_godot_tests: int,
    executed_python_tests: int,
    git_sha: str,
    changed_ref: str,
    changed_base_sha: str,
    static_checks: list[dict],
    godot_tests: list[dict],
    **metadata: object,
) -> dict:
    """Keep the documented quality-report contract in one schema source."""
    return {
        "selected_godot_tests": selected_godot_tests,
        "executed_python_tests": executed_python_tests,
        "git_sha": git_sha,
        "changed_ref": changed_ref,
        "changed_base_sha": changed_base_sha,
        "static_checks": static_checks,
        "godot_tests": godot_tests,
        **metadata,
    }


def _combine_reports(source: Path, output: Path, expected_shard_count: int | None) -> int:
    """Fail closed while joining static and full-profile shard reports."""
    report_paths = sorted(source.rglob("quality_gate_report.json"))
    reports: list[tuple[Path, dict]] = []
    errors: list[str] = []
    for path in report_paths:
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            errors.append(f"cannot read shard report {path}: {exc}")
            continue
        if not isinstance(payload, dict):
            errors.append(f"shard report {path} is not a JSON object")
            continue
        reports.append((path, payload))

    expected_sha = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True
    ).strip()
    integration_base_sha = _resolved_commit(INTEGRATION_CHANGED_REF)
    expected_scripts = [
        script_resource_path(path)
        for path in select_godot_tests("full", [], INTEGRATION_CHANGED_REF, False)
    ]
    expected_script_set = set(expected_scripts)
    static_reports = [item for item in reports if item[1].get("profile") == "static"]
    shard_reports = [
        item
        for item in reports
        if item[1].get("profile") == "full" and isinstance(item[1].get("shard"), dict)
    ]
    if len(static_reports) != 1:
        errors.append(f"expected exactly one static report, found {len(static_reports)}")
    if not shard_reports:
        errors.append("no full-profile shard reports were downloaded")

    static_checks: list[dict] = []
    if len(static_reports) == 1:
        static = static_reports[0][1]
        static_checks = static.get("static_checks", [])
        if static.get("git_sha") != expected_sha:
            errors.append(f"static report SHA is {static.get('git_sha')}, expected {expected_sha}")
        if static.get("status") != "passed":
            errors.append(f"static report status is {static.get('status', 'missing')}")

    seen_scripts: set[str] = set()
    seen_shards: set[int] = set()
    godot_tests: list[dict] = []
    shard_summaries: list[dict] = []
    for path, report in shard_reports:
        shard = report["shard"]
        index = shard.get("index")
        count = shard.get("count")
        selected = report.get("selected_godot_test_scripts", [])
        executed = report.get("godot_tests", [])
        label = f"shard {index}/{count}"
        if not isinstance(index, int) or not isinstance(count, int):
            errors.append(f"{label} has invalid shard metadata")
        else:
            if expected_shard_count is not None and count != expected_shard_count:
                errors.append(f"{label} has unexpected shard count")
            if index in seen_shards:
                errors.append(f"duplicate shard index: {index}")
            seen_shards.add(index)
        shard_summaries.append({
            "path": str(path.relative_to(source)),
            "index": index,
            "count": count,
            "status": report.get("status"),
            "selected_godot_tests": len(selected),
            "executed_godot_tests": len(executed),
        })
        if report.get("git_sha") != expected_sha:
            errors.append(f"{label} SHA is {report.get('git_sha')}, expected {expected_sha}")
        if report.get("status") == "failed":
            errors.append(f"{label} reported failure")
        if len(selected) != len(executed):
            errors.append(f"{label} executed {len(executed)} of {len(selected)} selected suites")
        for result in executed:
            script = result.get("script")
            if not isinstance(script, str):
                errors.append(f"{label} has a suite without a script path")
                continue
            if script in seen_scripts:
                errors.append(f"duplicate Godot suite across shards: {script}")
            seen_scripts.add(script)
            godot_tests.append(result)
            if result.get("status") != "passed":
                errors.append(f"{label} failed {script}")

    missing_scripts = sorted(expected_script_set - seen_scripts)
    unexpected_scripts = sorted(seen_scripts - expected_script_set)
    if missing_scripts:
        preview = ", ".join(missing_scripts[:10])
        suffix = " …" if len(missing_scripts) > 10 else ""
        errors.append(f"missing {len(missing_scripts)} Godot suites: {preview}{suffix}")
    if unexpected_scripts:
        preview = ", ".join(unexpected_scripts[:10])
        suffix = " …" if len(unexpected_scripts) > 10 else ""
        errors.append(f"unexpected {len(unexpected_scripts)} Godot suites: {preview}{suffix}")
    if expected_shard_count is not None:
        missing_shards = sorted(set(range(expected_shard_count)) - seen_shards)
        unexpected_shards = sorted(seen_shards - set(range(expected_shard_count)))
        if missing_shards:
            errors.append(f"missing shard indexes: {', '.join(map(str, missing_shards))}")
        if unexpected_shards:
            errors.append(f"unexpected shard indexes: {', '.join(map(str, unexpected_shards))}")

    payload = _report_payload(
        profile="full",
        certifying=not errors,
        filters=[],
        skip_static=False,
        skip_godot=False,
        worktree_clean=True,
        worktree_status=[],
        discovered_godot_tests=len(expected_scripts),
        selected_godot_tests=len(expected_scripts),
        selected_godot_test_scripts=expected_scripts,
        executed_python_tests=sum(
            item.get("executed_tests", 0) for item in static_checks
        ),
        git_sha=expected_sha,
        changed_ref=INTEGRATION_CHANGED_REF,
        changed_base_sha=integration_base_sha,
        platform=sys.platform,
        status="failed" if errors else "passed",
        static_checks=static_checks,
        godot_tests=sorted(godot_tests, key=lambda item: item.get("script", "")),
        shards=sorted(shard_summaries, key=lambda item: (str(item["count"]), str(item["index"]))),
        errors=errors,
    )
    _write_report(output, payload)
    for error in errors:
        print(f"QUALITY MERGE FAIL: {error}", file=sys.stderr, flush=True)
    print(
        f"QUALITY {payload['status'].upper()}: "
        f"{len(static_checks)} static, {len(godot_tests)} Godot; report={output}",
        flush=True,
    )
    return 1 if errors else 0


def _parse_args(argv: Sequence[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("filters", nargs="*", help="test-name substring filters")
    parser.add_argument("--profile", choices=("changed", "full", "windows", "static"), default="changed")
    parser.add_argument(
        "--static-only",
        action="store_true",
        help="CI compatibility alias for the certifying static profile",
    )
    parser.add_argument(
        "--changed-ref", default=INTEGRATION_CHANGED_REF, help="diff base for changed profile"
    )
    parser.add_argument("--skip-static", action="store_true")
    parser.add_argument("--skip-godot", action="store_true")
    parser.add_argument("--skip-umbrella", action="store_true")
    parser.add_argument("--fail-fast", action="store_true")
    parser.add_argument(
        "--shard-count",
        type=int,
        default=1,
        help="deterministically split selected Godot suites across this many runners",
    )
    parser.add_argument(
        "--shard-index",
        type=int,
        default=0,
        help="zero-based shard index for --shard-count",
    )
    parser.add_argument(
        "--test-timeout",
        type=float,
        default=float(os.getenv("FSD_GODOT_TEST_TIMEOUT", "900")),
        help="per-test timeout in seconds (default: 900)",
    )
    parser.add_argument(
        "--import-timeout",
        type=float,
        default=float(os.getenv("FSD_GODOT_IMPORT_TIMEOUT", str(DEFAULT_GODOT_IMPORT_TIMEOUT))),
        help="import-cache pre-pass timeout in seconds (default: 1200)",
    )
    parser.add_argument(
        "--static-timeout",
        type=float,
        default=float(os.getenv("FSD_STATIC_TEST_TIMEOUT", str(DEFAULT_STATIC_TEST_TIMEOUT))),
        help="per-static-command timeout in seconds (default: 1200)",
    )
    parser.add_argument(
        "--python-unit-idle-timeout",
        type=float,
        default=float(
            os.getenv("FSD_PYTHON_UNIT_IDLE_TIMEOUT", str(DEFAULT_PYTHON_UNIT_IDLE_TIMEOUT))
        ),
        help="maximum silent interval for verbose Python discovery (default: 60)",
    )
    parser.add_argument("--list", action="store_true", help="list selected Godot tests and exit")
    parser.add_argument("--report", default="build/quality_gate_report.json")
    parser.add_argument(
        "--combine-reports",
        type=Path,
        help="merge downloaded static and full-profile shard reports",
    )
    parser.add_argument(
        "--expected-shard-count",
        type=int,
        help="require this many full-profile shards while combining reports",
    )
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = _parse_args(argv)
    if args.combine_reports:
        if args.expected_shard_count is not None and args.expected_shard_count < 1:
            print("quality_gate: expected shard count must be positive", file=sys.stderr)
            return 2
        return _combine_reports(
            (ROOT / args.combine_reports).resolve(),
            (ROOT / args.report).resolve(),
            args.expected_shard_count,
        )
    if args.static_only:
        args.profile = "static"
    if args.shard_count < 1 or not 0 <= args.shard_index < args.shard_count:
        print("quality_gate: shard index must be within a positive shard count", file=sys.stderr)
        return 2
    if (
        args.test_timeout <= 0
        or args.import_timeout <= 0
        or args.static_timeout <= 0
        or args.python_unit_idle_timeout <= 0
    ):
        print("quality_gate: test/import/static/idle timeouts must be positive", file=sys.stderr)
        return 2
    if args.skip_static and (args.skip_godot or args.profile == "static"):
        print("quality_gate: refusing an empty run (--skip-static + --skip-godot)", file=sys.stderr)
        return 2
    if args.profile == "windows" and os.name != "nt":
        print("quality_gate: windows profile must run natively on Windows", file=sys.stderr)
        return 2
    try:
        changed_base_sha = _resolved_commit(args.changed_ref)
        selected = select_godot_tests(
            args.profile, args.filters, args.changed_ref, args.skip_umbrella
        )
        selected = selected[args.shard_index::args.shard_count]
        initial_worktree_status = _worktree_status()
    except RuntimeError as exc:
        print(f"quality_gate: {exc}", file=sys.stderr)
        return 2

    discovered = discover_godot_tests()
    python_tests = discover_python_tests()
    # Fail closed on every empty set: a scope that collected nothing must read
    # as FAILED, never as a green run that simply had nothing to do.
    discovery_errors: list[str] = []
    if not discovered:
        discovery_errors.append(f"no Godot tests discovered under {TEST_DIR.name}/")
    if not python_tests:
        discovery_errors.append(f"no Python tests discovered under {TEST_DIR.name}/")
    if args.profile != "static" and not args.skip_godot and not selected:
        scope = f"profile {args.profile}"
        if args.filters:
            scope += f" with filters {' '.join(args.filters)}"
        discovery_errors.append(f"no Godot tests selected for {scope}")

    if args.list:
        for path in selected:
            print(path.relative_to(ROOT).as_posix())
        print(f"Selected {len(selected)} Godot test(s).")
        for path in python_tests:
            print(path.relative_to(ROOT).as_posix())
        print(f"Discovered {len(python_tests)} Python test file(s).")
        for error in discovery_errors:
            print(f"EMPTY TEST SET: {error}", file=sys.stderr)
        return 1 if discovery_errors else 0

    started = time.monotonic()
    for error in discovery_errors:
        print(f"EMPTY TEST SET: {error}", file=sys.stderr, flush=True)
    # An empty scope is terminal, so it short-circuits the static suite: the
    # verdict is already FAILED and the remaining checks cannot change it.
    static_results = [] if (args.skip_static or discovery_errors) else run_static_checks(
        args.fail_fast,
        args.static_timeout,
        args.changed_ref,
        args.python_unit_idle_timeout,
    )
    # Discovery evidence is part of every run, including `--skip-static` and the
    # static CI profile: it is what proves the suites were collected at all.
    static_results.append({
        "name": "test-discovery",
        "status": "failed" if discovery_errors else "passed",
        "exit_code": 1 if discovery_errors else 0,
        "duration_seconds": 0.0,
        "errors": discovery_errors,
        "discovered_godot_tests": len(discovered),
        "selected_godot_tests": len(selected),
        "selected_godot_test_scripts": [script_resource_path(path) for path in selected],
        "discovered_python_tests": len(python_tests),
    })
    failed = any(item["status"] == "failed" for item in static_results)
    godot_results: list[dict] = []
    if (
        args.profile != "static"
        and not args.skip_godot
        and not discovery_errors
        and not (failed and args.fail_fast)
    ):
        print("GODOT warming import cache via semaphore gate", flush=True)
        import_result = run_godot_import(args.import_timeout)
        if import_result["status"] == "failed":
            failed = True
        else:
            print(f"GODOT running {len(selected)} test(s) via semaphore gate", flush=True)
            for index, path in enumerate(selected, start=1):
                print(
                    f"GODOT {index}/{len(selected)} {path.relative_to(ROOT).as_posix()}",
                    flush=True,
                )
                outcome = run_godot_test(path, args.test_timeout)
                godot_results.append(outcome)
                if outcome["status"] == "failed":
                    failed = True
                    if args.fail_fast:
                        break
    else:
        import_result = None

    try:
        final_worktree_status = _worktree_status()
    except RuntimeError as exc:
        print(f"quality_gate: {exc}", file=sys.stderr)
        return 2
    worktree_status = list(dict.fromkeys(initial_worktree_status + final_worktree_status))
    changed_ref_is_integration_base = args.changed_ref == INTEGRATION_CHANGED_REF
    certifying = _is_certifying(
        args, worktree_status, changed_ref_is_integration_base
    )
    if not changed_ref_is_integration_base:
        print(
            "QUALITY NON-CERTIFYING: changed ref "
            f"{args.changed_ref} is not the configured integration ref "
            f"{INTEGRATION_CHANGED_REF} (resolves to {changed_base_sha})",
            file=sys.stderr,
        )
    if worktree_status:
        print("QUALITY NON-CERTIFYING: worktree is not clean", file=sys.stderr)
        for line in worktree_status:
            print(f"  {line}", file=sys.stderr)
    status = "failed" if failed else ("passed" if certifying else "partial_pass")
    payload = _report_payload(
        profile=args.profile,
        certifying=certifying,
        filters=list(args.filters),
        skip_static=args.skip_static,
        skip_godot=args.skip_godot,
        skip_umbrella=args.skip_umbrella,
        godot_test_timeout_seconds=args.test_timeout,
        godot_import_timeout_seconds=args.import_timeout,
        static_timeout_seconds=args.static_timeout,
        python_unit_idle_timeout_seconds=args.python_unit_idle_timeout,
        worktree_clean=not worktree_status,
        worktree_status=worktree_status,
        discovered_godot_tests=len(discovered),
        selected_godot_tests=len(selected),
        selected_godot_test_scripts=[script_resource_path(path) for path in selected],
        discovered_python_tests=len(python_tests),
        executed_python_tests=sum(
            item.get("executed_tests", 0) for item in static_results
        ),
        git_sha=subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        changed_ref=args.changed_ref,
        changed_base_sha=changed_base_sha,
        platform=sys.platform,
        status=status,
        duration_seconds=round(time.monotonic() - started, 3),
        static_checks=static_results,
        godot_import_prepass=import_result,
        godot_tests=godot_results,
        shard={"index": args.shard_index, "count": args.shard_count},
    )
    _write_report((ROOT / args.report).resolve(), payload)
    print(
        f"QUALITY {payload['status'].upper()}: "
        f"{len(static_results)} static, {len(godot_results)} Godot; "
        f"report={args.report}",
        flush=True,
    )
    return 1 if failed else 0


if __name__ == "__main__":
    if os.name == "nt" and len(sys.argv) > 1 and sys.argv[1] == _WINDOWS_JOB_RUNNER_ARG:
        raise SystemExit(_run_in_windows_job(sys.argv[2:]))
    raise SystemExit(main())
