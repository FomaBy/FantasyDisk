class_name ProjectileVisualRegistry
extends RefCounted

## Canonical runtime reader for the accepted SCRUM-1065 projectile inventory.
## The manifest is the single data source; gameplay scripts resolve by weapon_id
## and never infer a visual from a filename or attack mode.

const MANIFEST_PATH := "res://assets/data/projectile_visual_profiles.json"
const SOURCE_MANIFEST_PATH := "res://docs/design/references/SCRUM-1065_player_projectiles/manifest.json"
const PROJECTILE_CLASSIFICATIONS := {
	"flying_projectile": true,
	"projectile_like_tracer": true,
}
const FORBIDDEN_CANONICAL_FALLBACKS := {
	"res://assets/sprites/effects/void_orb.png": true,
	"res://assets/sprites/projectiles/player_projectile_spark_64.png": true,
}

static var _loaded := false
static var _profiles_by_weapon: Dictionary = {}
static var _profiles_by_visual: Dictionary = {}
static var _inventory_by_weapon: Dictionary = {}
static var _errors: Array[String] = []


static func profile_for_weapon(weapon_id: String) -> Dictionary:
	_ensure_loaded()
	var raw = _profiles_by_weapon.get(weapon_id, {})
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


static func profile_for_visual(visual_id: String) -> Dictionary:
	_ensure_loaded()
	var raw = _profiles_by_visual.get(visual_id, {})
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


static func inventory_entry(weapon_id: String) -> Dictionary:
	_ensure_loaded()
	var raw = _inventory_by_weapon.get(weapon_id, {})
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


static func projectile_weapon_ids() -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for weapon_id in _profiles_by_weapon.keys():
		result.append(str(weapon_id))
	result.sort()
	return result


static func validation_errors() -> Array[String]:
	_ensure_loaded()
	return _errors.duplicate()


static func is_valid_profile(profile: Dictionary) -> bool:
	var path := str(profile.get("asset_path", ""))
	return (
		not str(profile.get("visual_id", "")).is_empty()
		and not path.is_empty()
		and not FORBIDDEN_CANONICAL_FALLBACKS.has(path)
		and FileAccess.file_exists(path)
		and profile.get("display_size", Vector2.ZERO) is Vector2
		and (profile.get("display_size", Vector2.ZERO) as Vector2).x > 0.0
		and (profile.get("display_size", Vector2.ZERO) as Vector2).y > 0.0
	)


static func reset_cache_for_tests() -> void:
	_loaded = false
	_profiles_by_weapon.clear()
	_profiles_by_visual.clear()
	_inventory_by_weapon.clear()
	_errors.clear()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_profiles_by_weapon.clear()
	_profiles_by_visual.clear()
	_inventory_by_weapon.clear()
	_errors.clear()
	if not FileAccess.file_exists(MANIFEST_PATH):
		_errors.append("missing manifest: %s" % MANIFEST_PATH)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:
		_errors.append("invalid manifest JSON root")
		return
	var manifest: Dictionary = parsed
	var asset_by_visual: Dictionary = {}
	for raw_asset in manifest.get("assets", []):
		if not raw_asset is Dictionary:
			_errors.append("invalid asset entry")
			continue
		var asset: Dictionary = raw_asset
		var visual_id := str(asset.get("visual_id", ""))
		if visual_id.is_empty() or asset_by_visual.has(visual_id):
			_errors.append("missing or duplicate visual_id: %s" % visual_id)
			continue
		asset_by_visual[visual_id] = asset
	for raw_entry in manifest.get("inventory", []):
		if not raw_entry is Dictionary:
			_errors.append("invalid inventory entry")
			continue
		var entry: Dictionary = raw_entry
		var weapon_id := str(entry.get("weapon_id", ""))
		if weapon_id.is_empty() or _inventory_by_weapon.has(weapon_id):
			_errors.append("missing or duplicate weapon_id: %s" % weapon_id)
			continue
		_inventory_by_weapon[weapon_id] = entry.duplicate(true)
		if not PROJECTILE_CLASSIFICATIONS.has(str(entry.get("classification", ""))):
			continue
		var visual_id := str(entry.get("projectile_visual_id", ""))
		var asset_raw = asset_by_visual.get(visual_id, {})
		if not asset_raw is Dictionary or (asset_raw as Dictionary).is_empty():
			_errors.append("%s references missing visual %s" % [weapon_id, visual_id])
			continue
		var asset: Dictionary = asset_raw
		var display_raw = asset.get("intended_runtime_display_px", [])
		if not display_raw is Array or display_raw.size() != 2:
			_errors.append("%s has invalid display size" % visual_id)
			continue
		var asset_path := str(entry.get("asset_path", asset.get("runtime_path", "")))
		if not asset_path.begins_with("res://"):
			asset_path = "res://" + asset_path
		var profile := {
			"weapon_id": weapon_id,
			"visual_id": visual_id,
			"asset_path": asset_path,
			"display_size": Vector2(float(display_raw[0]), float(display_raw[1])),
			"forward_orientation": str(asset.get("forward_orientation", "right")),
			"rotation_offset_degrees": float(asset.get("rotation_offset_degrees", 0.0)),
			"trail_palette": _palette(asset.get("trail_palette", [])),
			"impact_palette": _palette(asset.get("impact_palette", [])),
			"animation_frames": maxi(int(asset.get("animation_frames", 1)), 1),
		}
		if not is_valid_profile(profile):
			_errors.append("%s resolves invalid canonical profile %s" % [weapon_id, visual_id])
			continue
		_profiles_by_weapon[weapon_id] = profile
		_profiles_by_visual[visual_id] = profile
	var expected := int((manifest.get("contract", {}) as Dictionary).get("flying_or_projectile_like_profiles", -1))
	if _profiles_by_weapon.size() != expected:
		_errors.append("profile count %d != contract %d" % [_profiles_by_weapon.size(), expected])


static func _palette(raw) -> Array[Color]:
	var result: Array[Color] = []
	if raw is Array:
		for value in raw:
			result.append(Color.from_string(str(value), Color.WHITE))
	return result
