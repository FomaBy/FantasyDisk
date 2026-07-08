extends RefCounted

# Меню, настройки, выбор персонажа/оружия, магазин, события, отдых,
# level-up, победа/смерть, HUD и общие UI-стили.

var game
var settings_return_origin := "main_menu"
var settings_video_pending := {}
var _settings_v6_icon_cache := {}
var _global_tooltip_theme: Theme = null
# SCRUM-816: живая строка статуса геймпада на вкладке «Управление» + флаг режима
# прослушивания ребинда (клавиатура vs геймпад — один диспетчер _handle_rebind_input).
var _gamepad_status_label: Label = null
var _rebind_is_gamepad := false
# SCRUM-827: view-state экрана «Атлас героев» (ссылки на узлы + вкладка/класс/выбор).
# Все таймеры/твины экрана — property-твины на самих нодах либо колбэки строго через
# Callable(self, "метод").bind(...) — против use-after-free семьи SCRUM-551.
var _atlas := {}
# Скрытые звезды, чью церемонию рассеивания тумана уже показали в этой сессии.
var _atlas_hidden_seen := {}

const HeroStatRadar := preload("res://scripts/ui/hero_stat_radar.gd")
const UIThemePaths := preload("res://scripts/ui/ui_theme_paths.gd")
# SCRUM-871: прогноз level-up наград (дельты derived-статов + бейджи DPS/выживаемость).
const LevelUpAdvisor := preload("res://scripts/level_up_advisor.gd")
const ShopUIConstants := preload("res://scripts/ui/shop_ui_constants.gd")
const HeroSelectConstants := preload("res://scripts/ui/hero_select_constants.gd")
const FEEDBACK_REPORTER_SCRIPT := preload("res://scripts/feedback_reporter.gd")
const DisplayResolution := preload("res://scripts/display_resolution.gd")
const StatFormulas := preload("res://scripts/stat_formulas.gd")
const GlobalTooltip := preload("res://scripts/ui/global_tooltip.gd")
const GlobalTooltipControl := preload("res://scripts/ui/global_tooltip_control.gd")
# SCRUM-810/816: реестр глифов кнопок геймпада (null-safe; нет ассета → текст).
const InputGlyphRegistry := preload("res://scripts/ui/input_glyph_registry.gd")

# SCRUM-816: человекочитаемые подписи кнопок геймпада для вкладки «Управление».
# Локальная копия имён (не зависим от автолоада InputDeviceManager в тестах).
const GAMEPAD_BUTTON_LABELS := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Select", JOY_BUTTON_GUIDE: "Home", JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "Крестовина ↑", JOY_BUTTON_DPAD_DOWN: "Крестовина ↓",
	JOY_BUTTON_DPAD_LEFT: "Крестовина ←", JOY_BUTTON_DPAD_RIGHT: "Крестовина →",
}
const GAMEPAD_REBIND_ACTIVATION := 0.5  # порог |value| оси в режиме прослушивания

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
const TEXT_BUTTON_UNIQUE_TEXTURES := UIThemePaths.TEXT_BUTTON_UNIQUE_TEXTURES
const TEXT_BUTTON_UNIQUE_MARGINS := UIThemePaths.TEXT_BUTTON_UNIQUE_MARGINS
const TEXT_BUTTON_UNIQUE_CONTENT := UIThemePaths.TEXT_BUTTON_UNIQUE_CONTENT
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
const HERO_SELECT_PREVIEW_CLOCKWISE_DIRECTIONS := ["south", "south_west", "west", "north_west", "north", "north_east", "east", "south_east"]
const STANDARD_ACTION_BUTTON_HEIGHT := 104.0
const STANDARD_ACTION_BUTTON_WIDTH := 420.0
const MAX_ACTION_BUTTON_VISUAL_WIDTH := 560.0
const MAIN_MENU_ACTION_BUTTON_WIDTH := 380.0
const MAIN_MENU_BUTTON_COUNT := 6.0
const MAIN_MENU_BUTTON_SEPARATION := 10.0
const MAIN_MENU_ACTION_COLUMN_HEIGHT := STANDARD_ACTION_BUTTON_HEIGHT * MAIN_MENU_BUTTON_COUNT + MAIN_MENU_BUTTON_SEPARATION * (MAIN_MENU_BUTTON_COUNT - 1.0)
const MAIN_MENU_LOGO_RECT := Rect2(56.0, 44.0, 720.0, 270.0)
const MAIN_MENU_LOGO_ACTION_GAP := 80.0
const MAIN_MENU_ACTION_BOTTOM_MARGIN := 10.0
const COMPACT_UTILITY_BUTTON_SIZE := Vector2(54.0, 42.0)
const ASCENSION_BUTTON_SIZE := Vector2(54.0, 62.0)
const READABILITY_FONT_SCALE_MIN := 1.32
const READABILITY_FONT_SCALE_TARGET := 1.45
const BUTTON_NEUTRAL_HOVER_TINT := Color(1.16, 1.16, 1.16, 1.0)
# Фидбек 2026-07-08: hover заметнее (но «не сильно») — мягкий множитель ПОВЕРХ
# запечённого hover-арта пластин кита (unique + minimal_metal).
const BUTTON_HOVER_EXTRA_TINT := Color(1.12, 1.12, 1.12, 1.0)
const BUTTON_NEUTRAL_FOCUS_TINT := Color(1.20, 1.20, 1.20, 1.0)
const BUTTON_NEUTRAL_HOVER_FONT := Color(1.0, 1.0, 1.0, 1.0)
const SETTINGS_RETURN_MAIN_MENU := "main_menu"
const SETTINGS_RETURN_RUN_PAUSE := "run_pause"
# --- Settings v6 (SCRUM-847) + фулскрин атлас-шелл (SCRUM-879, итерация 2) ----
# Шелл экрана — единый атлас-паттерн (_show_atlas_screen): фон/safe-зона/полая
# рама, кнопки — глобальный кит. От v6 остался кит СТРОК (поля, бинды,
# чекбоксы, слайдеры, медальон, иконки табов): их геометрия — design-px листа
# 1420×1060, масштаб s = ширина контент-зоны / 1420 (кламп 0.55..1.05).
# Арт-кит строк — OpenAI gpt-image-2 + PixelLab, состояния hover/pressed/
# disabled — PIL-деривативы (tools/generate_settings_v6_openai.py).
const SETTINGS_V6_DIR := "res://assets/sprites/ui/frames/settings_v6/"
const SETTINGS_V6_DESIGN_SIZE := Vector2(1420.0, 1060.0)
const SETTINGS_V6_MEDALLION_PATH := SETTINGS_V6_DIR + "ui_settings_v6_medallion.png"
const SETTINGS_V6_TAB_ICON_PATHS := [
	SETTINGS_V6_DIR + "ui_settings_v6_icon_screen.png",
	SETTINGS_V6_DIR + "ui_settings_v6_icon_sound.png",
	SETTINGS_V6_DIR + "ui_settings_v6_icon_controls.png",
]
# SCRUM-879: пластины табов и кнопок-действий v6 (ui_settings_v6_tab_*/btn_*)
# выведены — табы и действия носят глобальный кит (_make_button, как Атлас).
const SETTINGS_V6_FIELD_PATHS := {
	"normal": SETTINGS_V6_DIR + "ui_settings_v6_field_normal.png",
	"hover": SETTINGS_V6_DIR + "ui_settings_v6_field_hover.png",
	"pressed": SETTINGS_V6_DIR + "ui_settings_v6_field_pressed.png",
}
const SETTINGS_V6_ARROW_PATH := SETTINGS_V6_DIR + "ui_settings_v6_arrow_socket.png"
const SETTINGS_V6_CHECKBOX_ON_PATH := SETTINGS_V6_DIR + "ui_settings_v6_checkbox_on.png"
const SETTINGS_V6_CHECKBOX_OFF_PATH := SETTINGS_V6_DIR + "ui_settings_v6_checkbox_off.png"
const SETTINGS_V6_SLIDER_TRACK_PATH := SETTINGS_V6_DIR + "ui_settings_v6_slider_track.png"
const SETTINGS_V6_SLIDER_FILL_PATH := SETTINGS_V6_DIR + "ui_settings_v6_slider_fill.png"
const SETTINGS_V6_SLIDER_GEM_PATH := SETTINGS_V6_DIR + "ui_settings_v6_slider_gem.png"
const SETTINGS_V6_VALUE_CHIP_PATH := SETTINGS_V6_DIR + "ui_settings_v6_value_chip.png"
# Геометрия (design-px @1420×1060): title/табы/панель/низ.
const SETTINGS_V6_LABEL_COL := Vector2(380.0, 56.0)
const SETTINGS_V6_CONTROL_SIZE := Vector2(560.0, 56.0)
# Палитра v6 — выведена из экрана Атласа (meta40): текст-пергамент, атласное
# золото титулов #F5E6AE, тёплое золото заголовков #C7A870, ценник-золото
# #F0CC75, голубой хинт #B8D6FF, латунь #856A3D, чип-фон #150F0D.
const SETTINGS_V6_TEXT := Color(0.93, 0.88, 0.72, 1.0)
const SETTINGS_V6_TEXT_BRIGHT := Color(0.96, 0.90, 0.68, 1.0)
const SETTINGS_V6_GOLD := Color(0.78, 0.66, 0.44, 1.0)
const SETTINGS_V6_AMBER := Color(0.94, 0.80, 0.46, 1.0)
const SETTINGS_V6_HINT_BLUE := Color(0.72, 0.84, 1.0, 0.95)
const SETTINGS_V6_MUTED := Color(0.72, 0.68, 0.58, 1.0)
const SETTINGS_V6_DISABLED := Color(0.48, 0.45, 0.40, 1.0)
const SETTINGS_V6_BRONZE_LINE := Color(0.52, 0.41, 0.24, 0.55)
const SETTINGS_V6_POPUP_BG := Color(0.085, 0.070, 0.055, 0.98)
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
const COMBAT_HUD_LEVEL_UP_MARGINS := Vector4(8.0, 8.0, 8.0, 8.0)
const COMBAT_HUD_LEVEL_UP_CONTENT := Vector4(6.0, 6.0, 6.0, 6.0)

# === SCRUM-487: координатная спека @2560×1440 — блок Боевые ===
# Источник правды для рисующего скрипта (рисует рамки/панели ровно в эти размеры) и
# документ-спека раскладки. Значения вычислены из фактической раскладки билдеров при
# базе 2560×1440 (window/stretch=canvas_items, aspect=keep → рантайм всегда лэйаутит в
# этой базе, окно скейлится автоматически). Стиль и инварианты — как у блока Меню (MM_*/
# QC_*/PM_* в SCRUM-484): панели с рамкой держат пустую safe-area под контент.
# Шаблонные размеры контейнер-зависимых слотов (карточки/кнопки/ряды) заданы как
# Rect2(0, 0, w, h) — позиция считается контейнером в рантайме (центрирование).
const COMBAT_BLOCK_DESIGN_BASE_2K := Vector2(2560.0, 1440.0)

# #5 Бой / HUD — generated 2K frame-kit slots. Keep these in sync with
# tools/build_ui_2k_frame_kit.py; SCRUM-671 runtime placement uses the SCRUM666_*
# geometry below because SCRUM-666 is a full-screen mockup/source package.
const CHUD_RESOURCE_PANEL_2K := Rect2(18, 18, 820, 84)
const CHUD_TIMER_2K := Rect2(1136, 14, 288, 96)
const CHUD_ASCENSION_BADGE_2K := Rect2(1432, 18, 64, 64)
const CHUD_ARTIFACT_ROW_2K := Rect2(2140, 16, 402, 104)
const CHUD_LEVELUP_BUTTON_2K := Rect2(2436, 1316, 96, 117)
const CHUD_LEVELUP_BADGE_2K := Rect2(2498, 1306, 28, 28)
const CHUD_DAMAGE_FLASH_2K := Rect2(0, 0, 2560, 1440)       # DamageFlashOverlay (full-rect)

# SCRUM-671 / SCRUM-666 clean essential-only runtime HUD geometry.
# SCRUM-778 keeps the same accepted HUD content, but compacts the runtime footprint
# so the 1080p top band and pending-level control no longer dominate the arena.
# SCRUM-806: карточные зоны (RESOURCE_PANEL/HP/XP/GOLD/ULT/TIMER/ASCENSION) заменены
# HUD_V2_* геометрией ниже; здесь остались только слоты level-up контрола.
const SCRUM666_CHUD_LEVELUP_FRAME_2K := Rect2(2300, 1160, 220, 250)
const SCRUM666_CHUD_LEVELUP_BUTTON_2K := Rect2(2370, 1248, 88, 104)
const SCRUM666_CHUD_LEVELUP_BADGE_2K := Rect2(2458, 1212, 58, 48)

# SCRUM-806: боевой HUD v2 — компактный кластер слим-баров без карточных рамок.
# Иконки — пиксель-арт PixelLab, подложка/трек — OpenAI-арт в стиле leather/gold кита.
# Геометрия @2K, масштабируется той же SCRUM-666 системой (_scrum666_hud_scale).
const COMBAT_HUD_V2_DIR := "res://assets/sprites/ui/hud/combat_hud_v2/"
const HUD_V2_CLUSTER_BG_PATH := COMBAT_HUD_V2_DIR + "ui_hud_v2_cluster_bg.png"
const HUD_V2_BAR_TRACK_PATH := COMBAT_HUD_V2_DIR + "ui_hud_v2_bar_track.png"
const HUD_V2_ICON_PATHS := {
	"hp": COMBAT_HUD_V2_DIR + "ui_hud_v2_icon_hp.png",
	"xp": COMBAT_HUD_V2_DIR + "ui_hud_v2_icon_xp.png",
	"ultimate_multiplier": COMBAT_HUD_V2_DIR + "ui_hud_v2_icon_ult.png",
	"money": COMBAT_HUD_V2_DIR + "ui_hud_v2_icon_money.png",
	"timer": COMBAT_HUD_V2_DIR + "ui_hud_v2_icon_timer.png",
	"ascension": COMBAT_HUD_V2_DIR + "ui_hud_v2_icon_ascension.png",
}
const HUD_V2_CLUSTER_2K := Rect2(36, 36, 640, 122)
const HUD_V2_HP_ICON_2K := Rect2(46, 43, 42, 42)
const HUD_V2_HP_BAR_2K := Rect2(96, 48, 516, 32)
const HUD_V2_XP_ICON_2K := Rect2(50, 87, 36, 36)
const HUD_V2_XP_BAR_2K := Rect2(96, 92, 420, 26)
const HUD_V2_ULT_ICON_2K := Rect2(50, 121, 36, 36)
const HUD_V2_ULT_BAR_2K := Rect2(96, 126, 420, 26)
const HUD_V2_MONEY_ICON_2K := Rect2(534, 90, 30, 30)
const HUD_V2_MONEY_LABEL_2K := Rect2(570, 88, 100, 34)
const HUD_V2_TIMER_2K := Rect2(1148, 40, 264, 92)
const HUD_V2_TIMER_ZONE_2K := Rect2(1190, 58, 180, 56)
const HUD_V2_TIMER_ICON_2K := Rect2(1194, 70, 32, 32)
# SCRUM-874: HUD-боссбар цели узла (акт-босс/элитка) — центр верха, ниже
# кластера ресурсов (36..158) и таймера (40..132), чтобы не пересекаться с ними.
const HUD_V2_BOSS_NAME_2K := Rect2(880, 168, 800, 40)
const HUD_V2_BOSS_BAR_2K := Rect2(880, 212, 800, 46)
# Ряд эмблем возвышения: правый край/верх/размер пипа/зазор @2K (ширина = от уровня).
const HUD_V2_ASCENSION_RIGHT_2K := 2524.0
const HUD_V2_ASCENSION_TOP_2K := 52.0
const HUD_V2_ASCENSION_PIP_2K := 44.0
const HUD_V2_ASCENSION_GAP_2K := 8.0

# #6 Событие — _show_event_screen (economy-панель "event"; safe = панель − content 58/72/58/66)
const EVT_PANEL_2K := Rect2(420, 330, 1720, 780)
const EVT_SAFE_2K := Rect2(478, 402, 1604, 642)
const EVT_CARD_2K := Rect2(0, 0, 480, 340)                  # EventChoiceButton{0..2} (3 в ряд, gap 48)
const EVT_BACK_BUTTON_2K := Rect2(0, 0, 380, 54)            # EventBackButton

# #14 Улучшение — _show_upgrade_screen (economy-панель "upgrade"; target 1720×730, центр)
const UPGRADE_PANEL_2K := Rect2(420, 355, 1720, 730)        # MenuPanel_upgrade (centered economy panel)
const UPGRADE_SAFE_2K := Rect2(478, 427, 1604, 592)         # safe = панель − content 58/72/58/66

# #11 Повышение уровня — _show_level_up_screen / _level_up_layout_metrics
# SCRUM-883: оверлей на едином атлас-стиле (эталон SCRUM-879) — панель/карточки/
# поля = чипы StyleBoxFlat (_atlas_chip_style/_atlas_translucent_style), «Позже» —
# глобальный кит (имя LevelUpLaterButton мапится на later_260x72). Дизайн-база
# 2K 1720×1040; контент-зона панели = фактические margins чипа (pad 20 → 28/20 @2K,
# зона 1664×1000), внутренние ректы заданы в этой зоне и скейлятся ×scale.
const LU_PANEL_2K := Rect2(420, 205, 1720, 1040)
const LU_PANEL_CHIP_PAD_2K := 20.0
const LU_CARD_2K := Rect2(0, 0, 470, 560)                   # LevelUpRewardButton{0..2} (3 в ряд)
const LU_CARD_GAP_2K := 24.0
const LU_CARD_CHIP_PAD_2K := 12.0
const LU_HERO_HEADER_RECT := Rect2(40.0, 8.0, 1584.0, 160.0)
const LU_HERO_FRAME_RECT := Rect2(60.0, 16.0, 146.0, 146.0)
const LU_TITLE_RECT := Rect2(260.0, 20.0, 1144.0, 64.0)
const LU_SUBTITLE_RECT := Rect2(260.0, 94.0, 1144.0, 48.0)
const LU_REWARDS_ROW_TOP_2K := 180.0
const LU_LATER_BUTTON_WIDTH := 260.0
# Раскладка карточки: контент-зона чипа (card 470×560 − pad 12 → 436.4×536);
# бейдж-плашка сверху, иконка, титул, описание, крупный блок «до -> после».
const LU_CARD_CONTENT_SOURCE := Vector2(436.4, 536.0)
const LU_CARD_BADGE_RECT := Rect2(58.0, 2.0, 320.0, 50.0)
const LU_CARD_ICON_RECT := Rect2(159.0, 60.0, 118.0, 118.0)
const LU_CARD_TITLE_RECT := Rect2(8.0, 196.0, 420.0, 48.0)
const LU_CARD_DESCRIPTION_RECT := Rect2(12.0, 250.0, 412.0, 84.0)
const LU_CARD_EFFECT_RECT := Rect2(16.0, 346.0, 404.0, 174.0)
# Бейджи советника: плашка _atlas_translucent_style(0.7, 6) + подпись цветом
# типа (PNG-риббоны lu682 сняты; тёмная плашка → светлые акцентные цвета).
const LU_BADGE_META := {
	"dps": {"text": "ЛУЧШИЙ УРОН", "text_color": Color(1.0, 0.76, 0.34, 1.0)},
	"surv": {"text": "ВЫЖИВАНИЕ", "text_color": Color(0.64, 0.94, 0.66, 1.0)},
	"both": {"text": "ЛУЧШИЙ ВЫБОР", "text_color": Color(0.98, 0.87, 0.42, 1.0)},
}

# #12/#13 Награды (обычная и элитки) — SCRUM-883: панели и карточки — чипы Атласа,
# геометрия задаётся _create_menu_box/REWARD_*_CARD_SIZE (спек-рамки @2K сняты).

# #28 Тост повышения — _show_level_up_toast (транзиентный full-rect burst на позиции игрока/центра)
const LUT_OVERLAY_2K := Rect2(0, 0, 2560, 1440)

# #29 Баннер заголовка боя — _show_combat_title_banner (center-top; ширина была 1280 = 720p-баг → 2K)
const CTB_BIG_2K := Rect2(100, 120, 2360, 90)              # появление босса (big)
const CTB_SMALL_2K := Rect2(100, 92, 2360, 56)             # появление элитки

# #30 Баннер победы — _show_victory_banner: дим + компактный чип Атласа с золотым
# титулом «ПОБЕДА» по вертикальному центру 2K-холста (SCRUM-883, ранее vbn_frame @2K).
const VICTORY_BANNER_CHIP_SIZE := Vector2(960.0, 224.0)
const VICTORY_BANNER_CHIP_TOP := 608.0
const VICTORY_BANNER_CHIP_PAD := 26.0
# === конец спеки SCRUM-487 ===

# === SCRUM-488: координатная спека @2560×1440 — блок Прогрессия/Экономика ===
# Те же правила и стиль, что у блока Меню (SCRUM-484) и Боевые (SCRUM-487): значения
# вычислены из фактической раскладки билдеров при базе 2560×1440 и сверены с рантайм-дампом
# верификатора (build/qa/ui_no_overlap_matrix.md, секции *_2560×1440). Контейнер-зависимые
# слоты-шаблоны заданы как Rect2(0, 0, w, h). Кодекс с SCRUM-879 — контейнерный
# атлас-шелл (см. #15 ниже), собственного координатного движка больше не имеет.

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

# #10 Дерево навыков (легаси-спека v3; экран заменён Атласом героев — _show_atlas_screen, SCRUM-827)
const SKILL_MAIN_PANEL_2K := Rect2(48, 26, 2464, 1388)
const SKILL_SAFE_2K := Rect2(136, 118, 2288, 1214)         # layout-VBox (header→hint→body)
const SKILL_POINTS_BADGE_2K := Rect2(0, 0, 215, 96)        # SkillTreePointsBadge (ширина растёт под текст очков)
const SKILL_BACK_2K := Rect2(0, 0, 260, 104)               # SkillTreeBackButton
const SKILL_CLASS_PANEL_2K := Rect2(136, 262, 330, 1070)   # SkillTreeClassPanel (левая колонка)
const SKILL_BRANCHES_2K := Rect2(484, 262, 1932, 1276)     # SkillTreeBranches (ряд веток; @2K без гориз-скролла)
const SKILL_BRANCH_2K := Rect2(0, 0, 164, 430)             # SkillTreeBranchPanel_* (шаблон ветки, separation 14)

# #15 Кодекс — _show_codex_screen / _show_codex_section: SCRUM-879, контейнерный
# шелл в атлас-стиле (фон COVERED → safe-зона рамы → «табы | объект-сцена | досье»
# → полая рама поверх); панели — _atlas_chip_style, ряды — _unified_apply_row_theme.

# #16 Настройки — _show_settings_menu (SCRUM-879: фулскрин атлас-шелл, строки v6)
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
const ECONOMY_DRAGON_PANEL_PATH := ECONOMY_FRAME_DIR + "ui_frame_economy_dragon_panel.png"
const ECONOMY_PRICE_BADGE_PATH := MINIMAL_FIELD_PATH
const ECONOMY_TOOLTIP_PATH := MINIMAL_TOOLTIP_PATH
const ECONOMY_PANEL_SOURCE_SIZE := Vector2(782.0, 716.0)
const ECONOMY_PANEL_TEXTURE_MARGINS := Vector4(38.0, 52.0, 38.0, 48.0)
const ECONOMY_PANEL_CONTENT := Vector4(58.0, 72.0, 58.0, 66.0)
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
# SCRUM-827: экран «Атлас героев» (Мета 4.0, дизайн meta_constellations.md §7).
# Ассет-кит SCRUM-826/832 нарисован ПОД целевые размеры слотов окна 2560×1440
# (bg_sky фулскрин, frame_border под 9-slice, сокеты/звёзды/гербы под свои px).
const META40_UI_DIR := "res://assets/sprites/ui/meta40/"
const META40_BG_SKY_PATH := META40_UI_DIR + "bg_sky.png"
const META40_FRAME_BORDER_PATH := META40_UI_DIR + "frame_border.png"
const META40_STAR_ALLOC_PATH := META40_UI_DIR + "star_alloc.png"
const META40_KEYSTONE_RING_PATH := META40_UI_DIR + "keystone_ring.png"
const META40_CURRENCY_EMBLEM_PATH := META40_UI_DIR + "currency_emblem.png"
const META40_CURRENCY_STARDUST_PATH := META40_UI_DIR + "currency_stardust.png"
const META40_SOCKET_TEXTURES := {
	"minor": META40_UI_DIR + "socket_minor.png",
	"technique": META40_UI_DIR + "socket_notable.png",
	"notable": META40_UI_DIR + "socket_notable.png",
	"keystone": META40_UI_DIR + "socket_keystone.png",
	"hidden": META40_UI_DIR + "socket_hidden.png",
	"core": META40_UI_DIR + "socket_notable.png",
}
# Целевые размеры сокетов @2560×1440 (§7: minor 96, notable 128, keystone 168,
# hidden 112, герб-ядро 160); на других вьюпортах — пропорциональный масштаб.
const ATLAS_SOCKET_SIZES := {
	"minor": 96.0, "technique": 128.0, "notable": 128.0,
	"keystone": 168.0, "hidden": 112.0, "core": 160.0,
}
const ATLAS_NODE_LAYOUT_PAD := Vector2(54.0, 42.0)
const ATLAS_NODE_COLLISION_GAP := 10.0
const ATLAS_NODE_RELAX_ITERATIONS := 180
const ATLAS_FRAME_SOURCE_SIZE := Vector2(1536.0, 1024.0)
# Орнаментная полоса frame_border ≈127px source; 160 покрывает угловые вырезы.
const ATLAS_FRAME_SOURCE_MARGIN := 160.0
const ATLAS_FOG_DISSOLVE_SEC := 0.6
const ATLAS_ROLE_LABELS := {
	"core": "ЯДРО СОЗВЕЗДИЯ", "minor": "ЗВЕЗДА-АТРИБУТ", "technique": "ЗВЕЗДА-ТЕХНИКА",
	"notable": "ПРИМЕЧАТЕЛЬНАЯ ЗВЕЗДА", "keystone": "КЛЮЧЕВАЯ ЗВЕЗДА", "hidden": "СКРЫТАЯ ЗВЕЗДА",
}
# Родительный падеж названий классов для шапки «Эмблемы …: N» (мокап).
const ATLAS_CLASS_GENITIVE := {
	"berserk": "Берсерка", "soldier": "Солдата", "thief": "Вора",
	"elementalist": "Элементалиста", "sniper": "Снайпера", "priest": "Священника",
	"biologist": "Биолога", "robot": "Робота", "engineer": "Инженера",
	"dark_mage": "Темного мага", "guitarist": "Гитариста", "assassin": "Ассасина",
	"ranger": "Рейнджера", "doctor": "Доктора", "chemist": "Химика",
	"knight": "Рыцаря", "druid": "Друида",
}
# SCRUM-879: единый атлас-стиль остальных экранов (выбор героя / кодекс /
# релиз-ноты / настройки). Фоны 2560×1440 — OpenAI-пайплайн SCRUM-832, акценты —
# PixelLab. Слои повторяют экран «Атлас героев»: тихий фон COVERED, контент в
# safe-зоне, полая рама frame_border поверх, панели — _atlas_chip_style, кнопки —
# глобальный кит (_make_button/_set_action_button_size).
const ATLAS_STYLE_DIR := "res://assets/sprites/ui/atlas_style/"
const ATLAS_STYLE_BG_PATHS := {
	"hero_select": ATLAS_STYLE_DIR + "bg_hero_hall.png",
	"codex": ATLAS_STYLE_DIR + "bg_codex_archive.png",
	"patch_notes": ATLAS_STYLE_DIR + "bg_chronicle.png",
	"settings": ATLAS_STYLE_DIR + "bg_sanctum.png",
}
const ATLAS_STYLE_EMBLEM_PATHS := {
	"hero_select": ATLAS_STYLE_DIR + "emblem_hero_hall.png",
	"codex": ATLAS_STYLE_DIR + "emblem_codex.png",
	"patch_notes": ATLAS_STYLE_DIR + "emblem_chronicle.png",
}
const ATLAS_STYLE_PEDESTAL_PATH := ATLAS_STYLE_DIR + "pedestal_dais.png"
const ATLAS_STYLE_DIVIDER_PATH := ATLAS_STYLE_DIR + "divider_ornament.png"
# SCRUM-879: от кита codex_pl в кодексе живут только пиксельные эмблемы разделов
# (иконки табов); панели/карточки/кнопки — единый атлас-стиль (_atlas_chip_style,
# _unified_apply_row_theme, глобальный кнопочный кит).
const CODEX_PL_FRAME_DIR := "res://assets/sprites/ui/frames/codex_pl/"
const CODEX_PL_CARD_BODY_COLOR := Color(0.76, 0.70, 0.57, 1.0)
const CODEX_PL_ICONS := {
	"characters": CODEX_PL_FRAME_DIR + "codex_pl_icon_characters.png",
	"monsters": CODEX_PL_FRAME_DIR + "codex_pl_icon_monsters.png",
	"artifacts": CODEX_PL_FRAME_DIR + "codex_pl_icon_artifacts.png",
	"stats": CODEX_PL_FRAME_DIR + "codex_pl_icon_stats.png",
	"glossary": CODEX_PL_FRAME_DIR + "codex_pl_icon_glossary.png",
	"ascensions": CODEX_PL_FRAME_DIR + "codex_pl_icon_ascensions.png",
}
# SCRUM-883: карточки наград — чип-ряды Атласа; display-размеры слотов сохранены.
const REWARD_CARD_SIZE := Vector2(300.0, 430.0)
const REWARD_ELITE_CARD_SIZE := Vector2(320.0, 430.0)


func _init(game_ref) -> void:
	game = game_ref


# SCRUM-484: координатная спека @2560×1440 — блок Меню/Навигация (главное меню).
# Документирующие const рядом с билдером: x,y,w,h каждого слота контента @2K, плюс
# safe-area (пустая зона внутри рамки, куда можно класть контент). База дизайна 2K
# (project.godot viewport 2560×1440, stretch=canvas_items/keep). Эти прямоугольники —
# вход для рисующего скрипта: он рисует ассеты ровно в эти размеры.
const MENU_NAV_DESIGN_BASE_2K := Vector2(2560.0, 1440.0)
const MM_TITLE_2K := Rect2(56, 44, 720, 270)
# Колонка кнопок слева (MarginContainer offset_left=72..452, VBox по центру вертикали,
# 6 кнопок 380×104, separation 10 → высота 674; top рассчитывается ниже лого).
const MM_BUTTON_COLUMN_2K := Rect2(72, 394, 380, 674)
const MM_BTN_START_2K := Rect2(72, 394, 380, 104)
const MM_BTN_SETTINGS_2K := Rect2(72, 508, 380, 104)
const MM_BTN_SKILLTREE_2K := Rect2(72, 622, 380, 104)
const MM_BTN_PATCHNOTES_2K := Rect2(72, 736, 380, 104)
const MM_BTN_CODEX_2K := Rect2(72, 850, 380, 104)
const MM_BTN_EXIT_2K := Rect2(72, 964, 380, 104)
const MM_VERSION_LABEL_2K := Rect2(2440, 1406, 104, 24)  # якорь bottom-right
const MM_SAFE_2K := Rect2(72, 394, 380, 674)  # фон обязан держать эту колонку пустой


func _main_menu_actions_top(viewport_size: Vector2, title_bottom: float) -> float:
	var preferred_top := roundf((viewport_size.y - MAIN_MENU_ACTION_COLUMN_HEIGHT) * 0.5)
	var min_top := roundf(title_bottom + MAIN_MENU_LOGO_ACTION_GAP)
	var max_top := roundf(viewport_size.y - MAIN_MENU_ACTION_COLUMN_HEIGHT - MAIN_MENU_ACTION_BOTTOM_MARGIN)
	if max_top >= min_top:
		return clampf(maxf(preferred_top, min_top), min_top, max_top)
	return maxf(0.0, max_top)


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
	title_logo.anchor_left = 0.0
	title_logo.anchor_top = 0.0
	title_logo.anchor_right = 0.0
	title_logo.anchor_bottom = 0.0
	title_logo.offset_left = MAIN_MENU_LOGO_RECT.position.x
	title_logo.offset_top = MAIN_MENU_LOGO_RECT.position.y
	title_logo.offset_right = MAIN_MENU_LOGO_RECT.position.x + MAIN_MENU_LOGO_RECT.size.x
	title_logo.offset_bottom = MAIN_MENU_LOGO_RECT.position.y + MAIN_MENU_LOGO_RECT.size.y
	title_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_logo.texture = game._cached_texture("res://assets/sprites/ui/menu_title/main_menu_title_fantasy_disk.png")
	title_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_logo)

	var viewport_size: Vector2 = game.get_viewport().get_visible_rect().size
	var action_top := _main_menu_actions_top(viewport_size, MAIN_MENU_LOGO_RECT.position.y + MAIN_MENU_LOGO_RECT.size.y)
	var layout := MarginContainer.new()
	layout.anchor_left = 0.0
	layout.anchor_top = 0.0
	layout.anchor_right = 0.0
	layout.anchor_bottom = 0.0
	layout.offset_left = 72.0
	layout.offset_top = action_top
	layout.offset_right = 452.0
	layout.offset_bottom = action_top + MAIN_MENU_ACTION_COLUMN_HEIGHT
	layout.add_theme_constant_override("margin_left", 0)
	layout.add_theme_constant_override("margin_top", 0)
	layout.add_theme_constant_override("margin_right", 0)
	layout.add_theme_constant_override("margin_bottom", 0)
	root.add_child(layout)

	var action_box := VBoxContainer.new()
	action_box.name = "MainMenuActions"
	action_box.custom_minimum_size = Vector2(380, MAIN_MENU_ACTION_COLUMN_HEIGHT)
	action_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	action_box.add_theme_constant_override("separation", int(MAIN_MENU_BUTTON_SEPARATION))
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
	version_label.add_theme_font_size_override("font_size", _readable_font_size(13))
	version_label.add_theme_color_override("font_color", Color(0.62, 0.66, 0.72, 0.85))
	version_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(version_label)

	var skill_tree_button := _make_button("Атлас героев")
	skill_tree_button.name = "MainMenuSkillTreeButton"
	_set_action_button_size(skill_tree_button, MAIN_MENU_ACTION_BUTTON_WIDTH)
	skill_tree_button.pressed.connect(_show_atlas_screen)
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

	# SCRUM-813: главное меню проходимо с геймпада/стрелок — вертикальный круг кнопок,
	# стартовый фокус «Начать новую игру»; B/Esc = подтверждение выхода (ui_escape_action).
	_wire_run_ui_focus([
		start_button, settings_button, skill_tree_button, patch_notes_button, codex_button, exit_button,
	], false, [], start_button)


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
	title_label.add_theme_font_size_override("font_size", _readable_font_size(34))
	title_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	box.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.name = "QuitConfirmationSubtitle"
	subtitle_label.text = "Несохраненный забег будет завершен. Продолжить выход?"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size", _readable_font_size(16))
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


# SCRUM-484/SCRUM-842: координатная спека @2560×1440 — продолжить забег (модалка).
# Панель расширена до 840×380, чтобы long-кнопка «Продолжить» 420×72 и «Новая игра»
# 240×72 с gap 18 оставались внутри safe-area и не клепали текст по орнаменту.
const CR_DIM_2K := Rect2(0, 0, 2560, 1440)
const CR_PANEL_2K := Rect2(860, 530, 840, 380)
const CR_SAFE_2K := Rect2(932, 602, 696, 242)
const CR_TITLE_2K := Rect2(932, 614, 696, 44)
const CR_SUBTITLE_2K := Rect2(932, 674, 696, 66)
const CR_BTN_CONTINUE_2K := Rect2(942, 758, 420, 72)
const CR_BTN_NEWGAME_2K := Rect2(1380, 758, 240, 72)

# SCRUM-584: координатная спека @2560x1440 — конфликт переназначения клавиши.
# Mockup/art source: docs/design/references/scrum584_rebind_conflict_2k/.
const RC_DIM_2K := Rect2(0, 0, 2560, 1440)
const RC_PANEL_2K := Rect2(940, 530, 680, 380)
const RC_SAFE_2K := Rect2(998, 602, 564, 242)
const RC_TITLE_2K := Rect2(998, 614, 564, 44)
const RC_MESSAGE_2K := Rect2(998, 674, 564, 66)
const RC_BTN_RETRY_2K := Rect2(1031, 758, 240, 72)
const RC_BTN_BACK_2K := Rect2(1289, 758, 240, 72)


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

	# SCRUM-677: стилизованный лого-заголовок вместо плоского жёлтого текста.
	var title_label := TextureRect.new()
	title_label.name = "ContinueRunTitle"
	title_label.custom_minimum_size = Vector2(0.0, 72.0)
	title_label.size_flags_horizontal = Control.SIZE_FILL
	title_label.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_label.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.texture = game._cached_texture("res://assets/sprites/ui/menu_title/continue_run_title.png")
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
	subtitle_label.add_theme_font_size_override("font_size", _readable_font_size(16))
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
const HS4_MINIMAL_PREVIEW_SIZE := 560.0
const HS4_MINIMAL_SLOT_SIZE := 280.0
const HS4_MINIMAL_BASE_STATS := HeroSelectConstants.HERO_BASE_STATS
const HS4_MINIMAL_PREVIEW_MIN_SIZE := 320.0
const HS4_MINIMAL_PREVIEW_MAX_SIZE := 660.0
const HS4_MINIMAL_SLOT_MIN_SIZE := 180.0
const HS4_MINIMAL_SLOT_MAX_SIZE := 320.0

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
const HS4_PIXELLAB_DIR := "res://assets/sprites/ui/frames/hero_select_pixellab/"
const HS4_PIXELLAB_PATHS := {
	"background": HS4_PIXELLAB_DIR + "background.png",
	"back": HS4_PIXELLAB_DIR + "button_back.png",
	"title": HS4_PIXELLAB_DIR + "frame_title.png",
	"portrait": HS4_PIXELLAB_DIR + "frame_portrait.png",
	"dossier": HS4_PIXELLAB_DIR + "frame_dossier.png",
	"radar": HS4_PIXELLAB_DIR + "frame_radar.png",
	"ascension": HS4_PIXELLAB_DIR + "frame_ascension.png",
	"asc_minus": HS4_PIXELLAB_DIR + "button_asc_minus.png",
	"asc_plus": HS4_PIXELLAB_DIR + "button_asc_plus.png",
	"choose": HS4_PIXELLAB_DIR + "button_choose.png",
	"carousel": HS4_PIXELLAB_DIR + "frame_carousel.png",
	"carousel_left": HS4_PIXELLAB_DIR + "button_carousel_left.png",
	"carousel_right": HS4_PIXELLAB_DIR + "button_carousel_right.png",
	"hero_slot": HS4_PIXELLAB_DIR + "frame_hero_slot.png",
}
const HS4_PIXELLAB_SOURCE_SIZE := {
	"back": Vector2(460, 148),
	"title": Vector2(1840, 184),
	"portrait": Vector2(600, 820),
	"dossier": Vector2(980, 820),
	"radar": Vector2(780, 520),
	"ascension": Vector2(780, 270),
	"asc_minus": Vector2(132, 92),
	"asc_plus": Vector2(132, 92),
	"choose": Vector2(512, 118),
	"carousel": Vector2(2432, 330),
	"carousel_left": Vector2(132, 176),
	"carousel_right": Vector2(132, 176),
	"hero_slot": Vector2(196, 220),
}
const HS4_PIXELLAB_CONTENT_RECT := {
	"back": Rect2(70, 38, 320, 72),
	"title": Rect2(120, 42, 1600, 96),
	"portrait": Rect2(72, 94, 456, 620),
	"dossier": Rect2(92, 84, 796, 640),
	"radar": Rect2(98, 57, 584, 406),
	"ascension": Rect2(74, 50, 632, 183),
	"asc_minus": Rect2(32, 22, 68, 48),
	"asc_plus": Rect2(32, 22, 68, 48),
	"choose": Rect2(70, 34, 372, 50),
	"carousel": Rect2(110, 61, 2212, 220),
	"carousel_left": Rect2(36, 42, 60, 92),
	"carousel_right": Rect2(36, 42, 60, 92),
	"hero_slot": Rect2(18, 18, 160, 160),
}
const HS4_PIXELLAB_LAYOUT_2K := {
	"back": Rect2(100, 86, 460, 148),
	"title": Rect2(240, 6, 1840, 184),
	"portrait": Rect2(64, 178, 600, 820),
	"dossier": Rect2(720, 178, 980, 820),
	"radar": Rect2(1716, 178, 780, 520),
	"ascension": Rect2(1714, 728, 780, 270),
	"choose": Rect2(1012, 998, 512, 118),
	"carousel": Rect2(64, 1080, 2432, 330),
}


func _hs4_scaled_rect(zone: Rect2, canvas_size: Vector2) -> Rect2:
	return Rect2(
		Vector2(round(zone.position.x * canvas_size.x), round(zone.position.y * canvas_size.y)),
		Vector2(round(zone.size.x * canvas_size.x), round(zone.size.y * canvas_size.y))
	)


func _hs4_pixellab_scale(viewport_size: Vector2) -> float:
	return minf(viewport_size.x / HS4_DESIGN_BASE_2K.x, viewport_size.y / HS4_DESIGN_BASE_2K.y)


func _hs4_pixellab_origin(viewport_size: Vector2, scale: float) -> Vector2:
	return Vector2(
		roundf((viewport_size.x - HS4_DESIGN_BASE_2K.x * scale) * 0.5),
		roundf((viewport_size.y - HS4_DESIGN_BASE_2K.y * scale) * 0.5)
	)


func _hs4_pixellab_content_margins(slot: String, display_size: Vector2) -> Vector4:
	if not HS4_PIXELLAB_SOURCE_SIZE.has(slot) or not HS4_PIXELLAB_CONTENT_RECT.has(slot):
		return Vector4.ZERO
	var source_size: Vector2 = HS4_PIXELLAB_SOURCE_SIZE[slot]
	var content_rect: Rect2 = HS4_PIXELLAB_CONTENT_RECT[slot]
	var scale_x := display_size.x / maxf(source_size.x, 1.0)
	var scale_y := display_size.y / maxf(source_size.y, 1.0)
	return Vector4(
		roundf(content_rect.position.x * scale_x),
		roundf(content_rect.position.y * scale_y),
		roundf((source_size.x - content_rect.position.x - content_rect.size.x) * scale_x),
		roundf((source_size.y - content_rect.position.y - content_rect.size.y) * scale_y)
	)


func _hs4_pixellab_style(slot: String, display_size: Vector2, tint := Color.WHITE) -> StyleBox:
	if not HS4_PIXELLAB_PATHS.has(slot):
		return _minimal_metal_frame_style("panel", tint)
	var margins := _hs4_pixellab_content_margins(slot, display_size)
	return _global_texture_style(str(HS4_PIXELLAB_PATHS[slot]), margins, tint, margins, false)


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


func _hero_select_preview_sprite_frames(character_id: String) -> SpriteFrames:
	var frames_path := "res://assets/sprites/characters/%s_spriteframes.tres" % character_id
	if not ResourceLoader.exists(frames_path):
		return null
	var frames := load(frames_path) as SpriteFrames
	if frames == null:
		return null
	for direction in HERO_SELECT_PREVIEW_CLOCKWISE_DIRECTIONS:
		if not _hero_select_direction_animation_name(frames, direction).is_empty():
			return frames
	return null


func _hero_select_direction_animation_name(frames: SpriteFrames, direction: String) -> String:
	for prefix in ["idle", "move", "walk"]:
		var animation_name := "%s_%s" % [prefix, direction]
		if frames.has_animation(animation_name):
			return animation_name
	return ""


func _set_hero_select_portrait_preview(portrait: TextureRect, character_id: String, config: Dictionary, preview_state: Dictionary) -> void:
	var frames := _hero_select_preview_sprite_frames(character_id)
	if frames == null:
		preview_state["character_id"] = ""
		preview_state["sprite_frames"] = null
		portrait.texture = game._cached_texture(str(config.get("sprite_path", config.get("sprite", ""))))
		return
	preview_state["character_id"] = character_id
	preview_state["sprite_frames"] = frames
	preview_state["direction_index"] = 0
	preview_state["frame_index"] = 0
	_advance_hero_select_portrait_preview(portrait, preview_state)


func _advance_hero_select_portrait_preview(portrait: TextureRect, preview_state: Dictionary) -> void:
	if portrait == null or not is_instance_valid(portrait):
		return
	var frames := preview_state.get("sprite_frames", null) as SpriteFrames
	if frames == null:
		return
	var direction_index := int(preview_state.get("direction_index", 0))
	var frame_index := int(preview_state.get("frame_index", 0))
	var directions := HERO_SELECT_PREVIEW_CLOCKWISE_DIRECTIONS
	for attempt in range(directions.size()):
		var direction := str(directions[posmod(direction_index + attempt, directions.size())])
		var animation_name := _hero_select_direction_animation_name(frames, direction)
		if animation_name.is_empty():
			continue
		var frame_count := maxi(frames.get_frame_count(animation_name), 1)
		frame_index = posmod(frame_index, frame_count)
		portrait.texture = frames.get_frame_texture(animation_name, frame_index)
		frame_index += 1
		if frame_index >= frame_count:
			frame_index = 0
			direction_index = posmod(direction_index + attempt + 1, directions.size())
		else:
			direction_index = posmod(direction_index + attempt, directions.size())
		preview_state["direction_index"] = direction_index
		preview_state["frame_index"] = frame_index
		return


# SCRUM-851: тултип стата краткий — «Имя — значение» + человеческое описание.
# Формулы, тех-листинги производных и классовые интерпретации — в кодекс, не в ховер.
func _hs4_stat_tooltip(stat_id: String, value: float, _character_id: String) -> String:
	var definition: Dictionary = StatFormulas.STAT_DEFINITIONS.get(stat_id, {})
	var stat_name := str(game.PROGRESSION_DATA.STAT_NAMES.get(stat_id, stat_id))
	return "%s — %d\n%s" % [
		stat_name,
		int(round(value)),
		str(definition.get("description", "")),
	]


func _hs4_ascension_text(level: int) -> String:
	var lines: Array = game.PROGRESSION_DATA.ascension_modifier_lines(level)
	if lines.is_empty():
		return "Уровень 0: без усложнений."
	return "\n".join(lines)


func _hs4_attribute_display_name(attr_id: String) -> String:
	for entry in game.PROGRESSION_DATA.ATTRIBUTE_REGISTRY:
		var item := entry as Dictionary
		if str(item.get("id", "")) == attr_id:
			return str(item.get("name", attr_id))
	return str(game.PROGRESSION_DATA.STAT_NAMES.get(attr_id, attr_id))


func _hs4_attribute_guidance_groups(character_id: String) -> Dictionary:
	var groups := {
		"primary": [],
		"secondary": [],
		"optional": [],
	}
	for entry in game.PROGRESSION_DATA.ATTRIBUTE_REGISTRY:
		var item := entry as Dictionary
		var attr_id := str(item.get("id", ""))
		if attr_id == "":
			continue
		var relevance := str(game.PROGRESSION_DATA.attribute_relevance(attr_id, character_id))
		if not groups.has(relevance):
			relevance = "optional"
		(groups[relevance] as Array).append(_hs4_attribute_display_name(attr_id))
	return groups


func _hs4_join_guidance_names(names: Array, max_items := 8) -> String:
	if names.is_empty():
		return "Нет."
	var shown := PackedStringArray()
	for i in range(mini(names.size(), max_items)):
		shown.append(str(names[i]))
	if names.size() > max_items:
		shown.append("+%d" % (names.size() - max_items))
	return ", ".join(shown)


func _hs4_stat_fill_color(stat_id: String) -> Color:
	var base := Color(0.92, 0.70, 0.28, 0.95)
	if HERO_CLASS_COLORS.has(game.selected_character_id):
		base = HERO_CLASS_COLORS[game.selected_character_id]
	match stat_id:
		"strength":
			return Color(1.0, 0.34, 0.22, 0.95).lerp(base, 0.25)
		"agility":
			return Color(0.96, 0.76, 0.28, 0.95).lerp(base, 0.25)
		"intelligence":
			return Color(0.62, 0.42, 1.0, 0.95).lerp(base, 0.25)
		"perception":
			return Color(0.44, 0.72, 1.0, 0.95).lerp(base, 0.25)
		"energy":
			return Color(0.24, 0.88, 1.0, 0.95).lerp(base, 0.25)
		"knowledge":
			return Color(0.52, 0.92, 0.54, 0.95).lerp(base, 0.25)
		"endurance":
			return Color(0.92, 0.52, 0.32, 0.95).lerp(base, 0.25)
		"leadership":
			return Color(1.0, 0.86, 0.42, 0.95).lerp(base, 0.25)
		_:
			return base


func _build_character_select_v4() -> void:
	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "HeroSelectScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.ui_layer.add_child(root)
	_prepare_global_tooltips(root)

	var vp: Vector2 = root.get_viewport_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		vp = Vector2(1600.0, 900.0)
	var layout_scale := clampf(vp.y / 900.0, 0.76, 1.18)
	var s := _atlas_ui_scale()
	var action_h := _atlas_action_button_height()

	# SCRUM-879: единый атлас-стиль — фон-зал героев, контент строго в safe-зоне
	# рамы, полая рама frame_border добавляется последней (поверх контента).
	_unified_add_background(root, "hero_select")
	var sm := _unified_safe_margins()
	var content_rect := Rect2(Vector2(sm.x, sm.y), vp - Vector2(sm.x + sm.z, sm.y + sm.w))

	# --- Шапка: чип-титул слева, «Назад» на глобальном ките справа ---
	var title_chip := _unified_header_chip("HS4", "Выбор героя", "hero_select", s)
	title_chip.position = content_rect.position
	root.add_child(title_chip)
	var back_button := _make_button("Назад")
	back_button.name = "HS4BackButton"
	# Единый возврат (фидбек 2026-07-08): та же плита 260×h, что на всех экранах.
	_set_action_button_size(back_button, 260.0, action_h)
	back_button.position = Vector2(content_rect.end.x - 260.0, content_rect.position.y)
	root.add_child(back_button)
	back_button.pressed.connect(_show_main_menu)
	# Реальная высота шапки: у кит-кнопки 9-slice минимум выше компактного
	# action_h (контент-маргины ассета) — меряем фактический минимум.
	var header_h := maxf(back_button.get_combined_minimum_size().y, action_h)

	# Геометрия (SCRUM-882): единая шапка (чип-титул слева, «Назад» справа) над
	# ОБЕИМИ колоннами; ниже слева колонна-витрина (портрет на пьедестале →
	# возвышение → CTA «Выбрать» у низа safe-зоны), справа досье строго вровень
	# с портретом и карусель под ним.
	var column_gap := clampf(content_rect.size.x * 0.012, 8.0, 16.0)
	var vgap := clampf(content_rect.size.y * 0.010, 4.0, 10.0)
	var header_band := maxf(title_chip.get_combined_minimum_size().y + 4.0, header_h)
	var carousel_slot_size := clampf(content_rect.size.y * 0.26, HS4_MINIMAL_SLOT_MIN_SIZE, HS4_MINIMAL_SLOT_MAX_SIZE)
	var carousel_h := carousel_slot_size + clampf(content_rect.size.y * 0.012, 6.0, 14.0)
	var carousel_min_w := 2.0 * 54.0 + 3.0 * HS4_MINIMAL_SLOT_MIN_SIZE + 4.0 * 6.0
	# CTA «Выбрать» — плита кнопок главного меню 380×104 (Правило 1: только
	# пропорциональный даунскейл под ширину колонны, аспект не ломаем).
	var choose_aspect := 104.0 / 380.0
	var ascension_pad := roundf(clampf(9.0 * s, 4.0, 9.0))
	var asc_min_h := 42.0 + ascension_pad * 2.0
	var asc_target_h := maxf(asc_min_h, clampf(content_rect.size.y * 0.115, 52.0, 100.0))
	# Вертикальный бюджет колонны: portrait + vgap + возвышение + vgap + CTA.
	# На коротких вьюпортах превью ужимается ниже прежнего пола 320 — CTA и
	# степпер возвышения (кнопки ≥42px, seal-контракт) важнее пары строк портрета.
	var preview_floor := HS4_MINIMAL_PREVIEW_MIN_SIZE
	if vp.y < 720.0:
		preview_floor = 240.0
	elif vp.y < 800.0:
		preview_floor = 270.0
	var left_x := content_rect.position.x
	var left_top := content_rect.position.y + header_band + vgap
	var column_budget := content_rect.end.y - left_top
	var portrait_size := (column_budget - vgap * 2.0 - asc_target_h) / (1.0 + choose_aspect)
	if portrait_size > MAX_ACTION_BUTTON_VISUAL_WIDTH:
		# Плита CTA шире 560 не растёт (глобальный кап кита) — высота фиксируется.
		portrait_size = column_budget - vgap * 2.0 - asc_target_h - roundf(MAX_ACTION_BUTTON_VISUAL_WIDTH * choose_aspect)
	portrait_size = minf(portrait_size, content_rect.size.x * 0.34)
	portrait_size = minf(portrait_size, content_rect.size.x - column_gap - carousel_min_w)
	portrait_size = floorf(clampf(portrait_size, preview_floor, HS4_MINIMAL_PREVIEW_MAX_SIZE))
	var choose_w := minf(portrait_size, MAX_ACTION_BUTTON_VISUAL_WIDTH)
	var choose_h := maxf(roundf(choose_w * choose_aspect), 68.0)
	var choose_top := content_rect.end.y - choose_h
	var dossier_x := left_x + portrait_size + column_gap
	var dossier_w := content_rect.end.x - dossier_x
	# Фидбек SCRUM-882: top досье == top портрет-фрейма (одна линия под шапкой).
	var dossier_y := left_top
	var carousel_y := content_rect.end.y - carousel_h

	# Счётчик карусели «N–M из K» — полупрозрачный чип над правым краем карусели.
	# Создаётся до досье: его высота резервирует полосу между досье и каруселью.
	var carousel_counter := PanelContainer.new()
	carousel_counter.name = "HS4CarouselCounter"
	var counter_style := _atlas_translucent_style(0.55, 8.0)
	counter_style.content_margin_left = 12.0
	counter_style.content_margin_right = 12.0
	counter_style.content_margin_top = 4.0
	counter_style.content_margin_bottom = 4.0
	carousel_counter.add_theme_stylebox_override("panel", counter_style)
	carousel_counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var carousel_counter_label := Label.new()
	carousel_counter_label.name = "HS4CarouselCounterLabel"
	carousel_counter_label.text = "88–88 из 88"
	carousel_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	carousel_counter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	carousel_counter_label.add_theme_font_size_override("font_size", _readable_font_size(12, 0, 18))
	carousel_counter_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.72, 1.0))
	carousel_counter.add_child(carousel_counter_label)
	root.add_child(carousel_counter)
	var counter_band := carousel_counter.get_combined_minimum_size().y

	# Досье чуть ниже по высоте (фидбек): низ поднят минимум на 10% высоты полосы,
	# освобождённая полоса — воздуху и счётчику карусели.
	var dossier_full_h := carousel_y - vgap - dossier_y
	var dossier_lift := maxf(roundf(dossier_full_h * 0.10), counter_band + 12.0)
	var dossier_h := dossier_full_h - dossier_lift

	var portrait_panel := Panel.new()
	portrait_panel.name = "HS4PortraitFrame"
	portrait_panel.position = Vector2(left_x, left_top)
	portrait_panel.size = Vector2(portrait_size, portrait_size)
	portrait_panel.custom_minimum_size = portrait_panel.size
	portrait_panel.add_theme_stylebox_override("panel", _atlas_chip_style(0.82, roundf(clampf(10.0 * s, 5.0, 10.0))))
	portrait_panel.clip_contents = true
	portrait_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(portrait_panel)

	# Пьедестал-подиум PixelLab: аспект-бокс 676:148 у нижней кромки портрет-фрейма,
	# добавлен ДО портрета (под ним по z-порядку). Герой floor-align на верхнюю
	# площадку — линия пола = верх бокса + 22% его высоты.
	var pedestal := TextureRect.new()
	pedestal.name = "HS4Pedestal"
	pedestal.texture = game._cached_texture(ATLAS_STYLE_PEDESTAL_PATH)
	pedestal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pedestal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pedestal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pedestal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pedestal_w := roundf(portrait_size * 0.86)
	var pedestal_h := roundf(pedestal_w * 148.0 / 676.0)
	pedestal.position = Vector2(roundf((portrait_size - pedestal_w) * 0.5), portrait_size - pedestal_h - maxf(6.0, roundf(portrait_size * 0.02)))
	pedestal.size = Vector2(pedestal_w, pedestal_h)
	portrait_panel.add_child(pedestal)
	var portrait := TextureRect.new()
	portrait.name = "HS4Portrait"
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.set_anchors_preset(Control.PRESET_TOP_LEFT)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_panel.add_child(portrait)
	var hs4_alpha_bbox_cache := {}
	var texture_alpha_bbox := func(texture: Texture2D) -> Rect2:
		var texture_size := Vector2(512.0, 512.0)
		if texture != null and texture.get_size().x > 0.0 and texture.get_size().y > 0.0:
			texture_size = texture.get_size()
		if texture == null:
			return Rect2(Vector2.ZERO, texture_size)
		var key := texture.resource_path
		if key.is_empty():
			key = str(texture.get_rid())
		if hs4_alpha_bbox_cache.has(key):
			return hs4_alpha_bbox_cache[key]
		var bbox := Rect2(Vector2.ZERO, texture_size)
		var image := texture.get_image()
		if image != null and not image.is_empty():
			var min_x := image.get_width()
			var min_y := image.get_height()
			var max_x := -1
			var max_y := -1
			var alpha_threshold := 0.02
			for y in range(image.get_height()):
				for x in range(image.get_width()):
					if image.get_pixel(x, y).a <= alpha_threshold:
						continue
					min_x = mini(min_x, x)
					min_y = mini(min_y, y)
					max_x = maxi(max_x, x)
					max_y = maxi(max_y, y)
			if max_x >= min_x and max_y >= min_y:
				bbox = Rect2(Vector2(float(min_x), float(min_y)), Vector2(float(max_x - min_x + 1), float(max_y - min_y + 1)))
		hs4_alpha_bbox_cache[key] = bbox
		return bbox
	var position_alpha_cropped_texture := func(texture_rect: TextureRect, texture: Texture2D, parent_size: Vector2, target_visible_size: Vector2, visible_bottom_y: float, visible_center_x: float) -> void:
		if texture_rect == null or not is_instance_valid(texture_rect):
			return
		var texture_size := Vector2(512.0, 512.0)
		if texture != null and texture.get_size().x > 0.0 and texture.get_size().y > 0.0:
			texture_size = texture.get_size()
		var bbox: Rect2 = texture_alpha_bbox.call(texture)
		var bbox_w := maxf(1.0, bbox.size.x)
		var bbox_h := maxf(1.0, bbox.size.y)
		var visible_target := Vector2(maxf(1.0, target_visible_size.x), maxf(1.0, target_visible_size.y))
		var draw_scale := minf(visible_target.x / bbox_w, visible_target.y / bbox_h)
		draw_scale = maxf(draw_scale, 0.01)
		var draw_size := Vector2(roundf(texture_size.x * draw_scale), roundf(texture_size.y * draw_scale))
		var visible_texture_center_x := bbox.position.x + bbox.size.x * 0.5
		var visible_texture_bottom_y := bbox.position.y + bbox.size.y
		var left := roundf(visible_center_x - visible_texture_center_x * draw_scale)
		var top := roundf(visible_bottom_y - visible_texture_bottom_y * draw_scale)
		texture_rect.anchor_left = 0.0
		texture_rect.anchor_top = 0.0
		texture_rect.anchor_right = 0.0
		texture_rect.anchor_bottom = 0.0
		texture_rect.offset_left = left
		texture_rect.offset_top = top
		texture_rect.offset_right = left + draw_size.x
		texture_rect.offset_bottom = top + draw_size.y
	var position_main_portrait := func(texture: Texture2D) -> void:
		# Floor-align на верхнюю площадку пьедестала (верх бокса + 22% высоты).
		var floor_y := pedestal.position.y + roundf(pedestal.size.y * 0.22)
		var visible_target := Vector2(portrait_panel.size.x * 0.86, maxf(96.0, floor_y - maxf(10.0, roundf(portrait_panel.size.y * 0.05))))
		position_alpha_cropped_texture.call(portrait, texture, portrait_panel.size, visible_target, floor_y, portrait_panel.size.x * 0.5)
	var portrait_preview_state := {
		"character_id": "",
		"sprite_frames": null,
		"direction_index": 0,
		"frame_index": 0,
	}
	var portrait_preview_timer := Timer.new()
	portrait_preview_timer.name = "HS4PortraitPreviewTimer"
	portrait_preview_timer.wait_time = 0.10
	portrait_preview_timer.autostart = true
	root.add_child(portrait_preview_timer)
	portrait_preview_timer.timeout.connect(func() -> void:
		_advance_hero_select_portrait_preview(portrait, portrait_preview_state)
		position_main_portrait.call(portrait.texture)
	)

	var dossier_chip_pad := roundf(clampf(12.0 * s, 6.0, 12.0))
	var dossier_panel := PanelContainer.new()
	dossier_panel.name = "HS4DossierFrame"
	dossier_panel.position = Vector2(dossier_x, dossier_y)
	dossier_panel.size = Vector2(dossier_w, dossier_h)
	dossier_panel.add_theme_stylebox_override("panel", _atlas_chip_style(0.88, dossier_chip_pad))
	dossier_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(dossier_panel)

	var dossier_margin_side := maxi(14, int(round(20.0 * layout_scale)))
	var dossier_margin_v := maxi(12, int(round(16.0 * layout_scale)))
	var dossier_margin := MarginContainer.new()
	dossier_margin.name = "HS4DossierContentSafe"
	dossier_margin.add_theme_constant_override("margin_left", dossier_margin_side)
	dossier_margin.add_theme_constant_override("margin_top", dossier_margin_v)
	dossier_margin.add_theme_constant_override("margin_right", dossier_margin_side)
	dossier_margin.add_theme_constant_override("margin_bottom", dossier_margin_v)
	dossier_panel.add_child(dossier_margin)

	# SCRUM-887: досье из двух колонн — слева скролл текстов (растёт), справа
	# фикс-колонна из 8 полос характеристик БЕЗ скролла (всегда все видимы).
	var dossier_columns := HBoxContainer.new()
	dossier_columns.name = "HS4DossierColumns"
	dossier_columns.add_theme_constant_override("separation", maxi(10, int(round(14.0 * layout_scale))))
	dossier_margin.add_child(dossier_columns)

	var dossier_scroll := ScrollContainer.new()
	dossier_scroll.name = "HS4DossierScroll"
	dossier_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dossier_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	dossier_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dossier_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dossier_columns.add_child(dossier_scroll)

	var dossier_content := VBoxContainer.new()
	dossier_content.name = "HS4DossierContent"
	dossier_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dossier_content.add_theme_constant_override("separation", maxi(5, int(round(8.0 * layout_scale))))
	dossier_scroll.add_child(dossier_content)

	var name_label := Label.new()
	name_label.name = "HS4NameLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.add_theme_font_size_override("font_size", _readable_font_size(maxi(20, int(round(30.0 * layout_scale))), 0, 44))
	name_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	dossier_content.add_child(name_label)

	var desc_label := Label.new()
	desc_label.name = "HS4Description"
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc_label.max_lines_visible = 3
	desc_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	desc_label.add_theme_font_size_override("font_size", _readable_font_size(maxi(12, int(round(16.0 * layout_scale))), 0, 24))
	desc_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))
	dossier_content.add_child(desc_label)

	var strengths_label := Label.new()
	strengths_label.name = "HS4Strengths"
	strengths_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	strengths_label.max_lines_visible = 2
	strengths_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	strengths_label.add_theme_font_size_override("font_size", _readable_font_size(maxi(11, int(round(15.0 * layout_scale))), 0, 22))
	strengths_label.add_theme_color_override("font_color", Color(0.78, 0.94, 0.74, 1.0))
	dossier_content.add_child(strengths_label)

	var weaknesses_label := Label.new()
	weaknesses_label.name = "HS4Weaknesses"
	weaknesses_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	weaknesses_label.max_lines_visible = 2
	weaknesses_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	weaknesses_label.add_theme_font_size_override("font_size", _readable_font_size(maxi(11, int(round(15.0 * layout_scale))), 0, 22))
	weaknesses_label.add_theme_color_override("font_color", Color(0.95, 0.62, 0.58, 1.0))
	dossier_content.add_child(weaknesses_label)

	# SCRUM-887: главные атрибуты класса из данных (main_attribute + следующий
	# по ATTRIBUTE_PRIORITIES) — сразу после слабых сторон, золотым.
	var main_attrs_label := Label.new()
	main_attrs_label.name = "HS4MainAttributes"
	main_attrs_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_attrs_label.max_lines_visible = 2
	main_attrs_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	main_attrs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	main_attrs_label.add_theme_font_size_override("font_size", _readable_font_size(maxi(11, int(round(15.0 * layout_scale))), 0, 22))
	main_attrs_label.add_theme_color_override("font_color", Color(0.94, 0.80, 0.46, 1.0))
	dossier_content.add_child(main_attrs_label)

	var weapon_label := Label.new()
	weapon_label.name = "HS4Weapon"
	weapon_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	weapon_label.max_lines_visible = 2
	weapon_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	weapon_label.add_theme_font_size_override("font_size", _readable_font_size(maxi(11, int(round(14.0 * layout_scale))), 0, 22))
	weapon_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))
	weapon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dossier_content.add_child(weapon_label)

	var identity_label := Label.new()
	identity_label.name = "HS4Identity"
	identity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity_label.max_lines_visible = 2
	identity_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	identity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	identity_label.add_theme_font_size_override("font_size", _readable_font_size(maxi(10, int(round(13.0 * layout_scale))), 0, 20))
	identity_label.add_theme_color_override("font_color", Color(0.78, 0.66, 0.44, 1.0))
	identity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dossier_content.add_child(identity_label)

	# SCRUM-887: правая фикс-колонна характеристик — 8 полос ВЕРТИКАЛЬНО, без
	# скролла. Высоты решает арифметика (не min-size детей): хост — обычный
	# Control, PanelContainer не распирается (грабли SCRUM-876, см. memory).
	var stats_col_w := clampf(300.0 * layout_scale, 220.0, 320.0)
	var stats_inner_h := dossier_h - 2.0 * dossier_chip_pad - 2.0 * float(dossier_margin_v)
	var stats_column := Control.new()
	stats_column.name = "HS4StatsColumn"
	stats_column.custom_minimum_size = Vector2(stats_col_w, 0.0)
	stats_column.mouse_filter = Control.MOUSE_FILTER_PASS
	dossier_columns.add_child(stats_column)

	var stats_title_font := _readable_font_size(maxi(11, int(round(14.0 * layout_scale))), 0, 22)
	var stats_title_band := roundf(float(stats_title_font) * 1.5) + 6.0
	# Норма: ряд 34–52px; не влезает (720p) — компакт-паддинги; совсем мало
	# (648p) — ультра-компакт: только бары, имена/значения уходят в тултип.
	var stat_row_sep := clampf(roundf(4.0 * layout_scale), 3.0, 6.0)
	var stat_row_h := clampf(floorf((stats_inner_h - stats_title_band - 7.0 * stat_row_sep) / 8.0), 34.0, 52.0)
	var stat_row_style_pad := 8.0
	var stat_row_pad_v := 5.0
	var stat_row_pad_h := 8.0
	if stats_title_band + 8.0 * stat_row_h + 7.0 * stat_row_sep > stats_inner_h + 0.5:
		stat_row_sep = 2.0
		stat_row_style_pad = 4.0
		stat_row_pad_v = 1.0
		stat_row_pad_h = 6.0
		stat_row_h = floorf((stats_inner_h - stats_title_band - 7.0 * stat_row_sep) / 8.0)
	var stat_rows_show_text := stat_row_h >= 14.0
	if not stat_rows_show_text:
		stat_row_style_pad = 2.0
		stat_row_h = maxf(10.0, stat_row_h)

	var stats_title := Label.new()
	stats_title.name = "HS4StatsTitle"
	stats_title.text = "Характеристики"
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stats_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stats_title.position = Vector2.ZERO
	stats_title.size = Vector2(stats_col_w, maxf(0.0, stats_title_band - 4.0))
	stats_title.add_theme_font_size_override("font_size", stats_title_font)
	stats_title.add_theme_color_override("font_color", Color(0.78, 0.66, 0.44, 1.0))
	stats_column.add_child(stats_title)

	var stats_grid := GridContainer.new()
	stats_grid.name = "HS4StatsGrid"
	stats_grid.columns = 1
	stats_grid.position = Vector2(0.0, stats_title_band)
	stats_grid.size = Vector2(stats_col_w, maxf(0.0, stats_inner_h - stats_title_band))
	stats_grid.add_theme_constant_override("v_separation", int(stat_row_sep))
	stats_column.add_child(stats_grid)
	var stat_buttons := {}
	var stat_fill_nodes := {}
	var stat_value_labels := {}
	for sid in HS4_MINIMAL_BASE_STATS:
		var stat_button := Button.new()
		stat_button.name = "HS4Stat_%s" % sid
		stat_button.custom_minimum_size = Vector2(stats_col_w, stat_row_h)
		stat_button.mouse_default_cursor_shape = Control.CURSOR_HELP
		stat_button.focus_mode = Control.FOCUS_ALL
		stat_button.text = ""
		stat_button.add_theme_font_size_override("font_size", _readable_font_size(maxi(10, int(round(12.0 * layout_scale))), 0, 18))
		_unified_apply_row_theme(stat_button, stat_row_style_pad)
		var stat_row := HBoxContainer.new()
		stat_row.name = "HS4StatLine_%s" % sid
		stat_row.set_anchors_preset(Control.PRESET_FULL_RECT)
		stat_row.offset_left = stat_row_pad_h
		stat_row.offset_right = -stat_row_pad_h
		stat_row.offset_top = stat_row_pad_v
		stat_row.offset_bottom = -stat_row_pad_v
		stat_row.add_theme_constant_override("separation", maxi(5, int(round(7.0 * layout_scale))))
		stat_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stat_button.add_child(stat_row)
		var stat_name := Label.new()
		stat_name.name = "HS4StatName_%s" % sid
		stat_name.custom_minimum_size = Vector2(maxf(72.0, 92.0 * layout_scale), 0.0)
		stat_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stat_name.text = str(game.PROGRESSION_DATA.STAT_NAMES.get(sid, sid))
		stat_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		stat_name.visible = stat_rows_show_text
		stat_name.add_theme_font_size_override("font_size", _readable_font_size(maxi(9, int(round(12.0 * layout_scale))), 0, 18))
		stat_name.add_theme_color_override("font_color", Color(0.88, 0.84, 0.74, 1.0))
		stat_row.add_child(stat_name)
		var bar_bg := ColorRect.new()
		bar_bg.name = "HS4StatBar_%s" % sid
		bar_bg.custom_minimum_size = Vector2(maxf(64.0, 96.0 * layout_scale), maxf(8.0, minf(12.0 * layout_scale, stat_row_h - 2.0 * stat_row_pad_v)))
		bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar_bg.color = Color(0.09, 0.085, 0.075, 0.92)
		bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stat_row.add_child(bar_bg)
		var bar_fill := ColorRect.new()
		bar_fill.name = "HS4StatBarFill_%s" % sid
		bar_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
		bar_fill.anchor_right = 0.5
		bar_fill.color = _hs4_stat_fill_color(sid)
		bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar_bg.add_child(bar_fill)
		var stat_value := Label.new()
		stat_value.name = "HS4StatValue_%s" % sid
		stat_value.custom_minimum_size = Vector2(maxf(22.0, 28.0 * layout_scale), 0.0)
		stat_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stat_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stat_value.visible = stat_rows_show_text
		stat_value.add_theme_font_size_override("font_size", _readable_font_size(maxi(9, int(round(12.0 * layout_scale))), 0, 18))
		stat_value.add_theme_color_override("font_color", Color(0.96, 0.90, 0.70, 1.0))
		stat_row.add_child(stat_value)
		stats_grid.add_child(stat_button)
		stat_buttons[sid] = stat_button
		stat_fill_nodes[sid] = bar_fill
		stat_value_labels[sid] = stat_value

	var guidance_title := Label.new()
	guidance_title.name = "HS4BuildGuidanceTitle"
	guidance_title.text = "Подсказки билда"
	guidance_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	guidance_title.add_theme_font_size_override("font_size", _readable_font_size(maxi(11, int(round(14.0 * layout_scale))), 0, 22))
	guidance_title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	dossier_content.add_child(guidance_title)

	var guidance_labels := {}
	for relevance in HeroSelectConstants.HERO_BUILD_RELEVANCE_ORDER:
		var guide_label := Label.new()
		guide_label.name = "HS4BuildGuidance_%s" % relevance
		guide_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		guide_label.max_lines_visible = 2 if relevance != "optional" else 1
		guide_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		guide_label.add_theme_font_size_override("font_size", _readable_font_size(maxi(10, int(round(13.0 * layout_scale))), 0, 20))
		guide_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))
		dossier_content.add_child(guide_label)
		guidance_labels[relevance] = guide_label

	# Возвышение занимает полосу между портретом и CTA (кап 132px — лишний воздух
	# уходит между возвышением и кнопкой, а не растягивает панель). Хост — обычный
	# Panel с ручным лейаутом: PanelContainer растёт от min-size детей и ломает
	# фикс-геометрию колонны (грабли SCRUM-876, см. memory).
	var ascension_top := left_top + portrait_size + vgap
	var ascension_h := maxf(asc_min_h, minf(choose_top - vgap - ascension_top, 132.0))
	var ascension_panel := Panel.new()
	ascension_panel.name = "HS4AscensionFrame"
	ascension_panel.position = Vector2(left_x, ascension_top)
	ascension_panel.size = Vector2(portrait_size, ascension_h)
	ascension_panel.add_theme_stylebox_override("panel", _atlas_chip_style(0.86, ascension_pad))
	ascension_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(ascension_panel)
	# Вертикальный бюджет контента: степпер + (если влезает) строка модификаторов.
	var asc_content_h := ascension_h - ascension_pad * 2.0
	var asc_mods_font := _readable_font_size(maxi(9, int(round(11.0 * layout_scale))), 0, 16)
	var asc_mods_line_h := roundf(float(asc_mods_font) * 1.5)
	var asc_row_gap := 4.0
	var asc_button_px := clampf(asc_content_h - asc_mods_line_h - asc_row_gap, 42.0, 56.0)
	var asc_button_size := Vector2(asc_button_px, asc_button_px)
	var asc_mods_fits := asc_content_h - asc_button_px - asc_row_gap >= asc_mods_line_h - 0.5
	var asc_used_h := asc_button_px + ((asc_row_gap + asc_mods_line_h) if asc_mods_fits else 0.0)
	var asc_row_y := ascension_pad + maxf(0.0, roundf((asc_content_h - asc_used_h) * 0.5))

	# SCRUM-882: компакт-панель между портретом и CTA — титул всегда в тултипе
	# панели, вертикальный бюджет уходит степперу и строке модификаторов.
	var asc_label := Label.new()
	asc_label.name = "AscensionLevelLabel"
	asc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	asc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	asc_label.add_theme_font_size_override("font_size", _readable_font_size(maxi(12, int(round(17.0 * layout_scale))), 0, 26))
	asc_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	asc_label.visible = false
	asc_label.position = Vector2(ascension_pad * 1.4, ascension_pad)
	asc_label.size = Vector2(maxf(0.0, portrait_size - ascension_pad * 2.8), 0.0)
	ascension_panel.add_child(asc_label)

	var asc_intro := Label.new()
	asc_intro.name = "HS4AscensionIntro"
	asc_intro.text = "Возвышение усложняет забег и открывает мета-прогресс персонажа после победы над боссом."
	asc_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	asc_intro.max_lines_visible = 1
	asc_intro.visible = false
	asc_intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	asc_intro.add_theme_font_size_override("font_size", _readable_font_size(maxi(9, int(round(11.0 * layout_scale))), 0, 16))
	asc_intro.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))
	asc_intro.position = Vector2(ascension_pad * 1.4, ascension_pad)
	asc_intro.size = Vector2(maxf(0.0, portrait_size - ascension_pad * 2.8), 0.0)
	ascension_panel.add_child(asc_intro)

	var asc_box := HBoxContainer.new()
	asc_box.name = "HS4AscensionActionRow"
	asc_box.alignment = BoxContainer.ALIGNMENT_CENTER
	asc_box.add_theme_constant_override("separation", maxi(5, int(round(7.0 * layout_scale))))
	ascension_panel.add_child(asc_box)
	var asc_minus := _make_button("−")
	asc_minus.name = "AscensionMinusButton"
	# Степпер ≥42px — seal-контракт runtime_smoke.
	_set_action_button_size(asc_minus, asc_button_size.x, asc_button_size.y)
	asc_minus.add_theme_font_size_override("font_size", _readable_font_size(maxi(16, int(round(22.0 * layout_scale))), 0, 34))
	asc_box.add_child(asc_minus)
	var asc_stepper_label := Label.new()
	asc_stepper_label.name = "HS4AscensionValue"
	asc_stepper_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	asc_stepper_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	asc_stepper_label.custom_minimum_size = Vector2(maxf(64.0, roundf(84.0 * layout_scale)), asc_button_size.y)
	asc_stepper_label.add_theme_font_size_override("font_size", _readable_font_size(maxi(12, int(round(15.0 * layout_scale))), 0, 24))
	asc_stepper_label.add_theme_color_override("font_color", Color(0.92, 0.84, 0.66, 1.0))
	asc_box.add_child(asc_stepper_label)
	var asc_plus := _make_button("+")
	asc_plus.name = "AscensionPlusButton"
	_set_action_button_size(asc_plus, asc_button_size.x, asc_button_size.y)
	asc_plus.add_theme_font_size_override("font_size", _readable_font_size(maxi(16, int(round(22.0 * layout_scale))), 0, 34))
	asc_box.add_child(asc_plus)
	# Ручное центрирование ряда степпера в фикс-панели.
	asc_box.size = asc_box.get_combined_minimum_size()
	asc_box.position = Vector2(roundf((portrait_size - asc_box.size.x) * 0.5), asc_row_y)

	var asc_mods := Label.new()
	asc_mods.name = "AscensionModsLabel"
	asc_mods.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	asc_mods.max_lines_visible = 1
	asc_mods.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	asc_mods.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	asc_mods.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	asc_mods.add_theme_font_size_override("font_size", asc_mods_font)
	asc_mods.add_theme_color_override("font_color", Color(0.95, 0.62, 0.55, 0.95))
	# Компакт-страховка: если строка модификаторов не помещается под степпером,
	# она уходит в тултип панели (бюджет решается арифметикой, не min-size).
	asc_mods.visible = asc_mods_fits
	asc_mods.position = Vector2(ascension_pad * 1.4, asc_row_y + asc_button_px + asc_row_gap)
	asc_mods.size = Vector2(maxf(0.0, portrait_size - ascension_pad * 2.8), asc_mods_line_h)
	ascension_panel.add_child(asc_mods)

	# Фидбек SCRUM-882: CTA «Выбрать» — под превью и возвышением, прижат к низу
	# safe-зоны, на плите кнопок главного меню (main_menu_380x104 через
	# _text_button_unique_id) во всю ширину колонны. Шрифт — базовый кнопочный
	# (как в главном меню), без кастомных override.
	var select_button := _make_button("Выбрать")
	select_button.name = "HS4ChooseButton"
	_set_action_button_size(select_button, choose_w, choose_h)
	select_button.clip_text = true
	select_button.position = Vector2(left_x + roundf((portrait_size - choose_w) * 0.5), choose_top)
	root.add_child(select_button)

	var carousel_panel := Panel.new()
	carousel_panel.name = "HS4CarouselFrame"
	carousel_panel.position = Vector2(dossier_x, carousel_y)
	carousel_panel.size = Vector2(dossier_w, carousel_h)
	carousel_panel.add_theme_stylebox_override("panel", _atlas_translucent_style(0.45, 12.0))
	carousel_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(carousel_panel)
	var carousel := Control.new()
	carousel.name = "HS4Carousel"
	carousel.position = Vector2.ZERO
	carousel.size = carousel_panel.size
	carousel.mouse_filter = Control.MOUSE_FILTER_PASS
	carousel_panel.add_child(carousel)
	var carousel_w: float = carousel.size.x
	var carousel_area_h: float = carousel.size.y
	var arrow_size := Vector2(54.0, 42.0)
	var slot_size := Vector2(carousel_slot_size, carousel_slot_size)
	var slot_label_h := clampf(roundf(slot_size.y * 0.17), 26.0, 34.0)
	var slot_label_gap := maxf(3.0, roundf(slot_size.y * 0.02))
	var slot_label_margin_x := maxf(6.0, roundf(slot_size.x * 0.04))
	var roster: Array = game.PROGRESSION_DATA.character_ids()
	if roster.is_empty():
		return
	var visible_slot_count := clampi(int(floor((carousel_w - arrow_size.x * 2.0 - 6.0) / (carousel_slot_size + 6.0))), 3, roster.size())
	var slot_gap: float = maxf(6.0, (carousel_w - arrow_size.x * 2.0 - slot_size.x * float(visible_slot_count)) / float(visible_slot_count + 1))
	var slot_y: float = round((carousel_area_h - slot_size.y) * 0.5)
	var arrow_y: float = round((carousel_area_h - arrow_size.y) * 0.5)

	# SCRUM-882: стрелки несут число скрытых героев («‹N» / «M›», 0 → просто
	# стрелка); размер плиты 54×42 фиксирован (seal-контракт), поэтому шрифт
	# компактный фиксированный + clip_text-страховка.
	var left_arrow := _make_button("‹")
	left_arrow.name = "HS4CarouselPrevButton"
	_set_action_button_size(left_arrow, arrow_size.x, arrow_size.y)
	left_arrow.add_theme_font_size_override("font_size", 14)
	left_arrow.clip_text = true
	left_arrow.position = Vector2(0.0, arrow_y)
	carousel.add_child(left_arrow)
	var right_arrow := _make_button("›")
	right_arrow.name = "HS4CarouselNextButton"
	_set_action_button_size(right_arrow, arrow_size.x, arrow_size.y)
	right_arrow.add_theme_font_size_override("font_size", 14)
	right_arrow.clip_text = true
	right_arrow.position = Vector2(carousel_w - arrow_size.x, arrow_y)
	carousel.add_child(right_arrow)

	if not roster.has(game.selected_character_id):
		game.selected_character_id = str(roster[0])

	var slot_buttons: Array = []
	var slot_portraits: Array = []
	var slot_labels: Array = []
	for i in range(visible_slot_count):
		var slot := Button.new()
		slot.name = "HS4CarouselSlot_%02d" % i
		slot.focus_mode = Control.FOCUS_ALL
		slot.text = ""
		slot.clip_contents = true
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		slot.position = Vector2(arrow_size.x + slot_gap + i * (slot_size.x + slot_gap), slot_y)
		slot.size = slot_size
		slot.custom_minimum_size = slot_size
		_unified_apply_row_theme(slot, 6.0)
		var slot_portrait := TextureRect.new()
		slot_portrait.name = "HS4CarouselPortrait_%02d" % i
		slot_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		slot_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot_portrait.set_anchors_preset(Control.PRESET_TOP_LEFT)
		slot_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(slot_portrait)
		var slot_label := Label.new()
		slot_label.name = "HS4CarouselLabel_%02d" % i
		slot_label.text = ""
		slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		slot_label.clip_text = true
		slot_label.position = Vector2(slot_label_margin_x, slot_size.y - slot_label_h)
		slot_label.size = Vector2(slot_size.x - slot_label_margin_x * 2.0, slot_label_h)
		slot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_label.add_theme_font_size_override("font_size", _readable_font_size(maxi(12, int(round(slot_size.y * 0.075))), 0, 16))
		slot_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.74, 0.94))
		slot_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
		slot_label.add_theme_constant_override("outline_size", 3)
		slot.add_child(slot_label)
		carousel.add_child(slot)
		slot_buttons.append(slot)
		slot_portraits.append(slot_portrait)
		slot_labels.append(slot_label)

	var state := {"offset": 0}
	var sel0: int = roster.find(game.selected_character_id)
	state["offset"] = clampi(sel0 - visible_slot_count / 2, 0, maxi(0, roster.size() - visible_slot_count))
	var position_carousel_portrait := func(slot_portrait: TextureRect, texture: Texture2D) -> void:
		var label_top := slot_size.y - slot_label_h
		var visible_bottom_y := label_top - slot_label_gap
		var visible_target := Vector2(slot_size.x * 0.94, maxf(24.0, visible_bottom_y * 0.96))
		position_alpha_cropped_texture.call(slot_portrait, texture, slot_size, visible_target, visible_bottom_y, slot_size.x * 0.5)

	var refresh_focus_graph := func(grab_default := false) -> void:
		var visible_slots: Array = []
		for slot in slot_buttons:
			var slot_button := slot as Button
			slot_button.focus_mode = Control.FOCUS_ALL
			if slot_button.visible:
				visible_slots.append(slot_button)
		var row_controls: Array = [left_arrow]
		row_controls.append_array(visible_slots)
		row_controls.append(right_arrow)
		var default_focus: Control = select_button
		if not visible_slots.is_empty():
			var selected_index: int = roster.find(game.selected_character_id)
			var visible_index: int = clampi(selected_index - int(state["offset"]), 0, visible_slots.size() - 1)
			default_focus = visible_slots[visible_index] as Control
		for i in range(row_controls.size()):
			var ctrl := row_controls[i] as Control
			var left := row_controls[posmod(i - 1, row_controls.size())] as Control
			var right := row_controls[posmod(i + 1, row_controls.size())] as Control
			ctrl.focus_neighbor_left = left.get_path()
			ctrl.focus_neighbor_right = right.get_path()
			ctrl.focus_neighbor_top = select_button.get_path()
			ctrl.focus_neighbor_bottom = ctrl.get_path()
		# SCRUM-887: статы — вертикальная колонна у правого края досье; цепочка
		# сверху вниз, вход — с «Назад», выход вниз — в правую стрелку карусели.
		var stat_chain: Array = []
		for sid in HS4_MINIMAL_BASE_STATS:
			stat_chain.append(stat_buttons[sid] as Control)
		for i in range(stat_chain.size()):
			var stat_ctrl := stat_chain[i] as Control
			var above := (back_button as Control) if i == 0 else (stat_chain[i - 1] as Control)
			var below := (right_arrow as Control) if i == stat_chain.size() - 1 else (stat_chain[i + 1] as Control)
			stat_ctrl.focus_neighbor_top = above.get_path()
			stat_ctrl.focus_neighbor_bottom = below.get_path()
			stat_ctrl.focus_neighbor_left = select_button.get_path()
			stat_ctrl.focus_neighbor_right = stat_ctrl.get_path()
		right_arrow.focus_neighbor_top = (stat_chain.back() as Control).get_path()
		back_button.focus_neighbor_left = back_button.get_path()
		back_button.focus_neighbor_right = back_button.get_path()
		back_button.focus_neighbor_top = back_button.get_path()
		back_button.focus_neighbor_bottom = (stat_chain.front() as Control).get_path()
		asc_minus.focus_neighbor_left = asc_plus.get_path()
		asc_minus.focus_neighbor_right = asc_plus.get_path()
		asc_minus.focus_neighbor_top = back_button.get_path()
		asc_minus.focus_neighbor_bottom = select_button.get_path()
		asc_plus.focus_neighbor_left = asc_minus.get_path()
		asc_plus.focus_neighbor_right = asc_minus.get_path()
		asc_plus.focus_neighbor_top = back_button.get_path()
		asc_plus.focus_neighbor_bottom = select_button.get_path()
		# SCRUM-882: CTA внизу левой колонны — сверху степпер возвышения,
		# справа вход в ряд карусели.
		select_button.focus_neighbor_left = asc_minus.get_path()
		select_button.focus_neighbor_right = left_arrow.get_path()
		select_button.focus_neighbor_top = asc_minus.get_path()
		select_button.focus_neighbor_bottom = default_focus.get_path()
		if grab_default:
			default_focus.grab_focus()

	var keep_selected_visible := func() -> void:
		var selected_index: int = roster.find(game.selected_character_id)
		if selected_index < 0:
			selected_index = 0
			game.selected_character_id = str(roster[0])
		var max_offset: int = maxi(0, roster.size() - visible_slot_count)
		if roster.size() <= visible_slot_count:
			state["offset"] = 0
			return
		var offset: int = int(state["offset"])
		if selected_index < offset:
			offset = selected_index
		elif selected_index >= offset + visible_slot_count:
			offset = selected_index - visible_slot_count + 1
		state["offset"] = clampi(offset, 0, max_offset)

	var refresh := func() -> void:
		keep_selected_visible.call()
		var cid: String = game.selected_character_id
		var config: Dictionary = game.PROGRESSION_DATA.character_config(cid)
		var stats: Dictionary = game.PROGRESSION_DATA.base_stats(cid)
		_set_hero_select_portrait_preview(portrait, cid, config, portrait_preview_state)
		position_main_portrait.call(portrait.texture)
		name_label.text = str(config.get("title", cid))
		desc_label.text = str(config.get("description", ""))
		strengths_label.text = "Сильные стороны: %s" % str(config.get("strengths", ""))
		weaknesses_label.text = "Слабые стороны: %s" % str(config.get("weaknesses", ""))
		weapon_label.text = "Оружие: %s" % _hero_weapon_names(cid)
		var identity: Dictionary = game.PROGRESSION_DATA.class_mechanic_identity(cid)
		var main_attr: String = str(game.PROGRESSION_DATA.class_main_attribute(cid))
		identity_label.text = "%s: %s" % [str(game.PROGRESSION_DATA.STAT_NAMES.get(main_attr, main_attr)), str(identity.get("summary", ""))]
		# SCRUM-887: пара главных атрибутов из данных — main_attribute + следующий
		# по приоритетам класса (русские имена статов, как в подписях полос).
		var main_attr_names := PackedStringArray()
		main_attr_names.append(str(game.PROGRESSION_DATA.STAT_NAMES.get(main_attr, main_attr)))
		for attr in game.PROGRESSION_DATA.attribute_priorities(cid):
			if str(attr) != main_attr:
				main_attr_names.append(str(game.PROGRESSION_DATA.STAT_NAMES.get(str(attr), str(attr))))
				break
		main_attrs_label.text = "Основные атрибуты: %s" % ", ".join(main_attr_names)
		for sid in HS4_MINIMAL_BASE_STATS:
			var sval := float(stats.get(sid, 0.0))
			var stat_button := stat_buttons[sid] as Button
			stat_button.text = ""
			stat_button.tooltip_text = _hs4_stat_tooltip(sid, sval, cid)
			var stat_fill := stat_fill_nodes[sid] as ColorRect
			stat_fill.anchor_right = clampf(sval / 10.0, 0.04, 1.0)
			stat_fill.color = _hs4_stat_fill_color(sid)
			var stat_value := stat_value_labels[sid] as Label
			stat_value.text = str(int(round(sval)))
		var guidance_groups := _hs4_attribute_guidance_groups(cid)
		for relevance in HeroSelectConstants.HERO_BUILD_RELEVANCE_ORDER:
			var guide_label := guidance_labels[relevance] as Label
			var title := str(HeroSelectConstants.HERO_BUILD_RELEVANCE_TITLES.get(relevance, relevance))
			var names: Array = guidance_groups.get(relevance, [])
			guide_label.text = "%s: %s" % [title, _hs4_join_guidance_names(names, 8 if relevance != "optional" else 6)]
			var tooltip_names := PackedStringArray()
			for name in names:
				tooltip_names.append(str(name))
			guide_label.tooltip_text = "%s\n%s" % [title, ", ".join(tooltip_names)]
		var maxl: int = game.ascension_selectable_max(cid)
		game.selected_ascension_level = clampi(game.selected_ascension_level, 0, maxl)
		asc_label.text = "Возвышение"
		asc_stepper_label.text = "%d / %d" % [game.selected_ascension_level, maxl]
		asc_mods.text = str(game.PROGRESSION_DATA.ascension_level_change_line(game.selected_ascension_level))
		var ascension_tooltip := _hs4_ascension_text(game.selected_ascension_level)
		asc_mods.tooltip_text = ascension_tooltip
		ascension_panel.tooltip_text = ascension_tooltip
		asc_minus.disabled = game.selected_ascension_level <= 0
		asc_plus.disabled = game.selected_ascension_level >= maxl
		var off: int = int(state["offset"])
		for i in range(visible_slot_count):
			var idx: int = off + i
			var slot: Button = slot_buttons[i]
			var slot_portrait := slot_portraits[i] as TextureRect
			var slot_label := slot_labels[i] as Label
			if idx < roster.size():
				var rid: String = str(roster[idx])
				var rconf: Dictionary = game.PROGRESSION_DATA.character_config(rid)
				var slot_texture := game._cached_texture(str(rconf.get("sprite_path", rconf.get("sprite", "")))) as Texture2D
				slot_portrait.texture = slot_texture
				position_carousel_portrait.call(slot_portrait, slot_texture)
				slot.visible = true
				var slot_title := str(rconf.get("title", rid))
				slot.tooltip_text = slot_title
				slot_label.text = slot_title
				_unified_apply_row_theme(slot, 6.0, rid == cid)
				slot_portrait.modulate = Color(1.0, 1.0, 1.0, 1.0) if rid == cid else Color(0.58, 0.60, 0.68, 0.78)
				slot_label.modulate = Color(1.0, 0.96, 0.80, 1.0) if rid == cid else Color(0.66, 0.68, 0.74, 0.84)
			else:
				slot.visible = false
				slot_portrait.texture = null
				slot_label.text = ""
		# SCRUM-882: явный счётчик карусели — «N–M из K» + число скрытых на стрелках.
		var roster_total: int = roster.size()
		var window_first: int = mini(off + 1, roster_total)
		var window_last: int = mini(off + visible_slot_count, roster_total)
		carousel_counter_label.text = "%d–%d из %d" % [window_first, window_last, roster_total]
		carousel_counter.size = carousel_counter.get_combined_minimum_size()
		carousel_counter.position = Vector2(
			content_rect.end.x - carousel_counter.size.x,
			carousel_y - 4.0 - carousel_counter.size.y)
		var hidden_left: int = off
		var hidden_right: int = maxi(0, roster_total - off - visible_slot_count)
		left_arrow.text = "‹" if hidden_left <= 0 else "‹%d" % hidden_left
		right_arrow.text = "›" if hidden_right <= 0 else "%d›" % hidden_right
		refresh_focus_graph.call(false)

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

	for i in range(visible_slot_count):
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
	refresh_focus_graph.call(true)
	# Полая рама 9-slice поверх всего контента — добавляется последней.
	_unified_add_frame(root, "HeroSelect")

func _show_character_select() -> void:
	game.clear_run_autosave()
	game.run_player_snapshot.clear()
	game.current_act = 1
	game.route_stage = 0
	game.route_selected_indices.clear()
	game.used_event_ids.clear()
	game.current_event_definition.clear()
	game.pending_event_combat.clear()
	game.run_used_shop = false
	game.shop_reentry_pending = false
	game.shop_reentry_route_stage = -1
	game.shop_reentry_branch_index = -1
	game.route_nodes = game.route._generate_route()
	_clear_current_shop_stock()
	game._clear_ui()

	# Экран выбора героя строит v4-билдер (SCRUM-470). Мёртвая v3-вёрстка удалена (SCRUM-492).
	_build_character_select_v4()


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
	# SCRUM-883: транзиентный оверлей поверх боя — компактный чип Атласа вместо
	# тяжёлой vbn_frame @2K-рамы (просто и торжественно; дим сохранён, растяжек нет).
	var banner_size := VICTORY_BANNER_CHIP_SIZE
	frame.offset_left = -banner_size.x * 0.5
	frame.offset_right = banner_size.x * 0.5
	frame.offset_top = VICTORY_BANNER_CHIP_TOP
	frame.offset_bottom = VICTORY_BANNER_CHIP_TOP + banner_size.y
	frame.pivot_offset = banner_size * 0.5
	frame.scale = Vector2(0.92, 0.92)
	frame.modulate.a = 0.0
	frame.add_theme_stylebox_override("panel", _atlas_chip_style(0.92, VICTORY_BANNER_CHIP_PAD))
	frame.set_meta("victory_banner_style", "atlas_chip")
	click_catcher.add_child(frame)

	var label := Label.new()
	label.name = "VictoryBannerLabel"
	label.text = "ПОБЕДА"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", _readable_font_size(90))
	label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
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
	_prepare_global_tooltips(root)
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
	# SCRUM-883: высокая панель докачки — чип Атласа (тёмная кожа, латунный кант)
	# вместо attr_panel @2K-рамки; дим-фон поверх меты сохранён.
	panel.add_theme_stylebox_override("panel", _atlas_chip_style(0.94, 18.0))
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
	title.add_theme_font_size_override("font_size", _readable_font_size(34))
	title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	box.add_child(title)

	var money_label := Label.new()
	money_label.name = "AttributeShopMoney"
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	money_label.add_theme_font_size_override("font_size", _readable_font_size(18))
	money_label.add_theme_color_override("font_color", Color(0.94, 0.80, 0.46, 1.0))
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
		# SCRUM-883: карточка опции — чип-ряд Атласа из общей фабрики (единый стиль
		# с экономикой/событием); отдельное переодевание в evt_card снято.
		offer_button.disabled = money < buy_cost
		# SCRUM-413: недоступные (не хватает золота) карточки визуально затемнены —
		# явно видно, что купить нельзя, а не «активная, но не реагирует».
		offer_button.modulate = Color(0.5, 0.5, 0.55, 0.85) if offer_button.disabled else Color(1.0, 1.0, 1.0, 1.0)
		# SCRUM-525/SCRUM-851: тултип краткий и по делу — на что влияет атрибут и живой
		# предпросмотр производных при +1; интерпретация класса уже написана на карточке.
		offer_button.tooltip_text = "%s +1" % stat_title
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

	# SCRUM-813: докач-опции + Reroll/Skip проходимы с геймпада/стрелок; старт — первая
	# доступная опция (иначе Reroll/Skip). follow_focus у скролла прокручивает к выбранной.
	var attr_skip_button := root.find_child("AttributeSkipButton", true, false) as Button
	var attr_focus: Array = []
	for offer_child in offers_box.get_children():
		if offer_child is Button:
			attr_focus.append(offer_child)
	var attr_secondary: Array = []
	if reroll_button != null:
		attr_secondary.append(reroll_button)
	if attr_skip_button != null:
		attr_secondary.append(attr_skip_button)
	_wire_run_ui_focus(attr_focus, true, attr_secondary, null)


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
	fab.add_theme_font_size_override("font_size", _readable_font_size(30))
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


func _show_atlas_screen() -> void:
	# SCRUM-827: экран «Атлас героев» (Мета 4.0, дизайн §7 + мокап meta40_atlas_mockup).
	# Две вкладки (Созвездие/Гильдия), созвездие класса ЦЕЛИКОМ без пан/зума на небе
	# bg_sky, лента 17 медальонов-гербов слева, панель узла справа, церемонии покупки
	# и рассеивания тумана. Ядро — SCRUM-828 (constellation_nodes/allocate_node/
	# active_keystone/hidden_star_progress); арт — кит SCRUM-826/832 (meta40/).
	game._clear_ui()
	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var s := _atlas_ui_scale()
	var class_id := str(game.selected_character_id)
	if not game.META_PROGRESSION.CLASS_ENTRY_NODES.has(class_id):
		class_id = "berserk"
	_atlas = {
		"tab": "constellation",
		"class_id": class_id,
		"selected": "",
		"status": {},
		"edges": [],
		"edge_flash": {},
		"node_buttons": {},
		"node_centers": {},
		"npos": {},
		"fog_tweens": {},
		"medallions": [],
	}

	var root := Control.new()
	root.name = "AtlasScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	game.ui_layer.add_child(root)
	_prepare_global_tooltips(root)
	_atlas["root"] = root

	# Ночное небо — фулскрин-ассет кита, без общего фона/шейда.
	var sky := TextureRect.new()
	sky.name = "AtlasSky"
	sky.texture = game._cached_texture(META40_BG_SKY_PATH)
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sky)

	# Контент строго в пустой зоне рамы (safe-area правило проекта): маргины
	# повторяют texture-margins рамы (band + угловые вырезы).
	var vp: Vector2 = game.get_viewport().get_visible_rect().size
	var frame_margins := _scaled_frame_margins_xy(
		ATLAS_FRAME_SOURCE_SIZE, vp,
		Vector4(ATLAS_FRAME_SOURCE_MARGIN, ATLAS_FRAME_SOURCE_MARGIN, ATLAS_FRAME_SOURCE_MARGIN, ATLAS_FRAME_SOURCE_MARGIN))
	var safe := MarginContainer.new()
	safe.name = "AtlasSafeArea"
	safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", int(frame_margins.x))
	safe.add_theme_constant_override("margin_top", int(frame_margins.y))
	safe.add_theme_constant_override("margin_right", int(frame_margins.z))
	safe.add_theme_constant_override("margin_bottom", int(frame_margins.w))
	root.add_child(safe)

	var layout := VBoxContainer.new()
	layout.name = "AtlasLayout"
	layout.add_theme_constant_override("separation", int(roundf(10.0 * s)))
	safe.add_child(layout)

	# --- Шапка (фидбек пользователя 2026-07-08): «Созвездие» слева + рядом счётчик
	# свободных эмблем класса; «Гильдия» + звёздная пыль по центру (между двумя
	# expand-спейсерами); «Назад» справа. Табы и назад — единые плиты кита 260×h,
	# как back-кнопки остальных экранов (однообразие возврата и кнопок).
	var header := HBoxContainer.new()
	header.name = "AtlasHeader"
	header.add_theme_constant_override("separation", int(roundf(12.0 * s)))
	layout.add_child(header)
	var atlas_action_h := _atlas_action_button_height()
	var tab_constellation := _make_button("Созвездие")
	tab_constellation.name = "AtlasTabConstellation"
	_set_action_button_size(tab_constellation, 260.0, atlas_action_h)
	tab_constellation.pressed.connect(Callable(self, "_atlas_switch_tab").bind("constellation"))
	header.add_child(tab_constellation)
	_atlas["tab_constellation"] = tab_constellation
	var emblem_badge := _atlas_make_currency_chip("AtlasEmblemBadge", META40_CURRENCY_EMBLEM_PATH, "AtlasEmblemsLabel", s)
	header.add_child(emblem_badge)
	_atlas["emblem_badge"] = emblem_badge
	_atlas["emblems_label"] = emblem_badge.find_child("AtlasEmblemsLabel", true, false)
	var header_spacer := Control.new()
	header_spacer.name = "AtlasHeaderSpacer"
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	var tab_guild := _make_button("Гильдия")
	tab_guild.name = "AtlasTabGuild"
	_set_action_button_size(tab_guild, 260.0, atlas_action_h)
	tab_guild.pressed.connect(Callable(self, "_atlas_switch_tab").bind("guild"))
	header.add_child(tab_guild)
	_atlas["tab_guild"] = tab_guild
	var stardust_badge := _atlas_make_currency_chip("AtlasStardustBadge", META40_CURRENCY_STARDUST_PATH, "AtlasStardustLabel", s)
	header.add_child(stardust_badge)
	_atlas["stardust_label"] = stardust_badge.find_child("AtlasStardustLabel", true, false)
	var header_spacer_right := Control.new()
	header_spacer_right.name = "AtlasHeaderSpacerRight"
	header_spacer_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer_right)
	var back_button := _make_button("Назад")
	back_button.name = "AtlasBackButton"
	_set_action_button_size(back_button, 260.0, atlas_action_h)
	back_button.pressed.connect(_show_main_menu)
	header.add_child(back_button)
	_atlas["back_button"] = back_button
	game.ui_escape_action = _show_main_menu

	# --- Тело: лента классов | небо-созвездие | панель узла ---
	var body := HBoxContainer.new()
	body.name = "AtlasBody"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", int(roundf(14.0 * s)))
	layout.add_child(body)

	# Фидбек 2026-07-08 (SCRUM-884): все 17 героев видимы разом — сетка в 2
	# столбца; размер медальона считается от высоты тела (9 рядов), скролл
	# остаётся только страховкой для карликовых окон (пол 44px).
	var strip_rows := ceili(float(game.META_PROGRESSION.constellation_class_ids().size()) / 2.0)
	var strip_sep := int(roundf(6.0 * s))
	var vp_h: float = game.get_viewport().get_visible_rect().size.y
	var medallion_px := roundf(clampf(vp_h * 0.55 / float(maxi(strip_rows, 1)) - float(strip_sep), 44.0, 112.0))
	var strip := ScrollContainer.new()
	strip.name = "AtlasClassStrip"
	strip.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	strip.custom_minimum_size = Vector2(medallion_px * 2.0 + float(strip_sep) + roundf(14.0 * s), 0.0)
	strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(strip)
	_atlas["strip"] = strip
	var strip_box := GridContainer.new()
	strip_box.name = "AtlasClassStripBox"
	strip_box.columns = 2
	strip_box.add_theme_constant_override("h_separation", strip_sep)
	strip_box.add_theme_constant_override("v_separation", strip_sep)
	strip.add_child(strip_box)
	for raw_cid in game.META_PROGRESSION.constellation_class_ids():
		var cid := str(raw_cid)
		var cfg: Dictionary = game.PROGRESSION_DATA.character_config(cid)
		var mb := TextureButton.new()
		mb.name = "AtlasMedallion_%s" % cid
		mb.texture_normal = game._cached_texture(META40_UI_DIR + "crest_%s.png" % cid)
		mb.ignore_texture_size = true
		mb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		mb.custom_minimum_size = Vector2(medallion_px, medallion_px)
		mb.focus_mode = Control.FOCUS_ALL
		mb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mb.tooltip_text = str(cfg.get("title", cid))
		mb.set_meta("class_id", cid)
		mb.pressed.connect(Callable(self, "_atlas_select_class").bind(cid))
		strip_box.add_child(mb)
		(_atlas["medallions"] as Array).append(mb)
		var prog_chip := PanelContainer.new()
		prog_chip.name = "MedallionProgressChip"
		prog_chip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		var chip_h := maxf(16.0, roundf(20.0 * s))
		prog_chip.offset_top = -chip_h
		prog_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		prog_chip.add_theme_stylebox_override("panel", _atlas_translucent_style(0.55, 6.0))
		mb.add_child(prog_chip)
		var prog := Label.new()
		prog.name = "AtlasMedallionProgress_%s" % cid
		prog.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prog.add_theme_font_size_override("font_size", _readable_font_size(11))
		prog.add_theme_color_override("font_color", Color(0.93, 0.89, 0.74, 0.96))
		prog_chip.add_child(prog)
		var badge := PanelContainer.new()
		badge.name = "AtlasMedallionBadge_%s" % cid
		badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		var badge_px := maxf(20.0, roundf(30.0 * s))
		badge.offset_left = -badge_px
		badge.offset_bottom = badge_px
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_theme_stylebox_override("panel", _atlas_unspent_badge_style(badge_px * 0.5))
		badge.visible = false
		mb.add_child(badge)
		var badge_label := Label.new()
		badge_label.name = "BadgeCount"
		badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge_label.add_theme_font_size_override("font_size", _readable_font_size(11))
		badge_label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.86, 1.0))
		badge.add_child(badge_label)

	var canvas := Control.new()
	canvas.name = "AtlasCanvas"
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.clip_contents = true
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.gui_input.connect(Callable(self, "_atlas_canvas_input"))
	canvas.resized.connect(Callable(self, "_atlas_schedule_layout_passes"))
	body.add_child(canvas)
	_atlas["canvas"] = canvas
	var edge_layer := Control.new()
	edge_layer.name = "AtlasEdges"
	edge_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	edge_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge_layer.draw.connect(Callable(self, "_atlas_draw_edges"))
	canvas.add_child(edge_layer)
	_atlas["edge_layer"] = edge_layer

	# --- Панель узла (титул/тип/описание с числами/цена/действия) ---
	var panel := PanelContainer.new()
	panel.name = "AtlasNodePanel"
	panel.custom_minimum_size = Vector2(roundf(clampf(452.0 * s, 272.0, 452.0)), 0.0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _atlas_chip_style(0.90, roundf(16.0 * s)))
	body.add_child(panel)
	var panel_box := VBoxContainer.new()
	panel_box.name = "AtlasNodePanelBox"
	panel_box.add_theme_constant_override("separation", int(roundf(8.0 * s)))
	panel.add_child(panel_box)
	var kind_label := Label.new()
	kind_label.name = "AtlasNodeKind"
	kind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kind_label.add_theme_font_size_override("font_size", _readable_font_size(13))
	kind_label.add_theme_color_override("font_color", Color(0.78, 0.66, 0.44, 1.0))
	panel_box.add_child(kind_label)
	_atlas["panel_kind"] = kind_label
	var icon_center := CenterContainer.new()
	icon_center.name = "AtlasNodeIconCenter"
	panel_box.add_child(icon_center)
	var node_icon := TextureRect.new()
	node_icon.name = "AtlasNodeIcon"
	node_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_px := roundf(clampf(104.0 * s, 56.0, 104.0))
	node_icon.custom_minimum_size = Vector2(icon_px, icon_px)
	icon_center.add_child(node_icon)
	_atlas["panel_icon"] = node_icon
	var title_label := Label.new()
	title_label.name = "AtlasNodeTitle"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", _readable_font_size(22))
	title_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	panel_box.add_child(title_label)
	_atlas["panel_title"] = title_label
	var info_scroll := ScrollContainer.new()
	info_scroll.name = "AtlasNodeScroll"
	info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	info_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_box.add_child(info_scroll)
	var info_box := VBoxContainer.new()
	info_box.name = "AtlasNodeInfoBox"
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_theme_constant_override("separation", int(roundf(8.0 * s)))
	info_scroll.add_child(info_box)
	var desc_label := Label.new()
	desc_label.name = "AtlasNodeDesc"
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.add_theme_font_size_override("font_size", _readable_font_size(15))
	desc_label.add_theme_color_override("font_color", Color(0.88, 0.91, 0.95, 0.96))
	info_box.add_child(desc_label)
	_atlas["panel_desc"] = desc_label
	var condition_label := Label.new()
	condition_label.name = "AtlasNodeCondition"
	condition_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	condition_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	condition_label.add_theme_font_size_override("font_size", _readable_font_size(13))
	condition_label.add_theme_color_override("font_color", Color(0.72, 0.84, 1.0, 0.95))
	condition_label.visible = false
	info_box.add_child(condition_label)
	_atlas["panel_condition"] = condition_label
	var lore_label := Label.new()
	lore_label.name = "AtlasNodeLore"
	lore_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lore_label.add_theme_font_size_override("font_size", _readable_font_size(12))
	lore_label.add_theme_color_override("font_color", Color(0.72, 0.74, 0.82, 0.85))
	lore_label.visible = false
	info_box.add_child(lore_label)
	_atlas["panel_lore"] = lore_label
	var price_row := HBoxContainer.new()
	price_row.name = "AtlasNodePriceRow"
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	price_row.add_theme_constant_override("separation", int(roundf(8.0 * s)))
	panel_box.add_child(price_row)
	_atlas["panel_price_row"] = price_row
	var price_label := Label.new()
	price_label.name = "AtlasNodePriceLabel"
	price_label.add_theme_font_size_override("font_size", _readable_font_size(17))
	price_label.add_theme_color_override("font_color", Color(0.94, 0.80, 0.46, 1.0))
	price_row.add_child(price_label)
	_atlas["panel_price_label"] = price_label
	var price_icon := TextureRect.new()
	price_icon.name = "AtlasNodePriceIcon"
	price_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	price_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var price_icon_px := maxf(18.0, roundf(28.0 * s))
	price_icon.custom_minimum_size = Vector2(price_icon_px, price_icon_px)
	price_row.add_child(price_icon)
	_atlas["panel_price_icon"] = price_icon
	var buy_button := _make_button("Вложить эмблему")
	buy_button.name = "AtlasBuyButton"
	_set_action_button_size(buy_button, 360.0, 88.0)
	buy_button.pressed.connect(Callable(self, "_atlas_buy_selected"))
	panel_box.add_child(buy_button)
	_atlas["buy_button"] = buy_button
	var keystone_toggle := _make_button("Сделать активной")
	keystone_toggle.name = "AtlasKeystoneToggle"
	_set_action_button_size(keystone_toggle, 360.0, 88.0)
	keystone_toggle.pressed.connect(Callable(self, "_atlas_toggle_keystone"))
	keystone_toggle.visible = false
	panel_box.add_child(keystone_toggle)
	_atlas["keystone_toggle"] = keystone_toggle
	var progress_label := Label.new()
	progress_label.name = "AtlasProgressLabel"
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress_label.add_theme_font_size_override("font_size", _readable_font_size(14))
	progress_label.add_theme_color_override("font_color", Color(0.90, 0.86, 0.70, 0.95))
	panel_box.add_child(progress_label)
	_atlas["panel_progress"] = progress_label
	var hidden_hint := Label.new()
	hidden_hint.name = "AtlasHiddenHint"
	hidden_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hidden_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hidden_hint.add_theme_font_size_override("font_size", _readable_font_size(12))
	hidden_hint.add_theme_color_override("font_color", Color(0.72, 0.82, 0.98, 0.88))
	hidden_hint.visible = false
	panel_box.add_child(hidden_hint)
	_atlas["panel_hidden_hint"] = hidden_hint

	# --- Низ: «Респек — бесплатно» + легенда состояний ---
	var footer := HBoxContainer.new()
	footer.name = "AtlasFooter"
	footer.add_theme_constant_override("separation", int(roundf(14.0 * s)))
	layout.add_child(footer)
	var respec_button := _make_button("Респек — бесплатно")
	respec_button.name = "AtlasRespecButton"
	_set_action_button_size(respec_button, 330.0, atlas_action_h)
	respec_button.pressed.connect(Callable(self, "_atlas_respec_prompt"))
	footer.add_child(respec_button)
	_atlas["respec_button"] = respec_button
	var footer_spacer := Control.new()
	footer_spacer.name = "AtlasFooterSpacer"
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_spacer)
	var legend := HBoxContainer.new()
	legend.name = "AtlasLegend"
	legend.add_theme_constant_override("separation", int(roundf(16.0 * s)))
	legend.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(legend)
	_atlas_add_legend_item(legend, META40_STAR_ALLOC_PATH, "куплено", s)
	_atlas_add_legend_item(legend, str(META40_SOCKET_TEXTURES["minor"]), "доступно", s)
	_atlas_add_legend_item(legend, str(META40_SOCKET_TEXTURES["keystone"]), "ключевая", s)
	_atlas_add_legend_item(legend, str(META40_SOCKET_TEXTURES["hidden"]), "скрытая", s)

	# Полая орнаментная рама кита ПОВЕРХ контента (клики сквозь; nearest — чтобы
	# key-цвет прозрачной середины не подмешивался фильтрацией).
	var frame := Panel.new()
	frame.name = "AtlasFrame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override("panel", _atlas_frame_style(frame_margins))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(frame)

	# --- Подтверждение респека (поверх рамы) ---
	var respec_popup := PanelContainer.new()
	respec_popup.name = "AtlasRespecPopup"
	respec_popup.visible = false
	respec_popup.custom_minimum_size = Vector2(roundf(clampf(560.0 * s, 380.0, 560.0)), 0.0)
	respec_popup.set_anchors_preset(Control.PRESET_CENTER)
	respec_popup.add_theme_stylebox_override("panel", _atlas_chip_style(0.97, roundf(20.0 * s)))
	respec_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(respec_popup)
	_atlas["respec_popup"] = respec_popup
	var respec_box := VBoxContainer.new()
	respec_box.add_theme_constant_override("separation", int(roundf(14.0 * s)))
	respec_popup.add_child(respec_box)
	var respec_text := Label.new()
	respec_text.name = "AtlasRespecPopupBody"
	respec_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	respec_text.add_theme_font_size_override("font_size", _readable_font_size(16))
	respec_text.add_theme_color_override("font_color", Color(0.92, 0.94, 0.88, 0.96))
	respec_box.add_child(respec_text)
	_atlas["respec_text"] = respec_text
	var respec_actions := HBoxContainer.new()
	respec_actions.alignment = BoxContainer.ALIGNMENT_END
	respec_actions.add_theme_constant_override("separation", int(roundf(14.0 * s)))
	respec_box.add_child(respec_actions)
	var respec_cancel := _make_button("Отмена")
	respec_cancel.name = "AtlasRespecCancelButton"
	_set_action_button_size(respec_cancel, 200.0, 84.0)
	respec_cancel.pressed.connect(Callable(self, "_atlas_respec_cancel"))
	respec_actions.add_child(respec_cancel)
	var respec_confirm := _make_button("Сбросить")
	respec_confirm.name = "AtlasRespecConfirmButton"
	_set_action_button_size(respec_confirm, 200.0, 84.0)
	respec_confirm.pressed.connect(Callable(self, "_atlas_respec_confirm"))
	respec_actions.add_child(respec_confirm)

	_ensure_run_ui_gamepad_bindings()
	_atlas_apply_tab_state()
	_atlas_build_canvas()
	_atlas_refresh()
	_atlas_wire_focus()


# Масштаб UI Атласа: min-ось от дизайн-окна 2560×1440 (ассеты кита нарисованы
# ровно под слоты этого окна).
func _atlas_ui_scale() -> float:
	var vp := Vector2(2560.0, 1440.0)
	if game != null and game.get_viewport() != null:
		vp = game.get_viewport().get_visible_rect().size
	return minf(vp.x / 2560.0, vp.y / 1440.0)


func _atlas_socket_scale() -> float:
	var vp := Vector2(2560.0, 1440.0)
	if game != null and game.get_viewport() != null:
		vp = game.get_viewport().get_visible_rect().size
	var compact := clampf((vp.y - 720.0) / 720.0, 0.0, 1.0)
	return _atlas_ui_scale() * lerpf(0.80, 1.0, compact)


func _atlas_action_button_height() -> float:
	var vp_h := 1440.0
	if game != null and game.get_viewport() != null:
		vp_h = game.get_viewport().get_visible_rect().size.y
	if vp_h < 760.0:
		return 72.0
	if vp_h < 1000.0:
		return 88.0
	return STANDARD_ACTION_BUTTON_HEIGHT


# Полая рама Атласа: 9-slice frame_border с draw_center=false (середина ассета —
# key-прозрачность). Margins масштабируются от source→display (паттерн SCRUM-486).
func _atlas_frame_style(margins: Vector4) -> StyleBox:
	var texture: Texture2D = game._cached_texture(META40_FRAME_BORDER_PATH)
	if texture == null:
		return _atlas_chip_style(0.0, 0.0)
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = margins.x
	style.texture_margin_top = margins.y
	style.texture_margin_right = margins.z
	style.texture_margin_bottom = margins.w
	style.draw_center = false
	return style


# Тёмная кожа + латунный кант (курс SCRUM-806/809, без ярко-жёлтых рамок).
func _atlas_chip_style(alpha: float, pad: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.085, 0.070, 0.055, alpha)
	style.border_color = Color(0.52, 0.41, 0.24, 0.90)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = pad * 1.4
	style.content_margin_right = pad * 1.4
	style.content_margin_top = pad
	style.content_margin_bottom = pad
	return style


func _atlas_translucent_style(alpha: float, radius: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.03, 0.05, alpha)
	style.set_corner_radius_all(int(radius))
	return style


func _atlas_unspent_badge_style(radius: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.56, 0.14, 0.12, 0.95)
	style.border_color = Color(0.78, 0.56, 0.30, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(int(radius))
	return style


func _atlas_make_currency_chip(chip_name: String, icon_path: String, label_name: String, s: float) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.name = chip_name
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_theme_stylebox_override("panel", _atlas_chip_style(0.86, roundf(10.0 * s)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(roundf(8.0 * s)))
	chip.add_child(row)
	var icon := TextureRect.new()
	icon.name = "%sIcon" % chip_name
	icon.texture = game._cached_texture(icon_path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_px := maxf(20.0, roundf(30.0 * s))
	icon.custom_minimum_size = Vector2(icon_px, icon_px)
	row.add_child(icon)
	var label := Label.new()
	label.name = label_name
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", _readable_font_size(16))
	label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.74, 1.0))
	row.add_child(label)
	return chip


func _atlas_add_legend_item(legend: HBoxContainer, icon_path: String, text: String, s: float) -> void:
	var item := HBoxContainer.new()
	item.name = "AtlasLegendItem_%s" % text
	item.add_theme_constant_override("separation", int(roundf(6.0 * s)))
	legend.add_child(item)
	var icon := TextureRect.new()
	icon.texture = game._cached_texture(icon_path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_px := maxf(16.0, roundf(26.0 * s))
	icon.custom_minimum_size = Vector2(icon_px, icon_px)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	item.add_child(icon)
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", _readable_font_size(13))
	label.add_theme_color_override("font_color", Color(0.86, 0.88, 0.94, 0.92))
	item.add_child(label)


# --- SCRUM-879: атлас-стиль для остальных экранов --------------------------
# Слои как у «Атласа героев»: фон COVERED (без растяжки осей, fallback bg_sky),
# контент ТОЛЬКО в safe-зоне рамы, полая рама 9-slice ПОВЕРХ контента
# (_unified_add_frame звать ПОСЛЕДНИМ). Панели — _atlas_chip_style.

func _unified_add_background(root: Control, screen_id: String, shade_alpha := 0.0) -> void:
	var path := str(ATLAS_STYLE_BG_PATHS.get(screen_id, ""))
	if path == "" or not ResourceLoader.exists(path):
		path = META40_BG_SKY_PATH
	var background := TextureRect.new()
	background.name = "UnifiedBackground_%s" % screen_id
	background.texture = game._cached_texture(path)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	if shade_alpha > 0.0:
		var shade := ColorRect.new()
		shade.name = "UnifiedBackgroundShade"
		shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		shade.color = Color(0.0, 0.0, 0.0, shade_alpha)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(shade)


func _unified_safe_margins() -> Vector4:
	var vp: Vector2 = game.get_viewport().get_visible_rect().size
	return _scaled_frame_margins_xy(
		ATLAS_FRAME_SOURCE_SIZE, vp,
		Vector4(ATLAS_FRAME_SOURCE_MARGIN, ATLAS_FRAME_SOURCE_MARGIN, ATLAS_FRAME_SOURCE_MARGIN, ATLAS_FRAME_SOURCE_MARGIN))


func _unified_make_safe_area(root: Control, prefix: String) -> MarginContainer:
	var margins := _unified_safe_margins()
	var safe := MarginContainer.new()
	safe.name = "%sSafeArea" % prefix
	safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", int(margins.x))
	safe.add_theme_constant_override("margin_top", int(margins.y))
	safe.add_theme_constant_override("margin_right", int(margins.z))
	safe.add_theme_constant_override("margin_bottom", int(margins.w))
	root.add_child(safe)
	return safe


func _unified_add_frame(root: Control, prefix: String) -> Panel:
	var frame := Panel.new()
	frame.name = "%sFrame" % prefix
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override("panel", _atlas_frame_style(_unified_safe_margins()))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(frame)
	return frame


# Кожаный чип-заголовок экрана: эмблема PixelLab + титул золотом (шапка как
# валютные чипы Атласа).
func _unified_header_chip(prefix: String, title: String, screen_id: String, s: float) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.name = "%sTitleChip" % prefix
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_theme_stylebox_override("panel", _atlas_chip_style(0.86, roundf(10.0 * s)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(roundf(10.0 * s)))
	chip.add_child(row)
	var emblem_path := str(ATLAS_STYLE_EMBLEM_PATHS.get(screen_id, ""))
	if emblem_path != "" and ResourceLoader.exists(emblem_path):
		var icon := TextureRect.new()
		icon.name = "%sTitleEmblem" % prefix
		icon.texture = game._cached_texture(emblem_path)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var icon_px := maxf(26.0, roundf(44.0 * s))
		icon.custom_minimum_size = Vector2(icon_px, icon_px)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
	var label := Label.new()
	label.name = "%sTitleLabel" % prefix
	label.text = title
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", _readable_font_size(22))
	label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	row.add_child(label)
	return chip


# Тема «кожаного ряда» для списочных Button-контролов (карточки кодекса,
# слоты карусели, строки статов): это НЕ действие-кнопки глобального кита,
# а контентные ряды в языке чипов Атласа.
func _unified_apply_row_theme(button: Button, pad := 10.0, selected := false) -> void:
	var normal := _atlas_chip_style(0.72, pad)
	var hover := _atlas_chip_style(0.82, pad)
	hover.border_color = Color(0.72, 0.58, 0.34, 0.95)
	var pressed := _atlas_chip_style(0.92, pad)
	pressed.bg_color = Color(0.11, 0.09, 0.07, 0.94)
	var focus := _atlas_chip_style(0.84, pad)
	focus.border_color = Color(0.93, 0.77, 0.40, 0.95)
	if selected:
		normal = _atlas_chip_style(0.88, pad)
		normal.border_color = Color(0.93, 0.77, 0.40, 0.95)
		normal.set_border_width_all(3)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("disabled", _atlas_translucent_style(0.45, 10.0))
	button.add_theme_color_override("font_color", Color(0.90, 0.86, 0.72, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.86, 1.0, 0.96, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.46, 0.49, 0.54, 1.0))


# Орнамент-разделитель PixelLab фикс-высоты (KEEP_ASPECT_CENTERED — без растяжки).
func _unified_add_divider(parent: Control, s: float, name_suffix := "") -> void:
	if not ResourceLoader.exists(ATLAS_STYLE_DIVIDER_PATH):
		return
	var divider := TextureRect.new()
	divider.name = "UnifiedDivider%s" % name_suffix
	divider.texture = game._cached_texture(ATLAS_STYLE_DIVIDER_PATH)
	divider.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	divider.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	divider.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	divider.custom_minimum_size = Vector2(0.0, maxf(18.0, roundf(28.0 * s)))
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(divider)


# Узлы текущего графа: созвездие выбранного класса либо Атлас гильдии.
func _atlas_graph_nodes() -> Array:
	if str(_atlas.get("tab", "constellation")) == "guild":
		return game.META_PROGRESSION.atlas_nodes()
	return game.META_PROGRESSION.constellation_nodes(str(_atlas.get("class_id", "berserk")))


func _atlas_core_node_id() -> String:
	if str(_atlas.get("tab", "constellation")) == "constellation":
		return str(game.META_PROGRESSION.CLASS_ENTRY_NODES.get(str(_atlas.get("class_id", "")), ""))
	for node in game.META_PROGRESSION.atlas_nodes():
		if str((node as Dictionary).get("role", "")) == "core":
			return str((node as Dictionary)["id"])
	return ""


# Пересборка холста под текущую вкладку/класс: кнопки-сокеты + оверлеи состояний.
func _atlas_build_canvas() -> void:
	var canvas: Control = _atlas.get("canvas")
	if canvas == null or not is_instance_valid(canvas):
		return
	for nb in (_atlas.get("node_buttons", {}) as Dictionary).values():
		if nb is Node and is_instance_valid(nb):
			(nb as Node).queue_free()
	_atlas["node_buttons"] = {}
	_atlas["fog_tweens"] = {}
	_atlas["edge_flash"] = {}
	var socket_scale := _atlas_socket_scale()
	var nodes := _atlas_graph_nodes()
	var npos_map := {}
	for node in nodes:
		npos_map[str((node as Dictionary)["id"])] = (node as Dictionary).get("npos", Vector2(0.5, 0.5))
	_atlas["npos"] = npos_map
	var edges := []
	for node in nodes:
		var a_id := str((node as Dictionary)["id"])
		for raw_neighbor in (node as Dictionary).get("adj", []):
			var b_id := str(raw_neighbor)
			if a_id < b_id and npos_map.has(b_id):
				edges.append([a_id, b_id])
	_atlas["edges"] = edges
	for node in nodes:
		var node_data: Dictionary = node
		var node_id := str(node_data["id"])
		var role := str(node_data.get("role", "minor"))
		var affinity := str(node_data.get("class_affinity", ""))
		var nb := TextureButton.new()
		nb.name = "AtlasNode_%s" % node_id
		var base_path := str(META40_SOCKET_TEXTURES.get(role, META40_SOCKET_TEXTURES["minor"]))
		if role == "core" and affinity != "":
			base_path = META40_UI_DIR + "crest_%s.png" % affinity
		nb.texture_normal = game._cached_texture(base_path)
		nb.ignore_texture_size = true
		nb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		var disp := maxf(24.0, roundf(float(ATLAS_SOCKET_SIZES.get(role, 96.0)) * socket_scale))
		nb.custom_minimum_size = Vector2(disp, disp)
		nb.size = Vector2(disp, disp)
		nb.focus_mode = Control.FOCUS_ALL
		nb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		nb.tooltip_text = "%s\n%s" % [str(node_data.get("title", "")), str(node_data.get("desc", ""))]
		nb.set_meta("node_id", node_id)
		nb.set_meta("role", role)
		nb.pressed.connect(Callable(self, "_atlas_node_pressed").bind(node_id))
		nb.focus_entered.connect(Callable(self, "_atlas_node_focused").bind(node_id))
		canvas.add_child(nb)
		(_atlas["node_buttons"] as Dictionary)[node_id] = nb
		# Оверлеи состояний (§7): выбор, пульс доступности, звезда, кольцо keystone, туман.
		var select_ring := _atlas_add_overlay(nb, "Select", META40_KEYSTONE_RING_PATH, 1.30, Color(0.55, 0.80, 1.0, 0.85))
		select_ring.z_index = 1
		var glow := _atlas_add_overlay(nb, "Glow", META40_STAR_ALLOC_PATH, 1.30, Color(0.66, 0.80, 1.0, 0.9))
		var glow_pulse := glow.create_tween()
		glow_pulse.set_loops()
		glow_pulse.tween_property(glow, "self_modulate:a", 0.95, 0.7).from(0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		glow_pulse.tween_property(glow, "self_modulate:a", 0.30, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if role != "core":
			var star := _atlas_add_overlay(nb, "Star", META40_STAR_ALLOC_PATH, 0.80, Color.WHITE)
			star.z_index = 1
		if role == "keystone":
			var ring := _atlas_add_overlay(nb, "Ring", META40_KEYSTONE_RING_PATH, 1.42, Color(0.72, 0.88, 1.0, 1.0))
			var ring_pulse := ring.create_tween()
			ring_pulse.set_loops()
			ring_pulse.tween_property(ring, "self_modulate:a", 1.0, 1.1).from(0.72).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			ring_pulse.tween_property(ring, "self_modulate:a", 0.72, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if role == "hidden":
			var qmark := Label.new()
			qmark.name = "QMark"
			qmark.set_anchors_preset(Control.PRESET_FULL_RECT)
			qmark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			qmark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			qmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			qmark.text = "?"
			qmark.add_theme_font_size_override("font_size", int(maxf(14.0, disp * 0.40)))
			qmark.add_theme_color_override("font_color", Color(0.82, 0.90, 1.0, 0.92))
			nb.add_child(qmark)
			var fog := _atlas_add_overlay(nb, "Fog", str(META40_SOCKET_TEXTURES["hidden"]), 1.0, Color.WHITE)
			fog.z_index = 2
	# Выбор по умолчанию — ядро (панель сразу информативна).
	if str(_atlas.get("selected", "")) == "" or not npos_map.has(str(_atlas.get("selected", ""))):
		_atlas["selected"] = _atlas_core_node_id()
	_atlas_layout_nodes()
	_atlas_schedule_layout_passes()


func _atlas_add_overlay(nb: TextureButton, overlay_name: String, texture_path: String, rel: float, tint: Color) -> TextureRect:
	var overlay := TextureRect.new()
	overlay.name = overlay_name
	overlay.texture = game._cached_texture(texture_path)
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var side := nb.custom_minimum_size.x * rel
	overlay.size = Vector2(side, side)
	overlay.position = (nb.custom_minimum_size - overlay.size) * 0.5
	overlay.pivot_offset = overlay.size * 0.5
	overlay.modulate = tint
	overlay.visible = false
	nb.add_child(overlay)
	return overlay


# Раскладка узлов: всё созвездие ЦЕЛИКОМ в холсте (без пан/зума), npos 0..1.
func _atlas_layout_nodes() -> void:
	var canvas: Control = _atlas.get("canvas")
	var edge_layer: Control = _atlas.get("edge_layer")
	if canvas == null or not is_instance_valid(canvas):
		return
	if canvas.size.x <= 1.0 or canvas.size.y <= 1.0:
		call_deferred("_atlas_layout_nodes")
		return
	var s := _atlas_ui_scale()
	var pad := ATLAS_NODE_LAYOUT_PAD * s
	var area := Vector2(maxf(canvas.size.x - pad.x * 2.0, 8.0), maxf(canvas.size.y - pad.y * 2.0, 8.0))
	var centers := {}
	var radii := {}
	var buttons: Dictionary = _atlas.get("node_buttons", {})
	var npos_map: Dictionary = _atlas.get("npos", {})
	for node_id in buttons.keys():
		var nb := buttons[node_id] as TextureButton
		if nb == null or not is_instance_valid(nb):
			continue
		var npos: Vector2 = npos_map.get(node_id, Vector2(0.5, 0.5))
		var radius := minf(nb.custom_minimum_size.x, nb.custom_minimum_size.y) * 0.5
		var center := pad + npos * area
		center.x += _atlas_column_jitter(str(node_id), npos, npos_map, radius, s)
		center = _atlas_clamp_node_center(center, radius, canvas.size, s)
		centers[node_id] = center
		radii[node_id] = radius
	_atlas_relax_node_centers(centers, radii, canvas.size, s)
	_atlas_place_open_node_centers(centers, radii, canvas.size, s)
	for node_id in buttons.keys():
		var nb := buttons[node_id] as TextureButton
		if nb == null or not is_instance_valid(nb) or not centers.has(node_id):
			continue
		var center: Vector2 = centers[node_id]
		nb.position = center - nb.custom_minimum_size * 0.5
	_atlas["node_centers"] = centers
	if edge_layer != null and is_instance_valid(edge_layer):
		edge_layer.queue_redraw()


func _atlas_finish_deferred_layout() -> void:
	if _atlas.is_empty():
		return
	var canvas = _atlas.get("canvas")
	if canvas == null or not is_instance_valid(canvas):
		_atlas["layout_passes_left"] = 0
		return
	_atlas_layout_nodes()
	_atlas_wire_focus()


func _atlas_schedule_layout_passes() -> void:
	if _atlas.is_empty():
		return
	_atlas["layout_passes_left"] = maxi(int(_atlas.get("layout_passes_left", 0)), 6)
	call_deferred("_atlas_finish_deferred_layout")
	if game != null and game.get_tree() != null:
		var layout_pass := Callable(self, "_atlas_process_frame_layout")
		if not game.get_tree().process_frame.is_connected(layout_pass):
			game.get_tree().process_frame.connect(layout_pass, CONNECT_ONE_SHOT)


func _atlas_process_frame_layout() -> void:
	if _atlas.is_empty():
		return
	_atlas_finish_deferred_layout()
	var remaining := maxi(int(_atlas.get("layout_passes_left", 0)) - 1, 0)
	_atlas["layout_passes_left"] = remaining
	if remaining > 0 and game != null and game.get_tree() != null:
		var layout_pass := Callable(self, "_atlas_process_frame_layout")
		if not game.get_tree().process_frame.is_connected(layout_pass):
			game.get_tree().process_frame.connect(layout_pass, CONNECT_ONE_SHOT)


func _atlas_column_jitter(node_id: String, npos: Vector2, npos_map: Dictionary, radius: float, s: float) -> float:
	var rank := 0
	var group_size := 0
	for other_id in npos_map.keys():
		var other_pos: Vector2 = npos_map.get(other_id, Vector2.ZERO)
		if absf(other_pos.x - npos.x) > 0.026:
			continue
		group_size += 1
		if other_pos.y < npos.y:
			rank += 1
	if group_size < 2 or node_id == _atlas_core_node_id():
		return 0.0
	var side := -1.0 if rank % 2 == 0 else 1.0
	return side * maxf(radius * 2.10, 30.0 * s)


func _atlas_relax_node_centers(centers: Dictionary, radii: Dictionary, canvas_size: Vector2, s: float) -> void:
	var ids := centers.keys()
	var gap := maxf(2.0, ATLAS_NODE_COLLISION_GAP * s)
	for iteration in range(ATLAS_NODE_RELAX_ITERATIONS):
		var moved := false
		for first_index in range(ids.size()):
			var first_id = ids[first_index]
			if not centers.has(first_id) or not radii.has(first_id):
				continue
			for second_index in range(first_index + 1, ids.size()):
				var second_id = ids[second_index]
				if not centers.has(second_id) or not radii.has(second_id):
					continue
				var first_center: Vector2 = centers[first_id]
				var second_center: Vector2 = centers[second_id]
				var delta := second_center - first_center
				var distance := delta.length()
				var min_distance := float(radii[first_id]) + float(radii[second_id]) + gap
				if distance >= min_distance:
					continue
				var direction := Vector2.ZERO
				if distance > 0.001:
					if absf(delta.x) < min_distance * 0.35:
						var pair_hash := int(("%s/%s" % [str(first_id), str(second_id)]).hash())
						var side := -1.0 if pair_hash % 2 == 0 else 1.0
						delta.x += side * min_distance * 0.72
						distance = delta.length()
					direction = delta / distance
				else:
					var angle := TAU * float(first_index + second_index + iteration + 1) / maxf(float(ids.size()), 1.0)
					direction = Vector2(cos(angle), sin(angle))
					distance = 0.0
				var push := min_distance - distance
				var first_radius := float(radii[first_id])
				var second_radius := float(radii[second_id])
				var total_radius := maxf(first_radius + second_radius, 1.0)
				first_center -= direction * push * (second_radius / total_radius)
				second_center += direction * push * (first_radius / total_radius)
				centers[first_id] = _atlas_clamp_node_center(first_center, first_radius, canvas_size, s)
				centers[second_id] = _atlas_clamp_node_center(second_center, second_radius, canvas_size, s)
				moved = true
		if not moved:
			return


func _atlas_place_open_node_centers(centers: Dictionary, radii: Dictionary, canvas_size: Vector2, s: float) -> void:
	var remaining := centers.keys()
	var placed := {}
	var core_id := _atlas_core_node_id()
	while remaining.size() > 0:
		var best_index := 0
		var best_score := -INF
		for idx in range(remaining.size()):
			var node_id = remaining[idx]
			var score := float(radii.get(node_id, 0.0))
			if str(node_id) == core_id:
				score += 1000.0
			if score > best_score:
				best_score = score
				best_index = idx
		var place_id = remaining[best_index]
		remaining.remove_at(best_index)
		var radius := float(radii.get(place_id, 1.0))
		var anchor: Vector2 = centers.get(place_id, canvas_size * 0.5)
		placed[place_id] = _atlas_find_open_node_center(anchor, radius, placed, radii, canvas_size, s)
	for node_id in placed.keys():
		centers[node_id] = placed[node_id]


func _atlas_find_open_node_center(anchor: Vector2, radius: float, placed: Dictionary, radii: Dictionary, canvas_size: Vector2, s: float) -> Vector2:
	var gap := maxf(2.0, ATLAS_NODE_COLLISION_GAP * s)
	var start := _atlas_clamp_node_center(anchor, radius, canvas_size, s)
	if _atlas_node_center_is_open(start, radius, placed, radii, gap):
		return start
	var best_center := start
	var best_clearance := -INF
	var step := maxf(12.0 * s, radius * 0.55)
	var angle_count := 16
	for ring in range(1, 34):
		var distance := step * float(ring)
		for angle_index in range(angle_count):
			var angle := TAU * float(angle_index) / float(angle_count)
			var candidate := _atlas_clamp_node_center(anchor + Vector2(cos(angle), sin(angle)) * distance, radius, canvas_size, s)
			var clearance := _atlas_node_center_clearance(candidate, radius, placed, radii)
			if clearance > best_clearance:
				best_clearance = clearance
				best_center = candidate
			if clearance >= gap:
				return candidate
	return best_center


func _atlas_node_center_is_open(center: Vector2, radius: float, placed: Dictionary, radii: Dictionary, gap: float) -> bool:
	return _atlas_node_center_clearance(center, radius, placed, radii) >= gap


func _atlas_node_center_clearance(center: Vector2, radius: float, placed: Dictionary, radii: Dictionary) -> float:
	var clearance := INF
	for other_id in placed.keys():
		var other_center: Vector2 = placed[other_id]
		var other_radius := float(radii.get(other_id, 0.0))
		clearance = minf(clearance, center.distance_to(other_center) - radius - other_radius)
	return clearance


func _atlas_clamp_node_center(center: Vector2, radius: float, canvas_size: Vector2, s: float) -> Vector2:
	var edge_gap := maxf(2.0, ATLAS_NODE_COLLISION_GAP * s * 0.5)
	var min_pos := Vector2(radius + edge_gap, radius + edge_gap)
	var max_pos := Vector2(
		maxf(min_pos.x, canvas_size.x - radius - edge_gap),
		maxf(min_pos.y, canvas_size.y - radius - edge_gap)
	)
	return Vector2(
		clampf(center.x, min_pos.x, max_pos.x),
		clampf(center.y, min_pos.y, max_pos.y)
	)


# Силуэт-линии созвездия: тусклые до покупки, золотые между купленными; вспышка
# покупки временно «зажигает» рёбра купленного узла (edge_flash).
func _atlas_draw_edges() -> void:
	var edge_layer: Control = _atlas.get("edge_layer")
	if edge_layer == null or not is_instance_valid(edge_layer):
		return
	var centers: Dictionary = _atlas.get("node_centers", {})
	var status: Dictionary = _atlas.get("status", {})
	var flash: Dictionary = _atlas.get("edge_flash", {})
	var s := _atlas_ui_scale()
	for edge in _atlas.get("edges", []):
		var a_id := str((edge as Array)[0])
		var b_id := str((edge as Array)[1])
		if not centers.has(a_id) or not centers.has(b_id):
			continue
		var a_on := str(status.get(a_id, "")) == "purchased"
		var b_on := str(status.get(b_id, "")) == "purchased"
		var color := Color(0.46, 0.60, 0.82, 0.28)
		var width := maxf(2.0, 2.6 * s)
		if a_on and b_on:
			color = Color(0.93, 0.77, 0.40, 0.92)
			width = maxf(3.0, 5.0 * s)
		elif a_on or b_on:
			color = Color(0.78, 0.67, 0.45, 0.55)
			width = maxf(2.5, 3.6 * s)
		var flash_amount := maxf(float(flash.get(a_id, 0.0)), float(flash.get(b_id, 0.0)))
		if flash_amount > 0.0:
			color = color.lerp(Color(1.0, 0.92, 0.62, 1.0), clampf(flash_amount, 0.0, 1.0))
			width += 2.0 * flash_amount
		edge_layer.draw_line(centers[a_id], centers[b_id], color, width, true)


# Полное обновление: валюты в шапке, медальоны, состояния узлов, панель узла.
func _atlas_refresh() -> void:
	if _atlas.is_empty():
		return
	var root: Control = _atlas.get("root")
	if root == null or not is_instance_valid(root):
		return
	var state: Dictionary = game.meta_state
	var class_id := str(_atlas.get("class_id", "berserk"))
	var on_guild := str(_atlas.get("tab", "constellation")) == "guild"

	var emblems_label := _atlas.get("emblems_label") as Label
	if emblems_label != null and is_instance_valid(emblems_label):
		var genitive := str(ATLAS_CLASS_GENITIVE.get(class_id, "класса"))
		emblems_label.text = "Эмблемы %s: %d" % [genitive, game.META_PROGRESSION.class_sigils_available(state, class_id)]
	var stardust_label := _atlas.get("stardust_label") as Label
	if stardust_label != null and is_instance_valid(stardust_label):
		stardust_label.text = "Звёздная пыль: %d" % game.META_PROGRESSION.stardust_available(state)

	# Медальоны: подсветка выбранного, прогресс x/N, бейдж непотраченных эмблем.
	var purchased_all: Array = game.META_PROGRESSION.purchased_nodes(state)
	for raw_mb in _atlas.get("medallions", []):
		var mb := raw_mb as TextureButton
		if mb == null or not is_instance_valid(mb):
			continue
		var cid := str(mb.get_meta("class_id"))
		mb.modulate = Color.WHITE if (cid == class_id and not on_guild) else Color(0.68, 0.70, 0.78, 0.88)
		var visible_total := 0
		var visible_bought := 0
		for node in game.META_PROGRESSION.constellation_nodes(cid):
			if str((node as Dictionary).get("role", "")) == "hidden":
				continue
			visible_total += 1
			if purchased_all.has(str((node as Dictionary)["id"])):
				visible_bought += 1
		var prog := mb.find_child("AtlasMedallionProgress_%s" % cid, true, false) as Label
		if prog != null:
			prog.text = "%d/%d" % [visible_bought, visible_total]
		var unspent: int = game.META_PROGRESSION.class_sigils_available(state, cid)
		var badge := mb.find_child("AtlasMedallionBadge_%s" % cid, true, false) as PanelContainer
		if badge != null:
			badge.visible = unspent > 0
			var badge_label := badge.find_child("BadgeCount", true, false) as Label
			if badge_label != null:
				badge_label.text = str(mini(unspent, 99))

	# Состояния узлов текущего графа (§7: 6 состояний).
	var status_map := {}
	var buttons: Dictionary = _atlas.get("node_buttons", {})
	for node_id in buttons.keys():
		status_map[node_id] = str(game.META_PROGRESSION.node_status(state, str(node_id)))
	_atlas["status"] = status_map
	var selected_id := str(_atlas.get("selected", ""))
	for node_id in buttons.keys():
		var nb := buttons[node_id] as TextureButton
		if nb == null or not is_instance_valid(nb):
			continue
		var role := str(nb.get_meta("role"))
		var node_status := str(status_map.get(node_id, "locked"))
		match node_status:
			"purchased":
				nb.modulate = Color.WHITE
			"available":
				nb.modulate = Color.WHITE
			"hidden":
				nb.modulate = Color(0.86, 0.90, 0.99, 0.92)
			_:
				nb.modulate = Color(0.52, 0.55, 0.63, 0.78)
		var glow := nb.get_node_or_null("Glow") as TextureRect
		if glow != null:
			glow.visible = node_status == "available"
		var star := nb.get_node_or_null("Star") as TextureRect
		if star != null:
			star.visible = node_status == "purchased" and role != "core"
			if role == "keystone":
				var keystone_active: bool = game.META_PROGRESSION.is_keystone_active(state, str(node_id))
				# Купленная неактивная ключевая — «тлеет»; активная — золото + сапфир.
				star.self_modulate = Color.WHITE if keystone_active else Color(1.0, 0.56, 0.28, 0.72)
		var ring := nb.get_node_or_null("Ring") as TextureRect
		if ring != null:
			ring.visible = role == "keystone" and game.META_PROGRESSION.is_keystone_active(state, str(node_id))
		var select_ring := nb.get_node_or_null("Select") as TextureRect
		if select_ring != null:
			select_ring.visible = str(node_id) == selected_id
		var qmark := nb.get_node_or_null("QMark") as Label
		if qmark != null:
			qmark.visible = node_status == "hidden"
		# Церемония открытия скрытой звезды: рассеивание тумана 0.6с, скип кликом.
		if role == "hidden" and node_status == "purchased" and not _atlas_hidden_seen.has(node_id):
			_atlas_hidden_seen[node_id] = true
			var fog := nb.get_node_or_null("Fog") as TextureRect
			if fog != null:
				fog.visible = true
				fog.modulate = Color.WHITE
				var fog_tween := fog.create_tween()
				fog_tween.tween_property(fog, "modulate:a", 0.0, ATLAS_FOG_DISSOLVE_SEC)
				fog_tween.tween_callback(Callable(self, "_atlas_finish_fog").bind(str(node_id)))
				(_atlas["fog_tweens"] as Dictionary)[node_id] = fog_tween

	var edge_layer: Control = _atlas.get("edge_layer")
	if edge_layer != null and is_instance_valid(edge_layer):
		edge_layer.queue_redraw()
	_atlas_refresh_node_panel()


# Правая панель: титул/тип/описание С ЧИСЛАМИ/цена/кнопки; для keystone —
# переключатель активности; для скрытой — условие и прогресс подвига.
func _atlas_refresh_node_panel() -> void:
	var state: Dictionary = game.meta_state
	var on_guild := str(_atlas.get("tab", "constellation")) == "guild"
	var selected_id := str(_atlas.get("selected", ""))
	var node: Dictionary = game.META_PROGRESSION.node_by_id(selected_id)
	var kind_label := _atlas.get("panel_kind") as Label
	var icon := _atlas.get("panel_icon") as TextureRect
	var title_label := _atlas.get("panel_title") as Label
	var desc_label := _atlas.get("panel_desc") as Label
	var condition_label := _atlas.get("panel_condition") as Label
	var lore_label := _atlas.get("panel_lore") as Label
	var price_row := _atlas.get("panel_price_row") as HBoxContainer
	var price_label := _atlas.get("panel_price_label") as Label
	var price_icon := _atlas.get("panel_price_icon") as TextureRect
	var buy_button := _atlas.get("buy_button") as Button
	var keystone_toggle := _atlas.get("keystone_toggle") as Button
	var progress_label := _atlas.get("panel_progress") as Label
	var hidden_hint := _atlas.get("panel_hidden_hint") as Label
	for control in [kind_label, icon, title_label, desc_label, condition_label, lore_label, price_row, price_label, price_icon, buy_button, keystone_toggle, progress_label, hidden_hint]:
		if control == null or not is_instance_valid(control):
			return
	var currency_icon_path := META40_CURRENCY_STARDUST_PATH if on_guild else META40_CURRENCY_EMBLEM_PATH
	var currency_word := "пыль" if on_guild else "эмблему"
	if node.is_empty():
		kind_label.text = "АТЛАС ГЕРОЕВ"
		icon.texture = game._cached_texture(str(META40_SOCKET_TEXTURES["minor"]))
		title_label.text = "Выберите звезду"
		desc_label.text = "Кликните по звезде созвездия, чтобы увидеть её силу и цену."
		condition_label.visible = false
		lore_label.visible = false
		price_row.visible = false
		buy_button.visible = false
		keystone_toggle.visible = false
	else:
		var role := str(node.get("role", "minor"))
		var affinity := str(node.get("class_affinity", ""))
		var node_status := str(game.META_PROGRESSION.node_status(state, selected_id))
		kind_label.text = "ХАБ ГИЛЬДИИ" if (role == "core" and affinity == "") else str(ATLAS_ROLE_LABELS.get(role, "ЗВЕЗДА"))
		var icon_path := str(META40_SOCKET_TEXTURES.get(role, META40_SOCKET_TEXTURES["minor"]))
		if role == "core" and affinity != "":
			icon_path = META40_UI_DIR + "crest_%s.png" % affinity
		icon.texture = game._cached_texture(icon_path)
		title_label.text = str(node.get("title", ""))
		desc_label.text = str(node.get("desc", ""))
		lore_label.text = str(node.get("lore", ""))
		lore_label.visible = role == "hidden" and lore_label.text != ""
		condition_label.visible = false
		if role == "hidden":
			var progress: Dictionary = game.META_PROGRESSION.hidden_star_progress(state, selected_id)
			if not progress.is_empty():
				condition_label.visible = true
				if bool(progress.get("unlocked", false)):
					condition_label.text = "Подвиг совершён — звезда зажжена!"
				else:
					condition_label.text = "Условие: %s\nПрогресс: %d/%d" % [str(progress.get("text", "")), int(progress.get("current", 0)), int(progress.get("required", 1))]
		var purchasable := role != "core" and role != "hidden"
		var cost := int(node.get("cost", 0))
		price_row.visible = purchasable and node_status != "purchased"
		price_label.text = "Цена: %d" % cost
		price_icon.texture = game._cached_texture(currency_icon_path)
		buy_button.visible = purchasable and node_status != "purchased"
		buy_button.text = "Вложить %s" % currency_word
		buy_button.disabled = node_status != "available"
		if node_status == "locked":
			var have: int = game.META_PROGRESSION.currency_available_for_node(state, selected_id)
			condition_label.visible = true
			if have < cost:
				condition_label.text = "Не хватает: %d из %d. Зарабатывайте %s подвигами класса." % [have, cost, "пыль" if on_guild else "эмблемы"]
			else:
				condition_label.text = "Нужна соседняя купленная звезда."
		elif purchasable and node_status == "purchased":
			condition_label.visible = true
			condition_label.text = "Звезда зажжена."
		keystone_toggle.visible = role == "keystone" and affinity != "" and node_status == "purchased"
		if keystone_toggle.visible:
			var active: bool = game.META_PROGRESSION.is_keystone_active(state, selected_id)
			keystone_toggle.text = "Активна — погасить" if active else "Сделать активной"

	# Итоги внизу панели: прогресс созвездия/Атласа + подсказка о скрытой звезде.
	var graph_nodes := _atlas_graph_nodes()
	var purchased_all: Array = game.META_PROGRESSION.purchased_nodes(state)
	var visible_total := 0
	var visible_bought := 0
	var hint_text := ""
	for raw_node in graph_nodes:
		var graph_node: Dictionary = raw_node
		if str(graph_node.get("role", "")) == "hidden":
			if hint_text == "" and not game.META_PROGRESSION.hidden_star_unlocked(state, str(graph_node["id"])):
				var progress: Dictionary = game.META_PROGRESSION.hidden_star_progress(state, str(graph_node["id"]))
				hint_text = "До скрытой звезды: %s (%d/%d)" % [str(progress.get("text", "")), int(progress.get("current", 0)), int(progress.get("required", 1))]
			continue
		visible_total += 1
		if purchased_all.has(str(graph_node["id"])):
			visible_bought += 1
	if on_guild:
		progress_label.text = "Атлас гильдии: %d/%d" % [visible_bought, visible_total]
	else:
		var power: float = game.META_PROGRESSION.estimated_class_power_multiplier(state, str(_atlas.get("class_id", "berserk")))
		progress_label.text = "Созвездие: %d/%d · Сила класса: +%d%%" % [visible_bought, visible_total, int(roundf((power - 1.0) * 100.0))]
	hidden_hint.text = hint_text
	hidden_hint.visible = hint_text != ""


func _atlas_node_pressed(node_id: String) -> void:
	_atlas_skip_fog_ceremonies()
	# SCRUM-838: clicking an Atlas cell is preview-only. Purchasing or keystone
	# activation must go through the explicit action buttons in the right panel.
	_atlas_select_node(node_id)


func _atlas_node_focused(node_id: String) -> void:
	# Геймпад/клавиатура: фокус на узле сразу показывает его в панели.
	if str(_atlas.get("selected", "")) != node_id:
		_atlas_select_node(node_id)


func _atlas_select_node(node_id: String) -> void:
	if _atlas.is_empty():
		return
	_atlas["selected"] = node_id
	_atlas_refresh()


func _atlas_select_class(class_id: String) -> void:
	if _atlas.is_empty() or str(_atlas.get("class_id", "")) == class_id and str(_atlas.get("tab", "")) == "constellation":
		_atlas_refresh()
		return
	_atlas["class_id"] = class_id
	_atlas["tab"] = "constellation"
	_atlas["selected"] = ""
	_atlas_apply_tab_state()
	_atlas_build_canvas()
	_atlas_refresh()
	_atlas_wire_focus()


func _atlas_switch_tab(tab: String) -> void:
	if _atlas.is_empty() or str(_atlas.get("tab", "")) == tab:
		return
	_atlas["tab"] = tab
	_atlas["selected"] = ""
	_atlas_apply_tab_state()
	_atlas_build_canvas()
	_atlas_refresh()
	_atlas_wire_focus()


# LB/RB (и Tab) листают вкладки Созвездие↔Гильдия (паттерн SCRUM-813).
func _atlas_cycle_tab(_dir: int) -> bool:
	if _atlas.is_empty():
		return false
	_atlas_switch_tab("guild" if str(_atlas.get("tab", "constellation")) == "constellation" else "constellation")
	return true


func _atlas_apply_tab_state() -> void:
	var on_guild := str(_atlas.get("tab", "constellation")) == "guild"
	var tab_constellation := _atlas.get("tab_constellation") as Button
	var tab_guild := _atlas.get("tab_guild") as Button
	var strip := _atlas.get("strip") as ScrollContainer
	var emblem_badge := _atlas.get("emblem_badge") as PanelContainer
	if tab_constellation == null or tab_guild == null or not is_instance_valid(tab_constellation) or not is_instance_valid(tab_guild):
		return
	var active_tint := Color(1.0, 0.94, 0.74, 1.0)
	var idle_tint := Color(0.74, 0.76, 0.84, 0.92)
	tab_constellation.modulate = idle_tint if on_guild else active_tint
	tab_guild.modulate = active_tint if on_guild else idle_tint
	# Tab-клавиша всегда жмёт ПРОТИВОПОЛОЖНУЮ вкладку (короткая дорога «Tab — вкладки»).
	var tab_shortcut := Shortcut.new()
	var tab_event := InputEventKey.new()
	tab_event.keycode = KEY_TAB
	tab_shortcut.events = [tab_event]
	tab_constellation.shortcut = tab_shortcut if on_guild else null
	tab_guild.shortcut = null if on_guild else tab_shortcut
	if strip != null and is_instance_valid(strip):
		strip.visible = not on_guild
	if emblem_badge != null and is_instance_valid(emblem_badge):
		emblem_badge.visible = not on_guild
	var respec_button := _atlas.get("respec_button") as Button
	if respec_button != null and is_instance_valid(respec_button):
		respec_button.text = "Респек Атласа — бесплатно" if on_guild else "Респек — бесплатно"


func _atlas_buy_selected() -> void:
	var node_id := str(_atlas.get("selected", ""))
	if node_id == "" or _atlas.is_empty():
		return
	if not game.META_PROGRESSION.can_buy_node(game.meta_state, node_id):
		return
	game.meta_state = game.META_PROGRESSION.allocate_node(game.meta_state, node_id)
	game.META_PROGRESSION.save_state(game.meta_state)
	_atlas_refresh()
	_atlas_play_purchase_ceremony(node_id)


# Церемония покупки: вспышка звезды + загорание линий к соседям (§7).
func _atlas_play_purchase_ceremony(node_id: String) -> void:
	var nb := (_atlas.get("node_buttons", {}) as Dictionary).get(node_id) as TextureButton
	if nb == null or not is_instance_valid(nb):
		return
	var star := nb.get_node_or_null("Star") as TextureRect
	if star != null and star.visible:
		var star_tween := star.create_tween()
		star_tween.tween_property(star, "scale", Vector2.ONE, 0.45).from(Vector2(1.7, 1.7)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		star_tween.parallel().tween_property(star, "self_modulate", star.self_modulate, 0.45).from(Color(2.0, 1.8, 1.2, 1.0))
	var edge_layer := _atlas.get("edge_layer") as Control
	if edge_layer != null and is_instance_valid(edge_layer):
		var edge_tween := edge_layer.create_tween()
		edge_tween.tween_method(Callable(self, "_atlas_set_edge_flash").bind(node_id), 1.0, 0.0, 0.8)


func _atlas_set_edge_flash(value: float, node_id: String) -> void:
	if _atlas.is_empty():
		return
	(_atlas.get("edge_flash", {}) as Dictionary)[node_id] = value
	var edge_layer := _atlas.get("edge_layer") as Control
	if edge_layer != null and is_instance_valid(edge_layer):
		edge_layer.queue_redraw()


func _atlas_toggle_keystone() -> void:
	var node_id := str(_atlas.get("selected", ""))
	var node: Dictionary = game.META_PROGRESSION.node_by_id(node_id)
	if node.is_empty() or str(node.get("role", "")) != "keystone":
		return
	var class_id := str(node.get("class_affinity", ""))
	if class_id == "":
		return
	var active: bool = game.META_PROGRESSION.is_keystone_active(game.meta_state, node_id)
	game.meta_state = game.META_PROGRESSION.set_active_keystone(game.meta_state, class_id, "" if active else node_id)
	game.META_PROGRESSION.save_state(game.meta_state)
	_atlas_refresh()


func _atlas_respec_prompt() -> void:
	var popup := _atlas.get("respec_popup") as PanelContainer
	var text := _atlas.get("respec_text") as Label
	if popup == null or text == null or not is_instance_valid(popup) or not is_instance_valid(text):
		return
	if str(_atlas.get("tab", "constellation")) == "guild":
		text.text = "Сбросить все узлы Атласа гильдии? Звёздная пыль вернётся полностью — респек бесплатный."
	else:
		var title := str(game.PROGRESSION_DATA.character_config(str(_atlas.get("class_id", ""))).get("title", ""))
		text.text = "Сбросить созвездие класса «%s»? Эмблемы вернутся полностью — респек бесплатный." % title
	popup.visible = true


func _atlas_respec_cancel() -> void:
	var popup := _atlas.get("respec_popup") as PanelContainer
	if popup != null and is_instance_valid(popup):
		popup.visible = false


func _atlas_respec_confirm() -> void:
	if _atlas.is_empty():
		return
	if str(_atlas.get("tab", "constellation")) == "guild":
		game.meta_state = game.META_PROGRESSION.reset_constellation(game.meta_state, "")
	else:
		game.meta_state = game.META_PROGRESSION.reset_constellation(game.meta_state, str(_atlas.get("class_id", "")))
	game.META_PROGRESSION.save_state(game.meta_state)
	_atlas_respec_cancel()
	_atlas_refresh()


func _atlas_canvas_input(event: InputEvent) -> void:
	# Клик по небу скипает церемонию рассеивания тумана (§7).
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_atlas_skip_fog_ceremonies()


func _atlas_skip_fog_ceremonies() -> void:
	var tweens: Dictionary = _atlas.get("fog_tweens", {})
	for node_id in tweens.keys():
		var fog_tween := tweens[node_id] as Tween
		if fog_tween != null and fog_tween.is_valid():
			fog_tween.kill()
		_atlas_finish_fog(str(node_id))
	_atlas["fog_tweens"] = {}


func _atlas_finish_fog(node_id: String) -> void:
	if _atlas.is_empty():
		return
	(_atlas.get("fog_tweens", {}) as Dictionary).erase(node_id)
	var nb := (_atlas.get("node_buttons", {}) as Dictionary).get(node_id) as TextureButton
	if nb == null or not is_instance_valid(nb):
		return
	var fog := nb.get_node_or_null("Fog") as TextureRect
	if fog != null:
		fog.visible = false


# SCRUM-812/813: фокус-цепочки — лента классов вертикальной цепью, узлы по
# adj-соседям созвездия (гео-направления), шапка/низ достижимы направлениями.
func _atlas_wire_focus() -> void:
	if _atlas.is_empty():
		return
	var tab_constellation := _atlas.get("tab_constellation") as Button
	var tab_guild := _atlas.get("tab_guild") as Button
	var back_button := _atlas.get("back_button") as Button
	var respec_button := _atlas.get("respec_button") as Button
	var buy_button := _atlas.get("buy_button") as Button
	var on_guild := str(_atlas.get("tab", "constellation")) == "guild"
	var medallions: Array = [] if on_guild else _atlas.get("medallions", [])
	var buttons: Dictionary = _atlas.get("node_buttons", {})
	var centers: Dictionary = _atlas.get("node_centers", {})
	for control in [tab_constellation, tab_guild, back_button, respec_button, buy_button]:
		if control == null or not is_instance_valid(control):
			return
	# Шапка: горизонтальная цепь.
	var header_ring: Array = [tab_constellation, tab_guild, back_button]
	for i in range(header_ring.size()):
		var current := header_ring[i] as Button
		current.focus_neighbor_left = (header_ring[(i - 1 + header_ring.size()) % header_ring.size()] as Control).get_path()
		current.focus_neighbor_right = (header_ring[(i + 1) % header_ring.size()] as Control).get_path()
		current.focus_neighbor_bottom = respec_button.get_path()
	# Лента классов: вертикальная цепь, вправо — ядро созвездия.
	var core_button := buttons.get(_atlas_core_node_id()) as TextureButton
	for i in range(medallions.size()):
		var mb := medallions[i] as TextureButton
		if mb == null or not is_instance_valid(mb):
			continue
		var prev := medallions[(i - 1 + medallions.size()) % medallions.size()] as TextureButton
		var next := medallions[(i + 1) % medallions.size()] as TextureButton
		mb.focus_neighbor_top = prev.get_path()
		mb.focus_neighbor_bottom = next.get_path()
		if core_button != null and is_instance_valid(core_button):
			mb.focus_neighbor_right = core_button.get_path()
	# Узлы: гео-направления по adj (лучший сосед в каждой из 4 сторон).
	var selected_medallion: TextureButton = null
	for raw_mb in medallions:
		var mb := raw_mb as TextureButton
		if mb != null and is_instance_valid(mb) and str(mb.get_meta("class_id")) == str(_atlas.get("class_id", "")):
			selected_medallion = mb
			break
	for node_id in buttons.keys():
		var nb := buttons[node_id] as TextureButton
		if nb == null or not is_instance_valid(nb) or not centers.has(node_id):
			continue
		var node: Dictionary = game.META_PROGRESSION.node_by_id(str(node_id))
		var center: Vector2 = centers[node_id]
		var best := {"left": null, "right": null, "top": null, "bottom": null}
		var best_score := {"left": 0.35, "right": 0.35, "top": 0.35, "bottom": 0.35}
		for raw_adj in node.get("adj", []):
			var adj_id := str(raw_adj)
			if not centers.has(adj_id) or not buttons.has(adj_id):
				continue
			var offset := (centers[adj_id] as Vector2) - center
			if offset.length() < 1.0:
				continue
			var direction := offset.normalized()
			var scores := {"left": -direction.x, "right": direction.x, "top": -direction.y, "bottom": direction.y}
			for side in scores.keys():
				if float(scores[side]) > float(best_score[side]):
					best_score[side] = float(scores[side])
					best[side] = buttons[adj_id]
		var left_target := best["left"] as Control
		if left_target == null:
			left_target = selected_medallion if selected_medallion != null else tab_constellation
		var right_target := best["right"] as Control
		if right_target == null:
			right_target = buy_button if buy_button.visible and not buy_button.disabled else respec_button
		var top_target := best["top"] as Control
		if top_target == null:
			top_target = tab_guild if on_guild else tab_constellation
		var bottom_target := best["bottom"] as Control
		if bottom_target == null:
			bottom_target = respec_button
		nb.focus_neighbor_left = left_target.get_path()
		nb.focus_neighbor_right = right_target.get_path()
		nb.focus_neighbor_top = top_target.get_path()
		nb.focus_neighbor_bottom = bottom_target.get_path()
	# Панель/низ: возврат к ядру созвездия.
	if core_button != null and is_instance_valid(core_button):
		buy_button.focus_neighbor_left = core_button.get_path()
		respec_button.focus_neighbor_top = core_button.get_path()
	var keystone_toggle := _atlas.get("keystone_toggle") as Button
	if keystone_toggle != null and is_instance_valid(keystone_toggle):
		buy_button.focus_neighbor_bottom = keystone_toggle.get_path()
		keystone_toggle.focus_neighbor_top = buy_button.get_path()
		if core_button != null and is_instance_valid(core_button):
			keystone_toggle.focus_neighbor_left = core_button.get_path()
	# Стартовый фокус: медальон выбранного класса (вкладка Гильдии — ядро Атласа).
	var initial: Control = selected_medallion
	if initial == null:
		initial = core_button
	if initial == null and not buttons.is_empty():
		initial = buttons.values()[0] as Control
	if initial != null and is_instance_valid(initial):
		initial.call_deferred("grab_focus")


func _show_patch_notes_screen() -> void:
	# SCRUM-159: экран «Что нового» из главного меню — data-driven патч-ноуты
	# по версиям (новейшая первой), только пользовательский русский текст.
	# SCRUM-879: единый атлас-стиль — тихий фон-хроника COVERED, контент в
	# safe-зоне рамы, кожаная панель _atlas_chip_style, полая рама поверх.
	const PatchNotesData := preload("res://scripts/patch_notes_data.gd")
	game._clear_ui()
	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "PatchNotesScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	game.ui_layer.add_child(root)
	_prepare_global_tooltips(root)
	_unified_add_background(root, "patch_notes")

	var s := _atlas_ui_scale()
	var safe := _unified_make_safe_area(root, "PatchNotes")
	var layout := VBoxContainer.new()
	layout.name = "PatchNotesLayout"
	layout.add_theme_constant_override("separation", int(roundf(12.0 * s)))
	safe.add_child(layout)

	var header := HBoxContainer.new()
	header.name = "PatchNotesHeader"
	header.add_theme_constant_override("separation", int(roundf(12.0 * s)))
	layout.add_child(header)
	header.add_child(_unified_header_chip("PatchNotes", "Что нового", "patch_notes", s))
	var header_spacer := Control.new()
	header_spacer.name = "PatchNotesHeaderSpacer"
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	# Единый возврат (фидбек 2026-07-08): везде «Назад» на плите 260×h.
	var back_button := _make_button("Назад")
	back_button.name = "PatchNotesBackButton"
	_set_action_button_size(back_button, 260.0, _atlas_action_button_height())
	back_button.pressed.connect(_show_main_menu)
	header.add_child(back_button)
	game.ui_escape_action = _show_main_menu
	# SCRUM-813: стартовый фокус — «Назад в меню»; A возвращает в меню, B/Esc тоже.
	# Контент патч-ноутов read-only — прокрутка колесом/перетаскиванием (гео-скролл геймпадом
	# на чисто-текстовых экранах — отдельная мелкая доработка).
	_ensure_run_ui_gamepad_bindings()
	back_button.call_deferred("grab_focus")

	var panel := PanelContainer.new()
	panel.name = "PatchNotesPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _atlas_chip_style(0.90, roundf(18.0 * s)))
	layout.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.name = "PatchNotesScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var content := VBoxContainer.new()
	content.name = "PatchNotesContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", int(roundf(12.0 * s)))
	scroll.add_child(content)

	var entries := PatchNotesData.all_entries()
	for i in entries.size():
		var entry_data: Dictionary = entries[i]
		var version := str(entry_data.get("version", ""))
		var version_label := Label.new()
		version_label.name = "PatchNotesVersion_%s" % version.replace(".", "_")
		version_label.text = "Версия %s  (%s)" % [version, str(entry_data.get("date", ""))]
		version_label.add_theme_font_size_override("font_size", _readable_font_size(24))
		version_label.add_theme_color_override("font_color", Color(0.94, 0.80, 0.46, 1.0))
		content.add_child(version_label)
		for line in (entry_data.get("highlights", []) as Array):
			var bullet := Label.new()
			bullet.text = "•  %s" % str(line)
			bullet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			bullet.add_theme_font_size_override("font_size", _readable_font_size(16))
			bullet.add_theme_color_override("font_color", Color(0.86, 0.90, 0.97, 0.96))
			content.add_child(bullet)
		if i < entries.size() - 1:
			_unified_add_divider(content, s, "_" + version)

	# Рама — ПОСЛЕДНЕЙ: полый 9-slice поверх контента (контент в safe-зоне).
	_unified_add_frame(root, "PatchNotes")


func _show_codex_screen() -> void:
	# SCRUM-879: кодекс на едином атлас-стиле (слои экрана «Атлас героев»):
	# фон COVERED → контент в safe-зоне рамы → тело «табы | список | досье»
	# → полая рама поверх. Контейнерный лейаут (без абсолютного _codex_v2-движка);
	# данные/дискавери/ленивые секции сохранены. SCRUM-884 (фидбек юзера):
	# центральный предпросмотр (сцена+сводка) упразднён — центр только список,
	# картинка и полное описание живут в правом досье.
	game._clear_ui()
	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "CodexScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	game.ui_layer.add_child(root)
	_prepare_global_tooltips(root)

	_unified_add_background(root, "codex")

	var s := _atlas_ui_scale()
	var safe := _unified_make_safe_area(root, "Codex")
	var layout := VBoxContainer.new()
	layout.name = "CodexLayout"
	layout.add_theme_constant_override("separation", int(roundf(12.0 * s)))
	safe.add_child(layout)

	# --- Шапка: чип-титул экрана + «Назад» на глобальном ките ---
	var header := HBoxContainer.new()
	header.name = "CodexHeader"
	header.add_theme_constant_override("separation", int(roundf(12.0 * s)))
	layout.add_child(header)
	header.add_child(_unified_header_chip("Codex", "Кодекс", "codex", s))
	var header_spacer := Control.new()
	header_spacer.name = "CodexHeaderSpacer"
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	var back_button := _make_button("Назад")
	back_button.name = "CodexBackButton"
	# SCRUM-881: единый размер back-кнопки со всеми экранами (атлас/настройки/
	# патч-ноуты) — 260 × action-height, кит мапит на нативную плиту back_260x104.
	_set_action_button_size(back_button, 260.0, _atlas_action_button_height())
	back_button.pressed.connect(_show_main_menu)
	header.add_child(back_button)
	game.ui_escape_action = _show_main_menu

	# --- Тело: нав-панель | центр (список записей) | досье ---
	var body := HBoxContainer.new()
	body.name = "CodexBody"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", int(roundf(14.0 * s)))
	layout.add_child(body)

	# SCRUM-881: nav ужат (300s против прежних 340s) — освобождённая ширина
	# уходит вправо, в широкое досье.
	var nav_panel := PanelContainer.new()
	nav_panel.name = "CodexNavPanel"
	nav_panel.custom_minimum_size = Vector2(roundf(clampf(300.0 * s, 220.0, 360.0)), 0.0)
	nav_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav_panel.add_theme_stylebox_override("panel", _atlas_chip_style(0.88, roundf(10.0 * s)))
	body.add_child(nav_panel)
	var tabs_row := VBoxContainer.new()
	tabs_row.name = "CodexTabs"
	tabs_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	tabs_row.add_theme_constant_override("separation", int(roundf(10.0 * s)))
	nav_panel.add_child(tabs_row)

	var content := PanelContainer.new()
	content.name = "CodexContent"
	# SCRUM-881: центр (список записей) не схлопывается на малых вьюпортах —
	# минимум ~220px; остальное ширины забирает широкое досье справа.
	content.custom_minimum_size = Vector2(roundf(clampf(240.0 * s, 220.0, 320.0)), 0.0)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_stylebox_override("panel", _atlas_chip_style(0.86, roundf(10.0 * s)))
	body.add_child(content)
	var center_box := VBoxContainer.new()
	center_box.name = "CodexCenterBox"
	center_box.add_theme_constant_override("separation", int(roundf(10.0 * s)))
	content.add_child(center_box)

	# SCRUM-884 (фидбек юзера): в центре ТОЛЬКО список карточек «имя + краткое
	# описание» на всю высоту колонки — предпросмотр (сцена/сводка) упразднён,
	# арт и полное досье показывает правая панель.
	var center_list_host := Control.new()
	center_list_host.name = "CodexCenterListHost"
	center_list_host.clip_contents = true
	center_list_host.custom_minimum_size = Vector2(0.0, roundf(clampf(150.0 * s, 96.0, 220.0)))
	center_list_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_box.add_child(center_list_host)

	# SCRUM-881: досье ×2 по ширине (940s против прежних 470s) под глубокое
	# структурированное описание; при конфликте ширина досье в приоритете.
	var detail_panel := PanelContainer.new()
	detail_panel.name = "CodexDetailPanel"
	detail_panel.custom_minimum_size = Vector2(roundf(clampf(940.0 * s, 420.0, 960.0)), 0.0)
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", _atlas_chip_style(0.90, roundf(12.0 * s)))
	body.add_child(detail_panel)

	content.set_meta("codex_detail_panel", detail_panel)
	content.set_meta("codex_tabs", tabs_row)
	content.set_meta("codex_section_host", center_list_host)
	content.set_meta("codex_active_section", "characters")

	# Табы разделов: глобальный кит (имя CodexTab_* мапится на нативный тип
	# codex_tab), слева — пиксельная эмблема раздела codex_pl_icon_*.
	var tab_height := roundf(clampf(96.0 * s, 50.0, 100.0))
	for section in CODEX_SECTIONS:
		var section_id := str(section["id"])
		var tab_button := _make_button(str(section["title"]))
		tab_button.name = "CodexTab_%s" % section_id
		tab_button.custom_minimum_size = Vector2(0.0, tab_height)
		_apply_fantasy_button_theme(tab_button)
		tab_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		# Однострочная подпись с clip/ellipsis (Label рендерит шире мерки) и
		# вертикальные content-margins кит-стиля, сжатые под высоту плитки —
		# иначе фикс-32px маргины кита распирают вертикальный стек за safe-зону.
		tab_button.autowrap_mode = TextServer.AUTOWRAP_OFF
		tab_button.clip_text = true
		tab_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tab_button.add_theme_font_size_override("font_size", _readable_font_size(15))
		for tab_state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var tab_style := tab_button.get_theme_stylebox(tab_state)
			if tab_style != null:
				tab_style.content_margin_top = maxf(12.0, roundf(32.0 * s))
				tab_style.content_margin_bottom = maxf(12.0, roundf(32.0 * s))
		var icon_path := str(CODEX_PL_ICONS.get(section_id, ""))
		if icon_path != "" and ResourceLoader.exists(icon_path):
			tab_button.icon = game._cached_texture(icon_path)
			tab_button.expand_icon = false
			tab_button.add_theme_constant_override("icon_max_width", int(roundf(40.0 * s)))
		tab_button.pressed.connect(_show_codex_section.bind(content, section_id))
		tabs_row.add_child(tab_button)

	_show_codex_section(content, "characters")

	# Полая орнаментная рама кита ПОВЕРХ контента — строго последним слоем.
	_unified_add_frame(root, "Codex")

	# SCRUM-813: стартовый фокус — первая вкладка кодекса; LB/RB листают разделы
	# (см. _handle_menu_shoulder_nav), карточки записей фокусируемы и прокручиваются
	# (follow_focus). B/Esc = назад в меню.
	_ensure_run_ui_gamepad_bindings()
	var first_codex_tab := tabs_row.get_node_or_null("CodexTab_characters") as Button
	if first_codex_tab != null:
		first_codex_tab.focus_mode = Control.FOCUS_ALL
		first_codex_tab.call_deferred("grab_focus")


func _show_codex_section(content: PanelContainer, section_id: String) -> void:
	# Ленивое построение: раздел собирается при первом открытии и кэшируется
	# внутри экрана, остальные скрываются — меню не фризит на старте.
	if content == null or not is_instance_valid(content):
		return
	var detail_panel := content.get_meta("codex_detail_panel", null) as PanelContainer
	var tabs_row := content.get_meta("codex_tabs", null) as Control
	var section_host := content.get_meta("codex_section_host", content) as Control
	if section_host == null:
		section_host = content
	content.set_meta("codex_active_section", section_id)
	_codex_update_tab_selection(tabs_row, section_id)
	for child in section_host.get_children():
		child.visible = false
	var existing := section_host.get_node_or_null("CodexSection_%s" % section_id)
	if existing != null:
		existing.visible = true
		var default_detail: Dictionary = existing.get_meta("codex_default_detail", {})
		if detail_panel != null and not default_detail.is_empty():
			_codex_update_detail(detail_panel, default_detail)
			if existing.has_meta("codex_default_entry_button"):
				_codex_set_selected_entry(content, existing.get_meta("codex_default_entry_button") as Button)
		return

	var scroll := ScrollContainer.new()
	scroll.name = "CodexSection_%s" % section_id
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	# SCRUM-813: скролл секции следует за сфокусированной карточкой (крестовина/стик).
	scroll.follow_focus = true
	section_host.add_child(scroll)

	var list := VBoxContainer.new()
	list.name = "CodexSectionList_%s" % section_id
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", maxi(5, int(roundf(8.0 * _atlas_ui_scale()))))
	list.set_meta("codex_detail_panel", detail_panel)
	list.set_meta("codex_section_scroll", scroll)
	list.set_meta("codex_content_panel", content)
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
		if scroll.has_meta("codex_default_entry_button"):
			_codex_set_selected_entry(content, scroll.get_meta("codex_default_entry_button") as Button)


func _codex_entry_panel(list: VBoxContainer, detail_data := {}) -> HBoxContainer:
	# SCRUM-879: карточка записи — «кожаный ряд» единого чип-языка Атласа.
	var s := _atlas_ui_scale()
	var panel := Button.new()
	panel.name = "CodexEntryCard"
	panel.text = ""
	panel.custom_minimum_size = Vector2(0.0, roundf(clampf(96.0 * s, 64.0, 104.0)))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.focus_mode = Control.FOCUS_ALL
	_unified_apply_row_theme(panel, 10.0, false)
	list.add_child(panel)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Контент в content-зоне чип-стиля ряда (pad 10 → 14/10, см. _atlas_chip_style).
	row.offset_left = 14.0
	row.offset_top = 10.0
	row.offset_right = -14.0
	row.offset_bottom = -10.0
	row.add_theme_constant_override("separation", int(roundf(14.0 * s)))
	panel.add_child(row)
	row.set_meta("entry_button", panel)
	if detail_data is Dictionary and not (detail_data as Dictionary).is_empty():
		_codex_attach_entry_detail(list, row, detail_data)
	return row


# Квадрат портрета/иконки в чип-ряду записи (влезает в content-зону карточки).
func _codex_entry_portrait_size() -> Vector2:
	return Vector2.ONE * roundf(clampf(56.0 * _atlas_ui_scale(), 36.0, 60.0))


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
	# Слот в карточке-строке: фикс-квадрат, по вертикали ужимается и центрируется,
	# чтобы НИКОГДА не превышать content-зону чип-ряда (не торчал сверху/снизу).
	slot.custom_minimum_size = size + Vector2(6.0, 6.0)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var slot_style := _atlas_translucent_style(0.45, 6.0)
	slot_style.set_content_margin_all(3.0)
	slot.add_theme_stylebox_override("panel", slot_style)
	_codex_pl_make_nearest(slot)
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
	_codex_pl_make_nearest(portrait)
	slot.add_child(portrait)


func _codex_label(parent: Control, text: String, font_size: int, color: Color, max_lines := 0) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", _codex_font_size(font_size, 10, 44))
	label.add_theme_color_override("font_color", color)
	if max_lines > 0:
		label.clip_text = true
		label.max_lines_visible = max_lines
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.custom_minimum_size.y = ceilf(float(_codex_font_size(font_size, 10, 44) * max_lines) * 1.18)
	parent.add_child(label)
	return label


func _codex_font_size(base_size: int, min_size := 10, max_size := 44) -> int:
	# SCRUM-879: единая шрифтовая шкала проекта (вместо собственной v2-шкалы кодекса).
	return _readable_font_size(base_size, min_size, max_size)


func _codex_update_tab_selection(tabs_row: Control, section_id: String) -> void:
	# Активный/неактивные табы — модуляцией, как _atlas_apply_tab_state.
	if tabs_row == null:
		return
	for child in tabs_row.get_children():
		var button := child as Button
		if button == null:
			continue
		var selected := button.name == "CodexTab_%s" % section_id
		button.modulate = Color(1.0, 0.94, 0.74, 1.0) if selected else Color(0.74, 0.76, 0.84, 0.92)


# Подсветка выбранной карточки записи: перекладываем «кожаный ряд» selected-стилем.
func _codex_set_selected_entry(content: PanelContainer, button: Button) -> void:
	if content == null or not is_instance_valid(content) or button == null or not is_instance_valid(button):
		return
	var previous: Button = null
	if content.has_meta("codex_selected_entry"):
		previous = content.get_meta("codex_selected_entry") as Button
	if previous == button:
		return
	if previous != null and is_instance_valid(previous):
		_unified_apply_row_theme(previous, 10.0, false)
	_unified_apply_row_theme(button, 10.0, true)
	content.set_meta("codex_selected_entry", button)


func _codex_attach_entry_detail(list: VBoxContainer, row: HBoxContainer, detail_data: Dictionary) -> void:
	var button := row.get_meta("entry_button", null) as Button
	var detail_panel := list.get_meta("codex_detail_panel", null) as PanelContainer
	var scroll := list.get_meta("codex_section_scroll", null) as ScrollContainer
	var content := list.get_meta("codex_content_panel", null) as PanelContainer
	if scroll != null and not scroll.has_meta("codex_default_detail"):
		scroll.set_meta("codex_default_detail", detail_data)
		if button != null:
			scroll.set_meta("codex_default_entry_button", button)
	if button == null or detail_panel == null:
		return
	button.set_meta("codex_detail_data", detail_data)
	button.pressed.connect(func() -> void:
		_codex_set_selected_entry(content, button)
		_codex_update_detail(detail_panel, detail_data)
	)


func _codex_update_detail(detail_panel: PanelContainer, detail_data: Dictionary) -> void:
	# SCRUM-879: досье записи — VBox в панели-чипе Атласа: титул золотом →
	# портрет-слот (полупрозрачный, KEEP_ASPECT) → чипы-ряды → «тёмная кожа»
	# вместо пергамента, тексты светлые (как панель узла Атласа).
	if detail_panel == null or not is_instance_valid(detail_panel):
		return
	for child in detail_panel.get_children():
		detail_panel.remove_child(child)
		child.queue_free()
	var s := _atlas_ui_scale()
	var box := VBoxContainer.new()
	box.name = "CodexDetailContent"
	box.add_theme_constant_override("separation", int(roundf(8.0 * s)))
	detail_panel.add_child(box)

	var title := Label.new()
	title.name = "CodexDetailTitle"
	title.text = str(detail_data.get("title", ""))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", _codex_font_size(22, 16, 30))
	title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	box.add_child(title)

	var texture := detail_data.get("texture", null) as Texture2D
	if texture != null:
		# SCRUM-881: слот арта ниже прежнего (300s против 360s) — высота досье
		# уходит глубокому структурированному тексту.
		var portrait_slot := PanelContainer.new()
		portrait_slot.name = "CodexDetailPortraitSlot"
		portrait_slot.custom_minimum_size = Vector2(0.0, roundf(clampf(300.0 * s, 150.0, 320.0)))
		portrait_slot.add_theme_stylebox_override("panel", _atlas_translucent_style(0.55, 10.0))
		box.add_child(portrait_slot)
		var portrait := TextureRect.new()
		portrait.name = "CodexDetailPortraitTexture"
		portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture = texture
		_codex_pl_make_nearest(portrait)
		portrait_slot.add_child(portrait)

	var chips: Array = detail_data.get("chips", [])
	if not chips.is_empty():
		var chip_row := HBoxContainer.new()
		chip_row.name = "CodexDetailChipRow"
		chip_row.alignment = BoxContainer.ALIGNMENT_CENTER
		chip_row.add_theme_constant_override("separation", int(roundf(8.0 * s)))
		box.add_child(chip_row)
		var chip_limit := mini(4, chips.size())
		for chip_index in range(chip_limit):
			var chip_text = chips[chip_index]
			var chip := PanelContainer.new()
			chip.name = "CodexDetailChip"
			chip.add_theme_stylebox_override("panel", _atlas_chip_style(0.86, roundf(6.0 * s)))
			chip_row.add_child(chip)
			var chip_label := Label.new()
			chip_label.text = str(chip_text)
			chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			chip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			chip_label.clip_text = true
			chip_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			chip_label.add_theme_font_size_override("font_size", _codex_font_size(14, 11, 18))
			chip_label.add_theme_color_override("font_color", Color(0.78, 0.66, 0.44, 1.0))
			chip.add_child(chip_label)

	var parchment := PanelContainer.new()
	parchment.name = "CodexDetailParchmentInset"
	parchment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parchment.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parchment.add_theme_stylebox_override("panel", _atlas_chip_style(0.62, roundf(10.0 * s)))
	box.add_child(parchment)
	var text_scroll := ScrollContainer.new()
	text_scroll.name = "CodexDetailTextScroll"
	text_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parchment.add_child(text_scroll)
	var text_box := VBoxContainer.new()
	text_box.name = "CodexDetailTextBody"
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 7)
	text_scroll.add_child(text_box)
	# SCRUM-881: глубокое досье — структурированные секции (бронзовый заголовок →
	# титулы записей золотом → светлое тело) из СУЩЕСТВУЮЩИХ данных
	# codex_data/ProgressionData; сырой body_lines остаётся fallback-путём.
	var sections: Array = detail_data.get("sections", [])
	if sections.is_empty():
		var lines: Array = detail_data.get("body_lines", [])
		for line in lines:
			if str(line) != "":
				_codex_label(text_box, str(line), 15, Color(0.88, 0.92, 0.98, 0.96))
	else:
		var heading_index := 0
		for section in sections:
			var section_dict := section as Dictionary
			if section_dict == null or section_dict.is_empty():
				continue
			var heading := str(section_dict.get("heading", ""))
			if heading != "":
				if heading_index > 0:
					var section_gap := Control.new()
					section_gap.custom_minimum_size = Vector2(0.0, roundf(6.0 * s))
					text_box.add_child(section_gap)
				var heading_label := _codex_label(text_box, heading, 17, Color(0.78, 0.66, 0.44, 1.0))
				heading_label.name = "CodexDetailSectionHeading_%d" % heading_index
				heading_index += 1
			for line in section_dict.get("lines", []):
				if line is Dictionary:
					var line_dict := line as Dictionary
					var line_title := str(line_dict.get("title", ""))
					if line_title != "":
						_codex_label(text_box, line_title, 15, Color(0.96, 0.90, 0.68, 1.0))
					var line_text := str(line_dict.get("text", ""))
					if line_text != "":
						_codex_label(text_box, line_text, 15, Color(0.88, 0.92, 0.98, 0.96))
				elif str(line) != "":
					_codex_label(text_box, str(line), 15, Color(0.88, 0.92, 0.98, 0.96))


# SCRUM-884 (фидбек юзера): всплывающие подсказки глоссария и отдельные
# term-кнопки упразднены — термины стали обычными карточками списка кодекса,
# определение показывает правое досье (_codex_glossary_sections).


# --- SCRUM-881: секции глубокого досье. СТРОГО существующие данные из
# codex_data/ProgressionData/StatFormulas/GLOSSARY; пустое поле = секция/строка
# пропускается (никаких заглушек). Формат: [{heading, lines:[String|{title,text}]}].
func _codex_character_sections(character: Dictionary) -> Array:
	var character_id := str(character.get("id", ""))
	var sections := []
	# Идентичность/роль: описание конфига + механическая идентичность класса + плейстайл.
	var identity: Dictionary = game.PROGRESSION_DATA.class_mechanic_identity(character_id)
	var identity_lines := []
	if str(character.get("description", "")) != "":
		identity_lines.append(str(character["description"]))
	var identity_title := str(identity.get("identity_title", ""))
	var identity_summary := str(identity.get("summary", ""))
	if identity_title != "" or identity_summary != "":
		identity_lines.append({"title": identity_title, "text": identity_summary})
	if str(character.get("playstyle", "")) != "":
		identity_lines.append(str(character["playstyle"]))
	if not identity_lines.is_empty():
		sections.append({"heading": "Идентичность и роль", "lines": identity_lines})
	# Сильные и слабые стороны.
	var side_lines := []
	if str(character.get("strengths", "")) != "":
		side_lines.append("Сильное: %s" % character["strengths"])
	if str(character.get("weaknesses", "")) != "":
		side_lines.append("Слабое: %s" % character["weaknesses"])
	if not side_lines.is_empty():
		sections.append({"heading": "Сильные и слабые стороны", "lines": side_lines})
	# 8 базовых характеристик компактными парами; ★ — главный стат класса.
	var base_stats: Dictionary = game.PROGRESSION_DATA.base_stats(character_id)
	var main_attribute := str(game.PROGRESSION_DATA.class_main_attribute(character_id))
	var stat_lines := []
	var stat_pair := PackedStringArray()
	for stat_id in game.PROGRESSION_DATA.STAT_NAMES.keys():
		var stat_piece := "%s: %d" % [str(game.PROGRESSION_DATA.STAT_NAMES[stat_id]), int(roundf(float(base_stats.get(stat_id, 0.0))))]
		if str(stat_id) == main_attribute:
			stat_piece += " ★"
		stat_pair.append(stat_piece)
		if stat_pair.size() == 2:
			stat_lines.append("  ·  ".join(stat_pair))
			stat_pair = PackedStringArray()
	if stat_pair.size() > 0:
		stat_lines.append("  ·  ".join(stat_pair))
	var priorities: Array = game.PROGRESSION_DATA.attribute_priorities(character_id)
	if not priorities.is_empty():
		var priority_names := PackedStringArray()
		for priority_id in priorities:
			priority_names.append(str(game.PROGRESSION_DATA.STAT_NAMES.get(priority_id, priority_id)))
		stat_lines.append("Приоритеты прокачки: %s." % " → ".join(priority_names))
	if not stat_lines.is_empty():
		sections.append({"heading": "Базовые характеристики", "lines": stat_lines})
	# Три оружия: полное описание + identity-строка механики из ProgressionData.
	var weapon_lines := []
	for weapon in character.get("weapons", []):
		var weapon_text := str(weapon.get("description", ""))
		var weapon_identity := str(game.PROGRESSION_DATA.weapon_mechanic_identity(character_id, str(weapon.get("id", ""))))
		if weapon_identity != "":
			weapon_text += "\nМеханика: %s." % weapon_identity
		weapon_lines.append({"title": str(weapon.get("title", "")), "text": weapon_text})
	if not weapon_lines.is_empty():
		sections.append({"heading": "Оружие", "lines": weapon_lines})
	# Ультимейт: описание + реальные параметры конфига (только присутствующие).
	var ultimate: Dictionary = character.get("ultimate", {})
	if not ultimate.is_empty():
		var ultimate_lines := [{"title": str(ultimate.get("title", "")), "text": str(ultimate.get("description", ""))}]
		var ultimate_bits := PackedStringArray()
		if float(ultimate.get("radius", 0.0)) > 0.0:
			ultimate_bits.append("радиус %d" % int(ultimate["radius"]))
		if float(ultimate.get("damage", 0.0)) > 0.0:
			ultimate_bits.append("урон ×%.2f" % float(ultimate["damage"]))
		if float(ultimate.get("duration", 0.0)) > 0.0:
			ultimate_bits.append("длительность %.1f с" % float(ultimate["duration"]))
		if int(ultimate.get("target_count", 0)) > 0:
			ultimate_bits.append("до %d целей" % int(ultimate["target_count"]))
		if float(ultimate.get("heal_ratio", 0.0)) > 0.0:
			ultimate_bits.append("лечение %d%% урона" % int(roundf(float(ultimate["heal_ratio"]) * 100.0)))
		if not ultimate_bits.is_empty():
			ultimate_lines.append("Параметры: %s." % "; ".join(ultimate_bits))
		sections.append({"heading": "Ультимейт", "lines": ultimate_lines})
	# Классовые вознесения: реальные титулы ступеней из ASCENSION_LEVELS.
	var ascension_levels: Array = game.PROGRESSION_DATA.ascension_levels(character_id)
	if not ascension_levels.is_empty():
		var ascension_names := PackedStringArray()
		for ascension_entry in ascension_levels:
			var ascension_title := str((ascension_entry as Dictionary).get("title", ""))
			if ascension_title != "":
				ascension_names.append(ascension_title)
		if not ascension_names.is_empty():
			sections.append({"heading": "Вознесения класса", "lines": ["Ступени: %s." % " → ".join(ascension_names)]})
	return sections


func _codex_monster_sections(monster: Dictionary) -> Array:
	var monster_id := str(monster.get("id", ""))
	var kind := str(monster.get("kind", "standard"))
	var sections := []
	# Профиль угрозы: тип из ENEMY_SIZE_PROFILES + поведение.
	var profile_id := "ordinary"
	match kind:
		"elite":
			profile_id = "elite"
		"mini_elite":
			profile_id = "mini_elite"
		"boss":
			profile_id = "boss"
	var size_profile: Dictionary = game.PROGRESSION_DATA.enemy_size_profile(profile_id)
	var behavior_lines := []
	if str(size_profile.get("label", "")) != "":
		behavior_lines.append("Класс угрозы: %s (габарит ×%.2f)." % [str(size_profile["label"]), float(size_profile.get("scale", 1.0))])
	if str(monster.get("behavior", "")) != "":
		behavior_lines.append(str(monster["behavior"]))
	if not behavior_lines.is_empty():
		sections.append({"heading": "Тип и поведение", "lines": behavior_lines})
	# Умения — канонические имена и описания из codex_data.
	var ability_lines := []
	for ability in monster.get("abilities", []):
		ability_lines.append({"title": str((ability as Dictionary).get("title", "")), "text": str((ability as Dictionary).get("description", ""))})
	if not ability_lines.is_empty():
		sections.append({"heading": "Умения", "lines": ability_lines})
	# Боевой паттерн элиток/боссов: UNIQUE_ENCOUNTER_PATTERNS + каталог механик.
	var pattern: Dictionary = game.PROGRESSION_DATA.unique_encounter_pattern(monster_id)
	if not pattern.is_empty():
		var pattern_lines := []
		if str(pattern.get("summary", "")) != "":
			pattern_lines.append({"title": str(pattern.get("title", "")), "text": "Паттерн боя: %s." % str(pattern["summary"])})
		var mechanic_catalog: Dictionary = game.PROGRESSION_DATA.enemy_mechanic_catalog()
		for mechanic_id in pattern.get("mechanics", []):
			var mechanic: Dictionary = mechanic_catalog.get(str(mechanic_id), {})
			if mechanic.is_empty():
				continue
			var mechanic_text := str(mechanic.get("desc", ""))
			if bool(mechanic.get("telegraph", false)):
				mechanic_text += " Телеграфится заранее."
			pattern_lines.append({"title": str(mechanic.get("title", mechanic_id)), "text": mechanic_text})
		if not pattern_lines.is_empty():
			sections.append({"heading": "Боевой паттерн", "lines": pattern_lines})
	# Боевые параметры из конфигов: спецатака элитки / множители мини-элитки.
	var combat_lines := []
	var attack_source_id := monster_id
	var mini_kind: Dictionary = {}
	if kind == "mini_elite":
		mini_kind = game.PROGRESSION_DATA.mini_elite_kind_by_id(monster_id)
		if not mini_kind.is_empty():
			combat_lines.append("Относительно базовой элитки: здоровье ×%.2f; скорость ×%.2f; урон ×%.2f." % [float(mini_kind.get("hp_mult", 1.0)), float(mini_kind.get("speed_mult", 1.0)), float(mini_kind.get("damage_mult", 1.0))])
			attack_source_id = str(mini_kind.get("behavior", monster_id))
	var attack_config: Dictionary = game.PROGRESSION_DATA.elite_attack_config(attack_source_id)
	if not attack_config.is_empty():
		var attack_bits := PackedStringArray()
		if float(attack_config.get("cooldown", 0.0)) > 0.0:
			attack_bits.append("перезарядка %.1f с" % float(attack_config["cooldown"]))
		if float(attack_config.get("trigger_range", 0.0)) > 0.0:
			attack_bits.append("дистанция срабатывания %d" % int(attack_config["trigger_range"]))
		if float(attack_config.get("radius", 0.0)) > 0.0:
			attack_bits.append("радиус %d" % int(attack_config["radius"]))
		if float(attack_config.get("damage_factor", 0.0)) > 0.0:
			attack_bits.append("урон ×%.1f от базового" % float(attack_config["damage_factor"]))
		if not attack_bits.is_empty():
			combat_lines.append("Спецатака: %s." % "; ".join(attack_bits))
	if not combat_lines.is_empty():
		sections.append({"heading": "Боевые параметры", "lines": combat_lines})
	return sections


func _codex_artifact_sections(artifact: Dictionary, definition: Dictionary) -> Array:
	var sections := []
	# Полный текст эффекта + интерпретация для текущего класса (если тематика чужая).
	var effect_lines := []
	if str(artifact.get("description", "")) != "":
		effect_lines.append(str(artifact["description"]))
	var affinity_note := _artifact_affinity_note(definition)
	if not affinity_note.is_empty():
		effect_lines.append(str(affinity_note["text"]))
	if not effect_lines.is_empty():
		sections.append({"heading": "Эффект", "lines": effect_lines})
	# Свойства: редкость/источник, цена, активность-триггер.
	var property_lines := []
	if str(artifact.get("source", "")) == "shop":
		property_lines.append("Источник: походный магазин.")
	else:
		property_lines.append("Редкость: %s." % _artifact_tier_text(definition))
	if definition.has("cost"):
		property_lines.append("Базовая цена: %d золота." % int(definition.get("cost", 0)))
	if bool(definition.get("active", false)):
		property_lines.append("Активный артефакт: срабатывает сам по триггеру из описания эффекта.")
	if not property_lines.is_empty():
		sections.append({"heading": "Свойства", "lines": property_lines})
	# Тематика классов + каноническое пояснение из глоссария.
	var affinity_list: Array = definition.get("class_affinity", [])
	if not affinity_list.is_empty():
		var class_names := PackedStringArray()
		for class_id in affinity_list:
			class_names.append(str(CLASS_RU.get(class_id, class_id)))
		var affinity_lines := ["Задуман для: %s." % ", ".join(class_names)]
		var affinity_term: Dictionary = GLOSSARY.definition("affinity")
		if str(affinity_term.get("desc", "")) != "":
			affinity_lines.append(str(affinity_term["desc"]))
		sections.append({"heading": "Тематика классов", "lines": affinity_lines})
	return sections


func _codex_stat_sections(stat: Dictionary) -> Array:
	var stat_id := str(stat.get("id", ""))
	var sections := []
	var description_lines := []
	if str(stat.get("description", "")) != "":
		description_lines.append(str(stat["description"]))
	var stat_definition: Dictionary = StatFormulas.STAT_DEFINITIONS.get(stat_id, {})
	if str(stat_definition.get("formula", "")) != "":
		description_lines.append("Формула: %s" % str(stat_definition["formula"]))
	if not description_lines.is_empty():
		sections.append({"heading": "Описание", "lines": description_lines})
	if str(stat.get("influences", "")) != "":
		sections.append({"heading": "Влияние", "lines": ["Влияет на: %s" % str(stat["influences"])]})
	# Связанные записи: классы, у которых этот стат — главный (identity-данные).
	if str(stat.get("type", "")) == "base":
		var main_class_names := PackedStringArray()
		for character_id in game.PROGRESSION_DATA.character_ids():
			if str(game.PROGRESSION_DATA.class_main_attribute(str(character_id))) == stat_id:
				var config: Dictionary = game.PROGRESSION_DATA.character_config(str(character_id))
				main_class_names.append(str(config.get("title", character_id)))
		if not main_class_names.is_empty():
			sections.append({"heading": "Связанные классы", "lines": ["Главный стат для: %s." % ", ".join(main_class_names)]})
	return sections


func _codex_glossary_sections(term_id: String, definition: Dictionary) -> Array:
	var sections := []
	if str(definition.get("desc", "")) != "":
		sections.append({"heading": "Определение", "lines": [str(definition["desc"])]})
	# Связанная характеристика: термин с тем же id в реестре статов.
	var stat_definition: Dictionary = StatFormulas.STAT_DEFINITIONS.get(term_id, {})
	if not stat_definition.is_empty():
		var stat_lines := []
		if str(stat_definition.get("description", "")) != "":
			stat_lines.append(str(stat_definition["description"]))
		if str(stat_definition.get("influences", "")) != "":
			stat_lines.append("Влияет на: %s" % str(stat_definition["influences"]))
		if not stat_lines.is_empty():
			sections.append({"heading": "Связанная характеристика", "lines": stat_lines})
	return sections


func _codex_ascension_sections(entry: Dictionary) -> Array:
	var sections := []
	if str(entry.get("description", "")) != "":
		sections.append({"heading": "Усложнение", "lines": [str(entry["description"])]})
	# Кумулятив: уровень N включает все усложнения 1..N (реальный хелпер данных).
	var cumulative_lines: Array = game.PROGRESSION_DATA.ascension_modifier_lines(int(entry.get("level", 0)))
	if not cumulative_lines.is_empty():
		sections.append({"heading": "Кумулятивно на этом уровне", "lines": cumulative_lines})
	return sections


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
			"summary": str(character["playstyle"]),
			"texture": texture,
			"covered_portrait": true,
			"chips": ["Герой", str(character.get("id", ""))],
			"body_lines": body_lines,
			"sections": _codex_character_sections(character),
		})
		_codex_portrait(row, str(character["sprite"]), _codex_entry_portrait_size())
		var text_box := VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		text_box.add_theme_constant_override("separation", 4)
		row.add_child(text_box)
		_codex_label(text_box, "%s — %s" % [character["title"], character["playstyle"]], 12, CODEX_PL_CARD_BODY_COLOR, 2)


func _build_codex_monsters(list: VBoxContainer) -> void:
	var kind_titles := {"standard": "Обычные Монстры", "elite": "Элитные Монстры", "mini_elite": "Мини-элитки (свита Возвышения)", "boss": "Боссы"}
	for kind in ["standard", "elite", "mini_elite", "boss"]:
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
				"summary": str(monster["behavior"]),
				"texture": texture,
				"covered_portrait": false,
				"chips": [str(kind_titles[kind]), str(monster["id"])],
				"body_lines": body_lines,
				"sections": _codex_monster_sections(monster),
			})
			_codex_portrait(row, str(monster["sprite"]), _codex_entry_portrait_size())
			var text_box := VBoxContainer.new()
			text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			text_box.add_theme_constant_override("separation", 3)
			row.add_child(text_box)
			_codex_label(text_box, "%s (%s) — %s" % [monster["title"], monster["id"], monster["behavior"]], 11, CODEX_PL_CARD_BODY_COLOR, 2)


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
			"summary": str(artifact["description"]),
			"texture": icon_texture,
			"covered_portrait": false,
			"chips": [_artifact_tier_text(artifact_definition), str(artifact["id"])],
			"body_lines": body_lines,
			"sections": _codex_artifact_sections(artifact, artifact_definition),
		})
		_codex_icon_slot(row, icon_texture, _codex_entry_portrait_size(), "CodexArtifactIconSlot")
		var text_box := VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(text_box)
		_codex_label(text_box, "%s [%s] — %s" % [artifact["title"], _artifact_tier_text(artifact_definition), artifact["description"]], 11, CODEX_PL_CARD_BODY_COLOR, 2)


func _build_codex_ascensions(list: VBoxContainer) -> void:
	for entry in CODEX_DATA.ascensions():
		var row := _codex_entry_panel(list, {
			"title": "%d. %s" % [entry["level"], entry["title"]],
			"summary": str(entry["description"]),
			"chips": ["Возвышение", "ур. %d" % entry["level"]],
			"body_lines": [str(entry["description"])],
			"sections": _codex_ascension_sections(entry),
		})
		var text_box := VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(text_box)
		_codex_label(text_box, "%d. %s — %s" % [entry["level"], entry["title"], entry["description"]], 12, CODEX_PL_CARD_BODY_COLOR, 2)


func _build_codex_stats(list: VBoxContainer) -> void:
	var type_titles := {"base": "Базовые Характеристики", "derived": "Производные Параметры"}
	for stat_type in ["base", "derived"]:
		for stat in CODEX_DATA.stats():
			if str(stat["type"]) != stat_type:
				continue
			var row := _codex_entry_panel(list, {
				"title": str(stat["title"]),
				"summary": str(stat["description"]),
				"chips": [str(type_titles.get(stat_type, stat_type)), str(stat["id"])],
				"body_lines": [
					str(stat["description"]),
					"Влияет на: %s" % stat["influences"] if str(stat["influences"]) != "" else "",
				],
				"sections": _codex_stat_sections(stat),
			})
			var icon_control: Control = game.UIIconRegistry.make_icon(str(stat["id"]), Vector2(36, 36))
			row.add_child(icon_control)
			var text_box := VBoxContainer.new()
			text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(text_box)
			_codex_label(text_box, "%s — %s" % [stat["title"], stat["description"]], 11, CODEX_PL_CARD_BODY_COLOR, 2)


func _build_codex_glossary(list: VBoxContainer) -> void:
	# SCRUM-884: термин — обычная карточка списка (тот же чип-ряд, что у прочих
	# разделов): имя золотом + краткое определение; клик показывает полное
	# определение в правом досье (_codex_glossary_sections). Тултипы упразднены.
	for term_id in GLOSSARY.term_ids():
		var definition: Dictionary = GLOSSARY.definition(term_id)
		var row := _codex_entry_panel(list, {
			"title": str(definition.get("name", term_id)),
			"summary": str(definition.get("desc", "")),
			"chips": ["Глоссарий", str(term_id)],
			"body_lines": [str(definition.get("desc", ""))],
			"sections": _codex_glossary_sections(str(term_id), definition),
		})
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(box)
		var term_name := _codex_label(box, str(definition.get("name", term_id)), 12, Color(0.96, 0.90, 0.68, 1.0), 1)
		term_name.name = "GlossaryTermName_%s" % term_id
		_codex_label(box, str(definition.get("desc", "")), 12, CODEX_PL_CARD_BODY_COLOR, 2)


func _apply_control_rect(control: Control, rect: Rect2) -> void:
	if control == null or not is_instance_valid(control):
		return
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.position.x + rect.size.x
	control.offset_bottom = rect.position.y + rect.size.y


func _settings_v6_font(design_px: float, s: float) -> int:
	# Кегль скейлится вместе с сеткой (s), пол 12px. На 1080p (s=0.75)
	# label 26 → 19.5px, статус 22 → 16.5px — читаемо по дизайн-инварианту.
	return maxi(12, int(roundf(design_px * s)))


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


func _pending_screen_index(screen_count: int) -> int:
	_ensure_settings_video_pending()
	return clampi(int(settings_video_pending.get("screen_index", game.selected_screen_index)), 0, maxi(screen_count - 1, 0))


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

	# --- Ряд 2: свитчер табов — кнопки глобального кита на плите «Назад»,
	# фикс-сетка 3×260×_atlas_action_button_height() (SCRUM-882) ---
	var switcher_row := HBoxContainer.new()
	switcher_row.name = "SettingsSwitcherRow"
	switcher_row.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(switcher_row)
	switcher_row.add_child(_make_settings_tab_switcher(tabs, s))

	# --- Ряд 3: контент-панель — чип Атласа (как AtlasNodePanel), табы внутри.
	# Фидбек 2026-07-08: панель ОБЖИМАЕТ контент по ширине (колонка + поля чипа),
	# а не тянется на всю safe-зону — пустых боков во фрейме нет.
	var content_panel := PanelContainer.new()
	content_panel.name = "SettingsContentPanel"
	var content_chip_pad := roundf(16.0 * s_ui)
	content_panel.add_theme_stylebox_override("panel", _atlas_chip_style(0.88, content_chip_pad))
	var settings_panel_w := settings_column_w + (content_chip_pad * 1.4 + 8.0 * s_ui) * 2.0 + 24.0
	content_panel.custom_minimum_size = Vector2(settings_panel_w, 0.0)
	content_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_panel.clip_contents = true
	layout.add_child(content_panel)
	# Малые поля: content-margins самого чипа уже держат контент на тёмном поле.
	var content_margin := MarginContainer.new()
	content_margin.name = "SettingsContentSafe"
	content_margin.add_theme_constant_override("margin_left", int(8.0 * s_ui))
	content_margin.add_theme_constant_override("margin_top", int(8.0 * s_ui))
	content_margin.add_theme_constant_override("margin_right", int(8.0 * s_ui))
	content_margin.add_theme_constant_override("margin_bottom", int(8.0 * s_ui))
	content_panel.add_child(content_margin)
	content_margin.add_child(tabs)

	var screen_tab := _make_settings_tab("Экран", s, settings_column_w)
	var screen_box := screen_tab.get_child(0) as VBoxContainer
	tabs.add_child(screen_tab)

	var screen_count := DisplayServer.get_screen_count()
	var pending_screen := _pending_screen_index(screen_count)
	if screen_count > 1:
		var screen_options := OptionButton.new()
		screen_options.name = "SettingsScreenOption"
		_settings_v6_apply_field_theme(screen_options, s)
		for screen_index in range(screen_count):
			var size := DisplayServer.screen_get_size(screen_index)
			screen_options.add_item("Экран %d (%dx%d)" % [screen_index + 1, size.x, size.y])
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
	pending_label.add_theme_font_size_override("font_size", _settings_v6_font(22.0, s))
	pending_label.add_theme_color_override("font_color", SETTINGS_V6_AMBER if _settings_video_dirty() else SETTINGS_V6_MUTED)
	screen_box.add_child(pending_label)

	var audio_tab := _make_settings_tab("Звук", s, settings_column_w)
	var audio_box := audio_tab.get_child(0) as VBoxContainer
	tabs.add_child(audio_tab)
	_add_volume_row(audio_box, "Общая громкость", "master_volume", "", s)
	_add_volume_row(audio_box, "Музыка", "music_volume", "music_enabled", s)
	_add_volume_row(audio_box, "Эффекты", "sfx_volume", "sfx_enabled", s)
	# SCRUM-879: кит-натив standard_420x104 (маппинг по имени кнопки).
	var reset_audio_button := _settings_v6_make_action_button("Сбросить звук", "SettingsResetAudioButton", 420.0, 104.0)
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
	device_hint.add_theme_font_size_override("font_size", _settings_v6_font(20.0, s))
	device_hint.add_theme_color_override("font_color", SETTINGS_V6_HINT_BLUE)
	controls_box.add_child(device_hint)

	var gamepad_status := Label.new()
	gamepad_status.name = "SettingsGamepadStatus"
	gamepad_status.add_theme_font_size_override("font_size", _settings_v6_font(22.0, s))
	gamepad_status.add_theme_color_override("font_color", SETTINGS_V6_AMBER)
	controls_box.add_child(gamepad_status)
	_gamepad_status_label = gamepad_status
	_connect_gamepad_status_signals()
	_refresh_gamepad_status_line()

	var aim_options := OptionButton.new()
	aim_options.name = "SettingsAimModeOption"
	_settings_v6_apply_field_theme(aim_options, s)
	aim_options.add_item("Автонаводка на ближайшего")
	aim_options.add_item("По курсору")
	aim_options.selected = 1 if str(game.aim_mode) == "cursor" else 0
	aim_options.item_selected.connect(func(index: int) -> void:
		game.aim_mode = "cursor" if index == 1 else "nearest"
		game.get_tree().root.set_meta("aim_mode", game.aim_mode)
		game.save_game_settings()
	)
	_add_settings_control_row(controls_box, "Прицеливание", aim_options, s)

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
	hint_label.add_theme_font_size_override("font_size", _settings_v6_font(22.0, s))
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
	gp_hint.add_theme_font_size_override("font_size", _settings_v6_font(20.0, s))
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
	deadzone_value.add_theme_font_size_override("font_size", _settings_v6_font(24.0, s))
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

	# --- Ряд 4: футер — «Вернуть»/«Применить» справа («Назад» теперь в шапке).
	# Кнопки глобального кита, фикс 280×64: Apply/Revert носят НАТИВНУЮ пластину
	# по size-маппингу кита (y<=66, 240<=x<360) — без даунскейла и растяжки.
	var action_row := HBoxContainer.new()
	action_row.name = "SettingsBottomActions"
	action_row.alignment = BoxContainer.ALIGNMENT_END
	action_row.add_theme_constant_override("separation", int(14.0 * s_ui))
	# Футер той же ширины, что панель: кнопки прижаты к её правому краю.
	action_row.custom_minimum_size = Vector2(settings_panel_w, 0.0)
	action_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	layout.add_child(action_row)
	var revert_button := _settings_v6_make_action_button("Вернуть", "SettingsRevertButton", 280.0, 64.0)
	revert_button.disabled = not _settings_video_dirty()
	revert_button.pressed.connect(_revert_pending_video_settings)
	action_row.add_child(revert_button)
	var apply_button := _settings_v6_make_action_button("Применить", "SettingsApplyButton", 280.0, 64.0)
	apply_button.disabled = not _settings_video_dirty()
	apply_button.pressed.connect(_apply_pending_video_settings)
	action_row.add_child(apply_button)
	_settings_fit_kit_row([revert_button, apply_button], 280.0, 64.0)

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
	if return_origin == SETTINGS_RETURN_RUN_PAUSE:
		game.pending_rebind_action = ""
		game.ui_escape_action = Callable()
		if game.ui_layer != null and is_instance_valid(game.ui_layer):
			game.ui_layer.queue_free()
		game.ui_layer = null
		_show_pause_menu(true)
		return
	_show_main_menu()


func _make_settings_tab_switcher(tabs: TabContainer, _s: float) -> Control:
	# SCRUM-882 (фидбек к SCRUM-879): табы настроек — тот же стиль, что у кнопки
	# «Назад»: 260×_atlas_action_button_height(); на высоте 104 size-маппинг кита
	# даёт ту же НАТИВНУЮ плиту back_260x104, что носит SettingsBackButton, на
	# компакт-высотах 88/72 кит штатно уходит в 9-slice-ветки (как табы Атласа).
	# Актив/неактив — модуляцией, иконки v6 остаются (32px — чтобы текст с
	# иконкой помещались в плоское поле плиты); гэп фикс 24 — сетка 828px
	# помещается даже в самой узкой safe-зоне рамы (912px на 1152×648).
	var switcher := Control.new()
	switcher.name = "SettingsTabSwitcher"
	switcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tab_width := 260.0
	var tab_height := _atlas_action_button_height()
	var tab_gap := 24.0
	switcher.custom_minimum_size = Vector2(tab_width * 3.0 + tab_gap * 2.0, tab_height)

	var buttons: Array[Button] = []
	var labels := ["Экран", "Звук", "Управление"]
	for tab_index in range(labels.size()):
		var button := _make_button(labels[tab_index])
		button.name = "SettingsTabButton_%d" % tab_index
		_set_action_button_size(button, tab_width, tab_height)
		var tab_left := float(tab_index) * (tab_width + tab_gap)
		button.set_anchors_preset(Control.PRESET_TOP_LEFT)
		button.offset_left = tab_left
		button.offset_top = 0.0
		button.offset_right = tab_left + tab_width
		button.offset_bottom = tab_height
		var icon := _settings_v6_icon(SETTINGS_V6_TAB_ICON_PATHS[tab_index], Vector2(32.0, 32.0), minf(1.0, tab_height / 104.0))
		if icon != null:
			button.icon = icon
			button.expand_icon = false
			button.add_theme_constant_override("icon_max_width", 32)
		button.tooltip_text = "Открыть вкладку: %s" % labels[tab_index]
		var target_tab := tab_index
		button.pressed.connect(func() -> void:
			tabs.current_tab = target_tab
		)
		switcher.add_child(button)
		buttons.append(button)
	# Плоское поле плиты back_260x104 — x∈[48,212] (по бокам драконьи головы
	# орнамента, промер арта): боковые поля контента 48; headless-мерку строки
	# держим с запасом ×0.72 — оконный рантайм рисует строку до ~1.4 шире
	# headless-мерки, а фидбек требует, чтобы текст и иконка помещались целиком.
	_settings_fit_kit_row(buttons, tab_width, tab_height, 48.0, 0.72)

	var update_buttons := func(active_tab: int) -> void:
		# Актив/неактив — модуляцией, теми же тонами, что _atlas_apply_tab_state.
		var active_tint := Color(1.0, 0.94, 0.74)
		var idle_tint := Color(0.74, 0.76, 0.84, 0.92)
		for button_index in range(buttons.size()):
			buttons[button_index].modulate = active_tint if button_index == active_tab else idle_tint
	update_buttons.call(tabs.current_tab)
	tabs.tab_changed.connect(func(tab_index: int) -> void:
		update_buttons.call(tab_index)
	)
	return switcher


func _settings_fit_kit_row(row_buttons: Array, button_width: float, button_height: float, side_pad := 0.0, fit_ratio := 1.0) -> void:
	# SCRUM-879: кит-кнопки в фиксированных слотах модалки (табы 84×s, нижний
	# ряд 80×s). Пластины кита не искажаем (те же текстуры, 9-slice-раскрой),
	# но контент доводим под слот: подпись одной строкой (autowrap раздувает
	# min-height Button двухстрочным переносом и распирает кнопку за слот —
	# матрица ловит наезд на соседей), ЕДИНЫЙ для ряда кегль по самой длинной
	# подписи, вертикальные content-margins дозируем от высоты слота; клип —
	# страховка оконного рендера (строка в окне до ×1.5 шире headless-мерки).
	# side_pad > 0 переопределяет боковые поля контента (левое гнездо иконки
	# у табов), 0 — родные поля пластины кита. fit_ratio < 1 — страховка
	# оконного рендера (строка в окне до ~1.4-1.5 шире headless-мерки): кегль
	# подбирается под долю доступной ширины, чтобы буквы не клипались в окне.
	if row_buttons.is_empty():
		return
	var first := row_buttons[0] as Button
	if first == null:
		return
	var font := first.get_theme_font("font")
	var font_size := _readable_font_size(16)
	var side_left := side_pad
	var side_right := side_pad
	if side_pad <= 0.0:
		var base_style := first.get_theme_stylebox("normal")
		side_left = base_style.content_margin_left if base_style != null else 45.0
		side_right = base_style.content_margin_right if base_style != null else 45.0
	var icon_span := 0.0
	var icon_height := 0.0
	for entry in row_buttons:
		var entry_icon := (entry as Button).icon
		if entry_icon != null:
			icon_span = maxf(icon_span, minf(36.0, float(entry_icon.get_width())) + 4.0)
			icon_height = maxf(icon_height, float(entry_icon.get_height()))
	if font != null:
		var avail := (button_width - side_left - side_right - icon_span) * clampf(fit_ratio, 0.1, 1.0)
		var widest := 0.0
		for entry in row_buttons:
			widest = maxf(widest, font.get_string_size((entry as Button).text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x)
		while font_size > 11 and widest > avail:
			font_size -= 1
			widest = 0.0
			for entry in row_buttons:
				widest = maxf(widest, font.get_string_size((entry as Button).text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x)
	var line_height := 22.0
	if font != null:
		line_height = font.get_height(font_size)
	var v_pad := clampf((button_height - maxf(line_height, icon_height)) * 0.5, 4.0, 16.0)
	for entry in row_buttons:
		var button := entry as Button
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.clip_text = true
		button.add_theme_font_size_override("font_size", font_size)
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var state_style := button.get_theme_stylebox(state)
			if state_style == null:
				continue
			var fitted: StyleBox = state_style.duplicate()
			if side_pad > 0.0:
				fitted.content_margin_left = side_pad
				fitted.content_margin_right = side_pad
			fitted.content_margin_top = v_pad
			fitted.content_margin_bottom = v_pad
			button.add_theme_stylebox_override(state, fitted)


func _make_settings_tab(tab_name: String, s := 1.0, column_w := 0.0) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.name = tab_name
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 0)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_right", 0)
	margin.add_theme_constant_override("margin_bottom", 0)
	var page := VBoxContainer.new()
	page.name = "%sContent" % tab_name
	# SCRUM-882 (фидбек): страница таба — колонка фикс-ширины column_w по ЦЕНТРУ
	# панели (SHRINK_CENTER внутри margin-обёртки), строки внутри колонки
	# остаются с левым выравниванием (у самих строк SIZE_SHRINK_BEGIN). Ширины
	# строк считаются от s = column_w/1276 — уже колонки по построению.
	page.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if column_w > 0.0 else Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if column_w > 0.0:
		page.custom_minimum_size = Vector2(roundf(column_w), 0.0)
	page.add_theme_constant_override("separation", int(roundf(20.0 * s)))
	margin.add_child(page)
	return margin


func _add_settings_control_row(parent: VBoxContainer, title: String, control: Control, s := 1.0) -> HBoxContainer:
	# v6: единая двухколоночная сетка label(380)|control — колонки выровнены по
	# всем вкладкам, контролы фиксированных размеров, ничего не тянется.
	var row := HBoxContainer.new()
	row.name = "SettingsRow_%s" % title.replace(" ", "_")
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_theme_constant_override("separation", int(roundf(24.0 * s)))
	parent.add_child(row)

	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(roundf(SETTINGS_V6_LABEL_COL.x * s), roundf(SETTINGS_V6_LABEL_COL.y * s))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", _settings_v6_font(26.0, s))
	label.add_theme_color_override("font_color", SETTINGS_V6_TEXT)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	return row


func _add_controls_section_header(parent: VBoxContainer, title: String, s := 1.0) -> Label:
	# v6: заголовок секции в атласном золоте + латунная линия до правого края —
	# секции «Устройство/Клавиатура/Геймпад» читаются как главы одного свитка.
	var row := HBoxContainer.new()
	row.name = "SettingsSectionRow_%s" % title.replace(" ", "_")
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", int(roundf(18.0 * s)))
	parent.add_child(row)
	var header := Label.new()
	header.name = "SettingsSectionHeader_%s" % title.replace(" ", "_")
	header.text = title
	header.add_theme_font_size_override("font_size", _settings_v6_font(28.0, s))
	header.add_theme_color_override("font_color", SETTINGS_V6_GOLD)
	header.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
	header.add_theme_constant_override("shadow_offset_x", maxi(1, int(roundf(1.5 * s))))
	header.add_theme_constant_override("shadow_offset_y", maxi(1, int(roundf(1.5 * s))))
	row.add_child(header)
	var line := ColorRect.new()
	line.color = SETTINGS_V6_BRONZE_LINE
	line.custom_minimum_size = Vector2(0.0, maxf(2.0, roundf(2.0 * s)))
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	return header


func _add_volume_row(box: VBoxContainer, title: String, volume_key: String, enabled_key: String, s := 1.0) -> void:
	var row := HBoxContainer.new()
	row.name = "VolumeRow_%s" % volume_key
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_theme_constant_override("separation", int(roundf(16.0 * s)))
	box.add_child(row)

	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(roundf(SETTINGS_V6_LABEL_COL.x * s), roundf(SETTINGS_V6_LABEL_COL.y * s))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", _settings_v6_font(26.0, s))
	label.add_theme_color_override("font_color", SETTINGS_V6_TEXT)
	row.add_child(label)

	var slider := HSlider.new()
	slider.name = "VolumeSlider_%s" % volume_key
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 2.0
	# Высота 42×s — компактный sound-ряд (контракт SCRUM-674: ≤460×46).
	slider.custom_minimum_size = Vector2(roundf(420.0 * s), roundf(42.0 * s))
	slider.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_ALL
	_settings_v6_style_slider(slider, s)
	slider.value = float(game.audio_settings.get(volume_key, 1.0)) * 100.0
	slider.value_changed.connect(func(value: float) -> void:
		game.audio_settings[volume_key] = value / 100.0
		game._apply_audio_settings()
		game.save_game_settings()
	)
	row.add_child(slider)

	var chip := PanelContainer.new()
	chip.name = "VolumeChip_%s" % volume_key
	chip.custom_minimum_size = Vector2(roundf(96.0 * s), roundf(48.0 * s))
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_theme_stylebox_override("panel", _settings_v6_texture_box(
		SETTINGS_V6_VALUE_CHIP_PATH, Vector4(16.0, 14.0, 16.0, 14.0), Vector4(6.0 * s, 2.0 * s, 6.0 * s, 2.0 * s)))
	row.add_child(chip)
	var value_label := Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.text = "%d%%" % int(slider.value)
	value_label.add_theme_font_size_override("font_size", _settings_v6_font(24.0, s))
	value_label.add_theme_color_override("font_color", SETTINGS_V6_AMBER)
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = "%d%%" % int(value)
	)
	chip.add_child(value_label)

	if enabled_key != "":
		var toggle := CheckBox.new()
		toggle.name = "VolumeToggle_%s" % enabled_key
		toggle.button_pressed = bool(game.audio_settings.get(enabled_key, true))
		toggle.text = "Вкл." if toggle.button_pressed else "Выкл."
		toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_settings_v6_style_checkbox(toggle, s)
		slider.editable = toggle.button_pressed
		toggle.toggled.connect(func(pressed: bool) -> void:
			game.audio_settings[enabled_key] = pressed
			toggle.text = "Вкл." if pressed else "Выкл."
			slider.editable = pressed
			game._apply_audio_settings()
			game.save_game_settings()
		)
		row.add_child(toggle)


func _settings_v6_apply_field_theme(button: Button, s: float) -> void:
	# Врезное поле 560×56×s: дропдауны и кнопки биндингов. Арт — 9-slice
	# источник 320×56 (углы 1:1, плоская середина тянется по ширине).
	button.custom_minimum_size = Vector2(roundf(SETTINGS_V6_CONTROL_SIZE.x * s), roundf(SETTINGS_V6_CONTROL_SIZE.y * s))
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", _settings_v6_font(24.0, s))
	button.clip_text = true
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	# v6: у арта поля декоративные наконечники ~52px + золотое кольцо капсулы
	# ~20px с каждого конца — текст держим строго в плоской зоне капсулы,
	# иначе края длинных опций ложатся на кольцо.
	var content := Vector4(76.0 * s, 6.0 * s, 76.0 * s, 6.0 * s)
	if button is OptionButton:
		# OptionButton резервирует справа зону стрелки (internal margin) и
		# центрирует текст в остатке — центр уезжает влево, длинные опции
		# ложатся на кольцо. Компенсируем слева (+20px к базе), справа держим
		# 76, чтобы стрелка осталась внутри капсулы; вместе с кеглем 22 у
		# самой длинной опции зазор до кольца ≥25px на 1080p/1440p.
		content = Vector4(96.0 * s, 6.0 * s, 76.0 * s, 6.0 * s)
		button.add_theme_font_size_override("font_size", _settings_v6_font(22.0, s))
	# Арт поля 560×56 — точный дизайн-размер контрола (без 9-slice растяжений).
	var source_margins := Vector4(12.0, 10.0, 12.0, 10.0)
	button.add_theme_stylebox_override("normal", _settings_v6_texture_box(SETTINGS_V6_FIELD_PATHS["normal"], source_margins, content))
	button.add_theme_stylebox_override("hover", _settings_v6_texture_box(SETTINGS_V6_FIELD_PATHS["hover"], source_margins, content))
	button.add_theme_stylebox_override("pressed", _settings_v6_texture_box(SETTINGS_V6_FIELD_PATHS["pressed"], source_margins, content))
	button.add_theme_stylebox_override("focus", _settings_v6_texture_box(SETTINGS_V6_FIELD_PATHS["hover"], source_margins, content))
	button.add_theme_stylebox_override("disabled", _settings_v6_texture_box(SETTINGS_V6_FIELD_PATHS["normal"], source_margins, content))
	button.add_theme_color_override("font_color", SETTINGS_V6_TEXT)
	button.add_theme_color_override("font_hover_color", SETTINGS_V6_TEXT_BRIGHT)
	button.add_theme_color_override("font_pressed_color", SETTINGS_V6_TEXT_BRIGHT)
	button.add_theme_color_override("font_focus_color", SETTINGS_V6_TEXT_BRIGHT)
	button.add_theme_color_override("font_disabled_color", SETTINGS_V6_DISABLED)
	if button is OptionButton:
		# 30px: меньший резерв стрелки оставляет длинным опциям запас от клипа.
		var arrow := _settings_v6_icon(SETTINGS_V6_ARROW_PATH, Vector2(30.0, 30.0), s)
		if arrow != null:
			button.add_theme_icon_override("arrow", arrow)
		var popup := (button as OptionButton).get_popup()
		popup.add_theme_font_size_override("font_size", _settings_v6_font(24.0, s))
		# v6: поп-ап как чип Атласа — тёмный фон, латунная кромка, скругление.
		var popup_style := StyleBoxFlat.new()
		popup_style.bg_color = SETTINGS_V6_POPUP_BG
		popup_style.border_color = Color(0.52, 0.41, 0.24, 0.90)
		popup_style.set_border_width_all(maxi(1, int(roundf(2.0 * s))))
		popup_style.set_corner_radius_all(int(roundf(10.0 * s)))
		popup_style.set_content_margin_all(roundf(10.0 * s))
		popup.add_theme_stylebox_override("panel", popup_style)
		var popup_hover := StyleBoxFlat.new()
		popup_hover.bg_color = Color(0.30, 0.23, 0.12, 0.85)
		popup_hover.set_corner_radius_all(int(roundf(8.0 * s)))
		popup.add_theme_stylebox_override("hover", popup_hover)
		popup.add_theme_color_override("font_color", SETTINGS_V6_TEXT)
		popup.add_theme_color_override("font_hover_color", SETTINGS_V6_TEXT_BRIGHT)


func _settings_v6_make_action_button(text: String, button_name: String, width: float, height: float) -> Button:
	# SCRUM-879: кнопки-действия настроек — глобальный кит (Правило 2, как экран
	# «Атлас героев»): _make_button + _set_action_button_size. Имя ставим ДО
	# применения размера: маппинг текстур кита (_text_button_unique_id /
	# _button_asset_type) читает name+size. Прежние ui_settings_v6_btn_* стили
	# не используются; disabled-состояние (Apply) кит поддерживает.
	var button := _make_button(text)
	button.name = button_name
	_set_action_button_size(button, width, height)
	return button


func _settings_v6_style_checkbox(toggle: CheckBox, s: float) -> void:
	toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	toggle.add_theme_font_size_override("font_size", _settings_v6_font(24.0, s))
	var unchecked := _settings_v6_icon(SETTINGS_V6_CHECKBOX_OFF_PATH, Vector2(52.0, 52.0), s)
	var checked := _settings_v6_icon(SETTINGS_V6_CHECKBOX_ON_PATH, Vector2(52.0, 52.0), s)
	if unchecked != null:
		toggle.add_theme_icon_override("unchecked", unchecked)
		toggle.add_theme_icon_override("unchecked_disabled", unchecked)
	if checked != null:
		toggle.add_theme_icon_override("checked", checked)
		toggle.add_theme_icon_override("checked_disabled", checked)
	toggle.add_theme_constant_override("h_separation", int(roundf(14.0 * s)))
	toggle.add_theme_color_override("font_color", SETTINGS_V6_TEXT)
	toggle.add_theme_color_override("font_hover_color", SETTINGS_V6_TEXT_BRIGHT)
	toggle.add_theme_color_override("font_pressed_color", SETTINGS_V6_TEXT_BRIGHT)
	# v6: видимое фокус-кольцо для геймпад-навигации (латунная рамка).
	var focus_ring := StyleBoxFlat.new()
	focus_ring.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	focus_ring.border_color = Color(0.78, 0.66, 0.44, 0.85)
	focus_ring.set_border_width_all(maxi(1, int(roundf(2.0 * s))))
	focus_ring.set_corner_radius_all(int(roundf(8.0 * s)))
	toggle.add_theme_stylebox_override("focus", focus_ring)


func _settings_v6_style_slider(slider: HSlider, s: float) -> void:
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var groove_h := maxf(8.0, 9.0 * s)
	var track := _settings_v6_texture_box(SETTINGS_V6_SLIDER_TRACK_PATH, Vector4(8.0, 5.0, 8.0, 5.0), Vector4.ZERO)
	if track is StyleBoxTexture:
		track.content_margin_top = groove_h
		track.content_margin_bottom = groove_h
	var fill := _settings_v6_texture_box(SETTINGS_V6_SLIDER_FILL_PATH, Vector4(6.0, 4.0, 6.0, 4.0), Vector4.ZERO)
	if fill is StyleBoxTexture:
		fill.content_margin_top = maxf(8.0, groove_h - 2.0 * s)
		fill.content_margin_bottom = maxf(8.0, groove_h - 2.0 * s)
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	slider.add_theme_constant_override("center_grabber", 1)
	var gem := _settings_v6_icon(SETTINGS_V6_SLIDER_GEM_PATH, Vector2(36.0, 36.0), s)
	if gem != null:
		slider.add_theme_icon_override("grabber", gem)
		slider.add_theme_icon_override("grabber_disabled", gem)
	# v6: под фокусом/hover гем чуть крупнее — заметно с геймпада.
	var gem_focus := _settings_v6_icon(SETTINGS_V6_SLIDER_GEM_PATH, Vector2(40.0, 40.0), s)
	if gem_focus != null:
		slider.add_theme_icon_override("grabber_highlight", gem_focus)


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
	# SCRUM-890: Esc в любой момент забега открывает сразу досье героя — промежуточное
	# простое меню паузы (RunPauseMenu) удалено, его функции живут в шапке досье.
	_show_pause_dossier_menu()


# SCRUM-883: модалка подтверждения «Завершить забег» из паузы — тот же стиль, что у
# quit-диалога главного меню: плотный atlas-чип, золотой титул, кит-кнопки 220×72
# (нативы quit_220x72 по size-маппингу), стартовый фокус на безопасной «Отмене»,
# Esc/B и клик мимо панели отменяют только модалку (пауза остаётся).
func _show_end_run_confirmation_dialog() -> void:
	if game.pause_overlay_layer == null or not is_instance_valid(game.pause_overlay_layer):
		return
	if game.pause_overlay_layer.find_child("EndRunConfirmationDialog", true, false) != null:
		var existing_cancel := game.pause_overlay_layer.find_child("EndRunConfirmCancelButton", true, false) as Button
		if existing_cancel != null:
			existing_cancel.grab_focus()
		return

	var overlay := Control.new()
	overlay.name = "EndRunConfirmationDialog"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 500
	game.pause_overlay_layer.add_child(overlay)

	var dim := ColorRect.new()
	dim.name = "EndRunConfirmationDim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "EndRunConfirmationPanel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -300.0
	panel.offset_top = -170.0
	panel.offset_right = 300.0
	panel.offset_bottom = 170.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _atlas_chip_style(0.97, roundf(20.0 * _atlas_ui_scale())))
	overlay.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title_label := Label.new()
	title_label.name = "EndRunConfirmationTitle"
	title_label.text = "Завершить забег?"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", _readable_font_size(34))
	title_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	box.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.name = "EndRunConfirmationSubtitle"
	subtitle_label.text = "Текущий забег закончится, и будет подведён итог. Продолжить?"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size", _readable_font_size(16))
	subtitle_label.add_theme_color_override("font_color", Color(0.90, 0.88, 0.78, 1.0))
	box.add_child(subtitle_label)

	var button_row := HBoxContainer.new()
	button_row.name = "EndRunConfirmationButtons"
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.custom_minimum_size = Vector2(0.0, 72.0)
	button_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button_row.add_theme_constant_override("separation", 18)
	box.add_child(button_row)

	var confirm_button := _make_button("Завершить")
	confirm_button.name = "EndRunConfirmAcceptButton"
	_set_action_button_size(confirm_button, 220.0, 72.0)
	confirm_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Диалог живёт в pause_overlay_layer и умрёт вместе с ним при _clear_ui завершения.
	confirm_button.pressed.connect(_end_current_run_by_player)
	button_row.add_child(confirm_button)

	var cancel_button := _make_button("Отмена")
	cancel_button.name = "EndRunConfirmCancelButton"
	_set_action_button_size(cancel_button, 220.0, 72.0)
	cancel_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cancel_button.pressed.connect(_cancel_end_run_confirmation_dialog)
	button_row.add_child(cancel_button)

	# Полное 4-стороннее замыкание фокуса: под модалкой вертикальная колонна кнопок
	# паузы, стрелки не должны уводить фокус за пределы диалога.
	confirm_button.focus_neighbor_left = cancel_button.get_path()
	confirm_button.focus_neighbor_right = cancel_button.get_path()
	confirm_button.focus_neighbor_top = cancel_button.get_path()
	confirm_button.focus_neighbor_bottom = cancel_button.get_path()
	cancel_button.focus_neighbor_left = confirm_button.get_path()
	cancel_button.focus_neighbor_right = confirm_button.get_path()
	cancel_button.focus_neighbor_top = confirm_button.get_path()
	cancel_button.focus_neighbor_bottom = confirm_button.get_path()
	cancel_button.grab_focus()

	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if not panel.get_global_rect().has_point((event as InputEventMouseButton).global_position):
				_cancel_end_run_confirmation_dialog()
	)


# Возвращает true, если модалка подтверждения была открыта и закрыта этим вызовом.
func _cancel_end_run_confirmation_dialog() -> bool:
	if game.pause_overlay_layer == null or not is_instance_valid(game.pause_overlay_layer):
		return false
	var overlay: Node = game.pause_overlay_layer.find_child("EndRunConfirmationDialog", true, false)
	if overlay == null:
		return false
	overlay.queue_free()
	var end_run_button := game.pause_overlay_layer.find_child("PauseEndRunButton", true, false) as Button
	if end_run_button != null and is_instance_valid(end_run_button):
		end_run_button.grab_focus()
	return true


func _show_pause_dossier_menu() -> void:
	if game.pause_overlay_layer == null or not is_instance_valid(game.pause_overlay_layer):
		return
	for child in game.pause_overlay_layer.get_children():
		child.queue_free()

	# SCRUM-890: досье может быть первым открытым UI забега — гарантируем
	# геймпад-биндинги ui_accept/ui_cancel (B = «Продолжить» через main._input).
	_ensure_run_ui_gamepad_bindings()
	game.pause_stats_menu = game.PAUSE_STATS_MENU_SCENE.instantiate() as Control
	game.pause_overlay_layer.add_child(game.pause_stats_menu)
	if game.pause_stats_menu.has_method("setup"):
		game.pause_stats_menu.setup(_pause_dossier_player())
	game.pause_stats_menu.resume_requested.connect(_resume_game)
	game.pause_stats_menu.settings_requested.connect(func() -> void:
		_show_settings_menu(SETTINGS_RETURN_RUN_PAUSE)
	)
	# SCRUM-890: «Завершить забег» из шапки досье открывает модалку SCRUM-883
	# (EndRunConfirmationDialog в pause_overlay_layer), а не движковый фолбэк сцены.
	game.pause_stats_menu.set("end_run_confirm_handler", Callable(self, "_show_end_run_confirmation_dialog"))
	game.pause_stats_menu.end_run_confirmed.connect(_end_current_run_by_player)
	game.pause_stats_menu.main_menu_requested.connect(_quit_current_run)


func _is_run_pause_overlay_open() -> bool:
	return game.pause_overlay_layer != null and is_instance_valid(game.pause_overlay_layer)


func _is_settings_screen_open() -> bool:
	if game.ui_layer == null or not is_instance_valid(game.ui_layer):
		return false
	return game.ui_layer.find_child("SettingsV2Root", true, false) != null


func _can_open_pause_dossier() -> bool:
	if _is_settings_screen_open():
		return false
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
	# SCRUM-883: Esc/B при открытом подтверждении «Завершить забег» отменяет только
	# модалку — пауза остаётся (паритет с Escape-отменой quit-диалога главного меню).
	if _cancel_end_run_confirmation_dialog():
		return
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
	game.run_used_shop = false
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


func _hero_card_line(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", _readable_font_size(font_size, 0, 44))
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


# SCRUM-883: экраны выбора оружия и стартового буна на едином атлас-стиле
# (эталон SCRUM-879): фон-зал героев COVERED (продолжение флоу выбора героя),
# контент в safe-зоне полой рамы meta40, панели/карточки — чипы StyleBoxFlat,
# кнопки — глобальный кит. Геометрия адаптивная от _atlas_ui_scale(): на базе
# 2560×1440 держит смоук-контракты (колодец ≥200, спрайт ≥176, статс ≥300),
# на малых вьюпортах матрицы пропорционально ужимается в safe-зону.


# Общий полноэкранный корень пре-ран экранов оружия/буна: чистка UI, слой,
# root на весь экран, глобальные тултипы. Фон/safe/рама добавляются звонящим.
func _weapon_flow_shell_root(screen_name: String) -> Control:
	game._clear_ui()
	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)
	var root := Control.new()
	root.name = screen_name
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.ui_layer.add_child(root)
	_prepare_global_tooltips(root)
	return root


# Шапка атлас-экрана: чип-титул слева, «Назад» на глобальном ките справа
# (единый возврат 2026-07-08: плита 260 × action-height на всех экранах).
func _weapon_flow_header(layout: VBoxContainer, prefix: String, title: String, s: float, back_action: Callable) -> Button:
	var header := HBoxContainer.new()
	header.name = "%sHeader" % prefix
	header.add_theme_constant_override("separation", int(roundf(12.0 * s)))
	layout.add_child(header)
	header.add_child(_unified_header_chip(prefix, title, "hero_select", s))
	var spacer := Control.new()
	spacer.name = "%sHeaderSpacer" % prefix
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)
	var back_button := _make_button("Назад")
	back_button.name = "%sBackButton" % prefix
	_set_action_button_size(back_button, 260.0, _atlas_action_button_height())
	back_button.pressed.connect(back_action)
	header.add_child(back_button)
	return back_button


func _show_weapon_select() -> void:
	var character_config = game.PROGRESSION_DATA.character_config(game.selected_character_id)
	var root := _weapon_flow_shell_root("WeaponSelectScreen")
	_unified_add_background(root, "hero_select")

	var s := _atlas_ui_scale()
	var safe := _unified_make_safe_area(root, "WeaponSelect")
	var layout := VBoxContainer.new()
	layout.name = "WeaponSelectLayout"
	layout.add_theme_constant_override("separation", int(roundf(12.0 * s)))
	safe.add_child(layout)
	var back_button := _weapon_flow_header(layout, "WeaponSelect", "Выбор оружия", s, _show_character_select)

	# Плита карточек: узел MenuPanel_weapon_select — тест-контракт (смоук/матрица:
	# PanelContainer + StyleBoxFlat alpha >= 0.80), стиль — атлас-чип.
	var panel := PanelContainer.new()
	panel.name = "MenuPanel_weapon_select"
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _weapon_select_panel_style())
	layout.add_child(panel)
	var box := VBoxContainer.new()
	box.name = "WeaponSelectCards"
	box.add_theme_constant_override("separation", int(roundf(12.0 * s)))
	panel.add_child(box)

	var subtitle := Label.new()
	subtitle.name = "WeaponSelectSubtitle"
	subtitle.text = "%s: выбери стартовое оружие." % str(character_config["title"])
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", _readable_font_size(17, 12, 24))
	subtitle.add_theme_color_override("font_color", Color(0.78, 0.66, 0.44, 1.0))
	box.add_child(subtitle)

	var weapon_cards: Array = []
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
		weapon_cards.append(button)

	game.ui_escape_action = _show_character_select
	# Полая рама атласа — ПОСЛЕДНЕЙ, поверх контента.
	_unified_add_frame(root, "WeaponSelect")

	# SCRUM-813: карточки оружия листаются вверх/вниз по кругу, «Назад» в шапке; A
	# выбирает, B/Esc возвращает к выбору героя. Старт — первая карточка.
	_wire_run_ui_focus(weapon_cards, false, [back_button],
		weapon_cards[0] if not weapon_cards.is_empty() else back_button)


func _make_weapon_select_card(config: Dictionary) -> Button:
	var weapon_id := str(config.get("id", ""))
	var character_id := str(config.get("character_id", game.selected_character_id))
	var s := _atlas_ui_scale()
	var button := Button.new()
	button.name = "WeaponOption_%s" % weapon_id
	button.set_meta("weapon_id", weapon_id)
	button.text = ""
	# Пол min-высоты держит карточку читаемой на малых вьюпортах; на базе карточки
	# растягиваются EXPAND_FILL и делят плиту (фактически ~260, смоук требует >=110).
	button.custom_minimum_size = Vector2(0.0, roundf(maxf(200.0 * s, 96.0)))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = "%s\n%s\n%s" % [
		str(config.get("title", weapon_id)),
		_weapon_select_identity_text(character_id, weapon_id),
		str(config.get("description", "")),
	]
	_weapon_card_theme(button, roundf(12.0 * s))

	var row := HBoxContainer.new()
	row.name = "WeaponOptionContent_%s" % weapon_id
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	var card_content := _weapon_select_card_content_margins()
	row.offset_left = card_content.x
	row.offset_top = card_content.y
	row.offset_right = -card_content.z
	row.offset_bottom = -card_content.w
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(roundf(24.0 * s)))
	button.add_child(row)

	var icon_well := PanelContainer.new()
	icon_well.name = "WeaponSelectIconWell_%s" % weapon_id
	# База 2560: 204×204 (смоук-контракт >=200); на малых вьюпортах ужимается.
	icon_well.custom_minimum_size = Vector2(roundf(204.0 * s), roundf(204.0 * s))
	icon_well.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_well.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_well.add_theme_stylebox_override("panel", _weapon_select_icon_well_style())
	row.add_child(icon_well)

	var sprite := TextureRect.new()
	sprite.name = "WeaponSelectSprite_%s" % weapon_id
	sprite.custom_minimum_size = Vector2(roundf(176.0 * s), roundf(176.0 * s))
	sprite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sprite.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.texture = game._cached_texture(_weapon_sprite_path(config))
	icon_well.add_child(sprite)

	var text_box := VBoxContainer.new()
	text_box.name = "WeaponSelectText_%s" % weapon_id
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	text_box.add_theme_constant_override("separation", int(roundf(6.0 * s)))
	row.add_child(text_box)

	var title_label := Label.new()
	title_label.name = "WeaponSelectTitle_%s" % weapon_id
	title_label.text = str(config.get("title", weapon_id))
	title_label.max_lines_visible = 1
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_font_size_override("font_size", _readable_font_size(26, 12, 36))
	title_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(title_label)

	var identity_label := Label.new()
	identity_label.name = "WeaponSelectIdentity_%s" % weapon_id
	identity_label.text = "Отличие: %s" % _weapon_select_identity_text(character_id, weapon_id)
	identity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity_label.max_lines_visible = 2
	identity_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	identity_label.add_theme_font_size_override("font_size", _readable_font_size(17, 12, 23))
	identity_label.add_theme_color_override("font_color", Color(0.78, 0.66, 0.44, 1.0))
	identity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(identity_label)

	var desc_label := Label.new()
	desc_label.name = "WeaponSelectDescription_%s" % weapon_id
	desc_label.text = _weapon_select_mechanic_summary(config)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.max_lines_visible = 2
	desc_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	desc_label.add_theme_font_size_override("font_size", _readable_font_size(15, 12, 21))
	desc_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(desc_label)

	var role_label := Label.new()
	role_label.name = "WeaponSelectRole_%s" % weapon_id
	role_label.text = _weapon_select_role_text(character_id, config)
	role_label.max_lines_visible = 1
	role_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	role_label.add_theme_font_size_override("font_size", _readable_font_size(14, 12, 18))
	role_label.add_theme_color_override("font_color", Color(0.78, 0.66, 0.44, 1.0))
	role_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(role_label)

	var stats_panel := PanelContainer.new()
	stats_panel.name = "WeaponSelectStatsPanel_%s" % weapon_id
	# База 2560: 310×204 (смоук-контракт min.x >= 300).
	stats_panel.custom_minimum_size = Vector2(roundf(310.0 * s), roundf(204.0 * s))
	stats_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stats_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_panel.add_theme_stylebox_override("panel", _weapon_select_stats_panel_style())
	row.add_child(stats_panel)

	var stats_label := Label.new()
	stats_label.name = "WeaponSelectStats_%s" % weapon_id
	stats_label.custom_minimum_size = Vector2(roundf(280.0 * s), 0)
	stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.text = _weapon_select_stats_text(config)
	stats_label.add_theme_font_size_override("font_size", _readable_font_size(13, 12, 17))
	stats_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))
	stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_panel.add_child(stats_label)
	return button


# SCRUM-883: плита экрана — атлас-чип (тест-контракт: StyleBoxFlat, alpha >= 0.80).
func _weapon_select_panel_style() -> StyleBoxFlat:
	return _atlas_chip_style(0.90, roundf(12.0 * _atlas_ui_scale()))


func _weapon_select_card_content_margins() -> Vector4:
	var s := _atlas_ui_scale()
	return Vector4(roundf(22.0 * s), roundf(18.0 * s), roundf(22.0 * s), roundf(18.0 * s))


# SCRUM-883: тема карточек оружия/буна — «кожаный ряд» атласа (hover/pressed/
# focus/disabled от row-theme) с поднятым normal-чипом: row-normal 0.72 ниже
# смоук-контракта прозрачности (>=0.80), карточкам нужен фон плотнее.
func _weapon_card_theme(button: Button, pad := 12.0) -> void:
	_unified_apply_row_theme(button, pad)
	button.add_theme_stylebox_override("normal", _atlas_chip_style(0.86, pad))


# Колодец иконки: тихая полупрозрачная подложка без канта (арт не спорит с рамой).
func _weapon_select_icon_well_style() -> StyleBoxFlat:
	return _atlas_translucent_style(0.55, 10.0)


func _weapon_select_stats_panel_style() -> StyleBoxFlat:
	return _atlas_chip_style(0.62, roundf(10.0 * _atlas_ui_scale()))


func _weapon_select_identity_text(character_id: String, weapon_id: String) -> String:
	var identity := str(game.PROGRESSION_DATA.weapon_mechanic_identity(character_id, weapon_id))
	if identity.strip_edges() == "":
		return "уникальный стиль атаки этого оружия"
	return identity


func _weapon_select_role_text(character_id: String, config: Dictionary) -> String:
	var archetype := _weapon_select_archetype_label(config)
	var main_attribute := str(game.PROGRESSION_DATA.class_main_attribute(character_id))
	var stat_name := str(game.PROGRESSION_DATA.STAT_NAMES.get(main_attribute, main_attribute))
	var mode_label := _weapon_select_mode_label(config)
	return "Роль: %s · %s · Скейл: %s" % [archetype, mode_label, stat_name]


func _weapon_select_mechanic_summary(config: Dictionary) -> String:
	var archetype := _weapon_select_archetype_label(config)
	var mode_label := _weapon_select_mode_label(config)
	var attack_range := float(config.get("attack_range", 0.0))
	var radius := float(config.get("aoe_radius", 0.0))
	if int(config.get("max_summons", 0)) > 0:
		return "Призывает до %d союзн.; держит давление сам, лучше раскрывается через Leadership." % int(config.get("max_summons", 0))
	match mode_label:
		"сектор":
			return "Направленный сектор: важно позиционирование. Дуга/радиус растут от секторных усилений."
		"круг":
			return "Круговая зона вокруг героя: стабильная зачистка рядом, радиус раскрывает контроль толпы."
		"траектория":
			return "Траектория/линия: сильнее по выбранному направлению, ценит дальность и точное наведение."
		"взрыв":
			return "Взрывная зона: короткое окно урона по группе, радиус повышает число задетых целей."
		"установка":
			return "Ставит объект/ловушку: контроль пространства, заранее покрывает подходы врагов."
		"цепь":
			return "Цепная атака: перескакивает между целями и лучше работает в плотной группе."
		_:
			if archetype == "область" or radius >= attack_range * 0.75:
				return "Зональная атака: держит область под контролем и хорошо чистит ближнюю толпу."
			if attack_range >= 420.0:
				return "Дальняя атака: безопаснее открывает бой и сильнее отыгрывает дистанцию."
	return "Уникальная схема атаки: отличается формой удара, темпом и способом контроля целей."


func _weapon_select_archetype_label(config: Dictionary) -> String:
	match str(game.PROGRESSION_DATA.weapon_archetype(config)):
		"melee":
			return "ближний бой"
		"beam":
			return "луч/линия"
		"aoe":
			return "область"
		"summon":
			return "призыв/устройство"
		"aura":
			return "аура"
		"projectile":
			return "снаряд"
	return "особая атака"


func _weapon_select_mode_label(config: Dictionary) -> String:
	var mode := str(config.get("attack_mode", config.get("attack_shape", "")))
	match mode:
		"cone", "sweep":
			return "сектор"
		"circle", "slam", "aura":
			return "круг"
		"beam", "line", "pierce":
			return "траектория"
		"burst", "explosion":
			return "взрыв"
		"deploy", "trap", "mine":
			return "установка"
		"chain":
			return "цепь"
		"single":
			return "точечная цель"
	if str(config.get("summon_role", "")) != "" or int(config.get("max_summons", 0)) > 0:
		return "союзники"
	return "механика"


func _weapon_select_stats_text(config: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("Архетип: %s" % _weapon_select_archetype_label(config))
	lines.append("Дальность %.0f / радиус %.0f" % [
		float(config.get("attack_range", 0.0)),
		float(config.get("aoe_radius", 0.0)),
	])
	lines.append("Перезарядка %.2fс" % float(config.get("fire_interval", 0.0)))
	if int(config.get("max_summons", 0)) > 0:
		lines.append("Лимит: %d" % int(config.get("max_summons", 0)))
	elif float(config.get("knockback", 0.0)) > 0.0:
		lines.append("Контроль: %.0f" % float(config.get("knockback", 0.0)))
	else:
		lines.append("Урон x%.2f" % float(config.get("damage_multiplier", 1.0)))
	return "\n".join(lines)


# SCRUM-618: пикер стартового боона. Показывает 3 случайных боона (карточный паттерн)
# между выбором оружия и стартом забега. Выбор → game.selected_start_boon_id + автосейв
# + карта. «Без боона» завершает выбор тождественно (selected_start_boon_id="").
# SCRUM-883: тот же атлас-шелл, что у выбора оружия (фон-зал/safe/чип-шапка/рама).
func _show_start_boon_select() -> void:
	var all_boons: Array = game.PROGRESSION_DATA.start_boons(game.selected_character_id)
	# Случайная выборка 3 без повторов (детерминирована текущим состоянием game.rng).
	var pool: Array = all_boons.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j: int = game.rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var offered: Array = pool.slice(0, mini(3, pool.size()))

	var root := _weapon_flow_shell_root("StartBoonScreen")
	_unified_add_background(root, "hero_select")

	var s := _atlas_ui_scale()
	var safe := _unified_make_safe_area(root, "StartBoon")
	var layout := VBoxContainer.new()
	layout.name = "StartBoonLayout"
	layout.add_theme_constant_override("separation", int(roundf(12.0 * s)))
	safe.add_child(layout)
	var back_button := _weapon_flow_header(layout, "StartBoon", "Стартовый боон", s, _show_weapon_select)

	var panel := PanelContainer.new()
	panel.name = "StartBoonPanel"
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _weapon_select_panel_style())
	layout.add_child(panel)
	var box := VBoxContainer.new()
	box.name = "StartBoonCards"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", int(roundf(12.0 * s)))
	panel.add_child(box)

	var subtitle := Label.new()
	subtitle.name = "StartBoonSubtitle"
	subtitle.text = "Выбери одно благословение на этот забег."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", _readable_font_size(17, 12, 24))
	subtitle.add_theme_color_override("font_color", Color(0.78, 0.66, 0.44, 1.0))
	box.add_child(subtitle)

	var boon_cards: Array = []
	for boon in offered:
		var boon_dict: Dictionary = boon
		var button := _make_start_boon_card(boon_dict)
		button.pressed.connect(func() -> void:
			game.selected_start_boon_id = str(boon_dict.get("id", ""))
			game.save_run_autosave("start_boon")
			game.route._show_battle_map()
		)
		box.add_child(button)
		boon_cards.append(button)

	# «Без боона» — пропустить (тождественность). Возможность не брать ничего.
	var skip_button := _make_button("Без боона")
	skip_button.name = "StartBoonSkipButton"
	skip_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skip_button.pressed.connect(func() -> void:
		game.selected_start_boon_id = ""
		game.save_run_autosave("start_boon")
		game.route._show_battle_map()
	)
	box.add_child(skip_button)
	game.ui_escape_action = _show_weapon_select
	_unified_add_frame(root, "StartBoon")

	# SCRUM-813: бооны листаются вверх/вниз по кругу, «Без боона» ниже, «Назад» в
	# шапке; A выбирает, B/Esc возвращает к выбору оружия. Старт — первый боон.
	_wire_run_ui_focus(boon_cards, false, [skip_button, back_button],
		boon_cards[0] if not boon_cards.is_empty() else skip_button)


func _make_start_boon_card(boon: Dictionary) -> Button:
	var boon_id := str(boon.get("id", ""))
	var s := _atlas_ui_scale()
	var button := Button.new()
	button.name = "StartBoonOption_%s" % boon_id
	button.set_meta("boon_id", boon_id)
	button.text = ""
	button.custom_minimum_size = Vector2(0.0, roundf(maxf(116.0 * s, 84.0)))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = "%s\n%s" % [str(boon.get("title", boon_id)), str(boon.get("description", ""))]
	_weapon_card_theme(button, roundf(10.0 * s))

	var text_box := VBoxContainer.new()
	text_box.name = "StartBoonText_%s" % boon_id
	text_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	text_box.offset_left = roundf(22.0 * s)
	text_box.offset_top = roundf(12.0 * s)
	text_box.offset_right = -roundf(22.0 * s)
	text_box.offset_bottom = -roundf(12.0 * s)
	text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_theme_constant_override("separation", int(roundf(6.0 * s)))
	button.add_child(text_box)

	var title_label := Label.new()
	title_label.name = "StartBoonTitle_%s" % boon_id
	title_label.text = str(boon.get("title", boon_id))
	title_label.max_lines_visible = 1
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_font_size_override("font_size", _readable_font_size(21, 12, 30))
	title_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(title_label)

	var desc_label := Label.new()
	desc_label.name = "StartBoonDescription_%s" % boon_id
	desc_label.text = str(boon.get("description", ""))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.max_lines_visible = 3
	desc_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	desc_label.add_theme_font_size_override("font_size", _readable_font_size(14, 12, 20))
	desc_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))
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


# SCRUM-812: единая разводка фокус-навигации внутризабеговых экранов под геймпад
# и стрелки. primary — основной ряд/столбец интерактивных контролов (карточки или
# кнопки меню); axis_h=true — горизонтальный ряд (лево/право по кругу), false —
# вертикальный столбец (верх/низ по кругу). secondary — вспомогательные кнопки
# («Позже»/«Назад»), доступные с перпендикулярной оси и связанные обратно в круг.
# initial — стартовый фокус (по умолчанию первый доступный контрол).
# Опирается на встроенные ui_*-экшены Godot (у них дефолтные joypad-биндинги
# A/B/крестовина/стик), поэтому не зависит от ядра InputDeviceManager (SCRUM-811).
func _wire_run_ui_focus(primary: Array, axis_h: bool, secondary: Array = [], initial: Control = null) -> void:
	_ensure_run_ui_gamepad_bindings()
	var ring := _collect_focusable_controls(primary)
	var extra := _collect_focusable_controls(secondary)
	for i in range(ring.size()):
		var cur := ring[i]
		var prev := ring[(i - 1 + ring.size()) % ring.size()]
		var nxt := ring[(i + 1) % ring.size()]
		var cross_first: Control = extra[0] if not extra.is_empty() else cur
		var cross_last: Control = extra[extra.size() - 1] if not extra.is_empty() else cur
		if axis_h:
			cur.focus_neighbor_left = prev.get_path()
			cur.focus_neighbor_right = nxt.get_path()
			cur.focus_neighbor_bottom = cross_first.get_path()
			cur.focus_neighbor_top = cross_last.get_path()
		else:
			cur.focus_neighbor_top = prev.get_path()
			cur.focus_neighbor_bottom = nxt.get_path()
			cur.focus_neighbor_right = cross_first.get_path()
			cur.focus_neighbor_left = cur.get_path()
	var ring_head: Control = ring[0] if not ring.is_empty() else null
	for j in range(extra.size()):
		var cur2 := extra[j]
		var back: Control = ring_head if ring_head != null else cur2
		var prev2: Control = extra[j - 1] if j > 0 else back
		var nxt2: Control = extra[j + 1] if j < extra.size() - 1 else back
		if axis_h:
			cur2.focus_neighbor_top = prev2.get_path()
			cur2.focus_neighbor_bottom = nxt2.get_path()
			cur2.focus_neighbor_left = cur2.get_path()
			cur2.focus_neighbor_right = cur2.get_path()
		else:
			cur2.focus_neighbor_left = prev2.get_path()
			cur2.focus_neighbor_right = nxt2.get_path()
			cur2.focus_neighbor_top = cur2.get_path()
			cur2.focus_neighbor_bottom = cur2.get_path()
	var target := initial
	if target == null or not is_instance_valid(target):
		target = ring_head if ring_head != null else (extra[0] if not extra.is_empty() else null)
	if target != null and is_instance_valid(target):
		target.call_deferred("grab_focus")


# SCRUM-812: собирает валидные фокусируемые контролы (не disabled), проставляя им
# FOCUS_ALL. Порядок сохраняется — соседи разводятся по позиции в списке.
func _collect_focusable_controls(controls: Array) -> Array[Control]:
	var out: Array[Control] = []
	for c in controls:
		if c is Control and is_instance_valid(c):
			var ctrl := c as Control
			if ctrl is Button and (ctrl as Button).disabled:
				continue
			ctrl.focus_mode = Control.FOCUS_ALL
			out.append(ctrl)
	return out


# SCRUM-812: в текущей сборке у ui_accept/ui_cancel НЕТ joypad-событий (проверено:
# только клавиатура; крестовина/стик у ui_up/down/left/right есть). Без A→ui_accept и
# B→ui_cancel геймпад не подтверждает/не отменяет на внутризабеговых экранах. Идемпотентно
# доводим их в рантайме, чтобы SCRUM-812 работал самостоятельно. Полную раскладку геймпада
# формализует ядро SCRUM-811 (InputDeviceManager) — гард ниже исключает дубли при слиянии.
func _ensure_run_ui_gamepad_bindings() -> void:
	_ensure_action_joy_button("ui_accept", JOY_BUTTON_A)
	_ensure_action_joy_button("ui_cancel", JOY_BUTTON_B)


func _ensure_action_joy_button(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		return
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == button:
			return
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = true
	InputMap.action_add_event(action, ev)


# SCRUM-813: LB/RB листают вкладки настроек / секции кодекса. Роутинг из main._input
# (raw JOY_BUTTON_LEFT/RIGHT_SHOULDER) в этот диспетчер — локально по открытому мета-экрану.
# dir: -1 = предыдущая (LB), +1 = следующая (RB). Возвращает true, если обработано.
func _handle_menu_shoulder_nav(dir: int) -> bool:
	if game.ui_layer == null or not is_instance_valid(game.ui_layer):
		return false
	if game.ui_layer.find_child("SettingsV2Root", true, false) != null:
		return _cycle_settings_tab(dir)
	if game.ui_layer.find_child("CodexScreen", true, false) != null:
		return _cycle_codex_section(dir)
	# SCRUM-827: LB/RB листают вкладки Атласа героев (Созвездие ↔ Гильдия).
	if game.ui_layer.find_child("AtlasScreen", true, false) != null:
		return _atlas_cycle_tab(dir)
	return false


func _cycle_settings_tab(dir: int) -> bool:
	if game.ui_layer == null or not is_instance_valid(game.ui_layer):
		return false
	var root_node: Node = game.ui_layer.find_child("SettingsV2Root", true, false)
	if root_node == null:
		return false
	var tab_containers: Array = root_node.find_children("*", "TabContainer", true, false)
	if tab_containers.is_empty():
		return false
	var tabs := tab_containers[0] as TabContainer
	var count := tabs.get_tab_count()
	if count <= 0:
		return false
	tabs.current_tab = (tabs.current_tab + dir + count) % count
	var tab_btn := root_node.find_child("SettingsTabButton_%d" % tabs.current_tab, true, false) as Button
	if tab_btn != null:
		tab_btn.call_deferred("grab_focus")
	return true


func _cycle_codex_section(dir: int) -> bool:
	if game.ui_layer == null or not is_instance_valid(game.ui_layer):
		return false
	var content: PanelContainer = null
	for node in game.ui_layer.find_children("*", "PanelContainer", true, false):
		if node.has_meta("codex_active_section"):
			content = node as PanelContainer
			break
	if content == null:
		return false
	var ids: Array = []
	for section in CODEX_SECTIONS:
		ids.append(str(section["id"]))
	if ids.is_empty():
		return false
	var cur := str(content.get_meta("codex_active_section", ids[0]))
	var idx := ids.find(cur)
	if idx < 0:
		idx = 0
	var next_id := str(ids[(idx + dir + ids.size()) % ids.size()])
	_show_codex_section(content, next_id)
	var tabs_row := content.get_meta("codex_tabs", null) as Control
	if tabs_row != null:
		var tab_btn := tabs_row.get_node_or_null("CodexTab_%s" % next_id) as Button
		if tab_btn != null:
			tab_btn.call_deferred("grab_focus")
	return true


func _show_reward_screen() -> void:
	# SCRUM-883: панель награды — чип Атласа (карточки внутри — чип-ряды).
	var box := _create_menu_box("Награда за бой", "Выбери 1 из 3 усилений.", "artifact_reward", _atlas_chip_style(0.94, 18.0))
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

	var rewards_row := HBoxContainer.new()
	rewards_row.name = "LevelUpRewardsRow"
	rewards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var level_up_card_size: Vector2 = layout.get("card_size", Vector2(238.0, 210.0))
	rewards_row.position = layout.get("rewards_row_position", Vector2.ZERO)
	rewards_row.size = layout.get("rewards_row_size", Vector2(level_up_card_size.x * 3.0, level_up_card_size.y))
	rewards_row.custom_minimum_size = rewards_row.size
	rewards_row.add_theme_constant_override("separation", int(layout.get("card_gap", 0)))
	box.add_child(rewards_row)

	# Набор фиксируется на полученный уровень: переоткрытие окна показывает то же.
	if game.level_up_offer.is_empty():
		game.level_up_offer = _random_level_up_rewards(3)
	# SCRUM-871: прогноз «до -> после» и бейджи «Лучший урон»/«Выживание» на весь
	# набор — один раз на построение экрана, от живых статов игрока.
	var advice := _level_up_offer_advice(game.level_up_offer)
	var reward_buttons: Array[Button] = []
	for reward in game.level_up_offer:
		var button := _make_level_up_reward_button(reward, layout, advice, reward_buttons.size())
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

	# Типографика: авто-подбор мог дать титулам разный размер — выравниваем ряд
	# по минимальному, чтобы карточки читались как одна линейка.
	var title_labels: Array = []
	var min_title_font := 999
	for button in reward_buttons:
		var reward_title := button.find_child("LevelUpRewardTitle", true, false) as Label
		if reward_title != null:
			title_labels.append(reward_title)
			min_title_font = mini(min_title_font, reward_title.get_theme_font_size("font_size"))
	for reward_title in title_labels:
		(reward_title as Label).add_theme_font_size_override("font_size", min_title_font)

	# Клавиатура/геймпад: фокус по карточкам стрелками по кругу, Enter/Space/A выбирают.
	# Полная разводка (карточки + «Позже») ставится ниже, после создания later_button.

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

	# SCRUM-883: «Позже» — Button-контрол действия, только глобальный кит (имя узла
	# LevelUpLaterButton мапится на текстуры later_260x72; _set_action_button_size
	# переприменяет тему кита после установки размера).
	var later_button := _make_button("Позже")
	later_button.name = "LevelUpLaterButton"
	var later_button_size: Vector2 = layout.get("later_button_size", Vector2(260.0, 72.0))
	_set_action_button_size(later_button, later_button_size.x, later_button_size.y)
	later_button.position = layout.get("later_button_position", Vector2.ZERO)
	later_button.size = later_button_size
	later_button.tooltip_text = "Закрыть без выбора — пик сохранится, вернуться можно кнопкой повышения внизу."
	later_button.pressed.connect(defer_choice)
	box.add_child(later_button)
	game.ui_escape_action = defer_choice

	# SCRUM-812: карточки по кругу (лево/право), «Позже» достижима ui_down, старт — первая карточка.
	_wire_run_ui_focus(reward_buttons, true, [later_button], reward_buttons[0] if not reward_buttons.is_empty() else null)

	var panel := box.get_parent() as PanelContainer
	var title_label := box.find_child("LevelUpTitle", true, false) as Label
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
	_prepare_global_tooltips(root)
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
	# SCRUM-883: панель трофея — чип Атласа; дим-фон сохранён.
	panel.add_theme_stylebox_override("panel", _atlas_chip_style(0.94, 20.0))
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
	title.add_theme_font_size_override("font_size", _readable_font_size(52, 0, 52))
	title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "EliteArtifactRewardSubtitle"
	subtitle.text = "Выбери 1 из 3 артефактов. Чем глубже маршрут, тем выше шанс редкой добычи."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", _readable_font_size(20, 12, 20))
	subtitle.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))
	box.add_child(subtitle)

	var rewards_row := HBoxContainer.new()
	rewards_row.name = "EliteArtifactRewardRow"
	rewards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	rewards_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rewards_row.custom_minimum_size = Vector2(0.0, REWARD_ELITE_CARD_SIZE.y)
	rewards_row.add_theme_constant_override("separation", 22)
	box.add_child(rewards_row)

	var choices: Array = game.PROGRESSION_DATA.elite_artifact_choices(game.route_scaling_stage(), 3, game.selected_character_id)
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


func _show_boss_artifact_reward(on_done: Callable) -> void:
	# SCRUM-873: награда за акт-босса — выбор 1 из 3 СУПЕРРЕДКИХ артефактов
	# (верхний тир, boss-only оффер). Паттерн и карточки — как у трофея элитки.
	game._clear_ui()
	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "BossArtifactRewardScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	game.ui_layer.add_child(root)
	_prepare_global_tooltips(root)
	_add_screen_background(root, "elite_reward")

	var shade := ColorRect.new()
	shade.name = "BossArtifactRewardShade"
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.015, 0.025, 0.76)
	root.add_child(shade)

	var center := CenterContainer.new()
	center.name = "BossArtifactRewardCenter"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "BossArtifactRewardPanel"
	panel.custom_minimum_size = Vector2(1140, 640)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# SCRUM-883: панель трофея босса — чип Атласа; дим-фон сохранён.
	panel.add_theme_stylebox_override("panel", _atlas_chip_style(0.94, 20.0))
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(box)

	var title := Label.new()
	title.name = "BossArtifactRewardTitle"
	title.text = "Трофей босса"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", _readable_font_size(52, 0, 52))
	title.add_theme_color_override("font_color", TIER_COLORS[3])
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "BossArtifactRewardSubtitle"
	subtitle.text = "Акт пройден! Выбери 1 из 3 суперредких артефактов."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", _readable_font_size(20, 12, 20))
	subtitle.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))
	box.add_child(subtitle)

	var rewards_row := HBoxContainer.new()
	rewards_row.name = "BossArtifactRewardRow"
	rewards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	rewards_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rewards_row.custom_minimum_size = Vector2(0.0, REWARD_ELITE_CARD_SIZE.y)
	rewards_row.add_theme_constant_override("separation", 22)
	box.add_child(rewards_row)

	var choices: Array = game.PROGRESSION_DATA.boss_completion_artifact_choices(3, game.selected_character_id)
	var reward_cards: Array[Button] = []
	for reward in choices:
		var reward_data: Dictionary = reward
		var button := _make_elite_artifact_card(reward_data)
		button.name = "BossArtifactRewardButton%d" % rewards_row.get_child_count()
		button.pressed.connect(func() -> void:
			_apply_reward_to_run(reward_data)
			game._clear_ui()
			if on_done.is_valid():
				on_done.call()
		)
		rewards_row.add_child(button)
		reward_cards.append(button)

	# Пул пуст (теоретический случай) — не запирать игрока на экране без карт.
	if reward_cards.is_empty():
		push_warning("Boss artifact reward: пул суперредких пуст — экран пропущен.")
		game._clear_ui()
		if on_done.is_valid():
			on_done.call()
		return

	# Клавиатура/геймпад: стрелки двигают фокус по кругу, Enter/Space выбирают.
	for index in range(reward_cards.size()):
		var card := reward_cards[index]
		var left := reward_cards[(index - 1 + reward_cards.size()) % reward_cards.size()]
		var right := reward_cards[(index + 1) % reward_cards.size()]
		card.focus_neighbor_left = left.get_path()
		card.focus_neighbor_right = right.get_path()
		card.focus_neighbor_top = card.get_path()
		card.focus_neighbor_bottom = card.get_path()
	reward_cards[0].grab_focus()

	# Выбор обязателен: Escape ничего не закрывает.
	game.ui_escape_action = Callable()
	game._play_sfx("level_up")


func _make_level_up_reward_button(reward: Dictionary, layout := {}, advice := {}, reward_index := -1) -> Button:
	var is_rare := bool(reward.get("rare", false))
	var rare_color: Color = TIER_COLORS[3]
	var card_size: Vector2 = layout.get("card_size", Vector2(245, 364))
	# SCRUM-871: прогноз этой карточки и её бейдж из общего advice набора.
	var forecast: Dictionary = {}
	var badge_kind := ""
	var forecasts: Array = advice.get("forecasts", [])
	var badges: Array = advice.get("badges", [])
	if reward_index >= 0 and reward_index < forecasts.size():
		forecast = forecasts[reward_index]
	if reward_index >= 0 and reward_index < badges.size():
		badge_kind = str(badges[reward_index])
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = card_size
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.clip_text = false
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = _level_up_card_tooltip(reward, forecast, badge_kind, advice)
	button.set_meta("level_up_text_field_card", true)
	_apply_level_up_card_atlas_theme(button, card_size, is_rare)
	button.add_theme_color_override("font_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_hover_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_pressed_color", Color.TRANSPARENT)

	# Контент-зона = фактические content margins чип-стиля карточки; внутренние
	# ректы заданы в 2K-зоне LU_CARD_CONTENT_SOURCE и скейлятся на её факт-размер.
	var card_margins: Vector4 = button.get_meta("level_up_card_content_margins", Vector4.ZERO)
	var content := Control.new()
	content.name = "LevelUpRewardContent"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.clip_contents = true
	content.position = Vector2(card_margins.x, card_margins.y)
	content.size = Vector2(
		maxf(card_size.x - card_margins.x - card_margins.z, 8.0),
		maxf(card_size.y - card_margins.y - card_margins.w, 8.0)
	)
	content.custom_minimum_size = content.size
	button.add_child(content)
	var content_scale := _level_up_xy_scale(LU_CARD_CONTENT_SOURCE, content.size)

	if badge_kind != "" and LU_BADGE_META.has(badge_kind):
		_add_level_up_badge(content, badge_kind, content_scale)

	var icon_size := _level_up_scaled_size(LU_CARD_ICON_RECT, content_scale)
	var icon := game.UIIconRegistry.make_icon(_reward_icon_id(reward), icon_size) as Control
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.position = _level_up_scaled_position(LU_CARD_ICON_RECT, content_scale)
	icon.size = icon_size
	icon.custom_minimum_size = icon_size
	content.add_child(icon)

	var title_label := Label.new()
	title_label.name = "LevelUpRewardTitle"
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.text = str(reward.get("title", "Upgrade"))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.clip_text = true
	title_label.max_lines_visible = 1
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_level_up_place_card_child(title_label, LU_CARD_TITLE_RECT, content_scale)
	# Фидбек читаемости SCRUM-883: пол кегля 12 (было 8) — длинные титулы уходят
	# в ellipsis, но не в нечитаемый микрошрифт.
	_shrink_label_font_to_width(title_label, _readable_font_size(maxi(12, int(roundf(18.0 * content_scale.y))), 0, 26), title_label.size.x - 4.0, 12)
	title_label.add_theme_color_override("font_color", rare_color if is_rare else Color(0.96, 0.90, 0.68, 1.0))
	content.add_child(title_label)

	var description_label := Label.new()
	description_label.name = "LevelUpRewardDescription"
	description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description_label.text = _level_up_card_description(reward)
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.clip_text = true
	description_label.max_lines_visible = 2
	description_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_level_up_place_card_child(description_label, LU_CARD_DESCRIPTION_RECT, content_scale)
	description_label.add_theme_font_size_override("font_size", _readable_font_size(maxi(12, int(roundf(13.0 * content_scale.y))), 0, 18))
	description_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))
	content.add_child(description_label)

	# SCRUM-871: блок «до -> после» — до 3 строк реально пересчитанных дельт
	# производных статов; полный список — в тултипе карточки.
	var effect_panel := PanelContainer.new()
	effect_panel.name = "LevelUpRewardEffectPreview"
	effect_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_up_place_card_child(effect_panel, LU_CARD_EFFECT_RECT, content_scale)
	var effect_style := _atlas_chip_style(0.62, maxf(5.0, roundf(10.0 * content_scale.y)))
	effect_panel.add_theme_stylebox_override("panel", effect_style)
	content.add_child(effect_panel)

	# Хост строк — обычный Control с нулевым minimum size: PanelContainer не
	# растёт от текста, дельта-блок гарантированно остаётся в контент-зоне
	# карточки (гейт ui_no_overlap_matrix). Строки позиционируются вручную по
	# content-зоне чип-стиля.
	var effect_rows := Control.new()
	effect_rows.name = "LevelUpRewardEffectRows"
	effect_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect_rows.clip_contents = true
	effect_panel.add_child(effect_rows)

	var effect_content_margins := Vector4(
		effect_style.content_margin_left,
		effect_style.content_margin_top,
		effect_style.content_margin_right,
		effect_style.content_margin_bottom
	)
	var rows_size := Vector2(
		maxf(effect_panel.size.x - effect_content_margins.x - effect_content_margins.z, 8.0),
		maxf(effect_panel.size.y - effect_content_margins.y - effect_content_margins.w, 8.0)
	)
	var delta_lines := _level_up_delta_lines(reward, forecast)
	var row_height := rows_size.y / float(maxi(delta_lines.size(), 1))
	var effect_font := _readable_font_size(maxi(12, int(roundf(15.0 * content_scale.y))), 0, 20)
	var has_forecast_deltas: bool = not (forecast.get("deltas", []) as Array).is_empty()
	# Раскладка по фактическому minimum size строк: юзерский масштаб шрифта может
	# сделать строку выше расчётного ряда — не влезающие в зону строки отбрасываем
	# (кроме первой: контракт смоук/матрицы «LevelUpRewardEffectText с '->'»),
	# вместо того чтобы дать им выйти за контент-зону.
	var used_height := 0.0
	for line_index in range(delta_lines.size()):
		var line_label := Label.new()
		line_label.name = "LevelUpRewardEffectText" if line_index == 0 else "LevelUpRewardEffectText%d" % (line_index + 1)
		line_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line_label.text = str(delta_lines[line_index])
		line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		line_label.clip_text = true
		line_label.max_lines_visible = 1
		line_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_shrink_label_font_to_width(line_label, effect_font, rows_size.x - 4.0)
		line_label.add_theme_color_override("font_color", Color(0.76, 0.96, 0.80, 1.0) if has_forecast_deltas else Color(0.84, 0.97, 1.0, 1.0))
		var line_height := maxf(row_height, line_label.get_minimum_size().y)
		if line_index > 0 and used_height + line_height > rows_size.y + 0.5:
			line_label.free()
			continue
		line_label.position = Vector2(0.0, used_height)
		line_label.size = Vector2(rows_size.x, line_height)
		effect_rows.add_child(line_label)
		used_height += line_height
	return button


# SCRUM-871: контекст прогноза — живые статы/моды игрока (бой или меню-снапшот,
# fallback на базу класса) + актуальный weapon_config (боевой или собранный по
# выбранному классу/оружию тем же ProgressionData.weapon путём).
func _level_up_offer_advice(rewards: Array) -> Dictionary:
	var weapon_config = {}
	if game.current_player != null and is_instance_valid(game.current_player):
		weapon_config = game.current_player.get("weapon_config")
	if not (weapon_config is Dictionary) or (weapon_config as Dictionary).is_empty():
		weapon_config = game.PROGRESSION_DATA.weapon(game.selected_character_id, game.selected_weapon_id)
	return LevelUpAdvisor.recommend(rewards, _active_stats_snapshot(), _active_modifiers_snapshot(), weapon_config)


# SCRUM-871: понижает размер шрифта, пока строка не влезает в ширину зоны —
# юзерский масштаб шрифта (readability) может раздуть текст шире слота, а
# клип срезал бы края подписи. Вызывать после присвоения label.text.
func _shrink_label_font_to_width(label: Label, base_font_size: int, max_width: float, min_font_size := 12, fit_ratio := 0.62) -> void:
	# Внешняя мерка Font.get_string_size детерминирована, но фактический рендер
	# строки в окне шире мерки до ~1.5x (font oversampling/DPI), а внутренняя
	# мерка Label.get_minimum_size в этом же окружении флачит. Поэтому меряем
	# внешне и держим жёсткий запас fit_ratio 0.62 (~1/1.6): подпись гарантированно
	# помещается на всех целевых разрешениях, клип/ellipsis остаются страховкой.
	var font: Font = label.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var font_size := base_font_size
	if font != null:
		var fit_width := maxf(max_width, 8.0) * fit_ratio
		while font_size > min_font_size and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > fit_width:
			font_size -= 1
	label.add_theme_font_size_override("font_size", font_size)


# Строки блока изменений карточки: топ-3 дельты прогноза; без измеримых дельт —
# прежнее SCRUM-525 превью (спец-эффекты вроде призывов), затем краткий фолбэк.
func _level_up_delta_lines(reward: Dictionary, forecast: Dictionary) -> Array:
	var lines: Array = []
	for delta in (forecast.get("deltas", []) as Array):
		lines.append(LevelUpAdvisor.delta_line(delta))
		if lines.size() >= 3:
			break
	if lines.is_empty():
		lines = _level_up_effect_preview_lines(reward, 2)
	if lines.is_empty():
		lines.append(_level_up_reward_preview(reward))
	return lines


func _format_level_up_gain_percent(gain: float) -> String:
	var percent := gain * 100.0
	return "%.1f%%" % percent if absf(percent) < 10.0 else "%d%%" % int(roundf(percent))


# Тултип карточки: название, описание, полный список изменений, классовая
# интерпретация и объяснение бейджа рекомендации.
func _level_up_card_tooltip(reward: Dictionary, forecast: Dictionary, badge_kind: String, advice := {}) -> String:
	var parts: Array = [str(reward.get("title", "Upgrade"))]
	var description := str(reward.get("description", "")).strip_edges()
	if description != "":
		parts.append(description)
	var deltas: Array = forecast.get("deltas", [])
	if not deltas.is_empty():
		var delta_lines: Array = []
		for delta in deltas:
			delta_lines.append("  %s" % LevelUpAdvisor.delta_line(delta))
		parts.append("Изменения:\n%s" % "\n".join(delta_lines))
	else:
		parts.append(_level_up_reward_preview(reward))
	var interpretation := _reward_interpretation_text(reward)
	if interpretation != "":
		parts.append(interpretation)
	match badge_kind:
		"dps":
			parts.append("Метка «Лучший урон»: наибольший прирост урона в секунду (+%s) для твоего класса и оружия." % _format_level_up_gain_percent(float(advice.get("dps_gain", 0.0))))
		"surv":
			parts.append("Метка «Выживание»: наибольший прирост живучести (+%s) — здоровье, защита, уклонение, поглощение и лечение." % _format_level_up_gain_percent(float(advice.get("surv_gain", 0.0))))
		"both":
			parts.append("Метка «Лучший выбор»: сильнейший рост и урона (+%s), и живучести (+%s)." % [_format_level_up_gain_percent(float(advice.get("dps_gain", 0.0))), _format_level_up_gain_percent(float(advice.get("surv_gain", 0.0)))])
	return "\n".join(parts)


# SCRUM-883: бейдж рекомендации советника — полупрозрачная плашка атласа
# (_atlas_translucent_style) в слоте сверху карточки, подпись цветом типа
# бейджа. Механика выбора kind (BADGE_DPS/SURV/BOTH) — в LevelUpAdvisor.
func _add_level_up_badge(content: Control, badge_kind: String, content_scale: Vector2) -> void:
	var badge_meta: Dictionary = LU_BADGE_META[badge_kind]
	var badge := PanelContainer.new()
	badge.name = "LevelUpRewardBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", _atlas_translucent_style(0.7, 6.0))
	_level_up_place_card_child(badge, LU_CARD_BADGE_RECT, content_scale)
	content.add_child(badge)

	var badge_label := Label.new()
	badge_label.name = "LevelUpRewardBadgeLabel"
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_label.text = str(badge_meta["text"])
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.clip_text = true
	badge_label.max_lines_visible = 1
	badge_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# Фидбек читаемости SCRUM-883: пол кегля 12 (было 6) — плашка тянется на всю
	# ширину слота, подпись всегда читаемая.
	_shrink_label_font_to_width(badge_label, _readable_font_size(maxi(12, int(roundf(13.0 * content_scale.y))), 0, 16), badge.size.x - 8.0, 12)
	badge_label.add_theme_color_override("font_color", badge_meta["text_color"])
	badge.add_child(badge_label)


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
	content.add_theme_constant_override("separation", 5)

	var icon_row := HBoxContainer.new()
	icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(icon_row)
	icon_row.add_child(game.UIIconRegistry.make_icon(_reward_icon_id(reward), Vector2(40, 40)))

	var title_label := Label.new()
	title_label.name = "BattleRewardTitle"
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.text = str(reward.get("title", "Награда"))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.max_lines_visible = 2
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_font_size_override("font_size", _readable_font_size(17, 12, 22))
	title_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	content.add_child(title_label)

	var preview_label := Label.new()
	preview_label.name = "BattleRewardPreview"
	preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_label.text = _level_up_reward_preview(reward)
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_label.add_theme_font_size_override("font_size", _readable_font_size(14, 12, 16))
	preview_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))
	content.add_child(preview_label)

	var description_label := Label.new()
	description_label.name = "BattleRewardDescription"
	description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description_label.text = str(reward.get("description", ""))
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.max_lines_visible = 2
	description_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	description_label.add_theme_font_size_override("font_size", _readable_font_size(12, 12, 14))
	description_label.add_theme_color_override("font_color", Color(0.78, 0.66, 0.44, 1.0))
	content.add_child(description_label)

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.custom_minimum_size = Vector2(0.0, 0.0)
	content.add_child(spacer)

	var action_label := Label.new()
	action_label.name = "BattleRewardActionLabel"
	action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_label.text = "Получить"
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_label.add_theme_font_size_override("font_size", _readable_font_size(15, 12, 16))
	action_label.add_theme_color_override("font_color", Color(0.94, 0.80, 0.46, 1.0))
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
	content.add_theme_constant_override("separation", 3)

	var icon_row := HBoxContainer.new()
	icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(icon_row)
	icon_row.add_child(game.UIIconRegistry.make_icon(_reward_icon_id(reward), Vector2(52, 52)))

	var title_label := Label.new()
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.text = str(reward.get("title", "Артефакт"))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.max_lines_visible = 2
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_font_size_override("font_size", _readable_font_size(18, 0, 22))
	title_label.add_theme_color_override("font_color", tier_color)
	content.add_child(title_label)

	var tier_label := Label.new()
	tier_label.name = "EliteArtifactRewardTier"
	tier_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tier_label.text = _artifact_tier_text(reward)
	tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_label.max_lines_visible = 1
	tier_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tier_label.add_theme_font_size_override("font_size", _readable_font_size(13, 0, 16))
	tier_label.add_theme_color_override("font_color", tier_color)
	content.add_child(tier_label)

	var effect_label := Label.new()
	effect_label.name = "EliteArtifactRewardDescription"
	effect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect_label.text = str(reward.get("description", ""))
	effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_label.max_lines_visible = 2
	effect_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	effect_label.add_theme_font_size_override("font_size", _readable_font_size(12, 12, 15))
	effect_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))
	content.add_child(effect_label)

	var interpretation := _reward_interpretation_text(reward)
	if interpretation != "":
		var interp_label := Label.new()
		interp_label.name = "EliteArtifactRewardInterpretation"
		interp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		interp_label.text = interpretation
		interp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		interp_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		interp_label.max_lines_visible = 1
		interp_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		interp_label.add_theme_font_size_override("font_size", _readable_font_size(11, 12, 14))
		interp_label.add_theme_color_override("font_color", Color(0.78, 0.66, 0.44, 1.0))
		content.add_child(interp_label)

	return button


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
	_prepare_global_tooltips(root)

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
	title.add_theme_font_size_override("font_size", _readable_font_size(42))
	title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Выбери предмет. Описание появляется при наведении."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", _readable_font_size(16, 12))
	subtitle.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))
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

	# SCRUM-812: товары проходимы с геймпада (крестовина/стик), «Назад» доступна ui_down,
	# покупка по A. Стартовый фокус — первый доступный товар (иначе «Назад»). Соседи между
	# анкер-размещёнными слотами Godot добирает по геометрии.
	var shop_focus_items: Array = []
	for slot in items_area.get_children():
		if slot is Button and not (slot as Button).disabled:
			shop_focus_items.append(slot)
	_wire_run_ui_focus(shop_focus_items, true, [skip_button],
		shop_focus_items[0] if not shop_focus_items.is_empty() else skip_button)


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
			note_label.add_theme_font_size_override("font_size", _readable_font_size(22))
			note_label.add_theme_color_override("font_color", affinity_note["color"])
			note_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			note_label.offset_left = -26.0
			note_label.offset_top = 4.0
			note_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(note_label)
	# SCRUM-883: слот товара — чип-ряд Атласа (StyleBoxFlat, hover — золотой кант);
	# внутренности слота (иконка, пергамент-плашка, ценник) сохранены.
	_apply_atlas_choice_card_theme(button, _atlas_card_pad(SHOP_INLINE_SLOT_SIZE))
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
	caption.add_theme_font_size_override("font_size", _readable_font_size(13))
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
	price_label.add_theme_font_size_override("font_size", _readable_font_size(18, 12))
	price_label.add_theme_color_override("font_color", Color(0.94, 0.80, 0.46, 1.0) if affordable else Color(1.0, 0.42, 0.42, 1.0))
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
	label.add_theme_font_size_override("font_size", _readable_font_size(13))
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
	label.add_theme_font_size_override("font_size", _readable_font_size(17))
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
	box.name = "RestContent"
	var scroll := box.get_parent() as ScrollContainer
	if scroll != null:
		scroll.follow_focus = false
		scroll.scroll_vertical = 0
	var rest_title := box.find_child("MenuTitle_campfire", false, false) as Label
	if rest_title != null:
		rest_title.name = "RestTitle"
	var rest_subtitle := box.find_child("MenuSubtitle_campfire", false, false) as Label
	if rest_subtitle != null:
		rest_subtitle.name = "RestSubtitle"
	_create_menu_run_hud()
	# Escape = уйти от костра без бонуса (последовательно с пропуском магазина).
	game.ui_escape_action = game.route._advance_route_after_noncombat
	var rest_panel := box.get_parent().get_parent() as Control if box.get_parent() != null and box.get_parent().get_parent() != null else null
	var rest_root := rest_panel.get_parent() as Control if rest_panel != null and rest_panel.get_parent() != null else null
	if rest_root != null:
		_create_upgrade_fab(rest_root, _show_rest_screen)
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
	var back_button := _make_button("Назад")
	back_button.name = "RestBackButton"
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_set_action_button_size(back_button, 380.0, 54.0)
	back_button.tooltip_text = "Вернуться на карту без отдыха."
	back_button.pressed.connect(game.route._advance_route_after_noncombat)
	box.add_child(back_button)

	# SCRUM-812: два выбора листаются лево/право, «Назад» доступна ui_down, старт — «Передышка».
	_wire_run_ui_focus([heal_button, guard_button], true, [back_button], heal_button)


func _show_upgrade_screen() -> void:
	# SCRUM-883: панель улучшения — чип Атласа (экономический фолбэк) вместо
	# upgrade_panel @2K-рамки; карточки — чип-ряды общей фабрики.
	var box := _create_menu_box("Улучшение", "Выбери усиление оружия или параметра.", "upgrade")
	_create_menu_run_hud()
	var upgrade_card_size := _economy_choice_display_size(3)
	var choices := _make_economy_choice_row("UpgradeChoiceRow", upgrade_card_size, 3)
	box.add_child(choices)
	var index := 0
	var upgrade_cards: Array = []
	for reward in _random_level_up_rewards(3):
		var button := _make_economy_choice_card(str(reward["title"]), str(reward["description"]), "Выбрать", "UpgradeChoiceButton%d" % index, upgrade_card_size)
		choices.add_child(button)
		button.pressed.connect(func() -> void:
			_apply_reward_to_run(reward)
			game.route._advance_route_after_noncombat()
		)
		upgrade_cards.append(button)
		index += 1

	# SCRUM-812: карточки улучшений листаются лево/право по кругу, старт — первая; A выбирает.
	_wire_run_ui_focus(upgrade_cards, true, [], upgrade_cards[0] if not upgrade_cards.is_empty() else null)


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

	# SCRUM-883: единый атлас-стиль — панель события на плотном кожаном чипе
	# (StyleBoxFlat, латунный кант) вместо per-слот evt_panel @2K-рамки.
	var box := _create_menu_box(str(event_definition.get("title", route_node["name"])), str(event_definition.get("story", "Странная возможность на дороге: риск, награда или оба сразу.")), "event", _atlas_chip_style(0.94, roundf(18.0 * _atlas_ui_scale())))
	_configure_event_menu_layout(box)
	var event_panel := box.get_parent().get_parent() as Control if box.get_parent() != null and box.get_parent().get_parent() != null else null
	var event_root := event_panel.get_parent() as Control if event_panel != null and event_panel.get_parent() != null else null
	if event_root != null:
		event_root.name = "EventScreen"
	_create_menu_run_hud()
	# На событии докачка недоступна: повторный вход перегенерировал бы выборы события.
	# Не добавляем disabled-FAB внутрь MenuPanel_event: PanelContainer раскладывает всех
	# детей как контент панели, и лишняя кнопка ломает видимость title/story/choices.
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
		# SCRUM-883: карточки выбора носят единый atlas-чип общего хелпера
		# _make_economy_choice_card (StyleBoxFlat a>=0.8, hover — более яркий золотой
		# кант) — per-слот evt_card перештамповка и пере-инсет больше не нужны.
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
	# Единый возврат (фидбек 2026-07-08): везде «Назад» на плите back_260x104, 260×action-height.
	var back_button := _make_button("Назад")
	back_button.name = "EventBackButton"
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_set_action_button_size(back_button, 260.0, _atlas_action_button_height())
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
# Геометрия победы и поражения использует pause/end-модалку, но с SCRUM-841 result
# screens больше не кладутся в ScrollContainer: title/subtitle занимают верх safe-зоны,
# body делит середину на crest-slot и компактную run-summary column, а action button
# всегда остаётся в нижнем safe-слоте. Pause screen сохраняет scroll-контракт отдельно.
# SCRUM-883: модалка итогов — чип Атласа с симметричным чип-пэддингом.
const RESULT_MODAL_CHIP_PAD := 24.0
const RESULT_DESIGN_BASE_2K := Vector2(2560.0, 1440.0)
const RESULT_PANEL_2K := Rect2(831, 310, 898, 820)
const RESULT_SAFE_2K := Rect2(898, 396, 764, 656)
const RESULT_TITLE_2K := Rect2(898, 396, 764, 42)
const RESULT_SUBTITLE_2K := Rect2(898, 448, 764, 128)
const RESULT_BODY_2K := Rect2(898, 586, 764, 352)
const RESULT_CREST_2K := Rect2(899, 678, 168, 168)
const RESULT_SUMMARY_2K := Rect2(1086, 586, 576, 352)
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
	var result_layout := _create_result_menu_box("Победа", subtitle, "victory")
	_add_result_crest_to_slot(result_layout["crest_slot"] as Control, "victory")
	_add_run_summary_rows(result_layout["summary_column"] as VBoxContainer, true, true)  # SCRUM-502: сводка прогона
	var finish_run := func() -> void:
		game.current_act = 1
		game.route_stage = 0
		game.run_player_snapshot.clear()
		game.route_selected_indices.clear()
		game.used_event_ids.clear()
		game.current_event_definition.clear()
		game.pending_event_combat.clear()
		game.run_used_shop = false
		game.reset_run_metrics()  # SCRUM-502: метрики не текут в следующий забег
		game.route_nodes = game.route._generate_route()
		_show_main_menu()
	var restart_button := _make_button("Новый забег")
	restart_button.name = "VictoryNewRunButton"
	_set_action_button_size(restart_button, STANDARD_ACTION_BUTTON_WIDTH, _pause_end_result_button_height())
	restart_button.pressed.connect(finish_run)
	(result_layout["button_slot"] as Control).add_child(restart_button)
	game.ui_escape_action = finish_run
	# SCRUM-812: стартовый фокус на основной кнопке; B/Esc = основная кнопка (finish_run),
	# «пустого» закрытия нет.
	_wire_run_ui_focus([restart_button], false, [], restart_button)


func _show_death_screen(reason := "") -> void:
	game.clear_run_autosave()
	var subtitle := str(reason)
	if subtitle == "":
		subtitle = "Забег завершён: %s, этап маршрута %d." % [game.act_progress_label(), game.route_stage + 1]
	var result_layout := _create_result_menu_box("Поражение", subtitle, "death")
	_add_result_crest_to_slot(result_layout["crest_slot"] as Control, "death")
	_add_run_summary_rows(result_layout["summary_column"] as VBoxContainer, false, true)  # SCRUM-502: сводка прогона
	var back_to_menu := func() -> void:
		game.current_act = 1
		game.route_stage = 0
		game.run_player_snapshot.clear()
		game.route_selected_indices.clear()
		game.used_event_ids.clear()
		game.current_event_definition.clear()
		game.pending_event_combat.clear()
		game.run_used_shop = false
		game.reset_run_metrics()  # SCRUM-502: метрики не текут в следующий забег
		game.route_nodes = game.route._generate_route()
		_show_main_menu()
	var retry_button := _make_button("Начать заново")
	retry_button.name = "DeathRetryButton"
	_set_action_button_size(retry_button, STANDARD_ACTION_BUTTON_WIDTH, _pause_end_result_button_height())
	retry_button.pressed.connect(back_to_menu)
	(result_layout["button_slot"] as Control).add_child(retry_button)
	game.ui_escape_action = back_to_menu
	# SCRUM-812: стартовый фокус на «Начать заново»; B/Esc = основная кнопка, без «пустого» закрытия.
	_wire_run_ui_focus([retry_button], false, [], retry_button)


# SCRUM-502/SCRUM-841: блок сводки прогона на экранах победы/смерти. В старом
# контейнерном пути он кладётся в box; в no-scroll result layout — в компактную
# RunSummaryColumn. Все строки MOUSE_FILTER_IGNORE, чтобы не перехватывать клик
# кнопки и Escape. Стабильные имена узлов — для matrix-теста.
func _add_run_summary_rows(box: VBoxContainer, _is_victory: bool, force_compact := false) -> void:
	var metrics: Dictionary = game.run_metrics if not game.run_metrics.is_empty() else {}
	var outcome := str(metrics.get("outcome_reason", ""))
	var summary_parent := _result_summary_parent(box)
	var target: VBoxContainer = summary_parent if summary_parent != null else box
	var compact := force_compact or summary_parent != null

	if outcome != "":
		var outcome_label := Label.new()
		outcome_label.name = "RunSummaryOutcome"
		outcome_label.text = outcome
		outcome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		outcome_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		outcome_label.add_theme_font_size_override("font_size", _readable_font_size(13 if compact else 17, 12, 22))
		outcome_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
		outcome_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		target.add_child(outcome_label)

	var grid := GridContainer.new()
	grid.name = "RunSummaryStats"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14 if compact else 28)
	grid.add_theme_constant_override("v_separation", 2 if compact else 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_SHRINK_CENTER
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(grid)

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
		name_label.add_theme_font_size_override("font_size", _readable_font_size(12 if compact else 16, 12, 20))
		name_label.add_theme_color_override("font_color", Color(0.78, 0.66, 0.44, 1.0))
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(name_label)
		var value_label := Label.new()
		value_label.name = "RunSummaryStat_%s" % str(row[0])
		value_label.text = str(row[2])
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		value_label.add_theme_font_size_override("font_size", _readable_font_size(13 if compact else 16, 12, 20))
		value_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))
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
		artifacts_label.text = _compact_result_artifact_names(names) if compact else ", ".join(names)
		artifacts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		artifacts_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		artifacts_label.add_theme_font_size_override("font_size", _readable_font_size(11 if compact else 14, 12, 18))
		artifacts_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 0.95))
		artifacts_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		target.add_child(artifacts_label)


func _result_summary_parent(box: VBoxContainer) -> VBoxContainer:
	if box == null or not bool(box.get_meta("result_no_scroll_layout", false)):
		return null
	var screen_id := str(box.get_meta("result_screen_id", ""))
	if screen_id == "":
		return null
	return box.find_child("RunSummaryColumn_%s" % screen_id, true, false) as VBoxContainer


func _compact_result_artifact_names(names: Array) -> String:
	if names.size() <= 3:
		return ", ".join(names)
	var visible_names := []
	for index in range(mini(3, names.size())):
		visible_names.append(str(names[index]))
	return "%s + ещё %d" % [", ".join(visible_names), names.size() - visible_names.size()]


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
	# SCRUM-695: правило релевантности — в одном показе НЕ БОЛЕЕ 1 атрибута,
	# который для текущего класса `optional`, и ВСЕГДА минимум 1 primary/secondary
	# (никогда набор только из необязательных). Основные характеристики (rare-слот)
	# и capstone «Озарение» считаются не-optional и правилу не противоречат.
	var regular_pool: Array = game.PROGRESSION_DATA.level_up_rewards(game.selected_character_id)
	var stat_pool: Array = game.PROGRESSION_DATA.main_stat_level_up_rewards(game.selected_character_id)
	var prefill: Array = []
	# Capstone «Озарение» (ветвь Знаний мета-древа, SCRUM-150): ПЕРВОЕ повышение
	# в забеге гарантированно даёт основную характеристику. Гейт по level<=2
	# (run-persistent через снапшот) — срабатывает один раз за забег.
	var skill_mods: Dictionary = game.META_PROGRESSION.skill_modifiers(game.meta_state)
	if float(skill_mods.get("first_levelup_rare", 0.0)) > 0.0 and not stat_pool.is_empty() \
			and game.current_player != null and is_instance_valid(game.current_player) \
			and int(game.current_player.get("level")) <= 2:
		var forced_index: int = game.rng.randi_range(0, stat_pool.size() - 1)
		prefill.append(stat_pool[forced_index])
		stat_pool.remove_at(forced_index)
	# SCRUM-695: правило релевантности (≤1 optional, ≥1 primary/secondary) и взвешивание
	# по матрице вынесены в тестируемую ProgressionData.weighted_level_up_selection.
	return game.PROGRESSION_DATA.weighted_level_up_selection(
		regular_pool, stat_pool, count, game.selected_character_id, game.rng, MAIN_STAT_SLOT_CHANCE, prefill)


func _random_shop_items(count: int) -> Array:
	var scaling_stage: int = game.route_scaling_stage()
	var items := _weighted_sample(game.PROGRESSION_DATA.shop_items(scaling_stage, game.selected_character_id), count)
	var price_mult := float(game.ascension_difficulty()["price_mult"])
	# Ветвь Богатства мета-древа (SCRUM-150): скидка магазина (shop_price_mult ≤ 0).
	var skill_mods: Dictionary = game.META_PROGRESSION.skill_modifiers(game.meta_state)
	price_mult *= maxf(1.0 + float(skill_mods.get("shop_price_mult", 0.0)), 0.1)
	# SCRUM-835: class keystone downside может быть положительным штрафом к ценам
	# выбранного героя (thief «Джекпот»), поэтому читаем class-specific моды тоже.
	# QA-фикс: skill_modifiers_for_class = Атлас + созвездие класса, поэтому берём
	# только классовую ДЕЛЬТУ — иначе аккаунтная скидка Атласа применялась бы дважды.
	var class_skill_mods: Dictionary = game.META_PROGRESSION.skill_modifiers_for_class(game.meta_state, game.selected_character_id)
	var class_shop_price_delta := float(class_skill_mods.get("shop_price_mult", 0.0)) - float(skill_mods.get("shop_price_mult", 0.0))
	price_mult *= maxf(1.0 + class_shop_price_delta, 0.1)
	# Capstone «Связи в гильдии»: гарантированный редкий (tier 3) товар на стене.
	if float(skill_mods.get("guaranteed_rare_shop", 0.0)) > 0.0 and not items.is_empty():
		var has_rare := false
		for item in items:
			if int(item.get("tier", 1)) >= 3:
				has_rare = true
				break
		if not has_rare:
			var rares: Array = (game.PROGRESSION_DATA.shop_items(scaling_stage, game.selected_character_id) as Array).filter(
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
	label.add_theme_font_size_override("font_size", _readable_font_size(54 if big else 34, 0, 54 if big else 36))
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
		game.level_up_button.tooltip_text = "Открыть выбор улучшения (непотраченные уровни)"
		game.level_up_button.add_theme_font_size_override("font_size", _readable_font_size(34))
		_apply_fantasy_button_theme(game.level_up_button)
		game.level_up_button.pressed.connect(_open_pending_level_up)
		level_button_parent.add_child(game.level_up_button)

		var badge_panel := PanelContainer.new()
		badge_panel.name = "LevelUpPlusBadgePanel"
		badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = Color(1.0, 0.84, 0.22, 1.0)
		badge_style.set_corner_radius_all(12)
		badge_panel.add_theme_stylebox_override("panel", badge_style)
		game.level_up_button.add_child(badge_panel)

		var badge := Label.new()
		badge.name = "LevelUpPlusBadge"
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", _readable_font_size(16))
		badge.add_theme_color_override("font_color", Color(0.08, 0.05, 0.02, 1.0))
		badge_panel.add_child(badge)

	game.level_up_button.text = "+"
	game.level_up_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
	var viewport_size: Vector2 = game.get_viewport().get_visible_rect().size
	var scale := _scrum666_hud_scale_for_size(viewport_size)
	var plus_rect := _scrum666_scaled_rect(SCRUM666_CHUD_LEVELUP_BUTTON_2K, scale)
	var base_size := COMBAT_BLOCK_DESIGN_BASE_2K * scale
	game.level_up_button.offset_left = plus_rect.position.x - base_size.x
	game.level_up_button.offset_right = plus_rect.position.x + plus_rect.size.x - base_size.x
	game.level_up_button.offset_top = plus_rect.position.y - base_size.y
	game.level_up_button.offset_bottom = plus_rect.position.y + plus_rect.size.y - base_size.y
	game.level_up_button.custom_minimum_size = plus_rect.size
	game.level_up_button.size = plus_rect.size
	game.level_up_button.set_meta("scrum666_frame_rect", _scrum666_scaled_rect(SCRUM666_CHUD_LEVELUP_FRAME_2K, scale))
	game.level_up_button.set_meta("scrum666_content_zone", plus_rect)
	game.level_up_button.clip_text = true
	game.level_up_button.add_theme_font_size_override("font_size", _readable_font_size(maxi(18, int(roundf(24.0 * scale))), 0, 34))
	_apply_fantasy_button_theme(game.level_up_button)

	var badge_panel := game.level_up_button.find_child("LevelUpPlusBadgePanel", true, false) as PanelContainer
	if badge_panel != null:
		var badge_rect := _scrum666_scaled_rect(SCRUM666_CHUD_LEVELUP_BADGE_2K, scale)
		var local_badge_pos := badge_rect.position - plus_rect.position
		badge_panel.offset_left = local_badge_pos.x
		badge_panel.offset_top = local_badge_pos.y
		badge_panel.offset_right = local_badge_pos.x + badge_rect.size.x
		badge_panel.offset_bottom = local_badge_pos.y + badge_rect.size.y
		badge_panel.custom_minimum_size = badge_rect.size
		badge_panel.set_meta("scrum666_content_zone", badge_rect)
	var badge_label := game.level_up_button.find_child("LevelUpPlusBadge", true, false) as Label
	if badge_label != null:
		badge_label.text = str(game.pending_level_ups)
		badge_label.add_theme_font_size_override("font_size", _readable_font_size(maxi(9, int(roundf(14.0 * scale))), 0, 22))


func _format_level_up_reward_text(reward: Dictionary) -> String:
	var preview := _level_up_reward_preview(reward)
	var interpretation := _reward_interpretation_text(reward)
	return "%s\n%s\n%s%s" % [
		str(reward.get("title", "Upgrade")),
		preview,
		str(reward.get("description", "")),
		"\n%s" % interpretation if interpretation != "" else "",
	]


func _level_up_card_description(reward: Dictionary) -> String:
	var description := str(reward.get("description", "")).strip_edges()
	if description == "":
		var interpretation := _reward_interpretation_text(reward).replace("Интерпретация: ", "")
		if interpretation != "":
			return interpretation
		return "Особое усиление текущего билда."
	return description


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


func _level_up_effect_preview_lines(reward: Dictionary, max_lines := 2) -> Array:
	var lines: Array = []
	if reward.has("stats"):
		for stat_key in (reward.get("stats", {}) as Dictionary).keys():
			var stat_id := str(stat_key)
			var delta := float((reward["stats"] as Dictionary).get(stat_id, 0.0))
			for line in _attribute_upgrade_preview_lines(stat_id, delta):
				lines.append(line)
				if lines.size() >= max_lines:
					return lines
			if lines.is_empty():
				var before_stats := _active_stats_snapshot()
				var before_value := float(before_stats.get(stat_id, 0.0))
				var stat_name := str(game.PROGRESSION_DATA.STAT_NAMES.get(stat_id, stat_id))
				lines.append("%s: %.0f -> %.0f" % [stat_name, before_value, before_value + delta])
				if lines.size() >= max_lines:
					return lines
	if reward.has("mods") or reward.has("affinity_mods"):
		var before_stats := _active_stats_snapshot()
		var before_mods := _active_modifiers_snapshot()
		var after_mods := before_mods.duplicate(true)
		_level_up_apply_mod_preview(after_mods, reward.get("mods", {}) as Dictionary)
		_level_up_apply_mod_preview(after_mods, reward.get("affinity_mods", {}) as Dictionary)
		var weapon_config = game.PROGRESSION_DATA.weapon(game.selected_character_id, game.selected_weapon_id)
		var before_parameters: Dictionary = game.PROGRESSION_DATA.derived_parameters(before_stats, before_mods, weapon_config)
		var after_parameters: Dictionary = game.PROGRESSION_DATA.derived_parameters(before_stats, after_mods, weapon_config)
		var seen_parameters := {}
		for mod_dict in [reward.get("mods", {}) as Dictionary, reward.get("affinity_mods", {}) as Dictionary]:
			for modifier_id_raw in mod_dict.keys():
				var modifier_id := str(modifier_id_raw)
				var parameter_id := str(game.LEVEL_UP_MOD_DISPLAY.get(modifier_id, modifier_id))
				if parameter_id == "damage":
					parameter_id = game.PROGRESSION_DATA.damage_parameter_for(game.selected_character_id)
				if seen_parameters.has(parameter_id):
					continue
				seen_parameters[parameter_id] = true
				var before_value := float(before_parameters.get(parameter_id, before_mods.get(modifier_id, 0.0)))
				var after_value := float(after_parameters.get(parameter_id, after_mods.get(modifier_id, 0.0)))
				var before_text := _format_level_up_value(parameter_id, before_value)
				var after_text := _format_level_up_value(parameter_id, after_value)
				if before_text == after_text and after_mods.has(modifier_id):
					before_text = _format_level_up_value(parameter_id, float(before_mods.get(modifier_id, 0.0)))
					after_text = _format_level_up_value(parameter_id, float(after_mods.get(modifier_id, 0.0)))
				if before_text == after_text:
					continue
				lines.append("%s: %s -> %s" % [_level_up_parameter_label(parameter_id), before_text, after_text])
				if lines.size() >= max_lines:
					return lines
	if lines.is_empty():
		var description := str(reward.get("description", "")).strip_edges()
		lines.append(description if description != "" else "Эффект применится к текущему билду")
	return lines


func _level_up_apply_mod_preview(target_mods: Dictionary, mods: Dictionary) -> void:
	for modifier_id in mods.keys():
		if str(modifier_id).ends_with("_multiplier"):
			target_mods[modifier_id] = float(target_mods.get(modifier_id, 1.0)) * float(mods[modifier_id])
		else:
			target_mods[modifier_id] = float(target_mods.get(modifier_id, 0.0)) + float(mods[modifier_id])


func _level_up_reward_preview(reward: Dictionary) -> String:
	var preview_lines := _level_up_effect_preview_lines(reward, 2)
	if not preview_lines.is_empty():
		return " • ".join(preview_lines)
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
	game.run_used_shop = true
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

		# SCRUM-830: гардим по отсутствию именно КЛАВИАТУРНОГО (InputEventKey) события,
		# а не по is_empty(). Автолоад InputDeviceManager (SCRUM-811) может предзасеять
		# joypad-события в глобальный InputMap ДО этого вызова (гонка старта под нагрузкой);
		# тогда is_empty()=false и клавиатурные дефолты (Escape=pause, R=ultimate и др.)
		# терялись — Escape не открывал quit-диалог, R не давал ультимейт. Проверка «нет
		# key-события» доливает клавиатуру идемпотентно, joypad не трогая
		# (_apply_keycodes_to_action стирает только key-события).
		if not _action_has_key_event(action_name):
			_apply_keycodes_to_action(action_name, _default_keycodes_for_action(input_action))
	_apply_saved_input_bindings()


func _action_has_key_event(action_name: String) -> bool:
	if not InputMap.has_action(action_name):
		return false
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			return true
	return false


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
	# SCRUM-816 баг-фикс: раньше здесь был action_erase_events, стиравший ВСЕ события
	# экшена — включая joypad-биндинги ядра (SCRUM-811). Клавиатурный ребинд/применение
	# сохранённых клавиш ронял геймпад. Теперь трогаем только InputEventKey.
	# ВАЖНО: НЕ звать здесь ensure_joypad_bindings — это примитив, используемый в
	# цикле _setup_default_input_actions. Долив joypad всем экшенам в середине цикла
	# сделал бы ещё-не-обработанные экшены «непустыми» и клавиатурные дефолты бы
	# пропустились. Долив делает менеджер (autoload) после первого кадра, а в
	# пользовательских ребиндах — вызывающие (_handle_rebind_input/reset) явно.
	_erase_key_events(action_name)
	for keycode_value in keycodes:
		var keycode := int(keycode_value)
		if keycode == 0:
			continue
		var event := InputEventKey.new()
		event.keycode = keycode
		InputMap.action_add_event(action_name, event)


func _erase_key_events(action_name: String) -> void:
	# Стереть только клавиатурные события экшена, не трогая joypad-биндинги.
	if not InputMap.has_action(action_name):
		return
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			InputMap.action_erase_event(action_name, event)


func _input_device_manager() -> Node:
	# Автолоад InputDeviceManager (SCRUM-811). null-safe для тестов без автолоада.
	if game == null:
		return null
	var tree = game.get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("InputDeviceManager")


func _ensure_joypad_after_rebind() -> void:
	var idm := _input_device_manager()
	if idm != null and idm.has_method("ensure_joypad_bindings"):
		idm.ensure_joypad_bindings()


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
	_rebind_is_gamepad = false
	var label := _action_label(action_name)
	var box := _create_menu_box("Клавиша: %s" % label, "Нажми новую клавишу. Esc отменяет.", "settings")

	var cancel_button := _make_button("Отмена")
	cancel_button.pressed.connect(func() -> void:
		game.pending_rebind_action = ""
		_show_settings_menu()
	)
	box.add_child(cancel_button)


func _handle_rebind_input(event: InputEvent) -> void:
	# SCRUM-816: один диспетчер на два режима прослушивания. В режиме геймпада ждём
	# joypad-кнопку/ось, в клавиатурном — клавишу. Роутинг из main._input по
	# game.pending_rebind_action; _rebind_is_gamepad различает режим.
	if _rebind_is_gamepad:
		_handle_gamepad_rebind_input(event)
		return

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

	# SCRUM-816 баг-фикс: только клавиатурные события, joypad ядра не затираем.
	_erase_key_events(game.pending_rebind_action)
	var new_event := InputEventKey.new()
	new_event.keycode = keycode
	new_event.physical_keycode = event.physical_keycode
	InputMap.action_add_event(game.pending_rebind_action, new_event)
	_ensure_joypad_after_rebind()

	game.input_bindings = _current_input_bindings()
	game.save_game_settings()
	game.pending_rebind_action = ""
	_show_settings_menu()


func _handle_gamepad_rebind_input(event: InputEvent) -> void:
	# Отмена: Esc (клавиатура) или B (ui_cancel). B в этот момент НЕ назначается.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_cancel_gamepad_rebind()
		return
	if event is InputEventJoypadButton and event.pressed and int(event.button_index) == JOY_BUTTON_B:
		_cancel_gamepad_rebind()
		return

	if event is InputEventJoypadButton and event.pressed:
		_assign_gamepad_button(game.pending_rebind_action, int(event.button_index))
		return
	if event is InputEventJoypadMotion and absf(event.axis_value) > GAMEPAD_REBIND_ACTIVATION:
		var value := 1.0 if event.axis_value > 0.0 else -1.0
		_assign_gamepad_axis(game.pending_rebind_action, int(event.axis), value)
		return


func _cancel_gamepad_rebind() -> void:
	game.pending_rebind_action = ""
	_rebind_is_gamepad = false
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
	game.pending_rebind_action = ""
	_rebind_is_gamepad = false
	game._clear_ui()

	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "RebindConflictDialog"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	game.ui_layer.add_child(root)
	_prepare_global_tooltips(root)
	_add_screen_background(root, "settings")

	var panel := Panel.new()
	panel.name = "RebindConflictPanel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -RC_PANEL_2K.size.x * 0.5
	panel.offset_top = -RC_PANEL_2K.size.y * 0.5
	panel.offset_right = RC_PANEL_2K.size.x * 0.5
	panel.offset_bottom = RC_PANEL_2K.size.y * 0.5
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _overhaul_2k_frame_style("rc_panel", RC_PANEL_2K.size))
	panel.set_meta("rebind_conflict_stage", "openai_mockup_ready_runtime_rc_assets")
	panel.set_meta("rebind_conflict_slot", "rc_panel")
	panel.set_meta("rebind_conflict_content_margins", _overhaul_2k_content_margins("rc_panel", RC_PANEL_2K.size))
	panel.set_meta("rebind_conflict_content_rect", Rect2(RC_SAFE_2K.position - RC_PANEL_2K.position, RC_SAFE_2K.size))
	root.add_child(panel)

	var title_label := Label.new()
	title_label.name = "RebindConflictTitle"
	title_label.text = "Клавиша занята"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", _readable_font_size(36, 0, 40))
	title_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	panel.add_child(title_label)
	title_label.position = RC_TITLE_2K.position - RC_PANEL_2K.position
	title_label.size = RC_TITLE_2K.size

	var message_label := Label.new()
	message_label.name = "RebindConflictMessage"
	message_label.text = "%s занята: «%s». Для «%s» выбери другую." % [key_name, conflict_label, target_label]
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	message_label.clip_text = true
	message_label.add_theme_font_size_override("font_size", _readable_font_size(18, 0, 24))
	message_label.add_theme_color_override("font_color", Color(0.88, 0.86, 0.78, 1.0))
	panel.add_child(message_label)
	message_label.position = RC_MESSAGE_2K.position - RC_PANEL_2K.position
	message_label.size = RC_MESSAGE_2K.size

	var retry_button := _make_button("Выбрать другую")
	retry_button.name = "RebindConflictRetryButton"
	_set_action_button_size(retry_button, RC_BTN_RETRY_2K.size.x, RC_BTN_RETRY_2K.size.y)
	_apply_overhaul_2k_button_theme(retry_button, "rc_btn", RC_BTN_RETRY_2K.size)
	retry_button.clip_text = true
	retry_button.add_theme_font_size_override("font_size", _readable_font_size(18, 0, 18))
	retry_button.pressed.connect(func() -> void:
		_begin_rebind(target_action)
	)
	panel.add_child(retry_button)
	retry_button.position = RC_BTN_RETRY_2K.position - RC_PANEL_2K.position
	retry_button.size = RC_BTN_RETRY_2K.size
	var back_button := _make_button("Настройки")
	back_button.name = "RebindConflictBackButton"
	_set_action_button_size(back_button, RC_BTN_BACK_2K.size.x, RC_BTN_BACK_2K.size.y)
	_apply_overhaul_2k_button_theme(back_button, "rc_btn", RC_BTN_BACK_2K.size)
	back_button.clip_text = true
	back_button.add_theme_font_size_override("font_size", _readable_font_size(18, 0, 18))
	back_button.pressed.connect(func() -> void:
		game.pending_rebind_action = ""
		_show_settings_menu()
	)
	panel.add_child(back_button)
	back_button.position = RC_BTN_BACK_2K.position - RC_PANEL_2K.position
	back_button.size = RC_BTN_BACK_2K.size
	retry_button.focus_neighbor_right = back_button.get_path()
	retry_button.focus_neighbor_left = back_button.get_path()
	back_button.focus_neighbor_left = retry_button.get_path()
	back_button.focus_neighbor_right = retry_button.get_path()
	retry_button.grab_focus()


func _reset_input_bindings_to_defaults() -> void:
	for input_action in game.INPUT_ACTIONS:
		_apply_keycodes_to_action(str(input_action["action"]), _default_keycodes_for_action(input_action))
	# После сброса клавиатуры один раз доливаем joypad (эрейз клавиш их не трогал,
	# но страхуемся и на случай, если экшен был свежесоздан).
	_ensure_joypad_after_rebind()
	game.input_bindings = _current_input_bindings()
	game.save_game_settings()


func _binding_text(action_name: String) -> String:
	# Только клавиатурные события: joypad-биндинги ядра (SCRUM-811) теперь живут в
	# том же экшене, но у клавиатурной кнопки-ребинда показываем лишь клавиши.
	var labels := []
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			var keycode: int = int(event.keycode if event.keycode != 0 else event.physical_keycode)
			labels.append(OS.get_keycode_string(keycode))
	if labels.is_empty():
		return "Не назначено"
	return " / ".join(labels)


# --- SCRUM-816: геймпад — текст биндингов, ребинд, статус устройства ---

func _gamepad_binding_text(action_name: String) -> String:
	if not InputMap.has_action(action_name):
		return "Не назначено"
	var labels := []
	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton:
			labels.append(_gamepad_button_label(int(event.button_index)))
		elif event is InputEventJoypadMotion:
			labels.append(_gamepad_axis_label(int(event.axis), float(event.axis_value)))
	if labels.is_empty():
		return "Не назначено"
	return " / ".join(labels)


func _gamepad_button_label(button_index: int) -> String:
	return GAMEPAD_BUTTON_LABELS.get(button_index, "Кнопка %d" % button_index)


func _gamepad_axis_label(axis: int, value: float) -> String:
	match axis:
		JOY_AXIS_LEFT_X:
			return "Стик ←" if value < 0.0 else "Стик →"
		JOY_AXIS_LEFT_Y:
			return "Стик ↑" if value < 0.0 else "Стик ↓"
		JOY_AXIS_RIGHT_X:
			return "Пр. стик ←" if value < 0.0 else "Пр. стик →"
		JOY_AXIS_RIGHT_Y:
			return "Пр. стик ↑" if value < 0.0 else "Пр. стик ↓"
		JOY_AXIS_TRIGGER_LEFT:
			return "LT"
		JOY_AXIS_TRIGGER_RIGHT:
			return "RT"
	return "Ось %d" % axis


func _gamepad_glyph_for_action(action_name: String) -> Texture2D:
	# Иконка первого joypad-события экшена, если ассет-манифест существует (SCRUM-810).
	# null-safe: нет ассета → null → показываем только текст.
	if not InputMap.has_action(action_name):
		return null
	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton:
			return InputGlyphRegistry.texture_for_joy_button(int(event.button_index), 32)
		elif event is InputEventJoypadMotion:
			return InputGlyphRegistry.texture_for_axis(int(event.axis), 32)
	return null


func _begin_gamepad_rebind(action_name: String) -> void:
	game.pending_rebind_action = action_name
	_rebind_is_gamepad = true
	var label := _action_label(action_name)
	var box := _create_menu_box("Геймпад: %s" % label, "Нажми кнопку или наклони стик. B/Esc отменяет.", "settings")

	var cancel_button := _make_button("Отмена")
	cancel_button.pressed.connect(func() -> void:
		_cancel_gamepad_rebind()
	)
	box.add_child(cancel_button)


func _assign_gamepad_button(action_name: String, button_index: int) -> void:
	var conflict := _gamepad_button_conflict(action_name, button_index)
	if conflict != "":
		_show_gamepad_rebind_conflict(action_name, _gamepad_button_label(button_index), conflict)
		return
	_commit_gamepad_binding(action_name, {"buttons": [button_index], "axes": []})


func _assign_gamepad_axis(action_name: String, axis: int, value: float) -> void:
	var conflict := _gamepad_axis_conflict(action_name, axis, value)
	if conflict != "":
		_show_gamepad_rebind_conflict(action_name, _gamepad_axis_label(axis, value), conflict)
		return
	_commit_gamepad_binding(action_name, {"buttons": [], "axes": [{"axis": axis, "value": value}]})


func _commit_gamepad_binding(action_name: String, binding: Dictionary) -> void:
	# Заменяет только joypad-часть экшена; клавиатурные события не трогаются
	# (ensure_joypad_bindings внутри set_gamepad_bindings стирает лишь joypad).
	if not (game.gamepad_bindings is Dictionary):
		game.gamepad_bindings = {}
	game.gamepad_bindings[action_name] = binding
	var idm := _input_device_manager()
	if idm != null and idm.has_method("set_gamepad_bindings"):
		idm.set_gamepad_bindings(game.gamepad_bindings)
	else:
		# Тесты без автолоада: применяем joypad-часть локально, детерминированно.
		_apply_gamepad_binding_local(action_name, binding)
	game.save_game_settings()
	game.pending_rebind_action = ""
	_rebind_is_gamepad = false
	_show_settings_menu()


func _apply_gamepad_binding_local(action_name: String, binding: Dictionary) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			InputMap.action_erase_event(action_name, event)
	for button_index in binding.get("buttons", []):
		var btn := InputEventJoypadButton.new()
		btn.button_index = int(button_index) as JoyButton
		InputMap.action_add_event(action_name, btn)
	for axis_binding in binding.get("axes", []):
		var motion := InputEventJoypadMotion.new()
		motion.axis = int(axis_binding.get("axis", 0)) as JoyAxis
		motion.axis_value = float(axis_binding.get("value", 1.0))
		InputMap.action_add_event(action_name, motion)


func _gamepad_button_conflict(target_action: String, button_index: int) -> String:
	for input_action in game.INPUT_ACTIONS:
		var action_name: String = input_action["action"]
		if action_name == target_action:
			continue
		for event in InputMap.action_get_events(action_name):
			if event is InputEventJoypadButton and int(event.button_index) == button_index:
				return action_name
	return ""


func _gamepad_axis_conflict(target_action: String, axis: int, value: float) -> String:
	for input_action in game.INPUT_ACTIONS:
		var action_name: String = input_action["action"]
		if action_name == target_action:
			continue
		for event in InputMap.action_get_events(action_name):
			if event is InputEventJoypadMotion and int(event.axis) == axis \
					and signf(event.axis_value) == signf(value):
				return action_name
	return ""


func _show_gamepad_rebind_conflict(target_action: String, binding_desc: String, conflict_action: String) -> void:
	# Тот же UX, что и у клавиатурного конфликта (_show_rebind_conflict), но текст
	# про кнопку/ось геймпада. «Выбрать другую» перезапускает прослушивание.
	var target_label := _action_label(target_action)
	var conflict_label := _action_label(conflict_action)
	game.pending_rebind_action = ""
	_rebind_is_gamepad = false
	var box := _create_menu_box("Кнопка занята",
		"%s занята: «%s». Для «%s» выбери другую." % [binding_desc, conflict_label, target_label], "settings")

	var retry_button := _make_button("Выбрать другую")
	retry_button.name = "GamepadRebindConflictRetryButton"
	retry_button.pressed.connect(func() -> void:
		_begin_gamepad_rebind(target_action)
	)
	box.add_child(retry_button)

	var back_button := _make_button("Настройки")
	back_button.name = "GamepadRebindConflictBackButton"
	back_button.pressed.connect(func() -> void:
		_cancel_gamepad_rebind()
	)
	box.add_child(back_button)
	_wire_run_ui_focus([retry_button, back_button], true, [], retry_button)
	game.ui_escape_action = _cancel_gamepad_rebind


func _reset_gamepad_bindings_to_defaults() -> void:
	game.gamepad_bindings = {}
	var idm := _input_device_manager()
	if idm != null and idm.has_method("reset_gamepad_bindings_to_defaults"):
		idm.reset_gamepad_bindings_to_defaults()
	game.save_game_settings()
	_show_settings_menu()


func _refresh_gamepad_status_line() -> void:
	if _gamepad_status_label == null or not is_instance_valid(_gamepad_status_label):
		return
	var idm := _input_device_manager()
	var connected := false
	var pad_name := ""
	if idm != null and idm.has_method("gamepad_connected"):
		connected = idm.gamepad_connected()
		pad_name = idm.gamepad_name()
	else:
		var pads := Input.get_connected_joypads()
		connected = not pads.is_empty()
		pad_name = Input.get_joy_name(int(pads[0])) if not pads.is_empty() else ""
	if connected:
		_gamepad_status_label.text = "Геймпад: %s подключён" % (pad_name if pad_name != "" else "устройство")
	else:
		_gamepad_status_label.text = "Геймпад не обнаружен"


func _connect_gamepad_status_signals() -> void:
	# Идемпотентно: ui_screens живёт всю сессию, коллбэки гардятся валидностью Label.
	if not Input.joy_connection_changed.is_connected(_on_gamepad_joy_connection_changed):
		Input.joy_connection_changed.connect(_on_gamepad_joy_connection_changed)
	var idm := _input_device_manager()
	if idm != null and idm.has_signal("device_changed") \
			and not idm.device_changed.is_connected(_on_gamepad_device_changed):
		idm.device_changed.connect(_on_gamepad_device_changed)


func _on_gamepad_device_changed(_kind: String) -> void:
	_refresh_gamepad_status_line()


func _on_gamepad_joy_connection_changed(_device: int, _connected: bool) -> void:
	_refresh_gamepad_status_line()


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
	_prepare_global_tooltips(root)

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
	title.add_theme_font_size_override("font_size", _readable_font_size(32))
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
	hint.add_theme_font_size_override("font_size", _readable_font_size(16))
	hint.add_theme_color_override("font_color", Color(0.88, 0.86, 0.78, 1.0))
	scroll_body.add_child(hint)

	var text_edit := TextEdit.new()
	text_edit.name = "FeedbackTextEdit"
	text_edit.custom_minimum_size = Vector2(0, 130)
	text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_edit.placeholder_text = "Что случилось? Где ты был в игре? Что ожидал увидеть?"
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_edit.add_theme_font_size_override("font_size", _readable_font_size(17))
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
	status.add_theme_font_size_override("font_size", _readable_font_size(14))
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
	_prepare_global_tooltips(root)

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
	var result_panel := _is_result_screen_background(screen_background_id)
	var display_size := _pause_end_modal_display_size(screen_background_id) if pause_end_panel else Vector2.ZERO
	var half_size := panel_display_size * 0.5 if panel_display_size != Vector2.ZERO else (display_size * 0.5 if pause_end_panel else (_economy_menu_panel_half_size(screen_background_id) if economy_panel else Vector2(560.0, 330.0)))
	panel.offset_left = -half_size.x
	panel.offset_top = -half_size.y
	panel.offset_right = half_size.x
	panel.offset_bottom = half_size.y
	if pause_end_panel:
		panel.name = "PauseEndModalPanel_%s" % screen_background_id
		panel.clip_contents = true
		panel.set_meta("pause_end_display_size", display_size)
		panel.set_meta("pause_end_content_margins", _pause_end_modal_content_margins(display_size, screen_background_id))
		panel.set_meta("pause_end_content_rect", _pause_end_modal_content_rect(display_size, screen_background_id))
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
	box.add_theme_constant_override("separation", (8 if result_panel and display_size.y < 660.0 else 10) if result_panel else (12 if pause_end_panel else (16 if economy_panel else 14)))
	if pause_end_panel and not result_panel:
		var scroll := ScrollContainer.new()
		scroll.name = "PauseEndModalScroll_%s" % screen_background_id
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		panel.add_child(scroll)
		scroll.add_child(box)
	elif result_panel:
		var result_shell := Control.new()
		result_shell.name = "ResultShell_%s" % screen_background_id
		result_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		result_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		result_shell.clip_contents = true
		panel.add_child(result_shell)
		result_shell.add_child(box)
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.custom_minimum_size = Vector2.ZERO
		box.clip_contents = true
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
	title_label.add_theme_font_size_override("font_size", _readable_font_size(34 if pause_end_panel and game.get_viewport().get_visible_rect().size.y < 800.0 else 42, 0, 60))
	title_label.add_theme_color_override("font_color", Color(0.96, 0.9, 0.68, 1.0))
	box.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.name = "MenuSubtitle_%s" % screen_background_id if screen_background_id != "" else "MenuSubtitle"
	subtitle_label.text = subtitle
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle_label.add_theme_font_size_override("font_size", _readable_font_size(15 if pause_end_panel and game.get_viewport().get_visible_rect().size.y < 800.0 else 17, 0, 24))
	subtitle_label.add_theme_color_override("font_color", Color(0.93, 0.89, 0.80, 1.0))
	box.add_child(subtitle_label)
	if result_panel:
		_configure_result_menu_layout(box, screen_background_id, display_size)

	return box


func _create_result_menu_box(title: String, subtitle: String, screen_background_id: String) -> Dictionary:
	game._clear_ui()

	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.ui_layer.add_child(root)
	_prepare_global_tooltips(root)
	_add_screen_background(root, screen_background_id)

	var display_size := _pause_end_modal_display_size(screen_background_id)
	var panel := PanelContainer.new()
	panel.name = "PauseEndModalPanel_%s" % screen_background_id
	panel.clip_contents = true
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	var half_size := display_size * 0.5
	panel.offset_left = -half_size.x
	panel.offset_top = -half_size.y
	panel.offset_right = half_size.x
	panel.offset_bottom = half_size.y
	panel.set_meta("pause_end_display_size", display_size)
	panel.set_meta("pause_end_content_margins", _pause_end_modal_content_margins(display_size, screen_background_id))
	panel.set_meta("pause_end_content_rect", _pause_end_modal_content_rect(display_size, screen_background_id))
	panel.add_theme_stylebox_override("panel", _pause_end_modal_style(display_size, screen_background_id))
	root.add_child(panel)

	var content := Control.new()
	content.name = "ResultContent_%s" % screen_background_id
	content.clip_contents = true
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.custom_minimum_size = Vector2.ZERO
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.set_meta("result_no_scroll_layout", true)
	content.set_meta("result_screen_id", screen_background_id)
	content.set_meta("result_content_rect", _pause_end_modal_content_rect(display_size, screen_background_id))
	panel.add_child(content)

	var title_label := Label.new()
	title_label.name = "MenuTitle_%s" % screen_background_id
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.clip_text = true
	title_label.add_theme_color_override("font_color", Color(0.96, 0.9, 0.68, 1.0))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.name = "MenuSubtitle_%s" % screen_background_id
	subtitle_label.text = subtitle
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.clip_text = true
	subtitle_label.add_theme_color_override("font_color", Color(0.93, 0.89, 0.80, 1.0))
	subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(subtitle_label)

	var body := Control.new()
	body.name = "ResultBody_%s" % screen_background_id
	body.clip_contents = true
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(body)

	var crest_slot := CenterContainer.new()
	crest_slot.name = "ResultCrestSlot_%s" % screen_background_id
	crest_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(crest_slot)

	var summary_column := VBoxContainer.new()
	summary_column.name = "RunSummaryColumn_%s" % screen_background_id
	summary_column.alignment = BoxContainer.ALIGNMENT_CENTER
	summary_column.clip_contents = true
	summary_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(summary_column)

	var button_slot := CenterContainer.new()
	button_slot.name = "ResultButtonSlot_%s" % screen_background_id
	button_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(button_slot)

	content.resized.connect(func() -> void:
		_layout_result_content(content, screen_background_id)
	)
	_layout_result_content(content, screen_background_id)
	call_deferred("_layout_result_content", content, screen_background_id)

	return {
		"content": content,
		"crest_slot": crest_slot,
		"summary_column": summary_column,
		"button_slot": button_slot,
	}


func _layout_result_content(content: Control, screen_background_id: String) -> void:
	if content == null or not is_instance_valid(content):
		return
	var size := content.size
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var compact := size.y < 520.0 or float(game.get_viewport().get_visible_rect().size.y) < 760.0
	var gap := 6.0 if compact else 10.0
	var button_height := minf(_pause_end_result_button_height(), maxf(56.0, size.y * 0.20))
	var available_height := maxf(1.0, size.y - button_height - gap * 3.0)
	var title_height := clampf(available_height * 0.12, 28.0 if compact else 34.0, 42.0)
	var subtitle_height := clampf(available_height * (0.23 if compact else 0.25), 76.0 if compact else 104.0, 112.0 if compact else 128.0)
	var body_height := maxf(1.0, available_height - title_height - subtitle_height)
	var minimum_body := 162.0 if compact else 220.0
	if body_height < minimum_body:
		var deficit := minimum_body - body_height
		subtitle_height = maxf(58.0 if compact else 82.0, subtitle_height - deficit)
		body_height = maxf(1.0, available_height - title_height - subtitle_height)

	var title := content.get_node_or_null("MenuTitle_%s" % screen_background_id) as Label
	var subtitle := content.get_node_or_null("MenuSubtitle_%s" % screen_background_id) as Label
	var body := content.get_node_or_null("ResultBody_%s" % screen_background_id) as Control
	var button_slot := content.get_node_or_null("ResultButtonSlot_%s" % screen_background_id) as Control

	_apply_control_rect(title, Rect2(0.0, 0.0, size.x, title_height))
	_apply_control_rect(subtitle, Rect2(0.0, title_height + gap, size.x, subtitle_height))
	_apply_control_rect(body, Rect2(0.0, title_height + gap + subtitle_height + gap, size.x, body_height))
	_apply_control_rect(button_slot, Rect2(0.0, maxf(0.0, size.y - button_height), size.x, button_height))

	if title != null:
		title.add_theme_font_size_override("font_size", _readable_font_size(26 if compact else 34, 0, 42))
	if subtitle != null:
		subtitle.add_theme_font_size_override("font_size", _readable_font_size(11 if compact else 13, 0, 18))
	if body == null:
		return

	var crest_slot := body.get_node_or_null("ResultCrestSlot_%s" % screen_background_id) as Control
	var summary_column := body.get_node_or_null("RunSummaryColumn_%s" % screen_background_id) as VBoxContainer
	var body_gap := 10.0 if compact else 18.0
	var crest_width := clampf(size.x * 0.26, 92.0 if compact else 112.0, 168.0)
	var summary_x := crest_width + body_gap
	var summary_width := maxf(1.0, size.x - summary_x)
	_apply_control_rect(crest_slot, Rect2(0.0, 0.0, crest_width, body_height))
	_apply_control_rect(summary_column, Rect2(summary_x, 0.0, summary_width, body_height))
	if summary_column != null:
		summary_column.add_theme_constant_override("separation", 2 if compact else 4)


func _configure_result_menu_layout(box: VBoxContainer, screen_background_id: String, display_size: Vector2) -> void:
	var content_rect := _pause_end_modal_content_rect(display_size, screen_background_id)
	var content_size := content_rect.size
	var compact := display_size.y < 660.0
	box.name = "ResultContent_%s" % screen_background_id
	box.set_meta("result_no_scroll_layout", true)
	box.set_meta("result_screen_id", screen_background_id)
	box.set_meta("result_content_rect", content_rect)
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.custom_minimum_size = Vector2.ZERO
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8 if compact else 10)

	var title_label := box.find_child("MenuTitle_%s" % screen_background_id, false, false) as Label
	if title_label != null:
		title_label.custom_minimum_size = Vector2(content_size.x, 30.0 if compact else 42.0)
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", _readable_font_size(28 if compact else 36, 0, 48))

	var subtitle_label := box.find_child("MenuSubtitle_%s" % screen_background_id, false, false) as Label
	if subtitle_label != null:
		subtitle_label.custom_minimum_size = Vector2(content_size.x, 112.0 if compact else 128.0)
		subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		subtitle_label.add_theme_font_size_override("font_size", _readable_font_size(13 if compact else 16, 0, 21))

	var body := HBoxContainer.new()
	body.name = "ResultBody_%s" % screen_background_id
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12 if compact else 18)
	box.add_child(body)

	var crest_column := VBoxContainer.new()
	crest_column.name = "ResultCrestColumn_%s" % screen_background_id
	crest_column.alignment = BoxContainer.ALIGNMENT_CENTER
	crest_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var crest_column_width := clampf(content_size.x * 0.28, 112.0, 170.0)
	crest_column.custom_minimum_size = Vector2(crest_column_width, 0.0)
	body.add_child(crest_column)

	var crest_slot := CenterContainer.new()
	crest_slot.name = "ResultCrestSlot_%s" % screen_background_id
	var crest_size := _pause_end_result_crest_size()
	crest_slot.custom_minimum_size = Vector2(crest_column_width, crest_size)
	crest_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crest_column.add_child(crest_slot)

	var summary_column := VBoxContainer.new()
	summary_column.name = "RunSummaryColumn_%s" % screen_background_id
	summary_column.alignment = BoxContainer.ALIGNMENT_CENTER
	summary_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary_column.add_theme_constant_override("separation", 4 if compact else 6)
	body.add_child(summary_column)


func _add_result_crest(box: VBoxContainer, kind: String) -> void:
	var slot := box.find_child("ResultCrestSlot_%s" % kind, true, false) as Control
	if slot != null:
		_add_result_crest_to_slot(slot, kind)
		return
	# Аддитивная геральдическая эмблема-кольцо над заголовком экранов победы/поражения
	# (D&D Dark Fantasy Dragon, fantasydisk-asset-generator). SCRUM-330.
	var crest := _make_result_crest(kind)
	if crest == null:
		return
	box.add_child(crest)
	box.move_child(crest, 0)


func _add_result_crest_to_slot(slot: Control, kind: String) -> void:
	if slot == null or not is_instance_valid(slot):
		return
	var crest := _make_result_crest(kind)
	if crest == null:
		return
	slot.add_child(crest)


func _make_result_crest(kind: String) -> TextureRect:
	# Аддитивная геральдическая эмблема-кольцо над заголовком экранов победы/поражения
	# (D&D Dark Fantasy Dragon, fantasydisk-asset-generator). SCRUM-330.
	var slug := "victory" if kind == "victory" else "defeat"
	var tex: Texture2D = game._cached_texture("res://assets/sprites/ui/result_crests/ui_crest_%s.png" % slug)
	if tex == null:
		return null
	var crest := TextureRect.new()
	crest.name = "ResultCrest"
	crest.texture = tex
	var crest_size := _pause_end_result_crest_size()
	crest.custom_minimum_size = Vector2(crest_size, crest_size)
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return crest


func _pause_end_result_crest_size() -> float:
	var viewport_height: float = float(game.get_viewport().get_visible_rect().size.y)
	if viewport_height < 760.0:
		return clampf(viewport_height * 0.15, 88.0, 112.0)
	return clampf(viewport_height * 0.16, 112.0, 168.0)


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
	# SCRUM-684: кодекс рисуется поверх детального гримуар-разворота — гасим фон
	# сильнее, чтобы орнаментные панели читались как передний план.
	shade.color = Color(0.02, 0.015, 0.03, 0.62) if screen_background_id == "codex" else Color(0.0, 0.0, 0.0, 0.44)
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
	var scale := maxf(0.5, minf(viewport_size.x / 2560.0, viewport_size.y / 1440.0))
	var compact := scale <= 0.52
	var xy := Vector2(scale, scale)
	var panel_size := Vector2(roundf(LU_PANEL_2K.size.x * scale), roundf(LU_PANEL_2K.size.y * scale))
	# Контент-зона = фактические content margins чипа панели (_atlas_chip_style:
	# по горизонтали pad*1.4) — PanelContainer сам ставит бокс ровно в эту зону.
	var panel_pad := roundf(LU_PANEL_CHIP_PAD_2K * scale)
	var content_position := Vector2(panel_pad * 1.4, panel_pad)
	var content_size := panel_size - Vector2(panel_pad * 2.8, panel_pad * 2.0)
	var card_size := _level_up_scaled_size(LU_CARD_2K, xy)
	var card_gap := roundf(LU_CARD_GAP_2K * scale)
	var rewards_row_size := Vector2(card_size.x * 3.0 + card_gap * 2.0, card_size.y)
	var rewards_row_position := Vector2(roundf((content_size.x - rewards_row_size.x) * 0.5), roundf(LU_REWARDS_ROW_TOP_2K * scale))
	# «Позже» — фикс-размер глобального кита (высота от вьюпорта, не от scale):
	# прижата к низу контент-зоны, по центру; между рядом карточек и кнопкой
	# остаётся ≥50px при любом scale (проверено на матрице 648..2160).
	var later_size := Vector2(LU_LATER_BUTTON_WIDTH, _atlas_action_button_height())
	var later_position := Vector2(
		roundf((content_size.x - later_size.x) * 0.5),
		content_size.y - later_size.y - maxf(8.0, roundf(12.0 * scale))
	)
	return {
		"scale": scale,
		"panel_size": panel_size,
		"panel_pad": panel_pad,
		"content_position": content_position,
		"content_size": content_size,
		"hero_header_position": _level_up_scaled_position(LU_HERO_HEADER_RECT, xy),
		"hero_header_size": _level_up_scaled_size(LU_HERO_HEADER_RECT, xy),
		"hero_frame_position": _level_up_scaled_position(LU_HERO_FRAME_RECT, xy),
		"hero_size": _level_up_scaled_size(LU_HERO_FRAME_RECT, xy),
		"title_position": _level_up_scaled_position(LU_TITLE_RECT, xy),
		"title_size": _level_up_scaled_size(LU_TITLE_RECT, xy),
		"subtitle_position": _level_up_scaled_position(LU_SUBTITLE_RECT, xy),
		"subtitle_size": _level_up_scaled_size(LU_SUBTITLE_RECT, xy),
		"rewards_row_position": rewards_row_position,
		"rewards_row_size": rewards_row_size,
		"card_size": card_size,
		"card_gap": card_gap,
		"later_button_position": later_position,
		"later_button_size": later_size,
		"title_font": maxi(16, int(roundf(38.0 * scale))),
		"title_scale": Vector2.ONE,
		"subtitle_font": maxi(12, int(roundf(18.0 * scale))),
		"compact": compact,
	}


func _create_level_up_menu_box(title: String, subtitle: String, layout := {}) -> Control:
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
	_prepare_global_tooltips(root)
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
	var panel_pad: float = layout.get("panel_pad", 14.0)
	var panel_content_position: Vector2 = layout.get("content_position", Vector2(46.0, 55.0))
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
	panel.custom_minimum_size = panel_size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# SCRUM-883: плотная кожа атласа поверх замороженного боя (дим ниже остаётся).
	var panel_style := _atlas_chip_style(0.96, panel_pad)
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.set_meta("level_up_slot", "level_up_panel")
	panel.set_meta("level_up_content_margins", Vector4(
		panel_style.content_margin_left,
		panel_style.content_margin_top,
		panel_style.content_margin_right,
		panel_style.content_margin_bottom
	))
	panel.set_meta("level_up_content_rect", Rect2(panel_content_position, layout.get("content_size", Vector2(768.0, 417.0))))
	root.add_child(panel)

	var box := Control.new()
	box.name = "LevelUpContent"
	box.position = panel_content_position
	box.size = layout.get("content_size", Vector2(768.0, 417.0))
	box.custom_minimum_size = box.size
	panel.add_child(box)

	var hero_header := Control.new()
	hero_header.name = "LevelUpHeroHeader"
	hero_header.position = layout.get("hero_header_position", Vector2.ZERO)
	hero_header.size = layout.get("hero_header_size", Vector2(645.0, 70.0))
	hero_header.custom_minimum_size = hero_header.size
	box.add_child(hero_header)

	var hero_size: Vector2 = layout.get("hero_size", Vector2(92, 92))
	var hero_frame := PanelContainer.new()
	hero_frame.name = "LevelUpHeroFrame"
	hero_frame.position = layout.get("hero_frame_position", Vector2.ZERO)
	hero_frame.custom_minimum_size = hero_size
	hero_frame.size = hero_size
	# SCRUM-883: портрет-слот — полупрозрачный чип атласа (как слоты Атласа героев).
	hero_frame.add_theme_stylebox_override("panel", _atlas_translucent_style(0.55, 10.0))
	box.add_child(hero_frame)

	var hero_portrait := TextureRect.new()
	hero_portrait.name = "LevelUpHeroPortrait"
	hero_portrait.texture = game._cached_texture(str(game.PROGRESSION_DATA.character_config(game.selected_character_id).get("sprite_path", "")))
	hero_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero_frame.add_child(hero_portrait)

	var title_label := Label.new()
	title_label.name = "LevelUpTitle"
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.position = layout.get("title_position", Vector2.ZERO)
	title_label.size = layout.get("title_size", Vector2(440.0, 30.0))
	title_label.scale = layout.get("title_scale", Vector2(1.18, 1.18))
	title_label.modulate.a = 0.0
	title_label.add_theme_font_size_override("font_size", _readable_font_size(int(layout.get("title_font", 50)), 0, 72))
	title_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	box.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.name = "LevelUpSubtitle"
	subtitle_label.text = subtitle
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.position = layout.get("subtitle_position", Vector2.ZERO)
	subtitle_label.size = layout.get("subtitle_size", Vector2(460.0, 22.0))
	subtitle_label.add_theme_font_size_override("font_size", _readable_font_size(int(layout.get("subtitle_font", 17)), 0, 26))
	subtitle_label.add_theme_color_override("font_color", Color(0.78, 0.66, 0.44, 1.0))
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
		# Keep generated frame geometry exact for safe-zone QA; reveal cards with fade only.
		button.scale = Vector2.ONE
		button.pivot_offset = button.size * 0.5
		var button_tween = button.create_tween()
		button_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		button_tween.set_trans(Tween.TRANS_CUBIC)
		button_tween.set_ease(Tween.EASE_OUT)
		button_tween.tween_interval(0.10 + float(index) * 0.07)
		button_tween.tween_property(button, "modulate:a", 1.0, 0.18)


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


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = _action_button_size()
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_button_control(button)
	return button


func _readability_font_scale() -> float:
	var viewport_height := 864.0
	if game != null and game.get_viewport() != null:
		viewport_height = game.get_viewport().get_visible_rect().size.y
	var t := clampf((viewport_height - 648.0) / 216.0, 0.0, 1.0)
	return lerpf(READABILITY_FONT_SCALE_MIN, READABILITY_FONT_SCALE_TARGET, t)


func _readable_font_size(base_size: int, min_size := 0, max_size := 96) -> int:
	var scaled := int(roundf(float(base_size) * _readability_font_scale()))
	if min_size > 0:
		scaled = maxi(scaled, min_size)
	if max_size > 0:
		scaled = mini(scaled, max_size)
	return scaled


func _make_compact_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = COMPACT_UTILITY_BUTTON_SIZE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", _readable_font_size(18))
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
	button.add_theme_font_size_override("font_size", _readable_font_size(16))


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
	# SCRUM-847: legacy-маршрут settings-узлов (v3/v4 tint-стили) удалён — экран
	# настроек v6 стилизует свои контролы явно (_settings_v6_*), сюда не попадает.
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
	var text_button_id := _text_button_unique_id(button)
	if text_button_id != "" and TEXT_BUTTON_UNIQUE_TEXTURES.has(text_button_id):
		var text_textures: Dictionary = TEXT_BUTTON_UNIQUE_TEXTURES[text_button_id]
		var text_path := str(text_textures.get(texture_state, text_textures["normal"]))
		var text_margins: Vector4 = TEXT_BUTTON_UNIQUE_MARGINS.get(text_button_id, TEXT_BUTTON_UNIQUE_MARGINS["standard_420x104"])
		var text_content: Vector4 = TEXT_BUTTON_UNIQUE_CONTENT.get(text_button_id, TEXT_BUTTON_UNIQUE_CONTENT["standard_420x104"])
		var text_tint := tint
		if texture_state == "hover" and tint == Color.WHITE:
			text_tint = BUTTON_HOVER_EXTRA_TINT
		return _global_texture_style(text_path, text_margins, text_tint, text_content)
	var suffix := "" if texture_state == "normal" else "_%s" % texture_state
	var path := "%sui_btn_minimal_metal_%s%s.png" % [MINIMAL_METAL_BUTTON_DIR, button_type, suffix]
	var final_tint := tint
	if texture_state == "hover" and tint == Color.WHITE:
		final_tint = BUTTON_HOVER_EXTRA_TINT
	var margins: Vector4 = MINIMAL_METAL_BUTTON_MARGINS.get(button_type, MINIMAL_METAL_BUTTON_MARGINS["standard"])
	var content: Vector4 = MINIMAL_METAL_BUTTON_CONTENT.get(button_type, MINIMAL_METAL_BUTTON_CONTENT["standard"])
	return _global_texture_style(path, margins, final_tint, content)


func _text_button_unique_id(button: Button) -> String:
	if button == null:
		return ""
	var button_name := button.name
	var text := button.text.to_lower()
	var size := button.custom_minimum_size
	if button_name == "LevelUpPlusButton" or button_name == "UpgradeFabButton":
		return ""
	if button_name in ["AscensionMinusButton", "AscensionPlusButton"] or size.x <= 70.0:
		return ""
	if button_name.begins_with("MainMenu"):
		return "main_menu_380x104"
	if button_name == "HS4ChooseButton":
		# Фидбек 2026-07-08: CTA «Выбрать» — на плите кнопок главного меню.
		return "main_menu_380x104"
	if button_name.begins_with("RunPause"):
		return "pause_280x60"
	if button_name.begins_with("QuitConfirm"):
		return "quit_220x72"
	if button_name == "ContinueRunButton":
		if size.x >= 360.0:
			return "continue_run_long_420x72"
		return "continue_240x72"
	if button_name == "ContinueRunNewGameButton":
		return "continue_240x72"
	if button_name == "LevelUpLaterButton":
		return "later_260x72"
	if button_name == "SettingsBackButton":
		# Фидбек 2026-07-08: единый возврат — та же плита, что у остальных back.
		return "back_260x104"
	if button_name == "SettingsResetBindingsButton":
		if size.x >= 540.0:
			return "reset_bindings_long_560x104"
		return "wide_440x104"
	if button_name == "SettingsResetAudioButton":
		return "standard_420x104"
	if button_name == "FeedbackSendButton":
		return "feedback_260x64"
	if button_name == "FeedbackCancelButton":
		return "feedback_cancel_220x64"
	if button_name == "EventBackButton":
		# Фидбек 2026-07-08: единый возврат — та же плита back_260x104, что у остальных back.
		return "back_260x104"
	if button_name.begins_with("BindingButton_") or button_name == "SettingsAimModeOption":
		return "rebind_420x62"
	if button_name in ["RebindConflictRetryButton", "RebindConflictBackButton"]:
		return ""
	if button_name in ["WeaponSelectBackButton", "StartBoonBackButton"]:
		# SCRUM-883: единый возврат (фидбек 2026-07-08) — нативная плита back_260x104.
		return "back_260x104"
	if button_name in ["SkillTreeBackButton", "PatchNotesBackButton"]:
		return "back_260x104"
	if button_name in ["AttributeRerollButton", "AttributeSkipButton", "VictoryNewRunButton", "DeathRetryButton"]:
		return "standard_420x104"
	if size.y <= 56.0 and size.x >= 340.0:
		return "event_back_380x54"
	if size.y <= 66.0 and size.x >= 360.0:
		return "rebind_420x62"
	if size.y <= 66.0 and size.x >= 240.0:
		return "settings_back_280x64"
	if size.y <= 76.0 and size.x <= 230.0:
		return "quit_220x72"
	if size.y <= 76.0 and size.x <= 250.0:
		return "continue_240x72"
	if size.y <= 76.0 and size.x <= 300.0:
		return "later_260x72"
	if size.y >= 96.0 and size.x >= 430.0:
		return "wide_440x104"
	if size.y >= 96.0 and size.x >= 400.0:
		return "standard_420x104"
	if size.y >= 96.0 and size.x >= 240.0:
		return "back_260x104"
	return ""


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


func _panel_style() -> StyleBox:
	return _minimal_frame_style("panel")


func _level_up_panel_style() -> StyleBox:
	return _minimal_frame_style("panel", Color(1.06, 1.03, 1.08, 1.0))


func _card_hover_style() -> StyleBox:
	return _minimal_frame_style("card", BUTTON_NEUTRAL_HOVER_TINT)


func _character_card_style() -> StyleBox:
	return _minimal_frame_style("card")


func _is_economy_screen_background(screen_background_id: String) -> bool:
	return ["campfire", "upgrade", "event"].has(screen_background_id)


func _is_pause_end_screen_background(screen_background_id: String) -> bool:
	return ["pause", "victory", "death"].has(screen_background_id)


func _is_result_screen_background(screen_background_id: String) -> bool:
	return ["victory", "death"].has(screen_background_id)


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


func _pause_end_modal_content_margins(display_size: Vector2, screen_background_id: String) -> Vector4:
	# SCRUM-883: у результ-чипа контент держат симметричные чип-пэддинги.
	if _is_result_screen_background(screen_background_id):
		return _atlas_chip_content_margins(RESULT_MODAL_CHIP_PAD)
	return _scaled_frame_margins(PAUSE_END_MODAL_SOURCE_SIZE, display_size, PAUSE_END_MODAL_CONTENT)


func _pause_end_modal_content_rect(display_size: Vector2, screen_background_id: String) -> Rect2:
	var margins := _pause_end_modal_content_margins(display_size, screen_background_id)
	return Rect2(
		Vector2(margins.x, margins.y),
		Vector2(maxf(1.0, display_size.x - margins.x - margins.z), maxf(1.0, display_size.y - margins.y - margins.w))
	)


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


func _level_up_xy_scale(source_size: Vector2, display_size: Vector2) -> Vector2:
	return Vector2(
		display_size.x / maxf(source_size.x, 1.0),
		display_size.y / maxf(source_size.y, 1.0)
	)


func _level_up_scaled_position(rect: Rect2, scale: Vector2) -> Vector2:
	return Vector2(roundf(rect.position.x * scale.x), roundf(rect.position.y * scale.y))


func _level_up_scaled_size(rect: Rect2, scale: Vector2) -> Vector2:
	return Vector2(roundf(rect.size.x * scale.x), roundf(rect.size.y * scale.y))


func _level_up_place_card_child(control: Control, rect: Rect2, scale: Vector2) -> void:
	control.position = _level_up_scaled_position(rect, scale)
	control.size = _level_up_scaled_size(rect, scale)
	control.custom_minimum_size = control.size


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


# SCRUM-684: Фикс-margins styling для Dark Fantasy pixel-art кодекса. Без
# масштабирования по display_size — texture_margins берутся РОВНО в пикселях
# источника, иначе 9-slice пересекает орнамент малых текстур.
# Pixel-art иконки/портреты кодекса масштабируются вьюпортом — рендерим nearest,
# чтобы не было блюра (дефолт проекта = linear).
func _codex_pl_make_nearest(node: CanvasItem) -> void:
	if node != null:
		node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _overhaul_2k_content_margins(slot: String, display_size: Vector2) -> Vector4:
	if not OVERHAUL_2K_FRAME_SOURCE_SIZE.has(slot):
		return Vector4.ZERO
	var source_size: Vector2 = OVERHAUL_2K_FRAME_SOURCE_SIZE[slot]
	var base_content: Vector4 = OVERHAUL_2K_FRAME_CONTENT.get(slot, Vector4.ZERO)
	return _scaled_frame_margins_xy(source_size, display_size, base_content)


func _apply_overhaul_2k_button_theme(button: Button, slot: String, display_size: Vector2) -> void:
	if slot in ["cr_btn", "pm_btn", "ws_btn_back"] and _text_button_unique_id(button) != "":
		_apply_fantasy_button_theme(button)
		return
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


# SCRUM-883: панели экономических экранов маршрута (костёр и фолбэк) — чип Атласа.
func _economy_panel_style() -> StyleBox:
	return _atlas_chip_style(0.94, 18.0)


# SCRUM-883: Событие в едином атлас-стиле. Панель — atlas-чип (MenuPanel_event),
# контент раскладывается от ФАКТИЧЕСКИХ content-margins чипа (не от source-зон
# @2K-рамки); титул золотом 30/36, стори — читаемое тело 16+ с autowrap.
func _configure_event_menu_layout(box: VBoxContainer) -> void:
	if box == null:
		return
	var display_size := _economy_menu_panel_half_size("event") * 2.0
	var margins := Vector4(25.0, 18.0, 25.0, 18.0)
	var scroll := box.get_parent() as ScrollContainer
	var panel: PanelContainer = null
	if scroll != null:
		panel = scroll.get_parent() as PanelContainer
	if panel != null:
		var panel_style := panel.get_theme_stylebox("panel")
		if panel_style != null:
			margins = Vector4(
				panel_style.get_content_margin(SIDE_LEFT),
				panel_style.get_content_margin(SIDE_TOP),
				panel_style.get_content_margin(SIDE_RIGHT),
				panel_style.get_content_margin(SIDE_BOTTOM)
			)
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
	if scroll != null:
		scroll.follow_focus = false
		scroll.scroll_vertical = 0
		scroll.custom_minimum_size = content_size
	var title_label := box.find_child("MenuTitle_event", false, false) as Label
	if title_label != null:
		title_label.name = "EventTitle"
		title_label.custom_minimum_size = Vector2(content_size.x, 38.0 if compact else 52.0)
		title_label.add_theme_font_size_override("font_size", _readable_font_size(30 if compact else 36, 0, 48))
		title_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	var story_label := box.find_child("MenuSubtitle_event", false, false) as Label
	if story_label != null:
		story_label.name = "EventStory"
		story_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		story_label.custom_minimum_size = Vector2(content_size.x, 58.0 if compact else 92.0)
		story_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		story_label.add_theme_font_size_override("font_size", _readable_font_size(16 if compact else 18, 12, 24))
		story_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))


# SCRUM-565/568 → SCRUM-883: чип-карточка держит контент собственными симметричными
# пэддингами — переинсет под content-зону текстурной рамки больше не нужен. Хелпер
# сохранён идемпотентной переустановкой чип-маржин (его зовёт экран события).
func _reinset_overhaul_choice_content(button: Button, _slot: String, _display_size: Vector2) -> void:
	if button == null:
		return
	var content := button.find_child("%sContent" % button.name, true, false) as Control
	if content == null:
		return
	var margins: Vector4 = button.get_meta("economy_content_margins", Vector4.ZERO)
	if margins == Vector4.ZERO:
		return
	content.offset_left = margins.x
	content.offset_top = margins.y
	content.offset_right = -margins.z
	content.offset_bottom = -margins.w


# SCRUM-565/568 → SCRUM-883: карточки выбора больше не переодеваются в текстурные
# @2K-рамки — единый чип-язык Атласа. Сигнатура и точки вызова сохранены (экран
# события зовёт хелпер со слотом; слот игнорируется).
func _apply_overhaul_choice_2k_theme(button: Button, _slot: String, display_size: Vector2) -> void:
	if button == null:
		return
	_apply_atlas_choice_card_theme(button, _atlas_card_pad(display_size))


# SCRUM-883: карточка награды = кожаный чип-ряд атласа (база — _unified_apply_
# row_theme) с поднятой плотностью поверх замороженного боя: normal 0.88,
# hover/focus — золотой кант ярче, pressed — толстый золотой борт (селект).
func _apply_level_up_card_atlas_theme(button: Button, display_size: Vector2, is_rare := false) -> void:
	var pad := maxf(6.0, roundf(LU_CARD_CHIP_PAD_2K * display_size.y / LU_CARD_2K.size.y))
	_unified_apply_row_theme(button, pad)
	var normal := _atlas_chip_style(0.88, pad)
	if is_rare:
		normal.border_color = Color(0.80, 0.62, 0.30, 0.95)
	var hover := _atlas_chip_style(0.92, pad)
	hover.border_color = Color(0.93, 0.77, 0.40, 0.95)
	var focus := _atlas_chip_style(0.90, pad)
	focus.border_color = Color(0.93, 0.77, 0.40, 0.95)
	var pressed := _atlas_chip_style(0.96, pad)
	pressed.border_color = Color(0.98, 0.84, 0.46, 1.0)
	pressed.set_border_width_all(3)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("pressed", pressed)
	var content_margins := Vector4(
		normal.content_margin_left,
		normal.content_margin_top,
		normal.content_margin_right,
		normal.content_margin_bottom
	)
	button.set_meta("level_up_card_slot", "level_up_card")
	button.set_meta("level_up_card_content_margins", content_margins)
	button.set_meta("level_up_card_content_rect", Rect2(
		content_margins.x,
		content_margins.y,
		display_size.x - content_margins.x - content_margins.z,
		display_size.y - content_margins.y - content_margins.w
	))


func _pause_end_modal_style(display_size: Vector2, screen_background_id := "") -> StyleBox:
	# SCRUM-883: итоги забега (Победа/Поражение) — модалка-чип Атласа 0.96 вместо
	# текстурных рам (result_panel @2K у смерти, minimal-modal у победы). Пауза —
	# чужая зона: остаётся на общем PAUSE_END_MODAL_PATH.
	if _is_result_screen_background(screen_background_id):
		return _atlas_chip_style(0.96, RESULT_MODAL_CHIP_PAD)
	var texture_margins := _scaled_frame_margins(PAUSE_END_MODAL_SOURCE_SIZE, display_size, PAUSE_END_MODAL_TEXTURE_MARGINS)
	var content_margins := _scaled_frame_margins(PAUSE_END_MODAL_SOURCE_SIZE, display_size, PAUSE_END_MODAL_CONTENT)
	return _global_texture_style(PAUSE_END_MODAL_PATH, texture_margins, Color.WHITE, content_margins, true)


# SCRUM-883: чип-пэддинг карточек наград/экономики от высоты слота (симметрия с
# _atlas_chip_style: по X пад расширяется 1.4x внутри самого стиля).
func _atlas_card_pad(display_size: Vector2) -> float:
	return roundf(clampf(display_size.y * 0.10, 18.0, 34.0))


func _atlas_chip_content_margins(pad: float) -> Vector4:
	return Vector4(pad * 1.4, pad, pad * 1.4, pad)


# SCRUM-883: контентные карточки-ряды (награда за бой, артефакты элитки/босса,
# экономика маршрута, докачка, события) — единый чип-язык Атласа поверх
# _unified_apply_row_theme: normal — плотный чип 0.86, hover/focus/pressed —
# золотой кант; disabled сохраняет силуэт чипа (дим — модуляцией карточки).
# Никаких текстурных рамок и растяжек (Правило 1/2 SCRUM-879).
func _apply_atlas_choice_card_theme(button: Button, pad: float) -> void:
	_unified_apply_row_theme(button, pad)
	button.add_theme_stylebox_override("normal", _atlas_chip_style(0.86, pad))
	var hover := _atlas_chip_style(0.90, pad)
	hover.border_color = Color(0.93, 0.77, 0.40, 0.95)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := _atlas_chip_style(0.94, pad)
	pressed.bg_color = Color(0.11, 0.09, 0.07, 0.94)
	pressed.border_color = Color(0.93, 0.77, 0.40, 0.95)
	button.add_theme_stylebox_override("pressed", pressed)
	var focus := _atlas_chip_style(0.90, pad)
	focus.border_color = Color(0.93, 0.77, 0.40, 0.95)
	button.add_theme_stylebox_override("focus", focus)
	var disabled := _atlas_chip_style(0.80, pad)
	disabled.border_color = Color(0.36, 0.32, 0.26, 0.70)
	button.add_theme_stylebox_override("disabled", disabled)
	button.set_meta("economy_card_style", "atlas_chip")
	button.set_meta("economy_card_pad", pad)


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
	button.set_meta("economy_display_size", display_size)
	button.text = ""
	button.custom_minimum_size = display_size
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = "%s\n%s" % [title, description]
	# SCRUM-883: карточка выбора — чип-ряд Атласа (StyleBoxFlat), контент держат
	# симметричные чип-пэддинги вместо content-зоны текстурной рамки.
	var card_pad := _atlas_card_pad(display_size)
	_apply_atlas_choice_card_theme(button, card_pad)

	var margins := _atlas_chip_content_margins(card_pad)
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
	title_label.add_theme_font_size_override("font_size", _readable_font_size(14 if compact_attribute else 17, 12, 24))
	title_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title_label)

	var desc_label := Label.new()
	desc_label.name = "%sDescription" % button.name
	desc_label.text = description
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_label.add_theme_font_size_override("font_size", _readable_font_size(11 if compact_attribute else 13, 12, 20))
	desc_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(desc_label)

	var action_label := Label.new()
	action_label.name = "%sAction" % button.name
	action_label.text = action_text
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_label.add_theme_font_size_override("font_size", _readable_font_size(12 if compact_attribute else 15, 12, 22))
	action_label.add_theme_color_override("font_color", Color(0.94, 0.80, 0.46, 1.0))
	action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(action_label)

	# SCRUM-808: длинное описание продавливало VBox за safe-зону фрейма (флаки матрицы
	# на 1536×864 в зависимости от выпавших наград). Доводка после ready — по реальным
	# minimum size (шрифтовые метрики без line_spacing врут на ~1 строку).
	desc_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.ready.connect(_fit_economy_choice_card_content.bind(button), CONNECT_ONE_SHOT)
	return button


func _fit_economy_choice_card_content(button: Button) -> void:
	# SCRUM-808: ужимаем шрифт описания (до 9), затем режем строки многоточием,
	# пока контент не влезет в safe-зону карточки; полный текст остаётся в tooltip.
	if button == null or not is_instance_valid(button):
		return
	var content := button.find_child("%sContent" % button.name, false, false) as BoxContainer
	var desc_label := button.find_child("%sDescription" % button.name, true, false) as Label
	if content == null or desc_label == null:
		return
	var margins: Vector4 = button.get_meta("economy_content_margins", Vector4.ZERO)
	var avail_h: float = button.custom_minimum_size.y - margins.y - margins.w
	if avail_h <= 0.0:
		return
	var font_size := desc_label.get_theme_font_size("font_size")
	while font_size > 12 and content.get_combined_minimum_size().y > avail_h:
		font_size -= 1
		desc_label.add_theme_font_size_override("font_size", font_size)
	var guard := desc_label.get_line_count()
	while guard > 1 and content.get_combined_minimum_size().y > avail_h:
		guard -= 1
		desc_label.max_lines_visible = guard


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


# SCRUM-883: чип-пэддинг карточки награды (обычной/элитной) от её display-размера.
func _reward_card_pad(elite := false) -> float:
	return _atlas_card_pad(REWARD_ELITE_CARD_SIZE if elite else REWARD_CARD_SIZE)


# SCRUM-883: карточки наград — чип-ряды Атласа (общий язык с карточками экономики);
# текстурные reward-рамки SCRUM-338/448 сняты.
func _apply_reward_card_theme(button: Button, elite := false) -> void:
	_apply_atlas_choice_card_theme(button, _reward_card_pad(elite))


func _add_reward_card_content_container(button: Button, elite := false) -> VBoxContainer:
	var margins := _atlas_chip_content_margins(_reward_card_pad(elite))
	var content := VBoxContainer.new()
	content.clip_contents = true
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = margins.x
	content.offset_top = margins.y
	content.offset_right = -margins.z
	content.offset_bottom = -margins.w
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	button.add_child(content)
	return content


func _progression_node_style(status: String, focused := false) -> StyleBox:
	var texture_id := "focus" if focused else status
	if not PROGRESSION_NODE_TEXTURES.has(texture_id):
		texture_id = "locked"
	var tint := Color.WHITE
	if status == "locked":
		tint = Color(0.70, 0.72, 0.78, 0.82)
	return _global_texture_style(str(PROGRESSION_NODE_TEXTURES[texture_id]), Vector4.ZERO, tint, Vector4(18.0, 18.0, 18.0, 18.0))


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


func _prepare_global_tooltips(root: Control) -> void:
	if root == null:
		return
	if _global_tooltip_theme == null:
		_global_tooltip_theme = GlobalTooltip.make_theme()
	root.theme = _global_tooltip_theme
	if not bool(root.get_meta("global_tooltip_child_hook", false)):
		root.set_meta("global_tooltip_child_hook", true)
		root.child_entered_tree.connect(func(_child: Node) -> void:
			_schedule_global_tooltip_install(root)
		)
	_schedule_global_tooltip_install(root)


func _schedule_global_tooltip_install(root: Control) -> void:
	if root == null or not is_instance_valid(root):
		return
	if bool(root.get_meta("global_tooltip_install_pending", false)):
		return
	root.set_meta("global_tooltip_install_pending", true)
	call_deferred("_install_global_tooltips_for_root", root)


func _install_global_tooltips_for_root(root: Control) -> void:
	if root == null or not is_instance_valid(root):
		return
	root.set_meta("global_tooltip_install_pending", false)
	GlobalTooltip.install_on_tree(root, GlobalTooltipControl)


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
	_prepare_global_tooltips(root)

	_create_resource_hud_panel(root, Vector2(20, 18))
	_create_combat_timer_panel(root)
	_create_boss_health_panel(root)
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


func _create_combat_timer_panel(root: Control) -> void:
	# SCRUM-806 (reopen): уровень возвышения — ряд пиксель-эмблем по числу уровня,
	# без плашки-рамки и цифры: считывается как «звёзды сложности», тултип сохранён.
	if game.selected_ascension_level > 0:
		var asc_row := HBoxContainer.new()
		asc_row.name = "AscensionHudRow"
		asc_row.set_anchors_preset(Control.PRESET_TOP_LEFT)
		asc_row.mouse_filter = Control.MOUSE_FILTER_STOP
		asc_row.tooltip_text = "Возвышение %d\n%s" % [game.selected_ascension_level, "\n".join(game.PROGRESSION_DATA.ascension_modifier_lines(game.selected_ascension_level))]
		root.add_child(asc_row)
		var pip_count := clampi(game.selected_ascension_level, 0, game.META_PROGRESSION.MAX_ASCENSION_LEVEL)  # SCRUM-622: клампить по динамическому капу (5), не хардкод 10
		for pip_index in range(pip_count):
			var pip := _make_hud_v2_icon("ascension")
			pip.name = "AscensionHudPip%d" % pip_index
			pip.custom_minimum_size = Vector2(44, 44)
			asc_row.add_child(pip)

	# SCRUM-799: таймер показываем во всех боях, включая боссовый/элитный
	# (5-минутный kill-timer из SCRUM-785). Ранний выход по boss_combat_active снят —
	# панель и timer_label создаются одинаково для обычного, элитного и боссового боя,
	# иначе игрок не видит обратный отсчёт и внезапно проигрывает на 5:00.
	var panel := PanelContainer.new()
	panel.name = "CombatTimerPanel"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(0, 14)
	panel.custom_minimum_size = Vector2(192, 64)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _timer_panel_style(false, HUD_V2_TIMER_2K.size, _scrum666_content_margins(HUD_V2_TIMER_2K, HUD_V2_TIMER_ZONE_2K, 1.0)))
	root.add_child(panel)

	var label := Label.new()
	label.name = "CombatTimerLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", _readable_font_size(26))
	label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.74, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.03, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	panel.add_child(label)
	game.timer_label = label

	# SCRUM-806: пиксель-песочные часы на левом краю плашки таймера.
	var timer_icon := _make_hud_v2_icon("timer")
	timer_icon.name = "CombatTimerIcon"
	timer_icon.set_anchors_preset(Control.PRESET_TOP_LEFT)
	timer_icon.custom_minimum_size = Vector2(28, 28)
	root.add_child(timer_icon)


func _create_boss_health_panel(root: Control) -> void:
	# SCRUM-874: общий HUD-боссбар цели узла (акт-босс/элитка) — крупная полоса HP
	# с именем цели по центру верха экрана. Создаётся скрытым; видимость и значения
	# ведёт _update_boss_hud_bar() по game.boss_hud_target (ставит combat_director
	# в _spawn_boss/_spawn_elite_enemy, снимает _end_combat). Плавающая полоса над
	# спрайтом у таких целей не создаётся (enemy._uses_hud_boss_bar).
	var name_label := Label.new()
	name_label.name = "BossHudNameLabel"
	name_label.visible = false
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", _readable_font_size(24))
	name_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.34, 1.0))
	name_label.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.03, 1.0))
	name_label.add_theme_constant_override("outline_size", 4)
	root.add_child(name_label)

	var track := PanelContainer.new()
	track.name = "BossHudTrack"
	track.visible = false
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_theme_stylebox_override("panel", _hud_v2_bar_track_style())
	root.add_child(track)

	var bar := ProgressBar.new()
	bar.name = "BossHudBar"
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("background", _bar_style(Color(0.05, 0.06, 0.08, 0.85)))
	bar.add_theme_stylebox_override("fill", _hud_v2_bar_fill_style("hp", Color(0.86, 0.20, 0.16, 0.95)))
	track.add_child(bar)

	game.boss_hud_name_label = name_label
	game.boss_hud_bar = bar


func _update_boss_hud_bar() -> void:
	var bar := game.boss_hud_bar as ProgressBar
	var name_label := game.boss_hud_name_label as Label
	if bar == null or not is_instance_valid(bar) or name_label == null or not is_instance_valid(name_label):
		return
	var track := bar.get_parent() as Control
	# ВАЖНО: не кастовать boss_hud_target до is_instance_valid — после free цели
	# `as Node2D` на freed-объекте даёт script error «Trying to cast a freed object».
	if game.boss_hud_target == null or not is_instance_valid(game.boss_hud_target):
		game.boss_hud_target = null
		if track != null:
			track.visible = false
		name_label.visible = false
		return
	var target: Node2D = game.boss_hud_target
	if not target.is_inside_tree():
		if track != null:
			track.visible = false
		name_label.visible = false
		return
	var max_hp := maxf(_number_value(target.get("max_health"), 1.0), 1.0)
	# Смерть цели: hp клампится в 0 — полоса доводится в ноль на время
	# death-анимации (SCRUM-865, ~2s), затем узел освобождается и панель гаснет.
	var hp := clampf(_number_value(target.get("health"), 0.0), 0.0, max_hp)
	bar.max_value = max_hp
	bar.value = hp
	var display_name = target.get("boss_display_name")
	var target_name := str(display_name) if display_name != null else ""
	if target_name == "":
		target_name = str(target.get("enemy_type_name"))
	name_label.text = target_name
	if track != null:
		track.visible = true
	name_label.visible = true


func _timer_panel_style(alarm: bool, display_size := Vector2(264.0, 92.0), content_margins := Vector4.ZERO) -> StyleBox:
	# SCRUM-806 (reopen): жёлтая рамка chud_timer убрана — таймер на той же кожаной
	# подложке, что левый кластер (единый стиль); alarm подкрашивает кожу в алый.
	var tint := Color(1.45, 0.58, 0.50, 0.96) if alarm else Color(1.0, 1.0, 1.0, 0.93)
	var texture_margins := _scaled_frame_margins_xy(Vector2(768.0, 256.0), display_size, Vector4(26, 22, 26, 22))
	var style := _global_texture_style(HUD_V2_CLUSTER_BG_PATH, texture_margins, tint, Vector4.ZERO, true)
	if content_margins != Vector4.ZERO:
		_apply_stylebox_content_margins(style, content_margins)
	return style


func _scrum666_hud_scale_for_size(viewport_size: Vector2) -> float:
	var scale_x := viewport_size.x / COMBAT_BLOCK_DESIGN_BASE_2K.x
	var scale_y := viewport_size.y / COMBAT_BLOCK_DESIGN_BASE_2K.y
	var scale := minf(scale_x, scale_y)
	if scale <= 0.0:
		return 0.5
	return scale


func _scrum666_hud_scale(root: Control) -> float:
	var viewport_size := root.get_viewport_rect().size
	if root.size.x > 0.0 and root.size.y > 0.0:
		viewport_size = root.size
	return _scrum666_hud_scale_for_size(viewport_size)


func _scrum666_scaled_rect(base_rect: Rect2, scale: float) -> Rect2:
	return Rect2(
		Vector2(roundf(base_rect.position.x * scale), roundf(base_rect.position.y * scale)),
		Vector2(roundf(base_rect.size.x * scale), roundf(base_rect.size.y * scale))
	)


func _scrum666_content_margins(frame_rect: Rect2, zone_rect: Rect2, scale: float) -> Vector4:
	return Vector4(
		roundf((zone_rect.position.x - frame_rect.position.x) * scale),
		roundf((zone_rect.position.y - frame_rect.position.y) * scale),
		roundf((frame_rect.position.x + frame_rect.size.x - zone_rect.position.x - zone_rect.size.x) * scale),
		roundf((frame_rect.position.y + frame_rect.size.y - zone_rect.position.y - zone_rect.size.y) * scale)
	)


func _apply_stylebox_content_margins(style: StyleBox, margins: Vector4) -> void:
	if style == null:
		return
	style.content_margin_left = margins.x
	style.content_margin_top = margins.y
	style.content_margin_right = margins.z
	style.content_margin_bottom = margins.w


func _apply_chud_rect(control: Control, rect: Rect2, meta_key := "") -> void:
	if control == null:
		return
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position
	control.custom_minimum_size = rect.size
	control.size = rect.size
	if meta_key != "":
		control.set_meta(meta_key, rect)


# SCRUM-876: разложить боевой ресурс-кластер на меню-экране с кастомной точкой
# привязки (карта держит его ПОД своим заголовком). Размер/содержимое — тот же
# скейл и лейаут, что в бою.
func _layout_menu_resource_hud(root: Control, origin: Vector2) -> void:
	if root == null or not is_instance_valid(root):
		return
	var resource := root.find_child("RunResourceHud", true, false) as PanelContainer
	if resource == null:
		return
	var scale := _scrum666_hud_scale(root)
	# Внутренние зоны кластера (_hud_v2_place_in_panel) заданы в абсолютных
	# боевых 2K-координатах и вычитают позицию панели — раскладываем содержимое
	# относительно БОЕВОГО ректа, а саму панель ставим на кастомный origin.
	var combat_rect := _scrum666_scaled_rect(HUD_V2_CLUSTER_2K, scale)
	_apply_chud_rect(resource, Rect2(origin, combat_rect.size), "scrum666_frame_rect")
	resource.add_theme_stylebox_override("panel", _hud_v2_cluster_style(combat_rect.size))
	_layout_hud_v2_cluster(resource, combat_rect, scale)


func _layout_combat_hud(root: Control) -> void:
	if root == null or not is_instance_valid(root):
		return
	var scale := _scrum666_hud_scale(root)
	var resource := root.find_child("RunResourceHud", true, false) as PanelContainer
	if resource != null:
		var resource_rect := _scrum666_scaled_rect(HUD_V2_CLUSTER_2K, scale)
		_apply_chud_rect(resource, resource_rect, "scrum666_frame_rect")
		resource.add_theme_stylebox_override("panel", _hud_v2_cluster_style(resource_rect.size))
		_layout_hud_v2_cluster(resource, resource_rect, scale)

	var timer_panel := root.find_child("CombatTimerPanel", true, false) as PanelContainer
	if timer_panel != null:
		var timer_rect := _scrum666_scaled_rect(HUD_V2_TIMER_2K, scale)
		var timer_content := _scrum666_content_margins(HUD_V2_TIMER_2K, HUD_V2_TIMER_ZONE_2K, scale)
		_apply_chud_rect(timer_panel, timer_rect, "scrum666_frame_rect")
		timer_panel.set_meta("scrum666_content_margins", timer_content)
		timer_panel.set_meta("scrum666_content_zone", _scrum666_scaled_rect(HUD_V2_TIMER_ZONE_2K, scale))
		timer_panel.add_theme_stylebox_override("panel", _timer_panel_style(bool(game.timer_label != null and game.timer_label.get_meta("alarm_active", false)), timer_rect.size, timer_content))
		if game.timer_label != null:
			game.timer_label.add_theme_font_size_override("font_size", maxi(16, int(roundf(34.0 * scale))))
		var timer_icon := root.find_child("CombatTimerIcon", true, false) as TextureRect
		if timer_icon != null:
			_apply_chud_rect(timer_icon, _scrum666_scaled_rect(HUD_V2_TIMER_ICON_2K, scale))

	# SCRUM-874: HUD-боссбар — центр верха, ниже кластера/таймера.
	var boss_track := root.find_child("BossHudTrack", true, false) as PanelContainer
	if boss_track != null:
		var boss_rect := _scrum666_scaled_rect(HUD_V2_BOSS_BAR_2K, scale)
		_apply_chud_rect(boss_track, boss_rect, "scrum666_frame_rect")
		var boss_inset := maxf(2.0, roundf(4.0 * scale))
		boss_track.add_theme_stylebox_override("panel", _hud_v2_bar_track_style(boss_rect.size, boss_inset))
		var boss_bar := boss_track.find_child("BossHudBar", true, false) as ProgressBar
		if boss_bar != null:
			boss_bar.custom_minimum_size = Vector2(0.0, maxf(4.0, boss_rect.size.y - boss_inset * 2.0))
		var boss_name := root.find_child("BossHudNameLabel", true, false) as Label
		if boss_name != null:
			_apply_chud_rect(boss_name, _scrum666_scaled_rect(HUD_V2_BOSS_NAME_2K, scale))
			boss_name.add_theme_font_size_override("font_size", maxi(16, int(roundf(32.0 * scale))))

	var asc_row := root.find_child("AscensionHudRow", true, false) as HBoxContainer
	if asc_row != null:
		var pip_size := maxf(18.0, roundf(HUD_V2_ASCENSION_PIP_2K * scale))
		var pip_gap := maxf(2.0, roundf(HUD_V2_ASCENSION_GAP_2K * scale))
		asc_row.add_theme_constant_override("separation", int(pip_gap))
		var pip_count := asc_row.get_child_count()
		for pip in asc_row.get_children():
			var pip_icon := pip as TextureRect
			if pip_icon != null:
				pip_icon.custom_minimum_size = Vector2(pip_size, pip_size)
		var row_size := Vector2(pip_count * pip_size + maxf(0.0, pip_count - 1.0) * pip_gap, pip_size)
		var row_rect := Rect2(Vector2(roundf(HUD_V2_ASCENSION_RIGHT_2K * scale) - row_size.x, roundf(HUD_V2_ASCENSION_TOP_2K * scale)), row_size)
		_apply_chud_rect(asc_row, row_rect, "scrum666_frame_rect")
		asc_row.set_meta("scrum666_content_zone", row_rect)


func _layout_hud_v2_cluster(resource: PanelContainer, panel_rect: Rect2, scale: float) -> void:
	# SCRUM-806: раскладка слим-кластера — все дети RunResourceHudContent позиционируются
	# по @2K-зонам, переведённым в координаты панели (content = full-rect без margins).
	var icon_zones := {
		"UIIcon_hp": HUD_V2_HP_ICON_2K,
		"UIIcon_xp": HUD_V2_XP_ICON_2K,
		"UIIcon_ultimate_multiplier": HUD_V2_ULT_ICON_2K,
		"UIIcon_money": HUD_V2_MONEY_ICON_2K,
	}
	for icon_name in icon_zones.keys():
		var icon := resource.find_child(str(icon_name), true, false) as TextureRect
		if icon != null:
			_hud_v2_place_in_panel(icon, icon_zones[icon_name], panel_rect, scale)
	var track_zones := {
		"HudHPTrack": HUD_V2_HP_BAR_2K,
		"HudXPTrack": HUD_V2_XP_BAR_2K,
		"HudULTTrack": HUD_V2_ULT_BAR_2K,
	}
	for track_name in track_zones.keys():
		var track := resource.find_child(str(track_name), true, false) as PanelContainer
		if track == null:
			continue
		var zone: Rect2 = track_zones[track_name]
		_hud_v2_place_in_panel(track, zone, panel_rect, scale)
		var track_size := _scrum666_scaled_rect(zone, scale).size
		var inset := maxf(2.0, roundf(4.0 * scale))
		track.add_theme_stylebox_override("panel", _hud_v2_bar_track_style(track_size, inset))
		var bar := track.find_child(track_name.replace("Track", "Bar"), true, false) as ProgressBar
		if bar != null:
			bar.custom_minimum_size = Vector2(0.0, maxf(4.0, track_size.y - inset * 2.0))
	var money_label := resource.find_child("HudMoneyLabel", true, false) as Label
	if money_label != null:
		_hud_v2_place_in_panel(money_label, HUD_V2_MONEY_LABEL_2K, panel_rect, scale)
		money_label.add_theme_font_size_override("font_size", maxi(14, int(roundf(24.0 * scale))))
	var bar_labels := {
		"HudHPLabel": [HUD_V2_HP_BAR_2K, 20.0],
		"HudXPLabel": [HUD_V2_XP_BAR_2K, 17.0],
		"HudULTLabel": [HUD_V2_ULT_BAR_2K, 17.0],
	}
	for label_name in bar_labels.keys():
		var label := resource.find_child(str(label_name), true, false) as Label
		if label == null:
			continue
		label.add_theme_font_size_override("font_size", maxi(12, int(roundf(float(bar_labels[label_name][1]) * scale))))
		label.add_theme_constant_override("outline_size", maxi(2, int(roundf(3.0 * scale))))
		_hud_v2_place_in_panel(label, bar_labels[label_name][0], panel_rect, scale)
		# Шрифт может требовать больше высоты, чем слим-бар: расширяем рект лейбла
		# симметрично вокруг зоны бара, текст остаётся визуально по центру бара.
		var min_h := label.get_combined_minimum_size().y
		if min_h > label.size.y:
			label.position.y -= roundf((min_h - label.size.y) * 0.5)
			label.size.y = min_h
			label.custom_minimum_size.y = 0.0


func _hud_v2_place_in_panel(node: Control, zone_2k: Rect2, panel_rect: Rect2, scale: float) -> void:
	var zone := _scrum666_scaled_rect(zone_2k, scale)
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.position = zone.position - panel_rect.position
	node.custom_minimum_size = zone.size
	node.size = zone.size
	node.set_meta("scrum666_content_zone", zone)


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
	root.name = "MenuRunHudRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.hud_layer.add_child(root)
	_prepare_global_tooltips(root)
	# SCRUM-876: меню-экраны забега (карта/level-up/награды/магазины/события)
	# показывают ТОТ ЖЕ боевой ресурс-кластер SCRUM-806 (HP/XP/ULT + золото),
	# что и бой — один вид HUD во всех местах. Боевые-only элементы (таймер,
	# боссбар, ascension-пипсы) здесь не создаются; _layout_combat_hud null-safe.
	_create_resource_hud_panel(root, Vector2(20, 18))
	root.resized.connect(func() -> void:
		_layout_combat_hud(root)
	)
	_layout_combat_hud(root)
	call_deferred("_layout_combat_hud", root)
	_update_hud()
	_update_level_up_button()


func _create_resource_hud_panel(parent: Control, position: Vector2) -> void:
	# SCRUM-806 боевой HUD v2 (слим-бары с пиксель-иконками); с SCRUM-876 —
	# единственный вид ресурс-панели: и бой, и все меню-экраны забега.
	game._last_hud_snapshot.clear()
	var panel := PanelContainer.new()
	panel.name = "RunResourceHud"
	panel.position = position
	panel.custom_minimum_size = HUD_V2_CLUSTER_2K.size
	panel.add_theme_stylebox_override("panel", _hud_v2_cluster_style(HUD_V2_CLUSTER_2K.size))
	parent.add_child(panel)

	var content := Control.new()
	content.name = "RunResourceHudContent"
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)
	_build_hud_v2_cluster(content)


func _build_hud_v2_cluster(content: Control) -> void:
	game.health_bar = _add_hud_v2_bar(content, "hp", "HP", Color(0.92, 0.08, 0.08, 1.0))
	game.xp_bar = _add_hud_v2_bar(content, "xp", "XP", Color(0.25, 0.78, 1.0, 1.0))
	game.ultimate_bar = _add_hud_v2_bar(content, "ultimate_multiplier", "ULT", Color(0.95, 0.68, 1.0, 1.0))

	var money_icon := _make_hud_v2_icon("money")
	money_icon.name = "UIIcon_money"
	content.add_child(money_icon)

	game.money_label = Label.new()
	game.money_label.name = "HudMoneyLabel"
	game.money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	game.money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game.money_label.add_theme_font_size_override("font_size", _readable_font_size(18))
	game.money_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.34, 1.0))
	game.money_label.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.03, 1.0))
	game.money_label.add_theme_constant_override("outline_size", 3)
	game.money_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(game.money_label)


func _make_hud_v2_icon(icon_id: String) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = game._cached_texture(str(HUD_V2_ICON_PATHS.get(icon_id, HUD_V2_ICON_PATHS["hp"])))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Пиксель-арт PixelLab: nearest сохраняет хрусткие пиксели при даунскейле.
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _add_hud_v2_bar(parent: Control, icon_id: String, tag: String, fill_fallback: Color) -> ProgressBar:
	var icon := _make_hud_v2_icon(icon_id)
	icon.name = "UIIcon_%s" % icon_id
	parent.add_child(icon)

	var track := PanelContainer.new()
	track.name = "Hud%sTrack" % tag
	track.mouse_filter = Control.MOUSE_FILTER_PASS
	track.add_theme_stylebox_override("panel", _hud_v2_bar_track_style())
	parent.add_child(track)

	var bar := ProgressBar.new()
	bar.name = "Hud%sBar" % tag
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	# PanelContainer не гарантирует растяжку Range-ребёнка — фиксируем флагами,
	# высоту дожимает _layout_hud_v2_cluster через custom_minimum_size.
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("background", _bar_style(Color(0.05, 0.06, 0.08, 0.85)))
	bar.add_theme_stylebox_override("fill", _hud_v2_bar_fill_style(icon_id, fill_fallback))
	track.add_child(bar)

	# Лейбл — сиблинг трека (не ребёнок бара): min-height шрифта на 4K выше слим-бара,
	# внутри бара он вылезал бы за родителя (text-overflow инвариант матрицы).
	# Позиционируется _layout_hud_v2_cluster по зоне бара с вертикальным центрированием.
	var label := Label.new()
	label.name = "Hud%sLabel" % tag
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.add_theme_font_size_override("font_size", _readable_font_size(13))
	label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.86, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.03, 1.0))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)

	if icon_id == "hp":
		game.health_label = label
	elif icon_id == "xp":
		game.xp_label = label
	elif icon_id == "ultimate_multiplier":
		game.ultimate_label = label
	return bar


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
	value.add_theme_font_size_override("font_size", _readable_font_size(15))
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


func _hud_v2_cluster_style(display_size := Vector2(640.0, 122.0)) -> StyleBox:
	# SCRUM-806: лёгкая кожаная подложка с тонкой латунной линией (768×256, OpenAI),
	# полупрозрачная, чтобы кластер не выглядел тяжёлой плитой поверх арены.
	var texture_margins := _scaled_frame_margins_xy(Vector2(768.0, 256.0), display_size, Vector4(26, 22, 26, 22))
	return _global_texture_style(HUD_V2_CLUSTER_BG_PATH, texture_margins, Color(1.0, 1.0, 1.0, 0.93), Vector4.ZERO, true)


func _hud_v2_bar_track_style(display_size := Vector2(516.0, 32.0), content_inset := 3.0) -> StyleBox:
	# SCRUM-806: слим-жёлоб с тонкой латунной окантовкой (512×32) под лайн-бар.
	var texture_margins := _scaled_frame_margins_xy(Vector2(512.0, 32.0), display_size, Vector4(10, 5, 10, 5))
	var inset := maxf(2.0, content_inset)
	return _global_texture_style(HUD_V2_BAR_TRACK_PATH, texture_margins, Color.WHITE, Vector4(inset, inset, inset, inset), true)


func _hud_v2_bar_fill_style(icon_id: String, fallback_color: Color) -> StyleBox:
	# SCRUM-806: филл слим-бара — прежние gradient-текстуры, но с полной вертикальной
	# растяжкой (margins только по X), иначе на треке высотой 10-20px поля съедают центр.
	var path := str(COMBAT_HUD_BAR_FILL_PATHS.get(icon_id, ""))
	if path != "" and ResourceLoader.exists(path):
		return _global_texture_style(path, Vector4(6, 0, 6, 0), Color.WHITE, Vector4.ZERO)
	return _bar_style(fallback_color)


func _character_stats_hud_style() -> StyleBox:
	return _global_texture_style(MINIMAL_FIELD_PATH, Vector4(10, 10, 10, 10), Color(1.0, 1.0, 1.0, 0.95), Vector4(16, 12, 16, 12), true)


func _hud_card_style(icon_id := "hp", display_size := Vector2.ZERO) -> StyleBox:
	var path := str(COMBAT_HUD_CARD_PATHS.get(icon_id, COMBAT_HUD_CARD_PATHS["hp"]))
	var resolved_size := display_size
	if resolved_size == Vector2.ZERO:
		resolved_size = Vector2(104.0, 48.0) if icon_id == "money" else Vector2(132.0, 48.0)
	var texture_margins := _scaled_frame_margins_xy(Vector2(616.0, 286.0), resolved_size, COMBAT_HUD_CARD_MARGINS)
	var content_margins := _scaled_frame_margins_xy(Vector2(616.0, 286.0), resolved_size, COMBAT_HUD_CARD_CONTENT)
	return _global_texture_style(path, texture_margins, Color.WHITE, content_margins, true)


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

	# SCRUM-874: боссбар обновляется ДО дедуп-гарда _last_hud_snapshot ниже —
	# HP цели меняется независимо от ресурсов игрока.
	_update_boss_hud_bar()

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
	# SCRUM-785: таймер показываем во всех боях, включая боссовый (5-минутный kill-timer).
	if game.combat_active:
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
		var content_margins: Vector4 = panel.get_meta("scrum666_content_margins", _scrum666_content_margins(HUD_V2_TIMER_2K, HUD_V2_TIMER_ZONE_2K, _scrum666_hud_scale_for_size(panel.get_viewport_rect().size))) as Vector4
		panel.add_theme_stylebox_override("panel", _timer_panel_style(alarm, panel.size, content_margins))
	if alarm:
		var tween: Tween = game.timer_label.create_tween()
		tween.set_loops(timer_seconds)
		tween.tween_property(game.timer_label, "scale", Vector2(1.12, 1.12), 0.16).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(game.timer_label, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_QUAD)
		game.timer_label.pivot_offset = game.timer_label.size * 0.5
