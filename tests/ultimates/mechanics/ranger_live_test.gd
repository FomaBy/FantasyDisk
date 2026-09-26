extends SceneTree

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Ledger := preload("res://scripts/ultimates/balance/ultimate_charge_ledger.gd")
const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const PlayerScene := preload("res://scenes/Player.tscn")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")
const PD := preload("res://scripts/progression_data.gd")
const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")
const DirectionContract := preload("res://scripts/ultimates/presentation/ultimate_visual_direction_contract.gd")

const CLASS_ID := "ranger"
const WEAPONS := ["moon_crossbow", "storm_longbow", "hunter_trap"]
const STEP := 0.01
const AIM_RANGE := 620.0
const BASE_DAMAGE := 12.0
const MARK_KEY := "moon_mark"


class Target extends Node2D:
	var health := 10000.0
	var max_health := 10000.0
	var received: Array[Dictionary] = []
	var knockback := Vector2.ZERO
	var ultimate_impact_flashes := 0

	func take_damage(amount: float, feedback := {}) -> void:
		received.append({"amount": amount, "feedback": feedback.duplicate(true)})
		health = maxf(health - amount, 0.0)

	func apply_knockback(impulse: Vector2) -> void:
		knockback += impulse

	func _show_hit_flash() -> void:
		ultimate_impact_flashes += 1

	func total_received() -> float:
		var total := 0.0
		for entry in received:
			total += float(entry["amount"])
		return total


class Host extends Node2D:
	var fixture_targets: Array[Node2D] = []
	var active := false

	func ultimate_host_context() -> Dictionary:
		return {"damage": BASE_DAMAGE, "multiplier": 1.0, "damage_type": "physical"}

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
		"Ranger packages must admit cleanly: %s" % [_registry.package_validation_errors()])
	await _test_moon_hunt()
	await _test_moon_mark_transfer()
	await _test_moon_mark_skips_a_dead_neighbour()
	await _test_moon_mark_without_a_living_heir()
	await _test_storm_corridor()
	await _test_grand_trap()
	await _test_victim_impact_paths()
	_test_victim_impact_source_contract()
	await _test_real_player_path()
	_test_charge_contract()
	_holder.queue_free()
	await process_frame
	_report()


## The prey is the heaviest silhouette inside the aimed circle, not the nearest
## body; the four split bolts must reach four distinct neighbours and no fifth.
func _test_moon_hunt() -> void:
	var host := _host()
	var prey := _target(host, Vector2(AIM_RANGE, 0.0))
	prey.add_to_group("bosses")
	var decoy := _target(host, Vector2(AIM_RANGE - 200.0, 0.0), 900.0)
	var neighbours: Array[Target] = []
	for index in 5:
		neighbours.append(_target(host, Vector2(AIM_RANGE + 40.0 + 20.0 * float(index), 60.0), 900.0))
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "moon_crossbow"), "Moon Hunt must activate")
	var activation = controller.active_activation()
	var effect := _effect(activation)
	_check(effect != null and effect.get("marked_target_for_tests") == prey,
		"the moon mark must land on the aimed highest-HP prey, not on the nearest body")
	_advance(activation, 0.71)
	_check(int(effect.get("wave_count_for_tests")) == 1 and int(effect.get("split_count_for_tests")) == 4,
		"the first wave must split into exactly four neighbours")
	var struck := 0
	for neighbour in neighbours:
		if neighbour.received.size() > 0:
			struck += 1
	_check(struck == 4, "the split must reach four distinct neighbours, got %d" % struck)
	_check(decoy.received.is_empty(), "the split must stay inside its declared radius")
	_advance(activation, 3.25)
	_check(int(effect.get("wave_count_for_tests")) == 5,
		"the hunt must resolve its five declared bolt waves")
	var removed := prey.max_health - prey.health
	_check(removed > 0.0 and removed <= prey.max_health * 0.09,
		"every bolt wave must share the nine-percent whole-activation boss cap")
	controller.cancel()
	await process_frame
	_check(not is_instance_valid(effect) and not host.active,
		"cancellation must remove the hunt scene and its active latch")
	await _drop(host)


## A killed prey hands the mark on instead of ending the hunt early.
func _test_moon_mark_transfer() -> void:
	var host := _host()
	# The prey still has to be the heaviest silhouette in the aimed circle, so the
	# heir sits just below it and survives the split bolt that comes with the kill.
	var prey := _target(host, Vector2(AIM_RANGE, 0.0), 260.0)
	var heir := _target(host, Vector2(AIM_RANGE + 60.0, 0.0), 200.0)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "moon_crossbow"), "Moon Hunt must activate")
	var activation = controller.active_activation()
	var effect := _effect(activation)
	_advance(activation, 0.71)
	_check(is_zero_approx(prey.health) and int(effect.get("mark_transfer_count_for_tests")) == 1,
		"a lethal wave must transfer the mark to a surviving neighbour")
	_check(effect.get("marked_target_for_tests") == heir, "the heir must carry the moon mark")
	var before := heir.total_received()
	_advance(activation, 0.8)
	_check(heir.total_received() > before + BASE_DAMAGE * 25.0 * 0.5,
		"the next wave must land a full bolt on the transferred mark")
	controller.cancel()
	await process_frame
	await _drop(host)


## The split bolts of a wave land before that wave picks the heir, so the nearest
## neighbour can already be a corpse when the mark moves. The mark has to walk
## past it to the nearest neighbour that still holds health.
func _test_moon_mark_skips_a_dead_neighbour() -> void:
	var host := _host()
	var prey := _target(host, Vector2(AIM_RANGE, 0.0), 260.0)
	var corpse := _target(host, Vector2(AIM_RANGE + 40.0, 0.0), 1.0)
	var heir := _target(host, Vector2(AIM_RANGE + 80.0, 0.0), 200.0)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "moon_crossbow"), "Moon Hunt must activate")
	var activation = controller.active_activation()
	var effect := _effect(activation)
	_advance(activation, 0.71)
	_check(is_zero_approx(prey.health) and is_zero_approx(corpse.health),
		"the lethal wave must kill the prey and its one-HP nearest neighbour")
	_check(effect != null and effect.get("marked_target_for_tests") == heir
		and int(effect.get("mark_transfer_count_for_tests")) == 1,
		"the mark must skip the killed nearest neighbour and reach the closest survivor")
	_check(activation.target_value(corpse, MARK_KEY) == null,
		"a zero-HP neighbour must never hold the moon mark")
	var before := heir.total_received()
	_advance(activation, 0.8)
	_check(heir.total_received() > before + BASE_DAMAGE * 25.0 * 0.5,
		"the next wave must land a full bolt on the surviving heir")
	controller.cancel()
	await process_frame
	await _drop(host)


## Nothing survives the wave that kills the prey: the hunt releases the mark
## instead of parking it on a corpse, and its remaining waves stay silent.
func _test_moon_mark_without_a_living_heir() -> void:
	var host := _host()
	var prey := _target(host, Vector2(AIM_RANGE, 0.0), 260.0)
	var near_corpse := _target(host, Vector2(AIM_RANGE + 40.0, 0.0), 1.0)
	var far_corpse := _target(host, Vector2(AIM_RANGE + 80.0, 0.0), 1.0)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "moon_crossbow"), "Moon Hunt must activate")
	var activation = controller.active_activation()
	var effect := _effect(activation)
	_advance(activation, 0.71)
	_check(is_zero_approx(near_corpse.health) and is_zero_approx(far_corpse.health),
		"the split bolts must kill both one-HP neighbours")
	_check(effect != null and effect.get("marked_target_for_tests") == null
		and int(effect.get("mark_transfer_count_for_tests")) == 0,
		"a wave that leaves no survivor must hand the mark to nobody")
	_check(activation.target_value(prey, MARK_KEY) == null,
		"the released mark must not stay on the killed prey")
	var removed := prey.total_received() + near_corpse.total_received() \
		+ far_corpse.total_received()
	_advance(activation, 3.25)
	_check(int(effect.get("wave_count_for_tests")) == 1
		and int(effect.get("split_count_for_tests")) == 2,
		"the released hunt must not fire another wave or split")
	_check(is_equal_approx(prey.total_received() + near_corpse.total_received()
		+ far_corpse.total_received(), removed),
		"the released hunt must not keep shooting the corpses")
	controller.cancel()
	await process_frame
	_check(not is_instance_valid(effect) and not host.active,
		"cleanup after a released mark must remove the hunt scene and its active latch")
	await _drop(host)


## The corridor is walked tail to tip: the body closest to the beat front takes
## the full strike, everything else decays, and every struck body is displaced
## off the axis under the shared control-resistance policy.
func _test_storm_corridor() -> void:
	var host := _host()
	var near := _target(host, Vector2(200.0, 20.0))
	var middle := _target(host, Vector2(430.0, -30.0))
	var epic := _target(host, Vector2(600.0, 60.0))
	epic.add_to_group("elite_enemies")
	var boss := _target(host, Vector2(700.0, -40.0))
	boss.add_to_group("bosses")
	var outside := _target(host, Vector2(400.0, 260.0))
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "storm_longbow"), "Storm Eye must activate")
	var activation = controller.active_activation()
	var effect := _effect(activation)
	_check(effect != null and int(effect.get("rail_size_for_tests")) == 4,
		"only the four bodies inside the corridor may enter the rail")
	_advance(activation, 0.56)
	_check(int(effect.get("beat_count_for_tests")) == 1, "the first beat must resolve after the windup")
	_check(near.total_received() > middle.total_received()
		and middle.total_received() > epic.total_received(),
		"the beat must decay away from its own front")
	_check(outside.received.is_empty(), "the corridor must stay inside its declared half width")
	_check(near.knockback.length() > 0.0 and absf(near.knockback.x) < 0.001,
		"the storm must push its targets off the axis, never along it")
	_check(near.knockback.y > 0.0 and middle.knockback.y < 0.0,
		"each body must be pushed to its own side of the safe axis")
	var normal_status := _status(near, "ranger_ultimate_storm_")
	var epic_status := _status(epic, "ranger_ultimate_storm_")
	var boss_status := _status(boss, "ranger_ultimate_storm_")
	_check(is_equal_approx(float(normal_status.get("duration", 0.0)), 2.6)
		and not bool(normal_status.get("movement_locked", false)),
		"the storm must slow without ever pinning a normal target")
	_check(is_equal_approx(float(epic_status.get("duration", 0.0)), 1.17)
		and is_equal_approx(float(boss_status.get("duration", 0.0)), 0.52),
		"epic and boss shocks must use the shared control-resistance policy")
	_check(boss.knockback.length() < epic.knockback.length()
		and epic.knockback.length() < near.knockback.length(),
		"displacement must shrink with the resistant tiers")
	_advance(activation, 3.1)
	_check(int(effect.get("beat_count_for_tests")) == 6,
		"the corridor must resolve its six declared beats")
	_check(boss.max_health - boss.health <= boss.max_health * 0.09,
		"all beats must share the nine-percent whole-activation boss cap")
	controller.cancel()
	await process_frame
	for target in [near, middle, epic, boss]:
		_check(_status(target, "ranger_ultimate_storm_").is_empty(),
			"corridor cleanup must remove only its own leased shock")
	await _drop(host)


## Three inward rings then one chain-net closure: the jaws bite one body, the
## chain shares a declared fraction with everything else it still holds.
func _test_grand_trap() -> void:
	var host := _host()
	var boss := _target(host, Vector2(520.0, 0.0))
	boss.add_to_group("bosses")
	var normal := _target(host, Vector2(560.0, 0.0))
	var epic := _target(host, Vector2(620.0, 0.0))
	epic.add_to_group("elite_enemies")
	var foreign := _target(host, Vector2(600.0, 0.0))
	StatusEffects.apply_status(foreign, "foreign_status", {"duration": 9.0})
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "hunter_trap"), "Grand Trap must activate")
	var activation = controller.active_activation()
	var effect := _effect(activation)
	_advance(activation, 0.86)
	_check(effect != null and int(effect.get("ring_count_for_tests")) == 1
		and effect.get("jaw_target_for_tests") == boss,
		"the first ring must bite the body nearest the trap centre")
	_check(is_equal_approx(normal.total_received(), BASE_DAMAGE * 67.5 * 0.11),
		"everything the jaws did not bite must keep only the declared chain share")
	_check(normal.knockback.length() > 0.0
		and (normal.global_position + normal.knockback).x < normal.global_position.x,
		"the trap must pull what it catches toward its centre")
	var normal_status := _status(normal, "ranger_ultimate_trap_")
	var epic_status := _status(epic, "ranger_ultimate_trap_")
	_check(bool(normal_status.get("movement_locked", false))
		and is_equal_approx(float(normal_status.get("duration", 0.0)), 3.4),
		"normal targets must stay locked in the jaws")
	_check(not bool(epic_status.get("movement_locked", false))
		and is_equal_approx(float(epic_status.get("duration", 0.0)), 1.53),
		"resistant tiers must keep only the shortened jaw slow")
	_advance(activation, 3.8)
	_check(int(effect.get("ring_count_for_tests")) == 3
		and int(effect.get("closure_count_for_tests")) == 1,
		"the trap must resolve three rings and exactly one chain-net closure")
	_check(boss.max_health - boss.health <= boss.max_health * 0.09,
		"rings and closure must share the nine-percent whole-activation boss cap")
	controller.cancel()
	await process_frame
	for target in [boss, normal, epic]:
		_check(_status(target, "ranger_ultimate_trap_").is_empty(),
			"trap cleanup must remove only its own leased jaws")
	_check(StatusEffects.snapshot(foreign).has("foreign_status"),
		"trap cleanup must leave a foreign status untouched")
	await _drop(host)


## Each Ranger ultimate must open its own real per-victim reader only after it
## lands a hit. The test drives the executor through its live controller path,
## then advances the reader far enough to require the victim-side white flash.
func _test_victim_impact_paths() -> void:
	for weapon_id in WEAPONS:
		var host := _host()
		match weapon_id:
			"moon_crossbow":
				_target(host, Vector2(AIM_RANGE, 0.0))
			"storm_longbow":
				_target(host, Vector2(200.0, 0.0))
			"hunter_trap":
				_target(host, Vector2(520.0, 0.0))
		var controller := Controller.new(host, _registry)
		_check(controller.activate(CLASS_ID, weapon_id), "%s must activate for its victim-impact contour" % weapon_id)
		var activation = controller.active_activation()
		var effect := _effect(activation)
		_check(_impact_player(effect) == null, "%s must not create a victim impact before a hit" % weapon_id)
		_advance(activation, 0.86 if weapon_id == "hunter_trap" else 0.71 if weapon_id == "moon_crossbow" else 0.56)
		var impacts := _impact_player(effect)
		_check(impacts != null, "%s must route hit victims through UltimateVictimImpactPlayer" % weapon_id)
		if impacts != null:
			var snapshot := impacts.call("snapshot") as Dictionary
			_check(int(snapshot.get("victims", 0)) > 0, "%s must enqueue its actual hit victims" % weapon_id)
			impacts.call("advance", 1.0)
			var flashed := false
			for target in host.fixture_targets:
				flashed = flashed or int((target as Target).ultimate_impact_flashes) > 0
			_check(flashed, "%s must play the victim-side hit flash" % weapon_id)
		controller.cancel()
		await process_frame
		_check(not is_instance_valid(effect), "%s cleanup must remove its impact owner without orphans" % weapon_id)
		await _drop(host)


## The live registry is the source of the Ranger roster. A local copy of those
## same source files is the negative control: removing one real construction
## must make the class-local contract fail closed for exactly that weapon.
func _test_victim_impact_source_contract() -> void:
	var canonical: Array[String] = []
	for key in _registry.package_pair_keys():
		if str(key).begins_with(CLASS_ID + "/"):
			canonical.append(str(key).trim_prefix(CLASS_ID + "/"))
	canonical.sort()
	var expected := WEAPONS.duplicate()
	expected.sort()
	_check(canonical == expected, "live Ranger schema must enumerate exactly %s, got %s" % [expected, canonical])
	var weapons: Array[Dictionary] = []
	for weapon_id in canonical:
		weapons.append({"weapon_id": weapon_id})
	var live_violations := DirectionContract.victim_impact_violations_from_sources(CLASS_ID, weapons)
	_check(live_violations.is_empty(), "every canonical Ranger ultimate must instantiate UltimateVictimImpactPlayer: %s" % [live_violations])

	var fixture_root := ProjectSettings.globalize_path("user://ranger_victim_impact_source_probe")
	for weapon in weapons:
		var weapon_id := str(weapon["weapon_id"])
		var fixture_path := fixture_root.path_join("scripts/ultimates/classes/%s/%s.gd" % [CLASS_ID, weapon_id])
		DirAccess.make_dir_recursive_absolute(fixture_path.get_base_dir())
		var source_path := "res://scripts/ultimates/classes/%s/%s.gd" % [CLASS_ID, weapon_id]
		var fixture := FileAccess.open(fixture_path, FileAccess.WRITE)
		fixture.store_string(FileAccess.get_file_as_string(source_path))
		fixture.close()
	_check(DirectionContract.victim_impact_violations_from_sources(CLASS_ID, weapons, fixture_root).is_empty(),
		"the mirrored Ranger mappings must all satisfy the source contract")
	var broken_id := str(weapons[0]["weapon_id"])
	var broken_path := fixture_root.path_join("scripts/ultimates/classes/%s/%s.gd" % [CLASS_ID, broken_id])
	var broken_source := FileAccess.get_file_as_string(broken_path).replace("ImpactPlayer.new()", "Node2D.new()")
	var broken := FileAccess.open(broken_path, FileAccess.WRITE)
	broken.store_string(broken_source)
	broken.close()
	var broken_violations := DirectionContract.victim_impact_violations_from_sources(CLASS_ID, weapons, fixture_root)
	_check(broken_violations == ["victim_impact.unwired: %s/%s routes no victim through UltimateVictimImpactPlayer" % [CLASS_ID, broken_id]],
		"removing one Ranger impact construction must fail closed, got %s" % [broken_violations])


func _test_real_player_path() -> void:
	for weapon_id in WEAPONS:
		var player := PlayerScene.instantiate() as Node2D
		_holder.add_child(player)
		await process_frame
		player.call("configure_character", CLASS_ID, weapon_id)
		await process_frame
		player.set_process(false)
		player.set_physics_process(false)
		var prey := _prey_at(player.call("attack_aim_position", AIM_RANGE))
		await process_frame
		player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
		_check(bool(player.call("activate_ultimate")),
			"%s must activate through the real Player entry point" % weapon_id)
		var controller = PlayerHost.for_player(player).controller()
		var activation = controller.active_activation()
		var spawned: Array[Node] = activation.spawned_for_tests() if activation != null else []
		_check(controller.is_active() and spawned.size() == 1,
			"%s must own one live activation scene through Player" % weapon_id)
		if spawned.size() == 1:
			_check(spawned[0].has_node("Presentation"),
				"%s must embed its accepted Ranger presentation scene" % weapon_id)
		_check(is_zero_approx(float(player.get("ultimate_charge"))),
			"%s must spend the real Player charge exactly once" % weapon_id)
		player.call("_gain_ultimate_charge", float(player.get("ultimate_max_charge")))
		_check(is_zero_approx(float(player.get("ultimate_charge"))),
			"%s must reject Player charge gain while active" % weapon_id)
		player.call("configure_character", CLASS_ID, weapon_id)
		await process_frame
		_check(not controller.is_active() and not bool(player.get("_ultimate_active")),
			"a new run must cancel %s through the real Player path" % weapon_id)
		for node in spawned:
			_check(not is_instance_valid(node),
				"a new run must clean the activation-owned effect from %s" % weapon_id)
		prey.queue_free()
		player.queue_free()
		await process_frame


func _test_charge_contract() -> void:
	var rows := Budget.build_rows(PD.WEAPONS_BY_CLASS, PD)
	for weapon_id in WEAPONS:
		var row := Budget.row_for(rows, CLASS_ID, weapon_id)
		var ledger := Ledger.new(row)
		ledger.begin_encounter(Budget.ENCOUNTER_NORMAL)
		ledger.apply_start_charge(1.0)
		_check(ledger.try_activate(), "%s must spend one full charge" % weapon_id)
		ledger.apply_start_charge(1.0)
		_check(not ledger.try_activate(), "%s must refuse a second cast in one encounter" % weapon_id)
		ledger.set_ultimate_active(true)
		var before := ledger.charge
		ledger.add_removed_health(float(row["reference_solo_dps"]) * 30.0)
		_check(is_equal_approx(ledger.charge, before), "%s must not earn active-window charge" % weapon_id)
		ledger.set_ultimate_active(false)
		ledger.apply_start_charge(0.63)
		var restored := Ledger.new(row)
		restored.apply_snapshot(ledger.to_snapshot())
		_check(is_equal_approx(restored.charge, 63.0),
			"%s charge must survive battle, act and Continue snapshots" % weapon_id)


func _host() -> Host:
	var host := Host.new()
	_holder.add_child(host)
	return host


func _target(host: Host, position: Vector2, health := 10000.0) -> Target:
	var target := Target.new()
	target.health = health
	target.max_health = health
	target.global_position = position
	host.add_child(target)
	host.fixture_targets.append(target)
	return target


## The real Player resolves enemies through the shared combat query, so the
## Player-path prey has to be a real member of the enemy group.
func _prey_at(position) -> Target:
	var prey := Target.new()
	prey.global_position = position as Vector2 if position is Vector2 else Vector2.ZERO
	prey.add_to_group("enemies")
	_holder.add_child(prey)
	return prey


func _effect(activation) -> Node:
	if activation == null:
		return null
	var spawned: Array = activation.spawned_for_tests()
	return spawned[0] if not spawned.is_empty() else null


func _impact_player(effect: Node) -> Node:
	if effect == null:
		return null
	for child in effect.get_children():
		if child.get_script() == ImpactPlayer:
			return child
	return null


func _advance(activation, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds and activation != null and not activation.is_finished():
		var step := minf(STEP, seconds - elapsed)
		for tween in activation.tweens_for_tests():
			if tween != null and tween.is_valid():
				tween.custom_step(step)
		elapsed += step


func _status(target: Node, prefix: String) -> Dictionary:
	for status_id in StatusEffects.snapshot(target):
		if str(status_id).begins_with(prefix):
			return StatusEffects.snapshot(target)[status_id] as Dictionary
	return {}


func _drop(host: Host) -> void:
	host.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("ranger_live_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("ranger_live_test: %s" % error)
	quit(1)
