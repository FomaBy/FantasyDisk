extends SceneTree

const ProgressionData := preload("res://scripts/progression_data.gd")
const ProjectileVisuals := preload("res://scripts/projectile_visual_registry.gd")
const AttackVfx := preload("res://scripts/attack_vfx.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array[String] = []
	ProjectileVisuals.reset_cache_for_tests()
	errors.append_array(ProjectileVisuals.validation_errors())
	var source_manifest = JSON.parse_string(FileAccess.get_file_as_string(ProjectileVisuals.SOURCE_MANIFEST_PATH))
	var runtime_manifest = JSON.parse_string(FileAccess.get_file_as_string(ProjectileVisuals.MANIFEST_PATH))
	if not source_manifest is Dictionary or not runtime_manifest is Dictionary:
		errors.append("source/runtime projectile manifests must both parse")
	else:
		if (source_manifest as Dictionary).get("contract", {}) != (runtime_manifest as Dictionary).get("contract", {}):
			errors.append("runtime contract drifted from SCRUM-1065 source manifest")
		if ((source_manifest as Dictionary).get("inventory", []) as Array).size() != ((runtime_manifest as Dictionary).get("inventory", []) as Array).size():
			errors.append("runtime inventory count drifted from SCRUM-1065 source manifest")
		var source_assets := {}
		for raw in (source_manifest as Dictionary).get("assets", []):
			source_assets[str((raw as Dictionary).get("visual_id", ""))] = raw
		for raw in (runtime_manifest as Dictionary).get("assets", []):
			var runtime_asset: Dictionary = raw
			var visual_id := str(runtime_asset.get("visual_id", ""))
			var source_asset: Dictionary = source_assets.get(visual_id, {})
			for key in ["weapon_id", "runtime_path", "forward_orientation", "rotation_offset_degrees", "intended_runtime_display_px", "trail_palette", "impact_palette", "animation_frames"]:
				if runtime_asset.get(key) != source_asset.get(key):
					errors.append("runtime profile %s field %s drifted from source" % [visual_id, key])
	var character_ids := ProgressionData.character_ids()
	var weapon_ids: Array = []
	for character_id in character_ids:
		weapon_ids.append_array(ProgressionData.weapon_ids(str(character_id)))
	if character_ids.size() != 17:
		errors.append("character inventory %d != 17" % character_ids.size())
	if weapon_ids.size() != 51:
		errors.append("weapon inventory %d != 51" % weapon_ids.size())
	var projectile_count := 0
	var non_projectile_count := 0
	var seen_visuals := {}
	for weapon_id_raw in weapon_ids:
		var weapon_id := str(weapon_id_raw)
		var entry := ProjectileVisuals.inventory_entry(weapon_id)
		if entry.is_empty():
			errors.append("missing inventory entry for %s" % weapon_id)
			continue
		var classification := str(entry.get("classification", ""))
		var profile := ProjectileVisuals.profile_for_weapon(weapon_id)
		if ProjectileVisuals.PROJECTILE_CLASSIFICATIONS.has(classification):
			projectile_count += 1
			if not ProjectileVisuals.is_valid_profile(profile):
				errors.append("invalid projectile profile for %s" % weapon_id)
				continue
			var path := str(profile.get("asset_path", ""))
			if ProjectileVisuals.FORBIDDEN_CANONICAL_FALLBACKS.has(path):
				errors.append("canonical %s uses forbidden fallback %s" % [weapon_id, path])
			var visual_id := str(profile.get("visual_id", ""))
			if seen_visuals.has(visual_id):
				errors.append("undocumented duplicate visual id %s" % visual_id)
			seen_visuals[visual_id] = weapon_id
			var weapon := ClassWeapon.new()
			weapon.configure_weapon(ProgressionData.weapon(str(entry.get("character_id", "")), weapon_id))
			var routed: Dictionary = weapon.call("_projectile_visual_profile")
			if str(routed.get("visual_id", "")) != visual_id:
				errors.append("ClassWeapon route mismatch for %s" % weapon_id)
			weapon.free()
		else:
			non_projectile_count += 1
			if not profile.is_empty():
				errors.append("non-projectile %s resolved a flying profile" % weapon_id)
	if projectile_count != 20 or non_projectile_count != 31:
		errors.append("inventory split %d/%d != 20/31" % [projectile_count, non_projectile_count])
	if ProjectileVisuals.projectile_weapon_ids().size() != 20:
		errors.append("registry does not expose 20 projectile weapons")

	var host := Node2D.new()
	root.add_child(host)
	for weapon_id in ProjectileVisuals.projectile_weapon_ids():
		var profile := ProjectileVisuals.profile_for_weapon(weapon_id)
		var shot := AttackVfx.orb_projectile(host, Vector2.ZERO, Color.WHITE, profile, Vector2.RIGHT)
		if str(shot.get_meta("projectile_visual_id", "")) != str(profile.get("visual_id", "")):
			errors.append("runtime metadata mismatch for %s" % weapon_id)
		var sprite := shot.get_child(0) as Sprite2D
		if sprite == null or sprite.texture == null or sprite.texture.resource_path != str(profile.get("asset_path", "")):
			errors.append("runtime texture mismatch for %s" % weapon_id)
		shot.queue_free()
	await process_frame
	var cleanup_profile := ProjectileVisuals.profile_for_weapon("soldier_rifle")
	AttackVfx.projectile_trace(host, Vector2.ZERO, Vector2(120.0, 0.0), Color.WHITE, cleanup_profile, 0.05)
	await create_timer(0.45).timeout
	if host.get_child_count() != 0:
		errors.append("projectile visual cleanup left %d orphan node(s)" % host.get_child_count())
	host.queue_free()
	if not ProjectileVisuals.profile_for_weapon("missing_dev_weapon").is_empty():
		errors.append("missing weapon did not fail safe to empty profile")

	if errors.is_empty():
		print("SCRUM-1066 projectile visual registry test passed (17/51, 20 mapped, 31 intentional non-projectile, runtime assets/fail-safe).")
		quit(0)
	else:
		for error in errors:
			push_error(error)
		quit(1)
