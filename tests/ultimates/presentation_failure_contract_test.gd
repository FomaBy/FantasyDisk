extends SceneTree

## FAN-2351: a ready presentation failure is an atomic, observable refusal.
##
## Run:
## python3 tools/godot_gate.py --headless --path . \
##   --script res://tests/ultimates/presentation_failure_contract_test.gd

const PlayerScene := preload("res://scenes/Player.tscn")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
const PresentationManifest := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_manifest.gd")
const PresentationRuntime := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_runtime.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "soldier"
const WEAPON_ID := "soldier_rifle"
const GRENADE_ID := "soldier_grenade"


class OverBudgetRuntime extends PresentationRuntime:
	func _within_declared_budget(runtime: Dictionary) -> bool:
		var scene := get("_scene") as Node
		if scene != null:
			scene.add_child(Sprite2D.new())
		return super._within_declared_budget(runtime)


var _errors: Array[String] = []
var _holder: Node2D = null


func _initialize() -> void:
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	root.set_meta("combat_feedback", false)
	await process_frame
	await _test_ready_failure_is_atomic()
	await _test_player_host_pause_bridge()
	_test_soldier_grenade_timing_truth()
	_holder.queue_free()
	await process_frame
	_report()


func _test_ready_failure_is_atomic() -> void:
	var player := await _spawn_player(WEAPON_ID)
	var host := PlayerHost.for_player(player)
	var runtime := OverBudgetRuntime.new(0)
	host.set("_presentation", runtime)
	var full_charge := float(player.get("ultimate_max_charge"))
	player.set("ultimate_charge", full_charge)
	var ledger = player.get("_ultimate_charge_ledger")
	var activation_count := int(ledger.encounter_activations())
	var presentation_count := _presentation_count()

	_check(not bool(player.call("activate_ultimate")),
		"an over-budget ready presentation must reject the cast")
	_check(is_equal_approx(float(player.get("ultimate_charge")), full_charge),
		"presentation rejection must not spend charge")
	_check(int(ledger.encounter_activations()) == activation_count,
		"presentation rejection must not consume the encounter activation")
	_check(not bool(player.get("_ultimate_active")),
		"presentation rejection must not run the legacy class ultimate")
	_check(not runtime.is_active() and not host.controller().is_active(),
		"presentation rejection must clear runtime and controller state")
	_check(host.get("_presentation") == null,
		"presentation rejection must clear host ownership")
	_check(PlayerHost.activation_failure(player) == "presentation_failed",
		"presentation rejection must expose a diagnostic result")

	await process_frame
	_check(_presentation_count() == presentation_count,
		"the rejected presentation scene must be freed")
	player.queue_free()
	await process_frame


func _test_player_host_pause_bridge() -> void:
	var player := await _spawn_player(WEAPON_ID)
	var host := PlayerHost.for_player(player)
	var runtime := PresentationRuntime.new(0)
	host.set("_presentation", runtime)
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(bool(player.call("activate_ultimate")),
		"the valid ready presentation must start through the real Player host")
	var timeline = runtime.get("_timeline")
	_check(timeline != null, "the live presentation must own a timeline")
	if timeline != null:
		runtime.advance(0.25)
		var before_pause := float(timeline.elapsed_seconds())
		host.notification(Node.NOTIFICATION_PAUSED)
		runtime.advance(1.0)
		_check(is_equal_approx(float(timeline.elapsed_seconds()), before_pause),
			"Player pause notification must freeze presentation time")
		host.notification(Node.NOTIFICATION_UNPAUSED)
		runtime.advance(1.0)
		_check(float(timeline.elapsed_seconds()) > before_pause,
			"Player unpause notification must resume presentation time")
	host.controller().cancel()
	_check(host.get("_presentation") == null,
		"controller cancel must release the successful presentation")
	player.queue_free()
	await process_frame


func _test_soldier_grenade_timing_truth() -> void:
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	var profile: Dictionary = registry.catalog_profile_for(CLASS_ID, GRENADE_ID)
	var manifest := PresentationManifest.manifest_for_profile(profile)
	var lifetime := float(((profile.get("executor", {}) as Dictionary).get("params", {}) as Dictionary).get("lifetime", -1.0))
	var cancel := float((manifest.get("timing", {}) as Dictionary).get("cancel", -1.0))
	var packed := load(str((manifest.get("runtime", {}) as Dictionary).get("scene_path", ""))) as PackedScene
	_check(packed != null, "the Soldier grenade presentation scene must load")
	if packed == null:
		return
	var scene := packed.instantiate()
	var timeline := scene.get_node_or_null("Timeline") as AnimationPlayer
	var animation := timeline.get_animation(&"ultimate") if timeline != null else null
	_check(is_equal_approx(lifetime, 8.4),
		"the unchanged Soldier grenade gameplay lifetime must remain 8.4 seconds")
	_check(is_equal_approx(float(profile.get("total_boss_cap", -1.0)), 0.09),
		"the Soldier grenade boss cap must remain unchanged")
	_check(animation != null and is_equal_approx(cancel, lifetime)
		and is_equal_approx(animation.length, lifetime),
		"Soldier grenade gameplay, cancel and scene clocks must agree")
	scene.free()


func _spawn_player(weapon_id: String) -> Node2D:
	var player := PlayerScene.instantiate() as Node2D
	_holder.add_child(player)
	await process_frame
	player.call("configure_character", CLASS_ID, weapon_id)
	await process_frame
	player.set_process(false)
	player.set_physics_process(false)
	return player


func _presentation_count() -> int:
	var count := 0
	for child in _holder.get_children():
		if str((child as Node).get_meta("ultimate_id", "")).begins_with("soldier/"):
			count += 1
	return count


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("presentation_failure_contract_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("presentation_failure_contract_test: %s" % error)
	print("presentation_failure_contract_test: FAIL (%d)" % _errors.size())
	quit(1)
