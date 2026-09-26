extends SceneTree

## Guards the v2 no-count-cap contract: putting a positive limit back on a
## Conclave beat or its supernova must leave this 32-target encounter failing.

const OrbRing := preload("res://scripts/ultimates/classes/elementalist/elementalist_orb_ring.gd")
const TARGET_COUNT := 32


class FixtureTarget extends Node2D:
	var damage := 0.0
	var events: Array[String] = []


class FixtureActivation:
	var fixture_targets: Array[Node2D] = []
	var target_values := {}

	func is_finished() -> bool:
		return false

	func origin() -> Vector2:
		return Vector2.ZERO

	func param_float(_key: String, fallback: float) -> float:
		return fallback

	func param_int(_key: String, fallback: int) -> int:
		return fallback

	func present(_event_id: String, _payload: Dictionary) -> void:
		pass

	func select_targets(
		center: Vector2, radius: float, limit: int, _priority: String, _hint := {}
	) -> Array:
		return _inside(center, radius, limit)

	func targets(center: Vector2, radius: float, limit := 0) -> Array:
		return _inside(center, radius, limit)

	func record_target_value(target: Node, key: String, value, _event_id: String) -> void:
		var values: Dictionary = target_values.get(target.get_instance_id(), {})
		values[key] = value
		target_values[target.get_instance_id()] = values

	func target_value(target: Node, key: String, fallback):
		return (target_values.get(target.get_instance_id(), {}) as Dictionary).get(key, fallback)

	func apply_control(
		_target: Node, _impulse: Vector2, _status_id: String, _config: Dictionary
	) -> Dictionary:
		return {}

	func scaled_damage(_key: String, fallback: float) -> float:
		return fallback

	func _inside(center: Vector2, radius: float, limit: int) -> Array:
		var found: Array[Node2D] = []
		for target in fixture_targets:
			if is_instance_valid(target) and target.global_position.distance_to(center) <= radius:
				found.append(target)
		return found.slice(0, limit) if limit > 0 else found


var _errors: Array[String] = []
var _holder: Node2D


func _initialize() -> void:
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	await process_frame
	_test_every_eligible_target_receives_the_conclave()
	_holder.queue_free()
	await process_frame
	_report()


func _test_every_eligible_target_receives_the_conclave() -> void:
	var activation := FixtureActivation.new()
	for index in TARGET_COUNT:
		var target := FixtureTarget.new()
		target.global_position = Vector2.ZERO
		_holder.add_child(target)
		activation.fixture_targets.append(target)

	var effect := OrbRing.new()
	_holder.add_child(effect)
	effect.configure(activation)
	effect.ultimate_damage_sink = func(
		target: Node, amount: float, _feedback: Dictionary, event_id: String, _execute: bool
	) -> void:
		var fixture := target as FixtureTarget
		if fixture != null:
			fixture.damage += amount
			fixture.events.append(event_id)

	for beat in 3:
		effect.cast_beat(beat)
	effect.combined_nova()

	for target in activation.fixture_targets:
		var values: Dictionary = activation.target_values.get(target.get_instance_id(), {})
		_check(bool(values.get("conclave_burn", false)) \
			and bool(values.get("conclave_frost", false)) \
			and bool(values.get("conclave_gale", false)),
			"every eligible target must receive each uncapped elemental beat")
		var fixture := target as FixtureTarget
		_check(fixture != null and fixture.damage > 0.0 \
			and fixture.events.count("conclave:nova") == 1,
			"every eligible target must receive non-zero Conclave damage and one nova")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("elementalist_orb_ring_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("elementalist_orb_ring_test: %s" % error)
	print("elementalist_orb_ring_test: FAIL (%d)" % _errors.size())
	quit(1)
