extends RefCounted
## EncounterFeature — versioned базовый контракт «бита» боя (API v1, FAN-1447).
##
## Бит — самодостаточный пакет: объявляет id/eligibility, детерминированно
## планирует момент триггера из node-seeded RNG контекста и ведёт жизненный цикл
## trigger → tick → resolve, возвращая outcome для метрик. Пакеты-фичи НЕ
## редактируют адаптер CombatDirector — их обнаруживает и приводит в движение
## EncounterBeatDirector по данным каталога.
##
## Контракт lifecycle (директор гарантирует порядок):
##   plan(context, beat_def)        -> Dictionary  # {trigger_at, window} или {}
##   on_trigger(context, beat_def)  -> bool         # true = бит реально стартовал
##   on_tick(context, delta)        -> void         # каждый не-паузный кадр
##   is_resolved()                  -> bool         # достигнут терминал?
##   resolve(context, reason)       -> Dictionary   # outcome + очистка узлов
##
## on_trigger/on_tick вызываются только между «не paused» кадрами (узел директора
## PAUSABLE), поэтому пауза/level-up/молитва замораживают бит без спец-логики.

const API_VERSION := 1
const DEFINITION_TYPE := "encounter_feature"
const ACT_STATE_SCHEMA_VERSION := 1
const ACT_DECISIONS := ["", "accepted", "declined"]
const ACT_RISK_STATES := ["", "armed", "succeeded", "failed"]
const ACT_RECORD_KEYS := ["decision", "offer_count", "risk", "claim_count", "checkpoint_ids"]

# Терминальные статусы outcome.
const STATUS_COMPLETED := "completed"
const STATUS_FAILED := "failed"
const STATUS_ABORTED := "aborted"


func api_version() -> int:
	return API_VERSION


func definition_type() -> String:
	return DEFINITION_TYPE


func id() -> String:
	push_error("EncounterFeature.id() must be overridden")
	return ""


# Подходит ли бит под текущий боевой контекст (обычно: нормальный бой).
func is_eligible(_context) -> bool:
	return false


# Детерминированный план из node-seeded RNG. Возвращает {trigger_at, window}
# (секунды) или {} — «отказаться» (бой слишком короткий и т.п.).
func plan(_context, _beat_def: Dictionary) -> Dictionary:
	return {}


# Optional data-driven spawn capability. A feature may override this method; the
# default selects one declared plan without consuming the global combat RNG.
func build_spawn_plan(context, feature_def: Dictionary) -> Dictionary:
	var options = feature_def.get("spawn_plans", [])
	if not (options is Array) or options.is_empty():
		return {}
	var rng: RandomNumberGenerator = context.aspect_rng(int(feature_def.get("seed_salt", 0)))
	var chosen = options[rng.randi_range(0, options.size() - 1)]
	return (chosen as Dictionary).duplicate(true) if chosen is Dictionary else {}


# Триггер бита: захватить цель и построить презентацию. true — бит стартовал;
# false — старт невозможен (нет валидной цели) → offer аборчен без метрик успеха.
func on_trigger(_context, _beat_def: Dictionary) -> bool:
	return false


# Кадровый апдейт активного бита (следование маркера, отсчёт окна, урон и т.п.).
func on_tick(_context, _delta: float) -> void:
	pass


# Достиг ли бит терминала (успех/провал) сам по себе.
func is_resolved() -> bool:
	return true


# Финализировать бит: вернуть outcome и ОСВОБОДИТЬ все свои узлы/твины/колбэки.
# reason ∈ {"resolved", "no_target", "combat_end"}.
func resolve(_context, _reason: String) -> Dictionary:
	return {}


# Единый билдер outcome-словаря (versioned outcome schema v1).
static func make_outcome(beat_id: String, status: String, fields: Dictionary = {}) -> Dictionary:
	var outcome := {
		"schema_version": API_VERSION,
		"beat_id": beat_id,
		"status": status,
		"duration": 0.0,
		"damage_to_target": 0.0,
		"player_died": false,
		"reason": "",
	}
	for key in fields:
		outcome[key] = fields[key]
	return outcome


static func empty_act_state(act: int, quarantined := false) -> Dictionary:
	return {
		"schema_version": ACT_STATE_SCHEMA_VERSION,
		"act": maxi(act, 1),
		"entries": {},
		"quarantined": quarantined,
	}


# Shared persistence envelope only stores decision/risk/cap/idempotency facts.
# UI nodes, reward payloads and arbitrary feature dictionaries are rejected.
static func normalize_act_state(value: Variant, act: int, known_feature_ids: Array) -> Dictionary:
	if value == null or (value is Dictionary and (value as Dictionary).is_empty()):
		return empty_act_state(act)
	if not (value is Dictionary):
		return empty_act_state(act, true)
	var raw := value as Dictionary
	if raw.keys().any(func(key): return key not in ["schema_version", "act", "entries", "quarantined"]):
		return empty_act_state(act, true)
	if not _exact_int(raw.get("schema_version"), ACT_STATE_SCHEMA_VERSION) \
			or not _exact_int(raw.get("act"), act) or not (raw.get("entries") is Dictionary):
		return empty_act_state(act, true)
	if raw.get("quarantined", false) is not bool or bool(raw.get("quarantined", false)):
		return empty_act_state(act, true)
	var normalized := empty_act_state(act)
	var entries: Dictionary = raw["entries"]
	for feature_id in entries:
		if not (feature_id is String) or feature_id not in known_feature_ids:
			return empty_act_state(act, true)
		var record := _normalize_act_record(entries[feature_id])
		if record.is_empty():
			return empty_act_state(act, true)
		normalized["entries"][feature_id] = record
	return normalized


static func checkpoint_act_state(value: Variant, act: int, feature_id: String,
		record: Dictionary, known_feature_ids: Array) -> Dictionary:
	var current := normalize_act_state(value, act, known_feature_ids)
	if bool(current.get("quarantined", false)) or feature_id not in known_feature_ids:
		return {}
	var normalized_record := _normalize_act_record(record)
	if normalized_record.is_empty():
		return {}
	var next := current.duplicate(true)
	var previous: Dictionary = next["entries"].get(feature_id, {})
	if not _valid_act_transition(previous, normalized_record):
		return {}
	next["entries"][feature_id] = normalized_record
	return next


static func act_feature_state(value: Variant, act: int, feature_id: String,
		known_feature_ids: Array) -> Dictionary:
	var normalized := normalize_act_state(value, act, known_feature_ids)
	if bool(normalized.get("quarantined", false)):
		return {"quarantined": true}
	return (normalized["entries"].get(feature_id, {}) as Dictionary).duplicate(true)


static func _normalize_act_record(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var raw := value as Dictionary
	if raw.keys().any(func(key): return key not in ACT_RECORD_KEYS):
		return {}
	var decision = raw.get("decision", "")
	var risk = raw.get("risk", "")
	var offer_count = raw.get("offer_count", 0)
	var claim_count = raw.get("claim_count", 0)
	var checkpoint_ids = raw.get("checkpoint_ids", [])
	if not (decision is String) or decision not in ACT_DECISIONS \
			or not (risk is String) or risk not in ACT_RISK_STATES \
			or not _bounded_int(offer_count, 0, 1) or not _bounded_int(claim_count, 0, 1) \
			or not (checkpoint_ids is Array) or checkpoint_ids.size() > 16:
		return {}
	var ids: Array = []
	for checkpoint_id in checkpoint_ids:
		if not (checkpoint_id is String) or checkpoint_id.is_empty() \
				or checkpoint_id.length() > 64 or ids.has(checkpoint_id):
			return {}
		ids.append(checkpoint_id)
	if decision == "" and (offer_count != 0 or risk != "" or claim_count != 0):
		return {}
	if decision == "declined" and (offer_count != 1 or risk != "" or claim_count != 0):
		return {}
	if decision == "accepted" and (offer_count != 1 or (claim_count == 1 and risk != "succeeded")):
		return {}
	if risk != "" and decision != "accepted":
		return {}
	return {
		"decision": decision,
		"offer_count": int(offer_count),
		"risk": risk,
		"claim_count": int(claim_count),
		"checkpoint_ids": ids,
	}


static func _valid_act_transition(previous: Dictionary, next: Dictionary) -> bool:
	if previous.is_empty():
		return true
	var previous_decision := str(previous.get("decision", ""))
	var next_decision := str(next.get("decision", ""))
	if previous_decision != "" and next_decision != previous_decision:
		return false
	if int(next.get("offer_count", 0)) < int(previous.get("offer_count", 0)) \
			or int(next.get("claim_count", 0)) < int(previous.get("claim_count", 0)):
		return false
	var previous_risk := str(previous.get("risk", ""))
	var next_risk := str(next.get("risk", ""))
	if previous_risk == "armed" and next_risk not in ["armed", "succeeded", "failed"]:
		return false
	if previous_risk in ["succeeded", "failed"] and next_risk != previous_risk:
		return false
	var next_checkpoints: Array = next.get("checkpoint_ids", [])
	for checkpoint_id in previous.get("checkpoint_ids", []):
		if checkpoint_id not in next_checkpoints:
			return false
	return true


static func _exact_int(value: Variant, expected: int) -> bool:
	return (value is int or value is float) and float(value) == float(expected)


static func _bounded_int(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and float(value) == floorf(float(value)) \
		and float(value) >= minimum and float(value) <= maximum
