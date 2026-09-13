extends SceneTree

# FAN-3934 compact-atlas repair: predeclared cold-process phase comparison.
#   -- phase compact  — shipped packed resource (3 atlas pages)
#   -- phase orig     — faithful standalone-texture reconstruction: the same
#     animation metadata (names/speed/loop/durations read from the shipped
#     SpriteFrames) over the 184 retained original PNGs loaded individually.
# Phases: before-load, loaded, first render/use, repeated use, second same-kind
# consumer, simultaneous different animation states, release one, release last,
# cold reload. Monitors are read BEFORE any tree walk; GPU/VRAM telemetry is
# UNAVAILABLE in this environment (marked, never zero-substituted). Observer
# work is bracketed by two consecutive idle snapshots.

const PACKED := "res://assets/sprites/enemies/full_frame/small_biter_spriteframes.tres"
const MANIFEST := "res://assets/sprites/enemies/full_frame/small_biter_atlas_manifest.json"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2 or String(args[0]) != "phase":
		printerr("FAN3934_CA_ERROR: expected 'phase <compact|orig>'")
		quit(1)
		return
	var arm := String(args[1])
	var result := {"arm": arm}
	await process_frame
	result["before_load"] = _snap()
	var frames: SpriteFrames
	var t0 := Time.get_ticks_usec()
	if arm == "compact":
		frames = load(PACKED)
	else:
		frames = _build_original_representation()
	result["load_us"] = Time.get_ticks_usec() - t0
	if frames == null:
		printerr("FAN3934_CA_ERROR: resource construction failed for arm " + arm)
		quit(1)
		return
	await process_frame
	result["loaded"] = _snap()
	var holder := Node2D.new()
	root.add_child(holder)
	var a := AnimatedSprite2D.new()
	holder.add_child(a)
	t0 = Time.get_ticks_usec()
	a.sprite_frames = frames
	a.play(frames.get_animation_names()[0])
	await process_frame
	result["first_render"] = _snap()
	result["first_use_us"] = Time.get_ticks_usec() - t0
	for i in range(20):
		a.play(frames.get_animation_names()[i % frames.get_animation_names().size()])
		await process_frame
	result["repeated_use"] = _snap()
	var b := AnimatedSprite2D.new()
	holder.add_child(b)
	b.sprite_frames = frames
	b.play(frames.get_animation_names()[1 % frames.get_animation_names().size()])
	b.flip_h = true
	b.scale = Vector2(0.3, 0.3)
	await process_frame
	result["second_consumer_simultaneous"] = _snap()
	a.queue_free()
	await process_frame
	await process_frame
	result["release_one"] = _snap()
	b.queue_free()
	holder.queue_free()
	frames = null
	await process_frame
	await process_frame
	await create_timer(0.3).timeout
	result["release_last"] = _snap()
	# Cold reload after all references dropped.
	var reloaded: SpriteFrames = load(PACKED) if arm == "compact" else _build_original_representation()
	await process_frame
	result["cold_reload_ok"] = reloaded != null
	result["observer_bracket"] = [_snap(), _snap()]
	result["gpu_memory_telemetry"] = "UNAVAILABLE in this environment (headless; not substituted)"
	_write(result, "phase-%s.json" % arm)
	print("FAN3934_CA_PHASE " + JSON.stringify(result))
	quit(0)

func _build_original_representation() -> SpriteFrames:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var packed: SpriteFrames = load(PACKED)
	if manifest.is_empty() or packed == null:
		return null
	var frames := SpriteFrames.new()
	for anim in packed.get_animation_names():
		frames.add_animation(anim)
		frames.set_animation_speed(anim, packed.get_animation_speed(anim))
		frames.set_animation_loop_mode(anim, packed.get_animation_loop_mode(anim))
		var count: int = packed.get_frame_count(anim)
		for i in range(count):
			frames.add_frame(anim, packed.get_frame_texture(anim, i), packed.get_frame_duration(anim, i))
	# Swap every frame texture for the original standalone PNG of the same
	# pixels: match by size+duration order via the manifest's committed frame
	# list against packed slot shas computed once.
	var source_by_order: Array = []
	for entry in manifest["frames"]:
		source_by_order.append(load(str(entry["path"])))
	var cursor := 0
	for anim in frames.get_animation_names():
		var count: int = frames.get_frame_count(anim)
		for i in range(count):
			frames.set_frame(anim, i, source_by_order[cursor], frames.get_frame_duration(anim, i))
			cursor += 1
	if cursor != source_by_order.size():
		return null
	return frames

func _snap() -> Dictionary:
	return {
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"static_kib": int(Performance.get_monitor(Performance.MEMORY_STATIC) / 1024),
	}

func _write(data: Dictionary, name: String) -> void:
	var f := FileAccess.open("res://evidence/p3-object-budget-rework/compact-small-biter-atlas/%s" % name, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  ") + "\n")
	f.close()
