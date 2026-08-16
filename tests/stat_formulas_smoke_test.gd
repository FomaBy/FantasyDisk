extends SceneTree

# Smoke-тест stat_formulas.gd (был непокрыт). Чистая логика характеристик:
# STAT_DEFINITIONS (данные кодекса статов), формульные функции урона/крита/
# уворота/HP и форматирование значений. Детерминирован, без RNG.
# Отдельный изолированный файл.
#
# Запуск: Godot --headless --path . --script res://tests/stat_formulas_smoke_test.gd

const SF := preload("res://scripts/stat_formulas.gd")

const VALID_TYPES := ["base", "derived"]
const VALID_FORMATS := ["decimal", "integer", "plain", "percent", "percent_from_one", "multiplier", "per_second", "units"]
const EPS := 0.0001


func _initialize() -> void:
	var errors: Array = []

	_check_definitions(errors)
	_check_dependency_matrix(errors)
	_check_base_stats(errors)
	_check_formulas(errors)
	_check_formatting(errors)

	if not errors.is_empty():
		for e in errors:
			push_error("Stat formulas smoke: %s" % e)
		push_error("Stat formulas smoke test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Stat formulas smoke test passed (%d определений, %d базовых, %d производных)." % [
		SF.STAT_DEFINITIONS.size(), SF.BASE_STAT_ORDER.size(), SF.DERIVED_STAT_ORDER.size()])
	quit(0)


func _check_definitions(errors: Array) -> void:
	if SF.STAT_DEFINITIONS.size() < 8:
		errors.append("STAT_DEFINITIONS подозрительно мал (%d)" % SF.STAT_DEFINITIONS.size())
	for stat_id in SF.STAT_DEFINITIONS:
		var d: Dictionary = SF.STAT_DEFINITIONS[stat_id]
		for field in ["name_ru", "name_en", "type", "description", "format"]:
			if str(d.get(field, "")).strip_edges() == "":
				errors.append("определение '%s': пустое поле '%s'" % [stat_id, field])
		if not VALID_TYPES.has(str(d.get("type", ""))):
			errors.append("определение '%s': недопустимый type '%s'" % [stat_id, d.get("type", "")])
		if not VALID_FORMATS.has(str(d.get("format", ""))):
			errors.append("определение '%s': недопустимый format '%s'" % [stat_id, d.get("format", "")])
	# Покрытие: все статы порядка отображения определены.
	for stat_id in SF.BASE_STAT_ORDER:
		if not SF.STAT_DEFINITIONS.has(stat_id):
			errors.append("базовый стат '%s' без STAT_DEFINITIONS" % stat_id)
		elif str(SF.STAT_DEFINITIONS[stat_id].get("type", "")) != "base":
			errors.append("базовый стат '%s' имеет type != base" % stat_id)
	for stat_id in SF.DERIVED_STAT_ORDER:
		if not SF.STAT_DEFINITIONS.has(stat_id):
			errors.append("производный стат '%s' без STAT_DEFINITIONS" % stat_id)


func _check_dependency_matrix(errors: Array) -> void:
	if SF.DERIVED_BASE_DEPENDENCIES.size() != SF.DERIVED_STAT_ORDER.size():
		errors.append("DERIVED_BASE_DEPENDENCIES (%d) не покрывает все %d производных статов" % [SF.DERIVED_BASE_DEPENDENCIES.size(), SF.DERIVED_STAT_ORDER.size()])
	for derived_id_value in SF.DERIVED_STAT_ORDER:
		var derived_id := str(derived_id_value)
		if not SF.DERIVED_BASE_DEPENDENCIES.has(derived_id):
			errors.append("DERIVED_BASE_DEPENDENCIES без строки '%s'" % derived_id)
			continue
		var dependencies: Array = SF.DERIVED_BASE_DEPENDENCIES[derived_id]
		var seen := {}
		var previous_index := -1
		for base_id_value in dependencies:
			var base_id := str(base_id_value)
			var canonical_index := SF.BASE_STAT_ORDER.find(base_id)
			if canonical_index < 0:
				errors.append("dependency '%s' -> неизвестная базовая характеристика '%s'" % [derived_id, base_id])
			elif canonical_index <= previous_index:
				errors.append("dependency '%s' нарушает BASE_STAT_ORDER: %s" % [derived_id, str(dependencies)])
			previous_index = canonical_index
			if seen.has(base_id):
				errors.append("dependency '%s' дублирует '%s'" % [derived_id, base_id])
			seen[base_id] = true


func _check_base_stats(errors: Array) -> void:
	# Известный класс: все 8 базовых статов присутствуют.
	var berserk: Dictionary = SF.character_stats("berserk")
	for stat_id in SF.BASE_STAT_ORDER:
		if not berserk.has(stat_id):
			errors.append("character_stats('berserk') без стата '%s'" % stat_id)
	# Неизвестный класс -> дефолт берсерка (не пусто).
	var unknown: Dictionary = SF.character_stats("__nope__")
	if unknown.is_empty():
		errors.append("character_stats неизвестного класса вернул пусто")
	# Возвращается КОПИЯ: мутация не трогает источник.
	berserk[SF.STRENGTH] = 999.0
	if float(SF.character_stats("berserk").get(SF.STRENGTH, 0.0)) >= 999.0:
		errors.append("character_stats вернул ссылку, а не копию (мутация протекла)")
	# enemy_stats: известный + дефолт.
	if SF.enemy_stats("melee").is_empty():
		errors.append("enemy_stats('melee') пуст")
	if SF.enemy_stats("__nope__").is_empty():
		errors.append("enemy_stats неизвестного врага не дал дефолт")


func _check_formulas(errors: Array) -> void:
	var stats := {
		SF.STRENGTH: 10.0, SF.AGILITY: 5.0, SF.ENDURANCE: 8.0,
		SF.INTELLIGENCE: 4.0, SF.PERCEPTION: 5.0, SF.ENERGY: 4.0,
		SF.KNOWLEDGE: 4.0, SF.LEADERSHIP: 3.0,
	}
	# Точные значения формул.
	_expect(errors, "physical_damage", SF.physical_damage(stats, 20.0, 0.0), 20.0)        # Strength only: damage-channel isolation
	_expect(errors, "crit_chance", SF.crit_chance(stats, 0.05, 0.0), 0.0842)              # 0.05+5*0.0075 with diminishing returns
	_expect(errors, "crit_damage", SF.crit_damage_multiplier(stats, 2.0, 0.0), 1.575)     # 1.30+5*0.055
	_expect(errors, "attack_speed", SF.attack_speed(stats, 1.0, 0.0), 0.1962)             # 1*3*(Agi+Energy/Per/End support)/100
	_expect(errors, "dodge", SF.dodge(stats, 0.1, 0.0), 0.0473)                           # 0.1*5/10 with diminishing returns
	# SCRUM-877: мёртвый helper SF.move_speed() удалён (реальная формула живёт в
	# progression_data.gd::derived_stats). Контракт: отображаемая строка формулы
	# обязана называть реальные константы 282 и 6.2, а не легаси 245/5.5.
	var move_speed_formula := str(SF.STAT_DEFINITIONS.get("move_speed", {}).get("formula", ""))
	if not (move_speed_formula.contains("282") and move_speed_formula.contains("6.2")):
		errors.append("move_speed: отображаемая формула '%s' не совпадает с реальной (282 + Agility * 6.2)" % move_speed_formula)
	if move_speed_formula.contains("245") or move_speed_formula.contains("5.5"):
		errors.append("move_speed: отображаемая формула '%s' содержит легаси-константы 245/5.5" % move_speed_formula)
	_expect(errors, "health_points", SF.health_points(stats, 100.0, 0.0), 200.0)         # 100*8/4
	# FAN-1891: дальность цели config-only (weapon config -> derived passthrough);
	# формульного attack_range больше нет, и кодекс статов не должен его вернуть.
	if SF.STAT_DEFINITIONS.has("attack_range") or SF.DERIVED_STAT_ORDER.has("attack_range") or SF.DERIVED_BASE_DEPENDENCIES.has("attack_range"):
		errors.append("attack_range вернулся в кодекс статов: дальность цели остаётся config-only (FAN-1891)")

	# Монотонность по характеристике.
	var strong := {SF.STRENGTH: 20.0}
	if not (SF.physical_damage(strong, 20.0, 0.0) > SF.physical_damage(stats, 20.0, 0.0)):
		errors.append("physical_damage не растёт с силой")
	var foreign_stats := stats.duplicate(true)
	foreign_stats[SF.INTELLIGENCE] = 1000.0
	foreign_stats[SF.PERCEPTION] = 1000.0
	if absf(SF.physical_damage(foreign_stats, 20.0) - SF.physical_damage(stats, 20.0)) > EPS:
		errors.append("physical_damage зависит от чужих характеристик")
	var nimble := {SF.AGILITY: 50.0}
	if not (SF.crit_chance(nimble, 0.05, 0.0) > SF.crit_chance(stats, 0.05, 0.0)):
		errors.append("crit_chance не растёт с ловкостью")
	var tanky := {SF.ENDURANCE: 16.0}
	if not (SF.health_points(tanky, 100.0, 0.0) > SF.health_points(stats, 100.0, 0.0)):
		errors.append("health_points не растёт с выносливостью")

	# Границы/клэмпы.
	var huge := {SF.AGILITY: 100000.0}
	if SF.crit_chance(huge, 0.05, 0.0) > 0.75 + EPS:
		errors.append("crit_chance не зажат в <= 0.75")
	var tail := SF.crit_damage_multiplier({SF.AGILITY: 100.0}, 2.0, 4.0)
	if tail <= 2.75 or not is_finite(tail):
		errors.append("crit_damage не сохранил конечный неограниченный sqrt-tail выше 2.75")
	if SF.dodge(huge, 0.1, 0.0) > 0.55 + EPS:
		errors.append("dodge не зажат в <= 0.55")
	# attack_speed имеет пол 0.1 при нулевой ловкости.
	if absf(SF.attack_speed({SF.AGILITY: 0.0}, 1.0, 0.0) - 0.1) > EPS:
		errors.append("attack_speed не держит пол 0.1 при agility=0")


func _check_formatting(errors: Array) -> void:
	# null -> N/A для любого стата.
	if SF.format_stat_value(SF.STRENGTH, null) != "N/A":
		errors.append("format_stat_value(null) != 'N/A'")
	# plain (Сила): "5.0".
	if SF.format_stat_value(SF.STRENGTH, 5.0) != "5.0":
		errors.append("format_stat_value plain != '5.0' (%s)" % SF.format_stat_value(SF.STRENGTH, 5.0))

	# По одному стату на формат -> суффикс соответствует формату.
	var by_format := {}
	for stat_id in SF.STAT_DEFINITIONS:
		var fmt := str(SF.STAT_DEFINITIONS[stat_id].get("format", ""))
		if not by_format.has(fmt):
			by_format[fmt] = stat_id
	for fmt in by_format:
		var sid: String = str(by_format[fmt])
		var out := SF.format_stat_value(sid, 0.6)
		match fmt:
			"percent", "percent_from_one":
				if not out.ends_with("%"):
					errors.append("format '%s' (стат %s) -> '%s' без '%%'" % [fmt, sid, out])
			"multiplier":
				if not out.ends_with("x"):
					errors.append("format '%s' (стат %s) -> '%s' без 'x'" % [fmt, sid, out])
			"per_second":
				if not out.ends_with("/ sec"):
					errors.append("format '%s' (стат %s) -> '%s' без '/ sec'" % [fmt, sid, out])
			"integer", "units":
				if not out.is_valid_int():
					errors.append("format '%s' (стат %s) -> '%s' не целое" % [fmt, sid, out])
			_:
				if out.strip_edges() == "":
					errors.append("format '%s' (стат %s) -> пусто" % [fmt, sid])


func _expect(errors: Array, name: String, got: float, want: float) -> void:
	if absf(got - want) > EPS:
		errors.append("%s = %.4f, ожидалось %.4f" % [name, got, want])
