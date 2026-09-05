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
const BASELINE_PATH := "res://build/ultimate_effectiveness_baseline.json"
const SHARD_DIRECTORY := "res://build/effectiveness"
const ENVELOPE_PATH := "res://build/effectiveness/_envelope.json"
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
		var loaded := read_baseline_document()
		var baseline_errors: Array = loaded.get("errors", [])
		if not baseline_errors.is_empty():
			errors.append_array(baseline_errors)
		var baseline_document = loaded.get("document")
		var baseline: Array = baseline_document.get("rows", []) \
			if baseline_document is Dictionary else []
		if baseline.is_empty() and baseline_errors.is_empty():
			print("ultimate_effectiveness_report: no stored baseline, regression gate skipped")
		elif baseline_errors.is_empty():
			errors.append_array(Runner.regressions(baseline, report))

	var path := _report_path(label)
	var document := Runner.report_document(report, label)
	var wrote := write_baseline_document(document) if label == BASELINE_LABEL \
		else _write(path, document)
	if not wrote:
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


## Reads the sharded baseline when present and falls back to the legacy file so
## older refs and external consumers remain compatible during the migration.
static func read_baseline_document() -> Dictionary:
	if not FileAccess.file_exists(ENVELOPE_PATH):
		if not FileAccess.file_exists(BASELINE_PATH):
			return {"document": {}, "errors": []}
		var legacy = JSON.parse_string(FileAccess.get_file_as_string(BASELINE_PATH))
		if not legacy is Dictionary:
			return {"document": {}, "errors": ["baseline.legacy_parse: expected a JSON object"]}
		return {"document": legacy, "errors": []}

	var envelope = JSON.parse_string(FileAccess.get_file_as_string(ENVELOPE_PATH))
	if not envelope is Dictionary:
		return {"document": {}, "errors": ["baseline.envelope_parse: expected a JSON object"]}
	var shards: Array = []
	var directory := DirAccess.open(SHARD_DIRECTORY)
	if directory == null:
		return {"document": {}, "errors": ["baseline.shard_directory: could not open %s" % SHARD_DIRECTORY]}
	for file_name in directory.get_files():
		if not file_name.ends_with(".json") or file_name == "_envelope.json":
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("%s/%s" % [SHARD_DIRECTORY, file_name]))
		if not parsed is Dictionary:
			return {
				"document": {},
				"errors": ["baseline.shard_parse: %s must be a JSON object" % file_name],
			}
		var shard := (parsed as Dictionary).duplicate(true)
		shard["_file_class_id"] = file_name.trim_suffix(".json")
		shards.append(shard)
	return assemble_baseline(envelope as Dictionary, shards)


## Reassembles the public legacy document and validates every ownership edge.
## The private indexes in `_envelope.json` preserve canonical class/row order
## and make missing or duplicate data fail instead of silently reordering it.
static func assemble_baseline(envelope: Dictionary, shards: Array) -> Dictionary:
	var errors: Array[String] = []
	var class_ids = envelope.get("class_ids")
	var row_keys = envelope.get("row_keys")
	if not class_ids is Array or (class_ids as Array).is_empty():
		errors.append("baseline.class_ids: envelope must list canonical classes")
	if not row_keys is Array or (row_keys as Array).is_empty():
		errors.append("baseline.row_keys: envelope must list canonical rows")
	if not errors.is_empty():
		return {"document": {}, "errors": errors}

	var expected_classes := {}
	for raw_class_id in class_ids as Array:
		var class_id := str(raw_class_id)
		if class_id.is_empty() or expected_classes.has(class_id):
			errors.append("baseline.class_id_duplicate: %s" % class_id)
		expected_classes[class_id] = true

	var rows_by_key := {}
	var seen_classes := {}
	for raw_shard in shards:
		if not raw_shard is Dictionary:
			errors.append("baseline.shard_type: every shard must be a Dictionary")
			continue
		var shard := raw_shard as Dictionary
		var class_id := str(shard.get("class_id", ""))
		var file_class_id := str(shard.get("_file_class_id", class_id))
		if class_id.is_empty() or not expected_classes.has(class_id):
			errors.append("baseline.class_unknown: %s" % class_id)
		if file_class_id != class_id:
			errors.append("baseline.class_file_mismatch: %s contains %s" % [file_class_id, class_id])
		if seen_classes.has(class_id):
			errors.append("baseline.class_duplicate: %s" % class_id)
		seen_classes[class_id] = true
		var rows = shard.get("rows")
		if not rows is Array:
			errors.append("baseline.rows_type: %s rows must be an Array" % class_id)
			continue
		for raw_row in rows as Array:
			if not raw_row is Dictionary:
				errors.append("baseline.row_type: %s shard contains a non-Dictionary row" % class_id)
				continue
			var row := raw_row as Dictionary
			var row_class_id := str(row.get("class_id", ""))
			var key := str(row.get("key", ""))
			if row_class_id != class_id:
				errors.append("baseline.row_cross_class: %s belongs to %s, not %s" % [key, row_class_id, class_id])
			if rows_by_key.has(key):
				errors.append("baseline.row_duplicate: %s" % key)
			else:
				rows_by_key[key] = row

	for raw_class_id in class_ids as Array:
		var class_id := str(raw_class_id)
		if not seen_classes.has(class_id):
			errors.append("baseline.class_missing: %s" % class_id)

	var ordered_rows: Array = []
	var expected_keys := {}
	for raw_key in row_keys as Array:
		var key := str(raw_key)
		if key.is_empty() or expected_keys.has(key):
			errors.append("baseline.row_key_duplicate: %s" % key)
		expected_keys[key] = true
		if not rows_by_key.has(key):
			errors.append("baseline.row_missing: %s" % key)
		else:
			ordered_rows.append((rows_by_key[key] as Dictionary).duplicate(true))
	for raw_key in rows_by_key.keys():
		var key := str(raw_key)
		if not expected_keys.has(key):
			errors.append("baseline.row_unknown: %s" % key)

	var document := {
		"schema_version": envelope.get("schema_version"),
		"label": envelope.get("label"),
		"scenario_ids": (envelope.get("scenario_ids") as Array).duplicate(true) \
			if envelope.get("scenario_ids") is Array else envelope.get("scenario_ids"),
		"metric_keys": (envelope.get("metric_keys") as Array).duplicate(true) \
			if envelope.get("metric_keys") is Array else envelope.get("metric_keys"),
		"tolerances": (envelope.get("tolerances") as Dictionary).duplicate(true) \
			if envelope.get("tolerances") is Dictionary else envelope.get("tolerances"),
		"rows": ordered_rows,
	}
	return {"document": document, "errors": errors}


## Converts the public document into one ownership shard per class plus the
## private ordering indexes needed for exact, deterministic reassembly.
static func split_baseline_document(document: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var rows = document.get("rows")
	if not rows is Array:
		return {"envelope": {}, "shards": [], "errors": ["baseline.rows_type: rows must be an Array"]}
	var class_ids: Array[String] = []
	var row_keys: Array[String] = []
	var rows_by_class := {}
	for raw_row in rows as Array:
		if not raw_row is Dictionary:
			errors.append("baseline.row_type: rows must be Dictionaries")
			continue
		var row := raw_row as Dictionary
		var class_id := str(row.get("class_id", ""))
		var key := str(row.get("key", ""))
		if class_id.is_empty() or key.is_empty():
			errors.append("baseline.row_identity: every row needs class_id and key")
			continue
		if not rows_by_class.has(class_id):
			class_ids.append(class_id)
			rows_by_class[class_id] = []
		(rows_by_class[class_id] as Array).append(row.duplicate(true))
		row_keys.append(key)

	var shards: Array = []
	for class_id in class_ids:
		shards.append({"class_id": class_id, "rows": rows_by_class[class_id]})
	var envelope := {
		"schema_version": document.get("schema_version"),
		"label": document.get("label"),
		"scenario_ids": (document.get("scenario_ids") as Array).duplicate(true) \
			if document.get("scenario_ids") is Array else document.get("scenario_ids"),
		"metric_keys": (document.get("metric_keys") as Array).duplicate(true) \
			if document.get("metric_keys") is Array else document.get("metric_keys"),
		"tolerances": (document.get("tolerances") as Dictionary).duplicate(true) \
			if document.get("tolerances") is Dictionary else document.get("tolerances"),
		"class_ids": class_ids,
		"row_keys": row_keys,
	}
	return {"envelope": envelope, "shards": shards, "errors": errors}


static func write_baseline_document(document: Dictionary) -> bool:
	var split := split_baseline_document(document)
	if not (split.get("errors", []) as Array).is_empty():
		return false
	if not _write(BASELINE_PATH, document):
		return false
	if not _write(ENVELOPE_PATH, split["envelope"] as Dictionary):
		return false
	for raw_shard in split["shards"] as Array:
		var shard := raw_shard as Dictionary
		var class_id := str(shard.get("class_id", ""))
		if not _write("%s/%s.json" % [SHARD_DIRECTORY, class_id], shard):
			return false
	return true


static func _write(path: String, document: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(document, "\t", true) + "\n")
	file.close()
	return true


func _fail(message: String) -> void:
	push_error("ultimate_effectiveness_report: %s" % message)
	quit(1)
