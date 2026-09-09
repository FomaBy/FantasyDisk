extends RefCounted

## Production boundary for the two persisted ultimate-presentation preferences.
## The root metadata value is the live snapshot consumers must read; changing a
## settings Dictionary alone does not update a running scene tree.

const REDUCED_MOTION_KEY := "ultimate_reduced_motion"
const PHOTOSENSITIVITY_SAFE_KEY := "ultimate_photosensitivity_safe"
const ROOT_METADATA_KEY := "ultimate_accessibility_settings"


static func default_snapshot() -> Dictionary:
	return {
		REDUCED_MOTION_KEY: false,
		PHOTOSENSITIVITY_SAFE_KEY: false,
	}


static func snapshot_from_settings(settings: Dictionary) -> Dictionary:
	var snapshot := default_snapshot()
	for key in snapshot:
		snapshot[key] = bool(settings.get(key, snapshot[key]))
	return snapshot


static func apply_settings(root: Node, settings: Dictionary) -> Dictionary:
	return apply_snapshot(root, snapshot_from_settings(settings))


static func apply_snapshot(root: Node, snapshot: Dictionary) -> Dictionary:
	var normalized := snapshot_from_settings(snapshot)
	if root != null:
		root.set_meta(ROOT_METADATA_KEY, normalized.duplicate(true))
	return normalized


static func read_snapshot(root: Node) -> Dictionary:
	if root == null:
		return default_snapshot()
	var stored = root.get_meta(ROOT_METADATA_KEY, {})
	return snapshot_from_settings(stored if stored is Dictionary else {})


static func write_applied_snapshot_to_settings(settings: Dictionary, root: Node) -> Dictionary:
	var snapshot := read_snapshot(root)
	for key in snapshot:
		settings[key] = snapshot[key]
	return settings
