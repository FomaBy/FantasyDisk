extends SceneTree

const ProjectileScene := preload("res://scenes/Projectile.tscn")
const ProjectileScript := preload("res://scripts/projectile.gd")
const ProjectileVisuals := preload("res://scripts/projectile_visual_registry.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array[String] = []
	var holder := Node2D.new()
	root.add_child(holder)

	var pre_tree := ProjectileScene.instantiate() as Area2D
	pre_tree.setup(Vector2.ZERO, Vector2(100.0, 0.0), 1.0, "thief_smoke_bomb")
	holder.add_child(pre_tree)
	await process_frame
	var pre_snapshot := _snapshot(pre_tree)
	_assert_profile(errors, "pre-tree thief", pre_tree, "thief_smoke_bomb")

	var post_tree := ProjectileScene.instantiate() as Area2D
	holder.add_child(post_tree)
	await process_frame
	_assert_profile(errors, "post-tree default", post_tree, "soldier_rifle")
	post_tree.setup(Vector2.ZERO, Vector2(100.0, 0.0), 1.0, "thief_smoke_bomb")
	var post_snapshot := _snapshot(post_tree)
	_assert_profile(errors, "post-tree thief", post_tree, "thief_smoke_bomb")
	if pre_snapshot != post_snapshot:
		errors.append("pre/post-tree thief snapshots differ: %s != %s" % [pre_snapshot, post_snapshot])

	# Empty override is backward compatible: it changes movement/damage only and
	# preserves the already selected visual profile.
	post_tree.setup(Vector2.ZERO, Vector2(0.0, 100.0), 2.0)
	if _snapshot(post_tree) != post_snapshot:
		errors.append("empty visual override changed the current profile")

	# A second, directional profile proves texture/scale/rotation/trail are all
	# reapplied rather than merely rewriting metadata.
	var ranger_pre := ProjectileScene.instantiate() as Area2D
	ranger_pre.setup(Vector2.ZERO, Vector2(100.0, 0.0), 1.0, "storm_longbow")
	holder.add_child(ranger_pre)
	await process_frame
	var ranger_snapshot := _snapshot(ranger_pre)
	post_tree.setup(Vector2.ZERO, Vector2(100.0, 0.0), 1.0, "storm_longbow")
	_assert_profile(errors, "post-tree ranger", post_tree, "storm_longbow")
	if _snapshot(post_tree) != ranger_snapshot:
		errors.append("pre/post-tree ranger snapshots differ")

	# Invalid IDs fail closed. Keeping the previous Ranger sprite while clearing
	# or changing only its ID would be a stale mismatched visual contract.
	post_tree.setup(Vector2.ZERO, Vector2(100.0, 0.0), 1.0, "missing_visual_profile")
	var invalid_visual := post_tree.get_node("Shape") as Sprite2D
	if post_tree.has_meta("projectile_visual_id") or post_tree.has_meta("projectile_asset_path"):
		errors.append("invalid profile retained stale canonical metadata")
	if invalid_visual.texture != null or invalid_visual.scale != Vector2.ONE or not is_zero_approx(invalid_visual.rotation):
		errors.append("invalid profile retained stale canonical sprite transform")
	var invalid_trail := post_tree.get("_trail") as Line2D
	if invalid_trail == null or not invalid_trail.default_color.is_equal_approx(ProjectileScript.DEFAULT_TRAIL_COLOR):
		errors.append("invalid profile did not restore the neutral trail palette")

	holder.queue_free()
	await process_frame
	if errors.is_empty():
		print("SCRUM-1085 projectile setup visual order test passed (pre/post-tree, two profiles, empty compatibility, invalid fail-safe).")
		quit(0)
	else:
		for error in errors:
			push_error(error)
		quit(1)


func _snapshot(projectile: Area2D) -> Dictionary:
	var visual := projectile.get_node("Shape") as Sprite2D
	var trail := projectile.get("_trail") as Line2D
	return {
		"visual_id": str(projectile.get_meta("projectile_visual_id", "")),
		"asset_path": str(projectile.get_meta("projectile_asset_path", "")),
		"texture_path": visual.texture.resource_path if visual.texture != null else "",
		"scale": visual.scale,
		"rotation": visual.rotation,
		"trail_color": trail.default_color if trail != null else Color.TRANSPARENT,
	}


func _assert_profile(errors: Array[String], label: String, projectile: Area2D, weapon_id: String) -> void:
	var profile := ProjectileVisuals.profile_for_weapon(weapon_id)
	var visual := projectile.get_node("Shape") as Sprite2D
	var trail := projectile.get("_trail") as Line2D
	if str(projectile.get_meta("projectile_visual_id", "")) != str(profile.get("visual_id", "")):
		errors.append("%s metadata visual_id mismatch" % label)
	if visual.texture == null or visual.texture.resource_path != str(profile.get("asset_path", "")):
		errors.append("%s texture mismatch" % label)
	var expected_size: Vector2 = profile.get("display_size", Vector2.ZERO)
	var texture_size := visual.texture.get_size() if visual.texture != null else Vector2.ONE
	var expected_scale := Vector2(expected_size.x / maxf(texture_size.x, 1.0), expected_size.y / maxf(texture_size.y, 1.0))
	if not visual.scale.is_equal_approx(expected_scale):
		errors.append("%s scale mismatch" % label)
	if not is_equal_approx(visual.rotation, deg_to_rad(float(profile.get("rotation_offset_degrees", 0.0)))):
		errors.append("%s rotation offset mismatch" % label)
	var palette = profile.get("trail_palette", [])
	var expected_trail := ProjectileScript.DEFAULT_TRAIL_COLOR
	if palette is Array and not palette.is_empty():
		var color: Color = palette[0]
		expected_trail = Color(color.r, color.g, color.b, 0.70)
	if trail == null or not trail.default_color.is_equal_approx(expected_trail):
		errors.append("%s trail palette mismatch" % label)
