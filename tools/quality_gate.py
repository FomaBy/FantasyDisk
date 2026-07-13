#!/usr/bin/env python3
"""Reproducible FantasyDisk code-quality and Windows-performance gate."""
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
GODOT_SUITES = (
    "feedback_webhook_config_test.gd",
    "run_autosave_persistence_test.gd",
    "scene_contract_instantiation_test.gd",
    "status_effects_aura_test.gd",
    "combat_target_query_cache_test.gd",
    "runtime_hotpath_cache_test.gd",
    "enemy_separation_behavior_test.gd",
    # Derived suites are explicit: run_focused_tests.sh historically discovered
    # only files whose first line was the exact `extends SceneTree` spelling.
    "runtime_smoke_combat_test.gd",
    "animation_smoke_test.gd",
    "meta_progression_smoke_test.gd",
    "melee_weapon_targeting_test.gd",
    "asset_reference_integrity_test.gd",
    "content_registry_consistency_test.gd",
    "runtime_smoke_test.gd",
)
FATAL_GODOT_RE = re.compile(
    r"SCRIPT ERROR|Parse Error|ObjectDB instances were leaked|resources still in use at exit",
    re.IGNORECASE,
)


def _run(label: str, command: list[str], env: dict[str, str] | None = None) -> bool:
    print(f"==> {label}", flush=True)
    result = subprocess.run(command, cwd=ROOT, env=env)
    if result.returncode != 0:
        print(f"FAIL: {label} (exit {result.returncode})", file=sys.stderr)
        return False
    print(f"PASS: {label}")
    return True


def _godot_binary(explicit: str) -> str:
    if explicit:
        return explicit
    configured = os.getenv("GODOT_BIN", "")
    if configured:
        return configured
    for candidate in ("godot", "godot4"):
        found = shutil.which(candidate)
        if found:
            return found
    return str(Path.home() / "Downloads/Godot.app/Contents/MacOS/Godot")


def _godot_version(binary: str) -> tuple[bool, str]:
    try:
        result = subprocess.run([binary, "--version"], capture_output=True, text=True, timeout=20)
    except (FileNotFoundError, PermissionError, subprocess.TimeoutExpired) as error:
        return False, str(error)
    version = (result.stdout or result.stderr).strip()
    return result.returncode == 0 and version.startswith("4.7"), version


def _run_godot_suite(binary: str, suite: str) -> bool:
    command = [
        sys.executable,
        str(ROOT / "tools/godot_gate.py"),
        "--headless",
        "--path",
        str(ROOT),
        "--script",
        f"res://tests/{suite}",
    ]
    env = os.environ.copy()
    env["GODOT_BIN"] = binary
    result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True)
    output = (result.stdout or "") + (result.stderr or "")
    fatal = FATAL_GODOT_RE.search(output)
    if result.returncode != 0 or fatal:
        print(f"FAIL: Godot {suite} (exit {result.returncode})", file=sys.stderr)
        relevant = [
            line for line in output.splitlines()
            if re.search(r"SCRIPT ERROR|Parse Error|push_error|ERROR|FAIL|leaked|still in use", line, re.I)
        ]
        print("\n".join((relevant or output.splitlines()[-40:])[:80]), file=sys.stderr)
        return False
    print(f"PASS: Godot {suite}")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--static-only", action="store_true", help="CI-safe checks that do not require Godot")
    parser.add_argument("--godot", default="", help="Godot 4.7 executable (or set GODOT_BIN)")
    parser.add_argument("--suite", action="append", default=[], help="Run only named Godot suite(s)")
    args = parser.parse_args()

    failures = 0
    with tempfile.TemporaryDirectory(prefix="fantasydisk-pycache-") as cache:
        env = os.environ.copy()
        env["PYTHONPYCACHEPREFIX"] = cache
        stages = (
            ("static repository invariants", [sys.executable, "tools/quality_static_guard.py"]),
            ("Python unit tests", [sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", "test_*.py"]),
            ("Python tool syntax", [sys.executable, "-m", "compileall", "-q", "tools", "tests"]),
        )
        for label, command in stages:
            if not _run(label, command, env):
                failures += 1

    if not args.static_only:
        binary = _godot_binary(args.godot)
        valid, version = _godot_version(binary)
        if not valid:
            print(
                f"FAIL: Godot 4.7 is required (binary={binary!r}, reported={version!r}).",
                file=sys.stderr,
            )
            failures += 1
        else:
            print(f"==> Godot runtime suites ({version})")
            suites = tuple(args.suite) if args.suite else GODOT_SUITES
            for suite in suites:
                if suite not in GODOT_SUITES:
                    print(f"FAIL: suite is not in the reviewed manifest: {suite}", file=sys.stderr)
                    failures += 1
                    continue
                if not _run_godot_suite(binary, suite):
                    failures += 1

    if failures:
        print(f"Quality gate failed: {failures} stage(s)/suite(s).", file=sys.stderr)
        return 1
    profile = "static" if args.static_only else "full"
    print(f"Quality gate passed ({profile} profile).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
