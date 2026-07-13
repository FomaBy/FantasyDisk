extends SceneTree

const SCENE_CONTRACTS := preload("res://scripts/scene_contracts.gd")


func _initialize() -> void:
	var errors: Array[String] = []
	var valid_scene := PackedScene.new()
	var valid_source := Node2D.new()
	valid_scene.pack(valid_source)
	valid_source.free()
	var valid := SCENE_CONTRACTS.instantiate_node_2d(valid_scene, "valid fixture", false)
	if valid == null:
		errors.append("valid Node2D root was rejected")
	else:
		valid.free()

	var wrong_scene := PackedScene.new()
	var wrong_source := Control.new()
	wrong_scene.pack(wrong_source)
	wrong_source.free()
	var wrong := SCENE_CONTRACTS.instantiate_node_2d(wrong_scene, "wrong fixture", false)
	if wrong != null:
		errors.append("Control root must be rejected by a Node2D scene contract")
		wrong.free()

	if not errors.is_empty():
		for error in errors:
			push_error("Scene contract: %s" % error)
		quit(1)
		return
	print("Scene contract instantiation test passed.")
	quit(0)
