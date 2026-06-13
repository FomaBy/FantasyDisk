class_name UIThemePaths
extends RefCounted

const DF_FRAME_DIR := "res://assets/sprites/ui/frames/dark_fantasy/"
const GLOBAL_PANEL_FRAME_PATH := DF_FRAME_DIR + "ui_df_panel_frame.png"
const GLOBAL_BUTTON_FRAME_PATH := DF_FRAME_DIR + "ui_df_button_secondary_idle.png"
const GLOBAL_CARD_FRAME_PATH := DF_FRAME_DIR + "ui_df_card_frame.png"
const GLOBAL_LEVEL_PANEL_FRAME_PATH := DF_FRAME_DIR + "ui_df_level_panel_frame.png"
const GLOBAL_HUD_PANEL_FRAME_PATH := DF_FRAME_DIR + "ui_df_hud_panel_frame.png"
const GLOBAL_HUD_CARD_FRAME_PATH := DF_FRAME_DIR + "ui_df_hud_card_frame.png"
const GLOBAL_TOOLTIP_FRAME_PATH := DF_FRAME_DIR + "ui_df_tooltip_frame.png"

const DF_BUTTON_TEXTURES := {
	"primary": {
		"normal": DF_FRAME_DIR + "ui_df_button_primary_idle.png",
		"hover": DF_FRAME_DIR + "ui_df_button_primary_hover.png",
		"pressed": DF_FRAME_DIR + "ui_df_button_primary_pressed.png",
		"disabled": DF_FRAME_DIR + "ui_df_button_primary_disabled.png",
	},
	"secondary": {
		"normal": DF_FRAME_DIR + "ui_df_button_secondary_idle.png",
		"hover": DF_FRAME_DIR + "ui_df_button_secondary_hover.png",
		"pressed": DF_FRAME_DIR + "ui_df_button_secondary_pressed.png",
		"disabled": DF_FRAME_DIR + "ui_df_button_secondary_disabled.png",
	},
	"danger": {
		"normal": DF_FRAME_DIR + "ui_df_button_danger_idle.png",
		"hover": DF_FRAME_DIR + "ui_df_button_danger_hover.png",
		"pressed": DF_FRAME_DIR + "ui_df_button_danger_pressed.png",
		"disabled": DF_FRAME_DIR + "ui_df_button_danger_disabled.png",
	},
}
