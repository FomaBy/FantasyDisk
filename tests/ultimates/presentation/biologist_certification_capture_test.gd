extends SceneTree

## Headless integrity gate for FAN-3936's non-headless Biologist evidence.
##
## The renderer owns live PlayerHost activation. This gate verifies the saved
## evidence independently: every canonical weapon/mode/viewport combination,
## smudged PNG bytes and IHDR dimensions, file hashes, class-local source
## mapping, and fail-closed mutations of the evidence contract.

const CERTIFICATION_MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/biologist/certification_capture_manifest.json"
const CLASS_MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/biologist/manifest.json"
const REPORT_PATH := "res://docs/design/references/weapon_ultimates/biologist/certification_readability_report.md"
const CAPTURE_SCRIPT_PATH := "res://tests/ultimates/presentation/biologist_certification_live_capture.gd"
const ASSET_DIRECTORY := "res://docs/design/reference-assets-lfs/ultimate-certification/biologist"
const POINTER_PROBE_PATH := "user://fan3936_biologist_lfs_pointer_probe.png"

const WEAPON_IDS: Array[String] = [
	"biologist_spore_lens",
	"biologist_sample_injector",
	"biologist_symbiote_seed",
]
const MODE_IDS: Array[String] = [
	"normal",
	"crowded",
	"reduced_motion",
	"photosensitivity_safe",
]
const VIEWPORTS := {
	"1152x648": Vector2i(1152, 648),
	"1280x720": Vector2i(1280, 720),
	"1920x1080": Vector2i(1920, 1080),
	"2560x1440": Vector2i(2560, 1440),
}


func _initialize() -> void:
	var errors: Array[String] = []
	var certification := _load_json(CERTIFICATION_MANIFEST_PATH, errors)
	var class_manifest := _load_json(CLASS_MANIFEST_PATH, errors)
	if not errors.is_empty():
		_finish(errors)
		return
	_check_manifest_shape(certification, errors)
	_check_capture_harness(certification, class_manifest, errors)
	_check_capture_files(certification, errors)
	_check_negative_probes(certification, errors)
	_finish(errors)


func _check_manifest_shape(manifest: Dictionary, errors: Array[String]) -> void:
	var violations := _manifest_violations(manifest)
	_expect(violations.is_empty(), "certification manifest must be complete: %s" % "; ".join(violations), errors)
	_expect(str(manifest.get("issue", "")) == "FAN-3936", "certification manifest must identify FAN-3936", errors)
	_expect(str(manifest.get("class_id", "")) == "biologist", "certification manifest must remain Biologist-local", errors)
	_expect(str(manifest.get("capture_script", "")) == CAPTURE_SCRIPT_PATH.trim_prefix("res://"), "certification manifest must pin its live renderer", errors)
	_expect(str(manifest.get("focused_test", "")) == "tests/ultimates/presentation/biologist_certification_capture_test.gd", "certification manifest must pin this integrity gate", errors)
	_expect(FileAccess.file_exists(REPORT_PATH), "certification readability report must exist", errors)
	var source := manifest.get("capture_source", {}) as Dictionary
	_expect(_is_git_sha(str(source.get("commit", ""))), "capture source commit must be a full SHA", errors)
	_expect(_is_git_sha(str(source.get("tree", ""))), "capture source tree must be a full SHA", errors)
	_expect(str(source.get("relationship", "")) == "pre_artifact_harness_commit", "capture source must explicitly precede the artifact commit", errors)
	var report := FileAccess.get_file_as_string(REPORT_PATH)
	_expect(report.contains(str(source.get("commit", ""))), "readability report must repeat the capture source commit", errors)
	_expect(report.contains("No capture-only visual override"), "readability report must disclose the native photosensitivity strategy", errors)


func _check_capture_harness(manifest: Dictionary, class_manifest: Dictionary, errors: Array[String]) -> void:
	_expect(FileAccess.file_exists(CAPTURE_SCRIPT_PATH), "non-headless capture runner must exist", errors)
	var source := FileAccess.get_file_as_string(CAPTURE_SCRIPT_PATH)
	for required_snippet in [
		"PlayerScene.instantiate()",
		"PlayerHost.activate(player)",
		"UltimateHudRuntimeAdapter",
		"HazardVfx.telegraph",
		"_has_visible_authored_visual",
		"Mycelium",
		"PerfectSample",
		"Matriarch",
		"FAN-3936_BEAT_RESULT",
		"native_no_repeating_fullscreen_flash",
	]:
		_expect(source.contains(required_snippet), "capture runner must retain live-runtime evidence hook: %s" % required_snippet, errors)
	var evidence := class_manifest.get("evidence", {}) as Dictionary
	var certification := evidence.get("certification_capture", {}) as Dictionary
	_expect(str(certification.get("manifest", "")) == CERTIFICATION_MANIFEST_PATH.trim_prefix("res://"), "class manifest must link the certification manifest", errors)
	_expect(str(certification.get("report", "")) == REPORT_PATH.trim_prefix("res://"), "class manifest must link the readability report", errors)
	_expect(str(certification.get("runner", "")) == CAPTURE_SCRIPT_PATH.trim_prefix("res://"), "class manifest must link the live runner", errors)
	var packages := _packages_by_weapon(class_manifest)
	for raw_capture in manifest.get("captures", []) as Array:
		if raw_capture is not Dictionary:
			continue
		var capture := raw_capture as Dictionary
		var weapon_id := str(capture.get("weapon_id", ""))
		var package := packages.get(weapon_id, {}) as Dictionary
		_expect(not package.is_empty(), "%s capture must map to a class-manifest package" % weapon_id, errors)
		_expect(str(capture.get("scene_path", "")) == "res://%s" % str(package.get("scene_path", "")), "%s capture must name its shipped authored scene" % weapon_id, errors)
		_expect(FileAccess.file_exists(str(capture.get("scene_path", ""))), "%s capture scene must exist" % weapon_id, errors)


func _check_capture_files(manifest: Dictionary, errors: Array[String]) -> void:
	var seen_files := {}
	for raw_capture in manifest.get("captures", []) as Array:
		if raw_capture is not Dictionary:
			continue
		var capture := raw_capture as Dictionary
		var viewport_id := str(capture.get("viewport_id", ""))
		var expected_size := VIEWPORTS.get(viewport_id, Vector2i.ZERO) as Vector2i
		var relative_path := str(capture.get("path", ""))
		var path := "res://%s" % relative_path
		seen_files[relative_path.get_file()] = true
		_expect(FileAccess.file_exists(path), "%s capture file must exist: %s" % [_capture_key(capture), path], errors)
		if not FileAccess.file_exists(path):
			continue
		var png_errors := _png_violations(path, expected_size)
		_expect(png_errors.is_empty(), "%s capture PNG must be hydrated and native-sized: %s" % [_capture_key(capture), "; ".join(png_errors)], errors)
		var actual_hash := FileAccess.get_sha256(path).to_lower()
		_expect(actual_hash == str(capture.get("sha256", "")), "%s stored SHA-256 must match the smudged PNG" % _capture_key(capture), errors)
		_expect("sha256:%s" % actual_hash == str(capture.get("lfs_object_id", "")), "%s LFS object ID must match the smudged PNG" % _capture_key(capture), errors)
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		_expect(image != null and not image.is_empty() and image.get_size() == expected_size, "%s PNG must decode at its declared viewport size" % _capture_key(capture), errors)
		if image != null and not image.is_empty():
			_expect(image.get_used_rect().size != Vector2i.ZERO, "%s PNG must contain reviewable rendered pixels" % _capture_key(capture), errors)
	var directory := DirAccess.open(ASSET_DIRECTORY)
	_expect(directory != null, "certification asset directory must exist", errors)
	if directory == null:
		return
	var disk_files := {}
	for file_name in directory.get_files():
		if file_name.ends_with(".png"):
			disk_files[file_name] = true
	_expect(disk_files.size() == WEAPON_IDS.size() * MODE_IDS.size() * VIEWPORTS.size(), "certification directory must contain exactly 48 PNGs", errors)
	_expect(disk_files == seen_files, "certification directory must contain no stale or unmanifested PNGs", errors)


func _check_negative_probes(manifest: Dictionary, errors: Array[String]) -> void:
	var missing_asset_errors := _png_violations("res://docs/design/reference-assets-lfs/ultimate-certification/biologist/missing.png", Vector2i(1, 1))
	_expect(not missing_asset_errors.is_empty(), "missing capture asset must fail closed", errors)
	var pointer := FileAccess.open(POINTER_PROBE_PATH, FileAccess.WRITE)
	if pointer == null:
		errors.append("cannot write disposable LFS-pointer negative probe")
	else:
		pointer.store_string("version https://git-lfs.github.com/spec/v1\noid sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\nsize 1\n")
		pointer.close()
		_expect(not _png_violations(POINTER_PROBE_PATH, Vector2i(1, 1)).is_empty(), "an unsmudged LFS pointer must fail PNG validation", errors)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(POINTER_PROBE_PATH))
	var wrong_size := manifest.duplicate(true)
	var wrong_size_records := wrong_size.get("captures", []) as Array
	if not wrong_size_records.is_empty():
		(wrong_size_records[0] as Dictionary)["width"] = int((wrong_size_records[0] as Dictionary).get("width", 0)) - 1
	_expect(not _manifest_violations(wrong_size).is_empty(), "wrong declared dimensions must fail closed", errors)
	var missing_mode := manifest.duplicate(true)
	var modes := missing_mode.get("presentation_modes", []) as Array
	if not modes.is_empty():
		modes.remove_at(0)
	_expect(not _manifest_violations(missing_mode).is_empty(), "missing presentation mode must fail closed", errors)
	var incorrect_mode := manifest.duplicate(true)
	var mode_records := incorrect_mode.get("presentation_modes", []) as Array
	if not mode_records.is_empty():
		(mode_records[0] as Dictionary)["id"] = "unsafe_mode"
	_expect(not _manifest_violations(incorrect_mode).is_empty(), "incorrect presentation mode must fail closed", errors)
	var missing_capture := manifest.duplicate(true)
	var captures := missing_capture.get("captures", []) as Array
	if not captures.is_empty():
		captures.remove_at(0)
	_expect(not _manifest_violations(missing_capture).is_empty(), "missing capture combination must fail closed", errors)


func _manifest_violations(manifest: Dictionary) -> Array[String]:
	var violations: Array[String] = []
	if int(manifest.get("schema_version", 0)) != 1:
		violations.append("schema_version")
	if str(manifest.get("class_id", "")) != "biologist":
		violations.append("class_id")
	if _string_array(manifest.get("canonical_weapon_ids", [])) != WEAPON_IDS:
		violations.append("canonical_weapon_ids")
	if _mode_ids(manifest.get("presentation_modes", [])) != MODE_IDS:
		violations.append("presentation_modes")
	var declared_viewports := _viewports_by_id(manifest.get("viewports", []))
	if declared_viewports.size() != VIEWPORTS.size():
		violations.append("viewport_count")
	for viewport_id in VIEWPORTS:
		var expected_size := VIEWPORTS[viewport_id] as Vector2i
		var viewport := declared_viewports.get(viewport_id, {}) as Dictionary
		if viewport.is_empty() or int(viewport.get("width", -1)) != expected_size.x or int(viewport.get("height", -1)) != expected_size.y:
			violations.append("viewport:%s" % viewport_id)
	var expected_keys := _expected_keys()
	var seen := {}
	var captures := manifest.get("captures", []) as Array
	if captures.size() != expected_keys.size():
		violations.append("capture_count")
	for raw_capture in captures:
		if raw_capture is not Dictionary:
			violations.append("capture_type")
			continue
		var capture := raw_capture as Dictionary
		var key := _capture_key(capture)
		if not expected_keys.has(key) or seen.has(key):
			violations.append("capture_key:%s" % key)
		seen[key] = true
		var viewport_id := str(capture.get("viewport_id", ""))
		var expected_size := VIEWPORTS.get(viewport_id, Vector2i.ZERO) as Vector2i
		if expected_size == Vector2i.ZERO or int(capture.get("width", -1)) != expected_size.x or int(capture.get("height", -1)) != expected_size.y:
			violations.append("capture_dimensions:%s" % key)
		var path := str(capture.get("path", ""))
		var expected_path := "%s/%s__%s__%s.png" % [ASSET_DIRECTORY.trim_prefix("res://"), str(capture.get("weapon_id", "")), str(capture.get("mode", "")), viewport_id]
		if path != expected_path:
			violations.append("capture_path:%s" % key)
		var digest := str(capture.get("sha256", ""))
		if not _is_sha256(digest) or str(capture.get("lfs_object_id", "")) != "sha256:%s" % digest:
			violations.append("capture_hash:%s" % key)
		if str(capture.get("captured_beat", "")) != "active" or capture.get("impact_verified") != true:
			violations.append("capture_beat:%s" % key)
		var mode_id := str(capture.get("mode", ""))
		var expected_shake := mode_id != "reduced_motion"
		if bool(capture.get("screen_shake", not expected_shake)) != expected_shake:
			violations.append("capture_motion:%s" % key)
		var expected_photo_strategy := "native_no_repeating_fullscreen_flash" if mode_id == "photosensitivity_safe" else "native_shipped_visual"
		if str(capture.get("photosensitivity_strategy", "")) != expected_photo_strategy:
			violations.append("capture_photosensitivity:%s" % key)
	if seen.size() != expected_keys.size():
		violations.append("capture_matrix")
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
	var png_signature := PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10])
	if file.get_buffer(8) != png_signature:
		file.close()
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


func _packages_by_weapon(manifest: Dictionary) -> Dictionary:
	var packages := {}
	for raw_package in manifest.get("weapons", []) as Array:
		if raw_package is Dictionary:
			var package := raw_package as Dictionary
			packages[str(package.get("weapon_id", ""))] = package
	return packages


func _viewports_by_id(raw_viewports: Variant) -> Dictionary:
	var result := {}
	if raw_viewports is not Array:
		return result
	for raw_viewport in raw_viewports as Array:
		if raw_viewport is Dictionary:
			var viewport := raw_viewport as Dictionary
			var viewport_id := str(viewport.get("id", ""))
			if not viewport_id.is_empty() and not result.has(viewport_id):
				result[viewport_id] = viewport
	return result


func _expected_keys() -> Dictionary:
	var keys := {}
	for weapon_id in WEAPON_IDS:
		for mode_id in MODE_IDS:
			for viewport_id in VIEWPORTS:
				keys["%s|%s|%s" % [weapon_id, mode_id, viewport_id]] = true
	return keys


func _capture_key(capture: Dictionary) -> String:
	return "%s|%s|%s" % [str(capture.get("weapon_id", "")), str(capture.get("mode", "")), str(capture.get("viewport_id", ""))]


func _mode_ids(raw_modes: Variant) -> Array[String]:
	var ids: Array[String] = []
	if raw_modes is Array:
		for raw_mode in raw_modes as Array:
			if raw_mode is Dictionary:
				ids.append(str((raw_mode as Dictionary).get("id", "")))
	return ids


func _string_array(raw_values: Variant) -> Array[String]:
	var values: Array[String] = []
	if raw_values is Array:
		for value in raw_values as Array:
			values.append(str(value))
	return values


func _is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for character in value:
		if not "0123456789abcdef".contains(character):
			return false
	return true


func _is_git_sha(value: String) -> bool:
	if value.length() != 40:
		return false
	for character in value:
		if not "0123456789abcdef".contains(character):
			return false
	return true


func _load_json(path: String, errors: Array[String]) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("missing JSON: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is not Dictionary:
		errors.append("invalid JSON: %s" % path)
		return {}
	return parsed as Dictionary


func _expect(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)


func _finish(errors: Array[String]) -> void:
	if errors.is_empty():
		print("FAN-3936 Biologist certification capture package: PASS")
		quit(0)
		return
	for error in errors:
		push_error("FAN-3936 Biologist certification capture package: %s" % error)
	quit(1)
