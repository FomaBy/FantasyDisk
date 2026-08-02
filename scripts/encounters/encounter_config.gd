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
const CONTRACT := "encounter-beats-v1"
const FEATURE_TYPE := "encounter_feature"
const FEATURE_ROOT := "res://data/encounters/features"
const KNOWN_CAPABILITIES := ["primary_beat", "spawn_plan", "act_state", "quota_exclusion"]
const FEATURE_BASE := preload("res://scripts/encounters/encounter_feature.gd")

# Соль выбора одного primary-бита среди eligible-кандидатов. Микшируется с
# node seed через game.node_aspect_rng — отдельный от game.rng генератор.
const PRIMARY_PICK_SALT := 0x2B1E5C9D

static var _catalog_cache: Dictionary = {}
static var _catalog_loaded := false
static var _features_cache: Array = []
static var _features_loaded := false
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
	if not _exact_version(data.get("schema_version")) or str(data.get("contract", "")) != CONTRACT \
			or not (data.get("enabled") is bool) or not (data.get("beats") is Array) \
			or not (data.get("feature_roots", []) is Array):
		push_error("EncounterConfig: несовместимая schema_version=%s (ожидалась %d)" % [
			str(data.get("schema_version", "?")), CONTRACT_VERSION])
		return _empty_catalog()
	return data.duplicate(true)


static func _empty_catalog() -> Dictionary:
	return {"schema_version": CONTRACT_VERSION, "contract": CONTRACT, "enabled": false,
		"feature_roots": [], "beats": []}


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


# Все валидные определения, включая per-feature default-off записи.
static func all_features() -> Array:
	if _features_loaded:
		return _features_cache.duplicate(true)
	var raw_entries = catalog().get("beats", [])
	if not (raw_entries is Array):
		return []
	var entries: Array = (raw_entries as Array).duplicate(true)
	entries.append_array(_external_features(catalog().get("feature_roots", [])))
	_features_cache = _validated_feature_definitions(entries)
	_features_loaded = true
	return _features_cache.duplicate(true)


static func enabled_features() -> Array:
	return all_features().filter(func(entry): return bool(entry.get("enabled", false)))


# Backward-compatible name for callers/tests built on the original catalog.
static func all_beats() -> Array:
	return all_features()


# Primary-биты (кандидаты на единственный основной бит боя), отсортированы по id.
static func primary_beats() -> Array:
	var result: Array = []
	for beat in enabled_features():
		if bool(beat.get("primary", false)) and (beat.get("capabilities", []) as Array).has("primary_beat"):
			result.append(beat)
	return result


static func features_with_capability(capability: String) -> Array:
	if capability not in KNOWN_CAPABILITIES:
		return []
	return enabled_features().filter(func(entry): return (entry.get("capabilities", []) as Array).has(capability))


static func feature_ids() -> Array:
	return all_features().map(func(entry): return str(entry.get("id", "")))


static func empty_act_state(act: int) -> Dictionary:
	return FEATURE_BASE.empty_act_state(act)


static func normalize_act_state(value: Variant, act: int) -> Dictionary:
	return FEATURE_BASE.normalize_act_state(value, act, feature_ids())


static func checkpoint_act_state(value: Variant, act: int, feature_id: String,
		record: Dictionary) -> Dictionary:
	return FEATURE_BASE.checkpoint_act_state(value, act, feature_id, record, feature_ids())


static func act_feature_state(value: Variant, act: int, feature_id: String) -> Dictionary:
	return FEATURE_BASE.act_feature_state(value, act, feature_id, feature_ids())


static func _validated_feature_definitions(entries: Array) -> Array:
	var duplicate_counts := {}
	for entry in entries:
		if entry is Dictionary and entry.get("id") is String and not str(entry.get("id")).is_empty():
			var feature_id := str(entry.get("id"))
			duplicate_counts[feature_id] = int(duplicate_counts.get(feature_id, 0)) + 1
	var result: Array = []
	for entry in entries:
		var normalized := _normalize_feature_definition(entry)
		if normalized.is_empty() or int(duplicate_counts.get(normalized.get("id", ""), 0)) != 1:
			continue
		result.append(normalized)
	result.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))
	return result


static func _normalize_feature_definition(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var entry := value as Dictionary
	var feature_id = entry.get("id")
	var script_path = entry.get("script")
	if not _exact_version(entry.get("schema_version")) or entry.get("type") != FEATURE_TYPE \
			or not (entry.get("enabled") is bool) or not (entry.get("primary", false) is bool) \
			or not (feature_id is String) or not _valid_feature_id(feature_id) \
			or not (script_path is String) or not _valid_feature_script_path(script_path):
		return {}
	var capabilities = entry.get("capabilities", [])
	if not (capabilities is Array):
		return {}
	var seen := {}
	for capability in capabilities:
		if not (capability is String) or capability not in KNOWN_CAPABILITIES or seen.has(capability):
			return {}
		seen[capability] = true
	if bool(entry.get("primary", false)) != capabilities.has("primary_beat"):
		return {}
	return entry.duplicate(true)


static func _valid_feature_id(value: String) -> bool:
	if value.is_empty() or value.length() > 64 or value != value.to_lower():
		return false
	for character in value:
		if character not in "abcdefghijklmnopqrstuvwxyz0123456789_":
			return false
	return true


static func _valid_feature_script_path(path: String) -> bool:
	return path.begins_with("res://scripts/encounters/features/") and path.ends_with(".gd") \
		and not path.contains("..") and ResourceLoader.exists(path)


static func _exact_version(value: Variant) -> bool:
	return (value is int or value is float) and float(value) == float(CONTRACT_VERSION)


static func _external_features(roots: Variant) -> Array:
	var result: Array = []
	if not (roots is Array):
		return result
	var paths: Array[String] = []
	for root in roots:
		if root is String and (root == FEATURE_ROOT or root.begins_with(FEATURE_ROOT + "/")) \
				and not root.contains(".."):
			_collect_feature_files(root, paths)
	paths.sort()
	for path in paths:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed is Dictionary:
			result.append(parsed)
	return result


static func _collect_feature_files(path: String, result: Array[String]) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var files := Array(DirAccess.get_files_at(path))
	files.sort()
	for filename in files:
		if str(filename).ends_with(".feature.json"):
			result.append(path.path_join(str(filename)))
	var directories := Array(DirAccess.get_directories_at(path))
	directories.sort()
	for directory in directories:
		_collect_feature_files(path.path_join(str(directory)), result)


static func _validated_feature_definitions_for_tests(entries: Array) -> Array:
	return _validated_feature_definitions(entries)


# Тестовый хук: сбросить кэш каталога (например, после подмены enabled override).
static func _reset_cache_for_tests() -> void:
	_catalog_cache = {}
	_catalog_loaded = false
	_features_cache = []
	_features_loaded = false


# Тестовый хук: подменить каталог в памяти процесса (фикстура discovery). Нужен,
# чтобы проверять сортировку на каталоге из нескольких битов, не трогая прод-данные
# и правило «ровно один primary-бит». Снимается через _reset_cache_for_tests().
static func _set_catalog_for_tests(data: Dictionary) -> void:
	_catalog_cache = data.duplicate(true)
	_catalog_loaded = true
	_features_cache = []
	_features_loaded = false
