extends RefCounted

# FAN-2412: class ultimates are class-level runtime evidence. Weapon rows stay
# sustain-only so an ultimate can never silently inflate one weapon's output.

const PD := preload("res://scripts/progression_data.gd")
const Meta := preload("res://scripts/meta_progression.gd")
const CodexData := preload("res://scripts/codex_data.gd")
const DamageTable := preload("res://tools/class_damage_table_3variants.gd")
const Report := preload("res://tools/a5_balance_report.gd")
const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")

const PACK_ID := "a5_ultimate_atlas_attribution"
const PACK_CONTRACT := "a5.scenario-pack.v1"
const FRAGMENT_SCHEMA := "fan2412.a5-ultimate-atlas-fragment.v1"
const FORMULA_SCHEMA := "fan1515.class-ultimate-formula.v1"
const FRAGMENT_DIR := "res://docs/design/reports/fan1438_a5_balance/fragments/ultimate_atlas"
const FRAGMENT_PATH := FRAGMENT_DIR + "/ultimate_atlas_attribution.json"
const PROBE_SECONDS := 60.0
const FIXED_FPS := 60
const PROBE_FRAMES := 3600
const FIXED_STEP_SAMPLE_COUNT := 8
const FIXED_STEP_TOLERANCE := 1.0e-9
const DAMAGE_EVIDENCE_TOLERANCE := 0.01
const SEED := 151501
const CROWD_TARGET_COUNT := 10
const SUSTAIN_METRIC_FIELDS := ["solo_dpm", "crowd_10_dpm"]
const ATLAS50_EXCLUSIONS := ["atlas_m2", "atlas_m3", "atlas_k0"]
const PLAYABLE_SCENARIOS := ["no_meta", "class_constellation", "class_atlas50"]
const NON_PLAYABLE_SCENARIO := "class_atlas59_upper"
const ZERO_DIRECT_CAUSES := {
	"chemist/acid_flask": {
		"reason_code": "acid_lake_had_no_applied_target",
		"runtime_path": "acid_flask._corrode",
		"fixture_precondition": "No static dummy was selected inside the aimed lake.",
	},
	"elementalist/elementalist_meteor_core": {
		"reason_code": "meteor_crater_had_no_applied_target",
		"runtime_path": "elementalist_meteor_core.impact/crater_pulse",
		"fixture_precondition": "No static dummy was selected inside the aimed crater.",
	},
	"priest/priest_censer": {
		"reason_code": "censer_counter_received_no_absorbed_damage",
		"runtime_path": "priest_censer.counter_burst",
		"fixture_precondition": "Static dummies have contact_damage=0, so the ward stores no prevention.",
	},
	"ranger/hunter_trap": {
		"reason_code": "trap_had_no_applied_target",
		"runtime_path": "hunter_trap.snap/close_net",
		"fixture_precondition": "No static dummy was selected inside the aimed trap.",
	},
}


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
	state["hidden_reveal_facts"] = {class_id: hidden_ids}
	if scenario_id == "class_atlas50" or scenario_id == NON_PLAYABLE_SCENARIO:
		purchased.append_array(_atlas_ids(scenario_id == NON_PLAYABLE_SCENARIO))
		var monster_ids := []
		for monster_value in CodexData.monsters():
			monster_ids.append(str((monster_value as Dictionary).get("id", "")))
		state["discovered_monsters"] = monster_ids
		state["secret_boss_defeated"] = true
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
			var solo_budget := PD.estimate_weapon_budget_for_stats(class_id, config, stats, true, {}, false)
			# FAN-2414: crowd_10_dpm must come from the canonical crowd-clear budget
			# (target_count=10), not the solo budget dict, which never carries a
			# "crowd_dps" key. NAN sentinel keeps a future missing key detectable
			# instead of silently collapsing to 0.0.
			var crowd_budget := PD.estimate_crowd_clear_budget_for_stats(class_id, config, CROWD_TARGET_COUNT, stats, true, {}, false)
			rows.append({
				"class_id": class_id,
				"weapon_id": weapon_id,
				"sustain_only": true,
				"solo_dpm": snappedf(float(solo_budget.get("solo_dps", NAN)) * 60.0, 0.0001),
				"crowd_10_dpm": snappedf(float(crowd_budget.get("crowd_dps", NAN)) * 60.0, 0.0001),
			})
	rows.sort_custom(func(left, right): return "%s/%s" % [left["class_id"], left["weapon_id"]] < "%s/%s" % [right["class_id"], right["weapon_id"]])
	return rows


static func damage_sources(feedback: Dictionary) -> PackedStringArray:
	if Activation.is_ultimate_damage_feedback(feedback):
		return PackedStringArray(["ultimate_source"])
	return PackedStringArray(["sustain_source"])

static func zero_direct_declaration(
	class_id: String, scenario_id: String, activation_count: int, ultimate_source: Dictionary
) -> Dictionary:
	if activation_count <= 0 or int(ultimate_source.get("hits", 0)) > 0:
		return {}
	var cause: Dictionary = ZERO_DIRECT_CAUSES.get(
		"%s/%s" % [class_id, canonical_weapon(class_id)], {}
	)
	var declaration := {
		"kind": "activation_completed_without_applied_damage",
		"class_id": class_id,
		"scenario": scenario_id,
		"activation_count": activation_count,
		"provenance_event_count": int(ultimate_source.get("hits", 0)),
	}
	if cause.is_empty():
		declaration["reason_code"] = "unexplained_zero_direct_damage"
		return declaration
	declaration.merge(cause, true)
	return declaration


static func evaluate_fragment(fragment: Dictionary) -> Dictionary:
	var errors := PackedStringArray()
	if str(fragment.get("fragment_schema", "")) != FRAGMENT_SCHEMA:
		errors.append("fragment schema mismatch")
	if str(fragment.get("pack_contract", "")) != PACK_CONTRACT:
		errors.append("pack contract mismatch")
	if not _equivalent(fragment.get("contract", {}), contract()):
		errors.append("frozen contract mismatch")
	if not _runtime_evidence_is_trusted(fragment.get("runtime_evidence", {})):
		errors.append("fragment was not generated at the required fixed timestep")
	var manifest: Dictionary = fragment.get("scenario_manifest", {})
	if not _equivalent(manifest, scenario_manifest()):
		errors.append("scenario manifest mismatch")
	if int((manifest.get(NON_PLAYABLE_SCENARIO, {}) as Dictionary).get("atlas_spend", -1)) != 59:
		errors.append("Atlas 59 upper bound is not explicit")
	if int((manifest.get("class_atlas50", {}) as Dictionary).get("atlas_spend", -1)) != 50:
		errors.append("Atlas 50 cap is not explicit")
	var expected_weapons := {}
	for class_value in class_ids():
		var class_id := str(class_value)
		for weapon_value in PD.weapon_ids(class_id):
			expected_weapons["%s/%s" % [class_id, weapon_value]] = true
	var seen_weapons := {}
	var metric_totals := {}
	for field in SUSTAIN_METRIC_FIELDS:
		metric_totals[field] = 0.0
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
		for field in SUSTAIN_METRIC_FIELDS:
			var value: Variant = row.get(field, null)
			if not _is_nonnegative_number(value):
				errors.append("%s has a missing or invalid %s" % [key, field])
				continue
			metric_totals[field] = float(metric_totals[field]) + float(value)
	if seen_weapons.size() != expected_weapons.size():
		errors.append("sustain rows cover %d/%d runtime weapons" % [seen_weapons.size(), expected_weapons.size()])
	# FAN-2414: a metric that reads a nonexistent budget key silently defaults to
	# 0.0 for every row instead of raising. Reject that shape outright unless the
	# fragment explicitly exempts the field.
	var zero_exemptions: Array = fragment.get("zero_metric_exemptions", [])
	for field in SUSTAIN_METRIC_FIELDS:
		if not seen_weapons.is_empty() and is_zero_approx(float(metric_totals[field])) and not zero_exemptions.has(field):
			errors.append("%s is a constant zero across all sustain rows without an explicit schema exemption" % field)
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
			if not _runtime_evidence_is_trusted(measurement.get("runtime_evidence", {})):
				errors.append("%s was not measured at the required fixed timestep" % key)
			if not is_equal_approx(float(measurement.get("initial_charge", -1.0)), float(formula.get("start_charge", -2.0))):
				errors.append("%s runtime initial charge differs from formula" % key)
			var raw_initial_activations: Variant = measurement.get("initial_activation_count", -1)
			var initial_activations := int(raw_initial_activations) if _is_nonnegative_count(raw_initial_activations) else -1
			if initial_activations != int(formula.get("expected_initial_activations", -2)):
				errors.append("%s start-charge attribution differs from formula" % key)
			if not (
				measurement.has("ultimate_source")
				and measurement.has("sustain_source")
				and measurement.has("activation_timing_seconds")
			):
				errors.append("%s lacks ultimate source/timing evidence" % key)
				continue
			var ultimate_source = measurement.get("ultimate_source")
			var sustain_source = measurement.get("sustain_source")
			var attribution = measurement.get("attribution")
			if not (
				ultimate_source is Dictionary
				and sustain_source is Dictionary
				and attribution is Dictionary
			):
				errors.append("%s lacks structured source attribution" % key)
				continue
			var ultimate := ultimate_source as Dictionary
			var sustain := sustain_source as Dictionary
			var source_attribution := attribution as Dictionary
			var activation_count: Variant = measurement.get("activation_count", -1)
			var activation_total := int(activation_count) if _is_nonnegative_count(activation_count) else -1
			if not _activation_timing_is_valid(measurement.get("activation_timing_seconds", []), activation_count, initial_activations):
				errors.append("%s activation timing is not complete runtime evidence" % key)
			if not _source_evidence_is_valid(ultimate, sustain):
				errors.append("%s source values or mechanism totals are invalid" % key)
			if not _provenance_is_valid(source_attribution, ultimate):
				errors.append("%s ultimate provenance is missing, duplicated or double-booked" % key)
			if activation_total > 0 and int(ultimate.get("hits", 0)) == 0 and float(ultimate.get("damage", 0.0)) != 0.0:
				errors.append("%s has zero ultimate hits with nonzero ultimate damage" % key)
			if activation_total == 0 and int(ultimate.get("hits", 0)) > 0:
				errors.append("%s has ultimate damage without an activation" % key)
			if int(source_attribution.get("ultimate_event_count", -1)) != int(ultimate.get("hits", -2)):
				errors.append("%s ultimate event count leaks into sustain" % key)
			var expected_zero := zero_direct_declaration(
				class_id, scenario_id, activation_total, ultimate
			)
			if str(expected_zero.get("reason_code", "")) == "unexplained_zero_direct_damage":
				errors.append("%s has an unexplained zero-direct-damage activation" % key)
			if not _equivalent(measurement.get("zero_direct_damage", {}), expected_zero):
				errors.append("%s zero-direct-damage declaration is missing or invalid" % key)
	if measurements.size() != class_ids().size() * PLAYABLE_SCENARIOS.size():
		errors.append("runtime measurement count is not class-only and complete")
	return {"ok": errors.is_empty(), "errors": errors}


static func _runtime_evidence_is_trusted(raw_value) -> bool:
	if not raw_value is Dictionary:
		return false
	var evidence := raw_value as Dictionary
	var expected_delta := 1.0 / float(FIXED_FPS)
	var delta: Variant = evidence.get("process_delta_seconds", -1.0)
	var fps: Variant = evidence.get("process_fps", -1.0)
	return (
		bool(evidence.get("trusted", false))
		and int(evidence.get("fixed_fps", -1)) == FIXED_FPS
		and int(evidence.get("sample_count", -1)) == FIXED_STEP_SAMPLE_COUNT
		and _is_nonnegative_number(delta)
		and _is_nonnegative_number(fps)
		and absf(float(delta) - expected_delta) <= FIXED_STEP_TOLERANCE
		and absf(float(fps) - float(FIXED_FPS)) <= 0.01
	)


static func _activation_timing_is_valid(raw_value, raw_count, initial_activation_count: int) -> bool:
	if not _is_nonnegative_count(raw_count) or not raw_value is Array:
		return false
	var timings := raw_value as Array
	if timings.size() != int(raw_count) or initial_activation_count < 0 or initial_activation_count > int(raw_count):
		return false
	var previous := -1.0
	for value in timings:
		if not _is_nonnegative_number(value) or float(value) > PROBE_SECONDS or float(value) <= previous:
			return false
		previous = float(value)
	return initial_activation_count == 0 or (not timings.is_empty() and is_zero_approx(float(timings[0])))


static func _source_evidence_is_valid(ultimate: Dictionary, sustain: Dictionary) -> bool:
	for source in [ultimate, sustain]:
		if not _is_nonnegative_number(source.get("damage", null)) or not _is_nonnegative_count(source.get("hits", null)):
			return false
		if (int(source.get("hits", 0)) == 0) != is_zero_approx(float(source.get("damage", 0.0))):
			return false
	var mechanisms = ultimate.get("by_mechanic", {})
	if not mechanisms is Dictionary:
		return false
	var total_damage := 0.0
	var total_hits := 0
	for mechanic_id_value in (mechanisms as Dictionary).keys():
		var mechanic_id := str(mechanic_id_value)
		var row = (mechanisms as Dictionary).get(mechanic_id_value)
		if mechanic_id.is_empty() or not row is Dictionary:
			return false
		var mechanism := row as Dictionary
		if (
			not _is_nonnegative_number(mechanism.get("damage", null))
			or not _is_nonnegative_count(mechanism.get("hits", null))
			or not _is_nonnegative_count(mechanism.get("first_frame", null))
			or int(mechanism.get("hits", 0)) <= 0
			or float(mechanism.get("damage", 0.0)) <= 0.0
			or int(mechanism.get("first_frame", 0)) >= PROBE_FRAMES
		):
			return false
		total_damage += float(mechanism.get("damage", 0.0))
		total_hits += int(mechanism.get("hits", 0))
	if int(ultimate.get("hits", 0)) == 0:
		return (mechanisms as Dictionary).is_empty()
	return (
		not (mechanisms as Dictionary).is_empty()
		and total_hits == int(ultimate.get("hits", 0))
		and absf(total_damage - float(ultimate.get("damage", 0.0))) <= DAMAGE_EVIDENCE_TOLERANCE
	)


static func _provenance_is_valid(attribution: Dictionary, ultimate: Dictionary) -> bool:
	for field in ["ultimate_event_count", "missing_ultimate_event_id_count", "duplicate_ultimate_event_id_count", "invalid_source_count"]:
		if not _is_nonnegative_count(attribution.get(field, null)):
			return false
	return (
		int(attribution.get("ultimate_event_count", -1)) == int(ultimate.get("hits", -2))
		and int(attribution.get("missing_ultimate_event_id_count", -1)) == 0
		and int(attribution.get("duplicate_ultimate_event_id_count", -1)) == 0
		and int(attribution.get("invalid_source_count", -1)) == 0
	)


static func _is_nonnegative_number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0


static func _is_nonnegative_count(value) -> bool:
	return _is_nonnegative_number(value) and is_equal_approx(float(value), float(int(value)))


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
	return (
		_equivalent(actual.get("stats", {}), expected.get("stats", {}))
		and _equivalent(actual.get("run_modifiers", {}), expected.get("run_modifiers", {}))
	)


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
