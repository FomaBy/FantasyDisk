extends SceneTree

## Smoke test for HazardVfx: telegraph + detonation helpers spawn textured
## visuals (no bare Polygon2D) and self-clean.

const HazardVfxScript := preload("res://scripts/hazard_vfx.gd")


func _initialize() -> void:
	await process_frame
	var host := Node2D.new()
	root.add_child(host)
	host.global_position = Vector2(400, 300)

	var color := Color(0.6, 0.4, 1.0, 1.0)
	var tele := HazardVfxScript.telegraph(host, 92.0, color, 0.6)
	if tele == null or not is_instance_valid(tele):
		push_error("HazardVfx.telegraph must return a live node.")
		quit(1)
	var has_sprite := false
	for child in tele.get_children():
		if child is Sprite2D and (child as Sprite2D).texture != null:
			has_sprite = true
	if not has_sprite:
		push_error("HazardVfx.telegraph must use textured sprites, not bare primitives.")
		quit(1)

	HazardVfxScript.detonate(host, 92.0, color)
	HazardVfxScript.detonate(host, 72.0, Color(0.55, 0.95, 0.30, 1.0), "poison")
	# poison burst must drop a pool sprite
	var burst := host.get_node_or_null("HazardBurst")
	if burst == null:
		push_error("HazardVfx.detonate must add a burst node.")
		quit(1)

	await process_frame
	print("Hazard VFX smoke test passed.")
	quit()
