extends "res://scripts/classes/class_weapon_state.gd"

# FAN-3840: модуль распределённого боевого класса ClassWeapon — автогенерируемые forward-объявления кросс-модульных методов (виртуальная диспетчеризация).
# Часть линейной extends-цепочки scripts/classes/** (сборка — фасад
# scripts/class_weapon.gd). Код перенесён из class_weapon.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в class_weapon_shared_api.gd.


func _alive_effects() -> Array[Node]:
	return []


func _amp_leadership_lifetime_bonus(owner_node: Node2D) -> float:
	return 0.0


func _amp_summon_haste_value(owner_node: Node2D) -> float:
	return 0.0


func _apply_constellation_prey_distribution(enemy: Node, owner_node: Node, amount: float, hit_type: String) -> void:
	pass


func _apply_constellation_symbiote_share(enemy: Node, owner_node: Node, amount: float, hit_type: String) -> void:
	pass


func _apply_ranger_bow_knockback(enemy: Node) -> void:
	pass


func _call_take_damage(enemy: Node, amount: float, feedback := {}) -> void:
	pass


func _capture_base_values() -> void:
	pass


func _charge_multiplier() -> float:
	return 0.0


func _constellation_event(event: String, enemy: Node2D = null, base_damage := 0.0, extra := {}) -> Dictionary:
	return {}


func _constellation_instrument_echo(owner_node: Node2D, origin: Vector2, result: Dictionary) -> void:
	pass


func _constellation_reliquary_expire(owner_node: Node2D, target: Node2D, center: Vector2, burst_base: float) -> Dictionary:
	return {}


func _constellation_result_param(result: Dictionary, key: String, fallback: float) -> float:
	return 0.0


func _constellation_transfer_skull_curse(dead_host: Node2D, payload: Dictionary) -> Dictionary:
	return {}


func _constellation_transfer_symbiote_host(enemy: Node, owner_node: Node) -> bool:
	return false


func _damage_enemies_in_circle(origin: Vector2, radius: float, amount: float) -> void:
	pass


func _damage_enemy(enemy: Node, amount: float, apply_unique_melee_effects := true, damage_type := "", notify_owner_hit := true) -> void:
	pass


func _damage_enemy_with_dot(enemy: Node, direct_damage: float, owner_node: Node2D) -> void:
	pass


func _deploy_visual_texture() -> Texture2D:
	return null


func _emit_weapon_animation_event(owner_node: Node2D, phase: String, duration: float, direction: Vector2, metadata := {}) -> void:
	pass


func _estimated_windup_duration() -> float:
	return 0.0


func _extra_projectiles() -> int:
	return 0


func _find_closest_enemy(owner_node: Node2D, range_limit := -1.0) -> Node2D:
	return null


func _find_combo_cloud(pool_position: Vector2) -> Node2D:
	return null


func _is_enemy_inside_wave(origin: Vector2, enemy_position: Vector2, direction: Vector2) -> bool:
	return false


func _launch_totem_raven(owner_node: Node2D, origin: Vector2, damage_scale := 1.0, support_seconds := 0.0) -> void:
	pass


func _nearest_enemies_from(origin: Vector2, range_limit: float, count: int, excluded_ids: Dictionary = {}) -> Array:
	return []


func _owner_node() -> CharacterBody2D:
	return null


func _owner_uses_cursor_aim(owner_node: Node) -> bool:
	return false


func _projectile_parent() -> Node:
	return null


func _push_enemy(enemy: Node2D, direction: Vector2) -> void:
	pass


func _register_effect(effect: Node) -> void:
	pass


func _release_effect(effect: Node) -> void:
	pass


func _retire_excess_damage_pools(new_pool: Node2D) -> void:
	pass


func _rolled_damage(owner_node: Node2D) -> float:
	return 0.0


func _spawn_projectile_visual(start: Vector2, travel_direction := Vector2.RIGHT) -> Node2D:
	return null


func _trigger_chemist_combo(new_cloud: Node2D, old_cloud: Node2D, tick_damage: float, direct_share := 1.0) -> void:
	pass


func _update_charge(delta: float) -> void:
	pass


func _volatile_powder_active() -> bool:
	return false


func _workshop_network_factor(owner_node: Node2D) -> float:
	return 0.0
