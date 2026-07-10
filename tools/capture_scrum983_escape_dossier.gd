extends SceneTree

# Windowed visual evidence for SCRUM-983. Headless runs still emit the geometry
# report; a real display driver additionally writes the three PNG screenshots.

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const TARGETS := [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]


func _initialize() -> void:
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum983")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var lines := PackedStringArray([
		"# SCRUM-983 Escape dossier visual matrix",
		"",
		"Display driver: `%s`" % DisplayServer.get_name(),
		"",
	])
	var passed := true
	for viewport_size in TARGETS:
		passed = (await _capture(viewport_size, qa_dir, lines)) and passed
	var report := FileAccess.open("%s/escape_dossier_visual_matrix.md" % qa_dir, FileAccess.WRITE)
	if report != null:
		report.store_string("\n".join(lines))
		report.close()
	if passed:
		print("SCRUM-983 Escape dossier visual capture passed.")
		quit(0)
	else:
		push_error("SCRUM-983 visual capture failed; inspect escape_dossier_visual_matrix.md.")
		quit(1)


func _capture(viewport_size: Vector2i, qa_dir: String, lines: PackedStringArray) -> bool:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await _settle()
	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "sword")
	main.set("route_stage", 2)
	main.call("_start_combat")
	await _settle()
	main.ui._show_pause_menu(true)
	await _settle()

	var pause := main.find_child("PauseStatsMenuRoot", true, false) as Control
	var frame := main.find_child("EscapeStatsPanelFrame", true, false) as PanelContainer
	var header := main.find_child("DossierHeader", true, false) as Control
	var body := main.find_child("DossierBody", true, false) as Control
	var hero := main.find_child("HeroCard", true, false) as Control
	var derived := main.find_child("DerivedStatsPanel", true, false) as Control
	var actions := main.find_child("PauseControlButtons", true, false) as Control
	var base_grid := main.find_child("BaseStatsGrid", true, false) as GridContainer
	var hero_scroll := main.find_child("HeroCardScroll", true, false) as ScrollContainer
	var derived_scroll := main.find_child("DerivedStatsScroll", true, false) as ScrollContainer
	var complete := pause != null and frame != null and header != null and body != null \
		and hero != null and derived != null and actions != null and base_grid != null \
		and hero_scroll != null and derived_scroll != null
	lines.append("## %dx%d" % [viewport_size.x, viewport_size.y])
	if complete:
		lines.append("- frame safe rect: `%s`" % str(frame.get_meta("gold_shell_content_rect", Rect2())))
		lines.append("- inner content rect: `%s`" % str(frame.get_meta("dossier_inner_content_rect", Rect2())))
		lines.append("- header: `%s`" % str(header.get_global_rect()))
		lines.append("- body: `%s`" % str(body.get_global_rect()))
		lines.append("- hero dossier: `%s`" % str(hero.get_global_rect()))
		lines.append("- derived stats: `%s`" % str(derived.get_global_rect()))
		lines.append("- actions: `%s`" % str(actions.get_global_rect()))
		var mask_area := 0.0
		for side in ["Top", "Bottom", "Left", "Right"]:
			var mask := main.find_child("DossierReserveMask%s" % side, true, false) as ColorRect
			if mask != null:
				mask_area += mask.get_global_rect().size.x * mask.get_global_rect().size.y
		lines.append("- opaque reserve masks: `4`, combined area `%.1f`, frame is final layer `%s`" % [mask_area, str(frame.get_index() > actions.get_parent().get_index())])
		lines.append("- BaseStatsGrid: `%d` real rows, `%d` columns" % [base_grid.get_child_count(), base_grid.columns])
		lines.append("- Hero scroll: vertical max `%.1f`, horizontal mode `%d`, follow_focus `%s`" % [hero_scroll.get_v_scroll_bar().max_value, hero_scroll.horizontal_scroll_mode, str(hero_scroll.follow_focus)])
		lines.append("- Derived scroll: vertical max `%.1f`, horizontal mode `%d`, follow_focus `%s`" % [derived_scroll.get_v_scroll_bar().max_value, derived_scroll.horizontal_scroll_mode, str(derived_scroll.follow_focus)])
		var attack_speed := main.find_child("DerivedStatValue_attack_speed", true, false) as Label
		var crit_chance := main.find_child("DerivedStatValue_crit_chance", true, false) as Label
		var crit_power := main.find_child("DerivedStatValue_crit_damage_multiplier", true, false) as Label
		lines.append("- compact units: attack `%s`, crit `%s`, crit power `%s`" % [attack_speed.text, crit_chance.text, crit_power.text])
		var alias_pairs := PackedStringArray()
		for stat_id in ["attack_speed", "magic_damage", "aoe_radius", "projectile_speed", "dot_damage", "dot_speed"]:
			var alias_label := main.find_child("DerivedStatName_%s" % stat_id, true, false) as Label
			var value_label := main.find_child("DerivedStatValue_%s" % stat_id, true, false) as Label
			if alias_label != null and value_label != null:
				alias_pairs.append("%s %s" % [alias_label.text, value_label.text])
		lines.append("- measured compact aliases: `%s`" % "; ".join(alias_pairs))
	lines.append("")

	if DisplayServer.get_name() != "headless" and complete:
		var image := viewport.get_texture().get_image()
		if image != null and not image.is_empty():
			image.save_png("%s/escape_dossier_%dx%d.png" % [qa_dir, viewport_size.x, viewport_size.y])
		else:
			complete = false

	main.queue_free()
	viewport.queue_free()
	await process_frame
	return complete


func _settle() -> void:
	for _frame in range(18):
		await process_frame
