extends Control

signal finished

const RING_TEXTURE := preload("res://assets/sprites/effects/impact_ring.png")
const FLASH_TEXTURE := preload("res://assets/sprites/effects/impact_flash.png")
const TOAST_FRAME_TEXTURE := preload("res://assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_lut_toast.png")
const TOAST_FRAME_SIZE := Vector2(480.0, 300.0)
const TOAST_TEXTURE_MARGINS := Vector4(58.0, 48.0, 58.0, 48.0)
const TOAST_CONTENT_MARGINS := Vector4(70.0, 112.0, 70.0, 112.0)
const RING_RADIUS := 104.0
const RING_START_RADIUS := 28.0
const RING_END_RADIUS := 38.0
const SPARK_BASE_DISTANCE := 28.0
const SPARK_DISTANCE_STEP := 6.0

const GOLD := Color(1.0, 0.82, 0.32, 1.0)
const CYAN := Color(0.40, 0.92, 1.0, 1.0)

var _player: Node2D = null


func setup(player: Node2D, _level_count: int) -> void:
	_player = player


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
	_add_frame(center)

	var flash := _additive(FLASH_TEXTURE, GOLD)
	flash.position = center
	flash.scale = Vector2.ONE * 0.28
	add_child(flash)

	var ring := _additive(RING_TEXTURE, Color(CYAN.r, CYAN.g, CYAN.b, 0.9))
	ring.position = center
	ring.scale = Vector2.ONE * (RING_START_RADIUS / RING_RADIUS)
	add_child(ring)

	var sparks: Array[Sprite2D] = []
	for index in range(18):
		var spark := _additive(FLASH_TEXTURE, GOLD if index % 2 == 0 else CYAN)
		spark.position = center
		spark.scale = Vector2.ONE * 0.08
		add_child(spark)
		sparks.append(spark)

	_play(center, flash, ring, sparks)


func _add_frame(center: Vector2) -> void:
	var frame := PanelContainer.new()
	frame.name = "LevelUpToastFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.custom_minimum_size = TOAST_FRAME_SIZE
	frame.size = TOAST_FRAME_SIZE
	frame.position = center - TOAST_FRAME_SIZE * 0.5
	frame.add_theme_stylebox_override("panel", _toast_frame_style())
	frame.set_meta("toast_frame_path", TOAST_FRAME_TEXTURE.resource_path)
	frame.set_meta("toast_source_size", TOAST_FRAME_SIZE)
	frame.set_meta("toast_texture_margins", TOAST_TEXTURE_MARGINS)
	frame.set_meta("toast_content_margins", TOAST_CONTENT_MARGINS)
	frame.set_meta("toast_content_rect", _toast_content_rect(frame.position))
	add_child(frame)


func _toast_frame_style() -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = TOAST_FRAME_TEXTURE
	style.texture_margin_left = TOAST_TEXTURE_MARGINS.x
	style.texture_margin_top = TOAST_TEXTURE_MARGINS.y
	style.texture_margin_right = TOAST_TEXTURE_MARGINS.z
	style.texture_margin_bottom = TOAST_TEXTURE_MARGINS.w
	style.content_margin_left = TOAST_CONTENT_MARGINS.x
	style.content_margin_top = TOAST_CONTENT_MARGINS.y
	style.content_margin_right = TOAST_CONTENT_MARGINS.z
	style.content_margin_bottom = TOAST_CONTENT_MARGINS.w
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return style


func _toast_content_rect(frame_position: Vector2) -> Rect2:
	return Rect2(
		frame_position + Vector2(TOAST_CONTENT_MARGINS.x, TOAST_CONTENT_MARGINS.y),
		TOAST_FRAME_SIZE - Vector2(TOAST_CONTENT_MARGINS.x + TOAST_CONTENT_MARGINS.z, TOAST_CONTENT_MARGINS.y + TOAST_CONTENT_MARGINS.w)
	)


func _play(center: Vector2, flash: Sprite2D, ring: Sprite2D, sparks: Array[Sprite2D]) -> void:
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
	flash_tween.tween_property(flash, "scale", Vector2.ONE * 0.52, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.5).set_delay(0.1)

	var ring_tween := ring.create_tween()
	ring_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	ring_tween.set_parallel(true)
	ring_tween.tween_property(ring, "scale", Vector2.ONE * (RING_END_RADIUS / RING_RADIUS), 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ring_tween.tween_property(ring, "modulate:a", 0.0, 0.5).set_delay(0.12)

	for index in range(sparks.size()):
		var spark := sparks[index]
		var angle := TAU * float(index) / float(sparks.size())
		var distance := SPARK_BASE_DISTANCE + float(index % 4) * SPARK_DISTANCE_STEP
		var spark_tween := spark.create_tween()
		spark_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		spark_tween.set_parallel(true)
		spark_tween.tween_property(spark, "position", center + Vector2.RIGHT.rotated(angle) * distance, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		spark_tween.tween_property(spark, "scale", Vector2.ONE * 0.03, 0.45)
		spark_tween.tween_property(spark, "modulate:a", 0.0, 0.55).set_delay(0.05)


func _toast_center() -> Vector2:
	if _player != null and is_instance_valid(_player):
		return _player.get_viewport_transform() * _player.global_position
	return get_viewport_rect().size * 0.5
