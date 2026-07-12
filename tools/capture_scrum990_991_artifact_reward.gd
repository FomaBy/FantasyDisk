extends SceneTree

## Persistent renderer evidence for SCRUM-990/991. Both elite/chest and boss
## paths are captured at the accepted responsive matrix. Run windowed through
## tools/godot_gate.py so SubViewport textures contain renderer output.

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const TARGETS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const KINDS := ["elite", "boss"]


func _initialize() -> void:
	var output_dir := ProjectSettings.globalize_path("res://docs/design/previews/scrum990_991_artifact_reward/runtime")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var report := PackedStringArray(["# SCRUM-990/991 Artifact Reward Runtime Matrix", ""])
	for viewport_size in TARGETS:
		for kind in KINDS:
			await _capture(viewport_size, kind, output_dir, report)
	var report_file := FileAccess.open("%s/runtime_matrix.md" % output_dir, FileAccess.WRITE)
	if report_file != null:
		report_file.store_string("\n".join(report))
		report_file.close()
	print("SCRUM-990/991 Artifact Reward runtime capture completed.")
	quit()


func _capture(viewport_size: Vector2i, kind: String, output_dir: String, report: PackedStringArray) -> void:
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
	main.set("route_stage", 6)
	if kind == "boss":
		main.ui._show_boss_artifact_reward(Callable())
	else:
		main.ui._show_elite_artifact_reward(Callable())
	for _frame in range(12):
		await process_frame

	var prefix := "Boss" if kind == "boss" else "Elite"
	var screen := main.find_child("%sArtifactRewardScreen" % prefix, true, false) as Control
	var content := main.find_child("%sArtifactRewardContentRoot" % prefix, true, false) as Control
	var row := main.find_child("%sArtifactRewardRow" % prefix, true, false) as HBoxContainer
	var frame := main.find_child("%sArtifactRewardFrame" % prefix, true, false) as Panel
	report.append("## %s %dx%d" % [kind, viewport_size.x, viewport_size.y])
	report.append("- inner: `%s`" % str(screen.get_meta("gold_shell_inner_rect", Rect2()) if screen != null else Rect2()))
	report.append("- content: `%s`" % str(content.get_global_rect() if content != null else Rect2()))
	report.append("- row: `%s`, count=%d" % [str(row.get_global_rect() if row != null else Rect2()), row.get_child_count() if row != null else 0])
	report.append("- frame final: `%s`, mouse-ignore=%s" % [str(frame != null and screen != null and screen.get_child(screen.get_child_count() - 1) == frame), str(frame.mouse_filter == Control.MOUSE_FILTER_IGNORE if frame != null else false)])
	if row != null:
		for child in row.get_children():
			var card := child as Button
			if card == null:
				continue
			var resolved := card.find_child("EliteArtifactRewardResolvedEffect", true, false) as Label
			var badge := card.find_child("EliteArtifactRewardBadge", true, false) as Label
			report.append("- %s: `%s`; badge=`%s`; resolved=`%s`" % [card.name, str(card.get_global_rect()), badge.text if badge != null else "", (resolved.text if resolved != null else "").replace("\n", " / ")])
	report.append("")
	if DisplayServer.get_name() != "headless":
		var image := viewport.get_texture().get_image()
		if image != null and not image.is_empty():
			image.save_png("%s/%s_%dx%d.png" % [output_dir, kind, viewport_size.x, viewport_size.y])
	main.queue_free()
	viewport.queue_free()
	await process_frame
