extends "res://tests/runtime_smoke_test.gd"

const CombatSmokeScenarios := preload("res://tests/combat/smoke_scenarios.gd")


func _initialize() -> void:
	var scenarios := CombatSmokeScenarios.new(self, EXPECTED_ARENA_CENTER)
	var fixture := await scenarios.create_combat_fixture()
	if fixture.is_empty():
		return
	if not await scenarios.run_projectile_scenario(fixture):
		return
	await scenarios.dispose_combat_fixture(fixture)
	_finish("Combat smoke projectile suite passed.")
