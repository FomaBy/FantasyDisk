extends SceneTree

# FAN-3934 read-only diagnostic: verifies (a) scripts loaded via plain load()
# stay resident in ResourceCache after all references are dropped, and
# (b) ResourceLoader.CACHE_MODE_IGNORE + reference drop releases the retained
# objects — the precondition for registry-side lazy residency designs.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := "res://scripts/ultimates/classes/berserk/axe.gd"
	var alt := "res://scripts/ultimates/classes/knight/sword.gd"
	for candidate in [path, alt]:
		if ResourceLoader.exists(candidate):
			path = candidate
			break
	if not ResourceLoader.exists(path):
		var files: Array = []
		_collect("res://scripts/ultimates/classes", ".gd", files)
		path = files[0]
	await process_frame
	var base := int(Performance.get_monitor(Performance.OBJECT_COUNT))

	# Fresh order: CACHE_MODE_IGNORE first on a not-yet-cached path.
	var ignored = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	await process_frame
	var after_ignore := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var ignore_cached_while_held := ResourceLoader.has_cached(path)
	ignored = null
	await process_frame
	await create_timer(0.2).timeout
	var after_ignore_drop := int(Performance.get_monitor(Performance.OBJECT_COUNT))

	var cached = load(path)
	await process_frame
	var after_plain := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var plain_cached_after_drop := ResourceLoader.has_cached(path)
	cached = null
	await process_frame
	await create_timer(0.2).timeout
	var after_drop := int(Performance.get_monitor(Performance.OBJECT_COUNT))

	print("FAN3934_CACHE_RESULT " + JSON.stringify({
		"path": path,
		"base": base,
		"plain_load_delta": after_plain - base,
		"still_cached_after_ref_drop": plain_cached_after_drop,
		"objects_after_ref_drop_delta": after_drop - base,
		"ignore_load_delta": after_ignore - base,
		"ignore_cached_while_held": ignore_cached_while_held,
		"plain_cached_after_drop": plain_cached_after_drop,
		"objects_after_ignore_ref_drop_delta": after_ignore_drop - base,
	}))
	quit(0)

func _collect(dir_path: String, suffix: String, out: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := "%s/%s" % [dir_path, name]
		if dir.current_is_dir():
			_collect(full, suffix, out)
		elif name.ends_with(suffix):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
