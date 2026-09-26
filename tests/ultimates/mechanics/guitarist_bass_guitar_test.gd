extends SceneTree

## Guards the v2 no-count-cap contract: all four Hell Subwoofer waves must
## enumerate live targets again, including a crowd above the retired cap.

const BassGuitar := preload("res://scripts/ultimates/classes/guitarist/bass_guitar.gd")
const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Runner := preload("res://scripts/ultimates/balance/ultimate_effectiveness_runner.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "guitarist"
const WEAPON_ID := "bass_guitar"
const BASELINE_PATH := "res://build/ultimate_effectiveness_baseline.json"
const TARGET_COUNT := 20
const STAGES := ["pull", "weight", "launch", "shock"]


class FixtureTarget extends Node2D:
	var damage_events: Array[String] = []
	var control_events: Array[String] = []


class FixtureActivation:
	var fixture_targets: Array[Node2D] = []
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

	func targets(center: Vector2, radius: float, limit := 0) -> Array:
		target_limits.append(limit)
		var found: Array[Node2D] = []
		for target in fixture_targets:
			if is_instance_valid(target) and target.global_position.distance_to(center) <= radius:
				found.append(target)
		return found.slice(0, limit) if limit > 0 else found

	func deal_damage(target: Node, _amount: float, _feedback: Dictionary, event_id: String) -> void:
		var fixture := target as FixtureTarget
		if fixture != null:
			fixture.damage_events.append(event_id)

	func apply_control(target: Node, _impulse: Vector2, event_id: String, _config: Dictionary) -> void:
		var fixture := target as FixtureTarget
		if fixture != null:
			fixture.control_events.append(event_id)

	func present(_event_id: String, _payload: Dictionary) -> void:
		pass


var _errors: Array[String] = []
var _holder: Node2D


func _initialize() -> void:
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	await process_frame
	_test_all_waves_are_uncapped_and_retarget()
	await _test_effectiveness_envelope()
	_holder.queue_free()
	await process_frame
	_report()


func _test_all_waves_are_uncapped_and_retarget() -> void:
	var activation := FixtureActivation.new()
	var original_targets: Array[FixtureTarget] = []
	for index in TARGET_COUNT:
		var target := _target(activation, Vector2.ZERO)
		original_targets.append(target)
	var state := {"waves": []}

	BassGuitar.fire_wave(activation, state, "pull")
	var late_target := _target(activation, Vector2.ZERO)
	for stage in STAGES.slice(1):
		BassGuitar.fire_wave(activation, state, stage)

	_check(activation.target_limits == [0, 0, 0, 0],
		"every Subwoofer wave must enumerate without a count cap")
	_check(state.get("waves", []) == STAGES,
		"Subwoofer must retain pull, weight, launch and shock ordering")
	for target in original_targets:
		_check(target.damage_events == ["bass:pull", "bass:weight", "bass:launch", "bass:shock"]
			and target.control_events.size() == STAGES.size(),
			"every original live target must receive all four waves")
	_check(late_target.damage_events == ["bass:weight", "bass:launch", "bass:shock"]
		and late_target.control_events.size() == STAGES.size() - 1,
		"each later wave must re-read targets that entered after pull")


func _test_effectiveness_envelope() -> void:
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	var rows := Budget.build_rows(PD.WEAPONS_BY_CLASS, PD)
	var row := Budget.row_for(rows, CLASS_ID, WEAPON_ID)
	var measured: Array = await Runner.new().measure(_holder, registry, [row], PD)
	if measured.is_empty():
		return
	var scenarios: Dictionary = (measured[0] as Dictionary).get("scenarios", {})
	for scenario in Runner.SCENARIOS:
		var spec := scenario as Dictionary
		var result: Dictionary = scenarios.get(str(spec["id"]), {})
		_check(int(result.get("targets_struck", 0)) == int(spec["probes"]),
			"%s must strike all %d eligible targets" % [spec["id"], spec["probes"]])
	var baseline := _baseline_row()
	_check(not baseline.is_empty() and Runner.regressions([baseline], measured).is_empty(),
		"Bass must not regress from the committed effectiveness baseline")
	for scenario in Runner.SCENARIOS:
		var spec := scenario as Dictionary
		var result: Dictionary = scenarios.get(str(spec["id"]), {})
		print("bass effectiveness %s: struck=%d damage=%.2f" % [
			spec["id"], int(result.get("targets_struck", 0)), float(result.get("damage_applied", 0.0)),
		])


func _baseline_row() -> Dictionary:
	var document = JSON.parse_string(FileAccess.get_file_as_string(BASELINE_PATH))
	if not document is Dictionary:
		return {}
	for raw_row in (document as Dictionary).get("rows", []):
		var row := raw_row as Dictionary
		if str(row.get("class_id", "")) == CLASS_ID and str(row.get("weapon_id", "")) == WEAPON_ID:
			return row
	return {}


func _target(activation: FixtureActivation, position: Vector2) -> FixtureTarget:
	var target := FixtureTarget.new()
	target.global_position = position
	_holder.add_child(target)
	activation.fixture_targets.append(target)
	return target


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("guitarist_bass_guitar_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("guitarist_bass_guitar_test: %s" % error)
	quit(1)
