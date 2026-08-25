extends SceneTree

## Focused contract test for the engineer weapon ultimate presentation pack.
##
## It proves the three class-local timelines against the frozen shared schema,
## the frozen engineer `cast_phases`, and the timeline lifecycle, and it proves
## that the three ultimates are mechanically distinguishable rather than one
## timeline in three colors.

const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Schema := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_schema.gd")
const Timeline := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_timeline.gd")
const Pack := preload("res://scenes/vfx/ultimates/engineer/engineer_ultimate_presentation_pack.gd")
const TimelineScene := preload("res://scenes/vfx/ultimates/engineer/engineer_ultimate_timeline_scene.gd")
const CaptureSpec := preload("res://tests/ultimates/presentation/engineer_ultimate_capture_spec.gd")

const PROFILE_PATH := "res://data/ultimates/schema/v1/classes/engineer.json"
const MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/engineer/manifest.json"
const SCENE_PATHS := {
	Pack.SENTRY_WRENCH: "res://scenes/vfx/ultimates/engineer/EngineerSentryWrenchUltimate.tscn",
	Pack.REPAIR_DRONE: "res://scenes/vfx/ultimates/engineer/EngineerRepairDroneUltimate.tscn",
	Pack.PRESSURE_MINES: "res://scenes/vfx/ultimates/engineer/EngineerPressureMinesUltimate.tscn",
}
const PHASE_ORDER: Array[String] = ["windup", "release", "active", "recovery", "cancel"]

## Readability floor: the smallest supported viewport is 648p, so a formation
## element must still cover a readable pixel span there.
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
	_expect(manifests.size() == 3, "pack must publish three engineer manifests", errors)

	_test_schema_contract(manifests, expected_profiles, errors)
	_test_frozen_phase_ids(manifests, errors)
	_test_distinct_timelines(manifests, errors)
	_test_distinct_element_frames(errors)
	_test_performance_and_readability(errors)
	_test_animation_pack(errors)
	_test_capture_evidence(errors)
	_test_v2_overlay(registry, errors)
	for weapon_id in Pack.WEAPON_IDS:
		_test_scene_lifecycle(registry, str(weapon_id), errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Engineer ultimate presentation: %s" % error)
		push_error("Engineer ultimate presentation test: %d errors." % errors.size())
		quit(1)
		return
	print("Engineer ultimate presentation pack passed (3 distinct timelines, schema, lifecycle, budgets).")
	quit(0)


## AC2: every timeline validates against the frozen shared schema, covers the
## five phase groups, and fits inside `max_timeline_seconds`.
func _test_schema_contract(manifests: Dictionary, expected_profiles: Dictionary, errors: Array[String]) -> void:
	var schema := Schema.schema_document()
	var maximum := float(schema.get("max_timeline_seconds", 0.0))
	_expect(maximum > 0.0, "shared schema must publish max_timeline_seconds", errors)

	var catalog: Array = []
	for weapon_id in manifests:
		catalog.append((manifests[weapon_id] as Dictionary).duplicate(true))
	var catalog_errors := Schema.validate_catalog(catalog, expected_profiles)
	_expect(
		catalog_errors.is_empty(),
		"engineer catalog must validate: %s" % ", ".join(catalog_errors),
		errors
	)

	for weapon_id in manifests:
		var manifest: Dictionary = manifests[weapon_id]
		var key := str(weapon_id)
		_expect(_phase_names(manifest) == PHASE_ORDER, "%s must cover the five phase groups in order" % key, errors)
		_expect(
			Pack.timeline_seconds(key) <= maximum,
			"%s timeline must fit inside max_timeline_seconds" % key,
			errors
		)
		var timing: Dictionary = manifest.get("timing", {})
		var previous := -1.0
		for phase_name in PHASE_ORDER:
			var value := float(timing.get(phase_name, -1.0))
			_expect(value >= previous, "%s timing must stay monotonic at %s" % [key, phase_name], errors)
			previous = value


## AC2: phase IDs are the exact frozen IDs of the engineer profile document,
## read straight from disk rather than from the code under test.
func _test_frozen_phase_ids(manifests: Dictionary, errors: Array[String]) -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
	if not parsed is Dictionary:
		errors.append("cannot read frozen engineer profile document")
		return
	var frozen := {}
	for raw_profile in (parsed as Dictionary).get("profiles", []) as Array:
		var profile := raw_profile as Dictionary
		frozen[str(profile.get("weapon_id", ""))] = profile.get("cast_phases", {})

	# Presentation phase name -> frozen cast phase key, per the schema bindings.
	var bindings := {
		"windup": "windup",
		"release": "execute",
		"active": "active",
		"recovery": "recover",
		"cancel": "cleanup",
	}
	for weapon_id in manifests:
		var key := str(weapon_id)
		var cast_phases: Dictionary = frozen.get(key, {})
		_expect(not cast_phases.is_empty(), "%s must exist in the frozen profile" % key, errors)
		for raw_phase in (manifests[key] as Dictionary).get("phases", []) as Array:
			var phase := raw_phase as Dictionary
			var name := str(phase.get("name", ""))
			var expected := str(cast_phases.get(str(bindings.get(name, "")), ""))
			_expect(
				str(phase.get("phase_id", "")) == expected,
				"%s/%s must reference frozen phase id %s" % [key, name, expected],
				errors
			)


## AC1: distinct timing rhythm, motion path, and impact language. A colour
## swap or a shared curve would fail here.
func _test_distinct_timelines(manifests: Dictionary, errors: Array[String]) -> void:
	var rhythms := {}
	var sfx_ids := {}
	for weapon_id in manifests:
		var manifest: Dictionary = manifests[weapon_id]
		rhythms[str(manifest.get("timing", {}))] = true
		sfx_ids[str((manifest.get("sfx", {}) as Dictionary).get("source_path", ""))] = true
	_expect(rhythms.size() == 3, "all three timing rhythms must differ", errors)
	_expect(sfx_ids.size() == 3, "all three impact sounds must differ", errors)

	var kinds := {}
	for weapon_id in Pack.WEAPON_IDS:
		var formation: Dictionary = Pack.weapon_config(str(weapon_id)).get("formation", {})
		kinds[str(formation.get("kind", ""))] = true
	_expect(kinds.size() == 3, "all three formation kinds must differ", errors)

	# Sampled motion paths must not coincide at any phase.
	for phase_name in PHASE_ORDER:
		for sample in 5:
			var progress := float(sample) / 4.0
			var signatures := {}
			for weapon_id in Pack.WEAPON_IDS:
				signatures[_motion_signature(str(weapon_id), phase_name, progress)] = true
			_expect(
				signatures.size() == 3,
				"motion paths must differ at %s progress %.2f" % [phase_name, progress],
				errors
			)

	# Each ultimate must actually move between phases rather than hold one pose.
	for weapon_id in Pack.WEAPON_IDS:
		var poses := {}
		for phase_name in PHASE_ORDER:
			poses[_motion_signature(str(weapon_id), phase_name, 0.5)] = true
		_expect(poses.size() == PHASE_ORDER.size(), "%s must change pose every phase" % weapon_id, errors)


## AC1: distinct silhouettes, proven from the committed frames themselves.
func _test_distinct_element_frames(errors: Array[String]) -> void:
	var aspects: Array[float] = []
	var digests := {}
	for weapon_id in Pack.WEAPON_IDS:
		var key := str(weapon_id)
		for path in [Pack.element_source_path(key), Pack.element_runtime_path(key)]:
			_expect(FileAccess.file_exists(path), "missing element frame %s" % path, errors)
		var image := _runtime_image(key)
		if image == null:
			errors.append("%s runtime frame must load" % key)
			continue
		var used := image.get_used_rect()
		_expect(used.size.x > 0 and used.size.y > 0, "%s runtime frame must not be empty" % key, errors)
		aspects.append(float(used.size.x) / maxf(float(used.size.y), 1.0))
		digests[FileAccess.get_sha256(Pack.element_runtime_path(key))] = true
	_expect(digests.size() == 3, "all three runtime frames must be distinct files", errors)
	for first in aspects.size():
		for second in range(first + 1, aspects.size()):
			_expect(
				absf(aspects[first] - aspects[second]) > 0.35,
				"element silhouettes must differ in proportion (%.2f vs %.2f)" % [aspects[first], aspects[second]],
				errors
			)


## AC3: crowd performance caps and 648p..2K readability budgets.
func _test_performance_and_readability(errors: Array[String]) -> void:
	for weapon_id in Pack.WEAPON_IDS:
		var key := str(weapon_id)
		var formation: Dictionary = Pack.weapon_config(key).get("formation", {})
		var count := int(formation.get("count", 0))
		_expect(
			count > 0 and count <= Pack.MAX_ELEMENTS_PER_ULTIMATE,
			"%s element count must respect the crowd cap" % key,
			errors
		)
		var image := _runtime_image(key)
		if image == null:
			continue
		var smallest_span := INF
		var largest_count := 0
		for phase_name in PHASE_ORDER:
			for sample in 5:
				var points := Pack.formation_points(key, phase_name, float(sample) / 4.0)
				_expect(
					points.size() <= Pack.MAX_ELEMENTS_PER_ULTIMATE,
					"%s must never exceed the crowd cap at %s" % [key, phase_name],
					errors
				)
				largest_count = maxi(largest_count, points.size())
				for point in points:
					if float(point.get("alpha", 0.0)) < 0.2:
						continue
					var span := float(image.get_used_rect().size.y) * float(point.get("scale", 0.0))
					smallest_span = minf(smallest_span, span)
		_expect(largest_count == count, "%s must place its whole formation" % key, errors)
		for height in READABILITY_HEIGHTS:
			var scaled := smallest_span * (float(height) / REFERENCE_VIEWPORT_HEIGHT)
			_expect(
				scaled >= MIN_READABLE_PIXELS,
				"%s must stay readable at %dp (%.1f px)" % [key, height, scaled],
				errors
			)


## FAN-2565: the sentry wrench plays a real animation source rather than one
## held frame — every frame is a distinct file on one canvas, the whole pack is
## reachable from the five phases, and the frames carry the clean transparency
## an isolated PixelLab source has to have.
func _test_animation_pack(errors: Array[String]) -> void:
	var pack: Dictionary = Pack.ANIMATION_FRAMES[Pack.SENTRY_WRENCH]
	var paths := Pack.element_frame_paths(Pack.SENTRY_WRENCH)
	var expected := int(pack.get("count", 0))
	_expect(paths.size() == expected, "sentry wrench must publish %d animation frames" % expected, errors)

	var digests := {}
	var canvas := Vector2i.ZERO
	for index in paths.size():
		var path := paths[index]
		var source := "%s%s" % [str(pack.get("source_directory", "")), str(pack.get("source_prefix", "")) % index]
		_expect(FileAccess.file_exists(path), "missing animation frame %s" % path, errors)
		_expect(FileAccess.file_exists(source), "missing PixelLab source frame %s" % source, errors)
		digests[FileAccess.get_sha256(path)] = true
		var texture: Texture2D = load(path)
		if texture == null:
			errors.append("animation frame must import: %s" % path)
			continue
		var image := texture.get_image()
		if canvas == Vector2i.ZERO:
			canvas = image.get_size()
		_expect(image.get_size() == canvas, "every animation frame shares one canvas: %s" % path, errors)
		var used := image.get_used_rect()
		_expect(
			used.position.x > 0 and used.position.y >= 0 and used.end.x < canvas.x and used.end.y <= canvas.y,
			"animation frame must not touch the canvas edge: %s" % path,
			errors
		)
		_expect(_semi_transparent_pixels(image) == 0, "animation frame must keep binary alpha: %s" % path, errors)
	_expect(digests.size() == paths.size(), "every animation frame must be a distinct file", errors)

	# Each phase names a frame, and the five phases together play the whole pack.
	var reached := {}
	for phase_name in PHASE_ORDER:
		for sample in 33:
			var index := Pack.frame_index(Pack.SENTRY_WRENCH, phase_name, float(sample) / 32.0)
			_expect(index >= 0 and index < paths.size(), "%s frame index %d is out of range" % [phase_name, index], errors)
			reached[index] = true
	_expect(reached.size() == paths.size(), "the five phases must play all %d frames, reached %d" % [paths.size(), reached.size()], errors)
	_expect(
		Pack.frame_index(Pack.SENTRY_WRENCH, "windup", 0.0) != Pack.frame_index(Pack.SENTRY_WRENCH, "recovery", 0.0),
		"windup and recovery must not show the same frame",
		errors
	)
	for weapon_id in [Pack.REPAIR_DRONE, Pack.PRESSURE_MINES]:
		_expect(
			Pack.element_frame_paths(str(weapon_id)).size() == 1,
			"%s must keep its single forged element frame" % weapon_id,
			errors
		)


## AC: the four supported live-capture viewports are committed, declared by the
## manifest, and each file really is the viewport it claims.
func _test_capture_evidence(errors: Array[String]) -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:
		errors.append("cannot read the engineer reference manifest")
		return
	var evidence: Dictionary = (parsed as Dictionary).get("evidence", {})
	var declared: Array = evidence.get("contact_sheets", [])
	_expect(
		str(evidence.get("capture_script", "")) == "tests/ultimates/presentation/engineer_ultimate_contact_capture.gd",
		"manifest must name the live capture script",
		errors
	)
	_expect(declared.size() == CaptureSpec.CAPTURES.size(), "manifest must declare every capture viewport", errors)
	for raw_capture in CaptureSpec.CAPTURES:
		var capture := raw_capture as Dictionary
		var path := str(capture["path"])
		var size := capture["size"] as Vector2i
		_expect(declared.has(path.trim_prefix("res://")), "manifest must declare %s" % path, errors)
		if not FileAccess.file_exists(path):
			errors.append("missing live capture %s" % path)
			continue
		var image := Image.load_from_file(path)
		_expect(
			image != null and image.get_size() == size,
			"%s must be captured at %dx%d" % [path, size.x, size.y],
			errors
		)


## FAN-2960: the sentry wrench is the first v2 pair — its scene builds the
## declared full-screen layers, they follow the timeline as pure functions, and
## every cleanup reason frees them together with the formation sprites.
func _test_v2_overlay(registry, errors: Array[String]) -> void:
	var packed: PackedScene = load(str(SCENE_PATHS.get(Pack.SENTRY_WRENCH, "")))
	var scene := packed.instantiate() as Node2D
	root.add_child(scene)
	scene.begin(registry, _probes(), 0)
	for node_name in ["BackdropDim", "WrenchSigil", "CrossfireChord0", "CrossfireChord1", "CrossfireChord2"]:
		_expect(scene.get_node_or_null(node_name) != null, "sentry v2 scene must build %s" % node_name, errors)
	for node_name in ["BackdropDim", "CrossfireChord0", "CrossfireChord1", "CrossfireChord2"]:
		var layer := scene.get_node_or_null(node_name) as Sprite2D
		_expect(
			layer != null and bool(layer.get_meta("fullscreen_layer", false)),
			"%s must be excluded from capture bounds and scene poses" % node_name,
			errors
		)
	_expect(
		_live_canvas_items(scene) == 11,
		"sentry v2 scene must own 11 drawing nodes (6 pylons + 5 overlay), got %d" % _live_canvas_items(scene),
		errors
	)

	var backdrop := scene.get_node_or_null("BackdropDim") as Sprite2D
	var sigil := scene.get_node_or_null("WrenchSigil") as Sprite2D
	_expect(backdrop != null and sigil != null, "sentry v2 scene must expose a Sprite2D backdrop and sigil", errors)
	if backdrop != null and sigil != null:
		scene.step(0.45)
		var windup_alpha := backdrop.modulate.a
		_expect(windup_alpha > 0.0, "backdrop must dim in during the cast ceremony", errors)
		scene.step(0.60)
		_expect(backdrop.modulate.a > windup_alpha, "backdrop must hold its release peak", errors)
		_expect(sigil.visible and sigil.modulate.a > 0.9, "wrench sigil must lead the release", errors)

	# Repeated activation rebuilds the layers instead of stacking them.
	scene.begin(registry, _probes(), 0)
	_expect(
		_live_canvas_items(scene) == 11,
		"repeated activation must rebuild the v2 layers, got %d" % _live_canvas_items(scene),
		errors
	)
	scene.free()

	for reason in TimelineScene.CLEANUP_REASONS:
		var cleanup_scene := packed.instantiate() as Node2D
		root.add_child(cleanup_scene)
		cleanup_scene.begin(registry, _probes(), 0)
		cleanup_scene.step(2.0)
		cleanup_scene.finish(str(reason))
		_expect(
			_live_canvas_items(cleanup_scene) == 0,
			"%s must free every v2 overlay with the sprites" % reason,
			errors
		)
		cleanup_scene.free()

	# The two v1 siblings keep their exact scene shape until their own cards.
	for weapon_id in [Pack.REPAIR_DRONE, Pack.PRESSURE_MINES]:
		var sibling := (load(str(SCENE_PATHS.get(str(weapon_id), ""))) as PackedScene).instantiate() as Node2D
		root.add_child(sibling)
		sibling.begin(registry, _probes(), 0)
		_expect(sibling.get_node_or_null("BackdropDim") == null, "%s must not gain v2 overlay nodes" % weapon_id, errors)
		sibling.free()


## Children that would still draw: not yet queued for deletion.
func _live_canvas_items(scene: Node2D) -> int:
	var count := 0
	for child in scene.get_children():
		var item := child as CanvasItem
		if item != null and not item.is_queued_for_deletion():
			count += 1
	return count


func _semi_transparent_pixels(image: Image) -> int:
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			var alpha := image.get_pixel(x, y).a
			if alpha > 0.0 and alpha < 1.0:
				count += 1
	return count


## AC3: pause freezes the timeline and every cleanup reason releases handles
## and sprites, driven through the shipped scene rather than a stand-in.
func _test_scene_lifecycle(registry, weapon_id: String, errors: Array[String]) -> void:
	var packed: PackedScene = load(str(SCENE_PATHS.get(weapon_id, "")))
	if packed == null:
		errors.append("%s scene must load" % weapon_id)
		return

	var headless_scene := packed.instantiate() as Node2D
	root.add_child(headless_scene)
	var headless_probes := _probes()
	var headless_snapshot: Dictionary = headless_scene.begin(registry, headless_probes, 1)
	_expect(
		str(headless_snapshot.get("state", "")) == Timeline.HEADLESS_STATE,
		"%s must fall back to the headless no-op" % weapon_id,
		errors
	)
	_expect(
		int(headless_snapshot.get("active_handle_count", -1)) == 0,
		"%s headless no-op must attach no handles" % weapon_id,
		errors
	)
	headless_scene.free()

	var scene := packed.instantiate() as Node2D
	root.add_child(scene)
	_expect(str(scene.weapon_id) == weapon_id, "%s scene must carry its weapon id" % weapon_id, errors)
	scene.begin(registry, _probes(), 0)
	_expect(scene.is_active(), "%s scene must start active" % weapon_id, errors)
	scene.step(0.20)
	_expect(scene.get_child_count() > 0, "%s scene must place formation sprites" % weapon_id, errors)
	var pose_before_pause := _scene_pose(scene)
	scene.set_paused(true)
	scene.step(1.00)
	_expect(_scene_pose(scene) == pose_before_pause, "%s pause must freeze the formation" % weapon_id, errors)
	scene.set_paused(false)
	scene.step(0.20)
	_expect(_scene_pose(scene) != pose_before_pause, "%s resume must continue the formation" % weapon_id, errors)
	scene.free()

	for reason in TimelineScene.CLEANUP_REASONS:
		var cleanup_scene := packed.instantiate() as Node2D
		root.add_child(cleanup_scene)
		var probes := _probes()
		cleanup_scene.begin(registry, probes, 0)
		cleanup_scene.step(0.30)
		var snapshot: Dictionary = cleanup_scene.finish(str(reason))
		_expect(
			int(snapshot.get("active_handle_count", -1)) == 0,
			"%s %s must release every handle" % [weapon_id, reason],
			errors
		)
		for channel in probes:
			_expect(
				(probes[channel] as HandleProbe).released == 1,
				"%s %s must release the %s handle exactly once" % [weapon_id, reason, channel],
				errors
			)
		_expect(not cleanup_scene.is_active(), "%s %s must leave the scene inactive" % [weapon_id, reason], errors)
		cleanup_scene.free()

	# Teardown mid-timeline must not orphan a handle either.
	var teardown_scene := packed.instantiate() as Node2D
	root.add_child(teardown_scene)
	var teardown_probes := _probes()
	teardown_scene.begin(registry, teardown_probes, 0)
	teardown_scene.step(0.30)
	teardown_scene.free()
	for channel in teardown_probes:
		_expect(
			(teardown_probes[channel] as HandleProbe).released == 1,
			"%s node teardown must release the %s handle" % [weapon_id, channel],
			errors
		)


## Read a runtime frame through its imported texture, the way the scene does.
func _runtime_image(weapon_id: String) -> Image:
	var texture: Texture2D = load(Pack.element_runtime_path(weapon_id))
	return texture.get_image() if texture != null else null


## Snapshot every formation sprite the scene currently owns.
func _scene_pose(scene: Node2D) -> String:
	var parts: Array[String] = []
	for child in scene.get_children():
		var sprite := child as Sprite2D
		if sprite == null or bool(sprite.get_meta("fullscreen_layer", false)):
			continue
		parts.append("%.3f:%.3f:%.3f:%.3f" % [
			sprite.position.x,
			sprite.position.y,
			sprite.scale.x,
			sprite.modulate.a,
		])
	return "|".join(parts)


func _motion_signature(weapon_id: String, phase_name: String, progress: float) -> String:
	var parts: Array[String] = []
	for point in Pack.formation_points(weapon_id, phase_name, progress):
		var position: Vector2 = point.get("position", Vector2.ZERO)
		parts.append("%.2f:%.2f:%.2f:%.2f" % [
			position.x,
			position.y,
			float(point.get("scale", 0.0)),
			float(point.get("alpha", 0.0)),
		])
	return "|".join(parts)


func _phase_names(manifest: Dictionary) -> Array[String]:
	var names: Array[String] = []
	for raw_phase in manifest.get("phases", []) as Array:
		if raw_phase is Dictionary:
			names.append(str((raw_phase as Dictionary).get("name", "")))
	return names


func _probes() -> Dictionary:
	return {
		"animation": HandleProbe.new(),
		"vfx": HandleProbe.new(),
		"sfx": HandleProbe.new(),
	}


func _expect(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)
