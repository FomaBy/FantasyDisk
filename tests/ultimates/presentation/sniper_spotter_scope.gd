extends SceneTree

const Support := preload("res://tests/ultimates/presentation/sniper_presentation_test_support.gd")


func _initialize() -> void:
	var errors := Support.run_weapon("sniper_spotter_scope")
	if not errors.is_empty():
		for error in errors:
			push_error("Sniper spotter scope presentation: %s" % error)
		quit(1)
		return
	print("Sniper spotter scope ultimate presentation passed.")
	quit(0)
