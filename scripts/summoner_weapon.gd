extends Node2D

const TARGET_QUERY := preload("res://scripts/combat_target_query.gd")

@export var ally_scene: PackedScene
@export var summon_interval := 4.0
@export var max_summons := 2

@export var weapon_id := "summon_amulet"
@export var damage := 6.0
@export var damage_parameter := "sound_wave_damage"
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
var ally_visual_ids: Array[String] = []


func configure_weapon(config: Dictionary) -> void:
	weapon_id = str(config.get("id", weapon_id))
	summon_interval = float(config.get("fire_interval", summon_interval))
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
	ally_visual_ids.clear()
	var configured_visuals: Array = config.get("ally_visual_ids", [])
	for visual_id in configured_visuals:
		ally_visual_ids.append(str(visual_id))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("player_weapons")


func _process(delta: float) -> void:
	_cooldown -= delta
	_command_refresh -= delta
	if _command_refresh <= 0.0:
		_command_existing_summons()
		_command_refresh = 0.25
	if _cooldown > 0.0:
		return

	_summon()
	_cooldown = summon_interval


func _summon() -> void:
	if ally_scene == null:
		return

	var active_summons := get_tree().get_nodes_in_group("allies").filter(func(ally: Node) -> bool:
		return ally != null and is_instance_valid(ally) and not ally.is_queued_for_deletion()
	)
	if active_summons.size() >= max_summons:
		return

	var owner_node := _owner_node()
	if owner_node == null:
		return

	var ally := ally_scene.instantiate() as Node2D
	var parent := owner_node.get_tree().current_scene
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		parent = owner_node.get_parent()
	if parent == null:
		parent = owner_node.get_tree().root

	parent.add_child(ally)
	ally.add_to_group("player_weapon_effects")
	var selected_visual_id := _selected_ally_visual_id()
	if ally.has_method("set_visual_id"):
		ally.call("set_visual_id", selected_visual_id)
	else:
		ally.set("ally_visual_id", selected_visual_id)
	ally.set("owner_node", owner_node)
	ally.set("command_mode", command_mode)
	var angle := randf() * TAU
	ally.global_position = owner_node.global_position + Vector2.RIGHT.rotated(angle) * 48.0
	var profile := _summon_profile(owner_node)
	if ally.has_method("set_combat_profile"):
		ally.call("set_combat_profile", profile)
	else:
		for key in profile.keys():
			if ally.get(str(key)) != null:
				ally.set(str(key), profile[key])

	if owner_node.has_method("play_action_animation"):
		owner_node.play_action_animation("cast", ally.global_position - owner_node.global_position)
	_command_existing_summons()


func _summon_profile(owner_node: Node) -> Dictionary:
	var parameters_raw = owner_node.get("derived_parameters")
	var parameters: Dictionary = parameters_raw if parameters_raw is Dictionary else {}
	var stats_raw = owner_node.get("stats")
	var stats: Dictionary = stats_raw if stats_raw is Dictionary else {}
	var leadership := float(stats.get("leadership", 0.0))
	var knowledge := float(stats.get("knowledge", 0.0))
	var intelligence := float(stats.get("intelligence", 0.0))
	var energy := float(stats.get("energy", 0.0))
	var summon_amount := float(parameters.get("summon_amount", 0.0))
	var base_damage := float(parameters.get(damage_parameter, parameters.get("damage", damage)))
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
	var summon_crowd_scale := 1.0 + minf(level_progress * 0.135, 2.40)
	var summon_radius := summon_aoe_radius * (1.0 + minf(summon_amount * 0.006 + leadership * 0.004, 0.18)) * sqrt(summon_crowd_scale)
	var summon_splash_damage := summon_aoe_damage_multiplier * summon_crowd_scale
	var owner_max_hp := float(owner_node.get("max_health")) if owner_node.get("max_health") != null else 80.0
	return {
		"damage": maxf(base_damage * damage_multiplier * role_damage, 1.0),
		"move_speed": 230.0 * summon_speed_multiplier * (1.0 + minf(leadership * 0.010, 0.28)),
		"attack_range": maxf(float(parameters.get("attack_range", attack_range)) * 0.18, 24.0),
		"attack_interval": maxf(summon_attack_interval / (1.0 + summon_haste), 0.18),
		"lifetime": 12.0 * summon_lifetime_multiplier * (1.0 + minf(leadership * 0.026, 0.48)),
		"max_health": owner_max_hp * summon_health_multiplier * (1.0 + summon_bulk),
		"summon_role": summon_role,
		"control_knockback": summon_control_knockback,
		"support_heal_percent": summon_support_heal_percent,
		"aoe_radius": summon_radius,
		"aoe_damage_multiplier": summon_splash_damage,
		"leash_radius": summon_leash_radius,
	}


func _selected_ally_visual_id() -> String:
	if not ally_visual_ids.is_empty():
		return ally_visual_ids[randi() % ally_visual_ids.size()]
	if not ally_visual_id.is_empty():
		return ally_visual_id
	match weapon_id:
		"homunculus_vial":
			return "homunculus"
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
	var assigned_damage := {}
	for ally in get_tree().get_nodes_in_group("allies"):
		var ally_node := ally as Node2D
		if ally_node == null or not is_instance_valid(ally_node):
			continue
		if ally_node.get("owner_node") != owner_node:
			continue
		_command_ally(ally_node, owner_node, targets, assigned_damage)


func _command_ally(ally: Node2D, owner_node: Node2D, targets: Array = [], assigned_damage: Dictionary = {}) -> void:
	if ally == null or not is_instance_valid(ally):
		return
	ally.set("command_mode", command_mode)
	ally.set("owner_node", owner_node)
	var target := _best_group_target(ally, owner_node, targets, assigned_damage)
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
		if ally_node.get("owner_node") == owner_node:
			result.append(ally_node)
	return result


func _target_candidates(owner_node: Node2D, count: int) -> Array:
	if owner_node.has_method("attack_aim_mode") and str(owner_node.call("attack_aim_mode")) == "cursor":
		var origin: Vector2 = owner_node.call("attack_aim_position", attack_range) if owner_node.has_method("attack_aim_position") else owner_node.global_position
		var cursor_targets := TARGET_QUERY.nearest_many(self, origin, minf(attack_range, summon_leash_radius), count)
		if not cursor_targets.is_empty():
			return cursor_targets
	return TARGET_QUERY.nearest_many(self, owner_node.global_position, summon_leash_radius, count)


func _best_group_target(ally: Node2D, owner_node: Node2D, targets: Array, assigned_damage: Dictionary) -> Node2D:
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
		var score := distance_score + owner_score + overkill_pressure
		if score < best_score:
			best_score = score
			best_target = target
	if best_target != null:
		var ally_damage := _ally_expected_damage(ally)
		var best_id := best_target.get_instance_id()
		assigned_damage[best_id] = float(assigned_damage.get(best_id, 0.0)) + ally_damage
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
