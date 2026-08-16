extends RefCounted

const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")
const PROFILE_ID := "weapon_ultimate.profile.fixture_class.fixture_weapon"
const EXECUTOR_ID := "weapon_ultimate.executor.fixture_class.fixture_weapon"

static func parameter_contract() -> Dictionary:
	return {
		"radius": {"type": "number", "minimum": 0.0},
		"damage": {"type": "number", "minimum": 0.0},
		"target_limit": {"type": "integer", "minimum": 0},
	}

static func execute(activation) -> float:
	return Library.execute("burst", activation)
