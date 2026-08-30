extends RefCounted

# FAN-3824: модуль распределённого UI-класса — разделяемое состояние, preload-константы и координатные спеки всего UI-класса.
# Часть линейной extends-цепочки scripts/ui/screens/** (сборка — фасад
# scripts/ui_screens.gd). Код перенесён из ui_screens.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в ui_screens_shared_api.gd.


# Меню, настройки, выбор персонажа/оружия, магазин, события, отдых,
# level-up, победа/смерть, HUD и общие UI-стили.

const AimController := preload("res://scripts/input/aim_controller.gd")
const UltimateHudRuntimeAdapter := preload("res://scripts/ui/ultimate_hud/ultimate_hud_runtime_adapter.gd")

var game
var settings_return_origin := "main_menu"
var settings_video_pending := {}
var _settings_v6_icon_cache := {}
var _global_tooltip_theme: Theme = null
# SCRUM-816: живая строка статуса геймпада на вкладке «Управление» + флаг режима
# прослушивания ребинда (клавиатура vs геймпад — один диспетчер _handle_rebind_input).
var _gamepad_status_label: Label = null
var _aim_mode_hint_label: Label = null  # FAN-1449: подсказка прицеливания, живёт на hot-plug сигналах
var _rebind_is_gamepad := false
# SCRUM-827: view-state экрана «Атлас героев» (ссылки на узлы + вкладка/класс/выбор).
# Все таймеры/твины экрана — property-твины на самих нодах либо колбэки строго через
# Callable(self, "метод").bind(...) — против use-after-free семьи SCRUM-551.
var _atlas := {}
# Скрытые звезды, чью церемонию рассеивания тумана уже показали в этой сессии.
var _atlas_hidden_seen := {}
var _feedback_request_id := 0
var codex_unlock_presenter
var _update_presenter

const HeroStatRadar := preload("res://scripts/ui/hero_stat_radar.gd")
const SemanticTypography := preload("res://scripts/ui/semantic_typography.gd")
const UIThemePaths := preload("res://scripts/ui/ui_theme_paths.gd")
const UIButtonFamily := preload("res://scripts/ui/ui_button_family.gd")
const ConstellationDescriptionFormatter := preload("res://scripts/constellation_description_formatter.gd")
# SCRUM-871: прогноз level-up наград (дельты derived-статов + бейджи DPS/выживаемость).
const LevelUpAdvisor := preload("res://scripts/level_up_advisor.gd")
const ArtifactRewardPresenter := preload("res://scripts/artifact_reward_presenter.gd")
const ShopUIConstants := preload("res://scripts/ui/shop_ui_constants.gd")
const HeroSelectConstants := preload("res://scripts/ui/hero_select_constants.gd")
const FEEDBACK_REPORTER_SCRIPT := preload("res://scripts/feedback_reporter.gd")
const FeedbackOverlayController := preload("res://scripts/ui/feedback_overlay.gd")
const DisplayResolution := preload("res://scripts/display_resolution.gd")
const StatFormulas := preload("res://scripts/stat_formulas.gd")
const GlobalTooltip := preload("res://scripts/ui/global_tooltip.gd")
const GlobalTooltipControl := preload("res://scripts/ui/global_tooltip_control.gd")
# SCRUM-810/816: реестр глифов кнопок геймпада (null-safe; нет ассета → текст).
const InputGlyphRegistry := preload("res://scripts/ui/input_glyph_registry.gd")
const CodexImageFit := preload("res://scripts/ui/codex_image_fit.gd")
const CodexUnlockPresenter := preload("res://scripts/codex_unlock_presenter.gd")
# FAN-1087: лор-модуль FAN-1080 подключается явным preload, как остальные
# вынесенные UI-модули: глобальное имя класса из global_script_class_cache
# не гарантировано в холодном/устаревшем чекауте и роняло компиляцию main.gd.
const LoreScreens := preload("res://scripts/ui/lore_screens.gd")
const UpdatePresenter := preload("res://scripts/ui/update_presenter.gd")
const BATTLE_PRAYER_ICON_IDS := {
	"prayer_wrath": "damage",
	"prayer_mending": "regeneration",
	"prayer_aegis": "defense",
}
const BATTLE_PRAYER_EFFECT_SUMMARIES := {
	"prayer_wrath": "+20% ко всему урону",
	"prayer_mending": "+2 HP/с",
	"prayer_aegis": "−20% вход. урона",
}

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
const GRATITUDE_ICON_PATH := "res://assets/sprites/ui/icons/credits/ui_icon_gratitude.png"
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
const END_RUN_CONFIRM_BUTTON_SIZE := Vector2(240.0, 72.0)
const END_RUN_CONFIRM_BUTTON_FAMILY := "text/continue_240x72"
const MAIN_MENU_BUTTON_COUNT := 6.0
const GOLD_SHELL_SCREEN_IDS := ["campfire", "upgrade", "artifact_reward", "victory", "death"]
const COMPACT_UTILITY_BUTTON_SIZE := Vector2(54.0, 42.0)
const ASCENSION_BUTTON_SIZE := Vector2(54.0, 62.0)
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
	SETTINGS_V6_DIR + "ui_settings_v6_icon_game.png",
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
# Значения вычислены из фактической раскладки билдеров при базе 2560×1440
# (window/stretch=canvas_items, aspect=keep → рантайм всегда лэйаутит в этой базе,
# окно скейлится автоматически). Панели с рамкой держат пустую safe-area под контент.
# Шаблонные размеры контейнер-зависимых слотов (карточки/кнопки/ряды) заданы как
# Rect2(0, 0, w, h) — позиция считается контейнером в рантайме (центрирование).
# Координатные спеки экранов, ушедших на атлас-стиль (SCRUM-879..888), сняты.
const COMBAT_BLOCK_DESIGN_BASE_2K := Vector2(2560.0, 1440.0)

# #5 Бой / HUD — SCRUM-671 runtime placement uses the SCRUM666_* geometry below
# because SCRUM-666 is a full-screen mockup/source package.

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

# #14 Улучшение — _show_upgrade_screen (economy-панель "upgrade"; target 1720×730, центр)

# #11 Повышение уровня — _show_level_up_screen / _level_up_layout_metrics
# SCRUM-892 → SCRUM-985: титул/divider и локальные сокеты Атласа сохранены,
# но самая большая внешняя frame_border-рама и видимый борт общей панели сняты.
# Arcane-lab фон открыт светлее; только карточки остаются плотными локальными
# поверхностями. Иконки наград живут в строгом inner-safe rect сокета; иконки/
# портрета класса на экране НЕТ. «Позже» — глобальный кит (LevelUpLaterButton →
# later_260x72).
# Дизайн-база 2K 1720×1040; контент-зона панели = фактические margins чипа
# (pad 20 → 28/20 @2K); карточки — контентной высоты (стек сокет→титул→
# описание→дельты без пустых зон), ряд центрируется в зоне между шапкой и «Позже».
const LU_PANEL_2K := Rect2(420, 205, 1720, 1040)
const LU_PANEL_CHIP_PAD_2K := 20.0
const LU_PANEL_BACKGROUND_ALPHA := 0.20
const LU_BACKGROUND_SHADE_ALPHA := 0.12
const LU_DIM_ALPHA := 0.24
const LU_BACKGROUND_BRIGHTEN := Color(1.15, 1.12, 1.18, 1.0)
const LU_CARD_2K := Rect2(0, 0, 470, 560)                   # ширина карточки @2K (высота — от контента)
const LU_CARD_GAP_2K := 24.0
const LU_CARD_CHIP_PAD_2K := 12.0
# Шапка без иконки/портрета класса (директива пользователя 2026-07-08):
# симметричный золотой титул на всю ширину, под ним церемониальная линия
# divider_ornament (800×56, ширина ~46% панели, высота 24-28, KEEP_ASPECT_
# CENTERED + NEAREST), под орнаментом сабтитул.
const LU_HERO_HEADER_RECT := Rect2(40.0, 8.0, 1584.0, 160.0)
const LU_TITLE_RECT := Rect2(40.0, 16.0, 1584.0, 64.0)
const LU_DIVIDER_TOP_2K := 86.0
const LU_DIVIDER_HEIGHT_2K := 28.0
const LU_DIVIDER_PANEL_WIDTH_RATIO := 0.46
const LU_SUBTITLE_RECT := Rect2(40.0, 120.0, 1584.0, 46.0)
const LU_REWARDS_ROW_TOP_2K := 180.0
const LU_LATER_BUTTON_WIDTH := 260.0
# Стек карточки (2K-номиналы, скейл ×scale): сокет 128 (socket_notable/keystone
# натив 128/168 в квадратном боксе, KEEP_ASPECT_CENTERED), иконка награды 72 по
# центру сокета, звезда советника 32 в правом-верхнем углу сокета, межблочный
# зазор 16 (внутренние паддинги 14-18 на целевых вьюпортах).
const LU_CARD_SOCKET_BOX_2K := 128.0
const LU_CARD_SOCKET_ICON_RATIO := 0.5625
const LU_CARD_STAR_2K := 32.0
const LU_CARD_STACK_GAP_2K := 16.0
const LU_CARD_BADGE_WIDTH_2K := 320.0
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

# #29 Баннер заголовка боя — _show_combat_title_banner (center-top; ширина была 1280 = 720p-баг → 2K)
const CTB_BIG_2K := Rect2(100, 120, 2360, 90)              # появление босса (big)
const CTB_SMALL_2K := Rect2(100, 92, 2360, 56)             # появление элитки

# #30 Баннер победы — _show_victory_banner: дим + компактный чип Атласа с золотым
# титулом «ПОБЕДА», центрированный по обеим осям любого viewport (SCRUM-986;
# ранее абсолютный 2K top=608 обрезал нижние 112px на 1280x720).
const VICTORY_BANNER_CHIP_SIZE := Vector2(960.0, 224.0)
const VICTORY_BANNER_CHIP_PAD := 26.0
# === конец спеки SCRUM-487 ===

# === SCRUM-488: координатная спека @2560×1440 — блок Прогрессия/Экономика ===
# Те же правила и стиль, что у блока Меню (SCRUM-484) и Боевые (SCRUM-487): значения
# вычислены из фактической раскладки билдеров при базе 2560×1440 и сверены с рантайм-дампом
# верификатора (build/qa/ui_no_overlap_matrix.md, секции *_2560×1440). Контейнер-зависимые
# слоты-шаблоны заданы как Rect2(0, 0, w, h). Кодекс с SCRUM-879 — контейнерный
# атлас-шелл (см. #15 ниже), собственного координатного движка больше не имеет.

# #8 Магазин — _show_shop_screen (backdrop-лавка; контент в центральной зоне «стены»)

# #9 Докача — _show_attribute_shop (панель full-height; скролл опций + фикс-низ)

# #10 Дерево навыков (легаси-спека v3; экран заменён Атласом героев — _show_atlas_screen, SCRUM-827)

# #15 Кодекс — _show_codex_screen / _show_codex_section: SCRUM-879, контейнерный
# шелл в атлас-стиле (фон COVERED → safe-зона рамы → «табы | объект-сцена | досье»
# → полая рама поверх); панели — _atlas_chip_style, ряды — _unified_apply_row_theme.

# #16 Настройки — _show_settings_menu (SCRUM-879: фулскрин атлас-шелл, строки v6)
# === конец спеки SCRUM-488 ===

# #17 Что нового / патч-ноуты — _show_patch_notes_screen (SCRUM-576). Полноэкранная панель
# (как skill-tree main), хедер «Что нового» + «Назад в меню» сверху, скролл версий/буллетов
# внутри safe-area. Текст длинных версий уходит в вертикальный скролл (рамка не растягивается).

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
	"weapon_boon": "УСИЛЕНИЕ ОРУЖИЯ", "weapon_final": "ФИНАЛ ОРУЖИЯ",
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
const CODEX_RUNTIME_DIR := ATLAS_STYLE_DIR + "codex/"
const CODEX_SANCTUM_BG_PATH := CODEX_RUNTIME_DIR + "bg_codex_sanctum.png"
const CODEX_PANEL_FRAME_PATH := CODEX_RUNTIME_DIR + "panel_9slice.png"
const CODEX_ENTRY_CARD_PATH := CODEX_RUNTIME_DIR + "entry_card_516x154.png"
const CODEX_CHIP_FRAME_PATH := CODEX_RUNTIME_DIR + "chip_bar.png"
const CODEX_DOSSIER_FRAME_PATH := CODEX_RUNTIME_DIR + "dossier_frame.png"
const CODEX_CREST_PATH := CODEX_RUNTIME_DIR + "codex_crest.png"
const CODEX_PANEL_TEXTURE_MARGINS := Vector4(46.0, 46.0, 46.0, 46.0)
const CODEX_CHIP_TEXTURE_MARGINS := Vector4(40.0, 20.0, 40.0, 20.0)
const CODEX_DOSSIER_TEXTURE_MARGINS := Vector4(96.0, 96.0, 96.0, 96.0)
const ATLAS_STYLE_BG_PATHS := {
	"hero_select": ATLAS_STYLE_DIR + "bg_hero_hall.png",
	"codex": CODEX_SANCTUM_BG_PATH,
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
# SCRUM-954: center rows keep the calm atlas card palette; generic codex_pl
# category emblems are no longer part of live navigation.
const CODEX_PL_CARD_BODY_COLOR := Color(0.76, 0.70, 0.57, 1.0)
# SCRUM-883: карточки наград — чип-ряды Атласа; display-размеры слотов сохранены.
const REWARD_CARD_SIZE := Vector2(300.0, 430.0)
const REWARD_ELITE_CARD_SIZE := Vector2(320.0, 430.0)


func _init(game_ref) -> void:
	game = game_ref
	codex_unlock_presenter = CodexUnlockPresenter.new(game_ref)


# SCRUM-484/SCRUM-842: координатная спека @2560×1440 — продолжить забег (модалка).
# Панель расширена до 840×380, чтобы long-кнопка «Продолжить» 420×72 и «Новая игра»
# 240×72 с gap 18 оставались внутри safe-area и не клепали текст по орнаменту.
const CR_PANEL_2K := Rect2(860, 530, 840, 380)
const CR_BTN_CONTINUE_2K := Rect2(942, 758, 420, 72)
const CR_BTN_NEWGAME_2K := Rect2(1380, 758, 240, 72)

# SCRUM-584: координатная спека @2560x1440 — конфликт переназначения клавиши.
# Mockup/art source: docs/design/references/scrum584_rebind_conflict_2k/.
const RC_PANEL_2K := Rect2(940, 530, 680, 380)
const RC_SAFE_2K := Rect2(998, 602, 564, 242)
const RC_TITLE_2K := Rect2(998, 614, 564, 44)
const RC_MESSAGE_2K := Rect2(998, 674, 564, 66)
const RC_BTN_RETRY_2K := Rect2(1031, 758, 240, 72)
const RC_BTN_BACK_2K := Rect2(1289, 758, 240, 72)


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
# Карусель SCRUM-561: thumbnails stay square inside the safe band of the carousel strip.
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


const CODEX_DATA := preload("res://scripts/codex_data.gd")
const LORE_DATA := preload("res://scripts/lore_data.gd")
const CODEX_SECTIONS := [
	{"id": "characters", "title": "Персонажи"},
	{"id": "monsters", "title": "Монстры"},
	{"id": "artifacts", "title": "Артефакты"},
	{"id": "characteristics", "title": "Параметры"},
	{"id": "attributes", "title": "Атрибуты"},
	{"id": "ascension", "title": "Возвыш."},
	{"id": "chronicle", "title": "Летопись"},
]


const ATTRIBUTE_BUY_BASE_COST := 18
const ATTRIBUTE_BUY_STAGE_COST := 6
const ATTRIBUTE_REROLL_BASE_COST := 6
const ATTRIBUTE_REROLL_STAGE_COST := 2
const ATTRIBUTE_REROLLS_PER_WINDOW := 2


# SCRUM-963: тёмный силуэт иконки запертой записи + дим всего чип-ряда — тот же
# приём, что «скрытая звезда» Атласа и locked-узлы прогрессии (тинты кита).
const CODEX_LOCKED_SILHOUETTE_TINT := Color(0.09, 0.11, 0.17, 0.96)
const CODEX_LOCKED_ROW_TINT := Color(0.70, 0.72, 0.78, 0.82)


# SCRUM-489: координатная спека @2560×1440 — блок «Результаты» (Победа / Поражение).
# Геометрия победы и поражения использует pause/end-модалку, но с SCRUM-841 result
# screens больше не кладутся в ScrollContainer: title/subtitle занимают верх safe-зоны,
# body делит середину на crest-slot и компактную run-summary column, а action button
# всегда остаётся в нижнем safe-слоте. Pause screen сохраняет scroll-контракт отдельно.
# SCRUM-883: модалка итогов — чип Атласа с симметричным чип-пэддингом.
const RESULT_MODAL_CHIP_PAD := 24.0
const VS_BTN_NEWRUN_2K := Rect2(1070, 948, 420, 104)     # x = 898 + (764-420)/2; нижний слот safe


# SCRUM-996: дефолт «загадочного» описания hidden-выбора без unknown_hint.
const EVENT_HIDDEN_CHOICE_FALLBACK_HINT := "Исход неизвестен…"


# SCRUM-634: золотая компенсация (база, масштабируется по этапу маршрута), если
# событие обещало random_artifact, но пул артефактов пуст — чтобы заплаченная
# цена события не превращалась в молчаливую потерю награды.
const EMPTY_ARTIFACT_POOL_FALLBACK_MONEY := 40


# SCRUM-996: верхняя граница событийной скидки — цены не бывают ниже 10% базы.
const EVENT_SHOP_DISCOUNT_MAX := 0.9


const MAIN_STAT_SLOT_CHANCE := 0.05


# SCRUM-963: канон редкости (artifact_system_matrix §1.1) — tier и есть редкость,
# без номеров: 1 обычный / 2 редкий / 3 эпический. Цвета тиров сохранены.
const TIER_LABELS := {1: "Обычный", 2: "Редкий", 3: "Эпический"}
const TIER_COLORS := {
	1: Color(0.80, 0.86, 0.94, 1.0),
	2: Color(0.46, 0.78, 1.0, 1.0),
	3: Color(1.0, 0.74, 0.30, 1.0),
}
# SCRUM-963: 17/17 — дословно titles ProgressionData.CHARACTER_CONFIGS.
const CLASS_RU := {
	"berserk": "Берсерк",
	"soldier": "Солдат",
	"thief": "Вор",
	"elementalist": "Элементалист",
	"sniper": "Снайпер",
	"priest": "Священник",
	"biologist": "Биолог",
	"robot": "Робот",
	"engineer": "Инженер",
	"dark_mage": "Темный маг",
	"guitarist": "Гитарист",
	"assassin": "Ассасин",
	"ranger": "Рейнджер",
	"doctor": "Доктор",
	"chemist": "Химик",
	"knight": "Рыцарь",
	"druid": "Друид",
}


const LOW_HP_VIGNETTE_ON_RATIO := 0.30
const LOW_HP_VIGNETTE_OFF_RATIO := 0.34
const LOW_HP_VIGNETTE_ALPHA := 0.26
const LOW_HP_VIGNETTE_FADE_IN := 0.42
const LOW_HP_VIGNETTE_FADE_OUT := 0.50


const ThreatIndicatorOverlay := preload("res://scripts/threat_indicators.gd")
