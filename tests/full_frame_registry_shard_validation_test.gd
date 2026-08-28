extends SceneTree

# FAN-3669 (rework of FAN-3638/FAN-3660, QA-rejected d3ddb939): the QA probe
# `FullFrameAnimationRegistry._entry_from_document({})` returned a usable-looking
# entry with empty/zeroed fields instead of being rejected, and malformed JSON
# was silently `continue`d without invalidating the catalog or catching
# duplicate canonical identities. This test drives the REAL loader
# (`_load_shards`, the file-list-driven core of `_load_kind`) against on-disk
# fixture shards — malformed JSON, a shard missing a required field, a shard
# with an invalid field type/value, and a case-insensitive duplicate identity
# pair — and proves every bad shard is excluded from the resulting table while
# the one valid shard in the same directory still loads (no partial/garbage
# entry, no collateral rejection).
#
# The duplicate pair is driven through an explicit file-name list rather than
# two real on-disk files: a case-preserving but case-INsensitive filesystem
# (default macOS/APFS) silently collapses "Duplicate_Actor.json" and
# "duplicate_actor.json" into a single physical file, so it cannot host a real
# duplicate-by-case fixture. `_load_shards` only needs the name list to detect
# the collision — the physical file backing either name resolves to the same
# valid content either way.
#
# Запуск: Godot --headless --path . --script res://tests/full_frame_registry_shard_validation_test.gd

const FullFrameAnimationRegistry := preload("res://scripts/full_frame_animation_registry.gd")

const FIXTURE_ROOT := "user://fan3669_shard_validation_fixture"
const FIXTURE_KIND := "testkind"


func _initialize() -> void:
	var errors: Array = []
	var fixture_dir := "%s/%s" % [FIXTURE_ROOT, FIXTURE_KIND]
	var file_names := _write_fixtures(fixture_dir, errors)

	var table: Dictionary = FullFrameAnimationRegistry._load_shards(FIXTURE_KIND, fixture_dir, file_names)

	if not table.has("valid_actor"):
		errors.append("valid_actor: a well-formed shard must still load.")
	elif str(table["valid_actor"].get("frames", "")) != "res://fixtures/valid_actor.tres":
		errors.append("valid_actor: loaded with the wrong 'frames' value — schema mapping broke.")

	if table.has("malformed_json"):
		errors.append("malformed_json: invalid JSON syntax must be rejected, not admitted.")

	if table.has("missing_frames"):
		errors.append("missing_frames: a shard missing the required 'frames' field must be rejected.")

	if table.has("invalid_scale_type"):
		errors.append("invalid_scale_type: a non-numeric 'scale.x' must be rejected.")

	if table.has("missing_source_faces_left"):
		errors.append("missing_source_faces_left: a shard missing the required 'source_faces_left' field must be rejected.")

	# Case-insensitive duplicate identity ("Duplicate_Actor" vs "duplicate_actor"):
	# neither variant may survive — admitting either one would be non-deterministic
	# silent behavior depending on filesystem sort order.
	for duplicate_key in table.keys():
		if str(duplicate_key).to_lower() == "duplicate_actor":
			errors.append("duplicate_actor: a case-insensitive duplicate identity must exclude BOTH shards, found '%s' admitted." % duplicate_key)

	_cleanup_fixtures(fixture_dir)

	if not errors.is_empty():
		for e in errors:
			push_error("Full-frame registry shard validation: %s" % e)
		push_error("Full-frame registry shard validation test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Full-frame registry shard validation test passed (malformed JSON, missing field, invalid type, and duplicate identity all fail closed; valid shard unaffected).")
	quit(0)


func _write_fixtures(fixture_dir: String, errors: Array) -> Array:
	DirAccess.make_dir_recursive_absolute(fixture_dir)
	# Physical files backing each name in the returned list. "Duplicate_Actor.json"
	# has no file of its own — see the class-level comment on why a real
	# case-variant duplicate can't be written to disk here — it is added to the
	# returned name list without a matching physical write further down.
	var shards := {
		"valid_actor.json": JSON.stringify({
			"frames": "res://fixtures/valid_actor.tres",
			"scale": {"x": 0.5, "y": 0.5},
			"position": {"x": 0.0, "y": -10.0},
			"source_faces_left": true,
		}),
		"malformed_json.json": "{not valid json,,,",
		"missing_frames.json": JSON.stringify({
			"scale": {"x": 0.5, "y": 0.5},
			"position": {"x": 0.0, "y": -10.0},
			"source_faces_left": true,
		}),
		"invalid_scale_type.json": JSON.stringify({
			"frames": "res://fixtures/invalid_scale_type.tres",
			"scale": {"x": "not_a_number", "y": 0.5},
			"position": {"x": 0.0, "y": -10.0},
			"source_faces_left": true,
		}),
		"missing_source_faces_left.json": JSON.stringify({
			"frames": "res://fixtures/missing_source_faces_left.tres",
			"scale": {"x": 0.5, "y": 0.5},
			"position": {"x": 0.0, "y": -10.0},
		}),
		"duplicate_actor.json": JSON.stringify({
			"frames": "res://fixtures/duplicate_actor.tres",
			"scale": {"x": 0.5, "y": 0.5},
			"position": {"x": 0.0, "y": -10.0},
			"source_faces_left": true,
		}),
	}
	for file_name in shards.keys():
		var file := FileAccess.open("%s/%s" % [fixture_dir, file_name], FileAccess.WRITE)
		if file == null:
			errors.append("fixture setup: could not write %s (errno %d)." % [file_name, FileAccess.get_open_error()])
			continue
		file.store_string(shards[file_name])
		file.close()
	var file_names := shards.keys()
	file_names.append("Duplicate_Actor.json")
	file_names.sort()
	return file_names


func _cleanup_fixtures(fixture_dir: String) -> void:
	var dir := DirAccess.open(fixture_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir():
			dir.remove(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(fixture_dir)
	DirAccess.remove_absolute(FIXTURE_ROOT)
