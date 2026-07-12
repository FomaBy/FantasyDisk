extends RefCounted

const UIButtonFamily := preload("res://scripts/ui/ui_button_family.gd")
const SemanticTypography := preload("res://scripts/ui/semantic_typography.gd")

# Генерация маршрута и full-screen экран маршрутной карты:
# узлы, связи, скролл/пан, активация encounter-ов.

var game

# SCRUM-812: геймпад-навигация по карте маршрута.
# _route_node_activating — реэнтранси-латч: активация ноды меняет экран, любой
#   повторный вызов в том же кадре (мышь + встроенный pressed) гасится. Сброс в _show_battle_map.
# _route_focus_target — нода, на которую ставится стартовый фокус (текущий доступный ряд).
var _route_node_activating := false
var _route_focus_target: Button = null

const START_BATTLE_ONLY_ROWS := 2

# SCRUM-489: историческая координатная спека @2560×1440 — экран «Карта маршрута».
# SCRUM-981 introduced the hollow meta40 shell. SCRUM-1057/1079 supersedes its
# vertical runtime geometry with the accepted horizontal five-target matrix in
# _route_map_shell_layout(); old 28px edge offsets below are historical only.
# Старые опорные значения (main.gd): ROUTE_MAP_SCREEN_MARGIN=28, ROUTE_MAP_HEADER_HEIGHT=140,
# MAP_NODE_SIZE=(88,88), ROUTE_MAP_PADDING=(170,72), ROUTE_STEPS_TO_BOSS=8 (SCRUM-786). Из viewport
# масштабируется только ширина canvas. Header: anchor top, offset L/R=±28, top=18, bottom=140-12=128
# → @2K (28,18,2504,110) — band ровно под content-min хедера (title 36px + stage 18px). Scroll:
# L/R=±28, top=140, bottom=-28 → (28,140,2504,1272) (зазор 12 до хедера). Canvas
# (map_area VerticalRouteMap): width = max(vp.x-56-16, 1000) = 2488 @2K; высота ДИНАМИЧЕСКАЯ:
# h = ROUTE_MAP_PADDING.y*2 + MAP_NODE_SIZE.y + 165*(row_count-1), row_count=max(route_nodes, ROUTE_STEPS_TO_BOSS+1)
# → минимум 144+88+165*10 = 1882 (выше viewport — это норма для скролл-карты, не overflow).
# Узлы 88×88 рисуются процедурно (_draw_route_nodes); ряд-gap 165, padding (170,72).
const RM_DESIGN_BASE_2K := Vector2(2560.0, 1440.0)
const RM_HEADER_2K := Rect2(28, 18, 2504, 110)
const RM_HEADER_SAFE_2K := Rect2(28, 18, 2504, 110)         # PanelContainer hud-style, контент = весь header
const RM_TITLE_2K := Rect2(28, 18, 2200, 44)               # title 36px (HBox, EXPAND_FILL)
const RM_STAGE_LABEL_2K := Rect2(28, 62, 2200, 24)         # stage 18px под заголовком
const RM_SCROLL_2K := Rect2(28, 140, 2504, 1272)
const RM_CANVAS_2K := Rect2(28, 140, 2488, 1882)           # height @ row_count=11 (минимум); см. формулу выше
const RM_NODE_2K := Rect2(0, 0, 88, 88)                    # шаблон узла маршрута
const RM_ROW_GAP_2K := 165.0
const RM_PADDING_2K := Vector2(170.0, 72.0)

# SCRUM-981: production frame 1536×1024, 160px 9-slice rail on every edge.
# Reserve is additional empty-zone breathing room, never part of the ornament.
const ROUTE_SHELL_FRAME_SOURCE_SIZE := Vector2(1536.0, 1024.0)
const ROUTE_SHELL_FRAME_SOURCE_MARGIN := 160.0
const ROUTE_SHELL_RESERVE_COMPACT := 24.0
const ROUTE_SHELL_RESERVE_LARGE := 32.0

# SCRUM-1057: accepted PixelLab horizontal Route Map contract. Arrays keep the
# machine-readable rectangles identical to responsive_matrix.json while making
# the table legal as a GDScript constant.
const ROUTE_HORIZONTAL_LAYOUTS := {
	"1152x648": {"safe": [120,101,912,446], "inner": [140,121,872,406], "header": [140,121,872,76], "title": [154,125,416,54], "resources": [666,125,332,54], "route": [140,209,872,318], "nodes": [158,227,740,258], "lane": [158,497,740,14], "fab": [922,437,72,72], "node_size": 56.0, "boss_size": 64.0},
	"1280x720": {"safe": [133,113,1014,494], "inner": [157,137,966,446], "header": [157,137,966,80], "title": [173,141,450,58], "resources": [731,141,376,58], "route": [157,229,966,354], "nodes": [175,249,834,286], "lane": [175,549,834,14], "fab": [1033,493,72,72], "node_size": 60.0, "boss_size": 68.0},
	"1600x900": {"safe": [167,141,1266,618], "inner": [191,165,1218,570], "header": [191,165,1218,84], "title": [211,169,580,62], "resources": [965,169,424,62], "route": [191,265,1218,470], "nodes": [215,289,1074,392], "lane": [215,701,1074,16], "fab": [1313,639,72,72], "node_size": 68.0, "boss_size": 76.0},
	"1920x1080": {"safe": [200,169,1520,742], "inner": [224,193,1472,694], "header": [224,193,1472,88], "title": [248,197,700,64], "resources": [1128,197,544,64], "route": [224,297,1472,590], "nodes": [248,321,1328,500], "lane": [248,845,1328,18], "fab": [1600,791,72,72], "node_size": 72.0, "boss_size": 88.0},
	"2560x1440": {"safe": [267,225,2026,990], "inner": [299,257,1962,926], "header": [299,257,1962,104], "title": [331,263,940,80], "resources": [1557,263,672,80], "route": [299,385,1962,798], "nodes": [331,417,1786,694], "lane": [331,1139,1786,20], "fab": [2149,1071,80,80], "node_size": 88.0, "boss_size": 104.0},
}
const ROUTE_HORIZONTAL_VISIBLE_COLUMNS := 8


func _init(game_ref) -> void:
	game = game_ref


func _semantic_font(role: StringName, authored_px: int, min_px := 0, max_px := 96) -> int:
	var viewport_height := 864.0
	if game != null and game.get_viewport() != null:
		viewport_height = game.get_viewport().get_visible_rect().size.y
	return SemanticTypography.resolve_authored_compat(role, authored_px, viewport_height, min_px, max_px)


func _route_map_stage_status_text(viewport_size: Vector2) -> String:
	var progress: int = mini(game.route_stage, game.route_nodes.size() - 1)
	var strength: int = game.route_scaling_stage()
	var next_battle_seconds := int(game.combat._current_round_duration())
	if viewport_size.x <= 1280.0 or viewport_size.y <= 720.0:
		return "Шаг %d/%d  ·  Сила %d  ·  Бой %dс  ·  Выбор пути необратим" % [
			progress,
			game.ROUTE_STEPS_TO_BOSS,
			strength,
			next_battle_seconds,
		]
	return "Прогресс: %d/%d   Сила маршрута: %d   Следующий бой: %ds   Выбранный путь фиксируется" % [
		progress,
		game.ROUTE_STEPS_TO_BOSS,
		strength,
		next_battle_seconds,
	]


func _update_route_map_stage_label(label: Label, viewport_size: Vector2) -> void:
	if label == null:
		return
	label.name = "RouteMapStageLabel"
	label.text = _route_map_stage_status_text(viewport_size)
	label.add_theme_color_override("font_color", Color(0.84, 0.90, 0.96, 1.0))
	if game.route_debug_free_pick:
		# Keep the compact two-line header contract even in debug mode.
		label.name = "RouteDebugFreePickLabel"
		label.text += "   DEBUG: свободный выбор (F12)"
		label.add_theme_color_override("font_color", Color(1.0, 0.58, 0.46, 1.0))


func _show_battle_map() -> void:
	# SCRUM-812: сброс латча активации и цели фокуса на каждое переоткрытие карты.
	_route_node_activating = false
	_route_focus_target = null
	# A→ui_accept / B→ui_cancel для геймпада (в текущей сборке их нет; идемпотентно).
	game.ui._ensure_run_ui_gamepad_bindings()
	# SCRUM-968: путевая тема карты маршрута (спека §2 №2); до SCRUM-966 звучал "menu".
	# Старт свежего забега (акт 1, этап 0 — ни одного обычного боя ещё не было)
	# пересыпает shuffle-bag боевой ротации (спека §4: session-only, не в autosave).
	if game.current_act <= 1 and game.route_stage <= 0:
		var audio: Node = game.get_node_or_null("/root/AudioManager")
		if audio != null and audio.has_method("reset_combat_rotation"):
			audio.reset_combat_rotation()
	game._play_music("route_map")
	game._clear_world()
	game._clear_hud()
	game._clear_ui()

	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "RouteMapScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.ui_layer.add_child(root)

	var backdrop_path := "res://assets/backgrounds/route_map_backdrop.png"
	if ResourceLoader.exists(backdrop_path):
		var backdrop := TextureRect.new()
		backdrop.name = "RouteMapBackdrop"
		backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
		backdrop.texture = game._cached_texture(backdrop_path)
		backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(backdrop)
		# Затемнение, чтобы узлы и линии читались поверх арта.
		var backdrop_shade := ColorRect.new()
		backdrop_shade.name = "RouteMapBackdropShade"
		backdrop_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		backdrop_shade.color = Color(0.012, 0.016, 0.030, 0.62)
		backdrop_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(backdrop_shade)
	else:
		# Fallback: текущий однотонный фон, пока Codex не положил backdrop PNG.
		var background := ColorRect.new()
		background.name = "RouteMapBackground"
		background.set_anchors_preset(Control.PRESET_FULL_RECT)
		background.color = Color(0.025, 0.032, 0.050, 0.98)
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(background)

	var grid_shade := ColorRect.new()
	grid_shade.name = "RouteMapTopShade"
	grid_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid_shade.color = Color(0.0, 0.0, 0.0, 0.20)
	grid_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(grid_shade)

	var shell_layout := _route_map_shell_layout(root.size)

	var header := PanelContainer.new()
	header.name = "RouteMapHeader"
	header.set_anchors_preset(Control.PRESET_TOP_LEFT)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# SCRUM-876: бывший _hud_panel_style — тонкая обёртка над этой @2K-рамкой;
	# обёртка удалена вместе со старым карточным меню-худом, вид заголовка прежний.
	header.add_theme_stylebox_override("panel", game.ui._overhaul_2k_frame_style("chud_resource_panel", Vector2(820.0, 84.0)))
	root.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.name = "RouteMapTitleProgress"
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.add_theme_constant_override("separation", 0)
	root.add_child(title_box)

	var title_label := Label.new()
	title_label.text = "%s — карта маршрута" % game.act_progress_label()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# SCRUM-981: шапка живёт в authored 68/70/80px zone; readable 29..32px
	# оставляет гарантированную отдельную строку прогресса без выхода на орнамент.
	title_label.add_theme_font_size_override("font_size", _semantic_font(SemanticTypography.ROLE_TITLE, 18, 22, 30))
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.add_child(title_label)

	var stage_label := Label.new()
	_update_route_map_stage_label(stage_label, game.get_viewport().get_visible_rect().size)
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# SCRUM-981: compact supporting line inside the same authored title zone.
	stage_label.add_theme_font_size_override("font_size", _semantic_font(SemanticTypography.ROLE_CAPTION, 9, 12, 16))
	stage_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stage_label.add_theme_color_override("font_color", Color(0.84, 0.90, 0.96, 1.0))
	stage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.add_child(stage_label)

	var scroll := ScrollContainer.new()
	scroll.name = "RouteMapScroll"
	scroll.set_anchors_preset(Control.PRESET_TOP_LEFT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(scroll)

	var map_area := Control.new()
	# Legacy node name is retained for test/save tooling compatibility; metadata
	# is the authoritative orientation contract from SCRUM-1057.
	map_area.name = "VerticalRouteMap"
	map_area.set_meta("route_orientation", "horizontal")
	var canvas_size := _route_map_canvas_size(
		float(shell_layout["node_viewport_rect"].size.x),
		float(shell_layout["node_viewport_rect"].size.y)
	)
	map_area.custom_minimum_size = canvas_size
	map_area.size = canvas_size
	map_area.mouse_filter = Control.MOUSE_FILTER_PASS
	map_area.gui_input.connect(func(event: InputEvent) -> void:
		_handle_route_map_pan_input(scroll, event)
	)
	scroll.add_child(map_area)

	var node_positions := _map_node_positions(map_area.custom_minimum_size)
	_draw_map_connections(map_area, node_positions)
	_draw_route_nodes(map_area, node_positions)
	game.ui._create_resource_hud_panel(root, Vector2.ZERO)
	# SCRUM-982: the paid Attribute Shop is mandatory post-combat only. Keep the
	# independent pending Level Up affordance on Route Map without recreating the
	# removed manual gold-stat entry.
	game.ui._update_level_up_button()
	game.ui._layout_level_up_button_in_gold_shell(root.size)
	_apply_route_map_shell_layout(root, header, title_box, scroll, map_area)
	_layout_route_map_fab(root, shell_layout["fab_rect"])
	root.resized.connect(func() -> void:
		_update_route_map_stage_label(stage_label, root.size)
		_apply_route_map_shell_layout(root, header, title_box, scroll, map_area)
		_apply_route_map_shell_layout.call_deferred(root, header, title_box, scroll, map_area)
		var resized_layout := _route_map_shell_layout(root.size)
		_layout_route_map_fab(root, resized_layout["fab_rect"])
		_layout_route_map_fab.call_deferred(root, resized_layout["fab_rect"])
	)
	game.ui._update_hud()
	game.route_map_pan_active = false
	game.route_map_drag_distance = 0.0
	game.route_map_drag_suppressed_click = false
	# SCRUM-812: скролл следует за выбранным нодом (крестовина/стик), стартовый фокус —
	# доступный нод текущего ряда, чтобы карта сразу управлялась с геймпада.
	scroll.follow_focus = true
	if _route_focus_target != null and is_instance_valid(_route_focus_target):
		_route_focus_target.call_deferred("grab_focus")
	_center_route_map_on_current_row.call_deferred(scroll, map_area.custom_minimum_size)

	# Hard contract: the hollow production frame is the final child, above every
	# content layer, and never participates in hit testing.
	game.ui._unified_add_frame(root, "RouteMap")


func _route_map_shell_layout(viewport_size: Vector2) -> Dictionary:
	var exact_key := "%dx%d" % [int(roundf(viewport_size.x)), int(roundf(viewport_size.y))]
	if ROUTE_HORIZONTAL_LAYOUTS.has(exact_key):
		return _route_map_layout_from_entry(ROUTE_HORIZONTAL_LAYOUTS[exact_key])

	# Non-matrix window sizes interpolate from the accepted 1920×1080 contract,
	# then clamp every zone back into the real hollow-frame interior.
	var margin_x := roundf(ROUTE_SHELL_FRAME_SOURCE_MARGIN * viewport_size.x / ROUTE_SHELL_FRAME_SOURCE_SIZE.x)
	var margin_y := roundf(ROUTE_SHELL_FRAME_SOURCE_MARGIN * viewport_size.y / ROUTE_SHELL_FRAME_SOURCE_SIZE.y)
	var safe_rect := Rect2(
		Vector2(margin_x, margin_y),
		viewport_size - Vector2(margin_x * 2.0, margin_y * 2.0)
	)
	var reserve := ROUTE_SHELL_RESERVE_LARGE if viewport_size.y >= 1200.0 else ROUTE_SHELL_RESERVE_COMPACT
	var inner_rect := safe_rect.grow(-reserve)
	var sx := viewport_size.x / 1920.0
	var sy := viewport_size.y / 1080.0
	var scale_rect := func(base: Rect2) -> Rect2:
		return Rect2(Vector2(roundf(base.position.x * sx), roundf(base.position.y * sy)), Vector2(roundf(base.size.x * sx), roundf(base.size.y * sy)))
	var header_rect: Rect2 = scale_rect.call(Rect2(224,193,1472,88)).intersection(inner_rect)
	var title_rect: Rect2 = scale_rect.call(Rect2(248,197,700,64)).intersection(inner_rect)
	var resource_rect: Rect2 = scale_rect.call(Rect2(1128,197,544,64)).intersection(inner_rect)
	var route_rect: Rect2 = scale_rect.call(Rect2(224,297,1472,590)).intersection(inner_rect)
	var node_rect: Rect2 = scale_rect.call(Rect2(248,321,1328,500)).intersection(route_rect)
	var lane_rect: Rect2 = scale_rect.call(Rect2(248,845,1328,18)).intersection(route_rect)
	var fab_rect: Rect2 = scale_rect.call(Rect2(1600,791,72,72)).intersection(inner_rect)
	var node_size := clampf(roundf(72.0 * minf(sx, sy)), 56.0, 88.0)
	return {
		"safe_rect": safe_rect,
		"inner_rect": inner_rect,
		"header_rect": header_rect,
		"title_rect": title_rect,
		"resource_rect": resource_rect,
		"route_rect": route_rect,
		"node_viewport_rect": node_rect,
		"horizontal_lane_rect": lane_rect,
		"fab_rect": fab_rect,
		"scroll_rect": Rect2(node_rect.position, Vector2(node_rect.size.x, maxf(node_rect.size.y, lane_rect.end.y - node_rect.position.y))),
		"node_size": node_size,
		"boss_size": node_size + maxf(8.0, node_size * 0.2),
	}


func _route_map_layout_from_entry(entry: Dictionary) -> Dictionary:
	var safe_rect := _route_map_rect(entry["safe"])
	var inner_rect := _route_map_rect(entry["inner"])
	var node_rect := _route_map_rect(entry["nodes"])
	var lane_rect := _route_map_rect(entry["lane"])
	return {
		"safe_rect": safe_rect,
		"inner_rect": inner_rect,
		"header_rect": _route_map_rect(entry["header"]),
		"title_rect": _route_map_rect(entry["title"]),
		"resource_rect": _route_map_rect(entry["resources"]),
		"route_rect": _route_map_rect(entry["route"]),
		"node_viewport_rect": node_rect,
		"horizontal_lane_rect": lane_rect,
		"fab_rect": _route_map_rect(entry["fab"]),
		"scroll_rect": Rect2(node_rect.position, Vector2(node_rect.size.x, lane_rect.end.y - node_rect.position.y)),
		"node_size": float(entry["node_size"]),
		"boss_size": float(entry["boss_size"]),
	}


func _route_map_rect(values: Array) -> Rect2:
	return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))


func _apply_route_map_shell_layout(root: Control, header: Control, title_box: Control, scroll: ScrollContainer, map_area: Control) -> void:
	if root == null or not is_instance_valid(root):
		return
	var layout := _route_map_shell_layout(root.size)
	root.set_meta("scrum981_safe_rect", layout["safe_rect"])
	root.set_meta("scrum981_inner_rect", layout["inner_rect"])
	root.set_meta("scrum1057_route_rect", layout["route_rect"])
	root.set_meta("scrum1057_node_viewport_rect", layout["node_viewport_rect"])
	root.set_meta("scrum1057_horizontal_lane_rect", layout["horizontal_lane_rect"])
	root.set_meta("scrum1057_fab_rect", layout["fab_rect"])
	_apply_route_map_control_rect(header, layout["header_rect"])
	_apply_route_map_control_rect(title_box, layout["title_rect"])
	_apply_route_map_control_rect(scroll, layout["scroll_rect"])
	header.set_meta("scrum981_zone_rect", layout["header_rect"])
	title_box.set_meta("scrum981_zone_rect", layout["title_rect"])
	scroll.set_meta("scrum981_zone_rect", layout["route_rect"])
	scroll.set_meta("scrum1057_node_viewport_rect", layout["node_viewport_rect"])
	scroll.set_meta("scrum1057_horizontal_lane_rect", layout["horizontal_lane_rect"])
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_vertical = 0
	var vertical_bar := scroll.get_v_scroll_bar()
	if vertical_bar != null:
		vertical_bar.visible = false
		vertical_bar.focus_mode = Control.FOCUS_NONE
	_style_route_map_horizontal_scrollbar(scroll, float(layout["horizontal_lane_rect"].size.y))

	var expected_canvas_size := _route_map_canvas_size(
		float(layout["node_viewport_rect"].size.x),
		float(layout["node_viewport_rect"].size.y)
	)
	if map_area.custom_minimum_size.distance_to(expected_canvas_size) > 1.0:
		_rebuild_route_map_canvas(map_area, expected_canvas_size)
	else:
		map_area.custom_minimum_size = expected_canvas_size
		map_area.size = expected_canvas_size
	_layout_route_map_resource_hud(root, layout["resource_rect"])
	_layout_route_map_fab(root, layout["fab_rect"])
	_center_route_map_on_current_row.call_deferred(scroll, expected_canvas_size)


func _layout_route_map_resource_hud(root: Control, resource_zone: Rect2) -> void:
	game.ui._layout_menu_resource_hud(root, Vector2.ZERO)
	var resource := root.find_child("RunResourceHud", true, false) as PanelContainer
	if resource == null:
		return
	resource.pivot_offset = Vector2.ZERO
	resource.scale = Vector2.ONE
	var unscaled_size := resource.size
	if unscaled_size.x <= 0.0 or unscaled_size.y <= 0.0:
		unscaled_size = resource.custom_minimum_size
	var fit_scale := minf(1.0, minf(resource_zone.size.x / unscaled_size.x, resource_zone.size.y / unscaled_size.y))
	resource.scale = Vector2(fit_scale, fit_scale)
	var visible_size := unscaled_size * fit_scale
	resource.position = Vector2(
		resource_zone.end.x - visible_size.x,
		resource_zone.position.y + roundf((resource_zone.size.y - visible_size.y) * 0.5)
	)
	resource.set_meta("scrum981_zone_rect", resource_zone)


func _layout_route_map_fab(root: Control, fab_zone: Rect2) -> void:
	if root == null or game.level_up_button == null or not is_instance_valid(game.level_up_button):
		return
	var button := game.level_up_button as Button
	button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	button.scale = Vector2.ONE
	button.pivot_offset = Vector2.ZERO
	button.position = fab_zone.position
	button.custom_minimum_size = fab_zone.size
	button.size = fab_zone.size
	button.set_meta("gold_shell_socket_rect", fab_zone)
	button.set_meta("scrum1057_fab_rect", fab_zone)


func _style_route_map_horizontal_scrollbar(scroll: ScrollContainer, lane_height: float) -> void:
	var scrollbar := scroll.get_h_scroll_bar()
	if scrollbar == null:
		return
	scrollbar.custom_minimum_size.y = lane_height
	scrollbar.focus_mode = Control.FOCUS_NONE
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.055, 0.046, 0.038, 0.94)
	track.border_color = Color(0.40, 0.30, 0.17, 0.90)
	track.set_border_width_all(1)
	track.set_corner_radius_all(maxi(2, int(roundf(lane_height * 0.25))))
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(0.62, 0.45, 0.22, 0.98)
	grabber.border_color = Color(0.90, 0.72, 0.36, 1.0)
	grabber.set_border_width_all(1)
	grabber.set_corner_radius_all(maxi(2, int(roundf(lane_height * 0.25))))
	var grabber_highlight: StyleBoxFlat = grabber.duplicate()
	grabber_highlight.bg_color = Color(0.78, 0.61, 0.31, 1.0)
	scrollbar.add_theme_stylebox_override("scroll", track)
	scrollbar.add_theme_stylebox_override("grabber", grabber)
	scrollbar.add_theme_stylebox_override("grabber_highlight", grabber_highlight)
	scrollbar.add_theme_stylebox_override("grabber_pressed", grabber_highlight)


func _apply_route_map_control_rect(control: Control, rect: Rect2) -> void:
	if control == null:
		return
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position
	control.custom_minimum_size = rect.size
	control.size = rect.size
func _rebuild_route_map_canvas(map_area: Control, canvas_size: Vector2) -> void:
	for child in map_area.get_children():
		map_area.remove_child(child)
		child.queue_free()
	map_area.custom_minimum_size = canvas_size
	map_area.size = canvas_size
	_route_focus_target = null
	var node_positions := _map_node_positions(canvas_size)
	_draw_map_connections(map_area, node_positions)
	_draw_route_nodes(map_area, node_positions)
	if _route_focus_target != null and is_instance_valid(_route_focus_target):
		_route_focus_target.call_deferred("grab_focus")


func _random_battle_node_name(index: int) -> String:
	var names := [
		"Forgotten Road",
		"Broken Watch",
		"Moonlit Crossing",
		"Old Battlefield",
		"Whispering Gate",
		"Ash Path",
	]
	return "Battle %d: %s" % [index + 1, names[game.rng.randi_range(0, names.size() - 1)]]


func _route_map_canvas_size(available_width := -1.0, available_height := -1.0) -> Vector2:
	# SCRUM-1057: columns advance on X. Eight authored columns fit without
	# scrolling; longer runtime routes grow the canvas and use only the bottom
	# horizontal lane. Height always fits the declared node viewport.
	var layout := _route_map_shell_layout(game.get_viewport().get_visible_rect().size)
	var requested_width: float = available_width if available_width > 0.0 else float(layout["node_viewport_rect"].size.x)
	var requested_height: float = available_height if available_height > 0.0 else float(layout["node_viewport_rect"].size.y)
	var column_count: int = maxi(game.route_nodes.size(), game.ROUTE_STEPS_TO_BOSS + 1)
	var node_size := float(layout["node_size"])
	var padding_x := maxf(24.0, roundf(node_size * 0.7))
	var authored_gaps := maxi(ROUTE_HORIZONTAL_VISIBLE_COLUMNS - 1, 1)
	var column_gap := maxf(node_size + 24.0, (requested_width - padding_x * 2.0 - node_size) / float(authored_gaps))
	var width := maxf(requested_width, padding_x * 2.0 + node_size + column_gap * float(maxi(column_count - 1, 0)))
	return Vector2(ceilf(width), maxf(1.0, requested_height))


func _node_pool_for_step(step_index: int) -> Array:
	# SCRUM-786: диапазоны рядов вычисляются от ROUTE_STEPS_TO_BOSS (8 нодов до босса),
	# а не магическими числами, чтобы пулы не «съезжали» при смене длины маршрута.
	var boss_row: int = game.ROUTE_STEPS_TO_BOSS  # ряд босса; не-боссовые ряды = 0..boss_row-1
	# Стартовые ряды — только бои (мягкий заход в акт).
	if step_index < START_BATTLE_ONLY_ROWS:
		return ["battle"]
	# Первый ряд после стартовых — бои + редкое событие.
	if step_index < START_BATTLE_ONLY_ROWS + 1:
		return ["battle", "battle", "battle", "event"]
	# Предбоссовый ряд — без перегруза (отдых/элитка перед боссом).
	if step_index == boss_row - 1:
		return ["rest", "battle", "rest", "elite_battle"]
	# Поздние ряды (последняя треть до босса) — риск/награда: элитки + hazard.
	# SCRUM-608: «Опасная развилка» (hazard) в поздних рядах.
	if step_index >= boss_row - 3:
		return ["battle", "elite_battle", "elite_battle", "event", "battle", "hazard"]
	# Средние ряды. SCRUM-608: hazard в средних рядах.
	return ["battle", "battle", "battle", "rest", "event", "elite_battle", "hazard"]


func _generate_route() -> Array:
	var route := []
	for step_index in range(game.ROUTE_STEPS_TO_BOSS):
		var branches := []
		var branch_count = game.rng.randi_range(game.MIN_BRANCHES_PER_STEP, game.MAX_BRANCHES_PER_STEP)
		for branch_index in range(branch_count):
			var pool := _node_pool_for_step(step_index)
			var node_type: String = pool[game.rng.randi_range(0, pool.size() - 1)]
			branches.append({
				"type": node_type,
				"name": _random_route_node_name(branch_index, node_type),
				"row": step_index,
				"branch": branch_index,
				"seed": game.rng.randi(),
			})
		route.append(branches)
	_place_required_shop_nodes(route)
	_place_chest_line_rows(route)
	_place_altar_node(route)
	route.append([_random_boss_route_node()])
	_assign_route_connections(route)
	return route


func _place_altar_node(route: Array) -> void:
	# SCRUM-610: ровно один «Алтарь жертвы» на маршрут (постоянная сделка тело-за-силу).
	# Переопределяем один уже сгенерированный узел (как chest/shop placement).
	# Стартовые ряды (только бои) исключаем; не затираем обязательные shop/chest, чтобы
	# не сломать их гарантии. Вызывается ДО _assign_route_connections — узел получает
	# связи как обычный узел маршрута.
	var non_boss_rows := route.size()
	if non_boss_rows <= START_BATTLE_ONLY_ROWS:
		return
	# Кандидаты: внутренние ряды (после стартовых, до последнего не-босс ряда),
	# в которых есть хотя бы одна свободная ветка (не shop/chest/elite_battle).
	# SCRUM-994: elite_battle защищён наравне с shop/chest — сгенерированный
	# элитный узел обязан остаться элитным боем, алтарь его не переписывает.
	var candidate_rows := []
	for row_index in range(START_BATTLE_ONLY_ROWS, non_boss_rows):
		var row: Array = route[row_index]
		if row.is_empty():
			continue
		for route_node in row:
			var node_type := str(route_node.get("type", ""))
			if node_type != "shop" and node_type != "chest" and node_type != "elite_battle":
				candidate_rows.append(row_index)
				break
	if candidate_rows.is_empty():
		return
	var chosen_row_index: int = candidate_rows[game.rng.randi_range(0, candidate_rows.size() - 1)]
	var chosen_row: Array = route[chosen_row_index]
	# Свободные ветки в выбранном ряду (не shop/chest/elite_battle), затем случайная из них.
	var free_branches := []
	for branch_index in range(chosen_row.size()):
		var branch_type := str((chosen_row[branch_index] as Dictionary).get("type", ""))
		if branch_type != "shop" and branch_type != "chest" and branch_type != "elite_battle":
			free_branches.append(branch_index)
	if free_branches.is_empty():
		return
	var altar_branch: int = free_branches[game.rng.randi_range(0, free_branches.size() - 1)]
	var altar_node: Dictionary = chosen_row[altar_branch]
	altar_node["type"] = "altar"
	altar_node["name"] = _random_route_node_name(altar_branch, "altar")
	altar_node["event_id"] = "sacrifice_altar"
	chosen_row[altar_branch] = altar_node
	route[chosen_row_index] = chosen_row


func _place_required_shop_nodes(route: Array) -> void:
	var non_boss_rows := route.size()
	if non_boss_rows <= START_BATTLE_ONLY_ROWS:
		return
	var second_half_start: int = clampi(ceili(float(non_boss_rows) * 0.5), START_BATTLE_ONLY_ROWS, non_boss_rows - 1)
	var first_half_start := START_BATTLE_ONLY_ROWS
	var first_half_end := maxi(first_half_start, second_half_start - 1)
	_place_shop_node_in_row_range(route, first_half_start, first_half_end)
	_place_shop_node_in_row_range(route, second_half_start, non_boss_rows - 1)


func _place_shop_node_in_row_range(route: Array, row_start: int, row_end: int) -> void:
	var clamped_start := clampi(row_start, 0, route.size() - 1)
	var clamped_end := clampi(row_end, clamped_start, route.size() - 1)
	var row_index: int = game.rng.randi_range(clamped_start, clamped_end)
	var row: Array = route[row_index]
	if row.is_empty():
		return
	var branch_index: int = game.rng.randi_range(0, row.size() - 1)
	var route_node: Dictionary = row[branch_index]
	route_node["type"] = "shop"
	route_node["name"] = _random_route_node_name(branch_index, "shop")
	row[branch_index] = route_node
	route[row_index] = row


func _place_chest_line_rows(route: Array) -> void:
	# SCRUM-787: вместо одиночного сундука — целые «линии» сундуков (ряд, где КАЖДАЯ ветка
	# = chest). Игрок проходит маршрут по одному ряду за раз (выбирает ровно одну ветку),
	# поэтому full-chest ряд непропускаем: какой бы путь ни выбрал — попадёт на сундук и
	# получит выбор 1-из-3 артефактов. С одного ряда — ровно 1 сундук (по выбранной ветке).
	# Вызывается ПОСЛЕ _place_required_shop_nodes — кандидаты исключают шоп-ряды, чтобы не
	# затереть гарантированный шоп. _place_altar_node идёт после нас и сам избегает
	# full-chest ряда (ему нужна свободная не-shop/не-chest ветка). Детерминированно (без rng).
	var non_boss_rows := route.size()
	if non_boss_rows <= START_BATTLE_ONLY_ROWS:
		return
	var line_count: int = maxi(1, int(game.CHEST_LINE_ROWS))
	# Кандидаты: внутренние ряды (после стартовых battle-only), не содержащие шоп.
	var candidate_rows := []
	for row_index in range(START_BATTLE_ONLY_ROWS, non_boss_rows):
		var row: Array = route[row_index]
		if row.is_empty():
			continue
		var has_shop := false
		for route_node in row:
			if str((route_node as Dictionary).get("type", "")) == "shop":
				has_shop = true
				break
		if not has_shop:
			candidate_rows.append(row_index)
	if candidate_rows.is_empty():
		return
	# Приоритет: ближе к середине акта (детерминированно; при равенстве — меньший индекс).
	var midpoint: int = clampi(int(floor(float(non_boss_rows - 1) * 0.5)), START_BATTLE_ONLY_ROWS, non_boss_rows - 1)
	candidate_rows.sort_custom(func(a, b):
		var da := absi(int(a) - midpoint)
		var db := absi(int(b) - midpoint)
		if da == db:
			return int(a) < int(b)
		return da < db)
	var rows_to_fill: int = mini(line_count, candidate_rows.size())
	for i in range(rows_to_fill):
		_fill_row_with_chests(route, candidate_rows[i])


func _fill_row_with_chests(route: Array, row_index: int) -> void:
	var row: Array = route[row_index]
	for branch_index in range(row.size()):
		var route_node: Dictionary = row[branch_index]
		route_node["type"] = "chest"
		route_node["name"] = _random_route_node_name(branch_index, "chest")
		route_node.erase("event_id")  # на случай если ветка была событием/алтарём
		row[branch_index] = route_node
	route[row_index] = row


func _random_boss_route_node() -> Dictionary:
	var boss_options := [
		{
			"boss_id": "rift_warden",
			"name": "Rift Warden",
		},
		{
			"boss_id": "disk_devourer",
			"name": "Disk Devourer",
		},
		{
			"boss_id": "bone_archon",
			"name": "Bone Archon",
		},
		{
			"boss_id": "brood_mother",
			"name": "Brood Mother",
		},
		{
			"boss_id": "ashen_colossus",
			"name": "Ashen Colossus",
		},
	]
	var boss: Dictionary = boss_options[game.rng.randi_range(0, boss_options.size() - 1)]
	return {
		"type": "boss",
		"name": boss["name"],
		"boss_id": boss["boss_id"],
		"row": game.ROUTE_STEPS_TO_BOSS,
		"branch": 0,
		"seed": game.rng.randi(),
	}


func _assign_route_connections(route: Array) -> void:
	for step_index in range(route.size() - 1):
		var current_row: Array = route[step_index]
		var next_row: Array = route[step_index + 1]
		var incoming := {}
		for next_index in range(next_row.size()):
			incoming[next_index] = 0

		for branch_index in range(current_row.size()):
			var connections := _route_connection_candidates(branch_index, current_row.size(), next_row.size())
			var route_node: Dictionary = current_row[branch_index]
			route_node["next_branches"] = connections
			current_row[branch_index] = route_node
			for next_branch in connections:
				incoming[int(next_branch)] = int(incoming.get(int(next_branch), 0)) + 1

		for next_index in range(next_row.size()):
			if int(incoming.get(next_index, 0)) > 0:
				continue
			var closest_previous := _closest_route_branch_for_next(next_index, current_row.size(), next_row.size())
			var previous_node: Dictionary = current_row[closest_previous]
			var previous_connections: Array = previous_node.get("next_branches", [])
			if not previous_connections.has(next_index):
				previous_connections.append(next_index)
				previous_connections.sort()
			previous_node["next_branches"] = previous_connections
			current_row[closest_previous] = previous_node

		route[step_index] = current_row


func _route_connection_candidates(branch_index: int, current_count: int, next_count: int) -> Array:
	if next_count <= 1:
		return [0]

	var mapped := 0
	if current_count <= 1:
		mapped = int(floor(float(next_count - 1) * 0.5))
	else:
		mapped = int(round(float(branch_index) * float(next_count - 1) / float(current_count - 1)))
	mapped = clampi(mapped, 0, next_count - 1)

	var connections := [mapped]
	if next_count > 2 and game.rng.randf() < 0.64:
		var side := 1 if branch_index <= current_count / 2 else -1
		if game.rng.randf() < 0.35:
			side *= -1
		var extra := clampi(mapped + side, 0, next_count - 1)
		if extra != mapped:
			connections.append(extra)

	connections.sort()
	return connections


func _closest_route_branch_for_next(next_index: int, current_count: int, next_count: int) -> int:
	if current_count <= 1 or next_count <= 1:
		return 0
	return clampi(int(round(float(next_index) * float(current_count - 1) / float(next_count - 1))), 0, current_count - 1)


func _random_route_node_name(index: int, node_type: String) -> String:
	if node_type == "shop":
		return "Shop %d: Broken Caravan" % [index + 1]
	if node_type == "rest":
		return "Rest %d: Moon Well" % [index + 1]
	if node_type == "event":
		return "Event %d: Strange Stone" % [index + 1]
	if node_type == "hazard":
		return "Hazard %d: Dangerous Fork" % [index + 1]
	if node_type == "chest":
		return "Chest %d: Relic Cache" % [index + 1]
	if node_type == "altar":
		return "Алтарь жертвы"
	if node_type == "elite_battle":
		return "Elite %d: Crowned Threat" % [index + 1]
	if node_type == "boss":
		return "Disk Warden"

	return _random_battle_node_name(index)


func _map_node_positions(map_size: Vector2) -> Array:
	var positions := []
	var column_count: int = game.route_nodes.size()
	var layout := _route_map_shell_layout(game.get_viewport().get_visible_rect().size)
	var normal_size := float(layout["node_size"])
	var boss_size := float(layout["boss_size"])
	var padding_x := maxf(24.0, roundf(normal_size * 0.7))
	var usable_width := maxf(1.0, map_size.x - padding_x * 2.0 - normal_size)
	var horizontal_gap := usable_width / float(maxi(column_count - 1, 1))
	for step_index in range(column_count):
		var step_positions := []
		var branch_count: int = game.route_nodes[step_index].size()
		var node_size := boss_size if step_index == column_count - 1 else normal_size
		var x_position := padding_x + horizontal_gap * float(step_index)
		if step_index == column_count - 1:
			x_position -= (boss_size - normal_size) * 0.5
		var minimum_gap := maxf(4.0, roundf(node_size * 0.08))
		var required_height := node_size * float(branch_count) + minimum_gap * float(maxi(branch_count - 1, 0))
		var padding_y := maxf(8.0, roundf((map_size.y - required_height) * 0.5))
		var branch_gap := 0.0
		if branch_count > 1:
			branch_gap = maxf(minimum_gap, (map_size.y - padding_y * 2.0 - node_size * float(branch_count)) / float(branch_count - 1))
		for branch_index in range(branch_count):
			step_positions.append(Vector2(
				x_position,
				padding_y + float(branch_index) * (node_size + branch_gap)
			))
		positions.append(step_positions)
	return positions


func _center_route_map_on_current_row(scroll: ScrollContainer, map_size: Vector2) -> void:
	await game.get_tree().process_frame
	if scroll == null or not is_instance_valid(scroll):
		return
	if game.route_nodes.is_empty():
		return
	var node_positions := _map_node_positions(map_size)
	var active_step = clampi(game.route_stage, 0, node_positions.size() - 1)
	if node_positions[active_step].is_empty():
		return
	var node_size := _route_map_node_size_for_step(active_step)
	var column_center_x := float(node_positions[active_step][0].x) + node_size.x * 0.5
	var focus_ratio := 0.22 if active_step == 0 else 0.5
	var target_x := maxi(0, int(column_center_x - scroll.size.x * focus_ratio))
	scroll.scroll_horizontal = target_x
	scroll.scroll_vertical = 0


func _handle_route_map_pan_input(scroll: ScrollContainer, event: InputEvent) -> void:
	if scroll == null or not is_instance_valid(scroll):
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if _handle_route_map_wheel(scroll, mouse_event):
			return
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			game.route_map_pan_active = mouse_event.pressed
			game.route_map_pan_last_position = mouse_event.position
			game.route_map_drag_distance = 0.0
			game.route_map_drag_suppressed_click = false
	elif event is InputEventMouseMotion and game.route_map_pan_active:
		var motion := event as InputEventMouseMotion
		_pan_route_map_scroll(scroll, motion.relative)


func _pan_route_map_scroll(scroll: ScrollContainer, drag_delta: Vector2) -> void:
	game.route_map_drag_distance += drag_delta.length()
	if game.route_map_drag_distance > game.ROUTE_MAP_DRAG_THRESHOLD:
		game.route_map_drag_suppressed_click = true
	scroll.scroll_horizontal = maxi(0, scroll.scroll_horizontal - int(drag_delta.x))
	scroll.scroll_vertical = 0


func _handle_route_map_wheel(scroll: ScrollContainer, event: InputEventMouseButton) -> bool:
	if not event.pressed or event.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
		return false
	var direction := -1
	if event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT]:
		direction = 1
	var amount := maxi(32, int(roundf(72.0 * maxf(event.factor, 1.0))))
	scroll.scroll_horizontal = maxi(0, scroll.scroll_horizontal + direction * amount)
	scroll.scroll_vertical = 0
	return true


func _route_map_node_size_for_step(step_index: int) -> Vector2:
	var layout := _route_map_shell_layout(game.get_viewport().get_visible_rect().size)
	var is_boss: bool = step_index == game.route_nodes.size() - 1
	var side := float(layout["boss_size"] if is_boss else layout["node_size"])
	return Vector2(side, side)


func _draw_map_connections(map_area: Control, node_positions: Array) -> void:
	for step_index in range(game.route_nodes.size() - 1):
		for from_index in range(node_positions[step_index].size()):
			for to_index in _route_node_connections(step_index, from_index):
				var to_branch := int(to_index)
				if to_branch < 0 or to_branch >= node_positions[step_index + 1].size():
					continue
				var from_position: Vector2 = node_positions[step_index][from_index] + _route_map_node_size_for_step(step_index) * 0.5
				var to_position: Vector2 = node_positions[step_index + 1][to_branch] + _route_map_node_size_for_step(step_index + 1) * 0.5
				var active := _is_route_connection_active(step_index, from_index, to_branch)
				_add_map_line(map_area, from_position, to_position, active)


func _draw_route_nodes(map_area: Control, node_positions: Array) -> void:
	var focusable_buttons: Array[Button] = []
	for step_index in range(game.route_nodes.size()):
		for branch_index in range(game.route_nodes[step_index].size()):
			var route_node: Dictionary = game.route_nodes[step_index][branch_index]
			var node_name: String = route_node["name"]
			var node_type: String = route_node["type"]
			var definition := _map_node_definition(node_type)
			var state := _route_node_state(step_index, branch_index)
			var is_clickable := state == "available" or state == "shop_revisit"
			var button = game.ui._make_button("")
			button.name = "RouteNode_%s_%d_%d" % [node_type, step_index, branch_index]
			UIButtonFamily.assign(button, "route_node")
			button.tooltip_text = _node_preview_tooltip(route_node, definition)
			if state == "shop_revisit":
				button.tooltip_text += "\nПосещено — можно вернуться"
			var authored_node_size := _route_map_node_size_for_step(step_index)
			button.custom_minimum_size = authored_node_size
			button.size = authored_node_size
			button.position = node_positions[step_index][branch_index]
			button.disabled = not is_clickable
			button.set_meta("route_step", step_index)
			button.set_meta("route_branch", branch_index)
			# SCRUM-812: доступные ноды фокусируемы под геймпад/стрелки; недоступные
			# (locked/completed) остаются FOCUS_NONE — фокус-навигация их пропускает.
			button.focus_mode = Control.FOCUS_ALL if is_clickable else Control.FOCUS_NONE
			button.z_index = 20 if is_clickable else 10
			_style_route_node_button(button, node_type, state)
			_add_route_node_icon(button, _route_node_icon_path(route_node, definition), str(definition["icon"]))
			if state == "completed" or state == "shop_revisit":
				_add_route_node_completed_mark(button)
			else:
				# SCRUM-616: компактный угловой бейдж-превью угрозы поверх кнопки для
				# battle/elite_battle/chest — детерминированный хинт без наведения и без
				# нового арта (только Label). На completed/shop_revisit не вешаем (там ✓);
				# на locked бейдж остаётся, но гаснет вместе с modulate кнопки.
				_add_route_node_threat_badge(button, route_node)
				if state == "locked":
					button.modulate = Color(0.55, 0.58, 0.62, 0.72)
			if is_clickable:
				button.gui_input.connect(func(event: InputEvent) -> void:
					_handle_route_node_input(button, event, map_area.get_parent() as ScrollContainer, step_index, branch_index, route_node)
				)
				# SCRUM-812: заметное выделение выбранного нода (золотая кайма) + активация
				# по A/Enter (pressed) для геймпада/стрелок. Мышь идёт своим путём (gui_input);
				# двойную активацию гасит реэнтранси-латч в _activate_route_node.
				button.add_theme_stylebox_override("focus", _route_node_focus_style())
				button.pressed.connect(func() -> void:
					_on_route_node_activate(step_index, branch_index, route_node)
				)
				# Стартовый фокус — доступный нод текущего ряда (первый), иначе первый доступный.
				focusable_buttons.append(button)
				if _route_focus_target == null:
					_route_focus_target = button
				elif step_index == int(game.route_stage) and int(_route_focus_target.get_meta("route_step", -1)) != int(game.route_stage):
					_route_focus_target = button
			map_area.add_child(button)
	_configure_horizontal_route_focus(focusable_buttons, map_area.get_parent() as ScrollContainer)


func _configure_horizontal_route_focus(buttons: Array[Button], scroll: ScrollContainer) -> void:
	for button in buttons:
		button.focus_entered.connect(func() -> void:
			_ensure_route_node_visible(scroll, button)
		)
		var step := int(button.get_meta("route_step", -1))
		var branch := int(button.get_meta("route_branch", -1))
		var same_column: Array[Button] = []
		for candidate in buttons:
			if int(candidate.get_meta("route_step", -1)) == step:
				same_column.append(candidate)
		same_column.sort_custom(func(a: Button, b: Button) -> bool:
			return int(a.get_meta("route_branch", -1)) < int(b.get_meta("route_branch", -1))
		)
		var local_index := same_column.find(button)
		if local_index > 0:
			button.focus_neighbor_top = button.get_path_to(same_column[local_index - 1])
		if local_index >= 0 and local_index + 1 < same_column.size():
			button.focus_neighbor_bottom = button.get_path_to(same_column[local_index + 1])
		var left := _nearest_route_focus_button(buttons, step, branch, -1)
		var right := _nearest_route_focus_button(buttons, step, branch, 1)
		if left != null:
			button.focus_neighbor_left = button.get_path_to(left)
		if right != null:
			button.focus_neighbor_right = button.get_path_to(right)


func _nearest_route_focus_button(buttons: Array[Button], step: int, branch: int, direction: int) -> Button:
	var target_step := step + direction
	while target_step >= 0 and target_step < game.route_nodes.size():
		var candidates: Array[Button] = []
		for candidate in buttons:
			if int(candidate.get_meta("route_step", -1)) == target_step:
				candidates.append(candidate)
		if not candidates.is_empty():
			var best := candidates[0]
			var best_distance := absi(int(best.get_meta("route_branch", 0)) - branch)
			for candidate in candidates:
				var distance := absi(int(candidate.get_meta("route_branch", 0)) - branch)
				if distance < best_distance:
					best = candidate
					best_distance = distance
			return best
		target_step += direction
	return null


func _ensure_route_node_visible(scroll: ScrollContainer, button: Control) -> void:
	if scroll == null or not is_instance_valid(scroll) or button == null or not is_instance_valid(button):
		return
	scroll.ensure_control_visible(button)
	scroll.scroll_vertical = 0


# --- SCRUM-499: детерминированное превью узла в тултипе ---

const _BIOME_NAMES := {
	"field_marsh": "Болото",
	"field_dry_road": "Сухая дорога",
	"field_stone_garden": "Каменный сад",
	"field_meadow": "Луг",
	"field_ruined_courtyard": "Разрушенный двор",
	"field_misty_marsh": "Туманное болото",
	"field_dusty_badlands": "Пыльные пустоши",
	"field_enchanted_meadow": "Зачарованный луг",
	"field_ashen_rift": "Пепельный разлом",
	"field_cursed_grove": "Проклятая роща",
}

const _ENEMY_ARCHETYPES := {
	"res://scenes/Enemy.tscn": "рядовые",
	"res://scenes/EnemyRunner.tscn": "бегуны",
	"res://scenes/EnemyBiter.tscn": "кусачи",
	"res://scenes/EnemyBruiser.tscn": "крупные бронированные",
	"res://scenes/EnemyShield.tscn": "щитоносцы",
	"res://scenes/EnemyFlyingRunner.tscn": "летуны",
	"res://scenes/EnemySummoner.tscn": "призыватели",
	"res://scenes/EnemyShooter.tscn": "стрелки",
	"res://scenes/EnemyMage.tscn": "маги",
	"res://scenes/EnemySpitter.tscn": "плевалы",
	"res://scenes/EnemyBoneShaman.tscn": "костяные шаманы",
}

const _ELITE_NAMES := {
	"res://scenes/EliteArmored.tscn": "Бронированный",
	"res://scenes/EliteStalker.tscn": "Сталкер",
	"res://scenes/ElitePoisoned.tscn": "Отравитель",
	"res://scenes/EliteCommander.tscn": "Командир",
}


func _node_preview_tooltip(route_node: Dictionary, definition: Dictionary) -> String:
	var node_type := str(route_node.get("type", "battle"))
	var node_seed := int(route_node.get("seed", game.fallback_node_seed(route_node)))
	var lines := [str(definition["name"]), str(definition["tooltip"])]
	match node_type:
		"battle":
			lines.append("Арена: " + _biome_display_name(game.node_background_path(node_type, false, node_seed)))
			lines.append("Угроза: " + _wave_threat_hint(route_node, node_seed))
		"elite_battle":
			lines.append("Арена: " + _biome_display_name(game.node_background_path(node_type, false, node_seed)))
			lines.append("Угроза: " + _wave_threat_hint(route_node, node_seed))
			lines.append("Элита: " + _elite_archetype_name(game.node_elite_scene(node_seed)))
			lines.append("Награда: гарантированный артефакт — " + _elite_artifact_tier_hint(route_node))
		"boss":
			lines.append("Босс: " + str(route_node.get("name", "?")))
		"chest":
			lines.append("Награда: выбор 1 из 3 артефактов")
			lines.append("Вес тиров: как у трофея элитки на этой глубине")
		"hazard":
			# SCRUM-608: превью развилки — безопасный исход и угроза рискового боя.
			lines.append("Безопасно: золото + лечение")
			lines.append("Риск: бой — " + _wave_threat_hint(route_node, node_seed))
			lines.append("Победа: +золото, +1 Сила, +урон")
		"altar":
			# SCRUM-610: превью сделки — без боя, цена в HP, постоянный бонус.
			lines.append("Без боя: сделка тело-за-силу")
			lines.append("Цена: часть макс. HP")
			lines.append("Награда: постоянные статы/моды на забег")
	return "\n".join(lines)


func _biome_display_name(path: String) -> String:
	var basename := path.get_file().get_basename()
	if _BIOME_NAMES.has(basename):
		return str(_BIOME_NAMES[basename])
	return basename.trim_prefix("field_").replace("_", " ").capitalize()


func _enemy_archetype_name(path: String) -> String:
	return str(_ENEMY_ARCHETYPES.get(path, "враги"))


func _elite_archetype_name(scene: PackedScene) -> String:
	if scene == null:
		return "элита"
	return str(_ELITE_NAMES.get(scene.resource_path, scene.resource_path.get_file().get_basename()))


func _node_predicted_stage(route_node: Dictionary) -> int:
	# Глубина, на которой узел реально стартует: его ряд + смещение по акту (как route_scaling_stage).
	return int(route_node.get("row", 0)) + (clampi(int(game.current_act), 1, int(game.ACT_COUNT)) - 1) * int(game.ACT_SCALING_STAGE_OFFSET)


func _wave_threat_hint(route_node: Dictionary, node_seed: int) -> String:
	var pred_stage := _node_predicted_stage(route_node)
	# Спец-архетипы с весом как в бою (стрелки/маги/плевалы растут с глубиной); рядовые/бегуны/кусачи — фон.
	var background_kinds := ["res://scenes/Enemy.tscn", "res://scenes/EnemyRunner.tscn", "res://scenes/EnemyBiter.tscn"]
	var ranged_kinds := ["res://scenes/EnemyShooter.tscn", "res://scenes/EnemyMage.tscn", "res://scenes/EnemySpitter.tscn"]
	var specials := {}
	for path in game.ENEMY_SPAWN_WEIGHTS.keys():
		if path in background_kinds:
			continue
		var weight := float(game.ENEMY_SPAWN_WEIGHTS[path])
		if path in ranged_kinds:
			weight *= (0.35 if pred_stage <= 0 else (1.25 if pred_stage >= 2 else 1.0))
		specials[path] = weight
	# Детерминированный сид-выбор «фишки» волны среди взвешенных спецов.
	var generator: RandomNumberGenerator = game.node_aspect_rng(node_seed, 0x27D4EB2F)
	var total := 0.0
	for weight in specials.values():
		total += float(weight)
	var hint_path := "res://scenes/EnemyBruiser.tscn"
	if total > 0.0:
		var roll: float = generator.randf() * total
		var cursor := 0.0
		for path in specials.keys():
			cursor += float(specials[path])
			if roll <= cursor:
				hint_path = path
				break
	var prefix := "лёгкая волна, " if pred_stage <= 0 else ""
	return prefix + "в составе — " + _enemy_archetype_name(hint_path)


func _elite_artifact_tier_hint(route_node: Dictionary) -> String:
	var pred_stage := _node_predicted_stage(route_node)
	# Тот же depth-weighting, что в ProgressionData.elite_artifact_choices.
	# SCRUM-963: формулировки — канон редкости «обычный/редкий/эпический»
	# без номеров тиров (artifact_system_matrix §1.1, TIER_LABELS).
	var scale: float = game.PROGRESSION_DATA.stage_scale(pred_stage)
	var tier3_weight := 0.22 + maxf(float(pred_stage) - 2.0, 0.0) * 0.18
	if tier3_weight >= 0.6:
		return "шанс эпического"
	if scale >= 1.5 or pred_stage >= 3:
		return "ориентир — редкий"
	return "ориентир — обычный или редкий"


func _handle_route_node_input(button: Button, event: InputEvent, scroll: ScrollContainer, step_index: int, branch_index: int, route_node: Dictionary) -> void:
	if scroll == null or not is_instance_valid(scroll):
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if _handle_route_map_wheel(scroll, mouse_event):
			button.accept_event()
			return
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			game.route_map_pan_active = true
			game.route_map_pan_last_position = mouse_event.position
			game.route_map_drag_distance = 0.0
			game.route_map_drag_suppressed_click = false
			button.accept_event()
			return

		var should_open = game.route_map_pan_active and not game.route_map_drag_suppressed_click and not button.disabled
		game.route_map_pan_active = false
		button.accept_event()
		if should_open:
			_activate_route_node(step_index, branch_index, route_node)
	elif event is InputEventMouseMotion and game.route_map_pan_active:
		var motion := event as InputEventMouseMotion
		_pan_route_map_scroll(scroll, motion.relative)
		button.accept_event()


# SCRUM-812: активация нода с геймпада/стрелок (Button.pressed по фокусу). Мышь
# активирует своим путём в _handle_route_node_input; латч в _activate_route_node
# гарантирует однократную активацию за кадр, даже если сработали оба пути.
func _on_route_node_activate(step_index: int, branch_index: int, route_node: Dictionary) -> void:
	if game.route_map_pan_active or game.route_map_drag_suppressed_click:
		return
	_activate_route_node(step_index, branch_index, route_node)


# SCRUM-812: золотая кайма выбранного нода — заметное выделение под геймпад/стрелки
# (Godot рисует "focus"-стайлбокс поверх сфокусированного контрола).
func _route_node_focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_width_left = 5
	style.border_width_top = 5
	style.border_width_right = 5
	style.border_width_bottom = 5
	style.border_color = Color(1.0, 0.84, 0.36, 1.0)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.expand_margin_left = 4.0
	style.expand_margin_top = 4.0
	style.expand_margin_right = 4.0
	style.expand_margin_bottom = 4.0
	return style


func _activate_route_node(step_index: int, branch_index: int, route_node: Dictionary) -> void:
	# SCRUM-812: реэнтранси-латч — активация меняет экран; повторный вызов в том же кадре гасится.
	if _route_node_activating:
		return
	_route_node_activating = true
	if game.shop_reentry_pending and step_index == int(game.shop_reentry_route_stage) + 1:
		_finalize_pending_shop_reentry()
		game.route_stage = step_index
	game.current_route_choice = str(route_node.get("name", ""))
	game.current_node_type = str(route_node.get("type", "battle"))
	game.current_node_seed = int(route_node.get("seed", game.fallback_node_seed(route_node)))
	if game.route_debug_free_pick and step_index != game.route_stage:
		# Debug-переход: прогресс перематывается к выбранному ряду.
		game.route_selected_indices.resize(step_index)
		game.route_stage = step_index
	_record_route_choice(step_index, branch_index)
	_open_route_node(route_node)


func _add_route_node_icon(button: Button, icon_path: String, fallback_text: String) -> void:
	if icon_path == "":
		button.text = fallback_text
		return

	var icon_texture = game._cached_texture(icon_path)
	if icon_texture == null:
		button.text = fallback_text
		return

	var icon := TextureRect.new()
	icon.name = "RouteNodeIcon"
	icon.texture = icon_texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 10.0
	icon.offset_top = 10.0
	icon.offset_right = -10.0
	icon.offset_bottom = -10.0
	button.add_child(icon)


func _add_route_node_completed_mark(button: Button) -> void:
	var mark := Label.new()
	mark.name = "RouteNodeCompletedMark"
	mark.text = "✓"
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# SCRUM-883: 24 фикс → readable (17×1.32…1.45 = 22…25), пол 16.
	mark.add_theme_font_size_override("font_size", _semantic_font(SemanticTypography.ROLE_HUD, 17, 16))
	mark.add_theme_color_override("font_color", Color(0.95, 0.78, 0.32, 1.0))
	mark.set_anchors_preset(Control.PRESET_FULL_RECT)
	mark.offset_left = 42.0
	mark.offset_top = -6.0
	button.add_child(mark)


# SCRUM-616: текст + цвет углового бейджа-превью угрозы для узла.
# Возвращает пустую строку для типов без бейджа (boss/shop/event/rest/...).
func _route_node_threat_badge(route_node: Dictionary) -> Dictionary:
	match str(route_node.get("type", "")):
		"elite_battle":
			# Гарантированная элита + артефакт — «звезда».
			return {"text": "★", "color": Color(0.98, 0.80, 0.30, 1.0)}
		"chest":
			# Выбор 1 из 3 артефактов.
			return {"text": "1/3", "color": Color(0.55, 0.85, 0.95, 1.0)}
		"battle":
			# Буква-хинт силы волны по предсказанной глубине (детерминированно):
			# Л — лёгкая (старт), С — средняя, Т — тяжёлая (глубокие ряды/акты).
			var pred_stage := _node_predicted_stage(route_node)
			if pred_stage <= 0:
				return {"text": "Л", "color": Color(0.62, 0.86, 0.55, 1.0)}
			if pred_stage >= 4:
				return {"text": "Т", "color": Color(0.95, 0.55, 0.45, 1.0)}
			return {"text": "С", "color": Color(0.92, 0.82, 0.45, 1.0)}
	return {}


func _add_route_node_threat_badge(button: Button, route_node: Dictionary) -> void:
	var badge_info := _route_node_threat_badge(route_node)
	if badge_info.is_empty():
		return
	var badge := Label.new()
	badge.name = "RouteNodeThreatBadge"
	badge.text = str(badge_info["text"])
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE  # не перехватывает клик/hover узла
	# SCRUM-883: 17 фикс → readable (12×1.32…1.45 = 16…17), пол 14.
	badge.add_theme_font_size_override("font_size", _semantic_font(SemanticTypography.ROLE_HUD, 12, 14))
	badge.add_theme_color_override("font_color", badge_info["color"])
	# Тёмная подложка-обводка для читаемости поверх иконки.
	badge.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.08, 0.92))
	badge.add_theme_constant_override("outline_size", 5)
	badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
	badge.position = Vector2(4.0, 1.0)  # верхний-левый угол, не на центральной иконке
	badge.z_index = 30  # поверх иконки (icon z неявно 0), но не мешает тултипу кнопки
	button.add_child(badge)


func _route_node_icon_path(route_node: Dictionary, definition: Dictionary) -> String:
	if str(route_node.get("type", "")) == "boss" and str(route_node.get("boss_id", "")) == "disk_devourer":
		return str(definition.get("disk_icon_path", definition.get("icon_path", "")))
	return str(definition.get("icon_path", ""))


func _add_map_line(parent: Control, from_position: Vector2, to_position: Vector2, active: bool) -> void:
	var line := ColorRect.new()
	var delta := to_position - from_position
	line.name = "RouteMapLine"
	line.color = Color(0.95, 0.78, 0.32, 0.72) if active else Color(0.35, 0.42, 0.50, 0.42)
	line.position = from_position
	line.size = Vector2(delta.length(), 2.25 if active else 1.25)
	line.rotation = delta.angle()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.z_index = 0
	parent.add_child(line)
	parent.move_child(line, 0)


func _map_node_definition(node_type: String) -> Dictionary:
	return game.MAP_NODE_DEFINITIONS.get(node_type, game.MAP_NODE_DEFINITIONS["battle"])


func _route_node_state(step_index: int, branch_index: int) -> String:
	if game.route_debug_free_pick:
		return "available"
	if game.shop_reentry_pending:
		var shop_step := int(game.shop_reentry_route_stage)
		var shop_branch := int(game.shop_reentry_branch_index)
		if step_index < shop_step:
			if step_index < game.route_selected_indices.size() and int(game.route_selected_indices[step_index]) == branch_index:
				return "completed"
			return "locked"
		if step_index == shop_step:
			var route_node: Dictionary = game.route_nodes[step_index][branch_index] if step_index >= 0 and step_index < game.route_nodes.size() and branch_index >= 0 and branch_index < game.route_nodes[step_index].size() else {}
			if branch_index == shop_branch and str(route_node.get("type", "")) == "shop":
				return "shop_revisit"
			return "locked"
		if step_index == shop_step + 1:
			if _route_node_connections(shop_step, shop_branch).has(branch_index):
				return "available"
			return "locked"
		return "locked"
	if step_index < game.route_stage:
		if step_index < game.route_selected_indices.size() and int(game.route_selected_indices[step_index]) == branch_index:
			return "completed"
		return "locked"
	if step_index == game.route_stage:
		if not _is_route_node_reachable(step_index, branch_index):
			return "locked"
		return "available"
	return "locked"


func _is_route_node_reachable(step_index: int, branch_index: int) -> bool:
	if step_index == 0:
		return true
	var previous_step := step_index - 1
	if previous_step < 0 or previous_step >= game.route_nodes.size():
		return false
	if previous_step >= game.route_selected_indices.size():
		return false
	var previous_branch = int(game.route_selected_indices[previous_step])
	if previous_branch < 0:
		return false
	return _route_node_connections(previous_step, previous_branch).has(branch_index)


func _route_node_connections(step_index: int, branch_index: int) -> Array:
	if step_index < 0 or step_index >= game.route_nodes.size():
		return []
	if branch_index < 0 or branch_index >= game.route_nodes[step_index].size():
		return []
	var route_node: Dictionary = game.route_nodes[step_index][branch_index]
	return route_node.get("next_branches", [])


func _is_route_connection_active(step_index: int, from_index: int, to_index: int) -> bool:
	if step_index >= game.route_selected_indices.size():
		return false
	if int(game.route_selected_indices[step_index]) != from_index:
		return false
	if step_index + 1 < game.route_selected_indices.size() and int(game.route_selected_indices[step_index + 1]) >= 0:
		return int(game.route_selected_indices[step_index + 1]) == to_index
	return true


func _record_route_choice(step_index: int, branch_index: int) -> void:
	while game.route_selected_indices.size() <= step_index:
		game.route_selected_indices.append(-1)
	game.route_selected_indices[step_index] = branch_index


func _open_route_node(route_node: Dictionary) -> void:
	var node_type := str(route_node.get("type", "battle"))
	if node_type == "shop":
		var route_choice := str(route_node.get("name", game.current_route_choice))
		var shop_node_key := "%d:%d:%s:%s" % [int(game.current_act), int(game.route_stage), node_type, route_choice]
		if game.current_shop_node_key != "" and game.current_shop_node_key != shop_node_key:
			game.current_shop_items.clear()
			game.current_shop_purchased.clear()
			game.current_shop_node_key = ""
	else:
		game.current_shop_items.clear()
		game.current_shop_purchased.clear()
		game.current_shop_node_key = ""
	# SCRUM-968: safe-узлы (магазин/костёр/событие/сундук) — камерная тема привала
	# (спека §2 №3); возврат к "route_map" делает _show_battle_map при выходе.
	# Бои музыку не трогают: их трек ставит _start_combat -> play_combat_music.
	if node_type in ["shop", "rest", "event", "hazard", "altar", "chest"]:
		game._play_music("shop")
	match node_type:
		"shop":
			game.ui._show_shop_screen()
		"rest":
			game.ui._show_rest_screen()
		"event":
			game.ui._show_event_screen(route_node)
		"hazard":
			# SCRUM-608: «Опасная развилка» — детерминированное спец-событие
			# sudden_fork (безопасный обход / рискованный срез). Штампуем event_id,
			# чтобы _show_event_screen загрузил именно его, а не случайное событие.
			var hazard_node := route_node.duplicate(true)
			hazard_node["event_id"] = "sudden_fork"
			game.ui._show_event_screen(hazard_node)
		"altar":
			# SCRUM-610: «Алтарь жертвы» — детерминированное спец-событие sacrifice_altar
			# (сделка тело-за-силу, без боя/арта). Штампуем event_id, чтобы
			# _show_event_screen загрузил именно его, а не случайное событие.
			var altar_node := route_node.duplicate(true)
			altar_node["event_id"] = "sacrifice_altar"
			game.ui._show_event_screen(altar_node)
		"chest":
			game.ui._show_elite_artifact_reward(Callable(self, "_advance_route_after_noncombat"))
		"elite_battle", "elite":
			# SCRUM-994: инвариант «elite = обязательный бой». Элитный узел может
			# войти ТОЛЬКО в элитный бой — никакого event-флоу. Алиас "elite"
			# страхует данные старых сейвов от дрейфа имени типа: без него такой
			# узел свалился бы в дефолтную ветку обычного боя.
			game.combat._start_combat(false, "elite")
		"boss":
			# Route always starts the normal final-act boss; the optional secret
			# boss is spawned only after that victory in combat_director.
			game.current_boss_id = game.resolve_final_act_boss_id(str(route_node.get("boss_id", "rift_warden")))
			game.combat._start_combat(true, "boss")
		_:
			game.combat._start_combat(false, "battle")


func _advance_route_after_noncombat() -> void:
	_finalize_pending_shop_reentry()
	game.route_stage += 1
	game.save_run_autosave("noncombat_node")
	_show_battle_map()


func _return_to_map_after_shop_visit() -> void:
	var selected_branch := -1
	if game.route_stage >= 0 and game.route_stage < game.route_selected_indices.size():
		selected_branch = int(game.route_selected_indices[game.route_stage])
	game.shop_reentry_pending = true
	game.shop_reentry_route_stage = int(game.route_stage)
	game.shop_reentry_branch_index = selected_branch
	game.save_run_autosave("shop_visit")
	_show_battle_map()


func _finalize_pending_shop_reentry() -> void:
	if not game.shop_reentry_pending:
		return
	game.current_shop_items.clear()
	game.current_shop_purchased.clear()
	game.current_shop_node_key = ""
	game.shop_reentry_pending = false
	game.shop_reentry_route_stage = -1
	game.shop_reentry_branch_index = -1


func _style_route_node_button(button: Button, node_type: String, state: String) -> void:
	var definition := _map_node_definition(node_type)
	var background: Color = definition.get("color", Color(0.14, 0.18, 0.24, 1.0))
	var border: Color = definition.get("border", Color(0.48, 0.62, 0.72, 1.0))
	if state == "locked":
		background = Color(0.08, 0.09, 0.12, 0.78)
		border = Color(0.25, 0.28, 0.33, 0.85)
	elif state == "completed" or state == "shop_revisit":
		background = Color(0.13, 0.16, 0.18, 0.90)
		border = Color(0.95, 0.78, 0.32, 0.82)
	elif state == "available":
		background = background.lightened(0.08)
		border = Color(1.0, 0.86, 0.28, 1.0)

	button.add_theme_stylebox_override("normal", _map_node_button_style(background, border))
	button.add_theme_stylebox_override("hover", _map_node_button_style(background.lightened(0.18), Color(1.0, 0.86, 0.28, 1.0)))
	button.add_theme_stylebox_override("pressed", _map_node_button_style(background.darkened(0.16), border))
	button.add_theme_stylebox_override("disabled", _map_node_button_style(background, border))
	button.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.72, 0.74, 0.76, 1.0) if state == "completed" else Color(0.46, 0.48, 0.52, 1.0))
	# SCRUM-883: 34 фикс → readable (24×1.32…1.45 = 32…35), пол 24; фолбэк-буква узла 88×88.
	button.add_theme_font_size_override("font_size", _semantic_font(SemanticTypography.ROLE_ACTION, 24, 24))


func _map_node_button_style(background: Color, _border: Color) -> StyleBox:
	var tint := background.lightened(0.48)
	tint.a = 1.0
	if game.ui != null and game.ui.has_method("_global_texture_style"):
		return game.ui._global_texture_style(
			"res://assets/sprites/ui/frames/global/ui_card_frame.png",
			Vector4(30, 30, 30, 30),
			tint,
			Vector4.ZERO
		)
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = _border
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	return style
