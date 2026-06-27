class_name ClassWeapon
extends Node2D

const SOUND_AMP_TEXTURE := preload("res://assets/sprites/weapons/sound_amp.png")
const POISON_POOL_TEXTURE := preload("res://assets/sprites/effects/poison_pool.png")
const SPARK_POOL_TEXTURE := preload("res://assets/sprites/effects/spark_pool.png")
const BRIAR_POOL_TEXTURE := preload("res://assets/sprites/effects/briar_pool.png")
const TARGET_QUERY := preload("res://scripts/combat_target_query.gd")
const ProgressionData := preload("res://scripts/progression_data.gd")

const DEFAULT_ATTACK_MODE := "sound_wave"
const PRIMARY_CAST_ACTION_MODES := {
	"aoe_projectile": true,
	"homing_curse": true,
	"beam": true,
	"drain_link": true,
}
const EVENT_CAST_ACTION_MODES := {
	"aoe_projectile": true,
	"homing_curse": true,
	"beam": true,
	"dot_beam": true,
	"drain_link": true,
	"priest_prayer_chain": true,
	"bio_symbiote_web": true,
	"engineer_repair_drone": true,
}
const ATTACK_MODE_EXECUTORS := {
	"aoe_projectile": "_exec_aoe_projectile",
	"boomerang": "_exec_boomerang",
	"stab_flurry": "_exec_stab_flurry",
	"dot_beam": "_exec_dot_beam",
	"homing_curse": "_exec_homing_curse",
	"beam": "_exec_beam",
	"drain_link": "_exec_drain_link",
	"sound_wave": "_exec_sound_wave",
	"pulse": "_exec_pulse",
	"amp": "_exec_amp",
	"trap": "_exec_trap",
	"suppression_burst": "_exec_suppression_burst",
	"grenade_cook": "_exec_grenade_cook",
	"bayonet_brace": "_exec_bayonet_brace",
	"coin_ricochet": "_exec_coin_ricochet",
	"shadow_backstab": "_exec_shadow_backstab",
	"smoke_bomb": "_exec_smoke_bomb",
	"elemental_orbit": "_exec_elemental_orbit",
	"prism_rift": "_exec_prism_rift",
	"meteor_shards": "_exec_meteor_shards",
	"sniper_lockshot": "_exec_sniper_lockshot",
	"sniper_kill_zone": "_exec_sniper_kill_zone",
	"sniper_split_round": "_exec_sniper_split_round",
	"priest_sanctify": "_exec_priest_sanctify",
	"priest_ward": "_exec_priest_ward",
	"priest_prayer_chain": "_exec_priest_prayer_chain",
	"bio_spore_bloom": "_exec_bio_spore_bloom",
	"bio_sample_dart": "_exec_bio_sample_dart",
	"bio_symbiote_web": "_exec_bio_symbiote_web",
	"robot_magnetic_anchor": "_exec_robot_magnetic_anchor",
	"robot_compression_line": "_exec_robot_compression_line",
	"robot_reactor_vent": "_exec_robot_reactor_vent",
	"engineer_sentry_link": "_exec_engineer_sentry_link",
	"engineer_repair_drone": "_exec_engineer_repair_drone",
	"engineer_pressure_mines": "_exec_engineer_pressure_mines",
}

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
@export var burst_interval := 0.08
@export var grenade_delay := 0.42
@export var brace_duration := 0.34
@export var suppression_width := 120.0
@export var damage_falloff := 0.55
@export var steal_money := 0
@export var dodge_bonus := 0.0
@export var smoke_duration := 1.8
@export var orbit_duration := 1.6
@export var storm_ticks := 4
@export var shard_count := 3
@export var split_count := 3
@export var mark_duration := 1.2
@export var amp_lifetime := 7.0
@export var amp_pulse_interval := 1.1
@export var max_summons := 0
@export var heal_percent_on_attack := 0.0
@export var heal_percent_of_damage := 0.0
@export var leaves_pool := false
@export var pool_element := ""
@export var combo_clouds := false
@export var pool_duration := 3.0
@export var pool_tick_interval := 0.6
@export var charge_seconds := 0.0
@export var charge_max_multiplier := 1.0
@export var crit_shadow_burst_radius := 0.0
@export var melee_close_bonus_radius := 0.0
@export var melee_close_damage_multiplier := 1.0
@export var melee_execute_threshold := 0.0
@export var melee_execute_multiplier := 1.0
@export var melee_stagger_knockback_multiplier := 0.0
@export var melee_arc_followup_radius := 0.0
@export var melee_arc_followup_multiplier := 0.0
@export var melee_heal_percent_on_hit := 0.0
@export var summon_role := ""
@export var summon_role_damage_multiplier := 1.0
@export var summon_support_heal_percent := 0.0
@export var summon_control_knockback := 0.0
@export var deploy_texture_path := ""
@export var visual_color := Color(0.5, 0.8, 1.0, 0.35)

var _cooldown := 0.0
var _last_direction := Vector2.RIGHT
var _last_attack_crit := false
var _charge_time := 0.0
var _current_charge_multiplier := 1.0
var _deployed_amps: Array[Node] = []
var _spawned_effects: Array[Node] = []
var _effects_shutdown := false


static func registered_attack_modes() -> Array:
	return ATTACK_MODE_EXECUTORS.keys()


static func has_attack_mode_executor(mode: String) -> bool:
	return ATTACK_MODE_EXECUTORS.has(mode)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("player_weapons")
	_capture_base_values()


func _exit_tree() -> void:
	cleanup_effects()


func cleanup_effects() -> void:
	_effects_shutdown = true
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
	burst_interval = float(config.get("burst_interval", burst_interval))
	grenade_delay = float(config.get("grenade_delay", grenade_delay))
	brace_duration = float(config.get("brace_duration", brace_duration))
	suppression_width = float(config.get("suppression_width", suppression_width))
	damage_falloff = float(config.get("damage_falloff", damage_falloff))
	steal_money = int(config.get("steal_money", steal_money))
	dodge_bonus = float(config.get("dodge_bonus", dodge_bonus))
	smoke_duration = float(config.get("smoke_duration", smoke_duration))
	orbit_duration = float(config.get("orbit_duration", orbit_duration))
	storm_ticks = int(config.get("storm_ticks", storm_ticks))
	shard_count = int(config.get("shard_count", shard_count))
	split_count = int(config.get("split_count", split_count))
	mark_duration = float(config.get("mark_duration", mark_duration))
	amp_lifetime = float(config.get("amp_lifetime", amp_lifetime))
	amp_pulse_interval = float(config.get("amp_pulse_interval", amp_pulse_interval))
	max_summons = int(config.get("max_summons", max_summons))
	heal_percent_on_attack = float(config.get("heal_percent_on_attack", heal_percent_on_attack))
	heal_percent_of_damage = float(config.get("heal_percent_of_damage", heal_percent_of_damage))
	leaves_pool = bool(config.get("leaves_pool", leaves_pool))
	pool_element = str(config.get("pool_element", pool_element))
	combo_clouds = bool(config.get("combo_clouds", combo_clouds))
	pool_duration = float(config.get("pool_duration", pool_duration))
	pool_tick_interval = float(config.get("pool_tick_interval", pool_tick_interval))
	charge_seconds = float(config.get("charge_seconds", charge_seconds))
	charge_max_multiplier = float(config.get("charge_max_multiplier", charge_max_multiplier))
	crit_shadow_burst_radius = float(config.get("crit_shadow_burst_radius", config.get("dash_on_crit_distance", crit_shadow_burst_radius)))
	melee_close_bonus_radius = float(config.get("melee_close_bonus_radius", melee_close_bonus_radius))
	melee_close_damage_multiplier = float(config.get("melee_close_damage_multiplier", melee_close_damage_multiplier))
	melee_execute_threshold = float(config.get("melee_execute_threshold", melee_execute_threshold))
	melee_execute_multiplier = float(config.get("melee_execute_multiplier", melee_execute_multiplier))
	melee_stagger_knockback_multiplier = float(config.get("melee_stagger_knockback_multiplier", melee_stagger_knockback_multiplier))
	melee_arc_followup_radius = float(config.get("melee_arc_followup_radius", melee_arc_followup_radius))
	melee_arc_followup_multiplier = float(config.get("melee_arc_followup_multiplier", melee_arc_followup_multiplier))
	melee_heal_percent_on_hit = float(config.get("melee_heal_percent_on_hit", melee_heal_percent_on_hit))
	summon_role = str(config.get("summon_role", summon_role))
	summon_role_damage_multiplier = float(config.get("summon_role_damage_multiplier", summon_role_damage_multiplier))
	summon_support_heal_percent = float(config.get("summon_support_heal_percent", summon_support_heal_percent))
	summon_control_knockback = float(config.get("summon_control_knockback", summon_control_knockback))
	deploy_texture_path = str(config.get("deploy_texture_path", deploy_texture_path))
	visual_color = config.get("visual_color", visual_color)
	_capture_base_values()


func _process(delta: float) -> void:
	# Направление атаки задает только ближайший враг; движение влияет
	# только на walk-анимацию персонажа.
	_update_charge(delta)
	_cooldown -= delta
	if _cooldown > 0.0:
		return

	_attack()


func _attack() -> void:
	var owner_node := _owner_node()
	if owner_node == null:
		return

	var cursor_aim := _owner_uses_cursor_aim(owner_node)
	var target: Node2D = null if cursor_aim else _find_closest_enemy(owner_node)
	var direction := _last_direction
	if target != null:
		direction = (target.global_position - owner_node.global_position).normalized()
	elif not cursor_aim:
		# Вне радиуса целимся в ближайшего врага на арене, чтобы удар не уходил «в никуда».
		var distant_enemy := _find_closest_enemy(owner_node, INF)
		if distant_enemy != null:
			direction = (distant_enemy.global_position - owner_node.global_position).normalized()
	if cursor_aim and owner_node.has_method("attack_aim_direction"):
		direction = owner_node.call("attack_aim_direction", direction, attack_range)
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	_last_direction = direction
	_cooldown = fire_interval

	if owner_node.has_method("play_action_animation"):
		owner_node.play_action_animation(_primary_action_animation_for_mode(), direction)
	_emit_weapon_animation_event(owner_node, "windup", _estimated_windup_duration(), direction)

	if heal_percent_on_attack > 0.0 and owner_node.has_method("heal_percent"):
		owner_node.heal_percent(heal_percent_on_attack * ProgressionData.WEAPON_DRAIN_HEAL_MULTIPLIER)

	_current_charge_multiplier = _charge_multiplier()
	_execute_attack_mode(owner_node, target, direction)
	if charge_seconds > 0.0:
		_charge_time = 0.0
	_current_charge_multiplier = 1.0


func _primary_action_animation_for_mode() -> String:
	return "cast" if PRIMARY_CAST_ACTION_MODES.has(attack_mode) else "shoot"


func _event_action_animation_for_mode() -> String:
	return "cast" if EVENT_CAST_ACTION_MODES.has(attack_mode) else "shoot"


func _execute_attack_mode(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_spawn_weapon_signature(owner_node, target, direction)
	var executor_name := str(ATTACK_MODE_EXECUTORS.get(attack_mode, ATTACK_MODE_EXECUTORS[DEFAULT_ATTACK_MODE]))
	call(executor_name, owner_node, target, direction)


func _spawn_weapon_signature(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	if owner_node == null or direction.length_squared() <= 0.001:
		return
	var center := owner_node.global_position + direction * minf(maxf(aoe_radius * 0.55, 72.0), 180.0)
	var radius := maxf(aoe_radius, beam_width * 1.4)
	match attack_mode:
		"pulse", "priest_ward", "elemental_orbit", "robot_reactor_vent":
			center = owner_node.global_position
		"amp", "trap", "engineer_sentry_link", "engineer_pressure_mines":
			center = owner_node.global_position + direction * minf(attack_range, 150.0)
		"grenade_cook", "smoke_bomb", "prism_rift", "meteor_shards", "sniper_kill_zone", "priest_sanctify", "bio_spore_bloom", "robot_magnetic_anchor":
			center = owner_node.global_position + direction * minf(attack_range, 360.0)
			if target != null:
				center = target.global_position
		"beam", "dot_beam", "suppression_burst", "sniper_lockshot", "sniper_split_round", "bayonet_brace", "robot_compression_line":
			center = owner_node.global_position + direction * minf(attack_range * 0.45, 240.0)
			radius = maxf(beam_width * 2.2, 86.0)
		"drain_link", "coin_ricochet", "priest_prayer_chain", "bio_symbiote_web", "engineer_repair_drone":
			center = owner_node.global_position + direction * minf(attack_range * 0.32, 190.0)
			if target != null:
				center = (owner_node.global_position + target.global_position) * 0.5
			radius = maxf(beam_width * 2.4, 96.0)
	var signature := AttackVfx.weapon_signature(_projectile_parent(), center, weapon_id, radius, visual_color, direction.angle())
	if signature != null:
		_register_effect(signature)


func _exec_aoe_projectile(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_aoe_projectile(owner_node, target, direction)


func _exec_boomerang(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_boomerang(owner_node, direction)


func _exec_stab_flurry(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_stab_flurry(owner_node, direction)


func _exec_dot_beam(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_dot_beam(owner_node, direction)


func _exec_homing_curse(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_curse(owner_node, target, direction)


func _exec_beam(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_beam(owner_node, direction)


func _exec_drain_link(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_drain_link(owner_node, target, direction)


func _exec_sound_wave(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_sound_wave(owner_node, direction)


func _exec_pulse(owner_node: Node2D, _target: Node2D, _direction: Vector2) -> void:
	_fire_pulse(owner_node, owner_node.global_position)


func _exec_amp(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_amp(owner_node, direction)


func _exec_trap(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_trap(owner_node, direction)


func _exec_suppression_burst(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_suppression_burst(owner_node, direction)


func _exec_grenade_cook(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_grenade_cook(owner_node, target, direction)


func _exec_bayonet_brace(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_bayonet_brace(owner_node, direction)


func _exec_coin_ricochet(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_coin_ricochet(owner_node, target, direction)


func _exec_shadow_backstab(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_shadow_backstab(owner_node, target, direction)


func _exec_smoke_bomb(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_smoke_bomb(owner_node, target, direction)


func _exec_elemental_orbit(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_elemental_orbit(owner_node, direction)


func _exec_prism_rift(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_prism_rift(owner_node, target, direction)


func _exec_meteor_shards(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_meteor_shards(owner_node, target, direction)


func _exec_sniper_lockshot(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_sniper_lockshot(owner_node, target, direction)


func _exec_sniper_kill_zone(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_sniper_kill_zone(owner_node, target, direction)


func _exec_sniper_split_round(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_sniper_split_round(owner_node, target, direction)


func _exec_priest_sanctify(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_priest_sanctify(owner_node, target, direction)


func _exec_priest_ward(owner_node: Node2D, _target: Node2D, _direction: Vector2) -> void:
	_fire_priest_ward(owner_node)


func _exec_priest_prayer_chain(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_priest_prayer_chain(owner_node, target, direction)


func _exec_bio_spore_bloom(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_bio_spore_bloom(owner_node, target, direction)


func _exec_bio_sample_dart(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_bio_sample_dart(owner_node, target, direction)


func _exec_bio_symbiote_web(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_bio_symbiote_web(owner_node, target, direction)


func _exec_robot_magnetic_anchor(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_robot_magnetic_anchor(owner_node, target, direction)


func _exec_robot_compression_line(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_robot_compression_line(owner_node, target, direction)


func _exec_robot_reactor_vent(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_robot_reactor_vent(owner_node, direction)


func _exec_engineer_sentry_link(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_engineer_sentry_link(owner_node, direction)


func _exec_engineer_repair_drone(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_engineer_repair_drone(owner_node, target, direction)


func _exec_engineer_pressure_mines(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_engineer_pressure_mines(owner_node, direction)


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


func _fire_stab_flurry(owner_node: Node2D, direction: Vector2) -> void:
	# Быстрый ближний веер: несколько целей в короткой зоне перед персонажем.
	var slash := AttackVfx.slash(owner_node, direction, attack_range, visual_color)
	_register_effect(slash)
	var candidates := []
	for enemy_node in TARGET_QUERY.enemies(self):
		if not is_instance_valid(enemy_node):
			continue
		if not _is_enemy_inside_wave(owner_node.global_position, enemy_node.global_position, direction):
			continue
		candidates.append({
			"node": enemy_node,
			"distance": owner_node.global_position.distance_squared_to(enemy_node.global_position),
		})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distance"]) < float(b["distance"])
	)
	var damage_value := _rolled_damage(owner_node)
	var hit_limit := maxi(projectile_count, 1)
	var hit_count := 0
	for candidate in candidates:
		if hit_count >= hit_limit:
			break
		var enemy_node := candidate["node"] as Node2D
		if dot_ticks > 0:
			_damage_enemy_with_dot(enemy_node, damage_value, owner_node)
		else:
			_damage_enemy(enemy_node, damage_value)
		hit_count += 1


func _damage_enemies_in_corridor(origin: Vector2, direction: Vector2, amount: float) -> void:
	for hit in TARGET_QUERY.in_corridor(self, origin, direction, beam_width, attack_range):
		_damage_enemy(hit["node"], amount)


func _spawn_damage_pool(pool_position: Vector2, tick_damage: float) -> void:
	# Ядовитое облако химика: тики по врагам в радиусе, группа player_weapon_effects.
	var combo_target := _find_combo_cloud(pool_position)
	var pool := Node2D.new()
	pool.name = "ChemistPoisonPool"
	_register_effect(pool)
	pool.add_to_group("chemist_clouds")
	if pool_element != "":
		pool.set_meta("pool_element", pool_element)
	pool.z_index = 5
	var visual := Node2D.new()
	visual.name = "PoolVisual"
	var pool_sprite := Sprite2D.new()
	pool_sprite.name = "PoolSprite"
	pool_sprite.texture = _pool_visual_texture()
	pool_sprite.modulate = Color(1.0, 1.0, 1.0, 0.82)
	var pool_scale := (aoe_radius * 1.42) / 256.0
	pool_sprite.scale = Vector2.ONE * pool_scale
	visual.add_child(pool_sprite)
	pool.add_child(visual)
	_projectile_parent().add_child(pool)
	pool.global_position = pool_position
	if combo_target != null:
		_trigger_chemist_combo(pool, combo_target, tick_damage)

	var visual_tween := pool.create_tween()
	visual_tween.set_loops()
	visual_tween.tween_property(pool_sprite, "scale", Vector2.ONE * pool_scale * 1.045, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	visual_tween.parallel().tween_property(pool_sprite, "rotation", 0.045, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	visual_tween.tween_property(pool_sprite, "scale", Vector2.ONE * pool_scale * 0.985, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	visual_tween.parallel().tween_property(pool_sprite, "rotation", -0.035, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var tick_count := int(floor(pool_duration / maxf(pool_tick_interval, 0.2)))
	var pool_tween := pool.create_tween()
	var pool_id := pool.get_instance_id()
	var weapon_id := get_instance_id()
	for tick_index in range(tick_count):
		pool_tween.tween_interval(pool_tick_interval)
		pool_tween.tween_callback(func() -> void:
			var current_weapon := instance_from_id(weapon_id) as Node
			var current_pool := instance_from_id(pool_id) as Node2D
			if current_weapon != null and current_pool != null:
				current_weapon.call("_damage_enemies_in_pool", current_pool.global_position, aoe_radius * 0.7, tick_damage)
		)
	pool_tween.tween_property(pool_sprite, "modulate:a", 0.0, 0.2)
	pool_tween.tween_callback(func() -> void:
		var current_weapon := instance_from_id(weapon_id) as Node
		var current_pool := instance_from_id(pool_id) as Node
		if current_pool == null:
			return
		if current_weapon != null:
			current_pool.remove_from_group("chemist_clouds")
			current_weapon.call("_release_effect", current_pool)
		else:
			current_pool.queue_free()
	)


func _pool_visual_texture() -> Texture2D:
	match pool_element:
		"spark":
			return SPARK_POOL_TEXTURE
		"briar":
			return BRIAR_POOL_TEXTURE
		_:
			return POISON_POOL_TEXTURE


func _find_combo_cloud(pool_position: Vector2) -> Node2D:
	if not combo_clouds:
		return null
	for cloud in get_tree().get_nodes_in_group("chemist_clouds"):
		var cloud_node := cloud as Node2D
		if cloud_node == null or not is_instance_valid(cloud_node):
			continue
		var cloud_element := str(cloud_node.get_meta("pool_element", ""))
		if pool_element != "" and cloud_element == pool_element:
			continue
		if cloud_node.global_position.distance_squared_to(pool_position) <= pow(aoe_radius * 0.95, 2.0):
			return cloud_node
	return null


func _trigger_chemist_combo(new_cloud: Node2D, old_cloud: Node2D, tick_damage: float) -> void:
	var combo_position := (new_cloud.global_position + old_cloud.global_position) * 0.5
	var combo_radius := aoe_radius * 1.05
	var combo_damage := maxf(damage, tick_damage * 5.5)
	AttackVfx.orb_burst(_projectile_parent(), combo_position, combo_radius, Color(1.0, 0.75, 0.16, 0.50))
	_damage_enemies_in_circle(combo_position, combo_radius, combo_damage)


func _find_closest_enemies(owner_node: Node2D, count: int) -> Array:
	return TARGET_QUERY.nearest_many(self, owner_node.global_position, attack_range, count)


func _launch_aoe_projectile(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var target_position: Vector2 = owner_node.global_position + direction * min(attack_range, 360.0)
	if target != null:
		target_position = target.global_position
	elif _owner_uses_cursor_aim(owner_node) and owner_node.has_method("attack_aim_position"):
		target_position = owner_node.call("attack_aim_position", attack_range)

	var projectile := AttackVfx.orb_projectile(_projectile_parent(), owner_node.global_position + direction * 28.0, visual_color)
	_register_effect(projectile)

	var travel_time: float = clamp(projectile.global_position.distance_to(target_position) / max(projectile_speed, 1.0), 0.08, 0.45)
	var tween := create_tween()
	var projectile_id := projectile.get_instance_id()
	var owner_id := owner_node.get_instance_id()
	var weapon_id := get_instance_id()
	tween.tween_property(projectile, "global_position", target_position, travel_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		var current_weapon := instance_from_id(weapon_id) as Node
		if current_weapon != null:
			var current_owner := instance_from_id(owner_id) as Node2D
			var explosion_damage := damage if current_owner == null else float(current_weapon.call("_rolled_damage", current_owner))
			current_weapon.call("_damage_enemies_in_circle", target_position, aoe_radius, explosion_damage)
			AttackVfx.orb_burst(current_weapon.call("_projectile_parent"), target_position, aoe_radius, visual_color)
			if leaves_pool:
				var parameters_raw = current_owner.get("derived_parameters") if current_owner != null else null
				var tick_damage := 2.0
				if parameters_raw is Dictionary:
					tick_damage = maxf(float((parameters_raw as Dictionary).get("dot_damage", 2.0)), 1.0)
				current_weapon.call("_spawn_damage_pool", target_position, tick_damage)
			var current_projectile := instance_from_id(projectile_id) as Node
			if current_projectile != null:
				current_weapon.call("_release_effect", current_projectile)
	)


func _fire_curse(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	if target == null:
		var miss_target: Vector2 = owner_node.global_position + direction * min(attack_range, 260.0)
		var miss_skull := AttackVfx.curse_skull(_projectile_parent(), owner_node.global_position + direction * 24.0, miss_target, visual_color, 0.22, Callable())
		_register_effect(miss_skull)
		return

	var target_position := target.global_position
	var rolled := _rolled_damage(owner_node)
	var target_id := target.get_instance_id()
	var owner_id := owner_node.get_instance_id()
	var weapon_id := get_instance_id()
	var skull := AttackVfx.curse_skull(_projectile_parent(), owner_node.global_position + direction * 24.0, target_position, visual_color, 0.20, func() -> void:
		var current_weapon := instance_from_id(weapon_id) as Node
		if current_weapon == null:
			return
		var current_target := instance_from_id(target_id) as Node2D
		var current_owner := instance_from_id(owner_id) as Node2D
		if current_target != null:
			current_weapon.call("_damage_enemy_with_dot", current_target, rolled, current_owner)
		if aoe_radius > 0.0:
			current_weapon.call("_damage_enemies_in_circle", target_position, aoe_radius * 0.72, rolled * 0.42)
			AttackVfx.orb_burst(current_weapon.call("_projectile_parent"), target_position, aoe_radius * 0.72, visual_color)
	)
	_register_effect(skull)


func _fire_beam(owner_node: Node2D, direction: Vector2) -> void:
	# Веер из beam_count лучей с шагом beam_fan_degrees, центрированный на цели.
	# «Ядро Расщепления» (tier 3): extra_projectile добавляет луч/снаряд.
	var count := maxi(beam_count + _extra_projectiles(), 1)
	_emit_weapon_animation_event(owner_node, "channel", 0.16, direction, {"beam_count": count})
	for beam_index in range(count):
		var fan_offset := 0.0
		if count > 1:
			fan_offset = deg_to_rad(beam_fan_degrees) * (float(beam_index) - float(count - 1) * 0.5)
		_fire_single_beam(owner_node, direction.rotated(fan_offset))


func _fire_dot_beam(owner_node: Node2D, direction: Vector2) -> void:
	var count := maxi(beam_count + _extra_projectiles(), 1)
	_emit_weapon_animation_event(owner_node, "channel", maxf(0.16, float(maxi(dot_ticks, 1)) * 0.04), direction, {"beam_count": count, "dot_ticks": dot_ticks})
	for beam_index in range(count):
		var fan_offset := 0.0
		if count > 1:
			fan_offset = deg_to_rad(beam_fan_degrees) * (float(beam_index) - float(count - 1) * 0.5)
		_fire_single_dot_beam(owner_node, direction.rotated(fan_offset))


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


func _fire_single_dot_beam(owner_node: Node2D, direction: Vector2) -> void:
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
		_damage_enemy_with_dot(hit["node"], damage_value, owner_node)
		hit_count += 1


func _fire_drain_link(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_emit_weapon_animation_event(owner_node, "channel", 0.20, direction, {"chain": true})
	var finish: Vector2 = owner_node.global_position + direction * min(attack_range, 520.0)
	if target != null:
		finish = target.global_position
	var start := owner_node.global_position + direction * 24.0
	var link_visual := AttackVfx.beam(_projectile_parent(), start, finish, beam_width, visual_color)
	_register_effect(link_visual)
	if target == null:
		return

	var damage_value := _rolled_damage(owner_node)
	if dot_ticks > 0:
		_damage_enemy_with_dot(target, damage_value, owner_node)
	else:
		_damage_enemy(target, damage_value)


func _heal_owner_from_damage(owner_node: Node2D, dealt_damage: float) -> void:
	if heal_percent_of_damage <= 0.0 or owner_node == null or not is_instance_valid(owner_node):
		return
	if owner_node.get("health") == null or owner_node.get("max_health") == null:
		return
	var heal_amount := dealt_damage * heal_percent_of_damage * ProgressionData.WEAPON_DRAIN_HEAL_MULTIPLIER
	if heal_amount <= 0.0:
		return
	# SCRUM-517: drain-heal обязан уважать per-second бюджет (как вампиризм), иначе
	# Доктор бессмертен (DoT-стак чумы × число целей лил сотни HP/с прямо в health).
	# Маршрутизируем через capped-метод игрока; для owner-ов без него (саммоны и т.п.)
	# сохраняем прежнее прямое поведение, чтобы не сломать чужой sustain.
	var healed := 0.0
	if owner_node.has_method("apply_drain_heal"):
		healed = float(owner_node.call("apply_drain_heal", heal_amount))
	else:
		var before := float(owner_node.get("health"))
		owner_node.set("health", minf(before + heal_amount, float(owner_node.get("max_health"))))
		healed = float(owner_node.get("health")) - before
	if healed > 0.01 and owner_node.has_method("show_combat_feedback_number"):
		owner_node.show_combat_feedback_number(healed, "heal")


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
	_emit_weapon_animation_event(owner_node, "deploy", amp_lifetime, direction, {"pulse_interval": amp_pulse_interval})
	# Деплой: усилитель ставится на землю, живет amp_lifetime секунд и пульсирует
	# самостоятельно. Лимит одновременных ампов растет от Лидерства через
	# max_summons (player._apply_weapon_scaling: base + floor(leadership / 4)).
	_deployed_amps = _deployed_amps.filter(func(amp: Node) -> bool:
		return amp != null and is_instance_valid(amp)
	)

	var amp := Node2D.new()
	amp.name = "SoundAmpPulseNode"
	amp.add_to_group("deployed_sound_amps")
	amp.z_index = 5
	var amp_visual := Sprite2D.new()
	amp_visual.texture = _deploy_visual_texture()
	amp_visual.scale = Vector2(0.42, 0.42)
	amp.add_child(amp_visual)
	_projectile_parent().add_child(amp)
	_register_effect(amp)
	amp.global_position = owner_node.global_position + direction * 92.0
	_deployed_amps.append(amp)

	var amp_limit := maxi(max_summons, 1)
	while _deployed_amps.size() > amp_limit:
		var oldest: Node = _deployed_amps.pop_front()
		_release_effect(oldest)

	var pulse_tween := amp.create_tween()
	var pulse_count := maxi(int(floor(amp_lifetime / maxf(amp_pulse_interval, 0.2))), 1)
	var amp_id := amp.get_instance_id()
	var weapon_id := get_instance_id()
	for pulse_index in range(pulse_count):
		pulse_tween.tween_interval(amp_pulse_interval)
		pulse_tween.tween_callback(func() -> void:
			var current_weapon := instance_from_id(weapon_id) as Node
			var current_amp := instance_from_id(amp_id) as Node2D
			if current_weapon != null and current_amp != null and not bool(current_weapon.get("_effects_shutdown")):
				var current_owner := current_weapon.call("_owner_node") as Node2D
				if current_owner != null:
					var pulse_direction := current_amp.global_position - current_owner.global_position
					current_weapon.call("_emit_weapon_animation_event", current_owner, "pulse", maxf(float(current_weapon.get("amp_pulse_interval")), 0.2), pulse_direction.normalized(), {"index": pulse_index, "count": pulse_count})
				current_weapon.call("_fire_pulse", current_owner, current_amp.global_position)
		)
	pulse_tween.tween_callback(func() -> void:
		var current_weapon := instance_from_id(weapon_id) as Node
		var current_amp := instance_from_id(amp_id) as Node
		if current_amp == null:
			return
		if current_weapon != null:
			var amps: Array = current_weapon.get("_deployed_amps")
			amps.erase(current_amp)
			current_weapon.call("_release_effect", current_amp)
		else:
			current_amp.queue_free()
	)

	# Первый пульс сразу при установке.
	_emit_weapon_animation_event(owner_node, "pulse", maxf(amp_pulse_interval, 0.2), direction, {"index": 0, "count": pulse_count})
	_fire_pulse(owner_node, amp.global_position)


func _fire_trap(owner_node: Node2D, direction: Vector2) -> void:
	_emit_weapon_animation_event(owner_node, "deploy", pool_duration, direction, {"check_interval": pool_tick_interval})
	var trap := Node2D.new()
	trap.name = "WeaponTrapNode"
	_register_effect(trap)
	trap.z_index = 5
	var trap_visual := Sprite2D.new()
	trap_visual.texture = _weapon_visual_texture()
	trap_visual.scale = Vector2(0.34, 0.34)
	trap.add_child(trap_visual)
	_projectile_parent().add_child(trap)
	trap.global_position = owner_node.global_position + direction * min(attack_range, 180.0)

	var state := {"triggered": false}
	var check_interval := maxf(pool_tick_interval, 0.15)
	var check_count := maxi(int(floor(pool_duration / check_interval)), 1)
	var trap_tween := trap.create_tween()
	var trap_id := trap.get_instance_id()
	var owner_id := owner_node.get_instance_id()
	var weapon_id := get_instance_id()
	for check_index in range(check_count):
		trap_tween.tween_interval(check_interval)
		trap_tween.tween_callback(func() -> void:
			var current_weapon := instance_from_id(weapon_id) as Node
			var current_trap := instance_from_id(trap_id) as Node2D
			if current_weapon == null or current_trap == null or bool(state["triggered"]):
				return
			if not current_weapon.call("_has_enemy_in_circle", current_trap.global_position, aoe_radius):
				return
			state["triggered"] = true
			var current_owner := instance_from_id(owner_id) as Node2D
			var trap_damage: float = float(current_weapon.call("_rolled_damage", current_owner)) if current_owner != null else damage
			current_weapon.call("_damage_enemies_in_circle", current_trap.global_position, aoe_radius, trap_damage)
			AttackVfx.ring_pulse(current_weapon.call("_projectile_parent"), current_trap.global_position, aoe_radius, visual_color, false)
			for enemy in current_weapon.get_tree().get_nodes_in_group("enemies"):
				var enemy_node := enemy as Node2D
				if enemy_node == null or not is_instance_valid(enemy_node):
					continue
				var away := enemy_node.global_position - current_trap.global_position
				if away.length_squared() > 0.001 and away.length() <= aoe_radius:
					current_weapon.call("_push_enemy", enemy_node, away.normalized())
			current_weapon.call("_release_effect", current_trap)
		)
	trap_tween.tween_callback(func() -> void:
		var current_weapon := instance_from_id(weapon_id) as Node
		var current_trap := instance_from_id(trap_id) as Node
		if current_trap == null:
			return
		if current_weapon != null and not bool(state["triggered"]):
			current_weapon.call("_release_effect", current_trap)
		else:
			current_trap.queue_free()
		)


func _fire_suppression_burst(owner_node: Node2D, direction: Vector2) -> void:
	var count := maxi(projectile_count + _extra_projectiles(), 1)
	_emit_weapon_animation_event(owner_node, "burst", maxf(burst_interval, 0.02) * float(maxi(count - 1, 1)), direction, {"count": count})
	var weapon_id := get_instance_id()
	var owner_id := owner_node.get_instance_id()
	var burst_tween := create_tween()
	for burst_index in range(count):
		if burst_index > 0:
			burst_tween.tween_interval(maxf(burst_interval, 0.02))
		burst_tween.tween_callback(func() -> void:
			var current_weapon := instance_from_id(weapon_id) as Node
			var current_owner := instance_from_id(owner_id) as Node2D
			if current_weapon == null or current_owner == null:
				return
			current_weapon.call("_emit_weapon_animation_event", current_owner, "pulse", maxf(float(current_weapon.get("burst_interval")), 0.02), direction, {"index": burst_index, "count": count})
			current_weapon.call("_fire_suppression_round", current_owner, direction)
		)


func _fire_suppression_round(owner_node: Node2D, direction: Vector2) -> void:
	var start := owner_node.global_position + direction * 28.0
	var finish := owner_node.global_position + direction * attack_range
	var tracer := AttackVfx.beam(_projectile_parent(), start, finish, beam_width, visual_color)
	_register_effect(tracer)
	var hits := _enemies_in_corridor(start, direction, suppression_width, attack_range)
	if hits.is_empty():
		return
	var damage_value := _rolled_damage(owner_node)
	var primary := hits[0]["node"] as Node2D
	_damage_enemy(primary, damage_value)
	for hit_index in range(1, mini(hits.size(), 4)):
		_damage_enemy(hits[hit_index]["node"], damage_value * damage_falloff)
		_push_enemy(hits[hit_index]["node"], direction)


func _fire_grenade_cook(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_emit_weapon_animation_event(owner_node, "windup", maxf(grenade_delay, 0.10), direction, {"delayed": true})
	var target_position: Vector2 = owner_node.global_position + direction * min(attack_range, 440.0)
	if target != null:
		target_position = target.global_position
	var telegraph := AttackVfx.ring_pulse(_projectile_parent(), target_position, aoe_radius, visual_color, true)
	_register_effect(telegraph)
	var grenade := AttackVfx.orb_projectile(_projectile_parent(), owner_node.global_position + direction * 26.0, visual_color)
	_register_effect(grenade)
	var weapon_id := get_instance_id()
	var owner_id := owner_node.get_instance_id()
	var tween := create_tween()
	tween.tween_property(grenade, "global_position", target_position, maxf(grenade_delay * 0.55, 0.08)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(maxf(grenade_delay * 0.45, 0.04))
	tween.tween_callback(func() -> void:
		var current_weapon := instance_from_id(weapon_id) as Node
		var current_owner := instance_from_id(owner_id) as Node2D
		if current_weapon == null:
			if is_instance_valid(grenade):
				grenade.queue_free()
			return
		var explosion_damage := damage if current_owner == null else float(current_weapon.call("_rolled_damage", current_owner))
		if current_owner != null:
			current_weapon.call("_emit_weapon_animation_event", current_owner, "release", 0.0, direction, {"delayed": true})
		current_weapon.call("_damage_enemies_in_circle_falloff", target_position, aoe_radius, explosion_damage, damage_falloff)
		AttackVfx.orb_burst(current_weapon.call("_projectile_parent"), target_position, aoe_radius, visual_color)
		current_weapon.call("_release_effect", grenade)
		current_weapon.call("_release_effect", telegraph)
	)


func _fire_bayonet_brace(owner_node: Node2D, direction: Vector2) -> void:
	var brace_visual := AttackVfx.slash(owner_node, direction, attack_range, visual_color)
	_register_effect(brace_visual)
	var state := {"hit_ids": {}}
	var checks := maxi(int(ceil(brace_duration / 0.08)), 1)
	var weapon_id := get_instance_id()
	var owner_id := owner_node.get_instance_id()
	var brace_tween := create_tween()
	for check_index in range(checks):
		if check_index > 0:
			brace_tween.tween_interval(brace_duration / float(checks))
		brace_tween.tween_callback(func() -> void:
			var current_weapon := instance_from_id(weapon_id) as Node
			var current_owner := instance_from_id(owner_id) as Node2D
			if current_weapon == null or current_owner == null:
				return
			current_weapon.call("_damage_bayonet_corridor_once", current_owner, direction, state)
		)


func _damage_bayonet_corridor_once(owner_node: Node2D, direction: Vector2, state: Dictionary) -> void:
	var origin := owner_node.global_position + direction * 18.0
	var hit_ids: Dictionary = state.get("hit_ids", {})
	var damage_value := _rolled_damage(owner_node)
	for hit in _enemies_in_corridor(origin, direction, beam_width, attack_range):
		var enemy_node := hit["node"] as Node2D
		if enemy_node == null:
			continue
		var enemy_id := enemy_node.get_instance_id()
		if hit_ids.has(enemy_id):
			continue
		hit_ids[enemy_id] = true
		_damage_enemy(enemy_node, damage_value)
		_push_enemy(enemy_node, direction)
	state["hit_ids"] = hit_ids


func _fire_coin_ricochet(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var current_target := target
	if current_target == null:
		current_target = _find_closest_enemy(owner_node, INF)
	if current_target == null:
		var miss := AttackVfx.orb_projectile(_projectile_parent(), owner_node.global_position + direction * 24.0, visual_color)
		_register_effect(miss)
		var miss_tween := create_tween()
		miss_tween.tween_property(miss, "global_position", owner_node.global_position + direction * min(attack_range, 280.0), 0.18)
		miss_tween.tween_callback(func() -> void:
			_release_effect(miss)
		)
		return

	var chain_targets := [current_target]
	var used := {current_target.get_instance_id(): true}
	var search_origin := current_target.global_position
	var chain_count := maxi(projectile_count + _extra_projectiles(), 1)
	for chain_index in range(chain_count - 1):
		var next_target := _find_nearest_enemy_from(search_origin, attack_range * 0.65, used)
		if next_target == null:
			break
		chain_targets.append(next_target)
		used[next_target.get_instance_id()] = true
		search_origin = next_target.global_position

	var damage_value := _rolled_damage(owner_node)
	var origin := owner_node.global_position + direction * 24.0
	for hit_index in range(chain_targets.size()):
		var enemy_node := chain_targets[hit_index] as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var segment := AttackVfx.beam(_projectile_parent(), origin, enemy_node.global_position, beam_width, visual_color)
		_register_effect(segment)
		var hit_damage := damage_value * pow(clampf(damage_falloff, 0.1, 1.0), float(hit_index))
		_damage_enemy(enemy_node, hit_damage)
		_try_steal_money(owner_node, hit_index)
		origin = enemy_node.global_position


func _fire_shadow_backstab(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var backstab_target := target
	if backstab_target == null:
		backstab_target = _find_closest_enemy(owner_node, INF)
	if backstab_target == null:
		_fire_stab_flurry(owner_node, direction)
		return
	var approach := (backstab_target.global_position - owner_node.global_position).normalized()
	if approach.length_squared() <= 0.001:
		approach = direction
	var start_position := owner_node.global_position
	var back_position := backstab_target.global_position + approach * 46.0
	var shadow_distance := start_position.distance_to(back_position)
	var max_shadow_reach := minf(attack_range, 360.0)
	if shadow_distance > max_shadow_reach:
		back_position = start_position + (back_position - start_position).normalized() * max_shadow_reach
	var strike_direction := (backstab_target.global_position - back_position).normalized()
	if strike_direction.length_squared() <= 0.001:
		strike_direction = -approach
	var slash := AttackVfx.slash(_projectile_parent(), strike_direction, aoe_radius, visual_color)
	_register_effect(slash)
	slash.global_position = back_position
	_damage_enemy(backstab_target, _rolled_damage(owner_node) * 1.22)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_node := enemy as Node2D
		if enemy_node == null or enemy_node == backstab_target or not is_instance_valid(enemy_node):
			continue
		if back_position.distance_squared_to(enemy_node.global_position) <= pow(aoe_radius * 0.55, 2.0):
			_damage_enemy(enemy_node, damage * 0.35)
	var vanish := AttackVfx.ring_pulse(_projectile_parent(), back_position, 62.0, visual_color, false)
	_register_effect(vanish)


func _fire_smoke_bomb(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_emit_weapon_animation_event(owner_node, "windup", maxf(grenade_delay, 0.10), direction, {"delayed": true})
	var target_position: Vector2 = owner_node.global_position + direction * min(attack_range, 240.0)
	if target != null:
		target_position = target.global_position
	var smoke := AttackVfx.ring_pulse(_projectile_parent(), target_position, aoe_radius, visual_color, true)
	_register_effect(smoke)
	_apply_temporary_dodge(owner_node)
	var weapon_id := get_instance_id()
	var owner_id := owner_node.get_instance_id()
	var tween := create_tween()
	tween.tween_interval(maxf(grenade_delay, 0.10))
	tween.tween_callback(func() -> void:
		var current_weapon := instance_from_id(weapon_id) as Node
		var current_owner := instance_from_id(owner_id) as Node2D
		if current_weapon == null:
			if is_instance_valid(smoke):
				smoke.queue_free()
			return
		var damage_value := damage if current_owner == null else float(current_weapon.call("_rolled_damage", current_owner))
		if current_owner != null:
			current_weapon.call("_emit_weapon_animation_event", current_owner, "release", maxf(float(current_weapon.get("smoke_duration")), 0.2), direction, {"delayed": true})
		current_weapon.call("_damage_enemies_in_circle", target_position, aoe_radius, damage_value)
		AttackVfx.orb_burst(current_weapon.call("_projectile_parent"), target_position, aoe_radius, visual_color)
	)
	tween.tween_interval(maxf(smoke_duration, 0.2))
	tween.tween_callback(func() -> void:
		var current_weapon := instance_from_id(weapon_id) as Node
		if current_weapon != null:
			current_weapon.call("_release_effect", smoke)
		elif is_instance_valid(smoke):
			smoke.queue_free()
	)


func _fire_elemental_orbit(owner_node: Node2D, direction: Vector2) -> void:
	_emit_weapon_animation_event(owner_node, "channel", orbit_duration, direction, {"ticks": maxi(storm_ticks, 1)})
	var orbit_root := Node2D.new()
	orbit_root.name = "ElementalOrbitNode"
	orbit_root.z_index = 10
	_projectile_parent().add_child(orbit_root)
	_register_effect(orbit_root)
	orbit_root.global_position = owner_node.global_position
	var colors := [
		Color(1.0, 0.42, 0.16, 0.55),
		Color(0.26, 0.76, 1.0, 0.55),
		Color(0.64, 1.0, 0.28, 0.55),
	]
	var orbit_count := maxi(projectile_count + _extra_projectiles(), 3)
	for orb_index in range(orbit_count):
		var orb := Sprite2D.new()
		orb.name = "ElementalOrbitOrb"
		orb.texture = _weapon_visual_texture()
		orb.modulate = colors[orb_index % colors.size()]
		orb.scale = Vector2.ONE * 0.16
		orb.position = Vector2.RIGHT.rotated(TAU * float(orb_index) / float(orbit_count)) * aoe_radius * 0.62
		orbit_root.add_child(orb)
	AttackVfx.ring_pulse(_projectile_parent(), owner_node.global_position, aoe_radius, visual_color, true)
	var ticks := maxi(storm_ticks, 1)
	_damage_enemies_in_circle(owner_node.global_position, aoe_radius, _rolled_damage(owner_node) / float(ticks))
	var weapon_id := get_instance_id()
	var owner_id := owner_node.get_instance_id()
	var orbit_id := orbit_root.get_instance_id()
	var tick_interval := maxf(orbit_duration / float(ticks), 0.08)
	var orbit_tween := create_tween()
	orbit_tween.set_parallel(true)
	orbit_tween.tween_property(orbit_root, "rotation", TAU * 1.35, orbit_duration).set_trans(Tween.TRANS_LINEAR)
	orbit_tween.chain()
	for tick_index in range(ticks):
		if tick_index > 0:
			orbit_tween.tween_interval(tick_interval)
		orbit_tween.tween_callback(func() -> void:
			var current_weapon := instance_from_id(weapon_id) as Node
			var current_owner := instance_from_id(owner_id) as Node2D
			var current_orbit := instance_from_id(orbit_id) as Node2D
			if current_weapon == null or current_owner == null or current_orbit == null:
				return
			current_weapon.call("_emit_weapon_animation_event", current_owner, "pulse", tick_interval, direction, {"index": tick_index, "count": ticks})
			current_orbit.global_position = current_owner.global_position
			var tick_damage := float(current_weapon.call("_rolled_damage", current_owner)) / float(ticks)
			current_weapon.call("_damage_enemies_in_circle", current_owner.global_position, current_weapon.get("aoe_radius"), tick_damage)
		)
	orbit_tween.tween_callback(func() -> void:
		var current_weapon := instance_from_id(weapon_id) as Node
		var current_orbit := instance_from_id(orbit_id) as Node
		if current_orbit == null:
			return
		if current_weapon != null:
			current_weapon.call("_release_effect", current_orbit)
		else:
			current_orbit.queue_free()
	)


func _fire_prism_rift(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_emit_weapon_animation_event(owner_node, "windup", maxf(grenade_delay, 0.12), direction, {"delayed": true})
	var center: Vector2 = owner_node.global_position + direction * min(attack_range, 360.0)
	if target != null:
		center = target.global_position
	var perpendicular := Vector2(-direction.y, direction.x).normalized()
	if perpendicular.length_squared() <= 0.001:
		perpendicular = Vector2.UP
	var side_span := minf(aoe_radius * 1.15, 220.0)
	var start_a := center - perpendicular * side_span - direction * 90.0
	var end_a := center + perpendicular * side_span + direction * 90.0
	var start_b := center + perpendicular * side_span - direction * 90.0
	var end_b := center - perpendicular * side_span + direction * 90.0
	var telegraph := AttackVfx.ring_pulse(_projectile_parent(), center, aoe_radius, visual_color, true)
	_register_effect(telegraph)
	var weapon_id := get_instance_id()
	var owner_id := owner_node.get_instance_id()
	var rift_tween := create_tween()
	rift_tween.tween_interval(maxf(grenade_delay, 0.12))
	rift_tween.tween_callback(func() -> void:
		var current_weapon := instance_from_id(weapon_id) as Node
		var current_owner := instance_from_id(owner_id) as Node2D
		if current_weapon == null:
			return
		if current_owner != null:
			current_weapon.call("_emit_weapon_animation_event", current_owner, "release", 0.0, direction, {"delayed": true})
		var damage_value := damage if current_owner == null else float(current_weapon.call("_rolled_damage", current_owner))
		var color_a := Color(0.26, 0.78, 1.0, 0.50)
		var color_b := Color(1.0, 0.46, 0.20, 0.50)
		var beam_a := AttackVfx.beam(current_weapon.call("_projectile_parent"), start_a, end_a, beam_width, color_a)
		var beam_b := AttackVfx.beam(current_weapon.call("_projectile_parent"), start_b, end_b, beam_width, color_b)
		current_weapon.call("_register_effect", beam_a)
		current_weapon.call("_register_effect", beam_b)
		current_weapon.call("_damage_enemies_in_segment", start_a, end_a, beam_width, damage_value * 0.62)
		current_weapon.call("_damage_enemies_in_segment", start_b, end_b, beam_width, damage_value * 0.62)
		current_weapon.call("_damage_enemies_in_circle", center, beam_width * 0.85, damage_value * 0.55)
		current_weapon.call("_release_effect", telegraph)
	)


func _fire_meteor_shards(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_emit_weapon_animation_event(owner_node, "windup", maxf(grenade_delay, 0.12), direction, {"delayed": true})
	var center: Vector2 = owner_node.global_position + direction * min(attack_range, 430.0)
	if target != null:
		center = target.global_position
	var telegraph := AttackVfx.ring_pulse(_projectile_parent(), center, aoe_radius, visual_color, true)
	_register_effect(telegraph)
	var meteor := AttackVfx.orb_projectile(_projectile_parent(), center + Vector2(0.0, -220.0), visual_color)
	_register_effect(meteor)
	var weapon_id := get_instance_id()
	var owner_id := owner_node.get_instance_id()
	var meteor_id := meteor.get_instance_id()
	var meteor_tween := create_tween()
	meteor_tween.tween_property(meteor, "global_position", center, maxf(grenade_delay, 0.12)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	meteor_tween.tween_callback(func() -> void:
		var current_weapon := instance_from_id(weapon_id) as Node
		var current_owner := instance_from_id(owner_id) as Node2D
		var current_meteor := instance_from_id(meteor_id) as Node
		if current_weapon == null:
			if current_meteor != null:
				current_meteor.queue_free()
			return
		if current_owner != null:
			current_weapon.call("_emit_weapon_animation_event", current_owner, "release", 0.0, direction, {"delayed": true, "shards": int(current_weapon.get("shard_count"))})
		var damage_value := damage if current_owner == null else float(current_weapon.call("_rolled_damage", current_owner))
		current_weapon.call("_damage_enemies_in_circle", center, aoe_radius, damage_value * 0.72)
		AttackVfx.orb_burst(current_weapon.call("_projectile_parent"), center, aoe_radius, visual_color)
		var count: int = maxi(int(current_weapon.get("shard_count")), 1)
		for shard_index in range(count):
			var angle := TAU * float(shard_index) / float(count)
			var shard_pos := center + Vector2.RIGHT.rotated(angle) * aoe_radius * 0.72
			current_weapon.call("_damage_enemies_in_circle", shard_pos, current_weapon.get("beam_width") * 1.45, damage_value * 0.34)
			AttackVfx.orb_burst(current_weapon.call("_projectile_parent"), shard_pos, current_weapon.get("beam_width") * 1.45, current_weapon.get("visual_color"))
		current_weapon.call("_release_effect", telegraph)
		if current_meteor != null:
			current_weapon.call("_release_effect", current_meteor)
	)


func _fire_sniper_lockshot(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var locked_target := target
	var finish: Vector2 = owner_node.global_position + direction * attack_range
	if locked_target != null:
		finish = locked_target.global_position
	var start := owner_node.global_position + direction * 30.0
	var telegraph := AttackVfx.beam(_projectile_parent(), start, finish, maxf(beam_width * 0.65, 18.0), Color(visual_color.r, visual_color.g, visual_color.b, 0.26))
	_register_effect(telegraph)
	var telegraph_ref: WeakRef = weakref(telegraph)
	var weapon_id := get_instance_id()
	var owner_id := owner_node.get_instance_id()
	var target_id := locked_target.get_instance_id() if locked_target != null else 0
	var lock_direction := direction
	var lock_tween := create_tween()
	lock_tween.tween_interval(maxf(grenade_delay, 0.10))
	lock_tween.tween_callback(func() -> void:
		var current_weapon := instance_from_id(weapon_id) as Node
		var current_owner := instance_from_id(owner_id) as Node2D
		if current_weapon == null or current_owner == null:
			var invalid_telegraph := telegraph_ref.get_ref() as Node
			if invalid_telegraph != null and is_instance_valid(invalid_telegraph):
				invalid_telegraph.queue_free()
			return
		var current_target := instance_from_id(target_id) as Node2D
		var shot_direction: Vector2 = lock_direction
		var shot_finish: Vector2 = current_owner.global_position + shot_direction * float(current_weapon.get("attack_range"))
		if current_target != null:
			var to_target: Vector2 = current_target.global_position - current_owner.global_position
			if to_target.length_squared() > 0.001:
				shot_direction = to_target.normalized()
				shot_finish = current_target.global_position + shot_direction * float(current_weapon.get("aoe_radius"))
		var shot_start: Vector2 = current_owner.global_position + shot_direction * 30.0
		var tracer := AttackVfx.beam(current_weapon.call("_projectile_parent"), shot_start, shot_finish, float(current_weapon.get("beam_width")), current_weapon.get("visual_color"))
		current_weapon.call("_register_effect", tracer)
		var damage_value := float(current_weapon.call("_rolled_damage", current_owner))
		if current_target != null:
			current_weapon.call("_damage_enemy", current_target, damage_value * 1.34)
		current_weapon.call("_damage_enemies_in_segment", shot_start, shot_finish, float(current_weapon.get("beam_width")) * 0.72, damage_value * float(current_weapon.get("damage_falloff")))
		var release_telegraph := telegraph_ref.get_ref() as Node
		if release_telegraph != null:
			current_weapon.call("_release_effect", release_telegraph)
	)


func _fire_sniper_kill_zone(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var center: Vector2 = owner_node.global_position + direction * min(attack_range, 520.0)
	if target != null:
		center = target.global_position
	var zone := AttackVfx.ring_pulse(_projectile_parent(), center, aoe_radius, visual_color, true)
	_register_effect(zone)
	var zone_ref: WeakRef = weakref(zone)
	var weapon_id := get_instance_id()
	var owner_id := owner_node.get_instance_id()
	var zone_tween := create_tween()
	zone_tween.tween_interval(maxf(grenade_delay, 0.12))
	zone_tween.tween_callback(func() -> void:
		var current_weapon := instance_from_id(weapon_id) as Node
		var current_owner := instance_from_id(owner_id) as Node2D
		if current_weapon == null:
			var invalid_zone := zone_ref.get_ref() as Node
			if invalid_zone != null and is_instance_valid(invalid_zone):
				invalid_zone.queue_free()
			return
		var shots := int(maxi(current_weapon.get("projectile_count"), 1))
		var damage_value := damage if current_owner == null else float(current_weapon.call("_rolled_damage", current_owner))
		var targets: Array = current_weapon.call("_enemies_in_circle_sorted", center, float(current_weapon.get("aoe_radius")), shots)
		if targets.is_empty():
			AttackVfx.orb_burst(current_weapon.call("_projectile_parent"), center, float(current_weapon.get("aoe_radius")) * 0.45, current_weapon.get("visual_color"))
			var empty_zone := zone_ref.get_ref() as Node
			if empty_zone != null:
				current_weapon.call("_release_effect", empty_zone)
			return
		for shot_index in range(targets.size()):
			var enemy_node := targets[shot_index] as Node2D
			if enemy_node == null or not is_instance_valid(enemy_node):
				continue
			var sky_start: Vector2 = enemy_node.global_position + Vector2(-80.0 + 80.0 * float(shot_index), -float(current_weapon.get("aoe_radius")) * 1.35)
			var strike := AttackVfx.beam(current_weapon.call("_projectile_parent"), sky_start, enemy_node.global_position, float(current_weapon.get("beam_width")), current_weapon.get("visual_color"))
			current_weapon.call("_register_effect", strike)
			current_weapon.call("_damage_enemy", enemy_node, damage_value * pow(float(current_weapon.get("damage_falloff")), float(shot_index)))
		var release_zone := zone_ref.get_ref() as Node
		if release_zone != null:
			current_weapon.call("_release_effect", release_zone)
	)


func _fire_sniper_split_round(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var first_target: Node2D = target
	if first_target == null:
		first_target = _find_closest_enemy(owner_node, INF)
	if first_target == null:
		_fire_sniper_lockshot(owner_node, null, direction)
		return
	var start: Vector2 = owner_node.global_position + direction * 30.0
	var to_target: Vector2 = first_target.global_position - owner_node.global_position
	var shot_direction: Vector2 = direction if to_target.length_squared() <= 0.001 else to_target.normalized()
	var tracer := AttackVfx.beam(_projectile_parent(), start, first_target.global_position, beam_width, visual_color)
	_register_effect(tracer)
	var damage_value := _rolled_damage(owner_node)
	_damage_enemy(first_target, damage_value)
	var used := {first_target.get_instance_id(): true}
	var split_targets: Array = _nearest_enemies_from(first_target.global_position, aoe_radius, maxi(split_count + _extra_projectiles(), 1), used)
	for split_index in range(split_targets.size()):
		var enemy_node := split_targets[split_index] as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var shard := AttackVfx.beam(_projectile_parent(), first_target.global_position, enemy_node.global_position, beam_width * 0.55, Color(visual_color.r, visual_color.g, visual_color.b, 0.36))
		_register_effect(shard)
		_damage_enemy(enemy_node, damage_value * pow(damage_falloff, float(split_index + 1)))
	if split_targets.is_empty():
		var end_point: Vector2 = first_target.global_position + shot_direction * min(aoe_radius, 220.0)
		_damage_enemies_in_segment(first_target.global_position, end_point, beam_width * 0.6, damage_value * damage_falloff)


func _fire_priest_sanctify(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_emit_weapon_animation_event(owner_node, "windup", maxf(grenade_delay, 0.10), direction, {"delayed": true})
	var center: Vector2 = owner_node.global_position + direction * min(attack_range, 480.0)
	var target_id := 0
	if target != null:
		center = target.global_position
		target_id = target.get_instance_id()
	var mark := AttackVfx.ring_pulse(_projectile_parent(), center, aoe_radius, visual_color, true)
	_register_effect(mark)
	var mark_ref: WeakRef = weakref(mark)
	var weapon_id := get_instance_id()
	var owner_id := owner_node.get_instance_id()
	var stored_center := center
	var sanctify_tween := create_tween()
	sanctify_tween.tween_interval(maxf(grenade_delay, 0.10))
	sanctify_tween.tween_callback(func() -> void:
		var current_weapon := instance_from_id(weapon_id) as Node
		var current_owner := instance_from_id(owner_id) as Node2D
		if current_weapon == null:
			var invalid_mark := mark_ref.get_ref() as Node
			if invalid_mark != null and is_instance_valid(invalid_mark):
				invalid_mark.queue_free()
			return
		var impact_center: Vector2 = stored_center
		var current_target := instance_from_id(target_id) as Node2D
		if current_target != null:
			impact_center = current_target.global_position
		var damage_value: float = float(current_weapon.call("_rolled_damage", current_owner)) if current_owner != null else float(current_weapon.get("damage"))
		if current_owner != null:
			current_weapon.call("_emit_weapon_animation_event", current_owner, "release", 0.0, direction, {"delayed": true})
		AttackVfx.orb_burst(current_weapon.call("_projectile_parent"), impact_center, float(current_weapon.get("aoe_radius")) * 0.72, current_weapon.get("visual_color"))
		current_weapon.call("_damage_enemies_in_circle_falloff", impact_center, float(current_weapon.get("aoe_radius")), damage_value, float(current_weapon.get("damage_falloff")))
		var release_mark := mark_ref.get_ref() as Node
		if release_mark != null:
			current_weapon.call("_release_effect", release_mark)
	)


func _fire_priest_ward(owner_node: Node2D) -> void:
	var weapon_id := get_instance_id()
	var owner_id := owner_node.get_instance_id()
	var pulse_count: int = maxi(storm_ticks, 1)
	_emit_weapon_animation_event(owner_node, "burst", maxf(burst_interval, 0.06) * float(maxi(pulse_count - 1, 1)), Vector2.RIGHT, {"count": pulse_count})
	var damage_value: float = _rolled_damage(owner_node)
	for pulse_index in range(pulse_count):
		var ward_tween := create_tween()
		ward_tween.tween_interval(float(pulse_index) * maxf(burst_interval, 0.06))
		ward_tween.tween_callback(func() -> void:
			var current_weapon := instance_from_id(weapon_id) as Node
			var current_owner := instance_from_id(owner_id) as Node2D
			if current_weapon == null or current_owner == null:
				return
			current_weapon.call("_emit_weapon_animation_event", current_owner, "pulse", maxf(float(current_weapon.get("burst_interval")), 0.06), Vector2.RIGHT, {"index": pulse_index, "count": pulse_count})
			var radius: float = float(current_weapon.get("aoe_radius")) * (0.72 + 0.14 * float(pulse_index))
			AttackVfx.ring_pulse(current_weapon.call("_projectile_parent"), current_owner.global_position, radius, current_weapon.get("visual_color"), false)
			current_weapon.call("_damage_enemies_in_circle", current_owner.global_position, radius, damage_value)
		)


func _fire_priest_prayer_chain(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_emit_weapon_animation_event(owner_node, "channel", maxf(0.14, float(projectile_count + _extra_projectiles()) * 0.04), direction, {"chain": true})
	var first_target: Node2D = target
	if first_target == null:
		first_target = _find_closest_enemy(owner_node, INF)
	if first_target == null:
		AttackVfx.beam(_projectile_parent(), owner_node.global_position + direction * 20.0, owner_node.global_position + direction * min(attack_range, 360.0), beam_width, visual_color)
		return
	var damage_value: float = _rolled_damage(owner_node)
	var used: Dictionary = {}
	var previous_position := owner_node.global_position
	var current_target := first_target
	var jumps := maxi(projectile_count + _extra_projectiles(), 1)
	for jump_index in range(jumps):
		if current_target == null or not is_instance_valid(current_target):
			break
		used[current_target.get_instance_id()] = true
		var tether := AttackVfx.beam(_projectile_parent(), previous_position, current_target.global_position, beam_width * maxf(0.42, pow(damage_falloff, float(jump_index)) + 0.12), visual_color)
		_register_effect(tether)
		_damage_enemy(current_target, damage_value * pow(damage_falloff, float(jump_index)))
		previous_position = current_target.global_position
		current_target = _find_nearest_enemy_from(previous_position, aoe_radius, used)
	if owner_node != null and is_instance_valid(owner_node):
		AttackVfx.beam(_projectile_parent(), previous_position, owner_node.global_position, beam_width * 0.42, Color(visual_color.r, visual_color.g, visual_color.b, 0.24))


func _fire_bio_spore_bloom(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_emit_weapon_animation_event(owner_node, "burst", maxf(burst_interval, 0.08) * float(maxi(storm_ticks - 1, 1)), direction, {"count": maxi(storm_ticks, 1)})
	var center: Vector2 = owner_node.global_position + direction * min(attack_range, 420.0)
	var target_id := 0
	if target != null:
		center = target.global_position
		target_id = target.get_instance_id()
	var weapon_id := get_instance_id()
	var owner_id := owner_node.get_instance_id()
	var stored_center := center
	var damage_value: float = _rolled_damage(owner_node)
	var pulse_count: int = maxi(storm_ticks, 1)
	for pulse_index in range(pulse_count):
		var bloom_tween := create_tween()
		bloom_tween.tween_interval(float(pulse_index) * maxf(burst_interval, 0.08))
		bloom_tween.tween_callback(func() -> void:
			var current_weapon := instance_from_id(weapon_id) as Node
			var current_owner := instance_from_id(owner_id) as Node2D
			if current_weapon == null or current_owner == null:
				return
			current_weapon.call("_emit_weapon_animation_event", current_owner, "pulse", maxf(float(current_weapon.get("burst_interval")), 0.08), direction, {"index": pulse_index, "count": pulse_count})
			var impact_center: Vector2 = stored_center
			var current_target := instance_from_id(target_id) as Node2D
			if current_target != null:
				impact_center = current_target.global_position
			var radius: float = float(current_weapon.get("aoe_radius")) * (0.44 + 0.24 * float(pulse_index + 1))
			var factor: float = pow(float(current_weapon.get("damage_falloff")), float(pulse_index))
			AttackVfx.ring_pulse(current_weapon.call("_projectile_parent"), impact_center, radius, current_weapon.get("visual_color"), pulse_index == 0)
			current_weapon.call("_damage_enemies_in_circle_falloff", impact_center, radius, damage_value * factor, float(current_weapon.get("damage_falloff")))
		)


func _fire_bio_sample_dart(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var first_target: Node2D = target
	if first_target == null:
		first_target = _find_closest_enemy(owner_node, INF)
	if first_target == null:
		_damage_enemies_in_segment(owner_node.global_position, owner_node.global_position + direction * min(attack_range, 420.0), beam_width, _rolled_damage(owner_node))
		return
	var start: Vector2 = owner_node.global_position + direction * 26.0
	var tracer := AttackVfx.beam(_projectile_parent(), start, first_target.global_position, beam_width, visual_color)
	_register_effect(tracer)
	var damage_value: float = _rolled_damage(owner_node)
	_damage_enemy_with_dot(first_target, damage_value, owner_node)
	var weapon_id := get_instance_id()
	var owner_id := owner_node.get_instance_id()
	var target_id := first_target.get_instance_id()
	var pulse_count: int = maxi(projectile_count, 1)
	_emit_weapon_animation_event(owner_node, "burst", maxf(burst_interval, 0.08) * float(pulse_count), direction, {"count": pulse_count})
	for pulse_index in range(pulse_count):
		var sample_tween := create_tween()
		sample_tween.tween_interval(maxf(burst_interval, 0.08) * float(pulse_index + 1))
		sample_tween.tween_callback(func() -> void:
			var current_weapon := instance_from_id(weapon_id) as Node
			var current_owner := instance_from_id(owner_id) as Node2D
			var current_target := instance_from_id(target_id) as Node2D
			if current_weapon == null or current_owner == null or current_target == null:
				return
			current_weapon.call("_emit_weapon_animation_event", current_owner, "pulse", maxf(float(current_weapon.get("burst_interval")), 0.08), direction, {"index": pulse_index, "count": pulse_count})
			var radius: float = float(current_weapon.get("aoe_radius")) * (0.70 + 0.16 * float(pulse_index))
			var pulse_damage: float = damage_value * pow(float(current_weapon.get("damage_falloff")), float(pulse_index + 1))
			AttackVfx.orb_burst(current_weapon.call("_projectile_parent"), current_target.global_position, radius * 0.42, current_weapon.get("visual_color"))
			current_weapon.call("_damage_enemies_in_circle_falloff", current_target.global_position, radius, pulse_damage, float(current_weapon.get("damage_falloff")))
		)


func _fire_bio_symbiote_web(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_emit_weapon_animation_event(owner_node, "channel", maxf(0.16, float(projectile_count + _extra_projectiles()) * 0.05), direction, {"chain": true})
	var first_target: Node2D = target
	if first_target == null:
		first_target = _find_closest_enemy(owner_node, INF)
	if first_target == null:
		AttackVfx.ring_pulse(_projectile_parent(), owner_node.global_position + direction * 120.0, aoe_radius * 0.45, visual_color, true)
		return
	var damage_value: float = _rolled_damage(owner_node)
	var used := {first_target.get_instance_id(): true}
	AttackVfx.ring_pulse(_projectile_parent(), first_target.global_position, aoe_radius * 0.36, visual_color, true)
	_damage_enemy_with_dot(first_target, damage_value * 0.72, owner_node)
	var linked_targets: Array = _nearest_enemies_from(first_target.global_position, aoe_radius, maxi(projectile_count + _extra_projectiles(), 1), used)
	for link_index in range(linked_targets.size()):
		var enemy_node := linked_targets[link_index] as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var width: float = beam_width * maxf(0.42, pow(damage_falloff, float(link_index)) + 0.10)
		var web := AttackVfx.beam(_projectile_parent(), first_target.global_position, enemy_node.global_position, width, visual_color)
		_register_effect(web)
		_damage_enemy_with_dot(enemy_node, damage_value * pow(damage_falloff, float(link_index + 1)), owner_node)
	if linked_targets.is_empty():
		_damage_enemies_in_circle_falloff(first_target.global_position, aoe_radius * 0.56, damage_value * damage_falloff, damage_falloff)


func _fire_robot_magnetic_anchor(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var center: Vector2 = owner_node.global_position + direction * min(attack_range, 360.0)
	if target != null:
		center = target.global_position
	var telegraph := AttackVfx.ring_pulse(_projectile_parent(), center, aoe_radius, visual_color, true)
	_register_effect(telegraph)
	var tether := AttackVfx.beam(_projectile_parent(), owner_node.global_position + direction * 24.0, center, beam_width, Color(visual_color.r, visual_color.g, visual_color.b, 0.26))
	_register_effect(tether)
	var weapon_id := get_instance_id()
	var owner_id := owner_node.get_instance_id()
	var stored_center := center
	var anchor_tween := create_tween()
	anchor_tween.tween_interval(maxf(grenade_delay, 0.08))
	anchor_tween.tween_callback(func() -> void:
		var current_weapon := instance_from_id(weapon_id) as Node
		var current_owner := instance_from_id(owner_id) as Node2D
		if current_weapon == null:
			if is_instance_valid(telegraph):
				telegraph.queue_free()
			if is_instance_valid(tether):
				tether.queue_free()
			return
		var damage_value: float = float(current_weapon.call("_rolled_damage", current_owner)) if current_owner != null else float(current_weapon.get("damage"))
		current_weapon.call("_damage_enemies_in_circle_falloff", stored_center, float(current_weapon.get("aoe_radius")), damage_value, float(current_weapon.get("damage_falloff")))
		current_weapon.call("_pull_enemies_toward", stored_center, float(current_weapon.get("aoe_radius")), float(current_weapon.get("knockback")))
		AttackVfx.orb_burst(current_weapon.call("_projectile_parent"), stored_center, float(current_weapon.get("aoe_radius")) * 0.62, current_weapon.get("visual_color"))
		current_weapon.call("_release_effect", telegraph)
		current_weapon.call("_release_effect", tether)
	)


func _fire_robot_compression_line(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var center: Vector2 = owner_node.global_position + direction * min(attack_range * 0.58, 260.0)
	if target != null:
		var to_target := target.global_position - owner_node.global_position
		if to_target.length_squared() > 0.001:
			center = owner_node.global_position + to_target.normalized() * minf(to_target.length(), attack_range * 0.58)
	var start := owner_node.global_position + direction * 28.0
	var finish := owner_node.global_position + direction * attack_range
	var perpendicular := Vector2(-direction.y, direction.x).normalized()
	var left_start := start + perpendicular * suppression_width * 0.5
	var left_finish := finish + perpendicular * suppression_width * 0.5
	var right_start := start - perpendicular * suppression_width * 0.5
	var right_finish := finish - perpendicular * suppression_width * 0.5
	var left := AttackVfx.beam(_projectile_parent(), left_start, left_finish, beam_width * 0.42, Color(visual_color.r, visual_color.g, visual_color.b, 0.28))
	var right := AttackVfx.beam(_projectile_parent(), right_start, right_finish, beam_width * 0.42, Color(visual_color.r, visual_color.g, visual_color.b, 0.28))
	_register_effect(left)
	_register_effect(right)
	var weapon_id := get_instance_id()
	var owner_id := owner_node.get_instance_id()
	var line_start := start
	var line_finish := finish
	var line_direction := direction
	var line_perpendicular := perpendicular
	var clamp_center := center
	var press_tween := create_tween()
	press_tween.tween_interval(maxf(grenade_delay, 0.08))
	press_tween.tween_callback(func() -> void:
		var current_weapon := instance_from_id(weapon_id) as Node
		var current_owner := instance_from_id(owner_id) as Node2D
		if current_weapon == null:
			if is_instance_valid(left):
				left.queue_free()
			if is_instance_valid(right):
				right.queue_free()
			return
		var damage_value: float = float(current_weapon.call("_rolled_damage", current_owner)) if current_owner != null else float(current_weapon.get("damage"))
		var impact := AttackVfx.beam(current_weapon.call("_projectile_parent"), line_start, line_finish, float(current_weapon.get("beam_width")), current_weapon.get("visual_color"))
		current_weapon.call("_register_effect", impact)
		current_weapon.call("_damage_enemies_in_corridor", line_start, line_direction, damage_value)
		current_weapon.call("_compress_enemies_to_axis", line_start, line_direction, line_perpendicular, float(current_weapon.get("suppression_width")), float(current_weapon.get("attack_range")), float(current_weapon.get("knockback")))
		AttackVfx.ring_pulse(current_weapon.call("_projectile_parent"), clamp_center, float(current_weapon.get("aoe_radius")) * 0.42, current_weapon.get("visual_color"), false)
		current_weapon.call("_release_effect", left)
		current_weapon.call("_release_effect", right)
	)


func _fire_robot_reactor_vent(owner_node: Node2D, direction: Vector2) -> void:
	var vent_count := maxi(projectile_count, 4)
	var damage_value := _rolled_damage(owner_node) / float(maxi(vent_count, 1))
	AttackVfx.ring_pulse(_projectile_parent(), owner_node.global_position, aoe_radius * 0.62, visual_color, true)
	for vent_index in range(vent_count):
		var vent_direction := direction.rotated(TAU * float(vent_index) / float(vent_count))
		var start := owner_node.global_position + vent_direction * 22.0
		var finish := owner_node.global_position + vent_direction * attack_range
		var beam := AttackVfx.beam(_projectile_parent(), start, finish, beam_width, visual_color)
		_register_effect(beam)
		_damage_enemies_in_segment(start, finish, beam_width, damage_value)
		for enemy in _enemies_in_corridor(start, vent_direction, beam_width, attack_range):
			var enemy_node := enemy["node"] as Node2D
			if enemy_node == null:
				continue
			_push_enemy(enemy_node, vent_direction)


func _fire_engineer_sentry_link(owner_node: Node2D, direction: Vector2) -> void:
	_emit_weapon_animation_event(owner_node, "deploy", amp_lifetime, direction, {"pulse_interval": amp_pulse_interval})
	_deployed_amps = _deployed_amps.filter(func(device: Node) -> bool:
		return device != null and is_instance_valid(device)
	)
	var sentry := Node2D.new()
	sentry.name = "EngineerSentryNode"
	sentry.add_to_group("engineer_devices")
	sentry.z_index = 7
	var visual := Sprite2D.new()
	visual.name = "SentryVisual"
	visual.texture = _weapon_visual_texture()
	visual.scale = Vector2.ONE * 0.28
	sentry.add_child(visual)
	_projectile_parent().add_child(sentry)
	_register_effect(sentry)
	sentry.global_position = owner_node.global_position + direction * 92.0
	_deployed_amps.append(sentry)
	while _deployed_amps.size() > maxi(max_summons, 1):
		var oldest: Node = _deployed_amps.pop_front()
		_release_effect(oldest)

	AttackVfx.ring_pulse(_projectile_parent(), sentry.global_position, aoe_radius * 0.45, visual_color, false)
	var weapon_id := get_instance_id()
	var owner_id := owner_node.get_instance_id()
	var sentry_id := sentry.get_instance_id()
	var shot_count := maxi(projectile_count + _extra_projectiles(), 1)
	var sentry_tween := sentry.create_tween()
	for shot_index in range(shot_count):
		if shot_index > 0:
			sentry_tween.tween_interval(maxf(amp_pulse_interval, 0.12))
		sentry_tween.tween_callback(func() -> void:
			var current_weapon := instance_from_id(weapon_id) as Node
			var current_owner := instance_from_id(owner_id) as Node2D
			var current_sentry := instance_from_id(sentry_id) as Node2D
			if current_weapon == null or current_owner == null or current_sentry == null:
				return
			current_weapon.call("_emit_weapon_animation_event", current_owner, "pulse", maxf(float(current_weapon.get("amp_pulse_interval")), 0.12), direction, {"index": shot_index, "count": shot_count})
			var used: Dictionary = {}
			var target_enemy: Node2D = current_weapon.call("_find_nearest_enemy_from", current_sentry.global_position, float(current_weapon.get("attack_range")), used)
			if target_enemy == null:
				return
			var beam := AttackVfx.beam(current_weapon.call("_projectile_parent"), current_sentry.global_position, target_enemy.global_position, float(current_weapon.get("beam_width")), current_weapon.get("visual_color"))
			current_weapon.call("_register_effect", beam)
			var shot_damage: float = float(current_weapon.call("_rolled_damage", current_owner)) * pow(float(current_weapon.get("damage_falloff")), float(shot_index))
			current_weapon.call("_damage_enemy", target_enemy, shot_damage)
		)
	sentry_tween.tween_interval(maxf(amp_lifetime - float(shot_count) * maxf(amp_pulse_interval, 0.12), 0.08))
	sentry_tween.tween_callback(func() -> void:
		var current_weapon := instance_from_id(weapon_id) as Node
		var current_sentry := instance_from_id(sentry_id) as Node
		if current_sentry == null:
			return
		if current_weapon != null:
			var devices: Array = current_weapon.get("_deployed_amps")
			devices.erase(current_sentry)
			current_weapon.call("_release_effect", current_sentry)
		else:
			current_sentry.queue_free()
	)


func _fire_engineer_repair_drone(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_emit_weapon_animation_event(owner_node, "channel", maxf(0.16, float(projectile_count + _extra_projectiles()) * 0.05), direction, {"chain": true})
	var first_target: Node2D = target
	if first_target == null:
		first_target = _find_closest_enemy(owner_node, INF)
	if first_target == null:
		AttackVfx.ring_pulse(_projectile_parent(), owner_node.global_position + direction * 120.0, aoe_radius * 0.34, visual_color, false)
		return
	var damage_value := _rolled_damage(owner_node)
	var used := {first_target.get_instance_id(): true}
	var previous_position := owner_node.global_position + direction * 28.0
	var current_target := first_target
	var healed := 0.0
	var links := maxi(projectile_count + _extra_projectiles(), 1)
	for link_index in range(links):
		if current_target == null or not is_instance_valid(current_target):
			break
		var width: float = beam_width * maxf(0.42, pow(damage_falloff, float(link_index)) + 0.10)
		var tether := AttackVfx.beam(_projectile_parent(), previous_position, current_target.global_position, width, visual_color)
		_register_effect(tether)
		var hit_damage := damage_value * pow(damage_falloff, float(link_index))
		_damage_enemy(current_target, hit_damage)
		healed += hit_damage * heal_percent_of_damage * ProgressionData.WEAPON_DRAIN_HEAL_MULTIPLIER
		previous_position = current_target.global_position
		current_target = _find_nearest_enemy_from(previous_position, aoe_radius, used)
		if current_target != null:
			used[current_target.get_instance_id()] = true
	AttackVfx.beam(_projectile_parent(), previous_position, owner_node.global_position, beam_width * 0.44, Color(visual_color.r, visual_color.g, visual_color.b, 0.25))
	if healed > 0.01 and owner_node.get("health") != null and owner_node.get("max_health") != null:
		# SCRUM-517: _damage_enemy выше уже провёл drain через capped apply_drain_heal,
		# поэтому этот батч-heal — двойное лечение в обход бюджета. Маршрутизируем его
		# через тот же per-second бюджет (для owner-ов без метода — прежнее поведение).
		var actual_healed := 0.0
		if owner_node.has_method("apply_drain_heal"):
			actual_healed = float(owner_node.call("apply_drain_heal", healed))
		else:
			var before := float(owner_node.get("health"))
			owner_node.set("health", minf(float(owner_node.get("max_health")), before + healed))
			actual_healed = float(owner_node.get("health")) - before
		if actual_healed > 0.01 and owner_node.has_method("_show_heal_vfx"):
			owner_node.call("_show_heal_vfx")
		if actual_healed > 0.01 and owner_node.has_method("show_combat_feedback_number"):
			owner_node.show_combat_feedback_number(actual_healed, "heal")
	if summon_support_heal_percent > 0.0 and owner_node.has_method("heal_percent"):
		owner_node.heal_percent(summon_support_heal_percent)


func _fire_engineer_pressure_mines(owner_node: Node2D, direction: Vector2) -> void:
	var mine_count := maxi(projectile_count + _extra_projectiles(), 1)
	_emit_weapon_animation_event(owner_node, "deploy", pool_duration, direction, {"count": mine_count, "check_interval": pool_tick_interval})
	var spread := deg_to_rad(46.0)
	for mine_index in range(mine_count):
		var offset := 0.0
		if mine_count > 1:
			offset = lerpf(-spread * 0.5, spread * 0.5, float(mine_index) / float(mine_count - 1))
		var mine_direction := direction.rotated(offset)
		var distance := minf(attack_range, 150.0 + 54.0 * float(mine_index))
		_spawn_engineer_pressure_mine(owner_node, owner_node.global_position + mine_direction * distance, mine_index)


func _spawn_engineer_pressure_mine(owner_node: Node2D, mine_position: Vector2, mine_index: int) -> void:
	var mine := Node2D.new()
	mine.name = "EngineerPressureMine"
	mine.add_to_group("engineer_devices")
	mine.z_index = 6
	var visual := Sprite2D.new()
	visual.texture = _weapon_visual_texture()
	visual.scale = Vector2.ONE * 0.18
	visual.modulate = Color(1.0, 1.0, 1.0, 0.86)
	mine.add_child(visual)
	_projectile_parent().add_child(mine)
	_register_effect(mine)
	mine.global_position = mine_position
	AttackVfx.ring_pulse(_projectile_parent(), mine_position, aoe_radius * 0.52, visual_color, true)
	var state := {"triggered": false}
	var check_interval := maxf(pool_tick_interval, 0.10)
	var check_count := maxi(int(floor(pool_duration / check_interval)), 1)
	var weapon_id := get_instance_id()
	var owner_id := owner_node.get_instance_id()
	var mine_id := mine.get_instance_id()
	var mine_tween := mine.create_tween()
	for check_index in range(check_count):
		if check_index > 0:
			mine_tween.tween_interval(check_interval)
		mine_tween.tween_callback(func() -> void:
			var current_weapon := instance_from_id(weapon_id) as Node
			var current_owner := instance_from_id(owner_id) as Node2D
			var current_mine := instance_from_id(mine_id) as Node2D
			if current_weapon == null or current_mine == null or bool(state["triggered"]):
				return
			if not current_weapon.call("_has_enemy_in_circle", current_mine.global_position, float(current_weapon.get("aoe_radius")) * 0.62):
				return
			state["triggered"] = true
			if current_owner != null:
				current_weapon.call("_emit_weapon_animation_event", current_owner, "release", 0.0, Vector2.RIGHT, {"mine_index": mine_index})
			var mine_damage: float = float(current_weapon.call("_rolled_damage", current_owner)) if current_owner != null else float(current_weapon.get("damage"))
			mine_damage *= pow(float(current_weapon.get("damage_falloff")), float(mine_index) * 0.35)
			current_weapon.call("_damage_enemies_in_circle_falloff", current_mine.global_position, float(current_weapon.get("aoe_radius")), mine_damage, float(current_weapon.get("damage_falloff")))
			AttackVfx.orb_burst(current_weapon.call("_projectile_parent"), current_mine.global_position, float(current_weapon.get("aoe_radius")) * 0.72, current_weapon.get("visual_color"))
			current_weapon.call("_release_effect", current_mine)
		)
	mine_tween.tween_callback(func() -> void:
		var current_weapon := instance_from_id(weapon_id) as Node
		var current_mine := instance_from_id(mine_id) as Node
		if current_mine == null:
			return
		if current_weapon != null and not bool(state["triggered"]):
			current_weapon.call("_release_effect", current_mine)
		elif current_mine != null:
			current_mine.queue_free()
	)


func _pull_enemies_toward(center: Vector2, radius: float, force: float) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var to_center := center - enemy_node.global_position
		var distance := to_center.length()
		if distance <= 0.001 or distance > radius:
			continue
		var pull_strength := force * lerpf(1.0, 0.35, distance / maxf(radius, 1.0))
		if enemy_node.has_method("apply_knockback"):
			enemy_node.apply_knockback(to_center.normalized() * pull_strength)
		else:
			enemy_node.global_position += to_center.normalized() * pull_strength * 0.10


func _compress_enemies_to_axis(origin: Vector2, direction: Vector2, perpendicular: Vector2, width: float, range_limit: float, force: float) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var to_enemy := enemy_node.global_position - origin
		var forward := to_enemy.dot(direction)
		if forward < -24.0 or forward > range_limit:
			continue
		var side := to_enemy.dot(perpendicular)
		if abs(side) > width * 0.5:
			continue
		var push_direction := -perpendicular if side > 0.0 else perpendicular
		if push_direction.length_squared() <= 0.001:
			continue
		if enemy_node.has_method("apply_knockback"):
			enemy_node.apply_knockback(push_direction.normalized() * force)
		else:
			enemy_node.global_position += push_direction.normalized() * force * 0.08


func _try_steal_money(owner_node: Node2D, hit_index: int) -> void:
	if steal_money <= 0 or owner_node == null or not owner_node.has_method("gain_money"):
		return
	if hit_index > 0 and randf() > 0.42:
		return
	owner_node.gain_money(steal_money)


func _apply_temporary_dodge(owner_node: Node2D) -> void:
	if dodge_bonus <= 0.0 or owner_node == null:
		return
	var modifiers_raw = owner_node.get("run_modifiers")
	if not (modifiers_raw is Dictionary):
		return
	var modifiers: Dictionary = modifiers_raw
	modifiers["dodge_flat"] = float(modifiers.get("dodge_flat", 0.0)) + dodge_bonus
	if owner_node.has_method("_apply_stat_scaling"):
		owner_node.call("_apply_stat_scaling", false, owner_node.get("max_health"))
	var owner_id := owner_node.get_instance_id()
	var remove_tween := create_tween()
	remove_tween.tween_interval(maxf(smoke_duration, 0.2))
	remove_tween.tween_callback(func() -> void:
		var current_owner := instance_from_id(owner_id) as Node
		if current_owner == null:
			return
		var current_modifiers_raw = current_owner.get("run_modifiers")
		if not (current_modifiers_raw is Dictionary):
			return
		var current_modifiers: Dictionary = current_modifiers_raw
		current_modifiers["dodge_flat"] = maxf(0.0, float(current_modifiers.get("dodge_flat", 0.0)) - dodge_bonus)
		if current_owner.has_method("_apply_stat_scaling"):
			current_owner.call("_apply_stat_scaling", false, current_owner.get("max_health"))
	)


func _extra_projectiles() -> int:
	var owner_node := _owner_node()
	if owner_node == null:
		return 0
	var mods = owner_node.get("run_modifiers")
	if not (mods is Dictionary):
		return 0
	return int(mods.get("extra_projectile", 0.0))


func _find_closest_enemy(owner_node: Node2D, range_limit := -1.0) -> Node2D:
	var max_distance := attack_range if range_limit < 0.0 else range_limit
	return TARGET_QUERY.nearest(self, owner_node.global_position, max_distance)


func _owner_uses_cursor_aim(owner_node: Node) -> bool:
	return owner_node != null and owner_node.has_method("attack_aim_mode") and str(owner_node.call("attack_aim_mode")) == "cursor"


func _enemies_in_corridor(origin: Vector2, direction: Vector2, width: float, range_limit: float) -> Array:
	return TARGET_QUERY.in_corridor(self, origin, direction, width, range_limit, 24.0)


func _find_nearest_enemy_from(origin: Vector2, range_limit: float, excluded_ids: Dictionary) -> Node2D:
	return TARGET_QUERY.nearest(self, origin, range_limit, excluded_ids)


func _nearest_enemies_from(origin: Vector2, range_limit: float, count: int, excluded_ids: Dictionary = {}) -> Array:
	return TARGET_QUERY.nearest_many(self, origin, range_limit, count, excluded_ids)


func _enemies_in_circle_sorted(origin: Vector2, radius: float, count: int) -> Array:
	return _nearest_enemies_from(origin, radius, count)


func _is_enemy_inside_wave(origin: Vector2, enemy_position: Vector2, direction: Vector2) -> bool:
	var perpendicular := Vector2(-direction.y, direction.x)
	var to_enemy := enemy_position - origin
	var forward := to_enemy.dot(direction)
	if forward < 0.0 or forward > attack_range:
		return false
	var width_ratio: float = clamp(forward / max(attack_range, 1.0), 0.0, 1.0)
	var half_width := lerpf(58.0, wave_width * 0.5, width_ratio)
	return abs(to_enemy.dot(perpendicular)) <= half_width


func _damage_enemy(enemy: Node, amount: float, apply_unique_melee_effects := true) -> void:
	if enemy != null and is_instance_valid(enemy) and enemy.has_method("take_damage"):
		_call_take_damage(enemy, amount, {"critical": _last_attack_crit and apply_unique_melee_effects})
		var owner_node := _owner_node()
		if owner_node != null and owner_node.has_method("on_weapon_hit"):
			owner_node.on_weapon_hit(enemy, amount)
		_heal_owner_from_damage(owner_node, amount)
		if _last_attack_crit and crit_shadow_burst_radius > 0.0 and owner_node != null and owner_node.has_method("trigger_assassin_crit_shadow"):
			owner_node.trigger_assassin_crit_shadow(enemy, crit_shadow_burst_radius)
		if apply_unique_melee_effects and owner_node != null:
			_apply_unique_melee_hit_effects(owner_node, enemy, amount)


func _apply_unique_melee_hit_effects(owner_node: Node2D, enemy: Node, amount: float) -> void:
	var enemy_node := enemy as Node2D
	if enemy_node == null or not is_instance_valid(enemy_node):
		return
	var direction := enemy_node.global_position - owner_node.global_position
	var distance := direction.length()
	if melee_close_bonus_radius > 0.0 and melee_close_damage_multiplier > 1.0 and distance <= melee_close_bonus_radius:
		enemy_node.take_damage(amount * (melee_close_damage_multiplier - 1.0))
	if melee_execute_threshold > 0.0 and melee_execute_multiplier > 1.0:
		var max_hp := float(enemy_node.get("max_health")) if enemy_node.get("max_health") != null else 0.0
		var health := float(enemy_node.get("health")) if enemy_node.get("health") != null else max_hp
		if max_hp > 0.0 and health / max_hp <= melee_execute_threshold:
			enemy_node.take_damage(amount * (melee_execute_multiplier - 1.0))
	if melee_stagger_knockback_multiplier > 0.0 and direction.length_squared() > 0.001:
		_push_enemy_scaled(enemy_node, direction.normalized(), melee_stagger_knockback_multiplier)
	if melee_arc_followup_radius > 0.0 and melee_arc_followup_multiplier > 0.0:
		var splash_damage := amount * melee_arc_followup_multiplier
		for nearby in TARGET_QUERY.in_radius(self, enemy_node.global_position, melee_arc_followup_radius):
			if nearby == enemy_node:
				continue
			if nearby.has_method("take_damage"):
				nearby.take_damage(splash_damage)
	if melee_heal_percent_on_hit > 0.0 and owner_node.has_method("heal_percent"):
		owner_node.heal_percent(melee_heal_percent_on_hit)


func _damage_enemy_with_dot(enemy: Node, direct_damage: float, owner_node: Node2D) -> void:
	_damage_enemy(enemy, direct_damage)
	var parameters_raw = owner_node.get("derived_parameters")
	var parameters: Dictionary = parameters_raw if parameters_raw is Dictionary else {}
	var tick_damage := float(parameters.get("dot_damage", max(1.0, direct_damage * 0.22)))
	var tick_speed: float = max(float(parameters.get("dot_speed", 1.0)), 0.2)
	if dot_ticks <= 0:
		return
	# Tween на оружии замораживается паузой, в отличие от SceneTreeTimer.
	var dot_color := Color(visual_color.r, visual_color.g, visual_color.b, 1.0)
	var dot_tween := create_tween()
	for tick_index in range(dot_ticks):
		dot_tween.tween_interval(1.0 / tick_speed)
		dot_tween.tween_callback(func() -> void:
			_damage_enemy(enemy, tick_damage, false)
			if enemy is Node2D:
				HazardVfx.dot_tick(enemy, dot_color)
		)


func _damage_enemies_in_circle(origin: Vector2, radius: float, amount: float) -> void:
	for enemy_node in TARGET_QUERY.in_radius(self, origin, radius):
		_damage_enemy(enemy_node, amount)


# SCRUM-533: тик ЛУЖИ (DoT-облако) с диминишингом по числу целей. Раньше каждый
# тик лужи лил ПОЛНЫЙ tick_damage всем врагам в круге без потолка, поэтому на
# плотном паке из 20 целей throughput рос линейно (chemist/acid_flask lvl20_ideal
# 20t ≈ 112k — кратно выше budget'а). Формула же бюджетит лужу как pool_targets ≤ 4
# (estimate_weapon_budget → _budget_hit_model, mode aoe_projectile), так что живой
# замер выбивался из формульного коридора. Здесь живой урон лужи приводится к тому
# же бюджету: ближайшие POOL_FULL_TARGETS целей получают полный урон, каждая
# следующая (по удалённости от центра) — убывающий 1/(1+(rank-knee)*decay). Облако
# конечной потенции: типичный бой 1-5 целей не задет, плотная толпа не даёт runaway.
const POOL_FULL_TARGETS := 4
const POOL_TARGET_DIMINISH := 0.6

func _damage_enemies_in_pool(origin: Vector2, radius: float, amount: float) -> void:
	var enemies: Array = TARGET_QUERY.in_radius(self, origin, radius)
	if enemies.size() <= POOL_FULL_TARGETS:
		for enemy_node in enemies:
			_damage_enemy(enemy_node, amount)
		return
	# Сортировка по близости к центру лужи — полный урон достаётся «ядру» пака.
	enemies.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)
	)
	for index in range(enemies.size()):
		var factor := 1.0
		if index >= POOL_FULL_TARGETS:
			factor = 1.0 / (1.0 + float(index - POOL_FULL_TARGETS + 1) * POOL_TARGET_DIMINISH)
		_damage_enemy(enemies[index] as Node2D, amount * factor)


func _damage_enemies_in_circle_falloff(origin: Vector2, radius: float, amount: float, minimum_factor: float) -> void:
	for enemy_node in TARGET_QUERY.in_radius(self, origin, radius):
		var distance := origin.distance_to(enemy_node.global_position)
		var factor := lerpf(1.0, clampf(minimum_factor, 0.0, 1.0), distance / maxf(radius, 1.0))
		_damage_enemy(enemy_node, amount * factor)


func _damage_enemies_in_segment(start: Vector2, finish: Vector2, width: float, amount: float) -> void:
	var segment := finish - start
	var length := segment.length()
	if length <= 0.001:
		_damage_enemies_in_circle(start, width * 0.5, amount)
		return
	for enemy_node in TARGET_QUERY.in_segment(self, start, finish, width):
		_damage_enemy(enemy_node, amount)


func _has_enemy_in_circle(origin: Vector2, radius: float) -> bool:
	return TARGET_QUERY.has_in_radius(self, origin, radius)


func _call_take_damage(enemy: Node, amount: float, feedback := {}) -> void:
	if _take_damage_accepts_feedback(enemy):
		enemy.call("take_damage", amount, feedback)
	else:
		enemy.call("take_damage", amount)


func _take_damage_accepts_feedback(enemy: Node) -> bool:
	for method in enemy.get_method_list():
		if str(method.get("name", "")) == "take_damage":
			var args: Array = method.get("args", [])
			return args.size() >= 2
	return false


func _push_enemy(enemy: Node2D, direction: Vector2) -> void:
	_push_enemy_scaled(enemy, direction, 1.0)


func _push_enemy_scaled(enemy: Node2D, direction: Vector2, multiplier: float) -> void:
	if direction.length_squared() <= 0.001:
		return
	var push_strength := knockback * maxf(multiplier, 0.0)
	if enemy.has_method("apply_knockback"):
		enemy.apply_knockback(direction.normalized() * push_strength * 3.6)
	else:
		enemy.global_position += direction.normalized() * push_strength * 0.12


func _rolled_damage(owner_node: Node2D) -> float:
	var raw_parameters = owner_node.get("derived_parameters")
	if not (raw_parameters is Dictionary):
		return damage

	var parameters: Dictionary = raw_parameters
	var result := float(parameters.get(damage_parameter, damage))
	_last_attack_crit = false
	if randf() < float(parameters.get("crit_chance", 0.0)):
		result *= float(parameters.get("crit_damage_multiplier", 1.0))
		_last_attack_crit = true
	if charge_seconds > 0.0:
		result *= _current_charge_multiplier
	if not summon_role.is_empty():
		result *= _summon_role_damage_factor(parameters)
	return result


func _summon_role_damage_factor(parameters: Dictionary) -> float:
	var summon_amount := float(parameters.get("summon_amount", 0.0))
	return summon_role_damage_multiplier * (1.0 + minf(summon_amount * 0.018, 0.22))


func _update_charge(delta: float) -> void:
	if charge_seconds <= 0.0:
		return
	var owner_node := _owner_node()
	if owner_node == null:
		return
	var energy := 0.0
	var owner_stats = owner_node.get("stats")
	if owner_stats is Dictionary:
		energy = float((owner_stats as Dictionary).get("energy", 0.0))
	var effective_charge_seconds := maxf(charge_seconds / (1.0 + energy * 0.025), 0.25)
	var owner_velocity := Vector2.ZERO
	var raw_velocity = owner_node.get("velocity")
	if raw_velocity is Vector2:
		owner_velocity = raw_velocity
	if owner_velocity.length_squared() <= 4.0:
		_charge_time = minf(_charge_time + delta, effective_charge_seconds)
	else:
		_charge_time = maxf(_charge_time - delta * 2.5, 0.0)


func _charge_multiplier() -> float:
	if charge_seconds <= 0.0:
		return 1.0
	var owner_node := _owner_node()
	var energy := 0.0
	if owner_node != null:
		var owner_stats = owner_node.get("stats")
		if owner_stats is Dictionary:
			energy = float((owner_stats as Dictionary).get("energy", 0.0))
	var effective_charge_seconds := maxf(charge_seconds / (1.0 + energy * 0.025), 0.25)
	var charge_ratio := clampf(_charge_time / maxf(effective_charge_seconds, 0.01), 0.0, 1.0)
	return lerpf(1.0, maxf(charge_max_multiplier, 1.0), charge_ratio)


func _owner_node() -> CharacterBody2D:
	var parent_node := get_parent()
	while parent_node != null:
		if parent_node is CharacterBody2D:
			return parent_node
		parent_node = parent_node.get_parent()
	return null


func _emit_weapon_animation_event(owner_node: Node2D, phase: String, duration: float, direction: Vector2, metadata := {}) -> void:
	if owner_node == null or not is_instance_valid(owner_node) or not owner_node.has_method("play_action_animation"):
		return
	var event_metadata: Dictionary = metadata if metadata is Dictionary else {}
	var payload := event_metadata.duplicate(true)
	payload["attack_mode"] = attack_mode
	payload["weapon_id"] = weapon_id
	payload["display_name"] = display_name
	payload["phase_source"] = "class_weapon"
	var action_id := _event_action_animation_for_mode()
	owner_node.call("play_action_animation", action_id, direction, phase, maxf(duration, 0.0), payload)


func _estimated_windup_duration() -> float:
	match attack_mode:
		"grenade_cook", "smoke_bomb", "prism_rift", "meteor_shards", "priest_sanctify", "robot_magnetic_anchor", "robot_compression_line", "sniper_lockshot", "sniper_kill_zone":
			return maxf(grenade_delay, 0.08)
		"suppression_burst", "priest_ward", "bio_spore_bloom", "bio_sample_dart":
			return maxf(burst_interval, 0.06)
		"amp", "trap", "engineer_sentry_link", "engineer_pressure_mines":
			return 0.10
		"beam", "dot_beam", "drain_link", "priest_prayer_chain", "bio_symbiote_web", "engineer_repair_drone":
			return 0.12
	return 0.08


func _projectile_parent() -> Node:
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	return parent


func _weapon_visual_texture() -> Texture2D:
	var visual := get_node_or_null("WeaponVisual") as Sprite2D
	if visual != null and visual.texture != null:
		return visual.texture
	return SOUND_AMP_TEXTURE


func _deploy_visual_texture() -> Texture2D:
	if not deploy_texture_path.is_empty():
		var texture := load(deploy_texture_path) as Texture2D
		if texture != null:
			return texture
	return _weapon_visual_texture()


func _register_effect(effect: Node) -> void:
	if effect == null:
		return
	_effects_shutdown = false
	effect.set_meta("weapon_owner_id", get_instance_id())
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
	if not has_meta("base_suppression_width"):
		set_meta("base_suppression_width", suppression_width)
	if not has_meta("base_knockback"):
		set_meta("base_knockback", knockback)
