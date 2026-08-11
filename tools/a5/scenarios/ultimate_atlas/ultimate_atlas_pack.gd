extends RefCounted

# FAN-1515: class ultimates are class-level runtime evidence.  Weapon rows stay
# sustain-only so an ultimate can never silently inflate one weapon's output.

const PD := preload("res://scripts/progression_data.gd")
const Meta := preload("res://scripts/meta_progression.gd")
const CodexData := preload("res://scripts/codex_data.gd")
const DamageTable := preload("res://tools/class_damage_table_3variants.gd")
const Report := preload("res://tools/a5_balance_report.gd")

const PACK_ID := "a5_ultimate_atlas_attribution"
const PACK_CONTRACT := "a5.scenario-pack.v1"
const FRAGMENT_SCHEMA := "fan1515.a5-ultimate-atlas-fragment.v1"
const FORMULA_SCHEMA := "fan1515.class-ultimate-formula.v1"
const FRAGMENT_DIR := "res://docs/design/reports/fan1438_a5_balance/fragments/ultimate_atlas"
const FRAGMENT_PATH := FRAGMENT_DIR + "/ultimate_atlas_attribution.json"
const PROBE_SECONDS := 60.0
const FIXED_FPS := 60
const PROBE_FRAMES := 3600
const SEED := 151501
const ATLAS50_EXCLUSIONS := ["atlas_m2", "atlas_m3", "atlas_k0"]
const PLAYABLE_SCENARIOS := ["no_meta", "class_constellation", "class_atlas50"]
const NON_PLAYABLE_SCENARIO := "class_atlas59_upper"


static func contract() -> Dictionary:
	return {
		"pack_id": PACK_ID,
		"pack_contract": PACK_CONTRACT,
		"fragment_schema": FRAGMENT_SCHEMA,
		"formula_schema": FORMULA_SCHEMA,
		"probe_seconds": PROBE_SECONDS,
		"fixed_fps": FIXED_FPS,
		"probe_frames": PROBE_FRAMES,
		"seed": SEED,
		"playable_scenarios": PLAYABLE_SCENARIOS,
		"non_playable_scenario": NON_PLAYABLE_SCENARIO,
	}


static func class_ids() -> Array:
	var ids: Array = PD.WEAPONS_BY_CLASS.keys()
	ids.sort()
	return ids


static func canonical_weapon(class_id: String) -> String:
	var ids: Array = PD.weapon_ids(class_id)
	ids.sort()
	return str(ids[0]) if not ids.is_empty() else ""


static func _atlas_ids(include_exclusions: bool) -> Array:
	var ids := []
	for node_value in Meta.atlas_nodes():
		var node: Dictionary = node_value
		var node_id := str(node.get("id", ""))
		if include_exclusions or not ATLAS50_EXCLUSIONS.has(node_id):
			ids.append(node_id)
	ids.sort()
	return ids


static func _cost(ids: Array) -> int:
	var total := 0
	for id_value in ids:
		total += int(Meta.node_by_id(str(id_value)).get("cost", 0))
	return total


static func scenario_manifest() -> Dictionary:
	var atlas50 := _atlas_ids(false)
	var atlas59 := _atlas_ids(true)
	return {
		"no_meta": {"label": "No meta control", "playable": true, "class_spend": 0, "atlas_spend": 0, "atlas_ids": []},
		"class_constellation": {"label": "Full class constellation", "playable": true, "class_spend": 20, "atlas_spend": 0, "atlas_ids": []},
		"class_atlas50": {"label": "Full class + legal Guild Atlas 50", "playable": true, "class_spend": 20, "atlas_spend": _cost(atlas50), "atlas_ids": atlas50, "excluded_ids": ATLAS50_EXCLUSIONS},
		"class_atlas59_upper": {"label": "NON-PLAYABLE: cap 50", "playable": false, "class_spend": 20, "atlas_spend": _cost(atlas59), "atlas_ids": atlas59, "excluded_ids": []},
	}


static func scenario_state(class_id: String, scenario_id: String) -> Dictionary:
	var state := Meta.default_state()
	state["ascension_levels"] = {class_id: 5}
	if scenario_id == "no_meta":
		return state
	var purchased := []
	var hidden_ids := []
	for node_value in Meta.constellation_nodes(class_id):
		var node: Dictionary = node_value
		var node_id := str(node.get("id", ""))
		if str(node.get("role", "")) != "core":
			purchased.append(node_id)
		if str(node.get("role", "")) == "hidden":
			hidden_ids.append(node_id)
	if scenario_id == "class_atlas50":
		purchased.append_array(_atlas_ids(false))
	elif scenario_id == NON_PLAYABLE_SCENARIO:
		purchased.append_array(_atlas_ids(true))
	var monster_ids := []
	for monster_value in CodexData.monsters():
		monster_ids.append(str((monster_value as Dictionary).get("id", "")))
	state["hidden_reveal_facts"] = {class_id: hidden_ids}
	state["discovered_monsters"] = monster_ids
	state["secret_boss_defeated"] = scenario_id != "no_meta"
	state["skill_nodes"] = purchased
	return state


static func class_formula(class_id: String, scenario_id: String) -> Dictionary:
	var state := scenario_state(class_id, scenario_id)
	var mods: Dictionary = Meta.skill_modifiers_for_class(state, class_id) if scenario_id != "no_meta" else {}
	var stats: Dictionary = DamageTable.optimized_stats_for_class(class_id, PD.base_stats(class_id))
	var run_mods := Report._a5_run_modifiers(class_id)
	# This is intentionally the single class-meta application used by the runtime.
	if scenario_id != "no_meta":
		Report._apply_meta_formula_mods(stats, run_mods, mods)
	var weapon_id := canonical_weapon(class_id)
	var config: Dictionary = PD.weapon(class_id, weapon_id).duplicate(true)
	config["character_id"] = class_id
	var params := PD.derived_parameters(stats, run_mods, config)
	var ultimate := PD.ultimate_config(class_id)
	var base_damage := maxf(float(params.get("damage", 1.0)), float(params.get("magic_damage", 1.0)))
	var ratio := clampf(float(mods.get("ult_start_charge", 0.0)), 0.0, 1.0)
	return {
		"formula_schema": FORMULA_SCHEMA,
		"class_id": class_id,
		"scenario": scenario_id,
		"canonical_weapon_id": weapon_id,
		"meta_application_count": 0 if scenario_id == "no_meta" else 1,
		"start_charge_ratio": snappedf(ratio, 0.0001),
		"start_charge": snappedf(ratio * 100.0, 0.0001),
		"expected_initial_activations": 1 if is_equal_approx(ratio, 1.0) else 0,
		"expected_activation_damage": snappedf(base_damage * float(ultimate.get("damage", 1.0)) * float(params.get("ultimate_multiplier", 1.0)), 0.0001),
		"stats": stats,
		"run_modifiers": run_mods,
	}


static func per_weapon_sustain_rows() -> Array:
	var rows := []
	for class_value in class_ids():
		var class_id := str(class_value)
		var stats: Dictionary = DamageTable.optimized_stats_for_class(class_id, PD.base_stats(class_id))
		for weapon_value in PD.weapon_ids(class_id):
			var weapon_id := str(weapon_value)
			var config := PD.weapon(class_id, weapon_id)
			var budget := PD.estimate_weapon_budget_for_stats(class_id, config, stats, true, {}, false)
			rows.append({
				"class_id": class_id,
				"weapon_id": weapon_id,
				"sustain_only": true,
				"solo_dpm": snappedf(float(budget.get("solo_dps", 0.0)) * 60.0, 0.0001),
				"crowd_10_dpm": snappedf(float(budget.get("crowd_dps", 0.0)) * 60.0, 0.0001),
			})
	rows.sort_custom(func(left, right): return "%s/%s" % [left["class_id"], left["weapon_id"]] < "%s/%s" % [right["class_id"], right["weapon_id"]])
	return rows


static func evaluate_fragment(fragment: Dictionary) -> Dictionary:
	var errors := PackedStringArray()
	if str(fragment.get("fragment_schema", "")) != FRAGMENT_SCHEMA:
		errors.append("fragment schema mismatch")
	if str(fragment.get("pack_contract", "")) != PACK_CONTRACT:
		errors.append("pack contract mismatch")
	if not _equivalent(fragment.get("contract", {}), contract()):
		errors.append("frozen contract mismatch")
	var manifest: Dictionary = fragment.get("scenario_manifest", {})
	if not _equivalent(manifest, scenario_manifest()):
		errors.append("scenario manifest mismatch")
	if int((manifest.get(NON_PLAYABLE_SCENARIO, {}) as Dictionary).get("atlas_spend", -1)) != 59:
		errors.append("Atlas 59 upper bound is not explicit")
	var expected_weapons := {}
	for class_value in class_ids():
		var class_id := str(class_value)
		for weapon_value in PD.weapon_ids(class_id):
			expected_weapons["%s/%s" % [class_id, weapon_value]] = true
	var seen_weapons := {}
	for row_value in fragment.get("per_weapon_sustain", []):
		var row: Dictionary = row_value
		var key := "%s/%s" % [row.get("class_id", ""), row.get("weapon_id", "")]
		if seen_weapons.has(key) or not expected_weapons.has(key):
			errors.append("invalid sustain row %s" % key)
		seen_weapons[key] = true
		if not bool(row.get("sustain_only", false)):
			errors.append("%s is not marked sustain-only" % key)
		for field in row.keys():
			if str(field).contains("ultimate"):
				errors.append("%s leaks ultimate into a per-weapon row" % key)
	if seen_weapons.size() != expected_weapons.size():
		errors.append("sustain rows cover %d/%d runtime weapons" % [seen_weapons.size(), expected_weapons.size()])
	var measurements: Dictionary = fragment.get("measurements", {})
	for class_value in class_ids():
		var class_id := str(class_value)
		for scenario_value in PLAYABLE_SCENARIOS:
			var scenario_id := str(scenario_value)
			var key := "%s|%s" % [class_id, scenario_id]
			if not measurements.has(key):
				errors.append("missing runtime measurement %s" % key)
				continue
			var measurement: Dictionary = measurements[key]
			var formula := class_formula(class_id, scenario_id)
			if not _formula_matches(measurement.get("formula", {}), formula):
				errors.append("%s formula is not the single-application class formula" % key)
			if int(measurement.get("frame_count", -1)) != PROBE_FRAMES or not is_equal_approx(float(measurement.get("duration_seconds", -1.0)), PROBE_SECONDS):
				errors.append("%s is not a 60-second probe" % key)
			if int(measurement.get("seed", -1)) != SEED:
				errors.append("%s seed mismatch" % key)
			if not is_equal_approx(float(measurement.get("initial_charge", -1.0)), float(formula.get("start_charge", -2.0))):
				errors.append("%s runtime initial charge differs from formula" % key)
			if int(measurement.get("initial_activation_count", -1)) != int(formula.get("expected_initial_activations", -2)):
				errors.append("%s start-charge attribution differs from formula" % key)
			if not measurement.has("ultimate_source") or not measurement.has("activation_timing_seconds"):
				errors.append("%s lacks ultimate source/timing evidence" % key)
	if measurements.size() != class_ids().size() * PLAYABLE_SCENARIOS.size():
		errors.append("runtime measurement count is not class-only and complete")
	return {"ok": errors.is_empty(), "errors": errors}


static func _formula_matches(raw_value, expected: Dictionary) -> bool:
	if not raw_value is Dictionary:
		return false
	var actual := raw_value as Dictionary
	for key in ["formula_schema", "class_id", "scenario", "canonical_weapon_id"]:
		if str(actual.get(key, "")) != str(expected.get(key, "")):
			return false
	for key in ["meta_application_count", "expected_initial_activations"]:
		if int(actual.get(key, -1)) != int(expected.get(key, -2)):
			return false
	for key in ["start_charge_ratio", "start_charge", "expected_activation_damage"]:
		if not is_equal_approx(float(actual.get(key, NAN)), float(expected.get(key, NAN))):
			return false
	return actual.get("stats", {}) is Dictionary and actual.get("run_modifiers", {}) is Dictionary


static func _equivalent(left, right) -> bool:
	if (left is int or left is float) and (right is int or right is float):
		return is_equal_approx(float(left), float(right))
	if left is Dictionary and right is Dictionary:
		var left_dict := left as Dictionary
		var right_dict := right as Dictionary
		if left_dict.size() != right_dict.size():
			return false
		for key in left_dict:
			if not right_dict.has(key) or not _equivalent(left_dict[key], right_dict[key]):
				return false
		return true
	if left is Array and right is Array:
		var left_array := left as Array
		var right_array := right as Array
		if left_array.size() != right_array.size():
			return false
		for index in range(left_array.size()):
			if not _equivalent(left_array[index], right_array[index]):
				return false
		return true
	return left == right
