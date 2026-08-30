extends SceneTree

# SCRUM-939/940/941/1007: фокусный тест кита Тёмного мага.
#
#   SCRUM-939 dark_wand (dark_chain_burst):
#     - цепь бьёт до 3 РАЗНЫХ целей (первая + 2 рикошета в ближайших валидных),
#       урон спадает по прыжкам, лишние цели за пределами лимита не задеваются;
#     - повторных хитов одной цели нет: одна цель на арене = ровно 1 прямой хит
#       (документированный fallback — цепь обрывается, а не отскакивает назад);
#     - каждое попадание рождает малый AoE-бурст по СОСЕДЯМ жертвы (сама жертва
#       бурстом не задевается), бурст магический.
#   SCRUM-940 cursed_skull (skull_curse_burn):
#     - только dot-тики: ни одного не-"dot" хита за весь прожиг;
#     - каденция и сумма: ровно dot_ticks тиков за каст, тик = dot_damage *
#       curse_tick_multiplier; скейл от dot_damage есть, от magic_damage — НЕТ;
#     - зона выбирает цели по aoe_radius; refresh не стакует (1 стак).
#   SCRUM-941 dark_book (dark_mirror_blast):
#     - зеркальная геометрия детерминирована: M = 2*owner - P для горизонтали,
#       вертикали и диагонали; оба взрыва бьют одинаково (mirror_ratio 1.0);
#     - враг, накрытый обеими зонами, легально получает ДВА удара.
#   SCRUM-1007 trait «Тёмный распад» (player._trigger_class_on_kill_trait):
#     - kill обычным player-owned хитом => ровно ОДИН магический взрыв;
#     - kill взрывом распада (dark_decay) => НОВОГО взрыва НЕТ — плотная группа
#       не цепляет каскад (анти-рекурсия);
#     - kill без атрибуции игрока и kill чужим классом => взрыва нет.
#
# Запуск: Godot --headless --path . --script res://tests/dark_mage_kit_test.gd

const ClassWeapon := preload("res://scripts/class_weapon.gd")
const PD := preload("res://scripts/progression_data.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")

const EPS := 0.001


class MockOwner extends CharacterBody2D:
	var derived_parameters := {
		"damage": 100.0,
		"magic_damage": 100.0,
		"crit_chance": 0.0,
		"crit_damage_multiplier": 1.0,
		"dot_damage": 10.0,
		"dot_speed": 1.0,
	}
	var run_modifiers := {}
	var stats := {}
	var health := 70.0
	var max_health := 100.0
	var curse_charge_feed := 0.0

	func heal_percent_capped(percent: float) -> void:
		health = minf(max_health, health + max_health * percent)

	func heal_percent(percent: float) -> void:
		heal_percent_capped(percent)

	func on_curse_applied(expected_burn: float) -> void:
		curse_charge_feed += expected_burn


# Feedback-capable мок (группа enemies + _show_combat_feedback => оружие шлёт
# take_damage(amount, feedback), и тест видит типы/атрибуцию каждого хита).
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

	func hits_of_type(damage_type: String) -> int:
		var count := 0
		for hit in hits:
			if str((hit["feedback"] as Dictionary).get("damage_type", "")) == damage_type:
				count += 1
		return count


func _initialize() -> void:
	var errors: Array = []
	await _test_wand_chain_targets_and_decay(errors)
	await _test_wand_no_repeat_and_burst(errors)
	await _test_skull_curse_only_and_cadence(errors)
	await _test_skull_scaling_and_refresh(errors)
	await _test_book_mirror_geometry(errors)
	await _test_book_double_hit_overlap(errors)
	await _test_freed_visual_callbacks_noop(errors)
	await _test_dark_decay_trait(errors)
	await _test_dark_decay_secondary_paths_unowned(errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Dark mage kit: %s" % str(error))
		push_error("Dark mage kit test failed with %d error(s)." % errors.size())
		quit(1)
		return
	print("Dark mage kit test passed (SCRUM-939/940/941/1007).")
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
	# Гвоздь от авто-атак: движок может заново включить _process в первый кадр
	# после set_process(false) (латентный quirk), поэтому дополнительно
	# замораживаем кулдаун — тест стреляет только явными вызовами _fire_*.
	weapon.set_process(false)
	weapon.set("_cooldown", 1.0e9)
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


# --- SCRUM-939 ---------------------------------------------------------------


func _test_wand_chain_targets_and_decay(errors: Array) -> void:
	var holder := _new_scene("Scrum939ChainTargets")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "dark_mage", "dark_wand")
	# Линия с шагом 150 (> бурст-радиуса 90): бурсты не перекрещиваются, прямые
	# хиты изолированы. Четвёртая цель в hop-range третьей, но за лимитом цепи.
	var first := _new_enemy(holder, owner.global_position + Vector2(150, 0))
	var second := _new_enemy(holder, first.global_position + Vector2(150, 0))
	var third := _new_enemy(holder, second.global_position + Vector2(150, 0))
	var fourth_in_range := _new_enemy(holder, third.global_position + Vector2(150, 0))
	await process_frame

	weapon.call("_fire_dark_chain_burst", owner, first, Vector2.RIGHT)
	await create_timer(1.1).timeout

	var falloff: float = clampf(float(weapon.get("pierce_damage_falloff")), 0.1, 1.0)
	if first.hit_count != 1 or second.hit_count != 1 or third.hit_count != 1:
		errors.append("chain must hit exactly 3 distinct targets once each (%d/%d/%d)" % [first.hit_count, second.hit_count, third.hit_count])
	if fourth_in_range.hit_count != 0:
		errors.append("chain must stop at chain_targets=3 even with a 4th valid enemy (hits %d)" % fourth_in_range.hit_count)
	if absf(first.total_damage - 100.0) > 0.5:
		errors.append("first chain hit should equal rolled damage (got %.3f)" % first.total_damage)
	if absf(second.total_damage - 100.0 * falloff) > 0.5 or absf(third.total_damage - 100.0 * pow(falloff, 2.0)) > 0.5:
		errors.append("chain damage must decay by pierce_damage_falloff per hop (%.3f, %.3f)" % [second.total_damage, third.total_damage])
	if first.hits_of_type("magic") != first.hit_count:
		errors.append("chain hits must be magic-typed")
	await _cleanup(holder)


func _test_wand_no_repeat_and_burst(errors: Array) -> void:
	# Fallback одной цели: цепь обрывается, повторного хита той же цели НЕТ.
	var solo_holder := _new_scene("Scrum939ChainSoloFallback")
	var solo_owner := _new_owner(solo_holder)
	var solo_weapon := _new_weapon(solo_owner, "dark_mage", "dark_wand")
	var lone := _new_enemy(solo_holder, solo_owner.global_position + Vector2(180, 0))
	await process_frame

	solo_weapon.call("_fire_dark_chain_burst", solo_owner, lone, Vector2.RIGHT)
	await create_timer(0.8).timeout
	if lone.hit_count != 1:
		errors.append("single-target fallback must end the chain after 1 hit, no repeats (hits %d)" % lone.hit_count)
	await _cleanup(solo_holder)

	# Бурст: сосед жертвы в aoe_radius получает долю урона хита; сама жертва
	# бурстом не задевается (ровно один прямой хит).
	var burst_holder := _new_scene("Scrum939ChainBurst")
	var burst_owner := _new_owner(burst_holder)
	var burst_weapon := _new_weapon(burst_owner, "dark_mage", "dark_wand")
	burst_weapon.set("chain_targets", 1)  # изолируем бурст первой цели
	var victim := _new_enemy(burst_holder, burst_owner.global_position + Vector2(200, 0))
	var neighbor := _new_enemy(burst_holder, victim.global_position + Vector2(float(burst_weapon.get("aoe_radius")) * 0.6, 0))
	await process_frame

	burst_weapon.call("_fire_dark_chain_burst", burst_owner, victim, Vector2.RIGHT)
	await create_timer(0.6).timeout
	var burst_ratio := float(burst_weapon.get("chain_burst_ratio"))
	if victim.hit_count != 1:
		errors.append("burst must not double-dip the direct-hit victim (hits %d)" % victim.hit_count)
	if neighbor.hit_count != 1 or absf(neighbor.total_damage - 100.0 * burst_ratio) > 0.5:
		errors.append("every chain hit must burst neighbors for chain_burst_ratio of the hit (hits %d, dmg %.3f)" % [neighbor.hit_count, neighbor.total_damage])
	if neighbor.hits_of_type("magic") != neighbor.hit_count:
		errors.append("chain burst damage must be magic-typed")
	await _cleanup(burst_holder)


func _test_freed_visual_callbacks_noop(errors: Array) -> void:
	var holder := _new_scene("DarkMageFreedVisualCallbacks")
	var owner := _new_owner(holder)
	var wand := _new_weapon(owner, "dark_mage", "dark_wand")
	var book := _new_weapon(owner, "dark_mage", "dark_book")
	var target := _new_enemy(holder, owner.global_position + Vector2(180, 0))
	# Free the real visual nodes before their tween callbacks run. This exercises
	# both Callable.bind argument conversion and the resolver no-op paths.
	wand._fire_dark_chain_burst(owner, target, Vector2.RIGHT)
	var chain_effects: Array = wand.get("_spawned_effects")
	if chain_effects.size() != 1:
		errors.append("dark chain must create one visual for freed-callback coverage")
	else:
		(chain_effects[0] as Node).queue_free()

	book._fire_dark_mirror_blast(owner, target, Vector2.RIGHT)
	var mirror_effects: Array = book.get("_spawned_effects")
	if mirror_effects.size() != 2:
		errors.append("dark mirror must create two visuals for freed-callback coverage")
	else:
		for effect in mirror_effects:
			(effect as Node).queue_free()

	await create_timer(0.6).timeout
	if target.hit_count != 0:
		errors.append("freed Dark Mage visuals must not resolve delayed damage")
	await _cleanup(holder)

	# Use a separate empty scene so the no-target branch cannot discover the
	# chain/mirror target above.
	var miss_holder := _new_scene("DarkMageFreedMissCallback")
	var miss_owner := _new_owner(miss_holder)
	var miss_wand := _new_weapon(miss_owner, "dark_mage", "dark_wand")
	await process_frame
	miss_wand._fire_dark_chain_burst(miss_owner, null, Vector2.RIGHT)
	var miss_effects: Array = miss_wand.get("_spawned_effects")
	if miss_effects.size() != 1:
		errors.append("dark chain miss must create one visual for freed-callback coverage")
	else:
		(miss_effects[0] as Node).queue_free()
	await create_timer(0.3).timeout
	await _cleanup(miss_holder)


# --- SCRUM-940 ---------------------------------------------------------------


func _test_skull_curse_only_and_cadence(errors: Array) -> void:
	var holder := _new_scene("Scrum940CurseOnly")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "dark_mage", "cursed_skull")
	var zone_radius := float(weapon.get("aoe_radius"))
	var primary := _new_enemy(holder, owner.global_position + Vector2(220, 0))
	var inside := _new_enemy(holder, primary.global_position + Vector2(zone_radius * 0.55, 0))
	var outside := _new_enemy(holder, primary.global_position + Vector2(zone_radius * 2.5, 0))
	await process_frame

	weapon.call("_fire_skull_curse_burn", owner, primary, Vector2.RIGHT)
	await create_timer(0.3).timeout

	if primary.total_damage > EPS or inside.total_damage > EPS:
		errors.append("skull impact must deal no direct damage (%.3f / %.3f)" % [primary.total_damage, inside.total_damage])
	if not StatusEffects.has_status(primary, "skull_curse") or not StatusEffects.has_status(inside, "skull_curse"):
		errors.append("all enemies inside the zone must be cursed")
	if StatusEffects.has_status(outside, "skull_curse"):
		errors.append("enemies outside aoe_radius must not be cursed")
	if owner.curse_charge_feed <= 0.0:
		errors.append("curse application must feed ultimate charge hook (on_curse_applied)")

	# Полный прожиг: dot_ticks тиков по dot_damage*curse_tick_multiplier, все "dot".
	var ticks := int(weapon.get("dot_ticks"))
	var expected_tick := 10.0 * float(weapon.get("curse_tick_multiplier"))
	for _frame in range(30):
		StatusEffects.tick(primary, 0.1)
	if primary.hit_count != ticks:
		errors.append("curse must tick exactly dot_ticks times per cast (got %d, want %d)" % [primary.hit_count, ticks])
	if absf(primary.total_damage - expected_tick * float(ticks)) > 0.5:
		errors.append("curse burn total must equal dot_damage*mult*ticks (got %.3f)" % primary.total_damage)
	if primary.hits_of_type("dot") != primary.hit_count:
		errors.append("curse-only: every skull hit must be dot-typed, no magic/physical")
	# Каденция: dot_speed=1.0 -> интервал 1/curse_tick_rate ~ 0.143с (быстрые тики):
	# за 0.32с должно пройти минимум 2 тика.
	var cadence_probe := _new_enemy(holder, primary.global_position + Vector2(20, 0))
	await process_frame
	weapon.call("_apply_skull_curse_zone", cadence_probe.global_position)
	for _frame in range(3):
		StatusEffects.tick(cadence_probe, 0.107)
	if cadence_probe.hit_count < 2:
		errors.append("curse ticks must be fast (>=2 ticks in ~0.32s at base dot_speed), got %d" % cadence_probe.hit_count)
	await _cleanup(holder)


func _test_skull_scaling_and_refresh(errors: Array) -> void:
	var holder := _new_scene("Scrum940CurseScaling")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "dark_mage", "cursed_skull")

	# Скейл: dot_damage x2 => тик x2; magic_damage x3 => тик НЕ меняется.
	var dot_probe := _new_enemy(holder, owner.global_position + Vector2(200, 0))
	await process_frame
	owner.derived_parameters["dot_damage"] = 20.0
	owner.derived_parameters["magic_damage"] = 300.0
	weapon.call("_apply_skull_curse_zone", dot_probe.global_position)
	StatusEffects.tick(dot_probe, 0.15)
	var expected_scaled := 20.0 * float(weapon.get("curse_tick_multiplier"))
	if dot_probe.hit_count < 1 or absf(float(dot_probe.hits[0]["amount"]) - expected_scaled) > 0.5:
		errors.append("curse tick must scale with dot_damage and ignore magic_damage (tick %.3f, want %.3f)" % [float(dot_probe.hits[0]["amount"]) if dot_probe.hit_count > 0 else -1.0, expected_scaled])
	owner.derived_parameters["dot_damage"] = 10.0
	owner.derived_parameters["magic_damage"] = 100.0

	# Refresh: повторный каст не стакует — 1 стак, тик не удваивается.
	var refresh_probe := _new_enemy(holder, owner.global_position + Vector2(-260, 0))
	await process_frame
	weapon.call("_apply_skull_curse_zone", refresh_probe.global_position)
	weapon.call("_apply_skull_curse_zone", refresh_probe.global_position)
	var status: Dictionary = StatusEffects.snapshot(refresh_probe).get("skull_curse", {})
	if int(status.get("stacks", 0)) != 1:
		errors.append("recast must refresh, not stack (stacks %d)" % int(status.get("stacks", 0)))
	StatusEffects.tick(refresh_probe, 0.15)
	var single_tick := 10.0 * float(weapon.get("curse_tick_multiplier"))
	if refresh_probe.hit_count >= 1 and absf(float(refresh_probe.hits[0]["amount"]) - single_tick) > 0.5:
		errors.append("refreshed curse tick must stay single-stack sized (%.3f, want %.3f)" % [float(refresh_probe.hits[0]["amount"]), single_tick])
	await _cleanup(holder)


# --- SCRUM-941 ---------------------------------------------------------------


func _test_book_mirror_geometry(errors: Array) -> void:
	var holder := _new_scene("Scrum941MirrorGeometry")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "dark_mage", "dark_book")
	var radius := float(weapon.get("aoe_radius"))

	# Горизонталь: цель справа, зеркальная жертва строго слева на той же дистанции.
	var target_right := _new_enemy(holder, owner.global_position + Vector2(250, 0))
	var mirror_left := _new_enemy(holder, owner.global_position + Vector2(-250, 0))
	# Контроль: вне обеих зон (250 по вертикали от центра каждой зоны > radius).
	var far_probe := _new_enemy(holder, owner.global_position + Vector2(0, 420))
	await process_frame

	weapon.call("_launch_dark_mirror_pair", owner, target_right.global_position)
	await create_timer(0.7).timeout
	if target_right.hit_count != 1 or mirror_left.hit_count != 1:
		errors.append("horizontal cast must produce primary and mirrored blasts (%d/%d)" % [target_right.hit_count, mirror_left.hit_count])
	elif absf(target_right.total_damage - mirror_left.total_damage) > 0.5:
		errors.append("mirror blast must deal symmetric damage (%.3f vs %.3f)" % [target_right.total_damage, mirror_left.total_damage])
	if far_probe.hit_count != 0:
		errors.append("blasts must stay bounded by aoe_radius (far probe hit %d)" % far_probe.hit_count)
	if target_right.hits_of_type("magic") != target_right.hit_count or mirror_left.hits_of_type("magic") != mirror_left.hit_count:
		errors.append("both book blasts must be magic-typed")
	await _cleanup(holder)

	# Вертикаль и диагональ: M = 2*owner - P.
	var axes := [Vector2(0, 260), Vector2(210, 210)]
	for axis_offset in axes:
		var axis_holder := _new_scene("Scrum941MirrorAxis")
		var axis_owner := _new_owner(axis_holder)
		var axis_weapon := _new_weapon(axis_owner, "dark_mage", "dark_book")
		var axis_target := _new_enemy(axis_holder, axis_owner.global_position + axis_offset)
		var axis_mirror := _new_enemy(axis_holder, axis_owner.global_position - axis_offset)
		await process_frame
		axis_weapon.call("_launch_dark_mirror_pair", axis_owner, axis_target.global_position)
		await create_timer(0.7).timeout
		if axis_target.hit_count != 1 or axis_mirror.hit_count != 1:
			errors.append("mirror geometry must hold for offset %s (%d/%d)" % [axis_offset, axis_target.hit_count, axis_mirror.hit_count])
		await _cleanup(axis_holder)
	# Радиус зоны не участвует в выборе зеркальной точки — вблизи границ арены
	# геометрия та же (зеркальная точка может лежать за краем, взрыв валиден).
	if radius <= 0.0:
		errors.append("book must define a positive aoe radius")


func _test_book_double_hit_overlap(errors: Array) -> void:
	var holder := _new_scene("Scrum941MirrorOverlap")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "dark_mage", "dark_book")
	# Цель почти вплотную: обе зоны перекрывают её позицию => двойной удар —
	# явно определённое поведение (см. описание оружия/доки).
	var close_enemy := _new_enemy(holder, owner.global_position + Vector2(40, 0))
	await process_frame

	weapon.call("_launch_dark_mirror_pair", owner, close_enemy.global_position)
	await create_timer(0.7).timeout
	if close_enemy.hit_count != 2:
		errors.append("enemy inside both zones must take exactly two blasts (got %d)" % close_enemy.hit_count)
	await _cleanup(holder)


# --- SCRUM-1007 ---------------------------------------------------------------


func _test_dark_decay_trait(errors: Array) -> void:
	var holder := _new_scene("Scrum1007DarkDecay")
	var player := PLAYER_SCENE.instantiate()
	holder.add_child(player)
	player.add_to_group("player")
	player.global_position = Vector2(900, 700)
	await process_frame
	player.call("configure_character", "dark_mage", "dark_wand")
	_mute_equipped_weapon(player)  # авто-атаки не должны трогать постановку
	await process_frame
	# SCRUM-1007: trait живёт data-driven записью в каноническом реестре
	# CLASS_TRAITS (паттерн SCRUM-935), on-kill ключи generic.
	var trait_config: Dictionary = PD.class_trait("dark_mage")
	if trait_config.is_empty() or str(trait_config.get("id", "")) != "dark_decay":
		errors.append("dark_mage must expose the dark_decay trait via the CLASS_TRAITS registry")
		await _cleanup(holder)
		return
	var trait_radius := float(trait_config.get("on_kill_blast_radius", 0.0))
	var expected_blast := float((player.get("derived_parameters") as Dictionary).get("magic_damage", 0.0)) * float(trait_config.get("on_kill_blast_magic_ratio", 0.0))
	if trait_radius <= 0.0 or expected_blast <= 0.0:
		errors.append("trait radius/damage must be positive (r %.1f, dmg %.2f)" % [trait_radius, expected_blast])

	# Плотная группа: жертва + 2 соседа в радиусе распада + свидетель поодаль
	# (уверенно ВНУТРИ радиуса распада от n1, но вне взрыва жертвы).
	var victim := _spawn_real_enemy(holder, Vector2(1100, 700), 10.0)
	var n1 := _spawn_real_enemy(holder, Vector2(1100 + trait_radius * 0.5, 700), 1.0)
	var n2 := _spawn_real_enemy(holder, Vector2(1100, 700 + trait_radius * 0.5), 1.0)
	var witness := _spawn_real_enemy(holder, Vector2(1100 + trait_radius * 1.3, 700), 100000.0)
	await process_frame

	var witness_hp_before := float(witness.get("health"))
	# Kill обычным player-owned хитом (маршрут оружия: take_damage с feedback).
	victim.call("take_damage", 99999.0, {"damage_type": "magic", "player_owned": true})
	if float(victim.get("health")) > 0.0:
		errors.append("setup: victim must die from the tagged hit")
	player.call("on_enemy_killed", victim)

	# Ровно один взрыв: соседи (HP 1) убиты распадом с меткой dark_decay.
	if float(n1.get("health")) > 0.0 or float(n2.get("health")) > 0.0:
		errors.append("dark decay blast must kill low-hp neighbors in radius (%.2f / %.2f)" % [float(n1.get("health")), float(n2.get("health"))])
	var n1_attribution: Dictionary = n1.get_meta("killing_hit_feedback") if n1.has_meta("killing_hit_feedback") else {}
	if not bool(n1_attribution.get("dark_decay", false)):
		errors.append("decay blast kills must carry the dark_decay non-recursion marker")

	# Анти-рекурсия: смерти соседей от взрыва НЕ порождают новых взрывов —
	# свидетель внутри их потенциального радиуса остаётся нетронутым.
	player.call("on_enemy_killed", n1)
	player.call("on_enemy_killed", n2)
	if absf(float(witness.get("health")) - witness_hp_before) > EPS:
		errors.append("dense group must not chain explosions (witness hp %.2f -> %.2f)" % [witness_hp_before, float(witness.get("health"))])

	# Неатрибутированный kill (без player_owned) => взрыва нет.
	var plain_victim := _spawn_real_enemy(holder, Vector2(600, 700), 10.0)
	var plain_probe := _spawn_real_enemy(holder, Vector2(600 + trait_radius * 0.5, 700), 100000.0)
	await process_frame
	var plain_probe_hp := float(plain_probe.get("health"))
	plain_victim.call("take_damage", 99999.0, {"damage_type": "physical"})
	player.call("on_enemy_killed", plain_victim)
	if absf(float(plain_probe.get("health")) - plain_probe_hp) > EPS:
		errors.append("kills without player attribution must not trigger the trait")

	# Чужой класс: у солдата trait-конфига нет — взрыв не срабатывает.
	var soldier := PLAYER_SCENE.instantiate()
	holder.add_child(soldier)
	soldier.global_position = Vector2(300, 700)
	await process_frame
	soldier.call("configure_character", "soldier", "soldier_rifle")
	_mute_equipped_weapon(soldier)
	await process_frame
	var foreign_victim := _spawn_real_enemy(holder, Vector2(400, 700), 10.0)
	var foreign_probe := _spawn_real_enemy(holder, Vector2(400 + trait_radius * 0.5, 700), 100000.0)
	await process_frame
	var foreign_probe_hp := float(foreign_probe.get("health"))
	foreign_victim.call("take_damage", 99999.0, {"damage_type": "physical", "player_owned": true})
	soldier.call("on_enemy_killed", foreign_victim)
	if absf(float(foreign_probe.get("health")) - foreign_probe_hp) > EPS:
		errors.append("non-dark-mage classes must not gain the on-kill explosion")

	soldier.queue_free()
	player.queue_free()
	await _cleanup(holder)


# --- FAN-1545: telemetry не синтезирует player_owned на вторичных путях --------
# Регресс FAN-1545 (telemetry-репейр FAN-1539): новый helper безусловно помечал
# вторичные пути (thorn reflect, echo, enchant, DoT-тик и т.п.) как
# player_owned=true, из-за чего их убийства ложно квалифицировали on-kill trait
# «Тёмный распад». Здесь прогоняем НАСТОЯЩИЕ функции вторичных путей и проверяем,
# что их kill НЕ помечен player_owned, НЕ запускает распад и НЕ двигает
# HP-свидетеля; при этом owned weapon/ульта-путь всё ещё квалифицирует распад.
func _test_dark_decay_secondary_paths_unowned(errors: Array) -> void:
	var holder := _new_scene("Fan1545SecondaryUnowned")
	var player := PLAYER_SCENE.instantiate()
	holder.add_child(player)
	player.add_to_group("player")
	player.global_position = Vector2(900, 700)
	await process_frame
	player.call("configure_character", "dark_mage", "dark_wand")
	_mute_equipped_weapon(player)
	await process_frame

	var trait_config: Dictionary = PD.class_trait("dark_mage")
	var trait_radius := float(trait_config.get("on_kill_blast_radius", 0.0))
	if trait_radius <= 0.0:
		errors.append("setup: dark_mage decay radius must be positive")
		await _cleanup(holder)
		return

	# (a) THORN REFLECT — реальный путь _trigger_thorn_reflect. victim стоит в
	# радиусе рефлекта игрока (<=200px). Детекторы распада (probe низкого HP и
	# высокоживучий witness) — ВНУТРИ радиуса распада от victim, но ВНЕ 200px
	# рефлекта, чтобы сам рефлект их не задел. Базовое поведение: рефлект
	# неатрибутирован → распада нет → детекторы нетронуты.
	var reflect_victim := _spawn_real_enemy(holder, Vector2(1099, 700), 10.0)  # dist 199 от игрока
	var reflect_probe := _spawn_real_enemy(holder, Vector2(1099 + trait_radius * 0.5, 700), 1.0)
	var reflect_witness := _spawn_real_enemy(holder, Vector2(1099, 760), 100000.0)
	await process_frame
	if player.global_position.distance_to(reflect_probe.global_position) <= 200.0 or player.global_position.distance_to(reflect_witness.global_position) <= 200.0:
		errors.append("setup: decay detectors must sit outside the 200px thorn-reflect range")
	var reflect_rm: Dictionary = player.get("run_modifiers")
	reflect_rm["thorn_reflect_multiplier"] = 2.0
	var reflect_witness_hp := float(reflect_witness.get("health"))
	player.call("_trigger_thorn_reflect", 100.0)  # reflected = 200 -> убивает victim (HP 10)
	if float(reflect_victim.get("health")) > 0.0:
		errors.append("setup: thorn reflect must kill the in-range victim")
	var reflect_attr: Dictionary = reflect_victim.get_meta("killing_hit_feedback") if reflect_victim.has_meta("killing_hit_feedback") else {}
	if bool(reflect_attr.get("player_owned", false)):
		errors.append("thorn-reflect kill must NOT be tagged player_owned (telemetry must not synthesize ownership)")
	player.call("on_enemy_killed", reflect_victim)
	if float(reflect_probe.get("health")) <= 0.0:
		errors.append("thorn-reflect secondary kill must not trigger Dark Decay (probe died)")
	if absf(float(reflect_witness.get("health")) - reflect_witness_hp) > EPS:
		errors.append("thorn-reflect secondary kill must not move the HP witness (%.2f -> %.2f)" % [reflect_witness_hp, float(reflect_witness.get("health"))])

	# (b) Второй ранее-unowned путь: универсальный DoT-тик (_apply_dot_tick).
	var dot_victim := _spawn_real_enemy(holder, Vector2(500, 700), 10.0)
	var dot_probe := _spawn_real_enemy(holder, Vector2(500 + trait_radius * 0.5, 700), 1.0)
	await process_frame
	player.call("_apply_dot_tick", dot_victim.get_instance_id(), 99999.0)
	if float(dot_victim.get("health")) > 0.0:
		errors.append("setup: universal DoT-tick must kill the victim")
	var dot_attr: Dictionary = dot_victim.get_meta("killing_hit_feedback") if dot_victim.has_meta("killing_hit_feedback") else {}
	if bool(dot_attr.get("player_owned", false)):
		errors.append("universal DoT-tick kill must NOT be tagged player_owned")
	player.call("on_enemy_killed", dot_victim)
	if float(dot_probe.get("health")) <= 0.0:
		errors.append("universal DoT-tick secondary kill must not trigger Dark Decay (probe died)")

	# (c) Meta-crit execute — отдельный direct secondary path с gameplay feedback,
	# но без ownership. Его kill тоже не должен запускать Dark Decay.
	var execute_victim := _spawn_real_enemy(holder, Vector2(700, 900), 10.0)
	var execute_probe := _spawn_real_enemy(holder, Vector2(700 + trait_radius * 0.5, 900), 1.0)
	await process_frame
	var execute_rm: Dictionary = player.get("run_modifiers")
	execute_rm["crit_execute_threshold"] = 1.0
	player.call("_apply_meta_crit_execute", execute_victim, {"critical": true, "damage_type": "physical"})
	if float(execute_victim.get("health")) > 0.0:
		errors.append("setup: meta-crit execute must kill the eligible victim")
	var execute_attr: Dictionary = execute_victim.get_meta("killing_hit_feedback") if execute_victim.has_meta("killing_hit_feedback") else {}
	if bool(execute_attr.get("player_owned", false)):
		errors.append("meta-crit execute kill must NOT be tagged player_owned")
	player.call("on_enemy_killed", execute_victim)
	if float(execute_probe.get("health")) <= 0.0:
		errors.append("meta-crit execute secondary kill must not trigger Dark Decay (probe died)")

	# (d) Позитивный контроль: owned weapon/ульта-style kill всё ещё квалифицирует
	# распад — фикс не должен зарубить легитимную атрибуцию.
	var owned_victim := _spawn_real_enemy(holder, Vector2(300, 900), 10.0)
	var owned_probe := _spawn_real_enemy(holder, Vector2(300 + trait_radius * 0.5, 900), 1.0)
	await process_frame
	owned_victim.call("take_damage", 99999.0, {"damage_type": "magic", "player_owned": true})
	player.call("on_enemy_killed", owned_victim)
	if float(owned_probe.get("health")) > 0.0:
		errors.append("owned weapon/ultimate kill must still qualify Dark Decay (probe survived)")

	player.queue_free()
	await _cleanup(holder)


func _mute_equipped_weapon(player: Node) -> void:
	var weapon = player.get("equipped_weapon")
	if weapon is Node:
		(weapon as Node).set_process(false)
		(weapon as Node).set("_cooldown", 1.0e9)


func _spawn_real_enemy(holder: Node2D, position: Vector2, health: float) -> Node2D:
	var enemy := ENEMY_SCENE.instantiate() as Node2D
	holder.add_child(enemy)
	enemy.global_position = position
	enemy.set("max_health", maxf(health, 1.0))
	enemy.set("health", health)
	enemy.set("move_speed", 0.0)
	enemy.set("contact_damage", 0.0)
	enemy.set_physics_process(false)
	return enemy
