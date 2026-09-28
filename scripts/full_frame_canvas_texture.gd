extends Texture2D
class_name FullFrameCanvasTexture

# FAN-3981 (0.3.1 release blocker, FAN-3964 QA M3): the logical canvas of a
# trim-atlas full-frame pack, drawn by nothing.
#
# Every frame of a trim-atlas SpriteFrames references ONE instance of this
# texture per pack instead of one `AtlasTexture` per unique frame, so a
# resident pack costs a handful of engine objects instead of ~230 (the
# 41 registry packs + the secret boss carry 9,438 frames; with 23 packs
# resident the route map alone sat at 7,606 objects against the perf
# checklist's 5,000/6,250 P2 line). `get_size()` still reports the original
# 512x512 (allies: 256x256) canvas, so `AnimatedSprite2D` computes the same
# destination rectangle as before and consumers that measure the frame
# texture (`enemy.gd` contact fitting, the actor smokes) see the unchanged
# canvas. The pixels come from the pack's `FullFrameTrimAtlas` (the
# SpriteFrames' `metadata/full_frame_trim_atlas`), which draws the trimmed
# region of the atlas page at the frame's canvas offset from the sprite's
# `draw` signal — see `FullFrameTrimAtlas.attach`.
#
# `_draw`, `_draw_rect` and `_draw_rect_region` are explicit no-ops: a
# script texture that leaves them unimplemented is drawn by the engine's
# RID fallback as an opaque white canvas-sized quad.

@export var size := Vector2i(512, 512)


func _get_width() -> int:
	return size.x


func _get_height() -> int:
	return size.y


func _has_alpha() -> bool:
	return true


func _is_pixel_opaque(_x: int, _y: int) -> bool:
	return false


func _draw(_to_canvas_item: RID, _pos: Vector2, _modulate: Color, _transpose: bool) -> void:
	pass


func _draw_rect(_to_canvas_item: RID, _rect: Rect2, _tile: bool, _modulate: Color, _transpose: bool) -> void:
	pass


func _draw_rect_region(_to_canvas_item: RID, _rect: Rect2, _src_rect: Rect2, _modulate: Color, _transpose: bool, _clip_uv: bool) -> void:
	pass
