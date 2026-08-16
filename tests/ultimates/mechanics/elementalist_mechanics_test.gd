extends SceneTree

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")
const OrbRing := preload("res://scripts/ultimates/classes/elementalist/elementalist_orb_ring.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "elementalist"
const WEAPONS := [
	"elementalist_orb_ring",
	"elementalist_prism_focus",
	"elementalist_meteor_core",
]
const STEP := 0.01


class FixtureTarget extends Node2D:
	var health := 5000.0
	var max_health := 5000.0
	var received: Array[Dictionary] = []
	var knockbacks: Array[Vector2] = []

	func take_damage(amount: float, feedback := {}) -> void:
		received.append({"amount": amount, "feedback": (feedback as Dictionary).duplicate(true)})
		health = maxf(health - amount, 0.0)

	func apply_knockback(impulse: Vector2) -> void:
		knockbacks.append(impulse)


class FixtureHost extends Node2D:
	var fixture_targets: Array[Node2D] = []
	var aim_point := Vector2(600.0, 0.0)
	var active := false
	var damage_calls := 0
	var base_damage := 20.0
	var presentations: Array[Dictionary] = []

	func ultimate_host_context() -> Dictionary:
		return {"damage": base_damage, "multiplier": 1.0, "damage_type": "magic"}

	func ultimate_host_position() -> Vector2:
		return global_position

	func ultimate_host_aim(max_range: float) -> Dictionary:
		var offset := aim_point - global_position
		if offset.length_squared() <= 0.001:
			offset = Vector2.RIGHT
		var point := global_position + offset.normalized() * minf(offset.length(), max_range)
		return {"point": point, "direction": offset.normalized()}

	func ultimate_host_targets(center: Vector2, radius: float, limit: int) -> Array:
		var found: Array[Node2D] = []
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
		damage_calls += 1
		target.call("take_damage", amount, feedback)

	func ultimate_host_modifier(_key: String, _value: float, _operation: String) -> void:
		pass

	func ultimate_host_effect_parent() -> Node:
		return self

	func ultimate_host_present(event_id: String, payload: Dictionary) -> Node:
		presentations.append({"event_id": event_id, "payload": payload.duplicate(true)})
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
	_test_package_routing()
	_test_conclave_orbit_geometry()
	await _test_grand_conclave()
	await _test_prismatic_verdict()
	await _test_starfall()
	_holder.queue_free()
	await process_frame
	_report()


func _test_package_routing() -> void:
	_check(_registry.package_validation_errors().is_empty(),
		"Elementalist package discovery must be clean: %s" % [_registry.package_validation_errors()])
	var pairs: Array[String] = []
	var executors := {}
	var signatures := {}
	for key in _registry.package_pair_keys():
		if key.begins_with(CLASS_ID + "/"):
			pairs.append(key)
	_check(pairs == [
		"elementalist/elementalist_meteor_core",
		"elementalist/elementalist_orb_ring",
		"elementalist/elementalist_prism_focus",
	], "exactly the Elementalist trio must be admitted, got %s" % [pairs])
	for weapon_id in WEAPONS:
		_check(_registry.resolution_source(CLASS_ID, weapon_id) == Resolver.SOURCE_WEAPON_PROFILE,
			"%s must resolve through its exact ready package" % weapon_id)
		_check(_registry.has_exact_executor_pair(CLASS_ID, weapon_id),
			"%s must own one exact executor pair" % weapon_id)
		var executor = _registry.executor_for(CLASS_ID, weapon_id)
		_check(executor is GDScript, "%s executor must load" % weapon_id)
		if not executor is GDScript:
			continue
		var path := (executor as GDScript).resource_path
		_check(not executors.has(path), "%s must own a distinct executor" % weapon_id)
		executors[path] = true
		var profile := _registry.catalog_profile_for(CLASS_ID, weapon_id)
		var signature := JSON.stringify((profile["executor"] as Dictionary)["params"], "", true)
		_check(not signatures.has(signature), "%s must own a distinct parameter signature" % weapon_id)
		signatures[signature] = true
		_check(str((profile["identity"] as Dictionary)["profile_id"]) \
			== "weapon_ultimate.profile.elementalist.%s" % weapon_id,
			"%s must preserve its immutable profile identity" % weapon_id)
	for raw_class_id in PD.WEAPONS_BY_CLASS.keys():
		var class_id := str(raw_class_id)
		if class_id == CLASS_ID:
			continue
		for raw_weapon_id in (PD.WEAPONS_BY_CLASS[class_id] as Dictionary).keys():
			var weapon_id := str(raw_weapon_id)
			var expected := Resolver.SOURCE_WEAPON_PROFILE \
				if _registry.has_exact_executor_pair(class_id, weapon_id) \
				else Resolver.SOURCE_LEGACY_CLASS_FALLBACK
			_check(_registry.resolution_source(class_id, weapon_id) == expected,
				"%s/%s routing must not change with Elementalist packages" % [class_id, weapon_id])


func _test_conclave_orbit_geometry() -> void:
	var profile := _registry.catalog_profile_for(CLASS_ID, "elementalist_orb_ring")
	var params := (profile["executor"] as Dictionary)["params"] as Dictionary
	var contract := OrbRing.parameter_contract()
	var orbit_radius := float(params["orbit_radius"])
	var half_width := orbit_radius / sqrt(2.0)
	var center := Vector2(120.0, -40.0)
	var rotation := 0.16
	var points := OrbRing.square_points(center, orbit_radius, rotation)
	_check(points.size() == 4, "the sigil square must keep exactly four corners")
	for corner in points.size():
		_check(is_equal_approx(center.distance_to(points[corner]), orbit_radius),
			"corner %d must stand exactly orbit_radius from the centre" % corner)
		_check(points[corner].is_equal_approx(
				center + Vector2(half_width, half_width).rotated(rotation + corner * PI * 0.5)),
			"corner %d must keep its accepted orbit position" % corner)
	_check(is_equal_approx(half_width, 150.0),
		"the accepted sigil square must keep its 150px half-width")
	var nova_contract := contract.get("nova_radius", {}) as Dictionary
	_check(str(nova_contract.get("type", "")) == "number" \
			and is_equal_approx(float(nova_contract.get("minimum", 0.0)), 1.0),
		"the nova radius must be an explicit positive number parameter")
	_check(is_equal_approx(float(params["nova_radius"]), 440.0),
		"the combined nova must declare its accepted 440px reach")


func _test_grand_conclave() -> void:
	var host := await _host()
	var normal := _target(host, Vector2.ZERO, 5000.0, 5000.0)
	var epic := _target(host, Vector2(30.0, 0.0), 5000.0, 5000.0)
	epic.add_to_group(Activation.EPIC_GROUP)
	var boss := _target(host, Vector2(-30.0, 0.0), 1000.0, 1000.0)
	boss.add_to_group(Activation.BOSS_GROUP)
	var nova_edge := _target(host, Vector2(439.9, 0.0), 5000.0, 5000.0)
	var nova_outside := _target(host, Vector2(440.1, 0.0), 5000.0, 5000.0)
	for index in 5:
		_target(host, Vector2(70.0 + index * 20.0, 20.0), 5000.0, 5000.0)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "elementalist_orb_ring"),
		"Grand Conclave must activate")
	var activation := controller.active_activation()
	var effect := _effect(activation)
	_check(effect != null and effect.has_node("Presentation"),
		"Conclave must own the accepted presentation scene")
	_advance(activation, 6.1)
	_check(effect != null and effect.get("beat_trace_for_tests") \
		== ["burn", "frost", "gale", "shock"],
		"Conclave must resolve four distinct elemental beats in order")
	_check(effect != null and int(effect.get("nova_count_for_tests")) == 1,
		"Conclave must finish with exactly one combined nova")
	_check(is_equal_approx(_presentation_radius(host, ".sigils"), 212.13203435596427),
		"sigil ring pulse must pass through the declared orbit radius")
	_check(is_equal_approx(_presentation_radius(host, ".supernova"), 440.0),
		"supernova presentation must keep its declared 440px radius")
	_check(nova_edge.health < nova_edge.max_health and is_equal_approx(
		nova_outside.health, nova_outside.max_health),
		"supernova target selection must stop at its declared 440px radius")
	_check(bool(_status(normal, "elementalist_conclave_frost_").get("movement_locked", false)),
		"normal targets must receive the full frost lock")
	var epic_frost := _status(epic, "elementalist_conclave_frost_")
	_check(not epic_frost.is_empty() and not bool(epic_frost.get("movement_locked", false)) \
			and is_equal_approx(float(epic_frost.get("duration", 0.0)), 1.4),
		"epic targets must keep only the 35% resistant frost slow")
	_check(normal.knockbacks.size() == 1 and is_equal_approx(normal.knockbacks[0].length(), 420.0),
		"normal targets must receive the full gale knockback")
	_check(epic.knockbacks.size() == 1 and is_equal_approx(epic.knockbacks[0].length(), 147.0),
		"epic targets must receive only 35% gale displacement")
	_check(boss.knockbacks.size() == 1 and is_equal_approx(boss.knockbacks[0].length(), 42.0),
		"bosses must receive only 10% gale displacement")
	_check(is_equal_approx(boss.max_health - boss.health, boss.max_health * 0.10),
		"all Conclave beats and nova must share one 10% boss budget")
	_check(is_equal_approx(activation.applied_total, _removed_health(host.fixture_targets)),
		"Conclave attribution must equal HP actually removed")
	var calls := host.damage_calls
	effect.call("cast_beat", 0)
	effect.call("combined_nova")
	_check(host.damage_calls == calls, "replayed Conclave callbacks must be idempotent")
	_check(_event_count(host, ".sigils") == 1 and _event_count(host, ".supernova") == 1,
		"Conclave must emit the accepted sigil and supernova presentation events")
	controller.cancel()
	await process_frame
	_check(not controller.is_active() and not is_instance_valid(effect),
		"Conclave cancellation must free its effect and tweens")
	for target in host.fixture_targets:
		_check(_status(target, "elementalist_conclave_").is_empty(),
			"Conclave cancellation must remove its leased statuses")
	await _drop(host)


func _test_prismatic_verdict() -> void:
	var host := await _host()
	host.aim_point = Vector2(600.0, 0.0)
	var normal := _target(host, Vector2(600.0, 10.0), 6000.0, 6000.0)
	var epic := _target(host, Vector2(630.0, 0.0), 6000.0, 6000.0)
	epic.add_to_group(Activation.EPIC_GROUP)
	var boss := _target(host, Vector2(600.0, -10.0), 1000.0, 1000.0)
	boss.add_to_group(Activation.BOSS_GROUP)
	_target(host, Vector2(700.0, 100.0), 6000.0, 6000.0)
	_target(host, Vector2(500.0, 100.0), 6000.0, 6000.0)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "elementalist_prism_focus"),
		"Prismatic Verdict must activate")
	var activation := controller.active_activation()
	var effect := _effect(activation)
	_advance(activation, 5.5)
	_check(effect != null and int(effect.get("sweep_count_for_tests")) == 6,
		"the rotating lattice must resolve exactly six sweeps")
	_check(effect != null and int(effect.call("hit_count_for", boss)) == 3,
		"one silhouette must receive at most three lattice hits")
	var calls := host.damage_calls
	effect.call("fire_sweep", 0)
	_check(host.damage_calls == calls, "a replayed lattice sweep must be idempotent")
	_advance(activation, 1.0)
	_check(effect != null and int(effect.get("shatter_count_for_tests")) == 1,
		"the lattice must end in one rainbow fracture")
	_check(is_equal_approx(float(_status(normal, "elementalist_prism_fracture_").get(
		"duration", 0.0)), 2.4), "normal fracture must retain its full window")
	_check(is_equal_approx(float(_status(epic, "elementalist_prism_fracture_").get(
		"duration", 0.0)), 1.2), "epic fracture must be duration-resistant")
	_check(is_equal_approx(float(_status(boss, "elementalist_prism_fracture_").get(
		"duration", 0.0)), 0.6), "boss fracture must be duration-resistant")
	_check(is_equal_approx(boss.max_health - boss.health, boss.max_health * 0.10),
		"lattice and fracture must share one 10% boss budget")
	_check(_event_count(host, ".unfold") == 1 and _event_count(host, ".lattice") == 12 \
			and _event_count(host, ".focus") == 12 and _event_count(host, ".shatter") == 1,
		"Prism must emit unfold, rotating X lattice, moving focus and shatter events")
	controller.cancel()
	await process_frame
	for target in host.fixture_targets:
		_check(_status(target, "elementalist_prism_fracture_").is_empty(),
			"Prism cancellation must remove its fracture lease")
	await _drop(host)


func _test_starfall() -> void:
	var host := await _host()
	host.aim_point = Vector2(400.0, 0.0)
	var weak := _target(host, Vector2(400.0, 0.0), 900.0, 900.0)
	var sturdy := _target(host, Vector2(350.0, 0.0), 901.0, 901.0)
	var epic := _target(host, Vector2(450.0, 0.0), 900.0, 900.0)
	epic.add_to_group(Activation.EPIC_GROUP)
	var boss := _target(host, Vector2(500.0, 0.0), 1000.0, 1000.0)
	boss.add_to_group(Activation.BOSS_GROUP)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "elementalist_meteor_core"),
		"Starfall must activate")
	var activation := controller.active_activation()
	var effect := _effect(activation)
	_advance(activation, 2.4)
	_check(weak.received.is_empty(), "the giant meteor must keep its fair 2.45s telegraph")
	_advance(activation, 0.4)
	_check(is_zero_approx(weak.health) and int(effect.get("execute_count_for_tests")) == 1,
		"the impact must destroy an admitted weak normal")
	_check(sturdy.health > 0.0 and epic.health > 0.0,
		"the execute rail must reject a 901-HP normal and a 900-HP epic")
	_check(epic.knockbacks.size() == 1 and is_equal_approx(epic.knockbacks[0].length(), 65.0),
		"epics must receive only 25% gravity displacement")
	_check(boss.knockbacks.is_empty(), "bosses must reject gravity displacement")
	_check(is_equal_approx(float(_status(epic, "elementalist_meteor_crater_").get(
		"duration", 0.0)), 1.92), "epic crater control must use 40% duration")
	_check(is_equal_approx(float(_status(boss, "elementalist_meteor_crater_").get(
		"duration", 0.0)), 0.96), "boss crater control must use 20% duration")
	_advance(activation, 4.4)
	_check(int(effect.get("pulse_count_for_tests")) == 5,
		"the gravity-fire crater must emit exactly five pulses")
	_check(is_equal_approx(boss.max_health - boss.health, boss.max_health * 0.10),
		"impact and crater pulses must share one 10% boss budget")
	var calls := host.damage_calls
	effect.call("impact")
	effect.call("crater_pulse", 0)
	_check(host.damage_calls == calls, "replayed meteor callbacks must be idempotent")
	_check(_event_count(host, ".rune_shadow") == 1 and _event_count(host, ".meteor") == 1 \
			and _event_count(host, ".impact") == 1 and _event_count(host, ".crater_pulse") == 5,
		"Meteor must emit rune, drop, impact and crater presentation events")
	controller.cancel()
	await process_frame
	_check(not is_instance_valid(effect), "Meteor cancellation must free the crater effect")
	for target in host.fixture_targets:
		_check(_status(target, "elementalist_meteor_crater_").is_empty(),
			"Meteor cancellation must remove its crater lease")
	await _drop(host)


func _host() -> FixtureHost:
	var host := FixtureHost.new()
	host.process_mode = Node.PROCESS_MODE_DISABLED
	_holder.add_child(host)
	await process_frame
	return host


func _target(
	host: FixtureHost, position: Vector2, health: float, max_health: float
) -> FixtureTarget:
	var target := FixtureTarget.new()
	target.global_position = position
	target.health = health
	target.max_health = max_health
	host.add_child(target)
	host.fixture_targets.append(target)
	return target


func _effect(activation: Activation) -> Node:
	if activation == null:
		return null
	var spawned := activation.spawned_for_tests()
	return spawned[0] if not spawned.is_empty() else null


func _advance(activation: Activation, seconds: float) -> void:
	if activation == null:
		return
	var elapsed := 0.0
	while elapsed < seconds:
		for tween in activation.tweens_for_tests():
			if tween != null and tween.is_valid():
				tween.custom_step(STEP)
		elapsed += STEP


func _status(target: Node, prefix: String) -> Dictionary:
	var snapshot := StatusEffects.snapshot(target)
	for status_id in snapshot:
		if str(status_id).begins_with(prefix):
			return (snapshot[status_id] as Dictionary).duplicate(true)
	return {}


func _event_count(host: FixtureHost, suffix: String) -> int:
	var count := 0
	for event in host.presentations:
		if str(event.get("event_id", "")).ends_with(suffix):
			count += 1
	return count


func _presentation_radius(host: FixtureHost, suffix: String) -> float:
	for event in host.presentations:
		if str(event.get("event_id", "")).ends_with(suffix):
			return float((event.get("payload", {}) as Dictionary).get("radius", -1.0))
	return -1.0


func _removed_health(targets: Array) -> float:
	var total := 0.0
	for raw_target in targets:
		var target := raw_target as FixtureTarget
		total += target.max_health - target.health
	return total


func _drop(host: FixtureHost) -> void:
	host.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("elementalist_mechanics_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("elementalist_mechanics_test: %s" % error)
	print("elementalist_mechanics_test: FAIL (%d)" % _errors.size())
	quit(1)
