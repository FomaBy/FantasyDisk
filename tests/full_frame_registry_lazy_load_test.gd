extends SceneTree

# FAN-3973 (0.3.1 release blocker, FAN-3964 QA FAILED): registry
# initialization used to run `ResourceLoader.load(frames) is SpriteFrames` for
# every actor shard, pulling all 41 full-frame packs (9,089 textures) through
# the loader before the main menu's first frame. This suite pins the fix:
#
# 1. Building FULL_FRAME_SPRITEFRAMES leaves every registered frames resource
#    OUT of the resource cache (no eager load), while the catalog is still
#    fully populated.
# 2. The cheap registry-time type check accepts only extensions a
#    SpriteFrames-capable loader serves (`.tres`/`.res`) and rejects script,
#    texture and scene paths.
# 3. The strict SpriteFrames check now runs at first use: a `.tres` that
#    exists but is not SpriteFrames yields null (static fallback), warns once
#    and is remembered, so the pack is never re-loaded on later spawns.
# 4. First use through the public facade loads the real pack and, from then
#    on, the pack is cached.
# 5. The bounded background prefetch: queuing is idempotent, at most
#    MAX_PREFETCH_IN_FLIGHT threaded requests run at once, completed packs
#    become resident and are what first use returns, and release drops them.
#
# Запуск: Godot --headless --path . --script res://tests/full_frame_registry_lazy_load_test.gd

const FullFrameAnimationRegistry := preload("res://scripts/full_frame_animation_registry.gd")

const WRONG_TYPE_TRES_PATH := "user://fan3973_wrong_type_frames.tres"
const FIRST_USE_KIND := "enemy"
const FIRST_USE_ID := "small_biter"
const MAX_PREFETCH_FRAMES := 3000

var _errors: Array = []


func _initialize() -> void:
	_test_registry_init_loads_nothing()
	_test_cheap_extension_check()
	_test_wrong_type_rejected_at_first_use()
	_test_first_use_loads_and_caches()
	await _test_bounded_prefetch()
	_cleanup()
	if not _errors.is_empty():
		for error in _errors:
			push_error("Full-frame registry lazy load: %s" % error)
		push_error("Full-frame registry lazy load test: %d ошибок." % _errors.size())
		quit(1)
		return
	print("Full-frame registry lazy load test passed (no eager load at registry init, cheap extension check, strict type check at first use, bounded prefetch).")
	quit(0)


func _fail(message: String) -> void:
	_errors.append(message)


func _catalog_frames_paths() -> Array:
	var paths: Array = []
	var table: Dictionary = FullFrameAnimationRegistry.FULL_FRAME_SPRITEFRAMES
	for entity_kind in table.keys():
		var kind_table: Dictionary = table[entity_kind]
		for entity_id in kind_table.keys():
			paths.append(str((kind_table[entity_id] as Dictionary).get("frames", "")))
	return paths


func _test_registry_init_loads_nothing() -> void:
	# This process preloads only the registry script; nothing else references a
	# full-frame pack, so any cached pack here was loaded by registry init.
	var paths := _catalog_frames_paths()
	if paths.size() < 20:
		_fail("catalog suspiciously small (%d entries) — the no-eager-load check would pass vacuously." % paths.size())
	var eagerly_loaded: Array = []
	for frames_path in paths:
		if frames_path == "":
			_fail("a registered entry has an empty 'frames' path.")
			continue
		if not ResourceLoader.exists(frames_path):
			_fail("%s: registered but nonexistent — registry-time existence check regressed." % frames_path)
		if ResourceLoader.has_cached(frames_path):
			eagerly_loaded.append(frames_path)
	if not eagerly_loaded.is_empty():
		_fail("registry init loaded %d full-frame pack(s) eagerly (first: %s) — that is the FAN-3964 cold-start regression." % [eagerly_loaded.size(), eagerly_loaded[0]])


func _test_cheap_extension_check() -> void:
	for accepted in ["res://assets/sprites/allies/ally_druid_ghost_stag_spriteframes.tres", "res://anything/pack.res", "res://anything/PACK.TRES"]:
		if not FullFrameAnimationRegistry._has_frames_resource_extension(accepted):
			_fail("%s: a SpriteFrames-capable extension must pass the cheap registry-time check." % accepted)
	for rejected in ["res://scripts/full_frame_animation_registry.gd", "res://assets/sprites/elites/iron_bastion.png", "res://scenes/Main.tscn", "res://no_extension", ""]:
		if FullFrameAnimationRegistry._has_frames_resource_extension(rejected):
			_fail("'%s': a non-SpriteFrames extension must fail the cheap registry-time check." % rejected)
	# The real shard path: an existing script resource is rejected before
	# admission (same warning as FAN-3680), without loading anything.
	var entry: Dictionary = FullFrameAnimationRegistry._entry_from_document({
		"frames": "res://scripts/full_frame_animation_registry.gd",
		"scale": {"x": 0.5, "y": 0.5},
		"position": {"x": 0.0, "y": 0.0},
		"source_faces_left": true,
	}, "testkind/wrong_type_script.json")
	if not entry.is_empty():
		_fail("a shard whose 'frames' is a .gd script must still be excluded at registry time.")


func _test_wrong_type_rejected_at_first_use() -> void:
	var wrong_type := Theme.new()
	var save_error := ResourceSaver.save(wrong_type, WRONG_TYPE_TRES_PATH)
	if save_error != OK:
		_fail("fixture setup: could not save a non-SpriteFrames .tres (error %d)." % save_error)
		return
	if not ResourceLoader.exists(WRONG_TYPE_TRES_PATH):
		_fail("fixture setup: %s does not exist after save." % WRONG_TYPE_TRES_PATH)
		return
	# Registry-time: a `.tres` cannot be told apart without loading, so the
	# cheap check admits it — the strict check is owed at first use.
	if not FullFrameAnimationRegistry._has_frames_resource_extension(WRONG_TYPE_TRES_PATH):
		_fail("a .tres path must pass the cheap extension check (strict type check belongs to first use).")
	var frames := FullFrameAnimationRegistry._frames_for_path(WRONG_TYPE_TRES_PATH, "testkind/wrong_type_tres")
	if frames != null:
		_fail("a .tres that is not SpriteFrames must yield null at first use (static fallback).")
	if not FullFrameAnimationRegistry._rejected_frames_paths.has(WRONG_TYPE_TRES_PATH):
		_fail("a wrong-type pack must be remembered as rejected so it is not re-loaded on every spawn.")
	if FullFrameAnimationRegistry._frames_for_path(WRONG_TYPE_TRES_PATH, "testkind/wrong_type_tres") != null:
		_fail("a remembered wrong-type pack must keep yielding null.")
	# A remembered rejection also blocks the prefetch path.
	FullFrameAnimationRegistry._prefetch_queue.append(WRONG_TYPE_TRES_PATH)
	FullFrameAnimationRegistry.advance_prefetch()
	if FullFrameAnimationRegistry._prefetch_in_flight.has(WRONG_TYPE_TRES_PATH) or FullFrameAnimationRegistry._prefetched_frames.has(WRONG_TYPE_TRES_PATH):
		_fail("a remembered wrong-type pack must never be prefetched.")


func _test_first_use_loads_and_caches() -> void:
	var config := FullFrameAnimationRegistry.registry_config(FIRST_USE_KIND, FIRST_USE_ID)
	var frames_path := str(config.get("frames", ""))
	if frames_path == "":
		_fail("%s/%s must be registered for the first-use check." % [FIRST_USE_KIND, FIRST_USE_ID])
		return
	if ResourceLoader.has_cached(frames_path):
		_fail("%s must not be cached before its first use." % frames_path)
	var frames := FullFrameAnimationRegistry.sprite_frames_for(FIRST_USE_KIND, FIRST_USE_ID)
	if frames == null or frames.get_animation_names().is_empty():
		_fail("%s/%s: first use must load a SpriteFrames with animations." % [FIRST_USE_KIND, FIRST_USE_ID])
		return
	if not ResourceLoader.has_cached(frames_path):
		_fail("%s must be cached after first use." % frames_path)
	# The safe-fallback contract for an unregistered actor is untouched.
	if FullFrameAnimationRegistry.sprite_frames_for(FIRST_USE_KIND, "fan3973_definitely_unregistered") != null:
		_fail("an unregistered actor must still resolve to null.")


func _test_bounded_prefetch() -> void:
	if FullFrameAnimationRegistry.queue_prefetch("enemy", "fan3973_definitely_unregistered"):
		_fail("queuing an unregistered actor must be a no-op.")
	if FullFrameAnimationRegistry.queue_prefetch("boss", "fan3973_definitely_unregistered"):
		_fail("queuing an unregistered boss must be a no-op.")
	var queued := FullFrameAnimationRegistry.queue_prefetch_kind("boss")
	var boss_count: int = (FullFrameAnimationRegistry.FULL_FRAME_SPRITEFRAMES.get("boss", {}) as Dictionary).size()
	if queued != boss_count or queued < 2:
		_fail("queue_prefetch_kind('boss') queued %d packs, expected all %d registered bosses." % [queued, boss_count])
	if FullFrameAnimationRegistry.queue_prefetch_kind("boss") != 0:
		_fail("re-queuing an already queued kind must queue nothing.")
	# A scene root property resolves to the same registered actor.
	var elite_scene := load("res://scenes/EliteArmored.tscn") as PackedScene
	if not FullFrameAnimationRegistry.queue_prefetch_for_scene("elite", elite_scene, "elite_behavior"):
		_fail("queue_prefetch_for_scene must queue the elite declared by EliteArmored.tscn's elite_behavior.")
	if FullFrameAnimationRegistry.queue_prefetch("elite", "iron_bastion"):
		_fail("the scene-declared elite (iron_bastion) must already be queued.")
	if FullFrameAnimationRegistry.queue_prefetch_for_scene("elite", null, "elite_behavior"):
		_fail("queue_prefetch_for_scene(null) must be a no-op.")
	var expected_total := queued + 1

	var remaining := FullFrameAnimationRegistry.advance_prefetch()
	if FullFrameAnimationRegistry._prefetch_in_flight.size() > FullFrameAnimationRegistry.MAX_PREFETCH_IN_FLIGHT:
		_fail("more than MAX_PREFETCH_IN_FLIGHT (%d) threaded requests in flight after one tick." % FullFrameAnimationRegistry.MAX_PREFETCH_IN_FLIGHT)
	if remaining != expected_total:
		_fail("advance_prefetch reported %d remaining after the first tick, expected %d." % [remaining, expected_total])
	var frames_waited := 0
	while remaining > 0 and frames_waited < MAX_PREFETCH_FRAMES:
		await process_frame
		frames_waited += 1
		remaining = FullFrameAnimationRegistry._prefetch_queue.size() + FullFrameAnimationRegistry._prefetch_in_flight.size()
		if FullFrameAnimationRegistry._prefetch_in_flight.size() > FullFrameAnimationRegistry.MAX_PREFETCH_IN_FLIGHT:
			_fail("prefetch exceeded MAX_PREFETCH_IN_FLIGHT while draining.")
			break
	if remaining > 0:
		_fail("prefetch did not finish within %d frames (%d still pending)." % [MAX_PREFETCH_FRAMES, remaining])
		return
	if FullFrameAnimationRegistry.prefetched_frames_count() != expected_total:
		_fail("expected %d resident packs after the prefetch, found %d." % [expected_total, FullFrameAnimationRegistry.prefetched_frames_count()])
	if FullFrameAnimationRegistry._prefetch_tick_connected:
		_fail("the process_frame tick must disconnect once the prefetch is idle.")
	var boss_ids := (FullFrameAnimationRegistry.FULL_FRAME_SPRITEFRAMES.get("boss", {}) as Dictionary).keys()
	for boss_id in boss_ids:
		var frames_path := str(FullFrameAnimationRegistry.registry_config("boss", str(boss_id)).get("frames", ""))
		var resident: SpriteFrames = FullFrameAnimationRegistry._prefetched_frames.get(frames_path)
		var served := FullFrameAnimationRegistry.sprite_frames_for("boss", str(boss_id))
		if resident == null or served != resident:
			_fail("boss/%s: first use must return the prefetched pack, not load a second copy." % boss_id)
	FullFrameAnimationRegistry.release_prefetched()
	if FullFrameAnimationRegistry.prefetched_frames_count() != 0 or not FullFrameAnimationRegistry._prefetch_queue.is_empty():
		_fail("release_prefetched must drop every resident pack and clear the queue.")
	# Queuing again after release goes through the loader again (not a no-op),
	# and releasing while that request is still in flight collects it
	# synchronously: nothing may stay pending in the threaded loader (a load
	# still running at engine shutdown is reported as a failed resource load —
	# the FAN-3973 route-map suites quit within a frame of showing the map).
	if not FullFrameAnimationRegistry.queue_prefetch("boss", str(boss_ids[0])):
		_fail("a released pack must be queueable again.")
	FullFrameAnimationRegistry.advance_prefetch()
	if FullFrameAnimationRegistry._prefetch_in_flight.size() != 1:
		_fail("expected exactly one request in flight before the release-while-loading check.")
	FullFrameAnimationRegistry.release_prefetched()
	if not FullFrameAnimationRegistry._prefetch_in_flight.is_empty() or FullFrameAnimationRegistry.prefetched_frames_count() != 0:
		_fail("release_prefetched must collect an in-flight request synchronously and keep nothing resident.")
	if FullFrameAnimationRegistry._prefetch_tick_connected:
		_fail("release_prefetched must disconnect the process_frame tick.")


func _cleanup() -> void:
	var absolute := ProjectSettings.globalize_path(WRONG_TYPE_TRES_PATH)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)
