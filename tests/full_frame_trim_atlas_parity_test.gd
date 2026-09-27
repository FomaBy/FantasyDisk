extends SceneTree

# FAN-3977: every full-frame actor pack (41 registry shards + the secret
# boss) now ships as lossless trim atlases built by
# tools/build_full_frame_trim_atlases.py: each frame is trimmed to its alpha
# bounding box (+PAD) and packed into pages; the SpriteFrames references an
# AtlasTexture per unique frame whose `margin` restores the original canvas
# offset and logical size. This suite is the visual-contract regression:
#
#   A. SOURCE PIXELS: for every atlas entry the page region is byte-identical
#      to the retained source PNG at the margin offset, and every frame of
#      the shipped .tres is an AtlasTexture over a listed page with exactly
#      the manifest region/margin and the original canvas size (get_size()).
#   B. METADATA: animation names, loop flags, speeds, frame counts, per-frame
#      durations and per-frame source identity match the manifest model.
#   C. NEGATIVE FIXTURES: a region shifted by one texel and a wrong margin
#      must FAIL the same comparisons (the detector is not vacuous).
#   D. CAPTURED RENDER (needs a real renderer — reported SKIPPED headless):
#      an AnimatedSprite2D playing the trimmed pack is captured against the
#      same sprite playing a reference SpriteFrames assembled from the
#      retained source textures, at the registry scale x the combat camera
#      zoom (1.12) and at a 4K-class 1.51 factor, with and without flip_h.
#      The captures must agree within RENDER_TOLERANCE (4/255 per channel):
#      the GPU interpolates texture coordinates over a different quad (the
#      trim instead of the full canvas) and a different page size, which
#      rounds bilinear weights differently on anti-aliased edge texels by at
#      most a few levels; any larger difference (a shifted region, a
#      wrong margin, resampling) fails. Pass `-- export=<dir>` to also write
#      before/after/diff side-by-side PNGs per pack (AC4 evidence).
#   E. IMPORT SETTINGS: each page .png.import is lossless (compress/mode=0)
#      without mipmaps, like the source frames.
#   F. LIFECYCLE: release, cold reload, repeat parity, orphan-free.
#
# Запуск: Godot --headless --path . --script res://tests/full_frame_trim_atlas_parity_test.gd
#         Godot --path . --script res://tests/full_frame_trim_atlas_parity_test.gd -- export=/abs/dir

const FullFrameAnimationRegistry := preload("res://scripts/full_frame_animation_registry.gd")

const SECRET_BOSS_FRAMES := "res://assets/sprites/bosses/full_frame/secret_ascension_boss_spriteframes.tres"
const MANIFEST_SUFFIX := "_trim_manifest.json"
const COMBAT_CAMERA_ZOOM := 1.12
const HIGH_DPI_FACTOR := 1.51
const CAPTURE_SIZE := Vector2i(768, 768)
const RENDER_ANIMATIONS_PER_PACK := 6
const RENDER_TOLERANCE := 4  # max per-channel difference (0-255) between reference and trimmed captures

var _errors: Array = []
var _export_dir := ""
var _render_checks := 0
var _render_skipped := false
var _render_max_diff := 0


func _initialize() -> void:
	# The dummy (headless) renderer never draws, so `frame_post_draw` never
	# fires: the render gate is only meaningful with a real renderer.
	_render_skipped = DisplayServer.get_name() == "headless"
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("export="):
			_export_dir = str(arg).trim_prefix("export=")
			DirAccess.make_dir_recursive_absolute(_export_dir)
	await _run()
	if not _errors.is_empty():
		for error in _errors:
			push_error("Full-frame trim atlas parity: %s" % error)
		push_error("Full-frame trim atlas parity test: %d ошибок." % _errors.size())
		quit(1)
		return
	print("Full-frame trim atlas parity test passed (%d packs: source pixels, metadata, negative fixtures, import settings, lifecycle; render captures: %s)." % [
		_pack_paths().size(), "SKIPPED (headless renderer)" if _render_skipped else "%d captures, max per-channel difference %d/255" % [_render_checks, _render_max_diff]])
	quit(0)


func _fail(message: String) -> void:
	_errors.append(message)


func _pack_paths() -> Array:
	var paths: Array = []
	for entity_kind in ["enemy", "elite", "boss", "ally"]:
		for entity_id in FullFrameAnimationRegistry.kind_entity_ids(entity_kind):
			paths.append(FullFrameAnimationRegistry.frames_path_for(entity_kind, str(entity_id)))
	paths.append(SECRET_BOSS_FRAMES)
	return paths


static func manifest_path_for(frames_path: String) -> String:
	var pack_id := frames_path.get_file().trim_suffix(".tres").trim_suffix("_spriteframes")
	if frames_path.contains("/allies/"):
		pack_id = pack_id.trim_prefix("ally_")
	return frames_path.get_base_dir().path_join(pack_id + MANIFEST_SUFFIX)


func _run() -> void:
	var packs := _pack_paths()
	if packs.size() < 42:
		_fail("expected at least 42 full-frame packs, found %d." % packs.size())
	var viewport: SubViewport = null
	for frames_path_variant in packs:
		var frames_path := str(frames_path_variant)
		var manifest := _load_manifest(frames_path)
		if manifest.is_empty():
			continue
		var frames := load(frames_path) as SpriteFrames
		if frames == null:
			_fail("%s: does not load as SpriteFrames." % frames_path)
			continue
		var pages := _load_page_images(manifest)
		var source_cache := {}
		_check_source_pixels(manifest, frames, pages, source_cache)
		_check_metadata(manifest, frames)
		_check_import_settings(manifest)
		if not _render_skipped:
			if viewport == null:
				viewport = _make_viewport()
			await _check_render(manifest, frames, viewport)
		print("  parity: %s ok (%d entries, %d pages) at %d ms" % [manifest["pack"], (manifest.get("entries", []) as Array).size(), pages.size(), Time.get_ticks_msec()])
	_check_negative_fixtures()
	await _check_lifecycle(packs[0])
	if viewport != null:
		viewport.queue_free()
		await process_frame


func _load_manifest(frames_path: String) -> Dictionary:
	var manifest_path := manifest_path_for(frames_path)
	if not FileAccess.file_exists(manifest_path):
		_fail("%s: trim manifest %s missing." % [frames_path, manifest_path])
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not (parsed is Dictionary) or str((parsed as Dictionary).get("tres", "")) != frames_path:
		_fail("%s: manifest malformed or bound to another pack." % manifest_path)
		return {}
	return parsed as Dictionary


func _load_png(res_path: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(res_path))
	if image == null or image.is_empty():
		return null
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image


func _load_page_images(manifest: Dictionary) -> Array:
	var pages: Array = []
	for page in manifest.get("pages", []):
		var image := _load_png(str(page["path"]))
		if image == null:
			_fail("%s: page %s cannot be decoded." % [manifest["pack"], page["path"]])
		elif image.get_size() != Vector2i(int(page["width"]), int(page["height"])):
			_fail("%s: page %s is %s, manifest says %dx%d." % [manifest["pack"], page["path"], image.get_size(), int(page["width"]), int(page["height"])])
		pages.append(image)
	return pages


static func _rect_from(values: Array) -> Rect2i:
	return Rect2i(int(values[0]), int(values[1]), int(values[2]), int(values[3]))


func _source_image(res_path: String, cache: Dictionary) -> Image:
	if not cache.has(res_path):
		cache[res_path] = _load_png(res_path)
	return cache[res_path]


# --- A. source pixels + geometry ---------------------------------------------

func _check_source_pixels(manifest: Dictionary, frames: SpriteFrames, pages: Array, source_cache: Dictionary) -> void:
	var pack_id := str(manifest["pack"])
	var entry_by_source := {}
	var page_paths := {}
	for page in manifest.get("pages", []):
		page_paths[str(page["path"])] = true
	for entry in manifest.get("entries", []):
		var region := _rect_from(entry["region"])
		var margin := _rect_from(entry["margin"])
		var canvas := Vector2i(int(entry["canvas"][0]), int(entry["canvas"][1]))
		var page_index := int(entry["page"])
		if page_index < 0 or page_index >= pages.size() or pages[page_index] == null:
			_fail("%s: entry references missing page %d." % [pack_id, page_index])
			continue
		if region.size + margin.size != canvas:
			_fail("%s: entry %s region+margin (%s + %s) does not restore the %s canvas." % [pack_id, entry["sources"][0], region.size, margin.size, canvas])
		var page_pixels: Image = (pages[page_index] as Image).get_region(region)
		var first := true
		for source_variant in entry["sources"]:
			var source := str(source_variant)
			entry_by_source[source] = entry
			var source_image := _source_image(source, source_cache)
			if source_image == null:
				_fail("%s: source %s cannot be decoded." % [pack_id, source])
				continue
			if source_image.get_size() != canvas:
				_fail("%s: source %s is %s, manifest canvas %s." % [pack_id, source, source_image.get_size(), canvas])
				continue
			if first:
				# Pixels outside the trim must be fully transparent in the source
				# (the trim keeps PAD transparent texels; nothing visible is lost).
				var used := source_image.get_used_rect()
				var trim := Rect2i(margin.position, region.size)
				if used.size != Vector2i.ZERO and not trim.encloses(used):
					_fail("%s: trim %s of %s does not enclose its visible pixels %s." % [pack_id, trim, source, used])
				first = false
			var expected := source_image.get_region(Rect2i(margin.position, region.size))
			if not _images_equal(expected, page_pixels):
				_fail("%s: page pixels differ from source %s at %s." % [pack_id, source, region])
	# Every frame texture of the shipped resource is one of those entries.
	for animation_name in frames.get_animation_names():
		for frame_index in range(frames.get_frame_count(animation_name)):
			var texture := frames.get_frame_texture(animation_name, frame_index)
			var atlas_texture := texture as AtlasTexture
			if atlas_texture == null or atlas_texture.atlas == null:
				_fail("%s: %s[%d] is not an AtlasTexture over a page." % [pack_id, animation_name, frame_index])
				continue
			if not page_paths.has(atlas_texture.atlas.resource_path):
				_fail("%s: %s[%d] atlas %s is not a listed page." % [pack_id, animation_name, frame_index, atlas_texture.atlas.resource_path])
			var source := _manifest_frame_source(manifest, str(animation_name), frame_index)
			var entry: Dictionary = entry_by_source.get(source, {})
			if entry.is_empty():
				_fail("%s: %s[%d] source %s has no atlas entry." % [pack_id, animation_name, frame_index, source])
				continue
			if Rect2i(atlas_texture.region) != _rect_from(entry["region"]) or Rect2i(atlas_texture.margin) != _rect_from(entry["margin"]):
				_fail("%s: %s[%d] region/margin %s/%s differ from the manifest entry." % [pack_id, animation_name, frame_index, atlas_texture.region, atlas_texture.margin])
			var canvas := Vector2i(int(entry["canvas"][0]), int(entry["canvas"][1]))
			if Vector2i(atlas_texture.get_size()) != canvas:
				_fail("%s: %s[%d] logical size %s, expected the %s canvas." % [pack_id, animation_name, frame_index, atlas_texture.get_size(), canvas])


func _manifest_frame_source(manifest: Dictionary, animation_name: String, frame_index: int) -> String:
	for animation in manifest.get("animations", []):
		if str(animation["name"]) == animation_name:
			var frame_list: Array = animation["frames"]
			if frame_index < frame_list.size():
				return str((frame_list[frame_index] as Dictionary)["source"])
	return ""


# Largest absolute per-channel difference (0-255) between two same-size RGBA8
# captures; 255 when they cannot be compared.
func _max_channel_difference(a: Image, b: Image) -> int:
	if a == null or b == null or a.get_size() != b.get_size():
		return 255
	var data_a := a.get_data()
	var data_b := b.get_data()
	if data_a.size() != data_b.size():
		return 255
	var max_diff := 0
	for index in range(data_a.size()):
		var diff := absi(int(data_a[index]) - int(data_b[index]))
		if diff > max_diff:
			max_diff = diff
			if max_diff > RENDER_TOLERANCE:
				return max_diff
	return max_diff


func _images_equal(a: Image, b: Image) -> bool:
	if a == null or b == null or a.get_size() != b.get_size():
		return false
	return a.get_data() == b.get_data()


# --- B. metadata ---------------------------------------------------------------

func _check_metadata(manifest: Dictionary, frames: SpriteFrames) -> void:
	var pack_id := str(manifest["pack"])
	var expected_names := {}
	for animation in manifest.get("animations", []):
		var name := str(animation["name"])
		expected_names[name] = true
		if not frames.has_animation(name):
			_fail("%s: animation %s missing from the shipped pack." % [pack_id, name])
			continue
		if frames.get_animation_loop(name) != bool(animation["loop"]):
			_fail("%s: %s loop flag differs." % [pack_id, name])
		if not is_equal_approx(frames.get_animation_speed(name), float(animation["speed"])):
			_fail("%s: %s speed %.3f differs from %.3f." % [pack_id, name, frames.get_animation_speed(name), float(animation["speed"])])
		var frame_list: Array = animation["frames"]
		if frames.get_frame_count(name) != frame_list.size():
			_fail("%s: %s has %d frames, expected %d." % [pack_id, name, frames.get_frame_count(name), frame_list.size()])
			continue
		for frame_index in range(frame_list.size()):
			if not is_equal_approx(frames.get_frame_duration(name, frame_index), float((frame_list[frame_index] as Dictionary)["duration"])):
				_fail("%s: %s[%d] duration differs." % [pack_id, name, frame_index])
	for name in frames.get_animation_names():
		if not expected_names.has(str(name)):
			_fail("%s: shipped pack has an animation %s the manifest does not list." % [pack_id, name])
	if int(manifest.get("frames_total", -1)) != _frame_total(frames):
		_fail("%s: manifest frames_total %d != shipped %d." % [pack_id, int(manifest.get("frames_total", -1)), _frame_total(frames)])


static func _frame_total(frames: SpriteFrames) -> int:
	var total := 0
	for name in frames.get_animation_names():
		total += frames.get_frame_count(name)
	return total


# --- C. negative fixtures ------------------------------------------------------

func _check_negative_fixtures() -> void:
	var page := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	page.fill(Color(0, 0, 0, 0))
	for y in range(10, 30):
		for x in range(10, 30):
			page.set_pixel(x, y, Color(float(x) / 64.0, float(y) / 64.0, 0.5, 1.0))
	var source := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	source.fill(Color(0, 0, 0, 0))
	source.blit_rect(page, Rect2i(10, 10, 20, 20), Vector2i(50, 60))
	var region := Rect2i(10, 10, 20, 20)
	var margin := Rect2i(50, 60, 108, 108)
	if not _images_equal(source.get_region(Rect2i(margin.position, region.size)), page.get_region(region)):
		_fail("negative fixture: the correct region/margin must compare equal.")
	var shifted := Rect2i(11, 10, 20, 20)
	if _images_equal(source.get_region(Rect2i(margin.position, shifted.size)), page.get_region(shifted)):
		_fail("negative fixture: a region shifted by one texel must NOT compare equal.")
	var wrong_margin := Rect2i(51, 60, 108, 108)
	if _images_equal(source.get_region(Rect2i(wrong_margin.position, region.size)), page.get_region(region)):
		_fail("negative fixture: a wrong margin offset must NOT compare equal.")
	var texture := ImageTexture.create_from_image(page)
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(region)
	atlas.margin = Rect2(margin)
	if Vector2i(atlas.get_size()) != Vector2i(128, 128):
		_fail("negative fixture: AtlasTexture margin must restore the 128x128 logical size (got %s)." % atlas.get_size())
	atlas.margin = Rect2(wrong_margin.position, Vector2(107, 108))
	if Vector2i(atlas.get_size()) == Vector2i(128, 128):
		_fail("negative fixture: a wrong margin size must change the logical size.")


# --- D. render capture ---------------------------------------------------------

func _make_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = CAPTURE_SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport


func _capture(viewport: SubViewport) -> Image:
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	return image


func _reference_frames(manifest: Dictionary) -> SpriteFrames:
	var reference := SpriteFrames.new()
	reference.remove_animation("default")
	var texture_cache := {}
	for animation in manifest.get("animations", []):
		var name := str(animation["name"])
		reference.add_animation(name)
		reference.set_animation_loop(name, bool(animation["loop"]))
		reference.set_animation_speed(name, float(animation["speed"]))
		for frame in animation["frames"]:
			var source := str((frame as Dictionary)["source"])
			if not texture_cache.has(source):
				texture_cache[source] = load(source)
			reference.add_frame(name, texture_cache[source], float((frame as Dictionary)["duration"]))
	return reference


func _registry_scale(frames_path: String) -> float:
	for entity_kind in ["enemy", "elite", "boss", "ally"]:
		for entity_id in FullFrameAnimationRegistry.kind_entity_ids(entity_kind):
			var config := FullFrameAnimationRegistry.registry_config(entity_kind, str(entity_id))
			if str(config.get("frames", "")) == frames_path:
				return float((config.get("scale", Vector2.ONE) as Vector2).x)
	return 0.86  # secret boss scene metadata


func _check_render(manifest: Dictionary, frames: SpriteFrames, viewport: SubViewport) -> void:
	var pack_id := str(manifest["pack"])
	var reference := _reference_frames(manifest)
	var sprite := AnimatedSprite2D.new()
	sprite.position = Vector2(CAPTURE_SIZE) * 0.5
	viewport.add_child(sprite)
	var base_scale := _registry_scale(str(manifest["tres"]))
	var names := frames.get_animation_names()
	var checked_names: Array = []
	var preferred := ["idle_south", "idle", "move_south", "attack_south", "death_west", "hit_east", "move_east"]
	for name in preferred:
		if frames.has_animation(name) and checked_names.size() < RENDER_ANIMATIONS_PER_PACK:
			checked_names.append(name)
	for name in names:
		if checked_names.size() >= RENDER_ANIMATIONS_PER_PACK:
			break
		if not checked_names.has(str(name)):
			checked_names.append(str(name))
	var evidence_written := false
	for name in checked_names:
		var frame_index := frames.get_frame_count(name) / 2
		for case in [[base_scale * COMBAT_CAMERA_ZOOM, false], [base_scale * COMBAT_CAMERA_ZOOM, true], [base_scale * HIGH_DPI_FACTOR, false]]:
			var scale_factor: float = case[0]
			var flip: bool = case[1]
			var before := await _capture_frame(sprite, reference, name, frame_index, scale_factor, flip, viewport)
			if before == null or before.is_empty():
				_render_skipped = true
				sprite.queue_free()
				return
			var after := await _capture_frame(sprite, frames, name, frame_index, scale_factor, flip, viewport)
			_render_checks += 1
			var max_diff := _max_channel_difference(before, after)
			_render_max_diff = maxi(_render_max_diff, max_diff)
			if max_diff > RENDER_TOLERANCE:
				_fail("%s: render of %s[%d] (scale %.3f, flip %s) differs from the source-frame reference by up to %d/255." % [pack_id, name, frame_index, scale_factor, flip, max_diff])
			if _export_dir != "" and not evidence_written:
				_write_side_by_side(pack_id, name, before, after)
				evidence_written = true
	sprite.queue_free()
	await process_frame


func _capture_frame(sprite: AnimatedSprite2D, source_frames: SpriteFrames, name: String, frame_index: int, scale_factor: float, flip: bool, viewport: SubViewport) -> Image:
	sprite.sprite_frames = source_frames
	sprite.play(name)
	sprite.pause()
	sprite.frame = frame_index
	sprite.flip_h = flip
	sprite.scale = Vector2(scale_factor, scale_factor)
	await process_frame
	await process_frame
	return await _capture(viewport)


func _write_side_by_side(pack_id: String, name: String, before: Image, after: Image) -> void:
	var size := before.get_size()
	var diff := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var differing := 0
	var max_diff := 0
	for y in range(size.y):
		for x in range(size.x):
			var a := before.get_pixel(x, y)
			var b := after.get_pixel(x, y)
			var pixel_diff := int(round(maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), maxf(absf(a.b - b.b), absf(a.a - b.a))) * 255.0))
			if pixel_diff == 0:
				diff.set_pixel(x, y, Color(0, 0, 0, 1))
			else:
				differing += 1
				max_diff = maxi(max_diff, pixel_diff)
				diff.set_pixel(x, y, Color(1, 0, 1, 1))
	var sheet := Image.create(size.x * 3, size.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.16, 0.16, 0.16, 1))
	sheet.blend_rect(before, Rect2i(Vector2i.ZERO, size), Vector2i.ZERO)
	sheet.blend_rect(after, Rect2i(Vector2i.ZERO, size), Vector2i(size.x, 0))
	sheet.blit_rect(diff, Rect2i(Vector2i.ZERO, size), Vector2i(size.x * 2, 0))
	sheet.save_png(_export_dir.path_join("%s_%s_before_after_diff.png" % [pack_id, name]))
	var summary := FileAccess.open(_export_dir.path_join("%s_%s.json" % [pack_id, name]), FileAccess.WRITE)
	if summary != null:
		summary.store_string(JSON.stringify({"pack": pack_id, "animation": name, "differing_pixels": differing, "max_channel_difference": max_diff, "capture": [size.x, size.y]}))


# --- E. import settings -------------------------------------------------------

func _check_import_settings(manifest: Dictionary) -> void:
	for page in manifest.get("pages", []):
		var sidecar := FileAccess.get_file_as_string(str(page["path"]) + ".import")
		if sidecar.is_empty():
			_fail("%s: missing import sidecar for %s." % [manifest["pack"], page["path"]])
			continue
		if not sidecar.contains("compress/mode=0"):
			_fail("%s: %s.import is not lossless." % [manifest["pack"], page["path"]])
		if not sidecar.contains("mipmaps/generate=false"):
			_fail("%s: %s.import generates mipmaps." % [manifest["pack"], page["path"]])


# --- F. lifecycle --------------------------------------------------------------

func _check_lifecycle(frames_path: String) -> void:
	var frames := load(frames_path) as SpriteFrames
	var name := frames.get_animation_names()[0]
	var texture := frames.get_frame_texture(name, 0) as AtlasTexture
	var region_before := texture.region
	var margin_before := texture.margin
	frames = null
	texture = null
	await process_frame
	await process_frame
	var reloaded := load(frames_path) as SpriteFrames
	if reloaded == null:
		_fail("lifecycle: cold reload of %s failed." % frames_path)
		return
	var reloaded_texture := reloaded.get_frame_texture(name, 0) as AtlasTexture
	if reloaded_texture == null or reloaded_texture.region != region_before or reloaded_texture.margin != margin_before:
		_fail("lifecycle: reloaded frame geometry differs.")
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	if orphans != 0:
		_fail("lifecycle: %d orphan nodes after reload." % orphans)
