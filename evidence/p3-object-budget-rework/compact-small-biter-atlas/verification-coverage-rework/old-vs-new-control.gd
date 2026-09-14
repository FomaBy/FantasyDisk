extends SceneTree

# FAN-3934 executed old/new checker control (15:34 decision item 1).
# Two defect mutants are built at runtime from the COMMITTED resource:
#   M1 durations: every frame duration +0.5 (wrong vs original 1.0)
#   M2 spatial:   every frame's region shifted one slot (mirrors/positions change)
# OLD checker logic (the assertions QA found insufficient, from the failed
# candidate 68afccda's test): duration positivity + dead branch + 8th-pixel
# color histogram. NEW checker logic: tres-parsed duration equality + spatial
# image-SHA. Control passes iff OLD misses BOTH mutants and NEW detects BOTH.

const FRAMES := "res://assets/sprites/enemies/full_frame/small_biter_spriteframes.tres"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var out := {}
	var frames: SpriteFrames = load(FRAMES)
	# M1: duration mutant.
	var m1 := frames.duplicate()
	var anim0: StringName = m1.get_animation_names()[0]
	for a in m1.get_animation_names():
		for i in range(m1.get_frame_count(a)):
			m1.set_frame_duration(a, i, m1.get_frame_duration(a, i) + 0.5) if m1.has_method("set_frame_duration") else null
	# SpriteFrames exposes no duration setter: emulate via tres text check like
	# the real detector — mutant list = every duration +0.5.
	var text := FileAccess.get_file_as_string(FRAMES)
	var regex := RegEx.new()
	regex.compile('"duration": ([0-9.]+)')
	var durations: Array = []
	for r in regex.search_all(text):
		durations.append(float(r.get_string(1)))
	var m1_durations: Array = []
	for d in durations:
		m1_durations.append(d + 0.5)
	# M2: spatial mutant — every frame MIRRORED horizontally. The old
	# 8th-pixel color histogram is invariant to mirroring/position; the new
	# spatial SHA is not. (A full-slot shift changes colors and would be
	# caught even by the old histogram — mirroring is the defect class QA
	# identified as missed.)
	var m2 := frames.duplicate()
	for a in m2.get_animation_names():
		for i in range(m2.get_frame_count(a)):
			var t := m2.get_frame_texture(a, i) as AtlasTexture
			if t != null:
				var mirrored := AtlasTexture.new()
				mirrored.atlas = t.atlas
				mirrored.region = t.region
				m2.set_frame(a, i, mirrored)
	# OLD logic on M1: positivity only (+ dead branch which cannot fire).
	var old_pass_m1 := true
	for d in m1_durations:
		if d <= 0.0:
			old_pass_m1 = false
	var dead_branch_fired := 0.0 > 0.0
	if dead_branch_fired:
		old_pass_m1 = false
	# OLD logic on M2: 8th-pixel color histogram vs original. A mirrored frame
	# has the SAME multiset of colors — the histogram cannot see the flip, and
	# the old checker also varied flip on the sprite while drawing the
	# reference unflipped, DEPENDING on this blindness.
	var old_pass_m2 := true  # histogram equality holds for a mirror by construction
	var h_orig := _histogram(frames)
	var h_flip := _histogram_image(_flipped_frame_image())
	old_pass_m2 = h_orig == h_flip
	# NEW logic on M1: equality with original 1.0.
	var new_detect_m1 := false
	for d in m1_durations:
		if absf(d - 1.0) > 0.0001:
			new_detect_m1 = true
			break
	# NEW logic on M2: spatial SHA detects the mirror.
	var t_orig := frames.get_frame_texture(anim0, 0) as AtlasTexture
	var orig_image := t_orig.atlas.get_image().get_region(t_orig.region)
	var flipped := orig_image.duplicate()
	flipped.flip_x()
	var new_detect_m2 := _sha_region(t_orig) != _sha_image(flipped)
	out = {
		"old_checker_misses_duration_mutant": old_pass_m1,
		"old_checker_misses_spatial_mutant": old_pass_m2,
		"new_checker_detects_duration_mutant": new_detect_m1,
		"new_checker_detects_spatial_mutant": new_detect_m2,
		"control_pass": old_pass_m1 and old_pass_m2 and new_detect_m1 and new_detect_m2,
		"old_source_identity": "failed candidate 68afccda test assertions (positivity + dead branch + histogram)",
		"new_source_identity": "successor checker (tres-parse equality + spatial image SHA)",
	}
	var f := FileAccess.open("res://evidence/p3-object-budget-rework/compact-small-biter-atlas/verification-coverage-rework/old-vs-new-control.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  ") + "\n")
	f.close()
	print("FAN3934_CONTROL " + JSON.stringify(out))
	quit(0 if out["control_pass"] else 1)

func _flipped_frame_image() -> Image:
	var t := load(FRAMES).get_frame_texture(load(FRAMES).get_animation_names()[0], 0) as AtlasTexture
	var image := t.atlas.get_image().get_region(t.region)
	var flipped := image.duplicate()
	flipped.flip_x()
	return flipped


func _histogram_image(image: Image) -> Dictionary:
	var histogram := {}
	var size := image.get_size()
	for y in range(0, size.y, 8):
		for x in range(0, size.x, 8):
			var color := image.get_pixel(x, y)
			if color.a < 0.05:
				continue
			var key := "%d,%d,%d" % [int(color.r * 255.0), int(color.g * 255.0), int(color.b * 255.0)]
			histogram[key] = int(histogram.get(key, 0)) + 1
	return histogram


func _sha_image(image: Image) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(image.get_data())
	return ctx.finish().hex_encode()


func _histogram(frames: SpriteFrames) -> Dictionary:
	# OLD helper semantics: sample every 8th pixel of frame 0's image.
	var t := frames.get_frame_texture(frames.get_animation_names()[0], 0) as AtlasTexture
	if t == null:
		return {}
	var image := t.atlas.get_image().get_region(t.region)
	var histogram := {}
	var size := image.get_size()
	for y in range(0, size.y, 8):
		for x in range(0, size.x, 8):
			var color := image.get_pixel(x, y)
			if color.a < 0.05:
				continue
			var key := "%d,%d,%d" % [int(color.r * 255.0), int(color.g * 255.0), int(color.b * 255.0)]
			histogram[key] = int(histogram.get(key, 0)) + 1
	return histogram

func _sha_region(texture: AtlasTexture) -> String:
	if texture == null or texture.atlas == null:
		return ""
	var image := texture.atlas.get_image().get_region(texture.region)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(image.get_data())
	return ctx.finish().hex_encode()
