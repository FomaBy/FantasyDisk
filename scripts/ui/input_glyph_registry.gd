extends RefCounted
## SCRUM-810 — реестр глифов ввода (геймпад + клавиатура).
##
## Статический словарь «константа Godot → имя глифа» + null-safe аксессоры к
## текстурам. Дизайн-роль: только данные + доступ; НЕ встраивает глифы в экраны
## (`ui_screens.gd` не трогается) — интеграцию делают UI-задачи пакета геймпада
## по этому реестру.
##
## Ассеты: assets/sprites/ui/input_glyphs/<name>_<32|64>.png (пиксель-арт,
## прозрачный фон). Два нативных размера; `size` в аксессорах выбирает ближайший.

const GLYPH_DIR := "res://assets/sprites/ui/input_glyphs/"
const SIZES := [32, 64]

## Полный набор имён глифов (файлы <name>_<size>.png существуют для каждого).
const ALL_GLYPHS := [
	"btn_a", "btn_b", "btn_x", "btn_y",
	"dpad", "dpad_up", "dpad_down", "dpad_left", "dpad_right",
	"lb", "rb", "lt", "rt",
	"start", "select",
	"stick_l", "stick_r", "stick_l_press", "stick_r_press", "stick_move",
	"key_generic", "key_esc", "key_enter", "key_space", "key_wasd", "key_arrows",
]

## JOY_BUTTON_* → имя глифа (generic Xbox-style раскладка).
const JOY_BUTTON_TO_GLYPH := {
	JOY_BUTTON_A: "btn_a",
	JOY_BUTTON_B: "btn_b",
	JOY_BUTTON_X: "btn_x",
	JOY_BUTTON_Y: "btn_y",
	JOY_BUTTON_BACK: "select",
	JOY_BUTTON_START: "start",
	JOY_BUTTON_LEFT_STICK: "stick_l_press",
	JOY_BUTTON_RIGHT_STICK: "stick_r_press",
	JOY_BUTTON_LEFT_SHOULDER: "lb",
	JOY_BUTTON_RIGHT_SHOULDER: "rb",
	JOY_BUTTON_DPAD_UP: "dpad_up",
	JOY_BUTTON_DPAD_DOWN: "dpad_down",
	JOY_BUTTON_DPAD_LEFT: "dpad_left",
	JOY_BUTTON_DPAD_RIGHT: "dpad_right",
}

## JOY_AXIS_* → имя глифа (триггеры — курки; оси стиков — «движение»/правый стик).
const JOY_AXIS_TO_GLYPH := {
	JOY_AXIS_LEFT_X: "stick_move",
	JOY_AXIS_LEFT_Y: "stick_move",
	JOY_AXIS_RIGHT_X: "stick_r",
	JOY_AXIS_RIGHT_Y: "stick_r",
	JOY_AXIS_TRIGGER_LEFT: "lt",
	JOY_AXIS_TRIGGER_RIGHT: "rt",
}

## Именованные клавиатурные глифы.
const KEY_TO_GLYPH := {
	"generic": "key_generic",
	"esc": "key_esc",
	"enter": "key_enter",
	"space": "key_space",
	"wasd": "key_wasd",
	"arrows": "key_arrows",
}


static func _nearest_size(size: int) -> int:
	var best := int(SIZES[0])
	var bestd := absi(size - best)
	for s in SIZES:
		var d := absi(size - int(s))
		if d < bestd:
			bestd = d
			best = int(s)
	return best


## res://-путь к PNG глифа (или "" для неизвестного имени). Не проверяет наличие
## файла — используйте has_glyph для этого.
static func path_for(glyph: String, size: int = 32) -> String:
	if not ALL_GLYPHS.has(glyph):
		return ""
	return "%s%s_%d.png" % [GLYPH_DIR, glyph, _nearest_size(size)]


static func has_glyph(glyph: String, size: int = 32) -> bool:
	var p := path_for(glyph, size)
	return p != "" and ResourceLoader.exists(p)


## Текстура по имени глифа; null если имени нет или ресурс отсутствует.
static func texture_for(glyph: String, size: int = 32) -> Texture2D:
	var p := path_for(glyph, size)
	if p == "" or not ResourceLoader.exists(p):
		return null
	return load(p) as Texture2D


## Текстура по JoyButton (0..14); null для незамапленной кнопки.
static func texture_for_joy_button(idx: int, size: int = 32) -> Texture2D:
	if not JOY_BUTTON_TO_GLYPH.has(idx):
		return null
	return texture_for(str(JOY_BUTTON_TO_GLYPH[idx]), size)


## Текстура по JoyAxis (0..5); null для незамапленной оси.
static func texture_for_axis(axis: int, size: int = 32) -> Texture2D:
	if not JOY_AXIS_TO_GLYPH.has(axis):
		return null
	return texture_for(str(JOY_AXIS_TO_GLYPH[axis]), size)


## Текстура по имени клавиатурного глифа (esc/enter/space/wasd/arrows/generic).
static func texture_for_key(key_name: String, size: int = 32) -> Texture2D:
	if not KEY_TO_GLYPH.has(key_name):
		return null
	return texture_for(str(KEY_TO_GLYPH[key_name]), size)
