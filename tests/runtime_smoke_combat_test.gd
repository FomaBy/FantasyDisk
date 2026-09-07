extends "res://tests/runtime_smoke_test.gd"

const CombatSmokeScenarios := preload("res://tests/combat/smoke_scenarios.gd")


# Compatibility batch: keep the legacy aggregate invocation serialized while
# the focused leaves under tests/combat/ provide independently executable runs.
func _initialize() -> void:
	var scenarios := CombatSmokeScenarios.new(self, EXPECTED_ARENA_CENTER)
	if not await scenarios.run_serialized_combat_smoke_suite():
		return
	_finish("Runtime combat smoke suite passed.")
