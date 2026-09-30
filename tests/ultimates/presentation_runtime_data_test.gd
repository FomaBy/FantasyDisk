extends SceneTree

## FAN-3985: the runtime presentation documents are the authored records.
##
## `data/ultimates/presentation/<class>.json` is what the exported game reads;
## `docs/design/references/weapon_ultimates/<class>/manifest.json` is what the
## class packages author and certify. This gate reads both through Godot and
## fails when any runtime record differs from its authored record, when a
## class or weapon is missing on either side, or when the bridge resolves a
## record that does not come from the runtime document.
##
## Run:
## python3 tools/godot_gate.py --headless --path . \
##   --script res://tests/ultimates/presentation_runtime_data_test.gd

const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Manifest := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_manifest.gd")
const DirectionContract := preload("res://scripts/ultimates/presentation/ultimate_visual_direction_contract.gd")

const RUNTIME_FIELDS: Array[String] = [
	"weapon_id", "scene_path", "timing_seconds", "performance", "pivot", "presence", "identity", "quality",
]
const EXPECTED_CLASSES := 17
const EXPECTED_PAIRS := 51


func _initialize() -> void:
	var errors: Array[String] = []
	var registry = Registry.new(PD.WEAPONS_BY_CLASS)
	_check(registry.is_valid(), "registry must be valid", errors)
	var authored_classes: Array[String] = DirectionContract.class_ids()
	var runtime_classes := _runtime_class_ids()
	_check(authored_classes.size() == EXPECTED_CLASSES, "17 authored class manifests expected, got %d" % authored_classes.size(), errors)
	_check(runtime_classes == authored_classes, "runtime documents %s must mirror authored classes %s" % [runtime_classes, authored_classes], errors)

	var pairs := 0
	for class_id in authored_classes:
		var authored: Dictionary = DirectionContract.load_manifest(class_id)
		var runtime: Dictionary = Manifest.class_document(class_id)
		_check(not authored.is_empty(), "%s: authored manifest must load" % class_id, errors)
		_check(not runtime.is_empty(), "%s: runtime document must load" % class_id, errors)
		if authored.is_empty() or runtime.is_empty():
			continue
		_check(
			str(runtime.get("generated_from", "")) == "docs/design/references/weapon_ultimates/%s/manifest.json" % class_id,
			"%s: runtime document must name its authored source" % class_id, errors
		)
		var authored_weapons := _weapons_by_id(authored)
		var runtime_weapons := _weapons_by_id(runtime)
		_check(
			authored_weapons.keys() == runtime_weapons.keys(),
			"%s: runtime weapons %s must mirror authored weapons %s" % [class_id, runtime_weapons.keys(), authored_weapons.keys()],
			errors
		)
		for weapon_id in authored_weapons.keys():
			pairs += 1
			var source: Dictionary = authored_weapons[weapon_id]
			var exported: Dictionary = runtime_weapons.get(weapon_id, {})
			for field in RUNTIME_FIELDS:
				if source.has(field):
					var authored_value: Variant = source[field]
					if field == "scene_path":
						# The generator normalises the authored path to `res://`.
						authored_value = _resource_path(str(authored_value))
					_check(
						exported.has(field) and _same(exported[field], authored_value),
						"%s/%s: runtime %s must equal the authored record" % [class_id, weapon_id, field], errors
					)
				else:
					_check(not exported.has(field), "%s/%s: runtime %s has no authored source" % [class_id, weapon_id, field], errors)
			for field in exported.keys():
				_check(RUNTIME_FIELDS.has(str(field)), "%s/%s: non-runtime field %s leaked into the export" % [class_id, weapon_id, field], errors)
			# The bridge resolves exactly the authored scene for the pair.
			var record: Dictionary = Manifest.class_weapon_record(class_id, str(weapon_id))
			_check(
				str(record.get("scene_path", "")) == _resource_path(str(source.get("scene_path", ""))),
				"%s/%s: bridge scene %s must be the authored scene %s" % [class_id, weapon_id, record.get("scene_path", ""), source.get("scene_path", "")],
				errors
			)
			_check(
				registry.resolution_source(class_id, str(weapon_id)) == "weapon_profile",
				"%s/%s: editor registry must resolve the weapon profile" % [class_id, weapon_id], errors
			)
	_check(pairs == EXPECTED_PAIRS, "51 pairs expected, got %d" % pairs, errors)
	_report(errors)


func _runtime_class_ids() -> Array[String]:
	var ids: Array[String] = []
	for name in DirAccess.get_files_at(Manifest.PRESENTATION_ROOT):
		if str(name).ends_with(".json"):
			ids.append(str(name).trim_suffix(".json"))
	ids.sort()
	return ids


static func _resource_path(path: String) -> String:
	return path if path.begins_with("res://") or path.is_empty() else "res://%s" % path


static func _weapons_by_id(document: Dictionary) -> Dictionary:
	var result := {}
	for raw_weapon in document.get("weapons", []) as Array:
		if raw_weapon is Dictionary:
			result[str((raw_weapon as Dictionary).get("weapon_id", ""))] = raw_weapon
	return result


## Deep equality that treats JSON ints and floats alike (both sides parse from JSON).
static func _same(left: Variant, right: Variant) -> bool:
	if left is Dictionary and right is Dictionary:
		if (left as Dictionary).keys() != (right as Dictionary).keys():
			return false
		for key in (left as Dictionary).keys():
			if not _same(left[key], right[key]):
				return false
		return true
	if left is Array and right is Array:
		if (left as Array).size() != (right as Array).size():
			return false
		for index in range((left as Array).size()):
			if not _same(left[index], right[index]):
				return false
		return true
	if (left is int or left is float) and (right is int or right is float) and not (left is bool or right is bool):
		return is_equal_approx(float(left), float(right))
	return typeof(left) == typeof(right) and left == right


func _check(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)


func _report(errors: Array[String]) -> void:
	if errors.is_empty():
		print("Presentation runtime data test passed: 17 runtime documents mirror the authored class manifests for all 51 pairs.")
		quit(0)
		return
	for error in errors:
		push_error("Presentation runtime data test: %s" % error)
	push_error("Presentation runtime data test: %d errors." % errors.size())
	quit(1)
