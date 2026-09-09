extends SceneTree

## FAN-3942 focused gate for the Doctor live certification capture package.
##
## The renderer produces the evidence; this suite decides whether the evidence
## is complete and whether it actually reads. It checks the declared coverage
## against the canonical class profile, the measured per-beat readability
## against the caps the class manifest already declares, and the committed
## sheets as real PNG bytes — signature, IHDR geometry, decode and content hash.
## Every validator is shown to go red on a mutated copy, so a missing mode, a
## missing weapon, a missing viewport, a missing file, an unsmudged LFS pointer
## or a wrong dimension cannot pass as evidence.
##
##     python3 tools/godot_gate.py --headless --path . \
##       --script res://tests/ultimates/presentation/doctor_certification_capture_test.gd

const Capture := preload("res://tests/ultimates/presentation/doctor_certification_live_capture.gd")
const Beats := preload("res://scripts/ultimates/presentation/contact_sheet_beats_contract.gd")
const Accessibility := preload("res://scripts/settings/ultimate_accessibility_settings.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "doctor"
const PROFILE_PATH := "res://data/ultimates/schema/v1/classes/doctor.json"
const CLASS_MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/doctor/manifest.json"
const CAPTURE_MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/doctor/certification_capture_manifest.json"
const POINTER_FIXTURE_PATH := "user://fan3942_doctor_capture_pointer.png"

## Readability floors. They sit well below every measured value in the committed
## package, so they fail on a real regression rather than on capture noise.
const MIN_HAZARDS_IN_FRAME := 4
const MIN_PLAYER_CONTRAST := 0.25
const MIN_HUD_BAND_CONTRAST := 0.35
const MIN_HUD_BANDS := 3
## The class declares `full_screen_flash_hz: 0.0` and
## `max_flash_coverage_ratio: 0.0`: no repeating full-screen flash at all. A
## frame whose near-white pixels pass this share is a full-screen flash.
const MAX_FLASH_PIXEL_RATIO := 0.05
const MIN_EFFECT_NODES_DRAWN := 1

const PNG_SIGNATURE := [137, 80, 78, 71, 13, 10, 26, 10]
const LFS_POINTER_PREFIX := "version https://git-lfs.github.com/spec/v1"
const SHA1_LENGTH := 40
const SHA256_LENGTH := 64


func _initialize() -> void:
	var errors: Array[String] = []
	var profile := _load_json(PROFILE_PATH, errors)
	var class_manifest := _load_json(CLASS_MANIFEST_PATH, errors)
	var manifest := _load_json(CAPTURE_MANIFEST_PATH, errors)
	if not errors.is_empty():
		_finish(errors)
		return

	errors.append_array(declaration_violations(manifest, profile))
	errors.append_array(coverage_violations(manifest, class_manifest))
	errors.append_array(readability_violations(manifest, class_manifest))
	errors.append_array(_sheet_violations(manifest))
	_check_class_manifest_registration(class_manifest, manifest, errors)
	_check_accessibility_modes(class_manifest, errors)
	_check_negative_probes(manifest, profile, class_manifest, errors)
	_finish(errors)


## The package must describe the canonical class, not a convenient subset of it.
func declaration_violations(manifest: Dictionary, profile: Dictionary) -> Array[String]:
	var violations: Array[String] = []
	if str(manifest.get("class_id", "")) != CLASS_ID:
		violations.append("capture manifest must be class-local to %s" % CLASS_ID)
	if str(manifest.get("issue", "")) != "FAN-3942":
		violations.append("capture manifest must record its issue")
	var canonical := _string_array(manifest.get("canonical_weapon_ids", []))
	var expected := _profile_weapon_ids(profile)
	if canonical != expected:
		violations.append("canonical weapon ids %s do not match the class profile %s" % [str(canonical), str(expected)])
	if canonical != _string_array(Capture.WEAPON_IDS):
		violations.append("canonical weapon ids do not match the capture script")
	var mode_ids: Array[String] = []
	for raw_mode in manifest.get("presentation_modes", []) as Array:
		mode_ids.append(str((raw_mode as Dictionary).get("id", "")))
	if mode_ids != _capture_mode_ids():
		violations.append("presentation modes %s do not match the four required modes %s" % [str(mode_ids), str(_capture_mode_ids())])
	if _string_array(manifest.get("beats", [])) != _string_array(Capture.BEAT_IDS):
		violations.append("declared beats must be release, active and recovery")
	var viewports := _viewports_by_id(manifest)
	if viewports.size() != Capture.VIEWPORTS.size():
		violations.append("expected %d declared viewports, found %d" % [Capture.VIEWPORTS.size(), viewports.size()])
	for raw_viewport in Capture.VIEWPORTS:
		var required := raw_viewport as Dictionary
		var id := str(required["id"])
		var size := required["size"] as Vector2i
		var declared := viewports.get(id, {}) as Dictionary
		if declared.is_empty():
			violations.append("viewport %s is not declared" % id)
			continue
		if int(declared.get("width", 0)) != size.x or int(declared.get("height", 0)) != size.y:
			violations.append("viewport %s declares %dx%d, expected %dx%d" % [
				id, int(declared.get("width", 0)), int(declared.get("height", 0)), size.x, size.y,
			])
	violations.append_array(_source_violations(manifest))
	violations.append_array(_capture_block_violations(manifest))
	return violations


## The capture must name a source that already exists. A manifest that pointed at
## the commit carrying it could never be verified.
func _source_violations(manifest: Dictionary) -> Array[String]:
	var violations: Array[String] = []
	var source := manifest.get("source", {}) as Dictionary
	if str(source.get("ref", "")).is_empty():
		violations.append("source.ref must name the captured checkout")
	var commit_sha := str(source.get("commit_sha", ""))
	var tree_sha := str(source.get("tree_sha", ""))
	for field in ["commit_sha", "tree_sha"]:
		var value := str(source.get(field, ""))
		if not _is_hex(value, SHA1_LENGTH):
			violations.append("source.%s must be a lowercase 40-hex object id, found %s" % [field, value])
	if _is_hex(commit_sha, SHA1_LENGTH) and _is_hex(tree_sha, SHA1_LENGTH):
		var output: Array = []
		if OS.execute("git", ["cat-file", "-e", "%s^{commit}" % commit_sha], output, true) != 0:
			violations.append("source.commit_sha must resolve to a Git commit in this checkout")
		else:
			output.clear()
			var status := OS.execute("git", ["rev-parse", "%s^{tree}" % commit_sha], output, true)
			var resolved_tree := "".join(output).strip_edges().to_lower()
			if status != 0 or resolved_tree != tree_sha:
				violations.append("source.tree_sha must be the tree owned by source.commit_sha")
			output.clear()
			if OS.execute("git", ["merge-base", "--is-ancestor", commit_sha, "HEAD"], output, true) != 0:
				violations.append("source.commit_sha must be an ancestor of the candidate under test")
	return violations


func _capture_block_violations(manifest: Dictionary) -> Array[String]:
	var violations: Array[String] = []
	var capture := manifest.get("capture", {}) as Dictionary
	for field in [
		"method", "capture_script", "focused_test", "godot_version", "renderer",
		"video_adapter", "platform", "beat_source", "captured_at",
	]:
		if str(capture.get(field, "")).is_empty():
			violations.append("capture.%s must be recorded" % field)
	if int(capture.get("seed", 0)) == 0:
		violations.append("capture.seed must record the pinned generator seed")
	if int(capture.get("fixed_fps", 0)) <= 0:
		violations.append("capture.fixed_fps must record the deterministic step")
	if not FileAccess.file_exists("res://%s" % str(capture.get("capture_script", ""))):
		violations.append("capture.capture_script must exist: %s" % str(capture.get("capture_script", "")))
	var commands := manifest.get("commands", {}) as Dictionary
	for field in ["live_capture", "focused_test", "static_guard", "lfs_integrity"]:
		if str(commands.get(field, "")).is_empty():
			violations.append("commands.%s must be recorded" % field)
	return violations


## Every weapon, in every mode, at every viewport, at every beat — or nothing.
func coverage_violations(manifest: Dictionary, class_manifest: Dictionary) -> Array[String]:
	var violations: Array[String] = []
	var scenes := _scene_paths(class_manifest)
	var viewports := _viewports_by_id(manifest)
	var seen := {}
	for raw_sample in manifest.get("samples", []) as Array:
		var sample := raw_sample as Dictionary
		var key := "%s/%s/%s/%s" % [
			str(sample.get("weapon_id", "")), str(sample.get("mode", "")),
			str(sample.get("viewport", "")), str(sample.get("beat", "")),
		]
		if seen.has(key):
			violations.append("duplicate sample %s" % key)
		seen[key] = sample
		var declared := viewports.get(str(sample.get("viewport", "")), {}) as Dictionary
		if int(sample.get("width", 0)) != int(declared.get("width", -1)) \
				or int(sample.get("height", 0)) != int(declared.get("height", -1)):
			violations.append("sample %s was measured at %dx%d, not at its declared viewport" % [
				key, int(sample.get("width", 0)), int(sample.get("height", 0)),
			])
		var expected_scene := str(scenes.get(str(sample.get("weapon_id", "")), ""))
		if str(sample.get("presentation_scene", "")) != expected_scene:
			violations.append("sample %s names scene %s, expected the shipped %s" % [
				key, str(sample.get("presentation_scene", "")), expected_scene,
			])
	for weapon_id in _string_array(manifest.get("canonical_weapon_ids", [])):
		for mode_id in _capture_mode_ids():
			for raw_viewport in Capture.VIEWPORTS:
				for beat_id in _string_array(manifest.get("beats", [])):
					var key := "%s/%s/%s/%s" % [weapon_id, mode_id, str((raw_viewport as Dictionary)["id"]), beat_id]
					if not seen.has(key):
						violations.append("missing live evidence for %s" % key)
	return violations


## Measured readability, judged against what the class already declares.
func readability_violations(manifest: Dictionary, class_manifest: Dictionary) -> Array[String]:
	var violations: Array[String] = []
	var weapons := _weapons_by_id(class_manifest)
	var declared_beats := Beats.frames_for_class(CLASS_ID)
	for raw_sample in manifest.get("samples", []) as Array:
		var sample := raw_sample as Dictionary
		var weapon_id := str(sample.get("weapon_id", ""))
		var mode_id := str(sample.get("mode", ""))
		var key := "%s/%s/%s/%s" % [weapon_id, mode_id, str(sample.get("viewport", "")), str(sample.get("beat", ""))]
		var weapon := weapons.get(weapon_id, {}) as Dictionary
		if weapon.is_empty():
			violations.append("sample %s names a weapon the class manifest does not carry" % key)
			continue
		var quality := weapon.get("quality", {}) as Dictionary
		var presence := weapon.get("presence", {}) as Dictionary
		if not bool(sample.get("required_nodes_present", false)):
			violations.append("%s: the beat's required presentation nodes were not drawn" % key)
		if int(sample.get("effect_nodes_drawn", 0)) < MIN_EFFECT_NODES_DRAWN:
			violations.append("%s: the live presentation drew nothing" % key)
		var coverage := float(sample.get("effect_box_ratio", 1.0))
		var cap := float(quality.get("max_viewport_coverage_ratio", 0.0))
		if cap <= 0.0:
			violations.append("%s: the class manifest declares no coverage cap" % key)
		elif coverage > cap:
			violations.append("%s: measured coverage %.4f is over the declared cap %.2f" % [key, coverage, cap])
		if bool(presence.get("fullscreen_footprint", false)) and float(sample.get("backdrop_box_ratio", 0.0)) < 1.0:
			violations.append("%s: the declared full-screen backdrop did not reach the viewport" % key)
		if not bool(sample.get("hud_bands_clear", false)):
			violations.append("%s: the presentation box overlapped a live HUD band" % key)
		if int(sample.get("hud_bands_measured", 0)) < MIN_HUD_BANDS:
			violations.append("%s: only %d live HUD bands were in frame" % [key, int(sample.get("hud_bands_measured", 0))])
		if float(sample.get("hud_band_min_contrast", 0.0)) < MIN_HUD_BAND_CONTRAST:
			violations.append("%s: HUD band contrast fell to %.3f" % [key, float(sample.get("hud_band_min_contrast", 0.0))])
		if float(sample.get("player_contrast", 0.0)) < MIN_PLAYER_CONTRAST:
			violations.append("%s: the player read fell to %.3f" % [key, float(sample.get("player_contrast", 0.0))])
		if float(sample.get("flash_pixel_ratio", 1.0)) > MAX_FLASH_PIXEL_RATIO:
			violations.append("%s: %.4f of the frame is near-white, which is a full-screen flash" % [
				key, float(sample.get("flash_pixel_ratio", 1.0)),
			])
		var hazards := int(sample.get("hazards_in_frame", 0))
		if mode_id == "crowded":
			var crowd_cap := int((weapon.get("performance", {}) as Dictionary).get("crowd_cap", 0))
			if hazards < crowd_cap:
				violations.append("%s: crowded mode held %d hazards, below the declared cap %d" % [key, hazards, crowd_cap])
		elif hazards < MIN_HAZARDS_IN_FRAME:
			violations.append("%s: only %d hazards stayed in frame" % [key, hazards])
		violations.append_array(_beat_time_violations(key, sample, weapon, declared_beats.get(weapon_id, [])))
	return violations


## Every sample must land on the exact frame-local beat declared by the shared
## contract. Release, active and recovery are all captured from the live scene.
func _beat_time_violations(key: String, sample: Dictionary, _weapon: Dictionary, declared: Variant) -> Array[String]:
	var violations: Array[String] = []
	var beat_id := str(sample.get("beat", ""))
	var declared_time := _declared_beat_time(declared, beat_id)
	if declared_time < 0.0:
		violations.append("%s: the shared beats contract declares no %s beat" % [key, beat_id])
		return violations
	if not is_equal_approx(float(sample.get("declared_beat_seconds", -1.0)), declared_time):
		violations.append("%s: declared beat time does not match the shared contract %.3f" % [key, declared_time])
	if not is_equal_approx(float(sample.get("beat_seconds", -1.0)), declared_time):
		violations.append("%s: sampled at %.3fs instead of its declared beat %.3fs" % [key, float(sample.get("beat_seconds", -1.0)), declared_time])
	return violations


func _declared_beat_time(declared: Variant, beat_id: String) -> float:
	if not declared is Array:
		return -1.0
	for raw_beat in declared as Array:
		var beat := raw_beat as Dictionary
		if str(beat.get("phase", "")) == beat_id:
			return float(beat.get("time", -1.0))
	return -1.0


## The committed sheets, as bytes on disk.
func _sheet_violations(manifest: Dictionary) -> Array[String]:
	var violations: Array[String] = []
	var matrix_viewports := {}
	var sheets := manifest.get("sheets", []) as Array
	if sheets.size() != Capture.VIEWPORTS.size():
		violations.append("expected one committed sheet per viewport, found %d" % sheets.size())
	for raw_sheet in sheets:
		var sheet := raw_sheet as Dictionary
		var path := "res://%s" % str(sheet.get("path", ""))
		var size := Vector2i(int(sheet.get("width", 0)), int(sheet.get("height", 0)))
		if str(sheet.get("kind", "")) == "mode_matrix":
			matrix_viewports[str(sheet.get("viewport", ""))] = true
		else:
			violations.append("%s declares an unknown sheet kind" % path)
		if not _is_hex(str(sheet.get("sha256", "")), SHA256_LENGTH):
			violations.append("%s must record a lowercase sha256 content hash" % path)
		for violation in png_violations(path, size):
			violations.append("%s: %s" % [path, violation])
		if FileAccess.file_exists(path):
			var digest := FileAccess.get_sha256(path).to_lower()
			if digest != str(sheet.get("sha256", "")).to_lower():
				violations.append("%s: content hash %s does not match the declared %s" % [
					path, digest, str(sheet.get("sha256", "")),
				])
	for raw_viewport in Capture.VIEWPORTS:
		var id := str((raw_viewport as Dictionary)["id"])
		if not matrix_viewports.has(id):
			violations.append("no mode-coverage sheet was committed for viewport %s" % id)
	return violations


## Real PNG bytes: an unsmudged LFS pointer, a truncated write and a wrong-sized
## sheet all look like a committed file until the header is read.
func png_violations(path: String, expected_size: Vector2i) -> Array[String]:
	var violations: Array[String] = []
	if not FileAccess.file_exists(path):
		violations.append("missing")
		return violations
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 24:
		violations.append("truncated")
		return violations
	var head := file.get_buffer(PNG_SIGNATURE.size())
	if head != PackedByteArray(PNG_SIGNATURE):
		file.seek(0)
		var text := file.get_buffer(LFS_POINTER_PREFIX.length())
		file.close()
		violations.append("lfs_pointer" if text == LFS_POINTER_PREFIX.to_utf8_buffer() else "not_png")
		return violations
	file.big_endian = true
	var ihdr_length := file.get_32()
	var chunk_type := file.get_buffer(4).get_string_from_ascii()
	var width := file.get_32()
	var height := file.get_32()
	file.close()
	if ihdr_length != 13 or chunk_type != "IHDR":
		violations.append("missing_ihdr")
		return violations
	if width != expected_size.x or height != expected_size.y:
		violations.append("ihdr_size:%dx%d" % [width, height])
		return violations
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		violations.append("decode_failed")
	elif image.get_size() != expected_size:
		violations.append("decoded_size:%s" % str(image.get_size()))
	return violations


## CI materializes exactly the LFS paths a class manifest lists under
## `evidence.contact_sheets`, so an unregistered sheet would reach the gate as an
## unsmudged pointer. `evidence.live_capture` is what declares this class as
## four-mode covered.
func _check_class_manifest_registration(class_manifest: Dictionary, manifest: Dictionary, errors: Array[String]) -> void:
	var evidence := class_manifest.get("evidence", {}) as Dictionary
	var hydrated := _string_array(evidence.get("contact_sheets", []))
	for raw_sheet in manifest.get("sheets", []) as Array:
		var path := str((raw_sheet as Dictionary).get("path", ""))
		if not hydrated.has(path):
			errors.append("sheet %s is not listed in evidence.contact_sheets, so CI would never materialize it" % path)
	var authored := _string_array(evidence.get("authored_timeline_sheets", []))
	if authored.size() != Capture.VIEWPORTS.size():
		errors.append("the four authored timeline sheets must stay declared as authored_timeline_sheets")
	for path in authored:
		if not FileAccess.file_exists("res://%s" % path):
			errors.append("authored timeline sheet %s must still exist" % path)
	var live := evidence.get("live_capture", {}) as Dictionary
	if live.is_empty():
		errors.append("the class manifest must declare evidence.live_capture")
		return
	if str(live.get("issue", "")) != "FAN-3942":
		errors.append("evidence.live_capture must record its issue")
	if _string_array(live.get("modes", [])) != _capture_mode_ids():
		errors.append("evidence.live_capture must declare all four presentation modes")
	if _string_array(live.get("weapon_ids", [])) != _string_array(manifest.get("canonical_weapon_ids", [])):
		errors.append("evidence.live_capture must declare the canonical weapon ids")
	var source := manifest.get("source", {}) as Dictionary
	for pair in [["source_commit_sha", "commit_sha"], ["source_tree_sha", "tree_sha"], ["source_ref", "ref"]]:
		if str(live.get(pair[0], "")) != str(source.get(pair[1], "")):
			errors.append("evidence.live_capture.%s must match the capture manifest" % pair[0])
	var viewports := live.get("viewports", {}) as Dictionary
	for raw_viewport in Capture.VIEWPORTS:
		var required := raw_viewport as Dictionary
		var size := required["size"] as Vector2i
		if str(viewports.get(str(required["id"]), "")) != "%dx%d" % [size.x, size.y]:
			errors.append("evidence.live_capture.viewports must declare %s as %dx%d" % [str(required["id"]), size.x, size.y])
	for field in ["capture_manifest", "readability_report", "capture_script", "focused_test"]:
		var path := str(live.get(field, ""))
		if path.is_empty() or not FileAccess.file_exists("res://%s" % path):
			errors.append("evidence.live_capture.%s must name an existing file, found %s" % [field, path])
	if str(live.get("capture_manifest", "")) != CAPTURE_MANIFEST_PATH.trim_prefix("res://"):
		errors.append("evidence.live_capture.capture_manifest must point at this package")


func _check_accessibility_modes(class_manifest: Dictionary, errors: Array[String]) -> void:
	var registry = Registry.new(PD.WEAPONS_BY_CLASS)
	var modes := [
		{"reduced": false, "photo": false},
		{"reduced": true, "photo": false},
		{"reduced": false, "photo": true},
		{"reduced": true, "photo": true},
	]
	for mode in modes:
		Accessibility.apply_snapshot(root, {
			Accessibility.REDUCED_MOTION_KEY: bool(mode["reduced"]),
			Accessibility.PHOTOSENSITIVITY_SAFE_KEY: bool(mode["photo"]),
		})
		root.set_meta("screen_shake", true)
		for raw_weapon in class_manifest.get("weapons", []) as Array:
			var weapon := raw_weapon as Dictionary
			var scene := (load("res://%s" % str(weapon.get("scene_path", ""))) as PackedScene).instantiate() as Node2D
			root.add_child(scene)
			if scene.has_method("begin"):
				scene.call("begin", registry, {}, 0)
			var state := scene.call("presence_snapshot") as Dictionary if scene.has_method("presence_snapshot") else {}
			var key := "%s/%s" % [CLASS_ID, str(weapon.get("weapon_id", ""))]
			_expect(bool(state.get("reduced_motion", false)) == bool(mode["reduced"]), "%s must apply the reduced-motion root flag" % key, errors)
			_expect(bool(state.get("photosensitivity_safe", false)) == bool(mode["photo"]), "%s must apply the photosensitivity-safe root flag" % key, errors)
			if bool(mode["reduced"]):
				_expect(int(state.get("motion_tracks_disabled", 0)) > 0, "%s reduced motion must replace a fast motion channel" % key, errors)
			if bool(mode["photo"]):
				_expect(int(state.get("photosensitive_nodes", 0)) > 0, "%s photosensitivity-safe must replace a bright authored surface" % key, errors)
			var backdrop := scene.get_node_or_null("BackdropLayer/BackdropVeil") as ColorRect
			_expect(backdrop != null and backdrop.get_meta("fullscreen_layer", false) == true, "%s must ship the screen-space darken backdrop" % key, errors)
			if scene.has_method("finish"):
				scene.call("finish", "cancel")
			scene.free()
	Accessibility.apply_snapshot(root, Accessibility.default_snapshot())


func _check_negative_probes(manifest: Dictionary, profile: Dictionary, class_manifest: Dictionary, errors: Array[String]) -> void:
	var missing_mode := manifest.duplicate(true)
	(missing_mode.get("presentation_modes", []) as Array).remove_at(0)
	_expect(not declaration_violations(missing_mode, profile).is_empty(), "a missing presentation mode must fail closed", errors)

	var missing_weapon := manifest.duplicate(true)
	(missing_weapon.get("canonical_weapon_ids", []) as Array).remove_at(0)
	_expect(not declaration_violations(missing_weapon, profile).is_empty(), "a missing canonical weapon must fail closed", errors)

	var missing_viewport := manifest.duplicate(true)
	(missing_viewport.get("viewports", []) as Array).remove_at(0)
	_expect(not declaration_violations(missing_viewport, profile).is_empty(), "a missing viewport must fail closed", errors)

	var wrong_viewport := manifest.duplicate(true)
	var wrong_record := (wrong_viewport.get("viewports", []) as Array)[0] as Dictionary
	wrong_record["width"] = int(wrong_record.get("width", 0)) - 1
	_expect(not declaration_violations(wrong_viewport, profile).is_empty(), "a wrong declared viewport size must fail closed", errors)

	var unpinned := manifest.duplicate(true)
	(unpinned.get("source", {}) as Dictionary)["commit_sha"] = "not-a-sha"
	_expect(not declaration_violations(unpinned, profile).is_empty(), "an unpinned capture source must fail closed", errors)

	var unknown_source := manifest.duplicate(true)
	(unknown_source.get("source", {}) as Dictionary)["commit_sha"] = "0".repeat(SHA1_LENGTH)
	_expect(not declaration_violations(unknown_source, profile).is_empty(), "an unknown 40-hex source commit must fail closed", errors)

	var wrong_tree := manifest.duplicate(true)
	(wrong_tree.get("source", {}) as Dictionary)["tree_sha"] = "0".repeat(SHA1_LENGTH)
	_expect(not declaration_violations(wrong_tree, profile).is_empty(), "a tree not owned by the source commit must fail closed", errors)

	var missing_key := manifest.duplicate(true)
	(missing_key.get("samples", []) as Array).remove_at(0)
	_expect(not coverage_violations(missing_key, class_manifest).is_empty(), "a missing weapon/mode/viewport/beat key must fail closed", errors)

	var wrong_scene := manifest.duplicate(true)
	((wrong_scene.get("samples", []) as Array)[0] as Dictionary)["presentation_scene"] = "res://scenes/vfx/ultimates/doctor/NotShipped.tscn"
	_expect(not coverage_violations(wrong_scene, class_manifest).is_empty(), "a sample that names an unshipped scene must fail closed", errors)

	var occluded := manifest.duplicate(true)
	((occluded.get("samples", []) as Array)[0] as Dictionary)["hud_bands_clear"] = false
	_expect(not readability_violations(occluded, class_manifest).is_empty(), "an occluded HUD band must fail closed", errors)

	var over_cap := manifest.duplicate(true)
	((over_cap.get("samples", []) as Array)[0] as Dictionary)["effect_box_ratio"] = 0.99
	_expect(not readability_violations(over_cap, class_manifest).is_empty(), "coverage over the declared cap must fail closed", errors)

	var flashed := manifest.duplicate(true)
	((flashed.get("samples", []) as Array)[0] as Dictionary)["flash_pixel_ratio"] = 0.8
	_expect(not readability_violations(flashed, class_manifest).is_empty(), "a full-screen flash must fail closed", errors)

	var empty_crowd := manifest.duplicate(true)
	for raw_sample in empty_crowd.get("samples", []) as Array:
		var sample := raw_sample as Dictionary
		if str(sample.get("mode", "")) == "crowded":
			sample["hazards_in_frame"] = 1
			break
	_expect(not readability_violations(empty_crowd, class_manifest).is_empty(), "a crowded capture below the declared crowd cap must fail closed", errors)

	var retimed := manifest.duplicate(true)
	((retimed.get("samples", []) as Array)[0] as Dictionary)["beat_seconds"] = 9.0
	_expect(not readability_violations(retimed, class_manifest).is_empty(), "a sample taken past its declared beat must fail closed", errors)

	var first_sheet := (manifest.get("sheets", []) as Array)[0] as Dictionary
	var real_path := "res://%s" % str(first_sheet.get("path", ""))
	_expect(not png_violations(real_path, Vector2i(1, 1)).is_empty(), "a wrong PNG dimension must fail closed", errors)
	_expect(png_violations("res://docs/design/reference-assets-lfs/ultimate-certification/doctor/absent.png", Vector2i(8, 8)).has("missing"), "a missing PNG must fail closed", errors)

	var wrong_hash := manifest.duplicate(true)
	((wrong_hash.get("sheets", []) as Array)[0] as Dictionary)["sha256"] = "0".repeat(SHA256_LENGTH)
	_expect(not _sheet_violations(wrong_hash).is_empty(), "a wrong sheet content hash must fail closed", errors)

	var pointer := FileAccess.open(POINTER_FIXTURE_PATH, FileAccess.WRITE)
	if pointer == null:
		errors.append("cannot write the LFS-pointer negative fixture")
		return
	pointer.store_string("%s\noid sha256:%s\nsize 1\n" % [LFS_POINTER_PREFIX, "0".repeat(SHA256_LENGTH)])
	pointer.close()
	_expect(
		png_violations(POINTER_FIXTURE_PATH, Vector2i(1152, 648)).has("lfs_pointer"),
		"an unsmudged LFS pointer must fail closed",
		errors
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(POINTER_FIXTURE_PATH))


func _profile_weapon_ids(profile: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for raw_entry in profile.get("profiles", []) as Array:
		ids.append(str((raw_entry as Dictionary).get("weapon_id", "")))
	return ids


func _weapons_by_id(class_manifest: Dictionary) -> Dictionary:
	var weapons := {}
	for raw_weapon in class_manifest.get("weapons", []) as Array:
		var weapon := raw_weapon as Dictionary
		weapons[str(weapon.get("weapon_id", ""))] = weapon
	return weapons


func _scene_paths(class_manifest: Dictionary) -> Dictionary:
	var scenes := {}
	for weapon_id in _weapons_by_id(class_manifest):
		var weapon := _weapons_by_id(class_manifest)[weapon_id] as Dictionary
		scenes[weapon_id] = str(weapon.get("scene_path", ""))
	return scenes


func _viewports_by_id(manifest: Dictionary) -> Dictionary:
	var viewports := {}
	for raw_viewport in manifest.get("viewports", []) as Array:
		var viewport := raw_viewport as Dictionary
		viewports[str(viewport.get("id", ""))] = viewport
	return viewports


func _capture_mode_ids() -> Array[String]:
	var ids: Array[String] = []
	for raw_mode in Capture.MODES:
		ids.append(str((raw_mode as Dictionary)["id"]))
	return ids


func _string_array(value: Variant) -> Array[String]:
	var items: Array[String] = []
	if value is Array:
		for entry in value as Array:
			items.append(str(entry))
	return items


func _is_hex(value: String, length: int) -> bool:
	if value.length() != length:
		return false
	for character in value:
		if not "0123456789abcdef".contains(character):
			return false
	return true


func _expect(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)


func _load_json(path: String, errors: Array[String]) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("%s is missing" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		errors.append("%s must contain a JSON object" % path)
		return {}
	return parsed as Dictionary


func _finish(errors: Array[String]) -> void:
	if errors.is_empty():
		print("FAN-3942 Doctor certification capture package: PASS")
		quit(0)
		return
	for error in errors:
		push_error("FAN-3942 Doctor certification capture package: %s" % error)
	quit(1)
