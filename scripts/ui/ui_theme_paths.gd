class_name UIThemePaths
extends RefCounted

const DF_FRAME_DIR := "res://assets/sprites/ui/frames/dark_fantasy/"
const RED_GOLD_BUTTON_DIR := "res://assets/sprites/ui/frames/red_gold/"
const MINIMAL_METAL_BUTTON_DIR := "res://assets/sprites/ui/frames/minimal_metal_buttons/"
const TEXT_BUTTON_UNIQUE_DIR := "res://assets/sprites/ui/frames/text_buttons_unique/"
const ORNATE_FRAME_DIR := "res://assets/sprites/ui/frames/ornate/"
const UNIFIED_FRAME_DIR := "res://assets/sprites/ui/frames/unified/"
const MINIMAL_METAL_FRAME_DIR := "res://assets/sprites/ui/frames/minimal_metal/"
const MINIMAL_METAL_MODAL_PATH := MINIMAL_METAL_FRAME_DIR + "ui_frame_minimal_metal_modal.png"
const MINIMAL_METAL_PANEL_PATH := MINIMAL_METAL_FRAME_DIR + "ui_frame_minimal_metal_panel.png"
const MINIMAL_METAL_CARD_PATH := MINIMAL_METAL_FRAME_DIR + "ui_frame_minimal_metal_card.png"
const MINIMAL_METAL_TOOLTIP_PATH := MINIMAL_METAL_FRAME_DIR + "ui_frame_minimal_metal_tooltip.png"
const MINIMAL_METAL_HUD_STRIP_PATH := MINIMAL_METAL_FRAME_DIR + "ui_frame_minimal_metal_hud_strip.png"
const MINIMAL_METAL_FIELD_PATH := MINIMAL_METAL_FRAME_DIR + "ui_frame_minimal_metal_field.png"
const MINIMAL_METAL_FRAME_PATHS := {
	"modal": MINIMAL_METAL_MODAL_PATH,
	"panel": MINIMAL_METAL_PANEL_PATH,
	"card": MINIMAL_METAL_CARD_PATH,
	"tooltip": MINIMAL_METAL_TOOLTIP_PATH,
	"hud_strip": MINIMAL_METAL_HUD_STRIP_PATH,
	"field": MINIMAL_METAL_FIELD_PATH,
}
const MINIMAL_METAL_FRAME_SOURCE_SIZE := {
	"modal": Vector2(986, 900),
	"panel": Vector2(782, 716),
	"card": Vector2(426, 486),
	"tooltip": Vector2(760, 242),
	"hud_strip": Vector2(1122, 288),
	"field": Vector2(616, 286),
}
const MINIMAL_METAL_FRAME_TEXTURE_MARGINS := {
	"modal": Vector4(46, 62, 46, 58),
	"panel": Vector4(38, 52, 38, 48),
	"card": Vector4(32, 42, 32, 40),
	"tooltip": Vector4(46, 30, 46, 28),
	"hud_strip": Vector4(76, 42, 76, 40),
	"field": Vector4(42, 38, 42, 36),
	# SCRUM-564: тонкие боевые HUD-стрипы — узкие верт. бордюры, чтобы остался плоский центр
	# и панель не вырастала за свой слот (resource ≤84, иначе наезжает на CharacterStatsHud).
	"hud_resource": Vector4(60, 16, 60, 16),
	"hud_timer": Vector4(56, 22, 56, 22),
	"hud_artifact": Vector4(60, 24, 60, 24),
	"combat_title_big": Vector4(70, 20, 70, 20),
	"combat_title_small": Vector4(56, 12, 56, 12),
	"victory_banner": Vector4(84, 44, 84, 44),
}
const MINIMAL_METAL_FRAME_CONTENT := {
	"modal": Vector4(72, 92, 72, 84),
	"panel": Vector4(58, 72, 58, 66),
	"card": Vector4(46, 58, 46, 54),
	"tooltip": Vector4(66, 44, 66, 40),
	"hud_strip": Vector4(104, 62, 104, 56),
	"field": Vector4(58, 52, 58, 48),
}
const MINIMAL_METAL_FRAME_SAFE_RECTS := {
	"modal": Rect2(72, 92, 842, 724),
	"panel": Rect2(58, 72, 666, 578),
	"card": Rect2(46, 58, 334, 374),
	"tooltip": Rect2(66, 44, 628, 158),
	"hud_strip": Rect2(104, 62, 914, 170),
	"field": Rect2(58, 52, 500, 186),
}

# SCRUM-486 (эпик SCRUM-481 UI Overhaul 2K): per-слот @2K-ассеты блока Меню/Навигация,
# сгенерированы рисующим скриптом tools/build_ui_2k_frame_kit.py (SCRUM-485) РОВНО в
# пиксельный размер слота из координатной спеки SCRUM-484. В отличие от общих
# minimal_metal-фреймов (которые ужимались под слот и мылили орнамент), эти нарисованы
# 1:1 под слот с нативными 9-slice бордюрами → при рантайм-9-slice тянется только плоская
# середина, орнамент резкий на 1080p/2K/4K. SOURCE_SIZE = фактический размер PNG;
# TEXTURE_MARGINS = тот же margin-профиль, которым их рисовал генератор (frame: panel/
# modal/tooltip из MINIMAL_METAL_FRAME_TEXTURE_MARGINS; button: main_menu/standard/pause
# из MINIMAL_METAL_BUTTON_MARGINS) — единый источник, anti-drift сверяется в --verify.
const OVERHAUL_2K_FRAME_DIR := "res://assets/sprites/ui/frames/overhaul_2k/"
const LEVEL_UP_SCRUM682_FRAME_DIR := "res://assets/sprites/ui/frames/level_up_scrum682/"
const LEVEL_UP_SCRUM682_FRAME_PATHS := {
	"panel": LEVEL_UP_SCRUM682_FRAME_DIR + "ui_frame_lu682_panel.png",
	"card": LEVEL_UP_SCRUM682_FRAME_DIR + "ui_frame_lu682_card.png",
	"card_hover": LEVEL_UP_SCRUM682_FRAME_DIR + "ui_frame_lu682_card_hover.png",
	"card_selected": LEVEL_UP_SCRUM682_FRAME_DIR + "ui_frame_lu682_card_selected.png",
	"portrait": LEVEL_UP_SCRUM682_FRAME_DIR + "ui_frame_lu682_portrait.png",
	"effect_preview": LEVEL_UP_SCRUM682_FRAME_DIR + "ui_frame_lu682_effect_preview.png",
	"later_button": LEVEL_UP_SCRUM682_FRAME_DIR + "ui_btn_lu682_later.png",
	"later_button_hover": LEVEL_UP_SCRUM682_FRAME_DIR + "ui_btn_lu682_later_hover.png",
	"later_button_pressed": LEVEL_UP_SCRUM682_FRAME_DIR + "ui_btn_lu682_later_pressed.png",
	# SCRUM-871: риббон-бейджи рекомендаций (PixelLab, textless — подпись рантаймом).
	"badge_dps": LEVEL_UP_SCRUM682_FRAME_DIR + "ui_badge_lu_best_dps.png",
	"badge_surv": LEVEL_UP_SCRUM682_FRAME_DIR + "ui_badge_lu_best_surv.png",
	"badge_both": LEVEL_UP_SCRUM682_FRAME_DIR + "ui_badge_lu_best_both.png",
}
const OVERHAUL_2K_FRAME_PATHS := {
	"qc_panel": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_qc_panel.png",
	"cr_panel": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_cr_panel.png",
	"rc_panel": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_rc_panel.png",
	"pm_panel": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_pm_panel.png",
	"fb_panel": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_fb_panel.png",
	"pd_panel": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_pd_panel.png",
	"gt_panel": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_gt_panel.png",
	"st_panel": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_st_panel.png",
	"stat_tooltip": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_stat_tooltip.png",
	"evt_panel": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_evt_panel.png",
	"evt_card": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_evt_card.png",
	"level_up_panel": LEVEL_UP_SCRUM682_FRAME_PATHS["panel"],
	"level_up_card": LEVEL_UP_SCRUM682_FRAME_PATHS["card"],
	"upgrade_panel": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_upgrade_panel.png",
	"ws_panel": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_ws_panel.png",
	"ws_card": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_ws_card.png",
	"ws_btn_back": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_ws_btn_back.png",
	"result_panel": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_result_panel.png",
	"qc_modal": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_qc_modal.png",
	"chud_resource_panel": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_chud_resource_panel.png",
	"chud_timer": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_chud_timer.png",
	"chud_artifact_row": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_chud_artifact_row.png",
	"lut_toast": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_lut_toast.png",
	"ctb_big": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_ctb_big.png",
	"ctb_small": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_ctb_small.png",
	"vbn_frame": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_vbn_frame.png",
	"hs4_portrait_panel": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_hs4_portrait_panel.png",
	"hs4_dossier_panel": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_hs4_dossier_panel.png",
	"hs4_radar_panel": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_hs4_radar_panel.png",
	"hs4_carousel_panel": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_hs4_carousel_panel.png",
	"hs4_choose_btn": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_hs4_choose_btn.png",
	"hs4_asc_btn": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_hs4_asc_btn.png",
	"attr_panel": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_attr_panel.png",
	"pn_panel": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_pn_panel.png",
	"codex_main": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_codex_main.png",
	"codex_nav": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_codex_nav.png",
	"codex_list": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_codex_list.png",
	"codex_detail": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_codex_detail.png",
	"codex_entry_card": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_codex_entry_card.png",
	"codex_tab_btn": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_codex_tab_btn.png",
	"codex_back_btn": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_codex_back_btn.png",
	"mm_btn": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_mm_btn.png",
	"qc_btn": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_qc_btn.png",
	"cr_btn": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_cr_btn.png",
	"rc_btn": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_rc_btn.png",
	"pm_btn": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_pm_btn.png",
	"fb_btn_send": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_fb_btn_send.png",
	"fb_btn_cancel": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_fb_btn_cancel.png",
	"pd_btn": OVERHAUL_2K_FRAME_DIR + "ui_frame_2k_pd_btn.png",
}
const OVERHAUL_2K_FRAME_SOURCE_SIZE := {
	"qc_panel": Vector2(600, 340),
	"cr_panel": Vector2(680, 380),
	"rc_panel": Vector2(680, 380),
	"pm_panel": Vector2(898, 820),
	"fb_panel": Vector2(940, 780),
	"pd_panel": Vector2(2520, 1404),
	"gt_panel": Vector2(460, 140),
	"st_panel": Vector2(430, 220),
	"stat_tooltip": Vector2(430, 288),
	"evt_panel": Vector2(1720, 780),
	"evt_card": Vector2(480, 340),
	"level_up_panel": Vector2(1720, 1040),
	"level_up_card": Vector2(470, 560),
	"upgrade_panel": Vector2(1720, 730),
	"ws_panel": Vector2(1720, 1060),
	"ws_card": Vector2(1564, 190),
	"ws_btn_back": Vector2(280, 60),
	"result_panel": Vector2(898, 820),
	"qc_modal": Vector2(600, 340),
	"chud_resource_panel": Vector2(820, 84),
	"chud_timer": Vector2(288, 96),
	"chud_artifact_row": Vector2(402, 104),
	"lut_toast": Vector2(480, 300),
	"ctb_big": Vector2(2360, 90),
	"ctb_small": Vector2(2360, 56),
	"vbn_frame": Vector2(1440, 240),
	"hs4_portrait_panel": Vector2(661, 959),
	"hs4_dossier_panel": Vector2(1091, 959),
	"hs4_radar_panel": Vector2(624, 959),
	"hs4_carousel_panel": Vector2(2448, 245),
	"hs4_choose_btn": Vector2(512, 89),
	"hs4_asc_btn": Vector2(102, 72),
	"attr_panel": Vector2(1124, 1384),
	"pn_panel": Vector2(2464, 1388),
	"codex_main": Vector2(2496, 1387),
	"codex_nav": Vector2(405, 1163),
	"codex_list": Vector2(1113, 1163),
	"codex_detail": Vector2(808, 1163),
	"codex_entry_card": Vector2(963, 147),
	"codex_tab_btn": Vector2(333, 115),
	"codex_back_btn": Vector2(168, 128),
	"mm_btn": Vector2(380, 104),
	"qc_btn": Vector2(220, 72),
	"cr_btn": Vector2(240, 72),
	"rc_btn": Vector2(240, 72),
	"pm_btn": Vector2(280, 60),
	"fb_btn_send": Vector2(260, 64),
	"fb_btn_cancel": Vector2(220, 64),
	"pd_btn": Vector2(280, 60),
}
# 9-slice бордюры: frame-слоты наследуют профиль panel/modal/tooltip, button-слоты —
# main_menu/standard/pause (см. SLOTS-таблицу build_ui_2k_frame_kit.py).
const OVERHAUL_2K_FRAME_TEXTURE_MARGINS := {
	"qc_panel": Vector4(38, 52, 38, 48),
	"cr_panel": Vector4(38, 52, 38, 48),
	"rc_panel": Vector4(38, 52, 38, 48),
	"pm_panel": Vector4(38, 52, 38, 48),
	"fb_panel": Vector4(38, 52, 38, 48),
	"pd_panel": Vector4(46, 62, 46, 58),
	"gt_panel": Vector4(46, 30, 46, 28),
	"st_panel": Vector4(46, 30, 46, 28),
	"stat_tooltip": Vector4(32, 32, 32, 32),
	"evt_panel": Vector4(38, 52, 38, 48),
	"evt_card": Vector4(32, 42, 32, 40),
	"level_up_panel": Vector4(64, 84, 64, 72),
	"level_up_card": Vector4(42, 54, 42, 50),
	"upgrade_panel": Vector4(38, 52, 38, 48),
	"ws_panel": Vector4(38, 52, 38, 48),
	"ws_card": Vector4(32, 42, 32, 40),
	"ws_btn_back": Vector4(34, 16, 34, 16),
	"result_panel": Vector4(46, 62, 46, 58),
	"qc_modal": Vector4(46, 62, 46, 58),
	"chud_resource_panel": Vector4(60, 16, 60, 16),
	"chud_timer": Vector4(56, 22, 56, 22),
	"chud_artifact_row": Vector4(60, 24, 60, 24),
	"lut_toast": Vector4(58, 48, 58, 48),
	"ctb_big": Vector4(70, 20, 70, 20),
	"ctb_small": Vector4(56, 12, 56, 12),
	"vbn_frame": Vector4(84, 44, 84, 44),
	"hs4_portrait_panel": Vector4(38, 52, 38, 48),
	"hs4_dossier_panel": Vector4(38, 52, 38, 48),
	"hs4_radar_panel": Vector4(38, 52, 38, 48),
	"hs4_carousel_panel": Vector4(76, 42, 76, 40),
	"hs4_choose_btn": Vector4(42, 28, 42, 28),
	"hs4_asc_btn": Vector4(12, 10, 12, 10),
	"attr_panel": Vector4(38, 52, 38, 48),
	"pn_panel": Vector4(38, 52, 38, 48),
	"codex_main": Vector4(46, 62, 46, 58),
	"codex_nav": Vector4(38, 52, 38, 48),
	"codex_list": Vector4(38, 52, 38, 48),
	"codex_detail": Vector4(38, 52, 38, 48),
	"codex_entry_card": Vector4(32, 42, 32, 40),
	"codex_tab_btn": Vector4(34, 28, 34, 28),
	"codex_back_btn": Vector4(12, 10, 12, 10),
	"mm_btn": Vector4(48, 28, 48, 28),
	"qc_btn": Vector4(50, 28, 50, 28),
	"cr_btn": Vector4(50, 28, 50, 28),
	"rc_btn": Vector4(50, 28, 50, 28),
	"pm_btn": Vector4(34, 16, 34, 16),
	"fb_btn_send": Vector4(50, 28, 50, 28),
	"fb_btn_cancel": Vector4(50, 28, 50, 28),
	"pd_btn": Vector4(34, 16, 34, 16),
}
# content-инсет = бордюр + небольшой воздух (как соотношение margins→content в
# MINIMAL_METAL_*); safe-area внутри этих инсетов держит текст/кнопки от орнамента.
const OVERHAUL_2K_FRAME_CONTENT := {
	"qc_panel": Vector4(58, 72, 58, 66),
	"cr_panel": Vector4(58, 72, 58, 66),
	"rc_panel": Vector4(58, 72, 58, 66),
	"pm_panel": Vector4(58, 72, 58, 66),
	"fb_panel": Vector4(58, 72, 58, 66),
	"pd_panel": Vector4(72, 92, 72, 84),
	"gt_panel": Vector4(66, 44, 66, 40),
	"st_panel": Vector4(66, 44, 66, 40),
	"stat_tooltip": Vector4(44, 42, 44, 42),
	"evt_panel": Vector4(58, 72, 58, 66),
	"evt_card": Vector4(46, 58, 46, 54),
	"level_up_panel": Vector4(92, 110, 92, 96),
	"level_up_card": Vector4(58, 70, 58, 64),
	"upgrade_panel": Vector4(58, 72, 58, 66),
	"ws_panel": Vector4(78, 96, 78, 66),
	"ws_card": Vector4(48, 35, 48, 32),
	"ws_btn_back": Vector4(42, 18, 42, 18),
	"result_panel": Vector4(72, 92, 72, 84),
	"qc_modal": Vector4(72, 92, 72, 84),
	"chud_resource_panel": Vector4(72, 18, 72, 18),
	"chud_timer": Vector4(64, 26, 64, 24),
	"chud_artifact_row": Vector4(70, 28, 70, 28),
	"lut_toast": Vector4(70, 112, 70, 112),
	"ctb_big": Vector4(86, 10, 86, 10),
	"ctb_small": Vector4(72, 8, 72, 8),
	"vbn_frame": Vector4(112, 52, 112, 52),
	"hs4_portrait_panel": Vector4(58, 72, 58, 66),
	"hs4_dossier_panel": Vector4(58, 72, 58, 66),
	"hs4_radar_panel": Vector4(58, 72, 58, 66),
	"hs4_carousel_panel": Vector4(104, 62, 104, 56),
	"hs4_choose_btn": Vector4(56, 32, 56, 32),
	"hs4_asc_btn": Vector4(15, 12, 15, 12),
	"attr_panel": Vector4(58, 72, 58, 66),
	"pn_panel": Vector4(58, 72, 58, 66),
	"codex_main": Vector4(72, 92, 72, 84),
	"codex_nav": Vector4(21, 37, 40, 165),
	"codex_list": Vector4(48, 45, 84, 56),
	"codex_detail": Vector4(64, 58, 59, 64),
	"codex_entry_card": Vector4(48, 35, 53, 32),
	"codex_tab_btn": Vector4(48, 32, 48, 32),
	"codex_back_btn": Vector4(20, 16, 20, 16),
	"rc_btn": Vector4(34, 8, 34, 8),
}
const UNIFIED_MASTER_FRAME_PATH := UNIFIED_FRAME_DIR + "ui_frame_unified_master.png"
const UNIFIED_MASTER_FILL_FRAME_PATH := UNIFIED_FRAME_DIR + "ui_frame_unified_master_fill.png"
const UNIFIED_INNER_FILL_PATH := UNIFIED_FRAME_DIR + "ui_frame_unified_inner_fill.png"
const UNIFIED_ORNAMENT_TOP_PATH := UNIFIED_FRAME_DIR + "ui_frame_unified_ornament_top.png"
const UNIFIED_ORNAMENT_BOTTOM_PATH := UNIFIED_FRAME_DIR + "ui_frame_unified_ornament_bottom.png"
const UNIFIED_HOVER_OVERLAY_PATH := UNIFIED_FRAME_DIR + "ui_frame_unified_hover_overlay.png"
const UNIFIED_FRAME_SOURCE_SIZE := Vector2i(1024, 1024)
const UNIFIED_FRAME_TEXTURE_MARGINS := Vector4(72, 72, 72, 72)
const UNIFIED_FRAME_SAFE_RECT := Rect2(88, 88, 848, 848)
const UNIFIED_FRAME_CONTENT := {
	"global_panel": Vector4(28, 26, 28, 26),
	"level_panel": Vector4(34, 30, 34, 30),
	"card_frame": Vector4(12, 10, 12, 10),
	"hero_card": Vector4(12, 10, 12, 10),
	"card_hover": Vector4(18, 14, 18, 14),
	"tooltip": Vector4(18, 16, 18, 16),
	"hud_panel": Vector4(10, 9, 10, 9),
	"hud_card": Vector4(8, 7, 8, 7),
	"timer_panel": Vector4(14, 4, 14, 4),
}

const GLOBAL_PANEL_FRAME_PATH := MINIMAL_METAL_PANEL_PATH
const GLOBAL_BUTTON_FRAME_PATH := MINIMAL_METAL_BUTTON_DIR + "ui_btn_minimal_metal_standard.png"
const GLOBAL_CARD_FRAME_PATH := MINIMAL_METAL_CARD_PATH
const GLOBAL_HERO_CARD_FRAME_PATH := MINIMAL_METAL_CARD_PATH
const GLOBAL_CARD_HOVER_FRAME_PATH := MINIMAL_METAL_CARD_PATH
const GLOBAL_LEVEL_PANEL_FRAME_PATH := MINIMAL_METAL_PANEL_PATH
const GLOBAL_HUD_PANEL_FRAME_PATH := MINIMAL_METAL_HUD_STRIP_PATH
const GLOBAL_HUD_CARD_FRAME_PATH := MINIMAL_METAL_FIELD_PATH
const GLOBAL_TOOLTIP_FRAME_PATH := MINIMAL_METAL_TOOLTIP_PATH
const GLOBAL_TIMER_PANEL_FRAME_PATH := MINIMAL_METAL_FIELD_PATH

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

const MINIMAL_METAL_BUTTON_MARGINS := {
	"standard": Vector4(50, 28, 50, 28),
	"max": Vector4(58, 28, 58, 28),
	"main_menu": Vector4(48, 28, 48, 28),
	"hero_confirm": Vector4(42, 28, 42, 28),
	"reset_audio": Vector4(50, 28, 50, 28),
	"reset_bindings": Vector4(50, 28, 50, 28),
	"codex_tab": Vector4(34, 28, 34, 28),
	"back_s": Vector4(34, 28, 34, 28),
	"back_m": Vector4(42, 28, 42, 28),
	"back_l": Vector4(48, 28, 48, 28),
	"attr_selector": Vector4(58, 28, 58, 28),
	"fab": Vector4(12, 12, 12, 12),
	"utility": Vector4(12, 10, 12, 10),
	"pause": Vector4(34, 16, 34, 16),
	"rebind": Vector4(34, 16, 34, 16),
}

const MINIMAL_METAL_BUTTON_CONTENT := {
	"standard": Vector4(64, 32, 64, 32),
	"max": Vector4(72, 32, 72, 32),
	"main_menu": Vector4(62, 32, 62, 32),
	"hero_confirm": Vector4(56, 32, 56, 32),
	"reset_audio": Vector4(64, 32, 64, 32),
	"reset_bindings": Vector4(64, 32, 64, 32),
	"codex_tab": Vector4(48, 32, 48, 32),
	"back_s": Vector4(48, 32, 48, 32),
	"back_m": Vector4(56, 32, 56, 32),
	"back_l": Vector4(62, 32, 62, 32),
	"attr_selector": Vector4(72, 32, 72, 32),
	"fab": Vector4(15, 15, 15, 15),
	"utility": Vector4(15, 12, 15, 12),
	"pause": Vector4(46, 18, 46, 18),
	"rebind": Vector4(46, 18, 46, 18),
}

const TEXT_BUTTON_UNIQUE_TEXTURES := {
	"main_menu_380x104": {
		"normal": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_main_menu_380x104_normal.png",
		"hover": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_main_menu_380x104_hover.png",
		"pressed": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_main_menu_380x104_pressed.png",
		"focus": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_main_menu_380x104_focus.png",
		"disabled": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_main_menu_380x104_disabled.png",
	},
	"standard_420x104": {
		"normal": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_standard_420x104_normal.png",
		"hover": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_standard_420x104_hover.png",
		"pressed": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_standard_420x104_pressed.png",
		"focus": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_standard_420x104_focus.png",
		"disabled": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_standard_420x104_disabled.png",
	},
	"wide_440x104": {
		"normal": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_wide_440x104_normal.png",
		"hover": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_wide_440x104_hover.png",
		"pressed": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_wide_440x104_pressed.png",
		"focus": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_wide_440x104_focus.png",
		"disabled": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_wide_440x104_disabled.png",
	},
	"back_260x104": {
		"normal": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_back_260x104_normal.png",
		"hover": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_back_260x104_hover.png",
		"pressed": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_back_260x104_pressed.png",
		"focus": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_back_260x104_focus.png",
		"disabled": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_back_260x104_disabled.png",
	},
	"quit_220x72": {
		"normal": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_quit_220x72_normal.png",
		"hover": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_quit_220x72_hover.png",
		"pressed": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_quit_220x72_pressed.png",
		"focus": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_quit_220x72_focus.png",
		"disabled": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_quit_220x72_disabled.png",
	},
	"continue_240x72": {
		"normal": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_continue_240x72_normal.png",
		"hover": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_continue_240x72_hover.png",
		"pressed": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_continue_240x72_pressed.png",
		"focus": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_continue_240x72_focus.png",
		"disabled": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_continue_240x72_disabled.png",
	},
	"later_260x72": {
		"normal": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_later_260x72_normal.png",
		"hover": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_later_260x72_hover.png",
		"pressed": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_later_260x72_pressed.png",
		"focus": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_later_260x72_focus.png",
		"disabled": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_later_260x72_disabled.png",
	},
	"settings_back_280x64": {
		"normal": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_settings_back_280x64_normal.png",
		"hover": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_settings_back_280x64_hover.png",
		"pressed": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_settings_back_280x64_pressed.png",
		"focus": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_settings_back_280x64_focus.png",
		"disabled": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_settings_back_280x64_disabled.png",
	},
	"feedback_260x64": {
		"normal": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_feedback_260x64_normal.png",
		"hover": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_feedback_260x64_hover.png",
		"pressed": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_feedback_260x64_pressed.png",
		"focus": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_feedback_260x64_focus.png",
		"disabled": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_feedback_260x64_disabled.png",
	},
	"feedback_cancel_220x64": {
		"normal": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_feedback_cancel_220x64_normal.png",
		"hover": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_feedback_cancel_220x64_hover.png",
		"pressed": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_feedback_cancel_220x64_pressed.png",
		"focus": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_feedback_cancel_220x64_focus.png",
		"disabled": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_feedback_cancel_220x64_disabled.png",
	},
	"pause_280x60": {
		"normal": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_pause_280x60_normal.png",
		"hover": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_pause_280x60_hover.png",
		"pressed": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_pause_280x60_pressed.png",
		"focus": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_pause_280x60_focus.png",
		"disabled": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_pause_280x60_disabled.png",
	},
	"event_back_380x54": {
		"normal": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_event_back_380x54_normal.png",
		"hover": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_event_back_380x54_hover.png",
		"pressed": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_event_back_380x54_pressed.png",
		"focus": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_event_back_380x54_focus.png",
		"disabled": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_event_back_380x54_disabled.png",
	},
	"rebind_420x62": {
		"normal": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_rebind_420x62_normal.png",
		"hover": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_rebind_420x62_hover.png",
		"pressed": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_rebind_420x62_pressed.png",
		"focus": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_rebind_420x62_focus.png",
		"disabled": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_rebind_420x62_disabled.png",
	},
	"reset_bindings_long_560x104": {
		"normal": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_reset_bindings_long_560x104_normal.png",
		"hover": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_reset_bindings_long_560x104_hover.png",
		"pressed": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_reset_bindings_long_560x104_pressed.png",
		"focus": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_reset_bindings_long_560x104_focus.png",
		"disabled": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_reset_bindings_long_560x104_disabled.png",
	},
	"continue_run_long_420x72": {
		"normal": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_continue_run_long_420x72_normal.png",
		"hover": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_continue_run_long_420x72_hover.png",
		"pressed": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_continue_run_long_420x72_pressed.png",
		"focus": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_continue_run_long_420x72_focus.png",
		"disabled": TEXT_BUTTON_UNIQUE_DIR + "ui_btn_text_unique_continue_run_long_420x72_disabled.png",
	},
}

const TEXT_BUTTON_UNIQUE_MARGINS := {
	"main_menu_380x104": Vector4(54, 21, 54, 21),
	"standard_420x104": Vector4(54, 21, 54, 21),
	"wide_440x104": Vector4(54, 21, 54, 21),
	"back_260x104": Vector4(54, 21, 54, 21),
	"quit_220x72": Vector4(37, 14, 37, 14),
	"continue_240x72": Vector4(37, 14, 37, 14),
	"later_260x72": Vector4(37, 14, 37, 14),
	"settings_back_280x64": Vector4(34, 13, 34, 13),
	"feedback_260x64": Vector4(34, 13, 34, 13),
	"feedback_cancel_220x64": Vector4(34, 13, 34, 13),
	"pause_280x60": Vector4(34, 12, 34, 12),
	"event_back_380x54": Vector4(34, 11, 34, 11),
	"rebind_420x62": Vector4(34, 12, 34, 12),
	"reset_bindings_long_560x104": Vector4(54, 21, 54, 21),
	"continue_run_long_420x72": Vector4(37, 14, 37, 14),
}

const TEXT_BUTTON_UNIQUE_CONTENT := {
	"main_menu_380x104": Vector4(69, 21, 69, 21),
	"standard_420x104": Vector4(71, 21, 71, 21),
	"wide_440x104": Vector4(72, 21, 72, 21),
	"back_260x104": Vector4(64, 21, 64, 21),
	"quit_220x72": Vector4(47, 14, 47, 14),
	"continue_240x72": Vector4(47, 14, 47, 14),
	"later_260x72": Vector4(47, 14, 47, 14),
	"settings_back_280x64": Vector4(45, 13, 45, 13),
	"feedback_260x64": Vector4(44, 13, 44, 13),
	"feedback_cancel_220x64": Vector4(44, 13, 44, 13),
	"pause_280x60": Vector4(45, 12, 45, 12),
	"event_back_380x54": Vector4(49, 11, 49, 11),
	"rebind_420x62": Vector4(51, 12, 51, 12),
	"reset_bindings_long_560x104": Vector4(76, 21, 76, 21),
	"continue_run_long_420x72": Vector4(54, 14, 54, 14),
}
