#!/usr/bin/env python3
"""Reproducible crash-logger probes and exact-SHA P1 frame profiling."""

from __future__ import annotations

import argparse
import json
import math
import os
from pathlib import Path
import re
import statistics
import subprocess
import sys
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_GODOT = Path("/Applications/Godot.app/Contents/MacOS/Godot")
EXPECTED_ERROR = "FAN-3905 deterministic expected-error probe"
SELF_TEST_ERROR = "FAN-3905 deterministic crash logger self-test"
INCIDENT_GLOB = "incident_*.json"
PROFILE_MARKER = "FAN3905_FRAME_PROFILE="

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
	var calibration_usec := 2000
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--warmup-frames="):
			warmup_frames = int(argument.trim_prefix("--warmup-frames="))
		elif argument.begins_with("--sample-frames="):
			sample_frames = int(argument.trim_prefix("--sample-frames="))
		elif argument.begins_with("--calibration-usec="):
			calibration_usec = int(argument.trim_prefix("--calibration-usec="))
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
	var normal: Dictionary = await _sample_windows(sample_frames)
	calibration_load.busy_usec = calibration_usec
	for frame in range(maxi(60, int(warmup_frames / 10))):
		await process_frame
	var calibrated: Dictionary = await _sample_windows(sample_frames)
	print(PROFILE_MARKER + JSON.stringify({
		"display": DisplayServer.get_name(),
		"metric": "wall time with --fixed-fps 60 real-time synchronization disabled",
		"warmup_frames": warmup_frames,
		"frames_per_sample": sample_frames,
		"samples_ms": normal["wall_ms"],
		"calibration_injected_ms": float(calibration_usec) / 1000.0,
		"calibration_samples_ms": calibrated["wall_ms"],
	}))
	quit(0)


func _sample_windows(sample_frames: int) -> Dictionary:
	var wall_samples_ms: Array[float] = []
	for sample_index in range(5):
		var wall_started := Time.get_ticks_usec()
		for frame in range(sample_frames):
			await process_frame
		var elapsed_usec := Time.get_ticks_usec() - wall_started
		wall_samples_ms.append(float(elapsed_usec) / float(sample_frames) / 1000.0)
	return {"wall_ms": wall_samples_ms}
'''


class ProbeFailure(RuntimeError):
    pass


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
        gate = worktree / "tools" / "godot_gate.py"
        if not gate.is_file():
            raise ProbeFailure(f"frame profile revision {revision} lacks tools/godot_gate.py")
        completed = _run(
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
                "--fixed-fps",
                "60",
                "--",
                f"--warmup-frames={warmup_frames}",
                f"--sample-frames={sample_frames}",
                f"--calibration-usec={calibration_usec}",
            ],
            worktree,
            env={"FSD_GODOT_EXCLUSIVE": "1", "GODOT_BIN": str(godot)},
        )
        diagnostics = _diagnostic_lines(completed.stdout)
        if diagnostics:
            raise ProbeFailure(f"frame profile for {revision} emitted fatal diagnostics: {diagnostics}")
        marker_lines = [line for line in completed.stdout.splitlines() if line.startswith(PROFILE_MARKER)]
        if len(marker_lines) != 1:
            raise ProbeFailure(f"frame profile for {revision} emitted {len(marker_lines)} result markers")
        payload = json.loads(marker_lines[0][len(PROFILE_MARKER) :])
        samples = [float(value) for value in payload.get("samples_ms", [])]
        calibration_samples = [float(value) for value in payload.get("calibration_samples_ms", [])]
        if len(samples) != 5 or any(not math.isfinite(value) or value <= 0 for value in samples):
            raise ProbeFailure(f"frame profile for {revision} did not return five valid samples")
        if len(calibration_samples) != 5 or any(
            not math.isfinite(value) or value <= 0 for value in calibration_samples
        ):
            raise ProbeFailure(f"frame profile for {revision} did not return five valid calibration samples")
        if payload.get("display") == "headless":
            raise ProbeFailure("P1 profile unexpectedly used the headless display driver")
        return {"sha": revision, **payload}
    finally:
        _run(["git", "worktree", "remove", "--force", str(worktree)], project)


def _median_and_mad(samples: list[float]) -> tuple[float, float]:
    median = statistics.median(samples)
    mad = statistics.median(abs(value - median) for value in samples)
    return median, mad


def command_profile(args: argparse.Namespace) -> dict:
    project = _project_path(args.project)
    godot = _godot_path(args.godot)
    baseline_sha = _resolve_commit(project, args.baseline_sha)
    candidate_sha = _resolve_commit(project, args.candidate_sha)
    cache = (project / ".godot").resolve()
    with tempfile.TemporaryDirectory(prefix=".fan3905-profile-", dir=project.parent) as temp_name:
        temp = Path(temp_name).resolve()
        baseline = _profile_one(
            project,
            godot,
            baseline_sha,
            temp / "baseline",
            cache,
            args.warmup_frames,
            args.frames_per_sample,
            args.calibration_usec,
        )
        candidate = _profile_one(
            project,
            godot,
            candidate_sha,
            temp / "candidate",
            cache,
            args.warmup_frames,
            args.frames_per_sample,
            args.calibration_usec,
        )
    baseline_median, baseline_mad = _median_and_mad(baseline["samples_ms"])
    candidate_median, candidate_mad = _median_and_mad(candidate["samples_ms"])
    regression_percent = (candidate_median / baseline_median - 1.0) * 100.0
    # Robust normal approximation around the median. 1.4826 scales MAD to sigma;
    # 1.645 is the one-sided 95% bound required by the <=1% regression decision.
    relative_se = math.sqrt(
        (1.4826 * baseline_mad / math.sqrt(5) / baseline_median) ** 2
        + (1.4826 * candidate_mad / math.sqrt(5) / candidate_median) ** 2
    )
    bound = 1.645 * relative_se * 100.0
    lower = regression_percent - bound
    upper = regression_percent + bound
    baseline_calibration_median = statistics.median(baseline["calibration_samples_ms"])
    candidate_calibration_median = statistics.median(candidate["calibration_samples_ms"])
    baseline_calibration_delta = baseline_calibration_median - baseline_median
    candidate_calibration_delta = candidate_calibration_median - candidate_median
    calibration_floor_ms = args.calibration_usec / 1000.0 * args.calibration_min_fraction
    calibration_responsive = (
        baseline_calibration_delta >= calibration_floor_ms
        and candidate_calibration_delta >= calibration_floor_ms
    )
    statistical_verdict = "PASS" if upper <= 1.0 else "FAIL" if lower > 1.0 else "INCONCLUSIVE"
    verdict = statistical_verdict if calibration_responsive else "INCONCLUSIVE"
    return {
        "verdict": verdict,
        "threshold_percent": 1.0,
        "baseline": baseline,
        "candidate": candidate,
        "baseline_median_ms": baseline_median,
        "candidate_median_ms": candidate_median,
        "regression_percent": regression_percent,
        "baseline_mad_ms": baseline_mad,
        "candidate_mad_ms": candidate_mad,
        "one_sided_95_percent_interval": [lower, upper],
        "calibration": {
            "injected_ms_per_frame": args.calibration_usec / 1000.0,
            "minimum_detected_ms": calibration_floor_ms,
            "baseline_detected_ms": baseline_calibration_delta,
            "candidate_detected_ms": candidate_calibration_delta,
            "responsive": calibration_responsive,
        },
        "statistical_verdict": statistical_verdict,
        "confidence_rationale": "fixed-step wall time with real-time synchronization disabled, median of five post-warmup means; MAD-scaled independent standard errors; one-sided z=1.645; calibrated with deterministic per-frame CPU load",
        "run_order": "baseline then candidate; identical 1280x720 rendered main-menu configuration, --fixed-fps 60, and shared import cache; each Godot process serialized exclusively by tools/godot_gate.py",
        "cleanup": "complete",
    }


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", default=str(ROOT))
    parser.add_argument("--godot", default=str(DEFAULT_GODOT))
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("probe")
    subparsers.add_parser("export-probe")
    profile = subparsers.add_parser("profile")
    profile.add_argument("--baseline-sha", required=True)
    profile.add_argument("--candidate-sha", required=True)
    profile.add_argument("--warmup-frames", type=int, default=600)
    profile.add_argument("--frames-per-sample", type=int, default=3000)
    profile.add_argument("--calibration-usec", type=int, default=2000)
    profile.add_argument("--calibration-min-fraction", type=float, default=0.75)
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
            if args.warmup_frames < 60 or args.frames_per_sample < 300:
                parser.error("profile requires at least 60 warmup and 300 measured frames")
            if args.calibration_usec < 1000 or not 0.5 <= args.calibration_min_fraction <= 1.0:
                parser.error("profile calibration requires >=1000 usec and a minimum fraction in [0.5, 1.0]")
            result = command_profile(args)
    except (ProbeFailure, OSError, json.JSONDecodeError, zipfile.BadZipFile) as exc:
        print(json.dumps({"verdict": "FAIL", "error": str(exc)}, ensure_ascii=False, indent=2))
        return 1
    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    return 0 if result.get("verdict") == "PASS" else 2 if result.get("verdict") == "INCONCLUSIVE" else 1


if __name__ == "__main__":
    sys.exit(main())
