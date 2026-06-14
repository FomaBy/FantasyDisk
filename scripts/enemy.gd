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
var _cached_full_frame_body: AnimatedSprite2D = null
var _cached_audio: Node = null
var elite_attack_state := "idle"
var elite_attack_id := ""
var _elite_attack_cooldown := 0.0
var _elite_attack_phase_left := 0.0
var _elite_attack_targets := []
var _elite_attack_direction := Vector2.RIGHT
var _elite_instant_phase_applied := false

const COLLISION_LAYER_PLAYER := 1
const COLLISION_LAYER_GROUND_ENEMY := 2
const COLLISION_LAYER_FLYING_ENEMY := 4
const COLLISION_LAYER_SOLID := 32
const ARENA_SIZE := Vector2(2560, 1440)
const ARENA_ENTITY_MARGIN := 48.0
const CUTOUT_RIG_SCRIPT := preload("res://scripts/cutout_rig_2d.gd")
const HEALTH_BAR_SCRIPT := preload("res://scripts/enemy_health_bar.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")
const FullFrameAnimationRegistry := preload("res://scripts/full_frame_animation_registry.gd")
const ENEMY_PROJECTILE_SCENE := preload("res://scenes/EnemyProjectile.tscn")
const ELITE_TELEGRAPH_TEXTURE := preload("res://assets/sprites/effects/elite_telegraph_circle.png")
const POISON_POOL_TEXTURE := preload("res://assets/sprites/effects/poison_pool.png")
const ELITE_SHOCKWAVE_TEXTURE := preload("res://assets/sprites/effects/elite_shockwave_ring.png")
const ELITE_SHADOW_TRAIL_TEXTURE := preload("res://assets/sprites/effects/elite_shadow_trail.png")
const ELITE_POISON_LOB_TEXTURE := preload("res://assets/sprites/effects/elite_poison_lob.png")
const ELITE_CRYSTAL_SHARD_TEXTURE := preload("res://assets/sprites/effects/elite_crystal_shard.png")
const ELITE_SHADOW_MARK_TEXTURE := preload("res://assets/sprites/effects/enemy_shadow_blink_mark.png")
const ELITE_SHARD_FAN_BURST_TEXTURE := preload("res://assets/sprites/effects/enemy_shard_fan_burst.png")

# Половина видимой ширины игрока: contact_range считается как сумма радиусов.
const PLAYER_CONTACT_PADDING := 26.0

# Epic-масштаб узла: визуал (rig — ребёнок), CollisionShape2D (ребёнок) и
# contact_range/health-bar (через _visible_sprite_size, учитывает scale) растут
# согласованно одним множителем. Профиль задается data-driven через
# ProgressionData.ENEMY_SIZE_PROFILES и meta `epic_scale_profile`.
const EPIC_SCALE_PROFILE_META := "epic_scale_profile"


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
		_apply_unique_encounter_pattern_meta(elite_behavior)
	_apply_epic_scale()
	if not _configure_full_frame_animation():
		_configure_enemy_rig()
	_fit_contact_range_to_sprite()
	_create_health_bar()
	var config := _elite_attack_config()
	if not config.is_empty():
		elite_attack_id = str(config["attack_id"])
		_elite_attack_cooldown = randf_range(2.2, 3.6)


func _apply_unique_encounter_pattern_meta(entity_id: String) -> void:
	var pattern := ProgressionData.unique_encounter_pattern(entity_id)
	if pattern.is_empty():
		return
	set_meta("unique_pattern_id", entity_id)
	set_meta("unique_pattern_title", str(pattern.get("title", "")))
	set_meta("unique_mechanics", (pattern.get("mechanics", []) as Array).duplicate())


func _elite_attack_config() -> Dictionary:
	return ProgressionData.elite_attack_config(elite_behavior)


func _epic_scale_factor() -> float:
	var profile_id := _epic_scale_profile_id()
	var profile: Dictionary = ProgressionData.enemy_size_profile(profile_id)
	return float(profile.get("scale", 1.0))


func _epic_scale_profile_id() -> String:
	if has_meta(EPIC_SCALE_PROFILE_META):
		return str(get_meta(EPIC_SCALE_PROFILE_META, "ordinary"))
	var lname := enemy_type_name.to_lower()
	if lname.contains("warden") or lname.contains("devourer") or is_in_group("bosses"):
		return "boss"
	if is_in_group("elite_enemies") or elite_behavior != "":
		return "elite"
	return "ordinary"


func _apply_epic_scale() -> void:
	# Элитки/боссы крупнее и страшнее: один node scale тянет визуал, хитбокс,
	# contact_range и health-bar вместе — «урона по воздуху» по гиганту не будет.
	var factor := _epic_scale_factor()
	if is_equal_approx(factor, 1.0):
		return
	scale = Vector2(factor, factor)


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
	StatusEffects.tick(self, delta)
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

	var status_speed := StatusEffects.speed_multiplier(self)
	if can_summon and distance < desired_summoning_distance * 0.85:
		velocity = -direction.normalized() * move_speed * status_speed
	elif can_summon and distance <= desired_summoning_distance * 1.15:
		velocity = Vector2.ZERO
	elif can_shoot and distance < desired_shooting_distance * 0.85:
		velocity = -direction.normalized() * move_speed * status_speed
	elif can_shoot and distance <= desired_shooting_distance:
		velocity = Vector2.ZERO
	elif direction.length_squared() > 0.0:
		velocity = direction.normalized() * move_speed * status_speed
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
	var final_amount := amount * StatusEffects.damage_taken_multiplier(self)
	if _elite_shield_active:
		final_amount *= elite_shield_damage_reduction
		_apply_elite_reflect_thorns(amount)
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
	_play_full_frame_state("hit", Vector2.ZERO)

	if health <= 0.0:
		# Награды/лут/счёт — сразу через сигнал, независимо от визуала смерти.
		died.emit(self)
		# SCRUM-379: если есть ЯВНАЯ full-frame death-анимация — проигрываем её до
		# удаления; иначе прежний death-ghost fallback (rig-призрак).
		var death_body := _full_frame_body()
		if death_body != null and death_body.visible and death_body.sprite_frames != null and death_body.sprite_frames.has_animation("death"):
			_play_full_frame_death_then_free(death_body)
		else:
			if rig != null and rig.has_method("spawn_death_ghost"):
				rig.spawn_death_ghost()
			queue_free()


func _play_full_frame_death_then_free(body: AnimatedSprite2D) -> void:
	# SCRUM-379: проигрываем death-кадры, отключив поведение/столкновения мёртвого
	# врага, затем удаляем по длительности анимации. Геймплей-награды уже выданы.
	set_physics_process(false)
	set_process(false)
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", true)
	var rig := _cutout_rig()
	if rig != null:
		rig.visible = false
	FullFrameAnimationRegistry.play_state(body, "death", Vector2.ZERO)
	var frames := body.sprite_frames
	var fps: float = maxf(frames.get_animation_speed("death"), 1.0)
	var count: int = maxi(frames.get_frame_count("death"), 1)
	var duration := float(count) / fps
	var tree := get_tree()
	if tree == null:
		queue_free()
		return
	tree.create_timer(duration + 0.05).timeout.connect(queue_free)


func _apply_elite_reflect_thorns(incoming_amount: float) -> void:
	var mechanics: Array = get_meta("unique_mechanics", []) as Array
	if not mechanics.has("reflect_thorns"):
		return
	var player := _player()
	if player == null or not player.has_method("take_damage"):
		return
	if player.global_position.distance_to(global_position) > 190.0:
		return
	var reflected_damage: float = minf(contact_damage * 0.55 + incoming_amount * 0.03, contact_damage * 1.15)
	if reflected_damage <= 0.0:
		return
	HazardVfx.aura_pulse(self, 150.0, Color(0.78, 0.92, 1.0, 0.9))
	player.take_damage(reflected_damage, "elite_reflect_thorns")


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
		HazardVfx.shield_block(self, Color(0.62, 0.86, 1.0, 1.0))
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

	var hazard_color := Color(0.55, 0.95, 0.30, 1.0)
	HazardVfx.telegraph(hazard, 72.0, hazard_color, 0.55)

	# Tween на hazard замораживается вместе с паузой дерева, в отличие от SceneTreeTimer.
	var hazard_tween := hazard.create_tween()
	hazard_tween.tween_interval(0.55)
	hazard_tween.tween_callback(func() -> void:
		HazardVfx.detonate(hazard, 72.0, hazard_color, "poison")
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
	HazardVfx.aura_pulse(self, 210.0, Color(1.0, 0.82, 0.36, 1.0))
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
	var config: Dictionary = _elite_attack_config()
	if config.is_empty():
		return false

	if elite_attack_state == "idle":
		# Возвышение 4 «Свирепые элитки»: боевая фаза (спец-атака) открывается сразу —
		# обнуляем стартовый кулдаун один раз (мета ставится в combat_director после _ready).
		if not _elite_instant_phase_applied and bool(get_meta("ascension_instant_phase", false)):
			_elite_instant_phase_applied = true
			_elite_attack_cooldown = 0.0
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
			# Фаза 2 (HP ≤ порога): ротация уникальных атак ускоряется (~-20%).
			_elite_attack_cooldown = float(config["cooldown"]) * (0.8 if _elite_in_phase2() else 1.0)
			elite_attack_phase_changed.emit(elite_attack_id, "idle")
			set_meta("elite_attack_phase", "idle")
	return elite_attack_state != "idle"


func _set_elite_attack_phase(phase: String, duration: float) -> void:
	elite_attack_state = phase
	_elite_attack_phase_left = duration
	set_meta("elite_attack_phase", phase)
	_play_elite_attack_phase_animation(phase, duration)
	elite_attack_phase_changed.emit(elite_attack_id, phase)


func _play_elite_attack_phase_animation(phase: String, duration: float) -> void:
	if elite_attack_id == "":
		var config: Dictionary = _elite_attack_config()
		elite_attack_id = str(config.get("attack_id", ""))
	var full_frame_state := "%s:%s:%s" % [elite_behavior, elite_attack_id, phase]
	if _play_full_frame_state(full_frame_state, _elite_attack_direction):
		var full_frame_body := _full_frame_body()
		if full_frame_body != null:
			full_frame_body.set_meta("phase_duration", duration)
		return
	var rig := _cutout_rig()
	if rig == null:
		_configure_enemy_rig()
		rig = _cutout_rig()
	if rig == null or not rig.has_method("play_action"):
		return
	var action_name := "attack"
	match elite_behavior:
		"iron_bastion":
			action_name = "attack"
		"night_stalker":
			action_name = "attack" if phase == "strike" else "cast"
		"plague_prophet":
			action_name = "shoot" if phase == "strike" else "cast"
		"shard_marshal":
			action_name = "shoot"
		_:
			action_name = "attack"
	var variant := "%s:%s:%s" % [elite_behavior, elite_attack_id, phase]
	rig.play_action(action_name, _elite_attack_direction, variant, duration)


func _begin_elite_attack_windup(config: Dictionary, player: Node2D) -> void:
	_elite_attack_targets.clear()
	_set_elite_attack_phase("windup", float(config["windup"]))
	var to_player := player.global_position - global_position
	if to_player.length_squared() > 0.001:
		_elite_attack_direction = to_player.normalized()

	var phase2 := _elite_in_phase2()
	match elite_behavior:
		"iron_bastion":
			# Телеграф совпадает с фаза-2 расширением волны (честное окно уворота).
			_spawn_elite_telegraph(global_position, _safe_radius(float(config["radius"]) * (1.3 if phase2 else 1.0)), float(config["windup"]))
		"night_stalker":
			var behind := player.global_position + _elite_attack_direction * float(config["behind_offset"])
			_elite_attack_targets.append(_clamp_to_arena(behind))
			_spawn_elite_telegraph(_elite_attack_targets[0], float(config["radius"]), float(config["windup"]))
			_set_body_alpha(0.25)
			_spawn_shadow_trail(global_position, _elite_attack_targets[0], float(config["windup"]))
		"plague_prophet":
			_play_rig_action("cast", _elite_attack_direction)
			var spread := float(config["lob_spread"])
			# Фаза 2: больше луж яда (второе применение) — +2 лоба.
			for lob_index in range(int(config["lob_count"]) + (2 if phase2 else 0)):
				var offset := Vector2.ZERO
				if lob_index > 0:
					offset = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(spread * 0.35, spread)
				var target := _clamp_to_arena(player.global_position + offset, 92.0)
				_elite_attack_targets.append(target)
				_spawn_elite_telegraph(target, float(config["radius"]), float(config["windup"]) + float(config["lob_travel_time"]))
		"shard_marshal":
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


func _elite_in_phase2() -> bool:
	# Боевая фаза 2 элитки: ниже порога HP (elite_phase_threshold, по умолч. 0.50).
	if max_health <= 0.0:
		return false
	var threshold := float(get_meta("elite_phase_threshold", 0.5))
	return health / max_health <= threshold


func _safe_radius(radius: float) -> float:
	# Safe corridor: ни один хазард не перекрывает арену целиком — даже две
	# одновременные зоны оставляют проходимый коридор (cap < полувысоты арены).
	return minf(radius, ARENA_SIZE.y * 0.34)


func _shake_player_camera(intensity: float, duration := 0.18) -> void:
	# Тряска на slam/детонациях из скриптов врага (без ссылки на game): флаг
	# берётся из tree-root меты, выставляемой main при загрузке настроек.
	if not bool(get_tree().root.get_meta("screen_shake", true)):
		return
	var player := _player()
	if player == null:
		return
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	var tween := camera.create_tween()
	var steps := 5
	for i in range(steps):
		var falloff: float = 1.0 - float(i) / float(steps)
		var off: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * intensity * falloff
		tween.tween_property(camera, "offset", off, duration / float(steps))
	tween.tween_property(camera, "offset", Vector2.ZERO, duration / float(steps))


func _elite_attack_damage(config: Dictionary, player: Node2D) -> float:
	var damage := contact_damage * float(config["damage_factor"])
	var player_max_health := float(player.get("max_health")) if player.get("max_health") != null else 0.0
	if player_max_health > 0.0:
		damage = minf(damage, player_max_health * 0.25)
	return damage


func _strike_slam_wave(config: Dictionary, player: Node2D) -> void:
	var phase2 := _elite_in_phase2()
	# Фаза 2: «двойная волна» — шире и сильнее, но в пределах безопасного коридора.
	var radius := _safe_radius(float(config["radius"]) * (1.3 if phase2 else 1.0))
	var knockback := float(config["knockback"]) * (1.3 if phase2 else 1.0)
	_spawn_shockwave_ring(global_position, radius)
	_shake_player_camera(9.0 if phase2 else 7.0, 0.2)
	if phase2:
		_spawn_shockwave_ring(global_position, radius * 0.6)
	if player.global_position.distance_to(global_position) > radius:
		return
	if player.has_method("take_damage") and player.take_damage(_elite_attack_damage(config, player), "elite_slam_wave"):
		var push_direction := (player.global_position - global_position).normalized()
		if push_direction.length_squared() <= 0.001:
			push_direction = Vector2.RIGHT
		player.global_position = _clamp_to_arena(player.global_position + push_direction * knockback)


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
	# Фаза 2: серия из двух ударов из тени — второй заход с другой стороны.
	if _elite_in_phase2():
		var second := _clamp_to_arena(player.global_position - _elite_attack_direction * float(config["behind_offset"]))
		_spawn_shadow_trail(global_position, second, 0.18)
		global_position = second
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
	for shard_index in range(shard_count):
		var t := 0.0 if shard_count == 1 else float(shard_index) / float(shard_count - 1)
		var angle := lerpf(-spread * 0.5, spread * 0.5, t)
		_spawn_shard(_elite_attack_direction.rotated(angle), damage, config)
	# Фаза 2: второе применение — кольцо осколков вдобавок к вееру (всегда есть
	# проход: кольцо разрежено, между лучами можно проскользнуть).
	if _elite_in_phase2():
		var ring_count := 8
		for ring_index in range(ring_count):
			var ring_angle := TAU * float(ring_index) / float(ring_count)
			_spawn_shard(Vector2.RIGHT.rotated(ring_angle), damage, config)


func _spawn_shard(direction: Vector2, damage: float, config: Dictionary) -> void:
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
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
	match elite_attack_id:
		"shadow_strike":
			sprite.texture = ELITE_SHADOW_MARK_TEXTURE
		"shard_fan":
			sprite.texture = ELITE_SHARD_FAN_BURST_TEXTURE
		_:
			sprite.texture = ELITE_TELEGRAPH_TEXTURE
	var texture_radius: float = maxf(float(maxi(sprite.texture.get_width(), sprite.texture.get_height())) * 0.5, 1.0)
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

	# Оформленная бурлящая лужа яда (raster pool) вместо голого Polygon2D-круга.
	var visual := Sprite2D.new()
	visual.texture = POISON_POOL_TEXTURE
	visual.scale = Vector2.ONE * (radius * 2.0 / float(POISON_POOL_TEXTURE.get_width()))
	visual.modulate = Color(1.0, 1.0, 1.0, 0.0)
	puddle.add_child(visual)
	# появление + непрерывное «бульканье» (pause-aware, привязан к ноде)
	var appear := puddle.create_tween()
	appear.tween_property(visual, "modulate:a", 0.92, 0.18)
	var bubble := puddle.create_tween()
	bubble.set_loops()
	bubble.tween_property(visual, "scale", visual.scale * 1.06, 0.7).set_trans(Tween.TRANS_SINE)
	bubble.tween_property(visual, "scale", visual.scale, 0.7).set_trans(Tween.TRANS_SINE)

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
	tween.tween_property(visual, "modulate:a", 0.0, 0.3)
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


func refresh_health_bar() -> void:
	if get_node_or_null("HealthBar") == null:
		_create_health_bar()
	_update_health_bar()


func _update_health_bar() -> void:
	var bar := get_node_or_null("HealthBar")
	if bar == null:
		return
	var sprite_size := _visible_sprite_size()
	bar.position = Vector2(0.0, -sprite_size.y * 0.5 - 14.0)
	if bar.has_method("configure"):
		bar.configure(max_health, health, sprite_size.x * 0.72)
	elif bar.has_method("set_value"):
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
	var full_frame_body := _full_frame_body()
	if full_frame_body != null and full_frame_body.visible:
		var state := "move" if velocity.length_squared() > 1.0 else "idle"
		FullFrameAnimationRegistry.play_state(full_frame_body, state, velocity)
		return

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


func _configure_full_frame_animation() -> bool:
	var entity_kind := _full_frame_entity_kind()
	var entity_id := _full_frame_entity_id(entity_kind)
	var static_body_name := "Body" if get_node_or_null("Body") != null else "Sprite2D"
	var animated_body := FullFrameAnimationRegistry.configure_entity_visual(self, entity_kind, entity_id, "FullFrameBody", static_body_name)
	if animated_body == null:
		return false
	_cached_full_frame_body = animated_body
	var rig := _cutout_rig()
	if rig != null:
		rig.visible = false
	return true


func refresh_full_frame_visual() -> void:
	_configure_full_frame_animation()


func _full_frame_entity_kind() -> String:
	if is_in_group("bosses"):
		return "boss"
	if is_in_group("elite_enemies") or elite_behavior != "":
		return "elite"
	return "enemy"


func _full_frame_entity_id(entity_kind: String) -> String:
	if entity_kind == "boss" and get("boss_behavior") != null and str(get("boss_behavior")) != "":
		return str(get("boss_behavior"))
	if entity_kind == "elite" and has_meta("mini_elite_kind"):
		var mini_elite_id := str(get_meta("mini_elite_kind", ""))
		if mini_elite_id != "" and FullFrameAnimationRegistry.sprite_frames_for("elite", mini_elite_id) != null:
			return mini_elite_id
	if entity_kind == "elite" and elite_behavior != "":
		return elite_behavior
	return enemy_type_name.to_lower().replace(" ", "_")


func _full_frame_body() -> AnimatedSprite2D:
	if _cached_full_frame_body != null and is_instance_valid(_cached_full_frame_body):
		return _cached_full_frame_body
	_cached_full_frame_body = get_node_or_null("FullFrameBody") as AnimatedSprite2D
	return _cached_full_frame_body


func _configure_enemy_rig() -> void:
	var full_frame_body := _full_frame_body()
	if full_frame_body != null and full_frame_body.visible:
		return
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
	if _play_full_frame_state(action_name, direction):
		return
	var rig := _cutout_rig()
	if rig != null and rig.has_method("play_action"):
		rig.play_action(action_name, direction)


func _play_full_frame_state(state_name: String, direction := Vector2.ZERO) -> bool:
	var full_frame_body := _full_frame_body()
	if full_frame_body == null or not full_frame_body.visible:
		return false
	return FullFrameAnimationRegistry.play_state(full_frame_body, state_name, direction)
