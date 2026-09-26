extends SceneTree

## FAN-3943 — Knight Long Spear keeps only its authored presentation alive
## after the unchanged 1.4-second gameplay boundary.
##
## This drives the shipped Player, executor, Enemy and presentation scene. It
## locks the combat contract (one damage event, 1.2-second leased pin, charge
## and active latch), proves the 2.8-second recovery is visible until the
## 3.4-second presentation cancel, and covers every way a visual tail can end.
##
## Run:
## python3 tools/godot_gate.py --headless --path . \
##   --script res://tests/ultimates/ultimate_presentation_tail_lifetime_test.gd

const PlayerScene := preload("res://scenes/Player.tscn")
const EnemyScene := preload("res://scenes/Enemy.tscn")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")

const CLASS_ID := "knight"
const WEAPON_ID := "long_spear"
const PRESENTATION_SCENE := "KnightLongSpearSpearWall"
const CONFIG_PATH := "res://data/ultimates/classes/knight/long_spear.json"
const MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/knight/manifest.json"
const GAMEPLAY_SECONDS := 1.4
const PIN_SECONDS := 1.2
const RECOVERY_SECONDS := 2.8
const CANCEL_SECONDS := 3.4
const CLEANUP_FRAMES := 2
const FRAME_SECONDS := 1.0 / 60.0
const UNSCALED_PROBE_SECONDS := 0.40
const MIN_UNSCALED_ADVANCE := 0.25

var _errors: Array[String] = []
var _holder: Node2D = null
var _player: Node2D = null
var _enemy: Node2D = null
var _host: Node = null
var _elapsed := 0.0
var _last_delta := FRAME_SECONDS
var _original_time_scale := 1.0


func _initialize() -> void:
	_original_time_scale = Engine.time_scale
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	root.set_meta("combat_feedback", false)
	root.set_meta("screen_shake", false)
	await process_frame

	_check_unchanged_declarations()
	await _test_recovery_tail_preserves_combat_boundary()
	await _test_force_cancel_after_combat_completion()
	await _test_new_activation_supersedes_old_tail()
	await _test_pause_and_time_scale()
	await _test_teardown_cleans_tail()

	Engine.time_scale = _original_time_scale
	paused = false
	_holder.queue_free()
	await process_frame
	_report()


func _check_unchanged_declarations() -> void:
	var config := _load_json(CONFIG_PATH)
	var params := ((config.get("executor", {}) as Dictionary).get("params", {}) as Dictionary)
	_check(is_equal_approx(float(params.get("recover_time", -1.0)), GAMEPLAY_SECONDS),
		"Long Spear gameplay recover_time must remain 1.4 seconds")
	_check(is_equal_approx(float(params.get("pin_duration", -1.0)), PIN_SECONDS),
		"Long Spear pin_duration must remain 1.2 seconds")
	var manifest := _load_json(MANIFEST_PATH)
	var timing := {}
	for raw_weapon in manifest.get("weapons", []) as Array:
		var weapon := raw_weapon as Dictionary
		if str(weapon.get("weapon_id", "")) == WEAPON_ID:
			timing = (weapon.get("timing_seconds", {}) as Dictionary).duplicate(true)
			break
	_check(is_equal_approx(float(timing.get("recovery", -1.0)), RECOVERY_SECONDS),
		"Long Spear presentation recovery must remain 2.8 seconds")
	_check(is_equal_approx(float(timing.get("cancel", -1.0)), CANCEL_SECONDS),
		"Long Spear presentation cancel must remain 3.4 seconds")


func _test_recovery_tail_preserves_combat_boundary() -> void:
	await _spawn()
	var scene := await _cast()
	if scene == null:
		await _despawn()
		return
	_check(is_zero_approx(float(_player.get("ultimate_charge"))),
		"activation must spend the charge exactly once")
	await _advance_until(1.0)
	var health_after_hit := float(_enemy.get("health"))
	_check(health_after_hit < float(_enemy.get("max_health")),
		"Long Spear must deal its shipped damage before gameplay completion")
	_check(_has_long_spear_pin(), "the shipped pin must be live during the combat window")

	await _advance_until(GAMEPLAY_SECONDS + 0.15)
	_check(not _host.controller().is_active() and not bool(_player.get("_ultimate_active")),
		"gameplay and the charge gate must close at the unchanged 1.4-second boundary")
	_check(not _has_long_spear_pin(),
		"the leased pin must be removed when gameplay ends, not when the visual tail ends")
	_check(bool(_host.call("ultimate_host_presentation_draining")) and is_instance_valid(scene),
		"the authored scene alone must drain after gameplay completion")
	_player.call("_gain_ultimate_charge", float(_player.get("ultimate_max_charge")))
	_check(bool(_player.call("ultimate_ready")),
		"charge gain must resume while the presentation-only tail is visible")

	await _advance_until(RECOVERY_SECONDS)
	_check(is_instance_valid(scene) and scene.is_inside_tree(),
		"Long Spear presentation must still be visible at the 2.8-second recovery beat")
	for path in ["CorridorGuide", "Phalanx/RankOne", "BannerLine"]:
		var node := scene.get_node_or_null(NodePath(path)) as CanvasItem
		_check(node != null and node.visible, "recovery must retain visible node %s" % path)
	_check(is_equal_approx(float(_enemy.get("health")), health_after_hit),
		"the presentation tail must not deal damage after gameplay completion "
		+ "(at 1.0s %.3f, at recovery %.3f)" % [health_after_hit, float(_enemy.get("health"))])
	_check(not _has_long_spear_pin(), "the presentation tail must not recreate the pin")

	var last_live_clock := _presentation_elapsed()
	while is_instance_valid(scene) and _elapsed < CANCEL_SECONDS + 0.25:
		last_live_clock = _presentation_elapsed()
		await _tick()
	_check(not is_instance_valid(scene),
		"Long Spear presentation must be released at its 3.4-second cancel")
	_check(last_live_clock < CANCEL_SECONDS
		and CANCEL_SECONDS - last_live_clock <= _frame_tolerance(),
		"last live presentation frame %.3f must sit within one frame of 3.4 seconds" % last_live_clock)
	_check(_host.get("_presentation") == null and _presentation_nodes() == 0,
		"natural tail completion must leave no presentation node")
	await _despawn()


func _test_force_cancel_after_combat_completion() -> void:
	await _spawn()
	var scene := await _cast()
	if scene == null:
		await _despawn()
		return
	await _advance_until(GAMEPLAY_SECONDS + 0.15)
	_check(bool(_host.call("ultimate_host_presentation_draining")),
		"force-cancel fixture must reach a presentation-only tail")
	_host.controller().cancel("cancel")
	for _frame in CLEANUP_FRAMES:
		await _tick()
	_check(not is_instance_valid(scene) and _host.get("_presentation") == null,
		"force cancel after combat completion must release the visual tail immediately")
	await _despawn()


func _test_new_activation_supersedes_old_tail() -> void:
	await _spawn()
	var old_scene := await _cast()
	if old_scene == null:
		await _despawn()
		return
	await _advance_until(GAMEPLAY_SECONDS + 0.15)
	_player.set("ultimate_charge", float(_player.get("ultimate_max_charge")))
	_check(bool(_player.call("activate_ultimate")),
		"a new activation must be available at the unchanged gameplay boundary")
	var new_scene := _live_scene()
	_check(new_scene != null and new_scene != old_scene,
		"the new activation must replace the draining scene with a fresh one")
	await _tick()
	_check(not is_instance_valid(old_scene), "the superseded tail must be released")
	_elapsed = 0.0
	await _advance_until(1.95)
	_check(new_scene != null and is_instance_valid(new_scene)
		and bool(_host.call("ultimate_host_presentation_draining")),
		"an old tail deadline must not end the later activation's presentation")
	_host.controller().cancel("cancel")
	await _tick()
	await _despawn()


func _test_pause_and_time_scale() -> void:
	await _spawn()
	var scene := await _cast()
	if scene == null:
		await _despawn()
		return
	await _advance_until(GAMEPLAY_SECONDS + 0.15)
	var before_scale := _presentation_elapsed()
	Engine.time_scale = 0.35
	await create_timer(UNSCALED_PROBE_SECONDS, false, false, true).timeout
	var after_scale := _presentation_elapsed()
	_check(after_scale - before_scale >= MIN_UNSCALED_ADVANCE,
		"presentation tail must use the unscaled presentation clock under non-default time scale")
	paused = true
	var before_pause := _presentation_elapsed()
	for _frame in 12:
		await process_frame
	var after_pause := _presentation_elapsed()
	paused = false
	Engine.time_scale = _original_time_scale
	_check(is_equal_approx(before_pause, after_pause),
		"tree pause must freeze the presentation tail clock")
	_check(is_instance_valid(scene), "pause and time-scale changes must not discard the tail")
	_host.controller().cancel("cancel")
	await _tick()
	await _despawn()


func _test_teardown_cleans_tail() -> void:
	await _spawn()
	var scene := await _cast()
	if scene == null:
		await _despawn()
		return
	await _advance_until(GAMEPLAY_SECONDS + 0.15)
	_holder.remove_child(_player)
	for _frame in CLEANUP_FRAMES:
		await process_frame
	_check(not is_instance_valid(scene) and _host.get("_presentation") == null,
		"player teardown must clear a presentation tail after the activation is null")
	_player.queue_free()
	_player = null
	await _despawn()


func _spawn() -> void:
	_player = PlayerScene.instantiate() as Node2D
	_holder.add_child(_player)
	await process_frame
	_player.call("configure_character", CLASS_ID, WEAPON_ID)
	await process_frame
	_player.set_process(false)
	_player.set_physics_process(false)
	for raw_weapon in get_nodes_in_group("player_weapons"):
		var weapon := raw_weapon as Node
		if weapon != null and _player.is_ancestor_of(weapon):
			weapon.process_mode = Node.PROCESS_MODE_DISABLED
	_host = PlayerHost.for_player(_player)
	_host.set("_presentation_headless_mode", 0)
	_enemy = EnemyScene.instantiate() as Node2D
	_enemy.set("max_health", 100000.0)
	_enemy.set("health", 100000.0)
	_holder.add_child(_enemy)
	_enemy.set_process(false)
	_enemy.set_physics_process(false)
	_enemy.global_position = _player.global_position + Vector2(300.0, 0.0)
	await process_frame
	_elapsed = 0.0


func _cast() -> Node:
	_player.set("ultimate_charge", float(_player.get("ultimate_max_charge")))
	var started := bool(_player.call("activate_ultimate"))
	_check(started, "Knight Long Spear must activate through the shipped Player")
	if not started:
		return null
	var scene := _live_scene()
	_check(scene != null and scene.name == PRESENTATION_SCENE,
		"the shipped Long Spear presentation scene must be live")
	return scene


func _despawn() -> void:
	Engine.time_scale = _original_time_scale
	paused = false
	if _player != null and is_instance_valid(_player):
		_player.queue_free()
	if _enemy != null and is_instance_valid(_enemy):
		_enemy.queue_free()
	_player = null
	_enemy = null
	_host = null
	await process_frame
	await process_frame
	for child in _holder.get_children():
		child.free()
	_check(_presentation_nodes() == 0, "fixture cleanup must leave no presentation node")


func _live_scene() -> Node:
	var presentation = _host.get("_presentation") if _host != null else null
	if presentation == null:
		return null
	var scene = presentation.get("_scene")
	return scene as Node if scene is Node and is_instance_valid(scene) else null


func _presentation_elapsed() -> float:
	var presentation = _host.get("_presentation") if _host != null else null
	if presentation == null:
		return -1.0
	var timeline = presentation.get("_timeline")
	return float(timeline.elapsed_seconds()) if timeline != null else -1.0


func _has_long_spear_pin() -> bool:
	if _enemy == null or not is_instance_valid(_enemy):
		return false
	for status_id in StatusEffects.snapshot(_enemy):
		if str(status_id).begins_with("knight_long_spear_pin_"):
			return true
	return false


func _tick() -> void:
	await process_frame
	_last_delta = maxf(root.get_process_delta_time(), 0.0001) / maxf(Engine.time_scale, 0.0001)
	_elapsed += _last_delta


func _advance_until(seconds: float) -> void:
	while _elapsed < seconds:
		await _tick()


func _frame_tolerance() -> float:
	return maxf(2.0 * _last_delta, FRAME_SECONDS + 0.005)


func _presentation_nodes() -> int:
	var count := 0
	for child in _holder.get_children():
		if (child as Node).has_meta("ultimate_id"):
			count += 1
	return count


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("ultimate_presentation_tail_lifetime_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("ultimate_presentation_tail_lifetime_test: %s" % error)
	print("ultimate_presentation_tail_lifetime_test: FAIL (%d)" % _errors.size())
	quit(1)
