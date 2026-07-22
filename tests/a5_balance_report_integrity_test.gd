extends SceneTree

# FAN-1438: fail-closed integrity guard for the committed A5 report artifacts.

const PD := preload("res://scripts/progression_data.gd")
const Meta := preload("res://scripts/meta_progression.gd")
const PlayerScript := preload("res://scripts/player.gd")
const CodexData := preload("res://scripts/codex_data.gd")
const Schema6 := preload("res://scripts/constellation_schema6_data.gd")
const Generator := preload("res://tools/a5_balance_report.gd")

var _errors := PackedStringArray()


func _initialize() -> void:
	var raw_text := _read_text(Generator.RAW_PATH)
	var report_text := _read_text(Generator.REPORT_PATH)
	var raw = JSON.parse_string(raw_text)
	_check(raw is Dictionary, "raw.json must parse as an object")
	if not raw is Dictionary:
		_finish()
		return
	var dataset := raw as Dictionary
	_check(str(dataset.get("schema", "")) == "fan1438.a5-balance.v1", "raw schema mismatch")
	_check(str(dataset.get("issue_id", "")) == "FAN-1438", "issue id mismatch")
	_check(str((dataset.get("source", {}) as Dictionary).get("commit", "")) not in ["", "UNSPECIFIED", "TEST"], "source commit is not pinned")
	_check(str((dataset.get("source", {}) as Dictionary).get("tree", "")) not in ["", "UNSPECIFIED", "TEST"], "source tree is not pinned")
	_check(str(dataset.get("dataset_digest_sha256", "")).length() == 64, "dataset digest is missing")
	_validate_dataset_digest(dataset)
	_validate_roster(dataset)
	_validate_builds(dataset)
	_validate_meta(dataset)
	_validate_weapon_rows(dataset)
	_validate_class_rows(dataset)
	_validate_class_ultimate_oracle(dataset)
	_validate_live_coverage(dataset)
	_validate_csv(dataset)
	_validate_markdown(dataset, report_text)
	_finish()


func _validate_roster(dataset: Dictionary) -> void:
	var expected_classes: Array = PD.character_ids()
	var expected_pairs := []
	for class_id_value in expected_classes:
		var class_id := str(class_id_value)
		for weapon_id_value in PD.weapon_ids(class_id):
			expected_pairs.append("%s/%s" % [class_id, str(weapon_id_value)])
	var roster: Dictionary = dataset.get("roster", {})
	_check(roster.get("class_ids", []) == expected_classes, "raw class roster differs from ProgressionData.character_ids()")
	_check(roster.get("pair_keys", []) == expected_pairs, "raw pair roster differs from WEAPONS_BY_CLASS")
	_check(int(roster.get("weapon_pair_count", -1)) == expected_pairs.size(), "raw pair count mismatch")


func _validate_builds(dataset: Dictionary) -> void:
	var builds: Dictionary = dataset.get("builds", {})
	for class_id_value in PD.character_ids():
		var class_id := str(class_id_value)
		var build: Dictionary = builds.get(class_id, {})
		_check(int(build.get("level20_points", -1)) == Generator.LEVEL20_POINTS, "%s level20 allocation is not 19 points" % class_id)
		var base: Dictionary = build.get("level1_stats", {})
		var level20: Dictionary = build.get("level20_stats", {})
		var sum := 0
		for stat_id in base:
			var delta := float(level20.get(stat_id, 0.0)) - float(base.get(stat_id, 0.0))
			_check(delta >= 0.0 and is_equal_approx(delta, round(delta)), "%s/%s delta is not a nonnegative integer" % [class_id, stat_id])
			sum += int(round(delta))
		_check(sum == Generator.LEVEL20_POINTS, "%s recomputed point sum is %d" % [class_id, sum])


func _validate_meta(dataset: Dictionary) -> void:
	for class_id_value in PD.character_ids():
		var class_id := str(class_id_value)
		var nodes := Meta.constellation_nodes(class_id)
		var spend := 0
		var hidden := 0
		for raw_node in nodes:
			var node: Dictionary = raw_node
			spend += int(node.get("cost", 0))
			if str(node.get("role", "")) == "hidden":
				hidden += 1
		_check(nodes.size() == 21, "%s constellation must have 21 nodes" % class_id)
		_check(spend == 20, "%s constellation spend must be 20" % class_id)
		_check(hidden == 2, "%s constellation must have two hidden purchases" % class_id)
	var scenarios: Dictionary = dataset.get("scenarios", {})
	var meta_builds: Dictionary = dataset.get("meta_builds", {})
	var legal: Dictionary = scenarios.get("class_atlas50", {})
	var upper: Dictionary = scenarios.get("class_atlas59_upper", {})
	_check(int(legal.get("atlas_spend", -1)) == Meta.STARDUST_CAP, "legal Atlas spend is not 50")
	_check(legal.get("excluded_ids", []) == Generator.ATLAS50_EXCLUSIONS, "legal Atlas exclusion set changed")
	_check(bool(legal.get("playable", false)), "legal Atlas is not marked playable")
	_check(int(upper.get("atlas_spend", -1)) == Meta.atlas_total_cost(), "upper Atlas spend is not the canonical total")
	_check(not bool(upper.get("playable", true)), "59-dust upper bound is marked playable")
	_check(str(upper.get("label", "")) == Generator.NON_PLAYABLE_LABEL, "59-dust upper-bound label mismatch")
	_check(_connected(legal.get("atlas_ids", [])), "legal Atlas node set is disconnected")
	_check(_connected(upper.get("atlas_ids", [])), "full Atlas node set is disconnected")
	for class_id_value in PD.character_ids():
		var class_id := str(class_id_value)
		var build: Dictionary = meta_builds.get(class_id, {})
		_check((build.get("purchased_ids", []) as Array).size() == 20, "%s raw meta build does not list all 20 purchases" % class_id)
		_check(int(build.get("spend", -1)) == 20, "%s raw meta spend is not 20" % class_id)
		_check((build.get("hidden_reveal_facts", []) as Array).size() == 2, "%s raw hidden reveal facts incomplete" % class_id)
		_check((build.get("weapon_profile_node_ids", {}) as Dictionary).size() == PD.weapon_ids(class_id).size(), "%s raw weapon profile map incomplete" % class_id)


func _connected(ids_value) -> bool:
	var ids: Array = ids_value if ids_value is Array else []
	var selected := {}
	for node_id in ids:
		selected[str(node_id)] = true
	var reached := {"atlas_hub": true}
	var frontier := ["atlas_hub"]
	while not frontier.is_empty():
		var current := str(frontier.pop_back())
		for neighbor_value in Meta.node_by_id(current).get("adj", []):
			var neighbor := str(neighbor_value)
			if selected.has(neighbor) and not reached.has(neighbor):
				reached[neighbor] = true
				frontier.append(neighbor)
	for node_id in ids:
		if not reached.has(str(node_id)):
			return false
	return true


func _validate_weapon_rows(dataset: Dictionary) -> void:
	var rows: Array = dataset.get("weapon_rows", [])
	var pair_count := int((dataset.get("roster", {}) as Dictionary).get("weapon_pair_count", 0))
	var expected_count := pair_count * Generator.LEVELS.size() * Generator.SCENARIO_IDS.size()
	_check(rows.size() == expected_count, "weapon row count %d != %d" % [rows.size(), expected_count])
	var keys := {}
	var baselines := {}
	for row_value in rows:
		var row: Dictionary = row_value
		var key := str(row.get("key", ""))
		_check(not keys.has(key), "duplicate weapon key %s" % key)
		keys[key] = true
		_check(not bool(row.get("ultimate_included", true)), "%s includes ultimate in weapon output" % key)
		_check(str(row.get("playstyle", "")).length() > 4, "%s lacks playstyle" % key)
		_check(str(row.get("strengths", "")).length() > 4, "%s lacks strengths" % key)
		_check(str(row.get("weaknesses", "")).length() > 4, "%s lacks weaknesses" % key)
		_check(int(row.get("runs", 0)) >= 1, "%s lacks run count" % key)
		_check(float(row.get("solo_variance_dpm2", -1.0)) >= 0.0 and float(row.get("crowd_variance_dpm2", -1.0)) >= 0.0, "%s lacks nonnegative variance" % key)
		for metric in ["solo_dpm", "crowd_10_total_dpm", "crowd_10_per_target_dpm", "hp", "ehp", "ttd_seconds", "pickup_radius", "move_speed"]:
			var value := float(row.get(metric, -1.0))
			_check(is_finite(value) and value >= 0.0, "%s %s is invalid" % [key, metric])
		_check(is_equal_approx(float(row.get("crowd_10_per_target_dpm", -1.0)), float(row.get("crowd_10_total_dpm", 0.0)) / Generator.TARGET_COUNT), "%s per-target DPM identity failed" % key)
		if str(row.get("scenario", "")) == "no_meta":
			baselines["%s|%s|%d" % [row["class_id"], row["weapon_id"], row["level"]]] = row
	var expected_keys := {}
	for pair_value in dataset["roster"]["pair_keys"]:
		var pair := str(pair_value).split("/", true, 1)
		for level in Generator.LEVELS:
			for scenario_id in Generator.SCENARIO_IDS:
				expected_keys["%s|%s|%d|%s" % [pair[0], pair[1], level, scenario_id]] = true
	_check(keys == expected_keys, "weapon key cross-product mismatch")
	for row_value in rows:
		var row: Dictionary = row_value
		var baseline: Dictionary = baselines["%s|%s|%d" % [row["class_id"], row["weapon_id"], row["level"]]]
		for metric in ["solo_dpm", "crowd_10_total_dpm", "ehp", "ttd_seconds", "pickup_radius", "move_speed"]:
			var expected_abs := snappedf(float(row[metric]) - float(baseline[metric]), 0.01)
			_check(is_equal_approx(float(row.get("%s_delta_abs" % metric, INF)), expected_abs), "%s %s absolute delta mismatch" % [row["key"], metric])


func _validate_class_rows(dataset: Dictionary) -> void:
	var rows: Array = dataset.get("class_rows", [])
	var expected := PD.character_ids().size() * Generator.LEVELS.size() * Generator.SCENARIO_IDS.size()
	_check(rows.size() == expected, "class-kit row count %d != %d" % [rows.size(), expected])
	var keys := {}
	for row_value in rows:
		var row: Dictionary = row_value
		keys[str(row.get("key", ""))] = true
		_check((row.get("roles", []) as Array).size() == 3, "%s must list exactly three weapon roles" % row.get("key", "?"))
		_check(str(row.get("strengths", "")).length() > 3, "%s lacks strengths" % row.get("key", "?"))
		_check(str(row.get("weaknesses", "")).length() > 3, "%s lacks weaknesses" % row.get("key", "?"))
		for score_key in ["solo_score", "aoe_score", "defense_score", "convenience_relative"]:
			_check(float(row.get(score_key, 0.0)) > 0.0, "%s lacks %s" % [row.get("key", "?"), score_key])
	_check(keys.size() == expected, "class-kit keys are not unique")


func _validate_class_ultimate_oracle(dataset: Dictionary) -> void:
	# This deliberately does not call the report generator's modifier helper or
	# class-row implementation. It rebuilds every class ultimate from raw level
	# stats and canonical runtime APIs, which catches a second attribute-flat pass.
	var rows: Array = dataset.get("class_rows", [])
	var meta_rows := 0
	var numerically_distinct_double_rows := 0
	var numerically_neutral_double_rows := 0
	for row_value in rows:
		var row: Dictionary = row_value
		var class_id := str(row.get("class_id", ""))
		var level := int(row.get("level", 0))
		var scenario_id := str(row.get("scenario", ""))
		var build: Dictionary = (dataset.get("builds", {}) as Dictionary).get(class_id, {})
		var stats: Dictionary = (build.get("level1_stats", {}) if level == 1 else build.get("level20_stats", {})).duplicate(true)
		var state := _oracle_state(dataset, class_id, scenario_id)
		var mods: Dictionary = Meta.skill_modifiers_for_class(state, class_id) if scenario_id != "no_meta" else {}
		var run_mods := _oracle_a5_run_modifiers(class_id)
		_apply_meta_once(stats, run_mods, mods)
		var expected := _oracle_first_minute_ultimate(class_id, stats, run_mods, mods)
		_check(is_equal_approx(float(row.get("first_minute_ultimate_damage", -1.0)), expected), "%s class ultimate is not the single-application runtime value" % row.get("key", "?"))
		_check(is_equal_approx(float(row.get("atlas_start_charge", -1.0)), snappedf(float(mods.get("ult_start_charge", 0.0)), 0.01)), "%s Atlas ultimate charge attribution differs from canonical meta state" % row.get("key", "?"))
		if scenario_id == "no_meta":
			continue
		meta_rows += 1
		var double_stats := stats.duplicate(true)
		_apply_attribute_flats(double_stats, mods)
		var double_applied := _oracle_first_minute_ultimate(class_id, double_stats, run_mods, mods)
		if is_equal_approx(expected, double_applied):
			numerically_neutral_double_rows += 1
		else:
			numerically_distinct_double_rows += 1
			_check(not is_equal_approx(float(row.get("first_minute_ultimate_damage", -1.0)), double_applied), "%s still stores a double-applied meta ultimate" % row.get("key", "?"))
	_check(meta_rows == 102, "meta ultimate oracle covers %d rows, expected 102" % meta_rows)
	_check(numerically_distinct_double_rows == 99 and numerically_neutral_double_rows == 3, "double-application regression shape changed: distinct=%d neutral=%d" % [numerically_distinct_double_rows, numerically_neutral_double_rows])


func _oracle_state(dataset: Dictionary, class_id: String, scenario_id: String) -> Dictionary:
	var state := Meta.default_state()
	state["ascension_levels"] = {class_id: 5}
	if scenario_id == "no_meta":
		return state
	var build: Dictionary = (dataset.get("meta_builds", {}) as Dictionary).get(class_id, {})
	var purchased: Array = (build.get("purchased_ids", []) as Array).duplicate()
	state["hidden_reveal_facts"] = {class_id: (build.get("hidden_reveal_facts", []) as Array).duplicate()}
	if scenario_id in ["class_atlas50", "class_atlas59_upper"]:
		var scenario: Dictionary = (dataset.get("scenarios", {}) as Dictionary).get(scenario_id, {})
		for atlas_id in scenario.get("atlas_ids", []):
			purchased.append(str(atlas_id))
		var monster_ids := []
		for raw_monster in CodexData.monsters():
			monster_ids.append(str((raw_monster as Dictionary).get("id", "")))
		state["discovered_monsters"] = monster_ids
		state["secret_boss_defeated"] = true
	state["skill_nodes"] = purchased
	return state


func _oracle_a5_run_modifiers(class_id: String) -> Dictionary:
	var run_mods := {}
	var ascension: Dictionary = PD.ascension_mods(class_id, 5)
	for key_value in ascension:
		var key := str(key_value)
		var value := float(ascension[key_value])
		if key.ends_with("_multiplier"):
			run_mods[key] = float(run_mods.get(key, 1.0)) * value
		else:
			run_mods[key] = float(run_mods.get(key, 0.0)) + value
	var difficulty := PD.ascension_difficulty_mods(5)
	run_mods["xp_gain_multiplier"] = float(run_mods.get("xp_gain_multiplier", 1.0)) * float(difficulty.get("reward_mult", 1.0))
	run_mods["money_gain_multiplier"] = float(run_mods.get("money_gain_multiplier", 1.0)) * float(difficulty.get("reward_mult", 1.0))
	run_mods["healing_multiplier"] = float(run_mods.get("healing_multiplier", 1.0)) * float(difficulty.get("healing_mult", 1.0))
	run_mods["max_health_multiplier"] = float(run_mods.get("max_health_multiplier", 1.0)) * float(difficulty.get("player_max_hp_mult", 1.0))
	return run_mods


func _apply_meta_once(stats: Dictionary, run_mods: Dictionary, mods: Dictionary) -> void:
	_apply_attribute_flats(stats, mods)
	for source_key in PlayerScript.META_SKILL_MULT_MAP:
		if mods.has(source_key):
			var run_key := str(PlayerScript.META_SKILL_MULT_MAP[source_key])
			run_mods[run_key] = float(run_mods.get(run_key, 1.0)) * (1.0 + float(mods[source_key]))
	for source_key in PlayerScript.META_SKILL_FLAT_MAP:
		if mods.has(source_key):
			var run_key := str(PlayerScript.META_SKILL_FLAT_MAP[source_key])
			run_mods[run_key] = float(run_mods.get(run_key, 0.0)) + float(mods[source_key])


func _apply_attribute_flats(stats: Dictionary, mods: Dictionary) -> void:
	for source_key in PlayerScript.META_SKILL_ATTRIBUTE_FLAT_MAP:
		if mods.has(source_key):
			var stat_key := str(PlayerScript.META_SKILL_ATTRIBUTE_FLAT_MAP[source_key])
			stats[stat_key] = float(stats.get(stat_key, 0.0)) + float(mods[source_key])


func _oracle_first_minute_ultimate(class_id: String, stats: Dictionary, run_mods: Dictionary, mods: Dictionary) -> float:
	var first_weapon := str(PD.weapon_ids(class_id)[0])
	var config := PD.weapon(class_id, first_weapon)
	config["character_id"] = class_id
	var params := PD.derived_parameters(stats, run_mods, config)
	var ultimate := PD._budget_ultimate_dps(class_id, params)
	var result := (float(ultimate.get("solo", 0.0)) + float(ultimate.get("aoe", 0.0))) * 30.0
	var start_charge := float(mods.get("ult_start_charge", 0.0))
	if start_charge > 0.0:
		var ultimate_config := PD.ultimate_config(class_id)
		var base_damage := maxf(float(params.get("damage", 1.0)), float(params.get("magic_damage", 1.0)))
		var activation_damage := base_damage * float(ultimate_config.get("damage", 1.0)) * float(params.get("ultimate_multiplier", 1.0))
		result += activation_damage * start_charge
	return snappedf(result, 0.01)


func _validate_live_coverage(dataset: Dictionary) -> void:
	var parity: Array = dataset.get("formula_live_parity", [])
	var expected_pairs: Array = dataset["roster"]["pair_keys"]
	_check(parity.size() == expected_pairs.size(), "live parity must cover every runtime pair")
	var actual_pairs := []
	var actual_modes := {}
	var actual_finals := {}
	for row_value in parity:
		var row: Dictionary = row_value
		actual_pairs.append(str(row.get("pair", "")))
		actual_modes[str(row.get("attack_mode", ""))] = true
		actual_finals[str(row.get("final_mechanic", ""))] = true
		_check((row.get("solo_samples_dpm", []) as Array).size() == Generator.LIVE_SEEDS.size(), "%s solo sample count mismatch" % row.get("pair", "?"))
		_check((row.get("pack_samples_dpm", []) as Array).size() == Generator.LIVE_SEEDS.size(), "%s pack sample count mismatch" % row.get("pair", "?"))
	_check(actual_pairs == expected_pairs, "live parity pair order/set mismatch")
	var expected_modes := {}
	var expected_finals := {}
	for pair_value in expected_pairs:
		var pair := str(pair_value).split("/", true, 1)
		var config := PD.weapon(str(pair[0]), str(pair[1]))
		expected_modes[str(config.get("attack_mode", config.get("attack_shape", "single")))] = true
		for raw_branch in Schema6.class_entry(str(pair[0])).get("weapon_branches", []):
			if str((raw_branch as Dictionary).get("weapon_id", "")) != str(pair[1]):
				continue
			for raw_node in (raw_branch as Dictionary).get("nodes", []):
				if str((raw_node as Dictionary).get("role", "")) == "weapon_final":
					expected_finals[str((raw_node as Dictionary).get("mechanic_id", ""))] = true
	_check(actual_modes == expected_modes, "live attack-mode coverage set mismatch")
	_check(actual_finals == expected_finals, "live nonlinear final coverage set mismatch")


func _validate_dataset_digest(dataset: Dictionary) -> void:
	var canonical: Dictionary = dataset.duplicate(true)
	canonical.erase("dataset_digest_sha256")
	var expected := _sha256(JSON.stringify(canonical, "", true, true))
	_check(str(dataset.get("dataset_digest_sha256", "")) == expected, "raw dataset digest does not match the canonical payload")


func _validate_csv(dataset: Dictionary) -> void:
	var file := FileAccess.open(Generator.CSV_PATH, FileAccess.READ)
	_check(file != null, "per_weapon.csv is missing")
	if file == null:
		return
	var header := file.get_csv_line()
	var indices := {}
	var valid_header := true
	for column in ["key", "class_id", "weapon_id", "level", "scenario", "solo_dpm", "crowd_10_total_dpm", "hp", "ehp", "ttd_seconds", "ult_start_charge"]:
		var index := Array(header).find(column)
		_check(index >= 0, "CSV lacks %s column" % column)
		indices[column] = index
		valid_header = valid_header and index >= 0
	if not valid_header:
		file.close()
		return
	var rows_by_key := {}
	while not file.eof_reached():
		var cells := file.get_csv_line()
		if cells.size() == 1 and str(cells[0]) == "":
			continue
		var key_index := int(indices["key"])
		if cells.size() > key_index:
			rows_by_key[str(cells[key_index])] = cells
	file.close()
	_check(rows_by_key.size() == (dataset.get("weapon_rows", []) as Array).size(), "CSV row/key count mismatch")
	for row_value in dataset["weapon_rows"]:
		var row: Dictionary = row_value
		var key := str(row.get("key", ""))
		_check(rows_by_key.has(key), "CSV missing key %s" % key)
		if not rows_by_key.has(key):
			continue
		var cells = rows_by_key[key]
		_check(str(cells[int(indices["class_id"])]) == str(row.get("class_id", "")), "CSV class differs for %s" % key)
		_check(str(cells[int(indices["weapon_id"])]) == str(row.get("weapon_id", "")), "CSV weapon differs for %s" % key)
		_check(int(cells[int(indices["level"])]) == int(row.get("level", -1)), "CSV level differs for %s" % key)
		_check(str(cells[int(indices["scenario"])]) == str(row.get("scenario", "")), "CSV scenario differs for %s" % key)
		for metric in ["solo_dpm", "crowd_10_total_dpm", "hp", "ehp", "ttd_seconds", "ult_start_charge"]:
			_check(is_equal_approx(float(cells[int(indices[metric])]), float(row.get(metric, INF))), "CSV %s differs for %s" % [metric, key])


func _validate_markdown(dataset: Dictionary, report_text: String) -> void:
	_check(report_text.contains("## Per-weapon matrix"), "Markdown lacks per-weapon matrix")
	_check(report_text.contains("## Formula / live parity"), "Markdown lacks formula/live section")
	_check(report_text.contains(Generator.NON_PLAYABLE_LABEL), "Markdown lacks mandatory non-playable label")
	_check(report_text.contains("changes no balance values") or report_text.contains("No balance values"), "Markdown does not state the no-balance-change scope")
	_check(report_text.contains("applies class/Atlas attribute and run modifiers exactly once"), "Markdown does not state the single-application ultimate rule")
	var source: Dictionary = dataset.get("source", {})
	_check(report_text.contains("Source commit `%s` (tree `%s`, timestamp `%s`)" % [source.get("commit", ""), source.get("tree", ""), source.get("commit_timestamp", "")]), "Markdown source provenance differs from raw.json")
	_check(report_text.contains("Dataset digest: `%s`" % dataset.get("dataset_digest_sha256", "")), "Markdown dataset digest differs from raw.json")
	for row_value in dataset.get("class_rows", []):
		var row: Dictionary = row_value
		var prefix := "| %s | %d | %s | %s | %.3f | %.3f | %.3f | %.3f | %.2f |" % [row["class_id"], row["level"], row["scenario"], "; ".join(row["roles"]), row["solo_score"], row["aoe_score"], row["defense_score"], row["convenience_relative"], row["first_minute_ultimate_damage"]]
		_check(report_text.contains(prefix), "Markdown class row differs from raw.json for %s" % row.get("key", "?"))


func _sha256(text: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return context.finish().hex_encode()


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var result := file.get_as_text()
	file.close()
	return result


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _finish() -> void:
	if not _errors.is_empty():
		for error in _errors:
			push_error(error)
		push_error("FAN-1438 A5 balance report integrity test failed (%d errors)." % _errors.size())
		quit(1)
		return
	print("FAN-1438 A5 report integrity passed dynamic roster, 19-point builds, 50/59 Atlas legality, 408-row matrix, class kits, live mechanic coverage, and CSV/Markdown evidence.")
	quit(0)
