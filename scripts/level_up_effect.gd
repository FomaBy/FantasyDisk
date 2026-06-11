extends Node2D

signal finished

var _player: Node2D = null


func setup(player: Node2D) -> void:
	_player = player


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("level_up_effects")
	z_index = 80
	_build_placeholder()
	_play()


func _build_placeholder() -> void:
	var ring := Polygon2D.new()
	ring.name = "LevelUpEffectRing"
	ring.color = Color(0.36, 0.88, 1.0, 0.32)
	ring.polygon = _ring_points(34.0, 62.0, 48)
	add_child(ring)

	var burst := Polygon2D.new()
	burst.name = "LevelUpEffectBurst"
	burst.color = Color(1.0, 0.78, 0.22, 0.30)
	var burst_points := PackedVector2Array()
	for index in range(36):
		var radius := 74.0 if index % 2 == 0 else 36.0
		burst_points.append(Vector2.RIGHT.rotated(TAU * float(index) / 36.0) * radius)
	burst.polygon = burst_points
	add_child(burst)

	var label := Label.new()
	label.name = "LevelUpEffectLabel"
	label.text = "LEVEL UP"
	label.position = Vector2(-86, -108)
	label.size = Vector2(172, 34)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.28, 1.0))
	add_child(label)

	for index in range(20):
		var spark := ColorRect.new()
		spark.name = "LevelUpEffectSpark%d" % index
		spark.color = Color(0.46, 0.96, 1.0, 0.92) if index % 2 == 0 else Color(1.0, 0.74, 0.18, 0.92)
		spark.position = Vector2.ZERO
		spark.size = Vector2(6, 6)
		spark.pivot_offset = Vector2(3, 3)
		add_child(spark)


func _play() -> void:
	scale = Vector2(0.75, 0.75)
	modulate.a = 1.0

	var root_tween := create_tween()
	root_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	root_tween.set_trans(Tween.TRANS_QUAD)
	root_tween.set_ease(Tween.EASE_OUT)
	root_tween.tween_property(self, "scale", Vector2(1.16, 1.16), 0.26)
	root_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.78).set_delay(0.28)
	root_tween.tween_callback(func() -> void:
		finished.emit()
		queue_free()
	)

	for child in get_children():
		if child is Polygon2D:
			var polygon := child as Polygon2D
			var polygon_tween := create_tween()
			polygon_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			polygon_tween.tween_property(polygon, "scale", Vector2(1.35, 1.35), 0.52)
			polygon_tween.parallel().tween_property(polygon, "rotation", TAU * 0.08, 0.52)
		elif child is ColorRect:
			var spark := child as ColorRect
			var index := int(str(spark.name).trim_prefix("LevelUpEffectSpark"))
			var angle := TAU * float(index) / 20.0
			var distance := 58.0 + float(index % 5) * 12.0
			var spark_tween := create_tween()
			spark_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			spark_tween.set_trans(Tween.TRANS_QUAD)
			spark_tween.set_ease(Tween.EASE_OUT)
			spark_tween.tween_property(spark, "position", Vector2.RIGHT.rotated(angle) * distance, 0.34)
			spark_tween.parallel().tween_property(spark, "color:a", 0.0, 0.58)


func _physics_process(_delta: float) -> void:
	if _player != null and is_instance_valid(_player):
		global_position = _player.global_position


func _ring_points(inner_radius: float, outer_radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		points.append(Vector2.RIGHT.rotated(TAU * float(index) / float(segments)) * outer_radius)
	for index in range(segments - 1, -1, -1):
		points.append(Vector2.RIGHT.rotated(TAU * float(index) / float(segments)) * inner_radius)
	return points
