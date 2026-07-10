extends SceneTree

## SCRUM-985 visual QA: captures the Level Up screen after removing the outer
## frame, brightening the backdrop and constraining reward icons to socket-safe
## rectangles. Run windowed; headless mode still writes the rect report.

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const VIEWPORT_SIZES := [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

const OFFER := [
	{"id": "scrum985_regeneration", "title": "+Регенерация", "description": "+1.3 здоровья в секунду к восстановлению.", "kind": "upgrade", "mods": {"regeneration_flat": 0.35}},
	{"id": "scrum985_ultimate", "title": "+Сила ультимейта", "description": "+12% к силе эффектов классового ультимейта.", "kind": "upgrade", "mods": {"ultimate_flat": 0.12}},
	{"id": "scrum985_move_speed", "title": "+Скорость движения", "description": "+10% к скорости движения.", "kind": "upgrade", "mods": {"move_speed_multiplier": 1.10}},
]


func _initialize() -> void:
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum985")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var lines := PackedStringArray(["# SCRUM-985 Level Up visual QA", ""])
	for viewport_size in VIEWPORT_SIZES:
		await _capture(viewport_size, qa_dir, lines)
	var report := FileAccess.open("%s/level_up_visual_matrix.md" % qa_dir, FileAccess.WRITE)
	if report != null:
		report.store_string("\n".join(lines))
		report.close()
	print("SCRUM-985 Level Up capture passed.")
	quit(0)


func _capture(viewport_size: Vector2i, qa_dir: String, lines: PackedStringArray) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame

	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await process_frame
	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "sword")
	main.set("pending_level_ups", 1)
	main.set("level_up_offer", OFFER.duplicate(true))
	main.ui._show_level_up_screen(false)
	for _frame in range(30):
		await process_frame

	var overlay := main.find_child("LevelUpOverlay", true, false) as Control
	var panel := main.find_child("LevelUpPanel", true, false) as PanelContainer
	var dim := main.find_child("LevelUpDim", true, false) as ColorRect
	var shade := main.find_child("ScreenBackgroundReadableShade", true, false) as ColorRect
	lines.append("## %dx%d" % [viewport_size.x, viewport_size.y])
	lines.append("- outer frame present: `%s`" % str(main.find_child("LevelUpFrame", true, false) != null))
	lines.append("- dim alpha: `%.3f`" % (dim.color.a if dim != null else -1.0))
	lines.append("- readable shade alpha: `%.3f`" % (shade.color.a if shade != null else -1.0))
	var panel_style := panel.get_theme_stylebox("panel") as StyleBoxFlat if panel != null else null
	lines.append("- panel alpha: `%.3f`" % (panel_style.bg_color.a if panel_style != null else -1.0))
	lines.append("| card | socket | icon | inner-safe contains icon |")
	lines.append("| --- | --- | --- | --- |")
	for index in range(3):
		var card := main.find_child("LevelUpRewardButton%d" % index, true, false) as Button
		var socket := card.find_child("LevelUpRewardSocket*", true, false) as TextureRect if card != null else null
		var icon := card.find_child("UIIcon_*", true, false) as Control if card != null else null
		var socket_rect := socket.get_global_rect() if socket != null else Rect2()
		var icon_rect := icon.get_global_rect() if icon != null else Rect2()
		var inset := maxf(2.0, roundf(socket_rect.size.x * 0.18))
		var safe_rect := socket_rect.grow(-inset).grow(1.0)
		lines.append("| `%d` | `%s` | `%s` | `%s` |" % [index, str(socket_rect), str(icon_rect), str(safe_rect.encloses(icon_rect))])
	lines.append("")

	if DisplayServer.get_name() != "headless" and overlay != null:
		var image := viewport.get_texture().get_image()
		if image != null:
			image.save_png("%s/level_up_%dx%d.png" % [qa_dir, viewport_size.x, viewport_size.y])

	main.queue_free()
	viewport.queue_free()
	await process_frame
