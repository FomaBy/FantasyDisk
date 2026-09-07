extends SceneTree

# FAN-3922 (FD15): characterization of Player's constellation/class-effect
# façade before and after extraction into player_class_effects.gd.
# Run: python3 tools/godot_gate.py --headless --path . \
#     --script res://tests/player_class_effects_characterization_test.gd

const Meta := preload("res://scripts/meta_progression.gd")
const PlayerScript := preload("res://scripts/player.gd")

const EPS := 0.0001


class FinalEventCollector:
	extends Node
	var records: Array = []

	func record(weapon_id: String, event: String, target: Node2D, context: Dictionary, resolution: Dictionary) -> void:
		records.append({
			"weapon_id": weapon_id,
			"event": event,
			"target": target,
			"context": context,
			"resolution": resolution,
		})


func _initialize() -> void:
	var errors: Array = []
	await process_frame
	_check_final_event_payloads(errors)
	_check_freed_equipped_weapon_falls_back(errors)
	await _check_timed_effect_cancellation_and_reconfigure(errors)
	await _check_death_cancels_owned_expiry(errors)
	_finish(errors)


func _check_final_event_payloads(errors: Array) -> void:
	var player = _make_player("berserk")
	var state := Meta.default_state()
	state["skill_nodes"] = ["berserk_sword_final"]
	player.apply_constellation_weapon_profiles(Meta.skill_profiles_for_class(state, "berserk"))

	var collector := FinalEventCollector.new()
	root.add_child(collector)
	player.constellation_final_resolved.connect(collector.record)
	var enemy := Node2D.new()
	root.add_child(enemy)
	var input_context := {
		"constellation_consumer_event": true,
		"damage": 12.5,
		"nested": {"probe": 7},
	}
	var last_result: Dictionary = {}
	for hit_index in range(3):
		last_result = player.constellation_weapon_event("sword", "hit", input_context, enemy)
		var expected_triggered := hit_index == 2
		if bool(last_result.get("triggered", false)) != expected_triggered:
			errors.append("final event: hit %d triggered=%s" % [hit_index + 1, str(last_result.get("triggered"))])

	var expected_context := input_context.duplicate(true)
	expected_context["target_id"] = str(enemy.get_instance_id())
	var expected_resolution := {
		"valid": true,
		"mechanic_id": "sword_repeat_execute",
		"mode": "repeat_execute",
		"event": "hit",
		"expected_event": "hit",
		"triggered": true,
		"progress": 3,
		"required": 3,
		"params": {"required_hits": 3.0, "execute_threshold": 0.35, "boss_bonus_cap": 0.24},
		"damage_multiplier": 1.0,
		"axis_gain": 1.2,
		"side_effect": {"kind": "repeat_execute"},
		"telemetry_final_activation_id": "final_000001",
	}
	if last_result != expected_resolution:
		errors.append("final event: exact triggered resolution changed: %s" % str(last_result))
	if collector.records.size() != 3:
		errors.append("final event: expected one signal per routed hit, got %d" % collector.records.size())
	else:
		var final_record: Dictionary = collector.records[2]
		if final_record["weapon_id"] != "sword" or final_record["event"] != "hit" or final_record["target"] != enemy:
			errors.append("final event: signal identity/target payload changed")
		if final_record["context"] != expected_context:
			errors.append("final event: signal context changed: %s" % str(final_record["context"]))
		if final_record["resolution"] != expected_resolution:
			errors.append("final event: signal resolution differs from the public return")
	if input_context.has("target_id"):
		errors.append("final event: caller context was mutated")
	last_result["progress"] = 99
	(input_context["nested"] as Dictionary)["probe"] = 99
	if collector.records.size() == 3:
		if int((collector.records[2]["resolution"] as Dictionary).get("progress", -1)) != 3:
			errors.append("final event: returned resolution aliases the emitted payload")
		if int(((collector.records[2]["context"] as Dictionary).get("nested", {}) as Dictionary).get("probe", -1)) != 7:
			errors.append("final event: caller context aliases the emitted payload")

	player.free()
	enemy.free()
	collector.free()


func _check_freed_equipped_weapon_falls_back(errors: Array) -> void:
	var player = _make_player("berserk")
	var stale_weapon := Node.new()
	player.add_child(stale_weapon)
	player.equipped_weapon = stale_weapon
	stale_weapon.free()

	var result: Dictionary = player.call("_dispatch_constellation_owner_event", "take_damage", {
		"constellation_consumer_event": true,
	})
	var expected := {
		"valid": true,
		"triggered": false,
		"damage_multiplier": 1.0,
		"axis_gain": 1.0,
	}
	if result != expected:
		errors.append("owner event: a freed equipped weapon did not use the Player fallback: %s" % str(result))

	player.equipped_weapon = null
	player.free()


func _check_timed_effect_cancellation_and_reconfigure(errors: Array) -> void:
	var player = _make_player("druid")
	player.set("_status_aura_cooldown_left", 0.0)
	player.call("_update_class_status_auras")
	if player.get_node_or_null(PlayerScript.WILD_AURA_RING_NAME) == null:
		errors.append("reconfigure: Druid setup did not create the aura ring")

	var base_absorb := float((player.get("run_modifiers") as Dictionary).get("absorb_flat", 0.0))
	var base_dodge := float((player.get("run_modifiers") as Dictionary).get("dodge_flat", 0.0))
	player.constellation_set_timed_absorb("cancelled", 3.0, 0.06)
	player.constellation_remove_timed_absorb("cancelled")
	player.constellation_set_timed_absorb("cancelled", 5.0, 0.20)
	player.constellation_set_timed_dodge("cancelled", 0.10, 0.06)
	player.constellation_remove_timed_dodge("cancelled")
	player.constellation_set_timed_dodge("cancelled", 0.15, 0.20)
	await create_timer(0.08).timeout
	if absf(player.constellation_timed_absorb("cancelled") - 5.0) > EPS:
		errors.append("cancellation: stale absorb expiry removed the replacement")
	if absf(float((player.get("run_modifiers") as Dictionary).get("dodge_flat", 0.0)) - (base_dodge + 0.15)) > EPS:
		errors.append("cancellation: stale dodge expiry removed the replacement")

	player.constellation_set_single_hit_ward("ward", 0.5, 1.0)
	player.configure_character("berserk")
	await process_frame
	if not (player.get("_constellation_final_state") as Dictionary).is_empty() \
			or not (player.get("_constellation_absorb_sources") as Dictionary).is_empty() \
			or not (player.get("_constellation_dodge_sources") as Dictionary).is_empty() \
			or not (player.get("_constellation_single_hit_ward") as Dictionary).is_empty():
		errors.append("reconfigure: constellation transient state survived the class reset")
	if player.get_node_or_null(PlayerScript.WILD_AURA_RING_NAME) != null:
		errors.append("reconfigure: the old Druid aura ring survived on Berserk")
	if absf(float(player.get("_status_aura_cooldown_left"))) > EPS:
		errors.append("reconfigure: aura cadence was not reset")
	if absf(float((player.get("run_modifiers") as Dictionary).get("absorb_flat", 0.0)) - base_absorb) > EPS \
			or absf(float((player.get("run_modifiers") as Dictionary).get("dodge_flat", 0.0)) - base_dodge) > EPS:
		errors.append("reconfigure: timed modifiers survived the fresh run state")

	player.constellation_set_timed_absorb("cancelled", 7.0, 0.20)
	player.constellation_set_timed_dodge("cancelled", 0.12, 0.20)
	await create_timer(0.13).timeout
	if absf(player.constellation_timed_absorb("cancelled") - 7.0) > EPS:
		errors.append("reconfigure: a pre-reset callback removed post-reset absorb")
	if absf(float((player.get("run_modifiers") as Dictionary).get("dodge_flat", 0.0)) - (base_dodge + 0.12)) > EPS:
		errors.append("reconfigure: a pre-reset callback removed post-reset dodge")

	player.free()


func _check_death_cancels_owned_expiry(errors: Array) -> void:
	var player = _make_player("berserk")
	player.constellation_set_timed_absorb("death", 4.0, 0.06)
	player.health = 1.0
	player.derived_parameters["raw_defense"] = 0.0
	player.derived_parameters["defense"] = 0.0
	player.derived_parameters["raw_dodge"] = 0.0
	player.derived_parameters["dodge"] = 0.0
	player.set("_damage_invulnerability_left", 0.0)
	player.take_damage(100000.0)
	await process_frame
	if is_instance_valid(player):
		errors.append("death: lethal damage did not release the Player and its owned expiry tween")
	await create_timer(0.08).timeout


func _make_player(character_id: String):
	var player = PlayerScript.new()
	player.set_physics_process(false)
	root.add_child(player)
	player.configure_character(character_id)
	return player


func _finish(errors: Array) -> void:
	if errors.is_empty():
		print("FAN-3922 class effects preserved cancellation, death, reconfiguration, and exact final-event payloads.")
		quit(0)
		return
	for error in errors:
		push_error(error)
	quit(1)
