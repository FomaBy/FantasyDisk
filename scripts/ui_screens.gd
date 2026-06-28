extends RefCounted

# Меню, настройки, выбор персонажа/оружия, магазин, события, отдых,
# level-up, победа/смерть, HUD и общие UI-стили.

var game
var settings_return_origin := "main_menu"

const HeroStatRadar := preload("res://scripts/ui/hero_stat_radar.gd")
const UIThemePaths := preload("res://scripts/ui/ui_theme_paths.gd")
const ShopUIConstants := preload("res://scripts/ui/shop_ui_constants.gd")
const HeroSelectConstants := preload("res://scripts/ui/hero_select_constants.gd")
const FEEDBACK_REPORTER_SCRIPT := preload("res://scripts/feedback_reporter.gd")
const DisplayResolution := preload("res://scripts/display_resolution.gd")
const StatFormulas := preload("res://scripts/stat_formulas.gd")

const ARTIFACT_ICON_DIR := ShopUIConstants.ARTIFACT_ICON_DIR
const SHOP_ICON_DIR := ShopUIConstants.SHOP_ICON_DIR
const SHOP_SLOT_FRAME_PATH := ShopUIConstants.SHOP_SLOT_FRAME_PATH
const SHOP_SLOT_HOVER_PATH := ShopUIConstants.SHOP_SLOT_HOVER_PATH
const SHOP_PRICE_BADGE_PATH := ShopUIConstants.SHOP_PRICE_BADGE_PATH
const SHOP_PURCHASED_OVERLAY_PATH := ShopUIConstants.SHOP_PURCHASED_OVERLAY_PATH
const SHOP_TOOLTIP_FRAME_PATH := ShopUIConstants.SHOP_TOOLTIP_FRAME_PATH
const SHOP_CAPTION_PLATE_PATH := ShopUIConstants.SHOP_CAPTION_PLATE_PATH
const SHOP_CAPTION_PLATE_MARGINS := ShopUIConstants.SHOP_CAPTION_PLATE_MARGINS
const DF_FRAME_DIR := UIThemePaths.DF_FRAME_DIR
const RED_GOLD_BUTTON_DIR := UIThemePaths.RED_GOLD_BUTTON_DIR
const MINIMAL_METAL_BUTTON_DIR := UIThemePaths.MINIMAL_METAL_BUTTON_DIR
const MINIMAL_MODAL_PATH := UIThemePaths.MINIMAL_METAL_MODAL_PATH
const MINIMAL_PANEL_PATH := UIThemePaths.MINIMAL_METAL_PANEL_PATH
const MINIMAL_CARD_PATH := UIThemePaths.MINIMAL_METAL_CARD_PATH
const MINIMAL_TOOLTIP_PATH := UIThemePaths.MINIMAL_METAL_TOOLTIP_PATH
const MINIMAL_HUD_STRIP_PATH := UIThemePaths.MINIMAL_METAL_HUD_STRIP_PATH
const MINIMAL_FIELD_PATH := UIThemePaths.MINIMAL_METAL_FIELD_PATH
const MINIMAL_FRAME_SOURCE_SIZE := UIThemePaths.MINIMAL_METAL_FRAME_SOURCE_SIZE
const MINIMAL_FRAME_TEXTURE_MARGINS := UIThemePaths.MINIMAL_METAL_FRAME_TEXTURE_MARGINS
const MINIMAL_FRAME_CONTENT := UIThemePaths.MINIMAL_METAL_FRAME_CONTENT
const MINIMAL_METAL_FRAME_PATHS := UIThemePaths.MINIMAL_METAL_FRAME_PATHS
const MINIMAL_METAL_FRAME_TEXTURE_MARGINS := UIThemePaths.MINIMAL_METAL_FRAME_TEXTURE_MARGINS
const MINIMAL_METAL_FRAME_CONTENT := UIThemePaths.MINIMAL_METAL_FRAME_CONTENT
const GLOBAL_PANEL_FRAME_PATH := UIThemePaths.GLOBAL_PANEL_FRAME_PATH
const GLOBAL_BUTTON_FRAME_PATH := UIThemePaths.GLOBAL_BUTTON_FRAME_PATH
const GLOBAL_CARD_FRAME_PATH := UIThemePaths.GLOBAL_CARD_FRAME_PATH
const GLOBAL_HERO_CARD_FRAME_PATH := UIThemePaths.GLOBAL_HERO_CARD_FRAME_PATH
const GLOBAL_CARD_HOVER_FRAME_PATH := UIThemePaths.GLOBAL_CARD_HOVER_FRAME_PATH
const GLOBAL_LEVEL_PANEL_FRAME_PATH := UIThemePaths.GLOBAL_LEVEL_PANEL_FRAME_PATH
const GLOBAL_HUD_PANEL_FRAME_PATH := UIThemePaths.GLOBAL_HUD_PANEL_FRAME_PATH
const GLOBAL_HUD_CARD_FRAME_PATH := UIThemePaths.GLOBAL_HUD_CARD_FRAME_PATH
const GLOBAL_TOOLTIP_FRAME_PATH := UIThemePaths.GLOBAL_TOOLTIP_FRAME_PATH
const GLOBAL_TIMER_PANEL_FRAME_PATH := UIThemePaths.GLOBAL_TIMER_PANEL_FRAME_PATH
const UNIFIED_MASTER_FILL_FRAME_PATH := UIThemePaths.UNIFIED_MASTER_FILL_FRAME_PATH
const UNIFIED_FRAME_TEXTURE_MARGINS := UIThemePaths.UNIFIED_FRAME_TEXTURE_MARGINS
const UNIFIED_FRAME_CONTENT := UIThemePaths.UNIFIED_FRAME_CONTENT
const ORNATE_FRAME_MARGINS := UIThemePaths.ORNATE_FRAME_MARGINS
const ORNATE_FRAME_CONTENT := UIThemePaths.ORNATE_FRAME_CONTENT
const RED_GOLD_BUTTON_TEXTURES := UIThemePaths.RED_GOLD_BUTTON_TEXTURES
const RED_GOLD_BUTTON_MARGINS := UIThemePaths.RED_GOLD_BUTTON_MARGINS
const RED_GOLD_BUTTON_CONTENT := UIThemePaths.RED_GOLD_BUTTON_CONTENT
const MINIMAL_METAL_BUTTON_MARGINS := UIThemePaths.MINIMAL_METAL_BUTTON_MARGINS
const MINIMAL_METAL_BUTTON_CONTENT := UIThemePaths.MINIMAL_METAL_BUTTON_CONTENT
# SCRUM-486: per-слот @2K-ассеты блока Меню/Навигация (см. UIThemePaths.OVERHAUL_2K_*).
const OVERHAUL_2K_FRAME_PATHS := UIThemePaths.OVERHAUL_2K_FRAME_PATHS
const OVERHAUL_2K_FRAME_SOURCE_SIZE := UIThemePaths.OVERHAUL_2K_FRAME_SOURCE_SIZE
const OVERHAUL_2K_FRAME_TEXTURE_MARGINS := UIThemePaths.OVERHAUL_2K_FRAME_TEXTURE_MARGINS
const OVERHAUL_2K_FRAME_CONTENT := UIThemePaths.OVERHAUL_2K_FRAME_CONTENT
const GLOSSARY := preload("res://scripts/glossary.gd")
const SYSTEM_CHECKBOX_UNCHECKED_PATH := "res://assets/sprites/ui/icons/system/ui_checkbox_unchecked.png"
const SYSTEM_CHECKBOX_CHECKED_PATH := "res://assets/sprites/ui/icons/system/ui_checkbox_checked.png"
const SYSTEM_SLIDER_TRACK_PATH := "res://assets/sprites/ui/icons/system/ui_slider_track.png"
const SYSTEM_SLIDER_GRABBER_PATH := "res://assets/sprites/ui/icons/system/ui_slider_grabber.png"
const SHOP_INLINE_SLOT_SIZE := ShopUIConstants.SHOP_INLINE_SLOT_SIZE
const SHOP_INLINE_ICON_SIZE := ShopUIConstants.SHOP_INLINE_ICON_SIZE
const SHOP_INLINE_CAPTION_SIZE := ShopUIConstants.SHOP_INLINE_CAPTION_SIZE
const SHOP_INLINE_CAPTION_TOP := ShopUIConstants.SHOP_INLINE_CAPTION_TOP
const SHOP_INLINE_ICON_TOP := ShopUIConstants.SHOP_INLINE_ICON_TOP
const SHOP_CURSOR_VARIANTS := ShopUIConstants.SHOP_CURSOR_VARIANTS
const HERO_RADAR_STATS := HeroSelectConstants.HERO_RADAR_STATS
const HERO_CLASS_COLORS := HeroSelectConstants.HERO_CLASS_COLORS
const STANDARD_ACTION_BUTTON_HEIGHT := 104.0
const STANDARD_ACTION_BUTTON_WIDTH := 420.0
const MAX_ACTION_BUTTON_VISUAL_WIDTH := 560.0
const MAIN_MENU_ACTION_BUTTON_WIDTH := 380.0
const COMPACT_UTILITY_BUTTON_SIZE := Vector2(54.0, 42.0)
const ASCENSION_BUTTON_SIZE := Vector2(54.0, 62.0)
const BUTTON_NEUTRAL_HOVER_TINT := Color(1.16, 1.16, 1.16, 1.0)
const BUTTON_NEUTRAL_FOCUS_TINT := Color(1.20, 1.20, 1.20, 1.0)
const BUTTON_NEUTRAL_HOVER_FONT := Color(1.0, 1.0, 1.0, 1.0)
const SETTINGS_RETURN_MAIN_MENU := "main_menu"
const SETTINGS_RETURN_RUN_PAUSE := "run_pause"
const SETTINGS_V2_FRAME_DIR := "res://assets/sprites/ui/frames/settings_v2/"
const SETTINGS_V2_MAIN_MODAL_PATH := MINIMAL_MODAL_PATH
const SETTINGS_V2_TAB_SWITCHER_PATH := MINIMAL_FIELD_PATH
const SETTINGS_V2_SECTION_PANEL_PATH := MINIMAL_PANEL_PATH
const SETTINGS_V2_CONTROL_ROW_PATH := MINIMAL_FIELD_PATH
const SETTINGS_V2_MAIN_SOURCE_SIZE := Vector2(986.0, 900.0)
const SETTINGS_V2_MAIN_TEXTURE_MARGINS := Vector4(46.0, 62.0, 46.0, 58.0)
const SETTINGS_V2_MAIN_CONTENT_MARGINS := Vector4(72.0, 92.0, 72.0, 84.0)
const SETTINGS_TAB_SWITCHER_FRAME_PATH := SETTINGS_V2_TAB_SWITCHER_PATH
const SETTINGS_TAB_SWITCHER_BASE_SIZE := Vector2(616.0, 286.0)
const SETTINGS_TAB_SWITCHER_CONTENT := Vector4(58.0, 52.0, 58.0, 48.0)
const COMBAT_HUD_FRAME_DIR := "res://assets/sprites/ui/frames/combat_hud/"
const COMBAT_HUD_FILL_DIR := "res://assets/sprites/ui/hud/combat_hud/"
const COMBAT_HUD_RESOURCE_PANEL_PATH := MINIMAL_HUD_STRIP_PATH
const COMBAT_HUD_CARD_PATHS := {
	"hp": MINIMAL_FIELD_PATH,
	"xp": MINIMAL_FIELD_PATH,
	"money": MINIMAL_FIELD_PATH,
	"ultimate_multiplier": MINIMAL_FIELD_PATH,
}
const COMBAT_HUD_TIMER_PATH := MINIMAL_FIELD_PATH
const COMBAT_HUD_ASCENSION_BADGE_PATH := MINIMAL_CARD_PATH
const COMBAT_HUD_LEVEL_UP_BUTTON_TEXTURES := {
	"normal": COMBAT_HUD_FRAME_DIR + "ui_btn_combat_level_up_plus.png",
	"hover": COMBAT_HUD_FRAME_DIR + "ui_btn_combat_level_up_plus_hover.png",
	"pressed": COMBAT_HUD_FRAME_DIR + "ui_btn_combat_level_up_plus_pressed.png",
	"disabled": COMBAT_HUD_FRAME_DIR + "ui_btn_combat_level_up_plus_disabled.png",
}
const COMBAT_HUD_BAR_FILL_PATHS := {
	"hp": COMBAT_HUD_FILL_DIR + "ui_hud_bar_fill_hp.png",
	"xp": COMBAT_HUD_FILL_DIR + "ui_hud_bar_fill_xp.png",
	"ultimate_multiplier": COMBAT_HUD_FILL_DIR + "ui_hud_bar_fill_ult.png",
	"money": COMBAT_HUD_FILL_DIR + "ui_hud_bar_fill_gold.png",
}
const COMBAT_HUD_GOLD_MEDALLION_PATH := COMBAT_HUD_FILL_DIR + "ui_hud_gold_medallion.png"
const COMBAT_HUD_RESOURCE_PANEL_MARGINS := Vector4(76.0, 42.0, 76.0, 40.0)
const COMBAT_HUD_RESOURCE_PANEL_CONTENT := Vector4(104.0, 62.0, 104.0, 56.0)
const COMBAT_HUD_CARD_MARGINS := Vector4(42.0, 38.0, 42.0, 36.0)
const COMBAT_HUD_CARD_CONTENT := Vector4(58.0, 52.0, 58.0, 48.0)
const COMBAT_HUD_TIMER_MARGINS := Vector4(42.0, 38.0, 42.0, 36.0)
const COMBAT_HUD_TIMER_CONTENT := Vector4(58.0, 52.0, 58.0, 48.0)
const COMBAT_HUD_ASCENSION_CONTENT := Vector4(46.0, 58.0, 46.0, 54.0)
const COMBAT_HUD_LEVEL_UP_MARGINS := Vector4(34.0, 34.0, 34.0, 34.0)
const COMBAT_HUD_LEVEL_UP_CONTENT := Vector4(36.0, 34.0, 36.0, 36.0)

# === SCRUM-487: координатная спека @2560×1440 — блок Боевые ===
# Источник правды для рисующего скрипта (рисует рамки/панели ровно в эти размеры) и
# документ-спека раскладки. Значения вычислены из фактической раскладки билдеров при
# базе 2560×1440 (window/stretch=canvas_items, aspect=keep → рантайм всегда лэйаутит в
# этой базе, окно скейлится автоматически). Стиль и инварианты — как у блока Меню (MM_*/
# QC_*/PM_* в SCRUM-484): панели с рамкой держат пустую safe-area под контент.
# Шаблонные размеры контейнер-зависимых слотов (карточки/кнопки/ряды) заданы как
# Rect2(0, 0, w, h) — позиция считается контейнером в рантайме (центрирование).
const COMBAT_BLOCK_DESIGN_BASE_2K := Vector2(2560.0, 1440.0)

# #5 Бой / HUD — _create_hud / _layout_combat_hud (процентная раскладка → детерминированная 2K-сетка)
const CHUD_RESOURCE_PANEL_2K := Rect2(18, 18, 820, 84)      # RunResourceHud (clampf 0.54·w → 820)
const CHUD_TIMER_2K := Rect2(1136, 14, 288, 96)             # CombatTimerPanel (центр; нет на боссе)
const CHUD_ASCENSION_BADGE_2K := Rect2(1432, 18, 64, 64)    # AscensionHudBadge (только при asc>0)
const CHUD_ARTIFACT_ROW_2K := Rect2(2140, 16, 402, 104)     # ArtifactHudRow (clampf 0.28·w → 402, прижат вправо)
const CHUD_LEVELUP_BUTTON_2K := Rect2(2436, 1316, 96, 117)  # LevelUpPlusButton (якорь bottom-right; min-size темы → h≈117)
const CHUD_LEVELUP_BADGE_2K := Rect2(2498, 1306, 28, 28)    # LevelUpPlusBadgePanel (счётчик пиков)
const CHUD_DAMAGE_FLASH_2K := Rect2(0, 0, 2560, 1440)       # DamageFlashOverlay (full-rect)

# #6 Событие — _show_event_screen (economy-панель "event"; safe = панель − content 58/72/58/66)
const EVT_PANEL_2K := Rect2(420, 330, 1720, 780)
const EVT_SAFE_2K := Rect2(478, 402, 1604, 642)
const EVT_CARD_2K := Rect2(0, 0, 480, 340)                  # EventChoiceButton{0..2} (3 в ряд, gap 48)
const EVT_BACK_BUTTON_2K := Rect2(0, 0, 380, 54)            # EventBackButton

# #14 Улучшение — _show_upgrade_screen (economy-панель "upgrade"; target 1720×730, центр)
const UPGRADE_PANEL_2K := Rect2(420, 355, 1720, 730)        # MenuPanel_upgrade (centered economy panel)
const UPGRADE_SAFE_2K := Rect2(478, 427, 1604, 592)         # safe = панель − content 58/72/58/66

# #11 Повышение уровня — _show_level_up_screen / _level_up_layout_metrics
const LU_PANEL_2K := Rect2(760, 420, 1040, 600)
const LU_SAFE_2K := Rect2(818, 492, 924, 462)
const LU_CARD_2K := Rect2(0, 0, 238, 210)                   # LevelUpRewardButton{0..2} (3 в ряд, gap 12)
const LU_LATER_BUTTON_2K := Rect2(0, 0, 260, 72)            # LevelUpLaterButton

# #12 Награда обычная — _show_reward_screen (_create_menu_box, панель 1120×660)
const RWD_PANEL_2K := Rect2(720, 390, 1120, 660)
const RWD_SAFE_2K := Rect2(778, 462, 1004, 522)
const RWD_CARD_2K := Rect2(0, 0, 300, 430)                  # BattleRewardButton{0..2} = REWARD_CARD_SIZE (gap 18)

# #13 Награда элитки — _show_elite_artifact_reward (панель 1140×640)
const ELR_PANEL_2K := Rect2(710, 400, 1140, 640)
const ELR_SAFE_2K := Rect2(768, 472, 1024, 502)
const ELR_CARD_2K := Rect2(0, 0, 320, 430)                  # EliteArtifactRewardButton{0..2} = REWARD_ELITE_CARD_SIZE (gap 22)

# #28 Тост повышения — _show_level_up_toast (транзиентный full-rect burst на позиции игрока/центра)
const LUT_OVERLAY_2K := Rect2(0, 0, 2560, 1440)

# #29 Баннер заголовка боя — _show_combat_title_banner (center-top; ширина была 1280 = 720p-баг → 2K)
const CTB_BIG_2K := Rect2(100, 120, 2360, 90)              # появление босса (big)
const CTB_SMALL_2K := Rect2(100, 92, 2360, 56)             # появление элитки

# #30 Баннер победы — _show_victory_banner (dim + "ПОБЕДА" 96pt по центру)
const VBN_DIM_2K := Rect2(0, 0, 2560, 1440)
const VBN_FRAME_2K := Rect2(560, 600, 1440, 240)
const VBN_SAFE_2K := Rect2(672, 652, 1216, 136)
# === конец спеки SCRUM-487 ===

# === SCRUM-488: координатная спека @2560×1440 — блок Прогрессия/Экономика ===
# Те же правила и стиль, что у блока Меню (SCRUM-484) и Боевые (SCRUM-487): значения
# вычислены из фактической раскладки билдеров при базе 2560×1440 и сверены с рантайм-дампом
# верификатора (build/qa/ui_no_overlap_matrix.md, секции *_2560×1440). Контейнер-зависимые
# слоты-шаблоны заданы как Rect2(0, 0, w, h). Кодекс/Настройки — путь (б) из ТЗ: рантайм-
# масштабирование V2 НЕ трогаем (оно уже uniform-заполняет вьюпорт: на 2K даёт ровно эти
# rect — codex = CODEX_V2_* × 4/3), здесь — документирующий 2K-вход для рисующего скрипта.

# #8 Магазин — _show_shop_screen (backdrop-лавка; контент в центральной зоне «стены»)
const SHOP_TITLE_2K := Rect2(900, 104, 760, 86)            # ShopHeader (заголовок+подзаголовок)
const SHOP_WALL_2K := Rect2(512, 547, 1536, 533)           # ShopParchmentWall (anchor-фракции 0.20/0.38/0.80/0.75)
const SHOP_SAFE_2K := Rect2(512, 547, 1536, 533)           # пустая зона лавки под слоты
const SHOP_SLOT_2K := Rect2(0, 0, 148, 148)                # ShopItemButton{0..3} (anchors 0.30/0.70 × 0.18/0.84 внутри стены)
const SHOP_BACK_2K := Rect2(1100, 1314, 360, 104)          # ShopLeaveButton (anchor bottom-center)

# #9 Докача — _show_attribute_shop (панель full-height; скролл опций + фикс-низ)
const ATTR_PANEL_2K := Rect2(730, 28, 1124, 1384)
const ATTR_SAFE_2K := Rect2(788, 100, 1008, 1246)          # панель − content 58/72/58/66
const ATTR_OFFER_2K := Rect2(0, 0, 480, 340)               # AttributeOffer_* = ECONOMY_CHOICE_TARGET_1440 (грид 2 кол)
const ATTR_ACTION_BUTTON_2K := Rect2(0, 0, 420, 62)        # AttributeReroll/Skip (фикс ВНЕ скролла снизу)

# #10 Дерево навыков — _show_skill_tree_screen (самый плотный: класс-панель + N веток)
const SKILL_MAIN_PANEL_2K := Rect2(48, 26, 2464, 1388)
const SKILL_SAFE_2K := Rect2(136, 118, 2288, 1214)         # layout-VBox (header→hint→body)
const SKILL_POINTS_BADGE_2K := Rect2(0, 0, 215, 96)        # SkillTreePointsBadge (ширина растёт под текст очков)
const SKILL_BACK_2K := Rect2(0, 0, 260, 104)               # SkillTreeBackButton
const SKILL_CLASS_PANEL_2K := Rect2(136, 262, 330, 1070)   # SkillTreeClassPanel (левая колонка)
const SKILL_BRANCHES_2K := Rect2(484, 262, 1932, 1276)     # SkillTreeBranches (ряд веток; @2K без гориз-скролла)
const SKILL_BRANCH_2K := Rect2(0, 0, 164, 430)             # SkillTreeBranchPanel_* (шаблон ветки, separation 14)

# #15 Кодекс — _show_codex_screen / _show_codex_section (3 колонки; V2-база 1920 × 4/3 → 2K)
const CODEX_OUTER_FRAME_2K := Rect2(32, 27, 2496, 1387)
const CODEX_HEADER_TITLE_2K := Rect2(149, 99, 1493, 85)
const CODEX_BACK_BUTTON_2K := Rect2(2245, 80, 168, 128)
const CODEX_NAV_PANEL_2K := Rect2(96, 227, 405, 1163)      # колонка навигации (панель)
const CODEX_NAV_SAFE_2K := Rect2(117, 264, 344, 960)
const CODEX_LIST_PANEL_2K := Rect2(517, 227, 1113, 1163)   # колонка списка (CodexContent)
const CODEX_DETAIL_PANEL_2K := Rect2(1656, 227, 808, 1163) # колонка детали (CodexDetailPanel)
const CODEX_PORTRAIT_SAFE_2K := Rect2(1861, 301, 427, 400)
const CODEX_CHIP_ROW_SAFE_2K := Rect2(1731, 731, 648, 107)
const CODEX_ENTRY_CARD_2K := Rect2(0, 0, 963, 147)
const CODEX_TAB_BUTTON_2K := Rect2(0, 0, 333, 115)

# #16 Настройки — _show_settings_menu (V2-модалка, scaled fill → 2K)
const SETTINGS_PANEL_2K := Rect2(256, 104, 2048, 1232)
const SETTINGS_SAFE_2K := Rect2(430, 229, 1700, 1062)
const SETTINGS_TITLE_2K := Rect2(448, 229, 1664, 64)
const SETTINGS_TAB_SWITCHER_2K := Rect2(730, 316, 1100, 220)
const SETTINGS_CONTENT_PANEL_2K := Rect2(430, 570, 1700, 610)
const SETTINGS_CONTROL_ROW_2K := Rect2(658, 602, 1438, 62) # строка контрола (разрешение/режим окна; шаблон h)
const SETTINGS_BACK_2K := Rect2(1140, 1204, 280, 87)
# === конец спеки SCRUM-488 ===

# #17 Что нового / патч-ноуты — _show_patch_notes_screen (SCRUM-576). Полноэкранная панель
# (как skill-tree main), хедер «Что нового» + «Назад в меню» сверху, скролл версий/буллетов
# внутри safe-area. Текст длинных версий уходит в вертикальный скролл (рамка не растягивается).
const PN_PANEL_2K := Rect2(48, 26, 2464, 1388)             # PatchNotesPanel (фрейм)
const PN_SAFE_2K := Rect2(136, 118, 2288, 1214)            # layout-VBox (header → scroll), панель − content 58/72/58/66 (масштаб)
const PN_HEADER_2K := Rect2(136, 118, 2288, 104)           # хедер (title EXPAND + back)
const PN_TITLE_2K := Rect2(136, 118, 1900, 104)            # «Что нового» (38px)
const PN_BACK_2K := Rect2(2164, 118, 260, 104)             # PatchNotesBackButton
const PN_SCROLL_2K := Rect2(136, 234, 2288, 1098)          # скролл версий/буллетов (под хедером)

const ECONOMY_FRAME_DIR := "res://assets/sprites/ui/frames/economy/"
const ECONOMY_PANEL_PATH := MINIMAL_PANEL_PATH
const ECONOMY_CHOICE_CARD_PATH := MINIMAL_CARD_PATH
const ECONOMY_CHOICE_CARD_HOVER_PATH := MINIMAL_CARD_PATH
const ECONOMY_DRAGON_PANEL_PATH := ECONOMY_FRAME_DIR + "ui_frame_economy_dragon_panel.png"
const ECONOMY_PRICE_BADGE_PATH := MINIMAL_FIELD_PATH
const ECONOMY_TOOLTIP_PATH := MINIMAL_TOOLTIP_PATH
const ECONOMY_PANEL_SOURCE_SIZE := Vector2(782.0, 716.0)
const ECONOMY_PANEL_TEXTURE_MARGINS := Vector4(38.0, 52.0, 38.0, 48.0)
const ECONOMY_PANEL_CONTENT := Vector4(58.0, 72.0, 58.0, 66.0)
const ECONOMY_CHOICE_SOURCE_SIZE := Vector2(426.0, 486.0)
const ECONOMY_CHOICE_TEXTURE_MARGINS := Vector4(32.0, 42.0, 32.0, 40.0)
const ECONOMY_CHOICE_HOVER_TEXTURE_MARGINS := Vector4(32.0, 42.0, 32.0, 40.0)
const ECONOMY_CHOICE_CONTENT := Vector4(46.0, 58.0, 46.0, 54.0)
const ECONOMY_CHOICE_HOVER_CONTENT := Vector4(46.0, 58.0, 46.0, 54.0)
const ECONOMY_CHOICE_SAFE_RECT := Rect2(46.0, 58.0, 334.0, 374.0)
const ECONOMY_CHOICE_TARGET_720 := Vector2(360.0, 240.0)
const ECONOMY_CHOICE_TARGET_1080 := Vector2(420.0, 300.0)
const ECONOMY_CHOICE_TARGET_1440 := Vector2(480.0, 340.0)
const ECONOMY_PRICE_BADGE_MARGINS := Vector4(42.0, 38.0, 42.0, 36.0)
const ECONOMY_PRICE_BADGE_CONTENT := Vector4(58.0, 52.0, 58.0, 48.0)
const ECONOMY_TOOLTIP_MARGINS := Vector4(46.0, 30.0, 46.0, 28.0)
const ECONOMY_TOOLTIP_CONTENT := Vector4(66.0, 44.0, 66.0, 40.0)
const PAUSE_END_MODAL_PATH := MINIMAL_MODAL_PATH
const PAUSE_END_MODAL_SOURCE_SIZE := Vector2(986.0, 900.0)
const PAUSE_END_MODAL_TEXTURE_MARGINS := Vector4(51.0, 70.0, 51.0, 63.0)
const PAUSE_END_MODAL_CONTENT := Vector4(74.0, 94.0, 74.0, 86.0)
const PROGRESSION_FRAME_DIR := "res://assets/sprites/ui/frames/progression/"
const PROGRESSION_MAIN_PANEL_PATH := PROGRESSION_FRAME_DIR + "ui_frame_progression_main_panel.png"
const PROGRESSION_BRANCH_PANEL_PATH := PROGRESSION_FRAME_DIR + "ui_frame_progression_branch_panel.png"
const PROGRESSION_CLASS_PANEL_PATH := PROGRESSION_FRAME_DIR + "ui_frame_progression_class_panel.png"
const PROGRESSION_POINTS_BADGE_PATH := PROGRESSION_FRAME_DIR + "ui_frame_progression_points_badge.png"
const PROGRESSION_TOOLTIP_PATH := PROGRESSION_FRAME_DIR + "ui_frame_progression_tooltip.png"
const PROGRESSION_NODE_TEXTURES := {
	"available": PROGRESSION_FRAME_DIR + "ui_frame_progression_node_available.png",
	"locked": PROGRESSION_FRAME_DIR + "ui_frame_progression_node_locked.png",
	"purchased": PROGRESSION_FRAME_DIR + "ui_frame_progression_node_purchased.png",
	"focus": PROGRESSION_FRAME_DIR + "ui_frame_progression_node_focus.png",
}
const PROGRESSION_MAIN_PANEL_MARGINS := Vector4(78.0, 92.0, 78.0, 86.0)
const PROGRESSION_MAIN_PANEL_CONTENT := Vector4(88.0, 92.0, 88.0, 82.0)
const PROGRESSION_BRANCH_PANEL_MARGINS := Vector4(54.0, 88.0, 54.0, 92.0)
const PROGRESSION_BRANCH_PANEL_CONTENT := Vector4(28.0, 54.0, 28.0, 48.0)
const PROGRESSION_CLASS_PANEL_MARGINS := Vector4(96.0, 52.0, 72.0, 56.0)
const PROGRESSION_CLASS_PANEL_CONTENT := Vector4(104.0, 42.0, 42.0, 42.0)
const PROGRESSION_POINTS_BADGE_CONTENT := Vector4(20.0, 18.0, 20.0, 28.0)
const PROGRESSION_TOOLTIP_MARGINS := Vector4(58.0, 58.0, 76.0, 76.0)
const PROGRESSION_TOOLTIP_CONTENT := Vector4(84.0, 78.0, 112.0, 100.0)
const CODEX_FRAME_DIR := "res://assets/sprites/ui/frames/codex/"
const CODEX_MAIN_PANEL_PATH := MINIMAL_MODAL_PATH
const CODEX_SECTION_PANEL_PATH := MINIMAL_PANEL_PATH
const CODEX_ENTRY_CARD_PATH := MINIMAL_CARD_PATH
const CODEX_ENTRY_CARD_HOVER_PATH := MINIMAL_CARD_PATH
const CODEX_PORTRAIT_SLOT_PATH := MINIMAL_FIELD_PATH
const CODEX_TOOLTIP_PATH := MINIMAL_TOOLTIP_PATH
const CODEX_TAB_TEXTURES := {
	"normal": CODEX_FRAME_DIR + "ui_frame_codex_tab.png",
	"hover": CODEX_FRAME_DIR + "ui_frame_codex_tab_hover.png",
	"pressed": CODEX_FRAME_DIR + "ui_frame_codex_tab_pressed.png",
	"disabled": CODEX_FRAME_DIR + "ui_frame_codex_tab_disabled.png",
}
const CODEX_MAIN_PANEL_MARGINS := Vector4(51.0, 70.0, 51.0, 63.0)
const CODEX_MAIN_PANEL_CONTENT := Vector4(74.0, 94.0, 74.0, 86.0)
const CODEX_SECTION_PANEL_MARGINS := Vector4(41.0, 56.0, 41.0, 50.0)
const CODEX_SECTION_PANEL_CONTENT := Vector4(59.0, 75.0, 59.0, 68.0)
const CODEX_ENTRY_CARD_MARGINS := Vector4(34.0, 45.0, 34.0, 44.0)
const CODEX_ENTRY_CARD_CONTENT := Vector4(45.0, 58.0, 45.0, 56.0)
const CODEX_PORTRAIT_SLOT_MARGINS := Vector4(44.0, 39.0, 44.0, 37.0)
const CODEX_PORTRAIT_SLOT_CONTENT := Vector4(59.0, 53.0, 59.0, 50.0)
const CODEX_TOOLTIP_MARGINS := Vector4(49.0, 31.0, 49.0, 29.0)
const CODEX_TOOLTIP_CONTENT := Vector4(68.0, 46.0, 68.0, 41.0)
const CODEX_TAB_MARGINS := Vector4(42.0, 20.0, 42.0, 20.0)
const CODEX_TAB_CONTENT := Vector4(24.0, 14.0, 24.0, 14.0)
const CODEX_V2_BASE_SIZE := Vector2(1920.0, 1080.0)
const CODEX_V2_OUTER_FRAME_RECT := Rect2(24.0, 20.0, 1872.0, 1040.0)
const CODEX_V2_HEADER_TITLE_SAFE := Rect2(112.0, 74.0, 1120.0, 64.0)
const CODEX_V2_BACK_BUTTON_SAFE := Rect2(1684.0, 60.0, 126.0, 96.0)
const CODEX_V2_NAV_PANEL_RECT := Rect2(72.0, 170.0, 304.0, 872.0)
const CODEX_V2_NAV_SAFE := Rect2(88.0, 198.0, 258.0, 720.0)
const CODEX_V2_LIST_PANEL_RECT := Rect2(388.0, 170.0, 835.0, 872.0)
const CODEX_V2_DETAIL_PANEL_RECT := Rect2(1242.0, 170.0, 606.0, 872.0)
const CODEX_V2_PORTRAIT_SAFE := Rect2(1396.0, 226.0, 320.0, 300.0)
const CODEX_V2_CHIP_ROW_SAFE := Rect2(1298.0, 548.0, 486.0, 80.0)
const CODEX_V2_ENTRY_CARD_SOURCE_SIZE := Vector2(722.0, 110.0)
const CODEX_V2_ENTRY_CARD_CONTENT := Vector4(36.0, 26.0, 40.0, 24.0)
const CODEX_V2_MAIN_PANEL_MARGINS := Vector4(48.0, 44.0, 72.0, 38.0)
const CODEX_V2_MAIN_PANEL_CONTENT := Vector4(72.0, 64.0, 72.0, 36.0)
const CODEX_V2_NAV_PANEL_CONTENT := Vector4(16.0, 28.0, 30.0, 124.0)
const CODEX_V2_LIST_PANEL_CONTENT := Vector4(36.0, 34.0, 63.0, 42.0)
const CODEX_V2_DETAIL_PANEL_CONTENT := Vector4(48.0, 44.0, 44.0, 48.0)
const CODEX_V2_TOOLTIP_CONTENT := Vector4(20.0, 28.0, 18.0, 34.0)
const REWARD_FRAME_DIR := "res://assets/sprites/ui/frames/rewards/"
const REWARD_CARD_PATH := MINIMAL_CARD_PATH
const REWARD_CARD_HOVER_PATH := MINIMAL_CARD_PATH
const REWARD_ELITE_CARD_PATH := MINIMAL_CARD_PATH
const REWARD_ELITE_CARD_HOVER_PATH := MINIMAL_CARD_PATH
const REWARD_FRAME_SOURCE_SIZE := Vector2(426.0, 486.0)
const REWARD_CARD_SIZE := Vector2(300.0, 430.0)
const REWARD_ELITE_CARD_SIZE := Vector2(320.0, 430.0)
const REWARD_CARD_TEXTURE_MARGINS := Vector4(32.0, 42.0, 32.0, 40.0)
const REWARD_CARD_SOURCE_CONTENT := Vector4(46.0, 58.0, 46.0, 54.0)
const REWARD_ELITE_CARD_TEXTURE_MARGINS := Vector4(32.0, 42.0, 32.0, 40.0)
const REWARD_ELITE_CARD_SOURCE_CONTENT := Vector4(46.0, 58.0, 46.0, 54.0)


func _init(game_ref) -> void:
	game = game_ref


# SCRUM-484: координатная спека @2560×1440 — блок Меню/Навигация (главное меню).
# Документирующие const рядом с билдером: x,y,w,h каждого слота контента @2K, плюс
# safe-area (пустая зона внутри рамки, куда можно класть контент). База дизайна 2K
# (project.godot viewport 2560×1440, stretch=canvas_items/keep). Эти прямоугольники —
# вход для рисующего скрипта: он рисует ассеты ровно в эти размеры.
const MENU_NAV_DESIGN_BASE_2K := Vector2(2560.0, 1440.0)
const MM_TITLE_2K := Rect2(640, 72, 1280, 150)
# Колонка кнопок слева (MarginContainer offset_left=72..452, VBox по центру вертикали,
# 6 кнопок 380×104, separation 10 → высота 674, центр 1440 → top=383).
const MM_BUTTON_COLUMN_2K := Rect2(72, 383, 380, 674)
const MM_BTN_START_2K := Rect2(72, 383, 380, 104)
const MM_BTN_SETTINGS_2K := Rect2(72, 497, 380, 104)
const MM_BTN_SKILLTREE_2K := Rect2(72, 611, 380, 104)
const MM_BTN_PATCHNOTES_2K := Rect2(72, 725, 380, 104)
const MM_BTN_CODEX_2K := Rect2(72, 839, 380, 104)
const MM_BTN_EXIT_2K := Rect2(72, 953, 380, 104)
const MM_VERSION_LABEL_2K := Rect2(2440, 1406, 104, 24)  # якорь bottom-right
const MM_SAFE_2K := Rect2(72, 383, 380, 674)  # фон обязан держать эту колонку пустой


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

	var title_label := Label.new()
	title_label.name = "MainMenuTitleLabel"
	title_label.text = "FANTASY DISK"
	title_label.anchor_left = 0.25
	title_label.anchor_top = 0.0
	title_label.anchor_right = 0.75
	title_label.anchor_bottom = 0.0
	title_label.offset_left = 0.0
	title_label.offset_top = 72.0
	title_label.offset_right = 0.0
	title_label.offset_bottom = 222.0
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 72)
	title_label.add_theme_color_override("font_color", Color(0.92, 0.78, 0.46, 0.94))
	title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.82))
	title_label.add_theme_constant_override("shadow_offset_x", 3)
	title_label.add_theme_constant_override("shadow_offset_y", 4)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_label)

	var layout := MarginContainer.new()
	layout.anchor_left = 0.0
	layout.anchor_top = 0.0
	layout.anchor_right = 0.0
	layout.anchor_bottom = 1.0
	layout.offset_left = 72.0
	layout.offset_top = 0.0
	layout.offset_right = 452.0
	layout.offset_bottom = 0.0
	layout.add_theme_constant_override("margin_left", 0)
	layout.add_theme_constant_override("margin_top", 0)
	layout.add_theme_constant_override("margin_right", 0)
	layout.add_theme_constant_override("margin_bottom", 0)
	root.add_child(layout)

	var action_box := VBoxContainer.new()
	action_box.name = "MainMenuActions"
	action_box.custom_minimum_size = Vector2(380, 0)
	action_box.alignment = BoxContainer.ALIGNMENT_CENTER
	action_box.add_theme_constant_override("separation", 10)
	layout.add_child(action_box)

	var start_button := _make_button("Начать новую игру")
	start_button.name = "MainMenuStartButton"
	_set_action_button_size(start_button, MAIN_MENU_ACTION_BUTTON_WIDTH)
	start_button.pressed.connect(func() -> void:
		if game.run_autosave_has_run():
			_show_continue_run_dialog()
		else:
			_show_character_select()
	)
	action_box.add_child(start_button)

	var settings_button := _make_button("Настройки")
	settings_button.name = "MainMenuSettingsButton"
	_set_action_button_size(settings_button, MAIN_MENU_ACTION_BUTTON_WIDTH)
	settings_button.pressed.connect(func() -> void:
		_show_settings_menu(SETTINGS_RETURN_MAIN_MENU)
	)
	action_box.add_child(settings_button)

	var version_label := Label.new()
	version_label.name = "MainMenuVersionLabel"
	version_label.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	version_label.anchor_left = 1.0
	version_label.anchor_top = 1.0
	version_label.anchor_right = 1.0
	version_label.anchor_bottom = 1.0
	version_label.offset_left = -120.0
	version_label.offset_top = -34.0
	version_label.offset_right = -16.0
	version_label.offset_bottom = -10.0
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version_label.add_theme_font_size_override("font_size", 13)
	version_label.add_theme_color_override("font_color", Color(0.62, 0.66, 0.72, 0.85))
	version_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(version_label)

	var skill_tree_button := _make_button("Древо умений")
	skill_tree_button.name = "MainMenuSkillTreeButton"
	_set_action_button_size(skill_tree_button, MAIN_MENU_ACTION_BUTTON_WIDTH)
	skill_tree_button.pressed.connect(_show_skill_tree_screen)
	action_box.add_child(skill_tree_button)

	# SCRUM-159: «Что нового» с бейджем непросмотренной версии (не модалка).
	var patch_notes_data := preload("res://scripts/patch_notes_data.gd")
	var settings_module := preload("res://scripts/game_settings.gd")
	var last_seen: String = str(settings_module.load_settings().get("last_seen_version", "0.0.0"))
	var patch_notes_button := _make_button("Что нового  ●" if patch_notes_data.has_new_since(last_seen) else "Что нового")
	patch_notes_button.name = "MainMenuPatchNotesButton"
	_set_action_button_size(patch_notes_button, MAIN_MENU_ACTION_BUTTON_WIDTH)
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
	_set_action_button_size(codex_button, MAIN_MENU_ACTION_BUTTON_WIDTH)
	codex_button.pressed.connect(_show_codex_screen)
	action_box.add_child(codex_button)

	var exit_button := _make_button("Выйти из игры")
	exit_button.name = "MainMenuExitButton"
	_set_action_button_size(exit_button, MAIN_MENU_ACTION_BUTTON_WIDTH)
	exit_button.pressed.connect(_show_quit_confirmation_dialog)
	action_box.add_child(exit_button)
	game.ui_escape_action = _show_quit_confirmation_dialog


# SCRUM-484: координатная спека @2560×1440 — подтверждение выхода (модалка).
# Панель PanelContainer (offset ±300×±170 от центра → 600×340), _panel_style content
# margins (58,72,58,66) → safe-area. Контент: заголовок, подзаголовок, ряд из двух
# кнопок 220×72 (separation 18). Всё помещается внутри safe-area без наслоений.
const QC_DIM_2K := Rect2(0, 0, 2560, 1440)
const QC_PANEL_2K := Rect2(980, 550, 600, 340)
const QC_SAFE_2K := Rect2(1038, 622, 484, 202)
const QC_TITLE_2K := Rect2(1038, 627, 484, 44)
const QC_SUBTITLE_2K := Rect2(1038, 687, 484, 44)
const QC_BTN_EXIT_2K := Rect2(1051, 747, 220, 72)
const QC_BTN_CANCEL_2K := Rect2(1289, 747, 220, 72)


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
	# SCRUM-581: свежий @2K per-слот фрейм диалога подтверждения (qc_modal 600×340, modal-
	# профиль — более ornate бордюр befitting confirm-модалки; SCRUM-486 держал qc_panel
	# на общем panel-профиле). Кнопки остаются на унифицированном 4-state minimal_metal.
	panel.add_theme_stylebox_override("panel", _overhaul_2k_frame_style("qc_modal", Vector2(600.0, 340.0)))
	overlay.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	var title_label := Label.new()
	title_label.name = "QuitConfirmationTitle"
	title_label.text = "Выйти из игры?"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	box.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.name = "QuitConfirmationSubtitle"
	subtitle_label.text = "Несохраненный забег будет завершен. Продолжить выход?"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size", 16)
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


# SCRUM-484: координатная спека @2560×1440 — продолжить забег (модалка).
# Панель (offset ±340×±190 → 680×380), _panel_style margins (58,72,58,66) → safe-area.
# Контент: заголовок, подзаголовок (2 строки, autowrap), ряд из двух кнопок 240×72
# (separation 18). Текст в рамках, кнопки не уезжают за нижний край.
const CR_DIM_2K := Rect2(0, 0, 2560, 1440)
const CR_PANEL_2K := Rect2(940, 530, 680, 380)
const CR_SAFE_2K := Rect2(998, 602, 564, 242)
const CR_TITLE_2K := Rect2(998, 614, 564, 44)
const CR_SUBTITLE_2K := Rect2(998, 674, 564, 66)
const CR_BTN_CONTINUE_2K := Rect2(1031, 758, 240, 72)
const CR_BTN_NEWGAME_2K := Rect2(1289, 758, 240, 72)


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
	panel.offset_left = -340.0
	panel.offset_top = -190.0
	panel.offset_right = 340.0
	panel.offset_bottom = 190.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# SCRUM-486: @2K per-слот фрейм (cr_panel 680×380, ровно размер панели).
	panel.add_theme_stylebox_override("panel", _overhaul_2k_frame_style("cr_panel", Vector2(680.0, 380.0)))
	panel.set_meta("continue_run_slot", "cr_panel")
	panel.set_meta("continue_run_content_margins", _overhaul_2k_content_margins("cr_panel", CR_PANEL_2K.size))
	panel.set_meta("continue_run_content_rect", Rect2(CR_SAFE_2K.position - CR_PANEL_2K.position, CR_SAFE_2K.size))
	overlay.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	var title_label := Label.new()
	title_label.name = "ContinueRunTitle"
	title_label.text = "Продолжить забег?"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	box.add_child(title_label)

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
	subtitle_label.add_theme_font_size_override("font_size", 16)
	subtitle_label.add_theme_color_override("font_color", Color(0.90, 0.88, 0.78, 1.0))
	box.add_child(subtitle_label)

	var button_row := HBoxContainer.new()
	button_row.name = "ContinueRunButtons"
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.custom_minimum_size = Vector2(0.0, 76.0)
	button_row.add_theme_constant_override("separation", 18)
	box.add_child(button_row)

	var continue_button := _make_button("Продолжить")
	continue_button.name = "ContinueRunButton"
	_set_action_button_size(continue_button, 240.0, 72.0)
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


# ВЫБОР ГЕРОЯ v4 (SCRUM-470): принятый макап-фон (contain-fit) + живой контент по
# нормализованным зонам. Контент размещается только в пустых content/safe зонах.
const HS4_TITLE := Rect2(0.265, 0.018, 0.470, 0.105)
const HS4_BACK := Rect2(0.022, 0.028, 0.110, 0.070)
const HS4_PORTRAIT_FRAME := Rect2(0.020, 0.135, 0.247, 0.580)
const HS4_PORTRAIT_SAFE := Rect2(0.035, 0.168, 0.217, 0.512)
const HS4_DOSSIER := Rect2(0.288, 0.138, 0.362, 0.555)
const HS4_RADAR := Rect2(0.715, 0.175, 0.230, 0.320)
const HS4_CAROUSEL := Rect2(0.020, 0.735, 0.960, 0.215)
const HS4_CAROUSEL_SLOTS := 9
const HS4_DOSSIER_STATS := ["strength", "agility", "intelligence", "endurance", "perception"]

# SCRUM-489: координатная спека @2560×1440 — экран «Выбор героя v4» (полноэкранный).
# ВАЖНО: билдер _build_character_select_v4 НЕ использует нормализованные доли HS4_* (выше,
# SCRUM-470) — он считает раскладку множителями vp.x/vp.y «на лету». Значения ниже — реальная
# раскладка билдера @2K (vp=2560×1440): mx=56, my=40, top_h=122, car_h=245, gap=36, pad=29,
# content_w=2448, mid_y=179, car_y=1155, mid_h=959, left_w=661, right_w=624, center_w=1091.
# Доли HS4_* (Rect2 в долях) НЕ совпадают с этими px (напр. HS4_PORTRAIT_FRAME долями ≈
# (51,194,632,835) против реальных (56,179,661,959)) — оставлены для mockup-валидации, НЕ трогать.
const HS4_DESIGN_BASE_2K := Vector2(2560.0, 1440.0)
const HS4_TITLE_2K := Rect2(56, 40, 2448, 122)
const HS4_BACK_2K := Rect2(56, 74, 218, 54)                  # compact runtime back button centered inside title band
const HS4_PORTRAIT_FRAME_2K := Rect2(56, 179, 661, 959)
const HS4_PORTRAIT_SAFE_2K := Rect2(114, 251, 545, 821)       # frame content margins: 58/72/58/66
const HS4_DOSSIER_2K := Rect2(753, 179, 1091, 959)            # x = 56 + 661 + gap 36
const HS4_RADAR_2K := Rect2(1880, 179, 624, 959)             # x = 753 + 1091 + gap 36
const HS4_CAROUSEL_2K := Rect2(56, 1155, 2448, 245)
const HS4_CHOOSE_BTN_2K := Rect2(0, 0, 512, 89)              # шаблон (shrink_center в dossier-VBox)
const HS4_ASC_BTN_2K := Rect2(0, 0, 102, 72)                 # шаблон ±-кнопок возвышения
# Карусель SCRUM-561: content-zone comes from hs4_carousel_panel; thumbnails stay square inside the safe band.
const HS4_CAROUSEL_SLOT_2K := Rect2(237, 1230, 101, 101)     # square slot inside hud-strip content safe area
const HS4_CAROUSEL_SLOT_STEP_2K := 248.0


func _hs4_scaled_rect(zone: Rect2, canvas_size: Vector2) -> Rect2:
	return Rect2(
		Vector2(round(zone.position.x * canvas_size.x), round(zone.position.y * canvas_size.y)),
		Vector2(round(zone.size.x * canvas_size.x), round(zone.size.y * canvas_size.y))
	)


func _hs4_place(ctrl: Control, parent: Control, canvas_size: Vector2, zone: Rect2) -> void:
	var rect := _hs4_scaled_rect(zone, canvas_size)
	ctrl.position = rect.position
	ctrl.size = rect.size
	parent.add_child(ctrl)


func _hs4_overlay_style(fill: Color, border: Color = Color(0, 0, 0, 0), border_width := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(6)
	style.content_margin_left = 4
	style.content_margin_top = 3
	style.content_margin_right = 4
	style.content_margin_bottom = 3
	return style


func _hs4_make_overlay_button(text: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_stylebox_override("normal", _hs4_overlay_style(Color(0.02, 0.015, 0.01, 0.04)))
	button.add_theme_stylebox_override("hover", _hs4_overlay_style(Color(0.32, 0.18, 0.04, 0.16), Color(0.98, 0.76, 0.34, 0.8), 1))
	button.add_theme_stylebox_override("focus", _hs4_overlay_style(Color(0.32, 0.18, 0.04, 0.18), Color(1.0, 0.86, 0.42, 0.95), 2))
	button.add_theme_stylebox_override("pressed", _hs4_overlay_style(Color(0.05, 0.025, 0.015, 0.28), Color(0.86, 0.62, 0.22, 0.9), 1))
	button.add_theme_stylebox_override("disabled", _hs4_overlay_style(Color(0.02, 0.02, 0.02, 0.12)))
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color(1.0, 0.88, 0.54, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.72, 1.0))
	button.add_theme_color_override("font_focus_color", Color(1.0, 0.96, 0.72, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.9, 1.0, 0.96, 1.0))
	return button


func _build_character_select_v4() -> void:
	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "HeroSelectScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.ui_layer.add_child(root)
	_add_screen_background(root, "hero_select")

	var vp: Vector2 = root.get_viewport_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		vp = Vector2(1600.0, 900.0)
	var mx: float = round(vp.x * 0.022)
	var my: float = round(vp.y * 0.028)
	var top_h: float = round(vp.y * 0.085)
	var car_h: float = round(vp.y * 0.17)
	var gap: float = round(vp.x * 0.014)
	var content_w: float = vp.x - mx * 2.0
	var mid_y: float = my + top_h + round(vp.y * 0.012)
	var car_y: float = vp.y - my - car_h
	var mid_h: float = car_y - mid_y - round(vp.y * 0.012)
	var left_w: float = round(content_w * 0.27)
	var right_w: float = round(content_w * 0.255)
	var center_w: float = content_w - left_w - right_w - gap * 2.0
	var pad: float = round(vp.y * 0.02)

	var title := Label.new()
	title.text = "Выбор героя"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.position = Vector2(mx, my)
	title.size = Vector2(content_w, top_h)
	title.add_theme_font_size_override("font_size", maxi(20, int(round(vp.y * 0.04))))
	title.add_theme_color_override("font_color", Color(0.96, 0.9, 0.68, 1.0))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title)

	var back_button := _make_button("Назад")
	back_button.name = "HS4BackButton"
	var back_button_size := Vector2(maxf(132.0, round(vp.x * 0.085)), clampf(round(top_h * 0.72), 44.0, 54.0))
	back_button.custom_minimum_size = back_button_size
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		back_button.add_theme_stylebox_override(state, _compact_button_style(state == "hover" or state == "focus", state == "pressed", state == "disabled"))
	back_button.position = Vector2(mx, my + round((top_h - back_button_size.y) * 0.5))
	root.add_child(back_button)
	back_button.pressed.connect(_show_main_menu)

	var portrait_panel := Panel.new()
	portrait_panel.position = Vector2(mx, mid_y)
	portrait_panel.size = Vector2(left_w, mid_h)
	portrait_panel.add_theme_stylebox_override("panel", _overhaul_2k_frame_style("hs4_portrait_panel", portrait_panel.size))
	portrait_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(portrait_panel)
	var portrait_safe := _overhaul_2k_content_margins("hs4_portrait_panel", portrait_panel.size)
	var portrait := TextureRect.new()
	portrait.name = "HS4Portrait"
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.position = Vector2(portrait_safe.x, portrait_safe.y)
	portrait.size = Vector2(left_w - portrait_safe.x - portrait_safe.z, mid_h - portrait_safe.y - portrait_safe.w)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_panel.add_child(portrait)

	var dossier_panel := Panel.new()
	dossier_panel.position = Vector2(mx + left_w + gap, mid_y)
	dossier_panel.size = Vector2(center_w, mid_h)
	dossier_panel.add_theme_stylebox_override("panel", _overhaul_2k_frame_style("hs4_dossier_panel", dossier_panel.size))
	dossier_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dossier_panel)
	var dossier_safe := _overhaul_2k_content_margins("hs4_dossier_panel", dossier_panel.size)
	var dossier := VBoxContainer.new()
	dossier.position = Vector2(dossier_safe.x, dossier_safe.y)
	dossier.size = Vector2(center_w - dossier_safe.x - dossier_safe.z, mid_h - dossier_safe.y - dossier_safe.w)
	dossier.add_theme_constant_override("separation", maxi(4, int(round(vp.y * 0.012))))
	dossier.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dossier_panel.add_child(dossier)

	var name_label := Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", maxi(18, int(round(vp.y * 0.035))))
	name_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42, 1.0))
	dossier.add_child(name_label)

	var desc_label := Label.new()
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", maxi(11, int(round(vp.y * 0.019))))
	desc_label.add_theme_color_override("font_color", Color(0.86, 0.89, 0.96, 1.0))
	dossier.add_child(desc_label)

	# SCRUM-493: строка стартового оружия класса (бриф v4). Trim-ellipsis, чтобы 3 названия
	# не вылезали за панель на 1280. Заполняется в refresh через _hero_weapon_names.
	var weapon_label := Label.new()
	weapon_label.name = "HS4Weapon"
	weapon_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	weapon_label.max_lines_visible = 1
	weapon_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_label.add_theme_font_size_override("font_size", maxi(11, int(round(vp.y * 0.019))))
	weapon_label.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0, 1.0))
	weapon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dossier.add_child(weapon_label)

	# SCRUM-493: 5 строк статов = [иконка] [название] [бар до глобального максимума] [значение],
	# вместо плоского GridContainer "%s: %d". Бар красится в цвет стата (ICON_COLORS), как радар.
	var stats_box := VBoxContainer.new()
	stats_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_box.add_theme_constant_override("separation", maxi(3, int(round(vp.y * 0.007))))
	stats_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dossier.add_child(stats_box)
	var stat_value_labels := {}
	var stat_bars := {}
	var stat_icon_px := maxi(18, int(round(vp.y * 0.028)))
	var stat_font_px := maxi(11, int(round(vp.y * 0.019)))
	var stat_name_min_w := maxf(float(center_w) * 0.30, 96.0)
	var stat_value_min_w := maxf(float(center_w) * 0.10, 36.0)
	var stat_bar_min_h := maxi(8, int(round(vp.y * 0.016)))
	for sid in HS4_DOSSIER_STATS:
		var srow := HBoxContainer.new()
		srow.name = "HS4StatRow_%s" % sid
		srow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		srow.add_theme_constant_override("separation", maxi(6, int(round(vp.x * 0.008))))
		srow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon: Control = game.UIIconRegistry.make_icon(sid, Vector2(stat_icon_px, stat_icon_px))
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		srow.add_child(icon)
		var name_lbl := Label.new()
		name_lbl.text = str(game.PROGRESSION_DATA.STAT_NAMES.get(sid, sid))
		name_lbl.custom_minimum_size = Vector2(stat_name_min_w, 0.0)
		name_lbl.add_theme_font_size_override("font_size", stat_font_px)
		name_lbl.add_theme_color_override("font_color", Color(0.86, 0.89, 0.96, 1.0))
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		srow.add_child(name_lbl)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.custom_minimum_size = Vector2(0.0, stat_bar_min_h)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bar_bg := StyleBoxFlat.new()
		bar_bg.bg_color = Color(0.10, 0.12, 0.16, 0.85)
		bar_bg.set_corner_radius_all(maxi(2, stat_bar_min_h / 3))
		var bar_fill := StyleBoxFlat.new()
		bar_fill.bg_color = game.UIIconRegistry.ICON_COLORS.get(sid, Color(0.95, 0.78, 0.34, 1.0))
		bar_fill.set_corner_radius_all(maxi(2, stat_bar_min_h / 3))
		bar.add_theme_stylebox_override("background", bar_bg)
		bar.add_theme_stylebox_override("fill", bar_fill)
		srow.add_child(bar)
		var value_lbl := Label.new()
		value_lbl.custom_minimum_size = Vector2(stat_value_min_w, 0.0)
		value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value_lbl.add_theme_font_size_override("font_size", stat_font_px)
		value_lbl.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98, 1.0))
		value_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		srow.add_child(value_lbl)
		stats_box.add_child(srow)
		stat_bars[sid] = bar
		stat_value_labels[sid] = value_lbl

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dossier.add_child(spacer)

	var asc_box := HBoxContainer.new()
	asc_box.alignment = BoxContainer.ALIGNMENT_CENTER
	asc_box.add_theme_constant_override("separation", maxi(8, int(round(vp.x * 0.01))))
	dossier.add_child(asc_box)
	var asc_minus := _make_button("−")
	asc_minus.name = "AscensionMinusButton"
	_set_action_button_size(asc_minus, vp.x * 0.04, vp.y * 0.05)
	_apply_overhaul_2k_button_theme(asc_minus, "hs4_asc_btn", asc_minus.custom_minimum_size)
	asc_box.add_child(asc_minus)
	var asc_label := Label.new()
	asc_label.name = "AscensionLevelLabel"
	asc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	asc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	asc_label.custom_minimum_size = Vector2(vp.x * 0.13, 0.0)
	asc_label.add_theme_font_size_override("font_size", maxi(13, int(round(vp.y * 0.022))))
	asc_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.5, 1.0))
	asc_box.add_child(asc_label)
	var asc_plus := _make_button("+")
	asc_plus.name = "AscensionPlusButton"
	_set_action_button_size(asc_plus, vp.x * 0.04, vp.y * 0.05)
	_apply_overhaul_2k_button_theme(asc_plus, "hs4_asc_btn", asc_plus.custom_minimum_size)
	asc_box.add_child(asc_plus)

	var asc_mods := Label.new()
	asc_mods.name = "AscensionModsLabel"
	asc_mods.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	asc_mods.max_lines_visible = 2
	asc_mods.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	asc_mods.add_theme_font_size_override("font_size", maxi(10, int(round(vp.y * 0.017))))
	asc_mods.add_theme_color_override("font_color", Color(0.95, 0.62, 0.55, 0.95))
	dossier.add_child(asc_mods)

	var select_button := _make_button("Выбрать")
	select_button.name = "HS4ChooseButton"
	select_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_set_action_button_size(select_button, vp.x * 0.2, vp.y * 0.062)
	_apply_overhaul_2k_button_theme(select_button, "hs4_choose_btn", select_button.custom_minimum_size)
	dossier.add_child(select_button)

	var radar_panel := Panel.new()
	radar_panel.position = Vector2(mx + left_w + gap + center_w + gap, mid_y)
	radar_panel.size = Vector2(right_w, mid_h)
	radar_panel.add_theme_stylebox_override("panel", _overhaul_2k_frame_style("hs4_radar_panel", radar_panel.size))
	radar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(radar_panel)
	var radar_safe := _overhaul_2k_content_margins("hs4_radar_panel", radar_panel.size)
	var radar := HeroStatRadar.new()
	radar.name = "HS4Radar"
	radar.position = Vector2(radar_safe.x, radar_safe.y)
	radar.size = Vector2(right_w - radar_safe.x - radar_safe.z, mid_h - radar_safe.y - radar_safe.w)
	radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radar_panel.add_child(radar)

	var carousel_panel := Panel.new()
	carousel_panel.position = Vector2(mx, car_y)
	carousel_panel.size = Vector2(content_w, car_h)
	carousel_panel.add_theme_stylebox_override("panel", _overhaul_2k_frame_style("hs4_carousel_panel", carousel_panel.size))
	carousel_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(carousel_panel)
	var carousel_safe := _overhaul_2k_content_margins("hs4_carousel_panel", carousel_panel.size)
	var carousel := Control.new()
	carousel.name = "HS4Carousel"
	carousel.position = Vector2(carousel_safe.x, carousel_safe.y)
	carousel.size = Vector2(content_w - carousel_safe.x - carousel_safe.z, car_h - carousel_safe.y - carousel_safe.w)
	carousel.mouse_filter = Control.MOUSE_FILTER_PASS
	carousel_panel.add_child(carousel)
	var carousel_w: float = carousel.size.x
	var carousel_h: float = carousel.size.y
	var cpad: float = round(carousel_h * 0.1)
	var arrow_w: float = round(carousel_h * 0.5)
	var slot_h: float = carousel_h - cpad * 2.0
	var slot_w: float = slot_h
	var slot_gap: float = maxf(0.0, (carousel_w - arrow_w * 2.0 - cpad * 2.0 - slot_w * float(HS4_CAROUSEL_SLOTS)) / float(maxi(1, HS4_CAROUSEL_SLOTS - 1)))

	var left_arrow := _make_button("◄")
	left_arrow.name = "HS4CarouselPrevButton"
	_set_action_button_size(left_arrow, arrow_w, slot_h * 0.8)
	_apply_overhaul_2k_button_theme(left_arrow, "hs4_asc_btn", left_arrow.custom_minimum_size)
	left_arrow.position = Vector2(cpad, round((carousel_h - slot_h * 0.8) * 0.5))
	carousel.add_child(left_arrow)
	var right_arrow := _make_button("►")
	right_arrow.name = "HS4CarouselNextButton"
	_set_action_button_size(right_arrow, arrow_w, slot_h * 0.8)
	_apply_overhaul_2k_button_theme(right_arrow, "hs4_asc_btn", right_arrow.custom_minimum_size)
	right_arrow.position = Vector2(carousel_w - cpad - arrow_w, round((carousel_h - slot_h * 0.8) * 0.5))
	carousel.add_child(right_arrow)

	var roster: Array = game.PROGRESSION_DATA.character_ids()
	if roster.is_empty():
		return
	if not roster.has(game.selected_character_id):
		game.selected_character_id = str(roster[0])

	var slot_buttons: Array = []
	for i in range(HS4_CAROUSEL_SLOTS):
		var slot := TextureButton.new()
		slot.ignore_texture_size = true
		slot.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		slot.position = Vector2(cpad + arrow_w + i * (slot_w + slot_gap), cpad)
		slot.size = Vector2(slot_w, slot_h)
		carousel.add_child(slot)
		slot_buttons.append(slot)

	var state := {"offset": 0}
	var sel0: int = roster.find(game.selected_character_id)
	state["offset"] = clampi(sel0 - HS4_CAROUSEL_SLOTS / 2, 0, maxi(0, roster.size() - HS4_CAROUSEL_SLOTS))
	var stat_maxima := _hero_radar_global_maxima()

	var keep_selected_visible := func() -> void:
		var selected_index: int = roster.find(game.selected_character_id)
		if selected_index < 0:
			selected_index = 0
			game.selected_character_id = str(roster[0])
		var max_offset: int = maxi(0, roster.size() - HS4_CAROUSEL_SLOTS)
		if roster.size() <= HS4_CAROUSEL_SLOTS:
			state["offset"] = 0
			return
		var offset: int = int(state["offset"])
		if selected_index < offset:
			offset = selected_index
		elif selected_index >= offset + HS4_CAROUSEL_SLOTS:
			offset = selected_index - HS4_CAROUSEL_SLOTS + 1
		state["offset"] = clampi(offset, 0, max_offset)

	var refresh := func() -> void:
		keep_selected_visible.call()
		var cid: String = game.selected_character_id
		var config: Dictionary = game.PROGRESSION_DATA.character_config(cid)
		var stats: Dictionary = game.PROGRESSION_DATA.base_stats(cid)
		portrait.texture = game._cached_texture(str(config.get("sprite_path", config.get("sprite", ""))))
		name_label.text = str(config.get("title", cid))
		desc_label.text = str(config.get("description", ""))
		weapon_label.text = "Оружие: %s" % _hero_weapon_names(cid)
		# SCRUM-493: бар каждого стата масштабируется к глобальному максимуму (stat_maxima,
		# захвачен выше из _hero_radar_global_maxima); значение — справа. Не пересчитывать maxima.
		for sid in HS4_DOSSIER_STATS:
			var sval := float(stats.get(sid, 0.0))
			var smax := maxf(float(stat_maxima.get(sid, 1.0)), 1.0)
			var sbar := stat_bars[sid] as ProgressBar
			sbar.max_value = smax
			sbar.value = clampf(sval, 0.0, smax)
			(stat_value_labels[sid] as Label).text = "%d" % int(round(sval))
		var maxl: int = game.ascension_selectable_max(cid)
		game.selected_ascension_level = clampi(game.selected_ascension_level, 0, maxl)
		asc_label.text = "Возв.: %d / %d" % [game.selected_ascension_level, maxl]
		asc_mods.text = str(game.PROGRESSION_DATA.ascension_level_change_line(game.selected_ascension_level))
		radar.setup(stats, stat_maxima, game.PROGRESSION_DATA.STAT_NAMES, HERO_RADAR_STATS, HERO_CLASS_COLORS.get(cid, Color(0.95, 0.78, 0.34, 0.82)))
		var off: int = int(state["offset"])
		for i in range(HS4_CAROUSEL_SLOTS):
			var idx: int = off + i
			var slot: TextureButton = slot_buttons[i]
			if idx < roster.size():
				var rid: String = str(roster[idx])
				var rconf: Dictionary = game.PROGRESSION_DATA.character_config(rid)
				slot.texture_normal = game._cached_texture(str(rconf.get("sprite_path", rconf.get("sprite", ""))))
				slot.visible = true
				slot.modulate = Color(1.0, 1.0, 1.0, 1.0) if rid == cid else Color(0.5, 0.52, 0.58, 0.78)
			else:
				slot.visible = false

	var select_hero := func(cid: String) -> void:
		game.selected_character_id = cid
		game.selected_ascension_level = game.ascension_selectable_max(cid)
		refresh.call()

	var select_relative_hero := func(direction: int) -> void:
		var selected_index: int = roster.find(game.selected_character_id)
		if selected_index < 0:
			selected_index = 0
		var next_index: int = posmod(selected_index + direction, roster.size())
		select_hero.call(str(roster[next_index]))

	for i in range(HS4_CAROUSEL_SLOTS):
		var slot_index := i
		slot_buttons[i].pressed.connect(func() -> void:
			var idx: int = int(state["offset"]) + slot_index
			if idx < roster.size():
				select_hero.call(str(roster[idx]))
		)
	left_arrow.pressed.connect(func() -> void:
		select_relative_hero.call(-1)
	)
	right_arrow.pressed.connect(func() -> void:
		select_relative_hero.call(1)
	)
	asc_minus.pressed.connect(func() -> void:
		game.selected_ascension_level = maxi(game.selected_ascension_level - 1, 0)
		refresh.call()
	)
	asc_plus.pressed.connect(func() -> void:
		game.selected_ascension_level = mini(game.selected_ascension_level + 1, game.ascension_selectable_max(game.selected_character_id))
		refresh.call()
	)
	select_button.pressed.connect(func() -> void:
		_show_weapon_select()
	)
	game.selected_ascension_level = game.ascension_selectable_max(game.selected_character_id)
	game.ui_escape_action = _show_main_menu
	refresh.call()

func _show_character_select() -> void:
	game.clear_run_autosave()
	game.run_player_snapshot.clear()
	game.current_act = 1
	game.route_stage = 0
	game.route_selected_indices.clear()
	game.used_event_ids.clear()
	game.current_event_definition.clear()
	game.pending_event_combat.clear()
	game.shop_reentry_pending = false
	game.shop_reentry_route_stage = -1
	game.shop_reentry_branch_index = -1
	game.route_nodes = game.route._generate_route()
	_clear_current_shop_stock()
	game._clear_ui()

	# Экран выбора героя строит v4-билдер (SCRUM-470). Мёртвая v3-вёрстка удалена (SCRUM-492).
	_build_character_select_v4()


func _place_control_in_rect(control: Control, rect: Rect2) -> void:
	if control == null:
		return
	control.position = rect.position
	control.size = rect.size
	control.custom_minimum_size = rect.size


func _hero_radar_global_maxima() -> Dictionary:
	var maxima := {}
	for stat_id in HERO_RADAR_STATS:
		maxima[stat_id] = 1.0
	for character_id in game.PROGRESSION_DATA.character_ids():
		var stats: Dictionary = game.PROGRESSION_DATA.base_stats(str(character_id))
		for stat_id in HERO_RADAR_STATS:
			maxima[stat_id] = max(float(maxima.get(stat_id, 1.0)), float(stats.get(stat_id, 0.0)))
	return maxima


func _hero_weapon_names(character_id: String) -> String:
	var names := []
	for weapon_id in game.PROGRESSION_DATA.weapon_ids(character_id):
		var weapon: Dictionary = game.PROGRESSION_DATA.weapon(character_id, str(weapon_id))
		names.append(str(weapon.get("title", weapon_id)))
	return ", ".join(names)


const CODEX_DATA := preload("res://scripts/codex_data.gd")
const CODEX_SECTIONS := [
	{"id": "characters", "title": "Персонажи"},
	{"id": "monsters", "title": "Монстры"},
	{"id": "artifacts", "title": "Артефакты"},
	{"id": "stats", "title": "Характеристики"},
	{"id": "glossary", "title": "Глоссарий"},
	{"id": "ascensions", "title": "Возвышения"},
]


const ATTRIBUTE_BUY_BASE_COST := 18
const ATTRIBUTE_BUY_STAGE_COST := 6
const ATTRIBUTE_REROLL_BASE_COST := 6
const ATTRIBUTE_REROLL_STAGE_COST := 2
const ATTRIBUTE_REROLLS_PER_WINDOW := 2


func _ascension_price(base: int) -> int:
	# Ветвь Богатства мета-древа (SCRUM-150): удешевление докачки атрибутов
	# (attr_cost_mult ≤ 0). Используется только ценами докачки, не магазином.
	var skill_mods: Dictionary = game.META_PROGRESSION.skill_modifiers(game.meta_state)
	var discount := maxf(1.0 + float(skill_mods.get("attr_cost_mult", 0.0)), 0.1)
	return maxi(1, int(round(float(base) * float(game.ascension_difficulty()["price_mult"]) * discount)))


func _attribute_buy_cost() -> int:
	var scaling_stage: int = game.route_scaling_stage()
	return _ascension_price(game.PROGRESSION_DATA.stage_scaled_cost(ATTRIBUTE_BUY_BASE_COST + ATTRIBUTE_BUY_STAGE_COST * scaling_stage, scaling_stage))


func _attribute_reroll_cost() -> int:
	var scaling_stage: int = game.route_scaling_stage()
	return _ascension_price(game.PROGRESSION_DATA.stage_scaled_cost(ATTRIBUTE_REROLL_BASE_COST + ATTRIBUTE_REROLL_STAGE_COST * scaling_stage, scaling_stage))


func _show_victory_banner(on_continue: Callable) -> void:
	# Затемнение + крупная «Победа»; продолжение по клику или через 1.3с.
	var banner_layer := CanvasLayer.new()
	banner_layer.name = "VictoryBannerLayer"
	banner_layer.layer = 80
	banner_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(banner_layer)

	var continue_once := func() -> void:
		if is_instance_valid(banner_layer):
			banner_layer.queue_free()
			if on_continue.is_valid():
				on_continue.call()

	var click_catcher := Button.new()
	click_catcher.name = "VictoryBanner"
	click_catcher.flat = true
	click_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_catcher.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	click_catcher.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	click_catcher.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	click_catcher.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	click_catcher.pressed.connect(continue_once)
	banner_layer.add_child(click_catcher)

	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.012, 0.02, 0.0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	click_catcher.add_child(shade)

	var frame := PanelContainer.new()
	frame.name = "VictoryBannerFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.anchor_left = 0.5
	frame.anchor_right = 0.5
	frame.anchor_top = 0.0
	frame.anchor_bottom = 0.0
	frame.offset_left = -VBN_FRAME_2K.size.x * 0.5
	frame.offset_right = VBN_FRAME_2K.size.x * 0.5
	frame.offset_top = VBN_FRAME_2K.position.y
	frame.offset_bottom = VBN_FRAME_2K.position.y + VBN_FRAME_2K.size.y
	frame.pivot_offset = Vector2(VBN_FRAME_2K.size.x * 0.5, VBN_FRAME_2K.size.y * 0.5)
	frame.scale = Vector2(0.92, 0.92)
	frame.modulate.a = 0.0
	frame.add_theme_stylebox_override("panel", _overhaul_2k_frame_style("vbn_frame", VBN_FRAME_2K.size))
	var content_margins := _overhaul_2k_content_margins("vbn_frame", VBN_FRAME_2K.size)
	var content_rect := Rect2(
		Vector2(content_margins.x, content_margins.y),
		Vector2(
			VBN_FRAME_2K.size.x - content_margins.x - content_margins.z,
			VBN_FRAME_2K.size.y - content_margins.y - content_margins.w
		)
	)
	frame.set_meta("victory_banner_slot", "vbn_frame")
	frame.set_meta("victory_banner_content_margins", content_margins)
	frame.set_meta("victory_banner_content_rect", content_rect)
	click_catcher.add_child(frame)

	var label := Label.new()
	label.name = "VictoryBannerLabel"
	label.text = "ПОБЕДА"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 90)
	label.add_theme_color_override("font_color", Color(0.98, 0.84, 0.30, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.10, 0.05, 0.02, 1.0))
	label.add_theme_constant_override("outline_size", 8)
	frame.add_child(label)

	var tween := banner_layer.create_tween()
	tween.set_parallel(true)
	tween.tween_property(shade, "color:a", 0.66, 0.30)
	tween.tween_property(frame, "modulate:a", 1.0, 0.35)
	tween.tween_property(frame, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(1.3)
	tween.chain().tween_callback(continue_once)

	game._play_sfx("level_up")


func _random_attribute_pair() -> Array:
	var pool := ["strength", "agility", "intelligence", "perception", "energy", "knowledge", "endurance", "leadership"]
	# Ветвь Знаний мета-древа (SCRUM-150): attr_extra_options добавляет варианты
	# в окне докачки (по умолчанию 2 — обратная совместимость).
	var skill_mods: Dictionary = game.META_PROGRESSION.skill_modifiers(game.meta_state)
	var option_count: int = clampi(2 + int(skill_mods.get("attr_extra_options", 0.0)), 2, pool.size())
	var pair := []
	for _pick in range(option_count):
		var index: int = game.rng.randi_range(0, pool.size() - 1)
		pair.append(pool[index])
		pool.remove_at(index)
	return pair


func _show_attribute_shop(on_done: Callable) -> void:
	# Окно докачки после боя: 1 из 2 характеристик за деньги, reroll x2, пропуск.
	game._clear_ui()
	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "AttributeShopScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	game.ui_layer.add_child(root)
	_add_screen_background(root, "meta_progression")

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.025, 0.045, 0.92)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	# SCRUM-413: высота адаптивна (вьюпорт минус поля сверху/снизу), не фикс 660px —
	# вписывается в 1280x720 и узкие окна. Карточки опций в ScrollContainer, а кнопки
	# «Обновить»/«Пропустить» закреплены ВНЕ скролла снизу панели (SCRUM-467).
	var viewport_size: Vector2 = game.get_viewport().get_visible_rect().size
	var panel_width: float = minf(1100.0, maxf(640.0, viewport_size.x - 48.0))
	var panel_vertical_margin: float = minf(28.0, maxf(18.0, viewport_size.y * 0.045))
	var panel := PanelContainer.new()
	panel.name = "AttributeShopPanel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 1.0
	panel.offset_left = -panel_width * 0.5
	panel.offset_top = panel_vertical_margin
	panel.offset_right = panel_width * 0.5
	panel.offset_bottom = -panel_vertical_margin
	# SCRUM-568: высокая панель докачи использует per-слот attr_panel @2K-рамку
	# (1124×1384, нарисована 1:1 под слот; 9-slice тянет только плоскую середину).
	var attr_panel_display := Vector2(panel_width, maxf(1.0, viewport_size.y - panel_vertical_margin * 2.0))
	panel.add_theme_stylebox_override("panel", _overhaul_2k_frame_style("attr_panel", attr_panel_display))
	root.add_child(panel)

	var outer := VBoxContainer.new()
	outer.name = "AttributeShopOuter"
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)

	var box := VBoxContainer.new()
	box.name = "AttributeShopContent"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)

	var title := Label.new()
	title.text = "Докачка"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	box.add_child(title)

	var money_label := Label.new()
	money_label.name = "AttributeShopMoney"
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	money_label.add_theme_font_size_override("font_size", 18)
	money_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.30, 1.0))
	box.add_child(money_label)

	var offers_box := GridContainer.new()
	offers_box.name = "AttributeOffers"
	offers_box.columns = 1 if panel_width < 820.0 else 2
	offers_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	offers_box.add_theme_constant_override("h_separation", _economy_choice_row_gap(_economy_attribute_choice_display_size()))
	offers_box.add_theme_constant_override("v_separation", 14)
	box.add_child(offers_box)

	# Кнопки действий — ВНЕ скролла, закреплены снизу панели: при 4+ опциях докачки
	# (ветка Знаний мета-древа) на 720p они раньше уезжали под фолд (SCRUM-467).
	var actions := VBoxContainer.new()
	actions.name = "AttributeShopActions"
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	var compact_action_height := 54.0 if viewport_size.y <= 660.0 else 62.0
	actions.add_theme_constant_override("separation", 6 if viewport_size.y <= 660.0 else 8)
	outer.add_child(actions)

	var reroll_button := _make_button("")
	reroll_button.name = "AttributeRerollButton"
	reroll_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_set_action_button_size(reroll_button, STANDARD_ACTION_BUTTON_WIDTH, compact_action_height)
	actions.add_child(reroll_button)

	var skip_button := _make_button("Пропустить")
	skip_button.name = "AttributeSkipButton"
	skip_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_set_action_button_size(skip_button, STANDARD_ACTION_BUTTON_WIDTH, compact_action_height)
	actions.add_child(skip_button)

	# Набор и счетчик rerolls живут в game-state: переоткрытие окна (FAB)
	# не дает бесплатного реролла; сброс — только в победном флоу нового боя.
	if game.attribute_offer.is_empty():
		game.attribute_offer = _random_attribute_pair()
	skip_button.pressed.connect(func() -> void:
		if on_done.is_valid():
			on_done.call()
	)
	reroll_button.pressed.connect(func() -> void:
		if game.attribute_rerolls_left <= 0 or not _spend_run_money(_attribute_reroll_cost()):
			return
		game.attribute_rerolls_left -= 1
		game.attribute_offer = _random_attribute_pair()
		_refresh_attribute_shop(root, on_done)
	)
	game.ui_escape_action = skip_button.pressed.emit
	_refresh_attribute_shop(root, on_done)


func _refresh_attribute_shop(root: Control, on_done: Callable) -> void:
	if root == null or not is_instance_valid(root):
		return
	var offers_box := root.find_child("AttributeOffers", true, false) as Container
	var money_label := root.find_child("AttributeShopMoney", true, false) as Label
	var reroll_button := root.find_child("AttributeRerollButton", true, false) as Button
	if offers_box == null or money_label == null or reroll_button == null:
		return
	for child in offers_box.get_children():
		child.queue_free()

	var buy_cost := _attribute_buy_cost()
	var money := _run_money()
	money_label.text = "Золото: %d   |   +1 к характеристике: %d зол." % [money, buy_cost]
	reroll_button.text = "Обновить (%d зол.) — осталось %d" % [_attribute_reroll_cost(), game.attribute_rerolls_left]
	reroll_button.disabled = game.attribute_rerolls_left <= 0 or money < _attribute_reroll_cost()

	for stat_id in game.attribute_offer:
		var stat_title: String = str(game.PROGRESSION_DATA.STAT_NAMES.get(stat_id, stat_id))
		var interpretation: String = str(game.PROGRESSION_DATA.class_interpretation_text(game.selected_character_id, stat_id))
		var attr_offer_size := _economy_attribute_choice_display_size()
		var offer_button: Button = _make_economy_choice_card(stat_title, "%s\n+1 к характеристике" % interpretation, "%d зол." % buy_cost, "AttributeOffer_%s" % stat_id, attr_offer_size)
		offer_button.name = "AttributeOffer_%s" % stat_id
		# SCRUM-568: карточка опции докачи переодета в evt_card @2K-рамку (480×340, тот же
		# card-тип) и переинсечена под её content-зону — единый дарк-фэнтези стиль с Событием.
		_apply_overhaul_choice_2k_theme(offer_button, "evt_card", attr_offer_size)
		_reinset_overhaul_choice_content(offer_button, "evt_card", attr_offer_size)
		offer_button.disabled = money < buy_cost
		# SCRUM-413: недоступные (не хватает золота) карточки визуально затемнены —
		# явно видно, что купить нельзя, а не «активная, но не реагирует».
		offer_button.modulate = Color(0.5, 0.5, 0.55, 0.85) if offer_button.disabled else Color(1.0, 1.0, 1.0, 1.0)
		offer_button.tooltip_text = "%s +1\n%s" % [stat_title, interpretation]
		# SCRUM-525: в тултип — на что влияет атрибут и живой предпросмотр производных при +1.
		# Подробности держим в tooltip_text (Godot клампит его в экран сам), тело карточки
		# оставляем компактным, чтобы не ловить overflow на 720p (ui_no_overlap_matrix_test).
		var influence_text := _attribute_influence_text(stat_id)
		if influence_text != "":
			offer_button.tooltip_text += "\nВлияет на: %s" % influence_text
		var preview_lines := _attribute_upgrade_preview_lines(stat_id)
		if not preview_lines.is_empty():
			offer_button.tooltip_text += "\nПредпросмотр при +1:\n• %s" % "\n• ".join(preview_lines)
		if offer_button.disabled:
			offer_button.tooltip_text += "\nНедостаточно золота: нужно %d, есть %d." % [buy_cost, money]
		var icon_control: Control = game.UIIconRegistry.make_icon(stat_id, Vector2(30, 30))
		icon_control.name = "AttributeOfferIcon_%s" % stat_id
		icon_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_prepend_economy_choice_content(offer_button, icon_control)
		offer_button.pressed.connect(func() -> void:
			if not _spend_run_money(buy_cost):
				return
			_apply_reward_to_run({"stats": {stat_id: 1.0}})
			game.attribute_offer = []
			if on_done.is_valid():
				on_done.call()
		)
		offers_box.add_child(offer_button)


func _spend_run_money(amount: int) -> bool:
	if game.current_player != null and is_instance_valid(game.current_player):
		return game.current_player.spend_money(amount)
	var temp_player = game.combat._snapshot_player_for_menu()
	if temp_player == null:
		return false
	if not temp_player.spend_money(amount):
		temp_player.queue_free()
		return false
	game.combat._store_player_snapshot(temp_player)
	temp_player.queue_free()
	return true


func _create_upgrade_fab(root: Control, return_action: Callable, allow_attribute_shop := true) -> void:
	# При pending level-up единственная точка входа — нижняя кнопка
	# "Повышение уровня (N)" с бейджем. FAB остается только для докачки за золото.
	if game.pending_level_ups > 0:
		_update_level_up_button()
		return

	# Желтая стрелка прокачки: докачка характеристик за деньги.
	var fab := _make_compact_button("⬆")
	fab.name = "UpgradeFabButton"
	fab.custom_minimum_size = Vector2(50, 50)
	fab.anchor_left = 1.0
	fab.anchor_top = 1.0
	fab.anchor_right = 1.0
	fab.anchor_bottom = 1.0
	fab.offset_left = -88.0
	fab.offset_top = -88.0
	fab.offset_right = -24.0
	fab.offset_bottom = -24.0
	fab.add_theme_font_size_override("font_size", 30)
	_apply_compact_button_theme(fab)
	fab.tooltip_text = "Докачка характеристик за золото"
	if not allow_attribute_shop:
		fab.disabled = true
		fab.tooltip_text = "Докачка здесь недоступна"
	fab.pressed.connect(func() -> void:
		if allow_attribute_shop:
			_show_attribute_shop(return_action)
	)
	root.add_child(fab)


func _show_skill_tree_screen() -> void:
	# SCRUM-150 ч.3: общий экран древа умений из главного меню. Данные/логика —
	# META_PROGRESSION (data-driven), сохранение узлов в user://. Применение
	# эффектов к забегу — player.apply_meta_skill_modifiers (ч.2a) + старт-вайринг (ч.2b).
	game._clear_ui()
	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "SkillTreeScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	game.ui_layer.add_child(root)
	# SCRUM-569: выделенный тематичный бэкдроп «святилище умений» (дракон-колонны +
	# руны-созвездие веток, тёмный центр под панели) вместо общего codex-собора.
	_add_screen_background(root, "skill_tree")

	var main_panel := PanelContainer.new()
	main_panel.name = "SkillTreeMainPanel"
	main_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_panel.offset_left = 48.0
	main_panel.offset_top = 26.0
	main_panel.offset_right = -48.0
	main_panel.offset_bottom = -26.0
	main_panel.add_theme_stylebox_override("panel", _progression_main_panel_style())
	root.add_child(main_panel)

	var layout := VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 136.0
	layout.offset_top = 118.0
	layout.offset_right = -136.0
	layout.offset_bottom = -108.0
	layout.add_theme_constant_override("separation", 10)
	root.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	layout.add_child(header)
	var title := Label.new()
	title.text = "Древо умений"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	header.add_child(title)
	var points_label := Label.new()
	points_label.name = "SkillTreePointsLabel"
	points_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	points_label.add_theme_font_size_override("font_size", 22)
	points_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.34, 1.0))
	var points_badge := PanelContainer.new()
	points_badge.name = "SkillTreePointsBadge"
	points_badge.custom_minimum_size = Vector2(132.0, 96.0)
	points_badge.add_theme_stylebox_override("panel", _progression_points_badge_style())
	points_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(points_badge)
	points_badge.add_child(points_label)
	var back_button := _make_button("Назад в меню")
	back_button.name = "SkillTreeBackButton"
	_set_action_button_size(back_button, 260.0)
	back_button.pressed.connect(_show_main_menu)
	header.add_child(back_button)
	game.ui_escape_action = _show_main_menu

	var hint := Label.new()
	hint.name = "SkillTreeHint"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.80, 0.86, 0.92, 0.9))
	layout.add_child(hint)

	var body := HBoxContainer.new()
	body.name = "SkillTreeBody"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	layout.add_child(body)

	# SCRUM-360: прогресс ПО КЛАССУ (выбранный класс) — реиграбельность за классы.
	var class_panel := PanelContainer.new()
	class_panel.name = "SkillTreeClassPanel"
	class_panel.custom_minimum_size = Vector2(330.0, 210.0)
	class_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	class_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	class_panel.add_theme_stylebox_override("panel", _progression_class_panel_style())
	body.add_child(class_panel)
	var class_margin := MarginContainer.new()
	class_panel.add_child(class_margin)
	var class_box := VBoxContainer.new()
	class_box.add_theme_constant_override("separation", 5)
	class_margin.add_child(class_box)
	var class_header := Label.new()
	class_header.name = "SkillTreeClassHeader"
	class_header.text = "Классы"
	class_header.add_theme_font_size_override("font_size", 18)
	class_header.add_theme_color_override("font_color", Color(1.0, 0.86, 0.40, 1.0))
	class_box.add_child(class_header)
	var class_progress := Label.new()
	class_progress.name = "SkillTreeClassProgress"
	class_progress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	class_progress.add_theme_font_size_override("font_size", 15)
	class_progress.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0, 0.95))
	class_box.add_child(class_progress)
	var class_bonus_list := Label.new()
	class_bonus_list.name = "SkillTreeClassBonusList"
	class_bonus_list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	class_bonus_list.add_theme_font_size_override("font_size", 13)
	class_bonus_list.add_theme_color_override("font_color", Color(0.78, 0.94, 0.82, 0.95))
	class_box.add_child(class_bonus_list)
	var class_id := str(game.selected_character_id)
	var class_config: Dictionary = game.PROGRESSION_DATA.character_config(class_id)
	var class_title := str(class_config.get("title", class_id))
	var class_wins: int = game.META_PROGRESSION.class_boss_wins(game.meta_state, class_id)
	var class_unlocked: int = game.META_PROGRESSION.class_level(game.meta_state, class_id)
	var class_next: Dictionary = game.META_PROGRESSION.class_next_threshold(game.meta_state, class_id)
	var class_text := "«%s»: %d побед над боссами, открыто бонусов: %d/%d." % [class_title, class_wins, class_unlocked, game.META_PROGRESSION.class_progression().size()]
	if class_next.is_empty():
		class_text += " Все бонусы класса открыты."
	else:
		class_text += " Следующий бонус — на %d победах: %s (%s)." % [int(class_next.get("wins", 0)), str(class_next.get("title", "")), str(class_next.get("desc", ""))]
	class_progress.text = class_text
	var unlocked_tiers: Array = game.META_PROGRESSION.class_unlocked_tiers(game.meta_state, class_id)
	if unlocked_tiers.is_empty():
		class_bonus_list.text = "Открытых классовых бонусов пока нет. Победи босса этим героем, чтобы начать его личную ветку."
	else:
		var bonus_lines := PackedStringArray()
		for tier in unlocked_tiers:
			bonus_lines.append("%s: %s" % [str(tier.get("title", "")), str(tier.get("desc", ""))])
		class_bonus_list.text = "\n".join(bonus_lines)

	var scroll := ScrollContainer.new()
	scroll.name = "SkillTreeBranchScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var branches_row := HBoxContainer.new()
	branches_row.name = "SkillTreeBranches"
	branches_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	branches_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	branches_row.add_theme_constant_override("separation", 14)
	scroll.add_child(branches_row)

	var node_buttons: Array[Button] = []
	var refresh := func() -> void:
		var pts: int = game.META_PROGRESSION.skill_points(game.meta_state)
		points_label.text = "Очки умений: %d" % pts
		var bought: int = game.META_PROGRESSION.purchased_nodes(game.meta_state).size()
		hint.text = "Очки умений зарабатываются за победы над боссами. Открывай узлы по ветвям — следующий требует предыдущий." if (pts == 0 and bought == 0) else ""
		for nb in node_buttons:
			var node_id: String = str(nb.get_meta("node_id"))
			var status: String = game.META_PROGRESSION.node_status(game.meta_state, node_id)
			nb.disabled = status != "available"
			_apply_progression_node_button_theme(nb, status)
			var title_label := nb.get_meta("title_label") as Label
			var desc_label := nb.get_meta("desc_label") as Label
			match status:
				"purchased":
					nb.modulate = Color(0.62, 1.0, 0.66, 1.0)
					if title_label != null:
						title_label.add_theme_color_override("font_color", Color(0.62, 1.0, 0.66, 1.0))
					if desc_label != null:
						desc_label.add_theme_color_override("font_color", Color(0.78, 0.94, 0.82, 0.95))
				"available":
					nb.modulate = Color(1.0, 0.92, 0.6, 1.0)
					if title_label != null:
						title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.40, 1.0))
					if desc_label != null:
						desc_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78, 1.0))
				_:
					nb.modulate = Color(0.62, 0.64, 0.70, 0.7)
					if title_label != null:
						title_label.add_theme_color_override("font_color", Color(0.70, 0.72, 0.78, 0.9))
					if desc_label != null:
						desc_label.add_theme_color_override("font_color", Color(0.60, 0.64, 0.70, 0.82))

	for branch in game.META_PROGRESSION.SKILL_BRANCHES:
		var branch_id: String = str(branch)
		var branch_panel := PanelContainer.new()
		branch_panel.name = "SkillTreeBranchPanel_%s" % branch_id
		branch_panel.custom_minimum_size = Vector2(164.0, 430.0)
		branch_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		branch_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		branch_panel.add_theme_stylebox_override("panel", _progression_branch_panel_style())
		branches_row.add_child(branch_panel)
		var col := VBoxContainer.new()
		col.name = "SkillTreeBranchContent_%s" % branch_id
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 6)
		branch_panel.add_child(col)
		var branch_title := Label.new()
		branch_title.text = str(game.META_PROGRESSION.SKILL_BRANCH_TITLES.get(branch_id, branch_id))
		branch_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		branch_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		branch_title.add_theme_font_size_override("font_size", 17)
		branch_title.add_theme_color_override("font_color", Color(0.96, 0.88, 0.54, 1.0))
		col.add_child(branch_title)
		for node in game.META_PROGRESSION.branch_nodes(branch_id):
			var node_data: Dictionary = node
			var node_id: String = str(node_data["id"])
			var node_box := VBoxContainer.new()
			node_box.name = "SkillNodeBlock_%s" % node_id
			node_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			node_box.add_theme_constant_override("separation", 2)
			col.add_child(node_box)
			var nb := Button.new()
			nb.name = "SkillNode_%s" % node_id
			nb.text = str(int(node_data["cost"]))
			nb.tooltip_text = "%s\n%s" % [str(node_data["title"]), str(node_data["desc"])]
			nb.custom_minimum_size = Vector2(74.0, 74.0)
			nb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			nb.focus_mode = Control.FOCUS_ALL
			nb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			nb.add_theme_font_size_override("font_size", 20)
			nb.add_theme_color_override("font_color", Color(1.0, 0.92, 0.58, 1.0))
			nb.add_theme_color_override("font_disabled_color", Color(0.70, 0.72, 0.78, 0.82))
			_apply_progression_node_button_theme(nb, "locked")
			nb.set_meta("node_id", node_id)
			nb.pressed.connect(func() -> void:
				game.meta_state = game.META_PROGRESSION.buy_skill_node(game.meta_state, node_id)
				game.META_PROGRESSION.save_state(game.meta_state)
				refresh.call()
			)
			node_buttons.append(nb)
			node_box.add_child(nb)
			var node_title := Label.new()
			node_title.name = "SkillNodeTitle_%s" % node_id
			node_title.text = str(node_data["title"])
			node_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			node_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			node_title.add_theme_font_size_override("font_size", 12)
			node_title.add_theme_color_override("font_color", Color(0.82, 0.84, 0.90, 0.95))
			node_box.add_child(node_title)
			var node_desc := Label.new()
			node_desc.name = "SkillNodeDesc_%s" % node_id
			node_desc.text = str(node_data["desc"])
			node_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			node_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			node_desc.add_theme_font_size_override("font_size", 10)
			node_desc.add_theme_color_override("font_color", Color(0.70, 0.74, 0.80, 0.9))
			node_box.add_child(node_desc)
			nb.set_meta("title_label", node_title)
			nb.set_meta("desc_label", node_desc)

	refresh.call()
	if not node_buttons.is_empty():
		node_buttons[0].grab_focus()


func _show_patch_notes_screen() -> void:
	# SCRUM-159: экран «Что нового» из главного меню — data-driven патч-ноуты
	# по версиям (новейшая первой), только пользовательский русский текст.
	const PatchNotesData := preload("res://scripts/patch_notes_data.gd")
	game._clear_ui()
	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "PatchNotesScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	game.ui_layer.add_child(root)
	_add_screen_background(root, "codex")

	# SCRUM-576: полноэкранная панель-фрейм @2K (PN_PANEL_2K 2464×1388), нарисована per-слот
	# рисующим пайплайном (9-slice-safe, орнамент в margin-band). Контент — внутри content-зоны
	# панели (58/72/58/66 source→display); хедер + скролл версий не лезут на рамку.
	var panel := PanelContainer.new()
	panel.name = "PatchNotesPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = PN_PANEL_2K.position.x
	panel.offset_top = PN_PANEL_2K.position.y
	panel.offset_right = -(2560.0 - PN_PANEL_2K.end.x)
	panel.offset_bottom = -(1440.0 - PN_PANEL_2K.end.y)
	panel.add_theme_stylebox_override("panel", _overhaul_2k_frame_style("pn_panel", PN_PANEL_2K.size))
	root.add_child(panel)

	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 12)
	panel.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	layout.add_child(header)
	var title := Label.new()
	title.text = "Что нового"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	header.add_child(title)
	var back_button := _make_button("Назад в меню")
	back_button.name = "PatchNotesBackButton"
	_set_action_button_size(back_button, 260.0)
	back_button.pressed.connect(_show_main_menu)
	header.add_child(back_button)
	game.ui_escape_action = _show_main_menu

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var content := VBoxContainer.new()
	content.name = "PatchNotesContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)

	for entry in PatchNotesData.all_entries():
		var entry_data: Dictionary = entry
		var version_label := Label.new()
		version_label.name = "PatchNotesVersion_%s" % str(entry_data.get("version", "")).replace(".", "_")
		version_label.text = "Версия %s  (%s)" % [str(entry_data.get("version", "")), str(entry_data.get("date", ""))]
		version_label.add_theme_font_size_override("font_size", 24)
		version_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.40, 1.0))
		content.add_child(version_label)
		for line in (entry_data.get("highlights", []) as Array):
			var bullet := Label.new()
			bullet.text = "•  %s" % str(line)
			bullet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			bullet.add_theme_font_size_override("font_size", 16)
			bullet.add_theme_color_override("font_color", Color(0.90, 0.93, 0.98, 1.0))
			content.add_child(bullet)


func _show_codex_screen() -> void:
	game._clear_ui()
	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "CodexScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	game.ui_layer.add_child(root)

	_add_screen_background(root, "codex")

	var main_panel := PanelContainer.new()
	main_panel.name = "CodexMainPanel"
	main_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_panel.add_theme_stylebox_override("panel", _codex_v2_main_panel_style())
	root.add_child(main_panel)

	var title := Label.new()
	title.name = "CodexHeaderTitle"
	title.text = "Кодекс · Персонажи"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	root.add_child(title)

	var back_button := _make_compact_button("←")
	back_button.name = "CodexBackButton"
	_apply_overhaul_2k_button_theme(back_button, "codex_back_btn", CODEX_V2_BACK_BUTTON_SAFE.size)
	back_button.tooltip_text = "Назад в меню"
	back_button.add_theme_font_size_override("font_size", 28)
	back_button.pressed.connect(_show_main_menu)
	root.add_child(back_button)
	game.ui_escape_action = _show_main_menu

	var nav_panel := PanelContainer.new()
	nav_panel.name = "CodexNavPanel"
	nav_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nav_panel.add_theme_stylebox_override("panel", _codex_v2_nav_panel_style())
	root.add_child(nav_panel)

	var tabs_row := VBoxContainer.new()
	tabs_row.name = "CodexTabs"
	tabs_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(tabs_row)

	var content := PanelContainer.new()
	content.name = "CodexContent"
	content.add_theme_stylebox_override("panel", _codex_v2_list_panel_style())
	root.add_child(content)

	var detail_panel := PanelContainer.new()
	detail_panel.name = "CodexDetailPanel"
	detail_panel.add_theme_stylebox_override("panel", _codex_v2_detail_panel_style())
	root.add_child(detail_panel)

	content.set_meta("codex_detail_panel", detail_panel)
	content.set_meta("codex_header_title", title)
	content.set_meta("codex_tabs", tabs_row)

	var layout_entries: Array = []
	_codex_v2_register_rect(layout_entries, main_panel, CODEX_V2_OUTER_FRAME_RECT)
	_codex_v2_register_rect(layout_entries, title, CODEX_V2_HEADER_TITLE_SAFE)
	_codex_v2_register_rect(layout_entries, back_button, CODEX_V2_BACK_BUTTON_SAFE)
	_codex_v2_register_rect(layout_entries, nav_panel, CODEX_V2_NAV_PANEL_RECT)
	_codex_v2_register_rect(layout_entries, tabs_row, CODEX_V2_NAV_SAFE)
	_codex_v2_register_rect(layout_entries, content, CODEX_V2_LIST_PANEL_RECT)
	_codex_v2_register_rect(layout_entries, detail_panel, CODEX_V2_DETAIL_PANEL_RECT)

	for section in CODEX_SECTIONS:
		var section_id := str(section["id"])
		var tab_button := _make_button(str(section["title"]))
		tab_button.name = "CodexTab_%s" % section_id
		tab_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tab_button.add_theme_font_size_override("font_size", 15)
		tab_button.pressed.connect(_show_codex_section.bind(content, section_id))
		tabs_row.add_child(tab_button)

	_codex_v2_apply_layout(layout_entries)
	_codex_v2_apply_tab_metrics(tabs_row)
	root.resized.connect(func() -> void:
		_codex_v2_apply_layout(layout_entries)
		_codex_v2_apply_tab_metrics(tabs_row)
	)

	_show_codex_section(content, "characters")


func _show_codex_section(content: PanelContainer, section_id: String) -> void:
	# Ленивое построение: раздел собирается при первом открытии и кэшируется
	# внутри экрана, остальные скрываются — меню не фризит на старте.
	if content == null or not is_instance_valid(content):
		return
	var detail_panel := content.get_meta("codex_detail_panel", null) as PanelContainer
	var header_title := content.get_meta("codex_header_title", null) as Label
	var tabs_row := content.get_meta("codex_tabs", null) as Control
	if header_title != null:
		header_title.text = "Кодекс · %s" % _codex_section_title(section_id)
	_codex_update_tab_selection(tabs_row, section_id)
	for child in content.get_children():
		child.visible = false
	var existing := content.get_node_or_null("CodexSection_%s" % section_id)
	if existing != null:
		existing.visible = true
		var default_detail: Dictionary = existing.get_meta("codex_default_detail", {})
		if detail_panel != null and not default_detail.is_empty():
			_codex_update_detail(detail_panel, default_detail)
		return

	var scroll := ScrollContainer.new()
	scroll.name = "CodexSection_%s" % section_id
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	list.set_meta("codex_detail_panel", detail_panel)
	list.set_meta("codex_section_scroll", scroll)
	scroll.add_child(list)

	match section_id:
		"characters":
			_build_codex_characters(list)
		"monsters":
			_build_codex_monsters(list)
		"artifacts":
			_build_codex_artifacts(list)
		"stats":
			_build_codex_stats(list)
		"glossary":
			_build_codex_glossary(list)
		"ascensions":
			_build_codex_ascensions(list)
	var default_detail: Dictionary = scroll.get_meta("codex_default_detail", {})
	if detail_panel != null and not default_detail.is_empty():
		_codex_update_detail(detail_panel, default_detail)


func _codex_entry_panel(list: VBoxContainer, detail_data := {}) -> HBoxContainer:
	var panel := Button.new()
	panel.name = "CodexEntryCard"
	panel.text = ""
	panel.custom_minimum_size = Vector2(0.0, CODEX_V2_ENTRY_CARD_SOURCE_SIZE.y * _codex_v2_scale())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.focus_mode = Control.FOCUS_ALL
	panel.add_theme_stylebox_override("normal", _codex_entry_card_style())
	panel.add_theme_stylebox_override("hover", _codex_entry_card_style(true))
	panel.add_theme_stylebox_override("focus", _codex_entry_card_style(true))
	panel.add_theme_stylebox_override("pressed", _codex_entry_card_style(true))
	panel.add_theme_color_override("font_color", Color.TRANSPARENT)
	panel.add_theme_color_override("font_hover_color", Color.TRANSPARENT)
	panel.add_theme_color_override("font_pressed_color", Color.TRANSPARENT)
	panel.add_theme_color_override("font_focus_color", Color.TRANSPARENT)
	list.add_child(panel)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	var margins := _codex_v2_scaled_margins(CODEX_V2_ENTRY_CARD_CONTENT)
	row.offset_left = margins.x
	row.offset_top = margins.y
	row.offset_right = -margins.z
	row.offset_bottom = -margins.w
	row.add_theme_constant_override("separation", int(round(16.0 * _codex_v2_scale())))
	panel.add_child(row)
	row.set_meta("entry_button", panel)
	if detail_data is Dictionary and not (detail_data as Dictionary).is_empty():
		_codex_attach_entry_detail(list, row, detail_data)
	return row


func _codex_portrait(row: HBoxContainer, sprite_path: String, size: Vector2) -> Texture2D:
	var texture: Texture2D = null
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		texture = game._cached_texture(sprite_path)
	_codex_icon_slot(row, texture, size, "CodexPortraitSlot")
	return texture


func _codex_icon_slot(row: HBoxContainer, texture: Texture2D, size: Vector2, node_name := "CodexPortraitSlot") -> void:
	var slot := PanelContainer.new()
	slot.name = node_name
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slot_padding := Vector2(16.0, 16.0) * _codex_v2_scale()
	slot.custom_minimum_size = size + slot_padding
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.add_theme_stylebox_override("panel", _codex_portrait_slot_style())
	row.add_child(slot)
	var portrait := TextureRect.new()
	portrait.name = "%sTexture" % node_name
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.custom_minimum_size = size
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if node_name == "CodexPortraitSlot" else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = texture
	slot.add_child(portrait)


func _codex_label(parent: Control, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _codex_v2_scale(viewport_size := Vector2.ZERO) -> float:
	var size := viewport_size
	if size == Vector2.ZERO:
		size = game.get_viewport().get_visible_rect().size if game != null and game.get_viewport() != null else CODEX_V2_BASE_SIZE
	return minf(size.x / CODEX_V2_BASE_SIZE.x, size.y / CODEX_V2_BASE_SIZE.y)


func _codex_v2_scaled_margins(margins: Vector4, viewport_size := Vector2.ZERO) -> Vector4:
	var scale := _codex_v2_scale(viewport_size)
	return Vector4(
		roundf(margins.x * scale),
		roundf(margins.y * scale),
		roundf(margins.z * scale),
		roundf(margins.w * scale)
	)


func _codex_v2_scaled_rect(base_rect: Rect2, viewport_size := Vector2.ZERO) -> Rect2:
	var size := viewport_size
	if size == Vector2.ZERO:
		size = game.get_viewport().get_visible_rect().size if game != null and game.get_viewport() != null else CODEX_V2_BASE_SIZE
	var scale := _codex_v2_scale(size)
	var offset := (size - CODEX_V2_BASE_SIZE * scale) * 0.5
	return Rect2(
		offset + base_rect.position * scale,
		base_rect.size * scale
	)


func _codex_v2_register_rect(entries: Array, control: Control, base_rect: Rect2) -> void:
	entries.append({"control": control, "rect": base_rect})


func _codex_v2_apply_layout(entries: Array) -> void:
	var viewport_size: Vector2 = game.get_viewport().get_visible_rect().size if game != null and game.get_viewport() != null else CODEX_V2_BASE_SIZE
	for entry in entries:
		var data: Dictionary = entry
		var control := data.get("control", null) as Control
		if control == null or not is_instance_valid(control):
			continue
		var rect := _codex_v2_scaled_rect(data.get("rect", Rect2()), viewport_size)
		control.set_anchors_preset(Control.PRESET_TOP_LEFT)
		control.offset_left = rect.position.x
		control.offset_top = rect.position.y
		control.offset_right = rect.position.x + rect.size.x
		control.offset_bottom = rect.position.y + rect.size.y
		control.custom_minimum_size = rect.size


func _codex_v2_apply_tab_metrics(tabs_row: VBoxContainer) -> void:
	if tabs_row == null:
		return
	var scale := _codex_v2_scale()
	var tab_size := Vector2(250.0, 86.0) * scale
	var separation: int = maxi(8, int(round(12.0 * scale)))
	tabs_row.add_theme_constant_override("separation", separation)
	for child in tabs_row.get_children():
		var button := child as Button
		if button == null:
			continue
		button.custom_minimum_size = tab_size
		button.add_theme_font_size_override("font_size", 13 if scale < 0.8 else 15)
		_apply_overhaul_2k_button_theme(button, "codex_tab_btn", tab_size)


func _codex_section_title(section_id: String) -> String:
	for section in CODEX_SECTIONS:
		if str(section.get("id", "")) == section_id:
			return str(section.get("title", section_id))
	return section_id


func _codex_update_tab_selection(tabs_row: Control, section_id: String) -> void:
	if tabs_row == null:
		return
	for child in tabs_row.get_children():
		var button := child as Button
		if button == null:
			continue
		var selected := button.name == "CodexTab_%s" % section_id
		button.modulate = Color(1.08, 0.95, 0.78, 1.0) if selected else Color.WHITE
		button.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48, 1.0) if selected else Color(0.98, 0.94, 0.78, 1.0))


func _codex_attach_entry_detail(list: VBoxContainer, row: HBoxContainer, detail_data: Dictionary) -> void:
	var button := row.get_meta("entry_button", null) as Button
	var detail_panel := list.get_meta("codex_detail_panel", null) as PanelContainer
	var scroll := list.get_meta("codex_section_scroll", null) as ScrollContainer
	if scroll != null and not scroll.has_meta("codex_default_detail"):
		scroll.set_meta("codex_default_detail", detail_data)
	if button == null or detail_panel == null:
		return
	button.set_meta("codex_detail_data", detail_data)
	button.pressed.connect(func() -> void:
		_codex_update_detail(detail_panel, detail_data)
	)


func _codex_update_detail(detail_panel: PanelContainer, detail_data: Dictionary) -> void:
	if detail_panel == null or not is_instance_valid(detail_panel):
		return
	for child in detail_panel.get_children():
		child.queue_free()
	var box := VBoxContainer.new()
	box.name = "CodexDetailContent"
	box.add_theme_constant_override("separation", int(round(14.0 * _codex_v2_scale())))
	detail_panel.add_child(box)

	var title := Label.new()
	title.name = "CodexDetailTitle"
	title.text = str(detail_data.get("title", ""))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22 if _codex_v2_scale() < 0.8 else 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42, 1.0))
	box.add_child(title)

	var texture := detail_data.get("texture", null) as Texture2D
	if texture != null:
		var portrait_slot := PanelContainer.new()
		portrait_slot.name = "CodexDetailPortraitSlot"
		var portrait_size := _codex_v2_scaled_rect(CODEX_V2_PORTRAIT_SAFE).size
		portrait_slot.custom_minimum_size = portrait_size
		portrait_slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		portrait_slot.add_theme_stylebox_override("panel", _codex_portrait_slot_style())
		box.add_child(portrait_slot)
		var portrait := TextureRect.new()
		portrait.name = "CodexDetailPortraitTexture"
		portrait.custom_minimum_size = Vector2(maxf(portrait_size.x - 36.0 * _codex_v2_scale(), 48.0), maxf(portrait_size.y - 36.0 * _codex_v2_scale(), 48.0))
		portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if bool(detail_data.get("covered_portrait", false)) else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture = texture
		portrait_slot.add_child(portrait)

	var chips: Array = detail_data.get("chips", [])
	if not chips.is_empty():
		var chip_row := HBoxContainer.new()
		chip_row.name = "CodexDetailChipRow"
		chip_row.alignment = BoxContainer.ALIGNMENT_CENTER
		chip_row.custom_minimum_size = Vector2(0.0, _codex_v2_scaled_rect(CODEX_V2_CHIP_ROW_SAFE).size.y)
		chip_row.add_theme_constant_override("separation", int(round(8.0 * _codex_v2_scale())))
		box.add_child(chip_row)
		var chip_limit := mini(4, chips.size())
		for chip_index in range(chip_limit):
			var chip_text = chips[chip_index]
			var chip := Label.new()
			chip.text = str(chip_text)
			chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			chip.add_theme_font_size_override("font_size", 12 if _codex_v2_scale() < 0.8 else 14)
			chip.add_theme_color_override("font_color", Color(0.82, 0.88, 1.0, 1.0))
			chip_row.add_child(chip)

	var term_id := str(detail_data.get("term_id", ""))
	if term_id != "":
		var glossary_button := _make_glossary_term_button(term_id, false)
		glossary_button.name = "CodexDetailGlossaryTerm_%s" % term_id
		glossary_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(glossary_button)

	var text_scroll := ScrollContainer.new()
	text_scroll.name = "CodexDetailTextScroll"
	text_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(text_scroll)
	var text_box := VBoxContainer.new()
	text_box.name = "CodexDetailTextBody"
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 7)
	text_scroll.add_child(text_box)
	var lines: Array = detail_data.get("body_lines", [])
	for line in lines:
		_codex_label(text_box, str(line), 13 if _codex_v2_scale() < 0.8 else 15, Color(0.92, 0.89, 0.80, 1.0))


func _make_glossary_term_button(term_id: String, popup_context := false) -> Button:
	var definition: Dictionary = GLOSSARY.definition(term_id)
	var button := Button.new()
	button.name = "GlossaryTerm_%s" % term_id
	button.text = str(definition.get("name", term_id))
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.tooltip_text = "" if popup_context else _glossary_tooltip_text(term_id)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color(0.92, 0.82, 0.54, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.62, 1.0))
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.mouse_entered.connect(func() -> void:
		if not popup_context or Input.is_key_pressed(KEY_ALT):
			_show_glossary_tooltip(button, term_id)
	)
	button.mouse_exited.connect(_hide_glossary_tooltip)
	button.gui_input.connect(func(event: InputEvent) -> void:
		if popup_context and event is InputEventKey and Input.is_key_pressed(KEY_ALT):
			_show_glossary_tooltip(button, term_id)
	)
	var underline := HBoxContainer.new()
	underline.name = "GlossaryDottedUnderline"
	underline.anchor_left = 0.0
	underline.anchor_top = 1.0
	underline.anchor_right = 1.0
	underline.anchor_bottom = 1.0
	underline.offset_top = -4.0
	underline.offset_bottom = -1.0
	underline.alignment = BoxContainer.ALIGNMENT_CENTER
	underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	underline.add_theme_constant_override("separation", 3)
	for dot_index in range(10):
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(3, 2)
		dot.color = Color(0.92, 0.74, 0.38, 0.95)
		underline.add_child(dot)
	button.add_child(underline)
	return button


func _glossary_tooltip_text(term_id: String) -> String:
	var definition: Dictionary = GLOSSARY.definition(term_id)
	return "%s\n%s" % [str(definition.get("name", term_id)), str(definition.get("desc", ""))]


# SCRUM-484: координатная спека @2560×1440 — тултип глоссария (транзиентный).
# Плавающая панель шириной 460, высота по контенту (заголовок + описание autowrap).
# Позиция динамическая (под якорем +8), но всегда внутри viewport с отступом 16 от
# краёв (clamp). Шаблон-размер ниже + правила размещения для рисующего скрипта.
const GT_PANEL_2K := Rect2(0, 0, 460, 140)  # w фикс, h по контенту (шаблон ~140)
const GT_PANEL_CONTENT_2K := Vector4(66, 44, 66, 40)
const GT_VIEWPORT_MARGIN_2K := 16.0  # минимальный отступ панели от краёв экрана
const GT_ANCHOR_GAP_2K := 8.0  # зазор от низа якоря до верха тултипа
const GT_TITLE_FONT_SIZE := 16
const GT_DESC_FONT_SIZE := 13
const GT_TEXT_SEPARATION := 4


func _show_glossary_tooltip(anchor: Control, term_id: String) -> void:
	_hide_glossary_tooltip()
	if game.ui_layer == null:
		return
	var definition: Dictionary = GLOSSARY.definition(term_id)
	if definition.is_empty():
		return
	var tooltip := PanelContainer.new()
	tooltip.name = "GlossaryTooltipPanel"
	tooltip.process_mode = Node.PROCESS_MODE_ALWAYS
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.custom_minimum_size = Vector2(GT_PANEL_2K.size.x, 0)
	# SCRUM-486: @2K per-слот фрейм тултипа глоссария (gt_panel 460×140; ширина фикс 460,
	# высота content-driven — 9-slice бордюры абсолютны в px, центр тянется по высоте).
	# SCRUM-585: content margins GT_PANEL_CONTENT_2K = real empty center; runtime text must
	# stay inside this zone and never cover the corner claws, ruby pins or metal rails.
	tooltip.add_theme_stylebox_override("panel", _overhaul_2k_frame_style("gt_panel", GT_PANEL_2K.size))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", GT_TEXT_SEPARATION)
	tooltip.add_child(box)
	var title := Label.new()
	title.text = str(definition.get("name", term_id))
	title.add_theme_font_size_override("font_size", GT_TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48, 1.0))
	box.add_child(title)
	var desc := Label.new()
	desc.text = str(definition.get("desc", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", GT_DESC_FONT_SIZE)
	desc.add_theme_color_override("font_color", Color(0.90, 0.88, 0.80, 1.0))
	box.add_child(desc)
	game.ui_layer.add_child(tooltip)
	var anchor_rect := anchor.get_global_rect()
	var viewport_size := anchor.get_viewport_rect().size
	tooltip.position = anchor_rect.position + Vector2(0, anchor_rect.size.y + GT_ANCHOR_GAP_2K)
	tooltip.size = Vector2(GT_PANEL_2K.size.x, 0)
	await game.get_tree().process_frame
	var rect := tooltip.get_global_rect()
	tooltip.position.x = clampf(tooltip.position.x, GT_VIEWPORT_MARGIN_2K, maxf(GT_VIEWPORT_MARGIN_2K, viewport_size.x - rect.size.x - GT_VIEWPORT_MARGIN_2K))
	tooltip.position.y = clampf(tooltip.position.y, GT_VIEWPORT_MARGIN_2K, maxf(GT_VIEWPORT_MARGIN_2K, viewport_size.y - rect.size.y - GT_VIEWPORT_MARGIN_2K))


func _hide_glossary_tooltip() -> void:
	if game.ui_layer == null:
		return
	var existing: Node = game.ui_layer.find_child("GlossaryTooltipPanel", true, false)
	if existing != null:
		existing.queue_free()


func _build_codex_characters(list: VBoxContainer) -> void:
	for character in CODEX_DATA.characters():
		var body_lines := [
			str(character["playstyle"]),
			"Сильное: %s" % character["strengths"],
			"Слабое: %s" % character["weaknesses"],
		]
		var ultimate: Dictionary = character.get("ultimate", {})
		if not ultimate.is_empty():
			body_lines.append("Ульта: %s — %s" % [ultimate.get("title", ""), ultimate.get("description", "")])
		for weapon in character["weapons"]:
			body_lines.append("• %s — %s" % [weapon["title"], weapon["description"]])
		var texture: Texture2D = null
		if str(character["sprite"]) != "" and ResourceLoader.exists(str(character["sprite"])):
			texture = game._cached_texture(str(character["sprite"]))
		var row := _codex_entry_panel(list, {
			"title": str(character["title"]),
			"texture": texture,
			"covered_portrait": true,
			"chips": ["Герой", str(character.get("id", ""))],
			"body_lines": body_lines,
		})
		_codex_portrait(row, str(character["sprite"]), Vector2(62, 62) * _codex_v2_scale())
		var text_box := VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_box.add_theme_constant_override("separation", 4)
		row.add_child(text_box)
		_codex_label(text_box, str(character["title"]), 18, Color(0.96, 0.88, 0.40, 1.0))
		_codex_label(text_box, str(character["playstyle"]), 13, Color(0.94, 0.90, 0.81, 1.0))
		_codex_label(text_box, "Сильное: %s" % character["strengths"], 12, Color(0.62, 0.88, 0.58, 1.0))


func _build_codex_monsters(list: VBoxContainer) -> void:
	var kind_titles := {"standard": "Обычные Монстры", "elite": "Элитные Монстры", "mini_elite": "Мини-элитки (свита Возвышения)", "boss": "Боссы"}
	for kind in ["standard", "elite", "mini_elite", "boss"]:
		_codex_label(list, str(kind_titles[kind]), 26, Color(0.96, 0.90, 0.68, 1.0))
		for monster in CODEX_DATA.monsters():
			if str(monster["kind"]) != kind:
				continue
			var body_lines := [str(monster["behavior"])]
			for ability in monster["abilities"]:
				body_lines.append("✦ %s — %s" % [ability["title"], ability["description"]])
			var texture: Texture2D = null
			if str(monster["sprite"]) != "" and ResourceLoader.exists(str(monster["sprite"])):
				texture = game._cached_texture(str(monster["sprite"]))
			var row := _codex_entry_panel(list, {
				"title": str(monster["title"]),
				"texture": texture,
				"covered_portrait": false,
				"chips": [str(kind_titles[kind]), str(monster["id"])],
				"body_lines": body_lines,
			})
			_codex_portrait(row, str(monster["sprite"]), Vector2(62, 62) * _codex_v2_scale())
			var text_box := VBoxContainer.new()
			text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			text_box.add_theme_constant_override("separation", 3)
			row.add_child(text_box)
			_codex_label(text_box, "%s   (%s)" % [monster["title"], monster["id"]], 17, Color(0.96, 0.88, 0.40, 1.0))
			_codex_label(text_box, str(monster["behavior"]), 12, Color(0.94, 0.90, 0.81, 1.0))


func _build_codex_artifacts(list: VBoxContainer) -> void:
	for artifact in CODEX_DATA.artifacts():
		var artifact_definition: Dictionary = game.PROGRESSION_DATA.artifact_definition(str(artifact["id"]))
		var body_lines := [str(artifact["description"])]
		var codex_note := _artifact_affinity_note(artifact_definition)
		if not codex_note.is_empty():
			body_lines.append(str(codex_note["text"]))
		var affinity_list: Array = artifact_definition.get("class_affinity", [])
		if not affinity_list.is_empty():
			var class_names := []
			for class_id in affinity_list:
				class_names.append(str(CLASS_RU.get(class_id, class_id)))
			body_lines.append("Тематика: %s" % ", ".join(class_names))
		var icon_texture := _artifact_icon_texture(str(artifact["id"]))
		var row := _codex_entry_panel(list, {
			"title": str(artifact["title"]),
			"texture": icon_texture,
			"covered_portrait": false,
			"chips": [_artifact_tier_text(artifact_definition), str(artifact["id"])],
			"body_lines": body_lines,
		})
		_codex_icon_slot(row, icon_texture, Vector2(54, 54) * _codex_v2_scale(), "CodexArtifactIconSlot")
		var text_box := VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text_box)
		_codex_label(text_box, "%s   [%s]" % [artifact["title"], _artifact_tier_text(artifact_definition)], 15, Color(0.96, 0.88, 0.40, 1.0))
		_codex_label(text_box, str(artifact["description"]), 12, Color(0.92, 0.88, 0.79, 1.0))


func _build_codex_ascensions(list: VBoxContainer) -> void:
	_codex_label(list, "Возвышения — режим усложнения (10 кумулятивных уровней)", 26, Color(0.96, 0.90, 0.68, 1.0))
	_codex_label(list, "Уровень N включает все усложнения 1..N. Повышает сложность и открывает мета-прогрессию (награда за победу над финальным боссом).", 13, Color(0.86, 0.90, 0.95, 1.0))
	for entry in CODEX_DATA.ascensions():
		var row := _codex_entry_panel(list, {
			"title": "%d. %s" % [entry["level"], entry["title"]],
			"chips": ["Возвышение", "ур. %d" % entry["level"]],
			"body_lines": [str(entry["description"])],
		})
		var text_box := VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text_box)
		_codex_label(text_box, "%d. %s" % [entry["level"], entry["title"]], 18, Color(1.0, 0.74, 0.30, 1.0))
		_codex_label(text_box, str(entry["description"]), 13, Color(0.93, 0.89, 0.80, 1.0))


func _build_codex_stats(list: VBoxContainer) -> void:
	var type_titles := {"base": "Базовые Характеристики", "derived": "Производные Параметры"}
	for stat_type in ["base", "derived"]:
		_codex_label(list, str(type_titles.get(stat_type, stat_type)), 26, Color(0.96, 0.90, 0.68, 1.0))
		for stat in CODEX_DATA.stats():
			if str(stat["type"]) != stat_type:
				continue
			var row := _codex_entry_panel(list, {
				"title": str(stat["title"]),
				"chips": [str(type_titles.get(stat_type, stat_type)), str(stat["id"])],
				"body_lines": [
					str(stat["description"]),
					"Влияет на: %s" % stat["influences"] if str(stat["influences"]) != "" else "",
				],
			})
			var icon_control: Control = game.UIIconRegistry.make_icon(str(stat["id"]), Vector2(36, 36))
			row.add_child(icon_control)
			var text_box := VBoxContainer.new()
			text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(text_box)
			_codex_label(text_box, str(stat["title"]), 17, Color(0.96, 0.88, 0.40, 1.0))
			_codex_label(text_box, str(stat["description"]), 13, Color(0.93, 0.89, 0.80, 1.0))
			if str(stat["influences"]) != "":
				_codex_label(text_box, "Влияет на: %s" % stat["influences"], 12, Color(0.70, 0.78, 0.88, 1.0))


func _build_codex_glossary(list: VBoxContainer) -> void:
	_codex_label(list, "Глоссарий терминов", 26, Color(0.96, 0.90, 0.68, 1.0))
	_codex_label(list, "Термины с пунктиром можно навести мышью. Во всплывающих окнах такие подсказки показываются только при зажатом Alt.", 13, Color(0.86, 0.90, 0.95, 1.0))
	for term_id in GLOSSARY.term_ids():
		var definition: Dictionary = GLOSSARY.definition(term_id)
		var row := _codex_entry_panel(list, {
			"title": str(definition.get("name", term_id)),
			"term_id": str(term_id),
			"chips": ["Глоссарий", str(term_id)],
			"body_lines": [str(definition.get("desc", ""))],
		})
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(box)
		box.add_child(_make_glossary_term_button(term_id, false))
		_codex_label(box, str(definition.get("desc", "")), 12, Color(0.90, 0.86, 0.76, 1.0))


func _apply_control_rect(control: Control, rect: Rect2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.position.x + rect.size.x
	control.offset_bottom = rect.position.y + rect.size.y


func _settings_v2_modal_rect() -> Rect2:
	var viewport_size := Vector2(1280.0, 720.0)
	if game != null and game.get_viewport() != null:
		viewport_size = game.get_viewport().get_visible_rect().size
	var width := clampf(roundf(viewport_size.x * 0.80), 1024.0, 2048.0)
	var height := roundf(width * 924.0 / 1536.0)
	var max_height := roundf(viewport_size.y * 0.88)
	if height > max_height:
		height = max_height
		width = roundf(height * 1536.0 / 924.0)
	return Rect2(
		Vector2(roundf((viewport_size.x - width) * 0.5), roundf((viewport_size.y - height) * 0.5)),
		Vector2(width, height)
	)


func _settings_v2_scaled_modal_rect(reference_rect: Rect2, modal_size: Vector2) -> Rect2:
	var scale := modal_size / Vector2(1536.0, 924.0)
	return Rect2(
		Vector2(roundf(reference_rect.position.x * scale.x), roundf(reference_rect.position.y * scale.y)),
		Vector2(roundf(reference_rect.size.x * scale.x), roundf(reference_rect.size.y * scale.y))
	)


func _settings_v2_tab_switcher_size(modal_size: Vector2) -> Vector2:
	var width := clampf(roundf(modal_size.x * 0.573), 640.0, 1100.0)
	var height := roundf(width / 5.0)
	return Vector2(width, height)


func _settings_v2_switcher_top(modal_size: Vector2) -> float:
	# Свитчер табов («Экран»/«Управление») ставится НИЖЕ заголовка «Настройки».
	# Заголовок прибит к верхней safe-зоне рамки (mockup y=94 ≈ локально 78–118);
	# раньше свитчер стоял на y≈40 и наезжал И на орнамент рамки, И на заголовок —
	# «Настройки» висела в пустой середине таб-бара (SCRUM-468). Теперь под ним.
	return roundf(maxf(112.0, modal_size.y * 0.172))


func _settings_v2_content_panel_rect(modal_size: Vector2) -> Rect2:
	var main_margins := _scaled_frame_margins_xy(SETTINGS_V2_MAIN_SOURCE_SIZE, modal_size, SETTINGS_V2_MAIN_CONTENT_MARGINS)
	var switcher_size := _settings_v2_tab_switcher_size(modal_size)
	var switcher_top := _settings_v2_switcher_top(modal_size)
	var top := switcher_top + switcher_size.y + roundf(maxf(18.0, modal_size.y * 0.028))
	var back_top := modal_size.y - 64.0 - maxf(28.0, modal_size.y * 0.055)
	var left := main_margins.x + 24.0
	var right := main_margins.z + 24.0
	var min_height := 180.0 if modal_size.y <= 590.0 else 248.0
	var height := maxf(min_height, back_top - top - 24.0)
	return Rect2(Vector2(left, top), Vector2(maxf(640.0, modal_size.x - left - right), height))


func _settings_v2_main_modal_style(display_size: Vector2) -> StyleBox:
	var texture_margins := _scaled_frame_margins_xy(SETTINGS_V2_MAIN_SOURCE_SIZE, display_size, SETTINGS_V2_MAIN_TEXTURE_MARGINS)
	var content_margins := _scaled_frame_margins_xy(SETTINGS_V2_MAIN_SOURCE_SIZE, display_size, SETTINGS_V2_MAIN_CONTENT_MARGINS)
	return _global_texture_style(SETTINGS_V2_MAIN_MODAL_PATH, texture_margins, Color.WHITE, content_margins, true)


func _settings_v2_content_panel_style() -> StyleBox:
	return _minimal_frame_style("panel", Color(1.0, 1.0, 1.0, 0.96))


func _settings_resolution_entries(usable_logical: Vector2i) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for resolution in game.RESOLUTION_OPTIONS:
		entries.append({
			"resolution": resolution,
			"label": "%dx%d" % [resolution.x, resolution.y],
		})
	if DisplayServer.get_name() == "macos":
		var native_resolution := DisplayResolution.native_logical_resolution(usable_logical)
		if native_resolution.x > 0 and native_resolution.y > 0:
			var duplicate := false
			for entry in entries:
				if entry["resolution"] == native_resolution:
					duplicate = true
					break
			if not duplicate:
				entries.append({
					"resolution": native_resolution,
					"label": "%dx%d (Mac)" % [native_resolution.x, native_resolution.y],
				})
	return entries


func _show_settings_menu(requested_return_origin := "") -> void:
	settings_return_origin = _resolve_settings_return_origin(str(requested_return_origin))
	game._clear_ui()

	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "SettingsV2Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.ui_layer.add_child(root)
	_add_screen_background(root, "settings")

	var modal_rect := _settings_v2_modal_rect()
	var modal := Control.new()
	modal.name = "SettingsV2Modal"
	modal.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_apply_control_rect(modal, modal_rect)
	root.add_child(modal)

	var modal_frame := PanelContainer.new()
	modal_frame.name = "SettingsV2MainModalFrame"
	modal_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_frame.add_theme_stylebox_override("panel", _settings_v2_main_modal_style(modal_rect.size))
	modal_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(modal_frame)

	var title := Label.new()
	title.name = "SettingsV2Title"
	title.text = "Настройки"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	_apply_control_rect(title, _settings_v2_scaled_modal_rect(Rect2(144.0, 94.0, 1248.0, 48.0), modal_rect.size))
	modal.add_child(title)

	var tabs := TabContainer.new()
	tabs.name = "SettingsTabs"
	tabs.custom_minimum_size = Vector2(700, 220)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.tabs_visible = false
	tabs.add_theme_font_size_override("font_size", 17)
	tabs.add_theme_color_override("font_selected_color", Color(0.98, 0.90, 0.50, 1.0))
	tabs.add_theme_color_override("font_unselected_color", Color(0.73, 0.78, 0.84, 1.0))

	var switcher_size := _settings_v2_tab_switcher_size(modal_rect.size)
	var switcher := _make_settings_tab_switcher(tabs, switcher_size)
	_apply_control_rect(switcher, Rect2(
		Vector2(roundf((modal_rect.size.x - switcher_size.x) * 0.5), _settings_v2_switcher_top(modal_rect.size)),
		switcher_size
	))
	modal.add_child(switcher)

	var content_panel := Panel.new()
	content_panel.name = "SettingsContentPanel"
	var content_panel_rect := _settings_v2_content_panel_rect(modal_rect.size)
	content_panel.add_theme_stylebox_override("panel", _settings_v2_content_panel_style())
	content_panel.clip_contents = true
	_apply_control_rect(content_panel, content_panel_rect)
	modal.add_child(content_panel)
	var content_margin := MarginContainer.new()
	content_margin.name = "SettingsContentSafe"
	content_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_margin.add_theme_constant_override("margin_left", 18)
	content_margin.add_theme_constant_override("margin_top", 14)
	content_margin.add_theme_constant_override("margin_right", 18)
	content_margin.add_theme_constant_override("margin_bottom", 14)
	content_panel.add_child(content_margin)
	content_margin.add_child(tabs)

	var screen_tab := _make_settings_tab("Экран")
	var screen_box := screen_tab.get_child(0) as VBoxContainer
	tabs.add_child(screen_tab)

	var screen_count := DisplayServer.get_screen_count()
	if screen_count > 1:
		var screen_options := OptionButton.new()
		screen_options.name = "SettingsScreenOption"
		screen_options.custom_minimum_size = Vector2(520, 62)
		screen_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_compact_button_theme(screen_options)
		for screen_index in range(screen_count):
			var size := DisplayServer.screen_get_size(screen_index)
			screen_options.add_item("Экран %d (%dx%d)" % [screen_index + 1, size.x, size.y])
		screen_options.selected = clampi(game.selected_screen_index, 0, screen_count - 1)
		screen_options.item_selected.connect(func(index: int) -> void:
			game.selected_screen_index = index
			_apply_video_settings()
			_show_settings_menu()
		)
		_add_settings_control_row(screen_box, "Монитор", screen_options)

	var resolution_options := OptionButton.new()
	resolution_options.name = "SettingsResolutionOption"
	resolution_options.custom_minimum_size = Vector2(520, 62)
	resolution_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_compact_button_theme(resolution_options)
	var usable_size := Vector2i(99999, 99999)
	var screen_full_size := Vector2i(99999, 99999)
	var screen_scale := 1.0
	if DisplayServer.get_name() != "headless":
		var res_screen := clampi(game.selected_screen_index, 0, maxi(screen_count - 1, 0))
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
	resolution_options.selected = clampi(game.selected_resolution_index, 0, resolution_entries.size() - 1)
	resolution_options.item_selected.connect(func(index: int) -> void:
		game.selected_resolution_index = index
		_apply_video_settings()
	)
	_add_settings_control_row(screen_box, "Разрешение", resolution_options)

	var mode_options := OptionButton.new()
	mode_options.name = "SettingsWindowModeOption"
	mode_options.custom_minimum_size = Vector2(520, 62)
	mode_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_compact_button_theme(mode_options)
	for mode_name in game.WINDOW_MODE_OPTIONS:
		mode_options.add_item(mode_name)
	mode_options.selected = game.selected_window_mode_index
	mode_options.item_selected.connect(func(index: int) -> void:
		game.selected_window_mode_index = index
		_apply_video_settings()
	)
	_add_settings_control_row(screen_box, "Режим окна", mode_options)

	var screen_hint := Label.new()
	screen_hint.text = "Оконные разрешения проверяются по физическим пикселям монитора; на Retina Full HD и 2K остаются доступными, если помещаются."
	screen_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen_hint.add_theme_font_size_override("font_size", 14)
	screen_hint.add_theme_color_override("font_color", Color(0.70, 0.76, 0.82, 1.0))
	screen_box.add_child(screen_hint)

	var shake_row := HBoxContainer.new()
	shake_row.name = "ScreenShakeRow"
	shake_row.add_theme_constant_override("separation", 12)
	screen_box.add_child(shake_row)
	var shake_label := Label.new()
	shake_label.text = "Тряска камеры"
	shake_label.custom_minimum_size = Vector2(220, 36)
	shake_label.add_theme_color_override("font_color", Color(0.86, 0.90, 0.96, 1.0))
	shake_row.add_child(shake_label)
	var shake_toggle := CheckBox.new()
	shake_toggle.name = "ScreenShakeToggle"
	shake_toggle.button_pressed = game.screen_shake_enabled
	_style_checkbox(shake_toggle)
	shake_toggle.toggled.connect(func(pressed: bool) -> void:
		game.screen_shake_enabled = pressed
		game.get_tree().root.set_meta("screen_shake", pressed)
		game.save_game_settings()
	)
	shake_row.add_child(shake_toggle)

	var audio_tab := _make_settings_tab("Звук")
	var audio_box := audio_tab.get_child(0) as VBoxContainer
	tabs.add_child(audio_tab)
	_add_volume_row(audio_box, "Общая громкость", "master_volume", "")
	_add_volume_row(audio_box, "Музыка", "music_volume", "music_enabled")
	_add_volume_row(audio_box, "Эффекты", "sfx_volume", "sfx_enabled")
	var reset_audio_button := _make_button("Сбросить звук по умолчанию")
	reset_audio_button.name = "SettingsResetAudioButton"
	_set_action_button_size(reset_audio_button, 420.0)
	reset_audio_button.pressed.connect(func() -> void:
		_reset_audio_to_defaults()
		_show_settings_menu()
	)
	audio_box.add_child(reset_audio_button)

	var controls_tab := _make_settings_tab("Управление")
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
	var controls_box := VBoxContainer.new()
	controls_box.name = "ControlsContent"
	controls_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_box.add_theme_constant_override("separation", 14)
	controls_scroll.add_child(controls_box)

	var aim_options := OptionButton.new()
	aim_options.name = "SettingsAimModeOption"
	aim_options.custom_minimum_size = Vector2(520, 62)
	aim_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_compact_button_theme(aim_options)
	aim_options.add_item("Автонаводка на ближайшего")
	aim_options.add_item("По курсору")
	aim_options.selected = 1 if str(game.aim_mode) == "cursor" else 0
	aim_options.item_selected.connect(func(index: int) -> void:
		game.aim_mode = "cursor" if index == 1 else "nearest"
		game.get_tree().root.set_meta("aim_mode", game.aim_mode)
		game.save_game_settings()
	)
	_add_settings_control_row(controls_box, "Прицеливание", aim_options)

	var debug_toggle := CheckBox.new()
	debug_toggle.name = "DebugModeToggle"
	debug_toggle.custom_minimum_size = Vector2(300, 42)
	debug_toggle.button_pressed = game.debug_mode_enabled
	debug_toggle.text = "Вкл. (ПКМ / Shift+ЛКМ)" if debug_toggle.button_pressed else "Выкл."
	debug_toggle.tooltip_text = "Дебаг: в бою ПКМ или Shift+ЛКМ задают точку движения, средняя кнопка телепортирует."
	_style_checkbox(debug_toggle)
	debug_toggle.toggled.connect(func(pressed: bool) -> void:
		game.debug_mode_enabled = pressed
		game.get_tree().root.set_meta("debug_mode", pressed)
		debug_toggle.text = "Вкл. (ПКМ / Shift+ЛКМ)" if pressed else "Выкл."
		game.save_game_settings()
	)
	_add_settings_control_row(controls_box, "Дебаг-режим", debug_toggle)

	var feedback_toggle := CheckBox.new()
	feedback_toggle.name = "CombatFeedbackToggle"
	feedback_toggle.custom_minimum_size = Vector2(300, 42)
	feedback_toggle.button_pressed = game.combat_feedback_enabled
	feedback_toggle.text = "Вкл." if feedback_toggle.button_pressed else "Выкл."
	feedback_toggle.tooltip_text = "Боевые цифры, крит-маркеры, вспышка попадания и зелёные числа лечения."
	_style_checkbox(feedback_toggle)
	feedback_toggle.toggled.connect(func(pressed: bool) -> void:
		game.combat_feedback_enabled = pressed
		game.get_tree().root.set_meta("combat_feedback", pressed)
		feedback_toggle.text = "Вкл." if pressed else "Выкл."
		game.save_game_settings()
	)
	_add_settings_control_row(controls_box, "Боевой фидбек", feedback_toggle)

	for input_action in game.INPUT_ACTIONS:
		var action_name: String = input_action["action"]
		var row := HBoxContainer.new()
		row.name = "BindingRow_%s" % action_name
		row.alignment = BoxContainer.ALIGNMENT_BEGIN
		row.add_theme_constant_override("separation", 12)
		controls_box.add_child(row)

		var label := Label.new()
		label.text = input_action["label"]
		label.custom_minimum_size = Vector2(170, 38)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color(0.93, 0.89, 0.80, 1.0))
		row.add_child(label)

		var bind_button := _make_compact_button(_binding_text(action_name))
		bind_button.name = "BindingButton_%s" % action_name
		bind_button.custom_minimum_size = Vector2(420, 62)
		bind_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_compact_button_theme(bind_button)
		bind_button.pressed.connect(func() -> void:
			_begin_rebind(action_name)
		)
		row.add_child(bind_button)

	var hint_label := Label.new()
	hint_label.text = "Клик по биндингу, затем нажми клавишу. Esc отменяет."
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.add_theme_color_override("font_color", Color(0.7, 0.76, 0.82, 1.0))
	controls_box.add_child(hint_label)

	var reset_button := _make_button("Сбросить управление по умолчанию")
	reset_button.name = "SettingsResetBindingsButton"
	_set_action_button_size(reset_button, 440.0)
	reset_button.pressed.connect(func() -> void:
		_reset_input_bindings_to_defaults()
		_show_settings_menu()
	)
	controls_box.add_child(reset_button)

	var settings_back := func() -> void:
		_return_from_settings()
	var back_button := _make_button("Назад")
	back_button.name = "SettingsBackButton"
	_set_action_button_size(back_button, 280.0, 64.0)
	back_button.pressed.connect(settings_back)
	var back_size := back_button.custom_minimum_size
	_apply_control_rect(back_button, Rect2(
		Vector2(roundf((modal_rect.size.x - back_size.x) * 0.5), roundf(modal_rect.size.y - back_size.y - maxf(28.0, modal_rect.size.y * 0.055))),
		back_size
	))
	modal.add_child(back_button)
	game.ui_escape_action = settings_back


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
	if return_origin == SETTINGS_RETURN_RUN_PAUSE:
		game.pending_rebind_action = ""
		game.ui_escape_action = Callable()
		if game.ui_layer != null and is_instance_valid(game.ui_layer):
			game.ui_layer.queue_free()
		game.ui_layer = null
		_show_pause_menu(true)
		return
	_show_main_menu()


func _make_settings_tab_switcher(tabs: TabContainer, display_size := Vector2.ZERO) -> Control:
	var switcher := Control.new()
	switcher.name = "SettingsTabSwitcher"
	var actual_display_size := display_size if display_size.x > 0.0 and display_size.y > 0.0 else Vector2(640.0, 128.0)
	switcher.custom_minimum_size = actual_display_size
	switcher.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	switcher.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	switcher.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var art := Panel.new()
	art.name = "SettingsTabSwitcherFrame"
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.add_theme_stylebox_override("panel", _minimal_frame_style("field"))
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	switcher.add_child(art)

	var buttons: Array[Button] = []
	var labels := ["Экран", "Звук", "Управление"]
	var content_left := roundf(actual_display_size.x * SETTINGS_TAB_SWITCHER_CONTENT.x / SETTINGS_TAB_SWITCHER_BASE_SIZE.x)
	var content_top := roundf(actual_display_size.y * SETTINGS_TAB_SWITCHER_CONTENT.y / SETTINGS_TAB_SWITCHER_BASE_SIZE.y)
	var content_right := roundf(actual_display_size.x * SETTINGS_TAB_SWITCHER_CONTENT.z / SETTINGS_TAB_SWITCHER_BASE_SIZE.x)
	var content_bottom := roundf(actual_display_size.y * SETTINGS_TAB_SWITCHER_CONTENT.w / SETTINGS_TAB_SWITCHER_BASE_SIZE.y)
	var safe_rect := Rect2(
		Vector2(content_left, content_top),
		Vector2(
			maxf(1.0, actual_display_size.x - content_left - content_right),
			maxf(1.0, actual_display_size.y - content_top - content_bottom)
		)
	)
	var tab_gap := maxf(6.0, roundf(actual_display_size.x * 0.014))
	var tab_width := maxf(1.0, (safe_rect.size.x - tab_gap * 2.0) / 3.0)
	for tab_index in range(labels.size()):
		var tab_left := safe_rect.position.x + float(tab_index) * (tab_width + tab_gap)
		var button := Button.new()
		button.name = "SettingsTabButton_%d" % tab_index
		button.text = labels[tab_index]
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.focus_mode = Control.FOCUS_ALL
		button.set_anchors_preset(Control.PRESET_TOP_LEFT)
		button.offset_left = roundf(tab_left)
		button.offset_top = roundf(safe_rect.position.y)
		button.offset_right = roundf(tab_left + tab_width)
		button.offset_bottom = roundf(safe_rect.position.y + safe_rect.size.y)
		button.add_theme_font_size_override("font_size", 12)
		button.tooltip_text = "Открыть вкладку: %s" % labels[tab_index]
		var target_tab := tab_index
		button.pressed.connect(func() -> void:
			tabs.current_tab = target_tab
		)
		switcher.add_child(button)
		buttons.append(button)

	var update_buttons := func(active_tab: int) -> void:
		for button_index in range(buttons.size()):
			_apply_settings_tab_button_theme(buttons[button_index], button_index == active_tab)
	update_buttons.call(tabs.current_tab)
	tabs.tab_changed.connect(func(tab_index: int) -> void:
		update_buttons.call(tab_index)
	)
	return switcher


func _apply_settings_tab_button_theme(button: Button, selected: bool) -> void:
	button.add_theme_stylebox_override("normal", _settings_tab_button_style(selected, false, false))
	button.add_theme_stylebox_override("hover", _settings_tab_button_style(selected, true, false))
	button.add_theme_stylebox_override("pressed", _settings_tab_button_style(selected, true, true))
	button.add_theme_stylebox_override("focus", _settings_tab_button_style(selected, true, false))
	button.add_theme_stylebox_override("disabled", _settings_tab_button_style(false, false, false))
	button.add_theme_color_override("font_color", Color(1.0, 0.88, 0.58, 1.0) if selected else Color(0.84, 0.86, 0.91, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.78, 1.0, 0.96, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.46, 0.49, 0.54, 1.0))


func _settings_tab_button_style(selected: bool, hovered: bool, pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.032, 0.040, 0.08)
	style.border_color = Color(0.74, 0.80, 0.88, 0.14)
	if selected:
		style.bg_color = Color(0.22, 0.045, 0.035, 0.34)
		style.border_color = Color(0.95, 0.82, 0.48, 0.42)
	if hovered:
		style.bg_color = Color(0.16, 0.16, 0.18, 0.38) if not selected else Color(0.28, 0.075, 0.060, 0.44)
		style.border_color = Color(0.92, 0.94, 0.98, 0.56)
	if pressed:
		style.bg_color = Color(0.05, 0.12, 0.13, 0.46)
		style.border_color = Color(0.72, 1.0, 0.96, 0.70)
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func _make_settings_tab(tab_name: String) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.name = tab_name
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	var page := VBoxContainer.new()
	page.name = "%sContent" % tab_name
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 14)
	margin.add_child(page)
	return margin


func _add_settings_control_row(parent: VBoxContainer, title: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.name = "SettingsRow_%s" % title.replace(" ", "_")
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)

	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(180, 46)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.93, 0.89, 0.80, 1.0))
	row.add_child(label)
	row.add_child(control)


func _add_volume_row(box: VBoxContainer, title: String, volume_key: String, enabled_key: String) -> void:
	var row := HBoxContainer.new()
	row.name = "VolumeRow_%s" % volume_key
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)

	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(170, 42)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.93, 0.89, 0.80, 1.0))
	row.add_child(label)

	var slider := HSlider.new()
	slider.name = "VolumeSlider_%s" % volume_key
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 2.0
	slider.custom_minimum_size = Vector2(560, 48)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_ALL
	_style_slider(slider)
	slider.value = float(game.audio_settings.get(volume_key, 1.0)) * 100.0
	slider.value_changed.connect(func(value: float) -> void:
		game.audio_settings[volume_key] = value / 100.0
		game._apply_audio_settings()
		game.save_game_settings()
	)
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(58, 42)
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.text = "%d%%" % int(slider.value)
	value_label.add_theme_color_override("font_color", Color(0.95, 0.86, 0.45, 1.0))
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = "%d%%" % int(value)
	)
	row.add_child(value_label)

	if enabled_key != "":
		var toggle := CheckBox.new()
		toggle.name = "VolumeToggle_%s" % enabled_key
		toggle.custom_minimum_size = Vector2(108, 42)
		toggle.button_pressed = bool(game.audio_settings.get(enabled_key, true))
		toggle.text = "Вкл." if toggle.button_pressed else "Выкл."
		_style_checkbox(toggle)
		slider.editable = toggle.button_pressed
		toggle.toggled.connect(func(pressed: bool) -> void:
			game.audio_settings[enabled_key] = pressed
			toggle.text = "Вкл." if pressed else "Выкл."
			slider.editable = pressed
			game._apply_audio_settings()
			game.save_game_settings()
		)
		row.add_child(toggle)


func _reset_audio_to_defaults() -> void:
	for key in ["master_volume", "music_volume", "sfx_volume", "music_enabled", "sfx_enabled"]:
		game.audio_settings[key] = game.GAME_SETTINGS.DEFAULTS[key]
	game.audio_settings["master_zero_intent"] = false
	game._apply_audio_settings()
	game.save_game_settings()


func _show_pause_menu(force := false) -> void:
	if not force and not _can_open_pause_dossier():
		return

	game.push_pause("escape_menu")
	if game.pause_overlay_layer != null and is_instance_valid(game.pause_overlay_layer):
		game.pause_overlay_layer.queue_free()
	game.pause_overlay_layer = CanvasLayer.new()
	game.pause_overlay_layer.name = "RunPauseOverlayLayer"
	game.pause_overlay_layer.layer = 120
	game.pause_overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.pause_overlay_layer)
	game.pause_stats_menu = null
	_build_run_pause_menu()


# SCRUM-484: координатная спека @2560×1440 — пауза в забеге (модалка).
# Панель _pause_end_modal_display_size("pause"): source 986×900, высота клампится в
# [520,820] → @2K = 898×820, CenterContainer центрирует. Content margins (74,94,74,86)
# скейлятся ×0.911 → safe-area ≈ (67,86,67,78). Контент: заголовок, подзаголовок,
# 5 кнопок 280×60 (separation 8). Всё внутри safe-area без наслоений.
const PM_PANEL_2K := Rect2(831, 310, 898, 820)
const PM_SAFE_2K := Rect2(898, 396, 764, 656)
const PM_TITLE_2K := Rect2(898, 509, 764, 58)
const PM_SUBTITLE_2K := Rect2(898, 575, 764, 24)
const PM_BTN_CONTINUE_2K := Rect2(1140, 607, 280, 60)
const PM_BTN_DOSSIER_2K := Rect2(1140, 675, 280, 60)
const PM_BTN_SETTINGS_2K := Rect2(1140, 743, 280, 60)
const PM_BTN_ENDRUN_2K := Rect2(1140, 811, 280, 60)
const PM_BTN_MAINMENU_2K := Rect2(1140, 879, 280, 60)


func _build_run_pause_menu() -> void:
	if game.pause_overlay_layer == null or not is_instance_valid(game.pause_overlay_layer):
		return
	for child in game.pause_overlay_layer.get_children():
		child.queue_free()

	var dim := ColorRect.new()
	dim.name = "RunPauseDim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.015, 0.025, 0.70)
	game.pause_overlay_layer.add_child(dim)

	var root := Control.new()
	root.name = "RunPauseMenuRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.pause_overlay_layer.add_child(root)

	var panel := PanelContainer.new()
	panel.name = "RunPauseMenuPanel"
	var panel_size := _pause_end_modal_display_size("pause")
	panel.custom_minimum_size = panel_size
	# SCRUM-486: @2K per-слот фрейм паузы (pm_panel 898×820). Размер панели берётся из
	# общей _pause_end_modal_display_size (на 2K ≈898×820), но стиль — собственный pm_panel,
	# чтобы НЕ трогать общий PAUSE_END_MODAL_* (его делят победа/смерть).
	panel.add_theme_stylebox_override("panel", _overhaul_2k_frame_style("pm_panel", panel_size))
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = _pause_menu_top_left_position(panel_size)
	panel.size = panel_size
	root.add_child(panel)
	root.resized.connect(func() -> void:
		if panel != null and is_instance_valid(panel):
			var next_size := _pause_end_modal_display_size("pause")
			panel.custom_minimum_size = next_size
			panel.size = next_size
			panel.position = _pause_menu_top_left_position(next_size)
	)

	var box := VBoxContainer.new()
	box.name = "RunPauseMenuContent"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var title := Label.new()
	title.name = "RunPauseMenuTitle"
	title.text = "Пауза"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "RunPauseMenuSubtitle"
	subtitle.text = "Забег поставлен на паузу"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.74, 0.82, 0.90, 1.0))
	box.add_child(subtitle)

	# SCRUM-579: 5 кнопок паузы переодеты в выделенный pm_btn @2K-фрейм (280×60),
	# нарисованный РОВНО под слот (9-slice-safe) — единый дарк-фэнтези стиль с панелью pm_panel,
	# вместо общего minimal-metal standard-кнопочного фрейма.
	var continue_button := _make_button("Продолжить")
	continue_button.name = "RunPauseContinueButton"
	_set_action_button_size(continue_button, 280.0, 60.0)
	_apply_overhaul_2k_button_theme(continue_button, "pm_btn", PM_BTN_CONTINUE_2K.size)
	continue_button.pressed.connect(_resume_game)
	box.add_child(continue_button)

	var dossier_button := _make_button("Досье персонажа")
	dossier_button.name = "RunPauseDossierButton"
	_set_action_button_size(dossier_button, 280.0, 60.0)
	_apply_overhaul_2k_button_theme(dossier_button, "pm_btn", PM_BTN_DOSSIER_2K.size)
	dossier_button.pressed.connect(_show_pause_dossier_menu)
	box.add_child(dossier_button)

	var settings_button := _make_button("Настройки")
	settings_button.name = "RunPauseSettingsButton"
	_set_action_button_size(settings_button, 280.0, 60.0)
	_apply_overhaul_2k_button_theme(settings_button, "pm_btn", PM_BTN_SETTINGS_2K.size)
	settings_button.pressed.connect(func() -> void:
		_show_settings_menu(SETTINGS_RETURN_RUN_PAUSE)
	)
	box.add_child(settings_button)

	var end_run_button := _make_button("Покинуть забег")
	end_run_button.name = "RunPauseEndRunButton"
	_set_action_button_size(end_run_button, 280.0, 60.0)
	_apply_overhaul_2k_button_theme(end_run_button, "pm_btn", PM_BTN_ENDRUN_2K.size)
	end_run_button.pressed.connect(_end_current_run_by_player)
	box.add_child(end_run_button)

	var main_menu_button := _make_button("Главное меню")
	main_menu_button.name = "RunPauseMainMenuButton"
	_set_action_button_size(main_menu_button, 280.0, 60.0)
	_apply_overhaul_2k_button_theme(main_menu_button, "pm_btn", PM_BTN_MAINMENU_2K.size)
	main_menu_button.pressed.connect(_quit_current_run)
	box.add_child(main_menu_button)


func _pause_menu_top_left_position(panel_size: Vector2) -> Vector2:
	var viewport_size: Vector2 = game.get_viewport().get_visible_rect().size
	var margin := clampf(viewport_size.y * 0.025, 18.0, 28.0)
	var max_x := maxf(margin, viewport_size.x - panel_size.x - margin)
	var max_y := maxf(margin, viewport_size.y - panel_size.y - margin)
	return Vector2(minf(margin, max_x), minf(margin, max_y))


func _show_pause_dossier_menu() -> void:
	if game.pause_overlay_layer == null or not is_instance_valid(game.pause_overlay_layer):
		return
	for child in game.pause_overlay_layer.get_children():
		child.queue_free()

	game.pause_stats_menu = game.PAUSE_STATS_MENU_SCENE.instantiate() as Control
	game.pause_overlay_layer.add_child(game.pause_stats_menu)
	if game.pause_stats_menu.has_method("setup"):
		game.pause_stats_menu.setup(_pause_dossier_player())
	game.pause_stats_menu.resume_requested.connect(_resume_game)
	game.pause_stats_menu.settings_requested.connect(func() -> void:
		_show_settings_menu(SETTINGS_RETURN_RUN_PAUSE)
	)
	game.pause_stats_menu.end_run_confirmed.connect(_end_current_run_by_player)
	game.pause_stats_menu.main_menu_requested.connect(_quit_current_run)


func _is_run_pause_overlay_open() -> bool:
	return game.pause_overlay_layer != null and is_instance_valid(game.pause_overlay_layer)


func _can_open_pause_dossier() -> bool:
	if game.combat_active:
		return true
	if game.ui_layer == null or not is_instance_valid(game.ui_layer):
		return false
	for screen_name in ["RouteMapScreen", "ShopScreen", "AttributeShopScreen", "LevelUpOverlay", "EliteArtifactRewardScreen", "EventScreen"]:
		if game.ui_layer.find_child(screen_name, true, false) != null:
			return true
	return false


func _pause_dossier_player() -> Node:
	if game.current_player != null and is_instance_valid(game.current_player):
		return game.current_player
	var temp_player: Node = game.combat._snapshot_player_for_menu()
	temp_player.set_meta("pause_dossier_temp_player", true)
	return temp_player


func _resume_game() -> void:
	game.pending_rebind_action = ""
	game.pop_pause("escape_menu")
	if game.pause_stats_menu != null and is_instance_valid(game.pause_stats_menu):
		var temp_player := game.pause_stats_menu.get("_player") as Node
		if temp_player != null and is_instance_valid(temp_player) and bool(temp_player.get_meta("pause_dossier_temp_player", false)):
			temp_player.queue_free()
	if game.pause_overlay_layer != null and is_instance_valid(game.pause_overlay_layer):
		game.pause_overlay_layer.queue_free()
	game.pause_overlay_layer = null
	game.pause_stats_menu = null


func _quit_current_run() -> void:
	game.pending_rebind_action = ""
	game._clear_all_game_pauses()
	game.combat_active = false
	game.boss_combat_active = false
	game.current_act = 1
	game.route_stage = 0
	game.run_player_snapshot.clear()
	game.route_selected_indices.clear()
	game.used_event_ids.clear()
	game.current_event_definition.clear()
	game.pending_event_combat.clear()
	game.pending_level_ups = 0
	game.current_route_choice = ""
	game.reset_run_metrics()  # SCRUM-502: метрики не текут в следующий забег
	game.route_nodes = game.route._generate_route()
	game._clear_world()
	game._clear_hud()
	_show_main_menu()


func _end_current_run_by_player() -> void:
	game.pending_rebind_action = ""
	game._clear_all_game_pauses()
	game.combat_active = false
	game.boss_combat_active = false
	# SCRUM-502: ручное завершение забега — снять метрики-финалы с живого игрока ДО очистки
	# снапшота (иначе экран итогов был бы пуст), затем причина исхода.
	if game.current_player != null and is_instance_valid(game.current_player):
		game.combat._store_player_snapshot(game.current_player)
	game.capture_run_metrics_finals(game.run_player_snapshot)
	if str(game.run_metrics.get("outcome_reason", "")) == "":
		game.run_metrics["outcome_reason"] = "Забег завершён игроком на этапе маршрута %d" % (game.route_stage + 1)
	game.run_player_snapshot.clear()
	game.route_selected_indices.clear()
	game.used_event_ids.clear()
	game.current_event_definition.clear()
	game.pending_event_combat.clear()
	game.pending_level_ups = 0
	game.current_route_choice = ""
	game._clear_world()
	game._clear_hud()
	_show_death_screen("Забег завершен игроком.")


func _add_character_button(box: Container, character_id: String, info_labels: Dictionary) -> void:
	var config: Dictionary = game.PROGRESSION_DATA.character_config(character_id)
	var stats: Dictionary = game.PROGRESSION_DATA.base_stats(character_id)
	var title := str(config.get("title", character_id))
	var description := str(config.get("description", ""))
	var strengths := str(config.get("strengths", ""))
	var weaknesses := str(config.get("weaknesses", ""))
	var stats_text: String = game.PROGRESSION_DATA.display_stats(stats)
	# Вся карточка — одна кнопка: клик в любом месте, hover подсвечивает рамку.
	var card := Button.new()
	card.name = "CharacterCard_%s" % character_id
	card.custom_minimum_size = Vector2(300, 150)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.clip_contents = true
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.tooltip_text = "%s\n%s\nСильные: %s\nСлабые: %s\n%s" % [title, description, strengths, weaknesses, stats_text]
	card.add_theme_stylebox_override("normal", _character_card_style())
	card.add_theme_stylebox_override("hover", _card_hover_style())
	card.add_theme_stylebox_override("pressed", _card_hover_style())
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	card.mouse_entered.connect(func() -> void:
		_update_hero_select_info(info_labels, title, description, strengths, weaknesses, stats_text)
	)
	card.pressed.connect(func() -> void:
		game.selected_character_id = character_id
		# Уровень возвышения клампится к открытому максимуму этого героя.
		game.selected_ascension_level = clampi(game.selected_ascension_level, 0, game.ascension_selectable_max(character_id))
		_show_weapon_select()
	)
	box.add_child(card)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(margin)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 3)
	margin.add_child(column)

	var portrait := TextureRect.new()
	portrait.name = "CharacterPortrait_%s" % character_id
	portrait.texture = game._cached_texture(str(config.get("sprite_path", "")))
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.custom_minimum_size = Vector2(0, 96)
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(portrait)

	var asc_badge := Label.new()
	asc_badge.name = "CharacterAscension_%s" % character_id
	var asc_unlocked: int = game.ascension_level_for(character_id)
	asc_badge.text = ("Возвышение %d" % asc_unlocked) if asc_unlocked > 0 else "Возвышение 0"
	asc_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	asc_badge.add_theme_font_size_override("font_size", 11)
	asc_badge.add_theme_color_override("font_color", Color(1.0, 0.74, 0.30, 0.9))
	asc_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(asc_badge)

	var title_label := Label.new()
	title_label.name = "CharacterTitle_%s" % character_id
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.38, 1.0))
	title_label.clip_text = true
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title_label)

	var style_line := _hero_card_line(description, 13, Color(0.94, 0.90, 0.81, 1.0))
	style_line.name = "CharacterStyle_%s" % character_id
	column.add_child(style_line)

	var strengths_line := _hero_card_line("Сильные: %s" % strengths, 12, Color(0.70, 0.95, 0.78, 1.0))
	strengths_line.name = "CharacterStrengths_%s" % character_id
	column.add_child(strengths_line)

	var weaknesses_line := _hero_card_line("Слабые: %s" % weaknesses, 12, Color(0.95, 0.72, 0.70, 1.0))
	weaknesses_line.name = "CharacterWeaknesses_%s" % character_id
	column.add_child(weaknesses_line)

	var ascension_level = game.ascension_level_for(character_id)
	if ascension_level > 0:
		var ascension_label := Label.new()
		ascension_label.name = "CharacterAscension_%s" % character_id
		ascension_label.text = "Возвышение: %d/%d" % [ascension_level, game.META_PROGRESSION.MAX_ASCENSION_LEVEL]  # SCRUM-516: динамический кап (5) вместо хардкода /10
		ascension_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ascension_label.add_theme_font_size_override("font_size", 11)
		ascension_label.add_theme_color_override("font_color", Color(0.78, 0.58, 1.0, 1.0))
		ascension_label.clip_text = true
		ascension_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(ascension_label)


func _hero_card_line(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _update_hero_select_info(info_labels: Dictionary, title: String, description: String, strengths: String, weaknesses: String, stats_text: String) -> void:
	var title_label := info_labels.get("title") as Label
	var description_label := info_labels.get("description") as Label
	var stats_label := info_labels.get("stats") as Label
	if title_label != null:
		title_label.text = title
	if description_label != null:
		description_label.text = "%s  |  Сильные: %s  |  Слабые: %s" % [description, strengths, weaknesses]
	if stats_label != null:
		stats_label.text = stats_text


# SCRUM-489: координатная спека @2560×1440 — экран «Выбор оружия» (economy-панель).
# Панель из _economy_menu_panel_half_size("weapon_select"): нет match-ветки → дефолт
# target 1120×660, clamp по viewport (2K не режет) → 1120×660 центр → top-left (720,390).
# Рамка _economy_panel_style() = minimal-metal "panel"; content-margins (58,72,58,66, абс. px,
# не скейлятся) → safe-area (778,462,1004,522). Контент в ScrollContainer→VBox (separation 16):
# title 42px → subtitle 17px → N карточек оружия (custom_min 860×173, EXPAND_FILL → ширина по
# safe 1004) → кнопка «Назад». Карточка — фикс высота 173, шаг = 173 + 16 = 189.
# РИСК overflow по высоте: title+subtitle+(до 4 карточек×189)+back > 522 → ScrollContainer
# скрывает вылет (берсерк = 3 оружия влезают; персонажи с 4 оружиями уходят в скролл).
const WS_DESIGN_BASE_2K := Vector2(2560.0, 1440.0)
const WS_PANEL_2K := Rect2(420, 190, 1720, 1060)
const WS_SAFE_2K := Rect2(498, 286, 1564, 898)
const WS_TITLE_2K := Rect2(498, 296, 1564, 64)
const WS_SUBTITLE_2K := Rect2(498, 376, 1564, 42)
const WS_CARD_2K := Rect2(498, 446, 1564, 190)
const WS_CARD_STEP_2K := 218.0
const WS_BTN_BACK_2K := Rect2(1140, 1120, 280, 60)


func _show_weapon_select() -> void:
	var character_config = game.PROGRESSION_DATA.character_config(game.selected_character_id)
	var box := _create_menu_box(
		"Выбор оружия",
		"%s: выбери стартовое оружие." % str(character_config["title"]),
		"weapon_select",
		_overhaul_2k_frame_style("ws_panel", WS_PANEL_2K.size),
		WS_PANEL_2K.size
	)
	box.add_theme_constant_override("separation", 24)
	for weapon_id in game.PROGRESSION_DATA.weapon_ids(game.selected_character_id):
		var config = game.PROGRESSION_DATA.weapon(game.selected_character_id, str(weapon_id))
		var button := _make_weapon_select_card(config)
		button.pressed.connect(func() -> void:
			game.selected_weapon_id = str(config["id"])
			# SCRUM-502: фактический старт нового забега (герой+оружие выбраны) — обнулить
			# метрики сводки, чтобы они не текли из прошлого прогона/autosave.
			game.reset_run_metrics()
			# SCRUM-618: между выбором оружия и стартом — пикер стартового боона.
			_show_start_boon_select()
		)
		box.add_child(button)

	var back_button := _make_button("Назад")
	back_button.name = "WeaponSelectBackButton"
	back_button.custom_minimum_size = WS_BTN_BACK_2K.size
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_apply_overhaul_2k_button_theme(back_button, "ws_btn_back", WS_BTN_BACK_2K.size)
	back_button.pressed.connect(_show_character_select)
	box.add_child(back_button)
	game.ui_escape_action = _show_character_select


func _make_weapon_select_card(config: Dictionary) -> Button:
	var weapon_id := str(config.get("id", ""))
	var button := Button.new()
	button.name = "WeaponOption_%s" % weapon_id
	button.set_meta("weapon_id", weapon_id)
	button.text = ""
	button.custom_minimum_size = WS_CARD_2K.size
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = "%s\n%s" % [str(config.get("title", weapon_id)), str(config.get("description", ""))]
	button.add_theme_stylebox_override("normal", _overhaul_2k_frame_style("ws_card", WS_CARD_2K.size))
	button.add_theme_stylebox_override("hover", _overhaul_2k_frame_style("ws_card", WS_CARD_2K.size, BUTTON_NEUTRAL_HOVER_TINT))
	button.add_theme_stylebox_override("pressed", _overhaul_2k_frame_style("ws_card", WS_CARD_2K.size, Color(0.90, 0.84, 0.76, 1.0)))
	button.add_theme_stylebox_override("focus", _overhaul_2k_frame_style("ws_card", WS_CARD_2K.size, BUTTON_NEUTRAL_HOVER_TINT))
	button.add_theme_stylebox_override("disabled", _overhaul_2k_frame_style("ws_card", WS_CARD_2K.size, Color(0.58, 0.58, 0.58, 0.82)))

	var row := HBoxContainer.new()
	row.name = "WeaponOptionContent_%s" % weapon_id
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	var card_content := _overhaul_2k_content_margins("ws_card", WS_CARD_2K.size)
	row.offset_left = card_content.x
	row.offset_top = card_content.y
	row.offset_right = -card_content.z
	row.offset_bottom = -card_content.w
	row.add_theme_constant_override("separation", 34)
	button.add_child(row)

	var sprite := TextureRect.new()
	sprite.name = "WeaponSelectSprite_%s" % weapon_id
	sprite.custom_minimum_size = Vector2(120, 120)
	sprite.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sprite.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.texture = game._cached_texture(_weapon_sprite_path(config))
	row.add_child(sprite)

	var text_box := VBoxContainer.new()
	text_box.name = "WeaponSelectText_%s" % weapon_id
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 5)
	row.add_child(text_box)

	var title_label := Label.new()
	title_label.name = "WeaponSelectTitle_%s" % weapon_id
	title_label.text = str(config.get("title", weapon_id))
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.46, 1.0))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(title_label)

	var desc_label := Label.new()
	desc_label.name = "WeaponSelectDescription_%s" % weapon_id
	desc_label.text = str(config.get("description", ""))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 20)
	desc_label.add_theme_color_override("font_color", Color(0.91, 0.88, 0.78, 1.0))
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(desc_label)

	var stats_label := Label.new()
	stats_label.name = "WeaponSelectStats_%s" % weapon_id
	stats_label.custom_minimum_size = Vector2(360, 0)
	stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.text = "Дальность %.0f\nРадиус %.0f\nПерезарядка %.2fс" % [
		float(config.get("attack_range", 0.0)),
		float(config.get("aoe_radius", 0.0)),
		float(config.get("fire_interval", 0.0)),
	]
	stats_label.add_theme_font_size_override("font_size", 18)
	stats_label.add_theme_color_override("font_color", Color(0.74, 0.92, 1.0, 1.0))
	stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(stats_label)
	return button


# SCRUM-618: пикер стартового боона. Показывает 3 случайных боона (карточный паттерн)
# между выбором оружия и стартом забега. Выбор → game.selected_start_boon_id + автосейв
# + карта. «Без боона» завершает выбор тождественно (selected_start_boon_id="").
func _show_start_boon_select() -> void:
	var all_boons: Array = game.PROGRESSION_DATA.start_boons()
	# Случайная выборка 3 без повторов (детерминирована текущим состоянием game.rng).
	var pool: Array = all_boons.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j: int = game.rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var offered: Array = pool.slice(0, mini(3, pool.size()))

	var box := _create_menu_box("Стартовый боон", "Выбери одно благословение на этот забег.", "weapon_select")
	for boon in offered:
		var boon_dict: Dictionary = boon
		var button := _make_start_boon_card(boon_dict)
		button.pressed.connect(func() -> void:
			game.selected_start_boon_id = str(boon_dict.get("id", ""))
			game.save_run_autosave("start_boon")
			game.route._show_battle_map()
		)
		box.add_child(button)

	# «Без боона» — пропустить (тождественность). Возможность не брать ничего.
	var skip_button := _make_button("Без боона")
	skip_button.pressed.connect(func() -> void:
		game.selected_start_boon_id = ""
		game.save_run_autosave("start_boon")
		game.route._show_battle_map()
	)
	box.add_child(skip_button)
	game.ui_escape_action = _show_weapon_select


func _make_start_boon_card(boon: Dictionary) -> Button:
	var boon_id := str(boon.get("id", ""))
	var button := Button.new()
	button.name = "StartBoonOption_%s" % boon_id
	button.set_meta("boon_id", boon_id)
	button.text = ""
	button.custom_minimum_size = Vector2(860, 116)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = "%s\n%s" % [str(boon.get("title", boon_id)), str(boon.get("description", ""))]
	button.add_theme_stylebox_override("normal", _weapon_card_style(false))
	button.add_theme_stylebox_override("hover", _weapon_card_style(true))
	button.add_theme_stylebox_override("pressed", _weapon_card_style(true, true))
	button.add_theme_stylebox_override("focus", _weapon_card_style(true))

	var text_box := VBoxContainer.new()
	text_box.name = "StartBoonText_%s" % boon_id
	text_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	text_box.offset_left = 22.0
	text_box.offset_top = 12.0
	text_box.offset_right = -22.0
	text_box.offset_bottom = -12.0
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_theme_constant_override("separation", 6)
	button.add_child(text_box)

	var title_label := Label.new()
	title_label.name = "StartBoonTitle_%s" % boon_id
	title_label.text = str(boon.get("title", boon_id))
	title_label.add_theme_font_size_override("font_size", 21)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.46, 1.0))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(title_label)

	var desc_label := Label.new()
	desc_label.name = "StartBoonDescription_%s" % boon_id
	desc_label.text = str(boon.get("description", ""))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.91, 0.88, 0.78, 1.0))
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(desc_label)
	return button


func _weapon_sprite_path(config: Dictionary) -> String:
	for key in ["icon_path", "sprite_path", "weapon_sprite_path"]:
		var configured_path := str(config.get(key, ""))
		if configured_path != "" and ResourceLoader.exists(configured_path):
			return configured_path
	var weapon_id := str(config.get("id", ""))
	var aliases := {
		"sword": "two_handed_sword",
		"axe": "two_handed_axe",
		"hammer": "two_handed_hammer",
	}
	var asset_id := str(aliases.get(weapon_id, weapon_id))
	var direct_path := "res://assets/sprites/weapons/%s.png" % asset_id
	if ResourceLoader.exists(direct_path):
		return direct_path
	return ""


func _show_reward_screen() -> void:
	var box := _create_menu_box("Награда за бой", "Выбери 1 из 3 усилений.", "artifact_reward")
	_create_menu_run_hud()
	var rewards_row := HBoxContainer.new()
	rewards_row.name = "BattleRewardCardsRow"
	rewards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	rewards_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rewards_row.custom_minimum_size = Vector2(0.0, REWARD_CARD_SIZE.y)
	rewards_row.add_theme_constant_override("separation", 18)
	box.add_child(rewards_row)
	var reward_buttons: Array[Button] = []
	for reward in _random_rewards(3):
		var reward_data: Dictionary = reward
		var button := _make_battle_reward_card(reward_data)
		button.name = "BattleRewardButton%d" % rewards_row.get_child_count()
		button.pressed.connect(func() -> void:
			_apply_reward_to_run(reward_data)
			game.save_run_autosave("reward_choice")
			game.route._show_battle_map()
		)
		rewards_row.add_child(button)
		reward_buttons.append(button)
	for index in range(reward_buttons.size()):
		var card := reward_buttons[index]
		var left := reward_buttons[(index - 1 + reward_buttons.size()) % reward_buttons.size()]
		var right := reward_buttons[(index + 1) % reward_buttons.size()]
		card.focus_neighbor_left = left.get_path()
		card.focus_neighbor_right = right.get_path()
		card.focus_neighbor_top = card.get_path()
		card.focus_neighbor_bottom = card.get_path()
	if not reward_buttons.is_empty():
		reward_buttons[0].grab_focus()


func _show_level_up_screen(return_to_map := false) -> void:
	game.level_up_return_to_map = return_to_map
	var layout := _level_up_layout_metrics()
	var box := _create_level_up_menu_box("Повышение уровня", "Выбери 1 из 3 усилений. Один выбор за уровень.", layout)
	if not game.combat_active:
		_create_menu_run_hud()

	# HFlowContainer: 3 карточки в ряд на широком экране, перенос на узком.
	var rewards_row := HFlowContainer.new()
	rewards_row.name = "LevelUpRewardsRow"
	rewards_row.alignment = FlowContainer.ALIGNMENT_CENTER
	rewards_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rewards_row.custom_minimum_size = Vector2(0.0, float(layout["card_size"].y))
	rewards_row.add_theme_constant_override("h_separation", int(layout["card_gap"]))
	rewards_row.add_theme_constant_override("v_separation", 8)
	box.add_child(rewards_row)

	# Набор фиксируется на полученный уровень: переоткрытие окна показывает то же.
	if game.level_up_offer.is_empty():
		game.level_up_offer = _random_level_up_rewards(3)
	var reward_buttons: Array[Button] = []
	for reward in game.level_up_offer:
		var button := _make_level_up_reward_button(reward, layout)
		button.name = "LevelUpRewardButton%d" % reward_buttons.size()
		button.pressed.connect(func() -> void:
			_apply_reward_to_active_run(reward)
			game.level_up_offer = []
			game.pending_level_ups = maxi(game.pending_level_ups - 1, 0)
			game.ui_escape_action = Callable()
			_update_level_up_button()
			if game.pending_level_ups > 0:
				_show_level_up_screen(return_to_map)
			else:
				game.level_up_return_to_map = false
				game.pop_pause("level_up")
				game._clear_ui()
				if game.combat_active:
					_create_hud()
					_update_hud()
				elif game.level_up_return_to_event and not game.current_event_definition.is_empty():
					# SCRUM-530: level-up был открыт с узла-события — возвращаемся на него.
					game.level_up_return_to_event = false
					_return_from_level_up_to_event()
				elif return_to_map or not game.combat_active:
					game.level_up_return_to_event = false
					game.save_run_autosave("level_up_choice")
					game.route._show_battle_map()
		)
		rewards_row.add_child(button)
		reward_buttons.append(button)

	# Клавиатура/геймпад: фокус по карточкам стрелками по кругу, Enter/Space выбирают.
	for index in range(reward_buttons.size()):
		var card := reward_buttons[index]
		var left := reward_buttons[(index - 1 + reward_buttons.size()) % reward_buttons.size()]
		var right := reward_buttons[(index + 1) % reward_buttons.size()]
		card.focus_neighbor_left = left.get_path()
		card.focus_neighbor_right = right.get_path()
	if not reward_buttons.is_empty():
		reward_buttons[0].grab_focus()

	# Отложенный выбор: «Позже» (и Escape) закрывают окно БЕЗ траты пика — набор
	# зафиксирован, вернуться можно кнопкой повышения внизу экрана.
	var defer_choice := func() -> void:
		game.ui_escape_action = Callable()
		game.level_up_return_to_map = false
		game.pop_pause("level_up")
		game._clear_ui()
		if game.combat_active:
			_create_hud()
			_update_hud()
			_update_level_up_button()
		elif game.level_up_return_to_event and not game.current_event_definition.is_empty():
			# SCRUM-530: «Позже»/Escape на level-up, открытом с события — пик сохранён,
			# возвращаемся на то же событие (угловая кнопка level-up появится снова).
			game.level_up_return_to_event = false
			_return_from_level_up_to_event()
		else:
			game.level_up_return_to_event = false
			game.save_run_autosave("level_up_deferred")
			game.route._show_battle_map()

	var later_button := _make_button("Позже")
	later_button.name = "LevelUpLaterButton"
	var later_button_size: Vector2 = layout.get("later_button_size", Vector2(260.0, 72.0))
	_set_action_button_size(later_button, later_button_size.x, later_button_size.y)
	later_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	later_button.tooltip_text = "Закрыть без выбора — пик сохранится, вернуться можно кнопкой повышения внизу."
	later_button.pressed.connect(defer_choice)
	box.add_child(later_button)
	game.ui_escape_action = defer_choice

	var panel := box.get_parent() as PanelContainer
	var title_label := box.get_node_or_null("LevelUpTitle") as Label
	var sparkle_root = game.ui_layer.get_node_or_null("LevelUpOverlay/LevelUpParticles") as Control
	_start_level_up_intro(panel, title_label, reward_buttons, sparkle_root)


func _show_elite_artifact_reward(on_done: Callable) -> void:
	game._clear_ui()
	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "EliteArtifactRewardScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	game.ui_layer.add_child(root)
	_add_screen_background(root, "elite_reward")

	var shade := ColorRect.new()
	shade.name = "EliteArtifactRewardShade"
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.015, 0.025, 0.76)
	root.add_child(shade)

	var center := CenterContainer.new()
	center.name = "EliteArtifactRewardCenter"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "EliteArtifactRewardPanel"
	panel.custom_minimum_size = Vector2(1140, 640)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _level_up_panel_style())
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(box)

	var title := Label.new()
	title.name = "EliteArtifactRewardTitle"
	title.text = "Трофей элитки"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.38, 1.0))
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "EliteArtifactRewardSubtitle"
	subtitle.text = "Выбери 1 из 3 артефактов. Чем глубже маршрут, тем выше шанс редкой добычи."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.86, 0.90, 0.98, 1.0))
	box.add_child(subtitle)

	var rewards_row := HBoxContainer.new()
	rewards_row.name = "EliteArtifactRewardRow"
	rewards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	rewards_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rewards_row.custom_minimum_size = Vector2(0.0, REWARD_ELITE_CARD_SIZE.y)
	rewards_row.add_theme_constant_override("separation", 22)
	box.add_child(rewards_row)

	var choices: Array = game.PROGRESSION_DATA.elite_artifact_choices(game.route_scaling_stage(), 3)
	var reward_cards: Array[Button] = []
	for reward in choices:
		var reward_data: Dictionary = reward
		var button := _make_elite_artifact_card(reward_data)
		button.name = "EliteArtifactRewardButton%d" % rewards_row.get_child_count()
		button.pressed.connect(func() -> void:
			_apply_reward_to_run(reward_data)
			game._clear_ui()
			if on_done.is_valid():
				on_done.call()
		)
		rewards_row.add_child(button)
		reward_cards.append(button)

	# Клавиатура/геймпад: стрелки двигают фокус по кругу, Enter/Space выбирают.
	for index in range(reward_cards.size()):
		var card := reward_cards[index]
		var left := reward_cards[(index - 1 + reward_cards.size()) % reward_cards.size()]
		var right := reward_cards[(index + 1) % reward_cards.size()]
		card.focus_neighbor_left = left.get_path()
		card.focus_neighbor_right = right.get_path()
		card.focus_neighbor_top = card.get_path()
		card.focus_neighbor_bottom = card.get_path()
	if not reward_cards.is_empty():
		reward_cards[0].grab_focus()

	# Выбор обязателен: Escape ничего не закрывает.
	game.ui_escape_action = Callable()
	game._play_sfx("level_up")


func _make_level_up_reward_button(reward: Dictionary, layout := {}) -> Button:
	var is_rare := bool(reward.get("rare", false))
	var rare_color: Color = TIER_COLORS[3]
	var card_size: Vector2 = layout.get("card_size", Vector2(245, 364))
	var compact := bool(layout.get("compact", false))
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = card_size
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.clip_text = false
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = _format_level_up_reward_text(reward)
	button.set_meta("level_up_text_field_card", true)
	button.add_theme_stylebox_override("normal", _level_up_text_field_style(false, is_rare))
	button.add_theme_stylebox_override("hover", _level_up_text_field_style(true, is_rare))
	button.add_theme_stylebox_override("pressed", _level_up_text_field_style(true, is_rare, true))
	button.add_theme_stylebox_override("focus", _level_up_text_field_style(true, is_rare))
	button.add_theme_stylebox_override("disabled", _level_up_text_field_style(false, is_rare, false, true))
	button.add_theme_color_override("font_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_hover_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_pressed_color", Color.TRANSPARENT)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 12.0
	content.offset_top = 10.0
	content.offset_right = -12.0
	content.offset_bottom = -10.0
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 3 if compact else 4)
	button.add_child(content)

	if is_rare:
		var rare_tag := Label.new()
		rare_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rare_tag.text = "★ ХАРАКТЕРИСТИКА"
		rare_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rare_tag.add_theme_font_size_override("font_size", 10 if compact else 12)
		rare_tag.add_theme_color_override("font_color", rare_color)
		content.add_child(rare_tag)

	var icon_row := HBoxContainer.new()
	icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(icon_row)
	icon_row.add_child(game.UIIconRegistry.make_icon(_reward_icon_id(reward), Vector2(42, 42) if compact else Vector2(56, 56)))

	var title_label := Label.new()
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.text = str(reward.get("title", "Upgrade"))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 14 if compact else 17)
	title_label.add_theme_color_override("font_color", rare_color if is_rare else Color(1.0, 0.91, 0.58, 1.0))
	content.add_child(title_label)

	var preview_label := Label.new()
	preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_label.text = _level_up_reward_preview(reward)
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_label.add_theme_font_size_override("font_size", 12 if compact else 15)
	preview_label.add_theme_color_override("font_color", Color(0.86, 0.96, 1.0, 1.0))
	content.add_child(preview_label)

	var description_label := Label.new()
	description_label.name = "LevelUpRewardDescription"
	description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description_label.text = str(reward.get("description", ""))
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override("font_size", 10 if compact else 12)
	description_label.add_theme_color_override("font_color", Color(0.64, 0.72, 0.80, 1.0))
	content.add_child(description_label)
	return button


func _make_battle_reward_card(reward: Dictionary) -> Button:
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = REWARD_CARD_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.clip_text = false
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = _format_level_up_reward_text(reward)
	button.set_meta("reward_frame_kind", "battle")
	_apply_reward_card_theme(button, false)

	var content := _add_reward_card_content_container(button, false)
	content.name = "BattleRewardCardContent"
	content.add_theme_constant_override("separation", 7)

	var icon_row := HBoxContainer.new()
	icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(icon_row)
	icon_row.add_child(game.UIIconRegistry.make_icon(_reward_icon_id(reward), Vector2(64, 64)))

	var title_label := Label.new()
	title_label.name = "BattleRewardTitle"
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.text = str(reward.get("title", "Награда"))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 17)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.58, 1.0))
	content.add_child(title_label)

	var preview_label := Label.new()
	preview_label.name = "BattleRewardPreview"
	preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_label.text = _level_up_reward_preview(reward)
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_label.add_theme_font_size_override("font_size", 14)
	preview_label.add_theme_color_override("font_color", Color(0.86, 0.96, 1.0, 1.0))
	content.add_child(preview_label)

	var description_label := Label.new()
	description_label.name = "BattleRewardDescription"
	description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description_label.text = str(reward.get("description", ""))
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override("font_size", 12)
	description_label.add_theme_color_override("font_color", Color(0.66, 0.74, 0.82, 1.0))
	content.add_child(description_label)

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.custom_minimum_size = Vector2(0.0, 4.0)
	content.add_child(spacer)

	var action_label := Label.new()
	action_label.name = "BattleRewardActionLabel"
	action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_label.text = "Получить"
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_label.add_theme_font_size_override("font_size", 15)
	action_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.64, 1.0))
	action_label.add_theme_color_override("font_outline_color", Color(0.13, 0.04, 0.035, 0.92))
	action_label.add_theme_constant_override("outline_size", 2)
	content.add_child(action_label)
	return button


func _make_elite_artifact_card(reward: Dictionary) -> Button:
	# Крупная карточка трофея элитки: иконка 112px, название/тир цветом тира,
	# эффект и классовая интерпретация. Кликается целиком, фокусируется с клавиатуры.
	var tier_color := _artifact_tier_color(reward)
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = REWARD_ELITE_CARD_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.clip_text = false
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = _format_level_up_reward_text(reward)
	button.set_meta("reward_frame_kind", "elite_artifact")
	_apply_reward_card_theme(button, true)

	var content := _add_reward_card_content_container(button, true)
	content.name = "EliteArtifactRewardContent"
	content.add_theme_constant_override("separation", 6)

	var icon_row := HBoxContainer.new()
	icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(icon_row)
	icon_row.add_child(game.UIIconRegistry.make_icon(_reward_icon_id(reward), Vector2(112, 112)))

	var title_label := Label.new()
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.text = str(reward.get("title", "Артефакт"))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", tier_color)
	content.add_child(title_label)

	var tier_label := Label.new()
	tier_label.name = "EliteArtifactRewardTier"
	tier_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tier_label.text = _artifact_tier_text(reward)
	tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_label.add_theme_font_size_override("font_size", 13)
	tier_label.add_theme_color_override("font_color", tier_color)
	content.add_child(tier_label)

	var effect_label := Label.new()
	effect_label.name = "EliteArtifactRewardDescription"
	effect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect_label.text = str(reward.get("description", ""))
	effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_label.add_theme_font_size_override("font_size", 12)
	effect_label.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0, 1.0))
	content.add_child(effect_label)

	var interpretation := _reward_interpretation_text(reward)
	if interpretation != "":
		var interp_label := Label.new()
		interp_label.name = "EliteArtifactRewardInterpretation"
		interp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		interp_label.text = interpretation
		interp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		interp_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		interp_label.add_theme_font_size_override("font_size", 11)
		interp_label.add_theme_color_override("font_color", Color(0.66, 0.74, 0.82, 1.0))
		content.add_child(interp_label)

	return button


func _resume_combat_after_level_up() -> void:
	game.pop_pause("level_up")
	game._clear_ui()
	if game.combat_active:
		_create_hud()
		_update_hud()


func _current_shop_node_key() -> String:
	var act := int(game.current_act)
	var stage := int(game.route_stage)
	var node_type := str(game.current_node_type)
	if node_type == "":
		node_type = "shop"
	var route_choice := str(game.current_route_choice)
	if route_choice == "":
		route_choice = "direct"
	return "%d:%d:%s:%s" % [act, stage, node_type, route_choice]


func _ensure_shop_stock_for_current_node() -> void:
	var node_key := _current_shop_node_key()
	if game.current_shop_node_key == "":
		game.current_shop_node_key = node_key
	var should_generate: bool = game.current_shop_items.is_empty()
	if should_generate:
		game.current_shop_items = _random_shop_items(4)
		game.current_shop_purchased.clear()
	while game.current_shop_purchased.size() < game.current_shop_items.size():
		game.current_shop_purchased.append(false)
	if game.current_shop_purchased.size() > game.current_shop_items.size():
		game.current_shop_purchased.resize(game.current_shop_items.size())


func _clear_current_shop_stock() -> void:
	game.current_shop_items.clear()
	game.current_shop_purchased.clear()
	game.current_shop_node_key = ""


func _show_shop_screen() -> void:
	_ensure_shop_stock_for_current_node()

	var money := _run_money()
	game._clear_ui()
	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "ShopScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.ui_layer.add_child(root)

	_add_screen_background(root, "shop")
	_create_menu_run_hud()
	_create_upgrade_fab(root, _show_shop_screen)

	var title_box := VBoxContainer.new()
	title_box.name = "ShopHeader"
	title_box.anchor_left = 0.5
	title_box.anchor_top = 0.0
	title_box.anchor_right = 0.5
	title_box.anchor_bottom = 0.0
	title_box.offset_left = -380.0
	title_box.offset_top = 104.0
	title_box.offset_right = 380.0
	title_box.offset_bottom = 190.0
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_box)

	var title := Label.new()
	title.text = "Магазин"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Выбери предмет. Описание появляется при наведении."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.84, 0.90, 0.96, 1.0))
	title_box.add_child(subtitle)

	# Товары лежат в центральной свободной зоне shop backdrop как предметы
	# лавки, а не как UI-карточки.
	var wall := Control.new()
	wall.name = "ShopParchmentWall"
	wall.anchor_left = 0.20
	wall.anchor_top = 0.38
	wall.anchor_right = 0.80
	wall.anchor_bottom = 0.75
	wall.offset_left = 0.0
	wall.offset_top = 0.0
	wall.offset_right = 0.0
	wall.offset_bottom = 0.0
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(wall)

	var items_area := Control.new()
	items_area.name = "ShopInlineItems"
	items_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	items_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wall.add_child(items_area)

	for index in range(game.current_shop_items.size()):
		var item: Dictionary = game.current_shop_items[index]
		var slot := _make_shop_item_slot(item, index, money)
		var slot_anchor := _shop_wall_slot_anchor(index)
		slot.anchor_left = slot_anchor.x
		slot.anchor_top = slot_anchor.y
		slot.anchor_right = slot_anchor.x
		slot.anchor_bottom = slot_anchor.y
		slot.offset_left = -SHOP_INLINE_SLOT_SIZE.x * 0.5
		slot.offset_top = -SHOP_INLINE_SLOT_SIZE.y * 0.5
		slot.offset_right = SHOP_INLINE_SLOT_SIZE.x * 0.5
		slot.offset_bottom = SHOP_INLINE_SLOT_SIZE.y * 0.5
		items_area.add_child(slot)

	var skip_button := _make_button("Назад")
	skip_button.name = "ShopLeaveButton"
	skip_button.tooltip_text = "Покинуть магазин и продолжить маршрут."
	skip_button.anchor_left = 0.5
	skip_button.anchor_top = 1.0
	skip_button.anchor_right = 0.5
	skip_button.anchor_bottom = 1.0
	skip_button.offset_left = -180.0
	skip_button.offset_top = -126.0
	skip_button.offset_right = 180.0
	skip_button.offset_bottom = -58.0
	_set_action_button_size(skip_button, 360.0)
	var leave_shop := func() -> void:
		game.route._return_to_map_after_shop_visit()
	skip_button.pressed.connect(leave_shop)
	game.ui_escape_action = leave_shop
	root.add_child(skip_button)


func _make_shop_item_slot(item: Dictionary, index: int, money: int) -> Button:
	var purchased: bool = index < game.current_shop_purchased.size() and bool(game.current_shop_purchased[index])
	var cost := int(item.get("cost", 0))
	var affordable := money >= cost
	var button := Button.new()
	button.name = "ShopItemButton%d" % index
	button.custom_minimum_size = SHOP_INLINE_SLOT_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.text = ""
	button.tooltip_text = _shop_item_tooltip(item, purchased, affordable)
	if str(item.get("kind", "")) == "artifact":
		button.tooltip_text += "\n%s" % _artifact_tier_text(item)
		var affinity_note := _artifact_affinity_note(item)
		if not affinity_note.is_empty():
			button.tooltip_text += "\n[%s]" % affinity_note["text"]
			var note_label := Label.new()
			note_label.name = "ShopAffinityNote"
			note_label.text = "!"
			note_label.tooltip_text = str(affinity_note["text"])
			note_label.add_theme_font_size_override("font_size", 22)
			note_label.add_theme_color_override("font_color", affinity_note["color"])
			note_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			note_label.offset_left = -26.0
			note_label.offset_top = 4.0
			note_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(note_label)
	button.add_theme_stylebox_override("normal", _shop_wall_button_style(false))
	button.add_theme_stylebox_override("hover", _shop_wall_button_style(true))
	button.add_theme_stylebox_override("pressed", _shop_wall_button_style(true))
	button.add_theme_stylebox_override("focus", _shop_wall_button_style(true))
	button.add_theme_stylebox_override("disabled", _shop_wall_button_style(false))
	button.pressed.connect(func() -> void:
		_buy_shop_item_at(index)
	)

	if purchased:
		button.disabled = true
		_add_shop_empty_hook(button)
		return button

	var content := Control.new()
	content.name = "ShopWallItemContent"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(content)

	var shadow := PanelContainer.new()
	shadow.name = "ShopItemContactShadow"
	shadow.anchor_left = 0.5
	shadow.anchor_top = 0.0
	shadow.anchor_right = 0.5
	shadow.anchor_bottom = 0.0
	shadow.offset_left = -46.0
	shadow.offset_top = 88.0
	shadow.offset_right = 46.0
	shadow.offset_bottom = 106.0
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.add_theme_stylebox_override("panel", _shop_item_shadow_style())
	content.add_child(shadow)

	var icon := TextureRect.new()
	icon.name = "ShopItemIcon"
	icon.texture = _shop_item_icon_texture(item)
	icon.custom_minimum_size = SHOP_INLINE_ICON_SIZE
	icon.anchor_left = 0.5
	icon.anchor_top = 0.0
	icon.anchor_right = 0.5
	icon.anchor_bottom = 0.0
	icon.offset_left = -SHOP_INLINE_ICON_SIZE.x * 0.5
	icon.offset_top = SHOP_INLINE_ICON_TOP
	icon.offset_right = SHOP_INLINE_ICON_SIZE.x * 0.5
	icon.offset_bottom = SHOP_INLINE_ICON_TOP + SHOP_INLINE_ICON_SIZE.y
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color(1.0, 1.0, 1.0, 1.0) if affordable else Color(0.52, 0.48, 0.45, 0.82)
	content.add_child(icon)

	# SCRUM-567: фикс-размерная подпись названия товара в верхней полосе слота —
	# превращает «голую стену иконок» в читаемую сетку товаров (название видно
	# сразу, полное описание по-прежнему в тултипе). Размер фиксирован
	# (SHOP_INLINE_CAPTION_SIZE), длинный текст ужимается clip в 1 строку, рамку
	# не растягивает и из слота не вылазит.
	# 9-slice плашка-нейм-плейт под подписью (отдельный ассет в едином стиле).
	var plate_texture: Texture2D = game._cached_texture(SHOP_CAPTION_PLATE_PATH)
	if plate_texture != null:
		var plate := NinePatchRect.new()
		plate.name = "ShopItemCaptionPlate"
		plate.texture = plate_texture
		plate.patch_margin_left = int(SHOP_CAPTION_PLATE_MARGINS.x)
		plate.patch_margin_top = int(SHOP_CAPTION_PLATE_MARGINS.y)
		plate.patch_margin_right = int(SHOP_CAPTION_PLATE_MARGINS.z)
		plate.patch_margin_bottom = int(SHOP_CAPTION_PLATE_MARGINS.w)
		plate.anchor_left = 0.5
		plate.anchor_top = 0.0
		plate.anchor_right = 0.5
		plate.anchor_bottom = 0.0
		plate.offset_left = -SHOP_INLINE_CAPTION_SIZE.x * 0.5
		plate.offset_top = SHOP_INLINE_CAPTION_TOP
		plate.offset_right = SHOP_INLINE_CAPTION_SIZE.x * 0.5
		plate.offset_bottom = SHOP_INLINE_CAPTION_TOP + SHOP_INLINE_CAPTION_SIZE.y
		plate.modulate = Color(1.0, 1.0, 1.0, 1.0) if affordable else Color(0.82, 0.78, 0.72, 0.82)
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(plate)

	var caption := Label.new()
	caption.name = "ShopItemCaption"
	caption.text = str(item.get("title", "Предмет"))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.clip_text = true
	# Текст ужимаем по ширине парчмент-центра плашки (≈ −16px от полной ширины).
	caption.custom_minimum_size = Vector2(SHOP_INLINE_CAPTION_SIZE.x - 16.0, SHOP_INLINE_CAPTION_SIZE.y)
	caption.anchor_left = 0.5
	caption.anchor_top = 0.0
	caption.anchor_right = 0.5
	caption.anchor_bottom = 0.0
	caption.offset_left = -(SHOP_INLINE_CAPTION_SIZE.x - 16.0) * 0.5
	caption.offset_top = SHOP_INLINE_CAPTION_TOP
	caption.offset_right = (SHOP_INLINE_CAPTION_SIZE.x - 16.0) * 0.5
	caption.offset_bottom = SHOP_INLINE_CAPTION_TOP + SHOP_INLINE_CAPTION_SIZE.y
	caption.add_theme_font_size_override("font_size", 13)
	caption.add_theme_color_override("font_color", Color(0.30, 0.20, 0.10, 1.0) if affordable else Color(0.42, 0.36, 0.30, 0.86))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(caption)

	var price_badge := PanelContainer.new()
	price_badge.name = "ShopPriceBadge"
	price_badge.anchor_left = 0.5
	price_badge.anchor_top = 1.0
	price_badge.anchor_right = 0.5
	price_badge.anchor_bottom = 1.0
	price_badge.offset_left = -64.0
	price_badge.offset_top = -52.0
	price_badge.offset_right = 64.0
	price_badge.offset_bottom = -12.0
	price_badge.custom_minimum_size = Vector2(128, 40)
	price_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_badge.add_theme_stylebox_override("panel", _shop_price_badge_style(affordable))
	content.add_child(price_badge)

	var price_row := HBoxContainer.new()
	price_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	price_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_badge.add_child(price_row)

	var money_icon := TextureRect.new()
	money_icon.name = "ShopPriceMoneyIcon"
	money_icon.texture = game.UIIconRegistry.texture_for("money")
	money_icon.custom_minimum_size = Vector2(18, 18)
	money_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	money_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	money_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_row.add_child(money_icon)

	var price_label := Label.new()
	price_label.name = "ShopItemPrice"
	price_label.text = "%d" % cost
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 18)
	price_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.34, 1.0) if affordable else Color(1.0, 0.42, 0.42, 1.0))
	price_row.add_child(price_label)

	if not affordable:
		_add_shop_state_overlay(button, "Нет монет")
	return button


func _shop_wall_slot_anchor(index: int) -> Vector2:
	var anchors := [
		Vector2(0.30, 0.18),
		Vector2(0.70, 0.18),
		Vector2(0.30, 0.84),
		Vector2(0.70, 0.84),
	]
	return anchors[index % anchors.size()]


func _add_shop_empty_hook(button: Button) -> void:
	var hook := PanelContainer.new()
	hook.name = "ShopEmptyHook"
	hook.anchor_left = 0.5
	hook.anchor_top = 0.5
	hook.anchor_right = 0.5
	hook.anchor_bottom = 0.5
	hook.offset_left = -34.0
	hook.offset_top = -18.0
	hook.offset_right = 34.0
	hook.offset_bottom = 18.0
	hook.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hook.add_theme_stylebox_override("panel", _shop_empty_hook_style())
	button.add_child(hook)

	var label := Label.new()
	label.text = "снято"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.40, 0.30, 0.20, 0.78))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hook.add_child(label)


func _add_shop_state_overlay(button: Button, text: String) -> void:
	var overlay := PanelContainer.new()
	overlay.name = "ShopItemStateOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_theme_stylebox_override("panel", _shop_purchased_overlay_style())
	button.add_child(overlay)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	overlay.add_child(label)


func _shop_item_tooltip(item: Dictionary, purchased: bool, affordable: bool) -> String:
	var lines := [
		str(item.get("title", "Предмет")),
		str(item.get("description", "")),
		"Цена: %dg" % int(item.get("cost", 0)),
	]
	var class_text := _shop_item_classes_text(item)
	if class_text != "":
		lines.append("Класс: %s" % class_text)
	if purchased:
		lines.append("Уже куплено")
	elif not affordable:
		lines.append("Не хватает монет")
	return "\n".join(lines)


func _shop_item_classes_text(item: Dictionary) -> String:
	var classes: Array = item.get("classes", [])
	if classes.is_empty():
		return ""
	var titles := []
	for character_id in classes:
		var config: Dictionary = game.PROGRESSION_DATA.character_config(str(character_id))
		titles.append(str(config.get("title", character_id)))
	return ", ".join(titles)


func _shop_item_icon_texture(item: Dictionary) -> Texture2D:
	var dedicated_path := _shop_item_icon_path(item)
	var dedicated_texture: Texture2D = game._cached_texture(dedicated_path)
	if dedicated_texture != null:
		return dedicated_texture
	return game.UIIconRegistry.texture_for(_shop_item_fallback_icon_id(item))


func _shop_item_icon_path(item: Dictionary) -> String:
	var item_id := str(item.get("id", ""))
	if item_id == "":
		return ""
	if str(item.get("kind", "")) == "artifact" or not item_id.begins_with("shop_"):
		return "%sartifact_%s.png" % [ARTIFACT_ICON_DIR, item_id]
	return "%sshop_%s.png" % [SHOP_ICON_DIR, item_id]


func _shop_item_fallback_icon_id(item: Dictionary) -> String:
	var stats: Dictionary = item.get("stats", {})
	for stat_id in game.UIIconRegistry.BASE_STAT_IDS:
		if stats.has(stat_id):
			return stat_id

	var modifiers: Dictionary = item.get("mods", {})
	if item.has("heal_percent") or modifiers.has("max_health_flat") or modifiers.has("max_health_multiplier"):
		return "health_point"
	if modifiers.has("attack_speed_multiplier"):
		return "attack_speed"
	if modifiers.has("move_speed_multiplier"):
		return "move_speed"
	if modifiers.has("pickup_radius_flat"):
		return "pickup_radius"
	if modifiers.has("range_multiplier"):
		return "attack_range"
	if modifiers.has("aoe_radius_multiplier"):
		return "aoe_radius"
	if modifiers.has("crit_chance_flat") or modifiers.has("crit_damage_flat"):
		return "crit_chance"
	if modifiers.has("defense_flat"):
		return "defense"
	if modifiers.has("summon_bonus"):
		return "summon_amount"
	if modifiers.has("knockback_multiplier"):
		return "knockback_power"

	var classes: Array = item.get("classes", [])
	if classes.has("dark_mage"):
		return "magic_damage"
	if classes.has("guitarist"):
		return "sound_wave_damage"
	if modifiers.has("money_gain_multiplier"):
		return "money"
	if modifiers.has("xp_gain_multiplier"):
		return "xp"
	if modifiers.has("damage_multiplier"):
		return "damage"
	return "artifact"


func _shop_slot_style(is_hovered: bool) -> StyleBox:
	var texture_path := SHOP_SLOT_HOVER_PATH if is_hovered else SHOP_SLOT_FRAME_PATH
	var texture_style := _shop_texture_style(texture_path, Vector2(24, 24))
	if texture_style != null:
		return texture_style

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.060, 0.105, 0.110, 0.72) if is_hovered else Color(0.035, 0.055, 0.070, 0.58)
	style.border_color = Color(0.60, 0.98, 0.92, 0.96) if is_hovered else Color(0.96, 0.75, 0.26, 0.72)
	style.set_border_width_all(2 if is_hovered else 1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_top = 10
	style.content_margin_right = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 12 if is_hovered else 6
	style.shadow_offset = Vector2(0.0, 4.0)
	return style


func _shop_wall_button_style(is_hovered: bool) -> StyleBox:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.90, 0.76, 0.38, 0.08) if is_hovered else Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(1.0, 0.86, 0.42, 0.38) if is_hovered else Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(1 if is_hovered else 0)
	style.set_corner_radius_all(18)
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	style.shadow_color = Color(1.0, 0.70, 0.24, 0.18) if is_hovered else Color(0.0, 0.0, 0.0, 0.0)
	style.shadow_size = 12 if is_hovered else 0
	return style


func _shop_item_shadow_style() -> StyleBox:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.025, 0.016, 0.38)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.set_corner_radius_all(16)
	return style


func _shop_empty_hook_style() -> StyleBox:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.075, 0.050, 0.22)
	style.border_color = Color(0.18, 0.13, 0.08, 0.42)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 6
	style.content_margin_top = 4
	style.content_margin_right = 6
	style.content_margin_bottom = 4
	return style


func _shop_price_badge_style(affordable := true) -> StyleBox:
	var display_size := Vector2(128.0, 40.0)
	var texture_margins := _scaled_frame_margins(Vector2(256.0, 96.0), display_size, ECONOMY_PRICE_BADGE_MARGINS)
	var content_margins := _scaled_frame_margins(Vector2(256.0, 96.0), display_size, ECONOMY_PRICE_BADGE_CONTENT)
	var tint := Color.WHITE if affordable else Color(0.76, 0.55, 0.55, 0.92)
	var texture_style := _global_texture_style(ECONOMY_PRICE_BADGE_PATH, texture_margins, tint, content_margins)
	if texture_style != null:
		return texture_style

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.055, 0.035, 0.78) if affordable else Color(0.20, 0.055, 0.050, 0.82)
	style.border_color = Color(0.72, 0.48, 0.16, 0.72) if affordable else Color(0.96, 0.30, 0.26, 0.76)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 5
	style.content_margin_top = 3
	style.content_margin_right = 6
	style.content_margin_bottom = 3
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0.0, 2.0)
	return style


func _shop_purchased_overlay_style() -> StyleBox:
	var texture_style := _shop_texture_style(SHOP_PURCHASED_OVERLAY_PATH, Vector2(18, 18))
	if texture_style != null:
		return texture_style

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.025, 0.030, 0.68)
	style.border_color = Color(0.36, 0.48, 0.52, 0.86)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style


func _shop_texture_style(path: String, margin: Vector2) -> StyleBoxTexture:
	var texture: Texture2D = game._cached_texture(path)
	if texture == null:
		return null
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = margin.x
	style.texture_margin_top = margin.y
	style.texture_margin_right = margin.x
	style.texture_margin_bottom = margin.y
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	return style


func _show_rest_screen() -> void:
	var box := _create_menu_box("Костер", "Восстановись или подготовься перед следующим боем.", "campfire")
	_create_menu_run_hud()
	# Escape = уйти от костра без бонуса (последовательно с пропуском магазина).
	game.ui_escape_action = game.route._advance_route_after_noncombat
	_create_upgrade_fab(box.get_parent().get_parent() if box.get_parent() != null else box, _show_rest_screen)
	var rest_card_size := _economy_choice_display_size(2)
	var choices := _make_economy_choice_row("RestChoiceRow", rest_card_size, 2)
	box.add_child(choices)
	var heal_button := _make_economy_choice_card("Передышка", "Восстановить 35% максимального здоровья.", "Отдохнуть", "RestHealButton", rest_card_size)
	choices.add_child(heal_button)
	heal_button.pressed.connect(func() -> void:
		_apply_event_choice({"title": "Rest", "description": "Recover", "heal_percent": 0.35})
		game.route._advance_route_after_noncombat()
	)

	var guard_button := _make_economy_choice_card("Защитная стойка", "Получить +6% защиты до конца забега.", "Подготовиться", "RestGuardButton", rest_card_size)
	choices.add_child(guard_button)
	guard_button.pressed.connect(func() -> void:
		_apply_reward_to_run({"title": "Защитная стойка", "description": "+6% к защите.", "mods": {"defense_flat": 0.06}})
		game.route._advance_route_after_noncombat()
	)


func _show_upgrade_screen() -> void:
	var box := _create_menu_box("Улучшение", "Выбери усиление оружия или параметра.", "upgrade", _upgrade_panel_2k_style())
	_create_menu_run_hud()
	var upgrade_card_size := _economy_choice_display_size(3)
	var choices := _make_economy_choice_row("UpgradeChoiceRow", upgrade_card_size, 3)
	box.add_child(choices)
	var index := 0
	for reward in _random_level_up_rewards(3):
		var button := _make_economy_choice_card(str(reward["title"]), str(reward["description"]), "Выбрать", "UpgradeChoiceButton%d" % index, upgrade_card_size)
		choices.add_child(button)
		button.pressed.connect(func() -> void:
			_apply_reward_to_run(reward)
			game.route._advance_route_after_noncombat()
		)
		index += 1


func _show_event_screen(route_node: Dictionary) -> void:
	var event_definition: Dictionary = {}
	if route_node.has("event_id"):
		event_definition = game.EVENT_DATA.event_by_id(str(route_node.get("event_id", "")))
	elif not game.current_event_definition.is_empty():
		# SCRUM-530: повторный вход в это же случайное (без event_id) событие — с карты,
		# после отложенного level-up или из автосейв-восстановления — НЕ рероллит набор
		# опций. current_event_definition очищается при выходе с события (выбор опции / «Назад»
		# / старт боя), поэтому непустое значение здесь = тот же незавершённый узел-событие.
		event_definition = game.current_event_definition.duplicate(true)
	if event_definition.is_empty():
		event_definition = game.EVENT_DATA.pick_event(game.used_event_ids, game.rng)
	var event_id := str(event_definition.get("id", ""))
	if event_id != "" and not game.used_event_ids.has(event_id):
		game.used_event_ids.append(event_id)
	game.current_event_definition = event_definition.duplicate(true)

	var box := _create_menu_box(str(event_definition.get("title", route_node["name"])), str(event_definition.get("story", "Странная возможность на дороге: риск, награда или оба сразу.")), "event", _event_panel_2k_style())
	_configure_event_menu_layout(box)
	var event_panel := box.get_parent().get_parent() as Control if box.get_parent() != null and box.get_parent().get_parent() != null else null
	var event_root := event_panel.get_parent() as Control if event_panel != null and event_panel.get_parent() != null else null
	if event_root != null:
		event_root.name = "EventScreen"
	_create_menu_run_hud()
	# На событии докачка недоступна: повторный вход перегенерировал бы выборы события.
	_create_upgrade_fab(box.get_parent().get_parent() if box.get_parent() != null else box, Callable(), false)
	var event_choices: Array = event_definition.get("choices", _random_event_choices())
	# Защита от тупика: пустой/битый набор выборов не должен оставлять серый экран без
	# опций. Подставляем процедурные выборы, чтобы экран всегда был кликабельным.
	if event_choices.is_empty():
		event_choices = _random_event_choices()
	var event_card_size := _economy_choice_display_size(3)
	var choices := _make_economy_choice_row("EventChoiceRow", event_card_size, 3)
	box.add_child(choices)
	var selectable_buttons: Array[Button] = []
	var index := 0
	for event_choice in event_choices:
		var title_text := str(event_choice.get("title", "Выбор"))
		var desc_text := _event_choice_description_text(event_choice)
		var action_text := _event_choice_action_text(event_choice)
		var button := _make_economy_choice_card(title_text, desc_text, action_text, "EventChoiceButton%d" % index, event_card_size)
		button.name = "EventChoiceButton%d" % index
		# SCRUM-565: переодеть карточку выбора в per-слот evt_card @2K-рамку и пере-инсетить
		# контент под её content-зону (46/58/46/54 source → display), чтобы текст не лез на орнамент.
		_apply_overhaul_choice_2k_theme(button, "evt_card", event_card_size)
		_reinset_overhaul_choice_content(button, "evt_card", event_card_size)
		var required_money := _event_choice_scaled_cost(event_choice)
		if required_money > 0 and _run_money() < required_money:
			button.disabled = true
			button.tooltip_text += "\nНедостаточно золота: нужно %d, есть %d." % [required_money, _run_money()]
		choices.add_child(button)
		if not button.disabled:
			selectable_buttons.append(button)
		button.pressed.connect(func() -> void:
			if not _event_choice_is_affordable(event_choice):
				return
			var starts_combat := _apply_event_choice(event_choice)
			if not starts_combat:
				game.current_event_definition.clear()
				game.route._advance_route_after_noncombat()
		)
		index += 1
	var back_button := _make_button("Назад")
	back_button.name = "EventBackButton"
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_set_action_button_size(back_button, 380.0, 54.0)
	var allow_skip := bool(event_definition.get("allow_skip", false))
	# Аварийный выход: если ни один выбор недоступен (например, не хватает золота на все
	# платные опции), кнопка «Назад» обязана работать, иначе забег застревает навсегда.
	var no_selectable_choice := selectable_buttons.is_empty()
	var back_enabled := allow_skip or no_selectable_choice
	back_button.disabled = not back_enabled
	if allow_skip:
		back_button.tooltip_text = "Вернуться на карту без исхода события."
	elif no_selectable_choice:
		back_button.tooltip_text = "Нет доступных выборов — вернуться на карту."
	else:
		back_button.tooltip_text = "Это событие требует выбрать исход."
	back_button.pressed.connect(func() -> void:
		if not back_enabled:
			return
		game.current_event_definition.clear()
		game.route._show_battle_map()
	)
	box.add_child(back_button)

	# Клавиатура/геймпад: события должны выбираться не только мышью (AC SCRUM-477).
	# Замыкаем фокус по доступным карточкам стрелками влево/вправо и ставим фокус на
	# первую выбираемую опцию (иначе при сбое мыши забег невозможно пройти с клавиатуры).
	var focus_chain: Array[Button] = selectable_buttons.duplicate()
	if back_enabled:
		focus_chain.append(back_button)
	for focus_index in range(focus_chain.size()):
		var card := focus_chain[focus_index]
		var prev := focus_chain[(focus_index - 1 + focus_chain.size()) % focus_chain.size()]
		var next := focus_chain[(focus_index + 1) % focus_chain.size()]
		card.focus_neighbor_left = prev.get_path()
		card.focus_neighbor_right = next.get_path()
		card.focus_neighbor_top = prev.get_path()
		card.focus_neighbor_bottom = next.get_path()
	if not focus_chain.is_empty():
		focus_chain[0].grab_focus()

	# SCRUM-530: Escape на событии открывает run-pause поверх экрана (консистентно с боем/
	# другими забеговыми экранами). На практике Escape перехватывается раньше через
	# _can_open_pause_dossier() (EventScreen в списке), но _create_menu_box→_clear_ui сбрасывает
	# ui_escape_action в начале функции, поэтому ставим явный фолбэк — если экран события когда-
	# либо перестанет опознаваться dossier-проверкой, Escape всё равно не станет «тихим тупиком».
	game.ui_escape_action = _show_pause_menu


# SCRUM-489: координатная спека @2560×1440 — блок «Результаты» (Победа / Поражение).
# Геометрия победы и поражения идентична: обе — pause/end-модалки через _create_menu_box
# (_is_pause_end_screen_background → ["pause","victory","death"]). Размер панели из
# _pause_end_modal_display_size("victory"/"death"): source 986×900, height clamp [520,820]
# упирается в 820 → @2K = 898×820, CenterContainer центрирует → top-left (831,310).
# Content-margins PAUSE_END_MODAL_CONTENT (74,94,74,86) скейлятся ×0.911 → (67,86,67,78) →
# safe-area (898,396,764,656) — идентична PM_SAFE_2K. Контент в ScrollContainer→VBox
# (alignment center, separation 12): crest 176×176 → title 42px → subtitle 17px (autowrap,
# до ~8 строк у победы) → кнопка 420×104. Все элементы по центру safe-x; Y — фиксированные
# слоты в safe 396..1052 (длинный subtitle победы при переполнении уходит в вертикальный
# скролл — дизайн-инвариант «помещается до скролла» держится при 2K).
const RESULT_DESIGN_BASE_2K := Vector2(2560.0, 1440.0)
const RESULT_PANEL_2K := Rect2(831, 310, 898, 820)
const RESULT_SAFE_2K := Rect2(898, 396, 764, 656)
const RESULT_CREST_2K := Rect2(1192, 401, 176, 176)      # x = 898 + (764-176)/2
const RESULT_TITLE_2K := Rect2(898, 589, 764, 54)        # crest_bottom 577 + sep 12
const RESULT_SUBTITLE_2K := Rect2(898, 655, 764, 220)    # до ~8 строк автопереноса
const VS_BTN_NEWRUN_2K := Rect2(1070, 948, 420, 104)     # x = 898 + (764-420)/2; нижний слот safe
const DS_BTN_RETRY_2K := Rect2(1070, 948, 420, 104)      # геометрия = VS_BTN_NEWRUN_2K


func _show_victory_screen() -> void:
	game.clear_run_autosave()
	var ascension_level: int = game.ascension_level_for(game.selected_character_id)
	var character_config: Dictionary = game.PROGRESSION_DATA.character_config(game.selected_character_id)
	var character_title := str(character_config.get("title", "Герой"))
	if character_title == "" or character_title == game.selected_character_id:
		character_title = "Герой"
	var run_level: int = game.selected_ascension_level
	# Победа над боссом даёт очко умений (record_boss_victory) — показываем игроку.
	var skill_points_total: int = game.META_PROGRESSION.skill_points(game.meta_state)
	var subtitle := "Финальный босс повержен.\n%s завершил забег.\nОчки наследия: %d.\nПолучено очко умений — всего %d, потрать их в «Древе умений» в меню.\n%s" % [
		character_title,
		game.meta_points,
		skill_points_total,
		_victory_ascension_summary(game.selected_character_id, run_level, ascension_level),
	]
	var box = _create_menu_box("Победа", subtitle, "victory")
	_add_result_crest(box, "victory")
	_add_run_summary_rows(box, true)  # SCRUM-502: сводка прогона
	var finish_run := func() -> void:
		game.current_act = 1
		game.route_stage = 0
		game.run_player_snapshot.clear()
		game.route_selected_indices.clear()
		game.used_event_ids.clear()
		game.current_event_definition.clear()
		game.pending_event_combat.clear()
		game.reset_run_metrics()  # SCRUM-502: метрики не текут в следующий забег
		game.route_nodes = game.route._generate_route()
		_show_main_menu()
	var restart_button := _make_button("Новый забег")
	restart_button.name = "VictoryNewRunButton"
	_set_action_button_size(restart_button, STANDARD_ACTION_BUTTON_WIDTH, _pause_end_result_button_height())
	restart_button.pressed.connect(finish_run)
	box.add_child(restart_button)
	game.ui_escape_action = finish_run


func _show_death_screen(reason := "") -> void:
	game.clear_run_autosave()
	var subtitle := str(reason)
	if subtitle == "":
		subtitle = "Забег завершён: %s, этап маршрута %d." % [game.act_progress_label(), game.route_stage + 1]
	var box := _create_menu_box("Поражение", subtitle, "death")
	_add_result_crest(box, "death")
	_add_run_summary_rows(box, false)  # SCRUM-502: сводка прогона
	var back_to_menu := func() -> void:
		game.current_act = 1
		game.route_stage = 0
		game.run_player_snapshot.clear()
		game.route_selected_indices.clear()
		game.used_event_ids.clear()
		game.current_event_definition.clear()
		game.pending_event_combat.clear()
		game.reset_run_metrics()  # SCRUM-502: метрики не текут в следующий забег
		game.route_nodes = game.route._generate_route()
		_show_main_menu()
	var retry_button := _make_button("Начать заново")
	retry_button.name = "DeathRetryButton"
	_set_action_button_size(retry_button, STANDARD_ACTION_BUTTON_WIDTH, _pause_end_result_button_height())
	retry_button.pressed.connect(back_to_menu)
	box.add_child(retry_button)
	game.ui_escape_action = back_to_menu


# SCRUM-502: блок сводки прогона на экранах победы/смерти. Кладётся в box (VBox внутри
# PauseEndModalScroll_*) после crest/subtitle, до кнопки. Все строки MOUSE_FILTER_IGNORE,
# чтобы не перехватывать клик кнопки и Escape. Стабильные имена узлов — для matrix-теста.
func _add_run_summary_rows(box: VBoxContainer, _is_victory: bool) -> void:
	var metrics: Dictionary = game.run_metrics if not game.run_metrics.is_empty() else {}
	var outcome := str(metrics.get("outcome_reason", ""))

	if outcome != "":
		var outcome_label := Label.new()
		outcome_label.name = "RunSummaryOutcome"
		outcome_label.text = outcome
		outcome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		outcome_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		outcome_label.add_theme_font_size_override("font_size", 17)
		outcome_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.54, 1.0))
		outcome_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(outcome_label)

	var grid := GridContainer.new()
	grid.name = "RunSummaryStats"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(grid)

	var artifacts: Array = metrics.get("artifacts", []) as Array
	var rows := [
		["time", "Время забега", _format_run_duration(float(metrics.get("time_seconds", 0.0)))],
		["route", "Дошёл до этапа", str(int(metrics.get("route_stage_reached", 0)) + 1)],
		["kills", "Убийств", str(int(metrics.get("kills", 0)))],
		["damage_dealt", "Урон по врагам", str(int(round(float(metrics.get("damage_dealt", 0.0)))))],
		["damage_taken", "Получено урона", str(int(round(float(metrics.get("damage_taken", 0.0)))))],
		["gold", "Собрано золота", str(int(metrics.get("gold_collected", 0)))],
		["level", "Финальный уровень", str(int(metrics.get("final_level", 0)))],
		["artifacts", "Артефактов", str(artifacts.size())],
	]
	for row in rows:
		var name_label := Label.new()
		name_label.name = "RunSummaryStatName_%s" % str(row[0])
		name_label.text = "%s:" % str(row[1])
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.94, 0.92))
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(name_label)
		var value_label := Label.new()
		value_label.name = "RunSummaryStat_%s" % str(row[0])
		value_label.text = str(row[2])
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		value_label.add_theme_font_size_override("font_size", 16)
		value_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.78, 1.0))
		value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(value_label)

	if not artifacts.is_empty():
		var names := []
		for artifact in artifacts:
			if artifact is Dictionary:
				names.append(str((artifact as Dictionary).get("title", (artifact as Dictionary).get("name", "Артефакт"))))
			else:
				names.append(str(artifact))
		var artifacts_label := Label.new()
		artifacts_label.name = "RunSummaryArtifacts"
		artifacts_label.text = ", ".join(names)
		artifacts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		artifacts_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		artifacts_label.add_theme_font_size_override("font_size", 14)
		artifacts_label.add_theme_color_override("font_color", Color(0.86, 0.82, 0.96, 0.95))
		artifacts_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(artifacts_label)


func _format_run_duration(total_seconds: float) -> String:
	var secs := int(maxf(0.0, total_seconds))
	return "%02d:%02d" % [secs / 60, secs % 60]


func _victory_ascension_summary(character_id: String, run_level: int, unlocked_level: int) -> String:
	var lines := ["Текущий предел Возвышения: %d из %d." % [unlocked_level, game.META_PROGRESSION.MAX_ASCENSION_LEVEL]]  # SCRUM-622: динамический кап (SCRUM-516: 10→5), не хардкод
	if run_level >= unlocked_level - 1 and unlocked_level > 0:
		lines.append("Открыт следующий уровень Возвышения.")
		var reward_text := _ascension_reward_summary(character_id, unlocked_level)
		if reward_text != "":
			lines.append(reward_text)
	else:
		lines.append("Пройден уже освоенный уровень Возвышения.")
	return "\n".join(lines)


func _ascension_reward_summary(character_id: String, level: int) -> String:
	var rewards: Array = game.PROGRESSION_DATA.ascension_levels(character_id)
	var index := clampi(level - 1, 0, rewards.size() - 1)
	if rewards.is_empty() or index < 0 or index >= rewards.size():
		return ""
	var reward: Dictionary = rewards[index]
	var title := str(reward.get("title", "Новая мета-награда"))
	var modifier_text := _modifier_summary_text(reward.get("mods", {}))
	if modifier_text == "":
		return "Новая награда для будущих забегов: %s." % title
	return "Новая награда для будущих забегов: %s — %s." % [title, modifier_text]


func _modifier_summary_text(mods_value) -> String:
	var mods: Dictionary = mods_value if mods_value is Dictionary else {}
	var parts := []
	for key in mods.keys():
		var value := float(mods[key])
		match str(key):
			"damage_multiplier":
				parts.append("урон +%d%%" % int(round((value - 1.0) * 100.0)))
			"attack_speed_multiplier":
				parts.append("скорость атаки +%d%%" % int(round((value - 1.0) * 100.0)))
			"move_speed_multiplier":
				parts.append("скорость движения +%d%%" % int(round((value - 1.0) * 100.0)))
			"aoe_radius_multiplier":
				parts.append("радиус атак +%d%%" % int(round((value - 1.0) * 100.0)))
			"range_multiplier":
				parts.append("дальность атак +%d%%" % int(round((value - 1.0) * 100.0)))
			"knockback_multiplier":
				parts.append("отталкивание +%d%%" % int(round((value - 1.0) * 100.0)))
			"max_health_flat":
				parts.append("максимальное здоровье +%d" % int(round(value)))
			"defense_flat":
				parts.append("защита +%d%%" % int(round(value * 100.0)))
			"crit_chance_flat":
				parts.append("шанс крита +%d%%" % int(round(value * 100.0)))
	return ", ".join(parts)


func _random_event_choices() -> Array:
	# SCRUM-597: пул наград может исчерпаться (_weighted_sample отдаёт меньше
	# count при пустом пуле) — индексировать rewards[0]/[1] вслепую нельзя
	# (Index out of bounds). Строим reward-варианты только под реально выпавшие
	# награды, иначе подставляем детерминированный фолбэк, чтобы всегда было
	# 3 осмысленных выбора и «Отдых» как гарантированный безопасный вариант.
	var rewards := _random_rewards(2)
	var choices := []
	if rewards.size() >= 1:
		choices.append({
			"title": "Тренировка",
			"description": "Получить случайное улучшение характеристики.",
			"reward": rewards[0],
		})
	else:
		# Фолбэк без награды из пула: маленький гарантированный прирост.
		choices.append({
			"title": "Тренировка",
			"description": "Небольшой прирост характеристики.",
			"mods": {"defense_flat": 0.04},
		})
	if rewards.size() >= 2:
		choices.append({
			"title": "Рискованная реликвия",
			"description": "Потерять 15% здоровья и получить артефакт или характеристику.",
			"reward": rewards[1],
			"health_percent_cost": 0.15,
		})
	else:
		# Нет второй награды — не берём плату за HP впустую; даём безопасный прирост.
		choices.append({
			"title": "Закалка",
			"description": "Небольшой прирост максимального здоровья.",
			"mods": {"max_health_flat": 8.0},
		})
	choices.append({
		"title": "Отдых",
		"description": "Восстановить 25% максимального здоровья.",
		"heal_percent": 0.25,
	})
	return choices


func _event_choice_button_text(event_choice: Dictionary) -> String:
	return "%s\n%s%s" % [
		str(event_choice.get("title", "Выбор")),
		"",
		_event_choice_description_text(event_choice),
	]


func _event_choice_description_text(event_choice: Dictionary) -> String:
	return _event_choice_risk_description(str(event_choice.get("description", "")), bool(event_choice.get("risk", false)))


func _event_choice_action_text(event_choice: Dictionary) -> String:
	var cost := _event_choice_scaled_cost(event_choice)
	if cost > 0:
		return "%d зол." % cost
	return "Выбрать"


func _event_choice_scaled_cost(event_choice: Dictionary) -> int:
	if not event_choice.has("cost_money"):
		return 0
	return game.PROGRESSION_DATA.stage_scaled_cost(int(event_choice["cost_money"]), game.route_scaling_stage())


func _event_choice_is_affordable(event_choice: Dictionary) -> bool:
	var cost := _event_choice_scaled_cost(event_choice)
	return cost <= 0 or _run_money() >= cost


func _event_choice_risk_description(description: String, is_risk: bool) -> String:
	var text := description.strip_edges()
	if not is_risk:
		return text
	if text.to_lower().begins_with("риск:"):
		return text
	return "Риск: %s" % text


func _apply_event_choice(event_choice: Dictionary) -> bool:
	var temp_player = game.player_scene.instantiate()
	game.add_child(temp_player)
	if game.run_player_snapshot.is_empty():
		temp_player.configure_character(game.selected_character_id, game.selected_weapon_id)
	else:
		game.combat._restore_player_snapshot(temp_player)

	var outcome := _resolve_event_choice_outcome(event_choice, temp_player)
	if not _apply_event_outcome_to_player(outcome, temp_player):
		temp_player.queue_free()
		return false
	var combat_payload: Dictionary = outcome.get("combat", {})

	game.combat._store_player_snapshot(temp_player)
	temp_player.queue_free()

	if not combat_payload.is_empty():
		game.pending_event_combat = combat_payload.duplicate(true)
		if outcome.has("post_combat"):
			game.pending_event_combat["post_combat"] = outcome["post_combat"]
		game.current_event_definition.clear()
		var combat_type := str(combat_payload.get("type", "battle"))
		game.combat._start_combat(false, "elite" if combat_type == "elite" else "battle")
		return true
	return false


func _resolve_event_choice_outcome(event_choice: Dictionary, temp_player: Node) -> Dictionary:
	var outcome := event_choice.duplicate(true)
	if outcome.has("random_outcomes"):
		var outcomes: Array = outcome.get("random_outcomes", [])
		if not outcomes.is_empty():
			var picked: Dictionary = outcomes[game.rng.randi_range(0, outcomes.size() - 1)]
			outcome.merge(picked.duplicate(true), true)
	if outcome.has("check"):
		var check: Dictionary = outcome.get("check", {})
		var stats: Dictionary = temp_player.get("stats")
		var stat_id := str(check.get("stat", "knowledge"))
		# SCRUM-633: при отсутствии difficulty НЕ давать тихий success — порог 0.0
		# проходит всегда (базовые статы положительны). Логируем и трактуем как провал.
		var passed: bool
		if not check.has("difficulty"):
			push_error("Event check missing 'difficulty' for stat '%s'; treating as failure" % stat_id)
			passed = false
		else:
			var difficulty := float(check.get("difficulty", 0.0))
			passed = float(stats.get(stat_id, 0.0)) >= difficulty
		var branch: Dictionary = outcome.get("success" if passed else "failure", {})
		outcome.merge(branch.duplicate(true), true)
		outcome["check_passed"] = passed
	return outcome


# SCRUM-634: золотая компенсация (база, масштабируется по этапу маршрута), если
# событие обещало random_artifact, но пул артефактов пуст — чтобы заплаченная
# цена события не превращалась в молчаливую потерю награды.
const EMPTY_ARTIFACT_POOL_FALLBACK_MONEY := 40


func _apply_event_outcome_to_player(outcome: Dictionary, temp_player: Node) -> bool:
	if outcome.has("cost_money"):
		if not temp_player.spend_money(game.PROGRESSION_DATA.stage_scaled_cost(int(outcome["cost_money"]), game.route_scaling_stage())):
			return false
	if outcome.has("money"):
		temp_player.gain_money(int(outcome["money"]))
	if outcome.has("reward"):
		temp_player.apply_reward(outcome["reward"])
		game.record_codex_artifact_discovery(outcome["reward"])
	if outcome.has("stats") or outcome.has("mods") or outcome.has("heal_percent"):
		temp_player.apply_reward({
			"kind": "event",
			"title": str(outcome.get("title", "Событие")),
			"stats": outcome.get("stats", {}),
			"mods": outcome.get("mods", {}),
			"heal_percent": outcome.get("heal_percent", 0.0),
		})
	if bool(outcome.get("random_artifact", false)):
		var artifacts := _weighted_sample(game.PROGRESSION_DATA.reward_pool(game.selected_character_id).filter(func(reward: Dictionary) -> bool:
			return str(reward.get("kind", "")) == "artifact"
		), 1)
		if not artifacts.is_empty():
			temp_player.apply_reward(artifacts[0])
			game.record_codex_artifact_discovery(artifacts[0])
		else:
			# SCRUM-634: пул артефактов пуст. Игрок уже мог заплатить цену события
			# (HP/золото выше/ниже), поэтому компенсируем золотом и пишем варн —
			# вместо тихой деградации «цена списана, награда не выдана».
			var fallback_money: int = game.PROGRESSION_DATA.stage_scaled_cost(EMPTY_ARTIFACT_POOL_FALLBACK_MONEY, game.route_scaling_stage())
			temp_player.gain_money(fallback_money)
			push_warning("Event random_artifact: пул артефактов пуст — выдана золотая компенсация %d вместо артефакта." % fallback_money)
	if outcome.has("health_percent_cost"):
		var cost := float(temp_player.get("max_health")) * float(outcome["health_percent_cost"])
		temp_player.set("health", max(1.0, float(temp_player.get("health")) - cost))
	return true


func _random_rewards(count: int) -> Array:
	return _weighted_sample(game.PROGRESSION_DATA.reward_pool(game.selected_character_id), count)


func _weighted_sample(pool: Array, count: int) -> Array:
	# Выбор без возврата с учетом weight (редкость артефактов растет с тиром).
	var picked := []
	while picked.size() < count and not pool.is_empty():
		var total := 0.0
		for entry in pool:
			total += float(entry.get("weight", 1.0))
		var roll: float = game.rng.randf() * total
		var index := 0
		for entry_index in range(pool.size()):
			roll -= float(pool[entry_index].get("weight", 1.0))
			if roll <= 0.0:
				index = entry_index
				break
		picked.append(pool[index])
		pool.remove_at(index)
	return picked


const MAIN_STAT_SLOT_CHANCE := 0.05


func _random_level_up_rewards(count: int) -> Array:
	# Микс: улучшения оружия/класса/вторичных атрибутов + РЕДКО (~5% на слот)
	# основная характеристика. Набор уникален и фиксируется на уровень.
	var regular_pool: Array = game.PROGRESSION_DATA.level_up_rewards(game.selected_character_id)
	var stat_pool: Array = game.PROGRESSION_DATA.main_stat_level_up_rewards(game.selected_character_id)
	var rewards := []
	# Capstone «Озарение» (ветвь Знаний мета-древа, SCRUM-150): ПЕРВОЕ повышение
	# в забеге гарантированно даёт основную характеристику. Гейт по level<=2
	# (run-persistent через снапшот) — срабатывает один раз за забег.
	var skill_mods: Dictionary = game.META_PROGRESSION.skill_modifiers(game.meta_state)
	if float(skill_mods.get("first_levelup_rare", 0.0)) > 0.0 and not stat_pool.is_empty() \
			and game.current_player != null and is_instance_valid(game.current_player) \
			and int(game.current_player.get("level")) <= 2:
		var forced_index: int = game.rng.randi_range(0, stat_pool.size() - 1)
		rewards.append(stat_pool[forced_index])
		stat_pool.remove_at(forced_index)
	while rewards.size() < count and (not regular_pool.is_empty() or not stat_pool.is_empty()):
		var want_rare: bool = not stat_pool.is_empty() and float(game.rng.randf()) < MAIN_STAT_SLOT_CHANCE
		var source: Array = stat_pool if (want_rare or regular_pool.is_empty()) else regular_pool
		var index: int = _weighted_level_up_index(source)
		rewards.append(source[index])
		source.remove_at(index)
	return rewards


func _weighted_level_up_index(source: Array) -> int:
	if source.size() <= 1:
		return 0
	var total := 0.0
	var weights := []
	for reward in source:
		var weight: float = game.PROGRESSION_DATA.level_up_reward_weight(reward, game.selected_character_id)
		weights.append(weight)
		total += weight
	if total <= 0.0:
		return game.rng.randi_range(0, source.size() - 1)
	var roll: float = game.rng.randf() * total
	for index in range(source.size()):
		roll -= float(weights[index])
		if roll <= 0.0:
			return index
	return source.size() - 1


func _random_shop_items(count: int) -> Array:
	var scaling_stage: int = game.route_scaling_stage()
	var items := _weighted_sample(game.PROGRESSION_DATA.shop_items(scaling_stage), count)
	var price_mult := float(game.ascension_difficulty()["price_mult"])
	# Ветвь Богатства мета-древа (SCRUM-150): скидка магазина (shop_price_mult ≤ 0).
	var skill_mods: Dictionary = game.META_PROGRESSION.skill_modifiers(game.meta_state)
	price_mult *= maxf(1.0 + float(skill_mods.get("shop_price_mult", 0.0)), 0.1)
	# Capstone «Связи в гильдии»: гарантированный редкий (tier 3) товар на стене.
	if float(skill_mods.get("guaranteed_rare_shop", 0.0)) > 0.0 and not items.is_empty():
		var has_rare := false
		for item in items:
			if int(item.get("tier", 1)) >= 3:
				has_rare = true
				break
		if not has_rare:
			var rares: Array = (game.PROGRESSION_DATA.shop_items(scaling_stage) as Array).filter(
				func(it): return int((it as Dictionary).get("tier", 1)) >= 3)
			if not rares.is_empty():
				items[game.rng.randi_range(0, items.size() - 1)] = (rares[game.rng.randi_range(0, rares.size() - 1)] as Dictionary).duplicate(true)
	if not is_equal_approx(price_mult, 1.0):
		for item in items:
			item["cost"] = maxi(1, int(round(float(item.get("cost", 0)) * price_mult)))
	return items


func _on_player_leveled_up() -> void:
	game._play_sfx("level_up")
	game.level_up_return_to_map = not game.combat_active
	game.pending_level_ups += 1
	_show_level_up_toast()
	_update_level_up_button()


func _open_pending_level_up() -> void:
	if game.pending_level_ups <= 0:
		return

	# SCRUM-530: помним, открыт ли level-up С УЗЛА-СОБЫТИЯ — тогда после выбора/«Позже»
	# возвращаемся на то же событие, а не на карту (иначе случайное событие рероллится).
	# Пересчитываем на каждом открытии: нейтрализует устаревший флаг от прошлого узла.
	game.level_up_return_to_event = _is_event_screen_active()
	game.push_pause("level_up")
	_show_level_up_screen(game.level_up_return_to_map)


func _is_event_screen_active() -> bool:
	if game.current_event_definition.is_empty():
		return false
	if game.ui_layer == null or not is_instance_valid(game.ui_layer):
		return false
	return game.ui_layer.find_child("EventScreen", true, false) != null


func _return_from_level_up_to_event() -> void:
	# SCRUM-530: повторно рендерим тот же узел-событие из сохранённого current_event_definition
	# (route_node без event_id → ветка переиспользования в _show_event_screen не рероллит).
	if game.current_event_definition.is_empty():
		game.save_run_autosave("level_up_choice")
		game.route._show_battle_map()
		return
	_show_event_screen({"type": "event", "name": str(game.current_event_definition.get("title", "Событие"))})


func _show_level_up_toast() -> void:
	_spawn_level_up_effect()

	if game.hud_layer == null or not is_instance_valid(game.hud_layer):
		if game.combat_active:
			_create_hud()
		else:
			_create_menu_run_hud()

	if game.hud_layer == null or not is_instance_valid(game.hud_layer):
		return

	var toast = game.LEVEL_UP_TOAST_SCENE.instantiate()
	toast.name = "LevelUpToast"
	toast.process_mode = Node.PROCESS_MODE_ALWAYS
	if toast.has_method("setup"):
		toast.setup(game.current_player, game.pending_level_ups)
	game.hud_layer.add_child(toast)


func _spawn_level_up_effect() -> void:
	if game.current_player == null or not is_instance_valid(game.current_player):
		return

	for existing in game.get_tree().get_nodes_in_group("level_up_effects"):
		if existing != null and is_instance_valid(existing):
			if existing.name != "LevelUpEffect":
				continue
			if existing is CanvasItem:
				(existing as CanvasItem).visible = false
			var parent: Node = existing.get_parent()
			if parent != null:
				parent.remove_child(existing)
			existing.queue_free()

	var effect = game.LEVEL_UP_EFFECT_SCENE.instantiate() as Node2D
	if effect == null:
		return
	effect.name = "LevelUpEffect"
	effect.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(effect)
	effect.global_position = game.current_player.global_position
	if effect.has_method("setup"):
		effect.setup(game.current_player)


func _show_combat_title_banner(title: String, color: Color, big := false) -> void:
	# Баннер появления элитки/босса: имя/титул вспыхивает над ареной и гаснет,
	# бой не ставится на паузу. Самоосвобождается; привязан к HUD-слою.
	if game.hud_layer == null or not is_instance_valid(game.hud_layer):
		return
	var existing: Node = game.hud_layer.get_node_or_null("CombatIntroBanner")
	if existing != null:
		existing.queue_free()
	var ctb_slot := "ctb_big" if big else "ctb_small"
	var ctb_spec: Rect2 = CTB_BIG_2K if big else CTB_SMALL_2K
	var ctb_half_width := ctb_spec.size.x * 0.5
	var banner := PanelContainer.new()
	banner.name = "CombatIntroBanner"
	banner.process_mode = Node.PROCESS_MODE_ALWAYS
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_stylebox_override("panel", _overhaul_2k_frame_style(ctb_slot, ctb_spec.size))
	# SCRUM-487: ширина баннера берётся из 2K-спеки (CTB_*_2K), а не из легаси 1280 (720p).
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.anchor_top = 0.0
	banner.anchor_bottom = 0.0
	banner.offset_left = -ctb_half_width
	banner.offset_right = ctb_half_width
	banner.offset_top = ctb_spec.position.y
	banner.offset_bottom = ctb_spec.position.y + ctb_spec.size.y
	banner.modulate.a = 0.0
	banner.scale = Vector2(0.9, 0.9)
	banner.pivot_offset = Vector2(ctb_half_width, 0.0)
	var content_margins := _overhaul_2k_content_margins(ctb_slot, ctb_spec.size)
	var content_rect := Rect2(
		Vector2(content_margins.x, content_margins.y),
		Vector2(
			ctb_spec.size.x - content_margins.x - content_margins.z,
			ctb_spec.size.y - content_margins.y - content_margins.w
		)
	)
	banner.set_meta("combat_title_slot", ctb_slot)
	banner.set_meta("combat_title_content_margins", content_margins)
	banner.set_meta("combat_title_content_rect", content_rect)
	var label := Label.new()
	label.name = "CombatIntroBannerLabel"
	label.text = title
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 54 if big else 34)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.02, 1.0))
	label.add_theme_constant_override("outline_size", 6 if big else 4)
	banner.add_child(label)
	game.hud_layer.add_child(banner)
	var tween := banner.create_tween()
	tween.set_parallel(true)
	tween.tween_property(banner, "modulate:a", 1.0, 0.18)
	tween.tween_property(banner, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(1.1 if big else 0.7)
	tween.chain().tween_property(banner, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(banner.queue_free)


func _update_level_up_button() -> void:
	if game.pending_level_ups <= 0:
		if game.level_up_button != null and is_instance_valid(game.level_up_button):
			game.level_up_button.queue_free()
		game.level_up_button = null
		return

	var level_button_parent: CanvasLayer = game.hud_layer
	if level_button_parent == null or not is_instance_valid(level_button_parent):
		level_button_parent = game.ui_layer
	if level_button_parent == null or not is_instance_valid(level_button_parent):
		return

	if game.level_up_button == null or not is_instance_valid(game.level_up_button):
		# SCRUM-278: corner return button keeps unspent picks visible without blocking center combat.
		game.level_up_button = Button.new()
		game.level_up_button.name = "LevelUpPlusButton"
		game.level_up_button.process_mode = Node.PROCESS_MODE_ALWAYS
		game.level_up_button.anchor_left = 1.0
		game.level_up_button.anchor_right = 1.0
		game.level_up_button.anchor_top = 1.0
		game.level_up_button.anchor_bottom = 1.0
		game.level_up_button.offset_left = -124.0
		game.level_up_button.offset_right = -28.0
		game.level_up_button.offset_top = -124.0
		game.level_up_button.offset_bottom = -26.0
		game.level_up_button.custom_minimum_size = Vector2(96, 98)
		game.level_up_button.tooltip_text = "Открыть выбор улучшения (непотраченные уровни)"
		game.level_up_button.add_theme_font_size_override("font_size", 34)
		_apply_fantasy_button_theme(game.level_up_button)
		game.level_up_button.pressed.connect(_open_pending_level_up)
		level_button_parent.add_child(game.level_up_button)

		var badge_panel := PanelContainer.new()
		badge_panel.name = "LevelUpPlusBadgePanel"
		badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_panel.anchor_left = 1.0
		badge_panel.anchor_top = 0.0
		badge_panel.anchor_right = 1.0
		badge_panel.anchor_bottom = 0.0
		badge_panel.offset_left = -34.0
		badge_panel.offset_top = -10.0
		badge_panel.offset_right = -6.0
		badge_panel.offset_bottom = 18.0
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = Color(1.0, 0.84, 0.22, 1.0)
		badge_style.set_corner_radius_all(12)
		badge_panel.add_theme_stylebox_override("panel", badge_style)
		game.level_up_button.add_child(badge_panel)

		var badge := Label.new()
		badge.name = "LevelUpPlusBadge"
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", 16)
		badge.add_theme_color_override("font_color", Color(0.08, 0.05, 0.02, 1.0))
		badge_panel.add_child(badge)

	game.level_up_button.text = "+"
	game.level_up_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
	var badge_label := game.level_up_button.find_child("LevelUpPlusBadge", true, false) as Label
	if badge_label != null:
		badge_label.text = str(game.pending_level_ups)


func _level_up_affinity_suffix(reward: Dictionary) -> String:
	if str(reward.get("kind", "")) != "artifact":
		return ""
	return _artifact_affinity_suffix(reward)


func _format_level_up_reward_text(reward: Dictionary) -> String:
	var preview := _level_up_reward_preview(reward)
	var interpretation := _reward_interpretation_text(reward)
	return "%s\n%s\n%s%s" % [
		str(reward.get("title", "Upgrade")),
		preview,
		str(reward.get("description", "")),
		"\n%s" % interpretation if interpretation != "" else "",
	]


func _reward_icon_id(reward: Dictionary) -> String:
	var stat_keys := (reward.get("stats", {}) as Dictionary).keys()
	if not stat_keys.is_empty():
		return str(stat_keys[0])
	var modifier_keys := (reward.get("mods", {}) as Dictionary).keys()
	if not modifier_keys.is_empty():
		var modifier_id := str(modifier_keys[0])
		return str(game.LEVEL_UP_MOD_DISPLAY.get(modifier_id, "artifact"))
	if str(reward.get("kind", "")) == "artifact":
		return "artifact"
	return "buff_power"


# SCRUM-525: какие производные статы реально двигает +1 к базовому атрибуту.
# Список — самые значимые производные (порядок = приоритет показа), чтобы тултип
# докачки не разрастался и не давал overflow на 720p. Damage-типы тут приводятся к
# «своему» типу класса в _attribute_upgrade_preview_lines/_attribute_influence_text
# (изоляция типов урона SCRUM-524): чужой тип урона в превью не показываем.
const STAT_DERIVED_PREVIEW := {
	"strength": ["damage"],
	"intelligence": ["magic_damage"],
	"perception": ["sound_wave_damage", "attack_range", "aoe_radius", "pickup_radius"],
	"energy": ["sound_wave_damage", "ultimate_multiplier", "projectile_speed"],
	"knowledge": ["dot_damage", "regeneration", "dot_speed", "summon_amount"],
	"agility": ["attack_speed", "crit_chance", "move_speed", "dodge"],
	"endurance": ["health_point", "defense", "absorb", "knockback_power"],
	"leadership": ["summon_amount", "aura_radius", "buff_power"],
}

const _DAMAGE_TYPE_PARAMETERS := ["damage", "magic_damage", "sound_wave_damage"]


# SCRUM-525: RU-список производных, на которые влияет атрибут (для блока «Влияет на: …»
# в тултипе докачки). Damage-типы фильтруем по «своему» типу класса (SCRUM-524).
# Для небазовых id (например форс ["damage","attack_speed"] из теста) — пустая строка.
func _attribute_influence_text(stat_id: String) -> String:
	var parameters: Array = STAT_DERIVED_PREVIEW.get(stat_id, [])
	if parameters.is_empty():
		return ""
	var class_damage: String = game.PROGRESSION_DATA.damage_parameter_for(game.selected_character_id)
	var labels: Array = []
	for parameter_id in parameters:
		if parameter_id in _DAMAGE_TYPE_PARAMETERS and parameter_id != class_damage:
			continue
		var label := _level_up_parameter_label(parameter_id)
		if not labels.has(label):
			labels.append(label)
	return ", ".join(labels)


# SCRUM-525: честный предпросмотр «было -> станет» для производных при +1 к базовому
# атрибуту. Считаем через derived_parameters от ЖИВОГО состояния игрока (тот же путь,
# что и боевые формулы), безопасно и вне боя (через снапшоты). Возвращаем только строки,
# где отображаемое значение реально меняется; список ограничен 4 строками (overflow на 720p).
func _attribute_upgrade_preview_lines(stat_id: String, delta := 1.0) -> Array:
	var parameters: Array = STAT_DERIVED_PREVIEW.get(stat_id, [])
	if parameters.is_empty():
		return []
	var before_stats := _active_stats_snapshot()
	var before_mods := _active_modifiers_snapshot()
	var after_stats := before_stats.duplicate(true)
	after_stats[stat_id] = float(after_stats.get(stat_id, 0.0)) + delta
	var weapon_config = game.PROGRESSION_DATA.weapon(game.selected_character_id, game.selected_weapon_id)
	var before_parameters: Dictionary = game.PROGRESSION_DATA.derived_parameters(before_stats, before_mods, weapon_config)
	var after_parameters: Dictionary = game.PROGRESSION_DATA.derived_parameters(after_stats, before_mods, weapon_config)
	var class_damage: String = game.PROGRESSION_DATA.damage_parameter_for(game.selected_character_id)
	var lines: Array = []
	for parameter_id in parameters:
		# Изоляция типов урона: показываем только «свой» damage-тип класса.
		if parameter_id in _DAMAGE_TYPE_PARAMETERS and parameter_id != class_damage:
			continue
		var before_text := _format_level_up_value(parameter_id, float(before_parameters.get(parameter_id, 0.0)))
		var after_text := _format_level_up_value(parameter_id, float(after_parameters.get(parameter_id, 0.0)))
		if before_text == after_text:
			continue
		lines.append("%s: %s -> %s" % [_level_up_parameter_label(parameter_id), before_text, after_text])
		if lines.size() >= 4:
			break
	return lines


func _level_up_reward_preview(reward: Dictionary) -> String:
	var kind := "Параметр"
	if reward.has("stats"):
		kind = "Атрибут"
	elif str(reward.get("kind", "")) == "skill":
		kind = "Скилл"

	var before_stats := _active_stats_snapshot()
	var before_mods := _active_modifiers_snapshot()
	var after_stats := before_stats.duplicate(true)
	var after_mods := before_mods.duplicate(true)
	if reward.has("stats"):
		for stat_id in (reward["stats"] as Dictionary).keys():
			after_stats[stat_id] = float(after_stats.get(stat_id, 0.0)) + float(reward["stats"][stat_id])
	if reward.has("mods"):
		for modifier_id in (reward["mods"] as Dictionary).keys():
			if str(modifier_id).ends_with("_multiplier"):
				after_mods[modifier_id] = float(after_mods.get(modifier_id, 1.0)) * float(reward["mods"][modifier_id])
			else:
				after_mods[modifier_id] = float(after_mods.get(modifier_id, 0.0)) + float(reward["mods"][modifier_id])

	var stat_keys := (reward.get("stats", {}) as Dictionary).keys()
	if not stat_keys.is_empty():
		var stat_id := str(stat_keys[0])
		return "%s: %s %.0f -> %.0f" % [
			kind,
			str(game.PROGRESSION_DATA.STAT_NAMES.get(stat_id, stat_id)),
			float(before_stats.get(stat_id, 0.0)),
			float(after_stats.get(stat_id, 0.0)),
		]

	var modifier_keys := (reward.get("mods", {}) as Dictionary).keys()
	if not modifier_keys.is_empty():
		var modifier_id := str(modifier_keys[0])
		var parameter_id = str(game.LEVEL_UP_MOD_DISPLAY.get(modifier_id, modifier_id))
		# Превью урона честное: показываем «свой» damage-параметр класса.
		if parameter_id == "damage":
			parameter_id = game.PROGRESSION_DATA.damage_parameter_for(game.selected_character_id)
		var weapon_config = game.PROGRESSION_DATA.weapon(game.selected_character_id, game.selected_weapon_id)
		var before_parameters: Dictionary = game.PROGRESSION_DATA.derived_parameters(before_stats, before_mods, weapon_config)
		var after_parameters: Dictionary = game.PROGRESSION_DATA.derived_parameters(after_stats, after_mods, weapon_config)
		return "%s: %s %s -> %s" % [
			kind,
			_level_up_parameter_label(parameter_id),
			_format_level_up_value(parameter_id, float(before_parameters.get(parameter_id, before_mods.get(modifier_id, 0.0)))),
			_format_level_up_value(parameter_id, float(after_parameters.get(parameter_id, after_mods.get(modifier_id, 0.0)))),
		]

	return kind


func _reward_interpretation_text(reward: Dictionary) -> String:
	var stat_keys := (reward.get("stats", {}) as Dictionary).keys()
	if not stat_keys.is_empty():
		return "Интерпретация: %s" % game.PROGRESSION_DATA.class_interpretation_text(game.selected_character_id, str(stat_keys[0]))
	var modifier_keys := (reward.get("mods", {}) as Dictionary).keys()
	if not modifier_keys.is_empty():
		var parameter_id = str(game.LEVEL_UP_MOD_DISPLAY.get(str(modifier_keys[0]), modifier_keys[0]))
		if parameter_id == "damage":
			parameter_id = game.PROGRESSION_DATA.damage_parameter_for(game.selected_character_id)
		return "Интерпретация: %s" % game.PROGRESSION_DATA.class_interpretation_text(game.selected_character_id, parameter_id)
	if reward.has("affinity_mods"):
		var affinity_keys := (reward.get("affinity_mods", {}) as Dictionary).keys()
		if not affinity_keys.is_empty():
			var affinity_parameter = str(game.LEVEL_UP_MOD_DISPLAY.get(str(affinity_keys[0]), affinity_keys[0]))
			return "Интерпретация: %s" % game.PROGRESSION_DATA.class_interpretation_text(game.selected_character_id, affinity_parameter)
	return ""


func _active_stats_snapshot() -> Dictionary:
	if game.current_player != null and is_instance_valid(game.current_player):
		return (game.current_player.get("stats") as Dictionary).duplicate(true)
	if not game.run_player_snapshot.is_empty():
		return (game.run_player_snapshot.get("stats", {}) as Dictionary).duplicate(true)
	return game.PROGRESSION_DATA.base_stats(game.selected_character_id)


func _active_modifiers_snapshot() -> Dictionary:
	if game.current_player != null and is_instance_valid(game.current_player):
		return (game.current_player.get("run_modifiers") as Dictionary).duplicate(true)
	if not game.run_player_snapshot.is_empty():
		return (game.run_player_snapshot.get("run_modifiers", {}) as Dictionary).duplicate(true)
	return {}


func _level_up_parameter_label(parameter_id: String) -> String:
	match parameter_id:
		"damage":
			return "Урон"
		"magic_damage":
			return "Маг. урон"
		"sound_wave_damage":
			return "Звуковой урон"
		"attack_speed":
			return "Скорость атаки"
		"health_point":
			return "Макс. здоровье"
		"move_speed":
			return "Скорость"
		"dodge":
			return "Уклонение"
		"aoe_radius":
			return "Радиус области"
		"pickup_radius":
			return "Радиус подбора"
		"defense":
			return "Защита"
		"attack_range":
			return "Дальность"
		"crit_chance":
			return "Шанс крита"
		"crit_damage_multiplier":
			return "Крит. урон"
		"knockback_power":
			return "Отталкивание"
		"dot_damage":
			return "Периодический урон"
		"dot_speed":
			return "Скорость тиков"
		"projectile_speed":
			return "Скорость снарядов"
		"aura_radius":
			return "Радиус ауры"
		"buff_power":
			return "Сила баффов"
		"summon_amount":
			return "Призывы"
		"absorb":
			return "Поглощение"
		"regeneration":
			return "Регенерация"
		"vampiric_amount":
			return "Вампиризм"
		"vampiric_chance":
			return "Шанс вампиризма"
		"ultimate_multiplier":
			return "Сила уник. механики"
		_:
			return parameter_id


func _format_level_up_value(parameter_id: String, value: float) -> String:
	if parameter_id in ["crit_chance", "defense", "dodge", "vampiric_chance"]:
		return "%.0f%%" % (value * 100.0)
	if parameter_id in ["attack_speed", "crit_damage_multiplier", "dot_speed", "buff_power", "ultimate_multiplier"]:
		return "%.2f" % value
	return "%.0f" % value


func _buy_shop_item_at(index: int) -> bool:
	if index < 0 or index >= game.current_shop_items.size():
		return false
	if index >= game.current_shop_purchased.size() or bool(game.current_shop_purchased[index]):
		return false
	var item: Dictionary = game.current_shop_items[index]
	if not _buy_shop_item(item):
		return false
	game.current_shop_purchased[index] = true
	_show_shop_screen()
	return true


func _buy_shop_item(item: Dictionary) -> bool:
	var temp_player = game.combat._snapshot_player_for_menu()
	if temp_player == null:
		return false

	if not temp_player.spend_money(int(item["cost"])):
		temp_player.queue_free()
		return false

	temp_player.apply_reward(item)
	game.record_codex_artifact_discovery(item)
	game.combat._store_player_snapshot(temp_player)
	temp_player.queue_free()
	return true


func _apply_reward_to_active_run(reward: Dictionary) -> void:
	if game.current_player != null and is_instance_valid(game.current_player):
		game.current_player.apply_reward(reward)
		game.record_codex_artifact_discovery(reward)
		game.combat._store_player_snapshot(game.current_player)
	else:
		_apply_reward_to_run(reward)


func _apply_reward_to_run(reward: Dictionary) -> void:
	var temp_player = game.combat._snapshot_player_for_menu()
	temp_player.apply_reward(reward)
	game.record_codex_artifact_discovery(reward)
	game.combat._store_player_snapshot(temp_player)
	temp_player.queue_free()


func _setup_default_input_actions() -> void:
	for input_action in game.INPUT_ACTIONS:
		var action_name: String = input_action["action"]
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

		if InputMap.action_get_events(action_name).is_empty():
			_apply_keycodes_to_action(action_name, _default_keycodes_for_action(input_action))
	_apply_saved_input_bindings()


func _apply_saved_input_bindings() -> void:
	var saved_bindings: Dictionary = game.input_bindings
	for input_action in game.INPUT_ACTIONS:
		var action_name: String = input_action["action"]
		var saved_keys: Array = saved_bindings.get(action_name, [])
		if saved_keys.is_empty():
			continue
		_apply_keycodes_to_action(action_name, saved_keys)


func _default_keycodes_for_action(input_action: Dictionary) -> Array:
	var keys := []
	var default_key := int(input_action.get("default_key", 0))
	var alternate_key := int(input_action.get("alternate_key", 0))
	if default_key != 0:
		keys.append(default_key)
	if alternate_key != 0 and alternate_key != default_key:
		keys.append(alternate_key)
	return keys


func _apply_keycodes_to_action(action_name: String, keycodes: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	InputMap.action_erase_events(action_name)
	for keycode_value in keycodes:
		var keycode := int(keycode_value)
		if keycode == 0:
			continue
		var event := InputEventKey.new()
		event.keycode = keycode
		InputMap.action_add_event(action_name, event)


func _current_input_bindings() -> Dictionary:
	var result := {}
	for input_action in game.INPUT_ACTIONS:
		var action_name: String = input_action["action"]
		var keys := []
		for event in InputMap.action_get_events(action_name):
			if event is InputEventKey:
				var keycode: int = int(event.keycode if event.keycode != 0 else event.physical_keycode)
				if keycode != 0:
					keys.append(keycode)
		result[action_name] = keys
	return result


func _apply_game_cursor() -> void:
	var arrow_texture: Texture2D = game._cached_texture(game.GAME_CURSOR_PATH)
	if arrow_texture == null:
		return
	Input.set_custom_mouse_cursor(arrow_texture, Input.CURSOR_ARROW, game.GAME_CURSOR_HOTSPOT)

	var hover_texture: Texture2D = game._cached_texture(str(SHOP_CURSOR_VARIANTS["pointing_hand"]))
	if hover_texture != null:
		Input.set_custom_mouse_cursor(hover_texture, Input.CURSOR_POINTING_HAND, game.GAME_CURSOR_HOTSPOT)

	var attack_texture: Texture2D = game._cached_texture(str(SHOP_CURSOR_VARIANTS["cross"]))
	if attack_texture != null:
		Input.set_custom_mouse_cursor(attack_texture, Input.CURSOR_CROSS, game.GAME_CURSOR_HOTSPOT)


func _begin_rebind(action_name: String) -> void:
	game.pending_rebind_action = action_name
	var label := _action_label(action_name)
	var box := _create_menu_box("Клавиша: %s" % label, "Нажми новую клавишу. Esc отменяет.", "settings")

	var cancel_button := _make_button("Отмена")
	cancel_button.pressed.connect(func() -> void:
		game.pending_rebind_action = ""
		_show_settings_menu()
	)
	box.add_child(cancel_button)


func _handle_rebind_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	if event.keycode == KEY_ESCAPE:
		game.pending_rebind_action = ""
		_show_settings_menu()
		return

	var keycode: int = int(event.keycode if event.keycode != 0 else event.physical_keycode)
	var conflict_action := _binding_conflict_action(game.pending_rebind_action, keycode)
	if conflict_action != "":
		_show_rebind_conflict(game.pending_rebind_action, keycode, conflict_action)
		return

	InputMap.action_erase_events(game.pending_rebind_action)
	var new_event := InputEventKey.new()
	new_event.keycode = keycode
	new_event.physical_keycode = event.physical_keycode
	InputMap.action_add_event(game.pending_rebind_action, new_event)

	game.input_bindings = _current_input_bindings()
	game.save_game_settings()
	game.pending_rebind_action = ""
	_show_settings_menu()


func _binding_conflict_action(target_action: String, keycode: int) -> String:
	for input_action in game.INPUT_ACTIONS:
		var action_name: String = input_action["action"]
		if action_name == target_action:
			continue
		for existing_event in InputMap.action_get_events(action_name):
			if existing_event is InputEventKey:
				var existing_key: int = int(existing_event.keycode if existing_event.keycode != 0 else existing_event.physical_keycode)
				if existing_key == keycode:
					return action_name
	return ""


func _show_rebind_conflict(target_action: String, keycode: int, conflict_action: String) -> void:
	var target_label := _action_label(target_action)
	var conflict_label := _action_label(conflict_action)
	var key_name := OS.get_keycode_string(keycode)
	var box := _create_menu_box("Клавиша занята", "%s уже используется для «%s». Выбери другую клавишу для «%s»." % [key_name, conflict_label, target_label], "settings")
	var retry_button := _make_button("Выбрать другую")
	retry_button.pressed.connect(func() -> void:
		_begin_rebind(target_action)
	)
	box.add_child(retry_button)
	var back_button := _make_button("Назад к настройкам")
	back_button.pressed.connect(func() -> void:
		game.pending_rebind_action = ""
		_show_settings_menu()
	)
	box.add_child(back_button)


func _reset_input_bindings_to_defaults() -> void:
	for input_action in game.INPUT_ACTIONS:
		_apply_keycodes_to_action(str(input_action["action"]), _default_keycodes_for_action(input_action))
	game.input_bindings = _current_input_bindings()
	game.save_game_settings()


func _binding_text(action_name: String) -> String:
	var events := InputMap.action_get_events(action_name)
	if events.is_empty():
		return "Не назначено"

	var labels := []
	for event in events:
		if event is InputEventKey:
			var keycode: int = int(event.keycode if event.keycode != 0 else event.physical_keycode)
			labels.append(OS.get_keycode_string(keycode))
		else:
			labels.append(event.as_text())
	return " / ".join(labels)


func _action_label(action_name: String) -> String:
	for input_action in game.INPUT_ACTIONS:
		if input_action["action"] == action_name:
			return input_action["label"]

	return action_name


func _sync_window_content_scale(content_size: Vector2i) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if content_size.x <= 0 or content_size.y <= 0:
		return
	var window: Window = game.get_window()
	if window == null:
		return
	window.content_scale_size = content_size


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


# SCRUM-484: координатная спека @2560×1440 — форма фидбэка (модалка со скроллом).
# Панель clamp(viewport-80, [480,940] × [380,780]) → @2K = 940×780, центрирована.
# _panel_style margins (58,72,58,66) → safe-area. Сверху фикс заголовок, снизу фикс
# статус + ряд кнопок (Отправить 260×64, Отмена 220×64, sep 18); середина (ScrollContainer)
# тянется и прокручивает поле ввода (h≥130) и превью скриншота (h 240). Кнопки никогда
# не уезжают за нижний край (SCRUM-460).
const FB_PANEL_2K := Rect2(810, 330, 940, 780)
const FB_SAFE_2K := Rect2(868, 402, 824, 642)
const FB_TITLE_2K := Rect2(868, 402, 824, 42)
const FB_SCROLL_2K := Rect2(868, 454, 824, 470)
const FB_TEXTEDIT_2K := Rect2(868, 508, 824, 130)
const FB_SCREENSHOT_2K := Rect2(868, 648, 824, 240)
const FB_STATUS_2K := Rect2(868, 934, 824, 36)
const FB_BTN_SEND_2K := Rect2(1031, 980, 260, 64)
const FB_BTN_CANCEL_2K := Rect2(1309, 980, 220, 64)


func _show_feedback_overlay(screenshot: Image = null) -> void:
	_close_feedback_overlay()
	# Пауза при открытии формы фидбека — как Escape (оверлей PROCESS_MODE_ALWAYS,
	# поэтому ввод в форму работает на паузе). Снимается в _close_feedback_overlay.
	game.push_pause("feedback")

	game.feedback_overlay_layer = CanvasLayer.new()
	game.feedback_overlay_layer.name = "FeedbackOverlayLayer"
	game.feedback_overlay_layer.layer = 128
	game.feedback_overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.feedback_overlay_layer)

	var root := Control.new()
	root.name = "FeedbackOverlay"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	game.feedback_overlay_layer.add_child(root)

	var dim := ColorRect.new()
	dim.name = "FeedbackDim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	# Размер панели подгоняется под вьюпорт (минус поля), с потолком — иначе на
	# 1600x970 контент (~720px) переполнял фиксированную панель 700px и кнопки
	# уезжали за нижний край экрана (SCRUM-460).
	var viewport_size: Vector2 = root.get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1280.0, 720.0)
	var panel_width: float = clampf(viewport_size.x - 80.0, 480.0, 940.0)
	var panel_height: float = clampf(viewport_size.y - 80.0, 380.0, 780.0)

	var panel := PanelContainer.new()
	panel.name = "FeedbackPanel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -panel_width * 0.5
	panel.offset_top = -panel_height * 0.5
	panel.offset_right = panel_width * 0.5
	panel.offset_bottom = panel_height * 0.5
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# SCRUM-486: @2K per-слот фрейм формы фидбэка (fb_panel 940×780; на 2K панель ровно
	# 940×780, на меньших вьюпортах 9-slice бордюры скейлятся от source 940×780).
	panel.add_theme_stylebox_override("panel", _overhaul_2k_frame_style("fb_panel", Vector2(panel_width, panel_height)))
	root.add_child(panel)

	var box := VBoxContainer.new()
	box.name = "FeedbackContent"
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Отправить фидбек"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	box.add_child(title)

	# Середина прокручивается: при любой высоте экрана заголовок сверху, а статус
	# и кнопки «Отправить»/«Отмена» снизу остаются закреплены и видимы.
	var scroll := ScrollContainer.new()
	scroll.name = "FeedbackScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	var scroll_body := VBoxContainer.new()
	scroll_body.name = "FeedbackScrollBody"
	scroll_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_body.add_theme_constant_override("separation", 10)
	scroll.add_child(scroll_body)

	var hint := Label.new()
	hint.text = "Опиши баг или впечатление. Скриншот ниже уже снят до открытия формы."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.88, 0.86, 0.78, 1.0))
	scroll_body.add_child(hint)

	var text_edit := TextEdit.new()
	text_edit.name = "FeedbackTextEdit"
	text_edit.custom_minimum_size = Vector2(0, 130)
	text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_edit.placeholder_text = "Что случилось? Где ты был в игре? Что ожидал увидеть?"
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_edit.add_theme_font_size_override("font_size", 17)
	text_edit.add_theme_color_override("font_color", Color(0.96, 0.93, 0.84, 1.0))
	text_edit.add_theme_color_override("font_placeholder_color", Color(0.66, 0.64, 0.58, 1.0))
	scroll_body.add_child(text_edit)

	var preview_frame := PanelContainer.new()
	preview_frame.name = "FeedbackScreenshotFrame"
	preview_frame.custom_minimum_size = Vector2(0, 240)
	preview_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_frame.add_theme_stylebox_override("panel", _character_card_style())
	scroll_body.add_child(preview_frame)

	var preview := TextureRect.new()
	preview.name = "FeedbackScreenshotPreview"
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(0, 224)
	var safe_screenshot: Image = FEEDBACK_REPORTER_SCRIPT._normalized_screenshot(screenshot)
	preview.texture = ImageTexture.create_from_image(safe_screenshot)
	preview_frame.add_child(preview)

	var status := Label.new()
	status.name = "FeedbackStatusLabel"
	status.text = "Отправка происходит только после нажатия «Отправить»."
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 14)
	status.add_theme_color_override("font_color", Color(0.74, 0.82, 0.88, 1.0))
	box.add_child(status)

	var buttons := HBoxContainer.new()
	buttons.name = "FeedbackButtons"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 18)
	box.add_child(buttons)

	var send_button := _make_button("Отправить")
	send_button.name = "FeedbackSendButton"
	_set_action_button_size(send_button, 260.0, 64.0)
	buttons.add_child(send_button)

	var cancel_button := _make_button("Отмена")
	cancel_button.name = "FeedbackCancelButton"
	_set_action_button_size(cancel_button, 220.0, 64.0)
	cancel_button.pressed.connect(_close_feedback_overlay)
	buttons.add_child(cancel_button)

	send_button.pressed.connect(func() -> void:
		send_button.disabled = true
		status.text = "Отправляем..."
		var reporter: Node = _feedback_reporter()
		reporter.connect("report_finished", func(success: bool, message: String, local_path: String) -> void:
			status.text = message if local_path == "" else "%s\n%s" % [message, local_path]
			status.add_theme_color_override("font_color", Color(0.74, 0.96, 0.74, 1.0) if success else Color(1.0, 0.82, 0.50, 1.0))
			send_button.disabled = false
		, CONNECT_ONE_SHOT)
		reporter.call("submit_report", text_edit.text, safe_screenshot, _feedback_metadata())
	)

	text_edit.grab_focus()


func _is_feedback_overlay_open() -> bool:
	return game.feedback_overlay_layer != null and is_instance_valid(game.feedback_overlay_layer)


func _close_feedback_overlay() -> void:
	if game.feedback_overlay_layer != null and is_instance_valid(game.feedback_overlay_layer):
		game.feedback_overlay_layer.queue_free()
	game.feedback_overlay_layer = null
	# Снять паузу, поставленную при открытии формы фидбека (no-op, если не стояла).
	game.pop_pause("feedback")


func _feedback_reporter() -> Node:
	var reporter: Node = game.get_node_or_null("FeedbackReporter")
	if reporter != null and is_instance_valid(reporter):
		return reporter
	reporter = FEEDBACK_REPORTER_SCRIPT.new()
	reporter.name = "FeedbackReporter"
	reporter.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(reporter)
	return reporter


func _feedback_metadata() -> Dictionary:
	var viewport_size: Vector2 = game.get_viewport().get_visible_rect().size
	return {
		"version": str(ProjectSettings.get_setting("application/config/version", "dev")),
		"character": str(game.selected_character_id),
		"weapon": str(game.selected_weapon_id),
		"ascension": int(game.selected_ascension_level),
		"current_act": int(game.current_act),
		"route_stage": int(game.route_stage),
		"route_scaling_stage": int(game.route_scaling_stage()),
		"current_node_type": str(game.current_node_type),
		"combat_active": bool(game.combat_active),
		"boss_active": bool(game.boss_combat_active),
		"screen": _current_ui_screen_name(),
		"resolution": "%dx%d" % [int(viewport_size.x), int(viewport_size.y)],
		"os": OS.get_name(),
		"timestamp": Time.get_datetime_string_from_system(),
	}


func _current_ui_screen_name() -> String:
	if game.ui_layer != null and is_instance_valid(game.ui_layer):
		for child in game.ui_layer.get_children():
			if child is Control and not str(child.name).begins_with("ScreenBackground"):
				return str(child.name)
	if game.pause_overlay_layer != null and is_instance_valid(game.pause_overlay_layer):
		return str(game.pause_overlay_layer.name)
	if game.combat_active:
		return "Combat"
	return "World"


func _create_menu_box(title: String, subtitle: String, screen_background_id := "", panel_style_override: StyleBox = null, panel_display_size := Vector2.ZERO) -> VBoxContainer:
	game._clear_ui()

	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.ui_layer.add_child(root)

	if screen_background_id != "":
		_add_screen_background(root, screen_background_id)

	var panel := PanelContainer.new()
	panel.name = "MenuPanel_%s" % screen_background_id if screen_background_id != "" else "MenuPanel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	var economy_panel := _is_economy_screen_background(screen_background_id)
	var pause_end_panel := _is_pause_end_screen_background(screen_background_id)
	var display_size := _pause_end_modal_display_size(screen_background_id) if pause_end_panel else Vector2.ZERO
	var half_size := panel_display_size * 0.5 if panel_display_size != Vector2.ZERO else (display_size * 0.5 if pause_end_panel else (_economy_menu_panel_half_size(screen_background_id) if economy_panel else Vector2(560.0, 330.0)))
	panel.offset_left = -half_size.x
	panel.offset_top = -half_size.y
	panel.offset_right = half_size.x
	panel.offset_bottom = half_size.y
	if pause_end_panel:
		panel.name = "PauseEndModalPanel_%s" % screen_background_id
		panel.clip_contents = true
		panel.add_theme_stylebox_override("panel", _pause_end_modal_style(display_size, screen_background_id))
	elif panel_style_override != null:
		panel.add_theme_stylebox_override("panel", panel_style_override)
	else:
		panel.add_theme_stylebox_override("panel", _economy_panel_style() if economy_panel else _panel_style())
	root.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12 if pause_end_panel else (16 if economy_panel else 14))
	if pause_end_panel:
		var scroll := ScrollContainer.new()
		scroll.name = "PauseEndModalScroll_%s" % screen_background_id
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		panel.add_child(scroll)
		scroll.add_child(box)
	elif economy_panel:
		var scroll := ScrollContainer.new()
		scroll.name = "EconomyMenuScroll_%s" % screen_background_id
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		panel.add_child(scroll)
		scroll.add_child(box)
	else:
		panel.add_child(box)

	var title_label := Label.new()
	title_label.name = "MenuTitle_%s" % screen_background_id if screen_background_id != "" else "MenuTitle"
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 34 if pause_end_panel and game.get_viewport().get_visible_rect().size.y < 800.0 else 42)
	title_label.add_theme_color_override("font_color", Color(0.96, 0.9, 0.68, 1.0))
	box.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.name = "MenuSubtitle_%s" % screen_background_id if screen_background_id != "" else "MenuSubtitle"
	subtitle_label.text = subtitle
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle_label.add_theme_font_size_override("font_size", 15 if pause_end_panel and game.get_viewport().get_visible_rect().size.y < 800.0 else 17)
	subtitle_label.add_theme_color_override("font_color", Color(0.93, 0.89, 0.80, 1.0))
	box.add_child(subtitle_label)

	return box


func _add_result_crest(box: VBoxContainer, kind: String) -> void:
	# Аддитивная геральдическая эмблема-кольцо над заголовком экранов победы/поражения
	# (D&D Dark Fantasy Dragon, fantasydisk-asset-generator). SCRUM-330.
	var slug := "victory" if kind == "victory" else "defeat"
	var tex: Texture2D = game._cached_texture("res://assets/sprites/ui/result_crests/ui_crest_%s.png" % slug)
	if tex == null:
		return
	var crest := TextureRect.new()
	crest.name = "ResultCrest"
	crest.texture = tex
	var crest_size := _pause_end_result_crest_size()
	crest.custom_minimum_size = Vector2(crest_size, crest_size)
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(crest)
	box.move_child(crest, 0)


func _pause_end_result_crest_size() -> float:
	var viewport_height: float = float(game.get_viewport().get_visible_rect().size.y)
	return clampf(viewport_height * 0.17, 112.0, 176.0)


func _pause_end_result_button_height() -> float:
	var viewport_height: float = float(game.get_viewport().get_visible_rect().size.y)
	if viewport_height < 800.0:
		return 72.0
	if viewport_height < 1000.0:
		return 88.0
	return STANDARD_ACTION_BUTTON_HEIGHT


func _add_screen_background(root: Control, screen_background_id: String) -> void:
	var texture := _screen_background_texture(screen_background_id)
	if texture != null:
		var background := TextureRect.new()
		background.name = "ScreenBackground_%s" % screen_background_id
		background.set_anchors_preset(Control.PRESET_FULL_RECT)
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		background.texture = texture
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(background)
	else:
		var fallback := ColorRect.new()
		fallback.name = "ScreenBackgroundFallback_%s" % screen_background_id
		fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
		fallback.color = game.SCREEN_BACKGROUND_FALLBACK_COLORS.get(screen_background_id, Color(0.035, 0.040, 0.060, 1.0))
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(fallback)

	var shade := ColorRect.new()
	shade.name = "ScreenBackgroundReadableShade"
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.44)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)


func _screen_background_texture(screen_background_id: String) -> Texture2D:
	if game.screen_background_cache.has(screen_background_id):
		return game.screen_background_cache[screen_background_id]
	var path = str(game.SCREEN_BACKGROUND_PATHS.get(screen_background_id, ""))
	if path == "" or not ResourceLoader.exists(path):
		game.screen_background_cache[screen_background_id] = null
		return null
	var texture = game._cached_texture(path)
	game.screen_background_cache[screen_background_id] = texture
	return texture


func _level_up_layout_metrics() -> Dictionary:
	var viewport_size := Vector2(1280.0, 720.0)
	if game != null and game.get_viewport() != null:
		viewport_size = game.get_viewport().get_visible_rect().size
	var compact := viewport_size.y <= 760.0
	var panel_width := minf(1040.0, viewport_size.x - 80.0)
	var panel_height := minf(600.0, viewport_size.y - 64.0)
	var card_width := clampf((panel_width - 190.0) / 3.0, 202.0, 238.0)
	var card_height := clampf(panel_height - 390.0, 186.0, 270.0)
	if compact:
		panel_width = minf(1000.0, viewport_size.x - 96.0)
		panel_height = minf(560.0, viewport_size.y - 88.0)
		card_width = clampf((panel_width - 180.0) / 3.0, 196.0, 228.0)
		card_height = minf(card_height, 160.0)
	return {
		"panel_size": Vector2(roundf(panel_width), roundf(panel_height)),
		"card_size": Vector2(roundf(card_width), roundf(card_height)),
		"card_gap": 8 if compact else 12,
		"later_button_size": Vector2(240.0, 56.0) if compact else Vector2(260.0, 72.0),
		"box_separation": 2 if compact else 8,
		"hero_size": Vector2(36, 36) if compact else Vector2(64, 64),
		"title_font": 26 if compact else 38,
		"title_scale": Vector2.ONE,
		"subtitle_font": 10 if compact else 14,
		"badge_font": 11 if compact else 15,
		"compact": compact,
	}


func _create_level_up_menu_box(title: String, subtitle: String, layout := {}) -> VBoxContainer:
	game._clear_ui()
	if layout.is_empty():
		layout = _level_up_layout_metrics()

	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "LevelUpOverlay"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	game.ui_layer.add_child(root)
	_add_screen_background(root, "level_up")

	var dim := ColorRect.new()
	dim.name = "LevelUpDim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.015, 0.035, 0.0)
	# ColorRect по умолчанию перехватывает мышь (STOP). Полноэкранная подложка не должна
	# глотать клики по карточкам — пропускаем ввод насквозь.
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var sparkle_root := Control.new()
	sparkle_root.name = "LevelUpParticles"
	sparkle_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	sparkle_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sparkle_root)
	_create_level_up_burst_shapes(sparkle_root)

	var panel := PanelContainer.new()
	panel.name = "LevelUpPanel"
	var panel_size: Vector2 = layout.get("panel_size", Vector2(1120, 660))
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -panel_size.x * 0.5
	panel.offset_top = -panel_size.y * 0.5
	panel.offset_right = panel_size.x * 0.5
	panel.offset_bottom = panel_size.y * 0.5
	# SCRUM-552: панель НЕ масштабируем на интро (scale<1 сжимал глобальные rect'ы
	# текстовых лейблов → ui_no_overlap_matrix флачил «needs height X but has 0.86*X»).
	# Раскрытие — через fade (modulate.a) ниже в _start_level_up_intro, геометрия с
	# первого кадра финальная и детерминированная.
	panel.scale = Vector2.ONE
	panel.modulate.a = 0.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _level_up_panel_style())
	root.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", int(layout.get("box_separation", 14)))
	panel.add_child(box)

	var badge_label := Label.new()
	badge_label.name = "LevelUpBadge"
	badge_label.text = _level_up_badge_text()
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.add_theme_font_size_override("font_size", int(layout.get("badge_font", 18)))
	badge_label.add_theme_color_override("font_color", Color(0.38, 0.95, 1.0, 1.0))
	box.add_child(badge_label)

	var hero_header := HBoxContainer.new()
	hero_header.name = "LevelUpHeroHeader"
	hero_header.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_header.add_theme_constant_override("separation", int(layout.get("box_separation", 14)))
	box.add_child(hero_header)

	var hero_size: Vector2 = layout.get("hero_size", Vector2(92, 92))
	var hero_frame := PanelContainer.new()
	hero_frame.name = "LevelUpHeroFrame"
	hero_frame.custom_minimum_size = hero_size
	hero_frame.add_theme_stylebox_override("panel", _level_up_hero_style())
	hero_header.add_child(hero_frame)

	var hero_portrait := TextureRect.new()
	hero_portrait.name = "LevelUpHeroPortrait"
	hero_portrait.texture = game._cached_texture(str(game.PROGRESSION_DATA.character_config(game.selected_character_id).get("sprite_path", "")))
	hero_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero_portrait.custom_minimum_size = hero_size
	hero_frame.add_child(hero_portrait)

	var title_label := Label.new()
	title_label.name = "LevelUpTitle"
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.scale = layout.get("title_scale", Vector2(1.18, 1.18))
	title_label.modulate.a = 0.0
	title_label.add_theme_font_size_override("font_size", int(layout.get("title_font", 50)))
	title_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.30, 1.0))
	box.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.name = "LevelUpSubtitle"
	subtitle_label.text = subtitle
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size", int(layout.get("subtitle_font", 17)))
	subtitle_label.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0, 1.0))
	box.add_child(subtitle_label)

	return box


func _create_level_up_burst_shapes(parent: Control) -> void:
	var center = game.ARENA_CENTER
	for index in range(12):
		var ray := ColorRect.new()
		ray.name = "LevelUpRay%d" % index
		ray.color = Color(1.0, 0.78, 0.24, 0.0)
		ray.position = center
		ray.size = Vector2(240.0 + float(index % 3) * 42.0, 4.0)
		ray.pivot_offset = Vector2(0.0, 2.0)
		ray.rotation = TAU * float(index) / 12.0
		parent.add_child(ray)

	for index in range(20):
		var spark := ColorRect.new()
		spark.name = "LevelUpSpark%d" % index
		spark.color = Color(0.38, 0.95, 1.0, 0.0) if index % 2 == 0 else Color(1.0, 0.78, 0.24, 0.0)
		spark.position = center
		spark.size = Vector2(8.0, 8.0)
		spark.pivot_offset = Vector2(4.0, 4.0)
		parent.add_child(spark)


func _start_level_up_intro(panel: Node, title_label: Node, reward_buttons: Array, sparkle_root: Node) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	await game.get_tree().process_frame
	if panel == null or not is_instance_valid(panel) or game.ui_layer == null or not is_instance_valid(game.ui_layer):
		return

	var level_up_panel := panel as PanelContainer
	if level_up_panel == null:
		return
	level_up_panel.pivot_offset = level_up_panel.size * 0.5
	var dim = game.ui_layer.get_node_or_null("LevelUpOverlay/LevelUpDim") as ColorRect
	if dim != null:
		var dim_tween = dim.create_tween()
		dim_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		dim_tween.tween_property(dim, "color:a", 0.68, 0.16)

	# SCRUM-552: панель раскрываем только fade'ом (modulate.a). Scale-«поп» убран —
	# он сжимал глобальные rect'ы текстовых лейблов (LevelUpTitle/RewardDescription),
	# из-за чего ui_no_overlap_matrix интермиттентно краснел на оверфлоу высоты.
	var panel_tween = level_up_panel.create_tween()
	panel_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	panel_tween.set_ease(Tween.EASE_OUT)
	panel_tween.tween_property(level_up_panel, "modulate:a", 1.0, 0.18)

	var title := title_label as Label
	if title != null and is_instance_valid(title):
		title.pivot_offset = title.size * 0.5
		var title_tween = title.create_tween()
		title_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		title_tween.set_trans(Tween.TRANS_BACK)
		title_tween.set_ease(Tween.EASE_OUT)
		title_tween.tween_property(title, "scale", Vector2.ONE, 0.28)
		title_tween.parallel().tween_property(title, "modulate:a", 1.0, 0.18)

	_start_level_up_button_intro(reward_buttons)
	_start_level_up_burst_intro(sparkle_root)


func _start_level_up_button_intro(reward_buttons: Array) -> void:
	for index in range(reward_buttons.size()):
		var button := reward_buttons[index] as Button
		if button == null or not is_instance_valid(button):
			continue
		button.modulate.a = 0.0
		button.scale = Vector2(0.94, 0.94)
		button.pivot_offset = button.size * 0.5
		var button_tween = button.create_tween()
		button_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		button_tween.set_trans(Tween.TRANS_CUBIC)
		button_tween.set_ease(Tween.EASE_OUT)
		button_tween.tween_interval(0.10 + float(index) * 0.07)
		button_tween.tween_property(button, "scale", Vector2.ONE, 0.22)
		button_tween.parallel().tween_property(button, "modulate:a", 1.0, 0.18)


func _start_level_up_burst_intro(sparkle_root: Node) -> void:
	if sparkle_root == null or not is_instance_valid(sparkle_root):
		return

	var center = game.ARENA_CENTER
	for child in sparkle_root.get_children():
		if not child is ColorRect:
			continue
		var rect := child as ColorRect
		var tween = rect.create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		if rect.name.begins_with("LevelUpRay"):
			rect.position = center
			rect.scale = Vector2(0.12, 1.0)
			tween.tween_property(rect, "scale", Vector2(1.0, 1.0), 0.24)
			tween.parallel().tween_property(rect, "color:a", 0.32, 0.10)
			tween.tween_property(rect, "color:a", 0.0, 0.30)
		else:
			var index := int(str(rect.name).trim_prefix("LevelUpSpark"))
			var angle := TAU * float(index) / 20.0
			var distance := 120.0 + float(index % 5) * 26.0
			rect.position = center
			rect.scale = Vector2(0.35, 0.35)
			tween.tween_interval(float(index % 4) * 0.035)
			tween.tween_property(rect, "position", center + Vector2.RIGHT.rotated(angle) * distance, 0.34)
			tween.parallel().tween_property(rect, "scale", Vector2(1.0, 1.0), 0.18)
			tween.parallel().tween_property(rect, "color:a", 0.92, 0.10)
			tween.tween_property(rect, "color:a", 0.0, 0.28)


func _level_up_badge_text() -> String:
	if game.current_player != null and is_instance_valid(game.current_player):
		return "УРОВЕНЬ %d" % int(game.current_player.get("level"))
	return "НОВЫЙ УРОВЕНЬ"


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = _action_button_size()
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_button_control(button)
	return button


func _add_text_action_block(parent: Control, title: String, description: String, action_text := "Выбрать", button_name := "") -> Button:
	var block := VBoxContainer.new()
	block.name = "%sBlock" % button_name if button_name != "" else "TextActionBlock"
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_constant_override("separation", 8)
	parent.add_child(block)

	var frame := PanelContainer.new()
	frame.name = "%sInfoFrame" % button_name if button_name != "" else "TextActionInfoFrame"
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", _character_card_style())
	block.add_child(frame)

	var text_box := VBoxContainer.new()
	text_box.add_theme_constant_override("separation", 3)
	frame.add_child(text_box)

	var title_label := Label.new()
	title_label.text = title
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 17)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.46, 1.0))
	text_box.add_child(title_label)

	if description.strip_edges() != "":
		var desc_label := Label.new()
		desc_label.text = description
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.add_theme_font_size_override("font_size", 13)
		desc_label.add_theme_color_override("font_color", Color(0.90, 0.86, 0.76, 1.0))
		text_box.add_child(desc_label)

	var button := _make_button(action_text)
	if button_name != "":
		button.name = button_name
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_set_action_button_size(button, STANDARD_ACTION_BUTTON_WIDTH)
	block.add_child(button)
	return button


func _make_compact_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = COMPACT_UTILITY_BUTTON_SIZE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 18)
	_apply_compact_button_theme(button)
	return button


func _action_button_size(width := STANDARD_ACTION_BUTTON_WIDTH) -> Vector2:
	return Vector2(minf(width, MAX_ACTION_BUTTON_VISUAL_WIDTH), STANDARD_ACTION_BUTTON_HEIGHT)


func _set_action_button_size(button: Button, width := STANDARD_ACTION_BUTTON_WIDTH, height := STANDARD_ACTION_BUTTON_HEIGHT) -> void:
	if button == null:
		return
	button.custom_minimum_size = Vector2(minf(width, MAX_ACTION_BUTTON_VISUAL_WIDTH), height)
	_apply_fantasy_button_theme(button)


func _style_button_control(button: Button) -> void:
	_apply_fantasy_button_theme(button)
	button.add_theme_font_size_override("font_size", 16)


func _apply_fantasy_button_theme(button: Button, variant := "default") -> void:
	var role := _button_role(button, variant)
	button.add_theme_stylebox_override("normal", _button_state_style(button, role, "normal"))
	button.add_theme_stylebox_override("hover", _button_state_style(button, role, "hover"))
	button.add_theme_stylebox_override("pressed", _button_state_style(button, role, "pressed"))
	button.add_theme_stylebox_override("disabled", _button_state_style(button, role, "disabled"))
	button.add_theme_stylebox_override("focus", _button_state_style(button, role, "focus"))
	button.add_theme_color_override("font_color", Color(0.98, 0.94, 0.78, 1.0))
	button.add_theme_color_override("font_hover_color", BUTTON_NEUTRAL_HOVER_FONT)
	button.add_theme_color_override("font_focus_color", BUTTON_NEUTRAL_HOVER_FONT)
	button.add_theme_color_override("font_pressed_color", Color(0.86, 1.0, 0.96, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.46, 0.49, 0.54, 1.0))


func _apply_static_level_up_return_button_theme(button: Button) -> void:
	var style := _level_up_return_button_style()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color(1.0, 0.92, 0.58, 1.0))
	button.add_theme_color_override("font_hover_color", BUTTON_NEUTRAL_HOVER_FONT)
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.92, 0.58, 1.0))
	button.add_theme_color_override("font_focus_color", BUTTON_NEUTRAL_HOVER_FONT)
	button.add_theme_color_override("font_disabled_color", Color(0.78, 0.70, 0.48, 1.0))
	button.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _level_up_return_button_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.035, 0.025, 1.0)
	style.border_color = Color(0.96, 0.72, 0.24, 1.0)
	style.set_corner_radius_all(12)
	style.set_border_width_all(3)
	style.content_margin_left = 24
	style.content_margin_top = 14
	style.content_margin_right = 24
	style.content_margin_bottom = 14
	return style


func _button_role(button: Button, variant := "default") -> String:
	if variant == "danger":
		return "danger"
	if variant in ["reward", "level_up", "primary"]:
		return "primary"
	var text := button.text.to_lower()
	if text.contains("выйти") or text.contains("покинуть") or text.contains("смерть") or text.contains("поражение"):
		return "danger"
	if text.contains("начать") or text.contains("выбрать") or text.contains("купить") or text.contains("получить") or text.contains("продолжить"):
		return "primary"
	return "secondary"


func _button_asset_type(button: Button, variant := "default") -> String:
	var button_name: String = button.name if button != null else ""
	var button_text: String = button.text.to_lower() if button != null else ""
	var size: Vector2 = button.custom_minimum_size if button != null else _action_button_size()
	if button_name == "LevelUpPlusButton":
		return "combat_level_up_plus"
	if button_name.begins_with("MainMenu"):
		return "main_menu"
	if button_name == "HeroSelectChooseButton" or button_name == "HS4ChooseButton":
		return "hero_confirm"
	if button_name == "SettingsResetAudioButton":
		return "reset_audio"
	if button_name == "SettingsResetBindingsButton":
		return "reset_bindings"
	if button_name.begins_with("CodexTab_"):
		return "codex_tab"
	if button_name.begins_with("AttributeOffer_"):
		return "attr_selector"
	if button_name.begins_with("RunPause"):
		return "pause"
	if button_name.begins_with("QuitConfirm"):
		return "pause"
	if button_name == "UpgradeFabButton":
		return "fab"
	if button_name.begins_with("BindingButton_") or button_name == "SettingsAimModeOption":
		return "rebind"
	if button_name in ["AscensionMinusButton", "AscensionPlusButton"] or size.x <= 64.0:
		return "utility"
	if variant == "level_up" or button_name == "LevelUpButton":
		return "back_l"
	if button_text == "назад":
		if size.x <= 180.0:
			return "back_s"
		if size.x <= 300.0:
			return "back_m"
		return "back_l"
	if variant in ["reward", "primary"] and size.x >= 540.0:
		return "attr_selector"
	if size.y <= 66.0:
		if size.x <= 70.0:
			return "utility"
		if size.x <= 300.0:
			return "pause"
		return "rebind"
	if size.x >= 540.0:
		return "max"
	if size.x >= 430.0:
		return "reset_bindings"
	if size.x >= 400.0:
		return "standard"
	if size.x >= 360.0:
		return "back_l"
	if size.x >= 300.0:
		return "hero_confirm"
	if size.x >= 240.0:
		return "back_m"
	return "back_s"


func _button_state_style(button: Button, _role: String, state: String, tint := Color.WHITE) -> StyleBox:
	var button_type := _button_asset_type(button)
	if button_type == "combat_level_up_plus":
		var plus_state := state
		if plus_state == "focus":
			plus_state = "hover"
		var plus_path := str(COMBAT_HUD_LEVEL_UP_BUTTON_TEXTURES.get(plus_state, COMBAT_HUD_LEVEL_UP_BUTTON_TEXTURES["normal"]))
		var plus_tint := BUTTON_NEUTRAL_HOVER_TINT if state == "hover" and tint == Color.WHITE else tint
		return _global_texture_style(plus_path, COMBAT_HUD_LEVEL_UP_MARGINS, plus_tint, COMBAT_HUD_LEVEL_UP_CONTENT)
	var texture_state := state
	if not ["normal", "hover", "pressed", "focus", "disabled"].has(texture_state):
		texture_state = "normal"
	var suffix := "" if texture_state == "normal" else "_%s" % texture_state
	var path := "%sui_btn_minimal_metal_%s%s.png" % [MINIMAL_METAL_BUTTON_DIR, button_type, suffix]
	var final_tint := tint
	var margins: Vector4 = MINIMAL_METAL_BUTTON_MARGINS.get(button_type, MINIMAL_METAL_BUTTON_MARGINS["standard"])
	var content: Vector4 = MINIMAL_METAL_BUTTON_CONTENT.get(button_type, MINIMAL_METAL_BUTTON_CONTENT["standard"])
	return _global_texture_style(path, margins, final_tint, content)


func _apply_compact_button_theme(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _button_state_style(button, "secondary", "normal"))
	button.add_theme_stylebox_override("hover", _button_state_style(button, "secondary", "hover"))
	button.add_theme_stylebox_override("pressed", _button_state_style(button, "secondary", "pressed"))
	button.add_theme_stylebox_override("focus", _button_state_style(button, "secondary", "focus"))
	button.add_theme_stylebox_override("disabled", _button_state_style(button, "secondary", "disabled"))
	button.add_theme_color_override("font_color", Color(0.98, 0.92, 0.72, 1.0))
	button.add_theme_color_override("font_hover_color", BUTTON_NEUTRAL_HOVER_FONT)
	button.add_theme_color_override("font_focus_color", BUTTON_NEUTRAL_HOVER_FONT)
	button.add_theme_color_override("font_pressed_color", Color(0.80, 1.0, 0.95, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.46, 0.49, 0.54, 1.0))


func _compact_button_style(hovered := false, pressed := false, disabled := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.075, 0.085, 0.78)
	style.border_color = Color(0.58, 0.48, 0.28, 0.86)
	if hovered:
		style.bg_color = Color(0.12, 0.10, 0.075, 0.92)
		style.border_color = Color(0.92, 0.72, 0.32, 1.0)
	if pressed:
		style.bg_color = Color(0.055, 0.060, 0.070, 0.96)
	if disabled:
		style.bg_color = Color(0.04, 0.045, 0.055, 0.58)
		style.border_color = Color(0.24, 0.24, 0.25, 0.72)
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.content_margin_left = 8
	style.content_margin_top = 6
	style.content_margin_right = 8
	style.content_margin_bottom = 6
	return style


func _hero_select_compact_choice_style(hovered := false, pressed := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.058, 0.064, 0.075, 0.80)
	style.border_color = Color(0.56, 0.50, 0.36, 0.82)
	if hovered:
		style.bg_color = Color(0.080, 0.084, 0.090, 0.92)
		style.border_color = Color(0.78, 0.72, 0.58, 0.96)
	if pressed:
		style.bg_color = Color(0.045, 0.050, 0.058, 0.96)
	style.set_corner_radius_all(7)
	style.set_border_width_all(1)
	style.content_margin_left = 6
	style.content_margin_top = 2
	style.content_margin_right = 6
	style.content_margin_bottom = 2
	return style


func _weapon_card_style(hovered := false, pressed := false, disabled := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.060, 0.074, 0.82)
	style.border_color = Color(0.50, 0.42, 0.25, 0.72)
	if hovered:
		style.bg_color = Color(0.085, 0.075, 0.060, 0.92)
		style.border_color = Color(0.92, 0.72, 0.30, 0.96)
	if pressed:
		style.bg_color = Color(0.045, 0.050, 0.060, 0.96)
	if disabled:
		style.bg_color = Color(0.04, 0.045, 0.055, 0.55)
		style.border_color = Color(0.22, 0.23, 0.25, 0.65)
	style.set_corner_radius_all(10)
	style.set_border_width_all(1)
	style.content_margin_left = 14
	style.content_margin_top = 10
	style.content_margin_right = 14
	style.content_margin_bottom = 10
	return style


func _level_up_text_field_style(hovered := false, rare := false, pressed := false, disabled := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.065, 0.060, 0.050, 0.88) if rare else Color(0.052, 0.058, 0.074, 0.86)
	style.border_color = Color(0.92, 0.72, 0.28, 0.98) if rare else Color(0.46, 0.52, 0.58, 0.82)
	if hovered:
		style.bg_color = Color(0.095, 0.080, 0.052, 0.94) if rare else Color(0.075, 0.082, 0.098, 0.94)
		style.border_color = Color(1.0, 0.84, 0.34, 1.0) if rare else Color(0.72, 0.82, 0.90, 0.94)
	if pressed:
		style.bg_color = style.bg_color.darkened(0.12)
	if disabled:
		style.bg_color = Color(0.04, 0.045, 0.055, 0.56)
		style.border_color = Color(0.25, 0.25, 0.27, 0.70)
	style.set_corner_radius_all(10)
	style.set_border_width_all(2 if rare else 1)
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	return style


func _make_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.96, 0.9, 0.68, 1.0))
	return label


func _panel_style() -> StyleBox:
	return _minimal_frame_style("panel")


func _level_up_panel_style() -> StyleBox:
	return _minimal_frame_style("panel", Color(1.06, 1.03, 1.08, 1.0))


func _level_up_hero_style() -> StyleBox:
	return _minimal_frame_style("card", Color(0.88, 1.04, 1.06, 1.0))


func _hero_portrait_style() -> StyleBox:
	return _minimal_frame_style("card", Color(1.06, 0.98, 0.82, 1.0))


func _card_hover_style() -> StyleBox:
	return _minimal_frame_style("card", BUTTON_NEUTRAL_HOVER_TINT)


func _character_card_style() -> StyleBox:
	return _minimal_frame_style("card")


func _is_economy_screen_background(screen_background_id: String) -> bool:
	return ["campfire", "upgrade", "event"].has(screen_background_id)


func _is_pause_end_screen_background(screen_background_id: String) -> bool:
	return ["pause", "victory", "death"].has(screen_background_id)


func _pause_end_modal_display_size(screen_background_id: String) -> Vector2:
	var viewport_size: Vector2 = game.get_viewport().get_visible_rect().size
	var max_width := viewport_size.x * 0.84
	var max_height := viewport_size.y * 0.90
	if screen_background_id == "victory" or screen_background_id == "death":
		max_width = viewport_size.x * 0.82
		max_height = viewport_size.y * 0.88
	var source_aspect := PAUSE_END_MODAL_SOURCE_SIZE.x / PAUSE_END_MODAL_SOURCE_SIZE.y
	var height := minf(max_height, max_width / source_aspect)
	height = clampf(height, 520.0, 820.0)
	var width := height * source_aspect
	if width > max_width:
		width = max_width
		height = width / source_aspect
	return Vector2(roundf(width), roundf(height))


func _economy_menu_panel_half_size(screen_background_id: String) -> Vector2:
	var target_size := Vector2(1120.0, 660.0)
	match screen_background_id:
		"event":
			target_size = Vector2(1720.0, 780.0)
		"upgrade":
			target_size = Vector2(1720.0, 730.0)
		"campfire":
			target_size = Vector2(1180.0, 716.0)
	var viewport_size: Vector2 = game.get_viewport().get_visible_rect().size
	var max_size := Vector2(maxf(520.0, viewport_size.x), maxf(420.0, viewport_size.y - 48.0))
	target_size.x = minf(target_size.x, max_size.x)
	target_size.y = minf(target_size.y, max_size.y)
	return target_size * 0.5


func _scaled_frame_margins(source_size: Vector2, display_size: Vector2, source_margins: Vector4) -> Vector4:
	var scale := minf(display_size.x / source_size.x, display_size.y / source_size.y)
	return Vector4(
		roundf(source_margins.x * scale),
		roundf(source_margins.y * scale),
		roundf(source_margins.z * scale),
		roundf(source_margins.w * scale)
	)


func _scaled_frame_margins_xy(source_size: Vector2, display_size: Vector2, source_margins: Vector4) -> Vector4:
	var scale_x := display_size.x / maxf(source_size.x, 1.0)
	var scale_y := display_size.y / maxf(source_size.y, 1.0)
	return Vector4(
		roundf(source_margins.x * scale_x),
		roundf(source_margins.y * scale_y),
		roundf(source_margins.z * scale_x),
		roundf(source_margins.w * scale_y)
	)


func _minimal_frame_style(frame_type: String, tint := Color.WHITE) -> StyleBox:
	var path_map := {
		"modal": MINIMAL_MODAL_PATH,
		"panel": MINIMAL_PANEL_PATH,
		"card": MINIMAL_CARD_PATH,
		"tooltip": MINIMAL_TOOLTIP_PATH,
		"hud_strip": MINIMAL_HUD_STRIP_PATH,
		"field": MINIMAL_FIELD_PATH,
	}
	var key := frame_type if path_map.has(frame_type) else "panel"
	var margins: Vector4 = MINIMAL_FRAME_TEXTURE_MARGINS.get(key, MINIMAL_FRAME_TEXTURE_MARGINS["panel"])
	var content: Vector4 = MINIMAL_FRAME_CONTENT.get(key, MINIMAL_FRAME_CONTENT["panel"])
	return _global_texture_style(str(path_map[key]), margins, tint, content, true)


func _minimal_metal_frame_style(frame_type: String, tint := Color.WHITE) -> StyleBox:
	var key := frame_type if MINIMAL_METAL_FRAME_PATHS.has(frame_type) else "panel"
	var margins: Vector4 = MINIMAL_METAL_FRAME_TEXTURE_MARGINS.get(key, MINIMAL_METAL_FRAME_TEXTURE_MARGINS["panel"])
	var content: Vector4 = MINIMAL_METAL_FRAME_CONTENT.get(key, MINIMAL_METAL_FRAME_CONTENT["panel"])
	return _global_texture_style(str(MINIMAL_METAL_FRAME_PATHS[key]), margins, tint, content, true)


# SCRUM-486: построить StyleBoxTexture для @2K-слота блока Меню/Навигация. Ассет нарисован
# РОВНО в свой пиксельный размер (OVERHAUL_2K_FRAME_SOURCE_SIZE[slot]); 9-slice-бордюры
# масштабируются от source→display (на 2K display==source, на 1080p/4K — uniform-скейл
# вьюпорта), поэтому орнамент держится в margin-band, а тянется только плоская середина.
# tile_edges=false: бордюры стретчатся по margins (как в minimal_metal panel-стиле), не тайлятся
# — для гладкого градиента, без STRETCH_SCALE на самой текстуре (верификатор SCRUM-483 чист).
func _overhaul_2k_frame_style(slot: String, display_size: Vector2, tint := Color.WHITE) -> StyleBox:
	if not OVERHAUL_2K_FRAME_PATHS.has(slot):
		return _minimal_metal_frame_style("panel", tint)
	var source_size: Vector2 = OVERHAUL_2K_FRAME_SOURCE_SIZE[slot]
	var base_margins: Vector4 = OVERHAUL_2K_FRAME_TEXTURE_MARGINS[slot]
	var base_content: Vector4 = OVERHAUL_2K_FRAME_CONTENT.get(slot, Vector4.ZERO)
	var texture_margins := _scaled_frame_margins_xy(source_size, display_size, base_margins)
	var content_margins := _scaled_frame_margins_xy(source_size, display_size, base_content)
	return _global_texture_style(str(OVERHAUL_2K_FRAME_PATHS[slot]), texture_margins, tint, content_margins, false)


func _overhaul_2k_content_margins(slot: String, display_size: Vector2) -> Vector4:
	if not OVERHAUL_2K_FRAME_SOURCE_SIZE.has(slot):
		return Vector4.ZERO
	var source_size: Vector2 = OVERHAUL_2K_FRAME_SOURCE_SIZE[slot]
	var base_content: Vector4 = OVERHAUL_2K_FRAME_CONTENT.get(slot, Vector4.ZERO)
	return _scaled_frame_margins_xy(source_size, display_size, base_content)


func _apply_overhaul_2k_button_theme(button: Button, slot: String, display_size: Vector2) -> void:
	button.add_theme_stylebox_override("normal", _overhaul_2k_frame_style(slot, display_size))
	button.add_theme_stylebox_override("hover", _overhaul_2k_frame_style(slot, display_size, BUTTON_NEUTRAL_HOVER_TINT))
	button.add_theme_stylebox_override("focus", _overhaul_2k_frame_style(slot, display_size, BUTTON_NEUTRAL_HOVER_TINT))
	button.add_theme_stylebox_override("pressed", _overhaul_2k_frame_style(slot, display_size, Color(0.90, 0.84, 0.76, 1.0)))
	button.add_theme_stylebox_override("disabled", _overhaul_2k_frame_style(slot, display_size, Color(0.58, 0.58, 0.58, 0.82)))
	button.add_theme_color_override("font_color", Color(0.98, 0.92, 0.72, 1.0))
	button.add_theme_color_override("font_hover_color", BUTTON_NEUTRAL_HOVER_FONT)
	button.add_theme_color_override("font_focus_color", BUTTON_NEUTRAL_HOVER_FONT)
	button.add_theme_color_override("font_pressed_color", Color(0.80, 1.0, 0.95, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.46, 0.49, 0.54, 1.0))


func _economy_panel_style() -> StyleBox:
	return _minimal_frame_style("panel")


# SCRUM-565: Событие @2K. Панель и карточки выбора используют per-слот overhaul_2k-рамки
# (evt_panel 1720×780, evt_card 480×340), нарисованные РОВНО в свой пиксельный размер →
# на 2K рендерятся 1:1, на 1080p/4K юниформ-скейлятся вьюпортом без растяжения орнамента.
func _event_panel_2k_style() -> StyleBox:
	var display_size := _economy_menu_panel_half_size("event") * 2.0
	return _overhaul_2k_frame_style("evt_panel", display_size)


func _configure_event_menu_layout(box: VBoxContainer) -> void:
	if box == null:
		return
	var display_size := _economy_menu_panel_half_size("event") * 2.0
	var margins := _overhaul_2k_content_margins("evt_panel", display_size)
	var content_size := Vector2(
		maxf(320.0, display_size.x - margins.x - margins.z),
		maxf(240.0, display_size.y - margins.y - margins.w)
	)
	var compact := display_size.y < 680.0
	box.name = "EventContent"
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.custom_minimum_size = content_size
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12 if compact else 16)
	var scroll := box.get_parent() as ScrollContainer
	if scroll != null:
		scroll.follow_focus = false
		scroll.scroll_vertical = 0
		scroll.custom_minimum_size = content_size
	var title_label := box.find_child("MenuTitle_event", false, false) as Label
	if title_label != null:
		title_label.name = "EventTitle"
		title_label.custom_minimum_size = Vector2(content_size.x, 38.0 if compact else 52.0)
		title_label.add_theme_font_size_override("font_size", 30 if compact else 36)
	var story_label := box.find_child("MenuSubtitle_event", false, false) as Label
	if story_label != null:
		story_label.name = "EventStory"
		story_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		story_label.custom_minimum_size = Vector2(content_size.x, 58.0 if compact else 92.0)
		story_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		story_label.add_theme_font_size_override("font_size", 14 if compact else 17)


# SCRUM-573: Улучшение @2K. Панель экрана улучшения — per-слот overhaul_2k-рамка
# (upgrade_panel 1720×730), нарисованная РОВНО в свой пиксельный размер → на 2K 1:1,
# на 1080p/4K юниформ-скейл вьюпортом без растяжения орнамента. Карточки выбора —
# общий economy-choice-арт (как остальные economy-экраны кроме события).
func _upgrade_panel_2k_style() -> StyleBox:
	var display_size := _economy_menu_panel_half_size("upgrade") * 2.0
	return _overhaul_2k_frame_style("upgrade_panel", display_size)


# SCRUM-565/568: переинсет контента карточки выбора под content-зону её overhaul_2k-рамки
# (slot), чтобы текст/иконки держались внутри safe-зоны и не лезли на орнамент.
func _reinset_overhaul_choice_content(button: Button, slot: String, display_size: Vector2) -> void:
	if button == null or not UIThemePaths.OVERHAUL_2K_FRAME_SOURCE_SIZE.has(slot):
		return
	var content := button.find_child("%sContent" % button.name, true, false) as Control
	if content == null:
		return
	var source_size: Vector2 = UIThemePaths.OVERHAUL_2K_FRAME_SOURCE_SIZE[slot]
	var base_content: Vector4 = UIThemePaths.OVERHAUL_2K_FRAME_CONTENT.get(slot, Vector4.ZERO)
	var margins := _scaled_frame_margins_xy(source_size, display_size, base_content)
	content.offset_left = margins.x
	content.offset_top = margins.y
	content.offset_right = -margins.z
	content.offset_bottom = -margins.w
	button.set_meta("economy_content_margins", margins)


# SCRUM-565/568: переодеть карточку выбора в overhaul_2k-рамку slot (normal/hover/
# pressed/focus/disabled) с теми же нейтральными тинтами, что у economy-карт.
func _apply_overhaul_choice_2k_theme(button: Button, slot: String, display_size: Vector2) -> void:
	button.add_theme_stylebox_override("normal", _overhaul_2k_frame_style(slot, display_size))
	button.add_theme_stylebox_override("hover", _overhaul_2k_frame_style(slot, display_size, BUTTON_NEUTRAL_HOVER_TINT))
	button.add_theme_stylebox_override("pressed", _overhaul_2k_frame_style(slot, display_size, Color(0.90, 0.84, 0.76, 1.0)))
	button.add_theme_stylebox_override("focus", _overhaul_2k_frame_style(slot, display_size, BUTTON_NEUTRAL_HOVER_TINT))
	button.add_theme_stylebox_override("disabled", _overhaul_2k_frame_style(slot, display_size, Color(0.58, 0.58, 0.58, 0.82)))
	button.add_theme_color_override("font_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_hover_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_pressed_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_focus_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_disabled_color", Color.TRANSPARENT)


func _pause_end_modal_style(display_size: Vector2, screen_background_id := "") -> StyleBox:
	# SCRUM-578: экран «Смерть» (end-модалка результата) получает per-слот @2K-рамку
	# result_panel (RESULT_PANEL_2K 898×820), нарисованную РОВНО в свой размер → резкий
	# орнамент на 1080p/2K/4K. Победа/пауза пока на общем PAUSE_END_MODAL_PATH (свои таски).
	if screen_background_id == "death":
		return _overhaul_2k_frame_style("result_panel", display_size)
	var texture_margins := _scaled_frame_margins(PAUSE_END_MODAL_SOURCE_SIZE, display_size, PAUSE_END_MODAL_TEXTURE_MARGINS)
	var content_margins := _scaled_frame_margins(PAUSE_END_MODAL_SOURCE_SIZE, display_size, PAUSE_END_MODAL_CONTENT)
	return _global_texture_style(PAUSE_END_MODAL_PATH, texture_margins, Color.WHITE, content_margins, true)


func _economy_choice_style(display_size: Vector2, hovered := false, pressed := false, disabled := false) -> StyleBox:
	var path := ECONOMY_CHOICE_CARD_HOVER_PATH if hovered else ECONOMY_CHOICE_CARD_PATH
	var texture_margins := _scaled_frame_margins_xy(ECONOMY_CHOICE_SOURCE_SIZE, display_size, ECONOMY_CHOICE_HOVER_TEXTURE_MARGINS if hovered else ECONOMY_CHOICE_TEXTURE_MARGINS)
	var content_margins := _scaled_frame_margins_xy(ECONOMY_CHOICE_SOURCE_SIZE, display_size, ECONOMY_CHOICE_HOVER_CONTENT if hovered else ECONOMY_CHOICE_CONTENT)
	var tint := Color.WHITE
	if hovered:
		tint = BUTTON_NEUTRAL_HOVER_TINT
	if pressed:
		tint = Color(0.90, 0.84, 0.76, 1.0)
	if disabled:
		tint = Color(0.58, 0.58, 0.58, 0.82)
	return _global_texture_style(path, texture_margins, tint, content_margins, true)


func _economy_choice_content_margins(display_size: Vector2) -> Vector4:
	return _scaled_frame_margins_xy(ECONOMY_CHOICE_SOURCE_SIZE, display_size, ECONOMY_CHOICE_CONTENT)


func _economy_choice_display_size(cards_in_row := 3) -> Vector2:
	var viewport_size := Vector2(1280.0, 720.0)
	if game != null and game.get_viewport() != null:
		viewport_size = game.get_viewport().get_visible_rect().size
	if cards_in_row <= 2:
		if viewport_size.x >= 1920.0 and viewport_size.y >= 1000.0:
			return ECONOMY_CHOICE_TARGET_1440
		return ECONOMY_CHOICE_TARGET_1080
	if viewport_size.x < 1280.0:
		return Vector2(320.0, 240.0)
	if viewport_size.x >= 2400.0 and viewport_size.y >= 1200.0:
		return ECONOMY_CHOICE_TARGET_1440
	if viewport_size.x >= 1800.0 and viewport_size.y >= 900.0:
		return ECONOMY_CHOICE_TARGET_1080
	return ECONOMY_CHOICE_TARGET_720


func _economy_attribute_choice_display_size() -> Vector2:
	var size := _economy_choice_display_size(3)
	var viewport_size := Vector2(1280.0, 720.0)
	if game != null and game.get_viewport() != null:
		viewport_size = game.get_viewport().get_visible_rect().size
	if viewport_size.y <= 660.0:
		return Vector2(maxf(size.x, 320.0), 240.0)
	if size.y < 280.0:
		size.y = 280.0
	return size


func _economy_choice_row_gap(display_size: Vector2) -> int:
	if display_size.x >= ECONOMY_CHOICE_TARGET_1440.x:
		return 48
	if display_size.x >= ECONOMY_CHOICE_TARGET_1080.x:
		return 36
	if display_size.x < ECONOMY_CHOICE_TARGET_720.x:
		return 20
	return 24


func _apply_economy_choice_theme(button: Button, display_size: Vector2) -> void:
	button.add_theme_stylebox_override("normal", _economy_choice_style(display_size))
	button.add_theme_stylebox_override("hover", _economy_choice_style(display_size, true))
	button.add_theme_stylebox_override("pressed", _economy_choice_style(display_size, true, true))
	button.add_theme_stylebox_override("focus", _economy_choice_style(display_size, true))
	button.add_theme_stylebox_override("disabled", _economy_choice_style(display_size, false, false, true))
	button.add_theme_color_override("font_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_hover_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_pressed_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_focus_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_disabled_color", Color.TRANSPARENT)


func _make_economy_choice_row(row_name: String, display_size := Vector2.ZERO, cards_in_row := 3) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = row_name
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var resolved_size := _economy_choice_display_size(cards_in_row) if display_size == Vector2.ZERO else display_size
	var gap := _economy_choice_row_gap(resolved_size)
	row.custom_minimum_size.x = resolved_size.x * float(cards_in_row) + float(gap * maxi(cards_in_row - 1, 0))
	row.add_theme_constant_override("separation", gap)
	return row


func _make_economy_choice_card(title: String, description: String, action_text: String, button_name: String, display_size: Vector2) -> Button:
	var button := Button.new()
	button.name = button_name if button_name != "" else "EconomyChoiceCard"
	var compact_attribute := button.name.begins_with("AttributeOffer_")
	button.set_meta("economy_frame_kind", "choice_card")
	button.set_meta("economy_frame_path", ECONOMY_CHOICE_CARD_PATH)
	button.set_meta("economy_hover_frame_path", ECONOMY_CHOICE_CARD_HOVER_PATH)
	button.set_meta("economy_source_size", ECONOMY_CHOICE_SOURCE_SIZE)
	button.set_meta("economy_source_safe_rect", ECONOMY_CHOICE_SAFE_RECT)
	button.set_meta("economy_display_size", display_size)
	button.text = ""
	button.custom_minimum_size = display_size
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = "%s\n%s" % [title, description]
	_apply_economy_choice_theme(button, display_size)

	var margins := _economy_choice_content_margins(display_size)
	button.set_meta("economy_content_margins", margins)
	var content := VBoxContainer.new()
	content.name = "%sContent" % button.name
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = margins.x
	content.offset_top = margins.y
	content.offset_right = -margins.z
	content.offset_bottom = -margins.w
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 3 if compact_attribute else 7)
	button.add_child(content)

	var title_label := Label.new()
	title_label.name = "%sTitle" % button.name
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 14 if compact_attribute else 17)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.46, 1.0))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title_label)

	var desc_label := Label.new()
	desc_label.name = "%sDescription" % button.name
	desc_label.text = description
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_label.add_theme_font_size_override("font_size", 11 if compact_attribute else 13)
	desc_label.add_theme_color_override("font_color", Color(0.90, 0.86, 0.76, 1.0))
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(desc_label)

	var action_label := Label.new()
	action_label.name = "%sAction" % button.name
	action_label.text = action_text
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_label.add_theme_font_size_override("font_size", 12 if compact_attribute else 15)
	action_label.add_theme_color_override("font_color", Color(0.74, 0.92, 1.0, 1.0))
	action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(action_label)
	return button


func _prepend_economy_choice_content(button: Button, control: Control) -> void:
	if button == null or control == null:
		return
	var content := button.find_child("%sContent" % button.name, true, false) as BoxContainer
	if content == null:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(control)
		return
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(control)
	content.move_child(control, 0)


func _reward_card_content_margins(elite := false) -> Vector4:
	var source_content := REWARD_ELITE_CARD_SOURCE_CONTENT if elite else REWARD_CARD_SOURCE_CONTENT
	var display_size := REWARD_ELITE_CARD_SIZE if elite else REWARD_CARD_SIZE
	return Vector4(
		roundf(source_content.x / REWARD_FRAME_SOURCE_SIZE.x * display_size.x),
		roundf(source_content.y / REWARD_FRAME_SOURCE_SIZE.y * display_size.y),
		roundf(source_content.z / REWARD_FRAME_SOURCE_SIZE.x * display_size.x),
		roundf(source_content.w / REWARD_FRAME_SOURCE_SIZE.y * display_size.y)
	)


func _reward_card_style(elite := false, hovered := false, pressed := false, disabled := false) -> StyleBox:
	var path := REWARD_ELITE_CARD_PATH if elite else REWARD_CARD_PATH
	if hovered:
		path = REWARD_ELITE_CARD_HOVER_PATH if elite else REWARD_CARD_HOVER_PATH
	var source_margins := REWARD_ELITE_CARD_TEXTURE_MARGINS if elite else REWARD_CARD_TEXTURE_MARGINS
	var display_size := REWARD_ELITE_CARD_SIZE if elite else REWARD_CARD_SIZE
	var texture_margins := _scaled_frame_margins_xy(REWARD_FRAME_SOURCE_SIZE, display_size, source_margins)
	var content_margins := _reward_card_content_margins(elite)
	var tint := Color.WHITE
	if hovered:
		tint = BUTTON_NEUTRAL_HOVER_TINT
	if pressed:
		tint = Color(0.88, 0.84, 0.90, 1.0) if elite else Color(0.90, 0.86, 0.78, 1.0)
	if disabled:
		tint = Color(0.58, 0.58, 0.58, 0.82)
	var texture: Texture2D = game._cached_texture(path)
	if texture == null:
		var fallback := StyleBoxFlat.new()
		fallback.bg_color = Color(0.08, 0.055, 0.08, 0.96) if elite else Color(0.09, 0.06, 0.045, 0.96)
		fallback.border_color = Color(0.72, 0.50, 1.0, 0.88) if elite else Color(0.95, 0.72, 0.28, 0.88)
		fallback.set_border_width_all(2)
		fallback.set_corner_radius_all(8)
		fallback.content_margin_left = content_margins.x
		fallback.content_margin_top = content_margins.y
		fallback.content_margin_right = content_margins.z
		fallback.content_margin_bottom = content_margins.w
		return fallback
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = texture_margins.x
	style.texture_margin_top = texture_margins.y
	style.texture_margin_right = texture_margins.z
	style.texture_margin_bottom = texture_margins.w
	style.modulate_color = tint
	style.content_margin_left = content_margins.x
	style.content_margin_top = content_margins.y
	style.content_margin_right = content_margins.z
	style.content_margin_bottom = content_margins.w
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return style


func _apply_reward_card_theme(button: Button, elite := false) -> void:
	button.add_theme_stylebox_override("normal", _reward_card_style(elite))
	button.add_theme_stylebox_override("hover", _reward_card_style(elite, true))
	button.add_theme_stylebox_override("pressed", _reward_card_style(elite, true, true))
	button.add_theme_stylebox_override("focus", _reward_card_style(elite, true))
	button.add_theme_stylebox_override("disabled", _reward_card_style(elite, false, false, true))
	button.add_theme_color_override("font_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_hover_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_pressed_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_focus_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_disabled_color", Color.TRANSPARENT)


func _add_reward_card_content_container(button: Button, elite := false) -> VBoxContainer:
	var margins := _reward_card_content_margins(elite)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = margins.x
	content.offset_top = margins.y
	content.offset_right = -margins.z
	content.offset_bottom = -margins.w
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	button.add_child(content)
	return content


func _codex_main_panel_style() -> StyleBox:
	return _global_texture_style(CODEX_MAIN_PANEL_PATH, CODEX_MAIN_PANEL_MARGINS, Color.WHITE, CODEX_MAIN_PANEL_CONTENT, true)


func _codex_v2_main_panel_style() -> StyleBox:
	return _overhaul_2k_frame_style("codex_main", CODEX_V2_OUTER_FRAME_RECT.size)


func _codex_v2_nav_panel_style() -> StyleBox:
	return _overhaul_2k_frame_style("codex_nav", CODEX_V2_NAV_PANEL_RECT.size)


func _codex_v2_list_panel_style() -> StyleBox:
	return _overhaul_2k_frame_style("codex_list", CODEX_V2_LIST_PANEL_RECT.size)


func _codex_v2_detail_panel_style() -> StyleBox:
	return _overhaul_2k_frame_style("codex_detail", CODEX_V2_DETAIL_PANEL_RECT.size)


func _codex_section_panel_style() -> StyleBox:
	return _global_texture_style(CODEX_SECTION_PANEL_PATH, CODEX_SECTION_PANEL_MARGINS, Color.WHITE, CODEX_SECTION_PANEL_CONTENT, true)


func _codex_entry_card_style(hovered := false) -> StyleBox:
	var tint := BUTTON_NEUTRAL_HOVER_TINT if hovered else Color.WHITE
	return _overhaul_2k_frame_style("codex_entry_card", CODEX_V2_ENTRY_CARD_SOURCE_SIZE, tint)


func _codex_portrait_slot_style() -> StyleBox:
	return _global_texture_style(CODEX_PORTRAIT_SLOT_PATH, CODEX_PORTRAIT_SLOT_MARGINS, Color.WHITE, CODEX_PORTRAIT_SLOT_CONTENT, true)


func _codex_tooltip_style() -> StyleBox:
	return _global_texture_style(CODEX_TOOLTIP_PATH, CODEX_TOOLTIP_MARGINS, Color.WHITE, CODEX_TOOLTIP_CONTENT, true)


func _progression_main_panel_style() -> StyleBox:
	return _global_texture_style(PROGRESSION_MAIN_PANEL_PATH, PROGRESSION_MAIN_PANEL_MARGINS, Color.WHITE, PROGRESSION_MAIN_PANEL_CONTENT)


func _progression_branch_panel_style() -> StyleBox:
	return _global_texture_style(PROGRESSION_BRANCH_PANEL_PATH, PROGRESSION_BRANCH_PANEL_MARGINS, Color.WHITE, PROGRESSION_BRANCH_PANEL_CONTENT)


func _progression_class_panel_style() -> StyleBox:
	return _global_texture_style(PROGRESSION_CLASS_PANEL_PATH, PROGRESSION_CLASS_PANEL_MARGINS, Color.WHITE, PROGRESSION_CLASS_PANEL_CONTENT)


func _progression_points_badge_style() -> StyleBox:
	return _global_texture_style(PROGRESSION_POINTS_BADGE_PATH, Vector4.ZERO, Color.WHITE, PROGRESSION_POINTS_BADGE_CONTENT)


func _progression_tooltip_style() -> StyleBox:
	return _global_texture_style(PROGRESSION_TOOLTIP_PATH, PROGRESSION_TOOLTIP_MARGINS, Color.WHITE, PROGRESSION_TOOLTIP_CONTENT)


func _progression_node_style(status: String, focused := false) -> StyleBox:
	var texture_id := "focus" if focused else status
	if not PROGRESSION_NODE_TEXTURES.has(texture_id):
		texture_id = "locked"
	var tint := Color.WHITE
	if status == "locked":
		tint = Color(0.70, 0.72, 0.78, 0.82)
	return _global_texture_style(str(PROGRESSION_NODE_TEXTURES[texture_id]), Vector4.ZERO, tint, Vector4(18.0, 18.0, 18.0, 18.0))


func _apply_progression_node_button_theme(button: Button, status: String) -> void:
	button.add_theme_stylebox_override("normal", _progression_node_style(status))
	button.add_theme_stylebox_override("hover", _progression_node_style(status, true))
	button.add_theme_stylebox_override("pressed", _progression_node_style(status, true))
	button.add_theme_stylebox_override("focus", _progression_node_style(status, true))
	button.add_theme_stylebox_override("disabled", _progression_node_style(status))


func _hero_select_clear_button_style(hovered := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.86, 0.42, 0.08) if hovered else Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(1.0, 0.82, 0.34, 0.42) if hovered else Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(2 if hovered else 0)
	style.set_corner_radius_all(3)
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	return style


func _apply_hero_select_clear_button_theme(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _hero_select_clear_button_style(false))
	button.add_theme_stylebox_override("hover", _hero_select_clear_button_style(true))
	button.add_theme_stylebox_override("pressed", _hero_select_clear_button_style(true))
	button.add_theme_stylebox_override("focus", _hero_select_clear_button_style(true))
	button.add_theme_stylebox_override("disabled", _hero_select_clear_button_style(false))


func _hero_select_text_backplate_style(alpha := 0.68) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.026, 0.024, alpha)
	style.border_color = Color(0.75, 0.55, 0.22, 0.18)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_top = 4
	style.content_margin_right = 8
	style.content_margin_bottom = 4
	return style


func _button_style(background: Color, _border: Color, _shadow_alpha := 0.38, _border_width := 2) -> StyleBox:
	var tint := background.lightened(0.38)
	tint.a = 1.0
	return _global_texture_style(GLOBAL_BUTTON_FRAME_PATH, Vector4(34, 26, 34, 28), tint, Vector4(18, 12, 18, 14))


func _bar_style(background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.set_corner_radius_all(6)
	return style


func _slider_track_style(background: Color, border := Color(0.0, 0.0, 0.0, 0.0)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0.0 else 0)
	style.set_corner_radius_all(9)
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.content_margin_left = 10
	style.content_margin_right = 10
	return style


func _global_texture_style(path: String, margins: Vector4, tint := Color.WHITE, content := Vector4.ZERO, tile_edges := false) -> StyleBox:
	var texture: Texture2D = game._cached_texture(path)
	if texture == null:
		var fallback := StyleBoxFlat.new()
		fallback.bg_color = Color(0.06, 0.08, 0.12, 0.94)
		fallback.border_color = Color(0.95, 0.78, 0.32, 0.85)
		fallback.set_border_width_all(2)
		fallback.set_corner_radius_all(8)
		fallback.content_margin_left = content.x
		fallback.content_margin_top = content.y
		fallback.content_margin_right = content.z
		fallback.content_margin_bottom = content.w
		return fallback
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = margins.x
	style.texture_margin_top = margins.y
	style.texture_margin_right = margins.z
	style.texture_margin_bottom = margins.w
	if tile_edges:
		style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.modulate_color = tint
	style.content_margin_left = content.x
	style.content_margin_top = content.y
	style.content_margin_right = content.z
	style.content_margin_bottom = content.w
	return style


func _unified_frame_style(frame_type: String, tint := Color.WHITE, center_fill := true) -> StyleBox:
	var content: Vector4 = UNIFIED_FRAME_CONTENT.get(frame_type, UNIFIED_FRAME_CONTENT.get("global_panel", Vector4(24, 24, 24, 24)))
	var path := UNIFIED_MASTER_FILL_FRAME_PATH if center_fill else GLOBAL_PANEL_FRAME_PATH
	return _global_texture_style(path, UNIFIED_FRAME_TEXTURE_MARGINS, tint, content, true)


func _ornate_frame_style(path: String, frame_type: String, tint := Color.WHITE) -> StyleBox:
	var margins: Vector4 = ORNATE_FRAME_MARGINS.get(frame_type, Vector4(30, 30, 30, 30))
	var content: Vector4 = ORNATE_FRAME_CONTENT.get(frame_type, Vector4(12, 12, 12, 12))
	return _global_texture_style(path, margins, tint, content)


func _style_slider(slider: HSlider) -> void:
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slider.add_theme_stylebox_override("slider", _slider_track_style(Color(0.035, 0.045, 0.065, 0.96), Color(0.55, 0.42, 0.18, 0.85)))
	slider.add_theme_stylebox_override("grabber_area", _slider_track_style(Color(0.86, 0.62, 0.20, 0.82), Color(1.0, 0.82, 0.36, 0.90)))
	slider.add_theme_stylebox_override("grabber_area_highlight", _slider_track_style(Color(1.0, 0.76, 0.28, 0.95), Color(1.0, 0.92, 0.54, 1.0)))
	slider.add_theme_constant_override("center_grabber", 1)
	var grabber: Texture2D = game._cached_texture(SYSTEM_SLIDER_GRABBER_PATH)
	if grabber != null:
		slider.add_theme_icon_override("grabber", grabber)
		slider.add_theme_icon_override("grabber_highlight", grabber)
		slider.add_theme_icon_override("grabber_disabled", grabber)


func _style_checkbox(toggle: CheckBox) -> void:
	toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var unchecked: Texture2D = game._cached_texture(SYSTEM_CHECKBOX_UNCHECKED_PATH)
	var checked: Texture2D = game._cached_texture(SYSTEM_CHECKBOX_CHECKED_PATH)
	if unchecked != null:
		toggle.add_theme_icon_override("unchecked", unchecked)
		toggle.add_theme_icon_override("unchecked_disabled", unchecked)
	if checked != null:
		toggle.add_theme_icon_override("checked", checked)
		toggle.add_theme_icon_override("checked_disabled", checked)
	toggle.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	toggle.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.54, 1.0))
	toggle.add_theme_color_override("font_pressed_color", Color(0.70, 1.0, 0.92, 1.0))


func _create_hud() -> void:
	game._clear_hud()
	game.hud_layer = CanvasLayer.new()
	game.hud_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.hud_layer)

	var root := Control.new()
	root.name = "CombatHudRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.hud_layer.add_child(root)

	_create_resource_hud_panel(root, Vector2(20, 18))
	_create_character_stats_hud(root, Vector2(20, 110))
	_create_combat_timer_panel(root)
	_create_artifact_hud_row(root)
	_create_damage_flash_overlay(root)
	_create_low_hp_vignette(root)
	_create_threat_indicator_overlay(root)
	root.resized.connect(func() -> void:
		_layout_combat_hud(root)
	)
	_layout_combat_hud(root)
	call_deferred("_layout_combat_hud", root)
	_update_level_up_button()
	_update_hud()


const ROMAN_NUMERALS := ["0", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]


func _create_combat_timer_panel(root: Control) -> void:
	# Индикатор уровня возвышения (римская цифра) — поверх любого боя.
	if game.selected_ascension_level > 0:
		var asc_badge := PanelContainer.new()
		asc_badge.name = "AscensionHudBadge"
		asc_badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
		asc_badge.position = Vector2(0, 18)
		asc_badge.custom_minimum_size = Vector2(64, 64)
		asc_badge.add_theme_stylebox_override("panel", _ascension_badge_style())
		asc_badge.tooltip_text = "Возвышение %d\n%s" % [game.selected_ascension_level, "\n".join(game.PROGRESSION_DATA.ascension_modifier_lines(game.selected_ascension_level))]
		root.add_child(asc_badge)
		var asc_text := Label.new()
		asc_text.text = ROMAN_NUMERALS[clampi(game.selected_ascension_level, 0, game.META_PROGRESSION.MAX_ASCENSION_LEVEL)]  # SCRUM-622: клампить по динамическому капу (5), не хардкод 10
		asc_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		asc_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		asc_text.add_theme_font_size_override("font_size", 24)
		asc_text.add_theme_color_override("font_color", Color(1.0, 0.74, 0.30, 1.0))
		asc_badge.add_child(asc_text)

	# На босс-файтах таймера нет — панель не создается вовсе.
	if game.boss_combat_active:
		game.timer_label = null
		return
	var panel := PanelContainer.new()
	panel.name = "CombatTimerPanel"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(0, 14)
	panel.custom_minimum_size = Vector2(192, 64)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _timer_panel_style(false))
	root.add_child(panel)

	var label := Label.new()
	label.name = "CombatTimerLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.74, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.03, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	panel.add_child(label)
	game.timer_label = label


func _timer_panel_style(alarm: bool) -> StyleBox:
	# SCRUM-564: per-слот @2K-рамка таймера (CHUD_TIMER_2K=288×96), нарисованная 1:1 под слот
	# с нативными 9-slice бордюрами — резкий орнамент на 1080p/2K/4K вместо ужатого field-фрейма.
	var tint := Color(1.20, 0.78, 0.72, 1.0) if alarm else Color.WHITE
	return _overhaul_2k_frame_style("chud_timer", Vector2(288.0, 96.0), tint)


func _ascension_badge_style() -> StyleBox:
	return _global_texture_style(COMBAT_HUD_ASCENSION_BADGE_PATH, Vector4(6, 8, 6, 8), Color.WHITE, Vector4(10, 10, 10, 10), true)


func _create_artifact_hud_row(root: Control) -> void:
	var row := HFlowContainer.new()
	row.name = "ArtifactHudRow"
	row.set_anchors_preset(Control.PRESET_TOP_LEFT)
	row.position = Vector2(0, 16)
	row.custom_minimum_size = Vector2(402, 104)
	row.alignment = FlowContainer.ALIGNMENT_END
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(row)


func _layout_combat_hud(root: Control) -> void:
	if root == null or not is_instance_valid(root):
		return
	var viewport_width := maxf(root.size.x, root.get_viewport_rect().size.x)
	if viewport_width <= 0.0:
		viewport_width = 1280.0
	var margin := 18.0
	var gap := 14.0
	var timer_size := Vector2(288, 96)
	var resource := root.find_child("RunResourceHud", true, false) as PanelContainer
	if resource != null:
		var resource_width := clampf(viewport_width * 0.54, 650.0, 820.0)
		if viewport_width <= 1280.0:
			resource_width = minf(resource_width, 690.0)
		resource.set_anchors_preset(Control.PRESET_TOP_LEFT)
		resource.position = Vector2(margin, 18.0)
		resource.custom_minimum_size = Vector2(resource_width, 84.0)
		resource.size = resource.custom_minimum_size
	var resource_right := margin
	if resource != null:
		resource_right = resource.position.x + resource.custom_minimum_size.x

	var stats_hud := root.find_child("CharacterStatsHud", true, false) as PanelContainer
	if stats_hud != null:
		var stats_width := 690.0
		if resource != null:
			stats_width = resource.custom_minimum_size.x
		else:
			stats_width = clampf(viewport_width * 0.54, 650.0, 820.0)
			if viewport_width <= 1280.0:
				stats_width = minf(stats_width, 690.0)
		stats_hud.set_anchors_preset(Control.PRESET_TOP_LEFT)
		stats_hud.position = Vector2(margin, 110.0)
		stats_hud.custom_minimum_size = Vector2(stats_width, 58.0)
		stats_hud.size = stats_hud.custom_minimum_size

	var timer_panel := root.find_child("CombatTimerPanel", true, false) as PanelContainer
	var timer_left := viewport_width * 0.5 - timer_size.x * 0.5
	if timer_panel != null:
		var right_limit := viewport_width - timer_size.x - margin
		if timer_left < resource_right + gap:
			timer_left = minf(resource_right + gap, right_limit)
			if timer_left < resource_right + gap:
				var narrow_resource_width := maxf(480.0, timer_left - gap - margin)
				if resource != null:
					resource.custom_minimum_size.x = narrow_resource_width
					resource.size.x = narrow_resource_width
					resource_right = resource.position.x + resource.custom_minimum_size.x
				timer_left = maxf(resource_right + gap, margin)
		timer_left = minf(timer_left, right_limit)
		timer_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		timer_panel.position = Vector2(timer_left, 14.0)
		timer_panel.custom_minimum_size = timer_size
		timer_panel.size = timer_size

	var asc_badge := root.find_child("AscensionHudBadge", true, false) as PanelContainer
	if asc_badge != null:
		var badge_size := 64.0
		var anchor_left := timer_left + timer_size.x + 8.0
		var badge_top := 18.0
		if timer_panel == null:
			anchor_left = maxf(viewport_width * 0.5 - badge_size * 0.5, resource_right + gap)
		if anchor_left + badge_size > viewport_width - margin:
			anchor_left = maxf(margin, timer_left - badge_size - 8.0)
		var badge_would_overlap_resource := false
		if resource != null:
			badge_would_overlap_resource = Rect2(Vector2(anchor_left, badge_top), Vector2(badge_size, badge_size)).intersects(Rect2(resource.position, resource.size))
		if anchor_left < resource_right + gap and badge_would_overlap_resource:
			badge_top = 110.0
		asc_badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
		asc_badge.position = Vector2(anchor_left, badge_top)
		asc_badge.custom_minimum_size = Vector2(badge_size, badge_size)
		asc_badge.size = asc_badge.custom_minimum_size

	var artifact_row := root.find_child("ArtifactHudRow", true, false) as HFlowContainer
	if artifact_row != null:
		var row_width := clampf(viewport_width * 0.28, 220.0, 402.0)
		var row_left := viewport_width - row_width - margin
		var row_top := 16.0
		var occupied_right := resource_right
		var occupied_bottom := 0.0
		if resource != null:
			occupied_bottom = maxf(occupied_bottom, resource.position.y + resource.size.y)
		if timer_panel != null:
			occupied_right = maxf(occupied_right, timer_panel.position.x + timer_size.x)
			occupied_bottom = maxf(occupied_bottom, timer_panel.position.y + timer_size.y)
		if asc_badge != null:
			occupied_right = maxf(occupied_right, asc_badge.position.x + asc_badge.custom_minimum_size.x)
			occupied_bottom = maxf(occupied_bottom, asc_badge.position.y + asc_badge.custom_minimum_size.y)
		if row_left < occupied_right + gap:
			row_top = occupied_bottom + 8.0
		artifact_row.set_anchors_preset(Control.PRESET_TOP_LEFT)
		artifact_row.position = Vector2(row_left, row_top)
		artifact_row.custom_minimum_size = Vector2(row_width, 104.0)
		artifact_row.size = artifact_row.custom_minimum_size


func _refresh_artifact_hud_row() -> void:
	if game.hud_layer == null or not is_instance_valid(game.hud_layer):
		return
	var row := game.hud_layer.find_child("ArtifactHudRow", true, false) as HFlowContainer
	if row == null:
		return
	for child in row.get_children():
		child.queue_free()
	for artifact in _player_artifacts():
		var artifact_id := str(artifact.get("id", ""))
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(48, 48)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = _artifact_icon_texture(artifact_id)
		icon.tooltip_text = _artifact_tooltip(artifact)
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(icon)


func _player_artifact_count() -> int:
	# Дешевый счетчик для ежекадрового HUD-снапшота (без нормализации списка).
	if game.current_player != null and is_instance_valid(game.current_player):
		return (game.current_player.get("artifacts") as Array).size()
	return (game.run_player_snapshot.get("artifacts", []) as Array).size()


func _player_artifacts() -> Array:
	var raw: Array = []
	if game.current_player != null and is_instance_valid(game.current_player):
		raw = game.current_player.get("artifacts")
	else:
		raw = game.run_player_snapshot.get("artifacts", [])
	var normalized := []
	for entry in raw:
		if entry is Dictionary:
			normalized.append(entry)
		else:
			# Совместимость со старым форматом, где хранился только title.
			normalized.append({"id": "", "title": str(entry)})
	return normalized


func _artifact_icon_texture(artifact_id: String) -> Texture2D:
	var path := "%sartifact_%s.png" % [ARTIFACT_ICON_DIR, artifact_id]
	if artifact_id != "" and ResourceLoader.exists(path):
		return game._cached_texture(path)
	return game.UIIconRegistry.texture_for("buff_power")


const TIER_LABELS := {1: "Тир 1", 2: "Тир 2 — редкий", 3: "Тир 3 — легендарный"}
const TIER_COLORS := {
	1: Color(0.80, 0.86, 0.94, 1.0),
	2: Color(0.46, 0.78, 1.0, 1.0),
	3: Color(1.0, 0.74, 0.30, 1.0),
}
const CLASS_RU := {
	"berserk": "Берсерк",
	"dark_mage": "Темный маг",
	"guitarist": "Гитарист",
	"assassin": "Ассасин",
	"ranger": "Рейнджер",
	"doctor": "Доктор",
	"chemist": "Химик",
	"knight": "Рыцарь",
	"druid": "Друид",
}


func _artifact_affinity_note(definition: Dictionary) -> Dictionary:
	# С 0.2 классовая часть больше не пропадает: affinity теперь объясняет,
	# как артефакт интерпретируется текущим классом.
	var affinity: Array = definition.get("class_affinity", definition.get("classes", []))
	if affinity.is_empty() or affinity.has(game.selected_character_id):
		return {}
	var affinity_keys := (definition.get("affinity_mods", {}) as Dictionary).keys()
	var parameter_id := "buff_power"
	if not affinity_keys.is_empty():
		parameter_id = str(game.LEVEL_UP_MOD_DISPLAY.get(str(affinity_keys[0]), affinity_keys[0]))
	var text := "Интерпретация: %s" % game.PROGRESSION_DATA.class_interpretation_text(game.selected_character_id, parameter_id)
	return {"text": text, "color": Color(0.55, 0.92, 1.0, 1.0)}


func _artifact_affinity_suffix(definition: Dictionary) -> String:
	var note := _artifact_affinity_note(definition)
	if note.is_empty():
		return ""
	return "
[%s]" % note["text"]


func _artifact_tier_text(definition: Dictionary) -> String:
	return str(TIER_LABELS.get(int(definition.get("tier", 1)), "Тир 1"))


func _artifact_tier_color(definition: Dictionary) -> Color:
	return TIER_COLORS.get(int(definition.get("tier", 1)), TIER_COLORS[1])


func _artifact_tooltip(artifact: Dictionary) -> String:
	var artifact_id := str(artifact.get("id", ""))
	var title := str(artifact.get("title", ""))
	var definition: Dictionary = game.PROGRESSION_DATA.artifact_definition(artifact_id)
	var description := str(definition.get("description", ""))
	if description == "":
		return title
	return "%s (%s)
%s%s" % [title, _artifact_tier_text(definition), description, _artifact_affinity_suffix(definition)]


func _create_damage_flash_overlay(root: Control) -> void:
	var flash := ColorRect.new()
	flash.name = "DamageFlashOverlay"
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(0.85, 0.08, 0.06, 1.0)
	flash.modulate.a = 0.0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Затухание вспышки должно замирать вместе с паузой, хотя HUD-слой ALWAYS.
	flash.process_mode = Node.PROCESS_MODE_PAUSABLE
	root.add_child(flash)


const LOW_HP_VIGNETTE_ON_RATIO := 0.30
const LOW_HP_VIGNETTE_OFF_RATIO := 0.34
const LOW_HP_VIGNETTE_ALPHA := 0.26
const LOW_HP_VIGNETTE_FADE_IN := 0.42
const LOW_HP_VIGNETTE_FADE_OUT := 0.50


const ThreatIndicatorOverlay := preload("res://scripts/threat_indicators.gd")


func _create_threat_indicator_overlay(root: Control) -> void:
	# SCRUM-498: edge-стрелки к внеэкранным угрозам (босс/элитки/стреляющие дальнобои).
	var overlay := ThreatIndicatorOverlay.new()
	overlay.game = game
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)


func _create_low_hp_vignette(root: Control) -> void:
	var vignette := ColorRect.new()
	vignette.name = "LowHpVignetteOverlay"
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color.WHITE
	vignette.modulate.a = 0.0
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Fade animation should pause together with combat even though the HUD layer is ALWAYS.
	vignette.process_mode = Node.PROCESS_MODE_PAUSABLE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec3 vignette_color = vec3(0.72, 0.035, 0.035);
uniform float inner_radius = 0.50;
uniform float outer_radius = 0.92;

void fragment() {
	vec2 centered_uv = UV - vec2(0.5);
	centered_uv.x *= 1.7777778;
	float distance_from_center = length(centered_uv);
	float edge_alpha = smoothstep(inner_radius, outer_radius, distance_from_center);
	COLOR = vec4(vignette_color, edge_alpha * COLOR.a);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	vignette.material = material
	vignette.set_meta("vignette_active", false)
	vignette.set_meta("vignette_target_alpha", 0.0)
	root.add_child(vignette)
	# Keep the long-lived warning behind the HUD cards; DamageFlashOverlay remains an intentional flash above them.
	root.move_child(vignette, 0)


func _update_low_hp_vignette(hp: float, max_hp: float) -> void:
	if game.hud_layer == null or not is_instance_valid(game.hud_layer):
		return
	var vignette := game.hud_layer.find_child("LowHpVignetteOverlay", true, false) as ColorRect
	if vignette == null:
		return
	var feedback_enabled := true
	if game.get_tree() != null:
		feedback_enabled = bool(game.get_tree().root.get_meta("combat_feedback", true))
	var active := bool(vignette.get_meta("vignette_active", false))
	if not feedback_enabled:
		_set_low_hp_vignette_active(vignette, false, true)
		return
	var hp_ratio := hp / maxf(max_hp, 1.0)
	var target_active := active
	if hp_ratio < LOW_HP_VIGNETTE_ON_RATIO:
		target_active = true
	elif hp_ratio >= LOW_HP_VIGNETTE_OFF_RATIO:
		target_active = false
	if target_active == active:
		return
	_set_low_hp_vignette_active(vignette, target_active)


func _set_low_hp_vignette_active(vignette: ColorRect, active: bool, immediate := false) -> void:
	var target_alpha := LOW_HP_VIGNETTE_ALPHA if active else 0.0
	var current_target := float(vignette.get_meta("vignette_target_alpha", -1.0))
	if not immediate and bool(vignette.get_meta("vignette_active", false)) == active and is_equal_approx(current_target, target_alpha):
		return
	var existing_tween: Tween = vignette.get_meta("vignette_tween") if vignette.has_meta("vignette_tween") else null
	if existing_tween != null and existing_tween.is_valid():
		existing_tween.kill()
	vignette.set_meta("vignette_active", active)
	vignette.set_meta("vignette_target_alpha", target_alpha)
	if immediate:
		vignette.modulate.a = target_alpha
		return
	var duration := LOW_HP_VIGNETTE_FADE_IN if active else LOW_HP_VIGNETTE_FADE_OUT
	var tween := vignette.create_tween()
	tween.tween_property(vignette, "modulate:a", target_alpha, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	vignette.set_meta("vignette_tween", tween)


func _on_player_damaged(amount: float) -> void:
	# SCRUM-502: аккумулируем полученный урон для экрана итогов. amount = входящий урон
	# (как эмитится player.gd:damaged), до индивидуальных мультипликаторов — приемлемо для сводки.
	game.add_run_damage_taken(amount)
	if game.hud_layer == null or not is_instance_valid(game.hud_layer):
		return
	var flash := game.hud_layer.find_child("DamageFlashOverlay", true, false) as ColorRect
	if flash == null:
		return
	var existing_tween: Tween = flash.get_meta("flash_tween") if flash.has_meta("flash_tween") else null
	if existing_tween != null and existing_tween.is_valid():
		existing_tween.kill()
	# Фиксированный пик не дает вспышке стакаться до непрозрачности при частых попаданиях.
	flash.modulate.a = 0.20
	var tween := flash.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flash.set_meta("flash_tween", tween)


func _create_menu_run_hud() -> void:
	game._clear_hud()
	game.hud_layer = CanvasLayer.new()
	game.hud_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.hud_layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.hud_layer.add_child(root)
	_create_resource_hud_panel(root, Vector2(18, 16))
	_update_hud()
	_update_level_up_button()


func _create_resource_hud_panel(parent: Control, position: Vector2) -> void:
	game._last_hud_snapshot.clear()
	var panel := PanelContainer.new()
	panel.name = "RunResourceHud"
	panel.position = position
	panel.custom_minimum_size = Vector2(690, 72)
	panel.add_theme_stylebox_override("panel", _hud_panel_style())
	parent.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)

	game.health_bar = _add_hud_resource_card(row, "hp", "HP", Color(0.92, 0.08, 0.08, 1.0))
	game.xp_bar = _add_hud_resource_card(row, "xp", "XP", Color(0.25, 0.78, 1.0, 1.0))
	_add_hud_money_card(row)
	game.ultimate_bar = _add_hud_resource_card(row, "ultimate_multiplier", "ULT", Color(0.95, 0.68, 1.0, 1.0))


func _create_character_stats_hud(parent: Control, position: Vector2) -> void:
	var panel := PanelContainer.new()
	panel.name = "CharacterStatsHud"
	panel.position = position
	panel.custom_minimum_size = Vector2(690, 58)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _character_stats_hud_style())
	parent.add_child(panel)

	var row := HBoxContainer.new()
	row.name = "CharacterStatsHudRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	for entry in _compact_character_stat_entries():
		row.add_child(_make_character_stat_chip(entry))


func _compact_character_stat_entries(limit := 4) -> Array:
	var entries: Array = []
	var character_id := str(game.selected_character_id)
	if game.current_player != null and is_instance_valid(game.current_player):
		character_id = str(game.current_player.get("character_id"))
		var sections: Dictionary = StatFormulas.stat_sections_for_player(game.current_player)
		entries = sections.get("base", [])
	else:
		var stats: Dictionary = game.PROGRESSION_DATA.base_stats(character_id)
		for stat_id in game.PROGRESSION_DATA.STAT_NAMES.keys():
			entries.append({
				"id": str(stat_id),
				"name_ru": str(game.PROGRESSION_DATA.STAT_NAMES[stat_id]),
				"value": float(stats.get(stat_id, 0.0)),
				"value_text": "%.0f" % float(stats.get(stat_id, 0.0)),
			})
	var priority_ids: Array = game.PROGRESSION_DATA.attribute_priorities(character_id)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ai: int = priority_ids.find(str(a.get("id", "")))
		var bi: int = priority_ids.find(str(b.get("id", "")))
		if ai == -1:
			ai = 999
		if bi == -1:
			bi = 999
		if ai == bi:
			return str(a.get("name_ru", "")) < str(b.get("name_ru", ""))
		return ai < bi
	)
	return entries.slice(0, mini(limit, entries.size()))


func _make_character_stat_chip(entry: Dictionary) -> Control:
	var stat_id := str(entry.get("id", ""))
	var chip := PanelContainer.new()
	chip.name = "CharacterStatChip_%s" % stat_id
	chip.custom_minimum_size = Vector2(132, 38)
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	chip.tooltip_text = "%s: %s" % [str(entry.get("name_ru", stat_id)), _compact_stat_value_text(entry)]
	chip.add_theme_stylebox_override("panel", _hud_card_style(stat_id))

	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 5)
	chip.add_child(line)

	line.add_child(game.UIIconRegistry.make_icon(stat_id, Vector2(22, 22)))

	var value := Label.new()
	value.name = "CharacterStatValue_%s" % stat_id
	value.text = _compact_stat_value_text(entry)
	value.clip_text = true
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 15)
	value.add_theme_color_override("font_color", _hud_stat_value_color(entry))
	line.add_child(value)
	return chip


func _compact_stat_value_text(entry: Dictionary) -> String:
	return str(entry.get("value_text", "N/A")).replace(" / sec", "/s").replace(" units", "")


func _hud_stat_value_color(entry: Dictionary) -> Color:
	var raw_value: Variant = entry.get("value", null)
	if raw_value == null:
		return Color(0.91, 0.86, 0.65, 1.0)
	var value := float(raw_value)
	return Color(0.44, 0.95, 0.65, 1.0) if value >= 8.0 else Color(0.91, 0.86, 0.65, 1.0)


func _add_hud_resource_card(parent: HBoxContainer, icon_id: String, label_text: String, fill_color: Color) -> ProgressBar:
	var card := PanelContainer.new()
	card.name = "Hud%sCard" % label_text
	card.custom_minimum_size = Vector2(132, 48)
	card.add_theme_stylebox_override("panel", _hud_card_style(icon_id))
	parent.add_child(card)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	card.add_child(line)
	line.add_child(game.UIIconRegistry.make_icon(icon_id, Vector2(24, 24)))

	var value_box := VBoxContainer.new()
	value_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_box.add_theme_constant_override("separation", 3)
	line.add_child(value_box)

	var value_label := Label.new()
	value_label.name = "Hud%sLabel" % label_text
	value_label.add_theme_font_size_override("font_size", 14)
	value_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.86, 1.0))
	value_box.add_child(value_label)
	if icon_id == "hp":
		game.health_label = value_label
	elif icon_id == "xp":
		game.xp_label = value_label
	elif icon_id == "ultimate_multiplier":
		game.ultimate_label = value_label

	var bar := ProgressBar.new()
	bar.name = "Hud%sBar" % label_text
	bar.custom_minimum_size = Vector2(58, 8)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _bar_style(Color(0.06, 0.07, 0.09, 0.94)))
	bar.add_theme_stylebox_override("fill", _hud_bar_fill_style(icon_id, fill_color))
	value_box.add_child(bar)
	return bar


func _add_hud_money_card(parent: HBoxContainer) -> void:
	var card := PanelContainer.new()
	card.name = "HudMoneyCard"
	card.custom_minimum_size = Vector2(104, 48)
	card.add_theme_stylebox_override("panel", _hud_card_style("money"))
	parent.add_child(card)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	card.add_child(line)
	var money_icon := TextureRect.new()
	money_icon.name = "UIIcon_money"
	money_icon.custom_minimum_size = Vector2(24, 24)
	money_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	money_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	money_icon.texture = game._cached_texture(COMBAT_HUD_GOLD_MEDALLION_PATH)
	money_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(money_icon)

	game.money_label = Label.new()
	game.money_label.name = "HudMoneyLabel"
	game.money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game.money_label.add_theme_font_size_override("font_size", 18)
	game.money_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.34, 1.0))
	line.add_child(game.money_label)


func _hud_panel_style() -> StyleBox:
	# SCRUM-564: per-слот @2K-рамка ресурс-панели (CHUD_RESOURCE_PANEL_2K=820×84) — узкие
	# верт. бордюры (hud_resource), плоский центр под HP/XP/Gold/ULT-карточки, орнамент не мылится.
	return _overhaul_2k_frame_style("chud_resource_panel", Vector2(820.0, 84.0))


func _character_stats_hud_style() -> StyleBox:
	return _global_texture_style(MINIMAL_FIELD_PATH, Vector4(10, 10, 10, 10), Color(1.0, 1.0, 1.0, 0.95), Vector4(16, 12, 16, 12), true)


func _hud_card_style(icon_id := "hp") -> StyleBox:
	var path := str(COMBAT_HUD_CARD_PATHS.get(icon_id, COMBAT_HUD_CARD_PATHS["hp"]))
	var display_size := Vector2(104.0, 48.0) if icon_id == "money" else Vector2(132.0, 48.0)
	var texture_margins := _scaled_frame_margins_xy(Vector2(616.0, 286.0), display_size, COMBAT_HUD_CARD_MARGINS)
	var content_margins := _scaled_frame_margins_xy(Vector2(616.0, 286.0), display_size, COMBAT_HUD_CARD_CONTENT)
	return _global_texture_style(path, texture_margins, Color.WHITE, content_margins, true)


func _hud_bar_fill_style(icon_id: String, fallback_color: Color) -> StyleBox:
	var path := str(COMBAT_HUD_BAR_FILL_PATHS.get(icon_id, ""))
	if path != "" and ResourceLoader.exists(path):
		return _global_texture_style(path, Vector4(4, 4, 4, 4), Color.WHITE, Vector4.ZERO)
	return _bar_style(fallback_color)


func _run_resource_values() -> Dictionary:
	var snapshot := {}
	if typeof(game.run_player_snapshot) == TYPE_DICTIONARY:
		snapshot = game.run_player_snapshot
	var hp = _number_value(snapshot.get("health", snapshot.get("max_health", 0.0)), 0.0)
	var max_hp = _number_value(snapshot.get("max_health", 0.0), 0.0)
	var xp = _int_value(snapshot.get("xp", 0), 0)
	var xp_to_next = _int_value(snapshot.get("xp_to_next", 5), 5)
	var money := _run_money()
	var ultimate_charge := 0.0
	var ultimate_max := 100.0
	if game.current_player != null and is_instance_valid(game.current_player):
		hp = _number_value(game.current_player.get("health"), hp)
		max_hp = _number_value(game.current_player.get("max_health"), max_hp)
		xp = _int_value(game.current_player.get("xp"), xp)
		xp_to_next = _int_value(game.current_player.get("xp_to_next"), xp_to_next)
		money = _int_value(game.current_player.get("money"), money)
		ultimate_charge = _number_value(game.current_player.get("ultimate_charge"), ultimate_charge)
		ultimate_max = _number_value(game.current_player.get("ultimate_max_charge"), ultimate_max)
	return {
		"hp": hp,
		"max_hp": max_hp,
		"xp": xp,
		"xp_to_next": xp_to_next,
		"money": money,
		"ultimate_charge": ultimate_charge,
		"ultimate_max": ultimate_max,
	}


func _run_money() -> int:
	if game.current_player != null and is_instance_valid(game.current_player):
		return _int_value(game.current_player.get("money"), 0)
	if typeof(game.run_player_snapshot) == TYPE_DICTIONARY:
		return _int_value(game.run_player_snapshot.get("money", 0), 0)
	return 0


func _number_value(value, fallback: float = 0.0) -> float:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)
	return fallback


func _int_value(value, fallback: int = 0) -> int:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	return fallback


func _update_hud() -> void:
	if game.health_bar == null or game.health_label == null:
		return

	var values: Dictionary = _run_resource_values()
	var max_hp: float = max(float(values["max_hp"]), 1.0)
	var hp: float = clamp(float(values["hp"]), 0.0, max_hp)
	_update_low_hp_vignette(hp, max_hp)
	var xp_to_next: int = max(int(values["xp_to_next"]), 1)
	var xp: int = clamp(int(values["xp"]), 0, xp_to_next)
	var money: int = int(values["money"])
	var ultimate_max: float = maxf(float(values.get("ultimate_max", 100.0)), 1.0)
	var ultimate_charge: float = clampf(float(values.get("ultimate_charge", 0.0)), 0.0, ultimate_max)
	var timer_seconds := -1
	if game.combat_active and not game.boss_combat_active:
		timer_seconds = maxi(int(ceil(game.round_time_left)), 0)
	var next_snapshot := {
		"hp": int(ceil(hp)),
		"max_hp": int(ceil(max_hp)),
		"xp": xp,
		"xp_to_next": xp_to_next,
		"money": money,
		"ultimate": int(floor(ultimate_charge)),
		"ultimate_max": int(floor(ultimate_max)),
		"timer": timer_seconds,
		"artifact_count": _player_artifact_count(),
	}
	if game._last_hud_snapshot == next_snapshot:
		return
	var artifacts_changed: bool = int(game._last_hud_snapshot.get("artifact_count", -1)) != int(next_snapshot["artifact_count"])
	game._last_hud_snapshot = next_snapshot
	_update_combat_timer(timer_seconds)
	if artifacts_changed:
		_refresh_artifact_hud_row()

	game.health_bar.max_value = max_hp
	game.health_bar.value = hp
	game.health_label.text = "ОЗ %d/%d" % [ceil(hp), ceil(max_hp)]

	if game.xp_bar != null and game.xp_label != null:
		game.xp_bar.max_value = xp_to_next
		game.xp_bar.value = xp
		game.xp_label.text = "Опыт %d/%d" % [xp, xp_to_next]

	if game.money_label != null:
		game.money_label.text = "%dg" % money

	if game.ultimate_bar != null and game.ultimate_label != null:
		game.ultimate_bar.max_value = ultimate_max
		game.ultimate_bar.value = ultimate_charge
		var ready := ultimate_charge >= ultimate_max
		game.ultimate_label.text = "Ульта %d%%" % int(floor(ultimate_charge / ultimate_max * 100.0))
		game.ultimate_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.36, 1.0) if ready else Color(0.98, 0.96, 0.86, 1.0))
		game.ultimate_bar.tooltip_text = "Ультимейт (%s): %s" % [_binding_text("ultimate"), "готов" if ready else "заряжается от урона"]


func _update_combat_timer(timer_seconds: int) -> void:
	if game.timer_label == null or not is_instance_valid(game.timer_label):
		return
	if timer_seconds < 0:
		return
	game.timer_label.text = "%d:%02d" % [timer_seconds / 60, timer_seconds % 60]
	var alarm := timer_seconds <= 5
	var panel := game.timer_label.get_parent() as PanelContainer
	var was_alarm := bool(game.timer_label.get_meta("alarm_active", false))
	if alarm == was_alarm:
		return
	game.timer_label.set_meta("alarm_active", alarm)
	game.timer_label.add_theme_color_override("font_color", Color(1.0, 0.32, 0.26, 1.0) if alarm else Color(0.96, 0.92, 0.74, 1.0))
	if panel != null:
		panel.add_theme_stylebox_override("panel", _timer_panel_style(alarm))
	if alarm:
		var tween: Tween = game.timer_label.create_tween()
		tween.set_loops(timer_seconds)
		tween.tween_property(game.timer_label, "scale", Vector2(1.12, 1.12), 0.16).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(game.timer_label, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_QUAD)
		game.timer_label.pivot_offset = game.timer_label.size * 0.5


func _format_artifact_list(artifacts: Array) -> String:
	if artifacts.is_empty():
		return "Artifacts\nNone"

	var visible_artifacts := []
	for index in range(min(artifacts.size(), 6)):
		var entry = artifacts[index]
		visible_artifacts.append(str(entry.get("title", "")) if entry is Dictionary else str(entry))
	if artifacts.size() > visible_artifacts.size():
		visible_artifacts.append("+%d more" % (artifacts.size() - visible_artifacts.size()))
	return "Artifacts\n%s" % "\n".join(visible_artifacts)
