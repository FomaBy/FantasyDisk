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
# SCRUM-894: число сегментов полилинии дуги возврата чакрамов (урон + полёт орба).
const BOOMERANG_ARC_SAMPLES := 12

const DEFAULT_ATTACK_MODE := "sound_wave"
const PRIMARY_CAST_ACTION_MODES := {
	"aoe_projectile": true,
	"homing_curse": true,
	"beam": true,
	"drain_link": true,
	# SCRUM-939..941: новый кит Тёмного мага кастует, как и прежние формы.
	"dark_chain_burst": true,
	"skull_curse_burn": true,
	"dark_mirror_blast": true,
	"plague_dart": true,  # SCRUM-900: бросок чумного дротика — каст-жест
}
const EVENT_CAST_ACTION_MODES := {
	"aoe_projectile": true,
	"homing_curse": true,
	"beam": true,
	"dot_beam": true,
	"drain_link": true,
	"plague_dart": true,  # SCRUM-900
	"priest_prayer_chain": true,
	"bio_symbiote_web": true,
	"engineer_repair_drone": true,
	"dark_chain_burst": true,
	"skull_curse_burn": true,
	"dark_mirror_blast": true,
}
const ATTACK_MODE_EXECUTORS := {
	"aoe_projectile": "_exec_aoe_projectile",
	"boomerang": "_exec_boomerang",
	"stab_flurry": "_exec_stab_flurry",
	"dot_beam": "_exec_dot_beam",
	"homing_curse": "_exec_homing_curse",
	"dark_chain_burst": "_exec_dark_chain_burst",
	"skull_curse_burn": "_exec_skull_curse_burn",
	"dark_mirror_blast": "_exec_dark_mirror_blast",
	"beam": "_exec_beam",
	"drain_link": "_exec_drain_link",
	"sound_wave": "_exec_sound_wave",
	"pulse": "_exec_pulse",
	"amp": "_exec_amp",
	"trap": "_exec_trap",
	"arquebus_shot": "_exec_arquebus_shot",
	"grenade_fuse": "_exec_grenade_fuse",
	"bayonet_cone": "_exec_bayonet_cone",
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
	"plague_dart": "_exec_plague_dart",  # SCRUM-900 doctor/plague_syringe
	"saw_sector": "_exec_saw_sector",  # SCRUM-900 doctor/bone_saw
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
# SCRUM-938 «Штык-конус»: сектор ближнего укола + редкий авто-выстрел винтовки.
@export var cone_degrees := 100.0
@export var bayonet_auto_shot_chance := 0.0
@export var bayonet_shot_range := 560.0
@export var bayonet_shot_damage_multiplier := 0.7
@export var damage_falloff := 0.55
@export var pierce_damage_falloff := 1.0
# SCRUM-897 «Кошель Рикошета»: steal_hits — сколько ПЕРВЫХ целей цепи обворовываются
# детерминированно (золото начисляется мгновенно, без пикапа).
@export var steal_money := 0
@export var steal_hits := 0
@export var dodge_bonus := 0.0
@export var smoke_duration := 1.8
# SCRUM-897 «Отравленный Кинжал»: встроенное окно паралича-яда (сек); артефакт
# «Парализующее лезвие» (backstab_root_duration) добавляется поверх, суммарно
# не выше POISON_PARALYSIS_CAP.
@export var poison_paralysis_duration := 0.0
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
# SCRUM-944: per-weapon скалер тика лужи (зеркалится в _budget_pool_dps).
@export var pool_tick_damage_multiplier := 1.0
# SCRUM-944: полупрозрачная наземная лужа (visual-polish кислотной колбы).
@export var pool_translucent := false
# SCRUM-944: перманентные контактные заряды лужи — один вечный DoT-заряд с КАЖДОЙ
# отдельной лужи (кап pool_charge_cap на цель; артефакт acid_charge_stacks: +3).
@export var pool_contact_charges := false
@export var pool_charge_tick_multiplier := 0.30
@export var pool_charge_tick_interval := 0.9
@export var pool_charge_cap := 5
@export var charge_seconds := 0.0
@export var charge_max_multiplier := 1.0
@export var crit_shadow_burst_radius := 0.0
# SCRUM-894 (кит Ассасина): дуга возврата чакрамов / point-blank покрытие серии
# кинжалов / близкий контакт и крит-снапшот яда струны. 0 = поведение без фичи.
@export var return_arc_offset := 0.0
@export var point_blank_radius := 0.0
@export var close_contact_radius := 0.0
@export var dot_crit_snapshot_ratio := 0.0
@export var melee_close_bonus_radius := 0.0
@export var melee_close_damage_multiplier := 1.0
@export var melee_execute_threshold := 0.0
@export var melee_execute_multiplier := 1.0
@export var melee_stagger_knockback_multiplier := 0.0
@export var melee_arc_followup_radius := 0.0
@export var melee_arc_followup_multiplier := 0.0
@export var melee_heal_percent_on_hit := 0.0
# SCRUM-900 doctor/bone_saw (saw_sector): диминиш урона по целям сверх
# sector_full_targets — сектор чистит толпу, но не масштабируется линейно.
@export var sector_full_targets := 4
@export var sector_target_diminish := 0.72
# SCRUM-900 doctor/plague_syringe (plague_dart): параметры чумы. Профиль тика —
# ProgressionData.plague_tick_profile (единый источник для боя и budget-модели).
@export var plague_duration := 24.0
@export var plague_tick_interval := 2.0
@export var plague_tick_ratio := 0.22
@export var plague_dot_coupling := 0.6
@export var plague_ramp_ticks := 5
@export var plague_spread_chance := 0.22
@export var plague_spread_radius := 200.0
@export var plague_max_infected := 10
@export var summon_role := ""
@export var summon_role_damage_multiplier := 1.0
@export var summon_support_heal_percent := 0.0
@export var summon_control_knockback := 0.0
@export var sentry_splash_radius := 0.0
@export var sentry_splash_damage_multiplier := 0.0
@export var sentry_splash_target_cap := 0
@export var deploy_texture_path := ""
# SCRUM-939..941: параметры кита Тёмного мага (цепь / curse-прожиг / зеркало).
@export var chain_targets := 3
@export var chain_hop_range := 300.0
@export var chain_burst_ratio := 0.45
@export var mirror_damage_ratio := 1.0
@export var curse_only := false
@export var curse_tick_rate := 7.0
@export var curse_tick_multiplier := 1.0
@export var curse_int_scale := 0.0
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
# SCRUM-900 plague_dart: реестр живых зараз этого оружия (enemy_id → Tween).
# Дедуп повторного заражения (рефреш), spread-исключение и кап plague_max_infected.
var _plague_tweens := {}


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
	# SCRUM-900: гасим живые заразы чумы (tween'ы) вместе с эффектами.
	for enemy_id in _plague_tweens.keys():
		var plague_tween: Tween = _plague_tweens[enemy_id]
		if plague_tween != null and plague_tween.is_valid():
			plague_tween.kill()
	_plague_tweens.clear()
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
	cone_degrees = float(config.get("cone_degrees", cone_degrees))
	bayonet_auto_shot_chance = float(config.get("bayonet_auto_shot_chance", bayonet_auto_shot_chance))
	bayonet_shot_range = float(config.get("bayonet_shot_range", bayonet_shot_range))
	bayonet_shot_damage_multiplier = float(config.get("bayonet_shot_damage_multiplier", bayonet_shot_damage_multiplier))
	damage_falloff = float(config.get("damage_falloff", damage_falloff))
	pierce_damage_falloff = float(config.get("pierce_damage_falloff", pierce_damage_falloff))
	steal_money = int(config.get("steal_money", steal_money))
	steal_hits = int(config.get("steal_hits", steal_hits))
	dodge_bonus = float(config.get("dodge_bonus", dodge_bonus))
	smoke_duration = float(config.get("smoke_duration", smoke_duration))
	poison_paralysis_duration = float(config.get("poison_paralysis_duration", poison_paralysis_duration))
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
	pool_tick_damage_multiplier = float(config.get("pool_tick_damage_multiplier", pool_tick_damage_multiplier))
	pool_translucent = bool(config.get("pool_translucent", pool_translucent))
	pool_contact_charges = bool(config.get("pool_contact_charges", pool_contact_charges))
	pool_charge_tick_multiplier = float(config.get("pool_charge_tick_multiplier", pool_charge_tick_multiplier))
	pool_charge_tick_interval = float(config.get("pool_charge_tick_interval", pool_charge_tick_interval))
	pool_charge_cap = int(config.get("pool_charge_cap", pool_charge_cap))
	charge_seconds = float(config.get("charge_seconds", charge_seconds))
	charge_max_multiplier = float(config.get("charge_max_multiplier", charge_max_multiplier))
	crit_shadow_burst_radius = float(config.get("crit_shadow_burst_radius", config.get("dash_on_crit_distance", crit_shadow_burst_radius)))
	return_arc_offset = float(config.get("return_arc_offset", return_arc_offset))
	point_blank_radius = float(config.get("point_blank_radius", point_blank_radius))
	close_contact_radius = float(config.get("close_contact_radius", close_contact_radius))
	dot_crit_snapshot_ratio = float(config.get("dot_crit_snapshot_ratio", dot_crit_snapshot_ratio))
	melee_close_bonus_radius = float(config.get("melee_close_bonus_radius", melee_close_bonus_radius))
	melee_close_damage_multiplier = float(config.get("melee_close_damage_multiplier", melee_close_damage_multiplier))
	melee_execute_threshold = float(config.get("melee_execute_threshold", melee_execute_threshold))
	melee_execute_multiplier = float(config.get("melee_execute_multiplier", melee_execute_multiplier))
	melee_stagger_knockback_multiplier = float(config.get("melee_stagger_knockback_multiplier", melee_stagger_knockback_multiplier))
	melee_arc_followup_radius = float(config.get("melee_arc_followup_radius", melee_arc_followup_radius))
	melee_arc_followup_multiplier = float(config.get("melee_arc_followup_multiplier", melee_arc_followup_multiplier))
	melee_heal_percent_on_hit = float(config.get("melee_heal_percent_on_hit", melee_heal_percent_on_hit))
	# SCRUM-900: докторский кит — сектор пилы и профиль чумы.
	sector_full_targets = int(config.get("sector_full_targets", sector_full_targets))
	sector_target_diminish = float(config.get("sector_target_diminish", sector_target_diminish))
	plague_duration = float(config.get("plague_duration", plague_duration))
	plague_tick_interval = float(config.get("plague_tick_interval", plague_tick_interval))
	plague_tick_ratio = float(config.get("plague_tick_ratio", plague_tick_ratio))
	plague_dot_coupling = float(config.get("plague_dot_coupling", plague_dot_coupling))
	plague_ramp_ticks = int(config.get("plague_ramp_ticks", plague_ramp_ticks))
	plague_spread_chance = float(config.get("plague_spread_chance", plague_spread_chance))
	plague_spread_radius = float(config.get("plague_spread_radius", plague_spread_radius))
	plague_max_infected = int(config.get("plague_max_infected", plague_max_infected))
	summon_role = str(config.get("summon_role", summon_role))
	summon_role_damage_multiplier = float(config.get("summon_role_damage_multiplier", summon_role_damage_multiplier))
	summon_support_heal_percent = float(config.get("summon_support_heal_percent", summon_support_heal_percent))
	summon_control_knockback = float(config.get("summon_control_knockback", summon_control_knockback))
	sentry_splash_radius = float(config.get("sentry_splash_radius", sentry_splash_radius))
	sentry_splash_damage_multiplier = float(config.get("sentry_splash_damage_multiplier", sentry_splash_damage_multiplier))
	sentry_splash_target_cap = int(config.get("sentry_splash_target_cap", sentry_splash_target_cap))
	deploy_texture_path = str(config.get("deploy_texture_path", deploy_texture_path))
	chain_targets = int(config.get("chain_targets", chain_targets))
	chain_hop_range = float(config.get("chain_hop_range", chain_hop_range))
	chain_burst_ratio = float(config.get("chain_burst_ratio", chain_burst_ratio))
	mirror_damage_ratio = float(config.get("mirror_damage_ratio", mirror_damage_ratio))
	curse_only = bool(config.get("curse_only", curse_only))
	curse_tick_rate = float(config.get("curse_tick_rate", curse_tick_rate))
	curse_tick_multiplier = float(config.get("curse_tick_multiplier", curse_tick_multiplier))
	curse_int_scale = float(config.get("curse_int_scale", curse_int_scale))
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
	_maybe_fire_action_echo(owner_node, target, direction)


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


# SCRUM-935 «Двойное действие» (class trait Солдата, data-driven): каждое действие
# оружия с шансом action_echo_chance (CLASS_TRAITS через Player.class_trait_value)
# создаёт ОДНУ полную копию себя с коротким читаемым сдвигом — второй выстрел /
# вторая граната / второй укол. Копия выполняется под флагом _action_echo_active и
# НЕ роллит новую копию: рекурсия невозможна и структурно (эхо не зовёт _attack()),
# и по гарду. Деплой-режимы исключены (эхо не ставит второй усилитель/капкан/мину).
# Эхо повторяет только само действие: кулдаун, heal-on-attack, заряд и ролл
# rhythm-эха НЕ переприменяются (без двойных классовых сайд-эффектов).
const ACTION_ECHO_EXCLUDED_MODES := {
	"amp": true, "trap": true,
	"engineer_sentry_link": true, "engineer_repair_drone": true, "engineer_pressure_mines": true,
}
const ACTION_ECHO_DEFAULT_DELAY := 0.18

var _action_echo_active := false


func _maybe_fire_action_echo(owner_node: Node2D, target: Node2D, direction: Vector2) -> bool:
	if _action_echo_active or _effects_shutdown:
		return false
	if ACTION_ECHO_EXCLUDED_MODES.has(attack_mode):
		return false
	if owner_node == null or not is_instance_valid(owner_node) or not owner_node.has_method("class_trait_value"):
		return false
	var echo_chance := clampf(float(owner_node.call("class_trait_value", "action_echo_chance", 0.0)), 0.0, 1.0)
	if echo_chance <= 0.0 or randf() >= echo_chance:
		return false
	var echo_delay := maxf(float(owner_node.call("class_trait_value", "action_echo_delay", ACTION_ECHO_DEFAULT_DELAY)), 0.01)
	var target_id := 0
	if target != null and is_instance_valid(target):
		target_id = target.get_instance_id()
	var echo_tween := create_tween()
	echo_tween.tween_interval(echo_delay)
	# SCRUM-551: без лямбды с захватом узлов — Callable + примитивные bind-аргументы.
	echo_tween.tween_callback(Callable(self, "_fire_action_echo").bind(owner_node.get_instance_id(), target_id, direction))
	return true


func _fire_action_echo(owner_id: int, target_id: int, direction: Vector2) -> void:
	if _effects_shutdown:
		return
	var current_owner := instance_from_id(owner_id) as Node2D
	if current_owner == null or not is_instance_valid(current_owner):
		return
	var current_target: Node2D = null
	if target_id != 0:
		var target_candidate := instance_from_id(target_id) as Node2D
		if target_candidate != null and is_instance_valid(target_candidate):
			current_target = target_candidate
	_action_echo_active = true
	_emit_weapon_animation_event(current_owner, "pulse", 0.0, direction, {"action_echo": true})
	_execute_attack_mode(current_owner, current_target, direction)
	_action_echo_active = false


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
		"grenade_fuse", "smoke_bomb", "prism_rift", "meteor_shards", "sniper_kill_zone", "priest_sanctify", "bio_spore_bloom", "robot_magnetic_anchor":
			center = owner_node.global_position + direction * minf(attack_range, 360.0)
			if target != null:
				center = target.global_position
		"beam", "dot_beam", "arquebus_shot", "sniper_lockshot", "sniper_split_round", "bayonet_cone", "robot_compression_line":
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


func _exec_dark_chain_burst(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_dark_chain_burst(owner_node, target, direction)


func _exec_skull_curse_burn(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_skull_curse_burn(owner_node, target, direction)


func _exec_dark_mirror_blast(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_dark_mirror_blast(owner_node, target, direction)


func _exec_beam(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_beam(owner_node, direction)


func _exec_plague_dart(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_plague_dart(owner_node, target, direction)


func _exec_saw_sector(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_saw_sector(owner_node, direction)


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


func _exec_arquebus_shot(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_arquebus_shot(owner_node, target, direction)


func _exec_grenade_fuse(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_grenade_fuse(owner_node, target, direction)


func _exec_bayonet_cone(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_bayonet_cone(owner_node, direction)


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
	# SCRUM-894: при return_arc_offset > 0 возврат идёт НЕ тем же коридором, а
	# видимой квадратичной дугой через ЛЕВУЮ сторону от направления броска
	# (от точки разворота к герою). Гейт per-cast/per-target: outbound — один
	# проход-скан, возврат — один дедуп-скан дуги ⇒ максимум 1+1 хита на цель
	# за каст, бесконечных повторных хитов нет.
	var origin := owner_node.global_position
	_damage_enemies_in_corridor(origin, direction, _rolled_damage(owner_node))
	var orb := AttackVfx.orb_projectile(_projectile_parent(), origin + direction * 24.0, visual_color)
	_register_effect(orb)
	var far_point := origin + direction * attack_range
	var orb_tween := create_tween()
	orb_tween.tween_property(orb, "global_position", far_point, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# SCRUM-551: захват owner_node/orb (Node) в lambda интермиттентно «освобождался»
	# под быстрым create/free в balance-CSV. Резолвим по instance_id внутри + гвард.
	var owner_id := owner_node.get_instance_id()
	var orb_id := orb.get_instance_id()
	var weapon_self_id := get_instance_id()
	if return_arc_offset > 0.0:
		orb_tween.tween_callback(Callable(self, "_begin_boomerang_return_arc").bind(owner_id, orb_id, far_point, direction))
		return
	orb_tween.tween_property(orb, "global_position", origin, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
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


# SCRUM-894: разворот чакрамов — считаем дугу от точки разворота к текущей позиции
# героя, наносим return-урон вдоль дуги и ведём орб по той же кривой. Bound-метод
# вместо лямбды с захватом узлов (канон SCRUM-551), резолв по instance_id + гварды.
func _begin_boomerang_return_arc(owner_id: int, orb_id: int, far_point: Vector2, direction: Vector2) -> void:
	var owner_node := instance_from_id(owner_id) as Node2D
	var orb := instance_from_id(orb_id) as Node2D
	if owner_node == null or not is_instance_valid(owner_node) or not is_inside_tree():
		if orb != null and is_instance_valid(orb):
			_release_effect(orb)
		return
	var home := owner_node.global_position
	var control := _boomerang_return_control_point(far_point, home, direction)
	_damage_boomerang_return_arc(far_point, control, home, _rolled_damage(owner_node))
	if orb == null or not is_instance_valid(orb):
		return
	var arc_tween := create_tween()
	arc_tween.tween_method(Callable(self, "_step_orb_along_return_arc").bind(orb_id, far_point, control, home), 0.0, 1.0, 0.25)
	arc_tween.tween_callback(Callable(self, "_release_effect_by_id").bind(orb_id))


# Контрольная точка возврата: середина хорды + смещение в ЛЕВУЮ сторону
# относительно направления броска (в экранных координатах Godot y вниз,
# левая нормаль = (dir.y, -dir.x)).
func _boomerang_return_control_point(from_point: Vector2, home: Vector2, direction: Vector2) -> Vector2:
	var left_normal := Vector2(direction.y, -direction.x)
	return (from_point + home) * 0.5 + left_normal * return_arc_offset


func _quadratic_bezier_point(from_point: Vector2, control: Vector2, to_point: Vector2, t: float) -> Vector2:
	var inv := 1.0 - t
	return from_point * (inv * inv) + control * (2.0 * inv * t) + to_point * (t * t)


# Возврат-урон вдоль дуги: сэмплируем кривую полилинией и бьём каждого врага
# коридора НЕ БОЛЕЕ ОДНОГО РАЗА (дедуп по instance_id — per-cast/per-target гейт).
# Артефактные ключи SCRUM-961 (ширина/урон возврата) продолжают действовать.
func _damage_boomerang_return_arc(from_point: Vector2, control: Vector2, home: Vector2, amount: float) -> void:
	var return_width := beam_width * (1.0 + _owner_mod("boomerang_return_width_mult"))
	var return_damage := amount * (1.0 + _owner_mod("boomerang_return_damage_mult"))
	var hit_ids := {}
	var previous := from_point
	for step in range(1, BOOMERANG_ARC_SAMPLES + 1):
		var point := _quadratic_bezier_point(from_point, control, home, float(step) / float(BOOMERANG_ARC_SAMPLES))
		for enemy_raw in TARGET_QUERY.in_segment(self, previous, point, return_width):
			var enemy_node := enemy_raw as Node2D
			if enemy_node == null or not is_instance_valid(enemy_node):
				continue
			var enemy_id := enemy_node.get_instance_id()
			if hit_ids.has(enemy_id):
				continue
			hit_ids[enemy_id] = true
			_damage_enemy(enemy_node, return_damage)
		previous = point


func _step_orb_along_return_arc(progress: float, orb_id: int, from_point: Vector2, control: Vector2, home: Vector2) -> void:
	var orb := instance_from_id(orb_id) as Node2D
	if orb == null or not is_instance_valid(orb):
		return
	orb.global_position = _quadratic_bezier_point(from_point, control, home, clampf(progress, 0.0, 1.0))


func _fire_stab_flurry(owner_node: Node2D, direction: Vector2) -> void:
	# Быстрый ближний веер: несколько целей в короткой зоне перед персонажем.
	# SCRUM-894: при point_blank_radius > 0 (Теневые кинжалы) серия дополнительно
	# покрывает врагов вплотную ВОКРУГ героя (под ногами/за спиной) — мёртвой зоны
	# в упор нет. Лимит целей общий (projectile_count) — бесплатных хитов нет.
	var slash := AttackVfx.slash(owner_node, direction, attack_range, visual_color)
	_register_effect(slash)
	if point_blank_radius > 0.0:
		AttackVfx.ring_pulse(_projectile_parent(), owner_node.global_position, point_blank_radius, Color(visual_color.r, visual_color.g, visual_color.b, 0.20), false)
	var candidates := []
	for enemy_node in TARGET_QUERY.enemies(self):
		if not is_instance_valid(enemy_node):
			continue
		var distance_squared := owner_node.global_position.distance_squared_to(enemy_node.global_position)
		var inside_point_blank := point_blank_radius > 0.0 and distance_squared <= point_blank_radius * point_blank_radius
		if not inside_point_blank and not _is_enemy_inside_wave(owner_node.global_position, enemy_node.global_position, direction):
			continue
		candidates.append({
			"node": enemy_node,
			"distance": distance_squared,
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
	# SCRUM-894 «Рывок темпа»: серия, задевшая врага, даёт короткий бафф
	# скорости+уворота. Величины/кулдаун — data-driven из weapon_config владельца
	# (Player.trigger_flurry_tempo — no-op у оружий без flurry_tempo_* ключей).
	if hit_count > 0 and owner_node.has_method("trigger_flurry_tempo"):
		owner_node.call("trigger_flurry_tempo")


func _damage_enemies_in_corridor(origin: Vector2, direction: Vector2, amount: float) -> void:
	for hit in _enemies_in_corridor(origin, direction, beam_width, attack_range):
		_damage_enemy(hit["node"], amount)


func _spawn_damage_pool(pool_position: Vector2, tick_damage: float) -> void:
	# Ядовитое облако химика: тики по врагам в радиусе, группа player_weapon_effects.
	# SCRUM-944: pool_tick_damage_multiplier — per-weapon скалер (зеркален в бюджете).
	tick_damage *= POOL_TICK_DAMAGE_MULTIPLIER * pool_tick_damage_multiplier
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
	# SCRUM-944 (визуальный контракт кита): pool_translucent-лужи (кислота) всегда
	# полупрозрачны — поле боя/UI читаются сквозь зону; SCRUM-961 «Прозрачная
	# кислота» дополнительно подчёркивает опасность яркой danger-кромкой при спавне.
	var clear_pool := weapon_id == "acid_flask" and _owner_mod("pool_duration_mult") > 0.0
	var pool_alpha := 0.82
	if pool_translucent:
		pool_alpha = 0.50
	elif clear_pool:
		pool_alpha = 0.58
	pool_sprite.modulate = Color(1.0, 1.0, 1.0, pool_alpha)
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
				# SCRUM-944: лужа передаёт себя тику — контактные заряды с per-pool
				# идентичностью («одна лужа = один вечный заряд», без повторов).
				current_weapon.call("_damage_enemies_in_pool", current_pool.global_position, aoe_radius * 0.7, tick_damage, current_pool)
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
			# SCRUM-941: старый хук «Зеркальной страницы» удалён — dark_book ушёл
			# с aoe_projectile на dark_mirror_blast (зеркало теперь база оружия,
			# артефакт репозиционирован в book_mirror_echo).
			# SCRUM-961 «Восстановительный пар» (SCRUM-900: хук на взрыве зелья —
			# restore_potion теперь aoe_projectile, а не drain_link).
			if current_owner != null and str(current_weapon.get("weapon_id")) == "restore_potion" and float(current_weapon.call("_owner_mod", "restore_vapor_power")) > 0.0:
				current_weapon.call("_spawn_restore_vapor", current_owner, target_position, explosion_damage)
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


# ============================================================================
# SCRUM-939..941: кит Тёмного мага (цепь палочки / curse-прожиг черепа /
# зеркальные взрывы книги). Все лямбды в tween_callback заменены на
# Callable(self, "...").bind(...) (канон SCRUM-551 против freed-lambda).
# ============================================================================


# SCRUM-939: Тёмная палочка — видимый цепной/рикошет-снаряд.
# Правила таргетинга (детерминированы, покрыты dark_mage_kit_test):
#   1) первая цель = переданный target (ближайший враг), иначе ближайший на арене;
#   2) каждый рикошет летит в БЛИЖАЙШЕГО ещё не поражённого врага в chain_hop_range
#      от точки текущего попадания; всего до chain_targets (+артефакт/extra) целей;
#   3) повторных попаданий по одной цели в рамках одного каста НЕТ. FALLBACK
#      (задокументирован): если валидных целей не осталось — цепь обрывается
#      раньше, снаряд НЕ возвращается в уже поражённые цели.
# На каждом попадании — малый магический AoE-бурст по соседям жертвы (сама
# жертва бурстом не задевается — без double-dip). Бурст бьёт напрямую и не
# порождает новых рикошетов/бурстов (анти-каскад §8.4).
func _fire_dark_chain_burst(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var first_target := target
	if first_target == null:
		first_target = _find_closest_enemy(owner_node, INF)
	if first_target == null:
		# Пустая арена: видимый снаряд «в никуда», урона нет.
		var miss := AttackVfx.orb_projectile(_projectile_parent(), owner_node.global_position + direction * 24.0, visual_color)
		_register_effect(miss)
		var miss_tween := create_tween()
		miss_tween.tween_property(miss, "global_position", owner_node.global_position + direction * minf(attack_range, 300.0), 0.2)
		miss_tween.tween_callback(Callable(self, "_release_effect").bind(miss))
		return
	# Цепь выбирается детерминированно в момент каста.
	var chain: Array = [first_target]
	var used := {first_target.get_instance_id(): true}
	var hop_origin: Vector2 = first_target.global_position
	var chain_limit := maxi(chain_targets + _extra_projectiles() + int(_owner_mod("wand_extra_chain")), 1)
	for hop_index in range(chain_limit - 1):
		var next_target := _find_nearest_enemy_from(hop_origin, chain_hop_range, used)
		if next_target == null:
			break  # документированный fallback: цепь обрывается без повторов
		chain.append(next_target)
		used[next_target.get_instance_id()] = true
		hop_origin = next_target.global_position
	_launch_dark_chain_hop(owner_node.global_position + direction * 26.0, chain, 0, _rolled_damage(owner_node))


# Один видимый прыжок цепи: орб летит из точки предыдущего попадания в
# следующую цель; попадание резолвится по прилёту.
func _launch_dark_chain_hop(from_position: Vector2, chain: Array, hop_index: int, damage_value: float) -> void:
	if _effects_shutdown or hop_index >= chain.size():
		return
	var enemy_node := chain[hop_index] as Node2D
	if enemy_node == null or not is_instance_valid(enemy_node):
		# Цель умерла в полёте — цепь продолжает к следующей из той же точки.
		_launch_dark_chain_hop(from_position, chain, hop_index + 1, damage_value)
		return
	var orb := AttackVfx.orb_projectile(_projectile_parent(), from_position, visual_color)
	_register_effect(orb)
	var target_position := enemy_node.global_position
	var travel_time := clampf(from_position.distance_to(target_position) / maxf(projectile_speed, 1.0), 0.05, 0.30)
	var hop_tween := create_tween()
	hop_tween.tween_property(orb, "global_position", target_position, travel_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop_tween.tween_callback(Callable(self, "_resolve_dark_chain_hit").bind(orb, chain, hop_index, damage_value))


func _resolve_dark_chain_hit(orb: Node, chain: Array, hop_index: int, damage_value: float) -> void:
	var impact_position := Vector2.ZERO
	var impact_known := false
	if orb != null and is_instance_valid(orb):
		impact_position = (orb as Node2D).global_position
		impact_known = true
		_release_effect(orb)
	var falloff := clampf(pierce_damage_falloff, 0.1, 1.0)
	var enemy_node := chain[hop_index] as Node2D
	if enemy_node != null and is_instance_valid(enemy_node):
		impact_position = enemy_node.global_position
		impact_known = true
		var hit_damage := damage_value * pow(falloff, float(hop_index))
		_damage_enemy(enemy_node, hit_damage)
		_fire_dark_chain_hit_burst(enemy_node, impact_position, hit_damage * chain_burst_ratio * (1.0 + _owner_mod("wand_burst_bonus")))
	if not impact_known:
		return
	_launch_dark_chain_hop(impact_position, chain, hop_index + 1, damage_value)


# Малый бурст у точки попадания цепи: соседи жертвы получают долю урона хита.
# Прямой урон без он-хит проков (анти-каскад §8.4: бурст не рикошетит и не
# порождает новые бурсты); сама жертва исключена (уже получила прямой хит).
func _fire_dark_chain_hit_burst(victim: Node2D, center: Vector2, amount: float) -> void:
	if amount <= 0.0 or aoe_radius <= 0.0:
		return
	AttackVfx.orb_burst(_projectile_parent(), center, aoe_radius, visual_color)
	for enemy_node in TARGET_QUERY.in_radius(self, center, aoe_radius):
		if enemy_node == victim:
			continue
		if enemy_node.has_method("take_damage"):
			_call_take_damage(enemy_node, amount, {"damage_type": _weapon_damage_type()})


# SCRUM-940: Проклятый череп — ЧИСТОЕ проклятие, прямого урона нет.
# Череп летит в точку цели и накрывает область: каждый враг в aoe_radius
# получает статус skull_curse (dot_ticks тиков dot-оси). Повторное попадание
# ОБНОВЛЯЕТ прожиг (refresh, 1 стак) — стакование запрещено, бесконечного
# прожига нет. Скейл: dot_damage (сила тика) и dot_speed (темп, капится
# floor-ом интервала 0.1с ≈ 10 тик/с). Магические множители НЕ участвуют.
func _fire_skull_curse_burn(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var target_position: Vector2 = owner_node.global_position + direction * minf(attack_range, 300.0)
	if target != null:
		target_position = target.global_position
	elif _owner_uses_cursor_aim(owner_node) and owner_node.has_method("attack_aim_position"):
		target_position = owner_node.call("attack_aim_position", attack_range)
	var skull := AttackVfx.curse_skull(_projectile_parent(), owner_node.global_position + direction * 24.0, target_position, visual_color, 0.20, Callable(self, "_apply_skull_curse_zone").bind(target_position))
	_register_effect(skull)


func _apply_skull_curse_zone(center: Vector2) -> void:
	if _effects_shutdown:
		return
	var owner_node := _owner_node()
	if owner_node == null:
		return
	AttackVfx.ring_pulse(_projectile_parent(), center, aoe_radius, visual_color, false)
	var parameters_raw = owner_node.get("derived_parameters")
	var parameters: Dictionary = parameters_raw if parameters_raw is Dictionary else {}
	# Документированный curse-пайплайн (SCRUM-940): сила тика = dot_damage *
	# curse_tick_multiplier * (1 + Интеллект * curse_int_scale). Интеллект
	# «углубляет» проклятие (канон identity), Знание/флэты дают dot_damage;
	# магические множители не участвуют. Зеркало — _budget_dot_dps.
	var owner_stats_raw = owner_node.get("stats")
	var owner_stats: Dictionary = owner_stats_raw if owner_stats_raw is Dictionary else {}
	var curse_depth := 1.0 + maxf(float(owner_stats.get("intelligence", 0.0)), 0.0) * maxf(curse_int_scale, 0.0)
	var tick_damage := maxf(float(parameters.get("dot_damage", 1.0)), 1.0) * maxf(curse_tick_multiplier, 0.0) * curse_depth
	var tick_speed := maxf(float(parameters.get("dot_speed", 1.0)), 0.2) * maxf(curse_tick_rate, 0.2)
	# Floor 0.1с зеркалит кламп StatusEffects.tick: выше ~10 тик/с прожиг не
	# ускоряется, но суммарный урон каста сохраняется (число тиков фиксировано).
	var tick_interval := maxf(1.0 / tick_speed, 0.1)
	var ticks := maxi(dot_ticks, 1)
	# +0.99 тика запаса: StatusEffects.tick списывает remaining ДО проверки
	# тика, и k-й тик реально срабатывает на первом кадре ПОСЛЕ k*interval —
	# с меньшим буфером последний тик терялся. +0.99 (а не +1.0) не даёт
	# родиться лишнему (ticks+1)-му тику на границе.
	var duration := (float(ticks) + 0.99) * tick_interval
	var cursed_count := 0
	for enemy_node in TARGET_QUERY.in_radius(self, center, aoe_radius):
		StatusEffects.apply_status(enemy_node, "skull_curse", {
			"duration": duration,
			"dot_damage": tick_damage,
			"dot_interval": tick_interval,
			"max_stacks": 1,
			"stack_mode": "refresh",
			"marker_color": Color(0.78, 0.16, 1.0, 1.0),
			# SCRUM-1007: тики проклятия — урон игрока (атрибуция он-килл trait).
			"tick_feedback": {"damage_type": "dot", "player_owned": true, "curse": true},
		})
		if enemy_node is Node2D:
			HazardVfx.dot_tick(enemy_node, Color(visual_color.r, visual_color.g, visual_color.b, 1.0))
		cursed_count += 1
	# Прямого урона нет → on_weapon_hit не зовётся; заряд ульты кормим явно
	# ожидаемым прожигом каста (половинный вес, без он-хит проков/вампиризма).
	if cursed_count > 0 and owner_node.has_method("on_curse_applied"):
		owner_node.call("on_curse_applied", tick_damage * float(ticks) * float(cursed_count) * 0.5)


# SCRUM-941: Книга тьмы — зеркальные AoE-взрывы вокруг мага.
# Каждый каст порождает ДВА взрыва: первичный в точке цели P и зеркальный в
# M = 2*owner_pos - P (позиция мага НА МОМЕНТ КАСТА — детерминированная
# геометрия: горизонталь/вертикаль/диагональ зеркалятся одинаково). Оба взрыва
# следуют одним правилам урона/диминишинга (_damage_aoe_projectile_explosion);
# враг, накрытый обоими зонами, ЛЕГАЛЬНО получает оба удара (задокументировано,
# покрыто тестом). У границ арены зеркальная точка может выйти за поле — взрыв
# всё равно валиден и бьёт врагов в своём радиусе.
func _fire_dark_mirror_blast(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var primary_targets: Array = []
	if target != null:
		primary_targets = _find_closest_enemies(owner_node, maxi(1 + _extra_projectiles(), 1))
	if primary_targets.is_empty():
		var aim_position: Vector2 = owner_node.global_position + direction * minf(attack_range, 360.0)
		if _owner_uses_cursor_aim(owner_node) and owner_node.has_method("attack_aim_position"):
			aim_position = owner_node.call("attack_aim_position", attack_range)
		_launch_dark_mirror_pair(owner_node, aim_position)
		return
	for target_node in primary_targets:
		var enemy_node := target_node as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		_launch_dark_mirror_pair(owner_node, enemy_node.global_position)


func _launch_dark_mirror_pair(owner_node: Node2D, target_position: Vector2) -> void:
	var mirror_position: Vector2 = owner_node.global_position * 2.0 - target_position
	var damage_value := _rolled_damage(owner_node)
	var to_target := (target_position - owner_node.global_position).normalized()
	if to_target.length_squared() <= 0.001:
		to_target = Vector2.RIGHT
	_launch_dark_mirror_orb(owner_node.global_position + to_target * 28.0, target_position, damage_value)
	_launch_dark_mirror_orb(owner_node.global_position - to_target * 28.0, mirror_position, damage_value * maxf(mirror_damage_ratio, 0.0))


func _launch_dark_mirror_orb(start: Vector2, blast_position: Vector2, blast_damage: float) -> void:
	if blast_damage <= 0.0:
		return
	var orb := AttackVfx.orb_projectile(_projectile_parent(), start, visual_color)
	_register_effect(orb)
	var travel_time := clampf(start.distance_to(blast_position) / maxf(projectile_speed, 1.0), 0.08, 0.45)
	var orb_tween := create_tween()
	orb_tween.tween_property(orb, "global_position", blast_position, travel_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	orb_tween.tween_callback(Callable(self, "_resolve_dark_mirror_blast").bind(orb, blast_position, blast_damage))


func _resolve_dark_mirror_blast(orb: Node, blast_position: Vector2, blast_damage: float) -> void:
	if orb != null and is_instance_valid(orb):
		_release_effect(orb)
	if _effects_shutdown:
		return
	AttackVfx.orb_burst(_projectile_parent(), blast_position, aoe_radius, visual_color)
	_damage_aoe_projectile_explosion(blast_position, aoe_radius, blast_damage)
	# SCRUM-961 «Зеркальная страница» (репозиционирована под новый кит): взрыв
	# отдаётся эхом на долю урона; эхо НЕ зеркалится и НЕ эхоится повторно.
	var echo_ratio := _owner_mod("book_mirror_echo")
	if echo_ratio > 0.0:
		var echo_tween := create_tween()
		echo_tween.tween_interval(0.22)
		echo_tween.tween_callback(Callable(self, "_resolve_dark_mirror_echo").bind(blast_position, blast_damage * clampf(echo_ratio, 0.0, 1.0)))


func _resolve_dark_mirror_echo(blast_position: Vector2, echo_damage: float) -> void:
	if _effects_shutdown or echo_damage <= 0.0:
		return
	AttackVfx.orb_burst(_projectile_parent(), blast_position, aoe_radius * 0.8, Color(visual_color.r, visual_color.g, visual_color.b, visual_color.a * 0.7))
	_damage_aoe_projectile_explosion(blast_position, aoe_radius * 0.8, echo_damage)


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
	# SCRUM-961: «Лунный расщепитель» ветвит болт с первой цели.
	# SCRUM-939: хук «Цепной палочки» (wand_chain_blasts) удалён — dark_wand
	# ушёл с beam на dark_chain_burst, артефакт репозиционирован (wand_extra_chain).
	var moon_splits := int(_owner_mod("moon_split_targets")) if weapon_id == "moon_crossbow" else 0
	for hit in hits:
		if hit_count >= hit_limit:
			break
		_damage_enemy(hit["node"], damage_value * pow(falloff, float(hit_count)))
		if hit_count == 0 and moon_splits > 0:
			_fire_moon_splits(hit["node"] as Node2D, damage_value, moon_splits)
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


func _fire_single_dot_beam(owner_node: Node2D, direction: Vector2) -> void:
	# SCRUM-894: при close_contact_radius > 0 (Ядовитая струна) линия начинается
	# у самого героя, а враги вплотную (с любой стороны) становятся ПЕРВЫМИ
	# кандидатами — точка в упор не мёртвая. Пирс-лимит общий для близких и
	# коридорных целей — бесплатных дополнительных хитов нет.
	var beam_visual_offset := 6.0 if close_contact_radius > 0.0 else 26.0
	var start := owner_node.global_position + direction * beam_visual_offset
	var finish := owner_node.global_position + direction * attack_range
	var beam_visual := AttackVfx.beam(_projectile_parent(), start, finish, beam_width, visual_color)
	_register_effect(beam_visual)

	var hits := []
	var seen_ids := {}
	if close_contact_radius > 0.0:
		AttackVfx.ring_pulse(_projectile_parent(), owner_node.global_position, close_contact_radius, Color(visual_color.r, visual_color.g, visual_color.b, 0.18), false)
		for enemy_node in TARGET_QUERY.in_radius(self, owner_node.global_position, close_contact_radius):
			if enemy_node == null or not is_instance_valid(enemy_node):
				continue
			seen_ids[enemy_node.get_instance_id()] = true
			# Отрицательный forward ставит цели в упор впереди коридорных при сортировке.
			hits.append({
				"node": enemy_node,
				"forward": owner_node.global_position.distance_to(enemy_node.global_position) - close_contact_radius,
			})
	var corridor_origin := owner_node.global_position if close_contact_radius > 0.0 else start
	for hit in _enemies_in_corridor(corridor_origin, direction, beam_width, attack_range):
		var corridor_enemy := hit["node"] as Node2D
		if corridor_enemy != null and seen_ids.has(corridor_enemy.get_instance_id()):
			continue
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
	# SCRUM-900: пила переехала на режим saw_sector.
	var heal_ratio := heal_percent_of_damage
	if attack_mode == "saw_sector":
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


# ============================ SCRUM-900: кит Доктора ============================
# «Клятва чумного доктора»: весь сустейн класса — heal_percent_of_damage от
# ФАКТИЧЕСКИ нанесённого урона (_damage_enemy → _heal_owner_from_damage →
# apply_drain_heal с per-second бюджетом SCRUM-517). Нет урона — нет лечения.


# Чумной дротик: летящий снаряд в цель; на попадании — малый прямой урон и
# долгая зараза (см. _apply_plague_infection). Мета-ветка drain_extra_targets
# (Атлас Доктора) добавляет дротики по ближайшим соседям первичной цели.
func _fire_plague_dart(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	if target == null:
		return
	var targets: Array = [target]
	var extra_darts := _extra_projectiles()
	if extra_darts > 0:
		var used := {target.get_instance_id(): true}
		var previous_position := target.global_position
		for _extra_index in range(extra_darts):
			var next_target := _find_nearest_enemy_from(previous_position, maxf(plague_spread_radius, aoe_radius), used)
			if next_target == null:
				break
			used[next_target.get_instance_id()] = true
			targets.append(next_target)
			previous_position = next_target.global_position
	for dart_target_raw in targets:
		var dart_target := dart_target_raw as Node2D
		if dart_target == null or not is_instance_valid(dart_target):
			continue
		_launch_plague_dart_at(owner_node, dart_target, direction)


func _launch_plague_dart_at(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var dart := AttackVfx.orb_projectile(_projectile_parent(), owner_node.global_position + direction * 26.0, visual_color)
	_register_effect(dart)
	var travel_time: float = clampf(dart.global_position.distance_to(target.global_position) / maxf(projectile_speed, 1.0), 0.06, 0.42)
	var tween := create_tween()
	tween.tween_property(dart, "global_position", target.global_position, travel_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# SCRUM-551: bound-метод вместо лямбды (захват узлов в лямбде — use-after-free).
	tween.tween_callback(Callable(self, "_plague_dart_arrive").bind(dart.get_instance_id(), owner_node.get_instance_id(), target.get_instance_id()))


func _plague_dart_arrive(dart_id: int, owner_id: int, target_id: int) -> void:
	var dart := instance_from_id(dart_id) as Node
	if dart != null:
		_release_effect(dart)
	if _effects_shutdown:
		return
	var owner_node := instance_from_id(owner_id) as Node2D
	var target := instance_from_id(target_id) as Node2D
	if owner_node == null or not is_instance_valid(owner_node) or target == null or not is_instance_valid(target):
		return
	# Прямой урон дротика: небольшой укол (magic), лечит через heal_percent_of_damage.
	_damage_enemy(target, _rolled_damage(owner_node))
	_apply_plague_infection(target, owner_node)


# Профиль чумы из текущих полей оружия + derived-статов владельца.
func _plague_runtime_profile(owner_node: Node2D) -> Dictionary:
	var params_raw = owner_node.get("derived_parameters") if owner_node != null else null
	var params: Dictionary = params_raw if params_raw is Dictionary else {}
	return ProgressionData.plague_tick_profile({
		"plague_duration": plague_duration,
		"plague_tick_interval": plague_tick_interval,
		"plague_tick_ratio": plague_tick_ratio,
		"plague_dot_coupling": plague_dot_coupling,
		"plague_ramp_ticks": plague_ramp_ticks,
	}, params)


func _plague_active_count() -> int:
	# Чистка мёртвых записей (враг умер/освобождён — tween-тики уже no-op).
	for enemy_id in _plague_tweens.keys().duplicate():
		var enemy := instance_from_id(int(enemy_id)) as Node2D
		if enemy == null or not is_instance_valid(enemy):
			var stale_tween: Tween = _plague_tweens[enemy_id]
			if stale_tween != null and stale_tween.is_valid():
				stale_tween.kill()
			_plague_tweens.erase(enemy_id)
	return _plague_tweens.size()


# Заражение цели чумой: долгий DoT с медленным ramp'ом тиков. Повторное
# попадание РЕФРЕШИТ заразу (полная длительность, ramp заново — без стакинга).
# Кап одновременных зараз plague_max_infected — «бессмертие от полного
# заражения карты» отрезано и здесь, и per-second drain-бюджетом лечения.
func _apply_plague_infection(enemy: Node2D, owner_node: Node2D) -> void:
	if enemy == null or not is_instance_valid(enemy) or owner_node == null or not is_instance_valid(owner_node):
		return
	if _effects_shutdown:
		return
	var enemy_id := enemy.get_instance_id()
	var refreshing := _plague_tweens.has(enemy_id)
	if not refreshing and _plague_active_count() >= maxi(plague_max_infected, 1):
		return
	if refreshing:
		var old_tween: Tween = _plague_tweens[enemy_id]
		if old_tween != null and old_tween.is_valid():
			old_tween.kill()
		_plague_tweens.erase(enemy_id)
	var profile := _plague_runtime_profile(owner_node)
	var tick_interval := maxf(float(profile.get("tick_interval", 1.0)), 0.2)
	var ticks := maxi(int(profile.get("ticks", 1)), 1)
	AttackVfx.ring_pulse(_projectile_parent(), enemy.global_position, 44.0, visual_color, false)
	var tween := create_tween()
	_plague_tweens[enemy_id] = tween
	var owner_id := owner_node.get_instance_id()
	for tick_index in range(ticks):
		tween.tween_interval(tick_interval)
		tween.tween_callback(Callable(self, "_plague_tick").bind(enemy_id, owner_id, tick_index))
	tween.tween_callback(Callable(self, "_end_plague_infection").bind(enemy_id))


func _plague_tick(enemy_id: int, owner_id: int, tick_index: int) -> void:
	if _effects_shutdown:
		return
	var enemy := instance_from_id(enemy_id) as Node2D
	if enemy == null or not is_instance_valid(enemy):
		_end_plague_infection(enemy_id)
		return
	var owner_node := instance_from_id(owner_id) as Node2D
	if owner_node == null or not is_instance_valid(owner_node):
		return
	var profile := _plague_runtime_profile(owner_node)
	var tick_damage := float(profile.get("tick_damage", 0.0)) * ProgressionData.plague_ramp_factor(tick_index, plague_ramp_ticks)
	if tick_damage <= 0.0:
		return
	# Тик чумы: dot-канал, без melee-эффектов и без owner-hit нотификаций;
	# лечение Доктора идёт внутри _damage_enemy → _heal_owner_from_damage.
	_damage_enemy(enemy, tick_damage, false, "dot", false)
	HazardVfx.dot_tick(enemy, Color(visual_color.r, visual_color.g, visual_color.b, 1.0))
	# Распространение: тикающая зараза с ограниченным шансом перескакивает на
	# ближайшего НЕзаражённого соседа (кап учтён в _apply_plague_infection).
	if plague_spread_chance > 0.0 and randf() < plague_spread_chance:
		_spread_plague_from(enemy, owner_node)


func _spread_plague_from(enemy: Node2D, owner_node: Node2D) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if _plague_active_count() >= maxi(plague_max_infected, 1):
		return
	var excluded := {}
	for infected_id in _plague_tweens.keys():
		excluded[int(infected_id)] = true
	var next_target := _find_nearest_enemy_from(enemy.global_position, plague_spread_radius, excluded)
	if next_target == null:
		return
	AttackVfx.beam(_projectile_parent(), enemy.global_position, next_target.global_position, 10.0, Color(visual_color.r, visual_color.g, visual_color.b, 0.30))
	_apply_plague_infection(next_target, owner_node)


func _end_plague_infection(enemy_id: int) -> void:
	_plague_tweens.erase(enemy_id)


# Костяная пила: melee-сектор cone_degrees (120-150°) перед Доктором с реальной
# дальностью. Бьёт все цели в дуге (диминиш сверх sector_full_targets), лечит
# сильнее всех оружий Доктора (heal_percent_of_damage) — но только по фронту:
# враги с флангов/спины давят безнаказанно, позиционирование = выживание.
func _fire_saw_sector(owner_node: Node2D, direction: Vector2) -> void:
	var slash := AttackVfx.slash(owner_node, direction, attack_range, visual_color)
	_register_effect(slash)
	var params_raw = owner_node.get("derived_parameters")
	var params: Dictionary = params_raw if params_raw is Dictionary else {}
	# Ширина дуги растёт от секторных улучшений (+«Зубья костяной пилы»).
	var cone_effective := clampf(
		cone_degrees * maxf(float(params.get("sector_multiplier", 1.0)), 0.1) * (1.0 + _owner_mod("saw_arc_width_mult")),
		20.0, 360.0)
	var half_angle := deg_to_rad(cone_effective * 0.5)
	var candidates := []
	for enemy_node in TARGET_QUERY.enemies(self):
		if not is_instance_valid(enemy_node):
			continue
		var offset: Vector2 = enemy_node.global_position - owner_node.global_position
		var distance := offset.length()
		if distance > attack_range:
			continue
		if distance > 0.001 and absf(direction.angle_to(offset)) > half_angle:
			continue
		candidates.append({"node": enemy_node, "distance": distance})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distance"]) < float(b["distance"])
	)
	var damage_value := _rolled_damage(owner_node)
	var hit_index := 0
	for candidate in candidates:
		var hit_damage := damage_value
		if hit_index >= maxi(sector_full_targets, 1) and sector_target_diminish > 0.0:
			hit_damage *= pow(sector_target_diminish, float(hit_index - maxi(sector_full_targets, 1) + 1))
		_damage_enemy(candidate["node"], hit_damage)
		hit_index += 1
# ========================== конец кита Доктора (SCRUM-900) ==========================


# SCRUM-961 «Восстановительный пар»: короткая паровая зона у цели — 2 тика
# за 1.4с, тик жжёт 28% урона, 20% урона пара лечит Доктора через
# apply_drain_heal (капы drain-бюджета соблюдены). SCRUM-900: хук переехал с
# drain_link-связи на взрыв зелья (см. _launch_aoe_projectile).
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


# SCRUM-936 «Аркебуза»: одна быстрая взрывная пуля — видимый снаряд летит далеко
# в цель и взрывается малым AoE (полный урон в центре, falloff к краю зоны).
# extra_projectile (артефакты «Ядро Расщепления» и т.п.) добавляет пули по
# следующим ближайшим целям. Trait «Двойное действие» даёт второй независимый
# выстрел через _maybe_fire_action_echo (без рекурсии).
func _fire_arquebus_shot(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var count := maxi(1 + _extra_projectiles(), 1)
	var targets := _find_closest_enemies(owner_node, count)
	if targets.is_empty():
		if target != null and is_instance_valid(target):
			targets = [target]  # цель вне базового радиуса поиска (передана _attack)
		else:
			_launch_arquebus_bullet(owner_node, null, direction)
			return
	for target_index in range(mini(count, targets.size())):
		var target_node := targets[target_index] as Node2D
		var aim := direction
		if target_node != null:
			var to_target: Vector2 = target_node.global_position - owner_node.global_position
			if to_target.length_squared() > 0.001:
				aim = to_target.normalized()
		_launch_arquebus_bullet(owner_node, target_node, aim)


func _launch_arquebus_bullet(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var start := owner_node.global_position + direction * 28.0
	var target_position: Vector2 = owner_node.global_position + direction * minf(attack_range, 560.0)
	if target != null:
		target_position = target.global_position
	# Короткая вспышка у дула — читаемое начало выстрела (важно для эха: два дула).
	var muzzle := AttackVfx.beam(_projectile_parent(), start, start + direction * 46.0, beam_width, Color(visual_color.r, visual_color.g, visual_color.b, 0.55))
	_register_effect(muzzle)
	var bullet := AttackVfx.orb_projectile(_projectile_parent(), start, visual_color)
	_register_effect(bullet)
	var travel_time: float = clampf(start.distance_to(target_position) / maxf(projectile_speed, 1.0), 0.05, 0.60)
	var tween := create_tween()
	tween.tween_property(bullet, "global_position", target_position, travel_time).set_trans(Tween.TRANS_LINEAR)
	# SCRUM-551: Callable + примитивные bind-аргументы вместо лямбды с захватом узлов.
	tween.tween_callback(Callable(self, "_explode_arquebus_bullet").bind(bullet.get_instance_id(), owner_node.get_instance_id(), target_position, direction))


func _explode_arquebus_bullet(bullet_id: int, owner_id: int, center: Vector2, direction: Vector2) -> void:
	var bullet := instance_from_id(bullet_id) as Node
	if _effects_shutdown:
		if bullet != null and is_instance_valid(bullet):
			bullet.queue_free()
		return
	var current_owner := instance_from_id(owner_id) as Node2D
	var explosion_damage := damage
	if current_owner != null and is_instance_valid(current_owner):
		explosion_damage = _rolled_damage(current_owner)
	# SCRUM-961 «Шрапнель аркебузы» (rework SCRUM-936): осколочная зона шире (+25%)
	# и злее к соседям (falloff-пол 0.45→0.59); центр без изменений.
	var shrapnel := _owner_mod("arquebus_shrapnel_bonus") > 0.0
	var blast_radius := aoe_radius * (1.25 if shrapnel else 1.0)
	var edge_falloff := clampf(damage_falloff + (0.14 if shrapnel else 0.0), 0.0, 0.9)
	_damage_enemies_in_circle_falloff(center, blast_radius, explosion_damage, edge_falloff)
	for enemy_node in TARGET_QUERY.in_radius(self, center, blast_radius):
		_push_enemy(enemy_node, direction)
	AttackVfx.orb_burst(_projectile_parent(), center, blast_radius, visual_color)
	if bullet != null and is_instance_valid(bullet):
		_release_effect(bullet)


# SCRUM-937 «Граната с фитилем»: медленный снаряд долго летит в телеграфированную
# зону, ложится и горит на видимом фитиле (grenade_delay), затем тяжёлый взрыв с
# falloff к краю. Урон ТОЛЬКО на взрыве — враги успевают выйти из зоны. Trait
# «Двойное действие» бросает вторую независимую гранату со своим полётом/фитилём.
# Полёт капится GRENADE_MAX_FLIGHT_SPEED: derived projectile_speed растёт от статов
# (perception 18/очко) и без капа съел бы «медленную» identity нюка.
const GRENADE_MAX_FLIGHT_SPEED := 460.0


func _fire_grenade_fuse(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	# SCRUM-961 «Длинный фитиль»: фитиль горит дольше (+0.35с телеграф), взрыв
	# окупается (+long_fuse_bonus урона, +10% радиуса).
	var fuse_bonus := _owner_mod("long_fuse_bonus")
	var fuse_delay := maxf(grenade_delay, 0.20) + (0.35 if fuse_bonus > 0.0 else 0.0)
	var blast_radius := aoe_radius * (1.10 if fuse_bonus > 0.0 else 1.0)
	var blast_damage_mult := 1.0 + fuse_bonus
	var target_position: Vector2 = owner_node.global_position + direction * minf(attack_range, 440.0)
	if target != null:
		target_position = target.global_position
	var start := owner_node.global_position + direction * 26.0
	var flight_speed := clampf(projectile_speed, 60.0, GRENADE_MAX_FLIGHT_SPEED)
	var travel_time := maxf(start.distance_to(target_position) / flight_speed, 0.25)
	_emit_weapon_animation_event(owner_node, "windup", travel_time + fuse_delay, direction, {"delayed": true})
	var telegraph := AttackVfx.ring_pulse(_projectile_parent(), target_position, blast_radius, visual_color, true)
	_register_effect(telegraph)
	var grenade := AttackVfx.orb_projectile(_projectile_parent(), start, visual_color)
	_register_effect(grenade)
	var tween := create_tween()
	tween.tween_property(grenade, "global_position", target_position, travel_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Посадка: отдельный «armed»-пульс фитиля — читаемая фаза между полётом и взрывом.
	tween.tween_callback(Callable(self, "_arm_grenade_fuse").bind(owner_node.get_instance_id(), target_position, blast_radius, direction, fuse_delay))
	tween.tween_interval(fuse_delay)
	tween.tween_callback(Callable(self, "_explode_grenade_fuse").bind(grenade.get_instance_id(), telegraph.get_instance_id(), owner_node.get_instance_id(), target_position, blast_radius, blast_damage_mult, direction))


func _arm_grenade_fuse(owner_id: int, center: Vector2, blast_radius: float, direction: Vector2, fuse_delay: float) -> void:
	if _effects_shutdown:
		return
	var fuse_ring := AttackVfx.ring_pulse(_projectile_parent(), center, blast_radius * 0.45, Color(1.0, 0.82, 0.30, 0.55), false)
	if fuse_ring != null:
		_register_effect(fuse_ring)
	var current_owner := instance_from_id(owner_id) as Node2D
	if current_owner != null and is_instance_valid(current_owner):
		_emit_weapon_animation_event(current_owner, "pulse", fuse_delay, direction, {"fuse": true})


func _explode_grenade_fuse(grenade_id: int, telegraph_id: int, owner_id: int, center: Vector2, blast_radius: float, blast_damage_mult: float, direction: Vector2) -> void:
	var current_grenade := instance_from_id(grenade_id) as Node
	var current_telegraph := instance_from_id(telegraph_id) as Node
	if _effects_shutdown:
		if current_grenade != null and is_instance_valid(current_grenade):
			current_grenade.queue_free()
		if current_telegraph != null and is_instance_valid(current_telegraph):
			current_telegraph.queue_free()
		return
	var current_owner := instance_from_id(owner_id) as Node2D
	var explosion_damage := damage
	if current_owner != null and is_instance_valid(current_owner):
		explosion_damage = _rolled_damage(current_owner)
		_emit_weapon_animation_event(current_owner, "release", 0.0, direction, {"delayed": true})
	explosion_damage *= blast_damage_mult
	_damage_enemies_in_circle_falloff(center, blast_radius, explosion_damage, damage_falloff)
	AttackVfx.orb_burst(_projectile_parent(), center, blast_radius, visual_color)
	if current_grenade != null and is_instance_valid(current_grenade):
		_release_effect(current_grenade)
	if current_telegraph != null and is_instance_valid(current_telegraph):
		_release_effect(current_telegraph)


# SCRUM-938 «Штык-конус»: активный ближний сектор (cone_degrees) в направлении
# атаки — каждый враг в конусе получает укол и отброс за один взмах; вплотную к
# ногам мёртвой зоны нет (contact-rescue радиус). Поверх укола — редкий
# авто-выстрел винтовки по цели ЗА конусом (bayonet_auto_shot_chance + артефакт
# «Спуск штыка»). Выстрел — бонус-акцент, не превращает штык в вторую аркебузу.
const BAYONET_CONTACT_RESCUE_RADIUS := 52.0


func _fire_bayonet_cone(owner_node: Node2D, direction: Vector2) -> void:
	var cone_visual := AttackVfx.slash(owner_node, direction, attack_range, visual_color)
	_register_effect(cone_visual)
	var damage_value := _rolled_damage(owner_node)
	var origin := owner_node.global_position
	for enemy_node in TARGET_QUERY.enemies(self):
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		if not _is_enemy_inside_bayonet_cone(origin, enemy_node.global_position, direction):
			continue
		_damage_enemy(enemy_node, damage_value)
		var push_direction := (enemy_node.global_position - origin)
		_push_enemy(enemy_node, push_direction.normalized() if push_direction.length_squared() > 0.001 else direction)
	# Редкий выстрел: встроенный шанс оружия + артефакт SCRUM-961 «Спуск штыка».
	var shot_chance := clampf(bayonet_auto_shot_chance + _owner_mod("bayonet_shot_chance"), 0.0, 1.0)
	if randf() < shot_chance:
		_fire_bayonet_auto_shot(owner_node, direction)


func _is_enemy_inside_bayonet_cone(origin: Vector2, enemy_position: Vector2, direction: Vector2) -> bool:
	var to_enemy := enemy_position - origin
	var distance := to_enemy.length()
	# Анти-deadzone: враг у самых ног (включая застрявшего на игроке) всегда в зоне.
	if distance <= BAYONET_CONTACT_RESCUE_RADIUS:
		return true
	if distance > attack_range:
		return false
	return absf(direction.angle_to(to_enemy)) <= deg_to_rad(clampf(cone_degrees, 1.0, 360.0) * 0.5)


# Авто-выстрел штыка: цель — ближайший враг ВНЕ конуса (дальше досягаемости укола),
# в пределах bayonet_shot_range; без такой цели пуля уходит по направлению укола.
# Урон bayonet_shot_damage_multiplier от укола первому врагу на траектории.
func _fire_bayonet_auto_shot(owner_node: Node2D, direction: Vector2) -> void:
	var shot_direction := direction
	var beyond_target := _find_bayonet_shot_target(owner_node)
	if beyond_target != null:
		var to_target := beyond_target.global_position - owner_node.global_position
		if to_target.length_squared() > 0.001:
			shot_direction = to_target.normalized()
	var start := owner_node.global_position + shot_direction * 22.0
	var tracer := AttackVfx.beam(_projectile_parent(), start, owner_node.global_position + shot_direction * bayonet_shot_range, beam_width * 0.6, Color(visual_color.r, visual_color.g, visual_color.b, 0.50))
	_register_effect(tracer)
	_emit_weapon_animation_event(owner_node, "pulse", 0.0, shot_direction, {"bayonet_shot": true})
	var hits := _enemies_in_corridor(start, shot_direction, maxf(beam_width, 40.0), bayonet_shot_range)
	if hits.is_empty():
		return
	_damage_enemy(hits[0]["node"], _rolled_damage(owner_node) * bayonet_shot_damage_multiplier)


func _find_bayonet_shot_target(owner_node: Node2D) -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	var origin := owner_node.global_position
	for enemy_node in TARGET_QUERY.enemies(self):
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var distance := origin.distance_to(enemy_node.global_position)
		if distance <= attack_range or distance > bayonet_shot_range:
			continue
		if distance < best_distance:
			best_distance = distance
			best = enemy_node
	return best


# === SCRUM-897: кит Вора (редизайн поверх trait «Воровская хватка») ===
# Ниши: экономический рикошет по толпе / контроль-кинжал с backstab-пейоффом /
# защитная дым-зона с разовым AoE-взрывом. Константы ниже — единственный источник
# истины по капам/долям; бюджетная модель (_budget_hit_model в progression_data.gd)
# зеркалит эти же числа в комментариях.

# «Кошель Рикошета»: жёсткий кап длины цепи. База 6 прыжков (projectile_count),
# прогрессия (extra_projectile / артефакт «Счастливая монета») добирает до 8 —
# цепь конечна и не становится лучшим полнокартным клиром (полоса AC 5..8).
const COIN_CHAIN_HARD_CAP := 8

# «Отравленный Кинжал»: базовый удар фантома в долях ролла и позиционный пейофф.
const BACKSTAB_STRIKE_MULTIPLIER := 1.22       # базовый удар фантома
const BACKSTAB_POSITIONAL_MULTIPLIER := 1.35   # доп. множитель удара В СПИНУ (цель смотрит прочь от фантома)
const BACKSTAB_NEIGHBOR_SHARE := 0.35          # доля ролла соседям у точки удара
const BACKSTAB_FACING_DOT_THRESHOLD := 0.25    # порог «спина отдана фантому» (dot facing · фантом→цель)
const POISON_PARALYSIS_SPEED := 0.12           # целевой множитель скорости яда (StatusEffects клампит группу на 0.25)
const POISON_PARALYSIS_CAP := 1.8              # кап суммарного окна паралича (база + артефакт), сек
const POISON_PARALYSIS_BOSS_FACTOR := 0.25     # боссы/элиты: срезанное окно (~0.21с база; на скейле темпа аптайм <60%)


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
	# SCRUM-961 «Счастливая монета» / extra_projectile: цепь скачет дольше, но
	# SCRUM-897 капит длину COIN_CHAIN_HARD_CAP — рикошет конечен по AC.
	var chain_count := clampi(projectile_count + _extra_projectiles() + int(_owner_mod("coin_extra_bounces")), 1, COIN_CHAIN_HARD_CAP)
	for chain_index in range(chain_count - 1):
		var next_target := _find_nearest_enemy_from(search_origin, attack_range * 0.65, used)
		if next_target == null:
			break
		chain_targets.append(next_target)
		used[next_target.get_instance_id()] = true
		search_origin = next_target.global_position

	var damage_value := _rolled_damage(owner_node)
	var origin := owner_node.global_position + direction * 24.0
	# SCRUM-897: монотонный спад до damage_falloff-доли (0.5) на ПОСЛЕДНЕМ
	# ЗАДУМАННОМ прыжке: hit_i = ролл × tail^(i/(n-1)). Экспонента считается от
	# полной длины цепи, поэтому спад читаем при любом числе реально найденных целей.
	var chain_tail := clampf(damage_falloff, 0.1, 1.0)
	var chain_span := maxf(float(chain_count - 1), 1.0)
	for hit_index in range(chain_targets.size()):
		var enemy_node := chain_targets[hit_index] as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var segment := AttackVfx.beam(_projectile_parent(), origin, enemy_node.global_position, beam_width, visual_color)
		_register_effect(segment)
		var hit_damage := damage_value * pow(chain_tail, float(hit_index) / chain_span)
		_damage_enemy(enemy_node, hit_damage)
		_try_steal_money(owner_node, hit_index)
		origin = enemy_node.global_position


# SCRUM-897 «Отравленный Кинжал»: фантомный удар из тени ЗА ближайшей целью.
# Герой НЕ двигается и НЕ телепортируется (позиционный пейофф в духе Dead Cells
# Assassin's Dagger): кинжал материализуется за спиной цели, паралич-яд даёт окно
# на побег или добивание, удар в спину бьёт больнее.
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
	var damage_value := _rolled_damage(owner_node)
	var strike_damage := damage_value * BACKSTAB_STRIKE_MULTIPLIER
	# Позиционный backstab: цель отдаёт спину фантому (смотрит/движется прочь) —
	# чейзеры, идущие на героя, наказываются; враг, глядящий на фантом, видит удар.
	if _is_backstab_hit(backstab_target, back_position, owner_node.global_position):
		strike_damage *= BACKSTAB_POSITIONAL_MULTIPLIER
	_damage_enemy(backstab_target, strike_damage)
	# Встроенный контроль SCRUM-897: короткое окно паралича-яда (кап, босс-резист);
	# SCRUM-961 «Парализующее лезвие» (backstab_root_duration) продлевает окно.
	var paralysis_window := clampf(poison_paralysis_duration + _owner_mod("backstab_root_duration"), 0.0, POISON_PARALYSIS_CAP)
	_apply_poison_paralysis(backstab_target, paralysis_window)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_node := enemy as Node2D
		if enemy_node == null or enemy_node == backstab_target or not is_instance_valid(enemy_node):
			continue
		if back_position.distance_squared_to(enemy_node.global_position) <= pow(aoe_radius * 0.55, 2.0):
			_damage_enemy(enemy_node, damage_value * BACKSTAB_NEIGHBOR_SHARE)
			_apply_poison_paralysis(enemy_node, paralysis_window)
	var vanish := AttackVfx.ring_pulse(_projectile_parent(), back_position, 62.0, visual_color, false)
	_register_effect(vanish)


# SCRUM-897: условие удара в спину — цель смотрит ПРОЧЬ от фантома. Направление
# взгляда: живая скорость врага (движение), иначе фоллбэк «чейзер смотрит на
# героя». Фантом появляется за спиной цели относительно героя, поэтому идущий на
# героя враг отдаёт спину, а убегающий/идущий на фантом — видит кинжал.
func _is_backstab_hit(enemy_node: Node2D, phantom_position: Vector2, owner_position: Vector2) -> bool:
	var away_from_phantom := enemy_node.global_position - phantom_position
	if away_from_phantom.length_squared() <= 0.001:
		return true
	var facing := Vector2.ZERO
	var velocity_raw = enemy_node.get("velocity")
	if velocity_raw is Vector2 and (velocity_raw as Vector2).length_squared() > 4.0:
		facing = (velocity_raw as Vector2).normalized()
	else:
		facing = (owner_position - enemy_node.global_position).normalized()
	if facing.length_squared() <= 0.001:
		return true
	return facing.dot(away_from_phantom.normalized()) >= BACKSTAB_FACING_DOT_THRESHOLD


# SCRUM-897: боссы и элиты сопротивляются контролю — окно паралича срезано
# (POISON_PARALYSIS_BOSS_FACTOR), пермалок невозможен (кап + короткая база).
func _control_resist_factor(enemy_node: Node2D) -> float:
	if enemy_node.is_in_group("bosses") or enemy_node.is_in_group("elite_enemies"):
		return POISON_PARALYSIS_BOSS_FACTOR
	return 1.0


func _apply_poison_paralysis(enemy_node: Node2D, duration: float) -> void:
	var effective_duration := duration * _control_resist_factor(enemy_node)
	if effective_duration <= 0.0:
		return
	# Паралич-лайт: StatusEffects.speed_multiplier клампит группу статусов на 0.25 —
	# жертва почти стоит, но контроль не абсолютен и всегда конечен.
	StatusEffects.apply_status(enemy_node, "poison_paralysis", {
		"duration": effective_duration,
		"speed_multiplier": POISON_PARALYSIS_SPEED,
		"marker_color": Color(0.50, 0.95, 0.45, 1.0),
	})


# SCRUM-897 «Дымовая Бомба»: брошенный снаряд с отложенной детонацией. Шашка
# видимо летит в точку grenade_delay, на детонации — ОДНО AoE-событие урона
# (скейлится уроном/AoE/темпом билда — реальный источник килов), затем на земле
# остаётся НЕдамажащее облако smoke_duration. Уклонение действует ТОЛЬКО пока
# герой стоит внутри облака (Player.register_smoke_cloud / smoke_cloud_dodge_bonus,
# суммарный кап в дыму — SMOKE_CLOUD_DODGE_CAP=0.90).
func _fire_smoke_bomb(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_emit_weapon_animation_event(owner_node, "windup", maxf(grenade_delay, 0.10), direction, {"delayed": true})
	var target_position: Vector2 = owner_node.global_position + direction * min(attack_range, 240.0)
	if target != null:
		target_position = target.global_position
	var bomb := AttackVfx.orb_projectile(_projectile_parent(), owner_node.global_position + direction * 20.0, visual_color)
	_register_effect(bomb)
	var fuse := maxf(grenade_delay, 0.10)
	var travel_tween := create_tween()
	travel_tween.tween_property(bomb, "global_position", target_position, fuse)
	# SCRUM-551: без захвата узлов в лямбду — Callable.bind по instance_id
	# (tween умирает вместе с оружием, бесхозная детонация невозможна).
	var detonation_tween := create_tween()
	detonation_tween.tween_interval(fuse)
	detonation_tween.tween_callback(Callable(self, "_detonate_smoke_bomb").bind(owner_node.get_instance_id(), bomb.get_instance_id(), target_position, direction))


func _detonate_smoke_bomb(owner_instance_id: int, bomb_instance_id: int, target_position: Vector2, direction: Vector2) -> void:
	var bomb := instance_from_id(bomb_instance_id) as Node
	if bomb != null and is_instance_valid(bomb):
		_release_effect(bomb)
	if _effects_shutdown:
		return
	var current_owner := instance_from_id(owner_instance_id) as Node2D
	if current_owner != null and not is_instance_valid(current_owner):
		current_owner = null
	var damage_value := damage if current_owner == null else _rolled_damage(current_owner)
	# Единственное дамажащее событие дыма — сам взрыв.
	_damage_enemies_in_circle(target_position, aoe_radius, damage_value)
	AttackVfx.orb_burst(_projectile_parent(), target_position, aoe_radius, visual_color)
	# Облако после взрыва урона НЕ наносит — только позиционное уклонение.
	var cloud := AttackVfx.ring_pulse(_projectile_parent(), target_position, aoe_radius, visual_color, true)
	_register_effect(cloud)
	var cloud_duration := maxf(_effective_smoke_duration(), 0.2)
	if current_owner != null:
		_emit_weapon_animation_event(current_owner, "release", cloud_duration, direction, {"delayed": true})
		# SCRUM-961 «Дымный тайник»: облако плотнее (+smoke_dodge_bonus) и дольше
		# (_effective_smoke_duration); бонус живёт только внутри зоны облака.
		var cloud_dodge := dodge_bonus + _owner_mod("smoke_dodge_bonus")
		if current_owner.has_method("register_smoke_cloud"):
			current_owner.call("register_smoke_cloud", target_position, aoe_radius, cloud_duration, cloud_dodge)
	var cloud_tween := create_tween()
	cloud_tween.tween_interval(cloud_duration)
	cloud_tween.tween_callback(Callable(self, "_release_effect_by_id").bind(cloud.get_instance_id()))


# === SCRUM-947..950: кит Элементалиста (редизайн поверх trait «Проводник стихий») ===
# Ниши: постоянный квадрат-ореол (кольцо) / редкий полнокартный X (призма) /
# сверхредкий нюк с догорающей зоной (метеор). Константы ниже — единственный
# источник истины по долям/геометрии; бюджетная модель (_budget_hit_model в
# progression_data.gd) зеркалит эти же числа в комментариях.

# SCRUM-948 «Кольцо Четырёх Стихий»: квадратная зона в точке каста.
const SQUARE_HALF_RATIO := 0.72          # половина стороны квадрата = aoe_radius * ratio
const SQUARE_PHYSICAL_SHARE := 0.45      # доля канала damage (ось силы) на КАСТ
const SQUARE_DOT_TICK_SHARE := 0.70      # доля dot_damage владельца на тик ожога
const SQUARE_EARTH_CORE_PHYS_BONUS := 0.60  # артефакт «Четвертое кольцо»: +60% физ.доли
const SQUARE_EXTRA_TICK_CAP := 2         # кап доп. тиков от extra-рун («Монолит»)
const SQUARE_ELEMENT_COLORS := [
	Color(1.0, 0.42, 0.16, 0.85),  # огонь
	Color(0.26, 0.76, 1.0, 0.85),  # вода
	Color(0.64, 1.0, 0.28, 0.85),  # природа
	Color(0.72, 0.52, 0.24, 0.85), # земля — четвёртая стихия
]

# SCRUM-949 «Призматический Фокус»: полнокартный X-разлом.
# PRISM_FULL_MAP_REACH — документированный практический предел «во всю карту»:
# длина плеча луча от центра. Диагональ арены 4096×2304 ≈ 4700px, значит 4800px
# достигает любой точки арены из любого центра каста (тест держит этот инвариант).
const PRISM_FULL_MAP_REACH := 4800.0
const PRISM_BEAM_DAMAGE_SHARE := 0.72    # один луч-хит на врага за каст (без дублей)
const PRISM_CENTER_BONUS_SHARE := 0.55   # бонус-хит центра пересечения (стакается с лучом)
const PRISM_CROSS_EXTRA_SHARE := 0.60    # артефакт «Призматический крест»: доп. крест «+»

# SCRUM-950 «Ядро Метеора»: grenade_delay = ПОЛНАЯ задержка до удара.
const METEOR_TELEGRAPH_RATIO := 0.42     # доля задержки на чистый телеграф до падения
const METEOR_FALL_HEIGHT := 540.0        # высота, с которой метеор летит в зону
const METEOR_ZONE_RADIUS_RATIO := 0.78   # радиус догорающей зоны от aoe_radius
const METEOR_ZONE_FULL_TARGETS := 2      # полные тики зоны ближайшим к ядру
const METEOR_ZONE_TARGET_DIMINISH := 1.2 # спад по рангу удалённости в зоне
const METEOR_HEART_CENTER_BONUS := 0.55  # артефакт «Сердце метеора»: +55% центра
const METEOR_HEART_EXTRA_ZONE_TICKS := 2 # и догорание на 2 тика дольше


# SCRUM-948: враги внутри КВАДРАТА (углы поражаются — вписанный круг их не берёт,
# за пределами стороны — нет). Сбор через окружающий радиус + осевой фильтр.
func _enemies_in_square(center: Vector2, half_size: float) -> Array:
	var result := []
	for enemy in TARGET_QUERY.in_radius(self, center, half_size * 1.4143):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var offset := enemy_node.global_position - center
		if absf(offset.x) <= half_size and absf(offset.y) <= half_size:
			result.append(enemy_node)
	return result


# SCRUM-948 «Кольцо Четырёх Стихий»: квадратная AoE четырёх стихий в точке каста
# (зона НЕ следует за героем). Каждый тик бьёт ТРЕМЯ каналами сразу — потому
# оружие тяжело масштабировать оптимально (три атрибутные оси):
#   магия     — ролл magic_damage, делённый на тики (ось интеллекта, канал оружия);
#   физика    — SQUARE_PHYSICAL_SHARE от канала damage владельца (ось силы);
#   периодика — статус ожога от dot_damage/dot_speed владельца (ось знания);
# и отбрасывает задетых ПРОЧЬ от центра квадрата (защита личного пространства).
# Имя функции сохраняет исторический attack_mode "elemental_orbit" (стабильные
# внешние контракты: меты, тесты, анимации).
func _fire_elemental_orbit(owner_node: Node2D, direction: Vector2) -> void:
	# «Монолит»/extra-руны: дополнительные тики поля (кап SQUARE_EXTRA_TICK_CAP).
	var ticks := maxi(storm_ticks, 1) + clampi(_extra_projectiles(), 0, SQUARE_EXTRA_TICK_CAP)
	_emit_weapon_animation_event(owner_node, "channel", orbit_duration, direction, {"ticks": ticks})
	var center: Vector2 = owner_node.global_position
	var half_size: float = aoe_radius * SQUARE_HALF_RATIO
	var field_root := Node2D.new()
	field_root.name = "ElementalSquareField"
	field_root.z_index = 3
	_projectile_parent().add_child(field_root)
	_register_effect(field_root)
	field_root.global_position = center
	_draw_square_field(field_root, half_size)
	_elemental_square_tick(owner_node, center, half_size, ticks)
	var tick_interval := maxf(orbit_duration / float(ticks), 0.08)
	var owner_id := owner_node.get_instance_id()
	var field_id := field_root.get_instance_id()
	var field_tween := create_tween()
	for tick_index in range(1, ticks):
		field_tween.tween_interval(tick_interval)
		field_tween.tween_callback(Callable(self, "_elemental_square_scheduled_tick").bind(owner_id, center, half_size, ticks, tick_index, direction))
	field_tween.tween_interval(tick_interval)
	field_tween.tween_callback(Callable(self, "_release_effect_by_id").bind(field_id))


# Разметка квадрата: 4 грани + руны четырёх стихий по углам. Полупрозрачно и
# под врагами (z_index поля 3), чтобы зона читалась квадратом, но не закрывала бой.
func _draw_square_field(field_root: Node2D, half_size: float) -> void:
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for corner_index in range(4):
		var edge_start: Vector2 = (corners[corner_index] as Vector2) * half_size
		var edge_end: Vector2 = (corners[(corner_index + 1) % 4] as Vector2) * half_size
		var edge := Line2D.new()
		edge.points = PackedVector2Array([edge_start, edge_end])
		edge.width = 6.0
		edge.default_color = Color(visual_color.r, visual_color.g, visual_color.b, 0.34)
		field_root.add_child(edge)
		var rune := Sprite2D.new()
		rune.name = "ElementRune%d" % corner_index
		rune.texture = _weapon_visual_texture()
		rune.modulate = SQUARE_ELEMENT_COLORS[corner_index % SQUARE_ELEMENT_COLORS.size()]
		rune.scale = Vector2.ONE * 0.16
		rune.position = (corners[corner_index] as Vector2) * half_size
		field_root.add_child(rune)


func _elemental_square_scheduled_tick(owner_id: int, center: Vector2, half_size: float, ticks: int, tick_index: int, direction: Vector2) -> void:
	if _effects_shutdown:
		return
	var current_owner := instance_from_id(owner_id) as Node2D
	if current_owner == null or not is_instance_valid(current_owner):
		return
	_emit_weapon_animation_event(current_owner, "pulse", 0.0, direction, {"index": tick_index, "count": ticks})
	_elemental_square_tick(current_owner, center, half_size, ticks)


# Один тик квадрата: три канала + отброс от ЦЕНТРА КВАДРАТА (не от героя — зона
# автономна после каста). Элиты/боссы получают тот же apply_knockback-импульс,
# что и у прочих отбросов оружий (их устойчивость решает enemy-сторона).
func _elemental_square_tick(owner_node: Node2D, center: Vector2, half_size: float, ticks: int) -> void:
	var parameters_raw = owner_node.get("derived_parameters")
	var parameters: Dictionary = parameters_raw if parameters_raw is Dictionary else {}
	var tick_divisor := float(maxi(ticks, 1))
	var magic_tick := _rolled_damage(owner_node) / tick_divisor
	var physical_total := float(parameters.get("damage", 0.0)) * SQUARE_PHYSICAL_SHARE
	if _owner_mod("earth_orb_mode") > 0.0:
		# «Четвертое кольцо»: земляное ядро укрепляет физический канал квадрата.
		physical_total *= 1.0 + SQUARE_EARTH_CORE_PHYS_BONUS
	var physical_tick := physical_total / tick_divisor
	var dot_tick_damage := maxf(float(parameters.get("dot_damage", 2.0)) * SQUARE_DOT_TICK_SHARE, 0.5)
	var dot_interval := 1.0 / maxf(float(parameters.get("dot_speed", 1.0)), 0.2)
	var burn_ticks := maxi(dot_ticks, 1)
	for enemy in _enemies_in_square(center, half_size):
		var enemy_node := enemy as Node2D
		_damage_enemy(enemy_node, magic_tick)
		if physical_tick > 0.0:
			_damage_enemy(enemy_node, physical_tick, false, "physical", false)
		StatusEffects.apply_status(enemy_node, "four_elements_burn", {
			"duration": dot_interval * float(burn_ticks),
			"dot_damage": dot_tick_damage,
			"dot_interval": dot_interval,
			"marker_color": Color(0.40, 0.82, 1.0, 1.0),
		})
		var away := enemy_node.global_position - center
		if away.length_squared() > 0.001:
			_push_enemy(enemy_node, away.normalized())
	# SCRUM-961 «Стихийный отдачник»: дополнительный радиальный пуш от кастера.
	_apply_elemental_repulse(owner_node, center, half_size * 1.4143)


func _release_effect_by_id(effect_id: int) -> void:
	var effect := instance_from_id(effect_id) as Node
	if effect != null:
		_release_effect(effect)


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


# SCRUM-949 «Призматический Фокус»: полнокартный X-разлом через точку фокуса
# (ближайшая цель или точка на attack_range по направлению атаки). Две диагональные
# линии (направление ±45°) длиной PRISM_FULL_MAP_REACH в каждое плечо пронзают
# всех врагов на пути; малый AoE в центре пересечения бьёт бонус-хитом.
# Телеграф: тонкие X-линии + кольцо центра на время grenade_delay ДО урона.
# Детерминизм урона: за каст враг получает НЕ БОЛЕЕ одного луч-хита (первая
# диагональ в порядке осей побеждает; кресты артефакта — своя доля, тоже один хит)
# и не более одного центр-хита. Центр+луч = полный пэйофф пересечения.
func _fire_prism_rift(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_emit_weapon_animation_event(owner_node, "windup", maxf(grenade_delay, 0.12), direction, {"delayed": true})
	var center: Vector2 = owner_node.global_position + direction * min(attack_range, 360.0)
	if target != null:
		center = target.global_position
	var axis_a := direction.rotated(PI / 4.0)
	if axis_a.length_squared() <= 0.001:
		axis_a = Vector2(1, -1)
	axis_a = axis_a.normalized()
	var axis_b := axis_a.rotated(PI / 2.0)
	var telegraph_ids: Array = []
	for axis in [axis_a, axis_b]:
		var axis_vector: Vector2 = axis
		var tele_beam := AttackVfx.beam(_projectile_parent(), center - axis_vector * PRISM_FULL_MAP_REACH, center + axis_vector * PRISM_FULL_MAP_REACH, maxf(beam_width * 0.35, 12.0), Color(visual_color.r, visual_color.g, visual_color.b, 0.20))
		_register_effect(tele_beam)
		telegraph_ids.append(tele_beam.get_instance_id())
	var telegraph_ring := AttackVfx.ring_pulse(_projectile_parent(), center, aoe_radius, visual_color, true)
	_register_effect(telegraph_ring)
	telegraph_ids.append(telegraph_ring.get_instance_id())
	var rift_tween := create_tween()
	rift_tween.tween_interval(maxf(grenade_delay, 0.12))
	rift_tween.tween_callback(Callable(self, "_resolve_prism_rift").bind(owner_node.get_instance_id(), center, axis_a, axis_b, direction, telegraph_ids))


func _resolve_prism_rift(owner_id: int, center: Vector2, axis_a: Vector2, axis_b: Vector2, direction: Vector2, telegraph_ids: Array) -> void:
	for telegraph_id in telegraph_ids:
		_release_effect_by_id(int(telegraph_id))
	if _effects_shutdown:
		return
	var current_owner := instance_from_id(owner_id) as Node2D
	if current_owner != null and is_instance_valid(current_owner):
		_emit_weapon_animation_event(current_owner, "release", 0.0, direction, {"delayed": true})
	var damage_value := damage
	if current_owner != null and is_instance_valid(current_owner):
		damage_value = _rolled_damage(current_owner)
	# Оси урона: главные диагонали X, при артефакте «Призматический крест» — ещё
	# крест «+» (горизонталь/вертикаль относительно атаки) со сниженной долей.
	var beam_axes := [[axis_a, PRISM_BEAM_DAMAGE_SHARE], [axis_b, PRISM_BEAM_DAMAGE_SHARE]]
	if _owner_mod("prism_cross_pierce") > 0.0:
		var cross_axis := direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
		beam_axes.append([cross_axis, PRISM_BEAM_DAMAGE_SHARE * PRISM_CROSS_EXTRA_SHARE])
		beam_axes.append([cross_axis.rotated(PI / 2.0), PRISM_BEAM_DAMAGE_SHARE * PRISM_CROSS_EXTRA_SHARE])
	var color_cycle := [Color(0.26, 0.78, 1.0, 0.50), Color(1.0, 0.46, 0.20, 0.50), Color(0.76, 0.42, 1.0, 0.42), Color(0.64, 1.0, 0.28, 0.42)]
	var struck := {}
	for axis_index in range(beam_axes.size()):
		var axis_vector: Vector2 = beam_axes[axis_index][0]
		var axis_share: float = beam_axes[axis_index][1]
		var beam_start := center - axis_vector * PRISM_FULL_MAP_REACH
		var beam_end := center + axis_vector * PRISM_FULL_MAP_REACH
		var beam_visual := AttackVfx.beam(_projectile_parent(), beam_start, beam_end, beam_width, color_cycle[axis_index % color_cycle.size()])
		_register_effect(beam_visual)
		for enemy in TARGET_QUERY.in_segment(self, beam_start, beam_end, beam_width):
			var enemy_node := enemy as Node2D
			if enemy_node == null or not is_instance_valid(enemy_node):
				continue
			var enemy_key := enemy_node.get_instance_id()
			if struck.has(enemy_key):
				continue
			struck[enemy_key] = true
			_damage_enemy(enemy_node, damage_value * axis_share)
	for enemy in TARGET_QUERY.in_radius(self, center, aoe_radius):
		_damage_enemy(enemy as Node2D, damage_value * PRISM_CENTER_BONUS_SHARE)
	AttackVfx.orb_burst(_projectile_parent(), center, aoe_radius, visual_color)
	# SCRUM-961 «Стихийный отдачник»: центр разлома толкает монстров от кастера.
	if current_owner != null and is_instance_valid(current_owner):
		_apply_elemental_repulse(current_owner, center, aoe_radius)


# SCRUM-950 «Ядро Метеора»: самое медленное оружие игрока. grenade_delay — полная
# задержка до удара: сначала чистый телеграф зоны (METEOR_TELEGRAPH_RATIO доли,
# HazardVfx.telegraph — рост + тревожный пульс, читаемо ГДЕ и КОГДА упадёт),
# затем видимое падение метеора остаток времени. Урона до удара НЕТ. На ударе —
# тяжёлый магический AoE с falloff, затем догорающая DoT-зона: dot_ticks тиков
# каждые pool_tick_interval по dot-оси владельца (спад по рангу удалённости).
func _fire_meteor_shards(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var total_delay := maxf(grenade_delay, 0.30)
	_emit_weapon_animation_event(owner_node, "windup", total_delay, direction, {"delayed": true})
	var center: Vector2 = owner_node.global_position + direction * min(attack_range, 430.0)
	if target != null:
		center = target.global_position
	var telegraph_holder := Node2D.new()
	telegraph_holder.name = "MeteorTelegraph"
	_projectile_parent().add_child(telegraph_holder)
	telegraph_holder.global_position = center
	_register_effect(telegraph_holder)
	HazardVfx.telegraph(telegraph_holder, aoe_radius, Color(1.0, 0.45, 0.15, 1.0), total_delay)
	var meteor := AttackVfx.orb_projectile(_projectile_parent(), center + Vector2(200.0, -METEOR_FALL_HEIGHT), visual_color)
	_register_effect(meteor)
	var fall_time := maxf(total_delay * (1.0 - METEOR_TELEGRAPH_RATIO), 0.15)
	var meteor_tween := create_tween()
	meteor_tween.tween_interval(total_delay - fall_time)
	meteor_tween.tween_property(meteor, "global_position", center, fall_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	meteor_tween.tween_callback(Callable(self, "_resolve_meteor_impact").bind(owner_node.get_instance_id(), center, direction, meteor.get_instance_id(), telegraph_holder.get_instance_id()))


func _resolve_meteor_impact(owner_id: int, center: Vector2, direction: Vector2, meteor_id: int, telegraph_id: int) -> void:
	_release_effect_by_id(meteor_id)
	_release_effect_by_id(telegraph_id)
	if _effects_shutdown:
		return
	var current_owner := instance_from_id(owner_id) as Node2D
	var owner_alive := current_owner != null and is_instance_valid(current_owner)
	if owner_alive:
		_emit_weapon_animation_event(current_owner, "release", 0.0, direction, {"delayed": true})
	var damage_value := damage
	if owner_alive:
		damage_value = _rolled_damage(current_owner)
	var heart_mode := _owner_mod("meteor_heart_mode") > 0.0
	# «Сердце метеора»: реже (интервал ×1.45 в _fire_interval_artifact_factor),
	# но центральный удар жирнее и зона догорает дольше.
	var center_multiplier := 1.0 + (METEOR_HEART_CENTER_BONUS if heart_mode else 0.0)
	_damage_enemies_in_circle_falloff(center, aoe_radius, damage_value * center_multiplier, 0.55)
	AttackVfx.orb_burst(_projectile_parent(), center, aoe_radius, visual_color)
	if owner_alive:
		# SCRUM-961 «Стихийный отдачник»: удар метеора толкает монстров от кастера.
		_apply_elemental_repulse(current_owner, center, aoe_radius)
	var zone_ticks := maxi(dot_ticks, 1) + (METEOR_HEART_EXTRA_ZONE_TICKS if heart_mode else 0)
	var tick_interval := maxf(pool_tick_interval, 0.18)
	var zone_radius := aoe_radius * METEOR_ZONE_RADIUS_RATIO
	var zone_tween := create_tween()
	for tick_index in range(zone_ticks):
		zone_tween.tween_interval(tick_interval)
		zone_tween.tween_callback(Callable(self, "_meteor_zone_tick").bind(owner_id, center, zone_radius))


# Тик догорающей зоны метеора: периодический канал (тип "dot", ось знания),
# полные тики — ближайшим к ядру, дальше спад по рангу (анти-раздувание толпой).
func _meteor_zone_tick(owner_id: int, center: Vector2, zone_radius: float) -> void:
	if _effects_shutdown:
		return
	var tick_damage := 2.0
	var current_owner := instance_from_id(owner_id) as Node2D
	if current_owner != null and is_instance_valid(current_owner):
		var parameters_raw = current_owner.get("derived_parameters")
		if parameters_raw is Dictionary:
			tick_damage = maxf(float((parameters_raw as Dictionary).get("dot_damage", 2.0)), 1.0)
	AttackVfx.ring_pulse(_projectile_parent(), center, zone_radius, Color(1.0, 0.45, 0.15, 0.22), false)
	var enemies: Array = TARGET_QUERY.in_radius(self, center, zone_radius)
	enemies.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return center.distance_squared_to(a.global_position) < center.distance_squared_to(b.global_position)
	)
	for index in range(enemies.size()):
		var factor := 1.0
		if index >= METEOR_ZONE_FULL_TARGETS:
			factor = 1.0 / (1.0 + float(index - METEOR_ZONE_FULL_TARGETS + 1) * METEOR_ZONE_TARGET_DIMINISH)
		_damage_enemy(enemies[index] as Node2D, tick_damage * factor, false, "dot", false)


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
	if attack_mode != "arquebus_shot" and not (universal and attack_mode in ["grenade_fuse", "bayonet_cone"]):
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
	# SCRUM-897: золото начисляется МГНОВЕННО в кошель забега (gain_money) — без
	# спавна и сбора money-пикапа — и ДЕТЕРМИНИРОВАННО с первых steal_hits целей
	# цепи (читаемая экономика вместо прежнего 42%-ролла по хвосту).
	# SCRUM-961 «Счастливая монета»: coin_steal_bonus добавляет краденое золото.
	var effective_steal := steal_money + int(_owner_mod("coin_steal_bonus")) if steal_money > 0 else steal_money
	if effective_steal <= 0 or owner_node == null or not owner_node.has_method("gain_money"):
		return
	if hit_index >= maxi(steal_hits, 1):
		return
	owner_node.gain_money(effective_steal)


# SCRUM-897: прежний глобальный временный dodge (_apply_temporary_dodge через
# run_modifiers) удалён — уклонение дыма стало ПОЗИЦИОННЫМ (только внутри облака,
# см. _detonate_smoke_bomb + Player.smoke_cloud_dodge_bonus).
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
		# SCRUM-1005 «Разбор образцов»: ПРЯМЫЕ хиты владельца по цели под ЕГО
		# периодическим эффектом усилены data-driven множителем CLASS_TRAITS
		# (infected_direct_hit_multiplier; есть только у Биолога — остальным
		# generic-хук возвращает 1.0). Тики DoT сюда приходят с hit_type "dot"
		# и НЕ усиливаются; чужой/истёкший статус отсекает
		# StatusEffects.has_dot_from_source (атрибуция source_id владельца).
		if hit_type != "dot" and owner_node != null and owner_node.has_method("class_trait_value"):
			var infected_multiplier := maxf(float(owner_node.call("class_trait_value", "infected_direct_hit_multiplier", 1.0)), 1.0)
			if infected_multiplier > 1.0 and StatusEffects.has_dot_from_source(enemy, owner_node.get_instance_id()):
				final_amount *= infected_multiplier
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
	# SCRUM-894: крит-снапшот яда (dot_crit_snapshot_ratio > 0, Ядовитая струна) —
	# критовый прямой удар усиливает тики долей крит-множителя, зафиксированного
	# на момент каста (_last_attack_crit из _rolled_damage). Множитель уже зажат
	# CRIT_DAMAGE_CAP в derived_parameters — runaway исключён.
	if dot_crit_snapshot_ratio > 0.0 and _last_attack_crit:
		tick_damage *= 1.0 + maxf(float(parameters.get("crit_damage_multiplier", 1.0)) - 1.0, 0.0) * clampf(dot_crit_snapshot_ratio, 0.0, 1.0)
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

func _damage_enemies_in_pool(origin: Vector2, radius: float, amount: float, source_pool: Node2D = null) -> void:
	var enemies: Array = TARGET_QUERY.in_radius(self, origin, radius)
	_apply_pool_contact_statuses(enemies, source_pool)
	if enemies.size() <= POOL_FULL_TARGETS:
		for enemy_node in enemies:
			# SCRUM-942: тик лужи — периодический канал и на одиночной цели тоже:
			# тип "dot" (единая покраска цифр + trait-множитель периодики), без
			# он-хит статусов/дублей — зеркально ветке толпы ниже.
			_damage_enemy(enemy_node, amount, false, "dot", false)
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


# SCRUM-944: базовый префикс id вечных кислотных зарядов (+ instance id лужи).
const ACID_CHARGE_STATUS_PREFIX := "acid_charge"
# SCRUM-944: «вечность» заряда — живёт до смерти носителя (раунды много короче).
const ACID_CHARGE_PERSIST_SECONDS := 999999.0
# SCRUM-961 «Кислотный катализатор»: артефакт поднимает кап зарядов на цель.
const ACID_CHARGE_ARTIFACT_CAP_BONUS := 3

# SCRUM-944: контактные статусы луж. Кислотная колба (pool_contact_charges):
# монстр в луже получает ОДИН вечный DoT-заряд ОТ ЭТОЙ КОНКРЕТНОЙ лужи
# (status id = acid_charge_p<pool_instance_id>, max_stacks 1 → стоять в одной
# луже бесконечно = всё равно один заряд). Разные лужи стакаются: каждая даёт
# свой статус; их тики складываются и живут до смерти носителя. Балансовый кап:
# pool_charge_cap зарядов на цель (артефакт «Кислотный катализатор» +3).
# Trait «Катализатор» (+50% периодики) запекается через apply_status_from.
# «Печать терновника» (briar_staff) — стабильный слоу, без изменений.
func _apply_pool_contact_statuses(enemies: Array, source_pool: Node2D = null) -> void:
	var acid_charges := pool_contact_charges and source_pool != null and is_instance_valid(source_pool)
	var briar_slow := weapon_id == "briar_staff" and _owner_mod("briar_slow_power") > 0.0
	if not acid_charges and not briar_slow:
		return
	var owner_node := _owner_node()
	var charge_status_id := ""
	var charge_tick := 0.0
	var charge_cap := pool_charge_cap
	if acid_charges:
		charge_status_id = "%s_p%d" % [ACID_CHARGE_STATUS_PREFIX, source_pool.get_instance_id()]
		if _owner_mod("acid_charge_stacks") > 0.0:
			charge_cap += ACID_CHARGE_ARTIFACT_CAP_BONUS
		var parameters_raw = owner_node.get("derived_parameters") if owner_node != null else null
		var dot_damage := 2.0
		if parameters_raw is Dictionary:
			dot_damage = maxf(float((parameters_raw as Dictionary).get("dot_damage", 2.0)), 1.0)
		charge_tick = maxf(dot_damage * pool_charge_tick_multiplier, 0.30)
	for enemy in enemies:
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		if acid_charges and not StatusEffects.has_status(enemy_node, charge_status_id) \
				and StatusEffects.count_status_prefix(enemy_node, ACID_CHARGE_STATUS_PREFIX) < charge_cap:
			StatusEffects.apply_status_from(owner_node, enemy_node, charge_status_id, {
				"duration": ACID_CHARGE_PERSIST_SECONDS,
				"dot_damage": charge_tick,
				"dot_interval": pool_charge_tick_interval,
				"max_stacks": 1,
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
		var tagged: Dictionary = feedback if feedback is Dictionary else {}
		# SCRUM-1007: весь урон классового оружия — урон ИГРОКА. Метка едет в
		# feedback убившего хита (enemy._record_kill_attribution) и служит
		# атрибуцией он-килл trait'ов; лишний ключ для остальных читателей шумом
		# не является (enemy читает только известные поля).
		tagged["player_owned"] = true
		enemy.call("take_damage", amount, tagged)
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
		"grenade_fuse", "smoke_bomb", "prism_rift", "meteor_shards", "priest_sanctify", "robot_magnetic_anchor", "robot_compression_line", "sniper_lockshot", "sniper_kill_zone":
			return maxf(grenade_delay, 0.08)
		"priest_ward", "bio_spore_bloom", "bio_sample_dart":
			return maxf(burst_interval, 0.06)
		"amp", "trap", "engineer_sentry_link", "engineer_pressure_mines":
			return 0.10
		"beam", "dot_beam", "drain_link", "priest_prayer_chain", "bio_symbiote_web", "engineer_repair_drone":
			return 0.12
		# SCRUM-939..941: касты кита Тёмного мага — короткий читаемый замах.
		"dark_chain_burst", "skull_curse_burn", "dark_mirror_blast":
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
