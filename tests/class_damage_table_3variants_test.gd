extends SceneTree

# SCRUM-453: regression guard for the deterministic class damage report.
# Regenerates the Markdown/CSV evidence and verifies that every live class and
# weapon contributes all three build variants.

const PD := preload("res://scripts/progression_data.gd")
const Generator := preload("res://tools/class_damage_table_3variants.gd")


func _initialize() -> void:
	var result: Dictionary = Generator.generate()
	var errors := []
	if not bool(result.get("ok", false)):
		errors.append_array(result.get("errors", []))

	var expected_class_rows := PD.character_ids().size() * 3
	var expected_weapon_rows := _weapon_count() * 3
	var csv_text := _read_text(Generator.CSV_PATH)
	var report_text := _read_text(Generator.REPORT_PATH)
	if csv_text == "":
		errors.append("SCRUM-453 CSV report is empty or missing.")
	if report_text == "":
		errors.append("SCRUM-453 Markdown report is empty or missing.")
	if csv_text.get_slice_count("\n") < expected_class_rows + expected_weapon_rows:
		errors.append("SCRUM-453 CSV has too few rows for all class/weapon/build variants.")
	if not report_text.contains("## Class Kit Averages") or not report_text.contains("## Weapon Details"):
		errors.append("SCRUM-453 Markdown report is missing required sections.")
	if not report_text.contains("current roster contains %d classes" % PD.character_ids().size()):
		errors.append("SCRUM-453 Markdown report does not document the live roster count.")
	for build_id in ["base_lvl1", "lvl20_optimum", "lvl20_random_avg"]:
		if not csv_text.contains(",\"%s\"," % build_id):
			errors.append("SCRUM-453 CSV missing build variant %s." % build_id)
	_validate_scrum469_balance_corridors(csv_text, errors)

	if not errors.is_empty():
		for error in errors:
			push_error(str(error))
		push_error("SCRUM-453 class damage table test failed.")
		quit(1)
		return

	print("SCRUM-453 class damage table test passed (%d classes, %d weapon-build rows)." % [
		PD.character_ids().size(),
		expected_weapon_rows,
	])
	quit(0)


func _weapon_count() -> int:
	var count := 0
	for character_id in PD.character_ids():
		count += PD.weapon_ids(str(character_id)).size()
	return count


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _validate_scrum469_balance_corridors(csv_text: String, errors: Array) -> void:
	var optimum_rows := 0
	for line in csv_text.split("\n", false):
		var cells := _csv_cells(line)
		if cells.size() < 11 or cells[0] != "class":
			continue
		var class_id := str(cells[1])
		var build_id := str(cells[3])
		var relative_score := float(cells[9])
		var flag := str(cells[10])
		match build_id:
			"base_lvl1":
				if relative_score < 0.90 or relative_score > 1.10:
					errors.append("%s base lvl1 relative_score %.3f outside 0.90-1.10." % [class_id, relative_score])
			"lvl20_optimum":
				optimum_rows += 1
				if relative_score < 0.90 or relative_score > 1.10:
					errors.append("%s lvl20 optimum relative_score %.3f outside SCRUM-469 0.90-1.10 corridor." % [class_id, relative_score])
				if flag != "ok":
					errors.append("%s lvl20 optimum still flagged %s after SCRUM-469." % [class_id, flag])
			"lvl20_random_avg":
				if flag != "ok":
					errors.append("%s lvl20 random avg still flagged %s after SCRUM-469." % [class_id, flag])
	if optimum_rows != PD.character_ids().size():
		errors.append("SCRUM-469 expected %d lvl20 optimum class rows, got %d." % [PD.character_ids().size(), optimum_rows])


func _csv_cells(line: String) -> Array:
	var trimmed := line.strip_edges()
	if trimmed == "":
		return []
	return Array(trimmed.replace("\"", "").split(",", true))
