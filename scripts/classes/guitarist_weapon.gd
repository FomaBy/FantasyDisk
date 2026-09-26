extends "res://scripts/classes/engineer_weapon.gd"

# FAN-3840: модуль распределённого боевого класса ClassWeapon — класс-локальные исполнители и приватные хелперы класса guitarist.
# Часть линейной extends-цепочки scripts/classes/** (сборка — фасад
# scripts/class_weapon.gd). Код перенесён из class_weapon.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в class_weapon_shared_api.gd.


func _exec_sound_wave(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_sound_wave(owner_node, direction)


func _exec_riff_strip(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_riff_strip(owner_node, direction)


func _exec_pulse(owner_node: Node2D, _target: Node2D, _direction: Vector2) -> void:
	_fire_pulse(owner_node, owner_node.global_position)


func _fire_sound_wave(owner_node: Node2D, direction: Vector2) -> void:
	var wave_visual := AttackVfx.sound_wave_blast(_projectile_parent(), owner_node.global_position + direction * 24.0, direction, attack_range, visual_color)
	_register_effect(wave_visual)
	var damage_value := _rolled_damage(owner_node)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		if not _is_enemy_inside_wave(owner_node.global_position, enemy_node.global_position, direction):
			continue
		_damage_enemy(enemy_node, damage_value)
		_push_enemy(enemy_node, direction)


# SCRUM-899: «рифф-полоса» Электрогитары — узкий передний коридор ПОСТОЯННОЙ
func _fire_riff_strip(owner_node: Node2D, direction: Vector2) -> void:
	var origin := owner_node.global_position
	var strip_visual := AttackVfx.beam(_projectile_parent(), origin + direction * 18.0, origin + direction * attack_range, maxf(wave_width, 24.0), visual_color)
	_register_effect(strip_visual)
	var damage_value := _rolled_damage(owner_node)
	var harmony_triggered := false
	for hit in _enemies_in_corridor(origin, direction, wave_width, attack_range):
		var enemy_node: Node2D = hit["node"]
		_damage_enemy(enemy_node, damage_value)
		_push_enemy(enemy_node, direction)
		var harmony := _constellation_event("hit", enemy_node, 0.0, {"now_msec": Time.get_ticks_msec(), "constellation_consumer_event": true})
		harmony_triggered = harmony_triggered or bool(harmony.get("triggered", false))
	if harmony_triggered:
		var perpendicular := Vector2(-direction.y, direction.x).normalized()
		var lane_origin := origin + perpendicular * maxf(wave_width * 0.65, 36.0)
		var lane_damage := damage_value * 0.38
		_register_effect(AttackVfx.beam(_projectile_parent(), lane_origin + direction * 18.0, lane_origin + direction * attack_range, maxf(wave_width * 0.72, 24.0), visual_color))
		for lane_hit in _enemies_in_corridor(lane_origin, direction, wave_width * 0.72, attack_range):
			_call_take_damage(lane_hit["node"], lane_damage, {"damage_type": _weapon_damage_type(), "constellation_final": "guitar_riff_harmony_lane"})


func _constellation_instrument_echo(owner_node: Node2D, origin: Vector2, result: Dictionary) -> void:
	var echo_damage := _rolled_damage(owner_node) * _constellation_result_param(result, "echo_damage_ratio", 0.30)
	var current_instrument := str(owner_node.get("weapon_id"))
	match current_instrument:
		"electric_guitar":
			var direction := _last_direction.normalized() if _last_direction.length_squared() > 0.001 else Vector2.RIGHT
			_register_effect(AttackVfx.beam(_projectile_parent(), origin + direction * 18.0, origin + direction * attack_range, maxf(wave_width, 24.0), visual_color))
			for hit in _enemies_in_corridor(origin, direction, wave_width, attack_range):
				_call_take_damage(hit["node"], echo_damage, {"damage_type": _weapon_damage_type(), "constellation_final": "amp_instrument_echo", "instrument": current_instrument})
		"bass_guitar", "sound_amp", "":
			_register_effect(AttackVfx.ring_pulse(_projectile_parent(), origin, aoe_radius, visual_color, false))
			for target in TARGET_QUERY.in_radius(self, origin, aoe_radius):
				_call_take_damage(target, echo_damage, {"damage_type": _weapon_damage_type(), "constellation_final": "amp_instrument_echo", "instrument": current_instrument if current_instrument != "" else "sound_amp"})
		_:
			return
