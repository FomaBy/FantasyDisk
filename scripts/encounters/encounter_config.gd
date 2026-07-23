extends RefCounted
## EncounterConfig — загрузчик data-driven каталога боевых «битов» (beats).
##
## Контракт encounter-beats-v1 (FAN-1447). Каталог лежит в
## `res://data/encounters/beats.json` и описывает каждый бит: id, eligibility,
## окно триггера, seed salt, теги совместимости, payload, success/failure и
## metrics-теги. Модуль только читает данные детерминированно и НЕ трогает
## глобальный боевой RNG (`game.rng`).
##
## Default-off: `enabled` в каталоге по умолчанию false, поэтому в проде адаптер
## CombatDirector не создаёт директора битов и бой идентичен baseline. Тесты и QA
## включают систему через `set_enabled_override(true)` — состояние живёт только в
## памяти процесса, без сети и без правки прод-данных.

const CONTRACT_VERSION := 1
const CATALOG_PATH := "res://data/encounters/beats.json"

# Соль выбора одного primary-бита среди eligible-кандидатов. Микшируется с
# node seed через game.node_aspect_rng — отдельный от game.rng генератор.
const PRIMARY_PICK_SALT := 0x2B1E5C9D

static var _catalog_cache: Dictionary = {}
static var _catalog_loaded := false
static var _enabled_override_set := false
static var _enabled_override := false


static func catalog() -> Dictionary:
	if _catalog_loaded:
		return _catalog_cache
	_catalog_loaded = true
	_catalog_cache = _load_catalog()
	return _catalog_cache


static func _load_catalog() -> Dictionary:
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		push_error("EncounterConfig: не удалось открыть каталог %s" % CATALOG_PATH)
		return _empty_catalog()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		push_error("EncounterConfig: каталог %s не является JSON-объектом" % CATALOG_PATH)
		return _empty_catalog()
	var data := parsed as Dictionary
	if int(data.get("schema_version", 0)) != CONTRACT_VERSION:
		push_error("EncounterConfig: несовместимая schema_version=%s (ожидалась %d)" % [
			str(data.get("schema_version", "?")), CONTRACT_VERSION])
		return _empty_catalog()
	return data.duplicate(true)


static func _empty_catalog() -> Dictionary:
	return {"schema_version": CONTRACT_VERSION, "enabled": false, "beats": []}


# Форсированное состояние в памяти (тест/QA). Не сохраняется и не уходит в сеть.
static func set_enabled_override(value: bool) -> void:
	_enabled_override_set = true
	_enabled_override = value


static func clear_enabled_override() -> void:
	_enabled_override_set = false
	_enabled_override = false


static func is_enabled() -> bool:
	if _enabled_override_set:
		return _enabled_override
	return bool(catalog().get("enabled", false))


# Все биты каталога, детерминированно отсортированные по id (стабильная discovery).
static func all_beats() -> Array:
	var beats: Array = []
	for entry in catalog().get("beats", []):
		if entry is Dictionary:
			beats.append((entry as Dictionary).duplicate(true))
	beats.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))
	return beats


# Primary-биты (кандидаты на единственный основной бит боя), отсортированы по id.
static func primary_beats() -> Array:
	var result: Array = []
	for beat in all_beats():
		if bool(beat.get("primary", false)):
			result.append(beat)
	return result


# Тестовый хук: сбросить кэш каталога (например, после подмены enabled override).
static func _reset_cache_for_tests() -> void:
	_catalog_cache = {}
	_catalog_loaded = false
