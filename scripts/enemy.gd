extends CharacterBody2D

signal died(enemy: Node2D)
# Фазы уникальной атаки элитки для Animator: windup -> strike -> recover -> idle.
signal elite_attack_phase_changed(attack_id: String, phase: String)

@export var enemy_type_name := "Basic"
@export var is_flying := false
@export var max_health := 3.0
@export var move_speed := 90.0
@export var can_shoot := false
@export var projectile_scene: PackedScene
@export var can_summon := false
@export var summoned_enemy_scene: PackedScene
@export var fire_interval := 1.5
@export var summon_interval := 3.4
@export var projectile_damage := 1.0
@export var projectile_speed := 360.0
@export var contact_damage := 1.0
@export var contact_range := 34.0
@export var contact_interval := 0.85
@export var contact_windup_time := 0.22
@export var desired_shooting_distance := 280.0
@export var desired_summoning_distance := 240.0
@export var max_active_summons := 4
@export var reward_xp := 1
@export var reward_money := 1
@export var elite_behavior := ""
@export var elite_shield_damage_reduction := 0.42
@export var elite_dash_speed_multiplier := 3.1
@export var elite_dash_duration := 0.34
@export var elite_hazard_damage := 2.0

var health := 0.0
var _shoot_cooldown := 0.0
var _summon_cooldown := 0.0
var _contact_cooldown := 0.0
var _contact_windup_left := -1.0
var _animation_time := 0.0
var _elite_shield_cooldown := 4.2
var _elite_shield_time_left := 0.0
var _elite_dash_cooldown := 2.8
var _elite_dash_time_left := 0.0
var _elite_dash_direction := Vector2.ZERO
var _elite_hazard_cooldown := 3.4
var _elite_aura_cooldown := 3.2
var _elite_shield_active := false
var _rig_source_scale := Vector2.ZERO
var _knockback_velocity := Vector2.ZERO
var _cached_player: Node2D = null
var _cached_body: Sprite2D = null
var _cached_rig: Node2D = null
var _cached_audio: Node = null
var elite_attack_state := "idle"
var elite_attack_id := ""
var _elite_attack_cooldown := 0.0
var _elite_attack_phase_left := 0.0
var _elite_attack_targets := []
var _elite_attack_direction := Vector2.RIGHT

const COLLISION_LAYER_PLAYER := 1
const COLLISION_LAYER_GROUND_ENEMY := 2
const COLLISION_LAYER_FLYING_ENEMY := 4
const COLLISION_LAYER_SOLID := 32
const ARENA_SIZE := Vector2(2560, 1440)
const ARENA_ENTITY_MARGIN := 48.0
const CUTOUT_RIG_SCRIPT := preload("res://scripts/cutout_rig_2d.gd")
const HEALTH_BAR_SCRIPT := preload("res://scripts/enemy_health_bar.gd")
const ENEMY_PROJECTILE_SCENE := preload("res://scenes/EnemyProjectile.tscn")
const ELITE_TELEGRAPH_TEXTURE := preload("res://assets/sprites/effects/elite_telegraph_circle.png")
const ELITE_SHOCKWAVE_TEXTURE := preload("res://assets/sprites/effects/elite_shockwave_ring.png")
const ELITE_SHADOW_TRAIL_TEXTURE := preload("res://assets/sprites/effects/elite_shadow_trail.png")
const ELITE_POISON_LOB_TEXTURE := preload("res://assets/sprites/effects/elite_poison_lob.png")
const ELITE_CRYSTAL_SHARD_TEXTURE := preload("res://assets/sprites/effects/elite_crystal_shard.png")

# Data-driven параметры уникальных атак элиток. Урон атаки считается как
# contact_damage * damage_factor и дополнительно ограничен 25% max HP игрока.
const ELITE_ATTACK_CONFIG := {
	"iron_bastion": {
		"attack_id": "slam_wave",
		"cooldown": 6.0, "windup": 0.6, "strike": 0.25, "recover": 0.5,
		"trigger_range": 340.0, "radius": 260.0,
		"damage_factor": 2.0, "knockback": 150.0,
	},
	"night_stalker": {
		"attack_id": "shadow_strike",
		"cooldown": 7.0, "windup": 0.5, "strike": 0.18, "recover": 0.45,
		"trigger_range": 540.0, "radius": 92.0,
		"damage_factor": 2.4, "behind_offset": 74.0,
	},
	"plague_prophet": {
		"attack_id": "poison_volley",
		"cooldown": 8.0, "windup": 0.45, "strike": 0.35, "recover": 0.5,
		"trigger_range": 560.0, "radius": 56.0,
		"damage_factor": 0.8, "lob_count": 3, "lob_spread": 130.0,
		"puddle_duration": 3.0, "tick_interval": 0.6, "lob_travel_time": 0.4,
	},
	"shard_marshal": {
		"attack_id": "shard_fan",
		"cooldown": 6.0, "windup": 0.5, "strike": 0.2, "recover": 0.4,
		"trigger_range": 620.0, "radius": 0.0,
		"damage_factor": 1.0, "shard_count": 5, "spread_degrees": 60.0,
		"shard_speed": 430.0,
	},
}
# Половина видимой ширины игрока: contact_range считается как сумма радиусов.
const PLAYER_CONTACT_PADDING := 26.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("enemies")
	_apply_collision_profile()
	health = max_health
	_shoot_cooldown = fire_interval
	_summon_cooldown = summon_interval
	if elite_behavior == "" and is_in_group("elite_enemies"):
		elite_behavior = enemy_type_name.to_lower().replace(" ", "_")
	if elite_behavior != "":
		set_meta("elite_behavior", elite_behavior)
	_configure_enemy_rig()
	_fit_contact_range_to_sprite()
	_create_health_bar()
	if ELITE_ATTACK_CONFIG.has(elite_behavior):
		elite_attack_id = str(ELITE_ATTACK_CONFIG[elite_behavior]["attack_id"])
		_elite_attack_cooldown = randf_range(2.2, 3.6)


func _apply_collision_profile() -> void:
	if is_flying:
		collision_layer = COLLISION_LAYER_FLYING_ENEMY
		collision_mask = COLLISION_LAYER_SOLID
		var body := get_node_or_null("Body") as Sprite2D
		if body != null:
			body.modulate = Color(0.72, 0.92, 1.0, 1.0)
	else:
		collision_layer = COLLISION_LAYER_GROUND_ENEMY
		collision_mask = COLLISION_LAYER_SOLID


func _physics_process(delta: float) -> void:
	var player := _player()
	if player == null:
		velocity = _consume_knockback(delta)
		move_and_slide()
		return

	var direction := player.global_position - global_position
	var distance := direction.length()

	if _update_elite_dash(delta, player, distance):
		move_and_slide()
		global_position = _clamp_to_arena(global_position)
		_update_movement_animation(delta)
		_update_contact_damage(delta, player, distance)
		return

	if _update_elite_attack(delta, player, distance):
		velocity = Vector2.ZERO
		move_and_slide()
		_update_movement_animation(delta)
		return

	if can_summon and distance < desired_summoning_distance * 0.85:
		velocity = -direction.normalized() * move_speed
	elif can_summon and distance <= desired_summoning_distance * 1.15:
		velocity = Vector2.ZERO
	elif can_shoot and distance < desired_shooting_distance * 0.85:
		velocity = -direction.normalized() * move_speed
	elif can_shoot and distance <= desired_shooting_distance:
		velocity = Vector2.ZERO
	elif direction.length_squared() > 0.0:
		velocity = direction.normalized() * move_speed
	else:
		velocity = Vector2.ZERO

	velocity += _consume_knockback(delta)
	move_and_slide()
	global_position = _clamp_to_arena(global_position)
	_update_movement_animation(delta)
	_update_contact_damage(delta, player, distance)
	_update_shooting(delta, player)
	_update_summoning(delta)
	_update_elite_patterns(delta, player, distance)


func take_damage(amount: float) -> void:
	var final_amount := amount
	if _elite_shield_active:
		final_amount *= elite_shield_damage_reduction
	health -= final_amount
	_update_health_bar()
	if is_inside_tree():
		if _cached_audio == null or not is_instance_valid(_cached_audio):
			_cached_audio = get_node_or_null("/root/AudioManager")
		if _cached_audio != null and _cached_audio.has_method("play_sfx"):
			_cached_audio.play_sfx("hit")
	var rig := _cutout_rig()
	if rig != null and rig.has_method("play_hit"):
		rig.play_hit()

	if health <= 0.0:
		if rig != null and rig.has_method("spawn_death_ghost"):
			rig.spawn_death_ghost()
		died.emit(self)
		queue_free()


func _update_elite_patterns(delta: float, player: Node2D, distance: float) -> void:
	if elite_behavior == "":
		return
	if elite_behavior.contains("armored") or elite_behavior.contains("bastion"):
		_update_elite_shield(delta)
	elif elite_behavior.contains("stalker"):
		_prepare_elite_dash(delta, player, distance)
	elif elite_behavior.contains("poison") or elite_behavior.contains("plague") or elite_behavior.contains("prophet"):
		_update_elite_hazard(delta, player)
	elif elite_behavior.contains("commander") or elite_behavior.contains("marshal"):
		_update_elite_aura(delta)


func _update_elite_shield(delta: float) -> void:
	if _elite_shield_time_left > 0.0:
		_elite_shield_time_left -= delta
		if _elite_shield_time_left <= 0.0:
			_elite_shield_active = false
			_elite_shield_cooldown = 5.4
			_set_body_tint(Color.WHITE)
		return

	_elite_shield_cooldown -= delta
	if _elite_shield_cooldown <= 0.0:
		_elite_shield_active = true
		_elite_shield_time_left = 1.8
		_set_body_tint(Color(0.62, 0.86, 1.0, 1.0))
		_play_rig_action("cast", Vector2.UP)


func _prepare_elite_dash(delta: float, player: Node2D, distance: float) -> void:
	_elite_dash_cooldown -= delta
	if _elite_dash_cooldown > 0.0 or distance < 80.0:
		return
	var direction := player.global_position - global_position
	if direction.length_squared() <= 0.0:
		return
	_elite_dash_direction = direction.normalized()
	_elite_dash_time_left = elite_dash_duration
	_elite_dash_cooldown = 4.2
	_set_body_tint(Color(1.0, 0.78, 0.36, 1.0))
	_play_rig_action("attack", _elite_dash_direction)


func _update_elite_dash(delta: float, _player: Node2D, _distance: float) -> bool:
	if _elite_dash_time_left <= 0.0:
		return false
	_elite_dash_time_left -= delta
	velocity = _elite_dash_direction * move_speed * elite_dash_speed_multiplier
	if _elite_dash_time_left <= 0.0:
		_set_body_tint(Color.WHITE)
	return true


func _update_elite_hazard(delta: float, player: Node2D) -> void:
	_elite_hazard_cooldown -= delta
	if _elite_hazard_cooldown > 0.0:
		return
	_play_rig_action("cast", player.global_position - global_position)
	_spawn_elite_hazard(player.global_position)
	_elite_hazard_cooldown = 4.6


func _spawn_elite_hazard(target_position: Vector2) -> void:
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	var hazard_damage := elite_hazard_damage
	var hazard := Node2D.new()
	hazard.name = "ElitePoisonZone"
	hazard.add_to_group("enemy_hazards")
	hazard.global_position = _clamp_to_arena(target_position, 92.0)
	hazard.z_index = 8
	parent.add_child(hazard)

	var warning := Polygon2D.new()
	warning.color = Color(0.45, 0.95, 0.18, 0.22)
	var points := PackedVector2Array()
	for point_index in range(28):
		points.append(Vector2.RIGHT.rotated(TAU * float(point_index) / 28.0) * 72.0)
	warning.polygon = points
	hazard.add_child(warning)

	# Tween на hazard замораживается вместе с паузой дерева, в отличие от SceneTreeTimer.
	var hazard_tween := hazard.create_tween()
	hazard_tween.tween_interval(0.55)
	hazard_tween.tween_callback(func() -> void:
		warning.color = Color(0.42, 0.85, 0.14, 0.48)
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null and player.global_position.distance_to(hazard.global_position) <= 72.0 and player.has_method("take_damage"):
			player.take_damage(hazard_damage, "poison_zone")
	)
	hazard_tween.tween_interval(1.45)
	hazard_tween.tween_callback(hazard.queue_free)


func _update_elite_aura(delta: float) -> void:
	_elite_aura_cooldown -= delta
	if _elite_aura_cooldown > 0.0:
		return
	_elite_aura_cooldown = 5.2
	_play_rig_action("cast", Vector2.UP)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_node := enemy as Node2D
		if enemy_node == null or enemy_node == self or enemy_node.is_in_group("elite_enemies"):
			continue
		if enemy_node.has_meta("commander_aura_buffed"):
			continue
		if enemy_node.global_position.distance_to(global_position) > 210.0:
			continue
		enemy_node.set_meta("commander_aura_buffed", true)
		if enemy_node.get("move_speed") != null:
			enemy_node.set("move_speed", float(enemy_node.get("move_speed")) * 1.08)
		if enemy_node.get("contact_damage") != null:
			enemy_node.set("contact_damage", float(enemy_node.get("contact_damage")) * 1.12)
		if enemy_node.has_method("_set_body_tint"):
			enemy_node._set_body_tint(Color(1.0, 0.86, 0.42, 1.0))


func _set_body_tint(color: Color) -> void:
	var body := get_node_or_null("Body") as Sprite2D
	if body == null:
		body = get_node_or_null("Sprite2D") as Sprite2D
	if body != null:
		body.modulate = color
	# Source-спрайт скрыт ригом, поэтому статусный цвет дублируется на видимый HeroFull.
	var rig := _cutout_rig()
	if rig != null and rig.has_method("set_status_tint"):
		rig.set_status_tint(color)


func _update_elite_attack(delta: float, player: Node2D, distance: float) -> bool:
	var config: Dictionary = ELITE_ATTACK_CONFIG.get(elite_behavior, {})
	if config.is_empty():
		return false

	if elite_attack_state == "idle":
		_elite_attack_cooldown -= delta
		if _elite_attack_cooldown > 0.0 or distance > float(config["trigger_range"]):
			return false
		_begin_elite_attack_windup(config, player)
		return true

	_elite_attack_phase_left -= delta
	if _elite_attack_phase_left > 0.0:
		return true

	match elite_attack_state:
		"windup":
			_execute_elite_strike(config, player)
			_set_elite_attack_phase("strike", float(config["strike"]))
		"strike":
			_set_elite_attack_phase("recover", float(config["recover"]))
			if elite_behavior == "night_stalker":
				_set_body_alpha(1.0)
		"recover":
			elite_attack_state = "idle"
			_elite_attack_cooldown = float(config["cooldown"])
			elite_attack_phase_changed.emit(elite_attack_id, "idle")
			set_meta("elite_attack_phase", "idle")
	return elite_attack_state != "idle"


func _set_elite_attack_phase(phase: String, duration: float) -> void:
	elite_attack_state = phase
	_elite_attack_phase_left = duration
	set_meta("elite_attack_phase", phase)
	elite_attack_phase_changed.emit(elite_attack_id, phase)


func _begin_elite_attack_windup(config: Dictionary, player: Node2D) -> void:
	_elite_attack_targets.clear()
	_set_elite_attack_phase("windup", float(config["windup"]))
	var to_player := player.global_position - global_position
	if to_player.length_squared() > 0.001:
		_elite_attack_direction = to_player.normalized()

	match elite_behavior:
		"iron_bastion":
			_play_rig_action("attack", _elite_attack_direction)
			_spawn_elite_telegraph(global_position, float(config["radius"]), float(config["windup"]))
		"night_stalker":
			_play_rig_action("cast", _elite_attack_direction)
			var behind := player.global_position + _elite_attack_direction * float(config["behind_offset"])
			_elite_attack_targets.append(_clamp_to_arena(behind))
			_spawn_elite_telegraph(_elite_attack_targets[0], float(config["radius"]), float(config["windup"]))
			_set_body_alpha(0.25)
			_spawn_shadow_trail(global_position, _elite_attack_targets[0], float(config["windup"]))
		"plague_prophet":
			_play_rig_action("cast", _elite_attack_direction)
			var spread := float(config["lob_spread"])
			for lob_index in range(int(config["lob_count"])):
				var offset := Vector2.ZERO
				if lob_index > 0:
					offset = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(spread * 0.35, spread)
				var target := _clamp_to_arena(player.global_position + offset, 92.0)
				_elite_attack_targets.append(target)
				_spawn_elite_telegraph(target, float(config["radius"]), float(config["windup"]) + float(config["lob_travel_time"]))
		"shard_marshal":
			_play_rig_action("shoot", _elite_attack_direction)
			_spawn_elite_telegraph(global_position + _elite_attack_direction * 120.0, 64.0, float(config["windup"]))


func _execute_elite_strike(config: Dictionary, player: Node2D) -> void:
	match elite_behavior:
		"iron_bastion":
			_strike_slam_wave(config, player)
		"night_stalker":
			_strike_shadow_strike(config, player)
		"plague_prophet":
			_strike_poison_volley(config, player)
		"shard_marshal":
			_strike_shard_fan(config, player)


func _elite_attack_damage(config: Dictionary, player: Node2D) -> float:
	var damage := contact_damage * float(config["damage_factor"])
	var player_max_health := float(player.get("max_health")) if player.get("max_health") != null else 0.0
	if player_max_health > 0.0:
		damage = minf(damage, player_max_health * 0.25)
	return damage


func _strike_slam_wave(config: Dictionary, player: Node2D) -> void:
	var radius := float(config["radius"])
	_spawn_shockwave_ring(global_position, radius)
	if player.global_position.distance_to(global_position) > radius:
		return
	if player.has_method("take_damage") and player.take_damage(_elite_attack_damage(config, player), "elite_slam_wave"):
		var push_direction := (player.global_position - global_position).normalized()
		if push_direction.length_squared() <= 0.001:
			push_direction = Vector2.RIGHT
		player.global_position = _clamp_to_arena(player.global_position + push_direction * float(config["knockback"]))


func _strike_shadow_strike(config: Dictionary, player: Node2D) -> void:
	if _elite_attack_targets.is_empty():
		return
	var strike_position: Vector2 = _elite_attack_targets[0]
	_spawn_shadow_trail(global_position, strike_position, 0.22)
	global_position = strike_position
	_set_body_alpha(1.0)
	_play_rig_action("attack", player.global_position - global_position)
	if player.global_position.distance_to(global_position) <= float(config["radius"]):
		if player.has_method("take_damage"):
			player.take_damage(_elite_attack_damage(config, player), "elite_shadow_strike")


func _strike_poison_volley(config: Dictionary, player: Node2D) -> void:
	var damage := _elite_attack_damage(config, player)
	for target in _elite_attack_targets:
		_spawn_poison_lob(target, float(config["lob_travel_time"]), damage, config)


func _strike_shard_fan(config: Dictionary, player: Node2D) -> void:
	var shard_count := int(config["shard_count"])
	var spread := deg_to_rad(float(config["spread_degrees"]))
	var damage := _elite_attack_damage(config, player)
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	for shard_index in range(shard_count):
		var t := 0.0 if shard_count == 1 else float(shard_index) / float(shard_count - 1)
		var angle := lerpf(-spread * 0.5, spread * 0.5, t)
		var direction := _elite_attack_direction.rotated(angle)
		var projectile := ENEMY_PROJECTILE_SCENE.instantiate()
		parent.add_child(projectile)
		var shard_sprite := projectile.get_node_or_null("Sprite2D") as Sprite2D
		if shard_sprite == null:
			shard_sprite = projectile.get_node_or_null("Body") as Sprite2D
		if shard_sprite != null:
			shard_sprite.texture = ELITE_CRYSTAL_SHARD_TEXTURE
			shard_sprite.rotation = direction.angle()
		if projectile.has_method("setup"):
			projectile.setup(global_position, global_position + direction * 200.0, damage, float(config["shard_speed"]))


func _spawn_elite_telegraph(target_position: Vector2, radius: float, duration: float) -> void:
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	var telegraph := Node2D.new()
	telegraph.name = "EliteAttackTelegraph"
	telegraph.add_to_group("enemy_hazards")
	telegraph.z_index = 7
	parent.add_child(telegraph)
	telegraph.global_position = target_position

	var sprite := Sprite2D.new()
	sprite.texture = ELITE_TELEGRAPH_TEXTURE
	var texture_radius: float = maxf(ELITE_TELEGRAPH_TEXTURE.get_size().x * 0.5, 1.0)
	var target_scale := maxf(radius, 32.0) / texture_radius
	sprite.scale = Vector2(target_scale, target_scale) * 0.4
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
	telegraph.add_child(sprite)

	var tween := telegraph.create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2(target_scale, target_scale), minf(duration * 0.5, 0.3)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate:a", 0.85, minf(duration * 0.4, 0.22))
	tween.chain().tween_interval(maxf(duration - 0.3, 0.05))
	tween.chain().tween_property(sprite, "modulate:a", 0.0, 0.12)
	tween.chain().tween_callback(telegraph.queue_free)


func _spawn_shockwave_ring(origin: Vector2, radius: float) -> void:
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	var ring := Node2D.new()
	ring.name = "EliteShockwave"
	ring.add_to_group("enemy_hazards")
	ring.z_index = 9
	parent.add_child(ring)
	ring.global_position = origin
	var sprite := Sprite2D.new()
	sprite.texture = ELITE_SHOCKWAVE_TEXTURE
	var texture_radius: float = maxf(ELITE_SHOCKWAVE_TEXTURE.get_size().x * 0.5, 1.0)
	sprite.scale = Vector2.ONE * 0.2
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.95)
	ring.add_child(sprite)
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2.ONE * (radius / texture_radius), 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.34)
	tween.chain().tween_callback(ring.queue_free)


func _spawn_shadow_trail(from_position: Vector2, to_position: Vector2, duration: float) -> void:
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	var trail := Node2D.new()
	trail.name = "EliteShadowTrail"
	trail.add_to_group("enemy_hazards")
	trail.z_index = 6
	parent.add_child(trail)
	trail.global_position = (from_position + to_position) * 0.5
	var sprite := Sprite2D.new()
	sprite.texture = ELITE_SHADOW_TRAIL_TEXTURE
	var delta := to_position - from_position
	sprite.rotation = delta.angle()
	var texture_length: float = maxf(ELITE_SHADOW_TRAIL_TEXTURE.get_size().x, 1.0)
	sprite.scale = Vector2(delta.length() / texture_length, 0.8)
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.65)
	trail.add_child(sprite)
	var tween := trail.create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, maxf(duration, 0.15))
	tween.tween_callback(trail.queue_free)


func _spawn_poison_lob(target_position: Vector2, travel_time: float, damage: float, config: Dictionary) -> void:
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	var lob := Node2D.new()
	lob.name = "ElitePoisonLob"
	lob.add_to_group("enemy_hazards")
	lob.z_index = 12
	parent.add_child(lob)
	lob.global_position = global_position
	var sprite := Sprite2D.new()
	sprite.texture = ELITE_POISON_LOB_TEXTURE
	sprite.scale = Vector2(0.5, 0.5)
	lob.add_child(sprite)
	var tween := lob.create_tween()
	tween.set_parallel(true)
	tween.tween_property(lob, "global_position", target_position, travel_time).set_trans(Tween.TRANS_LINEAR)
	# Имитация дуги: спрайт поднимается и опускается во время полета.
	tween.tween_property(sprite, "position", Vector2(0.0, -64.0), travel_time * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(sprite, "position", Vector2.ZERO, travel_time * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func() -> void:
		_spawn_poison_puddle(target_position, damage, config)
		lob.queue_free()
	)


func _spawn_poison_puddle(puddle_position: Vector2, tick_damage: float, config: Dictionary) -> void:
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	var puddle := Node2D.new()
	puddle.name = "ElitePoisonPuddle"
	puddle.add_to_group("enemy_hazards")
	puddle.z_index = 5
	parent.add_child(puddle)
	puddle.global_position = puddle_position
	var radius := float(config["radius"])

	var visual := Polygon2D.new()
	visual.color = Color(0.42, 0.85, 0.16, 0.42)
	var points := PackedVector2Array()
	for point_index in range(24):
		points.append(Vector2.RIGHT.rotated(TAU * float(point_index) / 24.0) * radius)
	visual.polygon = points
	puddle.add_child(visual)

	var duration := float(config["puddle_duration"])
	var tick_interval := float(config["tick_interval"])
	var tween := puddle.create_tween()
	var tick_count := int(floor(duration / tick_interval))
	for tick_index in range(tick_count):
		tween.tween_interval(tick_interval)
		tween.tween_callback(func() -> void:
			var player := get_tree().get_first_node_in_group("player") as Node2D
			if player != null and player.global_position.distance_to(puddle.global_position) <= radius and player.has_method("take_damage"):
				player.take_damage(tick_damage, "elite_poison_puddle")
		)
	tween.tween_property(visual, "color:a", 0.0, 0.25)
	tween.tween_callback(puddle.queue_free)


func _set_body_alpha(alpha: float) -> void:
	var rig := _cutout_rig()
	if rig != null:
		rig.modulate.a = alpha
	var body := get_node_or_null("Body") as Sprite2D
	if body == null:
		body = get_node_or_null("Sprite2D") as Sprite2D
	if body != null:
		body.modulate.a = alpha


func _visible_sprite_size() -> Vector2:
	var body := get_node_or_null("Body") as Sprite2D
	if body == null:
		body = get_node_or_null("Sprite2D") as Sprite2D
	if body == null or body.texture == null:
		return Vector2(64.0, 64.0)
	return body.texture.get_size() * body.scale.abs() * scale.abs()


func _fit_contact_range_to_sprite() -> void:
	# Контактный урон должен проходить при видимом касании спрайтов:
	# радиус врага + радиус игрока, экспортное значение остается минимумом.
	var visible_radius: float = maxf(_visible_sprite_size().x, _visible_sprite_size().y) * 0.5
	contact_range = maxf(contact_range, visible_radius * 0.82 + PLAYER_CONTACT_PADDING)


func _create_health_bar() -> void:
	if get_node_or_null("HealthBar") != null:
		return
	var bar := Node2D.new()
	bar.name = "HealthBar"
	bar.set_script(HEALTH_BAR_SCRIPT)
	add_child(bar)
	var sprite_size := _visible_sprite_size()
	bar.position = Vector2(0.0, -sprite_size.y * 0.5 - 14.0)
	bar.setup(max_health, sprite_size.x * 0.72)


func _update_health_bar() -> void:
	var bar := get_node_or_null("HealthBar")
	if bar == null:
		return
	if bar.has_method("setup") and float(bar.get("max_value")) != max_health and health >= max_health:
		bar.setup(max_health, float(bar.get("bar_width")))
	if bar.has_method("set_value"):
		bar.set_value(health)


func apply_knockback(impulse: Vector2) -> void:
	_knockback_velocity += impulse


func _consume_knockback(delta: float) -> Vector2:
	var current := _knockback_velocity
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, 2400.0 * delta)
	return current


func _player() -> Node2D:
	if _cached_player == null or not is_instance_valid(_cached_player):
		_cached_player = get_tree().get_first_node_in_group("player") as Node2D
	return _cached_player


func _update_shooting(delta: float, player: Node2D) -> void:
	if not can_shoot or projectile_scene == null:
		return

	_shoot_cooldown -= delta
	if _shoot_cooldown > 0.0:
		return

	var projectile := projectile_scene.instantiate()
	var projectile_parent := get_tree().current_scene
	if projectile_parent == null:
		projectile_parent = get_tree().root

	projectile_parent.add_child(projectile)

	if projectile.has_method("setup"):
		projectile.setup(global_position, player.global_position, projectile_damage, projectile_speed)

	_play_rig_action("shoot", player.global_position - global_position)
	_shoot_cooldown = fire_interval


func _update_summoning(delta: float) -> void:
	if not can_summon or summoned_enemy_scene == null:
		return

	_summon_cooldown -= delta
	if _summon_cooldown > 0.0:
		return

	var active_summons := 0
	for enemy in get_tree().get_nodes_in_group("summoned_enemies"):
		if is_instance_valid(enemy):
			active_summons += 1
	if active_summons >= max_active_summons:
		_summon_cooldown = summon_interval * 0.5
		return

	var summoned := summoned_enemy_scene.instantiate() as Node2D
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	parent.add_child(summoned)
	summoned.add_to_group("summoned_enemies")
	summoned.global_position = _clamp_to_arena(global_position + Vector2.RIGHT.rotated(randf() * TAU) * 44.0)
	_play_rig_action("cast", Vector2.UP)
	_summon_cooldown = summon_interval


func _clamp_to_arena(position: Vector2, margin: float = ARENA_ENTITY_MARGIN) -> Vector2:
	return Vector2(
		clampf(position.x, margin, ARENA_SIZE.x - margin),
		clampf(position.y, margin, ARENA_SIZE.y - margin)
	)


func _update_contact_damage(delta: float, player: Node2D, distance: float) -> void:
	_contact_cooldown = max(_contact_cooldown - delta, 0.0)
	if distance > contact_range:
		_contact_windup_left = -1.0
		return
	if _contact_cooldown > 0.0:
		return

	if _contact_windup_left < 0.0:
		_contact_windup_left = contact_windup_time
		_play_contact_windup()
		return

	_contact_windup_left -= delta
	if _contact_windup_left > 0.0:
		return

	if player.has_method("take_damage"):
		player.take_damage(contact_damage, "contact")

	_contact_cooldown = contact_interval
	_contact_windup_left = -1.0


func _play_contact_windup() -> void:
	var body := get_node_or_null("Body") as Sprite2D
	if body == null:
		body = get_node_or_null("Sprite2D") as Sprite2D
	if body == null:
		return
	_play_rig_action("attack", Vector2.RIGHT if velocity.length_squared() <= 0.0 else velocity)
	var restore_color := body.modulate
	_set_body_tint(Color(1.0, 0.72, 0.42, 1.0))
	var tween := create_tween()
	tween.tween_interval(max(contact_windup_time, 0.05))
	tween.tween_callback(_set_body_tint.bind(restore_color))


func _body_sprite() -> Sprite2D:
	if _cached_body != null and is_instance_valid(_cached_body):
		return _cached_body
	_cached_body = get_node_or_null("Body") as Sprite2D
	if _cached_body == null:
		_cached_body = get_node_or_null("Sprite2D") as Sprite2D
	return _cached_body


func _update_movement_animation(delta: float) -> void:
	var body := _body_sprite()
	if body == null:
		return

	if body.visible:
		body.visible = false
	if body.scale.distance_to(_rig_source_scale) > 0.01:
		_configure_enemy_rig()
	var rig := _cutout_rig()
	if rig != null and rig.has_method("update_animation"):
		rig.update_animation(delta, velocity, velocity)


func _configure_enemy_rig() -> void:
	var body := get_node_or_null("Body") as Sprite2D
	if body == null:
		body = get_node_or_null("Sprite2D") as Sprite2D
	if body == null or body.texture == null:
		return
	var rig := _cutout_rig()
	if rig == null:
		rig = Node2D.new()
		rig.name = "RigRoot"
		rig.set_script(CUTOUT_RIG_SCRIPT)
		add_child(rig)
	body.visible = false
	_rig_source_scale = body.scale
	if rig.has_method("configure"):
		rig.configure(body.texture, body.scale, enemy_type_name.to_lower().replace(" ", "_"), {
			"is_flying": is_flying,
			"is_elite": is_in_group("elite_enemies") or elite_behavior != "",
			"is_boss": is_in_group("bosses") or enemy_type_name.to_lower().contains("warden") or enemy_type_name.to_lower().contains("devourer"),
		})


func _cutout_rig() -> Node2D:
	if _cached_rig != null and is_instance_valid(_cached_rig):
		return _cached_rig
	_cached_rig = get_node_or_null("RigRoot") as Node2D
	return _cached_rig


func _play_rig_action(action_name: String, direction := Vector2.ZERO) -> void:
	var rig := _cutout_rig()
	if rig != null and rig.has_method("play_action"):
		rig.play_action(action_name, direction)
