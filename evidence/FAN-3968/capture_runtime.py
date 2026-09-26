#!/usr/bin/env python3
"""Render live class scenes and their cast pose/backdrop at four sizes."""

from __future__ import annotations

import subprocess
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = Path(__file__).resolve().parent
PARTS = EVIDENCE / "runtime_parts"
CASES = (
    "assassin_shadow", "assassin_venom", "doctor_restore", "doctor_plague",
    "doctor_saw", "robot_anchor", "robot_press", "robot_reactor",
)
HEIGHTS = (648, 720, 1080, 1440)

SCRIPT = r'''extends SceneTree

const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const CASES := [
	{"name": "assassin_shadow", "scene": preload("res://scenes/vfx/ultimates/assassin/AssassinShadowDaggersMomentBeforeDeath.tscn"), "time": 2.6},
	{"name": "assassin_venom", "scene": preload("res://scenes/vfx/ultimates/assassin/AssassinVenomWireBlackWeb.tscn"), "time": 2.8},
	{"name": "doctor_restore", "scene": preload("res://scenes/vfx/ultimates/doctor/DoctorRestorePotionElixir.tscn"), "time": 2.1},
	{"name": "doctor_plague", "scene": preload("res://scenes/vfx/ultimates/doctor/DoctorPlagueSyringeBlackEpidemic.tscn"), "time": 2.6},
	{"name": "doctor_saw", "scene": preload("res://scenes/vfx/ultimates/doctor/DoctorBoneSawEmergencySurgery.tscn"), "time": 1.7},
	{"name": "robot_anchor", "scene": preload("res://scenes/vfx/ultimates/robot/RobotMagneticAnchorSingularity.tscn"), "time": 2.0},
	{"name": "robot_press", "scene": preload("res://scenes/vfx/ultimates/robot/RobotHydraulicPressProtocol.tscn"), "time": 2.0},
	{"name": "robot_reactor", "scene": preload("res://scenes/vfx/ultimates/robot/RobotReactorCoreRedZone.tscn"), "time": 2.0},
]


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("FAN-3968 runtime capture needs a windowed renderer")
		quit(1)
		return
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	for height in [648, 720, 1080, 1440]:
		var panel_size := Vector2i(int(height * 16.0 / 9.0) / 4, height / 2)
		var cases_to_capture := CASES.duplicate()
		if height == 648:
			cases_to_capture.push_front(CASES[0])
		for spec in cases_to_capture:
			var viewport := SubViewport.new()
			viewport.size = panel_size
			viewport.transparent_bg = false
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(viewport)
			var background := ColorRect.new()
			background.color = Color(0.08, 0.085, 0.11, 1.0)
			viewport.add_child(background)
			background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			var player := Node2D.new()
			player.position = Vector2(panel_size) * Vector2(0.5, 0.54)
			var visual_root := Node2D.new()
			visual_root.name = "VisualRoot"
			player.add_child(visual_root)
			var body := Sprite2D.new()
			body.name = "Body"
			visual_root.add_child(body)
			viewport.add_child(player)
			player.add_to_group("player")
			await process_frame
			var scene := (spec["scene"] as PackedScene).instantiate() as Node2D
			scene.position = player.position
			viewport.add_child(scene)
			scene.call("begin", registry, {}, 0)
			if not str(spec["name"]).begins_with("robot_"):
				var plate := visual_root.get_node_or_null("UltimateCastPoseBackdrop") as Sprite2D
				if plate == null or not (plate.texture is GradientTexture2D):
					push_error("FAN-3968 cast pose missing: %s (%s)" % [spec["name"], str(scene.get("_cast_pose_binding_error"))])
					quit(1)
					return
				var texture := plate.texture as GradientTexture2D
				var pixels := texture.get_image()
				var center_alpha := pixels.get_pixel(32, 32).a * plate.modulate.a
				var corner_alpha := pixels.get_pixel(0, 0).a * plate.modulate.a
				if center_alpha < 0.85 or corner_alpha > 0.08 or texture.fill_from != Vector2(0.5, 0.5):
					push_error("FAN-3968 cast pose off centre: %s center=%.3f corner=%.3f" % [spec["name"], center_alpha, corner_alpha])
					quit(1)
					return
				print("FAN-3968 cast pose %s/%d center=%.3f corner=%.3f" % [spec["name"], height, center_alpha, corner_alpha])
			if scene.has_method("advance"):
				scene.call("advance", float(spec["time"]))
			else:
				scene.call("step", float(spec["time"]))
			scene.scale = Vector2.ONE * 0.38
			for _frame in 3:
				await process_frame
				await RenderingServer.frame_post_draw
			var output := "res://evidence/FAN-3968/runtime_parts/%s_%d.png" % [spec["name"], height]
			var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(output))
			if error != OK:
				push_error("FAN-3968 runtime capture failed: %s" % error_string(error))
				quit(1)
				return
			scene.call("finish", "cancel")
			viewport.queue_free()
			await process_frame
	quit(0)
'''


def main() -> int:
    PARTS.mkdir(parents=True, exist_ok=True)
    temporary = EVIDENCE / ".runtime_capture.gd"
    temporary.write_text(SCRIPT)
    try:
        result = subprocess.run(
            ["python3", "tools/godot_gate.py", "--path", ".", "--windowed",
             "--fixed-fps", "60", "--script", "res://evidence/FAN-3968/.runtime_capture.gd"],
            cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, check=False,
        )
        (EVIDENCE / "runtime_capture.log").write_text(result.stdout)
        if result.returncode:
            print("\n".join(result.stdout.splitlines()[-30:]))
            return result.returncode
        for height in HEIGHTS:
            width = height * 16 // 9
            panel_width, panel_height = width // 4, height // 2
            sheet = Image.new("RGB", (width, height), (16, 16, 23))
            draw = ImageDraw.Draw(sheet)
            for index, name in enumerate(CASES):
                source = PARTS / f"{name}_{height}.png"
                with Image.open(source) as part:
                    if part.size != (panel_width, panel_height):
                        raise RuntimeError(f"Wrong panel size: {source}: {part.size}")
                    sheet.paste(part.convert("RGB"), ((index % 4) * panel_width, (index // 4) * panel_height))
                x, y = (index % 4) * panel_width, (index // 4) * panel_height
                draw.text((x + 8, y + 8), name.replace("_", " ").upper(), fill=(235, 230, 238))
                source.unlink()
            target = EVIDENCE / f"runtime_{height}.png"
            sheet.save(target)
            print(target.relative_to(ROOT), sheet.size)
        PARTS.rmdir()
        return 0
    finally:
        temporary.unlink(missing_ok=True)
        temporary.with_suffix(".gd.uid").unlink(missing_ok=True)


if __name__ == "__main__":
    raise SystemExit(main())
