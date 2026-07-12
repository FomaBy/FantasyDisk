extends SceneTree

# SCRUM-942/943/944/946: гейт редизайна кита Химика.
#
#  - SCRUM-942 «Катализатор»: ВЕСЬ периодический урон Химика ×1.5 (hit-контексты
#    damage_type="dot" + статусы через StatusEffects.apply_status_from); прямые
#    хиты без бонуса; другим классам trait не протекает (data-driven CLASS_TRAITS).
#  - SCRUM-943 Взрывная пыль: быстрый ПРЯМОЙ физический close-mid AoE без луж/DoT.
#  - SCRUM-944 Кислотная колба: долгие полупрозрачные лужи; контакт с КАЖДОЙ
#    отдельной лужей вешает один ВЕЧНЫЙ кислотный заряд (тики по dot-оси, кап 5,
#    артефакт +3); стояние в одной луже заряды не множит; заряды переживают лужу.
#  - SCRUM-946 Склянка гомункула: постоянная пара — танк (4x max HP Химика,
#    таунт, смертен, респавн через summon_interval) + неуязвимый кастер
#    (вне allies, волны вечного периодического урона с trait-бонусом);
#    новые PixelLab-спрайты (SCRUM-945) на обоих юнитах.
#
# Запуск: Godot --headless --path . --script res://tests/chemist_kit_test.gd

const PD := preload("res://scripts/progression_data.gd")

const TANK_SPRITE_SOUTH := "res://assets/sprites/allies/homunculus_tank_south.png"
const CASTER_SPRITE_SOUTH := "res://assets/sprites/allies/homunculus_caster_south.png"

var _errors: Array = []


func _initialize() -> void:
	seed(20260709)
	await process_frame

	_check_trait_registry()
	await _check_trait_hooks()
	await _check_status_from_scaling()
	await _check_blast_powder_direct()
	await _check_acid_charges()
	await _check_acid_pool_visuals_and_lifetime()
	await _check_homunculus_pair()
	await _check_homunculus_tank_death_and_respawn()
	_check_new_sprites_exist()

	if not _errors.is_empty():
		for e in _errors:
			push_error("Chemist kit: %s" % str(e))
		push_error("Chemist kit test: %d ошибок." % _errors.size())
		quit(1)
		return
	print("Chemist kit test passed (trait x1.5, blast direct, acid charges, homunculus pair).")
	quit(0)


# --- SCRUM-942: data-driven реестр trait'а -----------------------------------------

func _check_trait_registry() -> void:
	var trait_config: Dictionary = PD.class_trait("chemist")
	if str(trait_config.get("id", "")) != "catalyst" or str(trait_config.get("title", "")).is_empty():
		_errors.append("trait: у Химика нет trait'а catalyst в CLASS_TRAITS")
	if not is_equal_approx(PD.class_periodic_damage_multiplier("chemist"), 1.5):
		_errors.append("trait: periodic-множитель Химика %.2f вместо 1.5" % PD.class_periodic_damage_multiplier("chemist"))
	for other_class in ["berserk", "doctor", "biologist", "dark_mage", "druid"]:
		if not is_equal_approx(PD.class_periodic_damage_multiplier(other_class), 1.0):
			_errors.append("trait: множитель протёк классу %s (%.2f)" % [other_class, PD.class_periodic_damage_multiplier(other_class)])


func _check_trait_hooks() -> void:
	var chemist := _make_player("chemist", "blast_powder")
	await process_frame
	if not is_equal_approx(float(chemist.call("periodic_damage_multiplier")), 1.5):
		_errors.append("trait: player.periodic_damage_multiplier Химика != 1.5")
	var dot_mult := float(chemist.call("meta_damage_multiplier", {"damage_type": "dot"}))
	var direct_mult := float(chemist.call("meta_damage_multiplier", {"damage_type": "physical"}))
	var magic_mult := float(chemist.call("meta_damage_multiplier", {"damage_type": "magic"}))
	if not is_equal_approx(dot_mult, 1.5):
		_errors.append("trait: dot-контекст Химика дал %.3f вместо 1.5" % dot_mult)
	if not is_equal_approx(direct_mult, 1.0) or not is_equal_approx(magic_mult, 1.0):
		_errors.append("trait: прямой контекст Химика изменился (phys %.3f, magic %.3f)" % [direct_mult, magic_mult])
	chemist.free()
	var berserk := _make_player("berserk", "sword")
	await process_frame
	if not is_equal_approx(float(berserk.call("meta_damage_multiplier", {"damage_type": "dot"})), 1.0):
		_errors.append("trait: dot-контекст Берсерка получил чужой множитель")
	berserk.free()
	await process_frame


func _check_status_from_scaling() -> void:
	var chemist := _make_player("chemist", "acid_flask")
	var berserk := _make_player("berserk", "sword")
	await process_frame
	var enemy_a := _make_dummy_enemy(Vector2(400, 300))
	var enemy_b := _make_dummy_enemy(Vector2(500, 300))
	await process_frame
	StatusEffects.apply_status_from(chemist, enemy_a, "test_periodic", {"duration": 5.0, "dot_damage": 2.0, "dot_interval": 1.0})
	StatusEffects.apply_status_from(berserk, enemy_b, "test_periodic", {"duration": 5.0, "dot_damage": 2.0, "dot_interval": 1.0})
	var chemist_tick := float((StatusEffects.snapshot(enemy_a).get("test_periodic", {}) as Dictionary).get("dot_damage", 0.0))
	var berserk_tick := float((StatusEffects.snapshot(enemy_b).get("test_periodic", {}) as Dictionary).get("dot_damage", 0.0))
	if not is_equal_approx(chemist_tick, 3.0):
		_errors.append("apply_status_from: тик Химика %.2f вместо 3.0 (2.0 x 1.5)" % chemist_tick)
	if not is_equal_approx(berserk_tick, 2.0):
		_errors.append("apply_status_from: тик Берсерка %.2f вместо 2.0 (без trait'а)" % berserk_tick)
	chemist.free()
	berserk.free()
	enemy_a.free()
	enemy_b.free()
	await process_frame


# --- SCRUM-943: взрывная пыль — быстрый прямой физический AoE ----------------------

func _check_blast_powder_direct() -> void:
	var config: Dictionary = PD.weapon("chemist", "blast_powder")
	if bool(config.get("leaves_pool", false)):
		_errors.append("blast: leaves_pool не убран — редизайн SCRUM-943 не применён")
	if str(config.get("damage_parameter", "")) != "damage":
		_errors.append("blast: damage_parameter %s вместо физического damage" % config.get("damage_parameter", ""))
	if float(config.get("fire_interval", 9.0)) > 0.8:
		_errors.append("blast: fire_interval %.2f — не быстрый темп (ожидается <= 0.8)" % float(config.get("fire_interval", 9.0)))
	if float(config.get("attack_range", 9999.0)) > 520.0 or float(config.get("aoe_radius", 9999.0)) > 170.0:
		_errors.append("blast: close-mid геометрия нарушена (range %.0f, radius %.0f)" % [float(config.get("attack_range", 0.0)), float(config.get("aoe_radius", 0.0))])
	if int(config.get("dot_ticks", 0)) > 0:
		_errors.append("blast: остались базовые dot_ticks")

	var chemist := _make_player("chemist", "blast_powder")
	await process_frame
	var weapon: Node = chemist.get("equipped_weapon")
	if weapon == null:
		_errors.append("blast: оружие не экипировалось")
		chemist.free()
		return
	if str(weapon.call("_weapon_damage_type")) != "physical":
		_errors.append("blast: канал урона не физический")
	var enemy := _make_dummy_enemy(chemist.global_position + Vector2(60, 0))
	await process_frame
	# Нейтрализуем универсальный он-хит magic-enchant (чужая механика) — здесь
	# проверяем ЧИСТЫЙ прямой урон взрыва и отсутствие trait-бонуса на нём.
	var chemist_derived: Dictionary = chemist.get("derived_parameters")
	chemist_derived["magic_damage"] = 0.0
	chemist.set("derived_parameters", chemist_derived)
	weapon.call("_damage_aoe_projectile_explosion", enemy.global_position, 150.0, 10.0)
	var taken := float(enemy.get_meta("damage_taken", 0.0))
	if taken <= 0.0:
		_errors.append("blast: прямой взрыв не нанёс урона")
	elif taken > 10.0 * 1.01:
		_errors.append("blast: прямой взрыв усилен (%.2f > 10) — trait протёк в прямой хит" % taken)
	if get_nodes_in_group("chemist_clouds").size() > 0:
		_errors.append("blast: взрыв оставил лужу")
	chemist.free()
	enemy.free()
	await process_frame


# --- SCRUM-944: кислотные лужи — вечные контактные заряды --------------------------

func _check_acid_charges() -> void:
	var chemist := _make_player("chemist", "acid_flask")
	await process_frame
	var weapon: Node = chemist.get("equipped_weapon")
	if weapon == null:
		_errors.append("acid: оружие не экипировалось")
		chemist.free()
		return
	var enemy := _make_dummy_enemy(chemist.global_position + Vector2(50, 0))
	await process_frame

	var pool_a := Node2D.new()
	var pool_b := Node2D.new()
	root.add_child(pool_a)
	root.add_child(pool_b)

	# Одна лужа: сколько ни тикай — ровно один заряд (без бесконечного стака).
	for i in range(6):
		weapon.call("_apply_pool_contact_statuses", [enemy], pool_a)
	if StatusEffects.count_status_prefix(enemy, "acid_charge") != 1:
		_errors.append("acid: одна лужа дала %d зарядов вместо 1" % StatusEffects.count_status_prefix(enemy, "acid_charge"))

	# Вторая лужа — второй заряд.
	weapon.call("_apply_pool_contact_statuses", [enemy], pool_b)
	if StatusEffects.count_status_prefix(enemy, "acid_charge") != 2:
		_errors.append("acid: две лужи дали %d зарядов вместо 2" % StatusEffects.count_status_prefix(enemy, "acid_charge"))

	# Тик заряда — по dot-оси с trait-бонусом: dot_damage x 0.30 x 1.5.
	var derived: Dictionary = chemist.get("derived_parameters")
	var expected_tick := maxf(float(derived.get("dot_damage", 2.0)) * float(weapon.get("pool_charge_tick_multiplier")), 0.30) * 1.5
	var charge_snapshot := StatusEffects.snapshot(enemy)
	for status_id in charge_snapshot.keys():
		if not str(status_id).begins_with("acid_charge"):
			continue
		var status: Dictionary = charge_snapshot[status_id]
		if absf(float(status.get("dot_damage", 0.0)) - expected_tick) > 0.01:
			_errors.append("acid: тик заряда %.3f вместо %.3f (dot-ось x trait)" % [float(status.get("dot_damage", 0.0)), expected_tick])
		if float(status.get("duration", 0.0)) < 900000.0:
			_errors.append("acid: заряд не вечный (duration %.0f)" % float(status.get("duration", 0.0)))
		break

	# Заряды живут после смерти лужи и продолжают тикать.
	pool_a.free()
	pool_b.free()
	await process_frame
	var taken_before := float(enemy.get_meta("damage_taken", 0.0))
	StatusEffects.tick(enemy, float(weapon.get("pool_charge_tick_interval")) + 0.05)
	var taken_after := float(enemy.get_meta("damage_taken", 0.0))
	if taken_after <= taken_before:
		_errors.append("acid: заряды перестали тикать после смерти лужи")
	var expected_two_charges := expected_tick * 2.0
	if absf((taken_after - taken_before) - expected_two_charges) > 0.05:
		_errors.append("acid: суммарный тик двух зарядов %.3f вместо %.3f" % [taken_after - taken_before, expected_two_charges])

	# Кап: базово 5 зарядов с разных луж.
	var extra_pools: Array = []
	for i in range(8):
		var extra_pool := Node2D.new()
		root.add_child(extra_pool)
		extra_pools.append(extra_pool)
		weapon.call("_apply_pool_contact_statuses", [enemy], extra_pool)
	if StatusEffects.count_status_prefix(enemy, "acid_charge") != int(weapon.get("pool_charge_cap")):
		_errors.append("acid: кап зарядов %d вместо %d" % [StatusEffects.count_status_prefix(enemy, "acid_charge"), int(weapon.get("pool_charge_cap"))])
	for extra_pool in extra_pools:
		(extra_pool as Node).free()

	chemist.free()
	enemy.free()
	await process_frame


func _check_acid_pool_visuals_and_lifetime() -> void:
	var config: Dictionary = PD.weapon("chemist", "acid_flask")
	if not bool(config.get("leaves_pool", false)) or not bool(config.get("pool_contact_charges", false)):
		_errors.append("acid: конфиг потерял leaves_pool/pool_contact_charges")
	if float(config.get("pool_duration", 0.0)) < 6.0:
		_errors.append("acid: pool_duration %.1f — лужа не долгоживущая (ожидается >= 6с)" % float(config.get("pool_duration", 0.0)))
	if not bool(config.get("pool_translucent", false)):
		_errors.append("acid: конфиг не полупрозрачный (pool_translucent)")

	var chemist := _make_player("chemist", "acid_flask")
	await process_frame
	var weapon: Node = chemist.get("equipped_weapon")
	weapon.call("_spawn_damage_pool", chemist.global_position + Vector2(80, 0), 2.0)
	var pools := get_nodes_in_group("chemist_clouds")
	if pools.is_empty():
		_errors.append("acid: лужа не заспавнилась")
	else:
		var pool_sprite := (pools[0] as Node).find_child("PoolSprite", true, false) as Sprite2D
		if pool_sprite == null:
			_errors.append("acid: у лужи нет PoolSprite")
		elif pool_sprite.modulate.a > 0.6:
			_errors.append("acid: лужа непрозрачная (alpha %.2f > 0.6)" % pool_sprite.modulate.a)
		for pool in pools:
			(pool as Node).queue_free()
	chemist.free()
	await process_frame


# --- SCRUM-946: пара «танк + кастер» ------------------------------------------------

func _check_homunculus_pair() -> void:
	var chemist := _make_player("chemist", "homunculus_vial")
	await process_frame
	var weapon: Node = chemist.get("equipped_weapon")
	if weapon == null:
		_errors.append("pair: оружие не экипировалось")
		chemist.free()
		return
	weapon.set_process(false)
	weapon.call("_update_homunculus_pair", 0.1)
	await process_frame

	var tank: Node2D = weapon.get("_pair_tank")
	var caster: Node2D = weapon.get("_pair_caster")
	if tank == null or not is_instance_valid(tank):
		_errors.append("pair: танк не заспавнился")
	if caster == null or not is_instance_valid(caster):
		_errors.append("pair: кастер не заспавнился")
	if tank == null or caster == null:
		chemist.free()
		return

	# Танк: боевой саммон в allies, 4x max HP Химика, таунт, без таймера жизни.
	if not tank.is_in_group("allies"):
		_errors.append("pair: танк не в группе allies")
	var expected_tank_hp := float(chemist.get("max_health")) * 4.0
	if absf(float(tank.get("max_health")) - expected_tank_hp) > expected_tank_hp * 0.01:
		_errors.append("pair: HP танка %.1f вместо 4x HP Химика (%.1f)" % [float(tank.get("max_health")), expected_tank_hp])
	if not bool(tank.get("taunt_pulse")):
		_errors.append("pair: у танка выключен таунт-пульс")
	if float(tank.get("lifetime")) < 1.0e8:
		_errors.append("pair: у танка остался таймер жизни (%.0f)" % float(tank.get("lifetime")))
	# Направленный арт мог уже развернуть танк (восток/запад/север) — принимаем
	# любой из 4 новых PixelLab-кадров танка.
	var tank_body := tank.get_node_or_null("Body") as Sprite2D
	if tank_body == null or tank_body.texture == null \
			or not tank_body.texture.resource_path.begins_with("res://assets/sprites/allies/homunculus_tank_"):
		_errors.append("pair: танк не на новом PixelLab-спрайте (%s)" % (tank_body.texture.resource_path if tank_body != null and tank_body.texture != null else "нет Body"))

	# Кастер: неуязвимый эффект вне боевых групп, без таймера, новый спрайт.
	if caster.is_in_group("allies"):
		_errors.append("pair: кастер попал в allies (собирает аггро/лимит)")
	if caster.has_method("take_damage"):
		_errors.append("pair: кастер уязвим (есть take_damage)")
	if not caster.is_in_group("player_weapon_effects"):
		_errors.append("pair: кастер не зарегистрирован для чистки конца боя")
	var caster_visual := caster.get_node_or_null("CasterVisual") as Sprite2D
	if caster_visual == null or caster_visual.texture == null \
			or not caster_visual.texture.resource_path.begins_with("res://assets/sprites/allies/homunculus_caster_"):
		_errors.append("pair: кастер не на новом PixelLab-спрайте")

	# Волны кастера: вечный периодический заряд с trait-бонусом, стак до капа.
	var enemy := _make_dummy_enemy(caster.global_position + Vector2(40, 0))
	await process_frame
	weapon.call("_fire_caster_wave", chemist)
	var wave_status: Dictionary = StatusEffects.snapshot(enemy).get("homunculus_caster_dot", {})
	if wave_status.is_empty():
		_errors.append("pair: волна кастера не навесила периодический заряд")
	else:
		var derived: Dictionary = chemist.get("derived_parameters")
		var expected_wave_tick := maxf(float(derived.get("dot_damage", 2.0)) * float(weapon.get("summon_wave_dot_multiplier")), 0.30) * 1.5
		if absf(float(wave_status.get("dot_damage", 0.0)) - expected_wave_tick) > 0.01:
			_errors.append("pair: тик волны %.3f вместо %.3f (dot-ось x trait)" % [float(wave_status.get("dot_damage", 0.0)), expected_wave_tick])
		if float(wave_status.get("duration", 0.0)) < 900000.0:
			_errors.append("pair: заряд волны не вечный (duration %.0f)" % float(wave_status.get("duration", 0.0)))
	for i in range(6):
		weapon.call("_fire_caster_wave", chemist)
	var wave_stacks := int((StatusEffects.snapshot(enemy).get("homunculus_caster_dot", {}) as Dictionary).get("stacks", 0))
	if wave_stacks != int(weapon.get("summon_wave_stack_cap")):
		_errors.append("pair: стаки волны %d вместо капа %d" % [wave_stacks, int(weapon.get("summon_wave_stack_cap"))])

	# Кастер следует за танком; после смерти танка — fallback к Химику.
	var anchor_with_tank: Vector2 = weapon.call("_pair_caster_anchor", chemist)
	if anchor_with_tank.distance_to(tank.global_position) > 120.0:
		_errors.append("pair: якорь кастера не у танка")
	tank.call("take_damage", 1.0e12)
	var anchor_fallback: Vector2 = weapon.call("_pair_caster_anchor", chemist)
	if anchor_fallback.distance_to((chemist as Node2D).global_position) > 120.0:
		_errors.append("pair: после смерти танка кастер не вернулся к Химику (fallback)")

	enemy.free()
	chemist.free()
	await process_frame


func _check_homunculus_tank_death_and_respawn() -> void:
	var chemist := _make_player("chemist", "homunculus_vial")
	chemist.add_to_group("player")
	await process_frame
	var weapon: Node = chemist.get("equipped_weapon")
	weapon.set_process(false)
	weapon.call("_update_homunculus_pair", 0.1)
	await process_frame
	var tank: Node2D = weapon.get("_pair_tank")
	if tank == null or not is_instance_valid(tank):
		_errors.append("respawn: танк не заспавнился")
		chemist.free()
		return

	# Живой танк перехватывает аггро реального врага таунт-пульсом.
	# HP врага задираем: базовые 3 HP танк сносит одним ударом ДО пульса,
	# и мёртвый враг вылетает из группы enemies (репро первой красной итерации).
	var enemy := (load("res://scenes/Enemy.tscn") as PackedScene).instantiate() as Node2D
	enemy.set("max_health", 1.0e9)
	root.add_child(enemy)
	enemy.set("health", 1.0e9)
	enemy.global_position = tank.global_position + Vector2(90, 0)
	await process_frame
	tank.call("_update_taunt_pulse", 2.0)
	await process_frame
	var taunted_target: Node2D = enemy.call("_combat_target")
	if taunted_target != tank:
		_errors.append("respawn: живой танк не перехватил аггро (цель %s)" % str(taunted_target))

	# Смерть танка: таунт спадает (цель снова игрок), запускается респавн-таймер.
	tank.call("take_damage", 1.0e12)
	await process_frame
	var target_after_death: Node2D = enemy.call("_combat_target")
	if target_after_death == tank:
		_errors.append("respawn: мёртвый танк продолжает держать аггро")
	weapon.call("_update_homunculus_pair", 0.1)
	var respawn_left := float(weapon.get("_pair_tank_respawn_left"))
	if respawn_left <= 0.0:
		_errors.append("respawn: таймер респавна не взведён после смерти танка")
	weapon.call("_update_homunculus_pair", float(weapon.get("summon_interval")) + 0.5)
	await process_frame
	var new_tank: Node2D = weapon.get("_pair_tank")
	if new_tank == null or not is_instance_valid(new_tank) or new_tank == tank:
		_errors.append("respawn: танк не переспавнился после паузы")
	elif float(new_tank.get("health")) <= 0.0:
		_errors.append("respawn: переспавненный танк мёртв")

	enemy.free()
	chemist.free()
	await process_frame


# --- SCRUM-945/946: новые спрайты гомункулов ---------------------------------------

func _check_new_sprites_exist() -> void:
	for direction in ["south", "north", "east", "west"]:
		for unit in ["tank", "caster"]:
			var path := "res://assets/sprites/allies/homunculus_%s_%s.png" % [unit, direction]
			if not ResourceLoader.exists(path):
				_errors.append("sprites: отсутствует %s" % path)
	# Интеграционные точки арт-воркера (SCRUM-945) переключены со старого арта.
	var legacy := "res://assets/sprites/allies/ally_homunculus.png"
	var ally_paths: Dictionary = (load("res://scripts/ally_minion.gd") as GDScript).get_script_constant_map().get("ALLY_VISUAL_PATHS", {})
	for visual_id in ally_paths.keys():
		if str(ally_paths[visual_id]) == legacy:
			_errors.append("sprites: ally_minion.ALLY_VISUAL_PATHS[%s] всё ещё на старом арте" % visual_id)
	var summoner_constants: Dictionary = (load("res://scripts/summoner_weapon.gd") as GDScript).get_script_constant_map()
	if str(summoner_constants.get("HOMUNCULUS_TEXTURE_PATH", "")) == legacy:
		_errors.append("sprites: summoner_weapon.HOMUNCULUS_TEXTURE_PATH всё ещё на старом арте")


# --- хелперы -------------------------------------------------------------------------

func _make_player(character_id: String, weapon_id := "") -> Node2D:
	var player := (load("res://scenes/Player.tscn") as PackedScene).instantiate() as Node2D
	root.add_child(player)
	player.global_position = Vector2(600, 400)
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
