extends SceneTree

## FAN-1458 — responsive/headless тест изолированной ultimate-HUD сцены
## (AC4, AC5).
##
## Изолированная сцена проходит fit/no-overlap и content-zone правила на
## 648p / 720p / 1080p / 2K со стресс-контентом (самое длинное название оружия
## и описание ульты из настоящего реестра). Headless-путь детерминированный:
## повторный рендер того же состояния даёт идентичную раскладку.
##
## Запуск: Godot --headless --path . \
##   --script res://tests/ultimates/hud_layout_responsive_test.gd

const State := preload("res://scripts/ui/ultimate_hud/ultimate_hud_state.gd")
const ViewModel := preload("res://scripts/ui/ultimate_hud/ultimate_hud_view_model.gd")
const FixtureLibrary := preload("res://tests/ultimates/hud_fixture_library.gd")
const WIDGET_SCENE := preload("res://scenes/ui/ultimate_hud/ultimate_hud_widget.tscn")

const VIEWPORT_SIZES := [
	Vector2i(1152, 648),
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const SCREEN_MARGIN := 16.0
# Видимые контент-блоки основного ряда: попарно не пересекаются.
const CONTENT_NODES := [
	"IconWell", "WeaponTitle", "ReadyBadge", "ChargeHolder", "AimHint",
	"BindingGlyph", "BindingKeyLabel",
]

var _errors: Array[String] = []


func _initialize() -> void:
	var fixtures := FixtureLibrary.new()
	var stress_pair: Dictionary = fixtures.longest_content_pair()
	var stress_state: Dictionary = ViewModel.build(fixtures.fallback_snapshot(
		str(stress_pair["class_id"]),
		str(stress_pair["weapon_id"]),
		{
			"charge": {"fraction": 1.0, "active": true},
			"input": fixtures.gamepad_input(),
			"aim": {"mode": State.AIM_MODE_MANUAL, "aiming": true},
		}
	))

	for viewport_size in VIEWPORT_SIZES:
		await _check_viewport(viewport_size as Vector2i, stress_state)

	if _errors.is_empty():
		print("FAN-1458 ultimate HUD responsive layout test passed.")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		print("FAN-1458 ultimate HUD responsive layout test FAILED (%d errors)." % _errors.size())
		quit(1)


func _check_viewport(viewport_size: Vector2i, stress_state: Dictionary) -> void:
	var context := str(viewport_size)
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	root.add_child(viewport)
	await process_frame

	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(host)

	var widget = WIDGET_SCENE.instantiate()
	host.add_child(widget)
	widget.apply_state(stress_state)
	await _settle()

	# Свободно стоящий чип принимает свой минимальный размер и прижимается
	# к нижнему левому углу с полем — как HUD-чип.
	widget.reset_size()
	widget.position = Vector2(
		SCREEN_MARGIN,
		float(viewport_size.y) - widget.size.y - SCREEN_MARGIN
	)
	await _settle()

	var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
	var widget_rect: Rect2 = widget.get_global_rect()
	_expect(
		viewport_rect.encloses(widget_rect),
		"%s: widget must fit the viewport, got %s" % [context, widget_rect]
	)

	# Content-zone: основной ряд остаётся внутри пустой контент-зоны рамки
	# (кант + авторские content margins стиля панели).
	var style := widget.get_theme_stylebox("panel") as StyleBoxFlat
	var layout := widget.find_child("Layout", true, false) as HBoxContainer
	if style == null or layout == null:
		_expect(false, "%s: missing panel style or Layout" % context)
	else:
		var content_zone := Rect2(
			widget_rect.position + Vector2(style.content_margin_left, style.content_margin_top),
			widget_rect.size - Vector2(
				style.content_margin_left + style.content_margin_right,
				style.content_margin_top + style.content_margin_bottom
			)
		).grow(1.0)
		_expect(
			content_zone.encloses(layout.get_global_rect()),
			"%s: layout must stay inside the frame content zone" % context
		)

	# Fit/no-overlap: видимые контент-блоки попарно не пересекаются.
	var rects: Array = []
	for node_name in CONTENT_NODES:
		var node := widget.find_child(str(node_name), true, false) as Control
		if node == null:
			_expect(false, "%s: missing content node %s" % [context, node_name])
			continue
		if not node.visible:
			continue
		rects.append({"name": str(node_name), "rect": node.get_global_rect()})
		_expect(
			widget_rect.grow(1.0).encloses(node.get_global_rect()),
			"%s: %s must stay inside the widget" % [context, node_name]
		)
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			var left: Dictionary = rects[i]
			var right: Dictionary = rects[j]
			var overlap := (left["rect"] as Rect2).grow(-1.0).intersects(right["rect"] as Rect2)
			_expect(
				not overlap,
				"%s: %s must not overlap %s" % [context, left["name"], right["name"]]
			)

	# Стресс-состояние показывает все элементы ряда.
	for node_name in ["ReadyBadge", "AimHint", "BindingGlyph"]:
		var node := widget.find_child(str(node_name), true, false) as Control
		_expect(node != null and node.visible, "%s: stress state must show %s" % [context, node_name])
	_expect(is_equal_approx(widget.charge_ratio(), 1.0), "%s: charge ratio must survive resize" % context)

	# Codex-тултип: показанная панель тоже помещается в кадр.
	var tooltip := widget.codex_tooltip() as PanelContainer
	tooltip.visible = true
	tooltip.reset_size()
	tooltip.position = Vector2(SCREEN_MARGIN, SCREEN_MARGIN)
	await _settle()
	_expect(
		viewport_rect.encloses(tooltip.get_global_rect()),
		"%s: codex tooltip must fit the viewport, got %s" % [context, tooltip.get_global_rect()]
	)

	# Headless-детерминизм: повторный рендер того же состояния не двигает
	# ни один контент-блок.
	var before := _layout_fingerprint(widget)
	widget.apply_state(stress_state)
	await _settle()
	_expect(
		_layout_fingerprint(widget) == before,
		"%s: re-applying the same state must keep the layout identical" % context
	)

	viewport.queue_free()
	await process_frame


func _layout_fingerprint(widget: Control) -> String:
	var parts := PackedStringArray()
	for node_name in CONTENT_NODES:
		var node := widget.find_child(str(node_name), true, false) as Control
		if node == null or not node.visible:
			continue
		parts.append("%s:%s" % [node_name, node.get_global_rect()])
	return ";".join(parts)


func _settle() -> void:
	for _frame in range(4):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
