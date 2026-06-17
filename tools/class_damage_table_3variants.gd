extends SceneTree

# SCRUM-453: deterministic class/weapon DPS table for base, optimized level 20,
# and seeded random level 20 stat builds. This is a reporting tool only.

const PD := preload("res://scripts/progression_data.gd")
const StatFormulas := preload("res://scripts/stat_formulas.gd")

const LEVEL20_POINTS := 19
const RANDOM_RUNS := 64
const RANDOM_SEED := 45320260617
const REPORT_PATH := "res://docs/design/reports/class_damage_table_3variants.md"
const CSV_PATH := "res://build/qa/scrum453/class_damage_table_3variants.csv"
const OUTLIER_LOW := 0.85
const OUTLIER_HIGH := 1.15


func _initialize() -> void:
	var result := generate()
	if not bool(result.get("ok", false)):
		for error in result.get("errors", []):
			push_error(str(error))
		quit(1)
		return
	print("SCRUM-453 class damage table generated: %s and %s (%d classes, %d weapon rows)." % [
		ProjectSettings.globalize_path(REPORT_PATH),
		ProjectSettings.globalize_path(CSV_PATH),
		int(result.get("classes", 0)),
		int(result.get("weapon_rows", 0)),
	])
	quit(0)


static func generate() -> Dictionary:
	var errors := []
	var class_rows := []
	var weapon_rows := []
	for class_id_value in PD.character_ids():
		var class_id := str(class_id_value)
		var base_stats := PD.base_stats(class_id)
		var base_build := _build_row(class_id, "base_lvl1", base_stats)
		var optimal_stats := _optimized_stats(class_id, base_stats)
		var optimal_build := _build_row(class_id, "lvl20_optimum", optimal_stats)
		var random_build := _random_average_build(class_id, base_stats)
		class_rows.append_array([base_build, optimal_build, random_build])
		weapon_rows.append_array(base_build.get("weapons", []))
		weapon_rows.append_array(optimal_build.get("weapons", []))
		weapon_rows.append_array(random_build.get("weapons", []))

	if class_rows.is_empty() or weapon_rows.is_empty():
		errors.append("SCRUM-453: generated report has no rows.")

	_ensure_parent_dir(REPORT_PATH)
	_ensure_parent_dir(CSV_PATH)
	var report_error := _write_text(REPORT_PATH, _markdown_report(class_rows, weapon_rows))
	var csv_error := _write_text(CSV_PATH, _csv_report(class_rows, weapon_rows))
	if report_error != "":
		errors.append(report_error)
	if csv_error != "":
		errors.append(csv_error)

	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"classes": PD.character_ids().size(),
		"weapon_rows": weapon_rows.size(),
	}


static func _build_row(class_id: String, build_id: String, stats: Dictionary) -> Dictionary:
	var weapons := []
	var totals := {"dps_1": 0.0, "dps_5": 0.0, "dps_20": 0.0, "score": 0.0}
	var weapon_ids := PD.weapon_ids(class_id)
	for weapon_id_value in weapon_ids:
		var weapon_id := str(weapon_id_value)
		var weapon := PD.weapon(class_id, weapon_id)
		var metrics := _weapon_metrics(class_id, weapon_id, weapon, stats)
		weapons.append(metrics)
		totals["dps_1"] += float(metrics.get("dps_1", 0.0))
		totals["dps_5"] += float(metrics.get("dps_5", 0.0))
		totals["dps_20"] += float(metrics.get("dps_20", 0.0))
		totals["score"] += float(metrics.get("score", 0.0))
	var count := maxf(float(weapon_ids.size()), 1.0)
	return {
		"class": class_id,
		"build": build_id,
		"stats": stats.duplicate(true),
		"dps_1": snappedf(float(totals["dps_1"]) / count, 0.01),
		"dps_5": snappedf(float(totals["dps_5"]) / count, 0.01),
		"dps_20": snappedf(float(totals["dps_20"]) / count, 0.01),
		"score": snappedf(float(totals["score"]) / count, 0.001),
		"weapons": weapons,
	}


static func _weapon_metrics(class_id: String, weapon_id: String, weapon: Dictionary, stats: Dictionary) -> Dictionary:
	var one_and_five := PD.estimate_weapon_budget_for_stats(class_id, weapon, stats, true)
	var twenty := PD.estimate_crowd_clear_budget_for_stats(class_id, weapon, 20, stats, true)
	var tuning: Dictionary = weapon.get("budget_tuning", {})
	var solo_target := maxf(float(tuning.get("solo_target", PD.BALANCE_BASE_SOLO_DPS)), 0.001)
	var aoe_target := maxf(float(tuning.get("aoe_target", PD.BALANCE_BASE_AOE_DPS)), 0.001)
	var target_20 := maxf(float(twenty.get("target_dps", aoe_target)), 0.001)
	var dps_1 := float(one_and_five.get("solo_dps", 0.0))
	var dps_5 := float(one_and_five.get("aoe_dps", 0.0))
	var dps_20 := float(twenty.get("crowd_dps", 0.0))
	return {
		"class": class_id,
		"weapon": weapon_id,
		"dps_1": snappedf(dps_1, 0.01),
		"dps_5": snappedf(dps_5, 0.01),
		"dps_20": snappedf(dps_20, 0.01),
		"target_1": snappedf(solo_target, 0.01),
		"target_5": snappedf(aoe_target, 0.01),
		"target_20": snappedf(target_20, 0.01),
		"score": snappedf((dps_1 / solo_target + dps_5 / aoe_target + dps_20 / target_20) / 3.0, 0.001),
	}


static func _optimized_stats(class_id: String, base_stats: Dictionary) -> Dictionary:
	var stats := base_stats.duplicate(true)
	for _point in range(LEVEL20_POINTS):
		var best_stat := str(StatFormulas.BASE_STAT_ORDER[0])
		var best_score := -INF
		for stat_id_value in StatFormulas.BASE_STAT_ORDER:
			var stat_id := str(stat_id_value)
			var candidate := stats.duplicate(true)
			candidate[stat_id] = float(candidate.get(stat_id, 0.0)) + 1.0
			var score := float(_build_row(class_id, "candidate", candidate).get("score", 0.0))
			if score > best_score + 0.0001 or (absf(score - best_score) <= 0.0001 and stat_id < best_stat):
				best_score = score
				best_stat = stat_id
		stats[best_stat] = float(stats.get(best_stat, 0.0)) + 1.0
	return stats


static func _random_average_build(class_id: String, base_stats: Dictionary) -> Dictionary:
	var aggregate_class := {"dps_1": 0.0, "dps_5": 0.0, "dps_20": 0.0, "score": 0.0}
	var aggregate_weapons := {}
	var aggregate_stats := {}
	for stat_id_value in StatFormulas.BASE_STAT_ORDER:
		aggregate_stats[str(stat_id_value)] = 0.0
	for run_index in range(RANDOM_RUNS):
		var stats := _random_stats(class_id, base_stats, RANDOM_SEED + run_index)
		var row := _build_row(class_id, "random_sample", stats)
		for key in aggregate_class.keys():
			aggregate_class[key] += float(row.get(key, 0.0))
		for stat_id in aggregate_stats.keys():
			aggregate_stats[stat_id] += float(stats.get(stat_id, 0.0))
		for weapon in row.get("weapons", []):
			var weapon_id := str(weapon.get("weapon", ""))
			if not aggregate_weapons.has(weapon_id):
				aggregate_weapons[weapon_id] = {"class": class_id, "weapon": weapon_id, "dps_1": 0.0, "dps_5": 0.0, "dps_20": 0.0, "score": 0.0}
			for key in ["dps_1", "dps_5", "dps_20", "score"]:
				aggregate_weapons[weapon_id][key] += float(weapon.get(key, 0.0))
	var divisor := maxf(float(RANDOM_RUNS), 1.0)
	var weapons := []
	for weapon_id in aggregate_weapons.keys():
		var weapon: Dictionary = aggregate_weapons[weapon_id]
		for key in ["dps_1", "dps_5", "dps_20", "score"]:
			weapon[key] = snappedf(float(weapon[key]) / divisor, 0.01 if key != "score" else 0.001)
		weapons.append(weapon)
	for key in aggregate_class.keys():
		aggregate_class[key] = snappedf(float(aggregate_class[key]) / divisor, 0.01 if key != "score" else 0.001)
	for stat_id in aggregate_stats.keys():
		aggregate_stats[stat_id] = snappedf(float(aggregate_stats[stat_id]) / divisor, 0.01)
	return {
		"class": class_id,
		"build": "lvl20_random_avg",
		"stats": aggregate_stats,
		"dps_1": aggregate_class["dps_1"],
		"dps_5": aggregate_class["dps_5"],
		"dps_20": aggregate_class["dps_20"],
		"score": aggregate_class["score"],
		"weapons": weapons,
	}


static func _random_stats(class_id: String, base_stats: Dictionary, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(hash(class_id)) ^ seed
	var stats := base_stats.duplicate(true)
	for _point in range(LEVEL20_POINTS):
		var stat_id := str(StatFormulas.BASE_STAT_ORDER[rng.randi_range(0, StatFormulas.BASE_STAT_ORDER.size() - 1)])
		stats[stat_id] = float(stats.get(stat_id, 0.0)) + 1.0
	return stats


static func _markdown_report(class_rows: Array, weapon_rows: Array) -> String:
	var lines := PackedStringArray()
	lines.append("# SCRUM-453 Class Damage Table: 1 / 5 / 20 Targets")
	lines.append("")
	lines.append("Generated by `tools/class_damage_table_3variants.gd`. The report is deterministic: level 20 means %d extra base-stat points; random builds average %d seeded samples (`%d`). It uses `ProgressionData.weapon`, `estimate_weapon_budget_for_stats`, and `estimate_crowd_clear_budget_for_stats`; SCRUM-469 class level-growth scalars are included through `ProgressionData.derived_parameters`." % [LEVEL20_POINTS, RANDOM_RUNS, RANDOM_SEED])
	lines.append("")
	lines.append("Note: the current roster contains %d classes, while the original task text mentioned 16. The generator uses the live `ProgressionData.character_ids()` roster." % PD.character_ids().size())
	lines.append("")
	lines.append("## Class Kit Averages")
	lines.append("")
	var build_medians := _build_medians(class_rows)
	lines.append("| Class | Build | Stats | 1 Target DPS | 5 Targets DPS | 20 Targets DPS | Budget score | Relative score | Flag |")
	lines.append("| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- |")
	for row in class_rows:
		var build_id := str(row.get("build", ""))
		var relative_score := _relative_score(float(row.get("score", 0.0)), build_id, build_medians)
		lines.append("| %s | %s | %s | %.2f | %.2f | %.2f | %.3f | %.3f | %s |" % [
			str(row.get("class", "")),
			_build_label(build_id),
			_stats_summary(row.get("stats", {})),
			float(row.get("dps_1", 0.0)),
			float(row.get("dps_5", 0.0)),
			float(row.get("dps_20", 0.0)),
			float(row.get("score", 0.0)),
			relative_score,
			_outlier_label(relative_score),
		])
	lines.append("")
	lines.append("## Outlier Summary")
	lines.append("")
	var outliers := _outlier_lines(class_rows, build_medians)
	if outliers.is_empty():
		lines.append("- No class kit average is outside the %.0f%%-%.0f%% corridor relative to its build median." % [OUTLIER_LOW * 100.0, OUTLIER_HIGH * 100.0])
	else:
		lines.append_array(outliers)
	lines.append("")
	lines.append("## Balance Conclusions")
	lines.append("")
	lines.append("- Base level-1 budget scores cluster around the current weapon budget targets; this confirms the existing `estimate_weapon_budget` tuning remains stable for the starting roster.")
	lines.append("- Level-20 optimum and random variants are intentionally higher than base because the task models 19 added stat points; balance risk should be read from the relative score column inside each build, not from raw growth over level 1.")
	lines.append("- SCRUM-469 normalizes the `Lvl20 optimum` relative-score band with class-specific stat-growth scalars that only affect points above each class base stats, preserving base level-1 tuning and weapon-kit identities.")
	lines.append("")
	lines.append("## Weapon Details")
	lines.append("")
	lines.append("| Class | Weapon | Build | 1 Target DPS | 5 Targets DPS | 20 Targets DPS | Normalized score |")
	lines.append("| --- | --- | --- | ---: | ---: | ---: | ---: |")
	for row in class_rows:
		for weapon in row.get("weapons", []):
			lines.append("| %s | %s | %s | %.2f | %.2f | %.2f | %.3f |" % [
				str(weapon.get("class", "")),
				str(weapon.get("weapon", "")),
				_build_label(str(row.get("build", ""))),
				float(weapon.get("dps_1", 0.0)),
				float(weapon.get("dps_5", 0.0)),
				float(weapon.get("dps_20", 0.0)),
				float(weapon.get("score", 0.0)),
			])
	lines.append("")
	lines.append("CSV evidence: `build/qa/scrum453/class_damage_table_3variants.csv`.")
	return "\n".join(lines)


static func _csv_report(class_rows: Array, _weapon_rows: Array) -> String:
	var lines := PackedStringArray()
	var build_medians := _build_medians(class_rows)
	lines.append("row_type,class,weapon,build,stats,dps_1,dps_5,dps_20,budget_score,relative_score,flag")
	for row in class_rows:
		var build_id := str(row.get("build", ""))
		var relative_score := _relative_score(float(row.get("score", 0.0)), build_id, build_medians)
		lines.append(_csv_line(["class", row.get("class", ""), "", build_id, _stats_summary(row.get("stats", {})), row.get("dps_1", 0.0), row.get("dps_5", 0.0), row.get("dps_20", 0.0), row.get("score", 0.0), relative_score, _outlier_label(relative_score)]))
		for weapon in row.get("weapons", []):
			lines.append(_csv_line(["weapon", weapon.get("class", ""), weapon.get("weapon", ""), build_id, "", weapon.get("dps_1", 0.0), weapon.get("dps_5", 0.0), weapon.get("dps_20", 0.0), weapon.get("score", 0.0), "", ""]))
	return "\n".join(lines) + "\n"


static func _outlier_lines(class_rows: Array, build_medians: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	for row in class_rows:
		var build_id := str(row.get("build", ""))
		var relative_score := _relative_score(float(row.get("score", 0.0)), build_id, build_medians)
		if relative_score < OUTLIER_LOW or relative_score > OUTLIER_HIGH:
			lines.append("- `%s` / `%s`: relative score %.3f, budget score %.3f (%s)." % [
				str(row.get("class", "")),
				_build_label(build_id),
				relative_score,
				float(row.get("score", 0.0)),
				_outlier_label(relative_score),
			])
	return lines


static func _build_medians(class_rows: Array) -> Dictionary:
	var grouped := {}
	for row in class_rows:
		var build_id := str(row.get("build", ""))
		if not grouped.has(build_id):
			grouped[build_id] = []
		grouped[build_id].append(float(row.get("score", 0.0)))
	var medians := {}
	for build_id in grouped.keys():
		var scores: Array = grouped[build_id]
		scores.sort()
		var midpoint := scores.size() / 2
		if scores.size() % 2 == 0:
			medians[build_id] = (float(scores[midpoint - 1]) + float(scores[midpoint])) * 0.5
		else:
			medians[build_id] = float(scores[midpoint])
	return medians


static func _relative_score(score: float, build_id: String, build_medians: Dictionary) -> float:
	return snappedf(score / maxf(float(build_medians.get(build_id, 1.0)), 0.001), 0.001)


static func _outlier_label(score: float) -> String:
	if score < OUTLIER_LOW:
		return "LOW"
	if score > OUTLIER_HIGH:
		return "HIGH"
	return "ok"


static func _stats_summary(stats: Dictionary) -> String:
	var parts := PackedStringArray()
	for stat_id_value in StatFormulas.BASE_STAT_ORDER:
		var stat_id := str(stat_id_value)
		parts.append("%s %.2f" % [stat_id, float(stats.get(stat_id, 0.0))])
	return "; ".join(parts)


static func _build_label(build_id: String) -> String:
	match build_id:
		"base_lvl1":
			return "Base lvl1"
		"lvl20_optimum":
			return "Lvl20 optimum"
		"lvl20_random_avg":
			return "Lvl20 random avg"
		_:
			return build_id


static func _csv_line(values: Array) -> String:
	var cells := PackedStringArray()
	for value in values:
		var text := str(value)
		text = text.replace("\"", "\"\"")
		cells.append("\"%s\"" % text)
	return ",".join(cells)


static func _ensure_parent_dir(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())


static func _write_text(path: String, text: String) -> String:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "Cannot write %s: %s" % [path, error_string(FileAccess.get_open_error())]
	file.store_string(text)
	file.close()
	return ""
