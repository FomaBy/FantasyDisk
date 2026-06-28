extends SceneTree

const PD := preload("res://scripts/progression_data.gd")
const EPS := 0.0001

const TRIGGERED_EXPECTED := {
	"field_kit": {"trigger": "on_room_clear", "mod": "room_clear_heal_percent", "value": 0.05},
	"vital_siphon": {"trigger": "on_kill", "mod": "kill_heal_percent", "value": 0.01},
	"powder_charge": {"trigger": "on_kill", "mod": "kill_explosion_chance", "value": 0.10},
	"bulwark_echo": {"trigger": "on_take_hit", "mod": "take_hit_pulse_chance", "value": 0.16},
	"duelist_spur": {"trigger": "on_crit", "mod": "crit_speed_burst", "value": 0.22},
}

const CURSE_EXPECTED := {
	"sacrifice_seal": {"crit_chance_flat": 0.30, "max_health_multiplier": 0.78},
	"hungry_amulet": {"money_gain_multiplier": 1.85, "healing_multiplier": 0.65},
	"berserk_totem": {"damage_multiplier": 1.60, "move_speed_multiplier": 0.80},
	"focus_lens": {"range_multiplier": 1.70, "aoe_radius_multiplier": 0.75},
	"stone_hide": {"defense_flat": 0.40, "attack_speed_multiplier": 0.75},
}

const SUPPORTED_CURSE_MOD_KEYS := [
	"attack_speed_multiplier",
	"aoe_radius_multiplier",
	"crit_chance_flat",
	"damage_multiplier",
	"defense_flat",
	"healing_multiplier",
	"max_health_multiplier",
	"money_gain_multiplier",
	"move_speed_multiplier",
	"range_multiplier",
]

const PLUS_KEYS := [
	"crit_chance_flat",
	"damage_multiplier",
	"defense_flat",
	"money_gain_multiplier",
	"range_multiplier",
]

const MINUS_KEYS := [
	"aoe_radius_multiplier",
	"attack_speed_multiplier",
	"healing_multiplier",
	"max_health_multiplier",
	"move_speed_multiplier",
]

const ICON_IDS := [
	"field_kit",
	"vital_siphon",
	"powder_charge",
	"bulwark_echo",
	"duelist_spur",
	"sacrifice_seal",
	"hungry_amulet",
	"berserk_totem",
	"focus_lens",
	"stone_hide",
]

func _initialize() -> void:
	var errors: Array[String] = []
	_check_icons(errors)
	_check_pool_and_shop(errors)
	_check_triggered_artifacts(errors)
	_check_curse_relics(errors)
	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("SCRUM-606/609 artifact data+icon verifier passed (%d artifacts)." % ICON_IDS.size())
	quit(0)


func _check_icons(errors: Array[String]) -> void:
	for artifact_id in ICON_IDS:
		var png_path := "res://assets/sprites/ui/icons/artifacts/artifact_%s.png" % artifact_id
		var import_path := png_path + ".import"
		if not ResourceLoader.exists(png_path):
			errors.append("missing runtime PNG: %s" % png_path)
			continue
		if not FileAccess.file_exists(ProjectSettings.globalize_path(import_path)):
			errors.append("missing import sidecar: %s" % import_path)
		var image := Image.new()
		var err := image.load(ProjectSettings.globalize_path(png_path))
		if err != OK:
			errors.append("cannot load PNG image: %s" % png_path)
			continue
		if image.get_width() != 256 or image.get_height() != 256:
			errors.append("%s size is %dx%d, expected 256x256" % [
				png_path,
				image.get_width(),
				image.get_height(),
			])
		if not [Image.FORMAT_RGBA8, Image.FORMAT_RGBAF, Image.FORMAT_RGBAH].has(image.get_format()):
			errors.append("%s is not RGBA format: %s" % [png_path, image.get_format()])
		var corner_alpha: float = max(
			image.get_pixel(0, 0).a,
			image.get_pixel(255, 0).a,
			image.get_pixel(0, 255).a,
			image.get_pixel(255, 255).a
		)
		if corner_alpha > 0.01:
			errors.append("%s has non-transparent corners: %.3f" % [png_path, corner_alpha])


func _check_pool_and_shop(errors: Array[String]) -> void:
	var reward_ids := _ids_from(PD.reward_pool("berserk"))
	var shop_ids := _ids_from(PD.shop_items(0))
	for artifact_id in ICON_IDS:
		var definition := PD.artifact_definition(artifact_id)
		if definition.is_empty():
			errors.append("%s missing from ARTIFACTS" % artifact_id)
			continue
		if not reward_ids.has(artifact_id):
			errors.append("%s missing from reward_pool" % artifact_id)
		if not shop_ids.has(artifact_id):
			errors.append("%s missing from shop_items" % artifact_id)


func _check_triggered_artifacts(errors: Array[String]) -> void:
	for artifact_id in TRIGGERED_EXPECTED.keys():
		var expected: Dictionary = TRIGGERED_EXPECTED[artifact_id]
		var definition := PD.artifact_definition(artifact_id)
		if definition.is_empty():
			errors.append("%s missing from ARTIFACTS" % artifact_id)
			continue
		if int(definition.get("tier", 0)) != 2:
			errors.append("%s must be tier 2" % artifact_id)
		if int(definition.get("cost", 0)) != 55:
			errors.append("%s must cost 55" % artifact_id)
		if not bool(definition.get("active", false)):
			errors.append("%s must carry active:true" % artifact_id)
		if str(definition.get("trigger", "")) != str(expected["trigger"]):
			errors.append("%s trigger expected %s, got %s" % [artifact_id, expected["trigger"], definition.get("trigger", "")])
		if not str(definition.get("description", "")).contains("Актив"):
			errors.append("%s description must note active state" % artifact_id)
		var mods: Dictionary = definition.get("mods", {})
		var mod_key := str(expected["mod"])
		if mods.size() != 1 or not mods.has(mod_key):
			errors.append("%s must only use consumer flag %s" % [artifact_id, mod_key])
			continue
		if not _float_eq(float(mods[mod_key]), float(expected["value"])):
			errors.append("%s %s expected %.3f, got %.3f" % [artifact_id, mod_key, expected["value"], mods[mod_key]])


func _check_curse_relics(errors: Array[String]) -> void:
	for artifact_id in CURSE_EXPECTED.keys():
		var expected: Dictionary = CURSE_EXPECTED[artifact_id]
		var definition := PD.artifact_definition(artifact_id)
		if definition.is_empty():
			errors.append("%s missing from ARTIFACTS" % artifact_id)
			continue
		if int(definition.get("tier", 0)) != 2:
			errors.append("%s must be tier 2" % artifact_id)
		if int(definition.get("cost", 0)) != 55:
			errors.append("%s must cost 55" % artifact_id)
		if bool(definition.get("active", false)) or str(definition.get("trigger", "")) != "":
			errors.append("%s must stay passive, not active/triggered" % artifact_id)
		var mods: Dictionary = definition.get("mods", {})
		if mods.size() != expected.size():
			errors.append("%s expected %d mods, got %d" % [artifact_id, expected.size(), mods.size()])
		for mod_key in mods.keys():
			if not SUPPORTED_CURSE_MOD_KEYS.has(str(mod_key)):
				errors.append("%s uses unsupported mod key %s" % [artifact_id, mod_key])
		for mod_key in expected.keys():
			if not mods.has(mod_key):
				errors.append("%s missing mod %s" % [artifact_id, mod_key])
				continue
			if not _float_eq(float(mods[mod_key]), float(expected[mod_key])):
				errors.append("%s %s expected %.3f, got %.3f" % [artifact_id, mod_key, expected[mod_key], mods[mod_key]])
		if not _has_real_plus(mods):
			errors.append("%s must include a real upside" % artifact_id)
		if not _has_real_minus(mods):
			errors.append("%s must include a real downside" % artifact_id)


func _ids_from(items: Array) -> Dictionary:
	var ids := {}
	for item in items:
		if item is Dictionary:
			ids[str((item as Dictionary).get("id", ""))] = true
	return ids


func _float_eq(a: float, b: float) -> bool:
	return absf(a - b) <= EPS


func _has_real_plus(mods: Dictionary) -> bool:
	for key in PLUS_KEYS:
		if not mods.has(key):
			continue
		var value := float(mods[key])
		if key.ends_with("_multiplier") and value > 1.0:
			return true
		if key.ends_with("_flat") and value > 0.0:
			return true
	return false


func _has_real_minus(mods: Dictionary) -> bool:
	for key in MINUS_KEYS:
		if not mods.has(key):
			continue
		if float(mods[key]) < 1.0:
			return true
	return false
