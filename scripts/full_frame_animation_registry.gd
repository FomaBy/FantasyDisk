extends RefCounted
class_name FullFrameAnimationRegistry

# Back-end runtime registry for optional full-frame SpriteFrames.
# Gameplay remains source of truth: this helper only chooses/plays visual states
# when Animator/Design assets exist, and returns false/null for safe fallback.

const DEFAULT_ANIMATED_BODY_NAME := "FullFrameBody"
const DEFAULT_STATIC_BODY_NAME := "Body"

# FAN-2519: 8-направленный рантайм-контракт не-игровых акторов (monsters,
# elites, bosses, summons). Именование направлений совпадает с игроком
# (player.gd DIRECTIONAL_ANIMATION_SUFFIXES): октанты по часовой стрелке от
# востока, строки именуются `<state>_<suffix>`. Пак декларирует контракт ключом
# конфигурации `explicit_eight_directions: true`; такой актор никогда не
# зеркалится (flip_h запрещён) и деградирует только в безнаправленную строку
# того же пула состояний с явным флагом `directional_fallback_used`.
const DIRECTION_SUFFIXES := ["east", "south_east", "south", "south_west", "west", "north_west", "north", "north_east"]
const DEFAULT_FACING_DIRECTION := Vector2.LEFT
const DIRECTION_SNAP_EPSILON := 0.001

# FAN-3638: per-actor configs live in data/animation/<kind>/<actor_id>.json so
# parallel actor tasks write disjoint files; this facade scans the catalog once
# at class load and rebuilds the same table the old inline const declared.
# JSON schema per actor: frames (res:// path), scale/position ({"x","y"} numbers),
# source_faces_left (bool), optional explicit_eight_directions /
# explicit_horizontal_directions (bool), optional provenance (free-form history
# note, dropped on load).
#
# FAN-3669 (rework of FAN-3638/FAN-3660, QA-rejected d3ddb939): a shard that
# fails schema validation — malformed JSON, a missing/invalid required field,
# or a canonical identity (case-insensitive filename stem) already used by
# another shard in the same kind directory — is a fail-closed rejection: the
# actor is EXCLUDED from the table (never admitted half-populated) and the
# reason is logged via push_warning. An excluded actor falls through the
# pre-existing safe-fallback contract (registry_config returns {}, callers
# treat that as "no full-frame visual") exactly like an unregistered actor —
# it never surfaces as a partially-valid entry.
const DATA_ROOT := "res://data/animation"
const ENTITY_KINDS := ["ally", "enemy", "elite", "boss", "hero"]
const REQUIRED_NUMERIC_VECTOR_FIELDS := ["x", "y"]

# FAN-3973 (0.3.1 release blocker, FAN-3964 QA): registry initialization runs
# at class load, which `enemy.gd` preloads from the main scene — i.e. before
# the main menu's first frame. It must therefore never load a frames resource:
# the FAN-3680 `ResourceLoader.load(frames_path) is SpriteFrames` type probe
# pulled every full-frame pack (41 SpriteFrames, 9,089 textures, ~8.5 GiB of
# lossless 512x512 frames) through the loader just to discard it, and cold
# start on the Windows reference host went from 5 s to 17 s. The cheap check
# keeps the fail-closed contract at registry time: the path must exist and
# carry an extension a SpriteFrames-capable loader serves (`.tres`/`.res`), so
# a `.gd`/`.png`/`.tscn` path is still excluded here with the same warning.
# Whether a `.tres`/`.res` really contains SpriteFrames cannot be known
# without loading it, so that strict check moved to first use
# (`_frames_for_path`): still fail-closed to the static body, remembered per
# path so a wrong-type pack is not re-loaded on every spawn, and the whole
# catalog is type-checked by `tests/full_frame_registry_integrity_test.gd`.
const FRAMES_RESOURCE_TYPE := "SpriteFrames"

static var FULL_FRAME_SPRITEFRAMES: Dictionary = _load_registry()

# First-use loader state (see `_frames_for_path`). Paths rejected at first use
# because the resource is not SpriteFrames; the actor keeps its static body.
static var _rejected_frames_paths: Dictionary = {}


static func _load_registry() -> Dictionary:
	var registry := {}
	for kind in ENTITY_KINDS:
		registry[kind] = _load_kind(str(kind))
	return registry


static func _load_kind(entity_kind: String, data_root := DATA_ROOT) -> Dictionary:
	var directory_path := "%s/%s" % [data_root, entity_kind]
	if DirAccess.open(directory_path) == null:
		return {}
	var file_names := DirAccess.get_files_at(directory_path)
	file_names.sort()
	return _load_shards(entity_kind, directory_path, file_names)


# Split out from _load_kind so tests can drive the validation/dedup logic with
# an explicit file-name list — a real duplicate-identity fixture (two files
# whose names differ only by case) cannot exist on a case-preserving but
# case-INsensitive filesystem such as default macOS/APFS, which silently
# collapses both writes into one file. `document_reader`, when given, is
# called with a file name and must return the same shape JSON.parse_string
# would (a Dictionary, or a non-Dictionary for "malformed"); it lets tests
# supply genuinely distinct content per case-variant name regardless of the
# host filesystem's case sensitivity. Production callers (_load_kind) never
# pass it, so on-disk behavior is unchanged.
static func _load_shards(entity_kind: String, directory_path: String, file_names: Array, document_reader := Callable()) -> Dictionary:
	var table := {}
	var seen_canonical_ids := {}
	for file_name_variant in file_names:
		var file_name := str(file_name_variant)
		if not file_name.ends_with(".json"):
			continue
		var actor_id := file_name.trim_suffix(".json")
		var where := "%s/%s" % [entity_kind, file_name]
		var canonical_id := actor_id.to_lower()
		if seen_canonical_ids.has(canonical_id):
			var prior_where: String = seen_canonical_ids[canonical_id]
			push_warning("full_frame_animation_registry: duplicate actor identity '%s' — %s conflicts with already-loaded %s; both excluded (safe fallback)." % [canonical_id, where, prior_where])
			for prior_actor_id in table.keys():
				if str(prior_actor_id).to_lower() == canonical_id:
					table.erase(prior_actor_id)
					break
			continue
		# Registered before validation (not after) so an invalid shard that loses
		# its own entry to schema rejection still claims the canonical identity —
		# otherwise a later, valid duplicate of the same identity would see no
		# prior claim and be silently admitted, defeating the dedup check whenever
		# the invalid shard happened to sort first.
		seen_canonical_ids[canonical_id] = where
		var parsed = document_reader.call(file_name) if document_reader.is_valid() else JSON.parse_string(
			FileAccess.get_file_as_string("%s/%s" % [directory_path, file_name])
		)
		if not parsed is Dictionary:
			push_warning("full_frame_animation_registry: malformed JSON in %s — actor excluded (safe fallback)." % where)
			continue
		var entry := _entry_from_document(parsed as Dictionary, where)
		if entry.is_empty():
			continue
		table[actor_id] = entry
	return table


# Returns {} when the document fails schema validation — callers must treat an
# empty result as "reject this shard", never as "admit it with empty/default
# values" (that was the FAN-3660 QA-rejected bug: _entry_from_document({})
# silently produced a usable-looking entry).
static func _entry_from_document(document: Dictionary, where: String) -> Dictionary:
	var frames_path = document.get("frames")
	if not (frames_path is String) or (frames_path as String).is_empty() or not (frames_path as String).begins_with("res://"):
		push_warning("full_frame_animation_registry: %s has a missing/invalid 'frames' path — actor excluded (safe fallback)." % where)
		return {}
	if not ResourceLoader.exists(frames_path):
		push_warning("full_frame_animation_registry: %s references a nonexistent 'frames' resource — actor excluded (safe fallback)." % where)
		return {}
	if not _has_frames_resource_extension(frames_path):
		push_warning("full_frame_animation_registry: %s references a 'frames' resource that is not SpriteFrames — actor excluded (safe fallback)." % where)
		return {}
	var scale: Variant = _vector2_from_document(document.get("scale"), where, "scale")
	var position: Variant = _vector2_from_document(document.get("position"), where, "position")
	if scale == null or position == null:
		return {}
	if not (document.get("source_faces_left") is bool):
		push_warning("full_frame_animation_registry: %s has a missing/invalid 'source_faces_left' flag — actor excluded (safe fallback)." % where)
		return {}
	for flag in ["explicit_eight_directions", "explicit_horizontal_directions"]:
		if document.has(flag) and not (document.get(flag) is bool):
			push_warning("full_frame_animation_registry: %s has a non-bool '%s' flag — actor excluded (safe fallback)." % [where, flag])
			return {}
	var entry := {
		"frames": frames_path,
		"scale": scale,
		"position": position,
		"source_faces_left": document.get("source_faces_left"),
	}
	for flag in ["explicit_eight_directions", "explicit_horizontal_directions"]:
		if bool(document.get(flag, false)):
			entry[flag] = true
	return entry


# FAN-3973: cheap, deterministic stand-in for the FAN-3680 full-load type
# probe. `ResourceLoader.get_recognized_extensions_for_type` asks the
# registered loaders which extensions can yield a SpriteFrames (text `.tres`,
# binary `.res`) without touching the file; `ResourceLoader.exists(path,
# type_hint)` is not usable here because it answers true for any path that is
# already in the resource cache regardless of type (the registry script
# itself, for example). Exported builds remap `.tres` to a binary `.res`
# behind the same logical path, so the declared extension is what matters.
static func _has_frames_resource_extension(frames_path: String) -> bool:
	var extension := frames_path.get_extension().to_lower()
	if extension == "":
		return false
	for recognized in ResourceLoader.get_recognized_extensions_for_type(FRAMES_RESOURCE_TYPE):
		if str(recognized).to_lower() == extension:
			return true
	return false


# Returns null (not Vector2.ZERO) on an invalid/missing document so callers can
# tell "absent transform" apart from "malformed transform admitted as zero".
static func _vector2_from_document(value, where: String, field_name: String):
	if not (value is Dictionary):
		push_warning("full_frame_animation_registry: %s has a missing/invalid '%s' transform — actor excluded (safe fallback)." % [where, field_name])
		return null
	for axis in REQUIRED_NUMERIC_VECTOR_FIELDS:
		var axis_value = (value as Dictionary).get(axis)
		if not (axis_value is float or axis_value is int):
			push_warning("full_frame_animation_registry: %s has a non-numeric '%s.%s' — actor excluded (safe fallback)." % [where, field_name, axis])
			return null
	return Vector2(float((value as Dictionary).get("x")), float((value as Dictionary).get("y")))


const STATE_ALIASES := {
	"idle": ["idle", "move", "walk"],
	"move": ["move", "walk", "run", "levitate", "idle"],
	"walk": ["walk", "move", "run", "levitate", "idle"],
	"run": ["run", "move", "walk", "levitate", "idle"],
	"attack": ["attack", "attack_primary", "cast", "shoot", "move"],
	"attack_primary": ["attack_primary", "attack", "cast", "shoot", "move"],
	"cast": ["cast", "attack", "attack_primary", "move"],
	"shoot": ["shoot", "attack", "attack_primary", "move"],
	"hit": ["hit", "hurt", "damage", "idle", "move"],
	"death": ["death", "die", "idle", "move"],
}


static func registry_config(entity_kind: String, entity_id: String) -> Dictionary:
	var kind_table: Dictionary = FULL_FRAME_SPRITEFRAMES.get(entity_kind, {})
	return (kind_table.get(entity_id, {}) as Dictionary).duplicate(true)


# FAN-3977: "this actor has a usable pack" without loading it — registered
# (fail-closed registry validation) and not rejected at first use. Callers
# that only need to CHOOSE an identity (enemy.gd picks the mini-elite pack
# over the base elite behavior) must use this instead of `sprite_frames_for`,
# which would load the pack synchronously outside a fight and, inside one,
# would count a combat-guard miss and hand the owner the wrong pack.
static func has_usable_pack(entity_kind: String, entity_id: String) -> bool:
	var frames_path := frames_path_for(entity_kind, entity_id)
	return frames_path != "" and not _rejected_frames_paths.has(frames_path)


static func sprite_frames_for(entity_kind: String, entity_id: String) -> SpriteFrames:
	var config := registry_config(entity_kind, entity_id)
	return _frames_for_path(str(config.get("frames", "")), "%s/%s" % [entity_kind, entity_id])


# FAN-3973: the single place a frames resource is actually loaded. Strict
# SpriteFrames type check lives here (registry init must stay load-free, see
# FRAMES_RESOURCE_TYPE); a resource that is not SpriteFrames is rejected once
# with the registry warning, remembered, and the caller falls back to the
# static body exactly like an unregistered actor.
#
# FAN-3977 (0.3.2 release blocker, FAN-3964 QA): while a fight is active
# (`set_combat_guard`), a pack that is not resident is NEVER loaded on the
# main thread — the Windows review traced every 1-FPS second to exactly such
# a load (a mini-elite, `night_stalker` or boss pack of several hundred
# textures). The miss is counted (`synchronous_combat_load_count`, asserted
# 0 by the residency regression), warned once per path per fight, queued at
# the front of the background prefetch, and the caller falls back to the
# static body; `configure_entity_visual` also registers the owner for a
# deferred swap when the pack lands. Outside a fight (menus, tests, tools)
# the pre-existing synchronous path is unchanged: a pending background
# request is collected from the threaded loader instead of being loaded a
# second time, an unstarted request runs inline.
static func _frames_for_path(frames_path: String, where: String) -> SpriteFrames:
	if frames_path == "" or _rejected_frames_paths.has(frames_path):
		return null
	if _prefetched_frames.has(frames_path):
		return _prefetched_frames[frames_path]
	if not ResourceLoader.exists(frames_path):
		return null
	if _combat_guard_active:
		_synchronous_combat_load_count += 1
		if not _combat_miss_warned_paths.has(frames_path):
			_combat_miss_warned_paths[frames_path] = true
			push_warning("full_frame_animation_registry: %s needed %s during a fight but the pack is not resident — static body until the background load lands (encounter roster miss)." % [where, frames_path])
		_queue_prefetch_path(frames_path, true)
		return null
	var loaded: Resource = null
	if _prefetch_in_flight.has(frames_path):
		_prefetch_in_flight.erase(frames_path)
		loaded = ResourceLoader.load_threaded_get(frames_path)
	if loaded == null:
		loaded = ResourceLoader.load(frames_path)
	if not (loaded is SpriteFrames):
		push_warning("full_frame_animation_registry: %s references a 'frames' resource that is not SpriteFrames — actor excluded (safe fallback)." % where)
		_rejected_frames_paths[frames_path] = true
		return null
	return loaded as SpriteFrames


# FAN-3973/FAN-3977: bounded background prefetch of the full-frame packs a
# fight can use. Callers queue a concrete roster at a natural boundary (the
# route map queues the core roster every regular fight can spawn; combat
# start completes the encounter's roster and waits for it, see
# `ensure_resident`), at most MAX_PREFETCH_IN_FLIGHT threaded requests
# run at once so texture uploads stay spread over frames instead of landing
# in one, completed packs are held by `_prefetched_frames` (the weak
# resource cache would otherwise drop and re-load them between fights),
# `retain_only` lets go of the packs the next encounter cannot spawn and
# `release_prefetched` lets go of everything when the run returns to the
# main menu. A roster entry that is unregistered, already rejected or
# already resident is a no-op. Progress is driven by `advance_prefetch`,
# which hooks the scene tree's `process_frame` only while there is work to
# do. FAN-3977 also shrank every pack ~5x (trim atlases, see
# tools/build_full_frame_trim_atlases.py), so the core roster of a regular
# fight (11 enemies, 10 mini-elites, 10 allies) is ~1 GiB of texture memory
# instead of the 3.1-4.4 GiB the FAN-3964 review measured for 11-14 packs.
const MAX_PREFETCH_IN_FLIGHT := 1

static var _prefetch_queue: Array = []
static var _prefetch_in_flight: Dictionary = {}
static var _prefetched_frames: Dictionary = {}
static var _prefetch_failed_paths: Dictionary = {}
static var _prefetch_tick_connected := false
# FAN-3977: combat guard state (see `_frames_for_path`).
static var _combat_guard_active := false
static var _synchronous_combat_load_count := 0
static var _combat_miss_warned_paths: Dictionary = {}
# frames_path -> Array[WeakRef] of owners waiting for a deferred visual swap.
static var _deferred_owners: Dictionary = {}
# [{"paths": Array[String], "callback": Callable}] waiting for residency.
static var _residency_waiters: Array = []


static func frames_path_for(entity_kind: String, entity_id: String) -> String:
	return str(registry_config(entity_kind, entity_id).get("frames", ""))


static func queue_prefetch(entity_kind: String, entity_id: String) -> bool:
	return _queue_prefetch_path(frames_path_for(entity_kind, entity_id), false)


# Queues a pack by its frames path (the secret boss declares its pack through
# scene metadata, not a registry shard). Same cheap fail-closed checks as a
# registry shard: the path must exist and carry a SpriteFrames extension.
static func queue_prefetch_path(frames_path: String) -> bool:
	if frames_path == "" or not frames_path.begins_with("res://"):
		return false
	if not ResourceLoader.exists(frames_path) or not _has_frames_resource_extension(frames_path):
		return false
	return _queue_prefetch_path(frames_path, false)


static func _queue_prefetch_path(frames_path: String, front: bool) -> bool:
	if frames_path == "" or _rejected_frames_paths.has(frames_path):
		return false
	if _prefetched_frames.has(frames_path) or _prefetch_in_flight.has(frames_path):
		return false
	if _prefetch_queue.has(frames_path):
		if front:
			_prefetch_queue.erase(frames_path)
			_prefetch_queue.push_front(frames_path)
		return false
	_prefetch_failed_paths.erase(frames_path)
	if front:
		_prefetch_queue.push_front(frames_path)
	else:
		_prefetch_queue.append(frames_path)
	_connect_prefetch_tick()
	return true


# Queues the pack of the actor a PackedScene's root declares through a string
# property (`elite_behavior`, `boss_behavior`) without instantiating the scene.
static func queue_prefetch_for_scene(entity_kind: String, scene: PackedScene, id_property: String) -> bool:
	var entity_id := scene_root_string_property(scene, id_property)
	return entity_id != "" and queue_prefetch(entity_kind, entity_id)


static func queue_prefetch_kind(entity_kind: String) -> int:
	var queued := 0
	for entity_id in kind_entity_ids(entity_kind):
		if queue_prefetch(entity_kind, str(entity_id)):
			queued += 1
	return queued


static func kind_entity_ids(entity_kind: String) -> Array:
	var kind_table: Dictionary = FULL_FRAME_SPRITEFRAMES.get(entity_kind, {})
	var entity_ids := kind_table.keys()
	entity_ids.sort()
	return entity_ids


# Reads a string property of a PackedScene's root node from the packed state
# (no instantiation). Returns "" when absent.
static func scene_root_string_property(scene: PackedScene, property_name: String) -> String:
	if scene == null:
		return ""
	var state := scene.get_state()
	for index in range(state.get_node_property_count(0)):
		if str(state.get_node_property_name(0, index)) == property_name:
			return str(state.get_node_property_value(0, index))
	return ""


# Returns the number of packs still queued or in flight; 0 means idle.
static func advance_prefetch() -> int:
	for frames_path in _prefetch_in_flight.keys():
		var status := ResourceLoader.load_threaded_get_status(frames_path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		_prefetch_in_flight.erase(frames_path)
		var loaded: Resource = ResourceLoader.load_threaded_get(frames_path) if status == ResourceLoader.THREAD_LOAD_LOADED else null
		if loaded is SpriteFrames:
			_prefetched_frames[frames_path] = loaded
			_swap_deferred_owners(frames_path)
		elif loaded != null:
			push_warning("full_frame_animation_registry: prefetched %s is not SpriteFrames — actor excluded (safe fallback)." % frames_path)
			_rejected_frames_paths[frames_path] = true
		else:
			_prefetch_failed_paths[frames_path] = true
			push_warning("full_frame_animation_registry: background prefetch of %s failed; the pack loads on first use instead." % frames_path)
	while _prefetch_in_flight.size() < MAX_PREFETCH_IN_FLIGHT and not _prefetch_queue.is_empty():
		var frames_path: String = _prefetch_queue.pop_front()
		if _prefetched_frames.has(frames_path) or _rejected_frames_paths.has(frames_path):
			continue
		if ResourceLoader.load_threaded_request(frames_path, FRAMES_RESOURCE_TYPE) == OK:
			_prefetch_in_flight[frames_path] = true
		else:
			_prefetch_failed_paths[frames_path] = true
			push_warning("full_frame_animation_registry: background prefetch of %s could not start; the pack loads on first use instead." % frames_path)
	_notify_residency_waiters()
	var remaining := _prefetch_queue.size() + _prefetch_in_flight.size()
	if remaining == 0:
		_disconnect_prefetch_tick()
	return remaining


# Drops every resident pack and the queue. A request still in flight is
# collected synchronously (at most MAX_PREFETCH_IN_FLIGHT packs, one pack's
# load time) and dropped: a threaded load that is still running when the
# engine shuts down is reported as a failed resource load, so `main.gd` calls
# this from its exit cleanup as well as the main menu calling it at run end.
static func release_prefetched() -> void:
	_prefetch_queue.clear()
	_prefetched_frames.clear()
	_prefetch_failed_paths.clear()
	_deferred_owners.clear()
	_residency_waiters.clear()
	for frames_path in _prefetch_in_flight.keys():
		ResourceLoader.load_threaded_get(frames_path)
	_prefetch_in_flight.clear()
	_disconnect_prefetch_tick()


# FAN-3977: keeps only the packs of `frames_paths` resident/queued and drops
# the rest, so texture memory is bounded by what the coming encounter can
# spawn (the route map keeps the core roster, an elite/boss fight drops the
# mini-elites, the next route map drops the boss). Must be called at a
# boundary where no live actor references a dropped pack (`_start_combat`
# clears the world first). Returns the number of resident packs dropped.
static func retain_only(frames_paths: Array) -> int:
	var keep := {}
	for frames_path in frames_paths:
		keep[str(frames_path)] = true
	var dropped := 0
	for frames_path in _prefetched_frames.keys():
		if not keep.has(frames_path):
			_prefetched_frames.erase(frames_path)
			_deferred_owners.erase(frames_path)
			dropped += 1
	var queue: Array = []
	for frames_path in _prefetch_queue:
		if keep.has(frames_path):
			queue.append(frames_path)
	_prefetch_queue = queue
	# An in-flight request is left to complete: collecting it here would block
	# for the remainder of the load; `advance_prefetch` drops nothing it did not
	# ask for, so the pack simply becomes resident and is released at the next
	# boundary.
	if _prefetch_queue.is_empty() and _prefetch_in_flight.is_empty():
		_disconnect_prefetch_tick()
	return dropped


static func is_resident(frames_path: String) -> bool:
	return _prefetched_frames.has(frames_path)


# A path counts as settled when it is resident or can never become resident
# through the prefetch (rejected type, failed/unstartable request,
# unregistered): waiting on it would never end.
static func _is_settled(frames_path: String) -> bool:
	if _prefetched_frames.has(frames_path) or _rejected_frames_paths.has(frames_path) or _prefetch_failed_paths.has(frames_path):
		return true
	return not (_prefetch_queue.has(frames_path) or _prefetch_in_flight.has(frames_path))


static func all_resident(frames_paths: Array) -> bool:
	for frames_path in frames_paths:
		if not _prefetched_frames.has(str(frames_path)):
			return false
	return true


# FAN-3977: queues every missing pack of `frames_paths` and returns true when
# all of them are settled — resident, or unable to become resident (rejected
# type, failed/unstartable request, unregistered/nonexistent path: the actor
# keeps its static body). Otherwise `callback` is registered once (a waiter
# with the same callback is updated, not duplicated) and invoked from the
# prefetch tick that settles the last pack; it is never invoked from inside
# this call. Combat start uses this so an encounter never spawns before its
# roster is resident, without a synchronous drain at the node click.
static func ensure_resident(frames_paths: Array, callback: Callable) -> bool:
	var pending: Array = []
	for frames_path_variant in frames_paths:
		var frames_path := str(frames_path_variant)
		if _prefetched_frames.has(frames_path):
			continue
		queue_prefetch_path(frames_path)
		if not _is_settled(frames_path):
			pending.append(frames_path)
	if pending.is_empty():
		return true
	for waiter in _residency_waiters:
		if (waiter["callback"] as Callable) == callback:
			waiter["paths"] = pending
			_connect_prefetch_tick()
			return false
	_residency_waiters.append({"paths": pending, "callback": callback})
	_connect_prefetch_tick()
	return false


static func _notify_residency_waiters() -> void:
	if _residency_waiters.is_empty():
		return
	var still_waiting: Array = []
	var ready: Array = []
	for waiter in _residency_waiters:
		var settled := true
		for frames_path in waiter["paths"]:
			if not _is_settled(str(frames_path)):
				settled = false
				break
		if settled:
			ready.append(waiter)
		else:
			still_waiting.append(waiter)
	_residency_waiters = still_waiting
	for waiter in ready:
		var callback: Callable = waiter["callback"]
		if callback.is_valid():
			callback.call()


static func residency_waiter_count() -> int:
	return _residency_waiters.size()


# FAN-3977: combat guard. `combat_director` raises it when spawning starts and
# lowers it when the fight ends; while it is up `_frames_for_path` never
# loads synchronously (see there). The miss counter is cumulative for the
# process so a scripted run can assert it stayed 0 across many fights.
static func set_combat_guard(active: bool) -> void:
	_combat_guard_active = active
	if active:
		_combat_miss_warned_paths.clear()


static func is_combat_guard_active() -> bool:
	return _combat_guard_active


static func synchronous_combat_load_count() -> int:
	return _synchronous_combat_load_count


static func reset_synchronous_combat_load_count() -> void:
	_synchronous_combat_load_count = 0


static func _register_deferred_owner(frames_path: String, owner: Node2D) -> void:
	if frames_path == "" or owner == null or _rejected_frames_paths.has(frames_path):
		return
	if not _deferred_owners.has(frames_path):
		_deferred_owners[frames_path] = []
	(_deferred_owners[frames_path] as Array).append(weakref(owner))


static func _swap_deferred_owners(frames_path: String) -> void:
	if not _deferred_owners.has(frames_path):
		return
	var owners: Array = _deferred_owners[frames_path]
	_deferred_owners.erase(frames_path)
	for owner_ref in owners:
		var owner = (owner_ref as WeakRef).get_ref()
		if owner == null or not is_instance_valid(owner) or not (owner is Node) or not (owner as Node).is_inside_tree():
			continue
		if owner.has_method("refresh_full_frame_visual"):
			owner.call("refresh_full_frame_visual")


static func deferred_owner_count() -> int:
	var total := 0
	for frames_path in _deferred_owners.keys():
		total += (_deferred_owners[frames_path] as Array).size()
	return total


static func prefetched_frames_count() -> int:
	return _prefetched_frames.size()


static func _connect_prefetch_tick() -> void:
	if _prefetch_tick_connected:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	tree.process_frame.connect(advance_prefetch)
	_prefetch_tick_connected = true


static func _disconnect_prefetch_tick() -> void:
	if not _prefetch_tick_connected:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.process_frame.is_connected(advance_prefetch):
		tree.process_frame.disconnect(advance_prefetch)
	_prefetch_tick_connected = false


static func configure_entity_visual(owner: Node2D, entity_kind: String, entity_id: String, animated_body_name := DEFAULT_ANIMATED_BODY_NAME, static_body_name := DEFAULT_STATIC_BODY_NAME) -> AnimatedSprite2D:
	if owner == null:
		return null
	var config := registry_config(entity_kind, entity_id)
	if config.is_empty() and owner.has_meta("full_frame_spriteframes_path"):
		config = {
			"frames": str(owner.get_meta("full_frame_spriteframes_path")),
			"scale": owner.get_meta("full_frame_scale", Vector2.ONE),
			"position": owner.get_meta("full_frame_position", Vector2.ZERO),
			"source_faces_left": bool(owner.get_meta("full_frame_source_faces_left", true)),
			"explicit_eight_directions": bool(owner.get_meta("full_frame_explicit_eight_directions", false)),
		}
	if config.is_empty():
		return null

	var frames_path := str(config.get("frames", ""))
	var frames := _frames_for_path(frames_path, "%s/%s" % [entity_kind, entity_id])
	if frames == null:
		# FAN-3977: a miss under the combat guard keeps the static body now and
		# swaps to the pack when the queued background load lands.
		if _combat_guard_active:
			_register_deferred_owner(frames_path, owner)
		return null

	var animated_body := owner.get_node_or_null(animated_body_name) as AnimatedSprite2D
	if animated_body == null:
		animated_body = AnimatedSprite2D.new()
		animated_body.name = animated_body_name
		owner.add_child(animated_body)
	animated_body.sprite_frames = frames
	animated_body.scale = config.get("scale", Vector2.ONE)
	animated_body.position = config.get("position", Vector2.ZERO)
	animated_body.visible = true
	animated_body.set_meta("entity_kind", entity_kind)
	animated_body.set_meta("entity_id", entity_id)
	animated_body.set_meta("source_faces_left", bool(config.get("source_faces_left", true)))
	animated_body.set_meta("explicit_horizontal_directions", bool(config.get("explicit_horizontal_directions", false)))
	animated_body.set_meta("explicit_eight_directions", bool(config.get("explicit_eight_directions", false)))

	var static_body := owner.get_node_or_null(static_body_name) as CanvasItem
	if static_body != null:
		static_body.visible = false

	play_state(animated_body, "move", Vector2.ZERO)
	return animated_body


static func play_state(animated_body: AnimatedSprite2D, requested_state: String, direction := Vector2.ZERO) -> bool:
	if animated_body == null or animated_body.sprite_frames == null:
		return false
	var effective_direction := _effective_facing_direction(animated_body, direction)
	var uses_explicit_eight := bool(animated_body.get_meta("explicit_eight_directions", false))
	var uses_explicit_horizontal := bool(animated_body.get_meta("explicit_horizontal_directions", false))
	var directional_state_name := ""
	if uses_explicit_eight:
		directional_state_name = _resolve_directional_animation_name(animated_body.sprite_frames, requested_state, direction_suffix_for(effective_direction))
	elif uses_explicit_horizontal:
		directional_state_name = _resolve_horizontal_animation_name(animated_body.sprite_frames, requested_state, _horizontal_facing_right(animated_body, effective_direction))
	var state_name := directional_state_name
	if state_name == "":
		# FAN-2519: явный направленный контракт без направленной строки деградирует
		# в безнаправленную строку ТОГО ЖЕ пула состояний и кандидатов — никогда в
		# зеркальный суррогат другого ракурса (flip ниже запрещён), и деградация
		# маркируется метой `directional_fallback_used`: живой актор не может
		# молча сыграть чужую/зеркальную идентичность.
		state_name = _resolve_animation_name(animated_body.sprite_frames, requested_state)
	if state_name == "":
		return false
	var uses_directional_contract := uses_explicit_eight or uses_explicit_horizontal
	animated_body.set_meta("directional_row_resolved", directional_state_name != "")
	animated_body.set_meta("directional_fallback_used", uses_directional_contract and directional_state_name == "")
	if uses_directional_contract:
		animated_body.flip_h = false
	elif effective_direction.length_squared() > DIRECTION_SNAP_EPSILON:
		var source_faces_left := bool(animated_body.get_meta("source_faces_left", true))
		animated_body.flip_h = effective_direction.x > 0.0 if source_faces_left else effective_direction.x < 0.0
	animated_body.set_meta("last_requested_state", requested_state)
	animated_body.set_meta("last_resolved_state", state_name)
	if uses_explicit_eight:
		animated_body.set_meta("last_resolved_direction_suffix", direction_suffix_for(effective_direction))
	if animated_body.animation != state_name or not animated_body.is_playing():
		animated_body.play(state_name)
	return true


# FAN-2519: фактическая резолвнутая строка последнего запроса состояния
# (8-направленные паки играют `death_<suffix>` последнего ракурса); мету
# берём только если последний запрос действительно совпадает с искомым
# состоянием, и падаем обратно на безнаправленную строку при её отсутствии.
static func resolved_last_row(animated_body: AnimatedSprite2D, requested_state: String, frames: SpriteFrames) -> String:
	var row := requested_state
	if str(animated_body.get_meta("last_requested_state", "")) == requested_state:
		row = str(animated_body.get_meta("last_resolved_state", requested_state))
	if not frames.has_animation(row):
		row = requested_state
	return row


static func has_state(animated_body: AnimatedSprite2D, requested_state: String) -> bool:
	if animated_body == null or animated_body.sprite_frames == null:
		return false
	if bool(animated_body.get_meta("explicit_eight_directions", false)):
		var persisted_direction: Vector2 = animated_body.get_meta("last_facing_direction", DEFAULT_FACING_DIRECTION)
		if _resolve_directional_animation_name(animated_body.sprite_frames, requested_state, direction_suffix_for(persisted_direction)) != "":
			return true
	if bool(animated_body.get_meta("explicit_horizontal_directions", false)):
		var faces_right := bool(animated_body.get_meta("last_horizontal_facing_right", false))
		if _resolve_horizontal_animation_name(animated_body.sprite_frames, requested_state, faces_right) != "":
			return true
	return _resolve_animation_name(animated_body.sprite_frames, requested_state) != ""


static func uses_explicit_horizontal_directions(animated_body: AnimatedSprite2D) -> bool:
	return animated_body != null and bool(animated_body.get_meta("explicit_horizontal_directions", false))


static func uses_explicit_eight_directions(animated_body: AnimatedSprite2D) -> bool:
	return animated_body != null and bool(animated_body.get_meta("explicit_eight_directions", false))


# FAN-2519: октант вектора в суффикс строки. Нулевой вектор даёт "south" —
# тот же дефолт, что у игрока; фактический ракурс для нулевого направления
# берётся из персистентной памяти последнего ненулевого направления.
static func direction_suffix_for(direction: Vector2) -> String:
	if direction.length_squared() <= DIRECTION_SNAP_EPSILON:
		return "south"
	var sector_size := TAU / float(DIRECTION_SUFFIXES.size())
	var index := int(floor((direction.angle() + sector_size * 0.5) / sector_size))
	return str(DIRECTION_SUFFIXES[posmod(index, DIRECTION_SUFFIXES.size())])


# FAN-2519: аудит-хелпер для паков с явным 8-направленным контрактом: состояние
# обязано иметь ВСЕ восемь явных строк, частичное покрытие — нарушение контракта.
static func has_full_directional_rows(frames: SpriteFrames, state_name: String) -> bool:
	if frames == null:
		return false
	for suffix in DIRECTION_SUFFIXES:
		if not frames.has_animation("%s_%s" % [state_name, suffix]):
			return false
	return true


static func _effective_facing_direction(animated_body: AnimatedSprite2D, direction: Vector2) -> Vector2:
	if direction.length_squared() > DIRECTION_SNAP_EPSILON:
		var normalized := direction.normalized()
		animated_body.set_meta("last_facing_direction", normalized)
		return normalized
	return animated_body.get_meta("last_facing_direction", DEFAULT_FACING_DIRECTION)


# Горизонтальный контракт помнит только знак X: вертикальные направления
# сохраняют последний горизонтальный ракурс (запад по умолчанию у west-facing
# исходников) — семантика ghost-паков SCRUM-885 сохранена, но живёт в реестре.
static func _horizontal_facing_right(animated_body: AnimatedSprite2D, effective_direction: Vector2) -> bool:
	if absf(effective_direction.x) > DIRECTION_SNAP_EPSILON:
		var faces_right := effective_direction.x > 0.0
		animated_body.set_meta("last_horizontal_facing_right", faces_right)
		return faces_right
	return bool(animated_body.get_meta("last_horizontal_facing_right", false))


static func _resolve_directional_animation_name(frames: SpriteFrames, requested_state: String, suffix: String) -> String:
	if frames == null or suffix == "":
		return ""
	for candidate in _state_candidates(requested_state):
		var directional_candidate := "%s_%s" % [candidate, suffix]
		if frames.has_animation(directional_candidate):
			return directional_candidate
	return ""


static func _resolve_horizontal_animation_name(frames: SpriteFrames, requested_state: String, faces_right: bool) -> String:
	if frames == null:
		return ""
	var suffix := "right" if faces_right else "left"
	for candidate in _state_candidates(requested_state):
		var directional_candidate := "%s_%s" % [candidate, suffix]
		if frames.has_animation(directional_candidate):
			return directional_candidate
	return ""


static func _resolve_animation_name(frames: SpriteFrames, requested_state: String) -> String:
	if frames == null:
		return ""
	var candidates := _state_candidates(requested_state)
	for candidate in candidates:
		if frames.has_animation(candidate):
			return candidate
	return ""


static func _state_candidates(requested_state: String) -> Array:
	var normalized := requested_state.strip_edges().to_lower()
	var candidates := []
	if normalized != "":
		candidates.append(normalized)
	if normalized.contains(":"):
		for part in normalized.split(":", false):
			if part != "":
				candidates.append(part)
				candidates.append("skill_%s" % part)
				candidates.append("attack_%s" % part)
	if normalized.begins_with("attack_"):
		candidates.append("attack")
		candidates.append("attack_primary")
	if normalized.begins_with("skill_"):
		candidates.append("cast")
		candidates.append("attack")
	if STATE_ALIASES.has(normalized):
		candidates.append_array(STATE_ALIASES[normalized])
	for generic_state in ["attack", "cast", "shoot", "hit", "death", "move", "idle"]:
		if normalized.contains(generic_state):
			candidates.append_array(STATE_ALIASES.get(generic_state, [generic_state]))
	candidates.append_array(["move", "idle"])
	var deduped := []
	for candidate in candidates:
		if candidate != "" and not deduped.has(candidate):
			deduped.append(candidate)
	return deduped
