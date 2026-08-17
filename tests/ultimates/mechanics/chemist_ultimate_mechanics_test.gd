extends SceneTree

## FAN-1483: the three Chemist weapon-ultimate mechanics.
##
## Every cast here goes through the SHIPPED package — the real registry, the
## real discovery pass and the real controller — so admission, resolution and
## runtime are one chain rather than three separately mocked halves. Timing is
## stepped manually, like the shared runtime suite, so the suite never depends
## on frame pacing.
##
## Run:
## python3 tools/godot_gate.py --headless --path . \
##   --script res://tests/ultimates/mechanics/chemist_ultimate_mechanics_test.gd

const PD := preload("res://scripts/progression_data.gd")
const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")
const BlastPowder := preload("res://scripts/ultimates/classes/chemist/blast_powder.gd")
const AcidFlask := preload("res://scripts/ultimates/classes/chemist/acid_flask.gd")
const HomunculusVial := preload("res://scripts/ultimates/classes/chemist/homunculus_vial.gd")

const CLASS_ID := "chemist"
const WEAPON_IDS := ["blast_powder", "acid_flask", "homunculus_vial"]
const PACKAGE_DATA_ROOT := "res://data/ultimates/classes/chemist"
const EXPECTED_BOSS_CAP := 0.1
const HOST_DAMAGE := 10.0
const STEP := 0.01


class FixtureEnemy extends Node2D:
	var health := 100.0
	var max_health := 100.0
	var impulse := Vector2.ZERO
	var hits := 0

	func take_damage(amount: float, _feedback := {}) -> void:
		hits += 1
		health = maxf(health - amount, 0.0)

	func apply_knockback(value: Vector2) -> void:
		impulse += value


class FixtureAlly extends Node2D:
	var owner_node: Node = null


class FixtureHost extends Node2D:
	var enemies: Array = []
	var allies: Array = []
	var aim_offset := Vector2.RIGHT * 200.0

	func ultimate_host_context() -> Dictionary:
		return {"damage": 10.0, "multiplier": 1.0, "damage_type": "physical"}

	func ultimate_host_position() -> Vector2:
		return global_position

	func ultimate_host_aim(max_range: float) -> Dictionary:
		var offset := aim_offset.limit_length(max_range)
		return {"point": global_position + offset, "direction": offset.normalized()}

	func ultimate_host_targets(center: Vector2, radius: float, limit: int) -> Array:
		var found: Array = []
		for raw_enemy in enemies:
			var enemy := raw_enemy as Node2D
			if enemy != null and is_instance_valid(enemy) \
					and enemy.global_position.distance_to(center) <= radius:
				found.append(enemy)
		found.sort_custom(func(left: Node2D, right: Node2D) -> bool:
			return left.global_position.distance_squared_to(center) \
				< right.global_position.distance_squared_to(center)
		)
		return found.slice(0, limit) if limit > 0 else found

	func ultimate_host_summons(_group_id: String) -> Array:
		return allies.duplicate()

	func ultimate_host_apply_damage(target: Node, amount: float, feedback: Dictionary) -> void:
		target.call("take_damage", amount, feedback)

	func ultimate_host_modifier(_key: String, _value: float, _operation: String) -> void:
		pass

	func ultimate_host_effect_parent() -> Node:
		return self

	func ultimate_host_present(_event_id: String, _payload: Dictionary) -> Node:
		return null

	func ultimate_host_set_active(_active: bool) -> void:
		pass


var _errors: Array[String] = []
var _holder: Node2D = null
var _registry = null


func _initialize() -> void:
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	await process_frame
	_registry = Registry.new(PD.WEAPONS_BY_CLASS)

	_test_package_admission()
	_test_declared_control_policies()
	await _test_blast_powder()
	await _test_acid_flask()
	await _test_homunculus_vial()

	_holder.queue_free()
	await process_frame
	_report()


# --- admission ---------------------------------------------------------------

## The shipped package must be the ONLY thing that became executable, and each
## weapon ID must reach its own profile and its own executor script.
func _test_package_admission() -> void:
	_check(_registry.is_valid(), "registry must stay valid: %s" % str(_registry.validation_errors()))
	_check(_registry.package_validation_errors().is_empty(),
		"chemist package must admit without errors: %s" % str(_registry.package_validation_errors()))
	var executable: Array = _registry.package_pair_keys()
	for weapon_id in WEAPON_IDS:
		_check(executable.has("%s/%s" % [CLASS_ID, weapon_id]),
			"chemist/%s must be executable, got %s" % [weapon_id, str(executable)])
	var chemist_pairs := 0
	for key in executable:
		if str(key).begins_with("%s/" % CLASS_ID):
			chemist_pairs += 1
	_check(chemist_pairs == WEAPON_IDS.size(),
		"chemist must contribute exactly three executable pairs, got %d" % chemist_pairs)

	var seen_executors := {}
	var seen_signatures := {}
	var seen_caps := {}
	for weapon_id in WEAPON_IDS:
		var key := "%s/%s" % [CLASS_ID, weapon_id]
		_check(_registry.resolution_source(CLASS_ID, weapon_id) == Resolver.SOURCE_WEAPON_PROFILE,
			"%s must resolve to its class-local profile, not a fallback" % key)
		var profile: Dictionary = _registry.catalog_profile_for(CLASS_ID, weapon_id)
		_check(str(profile.get("implementation_state", "")) == "ready", "%s must be ready" % key)
		var executor_binding: Dictionary = profile.get("executor", {})
		var executor_id := "weapon_ultimate.executor.%s.%s" % [CLASS_ID, weapon_id]
		_check(str(executor_binding.get("strategy_id", "")) == executor_id,
			"%s must bind its own executor id" % key)
		_check(is_equal_approx(float(profile.get("total_boss_cap", 0.0)), EXPECTED_BOSS_CAP),
			"%s must declare the class boss cap %.2f" % [key, EXPECTED_BOSS_CAP])
		seen_caps[snappedf(float(profile.get("total_boss_cap", 0.0)), 0.0001)] = true

		var executor = _registry.executor_for(CLASS_ID, weapon_id)
		_check(executor is GDScript, "%s must expose a class-local executor script" % key)
		if executor is GDScript:
			var constants := (executor as GDScript).get_script_constant_map()
			_check(str(constants.get("PROFILE_ID", "")) == str((profile.get("identity", {}) as Dictionary).get("profile_id", "")),
				"%s executor must own its profile id" % key)
			seen_executors[(executor as GDScript).resource_path] = weapon_id
		seen_signatures[JSON.stringify(executor_binding.get("params", {}), "", true)] = weapon_id

	_check(seen_executors.size() == WEAPON_IDS.size(), "the trio must not share an executor script")
	_check(seen_signatures.size() == WEAPON_IDS.size(), "the trio must not alias its executable contract")
	_check(seen_caps.size() == 1, "the class trio must declare exactly one boss cap")
	_check_no_leakage()


## No other pair may reach a chemist executor, and adding chemist may not change
## how any other pair resolves: a sibling package keeps its own package, a still
## declared pair keeps its legacy fallback.
func _check_no_leakage() -> void:
	var chemist_executors := {}
	for weapon_id in WEAPON_IDS:
		var executor = _registry.executor_for(CLASS_ID, weapon_id)
		if executor is GDScript:
			chemist_executors[(executor as GDScript).resource_path] = true
	for raw_class_id in PD.WEAPONS_BY_CLASS.keys():
		var class_id := str(raw_class_id)
		for raw_weapon_id in (PD.WEAPONS_BY_CLASS[class_id] as Dictionary).keys():
			var weapon_id := str(raw_weapon_id)
			if class_id == CLASS_ID:
				_check(WEAPON_IDS.has(weapon_id),
					"chemist must expose exactly its three canonical weapons, got %s" % weapon_id)
				continue
			var executor = _registry.executor_for(class_id, weapon_id)
			_check(not executor is GDScript
					or not chemist_executors.has((executor as GDScript).resource_path),
				"%s/%s must not resolve through a chemist executor" % [class_id, weapon_id])
			var expected := Resolver.SOURCE_WEAPON_PROFILE \
				if _registry.has_exact_executor_pair(class_id, weapon_id) \
				else Resolver.SOURCE_LEGACY_CLASS_FALLBACK
			_check(_registry.resolution_source(class_id, weapon_id) == expected,
				"%s/%s must keep resolving through its own package or its legacy fallback"
					% [class_id, weapon_id])


## A malformed tier policy would only surface halfway through a live cast, so the
## shipped declarations are admitted here instead.
func _test_declared_control_policies() -> void:
	for weapon_id in ["blast_powder", "homunculus_vial"]:
		var params := _declared_params(weapon_id)
		var errors := Library.validate_primitive_params(
			"control_resistance_policy", params.get("control_policy", {})
		)
		_check(errors.is_empty(), "%s control policy must be admitted: %s" % [weapon_id, str(errors)])
		var policy: Dictionary = params.get("control_policy", {})
		for tier in ["epic", "boss"]:
			_check(float((policy.get(tier, {}) as Dictionary).get("displacement_multiplier", 1.0)) < 1.0,
				"%s must resist %s displacement" % [weapon_id, tier])


# --- blast_powder ------------------------------------------------------------

func _test_blast_powder() -> void:
	var params := _declared_params("blast_powder")
	var host := await _make_host()
	var vertices := _pentagram_vertices(host, float(params["pentagram_radius"]))
	var normal := _add_enemy(host, vertices[0], "")
	var epic := _add_enemy(host, vertices[1], Activation.EPIC_GROUP)
	var boss := _add_enemy(host, vertices[2], Activation.BOSS_GROUP)
	var doomed := _add_enemy(host, vertices[3], "")
	doomed.health = 5.0
	var outsider := _add_enemy(host, host.global_position + Vector2.RIGHT * 2000.0, "")

	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "blast_powder"), "blast_powder must take the cast")
	var activation := controller.active_activation()
	if activation == null:
		await _drop(host, controller)
		return

	_advance(activation, float(params["pull_at"]) + 0.05)
	_check(normal.impulse.length() > 0.0 and normal.impulse.dot(host.global_position - normal.global_position) > 0.0,
		"the pentagram must pull a normal enemy inward")
	_check(StatusEffects.is_movement_locked(normal), "a crystallized normal enemy must be locked")
	_check(not StatusEffects.is_movement_locked(boss), "a boss must resist the crystal lock")
	_check(boss.impulse.length() < normal.impulse.length() * 0.5,
		"boss displacement must be resisted, got %.1f vs %.1f" % [boss.impulse.length(), normal.impulse.length()])
	_check(epic.impulse.length() < normal.impulse.length() * 0.5,
		"epic displacement must be resisted, got %.1f" % epic.impulse.length())

	var expected_target_cap := 100.0 * float(params["target_damage_cap"])
	var expected_boss_cap := 100.0 * EXPECTED_BOSS_CAP
	_advance(activation, float(params["detonate_at"]) - float(params["pull_at"]) + 0.05)
	_check(is_equal_approx(100.0 - normal.health, expected_target_cap),
		"the transmutation must be capped per target, removed %.2f" % (100.0 - normal.health))
	_check(is_equal_approx(100.0 - boss.health, expected_boss_cap),
		"the boss cap must bind the whole activation, removed %.2f" % (100.0 - boss.health))
	_check(is_zero_approx(doomed.health) and is_equal_approx(activation.applied_total,
			expected_target_cap + expected_boss_cap + expected_target_cap + 5.0),
		"attribution must count actual HP removed, got %.2f" % activation.applied_total)
	_check(is_equal_approx(outsider.health, 100.0), "the pentagram must not reach outside its charges")
	_check(activation.target_ledger_size_for_tests() == 0, "every crystal mark must be consumed once")

	# No recursive kill chain: the detonation only ever reads the recorded set,
	# and a second pass finds no mark left to consume.
	var before := normal.health
	var hits_before := normal.hits
	BlastPowder._transmute(activation, host.global_position, host.enemies)
	_check(is_equal_approx(normal.health, before) and normal.hits == hits_before,
		"a repeated transmutation must be a no-op")

	controller.cancel()
	_check(not controller.is_active() and activation.is_finished(), "cancel must end the cast")
	await _drop(host, controller)


# --- acid_flask --------------------------------------------------------------

func _test_acid_flask() -> void:
	var params := _declared_params("acid_flask")
	var host := await _make_host()
	var centre := host.global_position + host.aim_offset
	var soaked := _add_enemy(host, centre, "")
	soaked.health = 1000000.0
	soaked.max_health = 1000000.0
	var boss := _add_enemy(host, centre + Vector2.DOWN * 40.0, Activation.BOSS_GROUP)

	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "acid_flask"), "acid_flask must take the cast")
	var activation := controller.active_activation()
	if activation == null:
		await _drop(host, controller)
		return

	var owner_id := AcidFlask.charge_owner_id(activation)
	var tick_damage := HOST_DAMAGE * float(params["damage"])
	var conversion := float(params["charge_conversion"])
	_advance(activation, float(params["pour_at"]) + float(params["tick_interval"]) + 0.02)
	var first_tick := 1000000.0 - soaked.health
	_check(is_equal_approx(first_tick, tick_damage),
		"the first pour must corrode for one undissolved tick, removed %.2f" % first_tick)
	_check(is_equal_approx(float(activation.target_value(soaked, AcidFlask.DISSOLVE_KEY, 0.0)), 1.0),
		"a measured tick must dissolve one stack")
	# Both the soaked target and the boss were measured, so the charge is the
	# conversion of everything the tick actually removed, not of one target.
	_check(is_equal_approx(activation.owner_resource_amount(owner_id, AcidFlask.CHARGE_RESOURCE_ID),
			(first_tick + (100.0 - boss.health)) * conversion),
		"a measured tick must convert exactly what it removed, got %.3f"
			% activation.owner_resource_amount(owner_id, AcidFlask.CHARGE_RESOURCE_ID))

	# Armour dissolve: the second tick lands harder than the first by exactly
	# one declared stack, and nothing else.
	var before_second := soaked.health
	_advance(activation, float(params["tick_interval"]) + 0.02)
	_check(is_equal_approx(before_second - soaked.health, tick_damage * (1.0 + float(params["dissolve_bonus"]))),
		"the dissolved target must take the declared stack bonus, removed %.3f"
			% (before_second - soaked.health))
	_check(activation.owner_resource_amount(owner_id, AcidFlask.CHARGE_RESOURCE_ID)
			<= AcidFlask.charge_cap(activation) + 0.001,
		"the converted charge must stay inside its declared cap")

	# Stop just short of the recover pad: every tick and the finale have run, but
	# the activation is still live, so its ledgers are still readable.
	_advance(activation, float(params["tick_interval"]) * float(int(params["tick_count"]) - 2) + 0.1)
	_check(controller.is_active(), "the lake must still be live during its recovery beat")
	_check(is_equal_approx(float(activation.target_value(soaked, AcidFlask.DISSOLVE_KEY, 0.0)),
			float(params["dissolve_stack_cap"])),
		"dissolve must stop at its declared stack cap, got %.1f"
			% float(activation.target_value(soaked, AcidFlask.DISSOLVE_KEY, 0.0)))
	_check(is_equal_approx(activation.owner_resource_amount(owner_id, AcidFlask.CHARGE_RESOURCE_ID), 0.0),
		"the finale must spend the whole charge exactly once")
	_check(is_equal_approx(100.0 - boss.health, 100.0 * EXPECTED_BOSS_CAP),
		"the lake and its pillars must share one boss budget, removed %.2f" % (100.0 - boss.health))
	_check(soaked.hits > int(params["tick_count"]),
		"the pillars must land on top of every tick, got %d hits" % soaked.hits)
	_check(StatusEffects.snapshot(soaked).is_empty() and StatusEffects.snapshot(boss).is_empty(),
		"the lake must leave no status residue on its targets")

	# A repeated release finds the charge already consumed.
	var before_repeat := soaked.health
	AcidFlask._pillars(activation, centre, float(params["lake_radius"]))
	_check(is_equal_approx(soaked.health, before_repeat), "a repeated pillar release must be a no-op")

	# Encounter-bound cleanup: a cancel drops the lake even mid-pour.
	var hits_at_cancel := soaked.hits
	controller.cancel()
	_advance(activation, 2.0)
	_check(soaked.hits == hits_at_cancel, "a cancelled lake must stop ticking")
	_check(activation.tweens_for_tests().all(func(tween: Tween) -> bool: return not tween.is_valid()),
		"a cancelled lake must drop its tweens")
	_check(activation.target_ledger_size_for_tests() == 0, "a cancelled lake must clear its ledger")
	await _drop(host, controller)


# --- homunculus_vial ---------------------------------------------------------

func _test_homunculus_vial() -> void:
	var params := _declared_params("homunculus_vial")
	var host := await _make_host()
	var tank := _add_ally(host)
	var caster := _add_ally(host)
	# A pool the whole cascade fits inside: the escalation is asserted as an exact
	# formula, so an overkill clamp would hide the very bonus under test.
	var mob := _add_enemy(host, host.global_position + Vector2.RIGHT * 120.0, "")
	mob.health = 1000000.0
	mob.max_health = 1000000.0
	var boss := _add_enemy(host, host.global_position + Vector2.LEFT * 120.0, Activation.BOSS_GROUP)

	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "homunculus_vial"), "homunculus_vial must take the cast")
	var activation := controller.active_activation()
	if activation == null:
		await _drop(host, controller)
		return

	_check(activation.summon_snapshot_count_for_tests() == 2, "both persistent allies must be parked")
	_check(not tank.visible and not caster.visible, "the fused pair must leave the field")
	_check(tank.process_mode == Node.PROCESS_MODE_DISABLED, "a parked ally must stop acting")
	_check(activation.spawned_for_tests().size() == 1, "fusion must place exactly one avatar")
	var avatar: Node = activation.spawned_for_tests()[0] if not activation.spawned_for_tests().is_empty() else null
	_check(activation.spawn(str(params["avatar_scene"])) == null,
		"the temporary cap must refuse a second avatar")

	_advance(activation, float(params["fuse_at"]) + 0.05)
	_check(mob.impulse.length() > 0.0 and mob.impulse.dot(host.global_position - mob.global_position) > 0.0,
		"the taunt halo must drag the crowd onto the avatar")
	_check(boss.impulse.length() < mob.impulse.length() * 0.5, "a boss must resist the taunt pull")

	var beats := int(params["beat_count"])
	var stomp := HOST_DAMAGE * float(params["damage"])
	var bonus := float(params["wave_toxin_bonus"])
	# Beat 1 lands undosed, beat 2 carries one cascade stack, beat 3 carries two.
	var expected := 0.0
	for beat_index in beats:
		expected += stomp * (1.0 + bonus * float(beat_index))
	_advance(activation, float(params["beat_interval"]) * float(beats) + 0.05)
	_check(is_equal_approx(1000000.0 - mob.health, expected),
		"the cascade must escalate every stomp, removed %.3f vs %.3f" % [1000000.0 - mob.health, expected])
	_check(is_equal_approx(100.0 - boss.health, 100.0 * EXPECTED_BOSS_CAP),
		"stomps must share one boss budget, removed %.2f" % (100.0 - boss.health))
	_check(is_equal_approx(float(activation.target_value(mob, HomunculusVial.TOXIN_KEY, 0.0)), float(beats)),
		"each toxic wave must add one cascade stack")

	for extra in range(beats, beats + 3):
		HomunculusVial._beat(activation, avatar, extra)
	_check(is_equal_approx(float(activation.target_value(mob, HomunculusVial.TOXIN_KEY, 0.0)),
			float(params["wave_stack_cap"])),
		"the cascade must stop at its declared stack cap, got %.1f"
			% float(activation.target_value(mob, HomunculusVial.TOXIN_KEY, 0.0)))
	_check(StatusEffects.snapshot(boss).is_empty() or not StatusEffects.snapshot(boss).has("homunculus_caster_dot"),
		"the avatar must not write the persistent caster's permanent charge")

	controller.cancel()
	await process_frame
	_check(avatar == null or not is_instance_valid(avatar), "the avatar must not outlive the cast")
	_check(is_instance_valid(tank) and is_instance_valid(caster),
		"the split must return the original pair, not a copy")
	_check(tank.visible and caster.visible, "the pair must come back to the field")
	_check(tank.process_mode != Node.PROCESS_MODE_DISABLED, "a restored ally must act again")
	_check(host.allies.size() == 2, "the fusion must not duplicate the pair")
	await _drop(host, controller)


# --- fixture plumbing --------------------------------------------------------

func _declared_params(weapon_id: String) -> Dictionary:
	var parsed = JSON.parse_string(
		FileAccess.get_file_as_string("%s/%s.json" % [PACKAGE_DATA_ROOT, weapon_id])
	)
	if not parsed is Dictionary:
		_check(false, "%s declaration must parse" % weapon_id)
		return {}
	return ((parsed as Dictionary)["executor"] as Dictionary)["params"] as Dictionary


func _make_host() -> FixtureHost:
	var host := FixtureHost.new()
	# Disabled processing keeps the tree from stepping the cast tweens: this
	# suite advances them itself.
	host.process_mode = Node.PROCESS_MODE_DISABLED
	_holder.add_child(host)
	await process_frame
	return host


func _add_enemy(host: FixtureHost, position: Vector2, group: String) -> FixtureEnemy:
	var enemy := FixtureEnemy.new()
	enemy.global_position = position
	if not group.is_empty():
		enemy.add_to_group(group)
	host.add_child(enemy)
	host.enemies.append(enemy)
	return enemy


func _add_ally(host: FixtureHost) -> FixtureAlly:
	var ally := FixtureAlly.new()
	ally.owner_node = host
	host.add_child(ally)
	host.allies.append(ally)
	return ally


func _pentagram_vertices(host: FixtureHost, radius: float) -> Array:
	var points: Array = []
	for index in BlastPowder.PENTAGRAM_VERTICES:
		points.append(host.global_position + Vector2.RIGHT.rotated(
			deg_to_rad(BlastPowder.PENTAGRAM_ROTATION_DEGREES) + TAU * float(index) / 5.0
		) * radius)
	return points


func _advance(activation: Activation, seconds: float) -> void:
	if activation == null:
		return
	var elapsed := 0.0
	while elapsed < seconds:
		for tween in activation.tweens_for_tests():
			if tween != null and tween.is_valid():
				tween.custom_step(STEP)
		elapsed += STEP


func _drop(host: FixtureHost, controller: Controller) -> void:
	controller.cancel()
	host.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("chemist_ultimate_mechanics_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("chemist_ultimate_mechanics_test: %s" % error)
	print("chemist_ultimate_mechanics_test: FAIL (%d)" % _errors.size())
	quit(1)
