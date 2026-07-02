extends "res://tests/runtime_smoke_test.gd"

# SCRUM-815: сквозной smoke «игра проходима с геймпада». Навигация — ТОЛЬКО
# синтетическими joypad-событиями (InputEventJoypadButton/Motion через
# Input.parse_input_event). Тяжёлые переходы состояния (старт боя, форс level-up/
# смерти) выставляются напрямую (это НЕ key/mouse-события) — как в существующих smoke.
# Единственное исключение по key-событию — сценарий (g), где по спеке требуется
# проверить классификацию устройства parse(Key)→keyboard / parse(Joy)→gamepad.
#
# SCRUM-824/SCRUM-825: Start/RB battle actions are now strict regressions here:
# Start must open pause, and RB must open pending level-up through main._input.

const DEADZONE_VALUE := 0.9


func _joy_button(idx: int) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = idx
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	await process_frame
	await process_frame
	var up := InputEventJoypadButton.new()
	up.button_index = idx
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await process_frame


func _joy_axis(axis: int, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	await process_frame


func _focus(main) -> Control:
	var vp: Viewport = main.get_viewport()
	return vp.gui_get_focus_owner() if vp != null else null


func _focus_name(main) -> String:
	var f := _focus(main)
	return str(f.name) if f != null else ""


func _initialize() -> void:
	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main scene did not load for gamepad full-flow smoke.")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	if not await _scenario_a_main_menu(main):
		return
	if not await _scenario_b_hero_to_combat(main):
		return
	if not await _scenario_c_combat_move_and_pause(main):
		return
	if not await _scenario_d_level_up(main):
		return
	if not await _scenario_e_death(main):
		return
	if not await _scenario_f_settings_shoulders(main):
		return
	if not await _scenario_g_device_detection(main):
		return

	main.queue_free()
	await process_frame
	print("Gamepad full-flow smoke passed.")
	quit()


# (a) Главное меню: фокус есть, D-pad ведёт по кнопкам, A открывает выбор героя.
func _scenario_a_main_menu(main) -> bool:
	main.call("clear_run_autosave")  # чтобы «Начать» вело прямо в выбор героя, не в диалог
	main.ui._show_main_menu()
	await process_frame
	await process_frame
	if _focus_name(main) != "MainMenuStartButton":
		_fail("SCRUM-815(a): стартовый фокус главного меню — MainMenuStartButton, получено: %s" % [_focus_name(main)])
		return false
	# D-pad вниз двигает фокус, вверх — возвращает на Start.
	await _joy_button(JOY_BUTTON_DPAD_DOWN)
	if _focus_name(main) == "MainMenuStartButton":
		_fail("SCRUM-815(a): D-pad вниз должен сдвинуть фокус с MainMenuStartButton.")
		return false
	await _joy_button(JOY_BUTTON_DPAD_UP)
	if _focus_name(main) != "MainMenuStartButton":
		_fail("SCRUM-815(a): D-pad вверх должен вернуть фокус на MainMenuStartButton, получено: %s" % [_focus_name(main)])
		return false
	# A на «Начать» → экран выбора героя.
	await _joy_button(JOY_BUTTON_A)
	await process_frame
	if main.find_child("HeroSelectScreen", true, false) == null:
		_fail("SCRUM-815(a): A на «Начать» должен открыть выбор героя (joypad ui_accept).")
		return false
	return true


# (b) Выбор героя: экран проходим с геймпада (D-pad двигает фокус). Тяжёлый переход
# в бой форсируем состоянием (не key/mouse-событие) для стабильности headless.
func _scenario_b_hero_to_combat(main) -> bool:
	var focus_before := _focus_name(main)
	await _joy_button(JOY_BUTTON_DPAD_RIGHT)
	await _joy_button(JOY_BUTTON_DPAD_DOWN)
	# Фокус должен оставаться внутри экрана героя и быть валидным (навигация работает).
	if _focus(main) == null:
		_fail("SCRUM-815(b): на экране выбора героя фокус не должен теряться при D-pad.")
		return false
	# Форс старта боя (состояние, не ввод): герой+оружие+бун.
	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "sword")
	main.set("route_stage", 2)
	main.call("_start_combat")
	await process_frame
	await process_frame
	if not bool(main.get("combat_active")):
		_fail("SCRUM-815(b): бой не стартовал (combat_active=false).")
		return false
	if main.get("current_player") == null:
		_fail("SCRUM-815(b): в бою нет current_player.")
		return false
	return true


# (c) В бою: стик двигает игрока; Start→пауза; B закрывает открытую паузу.
func _scenario_c_combat_move_and_pause(main) -> bool:
	var player: Node2D = main.get("current_player") as Node2D
	if player == null:
		_fail("SCRUM-815(c): нет игрока для проверки движения.")
		return false
	var pos0: Vector2 = player.global_position
	# Синтетический наклон левого стика вправо; несколько физ-кадров.
	await _joy_axis(JOY_AXIS_LEFT_X, DEADZONE_VALUE)
	for i in range(16):
		await process_frame
	var pos1: Vector2 = player.global_position
	await _joy_axis(JOY_AXIS_LEFT_X, 0.0)  # отпустить стик
	if pos1.distance_to(pos0) < 1.0:
		_fail("SCRUM-815(c): левый стик должен двигать игрока (Δ=%.2f, было %s стало %s)." % [pos1.distance_to(pos0), pos0, pos1])
		return false
	await _joy_button(JOY_BUTTON_START)
	await process_frame
	if not main.ui._is_run_pause_overlay_open():
		_fail("SCRUM-824/SCRUM-815(c): joypad Start должен открыть паузу-оверлей в бою.")
		return false
	# B закрывает паузу (joypad ui_cancel — реализовано SCRUM-812).
	await _joy_button(JOY_BUTTON_B)
	await process_frame
	if main.ui._is_run_pause_overlay_open():
		_fail("SCRUM-815(c): B (joypad) должен закрыть паузу-оверлей.")
		return false
	return true


# (d) Level-up: форс доступности; карточка выбирается D-pad и подтверждается A.
func _scenario_d_level_up(main) -> bool:
	main.set("pending_level_ups", 1)
	await _joy_button(JOY_BUTTON_RIGHT_SHOULDER)
	await process_frame
	await process_frame
	var f := _focus(main)
	if f == null or not str(f.name).begins_with("LevelUpRewardButton"):
		_fail("SCRUM-825/SCRUM-815(d): RB должен открыть level-up; стартовый фокус — карточка, получено: %s" % [_focus_name(main)])
		return false
	var pending_before := int(main.get("pending_level_ups"))
	# D-pad вправо (сменить карточку) + A (подтвердить выбор).
	await _joy_button(JOY_BUTTON_DPAD_RIGHT)
	await _joy_button(JOY_BUTTON_A)
	await process_frame
	await process_frame
	if int(main.get("pending_level_ups")) >= pending_before:
		_fail("SCRUM-815(d): A должен применить выбор level-up (pending %d→%d)." % [pending_before, int(main.get("pending_level_ups"))])
		return false
	return true


# (e) Смерть: форс экрана; A на кнопке выхода → главное меню.
func _scenario_e_death(main) -> bool:
	main.ui._show_death_screen()
	await process_frame
	await process_frame
	var f := _focus(main)
	if f == null or str(f.name) != "DeathRetryButton":
		_fail("SCRUM-815(e): стартовый фокус экрана смерти — DeathRetryButton, получено: %s" % [_focus_name(main)])
		return false
	await _joy_button(JOY_BUTTON_A)
	await process_frame
	await process_frame
	if main.find_child("MainMenuActions", true, false) == null:
		_fail("SCRUM-815(e): A на «Начать заново» должен увести в главное меню.")
		return false
	return true


# (f) Настройки из главного меню: LB/RB листают вкладки (SCRUM-813). JOY-ребинд —
# scope SCRUM-816 (rebind принимает только InputEventKey), здесь не тестируется.
func _scenario_f_settings_shoulders(main) -> bool:
	main.ui._show_settings_menu()
	await process_frame
	await process_frame
	if _focus_name(main) != "SettingsTabButton_0":
		_fail("SCRUM-815(f): стартовый фокус настроек — SettingsTabButton_0, получено: %s" % [_focus_name(main)])
		return false
	var settings_root: Node = main.ui_layer.find_child("SettingsV2Root", true, false)
	var containers: Array = settings_root.find_children("*", "TabContainer", true, false) if settings_root != null else []
	if containers.is_empty():
		_fail("SCRUM-815(f): не найден TabContainer настроек.")
		return false
	var tabs := containers[0] as TabContainer
	if tabs.current_tab != 0:
		_fail("SCRUM-815(f): активная вкладка настроек на старте — 0, получено: %d" % [tabs.current_tab])
		return false
	await _joy_button(JOY_BUTTON_RIGHT_SHOULDER)  # RB → следующая вкладка
	if tabs.current_tab != 1:
		_fail("SCRUM-815(f): RB должен переключить вкладку на 1, получено: %d" % [tabs.current_tab])
		return false
	await _joy_button(JOY_BUTTON_LEFT_SHOULDER)  # LB → предыдущая
	if tabs.current_tab != 0:
		_fail("SCRUM-815(f): LB должен вернуть вкладку на 0, получено: %d" % [tabs.current_tab])
		return false
	return true


# (g) InputDeviceManager: parse(Key)→keyboard, parse(Joy)→gamepad (авто-переключение).
# Здесь по спеке допускается InputEventKey — это проверка классификации устройства.
func _scenario_g_device_detection(main) -> bool:
	var mgr: Node = main.get_node_or_null("/root/InputDeviceManager")
	if mgr == null:
		_fail("SCRUM-815(g): автолоад InputDeviceManager не найден.")
		return false
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	mgr.call("_input", key)
	await process_frame
	if str(mgr.call("active_kind")) != "keyboard":
		_fail("SCRUM-815(g): после InputEventKey active_kind должен быть keyboard, получено: %s" % [mgr.call("active_kind")])
		return false
	var jb := InputEventJoypadButton.new()
	jb.button_index = JOY_BUTTON_A
	jb.pressed = true
	mgr.call("_input", jb)
	await process_frame
	if str(mgr.call("active_kind")) != "gamepad":
		_fail("SCRUM-815(g): после InputEventJoypadButton active_kind должен быть gamepad, получено: %s" % [mgr.call("active_kind")])
		return false
	return true
