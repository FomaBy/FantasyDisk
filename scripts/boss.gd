extends "res://scripts/enemy.gd"

@export var boss_behavior := ""
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
@export var enrage_health_ratio := 0.35

var _burst_cooldown := 2.0
var _dash_cooldown := 3.0
var _dash_time_left := 0.0
var _dash_direction := Vector2.ZERO
var _shield_cooldown := 4.0
var _shield_time_left := 0.0
var _boss_summon_cooldown := 5.0
var _rift_zone_cooldown := 3.4
var _slam_cooldown := 4.2
var shield_active := false
var _enraged := false


func _ready() -> void:
	super()
	add_to_group("bosses")
	if boss_behavior == "":
		boss_behavior = "disk_devourer" if enemy_type_name == "Disk Devourer" else "rift_warden"
	set_meta("boss_behavior", boss_behavior)
	_update_shield_visual()


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
	_update_enrage()
	_update_boss_attacks(delta)


func take_damage(amount: float) -> void:
	var final_amount := amount
	if amount < max_health and randf() < dodge_chance:
		_flash_dodge()
		return
	if shield_active:
		final_amount *= shield_damage_reduction
	super(final_amount)


func _update_boss_attacks(delta: float) -> void:
	var player := _player()
	if player == null:
		return

	_burst_cooldown -= delta
	if boss_behavior == "disk_devourer":
		_dash_cooldown -= delta
		_slam_cooldown -= delta
		if _dash_cooldown <= 0.0:
			_start_dash_toward(player)
			_dash_cooldown = dash_interval * (0.78 if _enraged else 1.0)
		if _slam_cooldown <= 0.0:
			_spawn_disk_slam()
			_slam_cooldown = slam_interval * (0.82 if _enraged else 1.0)
		if _burst_cooldown <= 0.0:
			_fire_radial_burst()
			_burst_cooldown = burst_interval * (0.86 if _enraged else 1.0)
	else:
		_boss_summon_cooldown -= delta
		_rift_zone_cooldown -= delta
		if _burst_cooldown <= 0.0:
			_fire_targeted_volley(player)
			_burst_cooldown = burst_interval
		if _rift_zone_cooldown <= 0.0:
			_spawn_rift_zone(player.global_position)
			_rift_zone_cooldown = rift_zone_interval
		if _boss_summon_cooldown <= 0.0:
			_summon_riftlings()
			_boss_summon_cooldown = boss_summon_interval


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
	for index in range(burst_projectile_count):
		var angle := TAU * float(index) / float(burst_projectile_count)
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
	_play_rig_action("shoot", direction)
	var projectile_parent := get_tree().current_scene
	if projectile_parent == null:
		projectile_parent = get_tree().root
	var volley_count: int = maxi(5, burst_projectile_count)
	var spread := deg_to_rad(54.0)
	for index in range(volley_count):
		var t := 0.0 if volley_count == 1 else float(index) / float(volley_count - 1)
		var angle := lerpf(-spread * 0.5, spread * 0.5, t)
		var shot_direction := direction.rotated(angle)
		var projectile := projectile_scene.instantiate()
		projectile_parent.add_child(projectile)
		if projectile.has_method("setup"):
			projectile.setup(global_position, global_position + shot_direction * 160.0, projectile_damage, projectile_speed)


func _spawn_rift_zone(target_position: Vector2) -> void:
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	_play_rig_action("cast", target_position - global_position)
	var zone_damage := projectile_damage * 1.25
	var zone := Node2D.new()
	zone.name = "BossRiftZone"
	zone.add_to_group("enemy_hazards")
	zone.global_position = _clamp_to_arena(target_position, 92.0)
	zone.z_index = 9
	parent.add_child(zone)
	var visual := Polygon2D.new()
	visual.color = Color(0.45, 0.22, 1.0, 0.24)
	var points := PackedVector2Array()
	for point_index in range(32):
		points.append(Vector2.RIGHT.rotated(TAU * float(point_index) / 32.0) * 92.0)
	visual.polygon = points
	zone.add_child(visual)
	var zone_tween := zone.create_tween()
	zone_tween.tween_interval(0.65)
	zone_tween.tween_callback(func() -> void:
		visual.color = Color(0.62, 0.30, 1.0, 0.52)
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null and player.global_position.distance_to(zone.global_position) <= 92.0 and player.has_method("take_damage"):
			player.take_damage(zone_damage, "rift_zone")
	)
	zone_tween.tween_interval(1.45)
	zone_tween.tween_callback(zone.queue_free)


func _spawn_disk_slam() -> void:
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	_play_rig_action("attack", Vector2.DOWN)
	var slam_damage := contact_damage * 1.5
	var slam := Node2D.new()
	slam.name = "DiskSlamZone"
	slam.add_to_group("enemy_hazards")
	slam.global_position = _clamp_to_arena(global_position, 132.0)
	slam.z_index = 9
	parent.add_child(slam)
	var visual := Polygon2D.new()
	visual.color = Color(1.0, 0.36, 0.16, 0.24)
	var points := PackedVector2Array()
	for point_index in range(36):
		points.append(Vector2.RIGHT.rotated(TAU * float(point_index) / 36.0) * 132.0)
	visual.polygon = points
	slam.add_child(visual)
	var slam_tween := slam.create_tween()
	slam_tween.tween_interval(0.48)
	slam_tween.tween_callback(func() -> void:
		visual.color = Color(1.0, 0.28, 0.12, 0.55)
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null and player.global_position.distance_to(slam.global_position) <= 132.0 and player.has_method("take_damage"):
			player.take_damage(slam_damage, "disk_slam")
	)
	slam_tween.tween_interval(0.62)
	slam_tween.tween_callback(slam.queue_free)


func _summon_riftlings() -> void:
	var scene := boss_summon_scene
	if scene == null:
		scene = summoned_enemy_scene
	if scene == null:
		return
	var active_summons := get_tree().get_nodes_in_group("summoned_enemies").size()
	if active_summons >= 8:
		return
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	_play_rig_action("cast", Vector2.UP)
	for index in range(3):
		var summon := scene.instantiate() as Node2D
		parent.add_child(summon)
		summon.add_to_group("summoned_enemies")
		summon.global_position = _clamp_to_arena(global_position + Vector2.RIGHT.rotated(TAU * float(index) / 3.0 + randf() * 0.35) * 84.0)


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
