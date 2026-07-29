extends SceneTree

const Support := preload("res://tests/ultimates/presentation/sniper_presentation_test_support.gd")


func _initialize() -> void:
	var errors := Support.run_weapon("sniper_shatter_rounds")
	if not errors.is_empty():
		for error in errors:
			push_error("Sniper shatter rounds presentation: %s" % error)
		quit(1)
		return
	print("Sniper shatter rounds ultimate presentation passed.")
	quit(0)
