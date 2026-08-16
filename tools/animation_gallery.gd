extends SceneTree

## FAN-2518 — in-game animation gallery: deterministic captures of every
## runtime actor pack for state/direction inspection.
## Run windowed:  Godot --path . --script res://tools/animation_gallery.gd
## Output: build/animation_gallery/<actor_id>.png (one grid per actor, one
## cell per animation frozen at its middle frame — no time dependence).

const MANIFEST_PATH := "res://data/meta/animation_roster_manifest.json"
const OUT_DIR := "build/animation_gallery"
const Registry := preload("res://scripts/full_frame_animation_registry.gd")

const CELL := Vector2(150.0, 150.0)
const GRID_COLS := 8
const MARGIN := Vector2(16.0, 40.0)
const MAX_DISPLAY_HEIGHT := 110.0

var _shots: Array[String] = []


func _initialize() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var manifest: Array = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if manifest == null or manifest.is_empty():
		push_error("animation_gallery: manifest missing or empty: %s" % MANIFEST_PATH)
		quit(1)
		return
	var background := ColorRect.new()
	background.color = Color(0.10, 0.09, 0.12)
	background.size = Vector2(1280, 720)
	root.add_child(background)

	for entry in manifest:
		_capture_actor(entry)
		await process_frame
	DirAccess.dir_exists_absolute(OUT_DIR)
	print("captured: ", ", ".join(_shots))
	print("total: ", _shots.size())
	quit()


func _capture_actor(entry: Dictionary) -> void:
	var frames := load(str(entry.get("frames", ""))) as SpriteFrames
	if frames == null:
		push_error("animation_gallery: cannot load %s" % str(entry.get("frames", "")))
		return
	var actor_id := str(entry.get("id", ""))
	var config := {}
	for kind in _entity_kinds(str(entry.get("group", "")), actor_id):
		config = Registry.registry_config(kind, actor_id)
		if not config.is_empty():
			break

	var names: PackedStringArray = frames.get_animation_names()
	var rows := int(ceil(names.size() / float(GRID_COLS)))
	var holder := Control.new()
	holder.position = Vector2(6, 6)
	root.add_child(holder)

	var title := Label.new()
	title.text = "%s (%s)%s" % [actor_id, entry.get("group", ""),
		" fallback->%s" % entry.get("fallback_of", "") if entry.has("fallback_of") else ""]
	title.add_theme_font_size_override("font_size", 18)
	title.position = Vector2(MARGIN.x, 0)
	holder.add_child(title)

	for i in names.size():
		var anim_name := names[i]
		var col := i % GRID_COLS
		var row := i / GRID_COLS
		var origin := MARGIN + Vector2(col, row) * CELL

		var label := Label.new()
		label.text = "%s x%d%s" % [anim_name, frames.get_frame_count(anim_name),
			" L" if frames.get_animation_loop_mode(anim_name) != 0 else ""]
		label.add_theme_font_size_override("font_size", 10)
		label.position = origin + Vector2(0.0, CELL.y - 16.0)
		holder.add_child(label)

		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = frames
		sprite.animation = anim_name
		sprite.position = origin + CELL * 0.5 - Vector2(0.0, 8.0)
		var display_scale := config.get("scale", Vector2.ONE) as Vector2
		var frame_texture := frames.get_frame_texture(anim_name, 0)
		if frame_texture != null and frame_texture.get_height() * display_scale.y > MAX_DISPLAY_HEIGHT:
			display_scale = Vector2.ONE * (MAX_DISPLAY_HEIGHT / frame_texture.get_height())
		sprite.scale = display_scale
		holder.add_child(sprite)
		sprite.play(anim_name)
		sprite.stop()
		sprite.frame = maxi(0, frames.get_frame_count(anim_name) / 2)

	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, actor_id]
	image.save_png(path)
	_shots.append(path)
	holder.queue_free()


func _entity_kinds(group: String, actor_id: String) -> Array[String]:
	# Monster group spans plain enemies and elites; heroes resolve by class id,
	# homunculi share the legacy "homunculus" registry key. Try in order.
	match group:
		"hero":
			return ["hero"]
		"boss":
			return ["boss"]
		"druid_summon", "homunculus":
			# Homunculi share the single legacy "homunculus" registry entry at
			# runtime (ally_minion routes both visual ids to it).
			var ids: Array[String] = ["ally"]
			return ids
		"monster":
			return ["enemy", "elite"]
	return []
