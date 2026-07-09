class_name ClassWeapon
extends Node2D

const SOUND_AMP_TEXTURE := preload("res://assets/sprites/weapons/sound_amp.png")
const POISON_POOL_TEXTURE := preload("res://assets/sprites/effects/poison_pool.png")
const SPARK_POOL_TEXTURE := preload("res://assets/sprites/effects/spark_pool.png")
const BRIAR_POOL_TEXTURE := preload("res://assets/sprites/effects/briar_pool.png")
const TARGET_QUERY := preload("res://scripts/combat_target_query.gd")
const ProgressionData := preload("res://scripts/progression_data.gd")

# SCRUM-553: абсолютный z-слой наземных луж/декалей (summon-пулы химика и пр.).
# Ниже сущностей (игрок/монстры/пикапы z≈0), но выше фона арены (-100) и бордера (-20).
const GROUND_POOL_Z := -3
const CONTACT_STUCK_HIT_BACK_ALLOWANCE := 40.0

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
@export var pierce_damage_falloff := 1.0
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
@export var max_summons_cap := 0
@export var heal_percent_on_attack := 0.0
@export var heal_percent_of_damage := 0.0
@export var leaves_pool := false
@export var pool_element := ""
@export var combo_clouds := false
@export var pool_duration := 3.0
@export var pool_tick_interval := 0.6
@export var pool_direct_damage_multiplier := 1.0
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
@export var sentry_splash_radius := 0.0
@export var sentry_splash_damage_multiplier := 0.0
@export var sentry_splash_target_cap := 0
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
# SCRUM-961: состояние классовых артефактов (счётчик ритма / фаза реактора / эхо-скейл).
var _rhythm_cast_counter := 0
var _rhythm_echo_scale := 1.0
var _reactor_vent_phase := 0.0


# SCRUM-961: чтение ключа классового артефакта из run_modifiers владельца.
func _owner_mod(key: String, default_value := 0.0) -> float:
	var owner_node := _owner_node()
	if owner_node == null:
		return default_value
	var mods = owner_node.get("run_modifiers")
	if mods is Dictionary:
		return float((mods as Dictionary).get(key, default_value))
	return default_value


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
	pierce_damage_falloff = float(config.get("pierce_damage_falloff", pierce_damage_falloff))
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
	max_summons_cap = int(config.get("max_summons_cap", max_summons_cap))
	heal_percent_on_attack = float(config.get("heal_percent_on_attack", heal_percent_on_attack))
	heal_percent_of_damage = float(config.get("heal_percent_of_damage", heal_percent_of_damage))
	leaves_pool = bool(config.get("leaves_pool", leaves_pool))
	pool_element = str(config.get("pool_element", pool_element))
	combo_clouds = bool(config.get("combo_clouds", combo_clouds))
	pool_duration = float(config.get("pool_duration", pool_duration))
	pool_tick_interval = float(config.get("pool_tick_interval", pool_tick_interval))
	pool_direct_damage_multiplier = float(config.get("pool_direct_damage_multiplier", pool_direct_damage_multiplier))
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
	sentry_splash_radius = float(config.get("sentry_splash_radius", sentry_splash_radius))
	sentry_splash_damage_multiplier = float(config.get("sentry_splash_damage_multiplier", sentry_splash_damage_multiplier))
	sentry_splash_target_cap = int(config.get("sentry_splash_target_cap", sentry_splash_target_cap))
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
	_cooldown = fire_interval * _fire_interval_artifact_factor()

	if owner_node.has_method("play_action_animation"):
		owner_node.play_action_animation(_primary_action_animation_for_mode(), direction)
	_emit_weapon_animation_event(owner_node, "windup", _estimated_windup_duration(), direction)

	# SCRUM-603: лечение-от-атаки идёт через per-second бюджет (capped), как drain.
	if heal_percent_on_attack > 0.0 and owner_node.has_method("heal_percent_capped"):
		owner_node.heal_percent_capped(heal_percent_on_attack * ProgressionData.WEAPON_DRAIN_HEAL_MULTIPLIER)
	elif heal_percent_on_attack > 0.0 and owner_node.has_method("heal_percent"):
		owner_node.heal_percent(heal_percent_on_attack * ProgressionData.WEAPON_DRAIN_HEAL_MULTIPLIER)

	_current_charge_multiplier = _charge_multiplier()
	_execute_attack_mode(owner_node, target, direction)
	if charge_seconds > 0.0:
		_charge_time = 0.0
	_current_charge_multiplier = 1.0
	_maybe_fire_rhythm_echo(owner_node, target, direction)


# SCRUM-961: mode-rework артефакты меняют пейсинг оружия на точке потребления
# (само поле fire_interval пересобирает player._apply_weapon_scaling — не трогаем).
func _fire_interval_artifact_factor() -> float:
	var factor := 1.0
	if weapon_id == "priest_reliquary" and _owner_mod("reliquary_barrage_mode") > 0.0:
		factor *= 0.75  # «Реликварный залп»: частые залпы вместо лечения
	if weapon_id == "priest_censer" and _owner_mod("censer_vow_mode") > 0.0:
		factor *= 1.35  # «Обет кадила»: реже, но шире и больнее (DPS ≈ паритет)
	if weapon_id == "blast_powder" and _owner_mod("volatile_powder_mode") > 0.0:
		factor *= 0.78  # «Летучая пыль»: быстрый комфортный AoE без облака
	if weapon_id == "elementalist_meteor_core" and _owner_mod("meteor_heart_mode") > 0.0:
		factor *= 1.45  # «Сердце метеора»: самый долгий и жирный пэйофф
	return factor


# SCRUM-961 «Счетчик ритма»: каждый N-й гитарный каст срабатывает дважды — повтор
# на 55% урона с короткой задержкой. Деплой amp исключён (эхо не ставит второй
# усилитель), эхо не порождает эхо (гард по _rhythm_echo_scale).
# SCRUM-898: гейт по weapon_id гитариста — sound_wave_damage удалён, гитарные
# оружия теперь бьют магией и по damage_parameter неотличимы от прочей магии.
const _RHYTHM_ECHO_WEAPON_IDS := ["electric_guitar", "bass_guitar", "sound_amp"]


func _maybe_fire_rhythm_echo(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	if _rhythm_echo_scale < 1.0:
		return
	var echo_every := int(_owner_mod("rhythm_echo_every"))
	if echo_every <= 0 or attack_mode == "amp" or not weapon_id in _RHYTHM_ECHO_WEAPON_IDS:
		return
	_rhythm_cast_counter += 1
	if _rhythm_cast_counter < echo_every:
		return
	_rhythm_cast_counter = 0
	var weapon_self_id := get_instance_id()
	var owner_id := owner_node.get_instance_id()
	var target_id := target.get_instance_id() if target != null else 0
	var echo_tween := create_tween()
	echo_tween.tween_interval(0.12)
	echo_tween.tween_callback(func() -> void:
		var current_weapon := instance_from_id(weapon_self_id) as ClassWeapon
		var current_owner := instance_from_id(owner_id) as Node2D
		if current_weapon == null or current_owner == null or not is_instance_valid(current_weapon) or not is_instance_valid(current_owner):
			return
		current_weapon._rhythm_echo_scale = 0.55
		current_weapon._execute_attack_mode(current_owner, instance_from_id(target_id) as Node2D, direction)
		current_weapon._rhythm_echo_scale = 1.0
	)


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
	# SCRUM-551: захват owner_node/orb (Node) в lambda интермиттентно «освобождался»
	# под быстрым create/free в balance-CSV. Резолвим по instance_id внутри + гвард.
	var owner_id := owner_node.get_instance_id()
	var orb_id := orb.get_instance_id()
	var weapon_self_id := get_instance_id()
	orb_tween.tween_callback(func() -> void:
		var w := instance_from_id(weapon_self_id) as Node
		var o := instance_from_id(owner_id) as Node2D
		if w != null and o != null and is_instance_valid(w) and is_instance_valid(o):
			w.call("_damage_boomerang_return", o.global_position, direction, w.call("_rolled_damage", o))
		var orb_node := instance_from_id(orb_id) as Node
		if w != null and is_instance_valid(w) and orb_node != null and is_instance_valid(orb_node):
			w.call("_release_effect", orb_node)
	)


# SCRUM-961 «Руна обратной дуги»: обратный проход чакрамов идёт по широкой дуге
# (+boomerang_return_width_mult к коридору) и бьёт больнее (+boomerang_return_damage_mult).
# Без ключей тождествен прежнему возврату.
func _damage_boomerang_return(origin: Vector2, direction: Vector2, amount: float) -> void:
	var return_width := beam_width * (1.0 + _owner_mod("boomerang_return_width_mult"))
	var return_damage := amount * (1.0 + _owner_mod("boomerang_return_damage_mult"))
	for hit in _enemies_in_corridor(origin, direction, return_width, attack_range):
		_damage_enemy(hit["node"], return_damage)


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
	for hit in _enemies_in_corridor(origin, direction, beam_width, attack_range):
		_damage_enemy(hit["node"], amount)


func _spawn_damage_pool(pool_position: Vector2, tick_damage: float) -> void:
	# Ядовитое облако химика: тики по врагам в радиусе, группа player_weapon_effects.
	tick_damage *= POOL_TICK_DAMAGE_MULTIPLIER
	var combo_target := _find_combo_cloud(pool_position)
	var pool := Node2D.new()
	pool.name = "ChemistPoisonPool"
	_register_effect(pool)
	pool.add_to_group("chemist_clouds")
	pool.set_meta("pool_weapon_owner", get_instance_id())
	pool.set_meta("pool_duration", pool_duration)
	pool.set_meta("pool_tick_interval", pool_tick_interval)
	if pool_element != "":
		pool.set_meta("pool_element", pool_element)
	# SCRUM-553: наземная декаль — пул рисуется ПОД всеми боевыми сущностями
	# (игрок/монстры/пикапы z≈0), но над фоном (-100) и бордером (-20) арены.
	# Абсолютный слой (z_as_relative=false), чтобы не зависеть от z родителя-контейнера.
	pool.z_as_relative = false
	pool.z_index = GROUND_POOL_Z
	var visual := Node2D.new()
	visual.name = "PoolVisual"
	var pool_sprite := Sprite2D.new()
	pool_sprite.name = "PoolSprite"
	pool_sprite.texture = _pool_visual_texture()
	# SCRUM-961 «Прозрачная кислота» (виз. контракт): лужа прозрачнее (альфа ниже
	# базовой 0.82), опасность подчёркивает яркая danger-кромка при спавне.
	var clear_pool := weapon_id == "acid_flask" and _owner_mod("pool_duration_mult") > 0.0
	pool_sprite.modulate = Color(1.0, 1.0, 1.0, 0.58 if clear_pool else 0.82)
	var pool_scale := (aoe_radius * 1.42) / 256.0
	pool_sprite.scale = Vector2.ONE * pool_scale
	visual.add_child(pool_sprite)
	pool.add_child(visual)
	_projectile_parent().add_child(pool)
	pool.global_position = pool_position
	if clear_pool:
		AttackVfx.ring_pulse(_projectile_parent(), pool_position, aoe_radius * 0.78, Color(0.70, 1.0, 0.30, 0.55), true)
	_retire_excess_damage_pools(pool)
	if combo_target != null:
		_trigger_chemist_combo(pool, combo_target, tick_damage)

	var visual_tween := pool.create_tween()
	visual_tween.set_loops()
	visual_tween.tween_property(pool_sprite, "scale", Vector2.ONE * pool_scale * 1.045, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	visual_tween.parallel().tween_property(pool_sprite, "rotation", 0.045, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	visual_tween.tween_property(pool_sprite, "scale", Vector2.ONE * pool_scale * 0.985, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	visual_tween.parallel().tween_property(pool_sprite, "rotation", -0.035, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# SCRUM-649: гарантируем минимум 1 тик — при коротком pool_duration (< tick interval)
	# floor давал 0, и заспавненный пул не наносил урона (потраченная впустую атака).
	var tick_count := maxi(int(floor(pool_duration / maxf(pool_tick_interval, 0.2))), 1)
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
	var combo_damage := maxf(damage, tick_damage * 5.5) * pool_direct_damage_multiplier
	AttackVfx.orb_burst(_projectile_parent(), combo_position, combo_radius, Color(1.0, 0.75, 0.16, 0.50))
	_damage_enemies_in_circle_capped(combo_position, combo_radius, combo_damage, POOL_PROJECTILE_FULL_TARGETS, POOL_PROJECTILE_TARGET_DIMINISH)


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
			current_weapon.call("_damage_aoe_projectile_explosion", target_position, aoe_radius, explosion_damage)
			AttackVfx.orb_burst(current_weapon.call("_projectile_parent"), target_position, aoe_radius, visual_color)
			# SCRUM-961 «Зеркальная страница»: взрыв Книги тьмы дублируется на 55%
			# в точке, симметричной относительно мага; зеркало не зеркалится (§8.4).
			if current_owner != null and str(current_weapon.get("weapon_id")) == "dark_book" and float(current_weapon.call("_owner_mod", "book_mirror_blast")) > 0.0:
				var mirror_position: Vector2 = current_owner.global_position * 2.0 - target_position
				current_weapon.call("_damage_aoe_projectile_explosion", mirror_position, aoe_radius, explosion_damage * 0.55)
				AttackVfx.orb_burst(current_weapon.call("_projectile_parent"), mirror_position, aoe_radius, visual_color)
			# SCRUM-961 «Летучая пыль»: blast_powder без облака-DoT (трейд на темп).
			if leaves_pool and not bool(current_weapon.call("_volatile_powder_active")):
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
			current_weapon.call("_damage_enemies_in_circle_falloff", target_position, aoe_radius * 0.72, rolled * 0.42, current_weapon.get("damage_falloff"))
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
	for hit in _enemies_in_corridor(start, direction, beam_width, attack_range):
		hits.append(hit)

	hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["forward"]) < float(b["forward"])
	)

	var damage_value := _rolled_damage(owner_node)
	var hit_count := 0
	var hit_limit := _effective_pierce_count()
	var falloff := clampf(pierce_damage_falloff, 0.1, 1.0)
	# SCRUM-961: «Лунный расщепитель» ветвит болт с первой цели; «Цепная палочка»
	# лопает первые пробитые цели малыми взрывами.
	var moon_splits := int(_owner_mod("moon_split_targets")) if weapon_id == "moon_crossbow" else 0
	var wand_blasts := int(_owner_mod("wand_chain_blasts")) if weapon_id == "dark_wand" else 0
	for hit in hits:
		if hit_count >= hit_limit:
			break
		_damage_enemy(hit["node"], damage_value * pow(falloff, float(hit_count)))
		if hit_count == 0 and moon_splits > 0:
			_fire_moon_splits(hit["node"] as Node2D, damage_value, moon_splits)
		if hit_count < wand_blasts:
			_fire_wand_chain_blast(hit["node"] as Node2D, damage_value * 0.35)
		hit_count += 1


# SCRUM-961 «Лунный расщепитель»: болт ветвится с первой пробитой цели в соседние —
# под-лучи бьют 45% урона и дальше НЕ ветвятся (прямой удар без повторного сплита).
func _fire_moon_splits(first_hit: Node2D, damage_value: float, split_targets: int) -> void:
	if first_hit == null or not is_instance_valid(first_hit):
		return
	var excluded := {first_hit.get_instance_id(): true}
	for branch_target in TARGET_QUERY.nearest_many(self, first_hit.global_position, maxf(aoe_radius, 240.0), split_targets, excluded):
		if branch_target == null or not is_instance_valid(branch_target):
			continue
		var branch := AttackVfx.beam(_projectile_parent(), first_hit.global_position, branch_target.global_position, beam_width * 0.55, Color(visual_color.r, visual_color.g, visual_color.b, 0.36))
		_register_effect(branch)
		_damage_enemy(branch_target, damage_value * 0.45)


# SCRUM-961 «Цепная палочка»: малый взрыв (r70, 35% урона) у пробитой цели.
# Взрыв бьёт напрямую и новых взрывов/рикошетов не порождает (§8.4 анти-каскад).
func _fire_wand_chain_blast(center_enemy: Node2D, amount: float) -> void:
	if center_enemy == null or not is_instance_valid(center_enemy):
		return
	var center := center_enemy.global_position
	AttackVfx.orb_burst(_projectile_parent(), center, 70.0, visual_color)
	for enemy_node in TARGET_QUERY.in_radius(self, center, 70.0):
		if enemy_node.has_method("take_damage"):
			_call_take_damage(enemy_node, amount, {"damage_type": _weapon_damage_type()})


func _fire_single_dot_beam(owner_node: Node2D, direction: Vector2) -> void:
	var start := owner_node.global_position + direction * 26.0
	var finish := owner_node.global_position + direction * attack_range
	var beam_visual := AttackVfx.beam(_projectile_parent(), start, finish, beam_width, visual_color)
	_register_effect(beam_visual)

	var hits := []
	for hit in _enemies_in_corridor(start, direction, beam_width, attack_range):
		hits.append(hit)

	hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["forward"]) < float(b["forward"])
	)

	var damage_value := _rolled_damage(owner_node)
	var hit_count := 0
	var hit_limit := _effective_pierce_count()
	var falloff := clampf(pierce_damage_falloff, 0.1, 1.0)
	for hit in hits:
		if hit_count >= hit_limit:
			break
		_damage_enemy_with_dot(hit["node"], damage_value * pow(falloff, float(hit_count)), owner_node)
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
	# SCRUM-961 «Восстановительный пар»: по завершении связи — паровая зона у цели.
	if _owner_mod("restore_vapor_power") > 0.0:
		_spawn_restore_vapor(owner_node, target.global_position, damage_value)
	var extra_links := int(_extra_projectiles())
	if extra_links <= 0:
		return
	var used := {target.get_instance_id(): true}
	var previous_position := target.global_position
	for link_index in range(extra_links):
		var next_target := _find_nearest_enemy_from(previous_position, aoe_radius, used)
		if next_target == null:
			break
		used[next_target.get_instance_id()] = true
		var width: float = beam_width * maxf(0.42, pow(damage_falloff, float(link_index + 1)) + 0.10)
		var tether := AttackVfx.beam(_projectile_parent(), previous_position, next_target.global_position, width, visual_color)
		_register_effect(tether)
		var chained_damage := damage_value * pow(damage_falloff, float(link_index + 1))
		if dot_ticks > 0:
			_damage_enemy_with_dot(next_target, chained_damage, owner_node)
		else:
			_damage_enemy(next_target, chained_damage)
		previous_position = next_target.global_position


func _heal_owner_from_damage(owner_node: Node2D, dealt_damage: float) -> void:
	if heal_percent_of_damage <= 0.0 or owner_node == null or not is_instance_valid(owner_node):
		return
	if owner_node.get("health") == null or owner_node.get("max_health") == null:
		return
	# SCRUM-961 «Реликварный залп»: реликварий забывает лечение ради темпа/взрыва.
	if attack_mode == "priest_sanctify" and _owner_mod("reliquary_barrage_mode") > 0.0:
		return
	# SCRUM-961 «Зубья костяной пилы»: пила возвращает больше здоровья с урона.
	# Бонус только поверх живого heal-канала оружия — сустейн-гейт Доктора цел.
	var heal_ratio := heal_percent_of_damage
	if attack_mode == "stab_flurry":
		heal_ratio += _owner_mod("saw_heal_ratio_bonus")
	var heal_amount := dealt_damage * heal_ratio * ProgressionData.WEAPON_DRAIN_HEAL_MULTIPLIER
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


# SCRUM-961 «Восстановительный пар»: короткая паровая зона у цели связи — 2 тика
# за 1.4с, тик жжёт 28% урона связи (диминиш по толпе), 20% урона пара лечит
# Доктора через apply_drain_heal (капы drain-бюджета соблюдены).
func _spawn_restore_vapor(owner_node: Node2D, center: Vector2, link_damage: float) -> void:
	var vapor_radius := maxf(aoe_radius * 0.8, 90.0)
	var tick_damage := link_damage * 0.28
	var weapon_self_id := get_instance_id()
	var owner_id := owner_node.get_instance_id()
	AttackVfx.ring_pulse(_projectile_parent(), center, vapor_radius, Color(0.45, 1.0, 0.75, 0.35), true)
	var vapor_tween := create_tween()
	for tick_index in range(2):
		vapor_tween.tween_interval(0.7)
		vapor_tween.tween_callback(func() -> void:
			var current_weapon := instance_from_id(weapon_self_id) as ClassWeapon
			if current_weapon == null or not is_instance_valid(current_weapon) or current_weapon._effects_shutdown:
				return
			AttackVfx.ring_pulse(current_weapon._projectile_parent(), center, vapor_radius, Color(0.45, 1.0, 0.75, 0.26), false)
			current_weapon._damage_enemies_in_circle_capped(center, vapor_radius, tick_damage, 2, 1.5)
			var current_owner := instance_from_id(owner_id) as Node2D
			if current_owner != null and is_instance_valid(current_owner) and current_owner.has_method("apply_drain_heal"):
				current_owner.call("apply_drain_heal", tick_damage * 0.20)
		)


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
	var pulse_damage := _rolled_damage(owner_node)
	# SCRUM-961 «Голубой тотем»: пульс вороньего тотема злее (+raven_pulse_bonus).
	if weapon_id == "raven_totem":
		pulse_damage *= 1.0 + _owner_mod("raven_pulse_bonus")
	_damage_enemies_in_circle(origin, aoe_radius, pulse_damage)
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
	# SCRUM-961: «Сценический усилитель» продлевает жизнь ампа (+amp_lifetime_bonus,
	# кап деплоя — через amp_cap_bonus в player._apply_weapon_scaling); «Голубой
	# тотем» учащает пульс вороньего тотема (−15% интервала).
	var effective_amp_lifetime := amp_lifetime + _owner_mod("amp_lifetime_bonus")
	var effective_pulse_interval := amp_pulse_interval
	if weapon_id == "raven_totem" and _owner_mod("raven_pulse_bonus") > 0.0:
		effective_pulse_interval *= 0.85
	_emit_weapon_animation_event(owner_node, "deploy", effective_amp_lifetime, direction, {"pulse_interval": effective_pulse_interval})
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
	var pulse_count := maxi(int(floor(effective_amp_lifetime / maxf(effective_pulse_interval, 0.2))), 1)
	var amp_id := amp.get_instance_id()
	var weapon_id := get_instance_id()
	for pulse_index in range(pulse_count):
		pulse_tween.tween_interval(effective_pulse_interval)
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
			current_weapon.call("_salvage_device_refund")  # SCRUM-961 «Ядро утилизации»
		else:
			current_amp.queue_free()
	)

	# Первый пульс сразу при установке.
	_emit_weapon_animation_event(owner_node, "pulse", maxf(effective_pulse_interval, 0.2), direction, {"index": 0, "count": pulse_count})
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

	# SCRUM-961 «Корневой капкан»: капкан живёт до срабатывания (практичный потолок
	# волны 30с, кап 4 живых), жертвы укореняются и кровоточат; «Полевой чертеж»
	# продлевает жизнь обычных капканов от Лидерства.
	var root_mode := _owner_mod("trap_root_mode") > 0.0
	var effective_duration := 30.0 if root_mode else pool_duration * _blueprint_lifetime_multiplier()
	if root_mode:
		trap.set_meta("root_trap", true)
		_retire_excess_root_traps(trap)
	var state := {"triggered": false}
	var check_interval := maxf(pool_tick_interval, 0.15)
	var check_count := maxi(int(floor(effective_duration / check_interval)), 1)
	var trap_tween := trap.create_tween()
	var trap_id := trap.get_instance_id()
	var owner_id := owner_node.get_instance_id()
	var weapon_id := get_instance_id()
	var instant_arm := false
	if owner_node.has_method("meta_trap_instant_arm"):
		instant_arm = bool(owner_node.call("meta_trap_instant_arm", _meta_context()))
	for check_index in range(check_count):
		if check_index > 0 or not instant_arm:
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
			if root_mode:
				current_weapon.call("_apply_trap_root_bleed", current_trap.global_position)
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
	# SCRUM-961 «Шрапнель аркебузы»: коридор подавления шире (+25%), соседям
	# прилетает больше (falloff 0.38→0.52); основная цель без изменений.
	var shrapnel := _owner_mod("arquebus_shrapnel_bonus") > 0.0
	var corridor_width := suppression_width * (1.25 if shrapnel else 1.0)
	var neighbor_falloff := clampf(damage_falloff + (0.14 if shrapnel else 0.0), 0.0, 0.9)
	var hits := _enemies_in_corridor(start, direction, corridor_width, attack_range)
	if hits.is_empty():
		return
	var damage_value := _rolled_damage(owner_node)
	var primary := hits[0]["node"] as Node2D
	_damage_enemy(primary, damage_value)
	for hit_index in range(1, mini(hits.size(), 4)):
		_damage_enemy(hits[hit_index]["node"], damage_value * neighbor_falloff)
		_push_enemy(hits[hit_index]["node"], direction)


func _fire_grenade_cook(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	# SCRUM-961 «Длинный фитиль»: фитиль горит дольше (+0.35с телеграф), взрыв
	# окупается (+long_fuse_bonus урона, +10% радиуса).
	var fuse_bonus := _owner_mod("long_fuse_bonus")
	var effective_delay := grenade_delay + (0.35 if fuse_bonus > 0.0 else 0.0)
	var blast_radius := aoe_radius * (1.10 if fuse_bonus > 0.0 else 1.0)
	var blast_damage_mult := 1.0 + fuse_bonus
	_emit_weapon_animation_event(owner_node, "windup", maxf(effective_delay, 0.10), direction, {"delayed": true})
	var target_position: Vector2 = owner_node.global_position + direction * min(attack_range, 440.0)
	if target != null:
		target_position = target.global_position
	var telegraph := AttackVfx.ring_pulse(_projectile_parent(), target_position, blast_radius, visual_color, true)
	_register_effect(telegraph)
	var grenade := AttackVfx.orb_projectile(_projectile_parent(), owner_node.global_position + direction * 26.0, visual_color)
	_register_effect(grenade)
	var weapon_id := get_instance_id()
	var owner_id := owner_node.get_instance_id()
	var grenade_id := grenade.get_instance_id()
	var telegraph_id := telegraph.get_instance_id()
	var tween := create_tween()
	tween.tween_property(grenade, "global_position", target_position, maxf(effective_delay * 0.55, 0.08)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(maxf(effective_delay * 0.45, 0.04))
	tween.tween_callback(func() -> void:
		var current_weapon := instance_from_id(weapon_id) as Node
		var current_owner := instance_from_id(owner_id) as Node2D
		var current_grenade := instance_from_id(grenade_id) as Node
		var current_telegraph := instance_from_id(telegraph_id) as Node
		if current_weapon == null:
			if current_grenade != null:
				current_grenade.queue_free()
			if current_telegraph != null:
				current_telegraph.queue_free()
			return
		var explosion_damage := damage if current_owner == null else float(current_weapon.call("_rolled_damage", current_owner))
		explosion_damage *= blast_damage_mult
		if current_owner != null:
			current_weapon.call("_emit_weapon_animation_event", current_owner, "release", 0.0, direction, {"delayed": true})
		current_weapon.call("_damage_enemies_in_circle_falloff", target_position, blast_radius, explosion_damage, damage_falloff)
		AttackVfx.orb_burst(current_weapon.call("_projectile_parent"), target_position, blast_radius, visual_color)
		if current_grenade != null:
			current_weapon.call("_release_effect", current_grenade)
		if current_telegraph != null:
			current_weapon.call("_release_effect", current_telegraph)
	)


func _fire_bayonet_brace(owner_node: Node2D, direction: Vector2) -> void:
	var brace_visual := AttackVfx.slash(owner_node, direction, attack_range, visual_color)
	_register_effect(brace_visual)
	# SCRUM-961 «Спуск штыка»: при уколе шанс пули по линии за конусом стойки.
	if randf() < _owner_mod("bayonet_shot_chance"):
		_fire_bayonet_line_shot(owner_node, direction)
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


# SCRUM-961 «Спуск штыка»: пуля по линии — дальность 420, 70% урона первому
# врагу на траектории (закрывает мёртвую зону штыка по дальним).
func _fire_bayonet_line_shot(owner_node: Node2D, direction: Vector2) -> void:
	var start := owner_node.global_position + direction * 22.0
	var shot_range := 420.0
	var tracer := AttackVfx.beam(_projectile_parent(), start, owner_node.global_position + direction * shot_range, beam_width * 0.6, Color(visual_color.r, visual_color.g, visual_color.b, 0.50))
	_register_effect(tracer)
	var hits := _enemies_in_corridor(start, direction, beam_width, shot_range)
	if hits.is_empty():
		return
	_damage_enemy(hits[0]["node"], _rolled_damage(owner_node) * 0.7)


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
		# SCRUM-551: резолвим miss/self по instance_id (захват Node в lambda «освобождался» в CSV).
		var miss_id := miss.get_instance_id()
		var weapon_miss_self_id := get_instance_id()
		miss_tween.tween_callback(func() -> void:
			var w := instance_from_id(weapon_miss_self_id) as Node
			var m := instance_from_id(miss_id) as Node
			if w != null and is_instance_valid(w) and m != null and is_instance_valid(m):
				w.call("_release_effect", m)
		)
		return

	var chain_targets := [current_target]
	var used := {current_target.get_instance_id(): true}
	var search_origin := current_target.global_position
	# SCRUM-961 «Счастливая монета»: цепь скачет дольше (тот же falloff по хвосту).
	var chain_count := maxi(projectile_count + _extra_projectiles() + int(_owner_mod("coin_extra_bounces")), 1)
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
	# SCRUM-961 «Парализующее лезвие»: задетые ударом Плаща Захода коротко
	# укореняются (кламп скорости движка 0.25 = «паралич-лайт»).
	var root_duration := _owner_mod("backstab_root_duration")
	if root_duration > 0.0:
		_apply_backstab_root(backstab_target, root_duration)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_node := enemy as Node2D
		if enemy_node == null or enemy_node == backstab_target or not is_instance_valid(enemy_node):
			continue
		if back_position.distance_squared_to(enemy_node.global_position) <= pow(aoe_radius * 0.55, 2.0):
			_damage_enemy(enemy_node, damage * 0.35)
			if root_duration > 0.0:
				_apply_backstab_root(enemy_node, root_duration)
	var vanish := AttackVfx.ring_pulse(_projectile_parent(), back_position, 62.0, visual_color, false)
	_register_effect(vanish)


func _apply_backstab_root(enemy_node: Node2D, duration: float) -> void:
	StatusEffects.apply_status(enemy_node, "backstab_paralysis", {
		"duration": duration,
		"speed_multiplier": 0.25,
		"marker_color": Color(0.55, 0.70, 1.0, 1.0),
	})


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
	tween.tween_interval(maxf(_effective_smoke_duration(), 0.2))
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
	# SCRUM-961 «Четвертое кольцо»: земляная орбита (4-й орб добавляет EXISTS-ключ
	# elemental_orb_extra_count) — физический удар + мини-DoT + отброс на каждом
	# тике, квадратная разметка зоны отличает землю от трёх стихий.
	var earth_mode := _owner_mod("earth_orb_mode") > 0.0
	if earth_mode:
		colors.append(Color(0.72, 0.52, 0.24, 0.60))
		_draw_earth_square(owner_node.global_position, aoe_radius * 0.62)
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
			if earth_mode:
				current_weapon.call("_apply_earth_orb_strike", current_owner, tick_damage)
			# SCRUM-961 «Стихийный отдачник»: области толкают монстров от кастера.
			current_weapon.call("_apply_elemental_repulse", current_owner, current_owner.global_position, float(current_weapon.get("aoe_radius")))
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


# SCRUM-961 «Четвертое кольцо»: удар земли — физический (тип изолирован от
# магии кольца), мини-DoT и отброс; урон долевой от тика, без своего скейла.
func _apply_earth_orb_strike(owner_node: Node2D, tick_damage: float) -> void:
	var dot_tick := 1.0
	var parameters_raw = owner_node.get("derived_parameters")
	if parameters_raw is Dictionary:
		dot_tick = maxf(float((parameters_raw as Dictionary).get("dot_damage", 2.0)) * 0.35, 0.5)
	for enemy in TARGET_QUERY.in_radius(self, owner_node.global_position, aoe_radius):
		var enemy_node := enemy as Node2D
		if enemy_node == null:
			continue
		_damage_enemy(enemy_node, tick_damage * 0.5, false, "physical", false)
		StatusEffects.apply_status(enemy_node, "earth_orb_dot", {
			"duration": 1.2,
			"dot_damage": dot_tick,
			"dot_interval": 0.6,
			"marker_color": Color(0.72, 0.52, 0.24, 1.0),
		})
		var away := enemy_node.global_position - owner_node.global_position
		if away.length_squared() > 0.001:
			_push_enemy(enemy_node, away.normalized())


# SCRUM-961 «Четвертое кольцо»: квадратная разметка земляной зоны (4 грани).
func _draw_earth_square(center: Vector2, half_size: float) -> void:
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for corner_index in range(4):
		var edge_start: Vector2 = center + (corners[corner_index] as Vector2) * half_size
		var edge_end: Vector2 = center + (corners[(corner_index + 1) % 4] as Vector2) * half_size
		var edge := AttackVfx.beam(_projectile_parent(), edge_start, edge_end, 6.0, Color(0.72, 0.52, 0.24, 0.35))
		_register_effect(edge)


# SCRUM-961 «Стихийный отдачник»: радиальный пуш от кастера по врагам в зоне.
func _apply_elemental_repulse(owner_node: Node2D, center: Vector2, radius: float) -> void:
	var repulse_power := _owner_mod("elemental_repulse_power")
	if repulse_power <= 0.0 or owner_node == null or not is_instance_valid(owner_node):
		return
	for enemy in TARGET_QUERY.in_radius(self, center, radius):
		var enemy_node := enemy as Node2D
		if enemy_node == null:
			continue
		var away := enemy_node.global_position - owner_node.global_position
		if away.length_squared() <= 0.001:
			continue
		if enemy_node.has_method("apply_knockback"):
			enemy_node.apply_knockback(away.normalized() * repulse_power * 3.0)
		else:
			enemy_node.global_position += away.normalized() * repulse_power * 0.10


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
	var telegraph_id := telegraph.get_instance_id()
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
		# SCRUM-961 «Призматический крест»: X-линии пробивают карту насквозь.
		if float(current_weapon.call("_owner_mod", "prism_cross_pierce")) > 0.0:
			current_weapon.call("_fire_prism_extensions", start_a, end_a, damage_value)
			current_weapon.call("_fire_prism_extensions", start_b, end_b, damage_value)
		# SCRUM-961 «Стихийный отдачник»: зона креста толкает монстров от кастера.
		if current_owner != null:
			current_weapon.call("_apply_elemental_repulse", current_owner, center, float(current_weapon.get("aoe_radius")))
		var current_telegraph := instance_from_id(telegraph_id) as Node
		if current_telegraph != null:
			current_weapon.call("_release_effect", current_telegraph)
	)


# SCRUM-961 «Призматический крест»: продолжение линии в обе стороны за пределы
# зоны (по 900px), дальняя часть ослаблена до 60% сегментного урона.
func _fire_prism_extensions(start: Vector2, finish: Vector2, damage_value: float) -> void:
	var axis := finish - start
	if axis.length_squared() <= 0.001:
		return
	var axis_direction := axis.normalized()
	var far_damage := damage_value * 0.62 * 0.6
	for segment in [[finish, finish + axis_direction * 900.0], [start, start - axis_direction * 900.0]]:
		var segment_start: Vector2 = segment[0]
		var segment_end: Vector2 = segment[1]
		var extension := AttackVfx.beam(_projectile_parent(), segment_start, segment_end, beam_width * 0.7, Color(visual_color.r, visual_color.g, visual_color.b, 0.30))
		_register_effect(extension)
		_damage_enemies_in_segment(segment_start, segment_end, beam_width * 0.7, far_damage)


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
	var telegraph_id := telegraph.get_instance_id()
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
		# SCRUM-961 «Сердце метеора»: центральный удар жирнее (+70%), воронка
		# догорает DoT-зоной; пейсинг — в _fire_interval_artifact_factor.
		var heart_mode := float(current_weapon.call("_owner_mod", "meteor_heart_mode")) > 0.0
		current_weapon.call("_damage_enemies_in_circle_falloff", center, aoe_radius, damage_value * 0.96 * (1.7 if heart_mode else 1.0), 0.50)
		AttackVfx.orb_burst(current_weapon.call("_projectile_parent"), center, aoe_radius, visual_color)
		var count: int = maxi(int(current_weapon.get("shard_count")), 1)
		for shard_index in range(count):
			var angle := TAU * float(shard_index) / float(count)
			var shard_pos := center + Vector2.RIGHT.rotated(angle) * aoe_radius * 0.72
			current_weapon.call("_damage_enemies_in_circle_falloff", shard_pos, current_weapon.get("beam_width") * 1.45, damage_value * 0.28, 0.45)
			AttackVfx.orb_burst(current_weapon.call("_projectile_parent"), shard_pos, current_weapon.get("beam_width") * 1.45, current_weapon.get("visual_color"))
		if heart_mode:
			current_weapon.call("_spawn_meteor_crater", center)
		# SCRUM-961 «Стихийный отдачник»: удар метеора толкает монстров от кастера.
		if current_owner != null:
			current_weapon.call("_apply_elemental_repulse", current_owner, center, aoe_radius)
		var current_telegraph := instance_from_id(telegraph_id) as Node
		if current_telegraph != null:
			current_weapon.call("_release_effect", current_telegraph)
		if current_meteor != null:
			current_weapon.call("_release_effect", current_meteor)
	)


# SCRUM-961 «Сердце метеора»: воронка догорает 2.5с — dot-тики по врагам в кратере
# (диминиш толпы через _damage_enemies_in_pool, урон от dot_damage владельца).
func _spawn_meteor_crater(center: Vector2) -> void:
	var owner_node := _owner_node()
	var tick_damage := 2.0
	if owner_node != null:
		var parameters_raw = owner_node.get("derived_parameters")
		if parameters_raw is Dictionary:
			tick_damage = maxf(float((parameters_raw as Dictionary).get("dot_damage", 2.0)), 1.0)
	var crater_radius := aoe_radius * 0.72
	var weapon_self_id := get_instance_id()
	var crater_tween := create_tween()
	for tick_index in range(4):
		crater_tween.tween_interval(0.62)
		crater_tween.tween_callback(func() -> void:
			var current_weapon := instance_from_id(weapon_self_id) as ClassWeapon
			if current_weapon == null or not is_instance_valid(current_weapon) or current_weapon._effects_shutdown:
				return
			AttackVfx.ring_pulse(current_weapon._projectile_parent(), center, crater_radius, Color(1.0, 0.45, 0.15, 0.22), false)
			current_weapon._damage_enemies_in_pool(center, crater_radius, tick_damage)
		)


func _fire_sniper_lockshot(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var locked_target := target
	# SCRUM-961 «Патрон мертвого глаза»: винтовка предпочитает самую дальнюю цель
	# в радиусе (синергия с longshot_scope); терминальный взрыв — в release ниже.
	var terminal_ratio := _owner_mod("deadeye_terminal_blast")
	if terminal_ratio > 0.0:
		var far_target := _find_farthest_enemy(owner_node, attack_range)
		if far_target != null:
			locked_target = far_target
			var to_far := far_target.global_position - owner_node.global_position
			if to_far.length_squared() > 0.001:
				direction = to_far.normalized()
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
		# SCRUM-961 «Патрон мертвого глаза»: терминальный взрыв в конце линии.
		if terminal_ratio > 0.0:
			var blast_radius: float = float(current_weapon.get("beam_width")) * 2.2
			AttackVfx.orb_burst(current_weapon.call("_projectile_parent"), shot_finish, blast_radius, current_weapon.get("visual_color"))
			current_weapon.call("_damage_enemies_in_circle_falloff", shot_finish, blast_radius, damage_value * terminal_ratio, 0.5)
		var release_telegraph := telegraph_ref.get_ref() as Node
		if release_telegraph != null:
			current_weapon.call("_release_effect", release_telegraph)
	)


# SCRUM-961 «Патрон мертвого глаза»: самая дальняя цель в пределах дальности.
func _find_farthest_enemy(owner_node: Node2D, range_limit: float) -> Node2D:
	var best: Node2D = null
	var best_distance := -1.0
	var range_squared := range_limit * range_limit
	for enemy_node in TARGET_QUERY.enemies(self):
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var distance := owner_node.global_position.distance_squared_to(enemy_node.global_position)
		if distance <= range_squared and distance > best_distance:
			best_distance = distance
			best = enemy_node
	return best


func _fire_sniper_kill_zone(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var center: Vector2 = owner_node.global_position + direction * min(attack_range, 520.0)
	if target != null:
		center = target.global_position
	var zone := AttackVfx.ring_pulse(_projectile_parent(), center, aoe_radius, visual_color, true)
	_register_effect(zone)
	var zone_ref: WeakRef = weakref(zone)
	var weapon_id := get_instance_id()
	var owner_id := owner_node.get_instance_id()
	# SCRUM-961 «Метка наводчика»: зона ложится быстрее (телеграф −35%) и бьёт
	# плотнее (+1 удар серии).
	var fast_mark := _owner_mod("spotter_fast_mark") > 0.0
	var zone_tween := create_tween()
	zone_tween.tween_interval(maxf(grenade_delay * (0.65 if fast_mark else 1.0), 0.12))
	zone_tween.tween_callback(func() -> void:
		var current_weapon := instance_from_id(weapon_id) as Node
		var current_owner := instance_from_id(owner_id) as Node2D
		if current_weapon == null:
			var invalid_zone := zone_ref.get_ref() as Node
			if invalid_zone != null and is_instance_valid(invalid_zone):
				invalid_zone.queue_free()
			return
		var shots := int(maxi(current_weapon.get("projectile_count"), 1)) + (1 if fast_mark else 0)
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
	# SCRUM-961 «Барабан осколков»: больше осколков по ближайшим траекториям
	# (осколки наследуют falloff — прирост контролируем).
	var shard_count := maxi(split_count + _extra_projectiles() + int(_owner_mod("shatter_extra_splits")), 1)
	var shard_spread := deg_to_rad(42.0)
	var shard_range := minf(attack_range * 0.42, maxf(aoe_radius, 220.0))
	var pierce_limit := maxi(pierce_count, 1)
	for split_index in range(shard_count):
		var offset := 0.0
		if shard_count > 1:
			offset = lerpf(-shard_spread * 0.5, shard_spread * 0.5, float(split_index) / float(shard_count - 1))
		var shard_direction := shot_direction.rotated(offset).normalized()
		var shard_start := first_target.global_position + shard_direction * 10.0
		var shard_finish := first_target.global_position + shard_direction * shard_range
		var shard := AttackVfx.beam(_projectile_parent(), shard_start, shard_finish, beam_width * 0.55, Color(visual_color.r, visual_color.g, visual_color.b, 0.36))
		_register_effect(shard)
		var shard_damage := damage_value * pow(damage_falloff, float(split_index + 1))
		_damage_split_shard_corridor(shard_start, shard_direction, beam_width * 0.62, shard_range, shard_damage, used, pierce_limit)


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
	# SCRUM-961 «Реликварный залп»: взрыв освящения сильнее (+20%); лечение и темп —
	# в _heal_owner_from_damage / _fire_interval_artifact_factor.
	var barrage_blast_mult := 1.2 if _owner_mod("reliquary_barrage_mode") > 0.0 else 1.0
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
		var damage_value: float = (float(current_weapon.call("_rolled_damage", current_owner)) if current_owner != null else float(current_weapon.get("damage"))) * barrage_blast_mult
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
	# SCRUM-961 «Обет кадила»: пульс реже (fire_interval-фактор), но шире (+45%
	# радиуса) и больнее (+35%) — DPS ≈ паритет, пейсинг-переработка.
	var vow_mode := _owner_mod("censer_vow_mode") > 0.0
	var vow_radius_mult := 1.45 if vow_mode else 1.0
	var vow_damage_mult := 1.35 if vow_mode else 1.0
	_emit_weapon_animation_event(owner_node, "burst", maxf(burst_interval, 0.06) * float(maxi(pulse_count - 1, 1)), Vector2.RIGHT, {"count": pulse_count})
	if owner_node.has_method("meta_apply_priest_ward"):
		owner_node.call("meta_apply_priest_ward", maxf(burst_interval, 0.06) * float(pulse_count) + 0.35)
	var damage_value: float = _rolled_damage(owner_node) * vow_damage_mult
	for pulse_index in range(pulse_count):
		var ward_tween := create_tween()
		ward_tween.tween_interval(float(pulse_index) * maxf(burst_interval, 0.06))
		ward_tween.tween_callback(func() -> void:
			var current_weapon := instance_from_id(weapon_id) as Node
			var current_owner := instance_from_id(owner_id) as Node2D
			if current_weapon == null or current_owner == null:
				return
			current_weapon.call("_emit_weapon_animation_event", current_owner, "pulse", maxf(float(current_weapon.get("burst_interval")), 0.06), Vector2.RIGHT, {"index": pulse_index, "count": pulse_count})
			var radius: float = float(current_weapon.get("aoe_radius")) * (0.72 + 0.14 * float(pulse_index)) * vow_radius_mult
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
		current_target = _find_prayer_chain_next(owner_node.global_position, previous_position, aoe_radius, used)
	if owner_node != null and is_instance_valid(owner_node):
		AttackVfx.beam(_projectile_parent(), previous_position, owner_node.global_position, beam_width * 0.42, Color(visual_color.r, visual_color.g, visual_color.b, 0.24))
	# SCRUM-961 «Двойной колокол»: доп. взрывы 55% у первой цели И у жреца.
	# Overlap-protection: общий дедуп по instance id — враг ловит взрыв один раз за каст.
	if _owner_mod("chime_twin_toll") > 0.0:
		var blast_hit := {}
		_fire_twin_toll_blast(first_target.global_position, damage_value * 0.55, blast_hit)
		if owner_node != null and is_instance_valid(owner_node):
			_fire_twin_toll_blast(owner_node.global_position, damage_value * 0.55, blast_hit)


# SCRUM-961 «Двойной колокол»: одиночный взрыв колокола с дедупом по инстансу.
func _fire_twin_toll_blast(center: Vector2, amount: float, blast_hit: Dictionary) -> void:
	var blast_radius := maxf(aoe_radius * 0.6, 110.0)
	AttackVfx.ring_pulse(_projectile_parent(), center, blast_radius, visual_color, false)
	for enemy in TARGET_QUERY.in_radius(self, center, blast_radius):
		var enemy_node := enemy as Node2D
		if enemy_node == null:
			continue
		var enemy_id := enemy_node.get_instance_id()
		if blast_hit.has(enemy_id):
			continue
		blast_hit[enemy_id] = true
		_damage_enemy(enemy_node, amount)


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
	# SCRUM-961 «Расщепленный анализ»: первый задетый враг делится спорами с соседями.
	_apply_bio_split_analysis(TARGET_QUERY.nearest(self, center, aoe_radius), damage_value)
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
			# SCRUM-961 «Споровый конденсатор»: кольцо спор вешает замедление.
			current_weapon.call("_apply_bio_spore_slow", impact_center, radius)
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
	# SCRUM-961 «Цепь образцов»: дротик бьёт всех врагов на пути луча (70% основного),
	# терминальные пульсы анализа расцветают шире (+25% радиуса).
	var full_beam := _owner_mod("sample_beam_full_damage") > 0.0
	if full_beam:
		var to_target := first_target.global_position - start
		if to_target.length_squared() > 0.001:
			for hit in _enemies_in_corridor(start, to_target.normalized(), beam_width, to_target.length()):
				var line_enemy := hit["node"] as Node2D
				if line_enemy == null or line_enemy == first_target:
					continue
				_damage_enemy(line_enemy, damage_value * 0.7)
	var terminal_radius_mult := 1.25 if full_beam else 1.0
	# SCRUM-961 «Расщепленный анализ»: первичная цель делится образцами с соседями.
	_apply_bio_split_analysis(first_target, damage_value)
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
			var radius: float = float(current_weapon.get("aoe_radius")) * (0.70 + 0.16 * float(pulse_index)) * terminal_radius_mult
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
	# SCRUM-961 «Симбиотическая оболочка»: первичный хит семени сильнее (+35%);
	# продление тиков сети — в _damage_enemy_with_dot (symbiote_dot_extra_ticks).
	var impact_damage := damage_value * 0.72 * (1.0 + _owner_mod("symbiote_impact_bonus"))
	_damage_enemy_with_dot(first_target, impact_damage, owner_node)
	# SCRUM-961 «Расщепленный анализ»: первичная цель делится образцами с соседями.
	_apply_bio_split_analysis(first_target, impact_damage)
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


# SCRUM-961 «Споровый конденсатор»: кольца Споровой линзы вешают замедление
# (кламп движка ≥0.25 в StatusEffects.speed_multiplier — stack-safe).
func _apply_bio_spore_slow(center: Vector2, radius: float) -> void:
	var slow_power := _owner_mod("spore_slow_power")
	if slow_power <= 0.0:
		return
	for enemy_node in TARGET_QUERY.in_radius(self, center, radius):
		StatusEffects.apply_status(enemy_node, "bio_spore_slow", {
			"duration": 1.6,
			"speed_multiplier": maxf(1.0 - slow_power, 0.25),
			"marker_color": Color(0.55, 0.95, 0.35, 1.0),
		})


# SCRUM-961 «Расщепленный анализ»: первичная цель каста сплэшит долю урона на
# 2 ближайших врагов. Сплэш бьёт напрямую (без _damage_enemy) — без каскада.
func _apply_bio_split_analysis(primary: Node2D, amount: float) -> void:
	var split_ratio := _owner_mod("analysis_split_ratio")
	if split_ratio <= 0.0 or primary == null or not is_instance_valid(primary):
		return
	var excluded := {primary.get_instance_id(): true}
	for neighbor in TARGET_QUERY.nearest_many(self, primary.global_position, maxf(aoe_radius, 160.0), 2, excluded):
		if neighbor == null or not is_instance_valid(neighbor) or not neighbor.has_method("take_damage"):
			continue
		var spore := AttackVfx.beam(_projectile_parent(), primary.global_position, neighbor.global_position, beam_width * 0.5, Color(visual_color.r, visual_color.g, visual_color.b, 0.30))
		_register_effect(spore)
		_call_take_damage(neighbor, amount * split_ratio, {"damage_type": _weapon_damage_type()})


# SCRUM-961: он-хит статусы классовых артефактов. Только прямые хиты
# (apply_unique_melee_effects) — DoT/пул-тики стаки не накручивают.
func _apply_class_on_hit_statuses(enemy: Node) -> void:
	if not (enemy is Node2D) or not is_instance_valid(enemy):
		return
	if attack_mode.begins_with("bio_"):
		# «Колония торможения»: стакающееся замедление, кап 3 (−24% < кламп движка).
		var contact_slow := _owner_mod("bio_contact_slow")
		if contact_slow > 0.0:
			StatusEffects.apply_status(enemy, "bio_inhibitor_slow", {
				"duration": 2.0,
				"speed_multiplier": 1.0 - contact_slow,
				"stack_mode": "add",
				"max_stacks": 3,
				"marker_color": Color(0.40, 0.85, 0.30, 1.0),
			})
	elif attack_mode == "amp":
		# «Петля фидбэка»: пульсы усилителей стакают резонанс-уязвимость, кап 3 (+15%).
		var resonance := _owner_mod("amp_resonance_vuln")
		if resonance > 0.0:
			StatusEffects.apply_status(enemy, "amp_resonance_vuln", {
				"duration": 2.5,
				"damage_taken_multiplier": 1.0 + resonance,
				"stack_mode": "add",
				"max_stacks": 3,
				"marker_color": Color(0.30, 0.80, 1.0, 1.0),
			})


# SCRUM-961 «Второй залп»/«Боевой устав»: шанс повторить попадание ослабленным
# дублем (50% урона). duplicate_hit_chance сам по себе работает на аркебузе;
# duplicate_hit_universal распространяет дубль на гранату и штык. Суммарный шанс
# жёстко капится 0.65; дубль бьёт напрямую и дублей не порождает (§8.4).
func _maybe_duplicate_hit(enemy: Node, amount: float, hit_type: String) -> void:
	if hit_type == "dot":
		return
	var duplicate_chance := minf(_owner_mod("duplicate_hit_chance"), 0.65)
	if duplicate_chance <= 0.0:
		return
	var universal := _owner_mod("duplicate_hit_universal") > 0.0
	if attack_mode != "suppression_burst" and not (universal and attack_mode in ["grenade_cook", "bayonet_brace"]):
		return
	if randf() >= duplicate_chance:
		return
	if enemy is Node2D:
		AttackVfx.ring_pulse(_projectile_parent(), (enemy as Node2D).global_position, 46.0, Color(1.0, 0.85, 0.35, 0.40), false)
	_call_take_damage(enemy, amount * 0.5, {"damage_type": hit_type})


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
	# SCRUM-961 «Калибратор пресса»: коридор компрессии шире (+30%), урон не растёт.
	var corridor_width := suppression_width
	if _owner_mod("press_corridor_bonus") > 0.0:
		corridor_width *= 1.30
	var left_start := start + perpendicular * corridor_width * 0.5
	var left_finish := finish + perpendicular * corridor_width * 0.5
	var right_start := start - perpendicular * corridor_width * 0.5
	var right_finish := finish - perpendicular * corridor_width * 0.5
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
		current_weapon.call("_compress_enemies_to_axis", line_start, line_direction, line_perpendicular, corridor_width, float(current_weapon.get("attack_range")), float(current_weapon.get("knockback")))
		AttackVfx.ring_pulse(current_weapon.call("_projectile_parent"), clamp_center, float(current_weapon.get("aoe_radius")) * 0.42, current_weapon.get("visual_color"), false)
		current_weapon.call("_release_effect", left)
		current_weapon.call("_release_effect", right)
	)


func _fire_robot_reactor_vent(owner_node: Node2D, direction: Vector2) -> void:
	var vent_count := maxi(projectile_count + _extra_projectiles(), 4)
	var damage_value := _rolled_damage(owner_node) / float(maxi(vent_count, 1))
	AttackVfx.ring_pulse(_projectile_parent(), owner_node.global_position, aoe_radius * 0.62, visual_color, true)
	# SCRUM-961 «Реакторный хронометр»: выбросы идут последовательной ротацией с
	# накоплением фазы между кастами — круг покрывается без «мёртвых секторов»;
	# цикл наследует скорость атаки через fire_interval, выбросы не теряются.
	if _owner_mod("reactor_smooth_rotation") > 0.0:
		_reactor_vent_phase = fmod(_reactor_vent_phase + TAU / float(vent_count) * 0.5, TAU)
		var step := maxf(fire_interval, 0.2) * 0.85 / float(vent_count)
		var weapon_self_id := get_instance_id()
		var owner_id := owner_node.get_instance_id()
		var rotation_tween := create_tween()
		for vent_index in range(vent_count):
			var vent_direction := direction.rotated(_reactor_vent_phase + TAU * float(vent_index) / float(vent_count))
			if vent_index > 0:
				rotation_tween.tween_interval(step)
			rotation_tween.tween_callback(func() -> void:
				var current_weapon := instance_from_id(weapon_self_id) as ClassWeapon
				var current_owner := instance_from_id(owner_id) as Node2D
				if current_weapon == null or current_owner == null or not is_instance_valid(current_weapon) or not is_instance_valid(current_owner) or current_weapon._effects_shutdown:
					return
				current_weapon._fire_reactor_single_vent(current_owner, vent_direction, damage_value)
			)
		return
	for vent_index in range(vent_count):
		var vent_direction := direction.rotated(TAU * float(vent_index) / float(vent_count))
		_fire_reactor_single_vent(owner_node, vent_direction, damage_value)


func _fire_reactor_single_vent(owner_node: Node2D, vent_direction: Vector2, damage_value: float) -> void:
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
	# SCRUM-888: «Ключ Часового» = развёртка стационарных турелей.
	# По кулдауну оружия ставится турель (scripts/sentry_turret.gd); лимит
	# max_summons (жёсткий кап 2) — старейшая заменяется с мини-VFX. Турель
	# живёт до конца боя (чистка: player_weapon_effects / cleanup_effects) и
	# сама обстреливает ближайших врагов снарядами. Мгновенный первый выстрел
	# при развёртке — прямой компонент бюджет-модели (_budget_hit_model),
	# сустейн турелей моделирует _budget_summon_dps.
	_emit_weapon_animation_event(owner_node, "deploy", 0.62, direction, {"pulse_interval": amp_pulse_interval})
	var alive_turrets: Array[Node] = []
	for device in _deployed_amps:
		if device != null and is_instance_valid(device):
			alive_turrets.append(device)
	_deployed_amps = alive_turrets
	var turret_scene := load("res://scenes/SentryTurret.tscn") as PackedScene
	if turret_scene == null:
		return
	var turret := turret_scene.instantiate() as Node2D
	if turret == null:
		return
	if turret.has_method("setup"):
		turret.call("setup", self, owner_node)
	_projectile_parent().add_child(turret)
	_register_effect(turret)
	turret.global_position = owner_node.global_position + direction * 92.0
	_deployed_amps.append(turret)
	# SCRUM-961 «Магазин турели»: в режиме магазина турели уходят по расстрелу
	# боезапаса (sentry_turret), а не заменой старейшей — потолок мягко выше (+2).
	var turret_limit := maxi(max_summons, 1)
	if _owner_mod("sentry_magazine_bonus") > 0.0:
		turret_limit += 2
	while _deployed_amps.size() > turret_limit:
		var oldest: Node = _deployed_amps.pop_front()
		if oldest != null and is_instance_valid(oldest) and oldest is Node2D:
			AttackVfx.ring_pulse(_projectile_parent(), (oldest as Node2D).global_position, aoe_radius * 0.30, visual_color, false)
		_release_effect(oldest)
		_salvage_device_refund()  # SCRUM-961 «Ядро утилизации»

	AttackVfx.ring_pulse(_projectile_parent(), turret.global_position, aoe_radius * 0.45, visual_color, false)
	# Мгновенное включение: турель сразу обстреливает ближайшего врага.
	if turret.has_method("try_fire"):
		turret.call("try_fire", self)


func _engineer_turret_projectile_hit(target_instance_id: int, shot_damage: float) -> void:
	# Прилёт снаряда турели (колбэк твина полёта; цель — по instance id,
	# см. SCRUM-551: без захвата узлов в лямбдах).
	if _effects_shutdown:
		return
	var target := instance_from_id(target_instance_id) as Node2D
	if target == null or not is_instance_valid(target):
		return
	_damage_enemy(target, shot_damage)
	_damage_engineer_sentry_splash(target, shot_damage)


func _damage_engineer_sentry_splash(primary_target: Node2D, shot_damage: float) -> void:
	if primary_target == null or not is_instance_valid(primary_target):
		return
	if sentry_splash_radius <= 0.0 or sentry_splash_damage_multiplier <= 0.0 or sentry_splash_target_cap <= 0:
		return
	var excluded := {primary_target.get_instance_id(): true}
	var splash_targets := TARGET_QUERY.nearest_many(self, primary_target.global_position, sentry_splash_radius, sentry_splash_target_cap, excluded)
	for index in range(splash_targets.size()):
		var splash_target := splash_targets[index] as Node2D
		if splash_target == null or not is_instance_valid(splash_target):
			continue
		var factor := sentry_splash_damage_multiplier / (1.0 + float(index) * 0.75)
		_damage_enemy(splash_target, shot_damage * factor, false, _weapon_damage_type(), false)


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
	# SCRUM-961 «Гироскоп дрона»: +1 цель цепи (drone_extra_links).
	var links := maxi(projectile_count + _extra_projectiles() + int(_owner_mod("drone_extra_links")), 1)
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
	# SCRUM-603: summon-support лечение тоже через per-second бюджет (capped).
	if summon_support_heal_percent > 0.0 and owner_node.has_method("heal_percent_capped"):
		owner_node.heal_percent_capped(summon_support_heal_percent)
	elif summon_support_heal_percent > 0.0 and owner_node.has_method("heal_percent"):
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
	mine.set_meta("pool_duration", pool_duration)
	mine.set_meta("pool_tick_interval", pool_tick_interval)
	mine.set_meta("persistent_hazard", true)
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
	# SCRUM-961 «Минная сумка»: мина лежит до срабатывания (одноразовый подрыв,
	# кап 5 живых, автоподрыв на исходе окна) — отдельный жизненный цикл.
	if _owner_mod("mine_persistent_arm") > 0.0:
		_arm_persistent_mine(mine, owner_node, mine_index)
		return
	var state := {"trigger_count": 0}
	var check_interval := maxf(pool_tick_interval, 0.10)
	# SCRUM-961 «Полевой чертеж»: Лидерство продлевает жизнь минного поля.
	var effective_duration := pool_duration * _blueprint_lifetime_multiplier()
	var check_count := maxi(int(floor(effective_duration / check_interval)) + 1, 1)
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
			if current_weapon == null or current_mine == null:
				return
			if not current_weapon.call("_has_enemy_in_circle", current_mine.global_position, float(current_weapon.get("aoe_radius")) * 0.62):
				return
			state["trigger_count"] = int(state["trigger_count"]) + 1
			if current_owner != null:
				current_weapon.call("_emit_weapon_animation_event", current_owner, "release", 0.0, Vector2.RIGHT, {"mine_index": mine_index})
			var mine_damage: float = float(current_weapon.call("_rolled_damage", current_owner)) if current_owner != null else float(current_weapon.get("damage"))
			mine_damage *= pow(float(current_weapon.get("damage_falloff")), float(mine_index) * 0.35)
			current_weapon.call("_damage_enemies_in_circle_falloff", current_mine.global_position, float(current_weapon.get("aoe_radius")), mine_damage, float(current_weapon.get("damage_falloff")))
			AttackVfx.orb_burst(current_weapon.call("_projectile_parent"), current_mine.global_position, float(current_weapon.get("aoe_radius")) * 0.72, current_weapon.get("visual_color"))
		)
	var elapsed_checks := float(check_count - 1) * check_interval
	var remaining_lifetime := maxf(effective_duration - elapsed_checks, 0.0)
	if remaining_lifetime > 0.001:
		mine_tween.tween_interval(remaining_lifetime)
	mine_tween.tween_callback(func() -> void:
		var current_weapon := instance_from_id(weapon_id) as Node
		var current_mine := instance_from_id(mine_id) as Node
		if current_mine == null:
			return
		if current_weapon != null:
			current_weapon.call("_release_effect", current_mine)
			current_weapon.call("_salvage_device_refund")  # SCRUM-961 «Ядро утилизации»
		else:
			current_mine.queue_free()
	)


# SCRUM-961 «Минная сумка»: жизненный цикл персистентной мины — лежит до
# срабатывания (враг в радиусе после safe-задержки 2.5с), автоподрыв через 6с;
# один подрыв на мину, кап 5 живых (при полном поле новые мины не ставятся,
# пока слот не освободится подрывом/тайм-аутом — см. SCRUM-964 QA-фикс ниже).
const PERSISTENT_MINE_SAFE_DELAY := 2.5
const PERSISTENT_MINE_AUTO_DETONATE := 6.0
const PERSISTENT_MINE_CAP := 5


func _arm_persistent_mine(mine: Node2D, owner_node: Node2D, mine_index: int) -> void:
	# SCRUM-964 QA-фикс: при полном поле (кап 5) НОВАЯ мина не ставится (skip),
	# вместо тихого снятия старейшей. Прежний retire-oldest под живым автоогнём
	# (fire_interval ~0.79с × залп 3) вытеснял мины в ~1.3с — раньше армирования
	# 2.5с, из-за чего ни одна мина не доживала ни до proximity-подрыва, ни до
	# автоподрыва 6с: оружие с «Минной сумкой» давало 0 урона в непрерывном бою.
	if _alive_persistent_mines(mine).size() >= PERSISTENT_MINE_CAP:
		_release_effect(mine)
		return
	mine.set_meta("persistent_mine", true)
	var check_interval := maxf(pool_tick_interval, 0.10)
	var check_count := maxi(int(ceil(PERSISTENT_MINE_AUTO_DETONATE / check_interval)), 1)
	var state := {"triggered": false}
	var weapon_id := get_instance_id()
	var owner_id := owner_node.get_instance_id()
	var mine_id := mine.get_instance_id()
	var mine_tween := mine.create_tween()
	for check_index in range(check_count):
		mine_tween.tween_interval(check_interval)
		var elapsed := float(check_index + 1) * check_interval
		var timeout := check_index >= check_count - 1
		mine_tween.tween_callback(func() -> void:
			var current_weapon := instance_from_id(weapon_id) as Node
			var current_mine := instance_from_id(mine_id) as Node2D
			if current_weapon == null or current_mine == null or bool(state["triggered"]):
				return
			var armed := elapsed >= PERSISTENT_MINE_SAFE_DELAY
			var enemy_near: bool = current_weapon.call("_has_enemy_in_circle", current_mine.global_position, float(current_weapon.get("aoe_radius")) * 0.62)
			if not timeout and not (armed and enemy_near):
				return
			state["triggered"] = true
			var current_owner := instance_from_id(owner_id) as Node2D
			if current_owner != null:
				current_weapon.call("_emit_weapon_animation_event", current_owner, "release", 0.0, Vector2.RIGHT, {"mine_index": mine_index})
			var mine_damage: float = float(current_weapon.call("_rolled_damage", current_owner)) if current_owner != null else float(current_weapon.get("damage"))
			current_weapon.call("_damage_enemies_in_circle_falloff", current_mine.global_position, float(current_weapon.get("aoe_radius")), mine_damage, float(current_weapon.get("damage_falloff")))
			AttackVfx.orb_burst(current_weapon.call("_projectile_parent"), current_mine.global_position, float(current_weapon.get("aoe_radius")) * 0.72, current_weapon.get("visual_color"))
			current_weapon.call("_release_effect", current_mine)
			current_weapon.call("_salvage_device_refund")  # SCRUM-961 «Ядро утилизации»
		)


# SCRUM-961 «Корневой капкан»: сработавший капкан укореняет жертв (кламп движка
# 0.25) и вешает кровотечение ~3 тика по dot_damage владельца.
func _apply_trap_root_bleed(center: Vector2) -> void:
	var owner_node := _owner_node()
	var bleed_tick := 3.0
	if owner_node != null:
		var parameters_raw = owner_node.get("derived_parameters")
		if parameters_raw is Dictionary:
			bleed_tick = maxf(float((parameters_raw as Dictionary).get("dot_damage", 3.0)), 1.0)
	for enemy_node in TARGET_QUERY.in_radius(self, center, aoe_radius):
		StatusEffects.apply_status(enemy_node, "trap_root_snare", {
			"duration": 1.1,
			"speed_multiplier": 0.25,
			"marker_color": Color(0.60, 0.42, 0.20, 1.0),
		})
		StatusEffects.apply_status(enemy_node, "trap_bleed", {
			"duration": 1.6,
			"dot_damage": bleed_tick,
			"dot_interval": 0.5,
			"marker_color": Color(0.85, 0.20, 0.15, 1.0),
		})


func _retire_excess_root_traps(new_trap: Node2D) -> void:
	var alive_traps: Array[Node2D] = []
	for effect in _alive_effects():
		if effect is Node2D and effect.has_meta("root_trap") and effect != new_trap:
			alive_traps.append(effect as Node2D)
	while alive_traps.size() >= 4:
		var oldest := alive_traps.pop_front() as Node2D
		_release_effect(oldest)


func _alive_persistent_mines(exclude: Node2D = null) -> Array[Node2D]:
	var alive_mines: Array[Node2D] = []
	for effect in _alive_effects():
		if effect is Node2D and effect.has_meta("persistent_mine") and effect != exclude:
			alive_mines.append(effect as Node2D)
	return alive_mines


# SCRUM-961 «Ядро утилизации»: отжившее/подорванное устройство возвращает
# долю перезарядки текущего deploy-оружия.
func _salvage_device_refund() -> void:
	var refund_ratio := _owner_mod("salvage_refund_ratio")
	if refund_ratio <= 0.0:
		return
	_cooldown = maxf(_cooldown - fire_interval * refund_ratio, 0.0)


# SCRUM-961 «Полевой чертеж»: Лидерство продлевает жизнь мин/ловушек (+12% за 6 LDR).
func _blueprint_lifetime_multiplier() -> float:
	if _owner_mod("blueprint_leadership_scaling") <= 0.0:
		return 1.0
	var owner_node := _owner_node()
	if owner_node == null:
		return 1.0
	var stats = owner_node.get("stats")
	if not (stats is Dictionary):
		return 1.0
	return 1.0 + 0.12 * floor(float((stats as Dictionary).get("leadership", 0.0)) / 6.0)


func _pull_enemies_toward(center: Vector2, radius: float, force: float) -> void:
	# SCRUM-961 «Ядро якоря»: обычных (не элита/босс) врагов стягивает сильнее.
	var anchor_bonus := _owner_mod("anchor_pull_power") if attack_mode == "robot_magnetic_anchor" else 0.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var to_center := center - enemy_node.global_position
		var distance := to_center.length()
		if distance <= 0.001 or distance > radius:
			continue
		var pull_strength := force * lerpf(1.0, 0.35, distance / maxf(radius, 1.0))
		if anchor_bonus > 0.0 and _is_non_elite_target(enemy_node):
			pull_strength *= 1.0 + anchor_bonus
		if enemy_node.has_method("apply_knockback"):
			enemy_node.apply_knockback(to_center.normalized() * pull_strength)
		else:
			enemy_node.global_position += to_center.normalized() * pull_strength * 0.10


# SCRUM-961: рядовой враг (не элитка/босс) — для эффектов, которые по контракту
# «элитки/боссы прямо исключены» (ядро якоря и т.п.).
func _is_non_elite_target(enemy_node: Node2D) -> bool:
	if enemy_node.is_in_group("elite_enemies") or enemy_node.is_in_group("bosses"):
		return false
	if enemy_node.has_meta("elite_behavior") or enemy_node.has_meta("boss_id"):
		return false
	return true


func _compress_enemies_to_axis(origin: Vector2, direction: Vector2, perpendicular: Vector2, width: float, range_limit: float, force: float) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var to_enemy := enemy_node.global_position - origin
		var forward := to_enemy.dot(direction)
		if forward < -CONTACT_STUCK_HIT_BACK_ALLOWANCE or forward > range_limit:
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
	# SCRUM-961 «Счастливая монета»: coin_steal_bonus добавляет краденое золото.
	var effective_steal := steal_money + int(_owner_mod("coin_steal_bonus")) if steal_money > 0 else steal_money
	if effective_steal <= 0 or owner_node == null or not owner_node.has_method("gain_money"):
		return
	if hit_index > 0 and randf() > 0.42:
		return
	owner_node.gain_money(effective_steal)


func _apply_temporary_dodge(owner_node: Node2D) -> void:
	if dodge_bonus <= 0.0 or owner_node == null:
		return
	# SCRUM-961 «Дымный тайник»: завеса плотнее (+smoke_dodge_bonus) и дольше
	# (_effective_smoke_duration); снимаем ровно добавленное.
	var effective_dodge := dodge_bonus + _owner_mod("smoke_dodge_bonus")
	var modifiers_raw = owner_node.get("run_modifiers")
	if not (modifiers_raw is Dictionary):
		return
	var modifiers: Dictionary = modifiers_raw
	modifiers["dodge_flat"] = float(modifiers.get("dodge_flat", 0.0)) + effective_dodge
	if owner_node.has_method("_apply_stat_scaling"):
		owner_node.call("_apply_stat_scaling", false, owner_node.get("max_health"))
	var owner_id := owner_node.get_instance_id()
	var remove_tween := create_tween()
	remove_tween.tween_interval(maxf(_effective_smoke_duration(), 0.2))
	remove_tween.tween_callback(func() -> void:
		var current_owner := instance_from_id(owner_id) as Node
		if current_owner == null:
			return
		var current_modifiers_raw = current_owner.get("run_modifiers")
		if not (current_modifiers_raw is Dictionary):
			return
		var current_modifiers: Dictionary = current_modifiers_raw
		current_modifiers["dodge_flat"] = maxf(0.0, float(current_modifiers.get("dodge_flat", 0.0)) - effective_dodge)
		if current_owner.has_method("_apply_stat_scaling"):
			current_owner.call("_apply_stat_scaling", false, current_owner.get("max_health"))
	)


# SCRUM-961 «Дымный тайник»: длительность завесы с бонусом артефакта.
func _effective_smoke_duration() -> float:
	return smoke_duration * (1.0 + _owner_mod("smoke_duration_mult"))


func _extra_projectiles() -> int:
	var owner_node := _owner_node()
	if owner_node == null:
		return 0
	var mods = owner_node.get("run_modifiers")
	var generic_extra := 0
	if mods is Dictionary:
		generic_extra = int((mods as Dictionary).get("extra_projectile", 0.0))
	var semantic_extra := 0
	if owner_node.has_method("meta_extra_projectiles"):
		semantic_extra = int(owner_node.call("meta_extra_projectiles", _meta_context()))
	return generic_extra + semantic_extra


func _effective_pierce_count() -> int:
	var owner_node := _owner_node()
	var extra := 0
	if owner_node != null and owner_node.has_method("meta_extra_pierce"):
		extra = int(owner_node.call("meta_extra_pierce", _meta_context({"charge_seconds": charge_seconds})))
	return maxi(pierce_count + extra, 1)


func _meta_context(extra := {}) -> Dictionary:
	var owner_node := _owner_node()
	var payload: Dictionary = extra.duplicate(true) if extra is Dictionary else {}
	payload["pool_element"] = pool_element
	payload["leaves_pool"] = leaves_pool
	payload["summon_role"] = summon_role
	payload["charge_seconds"] = charge_seconds
	if owner_node != null and owner_node.has_method("meta_context_for_weapon"):
		return owner_node.call("meta_context_for_weapon", self, payload)
	payload["weapon_id"] = weapon_id
	payload["attack_mode"] = attack_mode
	payload["damage_parameter"] = damage_parameter
	payload["damage_type"] = str(payload.get("damage_type", _weapon_damage_type()))
	return payload


func _find_closest_enemy(owner_node: Node2D, range_limit := -1.0) -> Node2D:
	var max_distance := attack_range if range_limit < 0.0 else range_limit
	return TARGET_QUERY.nearest(self, owner_node.global_position, max_distance)


func _owner_uses_cursor_aim(owner_node: Node) -> bool:
	return owner_node != null and owner_node.has_method("attack_aim_mode") and str(owner_node.call("attack_aim_mode")) == "cursor"


func _enemies_in_corridor(origin: Vector2, direction: Vector2, width: float, range_limit: float) -> Array:
	return TARGET_QUERY.in_corridor(self, origin, direction, width, range_limit, _line_back_allowance(origin))


func _line_back_allowance(origin: Vector2) -> float:
	var owner_node := _owner_node()
	if owner_node == null:
		return 0.0
	if origin.distance_squared_to(owner_node.global_position) <= CONTACT_STUCK_HIT_BACK_ALLOWANCE * CONTACT_STUCK_HIT_BACK_ALLOWANCE:
		return CONTACT_STUCK_HIT_BACK_ALLOWANCE
	return 0.0


func _find_nearest_enemy_from(origin: Vector2, range_limit: float, excluded_ids: Dictionary) -> Node2D:
	return TARGET_QUERY.nearest(self, origin, range_limit, excluded_ids)


func _nearest_enemies_from(origin: Vector2, range_limit: float, count: int, excluded_ids: Dictionary = {}) -> Array:
	return TARGET_QUERY.nearest_many(self, origin, range_limit, count, excluded_ids)


func _find_prayer_chain_next(owner_position: Vector2, previous_position: Vector2, range_limit: float, excluded_ids: Dictionary) -> Node2D:
	var best_enemy: Node2D = null
	var best_score := INF
	var range_squared := range_limit * range_limit
	for enemy_node in TARGET_QUERY.enemies(self):
		if enemy_node == null or not is_instance_valid(enemy_node) or excluded_ids.has(enemy_node.get_instance_id()):
			continue
		if previous_position.distance_squared_to(enemy_node.global_position) > range_squared:
			continue
		var score := owner_position.distance_squared_to(enemy_node.global_position) * 0.65 + previous_position.distance_squared_to(enemy_node.global_position) * 0.35
		if score < best_score:
			best_score = score
			best_enemy = enemy_node
	return best_enemy


func _enemies_in_circle_sorted(origin: Vector2, radius: float, count: int) -> Array:
	return _nearest_enemies_from(origin, radius, count)


func _is_enemy_inside_wave(origin: Vector2, enemy_position: Vector2, direction: Vector2) -> bool:
	var perpendicular := Vector2(-direction.y, direction.x)
	var to_enemy := enemy_position - origin
	var forward := to_enemy.dot(direction)
	if forward < -CONTACT_STUCK_HIT_BACK_ALLOWANCE or forward > attack_range:
		return false
	var width_ratio: float = clamp(forward / max(attack_range, 1.0), 0.0, 1.0)
	# SCRUM-961 «Зубья костяной пилы»: веер пилы шире (+saw_arc_width_mult).
	var effective_wave_width := wave_width
	if attack_mode == "stab_flurry":
		effective_wave_width *= 1.0 + _owner_mod("saw_arc_width_mult")
	var half_width := lerpf(58.0, effective_wave_width * 0.5, width_ratio)
	return abs(to_enemy.dot(perpendicular)) <= half_width


# SCRUM-523: КАНАЛ урона оружия → строковый тип для палитры боевых цифр.
# Источник истины о канале — damage_parameter оружия (см. progression_data_weapons):
# "magic_damage" → магия, всё прочее ("damage") → физика (SCRUM-898: звуковой
# канал удалён, бывшие sound-оружия бьют магией). DoT-тики красятся "dot" в точке
# тика, а не отсюда. Цвет берёт владелец цифры (enemy.gd) через
# Enemy.damage_type_color() — здесь только маршрутизация типа.
func _weapon_damage_type() -> String:
	match damage_parameter:
		"magic_damage":
			return "magic"
		_:
			return "physical"


func _damage_enemy(enemy: Node, amount: float, apply_unique_melee_effects := true, damage_type := "", notify_owner_hit := true) -> void:
	if enemy != null and is_instance_valid(enemy) and enemy.has_method("take_damage"):
		var hit_type := damage_type if damage_type != "" else _weapon_damage_type()
		var owner_node := _owner_node()
		var hit_context := _meta_context({"damage_type": hit_type})
		var is_critical := _last_attack_crit and apply_unique_melee_effects
		hit_context["critical"] = is_critical
		var final_amount := amount
		if owner_node != null and owner_node.has_method("meta_damage_multiplier"):
			final_amount *= float(owner_node.call("meta_damage_multiplier", hit_context, enemy))
		_call_take_damage(enemy, final_amount, {"critical": is_critical, "damage_type": hit_type})
		# SCRUM-961: он-хит статусы и дубль-выстрел солдата (только прямые хиты).
		if apply_unique_melee_effects:
			_apply_class_on_hit_statuses(enemy)
			_maybe_duplicate_hit(enemy, final_amount, hit_type)
		if notify_owner_hit and owner_node != null and owner_node.has_method("on_weapon_hit"):
			owner_node.on_weapon_hit(enemy, final_amount, _last_attack_crit, hit_context)  # SCRUM-500/SCRUM-835: крит + semantic hit context
		_heal_owner_from_damage(owner_node, final_amount)
		if _last_attack_crit and crit_shadow_burst_radius > 0.0 and owner_node != null and owner_node.has_method("trigger_assassin_crit_shadow"):
			owner_node.trigger_assassin_crit_shadow(enemy, crit_shadow_burst_radius)
		if apply_unique_melee_effects and owner_node != null:
			_apply_unique_melee_hit_effects(owner_node, enemy, final_amount)


func _apply_unique_melee_hit_effects(owner_node: Node2D, enemy: Node, amount: float) -> void:
	var enemy_node := enemy as Node2D
	if enemy_node == null or not is_instance_valid(enemy_node):
		return
	var direction := enemy_node.global_position - owner_node.global_position
	var distance := direction.length()
	# SCRUM-523: добивания/осколки красим тем же каналом, что основное попадание.
	var hit_type := _weapon_damage_type()
	if melee_close_bonus_radius > 0.0 and melee_close_damage_multiplier > 1.0 and distance <= melee_close_bonus_radius:
		_call_take_damage(enemy_node, amount * (melee_close_damage_multiplier - 1.0), {"damage_type": hit_type})
	if melee_execute_threshold > 0.0 and melee_execute_multiplier > 1.0:
		var max_hp := float(enemy_node.get("max_health")) if enemy_node.get("max_health") != null else 0.0
		var health := float(enemy_node.get("health")) if enemy_node.get("health") != null else max_hp
		if max_hp > 0.0 and health / max_hp <= melee_execute_threshold:
			_call_take_damage(enemy_node, amount * (melee_execute_multiplier - 1.0), {"damage_type": hit_type})
	if melee_stagger_knockback_multiplier > 0.0 and direction.length_squared() > 0.001:
		_push_enemy_scaled(enemy_node, direction.normalized(), melee_stagger_knockback_multiplier)
	if melee_arc_followup_radius > 0.0 and melee_arc_followup_multiplier > 0.0:
		var splash_damage := amount * melee_arc_followup_multiplier
		for nearby in TARGET_QUERY.in_radius(self, enemy_node.global_position, melee_arc_followup_radius):
			if nearby == enemy_node:
				continue
			if nearby.has_method("take_damage"):
				_call_take_damage(nearby, splash_damage, {"damage_type": hit_type})
	# SCRUM-603: мили лечение-при-ударе тоже через per-second бюджет (capped).
	if melee_heal_percent_on_hit > 0.0 and owner_node.has_method("heal_percent_capped"):
		owner_node.heal_percent_capped(melee_heal_percent_on_hit)
	elif melee_heal_percent_on_hit > 0.0 and owner_node.has_method("heal_percent"):
		owner_node.heal_percent(melee_heal_percent_on_hit)


func _damage_enemy_with_dot(enemy: Node, direct_damage: float, owner_node: Node2D) -> void:
	_damage_enemy(enemy, direct_damage)
	var parameters_raw = owner_node.get("derived_parameters")
	var parameters: Dictionary = parameters_raw if parameters_raw is Dictionary else {}
	var tick_damage := float(parameters.get("dot_damage", max(1.0, direct_damage * 0.22)))
	var tick_speed: float = max(float(parameters.get("dot_speed", 1.0)), 0.2)
	if dot_ticks <= 0:
		return
	# SCRUM-961: классовые артефакты продлевают DoT-идентичность конкретных линий
	# («Ядовитая катушка» — Ядовитая струна, «Симбиотическая оболочка» — сеть).
	var extra_ticks := 0
	if attack_mode == "dot_beam":
		extra_ticks = int(_owner_mod("venom_dot_extra_ticks"))
	elif attack_mode == "bio_symbiote_web":
		extra_ticks = int(_owner_mod("symbiote_dot_extra_ticks"))
	# Tween на оружии замораживается паузой, в отличие от SceneTreeTimer.
	var dot_color := Color(visual_color.r, visual_color.g, visual_color.b, 1.0)
	var dot_tween := create_tween()
	for tick_index in range(dot_ticks + extra_ticks):
		dot_tween.tween_interval(1.0 / tick_speed)
		# SCRUM-551: bound-метод вместо лямбды с захватом локала `enemy` (Node). Захват
		# узла в lambda-callable интермиттентно «освобождался» под быстрым create/free
		# оружия и врагов в balance-CSV (ERROR: Lambda capture at index 1 was freed,
		# gdscript_lambda_callable.cpp:110) и валил прогон. Callable.bind держит self
		# (живёт пока жив tween) + value-args; гвард is_instance_valid внутри метода.
		dot_tween.tween_callback(Callable(self, "_apply_weapon_dot_tick").bind(enemy, tick_damage, dot_color))


func _apply_weapon_dot_tick(enemy: Node, tick_damage: float, dot_color: Color) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	_damage_enemy(enemy, tick_damage, false, "dot", false)
	if enemy is Node2D:
		HazardVfx.dot_tick(enemy, dot_color)


func _damage_enemies_in_circle(origin: Vector2, radius: float, amount: float) -> void:
	for enemy_node in TARGET_QUERY.in_radius(self, origin, radius):
		_damage_enemy(enemy_node, amount)


func _damage_aoe_projectile_explosion(origin: Vector2, radius: float, amount: float) -> void:
	# SCRUM-961 «Летучая пыль»: без облака взрыв прямой (+25%, каппинг обычного AoE).
	if _volatile_powder_active():
		_damage_enemies_in_circle_capped(origin, radius, amount * 1.25, AOE_PROJECTILE_FULL_TARGETS, AOE_PROJECTILE_TARGET_DIMINISH)
		return
	if leaves_pool:
		_damage_enemies_in_circle_capped(origin, radius, amount * POOL_PROJECTILE_DAMAGE_MULTIPLIER * pool_direct_damage_multiplier, POOL_PROJECTILE_FULL_TARGETS, POOL_PROJECTILE_TARGET_DIMINISH)
		return
	_damage_enemies_in_circle_capped(origin, radius, amount, AOE_PROJECTILE_FULL_TARGETS, AOE_PROJECTILE_TARGET_DIMINISH)


# SCRUM-961 «Летучая пыль»: blast_powder переведён в режим быстрого AoE без облака.
func _volatile_powder_active() -> bool:
	return weapon_id == "blast_powder" and _owner_mod("volatile_powder_mode") > 0.0


# SCRUM-533: тик ЛУЖИ (DoT-облако) с диминишингом по числу целей. Раньше каждый
# тик лужи лил ПОЛНЫЙ tick_damage всем врагам в круге без потолка, поэтому на
# плотном паке из 20 целей throughput рос линейно (chemist/acid_flask lvl20_ideal
# 20t ≈ 112k — кратно выше budget'а). Формула же бюджетит лужу как pool_targets ≤ 4
# (estimate_weapon_budget → _budget_hit_model, mode aoe_projectile), так что живой
# замер выбивался из формульного коридора. Здесь живой урон лужи приводится к тому
# же бюджету: центральная цель получает полный урон, каждая следующая (по удалённости
# от центра) — резко убывающий 1/(1+(rank-knee)*decay). Облако остаётся area-denial
# оружием, но плотная толпа больше не умножает один тик почти на весь экран.
const POOL_FULL_TARGETS := 1
const POOL_TARGET_DIMINISH := 1.5
const MAX_ACTIVE_DAMAGE_POOLS := 6
const AOE_PROJECTILE_FULL_TARGETS := 5
const AOE_PROJECTILE_TARGET_DIMINISH := 2.0
const POOL_PROJECTILE_FULL_TARGETS := 1
const POOL_PROJECTILE_TARGET_DIMINISH := 3.0
const POOL_TICK_DAMAGE_MULTIPLIER := 0.55
const POOL_PROJECTILE_DAMAGE_MULTIPLIER := 0.55


func _retire_excess_damage_pools(new_pool: Node2D) -> void:
	var active_pools: Array[Node2D] = []
	for cloud_node in get_tree().get_nodes_in_group("chemist_clouds"):
		if not (cloud_node is Node2D):
			continue
		if int(cloud_node.get_meta("pool_weapon_owner", 0)) != get_instance_id():
			continue
		active_pools.append(cloud_node as Node2D)
	active_pools.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		if a == new_pool:
			return false
		if b == new_pool:
			return true
		return int(a.get_instance_id()) < int(b.get_instance_id())
	)
	while active_pools.size() > MAX_ACTIVE_DAMAGE_POOLS:
		var stale_pool := active_pools.pop_front() as Node2D
		if stale_pool == new_pool:
			active_pools.append(stale_pool)
			continue
		stale_pool.remove_from_group("chemist_clouds")
		_release_effect(stale_pool)
		stale_pool.queue_free()

func _damage_enemies_in_pool(origin: Vector2, radius: float, amount: float) -> void:
	var enemies: Array = TARGET_QUERY.in_radius(self, origin, radius)
	_apply_pool_contact_statuses(enemies)
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
		_damage_enemy(enemies[index] as Node2D, amount * factor, false, "dot", false)


# SCRUM-961: контактные статусы луж («Кислотный катализатор» — перманентные стаки
# едкого DoT до смерти носителя, кап 5; «Печать терновника» — стабильный слоу).
func _apply_pool_contact_statuses(enemies: Array) -> void:
	var acid_charges := weapon_id == "acid_flask" and _owner_mod("acid_charge_stacks") > 0.0
	var briar_slow := weapon_id == "briar_staff" and _owner_mod("briar_slow_power") > 0.0
	if not acid_charges and not briar_slow:
		return
	for enemy in enemies:
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		if acid_charges:
			StatusEffects.apply_status(enemy_node, "acid_charge", {
				"duration": 999.0,
				"dot_damage": 0.8,
				"dot_interval": 1.0,
				"stack_mode": "add",
				"max_stacks": 5,
				"marker_color": Color(0.62, 0.95, 0.25, 1.0),
			})
		if briar_slow:
			StatusEffects.apply_status(enemy_node, "briar_seal_slow", {
				"duration": 1.2,
				"speed_multiplier": maxf(1.0 - _owner_mod("briar_slow_power"), 0.25),
				"marker_color": Color(0.35, 0.70, 0.25, 1.0),
			})


func _damage_enemies_in_circle_capped(origin: Vector2, radius: float, amount: float, full_targets: int, diminish: float) -> void:
	var enemies: Array = TARGET_QUERY.in_radius(self, origin, radius)
	if enemies.size() <= full_targets:
		for enemy_node in enemies:
			_damage_enemy(enemy_node, amount)
		return
	enemies.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)
	)
	for index in range(enemies.size()):
		var factor := 1.0
		if index >= full_targets:
			factor = 1.0 / (1.0 + float(index - full_targets + 1) * diminish)
		_damage_enemy(enemies[index] as Node2D, amount * factor, index < full_targets)


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
	for enemy_node in TARGET_QUERY.in_segment(self, start, finish, width, _line_back_allowance(start)):
		_damage_enemy(enemy_node, amount)


func _damage_split_shard_corridor(origin: Vector2, direction: Vector2, width: float, range_limit: float, amount: float, excluded_ids: Dictionary, hit_limit: int) -> int:
	var hit_count := 0
	for hit in _enemies_in_corridor(origin, direction, width, range_limit):
		if hit_count >= hit_limit:
			break
		var enemy_node := hit["node"] as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var enemy_id := enemy_node.get_instance_id()
		if excluded_ids.has(enemy_id):
			continue
		excluded_ids[enemy_id] = true
		_damage_enemy(enemy_node, amount * pow(0.72, float(hit_count)))
		hit_count += 1
	return hit_count


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
			if args.size() < 2:
				return false
			var script: Script = enemy.get_script()
			if script != null and str(script.resource_path) in ["res://scripts/enemy.gd", "res://scripts/boss.gd"]:
				return true
			return enemy.is_in_group("enemies") and enemy.has_method("_show_combat_feedback")
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
	# SCRUM-961 «Счетчик ритма»: ослабленный повтор каста (эхо активно только
	# внутри _maybe_fire_rhythm_echo, обычные касты не задевает).
	result *= _rhythm_echo_scale
	return result


func _summon_role_damage_factor(parameters: Dictionary) -> float:
	# SCRUM-546: deploy/sentry-саммоны (turret/totem/drone) масштабируются от
	# Лидерства так же, как pure-саммоны (summoner_weapon._summon_profile) и
	# бюджетная модель (progression_data._budget_summon_role_damage_factor).
	var summon_amount := float(parameters.get("summon_amount", 0.0))
	var leadership := float(parameters.get("leadership", 0.0))
	return summon_role_damage_multiplier * (1.0 + minf(leadership * 0.060 + summon_amount * 0.016, 1.15))


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
