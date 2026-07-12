extends SceneTree

const MANIFEST_PATH := "res://docs/design/references/weapon_attack_animations/robot_hydraulic_press/compression_animation_manifest.json"
const REPORT_PATH := "res://docs/design/references/weapon_attack_animations/robot_hydraulic_press/compression_animation_report.json"
const FRAMES_PATH := "res://assets/sprites/effects/robot_hydraulic_press_compression/robot_hydraulic_press_compression_spriteframes.tres"
const VFX_SCENE_PATH := "res://scenes/vfx/RobotHydraulicPressCompressionVfx.tscn"
const WEAPON_SCENE_PATH := "res://scenes/RobotHydraulicPress.tscn"
const EXPECTED_OBJECT_ID := "99b9c7ec-23d3-4110-a22a-912cf8b455b8"
const EXPECTED_GROUP_ID := "659bdae5-22a9-4319-a3ca-57b972e5a9a3"
const EXPECTED_FRAME_COUNT := 8
const EXPECTED_FPS := 25.0
const EXPECTED_ACTIVE_FRAME := 5
const EXPECTED_ACTIVE_DELAY := 0.20


class MockOwner extends CharacterBody2D:
	var character_id := "robot"
	var derived_parameters := {
		"damage": 100.0,
		"magic_damage": 40.0,
		"crit_chance": 0.0,
		"crit_damage_multiplier": 1.0,
	}
	var run_modifiers := {}
	var stats := {}


func _initialize() -> void:
	await process_frame
	var manifest := _load_json(MANIFEST_PATH)
	var report := _load_json(REPORT_PATH)
	if manifest.is_empty() or report.is_empty():
		return
	if not _test_manifest(manifest, report):
		return
	if not _test_runtime_frames(report):
		return
	if not await _test_visual_scene_geometry_and_timing():
		return
	if not await _test_weapon_scene_integration():
		return
	print("SCRUM-917 Robot Hydraulic Press compression VFX smoke passed.")
	quit(0)


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_fail("Missing SCRUM-917 evidence: %s" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		_fail("SCRUM-917 JSON must parse as a Dictionary: %s" % path)
		return {}
	return parsed as Dictionary


func _test_manifest(manifest: Dictionary, report: Dictionary) -> bool:
	if str(manifest.get("issue", "")) != "SCRUM-917":
		return _fail("Manifest issue must be SCRUM-917.")
	if str(manifest.get("weapon_id", "")) != "robot_hydraulic_press":
		return _fail("Manifest weapon_id must be robot_hydraulic_press.")
	if not bool(manifest.get("pixel_lab_only", false)) or bool(manifest.get("openai_images_used", true)):
		return _fail("SCRUM-917 must record PixelLab-only production.")
	var pixel_lab := manifest.get("pixel_lab", {}) as Dictionary
	if str(pixel_lab.get("source_object_id", "")) != EXPECTED_OBJECT_ID:
		return _fail("Manifest must record the selected PixelLab object.")
	if str(pixel_lab.get("animation_group_id", "")) != EXPECTED_GROUP_ID:
		return _fail("Manifest must record the PixelLab animation group.")
	if not bool(pixel_lab.get("config_smoke_passed", false)):
		return _fail("Manifest must record the PixelLab MCP config smoke PASS.")
	var animation := manifest.get("animation", {}) as Dictionary
	if int(animation.get("active_crush_frame", -1)) != EXPECTED_ACTIVE_FRAME:
		return _fail("Active crush must use frame 5.")
	if not is_equal_approx(float(animation.get("active_crush_time_seconds", -1.0)), EXPECTED_ACTIVE_DELAY):
		return _fail("Active crush frame must land at 0.20s.")
	var geometry := manifest.get("geometry", {}) as Dictionary
	if int(geometry.get("length_px", 0)) != 430:
		return _fail("Manifest corridor length must be 430px.")
	if int(geometry.get("full_width_px", 0)) != 300 or int(geometry.get("calibrator_full_width_px", 0)) != 390:
		return _fail("Manifest must record both 300px and 390px live widths.")
	if int(geometry.get("centre_beam_width_px", 0)) != 120:
		return _fail("Manifest centre width must stay 120px.")
	if bool((manifest.get("runtime", {}) as Dictionary).get("gameplay_changed", true)):
		return _fail("Animator manifest must record that gameplay stayed unchanged.")
	if str(report.get("decision", "")) != "pass":
		return _fail("Static alpha/gutter report must pass.")
	return true


func _test_runtime_frames(report: Dictionary) -> bool:
	if not ResourceLoader.exists(FRAMES_PATH):
		return _fail("Missing SCRUM-917 SpriteFrames resource.")
	var frames := load(FRAMES_PATH) as SpriteFrames
	if frames == null or not frames.has_animation(&"compress"):
		return _fail("SCRUM-917 SpriteFrames must expose compress.")
	if frames.get_frame_count(&"compress") != EXPECTED_FRAME_COUNT:
		return _fail("Compression animation must have exactly 8 frames.")
	if not is_equal_approx(frames.get_animation_speed(&"compress"), EXPECTED_FPS):
		return _fail("Compression animation must play at 25fps.")
	if frames.get_animation_loop(&"compress"):
		return _fail("Compression animation must be one-shot.")
	var cyan_counts: Array[int] = []
	for index in range(EXPECTED_FRAME_COUNT):
		var texture := frames.get_frame_texture(&"compress", index)
		if texture == null or texture.get_size() != Vector2(256, 256):
			return _fail("Runtime frame %d must be a 256x256 texture." % index)
		var image := Image.new()
		var path := "res://assets/sprites/effects/robot_hydraulic_press_compression/robot_hydraulic_press_compress_%02d.png" % index
		if image.load(ProjectSettings.globalize_path(path)) != OK:
			return _fail("Cannot load runtime frame %d." % index)
		var bbox := _visible_bbox(image)
		if bbox.size == Vector2i.ZERO:
			return _fail("Runtime frame %d is empty." % index)
		var gutters := [bbox.position.x, bbox.position.y,
			image.get_width() - bbox.end.x, image.get_height() - bbox.end.y]
		for gutter in gutters:
			if int(gutter) < 16:
				return _fail("Runtime frame %d needs >=16px gutter; got %s." % [index, str(gutters)])
		for point in [Vector2i.ZERO, Vector2i(255, 0), Vector2i(0, 255), Vector2i(255, 255)]:
			if image.get_pixelv(point).a > 0.001:
				return _fail("Runtime frame %d has a non-transparent corner." % index)
		cyan_counts.append(_cyan_pressure_pixels(image))
	# Image-derived pressure oracle: the authored active frame must contain a
	# materially stronger teal crush burst than anticipation and release.
	if cyan_counts[EXPECTED_ACTIVE_FRAME] <= int(float(cyan_counts[1]) * 1.40):
		return _fail("Active crush frame does not intensify pressure over anticipation: %s" % str(cyan_counts))
	if cyan_counts[EXPECTED_ACTIVE_FRAME] <= int(float(cyan_counts[7]) * 1.40):
		return _fail("Active crush frame does not read stronger than release: %s" % str(cyan_counts))
	var rows := report.get("frames", []) as Array
	if rows.size() != EXPECTED_FRAME_COUNT:
		return _fail("Alpha/gutter report must contain all 8 frames.")
	return true


func _visible_bbox(image: Image) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= (8.0 / 255.0):
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _cyan_pressure_pixels(image: Image) -> int:
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.a > (20.0 / 255.0) and color.g > (150.0 / 255.0) and color.b > (135.0 / 255.0) and color.g > color.r * 1.25:
				count += 1
	return count


func _test_visual_scene_geometry_and_timing() -> bool:
	var packed := load(VFX_SCENE_PATH) as PackedScene
	if packed == null:
		return _fail("Missing isolated SCRUM-917 VFX scene.")
	var effect := packed.instantiate() as Node2D
	root.add_child(effect)
	await process_frame
	effect.set("auto_free_on_finish", false)
	effect.call("configure", Vector2(100, 200), Vector2(530, 200), 300.0, 120.0, 0.20, Color(0.94, 0.72, 0.36, 0.42))
	var contract := effect.call("geometry_contract") as Dictionary
	if effect.name != "RobotHydraulicPressCompressionVfx" or str(contract.get("effect_id", "")).contains("beam"):
		return _fail("Press VFX must be a distinct compression effect, not a beam helper.")
	if effect.global_position.distance_to(Vector2(315, 200)) > 0.01:
		return _fail("Press VFX pivot must stay at the corridor centre.")
	if not is_equal_approx(float(contract.get("corridor_length_px", 0.0)), 430.0):
		return _fail("Runtime visual length must match live 430px.")
	if not is_equal_approx(float(contract.get("corridor_width_px", 0.0)), 300.0):
		return _fail("Runtime visual width must match live 300px.")
	var sprite := effect.get_node("AnimatedSprite2D") as AnimatedSprite2D
	if not is_equal_approx(sprite.rotation, PI * 0.5):
		return _fail("PixelLab jaws must rotate 90 degrees onto the perpendicular compression axis.")
	if sprite.scale.distance_to(Vector2(300.0 / 256.0, 430.0 / 256.0)) > 0.001:
		return _fail("PixelLab source scale must exactly map to 430x300 geometry.")
	var upper := effect.get_node("UpperJaw") as Line2D
	var lower := effect.get_node("LowerJaw") as Line2D
	if not is_equal_approx(upper.position.y, -150.0) or not is_equal_approx(lower.position.y, 150.0):
		return _fail("Force jaws must start on opposite full-width corridor edges.")
	await create_timer(0.22).timeout
	if not bool(effect.get_meta("active_frame_reached", false)) or sprite.frame < EXPECTED_ACTIVE_FRAME:
		return _fail("PixelLab active crush frame did not reach the 0.20s hit marker.")
	if absf(upper.position.y + 60.0) > 3.0 or absf(lower.position.y - 60.0) > 3.0:
		return _fail("Force jaws did not converge side-to-centre by hit time.")
	# Calibrator must widen only the visual corridor width while preserving length.
	var calibrated := packed.instantiate() as Node2D
	root.add_child(calibrated)
	await process_frame
	calibrated.set("auto_free_on_finish", false)
	calibrated.call("configure", Vector2(100, 500), Vector2(530, 500), 390.0, 120.0, 0.20, Color(0.94, 0.72, 0.36, 0.42))
	var calibrated_contract := calibrated.call("geometry_contract") as Dictionary
	if not is_equal_approx(float(calibrated_contract.get("corridor_width_px", 0.0)), 390.0):
		return _fail("Press Calibrator visual must expand to the live 390px width.")
	var calibrated_sprite := calibrated.get_node("AnimatedSprite2D") as AnimatedSprite2D
	if calibrated_sprite.scale.distance_to(Vector2(390.0 / 256.0, 430.0 / 256.0)) > 0.001:
		return _fail("Calibrator visual scaling must preserve 430px length and use 390px width.")
	effect.queue_free()
	calibrated.queue_free()
	await process_frame
	return true


func _test_weapon_scene_integration() -> bool:
	var packed := load(WEAPON_SCENE_PATH) as PackedScene
	if packed == null:
		return _fail("Missing RobotHydraulicPress weapon scene.")
	var holder := Node2D.new()
	holder.name = "Scrum917WeaponIntegration"
	root.add_child(holder)
	current_scene = holder
	var owner := MockOwner.new()
	holder.add_child(owner)
	owner.global_position = Vector2(400, 360)
	var weapon := packed.instantiate() as Node2D
	owner.add_child(weapon)
	weapon.set_process(false)
	await process_frame
	if weapon.get_script() == null or weapon.get_script().resource_path != "res://scripts/robot_hydraulic_press_weapon.gd":
		return _fail("Only RobotHydraulicPress must use the isolated visual bridge.")
	weapon.call("_fire_robot_compression_line", owner, null, Vector2.RIGHT)
	await process_frame
	var effect: Node2D = null
	for node in get_nodes_in_group("player_weapon_effects"):
		if is_instance_valid(node) and str(node.get_meta("effect_id", "")) == "robot_hydraulic_press_side_to_center_crush":
			effect = node as Node2D
			break
	if effect == null:
		return _fail("RobotHydraulicPress runtime attack did not spawn the SCRUM-917 VFX.")
	var contract := effect.call("geometry_contract") as Dictionary
	if not is_equal_approx(float(contract.get("corridor_length_px", 0.0)), 430.0):
		return _fail("Runtime visual segment must cover the full 430px damage/control range from start +28.")
	if not is_equal_approx(float(contract.get("corridor_width_px", 0.0)), 300.0):
		return _fail("Runtime weapon integration must use full suppression_width 300.")
	# Distinctness guard: sibling Robot scenes keep ClassWeapon and cannot spawn
	# the Press-only effect through a scene-specific subclass.
	for sibling_path in ["res://scenes/RobotMagneticAnchor.tscn", "res://scenes/RobotReactorCore.tscn"]:
		var sibling := (load(sibling_path) as PackedScene).instantiate() as Node2D
		if sibling.get_script() != null and sibling.get_script().resource_path == "res://scripts/robot_hydraulic_press_weapon.gd":
			return _fail("SCRUM-917 visual bridge leaked into %s." % sibling_path)
		sibling.queue_free()
	holder.queue_free()
	current_scene = null
	await process_frame
	await process_frame
	return true
