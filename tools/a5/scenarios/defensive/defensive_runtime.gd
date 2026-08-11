extends RefCounted

# Runtime counterpart of defensive_family_pack.gd. It deliberately uses tiny
# live Player fixtures rather than the balance formula, so every observation is
# tied to Player.take_damage or the pickup/movement runtime path.

const Pack := preload("res://tools/a5/scenarios/defensive/defensive_family_pack.gd")
const Meta := preload("res://scripts/meta_progression.gd")
const PlayerScript := preload("res://scripts/player.gd")
const BerserkWeapon := preload("res://scripts/berserk_weapon.gd")
const ClassWeapon := preload("res://scripts/class_weapon.gd")
const CombatDirector := preload("res://scripts/combat_director.gd")
const PickupScript := preload("res://scripts/pickup.gd")
const ProgressionData := preload("res://scripts/progression_data.gd")
const TargetQuery := preload("res://scripts/combat_target_query.gd")

const INCOMING_AMOUNT := 40.0
const INCOMING_SOURCE := "fan1514:canonical_incoming"


class DummyEnemy extends Node2D:
	var health := 10000.0
	var max_health := 10000.0
	var feedbacks: Array = []
	var damage_events: Array = []
	func take_damage(amount: float, feedback := {}) -> void:
		var received := maxf(amount, 0.0)
		var copied_feedback := (feedback as Dictionary).duplicate(true) if feedback is Dictionary else {}
		health -= received
		feedbacks.append(copied_feedback)
		damage_events.append({"amount": received, "feedback": copied_feedback})
	func _show_combat_feedback(_amount: float, _feedback := {}) -> void:
		pass
	func apply_knockback(_impulse: Vector2) -> void:
		pass


class ProbeGame extends Node:
	var current_player: Node2D
	func _play_sfx(_name: String) -> void:
		pass


static func run(root: Node) -> Dictionary:
	var reactive := {}
	for entry_value in Pack.REACTIVE_MATRIX:
		var entry: Dictionary = entry_value
		reactive[str(entry["id"])] = _measure_reactive(root, entry)
	return {
		"fragment_schema": Pack.FRAGMENT_SCHEMA,
		"pack_id": Pack.PACK_ID,
		"pack_contract": Pack.PACK_CONTRACT,
		"contract": Pack.contract(),
		"reactive": reactive,
		"survivability": _measure_survivability(root),
		"quality": _measure_quality(root),
		"limitations": [
			"A/B is scoped to the named final; ordinary incoming damage has no public source signal outside guard-prevention telemetry.",
			"A missing runtime event remains red through defensive_family_pack.gd rather than being inferred from a formula.",
		],
	}


static func _measure_reactive(root: Node, entry: Dictionary) -> Dictionary:
	var enabled := _empty_arm()
	var disabled := _empty_arm()
	var samples := []
	for seed_value in Pack.SEEDS:
		seed(int(seed_value))
		var enabled_sample := _run_reactive_arm(root, entry, true)
		seed(int(seed_value))
		var disabled_sample := _run_reactive_arm(root, entry, false)
		_accumulate_arm(enabled, enabled_sample)
		_accumulate_arm(disabled, disabled_sample)
		samples.append(int(enabled_sample.get("expected_events", 0)))
	return {
		"enabled": enabled,
		"disabled": disabled,
		"event_samples": samples,
		"variance": Pack.coefficient_of_variation(samples),
		"limitations": ["fixed seeds %s" % str(Pack.SEEDS)],
	}


static func _empty_arm() -> Dictionary:
	return {"incoming_hits": 0, "expected_events": 0, "final_damage": 0.0, "sources": []}


static func _accumulate_arm(total: Dictionary, sample: Dictionary) -> void:
	for key in ["incoming_hits", "expected_events"]:
		total[key] = int(total.get(key, 0)) + int(sample.get(key, 0))
	total["final_damage"] = float(total.get("final_damage", 0.0)) + float(sample.get("final_damage", 0.0))
	for source in sample.get("sources", []):
		if not (total["sources"] as Array).has(source):
			(total["sources"] as Array).append(source)


static func _run_reactive_arm(root: Node, entry: Dictionary, final_enabled: bool) -> Dictionary:
	var id := str(entry["id"])
	match id:
		"dodge":
			return _run_dodge(root, final_enabled)
		"block":
			return _run_knight(root, "long_spear", final_enabled)
		"absorb":
			return _run_knight(root, "tower_shield", final_enabled)
		"retaliation":
			return _run_censer(root, final_enabled)
	return _empty_arm()


static func _new_player(root: Node, class_id: String, weapon_id: String, final_enabled: bool, weapon) -> Node2D:
	var player = PlayerScript.new() as Node2D
	root.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.call("configure_character", class_id)
	player.set("weapon_id", weapon_id)
	player.set("weapon_config", ProgressionData.weapon(class_id, weapon_id))
	weapon.set("weapon_id", weapon_id)
	player.add_child(weapon)
	weapon.set_process(false)
	weapon.set_physics_process(false)
	player.set("equipped_weapon", weapon)
	var state := Meta.default_state()
	var nodes: Array[String] = []
	for order in range(1, 6):
		nodes.append("%s_%s_b%d" % [class_id, weapon_id, order])
	if final_enabled:
		nodes.append("%s_%s_final" % [class_id, weapon_id])
	state["skill_nodes"] = nodes
	player.call("apply_constellation_weapon_profiles", Meta.skill_profiles_for_class(state, class_id))
	return player


static func _target(root: Node, position: Vector2) -> DummyEnemy:
	var target := DummyEnemy.new()
	target.global_position = position
	root.add_child(target)
	target.add_to_group("enemies")
	# Several independent fixtures run in one headless frame. Refresh the live
	# query cache after replacing a target so a retired fixture cannot be reused.
	TargetQuery._cached_frame = -1
	return target


static func _run_dodge(root: Node, final_enabled: bool) -> Dictionary:
	var weapon = ClassWeapon.new()
	weapon.set("aoe_radius", 220.0)
	weapon.set("damage", 100.0)
	var player := _new_player(root, "thief", "thief_smoke_bomb", final_enabled, weapon)
	var target := _target(root, player.global_position + Vector2.RIGHT * 80.0)
	player.set("max_health", 10000.0)
	player.set("health", 10000.0)
	player.set("derived_parameters", {"dodge": 0.55, "defense": 0.0, "absorb": 0.0})
	player.call("register_smoke_cloud", player.global_position, 200.0, 10.0, 0.35)
	var observed := {"events": 0}
	player.connect("constellation_final_resolved", func(_weapon_id: String, event: String, _target: Node2D, _context: Dictionary, resolution: Dictionary) -> void:
		if event == "dodge" and bool(resolution.get("triggered", false)):
			observed["events"] = int(observed["events"]) + 1
	)
	var incoming_hits := 0
	var before := target.health
	for _attempt in range(32):
		player.set("_damage_invulnerability_left", 0.0)
		player.call("take_damage", INCOMING_AMOUNT, INCOMING_SOURCE)
		incoming_hits += 1
	var result := {"incoming_hits": incoming_hits, "expected_events": int(observed["events"]), "final_damage": before - target.health, "sources": ["Player.take_damage"]}
	target.free()
	player.free()
	return result


static func _run_knight(root: Node, weapon_id: String, final_enabled: bool) -> Dictionary:
	var weapon = BerserkWeapon.new()
	var player := _new_player(root, "knight", weapon_id, final_enabled, weapon)
	var target := _target(root, player.global_position + Vector2.RIGHT * 80.0)
	player.set("max_health", 10000.0)
	player.set("health", 10000.0)
	var params: Dictionary = player.get("derived_parameters")
	params["dodge"] = 0.0
	params["defense"] = 0.0
	params["absorb"] = 12.0 if weapon_id == "tower_shield" else 0.0
	player.set("derived_parameters", params)
	var observed := {"events": 0}
	player.connect("constellation_final_resolved", func(_weapon_id: String, event: String, _target: Node2D, _context: Dictionary, resolution: Dictionary) -> void:
		if event in ["block", "damage_absorbed"] and bool(resolution.get("triggered", false)):
			observed["events"] = int(observed["events"]) + 1
	)
	var before := target.health
	player.set("_damage_invulnerability_left", 0.0)
	player.call("take_damage", INCOMING_AMOUNT, INCOMING_SOURCE, target)
	weapon.call("_damage_target", player, target, Vector2.RIGHT)
	var events := int(observed["events"])
	var final_id := "shield_stored_damage_bash" if weapon_id == "tower_shield" else "spear_block_counter_line"
	var result := {"incoming_hits": 1, "expected_events": events, "final_damage": _constellation_damage(target, final_id), "sources": ["Player.take_damage"]}
	target.free()
	player.free()
	return result


static func _constellation_damage(target: DummyEnemy, mechanic_id: String) -> float:
	var total := 0.0
	for entry_value in target.damage_events:
		var entry: Dictionary = entry_value
		var feedback: Dictionary = entry.get("feedback", {})
		if str(feedback.get("constellation_final", "")) == mechanic_id:
			total += float(entry.get("amount", 0.0))
	return total


static func _run_censer(root: Node, final_enabled: bool) -> Dictionary:
	var weapon = ClassWeapon.new()
	weapon.set("aoe_radius", 320.0)
	weapon.set("damage", 100.0)
	var player := _new_player(root, "priest", "priest_censer", final_enabled, weapon)
	var target := _target(root, player.global_position + Vector2.RIGHT * 80.0)
	player.set("max_health", 10000.0)
	player.set("health", 10000.0)
	var params: Dictionary = player.get("derived_parameters")
	params["dodge"] = 0.0
	params["defense"] = 0.0
	params["absorb"] = 0.0
	player.set("derived_parameters", params)
	player.call("constellation_set_single_hit_ward", "censer_%d" % weapon.get_instance_id(), 0.5, 10.0)
	var observed := {"events": 0}
	player.connect("constellation_final_resolved", func(_weapon_id: String, event: String, _target: Node2D, _context: Dictionary, resolution: Dictionary) -> void:
		if event == "damage_absorbed" and bool(resolution.get("triggered", false)):
			observed["events"] = int(observed["events"]) + 1
	)
	var before := target.health
	player.set("_damage_invulnerability_left", 0.0)
	player.call("take_damage", INCOMING_AMOUNT, INCOMING_SOURCE, target)
	var result := {"incoming_hits": 1, "expected_events": int(observed["events"]), "final_damage": before - target.health, "sources": ["Player.take_damage"]}
	target.free()
	player.free()
	return result


static func _measure_survivability(root: Node) -> Dictionary:
	var player := _new_player(root, "berserk", "sword", false, BerserkWeapon.new())
	var attacker := _target(root, player.global_position + Vector2.RIGHT * 80.0)
	player.set("max_health", 100.0)
	player.set("health", 100.0)
	player.set("derived_parameters", {"dodge": 0.0, "defense": 0.25, "absorb": 10.0, "regeneration": 6.0})
	player.set("_damage_invulnerability_left", 0.0)
	player.call("take_damage", INCOMING_AMOUNT, INCOMING_SOURCE, attacker)
	var hp_loss := 100.0 - float(player.get("health"))
	player.call("_apply_regeneration", 1.0)
	var after_regen := float(player.get("health"))
	player.set("_drain_heal_budget", 10.0)
	var lifesteal_healed := float(player.call("apply_drain_heal", 4.0))
	player.call("_apply_stat_scaling", false, float(player.get("max_health")))
	var shield_before := float((player.get("derived_parameters") as Dictionary).get("absorb", 0.0))
	player.call("constellation_set_timed_absorb", "fan1514_probe", 5.0, 10.0)
	var shield_added := float((player.get("derived_parameters") as Dictionary).get("absorb", 0.0)) - shield_before
	var result := {
		"incoming_amount": INCOMING_AMOUNT,
		"hp_loss": hp_loss,
		"mitigated_amount": INCOMING_AMOUNT - hp_loss,
		"effective_health": 100.0 * INCOMING_AMOUNT / maxf(hp_loss, 0.001),
		"ttd_seconds": ceil(100.0 / maxf(hp_loss, 0.001)) / 2.0,
		"sustain_healed": after_regen - (100.0 - hp_loss),
		"shield_added": shield_added,
		"lifesteal_healed": lifesteal_healed,
		"source": INCOMING_SOURCE,
		"sources": [INCOMING_SOURCE],
		"samples": [hp_loss, hp_loss, hp_loss],
		"variance": 0.0,
	}
	attacker.free()
	player.free()
	return result


static func _measure_quality(root: Node) -> Dictionary:
	var player := _new_player(root, "berserk", "sword", false, BerserkWeapon.new())
	player.global_position = Vector2.ZERO
	var speed := float(player.get("speed"))
	var window := float((Pack.QUALITY_CONTRACT["move_speed"] as Dictionary).get("window_seconds", 0.5))
	player.call("debug_set_move_target", Vector2.RIGHT * speed * window)
	player.call("_physics_process", window)
	var movement := {"unit": "units/s", "speed": speed, "window_seconds": window, "distance": player.global_position.length()}

	var game := ProbeGame.new()
	root.add_child(game)
	game.current_player = player
	var director = CombatDirector.new(game)
	var radius := float(player.get("pickup_radius"))
	var inside = PickupScript.new()
	game.add_child(inside)
	inside.add_to_group("pickups")
	inside.global_position = player.global_position + Vector2.RIGHT * (radius - 0.1)
	inside.call("setup", "xp", 1)
	director.call("_update_pickups", 0.0)
	var inside_collected := inside.is_queued_for_deletion()
	var outside = PickupScript.new()
	game.add_child(outside)
	outside.add_to_group("pickups")
	outside.global_position = player.global_position + Vector2.RIGHT * (radius + 0.1)
	outside.call("setup", "xp", 1)
	director.call("_update_pickups", 0.0)
	var outside_collected := outside.is_queued_for_deletion()
	game.free()
	player.free()
	return {
		"move_speed": movement,
		"pickup_radius": {"unit": "units", "radius": radius, "inside_collected": inside_collected, "outside_collected": outside_collected},
	}
