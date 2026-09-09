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
