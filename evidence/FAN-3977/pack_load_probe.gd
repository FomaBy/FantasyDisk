extends SceneTree

# FAN-3977 per-pack load cost probe (AC2 before/after): for every full-frame
# pack (registry shards + secret boss) time a cold synchronous
# ResourceLoader.load of the SpriteFrames on the main thread — the cost a
# first-use load paid in v0.3.2 — and the RENDER_TEXTURE_MEM_USED it adds
# once its textures are uploaded. Run WINDOWED so uploads hit the real GL
# Compatibility renderer; each pack is released before the next one.
#   Godot --path <project> --script <abs path> -- label=<name> out=<abs dir>

const FullFrameAnimationRegistry := preload("res://scripts/full_frame_animation_registry.gd")
const SECRET_BOSS_FRAMES := "res://assets/sprites/bosses/full_frame/secret_ascension_boss_spriteframes.tres"

var _label := "build"
var _out_dir := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("label="):
			_label = str(arg).trim_prefix("label=")
		elif str(arg).begins_with("out="):
			_out_dir = str(arg).trim_prefix("out=")
	await _run()


func _mib() -> float:
	return Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0


func _run() -> void:
	for _i in range(30):
		await process_frame
	var packs: Array = []
	for kind in ["enemy", "elite", "boss", "ally"]:
		var table: Dictionary = FullFrameAnimationRegistry.FULL_FRAME_SPRITEFRAMES.get(kind, {})
		var ids := table.keys()
		ids.sort()
		for entity_id in ids:
			packs.append(["%s/%s" % [kind, entity_id], str((table[entity_id] as Dictionary).get("frames", ""))])
	packs.append(["boss/secret_ascension_boss", SECRET_BOSS_FRAMES])
	var rows: Array = []
	print("| pack | frames | textures | load ms | frame ms | texture MiB |")
	print("|---|---|---|---|---|---|")
	for pack in packs:
		await process_frame
		var before_mem := _mib()
		var frame_started := Time.get_ticks_usec()
		await process_frame
		var started := Time.get_ticks_usec()
		var frames := ResourceLoader.load(pack[1]) as SpriteFrames
		var load_ms := float(Time.get_ticks_usec() - started) / 1000.0
		await process_frame
		var frame_ms := float(Time.get_ticks_usec() - frame_started) / 1000.0
		await process_frame
		await process_frame
		var delta_mib := _mib() - before_mem
		var frame_count := 0
		var textures := {}
		if frames != null:
			for name in frames.get_animation_names():
				for index in range(frames.get_frame_count(name)):
					frame_count += 1
					var texture := frames.get_frame_texture(name, index)
					var atlas := texture as AtlasTexture
					textures[(atlas.atlas if atlas != null else texture).get_instance_id()] = true
		rows.append({"pack": pack[0], "frames": frame_count, "textures": textures.size(), "load_ms": load_ms, "frame_ms": frame_ms, "texture_mib": delta_mib})
		print("| %s | %d | %d | %.1f | %.1f | %.0f |" % [pack[0], frame_count, textures.size(), load_ms, frame_ms, delta_mib])
		frames = null
		textures.clear()
		for _i in range(10):
			await process_frame
	if _out_dir != "":
		var file := FileAccess.open(_out_dir.path_join("pack_load_%s.json" % _label), FileAccess.WRITE)
		file.store_string(JSON.stringify({"label": _label, "rows": rows}, "  "))
		file.close()
	quit(0)
