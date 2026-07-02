extends CanvasLayer
# SCRUM-831: внутриигровая дев-консоль в стиле Slay the Spire 2.
# Тоггл — физическая клавиша слева от «1» (` / ~ на ANSI, § на Mac ISO, Ё на русской
# раскладке), Esc — закрыть, Tab — автодополнение, Up/Down — история команд.
# Пока консоль открыта, игра стоит на паузе (push_pause "dev_console"), а Main._input
# отдаёт консоли весь ввод (ранний return), чтобы буквы команд не дёргали хоткеи
# (P-фидбек, Space-докачка, F12 и т.п.).
# Команды не заводят параллельной логики: идут через те же публичные пути, что и
# обычный геймплей (apply_reward/gain_xp/take_damage/_start_combat/_end_combat).

const PROGRESSION_DATA := preload("res://scripts/progression_data.gd")

const CONSOLE_LAYER := 130  # поверх паузы (120) и фидбек-оверлея (127)
const PAUSE_REASON := "dev_console"
const HISTORY_LIMIT := 64
const SPAWN_COUNT_LIMIT := 24
const TIMESCALE_MIN := 0.05
const TIMESCALE_MAX := 20.0

const COLOR_ECHO := "#ffd866"
const COLOR_OK := "#a9dc76"
const COLOR_INFO := "#d8d8d8"
const COLOR_ERROR := "#ff6188"
const COLOR_ACCENT := "#78dce8"

# Алиасы врагов для spawn — тот же пул сцен, что у боевых волн (ENEMY_SPAWN_WEIGHTS).
const SPAWN_ALIASES := {
	"basic": "res://scenes/Enemy.tscn",
	"runner": "res://scenes/EnemyRunner.tscn",
	"biter": "res://scenes/EnemyBiter.tscn",
	"bruiser": "res://scenes/EnemyBruiser.tscn",
	"shield": "res://scenes/EnemyShield.tscn",
	"flying": "res://scenes/EnemyFlyingRunner.tscn",
	"summoner": "res://scenes/EnemySummoner.tscn",
	"shooter": "res://scenes/EnemyShooter.tscn",
	"mage": "res://scenes/EnemyMage.tscn",
	"spitter": "res://scenes/EnemySpitter.tscn",
	"shaman": "res://scenes/EnemyBoneShaman.tscn",
}

var game: Node2D = null
var _output: RichTextLabel = null
var _input_line: LineEdit = null
var _history: Array[String] = []
var _history_index := -1
# Годмод «липкий»: игрок пересоздаётся на каждом узле маршрута, флаг переносится
# на нового игрока в _process, пока годмод не выключат командой.
var _godmode_sticky := false
var _commands := {}  # имя → {"usage", "desc", "handler": Callable}


func _init(game_ref: Node2D) -> void:
	game = game_ref
	layer = CONSOLE_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_register_commands()
	_build_ui()
	visible = false
	_print_line("[color=%s]FantasyDisk — консоль разработчика. help — список команд, Tab — автодополнение, ~ — закрыть.[/color]" % COLOR_ACCENT)


func is_console_open() -> bool:
	return visible


func toggle_console() -> void:
	if visible:
		close_console()
	else:
		open_console()


func open_console() -> void:
	if visible:
		return
	visible = true
	game.push_pause(PAUSE_REASON)
	_history_index = -1
	_input_line.clear()
	_input_line.grab_focus.call_deferred()


func close_console() -> void:
	if not visible:
		return
	visible = false
	_input_line.release_focus()
	game.pop_pause(PAUSE_REASON)


func get_output_text() -> String:
	return _output.get_parsed_text()


func _process(_delta: float) -> void:
	# Поддержка липкого годмода: новый игрок каждого боя получает флаг заново.
	if not _godmode_sticky:
		return
	var player := _live_player()
	if player != null and not bool(player.get("debug_godmode")):
		player.set("debug_godmode", true)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return

	if _is_toggle_event(key):
		toggle_console()
		get_viewport().set_input_as_handled()
		return

	if not visible:
		return

	match key.keycode:
		KEY_ESCAPE:
			close_console()
			get_viewport().set_input_as_handled()
		KEY_UP:
			_navigate_history(-1)
			get_viewport().set_input_as_handled()
		KEY_DOWN:
			_navigate_history(1)
			get_viewport().set_input_as_handled()
		KEY_TAB:
			_autocomplete()
			get_viewport().set_input_as_handled()


func _is_toggle_event(key: InputEventKey) -> bool:
	# Физическая клавиша слева от «1»: QUOTELEFT (`/~/Ё) или SECTION (§ на Mac ISO).
	if key.physical_keycode == KEY_QUOTELEFT or key.physical_keycode == KEY_SECTION:
		return true
	return key.keycode == KEY_QUOTELEFT or key.keycode == KEY_ASCIITILDE or key.keycode == KEY_SECTION


# --- UI ---------------------------------------------------------------------

func _build_ui() -> void:
	# Полноэкранный перехват мыши: пока консоль открыта, клики не проваливаются
	# в меню/кнопки под ней; клик возвращает фокус в строку ввода.
	var blocker := Control.new()
	blocker.name = "DevConsoleBlocker"
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			_input_line.grab_focus())
	add_child(blocker)

	var panel := PanelContainer.new()
	panel.name = "DevConsolePanel"
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.44
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.11, 0.94)
	style.border_width_bottom = 3
	style.border_color = Color(0.72, 0.60, 0.35, 0.9)
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", style)
	blocker.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	_output = RichTextLabel.new()
	_output.name = "DevConsoleOutput"
	_output.bbcode_enabled = true
	_output.scroll_following = true
	_output.scroll_active = true
	_output.selection_enabled = true
	_output.focus_mode = Control.FOCUS_NONE
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.add_theme_font_size_override("normal_font_size", 26)
	_output.add_theme_font_size_override("bold_font_size", 26)
	_output.add_theme_font_size_override("mono_font_size", 26)
	column.add_child(_output)

	_input_line = LineEdit.new()
	_input_line.name = "DevConsoleInput"
	_input_line.placeholder_text = "команда… (help — список)"
	_input_line.add_theme_font_size_override("font_size", 30)
	_input_line.caret_blink = true
	_input_line.text_submitted.connect(_on_command_submitted)
	column.add_child(_input_line)


func _print_line(bbcode_text: String) -> void:
	_output.append_text(bbcode_text + "\n")


func _print_ok(text: String) -> void:
	_print_line("[color=%s]%s[/color]" % [COLOR_OK, text])


func _print_info(text: String) -> void:
	_print_line("[color=%s]%s[/color]" % [COLOR_INFO, text])


func _print_error(text: String) -> void:
	_print_line("[color=%s]%s[/color]" % [COLOR_ERROR, text])


func _bb_escape(text: String) -> String:
	return text.replace("[", "[lb]")


# --- Ввод/история/автодополнение --------------------------------------------

func _on_command_submitted(text: String) -> void:
	var line := text.strip_edges()
	_input_line.clear()
	_history_index = -1
	if line == "":
		return
	if _history.is_empty() or _history.back() != line:
		_history.append(line)
		while _history.size() > HISTORY_LIMIT:
			_history.pop_front()
	_print_line("[color=%s]> %s[/color]" % [COLOR_ECHO, _bb_escape(line)])
	execute_command(line)


func _navigate_history(direction: int) -> void:
	if _history.is_empty():
		return
	if _history_index == -1:
		if direction > 0:
			return
		_history_index = _history.size() - 1
	else:
		_history_index += direction
	if _history_index >= _history.size():
		_history_index = -1
		_input_line.clear()
		return
	_history_index = clampi(_history_index, 0, _history.size() - 1)
	_input_line.text = _history[_history_index]
	_input_line.caret_column = _input_line.text.length()


func _autocomplete() -> void:
	var prefix := _input_line.text.strip_edges().to_lower()
	if prefix == "" or prefix.contains(" "):
		return
	var matches := _command_matches(prefix)
	if matches.is_empty():
		_print_error("Нет команд на «%s»." % _bb_escape(prefix))
		return
	if matches.size() == 1:
		_input_line.text = matches[0] + " "
		_input_line.caret_column = _input_line.text.length()
		return
	_print_info("Варианты: %s" % ", ".join(matches))


func _command_matches(prefix: String) -> Array:
	var names := _commands.keys()
	names.sort()
	var matches: Array = []
	for name in names:
		if String(name).begins_with(prefix):
			matches.append(String(name))
	return matches


# --- Диспетчер ---------------------------------------------------------------

func execute_command(line: String) -> void:
	var parts := line.split(" ", false)
	if parts.is_empty():
		return
	var name := String(parts[0]).to_lower()
	var args := []
	for index in range(1, parts.size()):
		args.append(String(parts[index]))

	if not _commands.has(name):
		var matches := _command_matches(name)
		if matches.size() == 1:
			name = matches[0]
		else:
			var hint := "" if matches.is_empty() else " Похожие: %s." % ", ".join(matches)
			_print_error("Неизвестная команда «%s». help — список.%s" % [_bb_escape(name), hint])
			return

	var spec: Dictionary = _commands[name]
	(spec["handler"] as Callable).call(args)


func _register(name: String, usage: String, desc: String, handler: Callable) -> void:
	_commands[name] = {"usage": usage, "desc": desc, "handler": handler}


func _register_commands() -> void:
	_register("help", "help [команда]", "Список команд или справка по одной.", _cmd_help)
	_register("clear", "clear", "Очистить лог консоли.", _cmd_clear)
	_register("stats", "stats", "Текущее состояние: класс, HP, золото, уровень, бой.", _cmd_stats)
	_register("gold", "gold <±количество>", "Добавить/отнять золото (работает и на карте между боями).", _cmd_gold)
	_register("xp", "xp <количество>", "Выдать опыт (учитывает xp_gain_multiplier).", _cmd_xp)
	_register("levelup", "levelup [n=1]", "Поднять уровень на n (докачка откроется по Space).", _cmd_levelup)
	_register("heal", "heal [процент=100]", "Вылечить на процент от максимума HP.", _cmd_heal)
	_register("hp", "hp <значение>", "Установить текущее HP (0 — мгновенная смерть).", _cmd_hp)
	_register("maxhp", "maxhp <±значение>", "Изменить максимум HP (плоская прибавка, можно отрицательную).", _cmd_maxhp)
	_register("godmode", "godmode", "Неуязвимость (тумблер, держится между боями).", _cmd_godmode)
	_register("die", "die", "Убить игрока — честное поражение в бою.", _cmd_die)
	_register("kill", "kill [all|bosses|elites]", "Убить врагов на арене (по умолчанию всех).", _cmd_kill)
	_register("win", "win", "Мгновенная победа: убивает всех врагов и завершает бой.", _cmd_win)
	_register("spawn", "spawn <тип> [count=1]", "Заспавнить врагов рядом с игроком. Типы: %s." % ", ".join(SPAWN_ALIASES.keys()), _cmd_spawn)
	_register("artifact", "artifact <add|list> [id|random]", "Выдать артефакт по id (artifact list — все id).", _cmd_artifact)
	_register("ult", "ult", "Зарядить ультимейт на 100%.", _cmd_ult)
	_register("timer", "timer <секунды>", "Установить остаток таймера текущего боя.", _cmd_timer)
	_register("timescale", "timescale [множитель]", "Скорость игры (без аргумента — показать; timescale 1 — вернуть).", _cmd_timescale)
	_register("act", "act <1-%d>" % _act_count(), "Прыгнуть в начало акта (вне боя).", _cmd_act)
	_register("fight", "fight <battle|elite|boss>", "Начать бой выбранного типа прямо сейчас.", _cmd_fight)
	_register("mod", "mod <ключ> <значение> | mod list", "Модификаторы забега: *_multiplier перемножается, остальные складываются.", _cmd_mod)
	_register("debug", "debug", "Режим отладки: ПКМ — плавный телепорт, средняя кнопка — мгновенный.", _cmd_debug)


# --- Хелперы состояния --------------------------------------------------------

func _act_count() -> int:
	var count = game.get("ACT_COUNT") if game != null else null
	return int(count) if count != null else 3


func _live_player() -> Node2D:
	if game != null and game.current_player != null and is_instance_valid(game.current_player):
		return game.current_player
	return null


func _require_player() -> Node2D:
	var player := _live_player()
	if player == null:
		_print_error("Нет активного игрока — команда работает в бою.")
	return player


func _require_combat() -> bool:
	if not game.combat_active:
		_print_error("Команда работает только в активном бою (fight — начать бой).")
		return false
	return true


func _refresh_hud() -> void:
	if game.combat_active and game.ui != null and game.ui.has_method("_update_hud"):
		game.ui._update_hud()


func _parse_number(raw: String, usage: String) -> Variant:
	if not raw.is_valid_float():
		_print_error("Ожидалось число. Использование: %s" % usage)
		return null
	return raw.to_float()


func _kill_group_members(group_names: Array) -> int:
	var seen := {}
	var killed := 0
	for group_name in group_names:
		for node in game.get_tree().get_nodes_in_group(group_name):
			var node_id := node.get_instance_id()
			if seen.has(node_id) or not is_instance_valid(node):
				continue
			seen[node_id] = true
			if node.has_method("take_damage"):
				node.take_damage(9.0e9)
				killed += 1
	return killed


# --- Команды -------------------------------------------------------------------

func _cmd_help(args: Array) -> void:
	if not args.is_empty():
		var name := String(args[0]).to_lower()
		var matches := _command_matches(name)
		if _commands.has(name):
			pass
		elif matches.size() == 1:
			name = matches[0]
		else:
			_print_error("Нет такой команды: «%s»." % _bb_escape(name))
			return
		var spec: Dictionary = _commands[name]
		_print_line("[color=%s]%s[/color] — %s" % [COLOR_ACCENT, spec["usage"], spec["desc"]])
		return
	_print_line("[color=%s]Команды (help <имя> — подробнее):[/color]" % COLOR_ACCENT)
	var names := _commands.keys()
	names.sort()
	for name in names:
		var spec: Dictionary = _commands[name]
		_print_line("  [color=%s]%s[/color] — %s" % [COLOR_ACCENT, name, spec["desc"]])


func _cmd_clear(_args: Array) -> void:
	_output.clear()


func _cmd_stats(_args: Array) -> void:
	var player := _live_player()
	if player != null:
		_print_info("Класс: %s | Уровень: %d | XP: %d/%d" % [
			str(player.get("character_id")), int(player.get("level")),
			int(player.get("xp")), int(player.get("xp_to_next"))])
		_print_info("HP: %.0f/%.0f | Золото: %d | Ульта: %.0f%%" % [
			float(player.get("health")), float(player.get("max_health")),
			int(player.get("money")),
			100.0 * float(player.get("ultimate_charge")) / maxf(float(player.get("ultimate_max_charge")), 1.0)])
		_print_info("Артефактов: %d | Годмод: %s" % [
			(player.get("artifacts") as Array).size(), "ON" if _godmode_sticky else "OFF"])
	elif not game.run_player_snapshot.is_empty():
		var snapshot: Dictionary = game.run_player_snapshot
		_print_info("Забег (между боями): %s, уровень %d, HP %.0f/%.0f, золото %d" % [
			str(snapshot.get("character_id", "?")), int(snapshot.get("level", 1)),
			float(snapshot.get("health", 0.0)), float(snapshot.get("max_health", 0.0)),
			int(snapshot.get("money", 0))])
	else:
		_print_info("Забег не начат (главное меню).")
	var combat_state := "нет"
	if game.combat_active:
		combat_state = "%s, осталось %.1fс" % [str(game.current_combat_type), maxf(game.round_time_left, 0.0)]
	_print_info("Акт %d, узел %d | Бой: %s | timescale ×%.2f" % [
		game.current_act, game.route_stage, combat_state, Engine.time_scale])


func _cmd_gold(args: Array) -> void:
	if args.is_empty():
		_print_error("Использование: gold <±количество>")
		return
	var amount = _parse_number(String(args[0]), "gold <±количество>")
	if amount == null:
		return
	var delta := int(amount)
	var player := _live_player()
	if player != null:
		player.set("money", maxi(0, int(player.get("money")) + delta))
		_refresh_hud()
		_print_ok("Золото: %d (%+d)" % [int(player.get("money")), delta])
	elif not game.run_player_snapshot.is_empty():
		var money := maxi(0, int(game.run_player_snapshot.get("money", 0)) + delta)
		game.run_player_snapshot["money"] = money
		_print_ok("Золото (снапшот забега): %d (%+d)" % [money, delta])
	else:
		_print_error("Нет ни игрока, ни активного забега.")


func _cmd_xp(args: Array) -> void:
	var player := _require_player()
	if player == null:
		return
	if args.is_empty():
		_print_error("Использование: xp <количество>")
		return
	var amount = _parse_number(String(args[0]), "xp <количество>")
	if amount == null or int(amount) <= 0:
		_print_error("Количество XP должно быть положительным.")
		return
	var old_level := int(player.get("level"))
	player.gain_xp(int(amount))
	_refresh_hud()
	_print_ok("XP выдан. Уровень: %d → %d (докачка — Space)." % [old_level, int(player.get("level"))])


func _cmd_levelup(args: Array) -> void:
	var player := _require_player()
	if player == null:
		return
	var times := 1
	if not args.is_empty():
		var amount = _parse_number(String(args[0]), "levelup [n=1]")
		if amount == null:
			return
		times = clampi(int(amount), 1, 50)
	var old_level := int(player.get("level"))
	for _index in range(times):
		player.gain_xp(maxi(int(player.get("xp_to_next")) - int(player.get("xp")), 1))
	_refresh_hud()
	_print_ok("Уровень: %d → %d (докачка — Space)." % [old_level, int(player.get("level"))])


func _cmd_heal(args: Array) -> void:
	var player := _require_player()
	if player == null:
		return
	var percent := 100.0
	if not args.is_empty():
		var amount = _parse_number(String(args[0]), "heal [процент=100]")
		if amount == null:
			return
		percent = clampf(float(amount), 1.0, 100.0)
	player.heal_percent(percent / 100.0)
	_refresh_hud()
	_print_ok("HP: %.0f/%.0f" % [float(player.get("health")), float(player.get("max_health"))])


func _cmd_hp(args: Array) -> void:
	var player := _require_player()
	if player == null:
		return
	if args.is_empty():
		_print_error("Использование: hp <значение>")
		return
	var amount = _parse_number(String(args[0]), "hp <значение>")
	if amount == null:
		return
	var value := float(amount)
	if value <= 0.0:
		_cmd_die([])
		return
	player.set("health", minf(value, float(player.get("max_health"))))
	_refresh_hud()
	_print_ok("HP: %.0f/%.0f" % [float(player.get("health")), float(player.get("max_health"))])


func _cmd_maxhp(args: Array) -> void:
	var player := _require_player()
	if player == null:
		return
	if args.is_empty():
		_print_error("Использование: maxhp <±значение>")
		return
	var amount = _parse_number(String(args[0]), "maxhp <±значение>")
	if amount == null:
		return
	var old_max := float(player.get("max_health"))
	player.apply_reward({"mods": {"max_health_flat": float(amount)}})
	_refresh_hud()
	_print_ok("Максимум HP: %.0f → %.0f" % [old_max, float(player.get("max_health"))])


func _cmd_godmode(_args: Array) -> void:
	_godmode_sticky = not _godmode_sticky
	var player := _live_player()
	if player != null:
		player.set("debug_godmode", _godmode_sticky)
	_print_ok("Годмод: %s" % ("ON — игрок неуязвим (держится между боями)" if _godmode_sticky else "OFF"))


func _cmd_die(_args: Array) -> void:
	if not _require_combat():
		return
	var player := _require_player()
	if player == null:
		return
	_godmode_sticky = false
	player.set("debug_godmode", false)
	player.set("health", 0.0)
	_print_ok("Игрок убит — поражение.")
	close_console()
	# Тот же порядок, что у смертельного take_damage: сигнал смерти, затем очистка.
	player.emit_signal("died")
	if is_instance_valid(player):
		player.queue_free()


func _cmd_kill(args: Array) -> void:
	var what := "all" if args.is_empty() else String(args[0]).to_lower()
	var groups: Array = []
	match what:
		"all":
			groups = ["enemies", "bosses", "elite_enemies"]
		"bosses":
			groups = ["bosses"]
		"elites":
			groups = ["elite_enemies"]
		_:
			_print_error("Использование: kill [all|bosses|elites]")
			return
	var killed := _kill_group_members(groups)
	if killed == 0:
		_print_info("Убивать некого (%s)." % what)
	else:
		_print_ok("Убито врагов: %d." % killed)


func _cmd_win(_args: Array) -> void:
	if not _require_combat():
		return
	# Сначала зачистка арены: смерть элитки честно взводит _elite_defeated (награда
	# элитного узла), смерть босса идёт обычным died-флоу с кодексом и метриками.
	_kill_group_members(["enemies", "bosses", "elite_enemies"])
	_print_ok("Победа: бой завершён.")
	close_console()
	game.combat._end_combat(true)


func _cmd_spawn(args: Array) -> void:
	if not _require_combat():
		return
	if args.is_empty():
		_print_error("Использование: spawn <тип> [count=1]. Типы: %s." % ", ".join(SPAWN_ALIASES.keys()))
		return
	var alias := String(args[0]).to_lower()
	if not SPAWN_ALIASES.has(alias):
		_print_error("Неизвестный тип «%s». Типы: %s." % [_bb_escape(alias), ", ".join(SPAWN_ALIASES.keys())])
		return
	var count := 1
	if args.size() > 1:
		var amount = _parse_number(String(args[1]), "spawn <тип> [count=1]")
		if amount == null:
			return
		count = clampi(int(amount), 1, SPAWN_COUNT_LIMIT)
	var scene := load(String(SPAWN_ALIASES[alias])) as PackedScene
	if scene == null:
		_print_error("Сцена врага не загрузилась: %s" % String(SPAWN_ALIASES[alias]))
		return
	var player := _live_player()
	var base_position: Vector2 = player.global_position if player != null else game.ARENA_CENTER
	for _index in range(count):
		var offset: Vector2 = Vector2.RIGHT.rotated(float(game.rng.randf()) * TAU) * float(game.rng.randf_range(320.0, 460.0))
		var spawn_position: Vector2 = game._clamp_arena_point(base_position + offset)
		game.combat._spawn_random_enemy(scene, spawn_position, true)
	_print_ok("Заспавнено: %d × %s." % [count, alias])


func _cmd_artifact(args: Array) -> void:
	if args.is_empty():
		_print_error("Использование: artifact <add|list> [id|random]")
		return
	var sub := String(args[0]).to_lower()
	if sub == "list":
		_print_line("[color=%s]Артефакты (%d):[/color]" % [COLOR_ACCENT, PROGRESSION_DATA.ARTIFACTS.size()])
		for artifact in PROGRESSION_DATA.ARTIFACTS:
			_print_info("  %s — %s (тир %d)" % [str(artifact.get("id")), str(artifact.get("title")), int(artifact.get("tier", 1))])
		return
	if sub != "add":
		_print_error("Использование: artifact <add|list> [id|random]")
		return
	var player := _require_player()
	if player == null:
		return
	if args.size() < 2:
		_print_error("Использование: artifact add <id|random> (artifact list — все id)")
		return
	var artifact_id := String(args[1]).to_lower()
	var definition := {}
	if artifact_id == "random":
		definition = PROGRESSION_DATA.ARTIFACTS[game.rng.randi_range(0, PROGRESSION_DATA.ARTIFACTS.size() - 1)]
	else:
		for artifact in PROGRESSION_DATA.ARTIFACTS:
			if str(artifact.get("id")) == artifact_id:
				definition = artifact
				break
	if definition.is_empty():
		_print_error("Артефакт «%s» не найден (artifact list — все id)." % _bb_escape(artifact_id))
		return
	var reward: Dictionary = definition.duplicate(true)
	reward["kind"] = "artifact"
	player.apply_reward(reward)
	if game.has_method("record_codex_artifact_discovery"):
		game.record_codex_artifact_discovery(reward)
	_refresh_hud()
	_print_ok("Артефакт добавлен: %s (%s)." % [str(definition.get("title")), str(definition.get("id"))])


func _cmd_ult(_args: Array) -> void:
	var player := _require_player()
	if player == null:
		return
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_refresh_hud()
	_print_ok("Ультимейт заряжен на 100% (кнопка R).")


func _cmd_timer(args: Array) -> void:
	if not _require_combat():
		return
	if args.is_empty():
		_print_error("Использование: timer <секунды>")
		return
	var amount = _parse_number(String(args[0]), "timer <секунды>")
	if amount == null:
		return
	game.round_time_left = maxf(float(amount), 0.0)
	_print_ok("Таймер боя: %.1fс." % game.round_time_left)


func _cmd_timescale(args: Array) -> void:
	if args.is_empty():
		_print_info("Текущий timescale: ×%.2f" % Engine.time_scale)
		return
	var amount = _parse_number(String(args[0]), "timescale [множитель]")
	if amount == null:
		return
	Engine.time_scale = clampf(float(amount), TIMESCALE_MIN, TIMESCALE_MAX)
	_print_ok("Скорость игры: ×%.2f (timescale 1 — вернуть)." % Engine.time_scale)


func _cmd_act(args: Array) -> void:
	if game.combat_active:
		_print_error("Сначала заверши бой (win или die).")
		return
	if args.is_empty():
		_print_error("Использование: act <1-%d>" % _act_count())
		return
	var amount = _parse_number(String(args[0]), "act <1-%d>" % _act_count())
	if amount == null:
		return
	var act := int(amount)
	if act < 1 or act > _act_count():
		_print_error("Акт должен быть от 1 до %d." % _act_count())
		return
	# Тот же сброс состояния, что у advance_to_next_act, но с произвольным актом.
	game.current_act = act
	game.route_stage = 0
	game.route_nodes = game.route._generate_route()
	game.route_selected_indices.clear()
	game.current_route_choice = ""
	game.current_node_type = ""
	game.current_combat_type = "battle"
	game.current_boss_id = "rift_warden"
	game.secret_boss_active = false
	game.current_node_seed = 0
	game.pending_event_combat.clear()
	game.level_up_return_to_map = false
	game.level_up_return_to_event = false
	game.shop_reentry_pending = false
	game.shop_reentry_route_stage = -1
	game.shop_reentry_branch_index = -1
	game.current_shop_items.clear()
	game.current_shop_purchased.clear()
	game.current_shop_node_key = ""
	if game.has_method("save_run_autosave"):
		game.save_run_autosave("dev_console_act")
	_print_ok("Прыжок в акт %d." % act)
	close_console()
	game.route._show_battle_map()


func _cmd_fight(args: Array) -> void:
	if game.combat_active:
		_print_error("Бой уже идёт (win — завершить победой).")
		return
	if args.is_empty():
		_print_error("Использование: fight <battle|elite|boss>")
		return
	var combat_type := String(args[0]).to_lower()
	if combat_type not in ["battle", "elite", "boss"]:
		_print_error("Тип боя: battle, elite или boss.")
		return
	_print_ok("Бой начат: %s." % combat_type)
	close_console()
	game.combat._start_combat(combat_type == "boss", combat_type)


func _cmd_mod(args: Array) -> void:
	var player := _require_player()
	if player == null:
		return
	var run_modifiers: Dictionary = player.get("run_modifiers")
	if args.is_empty() or String(args[0]).to_lower() == "list":
		_print_line("[color=%s]run_modifiers (%d):[/color]" % [COLOR_ACCENT, run_modifiers.size()])
		var keys := run_modifiers.keys()
		keys.sort()
		for key in keys:
			_print_info("  %s = %.3f" % [key, float(run_modifiers[key])])
		return
	if args.size() < 2:
		_print_error("Использование: mod <ключ> <значение> | mod list")
		return
	var key := String(args[0])
	if not run_modifiers.has(key):
		_print_error("Неизвестный ключ «%s» (mod list — все ключи)." % _bb_escape(key))
		return
	var amount = _parse_number(String(args[1]), "mod <ключ> <значение>")
	if amount == null:
		return
	var old_value := float(run_modifiers[key])
	player.apply_reward({"mods": {key: float(amount)}})
	_refresh_hud()
	_print_ok("%s: %.3f → %.3f%s" % [key, old_value, float((player.get("run_modifiers") as Dictionary)[key]),
		" (множитель перемножен)" if key.ends_with("_multiplier") else ""])


func _cmd_debug(_args: Array) -> void:
	game.debug_mode_enabled = not game.debug_mode_enabled
	if game.has_method("save_game_settings"):
		game.save_game_settings()
	if game.debug_mode_enabled:
		_print_ok("Режим отладки ON: в бою ПКМ/Shift+ЛКМ — плавный телепорт, средняя кнопка — мгновенный.")
	else:
		_print_ok("Режим отладки OFF.")
