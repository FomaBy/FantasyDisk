extends SceneTree

const MANIFEST_PATH := "res://docs/design/references/scrum924_holy_flail_spiral_vfx/manifest.json"
const REPORT_PATH := "res://docs/design/references/scrum924_holy_flail_spiral_vfx/frame_qa_report.json"
const FRAMES_PATH := "res://assets/sprites/effects/holy_flail_spiral/holy_flail_spiral_spriteframes.tres"
const VFX_SCENE_PATH := "res://scenes/vfx/HolyFlailSpiralVfx.tscn"
const WEAPON_SCENE_PATH := "res://scenes/HolyFlail.tscn"
const EXPECTED_OBJECT_ID := "b1089fd9-a4c7-49ce-aec2-af62fb0317b6"
const EXPECTED_GROUP_ID := "50cb9b87-58b3-411e-af3e-caabce8b4cb4"
const EXPECTED_ANIMATION_ID := "0ff0ce1e-e95c-409a-b542-e50b606fd928"
const STEP_COUNT := 7
const FRAME_COUNT := 8
const STEP_TIME := 0.085
const FULL_RADIUS := 235.0
const START_RATIO := 0.22


class MockOwner extends CharacterBody2D:
	var character_id := "knight"
	var derived_parameters := {
		"damage": 100.0,
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
	if not _test_frames(report):
		return
	if not await _test_isolated_vfx_geometry():
		return
	if not await _test_weapon_bridge():
		return
	print("SCRUM-924 Holy Flail spiral VFX smoke passed.")
	quit(0)


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_fail("Missing SCRUM-924 evidence: %s" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		_fail("SCRUM-924 JSON must parse as a Dictionary: %s" % path)
		return {}
	return parsed as Dictionary


func _test_manifest(manifest: Dictionary, report: Dictionary) -> bool:
	if str(manifest.get("issue", "")) != "SCRUM-924" or str(manifest.get("weapon_id", "")) != "holy_flail":
		return _fail("Manifest must identify SCRUM-924 / holy_flail.")
	if not bool(manifest.get("pixel_lab_only", false)) or bool(manifest.get("openai_images_used", true)):
		return _fail("SCRUM-924 must record PixelLab-only production.")
	var pixel_lab := manifest.get("pixel_lab", {}) as Dictionary
	if str(pixel_lab.get("object_id", "")) != EXPECTED_OBJECT_ID:
		return _fail("Manifest must record the selected PixelLab object.")
	if str(pixel_lab.get("animation_group_id", "")) != EXPECTED_GROUP_ID:
		return _fail("Manifest must record the PixelLab animation group.")
	if str(pixel_lab.get("animation_id", "")) != EXPECTED_ANIMATION_ID:
		return _fail("Manifest must record the PixelLab animation id.")
	if not bool(pixel_lab.get("config_smoke_passed", false)):
		return _fail("Manifest must record PixelLab MCP config smoke PASS.")
	var contract := manifest.get("mechanical_contract", {}) as Dictionary
	if int(contract.get("spiral_steps", 0)) != STEP_COUNT:
		return _fail("Manifest must keep the live 7-step spiral.")
	if not is_equal_approx(float(contract.get("spiral_step_time", 0.0)), STEP_TIME):
		return _fail("Manifest must keep the live 0.085s step timing.")
	if not is_equal_approx(float(contract.get("spiral_start_radius_ratio", 0.0)), START_RATIO):
		return _fail("Manifest must keep the live 0.22 start radius.")
	if int(contract.get("aoe_radius", 0)) != int(FULL_RADIUS):
		return _fail("Manifest must keep the live 235px full radius.")
	if bool((manifest.get("runtime", {}) as Dictionary).get("gameplay_changed", true)):
		return _fail("Animator manifest must record that gameplay stayed unchanged.")
	if str(report.get("decision", "")) != "pass":
		return _fail("Frame QA report must pass.")
	return true


func _test_frames(report: Dictionary) -> bool:
	if not ResourceLoader.exists(FRAMES_PATH):
		return _fail("Missing SCRUM-924 SpriteFrames resource.")
	var frames := load(FRAMES_PATH) as SpriteFrames
	if frames == null or not frames.has_animation(&"spiral"):
		return _fail("SCRUM-924 SpriteFrames must expose spiral.")
	if frames.get_frame_count(&"spiral") != FRAME_COUNT:
		return _fail("PixelLab spiral animation must have exactly 8 frames.")
	if frames.get_animation_loop(&"spiral"):
		return _fail("Holy Flail spiral frames must be one-shot.")
	if not is_equal_approx(frames.get_animation_speed(&"spiral"), 1.0 / STEP_TIME):
		return _fail("SpriteFrames speed must mirror the live 0.085s step cadence.")
	var rows := report.get("frames", []) as Array
	if rows.size() != FRAME_COUNT:
		return _fail("Frame QA report must cover all 8 PixelLab frames.")
	for index in range(FRAME_COUNT):
		var texture := frames.get_frame_texture(&"spiral", index)
		if texture == null or texture.get_size() != Vector2(256, 256):
			return _fail("Runtime frame %d must be 256x256." % index)
		var metrics := (rows[index] as Dictionary).get("runtime_metrics", {}) as Dictionary
		if int(metrics.get("minimum_gutter_px", 0)) < 16:
			return _fail("Runtime frame %d lacks the required 16px gutter." % index)
		if int(metrics.get("edge_visible_pixels", -1)) != 0:
			return _fail("Runtime frame %d touches a canvas edge." % index)
		if int(metrics.get("max_alpha", 255)) > 190:
			return _fail("Runtime frame %d exceeds calm combat alpha 190." % index)
	return true


func _test_isolated_vfx_geometry() -> bool:
	var packed := load(VFX_SCENE_PATH) as PackedScene
	if packed == null:
		return _fail("Missing isolated SCRUM-924 VFX scene.")
	var effect := packed.instantiate() as HolyFlailSpiralVfx
	root.add_child(effect)
	await process_frame
	effect.auto_free_on_finish = false
	var previous_radius := 0.0
	var base_angle := 0.35
	for step_index in range(STEP_COUNT):
		var progress := float(step_index + 1) / float(STEP_COUNT)
		var arm_angle := base_angle + TAU * progress
		var radius := lerpf(FULL_RADIUS * START_RATIO, FULL_RADIUS, progress)
		effect.apply_step(Vector2(400, 300), arm_angle, radius, FULL_RADIUS, step_index, Color(1.0, 0.84, 0.32, 0.34))
		var contract := effect.geometry_contract()
		if str(contract.get("effect_id", "")).contains("ring") or str(contract.get("effect_id", "")).contains("beam"):
			return _fail("Holy Flail must use a distinct center-out spiral, not generic ring/beam VFX.")
		if float(contract.get("front_radius_px", 0.0)) <= previous_radius:
			return _fail("Spiral front radius must grow monotonically at step %d." % step_index)
		if int(contract.get("step_index", -1)) != step_index:
			return _fail("Spiral VFX step index drifted from damage step %d." % step_index)
		if int(contract.get("pixel_lab_frame_index", -1)) != step_index:
			return _fail("PixelLab frame must advance with each damage step.")
		if int(contract.get("chain_sample_count", 0)) < 24:
			return _fail("Spiral chain trail needs enough samples for a readable curl.")
		var front := effect.get_meta("front_point", Vector2.ZERO) as Vector2
		if absf(front.length() - radius) > 0.05:
			return _fail("Flail head/front must sit on the live damage radius.")
		previous_radius = radius
	var final_contract := effect.geometry_contract()
	if absf(float(final_contract.get("front_radius_px", 0.0)) - FULL_RADIUS) > 0.05:
		return _fail("Final spiral frame must close at the full 235px radius.")
	if absf(float(final_contract.get("base_angle", 0.0)) - base_angle) > 0.01:
		return _fail("Final spiral frame must complete one full turn back to the base angle.")
	effect.queue_free()
	await process_frame
	return true


func _test_weapon_bridge() -> bool:
	var packed := load(WEAPON_SCENE_PATH) as PackedScene
	if packed == null:
		return _fail("Missing HolyFlail weapon scene.")
	var holder := Node2D.new()
	holder.name = "Scrum924WeaponIntegration"
	root.add_child(holder)
	current_scene = holder
	var owner := MockOwner.new()
	holder.add_child(owner)
	owner.global_position = Vector2(400, 360)
	var weapon := packed.instantiate() as Node2D
	owner.add_child(weapon)
	weapon.set_process(false)
	await process_frame
	if weapon.get_script() == null or weapon.get_script().resource_path != "res://scripts/holy_flail_weapon.gd":
		return _fail("Only HolyFlail must use the isolated SCRUM-924 visual bridge.")
	var config := ProgressionData.weapon("knight", "holy_flail")
	if int(config.get("spiral_steps", 0)) != STEP_COUNT or not is_equal_approx(float(config.get("spiral_step_time", 0.0)), STEP_TIME):
		return _fail("SCRUM-924 must not change the accepted backend spiral timing.")
	if not is_equal_approx(float(config.get("aoe_radius", 0.0)), FULL_RADIUS):
		return _fail("SCRUM-924 must not change Holy Flail damage radius.")
	var first_progress := 1.0 / float(STEP_COUNT)
	var first_radius := lerpf(FULL_RADIUS * START_RATIO, FULL_RADIUS, first_progress)
	weapon.call("_show_spiral_step_area", owner, TAU * first_progress, first_radius)
	await process_frame
	var found: Node2D = null
	for node in get_nodes_in_group("player_weapon_effects"):
		if is_instance_valid(node) and str(node.get_meta("effect_id", "")) == "holy_flail_center_out_spiral":
			found = node as Node2D
			break
	if found == null:
		return _fail("HolyFlail runtime visual hook did not spawn SCRUM-924 VFX.")
	var contract := found.call("geometry_contract") as Dictionary
	if int(contract.get("step_index", -1)) != 0:
		return _fail("HolyFlail first visual frame must align with first damage step.")
	for sibling_path in ["res://scenes/LongSpear.tscn", "res://scenes/TowerShield.tscn"]:
		var sibling := (load(sibling_path) as PackedScene).instantiate() as Node2D
		if sibling.get_script() != null and sibling.get_script().resource_path == "res://scripts/holy_flail_weapon.gd":
			return _fail("SCRUM-924 visual bridge leaked into %s." % sibling_path)
		sibling.queue_free()
	holder.queue_free()
	current_scene = null
	await process_frame
	await process_frame
	return true
