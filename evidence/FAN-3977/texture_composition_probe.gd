extends SceneTree

# FAN-3977: attributes RENDER_TEXTURE_MEM_USED at the route map — game
# baseline vs resident full-frame pages — and reports any retained per-frame
# source texture that something still loads. Run windowed.

const FullFrameAnimationRegistry := preload("res://scripts/full_frame_animation_registry.gd")
const FullFrameEncounterRoster := preload("res://scripts/full_frame_encounter_roster.gd")


func _mib() -> float:
	return Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0


func _initialize() -> void:
	for _i in range(30):
		await process_frame
	print("t0 empty tree: %.0f MiB" % _mib())
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	for _i in range(30):
		await process_frame
	print("t1 Main instantiated (menu): %.0f MiB" % _mib())
	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "sword")
	main.rng.seed = 3977
	main.set("route_nodes", main.route._generate_route())
	main.set("route_stage", 0)
	main.route._show_battle_map()
	FullFrameAnimationRegistry.release_prefetched()
	for _i in range(30):
		await process_frame
	print("t2 route map shown, no packs: %.0f MiB" % _mib())
	var core: Array = FullFrameEncounterRoster.core_paths(main.get("PROGRESSION_DATA"))
	var expected := 0
	for frames_path in core:
		var stem := str(frames_path).get_file().trim_suffix(".tres").trim_suffix("_spriteframes")
		if str(frames_path).contains("/allies/"):
			stem = stem.trim_prefix("ally_")
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(frames_path).get_base_dir().path_join(stem + "_trim_manifest.json")))
		expected += int(manifest.get("page_rgba_bytes", 0))
		FullFrameAnimationRegistry.queue_prefetch_path(str(frames_path))
	while FullFrameAnimationRegistry.advance_prefetch() > 0:
		await process_frame
	for _i in range(30):
		await process_frame
	print("t3 core roster resident (%d packs, manifest pages %.0f MiB): %.0f MiB" % [FullFrameAnimationRegistry.prefetched_frames_count(), expected / 1048576.0, _mib()])
	# Any retained per-frame source texture loaded by something?
	var loaded_sources := 0
	var sample := ""
	for frames_path in core:
		var stem := str(frames_path).get_file().trim_suffix(".tres").trim_suffix("_spriteframes")
		if str(frames_path).contains("/allies/"):
			stem = stem.trim_prefix("ally_")
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(frames_path).get_base_dir().path_join(stem + "_trim_manifest.json")))
		for source in manifest.get("sources", []):
			if ResourceLoader.has_cached(str(source["path"])):
				loaded_sources += 1
				if sample == "":
					sample = str(source["path"])
	print("t3 retained per-frame sources in the resource cache: %d (first: %s)" % [loaded_sources, sample])
	FullFrameAnimationRegistry.release_prefetched()
	for _i in range(60):
		await process_frame
	print("t4 packs released: %.0f MiB" % _mib())
	main.combat._start_combat(false, "battle")
	for _frame in range(3000):
		if bool(main.combat.get("_combat_start_finalized")):
			break
		await process_frame
	for _i in range(30):
		await process_frame
	print("t5 battle finalized (roster resident, first wave): %.0f MiB" % _mib())
	main.combat._end_combat(true)
	await process_frame
	quit(0)
