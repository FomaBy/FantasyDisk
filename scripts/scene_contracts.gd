class_name SceneContracts
extends RefCounted


# Configurable PackedScenes are content boundaries: validate the root before any
# add_child/set_meta access so a scene refactor fails locally instead of crashing.
static func instantiate_node_2d(scene: PackedScene, context: String, report_error := true) -> Node2D:
	if scene == null:
		if report_error:
			push_error("%s: PackedScene is null." % context)
		return null
	var instance := scene.instantiate()
	var node := instance as Node2D
	if node != null:
		return node
	if report_error:
		push_error("%s: scene root must inherit Node2D (%s)." % [context, scene.resource_path])
	if instance != null and is_instance_valid(instance):
		instance.free()
	return null
