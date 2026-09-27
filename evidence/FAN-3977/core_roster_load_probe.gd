extends SceneTree

# FAN-3977: how long the core roster (enemies + mini-elites + allies) takes to
# become resident through the background prefetch, and the frame deltas on
# the main thread while it loads. Run headless (loader cost only) or windowed
# (real GL Compatibility texture uploads):
#   Godot --path <project> [--headless] --script <abs path to this file>

const FullFrameAnimationRegistry := preload("res://scripts/full_frame_animation_registry.gd")
const FullFrameEncounterRoster := preload("res://scripts/full_frame_encounter_roster.gd")
const ProgressionData := preload("res://scripts/progression_data.gd")


func _initialize() -> void:
	await _run()


func _run() -> void:
	for _i in range(20):
		await process_frame
	var core: Array = FullFrameEncounterRoster.core_paths(ProgressionData)
	var started := Time.get_ticks_usec()
	var last := started
	var deltas: Array = []
	var mem_before := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	for frames_path in core:
		FullFrameAnimationRegistry.queue_prefetch_path(str(frames_path))
	while true:
		await process_frame
		var now := Time.get_ticks_usec()
		deltas.append(float(now - last) / 1000.0)
		last = now
		if FullFrameAnimationRegistry.advance_prefetch() == 0:
			break
	var total_ms := float(Time.get_ticks_usec() - started) / 1000.0
	deltas.sort()
	var over_50 := 0
	var over_100 := 0
	var sum := 0.0
	for d in deltas:
		sum += d
		if d > 50.0:
			over_50 += 1
		if d > 100.0:
			over_100 += 1
	print("core roster: %d packs resident=%d in %.0f ms over %d frames; frame delta mean %.1f ms, p95 %.1f ms, max %.1f ms; frames >50 ms: %d, >100 ms: %d; texture mem %.0f -> %.0f MiB; renderer=%s" % [
		core.size(), FullFrameAnimationRegistry.prefetched_frames_count(), total_ms, deltas.size(), sum / max(1, deltas.size()),
		deltas[int(floor(float(deltas.size() - 1) * 0.95))], deltas[deltas.size() - 1], over_50, over_100,
		mem_before / 1048576.0, Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		RenderingServer.get_current_rendering_method()])
	FullFrameAnimationRegistry.release_prefetched()
	quit(0)
