extends Node2D

const TARGET_QUERY := preload("res://scripts/combat_target_query.gd")
const SCENE_CONTRACTS := preload("res://scripts/scene_contracts.gd")
const CONSTELLATION_FINAL_MECHANICS := {
	"homunculus_intercept_death_burst": "summon_death",
	"pack_alpha_pounce_guard": "command",
}
const PACK_GUARD_ABSORB_CAP := 4.0

@export var ally_scene: PackedScene
@export var summon_interval := 4.0
@export var max_summons := 2

@export var weapon_id := "summon_amulet"
@export var damage := 6.0
@export var damage_parameter := "magic_damage"
@export var damage_multiplier := 0.55
@export var fire_interval := 3.0
@export var attack_range := 420.0
@export var command_mode := "attack_target"
@export var ally_visual_id := ""
@export var summon_role := "pack_damage"
@export var summon_health_multiplier := 0.28
@export var summon_speed_multiplier := 1.0
@export var summon_attack_interval := 0.45
@export var summon_lifetime_multiplier := 1.0
@export var summon_control_knockback := 0.0
@export var summon_support_heal_percent := 0.0
@export var summon_role_damage_multiplier := 1.0
@export var summon_aoe_radius := 70.0
@export var summon_aoe_damage_multiplier := 0.55
@export var summon_leash_radius := 520.0

var _cooldown := 0.0
var _command_refresh := 0.0
var _initial_prefill_done := false
var ally_visual_ids: Array[String] = []
# SCRUM-902: случайный ростер призывов (амулет Друида). Каждая запись:
# {visual_id, family: "physical"/"magic", attack_kind: "melee"/"ranged"}.
# Melee-звери бьют физически по площади (урон ← стат damage/Сила), дальние —
# магическим снарядом (урон ← magic_damage/Интеллект): physical- и magic-билды
# усиливают СВОЮ половину стаи. Пустой ростер = легаси-поведение (visual ids).
var summon_roster: Array[Dictionary] = []
var summon_ranged_range := 240.0
var summon_ranged_projectile_speed := 620.0

# SCRUM-902: дальние духи — редкие тяжёлые снаряды (интервал и урон ×2.2,
# per-body DPS равен melee-семье; см. _summon_profile).
const RANGED_CADENCE_SCALE := 2.2
# SCRUM-961 «Гомункул-реактор»: особый юнит вне боевого лимита + таймер его волн.
var _reactor_unit: Node2D = null
var _reactor_pulse_left := 0.0
# SCRUM-946: постоянная пара «танк + кастер» (homunculus_vial).
var summon_pair_mode := false
var pair_tank_visual_id := "homunculus_tank"
var summon_wave_interval := 1.7
var summon_wave_radius := 150.0
var summon_wave_dot_multiplier := 0.35
var summon_wave_dot_interval := 1.0
var summon_wave_stack_cap := 4
var _pair_tank: Node2D = null
var _pair_caster: Node2D = null
# Отдельный флаг «танк был развёрнут»: freed-ссылка в GDScript сравнивается с null
# как равная (freed == null → true), поэтому детект смерти по `_pair_tank != null`
# молча пропускал бы респавн-паузу после queue_free танка.
var _pair_tank_deployed := false
var _pair_tank_respawn_left := 0.0
var _pair_wave_left := 0.0
var _pair_caster_facing := "south"
var _pack_command_target_id := 0
var _pack_command_cooldown_left := 0.0
var _pack_guard_left := 0.0
var _pack_guard_absorb := 0.0

# SCRUM-946: новые PixelLab-спрайты пары (SCRUM-945); старый ally_homunculus.png
# больше не используется — реактор (SCRUM-961) тоже переведён на арт кастера.
const HOMUNCULUS_CASTER_TEXTURE_PATHS := {
	"south": "res://assets/sprites/allies/homunculus_caster_south.png",
	"north": "res://assets/sprites/allies/homunculus_caster_north.png",
	"east": "res://assets/sprites/allies/homunculus_caster_east.png",
	"west": "res://assets/sprites/allies/homunculus_caster_west.png",
}
const HOMUNCULUS_TEXTURE_PATH := "res://assets/sprites/allies/homunculus_caster_south.png"
const REACTOR_PULSE_INTERVAL := 1.6
const REACTOR_WAVE_RADIUS := 140.0
# SCRUM-946: вечный DoT-заряд волны кастера — живёт до смерти носителя.
const CASTER_WAVE_STATUS_ID := "homunculus_caster_dot"
const CASTER_WAVE_PERSIST_SECONDS := 999999.0
# SCRUM-946: плечо кастера у танка и fallback-плечо у Химика (танк мёртв).
const CASTER_TANK_OFFSET := Vector2(42.0, -34.0)
const CASTER_OWNER_FALLBACK_OFFSET := Vector2(64.0, -42.0)


# SCRUM-961: чтение ключа классового артефакта из run_modifiers владельца.
func _owner_mod(key: String, default_value := 0.0) -> float:
	var owner_node := _owner_node()
	if owner_node == null:
		return default_value
	var mods = owner_node.get("run_modifiers")
	if mods is Dictionary:
		return float((mods as Dictionary).get(key, default_value))
	return default_value


func configure_weapon(config: Dictionary) -> void:
	weapon_id = str(config.get("id", weapon_id))
	# SCRUM-644: clamp to a positive floor — a non-positive interval would make
	# _cooldown perpetually <= 0 in _process() and _summon() fire every frame.
	summon_interval = maxf(float(config.get("fire_interval", summon_interval)), 0.05)
	max_summons = int(config.get("max_summons", max_summons))
	damage_parameter = str(config.get("damage_parameter", damage_parameter))
	damage_multiplier = float(config.get("summon_damage_multiplier", damage_multiplier))
	attack_range = float(config.get("attack_range", attack_range))
	command_mode = str(config.get("command_mode", command_mode))
	ally_visual_id = str(config.get("ally_visual_id", ally_visual_id))
	summon_role = str(config.get("summon_role", summon_role))
	summon_health_multiplier = float(config.get("summon_health_multiplier", summon_health_multiplier))
	summon_speed_multiplier = float(config.get("summon_speed_multiplier", summon_speed_multiplier))
	summon_attack_interval = float(config.get("summon_attack_interval", summon_attack_interval))
	summon_lifetime_multiplier = float(config.get("summon_lifetime_multiplier", summon_lifetime_multiplier))
	summon_control_knockback = float(config.get("summon_control_knockback", summon_control_knockback))
	summon_support_heal_percent = float(config.get("summon_support_heal_percent", summon_support_heal_percent))
	summon_role_damage_multiplier = float(config.get("summon_role_damage_multiplier", summon_role_damage_multiplier))
	summon_aoe_radius = float(config.get("summon_aoe_radius", config.get("aoe_radius", summon_aoe_radius)))
	summon_aoe_damage_multiplier = float(config.get("summon_aoe_damage_multiplier", summon_aoe_damage_multiplier))
	summon_leash_radius = float(config.get("summon_leash_radius", summon_leash_radius))
	# SCRUM-946: конфиг пары «танк + кастер».
	summon_pair_mode = bool(config.get("summon_pair_mode", summon_pair_mode))
	pair_tank_visual_id = str(config.get("pair_tank_visual_id", pair_tank_visual_id))
	summon_wave_interval = maxf(float(config.get("summon_wave_interval", summon_wave_interval)), 0.2)
	summon_wave_radius = maxf(float(config.get("summon_wave_radius", summon_wave_radius)), 24.0)
	summon_wave_dot_multiplier = maxf(float(config.get("summon_wave_dot_multiplier", summon_wave_dot_multiplier)), 0.0)
	summon_wave_dot_interval = maxf(float(config.get("summon_wave_dot_interval", summon_wave_dot_interval)), 0.2)
	summon_wave_stack_cap = maxi(int(config.get("summon_wave_stack_cap", summon_wave_stack_cap)), 1)
	ally_visual_ids.clear()
	var configured_visuals: Array = config.get("ally_visual_ids", [])
	for visual_id in configured_visuals:
		ally_visual_ids.append(str(visual_id))
	# SCRUM-902: ростер призраков — источник выбора визуала/семьи урона.
	summon_roster.clear()
	var configured_roster: Array = config.get("summon_roster", [])
	for entry in configured_roster:
		if entry is Dictionary:
			summon_roster.append(entry as Dictionary)
	summon_ranged_range = maxf(float(config.get("summon_ranged_range", summon_ranged_range)), 60.0)
	summon_ranged_projectile_speed = maxf(float(config.get("summon_ranged_projectile_speed", summon_ranged_projectile_speed)), 120.0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("player_weapons")


func _process(delta: float) -> void:
	_pack_command_cooldown_left = maxf(_pack_command_cooldown_left - delta, 0.0)
	_tick_pack_guard(delta)
	_cooldown -= delta
	_command_refresh -= delta
	# SCRUM-946: пара «танк + кастер» ведёт популяцию сама (без generic-лимита
	# и прифилла) — постоянные юниты вместо потока временных саммонов.
	if summon_pair_mode:
		_initial_prefill_done = true
		if _command_refresh <= 0.0:
			_command_existing_summons()
			_command_refresh = 0.25
		_update_reactor_homunculus(delta)
		_update_homunculus_pair(delta)
		return
	if not _initial_prefill_done:
		_prefill_starting_summons()
	if _command_refresh <= 0.0:
		_command_existing_summons()
		_command_refresh = 0.25
	_update_reactor_homunculus(delta)
	if _cooldown > 0.0:
		return

	_summon()
	_cooldown = summon_interval


func _prefill_starting_summons() -> void:
	_initial_prefill_done = true
	var owner_node := _owner_node()
	if owner_node == null:
		return
	# SCRUM-902: ростер-оружие (амулет Друида) стартует с ПОЛНОЙ стаей — AC
	# «минимум 5 активных призывов без прокачки» выполняется с первого кадра боя.
	# Легаси-оружия без ростера сохраняют прежний прифилл половины лимита.
	var target_count := max_summons if not summon_roster.is_empty() else maxi(int(ceil(float(max_summons) * 0.5)), 1)
	while _active_weapon_summons(owner_node).size() < mini(target_count, max_summons):
		if not _summon(false):
			break
	_cooldown = summon_interval


func _summon(play_cast_animation := true) -> bool:
	if ally_scene == null:
		return false

	var owner_node := _owner_node()
	if owner_node == null:
		return false

	if _active_weapon_summons(owner_node).size() >= max_summons:
		return false

	var ally := SCENE_CONTRACTS.instantiate_node_2d(ally_scene, "SummonerWeapon ally spawn")
	if ally == null:
		return false
	var parent := owner_node.get_tree().current_scene
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		parent = owner_node.get_parent()
	if parent == null:
		parent = owner_node.get_tree().root

	parent.add_child(ally)
	ally.add_to_group("player_weapon_effects")
	ally.set_meta("summon_weapon_owner", get_instance_id())
	# SCRUM-902: выбор из случайного ростера (или легаси-выбор по visual ids).
	var roster_entry := _selected_roster_entry()
	var selected_visual_id := str(roster_entry.get("visual_id", "")) if not roster_entry.is_empty() else _selected_ally_visual_id()
	# SCRUM-961 «Зов волков»: состав стаи смещается к волкам-melee.
	var pack_bias := weapon_id == "summon_amulet" and _owner_mod("pack_wolf_bias") > 0.0
	if pack_bias and randf() < 0.8:
		if summon_roster.is_empty():
			selected_visual_id = "druid_beast"
		else:
			roster_entry = _wolf_roster_entry()
			selected_visual_id = str(roster_entry.get("visual_id", selected_visual_id))
	if ally.has_method("set_visual_id"):
		ally.call("set_visual_id", selected_visual_id)
	else:
		ally.set("ally_visual_id", selected_visual_id)
	ally.set("owner_node", owner_node)
	ally.set("command_mode", command_mode)
	var angle := randf() * TAU
	ally.global_position = owner_node.global_position + Vector2.RIGHT.rotated(angle) * 48.0
	var profile := _summon_profile(owner_node, roster_entry)
	# SCRUM-961 «Зов волков»: ближние (melee) духи рвут сильнее (+20% урона).
	if pack_bias and (selected_visual_id == "druid_beast" or str(roster_entry.get("attack_kind", "")) == "melee"):
		profile["damage"] = float(profile.get("damage", 1.0)) * 1.2
	if ally.has_method("set_combat_profile"):
		ally.call("set_combat_profile", profile)
	else:
		for key in profile.keys():
			if ally.get(str(key)) != null:
				ally.set(str(key), profile[key])

	if play_cast_animation and owner_node.has_method("play_action_animation"):
		owner_node.play_action_animation("cast", ally.global_position - owner_node.global_position)
	_command_existing_summons()
	return true


# SCRUM-902: выбор случайной записи ростера (пустой ростер = легаси-путь).
func _selected_roster_entry() -> Dictionary:
	if summon_roster.is_empty():
		return {}
	return summon_roster[randi() % summon_roster.size()]


# SCRUM-961 «Зов волков» поверх ростера SCRUM-902: смещение к волку (fallback —
# первый melee-зверь ростера, затем первая запись).
func _wolf_roster_entry() -> Dictionary:
	var first_melee := {}
	for entry in summon_roster:
		if str(entry.get("visual_id", "")).contains("wolf"):
			return entry
		if first_melee.is_empty() and str(entry.get("attack_kind", "")) == "melee":
			first_melee = entry
	if not first_melee.is_empty():
		return first_melee
	return summon_roster[0] if not summon_roster.is_empty() else {}


func _summon_profile(owner_node: Node, roster_entry: Dictionary = {}) -> Dictionary:
	var parameters_raw = owner_node.get("derived_parameters")
	var parameters: Dictionary = parameters_raw if parameters_raw is Dictionary else {}
	var stats_raw = owner_node.get("stats")
	var stats: Dictionary = stats_raw if stats_raw is Dictionary else {}
	var leadership := float(stats.get("leadership", 0.0))
	var knowledge := float(stats.get("knowledge", 0.0))
	var intelligence := float(stats.get("intelligence", 0.0))
	var energy := float(stats.get("energy", 0.0))
	var summon_amount := float(parameters.get("summon_amount", 0.0))
	# SCRUM-902: семья урона записи ростера выбирает СВОЙ стат: physical-звери
	# растут от damage (Сила), magic-духи — от magic_damage (Интеллект). Без
	# ростера — прежний damage_parameter оружия (легаси-саммоны не затронуты).
	var family := str(roster_entry.get("family", ""))
	var family_parameter := damage_parameter
	match family:
		"physical":
			family_parameter = "damage"
		"magic":
			family_parameter = "magic_damage"
	var base_damage := float(parameters.get(family_parameter, parameters.get("damage", damage)))
	var constellation_flat := 0.0
	var constellation_geometry := 1.0
	if owner_node.has_method("constellation_weapon_amount"):
		constellation_flat = float(owner_node.call("constellation_weapon_amount", weapon_id, "weapon_damage_flat"))
	if owner_node.has_method("constellation_weapon_geometry_multiplier"):
		constellation_geometry = float(owner_node.call("constellation_weapon_geometry_multiplier", weapon_id))
	base_damage += constellation_flat
	# SCRUM-546: Лидерство — главный драйвер урона саммонов (см.
	# progression_data._budget_summon_role_damage_factor — тот же коэффициент/потолок).
	var leadership_damage := 1.0 + minf(leadership * 0.060, 1.15)
	var attribute_damage := 1.0 + minf(summon_amount * 0.016 + knowledge * 0.004 + intelligence * 0.004 + energy * 0.003, 0.40)
	var role_damage := summon_role_damage_multiplier * leadership_damage * attribute_damage
	var summon_haste := minf(summon_amount * 0.014 + leadership * 0.006, 0.30)
	var summon_bulk := minf(leadership * 0.045 + summon_amount * 0.010, 0.75)
	# SCRUM-505: рой чистит толпу (20t-ось) тем шире, чем дальше ПРОКАЧАН забег.
	# КРИТИЧНО для lvl1-инварианта: драйвер = (level-1), РОВНО 0 на 1-м уровне (стартовый
	# баланс НЕ трогаем), растёт к lvl20. summon_amount/Лидерство как драйвер НЕ годятся:
	# summon_amount = leadership + … (derived_parameters:936), а базовое Лидерство
	# друида/инженера 9-10 → раздуло бы lvl1. Это РАНТАЙМ-покрытие splash — budget его
	# не моделирует (per-summon DPS-формула/haste остаются зеркалом budget, инвариант цел).
	var level_progress := maxf(float(owner_node.get("level")) - 1.0, 0.0) if owner_node.get("level") != null else 0.0
	var summon_crowd_scale := 1.0 + minf(level_progress * 0.275, 5.20)
	var summon_radius := summon_aoe_radius * constellation_geometry * (1.0 + minf(summon_amount * 0.006 + leadership * 0.004, 0.18)) * sqrt(summon_crowd_scale)
	var summon_splash_damage := summon_aoe_damage_multiplier * summon_crowd_scale
	var owner_max_hp := float(owner_node.get("max_health")) if owner_node.get("max_health") != null else 80.0
	var run_modifiers_raw = owner_node.get("run_modifiers")
	var run_modifiers: Dictionary = run_modifiers_raw if run_modifiers_raw is Dictionary else {}
	var meta_damage_mult := 1.0
	var meta_health_mult := 1.0
	var taunt_pulse := false
	if weapon_id == "homunculus_vial":
		meta_damage_mult *= 1.0 + float(run_modifiers.get("homunculus_power_mult", 0.0))
		meta_health_mult *= 1.0 + float(run_modifiers.get("homunculus_power_mult", 0.0))
		# SCRUM-961 «Гомункул-танк»: здоровяк (+60% HP) с периодической провокацией
		# (taunt-пульс — в ally_minion по образцу bastion_taunt игрока).
		if float(run_modifiers.get("homunculus_taunt", 0.0)) > 0.0:
			meta_health_mult *= 1.6
			taunt_pulse = true
	if weapon_id == "summon_amulet":
		meta_damage_mult *= 1.0 + float(run_modifiers.get("pet_damage_mult", 0.0))
	# SCRUM-902: дальние духи держат дистанцию снаряда (масштаб от attack_range
	# оружия относительно базы 420) и бьют одиночным магическим снарядом — их
	# splash-покрытие выключено (melee-звери остаются AoE-осью стаи).
	var attack_kind := str(roster_entry.get("attack_kind", "melee"))
	var profile_attack_range := maxf(float(parameters.get("attack_range", attack_range)) * constellation_geometry * 0.18, 24.0)
	# SCRUM-902: дальние духи бьют РЕЖЕ, но ТЯЖЕЛЕЕ (×RANGED_CADENCE_SCALE к
	# интервалу И к урону хита) — per-body DPS семьи равен melee-темпу, поэтому
	# budget-зеркало (_budget_summon_dps) остаётся композиционно-взвешенным по
	# семьям без отдельной модели темпа.
	var cadence_scale := 1.0
	if attack_kind == "ranged":
		profile_attack_range = maxf(summon_ranged_range * constellation_geometry * (float(parameters.get("attack_range", attack_range)) / maxf(attack_range, 1.0)), 120.0)
		cadence_scale = RANGED_CADENCE_SCALE
	var profile := {
		"damage": maxf(base_damage * damage_multiplier * role_damage * meta_damage_mult * cadence_scale, 1.0),
		"move_speed": 230.0 * summon_speed_multiplier * (1.0 + minf(leadership * 0.010, 0.28)),
		"attack_range": profile_attack_range,
		"attack_interval": maxf(summon_attack_interval * cadence_scale / (1.0 + summon_haste), 0.18),
		"lifetime": 12.0 * summon_lifetime_multiplier * (1.0 + minf(leadership * 0.026, 0.48)),
		"max_health": owner_max_hp * summon_health_multiplier * (1.0 + summon_bulk) * meta_health_mult,
		"summon_role": summon_role,
		"control_knockback": summon_control_knockback,
		"support_heal_percent": summon_support_heal_percent,
		"aoe_radius": summon_radius if attack_kind != "ranged" else 0.0,
		"aoe_damage_multiplier": summon_splash_damage,
		"leash_radius": summon_leash_radius,
		"taunt_pulse": taunt_pulse,
		# SCRUM-902: семья/вид атаки записи ростера (ally_minion).
		"damage_family": family if family != "" else ("magic" if damage_parameter == "magic_damage" else "physical"),
		"attack_kind": attack_kind,
		"ranged_projectile_speed": summon_ranged_projectile_speed,
		"constellation_owner_instance_id": owner_node.get_instance_id(),
		"constellation_weapon_id": weapon_id,
	}
	if weapon_id == "homunculus_vial" and owner_node.has_method("constellation_weapon_mechanic"):
		var mechanic_raw = owner_node.call("constellation_weapon_mechanic", weapon_id, "homunculus_intercept_death_burst")
		if mechanic_raw is Dictionary and not (mechanic_raw as Dictionary).is_empty():
			var final_params: Dictionary = (mechanic_raw as Dictionary).get("params", {})
			profile["constellation_intercepts_left"] = maxi(int(final_params.get("intercepts_per_summon", 1)), 0)
			profile["constellation_intercept_ratio"] = clampf(float(final_params.get("intercept_ratio", 0.30)), 0.0, 0.80)
			profile["constellation_death_burst_ratio"] = clampf(float(final_params.get("death_burst_damage_ratio", 0.42)), 0.0, 1.0)
	return profile


# SCRUM-961 «Гомункул-реактор»: второй особый гомункул — неуязвимый реактор.
# НЕ занимает боевой лимит (не в группе allies, не считается _active_weapon_summons),
# не атакует; каждые 1.6с волна r140 вешает стак DoT (0.8/тик, кап 3) на врагов.
func _update_reactor_homunculus(delta: float) -> void:
	if weapon_id != "homunculus_vial" or _owner_mod("homunculus_reactor") <= 0.0:
		return
	var owner_node := _owner_node()
	if owner_node == null:
		return
	if _reactor_unit == null or not is_instance_valid(_reactor_unit):
		_reactor_unit = _spawn_reactor_unit(owner_node)
		_reactor_pulse_left = REACTOR_PULSE_INTERVAL
		if _reactor_unit == null:
			return
	# Реактор дрейфует за владельцем на фиксированном плече.
	var anchor := owner_node.global_position + Vector2(64.0, -42.0)
	_reactor_unit.global_position = _reactor_unit.global_position.lerp(anchor, minf(delta * 3.0, 1.0))
	_reactor_pulse_left -= delta
	if _reactor_pulse_left > 0.0:
		return
	_reactor_pulse_left = REACTOR_PULSE_INTERVAL
	AttackVfx.ring_pulse(_reactor_unit.get_parent(), _reactor_unit.global_position, REACTOR_WAVE_RADIUS, Color(0.55, 0.95, 0.45, 0.34), false)
	for enemy in TARGET_QUERY.in_radius(self, _reactor_unit.global_position, REACTOR_WAVE_RADIUS):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		StatusEffects.apply_status(enemy_node, "reactor_homunculus_dot", {
			"duration": 3.4,
			"dot_damage": 0.8,
			"dot_interval": 1.0,
			"stack_mode": "add",
			"max_stacks": 3,
			"marker_color": Color(0.55, 0.95, 0.45, 1.0),
		})


func _spawn_reactor_unit(owner_node: Node2D) -> Node2D:
	var parent := owner_node.get_tree().current_scene
	if parent == null or not is_instance_valid(parent):
		parent = owner_node.get_parent()
	if parent == null:
		return null
	var reactor := Node2D.new()
	reactor.name = "ReactorHomunculus"
	reactor.z_index = 5
	var visual := Sprite2D.new()
	visual.texture = load(HOMUNCULUS_TEXTURE_PATH) as Texture2D
	visual.modulate = Color(0.65, 1.0, 0.60, 0.85)
	visual.scale = Vector2.ONE * 0.80
	reactor.add_child(visual)
	parent.add_child(reactor)
	reactor.add_to_group("player_weapon_effects")
	reactor.global_position = owner_node.global_position + Vector2(64.0, -42.0)
	return reactor


# ============================ SCRUM-946: пара гомункулов ============================
# Постоянная пара: ТАНК (смертен, 4x max HP Химика, таунт-пульсы — враги грызут
# его; после смерти переспавнивается через summon_interval) и КАСТЕР (неуязвимый
# Node2D-эффект вне групп allies/боевого лимита — аггро не собирает и урона не
# принимает; ходит рядом с танком, fallback — плечо Химика; каждые
# summon_wave_interval волной вешает ВЕЧНЫЙ DoT-заряд, кап summon_wave_stack_cap).
# Таймера жизни нет ни у одного из пары — только танк можно убить.
func _update_homunculus_pair(delta: float) -> void:
	if not summon_pair_mode:
		return
	var owner_node := _owner_node()
	if owner_node == null:
		return
	# --- танк: жив / переспавн через summon_interval после смерти -----------------
	if not _pair_tank_alive():
		if _pair_tank_deployed:
			# Танк только что умер/освобождён — таймер респавна; таунт спадает сам
			# (мёртвый владелец bastion_taunt не резолвится в enemy._taunt_target).
			_pair_tank = null
			_pair_tank_deployed = false
			_pair_tank_respawn_left = maxf(summon_interval, 0.05)
		_pair_tank_respawn_left -= delta
		if _pair_tank_respawn_left <= 0.0:
			_pair_tank = _spawn_pair_tank(owner_node)
			_pair_tank_deployed = _pair_tank != null and is_instance_valid(_pair_tank)
	# --- кастер: вечен, следует за танком (fallback — за Химиком) ------------------
	if _pair_caster == null or not is_instance_valid(_pair_caster):
		_pair_caster = _spawn_pair_caster(owner_node)
		_pair_wave_left = summon_wave_interval
		if _pair_caster == null:
			return
	var anchor := _pair_caster_anchor(owner_node)
	var previous_position := _pair_caster.global_position
	_pair_caster.global_position = _pair_caster.global_position.lerp(anchor, minf(delta * 3.2, 1.0))
	_update_pair_caster_facing(_pair_caster.global_position - previous_position)
	_pair_wave_left -= delta
	if _pair_wave_left > 0.0:
		return
	_pair_wave_left = summon_wave_interval
	_fire_caster_wave(owner_node)


func _pair_tank_alive() -> bool:
	if _pair_tank == null or not is_instance_valid(_pair_tank) or _pair_tank.is_queued_for_deletion():
		return false
	var health_value = _pair_tank.get("health")
	return health_value == null or float(health_value) > 0.0


func _spawn_pair_tank(owner_node: Node2D) -> Node2D:
	if ally_scene == null:
		return null
	var tank := SCENE_CONTRACTS.instantiate_node_2d(ally_scene, "SummonerWeapon pair tank spawn")
	if tank == null:
		return null
	var parent := owner_node.get_tree().current_scene
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		parent = owner_node.get_parent()
	if parent == null:
		parent = owner_node.get_tree().root
	parent.add_child(tank)
	tank.add_to_group("player_weapon_effects")
	tank.set_meta("summon_weapon_owner", get_instance_id())
	tank.set_meta("homunculus_pair_role", "tank")
	if tank.has_method("set_visual_id"):
		tank.call("set_visual_id", pair_tank_visual_id)
	else:
		tank.set("ally_visual_id", pair_tank_visual_id)
	tank.set("owner_node", owner_node)
	tank.set("command_mode", command_mode)
	tank.global_position = owner_node.global_position + Vector2.RIGHT.rotated(randf() * TAU) * 48.0
	var profile := _summon_profile(owner_node)
	# Танк-фантазия: РОВНО 4x max HP Химика (summon_health_multiplier=4.0) ×
	# мета-артефакты (homunculus_power_mult / «Гомункул-танк»); leadership-bulk
	# generic-саммонов сюда не подмешиваем — 4x и есть его «броня».
	var owner_max_hp := float(owner_node.get("max_health")) if owner_node.get("max_health") != null else 80.0
	var meta_health_mult := float(profile.get("max_health", owner_max_hp)) / maxf(owner_max_hp * summon_health_multiplier * (1.0 + _profile_summon_bulk(owner_node)), 0.001)
	profile["max_health"] = owner_max_hp * summon_health_multiplier * meta_health_mult
	profile["lifetime"] = 1.0e9  # без таймера жизни: пара постоянна (SCRUM-946)
	profile["taunt_pulse"] = true  # таунт — базовое поведение танка пары
	if tank.has_method("set_combat_profile"):
		tank.call("set_combat_profile", profile)
	else:
		for key in profile.keys():
			if tank.get(str(key)) != null:
				tank.set(str(key), profile[key])
	if owner_node.has_method("play_action_animation"):
		owner_node.play_action_animation("cast", tank.global_position - owner_node.global_position)
	_command_existing_summons()
	return tank


# Изолированный пересчёт leadership-bulk generic-профиля (зеркало _summon_profile),
# чтобы вычесть его из HP танка и оставить чистые 4x × мета-артефакты.
func _profile_summon_bulk(owner_node: Node) -> float:
	var stats_raw = owner_node.get("stats")
	var stats: Dictionary = stats_raw if stats_raw is Dictionary else {}
	var parameters_raw = owner_node.get("derived_parameters")
	var parameters: Dictionary = parameters_raw if parameters_raw is Dictionary else {}
	var leadership := float(stats.get("leadership", 0.0))
	var summon_amount := float(parameters.get("summon_amount", 0.0))
	return minf(leadership * 0.045 + summon_amount * 0.010, 0.75)


func _spawn_pair_caster(owner_node: Node2D) -> Node2D:
	var parent := owner_node.get_tree().current_scene
	if parent == null or not is_instance_valid(parent):
		parent = owner_node.get_parent()
	if parent == null:
		return null
	var caster := Node2D.new()
	caster.name = "HomunculusCaster"
	caster.z_index = 5
	caster.set_meta("homunculus_pair_role", "caster")
	var visual := Sprite2D.new()
	visual.name = "CasterVisual"
	visual.texture = load(str(HOMUNCULUS_CASTER_TEXTURE_PATHS["south"])) as Texture2D
	caster.add_child(visual)
	parent.add_child(caster)
	caster.add_to_group("player_weapon_effects")
	caster.global_position = _pair_caster_anchor(owner_node)
	_pair_caster_facing = "south"
	return caster


func _pair_caster_anchor(owner_node: Node2D) -> Vector2:
	if _pair_tank_alive():
		return _pair_tank.global_position + CASTER_TANK_OFFSET
	# Задокументированный fallback: танк мёртв — кастер держится у плеча Химика.
	return owner_node.global_position + CASTER_OWNER_FALLBACK_OFFSET


# 4-направленный статичный арт кастера (PixelLab, SCRUM-945): выбираем кадр по
# доминирующей оси дрейфа; стоя на месте — сохраняем последний ракурс.
func _update_pair_caster_facing(motion: Vector2) -> void:
	if _pair_caster == null or not is_instance_valid(_pair_caster):
		return
	if motion.length_squared() < 1.0:
		return
	var facing := "south"
	if absf(motion.x) >= absf(motion.y):
		facing = "east" if motion.x >= 0.0 else "west"
	else:
		facing = "south" if motion.y >= 0.0 else "north"
	if facing == _pair_caster_facing:
		return
	_pair_caster_facing = facing
	var visual := _pair_caster.get_node_or_null("CasterVisual") as Sprite2D
	if visual != null:
		visual.texture = load(str(HOMUNCULUS_CASTER_TEXTURE_PATHS.get(facing, HOMUNCULUS_CASTER_TEXTURE_PATHS["south"]))) as Texture2D


# Волна кастера: вечный периодический заряд (stack add до summon_wave_stack_cap).
# Тик = dot_damage Химика × summon_wave_dot_multiplier; trait «Катализатор»
# (+50% периодики) запекается через StatusEffects.apply_status_from(владелец).
func _fire_caster_wave(owner_node: Node2D) -> void:
	if _pair_caster == null or not is_instance_valid(_pair_caster) or not _pair_caster.is_inside_tree():
		return
	var parameters_raw = owner_node.get("derived_parameters")
	var dot_damage := 2.0
	if parameters_raw is Dictionary:
		dot_damage = maxf(float((parameters_raw as Dictionary).get("dot_damage", 2.0)), 1.0)
	var wave_tick := maxf(dot_damage * summon_wave_dot_multiplier, 0.30)
	AttackVfx.ring_pulse(_pair_caster.get_parent(), _pair_caster.global_position, summon_wave_radius, Color(0.55, 0.95, 0.45, 0.34), false)
	for enemy in TARGET_QUERY.in_radius(self, _pair_caster.global_position, summon_wave_radius):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		StatusEffects.apply_status_from(owner_node, enemy_node, CASTER_WAVE_STATUS_ID, {
			"duration": CASTER_WAVE_PERSIST_SECONDS,
			"dot_damage": wave_tick,
			"dot_interval": summon_wave_dot_interval,
			"stack_mode": "add",
			"max_stacks": summon_wave_stack_cap,
			"marker_color": Color(0.55, 0.95, 0.45, 1.0),
		})


func _selected_ally_visual_id() -> String:
	if not ally_visual_ids.is_empty():
		return ally_visual_ids[randi() % ally_visual_ids.size()]
	if not ally_visual_id.is_empty():
		return ally_visual_id
	match weapon_id:
		"homunculus_vial":
			# SCRUM-946: и generic-путь (прямой вызов _summon в тестах) идёт на
			# новый арт танка — легаси ally_homunculus.png больше не используется.
			return pair_tank_visual_id
		"summon_amulet":
			return "druid_beast" if randf() < 0.5 else "druid_pack_spirit"
		"leadership_echo":
			return "leadership_echo"
	return "druid_beast"


func _command_existing_summons() -> void:
	var owner_node := _owner_node()
	if owner_node == null:
		return
	var owned_allies := _owned_allies(owner_node)
	var targets := _target_candidates(owner_node, max(owned_allies.size() * 3, 6))
	_dispatch_constellation_pack_command(owner_node, owned_allies, targets)
	var assigned_damage := {}
	var assigned_counts := {}
	for ally in get_tree().get_nodes_in_group("allies"):
		var ally_node := ally as Node2D
		if ally_node == null or not is_instance_valid(ally_node):
			continue
		if not _is_owned_weapon_summon(ally_node, owner_node):
			continue
		_command_ally(ally_node, owner_node, targets, assigned_damage, assigned_counts)


func _constellation_mechanic(owner_node: Node, mechanic_id: String) -> Dictionary:
	if owner_node == null or not owner_node.has_method("constellation_weapon_mechanic"):
		return {}
	var raw = owner_node.call("constellation_weapon_mechanic", weapon_id, mechanic_id)
	return raw if raw is Dictionary else {}


func _dispatch_constellation_pack_command(owner_node: Node2D, owned_allies: Array[Node2D], targets: Array) -> Dictionary:
	if weapon_id != "summon_amulet" or owned_allies.is_empty() or targets.is_empty() or _pack_command_cooldown_left > 0.0:
		return {"triggered": false}
	var mechanic := _constellation_mechanic(owner_node, "pack_alpha_pounce_guard")
	if mechanic.is_empty():
		return {"triggered": false}
	var target := targets[0] as Node2D
	if target == null or not is_instance_valid(target):
		return {"triggered": false}
	var target_id := target.get_instance_id()
	if target_id == _pack_command_target_id and _pack_command_cooldown_left > 0.0:
		return {"triggered": false}
	var result := {"valid": true, "triggered": false}
	if owner_node.has_method("constellation_weapon_event"):
		var raw = owner_node.call("constellation_weapon_event", weapon_id, "command", {"pack_size": owned_allies.size()}, target)
		if raw is Dictionary:
			result = raw
	if not bool(result.get("triggered", false)):
		return result
	var params: Dictionary = mechanic.get("params", {})
	var pounce_ratio := clampf(float(params.get("pounce_damage_ratio", 0.5)), 0.0, 1.0)
	var alpha := owned_allies[0]
	if alpha != null and is_instance_valid(alpha) and alpha.has_method("constellation_alpha_pounce"):
		alpha.call("constellation_alpha_pounce", target, pounce_ratio)
	_pack_command_target_id = target_id
	_pack_command_cooldown_left = maxf(float(params.get("guard_seconds", 1.2)), 0.20)
	_apply_pack_guard(owner_node, float(params.get("guard_seconds", 1.2)))
	return result


func _apply_pack_guard(owner_node: Node, duration: float) -> void:
	if owner_node.has_method("constellation_set_timed_absorb"):
		_pack_guard_absorb = float(owner_node.call("constellation_set_timed_absorb", "pack_guard_%d" % get_instance_id(), PACK_GUARD_ABSORB_CAP, duration))
	_pack_guard_left = maxf(duration, 0.0)


func _tick_pack_guard(delta: float) -> void:
	if _pack_guard_absorb <= 0.0:
		return
	_pack_guard_left = maxf(_pack_guard_left - delta, 0.0)
	if _pack_guard_left > 0.0:
		return
	var owner_node := _owner_node()
	if owner_node != null and owner_node.has_method("constellation_remove_timed_absorb"):
		owner_node.call("constellation_remove_timed_absorb", "pack_guard_%d" % get_instance_id())
	_pack_guard_absorb = 0.0


func constellation_pack_state() -> Dictionary:
	return {"target_id": _pack_command_target_id, "command_cooldown": _pack_command_cooldown_left, "guard_absorb": _pack_guard_absorb, "guard_left": _pack_guard_left}


func _command_ally(ally: Node2D, owner_node: Node2D, targets: Array = [], assigned_damage: Dictionary = {}, assigned_counts: Dictionary = {}) -> void:
	if ally == null or not is_instance_valid(ally):
		return
	ally.set("command_mode", command_mode)
	ally.set("owner_node", owner_node)
	var target := _best_group_target(ally, owner_node, targets, assigned_damage, assigned_counts)
	if target != null:
		ally.set("command_target", target)
	else:
		ally.set("command_target", null)


func _owned_allies(owner_node: Node2D) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for ally in get_tree().get_nodes_in_group("allies"):
		var ally_node := ally as Node2D
		if ally_node == null or not is_instance_valid(ally_node):
			continue
		if _is_owned_weapon_summon(ally_node, owner_node):
			result.append(ally_node)
	return result


func _active_weapon_summons(owner_node: Node2D) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for ally in get_tree().get_nodes_in_group("allies"):
		var ally_node := ally as Node2D
		if ally_node == null or not is_instance_valid(ally_node) or ally_node.is_queued_for_deletion():
			continue
		if _is_owned_weapon_summon(ally_node, owner_node):
			result.append(ally_node)
	return result


func _is_owned_weapon_summon(ally_node: Node2D, owner_node: Node2D) -> bool:
	if ally_node.get("owner_node") != owner_node:
		return false
	if not ally_node.has_meta("summon_weapon_owner"):
		return false
	return int(ally_node.get_meta("summon_weapon_owner")) == get_instance_id()


func _target_candidates(owner_node: Node2D, count: int) -> Array:
	if owner_node.has_method("attack_aim_mode") and str(owner_node.call("attack_aim_mode")) == "cursor":
		var origin: Vector2 = owner_node.call("attack_aim_position", attack_range) if owner_node.has_method("attack_aim_position") else owner_node.global_position
		var cursor_targets := TARGET_QUERY.nearest_many(self, origin, minf(attack_range, summon_leash_radius), count)
		if not cursor_targets.is_empty():
			return cursor_targets
	return TARGET_QUERY.nearest_many(self, owner_node.global_position, summon_leash_radius, count)


func _best_group_target(ally: Node2D, owner_node: Node2D, targets: Array, assigned_damage: Dictionary, assigned_counts: Dictionary = {}) -> Node2D:
	if targets.is_empty():
		return TARGET_QUERY.nearest(self, owner_node.global_position, summon_leash_radius)
	var best_target: Node2D = null
	var best_score := INF
	for target_candidate in targets:
		var target := target_candidate as Node2D
		if target == null or not is_instance_valid(target):
			continue
		if owner_node.global_position.distance_to(target.global_position) > summon_leash_radius:
			continue
		var target_id := target.get_instance_id()
		var health := _enemy_health(target)
		var already_assigned := float(assigned_damage.get(target_id, 0.0))
		if already_assigned >= health * 1.10:
			continue
		var distance_score := ally.global_position.distance_squared_to(target.global_position)
		var owner_score := owner_node.global_position.distance_squared_to(target.global_position) * 0.20
		var overkill_pressure := (already_assigned / maxf(health, 1.0)) * 180000.0
		# SCRUM-902: давление РАСПРЕДЕЛЕНИЯ — каждый уже назначенный на цель
		# призыв дорожает как ~350px дистанции, поэтому при нескольких валидных
		# целях стая расползается по паку, а не догпайлит ближайшего; при
		# единственной цели штраф не меняет выбор (все идут в неё).
		var spread_pressure := float(assigned_counts.get(target_id, 0)) * 120000.0
		var score := distance_score + owner_score + overkill_pressure + spread_pressure
		if score < best_score:
			best_score = score
			best_target = target
	if best_target != null:
		var ally_damage := _ally_expected_damage(ally)
		var best_id := best_target.get_instance_id()
		assigned_damage[best_id] = float(assigned_damage.get(best_id, 0.0)) + ally_damage
		assigned_counts[best_id] = int(assigned_counts.get(best_id, 0)) + 1
	return best_target


func _enemy_health(enemy: Node2D) -> float:
	var health_value = enemy.get("health")
	if health_value != null:
		return maxf(float(health_value), 1.0)
	var max_health_value = enemy.get("max_health")
	if max_health_value != null:
		return maxf(float(max_health_value), 1.0)
	return 20.0


func _ally_expected_damage(ally: Node2D) -> float:
	var ally_damage = ally.get("damage")
	if ally_damage == null:
		return maxf(damage, 1.0)
	return maxf(float(ally_damage) * 1.6, 1.0)


func _owner_node() -> CharacterBody2D:
	var parent_node := get_parent()
	while parent_node != null:
		if parent_node is CharacterBody2D:
			return parent_node
		parent_node = parent_node.get_parent()
	return null
