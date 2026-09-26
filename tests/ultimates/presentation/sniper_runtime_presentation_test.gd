extends SceneTree

const Runtime := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_runtime.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "sniper"
const RELEASE_SECONDS := {
	"sniper_deadeye_rifle": 0.75,
	"sniper_spotter_scope": 0.85,
	"sniper_shatter_rounds": 0.65,
}


class Host extends Node2D:
	func ultimate_host_effect_parent() -> Node:
		return self

	func ultimate_host_position() -> Vector2:
		return global_position


var _errors: Array[String] = []


func _initialize() -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	current_scene = holder
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	for weapon_id in RELEASE_SECONDS:
		await _test_live_runtime(holder, registry, str(weapon_id))
	holder.queue_free()
	await process_frame
	_report()


func _test_live_runtime(holder: Node2D, registry: Registry, weapon_id: String) -> void:
	var host := Host.new()
	holder.add_child(host)
	var camera := Camera2D.new()
	# A camera can be displaced from the hero at an arena edge. Keep the host at
	# the origin and move the camera far enough to catch a player-centred veil.
	camera.position = Vector2(2000.0, 1000.0)
	camera.zoom = Vector2(1.12, 1.12)
	host.add_child(camera)
	await process_frame
	camera.make_current()
	await process_frame
	var runtime := Runtime.new(0)
	var profile := registry.catalog_profile_for(CLASS_ID, weapon_id)
	_check(runtime.begin(host, registry, profile), "%s runtime must instantiate its authored scene" % weapon_id)
	var scene := _mounted_presentation_scene(host)
	_check(scene != null and scene.has_method("visible_phase_name"), "%s must mount its phase scene" % weapon_id)
	if scene != null and scene.has_method("visible_phase_name"):
		_check(str(scene.call("visible_phase_name")) == "windup", "%s must show windup at runtime start" % weapon_id)
		runtime.advance(float(RELEASE_SECONDS[weapon_id]) + 0.01)
		_check(str(scene.call("visible_phase_name")) == "release", "%s must advance its visible scene to release" % weapon_id)
		_check(scene.has_method("presence_state_for_tests"), "%s must expose its applied presentation weight" % weapon_id)
		if scene.has_method("presence_state_for_tests"):
			var state := scene.call("presence_state_for_tests") as Dictionary
			_check(bool(state.get("backdrop_visible", false)), "%s must apply its backdrop in the live runtime" % weapon_id)
			_check(bool(state.get("camera_shake_triggered", false)), "%s must apply camera shake on first impact" % weapon_id)
			_check(float(state.get("hitstop_ms", 0.0)) >= 80.0, "%s must apply first-impact hitstop" % weapon_id)
			_check(bool(state.get("sfx_ducked", false)), "%s must duck SFX on first impact" % weapon_id)
			_check(not str(state.get("cast_pose_id", "")).is_empty() and bool(state.get("cast_pose_bound", false)) and bool(state.get("silhouette_bound", false)),
				"%s must render its declared Sniper cast pose and weapon silhouette" % weapon_id)
			_check(str(state.get("cast_pose_asset", "")) != str(state.get("silhouette_asset", "")),
				"%s must bind hero art separately from its weapon silhouette" % weapon_id)
		_check_backdrop_covers_camera_edge(scene as Node2D, camera, weapon_id)
	runtime.finish("cancel")
	host.queue_free()
	await process_frame


func _mounted_presentation_scene(host: Host) -> Node:
	for child in host.get_children():
		if child.has_method("visible_phase_name"):
			return child
	return null


func _check_backdrop_covers_camera_edge(scene: Node2D, camera: Camera2D, weapon_id: String) -> void:
	var backdrop := scene.get_node_or_null("BackdropTreatment") as Sprite2D
	_check(backdrop != null, "%s must create a texture-backed backdrop treatment" % weapon_id)
	_check(not _has_polygon(scene), "%s must not construct a Polygon2D backdrop" % weapon_id)
	if backdrop == null or backdrop.texture == null:
		return
	var visible_rect := scene.get_viewport().get_visible_rect()
	var half_visible := visible_rect.size / camera.zoom * 0.5
	var center := camera.get_screen_center_position()
	var minimum := backdrop.global_position
	var maximum := backdrop.global_position + backdrop.texture.get_size() * backdrop.global_scale
	_check(minimum.x <= center.x - half_visible.x and maximum.x >= center.x + half_visible.x
		and minimum.y <= center.y - half_visible.y and maximum.y >= center.y + half_visible.y,
		"%s backdrop must cover the displaced camera viewport at arena edges" % weapon_id)


func _has_polygon(node: Node) -> bool:
	if node is Polygon2D:
		return true
	for child in node.get_children():
		if _has_polygon(child):
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("sniper_runtime_presentation_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("sniper_runtime_presentation_test: %s" % error)
	quit(1)
