extends SceneTree

## FAN-2985 evidence: the three ultimates of a class cast live through the real
## Player and captured at the same three moments each. The sheet shows what the
## player actually sees, so a generic controller ring drawn over the authored
## scenes would appear in every tile of every class.
##
## Headless runs skip rendering instead of writing empty sheets. Run windowed:
## python3 tools/godot_gate.py --path . \
##   --script res://tests/ultimates/presentation/fan2985_live_ultimate_capture.gd

const PlayerScene := preload("res://scenes/Player.tscn")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_IDS: Array[String] = ["berserk", "sniper", "soldier"]
const VIEW := Vector2i(1152, 648)
const TILE := Vector2i(384, 216)
## Windup, release and active, in frames of a 60 fps windowed run.
const MOMENT_FRAMES: Array[int] = [24, 66, 132]
const PREY_OFFSETS: Array[Vector2] = [
	Vector2(150, 0), Vector2(-150, 40), Vector2(0, 150),
	Vector2(260, -90), Vector2(-260, -60), Vector2(60, -190),
]
const OUTPUT_DIR := "res://tmp"


class Prey extends Node2D:
	var health := 100000.0
	var max_health := 100000.0

	func take_damage(_amount: float, _feedback := {}) -> void:
		pass

	func apply_knockback(_impulse: Vector2) -> void:
		pass


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("FAN-2985 live ultimate capture skipped (headless); run windowed for PNGs.")
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	# `Player._vfx_parent` falls back to the Player's own parent unless the
	# current scene is a Node2D, which is how every effect of a cast lands
	# inside the capture viewport instead of the main window.
	var stage := Node.new()
	root.add_child(stage)
	current_scene = stage
	await process_frame
	for class_id in CLASS_IDS:
		var rows: Array = []
		for raw_weapon_id in (PD.WEAPONS_BY_CLASS[class_id] as Dictionary).keys():
			rows.append(await _cast(class_id, str(raw_weapon_id)))
		var path := "%s/fan2985_%s_live_ultimates.png" % [OUTPUT_DIR, class_id]
		if not _save_sheet(rows, path):
			quit(1)
			return
		print("FAN-2985 live ultimate capture saved: %s" % path)
	quit(0)


## One live cast in its own world, so a sheet cannot pick up the leftovers of a
## neighbouring cast. Each shot carries its own caption.
func _cast(class_id: String, weapon_id: String) -> Array:
	var viewport := SubViewport.new()
	viewport.size = VIEW
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node2D.new()
	viewport.add_child(world)
	var caption := Label.new()
	caption.add_theme_font_size_override("font_size", 44)
	var overlay := CanvasLayer.new()
	overlay.add_child(caption)
	world.add_child(overlay)
	var player := PlayerScene.instantiate() as Node2D
	world.add_child(player)
	await process_frame
	player.call("configure_character", class_id, weapon_id)
	player.global_position = Vector2(VIEW) * 0.5
	await process_frame
	for offset in PREY_OFFSETS:
		var prey := Prey.new()
		prey.global_position = player.global_position + offset
		prey.add_to_group("enemies")
		world.add_child(prey)
	await process_frame
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	if not bool(player.call("activate_ultimate")):
		push_error("FAN-2985 capture: %s/%s did not activate" % [class_id, weapon_id])
	var shots: Array = []
	var frame := 0
	for moment in MOMENT_FRAMES:
		while frame < moment:
			await process_frame
			frame += 1
		caption.text = "%s / %s   t=%.2fs" % [class_id, weapon_id, float(moment) / 60.0]
		await RenderingServer.frame_post_draw
		shots.append(viewport.get_texture().get_image())
	viewport.queue_free()
	await process_frame
	return shots


func _save_sheet(rows: Array, path: String) -> bool:
	var sheet := Image.create(TILE.x * MOMENT_FRAMES.size(), TILE.y * rows.size(), false, Image.FORMAT_RGBA8)
	for row_index in rows.size():
		var shots := rows[row_index] as Array
		for column_index in shots.size():
			var shot := (shots[column_index] as Image).duplicate() as Image
			shot.convert(Image.FORMAT_RGBA8)
			shot.resize(TILE.x, TILE.y, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(
				shot,
				Rect2i(Vector2i.ZERO, TILE),
				Vector2i(column_index * TILE.x, row_index * TILE.y)
			)
	var error := sheet.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("FAN-2985 live ultimate capture failed: %s" % error_string(error))
		return false
	return true
