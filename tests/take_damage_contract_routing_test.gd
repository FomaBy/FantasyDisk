extends SceneTree

const PlayerScene := preload("res://scenes/Player.tscn")
const EnemyScene := preload("res://scenes/Enemy.tscn")
const BossScene := preload("res://scenes/BossWarden.tscn")
const AllyMinionScript := preload("res://scripts/ally_minion.gd")


class FeedbackInferred extends Node:
	var last_feedback: Dictionary = {}

	func take_damage(_amount: float, feedback := {}) -> void:
		last_feedback = feedback.duplicate(true)


class FeedbackTyped extends Node:
	var last_feedback: Dictionary = {}

	func take_damage(_amount: float, feedback: Dictionary = {}) -> void:
		last_feedback = feedback.duplicate(true)


class SourceInferred extends Node:
	var last_source := "not-called"

	func take_damage(_amount: float, source := "") -> void:
		last_source = source


class SourceVariant extends Node:
	var last_source = "not-called"

	func take_damage(_amount: float, source = "") -> void:
		last_source = source


class SourceNil extends Node:
	var last_source = "not-called"

	func take_damage(_amount: float, source = null) -> void:
		last_source = source


func _initialize() -> void:
	var errors: Array = []
	var holder := Node2D.new()
	root.add_child(holder)
	current_scene = holder
	root.set_meta("combat_feedback", true)

	var player := PlayerScene.instantiate() as Node2D
	holder.add_child(player)
	await process_frame
	player.set_process(false)
	player.set_physics_process(false)

	_test_reflection_and_routing(player, errors)
	_test_production_contracts(player, holder, errors)

	holder.queue_free()
	await process_frame
	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("take_damage_contract_routing_test passed: dict types=27, inferred String=4, Variant fallbacks=0.")
	quit(0)


func _test_reflection_and_routing(player: Node, errors: Array) -> void:
	var feedback := {"damage_type": "magic", "player_owned": true, "dark_decay": true}
	var cases := [
		{"label": "feedback := {}", "target": FeedbackInferred.new(), "type": TYPE_DICTIONARY, "accepts": true},
		{"label": "feedback: Dictionary = {}", "target": FeedbackTyped.new(), "type": TYPE_DICTIONARY, "accepts": true},
		{"label": "source := \"\"", "target": SourceInferred.new(), "type": TYPE_STRING, "accepts": false},
		{"label": "source = \"\"", "target": SourceVariant.new(), "type": TYPE_NIL, "accepts": false},
		{"label": "source = null", "target": SourceNil.new(), "type": TYPE_NIL, "accepts": false},
	]
	for test_case in cases:
		var target: Node = test_case["target"]
		var reflected_type := _second_argument_type(target)
		if reflected_type != int(test_case["type"]):
			errors.append("%s reflected type %d, expected %d." % [test_case["label"], reflected_type, test_case["type"]])
		var accepts := bool(player.call("_take_damage_accepts_feedback", target))
		if accepts != bool(test_case["accepts"]):
			errors.append("%s routing was %s, expected %s." % [test_case["label"], accepts, test_case["accepts"]])
		player.call("_apply_player_damage", target, 7.0, feedback)
		if accepts:
			if target.get("last_feedback") != feedback:
				errors.append("%s did not receive the complete feedback Dictionary." % test_case["label"])
		else:
			var expected_default = null if test_case["label"] == "source = null" else ""
			if target.get("last_source") != expected_default:
				errors.append("%s received structured feedback instead of its source default." % test_case["label"])
		target.free()


func _test_production_contracts(player: Node, holder: Node, errors: Array) -> void:
	var ally := AllyMinionScript.new()
	if bool(player.call("_take_damage_accepts_feedback", player)):
		errors.append("Player.take_damage(amount, source, attacker) must keep the String source contract.")
	if bool(player.call("_take_damage_accepts_feedback", ally)):
		errors.append("AllyMinion.take_damage(amount, source, attacker) must keep the String source contract.")
	if _argument_count(player) != 3 or _second_argument_type(player) != TYPE_STRING or not _has_attacker_argument(player):
		errors.append("Player.take_damage must retain String source plus attacker.")
	if _argument_count(ally) != 3 or _second_argument_type(ally) != TYPE_STRING or not _has_attacker_argument(ally):
		errors.append("AllyMinion.take_damage must retain String source plus attacker.")
	ally.free()

	for target in [EnemyScene.instantiate(), BossScene.instantiate()]:
		holder.add_child(target)
		target.set_process(false)
		target.set_physics_process(false)
		target.set("max_health", 100.0)
		target.set("health", 25.0)
		if target.get("dodge_chance") != null:
			target.set("dodge_chance", 0.0)
		if not bool(player.call("_take_damage_accepts_feedback", target)):
			errors.append("%s must retain the Dictionary feedback contract." % target.get_class())
			target.queue_free()
			continue

		var observed := {}
		target.connect("damage_applied", func(
			_observed_target: Node2D,
			_attempted_amount: float,
			_applied_amount: float,
			received_feedback: Dictionary
		) -> void:
			observed["feedback"] = received_feedback.duplicate(true)
		)
		var feedback := {"damage_type": "magic", "player_owned": true, "dark_decay": true}
		player.call("_apply_player_damage", target, 30.0, feedback)
		if observed.get("feedback", {}) != feedback:
			errors.append("%s.damage_applied did not receive complete combat feedback." % target.get_class())
		var attribution = target.get_meta("killing_hit_feedback", {})
		if attribution != feedback:
			errors.append("%s did not preserve player_owned/dark_decay kill attribution." % target.get_class())
		var label := holder.find_child("CombatDamageNumber", true, false) as Label
		if label == null:
			errors.append("%s did not route feedback through _show_combat_feedback." % target.get_class())
		elif not label.modulate.is_equal_approx(target.call("damage_type_color", "magic")):
			errors.append("%s combat feedback did not consume damage_type=magic." % target.get_class())
		_free_feedback_nodes()
		target.queue_free()


func _argument_count(target: Object) -> int:
	for method in target.get_method_list():
		if str(method.get("name", "")) == "take_damage":
			return int((method.get("args", []) as Array).size())
	return 0


func _second_argument_type(target: Object) -> int:
	for method in target.get_method_list():
		if str(method.get("name", "")) == "take_damage":
			var args: Array = method.get("args", [])
			if args.size() >= 2:
				return int((args[1] as Dictionary).get("type", TYPE_NIL))
	return TYPE_NIL


func _has_attacker_argument(target: Object) -> bool:
	for method in target.get_method_list():
		if str(method.get("name", "")) == "take_damage":
			var args: Array = method.get("args", [])
			if args.size() < 3:
				return false
			var attacker: Dictionary = args[2]
			return int(attacker.get("type", TYPE_NIL)) == TYPE_OBJECT \
				and str(attacker.get("class_name", "")) == "Node2D"
	return false


func _free_feedback_nodes() -> void:
	for group_name in ["combat_feedback_labels", "combat_feedback_flashes"]:
		for node in get_nodes_in_group(group_name):
			node.free()
