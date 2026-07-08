extends SceneTree

# SCRUM-961: гейт классовых артефактов (artifact_system_matrix §4, §7.2, §8.4).
# Проверяет:
#   а) состав: ровно 85 записей requires_ascension=5, по 5 на каждый из 17 классов,
#      id уникальны, cost = COST_BY_TIER[tier], без affinity_mods;
#   б) применение: каждый классовый артефакт проходит apply_reward без ошибок,
#      его mods-ключи попадают в run_modifiers своего класса;
#   в) удаление: ни один из 17 легаси-id не остался в ARTIFACTS/SHOP_ITEMS;
#   г) поведение самых рискованных хуков (анти-runaway §8.4):
#      rage_hit_stacks (кап 5 + таймаут), duplicate_hit (жёсткий кап 0.65),
#      mine_persistent_arm (кап 5 живых), acid_charge_stacks (кап 5),
#      repair_subroutine (порог заряда 8% max HP), chime_twin_toll (дедуп за каст),
#      homunculus_reactor (вне боевого лимита саммонов).
#
# Запуск: Godot --headless --path . --script res://tests/class_artifacts_test.gd

const PD := preload("res://scripts/progression_data.gd")

const REMOVED_IDS := [
	"blood_sigil", "void_ink", "echo_pick", "jagged_blade", "heavy_grip", "war_belt",
	"warriors_rage", "dark_crystal", "ash_page", "skull_resonator", "ink_candle",
	"copper_string", "broken_pick", "loud_amp", "bass_cable", "split_core", "swift_ink",
]

var _errors: Array = []


func _initialize() -> void:
	seed(85961)

	_check_composition()
	_check_removed_ids()
	await _check_apply_reward_all_classes()
	await _check_rage_hit_stacks()
	await _check_duplicate_hit_cap()
	await _check_persistent_mine_cap()
	await _check_acid_charge_cap()
	await _check_repair_subroutine_threshold()
	await _check_twin_toll_dedup()
	await _check_reactor_homunculus_limit()

	if not _errors.is_empty():
		for e in _errors:
			push_error("Class artifacts: %s" % str(e))
		push_error("Class artifacts test: %d ошибок." % _errors.size())
		quit(1)
		return
	print("Class artifacts test passed (85 записей, 17 классов, поведенческие хуки).")
	quit(0)


func _class_artifacts() -> Array:
	var result := []
	for entry in PD.ARTIFACTS:
		if not ((entry as Dictionary).get("class_affinity", []) as Array).is_empty():
			result.append(entry)
	return result


# (а) Состав 85 классовых записей.
func _check_composition() -> void:
	var class_artifacts := _class_artifacts()
	if class_artifacts.size() != 85:
		_errors.append("ожидалось 85 классовых записей, найдено %d" % class_artifacts.size())
	var per_class := {}
	var seen_ids := {}
	for entry in class_artifacts:
		var art: Dictionary = entry
		var aid := str(art.get("id", ""))
		if seen_ids.has(aid):
			_errors.append("дубль классового id '%s'" % aid)
		seen_ids[aid] = true
		if int(art.get("requires_ascension", 0)) != 5:
			_errors.append("'%s': requires_ascension != 5" % aid)
		var affinity: Array = art.get("class_affinity", []) as Array
		if affinity.size() != 1:
			_errors.append("'%s': class_affinity должен нести ровно один класс" % aid)
			continue
		var cid := str(affinity[0])
		per_class[cid] = int(per_class.get(cid, 0)) + 1
		var tier := int(art.get("tier", 0))
		if int(art.get("cost", 0)) != int(PD.COST_BY_TIER.get(tier, 0)):
			_errors.append("'%s': cost != COST_BY_TIER[%d]" % [aid, tier])
		if art.has("affinity_mods"):
			_errors.append("'%s': affinity_mods запрещены (гейт на выдаче, §1.3)" % aid)
		if not (art.get("mods", {}) as Dictionary).size() > 0:
			_errors.append("'%s': пустые mods — no-op" % aid)
	for cid in PD.character_ids():
		if int(per_class.get(str(cid), 0)) != 5:
			_errors.append("класс %s: %d артефактов вместо 5" % [cid, int(per_class.get(str(cid), 0))])
	if per_class.size() != 17:
		_errors.append("классов с артефактами %d вместо 17" % per_class.size())


# (в) 17 удалённых id не существуют ни в ARTIFACTS, ни в SHOP_ITEMS.
func _check_removed_ids() -> void:
	for removed_id in REMOVED_IDS:
		if not PD.artifact_definition(str(removed_id)).is_empty():
			_errors.append("легаси id '%s' всё ещё в ARTIFACTS/SHOP_ITEMS" % removed_id)


func _make_player(character_id: String, weapon_id := "") -> Node2D:
	var player := (load("res://scenes/Player.tscn") as PackedScene).instantiate() as Node2D
	root.add_child(player)
	player.call("configure_character", character_id, weapon_id)
	return player


func _make_dummy_enemy(pos: Vector2) -> Node2D:
	var enemy := Area2D.new()
	enemy.add_to_group("enemies")
	enemy.set_meta("damage_taken", 0.0)
	enemy.set_script(_dummy_enemy_script())
	root.add_child(enemy)
	enemy.global_position = pos
	return enemy


func _dummy_enemy_script() -> GDScript:
	var src := """
extends Area2D
func take_damage(amount: float, _feedback := {}) -> bool:
	set_meta(\"damage_taken\", float(get_meta(\"damage_taken\", 0.0)) + amount)
	return true
func apply_knockback(_impulse: Vector2) -> void:
	pass
"""
	var gd := GDScript.new()
	gd.source_code = src
	gd.reload()
	return gd


# (б) apply_reward каждого классового артефакта на своём классе: без ошибок,
# все mods-ключи оказались в run_modifiers (множители ушли от 1.0 либо остались
# валидным float, аддитивные — появились ключом).
func _check_apply_reward_all_classes() -> void:
	var by_class := {}
	for entry in _class_artifacts():
		var cid := str(((entry as Dictionary).get("class_affinity", []) as Array)[0])
		if not by_class.has(cid):
			by_class[cid] = []
		(by_class[cid] as Array).append(entry)
	for cid in by_class.keys():
		var player := _make_player(str(cid))
		await process_frame
		for entry in by_class[cid]:
			var art: Dictionary = (entry as Dictionary).duplicate(true)
			art["kind"] = "artifact"
			player.call("apply_reward", art)
			var modifiers: Dictionary = player.get("run_modifiers")
			for key in (art.get("mods", {}) as Dictionary).keys():
				if not modifiers.has(key):
					_errors.append("%s/%s: mods-ключ '%s' не попал в run_modifiers" % [cid, art.get("id"), key])
		var artifacts: Array = player.get("artifacts")
		if artifacts.size() != 5:
			_errors.append("%s: player.artifacts %d записей вместо 5" % [cid, artifacts.size()])
		player.free()
	await process_frame


# (г1) «Багровая рукоять»: melee-стаки капятся 5 (+2%/+1.5% за стак) и гаснут по таймауту.
func _check_rage_hit_stacks() -> void:
	var player := _make_player("berserk", "sword")
	await process_frame
	player.call("apply_reward", {"kind": "artifact", "id": "crimson_grip", "title": "Багровая рукоять", "mods": {"rage_hit_stacks": 1.0}})
	var enemy := _make_dummy_enemy(player.global_position + Vector2(40.0, 0.0))
	await process_frame
	for i in range(9):
		player.call("_apply_meta_keystone_hit_effects", enemy, 10.0, {})
	var modifiers: Dictionary = player.get("run_modifiers")
	if not is_equal_approx(float(modifiers.get("rage_hit_damage_bonus", 0.0)), 0.10):
		_errors.append("rage_hit: кап 5 стаков должен дать +0.10 урона, получено %f" % float(modifiers.get("rage_hit_damage_bonus", 0.0)))
	if not is_equal_approx(float(modifiers.get("rage_hit_attack_speed_bonus", 0.0)), 0.075):
		_errors.append("rage_hit: кап 5 стаков должен дать +0.075 темпа, получено %f" % float(modifiers.get("rage_hit_attack_speed_bonus", 0.0)))
	player.call("_update_rage_hit_stacks", 4.5)
	modifiers = player.get("run_modifiers")
	if float(modifiers.get("rage_hit_damage_bonus", 0.0)) > 0.0:
		_errors.append("rage_hit: стаки не сброшены по таймауту 4с")
	player.free()
	enemy.free()
	await process_frame


# (г2) «Второй залп»/«Боевой устав»: суммарный шанс дубля жёстко капится 0.65 —
# даже с завышенным ключом часть попаданий обязана пройти без дубля.
func _check_duplicate_hit_cap() -> void:
	var player := _make_player("soldier", "soldier_rifle")
	await process_frame
	var weapon: Node = player.get("equipped_weapon")
	if weapon == null:
		_errors.append("duplicate_hit: у солдата не экипировалась аркебуза")
		player.free()
		return
	var modifiers: Dictionary = player.get("run_modifiers")
	modifiers["duplicate_hit_chance"] = 5.0  # заведомо выше капа
	var enemy := _make_dummy_enemy(player.global_position + Vector2(60.0, 0.0))
	await process_frame
	var duplicates := 0
	for i in range(60):
		enemy.set_meta("damage_taken", 0.0)
		weapon.call("_maybe_duplicate_hit", enemy, 10.0, "physical")
		if float(enemy.get_meta("damage_taken", 0.0)) > 0.0:
			duplicates += 1
	if duplicates >= 60:
		_errors.append("duplicate_hit: кап 0.65 не работает — 60/60 дублей при шансе 5.0")
	if duplicates <= 10:
		_errors.append("duplicate_hit: подозрительно мало дублей (%d/60) при капе 0.65" % duplicates)
	player.free()
	enemy.free()
	await process_frame


# (г3) «Минная сумка»: не больше 5 живых персистентных мин.
func _check_persistent_mine_cap() -> void:
	var player := _make_player("engineer", "engineer_pressure_mines")
	await process_frame
	var weapon: Node = player.get("equipped_weapon")
	if weapon == null:
		_errors.append("mine_persistent: у инженера не экипировалась минная сетка")
		player.free()
		return
	(player.get("run_modifiers") as Dictionary)["mine_persistent_arm"] = 1.0
	for i in range(8):
		weapon.call("_spawn_engineer_pressure_mine", player, player.global_position + Vector2(40.0 * float(i), 120.0), i)
	var alive_mines := 0
	for effect in weapon.call("_alive_effects"):
		if (effect as Node).has_meta("persistent_mine"):
			alive_mines += 1
	if alive_mines > 5:
		_errors.append("mine_persistent: %d живых мин > кап 5" % alive_mines)
	if alive_mines < 5:
		_errors.append("mine_persistent: после 8 установок должно жить ровно 5 мин, живых %d" % alive_mines)
	player.free()
	await process_frame


# (г4) «Кислотный катализатор»: стаки едкого DoT капятся 5.
func _check_acid_charge_cap() -> void:
	var player := _make_player("chemist", "acid_flask")
	await process_frame
	var weapon: Node = player.get("equipped_weapon")
	if weapon == null:
		_errors.append("acid_charge: у химика не экипировалась кислотная колба")
		player.free()
		return
	(player.get("run_modifiers") as Dictionary)["acid_charge_stacks"] = 1.0
	var enemy := _make_dummy_enemy(player.global_position + Vector2(50.0, 0.0))
	await process_frame
	for i in range(8):
		weapon.call("_apply_pool_contact_statuses", [enemy])
	var status: Dictionary = StatusEffects.snapshot(enemy).get("acid_charge", {})
	if status.is_empty():
		_errors.append("acid_charge: статус не навесился с лужи")
	elif int(status.get("stacks", 0)) != 5:
		_errors.append("acid_charge: %d стаков вместо капа 5" % int(status.get("stacks", 0)))
	player.free()
	enemy.free()
	await process_frame


# (г5) «Ремонтная подпрограмма»: бамп +3 absorb только по порогу 8% max HP.
func _check_repair_subroutine_threshold() -> void:
	var player := _make_player("robot", "robot_magnetic_anchor")
	await process_frame
	(player.get("run_modifiers") as Dictionary)["repair_charge_ratio"] = 0.5
	var max_health := float(player.get("max_health"))
	var absorb_before := float((player.get("run_modifiers") as Dictionary).get("absorb_flat", 0.0))
	player.call("_charge_repair_subroutine", max_health * 0.10)  # заряд 5% < порога 8%
	if float((player.get("run_modifiers") as Dictionary).get("absorb_flat", 0.0)) > absorb_before:
		_errors.append("repair_subroutine: щит выдан ДО порога 8%% max HP")
	player.call("_charge_repair_subroutine", max_health * 0.10)  # суммарно 10% >= 8%
	var absorb_after := float((player.get("run_modifiers") as Dictionary).get("absorb_flat", 0.0))
	if not is_equal_approx(absorb_after, absorb_before + 3.0):
		_errors.append("repair_subroutine: по порогу ожидался +3 absorb (было %f, стало %f)" % [absorb_before, absorb_after])
	player.free()
	await process_frame


# (г6) «Двойной колокол»: враг в перекрытии двух взрывов ловит урон один раз за каст.
func _check_twin_toll_dedup() -> void:
	var player := _make_player("priest", "priest_chime")
	await process_frame
	var weapon: Node = player.get("equipped_weapon")
	if weapon == null:
		_errors.append("twin_toll: у жреца не экипировался колокол")
		player.free()
		return
	var enemy := _make_dummy_enemy(player.global_position + Vector2(40.0, 0.0))
	await process_frame
	# Базлайн: одиночный взрыв по врагу (урон идёт через meta_damage_multiplier —
	# сравниваем с ним, а не с сырым amount).
	weapon.call("_fire_twin_toll_blast", player.global_position, 10.0, {})
	var single_blast := float(enemy.get_meta("damage_taken", 0.0))
	if single_blast <= 0.0:
		_errors.append("twin_toll: враг в зоне взрыва не получил урона")
	# Продакшен-каст: два взрыва (у цели и у жреца) с ОБЩИМ дедупом — враг в
	# перекрытии обязан получить ровно один взрыв.
	enemy.set_meta("damage_taken", 0.0)
	var blast_hit := {}
	weapon.call("_fire_twin_toll_blast", player.global_position + Vector2(80.0, 0.0), 10.0, blast_hit)
	weapon.call("_fire_twin_toll_blast", player.global_position, 10.0, blast_hit)
	var taken := float(enemy.get_meta("damage_taken", 0.0))
	if taken > single_blast * 1.01:
		_errors.append("twin_toll: дедуп не сработал — %f против одиночного %f" % [taken, single_blast])
	player.free()
	enemy.free()
	await process_frame


# (г7) «Гомункул-реактор»: реактор существует, но НЕ занимает боевой лимит саммонов.
func _check_reactor_homunculus_limit() -> void:
	var player := _make_player("chemist", "homunculus_vial")
	await process_frame
	var weapon: Node = player.get("equipped_weapon")
	if weapon == null:
		_errors.append("reactor: у химика не экипировалась склянка гомункула")
		player.free()
		return
	(player.get("run_modifiers") as Dictionary)["homunculus_reactor"] = 1.0
	var summons_before: int = (weapon.call("_active_weapon_summons", player) as Array).size()
	weapon.call("_update_reactor_homunculus", 0.1)
	var reactor: Node = weapon.get("_reactor_unit")
	if reactor == null or not is_instance_valid(reactor):
		_errors.append("reactor: юнит-реактор не заспавнился")
	else:
		if reactor.is_in_group("allies"):
			_errors.append("reactor: реактор попал в группу allies (занимает лимит)")
		if not reactor.is_in_group("player_weapon_effects"):
			_errors.append("reactor: реактор не зарегистрирован для чистки конца боя")
	var summons_after: int = (weapon.call("_active_weapon_summons", player) as Array).size()
	if summons_after != summons_before:
		_errors.append("reactor: боевой лимит саммонов изменился (%d → %d)" % [summons_before, summons_after])
	player.free()
	await process_frame
