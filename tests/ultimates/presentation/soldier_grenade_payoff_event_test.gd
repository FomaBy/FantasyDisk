extends SceneTree

## FAN-3941 — the Soldier grenade payoff is delivered by real executor events.
##
## Drives the shipped Player through the real ultimate host with the live
## authored presentation forced on headless, and lets the immutable executor
## run its whole 8.4 s cast against real enemies. It proves that the seven
## `.detonate` beats and the three `.crater` beats reach the live scene with
## the executor's own positions, radii, indices and timing; that the scene
## draws the blast ring and the burning crater from them (this is exactly what
## the pre-instrumentation candidate could not do, so the test fails there);
## that the seven-blast / three-crater damage mechanics and their times are
## unchanged; that a tree pause freezes the payoff; and that completion leaves
## no presentation, tween or node behind.
##
## Run:
## python3 tools/godot_gate.py --headless --path . \
##   --script res://tests/ultimates/presentation/soldier_grenade_payoff_event_test.gd

const PlayerScene := preload("res://scenes/Player.tscn")
const EnemyScene := preload("res://scenes/Enemy.tscn")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
const Executor := preload("res://scripts/ultimates/classes/soldier/soldier_grenade.gd")

const CLASS_ID := "soldier"
const WEAPON_ID := "soldier_grenade"
const SCENE_NAME := "SoldierGrenadeSevenSeconds"
## Enemies stand inside the crater radius around the real aim point, so the
## chain (one blast hit per target, deduplicated by the executor) and every
## crater tick reach each of them.
const ENEMY_OFFSETS := [Vector2(60.0, 0.0), Vector2(-70.0, 40.0), Vector2(20.0, -80.0)]
const ENEMY_HEALTH := 100000.0
const TIMEOUT_SECONDS := 12.0
const PAUSE_AT_SECONDS := 5.05
const PAUSE_FRAMES := 12
const TIME_TOLERANCE := 0.12
const BLAST_COUNT := 7
const CRATER_TICKS := 3
const FIRST_IMPACT := 4.7
const CHAIN_INTERVAL := 0.3
const CRATER_DELAY := 0.4
const CRATER_INTERVAL := 0.5
const BLAST_RADIUS := 155.0
const CRATER_RADIUS := 190.0

var _errors: Array[String] = []
var _holder: Node2D = null
var _player: Node2D = null
var _host: Node = null
var _enemies: Array[Node2D] = []
var _hits: Array[Dictionary] = []


func _initialize() -> void:
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	root.set_meta("combat_feedback", false)
	root.set_meta("screen_shake", true)
	await process_frame

	_player = PlayerScene.instantiate() as Node2D
	_holder.add_child(_player)
	await process_frame
	_player.call("configure_character", CLASS_ID, WEAPON_ID)
	await process_frame
	_player.set_process(false)
	_player.set_physics_process(false)
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
		enemy.connect("damage_applied", Callable(self, "_on_damage_applied").bind(enemy))
		_enemies.append(enemy)
	await process_frame

	await _run_cast()

	_player.queue_free()
	_holder.queue_free()
	await process_frame
	_report()


func _run_cast() -> void:
	var status: int = PlayerHost.activate(_player)
	_check(status == PlayerHost.ACTIVATION_STARTED, "activation must start, got %d (%s)" % [status, PlayerHost.activation_failure(_player)])
	if status != PlayerHost.ACTIVATION_STARTED:
		return
	var activation = _host.controller().active_activation()
	_check(activation != null, "an activation must be live")
	var points: PackedVector2Array = activation.primitive_value("points", PackedVector2Array()) if activation != null else PackedVector2Array()
	var target: Variant = activation.primitive_value("target") if activation != null else null
	_check(points.size() == BLAST_COUNT, "the executor must seed %d grenades, got %d" % [BLAST_COUNT, points.size()])
	_check(target is Vector2, "the executor must record its aim target")
	var scene := _holder.get_node_or_null(SCENE_NAME) as Node2D
	_check(scene != null and scene.has_method("payoff_snapshot"), "the authored grenade scene must be live under the effect parent with the payoff driver")
	if scene == null:
		return

	var beats: Array[Dictionary] = []
	var blast_edges: Array[Dictionary] = []
	var crater_edges: Array[Dictionary] = []
	var blast_was_lit := false
	var crater_was_lit := false
	var paused_done := false
	var pause_probe := {}
	var elapsed := 0.0
	var wall_start := Time.get_ticks_msec()
	while _host.call("ultimate_host_presentation_active") and elapsed < TIMEOUT_SECONDS:
		await process_frame
		elapsed = float(Time.get_ticks_msec() - wall_start) / 1000.0
		var presentation = _host.get("_presentation")
		if presentation != null:
			beats = presentation.recorded_beats()
		if not is_instance_valid(scene):
			break
		var snapshot: Dictionary = scene.call("payoff_snapshot")
		var blast_lit := float(snapshot["blast_alpha"]) > 0.05
		if blast_lit and not blast_was_lit:
			blast_edges.append({"elapsed": elapsed, "position": snapshot["blast_position"]})
		blast_was_lit = blast_lit
		var crater_lit := float(snapshot["crater_alpha"]) > 0.05
		if crater_lit and not crater_was_lit:
			crater_edges.append({"elapsed": elapsed, "position": snapshot["crater_position"]})
		crater_was_lit = crater_lit
		if not paused_done and elapsed >= PAUSE_AT_SECONDS:
			paused_done = true
			pause_probe = await _probe_pause(scene)
	_check(elapsed < TIMEOUT_SECONDS, "the cast must complete within %.1f s" % TIMEOUT_SECONDS)

	_check_beats(beats, points, target)
	_check_visible_payoff(beats, blast_edges, crater_edges, target)
	_check_damage(points.size())
	_check_pause(pause_probe)
	_check_cleanup(scene)


## While the tree is paused nothing may move: the ring alpha stays put and the
## timeline records no new beat.
func _probe_pause(scene: Node2D) -> Dictionary:
	var before: Dictionary = scene.call("payoff_snapshot")
	var beats_before: int = (_host.get("_presentation").recorded_beats() as Array).size()
	paused = true
	for _frame in PAUSE_FRAMES:
		await process_frame
	var after: Dictionary = scene.call("payoff_snapshot")
	var beats_after: int = (_host.get("_presentation").recorded_beats() as Array).size()
	paused = false
	return {
		"alpha_before": before["blast_alpha"], "alpha_after": after["blast_alpha"],
		"detonations_before": before["detonations"], "detonations_after": after["detonations"],
		"beats_before": beats_before, "beats_after": beats_after,
	}


func _check_beats(beats: Array[Dictionary], points: PackedVector2Array, target: Variant) -> void:
	var detonations: Array[Dictionary] = []
	var craters: Array[Dictionary] = []
	for beat in beats:
		var id := str(beat.get("event_id", ""))
		if id == Executor.EXECUTOR_ID + ".detonate":
			detonations.append(beat)
		elif id == Executor.EXECUTOR_ID + ".crater":
			craters.append(beat)
	_check(detonations.size() == BLAST_COUNT, "the live presentation must receive %d .detonate beats, got %d" % [BLAST_COUNT, detonations.size()])
	_check(craters.size() == CRATER_TICKS, "the live presentation must receive %d .crater beats, got %d" % [CRATER_TICKS, craters.size()])
	var seen_indices := {}
	var previous := -1.0
	for slot in detonations.size():
		var payload := detonations[slot].get("payload", {}) as Dictionary
		var index := int(payload.get("grenade_index", -1))
		_check(index >= 0 and index < points.size() and not seen_indices.has(index), "detonation %d must carry a unique grenade_index, got %d" % [slot, index])
		seen_indices[index] = true
		var position: Variant = payload.get("position")
		_check(position is Vector2 and index >= 0 and index < points.size() and (position as Vector2).is_equal_approx(points[index]), "detonation %d must carry the executor's blast position for grenade %d" % [slot, index])
		_check(is_equal_approx(float(payload.get("radius", 0.0)), BLAST_RADIUS), "detonation %d must carry the %.0f blast radius" % [slot, BLAST_RADIUS])
		_check(str(payload.get("shape", "")) == "orb_burst", "detonation %d must keep its orb_burst shape" % slot)
		var at := float(detonations[slot].get("elapsed_seconds", -1.0))
		var expected := FIRST_IMPACT + CHAIN_INTERVAL * float(slot)
		_check(absf(at - expected) <= TIME_TOLERANCE, "detonation %d must land at %.2f s on the presentation clock, got %.2f" % [slot, expected, at])
		_check(at > previous, "detonations must arrive in order")
		previous = at
	if target is Vector2:
		for slot in craters.size():
			var payload := craters[slot].get("payload", {}) as Dictionary
			var position: Variant = payload.get("position")
			_check(position is Vector2 and (position as Vector2).is_equal_approx(target as Vector2), "crater tick %d must carry the executor's aim centre" % slot)
			_check(is_equal_approx(float(payload.get("radius", 0.0)), CRATER_RADIUS), "crater tick %d must carry the %.0f crater radius" % [slot, CRATER_RADIUS])
			_check(int(payload.get("tick", -1)) == slot and int(payload.get("ticks", 0)) == CRATER_TICKS, "crater tick %d must carry tick/ticks metadata" % slot)
			var at := float(craters[slot].get("elapsed_seconds", -1.0))
			var expected := FIRST_IMPACT + CHAIN_INTERVAL * float(BLAST_COUNT - 1) + CRATER_DELAY + CRATER_INTERVAL * float(slot)
			_check(absf(at - expected) <= TIME_TOLERANCE, "crater tick %d must land at %.2f s on the presentation clock, got %.2f" % [slot, expected, at])


## The scene must have drawn every blast at its beat position and the crater at
## the aim centre; a presentation that never lights the ring or the column is
## the unreachable-payoff defect this card repairs.
func _check_visible_payoff(beats: Array[Dictionary], blast_edges: Array[Dictionary], crater_edges: Array[Dictionary], target: Variant) -> void:
	_check(blast_edges.size() >= BLAST_COUNT, "the blast ring must light once per detonation, lit %d times" % blast_edges.size())
	var beat_positions: Array[Vector2] = []
	for beat in beats:
		if str(beat.get("event_id", "")) == Executor.EXECUTOR_ID + ".detonate":
			beat_positions.append((beat.get("payload", {}) as Dictionary).get("position", Vector2.INF))
	for edge in blast_edges:
		var drawn := edge["position"] as Vector2
		var matched := target is Vector2 and drawn.distance_to(target as Vector2) <= 1.0
		for position in beat_positions:
			if drawn.distance_to(position) <= 1.0:
				matched = true
		_check(matched, "a ring lit at %s must sit on a detonation position or the crater centre" % drawn)
	_check(crater_edges.size() >= 1, "the fire column must light for the crater")
	if target is Vector2 and not crater_edges.is_empty():
		_check((crater_edges[0]["position"] as Vector2).distance_to(target as Vector2) <= 1.0, "the fire column must rise on the crater centre")


## The executor deduplicates the chain per target (one blast hit each, event
## `soldier_grenade_hit`) and burns three crater ticks on everything inside the
## crater radius: exactly the pre-instrumentation mechanics.
func _check_damage(_blasts: int) -> void:
	for enemy in _enemies:
		var chain: Array[float] = []
		var crater: Array[float] = []
		var last_chain_index := -1
		for hit in _hits:
			if hit["enemy"] != enemy:
				continue
			var feedback := hit["feedback"] as Dictionary
			match str(feedback.get("ultimate_mechanic", "")):
				"seven_grenade_chain":
					chain.append(float(hit["applied"]))
					_check(int(feedback.get("grenade_index", -1)) > last_chain_index or last_chain_index < 0, "chain hits must keep their grenade order")
					last_chain_index = int(feedback.get("grenade_index", -1))
				"burning_crater":
					crater.append(float(hit["applied"]))
		_check(chain.size() == 1, "%s must take exactly one deduplicated chain hit, took %d" % [enemy.name, chain.size()])
		_check(crater.size() == CRATER_TICKS, "%s must take exactly %d crater ticks, took %d" % [enemy.name, CRATER_TICKS, crater.size()])
		for value in chain:
			_check(value > 0.0, "%s chain hit must deal damage" % enemy.name)
		for value in crater:
			_check(value > 0.0 and is_equal_approx(value, crater[0]), "%s crater ticks must all deal the same damage" % enemy.name)
		if not chain.is_empty() and not crater.is_empty():
			_check(crater[0] < chain[0], "%s crater ticks must stay lighter than the blasts" % enemy.name)


func _check_pause(probe: Dictionary) -> void:
	_check(not probe.is_empty(), "the pause probe must run mid-chain")
	if probe.is_empty():
		return
	_check(is_equal_approx(float(probe["alpha_before"]), float(probe["alpha_after"])), "a tree pause must freeze the blast ring (%.3f -> %.3f)" % [float(probe["alpha_before"]), float(probe["alpha_after"])])
	_check(int(probe["detonations_before"]) == int(probe["detonations_after"]), "a tree pause must not detonate")
	_check(int(probe["beats_before"]) == int(probe["beats_after"]), "a tree pause must not deliver beats")


func _check_cleanup(scene: Variant) -> void:
	_check(not bool(_host.call("ultimate_host_presentation_active")), "the presentation must be released when the cast completes")
	_check(_host.controller().active_activation() == null, "the activation must be finished")
	_check(not is_instance_valid(scene) or not (scene as Node).is_inside_tree(), "the authored scene must leave the tree with the cast")
	_check(_holder.get_node_or_null(SCENE_NAME) == null, "no grenade scene may linger under the effect parent")
	for enemy in _enemies:
		_check(is_instance_valid(enemy) and float(enemy.get("health")) > 0.0, "%s must survive the probe" % enemy.name)


func _on_damage_applied(_target: Node2D, attempted: float, applied: float, feedback: Dictionary, enemy: Node2D) -> void:
	_hits.append({"enemy": enemy, "attempted": attempted, "applied": applied, "feedback": feedback.duplicate(true)})


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("Soldier grenade payoff events passed (7 detonation + 3 crater beats reached the live scene with executor positions and times, ring and crater drawn, damage unchanged, pause frozen, cleanup clean).")
		quit(0)
		return
	for error in _errors:
		push_error("Soldier grenade payoff events: %s" % error)
	quit(1)
