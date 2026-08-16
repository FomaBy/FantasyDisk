extends SceneTree

## Focused contract, lifecycle, distinction, readability, and evidence test for
## FAN-1474's isolated Ranger ultimate presentation package.

const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Schema := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_schema.gd")
const Timeline := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_timeline.gd")
const Pack := preload("res://scenes/vfx/ultimates/ranger/ranger_ultimate_presentation_pack.gd")
const ContactSheet := preload("res://scenes/vfx/ultimates/ranger/ranger_ultimate_contact_sheet.gd")
const TimelineScene := preload("res://scenes/vfx/ultimates/ranger/ranger_ultimate_timeline_scene.gd")

const PROFILE_PATH := "res://data/ultimates/schema/v1/classes/ranger.json"
const MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/ranger/manifest.json"
const CONTACT_SHEET_PATH := "res://docs/design/references/weapon_ultimates/ranger/ranger_ultimate_timelines_contact_sheet.png"
const CONTACT_SHEET_SIZE := Vector2i(4680, 594)
const SCENE_PATHS := {
	Pack.MOON_CROSSBOW: "res://scenes/vfx/ultimates/ranger/RangerMoonCrossbowMoonHunt.tscn",
	Pack.STORM_LONGBOW: "res://scenes/vfx/ultimates/ranger/RangerStormLongbowStormEye.tscn",
	Pack.HUNTER_TRAP: "res://scenes/vfx/ultimates/ranger/RangerHunterTrapGrandTrap.tscn",
}
const PHASE_ORDER: Array[String] = ["windup", "release", "active", "recovery", "cancel"]
const READABILITY_HEIGHTS: Array[int] = [648, 720, 1080, 1440]
const MIN_READABLE_PIXELS := 6.0
const REFERENCE_VIEWPORT_HEIGHT := 1080.0


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
	_expect(manifests.size() == 3, "pack must publish three Ranger manifests", errors)

	_test_schema_contract(manifests, expected_profiles, errors)
	_test_frozen_phase_ids(manifests, errors)
	_test_timeline_distinction(manifests, errors)
	_test_accepted_assets(errors)
	_test_performance_and_readability(errors)
	_test_provenance_and_evidence(errors)
	for weapon_id in Pack.WEAPON_IDS:
		_test_scene_lifecycle(registry, str(weapon_id), errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Ranger ultimate presentation: %s" % error)
		quit(1)
		return
	print("Ranger ultimate presentation passed (3 distinct timelines, frozen phases, lifecycle, budgets, and evidence).")
	quit(0)


func _test_schema_contract(manifests: Dictionary, expected_profiles: Dictionary, errors: Array[String]) -> void:
	var schema := Schema.schema_document()
	var maximum := float(schema.get("max_timeline_seconds", 0.0))
	var catalog: Array = []
	for weapon_id in manifests:
		catalog.append((manifests[weapon_id] as Dictionary).duplicate(true))
	var catalog_errors := Schema.validate_catalog(catalog, expected_profiles)
	_expect(catalog_errors.is_empty(), "Ranger catalog must validate: %s" % ", ".join(catalog_errors), errors)
	for weapon_id in manifests:
		var manifest: Dictionary = manifests[weapon_id]
		var timing: Dictionary = manifest.get("timing", {})
		_expect(_phase_names(manifest) == PHASE_ORDER, "%s must cover the five phase groups in order" % weapon_id, errors)
		_expect(Pack.timeline_seconds(str(weapon_id)) <= maximum, "%s must fit inside the ten-second cap" % weapon_id, errors)
		var previous := -1.0
		for phase_name in PHASE_ORDER:
			var timestamp := float(timing.get(phase_name, -1.0))
			_expect(timestamp >= previous, "%s timing must remain monotonic at %s" % [weapon_id, phase_name], errors)
			previous = timestamp


func _test_frozen_phase_ids(manifests: Dictionary, errors: Array[String]) -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
	if not parsed is Dictionary:
		errors.append("cannot read frozen Ranger profile document")
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
		_expect(poses.size() == PHASE_ORDER.size(), "%s must change its pose across every phase" % weapon_id, errors)


func _test_accepted_assets(errors: Array[String]) -> void:
	var digests := {}
	var aspects: Array[float] = []
	for weapon_id in Pack.WEAPON_IDS:
		var key := str(weapon_id)
		for path in [Pack.element_source_path(key), Pack.element_runtime_path(key)]:
			_expect(FileAccess.file_exists(path), "%s must exist" % path, errors)
		var image := _runtime_image(key)
		if image == null:
			errors.append("%s runtime image must load" % key)
			continue
		var used := image.get_used_rect()
		_expect(used.has_area(), "%s runtime image must not be empty" % key, errors)
		digests[FileAccess.get_sha256(Pack.element_runtime_path(key))] = true
		aspects.append(float(used.size.x) / maxf(float(used.size.y), 1.0))
	_expect(digests.size() == 3, "the three accepted runtime assets must be distinct", errors)
	for first in aspects.size():
		for second in range(first + 1, aspects.size()):
			_expect(absf(aspects[first] - aspects[second]) > 0.04, "accepted silhouettes must not be proportionally identical", errors)


func _test_performance_and_readability(errors: Array[String]) -> void:
	for weapon_id in Pack.WEAPON_IDS:
		var key := str(weapon_id)
		var formation: Dictionary = Pack.weapon_config(key).get("formation", {})
		var count := int(formation.get("count", 0))
		_expect(count > 0 and count <= Pack.MAX_ELEMENTS_PER_ULTIMATE, "%s element count must respect the crowd cap" % key, errors)
		var image := _runtime_image(key)
		if image == null:
			continue
		var smallest_span := INF
		for phase_name in PHASE_ORDER:
			for sample in 5:
				var points := Pack.formation_points(key, phase_name, float(sample) / 4.0)
				_expect(points.size() == count and points.size() <= Pack.MAX_ELEMENTS_PER_ULTIMATE, "%s must keep its bounded formation at %s" % [key, phase_name], errors)
				for point in points:
					if float(point.get("alpha", 0.0)) >= 0.2:
						smallest_span = minf(smallest_span, float(image.get_used_rect().size.y) * float(point.get("scale", 0.0)))
		for height in READABILITY_HEIGHTS:
			var scaled := smallest_span * float(height) / REFERENCE_VIEWPORT_HEIGHT
			_expect(scaled >= MIN_READABLE_PIXELS, "%s must remain readable at %dp (%.1f px)" % [key, height, scaled], errors)


func _test_provenance_and_evidence(errors: Array[String]) -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:
		errors.append("Ranger provenance manifest must parse")
		return
	var manifest := parsed as Dictionary
	_expect(str(manifest.get("class_id", "")) == Pack.CLASS_ID, "provenance manifest must be class-local", errors)
	var provenance := manifest.get("generator_provenance", {}) as Dictionary
	_expect(str(provenance.get("route", "")) == "reused_accepted_weapon_vfx_no_new_raster_generation", "provenance must declare reused accepted assets", errors)
	_expect(str(provenance.get("pixellab_mcp_config_smoke", "")).begins_with("PASS"), "PixelLab config smoke must be recorded as PASS", errors)
	var sources := provenance.get("reused_sources", {}) as Dictionary
	for weapon_id in Pack.WEAPON_IDS:
		var source := sources.get(str(weapon_id), {}) as Dictionary
		_expect(not str(source.get("source_path", "")).is_empty(), "%s source provenance missing" % weapon_id, errors)
		_expect(not str(source.get("runtime_path", "")).is_empty(), "%s runtime provenance missing" % weapon_id, errors)
	var layout := ContactSheet.layout_for_current_assets()
	var layout_errors := layout.get("errors", []) as Array
	_expect(layout_errors.is_empty(), "contact-sheet layout inputs must load: %s" % ", ".join(layout_errors), errors)
	_expect(int(layout.get("sample_count", 0)) == Pack.WEAPON_IDS.size() * PHASE_ORDER.size() * ContactSheet.SAMPLES_PER_PHASE, "contact-sheet bounds must cover every weapon, phase, and sample", errors)
	var violations := ContactSheet.layout_violations(layout)
	_expect(violations.is_empty(), "contact-sheet element bounds must stay inside every content zone: %s" % "; ".join(violations), errors)
	var cell: Vector2i = layout.get("cell", Vector2i.ZERO)
	var sheet := Image.create_empty(cell.x * PHASE_ORDER.size() * ContactSheet.SAMPLES_PER_PHASE, cell.y * Pack.WEAPON_IDS.size(), false, Image.FORMAT_RGBA8)
	var drawn_pixel_violations := ContactSheet.render_formations(sheet, layout)
	_expect(drawn_pixel_violations.is_empty(), "contact-sheet rendered pixels must stay inside every content zone: %s" % "; ".join(drawn_pixel_violations), errors)
	var content_rect := ContactSheet.content_rect_for(Vector2i(2, 1), Vector2i(12, 10))
	_expect(ContactSheet.pixel_content_violation(content_rect, content_rect.position).is_empty(), "contact-sheet rendered-pixel guard must allow a pixel inside its content rect", errors)
	_expect(not ContactSheet.pixel_content_violation(content_rect, Vector2i(content_rect.end.x, content_rect.position.y)).is_empty(), "contact-sheet rendered-pixel guard must reject a pixel outside its content rect", errors)
	_expect(cell * Vector2i(PHASE_ORDER.size() * ContactSheet.SAMPLES_PER_PHASE, Pack.WEAPON_IDS.size()) == CONTACT_SHEET_SIZE, "contact-sheet dimensions must follow the measured layout", errors)
	_expect(FileAccess.file_exists(CONTACT_SHEET_PATH), "contact-sheet evidence must exist", errors)
	if FileAccess.file_exists(CONTACT_SHEET_PATH):
		var contact := Image.load_from_file(CONTACT_SHEET_PATH)
		_expect(contact != null and contact.get_size() == CONTACT_SHEET_SIZE, "contact-sheet evidence dimensions must be stable", errors)


func _test_scene_lifecycle(registry, weapon_id: String, errors: Array[String]) -> void:
	var packed: PackedScene = load(str(SCENE_PATHS.get(weapon_id, "")))
	_expect(packed != null, "%s scene must load" % weapon_id, errors)
	if packed == null:
		return
	var headless_scene := packed.instantiate() as Node2D
	root.add_child(headless_scene)
	var headless: Dictionary = headless_scene.begin(registry, _probes(), 1)
	_expect(str(headless.get("state", "")) == Timeline.HEADLESS_STATE, "%s must use the deterministic headless no-op" % weapon_id, errors)
	headless_scene.free()

	var scene := packed.instantiate() as Node2D
	root.add_child(scene)
	scene.begin(registry, _probes(), 0)
	scene.step(0.20)
	_expect(scene.is_active(), "%s scene must start active" % weapon_id, errors)
	_expect(str(scene.get_meta("ultimate_id", "")) == "%s/%s" % [Pack.CLASS_ID, weapon_id], "%s scene must retain its exact profile key" % weapon_id, errors)
	_expect(scene.get_child_count() <= int(scene.get_meta("crowd_cap", 0)), "%s scene must stay within its crowd cap" % weapon_id, errors)
	var pose_before_pause := _scene_pose(scene)
	scene.set_paused(true)
	scene.step(1.0)
	_expect(_scene_pose(scene) == pose_before_pause, "%s pause must freeze the visible formation" % weapon_id, errors)
	scene.set_paused(false)
	scene.step(0.20)
	_expect(_scene_pose(scene) != pose_before_pause, "%s resume must continue the visible formation" % weapon_id, errors)
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
