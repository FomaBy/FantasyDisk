extends SceneTree

# SCRUM-600: гейт «boss остаётся апексом» — свести boss vs elite TTK.
#
# Проблема: ENEMY_BALANCE даёт elite hp_mult=4.6, boss=1.9, а run-скейл —
# elite (25.0 + scale*4.0) против boss (4.20 + scale*1.20): коэффициент элитки
# ~14x боссовского. Апексность боса держалась лишь на base max_health сцены
# (boss ~350 vs elite ~18.5). Задача поднимает boss-коэффициент HP в
# combat_director._scale_boss_for_run до (5.40 + scale*1.55), чтобы boss TTK
# был уверенно >= 1.35x elite TTK на всех стадиях. HP-коэффициент elite и
# ENEMY_BALANCE НЕ трогаем.
#
# Гейты (детерминированные, budget-модель из balance_harness, CSV не нужен):
#   1. Контракт коэффициента: combat_director._scale_boss_for_run И
#      balance_harness boss_ttk содержат '5.40'/'1.55', НЕ содержат старых
#      '4.20'/'1.20' (анти-реверт + кросс-файловая консистентность зеркал).
#   2. Апекс-полоса: на стадиях 0/2/4/6/8/10 boss TTK >= 1.35x elite TTK
#      (канонические репрезентативные базы harness: boss 350, elite 18.5).
#   3. Эффект подъёма: новый boss TTK строго > старого на каждой стадии.
#
# Запуск: Godot --headless --path . --script res://tests/boss_elite_ttk_gate.gd

const ProgressionData := preload("res://scripts/progression_data.gd")

# Зеркало combat_director._scale_boss_for_run (после SCRUM-600).
const BOSS_COEFF_BASE := 5.40
const BOSS_COEFF_SLOPE := 1.55
# Старые коэффициенты до задачи — для гейта эффекта.
const OLD_BOSS_COEFF_BASE := 4.20
const OLD_BOSS_COEFF_SLOPE := 1.20

# Репрезентативные базы из balance_harness._enemy_scaling_ttk_table.
const BOSS_BASE_HEALTH := 350.0
const ELITE_BASE_HEALTH := 18.5
const BOSS_HP_MULT := 1.9
const ELITE_HP_MULT := 4.6
# Run-скейл elite (НЕ трогаем): (25.0 + scale*4.0).
const ELITE_COEFF_BASE := 25.0
const ELITE_COEFF_SLOPE := 4.0

const APEX_FACTOR := 1.35
const STAGES := [0, 2, 4, 6, 8, 10]


func _elite_ehp(scale: float) -> float:
	return ELITE_BASE_HEALTH * ELITE_HP_MULT * (ELITE_COEFF_BASE + scale * ELITE_COEFF_SLOPE)


func _boss_ehp(scale: float, c0: float, c1: float) -> float:
	return BOSS_BASE_HEALTH * BOSS_HP_MULT * (c0 + scale * c1)


func _initialize() -> void:
	var errors: Array = []

	# --- Гейт 1: контракт коэффициента в обоих зеркалах ---
	_check_coeff_contract("res://scripts/combat_director.gd", "health_multiplier", errors)
	_check_coeff_contract("res://tools/balance_harness.gd", "boss_ttk", errors)

	# --- Гейт 2/3: апекс-полоса и эффект на стадиях ---
	# TTK ~ EHP при равном player DPS (DPS сокращается в отношении boss/elite).
	for stage in STAGES:
		var scale: float = ProgressionData.stage_scale(stage)
		var elite_ttk := _elite_ehp(scale)
		var boss_ttk := _boss_ehp(scale, BOSS_COEFF_BASE, BOSS_COEFF_SLOPE)
		var boss_ttk_old := _boss_ehp(scale, OLD_BOSS_COEFF_BASE, OLD_BOSS_COEFF_SLOPE)
		var ratio := boss_ttk / maxf(elite_ttk, 0.001)
		var floor_ratio := APEX_FACTOR
		print("stage %d: scale=%.3f elite_ttk=%.1f boss_ttk=%.1f (old %.1f) ratio=%.2fx (floor %.2fx)" % [
			stage, scale, elite_ttk, boss_ttk, boss_ttk_old, ratio, floor_ratio])
		if not (ratio >= floor_ratio):
			errors.append("stage %d: boss/elite TTK %.2fx < %.2fx — boss не апекс" % [stage, ratio, floor_ratio])
		if not (boss_ttk > boss_ttk_old):
			errors.append("stage %d: новый boss TTK %.1f не выше старого %.1f — подъём без эффекта" % [stage, boss_ttk, boss_ttk_old])

	_finish(errors)


func _check_coeff_contract(path: String, anchor: String, errors: Array) -> void:
	# Ищем строку boss run-скейла: содержит anchor (имя переменной множителя),
	# наклон по scale ('* 1.55' или старый '* 1.20') и оператор сложения базы.
	# Комментарии (#) пропускаем, чтобы пояснения не ловились как код.
	var src := FileAccess.get_file_as_string(path)
	if src.is_empty():
		errors.append("не удалось прочитать %s" % path)
		return
	var hit := ""
	for line in src.split("\n"):
		var stripped := line.strip_edges()
		if stripped.begins_with("#"):
			continue
		if not line.contains(anchor):
			continue
		var has_new_slope := line.contains("* 1.55")
		var has_old_slope := line.contains("* 1.20")
		if (has_new_slope or has_old_slope) and line.contains("+"):
			hit = line
			break
	if hit.is_empty():
		errors.append("%s: не найдена строка boss-коэффициента (anchor=%s)" % [path, anchor])
		return
	if not (hit.contains("5.40") and hit.contains("1.55")):
		errors.append("%s: boss-коэффициент не содержит 5.40/1.55: %s" % [path, hit.strip_edges()])
	if hit.contains("4.20") or hit.contains("* 1.20"):
		errors.append("%s: boss-коэффициент всё ещё содержит старые 4.20/1.20: %s" % [path, hit.strip_edges()])


func _finish(errors: Array) -> void:
	if not errors.is_empty():
		for e in errors:
			push_error("Boss/elite TTK gate: %s" % e)
		push_error("Boss/elite TTK gate: %d ошибок." % errors.size())
		quit(1)
		return
	print("Boss/elite TTK gate passed (boss-коэффициент 5.40/1.55, boss TTK >= 1.35x elite на стадиях 0/2/4/6/8/10).")
	quit(0)
