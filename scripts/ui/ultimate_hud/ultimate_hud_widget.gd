extends PanelContainer

## FAN-1458 — изолированный виджет ultimate-HUD с Codex-тултипом.
##
## Чисто декларативный рендер: `apply_state()` принимает нормализуемое
## состояние контракта `ultimate_hud_state.gd` и полностью перерисовывает
## виджет. Никакого чтения Input/InputMap/сцен боя изнутри — ввод, заряд и
## aim-семантику подаёт владелец состояния (fixtures до FAN-1457, живой
## адаптер — карточка FAN-1541, единственный владелец монтажа в combat HUD).
##
## Glyph-и берутся из реестра `input_glyph_registry.gd` (read-only) и
## переключаются сменой `input.device` в состоянии (hot-plug = повторный
## apply_state). Недоступный ввод (`device == "none"`) рисует ульту
## неактивной и блокирует activation-сигнал.
##
## Ready-feedback редкий: бейдж «ГОТОВО» + одноразовый пульс на переходе
## заряда в полный (consume_ready_pulse), без постоянного мигания поверх боя.

signal activation_requested(profile_id: String)

const State := preload("res://scripts/ui/ultimate_hud/ultimate_hud_state.gd")
const InputGlyphRegistry := preload("res://scripts/ui/input_glyph_registry.gd")
const SemanticTypography := preload("res://scripts/ui/semantic_typography.gd")
const GlobalTooltip := preload("res://scripts/ui/global_tooltip.gd")

const ICON_WELL_SIZE := Vector2(52.0, 52.0)
const CHARGE_BAR_MIN_SIZE := Vector2(168.0, 14.0)
const GLYPH_SIZE := 32
const TOOLTIP_MAX_WIDTH := 380.0
# Приглушение неактивного состояния (нет ввода / нерендерируемое состояние).
const INACTIVE_ALPHA := 0.55
const TITLE_COLOR := Color(0.96, 0.90, 0.68, 1.0)
const BODY_COLOR := Color(0.88, 0.92, 0.98, 1.0)
const READY_COLOR := Color(0.99, 0.86, 0.36, 1.0)
const CHARGE_BG_COLOR := Color(0.10, 0.09, 0.08, 0.92)
const CHARGE_FILL_COLOR := Color(0.78, 0.60, 0.22, 1.0)
const ACTIVE_OVERLAY_COLOR := Color(0.99, 0.90, 0.52, 0.38)

var _state := State.normalize({})
var _ready_now := false
var _ready_pulse_pending := false

var _layout: HBoxContainer = null
var _icon_well: Panel = null
var _weapon_icon: TextureRect = null
var _icon_fallback: Label = null
var _weapon_title: Label = null
var _ready_badge: Label = null
var _charge_bar: ProgressBar = null
var _active_overlay: Panel = null
var _aim_hint: Label = null
var _glyph_slot: VBoxContainer = null
var _binding_glyph: TextureRect = null
var _binding_key_label: Label = null
var _tooltip: PanelContainer = null
var _tooltip_weapon_line: Label = null
var _tooltip_title: Label = null
var _tooltip_description: Label = null
var _binding_glyph_name := ""


func _ready() -> void:
	_ensure_layout()
	_render()
	resized.connect(_apply_typography)


## Полный декларативный рендер нормализованного состояния контракта.
func apply_state(raw_state: Dictionary) -> void:
	var next_state := State.normalize(raw_state)
	var was_ready := _ready_now
	_state = next_state
	_ready_now = State.is_ready(next_state)
	if _ready_now and not was_ready:
		# Пульс одноразовый и только на переходе в готовность: редкий и
		# заметный, но не перекрывает бой постоянным миганием.
		_ready_pulse_pending = true
	elif not _ready_now:
		_ready_pulse_pending = false
	_ensure_layout()
	_render()


## Глубокая копия последнего нормализованного состояния.
func state() -> Dictionary:
	return _state.duplicate(true)


## Персистентная проекция для перехода между узлами UI: заряд сохраняется,
## overlay активной ульты принудительно сброшен (никогда не восстанавливается).
func persistent_snapshot() -> Dictionary:
	return State.persistent_snapshot(_state)


## Одноразовый ready-пульс для внешних FX; сбрасывается при чтении.
func consume_ready_pulse() -> bool:
	var pending := _ready_pulse_pending
	_ready_pulse_pending = false
	return pending


func is_input_available() -> bool:
	return State.input_available(_state)


func is_ultimate_ready() -> bool:
	return _ready_now


func aim_preview_visible() -> bool:
	return State.aim_preview_visible(_state)


func binding_glyph_name() -> String:
	return _binding_glyph_name


func charge_ratio() -> float:
	_ensure_layout()
	return float(_charge_bar.ratio)


func active_overlay_visible() -> bool:
	_ensure_layout()
	return _active_overlay.visible


## Codex-тултип выбранного оружия (скрытая панель; показ решает владелец).
func codex_tooltip() -> PanelContainer:
	_ensure_layout()
	return _tooltip


## Запрос активации от владельца ввода. Сигнал уходит только когда ульта
## готова, ввод доступен и активация ещё не идёт; иначе — молчаливый отказ.
func request_activation() -> bool:
	if not _ready_now:
		return false
	if bool((_state["charge"] as Dictionary)["active"]):
		return false
	activation_requested.emit(str((_state["selection"] as Dictionary)["profile_id"]))
	return true


func _ensure_layout() -> void:
	if _layout != null:
		return
	add_theme_stylebox_override("panel", GlobalTooltip.make_atlas_chip_panel_style())

	_layout = HBoxContainer.new()
	_layout.name = "Layout"
	_layout.add_theme_constant_override("separation", 12)
	add_child(_layout)

	_icon_well = Panel.new()
	_icon_well.name = "IconWell"
	_icon_well.custom_minimum_size = ICON_WELL_SIZE
	_icon_well.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon_well.add_theme_stylebox_override("panel", _icon_well_style())
	_layout.add_child(_icon_well)

	_weapon_icon = TextureRect.new()
	_weapon_icon.name = "WeaponIcon"
	_weapon_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_weapon_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_weapon_icon.offset_left = 4.0
	_weapon_icon.offset_top = 4.0
	_weapon_icon.offset_right = -4.0
	_weapon_icon.offset_bottom = -4.0
	_icon_well.add_child(_weapon_icon)

	_icon_fallback = Label.new()
	_icon_fallback.name = "WeaponIconFallback"
	_icon_fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon_fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_icon_fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon_fallback.add_theme_color_override("font_color", TITLE_COLOR)
	_icon_well.add_child(_icon_fallback)

	var body := VBoxContainer.new()
	body.name = "Body"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 4)
	_layout.add_child(body)

	var title_row := HBoxContainer.new()
	title_row.name = "TitleRow"
	title_row.add_theme_constant_override("separation", 10)
	body.add_child(title_row)

	_weapon_title = Label.new()
	_weapon_title.name = "WeaponTitle"
	_weapon_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_weapon_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon_title.add_theme_color_override("font_color", TITLE_COLOR)
	title_row.add_child(_weapon_title)

	_ready_badge = Label.new()
	_ready_badge.name = "ReadyBadge"
	_ready_badge.text = "ГОТОВО"
	_ready_badge.add_theme_color_override("font_color", READY_COLOR)
	title_row.add_child(_ready_badge)

	var charge_holder := Control.new()
	charge_holder.name = "ChargeHolder"
	charge_holder.custom_minimum_size = CHARGE_BAR_MIN_SIZE
	body.add_child(charge_holder)

	_charge_bar = ProgressBar.new()
	_charge_bar.name = "ChargeBar"
	_charge_bar.min_value = 0.0
	_charge_bar.max_value = 1.0
	_charge_bar.show_percentage = false
	_charge_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_charge_bar.add_theme_stylebox_override("background", _charge_style(CHARGE_BG_COLOR))
	_charge_bar.add_theme_stylebox_override("fill", _charge_style(CHARGE_FILL_COLOR))
	charge_holder.add_child(_charge_bar)

	_active_overlay = Panel.new()
	_active_overlay.name = "ActiveOverlay"
	_active_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_active_overlay.add_theme_stylebox_override("panel", _charge_style(ACTIVE_OVERLAY_COLOR))
	charge_holder.add_child(_active_overlay)

	_aim_hint = Label.new()
	_aim_hint.name = "AimHint"
	_aim_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_aim_hint.add_theme_color_override("font_color", BODY_COLOR)
	body.add_child(_aim_hint)

	_glyph_slot = VBoxContainer.new()
	_glyph_slot.name = "GlyphSlot"
	_glyph_slot.alignment = BoxContainer.ALIGNMENT_CENTER
	_glyph_slot.add_theme_constant_override("separation", 2)
	_layout.add_child(_glyph_slot)

	_binding_glyph = TextureRect.new()
	_binding_glyph.name = "BindingGlyph"
	_binding_glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_binding_glyph.custom_minimum_size = Vector2(GLYPH_SIZE, GLYPH_SIZE)
	_binding_glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_glyph_slot.add_child(_binding_glyph)

	_binding_key_label = Label.new()
	_binding_key_label.name = "BindingKeyLabel"
	_binding_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_binding_key_label.add_theme_color_override("font_color", BODY_COLOR)
	_glyph_slot.add_child(_binding_key_label)

	_tooltip = PanelContainer.new()
	_tooltip.name = "CodexTooltip"
	_tooltip.visible = false
	# top_level выводит тултип из раскладки PanelContainer: показанная панель
	# позиционируется владельцем и не перекрывает основной ряд виджета.
	_tooltip.top_level = true
	_tooltip.add_theme_stylebox_override("panel", GlobalTooltip.make_atlas_chip_panel_style())
	add_child(_tooltip)

	var tooltip_body := VBoxContainer.new()
	tooltip_body.name = "CodexTooltipBody"
	tooltip_body.add_theme_constant_override("separation", 4)
	_tooltip.add_child(tooltip_body)

	_tooltip_weapon_line = Label.new()
	_tooltip_weapon_line.name = "TooltipWeaponLine"
	_tooltip_weapon_line.add_theme_color_override("font_color", BODY_COLOR)
	tooltip_body.add_child(_tooltip_weapon_line)

	_tooltip_title = Label.new()
	_tooltip_title.name = "TooltipUltimateTitle"
	_tooltip_title.add_theme_color_override("font_color", TITLE_COLOR)
	tooltip_body.add_child(_tooltip_title)

	_tooltip_description = Label.new()
	_tooltip_description.name = "TooltipUltimateDescription"
	_tooltip_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_description.custom_minimum_size = Vector2(TOOLTIP_MAX_WIDTH, 0.0)
	_tooltip_description.add_theme_color_override("font_color", BODY_COLOR)
	tooltip_body.add_child(_tooltip_description)

	_apply_typography()


func _render() -> void:
	var selection := _state["selection"] as Dictionary
	var ultimate := _state["ultimate"] as Dictionary
	var charge := _state["charge"] as Dictionary
	var renderable := State.is_renderable(_state)
	var available := State.input_available(_state)

	var weapon_title := str(selection["weapon_title"])
	_weapon_title.text = weapon_title if renderable else "—"
	_render_weapon_icon(str(selection["weapon_icon_path"]), weapon_title, renderable)

	_charge_bar.ratio = float(charge["fraction"]) if renderable else 0.0
	# Overlay активной ульты — строго runtime-сигнал текущего состояния;
	# persistent_snapshot() его стирает, поэтому восстановление невозможно.
	_active_overlay.visible = renderable and bool(charge["active"])
	_ready_badge.visible = _ready_now

	_render_binding_glyph(available)
	_render_aim_hint(renderable)
	_render_tooltip(renderable, weapon_title, ultimate)

	# Недоступный ввод и нерендерируемое состояние приглушают весь виджет.
	var alpha := 1.0 if renderable and available else INACTIVE_ALPHA
	_layout.modulate = Color(1.0, 1.0, 1.0, alpha)


func _render_weapon_icon(icon_path: String, weapon_title: String, renderable: bool) -> void:
	var texture: Texture2D = null
	# Null-safe и headless-safe: отсутствующий ресурс — это фолбэк-буква,
	# а не ошибка.
	if renderable and not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		texture = load(icon_path) as Texture2D
	_weapon_icon.texture = texture
	_weapon_icon.visible = texture != null
	_icon_fallback.visible = texture == null
	_icon_fallback.text = weapon_title.left(1).to_upper() if renderable and not weapon_title.is_empty() else "?"


func _render_binding_glyph(available: bool) -> void:
	var input := _state["input"] as Dictionary
	var device := str(input["device"])
	var texture: Texture2D = null
	_binding_glyph_name = ""
	var key_text := ""
	if device == State.DEVICE_GAMEPAD:
		var joy_button := int(input["joy_button"])
		_binding_glyph_name = str(InputGlyphRegistry.JOY_BUTTON_TO_GLYPH.get(joy_button, ""))
		texture = InputGlyphRegistry.texture_for_joy_button(joy_button, GLYPH_SIZE)
	elif device == State.DEVICE_KEYBOARD:
		var key_glyph := str(input["key_glyph"])
		_binding_glyph_name = str(InputGlyphRegistry.KEY_TO_GLYPH.get(key_glyph, ""))
		texture = InputGlyphRegistry.texture_for_key(key_glyph, GLYPH_SIZE)
		key_text = str(input["key_label"])
	_binding_glyph.texture = texture
	_binding_glyph.visible = texture != null
	if available:
		_binding_key_label.text = key_text
		_binding_key_label.visible = not key_text.is_empty()
	else:
		_binding_key_label.text = "—"
		_binding_key_label.visible = true


func _render_aim_hint(renderable: bool) -> void:
	var aim := _state["aim"] as Dictionary
	var manual := str(aim["mode"]) == State.AIM_MODE_MANUAL
	var aiming := renderable and manual and bool(aim["aiming"])
	_aim_hint.visible = aiming
	if not aiming:
		_aim_hint.text = ""
		return
	# Каноническая семантика AimController: превью-прицел — у правого стика,
	# мышь ведёт собственный курсор.
	if State.aim_preview_visible(_state):
		_aim_hint.text = "Прицел: правый стик"
	else:
		_aim_hint.text = "Прицел: курсор мыши"


func _render_tooltip(renderable: bool, weapon_title: String, ultimate: Dictionary) -> void:
	var ultimate_title := str(ultimate["title"])
	var description := str(ultimate["description"])
	_tooltip_weapon_line.text = weapon_title if renderable else ""
	_tooltip_title.text = ultimate_title
	_tooltip_description.text = description
	_tooltip_description.visible = not description.is_empty()
	tooltip_text = "%s\n%s" % [ultimate_title, description] if renderable and not ultimate_title.is_empty() else ""


func _apply_typography() -> void:
	if _layout == null:
		return
	var viewport_height := 648.0
	if is_inside_tree():
		var viewport_size := get_viewport_rect().size
		if viewport_size.y > 0.0:
			viewport_height = viewport_size.y
	var hud_px := SemanticTypography.resolve(SemanticTypography.ROLE_HUD, viewport_height)
	var caption_px := SemanticTypography.resolve(SemanticTypography.ROLE_CAPTION, viewport_height)
	var tooltip_px := SemanticTypography.resolve(SemanticTypography.ROLE_TOOLTIP, viewport_height)
	_weapon_title.add_theme_font_size_override("font_size", hud_px)
	_icon_fallback.add_theme_font_size_override("font_size", hud_px)
	_ready_badge.add_theme_font_size_override("font_size", caption_px)
	_aim_hint.add_theme_font_size_override("font_size", caption_px)
	_binding_key_label.add_theme_font_size_override("font_size", caption_px)
	_tooltip_weapon_line.add_theme_font_size_override("font_size", caption_px)
	_tooltip_title.add_theme_font_size_override("font_size", tooltip_px)
	_tooltip_description.add_theme_font_size_override("font_size", tooltip_px)


func _icon_well_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.045, 0.95)
	style.border_color = Color(0.52, 0.41, 0.24, 0.90)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style


func _charge_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(5)
	return style
