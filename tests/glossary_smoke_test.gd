extends SceneTree

# Smoke-тест glossary.gd. Глоссарий — справочные игровые термины для внутренних
# пояснений и cross-reference данных; с SCRUM-889 он больше не является live
# разделом игрового Кодекса. Поломка (пустой/битый термин, потерянный базовый
# стат) всё равно важна для data/helpers.
# Валидирует контент, аксессоры, защитную копию и
# кросс-ссылку: у каждого базового стата есть статья глоссария. Изолированный файл.
#
# Запуск: Godot --headless --path . --script res://tests/glossary_smoke_test.gd

const Glossary := preload("res://scripts/glossary.gd")
const StatFormulas := preload("res://scripts/stat_formulas.gd")


func _initialize() -> void:
	var errors: Array = []
	_check_terms(errors)
	_check_accessors(errors)
	_check_defensive_copy(errors)
	_check_base_stat_coverage(errors)

	if not errors.is_empty():
		for e in errors:
			push_error("Glossary smoke: %s" % e)
		push_error("Glossary smoke test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Glossary smoke test passed (%d терминов)." % Glossary.TERMS.size())
	quit(0)


func _player_text_ok(text: String) -> bool:
	var t := text.strip_edges()
	if t == "":
		return false
	var low := t.to_lower()
	if low == "null" or low.begins_with("res://"):
		return false
	if t.contains("SCRUM") or low.contains("todo") or low.contains("placeholder"):
		return false
	return true


func _check_terms(errors: Array) -> void:
	var terms: Dictionary = Glossary.TERMS
	if terms.size() < 8:
		errors.append("TERMS подозрительно мал (%d) — гейт прошёл бы вакуумно" % terms.size())
	var seen_names := {}
	for term_id in terms:
		var tid := str(term_id)
		if tid.strip_edges() == "":
			errors.append("пустой term_id")
			continue
		var entry: Dictionary = terms[term_id]
		var nm := str(entry.get("name", ""))
		var desc := str(entry.get("desc", ""))
		if not _player_text_ok(nm):
			errors.append("термин '%s': негодное name '%s'" % [tid, nm])
		if not _player_text_ok(desc):
			errors.append("термин '%s': негодное desc" % tid)
		if desc.strip_edges() == nm.strip_edges():
			errors.append("термин '%s': desc дублирует name" % tid)
		# Описание должно нести смысл, а не быть короче названия.
		if desc.strip_edges().length() <= nm.strip_edges().length():
			errors.append("термин '%s': desc не длиннее name (нет смысловой подсказки)" % tid)
		var name_key := nm.strip_edges().to_lower()
		if seen_names.has(name_key):
			errors.append("дублирующееся отображаемое имя '%s' (термины '%s' и '%s')" % [nm, seen_names[name_key], tid])
		else:
			seen_names[name_key] = tid


func _check_accessors(errors: Array) -> void:
	var ids := Glossary.term_ids()
	if ids.size() != Glossary.TERMS.size():
		errors.append("term_ids() (%d) != TERMS (%d)" % [ids.size(), Glossary.TERMS.size()])
	# term_ids() должен быть отсортирован (детерминированный порядок в кодексе).
	var sorted_copy := ids.duplicate()
	sorted_copy.sort()
	if ids != sorted_copy:
		errors.append("term_ids() не отсортирован")
	if ids.is_empty():
		errors.append("term_ids() пуст")
		return
	var first := str(ids[0])
	var def := Glossary.definition(first)
	if str(def.get("name", "")) == "" or str(def.get("desc", "")) == "":
		errors.append("definition('%s') не вернул name+desc" % first)
	if not Glossary.is_valid_term(first):
		errors.append("is_valid_term('%s') должно быть true" % first)
	# Неизвестный термин: definition -> {}, is_valid_term -> false, фолбэки.
	const NOPE := "__nonexistent_term__"
	if not Glossary.definition(NOPE).is_empty():
		errors.append("definition неизвестного термина вернул не-{}")
	if Glossary.is_valid_term(NOPE):
		errors.append("is_valid_term неизвестного термина вернул true")
	if Glossary.name(NOPE) != NOPE:
		errors.append("name() неизвестного термина должен фолбэчить на сам id")
	if Glossary.description(NOPE) != "":
		errors.append("description() неизвестного термина должен быть пуст")


# definition() обязан возвращать КОПИЮ — иначе вызывающий может испортить TERMS.
func _check_defensive_copy(errors: Array) -> void:
	var ids := Glossary.term_ids()
	if ids.is_empty():
		return
	var first := str(ids[0])
	var original_name := Glossary.name(first)
	var grabbed := Glossary.definition(first)
	grabbed["name"] = "__mutated__"
	if Glossary.name(first) != original_name:
		errors.append("definition() вернул ссылку на TERMS — мутация утекла (нужна копия)")


# Каждый базовый стат обязан иметь статью глоссария — иначе пустой тултип в UI.
func _check_base_stat_coverage(errors: Array) -> void:
	for stat_id in StatFormulas.BASE_STAT_ORDER:
		var sid := str(stat_id)
		if not Glossary.is_valid_term(sid):
			errors.append("базовый стат '%s' без валидной статьи глоссария" % sid)
