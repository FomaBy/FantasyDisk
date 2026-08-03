extends SceneTree

const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")

const CLASS_ID := "guitarist"
const ELECTRIC := "electric_guitar"
const BASS := "bass_guitar"
const AMP := "sound_amp"
const STEP := 0.01


class Target extends Node2D:
	var health := 1000.0
	var max_health := 1000.0
	var knockback_impulses: Array[Vector2] = []

	func take_damage(amount: float, _feedback := {}) -> void:
		health = maxf(health - amount, 0.0)

	func apply_knockback(impulse: Vector2) -> void:
		knockback_impulses.append(impulse)


class Host extends Node2D:
	var fixture_targets: Array[Node2D] = []
	var active := false
	var base_damage := 1000.0

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
		"Guitarist packages must admit cleanly: %s" % [_registry.package_validation_errors()])
	_check(_guitarist_pairs() == [
		"guitarist/bass_guitar", "guitarist/electric_guitar", "guitarist/sound_amp",
	], "only the exact Guitarist trio may be admitted")
	await _test_last_chord()
	await _test_hell_subwoofer()
	await _test_wall_of_sound()
	_holder.queue_free()
	await process_frame
	_report()


func _test_last_chord() -> void:
	var host := _new_host()
	var normal := _target(host, Vector2(720.0, 0.0))
	var epic := _target(host, Vector2(720.0, 12.0))
	epic.add_to_group("elite_enemies")
	var boss := _target(host, Vector2(720.0, -12.0))
	boss.add_to_group("bosses")
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, ELECTRIC), "Last Chord must activate through its exact pair")
	_check(not controller.activate(CLASS_ID, ELECTRIC), "an active Last Chord must refuse re-entry")
	var activation = controller.active_activation()
	_advance(activation, 1.25)
	var state: Dictionary = activation.primitive_value("guitarist_last_chord", {})
	_check(int(state.get("strips_fired", 0)) == 5,
		"Last Chord must fire exactly five alternating riff strips before its finale")
	_advance(activation, 0.30)
	_check(int(state.get("intersections", 0)) == 3,
		"the final chord must resolve only on riff intersections")
	_check(normal.has_meta(StatusEffects.META_KEY), "a normal enemy at an intersection must be stunned")
	_check(epic.has_meta(StatusEffects.META_KEY), "an epic at an intersection keeps reduced control")
	_check(boss.knockback_impulses.is_empty(), "the final chord must not move a boss")
	_check(boss.max_health - boss.health <= boss.max_health * 0.09 + 0.001,
		"Last Chord must use the whole-activation nine-percent boss cap")
	var actual_lost := (normal.max_health - normal.health) + (epic.max_health - epic.health) \
		+ (boss.max_health - boss.health)
	_check(is_equal_approx(activation.applied_total, actual_lost),
		"Last Chord attribution must equal actual removed HP after every cap")
	var presentation := activation.presentation_for_tests()
	controller.cancel()
	await process_frame
	_check(not controller.is_active() and not host.active, "cancelling Last Chord must clear active state")
	for marker in presentation:
		_check(not is_instance_valid(marker), "cancelling Last Chord must free every presentation handle")
	await _drop(host)


func _test_hell_subwoofer() -> void:
	var host := _new_host()
	var normal := _target(host, Vector2(100.0, 0.0))
	var epic := _target(host, Vector2(120.0, 0.0))
	epic.add_to_group("elite_enemies")
	var boss := _target(host, Vector2(140.0, 0.0))
	boss.add_to_group("bosses")
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, BASS), "Hell Subwoofer must activate through its exact pair")
	var activation = controller.active_activation()
	_advance(activation, 0.72)
	var state: Dictionary = activation.primitive_value("guitarist_hell_subwoofer", {})
	_check(state.get("waves", []) == ["pull"], "the first bass wave must pull before later waves")
	_check(normal.knockback_impulses.size() == 1 and epic.knockback_impulses.size() == 1,
		"the pull ring must reach normal and epic targets")
	if not normal.knockback_impulses.is_empty() and not epic.knockback_impulses.is_empty():
		_check(is_equal_approx(epic.knockback_impulses[0].length(),
			normal.knockback_impulses[0].length() * 0.35),
			"epic pull resistance must retain the declared 35 percent impulse")
	_check(boss.knockback_impulses.is_empty(), "bass waves must not displace bosses")
	_advance(activation, 1.70)
	_check(state.get("waves", []) == ["pull", "weight", "launch", "shock"],
		"Subwoofer must resolve pull, compression, launch and shock in order")
	_check(boss.max_health - boss.health <= boss.max_health * 0.09 + 0.001,
		"Subwoofer must share the nine-percent boss budget across all four waves")
	var presentation := activation.presentation_for_tests()
	controller.cancel()
	await process_frame
	for marker in presentation:
		_check(not is_instance_valid(marker), "cancelling Subwoofer must free every presentation handle")
	await _drop(host)


func _test_wall_of_sound() -> void:
	var host := _new_host()
	var inner := _target(host, Vector2(120.0, 120.0))
	var epic := _target(host, Vector2(160.0, 0.0))
	epic.add_to_group("elite_enemies")
	var boss := _target(host, Vector2(80.0, 0.0))
	boss.add_to_group("bosses")
	var outside := _target(host, Vector2(270.0, 0.0))
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, AMP), "Wall of Sound must activate through its exact pair")
	var activation = controller.active_activation()
	_advance(activation, 0.71)
	var state: Dictionary = activation.primitive_value("guitarist_wall_of_sound", {})
	var points := state.get("points", PackedVector2Array()) as PackedVector2Array
	_check(points.size() == 4 and bool(state.get("linked", false)),
		"Wall of Sound must form four cardinal amps and one linked square")
	_check(inner.health < inner.max_health and is_equal_approx(outside.health, outside.max_health),
		"feedback may damage only targets inside the linked square")
	_advance(activation, 1.40)
	_check(int(state.get("pulses", 0)) == 4, "Wall of Sound must emit exactly four feedback pulses")
	_check(boss.max_health - boss.health <= boss.max_health * 0.09 + 0.001,
		"Wall of Sound must share the nine-percent boss budget across field and overload")
	_check(not epic.knockback_impulses.is_empty()
		and epic.knockback_impulses.back().length() > 0.0,
		"the four-way overload must eject epic targets with reduced, nonzero force")
	var presentation := activation.presentation_for_tests()
	controller.cancel()
	await process_frame
	for marker in presentation:
		_check(not is_instance_valid(marker), "cancelling Wall of Sound must free every presentation handle")
	await _drop(host)


func _guitarist_pairs() -> Array[String]:
	var pairs: Array[String] = []
	for key in _registry.package_pair_keys():
		if key.begins_with(CLASS_ID + "/"):
			pairs.append(key)
	return pairs


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
		print("guitarist_ultimate_mechanics_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("guitarist_ultimate_mechanics_test: %s" % error)
	print("guitarist_ultimate_mechanics_test: FAIL (%d)" % _errors.size())
	quit(1)
