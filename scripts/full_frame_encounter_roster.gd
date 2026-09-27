extends RefCounted
class_name FullFrameEncounterRoster

# FAN-3977 (0.3.2 release blocker, FAN-3964 QA): the set of full-frame packs
# an encounter can spawn, so they are resident BEFORE combat starts and
# nothing is loaded on the main thread mid-fight (see
# FullFrameAnimationRegistry.set_combat_guard).
#
# Spawn paths per encounter type (combat_director.gd):
# - regular battle: every wave draws from the whole enemy pool; every
#   mini-elite kind can roll (`_maybe_spawn_mini_elite`, any act); class
#   summons/allies come from the player's kit.
# - elite node: enemy waves + the node elite (`node_elite_scene(seed)`);
#   mini-elites never roll in elite/boss combat.
# - boss node: enemy waves (bosses also summon riftlings) + the act boss;
#   the secret boss declares its pack through scene metadata.
# Allies are the ones the selected class can summon: every registered ally
# id named anywhere in the class's weapon configs (`ally_visual_id`,
# `ally_visual_ids`, `pair_tank_visual_id`, roster `visual_id`), plus the
# `druid_beast`/`druid_pack_spirit` defaults of AllyMinion/summoner_weapon
# whenever the class has a summon weapon or is the Druid (its ultimate spawns
# default-visual allies). An unknown class keeps every ally pack (fail-safe).
#
# Memory bound (trim atlases, RGBA): core roster ~0.9 GiB (Druid) / ~0.85 GiB
# (no summons); an elite or boss roster drops the mini-elites (~0.45 GiB) and
# adds one pack (≤ 0.23 GiB). RENDER_TEXTURE_MEM_USED reports 4/3 of the RGBA
# bytes for every texture, so the resident set reads as ~1.1-1.2 GiB against
# the 1.5 GiB acceptance line.

const SECRET_BOSS_FRAMES_META := "metadata/full_frame_spriteframes_path"


static func enemy_paths() -> Array:
	return _kind_paths("enemy")


static func ally_paths() -> Array:
	return _kind_paths("ally")


const SUMMON_DEFAULT_ALLY_IDS := ["druid_beast", "druid_pack_spirit"]
const SUMMON_WEAPON_KEY_PREFIX := "summon_"


# Ally packs the class can summon (see the header). `character_id` "" or an
# id without weapon data falls back to every ally pack.
static func ally_paths_for_class(progression_data, character_id: String) -> Array:
	if progression_data == null or character_id == "" or not progression_data.has_method("weapon_ids"):
		return ally_paths()
	var weapon_ids: Array = progression_data.weapon_ids(character_id)
	if weapon_ids.is_empty():
		return ally_paths()
	var registered := {}
	for ally_id in FullFrameAnimationRegistry.kind_entity_ids("ally"):
		registered[str(ally_id)] = true
	var found := {}
	var has_summon_weapon := false
	for weapon_id in weapon_ids:
		var config: Dictionary = progression_data.weapon(character_id, str(weapon_id))
		has_summon_weapon = has_summon_weapon or _has_summon_keys(config)
		_collect_ally_ids(config, registered, found)
	if has_summon_weapon or character_id == "druid" or not found.is_empty():
		for ally_id in SUMMON_DEFAULT_ALLY_IDS:
			if registered.has(ally_id):
				found[ally_id] = true
	var paths: Array = []
	for ally_id in FullFrameAnimationRegistry.kind_entity_ids("ally"):
		if found.has(str(ally_id)):
			_append_unique(paths, FullFrameAnimationRegistry.frames_path_for("ally", str(ally_id)))
	return paths


static func _has_summon_keys(config: Dictionary) -> bool:
	for key in config.keys():
		if str(key).begins_with(SUMMON_WEAPON_KEY_PREFIX):
			return true
	return false


# Recursively collects every string equal to a registered ally id.
static func _collect_ally_ids(value, registered: Dictionary, found: Dictionary) -> void:
	if value is String:
		if registered.has(value):
			found[value] = true
	elif value is Dictionary:
		for key in (value as Dictionary).keys():
			_collect_ally_ids((value as Dictionary)[key], registered, found)
	elif value is Array:
		for item in (value as Array):
			_collect_ally_ids(item, registered, found)


# Every mini-elite kind that can roll in a regular fight, resolved the way
# enemy.gd `_full_frame_entity_id` resolves it: the kind's own pack when
# registered, otherwise the base elite behavior's pack.
static func mini_elite_paths(progression_data) -> Array:
	var paths: Array = []
	if progression_data == null or not progression_data.has_method("mini_elite_kinds"):
		return paths
	for kind_variant in progression_data.mini_elite_kinds():
		var kind: Dictionary = kind_variant
		var frames_path := FullFrameAnimationRegistry.frames_path_for("elite", str(kind.get("id", "")))
		if frames_path == "":
			frames_path = FullFrameAnimationRegistry.frames_path_for("elite", str(kind.get("behavior", "")))
		_append_unique(paths, frames_path)
	return paths


# What every regular fight of any act can spawn: the route map keeps this
# resident between fights.
static func core_paths(progression_data, character_id := "") -> Array:
	var paths: Array = enemy_paths()
	for frames_path in mini_elite_paths(progression_data):
		_append_unique(paths, frames_path)
	for frames_path in ally_paths_for_class(progression_data, character_id):
		_append_unique(paths, frames_path)
	return paths


# The roster of the encounter `game` is about to start. `boss_scene_for_id`
# resolves a boss id to its PackedScene (combat_director owns the preloads);
# the boss pack is read from the registry first and from the scene's
# `metadata/full_frame_spriteframes_path` otherwise (secret boss).
static func encounter_paths(game, boss_scene_for_id: Callable) -> Array:
	var paths: Array = enemy_paths()
	for frames_path in ally_paths_for_class(game.get("PROGRESSION_DATA"), str(game.get("selected_character_id"))):
		_append_unique(paths, frames_path)
	if bool(game.get("boss_combat_active")):
		var boss_id := str(game.get("current_boss_id"))
		var frames_path := FullFrameAnimationRegistry.frames_path_for("boss", boss_id)
		if frames_path == "" and boss_scene_for_id.is_valid():
			frames_path = FullFrameAnimationRegistry.scene_root_string_property(boss_scene_for_id.call(boss_id), SECRET_BOSS_FRAMES_META)
		_append_unique(paths, frames_path)
		return paths
	if str(game.get("current_combat_type")) == "elite":
		var elite_scene: PackedScene = game.node_elite_scene(int(game.get("current_node_seed"))) if game.has_method("node_elite_scene") else null
		var elite_id := FullFrameAnimationRegistry.scene_root_string_property(elite_scene, "elite_behavior")
		_append_unique(paths, FullFrameAnimationRegistry.frames_path_for("elite", elite_id))
		return paths
	for frames_path in mini_elite_paths(game.get("PROGRESSION_DATA")):
		_append_unique(paths, frames_path)
	return paths


# Combat-start gate: releases the packs the encounter cannot spawn, queues
# the missing ones and returns true when every pack of the roster is settled
# (resident, or unloadable and falling back to the static body). Otherwise
# `on_resident` is invoked from the prefetch tick once the last pack lands
# (see combat_director `_finalize_combat_start`); idempotent, so a stalled
# start can simply call it again.
static func prepare_encounter(game, boss_scene_for_id: Callable, on_resident: Callable) -> bool:
	var roster := encounter_paths(game, boss_scene_for_id)
	FullFrameAnimationRegistry.retain_only(roster)
	return FullFrameAnimationRegistry.ensure_resident(roster, on_resident)


static func _kind_paths(entity_kind: String) -> Array:
	var paths: Array = []
	for entity_id in FullFrameAnimationRegistry.kind_entity_ids(entity_kind):
		_append_unique(paths, FullFrameAnimationRegistry.frames_path_for(entity_kind, str(entity_id)))
	return paths


static func _append_unique(paths: Array, frames_path: String) -> void:
	if frames_path != "" and not paths.has(frames_path):
		paths.append(frames_path)
