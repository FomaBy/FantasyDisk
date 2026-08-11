extends SceneTree

## Deterministic clock-domain regression for FAN-2361.
##
## Godot passes time-scaled delta to Node._process(), while activation-owned
## gameplay tweens ignore time scale. The fixture feeds the host the exact delta
## Godot would provide and requires presentation phases to follow gameplay time.
##
## Run:
## python3 tools/godot_gate.py --headless --path . \
##   --script res://tests/ultimates/ultimate_player_host_time_scale_test.gd

const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
const PresentationRuntime := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_runtime.gd")
const Timeline := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_timeline.gd")

const HIT_STOP_TIME_SCALE := 0.32
const GAMEPLAY_STEP_SECONDS := 0.25
const PHASES := ["release", "active", "recovery"]

var _errors: Array[String] = []


func _initialize() -> void:
	var original_time_scale := Engine.time_scale
	_assert_legacy_clock_falsification()
	_test_clock(1.0)
	_test_clock(HIT_STOP_TIME_SCALE)
	Engine.time_scale = original_time_scale
	_report()


func _test_clock(time_scale: float) -> void:
	Engine.time_scale = time_scale
	var fixture := _clock_fixture()
	var host: Node = fixture["host"]
	var timeline = fixture["timeline"]
	for index in PHASES.size():
		var gameplay_elapsed := GAMEPLAY_STEP_SECONDS * float(index + 1)
		host.call("_process", GAMEPLAY_STEP_SECONDS * time_scale)
		_check(
			is_equal_approx(timeline.elapsed_seconds(), gameplay_elapsed),
			"time_scale=%.2f presentation must match %.2fs gameplay at %s, got %.3fs"
				% [time_scale, gameplay_elapsed, PHASES[index], timeline.elapsed_seconds()]
		)
		var emitted: Dictionary = timeline.get("_emitted_phases")
		_check(
			emitted.has(PHASES[index]) and emitted.size() == index + 1,
			"time_scale=%.2f must reach only %s by %.2fs gameplay: %s"
				% [time_scale, PHASES[index], gameplay_elapsed, str(emitted.keys())]
		)
	host.call("ultimate_host_finish_presentation", "node_end")
	_check(host.get("_presentation") == null, "time_scale=%.2f completion must clear presentation" % time_scale)
	_check(str(timeline.snapshot().get("state", "")) == Timeline.FINISHED_STATE,
		"time_scale=%.2f completion must finish the timeline" % time_scale)
	host.free()


func _assert_legacy_clock_falsification() -> void:
	var legacy_elapsed_at_recovery := GAMEPLAY_STEP_SECONDS * float(PHASES.size()) \
		* HIT_STOP_TIME_SCALE
	_check(
		legacy_elapsed_at_recovery < GAMEPLAY_STEP_SECONDS,
		"falsification fixture must leave the legacy scaled clock before release at gameplay recovery"
	)


func _clock_fixture() -> Dictionary:
	var manifest := {
		"timing": {
			"release": GAMEPLAY_STEP_SECONDS,
			"active": GAMEPLAY_STEP_SECONDS * 2.0,
			"recovery": GAMEPLAY_STEP_SECONDS * 3.0,
		},
		"phases": PHASES.map(func(phase: String) -> Dictionary: return {"name": phase, "phase_id": phase}),
	}
	var timeline = Timeline.new(manifest, 0)
	timeline.begin({})
	var presentation = PresentationRuntime.new(0)
	presentation.set("_timeline", timeline)
	var host = PlayerHost.new()
	host.set("_presentation", presentation)
	return {"host": host, "timeline": timeline}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("ultimate_player_host_time_scale_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("ultimate_player_host_time_scale_test: %s" % error)
	quit(1)
