class_name WeaponUltimateResolver
extends RefCounted

## Pure selection/migration policy. No Player or ProgressionData dependency is
## allowed here: the caller supplies both the canonical pairs and the exact
## legacy class config that must remain behaviorally unchanged.

const SOURCE_WEAPON_PROFILE := "weapon_profile"
const SOURCE_LEGACY_CLASS_FALLBACK := "legacy_class_fallback"
const SOURCE_INVALID_PAIR := "invalid_pair"
const SOURCE_UNAVAILABLE := "unavailable"
const Schema := preload("res://scripts/ultimates/schema/weapon_ultimate_schema.gd")


static func profile_key(class_id: String, weapon_id: String) -> String:
	return Schema.profile_key(class_id, weapon_id)


static func select_catalog_profile(
	profiles_by_key: Dictionary,
	class_id: String,
	weapon_id: String
) -> Dictionary:
	var raw = profiles_by_key.get(profile_key(class_id, weapon_id))
	if not raw is Dictionary:
		return {}
	return (raw as Dictionary).duplicate(true)


static func resolution_source(
	profiles_by_key: Dictionary,
	canonical_pairs: Dictionary,
	class_id: String,
	weapon_id: String,
	allow_legacy_fallback := true
) -> String:
	var key := profile_key(class_id, weapon_id)
	if not canonical_pairs.has(key):
		return SOURCE_INVALID_PAIR
	var profile := select_catalog_profile(profiles_by_key, class_id, weapon_id)
	if str(profile.get("implementation_state", "")) == "ready":
		return SOURCE_WEAPON_PROFILE
	if allow_legacy_fallback:
		return SOURCE_LEGACY_CLASS_FALLBACK
	return SOURCE_UNAVAILABLE


static func resolve_executable(
	profiles_by_key: Dictionary,
	canonical_pairs: Dictionary,
	class_id: String,
	weapon_id: String,
	legacy_class_fallback: Dictionary,
	allow_legacy_fallback := true
) -> Dictionary:
	var source := resolution_source(
		profiles_by_key,
		canonical_pairs,
		class_id,
		weapon_id,
		allow_legacy_fallback
	)
	if source == SOURCE_WEAPON_PROFILE:
		return select_catalog_profile(profiles_by_key, class_id, weapon_id)
	if source == SOURCE_LEGACY_CLASS_FALLBACK:
		return legacy_class_fallback.duplicate(true)
	return {}
