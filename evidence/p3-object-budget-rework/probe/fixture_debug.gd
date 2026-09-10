extends SceneTree
const DiscoveryScript := preload("res://scripts/ultimates/registry/weapon_ultimate_package_discovery.gd")
func _initialize() -> void:
	var d = DiscoveryScript.new("user://p3_residency_fixture/data", "user://p3_residency_fixture/executors")
	var base := {"identity": {"profile_id": "fixture_profile"}, "executor": {"executor_id": "fixture_exec"}}
	d.discover({"knight|sword": base}, true)
	print("ERRORS: ", d.validation_errors())
	print("PAIRS: ", d.pair_keys())
	quit(0)
