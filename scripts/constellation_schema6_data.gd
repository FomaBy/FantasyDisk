class_name ConstellationSchema6Data
extends RefCounted

const MANIFEST_PATH := "res://data/meta/constellation_schema6.json"
const EXPECTED_SCHEMA := 6
const EXPECTED_CLASS_COUNT := 17
const EXPECTED_CLASS_NODE_COUNT := 357
const EXPECTED_GUILD_NODE_COUNT := 25
const EXPECTED_RUNTIME_NODE_COUNT := 382
const EXPECTED_MECHANIC_COUNT := 51

static var _manifest_cache: Dictionary = {}
static var _classes_by_id_cache: Dictionary = {}
static var _nodes_by_id_cache: Dictionary = {}
static var _mechanics_by_id_cache: Dictionary = {}


static func manifest() -> Dictionary:
	if not _manifest_cache.is_empty():
		return _manifest_cache
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		push_error("SCRUM-1068 cannot open production manifest: %s" % MANIFEST_PATH)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("SCRUM-1068 production manifest is not a JSON object.")
		return {}
	_manifest_cache = (parsed as Dictionary).duplicate(true)
	if int(_manifest_cache.get("runtime_schema_version", 0)) != EXPECTED_SCHEMA:
		push_error("SCRUM-1068 production manifest schema mismatch.")
		_manifest_cache.clear()
		return {}
	_build_indexes()
	if (
		_classes_by_id_cache.size() != EXPECTED_CLASS_COUNT
		or _nodes_by_id_cache.size() != EXPECTED_CLASS_NODE_COUNT
		or _mechanics_by_id_cache.size() != EXPECTED_MECHANIC_COUNT
	):
		push_error(
			"SCRUM-1068 production manifest index mismatch: classes=%d nodes=%d mechanics=%d."
			% [_classes_by_id_cache.size(), _nodes_by_id_cache.size(), _mechanics_by_id_cache.size()]
		)
		_manifest_cache.clear()
		_classes_by_id_cache.clear()
		_nodes_by_id_cache.clear()
		_mechanics_by_id_cache.clear()
		return {}
	return _manifest_cache


static func classes_by_id() -> Dictionary:
	manifest()
	return _classes_by_id_cache


static func class_entry(class_id: String) -> Dictionary:
	return classes_by_id().get(class_id, {})


static func node(node_id: String) -> Dictionary:
	manifest()
	return _nodes_by_id_cache.get(node_id, {})


static func mechanic(mechanic_id: String) -> Dictionary:
	manifest()
	return _mechanics_by_id_cache.get(mechanic_id, {})


static func all_nodes_by_id() -> Dictionary:
	manifest()
	return _nodes_by_id_cache


static func all_mechanics_by_id() -> Dictionary:
	manifest()
	return _mechanics_by_id_cache


static func clear_cache_for_tests() -> void:
	_manifest_cache.clear()
	_classes_by_id_cache.clear()
	_nodes_by_id_cache.clear()
	_mechanics_by_id_cache.clear()


static func _build_indexes() -> void:
	_classes_by_id_cache.clear()
	_nodes_by_id_cache.clear()
	_mechanics_by_id_cache.clear()
	for raw_class in _manifest_cache.get("classes", []):
		if not raw_class is Dictionary:
			continue
		var class_entry_value := raw_class as Dictionary
		var class_id := str(class_entry_value.get("class_id", ""))
		_classes_by_id_cache[class_id] = class_entry_value
		_index_node(class_entry_value.get("core", {}))
		for hidden in class_entry_value.get("hidden", []):
			_index_node(hidden)
		for raw_branch in class_entry_value.get("weapon_branches", []):
			if not raw_branch is Dictionary:
				continue
			for branch_node in (raw_branch as Dictionary).get("nodes", []):
				_index_node(branch_node)


static func _index_node(raw_node) -> void:
	if not raw_node is Dictionary:
		return
	var node_value := raw_node as Dictionary
	var node_id := str(node_value.get("node_id", node_value.get("id", "")))
	if node_id == "":
		return
	_nodes_by_id_cache[node_id] = node_value
	if str(node_value.get("role", "")) != "weapon_final":
		return
	var mechanic_id := str(node_value.get("mechanic_id", ""))
	if mechanic_id != "":
		_mechanics_by_id_cache[mechanic_id] = node_value
