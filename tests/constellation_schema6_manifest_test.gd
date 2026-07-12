extends SceneTree

const Schema6 := preload("res://scripts/constellation_schema6_data.gd")

var errors := PackedStringArray()


func _initialize() -> void:
	var manifest := Schema6.manifest()
	_check(int(manifest.get("runtime_schema_version", 0)) == 6, "runtime schema must be 6")
	_check((manifest.get("classes", []) as Array).size() == 17, "expected 17 classes")
	_check(Schema6.classes_by_id().size() == 17, "class index must contain 17 classes")
	_check(Schema6.all_nodes_by_id().size() == 357, "node index must contain 357 class nodes")
	_check(Schema6.all_mechanics_by_id().size() == 51, "mechanic index must contain 51 finals")
	_check(Schema6.node("berserk_sword_final").get("weapon_id") == "sword", "canonical final lookup failed")
	_check(Schema6.mechanic("sword_repeat_execute").get("node_id") == "berserk_sword_final", "mechanic lookup failed")
	_check(Schema6.node("berserk_h0").get("purchase_required_for_effect") is bool, "hidden lookup failed")
	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("SCRUM-1068 production manifest loader passed 17/357/51 indexed parity.")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
