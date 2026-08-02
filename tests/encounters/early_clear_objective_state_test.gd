extends SceneTree

const OBJECTIVE_STATE := preload("res://scripts/encounters/features/early_clear/encounter_objective_state.gd")
const REWARDS := preload("res://scripts/encounters/features/early_clear/early_clear_rewards.gd")

var errors: Array = []


func _initialize() -> void:
	_check_objective_gates()
	_check_capped_rewards()
	if not errors.is_empty():
		for error in errors:
			push_error("early-clear-objective: %s" % str(error))
		quit(1)
		return
	print("FAN-1454 early-clear objective state test passed.")
	quit(0)


func _check_objective_gates() -> void:
	var state = OBJECTIVE_STATE.new()
	state.configure(30.0, 12, true)
	state.record_kills(12)
	_expect(not state.is_ready(), "quota must not clear before minimum elapsed")
	state.advance(30.0)
	_expect(not state.is_ready(), "living mandatory captain must block early clear")
	state.mark_captain_complete()
	_expect(state.is_ready(), "quota plus captain after minimum elapsed must clear")


func _check_capped_rewards() -> void:
	var config: Dictionary = REWARDS.config()
	_expect(int(config.get("schema_version", 0)) == 1, "reward config schema must be 1")
	_expect(not bool(config.get("reward_carrier_required", true)), "reward carrier must remain optional")
	var bonus: Dictionary = REWARDS.performance_bonus(999)
	_expect(int(bonus.get("xp", -1)) == 12, "XP performance reward must cap at 12")
	_expect(int(bonus.get("gold", -1)) == 8, "gold performance reward must cap at 8")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
