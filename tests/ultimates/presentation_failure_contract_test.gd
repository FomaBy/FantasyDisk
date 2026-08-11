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
const PAUSE_CLASS_ID := "robot"
const PAUSE_WEAPON_ID := "robot_magnetic_anchor"
const RUNTIME_SOURCE_PATH := "res://scripts/ultimates/presentation/weapon_ultimate_presentation_runtime.gd"
const MANIFEST_ADMISSION_GUARD := "if manifest.is_empty() or not Schema.validate_manifest(manifest, profile).is_empty():"
const SCENE_PATH_ADMISSION_GUARD := "if scene_path.is_empty() or not ResourceLoader.exists(scene_path):"


class OverBudgetRuntime extends PresentationRuntime:
	var observed_scene: Node = null
	var observed_parent: Node = null

	func _within_declared_budget(runtime: Dictionary) -> bool:
		observed_scene = get("_scene") as Node
		if observed_scene != null:
			observed_parent = observed_scene.get_parent()
			observed_scene.add_child(Sprite2D.new())
		return super._within_declared_budget(runtime)


class TimelineOnlyPauseRuntime extends PresentationRuntime:
	func set_paused(value: bool) -> void:
		var timeline = get("_timeline")
		if timeline != null:
			timeline.set_paused(value)


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
	await _test_scene_pause_mutation_control()
	_test_soldier_grenade_timing_truth()
	_holder.queue_free()
	await process_frame
	_report()


func _test_ready_failure_is_atomic() -> void:
	_test_presentation_admission_guards()
	var player := await _spawn_player(CLASS_ID, WEAPON_ID)
	var host := PlayerHost.for_player(player)
	var runtime := OverBudgetRuntime.new(0)
	host.set("_presentation", runtime)
	var effect_parent := player.call("_vfx_parent") as Node
	var legacy_effect_count := _legacy_effect_count(effect_parent)
	var full_charge := float(player.get("ultimate_max_charge"))
	player.set("ultimate_charge", full_charge)
	var ledger = player.get("_ultimate_charge_ledger")
	var activation_count := int(ledger.encounter_activations())
	var presentation_count := _presentation_count()

	_check(not bool(player.call("activate_ultimate")),
		"an over-budget ready presentation must reject the cast")
	_check(runtime.observed_scene != null,
		"the budget rejection must observe the instantiated presentation scene")
	_check(runtime.observed_parent == effect_parent,
		"the budget rejection must observe the presentation scene after parenting")
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
	_check(_legacy_effect_count(effect_parent) == legacy_effect_count,
		"a ready-package rejection must not emit the observable legacy fallback effect")
	player.queue_free()
	await process_frame


func _test_player_host_pause_bridge() -> void:
	var player := await _spawn_player(PAUSE_CLASS_ID, PAUSE_WEAPON_ID)
	var host := PlayerHost.for_player(player)
	var runtime := PresentationRuntime.new(0)
	host.set("_presentation", runtime)
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(bool(player.call("activate_ultimate")),
		"the valid ready presentation must start through the real Player host")
	var timeline = runtime.get("_timeline")
	var scene := runtime.get("_scene") as Node
	var scene_timeline = scene.get("_timeline") if scene != null else null
	_check(timeline != null, "the live presentation must own a timeline")
	_check(scene_timeline != null, "the live presentation scene must own a timeline")
	if timeline != null and scene_timeline != null:
		runtime.advance(0.25)
		_advance_scene(scene, 0.25)
		var before_pause := _timeline_elapsed(timeline)
		var before_scene_pause := _timeline_elapsed(scene_timeline)
		host.notification(Node.NOTIFICATION_PAUSED)
		runtime.advance(1.0)
		_advance_scene(scene, 1.0)
		_check(is_equal_approx(float(timeline.elapsed_seconds()), before_pause),
			"Player pause notification must freeze presentation time")
		_check(is_equal_approx(_timeline_elapsed(scene_timeline), before_scene_pause),
			"Player pause notification must freeze the presentation scene runner")
		host.notification(Node.NOTIFICATION_UNPAUSED)
		runtime.advance(1.0)
		_advance_scene(scene, 1.0)
		_check(float(timeline.elapsed_seconds()) > before_pause,
			"Player unpause notification must resume presentation time")
		_check(_timeline_elapsed(scene_timeline) > before_scene_pause,
			"Player unpause notification must resume the presentation scene runner")
	host.controller().cancel()
	_check(host.get("_presentation") == null,
		"controller cancel must release the successful presentation")
	player.queue_free()
	await process_frame


func _test_scene_pause_mutation_control() -> void:
	var player := await _spawn_player(PAUSE_CLASS_ID, PAUSE_WEAPON_ID)
	var host := PlayerHost.for_player(player)
	var runtime := TimelineOnlyPauseRuntime.new(0)
	host.set("_presentation", runtime)
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(bool(player.call("activate_ultimate")),
		"the scene-pause mutation control must start a real presentation")
	var scene := runtime.get("_scene") as Node
	var scene_timeline = scene.get("_timeline") if scene != null else null
	if scene_timeline != null:
		_advance_scene(scene, 0.25)
		var before_pause := _timeline_elapsed(scene_timeline)
		host.notification(Node.NOTIFICATION_PAUSED)
		_advance_scene(scene, 1.0)
		_check(_timeline_elapsed(scene_timeline) > before_pause,
			"deleting the scene pause bridge must leave the scene runner advancing")
	host.controller().cancel()
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


func _test_presentation_admission_guards() -> void:
	var source := FileAccess.get_file_as_string(RUNTIME_SOURCE_PATH)
	_check(_has_admission_guards(source),
		"presentation begin must reject invalid manifests and missing scene paths before scene creation")
	_check(not _has_admission_guards(source.replace(MANIFEST_ADMISSION_GUARD, "return true")),
		"the invalid-manifest early-success mutation must fail this contract")
	_check(not _has_admission_guards(source.replace(SCENE_PATH_ADMISSION_GUARD, "return true")),
		"the missing-scene-path early-success mutation must fail this contract")


func _has_admission_guards(source: String) -> bool:
	var manifest_guard := source.find(MANIFEST_ADMISSION_GUARD)
	var scene_path_guard := source.find(SCENE_PATH_ADMISSION_GUARD)
	var scene_creation := source.find("_scene = packed.instantiate()")
	return manifest_guard >= 0 and scene_path_guard > manifest_guard and scene_creation > scene_path_guard


func _spawn_player(class_id: String, weapon_id: String) -> Node2D:
	var player := PlayerScene.instantiate() as Node2D
	_holder.add_child(player)
	await process_frame
	player.call("configure_character", class_id, weapon_id)
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


func _legacy_effect_count(parent: Node) -> int:
	if parent == null:
		return 0
	var count := 0
	for child in parent.get_children():
		if child.name == "VoidBurstVfx":
			count += 1
	return count


func _timeline_elapsed(timeline) -> float:
	return float(timeline.call("elapsed_seconds"))


func _advance_scene(scene: Node, delta: float) -> void:
	if scene.has_method("advance"):
		scene.call("advance", delta)
	elif scene.has_method("step"):
		scene.call("step", delta)


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
