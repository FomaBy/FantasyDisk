extends SceneTree

const PROFILE_PATH := "res://data/ultimates/schema/v1/classes/chemist.json"
const MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/chemist/manifest.json"
const TIMELINE := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_timeline.gd")
const WEAPON_IDS := ["blast_powder", "acid_flask", "homunculus_vial"]
const SCENES := {
	"blast_powder": preload("res://scenes/vfx/ultimates/chemist/ChemistBlastPowderPhilosophersExplosion.tscn"),
	"acid_flask": preload("res://scenes/vfx/ultimates/chemist/ChemistAcidFlaskTsarFlask.tscn"),
	"homunculus_vial": preload("res://scenes/vfx/ultimates/chemist/ChemistHomunculusVialPerfectHomunculus.tscn"),
}
const PACKS := [
	{
		"weapon_id": "blast_powder",
		"scene": SCENES["blast_powder"],
		"time": 1.6,
		"title": "BLAST POWDER — PENTAGRAM",
		"position": Vector2(0.18, 0.54),
		"color": Color(1.0, 0.78, 0.28),
		"required_nodes": ["PowderPentagram/PentagramLines", "PowderPentagram/PowderOne", "CrystalImplosion", "TransmutationBlast", "GoldRadiance"],
	},
	{
		"weapon_id": "acid_flask",
		"scene": SCENES["acid_flask"],
		"time": 2.3,
		"title": "ACID FLASK — TSAR LAKE",
		"position": Vector2(0.5, 0.54),
		"color": Color(0.58, 1.0, 0.34),
		"required_nodes": ["PourArc", "AcidWave", "AcidLake", "ChargePillars/PillarTwo", "EvaporationSmoke"],
	},
	{
		"weapon_id": "homunculus_vial",
		"scene": SCENES["homunculus_vial"],
		"time": 2.6,
		"title": "HOMUNCULUS VIAL — FUSION",
		"position": Vector2(0.82, 0.54),
		"color": Color(0.48, 1.0, 0.52),
		"required_nodes": ["AlchemicalCircle", "Avatar", "TauntHalo", "StompWave", "ToxicCascade"],
	},
]
const CAPTURES := [
	{"name": "648p", "path": "res://docs/design/references/weapon_ultimates/chemist/chemist_ultimate_timelines_648p.png", "size": Vector2i(1152, 648)},
	{"name": "720p", "path": "res://docs/design/references/weapon_ultimates/chemist/chemist_ultimate_timelines_720p.png", "size": Vector2i(1280, 720)},
	{"name": "1080p", "path": "res://docs/design/references/weapon_ultimates/chemist/chemist_ultimate_timelines_1080p.png", "size": Vector2i(1920, 1080)},
	{"name": "2k", "path": "res://docs/design/references/weapon_ultimates/chemist/chemist_ultimate_timelines_2k.png", "size": Vector2i(2560, 1440)},
]
const SHEET_TITLE := "CHEMIST WEAPON ULTIMATES — DISTINCT PRESENTATION TIMELINES"
const SHEET_TITLE_Y_RATIO := 0.075
const SHEET_TITLE_FONT_RATIO := 0.036
const SHEET_TEXT_MARGIN := 8.0
const PANEL_HALF_WIDTH_RATIO := 0.145
const PANEL_HALF_HEIGHT_RATIO := 0.30
const PANEL_CONTENT_MARGIN_RATIO := 0.03
const CAPTURE_ALPHA_EPSILON := 0.01
const REQUIRED_PHASES := ["windup", "release", "active", "recovery", "cancel"]
const MAX_TIMELINE_SECONDS := 10.0


class HandleProbe extends RefCounted:
	var released := 0

	func release() -> void:
		released += 1


func _initialize() -> void:
	var errors: Array[String] = []
	var profiles := _profiles_by_weapon(_load_json(PROFILE_PATH, errors))
	var manifest := _load_json(MANIFEST_PATH, errors)
	if not errors.is_empty():
		_finish(errors)
		return
	_expect(str(manifest.get("class_id", "")) == "chemist", "manifest must be class-local to Chemist", errors)
	var contract := manifest.get("contract", {}) as Dictionary
	_expect(str(contract.get("headless_fallback", "")) == "no_op", "manifest must declare no_op headless fallback", errors)
	_expect(not str(contract.get("runtime_adapter_status", "")).is_empty(), "runtime adapter boundary must be documented", errors)
	_check_provenance(manifest, errors)
	var packages := _packages_by_weapon(manifest)
	_expect(packages.size() == 3, "manifest must contain exactly three Chemist packages", errors)
	for weapon_id in WEAPON_IDS:
		_check_package(weapon_id, profiles.get(weapon_id, {}) as Dictionary, packages.get(weapon_id, {}) as Dictionary, errors)
	_check_distinction(packages, errors)
	_check_capture_composition(errors)
	_check_capture_text(errors)
	_check_capture_evidence(errors)
	if not errors.is_empty():
		_finish(errors)
		return
	print("Chemist ultimate timelines passed (distinct scenes, frozen phases, lifecycle, text fit, and evidence).")
	quit(0)


func _check_provenance(manifest: Dictionary, errors: Array[String]) -> void:
	var provenance := manifest.get("generator_provenance", {}) as Dictionary
	_expect(str(provenance.get("route", "")) == "reused_approved_assets_no_new_raster_generation", "provenance must identify approved-asset reuse", errors)
	_expect((provenance.get("new_pixellab_assets", null) is Array) and (provenance.get("new_pixellab_assets") as Array).is_empty(), "no new PixelLab asset IDs should be declared", errors)
	var sources := provenance.get("reused_sources", {}) as Dictionary
	for weapon_id in WEAPON_IDS:
		var source := sources.get(weapon_id, {}) as Dictionary
		_expect(FileAccess.file_exists("res://%s" % str(source.get("source_path", ""))), "%s reused source must exist" % weapon_id, errors)
		_expect(FileAccess.file_exists("res://%s" % str(source.get("runtime_scene", ""))), "%s runtime scene must exist" % weapon_id, errors)


func _check_package(weapon_id: String, profile: Dictionary, package: Dictionary, errors: Array[String]) -> void:
	_expect(not profile.is_empty(), "%s frozen profile must exist" % weapon_id, errors)
	_expect(not package.is_empty(), "%s presentation package must exist" % weapon_id, errors)
	if profile.is_empty() or package.is_empty():
		return
	_expect(str(package.get("weapon_id", "")) == weapon_id, "%s package weapon ID must be exact" % weapon_id, errors)
	var timing := package.get("timing_seconds", {}) as Dictionary
	var phases := package.get("phase_ids", {}) as Dictionary
	var previous := -1.0
	for phase_name in REQUIRED_PHASES:
		var value = timing.get(phase_name, -1.0)
		_expect(value is float or value is int, "%s %s timing must be numeric" % [weapon_id, phase_name], errors)
		var seconds := float(value)
		_expect(seconds >= previous and seconds <= MAX_TIMELINE_SECONDS, "%s %s timing must be monotonic and capped" % [weapon_id, phase_name], errors)
		previous = seconds
		var expected := str((profile.get("cast_phases", {}) as Dictionary).get(_cast_phase_name(phase_name), ""))
		_expect(str(phases.get(phase_name, "")) == expected, "%s %s must bind to its frozen Cast phase ID" % [weapon_id, phase_name], errors)
	_check_scene(weapon_id, package, errors)
	_check_lifecycle(weapon_id, timing, phases, errors)


func _check_scene(weapon_id: String, package: Dictionary, errors: Array[String]) -> void:
	var scene := SCENES.get(weapon_id) as PackedScene
	_expect(scene != null, "%s scene must load" % weapon_id, errors)
	if scene == null:
		return
	var instance := scene.instantiate() as Node2D
	root.add_child(instance)
	var timeline := instance.get_node_or_null("Timeline") as AnimationPlayer
	_expect(timeline != null and timeline.has_animation(&"ultimate"), "%s must expose an ultimate animation" % weapon_id, errors)
	if timeline != null and timeline.has_animation(&"ultimate"):
		_expect(is_equal_approx(timeline.get_animation(&"ultimate").length, float((package.get("timing_seconds", {}) as Dictionary).get("cancel", -1.0))), "%s scene animation must end at cancel" % weapon_id, errors)
	_expect(str(instance.get_meta("ultimate_id", "")) == "chemist/%s" % weapon_id, "%s scene must retain exact profile key" % weapon_id, errors)
	for field in ["silhouette", "motion_path", "impact_language"]:
		_expect(not str(instance.get_meta(field, "")).is_empty(), "%s %s declaration missing" % [weapon_id, field], errors)
	_expect(instance.get_child_count() <= int(instance.get_meta("crowd_cap", 0)), "%s visible scene nodes must stay within crowd cap" % weapon_id, errors)
	_expect(int(instance.get_meta("max_visual_nodes", 0)) <= int(instance.get_meta("crowd_cap", 0)), "%s declared visual budget must stay within crowd cap" % weapon_id, errors)
	instance.queue_free()


func _check_lifecycle(weapon_id: String, timing: Dictionary, phases: Dictionary, errors: Array[String]) -> void:
	var phase_entries: Array[Dictionary] = []
	for name in REQUIRED_PHASES:
		phase_entries.append({"name": name, "phase_id": str(phases.get(name, ""))})
	var fixture := {"timing": timing, "phases": phase_entries}
	var timeline = TIMELINE.new(fixture, 0)
	timeline.begin({"animation": HandleProbe.new(), "vfx": HandleProbe.new(), "sfx": HandleProbe.new()})
	timeline.advance(0.05)
	var paused_time := timeline.elapsed_seconds()
	timeline.set_paused(true)
	timeline.advance(1.0)
	_expect(is_equal_approx(timeline.elapsed_seconds(), paused_time), "%s pause must freeze elapsed timeline time" % weapon_id, errors)
	for reason in ["cancel", "death", "node_end"]:
		var cleanup_timeline = TIMELINE.new(fixture, 0)
		var handles := {"animation": HandleProbe.new(), "vfx": HandleProbe.new(), "sfx": HandleProbe.new()}
		cleanup_timeline.begin(handles)
		cleanup_timeline.finish(reason)
		_expect(cleanup_timeline.active_handle_count() == 0, "%s %s cleanup must release every handle" % [weapon_id, reason], errors)
		for handle in handles.values():
			_expect((handle as HandleProbe).released == 1, "%s %s must release each handle once" % [weapon_id, reason], errors)


func _check_distinction(packages: Dictionary, errors: Array[String]) -> void:
	for field in ["silhouette", "motion_path", "timing_rhythm", "impact_language"]:
		var values := {}
		for weapon_id in WEAPON_IDS:
			values[str((packages.get(weapon_id, {}) as Dictionary).get(field, ""))] = true
		_expect(values.size() == 3 and not values.has(""), "all three weapons must have different %s values" % field, errors)


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
			var zone := panel_content_rect(size, pack)
			var context := "%s %s" % [str(capture.get("name", "")), str(pack.get("weapon_id", ""))]
			_expect(bounds.has_area() and zone.grow(0.5).encloses(bounds), "%s content must fit its panel" % context, errors)
			for raw_path in pack.get("required_nodes", []) as Array:
				var item := scene.get_node_or_null(str(raw_path)) as CanvasItem
				_expect(item != null and is_capture_item_visible(item, scene), "%s required item must be visible: %s" % [context, raw_path], errors)
				if item != null:
					_expect(zone.grow(0.5).encloses(transformed_capture_bounds(capture_item_bounds(scene, item), scene)), "%s item must fit its panel: %s" % [context, raw_path], errors)
			scene.queue_free()


func _check_capture_text(errors: Array[String]) -> void:
	for raw_capture in CAPTURES:
		var capture := raw_capture as Dictionary
		var size := capture.get("size", Vector2i.ZERO) as Vector2i
		var sheet_zone := Rect2(Vector2.ZERO, Vector2(size)).grow(-SHEET_TEXT_MARGIN)
		_expect(sheet_zone.encloses(sheet_title_rect(size)), "%s sheet title must fit measured bounds" % str(capture.get("name", "")), errors)
		for raw_pack in PACKS:
			var pack := raw_pack as Dictionary
			_expect(panel_rect(size, pack).grow(0.5).encloses(panel_label_rect(size, pack)), "%s panel label must fit: %s" % [str(capture.get("name", "")), str(pack.get("title", ""))], errors)


func _check_capture_evidence(errors: Array[String]) -> void:
	for raw_capture in CAPTURES:
		var capture := raw_capture as Dictionary
		var path := str(capture.get("path", ""))
		_expect(FileAccess.file_exists(path), "contact evidence is missing: %s" % path, errors)
		if FileAccess.file_exists(path):
			var image := Image.load_from_file(path)
			_expect(image != null and not image.is_empty() and image.get_size() == capture.get("size", Vector2i.ZERO), "contact evidence must decode at the declared resolution: %s" % path, errors)


static func panel_center(size: Vector2i, pack: Dictionary) -> Vector2:
	return Vector2(size) * (pack["position"] as Vector2)


static func panel_rect(size: Vector2i, pack: Dictionary) -> Rect2:
	var half_size := Vector2(float(size.x) * PANEL_HALF_WIDTH_RATIO, float(size.y) * PANEL_HALF_HEIGHT_RATIO)
	return Rect2(panel_center(size, pack) - half_size, half_size * 2.0)


static func panel_content_rect(size: Vector2i, pack: Dictionary) -> Rect2:
	var panel := panel_rect(size, pack)
	var margin := float(size.y) * PANEL_CONTENT_MARGIN_RATIO
	return Rect2(panel.position + Vector2.ONE * margin, Vector2(panel.size.x - margin * 2.0, panel.size.y - margin * 2.0 - sheet_title_font_size(size)))


static func sheet_title_font_size(size: Vector2i) -> int:
	return maxi(18, int(size.y * SHEET_TITLE_FONT_RATIO))


static func sheet_title_rect(size: Vector2i) -> Rect2:
	var text_size := ThemeDB.fallback_font.get_string_size(SHEET_TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, sheet_title_font_size(size))
	return Rect2(Vector2((float(size.x) - text_size.x) * 0.5, float(size.y) * SHEET_TITLE_Y_RATIO), text_size)


static func panel_label_rect(size: Vector2i, pack: Dictionary) -> Rect2:
	var panel := panel_rect(size, pack)
	var font_size := maxi(12, int(size.y * 0.021))
	var text_size := ThemeDB.fallback_font.get_string_size(str(pack["title"]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	return Rect2(Vector2(panel.get_center().x - text_size.x * 0.5, panel.end.y - text_size.y - float(size.y) * 0.018), text_size)


static func seek_capture_frame(scene: Node2D, pack: Dictionary) -> void:
	var timeline := scene.get_node("Timeline") as AnimationPlayer
	timeline.stop()
	timeline.play(&"ultimate")
	timeline.seek(float(pack["time"]), true)


static func layout_capture_scene(scene: Node2D, size: Vector2i, pack: Dictionary) -> Rect2:
	scene.position = Vector2.ZERO
	scene.scale = Vector2.ONE
	var bounds := capture_content_bounds(scene)
	if not bounds.has_area():
		return Rect2()
	var zone := panel_content_rect(size, pack)
	var scale := minf(float(size.y) / 1040.0, minf(zone.size.x / bounds.size.x, zone.size.y / bounds.size.y))
	scene.scale = Vector2.ONE * scale
	scene.position = zone.get_center() - bounds.get_center() * scale
	return transformed_capture_bounds(bounds, scene)


static func capture_content_bounds(scene: Node2D) -> Rect2:
	var bounds := Rect2()
	var found := false
	var pending: Array[Node] = [scene]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child in node.get_children():
			pending.append(child)
			if child is CanvasItem and is_capture_item_visible(child as CanvasItem, scene):
				var item_bounds := capture_item_bounds(scene, child as CanvasItem)
				if item_bounds.has_area():
					bounds = item_bounds if not found else bounds.merge(item_bounds)
					found = true
	return bounds


static func capture_item_bounds(scene: Node2D, item: CanvasItem) -> Rect2:
	var local_rect := Rect2()
	if item is Sprite2D:
		local_rect = (item as Sprite2D).get_rect()
	elif item is Line2D:
		local_rect = _rect_from_points((item as Line2D).points).grow((item as Line2D).width * 0.5)
	elif item is Polygon2D:
		local_rect = _rect_from_points((item as Polygon2D).polygon)
	if not local_rect.has_area():
		return Rect2()
	var transform := Transform2D.IDENTITY
	var cursor: Node = item
	while cursor != null and cursor != scene:
		if cursor is Node2D:
			transform = (cursor as Node2D).transform * transform
		cursor = cursor.get_parent()
	return _rect_from_points(PackedVector2Array([transform * local_rect.position, transform * Vector2(local_rect.end.x, local_rect.position.y), transform * local_rect.end, transform * Vector2(local_rect.position.x, local_rect.end.y)]))


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
	if item is Polygon2D and (item as Polygon2D).color.a <= CAPTURE_ALPHA_EPSILON:
		return false
	if item is Line2D and (item as Line2D).default_color.a <= CAPTURE_ALPHA_EPSILON:
		return false
	return true


static func _rect_from_points(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var min_point := points[0]
	var max_point := points[0]
	for point in points:
		min_point = min_point.min(point)
		max_point = max_point.max(point)
	return Rect2(min_point, max_point - min_point)


func _profiles_by_weapon(root_data: Dictionary) -> Dictionary:
	var result := {}
	for raw_profile in root_data.get("profiles", []) as Array:
		if raw_profile is Dictionary:
			result[str((raw_profile as Dictionary).get("weapon_id", ""))] = raw_profile
	return result


func _packages_by_weapon(manifest: Dictionary) -> Dictionary:
	var result := {}
	for raw_package in manifest.get("weapons", []) as Array:
		if raw_package is Dictionary:
			result[str((raw_package as Dictionary).get("weapon_id", ""))] = raw_package
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
		push_error("Chemist ultimate timeline: %s" % error)
	quit(1)
