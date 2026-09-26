extends SceneTree

## Focused contract, lifecycle, readability, and capture-layout gate for
## FAN-1490's isolated Robot weapon-ultimate presentation package.

const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Schema := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_schema.gd")
const Timeline := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_timeline.gd")
const Pack := preload("res://scenes/vfx/ultimates/robot/robot_ultimate_presentation_pack.gd")
const TimelineScene := preload("res://scenes/vfx/ultimates/robot/robot_ultimate_timeline_scene.gd")
const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")
const DirectionContract := preload("res://scripts/ultimates/presentation/ultimate_visual_direction_contract.gd")

const PROFILE_PATH := "res://data/ultimates/schema/v1/classes/robot.json"
const MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/robot/manifest.json"
const SCENE_PATHS := {
	Pack.MAGNETIC_ANCHOR: "res://scenes/vfx/ultimates/robot/RobotMagneticAnchorSingularity.tscn",
	Pack.HYDRAULIC_PRESS: "res://scenes/vfx/ultimates/robot/RobotHydraulicPressProtocol.tscn",
	Pack.REACTOR_CORE: "res://scenes/vfx/ultimates/robot/RobotReactorCoreRedZone.tscn",
}
const IMPACT_FRAMES := {
	Pack.MAGNETIC_ANCHOR: "res://assets/sprites/effects/robot/magnetic_anchor/magnetic_anchor_spriteframes.tres",
	Pack.HYDRAULIC_PRESS: "res://assets/sprites/effects/robot/hydraulic_press/hydraulic_press_spriteframes.tres",
	Pack.REACTOR_CORE: "res://assets/sprites/effects/robot/reactor_core/reactor_core_spriteframes.tres",
}
const PHASE_ORDER: Array[String] = ["windup", "release", "active", "recovery", "cancel"]
const READABILITY_HEIGHTS: Array[int] = [648, 720, 1080, 1440]
const MIN_READABLE_PIXELS := 6.0
const REFERENCE_VIEWPORT_HEIGHT := 1080.0

const CAPTURES := [
	{"name": "648p", "path": "res://docs/design/references/weapon_ultimates/robot/robot_ultimate_timelines_648p.png", "size": Vector2i(1152, 648)},
	{"name": "720p", "path": "res://docs/design/references/weapon_ultimates/robot/robot_ultimate_timelines_720p.png", "size": Vector2i(1280, 720)},
	{"name": "1080p", "path": "res://docs/design/references/weapon_ultimates/robot/robot_ultimate_timelines_1080p.png", "size": Vector2i(1920, 1080)},
	{"name": "2K", "path": "res://docs/design/references/weapon_ultimates/robot/robot_ultimate_timelines_2k.png", "size": Vector2i(2560, 1440)},
]
const CAPTURE_PACKS := [
	{"weapon_id": Pack.MAGNETIC_ANCHOR, "title": "СИНГУЛЯРНЫЙ ЯКОРЬ / implosion", "position": Vector2(0.18, 0.56), "time": 1.35, "color": Color(0.34, 0.88, 1.0)},
	{"weapon_id": Pack.HYDRAULIC_PRESS, "title": "ПРОТОКОЛ СЖАТИЯ / crush corridor", "position": Vector2(0.50, 0.56), "time": 1.60, "color": Color(0.96, 0.66, 0.30)},
	{"weapon_id": Pack.REACTOR_CORE, "title": "КРАСНАЯ ЗОНА / vent wheel", "position": Vector2(0.82, 0.56), "time": 1.65, "color": Color(1.0, 0.38, 0.22)},
]
const PANEL_HALF_WIDTH_RATIO := 0.145
const PANEL_HALF_HEIGHT_RATIO := 0.30
const PANEL_LABEL_Y_RATIO := 0.235
const PANEL_LABEL_FONT_RATIO := 0.018
const PANEL_CONTENT_MARGIN_RATIO := 0.030
const SHEET_TITLE := "ROBOT WEAPON ULTIMATES — DISTINCT PRESENTATION TIMELINES"
const SHEET_TITLE_Y_RATIO := 0.075
const SHEET_TITLE_FONT_RATIO := 0.036
const SHEET_TEXT_MARGIN := 8.0


class HandleProbe extends RefCounted:
	var released := 0

	func release() -> void:
		released += 1


class VictimProbe extends Node2D:
	var flashes := 0

	func _combat_feedback_enabled() -> bool:
		return true

	func _show_hit_flash() -> void:
		flashes += 1


func _initialize() -> void:
	var errors: Array[String] = []
	var registry = Registry.new(PD.WEAPONS_BY_CLASS)
	_expect(registry.is_valid(), "weapon registry must be valid", errors)
	var manifests := Pack.manifests(registry)
	var expected_profiles := Pack.expected_profiles(registry)
	_expect(manifests.size() == 3, "pack must publish three Robot manifests", errors)

	_test_schema_contract(manifests, expected_profiles, errors)
	_test_frozen_phase_ids(manifests, errors)
	_test_timeline_distinction(manifests, errors)
	_test_assets_and_budgets(errors)
	_test_provenance_and_evidence(errors)
	_test_capture_text(errors)
	_test_victim_impact_source_contract(errors)
	for weapon_id in Pack.WEAPON_IDS:
		_test_scene_lifecycle(registry, str(weapon_id), errors)
		_test_victim_impact(str(weapon_id), errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Robot ultimate presentation: %s" % error)
		quit(1)
		return
	print("Robot ultimate presentation passed (3 distinct timelines, frozen phases, lifecycle, budgets, and capture evidence).")
	quit(0)


func _test_schema_contract(manifests: Dictionary, expected_profiles: Dictionary, errors: Array[String]) -> void:
	var schema := Schema.schema_document()
	var maximum := float(schema.get("max_timeline_seconds", 0.0))
	var catalog: Array = []
	for weapon_id in manifests:
		catalog.append((manifests[weapon_id] as Dictionary).duplicate(true))
	var catalog_errors := Schema.validate_catalog(catalog, expected_profiles)
	_expect(catalog_errors.is_empty(), "Robot catalog must validate: %s" % ", ".join(catalog_errors), errors)
	for weapon_id in manifests:
		var manifest: Dictionary = manifests[weapon_id]
		var timing: Dictionary = manifest.get("timing", {})
		_expect(_phase_names(manifest) == PHASE_ORDER, "%s must cover five phase groups in order" % weapon_id, errors)
		_expect(Pack.timeline_seconds(str(weapon_id)) <= maximum, "%s must fit inside the ten-second cap" % weapon_id, errors)
		var previous := -1.0
		for phase_name in PHASE_ORDER:
			var timestamp := float(timing.get(phase_name, -1.0))
			_expect(timestamp >= previous, "%s timing must remain monotonic at %s" % [weapon_id, phase_name], errors)
			previous = timestamp


func _test_frozen_phase_ids(manifests: Dictionary, errors: Array[String]) -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
	if not parsed is Dictionary:
		errors.append("cannot read frozen Robot profile document")
		return
	var frozen := {}
	for raw_profile in (parsed as Dictionary).get("profiles", []) as Array:
		var profile := raw_profile as Dictionary
		frozen[str(profile.get("weapon_id", ""))] = profile.get("cast_phases", {})
	var bindings := {"windup": "windup", "release": "execute", "active": "active", "recovery": "recover", "cancel": "cleanup"}
	for weapon_id in manifests:
		var key := str(weapon_id)
		var cast_phases: Dictionary = frozen.get(key, {})
		for raw_phase in (manifests[key] as Dictionary).get("phases", []) as Array:
			var phase := raw_phase as Dictionary
			var name := str(phase.get("name", ""))
			_expect(str(phase.get("phase_id", "")) == str(cast_phases.get(str(bindings.get(name, "")), "")), "%s/%s must bind the frozen cast phase" % [key, name], errors)


func _test_timeline_distinction(manifests: Dictionary, errors: Array[String]) -> void:
	var rhythms := {}
	var silhouettes := {}
	var motions := {}
	var impacts := {}
	var formations := {}
	for weapon_id in Pack.WEAPON_IDS:
		var key := str(weapon_id)
		var config := Pack.weapon_config(key)
		rhythms[str((manifests[key] as Dictionary).get("timing", {}))] = true
		silhouettes[str(config.get("silhouette", ""))] = true
		motions[str(config.get("motion", ""))] = true
		impacts[str(config.get("impact", ""))] = true
		formations[str((config.get("formation", {}) as Dictionary).get("kind", ""))] = true
	_expect(rhythms.size() == 3, "all three timing rhythms must differ", errors)
	_expect(silhouettes.size() == 3, "all three silhouettes must differ", errors)
	_expect(motions.size() == 3, "all three motion paths must differ", errors)
	_expect(impacts.size() == 3, "all three impact languages must differ", errors)
	_expect(formations.size() == 3, "all three formation kinds must differ", errors)
	for phase_name in PHASE_ORDER:
		for sample in 5:
			var signatures := {}
			for weapon_id in Pack.WEAPON_IDS:
				signatures[_motion_signature(str(weapon_id), phase_name, float(sample) / 4.0)] = true
			_expect(signatures.size() == 3, "motion paths must differ at %s sample %d" % [phase_name, sample], errors)
	for weapon_id in Pack.WEAPON_IDS:
		var poses := {}
		for phase_name in PHASE_ORDER:
			poses[_motion_signature(str(weapon_id), phase_name, 0.5)] = true
		_expect(poses.size() == PHASE_ORDER.size(), "%s must change pose across every phase" % weapon_id, errors)


func _test_assets_and_budgets(errors: Array[String]) -> void:
	var digests := {}
	for weapon_id in Pack.WEAPON_IDS:
		var key := str(weapon_id)
		for path in [Pack.element_source_path(key), Pack.element_runtime_path(key)]:
			_expect(FileAccess.file_exists(path), "%s must exist" % path, errors)
		var image := _runtime_image(key)
		if image == null:
			errors.append("%s runtime image must load" % key)
			continue
		_expect(image.get_used_rect().has_area(), "%s runtime image must not be empty" % key, errors)
		digests[FileAccess.get_sha256(Pack.element_runtime_path(key))] = true
		var formation: Dictionary = Pack.weapon_config(key).get("formation", {})
		var count := int(formation.get("count", 0))
		_expect(count > 0 and count <= Pack.MAX_ELEMENTS_PER_ULTIMATE, "%s element count must respect the crowd cap" % key, errors)
		var smallest_span := INF
		for phase_name in PHASE_ORDER:
			for sample in 5:
				var points := Pack.formation_points(key, phase_name, float(sample) / 4.0)
				_expect(points.size() == count and points.size() <= Pack.MAX_ELEMENTS_PER_ULTIMATE, "%s must retain a bounded formation at %s" % [key, phase_name], errors)
				for point in points:
					if float(point.get("alpha", 0.0)) >= 0.2:
						smallest_span = minf(smallest_span, float(image.get_used_rect().size.y) * float(point.get("scale", 0.0)))
		for height in READABILITY_HEIGHTS:
			var scaled := smallest_span * float(height) / REFERENCE_VIEWPORT_HEIGHT
			_expect(scaled >= MIN_READABLE_PIXELS, "%s must remain readable at %dp (%.1f px)" % [key, height, scaled], errors)
	_expect(digests.size() == 3, "the three accepted runtime assets must be distinct", errors)


func _test_provenance_and_evidence(errors: Array[String]) -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:
		errors.append("Robot provenance manifest must parse")
		return
	var manifest := parsed as Dictionary
	_expect(str(manifest.get("class_id", "")) == Pack.CLASS_ID, "provenance manifest must be class-local", errors)
	var provenance := manifest.get("generator_provenance", {}) as Dictionary
	_expect(str(provenance.get("route", "")) == "reused_accepted_weapon_vfx_no_new_raster_generation", "provenance must declare reused accepted assets", errors)
	_expect((provenance.get("new_pixellab_assets", null) is Array) and (provenance.get("new_pixellab_assets") as Array).is_empty(), "provenance must record no new PixelLab generation", errors)
	var sources := provenance.get("reused_sources", {}) as Dictionary
	for weapon_id in Pack.WEAPON_IDS:
		var source := sources.get(str(weapon_id), {}) as Dictionary
		_expect(not str(source.get("pixellab_source_object_id", "")).is_empty(), "%s PixelLab source ID must be recorded" % weapon_id, errors)
		_expect(FileAccess.file_exists("res://%s" % str(source.get("source_path", ""))), "%s reused source must exist" % weapon_id, errors)
		_expect(FileAccess.file_exists("res://%s" % str(source.get("runtime_path", ""))), "%s runtime asset must exist" % weapon_id, errors)
		_expect(FileAccess.file_exists("res://%s" % str(source.get("source_manifest", ""))), "%s source manifest must exist" % weapon_id, errors)
	for raw_capture in CAPTURES:
		var capture := raw_capture as Dictionary
		var path := str(capture.get("path", ""))
		_expect(FileAccess.file_exists(path), "contact evidence is missing: %s" % path, errors)
		if FileAccess.file_exists(path):
			var image := Image.load_from_file(path)
			_expect(image != null and image.get_size() == capture.get("size", Vector2i.ZERO), "contact evidence size mismatch: %s" % path, errors)


func _test_capture_text(errors: Array[String]) -> void:
	for raw_capture in CAPTURES:
		var capture := raw_capture as Dictionary
		var size := capture.get("size", Vector2i.ZERO) as Vector2i
		var sheet_zone := Rect2(Vector2.ZERO, Vector2(size)).grow(-SHEET_TEXT_MARGIN)
		_expect(sheet_zone.encloses(sheet_title_rect(size)), "%s sheet title bounds must stay inside the sheet" % str(capture.get("name", "")), errors)
		for raw_pack in CAPTURE_PACKS:
			var pack := raw_pack as Dictionary
			_expect(panel_rect(size, pack).grow(0.5).encloses(panel_label_rect(size, pack)), "%s panel label must stay inside its panel" % str(pack.get("weapon_id", "")), errors)


func _test_scene_lifecycle(registry, weapon_id: String, errors: Array[String]) -> void:
	var packed: PackedScene = load(str(SCENE_PATHS.get(weapon_id, "")))
	_expect(packed != null, "%s scene must load" % weapon_id, errors)
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
	scene.step(0.20)
	_expect(scene.is_active(), "%s scene must start active" % weapon_id, errors)
	_expect(str(scene.get_meta("ultimate_id", "")) == "%s/%s" % [Pack.CLASS_ID, weapon_id], "%s scene must retain its exact profile key" % weapon_id, errors)
	_expect(scene.get_child_count() <= int(scene.get_meta("crowd_cap", 0)), "%s scene must stay within crowd cap" % weapon_id, errors)
	var pose_before_pause := _scene_pose(scene)
	scene.set_paused(true)
	scene.step(1.0)
	_expect(_scene_pose(scene) == pose_before_pause, "%s pause must freeze visible formation" % weapon_id, errors)
	scene.set_paused(false)
	scene.step(0.20)
	_expect(_scene_pose(scene) != pose_before_pause, "%s resume must continue visible formation" % weapon_id, errors)
	scene.free()

	for reason in TimelineScene.CLEANUP_REASONS:
		var cleanup_scene := packed.instantiate() as Node2D
		root.add_child(cleanup_scene)
		var probes := _probes()
		cleanup_scene.begin(registry, probes, 0)
		cleanup_scene.step(0.30)
		var snapshot: Dictionary = cleanup_scene.finish(str(reason))
		_expect(int(snapshot.get("active_handle_count", -1)) == 0, "%s %s must release all handles" % [weapon_id, reason], errors)
		for handle in probes.values():
			_expect((handle as HandleProbe).released == 1, "%s %s must release each handle exactly once" % [weapon_id, reason], errors)
		cleanup_scene.free()

	var teardown_scene := packed.instantiate() as Node2D
	root.add_child(teardown_scene)
	var teardown_probes := _probes()
	teardown_scene.begin(registry, teardown_probes, 0)
	teardown_scene.step(0.30)
	teardown_scene.free()
	for handle in teardown_probes.values():
		_expect((handle as HandleProbe).released == 1, "%s node teardown must release each handle" % weapon_id, errors)


func _test_victim_impact(weapon_id: String, errors: Array[String]) -> void:
	var packed: PackedScene = load(str(SCENE_PATHS.get(weapon_id, "")))
	_expect(packed != null, "%s impact scene must load" % weapon_id, errors)
	if packed == null:
		return
	var scene := packed.instantiate() as Node2D
	root.add_child(scene)
	_expect(scene.has_method("present"), "%s scene must accept damaging beat payloads" % weapon_id, errors)
	if scene.has_method("present"):
		var victims: Array = []
		for index in 2:
			var victim := VictimProbe.new()
			victim.position = Vector2(30.0 + float(index) * 25.0, 0.0)
			root.add_child(victim)
			victims.append(victim)
		scene.call("present", "%s.impact_probe" % weapon_id, {"victims": victims})
		var impacts := _impact_player(scene) as Node2D
		_expect(impacts != null, "%s must create UltimateVictimImpactPlayer for affected victims" % weapon_id, errors)
		if impacts != null:
			var planned := impacts.call("snapshot") as Dictionary
			_expect(int(planned.get("victims", 0)) == victims.size(), "%s must route every affected victim" % weapon_id, errors)
			impacts.call("advance", 0.0)
			var burst := impacts.find_child("VictimImpact0", true, false) as AnimatedSprite2D
			_expect(burst != null and burst.sprite_frames != null and burst.sprite_frames.resource_path == str(IMPACT_FRAMES.get(weapon_id, "")), "%s must load its Robot-local victim-impact frames" % weapon_id, errors)
			impacts.call("advance", 10.0)
			_expect(int((impacts.call("snapshot") as Dictionary).get("flashes", 0)) == victims.size(), "%s must preserve the existing victim flash" % weapon_id, errors)
			scene.call("finish", "cancel")
			var cleaned := impacts.call("snapshot") as Dictionary
			_expect(int(cleaned.get("active", 0)) == 0 and int(cleaned.get("pending", 0)) == 0 and int(cleaned.get("pooled", 0)) == 0, "%s cancel must clear victim impacts" % weapon_id, errors)
		for victim in victims:
			victim.queue_free()
	scene.queue_free()


func _test_victim_impact_source_contract(errors: Array[String]) -> void:
	var weapons: Array[Dictionary] = []
	for weapon_id in Pack.WEAPON_IDS:
		weapons.append({"weapon_id": weapon_id, "scene_path": str(SCENE_PATHS.get(weapon_id, "")).trim_prefix("res://")})
	_expect(DirectionContract.victim_impact_violations_from_sources(Pack.CLASS_ID, weapons).is_empty(), "every canonical Robot weapon must map to UltimateVictimImpactPlayer", errors)

	var root := ProjectSettings.globalize_path("user://fan3883_victim_impact_negative")
	DirAccess.make_dir_recursive_absolute(root.path_join("scripts/ultimates/classes/robot"))
	DirAccess.make_dir_recursive_absolute(root.path_join("scenes/vfx/ultimates/robot"))
	for weapon in weapons:
		var weapon_id := str(weapon.get("weapon_id", ""))
		var scene_path := root.path_join(str(weapon.get("scene_path", "")))
		_write_source_fixture(root.path_join("scripts/ultimates/classes/robot/%s.gd" % weapon_id), "")
		_write_source_fixture(scene_path, "[ext_resource type=\"Script\" path=\"%s\" id=\"1\"]\n" % root.path_join("scenes/vfx/ultimates/robot/robot_ultimate_timeline_scene.gd"))
	_write_source_fixture(root.path_join("scenes/vfx/ultimates/robot/robot_ultimate_timeline_scene.gd"), "extends Node2D\n")
	_expect(DirectionContract.victim_impact_violations_from_sources(Pack.CLASS_ID, weapons, root).size() == Pack.WEAPON_IDS.size(), "removing the Robot mapping must fail every canonical weapon", errors)


func _write_source_fixture(path: String, source: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
	file.close()


func _impact_player(scene: Node) -> Node:
	for child in scene.get_children():
		if child.get_script() == ImpactPlayer:
			return child
	return null


static func panel_center(size: Vector2i, pack: Dictionary) -> Vector2:
	return Vector2(size) * (pack.get("position", Vector2.ZERO) as Vector2)


static func panel_rect(size: Vector2i, pack: Dictionary) -> Rect2:
	var half_size := Vector2(float(size.x) * PANEL_HALF_WIDTH_RATIO, float(size.y) * PANEL_HALF_HEIGHT_RATIO)
	return Rect2(panel_center(size, pack) - half_size, half_size * 2.0)


static func sheet_title_font_size(size: Vector2i) -> int:
	return maxi(18, int(size.y * SHEET_TITLE_FONT_RATIO))


static func sheet_title_rect(size: Vector2i) -> Rect2:
	var text_size := ThemeDB.fallback_font.get_string_size(SHEET_TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, sheet_title_font_size(size))
	return Rect2(Vector2((float(size.x) - text_size.x) * 0.5, float(size.y) * SHEET_TITLE_Y_RATIO), text_size)


static func panel_label_font_size(size: Vector2i) -> int:
	return maxi(12, int(size.y * PANEL_LABEL_FONT_RATIO))


static func panel_label_rect(size: Vector2i, pack: Dictionary) -> Rect2:
	var text_size := ThemeDB.fallback_font.get_string_size(str(pack.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, panel_label_font_size(size))
	return Rect2(panel_center(size, pack) + Vector2(-text_size.x * 0.5, float(size.y) * PANEL_LABEL_Y_RATIO), text_size)


static func panel_content_rect(size: Vector2i, pack: Dictionary) -> Rect2:
	var panel := panel_rect(size, pack)
	var margin := float(size.y) * PANEL_CONTENT_MARGIN_RATIO
	return Rect2(panel.position + Vector2.ONE * margin, panel.size - Vector2.ONE * margin * 2.0)


func _runtime_image(weapon_id: String) -> Image:
	var texture: Texture2D = load(Pack.element_runtime_path(weapon_id))
	return texture.get_image() if texture != null else null


func _motion_signature(weapon_id: String, phase_name: String, progress: float) -> String:
	var parts: Array[String] = []
	for point in Pack.formation_points(weapon_id, phase_name, progress):
		var position: Vector2 = point.get("position", Vector2.ZERO)
		parts.append("%.2f:%.2f:%.2f:%.2f" % [position.x, position.y, float(point.get("scale", 0.0)), float(point.get("alpha", 0.0))])
	return "|".join(parts)


func _scene_pose(scene: Node2D) -> String:
	var parts: Array[String] = []
	for child in scene.get_children():
		var sprite := child as Sprite2D
		if sprite != null:
			parts.append("%.3f:%.3f:%.3f:%.3f" % [sprite.position.x, sprite.position.y, sprite.scale.x, sprite.modulate.a])
	return "|".join(parts)


func _phase_names(manifest: Dictionary) -> Array[String]:
	var names: Array[String] = []
	for raw_phase in manifest.get("phases", []) as Array:
		if raw_phase is Dictionary:
			names.append(str((raw_phase as Dictionary).get("name", "")))
	return names


func _probes() -> Dictionary:
	return {"animation": HandleProbe.new(), "vfx": HandleProbe.new(), "sfx": HandleProbe.new()}


func _expect(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)
