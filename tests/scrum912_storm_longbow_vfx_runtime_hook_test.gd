extends SceneTree

# SCRUM-1037 focused integration gate. It verifies one Animator release scene
# per live volley, live aim/range, unchanged data geometry, natural one-shot
# cleanup and the existing weapon cleanup path.

const ClassWeapon := preload("res://scripts/class_weapon.gd")
const ProgressionData := preload("res://scripts/progression_data.gd")
const EFFECT_ID := "storm_longbow_piercing_release"


class MockOwner extends CharacterBody2D:
	var character_id := "ranger"
	var derived_parameters := {
		"damage": 40.0,
		"magic_damage": 0.0,
		"crit_chance": 0.0,
		"crit_damage_multiplier": 1.0,
	}
	var run_modifiers := {}
	var stats := {}

	func class_trait_value(key: String, default_value := 0.0) -> float:
		return float((ProgressionData.CLASS_TRAITS.get(character_id, {}) as Dictionary).get(key, default_value))


func _initialize() -> void:
	var errors := PackedStringArray()
	var holder := Node2D.new()
	holder.name = "StormLongbowRuntimeHookFixture"
	root.add_child(holder)
	current_scene = holder

	var owner := MockOwner.new()
	holder.add_child(owner)
	owner.global_position = Vector2(420.0, 360.0)
	var weapon := ClassWeapon.new()
	owner.add_child(weapon)
	var config: Dictionary = ProgressionData.weapon("ranger", "storm_longbow")
	weapon.configure_weapon(config)
	weapon.set_process(false)
	weapon.set("_cooldown", 1.0e9)
	await process_frame

	var original_geometry := {
		"beam_count": weapon.beam_count,
		"cone_degrees": weapon.cone_degrees,
		"beam_width": weapon.beam_width,
		"attack_range": weapon.attack_range,
		"pierce_count": weapon.pierce_count,
		"pierce_damage_falloff": weapon.pierce_damage_falloff,
	}
	var aim := Vector2(0.6, 0.8).normalized()
	weapon.call("_fire_storm_pierce_cone", owner, aim)
	await process_frame
	var releases := _release_effects(weapon)
	if releases.size() != 1:
		errors.append("first volley created %d release scenes, expected exactly one" % releases.size())
	else:
		_assert_release(releases[0] as Node2D, weapon, owner, aim, errors)
	_assert_geometry_unchanged(weapon, original_geometry, errors)

	# A second live volley creates exactly one additional release, not one per
	# beam corridor and not a shared singleton.
	weapon.call("_fire_storm_pierce_cone", owner, Vector2.LEFT)
	await process_frame
	releases = _release_effects(weapon)
	if releases.size() != 2:
		errors.append("two volleys left %d live releases, expected two (one each)" % releases.size())

	# Animator scene is 8 frames / 16 FPS = 0.5s and self-cleans.
	await create_timer(0.65).timeout
	await process_frame
	if not _release_effects(weapon).is_empty():
		errors.append("release scene did not self-clean after its 0.5s one-shot")

	# Normal world/weapon cleanup must also retire a currently playing release.
	weapon.call("_fire_storm_pierce_cone", owner, Vector2.DOWN)
	await process_frame
	var cleanup_release := _release_effects(weapon)
	if cleanup_release.size() != 1:
		errors.append("cleanup fixture did not create exactly one live release")
	weapon.cleanup_effects()
	await process_frame
	if not _release_effects(weapon).is_empty():
		errors.append("weapon cleanup left the release scene alive/tracked")

	holder.queue_free()
	current_scene = null
	await process_frame
	await process_frame
	if not errors.is_empty():
		for error in errors:
			push_error("SCRUM-1037: %s" % error)
		quit(1)
		return
	print("SCRUM-1037 Storm Longbow runtime hook passed one-per-volley, aim/range, unchanged geometry and both cleanup paths.")
	quit(0)


func _release_effects(weapon: Node) -> Array:
	var releases := []
	for effect_raw in weapon.call("_alive_effects"):
		var effect := effect_raw as Node
		if effect != null and str(effect.get_meta("effect_id", "")) == EFFECT_ID:
			releases.append(effect)
	return releases


func _assert_release(effect: Node2D, weapon: Node, owner: Node2D, aim: Vector2, errors: PackedStringArray) -> void:
	var expected_position := owner.global_position + aim * 26.0
	if effect.global_position.distance_to(expected_position) > 0.01:
		errors.append("release origin %s != live origin %s" % [str(effect.global_position), str(expected_position)])
	if absf(wrapf(effect.rotation - aim.angle(), -PI, PI)) > 0.001:
		errors.append("release rotation %.4f != live aim %.4f" % [effect.rotation, aim.angle()])
	var contract := effect.call("geometry_contract") as Dictionary
	if float(contract.get("bow_silhouette_scale", 1.0)) > 0.50:
		errors.append("bow silhouette was not reduced by at least 2x")
	var expected_scale := (float(weapon.attack_range) - 26.0) / (float(contract.get("display_endpoint_x_px", 0.0)) - 26.0)
	if not is_equal_approx(effect.scale.x, expected_scale) or not is_equal_approx(effect.scale.y, expected_scale):
		errors.append("release scale %s != live range scale %.4f" % [str(effect.scale), expected_scale])
	if not effect.is_in_group("player_weapon_effects"):
		errors.append("release is missing player_weapon_effects cleanup group")
	if int(effect.get_meta("weapon_owner_id", 0)) != weapon.get_instance_id():
		errors.append("release is not registered to the firing weapon")


func _assert_geometry_unchanged(weapon: Node, before: Dictionary, errors: PackedStringArray) -> void:
	for property_name in before:
		var current = weapon.get(property_name)
		if current != before[property_name]:
			errors.append("gameplay geometry %s changed from %s to %s" % [property_name, str(before[property_name]), str(current)])
