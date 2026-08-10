extends Node
## EncounterBeatDirector — рантайм-двигатель битов боя (FAN-1447, contract v1).
##
## Один экземпляр живёт ровно один нормальный бой. Узел добавляется в дерево как
## ребёнок Main с process_mode = PAUSABLE, поэтому его `_process` (и все дети-
## маркеры) автоматически замерзают на паузе / level-up / молитве и тикают ровно
## по тем же кадрам, что и боевой `_process` Main (тот тоже гейтится
## get_tree().paused).
##
## Ответственность директора:
##   - детерминированная sorted discovery eligible primary-битов из каталога;
##   - один primary-бит в обычном default-off режиме либо сериализованный
##     slice с максимум одним активным primary в каждый момент;
##   - lifecycle: trigger → tick → resolve; терминальная очистка на конце боя;
##   - агрегирование локальных метрик.
## Новые пакеты-фичи подключаются данными каталога (id + script).

const API_VERSION := 1
const CONFIG := preload("res://scripts/encounters/encounter_config.gd")
const CONTEXT := preload("res://scripts/encounters/encounter_context.gd")
const METRICS := preload("res://scripts/encounters/encounter_metrics.gd")
const FEATURE_BASE := preload("res://scripts/encounters/encounter_feature.gd")

var game
var combat

var _context
var _metrics
var _feature            # активный EncounterFeature (единственный primary-бит)
var _beat_def: Dictionary = {}
var _plan: Dictionary = {}
var _spawn_plan: Dictionary = {}
var _slice_def: Dictionary = {}
var _primary_sequence: Array = []
var _sequence_index := 0
var _completed_sequence_ids: Array = []
var _elapsed := 0.0
# idle -> planned -> active -> done
var _state := "idle"


func setup(game_ref, combat_ref, slice_def: Dictionary = {}) -> void:
	game = game_ref
	combat = combat_ref
	_slice_def = slice_def.duplicate(true)
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_metrics = METRICS.new()


# Старт директора для текущего боя. Планирует обычный primary или объявленную
# последовательность slice; вне них остаётся инертным (baseline parity).
func begin() -> void:
	_context = CONTEXT.new()
	_context.game = game
	_context.combat = combat
	_context.node_seed = int(game.current_node_seed)
	_context.combat_type = str(game.current_combat_type)
	_context.event_active = not game.pending_event_combat.is_empty()
	_context.boss_active = bool(game.boss_combat_active)
	_context.route_scaling_stage = int(game.route_scaling_stage()) if game.has_method("route_scaling_stage") else 0
	_context.round_duration = maxf(float(game.round_time_left), 0.0)
	_context.elapsed = 0.0
	_context.presentation_parent = self
	var executor := Callable(combat, "spawn_encounter_plan") \
		if combat != null and combat.has_method("spawn_encounter_plan") else Callable()
	var spawn_weights = _game_value("ENEMY_SPAWN_WEIGHTS", {})
	var wave_settings = _game_value("WAVE_SETTINGS", {})
	var allowed_scenes: Array = spawn_weights.keys() if spawn_weights is Dictionary else []
	var maximum_active := int(wave_settings.get("max_active_cap", 1)) \
		if wave_settings is Dictionary else 1
	_context.configure_spawn_capability(allowed_scenes, maximum_active, executor)

	if not _context.is_normal_battle():
		_state = "done"
		return
	_spawn_plan = _build_spawn_plan(_context)
	_context.set_spawn_plan(_spawn_plan)
	_plan_primary_beat()


func _plan_primary_beat() -> void:
	if not _slice_def.is_empty():
		_primary_sequence = CONFIG.slice_primary_sequence(_slice_def, _context)
		_sequence_index = 0
		_plan_next_slice_phase()
		return
	var candidates: Array = []
	for beat_def in CONFIG.primary_beats():
		var feature = _instantiate_feature(beat_def)
		if feature == null:
			continue
		if not feature.is_eligible(_context):
			continue
		var plan: Dictionary = feature.plan(_context, beat_def)
		if plan.is_empty():
			continue
		candidates.append({"beat": beat_def, "feature": feature, "plan": plan})

	if candidates.is_empty():
		_state = "done"
		return

	# Ровно один primary-бит: детерминированный выбор из node seed (отдельный
	# генератор, глобальный game.rng не расходуется).
	var pick_rng: RandomNumberGenerator = game.node_aspect_rng(int(game.current_node_seed), CONFIG.PRIMARY_PICK_SALT)
	var chosen: Dictionary = candidates[pick_rng.randi_range(0, candidates.size() - 1)]
	_beat_def = chosen["beat"]
	_feature = chosen["feature"]
	_plan = chosen["plan"]
	_state = "planned"
	_metrics.note_offered(str(_beat_def.get("id", "")))


func _plan_next_slice_phase() -> void:
	while _sequence_index < _primary_sequence.size():
		var phase: Dictionary = _primary_sequence[_sequence_index]
		var beat_def: Dictionary = phase["beat"]
		var feature = _instantiate_feature(beat_def)
		if feature != null and (feature.is_eligible(_context) or bool(phase["slice_activates_pack"])):
			var next_plan: Dictionary = feature.plan(_context, beat_def)
			if not next_plan.is_empty():
				_beat_def = beat_def
				_feature = feature
				_plan = next_plan
				_state = "planned"
				_metrics.note_offered(str(_beat_def.get("id", "")))
				return
		_sequence_index += 1
	_feature = null
	_beat_def = {}
	_plan = {}
	_state = "done"


func _instantiate_feature(beat_def: Dictionary):
	var script_path := str(beat_def.get("script", ""))
	if script_path == "":
		push_error("EncounterBeatDirector: бит %s без script" % str(beat_def.get("id", "?")))
		return null
	var feature_script = load(script_path)
	if feature_script == null:
		push_error("EncounterBeatDirector: не удалось загрузить %s" % script_path)
		return null
	var feature = feature_script.new()
	if not (feature is FEATURE_BASE):
		push_error("EncounterBeatDirector: %s не наследует EncounterFeature" % script_path)
		return null
	if feature.api_version() != FEATURE_BASE.API_VERSION:
		push_error("EncounterBeatDirector: %s несовместимой API v%d" % [script_path, feature.api_version()])
		return null
	# Тип — единственная runtime-идентичность, общая для всех фич. Id принадлежит
	# записи каталога: один pack-скрипт может обслуживать несколько определений
	# (captain-роли биндят свою роль из beat_def), поэтому id везде берётся из
	# registry, а не из рантайма.
	if feature.definition_type() != str(beat_def.get("type", "")):
		push_error("EncounterBeatDirector: runtime type не совпадает с registry %s" % script_path)
		return null
	return feature


func _build_spawn_plan(context) -> Dictionary:
	var result: Dictionary = {}
	for feature_def in CONFIG.features_with_capability("spawn_plan", _slice_def):
		var feature = _instantiate_feature(feature_def)
		if feature == null or not feature.is_eligible(context):
			continue
		var request: Dictionary = feature.build_spawn_plan(context, feature_def)
		var candidate: Dictionary = context.canonical_spawn_plan(request, str(feature_def.get("id", "")))
		if candidate.is_empty():
			continue
		if not result.is_empty():
			return {}  # multiple live planners fail closed instead of stacking
		result = candidate
	return result


static func project_spawn_plan(game_ref, node_seed: int, scaling_stage: int,
		combat_type: String, slice_def: Dictionary = {}) -> Dictionary:
	var probe := new()
	probe.game = game_ref
	probe._slice_def = slice_def.duplicate(true)
	var context = CONTEXT.new()
	context.game = game_ref
	context.node_seed = node_seed
	context.combat_type = combat_type
	context.event_active = combat_type in ["event", "hazard"]
	context.boss_active = combat_type == "boss"
	context.route_scaling_stage = scaling_stage
	var spawn_weights = probe._game_value("ENEMY_SPAWN_WEIGHTS", {})
	var wave_settings = probe._game_value("WAVE_SETTINGS", {})
	var allowed_scenes: Array = spawn_weights.keys() if spawn_weights is Dictionary else []
	var maximum_active := int(wave_settings.get("max_active_cap", 1)) \
		if wave_settings is Dictionary else 1
	context.configure_spawn_capability(allowed_scenes, maximum_active)
	var result: Dictionary = probe._build_spawn_plan(context)
	probe.free()
	return result


func _game_value(name: String, fallback):
	for property in game.get_property_list():
		if str(property.get("name", "")) == name:
			return game.get(name)
	var script: Script = game.get_script()
	if script != null:
		var constants := script.get_script_constant_map()
		if constants.has(name):
			return constants[name]
	return fallback


func _process(delta: float) -> void:
	if _state == "idle" or _state == "done":
		return
	_elapsed += delta
	_context.elapsed = _elapsed

	if _state == "planned":
		if _elapsed >= float(_plan.get("trigger_at", INF)):
			_trigger()
	elif _state == "active":
		_feature.on_tick(_context, delta)
		if _feature.is_resolved():
			_resolve_active("resolved")


func _trigger() -> void:
	var started: bool = _feature.on_trigger(_context, _beat_def)
	if not started:
		# Нет валидной цели в момент триггера — offer аборчен.
		var outcome: Dictionary = _feature.resolve(_context, "no_target")
		_finish_phase(outcome)
		return
	_metrics.note_triggered(str(_beat_def.get("id", "")))
	_state = "active"


func _resolve_active(reason: String) -> void:
	var outcome: Dictionary = _feature.resolve(_context, reason)
	_finish_phase(outcome)


func _finish_phase(outcome: Dictionary) -> void:
	_metrics.record_outcome(outcome)
	_completed_sequence_ids.append(str(_beat_def.get("id", "")))
	_feature = null
	if _slice_def.is_empty():
		_state = "done"
		return
	_sequence_index += 1
	_plan_next_slice_phase()


# Терминальная остановка на конце боя/смерти. Резолвит активный бит (метрики +
# очистка узлов/твинов/колбэков), фиксирует death-флаг, снимает QA-снапшот и
# освобождает узел. Идемпотентна.
func shutdown(victory: bool) -> void:
	if _state == "active" and _feature != null:
		var outcome: Dictionary = _feature.resolve(_context, "combat_end")
		if not bool(victory):
			outcome["player_died"] = true
		_metrics.record_outcome(outcome)
	elif _feature != null:
		# Бит ещё не стартовал (planned) — просто отпускаем ссылку.
		_feature = null
	_feature = null
	_primary_sequence.clear()
	_state = "done"
	if _metrics != null:
		METRICS.last_summary = _metrics.export_summary()
	if not is_queued_for_deletion():
		queue_free()


# --- Доступ для тестов/QA ---

func metrics() -> RefCounted:
	return _metrics


func state() -> String:
	return _state


func planned_beat_id() -> String:
	return str(_beat_def.get("id", ""))


func planned_trigger_at() -> float:
	return float(_plan.get("trigger_at", -1.0))


func spawn_plan_projection() -> Dictionary:
	return _spawn_plan.duplicate(true)


func route_threat_projection() -> Dictionary:
	return _context.route_threat_projection() if _context != null else {}


func elapsed_seconds() -> float:
	return _elapsed


func debug_feature():
	return _feature


func active_primary_count() -> int:
	return 1 if _state == "active" and _feature != null else 0


func planned_sequence_ids() -> Array:
	return _primary_sequence.map(func(phase): return str((phase["beat"] as Dictionary).get("id", "")))


func completed_sequence_ids() -> Array:
	return _completed_sequence_ids.duplicate()
