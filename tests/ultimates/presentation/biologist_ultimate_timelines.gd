extends SceneTree

const PROFILE_PATH := "res://data/ultimates/schema/v1/classes/biologist.json"
const MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/biologist/manifest.json"
const TIMELINE := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_timeline.gd")
const V2_SCHEMA := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_schema.gd")
const VISUAL_CONTRACT := preload("res://scripts/ultimates/presentation/ultimate_visual_direction_contract.gd")
const WEAPON_IDS := ["biologist_spore_lens", "biologist_sample_injector", "biologist_symbiote_seed"]
const SCENES := {
	"biologist_spore_lens": preload("res://scenes/vfx/ultimates/biologist/BiologistSporeLensWorldMycelium.tscn"),
	"biologist_sample_injector": preload("res://scenes/vfx/ultimates/biologist/BiologistSampleInjectorPerfectSample.tscn"),
	"biologist_symbiote_seed": preload("res://scenes/vfx/ultimates/biologist/BiologistSymbioteSeedMatriarch.tscn"),
}
const PACKS := [
	{
		"weapon_id": "biologist_spore_lens",
		"scene": preload("res://scenes/vfx/ultimates/biologist/BiologistSporeLensWorldMycelium.tscn"),
		"time": 2.1,
		"title": "SPORE LENS — WORLD MYCELIUM",
		"position": Vector2(0.18, 0.54),
		"color": Color(0.68, 1.0, 0.52),
		"required_nodes": ["LensCore", "MyceliumGraph/VeinNorth", "MushroomBlooms/BloomA", "MushroomBlooms/BloomC"],
	},
	{
		"weapon_id": "biologist_sample_injector",
		"scene": preload("res://scenes/vfx/ultimates/biologist/BiologistSampleInjectorPerfectSample.tscn"),
		"time": 1.9,
		"title": "SAMPLE INJECTOR — PERFECT SAMPLE",
		"position": Vector2(0.5, 0.54),
		"color": Color(0.55, 1.0, 0.86),
		"required_nodes": ["NeedleRail", "ExtractionBeam", "SampleTarget", "DNAHelix/StrandA", "AnalysisPulses/PulseB"],
	},
	{
		"weapon_id": "biologist_symbiote_seed",
		"scene": preload("res://scenes/vfx/ultimates/biologist/BiologistSymbioteSeedMatriarch.tscn"),
		"time": 2.9,
		"title": "SYMBIOTE SEED — SYMBIONT MATRIARCH",
		"position": Vector2(0.82, 0.54),
		"color": Color(1.0, 0.48, 0.92),
		"required_nodes": ["Pod", "Tendrils/Tendril0", "Tendrils/Tendril3", "Larvae/Larva0", "HatchBurst"],
	},
]
const CAPTURES := [
	{"name": "648p", "path": "res://docs/design/references/weapon_ultimates/biologist/biologist_ultimate_timelines_648p.png", "size": Vector2i(1152, 648)},
	{"name": "720p", "path": "res://docs/design/references/weapon_ultimates/biologist/biologist_ultimate_timelines_720p.png", "size": Vector2i(1280, 720)},
	{"name": "1080p", "path": "res://docs/design/references/weapon_ultimates/biologist/biologist_ultimate_timelines_1080p.png", "size": Vector2i(1920, 1080)},
	{"name": "2k", "path": "res://docs/design/references/weapon_ultimates/biologist/biologist_ultimate_timelines_2k.png", "size": Vector2i(2560, 1440)},
]
const PANEL_HALF_WIDTH_RATIO := 0.145
const PANEL_HALF_HEIGHT_RATIO := 0.30
const PANEL_LABEL_Y_RATIO := 0.25
const PANEL_LABEL_FONT_RATIO := 0.018
const PANEL_CONTENT_MARGIN_RATIO := 0.03
const SHEET_TITLE := "BIOLOGIST WEAPON ULTIMATES — DISTINCT PRESENTATION TIMELINES"
const SHEET_TITLE_Y_RATIO := 0.075
const SHEET_TITLE_FONT_RATIO := 0.036
const SHEET_TEXT_MARGIN := 8.0
const CAPTURE_ALPHA_EPSILON := 0.01
const REQUIRED_PHASES := ["windup", "release", "active", "recovery", "cancel"]
const MAX_TIMELINE_SECONDS := 10.0


class HandleProbe extends RefCounted:
	var released := 0

	func release() -> void:
		released += 1


func _initialize() -> void:
	var errors: Array[String] = []
	var profile_root := _load_json(PROFILE_PATH, errors)
	var manifest := _load_json(MANIFEST_PATH, errors)
	if not errors.is_empty():
		_finish(errors)
		return
	_expect(str(manifest.get("class_id", "")) == "biologist", "manifest must be class-local to Biologist", errors)
	var contract := manifest.get("contract", {}) as Dictionary
	_expect(str(contract.get("headless_fallback", "")) == "no_op", "manifest must declare no_op headless fallback", errors)
	_expect(float(contract.get("max_timeline_seconds", 0.0)) == MAX_TIMELINE_SECONDS, "manifest must retain the ten-second cap", errors)
	_expect(not str(contract.get("runtime_adapter_status", "")).is_empty(), "runtime adapter boundary must be documented", errors)
	_check_provenance(manifest, errors)
	var profiles := _profiles_by_weapon(profile_root)
	var packages := _packages_by_weapon(manifest)
	_check_v2_ratchets(errors)
	_expect(packages.size() == WEAPON_IDS.size(), "manifest must contain exactly three Biologist packages", errors)
	for weapon_id in WEAPON_IDS:
		_check_package(weapon_id, profiles.get(weapon_id, {}) as Dictionary, packages.get(weapon_id, {}) as Dictionary, errors)
	_check_distinction(packages, errors)
	_check_timing_distinctness(packages, errors)
	_check_capture_composition(errors)
	_check_capture_text(errors)
	_check_capture_evidence(errors)
	if not errors.is_empty():
		_finish(errors)
		return
	print("Biologist ultimate timelines passed (three distinct scenes, frozen phases, lifecycle, evidence, and crowd budgets).")
	quit(0)


func _check_provenance(manifest: Dictionary, errors: Array[String]) -> void:
	var provenance := manifest.get("generator_provenance", {}) as Dictionary
	_expect(str(provenance.get("route", "")) == "reused_approved_assets_no_new_raster_generation", "provenance must explain the no-new-raster route", errors)
	var generated = provenance.get("new_pixellab_assets", [])
	_expect(generated is Array and (generated as Array).is_empty(), "no new PixelLab asset may be declared", errors)
	var sources := provenance.get("reused_sources", {}) as Dictionary
	for weapon_id in WEAPON_IDS:
		var source := sources.get(weapon_id, {}) as Dictionary
		for field in ["source_path", "runtime_texture", "runtime_scene"]:
			var path := str(source.get(field, ""))
			_expect(not path.is_empty() and FileAccess.file_exists("res://%s" % path), "%s %s must exist" % [weapon_id, field], errors)


func _check_package(weapon_id: String, profile: Dictionary, package: Dictionary, errors: Array[String]) -> void:
	_expect(not profile.is_empty(), "%s frozen profile must exist" % weapon_id, errors)
	_expect(not package.is_empty(), "%s package must exist" % weapon_id, errors)
	if profile.is_empty() or package.is_empty():
		return
	_expect(str(package.get("weapon_id", "")) == weapon_id, "%s package must retain its exact weapon ID" % weapon_id, errors)
	var pivot := package.get("pivot", {}) as Dictionary
	_expect(float(pivot.get("x", -1.0)) >= 0.0 and float(pivot.get("x", 2.0)) <= 1.0, "%s pivot x must be normalized" % weapon_id, errors)
	_expect(float(pivot.get("y", -1.0)) >= 0.0 and float(pivot.get("y", 2.0)) <= 1.0, "%s pivot y must be normalized" % weapon_id, errors)
	var timing := package.get("timing_seconds", {}) as Dictionary
	var phases := package.get("phase_ids", {}) as Dictionary
	var previous := -1.0
	for phase_name in REQUIRED_PHASES:
		var value = timing.get(phase_name, -1.0)
		_expect(value is float or value is int, "%s %s timing must be numeric" % [weapon_id, phase_name], errors)
		var seconds := float(value)
		_expect(seconds >= previous and seconds <= MAX_TIMELINE_SECONDS, "%s %s timing must be monotonic and within the cap" % [weapon_id, phase_name], errors)
		previous = seconds
		var expected := str((profile.get("cast_phases", {}) as Dictionary).get(_cast_phase_name(phase_name), ""))
		_expect(str(phases.get(phase_name, "")) == expected, "%s %s must bind the frozen Cast phase" % [weapon_id, phase_name], errors)
	_check_scene(weapon_id, package, errors)
	_check_v2_package(weapon_id, package, errors)
	_check_lifecycle(weapon_id, timing, phases, errors)


func _check_scene(weapon_id: String, package: Dictionary, errors: Array[String]) -> void:
	var packed := SCENES.get(weapon_id) as PackedScene
	_expect(packed != null, "%s scene must load" % weapon_id, errors)
	if packed == null:
		return
	var instance := packed.instantiate() as Node2D
	if instance.has_method("prepare"):
		instance.call("prepare")
	root.add_child(instance)
	var timeline := instance.get_node_or_null("Timeline") as AnimationPlayer
	_expect(timeline != null and timeline.has_animation(&"ultimate"), "%s must expose an ultimate animation" % weapon_id, errors)
	if timeline != null and timeline.has_animation(&"ultimate"):
		var cancel_time := float((package.get("timing_seconds", {}) as Dictionary).get("cancel", -1.0))
		_expect(is_equal_approx(timeline.get_animation(&"ultimate").length, cancel_time), "%s animation must end at cancel" % weapon_id, errors)
		_expect(timeline.process_mode == Node.PROCESS_MODE_INHERIT, "%s AnimationPlayer must inherit pause state" % weapon_id, errors)
	_expect(str(instance.get_meta("ultimate_id", "")) == "biologist/%s" % weapon_id, "%s scene must retain its exact profile key" % weapon_id, errors)
	for field in ["silhouette", "motion_path", "impact_language"]:
		_expect(str(instance.get_meta(field, "")) == str(package.get(field, "")), "%s scene %s must match manifest" % [weapon_id, field], errors)
	var performance := package.get("performance", {}) as Dictionary
	_expect(int(instance.get_meta("max_visual_nodes", 0)) == int(performance.get("max_visual_nodes", -1)), "%s node budget must match manifest" % weapon_id, errors)
	_expect(int(instance.get_meta("crowd_cap", 0)) == int(performance.get("crowd_cap", -1)), "%s crowd cap must match manifest" % weapon_id, errors)
	for material_key in ["max_unique_materials", "max_fullscreen_materials"]:
		_expect(int(instance.get_meta(material_key, 0)) == int(performance.get(material_key, -1)),
			"%s scene %s must match manifest" % [weapon_id, material_key], errors)
	var backdrop := instance.get_node_or_null("BackdropVeil") as CanvasItem
	_expect(backdrop != null and backdrop.visible and bool(backdrop.get_meta("fullscreen_layer", false)),
		"%s must carry a visible arena-wide backdrop veil" % weapon_id, errors)
	_expect(_visual_node_count(instance) <= int(instance.get_meta("max_visual_nodes", 0)), "%s scene must stay within its visual-node budget" % weapon_id, errors)
	match weapon_id:
		"biologist_spore_lens":
			_expect(instance.get_node("MushroomBlooms").get_child_count() == int(performance.get("secondary_bloom_cap", -1)), "spore lens bloom count must match its cap", errors)
			_expect(performance.get("secondary_bloom_recursion", true) == false, "spore lens secondary blooms must remain non-recursive", errors)
		"biologist_sample_injector":
			_expect(instance.get_node("AnalysisPulses").get_child_count() == int(performance.get("analysis_pulse_cap", -1)), "injector pulse count must match its cap", errors)
		"biologist_symbiote_seed":
			_expect(instance.get_node("Tendrils").get_child_count() == int(performance.get("tendril_cap", -1)), "seed tendril count must match its cap", errors)
			_expect(instance.get_node("Larvae").get_child_count() == int(performance.get("larva_cap", -1)), "seed larva count must match its cap", errors)
	_check_runtime_presence(instance, package, errors)
	instance.queue_free()


func _check_runtime_presence(instance: Node2D, package: Dictionary, errors: Array[String]) -> void:
	_expect(instance.has_method("begin") and instance.has_method("finish")
		and instance.has_method("presence_state_for_tests"),
		"Biologist scene must expose its runtime presence lifecycle", errors)
	if not instance.has_method("begin") or not instance.has_method("presence_state_for_tests"):
		return
	instance.call("begin", {}, {}, 0)
	var timing := package.get("timing_seconds", {}) as Dictionary
	instance.set("progress", float(timing.get("active", 0.0)) / float(timing.get("cancel", 1.0)))
	var state := instance.call("presence_state_for_tests") as Dictionary
	_expect(state.get("impact_triggered") == true,
		"first active beat must exercise the runtime presence weight", errors)
	_expect(float(state.get("hitstop_ms", 0.0)) == float((package.get("presence", {}) as Dictionary).get("hitstop_ms", -1.0)),
		"runtime hitstop must match the manifest", errors)
	_expect(state.get("cast_pose_bound") == true and state.get("silhouette_bound") == true,
		"runtime must bind the hero pose and weapon silhouette", errors)
	instance.call("finish", "cancel")


func _check_v2_package(weapon_id: String, package: Dictionary, errors: Array[String]) -> void:
	var key := "biologist/%s" % weapon_id
	_expect(V2_SCHEMA.v2_envelope_errors(package.get("timing_seconds", {}), key).is_empty(),
		"%s must stay inside the 2.5-4.0s v2 envelope" % weapon_id, errors)
	var presence := package.get("presence", {}) as Dictionary
	_expect(presence.get("fullscreen_footprint") == true,
		"%s must declare arena-wide footprint" % weapon_id, errors)
	_expect(V2_SCHEMA.V2_BACKDROP_TREATMENTS.has(str(presence.get("backdrop", ""))),
		"%s must declare a v2 backdrop" % weapon_id, errors)
	_expect(presence.get("camera_shake") == true and presence.get("sfx_ducking") == true,
		"%s must declare camera shake and SFX ducking" % weapon_id, errors)
	var hitstop := float(presence.get("hitstop_ms", 0.0))
	_expect(hitstop >= 80.0 and hitstop <= 150.0,
		"%s first-impact hitstop must stay in 80-150ms" % weapon_id, errors)
	var identity := package.get("identity", {}) as Dictionary
	_expect(str(identity.get("cast_pose_id", "")).begins_with("cast_pose.biologist."),
		"%s must declare a Biologist cast pose" % weapon_id, errors)
	var silhouette := str(identity.get("weapon_silhouette_asset", ""))
	_expect(not silhouette.is_empty() and FileAccess.file_exists(silhouette),
		"%s central weapon silhouette must exist" % weapon_id, errors)
	_expect(str(identity.get("class_palette_id", "")).begins_with("palette.biologist."),
		"%s must declare a Biologist palette" % weapon_id, errors)
	var quality := package.get("quality", {}) as Dictionary
	_expect(float(quality.get("max_viewport_coverage_ratio", 1.0)) <= 0.35
		and quality.get("hud_bands_clear") == true
		and quality.get("reduced_motion_preserves_timing") == true,
		"%s must declare HUD-safe reduced-motion readability" % weapon_id, errors)


func _check_v2_ratchets(errors: Array[String]) -> void:
	for weapon_id in WEAPON_IDS:
		_expect(not V2_SCHEMA.PRESENTATION_V2_MIGRATION_ALLOWLIST.has("biologist/%s" % weapon_id),
			"%s must leave the presentation v2 allowlist" % weapon_id, errors)
	_expect(not (VISUAL_CONTRACT.ADOPTION_GAPS.get("quality", {}) as Dictionary).has("biologist"),
		"Biologist must leave the visual-quality adoption gap", errors)


func _check_timing_distinctness(packages: Dictionary, errors: Array[String]) -> void:
	var rhythms: Array[Dictionary] = []
	for weapon_id in WEAPON_IDS:
		var timing := ((packages.get(weapon_id, {}) as Dictionary).get("timing_seconds", {}) as Dictionary)
		rhythms.append({
			"weapon_id": weapon_id,
			"total": float(timing.get("cancel", 0.0)),
			"active_window": float(timing.get("recovery", 0.0)) - float(timing.get("active", 0.0)),
		})
	for first_index in range(rhythms.size() - 1):
		for second_index in range(first_index + 1, rhythms.size()):
			for axis in ["total", "active_window"]:
				_expect(absf(float(rhythms[first_index][axis]) - float(rhythms[second_index][axis])) >= 0.1 - 0.000001,
					"%s/%s %s rhythms must differ by at least 0.1s" % [
						rhythms[first_index]["weapon_id"], rhythms[second_index]["weapon_id"], axis,
					], errors)


func _check_lifecycle(weapon_id: String, timing: Dictionary, phase_ids: Dictionary, errors: Array[String]) -> void:
	var phases: Array[Dictionary] = []
	for phase_name in REQUIRED_PHASES:
		phases.append({"name": phase_name, "phase_id": str(phase_ids.get(phase_name, ""))})
	var fixture := {"timing": timing, "phases": phases}
	var timeline = TIMELINE.new(fixture, 0)
	timeline.begin(_handles())
	timeline.advance(0.3)
	var paused_time := timeline.elapsed_seconds()
	timeline.set_paused(true)
	timeline.advance(1.0)
	_expect(is_equal_approx(timeline.elapsed_seconds(), paused_time), "%s pause must freeze elapsed time" % weapon_id, errors)
	for reason in ["cancel", "death", "node_end"]:
		var cleanup = TIMELINE.new(fixture, 0)
		var handles := _handles()
		cleanup.begin(handles)
		cleanup.finish(reason)
		_expect(cleanup.active_handle_count() == 0, "%s %s cleanup must release all handles" % [weapon_id, reason], errors)
		for handle in handles.values():
			_expect((handle as HandleProbe).released == 1, "%s %s must release each handle once" % [weapon_id, reason], errors)
	var headless = TIMELINE.new(fixture, 1)
	var snapshot := headless.begin(_handles()) as Dictionary
	_expect(str(snapshot.get("state", "")) == TIMELINE.HEADLESS_STATE, "%s headless timeline must no-op" % weapon_id, errors)
	_expect(int(snapshot.get("active_handle_count", -1)) == 0, "%s headless timeline must attach no handles" % weapon_id, errors)


func _check_distinction(packages: Dictionary, errors: Array[String]) -> void:
	for field in ["silhouette", "motion_path", "impact_language", "timing_seconds"]:
		var values := {}
		for weapon_id in WEAPON_IDS:
			values[str((packages.get(weapon_id, {}) as Dictionary).get(field, ""))] = true
		_expect(values.size() == WEAPON_IDS.size() and not values.has(""), "all Biologist weapons must have unique %s" % field, errors)


func _check_capture_composition(errors: Array[String]) -> void:
	for raw_capture in CAPTURES:
		var capture := raw_capture as Dictionary
		var size := capture.get("size", Vector2i.ZERO) as Vector2i
		for raw_pack in PACKS:
			var pack := raw_pack as Dictionary
			var scene := (pack["scene"] as PackedScene).instantiate() as Node2D
			root.add_child(scene)
			seek_capture_frame(scene, pack)
			var bounds := layout_capture_scene(scene, size, pack)
			var content_zone := panel_content_rect(size, pack)
			var context := "%s %s" % [str(capture.get("name", "")), str(pack.get("weapon_id", ""))]
			_expect(bounds.has_area(), "%s capture must expose visible bounds" % context, errors)
			_expect(content_zone.grow(0.5).encloses(bounds), "%s content %s must stay inside %s" % [context, bounds, content_zone], errors)
			for raw_node_path in pack.get("required_nodes", []) as Array:
				var node_path := str(raw_node_path)
				var item := scene.get_node_or_null(node_path) as CanvasItem
				_expect(item != null, "%s required node missing: %s" % [context, node_path], errors)
				if item == null:
					continue
				_expect(is_capture_item_visible(item, scene), "%s required node must be visible: %s" % [context, node_path], errors)
				var placed := transformed_capture_bounds(capture_item_bounds(scene, item), scene)
				_expect(placed.has_area() and content_zone.grow(0.5).encloses(placed), "%s %s must fit its panel" % [context, node_path], errors)
			scene.queue_free()


func _check_capture_text(errors: Array[String]) -> void:
	for raw_capture in CAPTURES:
		var capture := raw_capture as Dictionary
		var size := capture.get("size", Vector2i.ZERO) as Vector2i
		var sheet_zone := Rect2(Vector2.ZERO, Vector2(size)).grow(-SHEET_TEXT_MARGIN)
		_expect(sheet_zone.encloses(sheet_title_rect(size)), "%s measured sheet title must stay inside the sheet" % str(capture.get("name", "")), errors)
		for raw_pack in PACKS:
			var pack := raw_pack as Dictionary
			_expect(panel_rect(size, pack).grow(0.5).encloses(panel_label_rect(size, pack)), "%s panel label must fit: %s" % [str(capture.get("name", "")), str(pack["title"])], errors)


func _check_capture_evidence(errors: Array[String]) -> void:
	for raw_capture in CAPTURES:
		var capture := raw_capture as Dictionary
		var path := str(capture.get("path", ""))
		_expect(FileAccess.file_exists(path), "contact evidence missing: %s" % path, errors)
		if not FileAccess.file_exists(path):
			continue
		var image := Image.load_from_file(path)
		_expect(image != null and not image.is_empty(), "contact evidence must decode: %s" % path, errors)
		if image != null:
			_expect(image.get_size() == capture.get("size", Vector2i.ZERO), "contact evidence resolution mismatch: %s" % path, errors)


static func panel_center(size: Vector2i, pack: Dictionary) -> Vector2:
	return Vector2(size) * (pack["position"] as Vector2)


static func panel_rect(size: Vector2i, pack: Dictionary) -> Rect2:
	var center := panel_center(size, pack)
	var half_size := Vector2(float(size.x) * PANEL_HALF_WIDTH_RATIO, float(size.y) * PANEL_HALF_HEIGHT_RATIO)
	return Rect2(center - half_size, half_size * 2.0)


static func sheet_title_font_size(size: Vector2i) -> int:
	return maxi(18, int(size.y * SHEET_TITLE_FONT_RATIO))


static func sheet_title_rect(size: Vector2i) -> Rect2:
	var text_size := ThemeDB.fallback_font.get_string_size(SHEET_TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, sheet_title_font_size(size))
	return Rect2(Vector2((float(size.x) - text_size.x) * 0.5, float(size.y) * SHEET_TITLE_Y_RATIO), text_size)


static func panel_label_font_size(size: Vector2i) -> int:
	return maxi(12, int(size.y * PANEL_LABEL_FONT_RATIO))


static func panel_label_rect(size: Vector2i, pack: Dictionary) -> Rect2:
	var text_size := ThemeDB.fallback_font.get_string_size(str(pack["title"]), HORIZONTAL_ALIGNMENT_LEFT, -1, panel_label_font_size(size))
	var panel := panel_rect(size, pack)
	return Rect2(Vector2(panel.get_center().x - text_size.x * 0.5, panel.get_center().y + float(size.y) * PANEL_LABEL_Y_RATIO), text_size)


static func panel_content_rect(size: Vector2i, pack: Dictionary) -> Rect2:
	var panel := panel_rect(size, pack)
	var margin := float(size.y) * PANEL_CONTENT_MARGIN_RATIO
	var content_position := panel.position + Vector2.ONE * margin
	var label_y := panel.get_center().y + float(size.y) * PANEL_LABEL_Y_RATIO
	return Rect2(content_position, Vector2(panel.size.x - margin * 2.0, label_y - margin - content_position.y))


static func seek_capture_frame(scene: Node2D, pack: Dictionary) -> void:
	if scene.has_method("prepare"):
		scene.call("prepare")
	var timeline := scene.get_node("Timeline") as AnimationPlayer
	timeline.stop()
	timeline.play(&"ultimate")
	timeline.seek(float(pack["time"]), true)
	scene.set("progress", float(pack["time"]) / timeline.get_animation(&"ultimate").length)


static func layout_capture_scene(scene: Node2D, size: Vector2i, pack: Dictionary) -> Rect2:
	scene.position = Vector2.ZERO
	scene.scale = Vector2.ONE
	var bounds := capture_content_bounds(scene)
	if not bounds.has_area():
		return Rect2()
	var content_zone := panel_content_rect(size, pack)
	var base_scale := clampf(float(size.y) / 1040.0, 0.54, 1.28)
	var fit_scale := minf(content_zone.size.x / bounds.size.x, content_zone.size.y / bounds.size.y)
	var scale := minf(base_scale, fit_scale)
	scene.scale = Vector2.ONE * scale
	scene.position = content_zone.get_center() - bounds.get_center() * scale
	return transformed_capture_bounds(bounds, scene)


static func capture_content_bounds(scene: Node2D) -> Rect2:
	var bounds := Rect2()
	var found := false
	var pending: Array[Node] = [scene]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child in node.get_children():
			pending.append(child)
			if not child is CanvasItem:
				continue
			var item := child as CanvasItem
			if not is_capture_item_visible(item, scene):
				continue
			var item_bounds := capture_item_bounds(scene, item)
			if not item_bounds.has_area():
				continue
			bounds = item_bounds if not found else bounds.merge(item_bounds)
			found = true
	return bounds


static func capture_item_bounds(scene: Node2D, item: CanvasItem) -> Rect2:
	var local_rect := _capture_item_local_rect(item)
	if not local_rect.has_area():
		return Rect2()
	var transform := _transform_to_scene(scene, item)
	return _rect_from_points(PackedVector2Array([
		transform * local_rect.position,
		transform * Vector2(local_rect.end.x, local_rect.position.y),
		transform * local_rect.end,
		transform * Vector2(local_rect.position.x, local_rect.end.y),
	]))


static func transformed_capture_bounds(bounds: Rect2, scene: Node2D) -> Rect2:
	return Rect2(scene.position + bounds.position * scene.scale, bounds.size * scene.scale) if bounds.has_area() else Rect2()


static func is_capture_item_visible(item: CanvasItem, scene: Node2D) -> bool:
	var cursor: Node = item
	while cursor != null and cursor != scene:
		if cursor is CanvasItem:
			var canvas_item := cursor as CanvasItem
			if not canvas_item.visible or canvas_item.modulate.a * canvas_item.self_modulate.a <= CAPTURE_ALPHA_EPSILON:
				return false
		cursor = cursor.get_parent()
	if item is Line2D and (item as Line2D).default_color.a <= CAPTURE_ALPHA_EPSILON:
		return false
	return true


static func _capture_item_local_rect(item: CanvasItem) -> Rect2:
	if item is Sprite2D:
		return (item as Sprite2D).get_rect()
	if item is Line2D:
		var line := item as Line2D
		return _rect_from_points(line.points).grow(line.width * 0.5)
	return Rect2()


static func _transform_to_scene(scene: Node2D, item: CanvasItem) -> Transform2D:
	var transform := Transform2D.IDENTITY
	var cursor: Node = item
	while cursor != null and cursor != scene:
		if cursor is Node2D:
			transform = (cursor as Node2D).transform * transform
		cursor = cursor.get_parent()
	return transform


static func _rect_from_points(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var min_point := points[0]
	var max_point := points[0]
	for point in points:
		min_point = min_point.min(point)
		max_point = max_point.max(point)
	return Rect2(min_point, max_point - min_point)


func _visual_node_count(root_node: Node) -> int:
	var count := 0
	var pending: Array[Node] = [root_node]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		for child in current.get_children():
			pending.append(child)
			if child is Sprite2D or child is Line2D or child is Polygon2D:
				count += 1
	return count


func _handles() -> Dictionary:
	return {"animation": HandleProbe.new(), "vfx": HandleProbe.new(), "sfx": HandleProbe.new()}


func _profiles_by_weapon(data: Dictionary) -> Dictionary:
	var result := {}
	for raw_profile in data.get("profiles", []) as Array:
		if raw_profile is Dictionary:
			var profile := raw_profile as Dictionary
			result[str(profile.get("weapon_id", ""))] = profile
	return result


func _packages_by_weapon(manifest: Dictionary) -> Dictionary:
	var result := {}
	for raw_package in manifest.get("weapons", []) as Array:
		if raw_package is Dictionary:
			var package := raw_package as Dictionary
			result[str(package.get("weapon_id", ""))] = package
	return result


func _cast_phase_name(presentation_name: String) -> String:
	return {"windup": "windup", "release": "execute", "active": "active", "recovery": "recover", "cancel": "cleanup"}.get(presentation_name, "")


func _load_json(path: String, errors: Array[String]) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("missing JSON: %s" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		errors.append("invalid JSON: %s" % path)
		return {}
	return parsed as Dictionary


func _expect(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)


func _finish(errors: Array[String]) -> void:
	for error in errors:
		push_error("Biologist ultimate timeline: %s" % error)
	quit(1)
