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
@export var command_mode := "attack_target"
@export var ally_visual_id := ""

var _cooldown := 0.0
var _command_refresh := 0.0
var ally_visual_ids: Array[String] = []


func configure_weapon(config: Dictionary) -> void:
	weapon_id = str(config.get("id", weapon_id))
	summon_interval = float(config.get("fire_interval", summon_interval))
	max_summons = int(config.get("max_summons", max_summons))
	damage_parameter = str(config.get("damage_parameter", damage_parameter))
	damage_multiplier = float(config.get("summon_damage_multiplier", damage_multiplier))
	command_mode = str(config.get("command_mode", command_mode))
	ally_visual_id = str(config.get("ally_visual_id", ally_visual_id))
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
	# Урон зверя масштабируется от звукового урона друида (формула Per/Energy/Lead).
	var parameters_raw = owner_node.get("derived_parameters")
	if parameters_raw is Dictionary and ally.get("damage") != null:
		ally.set("damage", maxf(float((parameters_raw as Dictionary).get(damage_parameter, 6.0)) * damage_multiplier, 1.0))

	if owner_node.has_method("play_action_animation"):
		owner_node.play_action_animation("cast", ally.global_position - owner_node.global_position)
	_command_ally(ally, owner_node)


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
	return TARGET_QUERY.nearest(self, owner_node.global_position)


func _owner_node() -> CharacterBody2D:
	var parent_node := get_parent()
	while parent_node != null:
		if parent_node is CharacterBody2D:
			return parent_node
		parent_node = parent_node.get_parent()
	return null
