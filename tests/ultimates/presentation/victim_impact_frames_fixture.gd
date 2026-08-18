class_name VictimImpactFramesFixture
extends RefCounted

## Test-only SpriteFrames for the per-victim impact service (FAN-3008).
##
## The shipped impact packs are art-line work; a static one-frame stub in the
## game is forbidden by the FAN-3002 standard. So the runtime is proven against
## this generated flipbook, which never leaves `tests/`.

const ANIMATION := "impact"
const FRAME_COUNT := 6
const FRAME_SIZE := 16
const FRAME_FPS := 12.0


static func make(frame_count := FRAME_COUNT) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation(ANIMATION)
	frames.set_animation_speed(ANIMATION, FRAME_FPS)
	frames.set_animation_loop(ANIMATION, false)
	frames.remove_animation("default")
	for index in maxi(frame_count, 1):
		frames.add_frame(ANIMATION, _frame_texture(index))
	return frames


static func _frame_texture(index: int) -> Texture2D:
	var image := Image.create(FRAME_SIZE, FRAME_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 0.72, 0.36, 1.0 - float(index) / float(FRAME_COUNT)))
	return ImageTexture.create_from_image(image)
