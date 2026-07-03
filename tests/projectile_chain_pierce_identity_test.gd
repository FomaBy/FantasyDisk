extends SceneTree

# SCRUM-857: focused runtime contracts for projectile/chain/pierce/delayed-AoE
# class rebalance. These assertions intentionally use real ClassWeapon logic with
# tiny mock bodies so the test stays fast while catching timing/target-rule drift.

const ClassWeapon := preload("res://scripts/class_weapon.gd")
const PD := preload("res://scripts/progression_data.gd")

const EPS := 0.001


class MockOwner extends CharacterBody2D:
	var derived_parameters := {
		"damage": 100.0,
		"magic_damage": 100.0,
		"crit_chance": 0.0,
		"crit_damage_multiplier": 1.0,
		"dot_damage": 4.0,
		"dot_speed": 4.0,
	}
	var run_modifiers := {}
	var stats := {}
	var health := 70.0
	var max_health := 100.0
	var money := 0

	func gain_money(amount: int) -> void:
		money += amount

	func apply_drain_heal(amount: float) -> float:
		var before := health
		health = minf(max_health, health + amount)
		return health - before

	func heal_percent_capped(percent: float) -> void:
		apply_drain_heal(max_health * percent)

	func heal_percent(percent: float) -> void:
		apply_drain_heal(max_health * percent)


class MockEnemy extends Node2D:
	var total_damage := 0.0
	var hit_count := 0

	func take_damage(amount: float) -> void:
		total_damage += amount
		hit_count += 1


func _initialize() -> void:
	var errors: Array = []
	await _test_soldier_grenade_delayed_falloff(errors)
	await _test_elementalist_meteor_long_cast_payoff(errors)
	await _test_thief_coin_ricochet_vs_sniper_shatter(errors)
	await _test_priest_chain_target_rule(errors)
	await _test_dark_mage_pierce_and_curse_decay(errors)

	if not errors.is_empty():
		for error in errors:
			push_error("SCRUM-857 projectile/chain/pierce identity: %s" % str(error))
		push_error("SCRUM-857 focused identity test failed with %d error(s)." % errors.size())
		quit(1)
		return
	print("SCRUM-857 projectile/chain/pierce identity test passed.")
	quit(0)


func _new_scene(name: String) -> Node2D:
	var holder := Node2D.new()
	holder.name = name
	root.add_child(holder)
	current_scene = holder
	return holder


func _new_owner(holder: Node2D, position := Vector2(900, 700)) -> MockOwner:
	var owner := MockOwner.new()
	holder.add_child(owner)
	owner.global_position = position
	return owner


func _new_weapon(owner: MockOwner, class_id: String, weapon_id: String) -> ClassWeapon:
	var weapon := ClassWeapon.new()
	owner.add_child(weapon)
	weapon.configure_weapon(PD.weapon(class_id, weapon_id))
	weapon.set_process(false)
	return weapon


func _new_enemy(holder: Node2D, position: Vector2) -> MockEnemy:
	var enemy := MockEnemy.new()
	enemy.add_to_group("enemies")
	holder.add_child(enemy)
	enemy.global_position = position
	return enemy


func _cleanup(holder: Node2D) -> void:
	holder.queue_free()
	current_scene = null
	await process_frame
	await process_frame


func _test_soldier_grenade_delayed_falloff(errors: Array) -> void:
	var holder := _new_scene("Scrum857GrenadeContract")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "soldier", "soldier_grenade")
	var center := owner.global_position + Vector2(220, 0)
	var center_enemy := _new_enemy(holder, center)
	var edge_enemy := _new_enemy(holder, center + Vector2(float(weapon.get("aoe_radius")) * 0.92, 0))
	await process_frame

	weapon.call("_fire_grenade_cook", owner, center_enemy, Vector2.RIGHT)
	await create_timer(float(weapon.get("grenade_delay")) * 0.70).timeout
	if center_enemy.total_damage > EPS or edge_enemy.total_damage > EPS:
		errors.append("soldier_grenade dealt damage before fuse resolved (center %.3f, edge %.3f)" % [center_enemy.total_damage, edge_enemy.total_damage])
	await create_timer(float(weapon.get("grenade_delay")) * 0.45 + 0.08).timeout
	if center_enemy.total_damage <= EPS:
		errors.append("soldier_grenade did not damage center after fuse")
	if edge_enemy.total_damage <= EPS or edge_enemy.total_damage >= center_enemy.total_damage:
		errors.append("soldier_grenade falloff missing (center %.3f, edge %.3f)" % [center_enemy.total_damage, edge_enemy.total_damage])
	await _cleanup(holder)


func _test_elementalist_meteor_long_cast_payoff(errors: Array) -> void:
	var holder := _new_scene("Scrum857MeteorContract")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "elementalist", "elementalist_meteor_core")
	if float(weapon.get("grenade_delay")) < 0.60:
		errors.append("elementalist_meteor_core delay %.2f is not a long-cast contract" % float(weapon.get("grenade_delay")))
	if int(weapon.get("shard_count")) < 5:
		errors.append("elementalist_meteor_core should expose secondary shards")
	var center := owner.global_position + Vector2(260, 0)
	var center_enemy := _new_enemy(holder, center)
	var edge_enemy := _new_enemy(holder, center + Vector2(float(weapon.get("aoe_radius")) * 0.90, 0))
	await process_frame

	weapon.call("_fire_meteor_shards", owner, center_enemy, Vector2.RIGHT)
	await create_timer(float(weapon.get("grenade_delay")) * 0.55).timeout
	if center_enemy.total_damage > EPS or edge_enemy.total_damage > EPS:
		errors.append("elementalist_meteor_core dealt damage before long cast resolved")
	await create_timer(float(weapon.get("grenade_delay")) * 0.55 + 0.10).timeout
	if center_enemy.total_damage <= edge_enemy.total_damage:
		errors.append("elementalist_meteor_core center payoff should exceed edge damage (center %.3f, edge %.3f)" % [center_enemy.total_damage, edge_enemy.total_damage])
	await _cleanup(holder)


func _test_thief_coin_ricochet_vs_sniper_shatter(errors: Array) -> void:
	var coin_holder := _new_scene("Scrum857CoinContract")
	var coin_owner := _new_owner(coin_holder)
	var coin_weapon := _new_weapon(coin_owner, "thief", "thief_coin_pouch")
	var coin_first := _new_enemy(coin_holder, coin_owner.global_position + Vector2(210, 0))
	var coin_second := _new_enemy(coin_holder, coin_owner.global_position + Vector2(250, 84))
	await process_frame

	coin_weapon.call("_fire_coin_ricochet", coin_owner, coin_first, Vector2.RIGHT)
	await process_frame
	if coin_first.total_damage <= EPS or coin_second.total_damage <= EPS:
		errors.append("thief_coin_pouch should bounce to nearest secondary target")
	if coin_second.total_damage >= coin_first.total_damage:
		errors.append("thief_coin_pouch ricochet should apply falloff (first %.3f, second %.3f)" % [coin_first.total_damage, coin_second.total_damage])
	await _cleanup(coin_holder)

	var split_holder := _new_scene("Scrum857ShatterContract")
	var split_owner := _new_owner(split_holder)
	var split_weapon := _new_weapon(split_owner, "sniper", "sniper_shatter_rounds")
	var split_first := _new_enemy(split_holder, split_owner.global_position + Vector2(210, 0))
	var forward_shard := _new_enemy(split_holder, split_first.global_position + Vector2(165, 0))
	var lateral_nearest := _new_enemy(split_holder, split_first.global_position + Vector2(24, 126))
	await process_frame

	split_weapon.call("_fire_sniper_split_round", split_owner, split_first, Vector2.RIGHT)
	await process_frame
	if split_first.total_damage <= EPS:
		errors.append("sniper_shatter_rounds should hit primary target")
	if forward_shard.total_damage <= EPS:
		errors.append("sniper_shatter_rounds should damage along fan shard trajectory")
	if lateral_nearest.total_damage > EPS:
		errors.append("sniper_shatter_rounds should not behave like nearest-target chain; lateral nearest took %.3f" % lateral_nearest.total_damage)
	await _cleanup(split_holder)


func _test_priest_chain_target_rule(errors: Array) -> void:
	var holder := _new_scene("Scrum857PrayerChainContract")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "priest", "priest_chime")
	var previous := owner.global_position + Vector2(300, 0)
	var nearest_from_previous := _new_enemy(holder, previous + Vector2(42, 0))
	var sustain_arc_target := _new_enemy(holder, previous + Vector2(-38, 82))
	await process_frame

	var chosen = weapon.call("_find_prayer_chain_next", owner.global_position, previous, 160.0, {})
	if chosen != sustain_arc_target:
		errors.append("priest_chime should prefer sustain arc toward owner, not pure nearest bounce (chosen %s, nearest %s)" % [chosen, nearest_from_previous])
	await _cleanup(holder)


func _test_dark_mage_pierce_and_curse_decay(errors: Array) -> void:
	var beam_holder := _new_scene("Scrum857DarkPierceContract")
	var beam_owner := _new_owner(beam_holder)
	var beam_weapon := _new_weapon(beam_owner, "dark_mage", "dark_wand")
	var first := _new_enemy(beam_holder, beam_owner.global_position + Vector2(150, 0))
	var second := _new_enemy(beam_holder, beam_owner.global_position + Vector2(240, 0))
	var third := _new_enemy(beam_holder, beam_owner.global_position + Vector2(330, 0))
	await process_frame

	beam_weapon.call("_fire_single_beam", beam_owner, Vector2.RIGHT)
	await process_frame
	if first.total_damage <= EPS or second.total_damage <= EPS or third.total_damage <= EPS:
		errors.append("dark_wand pierce beam should hit line targets")
	if not (first.total_damage > second.total_damage and second.total_damage > third.total_damage):
		errors.append("dark_wand pierce damage should decay per target (%.3f, %.3f, %.3f)" % [first.total_damage, second.total_damage, third.total_damage])
	await _cleanup(beam_holder)

	var curse_holder := _new_scene("Scrum857CurseDecayContract")
	var curse_owner := _new_owner(curse_holder)
	var curse_weapon := _new_weapon(curse_owner, "dark_mage", "cursed_skull")
	curse_weapon.set("dot_ticks", 0)
	var primary := _new_enemy(curse_holder, curse_owner.global_position + Vector2(160, 0))
	var splash_edge := _new_enemy(curse_holder, primary.global_position + Vector2(float(curse_weapon.get("aoe_radius")) * 0.68, 0))
	await process_frame

	curse_weapon.call("_fire_curse", curse_owner, primary, Vector2.RIGHT)
	await create_timer(0.35).timeout
	if primary.total_damage <= splash_edge.total_damage:
		errors.append("cursed_skull primary curse should exceed decayed splash (primary %.3f, splash %.3f)" % [primary.total_damage, splash_edge.total_damage])
	if splash_edge.total_damage <= EPS:
		errors.append("cursed_skull should still apply decayed splash to nearby enemies")
	await _cleanup(curse_holder)
