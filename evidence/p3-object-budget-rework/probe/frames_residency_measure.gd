extends SceneTree

# FAN-3934 read-only diagnostic (round-5 correction): dynamic post-release
# ownership measurement of full-frame SpriteFrames, replacing round-4's static
# resource-entry census. Measures:
#   A. objects retained after FullFrameAnimationRegistry static initialization
#      (shard validation loads every actor's frames via ResourceLoader.load);
#   B. per-kind marginal cost AFTER the registry is already initialized
#      (i.e. what composition can still add during a run);
#   C. whether frames resources remain cached after all references are dropped.

const RegistryScript := preload("res://scripts/full_frame_animation_registry.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var result := {}
	await process_frame
	var base: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var table: Dictionary = RegistryScript.FULL_FRAME_SPRITEFRAMES
	await process_frame
	var after_init: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	result["registry_init"] = {
		"base_objects": base,
		"after_init_objects": after_init,
		"retained": after_init - base,
		"enemy_kinds_registered": (table.get("enemy", {}) as Dictionary).size(),
		"kinds_cached_after_init": _cached_kind_count(),
	}

	# B: per-kind marginal cost with the registry warm — the composition lever.
	var per_kind := {}
	var frames_by_kind := {}
	for kind in (table.get("enemy", {}) as Dictionary).keys():
		var entry: Dictionary = (table.get("enemy", {}) as Dictionary)[kind]
		var frames_path := str(entry.get("frames", ""))
		if frames_path == "" or ResourceLoader.has_cached(frames_path):
			continue
		var before: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
		var frames: SpriteFrames = load(frames_path)
		await process_frame
		var after: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
		per_kind[str(kind)] = after - before
		frames_by_kind[str(kind)] = frames
	await process_frame
	result["per_kind_marginal_after_registry"] = per_kind

	# C: post-release ownership — drop every reference we hold and free the
	# temporary holder; cached resources owned by ResourceCache remain resident.
	frames_by_kind.clear()
	var holder := Node2D.new()
	root.add_child(holder)
	var consumer := AnimatedSprite2D.new()
	holder.add_child(consumer)
	consumer.sprite_frames = load("res://assets/sprites/enemies/full_frame/small_biter_spriteframes.tres")
	await process_frame
	var held: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	consumer.sprite_frames = null
	holder.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.3).timeout
	var released: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	result["post_release"] = {
		"while_consumer_holds": held,
		"after_all_references_dropped": released,
		"small_biter_still_cached": ResourceLoader.has_cached("res://assets/sprites/enemies/full_frame/small_biter_spriteframes.tres"),
	}

	DirAccess.make_dir_recursive_absolute("res://evidence/p3-object-budget-rework/round5")
	var f := FileAccess.open("res://evidence/p3-object-budget-rework/round5/frames_residency.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(result, "  ") + "\n")
	f.close()
	print("FAN3934_FRAMES_RESIDENCY " + JSON.stringify(result))
	quit(0)

func _cached_kind_count() -> int:
	var count := 0
	for kind in ["ash_marksman", "bone_caller", "bone_shaman", "rift_cutter", "rift_shieldbearer", "small_biter", "spark_runner", "stone_bruiser", "venom_spitter", "void_mage", "winged_spark"]:
		if ResourceLoader.has_cached("res://assets/sprites/enemies/full_frame/%s_spriteframes.tres" % kind):
			count += 1
	return count
