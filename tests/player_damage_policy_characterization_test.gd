extends SceneTree

# FAN-3920 (FD13): characterization of the Player incoming-damage pipeline
# before/after extracting scripts/player/player_damage_policy.gd. Every check
# pins EXISTING behavior of Player.take_damage: prevention channels and their
# order, the dodge roll channel, Knight block/counter, constellation single-hit
# ward, mitigation math and caps, class multipliers, lethal/nonlethal outcomes,
# owner-event payloads/order, and reconfiguration resets.
#
# Run: python3 tools/godot_gate.py --headless --path . \
#     --script res://tests/player_damage_policy_characterization_test.gd

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const DefensiveAttributeRuntime := preload("res://scripts/defensive_attribute_runtime.gd")

const EPS := 0.0001

# Records owner events dispatched by Player._dispatch_constellation_owner_event.
class EventProbe:
	extends Node
	var events: Array = []

	func constellation_owner_event(event: String, context := {}, enemy: Node2D = null) -> Dictionary:
		events.append({"event": event, "context": context.duplicate(true)})
		return {}


func _initialize() -> void:
	seed(20260905)
	var errors: Array = []
	var holder := Node2D.new()
	root.add_child(holder)
	await process_frame

	var player := await _make_player(holder, errors, "berserk")
	var probe := EventProbe.new()
	holder.add_child(probe)

	if not errors.is_empty():
		_finish(errors)
		return

	# --- Channel 1: prevention gates return false and change nothing ---
	_force_clean_mitigation(player)
	_set_health(player, 1000.0, 1000.0)
	player.set("_warmup_no_hit_seconds", 3.0)

	player.set("debug_godmode", true)
	if player.take_damage(40.0) != false or _health(player) != 1000.0:
		errors.append("godmode: expected prevented hit (false) with full health")
	if absf(float(player.get("_warmup_no_hit_seconds")) - 3.0) > EPS:
		errors.append("godmode: fully prevented hit must not reset warmup")
	player.set("debug_godmode", false)

	player.set("_damage_invulnerability_left", 1.0)
	if player.take_damage(40.0) != false or _health(player) != 1000.0:
		errors.append("i-frames: expected prevented hit (false) with full health")
	player.set("_damage_invulnerability_left", 0.0)

	player.set("_shadow_invisible_left", 1.0)
	if player.take_damage(40.0) != false or _health(player) != 1000.0:
		errors.append("invisibility: expected prevented hit (false) with full health")
	player.set("_shadow_invisible_left", 0.0)

	# Prevention order: earlier gates beat the Knight ultimate channel.
	player.set("debug_godmode", true)
	player.set("_ultimate_active", true)
	if player.take_damage(40.0) != false:
		errors.append("ordering: godmode must win over the Knight ultimate gate")
	player.set("debug_godmode", false)
	player.set("_damage_invulnerability_left", 1.0)
	if player.take_damage(40.0) != false:
		errors.append("ordering: i-frames must win over the Knight ultimate gate")
	player.set("_damage_invulnerability_left", 0.0)

	# --- Channel 2: Knight ultimate gate returns true, no damage, before dodge ---
	var knight := await _make_player(holder, errors, "knight")
	if knight != null:
		_force_clean_mitigation(knight)
		_set_health(knight, 1000.0, 1000.0)
		knight.set("_warmup_no_hit_seconds", 3.0)
		knight.set("_ultimate_active", true)
		var ult_landed: bool = knight.take_damage(40.0)
		if ult_landed != true or _health(knight) != 1000.0:
			errors.append("knight ultimate: expected return true with full health")
		if absf(float(knight.get("_warmup_no_hit_seconds")) - 3.0) > EPS:
			errors.append("knight ultimate: gate hit must not reset warmup")
		knight.set("_ultimate_active", false)
		holder.remove_child(knight)
		knight.queue_free()

	# --- Channel 3: dodge roll (false, no damage, no i-frames, owner event) ---
	player.set("equipped_weapon", probe)
	probe.events.clear()
	var dp_dodge: Dictionary = player.get("derived_parameters").duplicate()
	dp_dodge["raw_dodge"] = 1000000.0
	dp_dodge["dodge"] = 0.0
	player.set("derived_parameters", dp_dodge)
	var dodge_chance := float(player.call("current_dodge_chance"))
	if dodge_chance <= 0.25 or dodge_chance > 0.55 + EPS:
		errors.append("dodge: unexpected dodge chance %.4f (expected near the 0.55 asymptote)" % dodge_chance)
	var saw_dodge := false
	var saw_landed := false
	for _i in range(400):
		player.set("_damage_invulnerability_left", 0.0)
		player.set("_warmup_no_hit_seconds", 3.0)
		var before := _health(player)
		var landed: bool = player.take_damage(40.0, "probe", null)
		if not landed and _health(player) == before:
			saw_dodge = true
			if absf(float(player.get("_damage_invulnerability_left"))) > EPS:
				errors.append("dodge: dodge must not grant invulnerability frames")
			if absf(float(player.get("_warmup_no_hit_seconds")) - 3.0) > EPS:
				errors.append("dodge: dodged hit must not reset warmup")
			var dodge_events := probe.events.filter(func(e): return e["event"] == "dodge")
			if dodge_events.is_empty():
				errors.append("dodge: owner event 'dodge' was not dispatched")
			else:
				var ctx: Dictionary = dodge_events[0]["context"]
				for key in ["incoming_amount", "smoke_zone", "smoke_cloud_id", "smoke_center"]:
					if not ctx.has(key):
						errors.append("dodge: owner event payload missing '%s'" % key)
				if absf(float(ctx.get("incoming_amount", -1.0)) - 40.0) > EPS:
					errors.append("dodge: owner event incoming_amount != hit amount")
			probe.events.clear()
		elif landed and _health(player) < before:
			saw_landed = true
			if absf(float(player.get("_warmup_no_hit_seconds"))) > EPS:
				errors.append("qualified hit must reset warmup no-hit stack to 0")
			probe.events.clear()
		if saw_dodge and saw_landed:
			break
	if not saw_dodge:
		errors.append("dodge: no dodged outcome in 400 seeded attempts — check vacuous")
	if not saw_landed:
		errors.append("dodge: no landed outcome in 400 seeded attempts — check vacuous")
	player.set("equipped_weapon", null)

	# --- Mitigation anchors (defense 0, absorb 0, no traits) ---
	_force_clean_mitigation(player)
	_set_health(player, 1000.0, 1000.0)
	var damaged_log: Array = []
	player.connect("damaged", func(amount: float) -> void: damaged_log.append(amount))
	player.set("_damage_invulnerability_left", 0.0)
	if player.take_damage(40.0) != true:
		errors.append("clean hit: expected return true")
	if absf(1000.0 - _health(player) - 40.0) > 0.05:
		errors.append("clean hit: expected exactly 40.0 damage with zero defense/absorb, got %.3f" % (1000.0 - _health(player)))
	if damaged_log.size() != 1 or absf(float(damaged_log[0]) - 40.0) > 0.05:
		errors.append("clean hit: damaged signal payload must be the final damage")
	if absf(float(player.get("_damage_invulnerability_left")) - float(player.get("damage_invulnerability_time"))) > EPS:
		errors.append("clean hit: qualified hit must set damage_invulnerability_time i-frames")

	# Flat absorb and the guaranteed min-damage fraction.
	_override_derived(player, {"absorb": 5.0})
	player.set("_damage_invulnerability_left", 0.0)
	_set_health(player, 1000.0, 1000.0)
	player.take_damage(40.0)
	if absf(1000.0 - _health(player) - 35.0) > 0.05:
		errors.append("absorb: expected 35.0 (40-5) damage, got %.3f" % (1000.0 - _health(player)))
	_override_derived(player, {"absorb": 100.0})
	player.set("_damage_invulnerability_left", 0.0)
	_set_health(player, 1000.0, 1000.0)
	player.take_damage(10.0)
	if absf(1000.0 - _health(player) - 10.0 * 0.42) > 0.05:
		errors.append("absorb min fraction: expected 4.2 damage from 10.0 hit, got %.3f" % (1000.0 - _health(player)))

	# Defense curve + hard cap.
	_override_derived(player, {"absorb": 0.0, "raw_defense": 30.0})
	player.set("_damage_invulnerability_left", 0.0)
	_set_health(player, 1000.0, 1000.0)
	player.take_damage(40.0)
	var expected_defense := DefensiveAttributeRuntime.effective_defense(30.0)
	if absf(1000.0 - _health(player) - 40.0 * (1.0 - expected_defense)) > 0.05:
		errors.append("defense: expected %.3f damage, got %.3f" % [40.0 * (1.0 - expected_defense), 1000.0 - _health(player)])
	_override_derived(player, {"raw_defense": 1000000.0})
	player.set("_damage_invulnerability_left", 0.0)
	_set_health(player, 1000.0, 1000.0)
	player.take_damage(40.0)
	var capped_defense := DefensiveAttributeRuntime.effective_defense(1000000.0)
	if capped_defense > 0.62 + EPS or 1000.0 - _health(player) < 40.0 * (1.0 - 0.62) - 0.05:
		errors.append("defense cap: mitigation escaped the 0.62 cap (effective %.4f, damage %.3f)" % [capped_defense, 1000.0 - _health(player)])

	# Stance defense bonus joins the raw rating before the curve.
	_override_derived(player, {"raw_defense": 0.0, "defense": 0.0})
	var stance_mods: Dictionary = player.get("run_modifiers").duplicate()
	stance_mods["bastion_defense_bonus"] = 50.0
	player.set("run_modifiers", stance_mods)
	player.set("_stance_active", true)
	player.set("_damage_invulnerability_left", 0.0)
	_set_health(player, 1000.0, 1000.0)
	player.take_damage(40.0)
	var stance_defense := DefensiveAttributeRuntime.effective_defense(50.0)
	if absf(1000.0 - _health(player) - 40.0 * (1.0 - stance_defense)) > 0.05:
		errors.append("stance defense: expected %.3f damage, got %.3f" % [40.0 * (1.0 - stance_defense), 1000.0 - _health(player)])
	player.set("_stance_active", false)

	# Battle prayer final multiplier.
	player.set("_battle_prayer_protection", 0.25)
	player.set("_damage_invulnerability_left", 0.0)
	_set_health(player, 1000.0, 1000.0)
	player.take_damage(40.0)
	if absf(1000.0 - _health(player) - 30.0) > 0.05:
		errors.append("battle prayer: expected 30.0 damage (0.75x), got %.3f" % (1000.0 - _health(player)))
	player.set("_battle_prayer_protection", 0.0)

	# Reactor heat incoming amplifier.
	player.set("_reactor_heat_active", true)
	var heat_mods: Dictionary = player.get("run_modifiers").duplicate()
	heat_mods["reactor_heat_incoming_damage"] = 0.5
	player.set("run_modifiers", heat_mods)
	player.set("_damage_invulnerability_left", 0.0)
	_set_health(player, 1000.0, 1000.0)
	player.take_damage(40.0)
	if absf(1000.0 - _health(player) - 60.0) > 0.05:
		errors.append("reactor heat: expected 60.0 damage (1.5x), got %.3f" % (1000.0 - _health(player)))
	player.set("_reactor_heat_active", false)

	# Contact attacker reaches the qualified-hit path without side effects for
	# a class without retaliation traits.
	var attacker := Node2D.new()
	holder.add_child(attacker)
	attacker.global_position = Vector2(40.0, 0.0)
	player.set("_damage_invulnerability_left", 0.0)
	_set_health(player, 1000.0, 1000.0)
	player.take_damage(40.0, "contact", attacker)
	if absf(1000.0 - _health(player) - 40.0) > 0.05:
		errors.append("attacker channel: expected 40.0 damage with a contact attacker, got %.3f" % (1000.0 - _health(player)))

	# --- Knight block/counter (weapon passive) ---
	var knight2 := await _make_player(holder, errors, "knight")
	if knight2 != null:
		_force_clean_mitigation(knight2)
		_set_health(knight2, 1000.0, 1000.0)
		knight2.set("equipped_weapon", probe)
		probe.events.clear()
		var knight_config: Dictionary = knight2.get("weapon_config").duplicate()
		knight_config["passive_mods"] = {"block_reduction": 0.5, "counter_cooldown": 2.4}
		knight2.set("weapon_config", knight_config)
		knight2.set("_damage_invulnerability_left", 0.0)
		knight2.take_damage(40.0)
		if absf(1000.0 - _health(knight2) - 20.0) > 0.05:
			errors.append("knight block: expected 20.0 damage after 50% block, got %.3f" % (1000.0 - _health(knight2)))
		var block_events := probe.events.filter(func(e): return e["event"] == "block")
		if block_events.size() != 1:
			errors.append("knight block: expected exactly one 'block' owner event, got %d" % block_events.size())
		else:
			var block_ctx: Dictionary = block_events[0]["context"]
			if absf(float(block_ctx.get("incoming_amount", -1.0)) - 40.0) > EPS or absf(float(block_ctx.get("blocked_amount", -1.0)) - 20.0) > EPS:
				errors.append("knight block: block event payload mismatch %s" % str(block_ctx))
		if float(knight2.get("_knight_counter_cooldown_left")) <= 0.0:
			errors.append("knight block: counter cooldown was not armed")
		# Second hit inside the cooldown: no second block.
		probe.events.clear()
		knight2.set("_damage_invulnerability_left", 0.0)
		_set_health(knight2, 1000.0, 1000.0)
		knight2.take_damage(40.0)
		if absf(1000.0 - _health(knight2) - 40.0) > 0.05:
			errors.append("knight block: cooldown hit must take full 40.0 damage, got %.3f" % (1000.0 - _health(knight2)))
		if not probe.events.filter(func(e): return e["event"] == "block").is_empty():
			errors.append("knight block: 'block' event fired during counter cooldown")
		knight2.set("equipped_weapon", null)

		# --- Constellation single-hit ward (owned absorb + consumption) ---
		knight2.set("_knight_counter_cooldown_left", 0.0)
		var plain_config: Dictionary = knight2.get("weapon_config").duplicate()
		plain_config.erase("passive_mods")
		knight2.set("weapon_config", plain_config)
		knight2.set("equipped_weapon", probe)
		probe.events.clear()
		var normalized_ratio: float = knight2.call("constellation_set_single_hit_ward", "probe_ward", 1.0, 10.0)
		if absf(normalized_ratio - 0.80) > EPS:
			errors.append("ward: set ratio must clamp to 0.80, got %.3f" % normalized_ratio)
		knight2.set("_damage_invulnerability_left", 0.0)
		_set_health(knight2, 1000.0, 1000.0)
		knight2.take_damage(40.0)
		if absf(1000.0 - _health(knight2) - 8.0) > 0.05:
			errors.append("ward: expected 8.0 damage after 0.80 ward absorb, got %.3f" % (1000.0 - _health(knight2)))
		var ward_events := probe.events.filter(func(e): return e["event"] == "damage_absorbed")
		if ward_events.size() != 1:
			errors.append("ward: expected exactly one 'damage_absorbed' event, got %d" % ward_events.size())
		else:
			var ward_ctx: Dictionary = ward_events[0]["context"]
			if absf(float(ward_ctx.get("absorbed_amount", -1.0)) - 32.0) > EPS \
					or absf(float(ward_ctx.get("incoming_amount", -1.0)) - 40.0) > EPS \
					or str(ward_ctx.get("constellation_ward_source", "")) != "probe_ward":
				errors.append("ward: damage_absorbed payload mismatch %s" % str(ward_ctx))
		if not knight2.call("constellation_consume_single_hit_ward").is_empty():
			errors.append("ward: ward must be consumed by the qualified hit")
		knight2.set("equipped_weapon", null)
		holder.remove_child(knight2)
		knight2.queue_free()

	# --- Lethal / nonlethal outcomes and death save ---
	_force_clean_mitigation(player)
	_set_health(player, 1000.0, 1000.0)
	player.set("_damage_invulnerability_left", 0.0)
	player.take_damage(40.0)
	if player.is_queued_for_deletion():
		errors.append("nonlethal: player must not be freed by a nonlethal hit")

	var died_count: Array = []
	player.connect("died", func() -> void: died_count.append(1))
	_set_health(player, 10.0, 1000.0)
	player.set("_damage_invulnerability_left", 0.0)
	player.take_damage(40.0)
	if died_count.size() != 1:
		errors.append("lethal: died signal must fire exactly once, got %d" % died_count.size())
	if not player.is_queued_for_deletion():
		errors.append("lethal: lethal hit must queue_free the player")

	# Death save: run-persistent revive with >=2s invulnerability, no death.
	var saver := await _make_player(holder, errors, "berserk")
	if saver != null:
		_force_clean_mitigation(saver)
		var save_mods: Dictionary = saver.get("run_modifiers").duplicate()
		save_mods["death_save"] = 1.0
		save_mods["death_save_health_fraction"] = 0.25
		saver.set("run_modifiers", save_mods)
		var saver_died: Array = []
		saver.connect("died", func() -> void: saver_died.append(1))
		saver.set("_damage_invulnerability_left", 0.0)
		_set_health(saver, 10.0, 400.0)
		saver.take_damage(40.0)
		if not saver_died.is_empty() or saver.is_queued_for_deletion():
			errors.append("death save: lethal hit must be saved without died/free")
		if absf(_health(saver) - 100.0) > 0.05:
			errors.append("death save: expected 100.0 health (25% of 400), got %.3f" % _health(saver))
		if float(saver.get("_damage_invulnerability_left")) < 2.0:
			errors.append("death save: expected >=2s invulnerability after the save")
		# The save is run-persistent: the next lethal hit kills.
		saver.set("_damage_invulnerability_left", 0.0)
		_set_health(saver, 10.0, 400.0)
		saver.take_damage(40.0)
		if saver_died.size() != 1 or not saver.is_queued_for_deletion():
			errors.append("death save: second lethal hit must kill (save already used)")
		holder.remove_child(saver)
		saver.queue_free()

	# --- Robot incoming multiplier (class trait, last multiplier) ---
	var robot := await _make_player(holder, errors, "robot")
	if robot != null:
		_force_clean_mitigation(robot)
		_set_health(robot, 1000.0, 1000.0)
		robot.set("_damage_invulnerability_left", 0.0)
		robot.take_damage(40.0)
		if absf(1000.0 - _health(robot) - 32.0) > 0.05:
			errors.append("robot trait: expected 32.0 damage (0.8x), got %.3f" % (1000.0 - _health(robot)))
		holder.remove_child(robot)
		robot.queue_free()

	# --- Reconfiguration resets damage-policy state ---
	var reconf := await _make_player(holder, errors, "knight")
	if reconf != null:
		_force_clean_mitigation(reconf)
		reconf.call("constellation_set_single_hit_ward", "stale_ward", 0.5, 30.0)
		reconf.set("_knight_counter_cooldown_left", 1.5)
		reconf.set("_warmup_no_hit_seconds", 3.0)
		var stale_mods: Dictionary = reconf.get("run_modifiers").duplicate()
		stale_mods["death_save"] = 1.0
		reconf.set("run_modifiers", stale_mods)
		reconf.call("configure_character", "berserk", "")
		await process_frame
		if not reconf.call("constellation_consume_single_hit_ward").is_empty():
			errors.append("reconfigure: single-hit ward must not survive reconfiguration")
		if absf(float(reconf.get("_knight_counter_cooldown_left"))) > EPS:
			errors.append("reconfigure: knight counter cooldown must reset")
		if absf(float(reconf.get("_warmup_no_hit_seconds"))) > EPS:
			errors.append("reconfigure: warmup stack must reset")
		if float(reconf.get("run_modifiers").get("death_save", 0.0)) != 0.0:
			errors.append("reconfigure: run modifiers must reset (death_save survived)")
		holder.remove_child(reconf)
		reconf.queue_free()

	holder.queue_free()
	await process_frame
	_finish(errors)


func _make_player(holder: Node2D, errors: Array, character_id: String) -> Node:
	var player := PLAYER_SCENE.instantiate() as Node2D
	holder.add_child(player)
	player.add_to_group("player")
	if not player.has_method("configure_character") or not player.has_method("take_damage"):
		errors.append("Player lacks configure_character/take_damage")
		return null
	player.call("configure_character", character_id, "")
	await process_frame
	return player


func _force_clean_mitigation(player: Node) -> void:
	_override_derived(player, {
		"raw_defense": 0.0, "defense": 0.0,
		"raw_dodge": 0.0, "dodge": 0.0,
		"absorb": 0.0, "support_multiplier": 0.0,
	})
	player.set("_damage_invulnerability_left", 0.0)
	player.set("_shadow_invisible_left", 0.0)
	player.set("_reactor_heat_active", false)
	player.set("_battle_prayer_protection", 0.0)
	player.set("_ultimate_active", false)
	player.set("debug_godmode", false)
	player.set("_stance_active", false)
	var plain_config: Dictionary = player.get("weapon_config").duplicate()
	plain_config.erase("passive_mods")
	player.set("weapon_config", plain_config)


func _override_derived(player: Node, overrides: Dictionary) -> void:
	var dp: Dictionary = player.get("derived_parameters").duplicate()
	for key in overrides:
		dp[key] = overrides[key]
	player.set("derived_parameters", dp)


func _set_health(player: Node, health: float, max_health: float) -> void:
	player.set("max_health", max_health)
	player.set("health", health)


func _health(player: Node) -> float:
	return float(player.get("health"))


func _finish(errors: Array) -> void:
	if not errors.is_empty():
		for e in errors:
			push_error("Player damage characterization: %s" % e)
		push_error("Player damage characterization test: %d errors." % errors.size())
		quit(1)
		return
	print("Player damage characterization test passed.")
	quit(0)
