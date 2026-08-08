extends SceneTree

const ProgressionData := preload("res://scripts/progression_data.gd")
const AttributeContract := preload("res://scripts/attribute_contract.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const REMOVED_KEYS := ["range_multiplier", "sector_multiplier", "projectile_speed_flat", "aura_radius_flat", "buff_power_flat"]
const RETIRED_CONE_CONFIGS := ["berserk/sword", "berserk/axe", "knight/long_spear", "knight/tower_shield"]
const LIVE_GEOMETRY_PROPERTIES := [
	"aoe_radius", "summon_aoe_radius", "beam_width", "wave_width",
	"suppression_width", "inner_width", "outer_width", "sweep_degrees", "cone_degrees",
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
	var sanitized := ProgressionData.sanitize_run_modifiers({"damage_multiplier": 1.10, "range_multiplier": 2.0, "buff_power_flat": 1.0})
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
