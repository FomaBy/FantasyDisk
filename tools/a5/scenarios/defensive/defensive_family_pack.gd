extends RefCounted

# FAN-1514: isolated behavioral oracle for defensive/reactive finals and the
# incoming-damage QoL probes. Production code only supplies observations; this
# pack owns the threshold policy and fails closed on a missing observation.

const PACK_ID := "a5_defensive_reactive"
const PACK_CONTRACT := "a5.scenario-pack.v1"
const FRAGMENT_SCHEMA := "fan1514.a5-defensive-fragment.v1"
const FRAGMENT_DIR := "res://docs/design/reports/fan1438_a5_balance/fragments/defensive"
const FRAGMENT_PATH := FRAGMENT_DIR + "/defensive_reactive_qol.json"
const SEEDS := [151401, 151402, 151403]
const MAX_EVENT_CV := 0.35

const REACTIVE_MATRIX := [
	{"id": "dodge", "class_id": "thief", "weapon_id": "thief_smoke_bomb", "mechanic_id": "smoke_dodge_triggered_burst", "event": "dodge"},
	{"id": "block", "class_id": "knight", "weapon_id": "long_spear", "mechanic_id": "spear_block_counter_line", "event": "block"},
	{"id": "absorb", "class_id": "knight", "weapon_id": "tower_shield", "mechanic_id": "shield_stored_damage_bash", "event": "damage_absorbed"},
	{"id": "retaliation", "class_id": "priest", "weapon_id": "priest_censer", "mechanic_id": "censer_absorb_retaliation", "event": "damage_absorbed"},
]

const QUALITY_CONTRACT := {
	"move_speed": {"unit": "units/s", "window_seconds": 0.5, "minimum": 1.0},
	"pickup_radius": {"unit": "units", "inside_margin": 0.1, "outside_margin": 0.1},
}


static func contract() -> Dictionary:
	return {
		"pack_id": PACK_ID,
		"pack_contract": PACK_CONTRACT,
		"fragment_schema": FRAGMENT_SCHEMA,
		"seeds": SEEDS,
		"max_event_cv": MAX_EVENT_CV,
		"quality": QUALITY_CONTRACT,
	}


static func coefficient_of_variation(values: Array) -> float:
	if values.size() < 2:
		return INF
	var total := 0.0
	for value in values:
		total += float(value)
	var mean := total / float(values.size())
	if is_zero_approx(mean):
		return INF
	var variance := 0.0
	for value in values:
		variance += pow(float(value) - mean, 2.0)
	return sqrt(variance / float(values.size())) / absf(mean)


static func verify_matrix(matrix := REACTIVE_MATRIX) -> Dictionary:
	var errors := PackedStringArray()
	var seen := {}
	for entry_value in matrix:
		var entry: Dictionary = entry_value
		var id := str(entry.get("id", ""))
		if id.is_empty() or seen.has(id):
			errors.append("reactive matrix id %s is missing or duplicated" % id)
		seen[id] = true
		for field in ["class_id", "weapon_id", "mechanic_id", "event"]:
			if str(entry.get(field, "")).is_empty():
				errors.append("%s is missing %s" % [id, field])
	for expected in ["dodge", "block", "absorb", "retaliation"]:
		if not seen.has(expected):
			errors.append("reactive matrix is missing %s" % expected)
	return {"ok": errors.is_empty(), "errors": errors}


static func evaluate_reactive(entry: Dictionary, measurement: Dictionary) -> Dictionary:
	var errors := PackedStringArray()
	var id := str(entry.get("id", ""))
	var enabled: Dictionary = measurement.get("enabled", {})
	var disabled: Dictionary = measurement.get("disabled", {})
	var samples: Array = measurement.get("event_samples", [])
	if int(enabled.get("incoming_hits", 0)) <= 0:
		errors.append("%s enabled arm observed no incoming hits" % id)
	if int(enabled.get("expected_events", 0)) <= 0:
		errors.append("%s enabled arm observed no %s event" % [id, entry.get("event", "")])
	if float(enabled.get("final_damage", 0.0)) <= 0.0:
		errors.append("%s enabled arm observed no final damage" % id)
	if not (enabled.get("sources", []) as Array).has("Player.take_damage"):
		errors.append("%s did not retain incoming-damage source attribution" % id)
	if int(disabled.get("expected_events", 0)) != 0:
		errors.append("%s disabled arm resolved an expected event" % id)
	if float(disabled.get("final_damage", 0.0)) != 0.0:
		errors.append("%s disabled arm dealt final damage" % id)
	if samples.size() != SEEDS.size():
		errors.append("%s has %d samples, expected %d" % [id, samples.size(), SEEDS.size()])
	for sample in samples:
		if int(sample) <= 0:
			errors.append("%s has an empty expected-event sample" % id)
	var cv := coefficient_of_variation(samples)
	if not is_finite(cv) or cv > MAX_EVENT_CV:
		errors.append("%s event variance is inconclusive (cv=%s)" % [id, "inf" if not is_finite(cv) else "%.4f" % cv])
	return {"ok": errors.is_empty(), "id": id, "cv": cv if is_finite(cv) else -1.0, "errors": errors}


static func evaluate_survivability(measurement: Dictionary) -> Dictionary:
	var errors := PackedStringArray()
	for field in ["hp_loss", "effective_health", "ttd_seconds", "mitigated_amount", "sustain_healed", "shield_added", "lifesteal_healed"]:
		if float(measurement.get(field, 0.0)) <= 0.0:
			errors.append("survivability %s is not observable" % field)
	if str(measurement.get("source", "")).is_empty():
		errors.append("survivability source attribution is missing")
	if not (measurement.get("sources", []) as Array).has(str(measurement.get("source", ""))):
		errors.append("survivability source was not retained in the sample")
	return {"ok": errors.is_empty(), "errors": errors}


static func evaluate_quality(measurement: Dictionary) -> Dictionary:
	var errors := PackedStringArray()
	var movement: Dictionary = measurement.get("move_speed", {})
	var pickup: Dictionary = measurement.get("pickup_radius", {})
	var minimum := float((QUALITY_CONTRACT["move_speed"] as Dictionary).get("minimum", 0.0))
	if str(movement.get("unit", "")) != "units/s" or float(movement.get("speed", 0.0)) < minimum:
		errors.append("move-speed runtime threshold is not observable in units/s")
	if float(movement.get("distance", 0.0)) < float(movement.get("speed", 0.0)) * float(movement.get("window_seconds", 0.0)) - 0.1:
		errors.append("move-speed runtime distance fell below its pass boundary")
	if str(pickup.get("unit", "")) != "units" or not bool(pickup.get("inside_collected", false)) or bool(pickup.get("outside_collected", true)):
		errors.append("pickup-radius distance boundary did not hold")
	return {"ok": errors.is_empty(), "errors": errors}


static func evaluate_fragment(fragment: Dictionary) -> Dictionary:
	var errors := PackedStringArray()
	if str(fragment.get("fragment_schema", "")) != FRAGMENT_SCHEMA:
		errors.append("fragment schema mismatch")
	if str(fragment.get("pack_contract", "")) != PACK_CONTRACT:
		errors.append("pack contract mismatch")
	for matrix_error in verify_matrix().get("errors", []):
		errors.append(str(matrix_error))
	var reactive: Dictionary = fragment.get("reactive", {})
	for entry_value in REACTIVE_MATRIX:
		var entry: Dictionary = entry_value
		var id := str(entry["id"])
		if not reactive.has(id):
			errors.append("fragment has no %s reactive measurement" % id)
			continue
		for error_value in evaluate_reactive(entry, reactive[id]).get("errors", []):
			errors.append(str(error_value))
	for error_value in evaluate_survivability(fragment.get("survivability", {})).get("errors", []):
		errors.append(str(error_value))
	for error_value in evaluate_quality(fragment.get("quality", {})).get("errors", []):
		errors.append(str(error_value))
	return {"ok": errors.is_empty(), "errors": errors}
