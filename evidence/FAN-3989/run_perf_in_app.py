#!/usr/bin/env python3
"""FAN-3989: run perf_ultimate_driver.gd inside a release app (installed
0.3.1.1 or the retained 0.3.1 DMG app for comparison).

Same launch mechanism as tools/ultimate_export_probe.py (FAN-3985): the app
is cloned (APFS clone, the original is never modified), an ``override.cfg``
beside the clone's executable points ``application/run/main_scene`` at a
generated scene that carries ``perf_ultimate_driver.gd`` and selects an
isolated user directory, then the clone's own binary is started windowed
with the shipping renderer.  One process per (class, weapon) run.

Usage:
    python3 evidence/FAN-3989/run_perf_in_app.py --app /Applications/FantasyDisk.app \
        --label v0.3.1.1 --out <dir> --runs berserk/sword druid/summon_amulet ...
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
DRIVER = HERE / "perf_ultimate_driver.gd"
USER_DIR_NAME = "FantasyDiskFan3989Perf"
TIMEOUT = 600.0


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


def write_scene(output_dir: Path) -> Path:
    scene = output_dir / "fan3989_perf_driver.tscn"
    scene.write_text(
        "[gd_scene load_steps=2 format=3]\n\n"
        f'[ext_resource type="Script" path="{DRIVER}" id="1_driver"]\n\n'
        '[node name="Fan3989PerfDriver" type="Node2D"]\n'
        'script = ExtResource("1_driver")\n',
        encoding="utf-8",
    )
    return scene


def install_override(app: Path, scene: Path) -> None:
    override = app_binary(app).parent / "override.cfg"
    override.write_text(
        "[application]\n"
        f'run/main_scene="{scene}"\n'
        "config/use_custom_user_dir=true\n"
        f'config/custom_user_dir_name="{USER_DIR_NAME}"\n\n'
        "[updates]\n"
        "check_on_startup=false\n",
        encoding="utf-8",
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--app", type=Path, required=True)
    parser.add_argument("--label", required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--runs", nargs="+", required=True, help="class/weapon pairs")
    parser.add_argument("--seconds", type=int, default=60)
    parser.add_argument("--cast-every", type=int, default=8)
    parser.add_argument("--resolution", default="2560x1440")
    parser.add_argument("--captures", action="store_true")
    args = parser.parse_args(argv)
    out: Path = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    source_app = args.app.resolve()
    app = clone_app(source_app, out / "clone" / args.app.name)
    scene = write_scene(out)
    install_override(app, scene)
    # macOS 26 kills and removes a Developer ID / notarized app whose seal was
    # broken by the added override.cfg (FAN-2199 behaviour, reproduced here).
    # Re-seal the CLONE ad-hoc so it launches like the FAN-3985 exported app;
    # the installed app is untouched and the clone's PCK stays byte-identical.
    subprocess.run(["codesign", "--force", "--deep", "--sign", "-", str(app)], check=True, capture_output=True)
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True, capture_output=True)
    pck_name = "FantasyDisk.pck"
    source_pck = sha256(source_app / "Contents" / "Resources" / pck_name)
    clone_pck = sha256(app / "Contents" / "Resources" / pck_name)
    if source_pck != clone_pck:
        print(f"ERROR: clone PCK {clone_pck} != source PCK {source_pck}", file=sys.stderr)
        return 2
    print(f"clone re-sealed ad-hoc; PCK sha256 {source_pck} identical to {source_app}", flush=True)
    binary = app_binary(app)
    capture_dir = out / "captures"
    if args.captures:
        capture_dir.mkdir(exist_ok=True)
    results = []
    for pair in args.runs:
        class_id, weapon_id = pair.split("/", 1)
        report = out / f"{args.label}__{class_id}__{weapon_id}.json"
        log = out / f"{args.label}__{class_id}__{weapon_id}.log"
        if report.exists():
            report.unlink()
        command = [str(binary), "--windowed", "--resolution", args.resolution, "--",
                   f"--report={report}", f"--label={args.label}", f"--class={class_id}", f"--weapon={weapon_id}",
                   f"--seconds={args.seconds}", f"--cast-every={args.cast_every}"]
        if args.captures:
            command.append(f"--captures={capture_dir}")
        started = time.time()
        print(f"==> {args.label} {pair}", flush=True)
        entry = {"pair": pair, "command": command, "exit_code": None, "timed_out": False}
        try:
            with log.open("w", encoding="utf-8") as handle:
                completed = subprocess.run(command, cwd=binary.parent, stdout=handle, stderr=subprocess.STDOUT, timeout=TIMEOUT)
            entry["exit_code"] = completed.returncode
        except subprocess.TimeoutExpired:
            entry["timed_out"] = True
        entry["seconds"] = round(time.time() - started, 1)
        if report.is_file():
            data = json.loads(report.read_text(encoding="utf-8"))
            entry["report"] = report.name
            entry["pass"] = data.get("pass")
            entry["resolution_source"] = data.get("resolution_source")
            entry["casts"] = f"{data.get('casts_activated')}/{data.get('casts_total')}"
            entry["scenes"] = data.get("instantiated_scenes")
            phase = data.get("phase", {})
            entry["phase"] = {k: phase.get(k) for k in ("seconds", "avg_fps", "low_1pct_fps", "worst_second_fps", "frames_over_50ms",
                                                          "frames_over_100ms", "longest_frame_ms", "peak_texture_mib", "objects_peak",
                                                          "objects_min", "objects_first_second", "objects_last_second", "alive_at_end",
                                                          "resident_packs_start", "resident_packs_end", "capture")}
        for line in log.read_text(encoding="utf-8", errors="replace").splitlines():
            if line.startswith(("driver ", "phase ", "cast @", "| ", "perf_ultimate_driver:")):
                print("    " + line, flush=True)
        print(f"    exit {entry['exit_code']} timed_out={entry['timed_out']} in {entry['seconds']}s", flush=True)
        results.append(entry)
    (out / f"{args.label}_summary.json").write_text(json.dumps({
        "app": str(source_app), "clone": str(app), "clone_reseal": "ad-hoc (codesign --force --deep --sign -) after override.cfg",
        "source_pck_sha256": source_pck, "clone_pck_sha256": clone_pck, "runs": results,
    }, indent=2) + "\n", encoding="utf-8")
    return 0 if all(r.get("exit_code") == 0 and r.get("pass") for r in results) else 1


if __name__ == "__main__":
    sys.exit(main())
