class_name BerserkWeapon
extends Node2D

const TARGET_QUERY := preload("res://scripts/combat_target_query.gd")
const CONTACT_STUCK_HIT_RADIUS := 40.0
# SCRUM-1043: Berserk's full-frame body extends farther below its origin than
# above it, so the hammer ground impact centers 16 px toward the footline; the
# same offset feeds both the hit query and the slam VFX.
# FAN-1100: the AoE must read round, not oval. The former vertical 1.12 stretch
# is gone — the damage query and VFX are now a true circle of aoe_radius around
# that shifted center (uniform reach in every direction; DPS/radius unchanged).
const HAMMER_CIRCLE_CENTER_OFFSET := Vector2(0.0, 16.0)
const HAMMER_CIRCLE_VISUAL_SCALE := Vector2.ONE
const CONSTELLATION_FINAL_MECHANICS := {
	"sword_repeat_execute": "hit",
	"axe_outer_followthrough": "attack_resolved",
	"hammer_stagger_aftershock": "attack_resolved",
	"spear_block_counter_line": "block",
	"shield_stored_damage_bash": "damage_absorbed",
}
const CONSTELLATION_AFTERSHOCK_DELAY := 0.12

@export var weapon_id := "sword"
@export var display_name := "Two-Handed Sword"
@export var attack_shape := "frustum"
@export var fire_interval := 0.75
@export var damage := 12.0
@export var attack_range := 260.0
@export var start_distance := 24.0
@export var inner_width := 54.0
@export var outer_width := 300.0
@export var aoe_radius := 190.0
@export var max_aoe_radius := 0.0
@export var sweep_degrees := 70.0
@export var circle_full_targets := 0
@export var circle_target_diminish := 0.0
@export var windup_time := 0.06
@export var swing_time := 0.14
@export var recover_time := 0.08
@export var melee_close_bonus_radius := 0.0
@export var melee_close_damage_multiplier := 1.0
@export var melee_execute_threshold := 0.0
@export var melee_execute_multiplier := 1.0
@export var melee_stagger_knockback_multiplier := 0.0
@export var melee_arc_followup_radius := 0.0
@export var melee_arc_followup_multiplier := 0.0
@export var visual_color := Color(0.62, 0.82, 1.0, 0.30)
# SCRUM-922: база отброса для derived knockback_power; свойство скейлится
# пайплайном Player._apply_weapon_scaling (Strength/knockback_multiplier ×
# meta-множитель), потребитель — формула stagger-импульса ниже.
@export var knockback := 60.0
# SCRUM-922: доля knockback-стата в stagger-импульсе (0 = прежний фикс 260) и
# кап отброса для боссов/главных элит (1.0 = прежнее поведение без капа).
@export var stagger_knockback_stat_ratio := 0.0
@export var epic_stagger_knockback_factor := 1.0
# SCRUM-921 «Тройной укол»: strip-оружие с thrust_count>1 колет секвенсом полос
# лево→центр→право под ±thrust_fan_degrees с окном thrust_step_time на укол.
@export var thrust_count := 1
@export var thrust_fan_degrees := 0.0
@export var thrust_step_time := 0.11
# SCRUM-923 «Расширяющаяся спираль»: circle-оружие со spiral_steps>0 бьёт
# фронтом-дугой spiral_arm_degrees, совершающим полный оборот за каст, пока
# радиус фронта растёт от aoe_radius×spiral_start_radius_ratio до полного.
@export var spiral_steps := 0
@export var spiral_step_time := 0.085
@export var spiral_arm_degrees := 150.0
@export var spiral_start_radius_ratio := 0.22

var _cooldown := 0.0
var _last_direction := Vector2.RIGHT
var _swinging := false
var _hit_targets := []
var _swing_tween: Tween = null
var _swing_timing_tween: Tween = null
var _last_attack_crit := false
# SCRUM-961 «Святая цепь»: раскрутка спирали кистеня (касты подряд, сброс паузой).
var _flail_spiral_casts := 0
var _flail_last_cast_ms := 0
var _sword_repeat_target_id := 0
var _sword_repeat_hits := 0
var _counter_line_left := 0.0
var _counter_line_ratio := 0.0
var _stored_bash_damage := 0.0
var _stored_bash_left := 0.0


# SCRUM-961: чтение ключа классового артефакта из run_modifiers владельца.
func _owner_mod(key: String, default_value := 0.0) -> float:
	var owner_node := _owner_node()
	if owner_node == null:
		return default_value
	var mods = owner_node.get("run_modifiers")
	if mods is Dictionary:
		return float((mods as Dictionary).get(key, default_value))
	return default_value


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("player_weapons")


func configure_weapon(config: Dictionary) -> void:
	weapon_id = str(config.get("id", weapon_id))
	display_name = str(config.get("title", display_name))
	attack_shape = str(config.get("attack_shape", attack_shape))
	fire_interval = float(config.get("fire_interval", fire_interval))
	damage *= float(config.get("damage_multiplier", 1.0))
	attack_range = float(config.get("attack_range", attack_range))
	start_distance = float(config.get("start_distance", start_distance))
	inner_width = float(config.get("inner_width", inner_width))
	outer_width = float(config.get("outer_width", outer_width))
	aoe_radius = float(config.get("aoe_radius", aoe_radius))
	max_aoe_radius = float(config.get("max_aoe_radius", max_aoe_radius))
	sweep_degrees = float(config.get("sweep_degrees", sweep_degrees))
	circle_full_targets = int(config.get("circle_full_targets", circle_full_targets))
	circle_target_diminish = float(config.get("circle_target_diminish", circle_target_diminish))
	windup_time = float(config.get("windup_time", windup_time))
	swing_time = float(config.get("swing_time", swing_time))
	recover_time = float(config.get("recover_time", recover_time))
	melee_close_bonus_radius = float(config.get("melee_close_bonus_radius", melee_close_bonus_radius))
	melee_close_damage_multiplier = float(config.get("melee_close_damage_multiplier", melee_close_damage_multiplier))
	melee_execute_threshold = float(config.get("melee_execute_threshold", melee_execute_threshold))
	melee_execute_multiplier = float(config.get("melee_execute_multiplier", melee_execute_multiplier))
	melee_stagger_knockback_multiplier = float(config.get("melee_stagger_knockback_multiplier", melee_stagger_knockback_multiplier))
	melee_arc_followup_radius = float(config.get("melee_arc_followup_radius", melee_arc_followup_radius))
	melee_arc_followup_multiplier = float(config.get("melee_arc_followup_multiplier", melee_arc_followup_multiplier))
	visual_color = config.get("visual_color", visual_color)
	knockback = float(config.get("knockback", knockback))
	stagger_knockback_stat_ratio = float(config.get("stagger_knockback_stat_ratio", stagger_knockback_stat_ratio))
	epic_stagger_knockback_factor = float(config.get("epic_stagger_knockback_factor", epic_stagger_knockback_factor))
	thrust_count = int(config.get("thrust_count", thrust_count))
	thrust_fan_degrees = float(config.get("thrust_fan_degrees", thrust_fan_degrees))
	thrust_step_time = float(config.get("thrust_step_time", thrust_step_time))
	spiral_steps = int(config.get("spiral_steps", spiral_steps))
	spiral_step_time = float(config.get("spiral_step_time", spiral_step_time))
	spiral_arm_degrees = float(config.get("spiral_arm_degrees", spiral_arm_degrees))
	spiral_start_radius_ratio = float(config.get("spiral_start_radius_ratio", spiral_start_radius_ratio))
	_capture_base_values()


func _process(delta: float) -> void:
	_counter_line_left = maxf(_counter_line_left - delta, 0.0)
	_stored_bash_left = maxf(_stored_bash_left - delta, 0.0)
	if _stored_bash_left <= 0.0:
		_stored_bash_damage = 0.0
	# Направление атаки задает только ближайший враг (см. _target_direction);
	# направление движения влияет лишь на walk-анимацию персонажа.
	_cooldown -= delta
	if _cooldown > 0.0 or _swinging:
		return

	_start_swing(false)


func _attack() -> void:
	_start_swing(true)


func _start_swing(immediate_damage := false) -> void:
	var owner_node := _owner_node()
	if owner_node == null:
		return

	var attack_direction := _target_direction(owner_node)
	if attack_direction.length_squared() == 0.0:
		attack_direction = _last_direction
	_last_direction = attack_direction.normalized()
	_swinging = true
	_hit_targets.clear()
	_cooldown = fire_interval
	_update_flail_spiral()

	if owner_node.has_method("play_action_animation"):
		owner_node.play_action_animation("attack", _last_direction)
	if owner_node.has_method("record_weapon_cast"):
		owner_node.call("record_weapon_cast", weapon_id, "melee", "attack", maxf(windup_time, 0.0))

	_animate_weapon(_last_direction)
	var owner_id := owner_node.get_instance_id()
	var thrust_sequence := _thrust_sequence_entries()
	if immediate_damage:
		if thrust_sequence.size() > 1:
			for step_index in range(thrust_sequence.size()):
				_run_thrust_step(owner_id, step_index)
		elif _uses_spiral():
			for step_index in range(spiral_steps):
				_run_spiral_step(owner_id, step_index)
		else:
			_damage_window(owner_node, _last_direction)
		_finish_swing()
		return

	# Tween на оружии замораживается паузой, чтобы окно урона не тикало в level-up/Escape.
	# SCRUM-551: храним ссылку и гасим прошлый таймер-твин — иначе при force-free оружия
	# (mass-free между замерами в character_balance_csv.gd) висящий swing-таймер дёргал
	# _finish_swing/lambda на уже освобождённом узле → нативный SIGABRT (freed object/lambda),
	# из-за чего balance-CSV падал на berserk-строках и не собирался.
	# SCRUM-921/923: секвенс-шаги планируются ТОЛЬКО bound-Callable'ами (без
	# лямбда-захвата узлов, урок SCRUM-551) — владелец резолвится по instance_id.
	if _swing_timing_tween != null and _swing_timing_tween.is_valid():
		_swing_timing_tween.kill()
	_swing_timing_tween = create_tween()
	if thrust_sequence.size() > 1:
		# SCRUM-921: окна урона лево→центр→право, каждое со своим тайминг-слотом.
		for step_index in range(thrust_sequence.size()):
			_swing_timing_tween.tween_interval(windup_time if step_index == 0 else maxf(thrust_step_time, 0.02))
			_swing_timing_tween.tween_callback(Callable(self, "_run_thrust_step").bind(owner_id, step_index))
		_swing_timing_tween.tween_interval(swing_time + recover_time)
	elif _uses_spiral():
		# SCRUM-923: фронт спирали шагает от центра наружу полный оборот.
		for step_index in range(spiral_steps):
			_swing_timing_tween.tween_interval(windup_time if step_index == 0 else maxf(spiral_step_time, 0.02))
			_swing_timing_tween.tween_callback(Callable(self, "_run_spiral_step").bind(owner_id, step_index))
		_swing_timing_tween.tween_interval(recover_time)
	else:
		_swing_timing_tween.tween_interval(windup_time)
		_swing_timing_tween.tween_callback(Callable(self, "_run_classic_damage_window").bind(owner_id))
		_swing_timing_tween.tween_interval(swing_time + recover_time)
	_swing_timing_tween.tween_callback(_finish_swing)


func _run_classic_damage_window(owner_id: int) -> void:
	if is_queued_for_deletion():
		return
	var owner_node := instance_from_id(owner_id) as Node2D
	if owner_node == null or not is_instance_valid(owner_node):
		return
	_damage_window(owner_node, _last_direction)


func _finish_swing() -> void:
	if is_queued_for_deletion():
		return
	_swinging = false
	_hit_targets.clear()


func _exit_tree() -> void:
	# Оружие покидает дерево (смена оружия ИЛИ каскадный force-free игрока) —
	# гасим оба твина, чтобы их отложенные колбэки не сработали по freed-self.
	if _swing_tween != null and _swing_tween.is_valid():
		_swing_tween.kill()
	if _swing_timing_tween != null and _swing_timing_tween.is_valid():
		_swing_timing_tween.kill()
	_swing_tween = null
	_swing_timing_tween = null


func _animate_weapon(direction: Vector2) -> void:
	if _swing_tween != null and _swing_tween.is_valid():
		_swing_tween.kill()

	if attack_shape == "circle":
		if _uses_spiral():
			_animate_spiral_spin(direction)
			return
		_animate_hammer_slam(direction)
		return

	if attack_shape == "strip":
		_animate_thrust(direction)
		return

	var half_sweep := deg_to_rad(sweep_degrees * 0.5)
	var base_angle := direction.angle()
	rotation = base_angle - half_sweep
	position = direction.normalized() * 32.0

	_swing_tween = create_tween()
	_swing_tween.tween_property(self, "rotation", base_angle + half_sweep, windup_time + swing_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_swing_tween.tween_property(self, "position", Vector2.ZERO, recover_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _animate_thrust(direction: Vector2) -> void:
	# Быстрый колющий выпад вдоль полосы вместо дугового замаха.
	var base_angle := direction.angle()
	rotation = base_angle
	position = -direction.normalized() * 14.0

	_swing_tween = create_tween()
	var entries := _thrust_sequence_entries()
	if entries.size() > 1:
		# SCRUM-921: три быстрых тычка спрайтом под углы секвенса (лево→центр→право);
		# косметика — окна урона планирует _swing_timing_tween независимо.
		for entry in entries:
			var thrust_direction: Vector2 = direction.normalized().rotated(deg_to_rad(float((entry as Dictionary).get("angle", 0.0))))
			_swing_tween.tween_property(self, "rotation", thrust_direction.angle(), 0.02)
			_swing_tween.tween_property(self, "position", thrust_direction * 40.0, maxf(thrust_step_time * 0.6, 0.04)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_swing_tween.tween_property(self, "position", -direction.normalized() * 8.0, maxf(thrust_step_time * 0.35, 0.03))
		_swing_tween.tween_property(self, "rotation", base_angle, recover_time)
		_swing_tween.parallel().tween_property(self, "position", Vector2.ZERO, recover_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		return
	_swing_tween.tween_property(self, "position", direction.normalized() * 40.0, windup_time + swing_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_swing_tween.tween_property(self, "position", Vector2.ZERO, recover_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# SCRUM-923: раскрутка кистеня — спрайт совершает полный оборот вокруг героя
# синхронно с фронтом спирали (косметика; урон планирует _swing_timing_tween).
func _animate_spiral_spin(direction: Vector2) -> void:
	var base_angle := direction.angle()
	rotation = base_angle
	position = direction.normalized() * 26.0
	var spin_time := windup_time + maxf(spiral_step_time, 0.02) * float(maxi(spiral_steps - 1, 1))
	_swing_tween = create_tween()
	_swing_tween.tween_property(self, "rotation", base_angle + TAU, spin_time)
	_swing_tween.tween_property(self, "position", Vector2.ZERO, recover_time * 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _animate_hammer_slam(direction: Vector2) -> void:
	# Замах вверх, затем ускоряющееся падение молота в землю перед героем.
	var base_angle := direction.angle()
	rotation = base_angle - 1.9
	position = Vector2(0.0, -20.0)

	_swing_tween = create_tween()
	_swing_tween.set_parallel(true)
	_swing_tween.tween_property(self, "rotation", base_angle + 0.45, windup_time + swing_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_swing_tween.tween_property(self, "position", direction.normalized() * 30.0 + Vector2(0.0, 10.0), windup_time + swing_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_swing_tween.chain().tween_property(self, "rotation", base_angle, recover_time * 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_swing_tween.parallel().tween_property(self, "position", Vector2.ZERO, recover_time * 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _damage_window(owner_node: Node2D, attack_direction: Vector2) -> void:
	_show_hit_area(owner_node, attack_direction)
	var candidates: Array = []
	for enemy_node in TARGET_QUERY.enemies(self):
		if not is_instance_valid(enemy_node) or _hit_targets.has(enemy_node):
			continue
		if not _is_enemy_inside_attack(owner_node, enemy_node, attack_direction):
			continue
		if enemy_node.has_method("take_damage"):
			candidates.append(enemy_node)
	if attack_shape == "circle" and circle_target_diminish > 0.0 and candidates.size() > 1:
		var circle_center := _circle_attack_center(owner_node)
		candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
			return circle_center.distance_squared_to(a.global_position) < circle_center.distance_squared_to(b.global_position)
		)
	for index in range(candidates.size()):
		_damage_target(owner_node, candidates[index] as Node2D, attack_direction, _circle_damage_factor(index))
	_resolve_constellation_attack(owner_node, attack_direction, candidates)
	# SCRUM-961 «Призрачный топор»: видимый спектральный повтор взмаха.
	if melee_arc_followup_radius > 0.0 and _owner_mod("spectral_followup_bonus") > 0.0 and not candidates.is_empty():
		_show_spectral_followup(owner_node, attack_direction)


# SCRUM-921 «Тройной укол»: секвенс углов укола в порядке AC лево→центр→право.
# «Лево» относительно направления атаки = поворот на -fan° (экранные координаты
# Y-вниз: facing вправо ⇒ отрицательный угол смотрит вверх-влево от луча).
# SCRUM-961 «Веер уколов» (классовый артефакт, бывш. «Тройной укол» до редизайна
# базы): добавляет два КРАЙНИХ укола ±2×fan° на 55% урона в конец секвенса.
func _thrust_sequence_entries() -> Array:
	var count := maxi(thrust_count, 1)
	if attack_shape != "strip" or count <= 1 or thrust_fan_degrees <= 0.0:
		return []
	var entries: Array = []
	for entry_index in range(count):
		var spread := float(entry_index) / float(count - 1)
		entries.append({"angle": lerpf(-thrust_fan_degrees, thrust_fan_degrees, spread), "factor": 1.0})
	if _owner_mod("spear_triple_thrust") > 0.0:
		entries.append({"angle": -thrust_fan_degrees * 2.0, "factor": 0.55})
		entries.append({"angle": thrust_fan_degrees * 2.0, "factor": 0.55})
	return entries


func _uses_spiral() -> bool:
	return attack_shape == "circle" and spiral_steps > 0


# SCRUM-921: одно окно укола — полоса под углом шага; дедуп _hit_targets живёт
# ВЕСЬ цикл (одна цель ≤ 1 укола за цикл — документированное анти-triple-dip
# решение, зеркалится budget-моделью solo_hits=1.0).
func _run_thrust_step(owner_id: int, step_index: int) -> void:
	if is_queued_for_deletion() or not is_inside_tree():
		return
	var owner_node := instance_from_id(owner_id) as Node2D
	if owner_node == null or not is_instance_valid(owner_node):
		return
	var entries := _thrust_sequence_entries()
	if step_index < 0 or step_index >= entries.size():
		return
	var entry: Dictionary = entries[step_index]
	var thrust_direction := _last_direction.rotated(deg_to_rad(float(entry.get("angle", 0.0)))).normalized()
	if step_index == 0:
		_show_weapon_signature(owner_node, thrust_direction)
	_show_thrust_step_area(owner_node, thrust_direction)
	for enemy_node in TARGET_QUERY.enemies(self):
		if not is_instance_valid(enemy_node) or _hit_targets.has(enemy_node):
			continue
		if not _is_enemy_inside_attack(owner_node, enemy_node, thrust_direction):
			continue
		if enemy_node.has_method("take_damage"):
			_damage_target(owner_node, enemy_node, thrust_direction, float(entry.get("factor", 1.0)))


func _show_thrust_step_area(owner_node: Node2D, thrust_direction: Vector2) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	AttackVfx.beam(scene, owner_node.global_position + thrust_direction * start_distance, owner_node.global_position + thrust_direction * attack_range, inner_width, visual_color)


# SCRUM-923: шаг спирали — фронт-дуга spiral_arm_degrees под углом
# base + 360°×(k+1)/steps с радиусом фронта от start_ratio×R до R. Дедуп
# _hit_targets на весь каст (максимум один хит по цели — анти-runaway правило
# AC). Последний шаг замыкает оборот на стартовом угле с полным радиусом —
# соло-цель по направлению атаки гарантированно накрыта к концу каста.
func _run_spiral_step(owner_id: int, step_index: int) -> void:
	if is_queued_for_deletion() or not is_inside_tree():
		return
	var owner_node := instance_from_id(owner_id) as Node2D
	if owner_node == null or not is_instance_valid(owner_node):
		return
	if spiral_steps <= 0 or step_index < 0 or step_index >= spiral_steps:
		return
	var progress := float(step_index + 1) / float(spiral_steps)
	var full_radius := _effective_circle_radius()
	var front_radius := lerpf(full_radius * clampf(spiral_start_radius_ratio, 0.05, 1.0), full_radius, progress)
	var arm_angle := _last_direction.angle() + TAU * progress
	if step_index == 0:
		_show_weapon_signature(owner_node, _last_direction)
	_show_spiral_step_area(owner_node, arm_angle, front_radius)
	var half_arm := deg_to_rad(maxf(spiral_arm_degrees, 10.0) * 0.5)
	for enemy_node in TARGET_QUERY.enemies(self):
		if not is_instance_valid(enemy_node) or _hit_targets.has(enemy_node):
			continue
		if not enemy_node.has_method("take_damage"):
			continue
		var to_enemy := enemy_node.global_position - owner_node.global_position
		var inside := false
		if to_enemy.length_squared() <= CONTACT_STUCK_HIT_RADIUS * CONTACT_STUCK_HIT_RADIUS:
			inside = true
		elif to_enemy.length_squared() <= front_radius * front_radius:
			var angle_delta: float = absf(wrapf(to_enemy.angle() - arm_angle, -PI, PI))
			inside = angle_delta <= half_arm
		if inside:
			var hit_direction := to_enemy.normalized() if to_enemy.length_squared() > 0.001 else _last_direction
			_damage_target(owner_node, enemy_node, hit_direction, 1.0)


func _show_spiral_step_area(owner_node: Node2D, arm_angle: float, front_radius: float) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	var arm_direction := Vector2.from_angle(arm_angle)
	AttackVfx.beam(scene, owner_node.global_position, owner_node.global_position + arm_direction * front_radius, 26.0, visual_color)


# SCRUM-961 «Призрачный топор»: полупрозрачный призрачный взмах-афтеримидж
# по той же дуге с короткой задержкой (существующий slash-VFX, без новых ассетов).
func _show_spectral_followup(owner_node: Node2D, attack_direction: Vector2) -> void:
	var owner_id := owner_node.get_instance_id()
	var ghost_tween := create_tween()
	ghost_tween.tween_interval(0.12)
	ghost_tween.tween_callback(func() -> void:
		var current_owner := instance_from_id(owner_id) as Node2D
		if current_owner == null or not is_instance_valid(current_owner):
			return
		var ghost := AttackVfx.slash(current_owner, attack_direction, attack_range, Color(0.55, 0.82, 1.0, 0.30), PI, _sweep_visual_lateral_scale(), _sweep_visual_degrees())
		if ghost != null:
			ghost.add_to_group("player_weapon_effects")
	)


# SCRUM-961 «Святая цепь»: последовательные касты раскручивают спираль кистеня
# (+12% радиуса за каст после первого, кап +36%); пауза 3с сбрасывает раскрутку.
func _update_flail_spiral() -> void:
	if weapon_id != "holy_flail" or _owner_mod("flail_spiral_growth") <= 0.0:
		return
	var now := Time.get_ticks_msec()
	if now - _flail_last_cast_ms > 3000:
		_flail_spiral_casts = 0
	_flail_last_cast_ms = now
	_flail_spiral_casts = mini(_flail_spiral_casts + 1, 4)


func _damage_target(owner_node: Node2D, enemy_node: Node2D, attack_direction: Vector2, amount_multiplier := 1.0) -> void:
	_hit_targets.append(enemy_node)
	var dealt := _rolled_damage(owner_node) * amount_multiplier
	var hit_context := {"weapon_id": weapon_id, "attack_mode": "melee", "damage_type": "physical"}
	if owner_node.has_method("meta_context_for_weapon"):
		hit_context = owner_node.call("meta_context_for_weapon", self, hit_context)
	if owner_node.has_method("telemetry_context_for_hit"):
		hit_context = owner_node.call("telemetry_context_for_hit", hit_context)
	if owner_node.has_method("meta_damage_multiplier"):
		dealt *= float(owner_node.call("meta_damage_multiplier", hit_context, enemy_node))
	var hit_feedback := {"critical": _last_attack_crit, "damage_type": "physical"}
	if owner_node.has_method("telemetry_feedback_for_hit"):
		hit_feedback = owner_node.call("telemetry_feedback_for_hit", hit_context, hit_feedback)
	_call_take_damage(enemy_node, dealt, hit_feedback)
	if owner_node.has_method("on_weapon_hit"):
		owner_node.on_weapon_hit(enemy_node, dealt, _last_attack_crit, hit_context)
	_apply_unique_melee_hit_effects(owner_node, enemy_node, attack_direction, dealt)
	_apply_constellation_primary_hit(owner_node, enemy_node, attack_direction, dealt)


func _constellation_mechanic(owner_node: Node, mechanic_id: String) -> Dictionary:
	if owner_node == null or not owner_node.has_method("constellation_weapon_mechanic"):
		return {}
	var raw = owner_node.call("constellation_weapon_mechanic", weapon_id, mechanic_id)
	return raw if raw is Dictionary else {}


func _constellation_event(owner_node: Node, event: String, context := {}, enemy: Node2D = null) -> Dictionary:
	if owner_node == null or not owner_node.has_method("constellation_weapon_event"):
		return {"valid": true, "triggered": false, "damage_multiplier": 1.0}
	var raw = owner_node.call("constellation_weapon_event", weapon_id, event, context, enemy)
	return raw if raw is Dictionary else {"valid": false, "triggered": false, "damage_multiplier": 1.0}


# Sword's runtime event is consumed by Player.meta_damage_multiplier. This
# consumer owns the stricter consecutive-target/execute gate and applies only
# the execute payoff; switching targets resets the local sequence.
func _apply_constellation_primary_hit(owner_node: Node2D, enemy_node: Node2D, attack_direction: Vector2, dealt: float) -> void:
	if weapon_id == "sword":
		var sword := _constellation_mechanic(owner_node, "sword_repeat_execute")
		if not sword.is_empty():
			var target_id := enemy_node.get_instance_id()
			if target_id != _sword_repeat_target_id:
				_sword_repeat_target_id = target_id
				_sword_repeat_hits = 0
			_sword_repeat_hits += 1
			var params: Dictionary = sword.get("params", {})
			var required := maxi(int(params.get("required_hits", 3)), 1)
			var max_hp := float(enemy_node.get("max_health")) if enemy_node.get("max_health") != null else 0.0
			var hp := float(enemy_node.get("health")) if enemy_node.get("health") != null else max_hp
			if _sword_repeat_hits >= required and max_hp > 0.0 and hp / max_hp <= clampf(float(params.get("execute_threshold", 0.35)), 0.0, 1.0):
				var bonus := dealt * clampf(float(params.get("boss_bonus_cap", 0.24)), 0.0, 1.0)
				_call_take_damage(enemy_node, bonus, {"damage_type": "physical", "constellation_final": "sword_repeat_execute"})
				_sword_repeat_hits = 0
	if weapon_id == "tower_shield" and _stored_bash_damage > 0.0 and _stored_bash_left > 0.0:
		_call_take_damage(enemy_node, _stored_bash_damage, {"damage_type": "physical", "constellation_final": "shield_stored_damage_bash"})
		_stored_bash_damage = 0.0
		_stored_bash_left = 0.0
	if weapon_id == "long_spear" and _counter_line_left > 0.0 and _counter_line_ratio > 0.0:
		_call_take_damage(enemy_node, dealt * _counter_line_ratio, {"damage_type": "physical", "constellation_final": "spear_block_counter_line"})
		_counter_line_left = 0.0
		_counter_line_ratio = 0.0


func _resolve_constellation_attack(owner_node: Node2D, attack_direction: Vector2, primary_targets: Array) -> void:
	if weapon_id == "axe" and not _constellation_mechanic(owner_node, "axe_outer_followthrough").is_empty():
		var result := _constellation_event(owner_node, "attack_resolved", {"primary_hits": primary_targets.size()})
		if bool(result.get("triggered", false)):
			_apply_axe_outer_followthrough(owner_node, attack_direction, primary_targets, result)
	elif weapon_id == "hammer" and not _constellation_mechanic(owner_node, "hammer_stagger_aftershock").is_empty():
		var result := _constellation_event(owner_node, "attack_resolved", {"primary_hits": primary_targets.size()})
		if bool(result.get("triggered", false)):
			_schedule_hammer_aftershock(owner_node, result)


func _apply_axe_outer_followthrough(owner_node: Node2D, attack_direction: Vector2, primary_targets: Array, result: Dictionary) -> void:
	var mechanic := _constellation_mechanic(owner_node, "axe_outer_followthrough")
	var params: Dictionary = mechanic.get("params", {})
	var target_cap := maxi(int(params.get("extra_arc_targets", 6)), 0)
	var ratio := clampf(float(params.get("followthrough_damage_ratio", 0.42)), 0.0, 1.0)
	if target_cap <= 0 or ratio <= 0.0:
		return
	var excluded := {}
	for target in primary_targets:
		if target != null and is_instance_valid(target):
			excluded[(target as Node).get_instance_id()] = true
	var candidates: Array = []
	for enemy in TARGET_QUERY.enemies(self):
		if enemy == null or not is_instance_valid(enemy):
			continue
		var enemy_node := enemy as Node2D
		if enemy_node == null or excluded.has(enemy_node.get_instance_id()):
			continue
		var offset := enemy_node.global_position - owner_node.global_position
		var distance := offset.length()
		if distance < attack_range * 0.45 or distance > attack_range * 1.12:
			continue
		if absf(wrapf(attack_direction.angle_to(offset.normalized()), -PI, PI)) > deg_to_rad(minf(sweep_degrees * 0.72, 88.0)):
			continue
		candidates.append(enemy_node)
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return owner_node.global_position.distance_squared_to(a.global_position) < owner_node.global_position.distance_squared_to(b.global_position)
	)
	var secondary_damage := _rolled_damage(owner_node) * ratio
	for index in range(mini(candidates.size(), target_cap)):
		var enemy_node := candidates[index] as Node2D
		_call_take_damage(enemy_node, secondary_damage, {"damage_type": "physical", "constellation_final": "axe_outer_followthrough"})


func _schedule_hammer_aftershock(owner_node: Node2D, result: Dictionary) -> void:
	if not is_inside_tree():
		return
	var mechanic := _constellation_mechanic(owner_node, "hammer_stagger_aftershock")
	var params: Dictionary = mechanic.get("params", {})
	var ratio := clampf(float(params.get("aftershock_damage_ratio", 0.38)), 0.0, 1.0)
	var stagger_seconds := maxf(float(params.get("stagger_seconds", 0.65)), 0.0)
	var delayed := create_tween()
	delayed.tween_interval(CONSTELLATION_AFTERSHOCK_DELAY)
	delayed.tween_callback(Callable(self, "_resolve_hammer_aftershock").bind(owner_node.get_instance_id(), _circle_attack_center(owner_node), _rolled_damage(owner_node) * ratio, stagger_seconds))


func _resolve_hammer_aftershock(owner_id: int, center: Vector2, aftershock_damage: float, stagger_seconds: float) -> void:
	var owner_node := instance_from_id(owner_id) as Node2D
	if owner_node == null or not is_instance_valid(owner_node):
		return
	AttackVfx.ring_pulse(get_tree().current_scene if get_tree().current_scene != null else get_tree().root, center, _effective_circle_radius() * 0.72, visual_color, false)
	for enemy in TARGET_QUERY.in_radius(self, center, _effective_circle_radius() * 0.72):
		if enemy == null or not is_instance_valid(enemy):
			continue
		var enemy_node := enemy as Node2D
		if enemy_node == null:
			continue
		_call_take_damage(enemy_node, aftershock_damage, {"damage_type": "physical", "constellation_final": "hammer_stagger_aftershock"})
		if stagger_seconds > 0.0:
			var factor := 0.25 if TARGET_QUERY.is_epic_displacement_immune(enemy_node) else 1.0
			StatusEffects.apply_status(enemy_node, "constellation_hammer_stagger", {"duration": stagger_seconds * factor, "speed_multiplier": 0.72, "marker_color": Color(0.85, 0.72, 0.35, 1.0)})


# Player's generic constellation_owner_event dispatch reaches these bridges on
# qualified knight block/absorb events; exact weapon-id gates prevent leakage.
func constellation_owner_event(event: String, context := {}, enemy: Node2D = null) -> Dictionary:
	var payload: Dictionary = context if context is Dictionary else {}
	match event:
		"block":
			return constellation_on_block(float(payload.get("blocked_amount", payload.get("incoming_amount", 0.0))), enemy)
		"damage_absorbed":
			return constellation_on_damage_absorbed(float(payload.get("absorbed_amount", 0.0)), enemy)
	return {"valid": true, "triggered": false}


func constellation_on_block(incoming_damage: float, attacker: Node2D = null) -> Dictionary:
	var owner_node := _owner_node()
	if weapon_id != "long_spear" or _constellation_mechanic(owner_node, "spear_block_counter_line").is_empty():
		return {"triggered": false}
	var result := _constellation_event(owner_node, "block", {"incoming_damage": maxf(incoming_damage, 0.0)}, attacker)
	if bool(result.get("triggered", false)):
		var params: Dictionary = _constellation_mechanic(owner_node, "spear_block_counter_line").get("params", {})
		_counter_line_ratio = clampf(float(params.get("counter_damage_ratio", 0.52)), 0.0, 1.0)
		_counter_line_left = maxf(float(params.get("window_seconds", 1.0)), 0.0)
	return result


func constellation_on_damage_absorbed(absorbed_damage: float, attacker: Node2D = null) -> Dictionary:
	var owner_node := _owner_node()
	if weapon_id != "tower_shield" or _constellation_mechanic(owner_node, "shield_stored_damage_bash").is_empty():
		return {"triggered": false}
	var result := _constellation_event(owner_node, "damage_absorbed", {"absorbed_damage": maxf(absorbed_damage, 0.0)}, attacker)
	if bool(result.get("triggered", false)):
		var params: Dictionary = _constellation_mechanic(owner_node, "shield_stored_damage_bash").get("params", {})
		var cap := maxf(float(params.get("stored_damage_cap", 30.0)), 0.0)
		_stored_bash_damage = minf(_stored_bash_damage + maxf(absorbed_damage, 0.0) * clampf(float(params.get("storage_ratio", 0.25)), 0.0, 1.0), cap)
		_stored_bash_left = maxf(float(params.get("expiry_seconds", 3.0)), 0.0)
	return result


func constellation_special_state() -> Dictionary:
	return {"sword_repeat_hits": _sword_repeat_hits, "counter_line_left": _counter_line_left, "stored_bash_damage": _stored_bash_damage, "stored_bash_left": _stored_bash_left}


func _circle_damage_factor(target_index: int) -> float:
	if attack_shape != "circle" or circle_target_diminish <= 0.0:
		return 1.0
	var full_targets := maxi(circle_full_targets, 1)
	var diminish := circle_target_diminish
	# SCRUM-961 «Вес молота»: слэм полновесно накрывает больше целей (4→6),
	# хвост толпы гаснет по спеке (0.62→0.78); одиночный DPS не трогается.
	if weapon_id == "hammer" and _owner_mod("hammer_slam_focus") > 0.0:
		full_targets += 2
		diminish += 0.16
	if target_index < full_targets:
		return 1.0
	return 1.0 / (1.0 + float(target_index - full_targets + 1) * diminish)


func _apply_unique_melee_hit_effects(owner_node: Node2D, enemy_node: Node2D, attack_direction: Vector2, amount: float) -> void:
	if enemy_node == null or not is_instance_valid(enemy_node):
		return
	if owner_node == null or not is_instance_valid(owner_node):  # SCRUM-631: owner_node мог быть освобождён между _damage_window и колбэком
		return
	var distance := owner_node.global_position.distance_to(enemy_node.global_position)
	if melee_close_bonus_radius > 0.0 and melee_close_damage_multiplier > 1.0 and distance <= melee_close_bonus_radius:
		enemy_node.take_damage(amount * (melee_close_damage_multiplier - 1.0))
	if melee_execute_threshold > 0.0 and melee_execute_multiplier > 1.0:
		var max_hp := float(enemy_node.get("max_health")) if enemy_node.get("max_health") != null else 0.0
		var health := float(enemy_node.get("health")) if enemy_node.get("health") != null else max_hp
		if max_hp > 0.0 and health / max_hp <= melee_execute_threshold:
			enemy_node.take_damage(amount * (melee_execute_multiplier - 1.0))
	if melee_stagger_knockback_multiplier > 0.0:
		var push_direction := enemy_node.global_position - owner_node.global_position
		if push_direction.length_squared() <= 0.001:
			push_direction = attack_direction
		if enemy_node.has_method("apply_knockback"):
			# SCRUM-922: импульс = (260 фикс + knockback-стат × ratio) × множитель
			# оружия. knockback скейлится пайплайном Player._apply_weapon_scaling
			# (derived knockback_power × meta-множитель) — вложения в отброс дают
			# видимо большее смещение. При ratio=0 поведение прежнее (фикс 260).
			# Боссы/главные элиты капятся epic_stagger_knockback_factor
			# (таксономия CombatTargetQuery.is_epic_displacement_immune;
			# мини-элиты волн отбрасываются полноценно).
			var stagger_impulse := (260.0 + maxf(knockback, 0.0) * maxf(stagger_knockback_stat_ratio, 0.0)) * melee_stagger_knockback_multiplier
			if TARGET_QUERY.is_epic_displacement_immune(enemy_node):
				stagger_impulse *= clampf(epic_stagger_knockback_factor, 0.0, 1.0)
			if stagger_impulse > 0.0:
				enemy_node.apply_knockback(push_direction.normalized() * stagger_impulse)
	# SCRUM-961 «Призрачный топор»: спектральный повтор усиливает followup-дугу
	# (0.12→0.37 у топора); работает только на оружии с followup-геометрией.
	var followup_multiplier := melee_arc_followup_multiplier
	if melee_arc_followup_radius > 0.0:
		followup_multiplier += _owner_mod("spectral_followup_bonus")
	if melee_arc_followup_radius > 0.0 and followup_multiplier > 0.0:
		var splash_damage := amount * followup_multiplier
		for nearby in TARGET_QUERY.in_radius(self, enemy_node.global_position, melee_arc_followup_radius):
			if nearby == enemy_node:
				continue
			if nearby.has_method("take_damage"):
				nearby.take_damage(splash_damage)


func _target_direction(owner_node: Node2D) -> Vector2:
	if owner_node.has_method("attack_aim_mode") and str(owner_node.call("attack_aim_mode")) == "cursor":
		return owner_node.call("attack_aim_direction", _last_direction, attack_range)
	var closest_enemy := _find_closest_enemy(owner_node)
	if closest_enemy == null:
		closest_enemy = _find_closest_enemy(owner_node, INF)
	if closest_enemy == null:
		return _last_direction

	var direction := closest_enemy.global_position - owner_node.global_position
	if direction.length_squared() == 0.0:
		return _last_direction
	return direction.normalized()


func _find_closest_enemy(owner_node: Node2D, range_limit := -1.0) -> Node2D:
	var max_distance := attack_range if range_limit < 0.0 else range_limit
	return TARGET_QUERY.nearest(self, owner_node.global_position, max_distance)


func _is_enemy_inside_attack(owner_node: Node2D, enemy_node: Node2D, attack_direction: Vector2) -> bool:
	if owner_node.global_position.distance_squared_to(enemy_node.global_position) <= CONTACT_STUCK_HIT_RADIUS * CONTACT_STUCK_HIT_RADIUS:
		return true
	if attack_shape == "circle":
		var radius := _effective_circle_radius()
		var center := _circle_attack_center(owner_node)
		var scale := _circle_attack_visual_scale()
		var center_to_enemy := enemy_node.global_position - center
		var normalized_delta := Vector2(
			center_to_enemy.x / maxf(absf(scale.x), 0.001),
			center_to_enemy.y / maxf(absf(scale.y), 0.001)
		)
		return normalized_delta.length_squared() <= radius * radius
	if attack_shape == "sweep":
		return _is_enemy_inside_sweep(owner_node, enemy_node, attack_direction)
	# "strip" — прямоугольная полоса: frustum с равными inner/outer width.
	return _is_enemy_inside_frustum(owner_node, enemy_node, attack_direction)


func _is_enemy_inside_sweep(owner_node: Node2D, enemy_node: Node2D, attack_direction: Vector2) -> bool:
	var to_enemy := enemy_node.global_position - owner_node.global_position
	if to_enemy.length_squared() > attack_range * attack_range:
		return false
	if to_enemy.length_squared() <= 0.001:
		return true

	var direction := attack_direction.normalized()
	var angle_to_enemy: float = abs(wrapf(direction.angle_to(to_enemy.normalized()), -PI, PI))
	return angle_to_enemy <= deg_to_rad(sweep_degrees * 0.5) + 0.001


func _is_enemy_inside_frustum(owner_node: Node2D, enemy_node: Node2D, attack_direction: Vector2) -> bool:
	var direction := attack_direction.normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	var to_enemy := enemy_node.global_position - owner_node.global_position
	var forward_distance := to_enemy.dot(direction)
	if forward_distance < start_distance or forward_distance > attack_range:
		return false

	var usable_length: float = max(attack_range - start_distance, 1.0)
	var distance_ratio: float = clamp((forward_distance - start_distance) / usable_length, 0.0, 1.0)
	var half_width := lerpf(inner_width * 0.5, outer_width * 0.5, distance_ratio)
	var side_distance: float = abs(to_enemy.dot(perpendicular))
	return side_distance <= half_width + 0.001


func _call_take_damage(enemy: Node, amount: float, feedback := {}) -> void:
	if _take_damage_accepts_feedback(enemy):
		var tagged: Dictionary = feedback if feedback is Dictionary else {}
		var owner_node := _owner_node()
		if str(tagged.get("telemetry_provenance_id", "")) == "" and owner_node != null and owner_node.has_method("telemetry_context_for_hit") and owner_node.has_method("telemetry_feedback_for_hit"):
			var telemetry_context: Dictionary = owner_node.call("telemetry_context_for_hit", {"weapon_id": weapon_id, "attack_mode": "melee", "damage_type": str(tagged.get("damage_type", "physical"))})
			tagged = owner_node.call("telemetry_feedback_for_hit", telemetry_context, tagged)
		tagged["player_owned"] = true
		enemy.call("take_damage", amount, tagged)
	else:
		enemy.call("take_damage", amount)


func _take_damage_accepts_feedback(enemy: Node) -> bool:
	for method in enemy.get_method_list():
		if str(method.get("name", "")) == "take_damage":
			var args: Array = method.get("args", [])
			if args.size() < 2:
				return false
			var script: Script = enemy.get_script()
			if script != null and str(script.resource_path) in ["res://scripts/enemy.gd", "res://scripts/boss.gd"]:
				return true
			return enemy.is_in_group("enemies") and enemy.has_method("_show_combat_feedback")
	return false


func _rolled_damage(owner_node: Node2D) -> float:
	# SCRUM-1004 «Ярость»: классовый low-HP множитель владельца (Берсерк:
	# непрерывно ×1.0 → ×1.4 от недостающего HP, см.
	# Player.rage_damage_multiplier) — Berserk-only слой ПОСЛЕ обычных
	# модификаторов урона и крита. Применяется РОВНО один раз за хит: вторичные
	# melee-эффекты (close bonus/execute/followup) наследуют уже усиленный
	# dealt и повторно не множат — рекурсивного стака нет. У владельцев без
	# trait'а метод возвращает 1.0 (data-driven, другим классам не течёт).
	var rage_multiplier := 1.0
	if owner_node != null and owner_node.has_method("rage_damage_multiplier"):
		rage_multiplier = maxf(float(owner_node.call("rage_damage_multiplier")), 0.0)
	var raw_parameters = owner_node.get("derived_parameters")
	if not (raw_parameters is Dictionary):
		return damage * rage_multiplier
	var parameters: Dictionary = raw_parameters
	var result := damage
	_last_attack_crit = false
	if randf() < float(parameters.get("crit_chance", 0.0)):
		result *= float(parameters.get("crit_damage_multiplier", 1.0))
		_last_attack_crit = true
	return result * rage_multiplier


func _show_hit_area(owner_node: Node2D, attack_direction: Vector2) -> void:
	_show_weapon_signature(owner_node, attack_direction)
	if attack_shape == "circle":
		_show_circle_area(owner_node)
	elif attack_shape == "sweep":
		_show_sweep_area(owner_node, attack_direction)
	elif attack_shape == "strip":
		_show_strip_area(owner_node, attack_direction)
	else:
		_show_frustum_area(owner_node, attack_direction)


func _show_weapon_signature(owner_node: Node2D, attack_direction: Vector2) -> void:
	if owner_node == null or attack_direction.length_squared() <= 0.001:
		return
	var direction := attack_direction.normalized()
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	var release_origin := owner_node.global_position + direction * 26.0
	var radius := maxf(aoe_radius, inner_width * 1.45)
	var weapon_texture: Texture2D = null
	var weapon_rotation := 0.0
	var weapon_scale := 0.58
	var weapon_offset := Vector2.ZERO
	if weapon_id == "axe":
		var weapon_visual := get_node_or_null("WeaponVisual") as Sprite2D
		if weapon_visual != null and weapon_visual.texture != null:
			weapon_texture = weapon_visual.texture
			weapon_scale = 0.62
			weapon_offset = Vector2(10.0, -2.0)
	var signature := AttackVfx.weapon_signature(
		scene,
		release_origin,
		weapon_id,
		radius,
		visual_color,
		direction.angle(),
		weapon_texture,
		weapon_rotation,
		weapon_scale,
		weapon_offset,
		AttackVfx.owner_class_id(owner_node)
	)
	if signature != null:
		signature.add_to_group("player_weapon_effects")


func _show_strip_area(owner_node: Node2D, attack_direction: Vector2) -> void:
	# Геометрия зоны урона: прямоугольник start_distance..attack_range шириной inner_width.
	var direction := attack_direction.normalized()
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	var start: Vector2 = owner_node.global_position + direction * start_distance
	var finish: Vector2 = owner_node.global_position + direction * attack_range
	AttackVfx.beam(scene, start, finish, inner_width, visual_color)


func _show_frustum_area(owner_node: Node2D, attack_direction: Vector2) -> void:
	AttackVfx.slash(owner_node, attack_direction, attack_range, visual_color)


func _show_sweep_area(owner_node: Node2D, attack_direction: Vector2) -> void:
	var slash := AttackVfx.slash(
		owner_node,
		attack_direction,
		attack_range,
		visual_color,
		PI,
		_sweep_visual_lateral_scale(),
		_sweep_visual_degrees()
	)
	if slash != null:
		slash.add_to_group("player_weapon_effects")


func _sweep_visual_lateral_scale() -> float:
	if weapon_id != "axe":
		return 1.0
	return clampf(sweep_degrees / 110.0, 1.0, 1.75)


func _sweep_visual_degrees() -> float:
	if weapon_id != "axe":
		return 0.0
	return sweep_degrees


func _sweep_zone_points(direction: Vector2) -> PackedVector2Array:
	var half_sweep := deg_to_rad(sweep_degrees * 0.5)
	var points := PackedVector2Array([Vector2.ZERO])
	for point_index in range(17):
		var angle := lerpf(-half_sweep, half_sweep, float(point_index) / 16.0)
		points.append(direction.rotated(angle) * attack_range)
	return points


func _show_circle_area(owner_node: Node2D) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	var slam := AttackVfx.hammer_slam(scene, _circle_attack_center(owner_node), _effective_circle_radius(), visual_color)
	if slam != null:
		slam.scale *= _circle_attack_visual_scale()


# SCRUM-1043 Animator handoff API. Both helpers deliberately default to the
# legacy centered circle for Holy Flail and every future non-hammer circle.
# Scene-specific hammer VFX bridges may consume these protected hooks instead
# of duplicating gameplay geometry constants.
func _circle_attack_center(owner_node: Node2D) -> Vector2:
	if owner_node == null:
		return Vector2.ZERO
	if weapon_id == "hammer":
		return owner_node.global_position + HAMMER_CIRCLE_CENTER_OFFSET
	return owner_node.global_position


func _circle_attack_visual_scale() -> Vector2:
	if weapon_id == "hammer":
		return HAMMER_CIRCLE_VISUAL_SCALE
	return Vector2.ONE


func _effective_circle_radius() -> float:
	var radius := aoe_radius
	if max_aoe_radius > 0.0:
		radius = minf(aoe_radius, max_aoe_radius)
	# SCRUM-961 «Вес молота»: слэм ложится шире (+12%).
	if weapon_id == "hammer" and _owner_mod("hammer_slam_focus") > 0.0:
		radius *= 1.12
	# SCRUM-961 «Святая цепь»: спираль раскручена от последовательных кастов.
	if weapon_id == "holy_flail" and _owner_mod("flail_spiral_growth") > 0.0:
		radius *= 1.0 + 0.12 * float(maxi(_flail_spiral_casts - 1, 0))
	return radius


func _owner_node() -> CharacterBody2D:
	var parent_node := get_parent()
	while parent_node != null:
		if parent_node is CharacterBody2D:
			return parent_node
		parent_node = parent_node.get_parent()
	return null


func _capture_base_values() -> void:
	if not has_meta("base_damage"):
		set_meta("base_damage", damage)
	if not has_meta("base_fire_interval"):
		set_meta("base_fire_interval", fire_interval)
	if not has_meta("base_attack_range"):
		set_meta("base_attack_range", attack_range)
	if not has_meta("base_aoe_radius"):
		set_meta("base_aoe_radius", aoe_radius)
	if not has_meta("base_max_aoe_radius"):
		set_meta("base_max_aoe_radius", max_aoe_radius)
	if not has_meta("base_inner_width"):
		set_meta("base_inner_width", inner_width)
	if not has_meta("base_outer_width"):
		set_meta("base_outer_width", outer_width)
