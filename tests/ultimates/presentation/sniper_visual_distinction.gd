extends SceneTree

const Support := preload("res://tests/ultimates/presentation/sniper_presentation_test_support.gd")


func _initialize() -> void:
	var errors := Support.run_visual_distinction()
	if not errors.is_empty():
		for error in errors:
			push_error("Sniper visual distinction: %s" % error)
		quit(1)
		return
	print("Sniper ultimate visual distinction passed.")
	quit(0)
