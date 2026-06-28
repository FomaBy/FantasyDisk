extends Node2D

signal finished

const RING_TEXTURE := preload("res://assets/sprites/effects/impact_ring.png")
const FLASH_TEXTURE := preload("res://assets/sprites/effects/impact_flash.png")
const BADGE_TEXTURE := preload("res://assets/sprites/effects/level_up_popup_badge.png")
const RING_RADIUS := 104.0
const BADGE_DISPLAY_SIZE := Vector2(224.0, 112.0)
const BADGE_START_POSITION := Vector2(0.0, -118.0)
# SCRUM-614: показ Level Up дольше и весомее (просьба игрока — момент роста почти
# незаметен при ~0.86с). Окно эффекта расширено до 1.35с, бейдж дольше держится и
# выше всплывает, добавлен второй пульс масштаба на пике. Фейд бейджа (delay 1.05 +
# 0.30) укладывается ровно в EFFECT_DURATION — нода самоосвобождается без обрезки.
const BADGE_FLOAT_DISTANCE := 40.0
const EFFECT_DURATION := 1.35

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
	# радиальные искры + готовый Level Up badge из SCRUM-519.
	var flash := _additive(FLASH_TEXTURE, GOLD)
	flash.scale = Vector2.ONE * 0.5
	add_child(flash)

	var ring := _additive(RING_TEXTURE, Color(CYAN.r, CYAN.g, CYAN.b, 0.95))
	ring.scale = Vector2.ONE * (28.0 / RING_RADIUS)
	add_child(ring)

	var badge := Sprite2D.new()
	badge.name = "LevelUpPopupBadge"
	badge.texture = BADGE_TEXTURE
	badge.position = BADGE_START_POSITION
	badge.scale = _badge_display_scale()
	badge.modulate.a = 0.0
	add_child(badge)

	var sparks: Array[Sprite2D] = []
	for index in range(16):
		var spark := _additive(FLASH_TEXTURE, GOLD if index % 2 == 0 else CYAN)
		spark.scale = Vector2.ONE * 0.12
		add_child(spark)
		sparks.append(spark)

	_play(flash, ring, badge, sparks)


func _badge_display_scale(multiplier := 1.0) -> Vector2:
	var texture_size := BADGE_TEXTURE.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Vector2.ONE * multiplier
	return Vector2(BADGE_DISPLAY_SIZE.x / texture_size.x, BADGE_DISPLAY_SIZE.y / texture_size.y) * multiplier


func _play(flash: Sprite2D, ring: Sprite2D, badge: Sprite2D, sparks: Array[Sprite2D]) -> void:
	var root_tween := create_tween()
	root_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	root_tween.tween_interval(EFFECT_DURATION)
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

	var badge_tween := badge.create_tween()
	badge_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	badge_tween.set_parallel(true)
	badge_tween.tween_property(badge, "modulate:a", 1.0, 0.12)
	badge_tween.tween_property(badge, "position:y", BADGE_START_POSITION.y - BADGE_FLOAT_DISTANCE, 0.95).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	badge_tween.tween_property(badge, "modulate:a", 0.0, 0.30).set_delay(1.05)

	var badge_scale_tween := badge.create_tween()
	badge_scale_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	badge_scale_tween.tween_property(badge, "scale", _badge_display_scale(1.04), 0.14).from(_badge_display_scale(0.92)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	badge_scale_tween.tween_property(badge, "scale", _badge_display_scale(), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Второй мягкий пульс масштаба на пике подъёма (вес/акцент момента роста, SCRUM-614).
	badge_scale_tween.tween_interval(0.40)
	badge_scale_tween.tween_property(badge, "scale", _badge_display_scale(1.06), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	badge_scale_tween.tween_property(badge, "scale", _badge_display_scale(), 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

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
