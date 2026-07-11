class_name HeroStatRadar
extends Control

const SemanticTypography := preload("res://scripts/ui/semantic_typography.gd")

const HERO_RADAR_RADIUS_FACTOR := 0.36
const HERO_RADAR_LABEL_OFFSET := 18.0
const HERO_RADAR_LABEL_WIDTH := 44.0

var stats: Dictionary = {}
var maxima: Dictionary = {}
var stat_names: Dictionary = {}
var stat_ids: Array = []
var fill_color := Color(0.90, 0.72, 0.26, 0.78)


func setup(new_stats: Dictionary, new_maxima: Dictionary, new_stat_names: Dictionary, new_stat_ids: Array, new_color: Color) -> void:
	stats = new_stats.duplicate(true)
	maxima = new_maxima.duplicate(true)
	stat_names = new_stat_names.duplicate(true)
	stat_ids = new_stat_ids.duplicate()
	fill_color = new_color
	queue_redraw()


func _draw() -> void:
	if stat_ids.is_empty():
		return
	var center: Vector2 = size * 0.5
	var radius: float = min(size.x, size.y) * HERO_RADAR_RADIUS_FACTOR
	if radius <= 4.0:
		return
	var axis_count := stat_ids.size()
	for ring_index in range(1, 5):
		var ring_points := PackedVector2Array()
		var ring_radius: float = radius * float(ring_index) / 4.0
		for axis_index in range(axis_count):
			ring_points.append(center + Vector2.UP.rotated(TAU * float(axis_index) / float(axis_count)) * ring_radius)
		var closed_ring := PackedVector2Array(ring_points)
		closed_ring.append(ring_points[0])
		draw_polyline(closed_ring, Color(0.74, 0.66, 0.44, 0.28), 1.0)
	var value_points := PackedVector2Array()
	for axis_index in range(axis_count):
		var stat_id := str(stat_ids[axis_index])
		var angle := TAU * float(axis_index) / float(axis_count)
		var direction := Vector2.UP.rotated(angle)
		draw_line(center, center + direction * radius, Color(0.86, 0.78, 0.56, 0.34), 1.0)
		var max_value: float = max(1.0, float(maxima.get(stat_id, 1.0)))
		var value: float = float(stats.get(stat_id, 0.0))
		value_points.append(center + direction * radius * clampf(value / max_value, 0.0, 1.0))
		var label_position: Vector2 = center + direction * (radius + HERO_RADAR_LABEL_OFFSET)
		var label := "%s %d" % [str(stat_names.get(stat_id, stat_id)).substr(0, 3), int(round(value))]
		draw_string(
			get_theme_default_font(),
			label_position - Vector2(HERO_RADAR_LABEL_WIDTH * 0.5, -5.0),
			label,
			HORIZONTAL_ALIGNMENT_CENTER,
			HERO_RADAR_LABEL_WIDTH,
			SemanticTypography.resolve_fixed(SemanticTypography.ROLE_CAPTION, 12),
			Color(0.96, 0.90, 0.70, 0.96)
		)
	draw_colored_polygon(value_points, Color(fill_color.r, fill_color.g, fill_color.b, 0.30))
	var closed_values := PackedVector2Array(value_points)
	closed_values.append(value_points[0])
	draw_polyline(closed_values, Color(fill_color.r, fill_color.g, fill_color.b, 0.95), 2.0)
