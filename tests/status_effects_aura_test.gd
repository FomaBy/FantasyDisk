extends SceneTree

const StatusEffects := preload("res://scripts/status_effects.gd")


func _initialize() -> void:
	var errors: Array = []
	await _test_status_duration_damage_and_dot(errors)
	await _test_player_aura_applies_in_radius(errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Status/aura: %s" % error)
		push_error("Status/aura test failed: %d errors." % errors.size())
		quit(1)
		return
	print("Status/aura test passed.")
	quit(0)


func _test_status_duration_damage_and_dot(errors: Array) -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	var enemy := enemy_scene.instantiate()
	holder.add_child(enemy)
	enemy.set("max_health", 1000.0)
	enemy.set("health", 1000.0)
	await process_frame

	StatusEffects.apply_status(enemy, "test_vulnerable", {
		"duration": 0.50,
		"damage_taken_multiplier": 1.25,
		"dot_damage": 5.0,
		"dot_interval": 0.20,
		"marker_color": Color(1.0, 0.4, 0.4, 1.0),
	})
	StatusEffects.apply_status(enemy, "bastion_taunt", {
		"duration": 0.50,
		"taunt_owner": 4242,
	})
	if int(StatusEffects.status_value(enemy, "bastion_taunt", "taunt_owner", 0)) != 4242:
		errors.append("Expected scalar status lookup without a full snapshot.")
	if int(StatusEffects.status_value(enemy, "missing", "taunt_owner", 7)) != 7:
		errors.append("Expected scalar status lookup to preserve its default.")
	enemy.call("take_damage", 20.0)
	if float(enemy.get("health")) > 975.1:
		errors.append("Expected vulnerability to increase incoming damage.")
	if not enemy.has_meta(StatusEffects.MARKER_META_KEY):
		errors.append("Expected status marker metadata to be set.")
	StatusEffects.tick(enemy, 0.25)
	if float(enemy.get("health")) > 970.1:
		errors.append("Expected DoT status to tick damage.")
	StatusEffects.tick(enemy, 0.45)
	if StatusEffects.has_status(enemy, "test_vulnerable"):
		errors.append("Expected status to expire after duration.")
	if enemy.has_meta(StatusEffects.META_KEY) or enemy.has_meta(StatusEffects.MARKER_META_KEY):
		errors.append("Expected final status expiry to remove status and marker metadata.")
	holder.queue_free()
	await process_frame


func _test_player_aura_applies_in_radius(errors: Array) -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var ally_scene := load("res://scenes/AllyMinion.tscn") as PackedScene
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	var player := player_scene.instantiate()
	holder.add_child(player)
	player.global_position = Vector2(600, 600)
	await process_frame
	player.call("configure_character", "druid", "summon_amulet")
	var weapon: Node = player.get("equipped_weapon")
	if weapon != null:
		weapon.set_process(false)
	player.set("derived_parameters", {
		"aura_radius": 240.0,
		"support_multiplier": 1.4,
		"move_speed": player.get("speed"),
		"health_point": player.get("max_health"),
	})
	player.set("_status_aura_cooldown_left", 0.0)

	var ally := ally_scene.instantiate()
	holder.add_child(ally)
	ally.set("owner_node", player)
	ally.global_position = player.global_position + Vector2(90, 0)
	var enemy := enemy_scene.instantiate()
	holder.add_child(enemy)
	enemy.set("max_health", 100000.0)
	enemy.set("health", 100000.0)
	enemy.global_position = player.global_position + Vector2(120, 0)
	await process_frame
	player.call("_update_class_status_auras")
	if not StatusEffects.has_status(ally, "command_aura"):
		errors.append("Expected Druid aura to buff owned ally inside radius.")
	if not StatusEffects.has_status(enemy, "command_pressure"):
		errors.append("Expected Druid aura to debuff enemy inside radius.")
	if StatusEffects.damage_multiplier(ally) <= 1.0:
		errors.append("Expected command aura to increase ally damage multiplier.")
	if StatusEffects.speed_multiplier(enemy) >= 1.0:
		errors.append("Expected command pressure to slow enemy.")
	holder.queue_free()
	await process_frame
