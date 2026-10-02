extends SceneTree

const ReactorCore := preload("res://scripts/ultimates/classes/robot/robot_reactor_core.gd")

const PROFILE_PATH := "res://data/ultimates/classes/robot/robot_reactor_core.json"
const TARGET_COUNT := 20


class FixtureTarget extends Node2D:
	var damage_events: Array[String] = []


class FixtureActivation:
	var fixture_targets: Array[Node2D] = []
	var corridor_limits: Array[int] = []
	var target_limits: Array[int] = []

	func is_finished() -> bool:
		return false

	func origin() -> Vector2:
		return Vector2.ZERO

	func param_float(_key: String, fallback: float) -> float:
		return fallback

	func param_int(_key: String, fallback: int) -> int:
		return fallback

	func scaled_damage(_key: String, fallback: float) -> float:
		return fallback

	func targets_in_corridor(
		_start: Vector2, _direction: Vector2, _length: float, _half_width: float, limit := 0
	) -> Array:
		corridor_limits.append(limit)
		return fixture_targets.slice(0, limit) if limit > 0 else fixture_targets

	func targets(_center: Vector2, _radius: float, limit := 0) -> Array:
		target_limits.append(limit)
		return fixture_targets.slice(0, limit) if limit > 0 else fixture_targets

	func deal_damage(target: Node, _amount: float, _feedback: Dictionary, event_id: String, _final := false) -> void:
		var fixture := target as FixtureTarget
		if fixture != null:
			fixture.damage_events.append(event_id)

	func present(_event_id: String, _payload: Dictionary) -> void:
		pass


var _errors: Array[String] = []
var _holder: Node2D


func _initialize() -> void:
	_test_profile_preserves_boss_cap_and_charge()
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	await process_frame
	_test_all_eligible_targets_receive_uncapped_vents_and_final()
	_holder.queue_free()
	await process_frame
	_report()


func _test_profile_preserves_boss_cap_and_charge() -> void:
	var profile = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
	_check(profile is Dictionary, "Reactor Core profile must remain readable")
	if not profile is Dictionary:
		return
	_check(is_equal_approx(float(profile.get("total_boss_cap", 0.0)), 0.08),
		"Reactor Core must retain its eight-percent boss cap")
	_check(str((profile.get("charge", {}) as Dictionary).get("strategy_id", "")) == "rare_charge_ledger",
		"Reactor Core must retain the rare charge ledger")


func _test_all_eligible_targets_receive_uncapped_vents_and_final() -> void:
	var activation := FixtureActivation.new()
	for index in TARGET_COUNT:
		var target := FixtureTarget.new()
		_holder.add_child(target)
		activation.fixture_targets.append(target)

	ReactorCore.vent_wave(activation, 0)
	ReactorCore.final_vent(activation)
	_check(activation.corridor_limits == [0, 0, 0, 0, 0, 0, 0, 0],
		"every Reactor Core vent must enumerate its corridor without a count cap")
	_check(activation.target_limits == [0], "the final vent must remain uncapped")
	for target in activation.fixture_targets:
		_check(target.damage_events.size() == 9 and target.damage_events.has("final"),
			"every eligible target must receive every vent and the non-zero final vent")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("robot_reactor_core_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("robot_reactor_core_test: %s" % error)
	quit(1)
