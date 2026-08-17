extends SceneTree

## Live 1080p capture of a runtime hero body pack's walk loops.
## Draws the shipped SpriteFrames through AnimatedSprite2D at the real combat
## presentation scale (player.gd BASE_SPRITE_SCALE x Player.tscn camera zoom),
## one row per direction, one column per walk frame, so the loop itself is
## reviewable and not just the middle frame the FAN-2518 gallery freezes.
##
## Actor-parameterized successor to capture_fan2606_sniper_walk.gd, so a
## per-card copy is not needed for the remaining roster.
##
## Needs a real renderer: --headless uses the dummy driver and cannot screenshot.
## After checking out a revision that changed the frames, run an import pass
## first (Godot --headless --path . --import --quit) or the capture silently
## renders the stale import cache instead of the checked-out PNGs.
## Run: Godot --path . --script res://tools/capture_actor_walk.gd -- <actor> <slug>
## Output: build/qa/<slug>_<actor>/<actor>_walk_1920x1080_page<n>.png

const VIEWPORT_SIZE := Vector2i(1920, 1080)
const DIRECTIONS := [
	"south", "south_east", "east", "north_east",
	"north", "north_west", "west", "south_west",
]
const FRAME_COUNT := 6
const ROWS_PER_PAGE := 4
# player.gd PLAYER_COMBAT_VISUAL_SCALE 0.64 x Player.tscn Camera2D zoom 1.12.
const LIVE_SCALE := 0.7168
# Runtime contract: 245 px of art bottom-aligned with 32 px padding on a 512 px
# canvas, so the art band centre sits this far below the canvas centre. Lift the
# sprite by it to centre the art, not the padded canvas, in its cell.
const ART_CENTRE_OFFSET := 101.5
const CELL := Vector2(300.0, 250.0)
const ORIGIN := Vector2(120.0, 30.0)

var _actor := ""
var _out_dir := ""


func _initialize() -> void:
	var user_args := OS.get_cmdline_user_args()
	if user_args.size() < 2:
		push_error("capture_actor_walk: usage -- <actor> <slug>")
		quit(1)
		return
	_actor = str(user_args[0])
	_out_dir = "res://build/qa/%s_%s" % [str(user_args[1]), _actor]

	var frames_path := "res://assets/sprites/characters/%s_spriteframes.tres" % _actor
	var frames := load(frames_path) as SpriteFrames
	if frames == null:
		push_error("capture_actor_walk: cannot load %s" % frames_path)
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		push_error("capture_actor_walk: needs a real renderer, run without --headless")
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))
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
		var animation_name := "walk_%s" % direction
		if not frames.has_animation(animation_name):
			push_error("capture_actor_walk: %s has no %s row" % [_actor, animation_name])
			viewport.queue_free()
			return false
		var centre_y := ORIGIN.y + row * CELL.y + CELL.y * 0.5

		var label := Label.new()
		label.text = direction
		label.add_theme_font_size_override("font_size", 16)
		label.position = Vector2(10.0, centre_y)
		viewport.add_child(label)

		for column in FRAME_COUNT:
			var sprite := AnimatedSprite2D.new()
			sprite.sprite_frames = frames
			sprite.animation = animation_name
			sprite.scale = Vector2(LIVE_SCALE, LIVE_SCALE)
			sprite.position = Vector2(
				ORIGIN.x + column * CELL.x + CELL.x * 0.5,
				centre_y - ART_CENTRE_OFFSET * LIVE_SCALE)
			viewport.add_child(sprite)
			sprite.play(sprite.animation)
			sprite.stop()
			sprite.frame = column

	await RenderingServer.frame_post_draw
	var path := "%s/%s_walk_%dx%d_page%d.png" % [
		_out_dir, _actor, VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, page + 1]
	var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	viewport.queue_free()
	if error != OK:
		push_error("capture_actor_walk: save failed (%d) for %s" % [error, path])
		return false
	print("captured: ", path)
	return true
