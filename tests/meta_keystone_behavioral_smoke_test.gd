extends SceneTree

# SCRUM-837: behavioral gate for Meta 4.1 keystones.
#
# This smoke intentionally verifies live Player/Enemy/Weapon outcomes. It must not
# pass by only checking modifier dictionaries: each scenario either deals damage,
# changes a live weapon cadence/radius/pierce count, changes incoming damage, or
# applies/ticks a real status effect in a headless SceneTree mini-arena.

const Meta := preload("res://scripts/meta_progression.gd")
const TreeData := preload("res://scripts/meta_progression_tree_data.gd")
const PlayerScript := preload("res://scripts/player.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")
const ClassWeaponScript := preload("res://scripts/class_weapon.gd")
const SummonerWeaponScript := preload("res://scripts/summoner_weapon.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")

const GENERIC_CONDITIONAL_KEYS := {
	"hurt_damage_bonus": true,
	"stance_damage_bonus": true,
	"rush_damage_bonus": true,
	"swarm_damage_bonus": true,
	"stance_attack_speed_bonus": true,
	"rush_crit_bonus": true,
}

const REQUIRED_SEMANTIC_KEYS := [
	"enemy_hit_damage_down",
	"gold_damage_per_50",
	"gold_damage_bonus_cap",
	"elemental_resonance_bonus",
	"elemental_orb_extra_count",
	"prism_rift_radius_mult",
	"heal_to_holy_damage_ratio",
	"ward_absorb_bonus",
	"reactor_heat_damage_bonus",
	"reactor_heat_incoming_damage",
	"magnet_radius_mult",
	"device_attack_speed_bonus",
	"non_device_damage_mult",
	"mine_extra_count",
	"repair_radius_mult",
	"dot_death_spread_duration",
	"direct_damage_mult",
	"beam_duration_mult",
	"explosion_radius_mult",
	"guitar_aura_radius_mult",
	"riff_streak_damage_bonus",
	"shadow_burst_invisibility_time",
	"charged_shot_extra_pierce",
	"charge_time_mult",
	"trap_extra_count",
	"non_trap_damage_mult",
	"drain_extra_targets",
	"medkit_healing_mult",
	"surgical_close_damage_bonus",
	"ranged_damage_mult",
	"cloud_detonation_radius_mult",
	"pool_duration_mult",
	"homunculus_power_mult",
	"pet_damage_mult",
	"pet_personal_damage_mult",
	"briar_radius_mult",
	"bastion_defense_bonus",
	"bastion_taunt",
]

const REQUIRED_PLAYER_METHODS := [
	"meta_context_for_weapon",
	"meta_damage_multiplier",
	"meta_extra_projectiles",
	"meta_extra_pierce",
	"meta_radius_multiplier",
	"meta_duration_multiplier",
	"meta_interval_multiplier",
	"meta_charge_time_multiplier",
	"meta_apply_priest_ward",
]

const REQUIRED_CLASS_SPECIFIC_KEYS := {
	"soldier": ["enemy_hit_damage_down", "stance_attack_speed_bonus"],
	"thief": ["rush_crit_bonus", "gold_damage_per_50", "shop_price_mult"],
	"elementalist": ["elemental_resonance_bonus", "elemental_orb_extra_count"],
	"priest": ["heal_to_holy_damage_ratio", "ward_absorb_bonus"],
	"robot": ["reactor_heat_damage_bonus", "reactor_heat_incoming_damage", "magnet_radius_mult"],
	"engineer": ["device_attack_speed_bonus", "mine_extra_count"],
	"dark_mage": ["dot_death_spread_duration", "beam_duration_mult"],
	"guitarist": ["guitar_aura_radius_mult", "riff_streak_damage_bonus"],
	"assassin": ["shadow_burst_invisibility_time"],
	"ranger": ["charged_shot_extra_pierce", "trap_extra_count"],
	"doctor": ["drain_extra_targets", "surgical_close_damage_bonus"],
	"chemist": ["cloud_detonation_radius_mult", "homunculus_power_mult"],
	"druid": ["pet_damage_mult", "briar_radius_mult"],
	"knight": ["bastion_defense_bonus", "bastion_taunt"],
}


func _initialize() -> void:
	root.set_meta("combat_feedback", false)
	var errors: Array = []
	_test_semantic_surface(errors)
	_test_keystone_signatures_are_not_flattened(errors)
	if not errors.is_empty():
		_report(errors)
		return

	var holder := Node2D.new()
	holder.name = "SCRUM837MiniArena"
	root.add_child(holder)
	current_scene = holder

	await _test_existing_condition_outcomes(holder, errors)
	await _test_semantic_condition_outcomes(holder, errors)
	await _test_downside_outcomes(holder, errors)
	await _test_mutation_self_checks(holder, errors)

	current_scene = null
	holder.queue_free()
	await process_frame

	if not errors.is_empty():
		_report(errors)
		return
	print("Meta keystone behavioral smoke test passed.")
	quit(0)


func _report(errors: Array) -> void:
	for error in errors:
		push_error("SCRUM-837 behavioral gate: %s" % str(error))
	push_error("Meta keystone behavioral smoke test FAILED: %d errors." % errors.size())
	quit(1)


func _test_semantic_surface(errors: Array) -> void:
	var flat_map: Dictionary = PlayerScript.META_SKILL_FLAT_MAP
	for key in REQUIRED_SEMANTIC_KEYS:
		if not flat_map.has(str(key)):
			errors.append("SCRUM-835 semantic key '%s' is not wired in Player.META_SKILL_FLAT_MAP." % str(key))
		if not TreeData.POWER_WEIGHTS.has(str(key)):
			errors.append("SCRUM-835 semantic key '%s' has no POWER_WEIGHTS entry." % str(key))
		if not TreeData.EFFECT_LABELS.has(str(key)):
			errors.append("SCRUM-835 semantic key '%s' has no EFFECT_LABELS entry." % str(key))
	var probe := PLAYER_SCENE.instantiate()
	for method_name in REQUIRED_PLAYER_METHODS:
		if not probe.has_method(str(method_name)):
			errors.append("Player missing SCRUM-835 runtime helper '%s'." % str(method_name))
	if _method_arg_count(probe, "on_weapon_hit") < 4:
		errors.append("Player.on_weapon_hit must accept hit_context for semantic on-hit effects.")
	probe.queue_free()
	var weapon_probe := ClassWeaponScript.new()
	for method_name in ["_meta_context", "_effective_pierce_count"]:
		if not weapon_probe.has_method(str(method_name)):
			errors.append("ClassWeapon missing SCRUM-835 runtime helper '%s'." % str(method_name))
	weapon_probe.queue_free()


func _test_keystone_signatures_are_not_flattened(errors: Array) -> void:
	var repeated_signatures := {}
	for class_id in REQUIRED_CLASS_SPECIFIC_KEYS.keys():
		var k0 := Meta.node_by_id("%s_k0" % str(class_id))
		var k1 := Meta.node_by_id("%s_k1" % str(class_id))
		if k0.is_empty() or k1.is_empty():
			errors.append("Class '%s' missing k0/k1 keystone nodes." % str(class_id))
			continue
		var key_union := {}
		for node in [k0, k1]:
			var effects: Dictionary = node.get("effects", {})
			var keys: Array = effects.keys()
			keys.sort()
			var signature := "%s:" % str(class_id)
			for key in keys:
				key_union[str(key)] = true
				signature += "%s=%.4f;" % [str(key), float(effects[key])]
			if repeated_signatures.has(signature):
				errors.append("Keystone signature repeated: %s and %s." % [str(node.get("id", "")), str(repeated_signatures[signature])])
			repeated_signatures[signature] = str(node.get("id", ""))
		for required_key in REQUIRED_CLASS_SPECIFIC_KEYS[str(class_id)]:
			if not key_union.has(str(required_key)):
				errors.append("Class '%s' k0/k1 still lacks class-specific semantic key '%s'." % [str(class_id), str(required_key)])
		var has_class_semantic_key := false
		for key in key_union.keys():
			if REQUIRED_SEMANTIC_KEYS.has(str(key)) or (REQUIRED_CLASS_SPECIFIC_KEYS[str(class_id)] as Array).has(str(key)):
				has_class_semantic_key = true
				break
		if not has_class_semantic_key:
			errors.append("Class '%s' k0/k1 are flattened to generic conditional/stat keys." % str(class_id))


func _test_existing_condition_outcomes(holder: Node2D, errors: Array) -> void:
	var player := await _make_player(holder, "berserk", {"hurt_damage_bonus": 0.35})
	var weapon := await _make_weapon(player, {"damage": 100.0})
	var base_loss := await _weapon_hit_loss(holder, player, weapon)
	player.set("health", float(player.get("max_health")) * 0.35)
	player.call("_update_conditional_keystones", 0.1)
	player.call("_apply_weapon_scaling", weapon)
	var hurt_loss := await _weapon_hit_loss(holder, player, weapon)
	if hurt_loss <= base_loss * 1.20:
		errors.append("HP-threshold keystone did not increase real weapon damage (base %.2f, hurt %.2f)." % [base_loss, hurt_loss])
	_cleanup_player(player)

	player = await _make_player(holder, "soldier", {"stance_attack_speed_bonus": 0.25})
	weapon = await _make_weapon(player, {"fire_interval": 1.0})
	var base_interval := float(weapon.get("fire_interval"))
	player.set("velocity", Vector2.ZERO)
	player.call("_update_conditional_keystones", 1.0)
	player.call("_apply_weapon_scaling", weapon)
	var stance_interval := float(weapon.get("fire_interval"))
	if stance_interval >= base_interval - 0.02:
		errors.append("Stance keystone did not reduce live weapon fire_interval (base %.3f, stance %.3f)." % [base_interval, stance_interval])
	_cleanup_player(player)

	player = await _make_player(holder, "thief", {"rush_crit_bonus": 0.18})
	var base_crit := _param(player, "crit_chance")
	player.call("_trigger_rush_window")
	var rush_crit := _param(player, "crit_chance")
	if rush_crit <= base_crit + 0.04:
		errors.append("Post-event rush window did not raise real crit chance (base %.3f, rush %.3f)." % [base_crit, rush_crit])
	_cleanup_player(player)

	player = await _make_player(holder, "berserk", {"swarm_damage_bonus": 0.28})
	weapon = await _make_weapon(player, {"damage": 100.0})
	base_loss = await _weapon_hit_loss(holder, player, weapon)
	for index in range(int(PlayerScript.SWARM_CAP)):
		var foe := await _make_enemy(holder, player.global_position + Vector2(12.0 + index, 0.0), 100.0)
		foe.name = "SwarmCounter_%d" % index
	player.call("_update_conditional_keystones", PlayerScript.SWARM_SCAN_INTERVAL + 0.1)
	player.call("_apply_weapon_scaling", weapon)
	var swarm_loss := await _weapon_hit_loss(holder, player, weapon)
	if swarm_loss <= base_loss * 1.15:
		errors.append("Count-in-radius keystone did not increase real weapon damage (base %.2f, swarm %.2f)." % [base_loss, swarm_loss])
	_cleanup_player(player)


func _test_semantic_condition_outcomes(holder: Node2D, errors: Array) -> void:
	await _test_on_hit_debuff(holder, errors, true)
	await _test_gold_scaling(holder, errors, true)
	await _test_elemental_mark(holder, errors)
	await _test_reactor_heat(holder, errors)
	await _test_device_tempo(holder, errors)
	await _test_dot_spread(holder, errors)
	await _test_invisibility(holder, errors)
	await _test_pierce(holder, errors, true)
	await _test_drain_extra_target(holder, errors)
	await _test_cloud_detonation(holder, errors)
	await _test_pet_buff(holder, errors)


func _test_on_hit_debuff(holder: Node2D, errors: Array, enabled: bool) -> bool:
	var player := await _make_player(holder, "soldier", {"enemy_hit_damage_down": 0.30 if enabled else 0.0})
	var weapon := await _make_weapon(player, {"damage": 20.0})
	var enemy := await _make_enemy(holder, player.global_position + Vector2(80.0, 0.0), 1000.0)
	weapon.call("_damage_enemy", enemy, 20.0)
	var outgoing := float(enemy.call("_outgoing_damage", 10.0)) if enemy.has_method("_outgoing_damage") else 10.0
	_cleanup_player(player)
	enemy.queue_free()
	await process_frame
	var ok := outgoing < 8.5 if enabled else outgoing > 9.5
	if not ok:
		errors.append("On-hit debuff %s produced enemy outgoing damage %.2f." % ["enabled" if enabled else "disabled", outgoing])
	return ok


func _test_gold_scaling(holder: Node2D, errors: Array, enabled: bool) -> bool:
	var mods := {"gold_damage_per_50": 0.05 if enabled else 0.0, "gold_damage_bonus_cap": 0.25}
	var player := await _make_player(holder, "thief", mods)
	player.set("money", 350)
	var weapon := await _make_weapon(player, {"damage": 100.0})
	var loss := await _weapon_hit_loss(holder, player, weapon, 100.0)
	_cleanup_player(player)
	var ok := loss > 118.0 if enabled else loss < 106.0
	if not ok:
		errors.append("Gold-scaling damage %s produced hit loss %.2f." % ["enabled" if enabled else "disabled", loss])
	return ok


func _test_elemental_mark(holder: Node2D, errors: Array) -> void:
	var player := await _make_player(holder, "elementalist", {"elemental_resonance_bonus": 0.35})
	var weapon := await _make_weapon(player, {"damage": 100.0, "pool_element": "spark", "leaves_pool": true})
	var enemy := await _make_enemy(holder, player.global_position + Vector2(80.0, 0.0), 1000.0)
	weapon.call("_damage_enemy", enemy, 100.0)
	var after_first := float(enemy.get("health"))
	weapon.set("pool_element", "poison")
	weapon.call("_damage_enemy", enemy, 100.0)
	var second_loss := after_first - float(enemy.get("health"))
	if second_loss < 128.0:
		errors.append("Elemental mark resonance did not increase the next different-element hit (loss %.2f)." % second_loss)
	_cleanup_player(player)
	enemy.queue_free()
	await process_frame


func _test_reactor_heat(holder: Node2D, errors: Array) -> void:
	var player := await _make_player(holder, "robot", {"reactor_heat_damage_bonus": 0.30, "reactor_heat_incoming_damage": 0.15})
	var weapon := await _make_weapon(player, {"damage": 100.0, "attack_mode": "robot_reactor_vent", "weapon_id": "robot_reactor_vent"})
	var cold_loss := await _weapon_hit_loss(holder, player, weapon)
	_disable_random_damage_avoidance(player)
	var hp_before := float(player.get("health"))
	player.call("take_damage", 10.0, "reactor_cold_test")
	var cold_taken := hp_before - float(player.get("health"))
	player.set("health", hp_before)
	player.set("_damage_invulnerability_left", 0.0)
	for _i in range(5):
		await _weapon_hit_loss(holder, player, weapon)
	player.call("_update_meta_keystone_runtime", 0.05)
	var hot_loss := await _weapon_hit_loss(holder, player, weapon)
	_disable_random_damage_avoidance(player)
	hp_before = float(player.get("health"))
	player.call("take_damage", 10.0, "reactor_test")
	var hot_taken := hp_before - float(player.get("health"))
	if hot_loss <= cold_loss * 1.20:
		errors.append("Reactor heat did not increase real weapon damage (cold %.2f, hot %.2f)." % [cold_loss, hot_loss])
	if cold_taken <= 0.0 or hot_taken <= cold_taken * 1.08:
		errors.append("Reactor heat downside did not increase incoming damage (cold %.2f, hot %.2f)." % [cold_taken, hot_taken])
	_cleanup_player(player)


func _test_device_tempo(holder: Node2D, errors: Array) -> void:
	var player := await _make_player(holder, "engineer", {"device_attack_speed_bonus": 0.25})
	var weapon := await _make_weapon(player, {"attack_mode": "amp", "weapon_id": "engineer_sentry_link", "fire_interval": 1.0, "amp_pulse_interval": 1.0})
	player.call("_apply_weapon_scaling", weapon)
	if float(weapon.get("fire_interval")) >= 0.90 or float(weapon.get("amp_pulse_interval")) >= 0.90:
		errors.append("Device tempo keystone did not reduce live device intervals (fire %.3f, pulse %.3f)." % [float(weapon.get("fire_interval")), float(weapon.get("amp_pulse_interval"))])
	_cleanup_player(player)


func _test_dot_spread(holder: Node2D, errors: Array) -> void:
	var player := await _make_player(holder, "dark_mage", {"dot_death_spread_duration": 2.0})
	var dead_enemy := await _make_enemy(holder, player.global_position + Vector2(90.0, 0.0), 100.0)
	var neighbor := await _make_enemy(holder, dead_enemy.global_position + Vector2(60.0, 0.0), 100.0)
	StatusEffects.apply_status(dead_enemy, "curse_dot", {"duration": 1.2, "dot_damage": 12.0, "dot_interval": 0.2})
	player.call("on_enemy_killed", dead_enemy)
	if not StatusEffects.has_status(neighbor, "curse_dot"):
		errors.append("DoT death spread did not copy a real DoT status to a nearby enemy.")
	else:
		var before := float(neighbor.get("health"))
		StatusEffects.tick(neighbor, 0.25)
		if float(neighbor.get("health")) >= before - 1.0:
			errors.append("Spread DoT status did not tick real damage on neighbor.")
	_cleanup_player(player)
	dead_enemy.queue_free()
	neighbor.queue_free()
	await process_frame


func _test_invisibility(holder: Node2D, errors: Array) -> void:
	var player := await _make_player(holder, "assassin", {"shadow_burst_invisibility_time": 1.5})
	var enemy := await _make_enemy(holder, player.global_position + Vector2(120.0, 0.0), 100.0)
	player.call("trigger_assassin_crit_shadow", enemy, 96.0)
	var hp_before := float(player.get("health"))
	var applied := bool(player.call("take_damage", 20.0, "invisibility_test"))
	if applied or float(player.get("health")) < hp_before - 0.1:
		errors.append("Shadow invisibility did not block incoming damage.")
	_cleanup_player(player)
	enemy.queue_free()
	await process_frame


func _test_pierce(holder: Node2D, errors: Array, enabled: bool) -> bool:
	var player := await _make_player(holder, "ranger", {"charged_shot_extra_pierce": 2.0 if enabled else 0.0})
	var weapon := await _make_weapon(player, {
		"attack_mode": "beam",
		"weapon_id": "charged_pierce_probe",
		"damage": 40.0,
		"pierce_count": 1,
		"charge_seconds": 0.4,
		"attack_range": 520.0,
		"beam_width": 80.0,
	})
	var enemies := []
	for index in range(3):
		enemies.append(await _make_enemy(holder, player.global_position + Vector2(110.0 + 70.0 * index, 0.0), 100.0))
	weapon.call("_fire_single_beam", player, Vector2.RIGHT)
	var hit_count := 0
	for enemy in enemies:
		if float((enemy as Node).get("health")) < 99.0:
			hit_count += 1
		(enemy as Node).queue_free()
	_cleanup_player(player)
	await process_frame
	var ok := hit_count >= 3 if enabled else hit_count == 1
	if not ok:
		errors.append("Pierce scenario %s hit %d targets." % ["enabled" if enabled else "disabled", hit_count])
	return ok


func _test_drain_extra_target(holder: Node2D, errors: Array) -> void:
	var player := await _make_player(holder, "doctor", {"drain_extra_targets": 1.0})
	player.set("health", float(player.get("max_health")) * 0.55)
	player.call("_apply_regeneration", 1.0)
	var weapon := await _make_weapon(player, {"attack_mode": "drain_link", "weapon_id": "drain_probe", "damage": 80.0, "heal_percent_of_damage": 0.25, "aoe_radius": 200.0, "damage_falloff": 0.72})
	var first := await _make_enemy(holder, player.global_position + Vector2(90.0, 0.0), 500.0)
	var second := await _make_enemy(holder, first.global_position + Vector2(80.0, 0.0), 500.0)
	var hp_before := float(player.get("health"))
	weapon.call("_fire_drain_link", player, first, Vector2.RIGHT)
	if float(second.get("health")) >= 499.0:
		errors.append("Drain extra target did not damage the chained enemy.")
	if float(player.get("health")) <= hp_before:
		errors.append("Drain scenario did not produce real capped healing.")
	_cleanup_player(player)
	first.queue_free()
	second.queue_free()
	await process_frame


func _test_cloud_detonation(holder: Node2D, errors: Array) -> void:
	var player := await _make_player(holder, "chemist", {"cloud_detonation_radius_mult": 0.45})
	var weapon := await _make_weapon(player, {"attack_mode": "aoe_projectile", "weapon_id": "acid_flask", "damage": 80.0, "aoe_radius": 100.0, "pool_element": "poison", "leaves_pool": true, "combo_clouds": true})
	player.call("_apply_weapon_scaling", weapon)
	var old_cloud := Node2D.new()
	var new_cloud := Node2D.new()
	holder.add_child(old_cloud)
	holder.add_child(new_cloud)
	old_cloud.global_position = player.global_position + Vector2(160.0, 0.0)
	new_cloud.global_position = player.global_position + Vector2(170.0, 0.0)
	var far_enemy := await _make_enemy(holder, player.global_position + Vector2(305.0, 0.0), 1000.0)
	weapon.call("_trigger_chemist_combo", new_cloud, old_cloud, 20.0)
	if float(far_enemy.get("health")) >= 999.0:
		errors.append("Cloud detonation radius keystone did not reach a farther real enemy.")
	_cleanup_player(player)
	old_cloud.queue_free()
	new_cloud.queue_free()
	far_enemy.queue_free()
	await process_frame


func _test_pet_buff(holder: Node2D, errors: Array) -> void:
	var player := await _make_player(holder, "druid", {"pet_damage_mult": 0.25})
	var summon := SummonerWeaponScript.new()
	player.add_child(summon)
	await process_frame
	summon.set("weapon_id", "summon_amulet")
	summon.set("damage", 50.0)
	summon.set("damage_multiplier", 1.0)
	var buffed: Dictionary = summon.call("_summon_profile", player)
	var buffed_damage := float(buffed.get("damage", 0.0))
	_cleanup_player(player)

	player = await _make_player(holder, "druid", {"pet_damage_mult": 0.0})
	summon = SummonerWeaponScript.new()
	player.add_child(summon)
	await process_frame
	summon.set("weapon_id", "summon_amulet")
	summon.set("damage", 50.0)
	summon.set("damage_multiplier", 1.0)
	var baseline: Dictionary = summon.call("_summon_profile", player)
	var base_damage := float(baseline.get("damage", 0.0))
	if buffed_damage <= base_damage * 1.15:
		errors.append("Pet damage keystone did not increase live summon profile damage (base %.2f, buffed %.2f)." % [base_damage, buffed_damage])
	_cleanup_player(player)


func _test_downside_outcomes(holder: Node2D, errors: Array) -> void:
	var player := await _make_player(holder, "berserk", {"healing_mult": -0.50})
	player.set("health", float(player.get("max_health")) * 0.25)
	var before := float(player.get("health"))
	player.call("heal_percent", 0.40)
	var reduced_heal := float(player.get("health")) - before
	_cleanup_player(player)
	player = await _make_player(holder, "berserk", {})
	player.set("health", float(player.get("max_health")) * 0.25)
	before = float(player.get("health"))
	player.call("heal_percent", 0.40)
	var full_heal := float(player.get("health")) - before
	if reduced_heal >= full_heal * 0.65:
		errors.append("Healing downside did not reduce real heal_percent output (full %.2f, reduced %.2f)." % [full_heal, reduced_heal])
	_cleanup_player(player)

	player = await _make_player(holder, "thief", {"max_health_mult": -0.15})
	var low_max := float(player.get("max_health"))
	_cleanup_player(player)
	player = await _make_player(holder, "thief", {})
	var full_max := float(player.get("max_health"))
	if low_max >= full_max * 0.92:
		errors.append("Max HP downside did not lower live max_health (full %.2f, low %.2f)." % [full_max, low_max])
	_cleanup_player(player)


func _test_mutation_self_checks(holder: Node2D, errors: Array) -> void:
	var mutation_errors: Array = []
	var on_hit_ok := await _test_on_hit_debuff(holder, mutation_errors, false)
	var gold_ok := await _test_gold_scaling(holder, mutation_errors, false)
	var pierce_ok := await _test_pierce(holder, mutation_errors, false)
	if not (on_hit_ok and gold_ok and pierce_ok):
		errors.append("Mutation/self-check disabled wiring cases failed: %s" % str(mutation_errors))


func _make_player(holder: Node2D, class_id: String, mods: Dictionary) -> Node:
	var player := PLAYER_SCENE.instantiate()
	holder.add_child(player)
	player.global_position = Vector2(600.0, 600.0)
	await process_frame
	player.call("configure_character", class_id)
	if not mods.is_empty():
		player.call("apply_meta_skill_modifiers", mods)
	await process_frame
	return player


func _make_weapon(player: Node, config: Dictionary) -> Node:
	var weapon := ClassWeaponScript.new()
	for key in config.keys():
		weapon.set(str(key), config[key])
	player.add_child(weapon)
	await process_frame
	weapon.call("_capture_base_values")
	player.call("_apply_weapon_scaling", weapon)
	return weapon


func _make_enemy(holder: Node2D, position: Vector2, max_hp: float) -> Node:
	var enemy := ENEMY_SCENE.instantiate()
	enemy.set("max_health", max_hp)
	holder.add_child(enemy)
	enemy.global_position = position
	await process_frame
	enemy.set("max_health", max_hp)
	enemy.set("health", max_hp)
	return enemy


func _weapon_hit_loss(holder: Node2D, player: Node, weapon: Node, override_amount := -1.0) -> float:
	var enemy := await _make_enemy(holder, player.global_position + Vector2(90.0, 0.0), 1000.0)
	var before := float(enemy.get("health"))
	var amount := override_amount if override_amount >= 0.0 else float(weapon.get("damage"))
	weapon.call("_damage_enemy", enemy, amount)
	var loss := before - float(enemy.get("health"))
	enemy.queue_free()
	await process_frame
	return loss


func _param(player: Node, key: String) -> float:
	var params: Dictionary = player.get("derived_parameters")
	return float(params.get(key, 0.0))


func _cleanup_player(player: Node) -> void:
	if player != null and is_instance_valid(player):
		player.queue_free()


func _disable_random_damage_avoidance(player: Node) -> void:
	var params: Dictionary = player.get("derived_parameters")
	params["dodge"] = 0.0
	player.set("derived_parameters", params)
	player.set("_damage_invulnerability_left", 0.0)


func _method_arg_count(obj: Object, method_name: String) -> int:
	for method in obj.get_method_list():
		if str(method.get("name", "")) == method_name:
			return int((method.get("args", []) as Array).size())
	return 0
