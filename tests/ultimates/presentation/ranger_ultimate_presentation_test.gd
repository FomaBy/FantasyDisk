extends SceneTree

## Focused contract, lifecycle, distinction, readability, and evidence test for
## FAN-1474's isolated Ranger ultimate presentation package.
##
## FAN-3736 extended it to the Ultimate Direction v2 contract. Every v2 gate the
## trio now claims — envelope, presence, identity, ratchet retirement, class
## manifest parity and the runtime bindings the scenes actually drive — carries a
## mutation-sensitive negative control here, so a gate that stops working turns
## this suite red instead of passing on a declaration alone.

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
	_test_v2_envelope(manifests, errors)
	_test_v2_presence_and_identity(manifests, expected_profiles, errors)
	_test_v2_ratchet_retired(errors)
	_test_class_manifest_parity(errors)
	_test_resolution_distinctness(errors)
	for weapon_id in Pack.WEAPON_IDS:
		_test_scene_lifecycle(registry, str(weapon_id), errors)
		_test_v2_scene_bindings(registry, str(weapon_id), errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Ranger ultimate presentation: %s" % error)
		quit(1)
		return
	print("Ranger ultimate presentation passed (3 distinct v2 timelines, frozen phases, presence/identity gates with negative controls, lifecycle, budgets, and evidence).")
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


## v2 envelope (FAN-2944 §1): 2.5-4.0 s total, a 0.6-1.0 s cast ceremony, at
## least 1.2 s of active presentation and a visible recovery. Each of the four
## ranges gets a mutation that must produce exactly its own code.
func _test_v2_envelope(manifests: Dictionary, errors: Array[String]) -> void:
	for weapon_id in Pack.WEAPON_IDS:
		var key := "%s/%s" % [Pack.CLASS_ID, weapon_id]
		var timing: Dictionary = (manifests[str(weapon_id)] as Dictionary).get("timing", {})
		var envelope_errors := Schema.v2_envelope_errors(timing, key)
		_expect(envelope_errors.is_empty(), "%s must satisfy the v2 envelope: %s" % [key, ", ".join(envelope_errors)], errors)
		var total := float(timing["cancel"]) - float(timing["windup"])
		_expect(total >= 2.5 and total <= 4.0, "%s total presentation is %.2fs" % [key, total], errors)
		_expect(
			float(timing["recovery"]) - float(timing["release"]) >= 1.2,
			"%s must keep at least 1.2s of active presentation" % key,
			errors
		)
		for mutation in [
			{"code": "presentation.v2.total_range", "timing": {"cancel": 6.0}},
			{"code": "presentation.v2.windup_range", "timing": {"release": 0.2}},
			{"code": "presentation.v2.active_window", "timing": {"recovery": float(timing["release"]) + 0.4}},
			{"code": "presentation.v2.recovery_window", "timing": {"cancel": float(timing["recovery"])}},
		]:
			var mutated: Dictionary = timing.duplicate()
			mutated.merge((mutation["timing"] as Dictionary), true)
			_expect_code(
				Schema.v2_envelope_errors(mutated, key),
				str(mutation["code"]),
				"%s envelope mutation must report %s" % [key, mutation["code"]],
				errors
			)


## v2 presence and identity (FAN-2944 §3.1) through the shared schema, with one
## mutation per declared field. Every mutation runs against an empty allowlist,
## so these controls stay red even if the migration ratchet changes again.
func _test_v2_presence_and_identity(manifests: Dictionary, expected_profiles: Dictionary, errors: Array[String]) -> void:
	for weapon_id in Pack.WEAPON_IDS:
		var key := "%s/%s" % [Pack.CLASS_ID, weapon_id]
		var manifest: Dictionary = (manifests[str(weapon_id)] as Dictionary)
		var profiles := {key: expected_profiles[Schema.profile_key(Pack.CLASS_ID, str(weapon_id))]}
		_expect(
			Schema.validate_catalog([manifest.duplicate(true)], profiles, {}).is_empty(),
			"%s must satisfy the full v2 contract outside the migration allowlist: %s"
				% [key, Schema.validate_catalog([manifest.duplicate(true)], profiles, {})],
			errors
		)
		for mutation in [
			{"code": "presentation.v2.presence", "block": "presence", "erase": true},
			{"code": "presentation.v2.footprint", "block": "presence", "field": "fullscreen_footprint", "value": false},
			{"code": "presentation.v2.backdrop", "block": "presence", "field": "backdrop", "value": "none"},
			{"code": "presentation.v2.camera_shake", "block": "presence", "field": "camera_shake", "value": false},
			{"code": "presentation.v2.hitstop", "block": "presence", "field": "hitstop_ms", "value": 40},
			{"code": "presentation.v2.hitstop", "block": "presence", "field": "hitstop_ms", "value": 200},
			{"code": "presentation.v2.time_scale_dip", "block": "presence", "field": "time_scale_dip", "value": 0.9},
			{"code": "presentation.v2.sfx_ducking", "block": "presence", "field": "sfx_ducking", "value": false},
			{"code": "presentation.v2.identity", "block": "identity", "erase": true},
			{"code": "presentation.v2.cast_pose", "block": "identity", "field": "cast_pose_id", "value": ""},
			{"code": "presentation.v2.weapon_silhouette", "block": "identity", "field": "weapon_silhouette_asset", "value": "res://assets/sprites/effects/does_not_exist.png"},
			{"code": "presentation.v2.class_palette", "block": "identity", "field": "class_palette_id", "value": ""},
		]:
			var mutated := manifest.duplicate(true)
			var block := str(mutation["block"])
			if bool(mutation.get("erase", false)):
				mutated.erase(block)
			else:
				(mutated[block] as Dictionary)[str(mutation["field"])] = mutation["value"]
			_expect_code(
				Schema.validate_catalog([mutated], profiles, {}),
				str(mutation["code"]),
				"%s %s mutation must report %s" % [key, block, mutation["code"]],
				errors
			)

	# The weapon silhouette is the visual core per pair: two Ranger weapons
	# sharing one frame is exactly the generic-burst reuse the schema forbids.
	var shared: Array = []
	var shared_profiles := {}
	var silhouette := ""
	for weapon_id in Pack.WEAPON_IDS:
		var key := "%s/%s" % [Pack.CLASS_ID, weapon_id]
		var copy := (manifests[str(weapon_id)] as Dictionary).duplicate(true)
		if silhouette.is_empty():
			silhouette = str((copy["identity"] as Dictionary)["weapon_silhouette_asset"])
		(copy["identity"] as Dictionary)["weapon_silhouette_asset"] = silhouette
		shared.append(copy)
		shared_profiles[key] = expected_profiles[Schema.profile_key(Pack.CLASS_ID, str(weapon_id))]
	_expect_code(
		Schema.validate_catalog(shared, shared_profiles, {}),
		"presentation.v2.generic_burst",
		"a silhouette shared across two Ranger pairs must fail closed",
		errors
	)


## The ratchet only shrinks: a v2-complete trio may not stay on the migration
## allowlist, or the shared catalog test fails it as a stale entry.
func _test_v2_ratchet_retired(errors: Array[String]) -> void:
	for weapon_id in Pack.WEAPON_IDS:
		var key := Schema.profile_key(Pack.CLASS_ID, str(weapon_id))
		_expect(
			not Schema.PRESENTATION_V2_MIGRATION_ALLOWLIST.has(key),
			"%s must have left PRESENTATION_V2_MIGRATION_ALLOWLIST" % key,
			errors
		)


## The class manifest is the single source the shared bridge reads, so its
## timing, presence, identity and budgets must agree with this pack field by
## field. A drifted copy is the negative control.
func _test_class_manifest_parity(errors: Array[String]) -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:
		errors.append("Ranger class manifest must parse")
		return
	var weapons := {}
	for raw_weapon in (parsed as Dictionary).get("weapons", []) as Array:
		weapons[str((raw_weapon as Dictionary).get("weapon_id", ""))] = raw_weapon
	for weapon_id in Pack.WEAPON_IDS:
		var key := str(weapon_id)
		var record: Dictionary = weapons.get(key, {})
		_expect(not record.is_empty(), "class manifest must declare %s" % key, errors)
		if record.is_empty():
			continue
		_expect(_parity_errors(record, key).is_empty(), "class manifest %s: %s" % [key, ", ".join(_parity_errors(record, key))], errors)
		var drifted := record.duplicate(true)
		(drifted["timing_seconds"] as Dictionary)["recovery"] = float((drifted["timing_seconds"] as Dictionary)["recovery"]) + 0.25
		_expect(not _parity_errors(drifted, key).is_empty(), "%s manifest timing drift must fail closed" % key, errors)
		var stripped := record.duplicate(true)
		(stripped["presence"] as Dictionary)["hitstop_ms"] = 40
		_expect(not _parity_errors(stripped, key).is_empty(), "%s manifest presence drift must fail closed" % key, errors)
		var rebudgeted := record.duplicate(true)
		(rebudgeted["performance"] as Dictionary)["max_visual_nodes"] = 1
		_expect(not _parity_errors(rebudgeted, key).is_empty(), "%s manifest budget drift must fail closed" % key, errors)


func _parity_errors(record: Dictionary, weapon_id: String) -> Array[String]:
	var mismatches: Array[String] = []
	var timing: Dictionary = Pack.weapon_config(weapon_id).get("timing", {})
	var declared: Dictionary = record.get("timing_seconds", {}) as Dictionary
	for phase_name in PHASE_ORDER:
		if absf(float(declared.get(phase_name, INF)) - float(timing.get(phase_name, -INF))) > 0.0001:
			mismatches.append("timing_seconds.%s" % phase_name)
	# JSON numbers arrive as floats, so presence is compared field by field
	# rather than as one dictionary literal.
	var presence: Dictionary = record.get("presence", {}) as Dictionary
	var expected_presence := Pack.presence_for(weapon_id)
	for field in expected_presence:
		if not _same_value(presence.get(field), expected_presence[field]):
			mismatches.append("presence.%s" % field)
	var identity: Dictionary = record.get("identity", {}) as Dictionary
	var expected_identity := Pack.identity_for(weapon_id)
	for field in expected_identity:
		if str(identity.get(field, "")) != str(expected_identity[field]):
			mismatches.append("identity.%s" % field)
	var performance: Dictionary = record.get("performance", {}) as Dictionary
	if int(performance.get("max_visual_nodes", 0)) != Pack.max_visual_nodes(weapon_id):
		mismatches.append("performance.max_visual_nodes")
	if int(performance.get("crowd_cap", 0)) != Pack.CROWD_CAP:
		mismatches.append("performance.crowd_cap")
	if int(performance.get("max_unique_materials", 0)) != Pack.MAX_UNIQUE_MATERIALS \
			or int(performance.get("max_fullscreen_materials", 0)) != Pack.MAX_FULLSCREEN_MATERIALS:
		mismatches.append("performance.materials")
	return mismatches


func _same_value(declared: Variant, expected: Variant) -> bool:
	if expected is bool:
		return declared is bool and bool(declared) == bool(expected)
	if expected is int or expected is float:
		if declared is bool or not (declared is int or declared is float):
			return false
		return absf(float(declared) - float(expected)) < 0.0001
	return str(declared) == str(expected)


## Criterion 4: the three timelines stay rhythmically and visually apart at every
## supported viewport height, not only at the reference one.
func _test_resolution_distinctness(errors: Array[String]) -> void:
	var backdrops := {}
	var hitstops := {}
	for weapon_id in Pack.WEAPON_IDS:
		var key := str(weapon_id)
		backdrops[str(Pack.presence_for(key).get("backdrop", "")) + ":%.2f" % Pack.backdrop_alpha(key, Pack.timeline_seconds(key) * 0.5)] = true
		hitstops[float(Pack.presence_for(key).get("hitstop_ms", 0.0))] = true
	_expect(backdrops.size() == 3, "the three backdrop treatments must stay distinct", errors)
	_expect(hitstops.size() == 3, "the three first-impact hitstops must stay distinct", errors)
	for height in READABILITY_HEIGHTS:
		var scale := float(height) / REFERENCE_VIEWPORT_HEIGHT
		for phase_name in PHASE_ORDER:
			for sample in 5:
				var signatures := {}
				for weapon_id in Pack.WEAPON_IDS:
					signatures[_scaled_signature(str(weapon_id), phase_name, float(sample) / 4.0, scale)] = true
				_expect(
					signatures.size() == 3,
					"the three formations must stay distinct at %dp (%s sample %d)" % [height, phase_name, sample],
					errors
				)


## Every v2 binding the shipped scene actually drives, positively and then with
## one binding removed at a time.
func _test_v2_scene_bindings(registry, weapon_id: String, errors: Array[String]) -> void:
	var packed: PackedScene = load(str(SCENE_PATHS.get(weapon_id, "")))
	if packed == null:
		return
	var scene := _declared_scene(registry, packed)
	var violations := Pack.scene_violations(scene, weapon_id)
	_expect(violations.is_empty(), "%s scene must bind every v2 gate: %s" % [weapon_id, ", ".join(violations)], errors)

	var timing: Dictionary = Pack.weapon_config(weapon_id).get("timing", {})
	var active := float(timing.get("active", 0.0))
	scene.begin(registry, _probes(), 0)
	scene.step(active * 0.5)
	var veil := scene.get_node_or_null(Pack.BACKDROP_NODE) as Sprite2D
	var pose := scene.get_node_or_null(Pack.HERO_POSE_NODE) as Sprite2D
	_expect(pose != null and pose.self_modulate.a > 0.0, "%s must show its hero cast pose during the ceremony" % weapon_id, errors)

	# First impact: the drawn pose freezes for the declared hitstop while the
	# envelope clock keeps running, then continues.
	scene.step(active - active * 0.5 + 0.01)
	var frozen := _scene_pose(scene)
	var hitstop_seconds := float(Pack.presence_for(weapon_id).get("hitstop_ms", 0.0)) / 1000.0
	_expect(hitstop_seconds >= 0.08 and hitstop_seconds <= 0.15, "%s hitstop must stay inside 80-150 ms" % weapon_id, errors)
	scene.step(hitstop_seconds * 0.5)
	_expect(_scene_pose(scene) == frozen, "%s first impact must hold the drawn pose for its hitstop" % weapon_id, errors)
	scene.step(hitstop_seconds)
	_expect(_scene_pose(scene) != frozen, "%s must resume drawing after the hitstop" % weapon_id, errors)
	_expect(veil != null and veil.self_modulate.a > 0.0, "%s backdrop must be lit across the active window" % weapon_id, errors)
	scene.finish("cancel")
	_expect(veil != null and is_zero_approx(veil.self_modulate.a), "%s cleanup must clear the arena-wide backdrop" % weapon_id, errors)
	scene.free()

	for mutation in [
		{"code": "ranger.v2.backdrop_node", "node": Pack.BACKDROP_NODE},
		{"code": "ranger.v2.hero_pose_node", "node": Pack.HERO_POSE_NODE},
	]:
		var stripped := _declared_scene(registry, packed)
		var target := stripped.get_node_or_null(str(mutation["node"]))
		if target != null:
			stripped.remove_child(target)
			target.free()
		_expect_code(
			Pack.scene_violations(stripped, weapon_id),
			str(mutation["code"]),
			"%s without %s must report %s" % [weapon_id, mutation["node"], mutation["code"]],
			errors
		)
		stripped.free()

	for mutation in [
		{"code": "ranger.v2.fullscreen_footprint", "meta": "", "node": Pack.BACKDROP_NODE},
		{"code": "ranger.v2.presence_meta", "meta": "presence"},
		{"code": "ranger.v2.identity_meta", "meta": "identity"},
		{"code": "ranger.v2.max_visual_nodes", "meta": "max_visual_nodes"},
		{"code": "ranger.v2.crowd_cap", "meta": "crowd_cap"},
		{"code": "ranger.v2.material_budget", "meta": "max_unique_materials"},
		{"code": "ranger.v2.ultimate_id", "meta": "ultimate_id"},
	]:
		var mutated := _declared_scene(registry, packed)
		if str(mutation["meta"]).is_empty():
			(mutated.get_node(str(mutation["node"])) as Node).set_meta("fullscreen_layer", false)
		else:
			mutated.set_meta(str(mutation["meta"]), 0)
		_expect_code(
			Pack.scene_violations(mutated, weapon_id),
			str(mutation["code"]),
			"%s with a broken %s declaration must report %s" % [weapon_id, mutation.get("meta", "fullscreen_layer"), mutation["code"]],
			errors
		)
		mutated.free()


## A headless contract tree never runs the node lifecycle — `root` itself is not
## inside the tree during `_initialize` — so the scene publishes its declarations
## through the same headless `begin` entry point a live activation uses.
func _declared_scene(registry, packed: PackedScene) -> Node2D:
	var scene := packed.instantiate() as Node2D
	root.add_child(scene)
	scene.begin(registry, _probes(), 1)
	return scene


func _scaled_signature(weapon_id: String, phase_name: String, progress: float, scale: float) -> String:
	var parts: Array[String] = []
	for point in Pack.formation_points(weapon_id, phase_name, progress):
		var position: Vector2 = (point.get("position", Vector2.ZERO) as Vector2) * scale
		parts.append("%.2f:%.2f:%.3f:%.2f" % [
			position.x, position.y, float(point.get("scale", 0.0)) * scale, float(point.get("alpha", 0.0)),
		])
	return "|".join(parts)


func _expect_code(reported: Array, code: String, message: String, errors: Array[String]) -> void:
	for entry in reported:
		if str(entry).begins_with("%s:" % code):
			return
	errors.append("%s (got %s)" % [message, reported])


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
