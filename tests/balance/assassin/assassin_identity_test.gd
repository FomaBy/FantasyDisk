extends "res://tests/runtime_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): балансовый smoke класса assassin.
# Домен владения: class/assassin (docs/process/ownership_map.md).


func _initialize() -> void:
	await _check_assassin_identity()
	_finish("[balance/assassin] PASSED")


func _check_assassin_identity() -> void:
	var holder := Node2D.new()
	holder.name = "AssassinIdentityScene"
	root.add_child(holder)
	current_scene = holder
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	var assassin := player_scene.instantiate()
	holder.add_child(assassin)
	assassin.global_position = Vector2(1700, 700)
	await process_frame
	assassin.call("configure_character", "assassin", "chakrams")
	var assassin_weapon: Node = assassin.get("equipped_weapon")
	if assassin_weapon != null:
		assassin_weapon.set_process(false)
	var assassin_enemy := enemy_scene.instantiate()
	holder.add_child(assassin_enemy)
	assassin_enemy.global_position = assassin.global_position + Vector2(220, 0)
	await process_frame
	var assassin_start: Vector2 = assassin.global_position
	var vfx_before := {}
	for existing_vfx in holder.find_children("*Vfx", "Node2D", true, false):
		vfx_before[int(existing_vfx.get_instance_id())] = true
	assassin.set("_assassin_crit_shadow_cooldown_left", 0.0)
	assassin.call("trigger_assassin_crit_shadow", assassin_enemy, 100.0)
	if assassin.global_position.distance_to(assassin_start) > 0.01:
		_fail("Expected Assassin critical shadow hook to preserve player-controlled position.")
		return
	var spawned_assassin_vfx_names := []
	for current_vfx in holder.find_children("*Vfx", "Node2D", true, false):
		if not vfx_before.has(int(current_vfx.get_instance_id())):
			spawned_assassin_vfx_names.append(String(current_vfx.name))
	if spawned_assassin_vfx_names.is_empty():
		_fail("Expected Assassin critical shadow hook to keep a non-moving combat/VFX effect.")
		return
	holder.queue_free()
	current_scene = null
	await process_frame
