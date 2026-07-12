extends CharacterBody2D

const SemanticTypography := preload("res://scripts/ui/semantic_typography.gd")

# SCRUM-611: мягкий радиальный тик попадания вместо квадратной красной рамки.
const HIT_FLASH_TEXTURE := preload("res://assets/sprites/effects/impact_flash.png")

signal died(enemy: Node2D)
# Фазы уникальной атаки элитки для Animator: windup -> strike -> recover -> idle.
signal elite_attack_phase_changed(attack_id: String, phase: String)

@export var enemy_type_name := "Basic"
@export var is_flying := false
@export var max_health := 3.0
@export var move_speed := 90.0
@export var can_shoot := false
@export var projectile_scene: PackedScene
@export var can_summon := false
@export var summoned_enemy_scene: PackedScene
@export var fire_interval := 1.5
@export var summon_interval := 3.4
@export var projectile_damage := 1.0
@export var projectile_speed := 360.0
@export var contact_damage := 1.0
@export var contact_range := 34.0
@export var contact_interval := 0.85
@export var contact_windup_time := 0.22
@export var desired_shooting_distance := 280.0
@export var desired_summoning_distance := 240.0
@export var max_active_summons := 4
@export var reward_xp := 1
@export var reward_money := 1
@export var elite_behavior := ""
@export var elite_shield_damage_reduction := 0.42
@export var elite_dash_speed_multiplier := 3.1
@export var elite_dash_duration := 0.34
@export var elite_hazard_damage := 2.0

var health := 0.0
var _shoot_cooldown := 0.0
# SCRUM-498: сколько ещё секунд враг считается «активно ведущим огонь» после выстрела —
# питает off-screen threat-маркер только реально стреляющих дальнобоев.
const THREAT_FIRE_MARKER_DURATION := 2.6
var _threat_fire_marker_left := 0.0
var _summon_cooldown := 0.0
var _contact_cooldown := 0.0
var _contact_windup_left := -1.0
var _animation_time := 0.0
var _elite_shield_cooldown := 4.2
var _elite_shield_time_left := 0.0
var _elite_dash_cooldown := 2.8
var _elite_dash_time_left := 0.0
var _elite_dash_direction := Vector2.ZERO
var _elite_hazard_cooldown := 3.4
var _elite_aura_cooldown := 3.2
var _elite_shield_active := false
var _rig_source_scale := Vector2.ZERO
var _knockback_velocity := Vector2.ZERO
# Combat Feel Rework (этап B): состояние движения — гистерезис отхода из
# глубокого оверлапа, знаки орбиты/строба (пер-инстанс из id, пачки расползаются
# в обе стороны) и кэш steering-сепарации от соседей по группе enemies.
var _melee_backoff_active := false
var _orbit_sign := 1.0
var _strafe_sign := 1.0
var _strafe_flip_left := 3.0
var _strafe_bound_flip_done := false
var _separation_neighbors: Array = []
var _separation_scratch_dist: Array = []
var _separation_refresh_left := 0.0
var _separation_weight := 1.0
var _separation_radius := 32.0
var _cached_player: Node2D = null
var _cached_body: Sprite2D = null
var _cached_rig: Node2D = null
var _cached_full_frame_body: AnimatedSprite2D = null
var _cached_audio: Node = null
var _death_lifecycle_started := false
var elite_attack_state := "idle"
var elite_attack_id := ""
var _elite_attack_cooldown := 0.0
var _elite_attack_phase_left := 0.0
var _elite_attack_targets := []
var _elite_attack_direction := Vector2.RIGHT
var _elite_instant_phase_applied := false

const COLLISION_LAYER_PLAYER := 1
const COLLISION_LAYER_GROUND_ENEMY := 2
const COLLISION_LAYER_FLYING_ENEMY := 4
const COLLISION_LAYER_SOLID := 32
const ARENA_SIZE := Vector2(4096, 2304)  # SCRUM-518: синхронно с main.gd (×1.6)
const ARENA_ENTITY_MARGIN := 48.0
const CUTOUT_RIG_SCRIPT := preload("res://scripts/cutout_rig_2d.gd")
const HEALTH_BAR_SCRIPT := preload("res://scripts/enemy_health_bar.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")
const GAMEPLAY_SANDBOX := preload("res://scripts/gameplay_sandbox.gd")
const FullFrameAnimationRegistry := preload("res://scripts/full_frame_animation_registry.gd")
const ENEMY_PROJECTILE_SCENE := preload("res://scenes/EnemyProjectile.tscn")
const ELITE_TELEGRAPH_TEXTURE := preload("res://assets/sprites/effects/elite_telegraph_circle.png")
const POISON_POOL_TEXTURE := preload("res://assets/sprites/effects/poison_pool.png")
const ELITE_SHOCKWAVE_TEXTURE := preload("res://assets/sprites/effects/elite_shockwave_ring.png")
const ELITE_SHADOW_TRAIL_TEXTURE := preload("res://assets/sprites/effects/elite_shadow_trail.png")
const ELITE_POISON_LOB_TEXTURE := preload("res://assets/sprites/effects/elite_poison_lob.png")
const ELITE_CRYSTAL_SHARD_TEXTURE := preload("res://assets/sprites/effects/elite_crystal_shard.png")
const ELITE_SHADOW_MARK_TEXTURE := preload("res://assets/sprites/effects/enemy_shadow_blink_mark.png")
const ELITE_SHARD_FAN_BURST_TEXTURE := preload("res://assets/sprites/effects/enemy_shard_fan_burst.png")

# Половина видимой ширины игрока: contact_range считается как сумма радиусов.
const PLAYER_CONTACT_PADDING := 26.0
# Combat Feel Rework (этап B): анти-прилипание — полосы поведения melee вместо
# «едем в точный центр игрока». engage-кольцо ВСЕГДА внутри contact_range
# (уптайм контактного урона — жёсткий контракт TTK-гейтов и smoke-тестов).
const MELEE_ENGAGE_RATIO := 0.8            # engage = 0.8×contact_range
const MELEE_DECELERATION_BAND := 60.0      # полоса плавного торможения перед engage, px
const MELEE_APPROACH_MIN_FACTOR := 0.35    # скорость у самой кромки engage
const MELEE_ORBIT_SPEED_FACTOR := 0.25     # тангенциальный дрейф на кольце
const MELEE_BACKOFF_SPEED_FACTOR := 0.45   # мягкий отход из глубокого оверлапа
const MELEE_BACKOFF_ENTER_RATIO := 0.62    # d < 0.62×engage → начать отход
const MELEE_BACKOFF_EXIT_RATIO := 0.75     # отход до 0.75×engage (= 0.6×contact_range, замах не рвётся)
# Стрелки/саммонеры: вместо freeze в hold-полосе — медленный тангенциальный строб
# с гистерезисом (убирает дребезг «стоп/шаг» на кромке полосы).
const RANGED_RETREAT_RATIO := 0.78         # d < 0.78×desired → отходим
const RANGED_APPROACH_RATIO := 0.92        # d > 0.92×desired → подходим
const RANGED_STRAFE_SPEED_FACTOR := 0.4    # скорость строба в hold-полосе
const STRAFE_FLIP_INTERVAL_MIN := 2.5      # пер-инстансный таймер смены направления строба
const STRAFE_FLIP_INTERVAL_MAX := 4.0
const STRAFE_BOUND_MARGIN := 120.0         # у кромки арены — разворот строба
# Сепарация врагов: только steering (БЕЗ физики — контракт «игрок проходит сквозь»).
const SEPARATION_REFRESH_INTERVAL := 0.2   # пересчёт кэша соседей, s (со stagger по id)
const SEPARATION_MAX_NEIGHBORS := 4        # держим 3-4 ближайших
const SEPARATION_MAX_RANGE := 90.0         # кап радиуса расталкивания, px
const SEPARATION_SEARCH_SLACK := 50.0      # запас поиска: соседи двигаются между рефрешами
const SEPARATION_MAX_SPEED := 90.0         # потолок push-скорости, px/s
const SEPARATION_ELITE_WEIGHT := 0.4       # элитки толкаются слабее; боссы (0.0) — никогда
# «Клюнул и ударил»: на время замаха контакт-удара steering падает до 20%.
const CONTACT_WINDUP_STEERING_FACTOR := 0.2
# Читаемый нокбек: вес chase-вклада = clamp(1 − |kb|/300, 0, 1).
const KNOCKBACK_STEERING_SUPPRESS_SPEED := 300.0
# Спавн-защита: миньоны саммонера/рифтлинги босса не появляются вплотную к игроку.
const MINION_SPAWN_MIN_PLAYER_DISTANCE := 140.0
# Combat Feel Rework (этап A): feet-origin визуал + тень-круг под ногами.
# Origin узла не двигается — поднимается только фолбэк-визуал (cutout/статический
# спрайт центрирован по арту, ноги ~на 0.38 высоты ниже центра). Живой full-frame
# путь уже feet-anchored ручными offsets в full_frame_animation_registry.
const STATIC_VISUAL_FEET_LIFT_RATIO := 0.38
const GROUND_CIRCLE_Z_INDEX := -8
const GROUND_CIRCLE_SEGMENTS := 32
const GROUND_CIRCLE_WIDTH_FACTOR := 0.34   # доля видимой ширины (полная ширина эллипса)
const GROUND_CIRCLE_HEIGHT_RATIO := 0.32
const GROUND_CIRCLE_ALPHA := 0.16
const GROUND_CIRCLE_BOSS_ALPHA := 0.20
const FULL_FRAME_DEATH_DURATION_FALLBACK := 0.62
const COMBAT_FEEDBACK_LABEL_GROUP := "combat_feedback_labels"
const COMBAT_FEEDBACK_FLASH_GROUP := "combat_feedback_flashes"
const COMBAT_FEEDBACK_MAX_LABELS := 42
const COMBAT_FEEDBACK_MAX_FLASHES := 36
# SCRUM-523: ЕДИНЫЙ источник правды палитры боевых цифр по ТИПУ урона.
# Цвет привязан к КАНАЛУ урона (физический/магический/периодический-DoT/
# чистый-true), НЕ к классу или оружию — бой читается одинаково во всех схватках.
# SCRUM-898: звуковой канал удалён — бывшие sound-оружия бьют магией.
# Итог по цели = сумма типизированных попаданий; каждый вызов take_damage с
# feedback{"damage_type"} порождает отдельную цветную цифру, поэтому виден вклад
# каждого типа. Враг (этот файл) — единственный, кто рисует боевые цифры; игрок
# своих цифр не спавнит. Третьих копий палитры не заводить: все системы
# (class_weapon/status_effects/boss-наследник) передают строковый damage_type во
# feedback, а цвет берут через статический Enemy.damage_type_color(). Документация —
# docs/design/systems/combat.md, раздел «Типы урона и палитра боевых цифр».
const COMBAT_FEEDBACK_DAMAGE_COLORS := {
	"physical": Color(1.0, 0.84, 0.42, 1.0),
	"magic": Color(0.68, 0.46, 1.0, 1.0),
	"dot": Color(0.46, 1.0, 0.42, 1.0),
	"true": Color(1.0, 0.96, 0.82, 1.0),
}


# Единый доступ к палитре. Неизвестный/непроставленный тип → "true" (чистый/белый).
# static — инстанс врага не нужен (зовётся из тестов/оружия/статусов).
static func damage_type_color(damage_type) -> Color:
	return COMBAT_FEEDBACK_DAMAGE_COLORS.get(str(damage_type), COMBAT_FEEDBACK_DAMAGE_COLORS["true"])


# SCRUM-968: маппинг типа урона -> SFX попадания (спека §5). Дефолт (physical/
# true/неизвестный) — глухой "hit"; static для headless focused-теста.
static func hit_sfx_for_damage_type(damage_type: String) -> String:
	match damage_type:
		"magic":
			return "hit_magic"
		"dot":
			return "hit_dot"
		_:
			return "hit"

# Epic-масштаб узла: визуал (rig — ребёнок), CollisionShape2D (ребёнок) и
# contact_range/health-bar (через _visible_sprite_size, учитывает scale) растут
# согласованно одним множителем. Профиль задается data-driven через
# ProgressionData.ENEMY_SIZE_PROFILES и meta `epic_scale_profile`.
const EPIC_SCALE_PROFILE_META := "epic_scale_profile"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("enemies")
	_apply_collision_profile()
	_apply_gameplay_sandbox_runtime()
	health = max_health
	_shoot_cooldown = fire_interval
	_summon_cooldown = summon_interval
	if elite_behavior == "" and is_in_group("elite_enemies"):
		elite_behavior = enemy_type_name.to_lower().replace(" ", "_")
	if elite_behavior != "":
		set_meta("elite_behavior", elite_behavior)
		_apply_unique_encounter_pattern_meta(elite_behavior)
	_apply_epic_scale()
	if not _configure_full_frame_animation():
		_configure_enemy_rig()
	_fit_contact_range_to_sprite()
	# Combat Feel Rework (этап B): пер-инстансные знаки орбиты/строба из чётности
	# instance id (детерминированный разъезд пачек в обе стороны) + видимый радиус
	# для сепарации (после fit/epic scale) + stagger рефреша кэша соседей, чтобы
	# 48 мобов не сканировали группу в один и тот же кадр.
	_orbit_sign = 1.0 if get_instance_id() % 2 == 0 else -1.0
	_strafe_sign = 1.0 if (get_instance_id() >> 1) % 2 == 0 else -1.0
	_strafe_flip_left = randf_range(STRAFE_FLIP_INTERVAL_MIN, STRAFE_FLIP_INTERVAL_MAX)
	var visible_size := _visible_sprite_size()
	_separation_radius = maxf(visible_size.x, visible_size.y) * 0.5
	_separation_refresh_left = float(get_instance_id() % 199) * 0.001
	_create_health_bar()
	_ensure_ground_circle()
	var config := _elite_attack_config()
	if not config.is_empty():
		elite_attack_id = str(config.get("attack_id", ""))
		_elite_attack_cooldown = randf_range(2.2, 3.6)


func _apply_unique_encounter_pattern_meta(entity_id: String) -> void:
	var pattern := ProgressionData.unique_encounter_pattern(entity_id)
	if pattern.is_empty():
		return
	set_meta("unique_pattern_id", entity_id)
	set_meta("unique_pattern_title", str(pattern.get("title", "")))
	set_meta("unique_mechanics", (pattern.get("mechanics", []) as Array).duplicate())


func _elite_attack_config() -> Dictionary:
	return ProgressionData.elite_attack_config(elite_behavior)


func _epic_scale_factor() -> float:
	var profile_id := _epic_scale_profile_id()
	var profile: Dictionary = ProgressionData.enemy_size_profile(profile_id)
	return float(profile.get("scale", 1.0))


func _epic_scale_profile_id() -> String:
	if has_meta(EPIC_SCALE_PROFILE_META):
		return str(get_meta(EPIC_SCALE_PROFILE_META, "ordinary"))
	var lname := enemy_type_name.to_lower()
	if lname.contains("warden") or lname.contains("devourer") or is_in_group("bosses"):
		return "boss"
	if is_in_group("elite_enemies") or elite_behavior != "":
		return "elite"
	return "ordinary"


func _apply_epic_scale() -> void:
	# Элитки/боссы крупнее и страшнее: один node scale тянет визуал, хитбокс,
	# contact_range и health-bar вместе — «урона по воздуху» по гиганту не будет.
	var factor := _epic_scale_factor()
	if is_equal_approx(factor, 1.0):
		return
	scale = Vector2(factor, factor)


func _apply_collision_profile() -> void:
	if is_flying:
		collision_layer = COLLISION_LAYER_FLYING_ENEMY
		collision_mask = COLLISION_LAYER_SOLID
		var body := get_node_or_null("Body") as Sprite2D
		if body != null:
			body.modulate = Color(0.72, 0.92, 1.0, 1.0)
	else:
		collision_layer = COLLISION_LAYER_GROUND_ENEMY
		collision_mask = COLLISION_LAYER_SOLID


func _physics_process(delta: float) -> void:
	StatusEffects.tick(self, delta)
	# SCRUM-498: окно «недавно стрелял» для off-screen threat-маркера дальнобоев.
	if _threat_fire_marker_left > 0.0:
		_threat_fire_marker_left = maxf(0.0, _threat_fire_marker_left - delta)
	var target := _combat_target()
	if target == null:
		velocity = _consume_knockback(delta)
		move_and_slide()
		return

	var direction := target.global_position - global_position
	var distance := direction.length()

	# SCRUM-913: жёсткий паралич (капкан Рейнджера, movement_locked-статус) —
	# жертва полностью стоит: перемещение, рывки, стрельба и призыв заморожены
	# до истечения статуса; двигают её только внешние импульсы apply_knockback.
	# Контактный урон СОХРАНЯЕТСЯ — наступать на захлопнутого врага всё ещё
	# больно. Конечность: длительность статуса конечна, у боссов/элит срезана
	# контроль-резистом источника (×0.25) — пермалок невозможен.
	if StatusEffects.is_movement_locked(self):
		velocity = _consume_knockback(delta)
		move_and_slide()
		global_position = _clamp_to_arena(global_position)
		_update_movement_animation(delta)
		_update_contact_damage(delta, target, distance)
		return

	if _update_elite_dash(delta, target, distance):
		move_and_slide()
		global_position = _clamp_to_arena(global_position)
		_update_movement_animation(delta)
		_update_contact_damage(delta, target, distance)
		return

	if _update_elite_attack(delta, target, distance):
		velocity = Vector2.ZERO
		move_and_slide()
		_update_movement_animation(delta)
		return

	# Combat Feel Rework (этап B): анти-прилипание. Вместо «едем в точный центр
	# игрока» — полосы поведения (подход → торможение → тангенциальный дрейф у
	# engage-кольца → мягкий отход из глубокого оверлапа), steering-сепарация от
	# соседей (без физики) и строб дальнобоев вместо freeze. Во время замаха
	# контакт-удара steering гасится («клюнул и ударил»), нокбек применяется
	# полностью и подавляет chase-вклад весом — удары реально отбрасывают.
	_tick_separation_cache(delta)
	var status_speed := StatusEffects.speed_multiplier(self)
	var steering := _band_steering(direction, distance, move_speed * status_speed, delta)
	steering += _separation_velocity()
	if _contact_windup_left >= 0.0:
		steering *= CONTACT_WINDUP_STEERING_FACTOR
	var knockback := _consume_knockback(delta)
	var knockback_weight := clampf(1.0 - knockback.length() / KNOCKBACK_STEERING_SUPPRESS_SPEED, 0.0, 1.0)
	velocity = steering * knockback_weight + knockback
	move_and_slide()
	global_position = _clamp_to_arena(global_position)
	_update_movement_animation(delta)
	_update_contact_damage(delta, target, distance)
	_update_shooting(delta, target)
	_update_summoning(delta)
	_update_elite_patterns(delta, target, distance)


# --- Combat Feel Rework (этап B): steering-движение -------------------------


# Пер-инстансное стабильное направление-фолбэк (для нулевых дистанций).
func _fallback_direction() -> Vector2:
	return Vector2.RIGHT.rotated(float(get_instance_id() % 628) * 0.01)


# Кольцо остановки melee: всегда внутри contact_range (уптайм контакт-урона —
# жёсткий контракт). Пересчитывается от текущего contact_range: fit по спрайту
# и epic scale уже учтены внутри него.
func _melee_engage_distance() -> float:
	return contact_range * MELEE_ENGAGE_RATIO


func _band_steering(direction: Vector2, distance: float, speed: float, delta: float) -> Vector2:
	var toward := direction / distance if distance > 0.001 else _fallback_direction()
	if can_summon:
		return _ranged_band_steering(toward, distance, desired_summoning_distance, speed, delta)
	if can_shoot:
		return _ranged_band_steering(toward, distance, desired_shooting_distance, speed, delta)
	return _melee_band_steering(toward, distance, speed)


func _melee_band_steering(toward: Vector2, distance: float, speed: float) -> Vector2:
	var engage := _melee_engage_distance()
	# Гистерезис отхода: вход в глубоком оверлапе (<0.62×engage — игрок сам
	# зашёл в моба или спавн-наложение), выход на 0.75×engage = 0.6×contact_range.
	# Добровольно враг НИКОГДА не отходит за contact_range — замах не рвётся.
	if _melee_backoff_active and distance >= engage * MELEE_BACKOFF_EXIT_RATIO:
		_melee_backoff_active = false
	elif not _melee_backoff_active and distance < engage * MELEE_BACKOFF_ENTER_RATIO:
		_melee_backoff_active = true
	if _melee_backoff_active:
		return -toward * speed * MELEE_BACKOFF_SPEED_FACTOR
	if distance <= engage:
		# Кольцо: держим свою точку и бьём с неё; тангенциальный дрейф — знак
		# фиксирован чётностью instance id, пачка расползается в обе стороны.
		return toward.orthogonal() * _orbit_sign * speed * MELEE_ORBIT_SPEED_FACTOR
	if distance <= engage + MELEE_DECELERATION_BAND:
		var band_t := (distance - engage) / MELEE_DECELERATION_BAND
		return toward * speed * lerpf(MELEE_APPROACH_MIN_FACTOR, 1.0, band_t)
	return toward * speed


func _ranged_band_steering(toward: Vector2, distance: float, desired: float, speed: float, delta: float) -> Vector2:
	if distance < desired * RANGED_RETREAT_RATIO:
		return -toward * speed
	if distance > desired * RANGED_APPROACH_RATIO:
		return toward * speed
	_tick_strafe_direction(delta)
	return toward.orthogonal() * _strafe_sign * speed * RANGED_STRAFE_SPEED_FACTOR


func _tick_strafe_direction(delta: float) -> void:
	_strafe_flip_left -= delta
	if _strafe_flip_left <= 0.0:
		_strafe_flip_left = randf_range(STRAFE_FLIP_INTERVAL_MIN, STRAFE_FLIP_INTERVAL_MAX)
		_strafe_sign = -_strafe_sign
	# У кромки арены — ОДИН разворот на вход в приграничную зону (без дребезга
	# каждый кадр); флаг сбрасывается при выходе из зоны.
	var near_bound := global_position.x < STRAFE_BOUND_MARGIN \
		or global_position.y < STRAFE_BOUND_MARGIN \
		or global_position.x > ARENA_SIZE.x - STRAFE_BOUND_MARGIN \
		or global_position.y > ARENA_SIZE.y - STRAFE_BOUND_MARGIN
	if near_bound and not _strafe_bound_flip_done:
		_strafe_bound_flip_done = true
		_strafe_sign = -_strafe_sign
	elif not near_bound:
		_strafe_bound_flip_done = false


func _tick_separation_cache(delta: float) -> void:
	_separation_refresh_left -= delta
	if _separation_refresh_left > 0.0:
		return
	_separation_refresh_left = SEPARATION_REFRESH_INTERVAL
	_refresh_separation_neighbors()


func _separation_rank_weight() -> float:
	# Боссы не толкаются вовсе, элитки — слабее рядовых; summon = ordinary.
	if is_in_group("bosses"):
		return 0.0
	if elite_behavior != "" or is_in_group("elite_enemies"):
		return SEPARATION_ELITE_WEIGHT
	return 1.0


# Кэш 3-4 ближайших соседей: один проход по группе enemies раз в 0.2s (со
# stagger по id), горячий кадр работает только по кэшу — O(48×4) на всё поле.
func _refresh_separation_neighbors() -> void:
	_separation_neighbors.clear()
	_separation_scratch_dist.clear()
	_separation_weight = _separation_rank_weight()
	if _separation_weight <= 0.0 or not is_inside_tree():
		return
	var search_limit := SEPARATION_MAX_RANGE + SEPARATION_SEARCH_SLACK
	var limit_sq := search_limit * search_limit
	for node in get_tree().get_nodes_in_group("enemies"):
		var other := node as Node2D
		if other == null or other == self or not is_instance_valid(other):
			continue
		var dist_sq := global_position.distance_squared_to(other.global_position)
		if dist_sq >= limit_sq:
			continue
		var insert_at := _separation_scratch_dist.size()
		for index in range(_separation_scratch_dist.size()):
			if dist_sq < float(_separation_scratch_dist[index]):
				insert_at = index
				break
		if insert_at >= SEPARATION_MAX_NEIGHBORS:
			continue
		_separation_scratch_dist.insert(insert_at, dist_sq)
		_separation_neighbors.insert(insert_at, other)
		if _separation_scratch_dist.size() > SEPARATION_MAX_NEIGHBORS:
			_separation_scratch_dist.resize(SEPARATION_MAX_NEIGHBORS)
			_separation_neighbors.resize(SEPARATION_MAX_NEIGHBORS)


func _separation_velocity() -> Vector2:
	if _separation_weight <= 0.0 or _separation_neighbors.is_empty():
		return Vector2.ZERO
	var push := Vector2.ZERO
	for node in _separation_neighbors:
		var other := node as Node2D
		if other == null or not is_instance_valid(other) or not other.is_inside_tree():
			continue
		var offset := global_position - other.global_position
		var dist := offset.length()
		var other_radius := 32.0
		var raw_radius = other.get("_separation_radius")
		if raw_radius != null:
			other_radius = float(raw_radius)
		var reach := minf((_separation_radius + other_radius) * 0.9, SEPARATION_MAX_RANGE)
		if reach <= 0.0 or dist >= reach:
			continue
		var away := Vector2.ZERO
		if dist > 0.001:
			away = offset / dist
		else:
			# Идеальная стопка (pack-спавн в одну точку): анти-симметричный
			# детерминированный развод — XOR id даёт общий угол, знак по порядку
			# id гарантирует противоположные стороны у обоих участников.
			var stack_angle := float((get_instance_id() ^ other.get_instance_id()) % 628) * 0.01
			away = Vector2.RIGHT.rotated(stack_angle) * (1.0 if get_instance_id() > other.get_instance_id() else -1.0)
		# Вес по глубине перекрытия: вплотную — полный push, у кромки — ноль.
		push += away * (1.0 - dist / reach)
	if push == Vector2.ZERO:
		return Vector2.ZERO
	return push.limit_length(1.0) * SEPARATION_MAX_SPEED * _separation_weight


# Спавн-защита минионов (саммонер/босс-рифтлинги): точка ближе min_distance к
# игроку выталкивается наружу вдоль направления игрок→точка (в пределах арены).
func _push_point_from_player(point: Vector2, min_distance: float) -> Vector2:
	var player := _player()
	if player == null:
		return point
	var offset := point - player.global_position
	var dist := offset.length()
	if dist >= min_distance:
		return point
	var away := offset / dist if dist > 0.001 else Vector2.RIGHT.rotated(randf() * TAU)
	return _clamp_to_arena(player.global_position + away * min_distance)


# --- /Combat Feel Rework (этап B) --------------------------------------------


func _sandbox_attack_delta(delta: float) -> float:
	return delta * clampf(float(get_meta("sandbox_attack_speed_multiplier", 1.0)), 0.5, 3.0)


# SCRUM-976: Enemy — общий предок ordinary/summon/elite/boss, поэтому этот
# одноразовый слой покрывает и прямые summon-пути, которых нет в CombatDirector.
func _apply_gameplay_sandbox_runtime() -> void:
	if bool(get_meta("gameplay_sandbox_applied", false)):
		return
	var game := _gameplay_sandbox_owner()
	if game == null:
		return
	var hp_multiplier: float = float(game.call("run_sandbox_multiplier", GAMEPLAY_SANDBOX.MONSTER_HP))
	var damage_multiplier: float = float(game.call("run_sandbox_multiplier", GAMEPLAY_SANDBOX.MONSTER_DAMAGE))
	var attack_speed_multiplier: float = float(game.call("run_sandbox_multiplier", GAMEPLAY_SANDBOX.MONSTER_ATTACK_SPEED))
	max_health *= hp_multiplier
	contact_damage *= damage_multiplier
	projectile_damage *= damage_multiplier
	elite_hazard_damage *= damage_multiplier
	set_meta("sandbox_attack_speed_multiplier", attack_speed_multiplier)
	set_meta("sandbox_damage_multiplier", damage_multiplier)
	set_meta("gameplay_sandbox_applied", true)


func _gameplay_sandbox_owner() -> Node:
	var candidate := get_parent()
	while candidate != null:
		if candidate.has_method("run_sandbox_multiplier"):
			return candidate
		candidate = candidate.get_parent()
	return null


func take_damage(amount: float, feedback := {}) -> void:
	if _death_lifecycle_started:
		return
	var feedback_data: Dictionary = feedback if feedback is Dictionary else {}
	var final_amount := amount * StatusEffects.damage_taken_multiplier(self)
	if _elite_shield_active:
		final_amount *= elite_shield_damage_reduction
		_apply_elite_reflect_thorns(amount)
	health -= final_amount
	_update_health_bar()
	# SCRUM-502: репортим нанесённый врагу урон в агрегатор забега (экран итогов).
	# enemy.take_damage(...) — единая точка схода ВСЕХ источников урона по врагу
	# (снаряды projectile.gd, прямой удар/enchant/echo/blast/контратаки player.gd,
	# DoT-тики, урон саммонов), поэтому один хук здесь покрывает все пути. Берём
	# final_amount = фактически снятое HP (после damage_taken_multiplier и elite-щита).
	if final_amount > 0.0 and is_inside_tree():
		var game_node := get_tree().current_scene
		if game_node != null and game_node.has_method("add_run_damage_dealt"):
			game_node.add_run_damage_dealt(final_amount)
	_show_combat_feedback(final_amount, feedback_data)
	if is_inside_tree():
		if _cached_audio == null or not is_instance_valid(_cached_audio):
			_cached_audio = get_node_or_null("/root/AudioManager")
		if _cached_audio != null and _cached_audio.has_method("play_sfx"):
			# SCRUM-968: типизированные попадания (спека §5) — маппинг по
			# feedback.damage_type в единой точке урона. Оси после SCRUM-898:
			# physical/magic/dot (+"true" у нетипизированных источников -> "hit").
			_cached_audio.play_sfx(hit_sfx_for_damage_type(str(feedback_data.get("damage_type", ""))))
	var rig := _cutout_rig()
	if rig != null and rig.has_method("play_hit"):
		rig.play_hit()
	_play_full_frame_state("hit", Vector2.ZERO)

	if health <= 0.0:
		_death_lifecycle_started = true
		health = 0.0
		# SCRUM-1007: фиксируем feedback убившего хита ДО сигнала — подписчики
		# died (он-килл trait'ы) читают атрибуцию из меты (отдельная функция,
		# не относится к маппингу damage_type→SFX).
		_record_kill_attribution(feedback_data)
		# Награды/лут/счёт — сразу через сигнал, независимо от визуала смерти.
		died.emit(self)
		# SCRUM-379: если есть ЯВНАЯ full-frame death-анимация — проигрываем её до
		# удаления; иначе прежний death-ghost fallback (rig-призрак).
		var death_body := _full_frame_body()
		if death_body != null and death_body.visible and death_body.sprite_frames != null and death_body.sprite_frames.has_animation("death"):
			_play_full_frame_death_then_free(death_body)
		else:
			if rig != null and rig.has_method("spawn_death_ghost"):
				rig.spawn_death_ghost()
			queue_free()


# SCRUM-1007: атрибуция смертельного удара. Feedback убившего хита кладётся в
# мету "killing_hit_feedback" непосредственно перед died.emit — обработчики
# смерти (player.on_enemy_killed → он-килл trait'ы) по ней различают источник:
#   player_owned=true  — урон игрока (оружие/тик проклятия/ульта);
#   dark_decay=true    — урон самого взрыва «Тёмного распада» (анти-рекурсия);
#   пустая мета         — неатрибутированный источник (hazard/чужой) → trait молчит.
# Отдельная функция вне блока маппинга damage_type→SFX (владение SCRUM-968).
func _record_kill_attribution(feedback: Dictionary) -> void:
	set_meta("killing_hit_feedback", feedback.duplicate(true) if feedback is Dictionary else {})


func _show_combat_feedback(amount: float, feedback: Dictionary) -> void:
	if amount <= 0.0 or not _combat_feedback_enabled():
		return
	_show_hit_flash()
	if bool(feedback.get("suppress_number", false)):
		return
	if _feedback_group_count(COMBAT_FEEDBACK_LABEL_GROUP) >= COMBAT_FEEDBACK_MAX_LABELS:
		return
	var critical := bool(feedback.get("critical", false))
	var damage_type := str(feedback.get("damage_type", "true"))
	var label := Label.new()
	label.name = "CombatCritNumber" if critical else "CombatDamageNumber"
	label.add_to_group(COMBAT_FEEDBACK_LABEL_GROUP)
	label.text = "! %d" % int(round(amount)) if critical else str(int(round(amount)))
	# Крит перебивает тип красным (ожидаемо, см. combat.md); иначе — цвет по типу.
	label.modulate = Color(1.0, 0.24, 0.16, 1.0) if critical else damage_type_color(damage_type)
	label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_HUD, 30 if critical else 22
	))
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.01, 0.95))
	label.add_theme_constant_override("outline_size", 6 if critical else 5)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(96.0, 34.0)
	label.z_index = 3000
	_feedback_parent().add_child(label)
	label.global_position = global_position + Vector2(randf_range(-18.0, 18.0) - 48.0, -_feedback_height() - 20.0 + randf_range(-6.0, 6.0))
	var target_position := label.global_position + Vector2(0.0, -44.0)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", target_position, 0.62).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.42).set_delay(0.20)
	tween.chain().tween_callback(label.queue_free)
	if critical:
		_show_critical_marker()


func _show_critical_marker() -> void:
	if _feedback_group_count(COMBAT_FEEDBACK_LABEL_GROUP) >= COMBAT_FEEDBACK_MAX_LABELS:
		return
	var marker := Label.new()
	marker.name = "CombatCritMarker"
	marker.add_to_group(COMBAT_FEEDBACK_LABEL_GROUP)
	marker.text = "!"
	marker.modulate = Color(1.0, 0.06, 0.02, 1.0)
	marker.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(SemanticTypography.ROLE_HUD, 34))
	marker.add_theme_color_override("font_outline_color", Color(1.0, 0.78, 0.20, 0.95))
	marker.add_theme_constant_override("outline_size", 4)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.custom_minimum_size = Vector2(34.0, 38.0)
	marker.z_index = 3001
	_feedback_parent().add_child(marker)
	marker.global_position = global_position + Vector2(18.0, -_feedback_height() - 36.0)
	var tween := marker.create_tween()
	tween.set_parallel(true)
	tween.tween_property(marker, "global_position", marker.global_position + Vector2(0.0, -28.0), 0.48).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(marker, "modulate:a", 0.0, 0.28).set_delay(0.20)
	tween.chain().tween_callback(marker.queue_free)


func _show_hit_flash() -> void:
	if _feedback_group_count(COMBAT_FEEDBACK_FLASH_GROUP) >= COMBAT_FEEDBACK_MAX_FLASHES:
		return
	# SCRUM-611: мягкий радиальный тёплый тик вместо чёрно-красной рамки (Line2D
	# читалась как UI-артефакт). Аддитивный impact_flash, низкая alpha, быстрый угас.
	var sprite_size := _visible_sprite_size()
	var tick := Sprite2D.new()
	tick.name = "CombatHitTick"
	tick.add_to_group(COMBAT_FEEDBACK_FLASH_GROUP)
	tick.texture = HIT_FLASH_TEXTURE
	var tick_material := CanvasItemMaterial.new()
	tick_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	tick.material = tick_material
	tick.modulate = Color(1.0, 0.46, 0.36, 0.40)
	# impact_flash 128px; масштабируем под видимый размер цели (мягкое покрытие).
	var tick_reach := maxf(maxf(sprite_size.x, sprite_size.y) * 0.95, 48.0)
	tick.scale = Vector2.ONE * (tick_reach / 128.0)
	tick.z_index = 2999
	_feedback_parent().add_child(tick)
	tick.global_position = global_position + Vector2(0.0, -sprite_size.y * 0.04)
	var tick_tween := tick.create_tween()
	tick_tween.tween_property(tick, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tick_tween.tween_callback(tick.queue_free)

	var body := _feedback_flash_body()
	if body == null:
		return
	# Смягчённая body-вспышка: меньше lerp и тёплый цвет (не слепит на светлых аренах).
	var original_modulate := body.modulate
	body.modulate = original_modulate.lerp(Color(1.0, 0.42, 0.34, original_modulate.a), 0.40)
	var body_tween := body.create_tween()
	body_tween.tween_property(body, "modulate", original_modulate, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _combat_feedback_enabled() -> bool:
	if not is_inside_tree():
		return false
	return bool(get_tree().root.get_meta("combat_feedback", true))


func _feedback_group_count(group_name: String) -> int:
	if not is_inside_tree():
		return 0
	return get_tree().get_nodes_in_group(group_name).size()


func _feedback_parent() -> Node:
	if is_inside_tree() and get_tree().current_scene != null:
		return get_tree().current_scene
	var parent := get_parent()
	return parent if parent != null else self


func _feedback_height() -> float:
	return maxf(_visible_sprite_size().y * 0.5, contact_range) + 10.0


func _feedback_flash_body() -> CanvasItem:
	var full_frame := _full_frame_body()
	if full_frame != null and full_frame.visible:
		return full_frame
	var rig := _cutout_rig()
	if rig != null and rig.visible:
		return rig
	var body := _body_sprite()
	if body != null:
		return body
	return null


func _play_full_frame_death_then_free(body: AnimatedSprite2D) -> void:
	# SCRUM-379: проигрываем death-кадры, отключив поведение/столкновения мёртвого
	# врага, затем удаляем по длительности анимации. Геймплей-награды уже выданы.
	var was_boss := is_in_group("bosses")
	set_physics_process(false)
	set_process(false)
	velocity = Vector2.ZERO
	for group_name in ["enemies", "bosses", "elite_enemies", "summoned_enemies"]:
		if is_in_group(group_name):
			remove_from_group(group_name)
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", true)
	var health_bar := get_node_or_null("HealthBar") as CanvasItem
	if health_bar != null:
		health_bar.visible = false
	var rig := _cutout_rig()
	if rig != null:
		rig.visible = false
	FullFrameAnimationRegistry.play_state(body, "death", Vector2.ZERO)
	var frames := body.sprite_frames
	var fps: float = maxf(frames.get_animation_speed("death"), 1.0)
	var count: int = maxi(frames.get_frame_count("death"), 1)
	var max_duration := 2.4 if was_boss else 1.2
	var duration := clampf(float(count) / fps, 0.25, max_duration)
	if not is_inside_tree():
		call_deferred("queue_free")
		return
	var tree := get_tree()
	if tree == null:
		call_deferred("queue_free")
		return
	tree.create_timer(duration + 0.05).timeout.connect(queue_free)


func _apply_elite_reflect_thorns(incoming_amount: float) -> void:
	var mechanics: Array = get_meta("unique_mechanics", []) as Array
	if not mechanics.has("reflect_thorns"):
		return
	var player := _player()
	if player == null or not player.has_method("take_damage"):
		return
	if player.global_position.distance_to(global_position) > 190.0:
		return
	var reflected_damage := _elite_reflect_damage(incoming_amount)
	if reflected_damage <= 0.0:
		return
	HazardVfx.aura_pulse(self, 150.0, Color(0.78, 0.92, 1.0, 0.9))
	player.take_damage(reflected_damage, "elite_reflect_thorns")


func _elite_reflect_damage(incoming_amount: float) -> float:
	var sandbox_damage := clampf(float(get_meta("sandbox_damage_multiplier", 1.0)), 0.5, 3.0)
	return minf(contact_damage * 0.55 + incoming_amount * 0.03 * sandbox_damage, contact_damage * 1.15)


func _update_elite_patterns(delta: float, player: Node2D, distance: float) -> void:
	if elite_behavior == "":
		return
	if elite_behavior.contains("armored") or elite_behavior.contains("bastion"):
		_update_elite_shield(delta)
	elif elite_behavior.contains("stalker"):
		_prepare_elite_dash(_sandbox_attack_delta(delta), player, distance)
	elif elite_behavior.contains("poison") or elite_behavior.contains("plague") or elite_behavior.contains("prophet"):
		_update_elite_hazard(_sandbox_attack_delta(delta), player)
	elif elite_behavior.contains("commander") or elite_behavior.contains("marshal"):
		_update_elite_aura(_sandbox_attack_delta(delta))


func _update_elite_shield(delta: float) -> void:
	if _elite_shield_time_left > 0.0:
		_elite_shield_time_left -= delta
		if _elite_shield_time_left <= 0.0:
			_elite_shield_active = false
			_elite_shield_cooldown = 5.4
			_set_body_tint(Color.WHITE)
		return

	_elite_shield_cooldown -= delta
	if _elite_shield_cooldown <= 0.0:
		_elite_shield_active = true
		_elite_shield_time_left = 1.8
		_set_body_tint(Color(0.62, 0.86, 1.0, 1.0))
		HazardVfx.shield_block(self, Color(0.62, 0.86, 1.0, 1.0))
		_play_rig_action("cast", Vector2.UP)


func _prepare_elite_dash(delta: float, player: Node2D, distance: float) -> void:
	_elite_dash_cooldown -= delta
	if _elite_dash_cooldown > 0.0 or distance < 80.0:
		return
	var direction := player.global_position - global_position
	if direction.length_squared() <= 0.0:
		return
	_elite_dash_direction = direction.normalized()
	_elite_dash_time_left = elite_dash_duration
	_elite_dash_cooldown = 4.2
	_set_body_tint(Color(1.0, 0.78, 0.36, 1.0))
	_play_rig_action("attack", _elite_dash_direction)


func _update_elite_dash(delta: float, _player: Node2D, _distance: float) -> bool:
	if _elite_dash_time_left <= 0.0:
		return false
	_elite_dash_time_left -= delta
	velocity = _elite_dash_direction * move_speed * elite_dash_speed_multiplier
	if _elite_dash_time_left <= 0.0:
		_set_body_tint(Color.WHITE)
	return true


func _update_elite_hazard(delta: float, player: Node2D) -> void:
	_elite_hazard_cooldown -= delta
	if _elite_hazard_cooldown > 0.0:
		return
	_play_rig_action("cast", player.global_position - global_position)
	_spawn_elite_hazard(player.global_position)
	_elite_hazard_cooldown = 4.6


func _spawn_elite_hazard(target_position: Vector2) -> void:
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	var hazard_damage := elite_hazard_damage
	var hazard := Node2D.new()
	hazard.name = "ElitePoisonZone"
	hazard.add_to_group("enemy_hazards")
	hazard.global_position = _clamp_to_arena(target_position, 92.0)
	hazard.z_index = 8
	parent.add_child(hazard)

	var hazard_color := Color(0.55, 0.95, 0.30, 1.0)
	HazardVfx.telegraph(hazard, 72.0, hazard_color, 0.55)

	# Tween на hazard замораживается вместе с паузой дерева, в отличие от SceneTreeTimer.
	var hazard_tween := hazard.create_tween()
	hazard_tween.tween_interval(0.55)
	hazard_tween.tween_callback(func() -> void:
		HazardVfx.detonate(hazard, 72.0, hazard_color, "poison")
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null and player.global_position.distance_to(hazard.global_position) <= 72.0 and player.has_method("take_damage"):
			player.take_damage(hazard_damage, "poison_zone")
	)
	hazard_tween.tween_interval(1.45)
	hazard_tween.tween_callback(hazard.queue_free)


func _update_elite_aura(delta: float) -> void:
	_elite_aura_cooldown -= delta
	if _elite_aura_cooldown > 0.0:
		return
	_elite_aura_cooldown = 5.2
	_play_rig_action("cast", Vector2.UP)
	HazardVfx.aura_pulse(self, 210.0, Color(1.0, 0.82, 0.36, 1.0))
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_node := enemy as Node2D
		if enemy_node == null or enemy_node == self or enemy_node.is_in_group("elite_enemies"):
			continue
		if enemy_node.has_meta("commander_aura_buffed"):
			continue
		if enemy_node.global_position.distance_to(global_position) > 210.0:
			continue
		enemy_node.set_meta("commander_aura_buffed", true)
		if enemy_node.get("move_speed") != null:
			enemy_node.set("move_speed", float(enemy_node.get("move_speed")) * 1.08)
		if enemy_node.get("contact_damage") != null:
			enemy_node.set("contact_damage", float(enemy_node.get("contact_damage")) * 1.12)
		if enemy_node.has_method("_set_body_tint"):
			enemy_node._set_body_tint(Color(1.0, 0.86, 0.42, 1.0))


func _set_body_tint(color: Color) -> void:
	var body := get_node_or_null("Body") as Sprite2D
	if body == null:
		body = get_node_or_null("Sprite2D") as Sprite2D
	if body != null:
		body.modulate = color
	# Source-спрайт скрыт ригом, поэтому статусный цвет дублируется на видимый HeroFull.
	var rig := _cutout_rig()
	if rig != null and rig.has_method("set_status_tint"):
		rig.set_status_tint(color)


func _update_elite_attack(delta: float, player: Node2D, distance: float) -> bool:
	var config: Dictionary = _elite_attack_config()
	if config.is_empty():
		return false

	if elite_attack_state == "idle":
		# Возвышение 4 «Свирепые элитки»: боевая фаза (спец-атака) открывается сразу —
		# обнуляем стартовый кулдаун один раз (мета ставится в combat_director после _ready).
		if not _elite_instant_phase_applied and bool(get_meta("ascension_instant_phase", false)):
			_elite_instant_phase_applied = true
			_elite_attack_cooldown = 0.0
		_elite_attack_cooldown -= _sandbox_attack_delta(delta)
		if _elite_attack_cooldown > 0.0 or distance > float(config.get("trigger_range", 360.0)):
			return false
		_begin_elite_attack_windup(config, player)
		return true

	_elite_attack_phase_left -= delta
	if _elite_attack_phase_left > 0.0:
		return true

	match elite_attack_state:
		"windup":
			_execute_elite_strike(config, player)
			_set_elite_attack_phase("strike", float(config.get("strike", 0.25)))
		"strike":
			_set_elite_attack_phase("recover", float(config.get("recover", 0.45)))
			if elite_behavior == "night_stalker":
				_set_body_alpha(1.0)
		"recover":
			elite_attack_state = "idle"
			# Фаза 2 (HP ≤ порога): ротация уникальных атак ускоряется (~-20%).
			_elite_attack_cooldown = float(config.get("cooldown", 6.0)) * (0.8 if _elite_in_phase2() else 1.0)
			elite_attack_phase_changed.emit(elite_attack_id, "idle")
			set_meta("elite_attack_phase", "idle")
	return elite_attack_state != "idle"


func _set_elite_attack_phase(phase: String, duration: float) -> void:
	elite_attack_state = phase
	_elite_attack_phase_left = duration
	set_meta("elite_attack_phase", phase)
	_play_elite_attack_phase_animation(phase, duration)
	elite_attack_phase_changed.emit(elite_attack_id, phase)


func _play_elite_attack_phase_animation(phase: String, duration: float) -> void:
	if elite_attack_id == "":
		var config: Dictionary = _elite_attack_config()
		elite_attack_id = str(config.get("attack_id", ""))
	var full_frame_state := "%s:%s:%s" % [elite_behavior, elite_attack_id, phase]
	if _play_full_frame_state(full_frame_state, _elite_attack_direction):
		var full_frame_body := _full_frame_body()
		if full_frame_body != null:
			full_frame_body.set_meta("phase_duration", duration)
		return
	var rig := _cutout_rig()
	if rig == null:
		_configure_enemy_rig()
		rig = _cutout_rig()
	if rig == null or not rig.has_method("play_action"):
		return
	var action_name := "attack"
	match elite_behavior:
		"iron_bastion":
			action_name = "attack"
		"night_stalker":
			action_name = "attack" if phase == "strike" else "cast"
		"plague_prophet":
			action_name = "shoot" if phase == "strike" else "cast"
		"shard_marshal":
			action_name = "shoot"
		_:
			action_name = "attack"
	var variant := "%s:%s:%s" % [elite_behavior, elite_attack_id, phase]
	rig.play_action(action_name, _elite_attack_direction, variant, duration)


func _begin_elite_attack_windup(config: Dictionary, player: Node2D) -> void:
	_elite_attack_targets.clear()
	var windup := float(config.get("windup", 0.5))
	_set_elite_attack_phase("windup", windup)
	var to_player := player.global_position - global_position
	if to_player.length_squared() > 0.001:
		_elite_attack_direction = to_player.normalized()

	var phase2 := _elite_in_phase2()
	match elite_behavior:
		"iron_bastion":
			# Телеграф совпадает с фаза-2 расширением волны (честное окно уворота).
			_spawn_elite_telegraph(global_position, _safe_radius(float(config.get("radius", 260.0)) * (1.3 if phase2 else 1.0)), windup)
		"night_stalker":
			var behind := player.global_position + _elite_attack_direction * float(config.get("behind_offset", 74.0))
			_elite_attack_targets.append(_clamp_to_arena(behind))
			_spawn_elite_telegraph(_elite_attack_targets[0], float(config.get("radius", 92.0)), windup)
			_set_body_alpha(0.25)
			_spawn_shadow_trail(global_position, _elite_attack_targets[0], windup)
		"plague_prophet":
			_play_rig_action("cast", _elite_attack_direction)
			var spread := float(config.get("lob_spread", 130.0))
			# Фаза 2: больше луж яда (второе применение) — +2 лоба.
			for lob_index in range(int(config.get("lob_count", 3)) + (2 if phase2 else 0)):
				var offset := Vector2.ZERO
				if lob_index > 0:
					offset = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(spread * 0.35, spread)
				var target := _clamp_to_arena(player.global_position + offset, 92.0)
				_elite_attack_targets.append(target)
				_spawn_elite_telegraph(target, float(config.get("radius", 56.0)), windup + float(config.get("lob_travel_time", 0.4)))
		"shard_marshal":
			_spawn_elite_telegraph(global_position + _elite_attack_direction * 120.0, 64.0, windup)


func _execute_elite_strike(config: Dictionary, player: Node2D) -> void:
	match elite_behavior:
		"iron_bastion":
			_strike_slam_wave(config, player)
		"night_stalker":
			_strike_shadow_strike(config, player)
		"plague_prophet":
			_strike_poison_volley(config, player)
		"shard_marshal":
			_strike_shard_fan(config, player)


# SCRUM-498: ранг угрозы для off-screen edge-индикатора HUD. "" — не значимая угроза
# (обычные melee-мобы не маркируются). boss > elite > активно стреляющий дальнобой.
func threat_marker_rank() -> String:
	if is_in_group("bosses"):
		return "boss"
	if elite_behavior != "" or is_in_group("elite_enemies"):
		return "elite"
	if can_shoot and _threat_fire_marker_left > 0.0:
		return "shooter"
	return ""


func _elite_in_phase2() -> bool:
	# Боевая фаза 2 элитки: ниже порога HP (elite_phase_threshold, по умолч. 0.50).
	if max_health <= 0.0:
		return false
	var threshold := float(get_meta("elite_phase_threshold", 0.5))
	return health / max_health <= threshold


func _safe_radius(radius: float) -> float:
	# Safe corridor: ни один хазард не перекрывает арену целиком — даже две
	# одновременные зоны оставляют проходимый коридор (cap < полувысоты арены).
	return minf(radius, ARENA_SIZE.y * 0.34)


func _shake_player_camera(intensity: float, duration := 0.18) -> void:
	# Тряска на slam/детонациях из скриптов врага (без ссылки на game): флаг
	# берётся из tree-root меты, выставляемой main при загрузке настроек.
	if not bool(get_tree().root.get_meta("screen_shake", true)):
		return
	var player := _player()
	if player == null:
		return
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	var tween := camera.create_tween()
	var steps := 5
	for i in range(steps):
		var falloff: float = 1.0 - float(i) / float(steps)
		var off: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * intensity * falloff
		tween.tween_property(camera, "offset", off, duration / float(steps))
	tween.tween_property(camera, "offset", Vector2.ZERO, duration / float(steps))


func _elite_attack_damage(config: Dictionary, player: Node2D) -> float:
	var damage := contact_damage * float(config.get("damage_factor", 1.0))
	var player_max_health := float(player.get("max_health")) if player.get("max_health") != null else 0.0
	if player_max_health > 0.0:
		damage = minf(damage, player_max_health * 0.25)
	return _outgoing_damage(damage)


func _strike_slam_wave(config: Dictionary, player: Node2D) -> void:
	var phase2 := _elite_in_phase2()
	# Фаза 2: «двойная волна» — шире и сильнее, но в пределах безопасного коридора.
	var radius := _safe_radius(float(config.get("radius", 260.0)) * (1.3 if phase2 else 1.0))
	var knockback := float(config.get("knockback", 150.0)) * (1.3 if phase2 else 1.0)
	_spawn_shockwave_ring(global_position, radius)
	_shake_player_camera(9.0 if phase2 else 7.0, 0.2)
	if phase2:
		_spawn_shockwave_ring(global_position, radius * 0.6)
	if player.global_position.distance_to(global_position) > radius:
		return
	if player.has_method("take_damage") and player.take_damage(_elite_attack_damage(config, player), "elite_slam_wave"):
		var push_direction := (player.global_position - global_position).normalized()
		if push_direction.length_squared() <= 0.001:
			push_direction = Vector2.RIGHT
		player.global_position = _clamp_to_arena(player.global_position + push_direction * knockback)


func _strike_shadow_strike(config: Dictionary, player: Node2D) -> void:
	if _elite_attack_targets.is_empty():
		return
	var strike_position: Vector2 = _elite_attack_targets[0]
	_spawn_shadow_trail(global_position, strike_position, 0.22)
	global_position = strike_position
	_set_body_alpha(1.0)
	_play_rig_action("attack", player.global_position - global_position)
	if player.global_position.distance_to(global_position) <= float(config.get("radius", 92.0)):
		if player.has_method("take_damage"):
			player.take_damage(_elite_attack_damage(config, player), "elite_shadow_strike")
	# Фаза 2: серия из двух ударов из тени — второй заход с другой стороны.
	if _elite_in_phase2():
		var second := _clamp_to_arena(player.global_position - _elite_attack_direction * float(config.get("behind_offset", 74.0)))
		_spawn_shadow_trail(global_position, second, 0.18)
		global_position = second
		_play_rig_action("attack", player.global_position - global_position)
		if player.global_position.distance_to(global_position) <= float(config.get("radius", 92.0)):
			if player.has_method("take_damage"):
				player.take_damage(_elite_attack_damage(config, player), "elite_shadow_strike")


func _strike_poison_volley(config: Dictionary, player: Node2D) -> void:
	var damage := _elite_attack_damage(config, player)
	for target in _elite_attack_targets:
		_spawn_poison_lob(target, float(config.get("lob_travel_time", 0.4)), damage, config)


func _strike_shard_fan(config: Dictionary, player: Node2D) -> void:
	var shard_count := maxi(int(config.get("shard_count", 5)), 1)
	var spread := deg_to_rad(float(config.get("spread_degrees", 60.0)))
	var damage := _elite_attack_damage(config, player)
	for shard_index in range(shard_count):
		var t := 0.0 if shard_count == 1 else float(shard_index) / float(shard_count - 1)
		var angle := lerpf(-spread * 0.5, spread * 0.5, t)
		_spawn_shard(_elite_attack_direction.rotated(angle), damage, config)
	# Фаза 2: второе применение — кольцо осколков вдобавок к вееру (всегда есть
	# проход: кольцо разрежено, между лучами можно проскользнуть).
	if _elite_in_phase2():
		var ring_count := 8
		for ring_index in range(ring_count):
			var ring_angle := TAU * float(ring_index) / float(ring_count)
			_spawn_shard(Vector2.RIGHT.rotated(ring_angle), damage, config)


func _spawn_shard(direction: Vector2, damage: float, config: Dictionary) -> void:
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	var projectile := ENEMY_PROJECTILE_SCENE.instantiate()
	parent.add_child(projectile)
	var shard_sprite := projectile.get_node_or_null("Sprite2D") as Sprite2D
	if shard_sprite == null:
		shard_sprite = projectile.get_node_or_null("Body") as Sprite2D
	if shard_sprite != null:
		shard_sprite.texture = ELITE_CRYSTAL_SHARD_TEXTURE
		shard_sprite.rotation = direction.angle()
	if projectile.has_method("setup"):
		projectile.setup(global_position, global_position + direction * 200.0, damage, float(config.get("shard_speed", 430.0)))


func _spawn_elite_telegraph(target_position: Vector2, radius: float, duration: float) -> void:
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	var telegraph := Node2D.new()
	telegraph.name = "EliteAttackTelegraph"
	telegraph.add_to_group("enemy_hazards")
	telegraph.z_index = 7
	parent.add_child(telegraph)
	telegraph.global_position = target_position

	var sprite := Sprite2D.new()
	match elite_attack_id:
		"shadow_strike":
			sprite.texture = ELITE_SHADOW_MARK_TEXTURE
		"shard_fan":
			sprite.texture = ELITE_SHARD_FAN_BURST_TEXTURE
		_:
			sprite.texture = ELITE_TELEGRAPH_TEXTURE
	var texture_radius: float = maxf(float(maxi(sprite.texture.get_width(), sprite.texture.get_height())) * 0.5, 1.0)
	var target_scale := maxf(radius, 32.0) / texture_radius
	sprite.scale = Vector2(target_scale, target_scale) * 0.4
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
	telegraph.add_child(sprite)

	var tween := telegraph.create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2(target_scale, target_scale), minf(duration * 0.5, 0.3)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate:a", 0.85, minf(duration * 0.4, 0.22))
	tween.chain().tween_interval(maxf(duration - 0.3, 0.05))
	tween.chain().tween_property(sprite, "modulate:a", 0.0, 0.12)
	tween.chain().tween_callback(telegraph.queue_free)


func _spawn_shockwave_ring(origin: Vector2, radius: float) -> void:
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	var ring := Node2D.new()
	ring.name = "EliteShockwave"
	ring.add_to_group("enemy_hazards")
	ring.z_index = 9
	parent.add_child(ring)
	ring.global_position = origin
	var sprite := Sprite2D.new()
	sprite.texture = ELITE_SHOCKWAVE_TEXTURE
	var texture_radius: float = maxf(ELITE_SHOCKWAVE_TEXTURE.get_size().x * 0.5, 1.0)
	sprite.scale = Vector2.ONE * 0.2
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.95)
	ring.add_child(sprite)
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2.ONE * (radius / texture_radius), 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.34)
	tween.chain().tween_callback(ring.queue_free)


func _spawn_shadow_trail(from_position: Vector2, to_position: Vector2, duration: float) -> void:
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	var trail := Node2D.new()
	trail.name = "EliteShadowTrail"
	trail.add_to_group("enemy_hazards")
	trail.z_index = 6
	parent.add_child(trail)
	trail.global_position = (from_position + to_position) * 0.5
	var sprite := Sprite2D.new()
	sprite.texture = ELITE_SHADOW_TRAIL_TEXTURE
	var delta := to_position - from_position
	sprite.rotation = delta.angle()
	var texture_length: float = maxf(ELITE_SHADOW_TRAIL_TEXTURE.get_size().x, 1.0)
	sprite.scale = Vector2(delta.length() / texture_length, 0.8)
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.65)
	trail.add_child(sprite)
	var tween := trail.create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, maxf(duration, 0.15))
	tween.tween_callback(trail.queue_free)


func _spawn_poison_lob(target_position: Vector2, travel_time: float, damage: float, config: Dictionary) -> void:
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	var lob := Node2D.new()
	lob.name = "ElitePoisonLob"
	lob.add_to_group("enemy_hazards")
	lob.z_index = 12
	parent.add_child(lob)
	lob.global_position = global_position
	var sprite := Sprite2D.new()
	sprite.texture = ELITE_POISON_LOB_TEXTURE
	sprite.scale = Vector2(0.5, 0.5)
	lob.add_child(sprite)
	var tween := lob.create_tween()
	tween.set_parallel(true)
	tween.tween_property(lob, "global_position", target_position, travel_time).set_trans(Tween.TRANS_LINEAR)
	# Имитация дуги: спрайт поднимается и опускается во время полета.
	tween.tween_property(sprite, "position", Vector2(0.0, -64.0), travel_time * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(sprite, "position", Vector2.ZERO, travel_time * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func() -> void:
		_spawn_poison_puddle(target_position, damage, config)
		lob.queue_free()
	)


func _spawn_poison_puddle(puddle_position: Vector2, tick_damage: float, config: Dictionary) -> void:
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	var puddle := Node2D.new()
	puddle.name = "ElitePoisonPuddle"
	puddle.add_to_group("enemy_hazards")
	# SCRUM-553: наземная декаль — лужа под всеми сущностями (z≈0), над фоном(-100)/бордером(-20)
	# арены. Абсолютный слой, чтобы не зависеть от z родителя (current_scene/root).
	puddle.z_as_relative = false
	puddle.z_index = -3
	parent.add_child(puddle)
	puddle.global_position = puddle_position
	var radius := float(config.get("radius", 56.0))

	# Оформленная бурлящая лужа яда (raster pool) вместо голого Polygon2D-круга.
	var visual := Sprite2D.new()
	visual.texture = POISON_POOL_TEXTURE
	visual.scale = Vector2.ONE * (radius * 2.0 / float(POISON_POOL_TEXTURE.get_width()))
	visual.modulate = Color(1.0, 1.0, 1.0, 0.0)
	puddle.add_child(visual)
	# появление + непрерывное «бульканье» (pause-aware, привязан к ноде)
	var appear := puddle.create_tween()
	appear.tween_property(visual, "modulate:a", 0.92, 0.18)
	var bubble := puddle.create_tween()
	bubble.set_loops()
	bubble.tween_property(visual, "scale", visual.scale * 1.06, 0.7).set_trans(Tween.TRANS_SINE)
	bubble.tween_property(visual, "scale", visual.scale, 0.7).set_trans(Tween.TRANS_SINE)

	var duration := float(config.get("puddle_duration", 3.0))
	# Защита от div0/KeyError: неполный config (без tick_interval или =0) больше
	# не роняет бой и не уходит в бесконечный tick_count (SCRUM-598).
	var tick_interval := maxf(float(config.get("tick_interval", 0.6)), 0.05)
	var tween := puddle.create_tween()
	var tick_count := int(floor(duration / tick_interval))
	for tick_index in range(tick_count):
		tween.tween_interval(tick_interval)
		tween.tween_callback(func() -> void:
			var player := get_tree().get_first_node_in_group("player") as Node2D
			if player != null and player.global_position.distance_to(puddle.global_position) <= radius and player.has_method("take_damage"):
				player.take_damage(tick_damage, "elite_poison_puddle")
		)
	tween.tween_property(visual, "modulate:a", 0.0, 0.3)
	tween.tween_callback(puddle.queue_free)


func _set_body_alpha(alpha: float) -> void:
	var rig := _cutout_rig()
	if rig != null:
		rig.modulate.a = alpha
	var body := get_node_or_null("Body") as Sprite2D
	if body == null:
		body = get_node_or_null("Sprite2D") as Sprite2D
	if body != null:
		body.modulate.a = alpha


func _visible_sprite_size() -> Vector2:
	# Combat Feel Rework (этап A): если активен живой FullFrameBody — меряем ЕГО
	# текущий кадр (раньше мерился скрытый статический Body, и health-bar/фидбек/
	# contact-fit тюнились по невидимому арту). Фолбэк — статический спрайт.
	var full_frame := _full_frame_body()
	if full_frame != null and full_frame.visible and full_frame.sprite_frames != null:
		var animation_name := str(full_frame.animation)
		if full_frame.sprite_frames.has_animation(animation_name) and full_frame.sprite_frames.get_frame_count(animation_name) > 0:
			var frame_index: int = clampi(full_frame.frame, 0, full_frame.sprite_frames.get_frame_count(animation_name) - 1)
			var frame_texture := full_frame.sprite_frames.get_frame_texture(animation_name, frame_index)
			if frame_texture != null:
				return frame_texture.get_size() * full_frame.scale.abs() * scale.abs()
	var body := get_node_or_null("Body") as Sprite2D
	if body == null:
		body = get_node_or_null("Sprite2D") as Sprite2D
	if body == null or body.texture == null:
		return Vector2(64.0, 64.0)
	return body.texture.get_size() * body.scale.abs() * scale.abs()


func _fit_contact_range_to_sprite() -> void:
	# Контактный урон должен проходить при видимом касании спрайтов:
	# радиус врага + радиус игрока, экспортное значение остается минимумом.
	var visible_radius: float = maxf(_visible_sprite_size().x, _visible_sprite_size().y) * 0.5
	contact_range = maxf(contact_range, visible_radius * 0.82 + PLAYER_CONTACT_PADDING)


func _ensure_ground_circle() -> void:
	# Combat Feel Rework (этап A): мягкая тень-эллипс под ногами (origin) —
	# визуальная «точка отсчёта» врага. Ребёнок узла: двигается/паузится/умирает
	# вместе с актёром, epic-масштаб элиток/боссов наследуется автоматически
	# (поэтому размеры полигона считаются в ЛОКАЛЬНЫХ координатах, без node scale).
	# Идемпотентна: boss.gd зовёт повторно после конфигурации full-frame визуала.
	var node_scale := scale.abs()
	var local_width: float = _visible_sprite_size().x / maxf(node_scale.x, 0.01)
	var radius_x := local_width * GROUND_CIRCLE_WIDTH_FACTOR * 0.5
	var radius_y := radius_x * GROUND_CIRCLE_HEIGHT_RATIO
	var is_boss_actor := is_in_group("bosses") or _epic_scale_profile_id() == "boss"
	var alpha := GROUND_CIRCLE_BOSS_ALPHA if is_boss_actor else GROUND_CIRCLE_ALPHA
	var circle := get_node_or_null("GroundCircle") as Node2D
	var fill: Polygon2D = null
	if circle == null:
		circle = Node2D.new()
		circle.name = "GroundCircle"
		circle.position = Vector2.ZERO
		circle.z_as_relative = true
		circle.z_index = GROUND_CIRCLE_Z_INDEX
		fill = Polygon2D.new()
		fill.name = "Fill"
		circle.add_child(fill)
		add_child(circle)
	else:
		fill = circle.get_node_or_null("Fill") as Polygon2D
	if fill == null:
		return
	var points := PackedVector2Array()
	for index in range(GROUND_CIRCLE_SEGMENTS):
		var angle := TAU * float(index) / float(GROUND_CIRCLE_SEGMENTS)
		points.append(Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	fill.polygon = points
	fill.color = Color(0.0, 0.0, 0.0, alpha)


func _uses_hud_boss_bar() -> bool:
	# SCRUM-874: у акт-босса и элитки узла HP показывает общий HUD-боссбар сверху
	# экрана (ui_screens._update_boss_hud_bar) — плавающая полоса над спрайтом не
	# создаётся. Мини-элитки волн (профиль mini_elite) и обычные мобы остаются с
	# обычной плавающей полосой.
	var profile := str(get_meta(EPIC_SCALE_PROFILE_META, ""))
	return profile == "boss" or profile == "elite"


func _create_health_bar() -> void:
	if _uses_hud_boss_bar():
		return
	if get_node_or_null("HealthBar") != null:
		return
	var bar := Node2D.new()
	bar.name = "HealthBar"
	bar.set_script(HEALTH_BAR_SCRIPT)
	add_child(bar)
	var sprite_size := _visible_sprite_size()
	var desired_position := _health_bar_desired_local_position(sprite_size)
	bar.position = desired_position
	bar.setup(max_health, sprite_size.x * 0.72)
	bar.position = _clamped_health_bar_local_position(desired_position, bar)


func refresh_health_bar() -> void:
	if get_node_or_null("HealthBar") == null:
		_create_health_bar()
	_update_health_bar()


func _update_health_bar() -> void:
	var bar := get_node_or_null("HealthBar")
	if bar == null:
		return
	var sprite_size := _visible_sprite_size()
	var desired_position := _health_bar_desired_local_position(sprite_size)
	bar.position = desired_position
	if bar.has_method("configure"):
		bar.configure(max_health, health, sprite_size.x * 0.72)
	elif bar.has_method("set_value"):
		bar.set_value(health)
	bar.position = _clamped_health_bar_local_position(desired_position, bar)


func _health_bar_desired_local_position(sprite_size: Vector2) -> Vector2:
	return Vector2(0.0, -sprite_size.y * 0.5 - 14.0)


func _should_clamp_health_bar_to_viewport() -> bool:
	return is_in_group("bosses") or is_in_group("elite_enemies")


func _clamped_health_bar_local_position(desired_position: Vector2, bar: Node2D) -> Vector2:
	if not _should_clamp_health_bar_to_viewport() or bar == null or not is_inside_tree():
		return desired_position
	var viewport := get_viewport()
	if viewport == null:
		return desired_position
	var visible_rect := viewport.get_visible_rect()
	if visible_rect.size.x <= 1.0 or visible_rect.size.y <= 1.0:
		return desired_position
	var canvas_inverse := viewport.get_canvas_transform().affine_inverse()
	var visible_top_left: Vector2 = canvas_inverse * visible_rect.position
	var visible_bottom_right: Vector2 = canvas_inverse * (visible_rect.position + visible_rect.size)
	var desired_global := to_global(desired_position)
	var half_width := maxf(8.0, float(bar.get("bar_width")) * 0.5)
	var bar_height := maxf(4.0, float(bar.get("bar_height")))
	var padding := 8.0
	var min_x := visible_top_left.x + half_width + padding
	var max_x := visible_bottom_right.x - half_width - padding
	var min_y := visible_top_left.y + bar_height + padding
	var max_y := visible_bottom_right.y - padding
	if max_x < min_x:
		var mid_x := (visible_top_left.x + visible_bottom_right.x) * 0.5
		min_x = mid_x
		max_x = mid_x
	if max_y < min_y:
		var mid_y := (visible_top_left.y + visible_bottom_right.y) * 0.5
		min_y = mid_y
		max_y = mid_y
	var clamped_global := Vector2(
		clampf(desired_global.x, min_x, max_x),
		clampf(desired_global.y, min_y, max_y)
	)
	bar.set_meta("screen_clamped", not clamped_global.is_equal_approx(desired_global))
	return to_local(clamped_global)


func apply_knockback(impulse: Vector2) -> void:
	_knockback_velocity += impulse


func _consume_knockback(delta: float) -> Vector2:
	var current := _knockback_velocity
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, 2400.0 * delta)
	return current


func _player() -> Node2D:
	if _cached_player == null or not is_instance_valid(_cached_player):
		_cached_player = get_tree().get_first_node_in_group("player") as Node2D
	return _cached_player


func _combat_target() -> Node2D:
	var taunt_target := _taunt_target()
	if taunt_target != null:
		return taunt_target
	return _player()


func _taunt_target() -> Node2D:
	var statuses := StatusEffects.snapshot(self)
	var status_raw = statuses.get("bastion_taunt", {})
	if not (status_raw is Dictionary):
		return null
	var status: Dictionary = status_raw
	var owner_id := int(status.get("taunt_owner", 0))
	if owner_id <= 0:
		return null
	var owner := instance_from_id(owner_id) as Node2D
	if owner == null or not is_instance_valid(owner) or owner.is_queued_for_deletion():
		return null
	if not owner.is_inside_tree() or not owner.has_method("take_damage"):
		return null
	var health_value = owner.get("health")
	if health_value != null and float(health_value) <= 0.0:
		return null
	return owner


func _update_shooting(delta: float, player: Node2D) -> void:
	if not can_shoot or projectile_scene == null:
		return

	_shoot_cooldown -= _sandbox_attack_delta(delta)
	if _shoot_cooldown > 0.0:
		return

	var projectile := projectile_scene.instantiate()
	var projectile_parent := get_tree().current_scene
	if projectile_parent == null:
		projectile_parent = get_tree().root

	projectile_parent.add_child(projectile)

	if projectile.has_method("setup"):
		projectile.setup(global_position, player.global_position, _outgoing_damage(projectile_damage), projectile_speed)

	_play_rig_action("shoot", player.global_position - global_position)
	_shoot_cooldown = fire_interval
	_threat_fire_marker_left = THREAT_FIRE_MARKER_DURATION  # SCRUM-498


func _update_summoning(delta: float) -> void:
	if not can_summon or summoned_enemy_scene == null:
		return

	_summon_cooldown -= _sandbox_attack_delta(delta)
	if _summon_cooldown > 0.0:
		return

	var active_summons := 0
	for enemy in get_tree().get_nodes_in_group("summoned_enemies"):
		if is_instance_valid(enemy):
			active_summons += 1
	if active_summons >= max_active_summons:
		_summon_cooldown = summon_interval * 0.5
		return

	var summoned := summoned_enemy_scene.instantiate() as Node2D
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	parent.add_child(summoned)
	summoned.add_to_group("summoned_enemies")
	# Этап B: кольцо призыва вокруг саммонера, но не вплотную к игроку (≥140px).
	var minion_position := _clamp_to_arena(global_position + Vector2.RIGHT.rotated(randf() * TAU) * 44.0)
	summoned.global_position = _push_point_from_player(minion_position, MINION_SPAWN_MIN_PLAYER_DISTANCE)
	_play_rig_action("cast", Vector2.UP)
	_summon_cooldown = summon_interval


func _clamp_to_arena(position: Vector2, margin: float = ARENA_ENTITY_MARGIN) -> Vector2:
	return Vector2(
		clampf(position.x, margin, ARENA_SIZE.x - margin),
		clampf(position.y, margin, ARENA_SIZE.y - margin)
	)


func _update_contact_damage(delta: float, player: Node2D, distance: float) -> void:
	_contact_cooldown = max(_contact_cooldown - _sandbox_attack_delta(delta), 0.0)
	if distance > contact_range:
		_contact_windup_left = -1.0
		return
	if _contact_cooldown > 0.0:
		return

	if _contact_windup_left < 0.0:
		_contact_windup_left = contact_windup_time
		_play_contact_windup()
		return

	_contact_windup_left -= delta
	if _contact_windup_left > 0.0:
		return

	if player.has_method("take_damage"):
		# Кап контактного урона долей max HP игрока (как у элитных атак, SCRUM-599):
		# на поздних стадиях множитель ~5x ваншотил fragile-класс одним тычком.
		var contact_hit := contact_damage
		var player_max_health := float(player.get("max_health")) if player.get("max_health") != null else 0.0
		if player_max_health > 0.0:
			contact_hit = minf(contact_hit, player_max_health * 0.20)
		contact_hit = _outgoing_damage(contact_hit)
		# SCRUM-920: контактный удар передаёт атакующего 3-м аргументом — trait
		# «Возмездие» Рыцаря отбрасывает именно нанёсшего удар (боссы/главные
		# элиты гейтятся на стороне Player; другие классы хук игнорируют).
		player.take_damage(contact_hit, "contact", self)

	_contact_cooldown = contact_interval
	_contact_windup_left = -1.0


func _outgoing_damage(amount: float) -> float:
	return maxf(amount * StatusEffects.damage_multiplier(self), 0.0)


func _play_contact_windup() -> void:
	var body := get_node_or_null("Body") as Sprite2D
	if body == null:
		body = get_node_or_null("Sprite2D") as Sprite2D
	if body == null:
		return
	_play_rig_action("attack", Vector2.RIGHT if velocity.length_squared() <= 0.0 else velocity)
	var restore_color := body.modulate
	_set_body_tint(Color(1.0, 0.72, 0.42, 1.0))
	var tween := create_tween()
	tween.tween_interval(max(contact_windup_time, 0.05))
	tween.tween_callback(_set_body_tint.bind(restore_color))


func _body_sprite() -> Sprite2D:
	if _cached_body != null and is_instance_valid(_cached_body):
		return _cached_body
	_cached_body = get_node_or_null("Body") as Sprite2D
	if _cached_body == null:
		_cached_body = get_node_or_null("Sprite2D") as Sprite2D
	return _cached_body


func _update_movement_animation(delta: float) -> void:
	var full_frame_body := _full_frame_body()
	if full_frame_body != null and full_frame_body.visible:
		var state := "move" if velocity.length_squared() > 1.0 else "idle"
		FullFrameAnimationRegistry.play_state(full_frame_body, state, velocity)
		return

	var body := _body_sprite()
	if body == null:
		return

	if body.visible:
		body.visible = false
	if body.scale.distance_to(_rig_source_scale) > 0.01:
		_configure_enemy_rig()
	var rig := _cutout_rig()
	if rig != null and rig.has_method("update_animation"):
		rig.update_animation(delta, velocity, velocity)


func _configure_full_frame_animation() -> bool:
	var entity_kind := _full_frame_entity_kind()
	var entity_id := _full_frame_entity_id(entity_kind)
	var static_body_name := "Body" if get_node_or_null("Body") != null else "Sprite2D"
	var animated_body := FullFrameAnimationRegistry.configure_entity_visual(self, entity_kind, entity_id, "FullFrameBody", static_body_name)
	if animated_body == null:
		return false
	_cached_full_frame_body = animated_body
	var rig := _cutout_rig()
	if rig != null:
		rig.visible = false
	return true


func refresh_full_frame_visual() -> void:
	_configure_full_frame_animation()


func _full_frame_entity_kind() -> String:
	if is_in_group("bosses"):
		return "boss"
	if is_in_group("elite_enemies") or elite_behavior != "":
		return "elite"
	return "enemy"


func _full_frame_entity_id(entity_kind: String) -> String:
	if entity_kind == "boss" and get("boss_behavior") != null and str(get("boss_behavior")) != "":
		return str(get("boss_behavior"))
	if entity_kind == "elite" and has_meta("mini_elite_kind"):
		var mini_elite_id := str(get_meta("mini_elite_kind", ""))
		if mini_elite_id != "" and FullFrameAnimationRegistry.sprite_frames_for("elite", mini_elite_id) != null:
			return mini_elite_id
	if entity_kind == "elite" and elite_behavior != "":
		return elite_behavior
	return enemy_type_name.to_lower().replace(" ", "_")


func _full_frame_body() -> AnimatedSprite2D:
	if _cached_full_frame_body != null and is_instance_valid(_cached_full_frame_body):
		return _cached_full_frame_body
	_cached_full_frame_body = get_node_or_null("FullFrameBody") as AnimatedSprite2D
	return _cached_full_frame_body


func _configure_enemy_rig() -> void:
	var full_frame_body := _full_frame_body()
	if full_frame_body != null and full_frame_body.visible:
		return
	var body := get_node_or_null("Body") as Sprite2D
	if body == null:
		body = get_node_or_null("Sprite2D") as Sprite2D
	if body == null or body.texture == null:
		return
	var rig := _cutout_rig()
	if rig == null:
		rig = Node2D.new()
		rig.name = "RigRoot"
		rig.set_script(CUTOUT_RIG_SCRIPT)
		add_child(rig)
	body.visible = false
	_rig_source_scale = body.scale
	if rig.has_method("configure"):
		rig.configure(body.texture, body.scale, enemy_type_name.to_lower().replace(" ", "_"), {
			"is_flying": is_flying,
			"is_elite": is_in_group("elite_enemies") or elite_behavior != "",
			"is_boss": is_in_group("bosses") or enemy_type_name.to_lower().contains("warden") or enemy_type_name.to_lower().contains("devourer"),
		})
	# Combat Feel Rework (этап A): fallback-путь (cutout/статический арт) тоже
	# feet-origin — визуал поднимается так, чтобы низ спрайта сел ≈ на origin
	# (единая простая доля высоты, как residual-оффсеты registry на живом пути).
	# Origin/коллизии/contact_range НЕ двигаются. Full-frame путь не трогаем:
	# у него ручные offsets в full_frame_animation_registry.
	var static_lift := body.texture.get_size().y * body.scale.abs().y * STATIC_VISUAL_FEET_LIFT_RATIO
	rig.position = Vector2(0.0, -static_lift)
	body.position = Vector2(0.0, -static_lift)


func _cutout_rig() -> Node2D:
	if _cached_rig != null and is_instance_valid(_cached_rig):
		return _cached_rig
	_cached_rig = get_node_or_null("RigRoot") as Node2D
	return _cached_rig


func _play_rig_action(action_name: String, direction := Vector2.ZERO) -> void:
	if _play_full_frame_state(action_name, direction):
		return
	var rig := _cutout_rig()
	if rig != null and rig.has_method("play_action"):
		rig.play_action(action_name, direction)


func _play_full_frame_state(state_name: String, direction := Vector2.ZERO) -> bool:
	var full_frame_body := _full_frame_body()
	if full_frame_body == null or not full_frame_body.visible:
		return false
	return FullFrameAnimationRegistry.play_state(full_frame_body, state_name, direction)
