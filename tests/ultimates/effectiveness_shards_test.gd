extends SceneTree

## FAN-3911: contract tests for the per-class effectiveness baseline shards.
##
## Run through `tools/godot_gate.py`; this suite is data-only and does not
## re-measure combat, so failures isolate storage/assembly defects.

const Store := preload("res://tools/ultimate_effectiveness_report.gd")
const Runner := preload("res://scripts/ultimates/balance/ultimate_effectiveness_runner.gd")

var _errors: Array[String] = []


func _initialize() -> void:
	var legacy := _read_legacy_document()
	var split := Store.split_baseline_document(legacy)
	_expect((split.get("errors", []) as Array).is_empty(), "legacy baseline must split cleanly")
	var envelope := split.get("envelope", {}) as Dictionary
	var shards := split.get("shards", []) as Array

	_check_exact_reassembly(legacy, envelope, shards)
	_check_committed_reader(legacy)
	_check_class_isolation(legacy, envelope, shards)
	_check_rejections(envelope, shards)
	_report()


func _read_legacy_document() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(Store.BASELINE_PATH))
	if not parsed is Dictionary:
		_expect(false, "compatibility baseline must be a JSON object")
		return {}
	return parsed as Dictionary


func _check_exact_reassembly(legacy: Dictionary, envelope: Dictionary, shards: Array) -> void:
	_expect(shards.size() == 17, "baseline must contain 17 class shards")
	for raw_shard in shards:
		var shard := raw_shard as Dictionary
		var rows := shard.get("rows", []) as Array
		_expect(rows.size() == 3, "%s shard must contain three rows" % str(shard.get("class_id", "?")))
	var assembled := Store.assemble_baseline(envelope, shards)
	_expect((assembled.get("errors", []) as Array).is_empty(), "canonical shards must assemble cleanly")
	_expect(
		assembled.get("document", {}) == legacy,
		"canonical shards must preserve the exact envelope, values, and row order"
	)
	var assembled_document := assembled.get("document", {}) as Dictionary
	var assembled_rows := assembled_document.get("rows", []) as Array
	_expect(assembled_rows.size() == 51, "assembled baseline must keep all 51 certified rows")
	_expect(Runner.violations(assembled_rows).is_empty(), "assembled rows must satisfy the live runner contract")


func _check_committed_reader(legacy: Dictionary) -> void:
	var loaded := Store.read_baseline_document()
	_expect((loaded.get("errors", []) as Array).is_empty(), "committed shards must load cleanly")
	_expect(loaded.get("document", {}) == legacy, "committed shards must match the compatibility export")


func _check_class_isolation(legacy: Dictionary, envelope: Dictionary, shards: Array) -> void:
	var changed := shards.duplicate(true)
	var druid_shard := _shard_for(changed, "druid")
	var druid_rows := druid_shard.get("rows", []) as Array
	var druid_first := druid_rows[0] as Dictionary
	var solo := (druid_first.get("scenarios", {}) as Dictionary).get("solo", {}) as Dictionary
	solo["damage_applied"] = float(solo.get("damage_applied", 0.0)) + 1.0

	var assembled := Store.assemble_baseline(envelope, changed)
	_expect((assembled.get("errors", []) as Array).is_empty(), "one valid class edit must still assemble")
	var before_by_key := _rows_by_key(legacy.get("rows", []) as Array)
	var after_document := assembled.get("document", {}) as Dictionary
	for raw_row in after_document.get("rows", []) as Array:
		var row := raw_row as Dictionary
		if str(row.get("class_id", "")) == "druid":
			continue
		var key := str(row.get("key", ""))
		_expect(row == before_by_key.get(key), "%s changed after editing only the Druid shard" % key)


func _check_rejections(envelope: Dictionary, shards: Array) -> void:
	var missing := shards.duplicate(true)
	((_shard_for(missing, "druid").get("rows", []) as Array)).pop_back()
	_expect(_has_error(Store.assemble_baseline(envelope, missing), "baseline.row_missing:"), "missing rows must fail")

	var duplicated := shards.duplicate(true)
	var duplicate_rows := _shard_for(duplicated, "druid").get("rows", []) as Array
	duplicate_rows.append((duplicate_rows[0] as Dictionary).duplicate(true))
	_expect(
		_has_error(Store.assemble_baseline(envelope, duplicated), "baseline.row_duplicate:"),
		"duplicate rows must fail"
	)

	var crossed := shards.duplicate(true)
	var crossed_row := (_shard_for(crossed, "druid").get("rows", []) as Array)[0] as Dictionary
	crossed_row["class_id"] = "doctor"
	_expect(
		_has_error(Store.assemble_baseline(envelope, crossed), "baseline.row_cross_class:"),
		"rows stored under another class must fail"
	)


func _shard_for(shards: Array, class_id: String) -> Dictionary:
	for raw_shard in shards:
		var shard := raw_shard as Dictionary
		if str(shard.get("class_id", "")) == class_id:
			return shard
	_expect(false, "missing test shard %s" % class_id)
	return {}


func _rows_by_key(rows: Array) -> Dictionary:
	var result := {}
	for raw_row in rows:
		var row := raw_row as Dictionary
		result[str(row.get("key", ""))] = row
	return result


func _has_error(result: Dictionary, prefix: String) -> bool:
	for raw_error in result.get("errors", []) as Array:
		if str(raw_error).begins_with(prefix):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if not _errors.is_empty():
		for error in _errors:
			push_error("effectiveness_shards_test: %s" % error)
		quit(1)
		return
	print("effectiveness_shards_test passed (17 shards, 51 rows, exact compatibility).")
	quit(0)
