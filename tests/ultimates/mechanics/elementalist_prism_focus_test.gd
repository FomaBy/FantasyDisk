extends SceneTree

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const PrismFocus := preload("res://scripts/ultimates/classes/elementalist/elementalist_prism_focus.gd")

const PROFILE_PATH := "res://data/ultimates/classes/elementalist/elementalist_prism_focus.json"
const COVERAGE_COUNTS := [1, 5, 10, 20]


class FixtureTarget extends Node2D:
	var health := 10000.0
	var max_health := 10000.0
	var hits := 0

	func take_damage(amount: float, _feedback := {}) -> void:
		hits += 1
		health = maxf(health - amount, 0.0)


class FixtureHost extends Node2D:
	var targets: Array[FixtureTarget] = []

	func ultimate_host_context() -> Dictionary:
		return {"damage": 20.0, "multiplier": 1.0, "damage_type": "magic"}

	func ultimate_host_position() -> Vector2:
		return global_position

	func ultimate_host_aim(_max_range: float) -> Dictionary:
		return {"point": Vector2.RIGHT * 600.0, "direction": Vector2.RIGHT}

	func ultimate_host_targets(center: Vector2, radius: float, limit: int) -> Array:
		var found: Array = []
		for target in targets:
			if is_instance_valid(target) and target.global_position.distance_to(center) <= radius:
				found.append(target)
		return found.slice(0, limit) if limit > 0 else found

	func ultimate_host_summons(_group_id: String) -> Array:
		return []

	func ultimate_host_apply_damage(target: Node, amount: float, feedback: Dictionary) -> void:
		target.call("take_damage", amount, feedback)

	func ultimate_host_modifier(_key: String, _value: float, _operation: String) -> void:
		pass

	func ultimate_host_effect_parent() -> Node:
		return self

	func ultimate_host_present(_event_id: String, _payload: Dictionary) -> Node:
		return null

	func ultimate_host_set_active(_value: bool) -> void:
		pass


var _errors: Array[String] = []
var _holder: Node2D


func _initialize() -> void:
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	await process_frame
	await _test_every_admitted_target_is_hit_in_each_coverage_scenario()
	await _test_elite_keeps_a_nonzero_effect()
	await _test_boss_damage_stays_inside_the_declared_cap()
	_test_profile_keeps_the_charge_ledger()
	_holder.queue_free()
	await process_frame
	_report()


func _test_every_admitted_target_is_hit_in_each_coverage_scenario() -> void:
	for count in COVERAGE_COUNTS:
		var host := await _host_with_targets(count)
		var activation := Activation.new(host, _params(), 0.10)
		var effect := _effect(host, activation)
		effect.fire_sweep(0)
		effect.shatter()
		for target in host.targets:
			_check(target.hits == 2,
				"coverage %d must give every admitted target one lattice and one fracture hit" % count)
		await _drop(host, activation)


func _test_elite_keeps_a_nonzero_effect() -> void:
	var host := await _host_with_targets(1)
	var elite := host.targets[0]
	elite.add_to_group(Activation.EPIC_GROUP)
	var activation := Activation.new(host, _params(), 0.10)
	var effect := _effect(host, activation)
	effect.fire_sweep(0)
	effect.shatter()
	_check(elite.hits == 2, "an elite inside both Prism shapes must receive both effects")
	await _drop(host, activation)


func _test_boss_damage_stays_inside_the_declared_cap() -> void:
	var host := await _host_with_targets(1)
	var boss := host.targets[0]
	boss.max_health = 1000.0
	boss.health = boss.max_health
	boss.add_to_group(Activation.BOSS_GROUP)
	var params := _params()
	params["lattice_damage"] = 100.0
	var activation := Activation.new(host, params, 0.10)
	var effect := _effect(host, activation)
	effect.fire_sweep(0)
	effect.shatter()
	_check(is_equal_approx(boss.max_health - boss.health, 100.0),
		"the shared boss budget must cap Prism at 10 percent despite a larger lattice hit")
	await _drop(host, activation)


func _test_profile_keeps_the_charge_ledger() -> void:
	var profile = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
	_check(profile is Dictionary, "Prism profile must stay readable")
	if not profile is Dictionary:
		return
	var document := profile as Dictionary
	var charge := document.get("charge", {}) as Dictionary
	_check(str(charge.get("strategy_id", "")) == "rare_charge_ledger",
		"Prism must keep the established rare charge ledger")


func _host_with_targets(count: int) -> FixtureHost:
	var host := FixtureHost.new()
	_holder.add_child(host)
	var direction := Vector2.RIGHT.rotated(deg_to_rad(45.0))
	for index in count:
		var target := FixtureTarget.new()
		target.global_position = direction * (20.0 + float(index) * 10.0)
		host.add_child(target)
		host.targets.append(target)
	await process_frame
	return host


func _effect(host: FixtureHost, activation: Activation) -> Node:
	var effect := PrismFocus.new()
	host.add_child(effect)
	effect.configure(activation, Vector2.ZERO)
	activation.bind_damage_sink(effect)
	return effect


func _params() -> Dictionary:
	return {
		"half_reach": 2400.0,
		"half_width": 74.0,
		"crowd_cap": 18,
		"sweep_count": 6,
		"rotation_step_degrees": 7.5,
		"lattice_hit_cap": 3,
		"lattice_damage": 6.5,
		"focus_radius": 100.0,
		"focus_orbit_radius": 180.0,
		"focus_multiplier": 1.20,
		"shatter_radius": 260.0,
		"shatter_damage": 4.55,
		"fracture_duration": 2.4,
		"fracture_slow": 0.70,
	}


func _drop(host: FixtureHost, activation: Activation) -> void:
	activation.shutdown(true)
	host.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if not _errors.is_empty():
		for error in _errors:
			push_error("elementalist_prism_focus_test: %s" % error)
		quit(1)
		return
	print("elementalist_prism_focus_test passed (coverage, elite, boss cap, charge ledger).")
	quit(0)
