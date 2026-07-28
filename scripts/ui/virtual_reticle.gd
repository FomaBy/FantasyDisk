extends Node2D

# FAN-1449: виртуальный прицел ручного прицеливания с геймпада.
#
# Живёт ребёнком игрока, но с `top_level = true`, поэтому не наследует его
# трансформ и стоит ровно в мировой точке прицела. Мышь свой курсор рисует
# сама, поэтому узел показывается только для правого стика.

const COLOR := Color(1.0, 0.86, 0.42, 0.92)
const SHADOW_COLOR := Color(0.06, 0.05, 0.03, 0.55)
const RADIUS := 17.0
const TICK_LENGTH := 9.0
const LINE_WIDTH := 2.0


func _ready() -> void:
	top_level = true
	z_index = 4096
	z_as_relative = false
	visible = false
	queue_redraw()


func set_aim(point: Vector2, aim_visible: bool) -> void:
	visible = aim_visible
	if not aim_visible:
		return
	global_position = point


func _draw() -> void:
	# Тень под контуром: прицел читается и на светлом полу арены.
	draw_arc(Vector2.ZERO, RADIUS + 1.0, 0.0, TAU, 28, SHADOW_COLOR, LINE_WIDTH + 2.0)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 28, COLOR, LINE_WIDTH)
	for axis in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		draw_line(axis * (RADIUS - TICK_LENGTH), axis * (RADIUS + TICK_LENGTH), COLOR, LINE_WIDTH)
	draw_circle(Vector2.ZERO, 2.0, COLOR)
