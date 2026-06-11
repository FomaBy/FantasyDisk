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

const BASE_ROUND_DURATION := 30.0
const ROUND_DURATION_STEP := 3.0
const ROUND_DURATION_MAX := 60.0
const ROUTE_STEPS_TO_BOSS := 10
const MIN_BRANCHES_PER_STEP := 2
const MAX_BRANCHES_PER_STEP := 4
const MAP_NODE_SIZE := Vector2(88, 88)
const ROUTE_MAP_PADDING := Vector2(170, 72)
const ROUTE_MAP_HEADER_HEIGHT := 118.0
const ROUTE_MAP_SCREEN_MARGIN := 28.0
const ROUTE_MAP_DRAG_THRESHOLD := 8.0
const ARENA_SIZE := Vector2(2560, 1440)
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
	],
	"battle": [
		"res://assets/backgrounds/field_marsh.png",
		"res://assets/backgrounds/field_dry_road.png",
		"res://assets/backgrounds/field_meadow.png",
	],
	"boss": [
		"res://assets/backgrounds/field_stone_garden.png",
		"res://assets/backgrounds/field_dry_road.png",
	],
}
const MAIN_MENU_BACKGROUND := "res://assets/backgrounds/main_menu_epic_battle.png"
const SCREEN_BACKGROUND_PATHS := {
	"event": "res://assets/sprites/ui/screens/screen_event_background.png",
	"shop": "res://assets/sprites/ui/screens/screen_shop_background.png",
	"campfire": "res://assets/sprites/ui/screens/screen_campfire_background.png",
}
const GAME_CURSOR_PATH := "res://assets/sprites/ui/cursor/game_cursor.png"
const GAME_CURSOR_HOTSPOT := Vector2(5, 4)
const SCREEN_BACKGROUND_FALLBACK_COLORS := {
	"event": Color(0.055, 0.045, 0.105, 1.0),
	"shop": Color(0.070, 0.052, 0.030, 1.0),
	"campfire": Color(0.080, 0.045, 0.025, 1.0),
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
	"rest": {
		"name": "Костер",
		"icon": "REST",
		"icon_path": "res://assets/sprites/map_icons/map_rest_campfire.png",
		"tooltip": "Костер\nОтдых. Можно восстановить здоровье или получить защитный бонус.",
		"color": Color(0.28, 0.18, 0.09, 0.96),
		"border": Color(1.0, 0.60, 0.22, 1.0),
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
const SPAWN_PLAYER_SAFE_RADIUS := 340.0
const SMALL_PACK_CHANCE := 0.22
const WAVE_SETTINGS := {
	"base_spawn_count": 2,
	"spawn_count_per_stage": 1,
	"spawn_count_per_wave_step": 1,
	"wave_step_size": 3,
	"normal_spawn_limit": 5,
	"elite_spawn_limit": 3,
	"boss_spawn_limit": 3,
	"base_active_cap": 14,
	"active_cap_per_stage": 5,
	"active_cap_per_wave_step": 2,
	"elite_active_cap": 12,
	"boss_active_cap": 12,
	"max_active_cap": 30,
	"spawn_pause_min": 1.35,
	"spawn_pause_max": 2.15,
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
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const WINDOW_MODE_OPTIONS := [
	"Windowed",
	"Borderless Window",
	"Fullscreen",
]
const PROGRESSION_DATA := preload("res://scripts/progression_data.gd")
const PAUSE_STATS_MENU_SCENE := preload("res://scenes/PauseStatsMenu.tscn")
const LEVEL_UP_TOAST_SCENE := preload("res://scenes/LevelUpToast.tscn")
const LEVEL_UP_EFFECT_SCENE := preload("res://scenes/LevelUpEffect.tscn")
const UIIconRegistry := preload("res://scripts/ui_icon_registry.gd")
const LEVEL_UP_MOD_DISPLAY := {
	"damage_multiplier": "damage",
	"attack_speed_multiplier": "attack_speed",
	"max_health_flat": "health_point",
	"move_speed_multiplier": "move_speed",
	"aoe_radius_multiplier": "aoe_radius",
	"pickup_radius_flat": "pickup_radius",
	"defense_flat": "defense",
	"range_multiplier": "attack_range",
	"crit_chance_flat": "crit_chance",
	"crit_damage_flat": "crit_damage_multiplier",
	"knockback_multiplier": "knockback_power",
}
const INPUT_ACTIONS := [
	{
		"action": "move_up",
		"label": "Move Up",
		"default_key": KEY_W,
		"alternate_key": KEY_UP,
	},
	{
		"action": "move_down",
		"label": "Move Down",
		"default_key": KEY_S,
		"alternate_key": KEY_DOWN,
	},
	{
		"action": "move_left",
		"label": "Move Left",
		"default_key": KEY_A,
		"alternate_key": KEY_LEFT,
	},
	{
		"action": "move_right",
		"label": "Move Right",
		"default_key": KEY_D,
		"alternate_key": KEY_RIGHT,
	},
]

var selected_character_id := "berserk"
var selected_weapon_id := "sword"
var route_stage := 0
var combat_active := false
var boss_combat_active := false
var round_time_left := 0.0
var spawn_cooldown := 0.0
var current_player: Node2D = null
var run_player_snapshot := {}
var ui_layer: CanvasLayer = null
var hud_layer: CanvasLayer = null
var timer_label: Label = null
var status_label: Label = null
var health_bar: ProgressBar = null
var health_label: Label = null
var xp_bar: ProgressBar = null
var xp_label: Label = null
var money_label: Label = null
var artifact_label: Label = null
var level_up_button: Button = null
var pause_stats_menu: Control = null
var route_nodes := []
var current_route_choice := ""
var current_node_type := ""
var current_combat_type := "battle"
var current_boss_id := "rift_warden"
var route_selected_indices := []
var level_up_return_to_map := false
var meta_points := 0
var berserk_ascension_unlocked := false
var spawn_wave_index := 0
var active_spawn_edges := []
var selected_resolution_index := 1
var selected_window_mode_index := 0
var pending_rebind_action := ""
var current_shop_items := []
var current_shop_purchased := []
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

var ui
var route
var combat
var meta_state := {}


func _init() -> void:
	ui = UI_SCREENS_SCRIPT.new(self)
	route = ROUTE_MAP_SCRIPT.new(self)
	combat = COMBAT_DIRECTOR_SCRIPT.new(self)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	_load_meta_progression()
	ui._setup_default_input_actions()
	ui._apply_game_cursor()
	ui._show_main_menu()


func _load_meta_progression() -> void:
	meta_state = META_PROGRESSION.load_state()
	meta_points = int(meta_state.get("meta_points", 0))
	berserk_ascension_unlocked = ascension_level_for("berserk") >= 1


func ascension_level_for(character_id: String) -> int:
	return META_PROGRESSION.ascension_level(meta_state, character_id)


func record_boss_victory() -> void:
	meta_state = META_PROGRESSION.record_boss_victory(meta_state, selected_character_id)
	META_PROGRESSION.save_state(meta_state)
	meta_points = int(meta_state.get("meta_points", 0))
	berserk_ascension_unlocked = ascension_level_for("berserk") >= 1


func apply_ascension_bonuses(player: Node) -> void:
	if player == null:
		return
	var level := ascension_level_for(selected_character_id)
	if level <= 0:
		return
	var mods: Dictionary = PROGRESSION_DATA.ascension_mods(selected_character_id, level)
	if mods.is_empty():
		return
	if player.has_method("apply_reward"):
		player.apply_reward({"mods": mods})


func _input(event: InputEvent) -> void:
	if pending_rebind_action != "":
		ui._handle_rebind_input(event)
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F12:
		route_debug_free_pick = not route_debug_free_pick
		if ui_layer != null and is_instance_valid(ui_layer) and ui_layer.get_node_or_null("RouteMapScreen") == null:
			pass
		elif not combat_active:
			route._show_battle_map()
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if combat_active:
			if _has_pause_reason("level_up"):
				return
			if pause_stats_menu != null and is_instance_valid(pause_stats_menu):
				ui._resume_game()
			elif not _has_pause_reason("escape_menu"):
				ui._show_pause_menu()


func _process(delta: float) -> void:
	if get_tree().paused:
		return

	if not combat_active:
		return

	if not boss_combat_active:
		round_time_left -= delta
	spawn_cooldown -= delta

	if spawn_cooldown <= 0.0:
		spawn_wave_index += 1
		combat._choose_wave_spawn_edges()
		combat._spawn_enemy_wave()
		spawn_cooldown = combat._next_spawn_cooldown()

	combat._update_pickups(delta)
	ui._update_hud()

	if boss_combat_active and get_tree().get_nodes_in_group("bosses").is_empty():
		combat._end_combat(true)
	elif not boss_combat_active and round_time_left <= 0.0:
		combat._end_combat(true)


func set_game_paused(reason: String, should_pause: bool) -> void:
	if should_pause:
		push_pause(reason)
	else:
		pop_pause(reason)


func set_gameplay_paused(should_pause: bool, reason := "") -> void:
	set_game_paused(reason, should_pause)


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


func is_gameplay_paused() -> bool:
	return _is_gameplay_paused()


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
	if not ResourceLoader.exists(path):
		texture_cache[path] = null
		return null
	var texture := load(path) as Texture2D
	texture_cache[path] = texture
	return texture


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
	if ui_layer != null and is_instance_valid(ui_layer):
		ui_layer.queue_free()
	ui_layer = null
	pause_stats_menu = null


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


func _route_node_icon_path(route_node: Dictionary, definition: Dictionary) -> String:
	return route._route_node_icon_path(route_node, definition)


func _show_battle_map() -> void:
	route._show_battle_map()


func _show_character_select() -> void:
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
