extends SceneTree

const OUT_PATH := "res://assets/sprites/allies/ally_druid_wolf_spriteframes.tres"
const FRAME_DIR := "res://assets/sprites/allies/druid_wolf/"


func _initialize() -> void:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	_add_animation(frames, "move", 8, 12.0, true)
	_add_animation(frames, "attack", 6, 14.0, false)
	var err := ResourceSaver.save(frames, OUT_PATH)
	if err != OK:
		push_error("Failed to save %s: %s" % [OUT_PATH, err])
		quit(1)
		return
	print("Saved ", OUT_PATH)
	quit(0)


func _add_animation(frames: SpriteFrames, anim_name: String, count: int, fps: float, loop: bool) -> void:
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, loop)
	for index in range(count):
		var path := "%sally_druid_wolf_%s_%02d.png" % [FRAME_DIR, anim_name, index]
		var texture := load(path) as Texture2D
		if texture == null:
			push_error("Missing wolf frame texture: %s" % path)
			continue
		frames.add_frame(anim_name, texture)
