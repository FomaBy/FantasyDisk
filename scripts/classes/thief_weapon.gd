extends "res://scripts/classes/soldier_weapon.gd"

# FAN-3840: модуль распределённого боевого класса ClassWeapon — класс-локальные исполнители и приватные хелперы класса thief.
# Часть линейной extends-цепочки scripts/classes/** (сборка — фасад
# scripts/class_weapon.gd). Код перенесён из class_weapon.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в class_weapon_shared_api.gd.


# === SCRUM-897: кит Вора (редизайн поверх trait «Воровская хватка») ===
# Ниши: экономический рикошет по толпе / контроль-кинжал с backstab-пейоффом /
# защитная дым-зона с разовым AoE-взрывом. Константы ниже — единственный источник
# истины по капам/долям; бюджетная модель (_budget_hit_model в progression_data.gd)
# зеркалит эти же числа в комментариях.

# «Кошель Рикошета»: жёсткий кап длины цепи. База 6 прыжков (projectile_count),
# артефакт «Счастливая монета» (coin_extra_bounces) добирает до 8; FAN-1893:
# generic extra_projectile цепь не удлиняет. Цепь конечна и не становится
# лучшим полнокартным клиром (полоса AC 5..8).
const COIN_CHAIN_HARD_CAP := 8


# «Отравленный Кинжал»: базовый удар фантома в долях ролла и позиционный пейофф.
const BACKSTAB_STRIKE_MULTIPLIER := 1.22       # базовый удар фантома


const BACKSTAB_POSITIONAL_MULTIPLIER := 1.35   # доп. множитель удара В СПИНУ (цель смотрит прочь от фантома)


const BACKSTAB_NEIGHBOR_SHARE := 0.35          # доля ролла соседям у точки удара


const BACKSTAB_FACING_DOT_THRESHOLD := 0.25    # порог «спина отдана фантому» (dot facing · фантом→цель)


const POISON_PARALYSIS_SPEED := 0.12           # целевой множитель скорости яда (StatusEffects клампит группу на 0.25)


func _exec_coin_ricochet(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_coin_ricochet(owner_node, target, direction)


func _exec_shadow_backstab(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_shadow_backstab(owner_node, target, direction)


func _exec_smoke_bomb(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_smoke_bomb(owner_node, target, direction)


func _fire_coin_ricochet(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var current_target := target
	if current_target == null:
		current_target = _find_closest_enemy(owner_node, INF)
	if current_target == null:
		var miss := _spawn_projectile_visual(owner_node.global_position + direction * 24.0, direction)
		_register_effect(miss)
		var miss_tween := create_tween()
		miss_tween.tween_property(miss, "global_position", owner_node.global_position + direction * min(attack_range, 280.0), 0.18)
		# SCRUM-551: резолвим miss/self по instance_id (захват Node в lambda «освобождался» в CSV).
		var miss_id := miss.get_instance_id()
		var weapon_miss_self_id := get_instance_id()
		miss_tween.tween_callback(func() -> void:
			var w := instance_from_id(weapon_miss_self_id) as Node
			var m := instance_from_id(miss_id) as Node
			if w != null and is_instance_valid(w) and m != null and is_instance_valid(m):
				w.call("_release_effect", m)
		)
		return

	var chain_targets := [current_target]
	var used := {current_target.get_instance_id(): true}
	var search_origin := current_target.global_position
	# FAN-1893: прыжки рикошета — не снаряды; цепь удлиняет только классовый
	# артефакт coin_extra_bounces (SCRUM-961 «Счастливая монета»), generic
	# extra_projectile инертен. SCRUM-897 капит длину COIN_CHAIN_HARD_CAP —
	# рикошет конечен по AC.
	var chain_count := clampi(projectile_count + int(_owner_mod("coin_extra_bounces")), 1, COIN_CHAIN_HARD_CAP)
	for chain_index in range(chain_count - 1):
		var next_target := _find_nearest_enemy_from(search_origin, attack_range * 0.65, used)
		if next_target == null:
			break
		chain_targets.append(next_target)
		used[next_target.get_instance_id()] = true
		search_origin = next_target.global_position

	var damage_value := _rolled_damage(owner_node)
	var origin := owner_node.global_position + direction * 24.0
	# SCRUM-897: монотонный спад до damage_falloff-доли (0.5) на ПОСЛЕДНЕМ
	# ЗАДУМАННОМ прыжке: hit_i = ролл × tail^(i/(n-1)). Экспонента считается от
	# полной длины цепи, поэтому спад читаем при любом числе реально найденных целей.
	var chain_tail := clampf(damage_falloff, 0.1, 1.0)
	var chain_span := maxf(float(chain_count - 1), 1.0)
	for hit_index in range(chain_targets.size()):
		var enemy_node := chain_targets[hit_index] as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var segment := AttackVfx.beam(_projectile_parent(), origin, enemy_node.global_position, beam_width, visual_color)
		_register_effect(segment)
		_register_effect(AttackVfx.projectile_trace(_projectile_parent(), origin, enemy_node.global_position, visual_color, _projectile_visual_profile(), 0.10))
		var hit_damage := damage_value * pow(chain_tail, float(hit_index) / chain_span)
		_damage_enemy(enemy_node, hit_damage)
		_try_steal_money(owner_node, hit_index)
		origin = enemy_node.global_position
	if chain_targets.size() >= 4:
		_constellation_event("return", chain_targets[0] as Node2D, damage_value, {"unique_targets": chain_targets.size()})


# SCRUM-897 «Отравленный Кинжал»: фантомный удар из тени ЗА ближайшей целью.
# Герой НЕ двигается и НЕ телепортируется (позиционный пейофф в духе Dead Cells
# Assassin's Dagger): кинжал материализуется за спиной цели, паралич-яд даёт окно
# на побег или добивание, удар в спину бьёт больнее.
func _fire_shadow_backstab(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var backstab_target := target
	if backstab_target == null:
		backstab_target = _find_closest_enemy(owner_node, INF)
	if backstab_target == null:
		_fire_stab_flurry(owner_node, direction)
		return
	var approach := (backstab_target.global_position - owner_node.global_position).normalized()
	if approach.length_squared() <= 0.001:
		approach = direction
	var start_position := owner_node.global_position
	var back_position := backstab_target.global_position + approach * 46.0
	var shadow_distance := start_position.distance_to(back_position)
	var max_shadow_reach := minf(attack_range, 360.0)
	if shadow_distance > max_shadow_reach:
		back_position = start_position + (back_position - start_position).normalized() * max_shadow_reach
	var strike_direction := (backstab_target.global_position - back_position).normalized()
	if strike_direction.length_squared() <= 0.001:
		strike_direction = -approach
	var slash := AttackVfx.slash(_projectile_parent(), strike_direction, aoe_radius, visual_color)
	_register_effect(slash)
	slash.global_position = back_position
	var damage_value := _rolled_damage(owner_node)
	var strike_damage := damage_value * BACKSTAB_STRIKE_MULTIPLIER
	# Позиционный backstab: цель отдаёт спину фантому (смотрит/движется прочь) —
	# чейзеры, идущие на героя, наказываются; враг, глядящий на фантом, видит удар.
	var positional_backstab := _is_backstab_hit(backstab_target, back_position, owner_node.global_position)
	if positional_backstab:
		strike_damage *= BACKSTAB_POSITIONAL_MULTIPLIER
	_damage_enemy(backstab_target, strike_damage)
	if positional_backstab and is_instance_valid(backstab_target):
		var mark_result := _constellation_event("hit", backstab_target, 0.0, {"constellation_consumer_event": true})
		if bool(mark_result.get("triggered", false)):
			_arm_constellation_target_mark(backstab_target, "backstab", _constellation_result_param(mark_result, "mark_duration_seconds", 2.5), _constellation_result_param(mark_result, "followup_damage_cap", 0.28), _constellation_result_param(mark_result, "execute_threshold", 0.30))
	# Встроенный контроль SCRUM-897: короткое окно паралича-яда (кап, босс-резист);
	# SCRUM-961 «Парализующее лезвие» (backstab_root_duration) продлевает окно.
	var paralysis_window := clampf(poison_paralysis_duration + _owner_mod("backstab_root_duration"), 0.0, POISON_PARALYSIS_CAP)
	_apply_poison_paralysis(backstab_target, paralysis_window)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_node := enemy as Node2D
		if enemy_node == null or enemy_node == backstab_target or not is_instance_valid(enemy_node):
			continue
		if back_position.distance_squared_to(enemy_node.global_position) <= pow(aoe_radius * 0.55, 2.0):
			_damage_enemy(enemy_node, damage_value * BACKSTAB_NEIGHBOR_SHARE)
			_apply_poison_paralysis(enemy_node, paralysis_window)
	var vanish := AttackVfx.ring_pulse(_projectile_parent(), back_position, 62.0, visual_color, false)
	_register_effect(vanish)


# SCRUM-897: условие удара в спину — цель смотрит ПРОЧЬ от фантома. Направление
# взгляда: живая скорость врага (движение), иначе фоллбэк «чейзер смотрит на
# героя». Фантом появляется за спиной цели относительно героя, поэтому идущий на
# героя враг отдаёт спину, а убегающий/идущий на фантом — видит кинжал.
func _is_backstab_hit(enemy_node: Node2D, phantom_position: Vector2, owner_position: Vector2) -> bool:
	var away_from_phantom := enemy_node.global_position - phantom_position
	if away_from_phantom.length_squared() <= 0.001:
		return true
	var facing := Vector2.ZERO
	var velocity_raw = enemy_node.get("velocity")
	if velocity_raw is Vector2 and (velocity_raw as Vector2).length_squared() > 4.0:
		facing = (velocity_raw as Vector2).normalized()
	else:
		facing = (owner_position - enemy_node.global_position).normalized()
	if facing.length_squared() <= 0.001:
		return true
	return facing.dot(away_from_phantom.normalized()) >= BACKSTAB_FACING_DOT_THRESHOLD


func _apply_poison_paralysis(enemy_node: Node2D, duration: float) -> void:
	var effective_duration := duration * _control_resist_factor(enemy_node)
	if effective_duration <= 0.0:
		return
	# Паралич-лайт: StatusEffects.speed_multiplier клампит группу статусов на 0.25 —
	# жертва почти стоит, но контроль не абсолютен и всегда конечен.
	StatusEffects.apply_status(enemy_node, "poison_paralysis", {
		"duration": effective_duration,
		"speed_multiplier": POISON_PARALYSIS_SPEED,
		"marker_color": Color(0.50, 0.95, 0.45, 1.0),
	})


# SCRUM-897 «Дымовая Бомба»: брошенный снаряд с отложенной детонацией. Шашка
func _fire_smoke_bomb(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_emit_weapon_animation_event(owner_node, "windup", maxf(grenade_delay, 0.10), direction, {"delayed": true})
	var target_position: Vector2 = owner_node.global_position + direction * min(attack_range, 240.0)
	if target != null:
		target_position = target.global_position
	var bomb := _spawn_projectile_visual(owner_node.global_position + direction * 20.0, target_position - owner_node.global_position)
	_register_effect(bomb)
	var fuse := maxf(grenade_delay, 0.10)
	var travel_tween := create_tween()
	travel_tween.tween_property(bomb, "global_position", target_position, fuse)
	# SCRUM-551: без захвата узлов в лямбду — Callable.bind по instance_id
	# (tween умирает вместе с оружием, бесхозная детонация невозможна).
	var detonation_tween := create_tween()
	detonation_tween.tween_interval(fuse)
	detonation_tween.tween_callback(Callable(self, "_detonate_smoke_bomb").bind(owner_node.get_instance_id(), bomb.get_instance_id(), target_position, direction))


func _detonate_smoke_bomb(owner_instance_id: int, bomb_instance_id: int, target_position: Vector2, direction: Vector2) -> void:
	var bomb := instance_from_id(bomb_instance_id) as Node
	if bomb != null and is_instance_valid(bomb):
		_release_effect(bomb)
	if _effects_shutdown:
		return
	var current_owner := instance_from_id(owner_instance_id) as Node2D
	if current_owner != null and not is_instance_valid(current_owner):
		current_owner = null
	var damage_value := damage if current_owner == null else _rolled_damage(current_owner)
	# Единственное дамажащее событие дыма — сам взрыв.
	_damage_enemies_in_circle(target_position, aoe_radius, damage_value)
	AttackVfx.orb_burst(_projectile_parent(), target_position, aoe_radius, _projectile_impact_color())
	# Облако после взрыва урона НЕ наносит — только позиционное уклонение.
	var cloud := AttackVfx.ring_pulse(_projectile_parent(), target_position, aoe_radius, visual_color, true)
	_register_effect(cloud)
	var cloud_duration := maxf(_effective_smoke_duration(), 0.2)
	if current_owner != null:
		_emit_weapon_animation_event(current_owner, "release", cloud_duration, direction, {"delayed": true})
		# SCRUM-961 «Дымный тайник»: облако плотнее (+smoke_dodge_bonus) и дольше
		# (_effective_smoke_duration); бонус живёт только внутри зоны облака.
		var cloud_dodge := dodge_bonus + _owner_mod("smoke_dodge_bonus")
		if current_owner.has_method("register_smoke_cloud"):
			current_owner.call("register_smoke_cloud", target_position, aoe_radius, cloud_duration, cloud_dodge)
	var cloud_tween := create_tween()
	cloud_tween.tween_interval(cloud_duration)
	cloud_tween.tween_callback(Callable(self, "_release_effect_by_id").bind(cloud.get_instance_id()))


func _try_steal_money(owner_node: Node2D, hit_index: int) -> void:
	# SCRUM-897: золото начисляется МГНОВЕННО в кошель забега (gain_money) — без
	# спавна и сбора money-пикапа — и ДЕТЕРМИНИРОВАННО с первых steal_hits целей
	# цепи (читаемая экономика вместо прежнего 42%-ролла по хвосту).
	# SCRUM-961 «Счастливая монета»: coin_steal_bonus добавляет краденое золото.
	var effective_steal := steal_money + int(_owner_mod("coin_steal_bonus")) if steal_money > 0 else steal_money
	if effective_steal <= 0 or owner_node == null or not owner_node.has_method("gain_money"):
		return
	if hit_index >= maxi(steal_hits, 1):
		return
	owner_node.gain_money(effective_steal)


# SCRUM-897: прежний глобальный временный dodge (_apply_temporary_dodge через
# run_modifiers) удалён — уклонение дыма стало ПОЗИЦИОННЫМ (только внутри облака,
# см. _detonate_smoke_bomb + Player.smoke_cloud_dodge_bonus).
# SCRUM-961 «Дымный тайник»: длительность завесы с бонусом артефакта.
func _effective_smoke_duration() -> float:
	return smoke_duration * (1.0 + _owner_mod("smoke_duration_mult"))
