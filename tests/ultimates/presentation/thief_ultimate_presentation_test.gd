extends SceneTree

## Focused contract, visual-distinction, budget, and lifecycle test for Thief.
const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Schema := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_schema.gd")
const Timeline := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_timeline.gd")
const Pack := preload("res://scenes/vfx/ultimates/thief/thief_ultimate_presentation_pack.gd")
const TimelineScene := preload("res://scenes/vfx/ultimates/thief/thief_ultimate_timeline_scene.gd")

const PROFILE_PATH := "res://data/ultimates/schema/v1/classes/thief.json"
const SCENE_PATHS := {
	Pack.COIN_POUCH: "res://scenes/vfx/ultimates/thief/ThiefCoinPouchUltimate.tscn",
	Pack.SHADOW_CLOAK: "res://scenes/vfx/ultimates/thief/ThiefShadowCloakUltimate.tscn",
	Pack.SMOKE_BOMB: "res://scenes/vfx/ultimates/thief/ThiefSmokeBombUltimate.tscn",
}
const PHASE_ORDER: Array[String] = ["windup", "release", "active", "recovery", "cancel"]
const READABILITY_HEIGHTS: Array[int] = [648, 720, 1080, 1440]
const MIN_READABLE_PIXELS := 6.0


class HandleProbe extends RefCounted:
	var released := 0
	func release() -> void:
		released += 1


func _initialize() -> void:
	var errors: Array[String] = []
	var registry = Registry.new(PD.WEAPONS_BY_CLASS)
	_expect(registry.is_valid(), "weapon registry must be valid", errors)
	var manifests := Pack.manifests(registry)
	_expect(manifests.size() == 3, "pack must publish three thief manifests", errors)
	_test_schema(manifests, registry, errors)
	_test_frozen_phase_ids(manifests, errors)
	_test_distinct_timelines(manifests, errors)
	_test_budgets(errors)
	for weapon_id in Pack.WEAPON_IDS:
		_test_lifecycle(registry, weapon_id, errors)
	if not errors.is_empty():
		for error in errors:
			push_error("Thief ultimate presentation: %s" % error)
		quit(1)
		return
	print("Thief ultimate presentation pack passed (3 distinct timelines, schema, lifecycle, budgets).")
	quit(0)


func _test_schema(manifests: Dictionary, registry, errors: Array[String]) -> void:
	var catalog: Array = []
	for weapon_id in Pack.WEAPON_IDS:
		catalog.append((manifests[weapon_id] as Dictionary).duplicate(true))
	var catalog_errors := Schema.validate_catalog(catalog, Pack.expected_profiles(registry))
	_expect(catalog_errors.is_empty(), "thief catalog must validate: %s" % ", ".join(catalog_errors), errors)
	var maximum := float(Schema.schema_document().get("max_timeline_seconds", 0.0))
	for weapon_id in Pack.WEAPON_IDS:
		var manifest: Dictionary = manifests[weapon_id]
		_expect(_phase_names(manifest) == PHASE_ORDER, "%s must cover five phase groups" % weapon_id, errors)
		_expect(Pack.timeline_seconds(weapon_id) <= maximum, "%s must fit max timeline" % weapon_id, errors)
		var previous := -1.0
		for phase_name in PHASE_ORDER:
			var value := float((manifest.get("timing", {}) as Dictionary).get(phase_name, -1.0))
			_expect(value >= previous, "%s timing must be monotonic" % weapon_id, errors)
			previous = value


func _test_frozen_phase_ids(manifests: Dictionary, errors: Array[String]) -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
	if not parsed is Dictionary:
		errors.append("cannot read frozen thief profile")
		return
	var frozen := {}
	for profile in (parsed as Dictionary).get("profiles", []) as Array:
		frozen[str((profile as Dictionary).get("weapon_id", ""))] = (profile as Dictionary).get("cast_phases", {})
	var bindings := {"windup": "windup", "release": "execute", "active": "active", "recovery": "recover", "cancel": "cleanup"}
	for weapon_id in Pack.WEAPON_IDS:
		for phase in (manifests[weapon_id] as Dictionary).get("phases", []) as Array:
			var item := phase as Dictionary
			_expect(str(item.get("phase_id", "")) == str((frozen.get(weapon_id, {}) as Dictionary).get(bindings.get(str(item.get("name", "")), ""), "")), "%s phase must bind frozen id" % weapon_id, errors)


func _test_distinct_timelines(manifests: Dictionary, errors: Array[String]) -> void:
	var rhythms := {}
	var assets := {}
	var silhouettes := {}
	var kinds := {}
	for weapon_id in Pack.WEAPON_IDS:
		var config := Pack.weapon_config(weapon_id)
		rhythms[str((manifests[weapon_id] as Dictionary).get("timing", {}))] = true
		assets[FileAccess.get_sha256(Pack.asset_path(weapon_id))] = true
		silhouettes[str(config.get("silhouette", ""))] = true
		kinds[str((config.get("formation", {}) as Dictionary).get("kind", ""))] = true
	_expect(rhythms.size() == 3 and assets.size() == 3 and silhouettes.size() == 3 and kinds.size() == 3, "silhouette, rhythm, assets, and motion kinds must differ", errors)
	for phase_name in PHASE_ORDER:
		for sample in 5:
			var signatures := {}
			for weapon_id in Pack.WEAPON_IDS:
				signatures[_motion_signature(weapon_id, phase_name, float(sample) / 4.0)] = true
			_expect(signatures.size() == 3, "motion paths must differ at %s" % phase_name, errors)


func _test_budgets(errors: Array[String]) -> void:
	for weapon_id in Pack.WEAPON_IDS:
		var count := int((Pack.weapon_config(weapon_id).get("formation", {}) as Dictionary).get("count", 0))
		_expect(count > 0 and count <= Pack.MAX_ELEMENTS_PER_ULTIMATE, "%s must respect crowd cap" % weapon_id, errors)
		var texture: Texture2D = load(Pack.asset_path(weapon_id))
		if texture == null:
			errors.append("missing accepted asset %s" % weapon_id)
			continue
		var smallest := INF
		for phase_name in PHASE_ORDER:
			for sample in 5:
				var points := Pack.formation_points(weapon_id, phase_name, float(sample) / 4.0)
				_expect(points.size() == count and points.size() <= Pack.MAX_ELEMENTS_PER_ULTIMATE, "%s formation exceeds cap" % weapon_id, errors)
				for point in points:
					if float(point.get("alpha", 0.0)) >= 0.2:
						smallest = minf(smallest, float(texture.get_height()) * float(point.get("scale", 0.0)))
		for height in READABILITY_HEIGHTS:
			_expect(smallest * float(height) / 1080.0 >= MIN_READABLE_PIXELS, "%s is unreadable at %dp" % [weapon_id, height], errors)


func _test_lifecycle(registry, weapon_id: String, errors: Array[String]) -> void:
	var packed: PackedScene = load(str(SCENE_PATHS.get(weapon_id, "")))
	_expect(packed != null, "%s scene must load" % weapon_id, errors)
	if packed == null:
		return
	var headless := packed.instantiate() as Node2D
	root.add_child(headless)
	_expect(str(headless.begin(registry, _probes(), 1).get("state", "")) == Timeline.HEADLESS_STATE, "%s headless fallback" % weapon_id, errors)
	headless.free()
	var scene := packed.instantiate() as Node2D
	root.add_child(scene)
	scene.begin(registry, _probes(), 0)
	scene.step(0.2)
	_expect(scene.is_active() and scene.get_child_count() > 0, "%s scene must animate" % weapon_id, errors)
	var before := _scene_pose(scene)
	scene.set_paused(true)
	scene.step(1.0)
	_expect(_scene_pose(scene) == before, "%s pause must freeze" % weapon_id, errors)
	scene.set_paused(false)
	scene.step(0.2)
	_expect(_scene_pose(scene) != before, "%s resume must move" % weapon_id, errors)
	scene.free()
	for reason in TimelineScene.CLEANUP_REASONS:
		var cleanup := packed.instantiate() as Node2D
		root.add_child(cleanup)
		var probes := _probes()
		cleanup.begin(registry, probes, 0)
		cleanup.step(0.2)
		_expect(int(cleanup.finish(reason).get("active_handle_count", -1)) == 0, "%s %s must release handles" % [weapon_id, reason], errors)
		for channel in probes:
			_expect((probes[channel] as HandleProbe).released == 1, "%s %s releases %s once" % [weapon_id, reason, channel], errors)
		cleanup.free()
	var teardown := packed.instantiate() as Node2D
	root.add_child(teardown)
	var teardown_probes := _probes()
	teardown.begin(registry, teardown_probes, 0)
	teardown.step(0.2)
	teardown.free()
	for channel in teardown_probes:
		_expect((teardown_probes[channel] as HandleProbe).released == 1, "%s node teardown releases %s once" % [weapon_id, channel], errors)


func _motion_signature(weapon_id: String, phase_name: String, progress: float) -> String:
	var parts: Array[String] = []
	for point in Pack.formation_points(weapon_id, phase_name, progress):
		var position: Vector2 = point.get("position", Vector2.ZERO)
		parts.append("%.1f:%.1f:%.2f:%.2f" % [position.x, position.y, float(point.get("scale", 0.0)), float(point.get("alpha", 0.0))])
	return "|".join(parts)


func _phase_names(manifest: Dictionary) -> Array[String]:
	var names: Array[String] = []
	for phase in manifest.get("phases", []) as Array:
		names.append(str((phase as Dictionary).get("name", "")))
	return names


func _scene_pose(scene: Node2D) -> String:
	var parts: Array[String] = []
	for child in scene.get_children():
		var sprite := child as Sprite2D
		if sprite != null:
			parts.append("%.2f:%.2f:%.2f:%.2f" % [sprite.position.x, sprite.position.y, sprite.scale.x, sprite.modulate.a])
	return "|".join(parts)


func _probes() -> Dictionary:
	return {"animation": HandleProbe.new(), "vfx": HandleProbe.new(), "sfx": HandleProbe.new()}


func _expect(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)
