extends SceneTree

# FAN-1585: production-scene determinism contract for the Druid's summon amulet.
#
# The fixture deliberately allocates a real observer before production nodes.  The
# enabled arm connects it to Player/Enemy production signals; the allocation-only
# control does not.  Therefore a red result distinguishes a callback side effect
# from gameplay that depends on unrelated object allocation.

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const ProgressionData := preload("res://scripts/progression_data.gd")

const SEEDS := [143801, 143802, 143803]
const SOLO_TARGETS := 1
const PACK_TARGETS := 10
const GUARD_FRAMES := 120
const MEASUREMENT_FRAMES := 6
const FIXED_DELTA := 1.0 / 60.0
const PLAYER_POSITION := Vector2(640.0, 480.0)
const SOLO_OFFSET := Vector2(180.0, 0.0)
const PACK_RADIUS := 140.0
const DUMMY_HP := 100000.0

var _errors := PackedStringArray()


class ProductionObserver extends RefCounted:
	var frame := 0
	var events: Array = []

	func on_weapon_cast(event: Dictionary) -> void:
		events.append({
			"frame": frame,
			"kind": "cast",
			"weapon_id": str(event.get("weapon_id", "")),
			"attack_mode": str(event.get("attack_mode", "")),
			"action_id": str(event.get("action_id", "")),
		})

	func on_final_resolution(weapon_id: String, event_name: String, target: Node2D, _context: Dictionary, _resolution: Dictionary) -> void:
		events.append({
			"frame": frame,
			"kind": "final",
			"weapon_id": weapon_id,
			"event": event_name,
			"target": _target_label(target),
		})

	func on_damage_applied(target: Node2D, _attempted_amount: float, applied_amount: float, feedback: Dictionary) -> void:
		events.append({
			"frame": frame,
			"kind": "damage",
			"target": _target_label(target),
			"applied": snappedf(applied_amount, 0.0001),
			"damage_type": str(feedback.get("damage_type", "")),
		})

	func on_target_died(target: Node2D) -> void:
		events.append({"frame": frame, "kind": "died", "target": _target_label(target)})

	static func _target_label(target: Node2D) -> String:
		return str(target.get_meta("fan1585_target", "unknown")) if target != null and is_instance_valid(target) else "released"


func _initialize() -> void:
	Engine.max_fps = 60
	for seed_value in SEEDS:
		for target_count in [SOLO_TARGETS, PACK_TARGETS]:
			await _assert_fixture(int(seed_value), int(target_count))
	if not _errors.is_empty():
		for error_value in _errors:
			push_error(error_value)
		quit(1)
		return
	print("FAN-1585 druid summon observer determinism regression passed: 3 seeds x solo/pack with observer, allocation, arm-order, and inert-node controls.")
	quit(0)


func _assert_fixture(seed_value: int, target_count: int) -> void:
	var baseline: Dictionary = await _run_arm(seed_value, target_count, false, false, false)
	var enabled: Dictionary = await _run_arm(seed_value, target_count, true, true, false)
	var allocated_disabled: Dictionary = await _run_arm(seed_value, target_count, true, false, false)
	var inert_node: Dictionary = await _run_arm(seed_value, target_count, false, false, true)
	# Reverse arm order catches state that is accidentally inherited between arms.
	var reverse_enabled: Dictionary = await _run_arm(seed_value, target_count, true, true, false)
	var reverse_disabled: Dictionary = await _run_arm(seed_value, target_count, false, false, false)
	var label := "seed %d / %s" % [seed_value, "solo" if target_count == SOLO_TARGETS else "pack"]

	_check(int(enabled["observer_subscriptions"]) > 0, "%s enabled arm must wire real production subscribers" % label)
	_check(int(enabled["observer_callbacks"]) > 0, "%s enabled arm must receive production callbacks" % label)
	_check(enabled["observer_trace"] == enabled["witness_trace"], "%s enabled observer trace must equal the invariant witness" % label)
	_check(int(baseline["observer_subscriptions"]) == 0 and int(baseline["observer_callbacks"]) == 0, "%s disabled baseline must have zero optional delivery" % label)
	_check(int(allocated_disabled["observer_subscriptions"]) == 0 and int(allocated_disabled["observer_callbacks"]) == 0, "%s connect/disconnect control must keep the allocated observer inert" % label)

	_assert_same_canonical(baseline, enabled, "%s observer enabled/disabled" % label)
	_assert_same_canonical(enabled, allocated_disabled, "%s same-allocation connect/disconnect" % label)
	_assert_same_canonical(baseline, inert_node, "%s inert Node allocation" % label)
	_assert_same_canonical(baseline, reverse_enabled, "%s reverse-order enabled" % label)
	_assert_same_canonical(baseline, reverse_disabled, "%s reverse-order disabled" % label)


func _run_arm(seed_value: int, target_count: int, allocate_observer: bool, connect_observer: bool, allocate_inert_node: bool) -> Dictionary:
	seed(seed_value)
	var holder := Node2D.new()
	holder.name = "FAN1585Holder"
	root.add_child(holder)
	current_scene = holder

	# The optional collector is deliberately allocated before Player/Enemy, matching
	# the production A/B seam.  Inert Node allocation is a separate no-signal control.
	var witness := ProductionObserver.new()
	var observer: ProductionObserver = ProductionObserver.new() if allocate_observer else null
	var inert: Node = Node.new() if allocate_inert_node else null
	var player := PLAYER_SCENE.instantiate() as Node2D
	holder.add_child(player)
	player.add_to_group("player")
	player.global_position = PLAYER_POSITION
	player.call("configure_character", "druid", "summon_amulet")
	player.set("stats", ProgressionData.base_stats("druid").duplicate(true))
	player.call("_apply_stat_scaling", true)
	player.set("max_health", DUMMY_HP)
	player.set("health", DUMMY_HP)
	player.connect("weapon_cast_observed", witness.on_weapon_cast)
	player.connect("constellation_final_resolved", witness.on_final_resolution)
	if observer != null and connect_observer:
		player.connect("weapon_cast_observed", observer.on_weapon_cast)
		player.connect("constellation_final_resolved", observer.on_final_resolution)

	await process_frame
	var summon_weapon := player.get("equipped_weapon") as Node
	_check(summon_weapon != null and summon_weapon.has_method("_prefill_starting_summons"), "Druid summon fixture must expose the production prefill path")
	if summon_weapon != null:
		summon_weapon.call("_prefill_starting_summons")
	await _advance_frames(GUARD_FRAMES, [], [], [witness, observer])
	var guard_roster := _summon_snapshot()
	var dummies := _spawn_dummies(holder, target_count)
	var anchors := []
	for index in range(dummies.size()):
		var enemy := dummies[index] as Node2D
		anchors.append(enemy.global_position)
		enemy.connect("damage_applied", witness.on_damage_applied)
		enemy.connect("died", witness.on_target_died)
		if observer != null and connect_observer:
			enemy.connect("damage_applied", observer.on_damage_applied)
			enemy.connect("died", observer.on_target_died)
	var paused_nodes: Array[Node] = [player]
	for ally_value in get_nodes_in_group("allies"):
		var ally := ally_value as Node
		if ally != null and is_instance_valid(ally):
			paused_nodes.append(ally)
	for node in paused_nodes:
		node.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	for node in paused_nodes:
		node.process_mode = Node.PROCESS_MODE_PAUSABLE
	var before_health := _health_snapshot(dummies)
	await _run_fixed_attack_window(player, dummies, [witness, observer])
	var after_health := _health_snapshot(dummies)
	var roster_after := _summon_snapshot()
	var observer_trace: Array = observer.events.duplicate(true) if observer != null and connect_observer else []
	var subscriptions := 0
	if observer != null and connect_observer:
		subscriptions = 2 + target_count * 2
		_check(player.is_connected("weapon_cast_observed", observer.on_weapon_cast), "observer player cast connection must remain live")
		_check(player.is_connected("constellation_final_resolved", observer.on_final_resolution), "observer player final connection must remain live")
		for dummy_value in dummies:
			var dummy := dummy_value as Node2D
			_check(dummy.is_connected("damage_applied", observer.on_damage_applied), "observer damage connection must remain live")
			_check(dummy.is_connected("died", observer.on_target_died), "observer death connection must remain live")
	var total_applied := 0.0
	for index in range(before_health.size()):
		total_applied += maxf(float(before_health[index]) - float(after_health[index]), 0.0)
	var result := {
		"seed": seed_value,
		"targets": target_count,
		"guard_roster": guard_roster,
		"roster_after": roster_after,
		"witness_trace": witness.events.duplicate(true),
		"observer_trace": observer_trace,
		"hp_ledger": {"before": before_health, "after": after_health, "total_applied": snappedf(total_applied, 0.0001)},
		"frame_window": {"guard": GUARD_FRAMES, "measurement": MEASUREMENT_FRAMES, "seconds": snappedf(MEASUREMENT_FRAMES * FIXED_DELTA, 0.0001)},
		"dpm": snappedf(total_applied / (MEASUREMENT_FRAMES * FIXED_DELTA) * 60.0, 0.0001),
		"rng_probe": randi(),
		"observer_subscriptions": subscriptions,
		"observer_callbacks": observer_trace.size(),
	}
	# Keep the allocation alive until the complete fixture has observed gameplay.
	if inert != null:
		inert.free()
	holder.queue_free()
	await process_frame
	await process_frame
	await process_frame
	return result


func _advance_frames(frame_count: int, dummies: Array, anchors: Array, collectors: Array) -> void:
	for frame_index in range(frame_count):
		await process_frame
		for collector_value in collectors:
			if collector_value != null:
				(collector_value as ProductionObserver).frame = frame_index
		for index in range(dummies.size()):
			if is_instance_valid(dummies[index]):
				(dummies[index] as Node2D).global_position = anchors[index]


func _run_fixed_attack_window(player: Node2D, _dummies: Array, collectors: Array) -> void:
	var weapon := player.get("equipped_weapon") as Node
	_check(weapon != null and weapon.has_method("_command_existing_summons"), "Druid summon fixture must expose the production command path")
	if weapon == null:
		return
	for frame_index in range(MEASUREMENT_FRAMES):
		for collector_value in collectors:
			if collector_value != null:
				(collector_value as ProductionObserver).frame = frame_index
		weapon.call("_command_existing_summons")
		for ally_value in get_nodes_in_group("allies"):
			var ally := ally_value as Node2D
			if ally == null or not is_instance_valid(ally):
				continue
			var target := ally.get("command_target") as Node2D
			if target == null or not is_instance_valid(target):
				continue
			ally.set("_attack_cooldown", 0.0)
			ally.call("_try_attack", target)


func _spawn_dummies(holder: Node2D, target_count: int) -> Array:
	var result := []
	for index in range(target_count):
		var enemy := ENEMY_SCENE.instantiate() as Node2D
		holder.add_child(enemy)
		if target_count == SOLO_TARGETS:
			enemy.global_position = PLAYER_POSITION + SOLO_OFFSET
		else:
			var radius := 0.0 if index == 0 else PACK_RADIUS * (0.55 + 0.45 * sqrt(float(index) / float(PACK_TARGETS - 1)))
			var angle := 0.0 if index == 0 else float(index - 1) * 2.3999632
			enemy.global_position = PLAYER_POSITION + SOLO_OFFSET + Vector2.RIGHT.rotated(angle) * radius
		enemy.add_to_group("enemies")
		enemy.set_meta("fan1585_target", "target_%d" % index)
		enemy.set("max_health", DUMMY_HP)
		enemy.set("health", DUMMY_HP)
		enemy.set("move_speed", 0.0)
		enemy.set("contact_damage", 0.0)
		result.append(enemy)
	return result


func _summon_snapshot() -> Array:
	var result := []
	for ally_value in get_nodes_in_group("allies"):
		var ally := ally_value as Node2D
		if ally == null or not is_instance_valid(ally):
			continue
		var target := ally.get("command_target") as Node2D
		result.append({
			"visual": str(ally.get("ally_visual_id")),
			"role": str(ally.get("summon_role")),
			"position": _vector_signature(ally.global_position),
			"velocity": _vector_signature(ally.get("velocity") as Vector2),
			"target": ProductionObserver._target_label(target),
		})
	return result


func _health_snapshot(nodes: Array) -> Array:
	var snapshot := []
	for node_value in nodes:
		var node := node_value as Node
		snapshot.append(snappedf(float(node.get("health")), 0.0001) if node != null and is_instance_valid(node) else 0.0)
	return snapshot


func _assert_same_canonical(expected: Dictionary, actual: Dictionary, label: String) -> void:
	var expected_canonical := _canonical(expected)
	var actual_canonical := _canonical(actual)
	_check(expected_canonical == actual_canonical, "%s diverged; first differing production state: %s" % [label, _first_difference(expected, actual)])


func _canonical(result: Dictionary) -> String:
	return JSON.stringify({
		"seed": result["seed"], "targets": result["targets"],
		"guard_roster": result["guard_roster"], "roster_after": result["roster_after"],
		"witness_trace": result["witness_trace"], "hp_ledger": result["hp_ledger"],
		"frame_window": result["frame_window"], "dpm": result["dpm"], "rng_probe": result["rng_probe"],
	}, "", true, true)


func _first_difference(expected: Dictionary, actual: Dictionary) -> String:
	for key in ["guard_roster", "roster_after", "witness_trace", "hp_ledger", "frame_window", "dpm", "rng_probe"]:
		if JSON.stringify(expected[key], "", true, true) != JSON.stringify(actual[key], "", true, true):
			return str(key)
	return "unknown"


func _vector_signature(value: Vector2) -> Array:
	return [snappedf(value.x, 0.0001), snappedf(value.y, 0.0001)]


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
