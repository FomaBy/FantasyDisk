extends SceneTree

## Fixture suite for FAN-1457: the generic ultimate runtime.
##
## Every family runs through the same `controller.activate(class_id, weapon_id)`
## call and differs only by declaration data — that is the acceptance evidence
## for "no class/weapon branches". Timing is stepped manually so the suite does
## not depend on frame pacing; only the pause case uses real frames, where the
## assertion ("nothing ticked") holds regardless of how fast they arrive.
##
## Run:
## python3 tools/godot_gate.py --headless --path . \
##   --script res://tests/ultimates/controller_runtime_test.gd

const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")
const PD := preload("res://scripts/progression_data.gd")

const FIXTURE_CLASS := "fixture_class"
const FIXTURE_WEAPON := "fixture_weapon"
const ALLY_MINION_SCENE_PATH := "res://scenes/AllyMinion.tscn"
const RUNTIME_SOURCE_DIRECTORIES := [
	"res://scripts/ultimates/controller",
	"res://scripts/ultimates/executors",
]
const EXPECTED_STRATEGIES := [
	"aimed_sequence",
	"burst",
	"chained_projectile",
	"control",
	"deploy_summon",
	"status_zone",
	"timed_modifier",
]
const BASE_PARAMS := {
	"aimed_sequence": {"radius": 620.0, "damage": 1.0, "shot_count": 1, "interval": 0.05},
	"burst": {"radius": 320.0, "damage": 1.0, "target_limit": 0},
	"chained_projectile": {
		"radius": 260.0, "damage": 1.0, "jumps": 1, "hop_delay": 0.05, "falloff": 0.5,
	},
	"control": {
		"radius": 340.0, "damage": 0.0, "target_limit": 0, "knockback": 0.0,
		"status_id": "", "status": {},
	},
	"deploy_summon": {
		"scene": ALLY_MINION_SCENE_PATH, "count": 1, "spawn_radius": 0.0,
		"lifetime": 0.2, "damage": 1.0, "properties": {},
	},
	"status_zone": {
		"radius": 260.0, "damage": 1.0, "duration": 0.2, "interval": 0.05,
		"follow_host": false, "status_id": "", "status": {},
	},
	"timed_modifier": {"duration": 0.2, "radius": 200.0, "modifiers": {}},
}

const STEP := 0.01


class FixtureTarget extends Node2D:
	var health := 100.0
	var max_health := 100.0
	var damage_taken_multiplier := 1.0
	var hits := 0
	var knockbacks := 0

	func take_damage(amount: float, _feedback := {}) -> void:
		hits += 1
		health = maxf(health - amount * damage_taken_multiplier, 0.0)

	func apply_knockback(_impulse: Vector2) -> void:
		knockbacks += 1


## A deferred damage source (summon/deploy) that opts into the activation ledger.
class FixtureSink extends Node2D:
	var ultimate_damage_sink: Callable = Callable()


class FixtureHost extends Node2D:
	var fixture_targets: Array[Node2D] = []
	var modifiers: Dictionary = {}
	var presentations: Array[String] = []
	var damage_calls := 0
	var active := false
	var base_damage := 10.0

	func ultimate_host_context() -> Dictionary:
		return {"damage": base_damage, "multiplier": 1.0, "damage_type": "physical"}

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
		damage_calls += 1
		if target != null and is_instance_valid(target) and target.has_method("take_damage"):
			target.call("take_damage", amount, feedback)

	func ultimate_host_modifier(key: String, value: float, op: String) -> void:
		var multiplicative := op == "mul"
		var current := float(modifiers.get(key, 1.0 if multiplicative else 0.0))
		modifiers[key] = current * value if multiplicative else current + value

	func ultimate_host_effect_parent() -> Node:
		return self

	func ultimate_host_set_active(value: bool) -> void:
		active = value

	func ultimate_host_present(event_id: String, _payload: Dictionary) -> Node:
		presentations.append(event_id)
		var marker := Node2D.new()
		add_child(marker)
		return marker


class FixtureRegistry extends RefCounted:
	var profile: Dictionary = {}

	func resolution_source(class_id: String, weapon_id: String, _allow_legacy := true) -> String:
		if class_id != FIXTURE_CLASS or weapon_id != FIXTURE_WEAPON or profile.is_empty():
			return Resolver.SOURCE_LEGACY_CLASS_FALLBACK
		if str(profile.get("implementation_state", "")) != "ready":
			return Resolver.SOURCE_LEGACY_CLASS_FALLBACK
		return Resolver.SOURCE_WEAPON_PROFILE

	func catalog_profile_for(class_id: String, weapon_id: String) -> Dictionary:
		if class_id != FIXTURE_CLASS or weapon_id != FIXTURE_WEAPON:
			return {}
		return profile.duplicate(true)


var _errors: Array[String] = []
var _holder: Node2D = null


func _initialize() -> void:
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	await process_frame

	_test_strategy_coverage()
	_test_no_class_or_weapon_branches()
	await _test_invalid_ready_profile_refuses_before_activation()
	await _test_burst()
	await _test_aimed_sequence()
	await _test_timed_modifier()
	await _test_status_zone()
	await _test_control()
	await _test_deploy_summon()
	await _test_chained_projectile()
	await _test_declared_profile_defers_to_legacy()
	await _test_single_activation_and_reentry()
	await _test_gameplay_slow_time_uses_wall_time()
	await _test_pause_does_not_tick()
	await _test_cancel_clears_everything()
	await _test_applied_hp_not_attempted()
	await _test_total_boss_cap_across_activation()
	await _test_deferred_sink_shares_boss_budget()

	_holder.queue_free()
	await process_frame
	_report()


# --- acceptance: one generic path, no class or weapon branches ---------------

func _test_strategy_coverage() -> void:
	var ids := Library.strategy_ids()
	_check(
		ids == EXPECTED_STRATEGIES,
		"executor library must expose exactly the declared families, got %s" % str(ids)
	)


func _test_no_class_or_weapon_branches() -> void:
	var forbidden: Array[String] = []
	for raw_class_id in PD.WEAPONS_BY_CLASS.keys():
		forbidden.append(str(raw_class_id))
		var weapons = PD.WEAPONS_BY_CLASS[raw_class_id]
		if weapons is Dictionary:
			for raw_weapon_id in (weapons as Dictionary).keys():
				forbidden.append(str(raw_weapon_id))
	var scanned := 0
	for directory_path in RUNTIME_SOURCE_DIRECTORIES:
		var directory := DirAccess.open(directory_path)
		_check(directory != null, "runtime directory must exist: %s" % directory_path)
		if directory == null:
			continue
		for file_name in DirAccess.get_files_at(directory_path):
			if not file_name.ends_with(".gd"):
				continue
			scanned += 1
			var source := FileAccess.get_file_as_string("%s/%s" % [directory_path, file_name])
			for identifier in forbidden:
				# Quoted form only: a bare substring would flag ordinary words.
				_check(
					not source.contains('"%s"' % identifier),
					"%s must not branch on class/weapon id \"%s\"" % [file_name, identifier]
				)
	_check(scanned >= 9, "expected the controller and every executor to be scanned, got %d" % scanned)


# --- acceptance: every family runs from declaration data --------------------

func _test_burst() -> void:
	var fixture := await _make_fixture("burst", {"radius": 400.0, "damage": 1.0}, 3)
	var host: FixtureHost = fixture["host"]
	var controller: Controller = fixture["controller"]
	_check(controller.activate(FIXTURE_CLASS, FIXTURE_WEAPON), "burst must be taken by the runtime")
	for target in host.fixture_targets:
		_check((target as FixtureTarget).hits == 1, "burst must hit every target in radius once")
		_check(
			is_equal_approx((target as FixtureTarget).health, 90.0),
			"burst damage must be base * coefficient"
		)
	_check(not controller.is_active(), "an instant family must complete inside activate()")
	_check(not host.active, "host must be told the cast ended")
	await _drop(fixture)


func _test_aimed_sequence() -> void:
	var fixture := await _make_fixture(
		"aimed_sequence", {"radius": 400.0, "damage": 1.0, "shot_count": 3, "interval": 0.05}, 3
	)
	var host: FixtureHost = fixture["host"]
	var controller: Controller = fixture["controller"]
	var activation := _start(controller)
	_check(controller.is_active(), "a timed family must stay live after activate()")
	_check(host.damage_calls == 0, "aimed sequence must not resolve instantly")
	_advance(activation, 0.06)
	_check(host.damage_calls == 3, "first volley must hit every target after one interval, got %d" % host.damage_calls)
	_advance(activation, 0.12)
	_check(host.damage_calls == 9, "every declared volley must hit every target, got %d" % host.damage_calls)
	for target in host.fixture_targets:
		_check((target as FixtureTarget).hits == 3, "every target must receive every declared volley")
	_advance(activation, 0.06)
	_check(not controller.is_active(), "the cast must end when its declared duration elapses")
	await _drop(fixture)


func _test_timed_modifier() -> void:
	var fixture := await _make_fixture("timed_modifier", {
		"duration": 0.2,
		"modifiers": {
			"attack_speed_multiplier": {"value": 1.35, "op": "mul"},
			"absorb_flat": {"value": 8.0, "op": "add"},
		},
	}, 1)
	var host: FixtureHost = fixture["host"]
	var controller: Controller = fixture["controller"]
	host.modifiers["attack_speed_multiplier"] = 1.2
	var activation := _start(controller)
	_check(
		is_equal_approx(float(host.modifiers["attack_speed_multiplier"]), 1.62),
		"multiplicative modifier must stack onto the live value"
	)
	_check(is_equal_approx(float(host.modifiers["absorb_flat"]), 8.0), "additive modifier must apply")
	_advance(activation, 0.25)
	_check(not controller.is_active(), "timed modifier must end after its duration")
	_check(
		is_equal_approx(float(host.modifiers["attack_speed_multiplier"]), 1.2),
		"multiplicative modifier must unwind to the pre-cast value, got %f"
		% float(host.modifiers["attack_speed_multiplier"])
	)
	_check(
		is_equal_approx(float(host.modifiers["absorb_flat"]), 0.0),
		"additive modifier must unwind to the pre-cast value"
	)
	await _drop(fixture)


func _test_status_zone() -> void:
	var fixture := await _make_fixture("status_zone", {
		"radius": 400.0,
		"damage": 0.5,
		"duration": 0.2,
		"interval": 0.05,
		"status_id": "fixture_slow",
		"status": {"duration": 2.0, "speed_multiplier": 0.5},
	}, 2)
	var host: FixtureHost = fixture["host"]
	var controller: Controller = fixture["controller"]
	var activation := _start(controller)
	_advance(activation, 0.30)
	for target in host.fixture_targets:
		var fixture_target := target as FixtureTarget
		_check(fixture_target.hits == 4, "zone must tick once per interval, got %d" % fixture_target.hits)
		_check(
			is_equal_approx(fixture_target.health, 80.0),
			"zone tick damage must be base * coefficient, got %f" % fixture_target.health
		)
		_check(
			StatusEffects.has_status(fixture_target, "fixture_slow"),
			"zone must apply its declared status"
		)
	await _drop(fixture)


func _test_control() -> void:
	var fixture := await _make_fixture("control", {
		"radius": 400.0,
		"damage": 0.4,
		"knockback": 600.0,
		"status_id": "fixture_root",
		"status": {"duration": 1.0, "movement_lock": true},
	}, 3)
	var host: FixtureHost = fixture["host"]
	var controller: Controller = fixture["controller"]
	_check(controller.activate(FIXTURE_CLASS, FIXTURE_WEAPON), "control must be taken by the runtime")
	for target in host.fixture_targets:
		var fixture_target := target as FixtureTarget
		_check(fixture_target.knockbacks == 1, "control must displace each target once")
		_check(
			StatusEffects.has_status(fixture_target, "fixture_root"),
			"control must apply its declared status"
		)
		_check(is_equal_approx(fixture_target.health, 96.0), "control may carry declared damage")
	await _drop(fixture)


func _test_deploy_summon() -> void:
	var fixture := await _make_fixture("deploy_summon", {
		"scene": ALLY_MINION_SCENE_PATH,
		"count": 3,
		"spawn_radius": 60.0,
		"lifetime": 0.2,
		"damage": 0.8,
	}, 1)
	var host: FixtureHost = fixture["host"]
	var controller: Controller = fixture["controller"]
	var activation := _start(controller)
	var spawned := activation.spawned_for_tests()
	_check(spawned.size() == 3, "deploy must place every declared instance, got %d" % spawned.size())
	for node in spawned:
		_check(node.get_parent() == host, "deploy must parent into the host effect parent")
		_check(is_equal_approx(float(node.get("damage")), 8.0), "deploy must carry the scaled damage")
		_check(node.get("owner_node") == host, "deploy must attribute back to the host")
	_advance(activation, 0.25)
	_check(not controller.is_active(), "deploy lifetime must end the cast")
	await process_frame
	for node in spawned:
		_check(not is_instance_valid(node), "deploy must not outlive its activation")
	await _drop(fixture)


func _test_chained_projectile() -> void:
	var fixture := await _make_fixture(
		"chained_projectile",
		{"radius": 200.0, "damage": 1.0, "jumps": 3, "hop_delay": 0.05, "falloff": 0.5},
		3
	)
	var host: FixtureHost = fixture["host"]
	var controller: Controller = fixture["controller"]
	var activation := _start(controller)
	_advance(activation, 0.16)
	var damaged: Array[float] = []
	for target in host.fixture_targets:
		var fixture_target := target as FixtureTarget
		_check(fixture_target.hits == 1, "a chain must never revisit a target")
		damaged.append(100.0 - fixture_target.health)
	damaged.sort()
	_check(
		is_equal_approx(damaged[0], 2.5) and is_equal_approx(damaged[1], 5.0)
			and is_equal_approx(damaged[2], 10.0),
		"chain damage must decay by the declared falloff, got %s" % str(damaged)
	)
	await _drop(fixture)


# --- acceptance: migration bridge, single charge, pause, cleanup -------------

func _test_declared_profile_defers_to_legacy() -> void:
	var fixture := await _make_fixture("burst", {"radius": 400.0, "damage": 1.0}, 2)
	var host: FixtureHost = fixture["host"]
	var controller: Controller = fixture["controller"]
	var registry: FixtureRegistry = fixture["registry"]
	registry.profile["implementation_state"] = "declared"
	_check(
		not controller.activate(FIXTURE_CLASS, FIXTURE_WEAPON),
		"a declared profile must stay with the legacy class ultimate"
	)
	_check(host.damage_calls == 0, "a declined activation must not touch the world")
	_check(not host.active, "a declined activation must not mark the host busy")
	_check(
		not controller.activate("unknown_class", "unknown_weapon"),
		"an unknown pair must fail closed"
	)
	await _drop(fixture)


func _test_invalid_ready_profile_refuses_before_activation() -> void:
	var fixture := await _make_fixture("burst", {}, 0)
	var host: FixtureHost = fixture["host"]
	var controller: Controller = fixture["controller"]
	var registry: FixtureRegistry = fixture["registry"]
	registry.profile["executor"]["params"]["radius"] = NAN
	_check(
		not controller.activate(FIXTURE_CLASS, FIXTURE_WEAPON),
		"an invalid ready profile must be refused before executor admission"
	)
	_check(not controller.is_active(), "a refused profile must not create an activation")
	_check(controller.active_activation() == null, "a refused profile must leave no active state")
	_check(not host.active and host.damage_calls == 0, "a refused profile must not touch the host")
	await _drop(fixture)


func _test_single_activation_and_reentry() -> void:
	var fixture := await _make_fixture(
		"status_zone", {"radius": 400.0, "damage": 0.5, "duration": 0.2, "interval": 0.05}, 1
	)
	var host: FixtureHost = fixture["host"]
	var controller: Controller = fixture["controller"]
	var activation := _start(controller)
	_advance(activation, 0.06)
	var hits_after_first_tick := (host.fixture_targets[0] as FixtureTarget).hits
	_check(
		not controller.activate(FIXTURE_CLASS, FIXTURE_WEAPON),
		"a second input during a live cast must be refused"
	)
	_check(
		not controller.activate(FIXTURE_CLASS, FIXTURE_WEAPON),
		"re-entry must stay refused for as long as the cast is live"
	)
	_check(
		controller.active_activation() == activation,
		"a refused re-entry must not replace the live activation"
	)
	_advance(activation, 0.05)
	_check(
		(host.fixture_targets[0] as FixtureTarget).hits == hits_after_first_tick + 1,
		"a refused re-entry must not double the effect"
	)
	_advance(activation, 0.15)
	_check(controller.activate(FIXTURE_CLASS, FIXTURE_WEAPON), "a finished cast must be recastable")
	await _drop(fixture)


func _test_pause_does_not_tick() -> void:
	var fixture := await _make_fixture(
		"status_zone", {"radius": 400.0, "damage": 0.5, "duration": 4.0, "interval": 0.05}, 1
	)
	var host: FixtureHost = fixture["host"]
	var controller: Controller = fixture["controller"]
	var original_time_scale := Engine.time_scale
	Engine.time_scale = 0.1
	host.process_mode = Node.PROCESS_MODE_PAUSABLE
	paused = true
	_start(controller)
	var deadline := Time.get_ticks_msec() + 250
	while Time.get_ticks_msec() < deadline:
		await process_frame
	_check(controller.is_active(), "a paused tree must keep the slow-time cast live")
	_check(
		host.damage_calls == 0,
		"a paused tree must not advance a live cast, got %d ticks" % host.damage_calls
	)
	paused = false
	controller.cancel()
	Engine.time_scale = original_time_scale
	await _drop(fixture)


func _test_gameplay_slow_time_uses_wall_time() -> void:
	var fixture := await _make_fixture(
		"status_zone", {"radius": 400.0, "damage": 0.5, "duration": 0.2, "interval": 0.05}, 1
	)
	var host: FixtureHost = fixture["host"]
	var controller: Controller = fixture["controller"]
	var original_time_scale := Engine.time_scale
	Engine.time_scale = 0.1
	host.process_mode = Node.PROCESS_MODE_PAUSABLE
	_start(controller)
	var deadline := Time.get_ticks_msec() + 800
	while controller.is_active() and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(
		not controller.is_active(),
		"gameplay slow-time must not stretch an activation-owned tween in wall time"
	)
	_check(host.damage_calls == 4, "the slow-time cast must still execute every declared tick")
	if controller.is_active():
		controller.cancel()
	Engine.time_scale = original_time_scale
	await _drop(fixture)


func _test_cancel_clears_everything() -> void:
	var fixture := await _make_fixture("deploy_summon", {
		"scene": ALLY_MINION_SCENE_PATH,
		"count": 2,
		"lifetime": 5.0,
		"damage": 1.0,
	}, 1)
	var host: FixtureHost = fixture["host"]
	var controller: Controller = fixture["controller"]
	var activation := _start(controller)
	activation.apply_modifier("move_speed_multiplier", 1.5, Activation.OP_MULTIPLY)
	var spawned := activation.spawned_for_tests()
	var presentation := activation.presentation_for_tests()
	var tweens := activation.tweens_for_tests()
	_check(not spawned.is_empty() and not presentation.is_empty() and not tweens.is_empty(),
		"the cancel fixture must actually be holding resources")

	controller.cancel()
	await process_frame

	for tween in tweens:
		_check(tween == null or not tween.is_valid(), "cancel must kill every tracked tween")
	for node in spawned:
		_check(not is_instance_valid(node), "cancel must free every summon and deploy")
	for node in presentation:
		_check(not is_instance_valid(node), "cancel must clear presentation nodes")
	_check(
		is_equal_approx(float(host.modifiers.get("move_speed_multiplier", 1.0)), 1.0),
		"cancel must revert transient modifiers"
	)
	_check(not controller.is_active() and not host.active, "cancel must release the cast")
	_check(activation.is_finished(), "a cancelled activation must refuse further work")
	_check(
		activation.deal_damage(host.fixture_targets[0], 50.0).applied == 0.0,
		"a cancelled activation must not keep dealing damage"
	)
	await _drop(fixture)


# --- acceptance: applied HP and the whole-activation boss cap ---------------

func _test_applied_hp_not_attempted() -> void:
	var fixture := await _make_fixture("burst", {"radius": 400.0, "damage": 1.0}, 0)
	var controller: Controller = fixture["controller"]
	var host: FixtureHost = fixture["host"]
	var activation := Activation.new(host, {}, 0.0)

	var resistant := _add_target(host, Vector2.ZERO, false)
	resistant.damage_taken_multiplier = 0.5
	var resistant_result := activation.deal_damage(resistant, 40.0)
	_check(
		is_equal_approx(resistant_result.attempted, 40.0)
			and is_equal_approx(resistant_result.applied, 20.0),
		"applied must be the HP actually lost, not the attempted amount"
	)

	var dying := _add_target(host, Vector2.ZERO, false)
	dying.health = 5.0
	var overkill_result := activation.deal_damage(dying, 500.0)
	_check(
		is_equal_approx(overkill_result.applied, 5.0) and overkill_result.killed,
		"overkill must contribute only the HP that existed, got %f" % overkill_result.applied
	)
	_check(
		is_equal_approx(activation.applied_total, 25.0),
		"the activation ledger must sum applied HP, got %f" % activation.applied_total
	)
	_check(controller != null, "controller fixture must be constructed")
	activation.shutdown(true)
	await _drop(fixture)


func _test_total_boss_cap_across_activation() -> void:
	var fixture := await _make_fixture("status_zone", {
		"radius": 400.0,
		"damage": 5.0,
		"duration": 0.5,
		"interval": 0.05,
	}, 0, 0.1)
	var host: FixtureHost = fixture["host"]
	var controller: Controller = fixture["controller"]
	var boss := _add_target(host, Vector2.ZERO, true)
	boss.health = 1000.0
	boss.max_health = 1000.0
	var normal := _add_target(host, Vector2.ZERO, false)
	normal.health = 5000.0
	normal.max_health = 5000.0

	var activation := _start(controller)
	_advance(activation, 0.70)

	var boss_lost := 1000.0 - boss.health
	_check(
		is_equal_approx(boss_lost, 100.0),
		"the boss cap must bound the whole activation at max_health * total_boss_cap, got %f"
			% boss_lost
	)
	_check(boss.hits >= 2, "the cap must be a budget across hits, not a single-hit clamp")
	var normal_lost := 5000.0 - normal.health
	_check(
		is_equal_approx(normal_lost, 500.0),
		"normal enemies must stay fully exposed to the ultimate, got %f" % normal_lost
	)
	await _drop(fixture)


func _test_deferred_sink_shares_boss_budget() -> void:
	var fixture := await _make_fixture("burst", {"radius": 0.0, "damage": 1.0}, 0, 0.2)
	var host: FixtureHost = fixture["host"]
	var boss := _add_target(host, Vector2.ZERO, true)
	boss.health = 500.0
	boss.max_health = 500.0
	var activation := Activation.new(host, {}, 0.2)

	var summon := FixtureSink.new()
	host.add_child(summon)
	activation.bind_damage_sink(summon)
	_check(summon.ultimate_damage_sink.is_valid(), "a sink-aware spawn must be bound to the ledger")

	activation.deal_damage(boss, 60.0)
	summon.ultimate_damage_sink.call(boss, 60.0, {})
	summon.ultimate_damage_sink.call(boss, 60.0, {})
	_check(
		is_equal_approx(500.0 - boss.health, 100.0),
		"deferred summon damage must spend the same activation budget, got %f" % (500.0 - boss.health)
	)
	_check(
		is_equal_approx(activation.remaining_boss_budget(boss), 0.0),
		"the budget must be exhausted once the cap is reached"
	)
	activation.shutdown(true)
	summon.queue_free()
	await _drop(fixture)


# --- fixture plumbing --------------------------------------------------------

func _make_fixture(
	strategy_id: String,
	params: Dictionary,
	target_count: int,
	total_boss_cap := 0.0
) -> Dictionary:
	var host := FixtureHost.new()
	# Disabled processing keeps tree-driven tween stepping out of the way so the
	# suite advances time itself; the pause case re-enables it deliberately.
	host.process_mode = Node.PROCESS_MODE_DISABLED
	_holder.add_child(host)
	await process_frame
	for index in target_count:
		_add_target(host, Vector2.RIGHT.rotated(TAU * float(index) / maxf(target_count, 1.0)) * 60.0, false)
	var registry := FixtureRegistry.new()
	registry.profile = {
		"class_id": FIXTURE_CLASS,
		"weapon_id": FIXTURE_WEAPON,
		"implementation_state": "ready",
		"total_boss_cap": total_boss_cap,
		"executor": {"strategy_id": strategy_id, "params": _params(strategy_id, params)},
	}
	return {"host": host, "registry": registry, "controller": Controller.new(host, registry)}


func _params(strategy_id: String, overrides: Dictionary) -> Dictionary:
	var params: Dictionary = (BASE_PARAMS.get(strategy_id, {}) as Dictionary).duplicate(true)
	params.merge(overrides, true)
	return params


func _add_target(host: FixtureHost, offset: Vector2, is_boss: bool) -> FixtureTarget:
	var target := FixtureTarget.new()
	target.global_position = host.global_position + offset
	if is_boss:
		target.add_to_group(Activation.BOSS_GROUP)
	host.add_child(target)
	host.fixture_targets.append(target)
	return target


func _start(controller: Controller) -> Activation:
	_check(controller.activate(FIXTURE_CLASS, FIXTURE_WEAPON), "the runtime must take the cast")
	return controller.active_activation()


func _advance(activation: Activation, seconds: float) -> void:
	if activation == null:
		return
	var elapsed := 0.0
	while elapsed < seconds:
		for tween in activation.tweens_for_tests():
			if tween != null and tween.is_valid():
				tween.custom_step(STEP)
		elapsed += STEP


func _drop(fixture: Dictionary) -> void:
	var controller: Controller = fixture["controller"]
	controller.cancel()
	var host: FixtureHost = fixture["host"]
	host.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("controller_runtime_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("controller_runtime_test: %s" % error)
	print("controller_runtime_test: FAIL (%d)" % _errors.size())
	quit(1)
