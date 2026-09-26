extends RefCounted

# FAN-3926 (agent-ready-refactor FD19): явный контекст исполнителей Солдата.
#
# Единственная дверь из scripts/classes/executors/soldier_executor.gd в общий
# кит ClassWeapon. Исполнитель не видит фасад, цепочку extends и TARGET_QUERY —
# только методы этого объекта. Каждый метод либо читает параметр оружия, либо
# пробрасывает вызов в один метод фасада; контекст не хранит копий состояния
# (единственное поле — `_weapon`) и не меняет порядок побочных эффектов.
#
# Отложенные шаги (взрыв пули, посадка/взрыв гранаты, контр-выстрел штыка)
# по-прежнему привязываются к МЕТОДАМ ФАСАДА по имени через `deferred()`:
# tween живёт на узле оружия, Callable + примитивные bind-аргументы (SCRUM-551),
# и внешние вызовы `weapon._explode_arquebus_bullet(...)` работают как раньше.
#
# Поверхность зависимостей ниже — измеряемый контракт шва: тест
# tests/balance/soldier/soldier_executor_composition_test.gd проверяет, что
# каждый член существует на фасаде и что исполнитель не вызывает на контексте
# ничего сверх объявленного здесь. Расширять списки — осознанное решение.

const CombatTargetQuery := preload("res://scripts/combat_target_query.gd")

# Параметры и runtime-состояние ClassWeapon, которые читает исполнитель.
const REQUIRED_WEAPON_PROPERTIES: Array[StringName] = [
	&"damage",
	&"attack_range",
	&"aoe_radius",
	&"damage_falloff",
	&"projectile_speed",
	&"grenade_delay",
	&"beam_width",
	&"visual_color",
	&"cone_degrees",
	&"bayonet_auto_shot_chance",
	&"bayonet_shot_range",
	&"bayonet_shot_damage_multiplier",
	&"_effects_shutdown",
	&"_constellation_local_state",
]

# Методы фасада, в которые контекст пробрасывает вызовы исполнителя.
const REQUIRED_WEAPON_METHODS: Array[StringName] = [
	&"_extra_projectiles",
	&"_find_closest_enemies",
	&"_enemies_in_corridor",
	&"_rolled_damage",
	&"_damage_enemy",
	&"_damage_enemies_in_circle_falloff",
	&"_call_take_damage",
	&"_weapon_damage_type",
	&"_push_enemy",
	&"_projectile_parent",
	&"_projectile_impact_color",
	&"_register_effect",
	&"_release_effect",
	&"_spawn_projectile_visual",
	&"create_tween",
	&"_owner_mod",
	&"_emit_weapon_animation_event",
	&"_constellation_event",
	&"_constellation_profile",
	&"_constellation_result_param",
]

# Точки входа фасада для отложенных шагов (bind по имени, см. `deferred()`).
const DEFERRED_FACADE_METHODS: Array[StringName] = [
	&"_explode_arquebus_bullet",
	&"_arm_grenade_fuse",
	&"_explode_grenade_fuse",
	&"_constellation_grenade_second_wave",
	&"_resolve_bayonet_brace_countershot",
]

# Контекст: инстанс фасада ClassWeapon (единственная ссылка, не копия состояния).
# Нетипизирован намеренно: типизация ClassWeapon из модуля его же extends-цепочки
# создала бы циклическую ссылку при загрузке скриптов.
var _weapon


func _init(weapon) -> void:
	_weapon = weapon


# Члены фасада, отсутствующие у `weapon`, — для контрактного теста шва.
static func missing_weapon_members(weapon: Object) -> Array[String]:
	var missing: Array[String] = []
	if weapon == null:
		missing.append("<null weapon>")
		return missing
	var property_names := {}
	for property in weapon.get_property_list():
		property_names[StringName(str(property.get("name", "")))] = true
	for property_name in REQUIRED_WEAPON_PROPERTIES:
		if not property_names.has(property_name):
			missing.append("property %s" % property_name)
	for method_name in REQUIRED_WEAPON_METHODS:
		if not weapon.has_method(method_name):
			missing.append("method %s" % method_name)
	for method_name in DEFERRED_FACADE_METHODS:
		if not weapon.has_method(method_name):
			missing.append("deferred %s" % method_name)
	return missing


# --- параметры оружия ---------------------------------------------------------


func damage() -> float:
	return _weapon.damage


func attack_range() -> float:
	return _weapon.attack_range


func aoe_radius() -> float:
	return _weapon.aoe_radius


func damage_falloff() -> float:
	return _weapon.damage_falloff


func projectile_speed() -> float:
	return _weapon.projectile_speed


func grenade_delay() -> float:
	return _weapon.grenade_delay


func beam_width() -> float:
	return _weapon.beam_width


func visual_color() -> Color:
	return _weapon.visual_color


func cone_degrees() -> float:
	return _weapon.cone_degrees


func bayonet_auto_shot_chance() -> float:
	return _weapon.bayonet_auto_shot_chance


func bayonet_shot_range() -> float:
	return _weapon.bayonet_shot_range


func bayonet_shot_damage_multiplier() -> float:
	return _weapon.bayonet_shot_damage_multiplier


# --- runtime-состояние оружия -------------------------------------------------


func effects_shutdown() -> bool:
	return _weapon._effects_shutdown


# Словарь состояния фасада по ссылке: исполнитель пишет в него на месте, как
# раньше писал сам модуль (cleanup_effects() чистит тот же объект).
func constellation_local_state() -> Dictionary:
	return _weapon._constellation_local_state


# --- выбор целей --------------------------------------------------------------


func extra_projectiles() -> int:
	return _weapon._extra_projectiles()


func find_closest_enemies(owner_node: Node2D, count: int) -> Array:
	return _weapon._find_closest_enemies(owner_node, count)


func enemies() -> Array[Node2D]:
	return CombatTargetQuery.enemies(_weapon)


func enemies_in_radius(center: Vector2, radius: float) -> Array:
	return CombatTargetQuery.in_radius(_weapon, center, radius)


func enemies_in_segment(start: Vector2, finish: Vector2, width: float) -> Array:
	return CombatTargetQuery.in_segment(_weapon, start, finish, width)


func enemies_in_corridor(origin: Vector2, direction: Vector2, width: float, range_limit: float) -> Array:
	return _weapon._enemies_in_corridor(origin, direction, width, range_limit)


# --- урон и смещение ----------------------------------------------------------


func rolled_damage(owner_node: Node2D) -> float:
	return _weapon._rolled_damage(owner_node)


func damage_enemy(enemy: Node, amount: float) -> void:
	_weapon._damage_enemy(enemy, amount)


func damage_enemies_in_circle_falloff(origin: Vector2, radius: float, amount: float, minimum_factor: float) -> void:
	_weapon._damage_enemies_in_circle_falloff(origin, radius, amount, minimum_factor)


func call_take_damage(enemy: Node, amount: float, feedback: Dictionary) -> void:
	_weapon._call_take_damage(enemy, amount, feedback)


func weapon_damage_type() -> String:
	return _weapon._weapon_damage_type()


func push_enemy(enemy: Node2D, direction: Vector2) -> void:
	_weapon._push_enemy(enemy, direction)


# --- визуал и реестр эффектов -------------------------------------------------


func projectile_parent() -> Node:
	return _weapon._projectile_parent()


func projectile_impact_color() -> Color:
	return _weapon._projectile_impact_color()


func register_effect(effect: Node) -> void:
	_weapon._register_effect(effect)


func release_effect(effect: Node) -> void:
	_weapon._release_effect(effect)


func spawn_projectile_visual(start: Vector2, travel_direction: Vector2) -> Node2D:
	return _weapon._spawn_projectile_visual(start, travel_direction)


# --- планирование -------------------------------------------------------------


# Tween принадлежит узлу оружия и гаснет вместе с ним — как раньше.
func create_tween() -> Tween:
	return _weapon.create_tween()


# Отложенный шаг разрешается на фасаде по имени (см. DEFERRED_FACADE_METHODS).
func deferred(method_name: StringName) -> Callable:
	return Callable(_weapon, method_name)


# --- владелец, анимация, созвездия --------------------------------------------


func owner_mod(key: String) -> float:
	return _weapon._owner_mod(key)


func emit_weapon_animation_event(owner_node: Node2D, phase: String, duration: float, direction: Vector2, metadata: Dictionary) -> void:
	_weapon._emit_weapon_animation_event(owner_node, phase, duration, direction, metadata)


func constellation_event(event: String, enemy: Node2D, base_damage: float, extra: Dictionary = {}) -> Dictionary:
	return _weapon._constellation_event(event, enemy, base_damage, extra)


func constellation_profile(mechanic_id: String) -> Dictionary:
	return _weapon._constellation_profile(mechanic_id)


func constellation_result_param(result: Dictionary, key: String, fallback: float) -> float:
	return _weapon._constellation_result_param(result, key, fallback)


# --- случайность --------------------------------------------------------------


# Единственный ролл исполнителя (шанс авто-выстрела штыка). Глобальный поток
# RNG и порядок вызовов те же, что до выноса.
func random_unit() -> float:
	return randf()
