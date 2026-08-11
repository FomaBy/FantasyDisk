extends SceneTree

const Pack := preload("res://tools/a5/scenarios/defensive/defensive_family_pack.gd")
const Runtime := preload("res://tools/a5/scenarios/defensive/defensive_runtime.gd")

var _errors := PackedStringArray()


func _initialize() -> void:
	await process_frame
	_verify_contract_and_fail_closed_oracle()
	_verify_live_runtime_probe()
	_verify_committed_fragment()
	_finish()


func _verify_contract_and_fail_closed_oracle() -> void:
	for error_value in Pack.verify_matrix().get("errors", []):
		_errors.append("matrix: %s" % error_value)
	var fragment := _green_fragment()
	_check(bool(Pack.evaluate_fragment(fragment).get("ok", false)), "a complete synthetic defensive fragment must be green")
	var empty_event := _green_fragment()
	(empty_event["reactive"] as Dictionary)["dodge"]["enabled"]["expected_events"] = 0
	_check(not bool(Pack.evaluate_fragment(empty_event).get("ok", false)), "a zero-event defensive probe must fail closed")
	var leaked_arm := _green_fragment()
	(leaked_arm["reactive"] as Dictionary)["block"]["disabled"]["final_damage"] = 1.0
	_check(not bool(Pack.evaluate_fragment(leaked_arm).get("ok", false)), "disabled-arm final damage must fail closed")
	var bad_boundary := _green_fragment()
	(bad_boundary["quality"] as Dictionary)["pickup_radius"]["outside_collected"] = true
	_check(not bool(Pack.evaluate_fragment(bad_boundary).get("ok", false)), "pickup distance above the boundary must not pass")


func _verify_live_runtime_probe() -> void:
	var fragment := Runtime.run(root)
	var result := Pack.evaluate_fragment(fragment)
	for error_value in result.get("errors", []):
		_errors.append("live probe: %s" % error_value)
	for entry_value in Pack.REACTIVE_MATRIX:
		var entry: Dictionary = entry_value
		var measurement: Dictionary = (fragment.get("reactive", {}) as Dictionary).get(str(entry["id"]), {})
		var enabled: Dictionary = measurement.get("enabled", {})
		_check(int(enabled.get("incoming_hits", 0)) > 0, "%s must receive deterministic incoming hits" % entry["id"])
		_check(int(enabled.get("expected_events", 0)) > 0, "%s must observe its expected runtime event" % entry["id"])
	_check(str(((fragment.get("quality", {}) as Dictionary).get("move_speed", {}) as Dictionary).get("unit", "")) == "units/s", "move speed must report units/s")
	_check(str(((fragment.get("quality", {}) as Dictionary).get("pickup_radius", {}) as Dictionary).get("unit", "")) == "units", "pickup radius must report units")


func _verify_committed_fragment() -> void:
	if not FileAccess.file_exists(Pack.FRAGMENT_PATH):
		_errors.append("committed defensive fragment is missing")
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(Pack.FRAGMENT_PATH))
	if not parsed is Dictionary:
		_errors.append("committed defensive fragment is not JSON")
		return
	var fragment: Dictionary = parsed
	for error_value in Pack.evaluate_fragment(fragment).get("errors", []):
		_errors.append("committed fragment: %s" % error_value)
	_check(str(fragment.get("verdict", "")) == "green", "committed defensive fragment must be green")


func _green_fragment() -> Dictionary:
	var reactive := {}
	for entry_value in Pack.REACTIVE_MATRIX:
		var entry: Dictionary = entry_value
		reactive[str(entry["id"])] = {
			"enabled": {"incoming_hits": 3, "expected_events": 3, "final_damage": 12.0, "sources": ["Player.take_damage"]},
			"disabled": {"incoming_hits": 3, "expected_events": 0, "final_damage": 0.0, "sources": ["Player.take_damage"]},
			"event_samples": [1, 1, 1],
		}
	return {
		"fragment_schema": Pack.FRAGMENT_SCHEMA,
		"pack_contract": Pack.PACK_CONTRACT,
		"reactive": reactive,
		"survivability": {"hp_loss": 12.0, "effective_health": 120.0, "ttd_seconds": 4.0, "mitigated_amount": 8.0, "sustain_healed": 2.0, "shield_added": 1.0, "lifesteal_healed": 1.0, "source": "fixture", "sources": ["fixture"]},
		"quality": {"move_speed": {"unit": "units/s", "speed": 200.0, "window_seconds": 0.5, "distance": 100.0}, "pickup_radius": {"unit": "units", "inside_collected": true, "outside_collected": false}},
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _finish() -> void:
	if _errors.is_empty():
		print("FAN-1514 defensive/reactive, survivability and QoL probes passed.")
		quit(0)
		return
	for error_value in _errors:
		push_error(error_value)
	quit(1)
