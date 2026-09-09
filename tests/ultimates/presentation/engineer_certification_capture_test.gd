extends SceneTree

## Headless integrity gate for the FAN-3939 Engineer certification capture
## package.
##
## The windowed renderer creates the images; this gate checks their real
## PNG/IHDR data, LFS object IDs, deterministic panel markers, player/HUD/
## hazard readability, the canonical weapon x mode x viewport coverage, and
## fail-closed mutations of every required dimension (missing mode, missing
## weapon key, missing file, unsmudged LFS pointer, wrong dimensions).

const Capture := preload("res://tests/ultimates/presentation/engineer_certification_live_capture.gd")

const PROFILE_PATH := "res://data/ultimates/schema/v1/classes/engineer.json"
const CLASS_MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/engineer/manifest.json"
const POINTER_FIXTURE_PATH := "user://fan3939_engineer_capture_pointer.png"


func _initialize() -> void:
	var errors: Array[String] = []
	var manifest := _load_json(Capture.CAPTURE_MANIFEST_PATH, errors)
	var profile := _load_json(PROFILE_PATH, errors)
	var class_manifest := _load_json(CLASS_MANIFEST_PATH, errors)
	if not errors.is_empty():
		_finish(errors)
		return
	_check_manifest_shape(manifest, profile, errors)
	_check_source_candidate(manifest, errors)
	_check_live_source_mapping(class_manifest, errors)
	_check_capture_files(manifest, errors)
	_check_negative_probes(manifest, errors)
	_finish(errors)


func _check_manifest_shape(manifest: Dictionary, profile: Dictionary, errors: Array[String]) -> void:
	var violations := _manifest_violations(manifest, profile)
	_expect(violations.is_empty(), "capture manifest must be complete: %s" % "; ".join(violations), errors)
	_expect(str(manifest.get("class_id", "")) == "engineer", "capture manifest must stay Engineer-local", errors)
	_expect(str(manifest.get("capture_script", "")) == "tests/ultimates/presentation/engineer_certification_live_capture.gd", "capture manifest must pin its renderer", errors)
	_expect(FileAccess.file_exists("res://%s" % str(manifest.get("capture_script", ""))), "capture renderer must exist", errors)
	for weapon_id in Capture.WEAPON_IDS:
		var timeline_scene := Capture.TIMELINE_SCENES.get(weapon_id) as PackedScene
		_expect(timeline_scene != null, "%s shipped timeline scene must load" % weapon_id, errors)
		var frames := Capture.VICTIM_FRAMES.get(weapon_id) as SpriteFrames
		_expect(frames != null and not frames.get_animation_names().is_empty(), "%s victim-impact flipbook must load" % weapon_id, errors)


func _check_source_candidate(manifest: Dictionary, errors: Array[String]) -> void:
	var base := manifest.get("capture_base", {}) as Dictionary
	_expect(str(base.get("sha", "")) == Capture.CAPTURE_BASE_SHA, "manifest must pin the capture base SHA", errors)
	_expect(str(base.get("tree", "")) == Capture.CAPTURE_BASE_TREE, "manifest must pin the capture base tree", errors)
	_expect(str(base.get("sha", "")) != "" and not str(manifest.get("final_commit_sha", "x")).begins_with("placeholder"), "provenance must not use a placeholder final hash", errors)


func _check_live_source_mapping(class_manifest: Dictionary, errors: Array[String]) -> void:
	var ids := _typed_weapon_ids(class_manifest.get("weapons", []) as Array)
	var expected := Capture.WEAPON_IDS.duplicate()
	expected.sort()
	_expect(ids == expected, "class manifest must enumerate exactly the canonical Engineer trio", errors)
	var live := (class_manifest.get("evidence", {}) as Dictionary).get("live_capture", {}) as Dictionary
	_expect(not live.is_empty(), "class manifest must publish its four-mode live capture evidence", errors)
	if not live.is_empty():
		_expect(str(live.get("certification_manifest", "")) == "docs/design/references/weapon_ultimates/engineer/certification_capture_manifest.json", "class manifest must point at the certification capture manifest", errors)
		_expect(int(live.get("mode_count", 0)) == Capture.MODE_IDS.size(), "class manifest must record all four presentation modes", errors)
		_expect(int(live.get("viewport_count", 0)) == Capture.CAPTURES.size(), "class manifest must record all four viewports", errors)


func _check_capture_files(manifest: Dictionary, errors: Array[String]) -> void:
	var viewports := _viewports_by_id(manifest)
	for raw_capture in Capture.CAPTURES:
		var capture := raw_capture as Dictionary
		var capture_id := str(capture.get("id", ""))
		var record := viewports.get(capture_id, {}) as Dictionary
		var path := str(record.get("path", ""))
		var expected_size := capture.get("size", Vector2i.ZERO) as Vector2i
		_expect(FileAccess.file_exists(path), "%s capture file must exist: %s" % [capture_id, path], errors)
		if not FileAccess.file_exists(path):
			continue
		var png_errors := _png_violations(path, expected_size)
		_expect(png_errors.is_empty(), "%s PNG/IHDR must be valid: %s" % [capture_id, "; ".join(png_errors)], errors)
		var actual_oid := "sha256:%s" % FileAccess.get_sha256(path).to_lower()
		_expect(actual_oid == str(record.get("lfs_object_id", "")), "%s LFS object ID must match the smudged PNG" % capture_id, errors)
		var image := Image.load_from_file(path)
		_expect(image != null and not image.is_empty() and image.get_size() == expected_size, "%s PNG must decode at its declared viewport size" % capture_id, errors)
		if image != null and not image.is_empty():
			_check_readability_pixels(image, expected_size, capture_id, errors)


func _check_readability_pixels(image: Image, size: Vector2i, capture_id: String, errors: Array[String]) -> void:
	_expect(_color_near(image.get_pixelv(Capture.hud_probe(size)), Capture.HUD_COLOR), "%s HUD probe must remain readable" % capture_id, errors)
	for weapon_index in Capture.WEAPON_IDS.size():
		for mode_index in Capture.MODE_IDS.size():
			var mode_id := Capture.MODE_IDS[mode_index]
			var mode := Capture.mode_spec(mode_id)
			var marker := image.get_pixelv(Capture.mode_marker_probe(size, weapon_index, mode_index))
			_expect(_color_near(marker, mode.get("marker_color", Color.WHITE) as Color), "%s must visibly contain %s for %s" % [capture_id, mode_id, Capture.WEAPON_IDS[weapon_index]], errors)
			_expect(_color_near(image.get_pixelv(Capture.player_probe(size, weapon_index, mode_index)), Capture.PLAYER_COLOR), "%s player must remain readable in %s/%s" % [capture_id, Capture.WEAPON_IDS[weapon_index], mode_id], errors)
			_expect(_color_near(image.get_pixelv(Capture.hazard_probe(size, weapon_index, mode_index)), Capture.HAZARD_COLOR), "%s critical hazard must remain readable in %s/%s" % [capture_id, Capture.WEAPON_IDS[weapon_index], mode_id], errors)


func _check_negative_probes(manifest: Dictionary, errors: Array[String]) -> void:
	var profile := _load_json(PROFILE_PATH, errors)
	if not errors.is_empty():
		return
	var missing_viewport := manifest.duplicate(true)
	(missing_viewport.get("viewports", []) as Array).remove_at(0)
	_expect(not _manifest_violations(missing_viewport, profile).is_empty(), "missing viewport must fail closed", errors)
	var wrong_viewport := manifest.duplicate(true)
	var wrong_record := (wrong_viewport.get("viewports", []) as Array)[0] as Dictionary
	wrong_record["width"] = int(wrong_record.get("width", 0)) - 1
	_expect(not _manifest_violations(wrong_viewport, profile).is_empty(), "wrong viewport size must fail closed", errors)
	var missing_weapon := manifest.duplicate(true)
	(missing_weapon.get("canonical_weapon_ids", []) as Array).remove_at(0)
	_expect(not _manifest_violations(missing_weapon, profile).is_empty(), "missing canonical weapon key must fail closed", errors)
	var missing_mode := manifest.duplicate(true)
	(missing_mode.get("presentation_modes", []) as Array).remove_at(0)
	_expect(not _manifest_violations(missing_mode, profile).is_empty(), "missing presentation mode must fail closed", errors)
	var missing_file := _png_violations("res://docs/design/reference-assets-lfs/ultimate-certification/engineer/engineer_ultimate_certification_missing.png", Vector2i(1152, 648))
	_expect(missing_file.has("missing"), "a missing capture file must fail closed", errors)
	var first_capture := Capture.CAPTURES[0] as Dictionary
	var wrong_size_errors := _png_violations(str(first_capture.get("path", "")), Vector2i(1, 1))
	_expect(not wrong_size_errors.is_empty(), "wrong PNG dimensions must fail closed", errors)
	var pointer := FileAccess.open(POINTER_FIXTURE_PATH, FileAccess.WRITE)
	if pointer == null:
		errors.append("cannot write LFS-pointer negative fixture")
		return
	pointer.store_string("version https://git-lfs.github.com/spec/v1\noid sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\nsize 1\n")
	pointer.close()
	_expect(not _png_violations(POINTER_FIXTURE_PATH, Vector2i(1, 1)).is_empty(), "an unsmudged LFS pointer must fail PNG validation", errors)


func _manifest_violations(manifest: Dictionary, profile: Dictionary) -> Array[String]:
	var violations: Array[String] = []
	if str(manifest.get("class_id", "")) != "engineer":
		violations.append("class_id")
	if str(manifest.get("capture_script", "")) != "tests/ultimates/presentation/engineer_certification_live_capture.gd":
		violations.append("capture_script")
	var expected_weapons := _profile_weapon_ids(profile)
	expected_weapons.sort()
	var declared_weapons := _string_array(manifest.get("canonical_weapon_ids", []))
	declared_weapons.sort()
	var sorted_capture := Capture.WEAPON_IDS.duplicate()
	sorted_capture.sort()
	if declared_weapons != expected_weapons or declared_weapons != sorted_capture:
		violations.append("canonical_weapon_ids")
	var declared_modes := _mode_ids(manifest.get("presentation_modes", []))
	if declared_modes != Capture.MODE_IDS:
		violations.append("presentation_modes")
	var viewports := _viewports_by_id(manifest)
	if viewports.size() != Capture.CAPTURES.size():
		violations.append("viewport_count")
	for raw_capture in Capture.CAPTURES:
		var capture := raw_capture as Dictionary
		var capture_id := str(capture.get("id", ""))
		var viewport := viewports.get(capture_id, {}) as Dictionary
		var size := capture.get("size", Vector2i.ZERO) as Vector2i
		if viewport.is_empty() \
				or int(viewport.get("width", -1)) != size.x \
				or int(viewport.get("height", -1)) != size.y \
				or str(viewport.get("path", "")) != str(capture.get("path", "")) \
				or not _is_lfs_oid(str(viewport.get("lfs_object_id", ""))):
			violations.append("viewport:%s" % capture_id)
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


func _viewports_by_id(manifest: Dictionary) -> Dictionary:
	var result := {}
	for raw_viewport in manifest.get("viewports", []) as Array:
		if raw_viewport is Dictionary:
			var viewport := raw_viewport as Dictionary
			var capture_id := str(viewport.get("id", ""))
			if not capture_id.is_empty() and not result.has(capture_id):
				result[capture_id] = viewport
	return result


func _profile_weapon_ids(profile: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for raw_weapon in profile.get("profiles", []) as Array:
		if raw_weapon is Dictionary:
			ids.append(str((raw_weapon as Dictionary).get("weapon_id", "")))
	return ids


func _typed_weapon_ids(raw_weapons: Array) -> Array[String]:
	var ids: Array[String] = []
	for raw_weapon in raw_weapons:
		if raw_weapon is Dictionary:
			ids.append(str((raw_weapon as Dictionary).get("weapon_id", "")))
	ids.sort()
	return ids


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
		for raw_value in raw_values as Array:
			values.append(str(raw_value))
	return values


func _is_lfs_oid(value: String) -> bool:
	if not value.begins_with("sha256:"):
		return false
	var digest := value.trim_prefix("sha256:")
	if digest.length() != 64:
		return false
	for character in digest:
		if not "0123456789abcdef".contains(character):
			return false
	return true


func _color_near(actual: Color, expected: Color) -> bool:
	return absf(actual.r - expected.r) <= 0.06 \
			and absf(actual.g - expected.g) <= 0.06 \
			and absf(actual.b - expected.b) <= 0.06 \
			and absf(actual.a - expected.a) <= 0.06


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
	if errors.is_empty():
		print("FAN-3939 Engineer four-mode certification capture package: PASS")
		quit(0)
		return
	for error in errors:
		push_error("FAN-3939 Engineer certification capture package: %s" % error)
	quit(1)
