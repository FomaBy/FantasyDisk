extends SceneTree

## Real-Player wall-time regression for every currently ready class package
## whose lifecycle is owned by an UltimateActivation tween.
##
## Run:
## python3 tools/godot_gate.py --headless --path . \
##   --script res://tests/ultimates/tracked_tween_natural_completion_test.gd

const PlayerScene := preload("res://scenes/Player.tscn")
const EnemyScene := preload("res://scenes/Enemy.tscn")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")
const PD := preload("res://scripts/progression_data.gd")

const GAMEPLAY_TIME_SCALE := 0.5
const COMPLETION_GRACE_SECONDS := 1.0
const PLAYER_SPACING := 2500.0
const LIFECYCLE_SPECS := [
	{"class_id": "biologist", "weapon_id": "biologist_sample_injector", "lifecycle": 10.65, "deadline": 11.65},
	{"class_id": "biologist", "weapon_id": "biologist_symbiote_seed", "lifecycle": 9.0, "deadline": 10.0},
	{"class_id": "biologist", "weapon_id": "biologist_spore_lens", "lifecycle": 8.6, "deadline": 9.6},
	{"class_id": "guitarist", "weapon_id": "sound_amp", "lifecycle": 6.0, "deadline": 7.0},
	{"class_id": "guitarist", "weapon_id": "bass_guitar", "lifecycle": 5.8, "deadline": 6.8},
	{"class_id": "engineer", "weapon_id": "engineer_repair_drone", "lifecycle": 5.5, "deadline": 6.5},
	{"class_id": "guitarist", "weapon_id": "electric_guitar", "lifecycle": 5.4, "deadline": 6.4},
	{"class_id": "engineer", "weapon_id": "engineer_sentry_wrench", "lifecycle": 4.6, "deadline": 5.6},
	{"class_id": "sniper", "weapon_id": "sniper_spotter_scope", "lifecycle": 4.4, "deadline": 5.4},
	{"class_id": "engineer", "weapon_id": "engineer_pressure_mines", "lifecycle": 4.0, "deadline": 5.0},
	{"class_id": "thief", "weapon_id": "thief_smoke_bomb", "lifecycle": 4.0, "deadline": 5.0},
	{"class_id": "sniper", "weapon_id": "sniper_shatter_rounds", "lifecycle": 2.82, "deadline": 3.82},
	{"class_id": "thief", "weapon_id": "thief_shadow_cloak", "lifecycle": 1.26, "deadline": 2.26},
	{"class_id": "thief", "weapon_id": "thief_coin_pouch", "lifecycle": 1.0, "deadline": 2.0},
	{"class_id": "sniper", "weapon_id": "sniper_deadeye_rifle", "lifecycle": 0.25, "deadline": 1.25},
]

var _errors: Array[String] = []
var _holder: Node2D = null


func _initialize() -> void:
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	root.set_meta("combat_feedback", false)
	await process_frame

	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	_check(
		registry.is_valid() and registry.validation_errors().is_empty(),
		"catalog must admit cleanly: %s" % [registry.validation_errors()]
	)
	_check(
		registry.package_validation_errors().is_empty(),
		"ready packages must admit cleanly: %s" % [registry.package_validation_errors()]
	)
	var ready_pairs := _discover_ready_pairs(registry)
	var inventory_errors := _inventory_errors(ready_pairs, LIFECYCLE_SPECS)
	for error in inventory_errors:
		_check(false, error)
	_assert_inventory_falsifications(ready_pairs)
	if not _errors.is_empty() or not inventory_errors.is_empty():
		_report()
		return
	var states: Array[Dictionary] = []
	for index in ready_pairs.size():
		var pair: Dictionary = ready_pairs[index]
		states.append(await _build_state(_spec_for_pair(pair), index, registry))
	await process_frame

	var original_time_scale := Engine.time_scale
	Engine.time_scale = GAMEPLAY_TIME_SCALE
	for state in states:
		_start_case(state)
	await _wait_for_natural_completion(states)
	Engine.time_scale = original_time_scale
	await process_frame
	_assert_natural_cleanup(states)
	await _assert_recast_and_cancel(states)

	for state in states:
		var player = state.get("player")
		if player != null and is_instance_valid(player):
			player.queue_free()
	_holder.queue_free()
	await process_frame
	_report()


func _discover_ready_pairs(registry) -> Array[Dictionary]:
	var pairs: Array[Dictionary] = []
	for raw_class_id in registry.class_ids():
		var class_id := str(raw_class_id)
		for raw_weapon_id in registry.weapon_ids(class_id):
			var weapon_id := str(raw_weapon_id)
			var label := _pair_key(class_id, weapon_id)
			var profile: Dictionary = registry.catalog_profile_for(class_id, weapon_id)
			if str(profile.get("implementation_state", "")) != "ready":
				continue
			if not registry.has_exact_executor_pair(class_id, weapon_id):
				_check(false, "%s ready pair must expose an exact executor" % label)
				continue
			if registry.resolution_source(class_id, weapon_id) != Resolver.SOURCE_WEAPON_PROFILE:
				_check(false, "%s ready pair must resolve through its exact package" % label)
				continue
			pairs.append({"class_id": class_id, "weapon_id": weapon_id})
	return pairs


func _inventory_errors(ready_pairs: Array, specs: Array) -> Array[String]:
	var errors: Array[String] = []
	var discovered: Dictionary = {}
	for raw_pair in ready_pairs:
		if not raw_pair is Dictionary:
			errors.append("ready inventory entry must be a pair identity")
			continue
		var pair := raw_pair as Dictionary
		var key := _pair_key(str(pair.get("class_id", "")), str(pair.get("weapon_id", "")))
		if key == "/":
			errors.append("ready inventory pair identity must name class_id/weapon_id")
			continue
		if discovered.has(key):
			errors.append("duplicate discovered ready pair: %s" % key)
			continue
		discovered[key] = true

	var documented: Dictionary = {}
	for raw_spec in specs:
		if not raw_spec is Dictionary:
			errors.append("lifecycle/deadline spec must be a pair identity")
			continue
		var spec := raw_spec as Dictionary
		var key := _pair_key(str(spec.get("class_id", "")), str(spec.get("weapon_id", "")))
		if key == "/":
			errors.append("lifecycle/deadline spec must name class_id/weapon_id")
			continue
		if documented.has(key):
			errors.append("duplicate lifecycle/deadline spec: %s" % key)
		else:
			documented[key] = true
		var lifecycle = spec.get("lifecycle")
		var deadline = spec.get("deadline")
		if not _positive_finite(lifecycle) or not _positive_finite(deadline):
			errors.append("%s lifecycle/deadline spec must be positive and finite" % key)
		elif not is_equal_approx(float(deadline), float(lifecycle) + COMPLETION_GRACE_SECONDS):
			errors.append("%s lifecycle/deadline spec must include %.1fs grace" % [key, COMPLETION_GRACE_SECONDS])

	for key in discovered:
		if not documented.has(key):
			errors.append("ready pair has no lifecycle/deadline spec: %s" % key)
	for key in documented:
		if not discovered.has(key):
			errors.append("stale lifecycle/deadline spec for missing ready pair: %s" % key)
	return errors


func _assert_inventory_falsifications(ready_pairs: Array) -> void:
	if ready_pairs.is_empty():
		return
	var original: Dictionary = ready_pairs[0]
	var original_key := _pair_key(str(original["class_id"]), str(original["weapon_id"]))
	var added_key := "%s/%s_added_ready_pair" % [str(original["class_id"]), str(original["weapon_id"])]
	var added := ready_pairs.duplicate(true)
	added.append({"class_id": str(original["class_id"]), "weapon_id": "%s_added_ready_pair" % str(original["weapon_id"])})
	_expect_inventory_failure(
		_inventory_errors(added, LIFECYCLE_SPECS),
		[added_key],
		"added ready pair"
	)

	var replaced := []
	for index in ready_pairs.size():
		if index != 0:
			replaced.append((ready_pairs[index] as Dictionary).duplicate(true))
	var replacement_key := "%s/%s_replaced_ready_pair" % [str(original["class_id"]), str(original["weapon_id"])]
	replaced.append({"class_id": str(original["class_id"]), "weapon_id": "%s_replaced_ready_pair" % str(original["weapon_id"])})
	var replacement_errors := _inventory_errors(replaced, LIFECYCLE_SPECS)
	_expect_inventory_failure(replacement_errors, [original_key, replacement_key], "replaced ready pair")

	var removed := []
	for index in ready_pairs.size():
		if index != 0:
			removed.append((ready_pairs[index] as Dictionary).duplicate(true))
	_expect_inventory_failure(
		_inventory_errors(removed, LIFECYCLE_SPECS),
		[original_key],
		"removed ready pair"
	)

	var duplicate_specs := LIFECYCLE_SPECS.duplicate(true)
	duplicate_specs.append((LIFECYCLE_SPECS[0] as Dictionary).duplicate(true))
	_expect_inventory_failure(
		_inventory_errors(ready_pairs, duplicate_specs),
		[_pair_key(str(LIFECYCLE_SPECS[0]["class_id"]), str(LIFECYCLE_SPECS[0]["weapon_id"]))],
		"duplicate lifecycle/deadline spec"
	)


func _expect_inventory_failure(errors: Array[String], required_keys: Array, scenario: String) -> void:
	_check(not errors.is_empty(), "%s must fail closed" % scenario)
	var joined := ""
	for error in errors:
		joined += str(error) + "\n"
	for raw_key in required_keys:
		_check(joined.contains(str(raw_key)), "%s failure must name %s" % [scenario, str(raw_key)])


func _spec_for_pair(pair: Dictionary) -> Dictionary:
	var key := _pair_key(str(pair.get("class_id", "")), str(pair.get("weapon_id", "")))
	for raw_spec in LIFECYCLE_SPECS:
		var spec := raw_spec as Dictionary
		if _pair_key(str(spec.get("class_id", "")), str(spec.get("weapon_id", ""))) == key:
			return spec.duplicate(true)
	return {}


func _pair_key(class_id: String, weapon_id: String) -> String:
	return "%s/%s" % [class_id, weapon_id]


func _positive_finite(value) -> bool:
	return (value is int or value is float) and not value is bool \
			and is_finite(float(value)) and float(value) > 0.0


func _build_state(spec: Dictionary, index: int, registry) -> Dictionary:
	var class_id := str(spec["class_id"])
	var weapon_id := str(spec["weapon_id"])
	var label := "%s/%s" % [class_id, weapon_id]
	_check(
		registry.resolution_source(class_id, weapon_id) == Resolver.SOURCE_WEAPON_PROFILE,
		"%s must remain an exact ready package" % label
	)
	var player := PlayerScene.instantiate() as Node2D
	_holder.add_child(player)
	await process_frame
	player.global_position = Vector2(float(index) * PLAYER_SPACING, 0.0)
	player.call("configure_character", class_id, weapon_id)
	await process_frame
	player.set_process(false)
	player.set_physics_process(false)
	_silence_equipped_weapon(player)
	_check(str(player.get("weapon_id")) == weapon_id, "%s must equip on the real Player" % label)

	var enemies := await _spawn_targets(player)
	var baseline_statuses := {}
	for enemy in enemies:
		baseline_statuses[enemy.get_instance_id()] = StatusEffects.snapshot(enemy)
	return {
		"class_id": class_id,
		"weapon_id": weapon_id,
		"label": label,
		"lifecycle": float(spec["lifecycle"]),
		"deadline": float(spec["deadline"]),
		"player": player,
		"enemies": enemies,
		"baseline_statuses": baseline_statuses,
		"baseline_modifiers": (player.get("run_modifiers") as Dictionary).duplicate(true),
		"started_ms": -1,
		"finished_ms": -1,
		"prechecked": false,
		"controller": null,
		"activation": null,
		"tweens": [],
		"spawned": [],
	}


func _silence_equipped_weapon(player: Node2D) -> void:
	# The matrix owns only the ultimate path. Child weapon nodes process
	# independently from Player and would otherwise add ordinary on-hit statuses.
	for child in player.find_children("*", "Node", true, false):
		(child as Node).process_mode = Node.PROCESS_MODE_DISABLED


func _spawn_targets(player: Node2D) -> Array[Node2D]:
	var source := player.global_position
	var aim: Vector2 = player.call("attack_aim_position", 760.0)
	var direction := (aim - source).normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	var perpendicular := Vector2(-direction.y, direction.x)
	var positions: Array[Vector2] = []
	for ratio in [0.2, 0.4, 0.6, 0.8]:
		positions.append(source.lerp(aim, float(ratio)))
	positions.append(aim)
	positions.append(aim + perpendicular * 70.0)
	positions.append(aim - perpendicular * 70.0)
	for angle in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
		positions.append(source + Vector2.RIGHT.rotated(float(angle)) * 210.0)
	var enemies: Array[Node2D] = []
	for position in positions:
		var enemy := EnemyScene.instantiate() as Node2D
		_holder.add_child(enemy)
		enemy.global_position = position
		enemy.set("max_health", 1000000.0)
		enemy.set("health", 1000000.0)
		enemy.set_process(false)
		enemy.set_physics_process(false)
		enemies.append(enemy)
	await process_frame
	return enemies


func _start_case(state: Dictionary) -> void:
	var player: Node2D = state["player"]
	var label := str(state["label"])
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	state["started_ms"] = Time.get_ticks_msec()
	_check(bool(player.call("activate_ultimate")), "%s must activate through real Player" % label)
	var controller = PlayerHost.for_player(player).controller()
	var activation = controller.active_activation()
	state["controller"] = controller
	state["activation"] = activation
	_check(controller.is_active(), "%s must be active immediately after admission" % label)
	_check(activation != null, "%s must expose its live activation" % label)
	if activation == null:
		return
	state["tweens"] = activation.tweens_for_tests()
	state["spawned"] = activation.spawned_for_tests()
	_check(
		(state["tweens"] as Array).size() == 1,
		"%s must own exactly one lifecycle tween" % label
	)
	_check(not (state["spawned"] as Array).is_empty(), "%s must own its live effect/deploy" % label)
	_check(is_zero_approx(float(player.get("ultimate_charge"))), "%s must spend charge once" % label)
	_check(bool(player.get("_ultimate_active")), "%s must set the Player active latch" % label)
	_check(not bool(player.call("activate_ultimate")), "%s must refuse live re-entry" % label)


func _wait_for_natural_completion(states: Array[Dictionary]) -> void:
	var global_deadline := 0
	for state in states:
		global_deadline = maxi(
			global_deadline,
			int(state["started_ms"]) + int(float(state["deadline"]) * 1000.0)
		)
	while Time.get_ticks_msec() <= global_deadline:
		var all_finished := true
		var now := Time.get_ticks_msec()
		for state in states:
			var controller = state.get("controller")
			if controller == null:
				continue
			var lifecycle := float(state["lifecycle"])
			var pre_margin := minf(0.35, lifecycle * 0.4)
			var pre_at := int(state["started_ms"]) + int((lifecycle - pre_margin) * 1000.0)
			if not bool(state["prechecked"]) and now >= pre_at:
				var activation = state.get("activation")
				_check(controller.is_active(), "%s must be active immediately before completion" % state["label"])
				_check(
					bool(state["player"].get("_ultimate_active")),
					"%s Player latch must remain active before completion" % state["label"]
				)
				_check(
					activation != null and not activation.is_finished(),
					"%s activation must remain live before completion" % state["label"]
				)
				state["prechecked"] = true
			if controller.is_active():
				all_finished = false
			elif int(state["finished_ms"]) < 0:
				state["finished_ms"] = now
		if all_finished:
			return
		await process_frame


func _assert_natural_cleanup(states: Array[Dictionary]) -> void:
	for state in states:
		var label := str(state["label"])
		var player: Node2D = state["player"]
		var controller = state.get("controller")
		var activation = state.get("activation")
		_check(bool(state["prechecked"]), "%s must reach its pre-completion checkpoint" % label)
		_check(controller != null and not controller.is_active(), "%s must finish naturally by lifecycle + 1s" % label)
		_check(not bool(player.get("_ultimate_active")), "%s must clear the Player active latch" % label)
		_check(activation != null and activation.is_finished(), "%s activation must finish" % label)
		if activation == null:
			continue
		if int(state["finished_ms"]) >= 0:
			var elapsed := float(int(state["finished_ms"]) - int(state["started_ms"])) / 1000.0
			_check(
				elapsed <= float(state["deadline"]),
				"%s finished after %.2fs, beyond lifecycle + 1s" % [label, elapsed]
			)
		_check(activation.applied_total > 0.0, "%s must execute a real gameplay damage step" % label)
		_check(activation.tweens_for_tests().is_empty(), "%s must drop tween ownership" % label)
		_check(activation.spawned_for_tests().is_empty(), "%s must drop spawn/deploy ownership" % label)
		_check(activation.presentation_for_tests().is_empty(), "%s must drop presentation handles" % label)
		_check(activation.summon_snapshot_count_for_tests() == 0, "%s must drop summon handles" % label)
		_check(activation.target_ledger_size_for_tests() == 0, "%s must clear target state" % label)
		for tween in state["tweens"]:
			_check(tween == null or not tween.is_valid(), "%s must invalidate its lifecycle tween" % label)
		for node in state["spawned"]:
			_check(not is_instance_valid(node), "%s must free each activation-owned node" % label)
		_check(
			_modifiers_restored(
				player.get("run_modifiers") as Dictionary,
				state["baseline_modifiers"] as Dictionary
			),
			"%s must restore transient modifiers" % label
		)
		for enemy in state["enemies"]:
			var actual_statuses := StatusEffects.snapshot(enemy)
			var baseline_statuses: Dictionary = state["baseline_statuses"].get(
				enemy.get_instance_id(), {}
			)
			_check(
				actual_statuses == baseline_statuses,
				"%s must remove activation-owned statuses, got %s" % [label, actual_statuses]
			)


func _assert_recast_and_cancel(states: Array[Dictionary]) -> void:
	for state in states:
		var player: Node2D = state["player"]
		var controller = state.get("controller")
		if controller == null or controller.is_active():
			if controller != null:
				controller.cancel()
			continue
		player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
		_check(bool(player.call("activate_ultimate")), "%s must be recastable after completion" % state["label"])
		controller.cancel()
		_check(not controller.is_active(), "%s recast cancel must finish synchronously" % state["label"])
	await process_frame


func _modifiers_restored(actual: Dictionary, baseline: Dictionary) -> bool:
	for key in baseline:
		var before = baseline[key]
		var after = actual.get(key)
		if before is float or before is int:
			if not (after is float or after is int) or not is_equal_approx(float(after), float(before)):
				return false
		elif after != before:
			return false
	for key in actual:
		if baseline.has(key):
			continue
		var value = actual[key]
		if not (value is float or value is int) or not is_zero_approx(float(value)):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("tracked_tween_natural_completion_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("tracked_tween_natural_completion_test: %s" % error)
	print("tracked_tween_natural_completion_test: FAIL (%d)" % _errors.size())
	quit(1)
