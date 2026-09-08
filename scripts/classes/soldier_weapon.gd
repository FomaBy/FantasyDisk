extends "res://scripts/classes/sniper_weapon.gd"

# FAN-3840: модуль распределённого боевого класса ClassWeapon — класс-локальные исполнители и приватные хелперы класса soldier.
# Часть линейной extends-цепочки scripts/classes/** (сборка — фасад
# scripts/class_weapon.gd); кросс-модульные вызовы разрешаются виртуально через
# forward-объявления в class_weapon_shared_api.gd.
#
# FAN-3926 (agent-ready-refactor FD19): тела исполнителей Солдата живут в
# scripts/classes/executors/soldier_executor.gd и достают общий кит только через
# явный контекст scripts/classes/executors/soldier_context.gd. Этот модуль —
# стабильный фасад: прежние методы сохранены как тонкие делегаты (их зовут
# реестр ATTACK_MODE_EXECUTORS, отложенные tween-шаги по имени и внешние
# suites), сигнатуры и порядок побочных эффектов не изменились. Следующая
# соседняя правка Солдата делается в executors/ без касания siblings и
# shared API.

const SoldierContext := preload("res://scripts/classes/executors/soldier_context.gd")
const SoldierExecutor := preload("res://scripts/classes/executors/soldier_executor.gd")

# Ленивое создание: ClassWeapon — одна цепочка на все классы, исполнитель
# Солдата нужен только оружию Солдата. Тесты могут подменить слот целиком
# (исполнитель с другим контекстом) без правок этого модуля.
var _soldier_executor_instance = null


func _soldier_executor() -> SoldierExecutor:
	if _soldier_executor_instance == null:
		_soldier_executor_instance = SoldierExecutor.new(SoldierContext.new(self))
	return _soldier_executor_instance


func _exec_arquebus_shot(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_arquebus_shot(owner_node, target, direction)


func _exec_grenade_fuse(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_grenade_fuse(owner_node, target, direction)


func _exec_bayonet_cone(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_bayonet_cone(owner_node, direction)


# --- SCRUM-936 «Аркебуза» -----------------------------------------------------


func _fire_arquebus_shot(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_soldier_executor().fire_arquebus_shot(owner_node, target, direction)


func _launch_arquebus_bullet(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_soldier_executor().launch_arquebus_bullet(owner_node, target, direction)


# Отложенный шаг tween'а (bind по имени, SCRUM-551).
func _explode_arquebus_bullet(bullet_id: int, owner_id: int, center: Vector2, direction: Vector2) -> void:
	_soldier_executor().explode_arquebus_bullet(bullet_id, owner_id, center, direction)


# --- SCRUM-937 «Граната с фитилем» -------------------------------------------


func _fire_grenade_fuse(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_soldier_executor().fire_grenade_fuse(owner_node, target, direction)


# Отложенный шаг tween'а (bind по имени, SCRUM-551).
func _arm_grenade_fuse(owner_id: int, center: Vector2, blast_radius: float, direction: Vector2, fuse_delay: float) -> void:
	_soldier_executor().arm_grenade_fuse(owner_id, center, blast_radius, direction, fuse_delay)


# Отложенный шаг tween'а (bind по имени, SCRUM-551).
func _explode_grenade_fuse(grenade_id: int, telegraph_id: int, owner_id: int, center: Vector2, blast_radius: float, blast_damage_mult: float, direction: Vector2) -> void:
	_soldier_executor().explode_grenade_fuse(grenade_id, telegraph_id, owner_id, center, blast_radius, blast_damage_mult, direction)


# Отложенный шаг tween'а (bind по имени, SCRUM-551).
func _constellation_grenade_second_wave(center: Vector2, shard_damage: float, blast_radius: float) -> void:
	_soldier_executor().constellation_grenade_second_wave(center, shard_damage, blast_radius)


# --- SCRUM-938 «Штык-конус» ---------------------------------------------------


func _fire_bayonet_cone(owner_node: Node2D, direction: Vector2) -> void:
	_soldier_executor().fire_bayonet_cone(owner_node, direction)


# Отложенный шаг tween'а (bind по имени, SCRUM-551).
func _resolve_bayonet_brace_countershot(brace_token: int, origin: Vector2, target_id: int, base_damage: float) -> void:
	_soldier_executor().resolve_bayonet_brace_countershot(brace_token, origin, target_id, base_damage)


func _fire_bayonet_countershot_line(origin: Vector2, through_position: Vector2, counter_damage: float) -> void:
	_soldier_executor().fire_bayonet_countershot_line(origin, through_position, counter_damage)


func _is_enemy_inside_bayonet_cone(origin: Vector2, enemy_position: Vector2, direction: Vector2) -> bool:
	return _soldier_executor().is_enemy_inside_bayonet_cone(origin, enemy_position, direction)


func _fire_bayonet_auto_shot(owner_node: Node2D, direction: Vector2) -> void:
	_soldier_executor().fire_bayonet_auto_shot(owner_node, direction)


func _find_bayonet_shot_target(owner_node: Node2D) -> Node2D:
	return _soldier_executor().find_bayonet_shot_target(owner_node)
