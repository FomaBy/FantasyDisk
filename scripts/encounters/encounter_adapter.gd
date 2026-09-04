extends RefCounted
## EncounterAdapter — единственная точка сцепления боевого цикла с пакетом битов
## (FAN-1447). Держит ссылку на живого EncounterBeatDirector текущего боя, чтобы
## `scripts/combat_director.gd` оставался тонким: там только два вызова,
## `begin()` и `shutdown()`, без знания о внутренностях пакета.
##
## Вынесено из CombatDirector осознанно: файл боевого цикла держит ratchet 1500
## строк (tools/quality_static_guard.py), и «растить монолит» ради адаптера
## запрещено — вся логика живёт в изолированном scripts/encounters/**.

const CONFIG := preload("res://scripts/encounters/encounter_config.gd")
const BEAT_DIRECTOR := preload("res://scripts/encounters/encounter_beat_director.gd")
const SCENE_CACHE := preload("res://scripts/encounters/encounter_scene_cache.gd")

# Живой директор текущего боя (узел-ребёнок Main, process_mode PAUSABLE).
var _director: Node = null
var _scene_cache: RefCounted = null


# Поднять директора на финализации боя. При выключенной системе — no-op, поэтому
# бой остаётся байт-идентичен baseline (default-off parity). Eligibility
# (нормальный бой, ровно один primary-бит) проверяет сам директор.
func begin(game, combat) -> void:
	_free_stale()
	var slice_def := CONFIG.slice_for_game(game)
	if slice_def.is_empty() and not CONFIG.is_enabled():
		return
	var director: Node = BEAT_DIRECTOR.new()
	director.name = "EncounterBeatDirector"
	game.add_child(director)
	director.setup(game, combat, slice_def)
	director.begin()
	_director = director
	_prepare_spawn_plan()


# Терминальная остановка бита: фича снимает маркеры/твины/колбэки и фиксирует
# метрики исхода (включая death-флаг), пока боевые узлы ещё живы. Идемпотентно.
func shutdown(victory: bool) -> void:
	_scene_cache = null
	if _director == null or not is_instance_valid(_director):
		_director = null
		return
	_director.shutdown(victory)
	_director = null


func spawn_plan_projection() -> Dictionary:
	if _director == null or not is_instance_valid(_director):
		return {}
	return _director.spawn_plan_projection()


func spawn_scene(plan: Dictionary, path: String) -> PackedScene:
	if _scene_cache == null:
		return null
	return _scene_cache.scene_for(plan, path)


static func project_spawn_plan(game, node_seed: int, scaling_stage: int,
		combat_type: String, slice_id := "") -> Dictionary:
	var slice_def := CONFIG.slice(slice_id)
	if slice_def.is_empty() and not CONFIG.is_enabled():
		return {}
	return BEAT_DIRECTOR.project_spawn_plan(game, node_seed, scaling_stage, combat_type, slice_def)


# Снять протёкшего директора прошлого боя (без записи метрик исхода).
func _free_stale() -> void:
	_scene_cache = null
	if _director != null and is_instance_valid(_director) \
			and not _director.is_queued_for_deletion():
		_director.queue_free()
	_director = null


func _prepare_spawn_plan() -> void:
	var plan := spawn_plan_projection()
	if plan.is_empty():
		return
	var cache := SCENE_CACHE.new()
	if cache.prepare(plan):
		_scene_cache = cache


# --- Доступ для тестов/QA ---

func debug_director() -> Node:
	return _director


func debug_scene_resolution_count() -> int:
	return _scene_cache.resolution_count() if _scene_cache != null else 0
