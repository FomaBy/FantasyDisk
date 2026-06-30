extends "res://scripts/enemy.gd"

# SCRUM-790: доставленные radial telegraph-PNG секретного босса (Animator-pack SCRUM-539).
# Используются ТОЛЬКО для secret_ascension_boss и ТОЛЬКО на круговых зонах (radius-based),
# с которыми их радиальная геометрия совпадает. См. коммент в _spawn_secret_sector_ring.
const SECRET_RING_TELEGRAPH := preload("res://assets/sprites/effects/secret_ascension_boss_ring_telegraph.png")
const SECRET_RUPTURE_TELEGRAPH := preload("res://assets/sprites/effects/secret_ascension_boss_rupture_telegraph.png")

# SCRUM-791: НАПРАВЛЕННЫЕ telegraph-PNG секретного босса (cone-sector / beam-lane).
# Канон ориентации обоих PNG — +X: исток (вершина конуса / устье луча) слева, форма
# растёт вправо. *_ANCHOR_PX — пиксель-исток, который сажается в origin зоны и вокруг
# которого крутится телеграф под направление атаки. *_LENGTH_PX — активная длина арта
# от истока до края (замерено по alpha). FAIRNESS: та же `dir`, что крутит телеграф,
# питает геометрию урона (directional_hit) — ориентация PNG == геометрия зоны.
const SECRET_CONE_TELEGRAPH := preload("res://assets/sprites/effects/secret_ascension_boss_cone_telegraph.png")
const SECRET_BEAM_TELEGRAPH := preload("res://assets/sprites/effects/secret_ascension_boss_beam_telegraph.png")
const SECRET_CONE_ANCHOR_PX := Vector2(77.0, 281.0)
const SECRET_CONE_LENGTH_PX := 617.0
const SECRET_CONE_HALF_ANGLE := 0.384  # ~22°, внутри видимого раствора арт-конуса (fairness)
const SECRET_BEAM_ANCHOR_PX := Vector2(121.0, 146.0)
const SECRET_BEAM_LENGTH_PX := 525.0
const SECRET_BEAM_HALF_WIDTH_PX := 48.0  # внутри видимой полосы (~52px) арт-луча (fairness)

@export var boss_behavior := ""
# Русский титул для баннера появления (enemy_type_name остаётся системным).
@export var boss_display_name := ""
@export var burst_projectile_count := 10
@export var burst_interval := 4.0
@export var dash_interval := 5.5
@export var dash_speed := 380.0
@export var dash_duration := 0.55
@export var shield_interval := 6.5
@export var shield_duration := 1.7
@export var shield_damage_reduction := 0.45
@export var dodge_chance := 0.12
@export var boss_summon_scene: PackedScene
@export var boss_summon_interval := 8.0
@export var rift_zone_interval := 5.3
@export var slam_interval := 5.8
@export var zone_wave_interval := 9.0
@export var enrage_health_ratio := 0.35

const BOSS_PHASE_MARKERS := [0.66, 0.33]
const SECRET_BOSS_PHASE_MARKERS := [0.50, 0.25]
# SCRUM-596: жёсткий потолок одновременно живых призывов босса. _summon_riftlings
# обязан только ДОЗАПОЛНЯТЬ до этого числа (учитывая уже живых), а не спавнить
# безусловную пачку поверх лимита.
const MAX_SUMMONED_RIFTLINGS := 8

var _burst_cooldown := 2.0
var _dash_cooldown := 3.0
var _dash_time_left := 0.0
var _dash_direction := Vector2.ZERO
var _shield_cooldown := 4.0
var _shield_time_left := 0.0
var _boss_summon_cooldown := 5.0
var _boss_directional_cooldown := 5.2  # SCRUM-791: cone/beam-каденс секретного босса
var _directional_beam_next := false    # чередование cone↔beam (beam — c фазы 2)
var _rift_zone_cooldown := 3.4
var _slam_cooldown := 4.2
var _zone_wave_cooldown := 6.0
var _boss_unique_cooldown := 5.4
var shield_active := false
var _enraged := false
var boss_phase := 1


func _ready() -> void:
	super()
	add_to_group("bosses")
	if boss_behavior == "":
		boss_behavior = "disk_devourer" if enemy_type_name == "Disk Devourer" else "rift_warden"
	set_meta("boss_behavior", boss_behavior)
	_apply_unique_encounter_pattern_meta(boss_behavior)
	if _full_frame_body() == null:
		_configure_full_frame_animation()
	set_meta("boss_phase", boss_phase)
	var phase_markers := _phase_markers_for_behavior()
	set_meta("boss_phase_markers", phase_markers)
	var health_bar := get_node_or_null("HealthBar")
	if health_bar != null:
		health_bar.set_meta("phase_markers", phase_markers)
	_update_shield_visual()
	_update_health_bar()


func _physics_process(delta: float) -> void:
	if _dash_time_left > 0.0:
		_dash_time_left -= delta
		velocity = _dash_direction * dash_speed
		move_and_slide()
		global_position = _clamp_to_arena(global_position)
		_update_movement_animation(delta)
	else:
		super(delta)

	_update_shield(delta)
	_update_boss_phase()
	_update_enrage()
	_update_boss_attacks(delta)


func take_damage(amount: float, feedback := {}) -> void:
	var final_amount := amount
	if amount < max_health and randf() < dodge_chance:
		_flash_dodge()
		return
	if shield_active:
		final_amount *= shield_damage_reduction
	super(final_amount, feedback)


func _update_boss_attacks(delta: float) -> void:
	var player := _player()
	if player == null:
		return

	_burst_cooldown -= delta
	match boss_behavior:
		"disk_devourer":
			_dash_cooldown -= delta
			_slam_cooldown -= delta
			if _dash_cooldown <= 0.0:
				_start_dash_toward(player)
				_dash_cooldown = dash_interval * _phase_interval_multiplier(0.82 if _enraged else 1.0)
			if _slam_cooldown <= 0.0:
				_spawn_disk_slam()
				_slam_cooldown = slam_interval * _phase_interval_multiplier(0.86 if _enraged else 1.0)
			if _burst_cooldown <= 0.0:
				_fire_radial_burst()
				_burst_cooldown = burst_interval * _phase_interval_multiplier(0.90 if _enraged else 1.0)
		"bone_archon":
			# Некромант: волны скелетов (summon) + черепа веером (volley);
			# «костяная стена» — общий паттерн волны зон с проходом (чаще: интервал в сцене).
			_boss_summon_cooldown -= delta
			if _burst_cooldown <= 0.0:
				_fire_targeted_volley(player)
				_burst_cooldown = burst_interval * _phase_interval_multiplier()
			if _boss_summon_cooldown <= 0.0:
				_summon_riftlings()
				_boss_summon_cooldown = boss_summon_interval * _phase_interval_multiplier(0.85 if _enraged else 1.0)
		"brood_mother":
			# Рой: частый выводок мелких + паутинные зоны замедления; рывок — в фазе 3.
			_boss_summon_cooldown -= delta
			_rift_zone_cooldown -= delta
			if _boss_summon_cooldown <= 0.0:
				_summon_riftlings()
				_boss_summon_cooldown = boss_summon_interval * _phase_interval_multiplier(0.8 if _enraged else 1.0)
			if _rift_zone_cooldown <= 0.0:
				_spawn_web_zone(player.global_position)
				_rift_zone_cooldown = rift_zone_interval * _phase_interval_multiplier()
			if boss_phase >= 3:
				_dash_cooldown -= delta
				if _dash_cooldown <= 0.0:
					_start_dash_toward(player)
					_dash_cooldown = dash_interval * _phase_interval_multiplier()
		"ashen_colossus":
			# Медленный гигант: slam-волны с тлеющими зонами после ударов;
			# редкий radial burst. Энрейдж <25% HP — быстрее и шире (см. _update_enrage).
			_slam_cooldown -= delta
			if _slam_cooldown <= 0.0:
				_spawn_disk_slam()
				_slam_cooldown = slam_interval * _phase_interval_multiplier(0.72 if _enraged else 1.0)
			if _burst_cooldown <= 0.0:
				_fire_radial_burst()
				_burst_cooldown = burst_interval * _phase_interval_multiplier()
		"secret_ascension_boss":
			_slam_cooldown -= delta
			_rift_zone_cooldown -= delta
			_boss_summon_cooldown -= delta
			if _slam_cooldown <= 0.0:
				_spawn_disk_slam()
				_slam_cooldown = slam_interval * _phase_interval_multiplier(0.78 if _enraged else 1.0)
			if _rift_zone_cooldown <= 0.0:
				_spawn_secret_eruption_cluster(player.global_position)
				_rift_zone_cooldown = rift_zone_interval * _phase_interval_multiplier(0.86)
			if _burst_cooldown <= 0.0:
				_fire_radial_burst()
				_spawn_secret_sector_ring(player.global_position)
				_burst_cooldown = burst_interval * _phase_interval_multiplier(0.82 if boss_phase >= 2 else 1.0)
			_boss_directional_cooldown -= delta
			if _boss_directional_cooldown <= 0.0:
				_spawn_secret_directional(player.global_position)
				_boss_directional_cooldown = (4.2 if _enraged else 5.2) * _phase_interval_multiplier(0.85 if boss_phase >= 2 else 1.0)
			if boss_phase >= 2 and _boss_summon_cooldown <= 0.0:
				_summon_riftlings()
				_boss_summon_cooldown = boss_summon_interval * _phase_interval_multiplier(0.82)
		_:
			_boss_summon_cooldown -= delta
			_rift_zone_cooldown -= delta
			if _burst_cooldown <= 0.0:
				_fire_targeted_volley(player)
				_burst_cooldown = burst_interval * _phase_interval_multiplier()
			if _rift_zone_cooldown <= 0.0:
				_spawn_rift_zone(player.global_position)
				_rift_zone_cooldown = rift_zone_interval * _phase_interval_multiplier()
			if _boss_summon_cooldown <= 0.0:
				_summon_riftlings()
				_boss_summon_cooldown = boss_summon_interval * _phase_interval_multiplier()

	_update_boss_unique_mechanic(delta, player)

	# +1 опасный паттерн (независим от фаз, оба босса): волна зон по периметру с
	# гарантированным проходом — короче окно безопасности, но коридор всегда есть.
	_zone_wave_cooldown -= delta
	if _zone_wave_cooldown <= 0.0:
		_spawn_zone_wave(player.global_position)
		_zone_wave_cooldown = zone_wave_interval * _phase_interval_multiplier()


func _update_boss_unique_mechanic(delta: float, player: Node2D) -> void:
	_boss_unique_cooldown -= delta
	if _boss_unique_cooldown > 0.0:
		return
	match boss_behavior:
		"rift_warden":
			_spawn_gravity_well(player.global_position)
			_boss_unique_cooldown = 8.8 * _phase_interval_multiplier()
		"disk_devourer":
			if player.global_position.distance_to(global_position) <= 280.0:
				_spawn_vampiric_bite(player)
				_boss_unique_cooldown = 7.2 * _phase_interval_multiplier(0.88 if _enraged else 1.0)
			else:
				_boss_unique_cooldown = 1.2
		"bone_archon":
			_spawn_bone_prison(player.global_position)
			_boss_unique_cooldown = 9.5 * _phase_interval_multiplier()
		"brood_mother":
			_spawn_web_zone(player.global_position + Vector2.RIGHT.rotated(randf() * TAU) * 120.0)
			_boss_unique_cooldown = 8.0 * _phase_interval_multiplier()
		"ashen_colossus":
			_spawn_molten_armor_pulse()
			_boss_unique_cooldown = 8.5 * _phase_interval_multiplier(0.82 if _enraged else 1.0)
		"secret_ascension_boss":
			_spawn_secret_sector_ring(player.global_position)
			if boss_phase >= 2:
				_spawn_secret_eruption_cluster(player.global_position)
			_boss_unique_cooldown = 6.8 * _phase_interval_multiplier(0.78 if boss_phase >= 2 else 1.0)
		_:
			_boss_unique_cooldown = 6.0


func _spawn_zone_wave(center: Vector2) -> void:
	# Кольцо зон вокруг игрока с двумя смежными пропущенными секторами —
	# гарантированный безопасный коридор (safe corridor, req В4+).
	var count := 8
	var ring_radius := 360.0
	var gap_index := randi() % count
	var rift_wave_skill := _boss_rift_zone_skill_state()
	if rift_wave_skill != "":
		_play_boss_skill_visual(rift_wave_skill, "cast", center - global_position)
	for i in range(count):
		if i == gap_index or i == (gap_index + 1) % count:
			continue
		var angle := TAU * float(i) / float(count)
		_spawn_rift_zone(_clamp_to_arena(center + Vector2.RIGHT.rotated(angle) * ring_radius, 92.0), false)


func _spawn_secret_sector_ring(center: Vector2) -> void:
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	var rift_skill := _boss_rift_zone_skill_state()
	if rift_skill != "":
		_play_boss_skill_visual(rift_skill, "cast", center - global_position)
	var marker := Node2D.new()
	marker.name = "SecretBossSectorRing"
	marker.add_to_group("enemy_hazards")
	marker.set_meta("boss_behavior", boss_behavior)
	marker.global_position = _clamp_to_arena(center, 180.0)
	marker.z_index = 10
	parent.add_child(marker)
	var radius := _safe_radius(250.0 + float(boss_phase - 1) * 34.0)
	var color := Color(0.78, 0.24, 1.0, 1.0)
	var windup := _ascension_telegraph(0.78)
	# SCRUM-790: доставленный radial ring-PNG вместо процедурного круга (зона круговая —
	# геометрия совпадает, ротация не нужна). Только секретный босс.
	var ring_tex: Texture2D = SECRET_RING_TELEGRAPH if boss_behavior == "secret_ascension_boss" else null
	HazardVfx.telegraph(marker, radius, color, windup, ring_tex)
	var marker_ref: WeakRef = weakref(marker)
	var tween := marker.create_tween()
	tween.tween_interval(windup)
	tween.tween_callback(func() -> void:
		var m: Node2D = marker_ref.get_ref()
		if m == null:
			return
		HazardVfx.detonate(m, radius, color)
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null and player.global_position.distance_to(m.global_position) <= radius and player.has_method("take_damage"):
			player.take_damage(projectile_damage * (0.82 + float(boss_phase - 1) * 0.18), "secret_sector_ring")
	)
	tween.tween_interval(0.45)
	tween.tween_callback(marker.queue_free)

	var count := 10 + (boss_phase - 1) * 2
	var gap_index := randi() % count
	var ring_radius := 410.0 + float(boss_phase - 1) * 24.0
	for index in range(count):
		if index == gap_index or index == (gap_index + 1) % count:
			continue
		var angle := TAU * float(index) / float(count)
		_spawn_rift_zone(_clamp_to_arena(center + Vector2.RIGHT.rotated(angle) * ring_radius, 92.0), false)


func _spawn_secret_eruption_cluster(center: Vector2) -> void:
	var count := 3 + int(boss_phase >= 2) + int(_enraged)
	for index in range(count):
		var angle := TAU * (float(index) / float(maxi(count, 1))) + randf_range(-0.24, 0.24)
		var distance := randf_range(70.0, 210.0 + float(boss_phase - 1) * 30.0)
		_spawn_rift_zone(_clamp_to_arena(center + Vector2.RIGHT.rotated(angle) * distance, 92.0), index == 0)


# SCRUM-791: чистая (без self/SceneTree) функция теста попадания направленной зоны —
# ЕДИНСТВЕННЫЙ источник правды для геометрии урона cone/beam. Та же `dir`, что крутит
# telegraph-PNG, питает эту проверку → ориентация телеграфа == геометрия зоны (fairness).
# kind: "cone" — угловой сектор от вершины `origin` (half_extent = полу-угол, рад;
#       урон если dist≤length и |угол(point−origin, dir)|≤half_extent);
# kind: "beam" — прямой коридор от устья `origin` вдоль `dir` (half_extent = полуширина;
#       урон если проекция на ось в [0, length] и |перпендикуляр|≤half_extent).
static func directional_hit(kind: String, origin: Vector2, dir: Vector2, length: float, half_extent: float, point: Vector2) -> bool:
	var d := dir.normalized()
	if d == Vector2.ZERO:
		return false
	var rel := point - origin
	if kind == "beam":
		var along := rel.dot(d)
		if along < 0.0 or along > length:
			return false
		return absf(rel.dot(Vector2(-d.y, d.x))) <= half_extent
	# cone
	var dist := rel.length()
	if dist < 1.0:
		return true
	if dist > length:
		return false
	return absf(rel.angle_to(d)) <= half_extent


# SCRUM-791: один направленный удар секретного босса — конус-сектор (с фазы 1) либо
# луч-коридор (чередуется с фазы 2). Цель — текущая позиция игрока на момент каста;
# windup-телеграф даёт окно для уворота вбок (fairness).
func _spawn_secret_directional(target: Vector2) -> void:
	var dir := target - global_position
	if dir.length_squared() < 1.0:
		dir = Vector2.RIGHT.rotated(randf() * TAU)
	dir = dir.normalized()
	var use_beam := _directional_beam_next and boss_phase >= 2
	_directional_beam_next = not _directional_beam_next
	if use_beam:
		_spawn_secret_directional_zone("beam", dir, SECRET_BEAM_TELEGRAPH, SECRET_BEAM_ANCHOR_PX, \
			SECRET_BEAM_LENGTH_PX, SECRET_BEAM_HALF_WIDTH_PX, 1.15, Color(1.0, 0.52, 0.26, 1.0))
	else:
		_spawn_secret_directional_zone("cone", dir, SECRET_CONE_TELEGRAPH, SECRET_CONE_ANCHOR_PX, \
			SECRET_CONE_LENGTH_PX, SECRET_CONE_HALF_ANGLE, 1.0, Color(0.86, 0.36, 1.0, 1.0))


# SCRUM-791: спавн направленной зоны = telegraph-PNG (повёрнут под `dir`) + отложенный
# урон через directional_hit с ТОЙ ЖЕ `dir`. Для cone `half_extent` — угол (рад, scale
# не трогает); для beam — полуширина в пикселях арта, масштабируется тем же scale_factor,
# что и текстура → геометрия урона всегда внутри видимого телеграфа (fairness-гейт).
func _spawn_secret_directional_zone(kind: String, dir: Vector2, texture: Texture2D, anchor_px: Vector2, \
		length_px: float, half_extent: float, scale_factor: float, color: Color) -> void:
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	var rift_skill := _boss_rift_zone_skill_state()
	if rift_skill != "":
		_play_boss_skill_visual(rift_skill, "cast", dir)
	var marker := Node2D.new()
	marker.name = "SecretBossDirectional"
	marker.add_to_group("enemy_hazards")
	marker.set_meta("boss_behavior", boss_behavior)
	marker.global_position = global_position
	marker.z_index = 10
	parent.add_child(marker)
	var angle := dir.angle()
	var windup := _ascension_telegraph(0.82)
	var length_world := length_px * scale_factor
	var half_extent_world := (half_extent * scale_factor) if kind == "beam" else half_extent
	HazardVfx.directional_telegraph(marker, texture, anchor_px, scale_factor, angle, color, windup)
	var marker_ref: WeakRef = weakref(marker)
	var tween := marker.create_tween()
	tween.tween_interval(windup)
	tween.tween_callback(func() -> void:
		var m: Node2D = marker_ref.get_ref()
		if m == null:
			return
		var holder := m.get_node_or_null("HazardDirTelegraph") as Node2D
		if holder != null:
			HazardVfx.directional_detonate(holder, color)
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null and player.has_method("take_damage") \
				and directional_hit(kind, m.global_position, dir, length_world, half_extent_world, player.global_position):
			player.take_damage(projectile_damage * (0.80 + float(boss_phase - 1) * 0.16), "secret_" + kind)
	)
	tween.tween_interval(0.5)
	tween.tween_callback(marker.queue_free)


func _spawn_gravity_well(target_position: Vector2) -> void:
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	_play_boss_skill_visual("skill_gravity_well", "cast", target_position - global_position)
	var well := Node2D.new()
	well.name = "BossGravityWell"
	well.add_to_group("enemy_hazards")
	well.set_meta("boss_behavior", boss_behavior)
	well.global_position = _clamp_to_arena(target_position, 120.0)
	well.z_index = 10
	parent.add_child(well)
	var radius := _safe_radius(150.0 + float(boss_phase - 1) * 16.0)
	var well_color := Color(0.42, 0.24, 1.0, 1.0)
	var windup := _ascension_telegraph(0.72)
	HazardVfx.telegraph(well, radius, well_color, windup)
	var well_ref: WeakRef = weakref(well)
	var tween := well.create_tween()
	tween.tween_interval(windup)
	tween.tween_callback(func() -> void:
		var w: Node2D = well_ref.get_ref()
		if w == null:
			return
		HazardVfx.detonate(w, radius, well_color)
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player == null:
			return
		var to_center: Vector2 = w.global_position - player.global_position
		if to_center.length() > radius:
			return
		if to_center.length_squared() > 0.001:
			player.global_position = _clamp_to_arena(player.global_position + to_center.normalized() * minf(92.0, to_center.length() * 0.45))
		if player.has_method("take_damage"):
			player.take_damage(projectile_damage * (0.65 + float(boss_phase - 1) * 0.12), "gravity_well")
	)
	tween.tween_interval(0.55)
	tween.tween_callback(well.queue_free)


func _spawn_vampiric_bite(player: Node2D) -> void:
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	_play_boss_skill_visual("skill_vampiric_bite", "attack", player.global_position - global_position)
	var bite := Node2D.new()
	bite.name = "BossVampiricBite"
	bite.add_to_group("enemy_hazards")
	bite.set_meta("boss_behavior", boss_behavior)
	bite.global_position = _clamp_to_arena(global_position, 110.0)
	bite.z_index = 10
	parent.add_child(bite)
	var radius := _safe_radius(132.0 + float(boss_phase - 1) * 12.0)
	var bite_color := Color(0.92, 0.12, 0.20, 1.0)
	var windup := _ascension_telegraph(0.42)
	HazardVfx.telegraph(bite, radius, bite_color, windup)
	var bite_ref: WeakRef = weakref(bite)
	var tween := bite.create_tween()
	tween.tween_interval(windup)
	tween.tween_callback(func() -> void:
		var b: Node2D = bite_ref.get_ref()
		if b == null:
			return
		HazardVfx.detonate(b, radius, bite_color)
		var current_player := get_tree().get_first_node_in_group("player") as Node2D
		if current_player == null or current_player.global_position.distance_to(b.global_position) > radius:
			return
		var bite_damage: float = contact_damage * (1.05 + float(boss_phase - 1) * 0.14)
		if current_player.has_method("take_damage") and current_player.take_damage(bite_damage, "devourer_vampiric_bite"):
			health = minf(max_health, health + bite_damage * 0.55)
			_update_health_bar()
	)
	tween.tween_interval(0.4)
	tween.tween_callback(bite.queue_free)


func _spawn_bone_prison(center: Vector2) -> void:
	_play_boss_skill_visual("skill_bone_prison", "cast", center - global_position)
	var count := 7
	var gap_index := randi() % count
	var ring_radius := 230.0
	for index in range(count):
		if index == gap_index:
			continue
		var angle := TAU * float(index) / float(count)
		var zone_position := _clamp_to_arena(center + Vector2.RIGHT.rotated(angle) * ring_radius, 92.0)
		_spawn_rift_zone(zone_position, false)


func _spawn_molten_armor_pulse() -> void:
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	_play_boss_skill_visual("skill_armor_pulse", "cast", Vector2.UP)
	var pulse := Node2D.new()
	pulse.name = "BossMoltenArmorPulse"
	pulse.add_to_group("enemy_hazards")
	pulse.set_meta("boss_behavior", boss_behavior)
	pulse.global_position = global_position
	pulse.z_index = 10
	parent.add_child(pulse)
	var radius := _safe_radius(170.0 + float(boss_phase - 1) * 14.0)
	var pulse_color := Color(1.0, 0.48, 0.14, 1.0)
	var windup := _ascension_telegraph(0.55)
	HazardVfx.telegraph(pulse, radius, pulse_color, windup)
	var pulse_ref: WeakRef = weakref(pulse)
	var tween := pulse.create_tween()
	tween.tween_interval(windup)
	tween.tween_callback(func() -> void:
		var p: Node2D = pulse_ref.get_ref()
		if p == null:
			return
		HazardVfx.detonate(p, radius, pulse_color)
		var current_player := get_tree().get_first_node_in_group("player") as Node2D
		if current_player != null and current_player.global_position.distance_to(p.global_position) <= radius and current_player.has_method("take_damage"):
			current_player.take_damage(contact_damage * 0.75, "molten_armor")
	)
	tween.tween_interval(0.55)
	tween.tween_callback(pulse.queue_free)


func _start_dash_toward(player: Node2D) -> void:
	var direction := player.global_position - global_position
	if direction.length_squared() > 0.0:
		_dash_direction = direction.normalized()
		_dash_time_left = dash_duration
		_play_rig_action("attack", _dash_direction)


func _update_shield(delta: float) -> void:
	if _shield_time_left > 0.0:
		_shield_time_left -= delta
		if _shield_time_left <= 0.0:
			shield_active = false
			_shield_cooldown = shield_interval
			_update_shield_visual()
		return

	_shield_cooldown -= delta
	if _shield_cooldown <= 0.0:
		shield_active = true
		_shield_time_left = shield_duration
		_update_shield_visual()
		HazardVfx.shield_block(self, Color(0.62, 0.85, 1.0, 1.0))
		_play_rig_action("cast", Vector2.UP)


func _update_shield_visual() -> void:
	if shield_active:
		_set_body_tint(Color(0.62, 0.85, 1.0, 1.0))
	else:
		_set_body_tint(Color.WHITE)


func _flash_dodge() -> void:
	_set_body_tint(Color(1.0, 1.0, 1.0, 0.45))
	var tween := create_tween()
	tween.tween_interval(0.09)
	tween.tween_callback(_update_shield_visual)


func _fire_radial_burst() -> void:
	if projectile_scene == null:
		return

	_play_rig_action("cast", Vector2.UP)
	var projectile_count := burst_projectile_count + (boss_phase - 1) * 4
	for index in range(projectile_count):
		var angle := TAU * float(index) / float(projectile_count)
		var target_position := global_position + Vector2.RIGHT.rotated(angle) * 100.0
		var projectile := projectile_scene.instantiate()
		var projectile_parent := get_tree().current_scene
		if projectile_parent == null:
			projectile_parent = get_tree().root

		projectile_parent.add_child(projectile)
		if projectile.has_method("setup"):
			projectile.setup(global_position, target_position, projectile_damage, projectile_speed)


func _fire_targeted_volley(player: Node2D) -> void:
	if projectile_scene == null:
		return
	var direction := (player.global_position - global_position).normalized()
	if direction.length_squared() <= 0.0:
		direction = Vector2.DOWN
	if boss_behavior == "bone_archon":
		_play_boss_skill_visual("skill_skull_volley", "shoot", direction)
	else:
		_play_rig_action("shoot", direction)
	var projectile_parent := get_tree().current_scene
	if projectile_parent == null:
		projectile_parent = get_tree().root
	var volley_count: int = maxi(5, burst_projectile_count + (boss_phase - 1) * 2)
	var spread := deg_to_rad(54.0 + float(boss_phase - 1) * 14.0)
	for index in range(volley_count):
		var t := 0.0 if volley_count == 1 else float(index) / float(volley_count - 1)
		var angle := lerpf(-spread * 0.5, spread * 0.5, t)
		var shot_direction := direction.rotated(angle)
		var projectile := projectile_scene.instantiate()
		projectile_parent.add_child(projectile)
		if projectile.has_method("setup"):
			projectile.setup(global_position, global_position + shot_direction * 160.0, projectile_damage, projectile_speed)


func _spawn_rift_zone(target_position: Vector2, play_visual := true) -> void:
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	if play_visual:
		var rift_skill := _boss_rift_zone_skill_state()
		if rift_skill != "":
			_play_boss_skill_visual(rift_skill, "cast", target_position - global_position)
		else:
			_play_rig_action("cast", target_position - global_position)
	var zone_damage := projectile_damage * (1.25 + float(boss_phase - 1) * 0.18)
	var zone := Node2D.new()
	zone.name = "BossRiftZone"
	zone.add_to_group("enemy_hazards")
	zone.set_meta("boss_behavior", boss_behavior)
	zone.global_position = _clamp_to_arena(target_position, 92.0)
	zone.z_index = 9
	parent.add_child(zone)
	var radius := _safe_radius(92.0 + float(boss_phase - 1) * 16.0)
	var zone_color := Color(0.64, 0.34, 1.0, 1.0)
	var zone_telegraph := _ascension_telegraph(0.65)
	# SCRUM-790: доставленный radial rupture-PNG для наземной круговой зоны секретного
	# босса (geometry-match). _spawn_rift_zone — общая для боссов, поэтому гейтим по
	# boss_behavior: остальные боссы получают null = прежний процедурный круг (без регресса).
	var rupture_tex: Texture2D = SECRET_RUPTURE_TELEGRAPH if boss_behavior == "secret_ascension_boss" else null
	HazardVfx.telegraph(zone, radius, zone_color, zone_telegraph, rupture_tex)
	var zone_ref: WeakRef = weakref(zone)
	var zone_tween := zone.create_tween()
	zone_tween.tween_interval(zone_telegraph)
	zone_tween.tween_callback(func() -> void:
		var z: Node2D = zone_ref.get_ref()
		if z == null:
			return
		HazardVfx.detonate(z, radius, zone_color)
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null and player.global_position.distance_to(z.global_position) <= radius and player.has_method("take_damage"):
			player.take_damage(zone_damage, "rift_zone")
	)
	zone_tween.tween_interval(1.45)
	zone_tween.tween_callback(zone.queue_free)


func _spawn_disk_slam() -> void:
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	if boss_behavior == "ashen_colossus" or boss_behavior == "secret_ascension_boss":
		_play_boss_skill_visual("skill_molten_slam", "attack", Vector2.DOWN)
	else:
		_play_rig_action("attack", Vector2.DOWN)
	var slam_damage := contact_damage * (1.5 + float(boss_phase - 1) * 0.22)
	var slam := Node2D.new()
	slam.name = "DiskSlamZone"
	slam.add_to_group("enemy_hazards")
	slam.set_meta("boss_behavior", boss_behavior)
	slam.global_position = _clamp_to_arena(global_position, 132.0)
	slam.z_index = 9
	parent.add_child(slam)
	_shake_player_camera(10.0, 0.2)
	# Энрейдж Колосса: волны шире (cap безопасного коридора сохраняется).
	var radius := _safe_radius((132.0 + float(boss_phase - 1) * 18.0) * (1.18 if _enraged else 1.0))
	var slam_color := Color(1.0, 0.42, 0.18, 1.0)
	var slam_telegraph := _ascension_telegraph(0.48)
	HazardVfx.telegraph(slam, radius, slam_color, slam_telegraph)
	var slam_ref: WeakRef = weakref(slam)
	var slam_tween := slam.create_tween()
	slam_tween.tween_interval(slam_telegraph)
	slam_tween.tween_callback(func() -> void:
		var s: Node2D = slam_ref.get_ref()
		if s == null:
			return
		HazardVfx.detonate(s, radius, slam_color)
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null and player.global_position.distance_to(s.global_position) <= radius and player.has_method("take_damage"):
			player.take_damage(slam_damage, "disk_slam")
		# Пепельный Колосс: после удара остаётся тлеющая зона (наказывает стояние).
		if boss_behavior == "ashen_colossus" or boss_behavior == "secret_ascension_boss":
			_spawn_ember_zone(s.global_position, radius * 0.62)
	)
	slam_tween.tween_interval(0.62)
	slam_tween.tween_callback(slam.queue_free)


func _spawn_web_zone(target_position: Vector2) -> void:
	# Матерь Роя: паутинная зона — телеграф, затем липкое поле: замедляет
	# и слегка жалит, если герой остался внутри.
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	_play_boss_skill_visual("skill_web_zone", "cast", target_position - global_position)
	var zone := Node2D.new()
	zone.name = "BroodWebZone"
	zone.add_to_group("enemy_hazards")
	zone.set_meta("boss_behavior", boss_behavior)
	zone.global_position = _clamp_to_arena(target_position, 92.0)
	zone.z_index = 9
	parent.add_child(zone)
	var radius := _safe_radius(108.0 + float(boss_phase - 1) * 14.0)
	var web_color := Color(0.84, 0.92, 0.78, 1.0)
	var windup := _ascension_telegraph(0.6)
	HazardVfx.telegraph(zone, radius, web_color, windup)
	var web_damage := projectile_damage * 0.4
	var zone_ref: WeakRef = weakref(zone)
	var tween := zone.create_tween()
	tween.tween_interval(windup)
	tween.tween_callback(func() -> void:
		var z: Node2D = zone_ref.get_ref()
		if z == null:
			return
		HazardVfx.detonate(z, radius, web_color)
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null and player.global_position.distance_to(z.global_position) <= radius:
			if player.has_method("apply_web_slow"):
				player.apply_web_slow(2.2, 0.55)
			if player.has_method("take_damage"):
				player.take_damage(web_damage, "brood_web")
	)
	tween.tween_interval(1.1)
	tween.tween_callback(zone.queue_free)


func _spawn_ember_zone(origin: Vector2, radius: float) -> void:
	# Тлеющий след Колосса: пара жгущих тиков по стоящим в зоне.
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	var zone := Node2D.new()
	zone.name = "AshEmberZone"
	zone.add_to_group("enemy_hazards")
	zone.set_meta("boss_behavior", boss_behavior)
	zone.global_position = origin
	zone.z_index = 8
	parent.add_child(zone)
	var ember_color := Color(1.0, 0.52, 0.22, 1.0)
	HazardVfx.telegraph(zone, radius, ember_color, 0.25)
	var ember_damage := contact_damage * 0.45
	var zone_ref: WeakRef = weakref(zone)
	var tween := zone.create_tween()
	for _tick in range(2):
		tween.tween_interval(0.8)
		tween.tween_callback(func() -> void:
			var z: Node2D = zone_ref.get_ref()
			if z == null:
				return
			var player := get_tree().get_first_node_in_group("player") as Node2D
			if player != null and player.global_position.distance_to(z.global_position) <= radius and player.has_method("take_damage"):
				player.take_damage(ember_damage, "ash_ember")
		)
	tween.tween_callback(zone.queue_free)


# Чистая функция (без SceneTree): сколько НОВЫХ призывов добавить, чтобы не
# превысить MAX_SUMMONED_RIFTLINGS. База = 3 + (фаза-1), но обрезается остатком
# свободных слотов и никогда не отрицательна (защищает /float(count) у вызывающего).
static func riftling_summon_count(phase: int, active_summons: int) -> int:
	var base := 3 + phase - 1
	var room := MAX_SUMMONED_RIFTLINGS - active_summons
	return maxi(mini(base, room), 0)


func _summon_riftlings() -> void:
	var scene := boss_summon_scene
	if scene == null:
		scene = summoned_enemy_scene
	if scene == null:
		return
	var active_summons := get_tree().get_nodes_in_group("summoned_enemies").size()
	# SCRUM-596: только дозаполняем до потолка (учитывая уже живых призывов), иначе
	# на поздних фазах при почти полном поле спавнилось >8 (3+phase-1 безусловно).
	var summon_count := riftling_summon_count(boss_phase, active_summons)
	if summon_count <= 0:
		return
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	if boss_behavior == "brood_mother":
		_play_boss_skill_visual("skill_brood_spawn", "cast", Vector2.UP)
	else:
		_play_rig_action("cast", Vector2.UP)
	for index in range(summon_count):
		var summon := scene.instantiate() as Node2D
		parent.add_child(summon)
		summon.add_to_group("summoned_enemies")
		summon.global_position = _clamp_to_arena(global_position + Vector2.RIGHT.rotated(TAU * float(index) / float(summon_count) + randf() * 0.35) * 84.0)
		HazardVfx.summon_portal(summon, 82.0, Color(0.58, 0.30, 1.0, 1.0))


func _play_boss_skill_visual(skill_state: String, fallback_action: String, direction := Vector2.ZERO) -> void:
	if skill_state != "" and _play_full_frame_state(skill_state, direction):
		return
	_play_rig_action(fallback_action, direction)


func _boss_rift_zone_skill_state() -> String:
	if boss_behavior == "rift_warden" or boss_behavior == "disk_devourer" or boss_behavior == "secret_ascension_boss":
		return "skill_rift_zone"
	return ""


func _phase_markers_for_behavior() -> Array:
	if boss_behavior == "secret_ascension_boss":
		return SECRET_BOSS_PHASE_MARKERS
	return BOSS_PHASE_MARKERS


func _phase_interval_multiplier(extra_multiplier := 1.0) -> float:
	return extra_multiplier * (1.0 - float(boss_phase - 1) * 0.14)


func _ascension_telegraph(base: float) -> float:
	return base * float(get_meta("ascension_telegraph_mult", 1.0))


# SCRUM-713: чистая (без self/SceneTree) функция порога фаз — вынесена из
# _update_boss_phase, чтобы контракт «секретный/обычный пороги + монотонность»
# покрывался фокус-тестом (boss_phase_progression_test). Возвращает фазу 1..4;
# maxi с current_phase делает монотонность явной (HP может скакнуть вверх от
# лечения — фаза при этом не откатывается).
static func phase_for_ratio(behavior: String, ratio: float, current_phase: int, has_extra_phase: bool) -> int:
	var next_phase := 1
	if behavior == "secret_ascension_boss":
		if has_extra_phase and ratio <= 0.15:
			next_phase = 4
		elif ratio <= 0.25:
			next_phase = 3
		elif ratio <= 0.50:
			next_phase = 2
	else:
		if has_extra_phase and ratio <= 0.15:
			next_phase = 4
		elif ratio <= 0.33:
			next_phase = 3
		elif ratio <= 0.66:
			next_phase = 2
	return maxi(next_phase, current_phase)


func _update_boss_phase() -> void:
	if max_health <= 0.0:
		return
	var ratio := health / max_health
	var has_extra_phase := bool(get_meta("ascension_extra_phase", false))
	var next_phase := phase_for_ratio(boss_behavior, ratio, boss_phase, has_extra_phase)
	if next_phase <= boss_phase:
		return

	boss_phase = next_phase
	set_meta("boss_phase", boss_phase)
	_burst_cooldown = minf(_burst_cooldown, 0.45)
	_dash_cooldown = minf(_dash_cooldown, 0.65)
	_slam_cooldown = minf(_slam_cooldown, 0.55)
	_rift_zone_cooldown = minf(_rift_zone_cooldown, 0.60)
	_boss_summon_cooldown = minf(_boss_summon_cooldown, 0.85)
	_shield_cooldown = minf(_shield_cooldown, 1.10)
	if boss_phase == 2:
		move_speed *= 1.08
		dash_speed *= 1.08
		_set_body_tint(Color(1.0, 0.82, 0.48, 1.0))
		if boss_behavior == "secret_ascension_boss":
			_spawn_secret_sector_ring(global_position)
			_summon_riftlings()
	elif boss_phase == 3:
		move_speed *= 1.10
		dash_speed *= 1.12
		shield_duration *= 1.12
		_set_body_tint(Color(1.0, 0.45, 0.36, 1.0))
	else:
		# Фаза 4 (только на возвышении 9+): гнев стража.
		move_speed *= 1.14
		dash_speed *= 1.16
		shield_duration *= 1.18
		burst_projectile_count += 4
		_set_body_tint(Color(1.0, 0.20, 0.20, 1.0))
	_spawn_phase_transition_hazard()


func _spawn_phase_transition_hazard() -> void:
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	var zone := Node2D.new()
	zone.name = "BossPhaseHazard"
	zone.add_to_group("enemy_hazards")
	zone.global_position = _clamp_to_arena(global_position, 180.0)
	zone.z_index = 10
	parent.add_child(zone)

	var radius := _safe_radius(178.0 + float(boss_phase - 2) * 46.0)
	var phase_color := Color(1.0, 0.32, 0.18, 1.0)
	var windup := _ascension_telegraph(0.55)
	HazardVfx.telegraph(zone, radius, phase_color, windup)

	var zone_ref: WeakRef = weakref(zone)
	var tween := zone.create_tween()
	tween.tween_interval(windup)
	tween.tween_callback(func() -> void:
		var z: Node2D = zone_ref.get_ref()
		if z == null:
			return
		HazardVfx.detonate(z, radius, phase_color)
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null and player.global_position.distance_to(z.global_position) <= radius and player.has_method("take_damage"):
			player.take_damage(projectile_damage * (1.35 + float(boss_phase - 1) * 0.25), "boss_phase")
	)
	tween.tween_interval(0.70)
	tween.tween_callback(zone.queue_free)


func _update_enrage() -> void:
	if _enraged or max_health <= 0.0:
		return
	if health / max_health > enrage_health_ratio:
		return
	_enraged = true
	move_speed *= 1.12
	dash_speed *= 1.12
	burst_interval *= 0.82
	_set_body_tint(Color(1.0, 0.62, 0.46, 1.0))
