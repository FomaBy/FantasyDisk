extends PanelContainer

const CURSOR_GAP := 18.0
const VIEWPORT_MARGIN := 16.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	call_deferred("_place_from_cursor")
	if get_tree() != null:
		get_tree().process_frame.connect(_place_from_cursor, CONNECT_ONE_SHOT)


func _place_from_cursor() -> void:
	if not is_inside_tree():
		return
	var desired_size := get_combined_minimum_size()
	size = Vector2(maxf(size.x, desired_size.x), maxf(size.y, desired_size.y))
	GlobalTooltip.place_near_anchor(
		self,
		GlobalTooltip.cursor_anchor_rect(self),
		get_viewport_rect().size,
		CURSOR_GAP,
		VIEWPORT_MARGIN
	)
