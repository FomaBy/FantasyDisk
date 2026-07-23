extends SceneTree

# FAN-1574: contract-only regressions for the production-scene observer A/B.
# The 309-sample scene run remains explicit because it is intentionally expensive;
# these fixtures make every failure mode fail closed without faking callbacks.

const Generator := preload("res://tools/a5_balance_report.gd")

var _errors := PackedStringArray()


func _initialize() -> void:
	var enabled := _arm(true)
	var disabled := _arm(false)
	_check(bool(Generator.verify_observer_ab(enabled, disabled).get("ok", false)), "valid fixed-step enabled/disabled baseline must pass")
	_check(not bool(Generator.verify_observer_ab({}, disabled).get("ok", true)), "missing disabled baseline must fail closed")

	var identical_delivery := _arm(false)
	var delivery: Dictionary = (identical_delivery["samples"][0] as Dictionary).get("observer_delivery", {})
	delivery["subscription_count"] = 1
	delivery["callback_event_count"] = 1
	delivery["wiring_verified"] = true
	_check(not bool(Generator.verify_observer_ab(enabled, identical_delivery).get("ok", true)), "identical enabled/disabled observer delivery must fail closed")

	var numerator_change := _arm(false)
	var numerator_ledger: Dictionary = (numerator_change["samples"][0] as Dictionary).get("hp_ledger", {})
	numerator_ledger["total_applied_damage"] = float(numerator_ledger["total_applied_damage"]) + 1.0
	_check(not bool(Generator.verify_observer_ab(enabled, numerator_change).get("ok", true)), "canonical numerator change must fail closed")

	var frame_change := _arm(false)
	var frame_ledger: Dictionary = (frame_change["samples"][0] as Dictionary).get("hp_ledger", {})
	frame_ledger["measurement_frame_count"] = Generator.LIVE_MEASUREMENT_FRAMES - 1
	_check(not bool(Generator.verify_observer_ab(enabled, frame_change).get("ok", true)), "off-by-one measurement frame must fail closed")

	var rng_change := _arm(false)
	var probe: Dictionary = (rng_change["samples"][0] as Dictionary).get("observer_probe", {})
	probe["rng_probe"] = int(probe["rng_probe"]) + 1
	_check(not bool(Generator.verify_observer_ab(enabled, rng_change).get("ok", true)), "RNG consumption change must fail closed")

	_validate_every_projection_cell_mutation()
	_finish()


func _arm(observer_enabled: bool) -> Dictionary:
	var samples := []
	for index in range(Generator.OBSERVER_AB_SAMPLE_COUNT):
		samples.append(_sample(index, observer_enabled))
	return {"mode": "enabled" if observer_enabled else "disabled", "samples": samples}


func _sample(index: int, observer_enabled: bool) -> Dictionary:
	var numerator := 10.0 + float(index)
	var duration := Generator.LIVE_MEASUREMENT_FRAMES * Generator.LIVE_FIXED_DELTA
	var dpm := Generator._project_dpm(numerator, duration)
	return {
		"sample_key": "observer-%03d" % index,
		"pair": "fixture/weapon", "seed": 1000 + index, "scenario": "observer_solo", "fixture": "sustain", "target_cardinality": 1,
		"events": [{"event_id": "fixture#0000", "trace_id": "fixture", "frame": 120, "probe_phase": "measurement", "kind": "hit", "damage": numerator}],
		"counters": {"hits": 1, "damage_total": numerator},
		"hp_ledger": {
			"canonical_numerator": "ledger_total", "total_applied_damage": numerator,
			"measurement_duration_seconds": duration, "measurement_duration_snapped_seconds": snappedf(duration, 0.0001),
			"measurement_frame_count": Generator.LIVE_MEASUREMENT_FRAMES,
			"legacy_health_delta_numerator": numerator,
			"dpm_projections": {"ledger_raw_duration_dpm": dpm, "legacy_hp_delta_raw_duration_dpm": dpm},
		},
		"dpm": dpm,
		"observer_probe": {"mode": "enabled" if observer_enabled else "disabled", "measurement_duration_seconds": duration, "measurement_frame_count": Generator.LIVE_MEASUREMENT_FRAMES, "health_before": [1000.0], "health_after": [1000.0 - numerator], "health_delta": numerator, "rng_probe": 2000 + index},
		"observer_delivery": {
			"mode": "enabled" if observer_enabled else "disabled", "enabled": observer_enabled,
			"subscription_count": 4 if observer_enabled else 0, "callback_event_count": 1 if observer_enabled else 0,
			"callback_matches_witness": observer_enabled, "wiring_verified": observer_enabled,
		},
	}


func _validate_every_projection_cell_mutation() -> void:
	var pair_keys := []
	var rows := []
	for index in range(51):
		var pair := "class_%02d/weapon" % index
		pair_keys.append(pair)
		rows.append({"class_id": "class_%02d" % index, "weapon_id": "weapon", "level": 20, "scenario": "class_constellation", "live_solo_dpm_mean": float(index) + 1.0, "live_crowd_dpm_mean": float(index) + 2.0, "solo_variance_dpm2": float(index) + 3.0, "crowd_variance_dpm2": float(index) + 4.0})
	var dataset := {"roster": {"pair_keys": pair_keys}, "weapon_rows": rows}
	var original: Dictionary = Generator.projection_oracle_digest(dataset)
	_check(bool(original.get("ok", false)), "fixture 51x4 projection must be valid")
	for row_index in range(rows.size()):
		for field in ["live_solo_dpm_mean", "live_crowd_dpm_mean", "solo_variance_dpm2", "crowd_variance_dpm2"]:
			var mutated := dataset.duplicate(true)
			var mutation_rows: Array = mutated.get("weapon_rows", [])
			var row: Dictionary = mutation_rows[row_index]
			row[field] = float(row[field]) + 0.01
			var digest: Dictionary = Generator.projection_oracle_digest(mutated)
			_check(bool(digest.get("ok", false)) and str(digest.get("digest", "")) != str(original.get("digest", "")), "51x4 mutation %d/%s must fail closed" % [row_index, field])


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _finish() -> void:
	if not _errors.is_empty():
		for error_value in _errors:
			push_error(error_value)
		quit(1)
		return
	print("FAN-1574 observer A/B contract regressions passed.")
	quit(0)
