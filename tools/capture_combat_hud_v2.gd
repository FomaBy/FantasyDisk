extends SceneTree

## SCRUM-806: captures the compact combat HUD v2 for visual QA.
## Run (windowed renderer required for pixels): Godot --path . --script res://tools/capture_combat_hud_v2.gd
## Output: build/qa/scrum806/combat_hud_*.png + rect dump.

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const VIEWPORT_SIZES := [
	Vector2i(1152, 648),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const DUMP_NODES := [
	"RunResourceHud",
	"UIIcon_hp", "HudHPTrack", "HudHPBar", "HudHPLabel",
	"UIIcon_xp", "HudXPTrack", "HudXPBar", "HudXPLabel",
	"UIIcon_ultimate_multiplier", "HudULTTrack", "HudULTBar", "HudULTLabel",
	"UIIcon_money", "HudMoneyLabel",
	"CombatTimerPanel", "CombatTimerLabel", "CombatTimerIcon",
	"AscensionHudBadge", "AscensionHudIcon", "AscensionHudLabel",
	"LevelUpPlusButton",
]


func _initialize() -> void:
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum806")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var dump_lines := PackedStringArray()
	dump_lines.append("# SCRUM-806 Combat HUD v2 QA Capture")
	dump_lines.append("")
	for viewport_size in VIEWPORT_SIZES:
		await _capture_at_size(viewport_size, qa_dir, dump_lines)
	var file := FileAccess.open("%s/combat_hud_capture_rects.md" % qa_dir, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(dump_lines))
		file.close()
		print("Combat HUD v2 QA capture updated.")
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
	main.call("_show_weapon_select")
	await process_frame
	main.set("selected_weapon_id", "axe")
	main.set("selected_ascension_level", 3)
	main.call("_start_combat")
	for _i in range(12):
		await process_frame
	# Частично заполненные бары: видно филлы, трек и READY-состояние ульты.
	var player: Node = main.get("current_player")
	if player != null:
		player.set("health", float(player.get("max_health")) * 0.68)
		player.set("xp", 3)
		player.set("xp_to_next", 8)
		player.set("money", 127)
		player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	main.set("_last_hud_snapshot", {})
	main.get("ui").call("_update_hud")
	for _i in range(4):
		await process_frame

	var output_path := "%s/combat_hud_%dx%d.png" % [qa_dir, viewport_size.x, viewport_size.y]
	dump_lines.append("## %dx%d" % [viewport_size.x, viewport_size.y])
	if DisplayServer.get_name() == "headless":
		dump_lines.append("- screenshot: skipped in headless dummy renderer; rect dump is authoritative.")
	else:
		var image := viewport.get_texture().get_image()
		if image != null:
			image.save_png(output_path)
			dump_lines.append("- screenshot: `%s`" % output_path)
		else:
			dump_lines.append("- screenshot: unavailable")
	for node_name in DUMP_NODES:
		var control := main.find_child(str(node_name), true, false) as Control
		if control != null:
			dump_lines.append("- `%s`: rect=`%s`" % [node_name, str(control.get_global_rect())])
		else:
			dump_lines.append("- `%s`: MISSING" % node_name)
	viewport.queue_free()
	await process_frame
