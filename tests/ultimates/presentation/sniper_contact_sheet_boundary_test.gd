extends SceneTree

const Capture := preload("res://tests/ultimates/presentation/sniper_contact_sheet.gd")


func _initialize() -> void:
	if Capture.supports_readback("headless"):
		push_error("Sniper contact capture must not read back dummy headless textures")
		quit(1)
		return
	if not Capture.supports_readback("windowed"):
		push_error("Sniper contact capture must retain the supported-renderer path")
		quit(1)
		return
	print("sniper_contact_sheet_boundary_test: PASS")
	quit(0)
