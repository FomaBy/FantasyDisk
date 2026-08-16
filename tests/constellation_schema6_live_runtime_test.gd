extends SceneTree

const Meta := preload("res://scripts/meta_progression.gd")
const PlayerScript := preload("res://scripts/player.gd")
const ClassWeaponScript := preload("res://scripts/class_weapon.gd")
const ProgressionData := preload("res://scripts/progression_data.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")


class RecordingEnemy extends Node2D:
	var health := 5000.0
	var max_health := 5000.0
	var knockback := Vector2.ZERO
	var damage_log: Array[float] = []

	func take_damage(amount: float, _feedback := {}) -> void:
		var dealt := maxf(amount, 0.0)
		damage_log.append(dealt)
		health -= dealt

	func apply_knockback(value: Vector2) -> void:
		knockback += value

	func damage_taken() -> float:
		return max_health - health


var errors := PackedStringArray()

# FAN-2238: запас на реальный полёт снаряда пыли (clamp 0.08..0.45 с) — короче
# окна реагентного следа (0.9 с), поэтому соседние броски успевают встретиться.
const POWDER_IMPACT_WAIT := 0.50


func _initialize() -> void:
	await process_frame
	await _test_timed_absorb_live_mitigation_and_refresh()
	await _test_timed_absorb_configure_epoch()
	_test_rifle_three_hit_suppression()
	await _test_crossbow_arms_then_consumes()
	await _test_deadeye_lockshot_arms_and_cycles_weakpoint()
	await _test_grenade_delayed_shrapnel()
	await _test_prism_three_delayed_ticks()
	await _test_meteor_single_recall()
	await _test_bayonet_countershot_line()
	await _test_censer_single_cast_ward()
	await _test_reactor_fourth_cast_knockback()
	await _test_dark_book_one_collapse_per_cast()
	await _test_acid_detonation_rearms_after_stack_reset()
	await _test_powder_reagent_pair_reacts_once()
	await _test_powder_reagent_same_cast_and_expiry_controls()
	await _test_powder_reagent_final_only_and_weapon_scoped()
	await process_frame
	_test_shatter_one_extra_pierce()
	await _test_shatter_volley_hit_cap()
	await process_frame
	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("SCRUM-1068 live runtime finals passed mitigation, marks, delayed geometry, per-cast caps, ward, knockback, and reset/rearm gates.")
	quit(0)


func _test_timed_absorb_live_mitigation_and_refresh() -> void:
	var player := _player_with_final("elementalist", "elementalist_prism_focus")
	var base_flat := float(player.run_modifiers.get("absorb_flat", 0.0))
	var base_derived := float(player.derived_parameters.get("absorb", 0.0))
	_neutralize_defense_and_dodge(player)
	player.health = player.max_health
	player.set("_damage_invulnerability_left", 0.0)
	player.take_damage(20.0)
	var baseline_loss: float = float(player.max_health) - float(player.health)

	player.health = player.max_health
	player.set("_damage_invulnerability_left", 0.0)
	var stored: float = float(player.constellation_set_timed_absorb("probe", 8.0, 0.12))
	_check(_approx(stored, 8.0), "timed absorb did not store the requested amount")
	_check(_approx(player.constellation_timed_absorb("probe"), 8.0), "timed absorb source lookup is stale")
	_check(_approx(float(player.run_modifiers.get("absorb_flat", 0.0)), base_flat + 8.0), "timed absorb did not update canonical absorb_flat")
	_check(float(player.derived_parameters.get("absorb", 0.0)) > base_derived, "timed absorb did not recompute derived absorb")
	_neutralize_defense_and_dodge(player)
	player.take_damage(20.0)
	var shielded_loss: float = float(player.max_health) - float(player.health)
	_check(shielded_loss + 0.01 < baseline_loss, "timed absorb did not reduce live Player.take_damage loss")

	await create_timer(0.03).timeout
	player.constellation_set_timed_absorb("probe", 5.0, 0.35)
	await create_timer(0.14).timeout
	_check(_approx(player.constellation_timed_absorb("probe"), 5.0), "superseded expiry removed a refreshed timed absorb source")
	await create_timer(0.24).timeout
	_check(_approx(player.constellation_timed_absorb("probe"), 0.0), "refreshed timed absorb did not expire")
	_check(_approx(float(player.run_modifiers.get("absorb_flat", 0.0)), base_flat), "timed absorb expiry did not restore canonical absorb_flat")
	_cleanup_nodes([player])


func _test_timed_absorb_configure_epoch() -> void:
	var player := _player_with_final("elementalist", "elementalist_prism_focus")
	player.constellation_set_timed_absorb("same_source", 2.0, 0.10)
	await create_timer(0.03).timeout
	player.configure_character("elementalist")
	player.constellation_set_timed_absorb("same_source", 5.0, 0.24)
	await create_timer(0.10).timeout
	_check(_approx(player.constellation_timed_absorb("same_source"), 5.0), "pre-config expiry removed a post-config timed absorb source")
	await create_timer(0.17).timeout
	_check(_approx(player.constellation_timed_absorb("same_source"), 0.0), "post-config timed absorb did not expire on its own deadline")
	_cleanup_nodes([player])


func _test_rifle_three_hit_suppression() -> void:
	var player := _player_with_final("soldier", "soldier_rifle")
	var weapon: Variant = _class_weapon(player, "soldier", "soldier_rifle")
	weapon.aoe_radius = 48.0
	weapon.damage_falloff = 0.0
	var enemy := _enemy(Vector2(120.0, 0.0))
	for hit_index in range(2):
		weapon._explode_arquebus_bullet(0, player.get_instance_id(), enemy.global_position, Vector2.RIGHT)
	_check(not StatusEffects.has_status(enemy, "constellation_suppression"), "rifle suppression triggered before the third live explosion hit")
	weapon._explode_arquebus_bullet(0, player.get_instance_id(), enemy.global_position, Vector2.RIGHT)
	_check(StatusEffects.has_status(enemy, "constellation_suppression"), "third live rifle explosion hit did not apply suppression")
	_check(_approx(StatusEffects.damage_multiplier(enemy), 0.78, 0.001), "rifle suppression is not the capped 22% outgoing-damage reduction")
	StatusEffects.tick(enemy, 2.01)
	_check(not StatusEffects.has_status(enemy, "constellation_suppression"), "rifle suppression did not expire after two seconds")
	_cleanup_nodes([enemy, player])


func _test_crossbow_arms_then_consumes() -> void:
	var player := _player_with_final("ranger", "moon_crossbow")
	var weapon: Variant = _class_weapon(player, "ranger", "moon_crossbow")
	weapon.split_count = 0
	weapon.aoe_radius = 80.0
	weapon.charge_seconds = weapon.fire_interval * 2.0
	weapon.charge_max_multiplier = 2.0
	var marked := _enemy(Vector2(140.0, 0.0), 10000.0, 10000.0)
	var other := _enemy(Vector2(220.0, 0.0), 10000.0, 10000.0)
	other.remove_from_group("enemies")
	var mark_key := "constellation_moon_%d" % player.get_instance_id()
	await process_frame

	weapon._process(weapon.fire_interval)
	var partial_damage: float = float(marked.damage_log.back()) if not marked.damage_log.is_empty() else 0.0
	weapon._process(weapon.fire_interval)
	var full_charge_damage: float = float(marked.damage_log.back()) if not marked.damage_log.is_empty() else 0.0
	_check(float(weapon.get("_charge_time")) <= 0.001, "full crossbow release did not reset its charge cycle")
	_check(marked.has_meta(mark_key), "production full-charge release did not arm a moon mark")

	weapon._process(weapon.fire_interval)
	var marked_followup: float = float(marked.damage_log.back()) if not marked.damage_log.is_empty() else 0.0
	_check(full_charge_damage > partial_damage * 1.2, "full-charge setup shot lost its charge identity")
	_check(_approx(marked_followup / maxf(partial_damage, 0.001), 1.28, 0.015), "moon mark did not grant exactly one +28% next-shot payoff")
	_check(not marked.has_meta(mark_key), "moon mark was not consumed by its next primary hit")

	weapon._process(weapon.fire_interval)
	_check(marked.has_meta(mark_key), "second full-charge release did not re-arm its own target")
	marked.remove_from_group("enemies")
	other.add_to_group("enemies")
	await process_frame
	weapon._process(weapon.fire_interval)
	var other_partial: float = float(other.damage_log.back()) if not other.damage_log.is_empty() else 0.0
	_check(_approx(other_partial / maxf(partial_damage, 0.001), 1.0, 0.015), "another target consumed a moon mark it did not own")
	_check(marked.has_meta(mark_key), "other-target hit consumed the original moon mark")
	await create_timer(4.08).timeout
	other.remove_from_group("enemies")
	marked.add_to_group("enemies")
	await process_frame
	weapon._process(weapon.fire_interval)
	var expired_marked: float = float(marked.damage_log.back()) if not marked.damage_log.is_empty() else 0.0
	_check(_approx(expired_marked / maxf(full_charge_damage, 0.001), 1.0, 0.015), "expired moon mark still amplified its primary hit")

	var targetless_player := _player_with_final("ranger", "moon_crossbow")
	var targetless_weapon: Variant = _class_weapon(targetless_player, "ranger", "moon_crossbow")
	targetless_weapon.charge_seconds = targetless_weapon.fire_interval * 2.0
	targetless_weapon.charge_max_multiplier = 2.0
	marked.remove_from_group("enemies")
	await process_frame
	targetless_weapon._process(targetless_weapon.fire_interval)
	targetless_weapon._process(targetless_weapon.fire_interval)
	_check(not targetless_player.run_modifiers.has("constellation_last_final_action"), "targetless full charge armed a constellation mark")
	_cleanup_nodes([marked, other, player, targetless_player])


func _test_deadeye_lockshot_arms_and_cycles_weakpoint() -> void:
	var player := _player_with_final("sniper", "sniper_deadeye_rifle")
	var weapon: Variant = _class_weapon(player, "sniper", "sniper_deadeye_rifle")
	var primary := _enemy(Vector2(540.0, 0.0), 10000.0, 10000.0)
	var overpenetrated := _enemy(Vector2(300.0, 0.0), 10000.0, 10000.0)
	var endpoint := _enemy(Vector2(490.0, 50.0), 10000.0, 10000.0)
	var close := _enemy(Vector2(0.0, 80.0), 10000.0, 10000.0)
	var mark_key := "constellation_weakpoint_%d" % player.get_instance_id()
	await process_frame

	var initial_hit_index := primary.damage_log.size()
	weapon._attack()
	await create_timer(weapon.grenade_delay + 0.08).timeout
	var base_primary_hit := float(primary.damage_log[initial_hit_index]) if primary.damage_log.size() > initial_hit_index else 0.0
	_check(base_primary_hit > 0.0, "deadeye lockshot did not apply its primary hit through the production attack/timer path")
	_check(primary.has_meta(mark_key), "completed deadeye lockshot did not arm its final weakpoint after the primary hit")
	_check(not overpenetrated.has_meta(mark_key), "deadeye overpenetration incorrectly armed a weakpoint")
	_check(not endpoint.has_meta(mark_key), "deadeye endpoint blast incorrectly armed a weakpoint")
	_check(not close.has_meta(mark_key), "deadeye close burst incorrectly armed a weakpoint")

	var other := _enemy(Vector2(650.0, 0.0), 10000.0, 10000.0)
	primary.global_position = Vector2(300.0, 0.0)
	weapon._attack()
	await create_timer(weapon.grenade_delay + 0.08).timeout
	_check(primary.has_meta(mark_key), "deadeye overpenetration consumed another target's weakpoint")
	primary.global_position = Vector2(620.0, 50.0)
	weapon._attack()
	await create_timer(weapon.grenade_delay + 0.08).timeout
	_check(primary.has_meta(mark_key), "deadeye endpoint blast consumed another target's weakpoint")
	primary.global_position = Vector2(0.0, 80.0)
	weapon._attack()
	await create_timer(weapon.grenade_delay + 0.08).timeout
	_check(primary.has_meta(mark_key), "deadeye close burst consumed another target's weakpoint")

	other.remove_from_group("enemies")
	primary.global_position = Vector2(540.0, 0.0)
	var marked_hit_index := primary.damage_log.size()
	weapon._attack()
	await create_timer(weapon.grenade_delay + 0.08).timeout
	var marked_primary_hit := float(primary.damage_log[marked_hit_index]) if primary.damage_log.size() > marked_hit_index else 0.0
	_check(_approx(marked_primary_hit / maxf(base_primary_hit, 0.001), 1.30, 0.015), "deadeye weakpoint did not apply exactly one capped +30% primary-hit bonus")

	var recycled_hit_index := primary.damage_log.size()
	weapon._attack()
	await create_timer(weapon.grenade_delay + 0.08).timeout
	var recycled_primary_hit := float(primary.damage_log[recycled_hit_index]) if primary.damage_log.size() > recycled_hit_index else 0.0
	_check(_approx(recycled_primary_hit / maxf(base_primary_hit, 0.001), 1.30, 0.015), "deadeye weakpoint stacked instead of consuming exactly one mark per primary lockshot")

	await create_timer(4.08).timeout
	var expired_hit_index := primary.damage_log.size()
	weapon._attack()
	await create_timer(weapon.grenade_delay + 0.08).timeout
	var expired_primary_hit := float(primary.damage_log[expired_hit_index]) if primary.damage_log.size() > expired_hit_index else 0.0
	_check(_approx(expired_primary_hit / maxf(base_primary_hit, 0.001), 1.0, 0.015), "deadeye weakpoint did not expire after four seconds")
	_cleanup_nodes([primary, overpenetrated, endpoint, close, other, player])


func _test_grenade_delayed_shrapnel() -> void:
	var player := _player_with_final("soldier", "soldier_grenade")
	var weapon: Variant = _class_weapon(player, "soldier", "soldier_grenade")
	weapon.aoe_radius = 120.0
	weapon.beam_width = 18.0
	weapon.damage_falloff = 0.0
	var center := Vector2(360.0, 0.0)
	var center_enemy := _enemy(center)
	var radial_enemies: Array = []
	for ray_index in range(8):
		radial_enemies.append(_enemy(center + Vector2.RIGHT.rotated(TAU * float(ray_index) / 8.0) * 90.0))
	weapon._explode_grenade_fuse(0, 0, player.get_instance_id(), center, 120.0, 1.0, Vector2.RIGHT)
	var center_after_impact := center_enemy.health
	var radial_after_impact: Array[float] = []
	for radial in radial_enemies:
		radial_after_impact.append(radial.health)
	await create_timer(0.14).timeout
	_check(_approx(center_enemy.health, center_after_impact), "grenade shrapnel fired before the delayed second-wave window")
	await create_timer(0.10).timeout
	for radial_index in range(radial_enemies.size()):
		_check(radial_enemies[radial_index].health < radial_after_impact[radial_index] - 0.01, "grenade shrapnel ray %d did not deal delayed damage" % radial_index)
	var center_second_wave := center_after_impact - center_enemy.health
	_check(center_second_wave > 0.0 and center_second_wave <= 72.01, "grenade center exceeded the two-shard per-target cap: %.3f" % center_second_wave)
	var all_nodes: Array = radial_enemies.duplicate()
	all_nodes.append(center_enemy)
	all_nodes.append(player)
	_cleanup_nodes(all_nodes)


func _test_prism_three_delayed_ticks() -> void:
	var player := _player_with_final("elementalist", "elementalist_prism_focus")
	var weapon: Variant = _class_weapon(player, "elementalist", "elementalist_prism_focus")
	weapon.aoe_radius = 120.0
	weapon.beam_width = 18.0
	var center := Vector2(360.0, 0.0)
	var enemy := _enemy(center)
	var axis_a := Vector2(1.0, 1.0).normalized()
	var axis_b := axis_a.rotated(PI / 2.0)
	weapon._resolve_prism_rift(player.get_instance_id(), center, axis_a, axis_b, Vector2.RIGHT, [])
	var after_impact := enemy.health
	var impact_log_size := enemy.damage_log.size()
	await create_timer(0.34).timeout
	_check(_approx(enemy.health, after_impact), "prism rift dealt damage before its first 0.4s tick")
	await create_timer(1.02).timeout
	var after_third := enemy.health
	_check(enemy.damage_log.size() == impact_log_size + 3, "prism rift did not emit exactly three delayed damage events")
	for log_index in range(impact_log_size, enemy.damage_log.size()):
		_check(_approx(float(enemy.damage_log[log_index]), 18.0, 0.05), "prism delayed tick %d is not 18%% of the live roll" % (log_index - impact_log_size + 1))
	await create_timer(0.45).timeout
	_check(_approx(enemy.health, after_third), "prism rift emitted more than three delayed ticks")
	_cleanup_nodes([enemy, player])


func _test_meteor_single_recall() -> void:
	var player := _player_with_final("elementalist", "elementalist_meteor_core")
	var weapon: Variant = _class_weapon(player, "elementalist", "elementalist_meteor_core")
	weapon.aoe_radius = 120.0
	weapon.beam_width = 18.0
	weapon.damage_falloff = 0.0
	weapon.dot_ticks = 1
	weapon.pool_tick_interval = 2.0
	var center := Vector2(360.0, 0.0)
	var center_enemy := _enemy(center)
	var radial_enemies: Array = []
	for ray_index in range(6):
		radial_enemies.append(_enemy(center + Vector2.RIGHT.rotated(TAU * float(ray_index) / 6.0) * 80.0))
	weapon._resolve_meteor_impact(player.get_instance_id(), center, Vector2.RIGHT, 0, 0)
	var center_after_impact := center_enemy.health
	var radial_after_impact: Array[float] = []
	for radial in radial_enemies:
		radial_after_impact.append(radial.health)
	await create_timer(0.16).timeout
	_check(_approx(center_enemy.health, center_after_impact), "meteor recall fired before its delayed return window")
	await create_timer(0.10).timeout
	for radial_index in range(radial_enemies.size()):
		_check(radial_enemies[radial_index].health < radial_after_impact[radial_index] - 0.01, "meteor recall shard %d dealt no damage" % radial_index)
	var center_recall := center_after_impact - center_enemy.health
	_check(center_recall > 0.0 and center_recall <= 48.01, "meteor center exceeded the two-recall per-target cap: %.3f" % center_recall)
	var health_after_recall := center_enemy.health
	await create_timer(0.30).timeout
	_check(_approx(center_enemy.health, health_after_recall), "meteor emitted more than one recall wave before crater ticks")
	var all_nodes: Array = radial_enemies.duplicate()
	all_nodes.append(center_enemy)
	all_nodes.append(player)
	_cleanup_nodes(all_nodes)


func _test_shatter_one_extra_pierce() -> void:
	var player := _player_with_final("sniper", "sniper_shatter_rounds")
	var weapon: Variant = _class_weapon(player, "sniper", "sniper_shatter_rounds")
	weapon.aoe_radius = 160.0
	var primary := _enemy(Vector2(180.0, 0.0))
	var nearest := _enemy(Vector2(215.0, 0.0))
	var farther := _enemy(Vector2(260.0, 0.0))
	weapon._impact_shatter_bullet(0, primary.get_instance_id(), 100.0)
	_check(primary.damage_taken() > 99.0, "shatter primary fragment dealt no live hit")
	_check(_approx(nearest.damage_taken(), 32.0, 0.05), "shatter extra pierce is not the capped 32% repeat hit")
	_check(_approx(farther.damage_taken(), 0.0), "one shatter fragment pierced more than one additional target")
	_cleanup_nodes([primary, nearest, farther, player])


func _test_bayonet_countershot_line() -> void:
	var player := _player_with_final("soldier", "soldier_bayonet")
	var weapon: Variant = _class_weapon(player, "soldier", "soldier_bayonet")
	weapon.bayonet_auto_shot_chance = 0.0
	weapon.attack_range = 180.0
	weapon.bayonet_shot_range = 320.0
	weapon.beam_width = 18.0
	var first := _enemy(Vector2(80.0, 0.0))
	var behind := _enemy(Vector2(230.0, 0.0))
	await process_frame
	weapon._fire_bayonet_cone(player, Vector2.RIGHT)
	_check(behind.damage_taken() <= 0.001, "bayonet countershot fired synchronously instead of respecting the brace window")
	await create_timer(0.12).timeout
	_check(first.damage_taken() - behind.damage_taken() >= 99.0, "bayonet brace target did not retain its ordinary cone hit")
	_check(_approx(behind.damage_taken(), 55.0, 0.05), "bayonet line target expected 55 damage, got %.3f" % behind.damage_taken())
	_cleanup_nodes([first, behind, player])


func _test_censer_single_cast_ward() -> void:
	var player := _player_with_final("priest", "priest_censer")
	var weapon: Variant = _class_weapon(player, "priest", "priest_censer")
	weapon.storm_ticks = 1
	weapon.burst_interval = 0.05
	weapon.aoe_radius = 120.0
	var enemy := _enemy(Vector2(60.0, 0.0))
	await process_frame
	weapon._fire_priest_ward(player)
	await process_frame
	var damage_before_retaliation := enemy.damage_taken()
	player.health = player.max_health
	_neutralize_defense_and_dodge(player)
	player.derived_parameters["absorb"] = 0.0
	player.set("_damage_invulnerability_left", 0.0)
	player.take_damage(20.0)
	_check(_approx(player.max_health - player.health, 16.4, 0.05), "censer ward expected 16.4 health loss, got %.3f" % (player.max_health - player.health))
	_check(_approx(enemy.damage_taken() - damage_before_retaliation, 45.0, 0.05), "censer retaliation expected 45 damage, got %.3f" % (enemy.damage_taken() - damage_before_retaliation))
	var after_first_retaliation := enemy.damage_taken()
	player.set("_damage_invulnerability_left", 0.0)
	player.take_damage(20.0)
	_check(_approx(enemy.damage_taken(), after_first_retaliation), "censer ward retaliated more than once for one cast")
	_cleanup_nodes([enemy, player])


func _test_reactor_fourth_cast_knockback() -> void:
	var player := _player_with_final("robot", "robot_reactor_core")
	var weapon: Variant = _class_weapon(player, "robot", "robot_reactor_core")
	weapon.aoe_radius = 180.0
	weapon.knockback = 10.0
	var enemy := _enemy(Vector2(65.0, 45.0))
	await process_frame
	for cast_index in range(3):
		weapon._fire_robot_reactor_vent(player, Vector2.RIGHT)
	var before_fourth := enemy.knockback
	weapon._fire_robot_reactor_vent(player, Vector2.RIGHT)
	var pulse_delta := (enemy.knockback - before_fourth).length()
	_check(pulse_delta >= 395.0, "reactor fourth-cast pulse did not apply configured 110 knockback: %.3f" % pulse_delta)
	_cleanup_nodes([enemy, player])


func _test_dark_book_one_collapse_per_cast() -> void:
	var player := _player_with_final("dark_mage", "dark_book")
	var weapon: Variant = _class_weapon(player, "dark_mage", "dark_book")
	weapon.aoe_radius = 48.0
	weapon.projectile_speed = 5000.0
	weapon.mirror_damage_ratio = 1.0
	var center_enemy := _enemy(Vector2.ZERO)
	await process_frame
	weapon.set("_constellation_mirror_cast_token", 20)
	weapon.set("_constellation_mirror_casts", {21: {"pending_pairs": 2, "collapsed": false}})
	weapon._launch_dark_mirror_pair(player, Vector2(220.0, 0.0), 21)
	weapon._launch_dark_mirror_pair(player, Vector2(0.0, 220.0), 21)
	await create_timer(0.30).timeout
	_check(_approx(center_enemy.damage_taken(), 42.0, 0.05), "dark book expected one 42-ratio midpoint collapse, got %.3f" % center_enemy.damage_taken())
	var cap_enemy := _enemy(Vector2.ZERO)
	await process_frame
	weapon.set("_constellation_mirror_casts", {22: {"pending_pairs": 2, "collapsed": false, "hit_counts": {}}})
	weapon._launch_dark_mirror_pair(player, Vector2(20.0, 0.0), 22)
	weapon._launch_dark_mirror_pair(player, Vector2(0.0, 20.0), 22)
	await create_timer(0.30).timeout
	_check(cap_enemy.damage_log.size() == 3, "dark book expected exactly three total hits on an overlapping target, got %d" % cap_enemy.damage_log.size())
	_cleanup_nodes([center_enemy, cap_enemy, player])


func _test_acid_detonation_rearms_after_stack_reset() -> void:
	var player := _player_with_final("chemist", "acid_flask")
	var weapon: Variant = _class_weapon(player, "chemist", "acid_flask")
	weapon.aoe_radius = 90.0
	weapon.pool_contact_charges = true
	weapon.pool_charge_cap = 8
	var enemy := _enemy(Vector2(40.0, 0.0))
	var pools: Array = []
	for pool_index in range(7):
		var pool := Node2D.new()
		root.add_child(pool)
		pools.append(pool)
	await process_frame
	for pool_index in range(5):
		weapon._apply_pool_contact_statuses([enemy], pools[pool_index])
	var after_first := enemy.damage_taken()
	_check(after_first > 0.0, "acid five-stack cycle emitted no detonation")
	var statuses: Dictionary = enemy.get_meta("status_effects", {}).duplicate(true)
	var removed := 0
	for status_id in statuses.keys():
		if str(status_id).begins_with("acid_charge") and removed < 2:
			statuses.erase(status_id)
			removed += 1
	enemy.set_meta("status_effects", statuses)
	weapon._apply_pool_contact_statuses([enemy], pools[5])
	_check(_approx(enemy.damage_taken(), after_first), "acid detonated before rebuilt stacks reached five")
	weapon._apply_pool_contact_statuses([enemy], pools[6])
	_check(enemy.damage_taken() > after_first, "acid latch did not rearm after the stack cycle reset below five")
	pools.append(player)
	pools.append(enemy)
	_cleanup_nodes(pools)


# FAN-2238: пыль давно летит прямым AoE без луж, поэтому облачный вход финала
# «Несовместимые реагенты» в проде мёртв. Реакцию обязан поднимать натуральный
# путь каст → полёт → прилёт: ни один тест ниже не зовёт резолвер, не ставит
# метки руками и не наносит урон вручную.
func _test_powder_reagent_pair_reacts_once() -> void:
	var player := _player_with_final("chemist", "blast_powder")
	var weapon: Variant = _class_weapon(player, "chemist", "blast_powder")
	weapon.damage = 100.0
	var enemy := _enemy(Vector2(200.0, 0.0), 100000.0, 100000.0)
	await process_frame

	weapon._process(weapon.fire_interval)
	await create_timer(POWDER_IMPACT_WAIT).timeout
	_check(enemy.damage_log.size() == 1, "one powder impact alone reacted: %d damage events" % enemy.damage_log.size())

	weapon._process(weapon.fire_interval)
	await create_timer(POWDER_IMPACT_WAIT).timeout
	_check(enemy.damage_log.size() == 3, "the incompatible second blast did not add exactly one reaction: %d events" % enemy.damage_log.size())
	_check(_approx(float(enemy.damage_log[2]), 48.0, 0.05), "cross-reagent reaction is not the declared 48%% payoff: %.3f" % float(enemy.damage_log[2]))

	weapon._process(weapon.fire_interval)
	await create_timer(POWDER_IMPACT_WAIT).timeout
	_check(enemy.damage_log.size() == 4, "the consumed reagent pair paid a repeat reaction: %d events" % enemy.damage_log.size())

	weapon._process(weapon.fire_interval)
	await create_timer(POWDER_IMPACT_WAIT).timeout
	_check(enemy.damage_log.size() == 6, "a fresh reagent pair did not re-arm exactly one reaction: %d events" % enemy.damage_log.size())
	_check(_approx(float(enemy.damage_log[5]), 48.0, 0.05), "re-armed reaction is not the declared 48%% payoff: %.3f" % float(enemy.damage_log[5]))
	_cleanup_nodes([enemy, player])


func _test_powder_reagent_same_cast_and_expiry_controls() -> void:
	var player := _player_with_final("chemist", "blast_powder")
	var weapon: Variant = _class_weapon(player, "chemist", "blast_powder")
	weapon.damage = 100.0
	var left := _enemy(Vector2(200.0, -40.0), 100000.0, 100000.0)
	var right := _enemy(Vector2(200.0, 40.0), 100000.0, 100000.0)
	await process_frame

	# Один бросок заряжен ОДНИМ реагентом: два его взрыва рядом не реагируют.
	weapon._process(weapon.fire_interval)
	await create_timer(POWDER_IMPACT_WAIT).timeout
	_check(
		left.damage_log.size() == 2 and right.damage_log.size() == 2,
		"two same-reagent impacts of one cast reacted: %d/%d events" % [left.damage_log.size(), right.damage_log.size()]
	)

	# Пауза длиннее окна следа: следующий несовместимый бросок реагировать не с чем.
	await create_timer(1.05).timeout
	weapon._process(weapon.fire_interval)
	await create_timer(POWDER_IMPACT_WAIT).timeout
	_check(
		left.damage_log.size() == 4 and right.damage_log.size() == 4,
		"an expired reagent trace still paid a reaction: %d/%d events" % [left.damage_log.size(), right.damage_log.size()]
	)
	_cleanup_nodes([left, right, player])


func _test_powder_reagent_final_only_and_weapon_scoped() -> void:
	# Без купленного финала пыль остаётся чистым прямым AoE и не копит состояния.
	var base_player := _player_with_final("chemist", "blast_powder", false)
	var base_weapon: Variant = _class_weapon(base_player, "chemist", "blast_powder")
	base_weapon.damage = 100.0
	var enemy := _enemy(Vector2(200.0, 0.0), 100000.0, 100000.0)
	await process_frame
	base_weapon._process(base_weapon.fire_interval)
	await create_timer(POWDER_IMPACT_WAIT).timeout
	base_weapon._process(base_weapon.fire_interval)
	await create_timer(POWDER_IMPACT_WAIT).timeout
	_check(enemy.damage_log.size() == 2, "pool-free blast powder reacted without its purchased final: %d events" % enemy.damage_log.size())
	_check(_powder_reagent_traces() == 0, "base blast powder left hidden reagent state behind")
	_check(get_nodes_in_group("chemist_clouds").is_empty(), "base blast powder spawned a pool")

	# Второе оружие того же класса несёт свой финал и реакцию пыли не поднимает.
	var acid_player := _player_with_final("chemist", "acid_flask")
	var acid_weapon: Variant = _class_weapon(acid_player, "chemist", "acid_flask")
	acid_weapon.damage = 100.0
	await process_frame
	acid_weapon._process(acid_weapon.fire_interval)
	await create_timer(POWDER_IMPACT_WAIT).timeout
	_check(_powder_reagent_traces() == 0, "acid flask impacts armed the powder final of another weapon")
	var after_acid := enemy.damage_log.size()
	_cleanup_nodes([acid_player])

	# Чужой владелец с тем же финалом: его след не кормит реакцию этого оружия.
	var owner_a := _player_with_final("chemist", "blast_powder")
	var weapon_a: Variant = _class_weapon(owner_a, "chemist", "blast_powder")
	weapon_a.damage = 100.0
	var owner_b := _player_with_final("chemist", "blast_powder")
	var weapon_b: Variant = _class_weapon(owner_b, "chemist", "blast_powder")
	weapon_b.damage = 100.0
	# Следующий бросок B несёт реагент, несовместимый со следом A: реакции всё
	# равно нет, потому что след принадлежит другому оружию.
	weapon_b.set("_powder_reagent_cast", 1)
	await process_frame
	weapon_a._process(weapon_a.fire_interval)
	await create_timer(POWDER_IMPACT_WAIT).timeout
	weapon_b._process(weapon_b.fire_interval)
	await create_timer(POWDER_IMPACT_WAIT).timeout
	_check(
		enemy.damage_log.size() == after_acid + 2,
		"a foreign owner's reagent trace paid this weapon's reaction: %d events" % (enemy.damage_log.size() - after_acid)
	)
	_cleanup_nodes([enemy, base_player, owner_a, owner_b])


func _powder_reagent_traces() -> int:
	var traces := 0
	for effect in get_nodes_in_group("player_weapon_effects"):
		if (effect as Node).name == "PowderReagentTrace":
			traces += 1
	return traces


func _test_shatter_volley_hit_cap() -> void:
	var player := _player_with_final("sniper", "sniper_shatter_rounds")
	var weapon: Variant = _class_weapon(player, "sniper", "sniper_shatter_rounds")
	weapon.aoe_radius = 180.0
	weapon.set("_constellation_shatter_volley_token", 7)
	var shared := _enemy(Vector2(220.0, 0.0))
	var primaries := [
		_enemy(Vector2(180.0, -24.0)),
		_enemy(Vector2(180.0, 0.0)),
		_enemy(Vector2(180.0, 24.0)),
	]
	for primary in primaries:
		primary.remove_from_group("enemies")
	await process_frame
	for primary in primaries:
		weapon._impact_shatter_bullet(0, primary.get_instance_id(), 100.0, 7)
	_check(_approx(shared.damage_taken(), 64.0, 0.05), "shatter volley expected 64.0 shared repeat damage, got %.3f" % shared.damage_taken())
	var all_nodes: Array = primaries.duplicate()
	all_nodes.append(shared)
	all_nodes.append(player)
	_cleanup_nodes(all_nodes)


func _player_with_final(class_id: String, weapon_id: String, with_final := true) -> CharacterBody2D:
	var player = PlayerScript.new()
	root.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.configure_character(class_id)
	var state := Meta.default_state()
	# The live-final fixture intentionally excludes the five ordinary branch boons:
	# their independent on-hit echoes/axis multipliers would obscure exact final
	# timings and caps. Meta accepts the canonical final node as a profile fixture.
	# `with_final == false` is the unbought-final control: same weapon, no profile.
	state["skill_nodes"] = ["%s_%s_final" % [class_id, weapon_id]] if with_final else []
	player.apply_constellation_weapon_profiles(Meta.skill_profiles_for_class(state, class_id))
	player.derived_parameters["damage"] = 100.0
	# Disable unrelated generic enchant/DoT/leadership echoes. Every weapon fixture
	# below is explicitly routed through the deterministic physical `damage` field.
	player.derived_parameters["magic_damage"] = 0.0
	player.derived_parameters["dot_damage"] = 0.0
	player.derived_parameters["summon_amount"] = 0.0
	player.derived_parameters["crit_chance"] = 0.0
	player.global_position = Vector2.ZERO
	return player


# Изолирует проверяемый эффект от классовой выживаемости. Принятый контракт считает
# защиту и уворот из СЫРЫХ рейтингов, поэтому обнуляем и их: effective_defense(0) ==
# effective_dodge(0) == 0 на любой кривой. Без raw-обнуления живой уворот класса
# случайно съедал бы удар, а живая защита — сдвигала бы ожидаемую потерю HP.
func _neutralize_defense_and_dodge(player: CharacterBody2D) -> void:
	player.derived_parameters["dodge"] = 0.0
	player.derived_parameters["raw_dodge"] = 0.0
	player.derived_parameters["defense"] = 0.0
	player.derived_parameters["raw_defense"] = 0.0


func _class_weapon(player: CharacterBody2D, class_id: String, weapon_id: String) -> Variant:
	var weapon = ClassWeaponScript.new()
	weapon.configure_weapon(ProgressionData.weapon(class_id, weapon_id))
	player.add_child(weapon)
	player.equipped_weapon = weapon
	weapon.set_process(false)
	weapon.damage_parameter = "damage"
	# Player child-entered scaling may recompute derived values after the fixture
	# was created; re-pin unrelated proc channels after weapon attachment.
	player.derived_parameters["damage"] = 100.0
	player.derived_parameters["magic_damage"] = 0.0
	player.derived_parameters["dot_damage"] = 0.0
	player.derived_parameters["summon_amount"] = 0.0
	player.derived_parameters["crit_chance"] = 0.0
	return weapon


func _enemy(position: Vector2, health := 5000.0, maximum := 5000.0) -> RecordingEnemy:
	var enemy := RecordingEnemy.new()
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


func _approx(actual: float, expected: float, epsilon := 0.0005) -> bool:
	return absf(actual - expected) <= epsilon


func _check(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
