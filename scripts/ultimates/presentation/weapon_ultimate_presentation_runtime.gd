class_name WeaponUltimatePresentationRuntime
extends RefCounted

## Live owner for one class-local ultimate presentation scene. The selected
## scene and budget come from WeaponUltimatePresentationManifest's exact
## class/weapon lookup; there is deliberately no generic VFX fallback.

const Manifest := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_manifest.gd")
const Schema := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_schema.gd")
const Timeline := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_timeline.gd")
const DirectionContract := preload("res://scripts/ultimates/presentation/ultimate_visual_direction_contract.gd")


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
var _headless_mode := -1
var _last_budget_diagnostic := ""


func _init(headless_mode := -1) -> void:
	_headless_mode = headless_mode


func begin(host: Node, registry, profile: Dictionary) -> bool:
	finish("cancel")
	_last_budget_diagnostic = ""
	var manifest := Manifest.manifest_for_profile(profile)
	if manifest.is_empty() or not Schema.validate_manifest(manifest, profile).is_empty():
		return false
	var runtime = manifest.get("runtime", {})
	if not runtime is Dictionary:
		return false
	var scene_path := str((runtime as Dictionary).get("scene_path", ""))
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return false
	if _uses_headless_fallback():
		_timeline = Timeline.new(manifest, _headless_mode)
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
	_timeline = Timeline.new(manifest, _headless_mode)
	if _scene is Node2D and host.has_method("ultimate_host_position"):
		(_scene as Node2D).global_position = host.call("ultimate_host_position")
	parent.add_child(_scene)
	_timeline.begin({"scene": SceneHandle.new(_scene)})
	if _scene.has_method("begin"):
		_begin_scene(registry)
	if not _within_declared_budget(runtime as Dictionary):
		finish("cancel")
		return false
	return true


func set_paused(value: bool) -> void:
	if _timeline != null:
		_timeline.set_paused(value)
	if _scene != null and is_instance_valid(_scene) and _scene.has_method("set_paused"):
		_scene.call("set_paused", value)


func advance(delta: float) -> void:
	if _timeline != null:
		_timeline.advance(delta)
	if _scene != null and is_instance_valid(_scene) and _scene.has_method("advance"):
		_scene.call("advance", delta)


## Delivers one executor beat (`event_id` plus its payload) to the live
## authored presentation. The timeline records the beat; a scene that opts into
## beat-driven visuals may expose `present(event_id, payload)`. Returning true
## means the beat was accepted by a live presentation and the controller must
## not draw anything over it.
func present_beat(event_id: String, payload: Dictionary) -> bool:
	if _timeline == null:
		return false
	_timeline.record_beat(event_id, payload)
	if _scene != null and is_instance_valid(_scene) and _scene.has_method("present"):
		_scene.call("present", event_id, payload)
	return true


## Beats recorded by the current (or just finished) timeline, in arrival order.
func recorded_beats() -> Array[Dictionary]:
	return _timeline.recorded_beats() if _timeline != null else []


func finish(reason: String) -> void:
	if _scene != null and is_instance_valid(_scene) and _scene.has_method("finish"):
		_scene.call("finish", reason)
	if _timeline != null:
		_timeline.finish(reason)
	_timeline = null
	_scene = null


func is_active() -> bool:
	return _timeline != null


## Last fail-closed visual-budget decision, suitable for activation diagnostics.
func last_budget_diagnostic() -> String:
	return _last_budget_diagnostic


func _uses_headless_fallback() -> bool:
	return DisplayServer.get_name() == "headless" if _headless_mode < 0 else _headless_mode == 1


func _begin_scene(registry) -> void:
	for raw_method in _scene.get_method_list():
		var method := raw_method as Dictionary
		if str(method.get("name", "")) != "begin":
			continue
		var args = method.get("args", [])
		if args is Array and not (args as Array).is_empty() \
				and str(((args as Array)[0] as Dictionary).get("name", "")) == "registry":
			if (args as Array).size() >= 3:
				_scene.call("begin", registry, {}, _headless_mode)
			else:
				_scene.call("begin", registry, {})
		else:
			if args is Array and (args as Array).size() >= 2:
				_scene.call("begin", {}, _headless_mode)
			else:
				_scene.call("begin", {})
		return


func _within_declared_budget(runtime: Dictionary) -> bool:
	if _scene == null or not is_instance_valid(_scene):
		return _reject_budget("scene is unavailable")
	var drawn := _drawing_node_count(_scene)
	var max_result := _resolve_declared_cap(runtime, "max_visual_nodes")
	if str(max_result.get("state", "")) != "valid":
		return _reject_budget(_cap_diagnostic("max_visual_nodes", max_result))
	var crowd_result := _resolve_declared_cap(runtime, "crowd_cap")
	if str(crowd_result.get("state", "")) != "valid":
		return _reject_budget(_cap_diagnostic("crowd_cap", crowd_result))
	var max_visual_nodes := int(max_result.get("value", 0))
	var crowd_cap := int(crowd_result.get("value", 0))
	if max_visual_nodes > crowd_cap:
		return _reject_budget("invalid cap relation: max_visual_nodes=%d exceeds crowd_cap=%d" % [max_visual_nodes, crowd_cap])
	if drawn > max_visual_nodes:
		return _reject_budget("drawn visual nodes %d exceed max_visual_nodes cap %d" % [drawn, max_visual_nodes])
	if drawn > crowd_cap:
		return _reject_budget("drawn visual nodes %d exceed crowd_cap %d" % [drawn, crowd_cap])
	var material_budget := {
		"max_unique_materials": runtime.get("max_unique_materials", null),
		"max_fullscreen_materials": runtime.get("max_fullscreen_materials", null),
	}
	var material_errors := DirectionContract.scene_material_violations(_scene, str(_scene.get_meta("ultimate_id", "")), material_budget)
	if not material_errors.is_empty():
		return _reject_budget("material budget rejected: %s" % "; ".join(material_errors))
	_last_budget_diagnostic = ""
	return true


func _resolve_declared_cap(runtime: Dictionary, key: String) -> Dictionary:
	var value: Variant = runtime.get(key, null)
	var source := "runtime"
	if not runtime.has(key) or value == null:
		if _scene.has_meta(key):
			value = _scene.get_meta(key)
			source = "scene_meta"
		else:
			return {"state": "missing", "value": value, "source": source}
	if not _is_valid_cap(value):
		return {"state": "invalid", "value": value, "source": source}
	return {"state": "valid", "value": int(value), "source": source}


func _is_valid_cap(value: Variant) -> bool:
	if not (value is int or value is float) or value is bool:
		return false
	var numeric := float(value)
	return is_finite(numeric) and numeric > 0.0 and is_equal_approx(numeric, floorf(numeric))


func _cap_diagnostic(key: String, result: Dictionary) -> String:
	return "%s cap is %s (source=%s, value=%s)" % [
		key,
		str(result.get("state", "invalid")),
		str(result.get("source", "unknown")),
		str(result.get("value", null)),
	]


func _reject_budget(reason: String) -> bool:
	_last_budget_diagnostic = "visual-node budget rejected: %s" % reason
	print("WeaponUltimatePresentationRuntime: %s" % _last_budget_diagnostic)
	return false


## One normative budget metric: nodes that directly draw a canvas primitive.
static func _drawing_node_count(node: Node) -> int:
	var count := 1 if node is Sprite2D or node is AnimatedSprite2D \
		or node is Polygon2D or node is Line2D or node is GPUParticles2D \
		or node is CPUParticles2D else 0
	for child in node.get_children():
		count += _drawing_node_count(child)
	return count
