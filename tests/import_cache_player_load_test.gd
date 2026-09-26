extends SceneTree

## The import gate's smallest real Player dependency probe.  Loading the scene
## resolves Player's texture preloads; missing `.ctex` files and parse errors
## are therefore reported before any gameplay suite starts.
const PlayerScene := preload("res://scenes/Player.tscn")


func _init() -> void:

	var player := PlayerScene.instantiate()
	player.free()
	quit()
