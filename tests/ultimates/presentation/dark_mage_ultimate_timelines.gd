extends SceneTree

const PROFILE_PATH := "res://data/ultimates/schema/v1/classes/dark_mage.json"
const MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/dark_mage/manifest.json"
const Schema := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_schema.gd")
const TIMELINE := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_timeline.gd")
const DirectionContract := preload("res://scripts/ultimates/presentation/ultimate_visual_direction_contract.gd")
const SCENES := {
	"dark_book": preload("res://scenes/vfx/ultimates/dark_mage/DarkMageBookAbyssMirror.tscn"),
	"cursed_skull": preload("res://scenes/vfx/ultimates/dark_mage/DarkMageSkullCursedCrown.tscn"),
	"dark_wand": preload("res://scenes/vfx/ultimates/dark_mage/DarkMageWandVanishingThread.tscn"),
}
const WEAPON_IDS := ["dark_book", "cursed_skull", "dark_wand"]
const PACKS := [
	{
		"weapon_id": "dark_book",
		"scene": preload("res://scenes/vfx/ultimates/dark_mage/DarkMageBookAbyssMirror.tscn"),
		"time": 1.95,
		"title": "DARK BOOK — ABYSS MIRROR",
		"position": Vector2(0.18, 0.54),
		"color": Color(0.76, 0.42, 1.0),
		"required_nodes": ["BookGhost", "MirrorPlane", "OriginalShadow", "ReflectionShadow", "PairedDetonation"],
	},
	{
		"weapon_id": "cursed_skull",
		"scene": preload("res://scenes/vfx/ultimates/dark_mage/DarkMageSkullCursedCrown.tscn"),
		"time": 2.55,
		"title": "CURSED SKULL — CURSED CROWN",
		"position": Vector2(0.5, 0.54),
		"color": Color(0.68, 0.9, 0.42),
		"required_nodes": ["SkullCrown", "CurseChains", "SoulWispLeft", "HarvestBite"],
	},
	{
		"weapon_id": "dark_wand",
		"scene": preload("res://scenes/vfx/ultimates/dark_mage/DarkMageWandVanishingThread.tscn"),
		"time": 2.5,
		"title": "DARK WAND — VANISHING THREAD",
		"position": Vector2(0.82, 0.54),
		"color": Color(0.4, 0.84, 1.0),
		"required_nodes": ["WandGhost", "OuterThread", "NodeMarks", "CollapseAfterimage"],
	},
]
const CAPTURES := [
	{"name": "648p", "path": "res://docs/design/references/weapon_ultimates/dark_mage/dark_mage_ultimate_timelines_648p.png", "size": Vector2i(1152, 648)},
	{"name": "720p", "path": "res://docs/design/references/weapon_ultimates/dark_mage/dark_mage_ultimate_timelines_720p.png", "size": Vector2i(1280, 720)},
	{"name": "1080p", "path": "res://docs/design/references/weapon_ultimates/dark_mage/dark_mage_ultimate_timelines_1080p.png", "size": Vector2i(1920, 1080)},
	{"name": "2k", "path": "res://docs/design/references/weapon_ultimates/dark_mage/dark_mage_ultimate_timelines_2k.png", "size": Vector2i(2560, 1440)},
]
const PANEL_HALF_WIDTH_RATIO := 0.145
const PANEL_HALF_HEIGHT_RATIO := 0.30
const PANEL_LABEL_Y_RATIO := 0.25
const PANEL_CONTENT_MARGIN_RATIO := 0.03
const CAPTURE_ALPHA_EPSILON := 0.01
const REQUIRED_PHASES := ["windup", "release", "active", "recovery", "cancel"]
const REQUIRED_CHANNELS := ["animation", "vfx", "sfx"]
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
	_expect(str(manifest.get("class_id", "")) == "dark_mage", "manifest must be class-local to Dark Mage", errors)
	var contract := manifest.get("contract", {}) as Dictionary
	_expect(contract.get("phase_groups", []) == REQUIRED_PHASES, "manifest must declare all five required phase groups", errors)
	_expect(str(contract.get("headless_fallback", "")) == "no_op", "manifest must declare no_op headless fallback", errors)
	_expect(is_equal_approx(float(contract.get("max_timeline_seconds", -1.0)), MAX_TIMELINE_SECONDS), "manifest must retain the ten-second cap", errors)
	_expect(not str(contract.get("runtime_adapter_status", "")).is_empty(), "runtime adapter boundary must be documented", errors)
	_check_provenance(manifest, errors)
	_check_provenance_negative_cases(manifest, errors)
	var profiles := _profiles_by_weapon(profile_root)
	var packages := _packages_by_weapon(manifest)
	_expect(packages.size() == 3, "manifest must contain exactly three Dark Mage weapon packages", errors)
	for weapon_id in WEAPON_IDS:
		_check_package(weapon_id, profiles.get(weapon_id, {}) as Dictionary, packages.get(weapon_id, {}) as Dictionary, errors)
	_check_v2_adoption(manifest, packages, errors)
	_check_distinction(packages, errors)
	_check_capture_composition(errors)
	_check_capture_evidence(errors)
	if not errors.is_empty():
		_finish(errors)
		return
	print("Dark Mage ultimate timelines passed (three distinct scenes, frozen phases, lifecycle, evidence, and crowd budgets).")
	quit(0)


func _check_provenance(manifest: Dictionary, errors: Array[String]) -> void:
	var provenance := manifest.get("generator_provenance", {}) as Dictionary
	_expect(str(provenance.get("route", "")) == "reused_approved_assets_plus_new_pixellab_animation_frames", "provenance must declare the reused-assets-plus-new-PixelLab-frames route", errors)
	var new_assets := {}
	for raw_id in provenance.get("new_pixellab_assets", []) as Array:
		new_assets[str(raw_id)] = true
	_expect(new_assets.size() == WEAPON_IDS.size(), "new PixelLab assets must list each Dark Mage weapon exactly once, with no foreign or duplicate entries", errors)
	for weapon_id in WEAPON_IDS:
		_expect(new_assets.has(weapon_id), "%s must be declared as a newly generated PixelLab asset" % weapon_id, errors)
	_expect(not str(provenance.get("historical_source_note", "")).is_empty(), "historical generator provenance must be retained", errors)
	var sources := provenance.get("reused_sources", {}) as Dictionary
	for weapon_id in WEAPON_IDS:
		var source := sources.get(weapon_id, {}) as Dictionary
		for key in ["source_reference", "source_notes", "weapon_runtime_path", "vfx_runtime_path", "runtime_scene"]:
			var path := str(source.get(key, ""))
			_expect(not path.is_empty() and FileAccess.file_exists("res://%s" % path), "%s %s must be recorded and exist" % [weapon_id, key], errors)
		_expect(_file_sha256(str(source.get("weapon_runtime_path", ""))) == str(source.get("weapon_sha256", "")), "%s weapon SHA-256 must match the reused asset" % weapon_id, errors)
		_expect(_file_sha256(str(source.get("vfx_runtime_path", ""))) == str(source.get("vfx_sha256", "")), "%s VFX SHA-256 must match the reused asset" % weapon_id, errors)
		_expect(source.get("modified", true) == false, "%s reused assets must remain unmodified" % weapon_id, errors)
	_check_pixellab_pack_provenance(provenance, errors)


func _check_pixellab_pack_provenance(provenance: Dictionary, errors: Array[String]) -> void:
	var pack_manifests := provenance.get("new_pack_manifests", {}) as Dictionary
	_expect(pack_manifests.size() == WEAPON_IDS.size(), "manifest must declare a pack provenance file for exactly the three Dark Mage weapons", errors)
	var object_ids := {}
	var animation_group_ids := {}
	for weapon_id in WEAPON_IDS:
		var manifest_path := str(pack_manifests.get(weapon_id, ""))
		_expect(not manifest_path.is_empty(), "%s must record a PixelLab pack provenance manifest path" % weapon_id, errors)
		if manifest_path.is_empty():
			continue
		var pack := _load_json("res://%s" % manifest_path, errors)
		if pack.is_empty():
			continue
		_expect(str(pack.get("class_id", "")) == "dark_mage", "%s pack provenance must be class-local to Dark Mage" % weapon_id, errors)
		_expect(str(pack.get("weapon_id", "")) == weapon_id, "%s pack provenance weapon ID must be exact" % weapon_id, errors)
		var pack_object := pack.get("object", {}) as Dictionary
		var object_id := str(pack_object.get("pixel_lab_object_id", ""))
		var animation_group_id := str(pack_object.get("pixel_lab_animation_group_id", ""))
		_expect(not object_id.is_empty(), "%s must record a PixelLab object ID" % weapon_id, errors)
		_expect(not animation_group_id.is_empty(), "%s must record a PixelLab animation group ID" % weapon_id, errors)
		_expect(not object_ids.has(object_id), "%s PixelLab object ID must be unique to this weapon" % weapon_id, errors)
		_expect(not animation_group_ids.has(animation_group_id), "%s PixelLab animation group ID must be unique to this weapon" % weapon_id, errors)
		object_ids[object_id] = true
		animation_group_ids[animation_group_id] = true


func _check_provenance_negative_cases(manifest: Dictionary, errors: Array[String]) -> void:
	_expect_provenance_case_rejected(manifest, {"route": "reused_approved_assets_no_new_raster_generation", "new_pixellab_assets": []}, "superseded no-new-raster contract", errors)
	_expect_provenance_case_rejected(manifest, {"new_pixellab_assets": []}, "empty PixelLab asset list", errors)
	_expect_provenance_case_rejected(manifest, {"new_pixellab_assets": ["dark_book", "cursed_skull", "unknown_weapon"]}, "foreign PixelLab asset ID", errors)
	_expect_provenance_case_rejected(manifest, {"new_pixellab_assets": ["dark_book", "dark_book", "cursed_skull"]}, "duplicate PixelLab asset ID", errors)


func _expect_provenance_case_rejected(manifest: Dictionary, overrides: Dictionary, case_name: String, errors: Array[String]) -> void:
	var mutated := manifest.duplicate(true)
	var provenance := (mutated.get("generator_provenance", {}) as Dictionary).duplicate(true)
	for key in overrides:
		provenance[key] = overrides[key]
	mutated["generator_provenance"] = provenance
	var case_errors: Array[String] = []
	_check_provenance(mutated, case_errors)
	_expect(not case_errors.is_empty(), "provenance check must fail-closed on %s" % case_name, errors)


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
		_expect(seconds >= previous and seconds <= MAX_TIMELINE_SECONDS, "%s %s timing must be monotonic and within the ten-second cap" % [weapon_id, phase_name], errors)
		previous = seconds
		var expected_phase := str((profile.get("cast_phases", {}) as Dictionary).get(_cast_phase_name(phase_name), ""))
		_expect(str(phases.get(phase_name, "")) == expected_phase, "%s %s must bind to the frozen Cast phase ID" % [weapon_id, phase_name], errors)
	var channels := package.get("channels", {}) as Dictionary
	for channel in REQUIRED_CHANNELS:
		var path := str(channels.get(channel, ""))
		_expect(not path.is_empty() and FileAccess.file_exists("res://%s" % path), "%s %s channel must resolve" % [weapon_id, channel], errors)
	var pivot := package.get("pivot", []) as Array
	_expect(pivot.size() == 2, "%s pivot must have two normalized components" % weapon_id, errors)
	if pivot.size() == 2:
		_expect(float(pivot[0]) >= 0.0 and float(pivot[0]) <= 1.0 and float(pivot[1]) >= 0.0 and float(pivot[1]) <= 1.0, "%s pivot must stay normalized" % weapon_id, errors)
	_check_scene(weapon_id, package, errors)
	_check_lifecycle(weapon_id, timing, phases, errors)


## FAN-2528: this card closes Dark Mage's own migration entries. The shared
## ratchets and the class-focused timeline proof must agree, so no future v1
## timing, generic silhouette or missing readable-impact declaration can slip
## back behind an allowlist.
func _check_v2_adoption(manifest: Dictionary, packages: Dictionary, errors: Array[String]) -> void:
	_expect(DirectionContract.violations("dark_mage", manifest).is_empty(),
		"Dark Mage must satisfy every visual-direction gate: %s" % [
			str(DirectionContract.violations("dark_mage", manifest)),
		], errors)
	for gate in DirectionContract.GATES:
		_expect(not (DirectionContract.ADOPTION_GAPS.get(gate, {}) as Dictionary).has("dark_mage"),
			"Dark Mage must leave the %s visual-direction allowlist" % gate, errors)
	for weapon_id in WEAPON_IDS:
		var key := "dark_mage/%s" % weapon_id
		var package := packages.get(weapon_id, {}) as Dictionary
		_expect(not Schema.PRESENTATION_V2_MIGRATION_ALLOWLIST.has(key),
			"%s must leave the presentation V2 migration allowlist" % key, errors)
		errors.append_array(Schema.v2_envelope_errors(package.get("timing_seconds"), key))
		var presence := package.get("presence", {}) as Dictionary
		_expect(presence.get("fullscreen_footprint") == true
			and presence.get("camera_shake") == true
			and float(presence.get("hitstop_ms", 0.0)) >= 80.0
			and float(presence.get("hitstop_ms", 0.0)) <= 150.0,
			"%s must declare full-screen presence, shake and 80-150ms hitstop" % key, errors)
		var identity := package.get("identity", {}) as Dictionary
		_expect(not str(identity.get("cast_pose_id", "")).is_empty()
			and FileAccess.file_exists(str(identity.get("cast_pose_asset", "")))
			and FileAccess.file_exists(str(identity.get("weapon_silhouette_asset", "")))
			and str(identity.get("cast_pose_asset", "")) != str(identity.get("weapon_silhouette_asset", ""))
			and str(identity.get("class_palette_id", "")) == "dark_mage.abyssal_violet",
			"%s must bind Dark Mage pose, unique weapon silhouette and palette" % key, errors)


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
		_expect(is_equal_approx(timeline.get_animation(&"ultimate").length, float((package.get("timing_seconds", {}) as Dictionary).get("cancel", -1.0))), "%s animation length must end on its cancel phase" % weapon_id, errors)
	_expect(str(instance.get_meta("ultimate_id", "")) == "dark_mage/%s" % weapon_id, "%s scene must retain its exact profile key" % weapon_id, errors)
	for key in ["silhouette", "motion_path", "timing_rhythm", "impact_language"]:
		_expect(not str(instance.get_meta(key, "")).is_empty(), "%s %s declaration missing" % [weapon_id, key], errors)
	var visual_nodes := _visual_node_count(instance)
	var max_visual_nodes := int(instance.get_meta("max_visual_nodes", 0))
	var crowd_cap := int(instance.get_meta("crowd_cap", 0))
	_expect(visual_nodes <= max_visual_nodes, "%s visual-node count %d exceeds declared maximum %d" % [weapon_id, visual_nodes, max_visual_nodes], errors)
	_expect(max_visual_nodes <= crowd_cap, "%s declared visual maximum must stay within crowd cap" % weapon_id, errors)
	var performance := package.get("performance", {}) as Dictionary
	_expect(max_visual_nodes == int(performance.get("max_visual_nodes", -1)), "%s scene and manifest visual budgets must agree" % weapon_id, errors)
	_expect(crowd_cap == int(performance.get("crowd_cap", -1)), "%s scene and manifest crowd caps must agree" % weapon_id, errors)
	_expect(int(instance.get_meta("max_unique_materials", 0)) == int(performance.get("max_unique_materials", -1))
		and int(instance.get_meta("max_fullscreen_materials", 0)) == int(performance.get("max_fullscreen_materials", -1)),
		"%s scene and manifest material budgets must agree" % weapon_id, errors)
	_expect(DirectionContract.scene_material_violations(instance, "dark_mage/%s" % weapon_id).is_empty(),
		"%s scene must fit its declared V2 material budget" % weapon_id, errors)
	instance.queue_free()


func _check_lifecycle(weapon_id: String, timing: Dictionary, phases: Dictionary, errors: Array[String]) -> void:
	var phase_entries: Array[Dictionary] = []
	for name in REQUIRED_PHASES:
		phase_entries.append({"name": name, "phase_id": str(phases.get(name, ""))})
	var fixture := {"timing": timing, "phases": phase_entries}
	var timeline = TIMELINE.new(fixture, 0)
	var handles := {"animation": HandleProbe.new(), "vfx": HandleProbe.new(), "sfx": HandleProbe.new()}
	var begun := timeline.begin(handles)
	_expect(str(begun.get("state", "")) == "active" and timeline.active_handle_count() == 3, "%s begin must own the three supplied handles" % weapon_id, errors)
	var initial_events := timeline.advance(0.05)
	var paused_time := timeline.elapsed_seconds()
	timeline.set_paused(true)
	timeline.advance(1.0)
	_expect(is_equal_approx(timeline.elapsed_seconds(), paused_time), "%s pause must freeze elapsed time" % weapon_id, errors)
	timeline.set_paused(false)
	var events := timeline.advance(MAX_TIMELINE_SECONDS)
	_expect(initial_events.size() + events.size() == REQUIRED_PHASES.size(), "%s must emit all five presentation phases" % weapon_id, errors)
	for reason in ["cancel", "death", "node_end"]:
		var cleanup_timeline = TIMELINE.new(fixture, 0)
		var cleanup_handles := {"animation": HandleProbe.new(), "vfx": HandleProbe.new(), "sfx": HandleProbe.new()}
		cleanup_timeline.begin(cleanup_handles)
		cleanup_timeline.finish(reason)
		_expect(cleanup_timeline.active_handle_count() == 0, "%s %s cleanup must release all handles" % [weapon_id, reason], errors)
		for handle in cleanup_handles.values():
			_expect((handle as HandleProbe).released == 1, "%s %s cleanup must release each handle exactly once" % [weapon_id, reason], errors)
	var headless_timeline = TIMELINE.new(fixture, 1)
	var headless_result := headless_timeline.begin(handles)
	_expect(str(headless_result.get("state", "")) == "headless_no_op" and headless_timeline.active_handle_count() == 0, "%s headless fallback must attach no handle" % weapon_id, errors)


func _check_distinction(packages: Dictionary, errors: Array[String]) -> void:
	for field in ["silhouette", "motion_path", "timing_rhythm", "impact_language"]:
		var values := {}
		for weapon_id in WEAPON_IDS:
			values[str((packages.get(weapon_id, {}) as Dictionary).get(field, ""))] = true
		_expect(values.size() == 3 and not values.has(""), "all three weapons must have different %s values" % field, errors)
	var timing_signatures := {}
	for weapon_id in WEAPON_IDS:
		var timing := (packages.get(weapon_id, {}) as Dictionary).get("timing_seconds", {}) as Dictionary
		var signature := PackedStringArray()
		for phase_name in REQUIRED_PHASES:
			signature.append("%.2f" % float(timing.get(phase_name, -1.0)))
		timing_signatures["/".join(signature)] = true
	_expect(timing_signatures.size() == 3, "all three weapons must have different timing rhythms", errors)


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
			_expect(bounds.has_area(), "%s capture must expose visible content bounds" % context, errors)
			_expect(content_zone.grow(0.5).encloses(bounds), "%s capture content %s must stay inside panel content zone %s" % [context, bounds, content_zone], errors)
			for raw_node_path in pack.get("required_nodes", []) as Array:
				var node_path := str(raw_node_path)
				var item := scene.get_node_or_null(node_path) as CanvasItem
				_expect(item != null, "%s required capture node missing: %s" % [context, node_path], errors)
				if item == null:
					continue
				_expect(is_capture_item_visible(item, scene), "%s required capture node must be visible: %s" % [context, node_path], errors)
				var item_bounds := capture_item_bounds(scene, item)
				var placed_item_bounds := transformed_capture_bounds(item_bounds, scene)
				_expect(placed_item_bounds.has_area(), "%s required capture node must have bounds: %s" % [context, node_path], errors)
				_expect(content_zone.grow(0.5).encloses(placed_item_bounds), "%s %s bounds %s must stay inside panel content zone %s" % [context, node_path, placed_item_bounds, content_zone], errors)
			scene.queue_free()


func _check_capture_evidence(errors: Array[String]) -> void:
	for raw_capture in CAPTURES:
		var capture := raw_capture as Dictionary
		var path := str(capture.get("path", ""))
		_expect(FileAccess.file_exists(path), "contact evidence is missing: %s" % path, errors)
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


static func panel_content_rect(size: Vector2i, pack: Dictionary) -> Rect2:
	var panel := panel_rect(size, pack)
	var center := panel_center(size, pack)
	var margin := float(size.y) * PANEL_CONTENT_MARGIN_RATIO
	var content_position := panel.position + Vector2.ONE * margin
	var label_y := center.y + float(size.y) * PANEL_LABEL_Y_RATIO
	return Rect2(content_position, Vector2(panel.size.x - margin * 2.0, label_y - margin - content_position.y))


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
	var corners := PackedVector2Array([
		transform * local_rect.position,
		transform * Vector2(local_rect.end.x, local_rect.position.y),
		transform * local_rect.end,
		transform * Vector2(local_rect.position.x, local_rect.end.y),
	])
	return _rect_from_points(corners)


static func transformed_capture_bounds(bounds: Rect2, scene: Node2D) -> Rect2:
	if not bounds.has_area():
		return Rect2()
	return Rect2(scene.position + bounds.position * scene.scale, bounds.size * scene.scale)


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


static func _capture_item_local_rect(item: CanvasItem) -> Rect2:
	if item is Sprite2D:
		return (item as Sprite2D).get_rect()
	if item is Line2D:
		var line := item as Line2D
		return _rect_from_points(line.points).grow(line.width * 0.5)
	if item is Polygon2D:
		return _rect_from_points((item as Polygon2D).polygon)
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


func _visual_node_count(scene: Node2D) -> int:
	var count := 0
	var pending: Array[Node] = [scene]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child in node.get_children():
			pending.append(child)
			if child is CanvasItem:
				count += 1
	return count


func _profiles_by_weapon(root_data: Dictionary) -> Dictionary:
	var result := {}
	for raw_profile in root_data.get("profiles", []) as Array:
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


func _file_sha256(path: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(FileAccess.get_file_as_bytes("res://%s" % path))
	return context.finish().hex_encode()


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
		push_error("Dark Mage ultimate timeline: %s" % error)
	quit(1)
