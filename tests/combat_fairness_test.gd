extends SceneTree

# Combat Feel Rework, этап C: математический гейт «честных замахов» (CombatFairness).
#
# Контракты:
#  A. Пол замаха = (REACTION_FLOOR + escape/ESCAPE_SPEED_REF) × slow_comp и
#     ABS_MIN_WINDUP — держится для репрезентативных (base, escape, asc) комбо,
#     включая ascension 0.72 (boss_telegraph_mult L5): множитель сжимает ТОЛЬКО
#     выше пола, пробить пол не может.
#  B. Компенсация замедлений игрока капится SLOW_COMP_CAP (1.8); ускорение
#     игрока окно НЕ сжимает (кламп снизу 1.0).
#  C. ABS_MIN_WINDUP == 0.55 — абсолютный минимум любой зоны.
#  D. Data-скан: elite windup в progression_data_enemies ∈ [0.65, 0.9],
#     относительный порядок сохранён (plague — самый короткий, iron — самый длинный).
#  E. Пост-фазовые клампы кулдаунов босса ≥ 1.2s (и ≤ 1.8s).
#  F. Замахи рывков (boss/elite) ≥ REACTION_FLOOR; база вампирского укуса ≥ 0.6.
#  G. circle_escape_distance: центр на игроке → полный радиус; смещение → radius−dist;
#     игрок снаружи → 0.
#
# Запуск: python3 tools/godot_gate.py --headless --path . --script res://tests/combat_fairness_test.gd

const CombatFairnessScript := preload("res://scripts/combat_fairness.gd")
const EnemyData := preload("res://scripts/progression_data_enemies.gd")
const BossScript := preload("res://scripts/boss.gd")
const EnemyScript := preload("res://scripts/enemy.gd")

const EPS := 0.0001


class SpeedStub extends Node:
	var current := 250.0
	var base := 250.0

	func escape_speed() -> float:
		return current

	func base_escape_speed() -> float:
		return base


func _initialize() -> void:
	var errors: Array = []
	var reaction: float = CombatFairnessScript.REACTION_FLOOR
	var speed_ref: float = CombatFairnessScript.ESCAPE_SPEED_REF
	var abs_min: float = CombatFairnessScript.ABS_MIN_WINDUP

	# --- A. Пол держится на сетке комбо, включая ascension 0.72 ---
	for base in [0.42, 0.48, 0.55, 0.6, 0.65, 0.72, 0.78, 0.82]:
		for escape in [0.0, 18.0, 56.0, 79.2, 92.0, 156.0, 250.0, 320.0]:
			for asc in [1.0, 0.72]:
				var w: float = CombatFairnessScript.fair_windup(float(base), float(escape), float(asc))
				var floor_value: float = reaction + float(escape) / speed_ref
				if w + EPS < floor_value:
					errors.append("fair_windup(%.2f, %.1f, %.2f)=%.3f ниже пола %.3f" % [base, escape, asc, w, floor_value])
				if w + EPS < abs_min:
					errors.append("fair_windup(%.2f, %.1f, %.2f)=%.3f ниже ABS_MIN %.2f" % [base, escape, asc, w, abs_min])
	# Репрезентативные точки (руками): rift в игрока, sector ring, вампирский укус.
	if absf(CombatFairnessScript.fair_windup(0.65, 92.0, 1.0) - (reaction + 92.0 / speed_ref)) > EPS:
		errors.append("rift-кейс: ожидался пол 0.768")
	if absf(CombatFairnessScript.fair_windup(0.78, 250.0, 0.72) - (reaction + 250.0 / speed_ref)) > EPS:
		errors.append("sector-ring при asc 0.72 обязан упереться в пол 1.4")
	# Ascension сжимает ТОЛЬКО выше пола: 2.0×0.72=1.44 > пола → именно 1.44.
	if absf(CombatFairnessScript.fair_windup(2.0, 0.0, 0.72) - 1.44) > EPS:
		errors.append("ascension должен сжимать замах, пока тот выше пола (2.0×0.72=1.44)")

	# --- B. Slow-компенсация: кап 1.8, ускорение не сжимает ---
	var stub := SpeedStub.new()
	stub.base = 250.0
	stub.current = 100.0  # слоу ×2.5 → кап 1.8
	var slowed: float = CombatFairnessScript.fair_windup(0.5, 100.0, 1.0, stub)
	if absf(slowed - (reaction + 100.0 / speed_ref) * CombatFairnessScript.SLOW_COMP_CAP) > EPS:
		errors.append("slow-comp кап: ожидалось %.3f, получено %.3f" % [(reaction + 0.4) * 1.8, slowed])
	stub.current = 200.0  # слоу ×1.25 — без капа
	if absf(CombatFairnessScript.fair_windup(0.5, 100.0, 1.0, stub) - (reaction + 0.4) * 1.25) > EPS:
		errors.append("slow-comp 1.25 не применился")
	stub.current = 300.0  # ускоренный герой: comp клампится к 1.0 (окно не сжимается)
	if absf(CombatFairnessScript.fair_windup(0.5, 100.0, 1.0, stub) - (reaction + 0.4)) > EPS:
		errors.append("ускорение игрока не должно сжимать окно (comp < 1.0 запрещён)")
	stub.free()

	# --- C. Абсолютный минимум ---
	if absf(abs_min - 0.55) > EPS:
		errors.append("ABS_MIN_WINDUP обязан быть 0.55, получен %.2f" % abs_min)
	if absf(CombatFairnessScript.fair_windup(0.1, 0.0) - 0.55) > EPS:
		errors.append("нулевая зона с крошечной базой обязана дать ABS_MIN 0.55")

	# --- D. Data-скан элитных windup ---
	var configs: Dictionary = EnemyData.ELITE_ATTACK_CONFIGS
	for behavior in configs:
		var w_cfg := float((configs[behavior] as Dictionary).get("windup", 0.0))
		if w_cfg < 0.65 - EPS or w_cfg > 0.9 + EPS:
			errors.append("ELITE_ATTACK_CONFIGS['%s'].windup=%.2f вне [0.65, 0.9]" % [behavior, w_cfg])
	var w_plague := float((configs.get("plague_prophet", {}) as Dictionary).get("windup", 0.0))
	var w_night := float((configs.get("night_stalker", {}) as Dictionary).get("windup", 0.0))
	var w_iron := float((configs.get("iron_bastion", {}) as Dictionary).get("windup", 0.0))
	if not (w_plague <= w_night and w_night <= w_iron):
		errors.append("относительный порядок windup нарушен: plague %.2f / night %.2f / iron %.2f" % [w_plague, w_night, w_iron])

	# --- E. Пост-фазовые клампы кулдаунов босса ---
	var clamps: Dictionary = BossScript.PHASE_UP_COOLDOWN_CLAMPS
	if clamps.is_empty():
		errors.append("PHASE_UP_COOLDOWN_CLAMPS пуст")
	for key in clamps:
		var clamp_value := float(clamps[key])
		if clamp_value < 1.2 - EPS or clamp_value > 1.8 + EPS:
			errors.append("пост-фазовый кламп '%s'=%.2f вне [1.2, 1.8]" % [key, clamp_value])

	# --- F. Замахи рывков и укуса ---
	if float(BossScript.BOSS_DASH_WINDUP) < reaction - EPS:
		errors.append("BOSS_DASH_WINDUP %.2f ниже порога реакции" % float(BossScript.BOSS_DASH_WINDUP))
	if float(EnemyScript.ELITE_DASH_WINDUP) < reaction - EPS:
		errors.append("ELITE_DASH_WINDUP %.2f ниже порога реакции" % float(EnemyScript.ELITE_DASH_WINDUP))
	if float(BossScript.VAMPIRIC_BITE_BASE_WINDUP) < 0.6 - EPS:
		errors.append("база вампирского укуса обязана быть >= 0.6 (была 0.42)")

	# --- G. circle_escape_distance ---
	var anchor := Node2D.new()
	root.add_child(anchor)
	anchor.add_to_group("player")
	anchor.global_position = Vector2(1000.0, 800.0)
	if absf(CombatFairnessScript.circle_escape_distance(anchor.global_position, 92.0, anchor) - 92.0) > EPS:
		errors.append("центр на игроке обязан давать полный радиус")
	if absf(CombatFairnessScript.circle_escape_distance(anchor.global_position + Vector2(74.0, 0.0), 92.0, anchor) - 18.0) > EPS:
		errors.append("смещённая зона обязана давать radius - dist")
	if absf(CombatFairnessScript.circle_escape_distance(anchor.global_position + Vector2(400.0, 0.0), 92.0, anchor)) > EPS:
		errors.append("игрок снаружи зоны обязан давать 0 (пол держит окно)")
	if absf(CombatFairnessScript.circle_escape_distance(Vector2.ZERO, 92.0, null) - 92.0) > EPS:
		errors.append("без игрока обязан возвращаться полный радиус (консервативно)")
	anchor.queue_free()

	if not errors.is_empty():
		for e in errors:
			push_error("Combat fairness: %s" % e)
		push_error("Combat fairness test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Combat fairness math test passed: пол замаха, slow-comp кап, data-windup'ы и пост-фазовые клампы честны.")
	quit(0)
