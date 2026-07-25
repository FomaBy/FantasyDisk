extends RefCounted

# FAN-1449: канонический провайдер прицеливания.
#
# Владелец всей геометрии наводки: режим (`nearest` / `cursor`), активное
# устройство (мышь / правый стик), точка прицела и направление атаки. Player
# остаётся тонким адаптером — публичный контракт оружия
# (`attack_aim_mode` / `attack_aim_position` / `attack_aim_direction`)
# не меняется, поэтому все 51 оружие получают ручное прицеливание без правок
# механик.
#
# Класс не трогает InputMap/сцены при вычислениях: он чистый и headless-
# проверяемый. Ввод в него подаёт владелец (`update_stick`, `set_device`),
# точку мыши и видимую область он тоже получает параметрами.

const MODE_AUTO := "nearest"
# Значение `cursor` — историческое имя ручного режима в settings.cfg и в
# root-мете `aim_mode`. Ломать его нельзя: его читают оружия и сохранения.
const MODE_MANUAL := "cursor"

const DEVICE_MOUSE := "mouse"
const DEVICE_GAMEPAD := "gamepad"

const VIRTUAL_RETICLE := preload("res://scripts/ui/virtual_reticle.gd")

# Правый стик — только наводка, ребиндом не управляется (как ui_* экшены).
const AIM_ACTIONS := {
	"aim_left": {"axis": JOY_AXIS_RIGHT_X, "value": -1.0},
	"aim_right": {"axis": JOY_AXIS_RIGHT_X, "value": 1.0},
	"aim_up": {"axis": JOY_AXIS_RIGHT_Y, "value": -1.0},
	"aim_down": {"axis": JOY_AXIS_RIGHT_Y, "value": 1.0},
}

const DEFAULT_STICK_DEADZONE := 0.25
# Совпадает с порогом `attack_aim_position` до FAN-1449: дальше этого значения
# range_limit считается «без ограничения».
const UNBOUNDED_RANGE := 999998.0
# Прицел не липнет к ногам героя и не улетает за экран на дальнобое.
const RETICLE_MIN_DISTANCE := 96.0
const RETICLE_MAX_DISTANCE := 520.0

var _mode := MODE_AUTO
var _device := DEVICE_MOUSE
# Последнее ненулевое направление стика: нейтраль его удерживает, поэтому
# отпущенный стик не роняет прицел в ноль и атаки не дрожат.
var _stick_direction := Vector2.ZERO
var _stick_strength := 0.0
var _reticle: Node2D = null


static func normalize_mode(mode: Variant) -> String:
	return MODE_MANUAL if str(mode) == MODE_MANUAL else MODE_AUTO


static func ensure_aim_actions() -> void:
	# Идемпотентно: экшены правого стика живут рядом с раскладкой
	# InputDeviceManager, но не ребиндятся и не стираются сбросом геймпада.
	for action_name in AIM_ACTIONS:
		var binding: Dictionary = AIM_ACTIONS[action_name]
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		var axis := int(binding["axis"])
		var value := float(binding["value"])
		if not _action_has_axis(action_name, axis, value):
			var event := InputEventJoypadMotion.new()
			event.axis = axis as JoyAxis
			event.axis_value = value
			InputMap.action_add_event(action_name, event)
		InputMap.action_set_deadzone(action_name, DEFAULT_STICK_DEADZONE)


static func _action_has_axis(action_name: String, axis: int, value: float) -> bool:
	for event in InputMap.action_get_events(action_name):
		var motion := event as InputEventJoypadMotion
		if motion != null and int(motion.axis) == axis and signf(motion.axis_value) == signf(value):
			return true
	return false


# --- Режим ---

func set_mode(mode: Variant) -> void:
	_mode = normalize_mode(mode)


func mode() -> String:
	return _mode


func is_manual() -> bool:
	return _mode == MODE_MANUAL


# --- Устройство ---

func set_device(kind: String) -> void:
	_device = DEVICE_GAMEPAD if kind == DEVICE_GAMEPAD else DEVICE_MOUSE


func device() -> String:
	return _device


func has_gamepad_aim() -> bool:
	return _stick_direction.length_squared() > 0.0


func stick_direction() -> Vector2:
	return _stick_direction


func stick_strength() -> float:
	return _stick_strength


func reset_gamepad_aim() -> void:
	# Hot-unplug: прицел стика гаснет мгновенно, ввод возвращается мыши.
	_stick_direction = Vector2.ZERO
	_stick_strength = 0.0
	_device = DEVICE_MOUSE


func update_stick(raw: Vector2, deadzone := DEFAULT_STICK_DEADZONE) -> void:
	var zone := clampf(deadzone, 0.0, 0.95)
	var magnitude := raw.length()
	if magnitude <= zone or magnitude <= 0.0:
		# Нейтраль (и неизвестный/шумовой ввод) удерживает прошлую наводку.
		return
	_stick_direction = raw / magnitude
	_stick_strength = clampf((magnitude - zone) / maxf(1.0 - zone, 0.001), 0.0, 1.0)


# --- Геометрия наводки ---

func aim_point(origin: Vector2, range_limit := 999999.0, facing := Vector2.RIGHT, mouse_point := Vector2.ZERO, view_rect := Rect2()) -> Vector2:
	if _device == DEVICE_GAMEPAD:
		return _clamp_to_view(_gamepad_point(origin, range_limit, facing), view_rect)
	return _mouse_point(origin, range_limit, facing, mouse_point)


func aim_direction(origin: Vector2, default_direction := Vector2.RIGHT, range_limit := 999999.0, facing := Vector2.RIGHT, mouse_point := Vector2.ZERO, view_rect := Rect2()) -> Vector2:
	if is_manual():
		var offset := aim_point(origin, range_limit, facing, mouse_point, view_rect) - origin
		if offset.length_squared() > 0.001:
			return offset.normalized()
	var fallback := default_direction
	if fallback.length_squared() <= 0.001:
		fallback = facing
	if fallback.length_squared() <= 0.001:
		fallback = Vector2.RIGHT
	return fallback.normalized()


func reticle_visible() -> bool:
	# Виртуальный прицел — подсказка геймпада: мышь рисует свой курсор сама,
	# в авто-наводке точки прицеливания нет вовсе.
	return is_manual() and _device == DEVICE_GAMEPAD


func reticle_point(origin: Vector2, range_limit := 999999.0, facing := Vector2.RIGHT, view_rect := Rect2()) -> Vector2:
	return _clamp_to_view(_gamepad_point(origin, range_limit, facing), view_rect)


func _mouse_point(origin: Vector2, range_limit: float, facing: Vector2, mouse_point: Vector2) -> Vector2:
	var offset := mouse_point - origin
	if range_limit >= UNBOUNDED_RANGE or offset.length() <= range_limit:
		return mouse_point
	if offset.length_squared() <= 0.001:
		return origin + _fallback_direction(facing) * range_limit
	return origin + offset.normalized() * range_limit


func _gamepad_point(origin: Vector2, range_limit: float, facing: Vector2) -> Vector2:
	var direction := _stick_direction
	if direction.length_squared() <= 0.001:
		direction = _fallback_direction(facing)
	var max_distance := RETICLE_MAX_DISTANCE
	if range_limit < UNBOUNDED_RANGE:
		max_distance = maxf(range_limit, 1.0)
	var min_distance := minf(RETICLE_MIN_DISTANCE, max_distance)
	return origin + direction * lerpf(min_distance, max_distance, _stick_strength)


func _clamp_to_view(point: Vector2, view_rect: Rect2) -> Vector2:
	if view_rect.size.x <= 0.0 or view_rect.size.y <= 0.0:
		return point
	return Vector2(
		clampf(point.x, view_rect.position.x, view_rect.end.x),
		clampf(point.y, view_rect.position.y, view_rect.end.y)
	)


func _fallback_direction(facing: Vector2) -> Vector2:
	if facing.length_squared() > 0.001:
		return facing.normalized()
	return Vector2.RIGHT


# --- Адаптер игрока ---
#
# Player держит только тонкие обёртки (`attack_aim_*`), а вся проводка —
# устройство, hot-plug, экранный прицел и чтение мировых координат — живёт
# здесь, чтобы монолит player.gd не рос.

func attach(player: Node2D) -> void:
	# Идемпотентно: экшены стика, подписка на hot-plug и узел прицела.
	ensure_aim_actions()
	var callback := Callable(player, "_on_aim_joy_connection_changed")
	if not Input.joy_connection_changed.is_connected(callback):
		Input.joy_connection_changed.connect(callback)
	if _reticle != null and is_instance_valid(_reticle):
		return
	var reticle := Node2D.new()
	reticle.name = "VirtualReticle"
	reticle.set_script(VIRTUAL_RETICLE)
	player.add_child(reticle)
	_reticle = reticle


func sync(player: Node2D, deadzone := DEFAULT_STICK_DEADZONE, mode: Variant = null) -> void:
	if mode != null:
		set_mode(mode)
	# Собственная радиальная мёртвая зона, поэтому у get_vector она 0. Без пада
	# экшены стика читаются нулём — ветвиться по списку устройств не нужно.
	update_stick(Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down", 0.0), deadzone)
	# Устройство наводки следует за общим детектом активного устройства
	# (InputDeviceManager): клавиатура/мышь забирают прицел обратно, правый стик
	# отдаёт его геймпаду. Без менеджера решает сам факт наводки стиком.
	# Ненайденный пад отменяет всё: прицелиться стиком, которого нет, нельзя.
	var pad_available := not Input.get_connected_joypads().is_empty() or has_gamepad_aim()
	var manager_kind := _manager_kind(player)
	_device = DEVICE_GAMEPAD if pad_available \
		and (manager_kind == DEVICE_GAMEPAD if manager_kind != "" else has_gamepad_aim()) \
		else DEVICE_MOUSE
	refresh_reticle(player)


func on_joy_connection_changed(connected: bool, player: Node2D) -> void:
	# Выдернули последний пад — прицел гаснет мгновенно, ввод у мыши.
	if connected or not Input.get_connected_joypads().is_empty():
		return
	reset_gamepad_aim()
	refresh_reticle(player)


func player_aim_point(player: Node2D, range_limit := 999999.0) -> Vector2:
	return aim_point(player.global_position, range_limit, _facing_of(player), _mouse_of(player), _view_rect(player))


func player_aim_direction(player: Node2D, default_direction := Vector2.RIGHT, range_limit := 999999.0) -> Vector2:
	return aim_direction(player.global_position, default_direction, range_limit, _facing_of(player), _mouse_of(player), _view_rect(player))


func reticle_position() -> Vector2:
	if _reticle == null or not is_instance_valid(_reticle):
		return Vector2.ZERO
	return _reticle.global_position


func refresh_reticle(player: Node2D) -> void:
	if _reticle == null or not is_instance_valid(_reticle):
		return
	var shown := reticle_visible()
	var point := player.global_position
	if shown:
		var config: Variant = player.get("weapon_config")
		var range_limit := 999999.0
		if config is Dictionary:
			range_limit = maxf(float((config as Dictionary).get("attack_range", range_limit)), 1.0)
		point = reticle_point(player.global_position, range_limit, _facing_of(player), _view_rect(player))
	_reticle.call("set_aim", point, shown)


static func aim_mode_hint_text(mode: Variant, gamepad_connected: bool) -> String:
	if normalize_mode(mode) != MODE_MANUAL:
		return "Автонаводка сама держит ближайшего врага — прицел на экране не нужен."
	if gamepad_connected:
		return "Ручное прицеливание: правый стик ведёт прицел на экране, курсор мыши работает одновременно."
	return "Ручное прицеливание: цельтесь курсором мыши. Подключите геймпад — наводку возьмёт правый стик."


static func apply_hint_label(label: Object, mode: Variant, device_manager: Object) -> void:
	# Настройки зовут это из живых hot-plug коллбэков, поэтому гардим Label.
	if label == null or not is_instance_valid(label):
		return
	var connected := not Input.get_connected_joypads().is_empty()
	if device_manager != null and is_instance_valid(device_manager) and device_manager.has_method("gamepad_connected"):
		connected = bool(device_manager.call("gamepad_connected"))
	label.set("text", aim_mode_hint_text(mode, connected))


func _manager_kind(player: Node2D) -> String:
	if not player.is_inside_tree():
		return ""
	var manager := player.get_node_or_null("/root/InputDeviceManager")
	if manager == null or not manager.has_method("active_kind"):
		return ""
	return str(manager.call("active_kind"))


func _facing_of(player: Node2D) -> Vector2:
	var facing: Variant = player.get("_facing_direction")
	return facing if facing is Vector2 else Vector2.RIGHT


func _mouse_of(player: Node2D) -> Vector2:
	if not player.is_inside_tree():
		return player.global_position
	return player.get_global_mouse_position()


func _view_rect(player: Node2D) -> Rect2:
	# Виртуальный прицел не должен уезжать за кадр. Мышь и так в кадре, поэтому
	# клампим только стик; без камеры/дерева клампа нет (пустой Rect2).
	if _device != DEVICE_GAMEPAD or not player.is_inside_tree():
		return Rect2()
	var camera := player.get_viewport().get_camera_2d()
	if camera == null:
		return Rect2()
	var view_size := Vector2(player.get_viewport().get_visible_rect().size) / camera.zoom
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		return Rect2()
	return Rect2(camera.get_screen_center_position() - view_size * 0.5, view_size)
