extends "res://scripts/ui/screens/ui_screens_state.gd"

# FAN-3824: модуль распределённого UI-класса — автогенерируемые forward-объявления кросс-модульных методов (виртуальная диспетчеризация).
# Часть линейной extends-цепочки scripts/ui/screens/** (сборка — фасад
# scripts/ui_screens.gd). Код перенесён из ui_screens.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в ui_screens_shared_api.gd.



func _active_modifiers_snapshot() -> Dictionary:
	return {}


func _active_stats_snapshot() -> Dictionary:
	return {}


func _active_weapon_config() -> Dictionary:
	return {}


func _add_audio_option_row(box: VBoxContainer, title: String, setting_key: String, s := 1.0) -> HBoxContainer:
	return null


func _add_controls_section_header(parent: VBoxContainer, title: String, s := 1.0) -> Label:
	return null


func _add_level_up_badge(content: Control, badge_kind: String, badge_rect: Rect2, base_font_size: int) -> void:
	pass


func _add_result_crest_to_slot(slot: Control, kind: String) -> void:
	pass


func _add_reward_card_content_container(button: Button, elite := false) -> VBoxContainer:
	return null


func _add_screen_background(root: Control, screen_background_id: String) -> void:
	pass


func _add_settings_control_row(parent: VBoxContainer, title: String, control: Control, s := 1.0) -> HBoxContainer:
	return null


func _add_volume_row(box: VBoxContainer, title: String, volume_key: String, enabled_key: String, s := 1.0) -> void:
	pass


func _advance_hero_select_portrait_preview(portrait: TextureRect, preview_state: Dictionary) -> void:
	pass


func _apply_atlas_choice_card_theme(button: Button, pad: float) -> void:
	pass


func _apply_control_rect(control: Control, rect: Rect2) -> void:
	pass


func _apply_fantasy_button_theme(button: Button, variant := "default", explicit_family := "") -> void:
	pass


func _apply_level_up_card_atlas_theme(button: Button, display_size: Vector2, is_rare := false) -> void:
	pass


func _apply_overhaul_2k_button_theme(button: Button, slot: String, display_size: Vector2) -> void:
	pass


func _apply_reward_card_theme(button: Button, elite := false) -> void:
	pass


func _apply_reward_to_active_run(reward: Dictionary) -> void:
	pass


func _apply_reward_to_run(reward: Dictionary) -> void:
	pass


func _apply_slim_action_button_theme(button: Button) -> void:
	pass


func _artifact_affinity_note(definition: Dictionary) -> Dictionary:
	return {}


func _artifact_icon_path(artifact_id: String) -> String:
	return ""


func _artifact_icon_texture(artifact_id: String) -> Texture2D:
	return null


func _artifact_reward_layout_metrics(viewport_size: Vector2) -> Dictionary:
	return {}


func _artifact_reward_presentations(rewards: Array) -> Array:
	return []


func _artifact_tier_color(definition: Dictionary) -> Color:
	return Color()


func _artifact_tier_text(definition: Dictionary) -> String:
	return ""


func _atlas_action_button_height() -> float:
	return 0.0


func _atlas_apply_tab_state() -> void:
	pass


func _atlas_build_canvas() -> void:
	pass


func _atlas_buy_selected() -> void:
	pass


func _atlas_canvas_input(event: InputEvent) -> void:
	pass


func _atlas_card_pad(display_size: Vector2) -> float:
	return 0.0


func _atlas_chip_content_margins(pad: float) -> Vector4:
	return Vector4.ZERO


func _atlas_chip_style(alpha: float, pad: float) -> StyleBoxFlat:
	return null


func _atlas_cycle_tab(_dir: int) -> bool:
	return false


func _atlas_draw_edges() -> void:
	pass


func _atlas_frame_style(margins: Vector4) -> StyleBox:
	return null


func _atlas_refresh() -> void:
	pass


func _atlas_respec_cancel() -> void:
	pass


func _atlas_respec_confirm() -> void:
	pass


func _atlas_respec_prompt() -> void:
	pass


func _atlas_schedule_layout_passes() -> void:
	pass


func _atlas_select_class(class_id: String) -> void:
	pass


func _atlas_socket_scale() -> float:
	return 0.0


func _atlas_switch_tab(tab: String) -> void:
	pass


func _atlas_toggle_keystone() -> void:
	pass


func _atlas_translucent_style(alpha: float, radius: float) -> StyleBoxFlat:
	return null


func _atlas_ui_scale() -> float:
	return 0.0


func _atlas_wire_focus(seed_initial_focus := false) -> void:
	pass


func _attribute_influence_text(stat_id: String) -> String:
	return ""


func _attribute_upgrade_preview_lines(stat_id: String, delta := 1.0, max_lines := 4) -> Array:
	return []


func _bar_style(background: Color) -> StyleBoxFlat:
	return null


func _battle_reward_card_size() -> Vector2:
	return Vector2.ZERO


func _battle_reward_card_size_for_viewport(viewport_size: Vector2) -> Vector2:
	return Vector2.ZERO


func _begin_gamepad_rebind(action_name: String) -> void:
	pass


func _begin_rebind(action_name: String) -> void:
	pass


func _binding_text(action_name: String) -> String:
	return ""


func _build_codex_artifacts(list: VBoxContainer) -> void:
	pass


func _build_codex_ascensions(list: VBoxContainer) -> void:
	pass


func _build_codex_characters(list: VBoxContainer) -> void:
	pass


func _build_codex_chronicle(list: VBoxContainer) -> void:
	pass


func _build_codex_monsters(list: VBoxContainer) -> void:
	pass


func _build_codex_stats(list: VBoxContainer, stat_type: String) -> void:
	pass


func _button_asset_type(button: Button, variant := "default") -> String:
	return ""


func _buy_shop_item_at(index: int) -> bool:
	return false


func _can_open_pause_dossier() -> bool:
	return false


func _clear_current_shop_stock() -> void:
	pass


func _codex_add_entry_name(row: HBoxContainer, display_name: String) -> Label:
	return null


func _codex_artifact_locked(definition: Dictionary) -> bool:
	return false


func _codex_artifact_sections(artifact: Dictionary, definition: Dictionary, locked := false) -> Array:
	return []


func _codex_artifact_unlock_condition(definition: Dictionary) -> String:
	return ""


func _codex_ascension_sections(entry: Dictionary) -> Array:
	return []


func _codex_character_sections(character: Dictionary) -> Array:
	return []


func _codex_entry_panel(list: VBoxContainer, detail_data := {}, unread_refs := []) -> HBoxContainer:
	return null


func _codex_entry_portrait_size() -> Vector2:
	return Vector2.ZERO


func _codex_icon_slot(row: HBoxContainer, texture: Texture2D, size: Vector2, node_name := "CodexPortraitSlot", image_policy := CodexImageFit.POLICY_CONTAIN, source_path := "") -> void:
	pass


func _codex_monster_sections(monster: Dictionary) -> Array:
	return []


func _codex_pl_make_nearest(node: CanvasItem) -> void:
	pass


func _codex_portrait(row: HBoxContainer, sprite_path: String, size: Vector2, image_policy := CodexImageFit.POLICY_CHARACTER) -> Texture2D:
	return null


func _codex_stat_sections(stat: Dictionary) -> Array:
	return []


func _collect_focusable_controls(controls: Array) -> Array[Control]:
	return []


func _configure_event_menu_layout(box: VBoxContainer) -> void:
	pass


func _connect_gamepad_status_signals() -> void:
	pass


func _connect_ui_sfx(button: BaseButton, kind := "click") -> void:
	pass


func _create_damage_flash_overlay(root: Control) -> void:
	pass


func _create_hud() -> void:
	pass


func _create_level_up_menu_box(title: String, subtitle: String, layout := {}) -> Control:
	return null


func _create_low_hp_vignette(root: Control) -> void:
	pass


func _create_menu_box(title: String, subtitle: String, screen_background_id := "", panel_style_override: StyleBox = null, panel_display_size := Vector2.ZERO) -> VBoxContainer:
	return null


func _create_menu_run_hud() -> void:
	pass


func _create_resource_hud_panel(parent: Control, position: Vector2) -> void:
	pass


func _create_result_menu_box(title: String, subtitle: String, screen_background_id: String) -> Dictionary:
	return {}


func _create_threat_indicator_overlay(root: Control) -> void:
	pass


func _current_ui_screen_name() -> String:
	return ""


func _economy_choice_row_gap(display_size: Vector2) -> int:
	return 0


func _economy_menu_panel_half_size(screen_background_id: String) -> Vector2:
	return Vector2.ZERO


func _economy_panel_style() -> StyleBox:
	return null


func _ensure_run_ui_gamepad_bindings() -> void:
	pass


func _ensure_shop_stock_for_current_node() -> void:
	pass


func _event_dialog_metrics() -> Dictionary:
	return {}


func _event_screen_root(box: VBoxContainer) -> Control:
	return null


func _fit_economy_choice_card_content(button: Button) -> void:
	pass


func _gamepad_binding_text(action_name: String) -> String:
	return ""


func _gamepad_glyph_for_action(action_name: String) -> Texture2D:
	return null


func _global_texture_style(path: String, margins: Vector4, tint := Color.WHITE, content := Vector4.ZERO, tile_edges := false) -> StyleBox:
	return null


func _gold_shell_economy_choice_display_size(cards_in_row: int) -> Vector2:
	return Vector2.ZERO


func _gold_shell_economy_choice_display_size_for_viewport(cards_in_row: int, viewport_size: Vector2) -> Vector2:
	return Vector2.ZERO


func _gold_shell_inner_rect_for_size(viewport_size: Vector2) -> Rect2:
	return Rect2()


func _handle_menu_shoulder_nav(dir: int) -> bool:
	return false


func _hs4_apply_wide_control_style(button: Button, display_size: Vector2) -> void:
	pass


func _hs4_ascension_text(level: int) -> String:
	return ""


func _hs4_join_dossier_names(entries: Array) -> String:
	return ""


func _hs4_stat_fill_color(stat_id: String) -> Color:
	return Color()


func _hs4_stat_text_color(stat_id: String) -> Color:
	return Color()


func _hs4_stat_tooltip(stat_id: String, value: float, _character_id: String) -> String:
	return ""


func _hud_v2_bar_fill_style(icon_id: String, fallback_color: Color) -> StyleBox:
	return null


func _hud_v2_bar_track_style(display_size := Vector2(516.0, 32.0), content_inset := 3.0) -> StyleBox:
	return null


func _hud_v2_cluster_style(display_size := Vector2(640.0, 122.0)) -> StyleBox:
	return null


func _input_device_manager() -> Node:
	return null


func _is_economy_screen_background(screen_background_id: String) -> bool:
	return false


func _is_pause_end_screen_background(screen_background_id: String) -> bool:
	return false


func _is_result_screen_background(screen_background_id: String) -> bool:
	return false


func _is_run_pause_overlay_open() -> bool:
	return false


func _layout_combat_hud(root: Control) -> void:
	pass


func _layout_gold_shell_menu_resource_hud(root: Control, inner_rect: Rect2) -> void:
	pass


func _layout_hud_v2_cluster(resource: PanelContainer, panel_rect: Rect2, scale: float) -> void:
	pass


func _layout_level_up_button_in_gold_shell(viewport_size: Vector2) -> void:
	pass


func _layout_menu_resource_hud(root: Control, origin: Vector2) -> void:
	pass


func _layout_shop_gold_shell_resource_hud_current(root: Control) -> void:
	pass


func _level_up_card_description(reward: Dictionary) -> String:
	return ""


func _level_up_card_plan(rewards: Array, advice: Dictionary, layout: Dictionary) -> Dictionary:
	return {}


func _level_up_card_tooltip(reward: Dictionary, forecast: Dictionary, badge_kind: String, advice := {}) -> String:
	return ""


func _level_up_delta_lines(reward: Dictionary, forecast: Dictionary) -> Array:
	return []


func _level_up_detail_drawer_text(reward: Dictionary, forecast: Dictionary, badge_kind: String, advice := {}) -> String:
	return ""


func _level_up_layout_metrics() -> Dictionary:
	return {}


func _level_up_offer_advice(rewards: Array) -> Dictionary:
	return {}


func _level_up_scaled_position(rect: Rect2, scale: Vector2) -> Vector2:
	return Vector2.ZERO


func _level_up_scaled_size(rect: Rect2, scale: Vector2) -> Vector2:
	return Vector2.ZERO


func _make_battle_reward_card(reward: Dictionary) -> Button:
	return null


func _make_button(text: String) -> Button:
	return null


func _make_economy_choice_card(title: String, description: String, action_text: String, button_name: String, display_size: Vector2) -> Button:
	return null


func _make_economy_choice_row(row_name: String, display_size := Vector2.ZERO, cards_in_row := 3) -> HBoxContainer:
	return null


func _make_elite_artifact_card(reward: Dictionary, presentation := {}) -> Button:
	return null


func _make_hud_v2_icon(icon_id: String) -> TextureRect:
	return null


func _make_level_up_reward_button(reward: Dictionary, layout := {}, advice := {}, reward_index := -1) -> Button:
	return null


func _make_settings_game_tab(s: float, column_w: float, viewport_size: Vector2) -> MarginContainer:
	return null


func _make_settings_tab(tab_name: String, s := 1.0, column_w := 0.0) -> MarginContainer:
	return null


func _make_settings_tab_switcher(tabs: TabContainer, _s: float) -> Control:
	return null


func _minimal_metal_frame_style(frame_type: String, tint := Color.WHITE) -> StyleBox:
	return null


func _number_value(value, fallback: float = 0.0) -> float:
	return 0.0


func _on_player_leveled_up() -> void:
	pass


func _overhaul_2k_content_margins(slot: String, display_size: Vector2) -> Vector4:
	return Vector4.ZERO


func _overhaul_2k_frame_style(slot: String, display_size: Vector2, tint := Color.WHITE) -> StyleBox:
	return null


func _panel_style() -> StyleBox:
	return null


func _pause_end_modal_content_margins(display_size: Vector2, screen_background_id: String) -> Vector4:
	return Vector4.ZERO


func _pause_end_modal_content_rect(display_size: Vector2, screen_background_id: String) -> Rect2:
	return Rect2()


func _pause_end_modal_display_size(screen_background_id: String) -> Vector2:
	return Vector2.ZERO


func _pause_end_modal_display_size_for_viewport(screen_background_id: String, viewport_size: Vector2) -> Vector2:
	return Vector2.ZERO


func _pause_end_modal_style(display_size: Vector2, screen_background_id := "") -> StyleBox:
	return null


func _pause_end_result_button_height() -> float:
	return 0.0


func _pause_end_result_button_width(screen_background_id: String) -> float:
	return 0.0


func _player_artifact_count() -> int:
	return 0


func _prepare_global_tooltips(root: Control) -> void:
	pass


func _random_level_up_rewards(count: int) -> Array:
	return []


func _random_rewards(count: int) -> Array:
	return []


func _random_shop_items(count: int) -> Array:
	return []


func _readable_font_size(role: StringName, base_size: int, min_size := 0, max_size := 96) -> int:
	return 0


func _refresh_artifact_hud_row() -> void:
	pass


func _refresh_gamepad_status_line() -> void:
	pass


func _reset_audio_to_defaults() -> void:
	pass


func _reset_gamepad_bindings_to_defaults() -> void:
	pass


func _reset_input_bindings_to_defaults() -> void:
	pass


func _resize_elite_artifact_card(button: Button, display_size: Vector2) -> void:
	pass


func _resize_reward_card(button: Button, display_size: Vector2) -> void:
	pass


func _return_from_level_up_to_event() -> void:
	pass


func _reward_icon_id(reward: Dictionary) -> String:
	return ""


func _run_ascension_level() -> int:
	return 0


func _run_cross_class_artifact_ids() -> Array:
	return []


func _run_money() -> int:
	return 0


func _scaled_frame_margins(source_size: Vector2, display_size: Vector2, source_margins: Vector4) -> Vector4:
	return Vector4.ZERO


func _scaled_frame_margins_xy(source_size: Vector2, display_size: Vector2, source_margins: Vector4) -> Vector4:
	return Vector4.ZERO


func _screen_background_texture(screen_background_id: String) -> Texture2D:
	return null


func _scrum666_content_margins(frame_rect: Rect2, zone_rect: Rect2, scale: float) -> Vector4:
	return Vector4.ZERO


func _scrum666_hud_scale_for_size(viewport_size: Vector2) -> float:
	return 0.0


func _scrum666_scaled_rect(base_rect: Rect2, scale: float) -> Rect2:
	return Rect2()


func _set_action_button_size(button: Button, width := STANDARD_ACTION_BUTTON_WIDTH, height := STANDARD_ACTION_BUTTON_HEIGHT) -> void:
	pass


func _set_hero_select_portrait_preview(portrait: TextureRect, character_id: String, config: Dictionary, preview_state: Dictionary) -> void:
	pass


func _settings_fit_kit_row(row_buttons: Array, button_width: float, button_height: float, side_pad := 0.0, fit_ratio := 1.0, fixed_font_size := 0) -> void:
	pass


func _settings_seamless_content_style(pad: float) -> StyleBoxFlat:
	return null


func _settings_v6_apply_field_theme(button: Button, s: float) -> void:
	pass


func _settings_v6_font(role: StringName, design_px: float, s: float) -> int:
	return 0


func _settings_v6_icon(path: String, design_size: Vector2, s: float) -> Texture2D:
	return null


func _settings_v6_make_action_button(text: String, button_name: String, width: float, height: float) -> Button:
	return null


func _settings_v6_style_audio_scrollbar(scroll: ScrollContainer, s: float) -> void:
	pass


func _settings_v6_style_checkbox(toggle: CheckBox, s: float) -> void:
	pass


func _settings_v6_style_slider(slider: HSlider, s: float) -> void:
	pass


func _settings_v6_texture_box(path: String, source_margins: Vector4, content: Vector4) -> StyleBox:
	return null


func _shop_gold_shell_metrics(viewport_size: Vector2) -> Dictionary:
	return {}


func _show_atlas_screen() -> void:
	pass


func _show_character_select() -> void:
	pass


func _show_codex_screen() -> void:
	pass


func _show_codex_section(content: PanelContainer, section_id: String) -> void:
	pass


func _show_credits_screen() -> void:
	pass


func _show_death_screen(reason := "") -> void:
	pass


func _show_event_screen(route_node: Dictionary) -> void:
	pass


func _show_level_up_screen(return_to_map := false) -> void:
	pass


func _show_main_menu() -> void:
	pass


func _show_patch_notes_screen() -> void:
	pass


func _show_pause_menu(force := false) -> void:
	pass


func _show_settings_menu(requested_return_origin := "") -> void:
	pass


func _show_shop_screen() -> void:
	pass


func _show_weapon_select() -> void:
	pass


func _shrink_label_font_to_width(label: Label, role: StringName, base_font_size: int, max_width: float, min_font_size := 12, fit_ratio := 0.62) -> void:
	pass


func _start_level_up_intro(panel: Node, title_label: Node, reward_buttons: Array, sparkle_root: Node) -> void:
	pass


func _text_button_unique_id(button: Button) -> String:
	return ""


func _timer_panel_style(alarm: bool, display_size := Vector2(264.0, 92.0), content_margins := Vector4.ZERO) -> StyleBox:
	return null


func _unified_add_background(root: Control, screen_id: String, shade_alpha := 0.0) -> void:
	pass


func _unified_add_divider(parent: Control, s: float, name_suffix := "") -> void:
	pass


func _unified_add_frame(root: Control, prefix: String) -> Panel:
	return null


func _unified_apply_row_theme(button: Button, pad := 10.0, selected := false) -> void:
	pass


func _unified_header_chip(prefix: String, title: String, screen_id: String, s: float) -> PanelContainer:
	return null


func _unified_make_safe_area(root: Control, prefix: String) -> MarginContainer:
	return null


func _unified_safe_margins() -> Vector4:
	return Vector4.ZERO


func _unified_safe_margins_for_size(viewport_size: Vector2) -> Vector4:
	return Vector4.ZERO


func _unified_safe_rect() -> Rect2:
	return Rect2()


func _unified_safe_rect_for_size(viewport_size: Vector2) -> Rect2:
	return Rect2()


func _update_boss_hud_bar() -> void:
	pass


func _update_hud() -> void:
	pass


func _update_level_up_button() -> void:
	pass


func _wire_main_menu_column_focus(buttons: Array, gratitude: Control, initial: Control = null) -> void:
	pass


func _wire_run_ui_focus(primary: Array, axis_h: bool, secondary: Array = [], initial: Control = null) -> void:
	pass


func _wire_settings_game_focus(tabs: TabContainer, game_tab: Control, compact: bool) -> void:
	pass
