extends SceneTree

const Contract := preload("res://scripts/take_damage_contract.gd")
const BerserkWeaponScript := preload("res://scripts/berserk_weapon.gd")
const ClassWeaponScript := preload("res://scripts/class_weapon.gd")
const AllyScript := preload("res://scripts/ally_minion.gd")
const EnemyScene := preload("res://scenes/Enemy.tscn")

var _errors: Array[String] = []


class LegacyTarget extends Node:
	var damage := 0.0

	func take_damage(amount: float) -> void:
		damage += amount

	func _show_combat_feedback() -> void:
		pass


class FeedbackTarget extends Node:
	var damage := 0.0
	var last_feedback: Dictionary = {}

	func take_damage(amount: float, feedback: Dictionary = {}) -> void:
		damage += amount
		last_feedback = feedback.duplicate(true)

	func _show_combat_feedback() -> void:
		pass


class VariantTarget extends Node:
	var last_feedback: Variant = null

	func take_damage(_amount: float, feedback = null) -> void:
		last_feedback = feedback

	func _show_combat_feedback() -> void:
		pass


class SourceTarget extends Node:
	var last_source := "not-called"

	func take_damage(_amount: float, source := "") -> void:
		last_source = source


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	current_scene = holder
	root.set_meta("combat_feedback", true)
	var weapons := [BerserkWeaponScript.new(), ClassWeaponScript.new()]
	for weapon in weapons:
		_test_weapon(weapon)
		_test_killing_feedback(weapon, holder)
		weapon.free()
	_test_summon()
	holder.queue_free()
	await process_frame
	if not _errors.is_empty():
		for message in _errors:
			push_error(message)
		quit(1)
		return
	print("take_damage_weapon_contract_test passed.")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _test_weapon(weapon: Node) -> void:
	var legacy := LegacyTarget.new()
	legacy.add_to_group("enemies")
	weapon.call("_call_take_damage", legacy, 7.0, {"damage_type": "magic"})
	_check(is_equal_approx(legacy.damage, 7.0), "One-argument enemy must receive a legacy hit.")
	legacy.free()

	# Same script, different instance eligibility; membership must never be cached.
	var enemy := FeedbackTarget.new()
	var other := FeedbackTarget.new()
	enemy.add_to_group("enemies")
	for iteration in range(2):
		_check(bool(weapon.call("_take_damage_accepts_feedback", enemy)), "Grouped feedback target must opt in.")
		_check(not bool(weapon.call("_take_damage_accepts_feedback", other)), "Ungrouped same-script target must stay legacy.")
		weapon.call("_call_take_damage", enemy, 3.0, {"damage_type": "magic", "critical": true, "dark_decay": true})
		_check(enemy.last_feedback == {"damage_type": "magic", "critical": true, "dark_decay": true, "player_owned": true}, "Weapon feedback fields must be preserved.")
		weapon.call("_call_take_damage", other, 2.0, {"damage_type": "magic"})
		_check(other.last_feedback.is_empty(), "Ineligible target must receive only the amount.")
	enemy.remove_from_group("enemies")
	other.add_to_group("enemies")
	_check(not bool(weapon.call("_take_damage_accepts_feedback", enemy)), "Removing membership must take effect after cache warmup.")
	_check(bool(weapon.call("_take_damage_accepts_feedback", other)), "Adding membership must take effect after cache warmup.")
	enemy.free()
	other.free()

	# Existing weapon arity routing accepts Variant=null, whereas the stricter
	# player API deliberately requires Dictionary type/default evidence.
	var variant := VariantTarget.new()
	variant.add_to_group("enemies")
	_check(not Contract.accepts_feedback(variant), "Variant=null must remain excluded from the strict dictionary API.")
	weapon.call("_call_take_damage", variant, 1.0, {"damage_type": "physical"})
	_check(variant.last_feedback == {"damage_type": "physical", "player_owned": true}, "Weapon arity routing must preserve Variant feedback.")
	variant.free()
	var source := SourceTarget.new()
	_check(not Contract.accepts_feedback(source), "String source must remain excluded from dictionary routing.")
	weapon.call("_call_take_damage", source, 1.0, {"damage_type": "magic"})
	_check(source.last_source == "", "Non-enemy source target must retain the default String source.")
	source.free()


func _test_killing_feedback(weapon: Node, holder: Node) -> void:
	var enemy := EnemyScene.instantiate()
	holder.add_child(enemy)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	enemy.set("health", 1.0)
	var observed: Array[Dictionary] = []
	enemy.connect("died", func(dead: Node) -> void:
		observed.append(dead.get_meta("killing_hit_feedback", {}).duplicate(true)))
	weapon.call("_call_take_damage", enemy, 2.0, {"damage_type": "magic", "critical": true})
	_check(observed == [{"damage_type": "magic", "critical": true, "player_owned": true}], "Real enemy must expose player-owned feedback before died.")
	var labels := get_nodes_in_group("combat_feedback_labels")
	var found_critical := false
	for label in labels:
		if label is Label and label.name == "CombatCritNumber":
			found_critical = found_critical or label.modulate.is_equal_approx(Color(1.0, 0.24, 0.16, 1.0))
	_check(found_critical, "Real killing hit must retain critical damage-number colouring.")
	# Also check the noncritical channel through the same real entry point.
	var magic_enemy := EnemyScene.instantiate()
	holder.add_child(magic_enemy)
	magic_enemy.set_process(false)
	magic_enemy.set_physics_process(false)
	weapon.call("_call_take_damage", magic_enemy, 1.0, {"damage_type": "magic"})
	var found_magic := false
	for label in get_nodes_in_group("combat_feedback_labels"):
		if label is Label and label.name == "CombatDamageNumber":
			found_magic = found_magic or label.modulate.is_equal_approx(magic_enemy.damage_type_color("magic"))
	_check(found_magic, "Real hit must retain magic damage-number colouring.")


func _test_summon() -> void:
	var ally := AllyScript.new()
	var legacy := LegacyTarget.new()
	var target := FeedbackTarget.new()
	var variant := VariantTarget.new()
	var feedback := {"damage_type": "magic", "player_owned": false}
	for iteration in range(2):
		ally.call("_deal_typed_damage", legacy, 4.0, feedback)
		ally.call("_deal_typed_damage", target, 4.0, feedback)
		ally.call("_deal_typed_damage", variant, 4.0, feedback)
	_check(is_equal_approx(legacy.damage, 8.0), "Summon must preserve one-argument calls.")
	_check(target.last_feedback == feedback, "Summon must preserve feedback without adding weapon ownership or requiring enemy membership.")
	_check(variant.last_feedback == feedback, "Summon must preserve Variant arity routing.")
	ally.call("_deal_typed_damage", null, 4.0, feedback)
	var no_damage := Node.new()
	ally.call("_deal_typed_damage", no_damage, 4.0, feedback)
	no_damage.free()
	legacy.free()
	target.free()
	variant.free()
	ally.free()
