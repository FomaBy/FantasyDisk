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

CORE_CHANGED_TESTS = {
    "combat_target_query_cache_test",
    "runtime_smoke_combat_test",
    "runtime_smoke_ui_test",
    "weapon_ultimate_timing_distinctness_test",
}
TYPOGRAPHY_INVENTORY_TEST = "semantic_typography_scrum1061_test"
TYPOGRAPHY_INVENTORY_SKIP = {
    "scripts/dev_console.gd",
    "scripts/ui/semantic_typography.gd",
}
TYPOGRAPHY_INVENTORY_RESOURCE_SUFFIXES = {".tscn", ".tres", ".theme"}
PATH_TEST_RULES = {
    "scripts/class_weapon.gd": {"engineer_kit_test", "persistent_hazard_contract_test"},
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


def _is_certifying(args: argparse.Namespace, worktree_status: Sequence[str]) -> bool:
    return not (
        args.filters
        or args.skip_static
        or args.skip_godot
        or args.skip_umbrella
        or worktree_status
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


def _terminate_process(process: subprocess.Popen[str]) -> None:
    try:
        if os.name == "nt":
            subprocess.run(
                ["taskkill", "/F", "/T", "/PID", str(process.pid)],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            )
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
        "text": True,
        "stdout": subprocess.PIPE,
        "stderr": subprocess.STDOUT,
    }
    if os.name == "nt":
        kwargs["creationflags"] = subprocess.CREATE_NEW_PROCESS_GROUP
    else:
        kwargs["start_new_session"] = True
    process = subprocess.Popen(command, **kwargs)
    if idle_timeout is None:
        try:
            output, _ = process.communicate(timeout=timeout)
            return process.returncode, output, False
        except subprocess.TimeoutExpired:
            _terminate_process(process)
            output, _ = process.communicate()
            return 124, output, True

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

    reader = threading.Thread(target=drain_output, name="quality-output-reader", daemon=True)
    reader.start()
    timed_out = False
    while process.poll() is None or not reader_done.is_set():
        now = time.monotonic()
        if now - started >= timeout or now - last_output_at[0] >= idle_timeout:
            timed_out = True
            break
        time.sleep(0.01)

    if timed_out:
        _terminate_process(process)
    process.wait()
    # Never close a buffered stream while another thread may be in readline().
    # A timed-out process group is killed above; its inherited descriptors then
    # reach EOF and let the reader finish cleanly.
    reader.join()
    if process.stdout is not None:
        process.stdout.close()
    return (124 if timed_out else process.returncode), "".join(output_parts), timed_out


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


def run_godot_import(timeout: float) -> dict:
    """Warm the shared project import cache without spending a suite's budget."""
    started = time.monotonic()
    with tempfile.TemporaryDirectory(prefix="fsd-import-") as scratch:
        user_data = Path(scratch).resolve()
        command = [
            sys.executable,
            str(GODOT_GATE),
            "--headless",
            "--path",
            str(ROOT),
            "--ensure-import-cache",
        ]
        exit_code, output, timed_out = _run_captured(
            command,
            _godot_environment(user_data, exclusive=False),
            timeout,
        )
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


def _parse_args(argv: Sequence[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("filters", nargs="*", help="test-name substring filters")
    parser.add_argument("--profile", choices=("changed", "full", "windows", "static"), default="changed")
    parser.add_argument(
        "--static-only",
        action="store_true",
        help="CI compatibility alias for the certifying static profile",
    )
    parser.add_argument("--changed-ref", default="origin/dev", help="diff base for changed profile")
    parser.add_argument("--skip-static", action="store_true")
    parser.add_argument("--skip-godot", action="store_true")
    parser.add_argument("--skip-umbrella", action="store_true")
    parser.add_argument("--fail-fast", action="store_true")
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
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = _parse_args(argv)
    if args.static_only:
        args.profile = "static"
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
        selected = select_godot_tests(
            args.profile, args.filters, args.changed_ref, args.skip_umbrella
        )
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
            for path in selected:
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
    certifying = _is_certifying(args, worktree_status)
    if worktree_status:
        print("QUALITY NON-CERTIFYING: worktree is not clean", file=sys.stderr)
        for line in worktree_status:
            print(f"  {line}", file=sys.stderr)
    status = "failed" if failed else ("passed" if certifying else "partial_pass")
    payload = {
        "profile": args.profile,
        "certifying": certifying,
        "filters": list(args.filters),
        "skip_static": args.skip_static,
        "skip_godot": args.skip_godot,
        "skip_umbrella": args.skip_umbrella,
        "godot_test_timeout_seconds": args.test_timeout,
        "godot_import_timeout_seconds": args.import_timeout,
        "static_timeout_seconds": args.static_timeout,
        "python_unit_idle_timeout_seconds": args.python_unit_idle_timeout,
        "worktree_clean": not worktree_status,
        "worktree_status": worktree_status,
        "discovered_godot_tests": len(discovered),
        "selected_godot_tests": len(selected),
        "discovered_python_tests": len(python_tests),
        "executed_python_tests": sum(
            item.get("executed_tests", 0) for item in static_results
        ),
        "git_sha": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "platform": sys.platform,
        "status": status,
        "duration_seconds": round(time.monotonic() - started, 3),
        "static_checks": static_results,
        "godot_import_prepass": import_result,
        "godot_tests": godot_results,
    }
    _write_report((ROOT / args.report).resolve(), payload)
    print(
        f"QUALITY {payload['status'].upper()}: "
        f"{len(static_results)} static, {len(godot_results)} Godot; "
        f"report={args.report}",
        flush=True,
    )
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
