#!/usr/bin/env python3
"""FAN-3994: run the FAN-3991 single-process multi-class session probe
(`tools/ultimate_session_lifecycle_probe.gd`) INSIDE the installed release
app and judge its output the way `tests/ultimates/multi_class_session_
lifecycle_test.gd` does.

Launch mechanism (FAN-3985/FAN-3989): the installed app is cloned (APFS
clone; the original is never modified), an ``override.cfg`` beside the
clone's executable selects an isolated user directory, turns the update
check off and starts the probe; the clone is re-sealed ad-hoc because macOS
26 kills a notarized app whose seal was broken, and its PCK is verified
byte-identical to the installed app's. Everything that runs — Main, the
combat director, Player, the ultimate host, executors and presentation
scenes — is the PCK's own exported code and data.

Two ways to start a SceneTree-derived probe without ``--script`` (refused by
official export templates):
  * ``main_loop_type``: ``application/run/main_loop_type`` names the probe
    script (the engine instantiates its base SceneTree and installs the
    script); ``run/main_scene`` is a trivial empty scene.
  * ``wrapper``: ``run/main_scene`` is a scene carrying
    ``session_probe_wrapper.gd``, which sets the probe script on the live
    SceneTree and calls ``_initialize``.

Per sequence one fresh process: ``--disable-crash-handler`` (a crash is an
immediate signal) and ``--log-file`` (every engine error stays on disk);
stdout/stderr are captured as well. A sequence fails on any lifecycle error
pattern in either log, a non-zero exit, a timeout, a missing report, a
report that is not ``pass`` or a pair count mismatch.

Usage:
    python3 evidence/FAN-3994/run_session_probe_in_app.py --app /Applications/FantasyDisk.app \
        --out <dir> --label v0.3.1.2_installed [--windowed] [--mode main_loop_type|wrapper] \
        [--sequences dark_mage_then_doctor chemist_then_doctor ...]
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
PROBE = ROOT / "tools" / "ultimate_session_lifecycle_probe.gd"
WRAPPER = HERE / "session_probe_wrapper.gd"
USER_DIR_NAME = "FantasyDiskFan3994Session"
EXPECTED_ALL_PAIRS = 51
TIMEOUT_BASE = 120.0
TIMEOUT_PER_PAIR = 30.0
LIFECYCLE_ERROR_PATTERNS = [
    "Parent node is busy adding/removing children",
    "Parent node is busy setting up children",
    'Condition "data.parent" is true',
    'Condition "!data.tree" is true',
    'Condition "p_node->data.tree != data.tree" is true',
    'Parameter "canvas_item" is null',
    "previously freed",
    "Trying to cast a freed object",
    "SCRIPT ERROR",
]
# The FAN-3991 gate sequences (tests/ultimates/multi_class_session_lifecycle_test.gd)
# plus the FAN-3990 driver's default `force` ending for the first pair.
SEQUENCES = {
    "dark_mage_then_doctor": (["--classes=dark_mage,doctor", "--end=during_cast"], 6),
    "chemist_then_doctor": (["--classes=chemist,doctor", "--end=during_cast"], 6),
    "dark_mage_then_doctor_natural_end": (["--classes=dark_mage,doctor", "--end=natural"], 6),
    "dark_mage_then_doctor_force": (["--classes=dark_mage,doctor", "--end=force"], 6),
    "all_17_classes": (["--all", "--end=during_cast"], EXPECTED_ALL_PAIRS),
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def app_binary(app: Path) -> Path:
    plist = app / "Contents" / "Info.plist"
    name = subprocess.run(["/usr/libexec/PlistBuddy", "-c", "Print CFBundleExecutable", plist],
                          check=True, capture_output=True, text=True).stdout.strip()
    return app / "Contents" / "MacOS" / name


def clone_app(app: Path, destination: Path) -> Path:
    if destination.exists():
        shutil.rmtree(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(["cp", "-Rc", str(app), str(destination)], check=False, capture_output=True)
    if result.returncode != 0:
        shutil.copytree(app, destination, symlinks=True)
    return destination


def write_scene(out: Path, mode: str) -> Path:
    scene = out / f"fan3994_session_{mode}.tscn"
    if mode == "wrapper":
        scene.write_text(
            "[gd_scene load_steps=2 format=3]\n\n"
            f'[ext_resource type="Script" path="{WRAPPER}" id="1_wrapper"]\n\n'
            '[node name="Fan3994SessionProbeWrapper" type="Node"]\n'
            'script = ExtResource("1_wrapper")\n',
            encoding="utf-8",
        )
    else:
        scene.write_text('[gd_scene format=3]\n\n[node name="Fan3994Empty" type="Node"]\n', encoding="utf-8")
    return scene


def install_override(app: Path, scene: Path, mode: str) -> None:
    override = app_binary(app).parent / "override.cfg"
    lines = ["[application]", f'run/main_scene="{scene}"']
    if mode == "main_loop_type":
        lines.append(f'run/main_loop_type="{PROBE}"')
    lines += ["config/use_custom_user_dir=true", f'config/custom_user_dir_name="{USER_DIR_NAME}"', "",
              "[updates]", "check_on_startup=false", ""]
    override.write_text("\n".join(lines), encoding="utf-8")


def scan(text: str) -> dict:
    counts = {pattern: 0 for pattern in LIFECYCLE_ERROR_PATTERNS}
    offending = []
    for line in text.splitlines():
        for pattern in LIFECYCLE_ERROR_PATTERNS:
            if pattern in line:
                counts[pattern] += 1
                if len(offending) < 40:
                    offending.append(line.strip())
    return {"counts": {k: v for k, v in counts.items() if v}, "total": sum(counts.values()), "offending": offending}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--app", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--label", required=True)
    parser.add_argument("--mode", choices=("main_loop_type", "wrapper"), default="main_loop_type")
    parser.add_argument("--windowed", action="store_true", help="real renderer (default: --headless like the gate)")
    parser.add_argument("--resolution", default="1280x720")
    parser.add_argument("--sequences", nargs="*", default=list(SEQUENCES))
    args = parser.parse_args(argv)
    out: Path = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    source_app = args.app.resolve()
    app = clone_app(source_app, out / "clone" / source_app.name)
    scene = write_scene(out, args.mode)
    install_override(app, scene, args.mode)
    subprocess.run(["codesign", "--force", "--deep", "--sign", "-", str(app)], check=True, capture_output=True)
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True, capture_output=True)
    source_pck = sha256(source_app / "Contents" / "Resources" / "FantasyDisk.pck")
    clone_pck = sha256(app / "Contents" / "Resources" / "FantasyDisk.pck")
    if source_pck != clone_pck:
        print(f"ERROR: clone PCK {clone_pck} != source PCK {source_pck}", file=sys.stderr)
        return 2
    print(f"clone re-sealed ad-hoc; PCK sha256 {source_pck} identical to {source_app}; mode={args.mode} probe={PROBE}", flush=True)
    binary = app_binary(app)
    results = []
    for label in args.sequences:
        probe_args, expected_pairs = SEQUENCES[label]
        report = out / f"{args.label}__{label}.json"
        engine_log = out / f"{args.label}__{label}.engine.log"
        stdout_log = out / f"{args.label}__{label}.stdout.log"
        for stale in (report, engine_log):
            if stale.exists():
                stale.unlink()
        command = [str(binary), "--disable-crash-handler", "--log-file", str(engine_log)]
        command += ["--windowed", "--resolution", args.resolution] if args.windowed else ["--headless"]
        command += ["--", *probe_args, f"--report={report}"]
        if args.mode == "wrapper":
            command.append(f"--probe={PROBE}")
        timeout = TIMEOUT_BASE + TIMEOUT_PER_PAIR * expected_pairs
        started = time.time()
        print(f"==> {args.label} {label} ({expected_pairs} pairs, timeout {timeout:.0f} s)", flush=True)
        entry = {"sequence": label, "args": probe_args, "expected_pairs": expected_pairs, "command": command,
                 "exit_code": None, "timed_out": False, "problems": []}
        try:
            with stdout_log.open("w", encoding="utf-8") as handle:
                completed = subprocess.run(command, cwd=binary.parent, stdout=handle, stderr=subprocess.STDOUT, timeout=timeout)
            entry["exit_code"] = completed.returncode
        except subprocess.TimeoutExpired:
            entry["timed_out"] = True
            entry["problems"].append(f"timed out after {timeout:.0f} s")
        entry["seconds"] = round(time.time() - started, 1)
        engine_text = engine_log.read_text(encoding="utf-8", errors="replace") if engine_log.is_file() else ""
        stdout_text = stdout_log.read_text(encoding="utf-8", errors="replace") if stdout_log.is_file() else ""
        entry["engine_log_scan"] = scan(engine_text)
        entry["stdout_scan"] = scan(stdout_text)
        if entry["engine_log_scan"]["total"] or entry["stdout_scan"]["total"]:
            entry["problems"].append("lifecycle error patterns in the logs")
        if not engine_log.is_file():
            entry["problems"].append("engine log missing")
        if entry["exit_code"] not in (0,) and not entry["timed_out"]:
            entry["problems"].append(f"exit code {entry['exit_code']} (negative = signal)")
        if report.is_file():
            data = json.loads(report.read_text(encoding="utf-8"))
            entry["report"] = report.name
            entry["pairs_total"] = data.get("pairs_total")
            entry["pairs_passing"] = data.get("pairs_passing")
            entry["report_pass"] = data.get("pass")
            entry["display_server"] = data.get("display_server")
            entry["engine_version"] = data.get("engine_version")
            entry["peak_object_count"] = data.get("peak_object_count")
            entry["pairs"] = [{k: p.get(k) for k in ("key", "pass", "activated_by_input_action", "instantiated_scene",
                                                      "cast_frames", "ultimate_active_at_end", "presentation_active_at_end", "failures")}
                              for p in data.get("pairs", [])]
            if data.get("pairs_total") != expected_pairs:
                entry["problems"].append(f"report has {data.get('pairs_total')} pairs, expected {expected_pairs}")
            if not data.get("pass"):
                entry["problems"].append("probe report is not pass")
            if any(not p.get("activated_by_input_action") for p in data.get("pairs", [])):
                entry["problems"].append("a pair did not activate through the ultimate action")
        else:
            entry["problems"].append("probe wrote no report")
        entry["pass"] = not entry["problems"]
        print(f"    exit {entry['exit_code']} timed_out={entry['timed_out']} {entry['seconds']}s pairs {entry.get('pairs_passing')}/{entry.get('pairs_total')} "
              f"engine-log errors {entry['engine_log_scan']['total']} stdout errors {entry['stdout_scan']['total']} problems {entry['problems']}", flush=True)
        results.append(entry)
    summary = {
        "probe": str(PROBE.relative_to(ROOT)), "mode": args.mode, "windowed": args.windowed, "app": str(source_app), "clone": str(app),
        "clone_reseal": "ad-hoc (codesign --force --deep --sign -) after override.cfg",
        "source_pck_sha256": source_pck, "clone_pck_sha256": clone_pck, "user_dir_name": USER_DIR_NAME,
        "lifecycle_error_patterns": LIFECYCLE_ERROR_PATTERNS, "sequences": results,
        "pass": bool(results) and all(r["pass"] for r in results),
    }
    (out / f"{args.label}_summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(f"session probe {args.label}: pass={summary['pass']} ({sum(1 for r in results if r['pass'])}/{len(results)} sequences)", flush=True)
    return 0 if summary["pass"] else 1


if __name__ == "__main__":
    sys.exit(main())
