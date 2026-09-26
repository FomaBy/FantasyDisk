extends SceneTree

# FAN-3922 (FD15): focused class-aura cadence and inactive-path regression.
# Run: python3 tools/godot_gate.py --headless --path . \
#     --script res://tests/player_aura_cadence_test.gd

const PlayerScript := preload("res://scripts/player.gd")

const EPS := 0.0001


func _initialize() -> void:
	var errors: Array = []
	await process_frame
	_check_inactive_class_skips_aura_node_lookup(errors)
	_check_druid_cadence(errors)
	await process_frame
	_finish(errors)


func _check_inactive_class_skips_aura_node_lookup(errors: Array) -> void:
	var player = PlayerScript.new()
	player.set_physics_process(false)
	root.add_child(player)
	player.configure_character("berserk")

	# A ring-shaped sentinel makes the otherwise invisible get_node_or_null
	# observable: inactive classes must not discover or mutate it.
	var sentinel = PlayerScript.WildForceAuraRing.new()
	sentinel.name = PlayerScript.WILD_AURA_RING_NAME
	player.add_child(sentinel)
	player.set("_status_aura_cooldown_left", 0.0)
	player.call("_update_class_status_auras")
	if sentinel.is_queued_for_deletion():
		errors.append("inactive aura: Berserk looked up and queued the ring sentinel")
	if absf(float(player.get("_status_aura_cooldown_left"))) > EPS:
		errors.append("inactive aura: a class without aura effects consumed the cadence")

	player.free()


func _check_druid_cadence(errors: Array) -> void:
	var player = PlayerScript.new()
	player.set_physics_process(false)
	root.add_child(player)
	player.configure_character("druid")
	player.set("_status_aura_cooldown_left", 0.0)
	player.call("_update_class_status_auras")

	var first_ring := player.get_node_or_null(PlayerScript.WILD_AURA_RING_NAME)
	if first_ring == null:
		errors.append("Druid aura: the first eligible update did not create the wild-force ring")
	if absf(float(player.get("_status_aura_cooldown_left")) - 0.55) > EPS:
		errors.append("Druid aura: eligible update must preserve the 0.55 second cadence")

	player.call("_update_class_status_auras")
	if player.get_node_or_null(PlayerScript.WILD_AURA_RING_NAME) != first_ring:
		errors.append("Druid aura: a cooldown-gated update replaced the live ring")
	if absf(float(player.get("_status_aura_cooldown_left")) - 0.55) > EPS:
		errors.append("Druid aura: a cooldown-gated update changed the cadence")

	player.free()


func _finish(errors: Array) -> void:
	if errors.is_empty():
		print("FAN-3922 aura cadence passed inactive lookup elimination and unchanged Druid timing.")
		quit(0)
		return
	for error in errors:
		push_error(error)
	quit(1)
