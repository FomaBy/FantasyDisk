extends SceneTree

## FAN-3985 editor-side export gate for the weapon ultimate runtime.
##
## The 0.3.1 builds lost every new weapon ultimate because the runtime read
## `docs/design/references/weapon_ultimates/<class>/manifest.json` while both
## export presets exclude `docs/*`. This suite reads the runtime-read roots
## straight from the script constants, expands them to the concrete files the
## exported game opens (class documents, package overlays and executors,
## presentation scenes, silhouettes, the shared SFX) and fails when any of
## them matches an `exclude_filter` fragment of the macOS or Windows Desktop
## preset. Filters are tested the way `EditorExportPlatform` tests them: with
## and without the `res://` prefix, case-insensitively, `*` spanning `/`.
##
## It also proves the bridge itself reads the exported location and fails
## closed without it, so a regression to a docs read cannot pass unnoticed.
##
## Run:
## python3 tools/godot_gate.py --headless --path . \
##   --script res://tests/ultimates/export_runtime_paths_test.gd

const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Discovery := preload("res://scripts/ultimates/registry/weapon_ultimate_package_discovery.gd")
const Text := preload("res://scripts/ultimates/registry/weapon_ultimate_text.gd")
const Manifest := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_manifest.gd")
const Schema := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_schema.gd")
const MigrationShards := preload("res://scripts/ultimates/presentation/presentation_v2_migration_shards.gd")

const EXPORT_PRESETS_PATH := "res://export_presets.cfg"
const PRESET_NAMES: Array[String] = ["macOS", "Windows Desktop"]
const EXPECTED_CLASSES := 17
const EXPECTED_PAIRS := 51
const OLD_DOCS_DOCUMENT := "res://docs/design/references/weapon_ultimates/knight/manifest.json"


func _initialize() -> void:
	var errors: Array[String] = []
	var filters := _exclude_filters(errors)
	var paths := _runtime_read_paths(errors)
	_check(paths.size() > EXPECTED_PAIRS, "runtime path expansion must list more than the 51 scenes, got %d" % paths.size(), errors)
	for preset_name in PRESET_NAMES:
		var fragments: Array = filters.get(preset_name, [])
		_check(not fragments.is_empty(), "preset %s must declare an exclude_filter" % preset_name, errors)
		for path in paths:
			var hits := _excluded_by(path, fragments)
			_check(hits.is_empty(), "preset %s excludes runtime-read path %s via %s" % [preset_name, path, hits], errors)
		_check(
			not _excluded_by(OLD_DOCS_DOCUMENT, fragments).is_empty(),
			"preset %s must keep excluding the docs manifests (%s)" % [preset_name, OLD_DOCS_DOCUMENT],
			errors
		)
	_check_bridge_reads_exported_location(errors)
	_check_filter_semantics(errors)
	_report(errors)


## Every `res://` location the exported ultimate runtime opens, expanded to
## concrete files so a filter on a deeper pattern is caught too.
func _runtime_read_paths(errors: Array[String]) -> Array[String]:
	var paths: Array[String] = []
	var roots: Array[String] = [
		Manifest.PRESENTATION_ROOT,
		Discovery.DATA_ROOT,
		Discovery.EXECUTOR_ROOT,
		Registry.CATALOG_DIRECTORY,
		MigrationShards.SHARD_ROOT,
	]
	for root in roots:
		_check(DirAccess.dir_exists_absolute(root), "runtime root must exist: %s" % root, errors)
		paths.append(root)
		_collect_files(root, paths)
	for file_path in [Schema.SCHEMA_PATH, Text.TEXT_PATH, Manifest.DEFAULT_SFX_PATH]:
		_check(ResourceLoader.exists(file_path) or FileAccess.file_exists(file_path), "runtime file must exist: %s" % file_path, errors)
		paths.append(file_path)
	var registry = Registry.new(PD.WEAPONS_BY_CLASS)
	_check(registry.is_valid(), "registry must be valid", errors)
	var classes: Array = registry.class_ids()
	_check(classes.size() == EXPECTED_CLASSES, "registry must list 17 classes", errors)
	var pair_count := 0
	for raw_class_id in classes:
		var class_id := str(raw_class_id)
		paths.append(Manifest.class_document_path(class_id))
		for raw_weapon_id in registry.weapon_ids(class_id):
			pair_count += 1
			var record: Dictionary = Manifest.class_weapon_record(class_id, str(raw_weapon_id))
			_check(not record.is_empty(), "%s/%s must resolve a presentation record" % [class_id, raw_weapon_id], errors)
			var scene_path := str(record.get("scene_path", ""))
			if not scene_path.is_empty():
				paths.append(scene_path)
			var identity = record.get("identity", {})
			if identity is Dictionary:
				var silhouette := str((identity as Dictionary).get("weapon_silhouette_asset", ""))
				if not silhouette.is_empty():
					paths.append(silhouette)
	_check(pair_count == EXPECTED_PAIRS, "registry must list 51 pairs, got %d" % pair_count, errors)
	return paths


func _collect_files(directory_path: String, paths: Array[String]) -> void:
	for file_name in DirAccess.get_files_at(directory_path):
		if file_name.ends_with(".uid") or file_name.ends_with(".import"):
			continue
		paths.append("%s/%s" % [directory_path, file_name])
	for directory_name in DirAccess.get_directories_at(directory_path):
		_collect_files("%s/%s" % [directory_path, directory_name], paths)


func _exclude_filters(errors: Array[String]) -> Dictionary:
	var result := {}
	var config := ConfigFile.new()
	if config.load(EXPORT_PRESETS_PATH) != OK:
		errors.append("cannot read %s" % EXPORT_PRESETS_PATH)
		return result
	for section in config.get_sections():
		if not section.begins_with("preset.") or section.contains(".options"):
			continue
		var name := str(config.get_value(section, "name", ""))
		var fragments: Array = []
		for raw_fragment in str(config.get_value(section, "exclude_filter", "")).split(","):
			var fragment := str(raw_fragment).strip_edges()
			if not fragment.is_empty():
				fragments.append(fragment)
		result[name] = fragments
	for preset_name in PRESET_NAMES:
		_check(result.has(preset_name), "export_presets.cfg must declare preset %s" % preset_name, errors)
	return result


## EditorExportPlatform tests each filter against the `res://` path and the
## same path without the prefix, with String.matchn().
static func _excluded_by(path: String, fragments: Array) -> Array[String]:
	var relative := path.trim_prefix("res://")
	var full := "res://%s" % relative
	var hits: Array[String] = []
	for raw_fragment in fragments:
		var fragment := str(raw_fragment)
		if full.matchn(fragment) or relative.matchn(fragment):
			hits.append(fragment)
	return hits


func _check_bridge_reads_exported_location(errors: Array[String]) -> void:
	_check(
		Manifest.PRESENTATION_ROOT.begins_with("res://data/"),
		"the presentation bridge must read from data/, got %s" % Manifest.PRESENTATION_ROOT,
		errors
	)
	_check(
		Manifest.class_document_path("knight") == "res://data/ultimates/presentation/knight.json",
		"class documents must live at data/ultimates/presentation/<class>.json",
		errors
	)
	_check(Manifest.class_document("__no_such_class__").is_empty(), "a missing class document must fail closed", errors)
	_check(Manifest.class_weapon_record("__no_such_class__", "long_spear").is_empty(), "a missing class document yields no record", errors)
	_check(Manifest.class_weapon_record("knight", "__no_such_weapon__").is_empty(), "an unknown weapon yields no record", errors)


func _check_filter_semantics(errors: Array[String]) -> void:
	_check(_excluded_by("res://docs/design/x.json", ["docs/*"]) == ["docs/*"], "docs/* must match a docs path", errors)
	_check(_excluded_by("res://data/docs/x.json", ["docs/*"]).is_empty(), "docs/* must not match a nested docs directory", errors)
	_check(_excluded_by("res://README.md", ["*.md"]) == ["*.md"], "*.md must match a markdown file", errors)
	_check(_excluded_by("res://data/ultimates/presentation/knight.json", ["docs/*", "tools/*", "*.md"]).is_empty(), "the runtime document must not match the standard exclusions", errors)


func _check(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)


func _report(errors: Array[String]) -> void:
	if errors.is_empty():
		print("Export runtime paths test passed: no runtime-read weapon ultimate path is excluded from the macOS or Windows Desktop export.")
		quit(0)
		return
	for error in errors:
		push_error("Export runtime paths test: %s" % error)
	push_error("Export runtime paths test: %d errors." % errors.size())
	quit(1)
