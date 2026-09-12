extends SceneTree

# FAN-3934 read-only diagnostic: isolates the allocation source behind the
# ~46 non-node objects per FullFrameBody. Steps measured individually:
#   1. load() of the small_biter SpriteFrames (cached resource)
#   2. second load() (cache proof)
#   3. creating a bare AnimatedSprite2D
#   4. assigning the shared SpriteFrames
#   5. playing an animation
#   6. frames.duplicate() (per-instance copy hypothesis)

const FRAMES_PATH := "res://assets/sprites/enemies/full_frame/small_biter_spriteframes.tres"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var steps := {}
	var mark := func(step: String) -> void:
		steps[step] = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	mark.call("base")
	var frames: SpriteFrames = load(FRAMES_PATH)
	mark.call("after_load_1")
	load(FRAMES_PATH)
	mark.call("after_load_2_cached")
	var holder := Node2D.new()
	root.add_child(holder)
	await process_frame
	mark.call("after_holder")
	var body := AnimatedSprite2D.new()
	holder.add_child(body)
	await process_frame
	mark.call("after_animated_sprite")
	body.sprite_frames = frames
	await process_frame
	mark.call("after_assign_frames")
	var anims := frames.get_animation_names()
	steps["animation_count"] = anims.size()
	var total_frames := 0
	for a in anims:
		total_frames += int(frames.get_frame_count(a))
	steps["total_frame_count"] = total_frames
	if anims.size() > 0:
		body.play(anims[0])
		await process_frame
	mark.call("after_play")
	var body2 := AnimatedSprite2D.new()
	holder.add_child(body2)
	await process_frame
	body2.sprite_frames = frames.duplicate()
	await process_frame
	mark.call("after_duplicate_frames")
	print("FAN3934_ANATOMY_RESULT " + JSON.stringify(steps))
	quit(0)
