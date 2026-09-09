extends SceneTree

# FAN-3934 read-only diagnostic (corrected per PM review 2026-09-09T06:22:25Z):
# script-release semantics and cold-activation timing. The earlier version
# sampled post-drop counts before clearing the reference; this version samples
# strictly AFTER the reference is dropped and the engine has idled, and every
# raw number is written to the evidence directory.

const RegistryScript := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const ProgressionData := preload("res://scripts/progression_data.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var result := {}
	var objects := func() -> int:
		return int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var settle := func() -> void:
		await process_frame
		await process_frame
		await create_timer(0.5).timeout

	await settle.call()
	var base := objects.call()

	# A: plain load() on a fresh script — residency while held and after drop.
	var plain_path := "res://scripts/ultimates/classes/ranger/bow.gd"
	var plain = load(plain_path)
	await settle.call()
	var plain_held := objects.call()
	plain = null
	await settle.call()
	var plain_dropped := objects.call()
	result["plain_load"] = {
		"path": plain_path,
		"delta_while_held": plain_held - base,
		"delta_after_ref_drop": plain_dropped - base,
		"cached_after_ref_drop": ResourceLoader.has_cached(plain_path),
	}

	# B: CACHE_MODE_IGNORE on a different fresh script.
	var ignore_path := "res://scripts/ultimates/classes/priest/staff.gd"
	var ignored = ResourceLoader.load(ignore_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	await settle.call()
	var ignore_held := objects.call()
	ignored = null
	await settle.call()
	var ignore_dropped := objects.call()
	result["ignore_load"] = {
		"path": ignore_path,
		"delta_while_held": ignore_held - base,
		"delta_after_ref_drop": ignore_dropped - base,
		"cached_while_held": ResourceLoader.has_cached(ignore_path),
		"cached_after_ref_drop": ResourceLoader.has_cached(ignore_path),
	}

	# C: cold-activation admission cost through the lazy runtime registry
	# (the controller's pre-charge resolution point).
	var registry = RegistryScript.new(ProgressionData.WEAPONS_BY_CLASS)
	var before_admission := objects.call()
	var t0 := Time.get_ticks_usec()
	var axe = registry.executor_for("berserk", "axe")
	var cold_us := Time.get_ticks_usec() - t0
	await settle.call()
	var after_admission := objects.call()
	var t1 := Time.get_ticks_usec()
	var axe_again = registry.executor_for("berserk", "axe")
	var warm_us := Time.get_ticks_usec() - t1
	result["cold_activation"] = {
		"admitted": axe is GDScript,
		"same_instance_on_repeat": axe_again == axe,
		"cold_admission_us": cold_us,
		"warm_admission_us": warm_us,
		"retained_delta": after_admission - before_admission,
	}

	DirAccess.make_dir_recursive_absolute("res://evidence/p3-object-budget-rework/round3")
	var f := FileAccess.open("res://evidence/p3-object-budget-rework/round3/script_cache_and_cold_activation.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(result, "  ") + "\n")
	f.close()
	print("FAN3934_CACHE_RESULT " + JSON.stringify(result))
	quit(0)
