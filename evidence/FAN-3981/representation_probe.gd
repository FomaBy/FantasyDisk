extends SceneTree

# FAN-3981 representation probe (run WINDOWED, real renderer):
#
#   Godot --path <project> --script res://evidence/FAN-3981/representation_probe.gd -- [packs=id,id,...] [out=<abs dir>]
#
# For every full-frame pack (or the listed ids) it:
#   1. loads the shipped SpriteFrames and checks the FAN-3981 representation
#      (one FullFrameCanvasTexture per pack reporting the canvas, a
#      FullFrameTrimAtlas table in metadata, the manifest geometry);
#   2. rebuilds the FAN-3977 representation in memory from the trim
#      manifest (one AtlasTexture per unique frame over the same pages) and
#      captures both through the same AnimatedSprite2D at the registry scale
#      x combat zoom, flipped, and at a 4K-class factor, for every animation
#      and every frame — the captures must be byte-identical (tolerance 0);
#   3. reports the engine objects each representation costs
#      (Performance.OBJECT_COUNT delta while the pack is held).
# Writes <out>/representation_probe.json when out= is given.

const FullFrameAnimationRegistry := preload("res://scripts/full_frame_animation_registry.gd")
const SECRET_BOSS_FRAMES := "res://assets/sprites/bosses/full_frame/secret_ascension_boss_spriteframes.tres"
const COMBAT_CAMERA_ZOOM := 1.12
const HIGH_DPI_FACTOR := 1.51
const CAPTURE_SIZE := Vector2i(768, 768)

var _errors: Array = []
var _only: Array = []
var _out_dir := ""
var _rows: Array = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("packs="):
			_only = text.trim_prefix("packs=").split(",", false)
		elif text.begins_with("out="):
			_out_dir = text.trim_prefix("out=")
	await _run()
	if not _errors.is_empty():
		for error in _errors:
			push_error("representation probe: %s" % error)
		print("REPRESENTATION PROBE FAILED (%d errors)" % _errors.size())
		quit(1)
		return
	print("REPRESENTATION PROBE OK (%d packs)" % _rows.size())
	quit(0)


func _fail(message: String) -> void:
	_errors.append(message)


func _pack_paths() -> Array:
	var paths: Array = []
	for entity_kind in ["enemy", "elite", "boss", "ally"]:
		for entity_id in FullFrameAnimationRegistry.kind_entity_ids(entity_kind):
			paths.append(FullFrameAnimationRegistry.frames_path_for(entity_kind, str(entity_id)))
	paths.append(SECRET_BOSS_FRAMES)
	if _only.is_empty():
		return paths
	var selected: Array = []
	for path in paths:
		var pack_id := FullFrameTrimAtlas.manifest_path_for(str(path)).get_file().trim_suffix(FullFrameTrimAtlas.MANIFEST_SUFFIX)
		if _only.has(pack_id):
			selected.append(path)
	return selected


func _run() -> void:
	for _i in range(5):
		await process_frame
	print("probe: renderer=%s headless=%s" % [RenderingServer.get_current_rendering_method(), DisplayServer.get_name() == "headless"])
	var viewport := SubViewport.new()
	viewport.size = CAPTURE_SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	for frames_path_variant in _pack_paths():
		var frames_path := str(frames_path_variant)
		await _probe_pack(frames_path, viewport)
	viewport.queue_free()
	await process_frame
	if _out_dir != "":
		DirAccess.make_dir_recursive_absolute(_out_dir)
		var file := FileAccess.open(_out_dir.path_join("representation_probe.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"renderer": RenderingServer.get_current_rendering_method(), "packs": _rows, "errors": _errors}, "  "))
		file.close()
	print("")
	print("| pack | frames | unique | pages | objects before (AtlasTexture) | objects after (trim table) | captures | max diff before/after | max diff vs source |")
	print("|---|---|---|---|---|---|---|---|---|")
	for row in _rows:
		print("| %s | %d | %d | %d | %d | %d | %d | %d | %d |" % [row["pack"], row["frames"], row["unique"], row["pages"], row["objects_before"], row["objects_after"], row["captures"], row["max_diff_before_after"], row["max_diff_vs_source"]])


func _objects() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_COUNT))


func _probe_pack(frames_path: String, viewport: SubViewport) -> void:
	var manifest := FullFrameTrimAtlas.load_manifest(frames_path)
	if manifest.is_empty():
		_fail("%s: no manifest" % frames_path)
		return
	var pack_id := str(manifest["pack"])
	# Pages first so both representations count only their own objects.
	var pages: Array = []
	for page in manifest["pages"]:
		pages.append(load(str(page["path"])))
	await process_frame
	var objects_base := _objects()
	var frames := load(frames_path) as SpriteFrames
	await process_frame
	var objects_after := _objects() - objects_base
	if frames == null:
		_fail("%s: does not load" % frames_path)
		return
	var atlas := FullFrameTrimAtlas.of(frames)
	if atlas == null:
		_fail("%s: no FullFrameTrimAtlas metadata" % pack_id)
		return
	if atlas.entry_count() != int(manifest["unique_frames"]):
		_fail("%s: %d table entries, manifest unique_frames %d" % [pack_id, atlas.entry_count(), int(manifest["unique_frames"])])
	var canvas_textures := {}
	for animation_name in frames.get_animation_names():
		for frame_index in range(frames.get_frame_count(animation_name)):
			var texture := frames.get_frame_texture(animation_name, frame_index)
			if not (texture is FullFrameCanvasTexture):
				_fail("%s: %s[%d] texture is %s" % [pack_id, animation_name, frame_index, texture.get_class() if texture != null else "null"])
				continue
			canvas_textures[texture.get_instance_id()] = true
			if Vector2i(texture.get_size()) != atlas.canvas:
				_fail("%s: %s[%d] size %s, canvas %s" % [pack_id, animation_name, frame_index, texture.get_size(), atlas.canvas])
			var entry := atlas.frame_entry(animation_name, frame_index)
			if entry.is_empty():
				_fail("%s: %s[%d] has no table entry" % [pack_id, animation_name, frame_index])
	if canvas_textures.size() != 1:
		_fail("%s: %d canvas textures, expected 1" % [pack_id, canvas_textures.size()])
	# FAN-3977 representation from the manifest.
	var before_started := _objects()
	var before := _atlas_texture_frames(manifest, pages)
	await process_frame
	var objects_before := _objects() - before_started
	# Render parity, every animation and frame, three cases each.
	var sprite := AnimatedSprite2D.new()
	sprite.position = Vector2(CAPTURE_SIZE) * 0.5
	viewport.add_child(sprite)
	if not FullFrameTrimAtlas.attach(sprite):
		_fail("%s: attach failed" % pack_id)
	var base_scale := _registry_scale(frames_path)
	var captures := 0
	var max_diff := 0
	var max_diff_source := 0
	var source_cache := {}
	var headless := DisplayServer.get_name() == "headless"
	for animation_name in frames.get_animation_names():
		var frame_count := frames.get_frame_count(animation_name)
		for frame_index in range(frame_count):
			for case in [[base_scale * COMBAT_CAMERA_ZOOM, false], [base_scale * COMBAT_CAMERA_ZOOM, true], [base_scale * HIGH_DPI_FACTOR, false]]:
				if headless:
					break
				var image_before := await _capture(sprite, before, animation_name, frame_index, case[0], case[1], viewport)
				var image_after := await _capture(sprite, frames, animation_name, frame_index, case[0], case[1], viewport)
				captures += 1
				var diff := _max_channel_difference(image_before, image_after)
				max_diff = maxi(max_diff, diff)
				if diff > 0:
					_fail("%s: %s[%d] scale %.3f flip %s differs from the AtlasTexture render by %d/255" % [pack_id, animation_name, frame_index, case[0], case[1], diff])
					if _out_dir != "":
						image_before.save_png(_out_dir.path_join("%s_%s_%d_before.png" % [pack_id, animation_name, frame_index]))
						image_after.save_png(_out_dir.path_join("%s_%s_%d_after.png" % [pack_id, animation_name, frame_index]))
				# Source-frame reference for the middle frame of each animation only (slow path).
				if frame_index == frame_count / 2 and not case[1]:
					var source := _source_frames(manifest, animation_name, frame_index, source_cache)
					if source != null:
						var image_source := await _capture(sprite, source, "frame", 0, case[0], case[1], viewport)
						max_diff_source = maxi(max_diff_source, _max_channel_difference(image_source, image_after))
	sprite.queue_free()
	await process_frame
	var row := {
		"pack": pack_id,
		"frames": int(manifest["frames_total"]),
		"unique": int(manifest["unique_frames"]),
		"pages": pages.size(),
		"objects_before": objects_before,
		"objects_after": objects_after,
		"captures": captures,
		"max_diff_before_after": max_diff,
		"max_diff_vs_source": max_diff_source,
	}
	_rows.append(row)
	print("probe %s: objects before %d / after %d, %d captures, max diff before/after %d, vs source %d" % [pack_id, objects_before, objects_after, captures, max_diff, max_diff_source])


func _atlas_texture_frames(manifest: Dictionary, pages: Array) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var by_source := {}
	for entry in manifest["entries"]:
		var texture := AtlasTexture.new()
		texture.atlas = pages[int(entry["page"])]
		var region: Array = entry["region"]
		var margin: Array = entry["margin"]
		texture.region = Rect2(int(region[0]), int(region[1]), int(region[2]), int(region[3]))
		texture.margin = Rect2(int(margin[0]), int(margin[1]), int(margin[2]), int(margin[3]))
		for source in entry["sources"]:
			by_source[str(source)] = texture
	for animation in manifest["animations"]:
		var name := str(animation["name"])
		frames.add_animation(name)
		frames.set_animation_loop(name, bool(animation["loop"]))
		frames.set_animation_speed(name, float(animation["speed"]))
		for frame in animation["frames"]:
			frames.add_frame(name, by_source[str(frame["source"])], float(frame["duration"]))
	return frames


func _source_frames(manifest: Dictionary, animation_name: String, frame_index: int, cache: Dictionary) -> SpriteFrames:
	for animation in manifest["animations"]:
		if str(animation["name"]) != animation_name:
			continue
		var frame_list: Array = animation["frames"]
		if frame_index >= frame_list.size():
			return null
		var source := str(frame_list[frame_index]["source"])
		if not cache.has(source):
			cache[source] = load(source)
		var frames := SpriteFrames.new()
		frames.remove_animation("default")
		frames.add_animation("frame")
		frames.add_frame("frame", cache[source])
		return frames
	return null


func _registry_scale(frames_path: String) -> float:
	for entity_kind in ["enemy", "elite", "boss", "ally"]:
		for entity_id in FullFrameAnimationRegistry.kind_entity_ids(entity_kind):
			var config := FullFrameAnimationRegistry.registry_config(entity_kind, str(entity_id))
			if str(config.get("frames", "")) == frames_path:
				return float((config.get("scale", Vector2.ONE) as Vector2).x)
	return 0.86


func _capture(sprite: AnimatedSprite2D, source_frames: SpriteFrames, name: String, frame_index: int, scale_factor: float, flip: bool, viewport: SubViewport) -> Image:
	sprite.sprite_frames = source_frames
	sprite.play(name)
	sprite.pause()
	sprite.frame = frame_index
	sprite.flip_h = flip
	sprite.scale = Vector2(scale_factor, scale_factor)
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func _max_channel_difference(a: Image, b: Image) -> int:
	if a == null or b == null or a.get_size() != b.get_size():
		return 255
	var data_a := a.get_data()
	var data_b := b.get_data()
	if data_a == data_b:
		return 0
	var max_diff := 0
	for index in range(data_a.size()):
		max_diff = maxi(max_diff, absi(int(data_a[index]) - int(data_b[index])))
	return max_diff
