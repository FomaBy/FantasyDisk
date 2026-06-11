class_name ClassWeapon
extends Node2D

const SOUND_AMP_TEXTURE := preload("res://assets/sprites/weapons/sound_amp.png")

@export var weapon_id := "dark_book"
@export var display_name := "Class Weapon"
@export var attack_mode := "aoe_projectile"
@export var damage_parameter := "damage"
@export var fire_interval := 0.8
@export var damage := 10.0
@export var attack_range := 520.0
@export var aoe_radius := 160.0
@export var projectile_speed := 520.0
@export var beam_width := 52.0
@export var wave_width := 220.0
@export var knockback := 80.0
@export var pierce_count := 4
@export var dot_ticks := 0
@export var beam_count := 1
@export var beam_fan_degrees := 12.0
@export var projectile_count := 1
@export var amp_lifetime := 7.0
@export var amp_pulse_interval := 1.1
@export var max_summons := 0
@export var heal_percent_on_attack := 0.0
@export var leaves_pool := false
@export var pool_duration := 3.0
@export var pool_tick_interval := 0.6
@export var visual_color := Color(0.5, 0.8, 1.0, 0.35)

var _cooldown := 0.0
var _last_direction := Vector2.RIGHT
var _deployed_amps: Array[Node] = []
var _spawned_effects: Array[Node] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("player_weapons")
	_capture_base_values()


func _exit_tree() -> void:
	cleanup_effects()


func cleanup_effects() -> void:
	# Самоочищающиеся VFX могли уже освободиться — отфильтровать мертвые ссылки.
	var tracked_effects := _alive_effects()
	_spawned_effects.clear()
	_deployed_amps.clear()
	for effect in tracked_effects:
		_release_effect(effect)


func configure_weapon(config: Dictionary) -> void:
	weapon_id = str(config.get("id", weapon_id))
	display_name = str(config.get("title", display_name))
	attack_mode = str(config.get("attack_mode", attack_mode))
	damage_parameter = str(config.get("damage_parameter", damage_parameter))
	fire_interval = float(config.get("fire_interval", fire_interval))
	damage *= float(config.get("damage_multiplier", 1.0))
	attack_range = float(config.get("attack_range", attack_range))
	aoe_radius = float(config.get("aoe_radius", aoe_radius))
	projectile_speed = float(config.get("projectile_speed", projectile_speed))
	beam_width = float(config.get("beam_width", beam_width))
	wave_width = float(config.get("wave_width", wave_width))
	knockback = float(config.get("knockback", knockback))
	pierce_count = int(config.get("pierce_count", pierce_count))
	dot_ticks = int(config.get("dot_ticks", dot_ticks))
	beam_count = int(config.get("beam_count", beam_count))
	beam_fan_degrees = float(config.get("beam_fan_degrees", beam_fan_degrees))
	projectile_count = int(config.get("projectile_count", projectile_count))
	amp_lifetime = float(config.get("amp_lifetime", amp_lifetime))
	amp_pulse_interval = float(config.get("amp_pulse_interval", amp_pulse_interval))
	max_summons = int(config.get("max_summons", max_summons))
	heal_percent_on_attack = float(config.get("heal_percent_on_attack", heal_percent_on_attack))
	leaves_pool = bool(config.get("leaves_pool", leaves_pool))
	pool_duration = float(config.get("pool_duration", pool_duration))
	pool_tick_interval = float(config.get("pool_tick_interval", pool_tick_interval))
	visual_color = config.get("visual_color", visual_color)
	_capture_base_values()


func _process(delta: float) -> void:
	# Направление атаки задает только ближайший враг; движение влияет
	# только на walk-анимацию персонажа.
	_cooldown -= delta
	if _cooldown > 0.0:
		return

	_attack()


func _attack() -> void:
	var owner_node := _owner_node()
	if owner_node == null:
		return

	var target := _find_closest_enemy(owner_node)
	var direction := _last_direction
	if target != null:
		direction = (target.global_position - owner_node.global_position).normalized()
	else:
		# Вне радиуса целимся в ближайшего врага на арене, чтобы удар не уходил «в никуда».
		var distant_enemy := _find_closest_enemy(owner_node, INF)
		if distant_enemy != null:
			direction = (distant_enemy.global_position - owner_node.global_position).normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	_last_direction = direction
	_cooldown = fire_interval

	if owner_node.has_method("play_action_animation"):
		owner_node.play_action_animation("cast" if attack_mode in ["aoe_projectile", "homing_curse", "beam"] else "shoot", direction)

	if heal_percent_on_attack > 0.0 and owner_node.has_method("heal_percent"):
		owner_node.heal_percent(heal_percent_on_attack)

	match attack_mode:
		"aoe_projectile":
			_fire_aoe_projectile(owner_node, target, direction)
		"boomerang":
			_fire_boomerang(owner_node, direction)
		"homing_curse":
			_fire_curse(owner_node, target, direction)
		"beam":
			_fire_beam(owner_node, direction)
		"sound_wave":
			_fire_sound_wave(owner_node, direction)
		"pulse":
			_fire_pulse(owner_node, owner_node.global_position)
		"amp":
			_fire_amp(owner_node, direction)
		_:
			_fire_sound_wave(owner_node, direction)


func _fire_aoe_projectile(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var targets := _find_closest_enemies(owner_node, maxi(projectile_count + _extra_projectiles(), 1))
	if targets.is_empty():
		_launch_aoe_projectile(owner_node, null, direction)
		return
	for target_node in targets:
		var to_target: Vector2 = target_node.global_position - owner_node.global_position
		var aim := direction if to_target.length_squared() <= 0.001 else to_target.normalized()
		_launch_aoe_projectile(owner_node, target_node, aim)


func _fire_boomerang(owner_node: Node2D, direction: Vector2) -> void:
	# Чакрамы: урон по коридору к цели сразу и повторно на «возврате» через 0.25с.
	var origin := owner_node.global_position
	_damage_enemies_in_corridor(origin, direction, _rolled_damage(owner_node))
	var orb := AttackVfx.orb_projectile(_projectile_parent(), origin + direction * 24.0, visual_color)
	_register_effect(orb)
	var far_point := origin + direction * attack_range
	var orb_tween := create_tween()
	orb_tween.tween_property(orb, "global_position", far_point, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	orb_tween.tween_property(orb, "global_position", origin, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	orb_tween.tween_callback(func() -> void:
		if is_instance_valid(self) and is_instance_valid(owner_node):
			_damage_enemies_in_corridor(owner_node.global_position, direction, _rolled_damage(owner_node))
		_release_effect(orb)
	)


func _damage_enemies_in_corridor(origin: Vector2, direction: Vector2, amount: float) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var to_enemy := enemy_node.global_position - origin
		var forward := to_enemy.dot(direction)
		if forward < 0.0 or forward > attack_range:
			continue
		var side: float = abs(to_enemy.dot(Vector2(-direction.y, direction.x)))
		if side <= beam_width * 0.5:
			_damage_enemy(enemy_node, amount)


func _spawn_damage_pool(pool_position: Vector2, tick_damage: float) -> void:
	# Ядовитое облако химика: тики по врагам в радиусе, группа player_weapon_effects.
	var pool := Node2D.new()
	pool.name = "ChemistPoisonPool"
	_register_effect(pool)
	pool.z_index = 5
	var visual := Polygon2D.new()
	visual.color = Color(visual_color.r, visual_color.g, visual_color.b, 0.30)
	var points := PackedVector2Array()
	for point_index in range(24):
		points.append(Vector2.RIGHT.rotated(TAU * float(point_index) / 24.0) * aoe_radius * 0.7)
	visual.polygon = points
	pool.add_child(visual)
	_projectile_parent().add_child(pool)
	pool.global_position = pool_position

	var tick_count := int(floor(pool_duration / maxf(pool_tick_interval, 0.2)))
	var pool_tween := pool.create_tween()
	for tick_index in range(tick_count):
		pool_tween.tween_interval(pool_tick_interval)
		pool_tween.tween_callback(func() -> void:
			if is_instance_valid(self):
				_damage_enemies_in_circle(pool.global_position, aoe_radius * 0.7, tick_damage)
		)
	pool_tween.tween_property(visual, "color:a", 0.0, 0.2)
	pool_tween.tween_callback(func() -> void:
		if is_instance_valid(self):
			_release_effect(pool)
		elif is_instance_valid(pool):
			pool.queue_free()
	)


func _find_closest_enemies(owner_node: Node2D, count: int) -> Array:
	var candidates := []
	var range_squared := attack_range * attack_range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var distance := owner_node.global_position.distance_squared_to(enemy_node.global_position)
		if distance <= range_squared:
			candidates.append({"node": enemy_node, "distance": distance})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distance"]) < float(b["distance"])
	)
	var result := []
	for candidate in candidates.slice(0, count):
		result.append(candidate["node"])
	return result


func _launch_aoe_projectile(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var target_position: Vector2 = owner_node.global_position + direction * min(attack_range, 360.0)
	if target != null:
		target_position = target.global_position

	var projectile := AttackVfx.orb_projectile(_projectile_parent(), owner_node.global_position + direction * 28.0, visual_color)
	_register_effect(projectile)

	var travel_time: float = clamp(projectile.global_position.distance_to(target_position) / max(projectile_speed, 1.0), 0.08, 0.45)
	var tween := create_tween()
	tween.tween_property(projectile, "global_position", target_position, travel_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		if is_instance_valid(self):
			var explosion_damage := damage if not is_instance_valid(owner_node) else _rolled_damage(owner_node)
			_damage_enemies_in_circle(target_position, aoe_radius, explosion_damage)
			AttackVfx.orb_burst(_projectile_parent(), target_position, aoe_radius, visual_color)
			if leaves_pool:
				var parameters_raw = owner_node.get("derived_parameters") if is_instance_valid(owner_node) else null
				var tick_damage := 2.0
				if parameters_raw is Dictionary:
					tick_damage = maxf(float((parameters_raw as Dictionary).get("dot_damage", 2.0)), 1.0)
				_spawn_damage_pool(target_position, tick_damage)
		_release_effect(projectile)
	)


func _fire_curse(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	if target == null:
		var miss_target: Vector2 = owner_node.global_position + direction * min(attack_range, 260.0)
		var miss_skull := AttackVfx.curse_skull(_projectile_parent(), owner_node.global_position + direction * 24.0, miss_target, visual_color, 0.22, Callable())
		_register_effect(miss_skull)
		return

	var target_position := target.global_position
	var rolled := _rolled_damage(owner_node)
	var skull := AttackVfx.curse_skull(_projectile_parent(), owner_node.global_position + direction * 24.0, target_position, visual_color, 0.20, func() -> void:
		if not is_instance_valid(self):
			return
		if is_instance_valid(target):
			_damage_enemy_with_dot(target, rolled, owner_node)
		if aoe_radius > 0.0:
			_damage_enemies_in_circle(target_position, aoe_radius * 0.72, rolled * 0.42)
			AttackVfx.orb_burst(_projectile_parent(), target_position, aoe_radius * 0.72, visual_color)
	)
	_register_effect(skull)


func _fire_beam(owner_node: Node2D, direction: Vector2) -> void:
	# Веер из beam_count лучей с шагом beam_fan_degrees, центрированный на цели.
	# «Ядро Расщепления» (tier 3): extra_projectile добавляет луч/снаряд.
	var count := maxi(beam_count + _extra_projectiles(), 1)
	for beam_index in range(count):
		var fan_offset := 0.0
		if count > 1:
			fan_offset = deg_to_rad(beam_fan_degrees) * (float(beam_index) - float(count - 1) * 0.5)
		_fire_single_beam(owner_node, direction.rotated(fan_offset))


func _fire_single_beam(owner_node: Node2D, direction: Vector2) -> void:
	var start := owner_node.global_position + direction * 26.0
	var finish := owner_node.global_position + direction * attack_range
	var beam_visual := AttackVfx.beam(_projectile_parent(), start, finish, beam_width, visual_color)
	_register_effect(beam_visual)

	var hits := []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var to_enemy := enemy_node.global_position - start
		var forward := to_enemy.dot(direction)
		if forward < 0.0 or forward > attack_range:
			continue
		var closest_point := start + direction * forward
		if enemy_node.global_position.distance_to(closest_point) <= beam_width * 0.5:
			hits.append({"node": enemy_node, "forward": forward})

	hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["forward"]) < float(b["forward"])
	)

	var damage_value := _rolled_damage(owner_node)
	var hit_count := 0
	for hit in hits:
		if hit_count >= pierce_count:
			break
		_damage_enemy(hit["node"], damage_value)
		hit_count += 1


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


func _fire_pulse(owner_node: Node2D, origin: Vector2) -> void:
	if owner_node == null or not is_instance_valid(owner_node):
		return
	_damage_enemies_in_circle(origin, aoe_radius, _rolled_damage(owner_node))
	var pulse_visual := AttackVfx.ring_pulse(_projectile_parent(), origin, aoe_radius, visual_color, attack_mode in ["pulse", "amp"])
	_register_effect(pulse_visual)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var away := enemy_node.global_position - origin
		if away.length_squared() > 0.001 and away.length() <= aoe_radius:
			_push_enemy(enemy_node, away.normalized())


func _fire_amp(owner_node: Node2D, direction: Vector2) -> void:
	# Деплой: усилитель ставится на землю, живет amp_lifetime секунд и пульсирует
	# самостоятельно. Лимит одновременных ампов растет от Лидерства через
	# max_summons (player._apply_weapon_scaling: base + floor(leadership / 4)).
	_deployed_amps = _deployed_amps.filter(func(amp: Node) -> bool:
		return amp != null and is_instance_valid(amp)
	)

	var amp := Node2D.new()
	amp.name = "SoundAmpPulseNode"
	amp.add_to_group("deployed_sound_amps")
	_register_effect(amp)
	amp.z_index = 5
	var amp_visual := Sprite2D.new()
	amp_visual.texture = SOUND_AMP_TEXTURE
	amp_visual.scale = Vector2(0.42, 0.42)
	amp.add_child(amp_visual)
	_projectile_parent().add_child(amp)
	amp.global_position = owner_node.global_position + direction * 92.0
	_deployed_amps.append(amp)

	var amp_limit := maxi(max_summons, 1)
	while _deployed_amps.size() > amp_limit:
		var oldest: Node = _deployed_amps.pop_front()
		_release_effect(oldest)

	var pulse_tween := amp.create_tween()
	var pulse_count := maxi(int(floor(amp_lifetime / maxf(amp_pulse_interval, 0.2))), 1)
	for pulse_index in range(pulse_count):
		pulse_tween.tween_interval(amp_pulse_interval)
		pulse_tween.tween_callback(func() -> void:
			if is_instance_valid(self):
				_fire_pulse(_owner_node(), amp.global_position)
		)
	pulse_tween.tween_callback(func() -> void:
		if is_instance_valid(self):
			_deployed_amps.erase(amp)
			_release_effect(amp)
		elif is_instance_valid(amp):
			amp.queue_free()
	)

	# Первый пульс сразу при установке.
	_fire_pulse(owner_node, amp.global_position)


func _extra_projectiles() -> int:
	var owner_node := _owner_node()
	if owner_node == null:
		return 0
	var mods = owner_node.get("run_modifiers")
	if not (mods is Dictionary):
		return 0
	return int(mods.get("extra_projectile", 0.0))


func _find_closest_enemy(owner_node: Node2D, range_limit := -1.0) -> Node2D:
	var closest_enemy: Node2D = null
	var closest_distance := attack_range * attack_range if range_limit < 0.0 else range_limit
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var distance := owner_node.global_position.distance_squared_to(enemy_node.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy_node
	return closest_enemy


func _is_enemy_inside_wave(origin: Vector2, enemy_position: Vector2, direction: Vector2) -> bool:
	var perpendicular := Vector2(-direction.y, direction.x)
	var to_enemy := enemy_position - origin
	var forward := to_enemy.dot(direction)
	if forward < 0.0 or forward > attack_range:
		return false
	var width_ratio: float = clamp(forward / max(attack_range, 1.0), 0.0, 1.0)
	var half_width := lerpf(58.0, wave_width * 0.5, width_ratio)
	return abs(to_enemy.dot(perpendicular)) <= half_width


func _damage_enemy(enemy: Node, amount: float) -> void:
	if enemy != null and is_instance_valid(enemy) and enemy.has_method("take_damage"):
		enemy.take_damage(amount)
		var owner_node := _owner_node()
		if owner_node != null and owner_node.has_method("on_weapon_hit"):
			owner_node.on_weapon_hit(enemy, amount)


func _damage_enemy_with_dot(enemy: Node, direct_damage: float, owner_node: Node2D) -> void:
	_damage_enemy(enemy, direct_damage)
	var parameters_raw = owner_node.get("derived_parameters")
	var parameters: Dictionary = parameters_raw if parameters_raw is Dictionary else {}
	var tick_damage := float(parameters.get("dot_damage", max(1.0, direct_damage * 0.22)))
	var tick_speed: float = max(float(parameters.get("dot_speed", 1.0)), 0.2)
	if dot_ticks <= 0:
		return
	# Tween на оружии замораживается паузой, в отличие от SceneTreeTimer.
	var dot_tween := create_tween()
	for tick_index in range(dot_ticks):
		dot_tween.tween_interval(1.0 / tick_speed)
		dot_tween.tween_callback(func() -> void:
			_damage_enemy(enemy, tick_damage)
		)


func _damage_enemies_in_circle(origin: Vector2, radius: float, amount: float) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		if origin.distance_squared_to(enemy_node.global_position) <= radius * radius:
			_damage_enemy(enemy_node, amount)


func _push_enemy(enemy: Node2D, direction: Vector2) -> void:
	if direction.length_squared() <= 0.001:
		return
	if enemy.has_method("apply_knockback"):
		enemy.apply_knockback(direction.normalized() * knockback * 3.6)
	else:
		enemy.global_position += direction.normalized() * knockback * 0.12


func _rolled_damage(owner_node: Node2D) -> float:
	var raw_parameters = owner_node.get("derived_parameters")
	if not (raw_parameters is Dictionary):
		return damage

	var parameters: Dictionary = raw_parameters
	var result := float(parameters.get(damage_parameter, damage))
	if randf() < float(parameters.get("crit_chance", 0.0)):
		result *= float(parameters.get("crit_damage_multiplier", 1.0))
	return result


func _owner_node() -> CharacterBody2D:
	var parent_node := get_parent()
	while parent_node != null:
		if parent_node is CharacterBody2D:
			return parent_node
		parent_node = parent_node.get_parent()
	return null


func _projectile_parent() -> Node:
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	return parent


func _register_effect(effect: Node) -> void:
	if effect == null:
		return
	effect.add_to_group("player_weapon_effects")
	_spawned_effects = _alive_effects()
	_spawned_effects.append(effect)


func _alive_effects() -> Array[Node]:
	var alive: Array[Node] = []
	for tracked in _spawned_effects:
		if tracked != null and is_instance_valid(tracked):
			alive.append(tracked)
	return alive


func _release_effect(effect: Node) -> void:
	if effect == null or not is_instance_valid(effect):
		return
	effect.remove_from_group("player_weapon_effects")
	_spawned_effects.erase(effect)
	effect.queue_free()


func _capture_base_values() -> void:
	if not has_meta("base_damage"):
		set_meta("base_damage", damage)
	if not has_meta("base_fire_interval"):
		set_meta("base_fire_interval", fire_interval)
	if not has_meta("base_attack_range"):
		set_meta("base_attack_range", attack_range)
	if not has_meta("base_aoe_radius"):
		set_meta("base_aoe_radius", aoe_radius)
	if not has_meta("base_projectile_speed"):
		set_meta("base_projectile_speed", projectile_speed)
	if not has_meta("base_beam_width"):
		set_meta("base_beam_width", beam_width)
	if not has_meta("base_wave_width"):
		set_meta("base_wave_width", wave_width)
	if not has_meta("base_knockback"):
		set_meta("base_knockback", knockback)
