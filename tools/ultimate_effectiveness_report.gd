extends SceneTree

## FAN-2516: emits the machine-readable live effectiveness report for the 51
## weapon ultimates.
##
##     python3 tools/godot_gate.py --headless --path . \
##         --script res://tools/ultimate_effectiveness_report.gd -- --label=final
##
## `--label=baseline` (the default) writes the stored baseline. `--label=final`
## writes the final report and, when a baseline exists, additionally fails on an
## unexplained corridor regression against it. Exit status is non-zero whenever
## the report itself is red, so the tool is usable as a gate.

const Runner := preload("res://scripts/ultimates/balance/ultimate_effectiveness_runner.gd")
const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const ProgressionData := preload("res://scripts/progression_data.gd")

const REPORT_DIRECTORY := "res://build"
const BASELINE_LABEL := "baseline"
const FINAL_LABEL := "final"


func _initialize() -> void:
	var label := _label()
	var holder := Node2D.new()
	root.add_child(holder)
	current_scene = holder
	await process_frame

	var registry := Registry.new(ProgressionData.WEAPONS_BY_CLASS)
	var registry_errors := registry.validation_errors()
	registry_errors.append_array(registry.package_validation_errors())
	if not registry_errors.is_empty():
		_fail("registry rejected the catalog: %s" % [registry_errors])
		return

	var rows := Budget.build_rows(ProgressionData.WEAPONS_BY_CLASS, ProgressionData)
	var report: Array = await Runner.new().measure(holder, registry, rows, ProgressionData)
	holder.queue_free()
	await process_frame

	var errors := Runner.violations(report)
	if label == FINAL_LABEL:
		var baseline := _read_rows(_report_path(BASELINE_LABEL))
		if baseline.is_empty():
			print("ultimate_effectiveness_report: no stored baseline, regression gate skipped")
		else:
			errors.append_array(Runner.regressions(baseline, report))

	var path := _report_path(label)
	if not _write(path, Runner.report_document(report, label)):
		_fail("could not write %s" % path)
		return
	print("ultimate_effectiveness_report: %d rows -> %s" % [
		report.size(), ProjectSettings.globalize_path(path)
	])
	if not errors.is_empty():
		for error in errors:
			push_error("ultimate_effectiveness_report: %s" % error)
		quit(1)
		return
	print("ultimate_effectiveness_report: PASS (%s)" % label)
	quit(0)


func _label() -> String:
	for raw_arg in OS.get_cmdline_user_args():
		var arg := str(raw_arg)
		if arg.begins_with("--label="):
			var value := arg.trim_prefix("--label=").strip_edges()
			if value == FINAL_LABEL or value == BASELINE_LABEL:
				return value
	return BASELINE_LABEL


static func _report_path(label: String) -> String:
	return "%s/ultimate_effectiveness_%s.json" % [REPORT_DIRECTORY, label]


static func _read_rows(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return []
	var rows = (parsed as Dictionary).get("rows")
	return rows as Array if rows is Array else []


static func _write(path: String, document: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_DIRECTORY))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(document, "\t", true) + "\n")
	file.close()
	return true


func _fail(message: String) -> void:
	push_error("ultimate_effectiveness_report: %s" % message)
	quit(1)
