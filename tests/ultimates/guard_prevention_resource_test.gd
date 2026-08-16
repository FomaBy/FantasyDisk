extends SceneTree

## Focused real-Player proof for the generic guard prevention/resource seam.
##
## Run:
## python3 tools/godot_gate.py --headless --path . \
##   --script res://tests/ultimates/guard_prevention_resource_test.gd

const PlayerScene := preload("res://scenes/Player.tscn")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const ProgressionData := preload("res://scripts/progression_data.gd")

const OWNER_ID := "fixture_guard_owner"
const RESOURCE_ID := "fixture_counter"
const CAP := 75.0
## The fixture stack is a RAW defense rating, and every expected mitigation is read back
## through the accepted effective_defense() composition instead of a fixed percentage, so
## the oracle follows the approved contract rather than one point on a superseded curve.
const RAW_DEFENSE := 0.5
const INCOMING := 100.0
const FULL_HEALTH := 1000.0

var _errors: Array[String] = []
var _holder: Node2D = null
var _player: Node2D = null


func _initialize() -> void:
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	_player = PlayerScene.instantiate() as Node2D
	_holder.add_child(_player)
	await process_frame
	_prepare_player()

	_test_real_player_measures_final_mitigation()
	_test_attribution_cap_replay_and_counter_emission()
	_test_new_run_clears_stale_resource()
	_test_node_end_clears_stale_resource()

	_holder.queue_free()
	await process_frame
	_report()


func _prepare_player() -> void:
	_player.call("configure_character", "berserk", "sword")
	_player.set_process(false)
	_player.set_physics_process(false)
	var derived: Dictionary = _player.get("derived_parameters")
	derived["dodge"] = 0.0
	derived["raw_dodge"] = 0.0
	derived["absorb"] = 0.0
	derived["raw_defense"] = RAW_DEFENSE
	derived["defense"] = _defense_mitigation()
	_player.set("max_health", FULL_HEALTH)
	_player.set("health", FULL_HEALTH)
	_player.set("_damage_invulnerability_left", 0.0)


func _defense_mitigation() -> float:
	return ProgressionData.effective_defense(RAW_DEFENSE)


func _test_real_player_measures_final_mitigation() -> void:
	var activation := _install_guard_activation()
	var attacker := Node2D.new()
	attacker.global_position = _player.global_position + Vector2(100.0, 0.0)
	_holder.add_child(attacker)
	var mitigation := _defense_mitigation()
	var prevented := INCOMING * mitigation
	_check(mitigation > 0.0 and mitigation < ProgressionData.SURVIVABILITY_DEFENSE_CAP,
		"a positive finite defense stack must mitigate strictly between zero and the 0.62 asymptote")
	_check(ProgressionData.effective_defense(RAW_DEFENSE * 4.0) > mitigation,
		"a larger finite defense stack must still add mitigation instead of hitting a hard clamp")
	_player.take_damage(INCOMING, "contact", attacker)
	_check(is_equal_approx(float(_player.get("health")), FULL_HEALTH - (INCOMING - prevented)),
		"the real Player path must preserve the contract final mitigation")
	_check(is_equal_approx(activation.owner_resource_amount(OWNER_ID, RESOURCE_ID), prevented),
		"the generic guard must record final mitigation, not a nominal counter value")
	_check(activation.guard_prevention_owner_id() == OWNER_ID,
		"the active guard owner must be exposed to the Player ingress")
	attacker.queue_free()
	PlayerHost.for_player(_player).controller().cancel()


func _test_attribution_cap_replay_and_counter_emission() -> void:
	var activation := _install_guard_activation()
	_check(activation.record_guard_prevention(_event("wrong_owner", {"owner_id": "foreign"})) == 0.0,
		"a prevention event for another owner must fail closed")
	_check(activation.record_guard_prevention(_event("wrong_source", {"source": "projectile"})) == 0.0,
		"an undeclared source must fail closed")
	_check(activation.record_guard_prevention(_event("wrong_direction", {"direction": Vector2.LEFT})) == 0.0,
		"a hit outside the declared guard arc must fail closed")
	_check(activation.record_guard_prevention(_event("zero", {
		"applied_amount": 100.0,
		"prevented_amount": 0.0,
	})) == 0.0, "zero prevention must not create a resource")
	_check(activation.record_guard_prevention(_event("nominal", {"prevented_amount": 90.0})) == 0.0,
		"reported nominal prevention must not exceed measured incoming minus final damage")

	var first := _event("first")
	_check(is_equal_approx(activation.record_guard_prevention(first), 50.0),
		"the first eligible prevention must add its measured value")
	_check(activation.record_guard_prevention(first) == 0.0,
		"replaying an eligible prevention event must not double count")
	_check(is_equal_approx(activation.record_guard_prevention(_event("capped")), 25.0),
		"the resource cap must admit only the remaining measured value")
	_check(is_equal_approx(activation.owner_resource_amount(OWNER_ID, RESOURCE_ID), CAP),
		"only eligible measured prevention may fill the capped owner resource")

	var emitted: Array[Dictionary] = []
	activation.owner_resource_emitted.connect(func(event: Dictionary) -> void:
		emitted.append(event.duplicate(true))
	)
	var counter: Dictionary = activation.consume_owner_resource(OWNER_ID, RESOURCE_ID, "counter")
	_check(is_equal_approx(float(counter.get("amount", 0.0)), CAP),
		"the counter consumer must receive the exact accumulated measured value")
	_check(emitted.size() == 1 and is_equal_approx(float(emitted[0].get("amount", 0.0)), CAP),
		"the one-shot counter event must emit the measured resource exactly once")
	_check(activation.consume_owner_resource(OWNER_ID, RESOURCE_ID, "counter_replay").get("amount", 0.0) == 0.0,
		"a spent owner resource must not emit or spend twice")
	_check(activation.apply_owner_resource(OWNER_ID, RESOURCE_ID, 50.0, CAP, "refill") == 0.0,
		"a consumed resource must not refill during the same activation")
	PlayerHost.for_player(_player).controller().cancel()


func _test_new_run_clears_stale_resource() -> void:
	var activation := _install_guard_activation()
	_check(activation.record_guard_prevention(_event("before_new_run")) > 0.0,
		"the cleanup fixture must hold resource state")
	_player.call("configure_character", "berserk", "sword")
	_check(activation.is_finished(), "a new run must finish the live guard activation")
	_check(activation.owner_resource_amount(OWNER_ID, RESOURCE_ID) == 0.0,
		"a new run must clear transient owner resources")
	_check(activation.record_guard_prevention(_event("stale_new_run")) == 0.0,
		"a stale prevention event must not credit a new run")
	_prepare_player()


func _test_node_end_clears_stale_resource() -> void:
	var activation := _install_guard_activation()
	var controller = PlayerHost.for_player(_player).controller()
	var lifecycle_tween := activation.track_tween()
	lifecycle_tween.tween_interval(10.0)
	var observed := {"event_count": 0, "resource": 0.0}
	_player.guard_prevention_measured.connect(func(_event: Dictionary) -> void:
		observed["event_count"] = int(observed["event_count"]) + 1
		observed["resource"] = activation.owner_resource_amount(OWNER_ID, RESOURCE_ID)
	, CONNECT_ONE_SHOT)
	var attacker := Node2D.new()
	attacker.global_position = _player.global_position + Vector2(100.0, 0.0)
	_holder.add_child(attacker)
	_player.set("health", 20.0)
	_player.set("_damage_invulnerability_left", 0.0)
	_player.take_damage(INCOMING, "contact", attacker)
	_check(int(observed["event_count"]) == 1 and is_equal_approx(float(observed["resource"]), INCOMING * _defense_mitigation()),
		"lethal prevention must be recorded before death cleanup at final mitigation")
	_check(activation.is_finished() and not controller.is_active(),
		"death must finish the activation and controller synchronously")
	_check(activation.owner_resource_amount(OWNER_ID, RESOURCE_ID) == 0.0,
		"death must clear transient owner resources after recording")
	_check(not lifecycle_tween.is_valid(), "death must invalidate activation-owned tweens")
	_holder.remove_child(_player)
	_check(activation.is_finished(), "node end must finish the live guard activation")
	_check(activation.owner_resource_amount(OWNER_ID, RESOURCE_ID) == 0.0,
		"node end must clear transient owner resources")
	_check(activation.consume_owner_resource(OWNER_ID, RESOURCE_ID, "stale_node_end").get("amount", 0.0) == 0.0,
		"node-end cleanup must not emit a stale counter")
	controller.cancel("node_end")
	_check(activation.is_finished() and not controller.is_active(),
		"death followed by node end and repeated cancellation must stay idempotent")
	_player.queue_free()


func _install_guard_activation() -> Activation:
	var host := PlayerHost.for_player(_player)
	var controller = host.controller()
	controller.cancel()
	var activation := Activation.new(host, {}, 0.0)
	controller._activation = activation
	_check(activation.configure_guard_prevention(
		OWNER_ID, RESOURCE_ID, CAP, Vector2.RIGHT, 90.0, ["contact"]
	), "the class-agnostic guard contract must open")
	return activation


func _event(event_id: String, overrides: Dictionary = {}) -> Dictionary:
	var event := {
		"event_id": event_id,
		"owner_id": OWNER_ID,
		"source": "contact",
		"direction": Vector2.RIGHT,
		"incoming_amount": 100.0,
		"applied_amount": 50.0,
		"prevented_amount": 50.0,
	}
	event.merge(overrides, true)
	return event


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("guard_prevention_resource_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("guard_prevention_resource_test: %s" % error)
	print("guard_prevention_resource_test: FAIL (%d)" % _errors.size())
	quit(1)
