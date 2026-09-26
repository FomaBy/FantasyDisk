extends SceneTree

# FAN-3921 (FD14): characterization of the Player progression/reward state
# pipeline before/after extracting scripts/player/player_progression_runtime.gd.
# Every check pins EXISTING behavior of the public Player API: run-state reset
# on configure_character, XP/level/money accounting and leveled_up interleaving,
# the reward pipeline (stats, mods, affinity mods, artifact entries, removed and
# sustain-blocked keys, heal gating), the seeded cross-class artifact roll and
# its exact RNG consumption, meta skill-tree modifiers, weapon scaling on
# equip/re-equip, and the stat snapshot -> RunAutosave -> restore round trip.
#
# Run: python3 tools/godot_gate.py --headless --path . \
#     --script res://tests/player_progression_runtime_characterization_test.gd

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const PlayerScript := preload("res://scripts/player.gd")
const PD := preload("res://scripts/progression_data.gd")
const RunAutosaveScript := preload("res://scripts/run_autosave.gd")

const EPS := 0.0001
const CROSS_CLASS_SEED := 3921
const AUTOSAVE_PATH := "user://fantasydisk_fan3921_characterization_autosave.cfg"
const SNAPSHOT_KEYS := ["character_id", "weapon_id", "health", "max_health", "stats", "run_modifiers", "artifacts", "xp", "xp_to_next", "level", "money", "ultimate_charge"]
const WEAPON_FIELDS := ["damage", "fire_interval", "attack_range", "aoe_radius", "inner_width", "outer_width", "sweep_degrees", "cone_degrees", "knockback", "projectile_speed", "max_summons"]

var _levels_seen: Array = []


func _initialize() -> void:
	var errors: Array = []
	var holder := Node2D.new()
	root.add_child(holder)
	await process_frame

	_check_defaults_and_reset(errors)
	await _check_xp_and_money(holder, errors)
	await _check_reward_pipeline(holder, errors)
	await _check_doctor_sustain_gate(holder, errors)
	await _check_cross_class_roll(holder, errors)
	await _check_meta_skill_modifiers(holder, errors)
	await _check_equip_reequip(holder, errors)
	await _check_snapshot_round_trip(holder, errors)

	holder.queue_free()
	await process_frame
	_finish(errors)


# --- Defaults and configure_character reset ---------------------------------
func _check_defaults_and_reset(errors: Array) -> void:
	var defaults: Dictionary = PlayerScript._default_run_modifiers()
	var expected_literals := {
		"damage_multiplier": 1.0, "magic_damage_multiplier": 1.0, "attack_speed_multiplier": 1.0,
		"sandbox_player_damage_multiplier": 1.0, "sandbox_player_attack_speed_multiplier": 1.0,
		"aoe_radius_multiplier": 1.0, "move_speed_multiplier": 1.0, "max_health_multiplier": 1.0,
		"summon_bonus": 0.0, "damage_flat": 0.0, "max_health_flat": 0.0, "pickup_radius_flat": 0.0,
		"defense_flat": 0.0, "crit_chance_flat": 0.0, "crit_damage_flat": 0.0,
		"kill_momentum_stacks": 0.0, "kill_momentum_attack_speed_bonus": 0.0,
		"kill_momentum_crit_damage_bonus": 0.0, "dodge_flat": 0.0, "xp_gain_multiplier": 1.0,
		"money_gain_multiplier": 1.0, "ult_charge_multiplier": 1.0, "elite_boss_damage_multiplier": 1.0,
		"healing_multiplier": 1.0, "enemy_health_multiplier": 1.0, "knockback_multiplier": 1.0,
		"vampiric_heal_per_second_cap": PD.VAMPIRIC_HEAL_CAP_DEFAULT,
		"drain_heal_per_second_cap": PD.BalanceData.DRAIN_HEAL_PER_SECOND_CAP_DEFAULT,
	}
	if defaults.size() != expected_literals.size():
		errors.append("defaults: expected %d run modifier keys, got %d" % [expected_literals.size(), defaults.size()])
	for key in expected_literals:
		if not defaults.has(key) or absf(float(defaults[key]) - float(expected_literals[key])) > EPS:
			errors.append("defaults: %s expected %s, got %s" % [key, str(expected_literals[key]), str(defaults.get(key))])
	# Each call must hand out an independent dictionary, never a shared literal.
	var first: Dictionary = PlayerScript._default_run_modifiers()
	first["damage_multiplier"] = 9.0
	if float(PlayerScript._default_run_modifiers()["damage_multiplier"]) != 1.0:
		errors.append("defaults: _default_run_modifiers must return a fresh dictionary each call")


# --- XP, level, money ---------------------------------------------------------
func _check_xp_and_money(holder: Node2D, errors: Array) -> void:
	var player := await _make_player(holder, errors, "berserk", "")
	if player == null:
		return
	# Dirty the run state, then reconfigure synchronously: the reset contract is
	# pinned before any physics frame can add transient *_active keys.
	player.set("xp", 12)
	player.set("level", 4)
	player.set("money", 30)
	(player.get("run_modifiers") as Dictionary)["damage_multiplier"] = 3.0
	(player.get("artifacts") as Array).append({"id": "stale"})
	player.configure_character("berserk", "")
	if int(player.get("xp")) != 0 or int(player.get("xp_to_next")) != 5 or int(player.get("level")) != 1 or int(player.get("money")) != 0:
		errors.append("reset: fresh configure must give xp 0 / xp_to_next 5 / level 1 / money 0")
	if not (player.get("artifacts") as Array).is_empty():
		errors.append("reset: artifacts must be empty after configure")
	if player.get("stats") != PD.base_stats("berserk"):
		errors.append("reset: stats must equal ProgressionData.base_stats after configure")
	if player.get("run_modifiers") != PlayerScript._default_run_modifiers():
		errors.append("reset: run_modifiers must equal the defaults after configure")

	_levels_seen.clear()
	player.leveled_up.connect(func() -> void: _levels_seen.append(int(player.get("level"))))

	player.gain_xp(3)
	if int(player.get("xp")) != 3 or int(player.get("level")) != 1 or not _levels_seen.is_empty():
		errors.append("gain_xp: 3 xp below the threshold must not level (xp=%d level=%d)" % [int(player.get("xp")), int(player.get("level"))])
	player.gain_xp(2)
	var second_requirement := PD.next_xp_requirement(5)
	if int(player.get("xp")) != 0 or int(player.get("level")) != 2 or int(player.get("xp_to_next")) != second_requirement:
		errors.append("gain_xp: reaching the threshold must level once and carry 0 xp (xp=%d level=%d next=%d)" % [int(player.get("xp")), int(player.get("level")), int(player.get("xp_to_next"))])
	if _levels_seen != [2]:
		errors.append("gain_xp: leveled_up must fire once with level already 2, saw %s" % str(_levels_seen))

	# Multi-level burst: the signal fires per level, interleaved with the state.
	_levels_seen.clear()
	var oracle_xp := 0
	var oracle_next := second_requirement
	var oracle_level := 2
	var oracle_levels: Array = []
	var burst := second_requirement * 3 + 1
	oracle_xp += burst
	while oracle_xp >= oracle_next:
		oracle_xp -= oracle_next
		oracle_level += 1
		oracle_next = PD.next_xp_requirement(oracle_next)
		oracle_levels.append(oracle_level)
	player.gain_xp(burst)
	if int(player.get("xp")) != oracle_xp or int(player.get("level")) != oracle_level or int(player.get("xp_to_next")) != oracle_next:
		errors.append("gain_xp burst: expected xp=%d level=%d next=%d, got xp=%d level=%d next=%d" % [oracle_xp, oracle_level, oracle_next, int(player.get("xp")), int(player.get("level")), int(player.get("xp_to_next"))])
	if oracle_levels.size() < 2 or _levels_seen != oracle_levels:
		errors.append("gain_xp burst: leveled_up sequence expected %s, got %s" % [str(oracle_levels), str(_levels_seen)])

	# Multiplier rounding: 3 * 1.5 = 4.5 rounds to 5; zero always yields at least 1.
	var mods: Dictionary = player.get("run_modifiers")
	mods["xp_gain_multiplier"] = 1.5
	mods["money_gain_multiplier"] = 1.25
	var xp_before := int(player.get("xp"))
	player.set("xp_to_next", 1000)
	player.gain_xp(3)
	if int(player.get("xp")) != xp_before + 5:
		errors.append("gain_xp: 3 xp at x1.5 must add 5 (round half up), got +%d" % (int(player.get("xp")) - xp_before))
	player.gain_xp(0)
	if int(player.get("xp")) != xp_before + 6:
		errors.append("gain_xp: zero xp must still add the minimum 1")
	player.gain_money(10)
	if int(player.get("money")) != 13:
		errors.append("gain_money: 10 at x1.25 must add 13, got %d" % int(player.get("money")))
	player.gain_money(0)
	if int(player.get("money")) != 14:
		errors.append("gain_money: zero must still add the minimum 1")
	if player.spend_money(100) != false or int(player.get("money")) != 14:
		errors.append("spend_money: insufficient funds must refuse and keep the balance")
	if player.spend_money(5) != true or int(player.get("money")) != 9:
		errors.append("spend_money: affordable spend must succeed and subtract")
	_free_player(holder, player)


# --- Reward pipeline (berserk with a weapon) ---------------------------------
func _check_reward_pipeline(holder: Node2D, errors: Array) -> void:
	var weapon_ids: Array = PD.weapon_ids("berserk")
	var player := await _make_player(holder, errors, "berserk", str(weapon_ids[0]))
	if player == null:
		return
	var weapon: Node = player.get("equipped_weapon")
	if weapon == null:
		errors.append("reward: expected an equipped weapon")
		_free_player(holder, player)
		return
	var base_strength := float((player.get("stats") as Dictionary).get("strength", 0.0))
	var old_max := float(player.get("max_health"))
	player.set("health", 10.0)

	var reward := {
		"kind": "artifact", "id": "fan3921_relic", "title": "FAN-3921 relic", "description": "pin", "tier": 2,
		"stats": {"strength": 3.0, "endurance": 2.0},
		"mods": {"damage_multiplier": 1.2, "damage_flat": 4.0, "range_multiplier": 3.0},
		"affinity_mods": {"crit_chance_flat": 0.05, "attack_speed_multiplier": 1.1},
		"heal_percent": 0.5,
	}
	player.apply_reward(reward)

	var stats: Dictionary = player.get("stats")
	if absf(float(stats.get("strength", 0.0)) - (base_strength + 3.0)) > EPS:
		errors.append("reward: strength must add the reward stat")
	var mods: Dictionary = player.get("run_modifiers")
	if absf(float(mods.get("damage_multiplier", 0.0)) - 1.2) > EPS or absf(float(mods.get("damage_flat", 0.0)) - 4.0) > EPS:
		errors.append("reward: mods must multiply *_multiplier and add flats")
	if absf(float(mods.get("crit_chance_flat", 0.0)) - 0.05) > EPS or absf(float(mods.get("attack_speed_multiplier", 0.0)) - 1.1) > EPS:
		errors.append("reward: affinity_mods must apply with the same semantics")
	if mods.has("range_multiplier"):
		errors.append("reward: removed progression modifier keys must be skipped")
	var artifacts: Array = player.get("artifacts")
	var expected_entry := {"id": "fan3921_relic", "title": "FAN-3921 relic", "description": "pin", "tier": 2}
	if artifacts.size() != 1 or artifacts[0] != expected_entry:
		errors.append("reward: artifact entry must be {id,title,description,tier}, got %s" % str(artifacts))

	var expected_derived: Dictionary = PD.derived_parameters(stats, mods, player.get("weapon_config"))
	if player.get("derived_parameters") != expected_derived:
		errors.append("reward: derived_parameters must be recomputed from stats/run_modifiers/weapon_config")
	var new_max := float(expected_derived.get("health_point", 0.0))
	if absf(float(player.get("max_health")) - new_max) > EPS or absf(float(player.get("speed")) - float(expected_derived.get("move_speed", 0.0))) > EPS:
		errors.append("reward: max_health/speed must follow derived_parameters")
	if absf(float(player.get("pickup_radius")) - float(expected_derived.get("pickup_radius", 0.0))) > EPS:
		errors.append("reward: pickup_radius must follow derived_parameters")
	var expected_health := minf(new_max, 10.0 + maxf(new_max - old_max, 0.0))
	expected_health = minf(new_max, expected_health + new_max * 0.5)
	if absf(float(player.get("health")) - expected_health) > 0.001:
		errors.append("reward: health must keep the max-health delta then heal 50%% (expected %.3f, got %.3f)" % [expected_health, float(player.get("health"))])
	_check_weapon_scaled(errors, player, weapon, "reward")

	# Artifact without tier stores no tier key; second entry appends.
	player.apply_reward({"kind": "artifact", "id": "fan3921_plain", "title": "Plain"})
	artifacts = player.get("artifacts")
	if artifacts.size() != 2 or artifacts[1] != {"id": "fan3921_plain", "title": "Plain", "description": ""}:
		errors.append("reward: tierless artifact must store {id,title,description} only, got %s" % str(artifacts))
	# Non-artifact rewards never touch the artifact list.
	player.apply_reward({"kind": "upgrade", "mods": {"defense_flat": 2.0}})
	if (player.get("artifacts") as Array).size() != 2 or absf(float((player.get("run_modifiers") as Dictionary).get("defense_flat", 0.0)) - 2.0) > EPS:
		errors.append("reward: non-artifact reward must apply mods without an artifact entry")
	_free_player(holder, player)


# --- Doctor sustain gate ------------------------------------------------------
func _check_doctor_sustain_gate(holder: Node2D, errors: Array) -> void:
	var player := await _make_player(holder, errors, "doctor", "")
	if player == null:
		return
	if not player.blocks_generic_sustain():
		errors.append("doctor: expected generic_sustain_blocked trait")
		_free_player(holder, player)
		return
	player.set("health", 1.0)
	player.apply_reward({"mods": {"regeneration_flat": 2.0, "damage_flat": 1.0}, "heal_percent": 0.5})
	var mods: Dictionary = player.get("run_modifiers")
	if mods.has("regeneration_flat"):
		errors.append("doctor: blocked sustain key must not be applied from rewards")
	if absf(float(mods.get("damage_flat", 0.0)) - 1.0) > EPS:
		errors.append("doctor: non-sustain reward keys must still apply")
	if float(player.get("health")) > 1.0 + EPS:
		errors.append("doctor: generic heal_percent must be a no-op for the sustain-blocked class")
	player.apply_reward({"doctor_friendly": true, "mods": {"regeneration_flat": 2.0}, "heal_percent": 0.5})
	mods = player.get("run_modifiers")
	if absf(float(mods.get("regeneration_flat", 0.0)) - 2.0) > EPS:
		errors.append("doctor: doctor_friendly reward must pass sustain keys through")
	var expected_health := minf(float(player.get("max_health")), 1.0 + float(player.get("max_health")) * 0.5)
	if absf(float(player.get("health")) - expected_health) > 0.001:
		errors.append("doctor: doctor_friendly heal_percent must heal (expected %.3f, got %.3f)" % [expected_health, float(player.get("health"))])
	_free_player(holder, player)


# --- Seeded cross-class artifact roll and RNG consumption --------------------
func _check_cross_class_roll(holder: Node2D, errors: Array) -> void:
	var player := await _make_player(holder, errors, "thief", "")
	if player == null:
		return
	# Oracle: the same candidate walk and one shuffle on the global RNG.
	seed(CROSS_CLASS_SEED)
	var candidates: Array = []
	for artifact in PD.ARTIFACTS:
		var affinity: Array = (artifact as Dictionary).get("class_affinity", []) as Array
		if affinity.is_empty() or affinity.has("thief"):
			continue
		candidates.append(str((artifact as Dictionary).get("id", "")))
	candidates.shuffle()
	var expected_ids: Array = candidates.slice(0, 2)
	var expected_next_random := randi()

	seed(CROSS_CLASS_SEED)
	player.apply_reward({"kind": "artifact", "id": "stolen_crest", "title": "crest", "mods": {"cross_class_artifact_slots": 2.0}})
	var actual_next_random := randi()
	var rolled: Variant = (player.get("run_modifiers") as Dictionary).get("cross_class_artifact_ids", null)
	if not (rolled is Array) or (rolled as Array) != expected_ids:
		errors.append("cross-class: seeded roll expected %s, got %s" % [str(expected_ids), str(rolled)])
	if actual_next_random != expected_next_random:
		errors.append("cross-class: reward pipeline must consume exactly one shuffle of the global RNG")
	if absf(float((player.get("run_modifiers") as Dictionary).get("cross_class_artifact_slots", 0.0)) - 2.0) > EPS:
		errors.append("cross-class: the slot count itself must stay a plain flat modifier")

	# A second roll appends without duplicates.
	player.apply_reward({"mods": {"cross_class_artifact_slots": 1.0}})
	var rolled_again: Array = (player.get("run_modifiers") as Dictionary).get("cross_class_artifact_ids", [])
	if rolled_again.size() != 3 or rolled_again.slice(0, 2) != expected_ids:
		errors.append("cross-class: second roll must keep the first ids and append one more, got %s" % str(rolled_again))
	var unique := {}
	for id in rolled_again:
		unique[id] = true
		var owner_affinity: Array = []
		for artifact in PD.ARTIFACTS:
			if str((artifact as Dictionary).get("id", "")) == str(id):
				owner_affinity = (artifact as Dictionary).get("class_affinity", []) as Array
		if owner_affinity.is_empty() or owner_affinity.has("thief"):
			errors.append("cross-class: rolled id %s is not a foreign class artifact" % str(id))
	if unique.size() != rolled_again.size():
		errors.append("cross-class: rolled ids must be unique")
	_free_player(holder, player)


# --- Meta skill-tree modifiers ------------------------------------------------
func _check_meta_skill_modifiers(holder: Node2D, errors: Array) -> void:
	var weapon_ids: Array = PD.weapon_ids("berserk")
	var player := await _make_player(holder, errors, "berserk", str(weapon_ids[0]))
	if player == null:
		return
	var base_strength := float((player.get("stats") as Dictionary).get("strength", 0.0))
	var old_max := float(player.get("max_health"))
	player.set("health", 5.0)
	player.apply_meta_skill_modifiers({
		"strength_flat": 2.0, "damage_mult": 0.1, "class_damage_mult": 0.1, "defense_flat": 3.0,
		"regeneration_flat": 1.0, "ult_start_charge": 0.4, "death_save": 1.0, "lowhp_guard": 1.0,
		"unknown_tree_key": 5.0,
	})
	var stats: Dictionary = player.get("stats")
	var mods: Dictionary = player.get("run_modifiers")
	if absf(float(stats.get("strength", 0.0)) - (base_strength + 2.0)) > EPS:
		errors.append("meta: attribute flats must add to stats")
	if absf(float(mods.get("damage_multiplier", 0.0)) - 1.1 * 1.1) > EPS:
		errors.append("meta: mult keys compound as (1 + value), expected 1.21 got %s" % str(mods.get("damage_multiplier")))
	if absf(float(mods.get("defense_flat", 0.0)) - 3.0) > EPS or absf(float(mods.get("regeneration_flat", 0.0)) - 1.0) > EPS:
		errors.append("meta: flat keys must add to run_modifiers")
	if absf(float(player.get("ultimate_charge")) - 0.4 * float(player.get("ultimate_max_charge"))) > EPS:
		errors.append("meta: ult_start_charge must preload the ultimate charge")
	if float(mods.get("death_save", 0.0)) != 1.0 or float(mods.get("lowhp_guard", 0.0)) != 1.0:
		errors.append("meta: death_save/lowhp_guard flags must be set to 1.0")
	if mods.has("unknown_tree_key"):
		errors.append("meta: unmapped tree keys must be ignored")
	var expected_derived: Dictionary = PD.derived_parameters(stats, mods, player.get("weapon_config"))
	if player.get("derived_parameters") != expected_derived:
		errors.append("meta: derived_parameters must be recomputed")
	var new_max := float(expected_derived.get("health_point", 0.0))
	if absf(float(player.get("health")) - minf(new_max, 5.0 + maxf(new_max - old_max, 0.0))) > 0.001:
		errors.append("meta: health must keep the max-health delta without a full heal")
	_check_weapon_scaled(errors, player, player.get("equipped_weapon"), "meta")
	_free_player(holder, player)

	var doctor := await _make_player(holder, errors, "doctor", "")
	if doctor == null:
		return
	doctor.apply_meta_skill_modifiers({"regeneration_flat": 1.0, "defense_flat": 3.0})
	var doctor_mods: Dictionary = doctor.get("run_modifiers")
	if doctor_mods.has("regeneration_flat") or absf(float(doctor_mods.get("defense_flat", 0.0)) - 3.0) > EPS:
		errors.append("meta doctor: sustain flats are blocked while other flats apply")
	_free_player(holder, doctor)


# --- Equip / re-equip weapon scaling -----------------------------------------
func _check_equip_reequip(holder: Node2D, errors: Array) -> void:
	var weapon_ids: Array = PD.weapon_ids("berserk")
	if weapon_ids.size() < 2:
		errors.append("equip: berserk must expose at least two weapons")
		return
	var first_id := str(weapon_ids[0])
	var second_id := str(weapon_ids[1])
	var player := await _make_player(holder, errors, "berserk", first_id)
	if player == null:
		return
	var first_weapon: Node = player.get("equipped_weapon")
	var first_fields := _weapon_fields(first_weapon)
	_check_weapon_scaled(errors, player, first_weapon, "equip first")
	# Re-running the scaling must be idempotent thanks to captured base_* metas.
	player.call("_apply_weapon_scaling", first_weapon)
	if _weapon_fields(first_weapon) != first_fields:
		errors.append("equip: repeated _apply_weapon_scaling must not drift (base_* metas)")
	if not first_weapon.has_meta("base_damage") or not first_weapon.has_meta("base_fire_interval"):
		errors.append("equip: base_damage/base_fire_interval metas must be captured")

	var old_max := float(player.get("max_health"))
	player.set("health", old_max - 5.0)
	player.apply_reward({"mods": {"max_health_flat": 20.0}})
	var grown_max := float(player.get("max_health"))
	if grown_max <= old_max or absf(float(player.get("health")) - (old_max - 5.0 + (grown_max - old_max))) > 0.001:
		errors.append("equip: max-health growth must carry the delta into current health")

	player.equip_weapon(second_id)
	await process_frame
	var second_weapon: Node = player.get("equipped_weapon")
	if second_weapon == null or second_weapon == first_weapon or str(player.get("weapon_id")) != second_id:
		errors.append("equip: switching weapons must attach a fresh node and update weapon_id")
	if str((player.get("weapon_config") as Dictionary).get("id", "")) != second_id:
		errors.append("equip: weapon_config must follow the equipped weapon")
	if (player.call("_equipped_weapons") as Array).size() != 1:
		errors.append("equip: exactly one weapon may stay attached after a switch")
	if player.get("derived_parameters") != PD.derived_parameters(player.get("stats"), player.get("run_modifiers"), player.get("weapon_config")):
		errors.append("equip: derived_parameters must be recomputed for the new weapon config")
	_check_weapon_scaled(errors, player, second_weapon, "equip second")

	player.equip_weapon(first_id)
	await process_frame
	var reequipped: Node = player.get("equipped_weapon")
	if reequipped == null or str(player.get("weapon_id")) != first_id:
		errors.append("re-equip: weapon_id must return to the first weapon")
	_check_weapon_scaled(errors, player, reequipped, "re-equip")
	# An unknown id falls back to the class's first weapon config (ProgressionData
	# .weapon fallback): a fresh node of that weapon with identical scaled fields.
	var before_unknown := _weapon_fields(reequipped)
	player.equip_weapon("fan3921_no_such_weapon")
	await process_frame
	var fallback: Node = player.get("equipped_weapon")
	if fallback == null or fallback == reequipped or str(player.get("weapon_id")) != first_id or _weapon_fields(fallback) != before_unknown:
		errors.append("equip: an unknown weapon id must fall back to the first class weapon with the same scaled fields")
	_free_player(holder, player)


# --- Stat snapshot -> RunAutosave -> restore round trip ----------------------
func _check_snapshot_round_trip(holder: Node2D, errors: Array) -> void:
	var weapon_ids: Array = PD.weapon_ids("berserk")
	var weapon_id := str(weapon_ids[0])
	var source := await _make_player(holder, errors, "berserk", weapon_id)
	if source == null:
		return
	source.apply_reward({"kind": "artifact", "id": "fan3921_relic", "title": "relic", "tier": 1, "stats": {"agility": 4.0}, "mods": {"damage_multiplier": 1.3, "max_health_flat": 15.0, "range_multiplier": 2.0}})
	source.apply_meta_skill_modifiers({"strength_flat": 1.0, "attack_speed_mult": 0.2})
	source.gain_xp(40)
	source.gain_money(77)
	source.set("ultimate_charge", 35.0)
	source.set("health", float(source.get("max_health")) * 0.6)
	var source_mods: Dictionary = source.get("run_modifiers")
	source_mods["cross_class_artifact_ids"] = ["fan3921_foreign_a", "fan3921_foreign_b"]
	source_mods["range_multiplier"] = 2.0  # legacy key: dropped by sanitize on restore

	var snapshot := _store_snapshot(source)
	var saved := RunAutosaveScript.save_run({"selected_character_id": "berserk", "selected_weapon_id": weapon_id, "run_player_snapshot": snapshot.duplicate(true)}, AUTOSAVE_PATH)
	if not saved:
		errors.append("autosave: save_run must succeed")
	var loaded: Dictionary = RunAutosaveScript.load_run(AUTOSAVE_PATH)
	var loaded_snapshot: Dictionary = loaded.get("run_player_snapshot", {})
	if loaded_snapshot != snapshot:
		errors.append("autosave: run_player_snapshot must survive the ConfigFile round trip unchanged")
	for key in SNAPSHOT_KEYS:
		if not loaded_snapshot.has(key):
			errors.append("autosave: snapshot misses key %s" % key)

	var restored := await _make_player(holder, errors, "doctor", "")
	if restored == null:
		return
	# Compare synchronously: a physics frame would regenerate health and add
	# transient *_active keys on both players.
	_restore_snapshot(restored, loaded_snapshot, weapon_id)
	var expected_mods: Dictionary = PD.sanitize_run_modifiers(snapshot["run_modifiers"])
	if expected_mods.has("range_multiplier") or not expected_mods.has("cross_class_artifact_ids"):
		errors.append("autosave: sanitize contract changed (legacy key kept or array key dropped)")
	if restored.get("run_modifiers") != expected_mods:
		errors.append("restore: run_modifiers must equal the sanitized snapshot")
	if restored.get("stats") != source.get("stats") or restored.get("artifacts") != source.get("artifacts"):
		errors.append("restore: stats and artifacts must round trip")
	for key in ["xp", "xp_to_next", "level", "money"]:
		if int(restored.get(key)) != int(source.get(key)):
			errors.append("restore: %s must round trip (%s vs %s)" % [key, str(restored.get(key)), str(source.get(key))])
	if str(restored.get("character_id")) != "berserk" or str(restored.get("weapon_id")) != weapon_id:
		errors.append("restore: character/weapon identity must follow the snapshot")
	var expected_derived: Dictionary = PD.derived_parameters(restored.get("stats"), restored.get("run_modifiers"), restored.get("weapon_config"))
	if restored.get("derived_parameters") != expected_derived:
		errors.append("restore: derived_parameters must be recomputed from the restored state")
	if absf(float(restored.get("max_health")) - float(source.get("max_health"))) > EPS or absf(float(restored.get("speed")) - float(source.get("speed"))) > EPS:
		errors.append("restore: max_health/speed must match the source player")
	if absf(float(restored.get("health")) - float(snapshot["health"])) > 0.001:
		errors.append("restore: health must be clamped to the snapshot value (%.3f vs %.3f)" % [float(restored.get("health")), float(snapshot["health"])])
	if absf(float(restored.get("ultimate_charge")) - 35.0) > EPS:
		errors.append("restore: ultimate_charge must round trip with clamp")
	var source_weapon: Node = source.get("equipped_weapon")
	var restored_weapon: Node = restored.get("equipped_weapon")
	if source_weapon == null or restored_weapon == null:
		errors.append("restore: both players must hold an equipped weapon")
	elif _weapon_fields(restored_weapon) != _weapon_fields(source_weapon):
		errors.append("restore: scaled weapon fields must match the source (%s vs %s)" % [str(_weapon_fields(restored_weapon)), str(_weapon_fields(source_weapon))])
	_check_weapon_scaled(errors, restored, restored_weapon, "restore")

	if not RunAutosaveScript.clear_run(AUTOSAVE_PATH) or RunAutosaveScript.has_run(AUTOSAVE_PATH):
		errors.append("autosave: clear_run must remove the characterization save")
	_free_player(holder, source)
	_free_player(holder, restored)


# Mirrors combat_director._store_player_snapshot for a player with no transient
# ultimate overlays (the transient-key scrub is a no-op here by construction).
func _store_snapshot(player: Node) -> Dictionary:
	return {
		"character_id": player.get("character_id"),
		"weapon_id": player.get("weapon_id"),
		"health": player.get("health"),
		"max_health": player.get("max_health"),
		"stats": (player.get("stats") as Dictionary).duplicate(true),
		"run_modifiers": (player.get("run_modifiers") as Dictionary).duplicate(true),
		"artifacts": (player.get("artifacts") as Array).duplicate(true),
		"xp": player.get("xp"),
		"xp_to_next": player.get("xp_to_next"),
		"level": player.get("level"),
		"money": player.get("money"),
		"ultimate_charge": player.get("ultimate_charge"),
	}


# Mirrors combat_director._restore_player_snapshot.
func _restore_snapshot(player: Node, snapshot: Dictionary, weapon_id: String) -> void:
	player.configure_character(str(snapshot.get("character_id", "berserk")))
	player.set("stats", (snapshot.get("stats", {}) as Dictionary).duplicate(true))
	player.set("run_modifiers", PD.sanitize_run_modifiers(snapshot.get("run_modifiers", {}) as Dictionary))
	player.set("artifacts", (snapshot.get("artifacts", []) as Array).duplicate(true))
	player.set("xp", int(snapshot.get("xp", 0)))
	player.set("xp_to_next", int(snapshot.get("xp_to_next", 5)))
	player.set("level", int(snapshot.get("level", 1)))
	player.set("money", int(snapshot.get("money", 0)))
	player.equip_weapon(weapon_id)
	player.set("health", minf(float(snapshot.get("health", player.get("max_health"))), float(player.get("max_health"))))
	var ultimate_max := maxf(float(player.get("ultimate_max_charge")), 0.0)
	player.set("ultimate_charge", clampf(float(snapshot.get("ultimate_charge", 0.0)), 0.0, ultimate_max))


# Weapon fields must equal the documented composition of derived parameters,
# captured base_* metas and the Player meta/constellation helpers.
func _check_weapon_scaled(errors: Array, player: Node, weapon: Node, label: String) -> void:
	if weapon == null:
		errors.append("%s: no weapon to check" % label)
		return
	var derived: Dictionary = player.get("derived_parameters")
	var context: Dictionary = player.meta_context_for_weapon(weapon)
	var wid := str(context.get("weapon_id", ""))
	var damage_parameter := "damage"
	if weapon.get("damage_parameter") != null:
		damage_parameter = str(weapon.get("damage_parameter"))
	var expected_damage: float = float(derived.get(damage_parameter, weapon.get_meta("base_damage"))) + player.constellation_weapon_amount(wid, "weapon_damage_flat")
	if absf(float(weapon.get("damage")) - expected_damage) > 0.001:
		errors.append("%s: weapon damage expected %.4f, got %.4f" % [label, expected_damage, float(weapon.get("damage"))])
	if weapon.get("fire_interval") != null:
		var attack_speed: float = float(derived.get("attack_speed", 1.0)) * player.constellation_weapon_multiplier(wid, "weapon_attack_speed_mult")
		var expected_interval: float = max(0.18, (float(weapon.get_meta("base_fire_interval", 1.0)) / max(attack_speed, 0.1)) * player.meta_interval_multiplier(context))
		if absf(float(weapon.get("fire_interval")) - expected_interval) > 0.001:
			errors.append("%s: fire_interval expected %.4f, got %.4f" % [label, expected_interval, float(weapon.get("fire_interval"))])
	if weapon.get("attack_range") != null:
		var expected_range: float = float(weapon.get_meta("base_attack_range")) * player.constellation_weapon_geometry_multiplier(wid)
		if absf(float(weapon.get("attack_range")) - expected_range) > 0.001:
			errors.append("%s: attack_range expected %.4f, got %.4f" % [label, expected_range, float(weapon.get("attack_range"))])
	var capabilities: Array = (player.get("weapon_config") as Dictionary).get("geometry_capabilities", [])
	if capabilities.has("aoe_radius") and weapon.get("aoe_radius") != null:
		var area: float = float(derived.get("attack_area_multiplier", 1.0)) * player.constellation_weapon_geometry_multiplier(wid)
		var expected_radius: float = float(weapon.get_meta("base_aoe_radius", 200.0)) * area * player.meta_radius_multiplier(context)
		if absf(float(weapon.get("aoe_radius")) - expected_radius) > 0.001:
			errors.append("%s: aoe_radius expected %.4f, got %.4f" % [label, expected_radius, float(weapon.get("aoe_radius"))])
	if weapon.get("knockback") != null:
		var control: float = player.constellation_weapon_multiplier(wid, "control_sustain_value_mult") * player.constellation_weapon_multiplier(wid, "hidden_defense_mastery_mult")
		var expected_knockback: float = float(derived.get("knockback_power", weapon.get_meta("base_knockback", 80.0))) * player.meta_knockback_multiplier(context) * control
		if absf(float(weapon.get("knockback")) - expected_knockback) > 0.001:
			errors.append("%s: knockback expected %.4f, got %.4f" % [label, expected_knockback, float(weapon.get("knockback"))])
	if weapon.get("projectile_speed") != null and absf(float(weapon.get("projectile_speed")) - float(weapon.get_meta("base_projectile_speed", 520.0))) > 0.001:
		errors.append("%s: projectile_speed must stay at its captured base" % label)


func _weapon_fields(weapon: Node) -> Dictionary:
	var fields := {}
	if weapon == null:
		return fields
	for field in WEAPON_FIELDS:
		var value: Variant = weapon.get(field)
		if value != null:
			fields[field] = value
	return fields


func _make_player(holder: Node2D, errors: Array, character_id: String, weapon_id: String) -> Node:
	var player := PLAYER_SCENE.instantiate() as Node2D
	holder.add_child(player)
	player.add_to_group("player")
	if not player.has_method("configure_character") or not player.has_method("apply_reward"):
		errors.append("Player lacks configure_character/apply_reward")
		return null
	player.call("configure_character", character_id, weapon_id)
	await process_frame
	return player


func _free_player(holder: Node2D, player: Node) -> void:
	holder.remove_child(player)
	player.queue_free()


func _finish(errors: Array) -> void:
	if not errors.is_empty():
		for e in errors:
			push_error("Player progression characterization: %s" % e)
		push_error("Player progression characterization test: %d errors." % errors.size())
		quit(1)
		return
	print("Player progression characterization test passed.")
	quit(0)
