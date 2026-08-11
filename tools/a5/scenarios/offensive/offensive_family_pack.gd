extends RefCounted

# FAN-1512: standalone A5 offensive-family contract.  The roster is derived
# from production data so a new runtime pair cannot silently escape coverage.

const PACK_ID := "a5_offensive_family"
const PACK_CONTRACT := "a5.scenario-pack.v1"
const MATRIX_SCHEMA := "fan1512.pair-family-event.v1"
const FRAGMENT_SCHEMA := "fan1512.a5-offensive-fragment.v1"
const FRAGMENT_DIR := "res://docs/design/reports/fan1438_a5_balance/fragments/offensive"
const FRAGMENT_PATH := FRAGMENT_DIR + "/offensive_family_ab.json"
const FORMULA_LIVE_TOLERANCE_PCT := 35.0
const SEEDS := [151201]
const WARMUP_SECONDS := 2.0
const WINDOW_SECONDS := 6.0
const TARGET_COUNT := 10
const DUMMY_HP := 1.0e9

const FAMILIES := ["direct", "projectile", "beam", "chain", "area"]
const REPRESENTATIVE_PAIRS := {
	"direct": "berserk/sword",
	"projectile": "sniper/sniper_deadeye_rifle",
	"beam": "assassin/venom_wire",
	"chain": "dark_mage/dark_wand",
	"area": "chemist/blast_powder",
}
const DIRECT_MODES := ["frustum", "sweep", "circle", "strip", "bayonet_cone", "stab_flurry", "saw_sector", "arquebus_shot", "bayonet_auto_shot", "shadow_backstab"]
const CHAIN_MODES := ["dark_chain_burst", "coin_ricochet", "moon_split_shot", "sniper_split_round"]
const BEAM_MODES := ["beam", "boomerang", "dot_beam", "drain_link", "prism_rift", "robot_compression_line", "storm_pierce_cone", "riff_strip", "sound_wave", "robot_reactor_vent"]
const AREA_MODES := ["aoe_projectile", "grenade_fuse", "skull_curse_burn", "dark_mirror_blast", "meteor_shards", "sniper_kill_zone", "pulse", "amp", "trap", "smoke_bomb", "elemental_orbit", "priest_sanctify", "priest_ward", "priest_dual_toll", "bio_spore_bloom", "bio_symbiote_web", "robot_magnetic_anchor", "engineer_pressure_mines"]


static func contract() -> Dictionary:
	return {
		"pack_id": PACK_ID,
		"pack_contract": PACK_CONTRACT,
		"matrix_schema": MATRIX_SCHEMA,
		"fragment_schema": FRAGMENT_SCHEMA,
		"formula_live_tolerance_pct": FORMULA_LIVE_TOLERANCE_PCT,
		"seeds": SEEDS,
		"geometry_coverage": ["80px", "formula_expected_distance", "practical_range", "forward", "diagonal", "reverse", "solo", "pack"],
	}


static func pair_key(entry: Dictionary) -> String:
	return "%s/%s" % [entry.get("class_id", ""), entry.get("weapon_id", "")]


static func family_for_config(config: Dictionary) -> String:
	if int(config.get("max_summons", 0)) > 0 or str(config.get("summon_semantics", "none")) != "none":
		return "area"
	var mode := str(config.get("attack_mode", config.get("attack_shape", "")))
	if DIRECT_MODES.has(mode):
		return "direct"
	if CHAIN_MODES.has(mode):
		return "chain"
	if BEAM_MODES.has(mode):
		return "beam"
	if AREA_MODES.has(mode):
		return "area"
	if ["plague_dart", "homing_curse", "sniper_lockshot", "bio_sample_dart"].has(mode):
		return "projectile"
	return ""


static func geometry_for(family: String, config: Dictionary) -> Dictionary:
	var attack_range := maxf(float(config.get("attack_range", 80.0)), 80.0)
	match family:
		"direct":
			return {"name": "minimum_80px", "distance": 80.0, "orientation": "forward", "layout": "solo"}
		"projectile":
			return {"name": "formula_expected_distance", "distance": maxf(80.0, attack_range * 0.50), "orientation": "diagonal", "layout": "pack"}
		"beam":
			return {"name": "practical_range", "distance": maxf(80.0, attack_range * 0.85), "orientation": "reverse", "layout": "pack"}
		"chain":
			return {"name": "formula_expected_distance", "distance": maxf(80.0, attack_range * 0.50), "orientation": "diagonal", "layout": "pack"}
		"area":
			return {"name": "practical_range", "distance": maxf(80.0, attack_range * 0.85), "orientation": "forward", "layout": "pack"}
	return {}


static func _expected_final(class_id: String, weapon_id: String) -> Dictionary:
	var schema := preload("res://scripts/constellation_schema6_data.gd")
	var runtime := preload("res://scripts/constellation_final_runtime.gd")
	for raw_branch in schema.class_entry(class_id).get("weapon_branches", []):
		var branch: Dictionary = raw_branch
		if str(branch.get("weapon_id", "")) != weapon_id:
			continue
		for raw_node in branch.get("nodes", []):
			var node: Dictionary = raw_node
			if str(node.get("role", "")) == "weapon_final":
				var mechanic_id := str(node.get("mechanic_id", ""))
				return {"mechanic_id": mechanic_id, "expected_event": str(runtime.EVENT_BY_MECHANIC.get(mechanic_id, ""))}
	return {}


static func family_matrix() -> Array:
	var progression := preload("res://scripts/progression_data.gd")
	var rows := []
	var class_ids: Array = progression.WEAPONS_BY_CLASS.keys()
	class_ids.sort()
	for class_id_value in class_ids:
		var class_id := str(class_id_value)
		var weapon_ids: Array = (progression.WEAPONS_BY_CLASS.get(class_id, {}) as Dictionary).keys()
		weapon_ids.sort()
		for weapon_id_value in weapon_ids:
			var weapon_id := str(weapon_id_value)
			var config: Dictionary = progression.weapon(class_id, weapon_id)
			var family := family_for_config(config)
			var final := _expected_final(class_id, weapon_id)
			rows.append({
				"class_id": class_id,
				"weapon_id": weapon_id,
				"attack_mode": str(config.get("attack_mode", config.get("attack_shape", ""))),
				"family": family,
				"mechanic_id": str(final.get("mechanic_id", "")),
				"expected_event": str(final.get("expected_event", "")),
				"ab_representative": REPRESENTATIVE_PAIRS.get(family, "") == "%s/%s" % [class_id, weapon_id],
				"geometry": geometry_for(family, config) if REPRESENTATIVE_PAIRS.get(family, "") == "%s/%s" % [class_id, weapon_id] else {},
			})
	return rows


static func representative_matrix(matrix := family_matrix()) -> Array:
	var representatives := []
	for entry_value in matrix:
		var entry: Dictionary = entry_value
		if bool(entry.get("ab_representative", false)):
			representatives.append(entry)
	return representatives


static func verify_matrix(matrix := family_matrix()) -> Dictionary:
	var progression := preload("res://scripts/progression_data.gd")
	var errors := PackedStringArray()
	var expected_pairs := {}
	for class_id_value in progression.WEAPONS_BY_CLASS.keys():
		var class_id := str(class_id_value)
		for weapon_id_value in (progression.WEAPONS_BY_CLASS.get(class_id, {}) as Dictionary).keys():
			expected_pairs["%s/%s" % [class_id, weapon_id_value]] = true
	var seen := {}
	var represented := {}
	for entry_value in matrix:
		var entry: Dictionary = entry_value
		var pair := pair_key(entry)
		if seen.has(pair):
			errors.append("%s appears more than once" % pair)
		seen[pair] = true
		if not expected_pairs.has(pair):
			errors.append("%s is not a runtime weapon pair" % pair)
		var family := str(entry.get("family", ""))
		if not FAMILIES.has(family):
			errors.append("%s has no supported offensive family" % pair)
		if str(entry.get("mechanic_id", "")) == "" or str(entry.get("expected_event", "")) == "":
			errors.append("%s has no schema-6 final event" % pair)
		if bool(entry.get("ab_representative", false)):
			if represented.has(family):
				errors.append("%s has more than one A/B representative" % family)
			represented[family] = true
			var geometry: Dictionary = entry.get("geometry", {})
			if float(geometry.get("distance", 0.0)) < 80.0 or str(geometry.get("layout", "")) == "" or str(geometry.get("orientation", "")) == "":
				errors.append("%s has an incomplete A/B geometry" % pair)
	if seen.size() != expected_pairs.size():
		errors.append("matrix covers %d/%d runtime pairs" % [seen.size(), expected_pairs.size()])
	for family in FAMILIES:
		if not represented.has(family):
			errors.append("%s has no A/B representative" % family)
	return {"ok": errors.is_empty(), "errors": errors, "runtime_pair_count": expected_pairs.size()}


static func evaluate_pair(entry: Dictionary, measurement: Dictionary) -> Dictionary:
	var errors := PackedStringArray()
	var enabled: Dictionary = measurement.get("enabled", {})
	var disabled: Dictionary = measurement.get("disabled", {})
	var pair := pair_key(entry)
	for arm_name in ["enabled", "disabled"]:
		var arm: Dictionary = measurement.get(arm_name, {})
		for counter in ["casts", "hits", "unique_target_count"]:
			if int(arm.get(counter, 0)) <= 0:
				errors.append("%s %s arm has no %s" % [pair, arm_name, counter])
		if float(arm.get("ledger_damage", 0.0)) <= 0.0:
			errors.append("%s %s arm has no source damage" % [pair, arm_name])
	if int(enabled.get("trigger_resolutions", 0)) <= 0:
		errors.append("%s enabled arm did not resolve %s" % [pair, entry.get("expected_event", "")])
	if int(disabled.get("trigger_resolutions", 0)) != 0 or int(disabled.get("final_event_count", 0)) != 0:
		errors.append("%s final leaked into the disabled arm" % pair)
	var formula_dpm := float(measurement.get("formula_expected_dpm", 0.0))
	var enabled_dpm := float(enabled.get("dpm", 0.0))
	var delta_pct := 0.0 if formula_dpm <= 0.0 else (enabled_dpm - formula_dpm) / formula_dpm * 100.0
	var event_damage := snappedf(float(enabled.get("final_event_damage", 0.0)), 0.0001)
	return {
		"ok": errors.is_empty(),
		"pair": pair,
		"family": str(entry.get("family", "")),
		"ab_verdict": "green" if errors.is_empty() else "red",
		"formula_live_verdict": "green" if absf(delta_pct) <= FORMULA_LIVE_TOLERANCE_PCT else "red",
		"formula_live_delta_pct": snappedf(delta_pct, 0.0001),
		"event_contribution": {"kind": "attributed_damage" if event_damage > 0.0 else "resolver_trigger", "trigger_resolutions": int(enabled.get("trigger_resolutions", 0)), "final_event_count": int(enabled.get("final_event_count", 0)), "damage": event_damage},
		"errors": errors,
	}


static func evaluate_fragment(fragment: Dictionary, matrix := family_matrix()) -> Dictionary:
	var errors := PackedStringArray()
	if str(fragment.get("fragment_schema", "")) != FRAGMENT_SCHEMA:
		errors.append("fragment schema mismatch")
	if str(fragment.get("pack_contract", "")) != PACK_CONTRACT:
		errors.append("pack contract mismatch")
	var matrix_check := verify_matrix(matrix)
	for matrix_error in matrix_check.get("errors", []):
		errors.append(str(matrix_error))
	var results := []
	var measurements: Dictionary = fragment.get("measurements", {})
	for entry_value in representative_matrix(matrix):
		var entry: Dictionary = entry_value
		var pair := pair_key(entry)
		if not measurements.has(pair):
			errors.append("%s has no A/B measurement" % pair)
			continue
		var result := evaluate_pair(entry, measurements[pair])
		results.append(result)
		for pair_error in result.get("errors", []):
			errors.append(str(pair_error))
	return {"ok": errors.is_empty(), "pairs": results, "errors": errors}
