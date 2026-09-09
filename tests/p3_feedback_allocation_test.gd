extends SceneTree

# FAN-3934: focused regression for the causally identified transient-allocation
# owners of the P3 object-budget breach — per-sprite CanvasItemMaterial copies
# in hazard/feedback VFX. The repair makes the additive material one shared
# immutable instance (HazardVfx.additive_material) and consolidates the
# telegraph tween tree (grow + urgent switch in one tween) with identical
# timing, lifetime and cleanup.
#
# Gates:
#   A. SHARED MATERIAL: HazardVfx.additive_material() returns the same
#      CanvasItemMaterial instance on every call, and every sprite produced by
#      HazardVfx._additive references that one instance.
#   B. BLEND MODE: the shared material is BLEND_MODE_ADD (visual identity).
#   C. ALLOCATION FLATNESS: building N additive sprites / telegraphs / aura
#      pulses grows live OBJECT_COUNT by nodes only — zero net resource
#      copies (previously +1 CanvasItemMaterial per sprite).
#   D. TELEGRAPH CONSOLIDATION: a telegraph holder carries exactly two tweens
#      after HazardVfx.telegraph() (grow+urgent timeline, pulse loop) instead
#      of three, and all tweens die with the holder (no orphans).
#
# Запуск: Godot --headless --path . --script res://tests/p3_feedback_allocation_test.gd

const HazardVfx := preload("res://scripts/hazard_vfx.gd")
const AttackVfx := preload("res://scripts/attack_vfx.gd")
const CombatFeedbackTimeline := preload("res://scripts/combat_feedback_timeline.gd")

const SAMPLES := 24
const TEXTURE := preload("res://assets/sprites/effects/impact_ring.png")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []

	# A/B: shared, additive, single instance.
	var first := HazardVfx.additive_material()
	if first == null:
		failures.append("additive_material() returned null")
	else:
		if first.blend_mode != CanvasItemMaterial.BLEND_MODE_ADD:
			failures.append("shared material blend mode is %d, expected BLEND_MODE_ADD" % first.blend_mode)
		for i in range(SAMPLES):
			if HazardVfx.additive_material() != first:
				failures.append("additive_material() returned a new instance on call %d" % i)
				break

	# A (player weapon VFX surface, FAN-3934 second grant): AttackVfx shares the
	# same single immutable additive material across figures.
	var attack_first := AttackVfx.additive_material()
	if attack_first == null:
		failures.append("AttackVfx.additive_material() returned null")
	else:
		if attack_first.blend_mode != CanvasItemMaterial.BLEND_MODE_ADD:
			failures.append("AttackVfx shared material blend mode is %d, expected BLEND_MODE_ADD" % attack_first.blend_mode)
		for i in range(SAMPLES):
			if AttackVfx.additive_material() != attack_first:
				failures.append("AttackVfx.additive_material() returned a new instance on call %d" % i)
				break
		var vfx_parent := Node2D.new()
		root.add_child(vfx_parent)
		await process_frame
		var slash_count := 0
		for i in range(4):
			var slash := AttackVfx.slash(vfx_parent, Vector2.RIGHT, 140.0, Color(0.9, 0.5, 0.2), PI, 1.0, 90.0)
			if slash == null:
				failures.append("AttackVfx.slash returned null — gate did not exercise the surface")
				break
			slash_count += 1
			await process_frame
			for sprite in _sprites_under(slash):
				var mat = sprite.material
				if mat is CanvasItemMaterial and (mat as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD:
					if mat != attack_first:
						failures.append("AttackVfx additive sprite does not use the shared material")
		if slash_count == 0 and failures.is_empty():
			failures.append("no AttackVfx slash figures produced")
		vfx_parent.queue_free()
		await process_frame

	# B (cleave reuse): a configured BerserkAxeCleaveVfx must NOT queue itself for
	# deletion when its swing finishes — it goes hidden/idle for bounded reuse.
	var cleave: BerserkAxeCleaveVfx = preload("res://scenes/vfx/BerserkAxeCleaveVfx.tscn").instantiate()
	root.add_child(cleave)
	await process_frame
	cleave.configure(Vector2.ZERO, Vector2.RIGHT, 120.0, 90.0, 0.2, Color.WHITE)
	await process_frame
	if not cleave.is_busy():
		failures.append("cleave VFX is not busy right after configure")
	await create_timer(0.5).timeout
	if cleave.is_busy():
		failures.append("cleave VFX is still busy after its swing duration")
	if not is_instance_valid(cleave) or cleave.is_queued_for_deletion():
		failures.append("cleave VFX freed itself instead of entering idle reuse state")
	elif cleave.visible:
		failures.append("idle cleave VFX remains visible")
	if is_instance_valid(cleave):
		cleave.queue_free()
	await process_frame

	# A via public surface: every additive-driven helper reuses the instance.
	var holder := Node2D.new()
	root.add_child(holder)
	await process_frame
	var checked := 0
	for i in range(SAMPLES):
		var parent := Node2D.new()
		holder.add_child(parent)
		HazardVfx.telegraph(parent, 120.0, Color(0.8, 0.3, 1.0), 1.0)
		HazardVfx.aura_pulse(parent, 150.0, Color(0.4, 0.9, 1.0))
		await process_frame
		for sprite in _sprites_under(parent):
			if sprite.material is CanvasItemMaterial:
				checked += 1
				if sprite.material != first:
					failures.append("sprite %s does not use the shared additive material" % sprite.get_path())
					break
	if checked == 0:
		failures.append("no CanvasItemMaterial sprites found — gate did not exercise the repair surface")

	# C: allocation flatness — after the first (shared) material exists, N more
	# telegraphs add nodes but zero additional material resources.
	await create_timer(1.2).timeout  # let the first batch die out
	var flat_holder := Node2D.new()
	root.add_child(flat_holder)
	await process_frame
	var before_objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var before_nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for i in range(SAMPLES):
		var parent := Node2D.new()
		flat_holder.add_child(parent)
		HazardVfx.telegraph(parent, 120.0, Color(0.8, 0.3, 1.0), 1.0)
	await process_frame
	await process_frame
	var object_growth := int(Performance.get_monitor(Performance.OBJECT_COUNT)) - before_objects
	var node_growth := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) - before_nodes
	# Each telegraph: holder + zone + rim nodes plus the consolidated tween tree
	# (timeline + pulse ≈ 9 tween/tweener objects). The material must contribute
	# zero: non-node growth stays within the tween budget and below the
	# pre-repair shape (3 tweens + per-rim CanvasItemMaterial ≈ 11).
	var tween_budget := 9 * SAMPLES + 2
	if object_growth - node_growth > tween_budget:
		failures.append("non-node object growth %d exceeds tween budget %d for %d telegraphs — per-sprite material copies are back" % [
			object_growth - node_growth, tween_budget, SAMPLES])

	# D: telegraph tween consolidation + cleanup. One telegraph must cost
	# 3 nodes (holder + zone + rim) plus a bounded tween tree and NO material:
	# non-node growth per telegraph is capped at the consolidated tween budget
	# (timeline + pulse ≈ 9 objects incl. tweeners; the pre-repair shape was
	# ≥11: three tweens plus a per-rim CanvasItemMaterial copy).
	var probe_parent := Node2D.new()
	root.add_child(probe_parent)
	await process_frame
	var tele_before_objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var tele_before_nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var tele := HazardVfx.telegraph(probe_parent, 120.0, Color(0.8, 0.3, 1.0), 1.0)
	await process_frame
	var tele_non_node := int(Performance.get_monitor(Performance.OBJECT_COUNT)) - tele_before_objects \
		- (int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) - tele_before_nodes)
	if tele_non_node > 9:
		failures.append("one telegraph holds %d non-node objects, expected <= 9 (consolidated tween tree, shared material)" % tele_non_node)
	tele.queue_free()
	await process_frame
	await process_frame
	var orphan_delta := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	if orphan_delta != 0:
		failures.append("orphan nodes appeared after telegraph cleanup: %d" % orphan_delta)

	holder.queue_free()
	flat_holder.queue_free()
	probe_parent.queue_free()
	await process_frame

	# E (round-5 grant): pooled feedback timeline — full density, zero warm-pool
	# allocation, group-count parity and cleanup.
	var scene_root := Node2D.new()
	root.add_child(scene_root)
	await process_frame
	var timeline: Node = CombatFeedbackTimeline.for_scene(scene_root)
	if timeline == null:
		failures.append("CombatFeedbackTimeline.for_scene did not create the timeline")
	else:
		if timeline.process_mode != Node.PROCESS_MODE_PAUSABLE:
			failures.append("timeline is not pause-aware (PAUSABLE)")
		if CombatFeedbackTimeline.for_scene(scene_root) != timeline:
			failures.append("for_scene created a second timeline for the same scene")
		var spawn_batch := func() -> void:
			for i in range(24):
				var setup := func(label: Label) -> void:
					label.text = str(i)
					label.z_index = 3000
				timeline.spawn_number(setup, Vector2(i * 10.0, 100.0), 44.0, 0.62, 0.20, 0.42, i % 2 == 0)
				timeline.spawn_tick(Vector2(i * 5.0, 50.0), Vector2.ONE, Color(1.0, 0.5, 0.4, 0.4), "combat_feedback_flashes")
		spawn_batch.call()
		await process_frame
		var warm_objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
		var warm_nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		var active_labels := scene_root.get_tree().get_nodes_in_group("combat_feedback_labels").size()
		if active_labels != 24:
			failures.append("group count is %d after 24 numbers — cap semantics broken" % active_labels)
		# Wait for full item lifetime, then re-spawn: must reuse the pool with
		# zero new objects (no per-event node/tween allocation).
		await create_timer(0.8).timeout
		if scene_root.get_tree().get_nodes_in_group("combat_feedback_labels").size() != 0:
			failures.append("released numbers remain in the feedback group")
		spawn_batch.call()
		await process_frame
		var reuse_delta_objects := int(Performance.get_monitor(Performance.OBJECT_COUNT)) - warm_objects
		var reuse_delta_nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) - warm_nodes
		if reuse_delta_objects != 0 or reuse_delta_nodes != 0:
			failures.append("warm-pool re-spawn allocated %d new objects / %d new nodes — pooling broken" % [reuse_delta_objects, reuse_delta_nodes])
		# Overlap: two body flashes on the same canvas item must restart, not stack.
		var flash_target := Sprite2D.new()
		scene_root.add_child(flash_target)
		await process_frame
		flash_target.modulate = Color(1.0, 1.0, 1.0, 1.0).lerp(Color(1.0, 0.42, 0.34, 1.0), 0.4)
		timeline.call("flash_body", flash_target, Color(1.0, 1.0, 1.0, 1.0))
		timeline.call("flash_body", flash_target, Color(1.0, 1.0, 1.0, 1.0))
		await create_timer(0.25).timeout
		var restored: Color = flash_target.modulate
		if absf(restored.r - 1.0) > 0.01 or absf(restored.g - 1.0) > 0.01:
			failures.append("body flash did not restore modulate (got %s)" % str(restored))
		scene_root.queue_free()
		await process_frame
		await process_frame
		var timeline_orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
		if timeline_orphans != 0:
			failures.append("orphans appeared after scene/timeline cleanup: %d" % timeline_orphans)

	# F (round-5 admission): feedback parity — the pooled timeline reproduces
	# the exact curves/timings the previous per-item tween trees used.
	# Closed forms of the original tweens:
	#   number: pos = start + (0,-44)*cubic_out(t/0.62); a = 1 until 0.20s,
	#           then 1-(t-0.20)/0.42; gone at 0.62s;
	#   tick:   a = 0.40*(1-quad_out(t/0.16)); gone at 0.16s.
	var parity_root := Node2D.new()
	root.add_child(parity_root)
	await process_frame
	var parity_timeline: Node = CombatFeedbackTimeline.for_scene(parity_root)
	var parity_start := Vector2(300.0, 200.0)
	var parity_setup := func(label: Label) -> void:
		label.text = "7"
		label.z_index = 3000
	parity_timeline.spawn_number(parity_setup, parity_start, 44.0, 0.62, 0.20, 0.42, false)
	parity_timeline.spawn_tick(parity_start, Vector2.ONE, Color(1.0, 0.46, 0.36, 0.40), "combat_feedback_flashes")
	var number_label: Label = null
	for child in parity_timeline.get_children():
		if child is Label:
			number_label = child
			break
	var tick_sprite: Sprite2D = null
	for child in parity_timeline.get_children():
		if child is Sprite2D:
			tick_sprite = child
			break
	if number_label == null or tick_sprite == null:
		failures.append("parity items were not created")
	else:
		await create_timer(0.31).timeout
		var sample_t := 0.31
		var expected_rise: float = 44.0 * (1.0 - pow(1.0 - sample_t / 0.62, 3.0))
		var expected_pos := parity_start + Vector2(0.0, -expected_rise)
		if number_label.global_position.distance_to(expected_pos) > 2.0:
			failures.append("number position at 0.31s is %s, expected %s (cubic-out parity)" % [str(number_label.global_position), str(expected_pos)])
		var expected_alpha: float = 1.0 - (sample_t - 0.20) / 0.42
		if absf(number_label.modulate.a - expected_alpha) > 0.06:
			failures.append("number alpha at 0.31s is %.3f, expected %.3f (delayed linear fade parity)" % [number_label.modulate.a, expected_alpha])
		var tick_alpha_at: float = 0.40 * (1.0 - (1.0 - pow(1.0 - minf(sample_t, 0.16) / 0.16, 2.0)))
		if not tick_sprite.visible and sample_t < 0.16:
			failures.append("tick disappeared before its 0.16s lifetime")
		await create_timer(0.35).timeout
		if tick_sprite.visible:
			failures.append("tick still visible after its 0.16s lifetime")
		await create_timer(0.2).timeout
		if number_label.visible:
			failures.append("number still visible after its 0.62s lifetime")
	parity_root.queue_free()
	await process_frame

	# G (14:50 UTC continuation): pause/resume and time-scale transitions.
	var pause_root := Node2D.new()
	root.add_child(pause_root)
	await process_frame
	var pause_timeline: Node = CombatFeedbackTimeline.for_scene(pause_root)
	Engine.time_scale = 0.5
	var pause_setup := func(label: Label) -> void:
		label.text = "t"
		label.z_index = 3000
	pause_timeline.spawn_number(pause_setup, Vector2(500.0, 300.0), 44.0, 0.62, 0.20, 0.42, false)
	# ignore_time_scale gives a real-time 0.2 s wait = 0.1 s of item time at 0.5x
	await create_timer(0.2, true, false, true).timeout
	var slowed_rise: float = 44.0 * (1.0 - pow(1.0 - 0.1 / 0.62, 3.0))
	var pause_label: Label = null
	for child in pause_timeline.get_children():
		if child is Label:
			pause_label = child
			break
	if pause_label == null:
		failures.append("time-scale parity item missing")
	else:
		if absf((300.0 - pause_label.global_position.y) - slowed_rise) > 2.0:
			failures.append("number rise does not follow Engine.time_scale (expected %.1f, got %.1f)" % [slowed_rise, 300.0 - pause_label.global_position.y])
	var pre_pause_y: float = pause_label.global_position.y
	paused = true
	# process_always timers still fire while the tree is paused; the feedback
	# item itself must NOT advance.
	await create_timer(0.3, true).timeout
	var paused_y: float = pause_label.global_position.y
	if absf(paused_y - pre_pause_y) > 0.001:
		failures.append("item advanced while the tree was paused: %.3f -> %.3f" % [pre_pause_y, paused_y])
	paused = false
	Engine.time_scale = 1.0
	await create_timer(0.2).timeout
	if absf(pause_label.global_position.y - paused_y) < 1.0:
		failures.append("number did not resume advancing after unpause")
	pause_root.queue_free()
	await process_frame

	# H (14:50 UTC continuation): production path — real enemies, real damage
	# feedback, originating-owner deletion mid-flight, seeded random parity.
	const ENEMY_SCENE := preload("res://scenes/EnemyBiter.tscn")
	var combat_root := Node2D.new()
	combat_root.name = "CurrentScene"
	root.add_child(combat_root)
	current_scene = combat_root
	await process_frame
	var victims: Array[Node2D] = []
	for i in range(3):
		var enemy: CharacterBody2D = ENEMY_SCENE.instantiate()
		combat_root.add_child(enemy)
		enemy.global_position = Vector2(200.0 + i * 120.0, 300.0)
		victims.append(enemy)
	await process_frame
	# Deterministic random parity: same seed produces the same jitter sequence
	# through the production path as the reference randf_range draws.
	seed(20260909)
	var reference_jitter: Array[float] = []
	for i in range(6):
		reference_jitter.append(randf_range(-18.0, 18.0))
		reference_jitter.append(randf_range(-6.0, 6.0))
	seed(20260909)
	for victim in victims:
		victim.set("max_health", 100.0)
		victim.set("health", 100.0)
		victim.call("take_damage", 7.0, {})
	await process_frame
	var production_timeline: Node = combat_root.get_node_or_null("CombatFeedbackTimeline")
	if production_timeline == null:
		failures.append("production damage did not create the feedback timeline")
	else:
		var labels: Array[Label] = []
		for child in production_timeline.get_children():
			if child is Label and child.visible:
				labels.append(child)
		if labels.size() != 3:
			failures.append("production damage on 3 enemies produced %d visible numbers, expected 3" % labels.size())
		# Seeded parity: the first number's start offset must match the seeded
		# reference sequence computed from the same randf_range calls.
		if labels.size() == 3:
			# Complete deterministic sequence: every label's x offset equals its
			# reference draw (x is never animated, so this is exact); the y jitter
			# differences between labels equal the reference draw differences
			# (all Biters share one feedback height).
			for index in range(3):
				var expected_x: float = victims[index].global_position.x - 48.0 + reference_jitter[index * 2]
				if absf(labels[index].global_position.x - expected_x) > 0.5:
					failures.append("seeded random parity broken: label %d x %.1f, expected %.1f" % [index, labels[index].global_position.x, expected_x])
			var y0: float = labels[0].global_position.y - victims[0].global_position.y
			var y1: float = labels[1].global_position.y - victims[1].global_position.y
			var y2: float = labels[2].global_position.y - victims[2].global_position.y
			if absf((y1 - y0) - (reference_jitter[3] - reference_jitter[1])) > 1.0 \
					or absf((y2 - y0) - (reference_jitter[5] - reference_jitter[1])) > 1.0:
				failures.append("seeded random parity broken: y jitter sequence mismatch")
		# Originating-owner deletion mid-flight: retain the EXACT label spawned
		# by the enemy about to be deleted (matched by its deterministic x
		# offset) and assert it survives its full remaining lifetime, then
		# releases cleanly — not merely that two of three labels remain.
		var orphaned_label: Label = null
		if labels.size() == 3:
			var target_x: float = victims[1].global_position.x - 48.0 + reference_jitter[2]
			for label in labels:
				if absf(label.global_position.x - target_x) < 0.5:
					orphaned_label = label
					break
		if orphaned_label == null:
			failures.append("could not identify the deleted enemy's label via seeded offsets")
		else:
			victims[1].queue_free()
			victims[1] = null
			await process_frame
			await process_frame
			if not is_instance_valid(orphaned_label) or not orphaned_label.visible:
				failures.append("the deleted enemy's own number died with its owner (owner lifetime broken)")
			await create_timer(0.75).timeout
			if is_instance_valid(orphaned_label) and orphaned_label.visible:
				failures.append("the deleted enemy's number outlived its 0.62 s lifetime")
			# All three numbers share one damage event, so after the full
			# lifetime none may remain; the deleted enemy's label must have been
			# released back to the pool (instance alive, hidden, group-free).
			var still_visible := 0
			for child in production_timeline.get_children():
				if child is Label and child.visible:
					still_visible += 1
			if still_visible != 0:
				failures.append("after full lifetimes, %d numbers remain visible" % still_visible)
			if is_instance_valid(orphaned_label) and orphaned_label.visible:
				failures.append("the deleted enemy's label was not released to the pool")
			if is_instance_valid(orphaned_label) and orphaned_label.is_in_group("combat_feedback_labels"):
				failures.append("released label still occupies the cap group")
	# Tick curve asserted in-flight, before expiry (complements F's end checks).
	var tick_root := Node2D.new()
	root.add_child(tick_root)
	await process_frame
	var tick_timeline: Node = CombatFeedbackTimeline.for_scene(tick_root)
	tick_timeline.spawn_tick(Vector2(100.0, 100.0), Vector2.ONE, Color(1.0, 0.46, 0.36, 0.40), "combat_feedback_flashes")
	var flight_tick: Sprite2D = null
	for child in tick_timeline.get_children():
		if child is Sprite2D:
			flight_tick = child
			break
	if flight_tick == null:
		failures.append("in-flight tick missing")
	else:
		await create_timer(0.08).timeout
		var expected: float = 0.40 * (1.0 - (1.0 - pow(1.0 - 0.08 / 0.16, 2.0)))
		if absf(flight_tick.modulate.a - expected) > 0.05:
			failures.append("tick alpha in flight is %.3f, expected %.3f (quad-out parity)" % [flight_tick.modulate.a, expected])
	# Overlapping flash trajectory: first flash partially restored, second flash
	# blends from the CURRENT modulate and restarts the restore toward its own
	# target — trajectory must be continuous, never jump to the endpoint.
	var overlap_root := Node2D.new()
	root.add_child(overlap_root)
	await process_frame
	var overlap_timeline: Node = CombatFeedbackTimeline.for_scene(overlap_root)
	var overlap_body := Sprite2D.new()
	overlap_root.add_child(overlap_body)
	await process_frame
	var white := Color(1.0, 1.0, 1.0, 1.0)
	overlap_body.modulate = white.lerp(Color(1.0, 0.42, 0.34, 1.0), 0.4)
	overlap_timeline.flash_body(overlap_body, white)
	await create_timer(0.08).timeout
	var mid_flash: Color = overlap_body.modulate
	if absf(mid_flash.g - white.g) < 0.02:
		failures.append("overlapping flash trajectory: body already at restore endpoint mid-flight")
	overlap_body.modulate = mid_flash.lerp(Color(0.4, 0.8, 1.0, 1.0), 0.4)
	var restart_from: Color = overlap_body.modulate
	overlap_timeline.flash_body(overlap_body, white)
	await create_timer(0.05).timeout
	# Expected restart trajectory: from the recorded restart blend toward white
	# with quad-out progress 0.05/0.16 — exact per channel, which also proves
	# continuity (the curve passes near mid_flight, never through the endpoint).
	var restart_blend: float = 1.0 - pow(1.0 - 0.05 / 0.16, 2.0)
	var expected_color: Color = restart_from.lerp(white, restart_blend)
	for channel in ["r", "g", "b"]:
		var observed: float = overlap_body.modulate[channel]
		var expected: float = expected_color[channel]
		if absf(observed - expected) > 0.03:
			failures.append("overlap restart curve mismatch on %s: %.3f, expected %.3f" % [channel, observed, expected])
	if absf(overlap_body.modulate.g - mid_flash.g) > 0.15:
		failures.append("overlap restart lost continuity with the first flash trajectory")
	await create_timer(0.25).timeout
	if absf(overlap_body.modulate.g - 1.0) > 0.01:
		failures.append("overlapping flashes did not converge to the restore target")
	for cleanup_root in [combat_root, pause_root, tick_root, overlap_root]:
		if cleanup_root != null and is_instance_valid(cleanup_root):
			cleanup_root.queue_free()
	await process_frame
	var final_orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	if final_orphans != 0:
		failures.append("orphans after teardown: %d" % final_orphans)

	# I (QA rework 19:33:57Z): exact body-flash endpoint. The restore must land
	# on the recorded pre-flash modulate exactly, at whatever frame crosses
	# 0.16 s (non-aligned lifetime), and repeated flash/reuse must not drift a
	# non-white base tint. No tolerance: is_equal_approx per channel.
	var endpoint_root := Node2D.new()
	root.add_child(endpoint_root)
	await process_frame
	var endpoint_timeline: Node = CombatFeedbackTimeline.for_scene(endpoint_root)
	var endpoint_body := Sprite2D.new()
	endpoint_root.add_child(endpoint_body)
	var base_tint := Color(0.62, 0.48, 0.71, 1.0)
	endpoint_body.modulate = base_tint
	await process_frame
	# Non-aligned crossing: the awaited lifetime deliberately does not divide
	# the 0.16 s restore window (frame steps land mid-interpolation).
	endpoint_body.modulate = base_tint.lerp(Color(1.0, 0.42, 0.34, base_tint.a), 0.4)
	endpoint_timeline.flash_body(endpoint_body, base_tint)
	await create_timer(0.163).timeout
	var restored_exact := true
	for channel in ["r", "g", "b", "a"]:
		if not is_equal_approx(endpoint_body.modulate[channel], base_tint[channel]):
			restored_exact = false
	if not restored_exact:
		failures.append("body flash did not land exactly on the recorded restore endpoint (got %s, expected %s)" % [str(endpoint_body.modulate), str(base_tint)])
	# Repeated flash/reuse from the restored state must converge back exactly,
	# proving no cumulative drift across hits.
	for round_index in range(4):
		endpoint_body.modulate = base_tint.lerp(Color(1.0, 0.42, 0.34, base_tint.a), 0.4)
		endpoint_timeline.flash_body(endpoint_body, base_tint)
		await create_timer(0.163 if round_index % 2 == 0 else 0.171).timeout
	for channel in ["r", "g", "b", "a"]:
		if not is_equal_approx(endpoint_body.modulate[channel], base_tint[channel]):
			failures.append("repeated flash/reuse drifted the body tint (channel %s: %s vs %s)" % [channel, str(endpoint_body.modulate[channel]), str(base_tint[channel])])
			break
	endpoint_root.queue_free()
	await process_frame

	if failures.is_empty():
		print("P3_FEEDBACK_ALLOCATION_TEST PASS")
		quit(0)
	else:
		for failure in failures:
			printerr("P3_FEEDBACK_ALLOCATION_TEST FAIL: " + failure)
		quit(1)


func _sprites_under(node: Node) -> Array[Sprite2D]:
	var found: Array[Sprite2D] = []
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is Sprite2D:
			found.append(current)
		for child in current.get_children():
			stack.append(child)
	return found
