#!/usr/bin/env python3
"""FAN-3934 round-5d evidence-owned foreground driver (Python).

Runs each measurement as a subprocess and polls `ps` every 5 s while it runs,
recording verbatim process-query output (own PIDs excluded) with UTC
timestamps before/during/after. Foreign processes are observed and preserved.
"""
import hashlib, os, subprocess, sys, time
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(sys.argv[1]).resolve()
OUT = REPO / "evidence/p3-object-budget-rework/round5d"
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
PROBE = "res://evidence/p3-object-budget-rework/raw-baseline/extracted/perf_probe.gd"
DRIVER_PIDS = {os.getpid()}

OUT.mkdir(parents=True, exist_ok=True)
(REPO / "evidence/FAN-3877").mkdir(exist_ok=True)


def utc() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def ps_listing() -> str:
    result = subprocess.run(
        ["ps", "axo", "pid,pcpu,time,command"], capture_output=True, text=True)
    lines = [line for line in result.stdout.splitlines()
             if "godot" in line.lower() and "grep" not in line
             and "godot_gate" not in line and "run_observed" not in line]
    return "\n".join(lines) if lines else "(no foreign godot processes)"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def observe(handle) -> None:
    handle.write(f"observed_utc={utc()}\n")
    handle.write("ps_query=ps axo pid,pcpu,time,command | grep -i godot | grep -v grep | grep -v godot_gate | grep -v run_observed\n")
    handle.write(ps_listing() + "\n")


def run(tag: str, argv: list, env_extra: dict, cwd=REPO) -> int:
    env_file = OUT / f"env-{tag}.txt"
    log_file = OUT / f"log-{tag}.txt"
    env = dict(os.environ, **env_extra)
    with open(env_file, "a") as handle:
        handle.write(f"command={' '.join(argv)}\n")
        handle.write(f"env_extra={env_extra}\n")
        observe(handle)
    with open(log_file, "w") as log:
        process = subprocess.Popen(argv, cwd=str(cwd), env=env,
                                   stdout=log, stderr=subprocess.STDOUT)
        with open(env_file, "a") as handle:
            while process.poll() is None:
                handle.write(f"--- during sampled_utc={utc()}\n")
                handle.write(ps_listing() + "\n")
                time.sleep(5)
        exit_status = process.wait()
    with open(env_file, "a") as handle:
        observe(handle)
    with open(log_file, "a") as log:
        log.write(f"\nexit_status={exit_status}\n")
        log.write(f"start/end recorded by driver; end_utc={utc()}\n")
    return exit_status


header = OUT / "driver-header.txt"
with open(header, "w") as handle:
    handle.write(f"driver_pid={os.getpid()}\n")
    handle.write(f"driver_argv={sys.argv}\n")
    handle.write(f"start_utc={utc()}\n")
    git = lambda rev: subprocess.run(["git", "-C", str(REPO), "rev-parse", rev],
                                     capture_output=True, text=True).stdout.strip()
    handle.write(f"git_head={git('HEAD')}\ngit_tree={git('HEAD^{tree}')}\n")
    handle.write(f"godot={subprocess.run([GODOT, '--version'], capture_output=True, text=True).stdout.strip()}\n")
    handle.write(f"probe_sha256={sha256(REPO / 'evidence/p3-object-budget-rework/raw-baseline/extracted/perf_probe.gd')}\n")

matrix_env = {"GODOT_BIN": GODOT, "FSD_GODOT_EXCLUSIVE": "1"}
for tag, scenario in [("p3-run1", "P3"), ("p3-run2", "P3"), ("p1", "P1"), ("p2", "P2")]:
    status = run(f"matrix-{tag}",
                 ["python3", "tools/godot_gate.py", "--path", ".", "--script", PROBE, "--", scenario],
                 matrix_env)
    lower = scenario.lower()
    for suffix in ("json", "csv"):
        source = REPO / f"evidence/FAN-3877/perf_{lower}.{suffix}"
        if source.exists():
            (OUT / f"perf-{tag}.{suffix}").write_bytes(source.read_bytes())
    with open(OUT / f"env-matrix-{tag}.txt", "a") as handle:
        handle.write(f"raw_staging_name=perf_{lower}.json / perf_{lower}.csv (shared staging; disambiguated by manifest)\n")
        handle.write(f"matrix_exit_status={status}\n")

suite_env = {"GODOT_BIN": GODOT}
suites = [
    ("feedback", "tests/p3_feedback_allocation_test.gd"),
    ("residency", "tests/p3_executor_residency_test.gd"),
    ("summon", "tests/boss_summon_cap_test.gd"),
    ("hazard", "tests/boss_hazard_cap_gate.gd"),
    ("hazardsmoke", "tests/hazard_vfx_smoke_test.gd"),
    ("berserk", "tests/ultimates/berserk_balance_test.gd"),
]
for name, script in suites:
    run(f"suite-{name}",
        ["python3", "tools/godot_gate.py", "--headless", "--path", ".", "--script", f"res://{script}"],
        suite_env)

subprocess.run(["rm", "-rf", str(REPO / "evidence/FAN-3877")])
with open(OUT / "env-final.txt", "w") as handle:
    observe(handle)
with open(OUT / "file-hashes.txt", "w") as handle:
    handle.write(f"end_utc={utc()}\n")
    for path in sorted(OUT.glob("*")):
        if path.name in ("file-hashes.txt", "run_observed.py"):
            continue
        handle.write(f"{sha256(path)}  {path.name}\n")
print("DRIVER COMPLETE")
