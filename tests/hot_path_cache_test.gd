extends SceneTree

const CombatTargetQuery := preload("res://scripts/combat_target_query.gd")
const ThreatIndicators := preload("res://scripts/threat_indicators.gd")


class ThreatStub extends Node2D:
	var rank := ""

	func _init(value: String) -> void:
		rank = value

	func threat_marker_rank() -> String:
		return rank


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array[String] = []
	var host := Node2D.new()
	root.add_child(host)
	var overlay := ThreatIndicators.new()
	host.add_child(overlay)

	var boss := ThreatStub.new("boss")
	host.add_child(boss)
	boss.add_to_group("enemies")
	boss.add_to_group("bosses")
	var shooter := ThreatStub.new("shooter")
	host.add_child(shooter)
	shooter.add_to_group("enemies")
	var ordinary := ThreatStub.new("")
	host.add_child(ordinary)
	ordinary.add_to_group("enemies")
	await process_frame

	var generation_before := CombatTargetQuery.cache_generation()
	overlay.call("_refresh_threat_candidates")
	var candidates: Array = overlay.call("_threat_candidates")
	var generation_after := CombatTargetQuery.cache_generation()
	if generation_after != generation_before + 1:
		errors.append("threat refresh must build the shared target cache exactly once")
	if candidates.size() != 2:
		errors.append("threat cache must contain exactly boss+shooter without duplicate group entries (got %d)" % candidates.size())
	var ids := {}
	for candidate in candidates:
		ids[(candidate as Node).get_instance_id()] = true
	if ids.size() != candidates.size():
		errors.append("threat cache contains duplicate node instances")

	CombatTargetQuery.enemies(overlay)
	if CombatTargetQuery.cache_generation() != generation_after:
		errors.append("same-frame consumers must reuse CombatTargetQuery instead of rebuilding the group array")

	host.queue_free()
	if errors.is_empty():
		print("Hot path cache test passed.")
		quit(0)
	else:
		for error in errors:
			push_error("Hot path cache: %s" % error)
		quit(1)
