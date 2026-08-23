extends SceneTree

## FAN-2528: the Dark Mage's V2 presence must be mounted by the live runtime,
## not only declared in its reference manifest.

const Runtime := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_runtime.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const PD := preload("res://scripts/progression_data.gd")

const RELEASE_SECONDS := {
	"dark_book": 0.7,
	"cursed_skull": 0.85,
	"dark_wand": 0.95,
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
	camera.position = Vector2(1600.0, 900.0)
	camera.zoom = Vector2(1.1, 1.1)
	host.add_child(camera)
	await process_frame
	camera.make_current()
	await process_frame
	var runtime := Runtime.new(0)
	var profile := registry.catalog_profile_for("dark_mage", weapon_id)
	_check(runtime.begin(host, registry, profile), "%s runtime must mount its authored V2 scene" % weapon_id)
	var scene := _mounted_scene(host)
	_check(scene != null and scene.has_method("presence_state_for_tests"),
		"%s must expose live V2 presence state" % weapon_id)
	if scene != null and scene.has_method("presence_state_for_tests"):
		runtime.advance(float(RELEASE_SECONDS[weapon_id]) + 0.01)
		var state := scene.call("presence_state_for_tests") as Dictionary
		_check(bool(state.get("backdrop_visible", false)), "%s must render its backdrop" % weapon_id)
		_check(bool(state.get("camera_shake_triggered", false)), "%s must apply camera shake at release" % weapon_id)
		var hitstop := float(state.get("hitstop_ms", 0.0))
		_check(hitstop >= 80.0 and hitstop <= 150.0, "%s must apply 80-150ms first-impact hitstop" % weapon_id)
		_check(bool(state.get("sfx_ducked", false)), "%s must duck SFX at release" % weapon_id)
		_check(bool(state.get("cast_pose_bound", false)) and bool(state.get("silhouette_bound", false)),
			"%s must render its Dark Mage cast pose and unique weapon silhouette" % weapon_id)
		_check(str(state.get("cast_pose_asset", "")) != str(state.get("silhouette_asset", "")),
			"%s pose and weapon assets must remain distinct" % weapon_id)
		_check_backdrop_covers_camera_edge(scene as Node2D, camera, weapon_id)
	runtime.finish("cancel")
	await process_frame
	if scene != null and is_instance_valid(scene):
		_check(scene.get_node_or_null("BackdropTreatment") == null,
			"%s must remove the backdrop after cleanup" % weapon_id)
	host.queue_free()
	await process_frame


func _mounted_scene(host: Host) -> Node:
	for child in host.get_children():
		if child.has_method("presence_state_for_tests"):
			return child
	return null


func _check_backdrop_covers_camera_edge(scene: Node2D, camera: Camera2D, weapon_id: String) -> void:
	var backdrop := scene.get_node_or_null("BackdropTreatment") as Sprite2D
	_check(backdrop != null and backdrop.texture != null and backdrop.top_level,
		"%s must create a top-level texture-backed backdrop" % weapon_id)
	if backdrop == null or backdrop.texture == null:
		return
	var visible_rect := scene.get_viewport().get_visible_rect()
	var half_visible := visible_rect.size / camera.zoom * 0.5
	var center := camera.get_screen_center_position()
	var minimum := backdrop.global_position
	var maximum := backdrop.global_position + backdrop.texture.get_size() * backdrop.global_scale
	_check(minimum.x <= center.x - half_visible.x and maximum.x >= center.x + half_visible.x
		and minimum.y <= center.y - half_visible.y and maximum.y >= center.y + half_visible.y,
		"%s backdrop must cover the arena-edge camera viewport" % weapon_id)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("dark_mage_runtime_presentation_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("dark_mage_runtime_presentation_test: %s" % error)
	quit(1)
