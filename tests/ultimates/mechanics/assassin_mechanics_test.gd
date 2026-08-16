extends SceneTree

const Chakrams := preload("res://scripts/ultimates/classes/assassin/chakrams.gd")
const ShadowDaggers := preload("res://scripts/ultimates/classes/assassin/shadow_daggers.gd")
const VenomWire := preload("res://scripts/ultimates/classes/assassin/venom_wire.gd")

var _errors: Array[String] = []


func _initialize() -> void:
	_test_eight_compass_returns()
	_test_black_web_geometry()
	_test_distinct_contracts()
	_report()


func _test_eight_compass_returns() -> void:
	var directions := Chakrams.compass_directions()
	_check(directions.size() == 8, "Eight Moons must launch exactly eight chakrams")
	var rounded := {}
	for direction in directions:
		_check(is_equal_approx((direction as Vector2).length(), 1.0),
			"every compass direction must be normalized")
		rounded[Vector2i(roundi((direction as Vector2).x * 1000.0), roundi((direction as Vector2).y * 1000.0))] = true
	_check(rounded.size() == 8, "all eight compass directions must be unique")
	for cardinal in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		_check(_contains_direction(directions, cardinal), "compass fan must contain %s" % cardinal)
	for direction in directions:
		var origin := Vector2(14.0, -9.0)
		var endpoint := origin + (direction as Vector2) * 520.0
		var path := Chakrams.curved_return_path(origin, endpoint, 132.0, 6)
		_check(path.size() == 7 and path[0].is_equal_approx(endpoint)
			and path[path.size() - 1].is_equal_approx(origin),
			"every return path must run from its outbound endpoint back to the hero")
		var straight_mid := (endpoint + origin) * 0.5
		_check(path[3].distance_to(straight_mid) > 40.0,
			"every return must remain visibly curved, not collapse to a straight ray")


func _test_black_web_geometry() -> void:
	var points := PackedVector2Array()
	for index in 6:
		points.append(Vector2.UP.rotated(TAU * float(index) / 6.0) * 300.0)
	var segments := VenomWire.web_segments(points)
	_check(segments.size() == 9, "Black Web must own six hex edges and three crossing chords")
	for index in 6:
		_check(segments[index][0].is_equal_approx(points[index])
			and segments[index][1].is_equal_approx(points[(index + 1) % 6]),
			"perimeter edge %d must join adjacent anchors" % index)
	for index in 3:
		var chord := segments[index + 6]
		_check(chord[0].is_equal_approx(points[index])
			and chord[1].is_equal_approx(points[index + 3]),
			"crossing chord %d must join opposite anchors" % index)
		_check(_distance_to_segment(Vector2.ZERO, chord[0], chord[1]) < 0.01,
			"crossing chord %d must pass through the toxin-burst center" % index)
	_check(VenomWire.web_segments(PackedVector2Array([Vector2.ZERO])).is_empty(),
		"an incomplete anchor set must fail closed")


func _test_distinct_contracts() -> void:
	var signatures := {}
	for script in [Chakrams, ShadowDaggers, VenomWire]:
		var signature := JSON.stringify(script.parameter_contract(), "", true)
		_check(not signatures.has(signature), "all three Assassin weapons need distinct mechanics")
		signatures[signature] = true
	_check((Chakrams.parameter_contract() as Dictionary).has("return_curve_offset"),
		"Chakrams must contract the curved return")
	_check((ShadowDaggers.parameter_contract() as Dictionary).has("untargetable_duration"),
		"Shadow Daggers must contract the untargetable window")
	_check((VenomWire.parameter_contract() as Dictionary).has("max_cuts_per_pulse"),
		"Venom Wire must contract crossing-wire stack bounds")


func _contains_direction(directions: Array, expected: Vector2) -> bool:
	for direction in directions:
		if (direction as Vector2).is_equal_approx(expected):
			return true
	return false


func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var offset := finish - start
	if offset.length_squared() <= 0.001:
		return point.distance_to(start)
	var t := clampf((point - start).dot(offset) / offset.length_squared(), 0.0, 1.0)
	return point.distance_to(start + offset * t)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("assassin_mechanics_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("assassin_mechanics_test: %s" % error)
	print("assassin_mechanics_test: FAIL (%d)" % _errors.size())
	quit(1)
