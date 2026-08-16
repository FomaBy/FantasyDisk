extends SceneTree

const Pack := preload("res://tools/a5/scenarios/ultimate_atlas/ultimate_atlas_pack.gd")
const PD := preload("res://scripts/progression_data.gd")
const Meta := preload("res://scripts/meta_progression.gd")
const PlayerScript := preload("res://scripts/player.gd")
const DamageTable := preload("res://tools/class_damage_table_3variants.gd")
const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const FRAGMENT_PATH := Pack.FRAGMENT_PATH

var _errors := PackedStringArray()


func _initialize() -> void:
	_verify_contract()
	_verify_provenance_contract()
	_verify_single_application_formula()
	_verify_class_constellation_excludes_atlas_only_modifiers()
	_verify_fail_closed_oracles()
	_verify_committed_fragment()
	_finish()


func _verify_contract() -> void:
	var contract := Pack.contract()
	_check(str(contract.get("pack_contract", "")) == "a5.scenario-pack.v1", "pack contract must stay frozen at v1")
	_check(float(contract.get("probe_seconds", 0.0)) == 60.0 and int(contract.get("probe_frames", 0)) == 3600, "runtime probe must remain 60 seconds at 60 FPS")
	var manifest := Pack.scenario_manifest()
	_check(not bool((manifest.get(Pack.NON_PLAYABLE_SCENARIO, {}) as Dictionary).get("playable", true)), "Atlas 59 must remain non-playable")
	_check(int((manifest.get(Pack.NON_PLAYABLE_SCENARIO, {}) as Dictionary).get("atlas_spend", 0)) == 59, "Atlas 59 upper bound must remain explicit")
	_check(int((manifest.get("class_atlas50", {}) as Dictionary).get("atlas_spend", -1)) == 50, "Atlas 50 cap must remain exactly the canonical legal maximum")
	_check(Pack.class_ids().size() == 17, "runtime roster must retain all 17 class kits")
	_check(Pack.per_weapon_sustain_rows().size() == 51, "sustain roster must retain all 51 runtime weapons")


# FAN-2413: discovered_monsters/secret_boss_defeated must only unlock the
# account-wide Guild Atlas hidden nodes in explicitly Atlas-enabled arcs, so
# the class_constellation control arm cannot silently inherit Atlas boons
# (e.g. atlas_h0 money_gain_mult, atlas_h1 start_gold_flat).
func _verify_class_constellation_excludes_atlas_only_modifiers() -> void:
	var atlas_hidden_keys := {}
	for node_value in Meta.atlas_nodes():
		var node: Dictionary = node_value
		if str(node.get("role", "")) != "hidden":
			continue
		for key in (node.get("effects", {}) as Dictionary).keys():
			atlas_hidden_keys[str(key)] = true
	_check(atlas_hidden_keys.has("start_gold_flat") and atlas_hidden_keys.has("money_gain_mult"), "Guild Atlas hidden boons must still include the known start_gold/money-multiplier effects")
	for class_value in Pack.class_ids():
		var class_id := str(class_value)
		var state := Pack.scenario_state(class_id, "class_constellation")
		_check(not bool(state.get("secret_boss_defeated", false)), "%s class_constellation must not carry secret_boss_defeated" % class_id)
		_check((state.get("discovered_monsters", []) as Array).is_empty(), "%s class_constellation must not carry discovered_monsters" % class_id)
		var mods := Meta.skill_modifiers_for_class(state, class_id)
		for key in atlas_hidden_keys.keys():
			_check(is_zero_approx(float(mods.get(key, 0.0))), "%s class_constellation leaked Guild Atlas hidden modifier %s" % [class_id, key])


func _verify_provenance_contract() -> void:
	var untagged_sources := Pack.damage_sources({"ultimate_mechanic": "legacy"})
	_check(
		untagged_sources.size() == 1 and untagged_sources[0] == "sustain_source",
		"the pre-fix untagged ultimate event must reproduce the sustain leak"
	)
	var activation := Activation.new(null, {}, 0.0)
	var feedback := activation.damage_feedback({
		"ultimate_mechanic": "legacy",
		"ultimate_provenance": "executor_override",
		"ultimate_provenance_event_id": "executor_override:1",
	})
	var sources := Pack.damage_sources(feedback)
	_check(
		sources.size() == 1 and sources[0] == "ultimate_source",
		"activation provenance must override executor feedback and use exactly one source bucket"
	)
	_check(
		str(feedback.get("ultimate_provenance_event_id", "")) != "executor_override:1",
		"activation provenance event id must not be overridden by an executor"
	)


func _verify_single_application_formula() -> void:
	var double_application_would_differ := 0
	for class_value in Pack.class_ids():
		var class_id := str(class_value)
		for scenario_value in Pack.PLAYABLE_SCENARIOS:
			var scenario_id := str(scenario_value)
			var expected := _formula_oracle(class_id, scenario_id)
			var actual := Pack.class_formula(class_id, scenario_id)
			_check(int(actual.get("meta_application_count", -1)) == int(expected.get("application_count", -2)), "%s/%s formula applied meta more than once" % [class_id, scenario_id])
			_check(is_equal_approx(float(actual.get("start_charge", -1.0)), float(expected.get("start_charge", -2.0))), "%s/%s start charge differs from independent formula" % [class_id, scenario_id])
			_check(is_equal_approx(float(actual.get("expected_activation_damage", -1.0)), float(expected.get("activation_damage", -2.0))), "%s/%s runtime expected damage differs from single-application formula" % [class_id, scenario_id])
			if scenario_id == "no_meta":
				continue
			var double_stats: Dictionary = (expected.get("stats", {}) as Dictionary).duplicate(true)
			var mods: Dictionary = expected.get("mods", {})
			for source_key in PlayerScript.META_SKILL_ATTRIBUTE_FLAT_MAP:
				if mods.has(source_key):
					var stat_key := str(PlayerScript.META_SKILL_ATTRIBUTE_FLAT_MAP[source_key])
					double_stats[stat_key] = float(double_stats.get(stat_key, 0.0)) + float(mods[source_key])
			var weapon_id := Pack.canonical_weapon(class_id)
			var config: Dictionary = PD.weapon(class_id, weapon_id).duplicate(true)
			config["character_id"] = class_id
			var double_params := PD.derived_parameters(double_stats, expected.get("run_modifiers", {}), config)
			var ultimate := PD.ultimate_config(class_id)
			var double_base := maxf(float(double_params.get("damage", 1.0)), float(double_params.get("magic_damage", 1.0)))
			var double_damage := double_base * float(ultimate.get("damage", 1.0)) * float(double_params.get("ultimate_multiplier", 1.0))
			if not is_equal_approx(double_damage, float(expected.get("activation_damage", 0.0))):
				double_application_would_differ += 1
				_check(not is_equal_approx(float(actual.get("expected_activation_damage", 0.0)), double_damage), "%s/%s retained a double-applied meta value" % [class_id, scenario_id])
	_check(double_application_would_differ > 0, "oracle must include a meta case where a second application is numerically visible")


func _formula_oracle(class_id: String, scenario_id: String) -> Dictionary:
	var state := Pack.scenario_state(class_id, scenario_id)
	var mods: Dictionary = Meta.skill_modifiers_for_class(state, class_id) if scenario_id != "no_meta" else {}
	var stats: Dictionary = DamageTable.optimized_stats_for_class(class_id, PD.base_stats(class_id))
	var run_modifiers := {}
	for key_value in PD.ascension_mods(class_id, 5).keys():
		var key := str(key_value)
		var value := float(PD.ascension_mods(class_id, 5)[key_value])
		run_modifiers[key] = float(run_modifiers.get(key, 1.0)) * value if key.ends_with("_multiplier") else float(run_modifiers.get(key, 0.0)) + value
	var difficulty := PD.ascension_difficulty_mods(5)
	for key in ["xp_gain_multiplier", "money_gain_multiplier", "healing_multiplier", "max_health_multiplier"]:
		run_modifiers[key] = float(run_modifiers.get(key, 1.0)) * float(difficulty.get({"xp_gain_multiplier": "reward_mult", "money_gain_multiplier": "reward_mult", "healing_multiplier": "healing_mult", "max_health_multiplier": "player_max_hp_mult"}[key], 1.0))
	if scenario_id != "no_meta":
		for source_key in PlayerScript.META_SKILL_ATTRIBUTE_FLAT_MAP:
			if mods.has(source_key):
				var stat_key := str(PlayerScript.META_SKILL_ATTRIBUTE_FLAT_MAP[source_key])
				stats[stat_key] = float(stats.get(stat_key, 0.0)) + float(mods[source_key])
		for source_key in PlayerScript.META_SKILL_MULT_MAP:
			if mods.has(source_key):
				var run_key := str(PlayerScript.META_SKILL_MULT_MAP[source_key])
				run_modifiers[run_key] = float(run_modifiers.get(run_key, 1.0)) * (1.0 + float(mods[source_key]))
		for source_key in PlayerScript.META_SKILL_FLAT_MAP:
			if mods.has(source_key):
				var run_key := str(PlayerScript.META_SKILL_FLAT_MAP[source_key])
				run_modifiers[run_key] = float(run_modifiers.get(run_key, 0.0)) + float(mods[source_key])
	var weapon_id := Pack.canonical_weapon(class_id)
	var config: Dictionary = PD.weapon(class_id, weapon_id).duplicate(true)
	config["character_id"] = class_id
	var params := PD.derived_parameters(stats, run_modifiers, config)
	var ultimate := PD.ultimate_config(class_id)
	var base_damage := maxf(float(params.get("damage", 1.0)), float(params.get("magic_damage", 1.0)))
	return {"application_count": 0 if scenario_id == "no_meta" else 1, "start_charge": clampf(float(mods.get("ult_start_charge", 0.0)), 0.0, 1.0) * 100.0, "activation_damage": base_damage * float(ultimate.get("damage", 1.0)) * float(params.get("ultimate_multiplier", 1.0)), "mods": mods, "stats": stats, "run_modifiers": run_modifiers}


func _verify_fail_closed_oracles() -> void:
	var fragment := _fixture_fragment()
	_check(bool(Pack.evaluate_fragment(fragment).get("ok", false)), "well-formed class/Atlas attribution fixture must pass")
	var leaked := fragment.duplicate(true)
	((leaked["per_weapon_sustain"] as Array)[0] as Dictionary)["ultimate_damage"] = 1.0
	_check(not bool(Pack.evaluate_fragment(leaked).get("ok", true)), "ultimate data in a weapon row must fail closed")
	# FAN-2414: a missing/invalid per-weapon metric, or a metric that reads a
	# nonexistent budget key and silently collapses to 0.0 for every row, must
	# fail closed instead of certifying as a green fragment.
	var missing_metric := fragment.duplicate(true)
	((missing_metric["per_weapon_sustain"] as Array)[0] as Dictionary).erase("crowd_10_dpm")
	_check(not bool(Pack.evaluate_fragment(missing_metric).get("ok", true)), "a missing crowd_10_dpm must fail closed")
	var zeroed_metric := fragment.duplicate(true)
	for row_value in (zeroed_metric["per_weapon_sustain"] as Array):
		(row_value as Dictionary)["crowd_10_dpm"] = 0.0
	_check(not bool(Pack.evaluate_fragment(zeroed_metric).get("ok", true)), "a column-wide constant-zero crowd_10_dpm must fail closed without an explicit exemption")
	var exempted_metric: Dictionary = zeroed_metric.duplicate(true)
	exempted_metric["zero_metric_exemptions"] = ["crowd_10_dpm"]
	_check(bool(Pack.evaluate_fragment(exempted_metric).get("ok", false)), "an explicit zero_metric_exemptions entry must allow a column-wide constant-zero metric")
	var wrong_charge := fragment.duplicate(true)
	var atlas_key := "%s|class_atlas50" % str(Pack.class_ids()[0])
	(wrong_charge["measurements"] as Dictionary)[atlas_key]["initial_activation_count"] = 0
	_check(not bool(Pack.evaluate_fragment(wrong_charge).get("ok", true)), "wrong Atlas start-charge attribution must fail closed")
	var zeroed := fragment.duplicate(true)
	var zeroed_measurement: Dictionary = (zeroed["measurements"] as Dictionary)[atlas_key]
	zeroed_measurement["ultimate_source"] = {"damage": 0.0, "hits": 1, "by_mechanic": {"fixture_activation": {"damage": 0.0, "hits": 1, "first_frame": 0}}}
	_check(not bool(Pack.evaluate_fragment(zeroed).get("ok", true)), "zeroed ultimate damage with an activation must fail closed")
	var moved_to_sustain := fragment.duplicate(true)
	var moved_measurement: Dictionary = (moved_to_sustain["measurements"] as Dictionary)[atlas_key]
	moved_measurement["ultimate_source"] = {"damage": 0.0, "hits": 0, "by_mechanic": {}}
	moved_measurement["sustain_source"] = {"damage": 11.0, "hits": 2}
	moved_measurement["attribution"] = {"ultimate_event_count": 0, "missing_ultimate_event_id_count": 0, "duplicate_ultimate_event_id_count": 0, "invalid_source_count": 0}
	_check(not bool(Pack.evaluate_fragment(moved_to_sustain).get("ok", true)), "ultimate damage moved to sustain must fail closed")
	var distorted_totals := fragment.duplicate(true)
	var distorted_measurement: Dictionary = (distorted_totals["measurements"] as Dictionary)[atlas_key]
	(distorted_measurement["ultimate_source"] as Dictionary)["by_mechanic"] = {"fixture_activation": {"damage": 9.0, "hits": 1, "first_frame": 0}}
	_check(not bool(Pack.evaluate_fragment(distorted_totals).get("ok", true)), "distorted ultimate mechanism totals must fail closed")
	var wrong_timing := fragment.duplicate(true)
	(wrong_timing["measurements"] as Dictionary)[atlas_key]["activation_timing_seconds"] = [Pack.PROBE_SECONDS + 1.0]
	_check(not bool(Pack.evaluate_fragment(wrong_timing).get("ok", true)), "out-of-window activation timing must fail closed")
	var untrusted_runtime := fragment.duplicate(true)
	(untrusted_runtime["measurements"] as Dictionary)[atlas_key]["runtime_evidence"]["process_delta_seconds"] = 1.0 / 30.0
	_check(not bool(Pack.evaluate_fragment(untrusted_runtime).get("ok", true)), "a non-fixed runtime measurement must fail closed")
	# FAN-2413: a recorded run_modifiers/stats value that no longer matches the
	# scenario_manifest-derived formula (e.g. a substituted hidden-unlock state)
	# must fail closed, not merely be type-checked.
	var tampered_modifiers := fragment.duplicate(true)
	var tampered_measurement: Dictionary = (tampered_modifiers["measurements"] as Dictionary)[atlas_key]
	var tampered_formula: Dictionary = (tampered_measurement["formula"] as Dictionary).duplicate(true)
	var tampered_run_mods: Dictionary = (tampered_formula["run_modifiers"] as Dictionary).duplicate(true)
	tampered_run_mods["money_gain_multiplier"] = float(tampered_run_mods.get("money_gain_multiplier", 1.0)) + 1.0
	tampered_formula["run_modifiers"] = tampered_run_mods
	tampered_measurement["formula"] = tampered_formula
	_check(not bool(Pack.evaluate_fragment(tampered_modifiers).get("ok", true)), "run_modifiers that disagree with the scenario_manifest-derived formula must fail closed")
	var tampered_manifest := fragment.duplicate(true)
	var mutated_manifest: Dictionary = (tampered_manifest["scenario_manifest"] as Dictionary).duplicate(true)
	var mutated_atlas50: Dictionary = (mutated_manifest["class_atlas50"] as Dictionary).duplicate(true)
	mutated_atlas50["atlas_spend"] = 55
	mutated_manifest["class_atlas50"] = mutated_atlas50
	tampered_manifest["scenario_manifest"] = mutated_manifest
	_check(not bool(Pack.evaluate_fragment(tampered_manifest).get("ok", true)), "a substituted scenario manifest must fail closed")


func _fixture_fragment() -> Dictionary:
	var measurements := {}
	for class_value in Pack.class_ids():
		var class_id := str(class_value)
		for scenario_value in Pack.PLAYABLE_SCENARIOS:
			var scenario_id := str(scenario_value)
			var formula := Pack.class_formula(class_id, scenario_id)
			var starts_activated := int(formula.get("expected_initial_activations", 0)) == 1
			var activation_count := 1
			var first_frame := 0 if starts_activated else Pack.FIXED_FPS
			var ultimate_source := {"damage": 10.0, "hits": 1, "by_mechanic": {"fixture_activation": {"damage": 10.0, "hits": 1, "first_frame": first_frame}}}
			var measurement := {
				"class_id": class_id,
				"scenario": scenario_id,
				"seed": Pack.SEED,
				"frame_count": Pack.PROBE_FRAMES,
				"duration_seconds": Pack.PROBE_SECONDS,
				"initial_charge": formula.get("start_charge", 0.0),
				"initial_activation_count": formula.get("expected_initial_activations", 0),
				"activation_count": activation_count,
				"activation_timing_seconds": [0.0 if starts_activated else 1.0],
				"runtime_evidence": _trusted_runtime_evidence(),
				"ultimate_source": ultimate_source,
				"sustain_source": {"damage": 1.0, "hits": 1},
				"attribution": {
					"ultimate_event_count": int(ultimate_source.get("hits", 0)),
					"missing_ultimate_event_id_count": 0,
					"duplicate_ultimate_event_id_count": 0,
					"invalid_source_count": 0,
				},
				"formula": formula,
			}
			measurements["%s|%s" % [class_id, scenario_id]] = measurement
	return {"fragment_schema": Pack.FRAGMENT_SCHEMA, "pack_id": Pack.PACK_ID, "pack_contract": Pack.PACK_CONTRACT, "issue": "FAN-2412", "contract": Pack.contract(), "runtime_evidence": _trusted_runtime_evidence(), "scenario_manifest": Pack.scenario_manifest(), "per_weapon_sustain": Pack.per_weapon_sustain_rows(), "measurements": measurements}


func _trusted_runtime_evidence() -> Dictionary:
	return {"trusted": true, "fixed_fps": Pack.FIXED_FPS, "process_delta_seconds": 1.0 / float(Pack.FIXED_FPS), "process_fps": float(Pack.FIXED_FPS), "sample_count": Pack.FIXED_STEP_SAMPLE_COUNT}


func _verify_committed_fragment() -> void:
	_check(FileAccess.file_exists(FRAGMENT_PATH), "committed ultimate/Atlas fragment must exist")
	if not FileAccess.file_exists(FRAGMENT_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FRAGMENT_PATH))
	_check(parsed is Dictionary, "committed ultimate/Atlas fragment must parse")
	if parsed is Dictionary:
		var result := Pack.evaluate_fragment(parsed as Dictionary)
		for error_value in result.get("errors", []):
			_check(false, "fragment: %s" % error_value)
		_check(str((parsed as Dictionary).get("verdict", "")) == "green", "committed fragment must record a green verdict")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _finish() -> void:
	if _errors.is_empty():
		print("ultimate_atlas_attribution_test: PASS")
		quit(0)
		return
	for error_value in _errors:
		push_error("ultimate_atlas_attribution_test: %s" % error_value)
	quit(1)
