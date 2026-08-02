extends SceneTree

## Focused admission, determinism and production-composition coverage for the
## five shared weapon-ultimate primitives.

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")

const CLASS_ID := "fixture_class"
const WEAPON_ID := "fixture_weapon"
const STEP := 0.01
const EXPECTED_PRIMITIVES := [
	"aim_context",
	"line_pierce_geometry",
	"ordered_step_composition",
	"pattern_geometry",
	"priority_target_selector",
]


class FixtureTarget extends Node2D:
	var health := 100.0
	var max_health := 100.0
	var hits := 0

	func take_damage(amount: float, _feedback := {}) -> void:
		hits += 1
		health = maxf(health - amount, 0.0)


class FixtureHost extends Node2D:
	var fixture_targets: Array = []
	var aim_point := Vector2(300.0, 0.0)
	var aim_direction := Vector2.RIGHT
	var modifiers := {}
	var damage_calls := 0
	var active := false
	var charge := 100.0

	func ultimate_host_context() -> Dictionary:
		return {"damage": 10.0, "multiplier": 1.0, "damage_type": "physical"}

	func ultimate_host_position() -> Vector2:
		return global_position

	func ultimate_host_aim(_max_range: float) -> Dictionary:
		return {"point": aim_point, "direction": aim_direction}

	func ultimate_host_targets(center: Vector2, radius: float, limit: int) -> Array:
		var found: Array = []
		for raw_target in fixture_targets:
			var target := raw_target as Node2D
			if target != null and is_instance_valid(target) \
					and target.global_position.distance_to(center) <= radius:
				found.append(target)
		if limit > 0:
			return found.slice(0, limit)
		return found

	func ultimate_host_apply_damage(target: Node, amount: float, feedback: Dictionary) -> void:
		damage_calls += 1
		target.call("take_damage", amount, feedback)

	func ultimate_host_modifier(key: String, value: float, op: String) -> void:
		var multiplicative := op == Activation.OP_MULTIPLY
		var current := float(modifiers.get(key, 1.0 if multiplicative else 0.0))
		modifiers[key] = current * value if multiplicative else current + value

	func ultimate_host_effect_parent() -> Node:
		return self

	func ultimate_host_present(_event_id: String, _payload: Dictionary) -> Node:
		return null

	func ultimate_host_set_active(value: bool) -> void:
		active = value


class FixtureRegistry extends RefCounted:
	var profile := {}

	func resolution_source(class_id: String, weapon_id: String, _allow_legacy := true) -> String:
		return Resolver.SOURCE_WEAPON_PROFILE \
			if class_id == CLASS_ID and weapon_id == WEAPON_ID \
			else Resolver.SOURCE_INVALID_PAIR

	func catalog_profile_for(_class_id: String, _weapon_id: String) -> Dictionary:
		return profile.duplicate(true)


var _errors: Array[String] = []
var _holder: Node2D


func _initialize() -> void:
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	await process_frame

	_test_admission_contracts()
	await _test_aim_and_priority_are_fixed()
	await _test_line_order_bounds_and_dedup()
	await _test_pattern_seed_order_bounds_and_dedup()
	await _test_ordered_composition_production_path()
	await _test_invalid_composition_has_no_side_effects()

	_holder.queue_free()
	await process_frame
	_report()


func _test_admission_contracts() -> void:
	_check(Library.primitive_ids() == EXPECTED_PRIMITIVES,
		"library must register exactly five primitive IDs, got %s" % [Library.primitive_ids()])
	var schema = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/ultimates/schema/v1/weapon_ultimate_profile.schema.json"
	))
	_check(schema is Dictionary and schema["executor_primitives"]["registered_ids"] == [
		"aim_context", "priority_target_selector", "line_pierce_geometry",
		"pattern_geometry", "ordered_step_composition",
	], "schema primitive declarations must match the production registry")

	for primitive_id in EXPECTED_PRIMITIVES:
		var params := _params_for(primitive_id)
		var normalized := Library.normalize_primitive_params(primitive_id, params)
		_check((normalized["errors"] as Array).is_empty(),
			"%s positive contract must normalize: %s" % [primitive_id, normalized["errors"]])
		_check(not Library.canonical_primitive_signature(primitive_id, params).is_empty(),
			"%s must expose a canonical signature" % primitive_id)

	_expect_error("missing", {}, "executor_primitive.unknown")
	_expect_error("aim_context", {"max_range": 100.0}, "executor_params.missing")
	var fractional := _params_for("priority_target_selector")
	fractional["limit"] = 1.5
	_expect_error("priority_target_selector", fractional, "executor_params.integer")
	var wrong_hint := _params_for("priority_target_selector")
	wrong_hint["hint"] = {"cluster_radius": 20.0}
	_expect_error("priority_target_selector", wrong_hint, "executor_params.unknown")
	var missing_pattern := _params_for("pattern_geometry")
	missing_pattern["params"].erase("radius")
	_expect_error("pattern_geometry", missing_pattern, "executor_params.missing")
	var inverted_annulus := _params_for("pattern_geometry")
	inverted_annulus["pattern"] = "seeded_annulus"
	inverted_annulus["params"] = {
		"count": 3, "inner_radius": 50.0, "outer_radius": 20.0, "seed": 7,
	}
	_expect_error("pattern_geometry", inverted_annulus, "executor_params.range")

	var unknown_step := _params_for("ordered_step_composition")
	unknown_step["steps"][0]["family"] = "missing"
	_expect_error("ordered_step_composition", unknown_step, "executor_step.unknown")
	var recursive := _params_for("ordered_step_composition")
	recursive["steps"][0] = {
		"at": 0.0, "primitive_id": "ordered_step_composition", "params": {"steps": []},
	}
	_expect_error("ordered_step_composition", recursive, "executor_step.recursive")
	var reversed := _params_for("ordered_step_composition")
	reversed["steps"].append({
		"at": -0.1, "family": "burst",
		"params": {"radius": 10.0, "damage": 1.0, "target_limit": 0},
	})
	_expect_error("ordered_step_composition", reversed, "executor_step.order")


func _test_aim_and_priority_are_fixed() -> void:
	var host := _host()
	var nearest := _target(host, Vector2(40.0, 0.0), 30.0)
	var healthiest := _target(host, Vector2(80.0, 0.0), 300.0)
	var activation := Activation.new(host, {}, 0.0)
	_check(Library.execute_primitive("aim_context", activation, _params_for("aim_context")),
		"host aim mode must execute")
	var fixed_target: Vector2 = activation.primitive_value("target")
	host.aim_point = Vector2.UP * 300.0
	_check((activation.aim_point(300.0) as Vector2).is_equal_approx(fixed_target),
		"aim context must retain the first source/target sample")

	var priority := _params_for("priority_target_selector")
	priority["priority"] = "highest_hp"
	_check(Library.execute_primitive("priority_target_selector", activation, priority),
		"highest-HP policy must execute")
	var selected: Array = activation.primitive_value("targets", [])
	_check(selected == [healthiest, nearest], "highest-HP policy must fix deterministic order")
	_check(activation.select_targets(Vector2.ZERO, 300.0, 0, "aimed", {}).is_empty(),
		"aimed policy without its declared point must not fall back to nearest")
	activation.shutdown(true)

	var empty_host := _host()
	var empty_activation := Activation.new(empty_host, {}, 0.0)
	var nearest_mode := _params_for("aim_context")
	nearest_mode["target_mode"] = "nearest_target"
	_check(not Library.execute_primitive("aim_context", empty_activation, nearest_mode),
		"nearest mode without a target must not fall back to the valid host aim")
	_check(empty_activation.primitive_value("target") == null,
		"failed nearest mode must leave no target context")
	empty_activation.shutdown(true)
	await _drop_host(host)
	await _drop_host(empty_host)


func _test_line_order_bounds_and_dedup() -> void:
	var host := _host()
	var first := _target(host, Vector2(40.0, 8.0), 100.0)
	var second := _target(host, Vector2(90.0, -4.0), 100.0)
	_target(host, Vector2(120.0, 30.0), 100.0)
	host.fixture_targets.append(first)
	var activation := Activation.new(host, {}, 0.0)
	activation.set_primitive_state({
		"source": Vector2.ZERO, "target": Vector2.RIGHT * 150.0, "direction": Vector2.RIGHT,
	})
	var params := _params_for("line_pierce_geometry")
	params["length"] = 100.0
	params["half_width"] = 10.0
	_check(Library.execute_primitive("line_pierce_geometry", activation, params),
		"line primitive must execute")
	_check(activation.primitive_value("targets", []) == [first, second],
		"line targets must be bounded, projection-ordered and duplicate-free")
	activation.shutdown(true)
	await _drop_host(host)


func _test_pattern_seed_order_bounds_and_dedup() -> void:
	var host := _host()
	var right := _target(host, Vector2(100.0, 0.0), 100.0)
	var down := _target(host, Vector2(0.0, 100.0), 100.0)
	host.fixture_targets.append(right)
	var activation := Activation.new(host, {}, 0.0)
	activation.set_primitive_state({"source": Vector2.ZERO, "target": Vector2.ZERO})
	var params := _params_for("pattern_geometry")
	params["hit_radius"] = 12.0
	_check(Library.execute_primitive("pattern_geometry", activation, params),
		"pattern primitive must execute")
	_check(activation.primitive_value("targets", []) == [right, down],
		"pattern traversal must preserve point order and deduplicate targets")

	var seeded := {"count": 8, "inner_radius": 40.0, "outer_radius": 80.0, "seed": 12345}
	var first := activation.pattern_points(Vector2.ZERO, "seeded_annulus", seeded)
	var second := activation.pattern_points(Vector2.ZERO, "seeded_annulus", seeded)
	_check(first == second, "same seed and input must reproduce the exact ordered point set")
	for point in first:
		_check(point.length() >= 40.0 - 0.001 and point.length() <= 80.0 + 0.001,
			"seeded annulus point must stay inside declared bounds: %s" % point)
		_target(host, point, 100.0)
	_check(activation.targets_at_points(first, 0.01) == activation.targets_at_points(second, 0.01),
		"same seeded points and targets must reproduce the exact ordered target set")
	activation.shutdown(true)
	await _drop_host(host)


func _test_ordered_composition_production_path() -> void:
	var host := _host()
	var first := _target(host, Vector2(60.0, 0.0), 100.0)
	var second := _target(host, Vector2(120.0, 5.0), 100.0)
	var outside := _target(host, Vector2(100.0, 80.0), 100.0)
	var registry := FixtureRegistry.new()
	registry.profile = {
		"implementation_state": "ready",
		"total_boss_cap": 0.1,
		"executor": {"strategy_id": "ordered_step_composition", "params": {
			"steps": [
				{"at": 0.0, "primitive_id": "aim_context", "params": _params_for("aim_context")},
				{"at": 0.0, "primitive_id": "priority_target_selector", "params": _params_for("priority_target_selector")},
				{"at": 0.0, "primitive_id": "line_pierce_geometry", "params": _params_for("line_pierce_geometry")},
				{"at": 0.0, "family": "burst", "params": {
					"radius": 400.0, "damage": 1.0, "target_limit": 0,
				}},
				{"at": 0.05, "family": "timed_modifier", "params": {
					"duration": 0.1, "radius": 0.0,
					"modifiers": {"armor": {"value": 2.0, "op": "add"}},
				}},
			],
		}},
	}
	var controller := Controller.new(host, registry)
	_check(controller.activate(CLASS_ID, WEAPON_ID), "controller must admit a valid composition")
	var activation := controller.active_activation()
	_check(activation != null and activation.composition_trace_for_tests() == [
		"aim_context", "priority_target_selector", "line_pierce_geometry", "burst",
	], "zero-time steps must execute exactly once in declared order")
	_check(first.hits == 1 and second.hits == 1 and outside.hits == 0,
		"existing family must consume the primitive-selected target set")
	_advance(activation, 0.06)
	_check(activation.composition_trace_for_tests() == [
		"aim_context", "priority_target_selector", "line_pierce_geometry", "burst",
		"timed_modifier",
	], "delayed step must execute once after its declared offset")
	_check(is_equal_approx(float(host.modifiers.get("armor", 0.0)), 2.0),
		"composed family must share the activation ledger, got %s" % [host.modifiers])
	_advance(activation, 0.2)
	_check(not controller.is_active() and is_zero_approx(float(host.modifiers.get("armor", 0.0))),
		"composition lifetime must finish and unwind through the controller")
	await _drop_host(host)


func _test_invalid_composition_has_no_side_effects() -> void:
	var host := _host()
	var registry := FixtureRegistry.new()
	registry.profile = {
		"implementation_state": "ready",
		"total_boss_cap": 0.1,
		"executor": {"strategy_id": "ordered_step_composition", "params": {
			"steps": [{"at": 0.0, "family": "missing", "params": {}}],
		}},
	}
	var controller := Controller.new(host, registry)
	_check(not controller.activate(CLASS_ID, WEAPON_ID),
		"unknown composition step must fail before activation")
	_check(host.charge == 100.0 and not host.active and host.damage_calls == 0,
		"rejected composition must leave charge, active state and host effects untouched")
	await _drop_host(host)


func _params_for(primitive_id: String) -> Dictionary:
	match primitive_id:
		"aim_context":
			return {"max_range": 300.0, "target_mode": "host_aim"}
		"priority_target_selector":
			return {
				"center": "source", "radius": 300.0, "limit": 0,
				"priority": "nearest", "hint": {},
			}
		"line_pierce_geometry":
			return {
				"start": "source", "direction": "aim", "length": 250.0,
				"half_width": 20.0, "limit": 0,
			}
		"pattern_geometry":
			return {
				"center": "source", "pattern": "ring",
				"params": {
					"count": 4, "radius": 100.0, "rotation_degrees": 0.0,
					"arc_degrees": 360.0,
				},
				"hit_radius": 0.0, "target_limit": 0,
			}
		"ordered_step_composition":
			return {"steps": [{
				"at": 0.0, "family": "burst",
				"params": {"radius": 10.0, "damage": 1.0, "target_limit": 0},
			}]}
	return {}


func _expect_error(primitive_id: String, params: Dictionary, prefix: String) -> void:
	for error in Library.validate_primitive_params(primitive_id, params):
		if str(error).begins_with(prefix):
			return
	_errors.append("%s must reject with %s; got %s" % [
		primitive_id, prefix, Library.validate_primitive_params(primitive_id, params),
	])


func _host() -> FixtureHost:
	var host := FixtureHost.new()
	host.process_mode = Node.PROCESS_MODE_DISABLED
	_holder.add_child(host)
	return host


func _target(host: FixtureHost, position: Vector2, health: float) -> FixtureTarget:
	var target := FixtureTarget.new()
	target.global_position = position
	target.health = health
	target.max_health = health
	host.add_child(target)
	host.fixture_targets.append(target)
	return target


func _advance(activation: Activation, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		for tween in activation.tweens_for_tests():
			if tween != null and tween.is_valid():
				tween.custom_step(STEP)
		elapsed += STEP


func _drop_host(host: FixtureHost) -> void:
	host.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("executor_primitives_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("executor_primitives_test: %s" % error)
	print("executor_primitives_test: FAIL (%d)" % _errors.size())
	quit(1)
