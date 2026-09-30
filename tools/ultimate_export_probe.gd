extends Node2D

## FAN-3985 exported-build probe for the 51 weapon ultimates.
##
## This script never ships: `tools/*` is excluded from every export preset.
## `tools/ultimate_export_probe.py` copies the exported app, drops an
## `override.cfg` beside its executable that points `run/main_scene` at a
## generated scene carrying this script, and starts the exported binary. The
## registry, package discovery, presentation bridge and presentation runtime
## that run here are therefore the exported PCK's own remapped scripts and
## data — the code path the player runs — not the editor tree.
##
## For every canonical class/weapon pair the probe records the registry's
## `resolution_source`, lazy executor admission, the resolved presentation
## record and scene, manifest validation and `begin()` of the real
## presentation runtime with the authored scene instantiated (headless mode
## forced off, exactly as the headless presentation suites do). The report is
## JSON; the orchestrator judges it. With `--captures=<dir>` in a windowed run
## it additionally screenshots one weapon per class at its `active` beat.
##
## User arguments (after `--`):
##   --report=<absolute path>      JSON report (required)
##   --captures=<absolute dir>     write PNG captures (windowed run only)
##   --capture-all                 capture all 51 pairs instead of one per class

const PROGRESSION_DATA_PATH := "res://scripts/progression_data.gd"
const REGISTRY_PATH := "res://scripts/ultimates/registry/weapon_ultimate_registry.gd"
const RESOLVER_PATH := "res://scripts/ultimates/registry/weapon_ultimate_resolver.gd"
const MANIFEST_PATH := "res://scripts/ultimates/presentation/weapon_ultimate_presentation_manifest.gd"
const SCHEMA_PATH := "res://scripts/ultimates/presentation/weapon_ultimate_presentation_schema.gd"
const RUNTIME_PATH := "res://scripts/ultimates/presentation/weapon_ultimate_presentation_runtime.gd"
const DOCS_MANIFEST_PROBE := "res://docs/design/references/weapon_ultimates/knight/manifest.json"
const EXPECTED_PAIRS := 51
const EXPECTED_CLASSES := 17
const CAPTURE_SETTLE_SECONDS := 0.2
## Captures run at 1280x720; the camera doubles the effect so a reviewer can
## read the class silhouette without zooming the PNG.
const CAPTURE_ZOOM := 2.0
const FRAME_SECONDS := 1.0 / 60.0

var _report_path := ""
var _capture_dir := ""
var _capture_all := false
var _effect_parent: Node2D = null
var _camera: Camera2D = null
var _label: Label = null


func _ready() -> void:
	_parse_user_args()
	if _report_path.is_empty():
		push_error("ultimate_export_probe: --report=<path> is required")
		get_tree().quit(2)
		return
	_build_stage()
	_run()


func _parse_user_args() -> void:
	for raw_arg in OS.get_cmdline_user_args():
		var arg := str(raw_arg)
		if arg.begins_with("--report="):
			_report_path = arg.trim_prefix("--report=")
		elif arg.begins_with("--captures="):
			_capture_dir = arg.trim_prefix("--captures=")
		elif arg == "--capture-all":
			_capture_all = true


func _build_stage() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.09, 0.08, 0.11, 1.0)
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	var layer := CanvasLayer.new()
	layer.layer = -100
	layer.add_child(backdrop)
	add_child(layer)
	_effect_parent = Node2D.new()
	_effect_parent.name = "UltimateHost"
	add_child(_effect_parent)
	_camera = Camera2D.new()
	_camera.name = "ProbeCamera"
	_camera.zoom = Vector2(CAPTURE_ZOOM, CAPTURE_ZOOM)
	_effect_parent.add_child(_camera)
	_camera.make_current()
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override("font_size", 18)
	overlay.add_child(_label)
	add_child(overlay)


## Host contract WeaponUltimatePresentationRuntime.begin() reads.
func ultimate_host_effect_parent() -> Node:
	return _effect_parent


func ultimate_host_position() -> Vector2:
	return _effect_parent.global_position


func _run() -> void:
	var report := {
		"probe": "tools/ultimate_export_probe.gd",
		"environment": _environment(),
		"pairs": [],
		"captures": [],
		"errors": [],
	}
	var errors: Array = report["errors"]
	var ProgressionData = load(PROGRESSION_DATA_PATH)
	var Registry = load(REGISTRY_PATH)
	var Resolver = load(RESOLVER_PATH)
	var Manifest = load(MANIFEST_PATH)
	var Schema = load(SCHEMA_PATH)
	var Runtime = load(RUNTIME_PATH)
	if ProgressionData == null or Registry == null or Resolver == null or Manifest == null \
			or Schema == null or Runtime == null:
		errors.append("a runtime script failed to load from the exported pack")
		_finish(report)
		return
	var registry = Registry.new(ProgressionData.WEAPONS_BY_CLASS)
	report["registry"] = {
		"valid": registry.is_valid(),
		"profile_count": registry.profile_count(),
		"package_pair_count": registry.package_pair_keys().size(),
		"validation_errors": registry.validation_errors(),
		"package_validation_errors": registry.package_validation_errors(),
		"text_validation_errors": registry.text_validation_errors(),
	}
	if not registry.is_valid():
		errors.append("registry is invalid: %s" % [registry.validation_errors()])
	var class_ids: Array = registry.class_ids()
	if class_ids.size() != EXPECTED_CLASSES:
		errors.append("expected %d classes, registry lists %d" % [EXPECTED_CLASSES, class_ids.size()])
	var pairs: Array = report["pairs"]
	var captured_classes := {}
	var is_headless := DisplayServer.get_name() == "headless"
	if not _capture_dir.is_empty() and is_headless:
		errors.append("--captures requires a windowed run; the display server is headless")
	for raw_class_id in class_ids:
		var class_id := str(raw_class_id)
		for raw_weapon_id in registry.weapon_ids(class_id):
			var weapon_id := str(raw_weapon_id)
			var entry := _probe_pair(registry, Resolver, Manifest, Schema, Runtime, class_id, weapon_id)
			var wants_capture := not _capture_dir.is_empty() and not is_headless \
				and (_capture_all or not captured_classes.has(class_id))
			if wants_capture and bool(entry.get("pass", false)):
				var capture := await _capture_pair(Runtime, registry, entry)
				entry["capture"] = capture
				(report["captures"] as Array).append(capture)
				if bool(capture.get("ok", false)):
					captured_classes[class_id] = true
				else:
					errors.append("capture failed for %s: %s" % [entry["key"], capture.get("error", "")])
			pairs.append(entry)
	if pairs.size() != EXPECTED_PAIRS:
		errors.append("expected %d pairs, probed %d" % [EXPECTED_PAIRS, pairs.size()])
	for raw_entry in pairs:
		var entry := raw_entry as Dictionary
		if not bool(entry.get("pass", false)):
			errors.append("%s: %s" % [entry["key"], entry.get("failures", [])])
	if not _capture_dir.is_empty() and not is_headless and captured_classes.size() != EXPECTED_CLASSES:
		errors.append("captured %d classes, expected %d" % [captured_classes.size(), EXPECTED_CLASSES])
	_finish(report)


func _probe_pair(registry, Resolver, Manifest, Schema, Runtime, class_id: String, weapon_id: String) -> Dictionary:
	var key := "%s/%s" % [class_id, weapon_id]
	var failures: Array[String] = []
	var entry := {"class_id": class_id, "weapon_id": weapon_id, "key": key}

	var source := str(registry.resolution_source(class_id, weapon_id))
	entry["resolution_source"] = source
	if source != Resolver.SOURCE_WEAPON_PROFILE:
		failures.append("resolution_source=%s" % source)

	var executor = registry.executor_for(class_id, weapon_id)
	entry["executor_admitted"] = executor != null
	entry["executor_script"] = str(executor.resource_path) if executor is Script else ""
	if executor == null:
		failures.append("executor not admitted: %s" % [registry.package_validation_errors()])

	var record: Dictionary = Manifest.class_weapon_record(class_id, weapon_id)
	entry["record_found"] = not record.is_empty()
	entry["scene_path"] = str(record.get("scene_path", ""))
	entry["scene_exists"] = not entry["scene_path"].is_empty() and ResourceLoader.exists(entry["scene_path"])
	if record.is_empty():
		failures.append("class_weapon_record is empty (document %s)" % Manifest.class_document_path(class_id))
	elif not bool(entry["scene_exists"]):
		failures.append("scene_path is not loadable: %s" % entry["scene_path"])
	elif not str(entry["scene_path"]).begins_with("res://scenes/vfx/ultimates/%s/" % class_id):
		failures.append("scene_path is not class-owned: %s" % entry["scene_path"])

	var profile: Dictionary = registry.catalog_profile_for(class_id, weapon_id)
	entry["implementation_state"] = str(profile.get("implementation_state", ""))
	var manifest: Dictionary = Manifest.manifest_for_profile(profile)
	var validation: Array = Schema.validate_manifest(manifest, profile) if not manifest.is_empty() else ["manifest_for_profile returned {}"]
	entry["manifest_validation_errors"] = validation
	if not validation.is_empty():
		failures.append("manifest validation: %s" % [validation])

	# Headless mode forced off: the authored scene is instantiated and the
	# declared budget is enforced, exactly as in a windowed run.
	var runtime = Runtime.new(0)
	var began := bool(runtime.begin(self, registry, profile))
	entry["begin_ok"] = began
	entry["budget_diagnostic"] = str(runtime.last_budget_diagnostic())
	var scene = runtime.get("_scene")
	entry["instantiated_scene_file"] = str(scene.scene_file_path) if scene is Node else ""
	entry["instantiated_scene_script"] = str(scene.get_script().resource_path) if scene is Node and scene.get_script() != null else ""
	if not began:
		failures.append("begin() returned false%s" % (": " + entry["budget_diagnostic"] if not entry["budget_diagnostic"].is_empty() else ""))
	elif not (scene is Node):
		failures.append("begin() succeeded without instantiating the presentation scene")
	elif str(scene.scene_file_path) != str(entry["scene_path"]):
		failures.append("instantiated scene %s differs from resolved %s" % [scene.scene_file_path, entry["scene_path"]])
	runtime.finish("cancel")
	_clear_effect_parent()

	entry["failures"] = failures
	entry["pass"] = failures.is_empty()
	return entry


func _capture_pair(Runtime, registry, entry: Dictionary) -> Dictionary:
	var class_id := str(entry["class_id"])
	var weapon_id := str(entry["weapon_id"])
	var profile: Dictionary = registry.catalog_profile_for(class_id, weapon_id)
	var runtime = Runtime.new(-1)
	var capture := {"key": entry["key"], "ok": false, "path": "", "beat": "active", "elapsed_seconds": 0.0}
	if not bool(runtime.begin(self, registry, profile)):
		capture["error"] = "begin() returned false: %s" % runtime.last_budget_diagnostic()
		_clear_effect_parent()
		return capture
	var record_timing: Dictionary = (load(MANIFEST_PATH).class_weapon_record(class_id, weapon_id) as Dictionary).get("timing", {})
	var active := float(record_timing.get("active", 0.0))
	var recovery := float(record_timing.get("recovery", active + 1.0))
	var target := active + maxf(CAPTURE_SETTLE_SECONDS, (recovery - active) * 0.35)
	_label.text = "FAN-3985 exported-build capture  %s  %s\nscene %s\n%s" % [
		entry["key"], "beat=active +%.2fs" % (target - active), entry["scene_path"], OS.get_executable_path()
	]
	var elapsed := 0.0
	var frames := int(ceil(target / FRAME_SECONDS))
	for _i in range(frames):
		await get_tree().process_frame
		var delta := get_process_delta_time()
		runtime.advance(delta)
		elapsed += delta
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s__%s.png" % [_capture_dir, class_id, weapon_id]
	var error := image.save_png(path)
	capture["elapsed_seconds"] = elapsed
	capture["viewport"] = [image.get_width(), image.get_height()]
	if error == OK:
		capture["ok"] = true
		capture["path"] = path
	else:
		capture["error"] = "save_png failed with %d" % error
	runtime.finish("cancel")
	_clear_effect_parent()
	_label.text = ""
	return capture


func _clear_effect_parent() -> void:
	for child in _effect_parent.get_children():
		if child == _camera:
			continue
		_effect_parent.remove_child(child)
		child.free()


func _environment() -> Dictionary:
	var documents := []
	if DirAccess.dir_exists_absolute("res://data/ultimates/presentation"):
		for name in DirAccess.get_files_at("res://data/ultimates/presentation"):
			documents.append(str(name))
	documents.sort()
	return {
		"editor_feature": OS.has_feature("editor"),
		"template_feature": OS.has_feature("template"),
		"release_feature": OS.has_feature("release"),
		"display_server": DisplayServer.get_name(),
		"executable_path": OS.get_executable_path(),
		"engine_version": Engine.get_version_info().get("string", ""),
		"user_args": OS.get_cmdline_user_args(),
		"docs_manifest_present": FileAccess.file_exists(DOCS_MANIFEST_PROBE),
		"presentation_documents": documents,
	}


func _finish(report: Dictionary) -> void:
	var errors: Array = report["errors"]
	report["pass"] = errors.is_empty()
	var file := FileAccess.open(_report_path, FileAccess.WRITE)
	if file == null:
		push_error("ultimate_export_probe: cannot write %s" % _report_path)
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	var passed := 0
	for raw_entry in report["pairs"]:
		if bool((raw_entry as Dictionary).get("pass", false)):
			passed += 1
	print("ultimate_export_probe: %d/%d pairs pass, %d errors, report %s" % [passed, (report["pairs"] as Array).size(), errors.size(), _report_path])
	for error in errors:
		print("ultimate_export_probe: FAIL %s" % str(error))
	get_tree().quit(0 if errors.is_empty() else 1)
