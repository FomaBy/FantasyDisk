#!/usr/bin/env python3
"""One cross-platform quality entry point for FantasyDisk.

The runner discovers both direct ``extends SceneTree`` tests and inherited test
suites, isolates ``user://`` per process, and routes every Godot invocation
through ``tools/godot_gate.py``.  It intentionally runs synchronously so a
Multica task cannot finish before validation has completed.
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
import time
from pathlib import Path
from typing import Iterable, Sequence

ROOT = Path(__file__).resolve().parents[1]
TEST_DIR = ROOT / "tests"
GODOT_GATE = ROOT / "tools" / "godot_gate.py"
RUNTIME_SMOKE = "runtime_smoke_test"
EXTENDS_RE = re.compile(
    r'^\s*extends\s+(?:SceneTree|["\']res://tests/[^"\']+\.gd["\'])\s*(?:#.*)?$',
    re.MULTILINE,
)
REAL_DISCORD_WEBHOOK_RE = re.compile(
    r"https://(?:discord(?:app)?\.com)/api/webhooks/[0-9]{15,}/[A-Za-z0-9_-]{20,}"
)
BASE64_LITERAL_RE = re.compile(r'["\']([A-Za-z0-9+/]{20,}={0,2})["\']')
FATAL_OUTPUT_RE = re.compile(r"\bSCRIPT ERROR\b|\bFATAL\b", re.IGNORECASE)

CORE_CHANGED_TESTS = {
    "combat_target_query_cache_test",
    "runtime_smoke_combat_test",
    "runtime_smoke_ui_test",
}
PATH_TEST_RULES = {
    "scripts/class_weapon.gd": {"engineer_kit_test", "persistent_hazard_contract_test"},
    "scripts/enemy.gd": {"enemy_separation_behavior_test"},
    "scripts/threat_indicators.gd": {"hot_path_cache_test"},
    "scripts/feedback_reporter.gd": {"feedback_webhook_config_test", "feedback_retry_policy_test"},
    "tests/feedback_webhook_config_test.gd": {"feedback_webhook_config_test"},
}


def discover_godot_tests() -> list[Path]:
    tests: list[Path] = []
    for path in sorted(TEST_DIR.glob("*.gd")):
        try:
            source = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        if EXTENDS_RE.search(source):
            tests.append(path)
    return tests


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


def select_godot_tests(
    profile: str,
    filters: Sequence[str],
    changed_ref: str,
    skip_umbrella: bool,
) -> list[Path]:
    discovered = discover_godot_tests()
    by_name = {path.stem: path for path in discovered}

    if profile == "static":
        return []
    if profile in {"full", "windows"}:
        selected_names = set(by_name)
    else:
        selected_names = set(CORE_CHANGED_TESTS)
        for changed_path in _git_changed_paths(changed_ref):
            selected_names.update(PATH_TEST_RULES.get(changed_path, set()))
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


def _run_command(name: str, command: Sequence[str], timeout: float) -> dict:
    started = time.monotonic()
    exit_code, output, timed_out = _run_captured(
        command, os.environ.copy(), timeout
    )
    if output:
        print(output, end="" if output.endswith("\n") else "\n", flush=True)
    return {
        "name": name,
        "status": "passed" if exit_code == 0 and not timed_out else "failed",
        "exit_code": exit_code,
        "timed_out": timed_out,
        "duration_seconds": round(time.monotonic() - started, 3),
    }


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
    roots = [ROOT / "scripts", ROOT / "scenes"]
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


def run_static_checks(fail_fast: bool, timeout: float) -> list[dict]:
    commands: list[tuple[str, list[str]]] = [
        ("repository-invariants", [sys.executable, "tools/quality_static_guard.py"]),
        ("python-unit", [sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", "test_*.py"]),
        ("python-syntax", [sys.executable, "-m", "compileall", "-q", "tools", "tests"]),
        ("asset-audit", [sys.executable, "tools/test_audit_unused_assets.py"]),
        ("constellation-validator", [sys.executable, "tools/test_validate_scrum1067_constellation_spec.py"]),
        ("runtime-manifest-validator", [sys.executable, "tools/test_validate_scrum1068_runtime_manifest.py"]),
        ("git-diff-check", ["git", "diff", "--check"]),
        ("git-head-check", ["git", "show", "--check", "--format=", "HEAD"]),
    ]
    shell_scripts = sorted((ROOT / "tools").glob("*.sh")) + sorted((ROOT / "scripts").glob("*.sh"))
    if shell_scripts:
        commands.append(("shell-syntax", ["bash", "-n", *[str(path) for path in shell_scripts]]))

    results: list[dict] = []
    for name, command in commands:
        print(f"STATIC {name}", flush=True)
        outcome = _run_command(name, command, timeout)
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


def _godot_environment(user_data: Path) -> dict[str, str]:
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
    return env


def _run_captured(command: Sequence[str], env: dict[str, str], timeout: float) -> tuple[int, str, bool]:
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
    try:
        output, _ = process.communicate(timeout=timeout)
        return process.returncode, output, False
    except subprocess.TimeoutExpired:
        if os.name == "nt":
            subprocess.run(
                ["taskkill", "/F", "/T", "/PID", str(process.pid)],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            )
        else:
            os.killpg(process.pid, signal.SIGKILL)
        output, _ = process.communicate()
        return 124, output, True


def run_godot_test(path: Path, timeout: float) -> dict:
    started = time.monotonic()
    name = path.stem
    with tempfile.TemporaryDirectory(prefix=f"fsd-{name}-") as scratch:
        user_data = Path(scratch).resolve()
        command = [
            sys.executable,
            str(GODOT_GATE),
            "--headless",
            "--path",
            str(ROOT),
            "--script",
            f"res://tests/{path.name}",
            "--",
            f"--user-data-dir={user_data}",
        ]
        exit_code, output, timed_out = _run_captured(
            command, _godot_environment(user_data), timeout
        )
    fatal_match = FATAL_OUTPUT_RE.search(output)
    passed = exit_code == 0 and fatal_match is None and not timed_out
    if passed:
        print(f"PASS  {name}", flush=True)
    else:
        reason = f"exit {exit_code}"
        if timed_out:
            reason += f", timeout after {timeout:.0f}s"
        if fatal_match is not None:
            reason += f", fatal diagnostic: {fatal_match.group(0)}"
        print(f"FAIL  {name} ({reason})", file=sys.stderr, flush=True)
        print(output[-12000:], file=sys.stderr)
    return {
        "name": name,
        "script": f"res://tests/{path.name}",
        "status": "passed" if passed else "failed",
        "exit_code": exit_code,
        "timed_out": timed_out,
        "fatal_diagnostic": fatal_match.group(0) if fatal_match else "",
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
        "--static-timeout",
        type=float,
        default=float(os.getenv("FSD_STATIC_TEST_TIMEOUT", "600")),
        help="per-static-command timeout in seconds (default: 600)",
    )
    parser.add_argument("--list", action="store_true", help="list selected Godot tests and exit")
    parser.add_argument("--report", default="build/quality_gate_report.json")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = _parse_args(argv)
    if args.static_only:
        args.profile = "static"
    if args.test_timeout <= 0 or args.static_timeout <= 0:
        print("quality_gate: test/static timeouts must be positive", file=sys.stderr)
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
    except RuntimeError as exc:
        print(f"quality_gate: {exc}", file=sys.stderr)
        return 2

    if args.list:
        for path in selected:
            print(path.relative_to(ROOT).as_posix())
        print(f"Selected {len(selected)} Godot test(s).")
        return 0
    if args.profile != "static" and not args.skip_godot and not selected:
        print("quality_gate: no Godot tests selected", file=sys.stderr)
        return 2

    started = time.monotonic()
    static_results = [] if args.skip_static else run_static_checks(
        args.fail_fast, args.static_timeout
    )
    failed = any(item["status"] == "failed" for item in static_results)
    godot_results: list[dict] = []
    if args.profile != "static" and not args.skip_godot and not (failed and args.fail_fast):
        print(f"GODOT running {len(selected)} test(s) via semaphore gate", flush=True)
        for path in selected:
            outcome = run_godot_test(path, args.test_timeout)
            godot_results.append(outcome)
            if outcome["status"] == "failed":
                failed = True
                if args.fail_fast:
                    break

    certifying = not (
        args.filters or args.skip_static or args.skip_godot or args.skip_umbrella
    )
    status = "failed" if failed else ("passed" if certifying else "partial_pass")
    payload = {
        "profile": args.profile,
        "certifying": certifying,
        "filters": list(args.filters),
        "skip_static": args.skip_static,
        "skip_godot": args.skip_godot,
        "skip_umbrella": args.skip_umbrella,
        "discovered_godot_tests": len(discover_godot_tests()),
        "selected_godot_tests": len(selected),
        "git_sha": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "platform": sys.platform,
        "status": status,
        "duration_seconds": round(time.monotonic() - started, 3),
        "static_checks": static_results,
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
