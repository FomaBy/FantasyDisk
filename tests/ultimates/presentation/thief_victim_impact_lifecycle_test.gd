extends SceneTree

## Controller-level victim-impact lifecycle proof for every canonical Thief
## ultimate (FAN-3886 rework). Each cast runs the real Registry → Controller →
## executor → activation path with no manual tween stepping and no manual
## advance() on the ripple: natural frames must show the per-victim impact
## after the cast's own effect is torn down, and must release every node once
## the ripple drains. This is the contour the QA blocker was reproduced on.

const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "thief"
const WEAPON_IDS := ["thief_coin_pouch", "thief_shadow_cloak", "thief_smoke_bomb"]
const MAX_CAST_FRAMES := 6000
const MAX_DRAIN_FRAMES := 6000


class FixtureTarget extends Node2D:
	var health := 5000.0
	var max_health := 5000.0
	var flashes := 0
	var damage_flashes := 0

	func _combat_feedback_enabled() -> bool:
		return true

	## The real enemy flashes on the damage path (enemy.gd _show_combat_feedback);
	## the count is kept apart so the impact's own flash contribution is visible.
	func take_damage(amount: float, _feedback := {}) -> void:
		health = maxf(health - amount, 0.0)
		if amount > 0.0:
			damage_flashes += 1
			_show_hit_flash()

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
		await _test_weapon(registry, holder, weapon_id, errors)
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
func _test_weapon(registry, holder: Node2D, weapon_id: String, errors: Array[String]) -> void:
	var host := FixtureHost.new()
	holder.add_child(host)
	await process_frame
	var victims: Array = []
	for index in 3:
		var target := FixtureTarget.new()
		target.position = Vector2(80.0 + float(index) * 120.0, 0.0)
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
	var frames := 0
	var saw_impact := false
	var impact_victims := 0
	var impact_flashes := 0
	var impact_outlived_controller := false
	var cast_done := false
	while frames < MAX_CAST_FRAMES + MAX_DRAIN_FRAMES and not cast_done:
		await process_frame
		frames += 1
		var impact := _impact_player(holder)
		if impact != null:
			saw_impact = true
			var state: Dictionary = impact.call("snapshot")
			impact_victims = maxi(impact_victims, int(state.get("victims", 0)))
			impact_flashes = maxi(impact_flashes, int(state.get("flashes", 0)))
			if not controller.is_active():
				impact_outlived_controller = true
		if frames > MAX_CAST_FRAMES:
			cast_done = true
		elif not controller.is_active() and impact == null and frames > 10:
			cast_done = true
	if controller.is_active():
		errors.append("%s must finish its cast naturally within the frame budget" % weapon_id)
	await _controller_await_drain(holder, weapon_id, errors, victims, saw_impact, impact_victims, impact_flashes, impact_outlived_controller)
	await _drop(host)


func _controller_await_drain(holder: Node2D, weapon_id: String, errors: Array[String], victims: Array,
		saw_impact: bool, impact_victims: int, impact_flashes: int, impact_outlived_controller: bool) -> void:
	# Wait out the drain window so the release timer proves node cleanup.
	for _index in 30:
		await process_frame
	_expect(saw_impact, "%s must start the shared victim impact on the real controller path" % weapon_id, errors)
	_expect(impact_victims >= victims.size(),
		"%s impact must cover every hit victim across its whole ripple (best victims=%d)" % [weapon_id, impact_victims], errors)
	_expect(impact_flashes >= victims.size(),
		"%s impact must fire its own per-victim flash on real frames (flashes=%d)" % [weapon_id, impact_flashes], errors)
	_expect(impact_outlived_controller,
		"%s impact must still exist at the frame the controller completed (the QA smoke-bomb blocker)" % weapon_id, errors)
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
		var target := raw_target as FixtureTarget
		_expect(target.health < target.max_health, "%s must actually damage the victims" % weapon_id, errors)
		_expect(target.flashes - target.damage_flashes >= 1,
			"%s victim must receive the impact flash in addition to the damage flash" % weapon_id, errors)


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
