extends RefCounted
## EncounterContext — versioned read-обёртка боевого состояния для битов
## (EncounterFeature API v1). Бит НЕ обращается к `game`/`combat` напрямую: он
## читает всё нужное отсюда. Это держит фичи изолированными и тестируемыми через
## versioned-контракт fixtures без скрытых зависимостей на sibling-реализацию.
##
## Детерминизм: `aspect_rng(salt)` создаёт независимый RandomNumberGenerator из
## node seed и соли (game.node_aspect_rng), НЕ расходуя глобальный `game.rng`.

const API_VERSION := 1
const SPAWN_PLAN_SCHEMA_VERSION := 1
const WAVE_QUOTA_EXCLUDED_META := &"encounter_wave_quota_excluded"
const MIN_SAFE_RADIUS := 420.0
const MAX_SAFE_RADIUS := 900.0
const MAX_PLAN_ENTRIES := 8
const MAX_COUNT_PER_ENTRY := 8
const MAX_TOTAL_COUNT := 24
const MAX_QUOTA_EXCLUDED := 1
const CONFIG := preload("res://scripts/encounters/encounter_config.gd")

var game
var node_seed := 0
var combat_type := "battle"
var event_active := false
var boss_active := false
var route_scaling_stage := 0
var round_duration := 0.0
# Секунды активного (не поставленного на паузу) боя с момента begin директора.
var elapsed := 0.0
# Мир-родитель для презентации бита (узел директора, process_mode = PAUSABLE):
# маркеры-дети замерзают на паузе вместе с ним и гибнут при shutdown.
var presentation_parent: Node = null
var _allowed_enemy_scenes := {}
var _max_active_cap := 1
var _spawn_executor := Callable()
var _spawn_plan: Dictionary = {}
var _quota_excluded_count := 0


func api_version() -> int:
	return API_VERSION


func aspect_rng(salt: int) -> RandomNumberGenerator:
	return game.node_aspect_rng(node_seed, salt)


func is_normal_battle() -> bool:
	return combat_type == "battle" and not boss_active and not event_active


func configure_spawn_capability(allowed_scene_paths: Array, max_active_cap: int,
		executor := Callable()) -> void:
	_allowed_enemy_scenes.clear()
	for path in allowed_scene_paths:
		if path is String and ResourceLoader.exists(path):
			_allowed_enemy_scenes[path] = true
	_max_active_cap = maxi(max_active_cap, 1)
	_spawn_executor = executor


# Pure-data canonicalizer used by both live combat and route preview.
func canonical_spawn_plan(request: Variant, feature_id: String) -> Dictionary:
	if not is_normal_battle() or not (request is Dictionary):
		return {}
	var raw := request as Dictionary
	if not _exact_int(raw.get("schema_version"), SPAWN_PLAN_SCHEMA_VERSION):
		return {}
	var min_stage = raw.get("min_stage", 0)
	var max_stage = raw.get("max_stage", 64)
	var active_cap = raw.get("active_cap")
	var safe_radius = raw.get("safe_radius")
	var entries = raw.get("entries")
	if not _bounded_int(min_stage, 0, 64) or not _bounded_int(max_stage, int(min_stage), 64) \
			or route_scaling_stage < int(min_stage) or route_scaling_stage > int(max_stage) \
			or not _bounded_int(active_cap, 1, _max_active_cap) \
			or not (safe_radius is int or safe_radius is float) \
			or float(safe_radius) < MIN_SAFE_RADIUS or float(safe_radius) > MAX_SAFE_RADIUS \
			or not (entries is Array) or entries.is_empty() or entries.size() > MAX_PLAN_ENTRIES:
		return {}
	var normalized_entries: Array = []
	var seen_scenes := {}
	var total_count := 0
	for value in entries:
		if not (value is Dictionary):
			return {}
		var entry := value as Dictionary
		var scene = entry.get("scene")
		var count = entry.get("count")
		if not (scene is String) or not _allowed_enemy_scenes.has(scene) or seen_scenes.has(scene) \
				or not _bounded_int(count, 1, MAX_COUNT_PER_ENTRY):
			return {}
		seen_scenes[scene] = true
		total_count += int(count)
		if total_count > MAX_TOTAL_COUNT:
			return {}
		normalized_entries.append({"scene": scene, "count": int(count)})
	normalized_entries.sort_custom(func(a, b): return str(a["scene"]) < str(b["scene"]))
	var threat: Dictionary = normalized_entries[0]
	for entry in normalized_entries:
		if int(entry["count"]) > int(threat["count"]):
			threat = entry
	return {
		"schema_version": SPAWN_PLAN_SCHEMA_VERSION,
		"feature_id": feature_id,
		"node_seed": node_seed,
		"stage": route_scaling_stage,
		"active_cap": int(active_cap),
		"safe_radius": float(safe_radius),
		"total_count": total_count,
		"threat_scene": str(threat["scene"]),
		"entries": normalized_entries,
	}


func set_spawn_plan(plan: Dictionary) -> void:
	_spawn_plan = plan.duplicate(true)


func spawn_plan_projection() -> Dictionary:
	return _spawn_plan.duplicate(true)


func route_threat_projection() -> Dictionary:
	if _spawn_plan.is_empty():
		return {}
	return {
		"feature_id": str(_spawn_plan.get("feature_id", "")),
		"threat_scene": str(_spawn_plan.get("threat_scene", "")),
		"total_count": int(_spawn_plan.get("total_count", 0)),
		"active_cap": int(_spawn_plan.get("active_cap", 0)),
	}


func execute_spawn_plan() -> int:
	if _spawn_plan.is_empty() or not _spawn_executor.is_valid():
		return 0
	return int(_spawn_executor.call(_spawn_plan.duplicate(true)))


# Narrow targetable-but-not-wave-quota marker. Bosses/elites cannot opt out.
func exclude_from_wave_quota(enemy: Node) -> bool:
	if not is_normal_battle() or enemy == null or not enemy.is_in_group("enemies") \
			or enemy.is_in_group("bosses") or enemy.is_in_group("elite_enemies") \
			or _quota_excluded_count >= MAX_QUOTA_EXCLUDED:
		return false
	if counts_toward_wave_quota(enemy):
		enemy.set_meta(WAVE_QUOTA_EXCLUDED_META, true)
		_quota_excluded_count += 1
	return true


static func counts_toward_wave_quota(enemy: Node) -> bool:
	if enemy == null or enemy.is_in_group("bosses") or enemy.is_in_group("elite_enemies"):
		return true
	var marker: Variant = enemy.get_meta(WAVE_QUOTA_EXCLUDED_META, false)
	return not (marker is bool and marker)


static func wave_quota_count(enemies: Array) -> int:
	var count := 0
	for enemy in enemies:
		if enemy is Node and counts_toward_wave_quota(enemy):
			count += 1
	return count


func act_feature_state(feature_id: String) -> Dictionary:
	if game == null:
		return {"quarantined": true}
	return CONFIG.act_feature_state(game.get("encounter_feature_state"), int(game.get("current_act")), feature_id)


# Checkpoint precedes risk activation. Failed persistence rolls memory back.
func checkpoint_act_feature_state(feature_id: String, record: Dictionary,
		persist := true) -> bool:
	if game == null:
		return false
	var previous: Dictionary = CONFIG.normalize_act_state(
		game.get("encounter_feature_state"), int(game.get("current_act")))
	var next := CONFIG.checkpoint_act_state(previous, int(game.get("current_act")), feature_id, record)
	if next.is_empty():
		return false
	game.set("encounter_feature_state", next)
	if persist and (not game.has_method("save_run_autosave") \
			or not bool(game.call("save_run_autosave", "encounter_feature_checkpoint"))):
		game.set("encounter_feature_state", previous)
		return false
	return true


func player() -> Node:
	if game != null and game.current_player != null and is_instance_valid(game.current_player):
		return game.current_player
	return null


func player_position() -> Vector2:
	var live := player() as Node2D
	if live != null:
		return live.global_position
	if game != null:
		return game.ARENA_CENTER
	return Vector2.ZERO


# Живые обычные враги на арене (без элиток, мини-элиток и боссов).
func alive_normal_enemies() -> Array:
	var result: Array = []
	if game == null or game.get_tree() == null:
		return result
	for node in game.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.is_queued_for_deletion():
			continue
		if enemy.is_in_group("bosses") or enemy.is_in_group("elite_enemies"):
			continue
		result.append(enemy)
	return result


# Живой корень боевого HUD (для экранного таймера бита). null, если HUD снят.
func hud_root() -> Control:
	if game == null or game.hud_layer == null or not is_instance_valid(game.hud_layer):
		return null
	return game.hud_layer.find_child("CombatHudRoot", true, false) as Control


static func _exact_int(value: Variant, expected: int) -> bool:
	return (value is int or value is float) and float(value) == float(expected)


static func _bounded_int(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and float(value) == floorf(float(value)) \
		and float(value) >= minimum and float(value) <= maximum
