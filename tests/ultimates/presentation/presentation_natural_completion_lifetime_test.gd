extends SceneTree

## FAN-3941 — natural completion keeps the authored presentation alive until
## its declared cancel; every explicit ending still releases it at once.
##
## The Thief coin-pouch executor completes after one hop per target (about
## 0.3 s with three targets) and the shadow-cloak executor after its eight
## strikes (about 1.3 s), long before their declared 3.05 s / 3.20 s
## presentations end. Before this repair the host released the authored
## scene the instant the activation completed, so the declared active and
## recovery beats never played in the real game (this test fails there).
##
## Drives the shipped Player through the real ultimate host with the live
## authored presentation forced on headless, against real enemies, and proves:
## - gameplay completes at the existing instant (controller inactive, the
##   Player's ultimate flag cleared) while the presentation keeps draining;
## - both Thief keys reach their active and recovery beats: the coin scene is
##   live at 1.0 s and 2.5 s and freed at 3.05 s within a frame, the cloak
##   scene at 3.20 s within a frame;
## - explicit cancel, death, reset, exit and a replacing activation clean a
##   draining presentation within two frames, leaving no node behind;
## - a tree pause freezes the drain, and supplied beats still route to the
##   draining presentation without drawing anything over it;
## - a long-lived executor (Soldier grenade, 8.4 s) is not shortened to its
##   3.5 s presentation boundary.
##
## Run (the fixed clock makes "within a frame" exact; the real clock is also
## accepted, with the tolerance derived from the observed frame time):
## python3 tools/godot_gate.py --headless --path . --fixed-fps 60 \
##   --script res://tests/ultimates/presentation/presentation_natural_completion_lifetime_test.gd

const PlayerScene := preload("res://scenes/Player.tscn")
const EnemyScene := preload("res://scenes/Enemy.tscn")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
const PresentationManifest := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_manifest.gd")

const ENEMY_OFFSETS := [Vector2(60.0, 0.0), Vector2(-70.0, 40.0), Vector2(20.0, -80.0)]
const ENEMY_HEALTH := 100000.0
const COIN := {"class_id": "thief", "weapon_id": "thief_coin_pouch", "scene": "ThiefCoinPouchUltimate"}
const CLOAK := {"class_id": "thief", "weapon_id": "thief_shadow_cloak", "scene": "ThiefShadowCloakUltimate"}
const GRENADE := {"class_id": "soldier", "weapon_id": "soldier_grenade", "scene": "SoldierGrenadeSevenSeconds"}
const DRAIN_PROBE_SECONDS := 1.0
const PAUSE_FRAMES := 10
const CLEANUP_FRAMES := 2
const GRENADE_EXECUTOR_SECONDS := 8.4
const TIMEOUT_SECONDS := 12.0

var _errors: Array[String] = []
var _holder: Node2D = null
var _player: Node2D = null
var _host: Node = null
var _enemies: Array[Node2D] = []
var _elapsed := 0.0
var _last_delta := 1.0 / 60.0


func _initialize() -> void:
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	root.set_meta("combat_feedback", false)
	root.set_meta("screen_shake", true)
	await process_frame

	await _test_natural_completion_drains_to_cancel(COIN, [1.0, 2.5])
	await _test_natural_completion_drains_to_cancel(CLOAK, [2.0, 2.5])
	await _test_explicit_ending_cleans_drain("cancel")
	await _test_explicit_ending_cleans_drain("death")
	await _test_explicit_ending_cleans_drain("reset")
	await _test_explicit_ending_cleans_drain("exit")
	await _test_explicit_ending_cleans_drain("replacement")
	await _test_pause_freezes_drain()
	await _test_beats_route_during_drain()
	await _test_long_executor_is_not_shortened()

	_holder.queue_free()
	await process_frame
	_report()


# --- cases ---------------------------------------------------------------------


func _test_natural_completion_drains_to_cancel(weapon: Dictionary, probes: Array) -> void:
	var label := str(weapon["weapon_id"])
	await _spawn(weapon)
	var timing := _timing(weapon)
	var cancel_at := float(timing.get("cancel", 0.0))
	var scene := await _cast(weapon)
	if scene == null:
		await _despawn()
		return
	var gameplay_done_at := -1.0
	var released_at := -1.0
	var last_live_presentation_elapsed := -1.0
	var live_at_probe := {}
	var frames_after_cancel := 0
	while _elapsed < cancel_at + 0.5 and frames_after_cancel < 6:
		await _tick()
		if is_instance_valid(scene) and _presentation_elapsed() >= 0.0:
			last_live_presentation_elapsed = _presentation_elapsed()
		if gameplay_done_at < 0.0 and not _host.controller().is_active():
			gameplay_done_at = _elapsed
		for probe in probes:
			if not live_at_probe.has(probe) and _elapsed >= float(probe):
				live_at_probe[probe] = {
					"scene_live": is_instance_valid(scene) and scene.is_inside_tree(),
					"presentation": bool(_host.call("ultimate_host_presentation_active")),
					"gameplay_active": _host.controller().is_active() or bool(_player.get("_ultimate_active")),
					"elapsed": _elapsed,
				}
		if released_at < 0.0 and not is_instance_valid(scene):
			released_at = _elapsed
		if _elapsed >= cancel_at:
			frames_after_cancel += 1
	_check(gameplay_done_at >= 0.0 and gameplay_done_at < float(probes[0]), "%s: gameplay must complete at its existing instant, well before the drain probes (completed at %.3f s)" % [label, gameplay_done_at])
	for probe in probes:
		var state: Dictionary = live_at_probe.get(probe, {})
		_check(bool(state.get("scene_live", false)) and bool(state.get("presentation", false)), "%s: the authored scene must be live at %.1f s (state %s)" % [label, float(probe), str(state)])
		_check(not bool(state.get("gameplay_active", true)), "%s: gameplay must be inactive while the presentation drains at %.1f s" % [label, float(probe)])
	_check(released_at >= 0.0, "%s: the presentation must be released by %.2f s + 6 frames" % [label, cancel_at])
	if released_at >= 0.0:
		# The scene is freed on the frame the presentation's own clock reaches
		# the declared cancel: the last frame it was alive sits within a frame
		# below that bound and the bound was never overrun.
		_check(last_live_presentation_elapsed < cancel_at and cancel_at - last_live_presentation_elapsed <= _frame_tolerance(), "%s: the presentation must end at its declared cancel %.2f s within a frame (last live presentation clock %.3f s, tolerance %.3f)" % [label, cancel_at, last_live_presentation_elapsed, _frame_tolerance()])
	_check(_host.get("_presentation") == null, "%s: the host must drop the drained presentation" % label)
	_check(_presentation_nodes() == 0, "%s: no presentation node may outlive the drain (%d remain)" % [label, _presentation_nodes()])
	await _despawn()


func _test_explicit_ending_cleans_drain(ending: String) -> void:
	var label := "coin pouch drain ended by %s" % ending
	await _spawn(COIN)
	var scene := await _cast(COIN)
	if scene == null:
		await _despawn()
		return
	await _advance_until(DRAIN_PROBE_SECONDS)
	_check(not _host.controller().is_active() and is_instance_valid(scene) and bool(_host.call("ultimate_host_presentation_draining")), "%s: precondition — gameplay done, presentation draining at %.2f s" % [label, _elapsed])
	var replacement: Node = null
	match ending:
		"cancel":
			_host.controller().cancel()
		"death":
			_player.emit_signal("died")
		"reset":
			PlayerHost.reset(_player)
		"exit":
			_holder.remove_child(_player)
		"replacement":
			_player.set("ultimate_charge", _player.get("ultimate_max_charge"))
			var status: int = PlayerHost.activate(_player)
			_check(status == PlayerHost.ACTIVATION_STARTED, "%s: the replacing activation must start, got %d (%s)" % [label, status, PlayerHost.activation_failure(_player)])
			replacement = _live_scene()
	for _frame in CLEANUP_FRAMES:
		await _tick()
	_check(not is_instance_valid(scene), "%s: the drained scene must be freed within %d frames" % [label, CLEANUP_FRAMES])
	if ending == "replacement":
		_check(replacement != null and is_instance_valid(replacement) and replacement != scene and _live_scene() == replacement, "%s: the new activation must own a fresh live presentation" % label)
		_host.controller().cancel()
		for _frame in CLEANUP_FRAMES:
			await _tick()
	elif ending == "exit":
		_check(_host.get("_presentation") == null, "%s: leaving the tree must drop the presentation" % label)
		_player.queue_free()
		_player = null
	else:
		_check(_host.get("_presentation") == null and not _host.controller().is_active(), "%s: the host must hold no presentation afterwards" % label)
	_check(_presentation_nodes() == 0, "%s: no presentation node may remain (%d remain)" % [label, _presentation_nodes()])
	await _despawn()


func _test_pause_freezes_drain() -> void:
	var label := "coin pouch drain under pause"
	await _spawn(COIN)
	var scene := await _cast(COIN)
	if scene == null:
		await _despawn()
		return
	await _advance_until(DRAIN_PROBE_SECONDS)
	var before := _presentation_elapsed()
	paused = true
	for _frame in PAUSE_FRAMES:
		await process_frame
	var during := _presentation_elapsed()
	paused = false
	_check(is_instance_valid(scene) and is_equal_approx(before, during), "%s: a paused tree must freeze the drain (%.3f vs %.3f)" % [label, before, during])
	await _tick()
	_check(_presentation_elapsed() > during, "%s: the drain must resume after unpausing" % label)
	_host.controller().cancel()
	await _tick()
	await _despawn()


func _test_beats_route_during_drain() -> void:
	var label := "coin pouch beats during drain"
	await _spawn(COIN)
	var scene := await _cast(COIN)
	if scene == null:
		await _despawn()
		return
	await _advance_until(DRAIN_PROBE_SECONDS)
	var presentation = _host.get("_presentation")
	var before: int = presentation.recorded_beats().size() if presentation != null else -1
	var children := _effect_children()
	var drawn = _host.call("ultimate_host_present", "fixture.beat", {"shape": "ring_pulse", "radius": 120.0})
	var after: int = presentation.recorded_beats().size() if presentation != null else -1
	_check(drawn == null and after == before + 1, "%s: a supplied beat must reach the draining presentation and draw nothing over it (drawn %s, beats %d -> %d)" % [label, str(drawn), before, after])
	_check(_effect_children() == children, "%s: a routed beat must not add a node over the live presentation" % label)
	_host.controller().cancel()
	await _tick()
	await _despawn()


func _test_long_executor_is_not_shortened() -> void:
	var label := "soldier grenade (8.4 s executor)"
	await _spawn(GRENADE)
	var cancel_at := float(_timing(GRENADE).get("cancel", 0.0))
	var scene := await _cast(GRENADE)
	if scene == null:
		await _despawn()
		return
	var released_at := -1.0
	var gameplay_done_at := -1.0
	while _elapsed < TIMEOUT_SECONDS:
		await _tick()
		if gameplay_done_at < 0.0 and not _host.controller().is_active():
			gameplay_done_at = _elapsed
		if not is_instance_valid(scene):
			released_at = _elapsed
			break
	# The executor's own scheduled end (about 8.4 s) is long past the 3.5 s
	# presentation boundary, so there is nothing to drain: the presentation
	# ends on the frame gameplay completes, neither shortened nor extended.
	_check(gameplay_done_at > cancel_at + 4.0 and gameplay_done_at >= GRENADE_EXECUTOR_SECONDS - 0.2, "%s: the executor must keep its own lifetime past the %.1f s presentation boundary, completed at %.3f s" % [label, cancel_at, gameplay_done_at])
	_check(released_at >= 0.0 and absf(released_at - gameplay_done_at) <= _frame_tolerance(), "%s: the presentation must end with its executor (gameplay %.3f s, released %.3f s)" % [label, gameplay_done_at, released_at])
	_check(_host.get("_presentation") == null and not _host.controller().is_active(), "%s: completion must leave no presentation" % label)
	await _despawn()


# --- world ---------------------------------------------------------------------


func _spawn(weapon: Dictionary) -> void:
	_player = PlayerScene.instantiate() as Node2D
	_holder.add_child(_player)
	await process_frame
	_player.call("configure_character", str(weapon["class_id"]), str(weapon["weapon_id"]))
	await process_frame
	_player.set_process(false)
	_player.set_physics_process(false)
	_player.set("ultimate_charge", _player.get("ultimate_max_charge"))
	_host = PlayerHost.for_player(_player)
	_host.set("_presentation_headless_mode", 0)
	var aim: Vector2 = _player.call("attack_aim_position", 720.0)
	for offset in ENEMY_OFFSETS:
		var enemy := EnemyScene.instantiate() as Node2D
		enemy.position = aim + offset
		enemy.set("max_health", ENEMY_HEALTH)
		enemy.set("health", ENEMY_HEALTH)
		_holder.add_child(enemy)
		enemy.set_physics_process(false)
		_enemies.append(enemy)
	await process_frame
	_elapsed = 0.0


func _despawn() -> void:
	# The game's own transient hit VFX and damage numbers self-free on their
	# tweens; they are outside the presentation channel, so they are given
	# their time before the arena is torn down.
	var waited := 0.0
	while _presentation_nodes() == 0 and _holder.get_child_count() > 1 + _enemies.size() and waited < 4.0:
		await _tick()
		waited += _last_delta
	if _player != null and is_instance_valid(_player):
		_player.queue_free()
	_player = null
	_host = null
	for enemy in _enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_enemies.clear()
	await process_frame
	await process_frame
	_check(_presentation_nodes() == 0, "a finished cast must leave no presentation node behind: %s" % _child_names())
	for child in _holder.get_children():
		child.free()


func _cast(weapon: Dictionary) -> Node:
	var status: int = PlayerHost.activate(_player)
	_check(status == PlayerHost.ACTIVATION_STARTED, "%s: activation must start, got %d (%s)" % [str(weapon["weapon_id"]), status, PlayerHost.activation_failure(_player)])
	if status != PlayerHost.ACTIVATION_STARTED:
		return null
	_elapsed = 0.0
	var scene := _live_scene()
	_check(scene != null and scene.name == str(weapon["scene"]), "%s: the authored scene must be live under the effect parent" % str(weapon["weapon_id"]))
	return scene


func _live_scene() -> Node:
	var presentation = _host.get("_presentation")
	if presentation == null:
		return null
	var scene = presentation.get("_scene")
	return scene as Node if scene is Node and is_instance_valid(scene) else null


func _presentation_elapsed() -> float:
	var presentation = _host.get("_presentation")
	if presentation == null:
		return -1.0
	var timeline = presentation.get("_timeline")
	return float(timeline.elapsed_seconds()) if timeline != null else -1.0


## Wall-clock seconds: the engine hands nodes a delta already multiplied by
## Engine.time_scale, so it is divided back out. This is the clock both sides
## of the seam run on — the host advances the presentation by
## delta / Engine.time_scale, and an activation's tweens ignore the time scale
## — so a first-impact dip (Soldier grenade 0.40 for 120 ms) cannot make the
## test's clock drift from theirs by a frame-rate-dependent amount.
func _tick() -> void:
	await process_frame
	_last_delta = maxf(root.get_process_delta_time(), 0.0001) / maxf(Engine.time_scale, 0.0001)
	_elapsed += _last_delta


func _advance_until(seconds: float) -> void:
	while _elapsed < seconds:
		await _tick()


func _frame_tolerance() -> float:
	return maxf(2.0 * _last_delta, 1.0 / 60.0 + 0.005)


func _timing(weapon: Dictionary) -> Dictionary:
	return PresentationManifest.class_weapon_record(str(weapon["class_id"]), str(weapon["weapon_id"])).get("timing", {}) as Dictionary


func _effect_children() -> int:
	return _holder.get_child_count()


## Authored presentation scenes carry the `ultimate_id` metadata of their
## class/weapon pair; nothing else in the arena does.
func _presentation_nodes() -> int:
	var count := 0
	for child in _holder.get_children():
		if (child as Node).has_meta("ultimate_id"):
			count += 1
	return count


func _child_names() -> String:
	var names: Array[String] = []
	for child in _holder.get_children():
		names.append(str(child.name))
	return ", ".join(names)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("Presentation natural-completion lifetime passed (Thief coin pouch and shadow cloak drain to their declared cancel with gameplay inactive; cancel/death/reset/exit/replacement clean within two frames; pause freezes the drain; beats route; the Soldier grenade keeps its 8.4 s executor).")
		quit(0)
		return
	for error in _errors:
		push_error("presentation_natural_completion_lifetime_test: %s" % error)
	print("presentation_natural_completion_lifetime_test: FAIL (%d)" % _errors.size())
	quit(1)
