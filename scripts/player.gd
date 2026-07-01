extends CharacterBody2D

signal died
signal leveled_up
signal damaged(amount: float)
signal weapon_animation_event(event: Dictionary)

@export var max_health := 10.0
@export var speed := 260.0
@export var damage_invulnerability_time := 0.32

const BERSERK_SPRITE := preload("res://assets/sprites/characters/berserk_unarmed.png")
const BERSERK_ANIMATED_SPRITE := preload("res://assets/sprites/characters/berserk_walk_sheet_v2.png")
const ProgressionData := preload("res://scripts/progression_data.gd")
const TARGET_QUERY := preload("res://scripts/combat_target_query.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")
const DARK_MAGE_SKELETON_RIG_SCENE := preload("res://scenes/characters/DarkMageSkeletonRig.tscn")
const KNIGHT_SKELETON_RIG_SCENE := preload("res://scenes/characters/KnightSkeletonRig.tscn")
const DARK_MAGE_SPRITE := preload("res://assets/sprites/characters/dark_mage.png")
const GUITARIST_SPRITE := preload("res://assets/sprites/characters/guitarist.png")
const ASSASSIN_SPRITE := preload("res://assets/sprites/characters/assassin.png")
const RANGER_SPRITE := preload("res://assets/sprites/characters/ranger.png")
const DOCTOR_SPRITE := preload("res://assets/sprites/characters/doctor.png")
const CHEMIST_SPRITE := preload("res://assets/sprites/characters/chemist.png")
const KNIGHT_SPRITE := preload("res://assets/sprites/characters/knight.png")
const ROBOT_SPRITE := preload("res://assets/sprites/characters/robot.png")
const DRUID_SPRITE := preload("res://assets/sprites/characters/druid.png")
const PROGRESSION_DATA := preload("res://scripts/progression_data.gd")
const CUTOUT_RIG_SCRIPT := preload("res://scripts/cutout_rig_2d.gd")
const ALLY_MINION_SCENE := preload("res://scenes/AllyMinion.tscn")
const BERSERK_ANIMATION_FRAME_SIZE := Vector2i(384, 384)
const CHARACTER_SHEET_FRAME_SIZE := Vector2i(384, 384)
const CHARACTER_SHEET_COLUMNS := 5
const DIRECTIONAL_ANIMATION_SUFFIXES := ["east", "south_east", "south", "south_west", "west", "north_west", "north", "north_east"]
# SCRUM-595: потолок суммарного absorb_flat от оверхил-ульты Доктора за забег,
# как доля от max_health (раньше копился безгранично → пауэр-крип/эксплойт).
const DOCTOR_ULT_ABSORB_CAP_FRACTION := 0.5
const PLAYER_COMBAT_VISUAL_SCALE := 0.425  # SCRUM-518: −15% от 0.5 (тело меньше на просторной арене)
const BASE_SPRITE_SCALE := Vector2(PLAYER_COMBAT_VISUAL_SCALE, PLAYER_COMBAT_VISUAL_SCALE)
# Анимация атаки персонажей отключена по запросу пользователя (2026-06-15).
const USE_ATTACK_ANIMATION := false
# CARTOON-проба (SCRUM-456/SCRUM-472) завершена для Dark Mage/Knight в SCRUM-473:
# эти классы теперь грузят реальные full-frame SpriteFrames, а список остаётся
# пустым как аварийный переключатель для будущих временных cartoon-интеграций.
const CARTOON_TRIAL_CLASSES := []
# Доводка cartoon-пробы (SCRUM-472, запрос пользователя): чуть мельче + лёгкий
# разворот спрайта вокруг своей оси (Z), чтобы не стоял строго анфас. Настраивается.
const CARTOON_TRIAL_SCALE := 0.82
const CARTOON_TRIAL_TILT_DEG := 12.0
const WEAPON_ORBIT_RADIUS := 104.0
const WEAPON_ORBIT_VERTICAL_BIAS := -8.0
const WEAPON_ORBIT_Z_INDEX := -8
# SCRUM-515: держимый (orbit) спрайт оружия не показываем в бою. Скрываем ТОЛЬКО
# рендер корня оружия (visible=false) — узел/группа player_weapons/текстура
# WeaponVisual остаются (нужны для снарядов/ловушек/орбов через
# class_weapon._weapon_visual_texture()). Снаряды/VFX/хазарды/саммоны парентятся
# к current_scene (class_weapon._projectile_parent()), не к оружию, поэтому не
# гаснут. Переинстанс при смене оружия снова применит скрытие через
# _configure_attached_weapon_layer. Флаг (+ root-meta override для тестов/превью)
# даёт единую точку вернуть визуал обратно вне боя/для отладки.
const SHOW_HELD_WEAPON_VISUAL := false
const DEBUG_MOVE_ARRIVAL_DISTANCE := 10.0
const COMBAT_FEEDBACK_LABEL_GROUP := "combat_feedback_labels"
const COMBAT_FEEDBACK_MAX_LABELS := 42

const CHARACTER_CONFIGS := {
	"berserk": {
		"display_name": "Берсерк",
		"color": Color(0.33, 0.65, 1.0, 1.0),
		"max_health": 88.0,
		"speed": 235.0,
		"sprite": BERSERK_SPRITE,
	},
	"dark_mage": {
		"display_name": "Темный маг",
		"color": Color(0.55, 0.33, 1.0, 1.0),
		"max_health": 42.0,
		"speed": 250.0,
		"sprite": DARK_MAGE_SPRITE,
	},
	"guitarist": {
		"display_name": "Гитарист",
		"color": Color(1.0, 0.72, 0.20, 1.0),
		"max_health": 60.0,
		"speed": 268.0,
		"sprite": GUITARIST_SPRITE,
	},
	"assassin": {"display_name": "Ассасин", "color": Color(0.66, 0.30, 0.95, 1.0), "max_health": 52.0, "speed": 285.0, "sprite": ASSASSIN_SPRITE},
	"thief": {"display_name": "Вор", "color": Color(0.92, 0.68, 0.30, 1.0), "max_health": 56.0, "speed": 292.0, "sprite": ASSASSIN_SPRITE},
	"elementalist": {"display_name": "Элементалист", "color": Color(0.30, 0.82, 1.0, 1.0), "max_health": 48.0, "speed": 258.0, "sprite": DARK_MAGE_SPRITE},
	"sniper": {"display_name": "Снайпер", "color": Color(0.82, 0.88, 1.0, 1.0), "max_health": 62.0, "speed": 252.0, "sprite": RANGER_SPRITE},
	"priest": {"display_name": "Священник", "color": Color(1.0, 0.90, 0.54, 1.0), "max_health": 66.0, "speed": 246.0, "sprite": DOCTOR_SPRITE},
	"biologist": {"display_name": "Биолог", "color": Color(0.48, 0.95, 0.42, 1.0), "max_health": 54.0, "speed": 254.0, "sprite": CHEMIST_SPRITE},
	"robot": {"display_name": "Робот", "color": Color(0.42, 0.82, 1.0, 1.0), "max_health": 98.0, "speed": 222.0, "sprite": ROBOT_SPRITE},
	"engineer": {"display_name": "Инженер", "color": Color(0.86, 0.70, 0.32, 1.0), "max_health": 70.0, "speed": 246.0, "sprite": DRUID_SPRITE},
	"ranger": {"display_name": "Рейнджер", "color": Color(0.40, 0.78, 0.42, 1.0), "max_health": 58.0, "speed": 262.0, "sprite": RANGER_SPRITE},
	"doctor": {"display_name": "Доктор", "color": Color(0.92, 0.94, 0.98, 1.0), "max_health": 64.0, "speed": 248.0, "sprite": DOCTOR_SPRITE},
	"chemist": {"display_name": "Химик", "color": Color(0.70, 0.95, 0.25, 1.0), "max_health": 50.0, "speed": 252.0, "sprite": CHEMIST_SPRITE},
	"knight": {"display_name": "Рыцарь", "color": Color(0.62, 0.70, 0.85, 1.0), "max_health": 95.0, "speed": 225.0, "sprite": KNIGHT_SPRITE},
	"druid": {"display_name": "Друид", "color": Color(0.52, 0.72, 0.34, 1.0), "max_health": 66.0, "speed": 255.0, "sprite": DRUID_SPRITE},
}

var health := 0.0
var character_id := "berserk"
var weapon_id := ""
var weapon_config := {}
var aim_mode := "nearest"
var last_weapon_animation_event: Dictionary = {}
var equipped_weapon: Node = null
var stats := {}
var run_modifiers := _default_run_modifiers()
var artifacts := []
var derived_parameters := {}
var xp := 0
var xp_to_next := 5
var level := 1
var money := 0
var pickup_radius := 115.0
var _animation_time := 0.0
var _movement_offset := Vector2.ZERO
var _movement_rotation := 0.0
var _movement_scale_delta := Vector2.ZERO
var _action_offset := Vector2.ZERO
var _action_rotation := 0.0
var _action_scale := Vector2.ONE
var _body_action_time_left := 0.0
var _action_tween: Tween = null
var _hit_flash_tween: Tween = null
var _facing_direction := Vector2.RIGHT
var _uses_full_frame_visual := false
var _uses_skeletal_visual := false
var _damage_invulnerability_left := 0.0
# Паутинное замедление (Матерь Роя): фактор скорости до отметки времени.
var _web_slow_until := 0.0
var _web_slow_factor := 1.0
var _echo_hit_counter := 0
var _leadership_echo_hit_counter := 0
var _dodge_rush_tween: Tween = null
var _low_hp_active := false
# SCRUM-500: триггерные артефакты — латчи/кулдауны/счётчики (не часть run_modifiers,
# поэтому сбрасываются явно в configure_character и при run-start).
var _crit_burst_tween: Tween = null      # «Импульс Крита»: tween снятия бафа скорости
var _lowhp_guard_used := false           # «Рубеж Стража»: латч одноразового щита за порог
var _lowhp_guard_cooldown_left := 0.0    # перезаряд щита (раз в N сек)
var _take_hit_pulse_cooldown_left := 0.0 # «Контр-волна»: перезаряд отталкивающей волны
var _kill_streak_counter := 0            # «Сбор Душ»: счётчик убийств до лечения
var _doctor_ult_absorb_total := 0.0      # SCRUM-595: суммарный absorb от ульты Доктора за забег (капится)
var _assassin_crit_shadow_cooldown_left := 0.0
var _knight_counter_cooldown_left := 0.0
var _battle_shout_cooldown_left := 0.0
var _status_aura_cooldown_left := 0.0
var _vampiric_heal_budget := 0.0
# SCRUM-517: per-second бюджет для DRAIN-heal оружия (drain_link/lifesteal). Раньше
# drain лился в health без потолка/с → Доктор был бессмертен. Теперь оружие зовёт
# apply_drain_heal(), который списывает из этого бюджета (пополняется в
# _apply_regeneration по тому же принципу, что вампирный).
var _drain_heal_budget := 0.0
var ultimate_charge := 0.0
var ultimate_max_charge := 100.0
var _ultimate_active := false
var _ultimate_tween: Tween = null
var _debug_move_target_active := false
var _debug_move_target := Vector2.ZERO


# SCRUM-709: единый источник дефолтных run_modifiers. Раньше тот же 22-ключевой
# литерал дублировался дословно в инициализаторе var и в configure_character — при
# добавлении ключа в одно место второе тихо отставало (drift-баг по модификаторам).
static func _default_run_modifiers() -> Dictionary:
	return {
		"damage_multiplier": 1.0,
		"attack_speed_multiplier": 1.0,
		"range_multiplier": 1.0,
		"aoe_radius_multiplier": 1.0,
		"move_speed_multiplier": 1.0,
		"max_health_multiplier": 1.0,
		"summon_bonus": 0.0,
		"damage_flat": 0.0,
		"max_health_flat": 0.0,
		"pickup_radius_flat": 0.0,
		"defense_flat": 0.0,
		"crit_chance_flat": 0.0,
		"crit_damage_flat": 0.0,
		"dodge_flat": 0.0,
		"xp_gain_multiplier": 1.0,
		"money_gain_multiplier": 1.0,
		"healing_multiplier": 1.0,
		"vampiric_heal_per_second_cap": ProgressionData.VAMPIRIC_HEAL_CAP_DEFAULT,
		"drain_heal_per_second_cap": ProgressionData.BalanceData.DRAIN_HEAL_PER_SECOND_CAP_DEFAULT,
		"enemy_health_multiplier": 1.0,
		"knockback_multiplier": 1.0,
	}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_ensure_default_input_actions()
	if stats.is_empty():
		configure_character(character_id)


func configure_character(new_character_id: String, new_weapon_id := "") -> void:
	character_id = new_character_id
	weapon_id = ""
	weapon_config = {}
	var config: Dictionary = CHARACTER_CONFIGS.get(character_id, CHARACTER_CONFIGS["berserk"])

	stats = PROGRESSION_DATA.base_stats(character_id)
	artifacts.clear()
	run_modifiers = _default_run_modifiers()
	xp = 0
	xp_to_next = 5
	level = 1
	money = 0
	ultimate_charge = 0.0
	_ultimate_active = false
	# SCRUM-500: сброс триггер-латчей при смене персонажа/старте забега (run_modifiers
	# уже пересоздан выше, флаги артефактов исчезли; здесь добиваем non-run_modifiers латчи).
	_low_hp_active = false
	_lowhp_guard_used = false
	_lowhp_guard_cooldown_left = 0.0
	_take_hit_pulse_cooldown_left = 0.0
	_kill_streak_counter = 0
	_doctor_ult_absorb_total = 0.0  # SCRUM-595: сброс накопленного доктор-щита при смене персонажа/старте забега
	if _crit_burst_tween != null and _crit_burst_tween.is_valid():
		_crit_burst_tween.kill()
	_crit_burst_tween = null
	_apply_stat_scaling(true)

	var visual_root := _visual_root()
	if visual_root != null:
		visual_root.position = Vector2.ZERO
		visual_root.rotation = 0.0
		visual_root.scale = Vector2.ONE
	var body := _animated_sprite()
	if body != null:
		var skeleton_scene := _character_skeleton_rig_scene(character_id)
		_uses_skeletal_visual = skeleton_scene != null
		var full_frame_frames: SpriteFrames = null if character_id in CARTOON_TRIAL_CLASSES or _uses_skeletal_visual else _character_full_frame_sprite_frames(character_id)
		_uses_full_frame_visual = full_frame_frames != null
		body.sprite_frames = full_frame_frames if _uses_full_frame_visual else _character_sprite_frames(config)
		body.animation = "idle"
		body.play("idle")
		body.position = Vector2.ZERO
		body.rotation = 0.0
		body.scale = BASE_SPRITE_SCALE
		body.flip_h = false
		body.visible = _uses_full_frame_visual
		_configure_skeletal_player_rig(skeleton_scene)
	_configure_player_rig(config, not _uses_full_frame_visual and not _uses_skeletal_visual)
	var weapon_socket := _weapon_socket()
	if weapon_socket != null:
		weapon_socket.position = Vector2.ZERO
		weapon_socket.rotation = 0.0
		weapon_socket.scale = Vector2.ONE

	_movement_offset = Vector2.ZERO
	_movement_rotation = 0.0
	_movement_scale_delta = Vector2.ZERO
	_action_offset = Vector2.ZERO
	_action_rotation = 0.0
	_action_scale = Vector2.ONE
	_facing_direction = Vector2.RIGHT
	if is_inside_tree():
		set_aim_mode(str(get_tree().root.get_meta("aim_mode", aim_mode)))

	_clear_equipped_weapon()
	if new_weapon_id != "":
		equip_weapon(new_weapon_id)


func configure_berserk_subclass(subclass_id: String) -> void:
	equip_weapon(subclass_id)


func equip_weapon(new_weapon_id: String) -> void:
	var config := PROGRESSION_DATA.weapon(character_id, new_weapon_id)
	var weapon_scene := load(str(config.get("scene_path", ""))) as PackedScene
	if weapon_scene == null:
		return

	weapon_id = str(config["id"])
	weapon_config = config
	var old_max_health := max_health
	_apply_stat_scaling(false, old_max_health)
	_attach_weapon_scene(weapon_scene, weapon_config)


func _attach_weapon_scene(weapon_scene: PackedScene, config: Dictionary) -> void:
	_clear_equipped_weapon()
	var socket := _weapon_socket()
	var weapon := weapon_scene.instantiate()
	weapon.add_to_group("player_weapons")
	socket.add_child(weapon)
	equipped_weapon = weapon
	_configure_attached_weapon_layer(weapon)
	if weapon.has_method("configure_weapon") and not config.is_empty():
		weapon.configure_weapon(config)
	_apply_weapon_scaling(weapon)


func _clear_equipped_weapon() -> void:
	equipped_weapon = null
	var had_weapon := false
	for weapon in _equipped_weapons():
		var weapon_node := weapon as Node
		if weapon_node == null:
			continue
		had_weapon = true
		if weapon_node.has_method("cleanup_effects"):
			weapon_node.cleanup_effects()
		if weapon_node.get_parent() != null:
			weapon_node.get_parent().remove_child(weapon_node)
		weapon_node.queue_free()
	_clear_detached_weapon_effects()
	if had_weapon:
		call_deferred("_clear_detached_weapon_effects")


func _clear_detached_weapon_effects() -> void:
	if not is_inside_tree():
		return
	for effect in get_tree().get_nodes_in_group("player_weapon_effects"):
		if effect != null and is_instance_valid(effect):
			effect.remove_from_group("player_weapon_effects")
			effect.queue_free()


func _weapon_socket() -> Node2D:
	var socket := get_node_or_null("VisualRoot/WeaponSocket") as Node2D
	if socket != null:
		_configure_weapon_socket_layer(socket)
		return socket
	socket = get_node_or_null("WeaponSocket") as Node2D
	if socket != null:
		_configure_weapon_socket_layer(socket)
		return socket
	var visual_root := _visual_root()
	if visual_root == null:
		visual_root = Node2D.new()
		visual_root.name = "VisualRoot"
		add_child(visual_root)
	socket = Node2D.new()
	socket.name = "WeaponSocket"
	visual_root.add_child(socket)
	_configure_weapon_socket_layer(socket)
	return socket


func _configure_weapon_socket_layer(socket: Node2D) -> void:
	socket.z_as_relative = true
	socket.z_index = WEAPON_ORBIT_Z_INDEX
	socket.set_meta("weapon_orbit_radius", WEAPON_ORBIT_RADIUS)


func _configure_attached_weapon_layer(weapon: Node) -> void:
	var weapon_canvas := weapon as CanvasItem
	if weapon_canvas != null:
		weapon_canvas.z_as_relative = true
		weapon_canvas.z_index = 0
	var visual := weapon.get_node_or_null("WeaponVisual") as CanvasItem
	if visual != null:
		visual.z_as_relative = true
		visual.z_index = 0
	# SCRUM-515: скрыть держимый визуал оружия (рендер корня + WeaponVisual), не
	# трогая узел/текстуру. Override через root-meta «show_held_weapon» (как aim_mode)
	# позволяет тестам/превью вернуть визуал без правки кода. Механика оружия
	# (_process/_attack/cooldown) от visible не зависит — урон/паттерн не меняются.
	# get_tree() может быть null, если оружие цепляется до входа игрока в дерево —
	# тогда берём дефолт-константу (override применится при следующем re-attach в дереве).
	var show_weapon := SHOW_HELD_WEAPON_VISUAL
	if is_inside_tree() and get_tree().root != null:
		var tree := get_tree()
		show_weapon = bool(tree.root.get_meta("show_held_weapon", SHOW_HELD_WEAPON_VISUAL))
	if weapon_canvas != null:
		weapon_canvas.visible = show_weapon
	if visual != null:
		visual.visible = show_weapon


func _physics_process(_delta: float) -> void:
	StatusEffects.tick(self, _delta)
	_damage_invulnerability_left = max(_damage_invulnerability_left - _delta, 0.0)
	_assassin_crit_shadow_cooldown_left = max(_assassin_crit_shadow_cooldown_left - _delta, 0.0)
	_knight_counter_cooldown_left = max(_knight_counter_cooldown_left - _delta, 0.0)
	_battle_shout_cooldown_left = max(_battle_shout_cooldown_left - _delta, 0.0)
	_status_aura_cooldown_left = max(_status_aura_cooldown_left - _delta, 0.0)
	# SCRUM-500: триггер-кулдауны (Рубеж Стража / Контр-волна).
	_lowhp_guard_cooldown_left = max(_lowhp_guard_cooldown_left - _delta, 0.0)
	_take_hit_pulse_cooldown_left = max(_take_hit_pulse_cooldown_left - _delta, 0.0)
	var direction := Vector2.ZERO

	if Input.is_action_pressed("move_left"):
		direction.x -= 1.0
	if Input.is_action_pressed("move_right"):
		direction.x += 1.0
	if Input.is_action_pressed("move_up"):
		direction.y -= 1.0
	if Input.is_action_pressed("move_down"):
		direction.y += 1.0
	var manual_direction := direction
	if InputMap.has_action("ultimate") and Input.is_action_just_pressed("ultimate"):
		activate_ultimate()

	var web_factor := 1.0
	if _web_slow_until > Time.get_ticks_msec() / 1000.0:
		web_factor = _web_slow_factor
	var speed_factor := speed * web_factor * StatusEffects.speed_multiplier(self)
	if manual_direction.length_squared() > 0.0:
		_clear_debug_move_target()
	elif _debug_move_target_active:
		var to_target := _debug_move_target - global_position
		if to_target.length() <= DEBUG_MOVE_ARRIVAL_DISTANCE:
			global_position = _debug_move_target
			_clear_debug_move_target()
		else:
			direction = to_target.normalized()
	velocity = direction.normalized() * speed_factor
	if _debug_move_target_active and manual_direction.length_squared() <= 0.0:
		var remaining := _debug_move_target - global_position
		var max_step := velocity.length() * _delta
		if remaining.length() <= maxf(DEBUG_MOVE_ARRIVAL_DISTANCE, max_step):
			global_position = _debug_move_target
			velocity = Vector2.ZERO
			_clear_debug_move_target()
		else:
			move_and_slide()
	else:
		move_and_slide()
	_update_movement_animation(_delta)
	_update_low_hp_state()
	_apply_regeneration(_delta)
	_update_battle_shout()
	_update_class_status_auras()


func debug_set_move_target(world_position: Vector2, instant := false) -> void:
	if instant:
		global_position = world_position
		velocity = Vector2.ZERO
		_clear_debug_move_target()
		return
	_debug_move_target = world_position
	_debug_move_target_active = true


func debug_has_move_target() -> bool:
	return _debug_move_target_active


func debug_move_target_position() -> Vector2:
	return _debug_move_target


func _clear_debug_move_target() -> void:
	_debug_move_target_active = false
	_debug_move_target = Vector2.ZERO


func set_aim_mode(mode: String) -> void:
	aim_mode = "cursor" if mode == "cursor" else "nearest"


func attack_aim_mode() -> String:
	if is_inside_tree():
		set_aim_mode(str(get_tree().root.get_meta("aim_mode", aim_mode)))
	return aim_mode


func attack_aim_position(range_limit := 999999.0) -> Vector2:
	var cursor_position := get_global_mouse_position()
	var offset := cursor_position - global_position
	if range_limit >= 999998.0 or offset.length() <= range_limit:
		return cursor_position
	if offset.length_squared() <= 0.001:
		return global_position + _facing_direction * range_limit
	return global_position + offset.normalized() * range_limit


func attack_aim_direction(default_direction := Vector2.RIGHT, range_limit := 999999.0) -> Vector2:
	if attack_aim_mode() == "cursor":
		var offset := attack_aim_position(range_limit) - global_position
		if offset.length_squared() > 0.001:
			return offset.normalized()
	var fallback := default_direction
	if fallback.length_squared() <= 0.001:
		fallback = _facing_direction
	if fallback.length_squared() <= 0.001:
		fallback = Vector2.RIGHT
	return fallback.normalized()


func play_action_animation(action_id: String, direction := Vector2.ZERO, phase := "", duration := 0.0, metadata := {}) -> void:
	if direction.length_squared() > 0.0:
		_facing_direction = direction.normalized()
		_update_sprite_facing(_facing_direction)
	var event_metadata: Dictionary = metadata if metadata is Dictionary else {}
	last_weapon_animation_event = {
		"action_id": action_id,
		"phase": phase,
		"duration": maxf(float(duration), 0.0),
		"direction": _facing_direction,
		"weapon_id": weapon_id,
		"character_id": character_id,
		"metadata": event_metadata.duplicate(true),
	}
	weapon_animation_event.emit(last_weapon_animation_event)
	if phase != "":
		if _uses_full_frame_visual:
			_play_body_action_animation(action_id, maxf(float(duration), 0.0))
		var event_rig := _cutout_rig()
		if event_rig != null and event_rig.has_method("play_action"):
			var event_weapon_id := str(event_metadata.get("weapon_id", weapon_id))
			var event_attack_mode := str(event_metadata.get("attack_mode", ""))
			var event_variant := event_weapon_id if event_weapon_id != "" else weapon_id
			if event_attack_mode != "":
				event_variant = "%s:%s:%s" % [event_variant, event_attack_mode, phase]
			event_rig.play_action(action_id, _facing_direction, event_variant, maxf(float(duration), 0.0))
		return
	_play_body_action_animation(action_id, maxf(float(duration), 0.0))
	var rig := _cutout_rig()
	if rig != null and rig.has_method("play_action"):
		var animation_variant: String = weapon_id if weapon_id != "" else character_id
		rig.play_action(action_id, _facing_direction, animation_variant)

	if _action_tween != null and _action_tween.is_valid():
		_action_tween.kill()

	var impact_offset := Vector2.ZERO
	var impact_rotation := 0.0
	var impact_scale := Vector2.ONE
	var windup_time := 0.06
	var recover_time := 0.13
	var direction_sign := 1.0 if _facing_direction.x >= 0.0 else -1.0

	match action_id:
		"attack":
			impact_offset = _facing_direction * 13.0
			impact_rotation = direction_sign * 0.22
			impact_scale = Vector2(1.08, 0.94)
			windup_time = 0.05
			recover_time = 0.14
		"shoot":
			impact_offset = -_facing_direction * 8.0
			impact_rotation = -direction_sign * 0.11
			impact_scale = Vector2(0.96, 1.04)
			windup_time = 0.04
			recover_time = 0.12
		"cast":
			impact_offset = Vector2(0.0, -10.0)
			impact_rotation = direction_sign * 0.08
			impact_scale = Vector2(1.05, 1.08)
			windup_time = 0.08
			recover_time = 0.18
		_:
			impact_offset = _facing_direction * 6.0

	_action_offset = impact_offset
	_action_rotation = impact_rotation
	_action_scale = impact_scale
	_apply_sprite_transform()

	_action_tween = create_tween()
	_action_tween.set_parallel(true)
	_action_tween.tween_property(self, "_action_offset", Vector2.ZERO, recover_time).set_delay(windup_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(self, "_action_rotation", 0.0, recover_time).set_delay(windup_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(self, "_action_scale", Vector2.ONE, recover_time).set_delay(windup_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_callback(_apply_sprite_transform)


func apply_web_slow(duration: float, factor: float) -> void:
	# Паутина: временное замедление движения (повтор продлевает, фактор общий).
	_web_slow_until = maxf(_web_slow_until, Time.get_ticks_msec() / 1000.0 + duration)
	_web_slow_factor = clampf(factor, 0.2, 1.0)


func take_damage(amount: float, _source := "") -> bool:
	if _damage_invulnerability_left > 0.0:
		return false
	if _ultimate_active and character_id == "knight":
		_gain_ultimate_charge(amount * float(_ultimate_config().get("taken_charge_rate", 1.0)) * 0.25)
		_play_sfx("dodge")
		AttackVfx.ring_pulse(_vfx_parent(), global_position, 170.0, Color(0.90, 0.95, 1.0, 0.40), false)
		return true

	if randf() < clampf(float(derived_parameters.get("dodge", 0.0)), 0.0, ProgressionData.SURVIVABILITY_DODGE_CAP):
		_show_dodge_popup()
		_play_sfx("dodge")
		_trigger_dodge_rush()
		return false

	var defended_amount := _try_knight_counter(amount)
	var defense := clampf(float(derived_parameters.get("defense", 0.0)), 0.0, ProgressionData.SURVIVABILITY_DEFENSE_CAP)
	# Поглощение плоско срезает часть удара до защиты, но после SCRUM-255
	# гарантированно пропускает заметную долю мелких ударов.
	var absorb := float(derived_parameters.get("absorb", 0.0))
	var absorbed_amount: float = maxf(defended_amount - absorb, defended_amount * ProgressionData.SURVIVABILITY_ABSORB_MIN_DAMAGE_FRACTION)
	var final_damage := absorbed_amount * (1.0 - defense)
	health = max(health - final_damage, 0.0)
	_damage_invulnerability_left = damage_invulnerability_time
	_play_hit_feedback()
	_play_sfx("player_hit")
	damaged.emit(amount)
	_gain_ultimate_charge(final_damage * float(_ultimate_config().get("taken_charge_rate", 1.0)))
	_trigger_thorn_reflect(final_damage)
	# SCRUM-500 (on_take_hit): «Контр-волна» — шанс выпустить отталкивающую волну.
	_trigger_take_hit_pulse(final_damage)
	# SCRUM-500 (on_low_hp): «Рубеж Стража» — одноразовый щит при падении ниже порога.
	_trigger_lowhp_guard()

	# Capstone «Вторая жизнь» (мета-древо, Стойкость): раз за забег смертельный удар
	# оставляет 1 HP и даёт 2с неуязвимости. Использование — run-persistent через snapshot.
	if health <= 0.0 and float(run_modifiers.get("death_save", 0.0)) > 0.0 \
			and float(run_modifiers.get("death_save_used", 0.0)) <= 0.0:
		run_modifiers["death_save_used"] = 1.0
		health = 1.0
		_damage_invulnerability_left = maxf(_damage_invulnerability_left, 2.0)
		_play_sfx("dodge")
		AttackVfx.ring_pulse(_vfx_parent(), global_position, 200.0, Color(1.0, 0.95, 0.6, 0.55), false)

	if health <= 0.0:
		var rig := _cutout_rig()
		if rig != null and rig.has_method("spawn_death_ghost"):
			rig.spawn_death_ghost()
		died.emit()
		queue_free()
	return true


func trigger_assassin_dash(target: Node2D, burst_radius: float) -> void:
	trigger_assassin_crit_shadow(target, burst_radius)


func trigger_assassin_crit_shadow(target: Node2D, burst_radius: float) -> void:
	if character_id != "assassin" or target == null or not is_instance_valid(target):
		return
	if _assassin_crit_shadow_cooldown_left > 0.0 or burst_radius <= 0.0:
		return
	var to_target := target.global_position - global_position
	if to_target.length_squared() <= 16.0:
		return
	var energy := float(stats.get("energy", 0.0))
	_assassin_crit_shadow_cooldown_left = maxf(0.25, 0.55 / (1.0 + energy * 0.035))
	var parent := get_parent() if get_parent() is Node2D else _vfx_parent()
	var radius := maxf(burst_radius, 42.0)
	AttackVfx.ring_pulse(parent, target.global_position, radius, Color(0.70, 0.20, 1.0, 0.38), false)
	AttackVfx.slash(parent, (target.global_position - global_position).normalized(), minf(radius * 1.4, 180.0), Color(0.72, 0.22, 1.0, 0.34)).global_position = target.global_position


func _try_knight_counter(incoming_amount: float) -> float:
	if character_id != "knight" or _knight_counter_cooldown_left > 0.0:
		return incoming_amount
	var passive_mods: Dictionary = weapon_config.get("passive_mods", {})
	var block_reduction := float(passive_mods.get("block_reduction", 0.0))
	var counter_multiplier := float(passive_mods.get("counter_damage_multiplier", 0.0))
	if block_reduction <= 0.0 and counter_multiplier <= 0.0:
		return incoming_amount
	var energy := float(stats.get("energy", 0.0))
	_knight_counter_cooldown_left = maxf(float(passive_mods.get("counter_cooldown", 2.4)) / (1.0 + energy * 0.03), 0.2)
	var parent := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	AttackVfx.ring_pulse(parent, global_position, 150.0, Color(0.92, 0.96, 1.0, 0.45), true)
	if counter_multiplier > 0.0:
		var counter_damage := float(derived_parameters.get("damage", 10.0)) * counter_multiplier
		for enemy in get_tree().get_nodes_in_group("enemies"):
			var enemy_node := enemy as Node2D
			if enemy_node == null or not is_instance_valid(enemy_node):
				continue
			if global_position.distance_squared_to(enemy_node.global_position) <= 170.0 * 170.0 and enemy_node.has_method("take_damage"):
				enemy_node.take_damage(counter_damage)
	return incoming_amount * clampf(1.0 - block_reduction, 0.15, 1.0)


func _trigger_thorn_reflect(received_damage: float) -> void:
	var reflect := float(run_modifiers.get("thorn_reflect_multiplier", 0.0))
	if reflect <= 0.0 or received_damage <= 0.0 or not is_inside_tree():
		return
	var reflected := received_damage * reflect
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		if global_position.distance_squared_to(enemy_node.global_position) <= 200.0 * 200.0 and enemy_node.has_method("take_damage"):
			enemy_node.take_damage(reflected)


func _trigger_dodge_rush() -> void:
	if float(run_modifiers.get("dodge_rush_bonus", 0.0)) <= 0.0:
		return
	run_modifiers["dodge_rush_active"] = 1.0
	_apply_stat_scaling(false, max_health)
	if _dodge_rush_tween != null and _dodge_rush_tween.is_valid():
		_dodge_rush_tween.kill()
	_dodge_rush_tween = create_tween()
	_dodge_rush_tween.tween_interval(2.0)
	_dodge_rush_tween.tween_callback(func() -> void:
		run_modifiers["dodge_rush_active"] = 0.0
		_apply_stat_scaling(false, max_health)
	)


# SCRUM-500 (on_crit): «Импульс Крита» — короткий бафф скорости движения по криту.
# Эталон — _trigger_dodge_rush: флаг *_active + tween на снятие + пересчёт скейла.
# crit_speed_burst (доля) консумится в derived_parameters как dodge_rush.
func _trigger_crit_speed_burst() -> void:
	if float(run_modifiers.get("crit_speed_burst", 0.0)) <= 0.0:
		return
	run_modifiers["crit_speed_burst_active"] = 1.0
	_apply_stat_scaling(false, max_health)
	if _crit_burst_tween != null and _crit_burst_tween.is_valid():
		_crit_burst_tween.kill()
	_crit_burst_tween = create_tween()
	_crit_burst_tween.tween_interval(1.8)
	_crit_burst_tween.tween_callback(func() -> void:
		run_modifiers["crit_speed_burst_active"] = 0.0
		_apply_stat_scaling(false, max_health)
	)


# SCRUM-500 (on_low_hp): «Рубеж Стража» — одноразовый (на порог) щит при падении ниже 30% HP:
# нокбэк-волна + краткая неуязвимость. Латч _lowhp_guard_used + перезаряд, перевооружение
# при подъёме HP выше порога (в _update_low_hp_state).
func _trigger_lowhp_guard() -> void:
	if float(run_modifiers.get("lowhp_guard", 0.0)) <= 0.0:
		return
	if _lowhp_guard_used or _lowhp_guard_cooldown_left > 0.0:
		return
	if max_health <= 0.0 or health <= 0.0 or health >= max_health * 0.3:
		return
	_lowhp_guard_used = true
	_lowhp_guard_cooldown_left = 18.0
	_damage_invulnerability_left = maxf(_damage_invulnerability_left, 1.5)
	_play_sfx("dodge")
	if is_inside_tree():
		AttackVfx.ring_pulse(_vfx_parent(), global_position, 210.0, Color(0.55, 0.85, 1.0, 0.55), false)
		# Нокбэк-волна: отталкивает врагов рядом (через их take_knockback при наличии).
		for enemy in get_tree().get_nodes_in_group("enemies"):
			var enemy_node := enemy as Node2D
			if enemy_node == null or not is_instance_valid(enemy_node):
				continue
			if global_position.distance_squared_to(enemy_node.global_position) <= 230.0 * 230.0:
				if enemy_node.has_method("apply_knockback"):
					enemy_node.apply_knockback((enemy_node.global_position - global_position).normalized() * 240.0)


# SCRUM-500 (on_take_hit): «Контр-волна» — шанс по получению удара выпустить отталкивающую
# волну, бьющую врагов рядом частью полученного урона. Шанс + перезаряд против runaway.
func _trigger_take_hit_pulse(received_damage: float) -> void:
	if float(run_modifiers.get("take_hit_pulse_chance", 0.0)) <= 0.0 or received_damage <= 0.0:
		return
	if _take_hit_pulse_cooldown_left > 0.0 or not is_inside_tree():
		return
	if randf() >= clampf(float(run_modifiers.get("take_hit_pulse_chance", 0.0)), 0.0, 1.0):
		return
	_take_hit_pulse_cooldown_left = 3.0
	var pulse_damage := received_damage * 0.9
	AttackVfx.ring_pulse(_vfx_parent(), global_position, 180.0, Color(1.0, 0.8, 0.4, 0.45), true)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		if global_position.distance_squared_to(enemy_node.global_position) <= 190.0 * 190.0:
			if enemy_node.has_method("take_damage"):
				enemy_node.take_damage(pulse_damage)
			if enemy_node.has_method("apply_knockback"):
				enemy_node.apply_knockback((enemy_node.global_position - global_position).normalized() * 180.0)


func _update_low_hp_state() -> void:
	# SCRUM-500: low_hp_active нужен не только «Кровавому Рубежу» (low_hp_damage_bonus),
	# но и «Второму Дыханию» (lowhp_regen_bonus). Трекаем порог, если есть любой low-HP флаг.
	var has_low_hp_artifact := float(run_modifiers.get("low_hp_damage_bonus", 0.0)) > 0.0 \
		or float(run_modifiers.get("lowhp_regen_bonus", 0.0)) > 0.0 \
		or float(run_modifiers.get("lowhp_guard", 0.0)) > 0.0
	var active := has_low_hp_artifact and health < max_health * 0.3
	# Перевооружаем одноразовый щит «Рубеж Стража», когда HP поднялось выше порога.
	if not active and max_health > 0.0 and health >= max_health * 0.3:
		_lowhp_guard_used = false
	if active == _low_hp_active:
		return
	_low_hp_active = active
	run_modifiers["low_hp_active"] = 1.0 if active else 0.0
	_apply_stat_scaling(false, max_health)


func apply_reward(reward: Dictionary) -> void:
	var old_max_health := max_health

	if reward.has("stats"):
		for stat_id in reward["stats"].keys():
			stats[stat_id] = float(stats.get(stat_id, 0.0)) + float(reward["stats"][stat_id])

	if reward.has("mods"):
		_apply_reward_mods(reward["mods"])
	if reward.has("affinity_mods"):
		# С 0.2 affinity_mods больше не пропадают у «чужого» класса: это
		# универсальная интерпретация артефакта через текущий class kit.
		_apply_reward_mods(reward["affinity_mods"])

	if reward.get("kind", "") == "artifact":
		# Храним id и title: id нужен для иконок HUD/паузы, title — для текстов.
		artifacts.append({"id": str(reward.get("id", "")), "title": str(reward.get("title", ""))})

	_apply_stat_scaling(false, old_max_health)

	if reward.has("heal_percent"):
		heal_percent(float(reward["heal_percent"]))

	for weapon in _equipped_weapons():
		_apply_weapon_scaling(weapon)


func _apply_reward_mods(mods: Dictionary) -> void:
	for modifier_id in mods.keys():
		if modifier_id.ends_with("_multiplier"):
			run_modifiers[modifier_id] = float(run_modifiers.get(modifier_id, 1.0)) * float(mods[modifier_id])
		else:
			run_modifiers[modifier_id] = float(run_modifiers.get(modifier_id, 0.0)) + float(mods[modifier_id])


# Боевое подмножество модификаторов мета-древа умений (SCRUM-150): суммарные
# приросты из META_PROGRESSION.skill_modifiers складываются в run_modifiers как
# постоянный бонус забега (поверх asc-наград). Экономические/мета-флаги дерева
# (золото/цены/рероллы/death_save) применяются на уровне забега/UI, не здесь.
const META_SKILL_MULT_MAP := {
	"damage_mult": "damage_multiplier",
	"attack_speed_mult": "attack_speed_multiplier",
	"max_health_mult": "max_health_multiplier",
	"xp_gain_mult": "xp_gain_multiplier",
	"money_gain_mult": "money_gain_multiplier",
	"ult_charge_mult": "ult_charge_multiplier",
	"elite_boss_damage_mult": "elite_boss_damage_multiplier",
	# Прогрессия по классам (SCRUM-360): бонусы текущего класса (передаются только
	# выбранному классу из main); множатся с аккаунтными на тот же run_modifier.
	"class_damage_mult": "damage_multiplier",
	"class_attack_speed_mult": "attack_speed_multiplier",
	"class_max_health_mult": "max_health_multiplier",
}
const META_SKILL_FLAT_MAP := {
	"defense_flat": "defense_flat",
	"dodge_flat": "dodge_flat",
	"regeneration_flat": "regeneration_flat",
}


func apply_meta_skill_modifiers(mods: Dictionary) -> void:
	var old_max_health := max_health
	for key in META_SKILL_MULT_MAP:
		if mods.has(key):
			var run_key: String = META_SKILL_MULT_MAP[key]
			# Значения дерева — доли (+0.06), множитель = 1.0 + сумма.
			run_modifiers[run_key] = float(run_modifiers.get(run_key, 1.0)) * (1.0 + float(mods[key]))
	for key in META_SKILL_FLAT_MAP:
		if mods.has(key):
			var run_key: String = META_SKILL_FLAT_MAP[key]
			run_modifiers[run_key] = float(run_modifiers.get(run_key, 0.0)) + float(mods[key])
	_apply_stat_scaling(false, old_max_health)
	for weapon in _equipped_weapons():
		_apply_weapon_scaling(weapon)
	# Capstone «Боевой раж»: ульта стартует частично заряженной.
	var start_charge := float(mods.get("ult_start_charge", 0.0))
	if start_charge > 0.0:
		ultimate_charge = clampf(ultimate_max_charge * start_charge, 0.0, ultimate_max_charge)
	# Capstone «Вторая жизнь»: флаг спасения от смерти (логика — в take_damage).
	if float(mods.get("death_save", 0.0)) > 0.0:
		run_modifiers["death_save"] = 1.0


func _apply_regeneration(delta: float) -> void:
	var vampiric_cap := ProgressionData.effective_vampiric_cap(float(run_modifiers.get("vampiric_heal_per_second_cap", ProgressionData.VAMPIRIC_HEAL_CAP_DEFAULT)))
	_vampiric_heal_budget = minf(_vampiric_heal_budget + vampiric_cap * delta, vampiric_cap)
	# SCRUM-517: пополняем drain-бюджет до его per-second потолка (отдельно от регена,
	# т.к. sustain Доктора — это drain, а не пассивный реген; бюджет нужен даже при regen=0).
	var drain_cap := _effective_drain_heal_cap()
	_drain_heal_budget = minf(_drain_heal_budget + drain_cap * delta, drain_cap)
	var regeneration := float(derived_parameters.get("regeneration", 0.0))
	# SCRUM-500 (on_low_hp): «Второе Дыхание» — усиленный реген, пока HP ниже порога.
	if _low_hp_active:
		regeneration += float(run_modifiers.get("lowhp_regen_bonus", 0.0))
	if regeneration <= 0.0 or health >= max_health or health <= 0.0:
		return
	health = minf(health + regeneration * float(run_modifiers.get("healing_multiplier", 1.0)) * delta, max_health)


func on_weapon_hit(enemy: Node2D, dealt_damage := 0.0, was_crit := false) -> void:
	_gain_ultimate_charge(maxf(dealt_damage, 0.0) * float(_ultimate_config().get("damage_charge_rate", 0.03)))
	# SCRUM-500 (on_crit): «Импульс Крита» — короткий бафф скорости движения по криту.
	if was_crit:
		_trigger_crit_speed_burst()
	# Вампиризм теперь sustain, а не бессмертие: малая доля урона + per-second cap.
	var vampiric_chance := float(derived_parameters.get("vampiric_chance", 0.0))
	if vampiric_chance > 0.0 and dealt_damage > 0.0 and _vampiric_heal_budget > 0.0 and randf() < vampiric_chance:
		var raw_heal := float(derived_parameters.get("vampiric_amount", 0.0)) + dealt_damage * ProgressionData.VAMPIRIC_DAMAGE_HEAL_RATIO
		var vampiric_heal := minf(raw_heal, _vampiric_heal_budget)
		_vampiric_heal_budget -= vampiric_heal
		health = minf(health + vampiric_heal * float(run_modifiers.get("healing_multiplier", 1.0)), max_health)
	_trigger_magic_enchant(enemy)
	_trigger_universal_dot(enemy)
	_trigger_leadership_echo(enemy)
	_trigger_class_status_effects(enemy)
	_trigger_berserk_ultimate_echo(enemy)
	_on_weapon_hit_echo(enemy)


# SCRUM-517: единая точка DRAIN-heal оружия (drain_link/lifesteal). Раньше
# class_weapon._heal_owner_from_damage писал лечение прямо в health БЕЗ потолка/с,
# из-за чего Доктор (restore_potion/plague_syringe) в толпе хилился на сотни HP/с
# (DoT-стак × число целей) и становился бессмертным. Теперь лечение списывается из
# per-second бюджета — drain остаётся сильнейшим в игре детерминированным sustain
# (потолок выше вампирного), но конечен: при достаточном входящем DPS HP убывает.
# Возвращает фактически вылеченное (для combat-feedback на стороне оружия).
func apply_drain_heal(amount: float) -> float:
	if amount <= 0.0 or health <= 0.0 or _drain_heal_budget <= 0.0:
		return 0.0
	var allowed := minf(amount, _drain_heal_budget)
	var before := health
	health = minf(health + allowed * float(run_modifiers.get("healing_multiplier", 1.0)), max_health)
	var healed := health - before
	# Списываем из бюджета по «сырому» allowed (до healing_multiplier и до клампа об
	# max_health), чтобы стоять у полного HP не позволяло копить и сливать бюджет залпом.
	_drain_heal_budget = maxf(_drain_heal_budget - allowed, 0.0)
	return healed


func _effective_drain_heal_cap() -> float:
	var raw_cap := float(run_modifiers.get("drain_heal_per_second_cap", ProgressionData.BalanceData.DRAIN_HEAL_PER_SECOND_CAP_DEFAULT))
	return clampf(raw_cap, 0.0, ProgressionData.BalanceData.DRAIN_HEAL_PER_SECOND_CAP_HARD)


func _ultimate_config() -> Dictionary:
	return PROGRESSION_DATA.ultimate_config(character_id)


func _gain_ultimate_charge(amount: float) -> void:
	if amount <= 0.0 or _ultimate_active:
		return
	var energy_scale := 1.0 + float(stats.get("energy", 0.0)) * 0.025
	ultimate_charge = clampf(ultimate_charge + amount * energy_scale, 0.0, ultimate_max_charge)


func ultimate_ready() -> bool:
	return ultimate_charge >= ultimate_max_charge


func activate_ultimate() -> bool:
	if not ultimate_ready() or _ultimate_active or not is_inside_tree():
		return false
	var config := _ultimate_config()
	var multiplier := float(derived_parameters.get("ultimate_multiplier", 1.0))
	ultimate_charge = 0.0
	_play_sfx("level_up")
	match character_id:
		"berserk":
			_activate_berserk_ultimate(config, multiplier)
		"dark_mage":
			_activate_dark_mage_ultimate(config, multiplier)
		"guitarist":
			_activate_guitarist_ultimate(config, multiplier)
		"assassin":
			_activate_assassin_ultimate(config, multiplier)
		"thief":
			_activate_thief_ultimate(config, multiplier)
		"elementalist":
			_activate_elementalist_ultimate(config, multiplier)
		"sniper":
			_activate_sniper_ultimate(config, multiplier)
		"priest":
			_activate_priest_ultimate(config, multiplier)
		"biologist":
			_activate_biologist_ultimate(config, multiplier)
		"robot":
			_activate_robot_ultimate(config, multiplier)
		"engineer":
			_activate_engineer_ultimate(config, multiplier)
		"ranger":
			_activate_ranger_ultimate(config, multiplier)
		"doctor":
			_activate_doctor_ultimate(config, multiplier)
		"chemist":
			_activate_chemist_ultimate(config, multiplier)
		"knight":
			_activate_knight_ultimate(config, multiplier)
		"druid":
			_activate_druid_ultimate(config, multiplier)
		_:
			_activate_dark_mage_ultimate(config, multiplier)
	return true


func _activate_timed_ultimate(duration: float) -> void:
	_ultimate_active = true
	if _ultimate_tween != null and _ultimate_tween.is_valid():
		_ultimate_tween.kill()
	_ultimate_tween = create_tween()
	_ultimate_tween.tween_interval(maxf(duration, 0.1))
	_ultimate_tween.tween_callback(func() -> void:
		_ultimate_active = false
		_apply_stat_scaling(false, max_health)
	)


func _activate_berserk_ultimate(config: Dictionary, multiplier: float) -> void:
	var duration := float(config.get("duration", 5.0)) * clampf(multiplier, 0.8, 2.2)
	run_modifiers["ultimate_berserk_active"] = 1.0
	run_modifiers["attack_speed_multiplier"] = float(run_modifiers.get("attack_speed_multiplier", 1.0)) * 1.35
	run_modifiers["move_speed_multiplier"] = float(run_modifiers.get("move_speed_multiplier", 1.0)) * 1.18
	_apply_stat_scaling(false, max_health)
	AttackVfx.ring_pulse(_vfx_parent(), global_position, float(config.get("radius", 180.0)), Color(0.95, 0.20, 0.10, 0.42), false)
	_activate_timed_ultimate(duration)
	_ultimate_tween.tween_callback(func() -> void:
		run_modifiers["attack_speed_multiplier"] = float(run_modifiers.get("attack_speed_multiplier", 1.0)) / 1.35
		run_modifiers["move_speed_multiplier"] = float(run_modifiers.get("move_speed_multiplier", 1.0)) / 1.18
		run_modifiers["ultimate_berserk_active"] = 0.0
		_apply_stat_scaling(false, max_health)
	)


func _trigger_berserk_ultimate_echo(enemy: Node2D) -> void:
	if not _ultimate_active or character_id != "berserk" or enemy == null or not is_instance_valid(enemy):
		return
	var config := _ultimate_config()
	var radius := float(config.get("radius", 180.0))
	var damage_amount := float(derived_parameters.get("damage", 10.0)) * float(config.get("damage", 0.75)) * float(derived_parameters.get("ultimate_multiplier", 1.0))
	AttackVfx.ring_pulse(_vfx_parent(), enemy.global_position, radius, Color(1.0, 0.26, 0.12, 0.34), false)
	_damage_enemies_in_radius(enemy.global_position, radius, damage_amount)


func _activate_dark_mage_ultimate(config: Dictionary, multiplier: float) -> void:
	var radius := float(config.get("radius", 360.0)) * clampf(multiplier, 0.8, 1.8)
	var damage_amount := float(derived_parameters.get("magic_damage", 12.0)) * float(config.get("damage", 1.35)) * multiplier
	AttackVfx.orb_burst(_vfx_parent(), global_position, radius, Color(0.42, 0.18, 1.0, 0.46))
	_damage_enemies_in_radius(global_position, radius, damage_amount)


func _activate_guitarist_ultimate(config: Dictionary, multiplier: float) -> void:
	var radius := float(config.get("radius", 430.0)) * clampf(multiplier, 0.8, 1.6)
	var damage_amount := float(derived_parameters.get("sound_wave_damage", 10.0)) * float(config.get("damage", 1.15)) * multiplier
	AttackVfx.ring_pulse(_vfx_parent(), global_position, radius, Color(0.25, 0.85, 1.0, 0.50), true)
	for enemy in _enemies_in_radius(global_position, radius):
		var away: Vector2 = enemy.global_position - global_position
		if enemy.has_method("apply_knockback") and away.length_squared() > 0.001:
			enemy.apply_knockback(away.normalized() * 650.0)
		_apply_ultimate_damage(enemy, damage_amount)


func _activate_assassin_ultimate(config: Dictionary, multiplier: float) -> void:
	var count := int(config.get("target_count", 7)) + int(floor(multiplier))
	var damage_amount := float(derived_parameters.get("damage", 10.0)) * float(config.get("damage", 1.05)) * multiplier
	for enemy in _nearest_enemies(int(count), float(config.get("radius", 520.0))):
		AttackVfx.slash(_vfx_parent(), (enemy.global_position - global_position).normalized(), 120.0, Color(0.72, 0.22, 1.0, 0.42)).global_position = enemy.global_position
		_apply_ultimate_damage(enemy, damage_amount * float(derived_parameters.get("crit_damage_multiplier", 1.5)))


func _activate_thief_ultimate(config: Dictionary, multiplier: float) -> void:
	var count := int(config.get("target_count", 8)) + int(floor(multiplier))
	var radius := float(config.get("radius", 500.0))
	var damage_amount := float(derived_parameters.get("damage", 10.0)) * float(config.get("damage", 1.0)) * multiplier
	var stolen := 0
	AttackVfx.ring_pulse(_vfx_parent(), global_position, radius * 0.52, Color(0.95, 0.66, 0.18, 0.36), true)
	for enemy in _nearest_enemies(count, radius):
		if not is_instance_valid(enemy):
			continue
		AttackVfx.beam(_vfx_parent(), global_position, enemy.global_position, 34.0, Color(1.0, 0.82, 0.28, 0.36))
		_apply_ultimate_damage(enemy, damage_amount)
		stolen += 2
	if stolen > 0:
		gain_money(stolen)


func _activate_elementalist_ultimate(config: Dictionary, multiplier: float) -> void:
	var radius := float(config.get("radius", 430.0)) * clampf(multiplier, 0.8, 1.65)
	var damage_amount := float(derived_parameters.get("magic_damage", 10.0)) * float(config.get("damage", 1.18)) * multiplier
	AttackVfx.orb_burst(_vfx_parent(), global_position, radius, Color(0.35, 0.80, 1.0, 0.44))
	AttackVfx.ring_pulse(_vfx_parent(), global_position, radius * 0.72, Color(1.0, 0.48, 0.16, 0.38), true)
	_damage_enemies_in_radius(global_position, radius, damage_amount)
	for enemy in _nearest_enemies(int(config.get("target_count", 6)), radius * 1.15):
		if not is_instance_valid(enemy):
			continue
		AttackVfx.beam(_vfx_parent(), global_position, enemy.global_position, 42.0, Color(0.86, 0.46, 1.0, 0.40))
		_apply_ultimate_damage(enemy, damage_amount * 0.42)


func _activate_sniper_ultimate(config: Dictionary, multiplier: float) -> void:
	var radius := float(config.get("radius", 760.0)) * clampf(multiplier, 0.8, 1.6)
	var count := int(config.get("target_count", 5)) + int(floor(multiplier))
	var damage_amount := float(derived_parameters.get("damage", 10.0)) * float(config.get("damage", 1.35)) * multiplier
	AttackVfx.ring_pulse(_vfx_parent(), global_position, radius * 0.28, Color(0.78, 0.88, 1.0, 0.34), true)
	for enemy in _nearest_enemies(count, radius):
		if not is_instance_valid(enemy):
			continue
		var sky_start: Vector2 = enemy.global_position + Vector2(0.0, -radius * 0.42)
		AttackVfx.beam(_vfx_parent(), sky_start, enemy.global_position, 36.0, Color(0.92, 0.96, 1.0, 0.48))
		_apply_ultimate_damage(enemy, damage_amount)


func _activate_priest_ultimate(config: Dictionary, multiplier: float) -> void:
	var radius := float(config.get("radius", 410.0)) * clampf(multiplier, 0.8, 1.65)
	var damage_amount := float(derived_parameters.get("magic_damage", 10.0)) * float(config.get("damage", 1.05)) * multiplier
	var heal_ratio := float(config.get("heal_ratio", 0.45))
	AttackVfx.ring_pulse(_vfx_parent(), global_position, radius, Color(1.0, 0.92, 0.52, 0.38), false)
	AttackVfx.orb_burst(_vfx_parent(), global_position, radius * 0.70, Color(0.88, 0.96, 1.0, 0.32))
	var healed := 0.0
	for enemy in _enemies_in_radius(global_position, radius):
		_apply_ultimate_damage(enemy, damage_amount)
		healed += damage_amount * heal_ratio
	var before := health
	health = minf(max_health, health + healed * float(run_modifiers.get("healing_multiplier", 1.0)))
	if health > before + 0.01:
		_show_heal_vfx()


func _activate_biologist_ultimate(config: Dictionary, multiplier: float) -> void:
	var radius := float(config.get("radius", 440.0)) * clampf(multiplier, 0.8, 1.65)
	var damage_amount := float(derived_parameters.get("magic_damage", 10.0)) * float(config.get("damage", 1.10)) * multiplier
	var heal_ratio := float(config.get("heal_ratio", 0.18))
	AttackVfx.ring_pulse(_vfx_parent(), global_position, radius, Color(0.46, 1.0, 0.38, 0.34), true)
	AttackVfx.orb_burst(_vfx_parent(), global_position, radius * 0.58, Color(0.28, 0.92, 0.54, 0.30))
	var healed := 0.0
	for enemy in _nearest_enemies(int(config.get("target_count", 9)), radius):
		if not is_instance_valid(enemy):
			continue
		AttackVfx.beam(_vfx_parent(), global_position, enemy.global_position, 30.0, Color(0.52, 1.0, 0.42, 0.36))
		_apply_ultimate_damage(enemy, damage_amount)
		healed += damage_amount * heal_ratio
	if healed > 0.01:
		var before := health
		health = minf(max_health, health + healed * float(run_modifiers.get("healing_multiplier", 1.0)))
		if health > before + 0.01:
			_show_heal_vfx()


func _activate_robot_ultimate(config: Dictionary, multiplier: float) -> void:
	var duration := float(config.get("duration", 4.5)) * clampf(multiplier, 0.8, 1.7)
	var radius := float(config.get("radius", 380.0)) * clampf(multiplier, 0.8, 1.55)
	var damage_amount := float(derived_parameters.get("damage", 10.0)) * float(config.get("damage", 0.78)) * multiplier
	var absorb_bonus := 8.0 + 4.0 * clampf(multiplier, 0.8, 2.0)
	run_modifiers["absorb_flat"] = float(run_modifiers.get("absorb_flat", 0.0)) + absorb_bonus
	run_modifiers["defense_flat"] = float(run_modifiers.get("defense_flat", 0.0)) + 0.05
	_apply_stat_scaling(false, max_health)
	AttackVfx.ring_pulse(_vfx_parent(), global_position, radius, Color(0.42, 0.82, 1.0, 0.42), true)
	_damage_enemies_in_radius(global_position, radius, damage_amount)
	_ultimate_active = true
	if _ultimate_tween != null and _ultimate_tween.is_valid():
		_ultimate_tween.kill()
	_ultimate_tween = create_tween()
	var self_id := get_instance_id()
	var pulse_count := maxi(int(config.get("target_count", 8)) / 2, 3)
	for pulse_index in range(pulse_count):
		_ultimate_tween.tween_interval(duration / float(pulse_count + 1))
		_ultimate_tween.tween_callback(func() -> void:
			var current_robot := instance_from_id(self_id) as Node2D
			if current_robot == null or not is_instance_valid(current_robot):
				return
			AttackVfx.ring_pulse(_vfx_parent(), current_robot.global_position, radius * 0.62, Color(0.36, 1.0, 0.86, 0.32), false)
			_damage_enemies_in_radius(current_robot.global_position, radius * 0.62, damage_amount * 0.34)
		)
	_ultimate_tween.tween_interval(duration / float(pulse_count + 1))
	_ultimate_tween.tween_callback(func() -> void:
		_ultimate_active = false
		run_modifiers["absorb_flat"] = maxf(0.0, float(run_modifiers.get("absorb_flat", 0.0)) - absorb_bonus)
		run_modifiers["defense_flat"] = maxf(0.0, float(run_modifiers.get("defense_flat", 0.0)) - 0.05)
		_apply_stat_scaling(false, max_health)
	)


func _activate_engineer_ultimate(config: Dictionary, multiplier: float) -> void:
	var duration := float(config.get("duration", 4.2)) * clampf(multiplier, 0.8, 1.7)
	var radius := float(config.get("radius", 430.0)) * clampf(multiplier, 0.8, 1.55)
	var damage_amount := float(derived_parameters.get("damage", 10.0)) * float(config.get("damage", 0.92)) * multiplier
	var heal_ratio := float(config.get("heal_ratio", 0.12))
	_ultimate_active = true
	run_modifiers["summon_bonus"] = float(run_modifiers.get("summon_bonus", 0.0)) + 2.0
	run_modifiers["regeneration_flat"] = float(run_modifiers.get("regeneration_flat", 0.0)) + 0.35
	_apply_stat_scaling(false, max_health)
	AttackVfx.ring_pulse(_vfx_parent(), global_position, radius, Color(0.90, 0.72, 0.28, 0.42), true)
	var healed := 0.0
	for enemy in _nearest_enemies(int(config.get("target_count", 9)), radius):
		if not is_instance_valid(enemy):
			continue
		AttackVfx.beam(_vfx_parent(), global_position, enemy.global_position, 30.0, Color(0.48, 0.90, 1.0, 0.42))
		_apply_ultimate_damage(enemy, damage_amount)
		healed += damage_amount * heal_ratio
	if healed > 0.01:
		var before := health
		health = minf(max_health, health + healed * float(run_modifiers.get("healing_multiplier", 1.0)))
		if health > before + 0.01:
			_show_heal_vfx()
	if _ultimate_tween != null and _ultimate_tween.is_valid():
		_ultimate_tween.kill()
	_ultimate_tween = create_tween()
	var self_id := get_instance_id()
	var pulse_count := maxi(int(config.get("target_count", 9)) / 3, 3)
	for pulse_index in range(pulse_count):
		_ultimate_tween.tween_interval(duration / float(pulse_count + 1))
		_ultimate_tween.tween_callback(func() -> void:
			var current_engineer := instance_from_id(self_id) as Node2D
			if current_engineer == null or not is_instance_valid(current_engineer):
				return
			AttackVfx.ring_pulse(_vfx_parent(), current_engineer.global_position, radius * 0.48, Color(1.0, 0.56, 0.22, 0.34), false)
			_damage_enemies_in_radius(current_engineer.global_position, radius * 0.48, damage_amount * 0.28)
		)
	_ultimate_tween.tween_interval(duration / float(pulse_count + 1))
	_ultimate_tween.tween_callback(func() -> void:
		_ultimate_active = false
		run_modifiers["summon_bonus"] = maxf(0.0, float(run_modifiers.get("summon_bonus", 0.0)) - 2.0)
		run_modifiers["regeneration_flat"] = maxf(0.0, float(run_modifiers.get("regeneration_flat", 0.0)) - 0.35)
		_apply_stat_scaling(false, max_health)
	)


func _activate_ranger_ultimate(config: Dictionary, multiplier: float) -> void:
	var radius := float(config.get("radius", 480.0)) * clampf(multiplier, 0.8, 1.6)
	var damage_amount := float(derived_parameters.get("damage", 10.0)) * float(config.get("damage", 1.18)) * multiplier
	AttackVfx.ring_pulse(_vfx_parent(), global_position, radius, Color(0.62, 0.88, 1.0, 0.35), false)
	for enemy in _nearest_enemies(int(config.get("target_count", 14)), radius):
		AttackVfx.beam(_vfx_parent(), global_position + Vector2(0, -radius * 0.55), enemy.global_position, 34.0, Color(0.70, 0.90, 1.0, 0.46))
		_apply_ultimate_damage(enemy, damage_amount)


func _activate_doctor_ultimate(config: Dictionary, multiplier: float) -> void:
	var radius := float(config.get("radius", 360.0)) * clampf(multiplier, 0.8, 1.6)
	var damage_amount := float(derived_parameters.get("magic_damage", 10.0)) * float(config.get("damage", 0.95)) * multiplier
	var healed := 0.0
	AttackVfx.ring_pulse(_vfx_parent(), global_position, radius, Color(0.86, 1.0, 0.92, 0.42), false)
	for enemy in _enemies_in_radius(global_position, radius):
		_apply_ultimate_damage(enemy, damage_amount)
		healed += damage_amount * 0.45
	# SCRUM-594: ульта Доктора — единственный хил, не уважавший healing_multiplier;
	# артефакты/мета на +лечение её не усиливали, хотя усиливают все прочие хилы.
	# Множим хил ОДИН раз и используем и для health, и для overflow→absorb.
	healed *= float(run_modifiers.get("healing_multiplier", 1.0))
	var before := health
	health = minf(max_health, health + healed)
	var overflow := maxf((before + healed) - max_health, 0.0)
	if overflow > 0.0:
		# SCRUM-595: раньше каждый оверхил-каст НАВСЕГДА добавлял absorb_flat и
		# никогда не снимал — за забег щит копился безгранично (эксплойт/пауэр-крип;
		# робо-ульта свой absorb возвращает, доктор только add). Идентичность Доктора
		# (overheal → постоянный щит) сохраняем, но КАПИМ суммарный доктор-вклад
		# потолком, привязанным к max_health, чтобы рост был ограничен.
		var cap := max_health * DOCTOR_ULT_ABSORB_CAP_FRACTION
		var gain := minf(overflow * 0.08, maxf(cap - _doctor_ult_absorb_total, 0.0))
		if gain > 0.0:
			_doctor_ult_absorb_total += gain
			run_modifiers["absorb_flat"] = float(run_modifiers.get("absorb_flat", 0.0)) + gain
			_apply_stat_scaling(false, max_health)


func _activate_chemist_ultimate(config: Dictionary, multiplier: float) -> void:
	var radius := float(config.get("radius", 420.0)) * clampf(multiplier, 0.8, 1.7)
	var damage_amount := float(derived_parameters.get("magic_damage", 10.0)) * float(config.get("damage", 1.25)) * multiplier
	AttackVfx.orb_burst(_vfx_parent(), global_position, radius, Color(0.55, 1.0, 0.18, 0.42))
	_damage_enemies_in_radius(global_position, radius, damage_amount)


func _activate_knight_ultimate(config: Dictionary, multiplier: float) -> void:
	var duration := float(config.get("duration", 5.0)) * clampf(multiplier, 0.8, 2.0)
	var radius := float(config.get("radius", 260.0))
	AttackVfx.ring_pulse(_vfx_parent(), global_position, radius, Color(0.92, 0.95, 1.0, 0.50), false)
	_damage_enemies_in_radius(global_position, radius, float(derived_parameters.get("damage", 10.0)) * float(config.get("damage", 0.7)) * multiplier)
	_activate_timed_ultimate(duration)


func _activate_druid_ultimate(config: Dictionary, multiplier: float) -> void:
	var count := int(config.get("target_count", 4)) + int(floor(multiplier))
	AttackVfx.ring_pulse(_vfx_parent(), global_position, float(config.get("radius", 260.0)), Color(0.45, 0.95, 0.38, 0.42), false)
	for index in range(count):
		var ally := ALLY_MINION_SCENE.instantiate() as Node2D
		_vfx_parent().add_child(ally)
		ally.add_to_group("player_weapon_effects")
		ally.set("owner_node", self)
		ally.set("damage", float(derived_parameters.get("sound_wave_damage", derived_parameters.get("damage", 8.0))) * float(config.get("damage", 0.8)) * multiplier)
		ally.global_position = global_position + Vector2.RIGHT.rotated(TAU * float(index) / maxf(count, 1.0)) * 72.0
		var life_tween := ally.create_tween()
		life_tween.tween_interval(float(config.get("duration", 6.0)) * clampf(multiplier, 0.8, 1.7))
		life_tween.tween_callback(ally.queue_free)


func _damage_enemies_in_radius(center: Vector2, radius: float, damage_amount: float) -> void:
	for enemy in _enemies_in_radius(center, radius):
		_apply_ultimate_damage(enemy, damage_amount)


func _enemies_in_radius(center: Vector2, radius: float) -> Array:
	return TARGET_QUERY.in_radius(self, center, radius)


func _nearest_enemies(count: int, radius: float) -> Array:
	return TARGET_QUERY.nearest_many(self, global_position, radius, count)


func _apply_ultimate_damage(enemy: Node2D, amount: float) -> void:
	if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
		return
	var final_amount := maxf(amount, 0.0)
	if enemy.is_in_group("bosses") and enemy.get("max_health") != null:
		final_amount = minf(final_amount, float(enemy.get("max_health")) * float(_ultimate_config().get("boss_cap", 0.1)))
	enemy.take_damage(final_amount)


func show_combat_feedback_number(amount: float, kind := "heal") -> void:
	if amount <= 0.0 or not _combat_feedback_enabled() or not is_inside_tree():
		return
	if get_tree().get_nodes_in_group(COMBAT_FEEDBACK_LABEL_GROUP).size() >= COMBAT_FEEDBACK_MAX_LABELS:
		return
	var parent := _vfx_parent()
	if parent == null:
		return
	var holder := Node2D.new()
	holder.z_index = 3000
	holder.global_position = global_position + Vector2(randf_range(-14.0, 14.0), -62.0 + randf_range(-4.0, 4.0))
	parent.add_child(holder)
	var label := Label.new()
	label.name = "CombatHealNumber"
	label.add_to_group(COMBAT_FEEDBACK_LABEL_GROUP)
	label.text = "+%d" % int(round(amount))
	label.modulate = Color(0.36, 1.0, 0.55, 1.0) if kind == "heal" else Color(1.0, 1.0, 1.0, 1.0)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.02, 0.92))
	label.add_theme_constant_override("outline_size", 5)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-36.0, -16.0)
	label.custom_minimum_size = Vector2(72.0, 0.0)
	holder.add_child(label)
	var tween := holder.create_tween()
	tween.set_parallel(true)
	tween.tween_property(holder, "global_position", holder.global_position + Vector2(0.0, -44.0), 0.62).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.42).set_delay(0.20)
	tween.chain().tween_callback(holder.queue_free)


func _combat_feedback_enabled() -> bool:
	if not is_inside_tree():
		return false
	return bool(get_tree().root.get_meta("combat_feedback", true))


func _vfx_parent() -> Node:
	var scene := get_tree().current_scene
	if scene is Node2D:
		return scene
	var parent := get_parent()
	if parent is Node2D:
		return parent
	return self


func _trigger_magic_enchant(enemy: Node2D) -> void:
	if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
		return
	var magic_damage := float(derived_parameters.get("magic_damage", 0.0))
	var physical_damage := float(derived_parameters.get("damage", 0.0))
	if magic_damage <= 3.0 or magic_damage <= physical_damage * 0.25:
		return
	var enchant_damage := magic_damage * (0.18 if character_id in ["berserk", "assassin", "ranger", "knight"] else 0.10)
	var radius := clampf(float(derived_parameters.get("aoe_radius", 120.0)) * 0.45, 72.0, 170.0)
	var parent := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	AttackVfx.orb_burst(parent, enemy.global_position, radius, Color(0.58, 0.38, 1.0, 0.34))
	for other_node in TARGET_QUERY.in_radius(self, enemy.global_position, radius):
		if other_node.has_method("take_damage"):
			other_node.take_damage(enchant_damage)


func _trigger_universal_dot(enemy: Node2D) -> void:
	if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
		return
	var dot_damage := float(derived_parameters.get("dot_damage", 0.0))
	var dot_speed := maxf(float(derived_parameters.get("dot_speed", 1.0)), 0.45)
	if dot_damage <= 5.0:
		return
	var tick_damage := dot_damage * (0.22 if character_id in ["doctor", "chemist", "dark_mage", "assassin", "druid"] else 0.14)
	var dot_tween := create_tween()
	for tick_index in range(2):
		dot_tween.tween_interval(1.0 / dot_speed)
		# SCRUM-551: bound-метод вместо лямбды с захватом локалов `enemy`/`tick_damage`.
		# Захват в lambda-callable интермиттентно «освобождался» под быстрым create/free
		# игрока и врагов в balance-CSV (ERROR: Lambda capture at index 1 was freed,
		# gdscript_lambda_callable.cpp:110) и валил прогон. Callable.bind держит self
		# (живёт пока жив tween, привязанный к ноде игрока) + value-args; гвард внутри метода.
		dot_tween.tween_callback(Callable(self, "_apply_dot_tick").bind(enemy, tick_damage))


func _apply_dot_tick(enemy: Node2D, tick_damage: float) -> void:
	if is_instance_valid(enemy) and enemy.has_method("take_damage"):
		enemy.take_damage(tick_damage)


func _trigger_class_status_effects(enemy: Node2D) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var buff_power := float(derived_parameters.get("buff_power", 1.0))
	match character_id:
		"dark_mage", "elementalist":
			StatusEffects.apply_status(enemy, "arcane_vulnerability", {
				"duration": 2.6,
				"max_stacks": 2,
				"stack_mode": "add",
				"damage_taken_multiplier": 1.0 + minf(0.045 * buff_power, 0.075),
				"marker_color": Color(0.72, 0.42, 1.0, 1.0),
			})
		"chemist", "doctor", "assassin", "biologist":
			StatusEffects.apply_status(enemy, "toxic_debuff", {
				"duration": 2.4,
				"max_stacks": 2,
				"stack_mode": "add",
				"dot_damage": maxf(float(derived_parameters.get("dot_damage", 1.0)) * 0.08, 0.35),
				"dot_interval": 0.75,
				"marker_color": Color(0.45, 1.0, 0.35, 1.0),
			})
		"soldier", "knight", "robot":
			StatusEffects.apply_status(enemy, "staggered", {
				"duration": 1.4,
				"speed_multiplier": 0.90,
				"marker_color": Color(0.90, 0.88, 0.72, 1.0),
			})


func _update_class_status_auras() -> void:
	if _status_aura_cooldown_left > 0.0 or not is_inside_tree():
		return
	if character_id not in ["guitarist", "druid", "engineer", "priest"]:
		return
	var aura_radius := clampf(float(derived_parameters.get("aura_radius", 160.0)) * 0.62, 120.0, 280.0)
	var buff_power := float(derived_parameters.get("buff_power", 1.0))
	var applied := false
	StatusEffects.apply_status(self, "class_aura_focus", {
		"duration": 0.85,
		"speed_multiplier": 1.0 + minf(0.018 * buff_power, 0.035),
	})
	for ally in get_tree().get_nodes_in_group("allies"):
		var ally_node := ally as Node2D
		if ally_node == null or not is_instance_valid(ally_node):
			continue
		if ally_node.get("owner_node") != self:
			continue
		if ally_node.global_position.distance_to(global_position) > aura_radius:
			continue
		StatusEffects.apply_status(ally_node, "command_aura", {
			"duration": 0.85,
			"damage_multiplier": 1.0 + minf(0.055 * buff_power, 0.12),
			"speed_multiplier": 1.0 + minf(0.025 * buff_power, 0.05),
			"marker_color": Color(0.50, 0.88, 1.0, 1.0),
		})
		applied = true
	if character_id in ["guitarist", "druid", "engineer"]:
		for enemy_node in TARGET_QUERY.in_radius(self, global_position, aura_radius):
			StatusEffects.apply_status(enemy_node, "command_pressure", {
				"duration": 0.85,
				"speed_multiplier": 0.93,
				"damage_taken_multiplier": 1.0 + minf(0.018 * buff_power, 0.035),
				"marker_color": Color(0.42, 0.78, 1.0, 1.0),
			})
			applied = true
	if character_id == "priest":
		heal_percent(minf(0.0015 * buff_power, 0.004))
		applied = true
	if applied:
		AttackVfx.ring_pulse(_vfx_parent(), global_position, aura_radius, Color(0.44, 0.82, 1.0, 0.20), false)
	_status_aura_cooldown_left = 0.55


func _trigger_leadership_echo(enemy: Node2D) -> void:
	if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
		return
	var summon_amount := float(derived_parameters.get("summon_amount", 0.0))
	if summon_amount < 4.0:
		return
	var every := maxi(3, 10 - int(floor(summon_amount * 0.55)))
	_leadership_echo_hit_counter += 1
	if _leadership_echo_hit_counter < every:
		return
	_leadership_echo_hit_counter = 0
	var echo_damage := float(derived_parameters.get(PROGRESSION_DATA.damage_parameter_for(character_id), derived_parameters.get("damage", 8.0))) * 0.34
	var parent := _vfx_parent() as Node2D
	AttackVfx.slash(parent, (enemy.global_position - global_position).normalized(), 110.0, Color(0.78, 0.90, 1.0, 0.34)).global_position = enemy.global_position
	enemy.take_damage(echo_damage)


func _update_battle_shout() -> void:
	if _battle_shout_cooldown_left > 0.0 or not is_inside_tree():
		return
	var sound_damage := float(derived_parameters.get("sound_wave_damage", 0.0))
	if character_id == "guitarist" or sound_damage < 10.0:
		return
	var shout_radius := clampf(float(derived_parameters.get("aura_radius", 160.0)) * 0.55, 105.0, 230.0)
	var affected := 0
	for enemy_node in TARGET_QUERY.in_radius(self, global_position, shout_radius):
		var away: Vector2 = enemy_node.global_position - global_position
		affected += 1
		if enemy_node.has_method("apply_knockback") and away.length_squared() > 0.001:
			enemy_node.apply_knockback(away.normalized() * sound_damage * 10.0)
		elif away.length_squared() > 0.001:
			enemy_node.global_position += away.normalized() * sound_damage * 0.08
	if affected <= 0:
		return
	var parent := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	AttackVfx.ring_pulse(parent, global_position, shout_radius, Color(0.26, 0.82, 1.0, 0.32), true)
	_battle_shout_cooldown_left = maxf(1.3, 4.4 - float(stats.get("energy", 0.0)) * 0.08)


func _on_weapon_hit_echo(enemy: Node2D) -> void:
	# «Эхо Разлома» (tier 3): каждый N-й удар — взрыв по области вокруг цели.
	var every := int(run_modifiers.get("echo_blast_every", 0.0))
	if every <= 0 or enemy == null or not is_instance_valid(enemy):
		return
	_echo_hit_counter += 1
	if _echo_hit_counter < every:
		return
	_echo_hit_counter = 0
	var blast_position := enemy.global_position
	var blast_damage := float(derived_parameters.get("damage", 10.0)) * 0.8
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	AttackVfx.orb_burst(scene, blast_position, 140.0, Color(1.0, 0.82, 0.30, 0.5))
	for other_node in TARGET_QUERY.in_radius(self, blast_position, 140.0):
		if other_node.has_method("take_damage"):
			other_node.take_damage(blast_damage)


# SCRUM-500 (on_kill): диспетчер триггеров убийства. Вызывается combat_director из
# _on_enemy_died. Взрыв «Цепная Искра» (шанс) + лечение-стак «Сбор Душ» (каждое N-е).
# Шанс/счётчик — анти-runaway: взрыв не рекурсивно усиливается, урон одноразовый.
func on_enemy_killed(enemy: Node2D) -> void:
	# «Цепная Искра»: шанс взрыва по области у трупа.
	var explosion_chance := clampf(float(run_modifiers.get("kill_explosion_chance", 0.0)), 0.0, 1.0)
	if explosion_chance > 0.0 and enemy != null and is_instance_valid(enemy) and is_inside_tree() and randf() < explosion_chance:
		var blast_position := enemy.global_position
		var blast_damage := float(derived_parameters.get("damage", 10.0)) * 0.7
		var scene := get_tree().current_scene
		if scene == null:
			scene = get_tree().root
		AttackVfx.orb_burst(scene, blast_position, 150.0, Color(1.0, 0.55, 0.20, 0.55))
		for other_node in TARGET_QUERY.in_radius(self, blast_position, 150.0):
			if other_node != enemy and other_node.has_method("take_damage"):
				other_node.take_damage(blast_damage)
	# «Сбор Душ»: каждое N-е убийство лечит процент max HP.
	var streak_every := int(run_modifiers.get("kill_streak_heal_every", 0.0))
	if streak_every > 0:
		_kill_streak_counter += 1
		if _kill_streak_counter >= streak_every:
			_kill_streak_counter = 0
			heal_percent(0.03)


func gain_xp(amount: int) -> void:
	xp += maxi(1, int(round(float(amount) * float(run_modifiers.get("xp_gain_multiplier", 1.0)))))
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = ProgressionData.next_xp_requirement(xp_to_next)
		leveled_up.emit()


func gain_money(amount: int) -> void:
	var gained := maxi(1, int(round(float(amount) * float(run_modifiers.get("money_gain_multiplier", 1.0)))))
	money += gained
	# SCRUM-502: учёт собранного за забег золота для экрана итогов. Main = current_scene.
	if is_inside_tree():
		var game_node := get_tree().current_scene
		if game_node != null and game_node.has_method("add_run_gold_collected"):
			game_node.add_run_gold_collected(gained)


func spend_money(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	return true


func heal_percent(percent: float) -> void:
	var before := health
	health = min(max_health, health + max_health * percent * float(run_modifiers.get("healing_multiplier", 1.0)))
	if health > before + 0.01:
		_show_heal_vfx()
		show_combat_feedback_number(health - before, "heal")


# SCRUM-603: БОЕВОЕ лечение-от-атаки (heal_percent_on_attack/melee_heal_percent_on_hit/
# summon_support_heal_percent) обязано уважать тот же per-second бюджет, что и drain
# (SCRUM-517), иначе на толпе суммарное лечение/с обходит cap и появляется второй
# «бессмертный» класс (priest/biologist/engineer/bone_saw). Конвертируем percent в
# абсолют (×max_health) и списываем из ЕДИНОГО drain-heal бюджета. VFX/цифра — только
# когда реально вылечили. Out-of-combat heal_percent (награды/левелап) НЕ трогаем.
func heal_percent_capped(percent: float) -> void:
	if percent <= 0.0:
		return
	var healed := apply_drain_heal(max_health * percent)
	if healed > 0.01:
		_show_heal_vfx()
		show_combat_feedback_number(healed, "heal")


func _show_heal_vfx() -> void:
	# Зелёный восстановительный отклик: мягкий пульс у ног + всплывающие искры.
	if not is_inside_tree():
		return
	var parent := _vfx_parent()
	if parent == null:
		return
	AttackVfx.ring_pulse(parent, global_position + Vector2(0.0, 6.0), 64.0, Color(0.40, 1.0, 0.55, 0.42), false)
	var rng := RandomNumberGenerator.new()
	for index in range(3):
		var spark := Sprite2D.new()
		spark.texture = AttackVfx.FLASH_TEXTURE
		var material := CanvasItemMaterial.new()
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		spark.material = material
		spark.modulate = Color(0.5, 1.0, 0.6, 0.9)
		spark.scale = Vector2.ONE * rng.randf_range(0.18, 0.28)
		spark.z_index = 14
		parent.add_child(spark)
		spark.global_position = global_position + Vector2(rng.randf_range(-16.0, 16.0), rng.randf_range(-4.0, 10.0))
		var spark_tween := spark.create_tween()
		spark_tween.set_parallel(true)
		spark_tween.tween_property(spark, "global_position", spark.global_position + Vector2(rng.randf_range(-6.0, 6.0), -34.0), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		spark_tween.tween_property(spark, "modulate:a", 0.0, 0.5)
		spark_tween.chain().tween_callback(spark.queue_free)


func _apply_stat_scaling(full_heal := false, old_max_health := 0.0) -> void:
	derived_parameters = PROGRESSION_DATA.derived_parameters(stats, run_modifiers, weapon_config)
	speed = float(derived_parameters.get("move_speed", 235.0))
	max_health = float(derived_parameters.get("health_point", 88.0))
	pickup_radius = float(derived_parameters.get("pickup_radius", 115.0))

	if full_heal or health <= 0.0:
		health = max_health
	else:
		health = min(max_health, health + max(max_health - old_max_health, 0.0))


func _apply_weapon_scaling(weapon: Node) -> void:
	_capture_weapon_base_values(weapon)

	if weapon.get("damage") != null:
		var damage_parameter := "damage"
		if weapon.get("damage_parameter") != null:
			damage_parameter = str(weapon.get("damage_parameter"))
		weapon.set("damage", float(derived_parameters.get(damage_parameter, weapon.get_meta("base_damage"))))

	if weapon.get("fire_interval") != null:
		var attack_speed := float(derived_parameters.get("attack_speed", 1.0))
		var base_fire_interval := float(weapon.get_meta("base_fire_interval", 1.0))
		weapon.set("fire_interval", max(0.18, base_fire_interval / max(attack_speed, 0.1)))

	if weapon.get("attack_range") != null:
		var base_attack_range := float(weapon.get_meta("base_attack_range"))
		var scaled_attack_range := float(derived_parameters.get("attack_range", base_attack_range))
		weapon.set("attack_range", scaled_attack_range)
		var width_scale: float = scaled_attack_range / max(base_attack_range, 1.0)
		if weapon.get("inner_width") != null:
			weapon.set("inner_width", float(weapon.get_meta("base_inner_width")) * min(width_scale, 1.35))
		if weapon.get("outer_width") != null:
			weapon.set("outer_width", float(weapon.get_meta("base_outer_width")) * width_scale)

	if weapon.get("aoe_radius") != null:
		weapon.set("aoe_radius", float(derived_parameters.get("aoe_radius", weapon.get_meta("base_aoe_radius", 200.0))))

	if weapon.get("projectile_speed") != null:
		weapon.set("projectile_speed", float(derived_parameters.get("projectile_speed", weapon.get_meta("base_projectile_speed", 520.0))))

	if weapon.get("knockback") != null:
		weapon.set("knockback", float(derived_parameters.get("knockback_power", weapon.get_meta("base_knockback", 80.0))))

	if weapon.get("beam_width") != null and weapon.has_meta("base_beam_width"):
		weapon.set("beam_width", float(weapon.get_meta("base_beam_width")) * max(float(derived_parameters.get("aoe_radius", 1.0)) / max(float(weapon.get_meta("base_aoe_radius", 1.0)), 1.0), 0.75))

	if weapon.get("wave_width") != null and weapon.has_meta("base_wave_width"):
		weapon.set("wave_width", float(weapon.get_meta("base_wave_width")) * max(float(derived_parameters.get("aoe_radius", 1.0)) / max(float(weapon.get_meta("base_aoe_radius", 1.0)), 1.0), 0.75))

	if weapon.get("suppression_width") != null and weapon.has_meta("base_suppression_width"):
		weapon.set("suppression_width", float(weapon.get_meta("base_suppression_width")) * max(float(derived_parameters.get("aoe_radius", 1.0)) / max(float(weapon.get_meta("base_aoe_radius", 1.0)), 1.0), 0.75))

	if weapon.get("max_summons") != null:
		var base_max_summons := int(weapon.get_meta("base_max_summons"))
		weapon.set("max_summons", base_max_summons + int(floor(float(stats.get("leadership", 0.0)) / 4.0)) + int(run_modifiers.get("summon_bonus", 0.0)))


func _equipped_weapons() -> Array:
	var weapons := []
	var socket := _weapon_socket()
	if socket != null:
		for child in socket.get_children():
			if child.is_in_group("player_weapons"):
				weapons.append(child)
	for child in get_children():
		if child.is_in_group("player_weapons"):
			weapons.append(child)
	return weapons


func _capture_weapon_base_values(weapon: Node) -> void:
	if weapon.get("damage") != null and not weapon.has_meta("base_damage"):
		weapon.set_meta("base_damage", weapon.get("damage"))
	if weapon.get("fire_interval") != null and not weapon.has_meta("base_fire_interval"):
		weapon.set_meta("base_fire_interval", weapon.get("fire_interval"))
	if weapon.get("attack_range") != null and not weapon.has_meta("base_attack_range"):
		weapon.set_meta("base_attack_range", weapon.get("attack_range"))
	if weapon.get("aoe_radius") != null and not weapon.has_meta("base_aoe_radius"):
		weapon.set_meta("base_aoe_radius", weapon.get("aoe_radius"))
	if weapon.get("inner_width") != null and not weapon.has_meta("base_inner_width"):
		weapon.set_meta("base_inner_width", weapon.get("inner_width"))
	if weapon.get("outer_width") != null and not weapon.has_meta("base_outer_width"):
		weapon.set_meta("base_outer_width", weapon.get("outer_width"))
	if weapon.get("max_summons") != null and not weapon.has_meta("base_max_summons"):
		weapon.set_meta("base_max_summons", weapon.get("max_summons"))
	if weapon.get("projectile_speed") != null and not weapon.has_meta("base_projectile_speed"):
		weapon.set_meta("base_projectile_speed", weapon.get("projectile_speed"))
	if weapon.get("beam_width") != null and not weapon.has_meta("base_beam_width"):
		weapon.set_meta("base_beam_width", weapon.get("beam_width"))
	if weapon.get("wave_width") != null and not weapon.has_meta("base_wave_width"):
		weapon.set_meta("base_wave_width", weapon.get("wave_width"))
	if weapon.get("knockback") != null and not weapon.has_meta("base_knockback"):
		weapon.set_meta("base_knockback", weapon.get("knockback"))


func _ensure_default_input_actions() -> void:
	_ensure_key_action("move_up", [KEY_W, KEY_UP])
	_ensure_key_action("move_down", [KEY_S, KEY_DOWN])
	_ensure_key_action("move_left", [KEY_A, KEY_LEFT])
	_ensure_key_action("move_right", [KEY_D, KEY_RIGHT])


func _ensure_key_action(action_name: String, keycodes: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	if not InputMap.action_get_events(action_name).is_empty():
		return

	for keycode in keycodes:
		var event := InputEventKey.new()
		event.keycode = keycode
		InputMap.action_add_event(action_name, event)


func _update_movement_animation(delta: float) -> void:
	var body := _animated_sprite()
	if body == null:
		return

	var body_action_locked := _body_action_time_left > 0.0
	if body_action_locked:
		_body_action_time_left = maxf(_body_action_time_left - delta, 0.0)
		body_action_locked = _body_action_time_left > 0.0
	if velocity.length_squared() > 0.0:
		_animation_time += delta * 10.0
		_facing_direction = velocity.normalized()
		_movement_offset = Vector2(0.0, sin(_animation_time) * 3.0)
		_movement_rotation = clamp(velocity.x / max(speed, 1.0), -1.0, 1.0) * 0.12
		_movement_scale_delta = Vector2(sin(_animation_time) * 0.025, -sin(_animation_time) * 0.018)
		var move_animation := _body_directional_animation_name(body, "walk", _facing_direction)
		if not body_action_locked and body.animation != move_animation:
			body.play(move_animation)
		_update_sprite_facing(_facing_direction)
	else:
		_movement_offset = _movement_offset.lerp(Vector2.ZERO, 10.0 * delta)
		_movement_rotation = lerpf(_movement_rotation, 0.0, 10.0 * delta)
		_movement_scale_delta = _movement_scale_delta.lerp(Vector2.ZERO, 10.0 * delta)
		var idle_animation := _body_directional_animation_name(body, "idle", _facing_direction)
		if not body_action_locked and body.animation != idle_animation:
			body.play(idle_animation)

	var rig := _cutout_rig()
	if rig != null and rig.has_method("update_animation"):
		rig.update_animation(delta, velocity, _facing_direction)
	var skeletal_rig := _skeletal_rig()
	if skeletal_rig != null and skeletal_rig.has_method("update_animation"):
		skeletal_rig.update_animation(delta, velocity, _facing_direction)
	_apply_sprite_transform()


func _update_sprite_facing(direction: Vector2) -> void:
	var body := _animated_sprite()
	if body == null:
		return
	if _is_directional_body_animation(str(body.animation)):
		body.flip_h = false
		return
	if abs(direction.x) > 0.05:
		body.flip_h = direction.x < 0.0


func _body_directional_animation_name(body: AnimatedSprite2D, base_name: String, direction: Vector2) -> String:
	if body == null or body.sprite_frames == null:
		return base_name
	var suffix := _directional_animation_suffix(direction)
	var directional_name := "%s_%s" % [base_name, suffix]
	if body.sprite_frames.has_animation(directional_name):
		return directional_name
	if base_name == "walk":
		var move_name := "move_%s" % suffix
		if body.sprite_frames.has_animation(move_name):
			return move_name
	elif base_name == "move":
		var walk_name := "walk_%s" % suffix
		if body.sprite_frames.has_animation(walk_name):
			return walk_name
	if body.sprite_frames.has_animation(base_name):
		return base_name
	return str(body.animation)


func _directional_animation_suffix(direction: Vector2) -> String:
	if direction.length_squared() <= 0.001:
		return "south"
	var sector_count := DIRECTIONAL_ANIMATION_SUFFIXES.size()
	var sector_size := TAU / float(sector_count)
	var index := int(floor((direction.angle() + sector_size * 0.5) / sector_size))
	index = posmod(index, sector_count)
	return str(DIRECTIONAL_ANIMATION_SUFFIXES[index])


func _is_directional_body_animation(animation_name: String) -> bool:
	for suffix in DIRECTIONAL_ANIMATION_SUFFIXES:
		if animation_name.ends_with("_%s" % suffix):
			return true
	return false


func _apply_sprite_transform() -> void:
	var visual_root := _visual_root()
	if visual_root == null:
		return

	visual_root.position = Vector2.ZERO
	visual_root.rotation = 0.0
	visual_root.scale = Vector2.ONE

	var weapon_socket := _weapon_socket()
	if weapon_socket != null:
		var orbit_direction := _weapon_orbit_direction()
		weapon_socket.position = _weapon_orbit_position(orbit_direction)
		weapon_socket.rotation = orbit_direction.angle()
		weapon_socket.scale = Vector2.ONE
		_configure_weapon_socket_layer(weapon_socket)
		weapon_socket.set_meta("weapon_orbit_direction", orbit_direction)


func _weapon_orbit_direction() -> Vector2:
	var direction := _facing_direction
	if equipped_weapon != null and is_instance_valid(equipped_weapon):
		var weapon_direction = equipped_weapon.get("_last_direction")
		if weapon_direction is Vector2 and (weapon_direction as Vector2).length_squared() > 0.001:
			direction = weapon_direction
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	return attack_aim_direction(direction, float(weapon_config.get("attack_range", 999999.0)))


func _weapon_orbit_position(direction: Vector2) -> Vector2:
	var normalized := direction.normalized()
	if normalized.length_squared() <= 0.001:
		normalized = Vector2.RIGHT
	return normalized * WEAPON_ORBIT_RADIUS + Vector2(0.0, WEAPON_ORBIT_VERTICAL_BIAS)


func _play_hit_feedback() -> void:
	var body := _animated_sprite()
	if body == null:
		return
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	body.modulate = Color(1.0, 0.35, 0.35, 1.0)
	var rig := _cutout_rig()
	if rig != null and rig.has_method("play_hit"):
		rig.play_hit()
	var skeletal_rig := _skeletal_rig()
	if skeletal_rig != null and skeletal_rig.has_method("play_hit"):
		skeletal_rig.play_hit()
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(body, "modulate", Color.WHITE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _show_dodge_popup() -> void:
	if not is_inside_tree():
		return
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	var popup := Label.new()
	popup.text = "Промах!"
	popup.z_index = 40
	popup.add_theme_font_size_override("font_size", 22)
	popup.add_theme_color_override("font_color", Color(0.78, 0.92, 1.0, 1.0))
	popup.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.16, 1.0))
	popup.add_theme_constant_override("outline_size", 5)
	parent.add_child(popup)
	popup.global_position = global_position + Vector2(-32.0, -64.0)
	var tween := popup.create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "global_position", popup.global_position + Vector2(0.0, -34.0), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(popup.queue_free)


var _cached_audio: Node = null


func _play_sfx(sfx_id: String) -> void:
	if not is_inside_tree():
		return
	if _cached_audio == null or not is_instance_valid(_cached_audio):
		_cached_audio = get_node_or_null("/root/AudioManager")
	if _cached_audio != null and _cached_audio.has_method("play_sfx"):
		_cached_audio.play_sfx(sfx_id)


func _visual_root() -> Node2D:
	return get_node_or_null("VisualRoot") as Node2D


func _animated_sprite() -> AnimatedSprite2D:
	return get_node_or_null("VisualRoot/Body") as AnimatedSprite2D


func _cutout_rig() -> Node2D:
	return get_node_or_null("VisualRoot/RigRoot") as Node2D


func _skeletal_rig() -> Node2D:
	return get_node_or_null("VisualRoot/SkeletalRigRoot") as Node2D


func _configure_player_rig(config: Dictionary, show_cutout := true) -> void:
	var visual_root := _visual_root()
	if visual_root == null:
		return
	var rig := _cutout_rig()
	if rig == null:
		rig = Node2D.new()
		rig.name = "RigRoot"
		rig.set_script(CUTOUT_RIG_SCRIPT)
		visual_root.add_child(rig)
	var texture := config.get("sprite", BERSERK_SPRITE) as Texture2D
	var is_cartoon: bool = character_id in CARTOON_TRIAL_CLASSES
	if rig.has_method("configure"):
		# CARTOON-проба: суффикс профиля уводит риг на legacy (целый спрайт), без
		# v2-боксов нарезки, не подходящих cartoon-пропорциям; cartoon чуть мельче (SCRUM-472).
		var rig_profile: String = character_id + "_cartoon" if is_cartoon else character_id
		var rig_scale: Vector2 = (BASE_SPRITE_SCALE * CARTOON_TRIAL_SCALE) if is_cartoon else BASE_SPRITE_SCALE
		rig.configure(texture, rig_scale, rig_profile, {"is_player": true})
	if is_cartoon:
		# Лёгкий разворот cartoon-спрайта вокруг своей оси — не строго анфас (SCRUM-472).
		var hero_full := rig.get_node_or_null("Pelvis/HeroFull") as Node2D
		if hero_full != null:
			hero_full.rotation = deg_to_rad(CARTOON_TRIAL_TILT_DEG)
	rig.visible = show_cutout


func _configure_skeletal_player_rig(skeleton_scene: PackedScene) -> void:
	var visual_root := _visual_root()
	if visual_root == null:
		return
	var existing := _skeletal_rig()
	if existing != null:
		visual_root.remove_child(existing)
		existing.queue_free()
	if skeleton_scene == null:
		_uses_skeletal_visual = false
		return
	var rig := skeleton_scene.instantiate() as Node2D
	if rig == null:
		_uses_skeletal_visual = false
		return
	rig.name = "SkeletalRigRoot"
	rig.z_index = 0
	visual_root.add_child(rig)
	rig.visible = true
	if rig.has_method("configure"):
		var manifest := str(rig.get("manifest_path"))
		rig.configure(manifest, character_id, BASE_SPRITE_SCALE)
	if rig.has_method("update_animation"):
		rig.update_animation(0.0, Vector2.ZERO, _facing_direction)


func _character_skeleton_rig_scene(class_id: String) -> PackedScene:
	match class_id:
		"knight":
			return KNIGHT_SKELETON_RIG_SCENE
	return null


func _character_sprite_frames(config: Dictionary) -> SpriteFrames:
	var full_frame_frames := _character_full_frame_sprite_frames(character_id)
	if full_frame_frames != null:
		return full_frame_frames
	if character_id == "berserk":
		return _berserk_sprite_frames()
	return _single_texture_sprite_frames(config["sprite"])


func _character_full_frame_sprite_frames(class_id: String) -> SpriteFrames:
	var resource_frames := _character_resource_sprite_frames(class_id)
	if resource_frames != null:
		return resource_frames
	return _character_sheet_sprite_frames(class_id)


func _character_resource_sprite_frames(class_id: String) -> SpriteFrames:
	var frames_path := "res://assets/sprites/characters/%s_spriteframes.tres" % class_id
	if not ResourceLoader.exists(frames_path):
		return null
	return load(frames_path) as SpriteFrames


func _character_sheet_sprite_frames(class_id: String) -> SpriteFrames:
	var sheet_path := "res://assets/sprites/characters/%s_sheet.png" % class_id
	if not ResourceLoader.exists(sheet_path):
		return null
	var texture := load(sheet_path) as Texture2D
	if texture == null:
		return null
	return _sprite_frames_from_character_sheet(texture, {
		"frame_size": CHARACTER_SHEET_FRAME_SIZE,
		"columns": CHARACTER_SHEET_COLUMNS,
		"idle_fps": 5.0,
		"walk_fps": 10.0,
		"attack_fps": 14.0,
	})


func _sprite_frames_from_character_sheet(texture: Texture2D, sheet_config: Dictionary = {}) -> SpriteFrames:
	if texture == null:
		return null
	var frame_size: Vector2i = sheet_config.get("frame_size", CHARACTER_SHEET_FRAME_SIZE)
	var columns := int(sheet_config.get("columns", CHARACTER_SHEET_COLUMNS))
	if frame_size.x <= 0 or frame_size.y <= 0 or columns <= 0:
		return null
	var rows := int(floor(float(texture.get_height()) / float(frame_size.y)))
	var available_columns := int(floor(float(texture.get_width()) / float(frame_size.x)))
	columns = min(columns, available_columns)
	if rows < 2 or columns <= 0:
		return null

	var has_idle_row := rows >= 3
	var idle_row := 0
	var walk_row := 1 if has_idle_row else 0
	var attack_row := 2 if has_idle_row else 1
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	_add_sheet_animation(frames, "idle", texture, idle_row, 1 if not has_idle_row else columns, frame_size, true, float(sheet_config.get("idle_fps", 5.0)))
	_add_sheet_animation(frames, "walk", texture, walk_row, columns, frame_size, true, float(sheet_config.get("walk_fps", 10.0)))
	_add_sheet_animation(frames, "attack_primary", texture, attack_row, columns, frame_size, false, float(sheet_config.get("attack_fps", 14.0)))
	_add_sheet_animation(frames, "attack", texture, attack_row, columns, frame_size, false, float(sheet_config.get("attack_fps", 14.0)))
	return frames


func _add_sheet_animation(frames: SpriteFrames, animation_name: String, texture: Texture2D, row: int, frame_count: int, frame_size: Vector2i, loop: bool, fps: float) -> void:
	if frames.has_animation(animation_name):
		frames.remove_animation(animation_name)
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, loop)
	frames.set_animation_speed(animation_name, fps)
	for frame_index in range(maxi(frame_count, 1)):
		frames.add_frame(animation_name, _atlas_frame(texture, frame_index, row, frame_size))


func _berserk_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 3.0)
	for frame_index in range(2):
		frames.add_frame("idle", _atlas_frame(BERSERK_ANIMATED_SPRITE, frame_index, 0, BERSERK_ANIMATION_FRAME_SIZE))

	frames.add_animation("walk")
	frames.set_animation_loop("walk", true)
	frames.set_animation_speed("walk", 10.0)
	for frame_index in range(6):
		frames.add_frame("walk", _atlas_frame(BERSERK_ANIMATED_SPRITE, frame_index, 1, BERSERK_ANIMATION_FRAME_SIZE))
	for animation_name in ["attack_primary", "attack"]:
		frames.add_animation(animation_name)
		frames.set_animation_loop(animation_name, false)
		frames.set_animation_speed(animation_name, 14.0)
		for frame_index in range(5):
			frames.add_frame(animation_name, _atlas_frame(BERSERK_ANIMATED_SPRITE, frame_index, 1, BERSERK_ANIMATION_FRAME_SIZE))
	return frames


func _single_texture_sprite_frames(texture: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for animation_name in ["idle", "walk"]:
		frames.add_animation(animation_name)
		frames.set_animation_loop(animation_name, true)
		frames.set_animation_speed(animation_name, 1.0)
		frames.add_frame(animation_name, texture)
	for animation_name in ["attack_primary", "attack"]:
		frames.add_animation(animation_name)
		frames.set_animation_loop(animation_name, false)
		frames.set_animation_speed(animation_name, 1.0)
		frames.add_frame(animation_name, texture)
	return frames


func _play_body_action_animation(action_id: String, duration := 0.0) -> void:
	# Анимация атаки ОТКЛЮЧЕНА (запрос пользователя 2026-06-15): attack/attack_primary
	# кадры не используем — тело остаётся на walk/idle при атаке. Чтобы вернуть —
	# поставить USE_ATTACK_ANIMATION = true.
	if not USE_ATTACK_ANIMATION:
		return
	var body := _animated_sprite()
	if body == null or body.sprite_frames == null:
		return
	var animation_name := "attack"
	if not body.sprite_frames.has_animation(animation_name):
		animation_name = "attack_primary"
	if not body.sprite_frames.has_animation(animation_name):
		return
	body.play(animation_name)
	var frame_count: int = maxi(body.sprite_frames.get_frame_count(animation_name), 1)
	var fps := maxf(body.sprite_frames.get_animation_speed(animation_name), 1.0)
	_body_action_time_left = maxf(maxf(duration, float(frame_count) / fps), 0.12)


func _atlas_frame(texture: Texture2D, column: int, row: int, frame_size: Vector2i) -> AtlasTexture:
	var frame := AtlasTexture.new()
	frame.atlas = texture
	frame.region = Rect2(Vector2(column * frame_size.x, row * frame_size.y), frame_size)
	return frame
