extends Control
## Runtime copy is kept in labels; generated art is never used as text content.

signal decision_made(decision: String, reason: String)

const BASE_SIZE := Vector2(1920.0, 1080.0)

var _remaining := 12.0
var _settled := false

@onready var _modal: Control = get_node_or_null("ModalFrame") as Control
@onready var _title: Label = get_node_or_null("Title") as Label
@onready var _subtitle: Label = get_node_or_null("Subtitle") as Label
@onready var _risk_value: Label = get_node_or_null("RiskValue") as Label
@onready var _risk_body: Label = get_node_or_null("RiskBody") as Label
@onready var _reward_value: Label = get_node_or_null("RewardValue") as Label
@onready var _reward_cap: Label = get_node_or_null("RewardCap") as Label
@onready var _reward_body: Label = get_node_or_null("RewardBody") as Label
@onready var _timeout_hint: Label = get_node_or_null("TimeoutHint") as Label
@onready var _accept: Button = get_node_or_null("AcceptButton") as Button
@onready var _decline: Button = get_node_or_null("DeclineButton") as Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _accept != null and not _accept.pressed.is_connected(_accept_contract):
		_accept.pressed.connect(_accept_contract)
	if _decline != null and not _decline.pressed.is_connected(_decline_contract):
		_decline.pressed.connect(_decline_contract)
	_layout_for_viewport(_viewport_size())
	call_deferred("_focus_safe_default")


func present(payload: Dictionary) -> void:
	_remaining = clampf(float(payload.get("timeout_seconds", 12.0)), 1.0, 30.0)
	if _title != null:
		_title.text = "Контракт следующей фазы"
	if _subtitle != null:
		_subtitle.text = "Условие действует только на эту нормальную фазу."
	if _risk_value != null:
		_risk_value.text = "+%d%% к угрозе" % int(payload.get("risk_percent", 0))
	if _risk_body != null:
		_risk_body.text = "%d усиленных врага. Отступить можно без штрафа." % int(payload.get("risk_enemies", 0))
	if _reward_value != null:
		_reward_value.text = "+%d XP · +%d золота" % [int(payload.get("reward_xp", 0)), int(payload.get("reward_gold", 0))]
	if _reward_cap != null:
		_reward_cap.text = "Лимит награды" if bool(payload.get("reward_capped", false)) else "Награда растёт с глубиной"
	if _reward_body != null:
		_reward_body.text = "Выдаётся один раз только после завершения риска."
	if _accept != null:
		_accept.disabled = false
	if _decline != null:
		_decline.disabled = false
	_update_timeout_hint()


func _process(delta: float) -> void:
	if _settled:
		return
	_remaining = maxf(0.0, _remaining - delta)
	_update_timeout_hint()
	if _remaining <= 0.0:
		_settle("declined", "timeout")


func _unhandled_key_input(event: InputEvent) -> void:
	if _settled:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_settle("declined", "cancelled")
	elif event.is_action_pressed("ui_left"):
		_focus(_accept)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_focus(_decline)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_for_viewport(_viewport_size())


func _accept_contract() -> void:
	_settle("accepted", "accepted")


func _decline_contract() -> void:
	_settle("declined", "declined")


func _settle(decision: String, reason: String) -> void:
	if _settled:
		return
	_settled = true
	if _accept != null:
		_accept.disabled = true
	if _decline != null:
		_decline.disabled = true
	decision_made.emit(decision, reason)
	queue_free()


func _focus_safe_default() -> void:
	_focus(_decline)


func _focus(button: Button) -> void:
	if button != null and not button.disabled:
		button.grab_focus()


func _update_timeout_hint() -> void:
	if _timeout_hint != null:
		_timeout_hint.text = "Автоотказ через %d сек. — без штрафа" % int(ceil(_remaining))


func _viewport_size() -> Vector2:
	var viewport := get_viewport()
	var size := viewport.get_visible_rect().size if viewport != null else Vector2.ZERO
	return size if size.x > 0.0 and size.y > 0.0 else BASE_SIZE


func _layout_for_viewport(viewport_size: Vector2) -> void:
	var layout := layout_for(viewport_size)
	_place(_modal, layout.get("modal", Rect2()))
	_place(get_node_or_null("Title") as Control, layout.get("title", Rect2()))
	_place(get_node_or_null("Subtitle") as Control, layout.get("subtitle", Rect2()))
	_place(get_node_or_null("InputHint") as Control, layout.get("input_hint", Rect2()))
	_place(get_node_or_null("RiskIcon") as Control, layout.get("risk_icon", Rect2()))
	_place(get_node_or_null("RewardIcon") as Control, layout.get("reward_icon", Rect2()))
	_place(get_node_or_null("RiskLabel") as Control, layout.get("risk_label", Rect2()))
	_place(get_node_or_null("RiskValue") as Control, layout.get("risk_value", Rect2()))
	_place(get_node_or_null("RiskBody") as Control, layout.get("risk_body", Rect2()))
	_place(get_node_or_null("RewardLabel") as Control, layout.get("reward_label", Rect2()))
	_place(get_node_or_null("RewardValue") as Control, layout.get("reward_value", Rect2()))
	_place(get_node_or_null("RewardCap") as Control, layout.get("reward_cap", Rect2()))
	_place(get_node_or_null("RewardBody") as Control, layout.get("reward_body", Rect2()))
	_place(get_node_or_null("TimeoutHint") as Control, layout.get("timeout", Rect2()))
	_place(_accept, layout.get("accept", Rect2()))
	_place(_decline, layout.get("decline", Rect2()))


func _place(node: Control, rect: Rect2) -> void:
	if node == null:
		return
	node.position = rect.position
	node.size = rect.size


static func layout_for(viewport_size: Vector2) -> Dictionary:
	var scale := minf(viewport_size.x / BASE_SIZE.x, viewport_size.y / BASE_SIZE.y)
	scale = maxf(scale, 0.1)
	var offset := (viewport_size - BASE_SIZE * scale) * 0.5
	var rect := func(x: float, y: float, width: float, height: float) -> Rect2:
		return Rect2(offset + Vector2(x, y) * scale, Vector2(width, height) * scale)
	return {
		"modal": rect.call(280, 160, 1360, 760),
		"top_hud": rect.call(0, 0, 1920, 112),
		"fab": rect.call(1827, 987, 93, 93),
		"title": rect.call(700, 180, 520, 52),
		"subtitle": rect.call(748, 312, 424, 34),
		"input_hint": rect.call(760, 254, 400, 26),
		"risk_icon": rect.call(518, 314, 92, 92),
		"reward_icon": rect.call(1256, 314, 92, 92),
		"risk_label": rect.call(742, 350, 204, 28),
		"risk_value": rect.call(742, 383, 204, 62),
		"risk_body": rect.call(742, 449, 204, 96),
		"reward_label": rect.call(978, 350, 202, 28),
		"reward_value": rect.call(978, 383, 202, 42),
		"reward_cap": rect.call(978, 429, 202, 28),
		"reward_body": rect.call(978, 462, 202, 82),
		"timeout": rect.call(744, 715, 430, 48),
		"accept": rect.call(672, 838, 258, 56),
		"decline": rect.call(990, 838, 258, 56),
	}


func debug_accept() -> void:
	_accept_contract()


func debug_decline() -> void:
	_decline_contract()


func debug_remaining() -> float:
	return _remaining
