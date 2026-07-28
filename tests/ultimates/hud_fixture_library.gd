extends RefCounted

## FAN-1458 — библиотека versioned contract fixtures для ultimate-HUD тестов.
##
## Не тест (не SceneTree): собирает снапшоты для view-model из НАСТОЯЩЕГО
## реестра ультимейтов и канонического инвентаря оружия, чтобы AC проверялись
## на fixture registry snapshot, а не на выдуманных словарях. Мутируются только
## deep-copy профили (например, синтетический weapon_profile-источник);
## сам реестр остаётся нетронутым.

const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const State := preload("res://scripts/ui/ultimate_hud/ultimate_hud_state.gd")

var registry = null


func _init() -> void:
	registry = Registry.new(PD.WEAPONS_BY_CLASS)


func keyboard_input() -> Dictionary:
	return {
		"device": State.DEVICE_KEYBOARD,
		"joy_button": State.DEFAULT_JOY_BUTTON,
		"key_label": State.DEFAULT_KEY_LABEL,
		"key_glyph": State.DEFAULT_KEY_GLYPH,
	}


func gamepad_input() -> Dictionary:
	return {
		"device": State.DEVICE_GAMEPAD,
		"joy_button": State.DEFAULT_JOY_BUTTON,
		"key_label": State.DEFAULT_KEY_LABEL,
		"key_glyph": State.DEFAULT_KEY_GLYPH,
	}


func unavailable_input() -> Dictionary:
	return {"device": State.DEVICE_NONE}


## Снапшот с настоящим источником резолюции из реестра. Для всех v1-профилей
## (`declared`) это legacy_class_fallback: именно случай «class-fallback-профиль
## обязан отрисовываться как selected weapon».
func fallback_snapshot(class_id: String, weapon_id: String, overrides := {}) -> Dictionary:
	var legacy := PD.ultimate_config(class_id)
	var snapshot := {
		"profile": registry.catalog_profile_for(class_id, weapon_id),
		"resolution_source": registry.resolution_source(class_id, weapon_id),
		"weapon_config": _weapon_config(class_id, weapon_id),
		"ultimate_text": {
			"title": str(legacy.get("title", "")),
			"description": str(legacy.get("description", "")),
		},
		"charge": {"fraction": 0.5, "active": false},
		"input": keyboard_input(),
		"aim": {"mode": State.AIM_MODE_AUTO, "aiming": false},
	}
	snapshot.merge(overrides, true)
	return snapshot


## Синтетический weapon_profile-источник: deep-copy реального профиля,
## помеченный ready на уровне fixture (реестр не мутируется).
func weapon_profile_snapshot(class_id: String, weapon_id: String, overrides := {}) -> Dictionary:
	var profile: Dictionary = registry.catalog_profile_for(class_id, weapon_id)
	profile["implementation_state"] = "ready"
	var snapshot := fallback_snapshot(class_id, weapon_id, overrides)
	snapshot["profile"] = profile
	snapshot["resolution_source"] = Resolver.SOURCE_WEAPON_PROFILE
	snapshot["ultimate_text"] = {
		"title": str(((profile.get("identity", {}) as Dictionary)).get("title_id", "")),
		"description": "Оружейная ульта (v1 fixture): исполняемый профиль выбранного оружия.",
	}
	return snapshot


## Пара (класс, оружие) с самым длинным названием оружия и самым длинным
## описанием класс-ульты — стресс-контент для responsive-теста.
func longest_content_pair() -> Dictionary:
	var best := {"class_id": "", "weapon_id": "", "score": -1}
	for class_id in registry.class_ids():
		var description_length := str(PD.ultimate_config(class_id).get("description", "")).length()
		for weapon_id in registry.weapon_ids(class_id):
			var title_length := str(_weapon_config(class_id, weapon_id).get("title", "")).length()
			var score := title_length * 1000 + description_length
			if score > int(best["score"]):
				best = {"class_id": class_id, "weapon_id": weapon_id, "score": score}
	return best


func _weapon_config(class_id: String, weapon_id: String) -> Dictionary:
	var weapons: Dictionary = PD.WEAPONS_BY_CLASS.get(class_id, {})
	var config = weapons.get(weapon_id, {})
	return config if config is Dictionary else {}
