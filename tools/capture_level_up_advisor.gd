extends SceneTree

## SCRUM-871: снимает экран Level Up 3.0 (советник) на 1280x720 / 1920x1080 /
## 2560x1440 с детерминированным набором наград (урон / HP / радиус подбора),
## чтобы в кадр попали бейджи «ЛУЧШИЙ УРОН» и «ВЫЖИВАНИЕ» и блоки «до -> после».
## Run (windowed для PNG): Godot --path . --script res://tools/capture_level_up_advisor.gd
## Output: build/qa/scrum871/level_up_advisor_<WxH>.png + rects.md

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const VIEWPORT_SIZES := [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

const DUMP_NODES := [
	"LevelUpPanel", "LevelUpHeroHeader", "LevelUpTitle", "LevelUpSubtitle",
	"LevelUpRewardButton0", "LevelUpRewardButton1", "LevelUpRewardButton2",
	"LevelUpRewardBadge", "LevelUpRewardBadgeLabel",
	"LevelUpRewardDescription", "LevelUpRewardEffectPreview",
	"LevelUpRewardEffectText", "LevelUpRewardEffectText2", "LevelUpRewardEffectText3",
	"LevelUpLaterButton",
]

const OFFER := [
	{"id": "damage_up", "attr": "damage", "title": "+Урон", "description": "+15% к урону.", "kind": "upgrade", "mods": {"damage_multiplier": 1.15}},
	{"id": "max_hp_up", "attr": "max_health", "title": "+Макс. здоровье", "description": "+18 к максимальному здоровью.", "kind": "upgrade", "mods": {"max_health_flat": 18.0}},
	{"id": "pickup_radius_up", "attr": "pickup_radius", "title": "+Радиус подбора", "description": "+45 к радиусу подбора опыта и золота.", "kind": "upgrade", "mods": {"pickup_radius_flat": 45.0}},
]


func _initialize() -> void:
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum871")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var dump_lines := PackedStringArray()
	dump_lines.append("# SCRUM-871 Level Up Advisor Capture")
	dump_lines.append("")
	for viewport_size in VIEWPORT_SIZES:
		await _capture_at_size(viewport_size, qa_dir, dump_lines)
	var file := FileAccess.open("%s/level_up_advisor_rects.md" % qa_dir, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(dump_lines))
		file.close()
	print("Level Up advisor capture done.")
	quit(0)


func _capture_at_size(viewport_size: Vector2i, qa_dir: String, dump_lines: PackedStringArray) -> void:
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
	# Интро-фейд панели: даём твинам дойти до видимого состояния.
	for _i in range(30):
		await process_frame

	dump_lines.append("## %dx%d" % [viewport_size.x, viewport_size.y])
	var output_path := "%s/level_up_advisor_%dx%d.png" % [qa_dir, viewport_size.x, viewport_size.y]
	if DisplayServer.get_name() == "headless":
		dump_lines.append("- screenshots skipped (headless); rect dump authoritative")
	else:
		var image := viewport.get_texture().get_image()
		if image != null:
			image.save_png(output_path)
			dump_lines.append("- screenshot: `%s`" % output_path)
	dump_lines.append("| node | global rect |")
	dump_lines.append("| --- | --- |")
	for node_name in DUMP_NODES:
		for node in main.find_children(node_name, "Control", true, false):
			var control := node as Control
			if control != null and control.is_visible_in_tree():
				var extra := ""
				if control is Label:
					extra = " font=%d text=%s" % [(control as Label).get_theme_font_size("font_size"), (control as Label).text]
				dump_lines.append("| `%s` (%s) | `%s`%s |" % [node_name, str(control.get_parent().get_parent().name), str(control.get_global_rect()), extra])
	dump_lines.append("")
	main.queue_free()
	viewport.queue_free()
	await process_frame
