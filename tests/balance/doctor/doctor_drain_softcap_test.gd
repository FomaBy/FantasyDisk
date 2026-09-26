extends SceneTree

# SCRUM-517: live-регресс на бессмертие Доктора через drain-heal.
#
# Раньше class_weapon._heal_owner_from_damage лил drain-лечение ПРЯМО в health
# без потолка/с. Для Доктора (restore_potion heal_pct 0.34; plague_syringe 0.26 +
# 6 DoT-тиков) это давало сотни HP/с в плотной толпе (DoT-стак × число целей) →
# герой был бессмертен. Существующие survivability-гейты абстрактны (4 профиля без
# weapon-lifesteal) и Доктора НЕ видели — поэтому баг просочился.
#
# Этот гейт ГОНЯЕТ настоящего Player.configure_character("doctor", ...) и проверяет
# два инварианта на боевом коде (не на абстрактной модели):
#   A. CAPPED: суммарный drain-heal за окно <= DRAIN_HEAL_PER_SECOND_CAP × окно
#      (+ запас на дискретность бюджета). Т.е. drain больше НЕ обходит per-second лимит.
#   B. MORTAL: при входящем митигированном DPS заметно выше cap чистый HP СТРОГО
#      убывает за окно, т.е. бессмертие недостижимо (аналог инварианта
#      global_survivability_balance_smoke_test, но на ЖИВОМ Докторе и его drain).
#   C. SUSTAIN-IDENTITY: drain-cap Доктора заметно выше вампирного дефолта — Доктор
#      остаётся сильнейшим детерминированным sustain-классом (не выхолостили).
#
# Запуск: Godot --headless --path . --script res://tests/doctor_drain_softcap_test.gd

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const ProgressionData := preload("res://scripts/progression_data.gd")
const Surv := preload("res://tools/survivability_harness.gd")

const EPS := 0.01
const DOCTOR_FORBIDDEN_SUSTAIN_IDS := {
	"regeneration_up": true,
	"vampiric_up": true,  # FAN-1034: мерж vampiric_amount_up + vampiric_chance_up
	"leech_heart": true,
	"leech_fang": true,
	"field_kit": true,
	"vital_siphon": true,
	"breather_totem": true,
	"soul_harvest": true,
	"second_wind": true,
	"swiftfoot": true,
	"shop_heal": true,
}
const DOCTOR_FORBIDDEN_SUSTAIN_ATTRS := {
	"regeneration": true,
	"vampiric": true,  # FAN-1034
}
const DOCTOR_FORBIDDEN_SUSTAIN_MOD_KEYS := {
	"regeneration_flat": true,
	"vampiric_chance_flat": true,
	"vampiric_amount_flat": true,
	"vampiric_heal_per_second_cap": true,
	"kill_heal_percent": true,
	"room_clear_heal_percent": true,
	"kill_streak_heal_every": true,
	"lowhp_regen_bonus": true,
}


func _initialize() -> void:
	seed(424242)
	var errors: Array = []

	await process_frame
	var holder := Node2D.new()
	root.add_child(holder)
	await process_frame

	var drain_cap_default := float(ProgressionData.BalanceData.DRAIN_HEAL_PER_SECOND_CAP_DEFAULT)
	var drain_cap_hard := float(ProgressionData.BalanceData.DRAIN_HEAL_PER_SECOND_CAP_HARD)
	var vampiric_default := float(ProgressionData.VAMPIRIC_HEAL_CAP_DEFAULT)

	_test_doctor_external_sustain_reward_filter(errors)

	# --- C. Идентичность: drain-cap должен быть заметно выше вампирного дефолта ---
	if not (drain_cap_default > vampiric_default * 2.0):
		errors.append("drain-cap %.2f не выше вампирного %.2f×2 — Доктор выхолощен" % [drain_cap_default, vampiric_default])
	if not (drain_cap_hard >= drain_cap_default):
		errors.append("hard-cap %.2f < default %.2f" % [drain_cap_hard, drain_cap_default])

	for weapon_id in ["restore_potion", "plague_syringe"]:
		var player := PLAYER_SCENE.instantiate() as Node2D
		holder.add_child(player)
		player.add_to_group("player")
		if not player.has_method("configure_character") or not player.has_method("apply_drain_heal"):
			errors.append("%s: Player без configure_character/apply_drain_heal — гейт невозможен" % weapon_id)
			player.queue_free()
			continue
		player.configure_character("doctor", weapon_id)
		await process_frame
		var weapon: Node = player.get("equipped_weapon")
		if weapon == null or not weapon.has_method("_heal_owner_from_damage"):
			errors.append("%s: нет equipped_weapon/_heal_owner_from_damage" % weapon_id)
			player.queue_free()
			continue
		var max_hp := float(player.get("max_health"))

		# === A. CAPPED: drain не обходит per-second бюджет ===
		# Пополняем бюджет ровно на 1 окно, затем заливаем заведомо избыточный спрос
		# (как толпа из N целей + DoT-стак) и смотрим, сколько реально влилось.
		var window := 1.0
		player.set("health", 1.0)
		player.call("_apply_regeneration", window)  # наполнить бюджет на окно
		# Имитируем «чрезмерный» спрос: много вызовов реального heal-пути с большим уроном.
		var huge_demand_heal := 0.0
		for _i in range(400):
			player.set("health", 1.0)  # держим HP низким, чтобы heal не упирался в потолок
			var before := float(player.get("health"))
			weapon.call("_heal_owner_from_damage", player, 240.0)  # 240 урона/удар — заведомо много
			huge_demand_heal += float(player.get("health")) - before
		# Бюджет за одно окно: не больше cap×окно (+ один «квант» на дискретность).
		var cap_for_window := drain_cap_default * window
		if not (huge_demand_heal <= cap_for_window + 0.5):
			errors.append("%s: drain за окно %.2f HP > cap %.2f — бюджет обходится (бессмертие)" % [weapon_id, huge_demand_heal, cap_for_window])
		# И должно быть СКОЛЬКО-ТО (Доктор всё ещё лечится, не ноль).
		if not (huge_demand_heal > 0.1):
			errors.append("%s: drain за окно ~0 (%.3f) — Доктор перестал лечиться вообще" % [weapon_id, huge_demand_heal])

		# Бюджет должен быть исчерпан — следующий мгновенный спрос (без рефилла) ~ноль.
		player.set("health", 1.0)
		var after_drain := 0.0
		for _j in range(50):
			player.set("health", 1.0)
			var b := float(player.get("health"))
			weapon.call("_heal_owner_from_damage", player, 240.0)
			after_drain += float(player.get("health")) - b
		if not (after_drain <= 0.2):
			errors.append("%s: после исчерпания бюджета drain продолжает лить %.3f HP — нет потолка" % [weapon_id, after_drain])

		# === B. MORTAL: при входящем DPS >> cap чистый HP убывает ===
		# Берём реальную митигацию Доктора и моделируем толпу контактных врагов.
		var dp: Dictionary = player.get("derived_parameters")
		var defense := clampf(float(dp.get("defense", 0.0)), 0.0, ProgressionData.SURVIVABILITY_DEFENSE_CAP)
		var absorb := float(dp.get("absorb", 0.0))
		var mit_per_hit := Surv.expected_hit_damage(14.0, defense, absorb, 0.0)  # ~средний контактный удар
		# 6 врагов, каждый бьёт ~1.2 раза/с → плотная толпа.
		var incoming_dps := mit_per_hit * 6.0 * 1.2
		if not (incoming_dps > drain_cap_hard + EPS):
			errors.append("%s: смоделированный incoming %.1f не выше hard-cap %.1f — сценарий вакуумен" % [weapon_id, incoming_dps, drain_cap_hard])
		# Прогоняем окно: каждый «кадр» — рефилл бюджета, максимальный drain-спрос и входящий урон.
		var sim_seconds := 4.0
		var dt := 0.1
		player.set("health", max_hp)
		var hp_start := float(player.get("health"))
		var steps := int(sim_seconds / dt)
		for _s in range(steps):
			player.call("_apply_regeneration", dt)  # рефилл бюджета на dt
			# максимально возможный drain в этот тик (толпа+DoT): большой спрос
			weapon.call("_heal_owner_from_damage", player, 240.0)
			weapon.call("_heal_owner_from_damage", player, 240.0)
			# входящий урон за тик
			player.set("health", float(player.get("health")) - incoming_dps * dt)
			if float(player.get("health")) <= 0.0:
				break
		var hp_end := float(player.get("health"))
		# Чистый HP должен заметно упасть (бессмертие недостижимо).
		var net_drop := hp_start - hp_end
		if not (net_drop > 0.0):
			errors.append("%s: HP НЕ упал за %.0fс под incoming %.1f/с (cap %.1f/с) — бессмертие" % [weapon_id, sim_seconds, incoming_dps, drain_cap_default])
		# При таком перевесе входящего над cap Доктор должен буквально умереть.
		if not (hp_end <= 0.0):
			errors.append("%s: Доктор выжил (HP=%.1f) под incoming %.1f/с >> cap — реген всё ещё спасает" % [weapon_id, hp_end, incoming_dps])

		print("Doctor[%s]: capped_heal/окно=%.2f (cap %.2f), incoming=%.1f/с, HP %.1f→%.1f (drop %.1f)" % [weapon_id, huge_demand_heal, cap_for_window, incoming_dps, hp_start, hp_end, net_drop])
		player.queue_free()
		await process_frame

	holder.queue_free()
	await process_frame

	if not errors.is_empty():
		for e in errors:
			push_error("Doctor drain softcap: %s" % e)
		push_error("Doctor drain softcap test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Doctor drain softcap test passed: drain capped per-second, Доктор смертен под плотной толпой, sustain-идентичность сохранена.")
	quit(0)


func _test_doctor_external_sustain_reward_filter(errors: Array) -> void:
	_assert_no_doctor_external_sustain(ProgressionData.level_up_rewards("doctor"), "level_up_rewards", errors)
	_assert_no_doctor_external_sustain(ProgressionData.reward_pool("doctor"), "reward_pool", errors)
	_assert_no_doctor_external_sustain(ProgressionData.shop_items(0, "doctor"), "shop_items", errors)
	_assert_no_doctor_external_sustain(ProgressionData.elite_artifact_choices(8, 20, "doctor"), "elite_artifact_choices", errors)
	_assert_no_doctor_external_sustain(ProgressionData.boss_completion_artifact_rewards("doctor"), "boss_completion_artifact_rewards", errors)
	_assert_no_doctor_external_sustain(ProgressionData.boss_completion_artifact_choices(3, "doctor"), "boss_completion_artifact_choices", errors)
	_assert_no_doctor_external_sustain(ProgressionData.start_boons("doctor"), "start_boons", errors)
	_assert_boss_completion_reward_path_filters_doctor(errors)
	if not ProgressionData.start_boon_mods("swiftfoot", "doctor").is_empty():
		errors.append("Doctor start_boon_mods('swiftfoot') must be empty.")
	if ProgressionData.start_boon_mods("swiftfoot", "berserk").is_empty():
		errors.append("Non-doctor classes should keep swiftfoot start boon available.")

	var berserk_level_rewards: Array = ProgressionData.level_up_rewards("berserk")
	if not _contains_reward_id(berserk_level_rewards, "vampiric_up"):
		errors.append("Expected non-doctor level-up pool to keep vampiric_up.")
	var berserk_pool: Array = ProgressionData.reward_pool("berserk")
	if not _contains_reward_id(berserk_pool, "leech_fang"):
		errors.append("Expected non-doctor artifact pool to keep leech_fang.")
	var berserk_boss_pool: Array = ProgressionData.boss_completion_artifact_rewards("berserk")
	if not _contains_reward_id(berserk_boss_pool, "leech_heart"):
		errors.append("Expected non-doctor boss completion pool to keep leech_heart.")
	if not _contains_reward_id(berserk_boss_pool, "soul_harvest"):
		errors.append("Expected non-doctor boss completion pool to keep soul_harvest.")


func _assert_no_doctor_external_sustain(rewards: Array, source_name: String, errors: Array) -> void:
	for reward in rewards:
		var reward_dict := reward as Dictionary
		if _is_forbidden_external_sustain(reward_dict):
			errors.append("Doctor %s still contains forbidden sustain reward '%s'." % [source_name, reward_dict.get("id", "?")])


func _is_forbidden_external_sustain(reward: Dictionary) -> bool:
	if DOCTOR_FORBIDDEN_SUSTAIN_IDS.has(str(reward.get("id", ""))):
		return true
	if DOCTOR_FORBIDDEN_SUSTAIN_ATTRS.has(str(reward.get("attr", ""))):
		return true
	var mods: Dictionary = reward.get("mods", {}) as Dictionary
	for key in mods.keys():
		if DOCTOR_FORBIDDEN_SUSTAIN_MOD_KEYS.has(str(key)):
			return true
	if reward.has("heal_percent"):
		return true
	return false


func _contains_reward_id(rewards: Array, reward_id: String) -> bool:
	for reward in rewards:
		if str((reward as Dictionary).get("id", "")) == reward_id:
			return true
	return false


func _assert_boss_completion_reward_path_filters_doctor(errors: Array) -> void:
	# SCRUM-873: артефакт-путь босса переехал из _grant_boss_completion_rewards
	# (combat_director) в экран выбора _show_boss_artifact_reward; после сплита
	# FAN-3824 экран живёт в scripts/ui/screens/level_up_screen.gd. Экран обязан
	# использовать character-filtered boss_completion_artifact_choices.
	var source := FileAccess.get_file_as_string("res://scripts/ui/screens/level_up_screen.gd")
	var start := source.find("func _show_boss_artifact_reward(")
	if start < 0:
		errors.append("level_up_screen missing _show_boss_artifact_reward.")
		return
	var next_func := source.find("\nfunc ", start + 1)
	var body := source.substr(start, next_func - start if next_func > start else source.length() - start)
	if not body.contains("boss_completion_artifact_choices"):
		errors.append("Boss reward screen must use character-filtered boss_completion_artifact_choices().")
	if not body.contains("selected_character_id"):
		errors.append("Boss reward screen must pass selected_character_id into the pool.")
