extends SceneTree

# FAN-1596: a Homunculus pair tank must carry its one randomized spawn direction
# into targetless guard formation. The fixture uses the production Player scene
# and pair lifecycle, then compares fresh-scene, observer, and inert-allocation
# controls without compensating RNG or object allocation.

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const Meta := preload("res://scripts/meta_progression.gd")

const SEEDS := [159601, 159602, 159603]
const OWNER_POSITION := Vector2(640.0, 480.0)
const SPAWN_RADIUS := 48.0
const GUARD_RADIUS := 56.0

var _errors := PackedStringArray()


class ProductionObserver extends RefCounted:
	var events: Array = []

	func on_weapon_animation(event: Dictionary) -> void:
		events.append({
			"kind": "animation",
			"action_id": str(event.get("action_id", "")),
			"weapon_id": str(event.get("weapon_id", "")),
		})

	func on_final_resolution(weapon_id: String, event_name: String, _target: Node2D, _context: Dictionary, resolution: Dictionary) -> void:
		events.append({
			"kind": "final",
			"weapon_id": weapon_id,
			"event": event_name,
			"triggered": bool(resolution.get("triggered", false)),
		})


func _initialize() -> void:
	Engine.max_fps = 60
	for seed_value in SEEDS:
		await _assert_seed(int(seed_value))
	if not _errors.is_empty():
		for error_value in _errors:
			push_error(error_value)
		quit(1)
		return
	print("FAN-1596 Homunculus pair guard determinism regression passed: 3 seeds with fresh-scene, observer, allocation, targetless-guard, and respawn controls.")
	quit(0)


func _assert_seed(seed_value: int) -> void:
	var baseline: Dictionary = await _run_arm(seed_value, false, false, false)
	var fresh_repeat: Dictionary = await _run_arm(seed_value, false, false, false)
	var observer_enabled: Dictionary = await _run_arm(seed_value, true, true, false)
	var observer_allocated_disabled: Dictionary = await _run_arm(seed_value, true, false, false)
	var inert_node: Dictionary = await _run_arm(seed_value, false, false, true)
	var label := "seed %d" % seed_value

	_check(int(baseline["observer_subscriptions"]) == 0 and int(baseline["observer_callbacks"]) == 0, "%s baseline must have zero optional observer delivery" % label)
	_check(int(observer_enabled["observer_subscriptions"]) == 2 and int(observer_enabled["observer_callbacks"]) > 0, "%s enabled arm must wire and receive real production observer callbacks" % label)
	_check(observer_enabled["observer_trace"] == observer_enabled["witness_trace"], "%s enabled observer trace must equal the invariant witness" % label)
	_check(int(observer_allocated_disabled["observer_subscriptions"]) == 0, "%s allocated-but-disabled observer must remain disconnected" % label)
	_check(int(observer_allocated_disabled["observer_callbacks"]) == 0, "%s allocated-but-disabled observer must receive no callbacks" % label)

	_assert_same_canonical(baseline, fresh_repeat, "%s fresh-scene repeat" % label)
	_assert_same_canonical(baseline, observer_enabled, "%s observer enabled/disabled" % label)
	_assert_same_canonical(baseline, observer_allocated_disabled, "%s same-allocation connect/disconnect" % label)
	_assert_same_canonical(baseline, inert_node, "%s inert Node allocation" % label)
	_assert_pair_contract(baseline, label)


func _run_arm(seed_value: int, allocate_observer: bool, connect_observer: bool, allocate_inert_node: bool) -> Dictionary:
	var expected_rng := _expected_rng_sequence(seed_value)
	seed(seed_value)
	var holder := Node2D.new()
	holder.name = "FAN1596Holder"
	root.add_child(holder)
	current_scene = holder

	# These allocations happen before the real Player scene. They must not affect
	# the pair's spawn, guard geometry, lifecycle, or the next RNG value.
	var witness := ProductionObserver.new()
	var observer: ProductionObserver = ProductionObserver.new() if allocate_observer else null
	var inert_node: Node = Node.new() if allocate_inert_node else null
	if inert_node != null:
		holder.add_child(inert_node)
	var player := PLAYER_SCENE.instantiate() as Node2D
	holder.add_child(player)
	player.global_position = OWNER_POSITION
	player.call("configure_character", "chemist", "homunculus_vial")
	_apply_homunculus_final(player)
	player.connect("weapon_animation_event", witness.on_weapon_animation)
	player.connect("constellation_final_resolved", witness.on_final_resolution)
	if observer != null and connect_observer:
		player.connect("weapon_animation_event", observer.on_weapon_animation)
		player.connect("constellation_final_resolved", observer.on_final_resolution)

	var weapon := player.get("equipped_weapon") as Node
	_check(weapon != null and weapon.has_method("_update_homunculus_pair"), "seed %d production Chemist fixture must expose the pair lifecycle" % seed_value)
	if weapon == null:
		holder.queue_free()
		await process_frame
		return {"canonical": {}, "observer_subscriptions": 0, "observer_callbacks": 0}
	weapon.set_process(false)
	weapon.set_physics_process(false)
	await process_frame
	weapon.call("_update_homunculus_pair", 0.1)
	await process_frame
	var initial_tank := weapon.get("_pair_tank") as Node2D
	var caster := weapon.get("_pair_caster") as Node2D
	_check(initial_tank != null and is_instance_valid(initial_tank), "seed %d initial pair tank did not spawn" % seed_value)
	_check(caster != null and is_instance_valid(caster), "seed %d pair caster did not spawn" % seed_value)
	var initial := _tank_snapshot(initial_tank, player) if initial_tank != null else {}
	var initial_rng_probe := randi()

	if initial_tank != null and is_instance_valid(initial_tank):
		initial_tank.set_process(false)
		initial_tank.set_physics_process(false)
		initial_tank.call("take_damage", float(initial_tank.get("max_health")) * 2.0)
	var death_constellation: Dictionary = initial_tank.call("constellation_special_state") if initial_tank != null and is_instance_valid(initial_tank) else {}
	await process_frame
	weapon.call("_update_homunculus_pair", 0.0)
	weapon.call("_update_homunculus_pair", float(weapon.get("summon_interval")) + 0.05)
	await process_frame
	var respawn_tank := weapon.get("_pair_tank") as Node2D
	_check(respawn_tank != null and is_instance_valid(respawn_tank), "seed %d pair tank did not respawn" % seed_value)
	var respawn := _tank_snapshot(respawn_tank, player) if respawn_tank != null else {}
	var respawn_rng_probe := randi()

	var canonical := {
		"initial": initial,
		"respawn": respawn,
		"death_constellation": {
			"intercepts_left": int(death_constellation.get("intercepts_left", -1)),
			"death_burst_fired": bool(death_constellation.get("death_burst_fired", false)),
		},
		"initial_rng_probe": initial_rng_probe,
		"respawn_rng_probe": respawn_rng_probe,
		"caster_is_noncombat": caster != null and is_instance_valid(caster) and not caster.is_in_group("allies"),
		"expected_rng": expected_rng,
		"witness_trace": witness.events.duplicate(true),
	}
	var result := {
		"canonical": canonical,
		"observer_subscriptions": 2 if observer != null and connect_observer else 0,
		"observer_callbacks": observer.events.size() if observer != null and connect_observer else 0,
		"observer_trace": observer.events.duplicate(true) if observer != null and connect_observer else [],
		"witness_trace": witness.events.duplicate(true),
	}
	holder.queue_free()
	await process_frame
	await process_frame
	return result


func _tank_snapshot(tank: Node2D, owner: Node2D) -> Dictionary:
	var spawn_offset := tank.global_position - owner.global_position
	var spawn_direction := spawn_offset.normalized()
	var guard_direction: Vector2 = tank.get("_guard_formation_direction")
	var guard_destination := owner.global_position + guard_direction * GUARD_RADIUS
	tank.set("command_target", null)
	tank.global_position = owner.global_position
	tank.call("_follow_guard_position")
	var velocity: Vector2 = tank.get("velocity")
	var constellation: Dictionary = tank.call("constellation_special_state")
	return {
		"spawn_offset": _round_vector(spawn_offset),
		"spawn_direction": _round_vector(spawn_direction),
		"guard_direction": _round_vector(guard_direction),
		"guard_destination": _round_vector(guard_destination),
		"guard_velocity_direction": _round_vector(velocity.normalized()),
		"role": str(tank.get("summon_role")),
		"permanent_lifetime": float(tank.get("lifetime")) >= 1.0e8,
		"taunt_pulse": bool(tank.get("taunt_pulse")),
		"owner_identity": int(tank.get("constellation_owner_instance_id")) == owner.get_instance_id(),
		"weapon_identity": str(tank.get("constellation_weapon_id")),
		"constellation": {
			"intercepts_left": int(constellation.get("intercepts_left", -1)),
			"intercept_ratio": snappedf(float(constellation.get("intercept_ratio", -1.0)), 0.0001),
			"death_burst_ratio": snappedf(float(constellation.get("death_burst_ratio", -1.0)), 0.0001),
			"death_burst_fired": bool(constellation.get("death_burst_fired", true)),
		},
	}


func _assert_pair_contract(result: Dictionary, label: String) -> void:
	var canonical: Dictionary = result["canonical"]
	_check(bool(canonical.get("caster_is_noncombat", false)), "%s caster must remain outside allies" % label)
	var expected_rng: Dictionary = canonical.get("expected_rng", {})
	_check(int(canonical.get("initial_rng_probe", -1)) == int(expected_rng.get("initial_probe", -2)), "%s initial spawn consumed an unexpected RNG sequence" % label)
	var death_constellation: Dictionary = canonical.get("death_constellation", {})
	_check(int(death_constellation.get("intercepts_left", -1)) == 0 and bool(death_constellation.get("death_burst_fired", false)), "%s death must consume the intercept and fire the Homunculus constellation burst" % label)
	for phase in ["initial", "respawn"]:
		var snapshot: Dictionary = canonical.get(phase, {})
		var spawn_offset: Vector2 = snapshot.get("spawn_offset", Vector2.ZERO)
		var spawn_direction: Vector2 = snapshot.get("spawn_direction", Vector2.ZERO)
		var guard_direction: Vector2 = snapshot.get("guard_direction", Vector2.ZERO)
		var guard_destination: Vector2 = snapshot.get("guard_destination", Vector2.ZERO)
		var guard_velocity_direction: Vector2 = snapshot.get("guard_velocity_direction", Vector2.ZERO)
		var expected_direction: Vector2 = expected_rng.get("initial_direction", Vector2.ZERO) if phase == "initial" else spawn_direction
		_check(is_equal_approx(spawn_offset.length(), SPAWN_RADIUS), "%s %s spawn offset must stay normalized at %.0f px" % [label, phase, SPAWN_RADIUS])
		_check(_same_vector(spawn_direction, expected_direction), "%s %s spawn direction changed or consumed extra RNG" % [label, phase])
		_check(_same_vector(spawn_direction, guard_direction), "%s %s guard direction must equal the one spawn direction" % [label, phase])
		_check(_same_vector(guard_destination, OWNER_POSITION + spawn_direction * GUARD_RADIUS), "%s %s targetless guard destination must be owner + direction * %.0f" % [label, phase, GUARD_RADIUS])
		_check(_same_vector(guard_velocity_direction, spawn_direction), "%s %s targetless guard movement must face its spawn direction" % [label, phase])
		_check(str(snapshot.get("role", "")) == "tank_control", "%s %s pair role changed" % [label, phase])
		_check(bool(snapshot.get("permanent_lifetime", false)), "%s %s pair lifetime changed" % [label, phase])
		_check(bool(snapshot.get("taunt_pulse", false)), "%s %s pair taunt changed" % [label, phase])
		_check(bool(snapshot.get("owner_identity", false)) and str(snapshot.get("weapon_identity", "")) == "homunculus_vial", "%s %s constellation owner/weapon identity changed" % [label, phase])
		var constellation: Dictionary = snapshot.get("constellation", {})
		_check(int(constellation.get("intercepts_left", -1)) == 1, "%s %s intercept count changed" % [label, phase])
		_check(is_equal_approx(float(constellation.get("intercept_ratio", -1.0)), 0.30), "%s %s intercept ratio changed" % [label, phase])
		_check(is_equal_approx(float(constellation.get("death_burst_ratio", -1.0)), 0.42) and not bool(constellation.get("death_burst_fired", true)), "%s %s death-burst state changed before death" % [label, phase])


func _apply_homunculus_final(player: Node2D) -> void:
	var state := Meta.default_state()
	var nodes: Array[String] = []
	for order in range(1, 6):
		nodes.append("chemist_homunculus_vial_b%d" % order)
	nodes.append("chemist_homunculus_vial_final")
	state["skill_nodes"] = nodes
	player.call("apply_constellation_weapon_profiles", Meta.skill_profiles_for_class(state, "chemist"))


func _expected_rng_sequence(seed_value: int) -> Dictionary:
	seed(seed_value)
	var initial_direction := Vector2.RIGHT.rotated(randf() * TAU)
	var initial_probe := randi()
	return {
		"initial_direction": _round_vector(initial_direction),
		"initial_probe": initial_probe,
	}


func _assert_same_canonical(left: Dictionary, right: Dictionary, label: String) -> void:
	var left_canonical: Dictionary = left.get("canonical", {})
	var right_canonical: Dictionary = right.get("canonical", {})
	_check(left_canonical == right_canonical, "%s changed pair geometry, lifecycle, constellation state, or RNG consumption" % label)


func _round_vector(value: Vector2) -> Vector2:
	return Vector2(snappedf(value.x, 0.0001), snappedf(value.y, 0.0001))


func _same_vector(left: Vector2, right: Vector2) -> bool:
	return left.distance_to(right) <= 0.01


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
