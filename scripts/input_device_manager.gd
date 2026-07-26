extends Node

# SCRUM-811: ядро поддержки геймпада.
# Autoload `InputDeviceManager`: joypad-биндинги экшенов, автодетект активного
# устройства по последнему вводу, hot-plug, режим ввода из настроек.
# Клавиатура и геймпад физически работают одновременно всегда; input_mode
# влияет только на active_kind() (чьи подсказки/глифы показывать).
#
# Порядок инициализации важен: ui._setup_default_input_actions() (main.gd:500)
# стирает события экшена при применении сохранённых клавиатурных ребиндов,
# поэтому joypad-события доливаются идемпотентно ПОСЛЕ первого кадра и
# повторно страхуются при подключении геймпада.

signal device_changed(kind: String)

const KIND_KEYBOARD := "keyboard"
const KIND_GAMEPAD := "gamepad"

const MODE_AUTO := "auto"
const MODE_KEYBOARD := "keyboard"
const MODE_GAMEPAD := "gamepad"

# Порог, с которого шевеление стика считается «игрок взял геймпад».
const MOTION_ACTIVATION_DEADZONE := 0.3
# Базовая мёртвая зона экшенов движения (814 читает gamepad_deadzone из настроек
# параметром get_vector; здесь — дефолт уровня InputMap).
const MOVE_ACTION_DEADZONE := 0.25

const GameSettingsScript := preload("res://scripts/game_settings.gd")
# FAN-1449: экшены правого стика (ручное прицеливание) — часть канон-раскладки,
# но ребиндом не управляются, как и ui_*.
const AimControllerScript := preload("res://scripts/input/aim_controller.gd")

# Канон-раскладка пакета геймпада (SCRUM-810..816): стик+D-pad — движение,
# Start — пауза, Y — ультимейт, RB — level-up, Back/Select — фидбек, A/B — ui.
const DEFAULT_GAMEPAD_BINDINGS := {
	"move_up": {"buttons": [JOY_BUTTON_DPAD_UP], "axes": [{"axis": JOY_AXIS_LEFT_Y, "value": -1.0}]},
	"move_down": {"buttons": [JOY_BUTTON_DPAD_DOWN], "axes": [{"axis": JOY_AXIS_LEFT_Y, "value": 1.0}]},
	"move_left": {"buttons": [JOY_BUTTON_DPAD_LEFT], "axes": [{"axis": JOY_AXIS_LEFT_X, "value": -1.0}]},
	"move_right": {"buttons": [JOY_BUTTON_DPAD_RIGHT], "axes": [{"axis": JOY_AXIS_LEFT_X, "value": 1.0}]},
	"pause": {"buttons": [JOY_BUTTON_START], "axes": []},
	"ultimate": {"buttons": [JOY_BUTTON_Y], "axes": []},
	"open_level_up": {"buttons": [JOY_BUTTON_RIGHT_SHOULDER], "axes": []},
	"feedback": {"buttons": [JOY_BUTTON_BACK], "axes": []},
}

# Встроенные ui_* экшены Godot: гарантируем A/B и стик поверх дефолтного D-pad.
const UI_ACTION_BINDINGS := {
	"ui_accept": {"buttons": [JOY_BUTTON_A], "axes": []},
	"ui_cancel": {"buttons": [JOY_BUTTON_B], "axes": []},
	"ui_up": {"buttons": [JOY_BUTTON_DPAD_UP], "axes": [{"axis": JOY_AXIS_LEFT_Y, "value": -1.0}]},
	"ui_down": {"buttons": [JOY_BUTTON_DPAD_DOWN], "axes": [{"axis": JOY_AXIS_LEFT_Y, "value": 1.0}]},
	"ui_left": {"buttons": [JOY_BUTTON_DPAD_LEFT], "axes": [{"axis": JOY_AXIS_LEFT_X, "value": -1.0}]},
	"ui_right": {"buttons": [JOY_BUTTON_DPAD_RIGHT], "axes": [{"axis": JOY_AXIS_LEFT_X, "value": 1.0}]},
}

const JOY_BUTTON_NAMES := {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Select",
	JOY_BUTTON_GUIDE: "Home",
	JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "Крестовина ↑",
	JOY_BUTTON_DPAD_DOWN: "Крестовина ↓",
	JOY_BUTTON_DPAD_LEFT: "Крестовина ←",
	JOY_BUTTON_DPAD_RIGHT: "Крестовина →",
}

var _raw_kind := KIND_KEYBOARD
var _input_mode := MODE_AUTO
var _gamepad_bindings := {}


func _ready() -> void:
	# Устройство должно детектиться и в паузе (меню паузы — главный потребитель).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_from_settings()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	if gamepad_connected() and _input_mode == MODE_GAMEPAD:
		_raw_kind = KIND_GAMEPAD
	# Долить joypad-события после того, как main применит клавиатурные дефолты
	# и сохранённые ребинды (те стирают список событий экшена целиком).
	if get_tree() != null:
		await get_tree().process_frame
	ensure_joypad_bindings()


func _input(event: InputEvent) -> void:
	# Движение мыши намеренно не учитывается: случайный сдвиг не должен
	# сбрасывать подсказки с геймпада на клавиатуру.
	var kind := ""
	if event is InputEventKey or event is InputEventMouseButton:
		kind = KIND_KEYBOARD
	elif event is InputEventJoypadButton:
		kind = KIND_GAMEPAD
	elif event is InputEventJoypadMotion and absf(event.axis_value) > MOTION_ACTIVATION_DEADZONE:
		kind = KIND_GAMEPAD
	if kind == "":
		return
	_set_raw_kind(kind)


# --- Публичное API (потребители: 812/813/816, HUD-подсказки) ---

func active_kind() -> String:
	if _input_mode == MODE_KEYBOARD:
		return KIND_KEYBOARD
	if _input_mode == MODE_GAMEPAD:
		return KIND_GAMEPAD
	return _raw_kind


func physical_kind() -> String:
	# В отличие от active_kind(), это фактическое последнее значимое устройство.
	# Gameplay использует его для гибридного ввода, не меняя UI-предпочтение.
	return _raw_kind


func gamepad_connected() -> bool:
	return not Input.get_connected_joypads().is_empty()


func gamepad_name() -> String:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return ""
	return Input.get_joy_name(pads[0])


func input_mode() -> String:
	return _input_mode


func set_input_mode(mode: String) -> void:
	# Сохранение в settings.cfg делает владелец настроек (SCRUM-816);
	# менеджер только применяет режим на рантайме.
	if not [MODE_AUTO, MODE_KEYBOARD, MODE_GAMEPAD].has(mode):
		mode = MODE_AUTO
	var before := active_kind()
	_input_mode = mode
	if active_kind() != before:
		device_changed.emit(active_kind())


func set_gamepad_bindings(bindings: Dictionary) -> void:
	# Кастомные бинды из настроек (SCRUM-816); формат — как DEFAULT_GAMEPAD_BINDINGS.
	# SCRUM-846: старые/битые settings.cfg могли хранить пустой бинд вроде
	# {"ui_accept": {"buttons": [], "axes": []}}. Такой бинд не должен стирать A/стик.
	var previous_actions := _gamepad_bindings.keys()
	_gamepad_bindings = _sanitize_gamepad_bindings(bindings)
	for action_name in previous_actions:
		if not _gamepad_bindings.has(action_name):
			_erase_joypad_events(str(action_name))
	ensure_joypad_bindings()


func reset_gamepad_bindings_to_defaults() -> void:
	_gamepad_bindings = {}
	for action_name in UI_ACTION_BINDINGS:
		_erase_joypad_events(action_name)
	for action_name in DEFAULT_GAMEPAD_BINDINGS:
		_erase_joypad_events(action_name)
	ensure_joypad_bindings()


func binding_text(action: String) -> String:
	# Человекочитаемое имя биндинга экшена для активного устройства.
	if not InputMap.has_action(action):
		return ""
	var want_gamepad := active_kind() == KIND_GAMEPAD
	for event in InputMap.action_get_events(action):
		if want_gamepad and event is InputEventJoypadButton:
			return JOY_BUTTON_NAMES.get(event.button_index, "Кнопка %d" % event.button_index)
		if want_gamepad and event is InputEventJoypadMotion:
			return _axis_text(event.axis, event.axis_value)
		if not want_gamepad and event is InputEventKey:
			var keycode: int = int(event.keycode if event.keycode != 0 else event.physical_keycode)
			if keycode != 0:
				return OS.get_keycode_string(keycode)
	return ""


func ensure_joypad_bindings() -> void:
	# Идемпотентно доливает joypad-события во все экшены раскладки.
	# Кастомный бинд экшена полностью замещает его joypad-часть (клавиатурные
	# события не трогаются никогда).
	AimControllerScript.ensure_aim_actions()
	var wanted := _wanted_bindings()
	for action_name in wanted:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		if _gamepad_bindings.has(action_name):
			_erase_joypad_events(action_name)
		var binding: Dictionary = wanted[action_name]
		for button_index in binding.get("buttons", []):
			if not _action_has_joy_button(action_name, int(button_index)):
				var ev := InputEventJoypadButton.new()
				ev.button_index = int(button_index) as JoyButton
				InputMap.action_add_event(action_name, ev)
		for axis_binding in binding.get("axes", []):
			var axis := int(axis_binding.get("axis", 0))
			var value := float(axis_binding.get("value", 1.0))
			if not _action_has_joy_axis(action_name, axis, value):
				var ev := InputEventJoypadMotion.new()
				ev.axis = axis as JoyAxis
				ev.axis_value = value
				InputMap.action_add_event(action_name, ev)
		if DEFAULT_GAMEPAD_BINDINGS.has(action_name) and action_name.begins_with("move_"):
			InputMap.action_set_deadzone(action_name, MOVE_ACTION_DEADZONE)


# --- Внутреннее ---

func _load_from_settings() -> void:
	var settings := GameSettingsScript.load_settings()
	_input_mode = str(settings.get("input_mode", MODE_AUTO))
	if not [MODE_AUTO, MODE_KEYBOARD, MODE_GAMEPAD].has(_input_mode):
		_input_mode = MODE_AUTO
	var bindings: Variant = settings.get("gamepad_bindings", {})
	_gamepad_bindings = _sanitize_gamepad_bindings(bindings)


func _wanted_bindings() -> Dictionary:
	var wanted := {}
	for action_name in UI_ACTION_BINDINGS:
		wanted[action_name] = UI_ACTION_BINDINGS[action_name]
	for action_name in DEFAULT_GAMEPAD_BINDINGS:
		wanted[action_name] = DEFAULT_GAMEPAD_BINDINGS[action_name]
	for action_name in _gamepad_bindings:
		var custom: Variant = _gamepad_bindings[action_name]
		if custom is Dictionary:
			var normalized := _normalize_gamepad_binding(custom)
			if _binding_has_input(normalized):
				wanted[action_name] = normalized
	return wanted


func _sanitize_gamepad_bindings(bindings: Variant) -> Dictionary:
	var sanitized := {}
	if not (bindings is Dictionary):
		return sanitized
	for action_name in bindings:
		var action_key := str(action_name)
		if not DEFAULT_GAMEPAD_BINDINGS.has(action_key):
			continue
		var custom: Variant = bindings[action_name]
		if not (custom is Dictionary):
			continue
		var normalized := _normalize_gamepad_binding(custom)
		if _binding_has_input(normalized):
			sanitized[action_key] = normalized
	return sanitized


func _normalize_gamepad_binding(binding: Dictionary) -> Dictionary:
	var normalized := {"buttons": [], "axes": []}
	var buttons: Variant = binding.get("buttons", [])
	if buttons is Array:
		for button_index in buttons:
			if _variant_is_number(button_index):
				normalized["buttons"].append(int(button_index))
	var axes: Variant = binding.get("axes", [])
	if axes is Array:
		for axis_binding in axes:
			if not (axis_binding is Dictionary):
				continue
			var axis: Variant = axis_binding.get("axis", null)
			var value: Variant = axis_binding.get("value", null)
			if not _variant_is_number(axis) or not _variant_is_number(value):
				continue
			if is_zero_approx(float(value)):
				continue
			normalized["axes"].append({"axis": int(axis), "value": float(value)})
	return normalized


func _binding_has_input(binding: Dictionary) -> bool:
	var buttons: Variant = binding.get("buttons", [])
	var axes: Variant = binding.get("axes", [])
	return (buttons is Array and not buttons.is_empty()) \
		or (axes is Array and not axes.is_empty())


func _variant_is_number(value: Variant) -> bool:
	var value_type := typeof(value)
	return value_type == TYPE_INT or value_type == TYPE_FLOAT


func _set_raw_kind(kind: String) -> void:
	if _raw_kind == kind:
		return
	var before := active_kind()
	_raw_kind = kind
	if kind == KIND_GAMEPAD:
		# Страховка: ребинд клавиатуры в настройках мог стереть joypad-события.
		ensure_joypad_bindings()
	if active_kind() != before:
		device_changed.emit(active_kind())


func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	if connected:
		# Подключение само по себе не меняет активное устройство: оно
		# переключится на геймпад лишь при первом вводе с него (см. _input).
		# Только доливаем биндинги — device_changed здесь НЕ эмитим.
		ensure_joypad_bindings()
	elif not gamepad_connected():
		# Геймпад выдернули — мгновенно возвращаемся на клавиатуру.
		# _set_raw_kind сам эмитит device_changed ровно один раз и только при
		# реальной смене active_kind() (в режиме gamepad смены нет — молчит).
		_set_raw_kind(KIND_KEYBOARD)


func _erase_joypad_events(action_name: String) -> void:
	if not InputMap.has_action(action_name):
		return
	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			InputMap.action_erase_event(action_name, event)


func _action_has_joy_button(action_name: String, button_index: int) -> bool:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton and int(event.button_index) == button_index:
			return true
	return false


func _action_has_joy_axis(action_name: String, axis: int, value: float) -> bool:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadMotion and int(event.axis) == axis \
				and signf(event.axis_value) == signf(value):
			return true
	return false


func _axis_text(axis: int, value: float) -> String:
	match axis:
		JOY_AXIS_LEFT_X:
			return "Стик ←" if value < 0.0 else "Стик →"
		JOY_AXIS_LEFT_Y:
			return "Стик ↑" if value < 0.0 else "Стик ↓"
		JOY_AXIS_RIGHT_X:
			return "Пр. стик ←" if value < 0.0 else "Пр. стик →"
		JOY_AXIS_RIGHT_Y:
			return "Пр. стик ↑" if value < 0.0 else "Пр. стик ↓"
		JOY_AXIS_TRIGGER_LEFT:
			return "LT"
		JOY_AXIS_TRIGGER_RIGHT:
			return "RT"
	return "Ось %d" % axis
