extends SceneTree

## FAN-2606 — live 1080p capture of the runtime hero sniper walk loops.
## Draws the shipped SpriteFrames through AnimatedSprite2D at the real combat
## presentation scale (player.gd BASE_SPRITE_SCALE x Player.tscn camera zoom),
## one row per direction, one column per walk frame, so the loop itself is
## reviewable and not just the middle frame the FAN-2518 gallery freezes.
## Needs a real renderer: --headless uses the dummy driver and cannot screenshot.
## After checking out a revision that changed the frames, run an import pass
## first (Godot --headless --path . --import --quit) or the capture silently
## renders the stale import cache instead of the checked-out PNGs.
## Run: Godot --path . --script res://tools/capture_fan2606_sniper_walk.gd
## Output: build/qa/fan2606_sniper/sniper_walk_1920x1080_page<n>.png

const FRAMES_PATH := "res://assets/sprites/characters/sniper_spriteframes.tres"
const OUT_DIR := "res://build/qa/fan2606_sniper"
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const DIRECTIONS := [
	"south", "south_east", "east", "north_east",
	"north", "north_west", "west", "south_west",
]
const FRAME_COUNT := 6
const ROWS_PER_PAGE := 4
# player.gd PLAYER_COMBAT_VISUAL_SCALE 0.64 x Player.tscn Camera2D zoom 1.12.
const LIVE_SCALE := 0.7168
# Visible art occupies y 235..479 of the 512 px runtime canvas; lift the sprite
# so that band, not the padded canvas, is centred in its cell.
const ART_CENTRE_OFFSET := 101.0
const CELL := Vector2(300.0, 250.0)
const ORIGIN := Vector2(120.0, 30.0)


func _initialize() -> void:
	var frames := load(FRAMES_PATH) as SpriteFrames
	if frames == null:
		push_error("capture_fan2606_sniper_walk: cannot load %s" % FRAMES_PATH)
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		push_error("capture_fan2606_sniper_walk: needs a real renderer, run without --headless")
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var page_count := int(ceil(DIRECTIONS.size() / float(ROWS_PER_PAGE)))
	for page in page_count:
		if not await _capture_page(frames, page):
			quit(1)
			return
	quit(0)


func _capture_page(frames: SpriteFrames, page: int) -> bool:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var background := ColorRect.new()
	background.color = Color(0.10, 0.09, 0.12)
	background.size = Vector2(VIEWPORT_SIZE)
	viewport.add_child(background)

	for row in ROWS_PER_PAGE:
		var index := page * ROWS_PER_PAGE + row
		if index >= DIRECTIONS.size():
			break
		var direction := str(DIRECTIONS[index])
		var centre_y := ORIGIN.y + row * CELL.y + CELL.y * 0.5

		var label := Label.new()
		label.text = direction
		label.add_theme_font_size_override("font_size", 16)
		label.position = Vector2(10.0, centre_y)
		viewport.add_child(label)

		for column in FRAME_COUNT:
			var sprite := AnimatedSprite2D.new()
			sprite.sprite_frames = frames
			sprite.animation = "walk_%s" % direction
			sprite.scale = Vector2(LIVE_SCALE, LIVE_SCALE)
			sprite.position = Vector2(
				ORIGIN.x + column * CELL.x + CELL.x * 0.5,
				centre_y - ART_CENTRE_OFFSET * LIVE_SCALE)
			viewport.add_child(sprite)
			sprite.play(sprite.animation)
			sprite.stop()
			sprite.frame = column

	await RenderingServer.frame_post_draw
	var path := "%s/sniper_walk_%dx%d_page%d.png" % [
		OUT_DIR, VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, page + 1]
	var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	viewport.queue_free()
	if error != OK:
		push_error("capture_fan2606_sniper_walk: save failed (%d) for %s" % [error, path])
		return false
	print("captured: ", path)
	return true
