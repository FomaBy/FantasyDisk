extends SceneTree

## FAN-3938 fail-closed integrity gate for the windowed Dark Mage capture.
##
## The paired renderer is the only component that creates images. This headless
## gate verifies that the committed artifacts are hydrated native PNGs, the
## complete runtime matrix is present, and the declared observations come from
## the real persisted-settings -> Main -> Player activation route. It does not
## paint or probe certification marker pixels: image bytes are checked only for
## materialization, dimensions, hashes, and non-empty rendered variation.

const CAPTURE_MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/dark_mage/certification_capture_manifest.json"
const CLASS_MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/dark_mage/manifest.json"
const REPORT_PATH := "res://docs/design/references/weapon_ultimates/dark_mage/certification_readability_report.md"
const LIVE_CAPTURE_SCRIPT := "res://tests/ultimates/presentation/dark_mage_certification_live_capture.gd"
const CAPTURE_ROOT := "res://docs/design/reference-assets-lfs/ultimate-certification/dark_mage"
const POINTER_FIXTURE_PATH := "user://fan3938_dark_mage_lfs_pointer_probe.png"
const LFS_POINTER_PREFIX := "version https://git-lfs.github.com/spec/v1"
const SHA256_LENGTH := 64
const GIT_SHA_LENGTH := 40

const WEAPON_IDS: Array[String] = ["dark_book", "cursed_skull", "dark_wand"]
const MODE_IDS: Array[String] = ["normal", "crowded", "reduced_motion", "photosensitivity_safe"]
const PHASE_IDS: Array[String] = ["release", "active", "recovery"]
const VIEWPORTS := {
	"1152x648": Vector2i(1152, 648),
	"1280x720": Vector2i(1280, 720),
	"1920x1080": Vector2i(1920, 1080),
	"2560x1440": Vector2i(2560, 1440),
}
const MODE_SETTINGS := {
	"normal": {"ultimate_reduced_motion": false, "ultimate_photosensitivity_safe": false, "crowded": false},
	"crowded": {"ultimate_reduced_motion": false, "ultimate_photosensitivity_safe": false, "crowded": true},
	"reduced_motion": {"ultimate_reduced_motion": true, "ultimate_photosensitivity_safe": false, "crowded": false},
	"photosensitivity_safe": {"ultimate_reduced_motion": false, "ultimate_photosensitivity_safe": true, "crowded": false},
}
const REQUIRED_ARTWORK_BY_PHASE := {
	"dark_book": {
		"release": ["AbyssMirror", "ReflectionLeft", "ReflectionRight"],
		"active": ["AbyssMirror", "ReflectionLeft", "ReflectionRight"],
		"recovery": ["AbyssMirror", "ReflectionLeft", "ReflectionRight"],
	},
	"cursed_skull": {
		"release": ["CursedCrown"],
		"active": ["CursedCrown", "SoulOrbitLeft", "SoulOrbitRight"],
		"recovery": ["CursedCrown", "SoulOrbitLeft", "SoulOrbitRight"],
	},
	"dark_wand": {
		"release": ["VanishingThread"],
		"active": ["VanishingThread", "ThreadEchoNear"],
		"recovery": ["VanishingThread", "ThreadEchoNear", "ThreadEchoFar"],
	},
}


func _initialize() -> void:
	var errors: Array[String] = []
	var certification := _load_json(CAPTURE_MANIFEST_PATH, errors)
	var class_manifest := _load_json(CLASS_MANIFEST_PATH, errors)
	if errors.is_empty():
		for violation in _manifest_violations(certification, class_manifest):
			errors.append(violation)
		_check_harness_registration(certification, class_manifest, errors)
		_check_capture_files(certification, errors)
		_check_negative_probes(certification, class_manifest, errors)
	_finish(errors)


func _check_harness_registration(certification: Dictionary, class_manifest: Dictionary, errors: Array[String]) -> void:
	_expect(FileAccess.file_exists(LIVE_CAPTURE_SCRIPT), "windowed live capture runner must exist", errors)
	_expect(FileAccess.file_exists(REPORT_PATH), "class-owned readability report must exist", errors)
	var source := FileAccess.get_file_as_string(LIVE_CAPTURE_SCRIPT)
	for required in [
		"GAME_SETTINGS.save_settings",
		"MAIN_SCENE_PATH",
		"Player.activate_ultimate()",
		"current_player.activate_ultimate",
		"_spawn_random_enemy",
		"CombatHudRoot",
		"root.get_texture().get_image",
		"DisplayServer.window_set_size",
		"release, active, and recovery",
		"DARK_MAGE_CERT_SOURCE_SHA",
	]:
		_expect(source.contains(required), "live renderer must retain production evidence hook: %s" % required, errors)
	for forbidden in ["Polygon2D.new", "scene.scale", "scene.modulate", "HUD_COLOR", "MARKER_COLOR"]:
		_expect(not source.contains(forbidden), "live renderer must not synthesize stand-in evidence: %s" % forbidden, errors)
	var evidence := class_manifest.get("evidence", {}) as Dictionary
	var certification_link := evidence.get("certification_capture", {}) as Dictionary
	_expect(
		str(certification_link.get("manifest", "")) == CAPTURE_MANIFEST_PATH.trim_prefix("res://"),
		"class manifest must link the certification manifest with evidence.certification_capture", errors)
	_expect(
		str(certification_link.get("capture_script", "")) == LIVE_CAPTURE_SCRIPT.trim_prefix("res://"),
		"class manifest must link the windowed renderer", errors)
	_expect(
		str(certification_link.get("focused_test", "")) == "tests/ultimates/presentation/dark_mage_certification_capture_test.gd",
		"class manifest must link this integrity gate", errors)
	_expect(
		str(certification_link.get("readability_report", "")) == REPORT_PATH.trim_prefix("res://"),
		"class manifest must link the readability report", errors)
	_expect(
		str(certification_link.get("capture_root", "")) == CAPTURE_ROOT.trim_prefix("res://"),
		"class manifest must register the class-owned LFS capture root", errors)
	var report := FileAccess.get_file_as_string(REPORT_PATH)
	var capture_source := certification.get("capture_source", {}) as Dictionary
	_expect(report.contains(str(capture_source.get("commit_sha", ""))), "report must repeat the capture source SHA", errors)
	_expect(report.contains("Dark Mage"), "report must contain class-specific readability observations", errors)


func _check_capture_files(certification: Dictionary, errors: Array[String]) -> void:
	var disk_files := {}
	var directory := DirAccess.open(CAPTURE_ROOT)
	_expect(directory != null, "certification capture root must exist", errors)
	if directory != null:
		for file_name in directory.get_files():
			if file_name.ends_with(".png"):
				disk_files[file_name] = true
	var declared_files := {}
	var mode_hashes := {}
	for raw_capture in certification.get("captures", []) as Array:
		if not raw_capture is Dictionary:
			continue
		var capture := raw_capture as Dictionary
		var key := _capture_key(capture)
		var path := "res://%s" % str(capture.get("path", ""))
		var expected_size := VIEWPORTS.get(str(capture.get("viewport_id", "")), Vector2i.ZERO) as Vector2i
		var file_name := path.get_file()
		declared_files[file_name] = true
		_expect(FileAccess.file_exists(path), "%s capture file must exist: %s" % [key, path], errors)
		if not FileAccess.file_exists(path):
			continue
		var png_errors := _png_violations(path, expected_size)
		_expect(png_errors.is_empty(), "%s PNG must be hydrated and native-sized: %s" % [key, "; ".join(png_errors)], errors)
		var actual_hash := FileAccess.get_sha256(path).to_lower()
		_expect(actual_hash == str(capture.get("sha256", "")).to_lower(), "%s stored PNG SHA-256 must match the hydrated artifact" % key, errors)
		_expect("sha256:%s" % actual_hash == str(capture.get("lfs_object_id", "")).to_lower(), "%s LFS object ID must match the hydrated artifact" % key, errors)
		var image := Image.load_from_file(path)
		_expect(image != null and not image.is_empty() and image.get_size() == expected_size, "%s must decode at the declared native size" % key, errors)
		if image != null and not image.is_empty():
			_expect(_luminance_variation(image) >= 0.04, "%s must retain non-empty rendered variation" % key, errors)
		if str(capture.get("phase", "")) == "active":
			var mode_key := "%s/%s" % [str(capture.get("weapon_id", "")), str(capture.get("viewport_id", ""))]
			if not mode_hashes.has(mode_key):
				mode_hashes[mode_key] = {}
			(mode_hashes[mode_key] as Dictionary)[str(capture.get("mode", ""))] = actual_hash
	_expect(disk_files == declared_files, "capture root must contain exactly the declared PNG evidence; stale or unmanifested PNGs are not allowed", errors)
	for mode_key in mode_hashes:
		var hashes := (mode_hashes[mode_key] as Dictionary).values()
		_expect(hashes.size() == MODE_IDS.size(), "%s must retain all four active-mode artifacts" % mode_key, errors)
		var unique_hashes := {}
		for digest in hashes:
			unique_hashes[str(digest)] = true
		_expect(unique_hashes.size() == MODE_IDS.size(), "%s active captures must distinguish the real normal/crowded/accessibility states" % mode_key, errors)


func _check_negative_probes(certification: Dictionary, class_manifest: Dictionary, errors: Array[String]) -> void:
	var missing_mode := certification.duplicate(true)
	for index in range((missing_mode.get("captures", []) as Array).size() - 1, -1, -1):
		var record := (missing_mode.get("captures", []) as Array)[index] as Dictionary
		if str(record.get("mode", "")) == "crowded":
			(missing_mode.get("captures", []) as Array).remove_at(index)
	_expect(not _manifest_violations(missing_mode, class_manifest).is_empty(), "a missing mode must fail closed", errors)

	var missing_key := certification.duplicate(true)
	var first_record := (missing_key.get("captures", []) as Array)[0] as Dictionary
	(first_record.get("persisted_settings", {}) as Dictionary).erase("ultimate_photosensitivity_safe")
	_expect(not _manifest_violations(missing_key, class_manifest).is_empty(), "a missing persisted-mode key must fail closed", errors)

	var missing_file := certification.duplicate(true)
	((missing_file.get("captures", []) as Array)[0] as Dictionary)["path"] = "docs/design/reference-assets-lfs/ultimate-certification/dark_mage/missing.png"
	_expect(not _manifest_violations(missing_file, class_manifest).is_empty(), "a missing declared PNG file must fail closed", errors)

	var wrong_dimensions := certification.duplicate(true)
	((wrong_dimensions.get("captures", []) as Array)[0] as Dictionary)["width"] = 1
	_expect(not _manifest_violations(wrong_dimensions, class_manifest).is_empty(), "a wrong declared viewport dimension must fail closed", errors)

	var wrong_hash := certification.duplicate(true)
	((wrong_hash.get("captures", []) as Array)[0] as Dictionary)["sha256"] = "0".repeat(SHA256_LENGTH)
	_expect(not _manifest_violations(wrong_hash, class_manifest).is_empty(), "a malformed or mismatched artifact hash must fail closed", errors)

	var pointer := FileAccess.open(POINTER_FIXTURE_PATH, FileAccess.WRITE)
	if pointer == null:
		errors.append("cannot write disposable LFS-pointer negative fixture")
	else:
		pointer.store_string("%s\noid sha256:%s\nsize 1\n" % [LFS_POINTER_PREFIX, "0".repeat(SHA256_LENGTH)])
		pointer.close()
		_expect(_png_violations(POINTER_FIXTURE_PATH, Vector2i(1152, 648)).has("lfs_pointer"), "an unsmudged LFS pointer must fail PNG validation", errors)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(POINTER_FIXTURE_PATH))


func _manifest_violations(certification: Dictionary, class_manifest: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if int(certification.get("schema_version", 0)) != 2:
		errors.append("schema_version")
	if str(certification.get("issue", "")) != "FAN-3938":
		errors.append("issue")
	if str(certification.get("class_id", "")) != "dark_mage":
		errors.append("class_id")
	if _string_array(certification.get("canonical_weapon_ids", [])) != WEAPON_IDS:
		errors.append("canonical_weapon_ids")
	if _string_array(certification.get("observed_beats", [])) != PHASE_IDS:
		errors.append("observed_beats")
	for mode_error in _mode_declaration_violations(certification.get("presentation_modes", []) as Array):
		errors.append(mode_error)
	for viewport_error in _viewport_declaration_violations(certification.get("viewports", []) as Array):
		errors.append(viewport_error)
	var source := certification.get("capture_source", {}) as Dictionary
	var source_commit := str(source.get("commit_sha", "")).to_lower()
	var source_tree := str(source.get("tree_sha", "")).to_lower()
	if str(source.get("ref", "")).is_empty() or not _is_git_sha(source_commit) or not _is_git_sha(source_tree):
		errors.append("capture_source")
	elif OS.execute("git", ["show", "-s", "--format=%T", source_commit], [], false) != 0:
		errors.append("capture_source_commit_missing")
	elif OS.execute("git", ["merge-base", "--is-ancestor", source_commit, "HEAD"], [], false) != 0:
		errors.append("capture_source_not_pre_artifact")
	else:
		var output: Array = []
		if OS.execute("git", ["show", "-s", "--format=%T", source_commit], output, false) != 0 or output.is_empty() or str(output[0]).strip_edges().to_lower() != source_tree:
			errors.append("capture_source_tree_mismatch")
	var capture_meta := certification.get("capture", {}) as Dictionary
	for field in ["method", "capture_script", "focused_test", "fixed_fps", "deterministic_seed", "godot_version", "renderer", "platform", "real_runtime"]:
		if not capture_meta.has(field) or str(capture_meta.get(field, "")).is_empty():
			errors.append("capture.%s" % field)
	if str(capture_meta.get("capture_script", "")) != LIVE_CAPTURE_SCRIPT.trim_prefix("res://"):
		errors.append("capture.capture_script")
	if str(capture_meta.get("focused_test", "")) != "tests/ultimates/presentation/dark_mage_certification_capture_test.gd":
		errors.append("capture.focused_test")
	var runtime := capture_meta.get("real_runtime", {}) as Dictionary
	for field in ["main_scene", "hud", "player_activation", "hazards", "crowded_enemy_count"]:
		if not runtime.has(field) or str(runtime.get(field, "")).is_empty():
			errors.append("capture.real_runtime.%s" % field)
	var weapon_scenes := _weapon_scenes(class_manifest)
	var captures := certification.get("captures", []) as Array
	if captures.size() != WEAPON_IDS.size() * MODE_IDS.size() * VIEWPORTS.size() * PHASE_IDS.size():
		errors.append("capture_count")
	var seen := {}
	var seen_paths := {}
	for raw_capture in captures:
		if not raw_capture is Dictionary:
			errors.append("capture_record_type")
			continue
		var capture := raw_capture as Dictionary
		var weapon_id := str(capture.get("weapon_id", ""))
		var mode_id := str(capture.get("mode", ""))
		var viewport_id := str(capture.get("viewport_id", ""))
		var phase_id := str(capture.get("phase", ""))
		var key := "%s/%s/%s/%s" % [weapon_id, mode_id, viewport_id, phase_id]
		if seen.has(key):
			errors.append("duplicate_capture:%s" % key)
		seen[key] = true
		if not WEAPON_IDS.has(weapon_id) or not MODE_IDS.has(mode_id) or not VIEWPORTS.has(viewport_id) or not PHASE_IDS.has(phase_id):
			errors.append("capture_key:%s" % key)
			continue
		var expected_size := VIEWPORTS[viewport_id] as Vector2i
		if int(capture.get("width", 0)) != expected_size.x or int(capture.get("height", 0)) != expected_size.y:
			errors.append("capture_dimensions:%s" % key)
		var path := str(capture.get("path", ""))
		if not path.begins_with(CAPTURE_ROOT.trim_prefix("res://") + "/") or not path.ends_with(".png") or seen_paths.has(path):
			errors.append("capture_path:%s" % key)
		seen_paths[path] = true
		if not _is_sha(str(capture.get("sha256", ""))) or str(capture.get("lfs_object_id", "")) != "sha256:%s" % str(capture.get("sha256", "")).to_lower():
			errors.append("capture_hash:%s" % key)
		if str(capture.get("scene_path", "")) != str(weapon_scenes.get(weapon_id, "")):
			errors.append("capture_scene:%s" % key)
		elif not FileAccess.file_exists("res://%s" % str(capture.get("scene_path", ""))):
			errors.append("capture_scene_missing:%s" % key)
		var expected_mode := MODE_SETTINGS[mode_id] as Dictionary
		var settings := capture.get("persisted_settings", {}) as Dictionary
		if not settings.has("ultimate_reduced_motion") \
				or not settings.has("ultimate_photosensitivity_safe") \
				or bool(settings.get("ultimate_reduced_motion", false)) != bool(expected_mode["ultimate_reduced_motion"]) \
				or bool(settings.get("ultimate_photosensitivity_safe", false)) != bool(expected_mode["ultimate_photosensitivity_safe"]) \
				or bool(capture.get("crowded", false)) != bool(expected_mode["crowded"]):
			errors.append("capture_mode:%s" % key)
		var expected_hazards := 39 if bool(expected_mode["crowded"]) else 8
		if int(capture.get("representative_enemy_count", 0)) != expected_hazards:
			errors.append("capture_hazard_count:%s" % key)
		var observations := capture.get("observed_beats", {}) as Dictionary
		for beat_id in PHASE_IDS:
			var observation := observations.get(beat_id, {}) as Dictionary
			if observation.is_empty() or str(observation.get("driver_phase", "")) != beat_id \
					or not bool(observation.get("hud_visible", false)) \
					or not bool(observation.get("artwork_visible", false)) \
					or int(observation.get("enemy_hazards_visible", 0)) <= 0 \
					or float(observation.get("luminance_variation", 0.0)) < 0.04 \
					or not _is_sha(str(observation.get("rgba_sha256", ""))):
				errors.append("observation:%s/%s" % [key, beat_id])
				continue
			if bool(observation.get("driver_reduced_motion", false)) != bool(expected_mode["ultimate_reduced_motion"]) \
					or bool(observation.get("driver_photosensitivity_safe", false)) != bool(expected_mode["ultimate_photosensitivity_safe"]):
				errors.append("observation_mode:%s/%s" % [key, beat_id])
			if _string_array(observation.get("visible_authored_nodes", [])) != _string_array((REQUIRED_ARTWORK_BY_PHASE[weapon_id] as Dictionary)[beat_id]):
				errors.append("observation_artwork:%s/%s" % [key, beat_id])
		var captured := capture.get("capture_observation", {}) as Dictionary
		if str(captured.get("phase", "")) != phase_id \
				or str(captured.get("path", "")) != path \
				or str(captured.get("sha256", "")) != str(capture.get("sha256", "")):
			errors.append("capture_observation:%s" % key)
	for weapon_id in WEAPON_IDS:
		for mode_id in MODE_IDS:
			for viewport_id in VIEWPORTS:
				for phase_id in PHASE_IDS:
					var required_key := "%s/%s/%s/%s" % [weapon_id, mode_id, viewport_id, phase_id]
					if not seen.has(required_key):
						errors.append("missing_capture:%s" % required_key)
	return errors


func _mode_declaration_violations(raw_modes: Array) -> Array[String]:
	var errors: Array[String] = []
	if raw_modes.size() != MODE_IDS.size():
		return ["presentation_modes_count"]
	for index in MODE_IDS.size():
		if not raw_modes[index] is Dictionary:
			errors.append("presentation_mode_type")
			continue
		var record := raw_modes[index] as Dictionary
		var mode_id := MODE_IDS[index]
		var configuration := record.get("configuration", {}) as Dictionary
		var expected := MODE_SETTINGS[mode_id] as Dictionary
		if str(record.get("id", "")) != mode_id \
				or bool(configuration.get("ultimate_reduced_motion", false)) != bool(expected["ultimate_reduced_motion"]) \
				or bool(configuration.get("ultimate_photosensitivity_safe", false)) != bool(expected["ultimate_photosensitivity_safe"]) \
				or int(configuration.get("director_enemy_count", 0)) != (39 if bool(expected["crowded"]) else 8) \
				or str(record.get("intent", "")).is_empty():
			errors.append("presentation_mode:%s" % mode_id)
	return errors


func _viewport_declaration_violations(raw_viewports: Array) -> Array[String]:
	var errors: Array[String] = []
	if raw_viewports.size() != VIEWPORTS.size():
		return ["viewport_count"]
	for viewport_id in VIEWPORTS:
		var expected := VIEWPORTS[viewport_id] as Vector2i
		var found := {}
		for raw_viewport in raw_viewports:
			if raw_viewport is Dictionary and str((raw_viewport as Dictionary).get("id", "")) == viewport_id:
				found = raw_viewport as Dictionary
				break
		if found.is_empty() or int(found.get("width", 0)) != expected.x or int(found.get("height", 0)) != expected.y:
			errors.append("viewport:%s" % viewport_id)
	return errors


func _png_violations(path: String, expected_size: Vector2i) -> Array[String]:
	var errors: Array[String] = []
	if not FileAccess.file_exists(path):
		return ["missing"]
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 24:
		return ["truncated"]
	var signature := PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10])
	if file.get_buffer(signature.size()) != signature:
		file.seek(0)
		var pointer_head := file.get_buffer(LFS_POINTER_PREFIX.length())
		file.close()
		return ["lfs_pointer" if pointer_head == LFS_POINTER_PREFIX.to_utf8_buffer() else "not_png"]
	file.big_endian = true
	var ihdr_length := file.get_32()
	var chunk_type := file.get_buffer(4).get_string_from_ascii()
	var width := file.get_32()
	var height := file.get_32()
	file.close()
	if ihdr_length != 13 or chunk_type != "IHDR":
		errors.append("missing_ihdr")
	elif width != expected_size.x or height != expected_size.y:
		errors.append("ihdr_size:%dx%d" % [width, height])
	return errors


func _luminance_variation(image: Image) -> float:
	image.convert(Image.FORMAT_RGBA8)
	var minimum := 1.0
	var maximum := 0.0
	for y in range(0, image.get_height(), 16):
		for x in range(0, image.get_width(), 16):
			var pixel := image.get_pixel(x, y)
			var luminance := 0.2126 * pixel.r + 0.7152 * pixel.g + 0.0722 * pixel.b
			minimum = minf(minimum, luminance)
			maximum = maxf(maximum, luminance)
	return maximum - minimum


func _weapon_scenes(class_manifest: Dictionary) -> Dictionary:
	var result := {}
	for raw_weapon in class_manifest.get("weapons", []) as Array:
		if raw_weapon is Dictionary:
			var weapon := raw_weapon as Dictionary
			result[str(weapon.get("weapon_id", ""))] = str(weapon.get("scene_path", ""))
	return result


func _load_json(path: String, errors: Array[String]) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("missing JSON: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		errors.append("invalid JSON: %s" % path)
		return {}
	return parsed as Dictionary


func _capture_key(capture: Dictionary) -> String:
	return "%s/%s/%s/%s" % [capture.get("weapon_id", ""), capture.get("mode", ""), capture.get("viewport_id", ""), capture.get("phase", "")]


func _string_array(raw: Variant) -> Array[String]:
	var values: Array[String] = []
	for value in raw as Array:
		values.append(str(value))
	return values


func _is_sha(value: String) -> bool:
	if value.length() != SHA256_LENGTH:
		return false
	for character in value:
		if not (character >= "0" and character <= "9") and not (character >= "a" and character <= "f"):
			return false
	return true


func _is_git_sha(value: String) -> bool:
	if value.length() != GIT_SHA_LENGTH:
		return false
	for character in value:
		if not (character >= "0" and character <= "9") and not (character >= "a" and character <= "f"):
			return false
	return true


func _expect(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)


func _finish(errors: Array[String]) -> void:
	if errors.is_empty():
		print("dark_mage_certification_capture_test: PASS (144 native phase captures; static and hydrated evidence verified)")
		quit(0)
		return
	for error in errors:
		push_error("dark_mage_certification_capture_test: %s" % error)
	quit(1)
