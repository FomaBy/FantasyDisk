extends "res://tests/runtime_smoke_test.gd"

# SCRUM-500: focused-тест триггерных (активируемых событием) артефактов.
# На КАЖДЫЙ триггер: применяем артефакт через apply_reward, симулируем событие,
# проверяем наблюдаемый эффект. Шанс-эффекты ставим детерминированно (chance=1.0
# в тестовом моде), чтобы тест не флапал.

const TriggerProgressionData := preload("res://scripts/progression_data.gd")


func _initialize() -> void:
	_test_triggered_artifacts_present_in_data()
	_test_triggered_artifacts_in_reward_pool()
	await _test_on_low_hp_guard()
	await _test_on_take_hit_pulse()
	await _test_on_crit_speed_burst()
	await _test_on_kill_explosion_and_streak()
	await _test_on_room_clear_heal()
	await _test_transient_flags_not_frozen_in_snapshot()
	await _test_character_change_clears_trigger_latches()
	_finish("[triggered_artifacts] PASSED")


func _make_player() -> Node2D:
	var player := (load("res://scenes/Player.tscn") as PackedScene).instantiate() as Node2D
	root.add_child(player)
	player.configure_character("berserk", "sword")
	return player


# Лёгкий враг-заглушка для on_kill/взрыва/контр-волны: умеет take_damage/apply_knockback,
# в группе enemies, считает полученный урон.
func _make_dummy_enemy(pos: Vector2) -> Node2D:
	var enemy := Area2D.new()
	enemy.add_to_group("enemies")
	enemy.global_position = pos
	enemy.set_meta("damage_taken", 0.0)
	enemy.set_meta("knockback_applied", false)
	enemy.set_script(_dummy_enemy_script())
	root.add_child(enemy)
	return enemy


func _dummy_enemy_script() -> GDScript:
	var src := """
extends Area2D
func take_damage(amount: float, _src := \"\") -> bool:
	set_meta(\"damage_taken\", float(get_meta(\"damage_taken\", 0.0)) + amount)
	return true
func apply_knockback(_impulse: Vector2) -> void:
	set_meta(\"knockback_applied\", true)
"""
	var gd := GDScript.new()
	gd.source_code = src
	gd.reload()
	return gd


func _test_triggered_artifacts_present_in_data() -> void:
	var expected_ids := {
		"guardian_bulwark": "on_low_hp",
		"chain_spark": "on_kill",
		"crit_impulse": "on_crit",
		"breather_totem": "on_room_clear",
		"counterwave_sigil": "on_take_hit",
		"soul_harvest": "on_kill",
		"second_wind": "on_low_hp",
		# SCRUM-961: классовые активные артефакты (+ новый триггер on_battle_start).
		"shadow_twin": "on_crit",
		"blood_roar": "on_take_hit",
		"last_onslaught": "on_low_hp",
		"triage_protocol": "on_low_hp",
		"martyr_shroud": "on_low_hp",
		"repair_subroutine": "on_take_hit",
		"prayer_beads": "on_battle_start",
	}
	var found := {}
	var triggers_seen := {}
	for artifact in TriggerProgressionData.ARTIFACTS:
		var aid := str(artifact.get("id", ""))
		if expected_ids.has(aid):
			found[aid] = true
			if not bool(artifact.get("active", false)):
				_fail("Triggered artifact %s must carry active:true." % aid)
				return
			var trig := str(artifact.get("trigger", ""))
			if trig != expected_ids[aid]:
				_fail("Triggered artifact %s expected trigger %s, got %s." % [aid, expected_ids[aid], trig])
				return
			triggers_seen[trig] = true
			if not str(artifact.get("description", "")).begins_with("⚡ Активный"):
				_fail("Triggered artifact %s must mark «⚡ Активный» in description (data-driven UI badge)." % aid)
				return
	if found.size() < 6:
		_fail("Expected >= 6 triggered artifacts in ARTIFACTS, found %d." % found.size())
		return
	if triggers_seen.size() < 4:
		_fail("Expected triggered artifacts to cover >= 4 distinct trigger events, got %d." % triggers_seen.size())
		return


func _test_triggered_artifacts_in_reward_pool() -> void:
	# Автоподхват в общий пул наград/магазин/элитка фактом добавления в ARTIFACTS.
	var pool := TriggerProgressionData.reward_pool("berserk")
	var pool_ids := {}
	for entry in pool:
		pool_ids[str(entry.get("id", ""))] = true
	for required in ["guardian_bulwark", "chain_spark", "crit_impulse", "breather_totem", "counterwave_sigil"]:
		if not pool_ids.has(required):
			_fail("Triggered artifact %s must appear in reward_pool (auto-pickup)." % required)
			return
	var shop := TriggerProgressionData.shop_items()
	var shop_ids := {}
	for entry in shop:
		shop_ids[str(entry.get("id", ""))] = true
	if not shop_ids.has("chain_spark"):
		_fail("Triggered artifacts must appear in shop_items (auto-pickup).")
		return


func _test_on_low_hp_guard() -> void:
	var player := _make_player()
	await process_frame
	player.call("apply_reward", {"kind": "artifact", "id": "guardian_bulwark", "title": "Рубеж Стража", "mods": {"lowhp_guard": 1.0}})
	# Сбить HP ниже порога, затем нанести удар → щит: неуязвимость >0.
	var maxhp := float(player.get("max_health"))
	player.set("health", maxhp * 0.25)
	player.call("_update_low_hp_state")
	var derived := player.get("derived_parameters") as Dictionary
	derived["dodge"] = 0.0  # детерминизм: dodge early-return не должен маскировать on_low_hp.
	player.call("take_damage", 1.0)
	if float(player.get("_damage_invulnerability_left")) < 1.0:
		_fail("on_low_hp guard (guardian_bulwark) should grant brief invulnerability on first low-HP hit.")
		player.queue_free()
		return
	if not bool(player.get("_lowhp_guard_used")):
		_fail("on_low_hp guard should latch _lowhp_guard_used after firing.")
		player.queue_free()
		return
	player.queue_free()
	await process_frame


func _test_on_take_hit_pulse() -> void:
	var player := _make_player()
	await process_frame
	# chance=1.0 для детерминизма.
	player.call("apply_reward", {"kind": "artifact", "id": "counterwave_sigil", "title": "Контр-волна", "mods": {"take_hit_pulse_chance": 1.0}})
	var enemy := _make_dummy_enemy(Vector2(player.global_position) + Vector2(60.0, 0.0))
	await process_frame
	player.set("health", float(player.get("max_health")))  # не дать low-HP щиту перехватить
	var derived := player.get("derived_parameters") as Dictionary
	derived["dodge"] = 0.0  # детерминизм: dodge early-return не должен маскировать on_take_hit.
	player.call("take_damage", 20.0)
	if float(enemy.get_meta("damage_taken", 0.0)) <= 0.0:
		_fail("on_take_hit pulse (counterwave_sigil) should damage nearby enemy.")
		player.queue_free(); enemy.queue_free()
		return
	player.queue_free()
	enemy.queue_free()
	await process_frame


func _test_on_crit_speed_burst() -> void:
	var player := _make_player()
	await process_frame
	player.call("apply_reward", {"kind": "artifact", "id": "crit_impulse", "title": "Импульс Крита", "mods": {"crit_speed_burst": 0.35}})
	var enemy := _make_dummy_enemy(Vector2(player.global_position) + Vector2(40.0, 0.0))
	await process_frame
	var base_speed := float(player.get("speed"))
	player.call("on_weapon_hit", enemy, 10.0, true)  # was_crit=true
	var rm := player.get("run_modifiers") as Dictionary
	if float(rm.get("crit_speed_burst_active", 0.0)) < 1.0:
		_fail("on_crit (crit_impulse) should set crit_speed_burst_active on crit hit.")
		player.queue_free(); enemy.queue_free()
		return
	if float(player.get("speed")) <= base_speed:
		_fail("on_crit speed burst should raise move speed while active (got %f <= %f)." % [float(player.get("speed")), base_speed])
		player.queue_free(); enemy.queue_free()
		return
	# Не-крит не должен включать бафф (на свежем игроке).
	var player2 := _make_player()
	await process_frame
	player2.call("apply_reward", {"kind": "artifact", "id": "crit_impulse", "title": "Импульс Крита", "mods": {"crit_speed_burst": 0.35}})
	player2.call("on_weapon_hit", enemy, 10.0, false)
	if float((player2.get("run_modifiers") as Dictionary).get("crit_speed_burst_active", 0.0)) > 0.0:
		_fail("Non-crit hit must NOT activate crit_speed_burst.")
		player.queue_free(); player2.queue_free(); enemy.queue_free()
		return
	player.queue_free(); player2.queue_free(); enemy.queue_free()
	await process_frame


func _test_on_kill_explosion_and_streak() -> void:
	var player := _make_player()
	await process_frame
	# chance=1.0 взрыв + стак каждое 1-е убийство для детерминизма.
	player.call("apply_reward", {"kind": "artifact", "id": "chain_spark", "title": "Цепная Искра", "mods": {"kill_explosion_chance": 1.0}})
	player.call("apply_reward", {"kind": "artifact", "id": "soul_harvest", "title": "Сбор Душ", "mods": {"kill_streak_heal_every": 1.0}})
	var dead := _make_dummy_enemy(Vector2(player.global_position) + Vector2(30.0, 0.0))
	var bystander := _make_dummy_enemy(Vector2(player.global_position) + Vector2(60.0, 0.0))
	await process_frame
	var maxhp := float(player.get("max_health"))
	player.set("health", maxhp * 0.5)
	var before := float(player.get("health"))
	player.call("on_enemy_killed", dead)
	if float(bystander.get_meta("damage_taken", 0.0)) <= 0.0:
		_fail("on_kill explosion (chain_spark) should damage a bystander near the corpse.")
		player.queue_free(); dead.queue_free(); bystander.queue_free()
		return
	if float(player.get("health")) <= before:
		_fail("on_kill streak heal (soul_harvest, every=1) should heal on kill.")
		player.queue_free(); dead.queue_free(); bystander.queue_free()
		return
	player.queue_free(); dead.queue_free(); bystander.queue_free()
	await process_frame


func _test_on_room_clear_heal() -> void:
	# Проверяем именно через combat_director._end_combat ветку victory (анкер on_room_clear).
	var main := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "sword")
	main.call("_start_combat", false, "battle")
	await process_frame
	var player = main.get("current_player")
	if player == null:
		_fail("on_room_clear test: combat did not spawn a player.")
		main.queue_free()
		return
	player.call("apply_reward", {"kind": "artifact", "id": "breather_totem", "title": "Передышка", "mods": {"room_clear_heal_percent": 0.08}})
	var maxhp := float(player.get("max_health"))
	player.set("health", maxhp * 0.5)
	var before := float(player.get("health"))
	main.get("combat").call("_end_combat", true)
	if float(main.get("run_player_snapshot").get("health", 0.0)) <= before:
		_fail("on_room_clear heal (breather_totem) should heal before snapshot on victory (snapshot health %f <= %f)." % [float(main.get("run_player_snapshot").get("health", 0.0)), before])
		main.queue_free()
		return
	main.queue_free()
	await process_frame


func _test_transient_flags_not_frozen_in_snapshot() -> void:
	# *_active флаги не должны застывать в снапшоте как постоянный бонус.
	var main := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var player := (load("res://scenes/Player.tscn") as PackedScene).instantiate() as Node2D
	root.add_child(player)
	player.configure_character("berserk", "sword")
	var rm := player.get("run_modifiers") as Dictionary
	rm["dodge_rush_active"] = 1.0
	rm["low_hp_active"] = 1.0
	rm["crit_speed_burst_active"] = 1.0
	rm["rush_window_active"] = 1.0
	rm["hurt_active"] = 1.0
	rm["stance_active"] = 1.0
	rm["swarm_fraction"] = 1.0
	rm["riff_streak_active"] = 1.0
	rm["reactor_heat_active"] = 1.0
	rm["ultimate_berserk_active"] = 1.0
	rm["attack_speed_multiplier"] = 1.25 * 1.35
	rm["move_speed_multiplier"] = 1.20 * 1.18
	player.set("run_modifiers", rm)
	main.call("_store_player_snapshot", player)
	var snap_rm: Dictionary = main.get("run_player_snapshot").get("run_modifiers", {})
	for flag in ["dodge_rush_active", "low_hp_active", "crit_speed_burst_active", "rush_window_active", "hurt_active", "stance_active", "swarm_fraction", "riff_streak_active", "reactor_heat_active", "ultimate_berserk_active"]:
		if float(snap_rm.get(flag, 0.0)) != 0.0:
			_fail("Transient flag %s must be zeroed in player snapshot (no balance drift across nodes)." % flag)
			player.queue_free(); main.queue_free()
			return
	if not is_equal_approx(float(snap_rm.get("attack_speed_multiplier", 0.0)), 1.25) \
			or not is_equal_approx(float(snap_rm.get("move_speed_multiplier", 0.0)), 1.20):
		_fail("Timed Berserk ultimate multipliers must be removed from snapshot without erasing persistent run multipliers.")
		player.queue_free(); main.queue_free()
		return
	player.queue_free()
	main.queue_free()
	await process_frame


func _test_character_change_clears_trigger_latches() -> void:
	var player := _make_player()
	await process_frame
	# Загрязнить латчи, затем сменить персонажа → всё должно сброситься.
	player.set("_lowhp_guard_used", true)
	player.set("_kill_streak_counter", 5)
	player.set("_take_hit_pulse_cooldown_left", 9.0)
	player.call("configure_character", "knight", "")
	if bool(player.get("_lowhp_guard_used")) or int(player.get("_kill_streak_counter")) != 0 or float(player.get("_take_hit_pulse_cooldown_left")) != 0.0:
		_fail("configure_character must reset trigger latches (_lowhp_guard_used/_kill_streak_counter/_take_hit_pulse_cooldown_left).")
		player.queue_free()
		return
	player.queue_free()
	await process_frame
