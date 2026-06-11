extends Node2D

# Дешевая полоса HP над врагом: один Node2D с кастомным _draw без Control-нод,
# перерисовка только при изменении значения — безопасно для 100+ мобов.

var max_value := 1.0
var value := 1.0
var bar_width := 44.0
var bar_height := 5.0

const BACKGROUND_COLOR := Color(0.07, 0.06, 0.08, 0.82)
const BORDER_COLOR := Color(0.0, 0.0, 0.0, 0.55)
const FILL_HIGH_COLOR := Color(0.38, 0.86, 0.30, 0.95)
const FILL_LOW_COLOR := Color(0.92, 0.22, 0.16, 0.95)


func _ready() -> void:
	z_index = 30


func setup(new_max_value: float, width: float) -> void:
	max_value = maxf(new_max_value, 0.001)
	value = max_value
	bar_width = clampf(width, 30.0, 150.0)
	queue_redraw()


func set_value(new_value: float) -> void:
	var clamped := clampf(new_value, 0.0, max_value)
	if absf(clamped - value) < 0.001:
		return
	value = clamped
	queue_redraw()


func _draw() -> void:
	var half := bar_width * 0.5
	draw_rect(Rect2(-half - 1.0, -1.0, bar_width + 2.0, bar_height + 2.0), BORDER_COLOR)
	draw_rect(Rect2(-half, 0.0, bar_width, bar_height), BACKGROUND_COLOR)
	var ratio := value / max_value
	if ratio <= 0.0:
		return
	var fill_color := FILL_LOW_COLOR.lerp(FILL_HIGH_COLOR, clampf(ratio, 0.0, 1.0))
	draw_rect(Rect2(-half, 0.0, bar_width * ratio, bar_height), fill_color)
