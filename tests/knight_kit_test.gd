extends SceneTree

# SCRUM-920..923: фокусный гейт редизайна кита Рыцаря («Возмездие»).
#
# Trait «Возмездие» (SCRUM-920, CLASS_TRAITS.knight): КОНТАКТНЫЙ удар по Рыцарю
#   отбрасывает атакующего прочь (импульс retaliation_knockback=760 ⇒ смещение
#   ≈ v²/4800 ≈ 120px > типового contact_range — серия тычков рвётся). Боссы и
#   главные элиты НЕ смещаются, мини-элиты волн отлетают как обычные монстры
#   (CombatTargetQuery.is_epic_displacement_immune). Внутренний кулдаун
#   retaliation_cooldown=0.4с; другим классам не течёт; предотвращённые удары
#   (i-frames и пр.) отброса не дают. Атакующего передаёт ТОЛЬКО контактный путь
#   enemy._update_contact_damage (3-й аргумент take_damage).
# «Копьё» (SCRUM-921, thrust_count=3): цикл = три БЫСТРЫХ последовательных укола
#   лево→центр→право под ±thrust_fan_degrees(16°) с окном thrust_step_time(0.11с);
#   полоса шире старой (90→110). Дедуп на весь цикл: одна цель ≤ 1 укола
#   (анти-triple-dip, budget solo_hits=1.0). Артефакт «Веер уколов»
#   (spear_triple_thrust) добавляет два КРАЙНИХ укола ±32° на 55%.
# «Башенный щит» (SCRUM-922): конус 95° в НАПРАВЛЕНИИ ближайшего монстра; все
#   цели конуса получают урон и отброс прочь от Рыцаря. Импульс =
#   (260 + knockback×stagger_knockback_stat_ratio(3.0)) × 1.15 — скейл от
#   вложений в отброс (derived knockback_power через свойство knockback).
#   Боссы/главные элиты капятся ×epic_stagger_knockback_factor(0.25).
# «Кистень» (SCRUM-923, spiral_steps=7): урон идёт ОТ ЦЕНТРА НАРУЖУ — фронт-дуга
#   150° делает полный оборот за каст, радиус фронта растёт 22%→100% aoe_radius;
#   максимум ОДИН хит по цели за каст; последний шаг замыкает оборот на стартовом
#   угле с полным радиусом (соло-цель гарантированно накрыта к концу).
#
# Запуск: Godot --headless --path . --script res://tests/knight_kit_test.gd

const PD := preload("res://scripts/progression_data.gd")
const BerserkWeaponScript := preload("res://scripts/berserk_weapon.gd")
const TQ := preload("res://scripts/combat_target_query.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")

const EPS := 0.01


class MockOwner extends CharacterBody2D:
	var run_modifiers := {}


# Feedback-capable мок (группа enemies + _show_combat_feedback ⇒ BerserkWeapon
# шлёт take_damage(amount, feedback) — тест видит тип и момент каждого хита).
class TypedEnemy extends Node2D:
	var total_damage := 0.0
	var hits: Array = []
	var impulses: Array = []

	func take_damage(amount: float, feedback: Dictionary = {}) -> void:
		total_damage += amount
		hits.append({
			"amount": amount,
			"type": str(feedback.get("damage_type", "")),
			"frame": Engine.get_process_frames(),
		})

	func apply_knockback(impulse: Vector2) -> void:
		impulses.append(impulse)

	func _show_combat_feedback(_amount: float = 0.0, _feedback: Dictionary = {}) -> void:
		pass

	# Прямые хиты оружия (с feedback-типом); 1-арг сплэши followup/close считаются отдельно.
	func typed_hit_count() -> int:
		var count := 0
		for hit in hits:
			if str((hit as Dictionary).get("type", "")) != "":
				count += 1
		return count

	func first_typed_frame() -> int:
		for hit in hits:
			if str((hit as Dictionary).get("type", "")) != "":
				return int((hit as Dictionary).get("frame", -1))
		return -1


func _initialize() -> void:
	var weapon_script: Script = BerserkWeaponScript
	if not weapon_script.can_instantiate():
		push_error("Knight kit: berserk_weapon.gd не компилируется — стенды мертвы, см. Parse Error выше.")
		quit(1)
		return
	var errors: Array = []
	_test_trait_registry_contract(errors)
	_test_kit_data_contracts(errors)
	_test_budget_mirrors(errors)
	await _test_retaliation_normal_enemy(errors)
	await _test_retaliation_contact_integration(errors)
	await _test_retaliation_taxonomy(errors)
	await _test_retaliation_cooldown(errors)
	await _test_retaliation_no_class_leak_and_prevented(errors)
	await _test_spear_triple_thrust_geometry_and_dedup(errors)
	await _test_spear_timed_order(errors)
	await _test_spear_fan_artifact(errors)
	await _test_shield_nearest_cone_and_knockback(errors)
	await _test_shield_knockback_scaling_and_epic_cap(errors)
	await _test_flail_spiral_progressive(errors)
	await _test_flail_full_turn_and_max_hits(errors)
	await _test_flail_timed_cast_and_cleanup(errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Knight kit: %s" % str(error))
		push_error("Knight kit test failed with %d error(s)." % errors.size())
		quit(1)
		return
	print("Knight kit test passed (SCRUM-920..923).")
	quit(0)


# --- Контракты данных ---


func _test_trait_registry_contract(errors: Array) -> void:
	var trait_config: Dictionary = PD.CLASS_TRAITS.get("knight", {})
	if trait_config.is_empty():
		errors.append("trait: нет записи CLASS_TRAITS.knight")
		return
	if str(trait_config.get("id", "")) != "retaliation":
		errors.append("trait: id '%s' != 'retaliation'" % str(trait_config.get("id", "")))
	if str(trait_config.get("title", "")) != "Возмездие":
		errors.append("trait: title '%s' != 'Возмездие'" % str(trait_config.get("title", "")))
	var impulse := float(trait_config.get("retaliation_knockback", 0.0))
	if impulse <= 0.0:
		errors.append("trait: retaliation_knockback должен быть > 0")
	# AC: смещение достаточно, чтобы рвать серию контактных ударов — аналитика
	# по декею enemy._consume_knockback (2400 px/s²): смещение = v²/4800.
	if impulse * impulse / 4800.0 < 90.0:
		errors.append("trait: импульс %.0f даёт смещение %.0fpx < 90px — контактную серию не рвёт" % [impulse, impulse * impulse / 4800.0])
	if float(trait_config.get("retaliation_cooldown", 0.0)) <= 0.0:
		errors.append("trait: retaliation_cooldown должен быть > 0 (документированный предохранитель)")


func _test_kit_data_contracts(errors: Array) -> void:
	var spear: Dictionary = PD.weapon("knight", "long_spear")
	if int(spear.get("thrust_count", 0)) != 3:
		errors.append("spear: thrust_count %d != 3" % int(spear.get("thrust_count", 0)))
	if float(spear.get("thrust_fan_degrees", 0.0)) <= 0.0:
		errors.append("spear: thrust_fan_degrees должен быть > 0")
	if float(spear.get("thrust_step_time", 0.0)) <= 0.0:
		errors.append("spear: thrust_step_time должен быть > 0 (уколы последовательные, не мгновенные)")
	if float(spear.get("inner_width", 0.0)) <= 90.0:
		errors.append("spear: полоса должна стать шире старых 90 (сейчас %.0f)" % float(spear.get("inner_width", 0.0)))
	if str(spear.get("attack_shape", "")) != "strip":
		errors.append("spear: attack_shape '%s' != 'strip' (веер полос, не конус)" % str(spear.get("attack_shape", "")))

	var shield: Dictionary = PD.weapon("knight", "tower_shield")
	if float(shield.get("stagger_knockback_stat_ratio", 0.0)) <= 0.0:
		errors.append("shield: stagger_knockback_stat_ratio должен быть > 0 (скейл отброса от вложений)")
	var epic_factor := float(shield.get("epic_stagger_knockback_factor", 1.0))
	if epic_factor < 0.0 or epic_factor >= 1.0:
		errors.append("shield: epic_stagger_knockback_factor %.2f должен капить эпиков (< 1.0)" % epic_factor)
	if float(shield.get("knockback", 0.0)) <= 0.0:
		errors.append("shield: нет базы knockback для derived knockback_power")
	if float(shield.get("damage_multiplier", 1.0)) >= float(spear.get("damage_multiplier", 1.0)):
		errors.append("shield: контроль-оружие должно бить слабее офф-копья")

	var flail: Dictionary = PD.weapon("knight", "holy_flail")
	if int(flail.get("spiral_steps", 0)) < 4:
		errors.append("flail: spiral_steps %d < 4 — спираль вырождается" % int(flail.get("spiral_steps", 0)))
	if float(flail.get("spiral_step_time", 0.0)) <= 0.0:
		errors.append("flail: spiral_step_time должен быть > 0")
	var start_ratio := float(flail.get("spiral_start_radius_ratio", 1.0))
	if start_ratio <= 0.0 or start_ratio >= 0.6:
		errors.append("flail: spiral_start_radius_ratio %.2f должен стартовать у центра (0..0.6)" % start_ratio)
	if float(flail.get("spiral_arm_degrees", 0.0)) < 360.0 / float(maxi(int(flail.get("spiral_steps", 1)), 1)) + 20.0:
		errors.append("flail: дуга фронта уже углового шага — оборот дырявый по углу")


func _test_budget_mirrors(errors: Array) -> void:
	# Бюджет-модель обязана зеркалить рантайм: дедуп уколов ⇒ solo_hits=1.0,
	# веер расширяет five_hits; спираль кроет диск с фактором 0.85.
	var spear_model: Dictionary = PD.estimate_weapon_budget("knight", PD.weapon("knight", "long_spear")).get("hit_model", {})
	if absf(float(spear_model.get("solo_hits", 0.0)) - 1.0) > EPS:
		errors.append("budget spear: solo_hits %.2f != 1.0 (дедуп цикла)" % float(spear_model.get("solo_hits", 0.0)))
	var expected_spear_five: float = clampf(1.0 + 110.0 / 160.0 + (540.0 * sin(deg_to_rad(16.0))) / 260.0, 1.0, 3.2)
	if absf(float(spear_model.get("five_hits", 0.0)) - expected_spear_five) > 0.02:
		errors.append("budget spear: five_hits %.3f != веерное покрытие %.3f" % [float(spear_model.get("five_hits", 0.0)), expected_spear_five])
	var flail_model: Dictionary = PD.estimate_weapon_budget("knight", PD.weapon("knight", "holy_flail")).get("hit_model", {})
	var expected_flail_five: float = clampf(1.0 + (235.0 / 72.0) * 0.85, 1.0, 5.0)
	if absf(float(flail_model.get("five_hits", 0.0)) - expected_flail_five) > 0.02:
		errors.append("budget flail: five_hits %.3f != спиральное покрытие %.3f" % [float(flail_model.get("five_hits", 0.0)), expected_flail_five])
	if float(flail_model.get("five_hits", 0.0)) >= 1.0 + 235.0 / 72.0 - EPS:
		errors.append("budget flail: спираль не должна считаться как мгновенный полный круг")


# --- Trait «Возмездие» ---


# FAN-2476: делает мутационную порчу пары raw_dodge/dodge (или raw_defense/
# defense) видимой ИМЕННО этой сюите, а не только aggregate-ратчету в
# tests/attribute_consumability_fan1887_test.gd. Возвращает "" при консистентной
# паре, иначе — человеко-читаемую причину.
func _raw_pair_defect(container: Dictionary, legacy_key: String, raw_key: String) -> String:
	if not container.has(raw_key):
		return "FAN-2474: '%s' отсутствует рядом с '%s' — raw/legacy контракт нарушен." % [raw_key, legacy_key]
	var raw_value := float(container[raw_key])
	var expected := PD.effective_dodge(raw_value) if legacy_key == "dodge" else PD.effective_defense(raw_value)
	var actual := float(container.get(legacy_key, 0.0))
	if absf(actual - expected) > EPS:
		return "FAN-2474: '%s'=%.4f != effective(%s=%.2f)=%.4f — raw/legacy разошлись." % [legacy_key, actual, raw_key, raw_value, expected]
	return ""


func _knight_bench(errors: Array, weapon_id := "tower_shield") -> Dictionary:
	var holder := Node2D.new()
	root.add_child(holder)
	var knight := PLAYER_SCENE.instantiate()
	holder.add_child(knight)
	knight.global_position = Vector2(620, 620)
	await process_frame
	knight.call("configure_character", "knight", weapon_id)
	var equipped: Node = knight.get("equipped_weapon")
	if equipped != null and is_instance_valid(equipped):
		equipped.set_process(false)
	var params: Dictionary = knight.get("derived_parameters")
	params["dodge"] = 0.0
	params["raw_dodge"] = 0.0
	params["defense"] = 0.0
	params["raw_defense"] = 0.0
	params["absorb"] = 0.0
	for defect in [_raw_pair_defect(params, "dodge", "raw_dodge"), _raw_pair_defect(params, "defense", "raw_defense")]:
		if defect != "":
			errors.append(defect)
	knight.set("derived_parameters", params)
	# Изоляция трейта от block/counter оружия (отдельный слой, свой тест ниже).
	knight.set("_knight_counter_cooldown_left", 999.0)
	return {"holder": holder, "knight": knight}


func _real_enemy(holder: Node2D, pos: Vector2, kind := "normal") -> Node2D:
	var enemy := ENEMY_SCENE.instantiate() as Node2D
	match kind:
		"mini_elite":
			enemy.add_to_group("elite_enemies")
			enemy.set_meta("epic_scale_profile", "mini_elite")
		"elite":
			enemy.add_to_group("elite_enemies")
		"boss":
			enemy.add_to_group("bosses")
	holder.add_child(enemy)
	enemy.global_position = pos
	enemy.set("move_speed", 0.0)
	enemy.set("max_health", 800.0)
	enemy.set("health", 800.0)
	return enemy


func _knockback_len(enemy: Node2D) -> float:
	var raw = enemy.get("_knockback_velocity")
	if raw is Vector2:
		return (raw as Vector2).length()
	return 0.0


func _test_retaliation_normal_enemy(errors: Array) -> void:
	var bench := await _knight_bench(errors)
	var knight: Node2D = bench["knight"]
	var attacker := _real_enemy(bench["holder"], knight.global_position + Vector2(-52.0, 0.0))
	await process_frame

	var landed: bool = knight.call("take_damage", 5.0, "contact", attacker)
	if not landed:
		errors.append("retaliation: контактный удар не прошёл (стенд сломан)")
	var raw = attacker.get("_knockback_velocity")
	var impulse: Vector2 = raw if raw is Vector2 else Vector2.ZERO
	var expected := float(PD.CLASS_TRAITS["knight"].get("retaliation_knockback", 0.0))
	if absf(impulse.length() - expected) > 1.0:
		errors.append("retaliation: импульс %.1f != trait %.1f" % [impulse.length(), expected])
	# Направление — ПРОЧЬ от Рыцаря в момент удара (атакующий слева ⇒ x < 0).
	if impulse.x >= 0.0 or absf(impulse.y) > 1.0:
		errors.append("retaliation: направление %s не «прочь от Рыцаря» (ожидался -X)" % str(impulse))
	# Смещение за время декея: атакующий обязан вылететь за контактную серию.
	var distance_before := knight.global_position.distance_to(attacker.global_position)
	for _i in range(36):
		await physics_frame
	var distance_after := knight.global_position.distance_to(attacker.global_position)
	if distance_after - distance_before < 60.0:
		errors.append("retaliation: смещение %.1fpx < 60px — контактный прессинг не прерван" % (distance_after - distance_before))
	bench["holder"].queue_free()
	await process_frame


func _test_retaliation_contact_integration(errors: Array) -> void:
	# Сквозная проверка проводки: enemy._update_contact_damage сам передаёт
	# себя атакующим 3-м аргументом take_damage.
	var bench := await _knight_bench(errors)
	var knight: Node2D = bench["knight"]
	var attacker := _real_enemy(bench["holder"], knight.global_position + Vector2(46.0, 0.0))
	await process_frame
	knight.set("_damage_invulnerability_left", 0.0)
	attacker.call("_update_contact_damage", 0.05, knight, 10.0)  # взводит windup
	attacker.call("_update_contact_damage", 0.5, knight, 10.0)   # наносит удар
	if _knockback_len(attacker) < 1.0:
		errors.append("retaliation: контактный путь enemy не отбросил атакующего (проводка attacker потеряна)")
	bench["holder"].queue_free()
	await process_frame


func _test_retaliation_taxonomy(errors: Array) -> void:
	var bench := await _knight_bench(errors)
	var knight: Node2D = bench["knight"]
	var cases := [
		{"kind": "mini_elite", "expect_knock": true, "label": "мини-элита"},
		{"kind": "elite", "expect_knock": false, "label": "главная элита"},
		{"kind": "boss", "expect_knock": false, "label": "босс"},
	]
	for case_raw in cases:
		var case: Dictionary = case_raw
		var attacker := _real_enemy(bench["holder"], knight.global_position + Vector2(50.0, 0.0), str(case["kind"]))
		await process_frame
		knight.set("_damage_invulnerability_left", 0.0)
		knight.set("_retaliation_cooldown_left", 0.0)
		knight.call("take_damage", 4.0, "contact", attacker)
		var knocked := _knockback_len(attacker) > 1.0
		if knocked != bool(case["expect_knock"]):
			errors.append("retaliation taxonomy: %s — ожидался knock=%s, получен %s" % [str(case["label"]), str(case["expect_knock"]), str(knocked)])
		attacker.queue_free()
		await process_frame
	bench["holder"].queue_free()
	await process_frame


func _test_retaliation_cooldown(errors: Array) -> void:
	var bench := await _knight_bench(errors)
	var knight: Node2D = bench["knight"]
	var first := _real_enemy(bench["holder"], knight.global_position + Vector2(48.0, 0.0))
	var second := _real_enemy(bench["holder"], knight.global_position + Vector2(0.0, 48.0))
	await process_frame

	knight.call("take_damage", 4.0, "contact", first)
	if _knockback_len(first) < 1.0:
		errors.append("retaliation cooldown: первый удар обязан отбросить")
	knight.set("_damage_invulnerability_left", 0.0)
	knight.call("take_damage", 4.0, "contact", second)
	if _knockback_len(second) > 0.5:
		errors.append("retaliation cooldown: второй удар в пределах кулдауна НЕ должен отбрасывать")
	knight.set("_retaliation_cooldown_left", 0.0)
	knight.set("_damage_invulnerability_left", 0.0)
	knight.call("take_damage", 4.0, "contact", second)
	if _knockback_len(second) < 1.0:
		errors.append("retaliation cooldown: после истечения кулдауна отброс обязан вернуться")
	bench["holder"].queue_free()
	await process_frame


func _test_retaliation_no_class_leak_and_prevented(errors: Array) -> void:
	# Утечка другим классам: солдат с теми же условиями отброса не даёт.
	var holder := Node2D.new()
	root.add_child(holder)
	var soldier := PLAYER_SCENE.instantiate()
	holder.add_child(soldier)
	soldier.global_position = Vector2(620, 620)
	await process_frame
	soldier.call("configure_character", "soldier", "soldier_rifle")
	var soldier_weapon: Node = soldier.get("equipped_weapon")
	if soldier_weapon != null and is_instance_valid(soldier_weapon):
		soldier_weapon.set_process(false)
	var params: Dictionary = soldier.get("derived_parameters")
	params["dodge"] = 0.0
	params["raw_dodge"] = 0.0
	var soldier_raw_defect := _raw_pair_defect(params, "dodge", "raw_dodge")
	if soldier_raw_defect != "":
		errors.append(soldier_raw_defect)
	soldier.set("derived_parameters", params)
	var attacker := _real_enemy(holder, soldier.global_position + Vector2(50.0, 0.0))
	await process_frame
	soldier.set("_damage_invulnerability_left", 0.0)
	soldier.call("take_damage", 4.0, "contact", attacker)
	if _knockback_len(attacker) > 0.5:
		errors.append("retaliation leak: трейт Рыцаря протёк Солдату")
	holder.queue_free()
	await process_frame

	# Полностью предотвращённый удар (i-frames) отброса не даёт.
	var bench := await _knight_bench(errors)
	var knight: Node2D = bench["knight"]
	var blocked_attacker := _real_enemy(bench["holder"], knight.global_position + Vector2(50.0, 0.0))
	await process_frame
	knight.set("_damage_invulnerability_left", 1.0)
	var landed: bool = knight.call("take_damage", 4.0, "contact", blocked_attacker)
	if landed:
		errors.append("retaliation prevented: удар сквозь i-frames не должен проходить")
	if _knockback_len(blocked_attacker) > 0.5:
		errors.append("retaliation prevented: предотвращённый удар не должен отбрасывать")
	bench["holder"].queue_free()
	await process_frame


# --- Long Spear: тройной укол (SCRUM-921) ---


func _weapon_bench(weapon_id: String) -> Dictionary:
	var holder := Node2D.new()
	root.add_child(holder)
	var owner := MockOwner.new()
	holder.add_child(owner)
	owner.global_position = Vector2(900.0, 900.0)
	var weapon: Node2D = BerserkWeaponScript.new()
	owner.add_child(weapon)
	weapon.set_process(false)
	weapon.call("configure_weapon", PD.weapon("knight", weapon_id))
	weapon.set("damage", 100.0)  # фикс для точных ассертов (крита у мок-владельца нет)
	return {"holder": holder, "owner": owner, "weapon": weapon}


func _mock_enemy(holder: Node2D, pos: Vector2) -> TypedEnemy:
	var enemy := TypedEnemy.new()
	holder.add_child(enemy)
	enemy.add_to_group("enemies")
	enemy.global_position = pos
	return enemy


func _test_spear_triple_thrust_geometry_and_dedup(errors: Array) -> void:
	var bench := _weapon_bench("long_spear")
	var owner: Node2D = bench["owner"]
	var weapon: Node = bench["weapon"]
	var base := owner.global_position
	# Геометрия веера (директные шаги — детерминизм без твин-таймингов):
	# лево = rotated(-16°) (экранные координаты Y-вниз), центр, право.
	var enemy_left := _mock_enemy(bench["holder"], base + Vector2(400.0, 0.0).rotated(deg_to_rad(-16.0)))
	var enemy_center := _mock_enemy(bench["holder"], base + Vector2(500.0, 0.0))
	var enemy_right := _mock_enemy(bench["holder"], base + Vector2(400.0, 0.0).rotated(deg_to_rad(16.0)))
	var enemy_wide := _mock_enemy(bench["holder"], base + Vector2(300.0, 50.0))   # |50| ≤ 55 — только новая ширина 110
	var enemy_out := _mock_enemy(bench["holder"], base + Vector2(400.0, 0.0).rotated(deg_to_rad(-50.0)))
	var enemy_behind := _mock_enemy(bench["holder"], base + Vector2(-200.0, 0.0))
	var enemy_close := _mock_enemy(bench["holder"], base + Vector2(180.0, 0.0))   # зона перекрытия всех трёх полос
	await process_frame

	weapon.set("_last_direction", Vector2.RIGHT)
	var owner_id := owner.get_instance_id()
	for step_index in range(3):
		weapon.call("_run_thrust_step", owner_id, step_index)

	if enemy_left.typed_hit_count() != 1:
		errors.append("spear: левый враг должен ловить ровно один укол (лево), получил %d" % enemy_left.typed_hit_count())
	if enemy_center.typed_hit_count() != 1:
		errors.append("spear: центральный враг должен ловить ровно один укол, получил %d" % enemy_center.typed_hit_count())
	if enemy_right.typed_hit_count() != 1:
		errors.append("spear: правый враг должен ловить ровно один укол, получил %d" % enemy_right.typed_hit_count())
	if enemy_wide.typed_hit_count() != 1:
		errors.append("spear: враг на 50px сбоку должен попадать в новую полосу 110 (старые 90 мимо)")
	if enemy_out.typed_hit_count() != 0:
		errors.append("spear: враг под -50° вне веера не должен ловить уколы")
	if enemy_behind.typed_hit_count() != 0:
		errors.append("spear: враг за спиной не должен ловить уколы")
	# Анти-triple-dip: враг в зоне перекрытия трёх полос — ровно ОДИН укол полного урона.
	if enemy_close.typed_hit_count() != 1:
		errors.append("spear dedup: враг в перекрытии полос получил %d уколов вместо 1" % enemy_close.typed_hit_count())
	if absf(enemy_close.total_damage - 100.0) > EPS:
		errors.append("spear dedup: урон по перекрытию %.1f != один полный укол 100" % enemy_close.total_damage)
	# Порядок директных окон: лево (шаг 0) раньше права (шаг 2) — оба хита есть,
	# геометрическая принадлежность окон доказана эксклюзивными полосами выше.
	weapon.call("_finish_swing")
	# Нет протухших хитбоксов: новый цикл бьёт заново (дедуп очищен).
	for step_index in range(3):
		weapon.call("_run_thrust_step", owner_id, step_index)
	if enemy_center.typed_hit_count() != 2:
		errors.append("spear stale: после нового цикла центральный враг должен иметь 2 укола, имеет %d" % enemy_center.typed_hit_count())
	bench["holder"].queue_free()
	await process_frame


func _test_spear_timed_order(errors: Array) -> void:
	# Сквозной тайминг: реальный свинг раскладывает окна лево→центр→право по
	# отдельным кадрам (thrust_step_time=0.11 ≫ кадра) — атака ЧИТАЕТСЯ как серия.
	var bench := _weapon_bench("long_spear")
	var owner: Node2D = bench["owner"]
	var weapon: Node = bench["weapon"]
	var base := owner.global_position
	var anchor := _mock_enemy(bench["holder"], base + Vector2(120.0, 0.0))  # ближайший — держит направление вправо
	var enemy_left := _mock_enemy(bench["holder"], base + Vector2(400.0, 0.0).rotated(deg_to_rad(-16.0)))
	var enemy_center := _mock_enemy(bench["holder"], base + Vector2(500.0, 0.0))
	var enemy_right := _mock_enemy(bench["holder"], base + Vector2(400.0, 0.0).rotated(deg_to_rad(16.0)))
	await process_frame

	weapon.call("_start_swing", false)
	for _i in range(90):
		await process_frame
		if not bool(weapon.get("_swinging")):
			break
	if bool(weapon.get("_swinging")):
		errors.append("spear timed: свинг не завершился за 90 кадров")
	for pair in [[enemy_left, "левый"], [enemy_center, "центральный"], [enemy_right, "правый"]]:
		if (pair[0] as TypedEnemy).typed_hit_count() != 1:
			errors.append("spear timed: %s враг должен получить ровно один укол" % str(pair[1]))
	var frame_left := enemy_left.first_typed_frame()
	var frame_center := enemy_center.first_typed_frame()
	var frame_right := enemy_right.first_typed_frame()
	if not (frame_left < frame_center and frame_center < frame_right):
		errors.append("spear timed: порядок окон нарушен (лево %d, центр %d, право %d)" % [frame_left, frame_center, frame_right])
	if anchor.typed_hit_count() != 1:
		errors.append("spear timed: якорный враг в перекрытии должен получить один укол")
	bench["holder"].queue_free()
	await process_frame


func _test_spear_fan_artifact(errors: Array) -> void:
	# SCRUM-961 «Веер уколов»: артефакт добавляет два КРАЙНИХ укола ±32° на 55%.
	var bench := _weapon_bench("long_spear")
	var owner: MockOwner = bench["owner"]
	var weapon: Node = bench["weapon"]
	owner.run_modifiers = {"spear_triple_thrust": 1.0}
	var base: Vector2 = owner.global_position
	var enemy_outer := _mock_enemy(bench["holder"], base + Vector2(400.0, 0.0).rotated(deg_to_rad(32.0)))
	await process_frame
	weapon.set("_last_direction", Vector2.RIGHT)
	var entries: Array = weapon.call("_thrust_sequence_entries")
	if entries.size() != 5:
		errors.append("spear artifact: секвенс с артефактом должен иметь 5 уколов, имеет %d" % entries.size())
	for step_index in range(entries.size()):
		weapon.call("_run_thrust_step", owner.get_instance_id(), step_index)
	if enemy_outer.typed_hit_count() != 1:
		errors.append("spear artifact: враг под +32° должен ловить крайний укол")
	elif absf(enemy_outer.total_damage - 55.0) > EPS:
		errors.append("spear artifact: крайний укол %.1f != 55%% урона" % enemy_outer.total_damage)
	bench["holder"].queue_free()
	await process_frame


# --- Tower Shield: конус-баш ближайшей цели (SCRUM-922) ---


func _test_shield_nearest_cone_and_knockback(errors: Array) -> void:
	var bench := _weapon_bench("tower_shield")
	var owner: Node2D = bench["owner"]
	var weapon: Node = bench["weapon"]
	weapon.set("knockback", 118.0)  # зеркало пайплайна Player._apply_weapon_scaling (база Рыцаря)
	var base := owner.global_position
	# Ближайший — сверху-слева: конус обязан развернуться К НЕМУ, а не по умолчанию вправо.
	var nearest := _mock_enemy(bench["holder"], base + Vector2(-30.0, -140.0))
	var cone_mate := _mock_enemy(bench["holder"], base + Vector2(30.0, -160.0))
	var opposite := _mock_enemy(bench["holder"], base + Vector2(170.0, 20.0))
	await process_frame

	var direction: Vector2 = weapon.call("_target_direction", owner)
	if direction.dot((nearest.global_position - base).normalized()) < 0.999:
		errors.append("shield: направление башa должно смотреть на ближайшего монстра")
	weapon.call("_damage_window", owner, direction)
	if nearest.typed_hit_count() != 1 or cone_mate.typed_hit_count() != 1:
		errors.append("shield: обе цели конуса должны получить урон (nearest %d, mate %d)" % [nearest.typed_hit_count(), cone_mate.typed_hit_count()])
	if opposite.typed_hit_count() != 0 or not opposite.impulses.is_empty():
		errors.append("shield: враг вне конуса (за спиной башa) не должен получать урон/отброс")
	if nearest.impulses.is_empty() or cone_mate.impulses.is_empty():
		errors.append("shield: ВСЕ цели конуса должны отлетать, не только первичная")
	else:
		var expected := (260.0 + 118.0 * 3.0) * 1.15
		var nearest_impulse: Vector2 = nearest.impulses[0]
		if absf(nearest_impulse.length() - expected) > 0.5:
			errors.append("shield: импульс %.1f != формуле (260+118×3)×1.15=%.1f" % [nearest_impulse.length(), expected])
		if nearest_impulse.dot((nearest.global_position - base).normalized()) < nearest_impulse.length() * 0.999:
			errors.append("shield: отброс должен идти прочь от Рыцаря вдоль радиуса")
	bench["holder"].queue_free()
	await process_frame


func _test_shield_knockback_scaling_and_epic_cap(errors: Array) -> void:
	var bench := _weapon_bench("tower_shield")
	var owner: Node2D = bench["owner"]
	var weapon: Node = bench["weapon"]
	var base := owner.global_position

	# Скейл: удвоение knockback-стата видимо усиливает отброс (AC SCRUM-922).
	var probe := _mock_enemy(bench["holder"], base + Vector2(150.0, 0.0))
	await process_frame
	weapon.set("knockback", 118.0)
	weapon.call("_damage_window", owner, Vector2.RIGHT)
	weapon.call("_finish_swing")
	weapon.set("knockback", 236.0)
	weapon.call("_damage_window", owner, Vector2.RIGHT)
	if probe.impulses.size() != 2:
		errors.append("shield scaling: ожидалось два замера отброса, получено %d" % probe.impulses.size())
	else:
		var low := (probe.impulses[0] as Vector2).length()
		var high := (probe.impulses[1] as Vector2).length()
		if high <= low * 1.3:
			errors.append("shield scaling: рост вложений не усиливает отброс (%.1f → %.1f)" % [low, high])
		if absf(high - (260.0 + 236.0 * 3.0) * 1.15) > 0.5:
			errors.append("shield scaling: импульс %.1f не совпадает с документированной формулой" % high)
	probe.queue_free()

	# Кап эпиков: босс/главная элита ×0.25, мини-элита — полный отброс.
	weapon.call("_finish_swing")
	weapon.set("knockback", 118.0)
	var boss := _mock_enemy(bench["holder"], base + Vector2(150.0, 0.0))
	boss.add_to_group("bosses")
	var main_elite := _mock_enemy(bench["holder"], base + Vector2(160.0, 30.0))
	main_elite.add_to_group("elite_enemies")
	var mini_elite := _mock_enemy(bench["holder"], base + Vector2(160.0, -30.0))
	mini_elite.add_to_group("elite_enemies")
	mini_elite.set_meta("epic_scale_profile", "mini_elite")
	await process_frame
	weapon.call("_damage_window", owner, Vector2.RIGHT)
	var full := (260.0 + 118.0 * 3.0) * 1.15
	if boss.impulses.is_empty() or absf((boss.impulses[0] as Vector2).length() - full * 0.25) > 0.5:
		errors.append("shield epic cap: босс должен получать 25%% импульса")
	if main_elite.impulses.is_empty() or absf((main_elite.impulses[0] as Vector2).length() - full * 0.25) > 0.5:
		errors.append("shield epic cap: главная элита должна капиться 25%%")
	if mini_elite.impulses.is_empty() or absf((mini_elite.impulses[0] as Vector2).length() - full) > 0.5:
		errors.append("shield epic cap: мини-элита должна отлетать полноценно")
	if boss.typed_hit_count() != 1 or main_elite.typed_hit_count() != 1:
		errors.append("shield epic cap: урон по эпикам конус наносит полноценно (капится только смещение)")
	bench["holder"].queue_free()
	await process_frame


# --- Holy Flail: расширяющаяся спираль (SCRUM-923) ---


func _flail_bench() -> Dictionary:
	var bench := _weapon_bench("holy_flail")
	# Изоляция спирали от 1-арг сплэшей melee_arc_followup (не предмет SCRUM-923).
	(bench["weapon"] as Node).set("melee_arc_followup_multiplier", 0.0)
	return bench


func _test_flail_spiral_progressive(errors: Array) -> void:
	var bench := _flail_bench()
	var owner: Node2D = bench["owner"]
	var weapon: Node = bench["weapon"]
	var base := owner.global_position
	var near := _mock_enemy(bench["holder"], base + Vector2(60.0, 0.0))
	var far := _mock_enemy(bench["holder"], base + Vector2(230.0, 0.0))
	await process_frame

	weapon.set("_last_direction", Vector2.RIGHT)
	var owner_id := owner.get_instance_id()
	# Шаг 0: фронт ~78px — ближний уже накрыт, дальний ещё НЕТ (не мгновенный круг).
	weapon.call("_run_spiral_step", owner_id, 0)
	if near.typed_hit_count() != 1:
		errors.append("flail progressive: ближний (60px) должен ловить фронт первого шага")
	if far.typed_hit_count() != 0:
		errors.append("flail progressive: дальний (230px) НЕ должен страдать в момент первого шага — круг не мгновенный")
	# Промежуточный шаг: радиус ещё не дорос до дальнего.
	weapon.call("_run_spiral_step", owner_id, 3)
	if far.typed_hit_count() != 0:
		errors.append("flail progressive: дальний накрыт до того, как фронт дорос до его радиуса")
	# Финальный шаг замыкает оборот на стартовом угле с полным радиусом.
	weapon.call("_run_spiral_step", owner_id, 6)
	if far.typed_hit_count() != 1:
		errors.append("flail progressive: дальний обязан быть накрыт финальным шагом полного радиуса")
	if near.typed_hit_count() != 1:
		errors.append("flail max-hit: ближний должен остаться с ОДНИМ хитом за каст (дедуп)")
	for hit in near.hits + far.hits:
		if str((hit as Dictionary).get("type", "")) != "physical":
			errors.append("flail: хиты спирали обязаны нести physical-тип")
			break
	bench["holder"].queue_free()
	await process_frame


func _test_flail_full_turn_and_max_hits(errors: Array) -> void:
	var bench := _flail_bench()
	var owner: Node2D = bench["owner"]
	var weapon: Node = bench["weapon"]
	var base := owner.global_position
	var ring: Array = []
	for angle_deg in [0.0, 90.0, 180.0, 270.0]:
		ring.append(_mock_enemy(bench["holder"], base + Vector2(100.0, 0.0).rotated(deg_to_rad(angle_deg))))
	await process_frame
	weapon.set("_last_direction", Vector2.RIGHT)
	var owner_id := owner.get_instance_id()
	for step_index in range(int(weapon.get("spiral_steps"))):
		weapon.call("_run_spiral_step", owner_id, step_index)
	for ring_index in range(ring.size()):
		var enemy := ring[ring_index] as TypedEnemy
		if enemy.typed_hit_count() != 1:
			errors.append("flail full turn: враг под %d° получил %d хитов вместо 1 — оборот дырявый или runaway" % [int(ring_index * 90), enemy.typed_hit_count()])
	bench["holder"].queue_free()
	await process_frame


func _test_flail_timed_cast_and_cleanup(errors: Array) -> void:
	# Сквозной каст твин-планировщиком: ближний ловит фронт РАНЬШЕ дальнего;
	# после каста дедуп чист — новый каст бьёт снова (нет протухших хитбоксов).
	var bench := _flail_bench()
	var owner: Node2D = bench["owner"]
	var weapon: Node = bench["weapon"]
	var base := owner.global_position
	var near := _mock_enemy(bench["holder"], base + Vector2(60.0, 0.0))
	var far := _mock_enemy(bench["holder"], base + Vector2(225.0, 0.0))
	await process_frame

	weapon.call("_start_swing", false)
	for _i in range(120):
		await process_frame
		if not bool(weapon.get("_swinging")):
			break
	if bool(weapon.get("_swinging")):
		errors.append("flail timed: каст не завершился за 120 кадров")
	if near.typed_hit_count() != 1 or far.typed_hit_count() != 1:
		errors.append("flail timed: обе цели должны быть накрыты за каст (near %d, far %d)" % [near.typed_hit_count(), far.typed_hit_count()])
	elif near.first_typed_frame() >= far.first_typed_frame():
		errors.append("flail timed: ближний обязан ловить фронт раньше дальнего (кадры %d/%d)" % [near.first_typed_frame(), far.first_typed_frame()])
	var second_cast_before := near.typed_hit_count()
	weapon.call("_start_swing", true)  # immediate-ветка гоняет все шаги сразу
	if near.typed_hit_count() != second_cast_before + 1:
		errors.append("flail cleanup: новый каст должен бить заново — дедуп не очищен")
	bench["holder"].queue_free()
	await process_frame
