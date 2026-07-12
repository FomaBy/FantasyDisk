extends SceneTree

## Runtime visual evidence for SCRUM-981. Run windowed through godot_gate; a
## headless run still writes geometry but cannot produce renderer screenshots.

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const QA_CAPTURE_TEARDOWN := preload("res://tools/qa_capture_teardown.gd")
const TARGETS := [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const SCREEN_IDS := ["main_menu", "route_map", "rest", "upgrade", "battle_reward", "victory", "defeat"]

var _errors := PackedStringArray()
var _capture_teardown := QA_CAPTURE_TEARDOWN.new()


func _initialize() -> void:
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum981")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var report := PackedStringArray(["# SCRUM-981 Runtime Visual Matrix", ""])
	for viewport_size in TARGETS:
		for screen_id in SCREEN_IDS:
			await _capture_screen(viewport_size, screen_id, qa_dir, report)
	await _capture_teardown.release_windowed_audio(self)
	var output := FileAccess.open("%s/runtime_visual_matrix.md" % qa_dir, FileAccess.WRITE)
	if output != null:
		output.store_string("\n".join(report))
		output.close()
	if _errors.is_empty():
		print("SCRUM-981 runtime visual capture completed.")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _capture_screen(viewport_size: Vector2i, screen_id: String, qa_dir: String, report: PackedStringArray) -> void:
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
	match screen_id:
		"main_menu":
			main.ui._show_main_menu()
		"route_map":
			main.set("route_stage", 0)
			main.set("route_nodes", main.route._generate_route())
			main.route._show_battle_map()
		"rest":
			main.ui._show_rest_screen()
		"upgrade":
			main.ui._show_upgrade_screen()
		"battle_reward":
			main.ui._show_reward_screen()
		"victory":
			main.set("run_metrics", _sample_metrics("Повержен финальный босс"))
			main.ui._show_victory_screen()
		"defeat":
			main.set("run_metrics", _sample_metrics("Пал в бою"))
			main.ui._show_death_screen("Забег завершён")
	for _frame in range(12):
		await process_frame

	var frame_name: String = str({
		"main_menu": "MainMenuFrame",
		"route_map": "RouteMapFrame",
		"rest": "RestFrame",
		"upgrade": "UpgradeFrame",
		"battle_reward": "BattleRewardFrame",
		"victory": "VictoryFrame",
		"defeat": "DefeatFrame",
	}.get(screen_id, ""))
	var frame := main.find_child(frame_name, true, false) as Panel
	var safe_rect: Rect2 = (frame.get_meta("gold_shell_content_rect", Rect2()) as Rect2) if frame != null else Rect2()
	report.append("## %s %dx%d" % [screen_id, viewport_size.x, viewport_size.y])
	report.append("- frame: `%s`" % frame_name)
	report.append("- safe rect: `%s`" % str(safe_rect))
	if screen_id == "main_menu":
		var title := main.find_child("MainMenuTitleLabel", true, false) as Control
		var actions := main.find_child("MainMenuActions", true, false) as Control
		report.append("- logo: `%s`" % str(title.get_global_rect() if title != null else Rect2()))
		report.append("- actions: `%s`" % str(actions.get_global_rect() if actions != null else Rect2()))
	else:
		var evidence_nodes: Array = ["RouteMapHeader", "RouteMapTitleProgress", "RunResourceHud", "RouteMapScroll"] if screen_id == "route_map" else _screen_evidence_nodes(screen_id)
		for node_name in evidence_nodes:
			var node := main.find_child(node_name, true, false) as Control
			report.append("- %s: `%s`" % [node_name, str(node.get_global_rect() if node != null else Rect2())])
	report.append("")

	if DisplayServer.get_name() != "headless":
		var image := viewport.get_texture().get_image()
		if image != null and not image.is_empty():
			image.save_png("%s/%s_%dx%d.png" % [qa_dir, screen_id, viewport_size.x, viewport_size.y])

	var teardown_errors := await _capture_teardown.release_viewport(self, viewport)
	for error in teardown_errors:
		_errors.append("%s %dx%d: %s" % [screen_id, viewport_size.x, viewport_size.y, error])
		report.append("- lifecycle error: `%s`" % error)


func _screen_evidence_nodes(screen_id: String) -> Array:
	match screen_id:
		"rest":
			return ["MenuPanel_campfire", "RunResourceHud", "RestHealButton", "RestGuardButton", "RestBackButton"]
		"upgrade":
			return ["MenuPanel_upgrade", "RunResourceHud", "UpgradeChoiceRow"]
		"battle_reward":
			return ["MenuPanel_artifact_reward", "RunResourceHud", "BattleRewardCardsRow"]
		"victory":
			return ["PauseEndModalPanel_victory", "ResultContent_victory", "RunSummaryStats", "VictoryNewRunButton"]
		"defeat":
			return ["PauseEndModalPanel_death", "ResultContent_death", "RunSummaryStats", "DeathRetryButton"]
	return []


func _sample_metrics(outcome: String) -> Dictionary:
	return {
		"kills": 137,
		"boss_kills": 1,
		"damage_dealt": 48213.0,
		"damage_taken": 6042.0,
		"gold_collected": 1840,
		"time_seconds": 742.0,
		"route_stage_reached": 5,
		"final_level": 12,
		"artifacts": [{"title": "Сердце Пиявки"}, {"title": "Шип Бездны"}],
		"outcome_reason": outcome,
	}
