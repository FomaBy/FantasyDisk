extends "res://tests/runtime_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): балансовый smoke класса druid.
# Домен владения: class/druid (docs/process/ownership_map.md).


func _initialize() -> void:
	_check_druid_identity_modes()
	await _check_druid_identity()
	await _check_druid_raven_totem()
	_finish("[balance/druid] PASSED")


func _check_druid_identity_modes() -> void:
	if ProgressionData.weapon("druid", "summon_amulet").get("command_mode", "") != "attack_target":
		_fail("Expected Druid summon amulet to command pets toward a target.")
		return


func _check_druid_identity() -> void:
	var holder := Node2D.new()
	holder.name = "DruidIdentityScene"
	root.add_child(holder)
	current_scene = holder
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	var druid := player_scene.instantiate()
	holder.add_child(druid)
	druid.global_position = Vector2(1500, 700)
	await process_frame
	druid.call("configure_character", "druid", "summon_amulet")
	var druid_enemy := enemy_scene.instantiate()
	holder.add_child(druid_enemy)
	druid_enemy.global_position = druid.global_position + Vector2(240, 0)
	var druid_weapon: Node = druid.get("equipped_weapon")
	druid_weapon.set_process(false)
	druid_weapon.call("_summon")
	await process_frame
	var commanded := false
	var druid_visual_ok := false
	for ally in get_nodes_in_group("allies"):
		var ally_target = ally.get("command_target")
		if ally.get("owner_node") == druid and ally_target != null and is_instance_valid(ally_target) and ally.get("command_mode") == "attack_target":
			commanded = true
			# SCRUM-902: стая — призрачный ростер (арт SCRUM-901/1015/1016);
			# каждый дух — одна из пяти ghost-записей с живым AnimatedBody.
			var ally_visual := str(ally.get("ally_visual_id"))
			if ally_visual.begins_with("druid_ghost_") and bool(ally.call("is_using_animated_ally_visual")):
				druid_visual_ok = true
	if not commanded:
		_fail("Expected Druid pets to receive an attack-target command.")
		return
	if not druid_visual_ok:
		_fail("Expected Druid pets to use the SCRUM-902 ghost roster visuals.")
		return
	for ally in get_nodes_in_group("allies"):
		if ally != null and is_instance_valid(ally):
			ally.queue_free()
	await process_frame
	holder.queue_free()
	current_scene = null
	await process_frame


func _check_druid_raven_totem() -> void:
	var holder := Node2D.new()
	holder.name = "DruidRavenTotemScene"
	root.add_child(holder)
	current_scene = holder
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var raven_druid := player_scene.instantiate()
	holder.add_child(raven_druid)
	raven_druid.global_position = Vector2(1620, 820)
	await process_frame
	raven_druid.call("configure_character", "druid", "raven_totem")
	var raven_weapon: Node = raven_druid.get("equipped_weapon")
	raven_weapon.set_process(false)
	raven_weapon.call("_attack")
	await process_frame
	var raven_visual_ok := false
	for deployable in get_nodes_in_group("deployed_sound_amps"):
		if _node_sprite_texture_path(deployable, "") == "res://assets/sprites/allies/deploy_raven_totem_field.png":
			raven_visual_ok = true
	if not raven_visual_ok:
		_fail("Expected Druid raven totem deployables to use the raven field sprite.")
		return
	holder.queue_free()
	current_scene = null
	await process_frame
