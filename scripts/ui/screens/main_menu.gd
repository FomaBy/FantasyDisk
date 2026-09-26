extends "res://scripts/ui/screens/menu_shell_kit.gd"

# FAN-3824: модуль распределённого UI-класса — главное меню, диалоги выхода и продолжения забега.
# Часть линейной extends-цепочки scripts/ui/screens/** (сборка — фасад
# scripts/ui_screens.gd). Код перенесён из ui_screens.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в ui_screens_shared_api.gd.





# SCRUM-1059 supersedes the SCRUM-981 2×3 action grid while preserving its
# accepted PixelLab/runtime background, logo, button family and hollow shell.
# Logo and six actions occupy one responsive left column inside the real
# authored inner rect; the scenic character group remains readable to the right.


func _main_menu_gold_shell_metrics(viewport_size: Vector2) -> Dictionary:
	# SCRUM-1059: exact UI Director content-zone contract for 1152×648 through
	# 2560×1440. The outer safe rect remains continuously derived from the
	# 9-slice source; controls use the stricter authored inner rect.
	var margins := _unified_safe_margins_for_size(viewport_size)
	var safe_rect := Rect2(
		Vector2(margins.x, margins.y),
		Vector2(maxf(1.0, viewport_size.x - margins.x - margins.z), maxf(1.0, viewport_size.y - margins.y - margins.w))
	)
	var reserve := 32.0 if viewport_size.y >= 1200.0 else 24.0
	var inner_rect := safe_rect.grow(-reserve)
	var logo_size := Vector2(480.0, 180.0)
	var button_width := MAIN_MENU_ACTION_BUTTON_WIDTH
	var button_height := 96.0
	var row_gap := 14.0
	var logo_gap := 20.0
	var glow_side := 116.0
	var gratitude_side := 96.0
	# SCRUM-1095: the glow keeps a validator-safe two-pixel separation from the
	# version rect.  The Button is biased three pixels toward the version inside
	# that glow; its hitbox remains bounded and never intersects the label.
	var utility_cluster_gap := 2.0
	var gratitude_button_x_bias := 3.0
	var utility_frame_reserve := 8.0
	var version_height := 32.0
	var version_font_size := 18
	if viewport_size.y < 700.0:
		logo_size = Vector2(160.0, 60.0)
		button_width = 320.0
		button_height = 54.0
		row_gap = 2.0
		logo_gap = 4.0
		glow_side = 84.0
		gratitude_side = 72.0
		version_height = 22.0
		version_font_size = 14
	elif viewport_size.y < 800.0:
		logo_size = Vector2(192.0, 72.0)
		button_width = 340.0
		button_height = 56.0
		row_gap = 5.0
		logo_gap = 6.0
		glow_side = 84.0
		gratitude_side = 72.0
		version_height = 24.0
		version_font_size = 14
	elif viewport_size.y < 1000.0:
		logo_size = Vector2(267.0, 100.0)
		button_width = 360.0
		button_height = 64.0
		row_gap = 8.0
		logo_gap = 8.0
		glow_side = 96.0
		gratitude_side = 80.0
		version_height = 26.0
		version_font_size = 15
	elif viewport_size.y < 1200.0:
		logo_size = Vector2(331.0, 124.0)
		button_height = 76.0
		row_gap = 10.0
		logo_gap = 12.0
		glow_side = 96.0
		gratitude_side = 80.0
		version_height = 28.0
		version_font_size = 16
	var logo_rect := Rect2(inner_rect.position, logo_size)
	var actions_rect := Rect2(
		Vector2(inner_rect.position.x, logo_rect.end.y + logo_gap),
		Vector2(button_width, button_height * MAIN_MENU_BUTTON_COUNT + row_gap * (MAIN_MENU_BUTTON_COUNT - 1.0))
	)
	# SCRUM-1093: the compact utility cluster has its own measured reserve from
	# the frame-safe opening. The page-wide inner rect remains intentionally more
	# conservative for large panels/buttons, but made the tiny version cluster
	# look detached from the actual lower-right rail.
	var utility_anchor := safe_rect.end - Vector2.ONE * utility_frame_reserve
	return {
		"safe_rect": safe_rect,
		"inner_rect": inner_rect,
		"logo_rect": logo_rect,
		"actions_rect": actions_rect,
		"button_width": button_width,
		"button_height": button_height,
		"row_gap": row_gap,
		"gratitude_glow_side": glow_side,
		"gratitude_side": gratitude_side,
		"utility_anchor": utility_anchor,
		"utility_cluster_gap": utility_cluster_gap,
		"gratitude_button_x_bias": gratitude_button_x_bias,
		"utility_frame_reserve": utility_frame_reserve,
		"version_height": version_height,
		"version_font_size": version_font_size,
	}




func _layout_main_menu_gold_shell(root: Control, title_logo: TextureRect, action_box: GridContainer, gratitude_glow: TextureRect, gratitude_button: Button, version_label: Label, buttons: Array) -> void:
	if root == null or not is_instance_valid(root):
		return
	var viewport_size := root.size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		viewport_size = game.get_viewport().get_visible_rect().size
	var metrics := _main_menu_gold_shell_metrics(viewport_size)
	var logo_rect: Rect2 = metrics["logo_rect"]
	var actions_rect: Rect2 = metrics["actions_rect"]
	_apply_control_rect(title_logo, logo_rect)
	_apply_control_rect(action_box, actions_rect)
	action_box.custom_minimum_size = actions_rect.size
	action_box.add_theme_constant_override("v_separation", int(metrics["row_gap"]))
	for candidate in buttons:
		var button := candidate as Button
		if button != null:
			# Keep one semantic/art family at every responsive tier. Without the
			# explicit assignment the generic resolver would switch compact rows
			# to the unrelated Continue plate solely because their height is <=76.
			UIButtonFamily.assign(button, "text/main_menu_380x104", true)
			# Main Menu labels are fixed one-line actions by contract. Smart-wrap
			# makes the longest Russian label inflate only the first compact row.
			button.autowrap_mode = TextServer.AUTOWRAP_OFF
			_set_action_button_size(button, float(metrics["button_width"]), float(metrics["button_height"]))
			_fit_main_menu_button_styles(button, float(metrics["button_width"]), float(metrics["button_height"]))
	action_box.queue_sort()
	var safe_rect: Rect2 = metrics["safe_rect"]
	var version_font_size := SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_CAPTION,
		int(metrics["version_font_size"]),
		SemanticTypography.role_min(SemanticTypography.ROLE_CAPTION),
		SemanticTypography.role_max(SemanticTypography.ROLE_CAPTION)
	)
	version_label.add_theme_font_size_override(
		"font_size",
		version_font_size
	)
	var version_font: Font = version_label.get_theme_font("font")
	if version_font == null:
		version_font = ThemeDB.fallback_font
	var measured_version_width := 1.0
	if version_font != null:
		measured_version_width = ceilf(version_font.get_string_size(
			version_label.text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			version_font_size
		).x)
	# Never silently clamp a future semantic version (for example a beta tag):
	# the rect follows the actual rendered string plus the outline/effect reserve.
	var version_width := measured_version_width + 6.0
	var utility_anchor: Vector2 = metrics["utility_anchor"]
	var version_size := Vector2(version_width, float(metrics["version_height"]))
	var version_rect := Rect2(utility_anchor - version_size, version_size)
	var glow_side := float(metrics["gratitude_glow_side"])
	var gratitude_side := float(metrics["gratitude_side"])
	var glow_rect := Rect2(
		Vector2(
			version_rect.position.x - float(metrics["utility_cluster_gap"]) - glow_side,
			utility_anchor.y - glow_side
		),
		Vector2.ONE * glow_side
	)
	var gratitude_inset := (glow_side - gratitude_side) * 0.5
	var gratitude_rect := Rect2(
		glow_rect.position + Vector2(gratitude_inset + float(metrics["gratitude_button_x_bias"]), gratitude_inset),
		Vector2.ONE * gratitude_side
	)
	_apply_control_rect(gratitude_glow, glow_rect)
	_apply_control_rect(gratitude_button, gratitude_rect)
	_apply_control_rect(version_label, version_rect)
	version_label.set_meta("scrum1093_measured_text_width", measured_version_width)
	version_label.set_meta("scrum1093_utility_anchor", utility_anchor)
	version_label.set_meta("scrum1093_cluster_gap", metrics["utility_cluster_gap"])
	version_label.set_meta("scrum1095_gratitude_button_x_bias", metrics["gratitude_button_x_bias"])
	root.set_meta("gold_shell_content_rect", safe_rect)
	root.set_meta("gold_shell_inner_rect", metrics["inner_rect"])
	root.set_meta("main_menu_utility_anchor", utility_anchor)
	root.set_meta("main_menu_utility_frame_reserve", metrics["utility_frame_reserve"])
	root.set_meta("gold_shell_screen_id", "main_menu")




func _fit_main_menu_button_styles(button: Button, width: float, height: float) -> void:
	# The accepted main-menu sources are 380×104 9-slice plates. Compact tiers
	# keep their caps/rails and the same family, but scale the content margins to
	# the rendered geometry so the StyleBox minimum does not force 60–92px rows.
	var horizontal := maxf(40.0, roundf(54.0 * width / 380.0) + 2.0)
	# The canonical source already defines vertical content=texture margin
	# (21px at 104px); preserve that ratio exactly. Adding a second reserve here
	# would inflate the compact control beyond its authored rect.
	var vertical := maxf(4.0, roundf(21.0 * height / 104.0))
	for state in UIButtonFamily.STATES:
		var original := button.get_theme_stylebox(state)
		if original == null:
			continue
		var fitted := original.duplicate(true) as StyleBox
		if fitted is StyleBoxTexture:
			var fitted_texture := fitted as StyleBoxTexture
			fitted_texture.texture_margin_left = roundf(54.0 * width / 380.0)
			fitted_texture.texture_margin_right = roundf(54.0 * width / 380.0)
			fitted_texture.texture_margin_top = roundf(21.0 * height / 104.0)
			fitted_texture.texture_margin_bottom = roundf(21.0 * height / 104.0)
		fitted.content_margin_left = horizontal
		fitted.content_margin_right = horizontal
		fitted.content_margin_top = vertical
		fitted.content_margin_bottom = vertical
		button.add_theme_stylebox_override(state, fitted)
	# Live downsize must discard the previous tier's cached combined minimum;
	# otherwise GridContainer keeps two stale pixels per row after 2K→648.
	button.update_minimum_size()
	button.reset_size()




func _gratitude_button_style(state: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.035, 0.045, 0.0)
	style.border_color = Color(0.68, 0.51, 0.25, 0.0)
	var border_width := 0
	match state:
		"hover":
			style.bg_color = Color(0.10, 0.075, 0.065, 0.42)
			style.border_color = Color(0.82, 0.66, 0.36, 0.78)
			border_width = 1
		"focus":
			style.bg_color = Color(0.11, 0.12, 0.14, 0.58)
			style.border_color = Color(0.84, 0.88, 0.94, 0.98)
			border_width = 2
		"pressed":
			style.bg_color = Color(0.075, 0.045, 0.05, 0.58)
			style.border_color = Color(0.78, 0.48, 0.30, 0.82)
			border_width = 1
		"disabled":
			style.bg_color = Color(0.03, 0.03, 0.035, 0.16)
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(4.0)
	return style




func _gratitude_glow_texture(peak_alpha: float) -> GradientTexture2D:
	# SCRUM-1081: a bounded procedural aura, not a new bitmap asset. The radial
	# texture is clipped to MainMenuGratitudeGlow, so no state can cover the gold
	# shell rail or change the icon hitbox geometry.
	var gradient := Gradient.new()
	var warm_gold := Color(0.84, 0.62, 0.28, clampf(peak_alpha, 0.0, 0.26))
	gradient.offsets = PackedFloat32Array([0.0, 0.58, 0.82, 1.0])
	gradient.colors = PackedColorArray([
		warm_gold,
		Color(warm_gold.r, warm_gold.g, warm_gold.b, warm_gold.a * 0.72),
		Color(warm_gold.r, warm_gold.g, warm_gold.b, warm_gold.a * 0.26),
		Color(warm_gold.r, warm_gold.g, warm_gold.b, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture




func _gratitude_alpha_aware_texture(source: Texture2D, button: Button) -> Texture2D:
	# SCRUM-1095: the accepted PixelLab PNG deliberately has generous transparent
	# source padding.  Button.expand_icon scales that full 256x256 square, so the
	# transparent right edge — not the visible hands/heart — used to define the
	# apparent gap.  Build a runtime AtlasTexture from actual used alpha instead
	# of modifying the source bitmap.  The square remains aspect-stable; all spare
	# width is placed on the left so the alpha edge facing the version is exact.
	if source == null:
		return source
	var image := source.get_image()
	if image == null or image.is_empty():
		return source
	var used: Rect2i = image.get_used_rect()
	if not used.has_area():
		return source
	var side := maxi(used.size.x, used.size.y)
	var region_x := used.end.x - side
	var region_y := used.position.y - int(floorf(float(side - used.size.y) * 0.5))
	region_x = clampi(region_x, 0, maxi(0, image.get_width() - side))
	region_y = clampi(region_y, 0, maxi(0, image.get_height() - side))
	var atlas_region := Rect2i(region_x, region_y, side, side)
	if not atlas_region.encloses(used):
		return source
	var cropped := AtlasTexture.new()
	cropped.atlas = source
	cropped.region = Rect2(atlas_region)
	cropped.filter_clip = true
	if button != null:
		button.set_meta("scrum1095_source_asset", source.resource_path)
		button.set_meta("scrum1095_source_alpha_rect", Rect2(used))
		button.set_meta("scrum1095_atlas_region", Rect2(atlas_region))
	return cropped




func _show_main_menu() -> void:
	game._play_music("menu")
	game._clear_all_game_pauses()
	game.pending_rebind_action = ""
	game._clear_world()
	game._clear_hud()
	game._clear_ui()
	game.current_act = 1
	game.route_stage = 0
	game.route_selected_indices.clear()
	game.used_event_ids.clear()
	game.current_event_definition.clear()
	game.pending_event_combat.clear()
	game.event_shop_exit_action = Callable()  # SCRUM-996
	game.pending_level_ups = 0
	game.shop_reentry_pending = false
	game.shop_reentry_route_stage = -1
	game.shop_reentry_branch_index = -1
	game.route_nodes = game.route._generate_route()

	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "MainMenuScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	game.ui_layer.add_child(root)
	_prepare_global_tooltips(root)

	var background := TextureRect.new()
	background.name = "MainMenuBackground"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.texture = game._cached_texture(game.MAIN_MENU_BACKGROUND)
	root.add_child(background)

	var global_shade := ColorRect.new()
	global_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	global_shade.color = Color(0.02, 0.02, 0.04, 0.18)
	root.add_child(global_shade)

	var title_logo := TextureRect.new()
	title_logo.name = "MainMenuTitleLabel"
	title_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_logo.texture = game._cached_texture("res://assets/sprites/ui/menu_title/main_menu_title_fantasy_disk.png")
	title_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_logo)

	var action_box := GridContainer.new()
	action_box.name = "MainMenuActions"
	action_box.columns = 1
	root.add_child(action_box)

	var start_button := _make_button("Начать новую игру")
	start_button.name = "MainMenuStartButton"
	start_button.pressed.connect(func() -> void:
		if game.run_autosave_has_run():
			_show_continue_run_dialog()
		else:
			# FAN-1099: вступление истории убрано из запуска игры — рассказ о мире
			# остался только в Кодексе («Летопись» → «Вступление»).
			_show_character_select()
	)
	action_box.add_child(start_button)

	var settings_button := _make_button("Настройки")
	settings_button.name = "MainMenuSettingsButton"
	settings_button.pressed.connect(func() -> void:
		_show_settings_menu(SETTINGS_RETURN_MAIN_MENU)
	)
	action_box.add_child(settings_button)

	var version_label := Label.new()
	version_label.name = "MainMenuVersionLabel"
	version_label.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	version_label.add_theme_font_size_override(
		"font_size",
		SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_CAPTION,
			14,
			SemanticTypography.role_min(SemanticTypography.ROLE_CAPTION),
			SemanticTypography.role_max(SemanticTypography.ROLE_CAPTION)
		)
	)
	version_label.add_theme_color_override("font_color", Color(0.847, 0.816, 0.741, 0.93))
	version_label.add_theme_color_override("font_outline_color", Color(0.07, 0.05, 0.07, 0.92))
	version_label.add_theme_constant_override("outline_size", 2)
	version_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(version_label)

	var skill_tree_button := _make_button("Атлас героев")
	skill_tree_button.name = "MainMenuSkillTreeButton"
	skill_tree_button.pressed.connect(_show_atlas_screen)
	action_box.add_child(skill_tree_button)

	# SCRUM-159: «Что нового» с бейджем непросмотренной версии (не модалка).
	var patch_notes_data := preload("res://scripts/patch_notes_data.gd")
	var settings_module := preload("res://scripts/game_settings.gd")
	var last_seen: String = str(settings_module.load_settings().get("last_seen_version", "0.0.0"))
	var patch_notes_button := _make_button("Что нового  ●" if patch_notes_data.has_new_since(last_seen) else "Что нового")
	patch_notes_button.name = "MainMenuPatchNotesButton"
	patch_notes_button.pressed.connect(func() -> void:
		# Просмотр отмечает актуальную версию как увиденную — бейдж гаснет.
		var saved: Dictionary = settings_module.load_settings()
		saved["last_seen_version"] = patch_notes_data.latest_version()
		settings_module.save_settings(saved)
		_show_patch_notes_screen()
	)
	action_box.add_child(patch_notes_button)

	var codex_button := _make_button("Кодекс")
	codex_button.name = "MainMenuCodexButton"
	codex_button.pressed.connect(_show_codex_screen)
	action_box.add_child(codex_button)
	var main_codex_badge: TextureRect = codex_unlock_presenter.add_unread_badge(codex_button, "MainMenuCodexUnreadBadge", 40.0, 52.0)
	main_codex_badge.visible = game.META_PROGRESSION.has_codex_unread(game.meta_state)

	var exit_button := _make_button("Выйти из игры")
	exit_button.name = "MainMenuExitButton"
	exit_button.pressed.connect(_show_quit_confirmation_dialog)
	action_box.add_child(exit_button)
	game.ui_escape_action = _show_quit_confirmation_dialog

	var action_buttons := [
		start_button, settings_button, skill_tree_button, patch_notes_button, codex_button, exit_button,
	]
	# SCRUM-968: озвучка кнопок меню через общий хелпер (ui_click). Живёт рядом со
	# штатными навигационными обработчиками; MainMenuActions остаётся ровно на 6
	# кнопках в одной колонке (контракт SCRUM-1059).
	for menu_button in action_buttons:
		_connect_ui_sfx(menu_button, "click")

	# SCRUM-968: «Благодарности» — player-facing блок атрибуций CC BY (docs/CREDITS.md).
	# Отдельная ссылка НА root (не в MainMenuActions — там контрактные 6 кнопок);
	# позиционируется внутри authored inner rect, то есть после обязательного
	# дополнительного резерва SCRUM-1036 от орнамента золотой рамы.
	var gratitude_glow := TextureRect.new()
	gratitude_glow.name = "MainMenuGratitudeGlow"
	gratitude_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gratitude_glow.stretch_mode = TextureRect.STRETCH_SCALE
	gratitude_glow.texture = _gratitude_glow_texture(0.18)
	gratitude_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(gratitude_glow)

	var credits_button := Button.new()
	credits_button.name = "MainMenuCreditsButton"
	credits_button.text = ""
	var gratitude_source: Texture2D = game._cached_texture(GRATITUDE_ICON_PATH) as Texture2D
	credits_button.icon = _gratitude_alpha_aware_texture(gratitude_source, credits_button)
	credits_button.expand_icon = true
	credits_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits_button.flat = true
	credits_button.focus_mode = Control.FOCUS_ALL
	credits_button.tooltip_text = "Благодарности"
	credits_button.set_meta("accessibility_name", "Благодарности")
	credits_button.set_meta("accessibility_description", "Открыть экран благодарностей")
	UIButtonFamily.assign(credits_button, "credits_icon")
	for credits_state in UIButtonFamily.STATES:
		credits_button.add_theme_stylebox_override(credits_state, _gratitude_button_style(credits_state))
	credits_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	credits_button.pressed.connect(_show_credits_screen)
	root.add_child(credits_button)
	_connect_ui_sfx(credits_button, "click")
	credits_button.mouse_entered.connect(func() -> void:
		gratitude_glow.texture = _gratitude_glow_texture(0.26)
	)
	credits_button.mouse_exited.connect(func() -> void:
		gratitude_glow.texture = _gratitude_glow_texture(0.20 if credits_button.has_focus() else 0.18)
	)
	credits_button.button_down.connect(func() -> void:
		gratitude_glow.texture = _gratitude_glow_texture(0.13)
	)
	credits_button.button_up.connect(func() -> void:
		gratitude_glow.texture = _gratitude_glow_texture(0.20 if credits_button.has_focus() else 0.18)
	)
	credits_button.focus_entered.connect(func() -> void:
		gratitude_glow.texture = _gratitude_glow_texture(0.20)
	)
	credits_button.focus_exited.connect(func() -> void:
		gratitude_glow.texture = _gratitude_glow_texture(0.18)
	)

	_layout_main_menu_gold_shell(root, title_logo, action_box, gratitude_glow, credits_button, version_label, action_buttons)
	root.resized.connect(_layout_main_menu_gold_shell.bind(root, title_logo, action_box, gratitude_glow, credits_button, version_label, action_buttons))
	_wire_main_menu_column_focus(action_buttons, credits_button, start_button)
	# Рама всегда последняя: она видима целиком, а все hitbox остаются в safe rect.
	_unified_add_frame(root, "MainMenu")




# SCRUM-484: координатная спека @2560×1440 — подтверждение выхода (модалка).
# Панель PanelContainer (offset ±300×±170 от центра → 600×340), _panel_style content
# margins (58,72,58,66) → safe-area. Контент: заголовок, подзаголовок, ряд из двух
# кнопок 220×72 (separation 18). Всё помещается внутри safe-area без наслоений.


func _connect_update_manager(manager) -> void:
	_update_presenter = UpdatePresenter.new(self, manager)




func _show_quit_confirmation_dialog() -> void:
	if game.ui_layer == null or not is_instance_valid(game.ui_layer):
		return
	if game.ui_layer.find_child("QuitConfirmationDialog", true, false) != null:
		var existing_cancel := game.ui_layer.find_child("QuitConfirmCancelButton", true, false) as Button
		if existing_cancel != null:
			existing_cancel.grab_focus()
		return

	var overlay := Control.new()
	overlay.name = "QuitConfirmationDialog"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 500
	game.ui_layer.add_child(overlay)
	_prepare_global_tooltips(overlay)

	var dim := ColorRect.new()
	dim.name = "QuitConfirmationDim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.70)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "QuitConfirmationPanel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -300.0
	panel.offset_top = -170.0
	panel.offset_right = 300.0
	panel.offset_bottom = 170.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# SCRUM-883: единый атлас-стиль — модалка подтверждения на плотном кожаном чипе
	# (StyleBoxFlat, латунный кант) вместо per-слот qc_modal @2K-рамки. Кнопки остаются
	# на глобальном ките (нативы quit_220x72 по маппингу имён QuitConfirm*).
	panel.add_theme_stylebox_override("panel", _atlas_chip_style(0.97, roundf(20.0 * _atlas_ui_scale())))
	overlay.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title_label := Label.new()
	title_label.name = "QuitConfirmationTitle"
	title_label.text = "Выйти из игры?"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_TITLE, 34))
	title_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	box.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.name = "QuitConfirmationSubtitle"
	subtitle_label.text = "Несохраненный забег будет завершен. Продолжить выход?"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_CAPTION,
		_readable_font_size(SemanticTypography.ROLE_CAPTION, 16),
		SemanticTypography.role_min(SemanticTypography.ROLE_CAPTION),
		SemanticTypography.role_max(SemanticTypography.ROLE_CAPTION)
	))
	subtitle_label.add_theme_color_override("font_color", Color(0.90, 0.88, 0.78, 1.0))
	box.add_child(subtitle_label)

	var button_row := HBoxContainer.new()
	button_row.name = "QuitConfirmationButtons"
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.custom_minimum_size = Vector2(0.0, 72.0)
	button_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button_row.add_theme_constant_override("separation", 18)
	box.add_child(button_row)

	var confirm_button := _make_button("Выйти")
	confirm_button.name = "QuitConfirmExitButton"
	_set_action_button_size(confirm_button, 220.0, 72.0)
	confirm_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	confirm_button.pressed.connect(func() -> void:
		if game.has_method("request_game_quit"):
			game.request_game_quit()
		else:
			game.get_tree().quit()
	)
	button_row.add_child(confirm_button)

	var cancel_button := _make_button("Отмена")
	cancel_button.name = "QuitConfirmCancelButton"
	_set_action_button_size(cancel_button, 220.0, 72.0)
	cancel_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cancel_button.pressed.connect(_cancel_quit_confirmation_dialog)
	button_row.add_child(cancel_button)

	confirm_button.focus_neighbor_right = cancel_button.get_path()
	confirm_button.focus_neighbor_left = cancel_button.get_path()
	cancel_button.focus_neighbor_left = confirm_button.get_path()
	cancel_button.focus_neighbor_right = confirm_button.get_path()
	# SCRUM-883: замыкаем и вертикаль — стрелки вверх/вниз не должны уводить фокус
	# на кнопки экрана ПОД модалкой (мышь блокирует overlay, клавиатуру — соседи).
	confirm_button.focus_neighbor_top = cancel_button.get_path()
	confirm_button.focus_neighbor_bottom = cancel_button.get_path()
	cancel_button.focus_neighbor_top = confirm_button.get_path()
	cancel_button.focus_neighbor_bottom = confirm_button.get_path()
	cancel_button.grab_focus()

	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if not panel.get_global_rect().has_point((event as InputEventMouseButton).global_position):
				_cancel_quit_confirmation_dialog()
	)
	game.ui_escape_action = _cancel_quit_confirmation_dialog




func _cancel_quit_confirmation_dialog() -> void:
	if game.ui_layer != null and is_instance_valid(game.ui_layer):
		var overlay: Node = game.ui_layer.find_child("QuitConfirmationDialog", true, false)
		if overlay != null:
			overlay.queue_free()
	game.ui_escape_action = _show_quit_confirmation_dialog




func _show_continue_run_dialog() -> void:
	if game.ui_layer == null or not is_instance_valid(game.ui_layer):
		return
	if game.ui_layer.find_child("ContinueRunDialog", true, false) != null:
		var existing_continue := game.ui_layer.find_child("ContinueRunButton", true, false) as Button
		if existing_continue != null:
			existing_continue.grab_focus()
		return

	var autosave_state: Dictionary = game.RUN_AUTOSAVE.load_run()
	if autosave_state.is_empty():
		_show_character_select()
		return

	var overlay := Control.new()
	overlay.name = "ContinueRunDialog"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 520
	game.ui_layer.add_child(overlay)
	_prepare_global_tooltips(overlay)

	var dim := ColorRect.new()
	dim.name = "ContinueRunDim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "ContinueRunPanel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	var panel_size := CR_PANEL_2K.size
	var panel_half_size := panel_size * 0.5
	panel.offset_left = -panel_half_size.x
	panel.offset_top = -panel_half_size.y
	panel.offset_right = panel_half_size.x
	panel.offset_bottom = panel_half_size.y
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# SCRUM-842: cr_panel 9-slice расширен по X под long continue button.
	panel.add_theme_stylebox_override("panel", _overhaul_2k_frame_style("cr_panel", panel_size))
	panel.set_meta("continue_run_slot", "cr_panel")
	var content_margins := _overhaul_2k_content_margins("cr_panel", panel_size)
	panel.set_meta("continue_run_content_margins", content_margins)
	panel.set_meta("continue_run_content_rect", Rect2(
		Vector2(content_margins.x, content_margins.y),
		Vector2(panel_size.x - content_margins.x - content_margins.z, panel_size.y - content_margins.y - content_margins.w)
	))
	overlay.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	# SCRUM-1062: живой title Label вместо отдельного системного Luminari wordmark.
	# До появления общего semantic token API (SCRUM-1061) используем ровно тот же
	# effective theme/default Font, что стандартная title-family (например
	# QuitConfirmationTitle), с локальным fit-safe title tier. Runtime текст остаётся доступным и не
	# растягивается как texture внутри authored content-zone панели.
	var title_label := Label.new()
	title_label.name = "ContinueRunTitle"
	title_label.text = "Продолжить забег?"
	title_label.custom_minimum_size = Vector2(0.0, 70.0)
	title_label.size_flags_horizontal = Control.SIZE_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	title_label.clip_text = false
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.08, 0.035, 0.02, 0.98))
	title_label.add_theme_color_override("font_shadow_color", Color(0.02, 0.01, 0.015, 0.86))
	title_label.add_theme_constant_override("outline_size", 2)
	title_label.add_theme_constant_override("shadow_offset_x", 2)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	title_label.set_meta("semantic_typography_role", "title")
	title_label.set_meta("font_family_contract", "theme_default")
	var refresh_continue_title_typography := func() -> void:
		if not is_instance_valid(title_label):
			return
		# Continue Run keeps the semantic title hierarchy but uses a narrower local
		# fit tier than the wider Quit modal: 29 -> 38/40/42 effective px. This leaves
		# authored reserve for Cyrillic ascenders, outline and shadow inside 70px.
		var title_font_size := _readable_font_size(SemanticTypography.ROLE_TITLE, 29)
		title_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(SemanticTypography.ROLE_TITLE, title_font_size))
		title_label.set_meta("effective_title_font_size", title_font_size)
	refresh_continue_title_typography.call()
	box.add_child(title_label)
	var continue_title_viewport: Viewport = game.get_viewport()
	if continue_title_viewport != null:
		continue_title_viewport.size_changed.connect(refresh_continue_title_typography)
		overlay.tree_exiting.connect(func() -> void:
			if is_instance_valid(continue_title_viewport) and continue_title_viewport.size_changed.is_connected(refresh_continue_title_typography):
				continue_title_viewport.size_changed.disconnect(refresh_continue_title_typography)
		)

	var character_id := str(autosave_state.get("selected_character_id", "berserk"))
	var character_config: Dictionary = game.PROGRESSION_DATA.character_config(character_id)
	var character_title := str(character_config.get("title", character_id))
	var route_stage := int(autosave_state.get("route_stage", 0)) + 1
	var current_act := clampi(int(autosave_state.get("current_act", 1)), 1, game.ACT_COUNT)
	var snapshot: Dictionary = {}
	if autosave_state.get("run_player_snapshot", {}) is Dictionary:
		snapshot = (autosave_state.get("run_player_snapshot", {}) as Dictionary)
	var money := int(snapshot.get("money", 0))
	var level := int(snapshot.get("level", 1))
	var subtitle_label := Label.new()
	subtitle_label.name = "ContinueRunSubtitle"
	subtitle_label.text = "%s · акт %d/%d · этап %d · уровень %d · золото %d\nМожно вернуться на карту или начать новый забег." % [character_title, current_act, game.ACT_COUNT, route_stage, level, money]
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_CAPTION,
		_readable_font_size(SemanticTypography.ROLE_CAPTION, 16),
		SemanticTypography.role_min(SemanticTypography.ROLE_CAPTION),
		SemanticTypography.role_max(SemanticTypography.ROLE_CAPTION)
	))
	subtitle_label.add_theme_color_override("font_color", Color(0.90, 0.88, 0.78, 1.0))
	box.add_child(subtitle_label)

	var button_row := HBoxContainer.new()
	button_row.name = "ContinueRunButtons"
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.custom_minimum_size = Vector2(0.0, CR_BTN_CONTINUE_2K.size.y)
	button_row.add_theme_constant_override("separation", 18)
	box.add_child(button_row)

	var continue_button := _make_button("Продолжить")
	continue_button.name = "ContinueRunButton"
	_set_action_button_size(continue_button, CR_BTN_CONTINUE_2K.size.x, CR_BTN_CONTINUE_2K.size.y)
	_apply_overhaul_2k_button_theme(continue_button, "cr_btn", CR_BTN_CONTINUE_2K.size)
	continue_button.pressed.connect(func() -> void:
		if game.load_run_autosave():
			game.route._show_battle_map()
		else:
			_show_character_select()
	)
	button_row.add_child(continue_button)

	var new_game_button := _make_button("Новая игра")
	new_game_button.name = "ContinueRunNewGameButton"
	_set_action_button_size(new_game_button, 240.0, 72.0)
	_apply_overhaul_2k_button_theme(new_game_button, "cr_btn", CR_BTN_NEWGAME_2K.size)
	new_game_button.pressed.connect(func() -> void:
		game.clear_run_autosave()
		# FAN-1099: вступление истории убрано из запуска игры — рассказ о мире
		# остался только в Кодексе («Летопись» → «Вступление»).
		_show_character_select()
	)
	button_row.add_child(new_game_button)

	continue_button.focus_neighbor_right = new_game_button.get_path()
	continue_button.focus_neighbor_left = new_game_button.get_path()
	new_game_button.focus_neighbor_left = continue_button.get_path()
	new_game_button.focus_neighbor_right = continue_button.get_path()
	continue_button.grab_focus()
	game.ui_escape_action = func() -> void:
		if is_instance_valid(overlay):
			overlay.queue_free()
		game.ui_escape_action = _show_quit_confirmation_dialog
