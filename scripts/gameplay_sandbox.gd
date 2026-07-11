extends RefCounted

# SCRUM-976: единый контракт persisted-настроек и immutable snapshot забега.
# UI (SCRUM-1025), autosave, combat и progression читают одни и те же ключи.

const MONSTER_HP := "sandbox_monster_hp_multiplier"
const MONSTER_DAMAGE := "sandbox_monster_damage_multiplier"
const PLAYER_DAMAGE := "sandbox_player_damage_multiplier"
const PLAYER_ATTACK_SPEED := "sandbox_player_attack_speed_multiplier"
const MONSTER_ATTACK_SPEED := "sandbox_monster_attack_speed_multiplier"

const SPECS := {
	MONSTER_HP: {"min": 0.5, "max": 3.0, "step": 0.1},
	MONSTER_DAMAGE: {"min": 0.5, "max": 3.0, "step": 0.1},
	PLAYER_DAMAGE: {"min": 0.5, "max": 2.0, "step": 0.1},
	PLAYER_ATTACK_SPEED: {"min": 0.5, "max": 2.0, "step": 0.1},
	MONSTER_ATTACK_SPEED: {"min": 0.5, "max": 3.0, "step": 0.1},
}


static func keys() -> Array:
	return SPECS.keys()


static func neutral_snapshot() -> Dictionary:
	var snapshot := {}
	for key in SPECS:
		snapshot[key] = 1.0
	return snapshot


static func normalized_value(key: String, value) -> float:
	var spec: Dictionary = SPECS.get(key, {"min": 1.0, "max": 1.0, "step": 0.1})
	var minimum := float(spec["min"])
	var maximum := float(spec["max"])
	var step := float(spec["step"])
	var numeric := float(value) if value is float or value is int else 1.0
	if not is_finite(numeric):
		numeric = 1.0
	numeric = clampf(numeric, minimum, maximum)
	# Настройки хранятся на той же сетке, которую показывает UI; это исключает
	# float-drift между клавиатурой, геймпадом, autosave и runtime.
	numeric = minimum + roundf((numeric - minimum) / step) * step
	return snappedf(clampf(numeric, minimum, maximum), step)


static func snapshot_from_settings(settings: Dictionary) -> Dictionary:
	var snapshot := {}
	for key in SPECS:
		snapshot[key] = normalized_value(key, settings.get(key, 1.0))
	return snapshot


static func write_snapshot_to_settings(settings: Dictionary, snapshot: Dictionary) -> Dictionary:
	var normalized := snapshot_from_settings(snapshot)
	for key in SPECS:
		settings[key] = normalized[key]
	return settings


static func set_multiplier(settings: Dictionary, key: String, value) -> float:
	if not SPECS.has(key):
		return 1.0
	var normalized := normalized_value(key, value)
	settings[key] = normalized
	return normalized


static func reset_settings(settings: Dictionary) -> Dictionary:
	return write_snapshot_to_settings(settings, neutral_snapshot())


static func is_neutral(snapshot: Dictionary) -> bool:
	var normalized := snapshot_from_settings(snapshot)
	for key in SPECS:
		if not is_equal_approx(float(normalized[key]), 1.0):
			return false
	return true


static func run_metadata(snapshot: Dictionary) -> Dictionary:
	var normalized := snapshot_from_settings(snapshot)
	var custom := not is_neutral(normalized)
	return {
		"mode": "custom" if custom else "neutral",
		"custom": custom,
		"progression_eligible": not custom,
		"achievements_eligible": not custom,
		"release_balance_evidence_eligible": not custom,
		"snapshot": normalized.duplicate(true),
		"multipliers": normalized,
	}
