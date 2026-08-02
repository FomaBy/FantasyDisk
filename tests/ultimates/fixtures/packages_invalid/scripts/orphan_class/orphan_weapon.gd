extends RefCounted

const PROFILE_ID := "weapon_ultimate.profile.orphan_class.orphan_weapon"
const EXECUTOR_ID := "weapon_ultimate.executor.orphan_class.orphan_weapon"

static func parameter_contract() -> Dictionary:
	return {"duration": {"type": "number", "minimum": 0.0}}

static func execute(_activation) -> float:
	return 0.0
