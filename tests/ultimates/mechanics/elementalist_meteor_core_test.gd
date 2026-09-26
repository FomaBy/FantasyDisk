extends SceneTree

const MeteorCore := preload("res://scripts/ultimates/classes/elementalist/elementalist_meteor_core.gd")

const PROFILE_PATH := "res://data/ultimates/classes/elementalist/elementalist_meteor_core.json"
const SCRIPT_PATH := "res://scripts/ultimates/classes/elementalist/elementalist_meteor_core.gd"
const TARGET_COUNT := 22
const PULSE_COUNT := 5


class FixtureTarget extends Node2D:
	var health := 5000.0
	var max_health := 5000.0
	var received: Array[Dictionary] = []

	func take_damage(amount: float, feedback := {}) -> void:
		received.append({"amount": amount, "feedback": (feedback as Dictionary).duplicate(true)})
		health = maxf(health - amount, 0.0)


class FixtureActivation:
	var fixture_targets: Array[Node2D] = []

	func is_finished() -> bool:
		return false

	func param_float(_key: String, fallback: float) -> float:
		return fallback

	func param_int(key: String, fallback: int) -> int:
		return PULSE_COUNT if key == "crater_pulses" else fallback

	func select_targets(
		center: Vector2, radius: float, limit: int, _priority: String, _hint := {}
	) -> Array:
		var found: Array[Node2D] = []
		for raw_target in fixture_targets:
			var target := raw_target as Node2D
			if target != null and is_instance_valid(target) \
					and target.get("health") > 0.0 \
					and target.global_position.distance_to(center) <= radius:
				found.append(target)
		return found.slice(0, limit) if limit > 0 else found

	func present(_event_id: String, _payload: Dictionary) -> void:
		pass

	func apply_control(
		_target: Node, _impulse: Vector2, _status_id: String, _config: Dictionary
	) -> Dictionary:
		return {"status_applied": false}

	func scaled_damage(_key: String, _fallback: float) -> float:
		return 1.0


var _errors: Array[String] = []
var _holder: Node2D


func _initialize() -> void:
	_test_profile_keeps_identity_and_timing()
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	await process_frame
	_test_every_live_target_receives_impact_and_each_crater_pulse()
	_holder.queue_free()
	await process_frame
	_report()


func _test_profile_keeps_identity_and_timing() -> void:
	var document = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
	_check(document is Dictionary, "Meteor Core profile must remain readable")
	if not document is Dictionary:
		return
	var profile := document as Dictionary
	var params := (profile.get("executor", {}) as Dictionary).get("params", {}) as Dictionary
	_check(not params.has("crowd_cap"),
		"Meteor Core profile must not carry a count cap")
	_check(not MeteorCore.parameter_contract().has("crowd_cap"),
		"Meteor Core parameter contract must not carry a count cap")
	_check(not FileAccess.get_file_as_string(SCRIPT_PATH).contains("crowd_cap"),
		"Meteor Core executor must not pass or declare a count cap")
	_check(is_equal_approx(float(profile.get("total_boss_cap", 0.0)), 0.10),
		"Meteor Core must keep its 10% whole-activation boss cap")
	_check(str((profile.get("charge", {}) as Dictionary).get("strategy_id", "")) \
			== "rare_charge_ledger",
		"Meteor Core must keep the rare charge ledger")
	_check(str(profile.get("weapon_id", "")) == "elementalist_meteor_core",
		"Meteor Core identity must remain canonical")
	_check(is_equal_approx(float(params.get("meteor_drop_at", -1.0)), 2.45) \
			and is_equal_approx(float(params.get("impact_at", -1.0)), 2.75) \
			and int(params.get("crater_pulses", 0)) == PULSE_COUNT \
			and is_equal_approx(float(params.get("crater_interval", -1.0)), 0.85),
		"Meteor Core timing must remain unchanged")


func _test_every_live_target_receives_impact_and_each_crater_pulse() -> void:
	var activation := FixtureActivation.new()
	for index in TARGET_COUNT:
		var target := FixtureTarget.new()
		target.global_position = Vector2.ZERO
		_holder.add_child(target)
		activation.fixture_targets.append(target)

	_check(activation.fixture_targets.size() > 20,
		"the focused cast must field more than 20 live targets")
	var effect := MeteorCore.new()
	_holder.add_child(effect)
	effect.configure(activation, Vector2.ZERO)
	effect.ultimate_damage_sink = func(
		target: Node, amount: float, feedback: Dictionary, _event_id: String, _execute: bool
	) -> void:
		var fixture := target as FixtureTarget
		if fixture != null:
			fixture.take_damage(amount, feedback)

	effect.impact()
	_check(int(effect.get("impact_count_for_tests")) == 1,
		"Meteor Core impact must resolve exactly once")
	for target in activation.fixture_targets:
		_check(target.received.size() == 1 and float(target.received[0]["amount"]) > 0.0,
			"impact must add one non-zero hit to every live target")

	for pulse in PULSE_COUNT:
		var received_before: Dictionary = {}
		var living_count := 0
		for target in activation.fixture_targets:
			if target.health > 0.0:
				living_count += 1
				received_before[target.get_instance_id()] = target.received.size()
		_check(living_count > 20,
			"crater pulse %d must start with more than 20 living targets" % pulse)
		effect.crater_pulse(pulse)
		_check(int(effect.get("pulse_count_for_tests")) == pulse + 1,
			"crater pulse %d must resolve exactly once" % pulse)
		for target in activation.fixture_targets:
			if not received_before.has(target.get_instance_id()):
				continue
			_check(target.health > 0.0,
				"crater pulse %d must not kill an eligible target" % pulse)
			var expected_size := int(received_before[target.get_instance_id()]) + 1
			_check(target.received.size() == expected_size,
				"crater pulse %d must add one new hit to every eligible target" % pulse)
			if target.received.size() == expected_size:
				var last: Dictionary = target.received[target.received.size() - 1]
				_check(float(last["amount"]) > 0.0 \
						and str((last["feedback"] as Dictionary).get("ultimate_mechanic", "")) \
						== "meteor_crater",
					"crater pulse %d must add a non-zero meteor_crater hit" % pulse)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("elementalist_meteor_core_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("elementalist_meteor_core_test: %s" % error)
	print("elementalist_meteor_core_test: FAIL (%d)" % _errors.size())
	quit(1)
