extends SceneTree

# Independent QA evidence for SCRUM-1091. This deliberately does not reuse the
# implementation test helpers: it audits the authoritative runtime projection,
# injects malformed contracts, and verifies the live Atlas fails closed.

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const META := preload("res://scripts/meta_progression.gd")
const FORMATTER := preload("res://scripts/constellation_description_formatter.gd")
const QA_CAPTURE_TEARDOWN := preload("res://tools/qa_capture_teardown.gd")

var errors := PackedStringArray()
var teardown := QA_CAPTURE_TEARDOWN.new()


func _initialize() -> void:
	if not _isolated_user_dir():
		quit(2)
		return
	_audit_runtime_projection()
	_audit_adversarial_contracts()
	await _audit_live_ui_failure()
	await teardown.release_windowed_audio(self)
	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("SCRUM-1091 independent QA passed source identities, fail-closed adversarial contracts, and live Buy blocking.")
	quit(0)


func _audit_runtime_projection() -> void:
	var class_nodes := []
	var final_ids := {}
	var final_texts := {}
	var source_identities := {}
	var localized_identities := {}
	for raw_node in META.node_list():
		var node: Dictionary = raw_node
		if str(node.get("class_affinity", "")) == "":
			continue
		class_nodes.append(node)
		var dossier: Dictionary = node.get("dossier", {})
		var full_text := str(dossier.get("full_text", ""))
		_check(bool(node.get("dossier_valid", false)) and not dossier.is_empty(), "%s is not a valid dossier" % str(node.get("id", "")))
		_check(not _has_ascii_letter(full_text), "%s leaks raw ASCII in player copy: %s" % [str(node.get("id", "")), full_text])
		_check(not full_text.contains("профиль оружия"), "%s used generic axis fallback" % str(node.get("id", "")))
		var profile: Dictionary = node.get("effect_profile", {})
		if str(profile.get("effect_key", "")) == "weapon_prefinal_identity_mult":
			var source_identity := str((profile.get("params", {}) as Dictionary).get("identity", ""))
			var localized_identity := str(dossier.get("identity_text", ""))
			_check(FORMATTER.PREFINAL_IDENTITY_RU.get(source_identity, "") == localized_identity, "%s is not keyed by its authoritative source identity" % str(node.get("id", "")))
			source_identities[source_identity] = true
			localized_identities[localized_identity] = true
		if str(node.get("role", "")) == "weapon_final":
			var mechanic_id := str(node.get("mechanic_id", ""))
			final_ids[mechanic_id] = true
			final_texts[full_text] = true
			_check(float(node.get("gain_over_order_5_min", 0.0)) >= 1.20, "%s dropped below final strength floor" % mechanic_id)
			_check(full_text.contains("Триггер и механика:") and full_text.contains("Ограничители:") and full_text.contains("Против босса:"), "%s lacks trigger/caps/boss behavior" % mechanic_id)
	_check(class_nodes.size() == 357, "expected 357 class dossiers, got %d" % class_nodes.size())
	_check(final_ids.size() == 51 and final_texts.size() == 51, "expected 51 distinct final ids/texts, got %d/%d" % [final_ids.size(), final_texts.size()])
	_check(source_identities.size() == 51 and localized_identities.size() == 51, "expected 51 distinct source/localized identities, got %d/%d" % [source_identities.size(), localized_identities.size()])
	_check(FORMATTER.PREFINAL_IDENTITY_RU.size() == 51, "localization registry has stale or missing source identities")
	for raw_source in FORMATTER.PREFINAL_IDENTITY_RU.keys():
		_check(source_identities.has(str(raw_source)), "localization registry contains non-authoritative identity: %s" % str(raw_source))


func _audit_adversarial_contracts() -> void:
	var boon := _node("berserk_sword_b1")
	var prefinal := _node("berserk_sword_b5")
	var core := _node("berserk_core")
	var final_node := _node("berserk_sword_final")
	_check(not boon.is_empty() and not prefinal.is_empty() and not core.is_empty() and not final_node.is_empty(), "could not find adversarial source nodes")
	if boon.is_empty() or prefinal.is_empty() or core.is_empty() or final_node.is_empty():
		return

	var wrong_scope := boon.duplicate(true)
	(wrong_scope["effect_profile"] as Dictionary)["scope"] = "owning_class"
	_expect_rejected(wrong_scope, "wrong weapon scope")

	var missing_weapon := boon.duplicate(true)
	missing_weapon["weapon_id"] = ""
	_expect_rejected(missing_weapon, "missing owning weapon")

	var invalid_axis := boon.duplicate(true)
	invalid_axis["axis"] = "generic"
	_expect_rejected(invalid_axis, "unknown axis")

	var empty_params := boon.duplicate(true)
	(empty_params["effect_profile"] as Dictionary)["params"] = {}
	_expect_rejected(empty_params, "empty ordinary params")

	var wrong_core_scope := core.duplicate(true)
	(wrong_core_scope["effect_profile"] as Dictionary)["scope"] = "owning_weapon_only"
	_expect_rejected(wrong_core_scope, "wrong core scope")

	var wrong_core_effect := core.duplicate(true)
	(wrong_core_effect["effect_profile"] as Dictionary)["effect_key"] = "weapon_damage_flat"
	_expect_rejected(wrong_core_effect, "wrong core effect")

	var stale_identity := prefinal.duplicate(true)
	((stale_identity["effect_profile"] as Dictionary)["params"] as Dictionary)["identity"] = "stale source identity"
	_expect_rejected(stale_identity, "stale source identity")

	var wrong_final_scope := final_node.duplicate(true)
	(wrong_final_scope["effect_profile"] as Dictionary)["scope"] = "owning_class"
	_expect_rejected(wrong_final_scope, "wrong final scope")

	var mismatched_final := final_node.duplicate(true)
	(mismatched_final["effect_profile"] as Dictionary)["effect_key"] = "different_mechanic"
	_expect_rejected(mismatched_final, "final mechanic/effect mismatch")

	var missing_caps := final_node.duplicate(true)
	missing_caps["caps"] = {}
	_expect_rejected(missing_caps, "missing final caps")

	var negative_cap := final_node.duplicate(true)
	var negative_params: Dictionary = (negative_cap["effect_profile"] as Dictionary)["params"]
	var first_key := str(negative_params.keys()[0])
	negative_params[first_key] = -1
	negative_cap["caps"] = negative_params.duplicate(true)
	_expect_rejected(negative_cap, "negative final cap")

	var weak_final := final_node.duplicate(true)
	weak_final["gain_over_order_5_min"] = 1.199
	_expect_rejected(weak_final, "weak final floor")


func _audit_live_ui_failure() -> void:
	var target_index := -1
	var locked_index := -1
	var saved := {}
	var locked_saved := {}
	for index in range(META.SKILL_TREE.size()):
		var node_id := str((META.SKILL_TREE[index] as Dictionary).get("id", ""))
		if node_id == "berserk_sword_b1":
			target_index = index
			saved = (META.SKILL_TREE[index] as Dictionary).duplicate(true)
		elif node_id == "berserk_sword_b2":
			locked_index = index
			locked_saved = (META.SKILL_TREE[index] as Dictionary).duplicate(true)
	_check(target_index >= 0 and locked_index >= 0, "live malformed UI targets were not found")
	if target_index < 0 or locked_index < 0:
		return
	var malformed: Dictionary = saved.duplicate(true)
	malformed["dossier"] = {}
	malformed["dossier_valid"] = false
	malformed["desc"] = FORMATTER.FAILURE_TEXT
	META.SKILL_TREE[target_index] = malformed
	var locked_malformed: Dictionary = locked_saved.duplicate(true)
	locked_malformed["dossier"] = {}
	locked_malformed["dossier_valid"] = false
	locked_malformed["desc"] = FORMATTER.FAILURE_TEXT
	META.SKILL_TREE[locked_index] = locked_malformed

	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await _settle()
	var state: Dictionary = main.get("meta_state")
	state["meta_point_awards"] = {"berserk": [0, 1, 2]}
	main.set("meta_state", state)
	main.set("selected_character_id", "berserk")
	main.ui._show_atlas_screen()
	await _settle()
	var button := main.find_child("AtlasNode_berserk_sword_b1", true, false) as TextureButton
	_check(button != null, "live malformed node button is missing")
	if button != null:
		button.pressed.emit()
		await _settle()
		var buy := main.find_child("AtlasBuyButton", true, false) as Button
		var desc := main.find_child("AtlasNodeDesc", true, false) as Label
		var condition := main.find_child("AtlasNodeCondition", true, false) as Label
		_check(buy != null and buy.visible and buy.disabled, "malformed available dossier did not disable Buy")
		_check(desc != null and desc.text == FORMATTER.FAILURE_TEXT, "malformed dossier did not show exact safe failure")
		_check(condition != null and condition.is_visible_in_tree() and condition.text.contains("Покупка отключена"), "malformed dossier did not explain disabled purchase")
	var locked_button := main.find_child("AtlasNode_berserk_sword_b2", true, false) as TextureButton
	_check(locked_button != null, "live malformed locked node button is missing")
	if locked_button != null:
		locked_button.pressed.emit()
		await _settle()
		var locked_buy := main.find_child("AtlasBuyButton", true, false) as Button
		var locked_desc := main.find_child("AtlasNodeDesc", true, false) as Label
		var locked_condition := main.find_child("AtlasNodeCondition", true, false) as Label
		_check(locked_buy != null and locked_buy.visible and locked_buy.disabled, "malformed locked dossier did not disable Buy")
		_check(locked_desc != null and locked_desc.text == FORMATTER.FAILURE_TEXT, "malformed locked dossier did not show exact safe failure")
		_check(locked_condition != null and locked_condition.is_visible_in_tree() and locked_condition.text.contains("Покупка отключена"), "malformed locked dossier did not preserve explicit purchase failure")
	META.SKILL_TREE[target_index] = saved
	META.SKILL_TREE[locked_index] = locked_saved
	var teardown_errors := await teardown.release_viewport(self, viewport)
	for error in teardown_errors:
		errors.append("live malformed UI teardown: %s" % error)


func _node(node_id: String) -> Dictionary:
	for raw_node in META.node_list():
		var node: Dictionary = raw_node
		if str(node.get("id", "")) == node_id:
			return node
	return {}


func _expect_rejected(node: Dictionary, context: String) -> void:
	var decorated := FORMATTER.apply_to_node(node)
	_check(not bool(decorated.get("dossier_valid", true)), "%s did not fail closed" % context)
	_check((decorated.get("dossier", {}) as Dictionary).is_empty(), "%s created plausible dossier copy" % context)
	_check(str(decorated.get("desc", "")) == FORMATTER.FAILURE_TEXT, "%s lost explicit failure text" % context)


func _settle() -> void:
	for _frame in range(10):
		await process_frame


func _isolated_user_dir() -> bool:
	var requested := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--user-data-dir="):
			requested = argument.trim_prefix("--user-data-dir=").simplify_path()
			break
	var actual := OS.get_user_data_dir().simplify_path()
	if requested == "" or requested == "/" or not actual.begins_with(requested.rstrip("/") + "/"):
		push_error("SCRUM-1091 independent QA requires an isolated --user-data-dir root")
		return false
	return true


func _has_ascii_letter(value: String) -> bool:
	for character in value:
		if (character >= "a" and character <= "z") or (character >= "A" and character <= "Z"):
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
