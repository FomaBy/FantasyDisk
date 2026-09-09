extends SceneTree

## Headless fail-closed gate for the FAN-3940 Sniper certification package.
##
## The renderer makes the evidence; this gate decides whether the committed
## evidence is real. It checks the manifest against the frozen Sniper profile,
## every sheet's PNG/IHDR header and hydrated content hash, the completeness of
## the weapon x mode x viewport x beat matrix, and it proves each rejection path
## with a mutated copy, so a missing mode, a missing canonical key, a missing
## file, an unsmudged LFS pointer and a wrong dimension all fail closed.

const Capture := preload("res://tests/ultimates/presentation/sniper_certification_live_capture.gd")
const DirectionContract := preload("res://scripts/ultimates/presentation/ultimate_visual_direction_contract.gd")

const CLASS_ID := "sniper"
const PROFILE_PATH := "res://data/ultimates/schema/v1/classes/sniper.json"
const POINTER_FIXTURE_PATH := "user://fan3940_sniper_capture_pointer.png"
const MISSING_FIXTURE_PATH := "user://fan3940_sniper_capture_absent.png"

var _errors: Array[String] = []


func _initialize() -> void:
	var manifest := _load_json(Capture.MANIFEST_PATH)
	var class_manifest := _load_json(Capture.CLASS_MANIFEST_PATH)
	var profile := _load_json(PROFILE_PATH)
	if manifest.is_empty() or class_manifest.is_empty() or profile.is_empty():
		_report()
		return
	_check_manifest_shape(manifest, profile)
	_check_source_pin(manifest)
	_check_class_manifest_link(class_manifest, manifest)
	_check_sheets(manifest)
	_check_live_source_mapping(class_manifest)
	_check_negative_probes(manifest, profile)
	_report()


func _check_manifest_shape(manifest: Dictionary, profile: Dictionary) -> void:
	var violations := _manifest_violations(manifest, profile)
	_check(violations.is_empty(), "capture manifest must be complete: %s" % "; ".join(violations))
	_check(FileAccess.file_exists("res://%s" % str(manifest.get("capture_script", ""))), "capture renderer must exist")
	_check(FileAccess.file_exists("res://%s" % str(manifest.get("focused_test", ""))), "focused gate must exist")
	_check(FileAccess.file_exists("res://%s" % str(manifest.get("readability_report", ""))), "readability report must exist")
	for weapon_id in Capture.WEAPON_IDS:
		_check(FileAccess.file_exists(str(Capture.ULTIMATE_SCENES.get(weapon_id, ""))),
			"%s shipped presentation scene must exist" % weapon_id)
		_check(FileAccess.file_exists(str(Capture.EFFECT_SCENES.get(weapon_id, ""))),
			"%s shipped weapon effect scene must exist" % weapon_id)


## The pin has to name an integrated source that is not the commit recording
## these files, otherwise the provenance is unverifiable by construction.
func _check_source_pin(manifest: Dictionary) -> void:
	var source := manifest.get("capture_source", {}) as Dictionary
	_check(str(source.get("sha", "")) == Capture.CAPTURE_SOURCE_SHA, "manifest must pin the renderer's declared source SHA")
	_check(str(source.get("tree", "")) == Capture.CAPTURE_SOURCE_TREE, "manifest must pin the renderer's declared source tree")
	_check(str(source.get("ref", "")) == Capture.CAPTURE_SOURCE_REF, "manifest must record the source ref")
	_check(_is_sha1(str(source.get("sha", ""))) and _is_sha1(str(source.get("tree", ""))), "source pins must be full object IDs")
	_check(str(source.get("sha", "")) != str(source.get("tree", "")), "commit and tree pins must be distinct objects")


func _check_class_manifest_link(class_manifest: Dictionary, manifest: Dictionary) -> void:
	var evidence := class_manifest.get("evidence", {}) as Dictionary
	var certification := evidence.get("certification_capture", {}) as Dictionary
	_check(str(certification.get("issue", "")) == str(manifest.get("issue", "")), "class manifest must record the certification issue")
	_check(str(certification.get("manifest", "")) == Capture.MANIFEST_PATH.trim_prefix("res://"),
		"class manifest must point at the certification capture manifest")
	_check(str(certification.get("capture_script", "")) == str(manifest.get("capture_script", "")),
		"class manifest and capture manifest must name the same renderer")
	var declared := _string_array(certification.get("modes", []))
	_check(declared == Capture.MODE_IDS, "class manifest must declare the four live modes")
	var sheets := _string_array(certification.get("sheets", []))
	_check(sheets.size() == Capture.MODE_IDS.size() * Capture.VIEWPORT_IDS.size(),
		"class manifest must list one sheet per mode and viewport")
	for path in sheets:
		_check(FileAccess.file_exists("res://%s" % path), "class manifest sheet must exist: %s" % path)
	var legacy := _string_array(evidence.get("contact_sheets", []))
	_check(legacy.size() == Capture.VIEWPORT_IDS.size(), "the shipped four-viewport contact sheets must stay declared")


func _check_sheets(manifest: Dictionary) -> void:
	var sizes := _viewport_sizes(manifest)
	for raw_sheet in manifest.get("sheets", []) as Array:
		var sheet := raw_sheet as Dictionary
		var label := "%s/%s" % [str(sheet.get("mode", "")), str(sheet.get("viewport", ""))]
		var path := str(sheet.get("path", ""))
		var expected := sizes.get(str(sheet.get("viewport", "")), Vector2i.ZERO) as Vector2i
		var png_errors := _png_violations(path, expected)
		_check(png_errors.is_empty(), "%s PNG/IHDR must be valid: %s" % [label, "; ".join(png_errors)])
		if not png_errors.is_empty():
			continue
		_check(FileAccess.get_sha256(path).to_lower() == str(sheet.get("sha256", "")),
			"%s content hash must match the hydrated file" % label)
		var image := Image.load_from_file(path)
		_check(image != null and not image.is_empty() and image.get_size() == expected,
			"%s PNG must decode at its declared native size" % label)


## The captured weapons must still be the ones the shared contract can prove are
## wired to the shipped victim-impact player, and the check must fail closed when
## a canonical key stops matching.
func _check_live_source_mapping(class_manifest: Dictionary) -> void:
	var weapons := _typed_weapons(class_manifest.get("weapons", []) as Array)
	var ids: Array[String] = []
	for weapon in weapons:
		ids.append(str(weapon.get("weapon_id", "")))
	_check(ids == Capture.WEAPON_IDS, "class manifest must enumerate exactly the canonical Sniper trio")
	var positive := DirectionContract.victim_impact_violations_from_sources(CLASS_ID, weapons)
	_check(positive.is_empty(), "each captured weapon must keep live victim-impact wiring: %s" % str(positive))
	var renamed := weapons.duplicate(true)
	if not renamed.is_empty():
		(renamed[0] as Dictionary)["weapon_id"] = "sniper_missing_capture_weapon"
	var negative := DirectionContract.victim_impact_violations_from_sources(CLASS_ID, renamed)
	_check(negative.size() == 1 and str(negative[0]).contains("sniper_missing_capture_weapon"),
		"a missing canonical weapon mapping must fail closed: %s" % str(negative))


func _check_negative_probes(manifest: Dictionary, profile: Dictionary) -> void:
	var missing_mode := manifest.duplicate(true)
	(missing_mode.get("presentation_modes", []) as Array).remove_at(0)
	_check(not _manifest_violations(missing_mode, profile).is_empty(), "a missing presentation mode must fail closed")

	var missing_key := manifest.duplicate(true)
	(missing_key.get("canonical_weapon_ids", []) as Array).remove_at(0)
	_check(not _manifest_violations(missing_key, profile).is_empty(), "a missing canonical weapon key must fail closed")

	var missing_beat := manifest.duplicate(true)
	(missing_beat.get("observations", []) as Array).remove_at(0)
	_check(not _manifest_violations(missing_beat, profile).is_empty(), "a missing weapon/mode/viewport/beat frame must fail closed")

	var missing_sheet := manifest.duplicate(true)
	(missing_sheet.get("sheets", []) as Array).remove_at(0)
	_check(not _manifest_violations(missing_sheet, profile).is_empty(), "a missing sheet must fail closed")

	var wrong_viewport := manifest.duplicate(true)
	var record := (wrong_viewport.get("viewports", []) as Array)[0] as Dictionary
	record["width"] = int(record.get("width", 0)) - 1
	_check(not _manifest_violations(wrong_viewport, profile).is_empty(), "a wrong declared viewport size must fail closed")

	var first_sheet := (manifest.get("sheets", []) as Array)[0] as Dictionary
	var sheet_path := str(first_sheet.get("path", ""))
	_check(not _png_violations(sheet_path, Vector2i(1, 1)).is_empty(), "a wrong PNG dimension must fail closed")
	_check(_png_violations(MISSING_FIXTURE_PATH, Vector2i(1, 1)) == ["missing"], "a missing capture file must fail closed")

	var pointer := FileAccess.open(POINTER_FIXTURE_PATH, FileAccess.WRITE)
	if pointer == null:
		_errors.append("cannot write the LFS-pointer negative fixture")
		return
	pointer.store_string("version https://git-lfs.github.com/spec/v1\noid sha256:%s\nsize 1\n" % "0".repeat(64))
	pointer.close()
	_check(_png_violations(POINTER_FIXTURE_PATH, Vector2i(1, 1)) == ["not_png_or_lfs_pointer"],
		"an unsmudged LFS pointer must fail closed")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(POINTER_FIXTURE_PATH))


func _manifest_violations(manifest: Dictionary, profile: Dictionary) -> Array[String]:
	var violations: Array[String] = []
	if str(manifest.get("class_id", "")) != CLASS_ID:
		violations.append("class_id")
	if str(manifest.get("capture_script", "")) != Capture.CAPTURE_SCRIPT_PATH:
		violations.append("capture_script")
	var declared_weapons := _string_array(manifest.get("canonical_weapon_ids", []))
	if declared_weapons != _profile_weapon_ids(profile) or declared_weapons != Capture.WEAPON_IDS:
		violations.append("canonical_weapon_ids")
	if _record_ids(manifest.get("presentation_modes", [])) != Capture.MODE_IDS:
		violations.append("presentation_modes")
	if _string_array(manifest.get("beats", [])) != Capture.BEAT_IDS:
		violations.append("beats")
	var sizes := _viewport_sizes(manifest)
	if sizes.size() != Capture.VIEWPORT_IDS.size():
		violations.append("viewport_count")
	for viewport_id in Capture.VIEWPORT_IDS:
		var expected := Capture.VIEWPORT_SIZES[viewport_id] as Vector2i
		if (sizes.get(viewport_id, Vector2i.ZERO) as Vector2i) != expected:
			violations.append("viewport:%s" % viewport_id)
	violations.append_array(_sheet_violations(manifest))
	violations.append_array(_observation_violations(manifest))
	return violations


func _sheet_violations(manifest: Dictionary) -> Array[String]:
	var violations: Array[String] = []
	var seen := {}
	for raw_sheet in manifest.get("sheets", []) as Array:
		var sheet := raw_sheet as Dictionary
		var key := "%s|%s" % [str(sheet.get("mode", "")), str(sheet.get("viewport", ""))]
		var expected := Capture.VIEWPORT_SIZES.get(str(sheet.get("viewport", "")), Vector2i.ZERO) as Vector2i
		if int(sheet.get("width", -1)) != expected.x or int(sheet.get("height", -1)) != expected.y:
			violations.append("sheet_size:%s" % key)
		if not str(sheet.get("path", "")).begins_with(Capture.OUTPUT_ROOT):
			violations.append("sheet_path:%s" % key)
		if not _is_sha256(str(sheet.get("sha256", ""))):
			violations.append("sheet_hash:%s" % key)
		seen[key] = true
	for mode_id in Capture.MODE_IDS:
		for viewport_id in Capture.VIEWPORT_IDS:
			if not seen.has("%s|%s" % [mode_id, viewport_id]):
				violations.append("sheet_missing:%s/%s" % [mode_id, viewport_id])
	return violations


## The coverage claim is the whole deliverable, so it is recomputed from the
## recorded frames rather than read from the manifest's own summary.
func _observation_violations(manifest: Dictionary) -> Array[String]:
	var violations: Array[String] = []
	var seen := {}
	for raw_record in manifest.get("observations", []) as Array:
		var record := raw_record as Dictionary
		var key := "%s|%s|%s|%s" % [
			str(record.get("weapon_id", "")), str(record.get("mode", "")),
			str(record.get("viewport", "")), str(record.get("beat", ""))]
		if str(record.get("visible_phase", "")) != str(record.get("beat", "")):
			violations.append("phase_mismatch:%s" % key)
		if not bool(record.get("cast_pose_bound", false)) or not bool(record.get("silhouette_bound", false)):
			violations.append("identity_unbound:%s" % key)
		if int((record.get("victim_impacts", {}) as Dictionary).get("victims", 0)) <= 0:
			violations.append("no_live_victims:%s" % key)
		seen[key] = true
	for weapon_id in Capture.WEAPON_IDS:
		for mode_id in Capture.MODE_IDS:
			for viewport_id in Capture.VIEWPORT_IDS:
				for beat_id in Capture.BEAT_IDS:
					if not seen.has("%s|%s|%s|%s" % [weapon_id, mode_id, viewport_id, beat_id]):
						violations.append("frame_missing:%s/%s/%s/%s" % [weapon_id, mode_id, viewport_id, beat_id])
	return violations


func _png_violations(path: String, expected_size: Vector2i) -> Array[String]:
	var violations: Array[String] = []
	if not FileAccess.file_exists(path):
		violations.append("missing")
		return violations
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 24:
		violations.append("truncated")
		return violations
	if file.get_buffer(8) != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]):
		violations.append("not_png_or_lfs_pointer")
		return violations
	file.big_endian = true
	var ihdr_length := file.get_32()
	var chunk_type := file.get_buffer(4).get_string_from_ascii()
	var width := file.get_32()
	var height := file.get_32()
	file.close()
	if ihdr_length != 13 or chunk_type != "IHDR":
		violations.append("missing_ihdr")
	elif width != expected_size.x or height != expected_size.y:
		violations.append("ihdr_size:%dx%d" % [width, height])
	return violations


func _viewport_sizes(manifest: Dictionary) -> Dictionary:
	var sizes := {}
	for raw_viewport in manifest.get("viewports", []) as Array:
		if raw_viewport is Dictionary:
			var viewport := raw_viewport as Dictionary
			var viewport_id := str(viewport.get("id", ""))
			if not viewport_id.is_empty() and not sizes.has(viewport_id):
				sizes[viewport_id] = Vector2i(int(viewport.get("width", -1)), int(viewport.get("height", -1)))
	return sizes


func _profile_weapon_ids(profile: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for raw_weapon in profile.get("profiles", []) as Array:
		if raw_weapon is Dictionary:
			ids.append(str((raw_weapon as Dictionary).get("weapon_id", "")))
	return ids


func _record_ids(raw_records: Variant) -> Array[String]:
	var ids: Array[String] = []
	if raw_records is Array:
		for raw_record in raw_records as Array:
			if raw_record is Dictionary:
				ids.append(str((raw_record as Dictionary).get("id", "")))
	return ids


func _string_array(raw_values: Variant) -> Array[String]:
	var values: Array[String] = []
	if raw_values is Array:
		for raw_value in raw_values as Array:
			values.append(str(raw_value))
	return values


func _typed_weapons(raw_weapons: Array) -> Array[Dictionary]:
	var weapons: Array[Dictionary] = []
	for raw_weapon in raw_weapons:
		if raw_weapon is Dictionary:
			weapons.append(raw_weapon as Dictionary)
	return weapons


func _is_sha256(value: String) -> bool:
	return _is_hex(value, 64)


func _is_sha1(value: String) -> bool:
	return _is_hex(value, 40)


func _is_hex(value: String, length: int) -> bool:
	if value.length() != length:
		return false
	for character in value:
		if not "0123456789abcdef".contains(character):
			return false
	return true


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_errors.append("missing JSON: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		_errors.append("invalid JSON: %s" % path)
		return {}
	return parsed as Dictionary


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("%s Sniper certification capture package: PASS (%d weapons x %d modes x %d viewports x %d beats)" % [
			Capture.ISSUE, Capture.WEAPON_IDS.size(), Capture.MODE_IDS.size(),
			Capture.VIEWPORT_IDS.size(), Capture.BEAT_IDS.size()])
		quit(0)
		return
	for error in _errors:
		push_error("%s Sniper certification capture package: %s" % [Capture.ISSUE, error])
	quit(1)
