extends Control

signal finished

const RING_TEXTURE := preload("res://assets/sprites/effects/impact_ring.png")
const FLASH_TEXTURE := preload("res://assets/sprites/effects/impact_flash.png")
const RING_RADIUS := 104.0

const GOLD := Color(1.0, 0.82, 0.32, 1.0)
const CYAN := Color(0.40, 0.92, 1.0, 1.0)

var _player: Node2D = null
var _level_count := 1


func setup(player: Node2D, level_count: int) -> void:
	_player = player
	_level_count = max(level_count, 1)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_visual()


func _additive(texture: Texture2D, color: Color) -> Sprite2D:
	# Sprite2D как CanvasItem-ребёнок Control: рендерится в его canvas-пространстве.
	var sprite := Sprite2D.new()
	sprite.texture = texture
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = material
	sprite.modulate = color
	return sprite


func _build_visual() -> void:
	var center := _toast_center()

	var flash := _additive(FLASH_TEXTURE, GOLD)
	flash.position = center
	flash.scale = Vector2.ONE * 0.7
	add_child(flash)

	var ring := _additive(RING_TEXTURE, Color(CYAN.r, CYAN.g, CYAN.b, 0.9))
	ring.position = center
	ring.scale = Vector2.ONE * (36.0 / RING_RADIUS)
	add_child(ring)

	var label := Label.new()
	label.text = "LEVEL UP" if _level_count <= 1 else "LEVEL UP x%d" % _level_count
	label.position = center + Vector2(-122, -94)
	label.size = Vector2(244, 48)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.34, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.18, 0.10, 0.02, 1.0))
	label.add_theme_constant_override("outline_size", 7)
	add_child(label)

	var sparks: Array[Sprite2D] = []
	for index in range(18):
		var spark := _additive(FLASH_TEXTURE, GOLD if index % 2 == 0 else CYAN)
		spark.position = center
		spark.scale = Vector2.ONE * 0.14
		add_child(spark)
		sparks.append(spark)

	_play(center, flash, ring, label, sparks)


func _play(center: Vector2, flash: Sprite2D, ring: Sprite2D, label: Label, sparks: Array[Sprite2D]) -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 1.0, 0.12)
	tween.tween_interval(0.6)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func() -> void:
		finished.emit()
		queue_free()
	)

	var flash_tween := flash.create_tween()
	flash_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	flash_tween.set_parallel(true)
	flash_tween.tween_property(flash, "scale", Vector2.ONE * 1.5, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.5).set_delay(0.1)

	var ring_tween := ring.create_tween()
	ring_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	ring_tween.set_parallel(true)
	ring_tween.tween_property(ring, "scale", Vector2.ONE * (150.0 / RING_RADIUS), 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ring_tween.tween_property(ring, "modulate:a", 0.0, 0.5).set_delay(0.12)

	for index in range(sparks.size()):
		var spark := sparks[index]
		var angle := TAU * float(index) / float(sparks.size())
		var distance := 86.0 + float(index % 4) * 18.0
		var spark_tween := spark.create_tween()
		spark_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		spark_tween.set_parallel(true)
		spark_tween.tween_property(spark, "position", center + Vector2.RIGHT.rotated(angle) * distance, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		spark_tween.tween_property(spark, "scale", Vector2.ONE * 0.05, 0.45)
		spark_tween.tween_property(spark, "modulate:a", 0.0, 0.55).set_delay(0.05)


func _toast_center() -> Vector2:
	if _player != null and is_instance_valid(_player):
		return _player.get_viewport_transform() * _player.global_position
	return get_viewport_rect().size * 0.5
