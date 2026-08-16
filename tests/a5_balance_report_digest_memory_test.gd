extends SceneTree

const Generator := preload("res://tools/a5_balance_report.gd")
const STREAMING_ALLOCATION_LIMIT_BYTES := 64 * 1024 * 1024
const MAX_PROCESS_PEAK_ALLOCATION_BYTES := 4_170_945_741

var _errors := PackedStringArray()


func _initialize() -> void:
	var raw_artifact := Generator.read_raw_artifact()
	_check(bool(raw_artifact.get("ok", false)), "immutable f09 A5 oracle must decode for digest verification")
	var raw_text := str(raw_artifact.get("text", ""))
	var parsed = JSON.parse_string(raw_text)
	_check(parsed is Dictionary, "immutable f09 A5 oracle must parse for digest verification")
	if parsed is Dictionary:
		var dataset := parsed as Dictionary
		_verify_streamed_digest(dataset)
		_verify_fail_closed_mutations(dataset, raw_text)
	_finish()


func _verify_streamed_digest(dataset: Dictionary) -> void:
	var before := OS.get_static_memory_usage()
	var actual := Generator.canonical_dataset_digest(dataset)
	var allocated := maxi(0, OS.get_static_memory_usage() - before)
	_check(actual == str(dataset.get("dataset_digest_sha256", "")), "streamed digest must equal the persisted canonical payload digest")
	_check(bool(Generator.verify_dataset_digest(dataset).get("ok", false)), "valid canonical dataset must pass digest verification")
	_check(allocated < STREAMING_ALLOCATION_LIMIT_BYTES, "streamed digest must avoid a full-payload allocation, got %d bytes" % allocated)
	print("FAN-2252 digest-stream allocation_bytes=%d digest=%s" % [allocated, actual])

	var probe := {"z": [0.1, true, null, "quoted\\ntext"], "dataset_digest_sha256": "ignored", "a": {"count": 42, "nested": ["x", -3.5]}}
	var legacy := probe.duplicate(true)
	legacy.erase("dataset_digest_sha256")
	_check(Generator.canonical_dataset_digest(probe) == Generator._sha256(JSON.stringify(legacy, "", true, true)), "streamed serializer must match legacy canonical JSON semantics")


func _verify_fail_closed_mutations(dataset: Dictionary, raw_text: String) -> void:
	var tampered := dataset.duplicate()
	tampered["schema"] = str(tampered.get("schema", "")) + ".tampered"
	_check(not bool(Generator.verify_dataset_digest(tampered).get("ok", true)), "dataset payload tamper must fail streamed digest verification")

	var loaded := Generator.load_oracle_lineage()
	_check(bool(loaded.get("ok", false)), "oracle lineage manifest must load for the lineage negative")
	if not bool(loaded.get("ok", false)):
		return
	var manifest: Dictionary = loaded.get("manifest", {})
	var tampered_manifest := manifest.duplicate(true)
	(tampered_manifest.get("historical_oracle", {}) as Dictionary)["raw_decoded_sha256"] = "0".repeat(64)
	_check(not bool(Generator.verify_oracle_lineage(tampered_manifest, dataset, raw_text).get("ok", true)), "lineage hash mutation must fail closed")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _finish() -> void:
	var peak := OS.get_static_memory_peak_usage()
	_check(peak <= MAX_PROCESS_PEAK_ALLOCATION_BYTES, "digest regression peak allocation must stay at or below 50%% of the 7.771 GB baseline, got %d bytes" % peak)
	if _errors.is_empty():
		print("FAN-2252 streamed A5 dataset digest regression passed. static_peak_bytes=%d" % peak)
		quit(0)
		return
	for error_value in _errors:
		push_error(error_value)
	quit(1)
