extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const Meta := preload("res://scripts/meta_progression.gd")
const Formatter := preload("res://scripts/constellation_description_formatter.gd")
const FAILURE_CONDITION := "Покупка отключена: требуется корректный schema-6 dossier."

var errors := PackedStringArray()
var originals := {}


func _initialize() -> void:
	_malform_node("berserk_sword_b1")
	_malform_node("berserk_sword_b2")
	await _check_available_and_locked()
	_restore_nodes()
	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("SCRUM-1094 Atlas malformed-dossier failure precedence passed for available and locked nodes.")
	quit(0)


func _malform_node(node_id: String) -> void:
	var node := Meta.node_by_id(node_id)
	if node.is_empty():
		errors.append("missing fixture node %s" % node_id)
		return
	originals[node_id] = node.duplicate(true)
	node["dossier_valid"] = false
	node["dossier"] = {}


func _restore_nodes() -> void:
	for raw_id in originals.keys():
		var node_id := str(raw_id)
		var live := Meta.node_by_id(node_id)
		var original: Dictionary = originals[node_id]
		live.clear()
		live.merge(original, true)


func _check_available_and_locked() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await _settle()
	var state := Meta.default_state()
	state["meta_point_awards"] = {"berserk": [0, 1, 2, 3, 4, 5]}
	state["skill_nodes"] = []
	main.set("meta_state", state)
	main.set("selected_character_id", "berserk")
	if Meta.node_status(state, "berserk_sword_b1") != "available":
		errors.append("fixture b1 must be available")
	if Meta.node_status(state, "berserk_sword_b2") != "locked":
		errors.append("fixture b2 must be locked")
	main.ui._show_atlas_screen()
	await _settle()
	await _select_and_assert(main, "berserk_sword_b1", "available malformed")
	await _select_and_assert(main, "berserk_sword_b2", "locked malformed")
	main.queue_free()
	viewport.queue_free()
	await process_frame


func _select_and_assert(main: Node, node_id: String, context: String) -> void:
	var node_button := main.find_child("AtlasNode_%s" % node_id, true, false) as TextureButton
	if node_button == null:
		errors.append("%s: node button missing" % context)
		return
	node_button.pressed.emit()
	await _settle()
	var desc := main.find_child("AtlasNodeDesc", true, false) as Label
	var condition := main.find_child("AtlasNodeCondition", true, false) as Label
	var buy := main.find_child("AtlasBuyButton", true, false) as Button
	if desc == null or condition == null or buy == null:
		errors.append("%s: dossier controls incomplete" % context)
		return
	if desc.text != Formatter.FAILURE_TEXT:
		errors.append("%s: safe description failure was replaced: %s" % [context, desc.text])
	if not condition.is_visible_in_tree() or condition.text != FAILURE_CONDITION:
		errors.append("%s: explicit failure condition was replaced: %s" % [context, condition.text])
	for generic in ["Не хватает", "Нужна соседняя", "Звезда зажжена"]:
		if condition.text.contains(generic):
			errors.append("%s: generic fallback leaked over failure: %s" % [context, generic])
	if not buy.visible or not buy.disabled:
		errors.append("%s: Buy must remain visible and disabled" % context)


func _settle() -> void:
	for _index in range(8):
		await process_frame
