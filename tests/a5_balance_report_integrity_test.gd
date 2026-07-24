extends SceneTree

# FAN-1438: fail-closed integrity guard for the committed A5 report artifacts.

const PD := preload("res://scripts/progression_data.gd")
const Meta := preload("res://scripts/meta_progression.gd")
const PlayerScript := preload("res://scripts/player.gd")
const CodexData := preload("res://scripts/codex_data.gd")
const Schema6 := preload("res://scripts/constellation_schema6_data.gd")
const Generator := preload("res://tools/a5_balance_report.gd")
# FAN-1641: external pin of the current integration-base (b8909e30) 51x4 digest,
# so a self-consistent lineage-manifest tamper cannot pass the integrity gate.
const CURRENT_BASE_PROJECTION_SHA256 := "ac7710a043848eb4fe895237092c3aa2458ab4c1092258a6ba03d5f02b635494"
# FAN-1649: external pin of the current integration-base full canonical telemetry
# payload aggregate over the 309 per-sample digests, anchoring the pinned map the
# same way as the projection digest above.
const CURRENT_BASE_TELEMETRY_FULL_SHA256 := "ad1d9a7ae1a36b087370b33582601a51b880d8cf102d3adc461fdb3e1c5d307f"
const LIVE_TELEMETRY_SCHEMA := "fan1511.runtime-telemetry.v2"

var _errors := PackedStringArray()


func _initialize() -> void:
	var raw_artifact := Generator.read_raw_artifact()
	_check(bool(raw_artifact.get("ok", false)), "raw.json.gz must decode and validate: %s" % raw_artifact.get("error", "unknown error"))
	var raw_text := str(raw_artifact.get("text", ""))
	var report_text := _read_text(Generator.REPORT_PATH)
	var raw = JSON.parse_string(raw_text)
	_check(raw is Dictionary, "raw.json.gz must parse as an object")
	if not raw is Dictionary:
		_finish()
		return
	var dataset := raw as Dictionary
	_check(str(dataset.get("schema", "")) == "fan1438.a5-balance.v2", "raw schema mismatch")
	_check(str(dataset.get("issue_id", "")) == "FAN-1438", "issue id mismatch")
	_check(str((dataset.get("source", {}) as Dictionary).get("commit", "")) not in ["", "UNSPECIFIED", "TEST"], "source commit is not pinned")
	_check(str((dataset.get("source", {}) as Dictionary).get("tree", "")) not in ["", "UNSPECIFIED", "TEST"], "source tree is not pinned")
	_validate_source_provenance(dataset)
	_validate_raw_artifact(dataset, raw_text)
	_check(bool(Generator.verify_dataset_digest(dataset).get("ok", false)), "dataset digest does not match canonical raw payload")
	_validate_roster(dataset)
	_validate_builds(dataset)
	_validate_meta(dataset)
	_validate_weapon_rows(dataset)
	_validate_class_rows(dataset)
	_validate_class_corridor(dataset, report_text)
	_validate_class_ultimate_oracle(dataset)
	_validate_live_coverage(dataset)
	_validate_csv(dataset)
	_validate_markdown(dataset, report_text)
	_validate_oracle_lineage(dataset, raw_text)
	_finish()


# FAN-1641: the committed oracle and the checked-in lineage manifest must stay
# fail-closed consistent. The full git-backed commit-level causality (ancestry,
# inventory segmentation, candidate zero-delta gate, and negative mutations) lives
# in tests/a5_balance_report_parity_test.gd.
func _validate_oracle_lineage(dataset: Dictionary, raw_text: String) -> void:
	var loaded := Generator.load_oracle_lineage()
	_check(bool(loaded.get("ok", false)), "oracle lineage manifest must load: %s" % loaded.get("error", "unknown"))
	if not bool(loaded.get("ok", false)):
		return
	var manifest: Dictionary = loaded.get("manifest", {})
	var lineage := Generator.verify_oracle_lineage(manifest, dataset, raw_text)
	_check(bool(lineage.get("ok", false)), "committed oracle must match the lineage manifest: %s" % "; ".join(lineage.get("errors", [])))
	_check(str(lineage.get("current_digest", "")) == CURRENT_BASE_PROJECTION_SHA256, "reconstructed current digest differs from the externally pinned current base")
	_check(str((manifest.get("current_integration_base", {}) as Dictionary).get("projection_sha256", "")) == CURRENT_BASE_PROJECTION_SHA256, "manifest current-base digest differs from the externally pinned current base")
	_check(str((manifest.get("historical_oracle", {}) as Dictionary).get("dataset_digest_sha256", "")) == str(dataset.get("dataset_digest_sha256", "")), "lineage manifest historical dataset digest differs from committed raw.json.gz")
	var drifted := manifest.duplicate(true)
	(drifted.get("current_integration_base", {}) as Dictionary)["projection_sha256"] = "0000000000000000000000000000000000000000000000000000000000000000"
	_check(not bool(Generator.verify_oracle_lineage(drifted, dataset, raw_text).get("ok", true)), "drifted manifest current-base digest must fail closed")
	# FAN-1649: the pinned current-base FULL telemetry payload is externally anchored
	# and internally self-consistent (309 samples, aggregate == full_sha256 == const).
	var pinned: Dictionary = (manifest.get("current_integration_base", {}) as Dictionary).get("telemetry_full", {})
	_check(not pinned.is_empty(), "manifest must pin a current-base full telemetry payload")
	var pinned_digests: Dictionary = pinned.get("sample_digests", {})
	_check(int(pinned.get("sample_count", -1)) == 309 and pinned_digests.size() == 309, "pinned full telemetry must cover all 309 samples")
	_check(str(pinned.get("telemetry_schema", "")) == LIVE_TELEMETRY_SCHEMA, "pinned full telemetry schema mismatch")
	var keys := pinned_digests.keys()
	keys.sort()
	var aggregate := ""
	for key in keys:
		aggregate += "%s|%s\n" % [str(key), str(pinned_digests[key])]
	_check(Generator._sha256(aggregate) == str(pinned.get("full_sha256", "")), "pinned full telemetry aggregate is internally inconsistent")
	_check(str(pinned.get("full_sha256", "")) == CURRENT_BASE_TELEMETRY_FULL_SHA256, "manifest full-telemetry digest differs from the externally pinned current base")
	# A self-consistent tamper (rewrite a sample digest AND recompute the aggregate)
	# stays internally consistent but diverges from the external committed constant.
	var tampered := pinned_digests.duplicate(true)
	tampered[str(keys[0])] = "0000000000000000000000000000000000000000000000000000000000000000"
	var tampered_keys := tampered.keys()
	tampered_keys.sort()
	var tampered_aggregate := ""
	for key in tampered_keys:
		tampered_aggregate += "%s|%s\n" % [str(key), str(tampered[key])]
	_check(Generator._sha256(tampered_aggregate) != CURRENT_BASE_TELEMETRY_FULL_SHA256, "self-consistent full-telemetry tamper must diverge from the external constant")


func _validate_source_provenance(dataset: Dictionary) -> void:
	var source: Dictionary = dataset.get("source", {})
	var verification := Generator.verify_source_provenance(source)
	_check(bool(verification.get("ok", false)), "source provenance is not the exact Git commit/tree/timestamp tuple: %s" % verification.get("error", "unknown error"))
	if not bool(verification.get("ok", false)):
		return
	var expected: Dictionary = verification.get("source", {})
	_check(str(source.get("commit_timestamp", "")) == str(expected.get("commit_timestamp", "")), "source commit_timestamp differs from git show -s --format=%cI")
	var mismatched := source.duplicate(true)
	mismatched["commit_timestamp"] = "1970-01-01T00:00:00Z"
	if str(source.get("commit_timestamp", "")) == str(mismatched["commit_timestamp"]):
		mismatched["commit_timestamp"] = "1970-01-01T00:00:01Z"
	var mismatch_verification := Generator.verify_source_provenance(mismatched)
	_check(not bool(mismatch_verification.get("ok", false)), "source provenance accepts a deliberately mismatched commit_timestamp")


func _validate_raw_artifact(dataset: Dictionary, raw_text: String) -> void:
	_check(not FileAccess.file_exists(Generator.LEGACY_RAW_PATH), "legacy uncompressed raw.json must not remain tracked")
	_check(raw_text == JSON.stringify(dataset, "\t", true, true) + "\n", "decoded raw.json.gz is not canonical JSON serialization")
	var source := FileAccess.open(Generator.RAW_PATH, FileAccess.READ)
	_check(source != null, "raw.json.gz must be readable for corruption test")
	if source == null:
		return
	var bytes := source.get_buffer(source.get_length())
	source.close()
	_check(bytes.size() > 10, "raw.json.gz is unexpectedly short")
	if bytes.size() <= 10:
		return
	bytes[bytes.size() - 1] = int(bytes[bytes.size() - 1]) ^ 1
	var corrupt_path := "user://fan1438_a5_corrupt_raw.json.gz"
	var corrupt := FileAccess.open(corrupt_path, FileAccess.WRITE)
	_check(corrupt != null, "cannot create corrupt gzip validation fixture")
	if corrupt == null:
		return
	corrupt.store_buffer(bytes)
	corrupt.close()
	var corrupt_result := Generator.read_raw_artifact(corrupt_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(corrupt_path))
	_check(not bool(corrupt_result.get("ok", true)), "corrupted raw.json.gz must fail closed")


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


func _validate_class_corridor(dataset: Dictionary, report_text: String) -> void:
	var verifier := Generator.verify_class_corridor_artifacts(dataset)
	_check(bool(verifier.get("ok", false)), "class corridor artifacts must match canonical three-axis status: %s" % "; ".join(verifier.get("errors", [])))
	var expected_count := 0
	var defense_only_rows := []
	for row_value in dataset.get("class_rows", []):
		var row: Dictionary = row_value
		var expected_axes := _strict_corridor_axes(row)
		var actual_status := Generator.class_corridor_status(float(row["solo_score"]), float(row["aoe_score"]), float(row["defense_score"]))
		_check(_axis_names(actual_status.get("axes", [])) == expected_axes, "%s corridor axes differ from strict three-axis oracle" % row.get("key", "?"))
		_check((str(row.get("outlier_flag", "")) != "ok") == not expected_axes.is_empty(), "%s outlier flag does not agree with strict three-axis oracle" % row.get("key", "?"))
		if not expected_axes.is_empty():
			expected_count += 1
		if expected_axes == ["defense"]:
			defense_only_rows.append(row)
			_check(str(row.get("outlier_flag", "")) != "ok", "%s defense-only outlier is marked ok" % row.get("key", "?"))
	_check(expected_count == 120, "three-axis class corridor union is %d, expected 120" % expected_count)
	_check(defense_only_rows.size() == 15, "defense-only class corridor count is %d, expected 15" % defense_only_rows.size())
	var summary: Array = (dataset.get("outliers", {}) as Dictionary).get("class_corridor_80_120", [])
	_check(summary.size() == 120, "raw class corridor summary count is %d, expected 120" % summary.size())
	for row_value in defense_only_rows:
		var row: Dictionary = row_value
		var matching_entries := []
		for entry_value in summary:
			var entry: Dictionary = entry_value
			if str(entry.get("key", "")) == str(row["key"]):
				matching_entries.append(entry)
		_check(matching_entries.size() == 1, "%s defense-only row must have exactly one raw summary entry" % row["key"])
		if matching_entries.size() == 1:
			var entry: Dictionary = matching_entries[0]
			_check(entry.get("axes", []) == ["defense"], "%s summary must explicitly list defense as its only outlier axis" % row["key"])
			_check(is_equal_approx(float(entry.get("defense_vs_median", 0.0)), float(row["defense_score"])), "%s summary defense ratio differs from class row" % row["key"])
	var lower_boundary := Generator.class_corridor_status(0.80, 1.0, 1.0)
	var upper_boundary := Generator.class_corridor_status(1.0, 1.0, 1.20)
	_check(not bool(lower_boundary.get("is_outlier", true)) and str(lower_boundary.get("flag", "")) == "ok", "0.80 must remain inside the class corridor")
	_check(not bool(upper_boundary.get("is_outlier", true)) and str(upper_boundary.get("flag", "")) == "ok", "1.20 must remain inside the class corridor")
	var multi_axis := Generator.class_corridor_status(0.799, 1.201, 0.799)
	_check(_axis_names(multi_axis.get("axes", [])) == ["solo", "AoE", "defense"], "multi-axis corridor status must keep solo/AoE/defense order")
	_check(str(multi_axis.get("flag", "")).contains("solo=0.80×") and str(multi_axis.get("flag", "")).contains("AoE=1.20×") and str(multi_axis.get("flag", "")).contains("defense=0.80×"), "multi-axis flag must name every triggered axis")
	_check(report_text.contains("- Class corridor flags (outside 80–120% of the same level/scenario median across solo, AoE, or defense): **120**."), "Markdown class corridor counter does not publish the three-axis total")
	if defense_only_rows.is_empty():
		return
	var defense_only_key := str((defense_only_rows[0] as Dictionary)["key"])
	var score_mutation := dataset.duplicate(true)
	for row_value in score_mutation["class_rows"]:
		var row: Dictionary = row_value
		if str(row["key"]) == defense_only_key:
			row["defense_score"] = 1.0
			break
	_check(not bool(Generator.verify_class_corridor_artifacts(score_mutation).get("ok", true)), "defense-score mutation must fail closed when flag and summary are stale")
	var flag_mutation := dataset.duplicate(true)
	for row_value in flag_mutation["class_rows"]:
		var row: Dictionary = row_value
		if str(row["key"]) == defense_only_key:
			row["outlier_flag"] = "ok"
			break
	_check(not bool(Generator.verify_class_corridor_artifacts(flag_mutation).get("ok", true)), "defense-only flag mutation must fail closed")
	var summary_mutation := dataset.duplicate(true)
	var mutated_summary: Array = (summary_mutation.get("outliers", {}) as Dictionary).get("class_corridor_80_120", [])
	for index in range(mutated_summary.size()):
		if str((mutated_summary[index] as Dictionary).get("key", "")) == defense_only_key:
			mutated_summary.remove_at(index)
			break
	_check(not bool(Generator.verify_class_corridor_artifacts(summary_mutation).get("ok", true)), "defense-only summary-count mutation must fail closed")


func _strict_corridor_axes(row: Dictionary) -> Array:
	var axes := []
	for axis in [
		{"name": "solo", "score": float(row["solo_score"])},
		{"name": "AoE", "score": float(row["aoe_score"])},
		{"name": "defense", "score": float(row["defense_score"])},
	]:
		var score := float(axis["score"])
		if score < 0.80 or score > 1.20:
			axes.append(str(axis["name"]))
	return axes


func _axis_names(axes: Array) -> Array:
	var names := []
	for axis_value in axes:
		names.append(str((axis_value as Dictionary).get("name", "")))
	return names


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
	_validate_live_telemetry(dataset)


func _validate_live_telemetry(dataset: Dictionary) -> void:
	var verification := Generator.verify_live_telemetry_artifacts(dataset)
	_check(bool(verification.get("ok", false)), "live telemetry contract failed: %s" % "; ".join(verification.get("errors", [])))
	if not bool(verification.get("ok", false)):
		return
	var telemetry: Dictionary = dataset.get("live_telemetry", {})
	var samples: Array = telemetry.get("samples", [])
	var expected_count := int((dataset.get("roster", {}) as Dictionary).get("weapon_pair_count", 0)) * Generator.LIVE_SEEDS.size() * 2 + 3
	_check(samples.size() == expected_count, "telemetry sample count does not cover every parity probe plus three fixtures")
	if samples.is_empty():
		return
	var missing_counter := dataset.duplicate(true)
	var missing_samples: Array = (missing_counter.get("live_telemetry", {}) as Dictionary).get("samples", [])
	var missing_counters: Dictionary = (missing_samples[0] as Dictionary).get("counters", {})
	missing_counters.erase("hits")
	_check(not bool(Generator.verify_live_telemetry_artifacts(missing_counter).get("ok", true)), "missing hit counter must fail closed")
	var duplicate_event := dataset.duplicate(true)
	var duplicate_samples: Array = (duplicate_event.get("live_telemetry", {}) as Dictionary).get("samples", [])
	var duplicate_events: Array = (duplicate_samples[0] as Dictionary).get("events", [])
	duplicate_events.append(duplicate_events[0].duplicate(true))
	_check(not bool(Generator.verify_live_telemetry_artifacts(duplicate_event).get("ok", true)), "duplicated trace event must fail closed")
	var target_cardinality := dataset.duplicate(true)
	var target_samples: Array = (target_cardinality.get("live_telemetry", {}) as Dictionary).get("samples", [])
	var target_counters: Dictionary = (target_samples[0] as Dictionary).get("counters", {})
	target_counters["unique_target_count"] = int(target_counters.get("unique_target_count", 0)) + 1
	_check(not bool(Generator.verify_live_telemetry_artifacts(target_cardinality).get("ok", true)), "target cardinality mismatch must fail closed")
	var source_phase := dataset.duplicate(true)
	var source_samples: Array = (source_phase.get("live_telemetry", {}) as Dictionary).get("samples", [])
	var source_counters: Dictionary = (source_samples[0] as Dictionary).get("counters", {})
	var buckets: Array = source_counters.get("damage_by_source_phase", [])
	buckets[0]["source"] = "formula_label"
	_check(not bool(Generator.verify_live_telemetry_artifacts(source_phase).get("ok", true)), "source/phase misattribution must fail closed")
	var final_count := dataset.duplicate(true)
	var final_count_samples: Array = (final_count.get("live_telemetry", {}) as Dictionary).get("samples", [])
	var final_count_counters: Dictionary = (final_count_samples[0] as Dictionary).get("counters", {})
	final_count_counters["final_event_count"] = int(final_count_counters.get("final_event_count", 0)) + 1
	_check(not bool(Generator.verify_live_telemetry_artifacts(final_count).get("ok", true)), "final event count mismatch must fail closed")
	var final_damage := dataset.duplicate(true)
	var final_damage_samples: Array = (final_damage.get("live_telemetry", {}) as Dictionary).get("samples", [])
	var final_damage_counters: Dictionary = (final_damage_samples[0] as Dictionary).get("counters", {})
	final_damage_counters["final_event_damage"] = float(final_damage_counters.get("final_event_damage", 0.0)) + 1.0
	_check(not bool(Generator.verify_live_telemetry_artifacts(final_damage).get("ok", true)), "final event damage mismatch must fail closed")
	var trace_id := dataset.duplicate(true)
	var trace_samples: Array = (trace_id.get("live_telemetry", {}) as Dictionary).get("samples", [])
	var trace_sample: Dictionary = trace_samples[0]
	trace_sample["trace_id"] = "fan1511:wrong"
	_check(not bool(Generator.verify_live_telemetry_artifacts(trace_id).get("ok", true)), "trace identifier mismatch must fail closed")
	var digest_mutation := dataset.duplicate(true)
	var methodology: Dictionary = digest_mutation.get("methodology", {})
	methodology["telemetry_mutation"] = true
	_check(not bool(Generator.verify_dataset_digest(digest_mutation).get("ok", true)), "raw payload mutation must fail digest verification")
	var final_location := _find_final_event(dataset)
	_check(not final_location.is_empty(), "telemetry evidence must include a linked final event for relationship rejection cases")
	if final_location.is_empty():
		return
	var sample_index := int(final_location["sample_index"])
	var final_index := int(final_location["event_index"])
	var related_hit_id := str(final_location["related_hit_id"])
	var fabricated_final := dataset.duplicate(true)
	var fabricated_samples: Array = (fabricated_final.get("live_telemetry", {}) as Dictionary).get("samples", [])
	var fabricated_events: Array = (fabricated_samples[sample_index] as Dictionary).get("events", [])
	for raw_event in fabricated_events:
		var event: Dictionary = raw_event
		if str(event.get("event_id", "")) == related_hit_id:
			var final_ids: Array = event.get("final_event_ids", [])
			final_ids.append("forged-final-event")
			event["final_event_ids"] = final_ids
			break
	_expect_telemetry_rejection(fabricated_final, "hit references a fabricated final event id", "fabricated final relation must fail closed")
	var missing_reciprocal := dataset.duplicate(true)
	var reciprocal_samples: Array = (missing_reciprocal.get("live_telemetry", {}) as Dictionary).get("samples", [])
	var reciprocal_events: Array = (reciprocal_samples[sample_index] as Dictionary).get("events", [])
	var reciprocal_final: Dictionary = reciprocal_events[final_index]
	reciprocal_final.erase("related_hit_id")
	_expect_telemetry_rejection(missing_reciprocal, "final event is not linked to a runtime hit", "missing final-to-hit relation must fail closed")
	var final_phase_mutation := dataset.duplicate(true)
	var phase_samples: Array = (final_phase_mutation.get("live_telemetry", {}) as Dictionary).get("samples", [])
	var phase_events: Array = (phase_samples[sample_index] as Dictionary).get("events", [])
	var phase_final: Dictionary = phase_events[final_index]
	phase_final["phase"] = "untrusted_final_phase"
	_expect_telemetry_rejection(final_phase_mutation, "final event has an invalid causal phase", "final source/phase mutation must fail closed")
	var causal_location := _find_post_hit_final_event(dataset)
	_check(not causal_location.is_empty(), "telemetry evidence must include a post-hit final event for causal-order rejection")
	if not causal_location.is_empty():
		var causal_mutation := dataset.duplicate(true)
		var causal_samples: Array = (causal_mutation.get("live_telemetry", {}) as Dictionary).get("samples", [])
		var causal_events: Array = (causal_samples[int(causal_location["sample_index"])] as Dictionary).get("events", [])
		var causal_final: Dictionary = causal_events[int(causal_location["event_index"])]
		causal_final["phase"] = "final_resolution"
		_expect_telemetry_rejection(causal_mutation, "final event causal order is invalid", "causal-order mutation must fail closed")
	var target_location := _find_target_mismatch_final_event(dataset)
	_check(not target_location.is_empty(), "telemetry evidence must include a multi-target final event for target-parity rejection")
	if not target_location.is_empty():
		var target_mutation := dataset.duplicate(true)
		var target_mutation_samples: Array = (target_mutation.get("live_telemetry", {}) as Dictionary).get("samples", [])
		var target_events: Array = (target_mutation_samples[int(target_location["sample_index"])] as Dictionary).get("events", [])
		var target_final: Dictionary = target_events[int(target_location["event_index"])]
		target_final["target_id"] = str(target_location["other_target_id"])
		_expect_telemetry_rejection(target_mutation, "final event target does not match related hit", "final target parity mutation must fail closed")
	var measurement_location := _find_measurement_hit(dataset)
	_check(not measurement_location.is_empty(), "telemetry evidence must include a measured player hit for HP-ledger rejection")
	if not measurement_location.is_empty():
		var missing_applied := dataset.duplicate(true)
		var applied_samples: Array = (missing_applied.get("live_telemetry", {}) as Dictionary).get("samples", [])
		var applied_events: Array = (applied_samples[int(measurement_location["sample_index"])] as Dictionary).get("events", [])
		var applied_hit: Dictionary = applied_events[int(measurement_location["event_index"])]
		applied_hit["damage"] = 0.0
		_expect_telemetry_rejection(missing_applied, "measurement hit damage does not reconcile to hp ledger", "missing applied damage must fail the HP ledger")


func _find_final_event(dataset: Dictionary) -> Dictionary:
	var samples: Array = (dataset.get("live_telemetry", {}) as Dictionary).get("samples", [])
	for sample_index in range(samples.size()):
		var events: Array = (samples[sample_index] as Dictionary).get("events", [])
		for event_index in range(events.size()):
			var event: Dictionary = events[event_index]
			if str(event.get("kind", "")) == "final_event" and str(event.get("related_hit_id", "")) != "":
				return {"sample_index": sample_index, "event_index": event_index, "related_hit_id": str(event["related_hit_id"])}
	return {}


func _find_post_hit_final_event(dataset: Dictionary) -> Dictionary:
	var samples: Array = (dataset.get("live_telemetry", {}) as Dictionary).get("samples", [])
	for sample_index in range(samples.size()):
		var events: Array = (samples[sample_index] as Dictionary).get("events", [])
		var event_indices := {}
		for event_index in range(events.size()):
			event_indices[str((events[event_index] as Dictionary).get("event_id", ""))] = event_index
		for event_index in range(events.size()):
			var event: Dictionary = events[event_index]
			var related_hit_id := str(event.get("related_hit_id", ""))
			if str(event.get("kind", "")) == "final_event" and event_indices.has(related_hit_id) and event_index > int(event_indices[related_hit_id]):
				return {"sample_index": sample_index, "event_index": event_index}
	return {}


func _find_target_mismatch_final_event(dataset: Dictionary) -> Dictionary:
	var samples: Array = (dataset.get("live_telemetry", {}) as Dictionary).get("samples", [])
	for sample_index in range(samples.size()):
		var sample: Dictionary = samples[sample_index]
		var targets: Array = sample.get("fixture_target_ids", [])
		if targets.size() < 2:
			continue
		var events: Array = sample.get("events", [])
		for event_index in range(events.size()):
			var event: Dictionary = events[event_index]
			if str(event.get("kind", "")) != "final_event" or str(event.get("related_hit_id", "")) == "":
				continue
			for target_value in targets:
				if str(target_value) != str(event.get("target_id", "")):
					return {"sample_index": sample_index, "event_index": event_index, "other_target_id": str(target_value)}
	return {}


func _find_measurement_hit(dataset: Dictionary) -> Dictionary:
	var samples: Array = (dataset.get("live_telemetry", {}) as Dictionary).get("samples", [])
	for sample_index in range(samples.size()):
		var events: Array = (samples[sample_index] as Dictionary).get("events", [])
		for event_index in range(events.size()):
			var event: Dictionary = events[event_index]
			if str(event.get("kind", "")) == "hit" and str(event.get("source", "")) == "player_weapon" and str(event.get("probe_phase", "")) == "measurement":
				return {"sample_index": sample_index, "event_index": event_index}
	return {}


func _expect_telemetry_rejection(candidate: Dictionary, expected_error: String, message: String) -> void:
	var verification := Generator.verify_live_telemetry_artifacts(candidate)
	_check(not bool(verification.get("ok", true)), message)
	_check("; ".join(verification.get("errors", [])).contains(expected_error), "%s (missing error: %s)" % [message, expected_error])


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
	_check(_read_text(Generator.CSV_PATH) == Generator.render_csv(dataset), "CSV is not the exact canonical render of raw.json.gz")


func _validate_markdown(dataset: Dictionary, report_text: String) -> void:
	_check(report_text.contains("## Per-weapon matrix"), "Markdown lacks per-weapon matrix")
	_check(report_text.contains("## Formula / live parity"), "Markdown lacks formula/live section")
	_check(report_text.contains(Generator.NON_PLAYABLE_LABEL), "Markdown lacks mandatory non-playable label")
	_check(report_text.contains("changes no balance values") or report_text.contains("No balance values"), "Markdown does not state the no-balance-change scope")
	_check(report_text.contains("applies class/Atlas attribute and run modifiers exactly once"), "Markdown does not state the single-application ultimate rule")
	var source: Dictionary = dataset.get("source", {})
	_check(report_text.contains("Source commit `%s` (tree `%s`, timestamp `%s`)" % [source.get("commit", ""), source.get("tree", ""), source.get("commit_timestamp", "")]), "Markdown source provenance differs from raw.json.gz")
	_check(report_text.contains("Dataset digest: `%s`" % dataset.get("dataset_digest_sha256", "")), "Markdown dataset digest differs from raw.json.gz")
	for row_value in dataset.get("class_rows", []):
		var row: Dictionary = row_value
		var prefix := "| %s | %d | %s | %s | %.3f | %.3f | %.3f | %.3f | %.2f |" % [row["class_id"], row["level"], row["scenario"], "; ".join(row["roles"]), row["solo_score"], row["aoe_score"], row["defense_score"], row["convenience_relative"], row["first_minute_ultimate_damage"]]
		_check(report_text.contains(prefix), "Markdown class row differs from raw.json.gz for %s" % row.get("key", "?"))
	_check(report_text.contains("## Live event telemetry"), "Markdown lacks live telemetry projection")
	_check(report_text.contains("Final-event damage is a deduplicated tagged subset"), "Markdown does not state final-event non-additivity")
	_check(report_text == Generator.render_markdown(dataset), "Markdown is not the exact canonical render of raw.json.gz")


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
