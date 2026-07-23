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

# Терминальные статусы outcome.
const STATUS_COMPLETED := "completed"
const STATUS_FAILED := "failed"
const STATUS_ABORTED := "aborted"


func api_version() -> int:
	return API_VERSION


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
