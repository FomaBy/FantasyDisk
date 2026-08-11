extends SceneTree

# FAN-2320: canonical pauses must freeze every combat-world family even though
# Main itself stays PROCESS_MODE_ALWAYS for menu, input and feedback controls.

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const BOSS_SCENE := preload("res://scenes/BossWarden.tscn")
const PROJECTILE_SCENE := preload("res://scenes/Projectile.tscn")
const ENEMY_PROJECTILE_SCENE := preload("res://scenes/EnemyProjectile.tscn")
const ClassWeaponScript := preload("res://scripts/class_weapon.gd")

const COMBAT_WORLD_GROUPS := [
	&"player", &"enemies", &"bosses", &"summoned_enemies", &"projectiles",
	&"enemy_projectiles", &"enemy_hazards", &"chemist_clouds", &"allies",
	&"pickups", &"player_weapons", &"player_weapon_effects", &"engineer_devices",
	&"deployed_sound_amps",
]


class PauseProbe:
	extends Node2D

	var process_ticks := 0
	var physics_ticks := 0
	var timer_ticks := 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		var timer := Timer.new()
		timer.name = "GameplayTimer"
		timer.process_mode = Node.PROCESS_MODE_ALWAYS
		timer.wait_time = 0.02
		timer.timeout.connect(_on_timer_timeout)
		add_child(timer)
		timer.start()
		var tween := create_tween()
		tween.tween_property(self, "rotation", 1.0, 1.0)

	func _process(delta: float) -> void:
		process_ticks += 1
		global_position.x += delta * 45.0

	func _physics_process(_delta: float) -> void:
		physics_ticks += 1

	func _on_timer_timeout() -> void:
		timer_ticks += 1


class ControlPlaneProbe:
	extends Control

	var process_ticks := 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(_delta: float) -> void:
		process_ticks += 1


func _initialize() -> void:
	var errors: Array[String] = []
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame

	var fixture := await _build_fixture(main, errors)
	if errors.is_empty():
		await _exercise_pause_contract(main, fixture, errors)

	main.call("_clear_all_game_pauses")
	main.queue_free()
	await process_frame

	if not errors.is_empty():
		for error in errors:
			push_error("Combat-world pause: %s" % error)
		quit(1)
		return
	print("Combat-world pause test passed.")
	quit(0)


func _build_fixture(main: Node, errors: Array[String]) -> Dictionary:
	var player := PLAYER_SCENE.instantiate() as Node2D
	var enemy := ENEMY_SCENE.instantiate() as Node2D
	var boss := BOSS_SCENE.instantiate() as Node2D
	var player_projectile := PROJECTILE_SCENE.instantiate() as Node2D
	var enemy_projectile := ENEMY_PROJECTILE_SCENE.instantiate() as Node2D
	var weapon := ClassWeaponScript.new()
	var control := ControlPlaneProbe.new()

	if player == null or enemy == null or boss == null or player_projectile == null or enemy_projectile == null:
		errors.append("Required player, enemy, boss or projectile fixture scene did not instantiate.")
		return {}

	main.add_child(player)
	main.add_child(enemy)
	main.add_child(boss)
	main.add_child(player_projectile)
	main.add_child(enemy_projectile)
	main.add_child(weapon)
	main.add_child(control)
	player.global_position = Vector2(220.0, 220.0)
	enemy.global_position = Vector2(720.0, 220.0)
	boss.global_position = Vector2(1180.0, 520.0)
	player_projectile.call("setup", Vector2(360.0, 340.0), Vector2(640.0, 340.0), 1.0)
	enemy_projectile.call("setup", Vector2(980.0, 340.0), Vector2(1240.0, 340.0), 1.0, 180.0)
	await process_frame

	weapon.pool_duration = 1.0
	weapon.pool_tick_interval = 0.2
	weapon.aoe_radius = 72.0
	weapon.call("_spawn_damage_pool", Vector2(540.0, 560.0), 3.0)
	weapon.call("_spawn_engineer_pressure_mine", player, Vector2(940.0, 700.0), 0)
	enemy.call("_spawn_elite_hazard", Vector2(820.0, 600.0))
	boss.call("_spawn_rift_zone", Vector2(1120.0, 660.0), false)

	var probes: Array[PauseProbe] = []
	for spec in [
		["ChemistPoolProbe", &"chemist_clouds"],
		["EliteTelegraphProbe", &"enemy_hazards"],
		["BossHazardProbe", &"enemy_hazards"],
		["PersistentWeaponEffectProbe", &"player_weapon_effects"],
	]:
		var probe := PauseProbe.new()
		probe.name = str(spec[0])
		probe.add_to_group(spec[1] as StringName)
		main.add_child(probe)
		probes.append(probe)
	await _wait_while_paused(0.08)

	return {
		"player": player,
		"enemy": enemy,
		"boss": boss,
		"player_projectile": player_projectile,
		"enemy_projectile": enemy_projectile,
		"control": control,
		"probes": probes,
	}


func _exercise_pause_contract(main: Node, fixture: Dictionary, errors: Array[String]) -> void:
	var player := fixture["player"] as Node2D
	var enemy := fixture["enemy"] as Node2D
	var boss := fixture["boss"] as Node2D
	var player_projectile := fixture["player_projectile"] as Node2D
	var enemy_projectile := fixture["enemy_projectile"] as Node2D
	var control := fixture["control"] as ControlPlaneProbe
	var probes: Array = fixture["probes"]
	if player == null or enemy == null or boss == null or player_projectile == null or enemy_projectile == null or control == null:
		errors.append("Pause fixture lost a required node before the contract ran.")
		return

	var tracked := [player, enemy, boss, player_projectile, enemy_projectile]
	tracked.append_array(probes)
	var before_pause := _snapshots(tracked)
	var group_counts := _group_counts()
	var node_count := get_node_count()
	var control_before := control.process_ticks

	main.call("push_pause", "escape_menu")
	main.call("push_pause", "level_up")
	main.call("push_pause", "feedback")
	if not bool(paused):
		errors.append("Stacked canonical pause reasons did not pause the SceneTree.")
		return
	await _wait_while_paused(0.18)
	_assert_unchanged(before_pause, tracked, "initial paused window", errors)
	_assert_group_counts(group_counts, "initial paused window", errors)
	if get_node_count() != node_count:
		errors.append("Gameplay node count changed during the initial paused window.")
	if control.process_ticks <= control_before:
		errors.append("Control-plane node did not continue processing while gameplay was paused.")
	_assert_fail_closed_groups(errors)

	var incoming := PauseProbe.new()
	incoming.name = "NewGameplayIngressProbe"
	incoming.add_to_group("enemy_hazards")
	main.add_child(incoming)
	var incoming_before := _snapshots([incoming])
	if incoming.process_mode != Node.PROCESS_MODE_PAUSABLE:
		errors.append("A gameplay node added during pause inherited PROCESS_MODE_ALWAYS.")
	await _wait_while_paused(0.12)
	_assert_unchanged(incoming_before, [incoming], "new gameplay ingress", errors)
	_assert_fail_closed_groups(errors)

	main.call("pop_pause", "escape_menu")
	main.call("pop_pause", "level_up")
	if not bool(paused):
		errors.append("Removing only part of a stacked pause unpaused the world.")
		return
	await _wait_while_paused(0.12)
	_assert_unchanged(before_pause, tracked, "remaining feedback pause", errors)

	main.call("pop_pause", "feedback")
	if bool(paused):
		errors.append("World remained paused after the last canonical reason was removed.")
		return
	await create_timer(0.12).timeout
	var resumed := _snapshots(tracked)
	var resumed_progressed := false
	for node in tracked:
		var id: int = node.get_instance_id()
		if int(resumed[id]["process_ticks"]) > int(before_pause[id]["process_ticks"]):
			resumed_progressed = true
			break
	if not resumed_progressed:
		errors.append("Combat-world fixture did not resume from its preserved paused state.")


func _snapshots(nodes: Array) -> Dictionary:
	var snapshots := {}
	for raw in nodes:
		var node := raw as Node
		if node == null or not is_instance_valid(node):
			continue
		var position: Vector2 = node.global_position if node is Node2D else Vector2.ZERO
		var probe := node as PauseProbe
		var timer_ticks := probe.timer_ticks if probe != null else -1
		var process_ticks := probe.process_ticks if probe != null else 0
		var physics_ticks := probe.physics_ticks if probe != null else 0
		snapshots[node.get_instance_id()] = {
			"position": position,
			"rotation": node.rotation if node is Node2D else 0.0,
			"process_ticks": process_ticks,
			"physics_ticks": physics_ticks,
			"timer_ticks": timer_ticks,
		}
	return snapshots


func _assert_unchanged(before: Dictionary, nodes: Array, context: String, errors: Array[String]) -> void:
	for raw in nodes:
		var node := raw as Node
		if node == null or not is_instance_valid(node) or not before.has(node.get_instance_id()):
			errors.append("%s: tracked gameplay node was removed." % context)
			continue
		var expected: Dictionary = before[node.get_instance_id()]
		var position: Vector2 = node.global_position if node is Node2D else Vector2.ZERO
		if position.distance_to(expected["position"] as Vector2) > 0.001:
			errors.append("%s: %s changed transform while paused." % [context, node.name])
		if node is Node2D and not is_equal_approx(node.rotation, float(expected["rotation"])):
			errors.append("%s: %s tween/animation progress changed while paused." % [context, node.name])
		var probe := node as PauseProbe
		if probe != null and (probe.process_ticks != int(expected["process_ticks"]) or probe.physics_ticks != int(expected["physics_ticks"]) or probe.timer_ticks != int(expected["timer_ticks"])):
			errors.append("%s: %s advanced a gameplay process, physics timer or lifetime." % [context, node.name])


func _group_counts() -> Dictionary:
	var counts := {}
	for group_name in COMBAT_WORLD_GROUPS:
		counts[group_name] = get_nodes_in_group(group_name).size()
	return counts


func _assert_group_counts(expected: Dictionary, context: String, errors: Array[String]) -> void:
	for group_name in COMBAT_WORLD_GROUPS:
		if int(expected[group_name]) != get_nodes_in_group(group_name).size():
			errors.append("%s: group %s changed node count while paused." % [context, group_name])


func _assert_fail_closed_groups(errors: Array[String]) -> void:
	for group_name in COMBAT_WORLD_GROUPS:
		for node in get_nodes_in_group(group_name):
			_assert_node_tree_pausable(node, str(group_name), errors)


func _assert_node_tree_pausable(node: Node, group_name: String, errors: Array[String]) -> void:
	if node.process_mode != Node.PROCESS_MODE_PAUSABLE:
		errors.append("Fail-closed oracle: %s in %s can process while paused." % [node.name, group_name])
	for child in node.get_children():
		_assert_node_tree_pausable(child, group_name, errors)


func _wait_while_paused(seconds: float) -> void:
	await create_timer(seconds, true).timeout
