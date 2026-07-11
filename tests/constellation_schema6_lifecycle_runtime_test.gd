extends SceneTree

const Meta := preload("res://scripts/meta_progression.gd")
const PlayerScript := preload("res://scripts/player.gd")
const ClassWeaponScript := preload("res://scripts/class_weapon.gd")
const ProgressionData := preload("res://scripts/progression_data.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")


class RecordingEnemy extends Node2D:
	var health := 10000.0
	var max_health := 10000.0
	var damage_log: Array[float] = []

	func take_damage(amount: float, _feedback := {}) -> void:
		var dealt := maxf(amount, 0.0)
		damage_log.append(dealt)
		health = maxf(health - dealt, 0.0)

	func apply_knockback(_value: Vector2) -> void:
		pass


var errors := PackedStringArray()


func _initialize() -> void:
	await process_frame
	_test_skull_authoritative_death_transfer()
	await _test_reliquary_expiry_death_and_heal_cap()
	await _test_plague_threshold_depth_duration_and_reset()
	_test_wire_timeout_reset()
	_test_saw_timeout_reset_and_capped_heal()
	await process_frame
	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("SCRUM-1068 lifecycle runtime passed skull/reliquary death, plague spread, and wire/saw reset gates.")
	quit(0)


func _test_skull_authoritative_death_transfer() -> void:
	var player := _player_with_final("dark_mage", "cursed_skull")
	var weapon: Variant = _class_weapon(player, "dark_mage", "cursed_skull")
	weapon.aoe_radius = 100.0
	weapon.dot_ticks = 4
	weapon.curse_tick_rate = 1.0
	var host := _enemy(Vector2.ZERO)
	var candidates: Array[RecordingEnemy] = []
	for position in [Vector2(112.0, 0.0), Vector2(-116.0, 0.0), Vector2(0.0, 120.0), Vector2(0.0, -126.0)]:
		candidates.append(_enemy(position))

	weapon._apply_skull_curse_zone(Vector2.ZERO)
	var mark_key: String = weapon._constellation_mark_key("skull_curse")
	var host_mark_raw = host.get_meta(mark_key, {})
	_check(host_mark_raw is Dictionary and int((host_mark_raw as Dictionary).get("depth", -1)) == 0, "skull cast did not arm a depth-0 host curse")
	var original_status: Dictionary = (host_mark_raw as Dictionary).get("status", {}) if host_mark_raw is Dictionary else {}
	var original_duration := float(original_status.get("duration", 0.0))
	_check(host.damage_log.is_empty(), "skull curse dealt forbidden direct damage before death")

	host.set_meta("killing_hit_feedback", {"damage_type": "dot", "player_owned": true, "curse": true})
	player.on_enemy_killed(host)
	var transferred: Array[RecordingEnemy] = []
	for candidate in candidates:
		if candidate.has_meta(mark_key):
			transferred.append(candidate)
	_check(transferred.size() == 3, "skull death transfer did not select exactly three unique nearby targets")
	_check(not host.has_meta(mark_key), "skull death transfer did not consume its host latch")
	for target in transferred:
		var transfer_mark: Dictionary = target.get_meta(mark_key, {})
		var transfer_status: Dictionary = transfer_mark.get("status", {})
		_check(int(transfer_mark.get("depth", -1)) == 1, "skull transfer exceeded or lost the depth-1 contract")
		_check(_approx(float(transfer_status.get("duration", 0.0)), original_duration * 0.55, 0.01), "skull transfer duration is not 55% of the source curse")
		_check(target.damage_log.is_empty(), "skull transfer dealt forbidden direct damage")

	if not transferred.is_empty():
		var depth_one_host := transferred[0]
		var previously_unmarked: RecordingEnemy = null
		for candidate in candidates:
			if not candidate.has_meta(mark_key):
				previously_unmarked = candidate
				break
		player.on_enemy_killed(depth_one_host)
		_check(previously_unmarked == null or not previously_unmarked.has_meta(mark_key), "depth-1 skull curse transferred recursively")

	var cleanup: Array = []
	cleanup.append_array(candidates)
	cleanup.append(host)
	cleanup.append(player)
	_cleanup_nodes(cleanup)


func _test_reliquary_expiry_death_and_heal_cap() -> void:
	var player := _player_with_final("priest", "priest_reliquary")
	var weapon: Variant = _class_weapon(player, "priest", "priest_reliquary")
	weapon.aoe_radius = 90.0
	weapon.damage_falloff = 1.0
	weapon.grenade_delay = 0.08
	weapon.burst_interval = 0.06
	weapon.storm_ticks = 1
	weapon.sanctify_tick_ratio = 0.5
	player.health = player.max_health - 20.0
	var health_before: float = float(player.health)

	var expiry_target := _enemy(Vector2(260.0, 0.0), 50000.0, 50000.0)
	weapon._fire_priest_sanctify(player, expiry_target, Vector2.RIGHT)
	await create_timer(0.38).timeout
	var expiry_wave_count := _count_damage_near(expiry_target.damage_log, 20.0, 0.05)
	_check(expiry_wave_count == 1, "reliquary scheduled expiry did not emit exactly one 40% wave")
	_check(_approx(player.health - health_before, 1.6, 0.02), "reliquary scheduled wave did not respect the 1.6 HP/s heal cap")

	var death_target := _enemy(Vector2(-260.0, 0.0), 50000.0, 50000.0)
	weapon._fire_priest_sanctify(player, death_target, Vector2.LEFT)
	death_target.set_meta("killing_hit_feedback", {"damage_type": "physical", "player_owned": true})
	player.on_enemy_killed(death_target)
	var immediate_death_waves := _count_damage_near(death_target.damage_log, 20.0, 0.05)
	_check(immediate_death_waves == 1, "reliquary marked death did not emit exactly one immediate wave")
	var health_after_death_wave: float = float(player.health)
	await create_timer(0.38).timeout
	_check(_count_damage_near(death_target.damage_log, 20.0, 0.05) == 1, "reliquary scheduled expiry duplicated an already-consumed death wave")
	_check(_approx(player.health, health_after_death_wave, 0.001), "reliquary exceeded its shared one-second heal cap across expiry and death waves")
	_cleanup_nodes([expiry_target, death_target, player])


func _test_plague_threshold_depth_duration_and_reset() -> void:
	var player := _player_with_final("doctor", "plague_syringe")
	var weapon: Variant = _class_weapon(player, "doctor", "plague_syringe")
	weapon.plague_duration = 1.8
	weapon.plague_tick_interval = 0.45
	weapon.plague_ramp_ticks = 1
	weapon.plague_spread_chance = 0.0
	weapon.plague_spread_radius = 180.0
	weapon.plague_max_infected = 8
	var host := _enemy(Vector2.ZERO, 50000.0, 50000.0)
	var candidates: Array[RecordingEnemy] = []
	for position in [Vector2(80.0, 0.0), Vector2(-90.0, 0.0), Vector2(0.0, 100.0), Vector2(0.0, -115.0)]:
		candidates.append(_enemy(position, 50000.0, 50000.0))

	for hit_index in range(3):
		weapon._apply_plague_infection(host, player)
	_check(weapon._plague_active_count() == 1, "plague spread triggered before the fourth direct infection")
	weapon._apply_plague_infection(host, player)
	_check(weapon._plague_active_count() == 4, "fourth direct infection did not spread to three unique uninfected targets")
	var stack_key: String = weapon._constellation_mark_key("syringe_infection")
	var spread_targets: Array[RecordingEnemy] = []
	for candidate in candidates:
		if weapon._plague_tweens.has(candidate.get_instance_id()):
			spread_targets.append(candidate)
		_check(not candidate.has_meta(stack_key), "depth-1 plague spread recursively armed a threshold stack")
	_check(spread_targets.size() == 3, "plague spread did not preserve the three-target uniqueness cap")

	await create_timer(1.02).timeout
	for target in spread_targets:
		_check(target.damage_log.size() == 2, "plague depth-1 copy did not run for exactly half of the four-tick source duration")
	_check(host.damage_log.size() == 2, "plague source cadence diverged before the half-duration checkpoint")
	await create_timer(0.92).timeout
	_check(host.damage_log.size() == 4, "plague source infection did not complete its four live ticks")
	for target in spread_targets:
		_check(target.damage_log.size() == 2, "plague depth-1 copy outlived its half-duration cap")

	weapon._apply_plague_infection(host, player)
	var reset_state: Dictionary = host.get_meta(stack_key, {})
	_check(int(reset_state.get("count", 0)) == 1 and not bool(reset_state.get("spread", true)), "expired plague threshold did not reset to one fresh direct stack")
	var cleanup: Array = []
	cleanup.append_array(candidates)
	cleanup.append(host)
	cleanup.append(player)
	_cleanup_nodes(cleanup)


func _test_wire_timeout_reset() -> void:
	var player := _player_with_final("assassin", "venom_wire")
	var weapon: Variant = _class_weapon(player, "assassin", "venom_wire")
	weapon.dot_ticks = 1
	var enemy := _enemy(Vector2(80.0, 0.0), 50000.0, 50000.0)
	for hit_index in range(4):
		weapon._damage_enemy_with_dot(enemy, 100.0, player)
	var stack_key: String = weapon._constellation_mark_key("wire_poison")
	var expired_state: Dictionary = enemy.get_meta(stack_key, {})
	expired_state["until_msec"] = 0
	enemy.set_meta(stack_key, expired_state)
	enemy.damage_log.clear()
	weapon._damage_enemy_with_dot(enemy, 100.0, player)
	_check(enemy.damage_log.size() == 1, "wire snap fired from stale pre-timeout stacks")
	_check(int((enemy.get_meta(stack_key, {}) as Dictionary).get("count", 0)) == 1, "wire timeout did not reset its local ramp to one")
	for hit_index in range(4):
		weapon._damage_enemy_with_dot(enemy, 100.0, player)
	_check(enemy.damage_log.size() == 6, "wire fresh fifth stack did not emit exactly one snap plus five direct hits")
	_check(_count_damage_near(enemy.damage_log, 55.0, 0.05) == 1, "wire fresh cycle snap is not exactly 55% or triggered more than once")
	_cleanup_nodes([enemy, player])


func _test_saw_timeout_reset_and_capped_heal() -> void:
	var player := _player_with_final("doctor", "bone_saw")
	var weapon: Variant = _class_weapon(player, "doctor", "bone_saw")
	player.global_position = Vector2.ZERO
	weapon.heal_percent_of_damage = 0.0
	weapon.attack_range = 180.0
	weapon.cone_degrees = 120.0
	weapon.sector_full_targets = 1
	var enemy := _enemy(Vector2(70.0, 0.0), 20000.0, 100000.0)
	for hit_index in range(4):
		weapon._fire_saw_sector(player, Vector2.RIGHT)
	var stack_key: String = weapon._constellation_mark_key("saw_wound")
	var expired_state: Dictionary = enemy.get_meta(stack_key, {})
	expired_state["until_msec"] = 0
	enemy.set_meta(stack_key, expired_state)
	player.health = player.max_health - 20.0
	player.set("_drain_heal_budget", 20.0)
	var before_reset_hit: float = float(player.health)
	weapon._fire_saw_sector(player, Vector2.RIGHT)
	_check(_approx(player.health, before_reset_hit, 0.001), "saw execute-heal consumed stale pre-timeout wounds")
	_check(int((enemy.get_meta(stack_key, {}) as Dictionary).get("count", 0)) == 1, "saw wound timeout did not reset its local stack to one")
	for hit_index in range(4):
		weapon._fire_saw_sector(player, Vector2.RIGHT)
	_check(player.health > before_reset_hit, "saw fresh fifth wound did not grant weapon-only healing")
	_check(player.health - before_reset_hit <= 6.01, "saw execute-heal exceeded the configured 6% hit ratio/drain budget")
	_check(not enemy.has_meta(stack_key), "saw execute did not consume its wound stack")
	_cleanup_nodes([enemy, player])


func _player_with_final(class_id: String, weapon_id: String) -> CharacterBody2D:
	var player = PlayerScript.new()
	root.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.configure_character(class_id)
	var state := Meta.default_state()
	state["skill_nodes"] = ["%s_%s_final" % [class_id, weapon_id]]
	player.apply_constellation_weapon_profiles(Meta.skill_profiles_for_class(state, class_id))
	player.global_position = Vector2(6000.0, 6000.0)
	return player


func _class_weapon(player: CharacterBody2D, class_id: String, weapon_id: String) -> Variant:
	var weapon = ClassWeaponScript.new()
	weapon.configure_weapon(ProgressionData.weapon(class_id, weapon_id))
	player.add_child(weapon)
	player.equipped_weapon = weapon
	player.weapon_id = weapon_id
	weapon.set_process(false)
	weapon.damage_parameter = "damage"
	player.derived_parameters["damage"] = 100.0
	player.derived_parameters["magic_damage"] = 0.0
	player.derived_parameters["dot_damage"] = 1.0
	player.derived_parameters["dot_speed"] = 1.0
	player.derived_parameters["summon_amount"] = 0.0
	player.derived_parameters["crit_chance"] = 0.0
	return weapon


func _enemy(position: Vector2, health := 10000.0, maximum := 10000.0) -> RecordingEnemy:
	var enemy := RecordingEnemy.new()
	enemy.global_position = position
	enemy.health = health
	enemy.max_health = maximum
	root.add_child(enemy)
	enemy.add_to_group("enemies")
	return enemy


func _count_damage_near(log: Array[float], expected: float, epsilon: float) -> int:
	var count := 0
	for amount in log:
		if _approx(amount, expected, epsilon):
			count += 1
	return count


func _cleanup_nodes(nodes: Array) -> void:
	for node in nodes:
		if node != null and is_instance_valid(node):
			node.free()


func _approx(actual: float, expected: float, epsilon := 0.0005) -> bool:
	return absf(actual - expected) <= epsilon


func _check(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
