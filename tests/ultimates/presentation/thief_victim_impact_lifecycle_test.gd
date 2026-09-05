extends SceneTree

## Controller-level victim-impact lifecycle proof for every canonical Thief
## ultimate (FAN-3886 rework). Each cast runs the real Registry → Controller →
## executor → activation path with no manual tween stepping and no manual
## advance() on the ripple. Two contours per weapon: a late-hit run (targets
## survive to the cast's last beat) must still show live bursts after the
## controller tears its effect down, and an early-lethal run (every target
## dies on the first beat, like enemy.gd's death fallback) must still spawn
## and play one burst per killed victim for the mandated burst window. Both
## must release player, markers and bursts promptly after the ripple drains —
## the empty player may not be retained beyond the conservative ripple bound.

const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "thief"
const WEAPON_IDS := ["thief_coin_pouch", "thief_shadow_cloak", "thief_smoke_bomb"]
const MAX_CAST_FRAMES := 6000
const MAX_DRAIN_FRAMES := 6000
## Cleanup oracle timing origin (PM publication reconciliation): simulation
## time from the ripple's LAST enqueue/collapse to the player's release,
## bounded by exactly the release window the executors arm — the shared
## service's conservative ripple bound (widest stagger, full burst, margin),
## recomputed from the service constants — plus an explicit process-frame
## scheduling tolerance. Wall-clock or last-burst-frame origins are not
## accepted: a release that re-waits a whole cast duration (the Smoke Bomb
## defect) lands far outside and fails.
const CLEANUP_FRAME_TOLERANCE_SECONDS := 0.25
const BURST_WINDOW_MIN_SECONDS := 0.30
const BURST_WINDOW_MAX_SECONDS := 0.60


class FixtureTarget extends Node2D:
	var health := 5000.0
	var max_health := 5000.0
	var flashes := 0
	var damage_flashes := 0
	var dies_on_damage := false

	func _combat_feedback_enabled() -> bool:
		return true

	## The real enemy flashes on the damage path (enemy.gd _show_combat_feedback);
	## the count is kept apart so the impact's own flash contribution is visible.
	## A lethal hit ends like enemy.gd's death fallback: the node is freed at the
	## end of this frame, before the ripple's next _process reads it.
	func take_damage(amount: float, _feedback := {}) -> void:
		health = maxf(health - amount, 0.0)
		if amount > 0.0:
			damage_flashes += 1
			_show_hit_flash()
		if dies_on_damage and is_zero_approx(health):
			queue_free()

	func _show_hit_flash() -> void:
		flashes += 1


class FixtureHost extends Node2D:
	var fixture_targets: Array[Node2D] = []
	var damage_calls := 0
	var modifiers := {"dodge_flat": 0.0}

	func ultimate_host_context() -> Dictionary:
		return {"damage": 10.0, "multiplier": 1.0, "damage_type": "physical"}

	func ultimate_host_position() -> Vector2:
		return global_position

	func ultimate_host_aim(max_range: float) -> Dictionary:
		var point := Vector2(160.0, 0.0)
		return {"point": point, "direction": (point - global_position).normalized() if max_range > 0.0 else Vector2.RIGHT}

	func ultimate_host_targets(center: Vector2, radius: float, limit: int) -> Array:
		var found: Array[Node2D] = []
		for target in fixture_targets:
			if is_instance_valid(target) and target.global_position.distance_to(center) <= radius:
				found.append(target)
		found.sort_custom(func(left: Node2D, right: Node2D) -> bool:
			return left.global_position.distance_squared_to(center) < right.global_position.distance_squared_to(center))
		return found.slice(0, limit) if limit > 0 else found

	func ultimate_host_summons(_group_id: String) -> Array:
		return []

	func ultimate_host_apply_damage(target: Node, amount: float, feedback: Dictionary) -> void:
		damage_calls += 1
		target.call("take_damage", amount, feedback)

	func ultimate_host_modifier(key: String, value: float, operation: String) -> void:
		if operation == "add":
			modifiers[key] = float(modifiers.get(key, 0.0)) + value
		else:
			modifiers[key] = float(modifiers.get(key, 1.0)) * value

	func ultimate_host_effect_parent() -> Node:
		return self

	func ultimate_host_present(_event_id: String, _payload: Dictionary) -> Node:
		return null

	func ultimate_host_set_active(_value: bool) -> void:
		pass

	func gain_money(_amount: int) -> void:
		pass


func _initialize() -> void:
	var errors: Array[String] = []
	var holder := Node2D.new()
	root.add_child(holder)
	current_scene = holder
	var registry = Registry.new(PD.WEAPONS_BY_CLASS)
	await process_frame
	for weapon_id in WEAPON_IDS:
		await _test_weapon(registry, holder, weapon_id, errors, false)
		# Lethal contour (the fifth QA blocker): a target killed by the cast is
		# freed before the ripple's next _process; its burst must still appear.
		await _test_weapon(registry, holder, weapon_id, errors, true)
	for error in errors:
		push_error("Thief victim impact lifecycle: %s" % error)
	if not errors.is_empty():
		print("thief_victim_impact_lifecycle_test: FAIL (%d)" % errors.size())
		quit(1)
		return
	print("thief_victim_impact_lifecycle_test: PASS")
	quit(0)


## One full natural cast per weapon: activate, let real frames run the tween
## chain to completion, keep watching while the ripple drains.
func _test_weapon(registry, holder: Node2D, weapon_id: String, errors: Array[String], lethal: bool) -> void:
	var host := FixtureHost.new()
	holder.add_child(host)
	await process_frame
	var victims: Array = []
	for index in 3:
		var target := FixtureTarget.new()
		target.position = Vector2(80.0 + float(index) * 120.0, 0.0)
		if lethal:
			target.health = 10.0
			target.max_health = 10.0
			target.dies_on_damage = true
		host.add_child(target)
		host.fixture_targets.append(target)
		victims.append(target)
	await process_frame
	var controller := Controller.new(host, registry)
	if not controller.activate(CLASS_ID, weapon_id):
		errors.append("%s must activate through the real controller" % weapon_id)
		await _drop(host)
		return
	# Natural run: no custom_step, no advance() — only real process frames.
	# Evidence is burst-centric, not node-centric: an existing-but-empty player
	# proves nothing (AC-3), so live bursts, their window and their timely
	# release are what gets measured.
	var frames := 0
	var saw_impact := false
	var impact_victims := 0
	var impact_flashes := 0
	var impact_bursts_spawned := 0
	var impact_bursts_peak_active := 0
	var impact_active_after_controller := false
	var burst_window := -1.0
	var sim_seconds := 0.0
	var last_enqueue_sim := -1.0
	var freed_sim := -1.0
	var drained_before_free := false
	var cast_done := false
	while frames < MAX_CAST_FRAMES + MAX_DRAIN_FRAMES and not cast_done:
		await process_frame
		frames += 1
		sim_seconds += root.get_process_delta_time()
		var impact := _impact_player(holder)
		if impact != null:
			saw_impact = true
			var state: Dictionary = impact.call("snapshot")
			# A rising victim total means this frame carried an enqueue beat —
			# the last one is the cleanup oracle's timing origin.
			if int(state.get("victims", 0)) > impact_victims:
				last_enqueue_sim = sim_seconds
			impact_victims = maxi(impact_victims, int(state.get("victims", 0)))
			impact_flashes = maxi(impact_flashes, int(state.get("flashes", 0)))
			impact_bursts_spawned = maxi(impact_bursts_spawned, int(state.get("created_nodes", 0)))
			impact_bursts_peak_active = maxi(impact_bursts_peak_active, int(state.get("active", 0)))
			burst_window = maxf(burst_window, float(state.get("burst_seconds", -1.0)))
			var busy := int(state.get("pending", 0)) > 0 or int(state.get("active", 0)) > 0
			drained_before_free = not busy
			if busy and not controller.is_active():
				impact_active_after_controller = true
		elif saw_impact and freed_sim < 0.0:
			freed_sim = sim_seconds
		if frames > MAX_CAST_FRAMES:
			cast_done = true
		elif not controller.is_active() and impact == null and frames > 10:
			cast_done = true
	if controller.is_active():
		errors.append("%s must finish its cast naturally within the frame budget" % weapon_id)
	await _assert_contour(holder, weapon_id, errors, victims, lethal, saw_impact, impact_victims,
		impact_flashes, impact_bursts_spawned, impact_bursts_peak_active,
		impact_active_after_controller, burst_window, last_enqueue_sim, freed_sim, drained_before_free)
	await _drop(host)


func _assert_contour(holder: Node2D, weapon_id: String, errors: Array[String], victims: Array,
		lethal: bool, saw_impact: bool, impact_victims: int, impact_flashes: int,
		impact_bursts_spawned: int, impact_bursts_peak_active: int,
		impact_active_after_controller: bool, burst_window: float,
		last_enqueue_sim: float, freed_sim: float, drained_before_free: bool) -> void:
	# Wait out the drain window so the release timer proves node cleanup.
	for _index in 30:
		await process_frame
	_expect(saw_impact, "%s must start the shared victim impact on the real controller path" % weapon_id, errors)
	_expect(impact_victims >= victims.size(),
		"%s impact must cover every hit victim across its whole ripple (best victims=%d)" % [weapon_id, impact_victims], errors)
	_expect(impact_bursts_spawned >= victims.size() and impact_bursts_peak_active >= 1,
		"%s must spawn one burst per victim and play it on real frames (created=%d, peak active=%d)" % [weapon_id, impact_bursts_spawned, impact_bursts_peak_active], errors)
	_expect(burst_window >= BURST_WINDOW_MIN_SECONDS and burst_window <= BURST_WINDOW_MAX_SECONDS,
		"%s burst window must stay the mandated 0.3-0.6s (planned %.2fs)" % [weapon_id, burst_window], errors)
	_expect(impact_flashes == 0,
		"%s impact must not draw the ordinary hit flash itself (AC-4: exactly one per damage event), flashes=%d" % [weapon_id, impact_flashes], errors)
	# Late-hit contour only: when the last beat lands at the cast's end, a
	# live burst must survive the controller's teardown — the original
	# blocker. In the early-lethal contour every victim dies on the first
	# beat, so the bursts legitimately end long before the cast does; what
	# must hold there is one real burst per killed victim, asserted above.
	if not lethal:
		_expect(impact_active_after_controller,
			"%s must still show live bursts after the controller completed" % weapon_id, errors)
	_expect(drained_before_free, "%s ripple must fully drain before its player is released" % weapon_id, errors)
	_expect(last_enqueue_sim >= 0.0 and freed_sim >= 0.0,
		"%s must observe both the last enqueue beat and the player's release" % weapon_id, errors)
	if last_enqueue_sim >= 0.0 and freed_sim >= 0.0:
		var retained := freed_sim - last_enqueue_sim
		if weapon_id == "thief_smoke_bomb":
			# Smoke Bomb's release is armed from the collapse beat itself, so
			# exactly the service ripple bound plus an explicit process-frame
			# scheduling tolerance applies — no cast-duration term. Coin Pouch
			# and Shadow Cloak arm at their FIRST beat with a hold that must
			# cover the tween-scheduled later beats (which in the lethal
			# contour never come), so a last-enqueue bound would be wrong for
			# them; their cleanup is proven by the drain and release checks.
			var bound := float(ImpactPlayer.MAX_WAVES) * float(ImpactPlayer.STAGGER_MAX_FRAMES) \
					* float(ImpactPlayer.FRAME_SECONDS) + ImpactPlayer.BURST_SECONDS \
					+ 0.2 + CLEANUP_FRAME_TOLERANCE_SECONDS
			_expect(retained <= bound,
				"%s empty player retained %.3fs of simulation time after its collapse enqueue (bound %.3fs) — release must not re-wait cast time" % [weapon_id, retained, bound], errors)
	var impact_left := false
	var orphan_bursts := 0
	for child in holder.get_children():
		if child.get_script() == ImpactPlayer:
			impact_left = true
		if str(child.name).begins_with("VictimImpact"):
			orphan_bursts += 1
	_expect(not impact_left, "%s drained ripple must release its node" % weapon_id, errors)
	_expect(orphan_bursts == 0, "%s drained ripple must leave no orphan burst sprites" % weapon_id, errors)
	for raw_target in victims:
		# Lethal contour: a target killed by the cast is freed — its burst
		# evidence is the ripple counters above, not this node.
		if not is_instance_valid(raw_target):
			continue
		var target := raw_target as FixtureTarget
		_expect(target.health < target.max_health, "%s must actually damage the victims" % weapon_id, errors)
		_expect(target.damage_flashes >= 1,
			"%s ordinary damage must draw the victim's hit flash exactly through the damage path" % weapon_id, errors)
		_expect(target.flashes == target.damage_flashes,
			"%s must draw exactly one ordinary hit flash per victim (got %d for %d damage events)" % [weapon_id, target.flashes, target.damage_flashes], errors)


func _impact_player(holder: Node2D) -> Node:
	for child in holder.get_children():
		if child.get_script() == ImpactPlayer:
			return child
	return null


func _drop(host: FixtureHost) -> void:
	host.queue_free()
	await process_frame


func _expect(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)
