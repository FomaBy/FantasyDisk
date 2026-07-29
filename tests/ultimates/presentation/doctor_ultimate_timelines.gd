extends SceneTree

## Focused contract, lifecycle, visual distinction, readability, and evidence
## gate for FAN-1486's isolated Doctor ultimate presentation package.

const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Schema := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_schema.gd")
const Timeline := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_timeline.gd")
const Pack := preload("res://scenes/vfx/ultimates/doctor/doctor_ultimate_presentation_pack.gd")
const TimelineScene := preload("res://scenes/vfx/ultimates/doctor/doctor_ultimate_timeline_scene.gd")
const TEXT_FIT := preload("res://tests/ultimates/presentation/contact_sheet_text_fit.gd")

const PROFILE_PATH := "res://data/ultimates/schema/v1/classes/doctor.json"
const MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/doctor/manifest.json"
const SCENE_PATHS := {
	Pack.RESTORE_POTION: "res://scenes/vfx/ultimates/doctor/DoctorRestorePotionElixir.tscn",
	Pack.PLAGUE_SYRINGE: "res://scenes/vfx/ultimates/doctor/DoctorPlagueSyringeBlackEpidemic.tscn",
	Pack.BONE_SAW: "res://scenes/vfx/ultimates/doctor/DoctorBoneSawEmergencySurgery.tscn",
}
const PACKS := [
	{
		"weapon_id": Pack.RESTORE_POTION,
		"scene": preload("res://scenes/vfx/ultimates/doctor/DoctorRestorePotionElixir.tscn"),
		"title": "RESTORE POTION — LIFE & DEATH",
		"position": Vector2(0.18, 0.54),
		"color": Color(0.72, 1.0, 0.68),
		"frames": [
			{"phase": "release", "time": 1.35, "required_nodes": ["GiantFlask", "GlassImpact"]},
			{"phase": "active", "time": 3.10, "required_nodes": ["GiantFlask", "OuterPoisonPool", "InnerHealingSpiral", "ShieldCrystal"]},
			{"phase": "recovery", "time": 5.45, "required_nodes": ["OuterPoisonPool", "InnerHealingSpiral", "ShieldCrystal"]},
		],
	},
	{
		"weapon_id": Pack.PLAGUE_SYRINGE,
		"scene": preload("res://scenes/vfx/ultimates/doctor/DoctorPlagueSyringeBlackEpidemic.tscn"),
		"title": "PLAGUE SYRINGE — BLACK EPIDEMIC",
		"position": Vector2(0.50, 0.54),
		"color": Color(0.38, 0.86, 0.32),
		"frames": [
			{"phase": "release", "time": 0.62, "required_nodes": ["OversizedSyringe", "PatientZero"]},
			{"phase": "active", "time": 4.35, "required_nodes": ["OversizedSyringe", "PatientZero", "PlagueVeinsA", "PlagueWaveThree"]},
			{"phase": "recovery", "time": 6.50, "required_nodes": ["MaskVaporBurst", "PlagueVeinsA"]},
		],
	},
	{
		"weapon_id": Pack.BONE_SAW,
		"scene": preload("res://scenes/vfx/ultimates/doctor/DoctorBoneSawEmergencySurgery.tscn"),
		"title": "BONE SAW — EMERGENCY SURGERY",
		"position": Vector2(0.82, 0.54),
		"color": Color(1.0, 0.72, 0.42),
		"frames": [
			{"phase": "release", "time": 0.37, "required_nodes": ["OrbitSaw1", "OrbitSaw2", "OrbitSaw3", "SurgicalOrbitArc"]},
			{"phase": "active", "time": 1.95, "required_nodes": ["OrbitSaw1", "OrbitSaw2", "SurgicalOrbitArc", "MetalSparks", "DrainRibbonGreen"]},
			{"phase": "recovery", "time": 3.40, "required_nodes": ["OrbitSaw1", "OrbitSaw2", "OrbitSaw3", "ShieldStitches"]},
		],
	},
]
const CAPTURES := [
	{"name": "648p", "path": "res://docs/design/references/weapon_ultimates/doctor/doctor_ultimate_timelines_648p.png", "size": Vector2i(1152, 648)},
	{"name": "720p", "path": "res://docs/design/references/weapon_ultimates/doctor/doctor_ultimate_timelines_720p.png", "size": Vector2i(1280, 720)},
	{"name": "1080p", "path": "res://docs/design/references/weapon_ultimates/doctor/doctor_ultimate_timelines_1080p.png", "size": Vector2i(1920, 1080)},
	{"name": "2k", "path": "res://docs/design/references/weapon_ultimates/doctor/doctor_ultimate_timelines_2k.png", "size": Vector2i(2560, 1440)},
]
const PHASE_ORDER: Array[String] = ["windup", "release", "active", "recovery", "cancel"]
const PANEL_HALF_WIDTH_RATIO := 0.145
const PANEL_HALF_HEIGHT_RATIO := 0.30
const PANEL_LABEL_Y_RATIO := 0.25
const PANEL_LABEL_FONT_RATIO := 0.019
const PANEL_CONTENT_MARGIN_RATIO := 0.03
const FRAME_GAP_WIDTH_RATIO := 0.004
const FRAME_LABEL_FONT_RATIO := 0.012
const FRAME_CONTENT_MARGIN_RATIO := 0.006
const SHEET_TITLE := "DOCTOR WEAPON ULTIMATES — DISTINCT PRESENTATION TIMELINES"
const SHEET_TITLE_Y_RATIO := 0.075
const SHEET_TITLE_FONT_RATIO := 0.036
const SHEET_TEXT_MARGIN := 8.0
const CAPTURE_ALPHA_EPSILON := 0.01


class HandleProbe extends RefCounted:
	var released := 0

	func release() -> void:
		released += 1


func _initialize() -> void:
	var errors: Array[String] = []
	var registry = Registry.new(PD.WEAPONS_BY_CLASS)
	_expect(registry.is_valid(), "weapon registry must be valid", errors)
	var manifests := Pack.manifests(registry)
	var expected_profiles := Pack.expected_profiles(registry)
	_expect(manifests.size() == 3, "pack must publish three Doctor manifests", errors)

	_check_schema(manifests, expected_profiles, errors)
	_check_frozen_phase_ids(manifests, errors)
	_check_manifest_document(manifests, errors)
	_check_distinction(manifests, errors)
	_check_phase_visuals(errors)
	_check_capture_frames(errors)
	_check_capture_composition(errors)
	_check_capture_text(errors)
	_check_capture_evidence(errors)
	for weapon_id in Pack.WEAPON_IDS:
		_check_scene_lifecycle(registry, str(weapon_id), errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Doctor ultimate timeline: %s" % error)
		quit(1)
		return
	print("Doctor ultimate timelines passed (3 distinct U5 scenes, pause/cleanup, 4-resolution evidence, and crowd budgets).")
	quit(0)


func _check_schema(manifests: Dictionary, expected_profiles: Dictionary, errors: Array[String]) -> void:
	var catalog: Array = []
	for weapon_id in manifests:
		catalog.append((manifests[weapon_id] as Dictionary).duplicate(true))
	var catalog_errors := Schema.validate_catalog(catalog, expected_profiles)
	_expect(catalog_errors.is_empty(), "Doctor catalog must validate: %s" % ", ".join(catalog_errors), errors)
	var maximum := float(Schema.schema_document().get("max_timeline_seconds", 0.0))
	for weapon_id in Pack.WEAPON_IDS:
		var key := str(weapon_id)
		var manifest: Dictionary = manifests.get(key, {})
		var timing: Dictionary = manifest.get("timing", {})
		_expect(_phase_names(manifest) == PHASE_ORDER, "%s must expose U5 phases in order" % key, errors)
		_expect(Pack.timeline_seconds(key) <= maximum, "%s must fit the schema timeline cap" % key, errors)
		var previous := -1.0
		for phase_name in PHASE_ORDER:
			var timestamp := float(timing.get(phase_name, -1.0))
			_expect(timestamp >= previous, "%s timing must remain monotonic at %s" % [key, phase_name], errors)
			_expect(str(Pack.phase_at(key, timestamp).get("name", "")) == phase_name, "%s visual phase must switch exactly at %s" % [key, phase_name], errors)
			previous = timestamp
		var timeline = Timeline.new(manifest, 0)
		timeline.begin(_probes())
		var events := timeline.advance(Pack.timeline_seconds(key) + 0.01)
		_expect(_event_names(events) == PHASE_ORDER, "%s timeline must emit all five phase windows in order" % key, errors)


func _check_frozen_phase_ids(manifests: Dictionary, errors: Array[String]) -> void:
	var profile_root := _load_json(PROFILE_PATH, errors)
	var profiles := {}
	for raw_profile in profile_root.get("profiles", []) as Array:
		var profile := raw_profile as Dictionary
		profiles[str(profile.get("weapon_id", ""))] = profile
	var bindings := {"windup": "windup", "release": "execute", "active": "active", "recovery": "recover", "cancel": "cleanup"}
	for weapon_id in Pack.WEAPON_IDS:
		var key := str(weapon_id)
		var cast_phases: Dictionary = (profiles.get(key, {}) as Dictionary).get("cast_phases", {})
		for raw_phase in (manifests.get(key, {}) as Dictionary).get("phases", []) as Array:
			var phase := raw_phase as Dictionary
			var name := str(phase.get("name", ""))
			_expect(str(phase.get("phase_id", "")) == str(cast_phases.get(str(bindings.get(name, "")), "")), "%s/%s must retain the frozen Cast phase ID" % [key, name], errors)


func _check_manifest_document(manifests: Dictionary, errors: Array[String]) -> void:
	var document := _load_json(MANIFEST_PATH, errors)
	_expect(str(document.get("class_id", "")) == Pack.CLASS_ID, "manifest must remain Doctor-local", errors)
	var contract := document.get("contract", {}) as Dictionary
	_expect(str(contract.get("headless_fallback", "")) == "no_op", "manifest must document the headless no-op", errors)
	_expect(str(contract.get("runtime_adapter_status", "")).contains("FAN-1541"), "manifest must retain the runtime integration owner", errors)
	_expect(str(contract.get("mechanics_owner", "")) == "FAN-1487", "manifest must keep gameplay with FAN-1487", errors)
	var provenance := document.get("generator_provenance", {}) as Dictionary
	_expect(str(provenance.get("route", "")) == "reused_accepted_doctor_assets_no_new_raster_generation", "provenance must record accepted-asset reuse", errors)
	_expect((provenance.get("new_pixellab_assets", []) as Array).is_empty(), "no new PixelLab assets may be claimed", errors)
	var reused := provenance.get("reused_sources", {}) as Dictionary
	var packages := _packages_by_weapon(document)
	for weapon_id in Pack.WEAPON_IDS:
		var key := str(weapon_id)
		var config := Pack.weapon_config(key)
		var source := reused.get(key, {}) as Dictionary
		for field in ["source_path", "runtime_path", "weapon_path"]:
			var resource_path := "res://%s" % str(source.get(field, ""))
			_expect(FileAccess.file_exists(resource_path), "%s provenance %s must exist" % [key, field], errors)
		var package := packages.get(key, {}) as Dictionary
		_expect((package.get("timing_seconds", {}) as Dictionary) == (manifests.get(key, {}) as Dictionary).get("timing", {}), "%s evidence timing must match the runtime manifest" % key, errors)
		_expect(str(package.get("silhouette", "")) == str(config.get("silhouette", "")), "%s silhouette evidence must match the scene contract" % key, errors)
		_expect(str(package.get("motion_path", "")) == str(config.get("motion", "")), "%s motion evidence must match the scene contract" % key, errors)
		_expect(str(package.get("impact_language", "")) == str(config.get("impact", "")), "%s impact evidence must match the scene contract" % key, errors)
		_expect(int((package.get("performance", {}) as Dictionary).get("max_visual_nodes", -1)) == int(config.get("max_visual_nodes", 0)), "%s visual budget must match the scene" % key, errors)


func _check_distinction(manifests: Dictionary, errors: Array[String]) -> void:
	var rhythms := {}
	var silhouettes := {}
	var motions := {}
	var impacts := {}
	var formations := {}
	for weapon_id in Pack.WEAPON_IDS:
		var key := str(weapon_id)
		var config := Pack.weapon_config(key)
		rhythms[str((manifests.get(key, {}) as Dictionary).get("timing", {}))] = true
		silhouettes[str(config.get("silhouette", ""))] = true
		motions[str(config.get("motion", ""))] = true
		impacts[str(config.get("impact", ""))] = true
		formations[str(config.get("formation", ""))] = true
	_expect(rhythms.size() == 3, "all three timing rhythms must differ", errors)
	_expect(silhouettes.size() == 3, "all three silhouettes must differ", errors)
	_expect(motions.size() == 3, "all three motion paths must differ", errors)
	_expect(impacts.size() == 3, "all three impact languages must differ", errors)
	_expect(formations.size() == 3, "all three formation kinds must differ", errors)


func _check_phase_visuals(errors: Array[String]) -> void:
	for weapon_id in Pack.WEAPON_IDS:
		var key := str(weapon_id)
		var packed: PackedScene = load(str(SCENE_PATHS.get(key, "")))
		_expect(packed != null, "%s scene must load" % key, errors)
		if packed == null:
			continue
		var scene := packed.instantiate() as Node2D
		root.add_child(scene)
		var timing: Dictionary = Pack.weapon_config(key).get("timing", {})
		var signatures := {}
		for index in PHASE_ORDER.size():
			var phase_name := PHASE_ORDER[index]
			var start := float(timing.get(phase_name, 0.0))
			var end := Pack.timeline_seconds(key) if index + 1 == PHASE_ORDER.size() else float(timing.get(PHASE_ORDER[index + 1], start))
			scene.preview_at(lerpf(start, end, 0.5))
			signatures[_scene_pose(scene)] = true
		_expect(signatures.size() == PHASE_ORDER.size(), "%s must have a different visible pose for every U5 phase" % key, errors)
		_expect(scene.get_child_count() == int(Pack.weapon_config(key).get("max_visual_nodes", -1)), "%s must build its declared visual-node count" % key, errors)
		_expect(scene.get_child_count() <= Pack.MAX_VISUAL_NODES, "%s must stay inside the crowd cap" % key, errors)
		scene.free()


func _check_capture_composition(errors: Array[String]) -> void:
	for raw_capture in CAPTURES:
		var capture := raw_capture as Dictionary
		var size := capture.get("size", Vector2i.ZERO) as Vector2i
		for raw_pack in PACKS:
			var pack := raw_pack as Dictionary
			var frames := pack.get("frames", []) as Array
			for frame_index in frames.size():
				var frame := frames[frame_index] as Dictionary
				var scene := (pack["scene"] as PackedScene).instantiate() as Node2D
				root.add_child(scene)
				seek_capture_frame(scene, frame)
				var bounds := layout_capture_scene(scene, size, pack, frame_index)
				var content_zone := frame_content_rect(size, pack, frame_index)
				var context := "%s %s %s" % [str(capture.get("name", "")), str(pack.get("weapon_id", "")), str(frame.get("phase", ""))]
				_expect(bounds.has_area(), "%s frame must expose visible content bounds" % context, errors)
				_expect(content_zone.grow(0.5).encloses(bounds), "%s content %s must stay inside %s" % [context, bounds, content_zone], errors)
				for raw_node_path in frame.get("required_nodes", []) as Array:
					var node_path := str(raw_node_path)
					var item := scene.get_node_or_null(node_path) as CanvasItem
					_expect(item != null, "%s required node missing: %s" % [context, node_path], errors)
					if item == null:
						continue
					_expect(is_capture_item_visible(item, scene), "%s required node must be visible: %s" % [context, node_path], errors)
					var placed := transformed_capture_bounds(capture_item_bounds(scene, item), scene)
					_expect(placed.has_area(), "%s required node must have non-zero bounds: %s" % [context, node_path], errors)
					_expect(content_zone.grow(0.5).encloses(placed), "%s required node must fit: %s" % [context, node_path], errors)
				scene.free()


func _check_capture_frames(errors: Array[String]) -> void:
	for raw_pack in PACKS:
		var pack := raw_pack as Dictionary
		var weapon_id := str(pack.get("weapon_id", ""))
		var frames := pack.get("frames", []) as Array
		_expect(frames.size() >= 3, "%s must capture at least three frames" % weapon_id, errors)
		var phases := {}
		var timing: Dictionary = Pack.weapon_config(weapon_id).get("timing", {})
		for raw_frame in frames:
			var frame := raw_frame as Dictionary
			var phase := str(frame.get("phase", ""))
			var time := float(frame.get("time", -1.0))
			var phase_index := PHASE_ORDER.find(phase)
			var end := float(timing.get(PHASE_ORDER[phase_index + 1], time)) if phase_index >= 0 and phase_index + 1 < PHASE_ORDER.size() else time
			phases[phase] = true
			_expect(phase_index >= 0, "%s capture phase is invalid: %s" % [weapon_id, phase], errors)
			_expect(time > float(timing.get(phase, time)) and time < end, "%s %s frame %.2fs must be strictly inside its phase" % [weapon_id, phase, time], errors)
			_expect(str(Pack.phase_at(weapon_id, time).get("name", "")) == phase, "%s %s frame %.2fs resolves to another phase" % [weapon_id, phase, time], errors)
		for required_phase in ["release", "active", "recovery"]:
			_expect(phases.has(required_phase), "%s must capture a %s frame" % [weapon_id, required_phase], errors)


func _check_capture_text(errors: Array[String]) -> void:
	for raw_capture in CAPTURES:
		var capture := raw_capture as Dictionary
		var size := capture.get("size", Vector2i.ZERO) as Vector2i
		var sheet_zone := Rect2(Vector2.ZERO, Vector2(size)).grow(-SHEET_TEXT_MARGIN)
		var title_rect := sheet_title_rect(size)
		_expect(sheet_zone.encloses(sheet_title_rect(size)), "%s sheet title \"%s\" bounds %s must stay inside sheet %s" % [str(capture.get("name", "")), SHEET_TITLE, title_rect, sheet_zone], errors)
		for raw_pack in PACKS:
			var pack := raw_pack as Dictionary
			var label_rect := panel_label_rect(size, pack)
			var panel := panel_rect(size, pack)
			_expect(panel.grow(0.5).encloses(label_rect), "%s panel label \"%s\" must fit its panel" % [str(capture.get("name", "")), str(pack["title"])], errors)
			var frames := pack.get("frames", []) as Array
			for frame_index in frames.size():
				var frame := frames[frame_index] as Dictionary
				var frame_label := frame_label_rect(size, pack, frame_index)
				_expect(frame_rect(size, pack, frame_index).grow(0.5).encloses(frame_label), "%s %s %s frame label \"%s\" must fit its frame" % [str(capture.get("name", "")), str(pack["weapon_id"]), str(frame["phase"]), frame_label_text(frame)], errors)


func _check_capture_evidence(errors: Array[String]) -> void:
	for raw_capture in CAPTURES:
		var capture := raw_capture as Dictionary
		var resource_path := str(capture.get("path", ""))
		_expect(FileAccess.file_exists(resource_path), "contact evidence is missing: %s" % resource_path, errors)
		if not FileAccess.file_exists(resource_path):
			continue
		var image := Image.load_from_file(resource_path)
		_expect(image != null and not image.is_empty(), "contact evidence must decode: %s" % resource_path, errors)
		if image != null:
			_expect(image.get_size() == capture.get("size", Vector2i.ZERO), "contact evidence resolution mismatch: %s" % resource_path, errors)


func _check_scene_lifecycle(registry, weapon_id: String, errors: Array[String]) -> void:
	var packed: PackedScene = load(str(SCENE_PATHS.get(weapon_id, "")))
	if packed == null:
		return
	var headless_scene := packed.instantiate() as Node2D
	root.add_child(headless_scene)
	var headless: Dictionary = headless_scene.begin(registry, _probes(), 1)
	_expect(str(headless.get("state", "")) == Timeline.HEADLESS_STATE, "%s must use deterministic headless no-op" % weapon_id, errors)
	headless_scene.free()

	var scene := packed.instantiate() as Node2D
	root.add_child(scene)
	scene.begin(registry, _probes(), 0)
	scene.step(0.10)
	_expect(scene.is_active(), "%s must start active" % weapon_id, errors)
	_expect(str(scene.get_meta("ultimate_id", "")) == "%s/%s" % [Pack.CLASS_ID, weapon_id], "%s must retain its exact profile key" % weapon_id, errors)
	var paused_pose := _scene_pose(scene)
	scene.set_paused(true)
	scene.step(1.0)
	_expect(_scene_pose(scene) == paused_pose, "%s pause must freeze the visible timeline" % weapon_id, errors)
	scene.set_paused(false)
	scene.step(0.15)
	_expect(_scene_pose(scene) != paused_pose, "%s resume must continue the visible timeline" % weapon_id, errors)
	scene.free()

	for reason in TimelineScene.CLEANUP_REASONS:
		var cleanup_scene := packed.instantiate() as Node2D
		root.add_child(cleanup_scene)
		var probes := _probes()
		cleanup_scene.begin(registry, probes, 0)
		cleanup_scene.step(0.10)
		var snapshot: Dictionary = cleanup_scene.finish(reason)
		_expect(int(snapshot.get("active_handle_count", -1)) == 0, "%s %s must release all handles" % [weapon_id, reason], errors)
		_expect(cleanup_scene.get_child_count() == 0, "%s %s must clear all visual nodes" % [weapon_id, reason], errors)
		for handle in probes.values():
			_expect((handle as HandleProbe).released == 1, "%s %s must release every handle once" % [weapon_id, reason], errors)
		cleanup_scene.free()

	var teardown_scene := packed.instantiate() as Node2D
	root.add_child(teardown_scene)
	var teardown_probes := _probes()
	teardown_scene.begin(registry, teardown_probes, 0)
	teardown_scene.step(0.10)
	teardown_scene.free()
	for handle in teardown_probes.values():
		_expect((handle as HandleProbe).released == 1, "%s node teardown must release every handle" % weapon_id, errors)


static func panel_center(size: Vector2i, pack: Dictionary) -> Vector2:
	return Vector2(size) * (pack["position"] as Vector2)


static func panel_rect(size: Vector2i, pack: Dictionary) -> Rect2:
	var center := panel_center(size, pack)
	var half_size := Vector2(float(size.x) * PANEL_HALF_WIDTH_RATIO, float(size.y) * PANEL_HALF_HEIGHT_RATIO)
	return Rect2(center - half_size, half_size * 2.0)


static func sheet_title_font_size(size: Vector2i) -> int:
	return TEXT_FIT.scaled_font_size(size, SHEET_TITLE_FONT_RATIO, 18)


static func sheet_title_rect(size: Vector2i) -> Rect2:
	return TEXT_FIT.centered_rect(SHEET_TITLE, size, float(size.y) * SHEET_TITLE_Y_RATIO, sheet_title_font_size(size))


static func panel_label_font_size(size: Vector2i) -> int:
	return TEXT_FIT.scaled_font_size(size, PANEL_LABEL_FONT_RATIO, 11)


static func panel_label_rect(size: Vector2i, pack: Dictionary) -> Rect2:
	var panel := panel_rect(size, pack)
	return TEXT_FIT.centered_in_rect(str(pack["title"]), panel, panel.position.y + panel.size.y * 0.90, panel_label_font_size(size))


static func panel_content_rect(size: Vector2i, pack: Dictionary) -> Rect2:
	var panel := panel_rect(size, pack)
	var margin := float(size.y) * PANEL_CONTENT_MARGIN_RATIO
	var label := panel_label_rect(size, pack)
	return Rect2(panel.position + Vector2.ONE * margin, Vector2(panel.size.x - margin * 2.0, label.position.y - margin - panel.position.y))


static func frame_rect(size: Vector2i, pack: Dictionary, frame_index: int) -> Rect2:
	var content := panel_content_rect(size, pack)
	var count := maxi(1, (pack.get("frames", []) as Array).size())
	var gap := float(size.x) * FRAME_GAP_WIDTH_RATIO
	var width := (content.size.x - gap * float(count - 1)) / float(count)
	return Rect2(content.position + Vector2(float(frame_index) * (width + gap), 0.0), Vector2(width, content.size.y))


static func frame_label_font_size(size: Vector2i) -> int:
	return TEXT_FIT.scaled_font_size(size, FRAME_LABEL_FONT_RATIO, 8)


static func frame_label_text(frame: Dictionary) -> String:
	return "%s %.2fs" % [str(frame.get("phase", "")).to_upper(), float(frame.get("time", 0.0))]


static func frame_label_rect(size: Vector2i, pack: Dictionary, frame_index: int) -> Rect2:
	var frame := frame_rect(size, pack, frame_index)
	var spec := (pack.get("frames", []) as Array)[frame_index] as Dictionary
	var margin := maxf(2.0, float(size.y) * FRAME_CONTENT_MARGIN_RATIO)
	return TEXT_FIT.centered_in_rect(frame_label_text(spec), frame, frame.position.y + margin, frame_label_font_size(size))


static func frame_content_rect(size: Vector2i, pack: Dictionary, frame_index: int) -> Rect2:
	var frame := frame_rect(size, pack, frame_index)
	var label := frame_label_rect(size, pack, frame_index)
	var margin := maxf(2.0, float(size.y) * FRAME_CONTENT_MARGIN_RATIO)
	var position := Vector2(frame.position.x + margin, label.end.y + margin)
	return Rect2(position, frame.end - Vector2(margin, margin) - position)


static func seek_capture_frame(scene: Node2D, frame: Dictionary) -> void:
	scene.preview_at(float(frame.get("time", 0.0)))


static func layout_capture_scene(scene: Node2D, size: Vector2i, pack: Dictionary, frame_index: int) -> Rect2:
	scene.position = Vector2.ZERO
	scene.scale = Vector2.ONE
	var bounds := capture_content_bounds(scene)
	if not bounds.has_area():
		return Rect2()
	var content_zone := frame_content_rect(size, pack, frame_index)
	var base_scale := clampf(float(size.y) / 1040.0, 0.54, 1.28)
	var fit_scale := minf(content_zone.size.x / bounds.size.x, content_zone.size.y / bounds.size.y)
	var applied_scale := minf(base_scale, fit_scale)
	scene.scale = Vector2.ONE * applied_scale
	scene.position = content_zone.get_center() - bounds.get_center() * applied_scale
	return transformed_capture_bounds(bounds, scene)


static func capture_content_bounds(scene: Node2D) -> Rect2:
	var bounds := Rect2()
	var found := false
	for child in scene.get_children():
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


func _scene_pose(scene: Node2D) -> String:
	var parts: Array[String] = []
	for child in scene.get_children():
		if not child is CanvasItem:
			continue
		var item := child as CanvasItem
		var node := child as Node2D
		parts.append("%s:%s:%.2f:%.2f:%.2f:%.2f:%.2f" % [child.name, item.visible, node.position.x, node.position.y, node.scale.x, node.rotation, item.modulate.a])
	return "|".join(parts)


func _phase_names(manifest: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for raw_phase in manifest.get("phases", []) as Array:
		result.append(str((raw_phase as Dictionary).get("name", "")))
	return result


func _event_names(events: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for event in events:
		result.append(str(event.get("name", "")))
	return result


func _packages_by_weapon(document: Dictionary) -> Dictionary:
	var result := {}
	for raw_package in document.get("weapons", []) as Array:
		var package := raw_package as Dictionary
		result[str(package.get("weapon_id", ""))] = package
	return result


func _load_json(resource_path: String, errors: Array[String]) -> Dictionary:
	if not FileAccess.file_exists(resource_path):
		errors.append("missing JSON: %s" % resource_path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(resource_path))
	if not parsed is Dictionary:
		errors.append("invalid JSON: %s" % resource_path)
		return {}
	return parsed as Dictionary


func _probes() -> Dictionary:
	return {"animation": HandleProbe.new(), "vfx": HandleProbe.new(), "sfx": HandleProbe.new()}


func _expect(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)
