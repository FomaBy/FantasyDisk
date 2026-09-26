extends SceneTree

## FAN-3237: Ultimate Direction v2 conversion card for druid/summon_amulet.
## The Wild Hunt must reach every live enemy on the map with no count-shaped
## bound, keep the frozen eight-percent whole-activation boss cap, and keep the
## activation's summon contribution accounting equal to the HP actually removed.

const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")

const CLASS_ID := "druid"
const WEAPON_ID := "summon_amulet"
const STEP := 0.01
const CAST_SECONDS := 6.6


class Target extends Node2D:
	var health := 10000.0
	var max_health := 10000.0

	func take_damage(_amount: float, _feedback := {}) -> void:
		health = maxf(health - _amount, 0.0)


class Host extends Node2D:
	var fixture_targets: Array[Node2D] = []
	var active := false
	var base_damage := 12.0

	func ultimate_host_context() -> Dictionary:
		return {"damage": base_damage, "multiplier": 1.0, "damage_type": "magic"}

	func ultimate_host_position() -> Vector2:
		return global_position

	func ultimate_host_aim(max_range: float) -> Dictionary:
		return {"point": global_position + Vector2.RIGHT * max_range, "direction": Vector2.RIGHT}

	func ultimate_host_targets(center: Vector2, radius: float, limit: int) -> Array:
		var found: Array = []
		for target in fixture_targets:
			if is_instance_valid(target) and target.global_position.distance_to(center) <= radius:
				found.append(target)
		found.sort_custom(func(left: Node2D, right: Node2D) -> bool:
			return left.global_position.distance_squared_to(center) \
				< right.global_position.distance_squared_to(center)
		)
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
		var marker := Node2D.new()
		add_child(marker)
		return marker

	func ultimate_host_set_active(value: bool) -> void:
		active = value


var _errors: Array[String] = []
var _holder: Node2D
var _registry


func _initialize() -> void:
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	await process_frame
	_registry = Registry.new(PD.WEAPONS_BY_CLASS)
	_check(_registry.package_validation_errors().is_empty(),
		"Druid packages must admit cleanly: %s" % [_registry.package_validation_errors()])
	await _test_stampede_reaches_whole_map()
	await _test_every_wave_reaches_every_enemy()
	await _test_boss_cap_and_attribution()
	_holder.queue_free()
	await process_frame
	_report()


## A crowd far larger than the retired twelve-target cap plus one silhouette
## parked thousands of pixels off-screen: the opening stampede alone must have
## removed HP from every one of them.
func _test_stampede_reaches_whole_map() -> void:
	var host := _new_host()
	for index in 30:
		_target(host, Vector2(0.0, -290.0 + float(index) * 20.0))
	_target(host, Vector2(5000.0, -4000.0))
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, WEAPON_ID), "Wild Hunt must activate")
	var activation = controller.active_activation()
	_advance(activation, 1.0)
	var reached := 0
	for raw_target in host.fixture_targets:
		if (raw_target as Target).health < (raw_target as Target).max_health:
			reached += 1
	_check(reached == host.fixture_targets.size(),
		"the stampede must reach every live enemy on the map, got %d of %d" % [
			reached, host.fixture_targets.size(),
		])
	controller.cancel()
	await process_frame
	await _drop(host)


## The dead-then-alive churn case: enemies that were not present at the stampede
## must still be reached by the later hunt waves, because every wave re-reads
## the live arena.
func _test_every_wave_reaches_every_enemy() -> void:
	var host := _new_host()
	for index in 30:
		_target(host, Vector2(0.0, -290.0 + float(index) * 20.0))
	var latecomer := _target(host, Vector2(4300.0, -3600.0))
	latecomer.health = 0.0
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, WEAPON_ID), "Wild Hunt must activate")
	var activation = controller.active_activation()
	_advance(activation, 1.0)
	_check(latecomer.health == 0.0 and latecomer.max_health > 0.0,
		"a dead enemy must stay dead through the stampede")
	latecomer.health = latecomer.max_health
	_advance(activation, CAST_SECONDS)
	_check(latecomer.health < latecomer.max_health,
		"an enemy that comes alive after the stampede must be reached by a hunt wave")
	var reached := 0
	for raw_target in host.fixture_targets:
		if (raw_target as Target).health < (raw_target as Target).max_health:
			reached += 1
	_check(reached == host.fixture_targets.size(),
		"the full hunt must reach every live enemy, got %d of %d" % [
			reached, host.fixture_targets.size(),
		])
	controller.cancel()
	await process_frame
	await _drop(host)


## The whole activation may remove at most the frozen eight percent of a boss's
## pool, and the activation's applied total must equal the HP actually removed.
func _test_boss_cap_and_attribution() -> void:
	var host := _new_host()
	var boss := _target(host, Vector2(180.0, 0.0))
	boss.add_to_group("bosses")
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, WEAPON_ID), "Wild Hunt must activate")
	var activation = controller.active_activation()
	_advance(activation, CAST_SECONDS)
	_check(boss.health < boss.max_health, "the boss must actually be struck")
	_check(boss.max_health - boss.health <= boss.max_health * 0.08 + 0.001,
		"all beast impacts must share the eight-percent whole-activation boss cap")
	_check(is_equal_approx(activation.applied_total, boss.max_health - boss.health),
		"activation attribution must equal the HP actually removed")
	_check(not controller.is_active(), "the hunt must complete its declared cast")
	await _drop(host)


func _new_host() -> Host:
	var host := Host.new()
	_holder.add_child(host)
	return host


func _target(host: Host, position: Vector2) -> Target:
	var target := Target.new()
	host.add_child(target)
	target.global_position = position
	host.fixture_targets.append(target)
	return target


func _advance(activation, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds and activation != null and not activation.is_finished():
		var step := minf(STEP, seconds - elapsed)
		for tween in activation.tweens_for_tests():
			if tween != null and tween.is_valid():
				tween.custom_step(step)
		elapsed += step


func _drop(host: Host) -> void:
	if host != null and is_instance_valid(host):
		host.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("druid_summon_amulet_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("druid_summon_amulet_test: %s" % error)
	print("druid_summon_amulet_test: FAIL (%d)" % _errors.size())
	quit(1)
