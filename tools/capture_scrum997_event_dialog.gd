extends SceneTree

## SCRUM-997: оконный капчер иллюстрированного экрана события.
## 3 разрешения × 3 состояния (normal / hidden / reveal) →
## docs/design/previews/scrum997_event_dialog_<WxH>_<state>.png + rects.md.
## Run (ОКОННО — headless не рисует): Godot --path . --script res://tools/capture_scrum997_event_dialog.gd

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")

const VIEWPORT_SIZES := [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

const RECT_NODES := [
	"MenuPanel_event", "EventContent", "EventTitle", "EventStory",
	"EventChoiceRow", "EventChoiceButton0", "EventChoiceButton1", "EventChoiceButton2",
	"EventChoiceButton0Hint", "EventChoiceButton1Hint", "EventChoiceButton2Hint",
	"EventBackButton", "EventContinueButton", "ScreenBackground_event",
]

# Синтетика для hidden-состояния (пул SCRUM-995 ещё едет параллельно):
# id = sacrifice_altar → родной арт пака SCRUM-998.
const HIDDEN_EVENT := {
	"id": "sacrifice_altar",
	"title": "Алтарь жертвоприношений",
	"story": "Чёрный монолит дышит холодом. Багровые руны на его гранях просыпаются, когда ты подходишь ближе, и воздух наполняется запахом железа. Алтарь ждёт подношения — и шёпот обещает силу тем, кто не торгуется.",
	"allow_skip": true,
	"choices": [
		{"id": "offer_blood", "title": "Отдать кровь", "description": "Полоснуть ладонь над рунами и позволить алтарю пить.", "health_percent_cost": 0.18, "stats": {"strength": 2}, "mods": {"damage_multiplier": 1.08}},
		{"id": "whisper_name", "title": "Прошептать имя", "hidden": true, "unknown_hint": "Алтарь хочет услышать имя. Чьё — он не говорит, и цену тоже.", "outcome_text": "Ты называешь имя старого врага. Руны вспыхивают, и тяжесть уходит из плеч.", "money": 30},
		{"id": "scrape_runes", "title": "Соскоблить руны", "description": "Попробовать унести частицу силы с собой.", "check": {"stat": "knowledge", "difficulty": 7}, "success": {"stats": {"knowledge": 1}}, "failure": {"health_percent_cost": 0.10}},
	],
}

# Синтетика для reveal-состояния: check + outcome_text (полный формат раскрытия),
# id = cursed_chapel → родной арт пака.
const REVEAL_EVENT := {
	"id": "cursed_chapel",
	"title": "Проклятая часовня",
	"story": "Лунный свет льётся сквозь разбитый витраж на заваленные скамьи. Из-под опечатанной двери крипты сочится фиолетовое свечение.",
	"choices": [
		{"id": "break_seal", "title": "Сорвать печать", "description": "Цепи стары, а свечение манит.", "check": {"stat": "strength", "difficulty": 7}, "success": {"outcome_text": "Цепи лопаются, и из крипты выкатывается ларец с монетами старой чеканки. Свечение гаснет — что бы там ни жило, оно ушло раньше тебя.", "money": 40}, "failure": {"outcome_text": "Цепи держат.", "health_percent_cost": 0.10}},
		{"id": "pray", "title": "Помолиться", "description": "Слова старой молитвы сами приходят на язык.", "heal_percent": 0.25},
		{"id": "leave", "title": "Уйти тихо", "description": "Не всякую дверь стоит открывать.", "money": 5},
	],
}


func _initialize() -> void:
	var out_dir := ProjectSettings.globalize_path("res://docs/design/previews")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var dump_lines := PackedStringArray()
	dump_lines.append("# SCRUM-997 event dialog capture — rects")
	dump_lines.append("")
	if DisplayServer.get_name() == "headless":
		push_error("SCRUM-997 capture требует ОКОННЫЙ запуск (headless не рисует PNG).")
		quit(1)
		return
	for viewport_size in VIEWPORT_SIZES:
		await _capture_state(viewport_size, "normal", out_dir, dump_lines)
		await _capture_state(viewport_size, "hidden", out_dir, dump_lines)
		await _capture_state(viewport_size, "reveal", out_dir, dump_lines)
	var file := FileAccess.open("%s/scrum997_event_dialog_rects.md" % out_dir, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(dump_lines))
		file.close()
	print("SCRUM-997 event dialog capture done.")
	quit(0)


func _capture_state(viewport_size: Vector2i, state: String, out_dir: String, dump_lines: PackedStringArray) -> void:
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
	main.set("route_stage", 0)
	var player := PLAYER_SCENE.instantiate()
	root.add_child(player)
	player.configure_character("berserk", "sword")
	player.set("money", 137)
	var stats: Dictionary = player.get("stats")
	for stat_id in stats.keys():
		stats[stat_id] = 12
	player.set("stats", stats)
	main.combat._store_player_snapshot(player)
	player.queue_free()
	await process_frame
	match state:
		"normal":
			main.ui._show_event_screen({"type": "event", "name": "Событие", "event_id": "sudden_fork"})
		"hidden":
			main.set("current_event_definition", HIDDEN_EVENT.duplicate(true))
			main.ui._show_event_screen({"type": "event", "name": "Событие"})
		"reveal":
			main.set("current_event_definition", REVEAL_EVENT.duplicate(true))
			main.ui._show_event_screen({"type": "event", "name": "Событие"})
			for _i in range(4):
				await process_frame
			var check_card := main.find_child("EventChoiceButton0", true, false) as Button
			if check_card != null:
				check_card.pressed.emit()
	for _i in range(10):
		await process_frame
	var output_path := "%s/scrum997_event_dialog_%dx%d_%s.png" % [out_dir, viewport_size.x, viewport_size.y, state]
	var image := viewport.get_texture().get_image()
	if image != null:
		image.save_png(output_path)
	dump_lines.append("## %dx%d %s" % [viewport_size.x, viewport_size.y, state])
	dump_lines.append("| node | global rect | visible |")
	dump_lines.append("| --- | --- | --- |")
	for node_name in RECT_NODES:
		var node := main.find_child(str(node_name), true, false) as Control
		if node != null:
			dump_lines.append("| `%s` | `%s` | %s |" % [node_name, str(node.get_global_rect()), str(node.is_visible_in_tree())])
	dump_lines.append("")
	main.queue_free()
	viewport.queue_free()
	await process_frame
