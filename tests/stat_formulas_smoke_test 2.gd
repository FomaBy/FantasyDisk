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
	_expect(errors, "physical_damage", SF.physical_damage(stats, 20.0, 0.0), 20.0)        # 20*10/10
	_expect(errors, "crit_chance", SF.crit_chance(stats, 0.05, 0.0), 0.10)                # 0.05+5/100
	_expect(errors, "crit_damage", SF.crit_damage_multiplier(stats, 2.0, 0.0), 1.5)       # 1+2*5/20
	_expect(errors, "attack_speed", SF.attack_speed(stats, 1.0, 0.0), 0.15)               # 1*3*5/100
	_expect(errors, "dodge", SF.dodge(stats, 0.1, 0.0), 0.05)                             # 0.1*5/10
	_expect(errors, "move_speed", SF.move_speed(300.0, stats, 0.0), 305.0)                # 300+5
	_expect(errors, "health_points", SF.health_points(stats, 100.0, 0.0), 200.0)         # 100*8/4
	_expect(errors, "attack_range", SF.attack_range(240.0, 10.0), 250.0)                  # 240+10

	# Монотонность по характеристике.
	var strong := {SF.STRENGTH: 20.0}
	if not (SF.physical_damage(strong, 20.0, 0.0) > SF.physical_damage(stats, 20.0, 0.0)):
		errors.append("physical_damage не растёт с силой")
	var nimble := {SF.AGILITY: 50.0}
	if not (SF.crit_chance(nimble, 0.05, 0.0) > SF.crit_chance(stats, 0.05, 0.0)):
		errors.append("crit_chance не растёт с ловкостью")
	var tanky := {SF.ENDURANCE: 16.0}
	if not (SF.health_points(tanky, 100.0, 0.0) > SF.health_points(stats, 100.0, 0.0)):
		errors.append("health_points не растёт с выносливостью")

	# Границы/клэмпы.
	var huge := {SF.AGILITY: 100000.0}
	if SF.crit_chance(huge, 0.05, 0.0) > 1.0 + EPS:
		errors.append("crit_chance не зажат в <= 1.0")
	if SF.dodge(huge, 0.1, 0.0) > 0.8 + EPS:
		errors.append("dodge не зажат в <= 0.8")
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
