extends "res://scripts/classes/class_weapon_shared_api.gd"

# FAN-3840: модуль распределённого боевого класса ClassWeapon — жизненный цикл и конвейер атаки: _ready/_attack/configure_weapon, эхо классовых артефактов, заряд, реестр эффектов.
# Часть линейной extends-цепочки scripts/classes/** (сборка — фасад
# scripts/class_weapon.gd). Код перенесён из class_weapon.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в class_weapon_shared_api.gd.


# SCRUM-961 «Счетчик ритма»: каждый N-й гитарный каст срабатывает дважды — повтор
# на 55% урона с короткой задержкой. Деплой amp исключён (эхо не ставит второй
# усилитель), эхо не порождает эхо (гард по _rhythm_echo_scale).
# SCRUM-898: гейт по weapon_id гитариста — sound_wave_damage удалён, гитарные
# оружия теперь бьют магией и по damage_parameter неотличимы от прочей магии.
const _RHYTHM_ECHO_WEAPON_IDS := ["electric_guitar", "bass_guitar", "sound_amp"]


# SCRUM-935 «Двойное действие» (class trait Солдата, data-driven): каждое действие
const ACTION_ECHO_EXCLUDED_MODES := {
	"amp": true, "trap": true,
	"engineer_sentry_link": true, "engineer_orbit_drone": true, "engineer_pressure_mines": true,
}


const ACTION_ECHO_DEFAULT_DELAY := 0.18


var _action_echo_active := false


const POOL_TICK_DAMAGE_MULTIPLIER := 0.55


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
	_constellation_mirror_pairs.clear()
	_constellation_mirror_casts.clear()
	_constellation_local_state.clear()
	_constellation_shatter_volleys.clear()
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
	real_projectile_count = maxi(int(config.get("real_projectile_count", 0)), 0)
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
	bow_knockback_trait = bool(config.get("bow_knockback_trait", bow_knockback_trait))
	trap_paralyze_seconds = float(config.get("trap_paralyze_seconds", trap_paralyze_seconds))
	trap_bleed_tick_interval = float(config.get("trap_bleed_tick_interval", trap_bleed_tick_interval))
	orbit_duration = float(config.get("orbit_duration", orbit_duration))
	storm_ticks = int(config.get("storm_ticks", storm_ticks))
	sanctify_tick_ratio = float(config.get("sanctify_tick_ratio", sanctify_tick_ratio))
	shard_count = int(config.get("shard_count", shard_count))
	split_count = int(config.get("split_count", split_count))
	mark_duration = float(config.get("mark_duration", mark_duration))
	amp_lifetime = float(config.get("amp_lifetime", amp_lifetime))
	amp_pulse_interval = float(config.get("amp_pulse_interval", amp_pulse_interval))
	amp_leadership_lifetime_per_point = float(config.get("amp_leadership_lifetime_per_point", amp_leadership_lifetime_per_point))
	amp_leadership_lifetime_cap = float(config.get("amp_leadership_lifetime_cap", amp_leadership_lifetime_cap))
	amp_summon_haste = bool(config.get("amp_summon_haste", amp_summon_haste))
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
	# SCRUM-903: терновая зона Друида (слоу + повторные физ-хиты с капом).
	briar_zone = bool(config.get("briar_zone", briar_zone))
	briar_hit_multiplier = maxf(float(config.get("briar_hit_multiplier", briar_hit_multiplier)), 0.0)
	briar_hit_cap = maxi(int(config.get("briar_hit_cap", briar_hit_cap)), 1)
	briar_slow_multiplier = clampf(float(config.get("briar_slow_multiplier", briar_slow_multiplier)), 0.25, 1.0)
	# SCRUM-903: вороний тотем — самонаводящиеся вороны с AoE-взрывом.
	raven_homing = bool(config.get("raven_homing", raven_homing))
	raven_damage_multiplier = maxf(float(config.get("raven_damage_multiplier", raven_damage_multiplier)), 0.0)
	raven_explosion_radius = maxf(float(config.get("raven_explosion_radius", raven_explosion_radius)), 24.0)
	charge_seconds = float(config.get("charge_seconds", charge_seconds))
	charge_max_multiplier = float(config.get("charge_max_multiplier", charge_max_multiplier))
	crit_shadow_burst_radius = float(config.get("crit_shadow_burst_radius", config.get("dash_on_crit_distance", crit_shadow_burst_radius)))
	return_arc_offset = float(config.get("return_arc_offset", return_arc_offset))
	point_blank_radius = float(config.get("point_blank_radius", point_blank_radius))
	close_contact_radius = float(config.get("close_contact_radius", close_contact_radius))
	dot_crit_snapshot_ratio = float(config.get("dot_crit_snapshot_ratio", dot_crit_snapshot_ratio))
	dot_beam_spread_ratio = float(config.get("dot_beam_spread_ratio", dot_beam_spread_ratio))
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
	# FAN-1031 S1: data-driven кап прямого AoE-взрыва (см. _damage_aoe_projectile_explosion).
	aoe_full_targets = int(config.get("aoe_full_targets", aoe_full_targets))
	aoe_target_diminish = float(config.get("aoe_target_diminish", aoe_target_diminish))
	# FAN-1031 3c(a): data-driven кап пул-канала (тик лужи + leaves_pool-ветка).
	pool_full_targets = int(config.get("pool_full_targets", pool_full_targets))
	pool_target_diminish = float(config.get("pool_target_diminish", pool_target_diminish))
	# FAN-1031 3c(b): data-driven кап STATUS fan-out (крауд-раздача DoT-статусов).
	status_full_targets = int(config.get("status_full_targets", status_full_targets))
	status_target_diminish = float(config.get("status_target_diminish", status_target_diminish))
	# FAN-1031 3c(b2): data-driven кап FALLOFF/ORBIT крауд-fan-out каналов.
	falloff_full_targets = int(config.get("falloff_full_targets", falloff_full_targets))
	falloff_target_diminish = float(config.get("falloff_target_diminish", falloff_target_diminish))
	orbit_full_targets = int(config.get("orbit_full_targets", orbit_full_targets))
	orbit_target_diminish = float(config.get("orbit_target_diminish", orbit_target_diminish))
	# FAN-1031 3c(final): жёсткий кап ШИРИНЫ (coverage) крауд-fan-out каналов.
	aoe_max_targets = int(config.get("aoe_max_targets", aoe_max_targets))
	pool_max_targets = int(config.get("pool_max_targets", pool_max_targets))
	status_max_targets = int(config.get("status_max_targets", status_max_targets))
	orbit_max_targets = int(config.get("orbit_max_targets", orbit_max_targets))
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
	sentry_shot_magazine = int(config.get("sentry_shot_magazine", sentry_shot_magazine))
	drone_orbit_radius = float(config.get("drone_orbit_radius", drone_orbit_radius))
	drone_visual_scale = float(config.get("drone_visual_scale", drone_visual_scale))
	drone_orbit_speed = float(config.get("drone_orbit_speed", drone_orbit_speed))
	drone_contact_radius = float(config.get("drone_contact_radius", drone_contact_radius))
	drone_hit_cooldown = float(config.get("drone_hit_cooldown", drone_hit_cooldown))
	drone_count_threshold = float(config.get("drone_count_threshold", drone_count_threshold))
	drone_count_step = float(config.get("drone_count_step", drone_count_step))
	mine_trigger_radius = float(config.get("mine_trigger_radius", mine_trigger_radius))
	mine_self_arm_delay = float(config.get("mine_self_arm_delay", mine_self_arm_delay))
	mine_active_cap = int(config.get("mine_active_cap", mine_active_cap))
	mine_place_min_distance = float(config.get("mine_place_min_distance", mine_place_min_distance))
	mine_place_max_distance = float(config.get("mine_place_max_distance", mine_place_max_distance))
	deploy_texture_path = str(config.get("deploy_texture_path", deploy_texture_path))
	chain_targets = int(config.get("chain_targets", chain_targets))
	chain_hop_range = float(config.get("chain_hop_range", chain_hop_range))
	chain_burst_ratio = float(config.get("chain_burst_ratio", chain_burst_ratio))
	mirror_damage_ratio = float(config.get("mirror_damage_ratio", mirror_damage_ratio))
	curse_only = bool(config.get("curse_only", curse_only))
	curse_tick_rate = float(config.get("curse_tick_rate", curse_tick_rate))
	curse_tick_multiplier = float(config.get("curse_tick_multiplier", curse_tick_multiplier))
	curse_int_scale = float(config.get("curse_int_scale", curse_int_scale))
	spore_slow_base = float(config.get("spore_slow_base", spore_slow_base))
	spore_slow_max = float(config.get("spore_slow_max", spore_slow_max))
	tip_burst_ratio = float(config.get("tip_burst_ratio", tip_burst_ratio))
	seed_impact_ratio = float(config.get("seed_impact_ratio", seed_impact_ratio))
	close_burst_radius = float(config.get("close_burst_radius", close_burst_radius))
	close_burst_ratio = float(config.get("close_burst_ratio", close_burst_ratio))
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
	if owner_node.has_method("record_weapon_cast"):
		owner_node.call("record_weapon_cast", weapon_id, attack_mode, _event_action_animation_for_mode(), _estimated_windup_duration())
	_emit_weapon_animation_event(owner_node, "windup", _estimated_windup_duration(), direction)

	# SCRUM-603: лечение-от-атаки идёт через per-second бюджет (capped), как drain.
	if heal_percent_on_attack > 0.0 and owner_node.has_method("heal_percent_capped"):
		owner_node.heal_percent_capped(heal_percent_on_attack * ProgressionData.WEAPON_DRAIN_HEAL_MULTIPLIER)
	elif heal_percent_on_attack > 0.0 and owner_node.has_method("heal_percent"):
		owner_node.heal_percent(heal_percent_on_attack * ProgressionData.WEAPON_DRAIN_HEAL_MULTIPLIER)

	_current_charge_multiplier = _charge_multiplier()
	var full_charge_release := charge_seconds > 0.0 and _current_charge_multiplier >= maxf(charge_max_multiplier - 0.01, 1.0)
	_execute_attack_mode(owner_node, target, direction)
	if full_charge_release:
		_charge_time = 0.0
	_current_charge_multiplier = 1.0
	_maybe_fire_rhythm_echo(owner_node, target, direction)
	_maybe_fire_action_echo(owner_node, target, direction)


# SCRUM-961: mode-rework артефакты меняют пейсинг оружия на точке потребления
# (само поле fire_interval пересобирает player._apply_weapon_scaling — не трогаем).
func _fire_interval_artifact_factor() -> float:
	var factor := 1.0
	# FAN-1031 v7 (координаторское решение): priest crowd 1.89 — КАДЕНС-driven, не width.
	if weapon_id == "priest_reliquary":
		# FAN-1031 v9-финал: 1.18→1.08 — ДОСМЯГЧАЕМ каденс-налог (координаторское решение,
		factor *= 1.08  # быстрый бурст-крауд, но каденс-налог досмягчён под random-floor лифт
	if weapon_id == "priest_censer":
		factor *= 1.15  # большой близкий AoE — вторичный крауд-вклад
	if weapon_id == "priest_reliquary" and _owner_mod("reliquary_barrage_mode") > 0.0:
		factor *= 0.75  # «Реликварный залп»: частые залпы вместо лечения
	if weapon_id == "priest_censer" and _owner_mod("censer_vow_mode") > 0.0:
		factor *= 1.35  # «Обет кадила»: реже, но шире и больнее (DPS ≈ паритет)
	if weapon_id == "blast_powder" and _owner_mod("volatile_powder_mode") > 0.0:
		factor *= 0.78  # «Летучая пыль»: быстрый комфортный AoE без облака
	if weapon_id == "elementalist_meteor_core" and _owner_mod("meteor_heart_mode") > 0.0:
		factor *= 1.45  # «Сердце метеора»: самый долгий и жирный пэйофф
	return factor


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


func _spawn_weapon_signature(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	if owner_node == null or direction.length_squared() <= 0.001:
		return
	var release_origin := owner_node.global_position + direction * 26.0
	var radius := maxf(aoe_radius, beam_width * 1.4)
	var signature := AttackVfx.weapon_signature(
		_projectile_parent(),
		release_origin,
		weapon_id,
		radius,
		visual_color,
		direction.angle(),
		null,
		0.0,
		0.58,
		Vector2.ZERO,
		AttackVfx.owner_class_id(owner_node)
	)
	if signature != null:
		_register_effect(signature)


func _exec_aoe_projectile(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_aoe_projectile(owner_node, target, direction)


func _exec_amp(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_amp(owner_node, direction)


func _fire_aoe_projectile(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	# FAN-2238: один бросок несёт ОДИН реагент, соседние броски — разные. Пара
	# снарядов одного каста поэтому не реагирует сама с собой (same-reagent), а
	# несовместимый соседний взрыв даёт реакцию (см. _mark_powder_reagent_impact).
	_powder_reagent_cast = (_powder_reagent_cast + 1) % 2
	var targets := _find_closest_enemies(owner_node, maxi(projectile_count + _extra_projectiles(), 1))
	if targets.is_empty():
		_launch_aoe_projectile(owner_node, null, direction, _powder_reagent_cast)
		return
	for target_node in targets:
		var to_target: Vector2 = target_node.global_position - owner_node.global_position
		var aim := direction if to_target.length_squared() <= 0.001 else to_target.normalized()
		_launch_aoe_projectile(owner_node, target_node, aim, _powder_reagent_cast)


func _quadratic_bezier_point(from_point: Vector2, control: Vector2, to_point: Vector2, t: float) -> Vector2:
	var inv := 1.0 - t
	return from_point * (inv * inv) + control * (2.0 * inv * t) + to_point * (t * t)


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
				# SCRUM-903: терновая зона — слоу + повторные ФИЗИЧЕСКИЕ хиты с
				# капом на врага/зону (не dot-тик; см. _briar_zone_tick).
				if bool(current_weapon.get("briar_zone")):
					current_weapon.call("_briar_zone_tick", current_pool)
				else:
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


func _find_closest_enemies(owner_node: Node2D, count: int) -> Array:
	return TARGET_QUERY.nearest_many(self, owner_node.global_position, attack_range, count)


func _launch_aoe_projectile(owner_node: Node2D, target: Node2D, direction: Vector2, reagent := 0) -> void:
	var target_position: Vector2 = owner_node.global_position + direction * min(attack_range, 360.0)
	if target != null:
		target_position = target.global_position
	elif _owner_uses_cursor_aim(owner_node) and owner_node.has_method("attack_aim_position"):
		target_position = owner_node.call("attack_aim_position", attack_range)

	var projectile := _spawn_projectile_visual(owner_node.global_position + direction * 28.0, target_position - owner_node.global_position)
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
			AttackVfx.orb_burst(current_weapon.call("_projectile_parent"), target_position, aoe_radius, current_weapon.call("_projectile_impact_color"))
			# FAN-2238: реагентный след ставит РЕАЛЬНЫЙ прилёт снаряда; без финала
			# созвездия вызов сразу выходит и базовое оружие не меняется.
			current_weapon.call("_mark_powder_reagent_impact", target_position, reagent)
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


func _heal_owner_from_damage(owner_node: Node2D, dealt_damage: float) -> void:
	if heal_percent_of_damage <= 0.0 or owner_node == null or not is_instance_valid(owner_node):
		return
	if owner_node.get("health") == null or owner_node.get("max_health") == null:
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
	# Overheal is the portion that could not fit under max HP. A per-second heal
	# budget denial is not overheal and must never mint absorb while still hurt.
	var missing_health_before := maxf(float(owner_node.get("max_health")) - float(owner_node.get("health")), 0.0)
	var overflow := 0.0
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
	# Convert only a real max-HP overflow. If the drain budget denied healing and
	# the owner is still hurt, no shield can be minted from the rejected amount.
	if float(owner_node.get("health")) >= float(owner_node.get("max_health")) - 0.001:
		overflow = maxf(heal_amount - missing_health_before, 0.0)
	if overflow > 0.0:
		var overheal_result := _constellation_event("overheal", null, 0.0, {"overheal": overflow})
		if bool(overheal_result.get("triggered", false)) and owner_node.has_method("constellation_set_timed_absorb"):
			var mechanic = owner_node.call("constellation_weapon_mechanic", weapon_id, "potion_overheal_absorb_pool") if owner_node.has_method("constellation_weapon_mechanic") else {}
			var params: Dictionary = (mechanic as Dictionary).get("params", {}) if mechanic is Dictionary else {}
			var cap := clampf(float(params.get("absorb_cap", 22.0)), 0.0, 30.0)
			var source_id := "overheal_%d" % get_instance_id()
			var previous := float(owner_node.call("constellation_timed_absorb", source_id)) if owner_node.has_method("constellation_timed_absorb") else 0.0
			var absorb_gain := overflow * clampf(float(params.get("conversion_ratio", 0.45)), 0.0, 1.0)
			owner_node.call("constellation_set_timed_absorb", source_id, minf(previous + absorb_gain, cap), maxf(float(params.get("duration_seconds", 4.0)), 0.0))


# SCRUM-903: маршрутизация «пульса» деплой-устройства: вороний тотем
# (raven_homing) вместо зонного пульса пускает самонаводящегося ворона;
# остальные ампы (sound_amp и т.п.) пульсируют как прежде.
func _fire_deployable_pulse(owner_node: Node2D, origin: Vector2) -> void:
	if raven_homing:
		_launch_totem_raven(owner_node, origin)
		var strike_result := _constellation_event("totem_pulse", null, 0.0)
		if bool(strike_result.get("triggered", false)):
			var strike_ratio := maxf(float(strike_result.get("damage_multiplier", 1.0)) - 1.0, 0.0)
			_launch_totem_raven(owner_node, origin, strike_ratio, 1.5)
		return
	if weapon_id == "sound_amp":
		var echo_result := _constellation_event("amp_pulse", null, 0.0)
		if bool(echo_result.get("triggered", false)):
			_constellation_instrument_echo(owner_node, origin, echo_result)
	_fire_pulse(owner_node, origin)


func _fire_pulse(owner_node: Node2D, origin: Vector2) -> void:
	if owner_node == null or not is_instance_valid(owner_node):
		return
	var pulse_damage := _rolled_damage(owner_node)
	var bass_result := {"triggered": false}
	if weapon_id == "bass_guitar":
		bass_result = _constellation_event("pulse", TARGET_QUERY.nearest(self, origin, aoe_radius), 0.0, {"constellation_consumer_event": true})
		if bool(bass_result.get("triggered", false)):
			pulse_damage *= _constellation_result_param(bass_result, "damage_ratio", 1.25)
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
			if bool(bass_result.get("triggered", false)):
				var stagger := _constellation_result_param(bass_result, "stagger_seconds", 0.7)
				if TARGET_QUERY.is_epic_displacement_immune(enemy_node):
					stagger *= _constellation_result_param(bass_result, "boss_factor", 0.25)
				StatusEffects.apply_status(enemy_node, "constellation_bass_stagger", {"duration": stagger, "speed_multiplier": 0.35})


func _fire_amp(owner_node: Node2D, direction: Vector2) -> void:
	# SCRUM-961: «Сценический усилитель» продлевает жизнь ампа (+amp_lifetime_bonus,
	# кап деплоя — через amp_cap_bonus в player._apply_weapon_scaling); «Голубой
	# тотем» учащает пульс вороньего тотема (−15% интервала).
	# SCRUM-899: поверх — opt-in саммонер-скейлинг (только sound_amp): Лидерство
	# продлевает uptime ампа, summon_amount учащает пульс (сила через темп).
	var effective_amp_lifetime := amp_lifetime + _owner_mod("amp_lifetime_bonus") + _amp_leadership_lifetime_bonus(owner_node)
	var effective_pulse_interval := amp_pulse_interval
	if amp_summon_haste:
		effective_pulse_interval /= 1.0 + _amp_summon_haste_value(owner_node)
	if weapon_id == "raven_totem" and _owner_mod("raven_pulse_bonus") > 0.0:
		effective_pulse_interval *= 0.85
	_emit_weapon_animation_event(owner_node, "deploy", effective_amp_lifetime, direction, {"pulse_interval": effective_pulse_interval})
	# Деплой: усилитель ставится на землю, живет amp_lifetime секунд и пульсирует
	var alive_amps: Array[Node] = []
	for tracked_amp in _deployed_amps:
		if tracked_amp != null and is_instance_valid(tracked_amp):
			alive_amps.append(tracked_amp)
	_deployed_amps = alive_amps

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
				# SCRUM-903: вороний тотем пускает homing-ворона вместо зонного пульса.
				current_weapon.call("_fire_deployable_pulse", current_owner, current_amp.global_position)
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
	_fire_deployable_pulse(owner_node, amp.global_position)


# SCRUM-897: боссы и элиты сопротивляются контролю — окно паралича срезано
# (POISON_PARALYSIS_BOSS_FACTOR), пермалок невозможен (кап + короткая база).
# SCRUM-909/913: тот же общий резист режет и trait-отброс лука, и паралич капкана.
func _control_resist_factor(enemy_node: Node2D) -> float:
	if enemy_node.is_in_group("bosses") or enemy_node.is_in_group("elite_enemies"):
		return POISON_PARALYSIS_BOSS_FACTOR
	return 1.0


func _release_effect_by_id(effect_id: int) -> void:
	var effect := instance_from_id(effect_id) as Node
	if effect != null:
		_release_effect(effect)


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
