#!/usr/bin/env python3
"""Capture the three current ultimate sheets into this card's evidence directory.

The maintained capture scripts are copied to temporary task-owned paths with
only their output target changed. The source scripts and their reference PNGs
remain untouched.
"""

from __future__ import annotations

import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = Path(__file__).resolve().parent
CAPTURES = EVIDENCE / "captures"
SOURCES = {
    "assassin": (
        "tests/ultimates/presentation/assassin_ultimate_contact_capture.gd",
        'var path := str(capture.get("path", ""))',
        'var path := "res://evidence/FAN-3968/captures/assassin_%d.png" % viewport.size.y',
    ),
    "doctor": (
        "tests/ultimates/presentation/doctor_ultimate_contact_capture.gd",
        'var output := str(capture["path"])',
        'var output := "res://evidence/FAN-3968/captures/doctor_%d.png" % viewport.size.y',
    ),
    "robot": (
        "tests/ultimates/presentation/robot_ultimate_contact_capture.gd",
        'var output := str(spec.get("path", ""))',
        'var output := "res://evidence/FAN-3968/captures/robot_%d.png" % viewport.size.y',
    ),
}
SHEET_FIXUPS = {
    "assassin": (
        "\t\tviewport.add_child(_make_sheet(viewport.size))",
        "\t\tvar sheet := _make_sheet(viewport.size)\n"
        "\t\tviewport.add_child(sheet)\n"
        "\t\tfor child in sheet.get_children():\n"
        "\t\t\tif not child.has_node(\"Timeline\"):\n"
        "\t\t\t\tcontinue\n"
        "\t\t\tvar scene := child as Node2D\n"
        "\t\t\tscene.show()\n"
        "\t\t\tvar backdrop := scene.get_node_or_null(\"BackdropLayer\") as CanvasLayer\n"
        "\t\t\tif backdrop != null:\n"
        "\t\t\t\tbackdrop.visible = false\n"
        "\t\t\tvar timeline := scene.get_node(\"Timeline\") as AnimationPlayer\n"
        "\t\t\tfor raw_pack in PACKS:\n"
        "\t\t\t\tif str(raw_pack[\"weapon_id\"]) == str(scene.get_meta(\"ultimate_id\")).get_slice(\"/\", 1):\n"
        "\t\t\t\t\ttimeline.play(&\"ultimate\")\n"
        "\t\t\t\t\ttimeline.seek(float(raw_pack[\"time\"]), true)",
    ),
    "doctor": (
        "\t\tviewport.add_child(_make_sheet(capture[\"size\"]))",
        "\t\tvar sheet := _make_sheet(capture[\"size\"])\n"
        "\t\tviewport.add_child(sheet)\n"
        "\t\tfor child in sheet.get_children():\n"
        "\t\t\tif child.has_node(\"BackdropLayer\"):\n"
        "\t\t\t\t(child.get_node(\"BackdropLayer\") as CanvasLayer).visible = false",
    ),
}
ASSASSIN_PANEL_FIXUPS = (
    (
        "\tfor raw_pack in PACKS:\n\t\tvar pack := raw_pack as Dictionary",
        "\tfor raw_pack in PACKS.slice(1):\n\t\tvar pack := raw_pack as Dictionary",
    ),
    (
        'var center := Vector2(size) * (pack.get("position", Vector2.ZERO) as Vector2)',
        'var center := Vector2(size) * (Vector2(0.32, 0.55) if str(pack["weapon_id"]) == "shadow_daggers" else Vector2(0.68, 0.55))',
    ),
)
FIRST_FRAME_WARMUP = {
    "assassin": (
        "\tfor raw_capture in SPEC.CAPTURES:",
        "\tfor raw_capture in [SPEC.CAPTURES[0]] + SPEC.CAPTURES:",
    ),
    "doctor": (
        "\tfor raw_capture in SPEC.CAPTURES:",
        "\tfor raw_capture in [SPEC.CAPTURES[0]] + SPEC.CAPTURES:",
    ),
    "robot": (
        "\tfor capture in CaptureSpec.CAPTURES:",
        "\tfor capture in [CaptureSpec.CAPTURES[0]] + CaptureSpec.CAPTURES:",
    ),
}


def main() -> int:
    CAPTURES.mkdir(parents=True, exist_ok=True)
    for name, (source, original, replacement) in SOURCES.items():
        code = (ROOT / source).read_text()
        if code.count(original) != 1:
            raise RuntimeError(f"Capture source output site changed: {source}")
        code = code.replace(original, replacement)
        before, after = FIRST_FRAME_WARMUP[name]
        if code.count(before) != 1:
            raise RuntimeError(f"Capture source loop changed: {source}")
        code = code.replace(before, after)
        if name in SHEET_FIXUPS:
            before, after = SHEET_FIXUPS[name]
            if code.count(before) != 1:
                raise RuntimeError(f"Capture source sheet site changed: {source}")
            code = code.replace(before, after)
        if name == "assassin":
            for before, after in ASSASSIN_PANEL_FIXUPS:
                if code.count(before) != 1:
                    raise RuntimeError(f"Assassin panel site changed: {before}")
                code = code.replace(before, after)
        temporary = EVIDENCE / f".capture_{name}.gd"
        temporary.write_text(code)
        try:
            command = [
                "python3", "tools/godot_gate.py", "--path", ".",
                "--windowed", "--fixed-fps", "60",
                "--script", f"res://evidence/FAN-3968/{temporary.name}",
            ]
            result = subprocess.run(
                command, cwd=ROOT, stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT, text=True, check=False,
            )
            (EVIDENCE / f"{name}_capture.log").write_text(result.stdout)
            print(f"{name} capture exit {result.returncode}")
            if result.returncode:
                print("\n".join(result.stdout.splitlines()[-18:]))
                return result.returncode
        finally:
            temporary.unlink(missing_ok=True)
            temporary.with_suffix(".gd.uid").unlink(missing_ok=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
