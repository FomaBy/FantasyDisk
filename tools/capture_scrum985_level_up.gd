extends SceneTree

## SCRUM-985 visual QA: captures the Level Up screen after removing the outer
## frame, brightening the backdrop and constraining reward icons to socket-safe
## rectangles. SCRUM-1032 additionally proves that advisor badges never cover
## the socket ornament/icon. Run windowed; headless still writes the rect report.

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const QA_CAPTURE_TEARDOWN := preload("res://tools/qa_capture_teardown.gd")
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

var _capture_teardown := QA_CAPTURE_TEARDOWN.new()


func _initialize() -> void:
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum985")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var lines := PackedStringArray(["# SCRUM-985 Level Up visual QA", ""])
	var passed := true
	for viewport_size in VIEWPORT_SIZES:
		passed = (await _capture(viewport_size, qa_dir, lines)) and passed
	await _capture_teardown.release_windowed_audio(self)
	var report := FileAccess.open("%s/level_up_visual_matrix.md" % qa_dir, FileAccess.WRITE)
	if report != null:
		report.store_string("\n".join(lines))
		report.close()
	if passed:
		print("SCRUM-985/SCRUM-1032 Level Up capture passed.")
		quit(0)
	else:
		push_error("SCRUM-985/SCRUM-1032 Level Up capture failed; inspect level_up_visual_matrix.md.")
		quit(1)


func _capture(viewport_size: Vector2i, qa_dir: String, lines: PackedStringArray) -> bool:
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
	lines.append("| card | badge | socket | icon | icon safe | badge/socket disjoint | badge/icon disjoint | label full | focus stable |")
	lines.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- |")
	var passed := true
	var advisor_badge_count := 0
	var advisor_badge_captions := PackedStringArray()
	var socket_tops := PackedFloat32Array()
	var title_tops := PackedFloat32Array()
	for index in range(3):
		var card := main.find_child("LevelUpRewardButton%d" % index, true, false) as Button
		var socket := card.find_child("LevelUpRewardSocket*", true, false) as TextureRect if card != null else null
		var icon := card.find_child("UIIcon_*", true, false) as Control if card != null else null
		var badge := card.find_child("LevelUpRewardBadge", true, false) as Control if card != null else null
		var badge_label := badge.find_child("LevelUpRewardBadgeLabel", true, false) as Label if badge != null else null
		var badge_rect := badge.get_global_rect() if badge != null else Rect2()
		var socket_rect := socket.get_global_rect() if socket != null else Rect2()
		var icon_rect := icon.get_global_rect() if icon != null else Rect2()
		var title := card.find_child("LevelUpRewardTitle", true, false) as Label if card != null else null
		if badge != null:
			advisor_badge_count += 1
			advisor_badge_captions.append(badge_label.text if badge_label != null else "")
		if socket != null:
			socket_tops.append(socket_rect.position.y)
		if title != null:
			title_tops.append(title.get_global_rect().position.y)
		var inset := maxf(2.0, roundf(socket_rect.size.x * 0.18))
		var safe_rect := socket_rect.grow(-inset).grow(1.0)
		var icon_safe := socket != null and icon != null and safe_rect.encloses(icon_rect)
		var badge_socket_disjoint := badge == null or not badge_rect.intersects(socket_rect)
		var badge_icon_disjoint := badge == null or not badge_rect.intersects(icon_rect)
		var label_full := true
		if badge_label != null:
			var font: Font = badge_label.get_theme_font("font")
			if font == null:
				font = ThemeDB.fallback_font
			var required_width := font.get_string_size(
				badge_label.text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				badge_label.get_theme_font_size("font_size")
			).x
			label_full = required_width <= badge_label.size.x + 1.0
		var focus_stable := true
		if card != null:
			var before := [badge_rect, socket_rect, icon_rect]
			card.grab_focus()
			await process_frame
			var after := [
				badge.get_global_rect() if badge != null else Rect2(),
				socket.get_global_rect() if socket != null else Rect2(),
				icon.get_global_rect() if icon != null else Rect2(),
			]
			focus_stable = before == after
			card.release_focus()
		passed = passed and icon_safe and badge_socket_disjoint and badge_icon_disjoint and label_full and focus_stable
		lines.append("| `%d` | `%s` | `%s` | `%s` | `%s` | `%s` | `%s` | `%s` | `%s` |" % [
			index, str(badge_rect) if badge != null else "n/a", str(socket_rect), str(icon_rect),
			str(icon_safe), str(badge_socket_disjoint), str(badge_icon_disjoint),
			str(label_full) if badge != null else "n/a", str(focus_stable),
		])
	var stacks_aligned := socket_tops.size() == 3 and title_tops.size() == 3
	if stacks_aligned:
		for aligned_index in range(1, 3):
			stacks_aligned = stacks_aligned \
				and absf(socket_tops[aligned_index] - socket_tops[0]) <= 1.0 \
				and absf(title_tops[aligned_index] - title_tops[0]) <= 1.0
	var expected_badge_present := advisor_badge_count >= 1 and advisor_badge_captions.has("ВЫЖИВАНИЕ")
	passed = passed and expected_badge_present and stacks_aligned
	lines.append("- advisor badges: `%d`, captions: `%s`, expected fixture badge present: `%s`" % [advisor_badge_count, str(advisor_badge_captions), str(expected_badge_present)])
	lines.append("- socket tops: `%s`; title tops: `%s`; three-card stacks aligned: `%s`" % [str(socket_tops), str(title_tops), str(stacks_aligned)])
	lines.append("")

	if DisplayServer.get_name() != "headless" and overlay != null:
		var image := viewport.get_texture().get_image()
		if image != null:
			image.save_png("%s/level_up_%dx%d.png" % [qa_dir, viewport_size.x, viewport_size.y])

	var teardown_errors := await _capture_teardown.release_viewport(self, viewport)
	for error in teardown_errors:
		lines.append("- lifecycle error: `%s`" % error)
	passed = passed and teardown_errors.is_empty()
	return passed
