extends Node2D

@export var ally_scene: PackedScene
@export var summon_interval := 4.0
@export var max_summons := 2

var _cooldown := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("player_weapons")


func _process(delta: float) -> void:
	_cooldown -= delta
	if _cooldown > 0.0:
		return

	_summon()
	_cooldown = summon_interval


func _summon() -> void:
	if ally_scene == null:
		return

	var active_summons := get_tree().get_nodes_in_group("allies")
	if active_summons.size() >= max_summons:
		return

	var owner_node := _owner_node()
	if owner_node == null:
		return

	var ally := ally_scene.instantiate() as Node2D
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root

	parent.add_child(ally)
	var angle := randf() * TAU
	ally.global_position = owner_node.global_position + Vector2.RIGHT.rotated(angle) * 48.0

	if owner_node.has_method("play_action_animation"):
		owner_node.play_action_animation("cast", ally.global_position - owner_node.global_position)


func _owner_node() -> CharacterBody2D:
	var parent_node := get_parent()
	while parent_node != null:
		if parent_node is CharacterBody2D:
			return parent_node
		parent_node = parent_node.get_parent()
	return null
