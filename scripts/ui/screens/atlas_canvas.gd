extends "res://scripts/ui/screens/atlas_screen.gd"

# FAN-3824: модуль распределённого UI-класса — канвас Атласа: раскладка узлов, рёбра, вкладки, покупка, фокус.
# Часть линейной extends-цепочки scripts/ui/screens/** (сборка — фасад
# scripts/ui_screens.gd). Код перенесён из ui_screens.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в ui_screens_shared_api.gd.





# Узлы текущего графа: созвездие выбранного класса либо Атлас гильдии.
func _atlas_graph_nodes() -> Array:
	if str(_atlas.get("tab", "constellation")) == "guild":
		return game.META_PROGRESSION.atlas_nodes()
	return game.META_PROGRESSION.constellation_nodes(str(_atlas.get("class_id", "berserk")))




func _atlas_core_node_id() -> String:
	if str(_atlas.get("tab", "constellation")) == "constellation":
		return str(game.META_PROGRESSION.CLASS_ENTRY_NODES.get(str(_atlas.get("class_id", "")), ""))
	for node in game.META_PROGRESSION.atlas_nodes():
		if str((node as Dictionary).get("role", "")) == "core":
			return str((node as Dictionary)["id"])
	return ""




# Пересборка холста под текущую вкладку/класс: кнопки-сокеты + оверлеи состояний.
func _atlas_build_canvas() -> void:
	var canvas: Control = _atlas.get("canvas")
	if canvas == null or not is_instance_valid(canvas):
		return
	for nb in (_atlas.get("node_buttons", {}) as Dictionary).values():
		if nb is Node and is_instance_valid(nb):
			(nb as Node).queue_free()
	_atlas["node_buttons"] = {}
	_atlas["fog_tweens"] = {}
	_atlas["edge_flash"] = {}
	var socket_scale := _atlas_socket_scale()
	var nodes := _atlas_graph_nodes()
	var npos_map := {}
	for node in nodes:
		npos_map[str((node as Dictionary)["id"])] = (node as Dictionary).get("npos", Vector2(0.5, 0.5))
	_atlas["npos"] = npos_map
	var edges := []
	for node in nodes:
		var a_id := str((node as Dictionary)["id"])
		for raw_neighbor in (node as Dictionary).get("adj", []):
			var b_id := str(raw_neighbor)
			if a_id < b_id and npos_map.has(b_id):
				edges.append([a_id, b_id])
	_atlas["edges"] = edges
	for node in nodes:
		var node_data: Dictionary = node
		var node_id := str(node_data["id"])
		var role := str(node_data.get("role", "minor"))
		var affinity := str(node_data.get("class_affinity", ""))
		var nb := TextureButton.new()
		nb.name = "AtlasNode_%s" % node_id
		UIButtonFamily.assign(nb, "atlas_socket")
		var base_path := str(META40_SOCKET_TEXTURES.get(role, META40_SOCKET_TEXTURES["minor"]))
		if role == "core" and affinity != "":
			base_path = META40_UI_DIR + "crest_%s.png" % affinity
		nb.texture_normal = game._cached_texture(base_path)
		nb.ignore_texture_size = true
		nb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		var disp := maxf(24.0, roundf(float(ATLAS_SOCKET_SIZES.get(role, 96.0)) * socket_scale))
		nb.custom_minimum_size = Vector2(disp, disp)
		nb.size = Vector2(disp, disp)
		# SCRUM-970: keep the visible socket itself as the authoritative pointer
		# target at every stretch ratio. Previewing on button-down also prevents a
		# responsive relayout/focus change from stealing the release phase.
		nb.mouse_filter = Control.MOUSE_FILTER_STOP
		nb.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		nb.focus_mode = Control.FOCUS_ALL
		nb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		nb.tooltip_text = "%s\n%s" % [str(node_data.get("title", "")), str(node_data.get("desc", ""))]
		nb.set_meta("node_id", node_id)
		nb.set_meta("role", role)
		nb.pressed.connect(Callable(self, "_atlas_node_pressed").bind(node_id))
		nb.focus_entered.connect(Callable(self, "_atlas_node_focused").bind(node_id))
		canvas.add_child(nb)
		(_atlas["node_buttons"] as Dictionary)[node_id] = nb
		# Оверлеи состояний (§7): выбор, пульс доступности, звезда, кольцо keystone, туман.
		var select_ring := _atlas_add_overlay(nb, "Select", META40_KEYSTONE_RING_PATH, 1.30, Color(0.55, 0.80, 1.0, 0.85))
		select_ring.z_index = 1
		var glow := _atlas_add_overlay(nb, "Glow", META40_STAR_ALLOC_PATH, 1.30, Color(0.66, 0.80, 1.0, 0.9))
		var glow_pulse := glow.create_tween()
		glow_pulse.set_loops()
		glow_pulse.tween_property(glow, "self_modulate:a", 0.95, 0.7).from(0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		glow_pulse.tween_property(glow, "self_modulate:a", 0.30, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if role != "core":
			var star := _atlas_add_overlay(nb, "Star", META40_STAR_ALLOC_PATH, 0.80, Color.WHITE)
			star.z_index = 1
		if role == "keystone":
			var ring := _atlas_add_overlay(nb, "Ring", META40_KEYSTONE_RING_PATH, 1.42, Color(0.72, 0.88, 1.0, 1.0))
			var ring_pulse := ring.create_tween()
			ring_pulse.set_loops()
			ring_pulse.tween_property(ring, "self_modulate:a", 1.0, 1.1).from(0.72).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			ring_pulse.tween_property(ring, "self_modulate:a", 0.72, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if role == "hidden":
			var qmark := Label.new()
			qmark.name = "QMark"
			qmark.set_anchors_preset(Control.PRESET_FULL_RECT)
			qmark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			qmark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			qmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			qmark.text = "?"
			qmark.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
				SemanticTypography.ROLE_HUD, int(maxf(14.0, disp * 0.40))
			))
			qmark.add_theme_color_override("font_color", Color(0.82, 0.90, 1.0, 0.92))
			nb.add_child(qmark)
			var fog := _atlas_add_overlay(nb, "Fog", str(META40_SOCKET_TEXTURES["hidden"]), 1.0, Color.WHITE)
			fog.z_index = 2
	# Выбор по умолчанию — ядро (панель сразу информативна).
	if str(_atlas.get("selected", "")) == "" or not npos_map.has(str(_atlas.get("selected", ""))):
		_atlas["selected"] = _atlas_core_node_id()
	_atlas_layout_nodes()
	_atlas_schedule_layout_passes()




func _atlas_add_overlay(nb: TextureButton, overlay_name: String, texture_path: String, rel: float, tint: Color) -> TextureRect:
	var overlay := TextureRect.new()
	overlay.name = overlay_name
	overlay.texture = game._cached_texture(texture_path)
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var side := nb.custom_minimum_size.x * rel
	overlay.size = Vector2(side, side)
	overlay.position = (nb.custom_minimum_size - overlay.size) * 0.5
	overlay.pivot_offset = overlay.size * 0.5
	overlay.modulate = tint
	overlay.visible = false
	nb.add_child(overlay)
	return overlay




# Раскладка узлов: всё созвездие ЦЕЛИКОМ в холсте (без пан/зума), npos 0..1.
func _atlas_layout_nodes() -> void:
	var canvas: Control = _atlas.get("canvas")
	var edge_layer: Control = _atlas.get("edge_layer")
	if canvas == null or not is_instance_valid(canvas):
		return
	if canvas.size.x <= 1.0 or canvas.size.y <= 1.0:
		call_deferred("_atlas_layout_nodes")
		return
	var s := _atlas_ui_scale()
	var pad := ATLAS_NODE_LAYOUT_PAD * s
	var area := Vector2(maxf(canvas.size.x - pad.x * 2.0, 8.0), maxf(canvas.size.y - pad.y * 2.0, 8.0))
	var centers := {}
	var radii := {}
	var buttons: Dictionary = _atlas.get("node_buttons", {})
	var npos_map: Dictionary = _atlas.get("npos", {})
	for node_id in buttons.keys():
		var nb := buttons[node_id] as TextureButton
		if nb == null or not is_instance_valid(nb):
			continue
		var npos: Vector2 = npos_map.get(node_id, Vector2(0.5, 0.5))
		var radius := minf(nb.custom_minimum_size.x, nb.custom_minimum_size.y) * 0.5
		var center := pad + npos * area
		center.x += _atlas_column_jitter(str(node_id), npos, npos_map, radius, s)
		center = _atlas_clamp_node_center(center, radius, canvas.size, s)
		centers[node_id] = center
		radii[node_id] = radius
	_atlas_relax_node_centers(centers, radii, canvas.size, s)
	_atlas_place_open_node_centers(centers, radii, canvas.size, s)
	for node_id in buttons.keys():
		var nb := buttons[node_id] as TextureButton
		if nb == null or not is_instance_valid(nb) or not centers.has(node_id):
			continue
		var center: Vector2 = centers[node_id]
		nb.position = center - nb.custom_minimum_size * 0.5
	_atlas["node_centers"] = centers
	if edge_layer != null and is_instance_valid(edge_layer):
		edge_layer.queue_redraw()




func _atlas_finish_deferred_layout() -> void:
	if _atlas.is_empty():
		return
	var canvas = _atlas.get("canvas")
	if canvas == null or not is_instance_valid(canvas):
		_atlas["layout_passes_left"] = 0
		return
	_atlas_layout_nodes()
	_atlas_wire_focus()




func _atlas_schedule_layout_passes() -> void:
	if _atlas.is_empty():
		return
	_atlas["layout_passes_left"] = maxi(int(_atlas.get("layout_passes_left", 0)), 6)
	call_deferred("_atlas_finish_deferred_layout")
	if game != null and game.get_tree() != null:
		var layout_pass := Callable(self, "_atlas_process_frame_layout")
		if not game.get_tree().process_frame.is_connected(layout_pass):
			game.get_tree().process_frame.connect(layout_pass, CONNECT_ONE_SHOT)




func _atlas_process_frame_layout() -> void:
	if _atlas.is_empty():
		return
	_atlas_finish_deferred_layout()
	var remaining := maxi(int(_atlas.get("layout_passes_left", 0)) - 1, 0)
	_atlas["layout_passes_left"] = remaining
	if remaining > 0 and game != null and game.get_tree() != null:
		var layout_pass := Callable(self, "_atlas_process_frame_layout")
		if not game.get_tree().process_frame.is_connected(layout_pass):
			game.get_tree().process_frame.connect(layout_pass, CONNECT_ONE_SHOT)




func _atlas_column_jitter(node_id: String, npos: Vector2, npos_map: Dictionary, radius: float, s: float) -> float:
	var rank := 0
	var group_size := 0
	for other_id in npos_map.keys():
		var other_pos: Vector2 = npos_map.get(other_id, Vector2.ZERO)
		if absf(other_pos.x - npos.x) > 0.026:
			continue
		group_size += 1
		if other_pos.y < npos.y:
			rank += 1
	if group_size < 2 or node_id == _atlas_core_node_id():
		return 0.0
	var side := -1.0 if rank % 2 == 0 else 1.0
	return side * maxf(radius * 2.10, 30.0 * s)




func _atlas_relax_node_centers(centers: Dictionary, radii: Dictionary, canvas_size: Vector2, s: float) -> void:
	var ids := centers.keys()
	var gap := maxf(2.0, ATLAS_NODE_COLLISION_GAP * s)
	for iteration in range(ATLAS_NODE_RELAX_ITERATIONS):
		var moved := false
		for first_index in range(ids.size()):
			var first_id = ids[first_index]
			if not centers.has(first_id) or not radii.has(first_id):
				continue
			for second_index in range(first_index + 1, ids.size()):
				var second_id = ids[second_index]
				if not centers.has(second_id) or not radii.has(second_id):
					continue
				var first_center: Vector2 = centers[first_id]
				var second_center: Vector2 = centers[second_id]
				var delta := second_center - first_center
				var distance := delta.length()
				var min_distance := float(radii[first_id]) + float(radii[second_id]) + gap
				if distance >= min_distance:
					continue
				var direction := Vector2.ZERO
				if distance > 0.001:
					if absf(delta.x) < min_distance * 0.35:
						var pair_hash := int(("%s/%s" % [str(first_id), str(second_id)]).hash())
						var side := -1.0 if pair_hash % 2 == 0 else 1.0
						delta.x += side * min_distance * 0.72
						distance = delta.length()
					direction = delta / distance
				else:
					var angle := TAU * float(first_index + second_index + iteration + 1) / maxf(float(ids.size()), 1.0)
					direction = Vector2(cos(angle), sin(angle))
					distance = 0.0
				var push := min_distance - distance
				var first_radius := float(radii[first_id])
				var second_radius := float(radii[second_id])
				var total_radius := maxf(first_radius + second_radius, 1.0)
				first_center -= direction * push * (second_radius / total_radius)
				second_center += direction * push * (first_radius / total_radius)
				centers[first_id] = _atlas_clamp_node_center(first_center, first_radius, canvas_size, s)
				centers[second_id] = _atlas_clamp_node_center(second_center, second_radius, canvas_size, s)
				moved = true
		if not moved:
			return




func _atlas_place_open_node_centers(centers: Dictionary, radii: Dictionary, canvas_size: Vector2, s: float) -> void:
	var remaining := centers.keys()
	var placed := {}
	var core_id := _atlas_core_node_id()
	while remaining.size() > 0:
		var best_index := 0
		var best_score := -INF
		for idx in range(remaining.size()):
			var node_id = remaining[idx]
			var score := float(radii.get(node_id, 0.0))
			if str(node_id) == core_id:
				score += 1000.0
			if score > best_score:
				best_score = score
				best_index = idx
		var place_id = remaining[best_index]
		remaining.remove_at(best_index)
		var radius := float(radii.get(place_id, 1.0))
		var anchor: Vector2 = centers.get(place_id, canvas_size * 0.5)
		placed[place_id] = _atlas_find_open_node_center(anchor, radius, placed, radii, canvas_size, s)
	for node_id in placed.keys():
		centers[node_id] = placed[node_id]




func _atlas_find_open_node_center(anchor: Vector2, radius: float, placed: Dictionary, radii: Dictionary, canvas_size: Vector2, s: float) -> Vector2:
	var gap := maxf(2.0, ATLAS_NODE_COLLISION_GAP * s)
	var start := _atlas_clamp_node_center(anchor, radius, canvas_size, s)
	if _atlas_node_center_is_open(start, radius, placed, radii, gap):
		return start
	var best_center := start
	var best_clearance := -INF
	var step := maxf(12.0 * s, radius * 0.55)
	var angle_count := 16
	for ring in range(1, 34):
		var distance := step * float(ring)
		for angle_index in range(angle_count):
			var angle := TAU * float(angle_index) / float(angle_count)
			var candidate := _atlas_clamp_node_center(anchor + Vector2(cos(angle), sin(angle)) * distance, radius, canvas_size, s)
			var clearance := _atlas_node_center_clearance(candidate, radius, placed, radii)
			if clearance > best_clearance:
				best_clearance = clearance
				best_center = candidate
			if clearance >= gap:
				return candidate
	return best_center




func _atlas_node_center_is_open(center: Vector2, radius: float, placed: Dictionary, radii: Dictionary, gap: float) -> bool:
	return _atlas_node_center_clearance(center, radius, placed, radii) >= gap




func _atlas_node_center_clearance(center: Vector2, radius: float, placed: Dictionary, radii: Dictionary) -> float:
	var clearance := INF
	for other_id in placed.keys():
		var other_center: Vector2 = placed[other_id]
		var other_radius := float(radii.get(other_id, 0.0))
		clearance = minf(clearance, center.distance_to(other_center) - radius - other_radius)
	return clearance




func _atlas_clamp_node_center(center: Vector2, radius: float, canvas_size: Vector2, s: float) -> Vector2:
	var edge_gap := maxf(2.0, ATLAS_NODE_COLLISION_GAP * s * 0.5)
	var min_pos := Vector2(radius + edge_gap, radius + edge_gap)
	var max_pos := Vector2(
		maxf(min_pos.x, canvas_size.x - radius - edge_gap),
		maxf(min_pos.y, canvas_size.y - radius - edge_gap)
	)
	return Vector2(
		clampf(center.x, min_pos.x, max_pos.x),
		clampf(center.y, min_pos.y, max_pos.y)
	)




# Силуэт-линии созвездия: тусклые до покупки, золотые между купленными; вспышка
# покупки временно «зажигает» рёбра купленного узла (edge_flash).
func _atlas_draw_edges() -> void:
	var edge_layer: Control = _atlas.get("edge_layer")
	if edge_layer == null or not is_instance_valid(edge_layer):
		return
	var centers: Dictionary = _atlas.get("node_centers", {})
	var status: Dictionary = _atlas.get("status", {})
	var flash: Dictionary = _atlas.get("edge_flash", {})
	var s := _atlas_ui_scale()
	for edge in _atlas.get("edges", []):
		var a_id := str((edge as Array)[0])
		var b_id := str((edge as Array)[1])
		if not centers.has(a_id) or not centers.has(b_id):
			continue
		var a_on := str(status.get(a_id, "")) == "purchased"
		var b_on := str(status.get(b_id, "")) == "purchased"
		var color := Color(0.46, 0.60, 0.82, 0.28)
		var width := maxf(2.0, 2.6 * s)
		if a_on and b_on:
			color = Color(0.93, 0.77, 0.40, 0.92)
			width = maxf(3.0, 5.0 * s)
		elif a_on or b_on:
			color = Color(0.78, 0.67, 0.45, 0.55)
			width = maxf(2.5, 3.6 * s)
		var flash_amount := maxf(float(flash.get(a_id, 0.0)), float(flash.get(b_id, 0.0)))
		if flash_amount > 0.0:
			color = color.lerp(Color(1.0, 0.92, 0.62, 1.0), clampf(flash_amount, 0.0, 1.0))
			width += 2.0 * flash_amount
		edge_layer.draw_line(centers[a_id], centers[b_id], color, width, true)




# Полное обновление: валюты в шапке, медальоны, состояния узлов, панель узла.
func _atlas_refresh() -> void:
	if _atlas.is_empty():
		return
	var root: Control = _atlas.get("root")
	if root == null or not is_instance_valid(root):
		return
	var state: Dictionary = game.meta_state
	var class_id := str(_atlas.get("class_id", "berserk"))
	var on_guild := str(_atlas.get("tab", "constellation")) == "guild"
	var selected_class_label := _atlas.get("selected_class_label") as Label
	if selected_class_label != null and is_instance_valid(selected_class_label):
		var class_config: Dictionary = game.PROGRESSION_DATA.character_config(class_id)
		selected_class_label.text = str(class_config.get("title", class_id))
		selected_class_label.tooltip_text = "Выбранный класс: %s" % selected_class_label.text

	var emblems_label := _atlas.get("emblems_label") as Label
	if emblems_label != null and is_instance_valid(emblems_label):
		var genitive := str(ATLAS_CLASS_GENITIVE.get(class_id, "класса"))
		var emblem_count: int = game.META_PROGRESSION.class_sigils_available(state, class_id)
		var emblem_text := "Эмблемы %s: %d" % [genitive, emblem_count]
		emblems_label.text = str(emblem_count) if bool(_atlas.get("compact_header_currency", false)) else emblem_text
		var emblem_badge := _atlas.get("emblem_badge") as Control
		if emblem_badge != null:
			emblem_badge.tooltip_text = emblem_text
	var stardust_label := _atlas.get("stardust_label") as Label
	if stardust_label != null and is_instance_valid(stardust_label):
		var stardust_count: int = game.META_PROGRESSION.stardust_available(state)
		var stardust_text := "Звёздная пыль: %d" % stardust_count
		stardust_label.text = str(stardust_count) if bool(_atlas.get("compact_header_currency", false)) else stardust_text
		var stardust_badge := _atlas.get("stardust_badge") as Control
		if stardust_badge != null:
			stardust_badge.tooltip_text = stardust_text

	# Медальоны: подсветка выбранного, прогресс x/N, бейдж непотраченных эмблем.
	var purchased_all: Array = game.META_PROGRESSION.purchased_nodes(state)
	for raw_mb in _atlas.get("medallions", []):
		var mb := raw_mb as TextureButton
		if mb == null or not is_instance_valid(mb):
			continue
		var cid := str(mb.get_meta("class_id"))
		mb.modulate = Color.WHITE if (cid == class_id and not on_guild) else Color(0.68, 0.70, 0.78, 0.88)
		var visible_total := 0
		var visible_bought := 0
		for node in game.META_PROGRESSION.constellation_nodes(cid):
			if str((node as Dictionary).get("role", "")) == "hidden":
				continue
			visible_total += 1
			if purchased_all.has(str((node as Dictionary)["id"])):
				visible_bought += 1
		var prog := mb.find_child("AtlasMedallionProgress_%s" % cid, true, false) as Label
		if prog != null:
			prog.text = "%d/%d" % [visible_bought, visible_total]
		var unspent: int = game.META_PROGRESSION.class_sigils_available(state, cid)
		var badge := mb.find_child("AtlasMedallionBadge_%s" % cid, true, false) as PanelContainer
		if badge != null:
			badge.visible = unspent > 0
			var badge_label := badge.find_child("BadgeCount", true, false) as Label
			if badge_label != null:
				badge_label.text = str(mini(unspent, 99))

	# Состояния узлов текущего графа (§7: 6 состояний).
	var status_map := {}
	var buttons: Dictionary = _atlas.get("node_buttons", {})
	for node_id in buttons.keys():
		status_map[node_id] = str(game.META_PROGRESSION.node_status(state, str(node_id)))
	_atlas["status"] = status_map
	var selected_id := str(_atlas.get("selected", ""))
	for node_id in buttons.keys():
		var nb := buttons[node_id] as TextureButton
		if nb == null or not is_instance_valid(nb):
			continue
		var role := str(nb.get_meta("role"))
		var node_status := str(status_map.get(node_id, "locked"))
		match node_status:
			"purchased":
				nb.modulate = Color.WHITE
			"available":
				nb.modulate = Color.WHITE
			"hidden":
				nb.modulate = Color(0.86, 0.90, 0.99, 0.92)
			_:
				nb.modulate = Color(0.52, 0.55, 0.63, 0.78)
		var glow := nb.get_node_or_null("Glow") as TextureRect
		if glow != null:
			glow.visible = node_status == "available"
		var star := nb.get_node_or_null("Star") as TextureRect
		if star != null:
			star.visible = node_status == "purchased" and role != "core"
			if role == "keystone":
				var keystone_active: bool = game.META_PROGRESSION.is_keystone_active(state, str(node_id))
				# Купленная неактивная ключевая — «тлеет»; активная — золото + сапфир.
				star.self_modulate = Color.WHITE if keystone_active else Color(1.0, 0.56, 0.28, 0.72)
		var ring := nb.get_node_or_null("Ring") as TextureRect
		if ring != null:
			ring.visible = role == "keystone" and game.META_PROGRESSION.is_keystone_active(state, str(node_id))
		var select_ring := nb.get_node_or_null("Select") as TextureRect
		if select_ring != null:
			select_ring.visible = str(node_id) == selected_id
		var qmark := nb.get_node_or_null("QMark") as Label
		if qmark != null:
			qmark.visible = node_status == "hidden"
		# Церемония открытия скрытой звезды: рассеивание тумана 0.6с, скип кликом.
		if role == "hidden" and node_status == "purchased" and not _atlas_hidden_seen.has(node_id):
			_atlas_hidden_seen[node_id] = true
			var fog := nb.get_node_or_null("Fog") as TextureRect
			if fog != null:
				fog.visible = true
				fog.modulate = Color.WHITE
				var fog_tween := fog.create_tween()
				fog_tween.tween_property(fog, "modulate:a", 0.0, ATLAS_FOG_DISSOLVE_SEC)
				fog_tween.tween_callback(Callable(self, "_atlas_finish_fog").bind(str(node_id)))
				(_atlas["fog_tweens"] as Dictionary)[node_id] = fog_tween

	var edge_layer: Control = _atlas.get("edge_layer")
	if edge_layer != null and is_instance_valid(edge_layer):
		edge_layer.queue_redraw()
	_atlas_refresh_node_panel()




# Правая панель: титул/тип/описание С ЧИСЛАМИ/цена/кнопки; для keystone —
# переключатель активности; для скрытой — условие и прогресс подвига.
func _atlas_refresh_node_panel() -> void:
	var state: Dictionary = game.meta_state
	var on_guild := str(_atlas.get("tab", "constellation")) == "guild"
	var selected_id := str(_atlas.get("selected", ""))
	var node: Dictionary = game.META_PROGRESSION.node_by_id(selected_id)
	var kind_label := _atlas.get("panel_kind") as Label
	var icon := _atlas.get("panel_icon") as TextureRect
	var title_label := _atlas.get("panel_title") as Label
	var desc_label := _atlas.get("panel_desc") as Label
	var final_callout := _atlas.get("panel_final_callout") as Label
	var condition_label := _atlas.get("panel_condition") as Label
	var lore_label := _atlas.get("panel_lore") as Label
	var price_row := _atlas.get("panel_price_row") as HBoxContainer
	var price_label := _atlas.get("panel_price_label") as Label
	var price_icon := _atlas.get("panel_price_icon") as TextureRect
	var buy_button := _atlas.get("buy_button") as Button
	var keystone_toggle := _atlas.get("keystone_toggle") as Button
	var progress_label := _atlas.get("panel_progress") as Label
	var hidden_hint := _atlas.get("panel_hidden_hint") as Label
	for control in [kind_label, icon, title_label, final_callout, desc_label, condition_label, lore_label, price_row, price_label, price_icon, buy_button, keystone_toggle, progress_label, hidden_hint]:
		if control == null or not is_instance_valid(control):
			return
	var currency_icon_path := META40_CURRENCY_STARDUST_PATH if on_guild else META40_CURRENCY_EMBLEM_PATH
	var currency_word := "пыль" if on_guild else "эмблему"
	if node.is_empty():
		kind_label.text = "АТЛАС ГЕРОЕВ"
		icon.texture = game._cached_texture(str(META40_SOCKET_TEXTURES["minor"]))
		title_label.text = "Выберите звезду"
		desc_label.text = "Кликните по звезде созвездия, чтобы увидеть её силу и цену."
		final_callout.visible = false
		condition_label.visible = false
		lore_label.visible = false
		price_row.visible = false
		buy_button.visible = false
		keystone_toggle.visible = false
	else:
		var role := str(node.get("role", "minor"))
		var affinity := str(node.get("class_affinity", ""))
		var node_status := str(game.META_PROGRESSION.node_status(state, selected_id))
		kind_label.text = "ХАБ ГИЛЬДИИ" if (role == "core" and affinity == "") else str(ATLAS_ROLE_LABELS.get(role, "ЗВЕЗДА"))
		var icon_path := str(META40_SOCKET_TEXTURES.get(role, META40_SOCKET_TEXTURES["minor"]))
		if role == "core" and affinity != "":
			icon_path = META40_UI_DIR + "crest_%s.png" % affinity
		icon.texture = game._cached_texture(icon_path)
		title_label.text = str(node.get("title", ""))
		var dossier: Dictionary = node.get("dossier", {})
		var dossier_valid := affinity == "" or (bool(node.get("dossier_valid", false)) and not dossier.is_empty())
		var is_weapon_final := role == "weapon_final" and dossier_valid
		final_callout.text = str(dossier.get("final_callout", "УНИКАЛЬНЫЙ ФИНАЛ"))
		final_callout.visible = is_weapon_final
		desc_label.text = str(node.get("desc", "")) if affinity == "" else (str(dossier.get("full_text", "")) if dossier_valid else ConstellationDescriptionFormatter.FAILURE_TEXT)
		lore_label.text = str(node.get("lore", ""))
		lore_label.visible = role == "hidden" and lore_label.text != ""
		condition_label.visible = false
		if role == "hidden":
			var progress: Dictionary = game.META_PROGRESSION.hidden_star_progress(state, selected_id)
			if not progress.is_empty():
				condition_label.visible = true
				if bool(progress.get("unlocked", false)):
					condition_label.text = "Подвиг совершён — тайную звезду можно купить."
				else:
					condition_label.text = "Условие: %s\nПрогресс: %d/%d" % [str(progress.get("text", "")), int(progress.get("current", 0)), int(progress.get("required", 1))]
		# Schema 6 hidden stars are reveal-then-purchase: the challenge only
		# exposes the node; its exact weapon-scoped effect still costs one sigil.
		var purchasable := role != "core" and (role != "hidden" or node_status != "hidden")
		var cost := int(node.get("cost", 0))
		price_row.visible = purchasable and node_status != "purchased"
		price_label.text = "Цена: %d" % cost
		price_icon.texture = game._cached_texture(currency_icon_path)
		buy_button.visible = purchasable and node_status != "purchased"
		buy_button.text = "Вложить %s" % currency_word
		buy_button.disabled = node_status != "available"
		var dossier_blocked := affinity != "" and not dossier_valid
		if dossier_blocked:
			buy_button.disabled = true
			condition_label.visible = true
			condition_label.text = "Покупка отключена: требуется корректный schema-6 dossier."
		# SCRUM-1094: an explicit fail-closed schema error has higher precedence
		# than ordinary adjacency/currency/purchased status hints.  Never replace
		# the actionable failure with a plausible generic condition.
		elif node_status == "locked":
			var have: int = game.META_PROGRESSION.currency_available_for_node(state, selected_id)
			condition_label.visible = true
			if have < cost:
				condition_label.text = "Не хватает: %d из %d. Зарабатывайте %s подвигами класса." % [have, cost, "пыль" if on_guild else "эмблемы"]
			else:
				condition_label.text = "Нужна соседняя купленная звезда."
		elif purchasable and node_status == "purchased":
			condition_label.visible = true
			condition_label.text = "Звезда зажжена."
		# Schema-6 weapon finals are independent permanent path capstones. They
		# never reuse the legacy mutually-exclusive keystone activation control.
		keystone_toggle.visible = role == "keystone" and affinity != "" and node_status == "purchased"
		if keystone_toggle.visible:
			var active: bool = game.META_PROGRESSION.is_keystone_active(state, selected_id)
			keystone_toggle.text = "Активна — погасить" if active else "Сделать активной"

	# Итоги внизу панели: прогресс созвездия/Атласа + подсказка о скрытой звезде.
	var graph_nodes := _atlas_graph_nodes()
	var purchased_all: Array = game.META_PROGRESSION.purchased_nodes(state)
	var visible_total := 0
	var visible_bought := 0
	var hint_text := ""
	for raw_node in graph_nodes:
		var graph_node: Dictionary = raw_node
		if str(graph_node.get("role", "")) == "hidden":
			if hint_text == "" and not game.META_PROGRESSION.hidden_star_unlocked(state, str(graph_node["id"])):
				var progress: Dictionary = game.META_PROGRESSION.hidden_star_progress(state, str(graph_node["id"]))
				hint_text = "До скрытой звезды: %s (%d/%d)" % [str(progress.get("text", "")), int(progress.get("current", 0)), int(progress.get("required", 1))]
			continue
		visible_total += 1
		if purchased_all.has(str(graph_node["id"])):
			visible_bought += 1
	if on_guild:
		progress_label.text = "Атлас гильдии: %d/%d" % [visible_bought, visible_total]
	else:
		var power: float = game.META_PROGRESSION.estimated_class_power_multiplier(state, str(_atlas.get("class_id", "berserk")))
		progress_label.text = "Созвездие: %d/%d · Сила класса: +%d%%" % [visible_bought, visible_total, int(roundf((power - 1.0) * 100.0))]
	hidden_hint.text = hint_text
	hidden_hint.visible = hint_text != ""
	var info_scroll := _atlas.get("panel_scroll") as ScrollContainer
	if info_scroll != null and is_instance_valid(info_scroll):
		info_scroll.scroll_vertical = 0
		info_scroll.set_deferred("scroll_vertical", 0)




func _atlas_node_pressed(node_id: String) -> void:
	_atlas_skip_fog_ceremonies()
	# SCRUM-838: clicking an Atlas cell is preview-only. Purchasing or keystone
	# activation must go through the explicit action buttons in the right panel.
	_atlas_select_node(node_id)




func _atlas_node_focused(node_id: String) -> void:
	# Геймпад/клавиатура: фокус на узле сразу показывает его в панели.
	if str(_atlas.get("selected", "")) != node_id:
		_atlas_select_node(node_id)




func _atlas_select_node(node_id: String) -> void:
	if _atlas.is_empty():
		return
	_atlas["selected"] = node_id
	_atlas_refresh()
	_atlas_wire_focus()




func _atlas_select_class(class_id: String) -> void:
	if _atlas.is_empty() or str(_atlas.get("class_id", "")) == class_id and str(_atlas.get("tab", "")) == "constellation":
		_atlas_refresh()
		return
	_atlas["class_id"] = class_id
	_atlas["tab"] = "constellation"
	_atlas["selected"] = ""
	_atlas_apply_tab_state()
	_atlas_build_canvas()
	_atlas_refresh()
	_atlas_wire_focus()




func _atlas_switch_tab(tab: String) -> void:
	if _atlas.is_empty() or str(_atlas.get("tab", "")) == tab:
		return
	_atlas["tab"] = tab
	_atlas["selected"] = ""
	_atlas_apply_tab_state()
	_atlas_build_canvas()
	_atlas_refresh()
	# The old tab's focused node/medallion may be hidden or queued for deletion.
	# Reseed only in that case; the guarded deferred helper preserves a still-live
	# header focus and deferred resize passes remain non-seeding (SCRUM-970).
	_atlas_wire_focus(true)




# LB/RB (и Tab) листают вкладки Созвездие↔Гильдия (паттерн SCRUM-813).
func _atlas_cycle_tab(_dir: int) -> bool:
	if _atlas.is_empty():
		return false
	_atlas_switch_tab("guild" if str(_atlas.get("tab", "constellation")) == "constellation" else "constellation")
	return true




func _atlas_apply_tab_state() -> void:
	var on_guild := str(_atlas.get("tab", "constellation")) == "guild"
	var tab_constellation := _atlas.get("tab_constellation") as Button
	var tab_guild := _atlas.get("tab_guild") as Button
	var strip := _atlas.get("strip") as ScrollContainer
	var emblem_badge := _atlas.get("emblem_badge") as PanelContainer
	if tab_constellation == null or tab_guild == null or not is_instance_valid(tab_constellation) or not is_instance_valid(tab_guild):
		return
	var active_tint := Color(1.0, 0.94, 0.74, 1.0)
	var idle_tint := Color(0.74, 0.76, 0.84, 0.92)
	tab_constellation.modulate = idle_tint if on_guild else active_tint
	tab_guild.modulate = active_tint if on_guild else idle_tint
	# Tab-клавиша всегда жмёт ПРОТИВОПОЛОЖНУЮ вкладку (короткая дорога «Tab — вкладки»).
	var tab_shortcut := Shortcut.new()
	var tab_event := InputEventKey.new()
	tab_event.keycode = KEY_TAB
	tab_shortcut.events = [tab_event]
	tab_constellation.shortcut = tab_shortcut if on_guild else null
	tab_guild.shortcut = null if on_guild else tab_shortcut
	if strip != null and is_instance_valid(strip):
		strip.visible = not on_guild
	if emblem_badge != null and is_instance_valid(emblem_badge):
		emblem_badge.visible = not on_guild
	var respec_button := _atlas.get("respec_button") as Button
	if respec_button != null and is_instance_valid(respec_button):
		respec_button.text = "Сброс умений Атласа" if on_guild else "Сброс умений"




func _atlas_buy_selected() -> void:
	var node_id := str(_atlas.get("selected", ""))
	if node_id == "" or _atlas.is_empty():
		return
	if not game.META_PROGRESSION.can_buy_node(game.meta_state, node_id):
		# SCRUM-968: узел недоступен (нет звёздной пыли / не открыт предок) — отказ.
		game._play_sfx("ui_error")
		return
	game.meta_state = game.META_PROGRESSION.allocate_node(game.meta_state, node_id)
	game.save_meta_progression()
	# SCRUM-968: успешная покупка узла Атласа — трата звёздной пыли.
	game._play_sfx("purchase")
	_atlas_refresh()
	_atlas_play_purchase_ceremony(node_id)




# Церемония покупки: вспышка звезды + загорание линий к соседям (§7).
func _atlas_play_purchase_ceremony(node_id: String) -> void:
	var nb := (_atlas.get("node_buttons", {}) as Dictionary).get(node_id) as TextureButton
	if nb == null or not is_instance_valid(nb):
		return
	var star := nb.get_node_or_null("Star") as TextureRect
	if star != null and star.visible:
		var star_tween := star.create_tween()
		star_tween.tween_property(star, "scale", Vector2.ONE, 0.45).from(Vector2(1.7, 1.7)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		star_tween.parallel().tween_property(star, "self_modulate", star.self_modulate, 0.45).from(Color(2.0, 1.8, 1.2, 1.0))
	var edge_layer := _atlas.get("edge_layer") as Control
	if edge_layer != null and is_instance_valid(edge_layer):
		var edge_tween := edge_layer.create_tween()
		edge_tween.tween_method(Callable(self, "_atlas_set_edge_flash").bind(node_id), 1.0, 0.0, 0.8)




func _atlas_set_edge_flash(value: float, node_id: String) -> void:
	if _atlas.is_empty():
		return
	(_atlas.get("edge_flash", {}) as Dictionary)[node_id] = value
	var edge_layer := _atlas.get("edge_layer") as Control
	if edge_layer != null and is_instance_valid(edge_layer):
		edge_layer.queue_redraw()




func _atlas_toggle_keystone() -> void:
	var node_id := str(_atlas.get("selected", ""))
	var node: Dictionary = game.META_PROGRESSION.node_by_id(node_id)
	if node.is_empty() or str(node.get("role", "")) != "keystone":
		return
	var class_id := str(node.get("class_affinity", ""))
	if class_id == "":
		return
	var active: bool = game.META_PROGRESSION.is_keystone_active(game.meta_state, node_id)
	game.meta_state = game.META_PROGRESSION.set_active_keystone(game.meta_state, class_id, "" if active else node_id)
	game.save_meta_progression()
	_atlas_refresh()




func _atlas_respec_prompt() -> void:
	var popup := _atlas.get("respec_popup") as PanelContainer
	var text := _atlas.get("respec_text") as Label
	if popup == null or text == null or not is_instance_valid(popup) or not is_instance_valid(text):
		return
	if str(_atlas.get("tab", "constellation")) == "guild":
		text.text = "Сбросить все узлы Атласа гильдии? Звёздная пыль вернётся полностью — респек бесплатный."
	else:
		var title := str(game.PROGRESSION_DATA.character_config(str(_atlas.get("class_id", ""))).get("title", ""))
		text.text = "Сбросить созвездие класса «%s»? Эмблемы вернутся полностью — респек бесплатный." % title
	popup.visible = true




func _atlas_respec_cancel() -> void:
	var popup := _atlas.get("respec_popup") as PanelContainer
	if popup != null and is_instance_valid(popup):
		popup.visible = false




func _atlas_respec_confirm() -> void:
	if _atlas.is_empty():
		return
	if str(_atlas.get("tab", "constellation")) == "guild":
		game.meta_state = game.META_PROGRESSION.reset_constellation(game.meta_state, "")
	else:
		game.meta_state = game.META_PROGRESSION.reset_constellation(game.meta_state, str(_atlas.get("class_id", "")))
	game.save_meta_progression()
	_atlas_respec_cancel()
	_atlas_refresh()




func _atlas_canvas_input(event: InputEvent) -> void:
	# Клик по небу скипает церемонию рассеивания тумана (§7).
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_atlas_skip_fog_ceremonies()




func _atlas_skip_fog_ceremonies() -> void:
	var tweens: Dictionary = _atlas.get("fog_tweens", {})
	for node_id in tweens.keys():
		var fog_tween := tweens[node_id] as Tween
		if fog_tween != null and fog_tween.is_valid():
			fog_tween.kill()
		_atlas_finish_fog(str(node_id))
	_atlas["fog_tweens"] = {}




func _atlas_finish_fog(node_id: String) -> void:
	if _atlas.is_empty():
		return
	(_atlas.get("fog_tweens", {}) as Dictionary).erase(node_id)
	var nb := (_atlas.get("node_buttons", {}) as Dictionary).get(node_id) as TextureButton
	if nb == null or not is_instance_valid(nb):
		return
	var fog := nb.get_node_or_null("Fog") as TextureRect
	if fog != null:
		fog.visible = false




# SCRUM-812/813: фокус-цепочки — лента классов вертикальной цепью, узлы по
# adj-соседям созвездия (гео-направления), шапка/низ достижимы направлениями.
func _atlas_wire_focus(seed_initial_focus := false) -> void:
	if _atlas.is_empty():
		return
	var tab_constellation := _atlas.get("tab_constellation") as Button
	var tab_guild := _atlas.get("tab_guild") as Button
	var back_button := _atlas.get("back_button") as Button
	var respec_button := _atlas.get("respec_button") as Button
	var buy_button := _atlas.get("buy_button") as Button
	var info_scroll := _atlas.get("panel_scroll") as ScrollContainer
	var on_guild := str(_atlas.get("tab", "constellation")) == "guild"
	var medallions: Array = [] if on_guild else _atlas.get("medallions", [])
	var buttons: Dictionary = _atlas.get("node_buttons", {})
	var centers: Dictionary = _atlas.get("node_centers", {})
	for control in [tab_constellation, tab_guild, back_button, respec_button, buy_button, info_scroll]:
		if control == null or not is_instance_valid(control):
			return
	# Шапка: горизонтальная цепь.
	var header_ring: Array = [tab_constellation, tab_guild, back_button]
	for i in range(header_ring.size()):
		var current := header_ring[i] as Button
		current.focus_neighbor_left = (header_ring[(i - 1 + header_ring.size()) % header_ring.size()] as Control).get_path()
		current.focus_neighbor_right = (header_ring[(i + 1) % header_ring.size()] as Control).get_path()
		current.focus_neighbor_bottom = respec_button.get_path()
	# Лента классов: вертикальная цепь, вправо — ядро созвездия.
	var core_button := buttons.get(_atlas_core_node_id()) as TextureButton
	for i in range(medallions.size()):
		var mb := medallions[i] as TextureButton
		if mb == null or not is_instance_valid(mb):
			continue
		var prev := medallions[(i - 1 + medallions.size()) % medallions.size()] as TextureButton
		var next := medallions[(i + 1) % medallions.size()] as TextureButton
		mb.focus_neighbor_top = prev.get_path()
		mb.focus_neighbor_bottom = next.get_path()
		if core_button != null and is_instance_valid(core_button):
			mb.focus_neighbor_right = core_button.get_path()
	# Узлы: гео-направления по adj (лучший сосед в каждой из 4 сторон).
	var selected_medallion: TextureButton = null
	for raw_mb in medallions:
		var mb := raw_mb as TextureButton
		if mb != null and is_instance_valid(mb) and str(mb.get_meta("class_id")) == str(_atlas.get("class_id", "")):
			selected_medallion = mb
			break
	for node_id in buttons.keys():
		var nb := buttons[node_id] as TextureButton
		if nb == null or not is_instance_valid(nb) or not centers.has(node_id):
			continue
		var node: Dictionary = game.META_PROGRESSION.node_by_id(str(node_id))
		var center: Vector2 = centers[node_id]
		var best := {"left": null, "right": null, "top": null, "bottom": null}
		var best_score := {"left": 0.35, "right": 0.35, "top": 0.35, "bottom": 0.35}
		for raw_adj in node.get("adj", []):
			var adj_id := str(raw_adj)
			if not centers.has(adj_id) or not buttons.has(adj_id):
				continue
			var offset := (centers[adj_id] as Vector2) - center
			if offset.length() < 1.0:
				continue
			var direction := offset.normalized()
			var scores := {"left": -direction.x, "right": direction.x, "top": -direction.y, "bottom": direction.y}
			for side in scores.keys():
				if float(scores[side]) > float(best_score[side]):
					best_score[side] = float(scores[side])
					best[side] = buttons[adj_id]
		var left_target := best["left"] as Control
		if left_target == null:
			left_target = selected_medallion if selected_medallion != null else tab_constellation
		var right_target := best["right"] as Control
		if right_target == null:
			right_target = buy_button if buy_button.visible and not buy_button.disabled else info_scroll
		var top_target := best["top"] as Control
		if top_target == null:
			top_target = tab_guild if on_guild else tab_constellation
		var bottom_target := best["bottom"] as Control
		if bottom_target == null:
			bottom_target = respec_button
		nb.focus_neighbor_left = left_target.get_path()
		nb.focus_neighbor_right = right_target.get_path()
		nb.focus_neighbor_top = top_target.get_path()
		nb.focus_neighbor_bottom = bottom_target.get_path()
	# Панель/низ: возврат к ядру созвездия.
	if core_button != null and is_instance_valid(core_button):
		buy_button.focus_neighbor_left = core_button.get_path()
		respec_button.focus_neighbor_top = core_button.get_path()
		info_scroll.focus_neighbor_left = core_button.get_path()
	var scroll_exit := buy_button if buy_button.visible and not buy_button.disabled else respec_button
	info_scroll.focus_neighbor_right = scroll_exit.get_path()
	info_scroll.focus_neighbor_top = back_button.get_path()
	info_scroll.focus_neighbor_bottom = scroll_exit.get_path()
	buy_button.focus_neighbor_top = info_scroll.get_path()
	var keystone_toggle := _atlas.get("keystone_toggle") as Button
	if keystone_toggle != null and is_instance_valid(keystone_toggle):
		buy_button.focus_neighbor_bottom = keystone_toggle.get_path()
		keystone_toggle.focus_neighbor_top = buy_button.get_path()
		if core_button != null and is_instance_valid(core_button):
			keystone_toggle.focus_neighbor_left = core_button.get_path()
	# Стартовый фокус нужен только при первом открытии экрана. Deferred responsive
	# layout passes may rewire neighbours, but must never steal a live pointer or
	# gamepad selection back to the class medallion/Guild hub (SCRUM-970).
	if not seed_initial_focus:
		return
	var initial: Control = selected_medallion
	if initial == null:
		initial = core_button
	if initial == null and not buttons.is_empty():
		initial = buttons.values()[0] as Control
	if initial != null and is_instance_valid(initial):
		call_deferred("_atlas_grab_initial_focus_if_outside", initial)




func _atlas_grab_initial_focus_if_outside(initial: Control) -> void:
	if _atlas.is_empty() or initial == null or not is_instance_valid(initial):
		return
	var atlas_root := _atlas.get("root") as Control
	if atlas_root == null or not is_instance_valid(atlas_root):
		return
	var viewport: Viewport = null
	if game != null:
		viewport = game.get_viewport()
	var current: Control = null
	if viewport != null:
		current = viewport.gui_get_focus_owner()
	if current != null and is_instance_valid(current) and not current.is_queued_for_deletion() \
			and current.is_visible_in_tree() and (current == atlas_root or atlas_root.is_ancestor_of(current)):
		return
	initial.grab_focus()
