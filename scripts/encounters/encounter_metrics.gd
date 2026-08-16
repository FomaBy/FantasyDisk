extends RefCounted
## EncounterMetrics — локальные in-memory метрики битов (FAN-1447).
##
## Считает: offered / triggered / completed / failed / aborted и хранит per-beat
## записи с duration / damage_to_target / player_died. НИКАКОЙ сети и никакого
## feedback-pipeline: только память процесса + детерминированный QA-экспорт
## (JSON с сортировкой ключей). Для QA/тестов последний прогон боя дублируется в
## статический снапшот `last_summary`.

const API_VERSION := 1

# Снапшот последнего завершённого боевого прогона директора (для QA/тестов).
static var last_summary: Dictionary = {}

var _counters := {
	"offered": 0,
	"triggered": 0,
	"completed": 0,
	"failed": 0,
	"aborted": 0,
}
var _records: Array = []


func note_offered(_beat_id: String) -> void:
	_counters["offered"] = int(_counters["offered"]) + 1


func note_triggered(_beat_id: String) -> void:
	_counters["triggered"] = int(_counters["triggered"]) + 1


# Записать терминальный outcome и обновить счётчики по его статусу.
func record_outcome(outcome: Dictionary) -> void:
	_records.append(outcome.duplicate(true))
	var status := str(outcome.get("status", ""))
	if _counters.has(status):
		_counters[status] = int(_counters[status]) + 1


func counters() -> Dictionary:
	return _counters.duplicate(true)


func records() -> Array:
	return _records.duplicate(true)


# Детерминированный сводный словарь (стабильный порядок ключей через JSON export).
func export_summary() -> Dictionary:
	return {
		"schema_version": API_VERSION,
		"counters": _counters.duplicate(true),
		"records": _records.duplicate(true),
	}


# Детерминированная строка для QA-экспорта: sort_keys=true даёт стабильный вывод
# независимо от порядка вставки. Без сети — вызывающий сам решает, куда её деть.
func export_json() -> String:
	return JSON.stringify(export_summary(), "\t", true)
