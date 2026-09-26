extends SceneTree

# FAN-3973 first-spawn cost probe (run WINDOWED so texture uploads hit the real
# GL compatibility renderer, exactly like a spawn in a fight):
#
#   Godot --path <project> --script <abs path to this file> -- [prefetch]
#
# Phase A ("first use", the path `configure_entity_visual` takes when a pack is
# not cached): time `sprite_frames_for` for representative actors with an
# empty cache. This is the pre-existing synchronous cost in v0.3.0/v0.3.1 and
# the unchanged fallback in the candidate.
#
# Phase B (candidate only, pass `prefetch` after `--`): queue the enemy pool +
# one elite + one boss through the registry prefetch, drain it while sampling
# main-thread frame deltas (a stall shows up as a long frame), then time
# `sprite_frames_for` for the same actors again — now served from the
# resident prefetch.
#
# Prints a Markdown table on stdout.

const FullFrameAnimationRegistry := preload("res://scripts/full_frame_animation_registry.gd")
# Untyped alias so the prefetch calls (candidate only) resolve at runtime and
# the same probe still compiles against v0.3.0/v0.3.1 for phase A.
var _registry: Variant = FullFrameAnimationRegistry

const PROBED_ACTORS := [
	["enemy", "small_biter"],
	["enemy", "rift_cutter"],
	["enemy", "ash_marksman"],
	["elite", "iron_bastion"],
	["boss", "rift_warden"],
]
const SETTLE_FRAMES := 30


func _initialize() -> void:
	await _run()


func _run() -> void:
	var with_prefetch := OS.get_cmdline_user_args().has("prefetch")
	# Let the window/renderer settle before timing anything.
	for _i in range(SETTLE_FRAMES):
		await process_frame
	print("probe: renderer=%s vsync=%s prefetch=%s" % [RenderingServer.get_current_rendering_method(), DisplayServer.window_get_vsync_mode(), with_prefetch])
	print("")
	print("| phase | actor | frames | sprite_frames_for (ms) | frame delta during load (ms) |")
	print("|---|---|---|---|---|")

	var texture_mem_before := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	var held: Array = []
	for actor in PROBED_ACTORS:
		var before_frame_usec := Time.get_ticks_usec()
		await process_frame
		var started := Time.get_ticks_usec()
		var frames := FullFrameAnimationRegistry.sprite_frames_for(actor[0], actor[1])
		var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
		await process_frame
		var frame_delta_ms := float(Time.get_ticks_usec() - before_frame_usec) / 1000.0
		held.append(frames)
		print("| A first use (sync) | %s/%s | %d | %.1f | %.1f |" % [actor[0], actor[1], _frame_count(frames), elapsed_ms, frame_delta_ms])
	var texture_mem_after := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	print("")
	print("phase A texture memory: %.0f MiB -> %.0f MiB for %d packs" % [texture_mem_before / 1048576.0, texture_mem_after / 1048576.0, held.size()])
	held.clear()
	for _i in range(SETTLE_FRAMES):
		await process_frame
	print("phase A texture memory after release: %.0f MiB" % (Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0))

	if not with_prefetch:
		quit(0)
		return

	print("")
	var queued: int = _registry.queue_prefetch_kind("enemy")
	queued += 1 if _registry.queue_prefetch("elite", "iron_bastion") else 0
	queued += 1 if _registry.queue_prefetch("boss", "rift_warden") else 0
	var prefetch_started := Time.get_ticks_usec()
	var last_frame := Time.get_ticks_usec()
	var deltas: Array = []
	var frames_seen := 0
	while true:
		await process_frame
		var now := Time.get_ticks_usec()
		deltas.append(float(now - last_frame) / 1000.0)
		last_frame = now
		frames_seen += 1
		if int(_registry.advance_prefetch()) == 0:
			break
		if frames_seen > 20000:
			print("prefetch did not finish within 20000 frames")
			break
	var prefetch_ms := float(Time.get_ticks_usec() - prefetch_started) / 1000.0
	deltas.sort()
	var p95: float = deltas[int(floor(float(deltas.size() - 1) * 0.95))]
	var maximum: float = deltas[deltas.size() - 1]
	var mean := 0.0
	for delta in deltas:
		mean += delta
	mean /= max(1, deltas.size())
	print("phase B prefetch: %d packs resident in %.0f ms over %d frames; frame delta mean %.1f ms, p95 %.1f ms, max %.1f ms; texture memory %.0f MiB; static memory %.0f MiB" % [
		int(_registry.prefetched_frames_count()), prefetch_ms, frames_seen, mean, p95, maximum,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
	print("")
	for actor in PROBED_ACTORS:
		var before_frame_usec := Time.get_ticks_usec()
		await process_frame
		var started := Time.get_ticks_usec()
		var frames := FullFrameAnimationRegistry.sprite_frames_for(actor[0], actor[1])
		var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
		await process_frame
		var frame_delta_ms := float(Time.get_ticks_usec() - before_frame_usec) / 1000.0
		print("| B after prefetch | %s/%s | %d | %.3f | %.1f |" % [actor[0], actor[1], _frame_count(frames), elapsed_ms, frame_delta_ms])
	_registry.release_prefetched()
	quit(0)


func _frame_count(frames: SpriteFrames) -> int:
	if frames == null:
		return 0
	var total := 0
	for animation_name in frames.get_animation_names():
		total += frames.get_frame_count(animation_name)
	return total
