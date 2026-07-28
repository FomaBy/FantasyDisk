extends SceneTree


func _init() -> void:
	push_error("FAN-1701 intentional hot-cache failure probe")
	quit(1)
