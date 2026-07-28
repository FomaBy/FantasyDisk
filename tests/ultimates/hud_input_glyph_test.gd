extends SceneTree

## FAN-1458 — glyph/hot-plug тест ultimate-HUD виджета (AC3).
##
## Fixtures покрывают keyboard, gamepad и hot-plug (смену устройства повторным
## apply_state), плюс недоступный ввод: виджет рисует ульту неактивной и не
## выдаёт activation-сигнал. Глифы берутся строго из read-only реестра
## `scripts/ui/input_glyph_registry.gd`.
##
## Запуск: Godot --headless --path . \
##   --script res://tests/ultimates/hud_input_glyph_test.gd

const InputGlyphRegistry := preload("res://scripts/ui/input_glyph_registry.gd")
const State := preload("res://scripts/ui/ultimate_hud/ultimate_hud_state.gd")
const ViewModel := preload("res://scripts/ui/ultimate_hud/ultimate_hud_view_model.gd")
const FixtureLibrary := preload("res://tests/ultimates/hud_fixture_library.gd")
const WIDGET_SCENE := preload("res://scenes/ui/ultimate_hud/ultimate_hud_widget.tscn")

const CLASS_ID := "sniper"
const WEAPON_ID := "sniper_deadeye_rifle"

var _errors: Array[String] = []


func _initialize() -> void:
	var fixtures := FixtureLibrary.new()
	var widget = WIDGET_SCENE.instantiate()
	root.add_child(widget)
	await process_frame

	var glyph := widget.find_child("BindingGlyph", true, false) as TextureRect
	var key_label := widget.find_child("BindingKeyLabel", true, false) as Label
	var layout := widget.find_child("Layout", true, false) as HBoxContainer
	if glyph == null or key_label == null or layout == null:
		push_error("missing BindingGlyph/BindingKeyLabel/Layout nodes")
		quit(1)
		return

	var received: Array[String] = []
	widget.activation_requested.connect(func(profile_id: String) -> void: received.append(profile_id))

	# Клавиатура: глиф клавиатурного реестра + подпись клавиши.
	widget.apply_state(ViewModel.build(fixtures.fallback_snapshot(CLASS_ID, WEAPON_ID)))
	_expect(widget.binding_glyph_name() == "key_generic", "keyboard must use the key_generic glyph")
	_expect(_texture_path(glyph) == InputGlyphRegistry.path_for("key_generic", 32), "keyboard glyph texture must come from the glyph registry")
	_expect(key_label.visible and key_label.text == State.DEFAULT_KEY_LABEL, "keyboard binding must show the key label")
	_expect(widget.is_input_available(), "keyboard input must be available")

	# Hot-plug: подключили геймпад — глиф переключается на кнопку Y.
	widget.apply_state(ViewModel.build(fixtures.fallback_snapshot(CLASS_ID, WEAPON_ID, {
		"input": fixtures.gamepad_input(),
	})))
	_expect(widget.binding_glyph_name() == "btn_y", "gamepad must use the btn_y glyph (ultimate = JOY_BUTTON_Y)")
	_expect(_texture_path(glyph) == InputGlyphRegistry.path_for("btn_y", 32), "gamepad glyph texture must come from the glyph registry")
	_expect(not key_label.visible, "gamepad binding must hide the keyboard key label")

	# Hot-plug обратно: выдернули пад — ввод возвращается клавиатуре.
	widget.apply_state(ViewModel.build(fixtures.fallback_snapshot(CLASS_ID, WEAPON_ID)))
	_expect(widget.binding_glyph_name() == "key_generic", "unplug must switch the glyph back to keyboard")
	_expect(key_label.visible and key_label.text == State.DEFAULT_KEY_LABEL, "unplug must restore the key label")

	# Незамапленная кнопка: null-safe, глиф скрыт, падения нет.
	widget.apply_state(ViewModel.build(fixtures.fallback_snapshot(CLASS_ID, WEAPON_ID, {
		"input": {"device": State.DEVICE_GAMEPAD, "joy_button": 999},
	})))
	_expect(widget.binding_glyph_name() == "", "unmapped joy button must resolve to no glyph")
	_expect(not glyph.visible, "unmapped joy button must hide the glyph texture")

	# Недоступный ввод: неактивный рендер и никакого activation-сигнала.
	widget.apply_state(ViewModel.build(fixtures.fallback_snapshot(CLASS_ID, WEAPON_ID, {
		"input": fixtures.unavailable_input(),
		"charge": {"fraction": 1.0, "active": false},
	})))
	_expect(not widget.is_input_available(), "device=none must read as unavailable input")
	_expect(not widget.is_ultimate_ready(), "full charge without input must not be ready")
	_expect(layout.modulate.a < 1.0, "unavailable input must dim the widget")
	_expect(key_label.visible and key_label.text == "—", "unavailable input must show the inert binding placeholder")
	_expect(not widget.request_activation(), "unavailable input must reject activation")
	_expect(received.is_empty(), "unavailable input must emit no activation signal")

	# Ввод вернулся: готовность и активация снова работают.
	widget.apply_state(ViewModel.build(fixtures.fallback_snapshot(CLASS_ID, WEAPON_ID, {
		"input": fixtures.gamepad_input(),
		"charge": {"fraction": 1.0, "active": false},
	})))
	_expect(is_equal_approx(layout.modulate.a, 1.0), "restored input must restore full opacity")
	_expect(widget.request_activation(), "restored input with full charge must activate")
	_expect(received.size() == 1, "exactly one activation signal after input returns")

	widget.queue_free()
	await process_frame

	if _errors.is_empty():
		print("FAN-1458 ultimate HUD input glyph test passed.")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		print("FAN-1458 ultimate HUD input glyph test FAILED (%d errors)." % _errors.size())
		quit(1)


func _texture_path(glyph: TextureRect) -> String:
	if glyph.texture == null:
		return ""
	return glyph.texture.resource_path


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
