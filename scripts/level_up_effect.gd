extends Node2D

signal finished

const RING_TEXTURE := preload("res://assets/sprites/effects/impact_ring.png")
const FLASH_TEXTURE := preload("res://assets/sprites/effects/impact_flash.png")
const RING_RADIUS := 104.0

const GOLD := Color(1.0, 0.82, 0.32, 1.0)
const CYAN := Color(0.46, 0.92, 1.0, 1.0)

var _player: Node2D = null


func setup(player: Node2D) -> void:
	_player = player


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("level_up_effects")
	z_index = 80
	_build_visual()


func _additive(texture: Texture2D, color: Color) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = material
	sprite.modulate = color
	return sprite


func _build_visual() -> void:
	# Текстурный праздничный бурст: золотая вспышка + расходящееся кольцо +
	# радиальные искры + поднимающаяся подпись (вместо Polygon2D/ColorRect).
	var flash := _additive(FLASH_TEXTURE, GOLD)
	flash.scale = Vector2.ONE * 0.5
	add_child(flash)

	var ring := _additive(RING_TEXTURE, Color(CYAN.r, CYAN.g, CYAN.b, 0.95))
	ring.scale = Vector2.ONE * (28.0 / RING_RADIUS)
	add_child(ring)

	var label := Label.new()
	label.text = "LEVEL UP"
	label.position = Vector2(-86, -104)
	label.size = Vector2(172, 34)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.28, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.18, 0.10, 0.02, 1.0))
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)

	var sparks: Array[Sprite2D] = []
	for index in range(16):
		var spark := _additive(FLASH_TEXTURE, GOLD if index % 2 == 0 else CYAN)
		spark.scale = Vector2.ONE * 0.12
		add_child(spark)
		sparks.append(spark)

	_play(flash, ring, label, sparks)


func _play(flash: Sprite2D, ring: Sprite2D, label: Label, sparks: Array[Sprite2D]) -> void:
	var root_tween := create_tween()
	root_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	root_tween.tween_interval(0.85)
	root_tween.tween_callback(func() -> void:
		finished.emit()
		queue_free()
	)

	var flash_tween := flash.create_tween()
	flash_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	flash_tween.set_parallel(true)
	flash_tween.tween_property(flash, "scale", Vector2.ONE * 1.1, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.4).set_delay(0.08)

	var ring_tween := ring.create_tween()
	ring_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	ring_tween.set_parallel(true)
	ring_tween.tween_property(ring, "scale", Vector2.ONE * (96.0 / RING_RADIUS), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ring_tween.tween_property(ring, "modulate:a", 0.0, 0.45).set_delay(0.12)

	label.modulate.a = 0.0
	var label_tween := label.create_tween()
	label_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	label_tween.set_parallel(true)
	label_tween.tween_property(label, "modulate:a", 1.0, 0.18)
	label_tween.tween_property(label, "position:y", -120.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	label_tween.tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.5)

	for index in range(sparks.size()):
		var spark := sparks[index]
		var angle := TAU * float(index) / float(sparks.size())
		var distance := 60.0 + float(index % 5) * 14.0
		var spark_tween := spark.create_tween()
		spark_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		spark_tween.set_parallel(true)
		spark_tween.tween_property(spark, "position", Vector2.RIGHT.rotated(angle) * distance, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		spark_tween.tween_property(spark, "scale", Vector2.ONE * 0.04, 0.42)
		spark_tween.tween_property(spark, "modulate:a", 0.0, 0.5).set_delay(0.06)


func _physics_process(_delta: float) -> void:
	if _player != null and is_instance_valid(_player):
		global_position = _player.global_position
