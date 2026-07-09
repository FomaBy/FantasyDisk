extends Node2D

@export var player_scene: PackedScene
@export var enemy_scene: PackedScene
@export var shooter_enemy_scene: PackedScene
@export var bruiser_enemy_scene: PackedScene
@export var runner_enemy_scene: PackedScene
@export var boss_scene: PackedScene
@export var disk_devourer_boss_scene: PackedScene
@export var summoner_enemy_scene: PackedScene
@export var mage_enemy_scene: PackedScene
@export var spitter_enemy_scene: PackedScene
@export var shield_enemy_scene: PackedScene
@export var biter_enemy_scene: PackedScene
@export var bone_shaman_enemy_scene: PackedScene
@export var flying_enemy_scene: PackedScene
@export var elite_armored_scene: PackedScene
@export var elite_stalker_scene: PackedScene
@export var elite_poisoned_scene: PackedScene
@export var elite_commander_scene: PackedScene
@export var pickup_scene: PackedScene

const BASE_ROUND_DURATION := 60.0
const ROUND_DURATION_STEP := 3.0
const ROUND_DURATION_MAX := 90.0
# SCRUM-785: элитка и босс — таймер «убей или проиграл» на 5 минут.
const ELITE_BOSS_ROUND_DURATION := 300.0
const ROUTE_STEPS_TO_BOSS := 8
# SCRUM-787: сундуки оформлены целыми «линиями» (ряд, где КАЖДАЯ ветка = chest), чтобы
# игрок не мог их пропустить (любой путь проходит через ряд). 1 линия в середине акта;
# можно поднять до 2 (ранняя + поздняя).
const CHEST_LINE_ROWS := 1
const ACT_COUNT := 3
# SCRUM-873: отхил при переходе в следующий акт — 70% max HP (запрошенный
# диапазон 60–80%). Лечение (clamp по max), не установка HP в фикс. значение.
const ACT_TRANSITION_HEAL_PERCENT := 0.7
const ACT_SCALING_STAGE_OFFSET := 4
const MIN_BRANCHES_PER_STEP := 2
const MAX_BRANCHES_PER_STEP := 4
const MAP_NODE_SIZE := Vector2(88, 88)
const ROUTE_MAP_PADDING := Vector2(170, 72)
# SCRUM-489: 140 (было 118) — хедер карты маршрута (title 36px + stage 18px в PanelContainer)
# имеет content-min ≈110px; при band 88 (118-12-18) PanelContainer рос вниз до y≈128 и
# наезжал на скролл (top=118). 140 даёт band 18..128 ровно под контент + зазор 12 до скролла.
const ROUTE_MAP_HEADER_HEIGHT := 140.0
const ROUTE_MAP_SCREEN_MARGIN := 28.0
const ROUTE_MAP_DRAG_THRESHOLD := 8.0
const ARENA_SIZE := Vector2(4096, 2304)  # SCRUM-518: ×1.6 от 2560×1440 → площадь ≈ ×2.56, 16:9 сохранён
const ARENA_CENTER := ARENA_SIZE * 0.5
const COMBAT_CAMERA_ZOOM := Vector2(1.12, 1.12)
const COLLISION_LAYER_PLAYER := 1
const COLLISION_LAYER_GROUND_ENEMY := 2
const COLLISION_LAYER_FLYING_ENEMY := 4
const COLLISION_LAYER_SOLID := 32
const ARENA_BACKGROUND_OPTIONS := {
	"default": [
		"res://assets/backgrounds/field_marsh.png",
		"res://assets/backgrounds/field_dry_road.png",
		"res://assets/backgrounds/field_stone_garden.png",
		"res://assets/backgrounds/field_meadow.png",
		"res://assets/backgrounds/field_ruined_courtyard.png",
		"res://assets/backgrounds/field_misty_marsh.png",
		"res://assets/backgrounds/field_dusty_badlands.png",
		"res://assets/backgrounds/field_enchanted_meadow.png",
		"res://assets/backgrounds/field_ashen_rift.png",
		"res://assets/backgrounds/field_cursed_grove.png",
	],
	"battle": [
		"res://assets/backgrounds/field_marsh.png",
		"res://assets/backgrounds/field_dry_road.png",
		"res://assets/backgrounds/field_meadow.png",
		"res://assets/backgrounds/field_ruined_courtyard.png",
		"res://assets/backgrounds/field_misty_marsh.png",
		"res://assets/backgrounds/field_dusty_badlands.png",
		"res://assets/backgrounds/field_enchanted_meadow.png",
		"res://assets/backgrounds/field_ashen_rift.png",
		"res://assets/backgrounds/field_cursed_grove.png",
	],
	"boss": [
		"res://assets/backgrounds/field_stone_garden.png",
		"res://assets/backgrounds/field_dry_road.png",
		"res://assets/backgrounds/field_ruined_courtyard.png",
		"res://assets/backgrounds/field_ashen_rift.png",
		"res://assets/backgrounds/field_cursed_grove.png",
	],
}
const MAIN_MENU_BACKGROUND := "res://assets/backgrounds/main_menu_epic_battle_v3.png"
const SCREEN_BACKGROUND_PATHS := {
	"system": "res://assets/backgrounds/ui/ui_backdrop_system_cathedral.png",
	"settings": "res://assets/backgrounds/ui/ui_backdrop_settings.png",
	"codex": "res://assets/sprites/ui/frames/codex_pl/codex_pl_backdrop.png",
	"hero_select": "res://assets/backgrounds/ui/ui_backdrop_system_cathedral.png",
	"weapon_select": "res://assets/backgrounds/ui/ui_backdrop_system_cathedral.png",
	"pause_stats": "res://assets/backgrounds/ui/ui_backdrop_system_cathedral.png",
	"meta_tree": "res://assets/backgrounds/ui/ui_backdrop_system_cathedral.png",
	"skill_tree": "res://assets/backgrounds/ui/ui_backdrop_skill_tree.png",
	"campfire": "res://assets/backgrounds/ui/ui_backdrop_rest_campfire.png",
	"shop": "res://assets/backgrounds/ui/ui_backdrop_merchant_archive.png",
	"event": "res://assets/backgrounds/ui/ui_backdrop_arcane_lab.png",
	"upgrade": "res://assets/backgrounds/ui/ui_backdrop_arcane_lab.png",
	"level_up": "res://assets/backgrounds/ui/ui_backdrop_arcane_lab.png",
	"meta_progression": "res://assets/backgrounds/ui/ui_backdrop_arcane_lab.png",
	"elite_reward": "res://assets/backgrounds/ui/ui_backdrop_reward_hall.png",
	"victory": "res://assets/backgrounds/ui/ui_backdrop_victory.png",
	"artifact_reward": "res://assets/backgrounds/ui/ui_backdrop_reward_hall.png",
	"death": "res://assets/backgrounds/ui/ui_backdrop_defeat_crypt.png",
	"defeat": "res://assets/backgrounds/ui/ui_backdrop_defeat_crypt.png",
	"end_run_confirm": "res://assets/backgrounds/ui/ui_backdrop_defeat_crypt.png",
}
# SCRUM-997: фоны-иллюстрации событий (пак SCRUM-998). Маппинг — файловая
# конвенция манифеста docs/design/references/events_backgrounds_pack/manifest.json:
# event_bg_<event.id>.png. Незамапленные id падают на общий фон "event"
# (ui_backdrop_arcane_lab) — пул артов сойдётся с пулом событий после SCRUM-995.
const EVENT_BACKGROUND_DIR := "res://assets/backgrounds/events"
const GAME_CURSOR_PATH := "res://assets/sprites/ui/cursor/game_cursor.png"
# SCRUM-592: hotspot сидит на самом верхнем-левом ВИДИМОМ пикселе острия
# (включая сглаживание апекса в (1,1)). Прежний (2,2) указывал на первый
# полностью-непрозрачный пиксель, на 1px НИЖЕ воспринимаемого кончика —
# поэтому OS-клик на Windows регистрировался чуть ниже видимого острия.
const GAME_CURSOR_HOTSPOT := Vector2(1, 1)
const SCREEN_BACKGROUND_FALLBACK_COLORS := {
	"system": Color(0.045, 0.052, 0.070, 1.0),
	"settings": Color(0.050, 0.044, 0.038, 1.0),
	"codex": Color(0.045, 0.052, 0.070, 1.0),
	"hero_select": Color(0.045, 0.052, 0.070, 1.0),
	"weapon_select": Color(0.045, 0.052, 0.070, 1.0),
	"pause_stats": Color(0.045, 0.052, 0.070, 1.0),
	"meta_tree": Color(0.045, 0.052, 0.070, 1.0),
	"skill_tree": Color(0.030, 0.034, 0.062, 1.0),
	"event": Color(0.055, 0.045, 0.105, 1.0),
	"shop": Color(0.070, 0.052, 0.030, 1.0),
	"campfire": Color(0.080, 0.045, 0.025, 1.0),
	"upgrade": Color(0.055, 0.045, 0.105, 1.0),
	"level_up": Color(0.055, 0.045, 0.105, 1.0),
	"meta_progression": Color(0.055, 0.045, 0.105, 1.0),
	"elite_reward": Color(0.080, 0.060, 0.035, 1.0),
	"victory": Color(0.080, 0.060, 0.035, 1.0),
	"artifact_reward": Color(0.080, 0.060, 0.035, 1.0),
	"death": Color(0.060, 0.035, 0.045, 1.0),
	"defeat": Color(0.060, 0.035, 0.045, 1.0),
	"end_run_confirm": Color(0.060, 0.035, 0.045, 1.0),
}
const MAP_NODE_DEFINITIONS := {
	"battle": {
		"name": "Обычный бой",
		"icon": "BT",
		"icon_path": "res://assets/sprites/map_icons/map_battle_skull.png",
		"tooltip": "Обычный бой\nСражение с волной врагов. Награда: опыт, деньги и шанс артефакта.",
		"color": Color(0.45, 0.12, 0.13, 0.96),
		"border": Color(0.92, 0.24, 0.20, 1.0),
	},
	"elite_battle": {
		"name": "Элитный бой",
		"icon": "EL",
		"icon_path": "res://assets/sprites/map_icons/map_elite_skull_bones.png",
		"tooltip": "Элитный бой\nБолее сложный бой с усиленным врагом. Награда лучше, чем за обычный бой.",
		"color": Color(0.42, 0.18, 0.08, 0.98),
		"border": Color(1.0, 0.76, 0.18, 1.0),
	},
	"shop": {
		"name": "Магазин",
		"icon": "$",
		"icon_path": "res://assets/sprites/map_icons/map_shop_tent.png",
		"tooltip": "Магазин\nПотрать деньги на артефакты, лечение или улучшения.",
		"color": Color(0.12, 0.30, 0.20, 0.96),
		"border": Color(0.42, 0.86, 0.48, 1.0),
	},
	"event": {
		"name": "Событие",
		"icon": "?",
		"icon_path": "res://assets/sprites/map_icons/map_event_question.png",
		"tooltip": "Событие\nСлучайный выбор с риском и наградой.",
		"color": Color(0.18, 0.18, 0.38, 0.96),
		"border": Color(0.58, 0.54, 1.0, 1.0),
	},
	# SCRUM-608: «Опасная развилка» — узел риск/безопасность. Переиспользует
	# event-иконку (без нового арта), но отдельный цвет/рамка под опасный тон.
	"hazard": {
		"name": "Опасная развилка",
		"icon": "!",
		"icon_path": "res://assets/sprites/map_icons/map_event_question.png",
		"tooltip": "Опасная развилка\nВыбор: безопасный обход (золото/лечение) или рискованный срез через бой.",
		"color": Color(0.34, 0.20, 0.10, 0.96),
		"border": Color(0.96, 0.58, 0.22, 1.0),
	},
	"chest": {
		"name": "Сундук",
		"icon": "CHEST",
		"icon_path": "res://assets/sprites/map_icons/map_chest_artifact.png",
		"tooltip": "Сундук\nГарантированный выбор 1 из 3 артефактов в середине маршрута.",
		"color": Color(0.30, 0.18, 0.07, 0.96),
		"border": Color(1.0, 0.78, 0.30, 1.0),
	},
	"rest": {
		"name": "Костер",
		"icon": "REST",
		"icon_path": "res://assets/sprites/map_icons/map_rest_campfire.png",
		"tooltip": "Костер\nОтдых. Можно восстановить здоровье или получить защитный бонус.",
		"color": Color(0.28, 0.18, 0.09, 0.96),
		"border": Color(1.0, 0.60, 0.22, 1.0),
	},
	# SCRUM-610: «Алтарь жертвы» — узел постоянной сделки тело-за-силу (без боя,
	# без арта). SCRUM-994: раньше носил иконку костей элиты и читался игроком как
	# элитный бой, хотя открывает событие — теперь переиспользует событийную
	# «?» (как hazard); иконка map_elite_skull_bones эксклюзивна для elite_battle.
	# Отдельный кроваво-пурпурный тон под жертвенный мотив сохранён.
	"altar": {
		"name": "Алтарь жертвы",
		"icon": "ALT",
		"icon_path": "res://assets/sprites/map_icons/map_event_question.png",
		"tooltip": "Алтарь жертвы\nСделка без боя: отдай часть здоровья за постоянную силу на весь забег.",
		"color": Color(0.30, 0.06, 0.12, 0.97),
		"border": Color(0.86, 0.20, 0.46, 1.0),
	},
	"boss": {
		"name": "Босс",
		"icon": "B",
		"icon_path": "res://assets/sprites/map_icons/map_boss_rift_warden.png",
		"disk_icon_path": "res://assets/sprites/map_icons/map_boss_disk_devourer.png",
		"tooltip": "Босс\nФинальная битва маршрута. Победа завершает забег и дает мета-награду.",
		"color": Color(0.34, 0.04, 0.06, 0.98),
		"border": Color(1.0, 0.14, 0.18, 1.0),
	},
}
const OBSTACLE_MAX_ATTEMPTS := 150
const SPAWN_EDGE_PADDING := 72.0
const SPAWN_PLAYER_SAFE_RADIUS := 420.0  # SCRUM-518: чуть шире на просторной арене (4096×2304) для комфорта старта
const SMALL_PACK_CHANCE := 0.28
const WAVE_SETTINGS := {
	"base_spawn_count": 5,
	"spawn_count_per_stage": 1,
	"spawn_count_per_wave_step": 1,
	"wave_step_size": 3,
	"normal_spawn_limit": 10,
	"elite_spawn_limit": 3,
	"boss_spawn_limit": 3,
	"base_active_cap": 22,
	"active_cap_per_stage": 6,
	"active_cap_per_wave_step": 3,
	"elite_active_cap": 12,
	"boss_active_cap": 12,
	"max_active_cap": 48,
	"spawn_pause_min": 0.7,
	"spawn_pause_max": 1.2,
	"boss_spawn_pause_min": 2.0,
	"boss_spawn_pause_max": 3.2,
}
const ENEMY_BALANCE := {
	"default": {"hp_multiplier": 3.1, "speed_multiplier": 0.86, "damage_multiplier": 1.25},
	"runner": {"hp_multiplier": 2.6, "speed_multiplier": 0.95, "damage_multiplier": 1.19},
	"biter": {"hp_multiplier": 2.7, "speed_multiplier": 0.94, "damage_multiplier": 1.23},
	"bruiser": {"hp_multiplier": 4.6, "speed_multiplier": 0.74, "damage_multiplier": 1.38},
	"shield": {"hp_multiplier": 4.3, "speed_multiplier": 0.76, "damage_multiplier": 1.27},
	"shooter": {"hp_multiplier": 3.2, "speed_multiplier": 0.80, "damage_multiplier": 1.30},
	"summoner": {"hp_multiplier": 3.6, "speed_multiplier": 0.80, "damage_multiplier": 1.23},
	"flying": {"hp_multiplier": 2.75, "speed_multiplier": 0.92, "damage_multiplier": 1.19},
	"elite": {"hp_multiplier": 4.6, "speed_multiplier": 0.84, "damage_multiplier": 2.10},
	"boss": {"hp_multiplier": 1.9, "speed_multiplier": 0.86, "damage_multiplier": 1.46},
}
const ENEMY_SPAWN_WEIGHTS := {
	"res://scenes/Enemy.tscn": 7.0,
	"res://scenes/EnemyRunner.tscn": 2.6,
	"res://scenes/EnemyBiter.tscn": 2.2,
	"res://scenes/EnemyBruiser.tscn": 1.35,
	"res://scenes/EnemyShield.tscn": 0.95,
	"res://scenes/EnemyFlyingRunner.tscn": 1.15,
	"res://scenes/EnemySummoner.tscn": 0.40,
	"res://scenes/EnemyShooter.tscn": 0.36,
	"res://scenes/EnemyMage.tscn": 0.28,
	"res://scenes/EnemySpitter.tscn": 0.24,
	"res://scenes/EnemyBoneShaman.tscn": 0.34,
}
const RESOLUTION_OPTIONS := [
	Vector2i(2560, 1440),
	Vector2i(1920, 1080),
]
const WINDOW_MODE_OPTIONS := [
	"Windowed",
	"Borderless Window",
	"Fullscreen",
]
const PROGRESSION_DATA := preload("res://scripts/progression_data.gd")
const EVENT_DATA := preload("res://scripts/event_data.gd")
const PAUSE_STATS_MENU_SCENE := preload("res://scenes/PauseStatsMenu.tscn")
const LEVEL_UP_TOAST_SCENE := preload("res://scenes/LevelUpToast.tscn")
const LEVEL_UP_EFFECT_SCENE := preload("res://scenes/LevelUpEffect.tscn")
const UIIconRegistry := preload("res://scripts/ui_icon_registry.gd")
const LEVEL_UP_MOD_DISPLAY := {
	"damage_multiplier": "damage",
	"magic_damage_multiplier": "magic_damage",
	"sound_damage_multiplier": "sound_wave_damage",
	"attack_speed_multiplier": "attack_speed",
	"max_health_flat": "health_point",
	"move_speed_multiplier": "move_speed",
	"sector_multiplier": "aoe_radius",
	"aoe_radius_multiplier": "aura_radius",
	"pickup_radius_flat": "pickup_radius",
	"defense_flat": "defense",
	"range_multiplier": "attack_range",
	"crit_chance_flat": "crit_chance",
	"crit_damage_flat": "crit_damage_multiplier",
	"knockback_multiplier": "knockback_power",
	"dodge_flat": "dodge",
	"dot_damage_flat": "dot_damage",
	"dot_speed_flat": "dot_speed",
	"projectile_speed_flat": "projectile_speed",
	"aura_radius_flat": "aura_radius",
	"buff_power_flat": "buff_power",
	"summon_bonus": "summon_amount",
	"extra_projectile": "summon_amount",
	"absorb_flat": "absorb",
	"regeneration_flat": "regeneration",
	"vampiric_amount_flat": "vampiric_amount",
	"vampiric_chance_flat": "vampiric_chance",
	"ultimate_flat": "ultimate_multiplier",
}
const INPUT_ACTIONS := [
	{
		"action": "move_up",
		"label": "Вверх",
		"default_key": KEY_W,
		"alternate_key": KEY_UP,
	},
	{
		"action": "move_down",
		"label": "Вниз",
		"default_key": KEY_S,
		"alternate_key": KEY_DOWN,
	},
	{
		"action": "move_left",
		"label": "Влево",
		"default_key": KEY_A,
		"alternate_key": KEY_LEFT,
	},
	{
		"action": "move_right",
		"label": "Вправо",
		"default_key": KEY_D,
		"alternate_key": KEY_RIGHT,
	},
	{
		"action": "pause",
		"label": "Пауза",
		"default_key": KEY_ESCAPE,
		"alternate_key": 0,
	},
	{
		"action": "ultimate",
		"label": "Ультимейт",
		"default_key": KEY_R,
		"alternate_key": 0,
	},
	{
		"action": "open_level_up",
		"label": "Level Up",
		"default_key": KEY_SPACE,
		"alternate_key": 0,
	},
	{
		"action": "feedback",
		"label": "Фидбек",
		"default_key": KEY_P,
		"alternate_key": 0,
	},
]
const CODEX_ENEMY_NAME_TO_ID := {
	"Rift Cutter": "rift_cutter",
	"Ash Marksman": "ash_marksman",
	"Spark Runner": "spark_runner",
	"Stone Bruiser": "stone_bruiser",
	"Bone Caller": "bone_caller",
	"Void Mage": "void_mage",
	"Venom Spitter": "venom_spitter",
	"Rift Shieldbearer": "rift_shieldbearer",
	"Small Biter": "small_biter",
	"Bone Shaman": "bone_shaman",
	"Winged Spark": "winged_spark",
	"Iron Bastion": "iron_bastion",
	"Night Stalker": "night_stalker",
	"Plague Prophet": "plague_prophet",
	"Shard Marshal": "shard_marshal",
	"Rift Warden": "rift_warden",
	"Disk Devourer": "disk_devourer",
	"Bone Archon": "bone_archon",
	"Brood Mother": "brood_mother",
	"Ashen Colossus": "ashen_colossus",
}

var selected_character_id := "berserk"
var selected_weapon_id := "sword"
# SCRUM-618: выбранный стартовый боон забега ("" = без боона, тождественность).
var selected_start_boon_id := ""
var current_act := 1
var route_stage := 0
var combat_active := false
var boss_combat_active := false
var round_time_left := 0.0
var spawn_cooldown := 0.0
var current_player: Node2D = null
var run_player_snapshot := {}
# SCRUM-502: метрики забега для экрана итогов (run summary). НЕ персистятся (нет в
# _run_autosave_state) — обнуляются на старте нового забега, не текут из autosave.
var run_metrics := {}
var ui_layer: CanvasLayer = null
var hud_layer: CanvasLayer = null
var pause_overlay_layer: CanvasLayer = null
var feedback_overlay_layer: CanvasLayer = null
var timer_label: Label = null
var status_label: Label = null
var health_bar: ProgressBar = null
var health_label: Label = null
var xp_bar: ProgressBar = null
var xp_label: Label = null
var money_label: Label = null
var ultimate_bar: ProgressBar = null
var ultimate_label: Label = null
var artifact_label: Label = null
var level_up_button: Button = null
# SCRUM-874: HUD-боссбар сверху экрана — цель узла (акт-босс/элитка) и её UI-ноды.
var boss_hud_target: Node2D = null
var boss_hud_bar: ProgressBar = null
var boss_hud_name_label: Label = null
var pause_stats_menu: Control = null
var route_nodes := []
var current_route_choice := ""
var current_node_type := ""
var current_combat_type := "battle"
var current_boss_id := "rift_warden"
# SCRUM-619: текущий бой — секретный апекс-босс конца Акта 3 (выставляется
# SCRUM-541: set only while the post-Act-3 secret boss follow-up is active.
var secret_boss_active := false
var current_node_seed := 0
var route_selected_indices := []
var used_event_ids := []
var current_event_definition := {}
var pending_event_combat := {}
# SCRUM-996: отложенный выход из «событийного» магазина (shop_after у исхода
# события или post_combat победы событийного боя). Непустой Callable подменяет
# штатный выход магазина (_return_to_map_after_shop_visit) на продолжение
# событийного пути (advance/возврат с автосейвом). Живёт только в памяти и НЕ
# сохраняется: выход из игры до завершения пути = откат к последнему автосейву
# (норма, см. docs/design/systems/persistence.md), поэтому рестор/новый забег
# обязаны сбрасывать поле.
var event_shop_exit_action := Callable()
var level_up_return_to_map := false
# SCRUM-530: level-up, открытый с узла-события, должен вернуть на ТО ЖЕ событие, а не на
# карту (иначе для случайного события происходит «тихий рерол» исходного набора опций).
var level_up_return_to_event := false
var meta_points := 0
var berserk_ascension_unlocked := false
var spawn_wave_index := 0
var active_spawn_edges := []
var selected_resolution_index := 0
var selected_window_mode_index := 0
var pending_rebind_action := ""
var current_shop_items := []
var current_shop_purchased := []
var current_shop_node_key := ""
var run_used_shop := false
var shop_reentry_pending := false
var shop_reentry_route_stage := -1
var shop_reentry_branch_index := -1
var pending_level_ups := 0
var pause_reasons := {}
var route_map_pan_active := false
var route_map_pan_last_position := Vector2.ZERO
var route_map_drag_distance := 0.0
var route_map_drag_suppressed_click := false
var route_debug_free_pick := false
var texture_cache := {}
var screen_background_cache := {}
var _last_hud_snapshot := {}
var rng := RandomNumberGenerator.new()

const UI_SCREENS_SCRIPT := preload("res://scripts/ui_screens.gd")
const ROUTE_MAP_SCRIPT := preload("res://scripts/route_map_screen.gd")
const COMBAT_DIRECTOR_SCRIPT := preload("res://scripts/combat_director.gd")
const META_PROGRESSION := preload("res://scripts/meta_progression.gd")
const ACHIEVEMENTS_DATA := preload("res://scripts/achievements_data.gd")
const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const RUN_AUTOSAVE := preload("res://scripts/run_autosave.gd")
const FEEDBACK_REPORTER_SCRIPT := preload("res://scripts/feedback_reporter.gd")
const DEV_CONSOLE_SCRIPT := preload("res://scripts/dev_console.gd")

var ui
var route
var combat
var dev_console: CanvasLayer = null
var meta_state := {}
# Подача боя: тряска камеры (тумблер в настройках, умеренная по умолчанию).
var screen_shake_enabled := true
var combat_feedback_enabled := true
# Единый Escape-назад: текущий экран регистрирует действие возврата;
# сбрасывается при каждой очистке UI. В бою Escape обрабатывается отдельно (пауза).
var ui_escape_action := Callable()
# Фиксация наборов предложений (анти-реролл): набор живет до легального сброса.
var level_up_offer := []
var attribute_offer := []
var attribute_rerolls_left := 0
var selected_screen_index := 0
var selected_ascension_level := 0
var run_ascension_difficulty := {}
var audio_settings := {
	"master_volume": 1.0,
	"music_volume": 1.0,
	"sfx_volume": 1.0,
	"music_enabled": false,
	"sfx_enabled": false,
}
var input_bindings := {}
var aim_mode := "nearest"
var debug_mode_enabled := false
# SCRUM-816: геймпад-настройки (устройство ввода + ребинд/deadzone/vibration).
# Персистятся через save_game_settings; deadzone/vibration зеркалятся в root-мету
# (player.gd._runtime_setting читает мету), input_mode/bindings применяет
# InputDeviceManager при живой смене из вкладки «Управление».
var input_mode := "auto"
var gamepad_bindings := {}
var gamepad_deadzone := 0.25
var gamepad_vibration := true


func _init() -> void:
	ui = UI_SCREENS_SCRIPT.new(self)
	route = ROUTE_MAP_SCRIPT.new(self)
	combat = COMBAT_DIRECTOR_SCRIPT.new(self)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	_load_meta_progression()
	_load_game_settings()
	ui._setup_default_input_actions()
	ui._apply_game_cursor()
	dev_console = DEV_CONSOLE_SCRIPT.new(self)
	add_child(dev_console)
	ui._show_main_menu()


func _exit_tree() -> void:
	_release_runtime_texture_refs()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_release_runtime_texture_refs()


func request_game_quit() -> void:
	set_meta("game_quit_requested", true)
	if bool(get_meta("suppress_game_quit", false)):
		return
	get_tree().quit()


func _release_runtime_texture_refs() -> void:
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)
	texture_cache.clear()


func _load_game_settings() -> void:
	var settings: Dictionary = GAME_SETTINGS.load_settings()
	selected_resolution_index = int(settings["resolution_index"])
	selected_window_mode_index = int(settings["window_mode_index"])
	selected_screen_index = int(settings["screen_index"])
	for key in audio_settings.keys():
		audio_settings[key] = settings[key]
	input_bindings = (settings.get("input_bindings", {}) as Dictionary).duplicate(true)
	aim_mode = str(settings.get("aim_mode", "nearest"))
	if not ["nearest", "cursor"].has(aim_mode):
		aim_mode = "nearest"
	screen_shake_enabled = bool(settings.get("screen_shake", true))
	combat_feedback_enabled = bool(settings.get("combat_feedback", true))
	debug_mode_enabled = bool(settings.get("debug_mode", false))
	# SCRUM-816: геймпад-настройки. input_mode валидируется, bindings — Dictionary,
	# deadzone клампится в диапазон ядра [0.05..0.5], vibration — bool.
	input_mode = str(settings.get("input_mode", "auto"))
	if not ["auto", "keyboard", "gamepad"].has(input_mode):
		input_mode = "auto"
	gamepad_bindings = (settings.get("gamepad_bindings", {}) as Dictionary).duplicate(true)
	gamepad_deadzone = clampf(float(settings.get("gamepad_deadzone", 0.25)), 0.05, 0.5)
	gamepad_vibration = bool(settings.get("gamepad_vibration", true))
	# Глобальный флаг для скриптов без ссылки на game (enemy/boss slam-тряска).
	get_tree().root.set_meta("screen_shake", screen_shake_enabled)
	get_tree().root.set_meta("combat_feedback", combat_feedback_enabled)
	get_tree().root.set_meta("aim_mode", aim_mode)
	get_tree().root.set_meta("debug_mode", debug_mode_enabled)
	# player.gd читает эти два ключа через root-мету (_runtime_setting).
	get_tree().root.set_meta("gamepad_deadzone", gamepad_deadzone)
	get_tree().root.set_meta("gamepad_vibration", gamepad_vibration)
	_apply_audio_settings()
	if DisplayServer.get_name() != "headless":
		if _is_editor_preview_runtime():
			ui._apply_editor_preview_video_settings()
		else:
			ui._apply_video_settings()


func _is_editor_preview_runtime() -> bool:
	return OS.has_feature("editor")


func save_game_settings() -> void:
	var settings := {
		"resolution_index": selected_resolution_index,
		"window_mode_index": selected_window_mode_index,
		"screen_index": selected_screen_index,
	}
	for key in audio_settings.keys():
		settings[key] = audio_settings[key]
	settings["screen_shake"] = screen_shake_enabled
	settings["combat_feedback"] = combat_feedback_enabled
	settings["debug_mode"] = debug_mode_enabled
	settings["aim_mode"] = aim_mode
	if ui != null:
		settings["input_bindings"] = ui._current_input_bindings()
	else:
		settings["input_bindings"] = input_bindings.duplicate(true)
	# SCRUM-816: без этих ключей save_settings перезаписал бы их дефолтами при
	# любом сохранении (aim/громкость/ребинд) — раскладка геймпада бы слетала.
	settings["input_mode"] = input_mode
	settings["gamepad_bindings"] = gamepad_bindings.duplicate(true)
	settings["gamepad_deadzone"] = gamepad_deadzone
	settings["gamepad_vibration"] = gamepad_vibration
	GAME_SETTINGS.save_settings(settings)
	get_tree().root.set_meta("combat_feedback", combat_feedback_enabled)
	get_tree().root.set_meta("aim_mode", aim_mode)
	get_tree().root.set_meta("debug_mode", debug_mode_enabled)
	get_tree().root.set_meta("gamepad_deadzone", gamepad_deadzone)
	get_tree().root.set_meta("gamepad_vibration", gamepad_vibration)


func run_autosave_has_run() -> bool:
	return RUN_AUTOSAVE.has_run()


func save_run_autosave(reason := "") -> bool:
	if route_nodes.is_empty():
		return false
	var state := _run_autosave_state()
	state["saved_reason"] = reason
	return RUN_AUTOSAVE.save_run(state)


func load_run_autosave() -> bool:
	var state: Dictionary = RUN_AUTOSAVE.load_run()
	if state.is_empty():
		return false
	_apply_run_autosave_state(state)
	return true


func clear_run_autosave() -> void:
	RUN_AUTOSAVE.clear_run()


# SCRUM-502 · Метрики забега (run summary). Аккумулируются по ходу прогона, обнуляются
# на старте нового забега. НЕ входят в _run_autosave_state — не персистятся и не текут
# из загруженного autosave (после «Продолжить» метрики считаются с нуля за новый прогон).
func reset_run_metrics() -> void:
	run_metrics = {
		"kills": 0,
		"boss_kills": 0,
		"damage_dealt": 0.0,
		"damage_taken": 0.0,
		"gold_collected": 0,
		"time_seconds": 0.0,
		"route_stage_reached": 0,
		"final_level": 0,
		"artifacts": [],
		"outcome_reason": "",
	}


func record_run_kill(is_boss: bool) -> void:
	if run_metrics.is_empty():
		reset_run_metrics()
	run_metrics["kills"] = int(run_metrics.get("kills", 0)) + 1
	if is_boss:
		run_metrics["boss_kills"] = int(run_metrics.get("boss_kills", 0)) + 1


func add_run_damage_dealt(amount: float) -> void:
	if amount <= 0.0:
		return
	if run_metrics.is_empty():
		reset_run_metrics()
	run_metrics["damage_dealt"] = float(run_metrics.get("damage_dealt", 0.0)) + amount


func add_run_damage_taken(amount: float) -> void:
	if amount <= 0.0:
		return
	if run_metrics.is_empty():
		reset_run_metrics()
	run_metrics["damage_taken"] = float(run_metrics.get("damage_taken", 0.0)) + amount


func add_run_time(delta: float) -> void:
	if delta <= 0.0:
		return
	if run_metrics.is_empty():
		reset_run_metrics()
	run_metrics["time_seconds"] = float(run_metrics.get("time_seconds", 0.0)) + delta


func add_run_gold_collected(amount: int) -> void:
	if amount <= 0:
		return
	if run_metrics.is_empty():
		reset_run_metrics()
	run_metrics["gold_collected"] = int(run_metrics.get("gold_collected", 0)) + amount


# Снять финальные значения игрока (уровень/артефакты) и достигнутый ряд в метрики.
# Зовётся на завершении забега (победа/смерть) до удаления игрока. snapshot = run_player_snapshot
# или живой игрок; берём из переданного словаря, чтобы не зависеть от queue_free.
# NB: gold_collected НЕ снимается из snapshot — это аккумулятор «собрано за забег»
# (add_run_gold_collected), а не остаток кошелька (см. SCRUM-555).
func capture_run_metrics_finals(source: Dictionary) -> void:
	if run_metrics.is_empty():
		reset_run_metrics()
	run_metrics["final_level"] = int(source.get("level", run_metrics.get("final_level", 0)))
	# SCRUM-555: не перезаписывать gold_collected кошельком (source.money). Перезапись
	# показывала на экране итогов ОСТАТОК (после трат в магазине), расходясь с подписью
	# «Собрано золота». Источник правды — накопитель add_run_gold_collected.
	var artifacts_raw = source.get("artifacts", run_metrics.get("artifacts", []))
	var artifacts_snapshot: Array = []
	if artifacts_raw is Array:
		artifacts_snapshot = artifacts_raw as Array
	run_metrics["artifacts"] = artifacts_snapshot.duplicate(true)
	run_metrics["route_stage_reached"] = maxi(int(run_metrics.get("route_stage_reached", 0)), route_stage)
	# SCRUM-617: финальные метрики собраны → оценить персистентные ачивки забега
	# (зовётся на ЛЮБОМ завершении: победа над финальным боссом, смерть, экран итогов).
	evaluate_run_achievements()


# SCRUM-617: разблокировать достигнутые ачивки по финальным метрикам забега и
# начислить разовую награду meta_points. Идемпотентно (уже открытые не начисляются).
# Сохраняет мету только если что-то реально открылось.
func evaluate_run_achievements() -> void:
	var result: Dictionary = ACHIEVEMENTS_DATA.evaluate_run(meta_state, run_metrics)
	if int(result.get("awarded", 0)) > 0 or not (result.get("newly_unlocked", []) as Array).is_empty():
		META_PROGRESSION.save_state(meta_state)
		meta_points = int(meta_state.get("meta_points", 0))


func _run_autosave_state() -> Dictionary:
	return {
		"selected_character_id": selected_character_id,
		"selected_weapon_id": selected_weapon_id,
		"selected_start_boon_id": selected_start_boon_id,
		"selected_ascension_level": selected_ascension_level,
		"current_act": current_act,
		"route_stage": route_stage,
		"route_nodes": route_nodes.duplicate(true),
		"route_selected_indices": route_selected_indices.duplicate(true),
		"current_route_choice": current_route_choice,
		"current_node_type": current_node_type,
		"current_combat_type": current_combat_type,
		"current_boss_id": current_boss_id,
		"secret_boss_active": secret_boss_active,
		"current_node_seed": current_node_seed,
		"run_player_snapshot": run_player_snapshot.duplicate(true),
		"pending_level_ups": pending_level_ups,
		"level_up_offer": level_up_offer.duplicate(true),
		"attribute_offer": attribute_offer.duplicate(true),
		"attribute_rerolls_left": attribute_rerolls_left,
		"used_event_ids": used_event_ids.duplicate(true),
		"current_event_definition": current_event_definition.duplicate(true),
		"run_ascension_difficulty": run_ascension_difficulty.duplicate(true),
		"current_shop_items": current_shop_items.duplicate(true),
		"current_shop_purchased": current_shop_purchased.duplicate(true),
		"current_shop_node_key": current_shop_node_key,
		"run_used_shop": run_used_shop,
		"shop_reentry_pending": shop_reentry_pending,
		"shop_reentry_route_stage": shop_reentry_route_stage,
		"shop_reentry_branch_index": shop_reentry_branch_index,
	}


func _apply_run_autosave_state(state: Dictionary) -> void:
	combat_active = false
	boss_combat_active = false
	_clear_all_game_pauses()
	_clear_world()
	_clear_hud()
	_clear_ui()

	selected_character_id = str(state.get("selected_character_id", selected_character_id))
	selected_weapon_id = str(state.get("selected_weapon_id", selected_weapon_id))
	selected_start_boon_id = PROGRESSION_DATA.canonical_start_boon_id(str(state.get("selected_start_boon_id", "")))
	selected_ascension_level = int(state.get("selected_ascension_level", 0))
	current_act = clampi(int(state.get("current_act", 1)), 1, ACT_COUNT)
	route_stage = maxi(0, int(state.get("route_stage", 0)))
	route_nodes = _autosave_array(state.get("route_nodes", []))
	if route_nodes.is_empty():
		route_nodes = route._generate_route()
	route_stage = clampi(route_stage, 0, maxi(route_nodes.size() - 1, 0))
	route_selected_indices = _autosave_array(state.get("route_selected_indices", []))
	current_route_choice = str(state.get("current_route_choice", ""))
	current_node_type = str(state.get("current_node_type", ""))
	current_combat_type = str(state.get("current_combat_type", "battle"))
	current_boss_id = str(state.get("current_boss_id", "rift_warden"))
	secret_boss_active = bool(state.get("secret_boss_active", false))
	current_node_seed = int(state.get("current_node_seed", 0))
	run_player_snapshot = _autosave_dictionary(state.get("run_player_snapshot", {}))
	pending_level_ups = maxi(0, int(state.get("pending_level_ups", 0)))
	level_up_offer = _autosave_array(state.get("level_up_offer", []))
	attribute_offer = _autosave_array(state.get("attribute_offer", []))
	attribute_rerolls_left = maxi(0, int(state.get("attribute_rerolls_left", 0)))
	used_event_ids = _autosave_array(state.get("used_event_ids", []))
	current_event_definition = _autosave_dictionary(state.get("current_event_definition", {}))
	pending_event_combat.clear()
	event_shop_exit_action = Callable()  # SCRUM-996: событийный магазин не переживает рестор
	run_ascension_difficulty = _autosave_dictionary(state.get("run_ascension_difficulty", {}))
	current_shop_items = _autosave_array(state.get("current_shop_items", []))
	current_shop_purchased = _autosave_array(state.get("current_shop_purchased", []))
	current_shop_node_key = str(state.get("current_shop_node_key", ""))
	run_used_shop = bool(state.get("run_used_shop", false))
	shop_reentry_pending = bool(state.get("shop_reentry_pending", false))
	shop_reentry_route_stage = int(state.get("shop_reentry_route_stage", -1))
	shop_reentry_branch_index = int(state.get("shop_reentry_branch_index", -1))


func _autosave_array(value: Variant) -> Array:
	if value is Array:
		return (value as Array).duplicate(true)
	return []


func _autosave_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func route_scaling_stage() -> int:
	return maxi(0, route_stage + (clampi(current_act, 1, ACT_COUNT) - 1) * ACT_SCALING_STAGE_OFFSET)


# --- SCRUM-499: детерминированное превью узлов маршрута ---
# Каждый узел несёт стабильный "seed". И бой, и тултип-превью катят выбор биома и
# типа элитки через эти общие функции от одного сида → превью совпадает с боем
# by construction (бой делегирует сюда, тултип зовёт то же самое заранее).
const NODE_SEED_SALT_BIOME := 0x9E3779B1
const NODE_SEED_SALT_ELITE := 0x85EBCA77

func fallback_node_seed(route_node: Dictionary) -> int:
	# Старые сейвы без поля "seed": детерминированный сид от позиции/типа узла.
	var row := int(route_node.get("row", 0))
	var branch := int(route_node.get("branch", 0))
	var type_hash := int(str(route_node.get("type", "battle")).hash())
	return ((row * 73856093) ^ (branch * 19349663) ^ type_hash) & 0x7FFFFFFF

func node_aspect_rng(node_seed: int, salt: int) -> RandomNumberGenerator:
	var generator := RandomNumberGenerator.new()
	generator.seed = (int(node_seed) ^ int(salt)) & 0x7FFFFFFFFFFFFFFF
	return generator

func node_background_path(node_type: String, is_boss_fight: bool, node_seed: int) -> String:
	var key := "boss" if is_boss_fight else str(node_type)
	var options: Array = ARENA_BACKGROUND_OPTIONS.get(key, ARENA_BACKGROUND_OPTIONS["default"])
	if options.is_empty():
		options = ARENA_BACKGROUND_OPTIONS["default"]
	var generator := node_aspect_rng(node_seed, NODE_SEED_SALT_BIOME)
	return str(options[generator.randi_range(0, options.size() - 1)])

func elite_scene_options() -> Array:
	var scenes := [elite_armored_scene, elite_stalker_scene, elite_poisoned_scene, elite_commander_scene]
	var available := []
	for scene in scenes:
		if scene != null:
			available.append(scene)
	return available

func node_elite_scene(node_seed: int) -> PackedScene:
	var available := elite_scene_options()
	if available.is_empty():
		return null
	var generator := node_aspect_rng(node_seed, NODE_SEED_SALT_ELITE)
	return available[generator.randi_range(0, available.size() - 1)] as PackedScene


func act_progress_label() -> String:
	return "Акт %d/%d" % [clampi(current_act, 1, ACT_COUNT), ACT_COUNT]


func advance_to_next_act() -> bool:
	if current_act >= ACT_COUNT:
		return false
	current_act += 1
	# SCRUM-873: отхил на переходе акта. Игрок между узлами живёт в
	# run_player_snapshot (снят в _end_combat ДО этого вызова) — лечим снапшот,
	# HP «переезжает» в первый бой нового акта через _restore_player_snapshot.
	if not run_player_snapshot.is_empty():
		var snapshot_max := maxf(float(run_player_snapshot.get("max_health", 0.0)), 0.0)
		var snapshot_health := float(run_player_snapshot.get("health", snapshot_max))
		run_player_snapshot["health"] = minf(snapshot_max, snapshot_health + snapshot_max * ACT_TRANSITION_HEAL_PERCENT)
	route_stage = 0
	route_nodes = route._generate_route()
	route_selected_indices.clear()
	current_route_choice = ""
	current_node_type = ""
	current_combat_type = "battle"
	current_boss_id = "rift_warden"
	secret_boss_active = false
	current_node_seed = 0
	pending_event_combat.clear()
	event_shop_exit_action = Callable()  # SCRUM-996: событийный магазин не тянется между актами
	level_up_return_to_map = false
	level_up_return_to_event = false
	shop_reentry_pending = false
	shop_reentry_route_stage = -1
	shop_reentry_branch_index = -1
	current_shop_items.clear()
	current_shop_purchased.clear()
	current_shop_node_key = ""
	save_run_autosave("act_transition")
	return true


func _apply_audio_settings() -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null and audio.has_method("apply_volume_settings"):
		audio.apply_volume_settings(audio_settings)


func _load_meta_progression() -> void:
	meta_state = META_PROGRESSION.load_state()
	meta_points = int(meta_state.get("meta_points", 0))
	berserk_ascension_unlocked = ascension_level_for("berserk") >= 1


func record_codex_discovery(category: String, content_id: String) -> void:
	var id := content_id.strip_edges()
	if id == "":
		return
	if meta_state.is_empty():
		meta_state = META_PROGRESSION.load_state()
	if META_PROGRESSION.is_codex_discovered(meta_state, category, id):
		return
	meta_state = META_PROGRESSION.record_codex_discovery(meta_state, category, id)
	META_PROGRESSION.save_state(meta_state)


func record_codex_artifact_discovery(reward: Dictionary) -> void:
	if str(reward.get("kind", "")) != "artifact":
		return
	record_codex_discovery("artifacts", str(reward.get("id", "")))


func record_codex_enemy_discovery(enemy: Node) -> void:
	if enemy == null:
		return
	var content_id := ""
	var category := "monsters"
	if enemy.is_in_group("bosses"):
		category = "bosses"
		content_id = str(enemy.get_meta("boss_id", current_boss_id))
	elif enemy.has_meta("mini_elite_kind"):
		content_id = str(enemy.get_meta("mini_elite_kind"))
	else:
		var enemy_name := ""
		if enemy.get("enemy_type_name") != null:
			enemy_name = str(enemy.get("enemy_type_name"))
		content_id = str(CODEX_ENEMY_NAME_TO_ID.get(enemy_name, ""))
	record_codex_discovery(category, content_id)


func ascension_level_for(character_id: String) -> int:
	return META_PROGRESSION.ascension_level(meta_state, character_id)


func secret_encounter_pending() -> bool:
	if current_act < ACT_COUNT:
		return false
	return META_PROGRESSION.secret_encounter_unlocked_for_level(selected_ascension_level)


func resolve_act3_boss_id(base_boss_id: String) -> String:
	secret_boss_active = false
	return base_boss_id


func should_start_secret_boss_after_act3() -> bool:
	if secret_boss_active:
		return false
	return current_act >= ACT_COUNT and secret_encounter_pending()


func start_secret_boss_encounter() -> void:
	secret_boss_active = true
	current_boss_id = META_PROGRESSION.SECRET_BOSS_ID
	current_node_type = "boss"
	current_combat_type = "boss"
	save_run_autosave("secret_boss")
	combat._start_combat(true, "boss")


func record_boss_victory() -> void:
	# SCRUM-620: контекст забега для челленджей класса — какое оружие и был ли магазин.
	# used_shop=false только если за ВЕСЬ забег не куплено ни одного предмета.
	var run_context := {
		"weapon_id": selected_weapon_id,
		"used_shop": run_used_shop,
	}
	meta_state = META_PROGRESSION.record_boss_victory(meta_state, selected_character_id, selected_ascension_level, run_context)
	# SCRUM-619: если это был секретный бой Акта 3 — разовая мета-награда (идемпотентно).
	if secret_boss_active:
		meta_state = META_PROGRESSION.record_secret_boss_victory(meta_state)
		secret_boss_active = false
	META_PROGRESSION.save_state(meta_state)
	meta_points = int(meta_state.get("meta_points", 0))
	berserk_ascension_unlocked = ascension_level_for("berserk") >= 1


func ascension_selectable_max(character_id: String) -> int:
	return META_PROGRESSION.selectable_max(meta_state, character_id)


func ascension_difficulty() -> Dictionary:
	# Активные модификаторы сложности текущего забега (кэш на забег).
	if run_ascension_difficulty.is_empty():
		run_ascension_difficulty = PROGRESSION_DATA.ascension_difficulty_mods(selected_ascension_level)
	return run_ascension_difficulty


func reset_run_ascension() -> void:
	# Подстраховка: уровень забега не выше открытого максимума выбранного героя.
	selected_ascension_level = clampi(selected_ascension_level, 0, ascension_selectable_max(selected_character_id))
	run_ascension_difficulty = PROGRESSION_DATA.ascension_difficulty_mods(selected_ascension_level)


func apply_ascension_bonuses(player: Node) -> void:
	if player == null:
		return
	# 1) Наградный трек меты: старые per-class баффы за ПРОЙДЕННЫЕ уровни (постоянно).
	var earned := ascension_level_for(selected_character_id)
	if earned > 0:
		var mods: Dictionary = PROGRESSION_DATA.ascension_mods(selected_character_id, earned)
		if not mods.is_empty() and player.has_method("apply_reward"):
			player.apply_reward({"mods": mods})
	# 2) Усложнения выбранного уровня возвышения: трофеи/лечение/макс-HP сворачиваем
	#    в run_modifiers игрока (combat_director читает остальное через ascension_difficulty()).
	reset_run_ascension()
	var difficulty := ascension_difficulty()
	var run_mods = player.get("run_modifiers")
	if run_mods is Dictionary:
		run_mods["xp_gain_multiplier"] = float(run_mods.get("xp_gain_multiplier", 1.0)) * float(difficulty["reward_mult"])
		run_mods["money_gain_multiplier"] = float(run_mods.get("money_gain_multiplier", 1.0)) * float(difficulty["reward_mult"])
		run_mods["healing_multiplier"] = float(run_mods.get("healing_multiplier", 1.0)) * float(difficulty["healing_mult"])
		run_mods["max_health_multiplier"] = float(run_mods.get("max_health_multiplier", 1.0)) * float(difficulty["player_max_hp_mult"])
		if player.has_method("_apply_stat_scaling"):
			player._apply_stat_scaling(true)
	# 3) Мета-древо умений (SCRUM-150): боевое подмножество в run_modifiers + старт-золото забега.
	var skill_mods: Dictionary = META_PROGRESSION.skill_modifiers_for_class(meta_state, selected_character_id)
	# Прогрессия по классам (SCRUM-360): бонусы ТОЛЬКО выбранного класса — мерджим в
	# skill_mods (ключи class_* не пересекаются с аккаунтными), применяются вместе.
	var class_mods: Dictionary = META_PROGRESSION.class_modifiers(meta_state, selected_character_id)
	for class_key in class_mods:
		skill_mods[class_key] = class_mods[class_key]
	# SCRUM-620: бонусы выполненных челленджей класса — те же class_*-ключи,
	# складываем ПОВЕРХ прогрессии (доли суммируются, эффект 1.0+sum). Вклад челленджей
	# уже клампнут на +5%/ключ в class_challenge_modifiers (анти-крип).
	var challenge_mods: Dictionary = META_PROGRESSION.class_challenge_modifiers(meta_state, selected_character_id)
	for challenge_key in challenge_mods:
		skill_mods[challenge_key] = float(skill_mods.get(challenge_key, 0.0)) + float(challenge_mods[challenge_key])
	# SCRUM-618: стартовый боон забега — мелкие mods в том же ключевом словаре (damage_mult,
	# *_flat и т.п.). Складываем с накопленными (множители суммируются как доли, эффект 1.0+sum;
	# плоские — сложением), как и древо/класс. "" = без боона (тождественность).
	var boon_mods: Dictionary = PROGRESSION_DATA.start_boon_mods(selected_start_boon_id, selected_character_id)
	for boon_key in boon_mods:
		skill_mods[boon_key] = float(skill_mods.get(boon_key, 0.0)) + float(boon_mods[boon_key])
	if player.has_method("apply_meta_skill_modifiers"):
		player.apply_meta_skill_modifiers(skill_mods)
	var start_gold := int(round(float(skill_mods.get("start_gold_flat", 0.0))))
	if start_gold > 0 and player.get("money") != null:
		player.set("money", int(player.get("money")) + start_gold)


func _is_fresh_action_press(event: InputEvent, action: StringName) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.pressed and not key_event.echo and key_event.is_action_pressed(action)
	if event is InputEventJoypadButton:
		var button_event := event as InputEventJoypadButton
		return button_event.pressed and button_event.is_action_pressed(action)
	if event is InputEventJoypadMotion:
		var motion_event := event as InputEventJoypadMotion
		return absf(motion_event.axis_value) > 0.5 and motion_event.is_action_pressed(action)
	if event is InputEventAction:
		var action_event := event as InputEventAction
		return action_event.pressed and action_event.is_action_pressed(action)
	return false


func _input(event: InputEvent) -> void:
	if pending_rebind_action != "":
		ui._handle_rebind_input(event)
		return

	# SCRUM-831: пока дев-консоль открыта, весь ввод принадлежит ей (тоггл/Esc/историю
	# обрабатывает её _input, текст добирает LineEdit на GUI-этапе) — иначе буквы
	# команд дёргали бы хоткеи (P-фидбек, Space-докачка, F12).
	if dev_console != null and dev_console.is_console_open():
		return

	if ui.has_method("_is_feedback_overlay_open") and ui._is_feedback_overlay_open():
		# SCRUM-846: закрытие фидбек-оверлея идет через actions, чтобы Esc/Start/B
		# и возможный joypad-axis rebind работали одним путем.
		var close_feedback: bool = _is_fresh_action_press(event, &"pause") \
			or _is_fresh_action_press(event, &"ui_cancel")
		if close_feedback:
			ui._close_feedback_overlay()
			get_viewport().set_input_as_handled()
		return

	if _is_fresh_action_press(event, &"feedback"):
		var screenshot: Image = null
		if DisplayServer.get_name() != "headless":
			var viewport_texture := get_viewport().get_texture()
			if viewport_texture != null:
				screenshot = viewport_texture.get_image()
		ui._show_feedback_overlay(screenshot)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F12:
		route_debug_free_pick = not route_debug_free_pick
		if ui_layer != null and is_instance_valid(ui_layer) and ui_layer.get_node_or_null("RouteMapScreen") == null:
			pass
		elif not combat_active:
			route._show_battle_map()
		return

	if _handle_debug_combat_move_input(event):
		return

	if _is_fresh_action_press(event, &"open_level_up"):
		if pending_level_ups > 0 and not _has_pause_reason("level_up"):
			ui._open_pending_level_up()
			get_viewport().set_input_as_handled()
			return

	# SCRUM-812: геймпад B (ui_cancel) закрывает/отменяет ТОЛЬКО открытый внутризабеговый
	# экран или паузу-оверлей — паритет с Esc. Вне открытых экранов B не трогаем: он
	# остаётся свободным под геймплей (dodge и т.п., ядро раскладки — SCRUM-811/814).
	# Клавиатурный путь «pause» (Esc) ниже не меняется.
	if not (event is InputEventKey) and event.is_action_pressed("ui_cancel"):
		if ui.has_method("_is_settings_screen_open") and ui._is_settings_screen_open() and ui_escape_action.is_valid():
			ui_escape_action.call()
			get_viewport().set_input_as_handled()
			return
		elif ui.has_method("_is_run_pause_overlay_open") and ui._is_run_pause_overlay_open():
			ui._resume_game()
			get_viewport().set_input_as_handled()
			return
		elif ui_escape_action.is_valid():
			ui_escape_action.call()
			get_viewport().set_input_as_handled()
			return

	# SCRUM-813: LB/RB (плечевые) листают вкладки настроек и секции кодекса — локально
	# по открытому мета-экрану (ui._handle_menu_shoulder_nav). Обрабатывается, только если
	# соответствующий экран открыт, иначе не трогаем (RB=open_level_up в бою — отдельный путь).
	if event is InputEventJoypadButton and event.pressed:
		var shoulder := event as InputEventJoypadButton
		if shoulder.button_index == JOY_BUTTON_LEFT_SHOULDER or shoulder.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			var dir := 1 if shoulder.button_index == JOY_BUTTON_RIGHT_SHOULDER else -1
			if ui.has_method("_handle_menu_shoulder_nav") and ui._handle_menu_shoulder_nav(dir):
				get_viewport().set_input_as_handled()
				return

	if _is_fresh_action_press(event, &"pause"):
		if ui.has_method("_is_settings_screen_open") and ui._is_settings_screen_open() and ui_escape_action.is_valid():
			ui_escape_action.call()
			get_viewport().set_input_as_handled()
		elif ui.has_method("_is_run_pause_overlay_open") and ui._is_run_pause_overlay_open():
			ui._resume_game()
			get_viewport().set_input_as_handled()
		elif ui.has_method("_can_open_pause_dossier") and ui._can_open_pause_dossier():
			ui._show_pause_menu()
			get_viewport().set_input_as_handled()
		elif ui_escape_action.is_valid():
			ui_escape_action.call()
			get_viewport().set_input_as_handled()


func _handle_debug_combat_move_input(event: InputEvent) -> bool:
	if not debug_mode_enabled or not combat_active or get_tree().paused:
		return false
	if current_player == null or not is_instance_valid(current_player):
		return false
	if not (event is InputEventMouseButton):
		return false
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return false
	var is_smooth_move := mouse_event.button_index == MOUSE_BUTTON_RIGHT \
			or (mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.shift_pressed)
	var is_instant_move := mouse_event.button_index == MOUSE_BUTTON_MIDDLE
	if not is_smooth_move and not is_instant_move:
		return false
	var world_position := _screen_position_to_arena_world(mouse_event.position)
	if current_player.has_method("debug_set_move_target"):
		current_player.call("debug_set_move_target", world_position, is_instant_move)
	get_viewport().set_input_as_handled()
	return true


func _screen_position_to_arena_world(screen_position: Vector2) -> Vector2:
	var canvas_transform := get_viewport().get_canvas_transform()
	var world_position := canvas_transform.affine_inverse() * screen_position
	return _clamp_arena_point(world_position)


func _clamp_arena_point(world_position: Vector2, margin := 32.0) -> Vector2:
	return Vector2(
		clampf(world_position.x, margin, ARENA_SIZE.x - margin),
		clampf(world_position.y, margin, ARENA_SIZE.y - margin)
	)


func _process(delta: float) -> void:
	if get_tree().paused:
		return

	if not combat_active:
		return

	# SCRUM-502: суммарное время забега (только в активном бою, не в паузе — оба гарда выше).
	add_run_time(delta)

	# SCRUM-785: таймер тикает во ВСЕХ боях, включая боссовый (5-минутный «убей или проиграл»).
	round_time_left -= delta
	spawn_cooldown -= delta

	if spawn_cooldown <= 0.0:
		spawn_wave_index += 1
		combat._choose_wave_spawn_edges()
		combat._spawn_enemy_wave()
		spawn_cooldown = combat._next_spawn_cooldown()

	combat._update_pickups(delta)
	ui._update_hud()

	# SCRUM-785: условия победы/поражения по типу боя.
	var timer_expired := round_time_left <= 0.0
	if boss_combat_active:
		# Босс: убит — победа после короткой cinematic-задержки, чтобы death row
		# не срезалась мгновенным _clear_world().
		if combat.is_boss_victory_pending():
			ui._update_hud()
			return
		if get_tree().get_nodes_in_group("bosses").is_empty():
			combat.request_boss_victory_after_death()
		elif timer_expired:
			combat._end_combat(false)
	elif current_combat_type == "elite":
		# Элитка: убита — победа (награда гейтится _elite_defeated в _end_combat);
		# таймер вышел с живой элиткой — поражение.
		if combat.is_elite_defeated():
			combat._end_combat(true)
		elif timer_expired:
			combat._end_combat(false)
	elif timer_expired:
		# Обычный бой: выжил до конца таймера = победа.
		combat._end_combat(true)


func push_pause(reason: String) -> void:
	if reason == "":
		return

	pause_reasons[reason] = true
	_freeze_gameplay_state()
	get_tree().paused = true


func pop_pause(reason: String) -> void:
	if reason == "":
		return

	pause_reasons.erase(reason)
	get_tree().paused = not pause_reasons.is_empty()


func _is_gameplay_paused() -> bool:
	return not pause_reasons.is_empty()


func _has_pause_reason(reason: String) -> bool:
	return pause_reasons.has(reason)


func _clear_all_game_pauses() -> void:
	pause_reasons.clear()
	get_tree().paused = false


func _freeze_gameplay_state() -> void:
	_zero_velocity(current_player)
	for group_name in ["enemies", "bosses", "summoned_enemies", "projectiles", "enemy_projectiles", "allies", "pickups", "player_weapons", "player_weapon_effects"]:
		for node in get_tree().get_nodes_in_group(group_name):
			_zero_velocity(node)

	if current_player != null and is_instance_valid(current_player):
		var camera := current_player.get_node_or_null("Camera2D")
		if camera != null and camera.has_method("reset_smoothing"):
			camera.call("reset_smoothing")


func _zero_velocity(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.get("velocity") != null:
		node.set("velocity", Vector2.ZERO)


func _play_sfx(sfx_id: String) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null and audio.has_method("play_sfx"):
		audio.play_sfx(sfx_id)


func _play_music(music_id: String) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null and audio.has_method("play_music"):
		audio.play_music(music_id)


func _cached_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if texture_cache.has(path):
		return texture_cache[path]
	var texture: Texture2D = null
	var can_load_import := not path.ends_with(".png") or _png_import_texture_ready(path)
	if can_load_import and ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	if texture == null and path.ends_with(".png") and FileAccess.file_exists(path):
		var image := Image.new()
		if image.load(path) == OK:
			var image_texture := ImageTexture.create_from_image(image)
			image_texture.resource_path = path
			texture = image_texture
	texture_cache[path] = texture
	return texture


# SCRUM-997: путь фона-иллюстрации события по event.id ("" — арта нет, UI берёт
# общий фолбэк "event"). Словарь-маппинг не дублируется в коде: истина — файлы
# пака SCRUM-998 (EVENT_BACKGROUND_DIR/event_bg_<id>.png), существование
# проверяется через ResourceLoader (работает и в экспортированном .pck).
func event_background_path(event_id: String) -> String:
	if event_id.strip_edges() == "":
		return ""
	var path := "%s/event_bg_%s.png" % [EVENT_BACKGROUND_DIR, event_id]
	if ResourceLoader.exists(path) or FileAccess.file_exists(path):
		return path
	return ""


func _png_import_texture_ready(path: String) -> bool:
	var import_path := "%s.import" % path
	if not FileAccess.file_exists(import_path):
		return false
	var import_file := FileAccess.open(import_path, FileAccess.READ)
	if import_file == null:
		return false
	var import_text := import_file.get_as_text()
	import_file.close()
	var cursor := 0
	var found_imported_texture := false
	while true:
		var start := import_text.find("res://.godot/imported/", cursor)
		if start == -1:
			break
		var end := import_text.find(".ctex", start)
		if end == -1:
			break
		end += 5
		found_imported_texture = true
		var imported_path := import_text.substr(start, end - start)
		if not FileAccess.file_exists(imported_path):
			return false
		cursor = end
	return found_imported_texture


func _clear_world() -> void:
	for group_name in ["enemies", "bosses", "summoned_enemies", "projectiles", "enemy_projectiles", "enemy_hazards", "allies", "pickups", "player_weapons", "player_weapon_effects", "level_up_effects", "arena_obstacles", "arena_backgrounds"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(node):
				node.queue_free()

	for child in get_children():
		if child == ui_layer or child == hud_layer:
			continue
		if child == current_player:
			child.queue_free()

	current_player = null


func _clear_ui() -> void:
	ui_escape_action = Callable()
	if pause_overlay_layer != null and is_instance_valid(pause_overlay_layer):
		pause_overlay_layer.queue_free()
	pause_overlay_layer = null
	pause_stats_menu = null
	if ui_layer != null and is_instance_valid(ui_layer):
		ui_layer.queue_free()
	ui_layer = null


func _clear_hud() -> void:
	if hud_layer != null and is_instance_valid(hud_layer):
		hud_layer.queue_free()
	hud_layer = null
	timer_label = null
	status_label = null
	health_bar = null
	health_label = null
	xp_bar = null
	xp_label = null
	money_label = null
	artifact_label = null
	level_up_button = null
	boss_hud_bar = null
	boss_hud_name_label = null
	_last_hud_snapshot.clear()


# --- Делегирующие стабы для smoke-тестов и внешних вызовов ---


func _active_enemy_cap() -> int:
	return combat._active_enemy_cap()


func _apply_event_choice(event_choice: Dictionary) -> void:
	ui._apply_event_choice(event_choice)


func _apply_reward_to_run(reward: Dictionary) -> void:
	ui._apply_reward_to_run(reward)


func _apply_video_settings() -> void:
	ui._apply_video_settings()


func _buy_shop_item_at(index: int) -> bool:
	return ui._buy_shop_item_at(index)


func _choose_wave_spawn_edges() -> void:
	combat._choose_wave_spawn_edges()


func _current_round_duration() -> float:
	return combat._current_round_duration()


func _generate_route() -> Array:
	return route._generate_route()


func _handle_route_node_input(button: Button, event: InputEvent, scroll: ScrollContainer, step_index: int, branch_index: int, route_node: Dictionary) -> void:
	route._handle_route_node_input(button, event, scroll, step_index, branch_index, route_node)


func _map_node_definition(node_type: String) -> Dictionary:
	return route._map_node_definition(node_type)


func _open_pending_level_up() -> void:
	ui._open_pending_level_up()


func _open_route_node(route_node: Dictionary) -> void:
	route._open_route_node(route_node)


func _random_edge_spawn_position() -> Vector2:
	return combat._random_edge_spawn_position()


func _random_spawn_position() -> Vector2:
	return combat._random_spawn_position()


func _run_money() -> int:
	return ui._run_money()


func _route_node_icon_path(route_node: Dictionary, definition: Dictionary) -> String:
	return route._route_node_icon_path(route_node, definition)


func _show_battle_map() -> void:
	route._show_battle_map()


func _show_character_select() -> void:
	# SCRUM-618: новый забег начинается без боона — выбор будет сделан в пикере после
	# выбора оружия. Сброс защищает от переноса боона из прошлого/прерванного забега.
	selected_start_boon_id = ""
	ui._show_character_select()


func _show_rest_screen() -> void:
	ui._show_rest_screen()


func _show_settings_menu() -> void:
	ui._show_settings_menu()


func _show_shop_screen() -> void:
	ui._show_shop_screen()


func _show_upgrade_screen() -> void:
	ui._show_upgrade_screen()


func _show_weapon_select() -> void:
	ui._show_weapon_select()


func _spawn_pickup(pickup_type: String, amount: int, position: Vector2) -> void:
	combat._spawn_pickup(pickup_type, amount, position)


func _spawn_weight_for_scene(scene: PackedScene) -> float:
	return combat._spawn_weight_for_scene(scene)


func _start_combat(is_boss_fight := false, combat_type := "battle") -> void:
	combat._start_combat(is_boss_fight, combat_type)


func _store_player_snapshot(player: Node) -> void:
	combat._store_player_snapshot(player)
