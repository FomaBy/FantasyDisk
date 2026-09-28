extends Resource
class_name FullFrameTrimAtlas

# FAN-3981 (0.3.1 release blocker, FAN-3964 QA M3): compact frame table of a
# trim-atlas full-frame pack, and the region draw that replaces one
# `AtlasTexture` sub-resource per frame.
#
# FAN-3977 shrank every pack into lossless trim atlases but kept one
# `AtlasTexture` object per unique frame (184-432 per pack), so the packs
# the encounter roster keeps resident cost ~230 engine objects each and the
# route map with the core roster resident read 7,606 `Performance.
# OBJECT_COUNT` (P2 8,643-8,719 against the checklist's 5,000 target /
# 6,250 red line; v0.3.0 measured 4,014-4,041). This resource holds the
# same geometry as plain arrays (no objects): one entry per unique frame
# (`entries`, ENTRY_STRIDE ints: page index, region x/y/w/h on that page,
# canvas offset x/y of the trim), and per animation the entry index of
# every frame (`animations`). The SpriteFrames keeps every animation name,
# order, loop flag, speed and per-frame duration; every frame's texture is
# the pack's single `FullFrameCanvasTexture`, which reports the canvas size
# and draws nothing, and the SpriteFrames carries this table as
# `metadata/full_frame_trim_atlas` (META_KEY).
#
# Drawing: `attach` connects the sprite's `draw` signal to `_draw_sprite`,
# which draws the current frame's page region at the same destination
# rectangle `AtlasTexture.draw_rect_region` produced for the same
# `AnimatedSprite2D` state — `offset`, `centered`, `flip_h`/`flip_v` and the
# pixel-snap rounding of `AnimatedSprite2D::_notification(NOTIFICATION_DRAW)`
# — so the on-screen position, size, flip axis and sampling of every frame
# are unchanged (`tests/full_frame_trim_atlas_parity_test.gd` compares the
# captures against the AtlasTexture representation with zero tolerance).
# The registry attaches every body it configures
# (`FullFrameAnimationRegistry.configure_entity_visual`); a tool or test
# that assigns a pack to its own `AnimatedSprite2D` must call `attach` too.
#
# Built by tools/build_full_frame_trim_atlases.py from the pack's trim
# manifest; `frame_entry` / `frame_canvas_image` / `frame_sources` give
# tests and tools the geometry, the canvas pixels and the retained source
# frames of a frame without any AtlasTexture.

const META_KEY := "full_frame_trim_atlas"
const ENTRY_STRIDE := 7
# Engine objects one resident pack may cost: the SpriteFrames, its canvas
# texture and this table (3) plus one CompressedTexture2D per page (the
# secret boss has 14) and slack; the FAN-3977 representation cost 184-435.
# Asserted per pack by tests/full_frame_trim_atlas_parity_test.gd and per
# encounter roster by tests/full_frame_combat_residency_test.gd.
const RESIDENT_OBJECT_BUDGET := 24
const DRAW_ATTACHED_META := "full_frame_trim_draw"
const MANIFEST_SUFFIX := "_trim_manifest.json"

@export var canvas := Vector2i(512, 512)
@export var pages: Array[Texture2D] = []
@export var entries := PackedInt32Array()
# animation name (String) -> PackedInt32Array of entry indices, one per frame.
@export var animations: Dictionary = {}


static func of(frames: SpriteFrames) -> FullFrameTrimAtlas:
	if frames == null or not frames.has_meta(META_KEY):
		return null
	return frames.get_meta(META_KEY) as FullFrameTrimAtlas


static func is_trim_atlas_frames(frames: SpriteFrames) -> bool:
	return of(frames) != null


# Draws the trimmed frames of whatever trim-atlas SpriteFrames the sprite
# plays. Idempotent; harmless on a sprite that plays ordinary SpriteFrames
# (the draw callback finds no table and returns).
static func attach(sprite: AnimatedSprite2D) -> bool:
	if sprite == null:
		return false
	if bool(sprite.get_meta(DRAW_ATTACHED_META, false)):
		return true
	sprite.draw.connect(FullFrameTrimAtlas._draw_sprite.bind(sprite))
	sprite.set_meta(DRAW_ATTACHED_META, true)
	sprite.queue_redraw()
	return true


static func is_attached(sprite: AnimatedSprite2D) -> bool:
	return sprite != null and bool(sprite.get_meta(DRAW_ATTACHED_META, false))


static func _draw_sprite(sprite: AnimatedSprite2D) -> void:
	var atlas := of(sprite.sprite_frames)
	if atlas != null:
		atlas.draw_frame(sprite, sprite.animation, sprite.frame)


func entry_count() -> int:
	return entries.size() / ENTRY_STRIDE


func entry_index(animation: StringName, frame_index: int) -> int:
	var indices: PackedInt32Array = animations.get(animation, PackedInt32Array())
	if frame_index < 0 or frame_index >= indices.size():
		return -1
	return indices[frame_index]


# {"page": int, "region": Rect2i, "margin": Rect2i, "canvas": Vector2i} —
# the same geometry the FAN-3977 AtlasTexture carried (`margin` position is
# the canvas offset of the trim, its size restores the canvas). Empty when
# the frame is unknown.
func entry(index: int) -> Dictionary:
	if index < 0 or index >= entry_count():
		return {}
	var base := index * ENTRY_STRIDE
	var region := Rect2i(entries[base + 1], entries[base + 2], entries[base + 3], entries[base + 4])
	var margin_position := Vector2i(entries[base + 5], entries[base + 6])
	return {
		"page": entries[base],
		"region": region,
		"margin": Rect2i(margin_position, canvas - region.size),
		"canvas": canvas,
	}


func frame_entry(animation: StringName, frame_index: int) -> Dictionary:
	return entry(entry_index(animation, frame_index))


func page_texture(page_index: int) -> Texture2D:
	if page_index < 0 or page_index >= pages.size():
		return null
	return pages[page_index]


# Draws `animation[frame_index]` on `item` exactly where the native
# AnimatedSprite2D draw placed the canvas-sized frame texture: the trim
# region lands at the canvas offset, mirrored around the canvas centre when
# flipped, with the same source rectangle and no UV clipping (the
# AtlasTexture had `filter_clip` off). Returns false when nothing is drawn.
func draw_frame(item: CanvasItem, animation: StringName, frame_index: int) -> bool:
	var index := entry_index(animation, frame_index)
	if index < 0:
		return false
	var base := index * ENTRY_STRIDE
	var page := page_texture(entries[base])
	if page == null:
		return false
	var region := Rect2(entries[base + 1], entries[base + 2], entries[base + 3], entries[base + 4])
	var trim_offset := Vector2(entries[base + 5], entries[base + 6])
	var canvas_size := Vector2(canvas)
	var flip_h := false
	var flip_v := false
	var origin := Vector2.ZERO
	if item is AnimatedSprite2D:
		var sprite := item as AnimatedSprite2D
		flip_h = sprite.flip_h
		flip_v = sprite.flip_v
		origin = sprite.offset
		if sprite.centered:
			origin -= canvas_size * 0.5
		var viewport := sprite.get_viewport()
		if viewport != null and viewport.snap_2d_transforms_to_pixel:
			origin = (origin + Vector2(0.5, 0.5)).floor()
	else:
		origin = -canvas_size * 0.5
	var destination := Rect2(origin + trim_offset, region.size)
	if flip_h:
		destination.position.x = origin.x + canvas_size.x - trim_offset.x - region.size.x
		destination.size.x = -destination.size.x
	if flip_v:
		destination.position.y = origin.y + canvas_size.y - trim_offset.y - region.size.y
		destination.size.y = -destination.size.y
	item.draw_texture_rect_region(page, destination, region, Color(1, 1, 1, 1), false, false)
	return true


# The frame as a canvas-sized RGBA8 image (trim pixels at the canvas
# offset, transparent elsewhere) — the image the retained source PNG holds.
# `page_images` caches decoded pages across calls when supplied.
func frame_canvas_image(animation: StringName, frame_index: int, page_images: Dictionary = {}) -> Image:
	var frame := frame_entry(animation, frame_index)
	if frame.is_empty():
		return null
	var page_index: int = frame["page"]
	var page_image: Image = page_images.get(page_index)
	if page_image == null:
		var page := page_texture(page_index)
		page_image = page.get_image() if page != null else null
		if page_image == null:
			return null
		if page_image.get_format() != Image.FORMAT_RGBA8:
			page_image.convert(Image.FORMAT_RGBA8)
		page_images[page_index] = page_image
	var region: Rect2i = frame["region"]
	var margin: Rect2i = frame["margin"]
	var image := Image.create(canvas.x, canvas.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	image.blit_rect(page_image.get_region(region), Rect2i(Vector2i.ZERO, region.size), margin.position)
	return image


# Retained source PNGs (res:// paths) a frame was cut from, read from the
# pack's trim manifest (the entry with the same page/region/margin). Empty
# when the manifest is absent (exported builds exclude it).
static func manifest_path_for(frames_path: String) -> String:
	var pack_id := frames_path.get_file().trim_suffix(".tres").trim_suffix("_spriteframes")
	if frames_path.contains("/allies/"):
		pack_id = pack_id.trim_prefix("ally_")
	return frames_path.get_base_dir().path_join(pack_id + MANIFEST_SUFFIX)


static func load_manifest(frames_path: String) -> Dictionary:
	var manifest_path := manifest_path_for(frames_path)
	if not FileAccess.file_exists(manifest_path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	return parsed if parsed is Dictionary else {}


func frame_sources(frames_path: String, animation: StringName, frame_index: int, manifest: Dictionary = {}) -> Array:
	var frame := frame_entry(animation, frame_index)
	if frame.is_empty():
		return []
	if manifest.is_empty():
		manifest = load_manifest(frames_path)
	var page_index: int = frame["page"]
	var region: Rect2i = frame["region"]
	var margin: Rect2i = frame["margin"]
	for manifest_entry in manifest.get("entries", []):
		var entry_region: Array = manifest_entry["region"]
		var entry_margin: Array = manifest_entry["margin"]
		if int(manifest_entry["page"]) != page_index:
			continue
		if Rect2i(int(entry_region[0]), int(entry_region[1]), int(entry_region[2]), int(entry_region[3])) != region:
			continue
		if Rect2i(int(entry_margin[0]), int(entry_margin[1]), int(entry_margin[2]), int(entry_margin[3])) != margin:
			continue
		return manifest_entry["sources"]
	return []
