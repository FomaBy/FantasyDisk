extends SceneTree
func _initialize() -> void:
	print("has_get_cached_resources=", ResourceLoader.has_method("get_cached_resources"))
	if ResourceLoader.has_method("get_cached_resources"):
		var res: Array = ResourceLoader.call("get_cached_resources")
		print("cached_resources=", res.size())
	quit(0)
