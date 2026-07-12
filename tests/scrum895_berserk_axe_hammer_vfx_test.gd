extends SceneTree

const MANIFEST_PATH := "res://docs/design/references/scrum895_berserk_axe_hammer_vfx/manifest.json"
const REPORT_PATH := "res://docs/design/references/scrum895_berserk_axe_hammer_vfx/frame_qa_report.json"
const AXE_FRAMES := "res://assets/sprites/effects/scrum895_berserk/axe_cleave_spriteframes.tres"
const HAMMER_FRAMES := "res://assets/sprites/effects/scrum895_berserk/hammer_slam_spriteframes.tres"
const AXE_VFX := "res://scenes/vfx/BerserkAxeCleaveVfx.tscn"
const HAMMER_VFX := "res://scenes/vfx/BerserkHammerSlamVfx.tscn"
const AXE_SCENE := "res://scenes/TwoHandedAxe.tscn"
const HAMMER_SCENE := "res://scenes/TwoHandedHammer.tscn"
const SWORD_SCENE := "res://scenes/TwoHandedSword.tscn"
const FRAME_COUNT := 8


class MockOwner extends CharacterBody2D:
	var character_id := "berserk"
	var derived_parameters := {"damage": 100.0, "crit_chance": 0.0, "crit_damage_multiplier": 1.0}
	var run_modifiers := {}
	var stats := {}


func _initialize() -> void:
	await process_frame
	var manifest := _load_json(MANIFEST_PATH)
	var report := _load_json(REPORT_PATH)
	if manifest.is_empty() or report.is_empty(): return
	if not _test_manifest(manifest, report): return
	if not _test_frames(report): return
	if not await _test_isolated_vfx(): return
	if not await _test_scene_bridges_and_sword_guard(): return
	print("SCRUM-895 Berserk Axe/Hammer VFX smoke passed.")
	quit(0)


func _fail(message: String) -> bool:
	push_error(message); quit(1); return false


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): _fail("Missing SCRUM-895 evidence: %s" % path); return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary: _fail("Invalid SCRUM-895 JSON: %s" % path); return {}
	return parsed as Dictionary


func _test_manifest(manifest: Dictionary, report: Dictionary) -> bool:
	if str(manifest.get("issue", "")) != "SCRUM-895": return _fail("Manifest issue must be SCRUM-895.")
	if not bool(manifest.get("pixel_lab_only", false)) or bool(manifest.get("openai_images_used", true)):
		return _fail("SCRUM-895 must record PixelLab-only generated sources.")
	if not bool(manifest.get("pixel_lab_config_smoke_passed", false)): return _fail("PixelLab config smoke PASS missing.")
	var packs := manifest.get("packs", {}) as Dictionary
	if str((packs.get("axe", {}) as Dictionary).get("object_id", "")) != "d5452069-7d6e-4646-8b9d-379f0c332f17": return _fail("Axe PixelLab id mismatch.")
	if str((packs.get("hammer", {}) as Dictionary).get("object_id", "")) != "b1fed1f3-71b6-47d5-a1eb-e3e4b8db65b5": return _fail("Hammer PixelLab id mismatch.")
	var contract := manifest.get("mechanical_contract", {}) as Dictionary
	if bool(contract.get("sword_changed", true)): return _fail("Animator manifest must record Sword unchanged.")
	var runtime := manifest.get("runtime", {}) as Dictionary
	for key in ["shared_berserk_weapon_changed", "shared_attack_vfx_changed", "shared_progression_data_changed"]:
		if bool(runtime.get(key, true)): return _fail("Animator must not change shared backend path: %s" % key)
	if str(report.get("decision", "")) != "pass": return _fail("Frame QA report must pass.")
	return true


func _test_frames(report: Dictionary) -> bool:
	var resources := {"axe": [AXE_FRAMES, &"cleave"], "hammer": [HAMMER_FRAMES, &"slam"]}
	var report_packs := report.get("packs", {}) as Dictionary
	for name in resources:
		var entry: Array = resources[name]
		var frames := load(str(entry[0])) as SpriteFrames
		var animation: StringName = entry[1]
		if frames == null or not frames.has_animation(animation): return _fail("Missing %s SpriteFrames animation." % name)
		if frames.get_frame_count(animation) != FRAME_COUNT or frames.get_animation_loop(animation): return _fail("%s must expose 8 one-shot frames." % name)
		var rows := ((report_packs.get(name, {}) as Dictionary).get("frames", [])) as Array
		if rows.size() != FRAME_COUNT: return _fail("%s QA report must contain 8 frames." % name)
		for index in range(FRAME_COUNT):
			var texture := frames.get_frame_texture(animation, index)
			if texture == null or texture.get_size() != Vector2(256, 256): return _fail("%s frame %d must be 256x256." % [name, index])
			var metrics := (rows[index] as Dictionary).get("runtime_metrics", {}) as Dictionary
			if int(metrics.get("minimum_gutter_px", 0)) < 16 or int(metrics.get("edge_visible_pixels", -1)) != 0: return _fail("%s frame %d failed gutter/edge contract." % [name, index])
			if int(metrics.get("max_alpha", 255)) > 205: return _fail("%s frame %d exceeds alpha cap." % [name, index])
	return true


func _test_isolated_vfx() -> bool:
	var axe := (load(AXE_VFX) as PackedScene).instantiate() as BerserkAxeCleaveVfx
	root.add_child(axe); await process_frame
	axe.configure(Vector2(400, 300), Vector2.RIGHT, 250.0, 180.0, 0.20, Color(1.0, 0.58, 0.24, 0.34))
	var axe_contract := axe.geometry_contract()
	if not is_equal_approx(float(axe_contract.get("radius_px", 0.0)), 250.0): return _fail("Axe VFX radius must mirror 250px gameplay.")
	if not is_equal_approx(float(axe_contract.get("sweep_degrees", 0.0)), 180.0): return _fail("Axe VFX arc must mirror 180 degrees.")
	if not bool(axe_contract.get("weapon_ghost_present", false)): return _fail("Axe cleave must contain an actual weapon ghost.")
	var axe_sprite := axe.get_node("WeaponPivot/AxeGhost") as AnimatedSprite2D
	if axe_sprite.sprite_frames.get_frame_count(&"cleave") != FRAME_COUNT: return _fail("Axe runtime ghost must use PixelLab motion frames.")

	var hammer := (load(HAMMER_VFX) as PackedScene).instantiate() as BerserkHammerSlamVfx
	root.add_child(hammer); await process_frame
	hammer.configure(Vector2(800, 300), 150.0, Vector2(1.0, 1.15), Color(0.82, 0.72, 1.0, 0.32))
	var hammer_contract := hammer.geometry_contract()
	if not is_equal_approx(float(hammer_contract.get("radius_px", 0.0)), 150.0): return _fail("Hammer VFX radius must mirror 150px gameplay.")
	var contract_scale: Vector2 = hammer_contract.get("visual_scale", Vector2.ZERO)
	if contract_scale.distance_to(Vector2(1.0, 1.15)) > 0.001: return _fail("Hammer VFX must honor backend visual-scale handoff.")
	if int(hammer_contract.get("impact_frame", -1)) != 5: return _fail("Hammer impact must use authored PixelLab frame 5.")
	var hammer_sprite := hammer.get_node("HammerGhost") as AnimatedSprite2D
	if hammer_sprite.frame != 5 or not bool(hammer_contract.get("weapon_ghost_present", false)): return _fail("Hammer impact must visibly contain the frame-5 weapon ghost.")
	axe.queue_free(); hammer.queue_free(); await process_frame
	return true


func _test_scene_bridges_and_sword_guard() -> bool:
	var holder := Node2D.new(); root.add_child(holder); current_scene = holder
	var owner := MockOwner.new(); holder.add_child(owner); owner.global_position = Vector2(600, 400)
	var axe := (load(AXE_SCENE) as PackedScene).instantiate() as Node2D
	var hammer := (load(HAMMER_SCENE) as PackedScene).instantiate() as Node2D
	var sword := (load(SWORD_SCENE) as PackedScene).instantiate() as Node2D
	owner.add_child(axe); owner.add_child(hammer); owner.add_child(sword)
	axe.set_process(false); hammer.set_process(false); sword.set_process(false); await process_frame
	if axe.get_script().resource_path != "res://scripts/two_handed_axe_weapon.gd": return _fail("Axe scene must use isolated visual bridge.")
	if hammer.get_script().resource_path != "res://scripts/two_handed_hammer_weapon.gd": return _fail("Hammer scene must use isolated visual bridge.")
	if sword.get_script().resource_path != "res://scripts/berserk_weapon.gd": return _fail("Sword scene/script must remain unchanged.")
	var axe_data := ProgressionData.weapon("berserk", "axe")
	var hammer_data := ProgressionData.weapon("berserk", "hammer")
	var sword_data := ProgressionData.weapon("berserk", "sword")
	if float(axe_data.get("attack_range", 0.0)) != 250.0 or float(axe_data.get("sweep_degrees", 0.0)) != 180.0 or float(axe_data.get("fire_interval", 0.0)) != 1.06 or float(axe_data.get("damage_multiplier", 0.0)) != 0.85: return _fail("Axe gameplay values changed in Animator task.")
	if float(hammer_data.get("aoe_radius", 0.0)) != 150.0 or float(hammer_data.get("fire_interval", 0.0)) != 1.25 or float(hammer_data.get("damage_multiplier", 0.0)) != 0.55: return _fail("Hammer balance values changed in Animator task.")
	if float(sword_data.get("attack_range", 0.0)) != 350.0 or float(sword_data.get("sweep_degrees", 0.0)) != 100.0 or float(sword_data.get("fire_interval", 0.0)) != 0.58: return _fail("Sword reference behavior regressed.")
	axe.call("_show_sweep_area", owner, Vector2.RIGHT)
	hammer.call("_show_circle_area", owner)
	await process_frame
	var found_axe := false; var found_hammer := false
	for node in get_nodes_in_group("player_weapon_effects"):
		if not is_instance_valid(node): continue
		if str(node.get_meta("effect_id", "")) == "berserk_axe_pixel_lab_cleave": found_axe = true
		if str(node.get_meta("effect_id", "")) == "berserk_hammer_pixel_lab_slam": found_hammer = true
	if not found_axe or not found_hammer: return _fail("Runtime Axe/Hammer bridge failed to spawn dedicated weapon VFX.")
	holder.queue_free(); current_scene = null; await process_frame; await process_frame
	return true
