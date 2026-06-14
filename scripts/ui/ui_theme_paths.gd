class_name UIThemePaths
extends RefCounted

const DF_FRAME_DIR := "res://assets/sprites/ui/frames/dark_fantasy/"
const RED_GOLD_BUTTON_DIR := "res://assets/sprites/ui/frames/red_gold/"
const ORNATE_FRAME_DIR := "res://assets/sprites/ui/frames/ornate/"
const GLOBAL_PANEL_FRAME_PATH := ORNATE_FRAME_DIR + "ui_frame_ornate_global_panel.png"
const GLOBAL_BUTTON_FRAME_PATH := RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_standard.png"
const GLOBAL_CARD_FRAME_PATH := ORNATE_FRAME_DIR + "ui_frame_ornate_card_frame.png"
const GLOBAL_HERO_CARD_FRAME_PATH := ORNATE_FRAME_DIR + "ui_frame_ornate_hero_card.png"
const GLOBAL_CARD_HOVER_FRAME_PATH := ORNATE_FRAME_DIR + "ui_frame_ornate_card_hover.png"
const GLOBAL_LEVEL_PANEL_FRAME_PATH := ORNATE_FRAME_DIR + "ui_frame_ornate_level_panel.png"
const GLOBAL_HUD_PANEL_FRAME_PATH := ORNATE_FRAME_DIR + "ui_frame_ornate_hud_panel.png"
const GLOBAL_HUD_CARD_FRAME_PATH := ORNATE_FRAME_DIR + "ui_frame_ornate_hud_card.png"
const GLOBAL_TOOLTIP_FRAME_PATH := ORNATE_FRAME_DIR + "ui_frame_ornate_tooltip.png"
const GLOBAL_TIMER_PANEL_FRAME_PATH := ORNATE_FRAME_DIR + "ui_frame_ornate_timer_panel.png"

const ORNATE_FRAME_MARGINS := {
	"global_panel": Vector4(34, 34, 34, 34),
	"level_panel": Vector4(46, 46, 46, 46),
	"card_frame": Vector4(28, 28, 28, 28),
	"hero_card": Vector4(28, 28, 28, 28),
	"card_hover": Vector4(30, 30, 30, 30),
	"tooltip": Vector4(26, 26, 26, 26),
	"hud_panel": Vector4(28, 22, 28, 24),
	"hud_card": Vector4(22, 18, 22, 20),
	"timer_panel": Vector4(34, 24, 34, 24),
	"pause_main": Vector4(40, 40, 40, 40),
	"pause_stat_group": Vector4(34, 30, 34, 34),
	"pause_stat_chip": Vector4(20, 12, 20, 14),
	"pause_stat_tooltip": Vector4(34, 30, 34, 34),
}

const ORNATE_FRAME_CONTENT := {
	"global_panel": Vector4(28, 26, 28, 26),
	"level_panel": Vector4(34, 30, 34, 30),
	"card_frame": Vector4(7, 7, 7, 7),
	"hero_card": Vector4(8, 8, 8, 8),
	"card_hover": Vector4(16, 14, 16, 14),
	"tooltip": Vector4(14, 12, 14, 12),
	"hud_panel": Vector4(10, 9, 10, 9),
	"hud_card": Vector4(8, 7, 8, 7),
	"timer_panel": Vector4(14, 4, 14, 4),
	"pause_main": Vector4(24, 24, 24, 24),
	"pause_stat_group": Vector4(14, 12, 14, 14),
	"pause_stat_chip": Vector4(8, 4, 8, 4),
	"pause_stat_tooltip": Vector4(18, 16, 18, 16),
}

const RED_GOLD_BUTTON_TYPES := [
	"standard",
	"max",
	"main_menu",
	"hero_confirm",
	"reset_audio",
	"reset_bindings",
	"codex_tab",
	"back_s",
	"back_m",
	"back_l",
	"attr_selector",
	"fab",
	"utility",
	"pause",
	"rebind",
]

const RED_GOLD_BUTTON_TEXTURES := {
	"standard": {
		"normal": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_standard.png",
		"hover": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_standard_hover.png",
		"pressed": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_standard_pressed.png",
		"disabled": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_standard_disabled.png",
	},
	"max": {
		"normal": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_max.png",
		"hover": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_max_hover.png",
		"pressed": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_max_pressed.png",
		"disabled": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_max_disabled.png",
	},
	"main_menu": {
		"normal": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_main_menu.png",
		"hover": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_main_menu_hover.png",
		"pressed": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_main_menu_pressed.png",
		"disabled": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_main_menu_disabled.png",
	},
	"hero_confirm": {
		"normal": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_hero_confirm.png",
		"hover": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_hero_confirm_hover.png",
		"pressed": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_hero_confirm_pressed.png",
		"disabled": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_hero_confirm_disabled.png",
	},
	"reset_audio": {
		"normal": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_reset_audio.png",
		"hover": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_reset_audio_hover.png",
		"pressed": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_reset_audio_pressed.png",
		"disabled": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_reset_audio_disabled.png",
	},
	"reset_bindings": {
		"normal": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_reset_bindings.png",
		"hover": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_reset_bindings_hover.png",
		"pressed": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_reset_bindings_pressed.png",
		"disabled": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_reset_bindings_disabled.png",
	},
	"codex_tab": {
		"normal": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_codex_tab.png",
		"hover": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_codex_tab_hover.png",
		"pressed": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_codex_tab_pressed.png",
		"disabled": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_codex_tab_disabled.png",
	},
	"back_s": {
		"normal": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_back_s.png",
		"hover": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_back_s_hover.png",
		"pressed": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_back_s_pressed.png",
		"disabled": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_back_s_disabled.png",
	},
	"back_m": {
		"normal": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_back_m.png",
		"hover": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_back_m_hover.png",
		"pressed": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_back_m_pressed.png",
		"disabled": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_back_m_disabled.png",
	},
	"back_l": {
		"normal": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_back_l.png",
		"hover": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_back_l_hover.png",
		"pressed": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_back_l_pressed.png",
		"disabled": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_back_l_disabled.png",
	},
	"attr_selector": {
		"normal": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_attr_selector.png",
		"hover": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_attr_selector_hover.png",
		"pressed": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_attr_selector_pressed.png",
		"disabled": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_attr_selector_disabled.png",
	},
	"fab": {
		"normal": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_fab.png",
		"hover": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_fab_hover.png",
		"pressed": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_fab_pressed.png",
		"disabled": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_fab_disabled.png",
	},
	"utility": {
		"normal": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_utility.png",
		"hover": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_utility_hover.png",
		"pressed": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_utility_pressed.png",
		"disabled": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_utility_disabled.png",
	},
	"pause": {
		"normal": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_pause.png",
		"hover": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_pause_hover.png",
		"pressed": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_pause_pressed.png",
		"disabled": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_pause_disabled.png",
	},
	"rebind": {
		"normal": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_rebind.png",
		"hover": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_rebind_hover.png",
		"pressed": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_rebind_pressed.png",
		"disabled": RED_GOLD_BUTTON_DIR + "ui_btn_red_gold_rebind_disabled.png",
	},
}

const RED_GOLD_BUTTON_MARGINS := {
	"standard": Vector4(84, 30, 84, 32),
	"max": Vector4(90, 30, 90, 32),
	"main_menu": Vector4(84, 30, 84, 32),
	"hero_confirm": Vector4(78, 30, 78, 32),
	"reset_audio": Vector4(84, 30, 84, 32),
	"reset_bindings": Vector4(86, 30, 86, 32),
	"codex_tab": Vector4(58, 30, 58, 32),
	"back_s": Vector4(58, 30, 58, 32),
	"back_m": Vector4(74, 30, 74, 32),
	"back_l": Vector4(84, 30, 84, 32),
	"attr_selector": Vector4(92, 30, 92, 32),
	"fab": Vector4(18, 18, 18, 18),
	"utility": Vector4(18, 14, 18, 14),
	"pause": Vector4(68, 20, 68, 20),
	"rebind": Vector4(82, 20, 82, 20),
}

const RED_GOLD_BUTTON_CONTENT := {
	"standard": Vector4(76, 14, 76, 14),
	"max": Vector4(82, 14, 82, 14),
	"main_menu": Vector4(76, 14, 76, 14),
	"hero_confirm": Vector4(54, 14, 54, 14),
	"reset_audio": Vector4(76, 14, 76, 14),
	"reset_bindings": Vector4(78, 14, 78, 14),
	"codex_tab": Vector4(50, 14, 50, 14),
	"back_s": Vector4(50, 14, 50, 14),
	"back_m": Vector4(66, 14, 66, 14),
	"back_l": Vector4(76, 14, 76, 14),
	"attr_selector": Vector4(82, 14, 82, 14),
	"fab": Vector4(8, 8, 8, 8),
	"utility": Vector4(8, 6, 8, 6),
	"pause": Vector4(56, 8, 56, 8),
	"rebind": Vector4(72, 8, 72, 8),
}
