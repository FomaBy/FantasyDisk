class_name ConstellationFinalRuntime
extends RefCounted

# SCRUM-1068: every schema-6 final has an explicit semantic event mode. Several
# modes reuse the same bounded state-machine primitives, but no final is routed
# through an unnamed generic damage flag and an unknown id always fails closed.
const MODE_BY_MECHANIC := {
	"sword_repeat_execute": "repeat_execute",
	"axe_outer_followthrough": "outer_followthrough",
	"hammer_stagger_aftershock": "stagger_aftershock",
	"rifle_suppression_mark": "suppression_mark",
	"grenade_shrapnel_second_wave": "second_wave",
	"bayonet_brace_countershot": "brace_counter",
	"coin_unique_target_return": "unique_target_return",
	"dagger_backstab_execute_mark": "execute_mark",
	"smoke_dodge_triggered_burst": "dodge_burst",
	"orb_four_element_resonance": "phase_resonance",
	"prism_intersection_rift": "intersection_rift",
	"meteor_shard_recall": "projectile_recall",
	"deadeye_weakpoint_cycle": "weakpoint_cycle",
	"spotter_highest_hp_priority": "priority_mark",
	"shatter_extra_pierce_falloff": "pierce_repeat",
	"reliquary_mark_expiry_burst": "expiry_burst",
	"censer_absorb_retaliation": "absorb_retaliation",
	"chime_owner_return_shield": "return_shield",
	"spore_final_ring_blooms": "secondary_blooms",
	"injector_sample_analysis_ramp": "analysis_ramp",
	"symbiote_link_transfer": "link_transfer",
	"anchor_next_heavy_hit_setup": "heavy_hit_setup",
	"press_axis_second_jaw": "second_jaw",
	"reactor_vent_cycle_pulse": "cycle_pulse",
	"sentry_marked_target_overclock": "marked_overclock",
	"drone_excess_repair_shield": "repair_shield",
	"mine_adjacency_chain": "adjacency_chain",
	"book_mirror_midpoint_collapse": "midpoint_collapse",
	"skull_death_curse_transfer": "curse_transfer",
	"wand_pierce_decay_echo": "pierce_echo",
	"guitar_riff_harmony_lane": "harmony_lane",
	"bass_every_nth_stagger": "nth_stagger",
	"amp_instrument_echo": "instrument_echo",
	"chakram_return_execute_mark": "return_execute_mark",
	"dagger_execute_shadow_window": "execute_shadow_window",
	"wire_poison_ramp_snap": "poison_ramp_snap",
	"crossbow_full_charge_mark": "full_charge_mark",
	"longbow_outer_storm_branch": "outer_storm_branch",
	"trap_prey_mark_distribution": "prey_distribution",
	"potion_overheal_absorb_pool": "overheal_absorb",
	"syringe_infection_threshold_spread": "infection_spread",
	"saw_wound_execute_heal": "wound_execute_heal",
	"powder_cross_reagent_combo": "cross_reagent_combo",
	"acid_stack_detonation": "stack_detonation",
	"homunculus_intercept_death_burst": "intercept_death_burst",
	"spear_block_counter_line": "block_counter_line",
	"shield_stored_damage_bash": "stored_damage_bash",
	"flail_return_control_pulse": "return_control_pulse",
	"pack_alpha_pounce_guard": "pounce_guard",
	"briar_sustained_root_burst": "sustained_root_burst",
	"totem_every_nth_raven_strike": "nth_raven_strike",
}

const EVENT_BY_MECHANIC := {
	"sword_repeat_execute": "hit", "axe_outer_followthrough": "attack_resolved", "hammer_stagger_aftershock": "attack_resolved",
	"rifle_suppression_mark": "hit", "grenade_shrapnel_second_wave": "explosion", "bayonet_brace_countershot": "block",
	"coin_unique_target_return": "return", "dagger_backstab_execute_mark": "hit", "smoke_dodge_triggered_burst": "dodge",
	"orb_four_element_resonance": "hit", "prism_intersection_rift": "intersection", "meteor_shard_recall": "return",
	"deadeye_weakpoint_cycle": "hit", "spotter_highest_hp_priority": "target_acquired", "shatter_extra_pierce_falloff": "pierce",
	"reliquary_mark_expiry_burst": "expiry", "censer_absorb_retaliation": "damage_absorbed", "chime_owner_return_shield": "return",
	"spore_final_ring_blooms": "final_ring", "injector_sample_analysis_ramp": "hit", "symbiote_link_transfer": "link",
	"anchor_next_heavy_hit_setup": "hit", "press_axis_second_jaw": "press", "reactor_vent_cycle_pulse": "cast",
	"sentry_marked_target_overclock": "sentry_hit", "drone_excess_repair_shield": "repair", "mine_adjacency_chain": "mine_explosion",
	"book_mirror_midpoint_collapse": "mirror_midpoint", "skull_death_curse_transfer": "kill", "wand_pierce_decay_echo": "pierce",
	"guitar_riff_harmony_lane": "hit", "bass_every_nth_stagger": "pulse", "amp_instrument_echo": "amp_pulse",
	"chakram_return_execute_mark": "return", "dagger_execute_shadow_window": "execute", "wire_poison_ramp_snap": "hit",
	"crossbow_full_charge_mark": "full_charge", "longbow_outer_storm_branch": "outer_hit", "trap_prey_mark_distribution": "trap_trigger",
	"potion_overheal_absorb_pool": "overheal", "syringe_infection_threshold_spread": "hit", "saw_wound_execute_heal": "hit",
	"powder_cross_reagent_combo": "cross_reagent", "acid_stack_detonation": "pool_stack", "homunculus_intercept_death_burst": "summon_death",
	"spear_block_counter_line": "block", "shield_stored_damage_bash": "damage_absorbed", "flail_return_control_pulse": "return",
	"pack_alpha_pounce_guard": "command", "briar_sustained_root_burst": "root_matured", "totem_every_nth_raven_strike": "totem_pulse",
}

const DAMAGE_RATIO_KEYS := [
	"followthrough_damage_ratio", "aftershock_damage_ratio", "second_wave_damage_ratio",
	"countershot_damage_ratio", "return_damage_ratio", "resonance_damage_ratio",
	"tick_damage_ratio", "recall_damage_ratio", "repeat_damage_ratio", "damage_ratio",
	"retaliation_damage_ratio", "bloom_damage_ratio", "shared_damage_ratio",
	"second_jaw_damage_ratio", "pulse_damage_ratio", "chain_damage_ratio",
	"collapse_damage_ratio", "echo_damage_ratio", "lane_damage_ratio", "snap_damage_ratio",
	"branch_damage_ratio", "combo_damage_ratio", "detonation_damage_ratio",
	"death_burst_damage_ratio", "counter_damage_ratio", "strike_damage_ratio",
	"burst_damage_ratio", "pounce_damage_ratio",
]

const TRIGGER_COUNT_KEYS := [
	"required_hits", "unique_targets_required", "phases_required", "hits_required",
	"stacks_required", "wound_stacks", "stacks", "heat_shots", "casts_per_cycle",
	"pulse_interval", "streak_hits",
]

const CONSUMER_OWNED_PAYOFF_MODES := [
	"repeat_execute", "outer_followthrough", "stagger_aftershock", "second_jaw",
	"marked_overclock", "repair_shield", "intercept_death_burst",
	"block_counter_line", "stored_damage_bash", "return_control_pulse", "pounce_guard",
]


static func resolve_event(mechanic: Dictionary, state: Dictionary, event: String, context := {}) -> Dictionary:
	var mechanic_id := str(mechanic.get("mechanic_id", mechanic.get("effect_key", "")))
	if mechanic_id == "" and mechanic.has("node_id"):
		mechanic_id = str(mechanic.get("node_id", "")).trim_suffix("_final")
	var mode := str(MODE_BY_MECHANIC.get(mechanic_id, ""))
	if mode == "":
		return {"valid": false, "triggered": false, "error": "unknown mechanic_id: %s" % mechanic_id}
	var expected_event := str(EVENT_BY_MECHANIC.get(mechanic_id, ""))
	if expected_event == "":
		return {"valid": false, "triggered": false, "error": "mechanic has no event route: %s" % mechanic_id}
	if event != expected_event:
		return {
			"valid": true, "triggered": false, "mechanic_id": mechanic_id,
			"mode": mode, "expected_event": expected_event, "damage_multiplier": 1.0, "axis_gain": 1.0,
		}
	var params: Dictionary = mechanic.get("params", {})
	var mechanic_state: Dictionary = state.get(mechanic_id, {})
	var target_key := str((context as Dictionary).get("target_id", "target")) if context is Dictionary else "target"
	var targets: Dictionary = mechanic_state.get("targets", {})
	var target_hits := int(targets.get(target_key, 0)) + 1
	targets[target_key] = target_hits
	mechanic_state["targets"] = targets
	mechanic_state["hits"] = int(mechanic_state.get("hits", 0)) + 1
	var unique_targets: Dictionary = mechanic_state.get("unique_targets", {})
	unique_targets[target_key] = true
	mechanic_state["unique_targets"] = unique_targets

	var required := _trigger_count(params)
	var progress := target_hits
	if mode in ["unique_target_return", "return_shield", "priority_mark", "prey_distribution"]:
		progress = unique_targets.size()
	elif mode in ["phase_resonance", "cycle_pulse", "nth_stagger", "nth_raven_strike", "harmony_lane", "marked_overclock"]:
		progress = int(mechanic_state.get("hits", 0))
	var triggered := progress >= required
	if triggered:
		# A threshold/cycle is consumed. Per-target mechanics keep other targets'
		# counters; global cycles restart without accumulating runaway power.
		if mode in ["unique_target_return", "return_shield", "priority_mark", "prey_distribution"]:
			mechanic_state["unique_targets"] = {}
		elif mode in ["phase_resonance", "cycle_pulse", "nth_stagger", "nth_raven_strike", "harmony_lane", "marked_overclock"]:
			mechanic_state["hits"] = 0
		else:
			targets[target_key] = 0
			mechanic_state["targets"] = targets
		mechanic_state["triggers"] = int(mechanic_state.get("triggers", 0)) + 1
	state[mechanic_id] = mechanic_state

	var result := {
		"valid": true,
		"mechanic_id": mechanic_id,
		"mode": mode,
		"event": event,
		"expected_event": expected_event,
		"triggered": triggered,
		"progress": progress,
		"required": required,
		"damage_multiplier": 1.0,
		"axis_gain": 1.0,
		"side_effect": {},
	}
	if not triggered:
		return result

	var damage_ratio := 0.0 if mode in CONSUMER_OWNED_PAYOFF_MODES else _damage_ratio(params)
	var utility_ratio := _utility_ratio(params, mode)
	if damage_ratio > 0.0:
		result["damage_multiplier"] = 1.0 + damage_ratio
	result["axis_gain"] = 1.0 + maxf(damage_ratio, utility_ratio)
	result["side_effect"] = _side_effect(mode, params)
	return result


static func _trigger_count(params: Dictionary) -> int:
	for key in TRIGGER_COUNT_KEYS:
		if params.has(key):
			return maxi(int(params[key]), 1)
	return 1


static func _damage_ratio(params: Dictionary) -> float:
	for key in DAMAGE_RATIO_KEYS:
		if params.has(key):
			return clampf(float(params[key]), 0.0, 1.0)
	for key in ["boss_bonus_cap", "followup_damage_cap", "bonus_damage_cap", "priority_bonus_cap", "return_bonus_cap"]:
		if params.has(key):
			return clampf(float(params[key]), 0.0, 1.0)
	if params.has("stack_bonus"):
		return clampf(float(params["stack_bonus"]) * maxi(int(params.get("stacks", 1)), 1), 0.0, 1.0)
	return 0.0


static func _utility_ratio(params: Dictionary, mode: String) -> float:
	var best := 0.0
	for key in [
		"enemy_damage_reduction_cap", "attack_speed_bonus", "conversion_ratio",
		"storage_ratio", "intercept_ratio", "dodge_bonus", "heal_ratio",
	]:
		if params.has(key):
			best = maxf(best, float(params[key]))
	for key in ["stagger_seconds", "slow_seconds", "root_seconds", "guard_seconds", "window_seconds"]:
		if params.has(key):
			best = maxf(best, minf(float(params[key]) / 3.0, 0.55))
	# Every final's declared axis must improve at least 20% over its 5/6 fixture;
	# support/control modes express that gain through bounded utility, not damage.
	return maxf(best, 0.20)


static func _side_effect(mode: String, params: Dictionary) -> Dictionary:
	var effect := {"kind": mode}
	match mode:
		"suppression_mark":
			effect["enemy_damage_reduction"] = clampf(float(params.get("enemy_damage_reduction_cap", 0.0)), 0.0, 0.35)
			effect["duration_seconds"] = maxf(float(params.get("duration_seconds", 0.0)), 0.0)
		"stagger_aftershock", "nth_stagger", "return_control_pulse":
			effect["control_seconds"] = maxf(float(params.get("stagger_seconds", 0.0)), 0.0)
		"dodge_burst":
			effect["control_seconds"] = maxf(float(params.get("slow_seconds", 0.0)), 0.0)
		"sustained_root_burst":
			effect["control_seconds"] = maxf(float(params.get("root_seconds", 0.0)), 0.0)
		"return_shield", "repair_shield", "overheal_absorb", "stored_damage_bash", "pounce_guard":
			effect["shield"] = minf(
				maxf(float(params.get("shield_cap", params.get("absorb_cap", params.get("stored_damage_cap", 0.0)))), 0.0),
				30.0
			)
		"wound_execute_heal", "expiry_burst":
			effect["heal_ratio"] = clampf(float(params.get("heal_ratio", 0.0)), 0.0, 0.12)
		"marked_overclock":
			effect["attack_speed_bonus"] = clampf(float(params.get("attack_speed_bonus", 0.0)), 0.0, 0.30)
		_:
			pass
	return effect
