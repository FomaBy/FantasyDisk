extends SceneTree

const Support := preload("res://tests/ultimates/presentation/sniper_presentation_test_support.gd")


func _initialize() -> void:
	var errors := Support.run_weapon("sniper_deadeye_rifle")
	if not errors.is_empty():
		for error in errors:
			push_error("Sniper deadeye rifle presentation: %s" % error)
		quit(1)
		return
	print("Sniper deadeye rifle ultimate presentation passed.")
	quit(0)
