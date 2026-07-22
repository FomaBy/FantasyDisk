extends SceneTree

# FAN-1438: fail-closed integrity guard for the committed A5 report artifacts.

const PD := preload("res://scripts/progression_data.gd")
const Meta := preload("res://scripts/meta_progression.gd")
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
	_validate_roster(dataset)
	_validate_builds(dataset)
	_validate_meta(dataset)
	_validate_weapon_rows(dataset)
	_validate_class_rows(dataset)
	_validate_live_coverage(dataset)
	_validate_csv(dataset)
	_check(report_text.contains("## Per-weapon matrix"), "Markdown lacks per-weapon matrix")
	_check(report_text.contains("## Formula / live parity"), "Markdown lacks formula/live section")
	_check(report_text.contains(Generator.NON_PLAYABLE_LABEL), "Markdown lacks mandatory non-playable label")
	_check(report_text.contains("changes no balance values") or report_text.contains("No balance values"), "Markdown does not state the no-balance-change scope")
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


func _validate_csv(dataset: Dictionary) -> void:
	var file := FileAccess.open(Generator.CSV_PATH, FileAccess.READ)
	_check(file != null, "per_weapon.csv is missing")
	if file == null:
		return
	var header := file.get_csv_line()
	var key_index := Array(header).find("key")
	_check(key_index >= 0, "CSV lacks key column")
	var keys := {}
	while not file.eof_reached():
		var cells := file.get_csv_line()
		if cells.size() == 1 and str(cells[0]) == "":
			continue
		if key_index >= 0 and cells.size() > key_index:
			keys[str(cells[key_index])] = true
	file.close()
	_check(keys.size() == (dataset.get("weapon_rows", []) as Array).size(), "CSV row/key count mismatch")
	for row_value in dataset["weapon_rows"]:
		_check(keys.has(str((row_value as Dictionary).get("key", ""))), "CSV missing key %s" % (row_value as Dictionary).get("key", "?"))


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
