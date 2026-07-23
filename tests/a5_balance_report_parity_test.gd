extends SceneTree

# FAN-1551: f09 is the executable numeric oracle. This compact digest covers the
# ordered 51-key manifest and all four live projection fields exactly as rendered.
const Generator := preload("res://tools/a5_balance_report.gd")
const F09_ORACLE_PROJECTION_SHA256 := "d81092333cdf6e3f4196b8c5ee9198e83ccef8bfe7530a8ef20f911a54d5efd1"

var _errors := PackedStringArray()


func _initialize() -> void:
	var raw_artifact := Generator.read_raw_artifact()
	_check(bool(raw_artifact.get("ok", false)), "raw A5 artifact must decode before parity verification")
	var dataset = JSON.parse_string(str(raw_artifact.get("text", "")))
	_check(dataset is Dictionary, "raw A5 artifact must parse before parity verification")
	if dataset is Dictionary:
		var oracle := Generator.projection_oracle_digest(dataset as Dictionary)
		_check(bool(oracle.get("ok", false)), "51x4 projection manifest is invalid: %s" % oracle.get("error", "unknown"))
		if bool(oracle.get("ok", false)):
			_check(str(oracle.get("digest", "")) == F09_ORACLE_PROJECTION_SHA256, "51x4 exact projection differs from executable f09 oracle")
			var mutated := (dataset as Dictionary).duplicate(true)
			var rows: Array = mutated.get("weapon_rows", [])
			for row_value in rows:
				var row: Dictionary = row_value
				if int(row.get("level", 0)) == 20 and str(row.get("scenario", "")) == "class_constellation":
					row["live_solo_dpm_mean"] = float(row.get("live_solo_dpm_mean", 0.0)) + 0.01
					break
			var mutation_oracle := Generator.projection_oracle_digest(mutated)
			_check(str(mutation_oracle.get("digest", "")) != F09_ORACLE_PROJECTION_SHA256, "projection oracle must fail closed on a 0.01 DPM mutation")
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _finish() -> void:
	if _errors.is_empty():
		print("FAN-1551 A5 51x4 executable-oracle parity passed.")
		quit(0)
		return
	for error_value in _errors:
		push_error(error_value)
	quit(1)
