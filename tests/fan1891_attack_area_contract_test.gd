extends SceneTree

const ProgressionData := preload("res://scripts/progression_data.gd")
const AttributeContract := preload("res://scripts/attribute_contract.gd")
const REMOVED_KEYS := ["range_multiplier", "sector_multiplier", "projectile_speed_flat", "aura_radius_flat", "buff_power_flat"]


func _initialize() -> void:
	var errors: Array[String] = []
	var weapon_count := 0
	for character_id_value in ProgressionData.character_ids():
		var character_id := str(character_id_value)
		var stats: Dictionary = ProgressionData.base_stats(character_id)
		for weapon_id_value in ProgressionData.weapon_ids(character_id):
			var config: Dictionary = ProgressionData.weapon(character_id, str(weapon_id_value))
			weapon_count += 1
			var dimensions: Array = config.get("geometry_capabilities", [])
			if dimensions.is_empty():
				errors.append("%s/%s has no declared geometry dimensions" % [character_id, str(weapon_id_value)])
			var base := ProgressionData.derived_parameters(stats, {}, config)
			var area := ProgressionData.derived_parameters(stats, {"aoe_radius_multiplier": 1.15}, config)
			if float(area.get("attack_area_multiplier", 1.0)) <= float(base.get("attack_area_multiplier", 1.0)):
				errors.append("%s/%s area upgrade did not change shared multiplier" % [character_id, str(weapon_id_value)])
			if not is_equal_approx(float(area.get("attack_range", 0.0)), float(base.get("attack_range", 0.0))):
				errors.append("%s/%s area upgrade changed target reach" % [character_id, str(weapon_id_value)])
			if not is_equal_approx(float(area.get("projectile_speed", 0.0)), float(base.get("projectile_speed", 0.0))):
				errors.append("%s/%s area upgrade changed projectile speed" % [character_id, str(weapon_id_value)])
	if weapon_count != 51:
		errors.append("expected 51 weapon configurations, got %d" % weapon_count)

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
	print("FAN-1891 attack-area/control contract passed for 51 weapons.")
	quit(0)


func _check_source(label: String, mods_value: Variant, errors: Array[String]) -> void:
	if not mods_value is Dictionary:
		return
	var mods: Dictionary = mods_value
	for key in REMOVED_KEYS:
		if mods.has(key):
			errors.append("%s still offers removed modifier '%s'" % [label, key])
