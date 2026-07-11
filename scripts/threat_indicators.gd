extends Control
## SCRUM-498: edge-индикаторы внеэкранных угроз.
##
## Полупрозрачный full-rect overlay в HUD CanvasLayer (mouse_filter IGNORE — клики
## по карте/бою не перехватывает). Каждый кадр находит значимые ВНЕэкранные угрозы
## (босс, элитки, активно стреляющие дальнобои) и рисует стрелку на краю вьюпорта в
## их направлении с цветом/глифом ранга. Маркер пропадает, как только цель в кадре
## или мертва. Обычные melee-мобы не маркируются (Enemy.threat_marker_rank() == "").

const SemanticTypography := preload("res://scripts/ui/semantic_typography.gd")

const EDGE_INSET := 34.0          # отступ маркера от края экрана
const ARROW_LENGTH := 26.0
const ARROW_HALF_WIDTH := 13.0

# Ранг → цвет/масштаб/глиф. boss крупнее и краснее, дальнобой компактный жёлтый.
const RANK_STYLE := {
	"boss": {"color": Color(1.0, 0.22, 0.18, 0.95), "scale": 1.35, "glyph": "B"},
	"elite": {"color": Color(1.0, 0.62, 0.20, 0.92), "scale": 1.10, "glyph": "E"},
	"shooter": {"color": Color(1.0, 0.86, 0.30, 0.88), "scale": 0.86, "glyph": "!"},
}

var game: Node  # game-синглтон (Main); проставляется в ui_screens._create_hud()


func _ready() -> void:
	name = "ThreatIndicatorOverlay"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 4
	# Full-rect под CombatHudRoot (его origin = 0,0) → локальные координаты = координаты вьюпорта.


func _process(_delta: float) -> void:
	queue_redraw()


# Точка на границе inset-прямоугольника в направлении от center к target.
# Возвращает {offscreen: bool, pos: Vector2, dir: Vector2}. offscreen=false, если
# target уже внутри inset-области (маркер не нужен). Детерминирована — покрыта тестом.
static func screen_edge_point(center: Vector2, target: Vector2, inset_min: Vector2, inset_max: Vector2) -> Dictionary:
	var inside := target.x >= inset_min.x and target.x <= inset_max.x and target.y >= inset_min.y and target.y <= inset_max.y
	var dir := target - center
	if dir.length_squared() < 0.0001:
		return {"offscreen": false, "pos": center, "dir": Vector2.UP}
	if inside:
		return {"offscreen": false, "pos": target, "dir": dir.normalized()}
	var t := INF
	if dir.x > 0.0:
		t = minf(t, (inset_max.x - center.x) / dir.x)
	elif dir.x < 0.0:
		t = minf(t, (inset_min.x - center.x) / dir.x)
	if dir.y > 0.0:
		t = minf(t, (inset_max.y - center.y) / dir.y)
	elif dir.y < 0.0:
		t = minf(t, (inset_min.y - center.y) / dir.y)
	t = clampf(t, 0.0, 1.0)
	return {"offscreen": true, "pos": center + dir * t, "dir": dir.normalized()}


func _draw() -> void:
	if game == null or not is_instance_valid(game) or not bool(game.get("combat_active")):
		return
	var player = game.get("current_player")
	if player == null or not is_instance_valid(player):
		return
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	var viewport_size := get_viewport_rect().size
	var center := viewport_size * 0.5
	var cam_center: Vector2 = camera.get_screen_center_position()
	var zoom: Vector2 = camera.zoom
	var inset_min := Vector2(EDGE_INSET, EDGE_INSET)
	var inset_max := viewport_size - Vector2(EDGE_INSET, EDGE_INSET)
	if inset_max.x <= inset_min.x or inset_max.y <= inset_min.y:
		return

	var seen_positions := []  # анти-нагромождение: близкие маркеры одного ранга не дублируем
	for node in _threat_candidates():
		if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		if not node.has_method("threat_marker_rank"):
			continue
		var rank := str(node.call("threat_marker_rank"))
		if rank == "" or not RANK_STYLE.has(rank):
			continue
		# world → screen (CanvasLayer не двигается камерой): screen = center + (world-cam)*zoom
		var enemy_world: Vector2 = node.global_position
		var screen_pos: Vector2 = center + (enemy_world - cam_center) * zoom
		var edge: Dictionary = screen_edge_point(center, screen_pos, inset_min, inset_max)
		if not bool(edge["offscreen"]):
			continue
		var pos: Vector2 = edge["pos"]
		var skip := false
		for prev in seen_positions:
			if prev.distance_to(pos) < 26.0:
				skip = true
				break
		if skip:
			continue
		seen_positions.append(pos)
		_draw_marker(pos, edge["dir"], RANK_STYLE[rank])


func _draw_marker(pos: Vector2, dir: Vector2, style: Dictionary) -> void:
	var scale := float(style["scale"])
	var color: Color = style["color"]
	var length := ARROW_LENGTH * scale
	var half := ARROW_HALF_WIDTH * scale
	var perp := dir.orthogonal()
	var tip := pos + dir * (length * 0.5)
	var base_a := pos - dir * (length * 0.5) + perp * half
	var base_b := pos - dir * (length * 0.5) - perp * half
	# Тёмная подложка-обводка для читаемости поверх любого фона.
	draw_circle(pos, half + 5.0, Color(0.04, 0.02, 0.01, 0.55))
	draw_colored_polygon(PackedVector2Array([tip, base_a, base_b]), color)
	var glyph := str(style["glyph"])
	var font := ThemeDB.fallback_font
	if font != null:
		var font_size := SemanticTypography.resolve_scaled_compat(
			SemanticTypography.ROLE_HUD, 15.0, scale
		)
		var text_size := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(font, pos - text_size * 0.5 + Vector2(0, text_size.y * 0.35), glyph,
			HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.05, 0.03, 0.02, 0.95))


func _threat_candidates() -> Array:
	var out := []
	var tree := get_tree()
	if tree == null:
		return out
	out.append_array(tree.get_nodes_in_group("bosses"))
	out.append_array(tree.get_nodes_in_group("elite_enemies"))
	out.append_array(tree.get_nodes_in_group("enemies"))
	return out
