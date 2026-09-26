extends "res://scripts/ui/screens/codex_entries.gd"

# FAN-3824: модуль распределённого UI-класса — экран настроек: показ, видео-настройки, возврат.
# Часть линейной extends-цепочки scripts/ui/screens/** (сборка — фасад
# scripts/ui_screens.gd). Код перенесён из ui_screens.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в ui_screens_shared_api.gd.





func _apply_control_rect(control: Control, rect: Rect2) -> void:
	if control == null or not is_instance_valid(control):
		return
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.position.x + rect.size.x
	control.offset_bottom = rect.position.y + rect.size.y




func _settings_v6_font(role: StringName, design_px: float, s: float) -> int:
	# Кегль скейлится вместе с сеткой (s), пол 12px. На 1080p (s=0.75)
	# label 26 → 19.5px, статус 22 → 16.5px — читаемо по дизайн-инварианту.
	return SemanticTypography.resolve_scaled_compat(
		role, design_px, s, 12, 96
	)




func _settings_v6_icon(path: String, design_size: Vector2, s: float) -> Texture2D:
	# Иконки тем (чекбоксы, граббер, стрелка, иконки табов) рендерятся Godot в
	# НАТИВНОМ размере текстуры — заранее ресайзим под текущий масштаб сетки.
	var target := Vector2i(maxi(1, int(roundf(design_size.x * s))), maxi(1, int(roundf(design_size.y * s))))
	var key := "%s@%dx%d" % [path, target.x, target.y]
	if _settings_v6_icon_cache.has(key):
		return _settings_v6_icon_cache[key]
	var texture: Texture2D = game._cached_texture(path)
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null:
		return texture
	image = image.duplicate()
	image.resize(target.x, target.y, Image.INTERPOLATE_LANCZOS)
	var scaled := ImageTexture.create_from_image(image)
	_settings_v6_icon_cache[key] = scaled
	return scaled




func _settings_v6_texture_box(path: String, source_margins: Vector4, content: Vector4) -> StyleBox:
	# margins — в px источника (углы рисуются 1:1, середина тянется);
	# content — в экранных px (уже ×s у вызывающего).
	return _global_texture_style(path, source_margins, Color.WHITE, content)




func _settings_resolution_entries(usable_logical: Vector2i) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for resolution in game.RESOLUTION_OPTIONS:
		entries.append({
			"resolution": resolution,
			"label": "%dx%d" % [resolution.x, resolution.y],
		})
	return entries




func _current_video_settings() -> Dictionary:
	return {
		"screen_index": int(game.selected_screen_index),
		"resolution_index": int(game.selected_resolution_index),
		"window_mode_index": int(game.selected_window_mode_index),
	}




func _ensure_settings_video_pending() -> void:
	if settings_video_pending.is_empty():
		settings_video_pending = _current_video_settings()




func _settings_video_dirty() -> bool:
	_ensure_settings_video_pending()
	var current := _current_video_settings()
	for key in ["screen_index", "resolution_index", "window_mode_index"]:
		if int(settings_video_pending.get(key, current[key])) != int(current[key]):
			return true
	return false




func _settings_monitor_model(screen_sizes: Array[Vector2i]) -> Dictionary:
	_ensure_settings_video_pending()
	return DisplayResolution.monitor_options(
		screen_sizes,
		int(settings_video_pending.get("screen_index", game.selected_screen_index))
	)




func _current_monitor_sizes() -> Array[Vector2i]:
	var screen_sizes: Array[Vector2i] = []
	for screen_index in range(maxi(DisplayServer.get_screen_count(), 0)):
		screen_sizes.append(DisplayServer.screen_get_size(screen_index))
	return screen_sizes




func _clamp_pending_resolution_for_screen(screen_index: int) -> void:
	_ensure_settings_video_pending()
	var resolution_index := clampi(int(settings_video_pending.get("resolution_index", game.selected_resolution_index)), 0, game.RESOLUTION_OPTIONS.size() - 1)
	if DisplayServer.get_name() == "headless":
		settings_video_pending["resolution_index"] = resolution_index
		return
	var screen_full := DisplayServer.screen_get_size(screen_index)
	var screen_scale := DisplayServer.screen_get_scale(screen_index)
	var resolution: Vector2i = game.RESOLUTION_OPTIONS[resolution_index]
	if not DisplayResolution.resolution_fits(resolution, screen_full, screen_scale):
		resolution_index = DisplayResolution.default_resolution_index(screen_full, screen_scale)
	settings_video_pending["resolution_index"] = clampi(resolution_index, 0, game.RESOLUTION_OPTIONS.size() - 1)




func _apply_pending_video_settings() -> void:
	_ensure_settings_video_pending()
	game.selected_screen_index = int(settings_video_pending.get("screen_index", game.selected_screen_index))
	game.selected_resolution_index = int(settings_video_pending.get("resolution_index", game.selected_resolution_index))
	game.selected_window_mode_index = int(settings_video_pending.get("window_mode_index", game.selected_window_mode_index))
	_apply_video_settings()
	settings_video_pending = _current_video_settings()
	_show_settings_menu(settings_return_origin)




func _revert_pending_video_settings() -> void:
	settings_video_pending = _current_video_settings()
	_show_settings_menu(settings_return_origin)




func _show_settings_menu(requested_return_origin := "") -> void:
	settings_return_origin = _resolve_settings_return_origin(str(requested_return_origin))
	_ensure_settings_video_pending()
	game._clear_ui()

	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "SettingsV2Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.ui_layer.add_child(root)
	_prepare_global_tooltips(root)
	# SCRUM-879: фон — единый атлас-стиль (bg_sanctum, COVERED без растяжки осей)
	# с лёгким шейдом 0.30: поверх фона лежит модалка, сильное затемнение не нужно.
	_unified_add_background(root, "settings", 0.30)

	# SCRUM-879 (итерация 2): полноэкранный атлас-шелл вместо v6-модалки — слои
	# как у «Атласа героев» (_show_atlas_screen): фон → safe-зона рамы → VBox
	# (шапка / свитчер табов / контент / футер) → полая рама ПОВЕРХ
	# (_unified_add_frame последним). Строки контента (поля/бинды/чекбоксы/
	# слайдеры v6) сохранены — их масштаб s считается ниже.
	var s_ui := _atlas_ui_scale()
	# SCRUM-882 (фидбек): строки настроек — колонка ФИКСИРОВАННОЙ ширины по
	# центру контент-панели, элементы внутри колонки выровнены влево.
	# Детерминированно от вьюпорта ДО построения строк: ширина контент-зоны
	# safe-области (минус запас на поля чипа) задаёт column_w, а масштаб строк s
	# считается уже от column_w к самой широкой строке дизайна (~1276: volume-ряд
	# label 380 + слайдер 420 + чип 96 + toggle с зазорами + запас) — ряды
	# гарантированно уже колонки, переполнений нет; клампы держат строки
	# читаемыми на 648p и не дают распухнуть на 4K.
	var vp: Vector2 = game.get_viewport().get_visible_rect().size
	var safe_m := _unified_safe_margins()
	var content_w := vp.x - safe_m.x - safe_m.z - roundf(44.0 * s_ui) * 2.0
	var s_fit := clampf(content_w / SETTINGS_V6_DESIGN_SIZE.x, 0.55, 1.05)
	var settings_column_w := clampf(roundf(920.0 * s_fit), 560.0, 980.0)
	var s := clampf(settings_column_w / 1276.0, 0.55, 1.05)

	var safe := _unified_make_safe_area(root, "Settings")
	var layout := VBoxContainer.new()
	layout.name = "SettingsLayout"
	layout.add_theme_constant_override("separation", int(12.0 * s_ui))
	safe.add_child(layout)

	var settings_back := func() -> void:
		_return_from_settings()

	# --- Ряд 1: шапка — чип-титул (v6-медальон внутри) + спейсер + «Назад» ---
	var header := HBoxContainer.new()
	header.name = "SettingsHeader"
	header.add_theme_constant_override("separation", int(12.0 * s_ui))
	layout.add_child(header)
	var title_chip := _unified_header_chip("Settings", "Настройки", "settings", s_ui)
	header.add_child(title_chip)
	# Эмблемы кита для "settings" в ATLAS_STYLE_EMBLEM_PATHS нет (чип текстовый) —
	# вставляем v6-медальон первым в ряд чипа: арт 180×72, аспект 2.5:1 сохранён
	# (85×34×s_ui, KEEP_ASPECT_CENTERED — без растяжки, Правило 1).
	var chip_row := title_chip.get_child(0) as HBoxContainer
	var medallion_texture: Texture2D = game._cached_texture(SETTINGS_V6_MEDALLION_PATH)
	if chip_row != null and medallion_texture != null:
		var medallion := TextureRect.new()
		medallion.name = "SettingsV6Emblem"
		medallion.texture = medallion_texture
		medallion.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		medallion.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		medallion.custom_minimum_size = Vector2(roundf(85.0 * s_ui), roundf(34.0 * s_ui))
		medallion.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		medallion.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip_row.add_child(medallion)
		chip_row.move_child(medallion, 0)
	var header_spacer := Control.new()
	header_spacer.name = "SettingsHeaderSpacer"
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	# «Назад» — в шапке; единый возврат (фидбек 2026-07-08): та же плита 260×h,
	# что на всех экранах (маппинг имени переведён на back_260x104).
	var back_button := _settings_v6_make_action_button("Назад", "SettingsBackButton", 260.0, _atlas_action_button_height())
	back_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back_button.pressed.connect(settings_back)
	header.add_child(back_button)
	_settings_fit_kit_row([back_button], 280.0, 64.0)
	game.ui_escape_action = settings_back

	var tabs := TabContainer.new()
	tabs.name = "SettingsTabs"
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.tabs_visible = false
	# Hidden TabContainer headers do not disable the engine theme's own panel
	# fill. Preserve its layout margins while making that second surface fully
	# transparent, otherwise it remains visible beneath the outer content owner.
	var inherited_tabs_panel := tabs.get_theme_stylebox("panel")
	var seamless_tabs_panel := StyleBoxFlat.new()
	seamless_tabs_panel.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	seamless_tabs_panel.set_border_width_all(0)
	if inherited_tabs_panel != null:
		seamless_tabs_panel.content_margin_left = inherited_tabs_panel.get_content_margin(SIDE_LEFT)
		seamless_tabs_panel.content_margin_top = inherited_tabs_panel.get_content_margin(SIDE_TOP)
		seamless_tabs_panel.content_margin_right = inherited_tabs_panel.get_content_margin(SIDE_RIGHT)
		seamless_tabs_panel.content_margin_bottom = inherited_tabs_panel.get_content_margin(SIDE_BOTTOM)
	tabs.add_theme_stylebox_override("panel", seamless_tabs_panel)

	# --- Ряд 2: свитчер табов — кнопки глобального кита на плите «Назад»,
	# фикс-сетка 3×260×_atlas_action_button_height() (SCRUM-882) ---
	var switcher_row := HBoxContainer.new()
	switcher_row.name = "SettingsSwitcherRow"
	switcher_row.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(switcher_row)
	switcher_row.add_child(_make_settings_tab_switcher(tabs, s))

	# --- Ряд 3: бесшовный content-owner поверх общего sanctum background.
	# Фидбек 2026-07-08: панель ОБЖИМАЕТ контент по ширине (колонка + поля чипа),
	# а не тянется на всю safe-зону. SCRUM-972 сохраняет её responsive rect,
	# margins и clipping, но убирает отдельный серый fill/кант внутри outer frame.
	var content_panel := PanelContainer.new()
	content_panel.name = "SettingsContentPanel"
	var content_chip_pad := roundf(16.0 * s_ui)
	content_panel.add_theme_stylebox_override("panel", _settings_seamless_content_style(content_chip_pad))
	# SCRUM-1025 accepted transparent clip-owner: 960 @720, 1158 @1080,
	# 1544 @1440. Existing pages retain their centered fixed-width columns.
	var settings_panel_target := 960.0 if vp.y <= 760.0 else clampf(1544.0 * (vp.y / 1440.0), 1158.0, 1544.0)
	var settings_panel_w := minf(settings_panel_target, content_w)
	content_panel.custom_minimum_size = Vector2(settings_panel_w, 0.0)
	content_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_panel.clip_contents = true
	layout.add_child(content_panel)
	# Малые поля: transparent StyleBox margins держат контент внутри safe-zone.
	var content_margin := MarginContainer.new()
	content_margin.name = "SettingsContentSafe"
	content_margin.add_theme_constant_override("margin_left", int(8.0 * s_ui))
	content_margin.add_theme_constant_override("margin_top", int(8.0 * s_ui))
	content_margin.add_theme_constant_override("margin_right", int(8.0 * s_ui))
	content_margin.add_theme_constant_override("margin_bottom", int(8.0 * s_ui))
	content_panel.add_child(content_margin)
	content_margin.add_child(tabs)

	var screen_tab := _make_settings_tab("Экран", s, settings_column_w)
	var screen_page := screen_tab.get_child(0) as VBoxContainer
	var screen_box := screen_page
	# SCRUM-1053: compact Settings needs a structural 24px footer reserve. Make
	# the only non-scrollable legacy page scroll-capable on this tier so its
	# native rows no longer force the VBox past the Atlas safe boundary.
	if vp.y <= 760.0:
		screen_page.add_theme_constant_override("separation", 0)
		var screen_scroll := ScrollContainer.new()
		screen_scroll.name = "SettingsScreenScroll"
		screen_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		screen_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		screen_scroll.follow_focus = true
		screen_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		screen_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		screen_page.add_child(screen_scroll)
		_settings_v6_style_audio_scrollbar(screen_scroll, s)
		screen_box = VBoxContainer.new()
		screen_box.name = "SettingsScreenContent"
		screen_box.custom_minimum_size = Vector2(settings_column_w, 0.0)
		screen_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		screen_box.add_theme_constant_override("separation", int(roundf(20.0 * s)))
		screen_scroll.add_child(screen_box)
	tabs.add_child(screen_tab)

	var monitor_model := _settings_monitor_model(_current_monitor_sizes())
	var pending_screen := int(monitor_model["selected_index"])
	if bool(monitor_model["visible"]):
		var screen_options := OptionButton.new()
		screen_options.name = "SettingsScreenOption"
		_settings_v6_apply_field_theme(screen_options, s)
		for option: Dictionary in monitor_model["options"]:
			screen_options.add_item(str(option["label"]), int(option["index"]))
		screen_options.selected = pending_screen
		screen_options.item_selected.connect(func(index: int) -> void:
			settings_video_pending["screen_index"] = index
			_clamp_pending_resolution_for_screen(index)
			_show_settings_menu()
		)
		_add_settings_control_row(screen_box, "Монитор", screen_options, s)

	var resolution_options := OptionButton.new()
	resolution_options.name = "SettingsResolutionOption"
	_settings_v6_apply_field_theme(resolution_options, s)
	var usable_size := Vector2i(99999, 99999)
	var screen_full_size := Vector2i(99999, 99999)
	var screen_scale := 1.0
	if DisplayServer.get_name() != "headless":
		var res_screen := pending_screen
		usable_size = DisplayServer.screen_get_usable_rect(res_screen).size
		screen_full_size = DisplayServer.screen_get_size(res_screen)
		screen_scale = DisplayServer.screen_get_scale(res_screen)
	var resolution_entries := _settings_resolution_entries(usable_size)
	for option_index in range(resolution_entries.size()):
		var entry: Dictionary = resolution_entries[option_index]
		var resolution: Vector2i = entry["resolution"]
		resolution_options.add_item(str(entry["label"]))
		# SCRUM-591: доступность считаем по ПОЛНОМУ размеру экрана (фуллскрин использует
		# весь экран), а не usable-rect минус таскбар — иначе нативное разрешение (2K на
		# Windows 2560×1440) зря отключается. usable_size остаётся для «Mac»-нативной опции.
		# Физпиксели (× Retina scale) сохраняют корректность Mac/HiDPI (SCRUM-441).
		if not DisplayResolution.resolution_fits(resolution, screen_full_size, screen_scale):
			resolution_options.set_item_disabled(option_index, true)
	resolution_options.selected = clampi(int(settings_video_pending.get("resolution_index", game.selected_resolution_index)), 0, resolution_entries.size() - 1)
	resolution_options.item_selected.connect(func(index: int) -> void:
		settings_video_pending["resolution_index"] = index
		_show_settings_menu()
	)
	_add_settings_control_row(screen_box, "Разрешение", resolution_options, s)

	var mode_options := OptionButton.new()
	mode_options.name = "SettingsWindowModeOption"
	_settings_v6_apply_field_theme(mode_options, s)
	for mode_name in game.WINDOW_MODE_OPTIONS:
		mode_options.add_item(mode_name)
	mode_options.selected = clampi(int(settings_video_pending.get("window_mode_index", game.selected_window_mode_index)), 0, game.WINDOW_MODE_OPTIONS.size() - 1)
	mode_options.item_selected.connect(func(index: int) -> void:
		settings_video_pending["window_mode_index"] = index
		_show_settings_menu()
	)
	_add_settings_control_row(screen_box, "Режим окна", mode_options, s)

	var shake_toggle := CheckBox.new()
	shake_toggle.name = "ScreenShakeToggle"
	shake_toggle.button_pressed = game.screen_shake_enabled
	shake_toggle.text = "Вкл." if shake_toggle.button_pressed else "Выкл."
	_settings_v6_style_checkbox(shake_toggle, s)
	shake_toggle.toggled.connect(func(pressed: bool) -> void:
		game.screen_shake_enabled = pressed
		game.get_tree().root.set_meta("screen_shake", pressed)
		shake_toggle.text = "Вкл." if pressed else "Выкл."
		game.save_game_settings()
	)
	_add_settings_control_row(screen_box, "Тряска камеры", shake_toggle, s)

	var pending_label := Label.new()
	pending_label.name = "SettingsPendingLabel"
	pending_label.text = "Есть непримененные изменения." if _settings_video_dirty() else "Экранные настройки применены."
	pending_label.custom_minimum_size = Vector2(roundf(600.0 * s), roundf(36.0 * s))
	pending_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pending_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pending_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pending_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pending_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_VALUE,
		_settings_v6_font(SemanticTypography.ROLE_VALUE, 22.0, s),
		SemanticTypography.role_min(SemanticTypography.ROLE_VALUE),
		SemanticTypography.role_max(SemanticTypography.ROLE_VALUE)
	))
	pending_label.add_theme_color_override("font_color", SETTINGS_V6_AMBER if _settings_video_dirty() else SETTINGS_V6_MUTED)
	screen_box.add_child(pending_label)

	var audio_tab := _make_settings_tab("Звук", s, settings_column_w)
	tabs.add_child(audio_tab)
	var audio_page := audio_tab.get_child(0) as VBoxContainer
	var audio_scroll := ScrollContainer.new()
	audio_scroll.name = "AudioScroll"
	audio_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	audio_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	audio_scroll.follow_focus = true
	audio_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	audio_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	audio_page.add_child(audio_scroll)
	_settings_v6_style_audio_scrollbar(audio_scroll, s)
	var audio_box := VBoxContainer.new()
	audio_box.name = "SettingsAudioContent"
	audio_box.custom_minimum_size = Vector2(settings_column_w, 0.0)
	audio_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Six real rows + Reset fit 1080p without a scrollbar; compact 720p keeps
	# full-size controls and scrolls instead of shrinking labels.
	audio_box.add_theme_constant_override("separation", int(roundf(10.0 * s)))
	audio_scroll.add_child(audio_box)
	_add_volume_row(audio_box, "Общая громкость", "master_volume", "", s)
	_add_volume_row(audio_box, "Музыка", "music_volume", "music_enabled", s)
	_add_volume_row(audio_box, "Эффекты", "sfx_volume", "sfx_enabled", s)
	_add_volume_row(audio_box, "Звуки интерфейса", "ui_volume", "", s)
	_add_audio_option_row(audio_box, "Без звука вне окна", "mute_when_unfocused", s)
	_add_audio_option_row(audio_box, "Предупреждение о здоровье", "low_hp_warning_enabled", s)
	# SCRUM-879: кит-натив standard_420x104 (маппинг по имени кнопки).
	var audio_reset_height := 72.0 if vp.y < 760.0 else (88.0 if vp.y < 1200.0 else 104.0)
	var reset_audio_button := _settings_v6_make_action_button("Сбросить звук", "SettingsResetAudioButton", 420.0, audio_reset_height)
	reset_audio_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset_audio_button.pressed.connect(func() -> void:
		_reset_audio_to_defaults()
		_show_settings_menu()
	)
	audio_box.add_child(reset_audio_button)

	var controls_tab := _make_settings_tab("Управление", s, settings_column_w)
	tabs.add_child(controls_tab)
	# Вкладка «Управление» переполнялась (прицеливание + строка-ребинд на каждый
	# INPUT_ACTION) — оборачиваем контент в вертикальный ScrollContainer, чтобы
	# всё помещалось и прокручивалось внутри высоты таба.
	var controls_page := controls_tab.get_child(0) as VBoxContainer
	var controls_scroll := ScrollContainer.new()
	controls_scroll.name = "ControlsScroll"
	controls_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	controls_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	controls_scroll.follow_focus = true
	controls_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls_page.add_child(controls_scroll)
	# v6: скроллбар в палитре кита — тёмный жёлоб, латунный граббер.
	var scrollbar := controls_scroll.get_v_scroll_bar()
	if scrollbar != null:
		var scroll_track := StyleBoxFlat.new()
		scroll_track.bg_color = Color(0.05, 0.04, 0.03, 0.85)
		scroll_track.set_corner_radius_all(int(roundf(4.0 * s)))
		scroll_track.set_content_margin_all(roundf(2.0 * s))
		var scroll_grabber := StyleBoxFlat.new()
		scroll_grabber.bg_color = Color(0.52, 0.41, 0.24, 0.95)
		scroll_grabber.set_corner_radius_all(int(roundf(4.0 * s)))
		var scroll_grabber_hi := scroll_grabber.duplicate()
		scroll_grabber_hi.bg_color = Color(0.78, 0.66, 0.44, 1.0)
		scrollbar.add_theme_stylebox_override("scroll", scroll_track)
		scrollbar.add_theme_stylebox_override("grabber", scroll_grabber)
		scrollbar.add_theme_stylebox_override("grabber_highlight", scroll_grabber_hi)
		scrollbar.add_theme_stylebox_override("grabber_pressed", scroll_grabber_hi)
		scrollbar.custom_minimum_size = Vector2(roundf(10.0 * s), 0.0)
	var controls_box := VBoxContainer.new()
	controls_box.name = "ControlsContent"
	controls_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_box.add_theme_constant_override("separation", int(roundf(20.0 * s)))
	controls_scroll.add_child(controls_box)

	# SCRUM-816: верхняя секция «Устройство ввода» — режим подсказок + live-статус.
	_add_controls_section_header(controls_box, "Устройство ввода", s)
	var device_option := OptionButton.new()
	device_option.name = "SettingsInputModeOption"
	device_option.focus_mode = Control.FOCUS_ALL
	_settings_v6_apply_field_theme(device_option, s)
	device_option.add_item("Авто (по последнему вводу)")
	device_option.add_item("Клавиатура и мышь")
	device_option.add_item("Геймпад")
	var input_mode_index: int = int({"auto": 0, "keyboard": 1, "gamepad": 2}.get(str(game.input_mode), 0))
	device_option.selected = input_mode_index
	device_option.item_selected.connect(func(index: int) -> void:
		var mode: String = ["auto", "keyboard", "gamepad"][clampi(index, 0, 2)]
		game.input_mode = mode
		var idm := _input_device_manager()
		if idm != null and idm.has_method("set_input_mode"):
			idm.set_input_mode(mode)
		game.save_game_settings()
	)
	_add_settings_control_row(controls_box, "Режим устройства", device_option, s)

	var device_hint := Label.new()
	device_hint.name = "SettingsInputModeHint"
	device_hint.text = "И клавиатура, и геймпад работают одновременно в любом режиме — режим лишь задаёт, чьи подсказки показывать."
	device_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	device_hint.custom_minimum_size = Vector2(roundf(880.0 * s), 0.0)
	device_hint.add_theme_font_size_override("font_size", _settings_v6_font(SemanticTypography.ROLE_CAPTION, 20.0, s))
	device_hint.add_theme_color_override("font_color", SETTINGS_V6_HINT_BLUE)
	controls_box.add_child(device_hint)

	var gamepad_status := Label.new()
	gamepad_status.name = "SettingsGamepadStatus"
	gamepad_status.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_VALUE,
		_settings_v6_font(SemanticTypography.ROLE_VALUE, 22.0, s),
		SemanticTypography.role_min(SemanticTypography.ROLE_VALUE),
		SemanticTypography.role_max(SemanticTypography.ROLE_VALUE)
	))
	gamepad_status.add_theme_color_override("font_color", SETTINGS_V6_AMBER)
	controls_box.add_child(gamepad_status)
	_gamepad_status_label = gamepad_status
	_connect_gamepad_status_signals()
	_refresh_gamepad_status_line()

	var aim_options := OptionButton.new()
	aim_options.name = "SettingsAimModeOption"
	_settings_v6_apply_field_theme(aim_options, s)
	# FAN-1449: device-neutral копия — ручной режим одинаково работает курсором
	# мыши и правым стиком (значение в settings.cfg остаётся `cursor`).
	aim_options.add_item("Автонаводка на ближайшего")
	aim_options.add_item("Ручное: курсор / стик")
	aim_options.selected = 1 if str(game.aim_mode) == "cursor" else 0
	aim_options.item_selected.connect(func(index: int) -> void:
		game.aim_mode = "cursor" if index == 1 else "nearest"
		game.get_tree().root.set_meta("aim_mode", game.aim_mode)
		game.save_game_settings()
		AimController.apply_hint_label(_aim_mode_hint_label, game.aim_mode, _input_device_manager())
	)
	_add_settings_control_row(controls_box, "Прицеливание", aim_options, s)
	var aim_hint := Label.new()
	aim_hint.name = "SettingsAimModeHint"
	aim_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aim_hint.custom_minimum_size = Vector2(roundf(880.0 * s), 0.0)
	aim_hint.add_theme_font_size_override("font_size", _settings_v6_font(SemanticTypography.ROLE_CAPTION, 20.0, s))
	aim_hint.add_theme_color_override("font_color", SETTINGS_V6_HINT_BLUE)
	controls_box.add_child(aim_hint)
	_aim_mode_hint_label = aim_hint
	AimController.apply_hint_label(aim_hint, game.aim_mode, _input_device_manager())

	var debug_toggle := CheckBox.new()
	debug_toggle.name = "DebugModeToggle"
	debug_toggle.button_pressed = game.debug_mode_enabled
	debug_toggle.text = "Вкл. (ПКМ / Shift+ЛКМ)" if debug_toggle.button_pressed else "Выкл."
	debug_toggle.tooltip_text = "Дебаг: в бою ПКМ или Shift+ЛКМ задают точку движения, средняя кнопка телепортирует."
	_settings_v6_style_checkbox(debug_toggle, s)
	debug_toggle.toggled.connect(func(pressed: bool) -> void:
		game.debug_mode_enabled = pressed
		game.get_tree().root.set_meta("debug_mode", pressed)
		debug_toggle.text = "Вкл. (ПКМ / Shift+ЛКМ)" if pressed else "Выкл."
		game.save_game_settings()
	)
	_add_settings_control_row(controls_box, "Дебаг-режим", debug_toggle, s)

	var feedback_toggle := CheckBox.new()
	feedback_toggle.name = "CombatFeedbackToggle"
	feedback_toggle.button_pressed = game.combat_feedback_enabled
	feedback_toggle.text = "Вкл." if feedback_toggle.button_pressed else "Выкл."
	feedback_toggle.tooltip_text = "Боевые цифры, крит-маркеры, вспышка попадания и зелёные числа лечения."
	_settings_v6_style_checkbox(feedback_toggle, s)
	feedback_toggle.toggled.connect(func(pressed: bool) -> void:
		game.combat_feedback_enabled = pressed
		game.get_tree().root.set_meta("combat_feedback", pressed)
		feedback_toggle.text = "Вкл." if pressed else "Выкл."
		game.save_game_settings()
	)
	_add_settings_control_row(controls_box, "Боевой фидбек", feedback_toggle, s)

	_add_controls_section_header(controls_box, "Клавиатура", s)
	for input_action in game.INPUT_ACTIONS:
		var action_name: String = input_action["action"]
		var bind_button := Button.new()
		bind_button.name = "BindingButton_%s" % action_name
		bind_button.text = _binding_text(action_name)
		bind_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_settings_v6_apply_field_theme(bind_button, s)
		bind_button.pressed.connect(func() -> void:
			_begin_rebind(action_name)
		)
		var bind_row := _add_settings_control_row(controls_box, input_action["label"], bind_button, s)
		bind_row.name = "BindingRow_%s" % action_name

	var hint_label := Label.new()
	hint_label.text = "Клик по биндингу, затем нажми клавишу. Esc отменяет."
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hint_label.add_theme_font_size_override("font_size", _settings_v6_font(SemanticTypography.ROLE_CAPTION, 22.0, s))
	hint_label.add_theme_color_override("font_color", SETTINGS_V6_HINT_BLUE)
	controls_box.add_child(hint_label)

	# SCRUM-879: кит-натив wide_440x104 (маппинг по имени кнопки).
	var reset_button := _settings_v6_make_action_button("Сбросить управление", "SettingsResetBindingsButton", 440.0, 104.0)
	reset_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset_button.pressed.connect(func() -> void:
		_reset_input_bindings_to_defaults()
		_show_settings_menu()
	)
	controls_box.add_child(reset_button)

	# SCRUM-816: секция «Геймпад» — ребинд joypad-кнопок/осей + deadzone + вибрация.
	_add_controls_section_header(controls_box, "Геймпад", s)
	for input_action in game.INPUT_ACTIONS:
		var gp_action: String = input_action["action"]
		var gp_button := Button.new()
		gp_button.name = "GamepadBindButton_%s" % gp_action
		gp_button.text = _gamepad_binding_text(gp_action)
		gp_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		gp_button.focus_mode = Control.FOCUS_ALL
		_settings_v6_apply_field_theme(gp_button, s)
		var gp_glyph := _gamepad_glyph_for_action(gp_action)
		if gp_glyph != null:
			gp_button.icon = gp_glyph
			gp_button.expand_icon = false
		gp_button.pressed.connect(func() -> void:
			_begin_gamepad_rebind(gp_action)
		)
		var gp_row := _add_settings_control_row(controls_box, input_action["label"], gp_button, s)
		gp_row.name = "GamepadBindRow_%s" % gp_action

	var gp_hint := Label.new()
	gp_hint.text = "Клик по кнопке, затем нажми кнопку/наклони стик геймпада. B/Esc отменяет."
	gp_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	gp_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gp_hint.custom_minimum_size = Vector2(roundf(880.0 * s), 0.0)
	gp_hint.add_theme_font_size_override("font_size", _settings_v6_font(SemanticTypography.ROLE_CAPTION, 20.0, s))
	gp_hint.add_theme_color_override("font_color", SETTINGS_V6_HINT_BLUE)
	controls_box.add_child(gp_hint)

	var deadzone_slider := HSlider.new()
	deadzone_slider.name = "SettingsGamepadDeadzoneSlider"
	deadzone_slider.min_value = 0.05
	deadzone_slider.max_value = 0.5
	deadzone_slider.step = 0.05
	deadzone_slider.custom_minimum_size = Vector2(roundf(420.0 * s), roundf(42.0 * s))
	deadzone_slider.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	deadzone_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	deadzone_slider.focus_mode = Control.FOCUS_ALL
	_settings_v6_style_slider(deadzone_slider, s)
	deadzone_slider.value = clampf(float(game.gamepad_deadzone), 0.05, 0.5)
	var deadzone_row := _add_settings_control_row(controls_box, "Мёртвая зона стика", deadzone_slider, s)
	var deadzone_value := Label.new()
	deadzone_value.name = "SettingsGamepadDeadzoneValue"
	deadzone_value.text = "%.2f" % deadzone_slider.value
	deadzone_value.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_VALUE,
		_settings_v6_font(SemanticTypography.ROLE_VALUE, 24.0, s),
		SemanticTypography.role_min(SemanticTypography.ROLE_VALUE),
		SemanticTypography.role_max(SemanticTypography.ROLE_VALUE)
	))
	deadzone_value.add_theme_color_override("font_color", SETTINGS_V6_AMBER)
	deadzone_row.add_child(deadzone_value)
	deadzone_slider.value_changed.connect(func(value: float) -> void:
		var dz := snappedf(clampf(value, 0.05, 0.5), 0.05)
		game.gamepad_deadzone = dz
		game.get_tree().root.set_meta("gamepad_deadzone", dz)
		deadzone_value.text = "%.2f" % dz
		game.save_game_settings()
	)

	var vibration_toggle := CheckBox.new()
	vibration_toggle.name = "SettingsGamepadVibrationToggle"
	vibration_toggle.button_pressed = bool(game.gamepad_vibration)
	vibration_toggle.text = "Вкл." if vibration_toggle.button_pressed else "Выкл."
	_settings_v6_style_checkbox(vibration_toggle, s)
	vibration_toggle.toggled.connect(func(pressed: bool) -> void:
		game.gamepad_vibration = pressed
		game.get_tree().root.set_meta("gamepad_vibration", pressed)
		vibration_toggle.text = "Вкл." if pressed else "Выкл."
		game.save_game_settings()
	)
	_add_settings_control_row(controls_box, "Вибрация", vibration_toggle, s)

	# SCRUM-879: кит-натив standard_420x104 (по size-маппингу): у minimal_metal
	# высоты 72 глобальный seal-инвариант SCRUM-450 требует 104 — берём натив,
	# единый с «Сбросить звук».
	var gp_reset := _settings_v6_make_action_button("Сбросить геймпад", "SettingsResetGamepadButton", 420.0, 104.0)
	gp_reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	gp_reset.pressed.connect(func() -> void:
		_reset_gamepad_bindings_to_defaults()
	)
	controls_box.add_child(gp_reset)

	# SCRUM-1025: fourth Settings/Game page consumes the authoritative
	# SCRUM-976 API. Values persist now but affect only the next run snapshot.
	var game_settings_tab := _make_settings_game_tab(s, settings_column_w, vp)
	tabs.add_child(game_settings_tab)
	_wire_settings_game_focus(tabs, game_settings_tab, vp.y <= 760.0)

	# --- Ряд 4: футер — «Вернуть»/«Применить» справа («Назад» теперь в шапке).
	# Кнопки глобального кита, фикс 280×64: Apply/Revert носят НАТИВНУЮ пластину
	# по size-маппингу кита (y<=66, 240<=x<360) — без даунскейла и растяжки.
	# SCRUM-1053: on the compact tier the texture-safe SettingsSafeArea ends at
	# the first bottom-frame pixel. Keep a 24px authored inner reserve beneath
	# the footer so the plates, labels, focus and hit rects cannot enter the live
	# Atlas ornament. The wrapper is hidden together with the footer on Game, so
	# SCRUM-1025's exact 892x242 compact scroll viewport remains unchanged.
	var action_safe := Control.new()
	action_safe.name = "SettingsBottomActionsSafe"
	action_safe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var footer_bottom_reserve := 24 if vp.y <= 760.0 else 0
	action_safe.custom_minimum_size = Vector2(0.0, 64.0 + float(footer_bottom_reserve))
	action_safe.set_meta("settings_footer_bottom_reserve", footer_bottom_reserve)
	layout.add_child(action_safe)
	var action_row := HBoxContainer.new()
	action_row.name = "SettingsBottomActions"
	action_row.alignment = BoxContainer.ALIGNMENT_END
	action_row.add_theme_constant_override("separation", int(14.0 * s_ui))
	# Футер той же ширины, что панель: кнопки прижаты к её правому краю.
	action_row.set_anchors_preset(Control.PRESET_CENTER_TOP)
	action_row.offset_left = -settings_panel_w * 0.5
	action_row.offset_top = 0.0
	action_row.offset_right = settings_panel_w * 0.5
	action_row.offset_bottom = 64.0
	action_row.custom_minimum_size = Vector2(settings_panel_w, 64.0)
	action_safe.add_child(action_row)
	var update_button := _settings_v6_make_action_button("Обновить игру", "SettingsUpdateButton", 280.0, 64.0)
	update_button.pressed.connect(_update_presenter.request_check)
	action_row.add_child(update_button)
	var action_spacer := Control.new()
	action_spacer.name = "SettingsBottomActionsSpacer"
	action_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_child(action_spacer)
	var revert_button := _settings_v6_make_action_button("Вернуть", "SettingsRevertButton", 280.0, 64.0)
	revert_button.disabled = not _settings_video_dirty()
	revert_button.pressed.connect(_revert_pending_video_settings)
	action_row.add_child(revert_button)
	var apply_button := _settings_v6_make_action_button("Применить", "SettingsApplyButton", 280.0, 64.0)
	apply_button.disabled = not _settings_video_dirty()
	apply_button.pressed.connect(_apply_pending_video_settings)
	action_row.add_child(apply_button)
	_settings_fit_kit_row([update_button, revert_button, apply_button], 280.0, 64.0)
	# Apply/Revert belong only to pending Screen settings. The accepted Game-tab
	# mockup has no irrelevant footer; hiding it also restores the exact compact
	# scroll viewport while tabs/header remain fixed.
	var update_settings_footer_visibility := func(tab_index: int) -> void:
		var show_footer := tab_index != 3
		action_safe.visible = show_footer
		action_row.visible = show_footer
	tabs.tab_changed.connect(update_settings_footer_visibility)
	update_settings_footer_visibility.call(tabs.current_tab)

	# Полая рама frame_border ПОВЕРХ всего контента — строго последним слоем.
	_unified_add_frame(root, "Settings")

	# SCRUM-813: стартовый фокус — первая вкладка настроек; LB/RB листают вкладки
	# (см. _handle_menu_shoulder_nav). Слайдеры/OptionButton/CheckBox фокусируемы —
	# ui_left/right меняют значение из коробки. B/Esc = «Назад» (settings_back).
	_ensure_run_ui_gamepad_bindings()
	var first_settings_tab := root.find_child("SettingsTabButton_0", true, false) as Button
	if first_settings_tab != null:
		first_settings_tab.call_deferred("grab_focus")




func _resolve_settings_return_origin(requested_return_origin: String) -> String:
	if requested_return_origin == SETTINGS_RETURN_RUN_PAUSE:
		return SETTINGS_RETURN_RUN_PAUSE
	if requested_return_origin == SETTINGS_RETURN_MAIN_MENU:
		return SETTINGS_RETURN_MAIN_MENU
	if settings_return_origin == SETTINGS_RETURN_RUN_PAUSE and game._is_gameplay_paused():
		return SETTINGS_RETURN_RUN_PAUSE
	if _is_run_settings_context():
		return SETTINGS_RETURN_RUN_PAUSE
	return SETTINGS_RETURN_MAIN_MENU




func _is_run_settings_context() -> bool:
	if _is_run_pause_overlay_open():
		return true
	if game._has_pause_reason("escape_menu"):
		return true
	return game._is_gameplay_paused() and game.combat_active




func _return_from_settings() -> void:
	var return_origin := settings_return_origin
	settings_return_origin = SETTINGS_RETURN_MAIN_MENU
	settings_video_pending.clear()
	# SCRUM-816: live-статус геймпада привязан к Label вкладки — обнуляем ссылку,
	# чтобы hot-plug коллбэки не трогали освобождённый узел (они гардят валидность).
	_gamepad_status_label = null
	_aim_mode_hint_label = null
	if return_origin == SETTINGS_RETURN_RUN_PAUSE:
		game.pending_rebind_action = ""
		game.ui_escape_action = Callable()
		if game.ui_layer != null and is_instance_valid(game.ui_layer):
			game.ui_layer.queue_free()
		game.ui_layer = null
		_show_pause_menu(true)
		return
	_show_main_menu()




func _sync_window_content_scale(content_size: Vector2i) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if content_size.x <= 0 or content_size.y <= 0:
		return
	var window: Window = game.get_window()
	if window == null:
		return
	window.content_scale_size = content_size




func _editor_preview_window_resolution(usable_logical: Vector2i, screen_full: Vector2i, screen_scale: float) -> Vector2i:
	var scale := maxf(screen_scale, 1.0)
	var usable_physical := DisplayResolution.physical_usable_size(usable_logical, scale)
	var max_window := Vector2i(maxi(320, usable_physical.x - 96), maxi(180, usable_physical.y - 96))
	var default_index := DisplayResolution.default_resolution_index(screen_full, scale)
	var target: Vector2i = game.RESOLUTION_OPTIONS[clampi(default_index, 0, game.RESOLUTION_OPTIONS.size() - 1)]
	var fit_scale: float = minf(minf(float(max_window.x) / float(target.x), float(max_window.y) / float(target.y)), 1.0)
	if fit_scale < 1.0:
		target = Vector2i(
			maxi(320, int(floor(float(target.x) * fit_scale))),
			maxi(180, int(floor(float(target.y) * fit_scale)))
		)
	target.x = mini(target.x, max_window.x)
	target.y = mini(target.y, max_window.y)
	return target




func _apply_editor_preview_video_settings() -> void:
	if DisplayServer.get_name() == "headless":
		return

	var screen_count := DisplayServer.get_screen_count()
	var screen: int = clampi(game.selected_screen_index, 0, maxi(screen_count - 1, 0))
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var screen_full := DisplayServer.screen_get_size(screen)
	var screen_scale := DisplayServer.screen_get_scale(screen)
	var resolution := _editor_preview_window_resolution(usable.size, screen_full, screen_scale)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)
	DisplayServer.window_set_current_screen(screen)
	DisplayServer.window_set_size(resolution)
	_sync_window_content_scale(resolution)
	var logical_window_size := Vector2i(
		int(round(float(resolution.x) / maxf(screen_scale, 1.0))),
		int(round(float(resolution.y) / maxf(screen_scale, 1.0)))
	)
	DisplayServer.window_set_position(usable.position + (usable.size - logical_window_size) / 2)




func _apply_video_settings() -> void:
	game.selected_window_mode_index = clampi(game.selected_window_mode_index, 0, game.WINDOW_MODE_OPTIONS.size() - 1)
	if DisplayServer.get_name() == "headless":
		game.selected_resolution_index = clampi(game.selected_resolution_index, 0, game.RESOLUTION_OPTIONS.size() - 1)
		game.save_game_settings()
		return

	var screen_count := DisplayServer.get_screen_count()
	game.selected_screen_index = clampi(game.selected_screen_index, 0, maxi(screen_count - 1, 0))
	var screen: int = game.selected_screen_index
	# usable rect учитывает масштаб ОС, док и меню-бар: окно не вылезет за экран.
	var usable := DisplayServer.screen_get_usable_rect(screen)
	# SCRUM-591: полный размер экрана — база доступности/клэмпа нативного разрешения.
	var screen_full := DisplayServer.screen_get_size(screen)
	var screen_scale := DisplayServer.screen_get_scale(screen)
	var resolution_entries := _settings_resolution_entries(usable.size)
	game.selected_resolution_index = clampi(game.selected_resolution_index, 0, resolution_entries.size() - 1)
	var selected_resolution: Vector2i = resolution_entries[game.selected_resolution_index]["resolution"]
	if not DisplayResolution.resolution_fits(selected_resolution, screen_full, screen_scale):
		game.selected_resolution_index = DisplayResolution.default_resolution_index(screen_full, screen_scale)

	match game.selected_window_mode_index:
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_current_screen(screen)
			DisplayServer.window_set_position(usable.position)
			DisplayServer.window_set_size(usable.size)
			_sync_window_content_scale(usable.size)
		2:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_current_screen(screen)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			_sync_window_content_scale(DisplayServer.screen_get_size(screen))
		_:
			var resolution: Vector2i = resolution_entries[game.selected_resolution_index]["resolution"]
			# SCRUM-441: клэмп к ФИЗ.пикселям (× Retina scale), не к лог.точкам.
			# SCRUM-591: база клэмпа — ПОЛНЫЙ размер экрана (screen_full), а не usable-rect
			# минус таскбар, иначе выбранное нативное разрешение (2K) ужимается при применении.
			resolution = DisplayResolution.clamp_to_physical(resolution, screen_full, screen_scale)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_current_screen(screen)
			DisplayServer.window_set_size(resolution)
			_sync_window_content_scale(resolution)
			var logical_window_size := Vector2i(
				int(round(float(resolution.x) / maxf(screen_scale, 1.0))),
				int(round(float(resolution.y) / maxf(screen_scale, 1.0)))
			)
			# Центр выбранного монитора: позиция считается от origin его usable rect.
			DisplayServer.window_set_position(usable.position + (usable.size - logical_window_size) / 2)

	game.save_game_settings()
