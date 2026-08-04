class_name UltimateGuardPreventionLedger
extends RefCounted

signal owner_resource_emitted(event: Dictionary)

var _guard_prevention: Dictionary = {}
var _owner_resources: Dictionary = {}
var _claimed_events: Dictionary = {}


func configure(
		owner_id: String,
		resource_id: String,
		cap: float,
		facing: Vector2,
		arc_degrees: float,
		sources: Array[String]
) -> bool:
	if owner_id.strip_edges().is_empty() or resource_id.strip_edges().is_empty() \
			or not is_finite(cap) or cap <= 0.0 or facing.length_squared() <= 0.001 \
			or not is_finite(arc_degrees) or arc_degrees <= 0.0 or arc_degrees > 360.0:
		return false
	var admitted_sources: Array[String] = []
	for raw_source in sources:
		var source := raw_source.strip_edges()
		if source.is_empty():
			return false
		if not admitted_sources.has(source):
			admitted_sources.append(source)
	if admitted_sources.is_empty():
		return false
	admitted_sources.sort()
	var requested := {
		"owner_id": owner_id.strip_edges(),
		"resource_id": resource_id.strip_edges(),
		"cap": cap,
		"facing": facing.normalized(),
		"arc_degrees": arc_degrees,
		"sources": admitted_sources,
	}
	if not _guard_prevention.is_empty():
		return _guard_prevention == requested
	_guard_prevention = requested
	return true


func owner_id() -> String:
	return str(_guard_prevention.get("owner_id", ""))


func record(event: Dictionary) -> float:
	if _guard_prevention.is_empty():
		return 0.0
	var owner_id := str(event.get("owner_id", "")).strip_edges()
	var resource_id := str(_guard_prevention["resource_id"])
	var event_id := str(event.get("event_id", "")).strip_edges()
	var source := str(event.get("source", "")).strip_edges()
	var direction = event.get("direction")
	var incoming = event.get("incoming_amount")
	var applied = event.get("applied_amount")
	var reported_prevented = event.get("prevented_amount")
	if owner_id != str(_guard_prevention["owner_id"]) or event_id.is_empty() \
			or not _guard_prevention["sources"].has(source) or not direction is Vector2 \
			or not (incoming is int or incoming is float) or incoming is bool \
			or not (applied is int or applied is float) or applied is bool \
			or not (reported_prevented is int or reported_prevented is float) or reported_prevented is bool:
		return 0.0
	var incoming_amount := float(incoming)
	var applied_amount := float(applied)
	var prevented_amount := float(reported_prevented)
	var incoming_direction := direction as Vector2
	if not is_finite(incoming_amount) or not is_finite(applied_amount) \
			or not is_finite(prevented_amount) or incoming_amount <= 0.0 \
			or applied_amount < 0.0 or applied_amount > incoming_amount \
			or incoming_direction.length_squared() <= 0.001:
		return 0.0
	var measured_prevented := maxf(incoming_amount - applied_amount, 0.0)
	if measured_prevented <= 0.0 or not is_equal_approx(prevented_amount, measured_prevented):
		return 0.0
	var facing: Vector2 = _guard_prevention["facing"]
	var half_arc := deg_to_rad(float(_guard_prevention["arc_degrees"]) * 0.5)
	if facing.dot(incoming_direction.normalized()) < cos(half_arc):
		return 0.0
	return apply(owner_id, resource_id, measured_prevented, float(_guard_prevention["cap"]), "guard:%s" % event_id)


func apply(owner_id: String, resource_id: String, amount: float, cap: float, event_id: String) -> float:
	if owner_id.strip_edges().is_empty() or resource_id.strip_edges().is_empty() \
			or event_id.strip_edges().is_empty() or not is_finite(amount) or amount <= 0.0 \
			or not is_finite(cap) or cap <= 0.0:
		return 0.0
	var normalized_owner := owner_id.strip_edges()
	var normalized_resource := resource_id.strip_edges()
	var resources: Dictionary = _owner_resources.get(normalized_owner, {})
	var record: Dictionary = resources.get(normalized_resource, {})
	if record.is_empty():
		record = {"cap": cap, "amount": 0.0, "spent": false}
	elif not is_equal_approx(float(record.get("cap", 0.0)), cap) or bool(record.get("spent", false)):
		return 0.0
	if not _claim_event("owner_resource:%s:%s:%s" % [normalized_owner, normalized_resource, event_id]):
		return 0.0
	var granted := minf(amount, maxf(cap - float(record.get("amount", 0.0)), 0.0))
	record["amount"] = float(record.get("amount", 0.0)) + granted
	resources[normalized_resource] = record
	_owner_resources[normalized_owner] = resources
	return granted


func amount(owner_id: String, resource_id: String) -> float:
	var resources = _owner_resources.get(owner_id.strip_edges(), {})
	if not resources is Dictionary:
		return 0.0
	var record = (resources as Dictionary).get(resource_id.strip_edges(), {})
	return float((record as Dictionary).get("amount", 0.0)) if record is Dictionary else 0.0


func consume(owner_id: String, resource_id: String, event_id: String) -> Dictionary:
	var result := {
		"owner_id": owner_id.strip_edges(),
		"resource_id": resource_id.strip_edges(),
		"event_id": event_id.strip_edges(),
		"amount": 0.0,
	}
	if result["owner_id"].is_empty() or result["resource_id"].is_empty() or result["event_id"].is_empty():
		return result
	var resources = _owner_resources.get(result["owner_id"], {})
	if not resources is Dictionary:
		return result
	var record = (resources as Dictionary).get(result["resource_id"], {})
	if not record is Dictionary or bool((record as Dictionary).get("spent", false)) \
			or not _claim_event("owner_resource_consume:%s:%s:%s" % [
				result["owner_id"], result["resource_id"], result["event_id"]
			]):
		return result
	result["amount"] = maxf(float((record as Dictionary).get("amount", 0.0)), 0.0)
	(record as Dictionary)["amount"] = 0.0
	(record as Dictionary)["spent"] = true
	(resources as Dictionary)[result["resource_id"]] = record
	_owner_resources[result["owner_id"]] = resources
	if float(result["amount"]) > 0.0:
		owner_resource_emitted.emit(result.duplicate(true))
	return result


func clear() -> void:
	_guard_prevention.clear()
	_owner_resources.clear()
	_claimed_events.clear()


func _claim_event(event_id: String) -> bool:
	if _claimed_events.has(event_id):
		return false
	_claimed_events[event_id] = true
	return true
