extends SceneTree

# SCRUM-524: атрибуты урона изолированы по типу. Гейт-инвариант: прокачка
# атрибута, владеющего типом урона X, меняет ТОЛЬКО урон типа X и НИКАК не влияет
# на остальные типы. Опирается на систему типов урона (SCRUM-523).
#
# Типы урона и их атрибуты-владельцы (см. derived_parameters в progression_data.gd):
#   физический  damage        ← сила (strength)
#   магический  magic_damage  ← интеллект (intelligence)
#   DoT         dot_damage    ← знание (knowledge)
#
# SCRUM-898: звуковой тип (sound_wave_damage ← восприятие+энергия) удалён.
# Восприятие и энергия больше НЕ владеют типом урона и проверяются как инертные.
#
# Чистая логика, без RNG. Отдельный изолированный файл.
# Запуск: Godot --headless --path . --script res://tests/damage_type_isolation_test.gd

const PD := preload("res://scripts/progression_data.gd")

const DAMAGE_TYPES := ["damage", "magic_damage", "dot_damage"]
const EPS := 0.0001

# Атрибут -> тип урона, которым он владеет. Прокачка атрибута обязана менять ТОЛЬКО
# этот тип и оставлять остальные без изменений.
const ATTRIBUTE_OWNS := {
	"strength": "damage",
	"intelligence": "magic_damage",
	"knowledge": "dot_damage",
}

# Базовые статы: все восемь атрибутов ненулевые, чтобы каждый тип урона имел
# измеримое значение и любой «протёкший» вклад был заметен.
const BASE_STATS := {
	"strength": 10.0, "agility": 7.0, "intelligence": 9.0, "perception": 8.0,
	"energy": 6.0, "knowledge": 7.0, "endurance": 8.0, "leadership": 5.0,
}

const BUMP := 25.0


func _initialize() -> void:
	var errors: Array = []

	_check_attribute_isolation(errors)
	_check_non_owner_attributes_inert(errors)
	_check_run_modifier_isolation(errors)
	_check_sound_axis_removed(errors)
	_check_ui_sound_axis_removed(errors)

	if not errors.is_empty():
		for e in errors:
			push_error("Damage type isolation: %s" % e)
		push_error("Damage type isolation test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Damage type isolation test passed (%d атрибут-владельцев, %d типов урона)." % [
		ATTRIBUTE_OWNS.size(), DAMAGE_TYPES.size()])
	quit(0)


func _damage_values(stats: Dictionary) -> Dictionary:
	# character_id опускаем (пустой weapon_config): без классового _scaled_stat_growth
	# и budget-множителя, чтобы мерить чистую формулу типов урона.
	var params := PD.derived_parameters(stats, {}, {})
	var out := {}
	for t in DAMAGE_TYPES:
		out[t] = float(params.get(t, 0.0))
	return out


func _check_attribute_isolation(errors: Array) -> void:
	var base_values := _damage_values(BASE_STATS)
	for attribute in ATTRIBUTE_OWNS:
		var owned_type: String = ATTRIBUTE_OWNS[attribute]
		var bumped: Dictionary = BASE_STATS.duplicate(true)
		bumped[attribute] = float(bumped[attribute]) + BUMP
		var bumped_values := _damage_values(bumped)
		# Свой тип обязан вырасти.
		if not (bumped_values[owned_type] > base_values[owned_type] + EPS):
			errors.append("прокачка '%s' не увеличила свой тип '%s' (%.4f -> %.4f)" % [
				attribute, owned_type, base_values[owned_type], bumped_values[owned_type]])
		# Все прочие типы обязаны остаться неизменными.
		for other_type in DAMAGE_TYPES:
			if other_type == owned_type:
				continue
			if absf(bumped_values[other_type] - base_values[other_type]) > EPS:
				errors.append("прокачка '%s' (тип '%s') протекла в чужой тип '%s' (%.4f -> %.4f)" % [
					attribute, owned_type, other_type,
					base_values[other_type], bumped_values[other_type]])


func _check_non_owner_attributes_inert(errors: Array) -> void:
	# Атрибуты, НЕ владеющие ни одним типом урона (ловкость, выносливость,
	# лидерство; после SCRUM-898 также восприятие и энергия), не должны менять
	# ни один тип урона.
	var base_values := _damage_values(BASE_STATS)
	for attribute in BASE_STATS:
		if ATTRIBUTE_OWNS.has(attribute):
			continue
		var bumped: Dictionary = BASE_STATS.duplicate(true)
		bumped[attribute] = float(bumped[attribute]) + BUMP
		var bumped_values := _damage_values(bumped)
		for t in DAMAGE_TYPES:
			if absf(bumped_values[t] - base_values[t]) > EPS:
				errors.append("неурочный атрибут '%s' изменил тип урона '%s' (%.4f -> %.4f)" % [
					attribute, t, base_values[t], bumped_values[t]])


func _damage_values_with_mods(run_modifiers: Dictionary) -> Dictionary:
	var params := PD.derived_parameters(BASE_STATS, run_modifiers, {})
	var out := {}
	for t in DAMAGE_TYPES:
		out[t] = float(params.get(t, 0.0))
	return out


func _check_sound_axis_removed(errors: Array) -> void:
	# SCRUM-898: derived_parameters больше не эмитит sound_wave_damage, а легаси
	# run-модификатор sound_damage_multiplier инертен для всех оставшихся типов.
	var params := PD.derived_parameters(BASE_STATS, {}, {})
	if params.has("sound_wave_damage"):
		errors.append("derived_parameters всё ещё отдаёт удалённый стат sound_wave_damage")
	var base_values := _damage_values_with_mods({})
	var legacy_values := _damage_values_with_mods({"sound_damage_multiplier": 1.5})
	for t in DAMAGE_TYPES:
		if absf(legacy_values[t] - base_values[t]) > EPS:
			errors.append("легаси sound_damage_multiplier изменил тип '%s' (%.4f -> %.4f)" % [
				t, base_values[t], legacy_values[t]])


func _check_ui_sound_axis_removed(errors: Array) -> void:
	# Acceptance contract SCRUM-898: the active UI source must not regain the
	# deleted derived-stat id. Build the marker in two pieces so repository search
	# continues to distinguish this guard from an active config reference.
	var ui_source := FileAccess.get_file_as_string("res://scripts/ui_screens.gd")
	if ui_source.is_empty():
		errors.append("не удалось прочитать scripts/ui_screens.gd для проверки удалённой оси")
		return
	var removed_parameter := "sound_wave" + "_damage"
	if ui_source.contains(removed_parameter):
		errors.append("scripts/ui_screens.gd всё ещё содержит удалённый стат")


func _check_run_modifier_isolation(errors: Array) -> void:
	var base_values := _damage_values_with_mods({})
	var modifier_owns := {
		"magic_damage_multiplier": "magic_damage",
	}
	for modifier_id in modifier_owns:
		var owned_type: String = modifier_owns[modifier_id]
		var modified_values := _damage_values_with_mods({modifier_id: 1.5})
		if not (modified_values[owned_type] > base_values[owned_type] + EPS):
			errors.append("модификатор '%s' не увеличил свой тип '%s' (%.4f -> %.4f)" % [
				modifier_id, owned_type, base_values[owned_type], modified_values[owned_type]])
		for other_type in DAMAGE_TYPES:
			if other_type == owned_type:
				continue
			if absf(modified_values[other_type] - base_values[other_type]) > EPS:
				errors.append("модификатор '%s' (тип '%s') протек в чужой тип '%s' (%.4f -> %.4f)" % [
					modifier_id, owned_type, other_type,
					base_values[other_type], modified_values[other_type]])
