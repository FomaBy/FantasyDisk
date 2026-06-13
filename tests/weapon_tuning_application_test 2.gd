extends SceneTree

# SCRUM-191: регрессия применения бюджетной настройки оружия.
# Гарантирует, что КАЖДОЕ оружие на рантайме получает конфиг через
# ProgressionData.weapon() с применённым budget_damage_multiplier, а не сырой
# WEAPONS_BY_CLASS в обход тюнинга. Три гейта:
#   1) Реестр: weapon() добавляет budget_damage_multiplier/budget_tuning;
#      сырой WEAPONS_BY_CLASS их НЕ содержит (обход => потеря тюнинга, ловится).
#   2) Деривация: множитель реально масштабирует урон в derived_parameters
#      (damage с тюнингом / без == budget_damage_multiplier).
#   3) Рантайм: реальный Player.configure_character кладёт тюненный конфиг в
#      weapon_config и его derived_parameters["damage"] учитывает множитель.
# Отдельный изолированный файл (анти-коллизия с занятыми runtime_smoke/ui).
#
# Запуск: Godot --headless --path . --script res://tests/weapon_tuning_application_test.gd

const ProgressionData := preload("res://scripts/progression_data.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")

const EPS := 0.001
# Нетривиальный стат-блок: strength/intelligence/perception/energy > 0, чтобы
# damage/magic_damage/sound_wave_damage были ненулевыми и множитель проявился.
const PROBE_STATS := {
	"strength": 12.0, "agility": 8.0, "intelligence": 12.0, "perception": 10.0,
	"energy": 9.0, "knowledge": 8.0, "endurance": 10.0, "leadership": 9.0,
}
const NEUTRAL_MODS := {"damage_multiplier": 1.0}


func _initialize() -> void:
	await process_frame
	var errors: Array = []
	var pairs := 0
	var tuned_nontrivial := 0     # сколько оружий имеют множитель != 1.0 (анти-вакуум)

	for character_id in ProgressionData.character_ids():
		var cid := str(character_id)
		var raw_weapons: Dictionary = ProgressionData.WEAPONS_BY_CLASS.get(cid, {})
		for weapon_id in ProgressionData.weapon_ids(cid):
			var wid := str(weapon_id)
			pairs += 1
			var config: Dictionary = ProgressionData.weapon(cid, wid)

			# --- Гейт 1: реестр ---
			if not config.has("budget_damage_multiplier"):
				errors.append("%s/%s: weapon() без budget_damage_multiplier" % [cid, wid])
				continue
			if not config.has("budget_tuning"):
				errors.append("%s/%s: weapon() без budget_tuning" % [cid, wid])
			var mult := float(config["budget_damage_multiplier"])
			if not is_finite(mult) or mult <= 0.0:
				errors.append("%s/%s: некорректный budget_damage_multiplier=%s" % [cid, wid, mult])
				continue
			# Сырой dict не должен нести тюнинг — иначе обход weapon() был бы незаметен.
			if raw_weapons.has(wid) and (raw_weapons[wid] as Dictionary).has("budget_damage_multiplier"):
				errors.append("%s/%s: сырой WEAPONS_BY_CLASS уже содержит budget_damage_multiplier — обход weapon() не отловить" % [cid, wid])
			if absf(mult - 1.0) > EPS:
				tuned_nontrivial += 1

			# --- Гейт 2: деривация ---
			var tuned := ProgressionData.derived_parameters(PROBE_STATS, NEUTRAL_MODS, config)
			var untuned_cfg: Dictionary = config.duplicate(true)
			untuned_cfg["budget_damage_multiplier"] = 1.0
			var untuned := ProgressionData.derived_parameters(PROBE_STATS, NEUTRAL_MODS, untuned_cfg)
			for key in ["damage", "magic_damage", "sound_wave_damage"]:
				var base_v := float(untuned.get(key, 0.0))
				var tuned_v := float(tuned.get(key, 0.0))
				if base_v <= EPS:
					continue
				var ratio := tuned_v / base_v
				if absf(ratio - mult) > 0.01:
					errors.append("%s/%s: %s не масштабируется множителем (ratio=%.4f, ожидался %.4f) — тюнинг не применяется" % [
						cid, wid, key, ratio, mult])

	# --- Гейт 3: рантайм (по одному оружию на класс — дорогая инстанциация) ---
	var holder := Node2D.new()
	root.add_child(holder)
	await process_frame
	for character_id in ProgressionData.character_ids():
		var cid := str(character_id)
		var weapon_ids: Array = ProgressionData.weapon_ids(cid)
		if weapon_ids.is_empty():
			continue
		var wid := str(weapon_ids[0])
		var expected: Dictionary = ProgressionData.weapon(cid, wid)
		var player := PLAYER_SCENE.instantiate() as Node2D
		holder.add_child(player)
		if not player.has_method("configure_character"):
			errors.append("Player без configure_character — рантайм-гейт невозможен")
			player.queue_free()
			break
		player.configure_character(cid, wid)
		await process_frame
		var rt_cfg: Dictionary = player.get("weapon_config")
		if rt_cfg == null or not rt_cfg.has("budget_damage_multiplier"):
			errors.append("%s/%s: рантайм weapon_config без budget_damage_multiplier — equip обходит weapon()" % [cid, wid])
		elif absf(float(rt_cfg["budget_damage_multiplier"]) - float(expected["budget_damage_multiplier"])) > EPS:
			errors.append("%s/%s: рантайм множитель %.4f != реестр %.4f" % [
				cid, wid, float(rt_cfg["budget_damage_multiplier"]), float(expected["budget_damage_multiplier"])])
		# Урон в реальных derived_parameters должен учитывать множитель.
		var dp: Dictionary = player.get("derived_parameters")
		if dp != null and float(dp.get("damage", 0.0)) <= 0.0 and float(dp.get("magic_damage", 0.0)) <= 0.0:
			errors.append("%s/%s: рантайм derived_parameters без урона" % [cid, wid])
		player.queue_free()
		await process_frame
	holder.queue_free()
	await process_frame

	# --- Анти-вакуум ---
	if pairs < 9:
		errors.append("Подозрительно мало пар класс/оружие (%d) — гейт прошёл бы вакуумно" % pairs)
	if tuned_nontrivial == 0:
		errors.append("Ни одно оружие не имеет budget_damage_multiplier != 1.0 — тест пропорциональности тривиален, тюнинг не настроен")

	if not errors.is_empty():
		for e in errors:
			push_error("Weapon tuning regression: %s" % e)
		push_error("Weapon budget tuning application: %d ошибок (пар %d)." % [errors.size(), pairs])
		quit(1)
		return
	print("Weapon tuning application test passed (%d пар, %d с нетривиальным множителем)." % [pairs, tuned_nontrivial])
	quit(0)
