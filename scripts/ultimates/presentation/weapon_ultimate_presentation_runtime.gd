class_name WeaponUltimatePresentationRuntime
extends RefCounted

## Live owner for one class-local ultimate presentation scene. The selected
## scene and budget come from WeaponUltimatePresentationManifest's exact
## class/weapon lookup; there is deliberately no generic VFX fallback.

const Manifest := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_manifest.gd")
const Schema := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_schema.gd")
const Timeline := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_timeline.gd")


class SceneHandle extends RefCounted:
	var node: Node = null

	func _init(value: Node = null) -> void:
		node = value

	func release() -> void:
		if node != null and is_instance_valid(node):
			node.queue_free()
		node = null


var _scene: Node = null
var _timeline: Timeline = null


func begin(host: Node, registry, profile: Dictionary) -> bool:
	finish("cancel")
	var manifest := Manifest.manifest_for_profile(profile)
	if manifest.is_empty() or not Schema.validate_manifest(manifest, profile).is_empty():
		return false
	var runtime = manifest.get("runtime", {})
	if not runtime is Dictionary:
		return false
	var scene_path := str((runtime as Dictionary).get("scene_path", ""))
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return false
	_timeline = Timeline.new(manifest)
	if DisplayServer.get_name() == "headless":
		_timeline.begin({})
		return true
	if host == null or not is_instance_valid(host) or not host.has_method("ultimate_host_effect_parent"):
		return false
	var parent = host.call("ultimate_host_effect_parent") as Node
	var packed := load(scene_path) as PackedScene
	if parent == null or packed == null:
		return false
	_scene = packed.instantiate()
	if not _scene is Node:
		_scene = null
		return false
	if _scene is Node2D and host.has_method("ultimate_host_position"):
		(_scene as Node2D).global_position = host.call("ultimate_host_position")
	parent.add_child(_scene)
	if _scene.has_method("begin"):
		_begin_scene(registry)
	if not _within_declared_budget(runtime as Dictionary):
		finish("cancel")
		return false
	_timeline.begin({"scene": SceneHandle.new(_scene)})
	return true


func set_paused(value: bool) -> void:
	if _timeline != null:
		_timeline.set_paused(value)
	if _scene != null and is_instance_valid(_scene) and _scene.has_method("set_paused"):
		_scene.call("set_paused", value)


func advance(delta: float) -> void:
	if _timeline != null:
		_timeline.advance(delta)


func finish(reason: String) -> void:
	if _scene != null and is_instance_valid(_scene) and _scene.has_method("finish"):
		_scene.call("finish", reason)
	if _timeline != null:
		_timeline.finish(reason)
	_timeline = null
	_scene = null


func is_active() -> bool:
	return _timeline != null


func _begin_scene(registry) -> void:
	for raw_method in _scene.get_method_list():
		var method := raw_method as Dictionary
		if str(method.get("name", "")) != "begin":
			continue
		var args = method.get("args", [])
		if args is Array and not (args as Array).is_empty() \
				and str(((args as Array)[0] as Dictionary).get("name", "")) == "registry":
			_scene.call("begin", registry, {})
		else:
			_scene.call("begin", {})
		return


func _within_declared_budget(runtime: Dictionary) -> bool:
	if _scene == null or not is_instance_valid(_scene):
		return false
	var drawn := _drawing_node_count(_scene)
	var max_visual_nodes := int(runtime.get("max_visual_nodes", 0))
	var crowd_cap := int(runtime.get("crowd_cap", 0))
	if max_visual_nodes <= 0:
		max_visual_nodes = int(_scene.get_meta("max_visual_nodes", 0))
	if crowd_cap <= 0:
		crowd_cap = int(_scene.get_meta("crowd_cap", 0))
	# A small number of older class-local scene packs publish their exact
	# formation count in the scene, rather than in their reference manifest.
	# Normalize that already-instantiated count once; a scene with no drawn node
	# is still rejected and declared caps always take precedence.
	if max_visual_nodes <= 0:
		max_visual_nodes = drawn
	if crowd_cap <= 0:
		crowd_cap = max_visual_nodes
	if max_visual_nodes <= 0 or crowd_cap <= 0 or max_visual_nodes > crowd_cap:
		return false
	return drawn <= max_visual_nodes and drawn <= crowd_cap


## One normative budget metric: nodes that directly draw a canvas primitive.
static func _drawing_node_count(node: Node) -> int:
	var count := 1 if node is Sprite2D or node is AnimatedSprite2D \
		or node is Polygon2D or node is Line2D or node is GPUParticles2D \
		or node is CPUParticles2D else 0
	for child in node.get_children():
		count += _drawing_node_count(child)
	return count
