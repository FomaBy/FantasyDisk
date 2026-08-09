extends SceneTree

const ProgressionData := preload("res://scripts/progression_data.gd")
const AttributeContract := preload("res://scripts/attribute_contract.gd")
const Meta := preload("res://scripts/meta_progression.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const REMOVED_KEYS := ["range_multiplier", "sector_multiplier", "projectile_speed_flat", "aura_radius_flat", "buff_power_flat"]
const RETIRED_CONE_CONFIGS := ["berserk/sword", "berserk/axe", "knight/long_spear", "knight/tower_shield"]
const LIVE_GEOMETRY_PROPERTIES := [
	"aoe_radius", "summon_aoe_radius", "beam_width", "wave_width",
	"suppression_width", "inner_width", "outer_width", "sweep_degrees", "cone_degrees",
]
const CANONICAL_DOC_FACTS := {
	"res://docs/design/content_registry.md": "retired range/projectile-speed/buff axes остаются только legacy assets",
	"res://docs/design/systems/characters_weapons.md": "единая область атаки масштабирует живую геометрию, но не target reach",
	"res://docs/design/current_game_state.md": "reach/projectile-speed остаются config-defined",
	"res://docs/design/mechanics_extract.md": "standalone `buff_power` источника нет",
}
const RETIRED_CURRENT_PROMISES := [
	"radius расширяет дальность",
	"radius расширяет reach",
	"sector_multiplier расширяет",
	"stat cross-scaling range/projectile speed",
	"range_multiplier scales attack_range",
	"buff_power scales support",
]


func _initialize() -> void:
	var errors: Array[String] = []
	var weapon_count := 0
	var holder := Node2D.new()
	root.add_child(holder)
	for character_id_value in ProgressionData.character_ids():
		var character_id := str(character_id_value)
		var stats: Dictionary = ProgressionData.base_stats(character_id)
		for weapon_id_value in ProgressionData.weapon_ids(character_id):
			var weapon_id := str(weapon_id_value)
			var label := "%s/%s" % [character_id, weapon_id]
			var config: Dictionary = ProgressionData.weapon(character_id, weapon_id)
			weapon_count += 1
			var dimensions: Array = config.get("geometry_capabilities", [])
			if dimensions.is_empty():
				errors.append("%s has no declared geometry dimensions" % label)
			if dimensions.size() != _unique_dimensions(dimensions).size():
				errors.append("%s declares a geometry dimension more than once" % label)
			if label in RETIRED_CONE_CONFIGS:
				if config.has("cone_degrees"):
					errors.append("%s retains retired cone_degrees beside sweep_degrees" % label)
				if not config.has("sweep_degrees") or not dimensions.has("sweep_degrees"):
					errors.append("%s does not declare its live sweep_degrees" % label)

			var player := PLAYER_SCENE.instantiate() as Node2D
			holder.add_child(player)
			player.call("configure_character", character_id, weapon_id)
			var weapon = player.get("equipped_weapon")
			if weapon == null or not is_instance_valid(weapon):
				errors.append("%s did not equip its real weapon scene" % label)
				player.free()
				continue
			_check_live_geometry(label, player, weapon, dimensions, errors)
			player.free()
	if weapon_count != 51:
		errors.append("expected 51 weapon configurations, got %d" % weapon_count)
	_check_live_summon_geometry(holder, "druid", "summon_amulet", 1.12, "druid_h0", errors)
	_check_live_summon_geometry(holder, "chemist", "homunculus_vial", 1.232, "chemist_homunculus_vial_final", errors)
	holder.free()

	var control_config: Dictionary = ProgressionData.weapon("berserk", "sword")
	var base_stats: Dictionary = ProgressionData.base_stats("berserk")
	var stronger := base_stats.duplicate(true)
	stronger["strength"] = float(stronger.get("strength", 0.0)) + 10.0
	var tougher := base_stats.duplicate(true)
	tougher["endurance"] = float(tougher.get("endurance", 0.0)) + 10.0
	var leader := base_stats.duplicate(true)
	leader["leadership"] = float(leader.get("leadership", 0.0)) + 10.0
	var base_knockback := float(ProgressionData.derived_parameters(base_stats, {}, control_config).get("knockback_power", 0.0))
	if float(ProgressionData.derived_parameters(stronger, {}, control_config).get("knockback_power", 0.0)) <= base_knockback:
		errors.append("Strength did not increase knockback")
	if not is_equal_approx(float(ProgressionData.derived_parameters(tougher, {}, control_config).get("knockback_power", 0.0)), base_knockback):
		errors.append("Endurance changed knockback")
	if not is_equal_approx(float(ProgressionData.derived_parameters(leader, {}, control_config).get("knockback_power", 0.0)), base_knockback):
		errors.append("Leadership changed knockback")

	var support := ProgressionData.derived_parameters(base_stats, {"damage_multiplier": 1.20, "buff_power_flat": 50.0}, control_config)
	var support_without_legacy := ProgressionData.derived_parameters(base_stats, {"damage_multiplier": 1.20}, control_config)
	if not is_equal_approx(float(support.get("support_multiplier", 0.0)), float(support_without_legacy.get("support_multiplier", 0.0))) or float(support.get("support_multiplier", 0.0)) <= 1.0:
		errors.append("support multiplier is not derived exactly from shared % damage")
	var legacy_modifiers := {"damage_multiplier": 1.10}
	for key in REMOVED_KEYS:
		legacy_modifiers[key] = 1.0
	var sanitized := ProgressionData.sanitize_run_modifiers(legacy_modifiers)
	for key in REMOVED_KEYS:
		if sanitized.has(key):
			errors.append("legacy save modifier '%s' survived sanitization" % key)
	var legacy_offer := [{"id": "legacy_range", "kind": "upgrade", "mods": {"range_multiplier": 1.20}}]
	var clean_offer := AttributeContract.sanitize_level_up_offer(legacy_offer, "berserk", base_stats, {}, control_config)
	if not clean_offer.is_empty():
		errors.append("legacy range offer was restored from save")

	for item in ProgressionData.reward_pool():
		_check_source("reward %s" % str(item.get("id", "")), item.get("mods", {}), errors)
	for item in ProgressionData.shop_items():
		_check_source("shop %s" % str(item.get("id", "")), item.get("mods", {}), errors)
	for character_id_value in ProgressionData.character_ids():
		for ascension in ProgressionData.ascension_levels(str(character_id_value)):
			_check_source("ascension %s" % str(ascension.get("id", "")), ascension.get("mods", {}), errors)
	_check_canonical_docs(errors)

	if not errors.is_empty():
		for error in errors:
			push_error("FAN-1891: %s" % error)
		quit(1)
		return
	print("FAN-2209 live-scene attack-area/control contract passed for 51 weapons.")
	quit(0)


func _check_live_geometry(label: String, player: Node, weapon: Node, dimensions: Array, errors: Array[String]) -> void:
	var before_parameters: Dictionary = player.get("derived_parameters")
	var before_area := float(before_parameters.get("attack_area_multiplier", 1.0))
	var before_reach := float(before_parameters.get("attack_range", 0.0))
	var before_speed := float(before_parameters.get("projectile_speed", 0.0))
	var before_weapon_reach = weapon.get("attack_range")
	var before_weapon_speed = weapon.get("projectile_speed")
	var before_properties := _live_property_values(weapon)
	var before_declared := _declared_values(weapon, before_parameters, dimensions, label, errors)

	var modifiers: Dictionary = (player.get("run_modifiers") as Dictionary).duplicate(true)
	modifiers["aoe_radius_multiplier"] = float(modifiers.get("aoe_radius_multiplier", 1.0)) * 1.15
	player.set("run_modifiers", modifiers)
	player.call("_apply_stat_scaling")
	player.call("_apply_weapon_scaling", weapon)
	var after_parameters: Dictionary = player.get("derived_parameters")
	var after_area := float(after_parameters.get("attack_area_multiplier", 1.0))
	if after_area <= before_area:
		errors.append("%s area upgrade did not change shared multiplier" % label)
		return
	var area_ratio := after_area / before_area
	var after_declared := _declared_values(weapon, after_parameters, dimensions, label, errors)
	for dimension in dimensions:
		if not before_declared.has(dimension) or not after_declared.has(dimension):
			continue
		var before := float(before_declared[dimension])
		var expected := clampf(before * area_ratio, 1.0, 360.0) if str(dimension).ends_with("degrees") else before * area_ratio
		if not is_equal_approx(float(after_declared[dimension]), expected):
			errors.append("%s declared %s changed %.4f -> %.4f, expected %.4f" % [label, dimension, before, after_declared[dimension], expected])

	var after_properties := _live_property_values(weapon)
	for property in before_properties:
		var canonical: String = "aoe_radius" if property == "summon_aoe_radius" else property
		if not dimensions.has(canonical) and not is_equal_approx(float(after_properties[property]), float(before_properties[property])):
			errors.append("%s undeclared %s changed %.4f -> %.4f" % [label, property, before_properties[property], after_properties[property]])
	var parameter_reach_changed := not is_equal_approx(float(after_parameters.get("attack_range", 0.0)), before_reach)
	var weapon_reach_changed := before_weapon_reach != null and not is_equal_approx(float(weapon.get("attack_range")), float(before_weapon_reach))
	if parameter_reach_changed or weapon_reach_changed:
		errors.append("%s area upgrade changed target reach" % label)
	var parameter_speed_changed := not is_equal_approx(float(after_parameters.get("projectile_speed", 0.0)), before_speed)
	var weapon_speed_changed := before_weapon_speed != null and not is_equal_approx(float(weapon.get("projectile_speed")), float(before_weapon_speed))
	if parameter_speed_changed or weapon_speed_changed:
		errors.append("%s area upgrade changed projectile speed" % label)

	player.call("_apply_stat_scaling")
	player.call("_apply_weapon_scaling", weapon)
	var repeated := _declared_values(weapon, player.get("derived_parameters"), dimensions, label, errors)
	for dimension in after_declared:
		if not is_equal_approx(float(repeated.get(dimension, INF)), float(after_declared[dimension])):
			errors.append("%s declared %s applied the shared multiplier more than once" % [label, dimension])


func _check_live_summon_geometry(holder: Node, character_id: String, weapon_id: String, multiplier: float, final_node: String, errors: Array[String]) -> void:
	var label := "%s/%s" % [character_id, weapon_id]
	var player := PLAYER_SCENE.instantiate() as Node2D
	holder.add_child(player)
	player.call("configure_character", character_id, weapon_id)
	var weapon = player.get("equipped_weapon")
	if weapon == null or not is_instance_valid(weapon):
		errors.append("%s did not equip its real summon weapon scene" % label)
		player.free()
		return
	var neutral_profile: Dictionary = weapon.call("_summon_profile", player)
	var neutral_splash := float(neutral_profile.get("aoe_radius", 0.0))
	var neutral_stored := float(weapon.get("summon_aoe_radius"))
	var state := Meta.default_state()
	var nodes: Array[String] = []
	for order in range(1, 6):
		nodes.append("%s_%s_b%d" % [character_id, weapon_id, order])
	nodes.append(final_node)
	state["skill_nodes"] = nodes
	player.call("apply_constellation_weapon_profiles", Meta.skill_profiles_for_class(state, character_id))
	player.call("_apply_weapon_scaling", weapon)
	var actual_multiplier := float(player.call("constellation_weapon_geometry_multiplier", weapon_id))
	var boosted_profile: Dictionary = weapon.call("_summon_profile", player)
	var stored_ratio := float(weapon.get("summon_aoe_radius")) / maxf(neutral_stored, 0.0001)
	var final_ratio := float(boosted_profile.get("aoe_radius", 0.0)) / maxf(neutral_splash, 0.0001)
	if not is_equal_approx(actual_multiplier, multiplier):
		errors.append("%s constellation geometry multiplier %.6f, expected %.6f" % [label, actual_multiplier, multiplier])
	if not _matches_summon_ratio(stored_ratio, multiplier):
		errors.append("%s stored summon splash ratio %.6f, expected %.6f" % [label, stored_ratio, multiplier])
	if not _matches_summon_ratio(final_ratio, multiplier):
		errors.append("%s final summon splash ratio %.6f, expected %.6f (squared %.6f)" % [label, final_ratio, multiplier, multiplier * multiplier])
	if _matches_summon_ratio(multiplier * multiplier, multiplier):
		errors.append("%s mutation oracle accepted repeated constellation geometry" % label)
	if _matches_summon_ratio(1.0, multiplier):
		errors.append("%s mutation oracle accepted missing constellation geometry" % label)
	player.call("_apply_weapon_scaling", weapon)
	var repeated_profile: Dictionary = weapon.call("_summon_profile", player)
	var repeated_ratio := float(repeated_profile.get("aoe_radius", 0.0)) / maxf(neutral_splash, 0.0001)
	if not _matches_summon_ratio(repeated_ratio, multiplier):
		errors.append("%s repeated setter changed final summon splash ratio %.6f" % [label, repeated_ratio])
	player.free()


func _matches_summon_ratio(actual: float, expected: float) -> bool:
	return is_equal_approx(actual, expected)


func _check_canonical_docs(errors: Array[String]) -> void:
	for path_value in CANONICAL_DOC_FACTS:
		var path := str(path_value)
		var text := FileAccess.get_file_as_string(path)
		var required_fact := str(CANONICAL_DOC_FACTS[path])
		if text.is_empty() or not text.contains(required_fact):
			errors.append("%s is missing its current attack-area contract" % path)
		if _has_current_retired_promise(text):
			errors.append("%s retains a current-facing retired range/sector/speed/buff promise" % path)
		for promise_value in RETIRED_CURRENT_PROMISES:
			if not _has_current_retired_promise("Current gameplay: %s." % str(promise_value)):
				errors.append("%s mutation oracle missed '%s'" % [path, promise_value])


func _has_current_retired_promise(text: String) -> bool:
	for line_value in text.split("\n"):
		var line := str(line_value).to_lower()
		if line.contains("legacy") or line.contains("internal"):
			continue
		for promise_value in RETIRED_CURRENT_PROMISES:
			if line.contains(str(promise_value)):
				return true
	return false


func _declared_values(weapon: Node, parameters: Dictionary, dimensions: Array, label: String, errors: Array[String]) -> Dictionary:
	var values := {}
	for dimension_value in dimensions:
		var dimension := str(dimension_value)
		if dimension == "aura_radius":
			if not parameters.has(dimension):
				errors.append("%s declared %s, but live Player has no such parameter" % [label, dimension])
				continue
			values[dimension] = float(parameters[dimension])
			continue
		var property := dimension
		if dimension == "aoe_radius" and weapon.get(property) == null:
			property = "summon_aoe_radius"
		if weapon.get(property) == null:
			errors.append("%s declared %s, but live weapon has no matching property" % [label, dimension])
			continue
		values[dimension] = float(weapon.get(property))
	return values


func _live_property_values(weapon: Node) -> Dictionary:
	var values := {}
	for property in LIVE_GEOMETRY_PROPERTIES:
		if weapon.get(property) != null:
			values[property] = float(weapon.get(property))
	return values


func _unique_dimensions(dimensions: Array) -> Dictionary:
	var unique := {}
	for dimension in dimensions:
		unique[str(dimension)] = true
	return unique


func _check_source(label: String, mods_value: Variant, errors: Array[String]) -> void:
	if not mods_value is Dictionary:
		return
	var mods: Dictionary = mods_value
	for key in REMOVED_KEYS:
		if mods.has(key):
			errors.append("%s still offers removed modifier '%s'" % [label, key])
