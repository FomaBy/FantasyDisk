extends SceneTree

# FAN-1031 Stage 3c-c — numeric down-tune перекормленных верхов (dark_mage,
# elementalist) + druid kit-rebuild (амулет вниз, briar/raven из мёртвых).
# Лёгкий детерминированный A/B-гейт: доказывает НАПРАВЛЕНИЕ правок формульно
# (без тяжёлого DPS-харнеса) и служит anti-silent-retune замком новых значений.
#
# Ключевой контракт (проверено пробой budget_tuning_for, см.
# build/stage3c_c_numeric_fan1031.md): живой per-hit direct-канала =
# damage_multiplier × budget_damage_multiplier, где budget_damage_multiplier
# авто-компенсирует damage_multiplier до формульной цели (solo_target/aoe_target
# × damage_budget) с клампом [0.28, 2.80]. Поэтому НУЖНЫЙ рычаг per-hit — сдвиг
# ЦЕЛИ профиля, а НЕ weapon.damage_multiplier. Гейт проверяет, что новый профиль
# даёт СТРОГО меньший эффективный per-hit, чем прежний (A/B по реальной формуле).
#
# Запуск: Godot --headless --path . --script res://tests/stage3c_c_numeric_gate.gd

const PD := preload("res://scripts/progression_data.gd")
const Bal := preload("res://scripts/progression_data_balance.gd")

const EPS := 0.0005


func _initialize() -> void:
	var errors: Array = []
	_check_profile_down_tune(errors)
	_check_cursed_skull(errors)
	_check_druid_rebuild(errors)

	if not errors.is_empty():
		for e in errors:
			push_error("Stage 3c-c numeric gate: %s" % e)
		push_error("Stage 3c-c numeric gate: %d ошибок." % errors.size())
		quit(1)
		return
	print("Stage 3c-c numeric gate passed (profile down-tune A/B, cursed_skull DoT, druid rebuild).")
	quit(0)


# Эффективный live per-hit множитель direct-канала при заданном профиле
# (реплика budget_tuning_for с явной подстановкой цели — для A/B «до/после»).
func _effective_multiplier(cid: String, cfg: Dictionary, solo_t: float, aoe_t: float, db: float) -> float:
	var base := PD.estimate_weapon_budget(cid, cfg, false)
	var sd: float = maxf(float(base.get("solo_dps", 0.0)), 0.001)
	var ad: float = maxf(float(base.get("aoe_dps", 0.0)), 0.001)
	var st: float = PD.BALANCE_BASE_SOLO_DPS * solo_t * db
	var at: float = PD.BALANCE_BASE_AOE_DPS * aoe_t * db
	var bdm: float = clampf(sqrt((st / sd) * (at / ad)), 0.28, 2.80)
	return float(cfg.get("damage_multiplier", 1.0)) * bdm


func _check_profile_down_tune(errors: Array) -> void:
	# Прежние (pre-3c-c) цели профиля — anti-silent-retune reference.
	var prev := {
		"dark_mage": {"solo": 0.84, "aoe": 1.30, "budget": 1.15},
		"elementalist": {"solo": 1.00, "aoe": 1.10, "budget": 1.08},
	}
	var probe_weapon := {"dark_mage": "dark_book", "elementalist": "elementalist_orb_ring"}
	for cid in prev.keys():
		var p: Dictionary = Bal.CLASS_BUDGET_PROFILES.get(cid, {})
		var now_budget := float(p.get("damage_budget", 1.0))
		var prev_budget := float(prev[cid]["budget"])
		if now_budget >= prev_budget - EPS:
			errors.append("%s: damage_budget не снижен (%.2f, было %.2f)" % [cid, now_budget, prev_budget])
		# A/B: эффективный per-hit direct-оружия строго ниже на НОВОМ профиле.
		var cfg: Dictionary = PD.WEAPONS_BY_CLASS.get(cid, {}).get(probe_weapon[cid], {}).duplicate(true)
		var eff_prev := _effective_multiplier(cid, cfg, float(prev[cid]["solo"]), float(prev[cid]["aoe"]), prev_budget)
		var eff_now := _effective_multiplier(cid, cfg, float(p.get("solo_target", 1.0)), float(p.get("aoe_target", 1.0)), now_budget)
		if eff_now >= eff_prev - EPS:
			errors.append("%s/%s: эффективный per-hit не снижен профилем (now %.3f vs prev %.3f)" % [cid, probe_weapon[cid], eff_now, eff_prev])


func _check_cursed_skull(errors: Array) -> void:
	# cursed_skull — curse_only: budget-direct его НЕ ведёт, единственный per-hit
	# рычаг DoT = curse_tick_multiplier. 0.58 → 0.36 (anti-silent-retune замок).
	var cfg: Dictionary = PD.WEAPONS_BY_CLASS.get("dark_mage", {}).get("cursed_skull", {})
	var m := float(cfg.get("curse_tick_multiplier", 1.0))
	if m >= 0.58 - EPS:
		errors.append("cursed_skull: curse_tick_multiplier не снижен (%.3f, было 0.58)" % m)
	if absf(m - 0.36) > EPS:
		errors.append("cursed_skull: curse_tick_multiplier ожидался 0.36 (got %.3f)" % m)
	# int-скейл проклятия оставлен нетронутым (identity «Интеллект кормит тьму»).
	if absf(float(cfg.get("curse_int_scale", 0.0)) - 0.08) > EPS:
		errors.append("cursed_skull: curse_int_scale должен остаться 0.08 (got %.3f)" % float(cfg.get("curse_int_scale", 0.0)))


func _check_druid_rebuild(errors: Array) -> void:
	var amulet: Dictionary = PD.WEAPONS_BY_CLASS.get("druid", {}).get("summon_amulet", {})
	var briar: Dictionary = PD.WEAPONS_BY_CLASS.get("druid", {}).get("briar_staff", {})
	var raven: Dictionary = PD.WEAPONS_BY_CLASS.get("druid", {}).get("raven_totem", {})
	# Амулет вниз (был 1.85 / 1.45).
	if float(amulet.get("summon_damage_multiplier", 1.85)) >= 1.85 - EPS:
		errors.append("summon_amulet: summon_damage_multiplier не снижен (%.3f)" % float(amulet.get("summon_damage_multiplier", 1.85)))
	if float(amulet.get("summon_role_damage_multiplier", 1.45)) >= 1.45 - EPS:
		errors.append("summon_amulet: summon_role_damage_multiplier не снижен (%.3f)" % float(amulet.get("summon_role_damage_multiplier", 1.45)))
	# briar из мёртвых (был 0.34 / cap 5).
	if float(briar.get("briar_hit_multiplier", 0.34)) <= 0.34 + EPS:
		errors.append("briar_staff: briar_hit_multiplier не поднят (%.3f)" % float(briar.get("briar_hit_multiplier", 0.34)))
	if int(briar.get("briar_hit_cap", 5)) < 6:
		errors.append("briar_staff: briar_hit_cap не поднят (%d)" % int(briar.get("briar_hit_cap", 5)))
	# raven из мёртвых (был 0.85, pulse 1.10).
	if float(raven.get("raven_damage_multiplier", 0.85)) <= 0.85 + EPS:
		errors.append("raven_totem: raven_damage_multiplier не поднят (%.3f)" % float(raven.get("raven_damage_multiplier", 0.85)))
	if float(raven.get("amp_pulse_interval", 1.10)) >= 1.10 - EPS:
		errors.append("raven_totem: amp_pulse_interval не ускорен (%.3f)" % float(raven.get("amp_pulse_interval", 1.10)))
