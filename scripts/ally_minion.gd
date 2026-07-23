extends CharacterBody2D

const TARGET_QUERY := preload("res://scripts/combat_target_query.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")
const FullFrameAnimationRegistry := preload("res://scripts/full_frame_animation_registry.gd")

const ALLY_VISUAL_PATHS := {
	"druid_beast": "res://assets/sprites/allies/ally_druid_beast.png",
	"druid_pack_spirit": "res://assets/sprites/allies/ally_druid_pack_spirit.png",
	# SCRUM-946: гомункулы переведены на новые PixelLab-спрайты (SCRUM-945);
	# легаси-id "homunculus" тоже указывает на арт танка.
	"homunculus": "res://assets/sprites/allies/homunculus_tank_south.png",
	"homunculus_tank": "res://assets/sprites/allies/homunculus_tank_south.png",
	"leadership_echo": "res://assets/sprites/allies/ally_leadership_echo.png",
}
# SCRUM-946: 4-направленный статичный арт (по PNG на ракурс, без spriteframes) —
# кадр выбирается по доминирующей оси движения в _update_visual_animation.
const DIRECTIONAL_ALLY_VISUAL_PATHS := {
	"homunculus": {
		"south": "res://assets/sprites/allies/homunculus_tank_south.png",
		"north": "res://assets/sprites/allies/homunculus_tank_north.png",
		"east": "res://assets/sprites/allies/homunculus_tank_east.png",
		"west": "res://assets/sprites/allies/homunculus_tank_west.png",
	},
	"homunculus_tank": {
		"south": "res://assets/sprites/allies/homunculus_tank_south.png",
		"north": "res://assets/sprites/allies/homunculus_tank_north.png",
		"east": "res://assets/sprites/allies/homunculus_tank_east.png",
		"west": "res://assets/sprites/allies/homunculus_tank_west.png",
	},
	"homunculus_caster": {
		"south": "res://assets/sprites/allies/homunculus_caster_south.png",
		"north": "res://assets/sprites/allies/homunculus_caster_north.png",
		"east": "res://assets/sprites/allies/homunculus_caster_east.png",
		"west": "res://assets/sprites/allies/homunculus_caster_west.png",
	},
}
const FALLBACK_ALLY_VISUAL_ID := "druid_beast"
const FULL_FRAME_DEATH_DURATION_FALLBACK := 0.62

@export var move_speed := 230.0
@export var damage := 1.5
@export var attack_range := 24.0
@export var attack_interval := 0.45
@export var lifetime := 12.0
@export var command_mode := "attack_target"
@export var ally_visual_id := FALLBACK_ALLY_VISUAL_ID
@export var max_health := 18.0
@export var summon_role := "pack_damage"
@export var control_knockback := 0.0
@export var support_heal_percent := 0.0
@export var aoe_radius := 0.0
@export var aoe_damage_multiplier := 0.55
@export var leash_radius := 520.0

# SCRUM-902: семья урона и вид атаки записи ростера (см. summoner_weapon
# ._summon_profile). physical-melee — контактный AoE-удар, magic-ranged —
# магический снаряд по цели. Урон красится своим каналом (damage_type feedback).
@export var damage_family := "physical"
@export var attack_kind := "melee"
@export var ranged_projectile_speed := 620.0

var _attack_cooldown := 0.0
var _attack_anim_time := 0.0
var _last_facing_right := false
# Stable spawn-derived direction for the guard formation. ObjectID is opaque
# runtime identity and must not affect gameplay geometry or timing.
var _guard_formation_direction := Vector2.RIGHT
# SCRUM-946: текущий ракурс 4-направленного статичного арта (см.
# DIRECTIONAL_ALLY_VISUAL_PATHS); юниты без направленного арта его не трогают.
var _directional_facing := "south"
var owner_node: Node2D = null
var command_target: Node2D = null
var health := 18.0
var _death_lifecycle_started := false
var _death_tween: Tween = null
# SCRUM-961 «Гомункул-танк»: периодическая провокация (по образцу bastion_taunt).
var taunt_pulse := false
var _taunt_pulse_left := 0.0
var constellation_owner_instance_id := 0
var constellation_weapon_id := ""
var constellation_intercepts_left := 0
var constellation_intercept_ratio := 0.0
var constellation_death_burst_ratio := 0.0
var _constellation_death_burst_fired := false

const CONSTELLATION_FINAL_MECHANICS := {"homunculus_intercept_death_burst": "summon_death"}
const CONSTELLATION_HEAVY_HIT_RATIO := 0.20
const CONSTELLATION_POUNCE_RANGE := 120.0

const TAUNT_PULSE_INTERVAL := 1.4
const TAUNT_PULSE_RADIUS := 210.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("allies")
	health = max_health
	_apply_visual()


func set_visual_id(visual_id: String) -> void:
	ally_visual_id = visual_id
	_apply_visual()


func set_guard_formation_direction(direction: Vector2) -> void:
	if direction.length_squared() > 0.001:
		_guard_formation_direction = direction.normalized()


func set_combat_profile(profile: Dictionary) -> void:
	damage = maxf(float(profile.get("damage", damage)), 0.1)
	move_speed = maxf(float(profile.get("move_speed", move_speed)), 40.0)
	attack_range = maxf(float(profile.get("attack_range", attack_range)), 8.0)
	attack_interval = maxf(float(profile.get("attack_interval", attack_interval)), 0.12)
	lifetime = maxf(float(profile.get("lifetime", lifetime)), 1.0)
	max_health = maxf(float(profile.get("max_health", max_health)), 1.0)
	health = max_health
	summon_role = str(profile.get("summon_role", summon_role))
	control_knockback = maxf(float(profile.get("control_knockback", control_knockback)), 0.0)
	support_heal_percent = maxf(float(profile.get("support_heal_percent", support_heal_percent)), 0.0)
	aoe_radius = maxf(float(profile.get("aoe_radius", aoe_radius)), 0.0)
	aoe_damage_multiplier = clampf(float(profile.get("aoe_damage_multiplier", aoe_damage_multiplier)), 0.0, 1.0)
	leash_radius = maxf(float(profile.get("leash_radius", leash_radius)), 120.0)
	taunt_pulse = bool(profile.get("taunt_pulse", taunt_pulse))
	# SCRUM-902: семья урона / вид атаки ростера.
	damage_family = str(profile.get("damage_family", damage_family))
	attack_kind = str(profile.get("attack_kind", attack_kind))
	ranged_projectile_speed = maxf(float(profile.get("ranged_projectile_speed", ranged_projectile_speed)), 120.0)
	constellation_owner_instance_id = int(profile.get("constellation_owner_instance_id", 0))
	constellation_weapon_id = str(profile.get("constellation_weapon_id", ""))
	constellation_intercepts_left = maxi(int(profile.get("constellation_intercepts_left", 0)), 0)
	constellation_intercept_ratio = clampf(float(profile.get("constellation_intercept_ratio", 0.0)), 0.0, 0.80)
	constellation_death_burst_ratio = clampf(float(profile.get("constellation_death_burst_ratio", 0.0)), 0.0, 1.0)


func set_visual_scale(scale_value: Vector2) -> void:
	var safe_scale := Vector2(maxf(scale_value.x, 0.1), maxf(scale_value.y, 0.1))
	var body := get_node_or_null("Body") as Sprite2D
	if body != null:
		body.scale = safe_scale
	var animated_body := get_node_or_null("AnimatedBody") as AnimatedSprite2D
	if animated_body != null:
		animated_body.scale = safe_scale


func heal(amount: float) -> float:
	if _death_lifecycle_started or health <= 0.0 or amount <= 0.0:
		return 0.0
	var before := health
	health = minf(health + amount, max_health)
	return health - before


func take_damage(amount: float, _source := "", _attacker: Node2D = null) -> void:
	# Сигнатура зеркалит Player.take_damage: по таунту (bastion_taunt) контактный
	# удар врага приходит сюда с source/attacker вместо игрока.
	if _death_lifecycle_started:
		return
	var incoming := maxf(amount, 0.0)
	if constellation_intercepts_left > 0 and constellation_intercept_ratio > 0.0 and incoming >= max_health * CONSTELLATION_HEAVY_HIT_RATIO:
		incoming *= 1.0 - constellation_intercept_ratio
		constellation_intercepts_left -= 1
	health -= incoming
	if health <= 0.0:
		_constellation_emit_death_burst()
		_begin_death_lifecycle()


func constellation_alpha_pounce(target: Node2D, damage_ratio: float) -> bool:
	if _death_lifecycle_started or target == null or not is_instance_valid(target) or not target.has_method("take_damage"):
		return false
	var to_target := target.global_position - global_position
	if to_target.length_squared() > 0.001:
		global_position += to_target.normalized() * minf(to_target.length(), CONSTELLATION_POUNCE_RANGE)
	var pounce_damage := damage * clampf(damage_ratio, 0.0, 1.0)
	var constellation_owner := instance_from_id(constellation_owner_instance_id) as Node
	if constellation_owner != null and is_instance_valid(constellation_owner) and constellation_owner.has_method("meta_damage_multiplier"):
		pounce_damage *= float(constellation_owner.call("meta_damage_multiplier", {"weapon_id": constellation_weapon_id, "attack_mode": "summon", "damage_type": "physical", "summon_role": summon_role, "constellation_secondary": true}, target))
	_deal_typed_damage(target, pounce_damage, {"damage_type": "physical", "constellation_final": "pack_alpha_pounce_guard"})
	_play_attack_animation(to_target)
	return true


func _constellation_emit_death_burst() -> void:
	if _constellation_death_burst_fired or constellation_death_burst_ratio <= 0.0:
		return
	var constellation_owner := instance_from_id(constellation_owner_instance_id) as Node
	if constellation_owner == null or not is_instance_valid(constellation_owner) or not constellation_owner.has_method("constellation_weapon_event"):
		return
	var result_raw = constellation_owner.call("constellation_weapon_event", constellation_weapon_id, "summon_death", {"summon_id": get_instance_id(), "intercepts_left": constellation_intercepts_left}, self)
	if not result_raw is Dictionary or not bool((result_raw as Dictionary).get("triggered", false)):
		return
	_constellation_death_burst_fired = true
	var radius := maxf(aoe_radius, 96.0)
	AttackVfx.ring_pulse(get_parent(), global_position, radius, Color(0.72, 1.0, 0.48, 0.42), false)
	for enemy in TARGET_QUERY.in_radius(self, global_position, radius):
		if enemy == null or not is_instance_valid(enemy):
			continue
		var enemy_node := enemy as Node2D
		if enemy_node == null:
			continue
		var burst_damage := damage * constellation_death_burst_ratio
		if constellation_owner.has_method("meta_damage_multiplier"):
			burst_damage *= float(constellation_owner.call("meta_damage_multiplier", {"weapon_id": constellation_weapon_id, "attack_mode": "summon", "damage_type": "physical", "summon_role": summon_role, "constellation_secondary": true}, enemy_node))
		_deal_typed_damage(enemy_node, burst_damage, {"damage_type": "physical", "constellation_final": "homunculus_intercept_death_burst"})


func constellation_special_state() -> Dictionary:
	return {"intercepts_left": constellation_intercepts_left, "intercept_ratio": constellation_intercept_ratio, "death_burst_ratio": constellation_death_burst_ratio, "death_burst_fired": _constellation_death_burst_fired}


# SCRUM-961 «Гомункул-танк»: периодический taunt-пульс — враги рядом грызут
# гомункула, а не Химика (bastion_taunt с taunt_owner = этот юнит; enemy
# ._taunt_target уже резолвит владельца статуса по instance id).
func _update_taunt_pulse(delta: float) -> void:
	if not taunt_pulse or _death_lifecycle_started:
		return
	_taunt_pulse_left -= delta
	if _taunt_pulse_left > 0.0:
		return
	_taunt_pulse_left = TAUNT_PULSE_INTERVAL
	if not is_inside_tree():
		return
	AttackVfx.ring_pulse(get_parent(), global_position, TAUNT_PULSE_RADIUS * 0.62, Color(0.95, 0.75, 0.35, 0.30), false)
	for enemy in TARGET_QUERY.in_radius(self, global_position, TAUNT_PULSE_RADIUS):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		StatusEffects.apply_status(enemy_node, "bastion_taunt", {
			"duration": 1.5,
			"speed_multiplier": 1.04,
			"marker_color": Color(0.95, 0.80, 0.45, 1.0),
			"taunt_owner": get_instance_id(),
		})


func _apply_visual() -> void:
	var body := get_node_or_null("Body") as Sprite2D
	var animated_body := get_node_or_null("AnimatedBody") as AnimatedSprite2D
	if body == null:
		return
	var path := str(ALLY_VISUAL_PATHS.get(ally_visual_id, ALLY_VISUAL_PATHS[FALLBACK_ALLY_VISUAL_ID]))
	var texture := load(path) as Texture2D
	if texture != null:
		body.texture = texture
	body.visible = true
	_directional_facing = "south"  # SCRUM-946: базовый кадр направленного арта

	if animated_body == null:
		return
	var configured := FullFrameAnimationRegistry.configure_entity_visual(self, "ally", ally_visual_id, "AnimatedBody", "Body")
	if configured == null or configured.sprite_frames == null or not configured.sprite_frames.has_animation("move") or not configured.sprite_frames.has_animation("attack"):
		animated_body.visible = false
		animated_body.stop()
		body.visible = true
		return
	animated_body.flip_h = false if FullFrameAnimationRegistry.uses_explicit_horizontal_directions(animated_body) else _last_facing_right
	FullFrameAnimationRegistry.play_state(animated_body, "move", Vector2.LEFT)


func _physics_process(delta: float) -> void:
	StatusEffects.tick(self, delta)
	lifetime -= delta
	_attack_cooldown -= delta
	_attack_anim_time = maxf(_attack_anim_time - delta, 0.0)
	if lifetime <= 0.0:
		queue_free()
		return
	_update_taunt_pulse(delta)

	var target := _commanded_target()
	if target == null:
		_follow_guard_position()
		move_and_slide()
		_update_visual_animation()
		return

	var to_target := target.global_position - global_position
	if to_target.length() <= attack_range:
		velocity = Vector2.ZERO
		_try_attack(target)
	else:
		velocity = to_target.normalized() * move_speed * StatusEffects.speed_multiplier(self)

	move_and_slide()
	_update_visual_animation()


func _find_closest_enemy() -> Node2D:
	return TARGET_QUERY.nearest(self, global_position)


func _commanded_target() -> Node2D:
	if command_mode == "guard_owner" and owner_node != null and is_instance_valid(owner_node):
		var local_target := _find_closest_enemy_near(owner_node.global_position, minf(leash_radius, 360.0))
		if local_target != null:
			return local_target
		return null
	if command_target != null and is_instance_valid(command_target):
		if owner_node != null and is_instance_valid(owner_node) and owner_node.global_position.distance_to(command_target.global_position) > leash_radius:
			command_target = null
		else:
			return command_target
	if owner_node != null and is_instance_valid(owner_node):
		var owner_local_target := _find_closest_enemy_near(owner_node.global_position, leash_radius)
		if owner_local_target != null:
			return owner_local_target
		return command_target
	return _find_closest_enemy()


func _find_closest_enemy_near(origin: Vector2, max_distance: float) -> Node2D:
	return TARGET_QUERY.nearest(self, origin, max_distance)


func _follow_guard_position() -> void:
	if owner_node == null or not is_instance_valid(owner_node):
		velocity = Vector2.ZERO
		return
	var guard_offset := _guard_formation_direction * 56.0
	var guard_position := owner_node.global_position + guard_offset
	var to_guard := guard_position - global_position
	if to_guard.length() <= 18.0:
		velocity = Vector2.ZERO
	else:
		velocity = to_guard.normalized() * move_speed


func _try_attack(target: Node2D) -> void:
	if _attack_cooldown > 0.0:
		return

	var final_damage := damage * StatusEffects.damage_multiplier(self)
	var constellation_owner := instance_from_id(constellation_owner_instance_id) as Node
	if constellation_owner != null and is_instance_valid(constellation_owner) and constellation_owner.has_method("meta_damage_multiplier"):
		var constellation_context := {
			"weapon_id": constellation_weapon_id,
			"attack_mode": "summon",
			"damage_type": "magic" if damage_family == "magic" else "physical",
			"summon_role": summon_role,
		}
		final_damage *= float(constellation_owner.call("meta_damage_multiplier", constellation_context, target))
	# SCRUM-902: попадания призыва красятся семьёй урона записи ростера
	# (physical-melee / magic-ranged) — единый feedback-контракт enemy.take_damage.
	var hit_feedback := {"damage_type": "magic" if damage_family == "magic" else "physical"}
	var hit_ids := {}
	_deal_typed_damage(target, final_damage, hit_feedback)
	hit_ids[target.get_instance_id()] = true
	if attack_kind == "ranged":
		# SCRUM-902: магический дух — снаряд. Урон применён мгновенно (контракт
		# take_damage выше), болт — чисто визуальный: твин живёт НА болте и
		# завершается его же queue_free (Callable без чужих захватов — канон
		# SCRUM-551, гонок с freed-целью/духом нет).
		_spawn_ranged_bolt_visual(target.global_position)
	if control_knockback > 0.0 and target.has_method("apply_knockback"):
		var push_origin := owner_node.global_position if owner_node != null and is_instance_valid(owner_node) else global_position
		var push_direction := target.global_position - push_origin
		if push_direction.length_squared() > 0.001:
			target.apply_knockback(push_direction.normalized() * control_knockback)
	if aoe_radius > 0.0 and aoe_damage_multiplier > 0.0:
		for enemy in TARGET_QUERY.in_radius(self, target.global_position, aoe_radius):
			var enemy_node := enemy as Node2D
			if enemy_node == null or not is_instance_valid(enemy_node) or hit_ids.has(enemy_node.get_instance_id()):
				continue
			_deal_typed_damage(enemy_node, final_damage * aoe_damage_multiplier, hit_feedback)
			if control_knockback > 0.0 and enemy_node.has_method("apply_knockback"):
				var splash_direction := enemy_node.global_position - target.global_position
				if splash_direction.length_squared() > 0.001:
					enemy_node.apply_knockback(splash_direction.normalized() * control_knockback * 0.45)
	if support_heal_percent > 0.0 and owner_node != null and is_instance_valid(owner_node):
		if owner_node.has_method("heal_percent_capped"):
			owner_node.heal_percent_capped(support_heal_percent)
		elif owner_node.has_method("heal_percent"):
			owner_node.heal_percent(support_heal_percent)

	_attack_cooldown = attack_interval
	_play_attack_animation(target.global_position - global_position)


# SCRUM-902: типизированный урон призыва. Реальный Enemy принимает feedback
# (окраска цифр каналом physical/magic), легаси/тестовые цели с 1-арговым
# take_damage получают классический вызов (зеркало канона
# class_weapon._call_take_damage — без падений на моках).
func _deal_typed_damage(target: Node, amount: float, feedback: Dictionary) -> void:
	if target == null or not is_instance_valid(target) or not target.has_method("take_damage"):
		return
	for method in target.get_method_list():
		if str(method.get("name", "")) == "take_damage":
			if (method.get("args", []) as Array).size() >= 2:
				target.call("take_damage", amount, feedback)
			else:
				target.call("take_damage", amount)
			return


# SCRUM-902: косметический магический болт дальнего духа — самодостаточный
# узел: летит твином к точке цели и сам себя освобождает (владелец твина и
# цель Callable — сам болт; смерть духа/цели в полёте ничего не ломает).
func _spawn_ranged_bolt_visual(target_position: Vector2) -> void:
	if not is_inside_tree():
		return
	var parent := get_parent()
	if parent == null:
		return
	var bolt := Node2D.new()
	bolt.name = "GhostSpiritBolt"
	bolt.z_index = 6
	var glow := Sprite2D.new()
	glow.texture = load("res://assets/sprites/effects/spark_pool.png") as Texture2D
	glow.scale = Vector2.ONE * 0.055
	glow.modulate = Color(0.55, 0.85, 1.0, 0.85)
	bolt.add_child(glow)
	parent.add_child(bolt)
	bolt.global_position = global_position + Vector2(0.0, -26.0)
	var flight_time := clampf(bolt.global_position.distance_to(target_position) / maxf(ranged_projectile_speed, 120.0), 0.08, 0.45)
	var bolt_tween := bolt.create_tween()
	bolt_tween.tween_property(bolt, "global_position", target_position, flight_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	bolt_tween.tween_property(glow, "modulate:a", 0.0, 0.08)
	bolt_tween.tween_callback(Callable(bolt, "queue_free"))


func _update_visual_animation() -> void:
	var animated_body := get_node_or_null("AnimatedBody") as AnimatedSprite2D
	if animated_body == null or not animated_body.visible:
		_update_directional_static_visual()
		return

	if absf(velocity.x) > 1.0:
		_last_facing_right = velocity.x > 0.0
	if FullFrameAnimationRegistry.uses_explicit_horizontal_directions(animated_body):
		animated_body.flip_h = false
	else:
		animated_body.flip_h = _last_facing_right

	if _attack_anim_time > 0.0:
		FullFrameAnimationRegistry.play_state(animated_body, "attack", Vector2.RIGHT if _last_facing_right else Vector2.LEFT)
		return

	FullFrameAnimationRegistry.play_state(animated_body, "move", Vector2.RIGHT if _last_facing_right else Vector2.LEFT)


# SCRUM-946: 4-направленный статичный арт гомункулов — подмена кадра Body по
# доминирующей оси движения (стоя на месте — держим последний ракурс).
func _update_directional_static_visual(direction := Vector2.ZERO) -> void:
	if not DIRECTIONAL_ALLY_VISUAL_PATHS.has(ally_visual_id):
		return
	var motion := direction if direction.length_squared() > 0.01 else velocity
	if motion.length_squared() < 4.0:
		return
	var facing := "south"
	if absf(motion.x) >= absf(motion.y):
		facing = "east" if motion.x >= 0.0 else "west"
	else:
		facing = "south" if motion.y >= 0.0 else "north"
	if facing == _directional_facing:
		return
	_directional_facing = facing
	var body := get_node_or_null("Body") as Sprite2D
	if body == null:
		return
	var directions: Dictionary = DIRECTIONAL_ALLY_VISUAL_PATHS[ally_visual_id]
	var texture := load(str(directions.get(facing, directions["south"]))) as Texture2D
	if texture != null:
		body.texture = texture


func _play_attack_animation(direction: Vector2 = Vector2.ZERO) -> void:
	var animated_body := get_node_or_null("AnimatedBody") as AnimatedSprite2D
	if animated_body == null or not animated_body.visible:
		# SCRUM-946: направленный статичный арт разворачивается к цели удара.
		_update_directional_static_visual(direction)
		return
	if absf(direction.x) > 0.01:
		_last_facing_right = direction.x > 0.0
	var visual_direction := direction
	if FullFrameAnimationRegistry.uses_explicit_horizontal_directions(animated_body) and absf(direction.x) <= 0.01:
		visual_direction = Vector2.RIGHT if _last_facing_right else Vector2.LEFT
	if FullFrameAnimationRegistry.play_state(animated_body, "attack", visual_direction):
		_attack_anim_time = _active_full_frame_animation_duration(animated_body, 0.44)
	else:
		_attack_anim_time = 0.44


func _active_full_frame_animation_duration(animated_body: AnimatedSprite2D, fallback: float) -> float:
	if animated_body == null or animated_body.sprite_frames == null:
		return fallback
	var frames := animated_body.sprite_frames
	var animation_name := animated_body.animation
	if not frames.has_animation(animation_name):
		return fallback
	var frame_count := frames.get_frame_count(animation_name)
	var speed := frames.get_animation_speed(animation_name)
	if frame_count <= 0 or speed <= 0.0:
		return fallback
	return maxf(fallback, float(frame_count) / speed)


func is_using_animated_ally_visual() -> bool:
	var animated_body := get_node_or_null("AnimatedBody") as AnimatedSprite2D
	return animated_body != null and animated_body.visible


func _begin_death_lifecycle() -> void:
	if _death_lifecycle_started:
		return
	_death_lifecycle_started = true
	health = 0.0
	if _play_full_frame_death():
		_disable_dead_ally_runtime()
		# Деферим free до конца death-анимации, но через ГВАРД-колбэк и со ссылкой на
		# твин: если узел успеют форс-фрильнуть раньше (каскад queue_free родителя —
		# напр. mass-free между замерами в character_balance_csv.gd), _exit_tree убьёт
		# твин, и колбэк не дёрнет queue_free на уже освобождённом self. Без этого
		# tween_callback(queue_free) интермиттентно валит нативный SIGABRT (freed object).
		_death_tween = create_tween()
		_death_tween.tween_interval(_full_frame_death_duration())
		_death_tween.tween_callback(_finish_death_lifecycle)
		return
	# Нет полнокадровой death-анимации (обычные ally без "death"): всё равно гасим
	# рантайм до queue_free, иначе мёртвый ally остаётся в группе "allies" и ещё кадр
	# двигается/бьёт до фактического удаления. Делаем деактивацию единой для обоих путей.
	_disable_dead_ally_runtime()
	queue_free()


func _finish_death_lifecycle() -> void:
	if is_queued_for_deletion():
		return
	queue_free()


func _exit_tree() -> void:
	# Узел покидает дерево (death-free ИЛИ каскадный force-free родителя) —
	# гасим отложенный death-твин, чтобы его колбэк не сработал по freed-self.
	if _death_tween != null and _death_tween.is_valid():
		_death_tween.kill()
	_death_tween = null


func _play_full_frame_death() -> bool:
	var animated_body := get_node_or_null("AnimatedBody") as AnimatedSprite2D
	if animated_body == null or not animated_body.visible or animated_body.sprite_frames == null:
		return false
	if not animated_body.sprite_frames.has_animation("death"):
		return false
	var direction := Vector2.RIGHT if _last_facing_right else Vector2.LEFT
	return FullFrameAnimationRegistry.play_state(animated_body, "death", direction)


func _full_frame_death_duration() -> float:
	var animated_body := get_node_or_null("AnimatedBody") as AnimatedSprite2D
	if animated_body == null or animated_body.sprite_frames == null or not animated_body.sprite_frames.has_animation("death"):
		return FULL_FRAME_DEATH_DURATION_FALLBACK
	var frames := animated_body.sprite_frames
	var frame_count := frames.get_frame_count("death")
	var animation_speed := maxf(frames.get_animation_speed("death"), 1.0)
	return clampf(float(frame_count) / animation_speed, 0.25, 1.2)


func _disable_dead_ally_runtime() -> void:
	velocity = Vector2.ZERO
	set_physics_process(false)
	set_process(false)
	if is_in_group("allies"):
		remove_from_group("allies")
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.set_deferred("disabled", true)
