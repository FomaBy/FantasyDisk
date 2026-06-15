extends SceneTree

# Integrity-тест CLASS_BUDGET_PROFILES (progression_data_balance.gd). Симуляционные
# баланс-тесты меряют DPS-коридоры, но НЕ проверяют консистентность ярлыка профиля:
# профиль 'solo' с aoe_target > solo_target (или наоборот для 'aoe') — мисс-ярлык,
# который тихо уводит авто-тюнинг (budget_tuning_for) не туда. Плюс валидность
# enum-полей и диапазон бюджетов (опечатка 10.0 вместо 1.0). Самодостаточно: только
# таблица бюджетов, без сцепки с занятым файлом классов. Изолированный файл.
#
# Запуск: Godot --headless --path . --script res://tests/class_budget_profiles_integrity_test.gd

const Balance := preload("res://scripts/progression_data_balance.gd")

const VALID_PROFILES := ["balanced", "aoe", "solo"]
const VALID_SURVIVAL := ["sturdy", "steady", "fragile", "tank", "control"]
const REQUIRED_KEYS := ["profile", "survival", "damage_budget", "solo_target", "aoe_target"]
const BUDGET_MIN := 0.0
const BUDGET_MAX := 2.0


func _initialize() -> void:
	var errors: Array = []
	_check_profiles(errors)
	_check_base_constants(errors)

	if not errors.is_empty():
		for e in errors:
			push_error("Class budget profiles: %s" % e)
		push_error("Class budget profiles test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Class budget profiles test passed (%d классов)." % Balance.CLASS_BUDGET_PROFILES.size())
	quit(0)


func _num_in_range(errors: Array, dict: Dictionary, key: String, where: String) -> void:
	var v = dict.get(key, null)
	if not (v is int or v is float):
		errors.append("%s: %s не число" % [where, key])
		return
	var f := float(v)
	if f <= BUDGET_MIN or f > BUDGET_MAX:
		errors.append("%s: %s=%.2f вне (%.1f, %.1f] — похоже на опечатку" % [where, key, f, BUDGET_MIN, BUDGET_MAX])


func _check_profiles(errors: Array) -> void:
	var profiles: Dictionary = Balance.CLASS_BUDGET_PROFILES
	if profiles.is_empty():
		errors.append("CLASS_BUDGET_PROFILES пуст")
	for class_id in profiles:
		var p: Dictionary = profiles[class_id]
		var where := "класс '%s'" % str(class_id)
		for key in REQUIRED_KEYS:
			if not p.has(key):
				errors.append("%s: нет ключа '%s'" % [where, key])
		var profile := str(p.get("profile", ""))
		if not VALID_PROFILES.has(profile):
			errors.append("%s: profile '%s' вне %s" % [where, profile, str(VALID_PROFILES)])
		if not VALID_SURVIVAL.has(str(p.get("survival", ""))):
			errors.append("%s: survival '%s' вне %s" % [where, str(p.get("survival", "")), str(VALID_SURVIVAL)])
		_num_in_range(errors, p, "damage_budget", where)
		_num_in_range(errors, p, "solo_target", where)
		_num_in_range(errors, p, "aoe_target", where)
		# Консистентность ярлыка: solo-класс заточен под одиночную цель, aoe — под толпу.
		var solo := float(p.get("solo_target", 0.0))
		var aoe := float(p.get("aoe_target", 0.0))
		if profile == "solo" and solo <= aoe:
			errors.append("%s: profile 'solo', но solo_target (%.2f) <= aoe_target (%.2f)" % [where, solo, aoe])
		if profile == "aoe" and aoe <= solo:
			errors.append("%s: profile 'aoe', но aoe_target (%.2f) <= solo_target (%.2f)" % [where, aoe, solo])
		# 'balanced' намеренно может слегка крениться — строгого равенства не требуем.


func _check_base_constants(errors: Array) -> void:
	if float(Balance.BALANCE_BASE_SOLO_DPS) <= 0.0:
		errors.append("BALANCE_BASE_SOLO_DPS <= 0")
	if float(Balance.BALANCE_BASE_AOE_DPS) <= 0.0:
		errors.append("BALANCE_BASE_AOE_DPS <= 0")
	if float(Balance.BALANCE_WINDOW_SECONDS) <= 0.0:
		errors.append("BALANCE_WINDOW_SECONDS <= 0")
	# Коридоры — доли в (0,1).
	var corridor := float(Balance.CROWD_CLEAR_CORRIDOR)
	if corridor <= 0.0 or corridor >= 1.0:
		errors.append("CROWD_CLEAR_CORRIDOR=%.2f вне (0,1)" % corridor)
	var solo_corridor := float(Balance.CROWD_CLEAR_SOLO_CORRIDOR)
	if solo_corridor <= 0.0 or solo_corridor >= 1.0:
		errors.append("CROWD_CLEAR_SOLO_CORRIDOR=%.2f вне (0,1)" % solo_corridor)
	# AoE-база осмысленно выше соло-базы (площадь vs одиночная цель).
	if float(Balance.BALANCE_BASE_AOE_DPS) <= float(Balance.BALANCE_BASE_SOLO_DPS):
		errors.append("BALANCE_BASE_AOE_DPS не выше BALANCE_BASE_SOLO_DPS")
