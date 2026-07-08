extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const OUT_DIR := "res://build/qa/design_review"

const SCREEN_IDS := [
	"main_menu",
	"quit_dialog",
	"settings_display",
	"settings_audio",
	"settings_controls",
	"hero_select",
	"weapon_select",
	"codex",
	"battle_reward",
	"level_up",
	"elite_reward",
	"shop",
	"attribute_shop",
	"rest",
	"upgrade",
	"event",
	"pause_menu",
	"pause_stats",
	"victory",
	"death",
	"combat_hud",
	"feedback_dialog",
]

var _missing_captures: PackedStringArray = []


func _initialize() -> void:
	var absolute_out := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_out)
	var manifest := PackedStringArray()
	manifest.append("# SCRUM-458 Design Review Screenshot Manifest")
	manifest.append("")
	for viewport_size in VIEWPORT_SIZES:
		for screen_id in SCREEN_IDS:
			var path := await _capture_screen(viewport_size, screen_id, absolute_out)
			manifest.append("- `%s` `%s`: `%s`" % [screen_id, str(viewport_size), path])
	var file := FileAccess.open("%s/manifest.md" % absolute_out, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(manifest))
		file.close()
	if not _missing_captures.is_empty():
		for missing in _missing_captures:
			push_error(missing)
		quit(1)
		return
	print("Design review screenshots written to %s" % absolute_out)
	quit(0)


func _capture_screen(viewport_size: Vector2i, screen_id: String, absolute_out: String) -> String:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await process_frame
	await process_frame
	await _open_screen(main, screen_id)
	for _i in range(45):
		await process_frame
	var image := viewport.get_texture().get_image()
	var path := "%s/%s_%dx%d.png" % [absolute_out, screen_id, viewport_size.x, viewport_size.y]
	if image == null:
		_missing_captures.append("%s %s: viewport image unavailable" % [screen_id, str(viewport_size)])
		viewport.queue_free()
		await process_frame
		return ""
	image.save_png(path)
	viewport.queue_free()
	await process_frame
	return path


func _open_screen(main: Node, screen_id: String) -> void:
	match screen_id:
		"main_menu":
			main.ui._show_main_menu()
		"quit_dialog":
			main.ui._show_main_menu()
			await process_frame
			main.ui._show_quit_confirmation_dialog()
		"settings_display":
			await _open_settings_tab(main, 0)
		"settings_audio":
			await _open_settings_tab(main, 1)
		"settings_controls":
			await _open_settings_tab(main, 2)
		"hero_select":
			main.call("_show_character_select")
		"weapon_select":
			_prepare_run_state(main)
			main.ui._show_weapon_select()
		"codex":
			main.ui._show_codex_screen()
		"battle_reward":
			_prepare_run_state(main)
			main.ui._show_reward_screen()
		"level_up":
			_prepare_run_state(main)
			main.ui._show_level_up_screen(false)
		"elite_reward":
			_prepare_run_state(main)
			main.set("route_stage", 6)
			main.ui._show_elite_artifact_reward(Callable())
		"shop":
			_prepare_shop_state(main)
			main.call("_show_shop_screen")
		"attribute_shop":
			_prepare_run_state(main)
			main.set("attribute_offer", ["damage", "attack_speed"])
			main.ui._show_attribute_shop(Callable())
		"rest":
			_prepare_run_state(main)
			main.call("_show_rest_screen")
		"upgrade":
			_prepare_run_state(main)
			main.call("_show_upgrade_screen")
		"event":
			_prepare_run_state(main)
			main.ui._show_event_screen({
				"name": "Design review event",
				# SCRUM-995: флагман нового пака (3 карточки, самые длинные тексты).
				"event_id": "caravan_bandits",
			})
		"pause_menu":
			_prepare_run_state(main)
			main.call("_start_combat")
			await process_frame
			main.ui._show_pause_menu()
		"pause_stats":
			_prepare_run_state(main)
			main.call("_start_combat")
			await process_frame
			main.ui._show_pause_menu()
			await process_frame
			main.ui._show_pause_dossier_menu()
		"victory":
			_prepare_run_state(main)
			main.ui._show_victory_screen()
		"death":
			_prepare_run_state(main)
			main.ui._show_death_screen("Design review death state.")
		"combat_hud":
			_prepare_run_state(main)
			main.call("_start_combat")
		"feedback_dialog":
			main.ui._show_main_menu()
			await process_frame
			var preview := Image.create(96, 54, false, Image.FORMAT_RGBA8)
			preview.fill(Color(0.12, 0.10, 0.08, 1.0))
			main.ui._show_feedback_overlay(preview)


func _open_settings_tab(main: Node, tab_index: int) -> void:
	main.call("_show_settings_menu")
	await process_frame
	var tabs := main.find_child("SettingsTabs", true, false) as TabContainer
	if tabs != null:
		tabs.current_tab = tab_index
	await process_frame


func _prepare_run_state(main: Node) -> void:
	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "sword")
	main.set("route_stage", 3)
	main.set("current_node_type", "battle")
	main.set("current_route_choice", "design_review")


func _prepare_shop_state(main: Node) -> void:
	_prepare_run_state(main)
	main.set("current_node_type", "shop")
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var player := player_scene.instantiate()
	main.add_child(player)
	player.configure_character("berserk", "sword")
	player.set("money", 5000)
	main.call("_store_player_snapshot", player)
	player.queue_free()
