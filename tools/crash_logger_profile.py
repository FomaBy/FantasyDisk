#!/usr/bin/env python3
"""Reproducible crash-logger probes and exact-SHA P1 frame profiling."""

from __future__ import annotations

import argparse
import ctypes
import hashlib
import json
import math
import os
from pathlib import Path
import re
import signal
import statistics
import subprocess
import sys
import tempfile
import time
import zipfile


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_GODOT = Path("/Applications/Godot.app/Contents/MacOS/Godot")
EXPECTED_ERROR = "FAN-3905 deterministic expected-error probe"
SELF_TEST_ERROR = "FAN-3905 deterministic crash logger self-test"
INCIDENT_GLOB = "incident_*.json"
PROFILE_MARKER = "FAN3905_FRAME_PROFILE="
PROFILE_WARMUP_FRAMES = 6000
PROFILE_SAMPLE_FRAMES = 24000
PROFILE_CALIBRATION_USEC = 2000
PROFILE_CALIBRATION_MIN_FRACTION = 0.75
# Three predeclared ABBA blocks keep each revision first in exactly six pairs.
PROFILE_PAIR_ORDER = (
    ("baseline", "candidate"),
    ("candidate", "baseline"),
    ("candidate", "baseline"),
    ("baseline", "candidate"),
    ("baseline", "candidate"),
    ("candidate", "baseline"),
    ("candidate", "baseline"),
    ("baseline", "candidate"),
    ("baseline", "candidate"),
    ("candidate", "baseline"),
    ("candidate", "baseline"),
    ("baseline", "candidate"),
)

PROFILE_SCRIPT = r'''extends SceneTree

const PROFILE_MARKER := "FAN3905_FRAME_PROFILE="


class CalibrationLoad:
	extends Node

	var busy_usec := 0


	func _process(_delta: float) -> void:
		if busy_usec <= 0:
			return
		var started := Time.get_ticks_usec()
		while Time.get_ticks_usec() - started < busy_usec:
			pass


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var warmup_frames := 600
	var sample_frames := 3000
	var sample_count := 1
	var calibration_usec := 2000
	var phase_file := ""
	var phase_ack_file := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--warmup-frames="):
			warmup_frames = int(argument.trim_prefix("--warmup-frames="))
		elif argument.begins_with("--sample-frames="):
			sample_frames = int(argument.trim_prefix("--sample-frames="))
		elif argument.begins_with("--sample-count="):
			sample_count = int(argument.trim_prefix("--sample-count="))
		elif argument.begins_with("--calibration-usec="):
			calibration_usec = int(argument.trim_prefix("--calibration-usec="))
		elif argument.begins_with("--phase-file="):
			phase_file = argument.trim_prefix("--phase-file=")
		elif argument.begins_with("--phase-ack-file="):
			phase_ack_file = argument.trim_prefix("--phase-ack-file=")
	var logger: Node = root.get_node_or_null("CrashLogger")
	if logger == null and ResourceLoader.exists("res://scripts/crash_logger.gd"):
		logger = load("res://scripts/crash_logger.gd").new()
		root.add_child(logger)
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main := main_scene.instantiate()
	root.add_child(main)
	var calibration_load := CalibrationLoad.new()
	root.add_child(calibration_load)
	for frame in range(warmup_frames):
		await process_frame
	_phase("normal_start", phase_file, phase_ack_file)
	var normal: Dictionary = await _sample_windows(sample_frames, sample_count)
	_phase("normal_end", phase_file, phase_ack_file)
	calibration_load.busy_usec = calibration_usec
	for frame in range(maxi(60, int(warmup_frames / 10))):
		await process_frame
	_phase("calibration_start", phase_file, phase_ack_file)
	var calibrated: Dictionary = await _sample_windows(sample_frames, sample_count)
	_phase("calibration_end", phase_file, phase_ack_file)
	calibration_load.busy_usec = 0
	calibration_load.queue_free()
	main.queue_free()
	await process_frame
	await process_frame
	print(PROFILE_MARKER + JSON.stringify({
		"display": DisplayServer.get_name(),
		"metric": "wall-clock diagnostic; authoritative CPU samples added by host profiler",
		"warmup_frames": warmup_frames,
		"frames_per_sample": sample_frames,
		"samples_ms": normal["wall_ms"],
		"calibration_injected_ms": float(calibration_usec) / 1000.0,
		"calibration_samples_ms": calibrated["wall_ms"],
	}))
	quit(0)


func _phase(name: String, phase_file: String, phase_ack_file: String) -> void:
	if phase_file.is_empty() or phase_ack_file.is_empty():
		return
	var file := FileAccess.open(phase_file, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(name)
	file.close()
	while FileAccess.get_file_as_string(phase_ack_file) != name:
		OS.delay_msec(1)


func _sample_windows(sample_frames: int, sample_count: int) -> Dictionary:
	var wall_samples_ms: Array[float] = []
	for sample_index in range(sample_count):
		var wall_started := Time.get_ticks_usec()
		for frame in range(sample_frames):
			await process_frame
		var elapsed_usec := Time.get_ticks_usec() - wall_started
		wall_samples_ms.append(float(elapsed_usec) / float(sample_frames) / 1000.0)
	return {"wall_ms": wall_samples_ms}
'''


class ProbeFailure(RuntimeError):
    pass


class _RUsageInfoV0(ctypes.Structure):
    _fields_ = [
        ("uuid", ctypes.c_uint8 * 16),
        ("user_time", ctypes.c_uint64),
        ("system_time", ctypes.c_uint64),
        ("package_idle_wakeups", ctypes.c_uint64),
        ("interrupt_wakeups", ctypes.c_uint64),
        ("pageins", ctypes.c_uint64),
        ("wired_size", ctypes.c_uint64),
        ("resident_size", ctypes.c_uint64),
        ("physical_footprint", ctypes.c_uint64),
        ("process_start_abstime", ctypes.c_uint64),
        ("process_exit_abstime", ctypes.c_uint64),
    ]


class _MachTimebaseInfo(ctypes.Structure):
    _fields_ = [("numerator", ctypes.c_uint32), ("denominator", ctypes.c_uint32)]


def _mac_abstime_to_ns(value: int) -> int:
    timebase = _MachTimebaseInfo()
    libsystem = ctypes.CDLL("/usr/lib/libSystem.B.dylib", use_errno=True)
    if libsystem.mach_timebase_info(ctypes.byref(timebase)) != 0 or timebase.denominator == 0:
        raise ProbeFailure("cannot resolve the macOS Mach absolute-time conversion")
    return value * int(timebase.numerator) // int(timebase.denominator)


def _mac_child_pids(parent_pid: int) -> list[int]:
    libproc = ctypes.CDLL("/usr/lib/libproc.dylib", use_errno=True)
    child_pids = (ctypes.c_int * 64)()
    child_count = libproc.proc_listchildpids(
        ctypes.c_int(parent_pid), ctypes.byref(child_pids), ctypes.sizeof(child_pids)
    )
    if child_count < 0:
        raise ProbeFailure(f"cannot inspect gated Godot child PID: errno {ctypes.get_errno()}")
    return [pid for pid in child_pids[:child_count] if pid > 0]


def _mac_process_cpu_ns(pid: int) -> int:
    usage = _RUsageInfoV0()
    libproc = ctypes.CDLL("/usr/lib/libproc.dylib", use_errno=True)
    if libproc.proc_pid_rusage(ctypes.c_int(pid), ctypes.c_int(0), ctypes.byref(usage)) != 0:
        raise ProbeFailure(f"cannot read Godot CPU usage for PID {pid}: errno {ctypes.get_errno()}")
    return _mac_abstime_to_ns(int(usage.user_time + usage.system_time))


def _run(command: list[str], cwd: Path, *, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    merged_env = os.environ.copy()
    if env:
        merged_env.update(env)
    completed = subprocess.run(
        command,
        cwd=cwd,
        env=merged_env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if completed.returncode != 0:
        raise ProbeFailure(
            f"command exited {completed.returncode}: {' '.join(command)}\n{completed.stdout}"
        )
    return completed


def _run_profile_gated(
    command: list[str],
    cwd: Path,
    env: dict[str, str],
    phase_file: Path,
    phase_ack_file: Path,
) -> tuple[subprocess.CompletedProcess[str], dict[str, int]]:
    if sys.platform != "darwin":
        raise ProbeFailure("the process-CPU P1 profile is certified only for the required macOS host")
    merged_env = os.environ.copy()
    merged_env.update(env)
    phases = ("normal_start", "normal_end", "calibration_start", "calibration_end")
    cpu_at_phase: dict[str, int] = {}
    godot_pid = 0
    with tempfile.TemporaryFile(mode="w+", encoding="utf-8") as output:
        process = subprocess.Popen(
            command,
            cwd=cwd,
            env=merged_env,
            text=True,
            stdout=output,
            stderr=subprocess.STDOUT,
        )
        phase_index = 0
        try:
            while process.poll() is None:
                if phase_index < len(phases) and phase_file.is_file():
                    observed = phase_file.read_text(encoding="utf-8").strip()
                    expected = phases[phase_index]
                    if observed == expected:
                        if godot_pid == 0:
                            children = _mac_child_pids(process.pid)
                            if len(children) != 1:
                                raise ProbeFailure(
                                    f"expected one live Godot child for gated profile, found {children}"
                                )
                            godot_pid = children[0]
                        cpu_at_phase[expected] = _mac_process_cpu_ns(godot_pid)
                        phase_ack_file.write_text(expected, encoding="utf-8")
                        phase_index += 1
                time.sleep(0.005)
        except BaseException:
            # Only terminate direct, task-owned children of the gate process.
            for child_pid in _mac_child_pids(process.pid):
                try:
                    os.kill(child_pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
            process.terminate()
            process.wait()
            raise
        return_code = process.wait()
        output.seek(0)
        captured = output.read()
    completed = subprocess.CompletedProcess(command, return_code, captured, "")
    if return_code != 0:
        raise ProbeFailure(
            f"command exited {return_code}: {' '.join(command)}\n{captured}"
        )
    if tuple(cpu_at_phase) != phases:
        raise ProbeFailure(
            f"profile process completed without the required CPU phase sequence: {list(cpu_at_phase)}"
        )
    return completed, cpu_at_phase


def _godot_path(value: str) -> Path:
    path = Path(value).expanduser().resolve()
    if not path.is_file():
        raise ProbeFailure(f"Godot executable not found: {path}")
    return path


def _project_path(value: str) -> Path:
    path = Path(value).expanduser().resolve()
    if not (path / "project.godot").is_file():
        raise ProbeFailure(f"Godot project not found: {path}")
    return path


def _diagnostic_lines(output: str) -> list[str]:
    return [
        line.strip()
        for line in output.splitlines()
        if re.search(r"(?:SCRIPT ERROR|\bERROR:|\bFATAL:|Failed to load script)", line)
    ]


def _verify_only_expected_diagnostic(output: str, expected: str) -> None:
    diagnostics = _diagnostic_lines(output)
    if len(diagnostics) != 1 or expected not in diagnostics[0]:
        raise ProbeFailure(
            "expected exactly one intentional Godot error; got "
            + json.dumps(diagnostics, ensure_ascii=False)
        )


def _verify_incident(directory: Path, expected: str, required_functions: set[str]) -> dict:
    paths = sorted(directory.glob(INCIDENT_GLOB))
    if len(paths) != 1:
        raise ProbeFailure(f"expected one complete incident in {directory}, found {len(paths)}")
    try:
        record = json.loads(paths[0].read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ProbeFailure(f"incident is not complete JSON: {exc}") from exc
    if expected not in str(record.get("error", {}).get("text", "")):
        raise ProbeFailure("incident did not preserve the expected error identity")
    backtrace = record.get("script_backtrace", {})
    if not backtrace.get("available"):
        raise ProbeFailure(f"expected script frames, got {backtrace.get('status', 'no status')}")
    frames = [
        frame
        for trace in backtrace.get("traces", [])
        for frame in trace.get("frames", [])
        if str(frame.get("file", "")).startswith("res://")
    ]
    functions = {str(frame.get("function", "")) for frame in frames}
    if len(frames) < 2 or not required_functions.issubset(functions):
        raise ProbeFailure(
            f"expected at least two meaningful GDScript frames {sorted(required_functions)}, got {sorted(functions)}"
        )
    digest = str(record.get("build_sha256", ""))
    if not re.fullmatch(r"[0-9a-f]{64}", digest):
        raise ProbeFailure("incident lacks a valid immutable SHA-256 identity")
    if not str(record.get("timestamp_utc", "")).endswith("Z"):
        raise ProbeFailure("incident lacks a UTC timestamp")
    if not str(record.get("build_version", "")):
        raise ProbeFailure("incident lacks the build version")
    if not isinstance(record.get("breadcrumbs"), list):
        raise ProbeFailure("incident lacks the combat breadcrumb ring")
    return {
        "incident_file": paths[0].name,
        "backtrace_frames": len(frames),
        "functions": sorted(functions),
        "build_sha256": digest,
        "build_sha256_source": record.get("build_sha256_source"),
        "build_version": record.get("build_version"),
    }


def command_probe(args: argparse.Namespace) -> dict:
    project = _project_path(args.project)
    godot = _godot_path(args.godot)
    with tempfile.TemporaryDirectory(prefix=".fan3905-probe-", dir=project) as temp_name:
        output_dir = Path(temp_name).resolve()
        completed = _run(
            [
                str(godot),
                "--headless",
                "--path",
                str(project),
                "--script",
                "res://tests/crash_logger_expected_error_probe.gd",
                "--",
                f"--crash-logger-output={output_dir}",
            ],
            project,
        )
        _verify_only_expected_diagnostic(completed.stdout, EXPECTED_ERROR)
        if "CRASH_LOGGER_EXPECTED_ERROR" not in completed.stdout:
            raise ProbeFailure("expected-error probe did not reach its completion marker")
        result = _verify_incident(
            output_dir,
            EXPECTED_ERROR,
            {"_expected_error_leaf", "_expected_error_parent"},
        )
    return {"verdict": "PASS", "probe": "expected-error", **result, "cleanup": "complete"}


def _find_exported_executable(extracted: Path) -> Path:
    matches = sorted(extracted.glob("*.app/Contents/MacOS/*"))
    files = [path for path in matches if path.is_file()]
    if len(files) != 1:
        raise ProbeFailure(f"expected one exported executable, found {len(files)}")
    # Python's ZipFile extracts data but does not restore the executable mode
    # recorded by Godot's macOS bundle archive.
    files[0].chmod(files[0].stat().st_mode | 0o111)
    return files[0]


def command_export_probe(args: argparse.Namespace) -> dict:
    project = _project_path(args.project)
    godot = _godot_path(args.godot)
    with tempfile.TemporaryDirectory(prefix=".fan3905-export-", dir=project) as temp_name:
        temp = Path(temp_name).resolve()
        archive = temp / "FantasyDisk-macOS-debug.zip"
        export = _run(
            [str(godot), "--headless", "--path", str(project), "--export-debug", "macOS", str(archive)],
            project,
        )
        export_diagnostics = _diagnostic_lines(export.stdout)
        if export_diagnostics:
            raise ProbeFailure(f"debug export emitted fatal diagnostics: {export_diagnostics}")
        extracted = temp / "extracted"
        extracted.mkdir()
        with zipfile.ZipFile(archive) as bundle:
            bundle.extractall(extracted)
        executable = _find_exported_executable(extracted)
        output_dir = temp / "incidents"
        output_dir.mkdir()
        completed = _run(
            [
                str(executable),
                "--headless",
                "--",
                "--crash-logger-self-test",
                f"--crash-logger-output={output_dir}",
            ],
            temp,
        )
        _verify_only_expected_diagnostic(completed.stdout, SELF_TEST_ERROR)
        if "CRASH_LOGGER_SELF_TEST incident=" not in completed.stdout:
            raise ProbeFailure("exported self-test did not report its incident path")
        result = _verify_incident(
            output_dir,
            SELF_TEST_ERROR,
            {"_self_test_leaf", "_self_test_parent"},
        )
        if result["build_sha256_source"] != "exported project pack":
            raise ProbeFailure("exported candidate did not hash its project pack")
    return {"verdict": "PASS", "probe": "macOS-debug-export", **result, "cleanup": "complete"}


def _resolve_commit(project: Path, revision: str) -> str:
    completed = _run(["git", "rev-parse", f"{revision}^{{commit}}"], project)
    commit = completed.stdout.strip()
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ProbeFailure(f"revision did not resolve to a commit: {revision}")
    return commit


def _profile_one(
    project: Path,
    godot: Path,
    revision: str,
    worktree: Path,
    cache: Path,
    warmup_frames: int,
    sample_frames: int,
    calibration_usec: int,
    sample_count: int,
) -> dict:
    # Multica's checkout lifecycle hook owns persistent workspaces. These
    # detached, task-scoped measurement trees are intentionally ephemeral.
    _run(
        ["git", "-c", "core.hooksPath=/dev/null", "worktree", "add", "--detach", str(worktree), revision],
        project,
    )
    try:
        if cache.is_dir():
            (worktree / ".godot").symlink_to(cache, target_is_directory=True)
        probe = worktree / ".fan3905_frame_probe.gd"
        probe.write_text(PROFILE_SCRIPT, encoding="utf-8")
        phase_file = worktree / ".fan3905_profile_phase"
        phase_ack_file = worktree / ".fan3905_profile_phase_ack"
        gate = worktree / "tools" / "godot_gate.py"
        if not gate.is_file():
            raise ProbeFailure(f"frame profile revision {revision} lacks tools/godot_gate.py")
        completed, cpu_at_phase = _run_profile_gated(
            [
                sys.executable,
                str(gate),
                "--path",
                str(worktree),
                "--script",
                "res://.fan3905_frame_probe.gd",
                "--resolution",
                "1280x720",
                "--position",
                "0,0",
                "--disable-vsync",
                "--max-fps",
                "0",
                "--",
                f"--warmup-frames={warmup_frames}",
                f"--sample-frames={sample_frames}",
                f"--sample-count={sample_count}",
                f"--calibration-usec={calibration_usec}",
                f"--phase-file={phase_file}",
                f"--phase-ack-file={phase_ack_file}",
            ],
            worktree,
            {"FSD_GODOT_EXCLUSIVE": "1", "GODOT_BIN": str(godot)},
            phase_file,
            phase_ack_file,
        )
        diagnostics = _diagnostic_lines(completed.stdout)
        if diagnostics:
            raise ProbeFailure(f"frame profile for {revision} emitted fatal diagnostics: {diagnostics}")
        marker_lines = [line for line in completed.stdout.splitlines() if line.startswith(PROFILE_MARKER)]
        if len(marker_lines) != 1:
            raise ProbeFailure(f"frame profile for {revision} emitted {len(marker_lines)} result markers")
        payload = json.loads(marker_lines[0][len(PROFILE_MARKER) :])
        wall_samples = [float(value) for value in payload.get("samples_ms", [])]
        calibration_wall_samples = [
            float(value) for value in payload.get("calibration_samples_ms", [])
        ]
        samples = [
            (cpu_at_phase["normal_end"] - cpu_at_phase["normal_start"])
            / sample_frames
            / 1_000_000.0
        ]
        calibration_samples = [
            (cpu_at_phase["calibration_end"] - cpu_at_phase["calibration_start"])
            / sample_frames
            / 1_000_000.0
        ]
        if len(samples) != sample_count or any(not math.isfinite(value) or value <= 0 for value in samples):
            raise ProbeFailure(
                f"frame profile for {revision} did not return {sample_count} valid samples"
            )
        if len(calibration_samples) != sample_count or any(
            not math.isfinite(value) or value <= 0 for value in calibration_samples
        ):
            raise ProbeFailure(
                f"frame profile for {revision} did not return {sample_count} valid calibration samples"
            )
        if payload.get("display") == "headless":
            raise ProbeFailure("P1 profile unexpectedly used the headless display driver")
        payload["wall_samples_ms"] = wall_samples
        payload["calibration_wall_samples_ms"] = calibration_wall_samples
        payload["samples_ms"] = samples
        payload["calibration_samples_ms"] = calibration_samples
        payload["metric"] = "macOS process CPU user+system time per rendered main-menu frame"
        payload["cpu_accounting"] = "proc_pid_rusage RUSAGE_INFO_V0 sampled at acknowledged GDScript phase boundaries"
        return {"sha": revision, **payload}
    finally:
        _run(["git", "worktree", "remove", "--force", str(worktree)], project)


def _median_and_mad(samples: list[float]) -> tuple[float, float]:
    median = statistics.median(samples)
    mad = statistics.median(abs(value - median) for value in samples)
    return median, mad


def _sha256_json(value: object) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def _host_load_observation() -> dict:
    try:
        load_average = list(os.getloadavg())
    except OSError:
        load_average = []
    return {
        "observed_unix_ns": time.time_ns(),
        "load_average_1m_5m_15m": load_average,
    }


def _merge_profile_runs(runs: list[dict]) -> dict:
    sample_fields = {
        "samples_ms",
        "calibration_samples_ms",
        "wall_samples_ms",
        "calibration_wall_samples_ms",
    }
    merged = {
        key: value
        for key, value in runs[0].items()
        if key not in sample_fields
    }
    for field in sample_fields:
        merged[field] = [float(run[field][0]) for run in runs]
    merged["trial_count"] = len(runs)
    return merged


def _validate_null_evidence(path: Path, baseline_sha: str) -> str:
    artifact = path.read_bytes()
    evidence = json.loads(artifact)
    if not isinstance(evidence, dict):
        raise ProbeFailure("null evidence must be a JSON object")
    expected_source = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    expected_order = [list(pair) for pair in PROFILE_PAIR_ORDER]
    protocol = evidence.get("protocol", {})
    calibration = evidence.get("calibration", {})
    interval = evidence.get("one_sided_95_percent_interval", [])
    valid = (
        evidence.get("mode") == "baseline-only-null"
        and evidence.get("verdict") == "PASS"
        and evidence.get("cleanup") == "complete"
        and evidence.get("profile_source_sha256") == expected_source
        and evidence.get("baseline", {}).get("sha") == baseline_sha
        and evidence.get("candidate", {}).get("sha") == baseline_sha
        and protocol.get("warmup_frames") == PROFILE_WARMUP_FRAMES
        and protocol.get("frames_per_sample") == PROFILE_SAMPLE_FRAMES
        and protocol.get("pair_order") == expected_order
        and protocol.get("calibration_usec") == PROFILE_CALIBRATION_USEC
        and protocol.get("calibration_min_fraction") == PROFILE_CALIBRATION_MIN_FRACTION
        and calibration.get("responsive") is True
        and isinstance(interval, list)
        and len(interval) == 2
        and float(interval[0]) >= -1.0
        and float(interval[1]) <= 1.0
    )
    if not valid:
        raise ProbeFailure(
            "candidate comparison requires PASS baseline-only null evidence for "
            "the same baseline, current profiler source, fixed protocol, and +/-1% interval"
        )
    return hashlib.sha256(artifact).hexdigest()


def command_profile(args: argparse.Namespace, *, baseline_only: bool = False) -> dict:
    project = _project_path(args.project)
    godot = _godot_path(args.godot)
    baseline_sha = _resolve_commit(project, args.baseline_sha)
    candidate_sha = baseline_sha if baseline_only else _resolve_commit(project, args.candidate_sha)
    null_evidence_sha256 = None
    if not baseline_only:
        null_evidence_sha256 = _validate_null_evidence(Path(args.null_evidence), baseline_sha)
    effective_command = {
        "tool": (
            "python3 tools/crash_logger_profile.py null-profile"
            if baseline_only
            else "python3 tools/crash_logger_profile.py profile"
        ),
        "baseline_sha": baseline_sha,
        "candidate_sha": candidate_sha,
        "warmup_frames": args.warmup_frames,
        "frames_per_sample": args.frames_per_sample,
        "pair_order": [list(pair) for pair in PROFILE_PAIR_ORDER],
        "calibration_usec": args.calibration_usec,
        "calibration_min_fraction": args.calibration_min_fraction,
        "scenario": {
            "scene": "res://scenes/Main.tscn",
            "resolution": "1280x720",
            "vsync": "disabled",
            "max_fps": 0,
            "metric": "macOS process CPU user+system time per rendered main-menu frame",
        },
    }
    if null_evidence_sha256 is not None:
        effective_command["null_evidence_sha256"] = null_evidence_sha256
    cache = (project / ".godot").resolve()
    with tempfile.TemporaryDirectory(prefix=".fan3905-profile-", dir=project.parent) as temp_name:
        temp = Path(temp_name).resolve()
        baseline_runs: list[dict] = []
        candidate_runs: list[dict] = []
        runs_by_label = {"baseline": baseline_runs, "candidate": candidate_runs}
        revisions_by_label = {"baseline": baseline_sha, "candidate": candidate_sha}
        execution_order: list[dict] = []
        for pair_index, pair_order in enumerate(PROFILE_PAIR_ORDER, start=1):
            for within_pair_index, label in enumerate(pair_order, start=1):
                revision = revisions_by_label[label]
                load_before = _host_load_observation()
                run = _profile_one(
                    project,
                    godot,
                    revision,
                    temp / f"pair-{pair_index:02d}-{within_pair_index}-{label}",
                    cache,
                    args.warmup_frames,
                    args.frames_per_sample,
                    args.calibration_usec,
                    1,
                )
                load_after = _host_load_observation()
                runs_by_label[label].append(run)
                execution_order.append({
                    "pair": pair_index,
                    "within_pair": within_pair_index,
                    "label": label,
                    "sha": revision,
                    "sample_ms": float(run["samples_ms"][0]),
                    "calibration_sample_ms": float(run["calibration_samples_ms"][0]),
                    "wall_sample_ms": float(run["wall_samples_ms"][0]),
                    "calibration_wall_sample_ms": float(run["calibration_wall_samples_ms"][0]),
                    "host_load_before": load_before,
                    "host_load_after": load_after,
                })
        baseline = _merge_profile_runs(baseline_runs)
        candidate = _merge_profile_runs(candidate_runs)
    baseline_median, baseline_mad = _median_and_mad(baseline["samples_ms"])
    candidate_median, candidate_mad = _median_and_mad(candidate["samples_ms"])
    paired_regressions = [
        (candidate_sample / baseline_sample - 1.0) * 100.0
        for baseline_sample, candidate_sample in zip(
            baseline["samples_ms"], candidate["samples_ms"]
        )
    ]
    regression_percent, paired_mad = _median_and_mad(paired_regressions)
    # Pairing controls machine drift between neighboring exact-SHA trials.
    # 1.4826 scales MAD to sigma; 1.645 is the one-sided 95% bound.
    bound = 1.645 * 1.4826 * paired_mad / math.sqrt(len(PROFILE_PAIR_ORDER))
    lower = regression_percent - bound
    upper = regression_percent + bound
    baseline_calibration_deltas = [
        calibrated - normal
        for normal, calibrated in zip(
            baseline["samples_ms"], baseline["calibration_samples_ms"]
        )
    ]
    candidate_calibration_deltas = [
        calibrated - normal
        for normal, calibrated in zip(
            candidate["samples_ms"], candidate["calibration_samples_ms"]
        )
    ]
    baseline_calibration_delta = statistics.median(baseline_calibration_deltas)
    candidate_calibration_delta = statistics.median(candidate_calibration_deltas)
    calibration_floor_ms = args.calibration_usec / 1000.0 * args.calibration_min_fraction
    calibration_responsive = (
        min(baseline_calibration_deltas) >= calibration_floor_ms
        and min(candidate_calibration_deltas) >= calibration_floor_ms
    )
    statistical_verdict = "PASS" if upper <= 1.0 else "FAIL" if lower > 1.0 else "INCONCLUSIVE"
    if baseline_only:
        verdict = (
            "PASS"
            if calibration_responsive and lower >= -1.0 and upper <= 1.0
            else "INCONCLUSIVE"
        )
    else:
        verdict = statistical_verdict if calibration_responsive else "INCONCLUSIVE"
    return {
        "mode": "baseline-only-null" if baseline_only else "candidate-comparison",
        "verdict": verdict,
        "threshold_percent": 1.0,
        "baseline": baseline,
        "candidate": candidate,
        "baseline_median_ms": baseline_median,
        "candidate_median_ms": candidate_median,
        "regression_percent": regression_percent,
        "baseline_mad_ms": baseline_mad,
        "candidate_mad_ms": candidate_mad,
        "paired_regression_samples_percent": paired_regressions,
        "paired_regression_mad_percent": paired_mad,
        "one_sided_95_percent_interval": [lower, upper],
        "calibration": {
            "injected_ms_per_frame": args.calibration_usec / 1000.0,
            "minimum_detected_ms": calibration_floor_ms,
            "baseline_detected_ms": baseline_calibration_delta,
            "candidate_detected_ms": candidate_calibration_delta,
            "baseline_trial_deltas_ms": baseline_calibration_deltas,
            "candidate_trial_deltas_ms": candidate_calibration_deltas,
            "responsive": calibration_responsive,
        },
        "statistical_verdict": statistical_verdict,
        "confidence_rationale": (
            "baseline-only positional-slot null; PASS requires the entire paired interval "
            "inside +/-1% and responsive calibration"
            if baseline_only
            else "median of twelve paired exact-SHA process-CPU ratios; MAD-scaled paired standard error; one-sided z=1.645; every trial calibrated with deterministic per-frame CPU load"
        ),
        "protocol": effective_command,
        "profile_source_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "effective_command_sha256": _sha256_json(effective_command),
        "host": {
            "platform": sys.platform,
            "logical_cpu_count": os.cpu_count(),
            "load_observations_are_diagnostic_only": True,
        },
        "execution_order": execution_order,
        "run_order": "twelve independent positional-slot pairs in the predeclared BC-CB-CB-BC schedule repeated three times; each slot runs first in six pairs; identical 1280x720 rendered main-menu configuration and shared import cache; phase-acknowledged process CPU excludes display pacing; each Godot process serialized exclusively by tools/godot_gate.py; all trials and host-load observations retained with no exclusions or retries",
        "cleanup": "complete",
    }


def _add_profile_arguments(parser: argparse.ArgumentParser, *, candidate: bool) -> None:
    parser.add_argument("--baseline-sha", required=True)
    if candidate:
        parser.add_argument("--candidate-sha", required=True)
        parser.add_argument("--null-evidence", required=True)
    parser.add_argument("--warmup-frames", type=int, default=PROFILE_WARMUP_FRAMES)
    parser.add_argument("--frames-per-sample", type=int, default=PROFILE_SAMPLE_FRAMES)
    parser.add_argument("--calibration-usec", type=int, default=PROFILE_CALIBRATION_USEC)
    parser.add_argument(
        "--calibration-min-fraction",
        type=float,
        default=PROFILE_CALIBRATION_MIN_FRACTION,
    )


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", default=str(ROOT))
    parser.add_argument("--godot", default=str(DEFAULT_GODOT))
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("probe")
    subparsers.add_parser("export-probe")
    profile = subparsers.add_parser("profile")
    _add_profile_arguments(profile, candidate=True)
    null_profile = subparsers.add_parser("null-profile")
    _add_profile_arguments(null_profile, candidate=False)
    return parser


def main() -> int:
    parser = _parser()
    args = parser.parse_args()
    try:
        if args.command == "probe":
            result = command_probe(args)
        elif args.command == "export-probe":
            result = command_export_probe(args)
        else:
            fixed_values = (
                args.warmup_frames == PROFILE_WARMUP_FRAMES
                and args.frames_per_sample == PROFILE_SAMPLE_FRAMES
                and args.calibration_usec == PROFILE_CALIBRATION_USEC
                and args.calibration_min_fraction == PROFILE_CALIBRATION_MIN_FRACTION
            )
            if not fixed_values:
                parser.error(
                    "the declared FAN-3905 protocol is fixed at 6000 warmup frames, "
                    "24000 measured frames, 12 predeclared pairs, 2000 calibration usec, "
                    "and 0.75 calibration minimum fraction"
                )
            result = command_profile(args, baseline_only=args.command == "null-profile")
    except (ProbeFailure, OSError, ValueError, json.JSONDecodeError, zipfile.BadZipFile) as exc:
        print(json.dumps({"verdict": "FAIL", "error": str(exc)}, ensure_ascii=False, indent=2))
        return 1
    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    return 0 if result.get("verdict") == "PASS" else 2 if result.get("verdict") == "INCONCLUSIVE" else 1


if __name__ == "__main__":
    sys.exit(main())
