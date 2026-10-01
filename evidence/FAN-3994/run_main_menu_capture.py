#!/usr/bin/env python3
"""FAN-3994: screenshot the installed app's real main menu (version label).
Clone the installed app, override.cfg main scene -> main_menu_capture.gd,
isolated user dir, ad-hoc reseal of the clone (installed app untouched).
Usage: run_main_menu_capture.py --app /Applications/FantasyDisk.app --out <dir> --label v0.3.1.2_installed
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SCRIPT = HERE / "main_menu_capture.gd"
USER_DIR_NAME = "FantasyDiskFan3994Menu"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--app", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--label", required=True)
    args = parser.parse_args()
    out = args.out.resolve(); out.mkdir(parents=True, exist_ok=True)
    source = args.app.resolve(); clone = out / "clone" / source.name
    if clone.exists():
        shutil.rmtree(clone)
    clone.parent.mkdir(parents=True, exist_ok=True)
    if subprocess.run(["cp", "-Rc", str(source), str(clone)], capture_output=True).returncode != 0:
        shutil.copytree(source, clone, symlinks=True)
    scene = out / "fan3994_main_menu_capture.tscn"
    scene.write_text("[gd_scene load_steps=2 format=3]\n\n" f'[ext_resource type="Script" path="{SCRIPT}" id="1"]\n\n'
                     '[node name="Fan3994MainMenuCapture" type="Node2D"]\nscript = ExtResource("1")\n', encoding="utf-8")
    binary = clone / "Contents" / "MacOS" / "FantasyDisk"
    (binary.parent / "override.cfg").write_text("[application]\n" f'run/main_scene="{scene}"\n' "config/use_custom_user_dir=true\n"
                                                f'config/custom_user_dir_name="{USER_DIR_NAME}"\n\n[updates]\ncheck_on_startup=false\n', encoding="utf-8")
    subprocess.run(["codesign", "--force", "--deep", "--sign", "-", str(clone)], check=True, capture_output=True)
    pck_source = sha256(source / "Contents" / "Resources" / "FantasyDisk.pck")
    pck_clone = sha256(clone / "Contents" / "Resources" / "FantasyDisk.pck")
    png = out / f"main_menu_{args.label}.png"
    log = out / "main_menu_capture.log"
    with log.open("w", encoding="utf-8") as handle:
        completed = subprocess.run([str(binary), "--windowed", "--resolution", "1920x1080", "--", f"--capture={png}"],
                                   cwd=binary.parent, stdout=handle, stderr=subprocess.STDOUT, timeout=120)
    text = log.read_text(encoding="utf-8", errors="replace")
    line = next((l for l in text.splitlines() if l.startswith("main_menu_capture:")), "")
    result = {"app": str(source), "pck_sha256": pck_source, "clone_pck_identical": pck_source == pck_clone, "exit_code": completed.returncode,
              "capture": png.name, "capture_sha256": sha256(png) if png.is_file() else None, "result_line": line}
    (out / "main_menu_capture.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 0 if completed.returncode == 0 and png.is_file() else 1


if __name__ == "__main__":
    sys.exit(main())
