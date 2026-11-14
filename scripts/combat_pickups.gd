extends RefCounted
## CombatPickups — XP/money drops of the current fight (FAN-4003): spawn with
## merging under a per-type live-node cap, per-frame radius collection, and the
## victory sweep that banks every drop still on the ground before the snapshot.
## Kept out of scripts/combat_director.gd, which holds a 1500-line ratchet
## (tools/quality_static_guard.py).

const SCENE_CONTRACTS := preload("res://scripts/scene_contracts.gd")
# A drop landing this close to a live same-type pickup merges into it; once a
# type has PICKUP_LIVE_CAP_PER_TYPE live nodes, a drop merges into the nearest
# same-type pickup. Measured choice: docs/design/systems/progression_balance.md.
const PICKUP_MERGE_RADIUS := 48.0
const PICKUP_LIVE_CAP_PER_TYPE := 120

var game


func _init(game_ref) -> void:
	game = game_ref


func spawn(pickup_type: String, amount: int, position: Vector2) -> void:
	if game.pickup_scene == null or amount <= 0:
		return
	# Merged nodes keep every drop (see pickup.gd), so reward value is unchanged.
	var merge_target := _merge_target(pickup_type, position)
	if merge_target != null:
		merge_target.absorb_drop(amount)
		return
	var pickup := SCENE_CONTRACTS.instantiate_node_2d(game.pickup_scene, "CombatDirector pickup spawn")
	if pickup == null:
		return
	game.add_child(pickup)
	pickup.global_position = position
	if pickup.has_method("setup"):
		pickup.setup(pickup_type, amount)


func _merge_target(pickup_type: String, position: Vector2) -> Node2D:
	var nearest: Node2D = null
	var nearest_distance_sq := INF
	var same_type_count := 0
	for pickup in game.get_tree().get_nodes_in_group("pickups"):
		var pickup_node := pickup as Node2D
		if pickup_node == null or not is_instance_valid(pickup_node) or pickup_node.is_queued_for_deletion():
			continue
		if str(pickup_node.get("pickup_type")) != pickup_type or not pickup_node.has_method("absorb_drop"):
			continue
		same_type_count += 1
		var distance_sq := pickup_node.global_position.distance_squared_to(position)
		if distance_sq < nearest_distance_sq:
			nearest_distance_sq = distance_sq
			nearest = pickup_node
	if nearest == null:
		return null
	if nearest_distance_sq <= PICKUP_MERGE_RADIUS * PICKUP_MERGE_RADIUS or same_type_count >= PICKUP_LIVE_CAP_PER_TYPE:
		return nearest
	return null


func update(delta: float) -> void:
	if game.current_player == null or not is_instance_valid(game.current_player):
		return

	var raw_pickup_radius = game.current_player.get("pickup_radius")
	var pickup_radius := 0.0
	if typeof(raw_pickup_radius) == TYPE_INT or typeof(raw_pickup_radius) == TYPE_FLOAT:
		pickup_radius = float(raw_pickup_radius)
	for pickup in game.get_tree().get_nodes_in_group("pickups"):
		var pickup_node := pickup as Node2D
		if pickup_node == null or not is_instance_valid(pickup_node):
			continue

		var distance = pickup_node.global_position.distance_to(game.current_player.global_position)
		if distance <= pickup_radius:
			collect(pickup_node)
		elif distance <= pickup_radius * 1.75:
			pickup_node.global_position = pickup_node.global_position.lerp(game.current_player.global_position, 8.0 * delta)


func collect(pickup: Node, play_sfx := true) -> void:
	# A collected node leaves the group at once, so a pickup collected by update()
	# and the victory sweep in the same frame pays only once.
	if pickup.is_queued_for_deletion() or not pickup.is_in_group("pickups"):
		return
	pickup.remove_from_group("pickups")
	var pickup_type := str(pickup.get("pickup_type"))
	var drops: Dictionary = pickup.call("drop_counts") if pickup.has_method("drop_counts") else {int(pickup.get("amount")): 1}
	for drop_amount in drops.keys():
		for _drop in range(int(drops[drop_amount])):
			if pickup_type == "money":
				game.current_player.gain_money(int(drop_amount))
			else:
				game.current_player.gain_xp(int(drop_amount))
	if play_sfx:
		game._play_sfx("pickup_money" if pickup_type == "money" else "pickup_xp")
	pickup.queue_free()


## A won fight banks every uncollected drop through the ordinary pickup path
## (run multipliers once per drop, gold counter, queued level-ups).
func collect_all_ground() -> void:
	var collected_any := false
	for pickup in game.get_tree().get_nodes_in_group("pickups"):
		if pickup is Node and is_instance_valid(pickup) and not pickup.is_queued_for_deletion():
			collect(pickup, false)
			collected_any = true
	if collected_any:
		game._play_sfx("pickup_money")
