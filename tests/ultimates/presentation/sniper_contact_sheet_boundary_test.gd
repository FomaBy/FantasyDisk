extends SceneTree

const Capture := preload("res://tests/ultimates/presentation/sniper_contact_sheet.gd")


func _initialize() -> void:
	if Capture.supports_readback("headless") or not Capture.supports_readback("windowed"):
		push_error("Sniper contact capture must skip dummy readback and retain windowed capture.")
		quit(1)
		return
	print("sniper_contact_sheet_boundary_test: PASS")
	quit(0)
