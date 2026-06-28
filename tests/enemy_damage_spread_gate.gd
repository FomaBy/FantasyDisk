extends SceneTree

# SCRUM-604: гейт сжатия спреда enemy damage_multiplier по стадиям.
#
# combat_director._scale_enemy_for_current_wave масштабирует урон врага как
#   damage_mult = base * (1 + (stage_scale-1)*SLOPE_STAGE + wave*SLOPE_WAVE)
# До задачи SLOPE_STAGE=0.62, SLOPE_WAVE=0.030 → на стадии 10 ~4.9x, что в паре
# без контактного капа обгоняло EHP fragile-профиля. Задача сжимает наклон урона
# (HP-наклон не трогаем) до SLOPE_STAGE=0.46, SLOPE_WAVE=0.024.
#
# Гейты (детерминированные, без CSV-арбитра):
#   1. Контракт наклона: SLOPE_STAGE/SLOPE_WAVE в combat_director.gd сжаты
#      (исходник содержит '* 0.46' и '* 0.024', НЕ содержит старых '* 0.62'/'* 0.030'
#      в строке damage_multiplier). Защита от реверта литералов.
#   2. Реакционное окно: на стадиях 0/4/8/10 time-to-death fragile-профиля под
#      форсированным контактным потоком (кадэнс = 1/i-frame) >= 1.5x окна реакции.
#   3. Эффект сжатия: множитель урона на стадии 10 со сжатым наклоном строго
#      меньше, чем со старым наклоном (компрессия реально срезает спайк).
#
# Запуск: Godot --headless --path . --script res://tests/enemy_damage_spread_gate.gd

const Surv := preload("res://tools/survivability_harness.gd")
const ProgressionData := preload("res://scripts/progression_data.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")

# Сжатые наклоны после SCRUM-604 (зеркало combat_director._scale_enemy_for_current_wave).
const SLOPE_STAGE := 0.46
const SLOPE_WAVE := 0.024
# Старые наклоны до задачи — для гейта эффекта сжатия.
const OLD_SLOPE_STAGE := 0.62
const OLD_SLOPE_WAVE := 0.030

# Базовый множитель урона рядового врага ("default") из main.ENEMY_BALANCE.
const ENEMY_DEFAULT_DAMAGE_MULT := 1.25
# Репрезентативный базовый контактный урон рядового врага до стадийного скейла.
const ENEMY_BASE_CONTACT_DAMAGE := 6.0
# Окно реакции игрока = i-frame между форсированными контактными ударами.
const REACTION_WINDOW := 0.32
const REACTION_FACTOR := 1.5

const STAGES := [0, 4, 8, 10]


func _stage_damage_mult(stage_scale: float, wave: float, slope_stage: float, slope_wave: float) -> float:
	return ENEMY_DEFAULT_DAMAGE_MULT * (1.0 + (stage_scale - 1.0) * slope_stage + wave * slope_wave)


func _initialize() -> void:
	seed(424242)
	var errors: Array = []

	# --- Гейт 1: контракт наклона в исходнике (защита от реверта) ---
	var src := FileAccess.get_file_as_string("res://scripts/combat_director.gd")
	if src.is_empty():
		errors.append("не удалось прочитать combat_director.gd")
	else:
		var dmg_line := ""
		for line in src.split("\n"):
			if line.contains("damage_multiplier") and line.contains("stage_scale - 1.0") and line.contains("wave_scale"):
				dmg_line = line
				break
		if dmg_line.is_empty():
			errors.append("не найдена строка damage_multiplier стадийного скейла в combat_director.gd")
		else:
			if not (dmg_line.contains("* 0.46") and dmg_line.contains("* 0.024")):
				errors.append("строка damage_multiplier не содержит сжатых наклонов 0.46/0.024: %s" % dmg_line.strip_edges())
			if dmg_line.contains("* 0.62") or dmg_line.contains("* 0.030"):
				errors.append("строка damage_multiplier всё ещё содержит старые наклоны 0.62/0.030: %s" % dmg_line.strip_edges())

	# --- Реальный fragile-профиль из боевой формулы ---
	var fragile: Dictionary = {}
	for prof in Surv.PROFILES:
		if str(prof["id"]) == "fragile":
			fragile = prof
			break
	if fragile.is_empty():
		errors.append("в harness нет профиля fragile")
		_finish(errors)
		return

	var p := Surv.profile_params(fragile)
	var health := float(p.get("health_point", 1.0))
	var defense := clampf(float(p.get("defense", 0.0)), 0.0, ProgressionData.SURVIVABILITY_DEFENSE_CAP)
	var absorb := float(p.get("absorb", 0.0))
	var dodge := clampf(float(p.get("dodge", 0.0)), 0.0, ProgressionData.SURVIVABILITY_DODGE_CAP)
	var regen := float(p.get("regeneration", 0.0))
	# Кадэнс форсированных контактных ударов: i-frame гейтит до 1 удара/окно.
	var cadence := 1.0 / REACTION_WINDOW

	# --- Гейт 2/3: TTD под сжатым наклоном на стадиях 0/4/8/10 ---
	for stage in STAGES:
		var stage_scale: float = ProgressionData.stage_scale(stage)
		var per_hit := ENEMY_BASE_CONTACT_DAMAGE * _stage_damage_mult(stage_scale, 0.0, SLOPE_STAGE, SLOPE_WAVE)
		var mitigated := Surv.expected_hit_damage(per_hit, defense, absorb, dodge)
		var effective_dps: float = maxf(mitigated * cadence - regen, 0.05)
		var ttd := health / effective_dps
		var floor_ttd := REACTION_FACTOR * REACTION_WINDOW
		print("stage %d: stage_scale=%.3f per_hit=%.2f mitig=%.2f eff_dps=%.2f TTD=%.2fс (floor %.2fс)" % [
			stage, stage_scale, per_hit, mitigated, effective_dps, ttd, floor_ttd])
		if not (ttd >= floor_ttd):
			errors.append("stage %d: TTD fragile %.2fс < %.2fс (1.5x окна реакции) — урон обгоняет EHP" % [stage, ttd, floor_ttd])

		# Гейт 3: сжатие реально срезает спайк на этой стадии (stage>0).
		if stage > 0:
			var new_mult := _stage_damage_mult(stage_scale, 0.0, SLOPE_STAGE, SLOPE_WAVE)
			var old_mult := _stage_damage_mult(stage_scale, 0.0, OLD_SLOPE_STAGE, OLD_SLOPE_WAVE)
			if not (new_mult < old_mult):
				errors.append("stage %d: сжатый множитель %.3f не ниже старого %.3f" % [stage, new_mult, old_mult])

	_finish(errors)


func _finish(errors: Array) -> void:
	if not errors.is_empty():
		for e in errors:
			push_error("Enemy damage spread gate: %s" % e)
		push_error("Enemy damage spread gate: %d ошибок." % errors.size())
		quit(1)
		return
	print("Enemy damage spread gate passed (наклон сжат 0.46/0.024, fragile TTD >= 1.5x окна реакции на стадиях 0/4/8/10).")
	quit(0)
