extends SceneTree

# FAN-3992: the Dark Mage wand chain stores its target nodes in an Array that
# outlives the frame (it is bound into tween callbacks). A target can be freed
# before its hop launches or before the orb arrives. The resolver used to cast
# the stored entry (`chain[i] as Node2D`) before checking it, which raises
# "Trying to cast a freed object" and aborts the callback; in a release template
# the same cast dereferences a dangling pointer (FAN-3985). The QA session gate
# hit it in dark_mage -> doctor (natural end).
#
# Each case stores a freed target ahead of a live one. The chain must skip the
# freed entry and still reach the live target; on the old code the cast error
# aborts the chain, so the live target is never hit. A live-only chain checks
# that hits and damage falloff are unchanged.
#
# Запуск: Godot --headless --path . --script res://tests/fan3992_dark_chain_freed_target_test.gd

const ClassWeapon := preload("res://scripts/class_weapon.gd")
const PD := preload("res://scripts/progression_data.gd")
# Far enough apart that a hit burst never reaches the other targets.
const SPACING := Vector2(700, 0)


class MockOwner extends CharacterBody2D:
	var derived_parameters := {
		"damage": 100.0,
		"magic_damage": 100.0,
		"crit_chance": 0.0,
		"crit_damage_multiplier": 1.0,
	}
	var run_modifiers := {}
	var stats := {}


class MockEnemy extends Node2D:
	var hits: Array = []

	func take_damage(amount: float, _feedback := {}) -> void:
		hits.append(amount)

	func _show_combat_feedback(_amount: float, _feedback: Dictionary) -> void:
		pass


var _errors := PackedStringArray()


func _initialize() -> void:
	await _check_hop_skips_freed_target()
	await _check_hit_skips_freed_target()
	await _check_live_chain_unchanged()
	if not _errors.is_empty():
		for error in _errors:
			push_error("FAN-3992 dark chain: %s" % error)
		quit(1)
		return
	print("FAN-3992 dark chain freed-target test passed (hop, hit, live chain).")
	quit(0)


func _check_hop_skips_freed_target() -> void:
	var holder := _new_scene("DarkChainFreedHop")
	var wand := _new_wand(holder)
	var live := _new_enemy(holder, wand.global_position + SPACING)
	await process_frame
	var chain: Array = [_freed_enemy(holder), live]
	wand._launch_dark_chain_hop(wand.global_position, chain, 0, 100.0)
	await create_timer(0.6).timeout
	if live.hits.size() != 1:
		_errors.append("hop: a freed first target must be skipped and the live one hit once, got %d hits" % live.hits.size())
	await _cleanup(holder)


func _check_hit_skips_freed_target() -> void:
	var holder := _new_scene("DarkChainFreedHit")
	var wand := _new_wand(holder)
	var live := _new_enemy(holder, wand.global_position + SPACING)
	# The orb has arrived, but the target it flew to was freed meanwhile.
	var orb := Node2D.new()
	holder.add_child(orb)
	orb.global_position = wand.global_position + SPACING * 0.5
	await process_frame
	var chain: Array = [_freed_enemy(holder), live]
	wand._resolve_dark_chain_hit(orb.get_instance_id(), chain, 0, 100.0)
	await create_timer(0.6).timeout
	if live.hits.size() != 1:
		_errors.append("hit: the chain must continue past a freed target to the live one, got %d hits" % live.hits.size())
	await _cleanup(holder)


func _check_live_chain_unchanged() -> void:
	var holder := _new_scene("DarkChainLive")
	var wand := _new_wand(holder)
	var first := _new_enemy(holder, wand.global_position + SPACING)
	var second := _new_enemy(holder, wand.global_position + SPACING * 2.0)
	await process_frame
	wand._launch_dark_chain_hop(wand.global_position, [first, second], 0, 100.0)
	await create_timer(1.0).timeout
	if first.hits.size() != 1 or second.hits.size() != 1:
		_errors.append("live chain: each target must be hit once, got %d and %d" % [first.hits.size(), second.hits.size()])
	else:
		var falloff := clampf(float(wand.get("pierce_damage_falloff")), 0.1, 1.0)
		var ratio := float(second.hits[0]) / maxf(float(first.hits[0]), 0.001)
		if absf(ratio - falloff) > 0.01:
			_errors.append("live chain: second hit must keep the %.2f falloff, got %.3f" % [falloff, ratio])
	await _cleanup(holder)


func _new_scene(scene_name: String) -> Node2D:
	var holder := Node2D.new()
	holder.name = scene_name
	root.add_child(holder)
	current_scene = holder
	return holder


func _new_wand(holder: Node2D) -> ClassWeapon:
	var owner := MockOwner.new()
	holder.add_child(owner)
	owner.global_position = Vector2(200, 400)
	var wand := ClassWeapon.new()
	owner.add_child(wand)
	wand.configure_weapon(PD.weapon("dark_mage", "dark_wand"))
	# Only the explicit calls above may fire.
	wand.set_process(false)
	wand.set("_cooldown", 1.0e9)
	return wand


func _new_enemy(holder: Node2D, position: Vector2) -> MockEnemy:
	var enemy := MockEnemy.new()
	enemy.add_to_group("enemies")
	holder.add_child(enemy)
	enemy.global_position = position
	return enemy


func _freed_enemy(holder: Node2D) -> Variant:
	var enemy := _new_enemy(holder, Vector2(-5000, -5000))
	enemy.free()
	return enemy


func _cleanup(holder: Node2D) -> void:
	holder.queue_free()
	current_scene = null
	await process_frame
	await process_frame
