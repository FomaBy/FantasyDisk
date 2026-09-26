class_name PlayerProgressionRuntime
extends RefCounted

## FAN-3921 (FD14): run progression and reward state transitions, extracted
## from Player as a collaborator (no inheritance, no owned state). The Player
## node keeps every state field (stats, run_modifiers, artifacts, xp, level,
## money, derived_parameters, health), its signals and node-tree effects; this
## runtime applies the documented transitions in their original order and
## reaches back into the same Player helpers (heal, weapon lookup, meta and
## constellation multipliers, leveled_up) at the same pipeline positions, so
## observable ordering — including the single cross-class shuffle on the global
## RNG — is unchanged. Save representation is untouched: the snapshot readers
## (combat_director, main autosave) keep reading the same Player fields.

const ProgressionData := preload("res://scripts/progression_data.gd")

# Combat subset of the meta skill-tree modifiers (SCRUM-150): summed
# META_PROGRESSION.skill_modifiers land in run_modifiers as a permanent run
# bonus on top of ascension rewards. Economy/meta flags of the tree (gold,
# prices, rerolls, death_save) are applied at run/UI level, not here.
const META_SKILL_MULT_MAP := {
	"damage_mult": "damage_multiplier",
	"attack_speed_mult": "attack_speed_multiplier",
	"move_speed_mult": "move_speed_multiplier",
	"max_health_mult": "max_health_multiplier",
	"aoe_radius_mult": "aoe_radius_multiplier",
	"knockback_mult": "knockback_multiplier",
	"xp_gain_mult": "xp_gain_multiplier",
	"money_gain_mult": "money_gain_multiplier",
	"ult_charge_mult": "ult_charge_multiplier",
	"elite_boss_damage_mult": "elite_boss_damage_multiplier",
	# SCRUM-828 (Meta 4.0): healing as a keystone trade-off lever (Atlas
	# pharmacy +, berserk «Кровавый танец» −). healing_multiplier is consumed by
	# _apply_regeneration and the heal flows.
	"healing_mult": "healing_multiplier",
	# Class progression (SCRUM-360): bonuses of the current class only (main
	# forwards them for the selected class); they multiply with the account
	# bonuses on the same run modifier.
	"class_damage_mult": "damage_multiplier",
	"class_attack_speed_mult": "attack_speed_multiplier",
	"class_max_health_mult": "max_health_multiplier",
}
const META_SKILL_FLAT_MAP := {
	"defense_flat": "defense_flat",
	"dodge_flat": "dodge_flat",
	"regeneration_flat": "regeneration_flat",
	"crit_chance_flat": "crit_chance_flat",
	"crit_damage_flat": "crit_damage_flat",
	"dot_damage_flat": "dot_damage_flat",
	"vampiric_chance_flat": "vampiric_chance_flat",
	"vampiric_amount_flat": "vampiric_amount_flat",
	"summon_bonus": "summon_bonus",
	"ultimate_flat": "ultimate_flat",
	"low_hp_damage_bonus": "low_hp_damage_bonus",
	"lowhp_regen_bonus": "lowhp_regen_bonus",
	# SCRUM-807: split under the class branches of Skill Tree 3.0 (same run
	# keys the level-up flow uses — progression_data.derived_parameters).
	"pickup_radius_flat": "pickup_radius_flat",
	"absorb_flat": "absorb_flat",
	# SCRUM-828 (Meta 4.0): technique stars and hidden constellation stars. All
	# keys are already consumed by the player.gd artifact triggers (SCRUM-500):
	# kill explosion, counter-wave, thorns, crit/dodge dashes.
	"kill_explosion_chance": "kill_explosion_chance",
	"take_hit_pulse_chance": "take_hit_pulse_chance",
	"thorn_reflect_multiplier": "thorn_reflect_multiplier",
	"crit_speed_burst": "crit_speed_burst",
	"dodge_rush_bonus": "dodge_rush_bonus",
	# SCRUM-834 (Meta 4.1): conditional keystones — a damage bonus active only
	# while its condition holds. Stored as a run bonus; the gates
	# (*_active/fraction) are set by _update_conditional_keystones /
	# _trigger_rush_window and consumed by derived_parameters
	# (damage_multiplier).
	"hurt_damage_bonus": "hurt_damage_bonus",
	"stance_damage_bonus": "stance_damage_bonus",
	"rush_damage_bonus": "rush_damage_bonus",
	"swarm_damage_bonus": "swarm_damage_bonus",
	# SCRUM-834a: conditional keystones on the EXISTING gates but with a
	# non-damage stat target (same stance_active/rush_window_active flag).
	# stance → attack speed (soldier «Шквал»), rush → crit chance (thief «Из
	# тени»). Consumed by derived_parameters.
	"stance_attack_speed_bonus": "stance_attack_speed_bonus",
	"rush_crit_bonus": "rush_crit_bonus",
	# SCRUM-835 (Meta 4.1b): semantic keystone keys, consumed by the meta_*
	# helpers of player.gd/class_weapon.gd so effects bind to the combat
	# subsystem instead of a generic damage gate.
	"enemy_hit_damage_down": "enemy_hit_damage_down",
	"gold_damage_per_50": "gold_damage_per_50",
	"gold_damage_bonus_cap": "gold_damage_bonus_cap",
	"elemental_resonance_bonus": "elemental_resonance_bonus",
	"elemental_orb_extra_count": "elemental_orb_extra_count",
	"prism_rift_radius_mult": "prism_rift_radius_mult",
	"heal_to_holy_damage_ratio": "heal_to_holy_damage_ratio",
	"ward_absorb_bonus": "ward_absorb_bonus",
	"reactor_heat_damage_bonus": "reactor_heat_damage_bonus",
	"reactor_heat_incoming_damage": "reactor_heat_incoming_damage",
	"magnet_radius_mult": "magnet_radius_mult",
	"device_attack_speed_bonus": "device_attack_speed_bonus",
	"non_device_damage_mult": "non_device_damage_mult",
	"mine_extra_count": "mine_extra_count",
	"dot_death_spread_duration": "dot_death_spread_duration",
	"direct_damage_mult": "direct_damage_mult",
	"beam_duration_mult": "beam_duration_mult",
	"explosion_radius_mult": "explosion_radius_mult",
	"guitar_aura_radius_mult": "guitar_aura_radius_mult",
	"riff_streak_damage_bonus": "riff_streak_damage_bonus",
	"crit_execute_threshold": "crit_execute_threshold",
	"shadow_burst_invisibility_time": "shadow_burst_invisibility_time",
	"charged_shot_extra_pierce": "charged_shot_extra_pierce",
	"charge_time_mult": "charge_time_mult",
	"trap_extra_count": "trap_extra_count",
	"non_trap_damage_mult": "non_trap_damage_mult",
	"drain_extra_targets": "drain_extra_targets",
	"medkit_healing_mult": "medkit_healing_mult",
	"surgical_close_damage_bonus": "surgical_close_damage_bonus",
	"ranged_damage_mult": "ranged_damage_mult",
	"cloud_detonation_radius_mult": "cloud_detonation_radius_mult",
	"pool_duration_mult": "pool_duration_mult",
	"homunculus_power_mult": "homunculus_power_mult",
	"pet_damage_mult": "pet_damage_mult",
	"pet_personal_damage_mult": "pet_personal_damage_mult",
	"briar_radius_mult": "briar_radius_mult",
	"bastion_defense_bonus": "bastion_defense_bonus",
	"bastion_taunt": "bastion_taunt",
	# SCRUM-1069 Guild Atlas: bounded once-per-run recovery share.
	"death_save_health_fraction": "death_save_health_fraction",
}
const META_SKILL_ATTRIBUTE_FLAT_MAP := {
	"strength_flat": "strength",
	"agility_flat": "agility",
	"intelligence_flat": "intelligence",
	"perception_flat": "perception",
	"energy_flat": "energy",
	"knowledge_flat": "knowledge",
	"endurance_flat": "endurance",
	"leadership_flat": "leadership",
}


## SCRUM-709: the single source of default run_modifiers. The Player var
## initializer and configure_character both read this, so a new key cannot
## silently drift between the two (the old duplicated literal did).
static func default_run_modifiers() -> Dictionary:
	return {
		"damage_multiplier": 1.0,
		"magic_damage_multiplier": 1.0,
		"attack_speed_multiplier": 1.0,
		# SCRUM-976: separate final layer outside the release-balance softcap.
		"sandbox_player_damage_multiplier": 1.0,
		"sandbox_player_attack_speed_multiplier": 1.0,
		"aoe_radius_multiplier": 1.0,
		"move_speed_multiplier": 1.0,
		"max_health_multiplier": 1.0,
		"summon_bonus": 0.0,
		"damage_flat": 0.0,
		"max_health_flat": 0.0,
		"pickup_radius_flat": 0.0,
		"defense_flat": 0.0,
		"crit_chance_flat": 0.0,
		"crit_damage_flat": 0.0,
		"kill_momentum_stacks": 0.0,
		"kill_momentum_attack_speed_bonus": 0.0,
		"kill_momentum_crit_damage_bonus": 0.0,
		"dodge_flat": 0.0,
		"xp_gain_multiplier": 1.0,
		"money_gain_multiplier": 1.0,
		"ult_charge_multiplier": 1.0,
		"elite_boss_damage_multiplier": 1.0,
		"healing_multiplier": 1.0,
		"vampiric_heal_per_second_cap": ProgressionData.VAMPIRIC_HEAL_CAP_DEFAULT,
		"drain_heal_per_second_cap": ProgressionData.BalanceData.DRAIN_HEAL_PER_SECOND_CAP_DEFAULT,
		"enemy_health_multiplier": 1.0,
		"knockback_multiplier": 1.0,
	}


## Fresh-run progression state for configure_character: base stats of the
## current class, no artifacts, default run modifiers, level 1 with the
## initial 5-xp threshold and an empty wallet. Runtime latches and the
## ultimate ledger stay with Player, which resets them around this call.
static func reset_run_state(player) -> void:
	player.stats = ProgressionData.base_stats(player.character_id)
	player.artifacts.clear()
	player.run_modifiers = default_run_modifiers()
	player.xp = 0
	player.xp_to_next = 5
	player.level = 1
	player.money = 0


## XP with the run multiplier (at least 1 per pickup). Each threshold crossed
## raises the level, advances xp_to_next along ProgressionData's curve and
## emits leveled_up immediately, so a listener sees the level of that step.
static func gain_xp(player, amount: int) -> void:
	player.xp += maxi(1, int(round(float(amount) * float(player.run_modifiers.get("xp_gain_multiplier", 1.0)))))
	while player.xp >= player.xp_to_next:
		player.xp -= player.xp_to_next
		player.level += 1
		player.xp_to_next = ProgressionData.next_xp_requirement(player.xp_to_next)
		player.leveled_up.emit()


## Gold with the run multiplier (at least 1 per pickup). SCRUM-502: the
## per-run "gold collected" accumulator for the results screen lives on the
## current scene (Main), which receives the gained amount, not the wallet.
static func gain_money(player, amount: int) -> void:
	var gained := maxi(1, int(round(float(amount) * float(player.run_modifiers.get("money_gain_multiplier", 1.0)))))
	player.money += gained
	if player.is_inside_tree():
		var game_node: Node = player.get_tree().current_scene
		if game_node != null and game_node.has_method("add_run_gold_collected"):
			game_node.add_run_gold_collected(gained)


static func spend_money(player, amount: int) -> bool:
	if player.money < amount:
		return false
	player.money -= amount
	return true


## Reward pipeline, in the original order: stat deltas, mods (plus the
## SCRUM-961 cross-class roll), affinity mods, the artifact entry, stat
## rescale with max-health carry-over, the gated heal, then weapon rescale.
static func apply_reward(player, reward: Dictionary) -> void:
	var old_max_health: float = player.max_health

	if reward.has("stats"):
		for stat_id in reward["stats"].keys():
			player.stats[stat_id] = float(player.stats.get(stat_id, 0.0)) + float(reward["stats"][stat_id])

	# SCRUM-900: an explicit doctor_friendly mark lets the item's sustain mods
	# through the «Клятва чумного доктора» gate (see apply_reward_mods).
	var reward_doctor_friendly := bool(reward.get("doctor_friendly", false))
	if reward.has("mods"):
		apply_reward_mods(player, reward["mods"], reward_doctor_friendly)
		# SCRUM-961 «Украденный герб» (§5): slots roll foreign class ids for the run.
		if float((reward.get("mods") as Dictionary).get("cross_class_artifact_slots", 0.0)) > 0.0:
			roll_cross_class_artifacts(player, int(float((reward.get("mods") as Dictionary).get("cross_class_artifact_slots", 0.0))))
	if reward.has("affinity_mods"):
		# Since 0.2 affinity_mods no longer vanish for a "foreign" class: they
		# are the universal reading of the artifact through the current kit.
		apply_reward_mods(player, reward["affinity_mods"], reward_doctor_friendly)

	if reward.get("kind", "") == "artifact":
		# Store id and title: the id drives HUD/pause icons, the title the texts.
		# SCRUM-960: plus the optional tier of the materialized offer (rarity for
		# UI). Legacy {id, title} entries without tier stay valid — readers use
		# .get("tier", 0), 0 = do not show.
		var artifact_entry := {"id": str(reward.get("id", "")), "title": str(reward.get("title", "")), "description": str(reward.get("description", ""))}
		var reward_tier := int(reward.get("tier", 0))
		if reward_tier > 0:
			artifact_entry["tier"] = reward_tier
		player.artifacts.append(artifact_entry)

	apply_stat_scaling(player, false, old_max_health)

	if reward.has("heal_percent"):
		# SCRUM-900: a direct reward heal is generic sustain; «Клятва чумного
		# доктора» cancels it (except explicitly doctor_friendly items).
		# Route/rest/shop healing outside apply_reward is untouched.
		if not player.blocks_generic_sustain() or reward_doctor_friendly:
			player.heal_percent(float(reward["heal_percent"]))

	for weapon in player._equipped_weapons():
		apply_weapon_scaling(player, weapon)


## SCRUM-900: allow_generic_sustain=true (doctor_friendly reward) passes
## sustain mods into the ordinary run keys. Without it the forbidden keys
## (ProgressionData.is_blocked_sustain_mod_key) are NOT applied for a class
## with the plague_oath trait: reward regen/vampirism/trigger heals become a
## documented no-op (AC SCRUM-900). Removed legacy axes are always skipped.
static func apply_reward_mods(player, mods: Dictionary, allow_generic_sustain := false) -> void:
	var sustain_blocked: bool = player.blocks_generic_sustain() and not allow_generic_sustain
	for modifier_id in mods.keys():
		if ProgressionData.is_removed_progression_modifier(str(modifier_id)):
			continue
		if sustain_blocked and ProgressionData.is_blocked_sustain_mod_key(str(modifier_id)):
			continue
		if modifier_id.ends_with("_multiplier"):
			player.run_modifiers[modifier_id] = float(player.run_modifiers.get(modifier_id, 1.0)) * float(mods[modifier_id])
		else:
			player.run_modifiers[modifier_id] = float(player.run_modifiers.get(modifier_id, 0.0)) + float(mods[modifier_id])


## SCRUM-961 «Украденный герб» (artifact_system_matrix §5): roll N random
## FOREIGN class artifacts for this run — uniform, no duplicates. The Array is
## written into run_modifiers DIRECTLY (not through apply_reward_mods, which
## coerces to float); it lives until the end of the run (run_modifiers are
## recreated in configure_character) and the samplers read it as the
## cross_class_ids parameter (§1.4). The single shuffle is the only RNG call.
static func roll_cross_class_artifacts(player, slots: int) -> void:
	var existing_raw = player.run_modifiers.get("cross_class_artifact_ids", [])
	var rolled: Array = (existing_raw as Array).duplicate() if existing_raw is Array else []
	var candidates: Array = []
	for artifact in ProgressionData.ARTIFACTS:
		var affinity: Array = (artifact as Dictionary).get("class_affinity", []) as Array
		if affinity.is_empty() or affinity.has(player.character_id):
			continue
		var artifact_id := str((artifact as Dictionary).get("id", ""))
		if not rolled.has(artifact_id):
			candidates.append(artifact_id)
	candidates.shuffle()
	for index in range(mini(slots, candidates.size())):
		rolled.append(candidates[index])
	player.run_modifiers["cross_class_artifact_ids"] = rolled


## Meta skill-tree modifiers: attribute flats into stats, mult keys as
## (1 + value) factors, flat keys added (sustain keys gated by plague_oath),
## stat/weapon rescale, then the capstone side effects.
static func apply_meta_skill_modifiers(player, mods: Dictionary) -> void:
	var old_max_health: float = player.max_health
	# SCRUM-900 «Клятва чумного доктора»: the meta tree is a generic source too;
	# regen/vampirism/low-HP regen stars do not apply to the trait class
	# (documented no-op, as with the reward pool).
	var sustain_blocked: bool = player.blocks_generic_sustain()
	for key in META_SKILL_ATTRIBUTE_FLAT_MAP:
		if mods.has(key):
			var stat_key: String = META_SKILL_ATTRIBUTE_FLAT_MAP[key]
			player.stats[stat_key] = float(player.stats.get(stat_key, 0.0)) + float(mods[key])
	for key in META_SKILL_MULT_MAP:
		if mods.has(key):
			var run_key: String = META_SKILL_MULT_MAP[key]
			# Tree values are shares (+0.06); the multiplier is 1.0 + sum.
			player.run_modifiers[run_key] = float(player.run_modifiers.get(run_key, 1.0)) * (1.0 + float(mods[key]))
	for key in META_SKILL_FLAT_MAP:
		if mods.has(key):
			var run_key: String = META_SKILL_FLAT_MAP[key]
			if sustain_blocked and ProgressionData.is_blocked_sustain_mod_key(run_key):
				continue
			player.run_modifiers[run_key] = float(player.run_modifiers.get(run_key, 0.0)) + float(mods[key])
	apply_stat_scaling(player, false, old_max_health)
	for weapon in player._equipped_weapons():
		apply_weapon_scaling(player, weapon)
	# Capstone «Боевой раж»: the ultimate starts partially charged.
	var start_charge := float(mods.get("ult_start_charge", 0.0))
	if start_charge > 0.0:
		player.ultimate_charge = clampf(player.ultimate_max_charge * start_charge, 0.0, player.ultimate_max_charge)
	# Capstone «Вторая жизнь»: death-save flag (the logic lives in take_damage).
	if float(mods.get("death_save", 0.0)) > 0.0:
		player.run_modifiers["death_save"] = 1.0
	# SCRUM-828: hidden "shield wave at low HP" stars (same mechanic as the
	# «Рубеж Стража» artifact — _trigger_lowhp_guard, recharge per threshold).
	if float(mods.get("lowhp_guard", 0.0)) > 0.0:
		player.run_modifiers["lowhp_guard"] = 1.0


## Derived parameters from stats/run_modifiers/weapon_config, then the cached
## speed/max_health/pickup_radius. Health is refilled on a full heal or when
## empty; otherwise it grows by the max-health delta and is clamped.
static func apply_stat_scaling(player, full_heal := false, old_max_health := 0.0) -> void:
	player.derived_parameters = ProgressionData.derived_parameters(player.stats, player.run_modifiers, player.weapon_config)
	player.speed = float(player.derived_parameters.get("move_speed", 235.0))
	player.max_health = float(player.derived_parameters.get("health_point", 88.0))
	player.pickup_radius = float(player.derived_parameters.get("pickup_radius", 115.0))

	if full_heal or player.health <= 0.0:
		player.health = player.max_health
	else:
		player.health = min(player.max_health, player.health + max(player.max_health - old_max_health, 0.0))


## Rescale a weapon node from the captured base_* metas, the derived
## parameters and the Player meta/constellation multipliers.
static func apply_weapon_scaling(player, weapon: Node) -> void:
	capture_weapon_base_values(weapon)
	var derived_parameters: Dictionary = player.derived_parameters
	var run_modifiers: Dictionary = player.run_modifiers
	var weapon_config: Dictionary = player.weapon_config
	var meta_context: Dictionary = player.meta_context_for_weapon(weapon)
	var weapon_id_value := str(meta_context.get("weapon_id", ""))
	var constellation_attack_speed: float = player.constellation_weapon_multiplier(weapon_id_value, "weapon_attack_speed_mult")
	var constellation_geometry: float = player.constellation_weapon_geometry_multiplier(weapon_id_value)
	var geometry_capabilities: Array = weapon_config.get("geometry_capabilities", [])
	var attack_area_multiplier := float(derived_parameters.get("attack_area_multiplier", 1.0)) * constellation_geometry

	if weapon.get("damage") != null:
		var damage_parameter := "damage"
		if weapon.get("damage_parameter") != null:
			damage_parameter = str(weapon.get("damage_parameter"))
		var scaled_damage := float(derived_parameters.get(damage_parameter, weapon.get_meta("base_damage")))
		scaled_damage += player.constellation_weapon_amount(weapon_id_value, "weapon_damage_flat")
		weapon.set("damage", scaled_damage)

	if weapon.get("fire_interval") != null:
		var attack_speed := float(derived_parameters.get("attack_speed", 1.0))
		var base_fire_interval := float(weapon.get_meta("base_fire_interval", 1.0))
		weapon.set("fire_interval", max(0.18, (base_fire_interval / max(attack_speed * constellation_attack_speed, 0.1)) * player.meta_interval_multiplier(meta_context)))

	var cadence := maxf(float(derived_parameters.get("attack_cadence_multiplier", 1.0)), 0.1)
	AttributeContract.apply_weapon_cadence(weapon, cadence, player.meta_interval_multiplier(meta_context))
	if weapon.has_method("refresh_persistent_status_cadence"):
		weapon.call("refresh_persistent_status_cadence")

	# SummonerWeapon historically ignores canonical derived attack speed. Preserve
	# that neutral release behaviour and apply only SCRUM-976's explicit factor.
	if weapon.get("summon_interval") != null:
		var summon_attack_speed := clampf(float(run_modifiers.get("sandbox_player_attack_speed_multiplier", 1.0)), 0.5, 2.0)
		var base_summon_interval := float(weapon.get_meta("base_summon_interval", weapon.get("summon_interval")))
		weapon.set("summon_interval", maxf(0.18, base_summon_interval / maxf(summon_attack_speed * constellation_attack_speed, 0.1)))
	if weapon.get("summon_attack_interval") != null:
		var unit_attack_speed := clampf(float(run_modifiers.get("sandbox_player_attack_speed_multiplier", 1.0)), 0.5, 2.0)
		var base_summon_attack_interval := float(weapon.get_meta("base_summon_attack_interval", weapon.get("summon_attack_interval")))
		weapon.set("summon_attack_interval", maxf(0.18, base_summon_attack_interval / maxf(unit_attack_speed * constellation_attack_speed, 0.1)))

	if weapon.get("attack_range") != null:
		var base_attack_range := float(weapon.get_meta("base_attack_range"))
		weapon.set("attack_range", base_attack_range * constellation_geometry)

	if geometry_capabilities.has("aoe_radius"):
		var radius_property := "aoe_radius" if weapon.get("aoe_radius") != null else "summon_aoe_radius"
		if weapon.get(radius_property) != null:
			var base_radius := float(weapon.get_meta("base_%s" % radius_property, 200.0))
			weapon.set(radius_property, base_radius * attack_area_multiplier * player.meta_radius_multiplier(meta_context))
	if geometry_capabilities.has("inner_width") and weapon.get("inner_width") != null:
		weapon.set("inner_width", float(weapon.get_meta("base_inner_width")) * attack_area_multiplier)
	if geometry_capabilities.has("outer_width") and weapon.get("outer_width") != null:
		weapon.set("outer_width", float(weapon.get_meta("base_outer_width")) * attack_area_multiplier)

	if geometry_capabilities.has("sweep_degrees") and weapon.get("sweep_degrees") != null:
		var base_sweep_degrees := float(weapon.get_meta("base_sweep_degrees", weapon.get("sweep_degrees")))
		weapon.set("sweep_degrees", clampf(base_sweep_degrees * attack_area_multiplier, 1.0, 360.0))
	if geometry_capabilities.has("cone_degrees") and weapon.get("cone_degrees") != null:
		weapon.set("cone_degrees", clampf(float(weapon.get_meta("base_cone_degrees")) * attack_area_multiplier, 1.0, 360.0))

	if weapon.get("projectile_speed") != null:
		weapon.set("projectile_speed", float(weapon.get_meta("base_projectile_speed", 520.0)))

	if weapon.get("knockback") != null:
		var control_multiplier: float = player.constellation_weapon_multiplier(weapon_id_value, "control_sustain_value_mult") * player.constellation_weapon_multiplier(weapon_id_value, "hidden_defense_mastery_mult")
		weapon.set("knockback", float(derived_parameters.get("knockback_power", weapon.get_meta("base_knockback", 80.0))) * player.meta_knockback_multiplier(meta_context) * control_multiplier)

	if weapon.get("pool_duration") != null and weapon.has_meta("base_pool_duration"):
		weapon.set("pool_duration", maxf(0.2, float(weapon.get_meta("base_pool_duration")) * player.meta_duration_multiplier(meta_context)))

	if weapon.get("orbit_duration") != null and weapon.has_meta("base_orbit_duration"):
		weapon.set("orbit_duration", maxf(0.2, float(weapon.get_meta("base_orbit_duration")) * player.meta_duration_multiplier(meta_context)))

	if weapon.get("charge_seconds") != null and weapon.has_meta("base_charge_seconds"):
		var charge_context := meta_context.duplicate(true)
		charge_context["charge_seconds"] = float(weapon.get_meta("base_charge_seconds"))
		charge_context["is_charged"] = float(weapon.get_meta("base_charge_seconds")) > 0.0
		weapon.set("charge_seconds", maxf(0.0, float(weapon.get_meta("base_charge_seconds")) * player.meta_charge_time_multiplier(charge_context)))

	if geometry_capabilities.has("beam_width") and weapon.get("beam_width") != null and weapon.has_meta("base_beam_width"):
		weapon.set("beam_width", float(weapon.get_meta("base_beam_width")) * attack_area_multiplier)

	if geometry_capabilities.has("wave_width") and weapon.get("wave_width") != null and weapon.has_meta("base_wave_width"):
		weapon.set("wave_width", float(weapon.get_meta("base_wave_width")) * attack_area_multiplier)

	if geometry_capabilities.has("suppression_width") and weapon.get("suppression_width") != null and weapon.has_meta("base_suppression_width"):
		weapon.set("suppression_width", float(weapon.get_meta("base_suppression_width")) * attack_area_multiplier)

	if weapon.get("max_summons") != null:
		# FAN-2249: the declared summon_semantics of the config picks the park
		# branch, not a second attack_mode list; the "ordinary" branch has a
		# single formula, AttributeContract.summon_runtime_count, so runtime and
		# presentation (cards/dossier/advisor) cannot diverge.
		if AttributeContract.weapon_summon_semantics(weapon_config) == "device":
			# SCRUM-905/906: Engineer devices size their park in the kit from
			# summon_amount (ClassWeapon._engineer_turret_limit /
			# _engineer_drone_target_count mirror the budget; «Полевой чертеж»
			# is added there on top of the rail). A generic Leadership scale here
			# would DOUBLE count the park (Leadership is already in summon_amount)
			# and break the documented thresholds (base: 2 turrets, EXACTLY 1
			# drone — AC SCRUM-906).
			weapon.set("max_summons", int(weapon.get_meta("base_max_summons")))
		else:
			weapon.set("max_summons", int(AttributeContract.summon_runtime_count(weapon_config, player.stats, run_modifiers)))


## Capture each scalable field once as a base_* meta so repeated rescales
## stay idempotent.
static func capture_weapon_base_values(weapon: Node) -> void:
	if weapon.get("damage") != null and not weapon.has_meta("base_damage"):
		weapon.set_meta("base_damage", weapon.get("damage"))
	if weapon.get("fire_interval") != null and not weapon.has_meta("base_fire_interval"):
		weapon.set_meta("base_fire_interval", weapon.get("fire_interval"))
	if weapon.get("summon_interval") != null and not weapon.has_meta("base_summon_interval"):
		weapon.set_meta("base_summon_interval", weapon.get("summon_interval"))
	if weapon.get("summon_attack_interval") != null and not weapon.has_meta("base_summon_attack_interval"):
		weapon.set_meta("base_summon_attack_interval", weapon.get("summon_attack_interval"))
	if weapon.get("attack_range") != null and not weapon.has_meta("base_attack_range"):
		weapon.set_meta("base_attack_range", weapon.get("attack_range"))
	if weapon.get("aoe_radius") != null and not weapon.has_meta("base_aoe_radius"):
		weapon.set_meta("base_aoe_radius", weapon.get("aoe_radius"))
	if weapon.get("summon_aoe_radius") != null and not weapon.has_meta("base_summon_aoe_radius"):
		weapon.set_meta("base_summon_aoe_radius", weapon.get("summon_aoe_radius"))
	if weapon.get("sweep_degrees") != null and not weapon.has_meta("base_sweep_degrees"):
		weapon.set_meta("base_sweep_degrees", weapon.get("sweep_degrees"))
	if weapon.get("cone_degrees") != null and not weapon.has_meta("base_cone_degrees"):
		weapon.set_meta("base_cone_degrees", weapon.get("cone_degrees"))
	if weapon.get("inner_width") != null and not weapon.has_meta("base_inner_width"):
		weapon.set_meta("base_inner_width", weapon.get("inner_width"))
	if weapon.get("outer_width") != null and not weapon.has_meta("base_outer_width"):
		weapon.set_meta("base_outer_width", weapon.get("outer_width"))
	if weapon.get("max_summons") != null and not weapon.has_meta("base_max_summons"):
		weapon.set_meta("base_max_summons", weapon.get("max_summons"))
	if weapon.get("projectile_speed") != null and not weapon.has_meta("base_projectile_speed"):
		weapon.set_meta("base_projectile_speed", weapon.get("projectile_speed"))
	if weapon.get("beam_width") != null and not weapon.has_meta("base_beam_width"):
		weapon.set_meta("base_beam_width", weapon.get("beam_width"))
	if weapon.get("wave_width") != null and not weapon.has_meta("base_wave_width"):
		weapon.set_meta("base_wave_width", weapon.get("wave_width"))
	if weapon.get("knockback") != null and not weapon.has_meta("base_knockback"):
		weapon.set_meta("base_knockback", weapon.get("knockback"))
	if weapon.get("amp_pulse_interval") != null and not weapon.has_meta("base_amp_pulse_interval"):
		weapon.set_meta("base_amp_pulse_interval", weapon.get("amp_pulse_interval"))
	if weapon.get("pool_tick_interval") != null and not weapon.has_meta("base_pool_tick_interval"):
		weapon.set_meta("base_pool_tick_interval", weapon.get("pool_tick_interval"))
	if weapon.get("pool_duration") != null and not weapon.has_meta("base_pool_duration"):
		weapon.set_meta("base_pool_duration", weapon.get("pool_duration"))
	if weapon.get("orbit_duration") != null and not weapon.has_meta("base_orbit_duration"):
		weapon.set_meta("base_orbit_duration", weapon.get("orbit_duration"))
	if weapon.get("charge_seconds") != null and not weapon.has_meta("base_charge_seconds"):
		weapon.set_meta("base_charge_seconds", weapon.get("charge_seconds"))
