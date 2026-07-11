extends SceneTree

const Meta := preload("res://scripts/meta_progression.gd")
const PlayerScript := preload("res://scripts/player.gd")
const BerserkWeaponScript := preload("res://scripts/berserk_weapon.gd")
const HolyFlailScript := preload("res://scripts/holy_flail_weapon.gd")
const PressScript := preload("res://scripts/robot_hydraulic_press_weapon.gd")
const ClassWeaponScript := preload("res://scripts/class_weapon.gd")
const SentryScript := preload("res://scripts/sentry_turret.gd")
const DroneScript := preload("res://scripts/engineer_orbit_drone.gd")
const SummonerScript := preload("res://scripts/summoner_weapon.gd")
const AllyScript := preload("res://scripts/ally_minion.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")

class DummyEnemy extends Node2D:
	var health := 1000.0
	var max_health := 1000.0
	var knockback := Vector2.ZERO
	func take_damage(amount: float, _feedback := {}) -> void:
		health -= maxf(amount, 0.0)
	func apply_knockback(value: Vector2) -> void:
		knockback += value

var errors := PackedStringArray()


func _initialize() -> void:
	await process_frame
	_check_registries()
	_test_sword_execute_and_knight_bridges()
	await _test_axe_followthrough()
	await _test_hammer_and_flail()
	await _test_press_second_jaw()
	_test_sentry_overclock()
	_test_drone_repair_shield()
	await _test_homunculus_and_pack()
	await process_frame
	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("SCRUM-1068 special finals passed 11 scoped consumer mechanics, caps, events, and lifecycle guards.")
	quit(0)


func _check_registries() -> void:
	for mechanic_id in ["sword_repeat_execute", "axe_outer_followthrough", "hammer_stagger_aftershock", "spear_block_counter_line", "shield_stored_damage_bash"]:
		_check(BerserkWeaponScript.CONSTELLATION_FINAL_MECHANICS.has(mechanic_id), "Berserk registry missing %s" % mechanic_id)
	_check(HolyFlailScript.HOLY_FLAIL_CONSTELLATION_FINAL_MECHANICS.has("flail_return_control_pulse"), "Holy Flail registry missing return pulse")
	_check(PressScript.PRESS_CONSTELLATION_FINAL_MECHANICS.has("press_axis_second_jaw"), "Press registry missing second jaw")
	_check(SentryScript.CONSTELLATION_FINAL_MECHANICS.has("sentry_marked_target_overclock"), "Sentry registry missing overclock")
	_check(DroneScript.CONSTELLATION_FINAL_MECHANICS.has("drone_excess_repair_shield"), "Drone registry missing repair shield")
	_check(SummonerScript.CONSTELLATION_FINAL_MECHANICS.size() == 2, "Summoner registry must expose its two finals")
	_check(AllyScript.CONSTELLATION_FINAL_MECHANICS.has("homunculus_intercept_death_burst"), "Ally bridge registry missing homunculus final")


func _test_sword_execute_and_knight_bridges() -> void:
	var berserk := _player_with_final("berserk", "sword")
	berserk.derived_parameters["crit_chance"] = 0.0
	var sword = BerserkWeaponScript.new()
	sword.weapon_id = "sword"
	berserk.add_child(sword)
	sword.set_process(false)
	var enemy := _enemy(Vector2(90.0, 0.0), 330.0, 1000.0)
	var before := enemy.health
	sword._damage_target(berserk, enemy, Vector2.RIGHT)
	var first := before - enemy.health
	sword._damage_target(berserk, enemy, Vector2.RIGHT)
	before = enemy.health
	sword._damage_target(berserk, enemy, Vector2.RIGHT)
	var third := before - enemy.health
	_check(third > first * 1.20, "sword third consecutive low-HP hit did not execute")
	_check(int(sword.constellation_special_state().get("sword_repeat_hits", -1)) == 0, "sword execute did not consume repeat sequence")
	_cleanup_nodes([enemy, berserk])

	var knight_spear := _player_with_final("knight", "long_spear")
	var spear = BerserkWeaponScript.new()
	spear.weapon_id = "long_spear"
	knight_spear.add_child(spear)
	spear.set_process(false)
	var block_result: Dictionary = spear.constellation_on_block(40.0)
	_check(bool(block_result.get("triggered", false)), "spear block bridge did not arm counter")
	var spear_enemy := _enemy(Vector2(80.0, 0.0))
	var spear_before := spear_enemy.health
	spear._damage_target(knight_spear, spear_enemy, Vector2.RIGHT)
	_check(spear_before - spear_enemy.health > spear.damage * 1.50, "spear counter line did not add capped counter hit")
	_cleanup_nodes([spear_enemy, knight_spear])

	var knight_shield := _player_with_final("knight", "tower_shield")
	var shield = BerserkWeaponScript.new()
	shield.weapon_id = "tower_shield"
	knight_shield.add_child(shield)
	shield.set_process(false)
	var absorb_result: Dictionary = shield.constellation_on_damage_absorbed(200.0)
	_check(bool(absorb_result.get("triggered", false)), "shield damage-absorbed bridge did not trigger")
	_check(is_equal_approx(float(shield.constellation_special_state().get("stored_bash_damage", 0.0)), 30.0), "shield stored damage cap is not 30")
	var shield_enemy := _enemy(Vector2(80.0, 0.0))
	var shield_before := shield_enemy.health
	shield._damage_target(knight_shield, shield_enemy, Vector2.RIGHT)
	_check(shield_before - shield_enemy.health >= shield.damage + 29.9, "shield bash did not consume stored damage")
	_check(is_equal_approx(float(shield.constellation_special_state().get("stored_bash_damage", -1.0)), 0.0), "shield stored damage was not consumed")
	_cleanup_nodes([shield_enemy, knight_shield])


func _test_axe_followthrough() -> void:
	var player := _player_with_final("berserk", "axe")
	var axe = BerserkWeaponScript.new()
	axe.weapon_id = "axe"
	axe.attack_range = 260.0
	axe.sweep_degrees = 70.0
	root.add_child(axe)
	axe.set_process(false)
	var primary := _enemy(Vector2(105.0, 0.0))
	var outer := _enemy(Vector2(190.0, 150.0))
	await process_frame
	var outer_before := outer.health
	axe._damage_window(player, Vector2.RIGHT)
	_check(primary.health < primary.max_health, "axe primary fixture was not hit")
	_check(outer.health < outer_before, "axe outer follow-through did not seek an unhit enemy")
	_cleanup_nodes([primary, outer, player])


func _test_hammer_and_flail() -> void:
	var hammer_player := _player_with_final("berserk", "hammer")
	var hammer = BerserkWeaponScript.new()
	hammer.weapon_id = "hammer"
	hammer.attack_shape = "circle"
	hammer.aoe_radius = 190.0
	hammer_player.add_child(hammer)
	hammer.set_process(false)
	var delayed_target := _enemy(Vector2(120.0, 0.0))
	await process_frame
	var before := delayed_target.health
	hammer._resolve_constellation_attack(hammer_player, Vector2.RIGHT, [])
	await create_timer(0.18).timeout
	_check(delayed_target.health < before, "hammer delayed aftershock dealt no damage")
	_check(StatusEffects.has_status(delayed_target, "constellation_hammer_stagger"), "hammer aftershock did not apply stagger status")
	_cleanup_nodes([delayed_target, hammer_player])

	var flail_player := _player_with_final("knight", "holy_flail")
	var flail = HolyFlailScript.new()
	flail.weapon_id = "holy_flail"
	flail.aoe_radius = 190.0
	flail_player.add_child(flail)
	flail.set_process(false)
	var flail_target := _enemy(Vector2(70.0, 0.0))
	await process_frame
	var flail_before := flail_target.health
	var return_result: Dictionary = flail.constellation_return_pulse()
	_check(bool(return_result.get("triggered", false)), "flail return event did not trigger")
	_check(flail_target.health < flail_before, "flail return pulse dealt no damage")
	_cleanup_nodes([flail_target, flail_player])


func _test_press_second_jaw() -> void:
	var player := _player_with_final("robot", "robot_hydraulic_press")
	var press = PressScript.new()
	press.weapon_id = "robot_hydraulic_press"
	press.attack_range = 430.0
	press.beam_width = 56.0
	press.grenade_delay = 0.01
	player.add_child(press)
	press.set_process(false)
	var target := _enemy(Vector2(180.0, 10.0))
	await process_frame
	var before := target.health
	var result: Dictionary = press._schedule_constellation_second_jaw(player, Vector2(28.0, 0.0), Vector2(458.0, 0.0), Vector2.RIGHT, 180.0)
	_check(bool(result.get("triggered", false)), "press event did not schedule second jaw")
	await create_timer(0.18).timeout
	_check(target.health < before, "press second jaw dealt no damage")
	_check(int(press.constellation_second_jaw_preview(180.0).get("jaw_count", 0)) == 1, "press final must keep exactly one second jaw")
	_cleanup_nodes([target, player])


func _test_sentry_overclock() -> void:
	var player := _player_with_final("engineer", "engineer_sentry_wrench")
	var weapon = ClassWeaponScript.new()
	weapon.weapon_id = "engineer_sentry_wrench"
	player.add_child(weapon)
	weapon.set_process(false)
	var sentry = SentryScript.new()
	root.add_child(sentry)
	sentry.setup(weapon, player)
	sentry.set_physics_process(false)
	var target := _enemy(Vector2(60.0, 0.0), 900.0, 1200.0)
	sentry._select_constellation_durable_mark(weapon, player, [target])
	for hit_index in range(4):
		sentry._register_constellation_sentry_hit(weapon, player, target)
	_check(is_equal_approx(sentry.constellation_overclock_bonus(), 0.24), "sentry marked-target overclock bonus is not +24% before heat cap")
	var fifth: Dictionary = sentry._register_constellation_sentry_hit(weapon, player, target)
	_check(bool(fifth.get("triggered", false)), "sentry fifth heat shot did not trigger runtime event")
	var state: Dictionary = sentry.constellation_overclock_state()
	_check(float(state.get("cooldown", 0.0)) >= 1.99 and is_equal_approx(float(state.get("attack_speed_bonus", -1.0)), 0.0), "sentry heat cap did not enter bounded cooldown")
	_cleanup_nodes([target, sentry, player])


func _test_drone_repair_shield() -> void:
	var player := _player_with_final("engineer", "engineer_repair_drone")
	var weapon = ClassWeaponScript.new()
	weapon.weapon_id = "engineer_repair_drone"
	player.add_child(weapon)
	weapon.set_process(false)
	var drone = DroneScript.new()
	root.add_child(drone)
	drone.set_physics_process(false)
	player.health = player.max_health
	var result: Dictionary = drone.constellation_repair_tick(weapon, player, 0.25)
	_check(is_equal_approx(float(result.get("excess", 0.0)), 0.5), "repair tether exceeded/undershot 2 HP/s rail")
	_check(is_equal_approx(float(result.get("shield_added", 0.0)), 0.25), "drone excess repair did not convert at 50%")
	_check(is_equal_approx(float(player.run_modifiers.get("constellation_absorb_flat", 0.0)), 0.25), "drone normalized shield bucket ignored excess conversion")
	_cleanup_nodes([drone, player])


func _test_homunculus_and_pack() -> void:
	var chemist := _player_with_final("chemist", "homunculus_vial")
	var summoner = SummonerScript.new()
	summoner.weapon_id = "homunculus_vial"
	chemist.add_child(summoner)
	summoner.set_process(false)
	var profile: Dictionary = summoner._summon_profile(chemist)
	_check(int(profile.get("constellation_intercepts_left", 0)) == 1, "homunculus profile lost one-intercept cap")
	var ally = AllyScript.new()
	root.add_child(ally)
	ally.set_physics_process(false)
	ally.set_combat_profile(profile)
	var hp_before: float = ally.health
	ally.take_damage(ally.max_health * 0.25)
	_check(is_equal_approx(hp_before - ally.health, ally.max_health * 0.25 * 0.70), "homunculus heavy-hit intercept ratio is not 30%")
	_check(int(ally.constellation_special_state().get("intercepts_left", -1)) == 0, "homunculus intercept was not consumed")
	var burst_target := _enemy(ally.global_position + Vector2(30.0, 0.0))
	await process_frame
	var burst_before := burst_target.health
	ally.take_damage(ally.max_health * 2.0)
	_check(burst_target.health < burst_before, "homunculus death burst dealt no damage")
	_check(bool(ally.constellation_special_state().get("death_burst_fired", false)), "homunculus death burst lifecycle guard did not latch")
	_cleanup_nodes([burst_target, ally, chemist])

	var druid := _player_with_final("druid", "summon_amulet")
	var pack = SummonerScript.new()
	pack.weapon_id = "summon_amulet"
	druid.add_child(pack)
	pack.set_process(false)
	var alpha = AllyScript.new()
	root.add_child(alpha)
	alpha.set_physics_process(false)
	alpha.owner_node = druid
	alpha.constellation_owner_instance_id = druid.get_instance_id()
	alpha.constellation_weapon_id = "summon_amulet"
	var prey := _enemy(Vector2(100.0, 0.0))
	var prey_before := prey.health
	var command: Dictionary = pack._dispatch_constellation_pack_command(druid, [alpha], [prey])
	_check(bool(command.get("triggered", false)), "pack command did not trigger alpha pounce")
	_check(prey.health < prey_before, "pack alpha pounce dealt no damage")
	_check(is_equal_approx(float(pack.constellation_pack_state().get("guard_absorb", 0.0)), 4.0), "pack command did not grant bounded owner guard")
	_cleanup_nodes([prey, alpha, druid])


func _player_with_final(class_id: String, weapon_id: String) -> CharacterBody2D:
	var player = PlayerScript.new()
	root.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.configure_character(class_id)
	var state := Meta.default_state()
	var nodes: Array[String] = []
	for order in range(1, 6):
		nodes.append("%s_%s_b%d" % [class_id, weapon_id, order])
	nodes.append("%s_%s_final" % [class_id, weapon_id])
	state["skill_nodes"] = nodes
	player.apply_constellation_weapon_profiles(Meta.skill_profiles_for_class(state, class_id))
	return player


func _enemy(position: Vector2, health := 1000.0, maximum := 1000.0) -> DummyEnemy:
	var enemy := DummyEnemy.new()
	enemy.global_position = position
	enemy.health = health
	enemy.max_health = maximum
	root.add_child(enemy)
	enemy.add_to_group("enemies")
	return enemy


func _cleanup_nodes(nodes: Array) -> void:
	for node in nodes:
		if node != null and is_instance_valid(node):
			node.free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
