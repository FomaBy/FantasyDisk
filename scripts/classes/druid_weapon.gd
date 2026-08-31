extends "res://scripts/classes/doctor_weapon.gd"

# FAN-3840: модуль распределённого боевого класса ClassWeapon — класс-локальные исполнители и приватные хелперы класса druid.
# Часть линейной extends-цепочки scripts/classes/** (сборка — фасад
# scripts/class_weapon.gd). Код перенесён из class_weapon.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в class_weapon_shared_api.gd.


const RAVEN_EXPLOSION_TARGET_DIMINISH := 0.60


const RAVEN_CURVE_BEND := 0.38


var _raven_side_toggle := 1.0


func _launch_totem_raven(owner_node: Node2D, origin: Vector2, damage_scale := 1.0, support_seconds := 0.0) -> void:
	if _effects_shutdown or not is_inside_tree():
		return
	var target := TARGET_QUERY.nearest(self, origin, attack_range) as Node2D
	if target == null or not is_instance_valid(target):
		return
	var raven := _spawn_projectile_visual(origin + Vector2(0.0, -34.0), target.global_position - origin)
	_register_effect(raven)
	raven.set_meta("raven_last_target_position", target.global_position)
	raven.set_meta("constellation_damage_scale", clampf(damage_scale, 0.0, 1.0))
	raven.set_meta("constellation_support_seconds", maxf(support_seconds, 0.0))
	_raven_side_toggle = -_raven_side_toggle
	var travel_time := clampf(origin.distance_to(target.global_position) / maxf(projectile_speed, 120.0), 0.28, 0.75)
	var owner_id := owner_node.get_instance_id() if owner_node != null and is_instance_valid(owner_node) else 0
	var flight_tween := create_tween()
	flight_tween.tween_method(
		Callable(self, "_step_raven_flight").bind(raven.get_instance_id(), target.get_instance_id(), raven.global_position, _raven_side_toggle),
		0.0, 1.0, travel_time)
	flight_tween.tween_callback(Callable(self, "_resolve_raven_impact").bind(raven.get_instance_id(), owner_id))


func _step_raven_flight(progress: float, raven_id: int, target_id: int, start_position: Vector2, side_sign: float) -> void:
	var raven := instance_from_id(raven_id) as Node2D
	if raven == null or not is_instance_valid(raven):
		return
	var end_position: Vector2 = raven.get_meta("raven_last_target_position", start_position)
	var target := instance_from_id(target_id) as Node2D
	if target != null and is_instance_valid(target):
		end_position = target.global_position
		raven.set_meta("raven_last_target_position", end_position)
	var chord := end_position - start_position
	if chord.length_squared() < 1.0:
		raven.global_position = end_position
		return
	var control := (start_position + end_position) * 0.5 + Vector2(chord.y, -chord.x).normalized() * chord.length() * RAVEN_CURVE_BEND * side_sign
	raven.global_position = _quadratic_bezier_point(start_position, control, end_position, clampf(progress, 0.0, 1.0))


func _resolve_raven_impact(raven_id: int, owner_id: int) -> void:
	var raven := instance_from_id(raven_id) as Node2D
	if raven == null or not is_instance_valid(raven):
		return
	var impact_position := raven.global_position
	if _effects_shutdown or not is_inside_tree():
		_release_effect(raven)
		return
	var current_owner := instance_from_id(owner_id) as Node2D
	var explosion_damage := damage * raven_damage_multiplier
	if current_owner != null and is_instance_valid(current_owner):
		explosion_damage = _rolled_damage(current_owner) * raven_damage_multiplier
	explosion_damage *= float(raven.get_meta("constellation_damage_scale", 1.0))
	# SCRUM-961 «Голубой тотем» поверх SCRUM-903: вороны бьют злее (+25%).
	explosion_damage *= 1.0 + _owner_mod("raven_pulse_bonus")
	AttackVfx.orb_burst(_projectile_parent(), impact_position, raven_explosion_radius, _projectile_impact_color())
	_damage_enemies_in_circle_capped(impact_position, raven_explosion_radius, explosion_damage, RAVEN_EXPLOSION_FULL_TARGETS, RAVEN_EXPLOSION_TARGET_DIMINISH)
	for enemy in TARGET_QUERY.in_radius(self, impact_position, raven_explosion_radius):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var away := enemy_node.global_position - impact_position
		if away.length_squared() > 0.001:
			_push_enemy(enemy_node, away.normalized())
	var support_seconds := float(raven.get_meta("constellation_support_seconds", 0.0))
	if support_seconds > 0.0 and current_owner != null and current_owner.has_method("constellation_set_timed_absorb"):
		current_owner.call("constellation_set_timed_absorb", "raven_support_%d" % get_instance_id(), 2.0, support_seconds)
	_release_effect(raven)


# SCRUM-903: тик терновой зоны — контракт повторных ФИЗИЧЕСКИХ хитов:
func _briar_zone_tick(pool: Node2D) -> void:
	if pool == null or not is_instance_valid(pool):
		return
	var origin := pool.global_position
	var zone_radius := aoe_radius * 0.7
	var hit_counts: Dictionary = pool.get_meta("briar_hit_counts", {})
	var dwell: Dictionary = pool.get_meta("constellation_briar_dwell", {})
	var matured: Dictionary = pool.get_meta("constellation_briar_matured", {})
	var previous_inside: Dictionary = pool.get_meta("constellation_briar_inside", {})
	var last_positions: Dictionary = pool.get_meta("constellation_briar_positions", {})
	var current_inside := {}
	var slow_multiplier := briar_slow_multiplier
	var seal_power := _owner_mod("briar_slow_power")
	if seal_power > 0.0:
		slow_multiplier = minf(slow_multiplier, maxf(1.0 - seal_power, 0.25))
	var hit_damage := damage * briar_hit_multiplier
	for enemy in TARGET_QUERY.in_radius(self, origin, zone_radius):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		StatusEffects.apply_status(enemy_node, "briar_zone_slow", {
			"duration": maxf(pool_tick_interval * 1.6, 0.7),
			"speed_multiplier": slow_multiplier,
			"marker_color": Color(0.35, 0.70, 0.25, 1.0),
		})
		var enemy_id := enemy_node.get_instance_id()
		current_inside[enemy_id] = true
		last_positions[enemy_id] = enemy_node.global_position
		dwell[enemy_id] = float(dwell.get(enemy_id, 0.0)) + pool_tick_interval
		if float(dwell[enemy_id]) >= 1.2 and not bool(matured.get(enemy_id, false)):
			var root_result := _constellation_event("root_matured", enemy_node, 0.0)
			if bool(root_result.get("triggered", false)):
				matured[enemy_id] = true
				StatusEffects.apply_status(enemy_node, "constellation_briar_root", {"duration": 0.75, "speed_multiplier": 0.0, "movement_locked": true})
		var hits := int(hit_counts.get(enemy_id, 0))
		if hits >= briar_hit_cap:
			continue
		hit_counts[enemy_id] = hits + 1
		_damage_enemy(enemy_node, hit_damage, false, "physical", false)
	for previous_id in previous_inside.keys():
		if current_inside.has(previous_id):
			continue
		if bool(matured.get(previous_id, false)):
			var burst_center: Vector2 = last_positions.get(previous_id, origin)
			AttackVfx.orb_burst(_projectile_parent(), burst_center, zone_radius * 0.55, visual_color)
			for burst_target in TARGET_QUERY.in_radius(self, burst_center, zone_radius * 0.55):
				_call_take_damage(burst_target as Node, hit_damage * 0.38, {"damage_type": "physical", "constellation_final": "briar_sustained_root_burst"})
		matured.erase(previous_id)
		dwell.erase(previous_id)
		last_positions.erase(previous_id)
	pool.set_meta("briar_hit_counts", hit_counts)
	pool.set_meta("constellation_briar_dwell", dwell)
	pool.set_meta("constellation_briar_matured", matured)
	pool.set_meta("constellation_briar_inside", current_inside)
	pool.set_meta("constellation_briar_positions", last_positions)
