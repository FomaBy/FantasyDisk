extends SceneTree

## Focused contract test for the weapon-keyed ultimate presentation bridge.

const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Manifest := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_manifest.gd")
const Schema := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_schema.gd")
const Timeline := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_timeline.gd")


class HandleProbe extends RefCounted:
	var attached := 1
	var released := 0

	func release() -> void:
		released += 1

	func orphan_handle_count() -> int:
		return attached - released


func _initialize() -> void:
	var errors: Array[String] = []
	var registry = Registry.new(PD.WEAPONS_BY_CLASS)
	var catalog := Manifest.catalog_for_registry(registry)
	var expected_profiles := Manifest.expected_profiles_for_registry(registry)
	_expect(registry.is_valid(), "weapon registry must be valid", errors)
	_expect(catalog.size() == 51, "presentation catalog must contain all 51 weapon profiles", errors)
	_expect(
		Schema.validate_catalog(_manifest_array(catalog), expected_profiles).is_empty(),
		"canonical presentation catalog must validate",
		errors
	)

	var presentation_ids := {}
	for raw_key in catalog.keys():
		var key := str(raw_key)
		var manifest: Dictionary = catalog[key]
		var profile: Dictionary = expected_profiles[key]
		var key_data: Dictionary = manifest.get("key", {})
		_expect(str(key_data.get("action", "")) == "ultimate", "%s action must be ultimate" % key, errors)
		_expect(not str(key_data.get("weapon_id", "")).is_empty(), "%s weapon key must be stable" % key, errors)
		var presentation: Dictionary = profile.get("presentation", {})
		_expect(
			str(manifest.get("presentation_id", "")) == str(presentation.get("presentation_id", "")),
			"%s must preserve immutable presentation ID" % key,
			errors
		)
		presentation_ids[str(manifest.get("presentation_id", ""))] = true
		_expect(_phase_names(manifest) == ["windup", "release", "active", "recovery", "cancel"], "%s phase order must be complete" % key, errors)
	_expect(presentation_ids.size() == 51, "all 51 presentation IDs must be distinct", errors)

	var first_manifest: Dictionary = catalog["berserk/sword"]
	_test_headless_no_op(first_manifest, errors)
	_test_pause_freezes_timeline(first_manifest, errors)
	for cleanup_reason in ["cancel", "death", "node_end"]:
		_test_cleanup_releases_all_handles(first_manifest, cleanup_reason, errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Weapon ultimate presentation contract: %s" % error)
		push_error("Weapon ultimate presentation contract test: %d errors." % errors.size())
		quit(1)
		return
	print("Weapon ultimate presentation contract passed (51 stable manifests, pause/cleanup and headless no-op).")
	quit(0)


func _test_headless_no_op(manifest: Dictionary, errors: Array[String]) -> void:
	var timeline = Timeline.new(manifest, 1)
	var probes := _probes()
	var result := timeline.begin(probes)
	_expect(str(result.get("state", "")) == Timeline.HEADLESS_STATE, "headless begin must be a no-op", errors)
	_expect(int(result.get("active_handle_count", -1)) == 0, "headless no-op must attach no handles", errors)
	_expect(timeline.advance(1.0).is_empty(), "headless no-op must emit no events", errors)
	_expect(timeline.finish("cancel").get("state", "") == Timeline.HEADLESS_STATE, "headless cleanup must stay deterministic", errors)
	for probe in probes.values():
		_expect((probe as HandleProbe).orphan_handle_count() == 1, "headless no-op must not claim live handles", errors)


func _test_pause_freezes_timeline(manifest: Dictionary, errors: Array[String]) -> void:
	var timeline = Timeline.new(manifest, 0)
	timeline.begin(_probes())
	timeline.advance(0.05)
	var elapsed_before_pause := timeline.elapsed_seconds()
	timeline.set_paused(true)
	_expect(timeline.advance(1.0).is_empty(), "paused timeline must not emit events", errors)
	_expect(is_equal_approx(timeline.elapsed_seconds(), elapsed_before_pause), "paused timeline must not advance time", errors)
	timeline.set_paused(false)
	_expect(not timeline.advance(0.10).is_empty(), "resumed timeline must continue events", errors)
	timeline.finish("cancel")


func _test_cleanup_releases_all_handles(manifest: Dictionary, reason: String, errors: Array[String]) -> void:
	var timeline = Timeline.new(manifest, 0)
	var probes := _probes()
	timeline.begin(probes)
	timeline.finish(reason)
	_expect(timeline.active_handle_count() == 0, "%s must clear timeline handles" % reason, errors)
	for channel in probes:
		var probe := probes[channel] as HandleProbe
		_expect(probe.orphan_handle_count() == 0, "%s must release %s handle" % [reason, channel], errors)


func _probes() -> Dictionary:
	return {
		"animation": HandleProbe.new(),
		"vfx": HandleProbe.new(),
		"sfx": HandleProbe.new(),
	}


func _manifest_array(catalog: Dictionary) -> Array:
	var manifests: Array = []
	for key in catalog.keys():
		manifests.append((catalog[key] as Dictionary).duplicate(true))
	return manifests


func _phase_names(manifest: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for raw_phase in manifest.get("phases", []) as Array:
		if raw_phase is Dictionary:
			result.append(str((raw_phase as Dictionary).get("name", "")))
	return result


func _expect(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)
