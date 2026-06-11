extends Control

signal finished

var _player: Node2D = null
var _level_count := 1


func setup(player: Node2D, level_count: int) -> void:
	_player = player
	_level_count = max(level_count, 1)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_placeholder()
	_play()


func _build_placeholder() -> void:
	var center := _toast_center()

	var burst := Polygon2D.new()
	burst.name = "LevelUpToastBurst"
	burst.color = Color(1.0, 0.78, 0.24, 0.34)
	var points := PackedVector2Array()
	for index in range(32):
		var radius := 62.0 if index % 2 == 0 else 34.0
		points.append(Vector2.RIGHT.rotated(TAU * float(index) / 32.0) * radius)
	burst.polygon = points
	burst.position = center
	add_child(burst)

	var label := Label.new()
	label.name = "LevelUpToastLabel"
	label.text = "LEVEL UP" if _level_count <= 1 else "LEVEL UP x%d" % _level_count
	label.position = center + Vector2(-122, -94)
	label.size = Vector2(244, 48)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.34, 1.0))
	add_child(label)

	for index in range(18):
		var spark := ColorRect.new()
		spark.name = "LevelUpToastSpark%d" % index
		spark.color = Color(0.38, 0.95, 1.0, 0.90) if index % 2 == 0 else Color(1.0, 0.78, 0.24, 0.90)
		spark.position = center
		spark.size = Vector2(7, 7)
		spark.pivot_offset = Vector2(3.5, 3.5)
		add_child(spark)


func _play() -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 1.0, 0.12)
	tween.tween_interval(0.55)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func() -> void:
		finished.emit()
		queue_free()
	)

	var center := _toast_center()
	for child in get_children():
		if child is Polygon2D:
			var burst := child as Polygon2D
			burst.scale = Vector2(0.35, 0.35)
			var burst_tween := create_tween()
			burst_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			burst_tween.tween_property(burst, "scale", Vector2(1.45, 1.45), 0.45)
			burst_tween.parallel().tween_property(burst, "color:a", 0.0, 0.55)
		elif child is ColorRect:
			var spark := child as ColorRect
			var index := int(str(spark.name).trim_prefix("LevelUpToastSpark"))
			var angle := TAU * float(index) / 18.0
			var distance := 82.0 + float(index % 4) * 16.0
			var spark_tween := create_tween()
			spark_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			spark_tween.tween_property(spark, "position", center + Vector2.RIGHT.rotated(angle) * distance, 0.38)
			spark_tween.parallel().tween_property(spark, "color:a", 0.0, 0.55)


func _toast_center() -> Vector2:
	if _player != null and is_instance_valid(_player):
		return _player.get_viewport_transform() * _player.global_position
	return get_viewport_rect().size * 0.5
