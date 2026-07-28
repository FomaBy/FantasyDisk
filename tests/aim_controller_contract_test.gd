extends SceneTree

# FAN-1449: контракт канонического провайдера прицеливания.
# Чистая проверка геометрии наводки без сцен: режимы, deadzone правого стика,
# удержание последнего направления на нейтрали, клампы дальности и кадра,
# hot-unplug и идемпотентность экшенов aim_*.

const AimController := preload("res://scripts/input/aim_controller.gd")

const ORIGIN := Vector2(400.0, 300.0)

var _errors: Array[String] = []


func _initialize() -> void:
	_check_mode_normalization()
	_check_auto_mode_fallbacks()
	_check_mouse_geometry()
	_check_stick_deadzone()
	_check_neutral_hold_is_stable()
	_check_range_clamp()
	_check_view_clamp()
	_check_hot_unplug()
	_check_reticle_visibility()
	_check_aim_actions_idempotent()

	if not _errors.is_empty():
		for error in _errors:
			push_error("aim_controller_contract_test: %s" % error)
		quit(1)
		return
	print("aim_controller_contract_test passed.")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _manual_gamepad(stick: Vector2) -> AimController:
	var aim := AimController.new()
	aim.set_mode(AimController.MODE_MANUAL)
	aim.set_device(AimController.DEVICE_GAMEPAD)
	if stick != Vector2.ZERO:
		aim.update_stick(stick)
	return aim


func _check_mode_normalization() -> void:
	_expect(AimController.normalize_mode("cursor") == AimController.MODE_MANUAL,
		"cursor должен нормализоваться в ручной режим")
	_expect(AimController.normalize_mode("nearest") == AimController.MODE_AUTO,
		"nearest должен нормализоваться в авто-режим")
	_expect(AimController.normalize_mode("сломано") == AimController.MODE_AUTO,
		"неизвестный режим обязан падать в авто-наводку")
	_expect(AimController.normalize_mode(null) == AimController.MODE_AUTO,
		"null-режим обязан падать в авто-наводку")

	var aim := AimController.new()
	_expect(aim.mode() == AimController.MODE_AUTO, "дефолт провайдера — авто-наводка")
	_expect(aim.device() == AimController.DEVICE_MOUSE, "дефолт устройства — мышь")
	_expect(not aim.is_manual(), "свежий провайдер не в ручном режиме")


func _check_auto_mode_fallbacks() -> void:
	var aim := AimController.new()
	aim.set_mode(AimController.MODE_AUTO)
	# Авто-наводка не трогает направление, которое посчитало оружие.
	var nearest := Vector2(0.0, -1.0)
	var resolved := aim.aim_direction(ORIGIN, nearest, 320.0, Vector2.RIGHT, Vector2(1000.0, 300.0))
	_expect(resolved.dot(nearest) > 0.999, "авто-наводка обязана вернуть направление на цель, получено %s" % resolved)

	# Пустой default → facing; пустой facing → RIGHT. Ноль направления невозможен.
	var from_facing := aim.aim_direction(ORIGIN, Vector2.ZERO, 320.0, Vector2.DOWN, Vector2(1000.0, 300.0))
	_expect(from_facing.dot(Vector2.DOWN) > 0.999, "без цели авто-наводка обязана взять facing, получено %s" % from_facing)
	var from_default := aim.aim_direction(ORIGIN, Vector2.ZERO, 320.0, Vector2.ZERO, Vector2(1000.0, 300.0))
	_expect(from_default.is_equal_approx(Vector2.RIGHT), "без facing авто-наводка обязана взять RIGHT, получено %s" % from_default)


func _check_mouse_geometry() -> void:
	var aim := AimController.new()
	aim.set_mode(AimController.MODE_MANUAL)
	aim.set_device(AimController.DEVICE_MOUSE)

	# Без ограничения дальности точка прицела = курсор (контракт до FAN-1449).
	var cursor := Vector2(900.0, 120.0)
	_expect(aim.aim_point(ORIGIN, 999999.0, Vector2.RIGHT, cursor).is_equal_approx(cursor),
		"безлимитная дальность обязана вернуть точный курсор")

	# Курсор внутри радиуса не обрезается, снаружи — прижимается к радиусу.
	var near_cursor := ORIGIN + Vector2(60.0, 0.0)
	_expect(aim.aim_point(ORIGIN, 200.0, Vector2.RIGHT, near_cursor).is_equal_approx(near_cursor),
		"курсор внутри радиуса не должен обрезаться")
	var far_point := aim.aim_point(ORIGIN, 200.0, Vector2.RIGHT, ORIGIN + Vector2(1000.0, 0.0))
	_expect(is_equal_approx(ORIGIN.distance_to(far_point), 200.0),
		"курсор за радиусом обязан прижаться к дальности, получено %.2f" % ORIGIN.distance_to(far_point))

	# Курсор ровно на герое: точка совпадает с героем (как и до FAN-1449), но
	# направление обязано упасть в facing, а не в нулевой вектор.
	_expect(aim.aim_point(ORIGIN, 200.0, Vector2.UP, ORIGIN).is_equal_approx(ORIGIN),
		"курсор на герое обязан дать точку героя")
	var degenerate := aim.aim_direction(ORIGIN, Vector2.ZERO, 200.0, Vector2.UP, ORIGIN)
	_expect(degenerate.dot(Vector2.UP) > 0.999,
		"курсор на герое обязан уводить направление в facing, получено %s" % degenerate)

	var direction := aim.aim_direction(ORIGIN, Vector2.RIGHT, 999999.0, Vector2.RIGHT, ORIGIN + Vector2(0.0, -400.0))
	_expect(direction.dot(Vector2.UP) > 0.999, "ручная мышь обязана целиться в курсор, получено %s" % direction)


func _check_stick_deadzone() -> void:
	var aim := _manual_gamepad(Vector2.ZERO)
	aim.update_stick(Vector2(0.1, 0.0), 0.25)
	_expect(not aim.has_gamepad_aim(), "дрожание стика внутри deadzone не считается наводкой")

	aim.update_stick(Vector2(0.9, 0.0), 0.25)
	_expect(aim.has_gamepad_aim(), "наклон стика за deadzone обязан задавать наводку")
	_expect(aim.stick_direction().dot(Vector2.RIGHT) > 0.999,
		"направление стика вправо, получено %s" % aim.stick_direction())
	_expect(aim.stick_strength() > 0.85, "почти полный наклон обязан давать сильную наводку, получено %.2f" % aim.stick_strength())

	# Deadzone нормализуется: сразу за порогом сила близка к нулю, а не к 0.3.
	var edge := AimController.new()
	edge.update_stick(Vector2(0.26, 0.0), 0.25)
	_expect(edge.stick_strength() < 0.1, "сила у границы deadzone обязана быть около нуля, получено %.3f" % edge.stick_strength())


func _check_neutral_hold_is_stable() -> void:
	var aim := _manual_gamepad(Vector2(0.0, -0.9))
	var first := aim.aim_direction(ORIGIN, Vector2.RIGHT, 300.0)
	# Отпущенный стик и «неизвестный» нулевой ввод удерживают прошлую наводку:
	# прицел не дрожит и не прыгает в facing между кадрами.
	aim.update_stick(Vector2.ZERO, 0.25)
	var second := aim.aim_direction(ORIGIN, Vector2.RIGHT, 300.0)
	aim.update_stick(Vector2(0.05, 0.05), 0.25)
	var third := aim.aim_direction(ORIGIN, Vector2.RIGHT, 300.0)
	_expect(first.dot(Vector2.UP) > 0.999, "стик вверх обязан целиться вверх, получено %s" % first)
	_expect(first.is_equal_approx(second) and second.is_equal_approx(third),
		"нейтраль обязана удерживать направление: %s / %s / %s" % [first, second, third])

	# Стик не тронут вовсе — падаем в facing, а не в нулевой вектор.
	var untouched := _manual_gamepad(Vector2.ZERO)
	var fallback := untouched.aim_direction(ORIGIN, Vector2.ZERO, 300.0, Vector2.DOWN)
	_expect(fallback.dot(Vector2.DOWN) > 0.999, "нетронутый стик обязан целиться по facing, получено %s" % fallback)


func _check_range_clamp() -> void:
	for range_limit in [150.0, 235.0, 520.0, 980.0]:
		var aim := _manual_gamepad(Vector2(1.0, 0.0))
		var point := aim.aim_point(ORIGIN, range_limit, Vector2.RIGHT)
		var distance := ORIGIN.distance_to(point)
		_expect(distance <= range_limit + 0.01,
			"прицел стика вышел за дальность %.0f: %.2f" % [range_limit, distance])
		_expect(distance > 0.0, "прицел стика не должен схлопываться в героя при дальности %.0f" % range_limit)

	var unbounded := _manual_gamepad(Vector2(1.0, 0.0))
	var far := unbounded.aim_point(ORIGIN, 999999.0, Vector2.RIGHT)
	_expect(ORIGIN.distance_to(far) <= AimController.RETICLE_MAX_DISTANCE + 0.01,
		"безлимитная дальность обязана держать прицел в пределах RETICLE_MAX_DISTANCE")

	# Слабый наклон подтягивает прицел ближе, сильный — дальше: игрок управляет
	# и углом, и дистанцией точки (важно для ловушек/деплоя).
	var soft := _manual_gamepad(Vector2(0.35, 0.0))
	var hard := _manual_gamepad(Vector2(1.0, 0.0))
	_expect(ORIGIN.distance_to(soft.aim_point(ORIGIN, 600.0)) < ORIGIN.distance_to(hard.aim_point(ORIGIN, 600.0)),
		"слабый наклон обязан ставить прицел ближе полного")


func _check_view_clamp() -> void:
	var aim := _manual_gamepad(Vector2(1.0, 0.0))
	var view := Rect2(ORIGIN - Vector2(120.0, 90.0), Vector2(240.0, 180.0))
	var point := aim.aim_point(ORIGIN, 999999.0, Vector2.RIGHT, Vector2.ZERO, view)
	_expect(view.has_point(point) or view.abs().grow(0.01).has_point(point),
		"прицел стика обязан оставаться в кадре, получено %s при кадре %s" % [point, view])
	# Пустой кадр (нет камеры) клампа не добавляет.
	var unclamped := aim.aim_point(ORIGIN, 999999.0, Vector2.RIGHT, Vector2.ZERO, Rect2())
	_expect(ORIGIN.distance_to(unclamped) > 120.0, "без камеры кламп кадра применяться не должен")


func _check_hot_unplug() -> void:
	var aim := _manual_gamepad(Vector2(0.0, 1.0))
	_expect(aim.reticle_visible(), "ручной режим на геймпаде обязан показывать прицел")
	aim.reset_gamepad_aim()
	_expect(aim.device() == AimController.DEVICE_MOUSE, "hot-unplug обязан вернуть устройство мыши")
	_expect(not aim.has_gamepad_aim(), "hot-unplug обязан стереть наводку стика")
	_expect(not aim.reticle_visible(), "после hot-unplug прицел обязан погаснуть")


func _check_reticle_visibility() -> void:
	var auto_pad := AimController.new()
	auto_pad.set_mode(AimController.MODE_AUTO)
	auto_pad.set_device(AimController.DEVICE_GAMEPAD)
	_expect(not auto_pad.reticle_visible(), "в авто-наводке прицела быть не должно")

	var manual_mouse := AimController.new()
	manual_mouse.set_mode(AimController.MODE_MANUAL)
	manual_mouse.set_device(AimController.DEVICE_MOUSE)
	_expect(not manual_mouse.reticle_visible(), "у мыши свой курсор — виртуальный прицел не рисуется")


func _check_aim_actions_idempotent() -> void:
	AimController.ensure_aim_actions()
	AimController.ensure_aim_actions()
	for action_name in AimController.AIM_ACTIONS:
		_expect(InputMap.has_action(action_name), "экшен %s не создан" % action_name)
		var binding: Dictionary = AimController.AIM_ACTIONS[action_name]
		var matches := 0
		for event in InputMap.action_get_events(action_name):
			var motion := event as InputEventJoypadMotion
			if motion == null:
				continue
			if int(motion.axis) == int(binding["axis"]) and signf(motion.axis_value) == signf(float(binding["value"])):
				matches += 1
		_expect(matches == 1, "экшен %s обязан иметь ровно одно событие оси, найдено %d" % [action_name, matches])
	# Наводка живёт на правом стике и не пересекается с движением/UI.
	_expect(int(AimController.AIM_ACTIONS["aim_left"]["axis"]) == JOY_AXIS_RIGHT_X,
		"aim_left обязан висеть на правом стике")
	_expect(int(AimController.AIM_ACTIONS["aim_up"]["axis"]) == JOY_AXIS_RIGHT_Y,
		"aim_up обязан висеть на правом стике")
