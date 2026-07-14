class_name PauseDossierActionLayout
extends RefCounted


static func build(viewport_size: Vector2, safe_rect: Rect2, compact_reserve: float, large_reserve: float) -> Dictionary:
	var compact := viewport_size.y <= 900.0
	var large := viewport_size.y >= 1200.0
	var inner_rect := safe_rect.grow(-(large_reserve if large else compact_reserve))
	var header_height := (48.0 if viewport_size.y >= 900.0 else 46.0) if compact else (104.0 if large else 72.0)
	var header_gap := 4.0 if compact else (24.0 if large else 12.0)
	var footer_bottom := 4.0 if compact else (16.0 if large else 12.0)
	var hero_width := 348.0 if compact else (520.0 if large else 420.0)
	var column_gap := 12.0 if compact else (24.0 if large else 20.0)
	var body_top := inner_rect.position.y + header_height + header_gap
	var action_height := 60.0 if viewport_size.y <= 648.0 else (72.0 if compact else (104.0 if large else 88.0))
	var action_width := 219.0 if viewport_size.y <= 648.0 else (263.0 if compact else (380.0 if large else 320.0))
	var action_gap := (6.0 if viewport_size.y <= 648.0 else (10.0 if viewport_size.y >= 900.0 else 8.0)) if compact else (20.0 if large else 16.0)
	var action_rect: Rect2
	var body_rect: Rect2
	if compact:
		var body_height := maxf(1.0, inner_rect.end.y - footer_bottom - body_top)
		var action_total_height := action_height * 4.0 + action_gap * 3.0
		action_rect = Rect2(
			Vector2(inner_rect.end.x - action_width, body_top + maxf(0.0, (body_height - action_total_height) * 0.5)),
			Vector2(action_width, action_total_height)
		)
		body_rect = Rect2(
			Vector2(inner_rect.position.x, body_top),
			Vector2(maxf(1.0, inner_rect.size.x - column_gap - action_width), body_height)
		)
	else:
		var footer_gap := 24.0 if large else 12.0
		var action_total_width := action_width * 4.0 + action_gap * 3.0
		action_rect = Rect2(
			Vector2(inner_rect.get_center().x - action_total_width * 0.5, inner_rect.end.y - footer_bottom - action_height),
			Vector2(action_total_width, action_height)
		)
		body_rect = Rect2(
			Vector2(inner_rect.position.x, body_top),
			Vector2(inner_rect.size.x, maxf(1.0, action_rect.position.y - footer_gap - body_top))
		)
	return {
		"safe_rect": safe_rect,
		"inner_rect": inner_rect,
		"header_rect": Rect2(inner_rect.position, Vector2(inner_rect.size.x, header_height)),
		"body_rect": body_rect,
		"hero_width": hero_width,
		"column_gap": column_gap,
		"action_rect": action_rect,
		"action_size": Vector2(action_width, action_height),
		"action_gap": action_gap,
		"actions_vertical": compact,
	}
