extends RefCounted
## EncounterConfig — загрузчик data-driven каталога боевых «битов» (beats).
##
## Контракт encounter-beats-v1 (FAN-1447). Каталог лежит в
## `res://data/encounters/beats.json` и описывает каждый бит: id, eligibility,
## окно триггера, seed salt, теги совместимости, payload, success/failure и
## metrics-теги. Модуль только читает данные детерминированно и НЕ трогает
## глобальный боевой RNG (`game.rng`).
##
## Обычные бои остаются default-off. Именованный route-slice может включить
## ограниченный набор уже принятых фич без глобальной runtime-подмены каталога.

const CONTRACT_VERSION := 1
const CATALOG_PATH := "res://data/encounters/beats.json"
const CONTRACT := "encounter-beats-v1"
const FEATURE_TYPE := "encounter_feature"
const FEATURE_ROOT := "res://data/encounters/features"
const SLICE_CONTRACT := "combat-variety-slice-v1"
const SLICE_PATHS := {
	"combat_variety_slice": "res://data/encounters/combat_variety_slice.json",
}
const SLICE_PACK_ACTIVATION_IDS := ["captain_commander", "captain_hunter"]
const KNOWN_CAPABILITIES := ["primary_beat", "spawn_plan", "act_state", "quota_exclusion"]
const FEATURE_BASE := preload("res://scripts/encounters/encounter_feature.gd")
const CAPTAIN_CATALOG := preload("res://scripts/encounters/features/captains/captain_catalog.gd")

# Соль выбора одного primary-бита среди eligible-кандидатов. Микшируется с
# node seed через game.node_aspect_rng — отдельный от game.rng генератор.
const PRIMARY_PICK_SALT := 0x2B1E5C9D

static var _catalog_cache: Dictionary = {}
static var _catalog_loaded := false
static var _features_cache: Array = []
static var _features_loaded := false
static var _slice_cache := {}
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


static func enabled_features(slice_def: Dictionary = {}) -> Array:
	if not slice_def.is_empty():
		return (slice_def.get("features", []) as Array).duplicate(true)
	return all_features().filter(func(entry): return bool(entry.get("enabled", false)))


# Backward-compatible name for callers/tests built on the original catalog.
static func all_beats() -> Array:
	return all_features()


# Primary-биты (кандидаты на единственный основной бит боя), отсортированы по id.
static func primary_beats(slice_def: Dictionary = {}) -> Array:
	var result: Array = []
	for beat in enabled_features(slice_def):
		if bool(beat.get("primary", false)) and (beat.get("capabilities", []) as Array).has("primary_beat"):
			result.append(beat)
	return result


static func features_with_capability(capability: String, slice_def: Dictionary = {}) -> Array:
	if capability not in KNOWN_CAPABILITIES:
		return []
	return enabled_features(slice_def).filter(func(entry): return (entry.get("capabilities", []) as Array).has(capability))


static func slice(slice_id: String) -> Dictionary:
	if not SLICE_PATHS.has(slice_id):
		return {}
	if _slice_cache.has(slice_id):
		return (_slice_cache[slice_id] as Dictionary).duplicate(true)
	var file := FileAccess.open(str(SLICE_PATHS[slice_id]), FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	var result := _normalize_slice(parsed, slice_id)
	if not result.is_empty():
		_slice_cache[slice_id] = result
	return result.duplicate(true)


static func slice_id_for_route_node(route_node: Dictionary) -> String:
	if str(route_node.get("type", "")) != "battle":
		return ""
	var slice_id := str(route_node.get("encounter_slice_id", ""))
	return slice_id if not slice(slice_id).is_empty() else ""


static func slice_for_game(game) -> Dictionary:
	if game == null:
		return {}
	var pending_event = game.get("pending_event_combat")
	if str(game.get("current_combat_type")) != "battle" or bool(game.get("boss_combat_active")) \
			or not (pending_event is Dictionary) or not (pending_event as Dictionary).is_empty():
		return {}
	var route_nodes = game.get("route_nodes")
	var selected = game.get("route_selected_indices")
	var stage := int(game.get("route_stage"))
	if route_nodes is Array and selected is Array and stage >= 0 and stage < route_nodes.size() \
			and stage < selected.size() and route_nodes[stage] is Array:
		var branch := int(selected[stage])
		if branch >= 0 and branch < (route_nodes[stage] as Array).size() \
				and route_nodes[stage][branch] is Dictionary:
			return slice(slice_id_for_route_node(route_nodes[stage][branch]))
	return {}


static func slice_route_position(route: Array, act: int, slice_id := "combat_variety_slice") -> Dictionary:
	var slice_def := slice(slice_id)
	if slice_def.is_empty():
		return {}
	var selector: Dictionary = slice_def.get("route_selector", {})
	var minimum := int(selector.get("min_row", 0))
	var maximum := int(selector.get("max_row", 64))
	var salt := int(selector.get("seed_salt", 0))
	var candidates: Array = []
	for row_index in range(route.size()):
		if row_index < minimum or row_index > maximum or not (route[row_index] is Array):
			continue
		for branch_index in range((route[row_index] as Array).size()):
			var node = route[row_index][branch_index]
			if node is Dictionary and str(node.get("type", "")) == "battle":
				var score := (int(node.get("seed", 0)) ^ salt ^ (act * 0x45D9F3B)) & 0x7FFFFFFF
				candidates.append({"row": row_index, "branch": branch_index, "score": score})
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a, b):
		return int(a["score"]) < int(b["score"]) if int(a["score"]) != int(b["score"]) \
			else (int(a["row"]) < int(b["row"]) if int(a["row"]) != int(b["row"]) else int(a["branch"]) < int(b["branch"])))
	return {"row": candidates[0]["row"], "branch": candidates[0]["branch"], "slice_id": slice_id}


static func slice_primary_sequence(slice_def: Dictionary, context) -> Array:
	var by_id := {}
	for feature_def in primary_beats(slice_def):
		by_id[str(feature_def.get("id", ""))] = feature_def
	var result: Array = []
	for phase in slice_def.get("primary_sequence", []):
		var feature_id := str(phase.get("feature_id", ""))
		var choices: Array = phase.get("choices", [])
		if feature_id == "" and not choices.is_empty():
			var sorted_choices := choices.duplicate()
			sorted_choices.sort()
			var rng: RandomNumberGenerator = context.aspect_rng(int(phase.get("seed_salt", 0)))
			feature_id = str(sorted_choices[rng.randi_range(0, sorted_choices.size() - 1)])
		if by_id.has(feature_id):
			result.append({"beat": (by_id[feature_id] as Dictionary).duplicate(true),
				"slice_activates_pack": bool(phase.get("slice_activates_pack", false))})
	return result


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


static func _normalize_slice(value: Variant, expected_id: String) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var data := value as Dictionary
	if not _exact_version(data.get("schema_version")) or str(data.get("contract", "")) != SLICE_CONTRACT \
			or str(data.get("id", "")) != expected_id or data.get("enabled", false) is not bool \
			or not bool(data.get("enabled", false)) or not (data.get("route_selector") is Dictionary) \
			or not (data.get("primary_sequence") is Array) or not (data.get("inline_features", []) is Array) \
			or not (data.get("feature_overrides", {}) is Dictionary):
		return {}
	var selector := data.get("route_selector") as Dictionary
	if not _exact_integer(selector.get("min_row")) or not _exact_integer(selector.get("max_row")) \
			or not _exact_integer(selector.get("seed_salt")) \
			or int(selector.get("min_row")) < 0 or int(selector.get("max_row")) < int(selector.get("min_row")):
		return {}
	var entries := all_features()
	entries.append_array(CAPTAIN_CATALOG.all_roles())
	entries.append_array((data.get("inline_features", []) as Array).duplicate(true))
	var definitions := _validated_feature_definitions(entries)
	var by_id := {}
	for feature_def in definitions:
		by_id[str(feature_def.get("id", ""))] = feature_def
	var spawn_feature_id := str(data.get("spawn_plan_feature_id", ""))
	if not by_id.has(spawn_feature_id) \
			or not ((by_id[spawn_feature_id] as Dictionary).get("capabilities", []) as Array).has("spawn_plan"):
		return {}
	var requested := [spawn_feature_id]
	for phase in data.get("primary_sequence", []):
		if not (phase is Dictionary):
			return {}
		var phase_id := str(phase.get("feature_id", ""))
		var choices = phase.get("choices", [])
		if phase_id == "" and (not (choices is Array) or choices.is_empty() \
				or not _exact_integer(phase.get("seed_salt"))):
			return {}
		if phase_id != "":
			if not by_id.has(phase_id) or not bool((by_id[phase_id] as Dictionary).get("primary", false)):
				return {}
			requested.append(phase_id)
		else:
			for choice in choices:
				if not (choice is String) or not by_id.has(choice) \
						or not bool((by_id[choice] as Dictionary).get("primary", false)):
					return {}
				requested.append(str(choice))
		if bool(phase.get("slice_activates_pack", false)) \
				and (phase_id != "" or not (choices as Array).all(
					func(id): return id in SLICE_PACK_ACTIVATION_IDS)):
			return {}
	var activated: Array = []
	for feature_id in requested:
		if feature_id == "" or not by_id.has(feature_id):
			return {}
		var feature_def: Dictionary = (by_id[feature_id] as Dictionary).duplicate(true)
		var override_value = data.get("feature_overrides", {}).get(feature_id, {})
		if not (override_value is Dictionary):
			return {}
		var overrides := override_value as Dictionary
		if overrides.keys().any(func(key): return key in ["schema_version", "id", "type", "primary", "capabilities", "script"]):
			return {}
		for key in overrides:
			feature_def[key] = overrides[key]
		# JSON preserves integral value, but returns it as float. Packs that use the
		# seed as an integer receive the same canonical value as GDScript catalogs.
		if feature_def.has("seed_salt") and _exact_integer(feature_def["seed_salt"]):
			feature_def["seed_salt"] = int(feature_def["seed_salt"])
		feature_def["enabled"] = true
		var normalized := _normalize_feature_definition(feature_def)
		if normalized.is_empty():
			return {}
		if not activated.any(func(entry): return str(entry.get("id", "")) == feature_id):
			activated.append(normalized)
	activated.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))
	var result := data.duplicate(true)
	result["features"] = activated
	return result


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


static func _exact_integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and float(value) == float(int(value))


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
	_slice_cache = {}


# Тестовый хук: подменить каталог в памяти процесса (фикстура discovery). Нужен,
# чтобы проверять сортировку на каталоге из нескольких битов, не трогая прод-данные
# и правило «ровно один primary-бит». Снимается через _reset_cache_for_tests().
static func _set_catalog_for_tests(data: Dictionary) -> void:
	_catalog_cache = data.duplicate(true)
	_catalog_loaded = true
	_features_cache = []
	_features_loaded = false
