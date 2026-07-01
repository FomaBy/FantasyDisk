extends SceneTree

const Meta := preload("res://scripts/meta_progression.gd")
const CharacterData := preload("res://scripts/progression_data_characters.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")


func _initialize() -> void:
	_test_class_affinity_keystones_are_unique()
	_test_class_affinity_effects_are_filtered()
	await _test_attribute_nodes_create_different_profiles()
	print("Skill tree per-hero test passed.")
	quit(0)


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)


func _test_class_affinity_keystones_are_unique() -> void:
	var seen := {}
	for node in Meta.node_list():
		var node_data: Dictionary = node
		if str(node_data.get("kind", "")) == "keystone" and str(node_data.get("class_affinity", "")) != "":
			var class_id := str(node_data["class_affinity"])
			seen[class_id] = int(seen.get(class_id, 0)) + 1
			if not (node_data.get("effects", {}) is Dictionary) or (node_data.get("effects", {}) as Dictionary).is_empty():
				_fail("Class keystone '%s' has no effects." % str(node_data.get("id", "")))
				return
	for class_id in CharacterData.CHARACTER_CONFIGS.keys():
		var cid := str(class_id)
		if int(seen.get(cid, 0)) != 1:
			_fail("Expected exactly one class keystone for '%s', got %d." % [cid, int(seen.get(cid, 0))])
			return


func _test_class_affinity_effects_are_filtered() -> void:
	var state: Dictionary = Meta.default_state()
	state["skill_nodes"] = ["sig_berserk_minor", "sig_berserk_notable", "sig_berserk_keystone"]
	var account_mods := Meta.skill_modifiers(state)
	if not account_mods.is_empty():
		_fail("Expected account skill_modifiers() to skip class-affinity nodes.")
		return
	var berserk_mods := Meta.skill_modifiers_for_class(state, "berserk")
	if float(berserk_mods.get("damage_mult", 0.0)) <= 0.0 or float(berserk_mods.get("low_hp_damage_bonus", 0.0)) <= 0.0:
		_fail("Expected Berserk signature effects for selected Berserk.")
		return
	var soldier_mods := Meta.skill_modifiers_for_class(state, "soldier")
	if soldier_mods.has("damage_mult") or soldier_mods.has("low_hp_damage_bonus"):
		_fail("Expected Berserk signature effects not to leak to Soldier.")
		return


func _test_attribute_nodes_create_different_profiles() -> void:
	var state: Dictionary = Meta.default_state()
	state["skill_nodes"] = [
		"strength_flow_1", "strength_flow_2", "strength_notable",
		"intelligence_flow_1", "intelligence_flow_2", "intelligence_notable",
		"leadership_flow_1", "leadership_flow_2", "leadership_notable",
	]
	var mods := Meta.skill_modifiers(state)
	for required in ["strength_flat", "intelligence_flat", "leadership_flat"]:
		if float(mods.get(required, 0.0)) <= 0.0:
			_fail("Expected attribute modifier '%s' from purchased petals." % required)
			return

	var holder := Node2D.new()
	root.add_child(holder)
	current_scene = holder
	await process_frame

	var berserk := PLAYER_SCENE.instantiate()
	holder.add_child(berserk)
	berserk.configure_character("berserk", "sword")
	var berserk_before: Dictionary = (berserk.get("derived_parameters") as Dictionary).duplicate(true)
	berserk.apply_meta_skill_modifiers(mods)
	await process_frame
	var berserk_after: Dictionary = berserk.get("derived_parameters")

	var engineer := PLAYER_SCENE.instantiate()
	holder.add_child(engineer)
	engineer.configure_character("engineer", "engineer_sentry_wrench")
	var engineer_before: Dictionary = (engineer.get("derived_parameters") as Dictionary).duplicate(true)
	engineer.apply_meta_skill_modifiers(mods)
	await process_frame
	var engineer_after: Dictionary = engineer.get("derived_parameters")

	var berserk_damage_gain := float(berserk_after.get("damage", 0.0)) - float(berserk_before.get("damage", 0.0))
	var berserk_summon_gain := float(berserk_after.get("summon_amount", 0.0)) - float(berserk_before.get("summon_amount", 0.0))
	var engineer_damage_gain := float(engineer_after.get("damage", 0.0)) - float(engineer_before.get("damage", 0.0))
	var engineer_summon_gain := float(engineer_after.get("summon_amount", 0.0)) - float(engineer_before.get("summon_amount", 0.0))

	if berserk_damage_gain <= 0.0 or engineer_summon_gain <= 0.0:
		_fail("Expected attribute petals to change derived combat parameters.")
		return
	if is_equal_approx(berserk_damage_gain, engineer_damage_gain) and is_equal_approx(berserk_summon_gain, engineer_summon_gain):
		_fail("Expected same attribute petals to produce different per-hero derived profiles.")
		return
	holder.queue_free()
	current_scene = null
	await process_frame
