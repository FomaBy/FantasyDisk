extends SceneTree

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "biologist"
const WEAPONS := ["biologist_spore_lens", "biologist_sample_injector", "biologist_symbiote_seed"]
const DURATIONS := {"biologist_spore_lens": 3.5, "biologist_sample_injector": 3.0, "biologist_symbiote_seed": 3.9}
const STEP := 0.01
const CROWD_SIZES := [1, 5, 10, 20]


class FixtureTarget extends Node2D:
	var health := 100000.0
	var max_health := 100000.0
	var received: Array[Dictionary] = []

	func take_damage(amount: float, feedback := {}) -> void:
		received.append({"amount": amount, "feedback": (feedback as Dictionary).duplicate(true)})
		health = maxf(health - amount, 0.0)

	func apply_knockback(impulse: Vector2) -> void:
		pass


class FixtureHost extends Node2D:
	var fixture_targets: Array[Node2D] = []
	var active := false
	var base_damage := 10.0

	func ultimate_host_context() -> Dictionary:
		return {"damage": base_damage, "multiplier": 1.0, "damage_type": "magic"}

	func ultimate_host_position() -> Vector2:
		return global_position

	func ultimate_host_aim(max_range: float) -> Dictionary:
		return {"point": global_position + Vector2.RIGHT * max_range, "direction": Vector2.RIGHT}

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
		if target != null and is_instance_valid(target):
			target.call("take_damage", amount, feedback)

	func ultimate_host_modifier(_key: String, _value: float, _operation: String) -> void:
		pass

	func ultimate_host_effect_parent() -> Node:
		return self

	func ultimate_host_present(_event_id: String, _payload: Dictionary) -> Node:
		return null

	func ultimate_host_set_active(value: bool) -> void:
		active = value


var _errors: Array[String] = []
var _holder: Node2D
var _registry: Registry


func _initialize() -> void:
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	_registry = Registry.new(PD.WEAPONS_BY_CLASS)
	await process_frame
	for weapon_id in WEAPONS:
		for crowd_size in CROWD_SIZES:
			await _test_arena_coverage(weapon_id, int(crowd_size))
	_holder.queue_free()
	await process_frame
	_report()


func _test_arena_coverage(weapon_id: String, crowd_size: int) -> void:
	var host := FixtureHost.new()
	_holder.add_child(host)
	var targets: Array[FixtureTarget] = []
	for index in crowd_size:
		var target := FixtureTarget.new()
		target.global_position = Vector2(160.0 + float(index * 80), float((index % 5) * 90))
		host.add_child(target)
		host.fixture_targets.append(target)
		targets.append(target)
	var elite := FixtureTarget.new()
	elite.global_position = Vector2(-1600.0, -900.0)
	elite.add_to_group(Activation.EPIC_GROUP)
	host.add_child(elite)
	host.fixture_targets.append(elite)
	var boss := FixtureTarget.new()
	boss.health = 10000.0
	boss.max_health = 10000.0
	boss.global_position = Vector2(-1200.0, 900.0)
	boss.add_to_group(Activation.BOSS_GROUP)
	host.add_child(boss)
	host.fixture_targets.append(boss)
	await process_frame
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, weapon_id), "%s must activate" % weapon_id)
	var activation := controller.active_activation()
	_check(activation != null and controller.is_active(), "%s must stay active during its presentation" % weapon_id)
	_advance(activation, 2.0)
	for target in targets:
		_check(not target.received.is_empty() and target.health < target.max_health,
			"%s must damage every one of %d live crowd targets" % [weapon_id, crowd_size])
		if weapon_id == "biologist_spore_lens":
			_check(not _status_with_prefix(target, "biologist_ultimate_spore_").is_empty(),
				"Spore Lens must infect every covered enemy")
		if weapon_id == "biologist_symbiote_seed":
			_check(not _status_with_prefix(target, "biologist_ultimate_symbiote_").is_empty(),
				"Symbiote Seed must root every covered enemy")
		if weapon_id == "biologist_sample_injector" and crowd_size > 1:
			# At crowd 1 the lone enemy is the primary itself, so it takes the
			# full extraction and pulses instead of the tissue echo.
			var primary := false
			var tissue := false
			for entry in target.received:
				var mechanic := str((entry as Dictionary).get("feedback", {}).get("ultimate_mechanic", ""))
				if mechanic == "sample_extraction":
					primary = true
				if mechanic == "analysis_tissue":
					tissue = true
			_check(primary or tissue, "Sample Injector must reach every live enemy (primary or tissue echo)")
	_check(not elite.received.is_empty() and elite.health < elite.max_health,
		"%s must damage the elite in the live arena" % weapon_id)
	if weapon_id == "biologist_spore_lens":
		var infection := _status_with_prefix(elite, "biologist_ultimate_spore_")
		_check(not infection.is_empty() and not infection.has("movement_locked"),
			"Spore Lens must apply the resisted, non-pinning elite infection")
	if weapon_id == "biologist_symbiote_seed":
		var root_status := _status_with_prefix(elite, "biologist_ultimate_symbiote_")
		_check(not root_status.is_empty() and not root_status.has("movement_locked"),
			"Symbiote Seed must apply the resisted, non-pinning elite root")
	var boss_damage := boss.max_health - boss.health
	_check(boss_damage > 0.0 and boss_damage <= boss.max_health * 0.10 + 0.001,
		"%s must preserve the shared 10%% boss cap" % weapon_id)
	_check(is_equal_approx(activation.applied_total, _removed_health(host.fixture_targets)),
		"%s attribution must match the HP removed from its arena-wide target set" % weapon_id)
	_advance(activation, float(DURATIONS[weapon_id]))
	await process_frame
	_check(not controller.is_active() and not host.active, "%s must clean up after its declared duration" % weapon_id)
	host.queue_free()
	await process_frame


func _advance(activation, seconds: float) -> void:
	if activation == null:
		return
	var elapsed := 0.0
	while elapsed < seconds:
		for tween in activation.tweens_for_tests():
			if tween != null and tween.is_valid():
				tween.custom_step(STEP)
		elapsed += STEP


func _status_with_prefix(target: Node, prefix: String) -> Dictionary:
	for status_id in StatusEffects.snapshot(target):
		if str(status_id).begins_with(prefix):
			return (StatusEffects.snapshot(target)[status_id] as Dictionary).duplicate(true)
	return {}


func _removed_health(targets: Array) -> float:
	var total := 0.0
	for raw_target in targets:
		var target := raw_target as FixtureTarget
		total += target.max_health - target.health
	return total


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("biologist_live_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("biologist_live_test: %s" % error)
	print("biologist_live_test: FAIL (%d)" % _errors.size())
	quit(1)
