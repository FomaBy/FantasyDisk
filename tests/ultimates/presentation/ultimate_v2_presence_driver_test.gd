extends SceneTree

const Driver := preload("res://scripts/ultimates/presentation/ultimate_v2_presence_driver.gd")
const STEP := 1.0 / 60.0

var _original_time_scale := 1.0
var _screen_shake_meta: Variant = null
var _combat_feedback_meta: Variant = null
var _had_screen_shake := false
var _had_combat_feedback := false


func _initialize() -> void:
	_original_time_scale = Engine.time_scale
	_had_screen_shake = root.has_meta("screen_shake")
	_had_combat_feedback = root.has_meta("combat_feedback")
	_screen_shake_meta = root.get_meta("screen_shake") if _had_screen_shake else null
	_combat_feedback_meta = root.get_meta("combat_feedback") if _had_combat_feedback else null
	call_deferred("_run")


func _run() -> void:
	var errors: Array[String] = []
	_check_accessibility_modes(errors)
	_check_pause_and_hitstop(errors)
	_check_camera_state_ownership(errors)
	_check_audio_overlap_and_external_change(errors)
	_check_time_scale_and_tree_ownership(errors)
	_check_viewport_fit(errors)
	_restore_globals()
	if errors.is_empty():
		print("Ultimate v2 presence driver passed accessibility, fit, pause, overlap, cancellation and state-ownership checks.")
		quit(0)
		return
	for error in errors:
		push_error(error)
	quit(1)


func _make_host() -> Dictionary:
	var host := Node2D.new()
	var backdrop := Polygon2D.new()
	backdrop.name = "BackdropVeil"
	backdrop.color = Color(0.08, 0.06, 0.12, 0.7)
	host.add_child(backdrop)
	var timeline := AnimationPlayer.new()
	timeline.name = "Timeline"
	var animation := Animation.new()
	animation.length = 4.0
	var library := AnimationLibrary.new()
	library.add_animation(&"ultimate", animation)
	timeline.add_animation_library(&"", library)
	host.add_child(timeline)
	var driver := Driver.new()
	driver.name = "PresenceDriver"
	driver.release_at = 0.10
	driver.impact_at = 0.20
	driver.recovery_at = 0.70
	driver.cancel_at = 1.0
	driver.hitstop_ms = 100.0
	driver.shake_seconds = 0.35
	driver.shake_amplitude = 6.0
	driver.sfx_duck_db = -8.0
	host.add_child(driver)
	root.add_child(host)
	timeline.play(&"ultimate")
	driver.set_process(false)
	return {"host": host, "backdrop": backdrop, "timeline": timeline, "driver": driver}


func _release_host(bundle: Dictionary) -> void:
	var host := bundle["host"] as Node
	if host != null and is_instance_valid(host):
		host.free()


func _check_accessibility_modes(errors: Array[String]) -> void:
	for mode in [
		{"shake": true, "feedback": true, "alpha": 1.0},
		{"shake": false, "feedback": true, "alpha": Driver.REDUCED_MOTION_ALPHA},
		{"shake": false, "feedback": false, "alpha": Driver.PHOTOSENSITIVITY_SAFE_ALPHA},
	]:
		root.set_meta("screen_shake", mode["shake"])
		root.set_meta("combat_feedback", mode["feedback"])
		var bundle := _make_host()
		var backdrop := bundle["backdrop"] as Polygon2D
		_expect(is_equal_approx(backdrop.self_modulate.a, float(mode["alpha"])), "accessibility mode must apply the declared steady veil alpha", errors)
		(bundle["driver"] as Node).call("finish", "cancel")
		_expect(is_equal_approx(backdrop.self_modulate.a, 1.0), "cancellation must restore the veil modulation", errors)
		_release_host(bundle)


func _check_pause_and_hitstop(errors: Array[String]) -> void:
	root.set_meta("screen_shake", true)
	root.set_meta("combat_feedback", true)
	var bundle := _make_host()
	var driver := bundle["driver"] as Node
	var timeline := bundle["timeline"] as AnimationPlayer
	driver.call("_process", 0.21)
	_expect(not timeline.is_playing(), "impact hitstop must pause the owned timeline", errors)
	driver.call("set_paused", true)
	driver.call("_process", 0.30)
	_expect(not timeline.is_playing(), "manual pause must hold an in-flight hitstop", errors)
	driver.call("set_paused", false)
	driver.call("_process", 0.11)
	_expect(timeline.is_playing(), "timeline must resume after every owned pause reason clears", errors)
	driver.call("set_paused", true)
	timeline.seek(0.5, true)
	driver.call("set_paused", false)
	_expect(not timeline.is_playing(), "a concurrent timeline seek must prevent blind resume", errors)
	_release_host(bundle)


func _check_camera_state_ownership(errors: Array[String]) -> void:
	root.set_meta("screen_shake", true)
	root.set_meta("combat_feedback", true)
	var camera := Camera2D.new()
	root.add_child(camera)
	camera.enabled = true
	camera.make_current()
	camera.offset = Vector2(11.0, -7.0)
	var bundle := _make_host()
	var driver := bundle["driver"] as Node
	driver.call("_process", 0.21)
	driver.call("_process", STEP)
	var shaken := camera.offset
	_expect(not shaken.is_equal_approx(Vector2(11.0, -7.0)), "normal mode must apply an impact shake", errors)
	var external_delta := Vector2(4.0, -2.0)
	camera.offset += external_delta
	driver.call("_process", STEP)
	driver.call("finish", "cancel")
	_expect(camera.offset.is_equal_approx(Vector2(11.0, -7.0) + external_delta), "finish must subtract only its own camera delta", errors)
	_release_host(bundle)
	camera.free()


func _check_audio_overlap_and_external_change(errors: Array[String]) -> void:
	var created := AudioServer.get_bus_index("SFX") == -1
	if created:
		AudioServer.add_bus(AudioServer.bus_count)
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
	var bus := AudioServer.get_bus_index("SFX")
	var before := AudioServer.get_bus_volume_db(bus)
	AudioServer.set_bus_volume_db(bus, -3.0)
	var first := _make_host()
	var second := _make_host()
	(first["driver"] as Node).call("_process", 0.11)
	(second["driver"] as Node).call("_process", 0.11)
	_expect(is_equal_approx(AudioServer.get_bus_volume_db(bus), -11.0), "overlapping activations must duck SFX once", errors)
	(first["driver"] as Node).call("finish", "cancel")
	_expect(is_equal_approx(AudioServer.get_bus_volume_db(bus), -11.0), "first overlap teardown must retain the shared duck", errors)
	AudioServer.set_bus_volume_db(bus, -5.5)
	(second["driver"] as Node).call("finish", "cancel")
	_expect(is_equal_approx(AudioServer.get_bus_volume_db(bus), -5.5), "external audio change must survive final teardown", errors)
	_release_host(first)
	_release_host(second)
	var exact := _make_host()
	(exact["driver"] as Node).call("_process", 0.11)
	(exact["driver"] as Node).call("finish", "cancel")
	_expect(is_equal_approx(AudioServer.get_bus_volume_db(bus), -5.5), "an unchanged owned duck must restore its exact prior volume", errors)
	_release_host(exact)
	AudioServer.set_bus_volume_db(bus, before)
	if created:
		AudioServer.remove_bus(bus)


func _check_time_scale_and_tree_ownership(errors: Array[String]) -> void:
	Engine.time_scale = 0.35
	var paused_before := paused
	var bundle := _make_host()
	var driver := bundle["driver"] as Node
	driver.call("_process", 0.035)
	_expect(is_equal_approx(Engine.time_scale, 0.35), "driver must not overwrite a non-default Engine.time_scale", errors)
	Engine.time_scale = 0.6
	driver.call("finish", "cancel")
	_expect(is_equal_approx(Engine.time_scale, 0.6), "concurrent Engine.time_scale changes must survive teardown", errors)
	_expect(paused == paused_before, "driver must never own SceneTree.paused", errors)
	_release_host(bundle)
	Engine.time_scale = _original_time_scale


func _check_viewport_fit(errors: Array[String]) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 180)
	root.add_child(viewport)
	var host := Node2D.new()
	var backdrop := Polygon2D.new()
	backdrop.name = "BackdropVeil"
	host.add_child(backdrop)
	var timeline := AnimationPlayer.new()
	timeline.name = "Timeline"
	host.add_child(timeline)
	var driver := Driver.new()
	host.add_child(driver)
	viewport.add_child(host)
	driver.set_process(false)
	driver.call("_process", STEP)
	var first_bounds := _bounds(backdrop.polygon)
	_expect(first_bounds.size.x >= 320.0 and first_bounds.size.y >= 180.0, "backdrop must cover the first viewport", errors)
	viewport.size = Vector2i(640, 360)
	driver.call("_process", STEP)
	var second_bounds := _bounds(backdrop.polygon)
	_expect(second_bounds.size.x >= 640.0 and second_bounds.size.y >= 360.0, "backdrop must refit after viewport resize", errors)
	viewport.free()


func _bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds


func _expect(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)


func _restore_globals() -> void:
	Engine.time_scale = _original_time_scale
	if _had_screen_shake:
		root.set_meta("screen_shake", _screen_shake_meta)
	else:
		root.remove_meta("screen_shake")
	if _had_combat_feedback:
		root.set_meta("combat_feedback", _combat_feedback_meta)
	else:
		root.remove_meta("combat_feedback")
