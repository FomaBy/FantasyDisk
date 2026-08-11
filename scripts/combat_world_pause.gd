extends Node

# Main is the always-processing UI/input coordinator. This helper keeps its
# combat-world pause contract and runtime ingress separate from that control plane.
const GROUPS := [
	&"player", &"enemies", &"bosses", &"summoned_enemies", &"projectiles",
	&"enemy_projectiles", &"enemy_hazards", &"chemist_clouds", &"allies",
	&"pickups", &"player_weapons", &"player_weapon_effects", &"engineer_devices",
	&"deployed_sound_amps",
]

var _tree: SceneTree
var _is_paused := Callable()


func attach(owner: Node, tree: SceneTree, is_paused: Callable) -> void:
	_tree = tree
	_is_paused = is_paused
	_tree.node_added.connect(_on_tree_node_added)
	owner.add_child(self)


func enforce() -> void:
	for group_name in GROUPS:
		for node in _tree.get_nodes_in_group(group_name):
			_pause_node(node)


func _on_tree_node_added(node: Node) -> void:
	if not _paused() or not _is_combat_world_node(node):
		return
	_pause_node(node)
	if not node.is_node_ready():
		node.ready.connect(_on_combat_world_node_ready.bind(node), CONNECT_ONE_SHOT)


func _on_combat_world_node_ready(node: Node) -> void:
	if _paused() and _is_combat_world_node(node):
		_pause_node(node)


func _paused() -> bool:
	return _is_paused.is_valid() and bool(_is_paused.call())


func _is_combat_world_node(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	for group_name in GROUPS:
		if node.is_in_group(group_name):
			return true
	return false


func _pause_node(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.process_mode = Node.PROCESS_MODE_PAUSABLE
	if node.get("velocity") != null:
		node.set("velocity", Vector2.ZERO)
	for child in node.get_children():
		_pause_node(child)
