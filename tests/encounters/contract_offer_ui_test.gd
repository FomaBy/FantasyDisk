extends SceneTree
## FAN-1452 offer UI: declared content zones, safe HUD/FAB reserves and safe
## decline/timeout interaction. Geometry comes from the approved UI handoff.

const OFFER_SCENE := preload("res://scenes/ui/encounter_contract_offer.tscn")
const OFFER_SCRIPT := preload("res://scripts/ui/encounter_contract_offer.gd")

var errors: Array[String] = []


func _initialize() -> void:
	_check_safe_zone_matrix()
	await _check_safe_default_and_copy()
	await _check_timeout_declines()
	if not errors.is_empty():
		for error in errors:
			push_error("contract-offer-ui: " + error)
		quit(1)
		return
	print("FAN-1452 encounter contract offer UI passed.")
	quit(0)


func _check_safe_zone_matrix() -> void:
	for viewport in [Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1440)]:
		var layout: Dictionary = OFFER_SCRIPT.layout_for(viewport)
		var modal: Rect2 = layout["modal"]
		var top_hud: Rect2 = layout["top_hud"]
		var fab: Rect2 = layout["fab"]
		_expect(not modal.intersects(top_hud) and not modal.intersects(fab),
			"modal must preserve HUD and FAB reserves at %s" % str(viewport))
		for key in ["risk_icon", "reward_icon", "risk_value", "reward_value", "accept", "decline", "timeout"]:
			var zone: Rect2 = layout[key]
			_expect(modal.encloses(zone), "%s must remain inside the modal safe frame at %s" % [key, str(viewport)])
		_expect(not (layout["accept"] as Rect2).intersects(layout["decline"] as Rect2),
			"Accept and Decline hit targets must not overlap at %s" % str(viewport))


func _check_safe_default_and_copy() -> void:
	var offer := OFFER_SCENE.instantiate() as Control
	root.add_child(offer)
	await process_frame
	offer.present({"timeout_seconds": 12.0, "risk_percent": 35, "risk_enemies": 3,
		"reward_xp": 10, "reward_gold": 11, "reward_capped": false})
	await process_frame
	var decline := offer.get_node_or_null("DeclineButton") as Button
	var risk_value := offer.get_node_or_null("RiskValue") as Label
	var reward_value := offer.get_node_or_null("RewardValue") as Label
	_expect(decline != null and decline.has_focus(), "Decline must be the initial keyboard/controller focus")
	_expect(risk_value != null and risk_value.text.contains("35"), "risk must be visible before accepting")
	_expect(reward_value != null and reward_value.text.contains("10") and reward_value.text.contains("11"),
		"depth-aware reward must be visible before accepting")
	var decisions: Array = []
	offer.decision_made.connect(func(decision, reason): decisions.append([decision, reason]))
	offer.debug_decline()
	await process_frame
	_expect(decisions == [["declined", "declined"]], "safe default decline must emit one machine-readable decision")


func _check_timeout_declines() -> void:
	var offer := OFFER_SCENE.instantiate() as Control
	root.add_child(offer)
	await process_frame
	var decisions: Array = []
	offer.decision_made.connect(func(decision, reason): decisions.append([decision, reason]))
	offer.present({"timeout_seconds": 1.0})
	offer._process(1.1)
	await process_frame
	_expect(decisions == [["declined", "timeout"]], "timeout must choose the same no-penalty decline path")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
