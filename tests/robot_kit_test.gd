extends SceneTree

# SCRUM-914/915/916/918: фокусный тест кита Робота.
#
#   SCRUM-914 trait «Бронекорпус» (CLASS_TRAITS.robot):
#     - Робот получает ровно 80% ПОСТ-митигационного входящего урона
#       (100 → 80, 5 → 4); множитель применяется ПОСЛЕДНИМ — после
#       absorb/defense (порядок различим субтрактивным absorb'ом);
#     - действует и на «тиковые» источники (source-тег хазарда) — всё, что
#       идёт через Player.take_damage;
#     - другие классы не затронуты (soldier 100 → 100);
#     - анти-бессмертие: рантайм-кламп множителя [0.5..1.0] + худшая суммарная
#       митигация Робота по живым капам < глобального гейта 0.98.
#   SCRUM-915 robot_magnetic_anchor (тяжёлый AoE-пулл):
#     - удар ОТЛОЖЕН на grenade_delay (тяжёлый темп: базовый fire_interval —
#       самый медленный в ките), затем полный ролл с falloff от ЦЕНТРА якоря;
#     - центр = точка якоря (цель), НЕ позиция игрока: рядовые стягиваются к
#       центру (конвергенция 0.85 пути за каст, без овершута через центр);
#     - элитки и боссы НЕ смещаются вовсе, но урон получают полностью;
#     - вне aoe_radius — ни урона, ни пулла; импульс пулла зажат капом 1500
#       (анти-runaway физики на раскачанном радиусе).
#   SCRUM-916 robot_compression_line (широкий коридор компрессии):
#     - урон по ВСЕЙ ширине коридора suppression_width (не только beam_width);
#     - рядовых прижимает к осевой линии (конвергенция 0.80 бокового отступа
#       за каст, ось не пересекается — за 2 каста толпа «выравнивается в ряд»);
#     - элитки/боссы: урон полный, смещение с резистом x0.25;
#     - Робот при касте не двигается; вне коридора/дальности — нетронуты.
#   SCRUM-918 robot_reactor_vent (вращающийся 4-направленный веер):
#     - ровно 4 вентиля с шагом 90° от МИРОВОЙ фазы (старт 0° = восток);
#       направления НЕ зависят от ближайшего врага и параметра direction;
#     - после КАЖДОЙ атаки паттерн +6° по часовой (fire_interval шаг не меняет —
#       скорость атаки ускоряет только частоту шагов); 15 атак = 90° = период;
#     - пер-вентильный урон = ролл x REACTOR_VENT_DAMAGE_RATIO (0.42);
#     - extra_projectile расширяет лопасти, но направлений остаётся 4;
#     - свежий инстанс оружия стартует с фазы 0 (нет застарелого состояния).
#
# Запуск: Godot --headless --path . --script res://tests/robot_kit_test.gd

const ClassWeapon := preload("res://scripts/class_weapon.gd")
const PD := preload("res://scripts/progression_data.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")

const EPS := 0.01
# Дрейф позиций (float-геометрия): полпикселя достаточно строго.
const POS_EPS := 0.5


class MockOwner extends CharacterBody2D:
	var character_id := "robot"
	var derived_parameters := {
		"damage": 100.0,
		"magic_damage": 40.0,
		"crit_chance": 0.0,
		"crit_damage_multiplier": 1.0,
		"dot_damage": 5.0,
		"dot_speed": 1.0,
	}
	var run_modifiers := {}
	var stats := {}

	func class_trait_value(key: String, default_value := 0.0) -> float:
		var trait_config: Dictionary = PD.CLASS_TRAITS.get(character_id, {})
		return float(trait_config.get(key, default_value))


# БЕЗ apply_knockback: смещения применяются напрямую к позиции — геометрия
# пулла/компрессии проверяется детерминированно, в пикселях.
class MockEnemy extends Node2D:
	var total_damage := 0.0
	var hit_count := 0
	var hits: Array = []

	func take_damage(amount: float, feedback := {}) -> void:
		total_damage += amount
		hit_count += 1
		hits.append({"amount": amount, "feedback": (feedback if feedback is Dictionary else {}).duplicate(true)})

	func _show_combat_feedback(_amount: float, _feedback: Dictionary) -> void:
		pass


# С apply_knockback: копит импульсы — проверка капа импульса пулла.
class MockKnockbackEnemy extends MockEnemy:
	var impulses: Array = []

	func apply_knockback(impulse: Vector2) -> void:
		impulses.append(impulse)


func _initialize() -> void:
	var errors: Array = []
	_test_kit_data_shape(errors)
	await _test_armored_hull_trait(errors)
	await _test_anchor_pull_center_and_immunity(errors)
	await _test_anchor_impulse_cap(errors)
	await _test_press_corridor_compression(errors)
	await _test_reactor_rotating_fan(errors)
	await _test_reactor_blade_width_and_reset(errors)
	await _test_delayed_callbacks_survive_vfx_teardown(errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Robot kit: %s" % str(error))
		push_error("Robot kit test failed with %d error(s)." % errors.size())
		quit(1)
		return
	print("Robot kit test passed (SCRUM-914/915/916/918).")
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


func _new_weapon(owner: CharacterBody2D, class_id: String, weapon_id: String) -> ClassWeapon:
	var weapon := ClassWeapon.new()
	owner.add_child(weapon)
	weapon.configure_weapon(PD.weapon(class_id, weapon_id))
	# Гвоздь от авто-атак: тест стреляет только явными вызовами.
	weapon.set_process(false)
	weapon.set("_cooldown", 1.0e9)
	return weapon


func _new_enemy(holder: Node2D, position: Vector2, groups: Array = []) -> MockEnemy:
	var enemy := MockEnemy.new()
	enemy.add_to_group("enemies")
	for group in groups:
		enemy.add_to_group(str(group))
	holder.add_child(enemy)
	enemy.global_position = position
	return enemy


func _cleanup(holder: Node2D) -> void:
	holder.queue_free()
	current_scene = null
	await process_frame
	await process_frame


# --- форма данных кита -----------------------------------------------------------


func _test_kit_data_shape(errors: Array) -> void:
	# SCRUM-914: trait в каноническом реестре, ровно x0.8, в рантайм-клампе.
	var trait_config: Dictionary = PD.class_trait("robot")
	if str(trait_config.get("id", "")) != "armored_hull":
		errors.append("robot trait must be registered as armored_hull (got '%s')" % str(trait_config.get("id", "")))
	var multiplier := float(trait_config.get("incoming_damage_multiplier", 0.0))
	if absf(multiplier - 0.8) > 0.001:
		errors.append("armored_hull must be exactly x0.8 incoming (got %.3f)" % multiplier)
	if multiplier < 0.5 or multiplier > 1.0:
		errors.append("trait multiplier must live inside the runtime clamp [0.5..1.0]")
	# Изоляция: ключ несёт ТОЛЬКО Робот (другие классы не затронуты).
	for class_id in PD.CLASS_TRAITS:
		if class_id == "robot":
			continue
		if (PD.CLASS_TRAITS[class_id] as Dictionary).has("incoming_damage_multiplier"):
			errors.append("incoming_damage_multiplier leaked into CLASS_TRAITS.%s" % str(class_id))
	# Русский codex: игрок видит встроенный игнор 20%.
	var character: Dictionary = PD.character_config("robot")
	if not str(character.get("strengths", "")).contains("20%"):
		errors.append("robot codex strengths must explain the built-in 20%% damage ignore")

	var anchor: Dictionary = PD.weapon("robot", "robot_magnetic_anchor")
	var press: Dictionary = PD.weapon("robot", "robot_hydraulic_press")
	var reactor: Dictionary = PD.weapon("robot", "robot_reactor_core")
	# SCRUM-915: якорь — самый тяжёлый/редкий инструмент кита с большой зоной.
	var anchor_interval := float(anchor.get("fire_interval", 0.0))
	if anchor_interval < 1.8:
		errors.append("anchor must feel slow/heavy at baseline (fire_interval >= 1.8, got %.2f)" % anchor_interval)
	if not (anchor_interval > float(press.get("fire_interval", 99.0)) and anchor_interval > float(reactor.get("fire_interval", 99.0))):
		errors.append("anchor must be the slowest weapon of the kit")
	if float(anchor.get("damage_multiplier", 0.0)) < 1.3:
		errors.append("anchor must carry the heavy-hit budget of the kit (damage_multiplier >= 1.3)")
	if float(anchor.get("aoe_radius", 0.0)) < 230.0:
		errors.append("anchor AoE must stay fairly large (>= 230, got %.0f)" % float(anchor.get("aoe_radius", 0.0)))
	# SCRUM-916: коридор заметно шире центральной оси (урон — по всей ширине).
	var corridor_width := float(press.get("suppression_width", 0.0))
	if corridor_width < 280.0:
		errors.append("press corridor must be wide (suppression_width >= 280, got %.0f)" % corridor_width)
	if corridor_width <= float(press.get("beam_width", 0.0)):
		errors.append("press corridor must be wider than the visual center jaw (beam_width)")
	# SCRUM-918: ровно 4 направления в данных.
	if int(reactor.get("projectile_count", 0)) != 4:
		errors.append("reactor must fix exactly 4 vent directions (projectile_count 4)")
	# Кит остаётся физическим (класс-балансовая семья).
	for pair in [["anchor", anchor], ["press", press], ["reactor", reactor]]:
		if str((pair[1] as Dictionary).get("damage_parameter", "")) != "damage":
			errors.append("%s must stay on the physical damage channel" % str(pair[0]))


# --- SCRUM-914: trait «Бронекорпус» ------------------------------------------------


func _take_hit(player: Node, amount: float, source := "") -> float:
	var before := float(player.get("health"))
	player.set("_damage_invulnerability_left", 0.0)
	player.call("take_damage", amount, source)
	return before - float(player.get("health"))


func _make_real_player(character_id: String, weapon_id: String) -> Node:
	var player := PLAYER_SCENE.instantiate()
	root.add_child(player)
	(player as Node2D).global_position = Vector2(2600, 2600)
	player.call("configure_character", character_id, weapon_id)
	var weapon: Node = player.get("equipped_weapon")
	if weapon != null:
		weapon.set_process(false)
		weapon.set("_cooldown", 1.0e9)
	# Детерминизм: без уворота/брони/поглощения/регена и без run-модов —
	# post-mitigation вход равен сырому amount.
	var derived: Dictionary = player.get("derived_parameters")
	derived["dodge"] = 0.0
	derived["defense"] = 0.0
	derived["absorb"] = 0.0
	derived["regeneration"] = 0.0
	player.set("run_modifiers", {})
	player.set("health", 400.0)
	return player


func _test_armored_hull_trait(errors: Array) -> void:
	var robot := _make_real_player("robot", "robot_reactor_core")
	await process_frame

	# AC: 100 post-mitigation → 80; 5 → 4 (большой и малый удар).
	var big_hit := _take_hit(robot, 100.0)
	if absf(big_hit - 80.0) > EPS:
		errors.append("robot must take exactly 80 of a 100 post-mitigation hit (got %.3f)" % big_hit)
	var small_hit := _take_hit(robot, 5.0)
	if absf(small_hit - 4.0) > EPS:
		errors.append("robot must take exactly 4 of a 5 post-mitigation hit (got %.3f)" % small_hit)

	# AC: множитель — ПОСЛЕ absorb/defense. Субтрактивный absorb различает
	# порядок: 100 → max(100-20, 42) x (1-0.5) x 0.8 = 32; «x0.8 сначала»
	# дал бы (80-20) x 0.5 = 30.
	var derived: Dictionary = robot.get("derived_parameters")
	derived["defense"] = 0.5
	derived["absorb"] = 20.0
	var ordered_hit := _take_hit(robot, 100.0)
	if absf(ordered_hit - 32.0) > EPS:
		errors.append("trait must be the LAST multiplier after absorb+defense (got %.3f, want 32)" % ordered_hit)
	derived["defense"] = 0.0
	derived["absorb"] = 0.0

	# AC: тиковые/хазардные источники (всё, что идёт через take_damage) тоже x0.8.
	var dot_hit := _take_hit(robot, 10.0, "poison_zone_tick")
	if absf(dot_hit - 8.0) > EPS:
		errors.append("tick/hazard-style incoming damage must also be reduced (got %.3f, want 8)" % dot_hit)

	# AC: другие классы не затронуты.
	var soldier := _make_real_player("soldier", "soldier_rifle")
	await process_frame
	var soldier_hit := _take_hit(soldier, 100.0)
	if absf(soldier_hit - 100.0) > EPS:
		errors.append("other classes must be unaffected by armored_hull (soldier took %.3f)" % soldier_hit)

	# AC: бессмертие недостижимо. Худшая детерминированная цепочка Робота по
	# живым капам: absorb-пол x (1-defense-кап) x trait; поверх — dodge-кап как
	# expected value. Суммарная митигация обязана оставаться < гейта 0.98
	# (MAX_MITIG global_survivability_balance_smoke).
	var trait_multiplier := clampf(float(PD.class_trait("robot").get("incoming_damage_multiplier", 1.0)), 0.5, 1.0)
	var deterministic_pass := PD.SURVIVABILITY_ABSORB_MIN_DAMAGE_FRACTION * (1.0 - PD.SURVIVABILITY_DEFENSE_CAP) * trait_multiplier
	var deterministic_mitigation := 1.0 - deterministic_pass
	var dodge_ev_mitigation := 1.0 - (1.0 - PD.SURVIVABILITY_DODGE_CAP) * deterministic_pass
	if deterministic_mitigation >= 0.98 or dodge_ev_mitigation >= 0.98:
		errors.append("robot worst-case mitigation breaches the 0.98 immunity gate (det %.4f, dodge-EV %.4f)" % [deterministic_mitigation, dodge_ev_mitigation])
	print("SCRUM-914 evidence: 100->%.1f, 5->%.1f, absorb20+def50 100->%.1f, dot10->%.1f, soldier 100->%.1f; worst-case mitigation det %.2f%%, dodge-EV %.2f%% (< 98%%)." % [
		big_hit, small_hit, ordered_hit, dot_hit, soldier_hit,
		deterministic_mitigation * 100.0, dodge_ev_mitigation * 100.0])

	robot.free()
	soldier.free()
	await process_frame


# --- SCRUM-915: Магнитный Якорь ----------------------------------------------------


func _test_anchor_pull_center_and_immunity(errors: Array) -> void:
	var holder := _new_scene("Scrum915AnchorPull")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "robot", "robot_magnetic_anchor")
	var radius := float(weapon.get("aoe_radius"))
	var falloff := float(weapon.get("damage_falloff"))
	var center := owner.global_position + Vector2(400, 0)
	# Цель на месте якоря; рядовой МЕЖДУ Роботом и центром (пулл к центру =
	# движение ОТ игрока — различает «центр зоны» и «к игроку»).
	var target := _new_enemy(holder, center)
	var puller := _new_enemy(holder, center + Vector2(-150, 0))
	var elite := _new_enemy(holder, center + Vector2(0, 120), ["elite_enemies"])
	var boss := _new_enemy(holder, center + Vector2(120, 0), ["bosses"])
	var outsider := _new_enemy(holder, center + Vector2(radius * 1.6, 0))
	await process_frame

	weapon.call("_fire_robot_magnetic_anchor", owner, target, Vector2.RIGHT)
	# Тяжесть: до grenade_delay удара нет.
	await create_timer(0.15).timeout
	if target.hit_count != 0 or puller.hit_count != 0:
		errors.append("anchor must not hit before its heavy telegraph delay")
	await create_timer(maxf(float(weapon.get("grenade_delay")), 0.08) + 0.30).timeout

	# Урон: полный ролл в центре, falloff от центра зоны.
	if target.hit_count != 1 or absf(target.total_damage - 100.0) > 0.5:
		errors.append("anchor center target must take one full roll (got %.2f)" % target.total_damage)
	var puller_expected := 100.0 * lerpf(1.0, falloff, 150.0 / radius)
	if puller.hit_count != 1 or absf(puller.total_damage - puller_expected) > 0.5:
		errors.append("anchor damage must fall off from the ANCHOR center (got %.2f, want %.2f)" % [puller.total_damage, puller_expected])
	var elite_expected := 100.0 * lerpf(1.0, falloff, 120.0 / radius)
	if absf(elite.total_damage - elite_expected) > 0.5 or absf(boss.total_damage - elite_expected) > 0.5:
		errors.append("elites/bosses inside the AoE must still take correct damage (elite %.2f, boss %.2f, want %.2f)" % [elite.total_damage, boss.total_damage, elite_expected])
	if outsider.hit_count != 0:
		errors.append("enemies outside aoe_radius must be untouched (hits %d)" % outsider.hit_count)

	# Пулл: рядовой стянут к ЦЕНТРУ на 85% пути (150 → 22.5), без овершута,
	# движение ОТ игрока (+x) — центр зоны, не позиция Робота.
	var puller_distance := puller.global_position.distance_to(center)
	if absf(puller_distance - 150.0 * 0.15) > POS_EPS:
		errors.append("normal enemy must converge 85%% of the way to the center (left %.2f, want %.2f)" % [puller_distance, 150.0 * 0.15])
	if puller.global_position.x <= center.x - 150.0 + 100.0:
		errors.append("pull must displace the normal enemy toward the anchor center")
	if puller.global_position.x > center.x + POS_EPS:
		errors.append("pull must never overshoot through the center (x %.2f)" % puller.global_position.x)
	# Элитка/босс: НЕ смещаются вовсе; аутсайдер тоже на месте.
	if elite.global_position.distance_to(center + Vector2(0, 120)) > POS_EPS:
		errors.append("elite must not be displaced by the anchor pull")
	if boss.global_position.distance_to(center + Vector2(120, 0)) > POS_EPS:
		errors.append("boss must not be displaced by the anchor pull")
	if outsider.global_position.distance_to(center + Vector2(radius * 1.6, 0)) > POS_EPS:
		errors.append("outsider must not be displaced")
	await _cleanup(holder)


func _test_anchor_impulse_cap(errors: Array) -> void:
	var holder := _new_scene("Scrum915AnchorCap")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "robot", "robot_magnetic_anchor")
	var center := owner.global_position + Vector2(300, 0)
	var far_enemy := MockKnockbackEnemy.new()
	far_enemy.add_to_group("enemies")
	holder.add_child(far_enemy)
	far_enemy.global_position = center + Vector2(-700, 0)
	await process_frame

	# Раскачанный радиус (AoE-прогрессия): travel 700*0.85=595 требует импульс
	# sqrt(4800*595)~=1690 — рантайм обязан зажать его капом 1500 (анти-runaway).
	weapon.call("_pull_enemies_toward", center, 800.0, float(weapon.get("knockback")))
	if far_enemy.impulses.size() != 1:
		errors.append("pull must knockback the far normal enemy exactly once (got %d)" % far_enemy.impulses.size())
	else:
		var impulse: Vector2 = far_enemy.impulses[0]
		if absf(impulse.length() - ClassWeapon.ANCHOR_PULL_IMPULSE_CAP) > 1.0:
			errors.append("scaled-radius pull impulse must be clamped to the cap (got %.1f, cap %.1f)" % [impulse.length(), ClassWeapon.ANCHOR_PULL_IMPULSE_CAP])
		if impulse.x <= 0.0 or absf(impulse.y) > 0.001:
			errors.append("pull impulse must aim at the anchor center (got %s)" % str(impulse))
	await _cleanup(holder)


# --- SCRUM-916: Гидравлический Пресс -----------------------------------------------


func _test_press_corridor_compression(errors: Array) -> void:
	var holder := _new_scene("Scrum916PressCorridor")
	var owner := _new_owner(holder)
	var owner_start := owner.global_position
	var weapon := _new_weapon(owner, "robot", "robot_hydraulic_press")
	var corridor_width := float(weapon.get("suppression_width"))
	var half_width := corridor_width * 0.5
	var jaw_half_width := float(weapon.get("beam_width")) * 0.5
	var corridor_origin := owner.global_position + Vector2(28, 0)
	# Рядовой в коридоре (side +100); рядовой у ШИРОКОГО края (side > beam_width/2 —
	# регресс полной ширины урона); вне коридора; за дальностью; элитка и босс.
	var compress_a := _new_enemy(holder, corridor_origin + Vector2(300, 100))
	var wide_edge := _new_enemy(holder, corridor_origin + Vector2(250, half_width - 10.0))
	var outside_side := _new_enemy(holder, corridor_origin + Vector2(250, half_width + 30.0))
	var outside_far := _new_enemy(holder, corridor_origin + Vector2(float(weapon.get("attack_range")) + 40.0, 60))
	var elite := _new_enemy(holder, corridor_origin + Vector2(300, -100), ["elite_enemies"])
	var boss := _new_enemy(holder, corridor_origin + Vector2(200, -80), ["bosses"])
	await process_frame

	if half_width - 10.0 <= jaw_half_width:
		errors.append("test geometry: wide_edge must sit beyond the central jaw width")

	weapon.call("_fire_robot_compression_line", owner, null, Vector2.RIGHT)
	await create_timer(maxf(float(weapon.get("grenade_delay")), 0.08) + 0.30).timeout

	# Урон: плоский ролл по ВСЕЙ ширине коридора, включая широкий край.
	for pair in [["compress_a", compress_a], ["wide_edge", wide_edge], ["elite", elite], ["boss", boss]]:
		var corridor_enemy := pair[1] as MockEnemy
		if corridor_enemy.hit_count != 1 or absf(corridor_enemy.total_damage - 100.0) > 0.5:
			errors.append("%s must take exactly one full corridor hit (hits %d, dmg %.2f)" % [str(pair[0]), corridor_enemy.hit_count, corridor_enemy.total_damage])
	if outside_side.hit_count != 0 or outside_far.hit_count != 0:
		errors.append("enemies outside the corridor/range must be untouched (side %d, far %d)" % [outside_side.hit_count, outside_far.hit_count])

	# Компрессия: рядовой side 100 → 20 (гасится 80% отступа), знак сохранён.
	var side_a := compress_a.global_position.y - owner_start.y
	if absf(side_a - 20.0) > POS_EPS:
		errors.append("normal enemy must be squeezed 80%% toward the axis (side %.2f, want 20)" % side_a)
	var side_wide := wide_edge.global_position.y - owner_start.y
	if absf(side_wide - (half_width - 10.0) * 0.2) > POS_EPS:
		errors.append("wide-edge enemy must also compress toward the axis (side %.2f)" % side_wide)
	# Элитка/босс: резист x0.25 → side -100 → -80 и -80 → -64.
	var elite_side := elite.global_position.y - owner_start.y
	if absf(elite_side - (-80.0)) > POS_EPS:
		errors.append("elite displacement must be resisted x0.25 (side %.2f, want -80)" % elite_side)
	var boss_side := boss.global_position.y - owner_start.y
	if absf(boss_side - (-64.0)) > POS_EPS:
		errors.append("boss displacement must be resisted x0.25 (side %.2f, want -64)" % boss_side)
	if outside_side.global_position.distance_to(corridor_origin + Vector2(250, half_width + 30.0)) > POS_EPS:
		errors.append("enemy outside the corridor must not be displaced")

	# Второй каст: толпа «выравнивается в ряд» (side < 5), ось не пересекается.
	weapon.call("_fire_robot_compression_line", owner, null, Vector2.RIGHT)
	await create_timer(maxf(float(weapon.get("grenade_delay")), 0.08) + 0.30).timeout
	var aligned_side := compress_a.global_position.y - owner_start.y
	if aligned_side < -POS_EPS or aligned_side > 5.0:
		errors.append("after two casts normals must align into the lane without crossing it (side %.2f)" % aligned_side)
	# Робот сам не сдвинулся (атака двигает только врагов).
	if owner.global_position.distance_to(owner_start) > 0.001:
		errors.append("press must never move the Robot body")
	await _cleanup(holder)


# --- SCRUM-918: Реакторное Ядро ----------------------------------------------------


func _reactor_axis_enemies(holder: Node2D, owner: MockOwner, distance: float) -> Dictionary:
	return {
		"east": _new_enemy(holder, owner.global_position + Vector2(distance, 0)),
		"south": _new_enemy(holder, owner.global_position + Vector2(0, distance)),
		"west": _new_enemy(holder, owner.global_position + Vector2(-distance, 0)),
		"north": _new_enemy(holder, owner.global_position + Vector2(0, -distance)),
	}


func _test_reactor_rotating_fan(errors: Array) -> void:
	var holder := _new_scene("Scrum918ReactorFan")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "robot", "robot_reactor_core")
	# Свежий инстанс всегда стартует с фазы 0 (новый забег/смена оружия —
	# новый инстанс ClassWeapon => застарелого состояния нет).
	if absf(float(weapon.get("_reactor_vent_phase"))) > 0.0001:
		errors.append("fresh reactor must start at 0 degrees (phase %.4f)" % float(weapon.get("_reactor_vent_phase")))
	var axis := _reactor_axis_enemies(holder, owner, 250.0)
	# Ближайший враг — на диагонали 45° (между вентилями): самонаведение
	# развернуло бы крест на него.
	var diagonal := _new_enemy(holder, owner.global_position + Vector2(85, 85))
	await process_frame

	# Полный пайплайн _attack: цель = ближайший (диагональ), но вентили обязаны
	# пойти по мировому кресту 0/90/180/270 и промахнуться по диагонали.
	weapon.call("_attack")
	await process_frame
	for key in axis:
		var axis_enemy := axis[key] as MockEnemy
		if axis_enemy.hit_count != 1:
			errors.append("cast 1 must hit the %s axis enemy exactly once (got %d)" % [str(key), axis_enemy.hit_count])
		elif absf(axis_enemy.total_damage - 100.0 * ClassWeapon.REACTOR_VENT_DAMAGE_RATIO) > 0.5:
			errors.append("per-vent damage must be roll x %.2f (got %.2f)" % [ClassWeapon.REACTOR_VENT_DAMAGE_RATIO, axis_enemy.total_damage])
	if diagonal.hit_count != 0:
		errors.append("reactor must NOT seek the nearest enemy (diagonal was hit %d times)" % diagonal.hit_count)
	var step := deg_to_rad(ClassWeapon.REACTOR_ROTATION_STEP_DEG)
	if absf(float(weapon.get("_reactor_vent_phase")) - step) > 0.0001:
		errors.append("pattern must rotate exactly +6 degrees after an attack (phase %.4f)" % float(weapon.get("_reactor_vent_phase")))

	# Каст 2 с ЯВНЫМ чужим направлением: паттерн продолжает мировую фазу 6°
	# (aim-независимость), восточный враг ещё в лопасти (side ~26 < 48).
	weapon.call("_fire_robot_reactor_vent", owner, Vector2.UP)
	await process_frame
	var east := axis["east"] as MockEnemy
	if east.hit_count != 2:
		errors.append("cast 2 (phase 6deg) must still clip the east enemy regardless of aim (hits %d)" % east.hit_count)
	# Каст 3: фаза 12° — восточная лопасть уже уехала (side ~52 > 48): веер
	# «заметает» круг, а не липнет к цели.
	weapon.call("_fire_robot_reactor_vent", owner, Vector2.RIGHT)
	await process_frame
	if east.hit_count != 2:
		errors.append("cast 3 (phase 12deg) must sweep past the east enemy (hits %d)" % east.hit_count)
	if absf(float(weapon.get("_reactor_vent_phase")) - step * 3.0) > 0.0001:
		errors.append("after 3 attacks the phase must be exactly 18 degrees")

	# Скорость атаки меняет только частоту шагов: с другим fire_interval шаг
	# остаётся +6°. Добиваем цикл до 15 атак => ровно 90° (крест самосовместился).
	weapon.set("fire_interval", 0.2)
	for _cast in range(12):
		weapon.call("_fire_robot_reactor_vent", owner, Vector2.RIGHT)
	await process_frame
	if absf(float(weapon.get("_reactor_vent_phase")) - deg_to_rad(90.0)) > 0.001:
		errors.append("15 attacks must sweep exactly 90 degrees (phase %.4f rad)" % float(weapon.get("_reactor_vent_phase")))
	# За полный цикл веер накрыл и «мёртвую» диагональ.
	if diagonal.hit_count == 0:
		errors.append("a full rotation cycle must eventually cover the diagonal gap")
	await _cleanup(holder)


func _test_reactor_blade_width_and_reset(errors: Array) -> void:
	var holder := _new_scene("Scrum918ReactorBlades")
	var owner := _new_owner(holder)
	# extra_projectile расширяет лопасти, но направлений остаётся ровно 4.
	owner.run_modifiers = {"extra_projectile": 2.0}
	var weapon := _new_weapon(owner, "robot", "robot_reactor_core")
	if absf(float(weapon.get("_reactor_vent_phase"))) > 0.0001:
		errors.append("re-attached reactor must reset rotation state to 0")
	var axis := _reactor_axis_enemies(holder, owner, 250.0)
	var diagonal := _new_enemy(holder, owner.global_position + Vector2(85, 85))
	await process_frame

	weapon.call("_fire_robot_reactor_vent", owner, Vector2.RIGHT)
	await process_frame
	var total_hits := 0
	for key in axis:
		var axis_enemy := axis[key] as MockEnemy
		total_hits += axis_enemy.hit_count
		if axis_enemy.hit_count != 1:
			errors.append("with extra projectiles the %s vent must still hit exactly once (got %d)" % [str(key), axis_enemy.hit_count])
		elif absf(axis_enemy.total_damage - 100.0 * ClassWeapon.REACTOR_VENT_DAMAGE_RATIO) > 0.5:
			errors.append("extra projectiles must not inflate per-vent damage (got %.2f)" % axis_enemy.total_damage)
	if total_hits != 4:
		errors.append("exactly four vents per attack, extra projectiles only widen blades (hits %d)" % total_hits)
	# Ширина: бонус +14%/снаряд НЕ дотягивается до диагонали (85 > 96*1.28/2).
	if diagonal.hit_count != 0:
		errors.append("widened blades must still be blades, not a circle (diagonal hits %d)" % diagonal.hit_count)
	await _cleanup(holder)


# --- SCRUM-1034: lifecycle-safe отложенные колбэки ---------------------------------


func _free_all_weapon_effects() -> void:
	# Симулируем само-освобождение VFX (телеграф/тезер/боковые лучи) ДО того, как
	# сработает отложенный удар — именно эта гонка раньше держала в лямбде
	# освобождённый Node и печатала engine-ERROR «Lambda capture was freed».
	for effect in get_nodes_in_group("player_weapon_effects"):
		if is_instance_valid(effect):
			effect.queue_free()
	await process_frame
	await process_frame


func _test_delayed_callbacks_survive_vfx_teardown(errors: Array) -> void:
	# SCRUM-1034 focused lifecycle assertion: отложенные удары Робота обязаны
	# довершаться БЕЗ обращения к освобождённым Node (никаких Node-захватов в
	# колбэке — только instance id + Callable.bind), а после cleanup_effects —
	# вовсе не наносить урон (shutdown-гард), не задевая мёртвые VFX.

	# Якорь: VFX рвутся ДО удара, но полный ролл всё равно должен лечь.
	var anchor_holder := _new_scene("Scrum1034AnchorTeardown")
	var anchor_owner := _new_owner(anchor_holder)
	var anchor_weapon := _new_weapon(anchor_owner, "robot", "robot_magnetic_anchor")
	var anchor_center := anchor_owner.global_position + Vector2(400, 0)
	var anchor_target := _new_enemy(anchor_holder, anchor_center)
	await process_frame
	anchor_weapon.call("_fire_robot_magnetic_anchor", anchor_owner, anchor_target, Vector2.RIGHT)
	await _free_all_weapon_effects()
	await create_timer(maxf(float(anchor_weapon.get("grenade_delay")), 0.08) + 0.30).timeout
	if anchor_target.hit_count != 1 or absf(anchor_target.total_damage - 100.0) > 0.5:
		errors.append("anchor delayed hit must still land after its VFX are torn down (hits %d, dmg %.2f)" % [anchor_target.hit_count, anchor_target.total_damage])
	if not is_instance_valid(anchor_weapon):
		errors.append("anchor weapon must survive its delayed callback")
	await _cleanup(anchor_holder)

	# Пресс: боковые телеграфы рвутся ДО удара, коридорный урон всё равно ложится.
	var press_holder := _new_scene("Scrum1034PressTeardown")
	var press_owner := _new_owner(press_holder)
	var press_weapon := _new_weapon(press_owner, "robot", "robot_hydraulic_press")
	var press_origin := press_owner.global_position + Vector2(28, 0)
	var press_target := _new_enemy(press_holder, press_origin + Vector2(300, 90))
	await process_frame
	press_weapon.call("_fire_robot_compression_line", press_owner, null, Vector2.RIGHT)
	await _free_all_weapon_effects()
	await create_timer(maxf(float(press_weapon.get("grenade_delay")), 0.08) + 0.30).timeout
	if press_target.hit_count != 1 or absf(press_target.total_damage - 100.0) > 0.5:
		errors.append("press delayed corridor hit must still land after its VFX are torn down (hits %d, dmg %.2f)" % [press_target.hit_count, press_target.total_damage])
	if not is_instance_valid(press_weapon):
		errors.append("press weapon must survive its delayed callback")
	await _cleanup(press_holder)

	# Shutdown-гард: после cleanup_effects отложенный удар НЕ наносится и не лезет
	# в освобождённые узлы (старый лямбда-колбэк без shutdown-гарда ударил бы).
	var shut_holder := _new_scene("Scrum1034ShutdownGuard")
	var shut_owner := _new_owner(shut_holder)
	var shut_weapon := _new_weapon(shut_owner, "robot", "robot_magnetic_anchor")
	var shut_center := shut_owner.global_position + Vector2(400, 0)
	var shut_target := _new_enemy(shut_holder, shut_center)
	await process_frame
	shut_weapon.call("_fire_robot_magnetic_anchor", shut_owner, shut_target, Vector2.RIGHT)
	shut_weapon.call("cleanup_effects")
	await _free_all_weapon_effects()
	await create_timer(maxf(float(shut_weapon.get("grenade_delay")), 0.08) + 0.30).timeout
	if shut_target.hit_count != 0:
		errors.append("delayed anchor must not fire after cleanup_effects tears the weapon down (hits %d)" % shut_target.hit_count)
	if not is_instance_valid(shut_weapon):
		errors.append("weapon must stay valid through the shutdown-guarded callback")
	await _cleanup(shut_holder)
