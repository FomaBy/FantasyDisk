extends SceneTree

# FAN-1449: боевая проводка ручного прицеливания в Player.
#
# Матрица оружий (`tests/aim_controller_weapon_matrix_test.gd`) проверяет
# контракт наводки, а здесь — рантайм вокруг него: выбор устройства по правому
# стику, виртуальный прицел, hot-plug и то, что дебажные ПКМ/Shift+ЛКМ и
# ручное прицеливание не мешают друг другу.

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const AimController := preload("res://scripts/input/aim_controller.gd")

const PLAYER_POSITION := Vector2(1500.0, 1100.0)
const FRAME := 1.0 / 60.0

var _errors: Array[String] = []


func _initialize() -> void:
	await _run()
	_release_right_stick()
	root.set_meta("aim_mode", "nearest")
	if not _errors.is_empty():
		for error in _errors:
			push_error("aim_controller_runtime_test: %s" % error)
		quit(1)
		return
	print("aim_controller_runtime_test passed.")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _run() -> void:
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	if player == null:
		_expect(false, "Player.tscn не инстанцировалась")
		return
	root.add_child(player)
	player.global_position = PLAYER_POSITION
	root.set_meta("gamepad_deadzone", 0.25)
	await process_frame

	_check_setup(player)
	# Порядок важен: «мышь без пада» проверяется до первого наклона стика,
	# иначе наводка уже законно принадлежит геймпаду.
	await _check_manual_mouse_keeps_reticle_hidden(player)
	await _check_auto_mode_has_no_reticle(player)
	await _check_manual_stick_drives_reticle(player)
	await _check_neutral_stick_holds_aim(player)
	await _check_hot_unplug_clears_reticle(player)
	await _check_debug_move_does_not_fight_aim(player)

	player.queue_free()


func _check_setup(player: CharacterBody2D) -> void:
	for action_name in AimController.AIM_ACTIONS:
		_expect(InputMap.has_action(action_name), "Player не создал экшен наводки %s" % action_name)
	var reticle := player.get_node_or_null("VirtualReticle")
	_expect(reticle != null, "Player не создал узел виртуального прицела")
	if reticle != null:
		_expect(bool(reticle.get("top_level")), "прицел обязан быть top_level, иначе едет вместе с героем")
		_expect(not reticle.visible, "свежий прицел обязан быть скрыт")


func _check_auto_mode_has_no_reticle(player: CharacterBody2D) -> void:
	root.set_meta("aim_mode", "nearest")
	_send_right_stick(0.0, -0.95)
	await _tick(player)
	_expect(str(player.call("attack_aim_mode")) == "nearest", "режим из root-меты не доехал до Player")
	_expect(not bool(_aim_of(player).reticle_visible()),
		"в авто-наводке прицел показываться не должен")
	var reticle := player.get_node_or_null("VirtualReticle")
	_expect(reticle == null or not reticle.visible, "узел прицела обязан быть скрыт в авто-наводке")
	# Авто-наводка не трогает направление, посчитанное оружием.
	var resolved: Vector2 = player.call("attack_aim_direction", Vector2.LEFT, 320.0)
	_expect(resolved.dot(Vector2.LEFT) > 0.999,
		"авто-наводка обязана вернуть направление оружия, получено %s" % resolved)
	_release_right_stick()
	await _tick(player)


func _check_manual_mouse_keeps_reticle_hidden(player: CharacterBody2D) -> void:
	root.set_meta("aim_mode", "cursor")
	_release_right_stick()
	await _tick(player)
	_expect(str(_aim_of(player).device()) == AimController.DEVICE_MOUSE,
		"без ввода со стика устройство наводки обязано остаться мышью, получено %s" % _aim_of(player).device())
	_expect(not bool(_aim_of(player).reticle_visible()),
		"у мыши свой курсор — виртуальный прицел не рисуется")


func _check_manual_stick_drives_reticle(player: CharacterBody2D) -> void:
	root.set_meta("aim_mode", "cursor")
	_send_right_stick(0.0, 0.95)
	await _tick(player)

	_expect(str(_aim_of(player).device()) == AimController.DEVICE_GAMEPAD,
		"наклон правого стика обязан переключить наводку на геймпад, получено %s" % _aim_of(player).device())
	_expect(bool(_aim_of(player).reticle_visible()),
		"ручная наводка со стика обязана показать прицел")

	var direction: Vector2 = player.call("attack_aim_direction", Vector2.LEFT, 320.0)
	_expect(direction.dot(Vector2.DOWN) > 0.99,
		"стик вниз обязан целиться вниз, получено %s" % direction)
	var point: Vector2 = player.call("attack_aim_position", 320.0)
	_expect(PLAYER_POSITION.distance_to(point) <= 320.0 + 0.01,
		"точка наводки обязана держаться в дальности оружия, получено %.2f" % PLAYER_POSITION.distance_to(point))

	var reticle_position: Vector2 = _aim_of(player).reticle_position()
	_expect((reticle_position - PLAYER_POSITION).normalized().dot(Vector2.DOWN) > 0.99,
		"прицел обязан стоять по направлению стика, получено %s" % reticle_position)

	# Смена направления стика ведёт прицел, а не телепортирует его в героя.
	_send_right_stick(0.95, 0.0)
	await _tick(player)
	var turned: Vector2 = player.call("attack_aim_direction", Vector2.LEFT, 320.0)
	_expect(turned.dot(Vector2.RIGHT) > 0.99, "стик вправо обязан развернуть наводку, получено %s" % turned)


func _check_neutral_stick_holds_aim(player: CharacterBody2D) -> void:
	_send_right_stick(0.95, 0.0)
	await _tick(player)
	var before: Vector2 = player.call("attack_aim_direction", Vector2.LEFT, 320.0)
	# Отпущенный стик — «неизвестный» ввод: наводка обязана замереть, а не
	# дрожать между facing и последним направлением от кадра к кадру.
	_release_right_stick()
	var samples: Array[Vector2] = []
	for _index in range(4):
		await _tick(player)
		samples.append(player.call("attack_aim_direction", Vector2.LEFT, 320.0))
	for sample in samples:
		_expect(sample.is_equal_approx(before),
			"нейтраль правого стика обязана удерживать наводку: было %s, стало %s" % [before, sample])
	_expect(bool(_aim_of(player).reticle_visible()),
		"на нейтрали прицел не должен мигать — устройство осталось геймпадом")


func _check_hot_unplug_clears_reticle(player: CharacterBody2D) -> void:
	_expect(bool(_aim_of(player).reticle_visible()), "перед hot-unplug прицел обязан быть виден")
	# Выдернули последний пад: Godot шлёт joy_connection_changed(device, false).
	player.call("_on_aim_joy_connection_changed", 0, false)
	_expect(str(_aim_of(player).device()) == AimController.DEVICE_MOUSE,
		"hot-unplug обязан вернуть наводку мыши, получено %s" % _aim_of(player).device())
	_expect(not bool(_aim_of(player).reticle_visible()), "hot-unplug обязан погасить прицел")
	var reticle := player.get_node_or_null("VirtualReticle")
	_expect(reticle == null or not reticle.visible, "узел прицела обязан скрыться сразу после hot-unplug")

	# Следующий кадр без пада не должен «воскрешать» прицел сам по себе.
	_release_right_stick()
	await _tick(player)
	_expect(not bool(_aim_of(player).reticle_visible()), "без пада прицел обязан остаться скрытым")


func _check_debug_move_does_not_fight_aim(player: CharacterBody2D) -> void:
	# Дебаг-перемещение (ПКМ / Shift+ЛКМ) живёт на кнопках мыши, ручная наводка —
	# на позиции курсора и правом стике. Проверяем, что каналы не конфликтуют:
	# клик ставит точку движения и штатно возвращает наводку мыши, а следующий
	# наклон стика забирает её обратно — без застрявшего прицела.
	root.set_meta("aim_mode", "cursor")
	_send_right_stick(0.0, 0.95)
	await _tick(player)
	_expect(str(_aim_of(player).device()) == AimController.DEVICE_GAMEPAD,
		"перед проверкой дебага наводка обязана быть на стике, получено %s" % _aim_of(player).device())

	var target := PLAYER_POSITION + Vector2(-260.0, 120.0)
	player.call("debug_set_move_target", target)
	_expect(bool(player.call("debug_has_move_target")), "ПКМ-цель обязана ставиться при ручной наводке")
	_expect(Vector2(player.call("debug_move_target_position")).is_equal_approx(target),
		"ручная наводка не должна подменять дебажную точку движения")

	# Клик мыши — это ввод «клавиатура и мышь»: наводка возвращается курсору,
	# прицел стика гаснет, но дебажная точка остаётся нетронутой.
	_send_mouse_button(MOUSE_BUTTON_RIGHT, false)
	_send_mouse_button(MOUSE_BUTTON_LEFT, true)
	await _tick(player)
	_expect(str(_aim_of(player).device()) == AimController.DEVICE_MOUSE,
		"после клика наводка обязана вернуться мыши, получено %s" % _aim_of(player).device())
	_expect(not bool(_aim_of(player).reticle_visible()),
		"после клика прицел стика обязан погаснуть, а не залипнуть")
	_expect(bool(player.call("debug_has_move_target")), "клик не должен стирать дебажную точку движения")
	_expect(Vector2(player.call("debug_move_target_position")).is_equal_approx(target),
		"прицеливание не должно двигать дебажную точку")
	var mouse_direction: Vector2 = player.call("attack_aim_direction", Vector2.LEFT, 320.0)
	_expect(mouse_direction.length() > 0.99, "наводка мыши обязана давать нормализованное направление, получено %s" % mouse_direction)

	# Обратный переход: стик снова забирает наводку и прицел зажигается.
	_send_right_stick(-0.95, 0.0)
	await _tick(player)
	_expect(str(_aim_of(player).device()) == AimController.DEVICE_GAMEPAD,
		"стик обязан забрать наводку обратно после клика, получено %s" % _aim_of(player).device())
	_expect(bool(_aim_of(player).reticle_visible()), "после возврата на стик прицел обязан снова гореть")
	_expect(Vector2(player.call("attack_aim_direction", Vector2.LEFT, 320.0)).dot(Vector2.LEFT) > 0.99,
		"стик влево обязан целиться влево")

	player.call("_clear_debug_move_target")
	_release_right_stick()
	await _tick(player)


func _aim_of(player: CharacterBody2D) -> RefCounted:
	# Провайдер живёт в player._aim: адаптер намеренно тонкий и своих
	# аксессоров не держит (ratchet на размер player.gd).
	return player.get("_aim") as RefCounted


func _tick(player: CharacterBody2D) -> void:
	player.call("_physics_process", FRAME)
	await process_frame


func _send_right_stick(x: float, y: float) -> void:
	for axis_value in [[JOY_AXIS_RIGHT_X, x], [JOY_AXIS_RIGHT_Y, y]]:
		var event := InputEventJoypadMotion.new()
		event.device = 0
		event.axis = axis_value[0]
		event.axis_value = axis_value[1]
		Input.parse_input_event(event)
	Input.flush_buffered_events()


func _release_right_stick() -> void:
	_send_right_stick(0.0, 0.0)


func _send_mouse_button(button_index: int, shift: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button_index as MouseButton
	event.pressed = true
	event.shift_pressed = shift
	Input.parse_input_event(event)
	var release := InputEventMouseButton.new()
	release.button_index = button_index as MouseButton
	release.pressed = false
	release.shift_pressed = shift
	Input.parse_input_event(release)
	Input.flush_buffered_events()
