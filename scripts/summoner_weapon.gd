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
	_command_ally(ally, owner_node)


func _summon_profile(owner_node: Node) -> Dictionary:
	var parameters_raw = owner_node.get("derived_parameters")
	var parameters: Dictionary = parameters_raw if parameters_raw is Dictionary else {}
	var stats_raw = owner_node.get("stats")
	var stats: Dictionary = stats_raw if stats_raw is Dictionary else {}
	var leadership := float(stats.get("leadership", 0.0))
	var summon_amount := float(parameters.get("summon_amount", 0.0))
	var base_damage := float(parameters.get(damage_parameter, parameters.get("damage", damage)))
	var role_damage := summon_role_damage_multiplier * (1.0 + minf(summon_amount * 0.018, 0.22))
	var owner_max_hp := float(owner_node.get("max_health")) if owner_node.get("max_health") != null else 80.0
	return {
		"damage": maxf(base_damage * damage_multiplier * role_damage, 1.0),
		"move_speed": 230.0 * summon_speed_multiplier * (1.0 + minf(leadership * 0.006, 0.16)),
		"attack_range": maxf(float(parameters.get("attack_range", attack_range)) * 0.18, 24.0),
		"attack_interval": maxf(summon_attack_interval / (1.0 + minf(summon_amount * 0.012, 0.18)), 0.18),
		"lifetime": 12.0 * summon_lifetime_multiplier * (1.0 + minf(leadership * 0.018, 0.32)),
		"max_health": owner_max_hp * summon_health_multiplier * (1.0 + minf(leadership * 0.035, 0.45)),
		"summon_role": summon_role,
		"control_knockback": summon_control_knockback,
		"support_heal_percent": summon_support_heal_percent,
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
	for ally in get_tree().get_nodes_in_group("allies"):
		var ally_node := ally as Node2D
		if ally_node == null or not is_instance_valid(ally_node):
			continue
		if ally_node.get("owner_node") != owner_node:
			continue
		_command_ally(ally_node, owner_node)


func _command_ally(ally: Node2D, owner_node: Node2D) -> void:
	if ally == null or not is_instance_valid(ally):
		return
	ally.set("command_mode", command_mode)
	ally.set("owner_node", owner_node)
	var target := _closest_enemy(owner_node)
	if target != null:
		ally.set("command_target", target)


func _closest_enemy(owner_node: Node2D) -> Node2D:
	if owner_node.has_method("attack_aim_mode") and str(owner_node.call("attack_aim_mode")) == "cursor":
		var origin: Vector2 = owner_node.call("attack_aim_position", attack_range) if owner_node.has_method("attack_aim_position") else owner_node.global_position
		return TARGET_QUERY.nearest(self, origin, attack_range)
	return TARGET_QUERY.nearest(self, owner_node.global_position)


func _owner_node() -> CharacterBody2D:
	var parent_node := get_parent()
	while parent_node != null:
		if parent_node is CharacterBody2D:
			return parent_node
		parent_node = parent_node.get_parent()
	return null
