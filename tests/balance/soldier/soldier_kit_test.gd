extends SceneTree

# SCRUM-935..938: focused-тест редизайна кита Солдата.
#   SCRUM-935 «Двойное действие»: ~50% полных копий действия на большой выборке
#     для каждого оружия; копия НЕ роллит новую копию (нет рекурсии/цепочек);
#     эхо применяется ко всем трём оружиям и не течёт другим классам.
#   SCRUM-936 Аркебуза: одна взрывная пуля, малый AoE с falloff по соседям.
#   SCRUM-937 Граната: медленный полёт + отдельный фитиль, урон только на взрыве,
#     тяжёлый per-hit урон при редком кулдауне.
#   SCRUM-938 Штык: ближний конус без мёртвой зоны у ног, вне сектора не бьёт;
#     детерминируемый редкий авто-выстрел по цели ЗА конусом; выстрел — бонус,
#     а не вторая аркебуза.
#
# Запуск: Godot --headless --path . --script res://tests/soldier_kit_test.gd

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
	# SCRUM-935: тестовый аналог Player.class_trait_value — управляемые trait-данные.
	var trait_overrides := {}

	func class_trait_value(key: String, default_value := 0.0) -> float:
		return float(trait_overrides.get(key, default_value))


class MockEnemy extends Node2D:
	var total_damage := 0.0
	var hit_count := 0

	func take_damage(amount: float) -> void:
		total_damage += amount
		hit_count += 1


func _initialize() -> void:
	seed(20260710)
	var errors: Array = []
	# Дешёвые конфиг-гейты первыми (FAIL fast), потом live-механика.
	_test_trait_data_and_configs(errors)
	await _test_trait_distribution_per_weapon(errors)
	await _test_trait_no_recursion_live(errors)
	await _test_trait_echo_all_three_weapons(errors)
	await _test_trait_no_leak_to_other_classes(errors)
	await _test_arquebus_explosion_aoe(errors)
	await _test_grenade_fuse_timing_and_damage(errors)
	await _test_bayonet_cone_geometry(errors)
	await _test_bayonet_occasional_shot(errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Soldier kit (SCRUM-935..938): %s" % str(error))
		push_error("Soldier kit test failed with %d error(s)." % errors.size())
		quit(1)
		return
	print("Soldier kit test passed (SCRUM-935 trait, SCRUM-936 arquebus, SCRUM-937 grenade, SCRUM-938 bayonet).")
	quit(0)


# --- helpers -----------------------------------------------------------------


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


func _soldier_owner(holder: Node2D, echo_chance := -1.0) -> MockOwner:
	var owner := _new_owner(holder)
	owner.trait_overrides = PD.class_trait("soldier")
	if echo_chance >= 0.0:
		owner.trait_overrides["action_echo_chance"] = echo_chance
	# Быстрое эхо в тестах, чтобы не ждать стенных секунд на каждом действии.
	owner.trait_overrides["action_echo_delay"] = 0.05
	return owner


func _new_weapon(owner: MockOwner, weapon_id: String) -> ClassWeapon:
	var weapon := ClassWeapon.new()
	owner.add_child(weapon)
	weapon.configure_weapon(PD.weapon("soldier", weapon_id))
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


# --- SCRUM-935: данные trait'а и конфиг-гейты кита ----------------------------


func _test_trait_data_and_configs(errors: Array) -> void:
	# Trait data-driven: канон реестра — Солдат 50%, копия не рекурсивна.
	if absf(PD.class_action_echo_chance("soldier") - 0.5) > EPS:
		errors.append("CLASS_TRAITS.soldier.action_echo_chance != 0.5")
	if float(PD.class_trait("soldier").get("action_echo_delay", 0.0)) <= 0.0:
		errors.append("CLASS_TRAITS.soldier.action_echo_delay должен быть > 0 (читаемость второго действия)")
	# Echo-фактор учтён в budget-модели: у соло-оси аркебузы (dot/pool/summon = 0)
	# solo_dps = direct_dps * solo_hits * (1 + 0.5) + ульта (малая добавка) —
	# без фактора было бы ≈ direct * solo_hits * 1.03. Порог 1.45 разделяет чётко.
	var rifle_raw: Dictionary = PD.WEAPONS_BY_CLASS["soldier"]["soldier_rifle"]
	var estimate: Dictionary = PD.estimate_weapon_budget("soldier", rifle_raw, false)
	var direct_component := float(estimate.get("direct_dps", 0.0)) * float((estimate.get("hit_model", {}) as Dictionary).get("solo_hits", 1.0))
	if float(estimate.get("solo_dps", 0.0)) < direct_component * 1.45:
		errors.append("budget-модель не учитывает echo-фактор солдата (solo %.2f < direct*hits*1.45 = %.2f)" % [float(estimate.get("solo_dps", 0.0)), direct_component * 1.45])

	var rifle: Dictionary = PD.weapon("soldier", "soldier_rifle")
	var grenade: Dictionary = PD.weapon("soldier", "soldier_grenade")
	var bayonet: Dictionary = PD.weapon("soldier", "soldier_bayonet")
	# SCRUM-936: быстрая взрывная пуля с малым AoE.
	if str(rifle.get("attack_mode", "")) != "arquebus_shot":
		errors.append("soldier_rifle не на arquebus_shot")
	if float(rifle.get("fire_interval", 99.0)) > 0.80:
		errors.append("аркебуза должна стрелять часто (fire_interval %.2f > 0.80)" % float(rifle.get("fire_interval", 0.0)))
	if float(rifle.get("aoe_radius", 999.0)) > float(grenade.get("aoe_radius", 0.0)) * 0.6:
		errors.append("AoE аркебузы должен быть малым против гранаты")
	# SCRUM-937: медленный редкий нюк с фитилём.
	if str(grenade.get("attack_mode", "")) != "grenade_fuse":
		errors.append("soldier_grenade не на grenade_fuse")
	if float(grenade.get("fire_interval", 0.0)) < float(rifle.get("fire_interval", 0.0)) * 3.0:
		errors.append("граната должна быть заметно реже аркебузы")
	if float(grenade.get("damage_multiplier", 0.0)) < float(rifle.get("damage_multiplier", 0.0)) * 3.0:
		errors.append("per-hit урон гранаты должен быть тяжёлым против аркебузы")
	# SCRUM-938: ближний конус + редкий встроенный выстрел.
	if str(bayonet.get("attack_mode", "")) != "bayonet_cone":
		errors.append("soldier_bayonet не на bayonet_cone")
	if float(bayonet.get("attack_range", 999.0)) > 260.0:
		errors.append("штык-конус должен остаться ближним (range ≤ 260)")
	var shot_chance := float(bayonet.get("bayonet_auto_shot_chance", 0.0))
	if shot_chance <= 0.0 or shot_chance > 0.5:
		errors.append("bayonet_auto_shot_chance должен быть редким и ненулевым (0 < c ≤ 0.5), сейчас %.2f" % shot_chance)
	# Выстрел штыка — бонус-акцент, не вторая аркебуза: ожидание дальнобойного
	# выхода за интервал аркебузы много меньше одной пули.
	var ranged_expectation := shot_chance * float(bayonet.get("bayonet_shot_damage_multiplier", 0.7)) \
		* float(rifle.get("fire_interval", 0.62)) / maxf(float(bayonet.get("fire_interval", 0.82)), EPS)
	if ranged_expectation >= 0.5:
		errors.append("авто-выстрел штыка слишком силён как ranged-источник (%.2f ≥ 0.5 пули аркебузы)" % ranged_expectation)


# --- SCRUM-935: распределение ~50% на большой выборке (каждое оружие) ----------


func _test_trait_distribution_per_weapon(errors: Array) -> void:
	var holder := _new_scene("SoldierTraitDistribution")
	for weapon_id in ["soldier_rifle", "soldier_grenade", "soldier_bayonet"]:
		var owner := _soldier_owner(holder)
		var weapon := _new_weapon(owner, str(weapon_id))
		var samples := 2000
		var echoes := 0
		for i in range(samples):
			if bool(weapon.call("_maybe_fire_action_echo", owner, null, Vector2.RIGHT)):
				echoes += 1
		var ratio := float(echoes) / float(samples)
		if ratio < 0.45 or ratio > 0.55:
			errors.append("%s: доля эха %.3f вне [0.45..0.55] на %d роллах" % [weapon_id, ratio, samples])
		# Немедленный free: назначенные echo-твины умирают вместе с оружием,
		# 1000+ отложенных копий не выполняются в последующих кадрах.
		owner.free()
	await _cleanup(holder)


# --- SCRUM-935: копия не порождает копию (нет рекурсии) ------------------------


func _test_trait_no_recursion_live(errors: Array) -> void:
	var holder := _new_scene("SoldierTraitNoRecursion")
	# Гард: под активным эхом ролл всегда отклоняется даже при шансе 1.0.
	var guard_owner := _soldier_owner(holder, 1.0)
	var guard_weapon := _new_weapon(guard_owner, "soldier_rifle")
	guard_weapon.set("_action_echo_active", true)
	for i in range(200):
		if bool(guard_weapon.call("_maybe_fire_action_echo", guard_owner, null, Vector2.RIGHT)):
			errors.append("эхо роллит новую копию под активным эхом (рекурсия)")
			break
	guard_owner.free()

	# Live: шанс 1.0 ⇒ ровно ДВА действия (основное + одна копия), не 3+ и не цепь.
	var owner := _soldier_owner(holder, 1.0)
	var weapon := _new_weapon(owner, "soldier_rifle")
	var enemy := _new_enemy(holder, owner.global_position + Vector2(200, 0))
	await process_frame
	weapon.call("_attack")
	await create_timer(0.8).timeout
	if enemy.hit_count != 2:
		errors.append("аркебуза с шансом эха 1.0 должна дать ровно 2 попадания (основное+копия), получено %d" % enemy.hit_count)
	await create_timer(0.5).timeout
	if enemy.hit_count > 2:
		errors.append("эхо породило дополнительные действия после копии (цепочка): %d попаданий" % enemy.hit_count)
	await _cleanup(holder)


# --- SCRUM-935: эхо применяется ко всем трём оружиям ---------------------------


func _test_trait_echo_all_three_weapons(errors: Array) -> void:
	var holder := _new_scene("SoldierTraitAllWeapons")
	var waits := {
		"soldier_rifle": 0.8,
		"soldier_grenade": 2.6,  # полёт (~0.85с) + фитиль (0.85с) + эхо + запас
		"soldier_bayonet": 0.6,
	}
	for weapon_id in waits.keys():
		var owner := _soldier_owner(holder, 1.0)
		var weapon := _new_weapon(owner, str(weapon_id))
		if weapon_id == "soldier_bayonet":
			# Отключаем авто-выстрел (он бьёт ту же одинокую цель — отдельный
			# детерминированный тест ниже) и пуши (mock-враг без apply_knockback
			# физически сдвигается фоллбеком и выпал бы из конуса до эха).
			# Цель на 180 — вне melee_close_bonus_radius (150), внутри конуса:
			# ровно один take_damage на действие.
			weapon.set("bayonet_auto_shot_chance", 0.0)
			weapon.set("knockback", 0.0)
			weapon.set("melee_stagger_knockback_multiplier", 0.0)
		var offset := Vector2(220, 0) if weapon_id != "soldier_bayonet" else Vector2(180, 0)
		var enemy := _new_enemy(holder, owner.global_position + offset)
		await process_frame
		weapon.call("_attack")
		await create_timer(float(waits[weapon_id])).timeout
		if enemy.hit_count != 2:
			errors.append("%s: эхо-копия должна дать ровно 2 действия по одиночной цели, получено %d" % [weapon_id, enemy.hit_count])
		owner.free()
		enemy.free()
		await process_frame
	await _cleanup(holder)


# --- SCRUM-935: trait не течёт другим классам ---------------------------------


func _test_trait_no_leak_to_other_classes(errors: Array) -> void:
	for class_id in PD.character_ids():
		if str(class_id) == "soldier":
			continue
		if PD.class_action_echo_chance(str(class_id)) > 0.0:
			errors.append("action_echo_chance > 0 у класса %s — «Двойное действие» только у Солдата" % class_id)
	var holder := _new_scene("SoldierTraitNoLeak")
	var owner := _new_owner(holder)
	owner.trait_overrides = PD.class_trait("thief")  # пустой словарь
	var weapon := _new_weapon(owner, "soldier_rifle")
	for i in range(100):
		if bool(weapon.call("_maybe_fire_action_echo", owner, null, Vector2.RIGHT)):
			errors.append("эхо сработало у владельца без trait'а")
			break
	await _cleanup(holder)


# --- SCRUM-936: взрыв пули — малый AoE с falloff -------------------------------


func _test_arquebus_explosion_aoe(errors: Array) -> void:
	var holder := _new_scene("SoldierArquebusAoe")
	var owner := _soldier_owner(holder, 0.0)  # эхо выкл: детерминизм урона
	var weapon := _new_weapon(owner, "soldier_rifle")
	var primary := _new_enemy(holder, owner.global_position + Vector2(220, 0))
	var neighbor := _new_enemy(holder, owner.global_position + Vector2(220 + float(weapon.aoe_radius) * 0.7, 0))
	var outside := _new_enemy(holder, owner.global_position + Vector2(220 + float(weapon.aoe_radius) * 2.5, 0))
	await process_frame
	weapon.call("_attack")
	await create_timer(0.7).timeout
	if primary.total_damage <= EPS:
		errors.append("аркебуза не нанесла урон основной цели")
	if neighbor.total_damage <= EPS:
		errors.append("взрыв пули не задел соседа в малом AoE")
	elif neighbor.total_damage >= primary.total_damage - EPS:
		errors.append("нет falloff взрыва: сосед %.2f ≥ центр %.2f" % [neighbor.total_damage, primary.total_damage])
	if outside.total_damage > EPS:
		errors.append("взрыв пули достал цель вне малого AoE (%.0f px)" % (float(weapon.aoe_radius) * 2.5))
	await _cleanup(holder)


# --- SCRUM-937: тайминг фитиля и тяжёлый урон ----------------------------------


func _test_grenade_fuse_timing_and_damage(errors: Array) -> void:
	var holder := _new_scene("SoldierGrenadeFuse")
	var owner := _soldier_owner(holder, 0.0)
	var rifle := _new_weapon(owner, "soldier_rifle")
	var rifle_enemy := _new_enemy(holder, owner.global_position + Vector2(220, 0))
	await process_frame
	rifle.call("_attack")
	await create_timer(0.6).timeout
	var rifle_hit := rifle_enemy.total_damage
	rifle_enemy.free()
	rifle.queue_free()
	await process_frame

	var weapon := _new_weapon(owner, "soldier_grenade")
	var enemy := _new_enemy(holder, owner.global_position + Vector2(220, 0))
	await process_frame
	var travel := (220.0 - 26.0) / clampf(float(weapon.projectile_speed), 60.0, 460.0)
	var fuse := float(weapon.grenade_delay)
	if travel + fuse < 1.2:
		errors.append("суммарная задержка гранаты %.2fс не читается как «медленно + фитиль» (< 1.2с)" % (travel + fuse))
	weapon.call("_attack")
	await create_timer(travel + fuse * 0.35).timeout
	if enemy.total_damage > EPS:
		errors.append("граната нанесла урон до конца фитиля")
	await create_timer(fuse * 0.65 + 0.2).timeout
	if enemy.total_damage <= EPS:
		errors.append("граната не взорвалась после фитиля")
	# Тяжёлый нюк: per-hit урон гранаты ощутимо выше выстрела аркебузы.
	# (мок даёт плоский derived damage — сравниваем через реальную деривацию данных)
	var probe_stats: Dictionary = PD.base_stats("soldier")
	var rifle_params: Dictionary = PD.derived_parameters(probe_stats, {"damage_multiplier": 1.0}, PD.weapon("soldier", "soldier_rifle"))
	var grenade_params: Dictionary = PD.derived_parameters(probe_stats, {"damage_multiplier": 1.0}, PD.weapon("soldier", "soldier_grenade"))
	var per_hit_ratio := float(grenade_params.get("damage", 0.0)) / maxf(float(rifle_params.get("damage", 0.0)), EPS)
	if per_hit_ratio < 2.0:
		errors.append("derived per-hit урон гранаты должен быть ≥ 2x аркебузы, сейчас %.2fx" % per_hit_ratio)
	if rifle_hit <= EPS:
		errors.append("контрольный выстрел аркебузы не попал (сравнение нюка невалидно)")
	await _cleanup(holder)


# --- SCRUM-938: геометрия конуса без мёртвой зоны ------------------------------


func _test_bayonet_cone_geometry(errors: Array) -> void:
	var holder := _new_scene("SoldierBayonetCone")
	var owner := _soldier_owner(holder, 0.0)
	var weapon := _new_weapon(owner, "soldier_bayonet")
	weapon.set("bayonet_auto_shot_chance", 0.0)
	var contact := _new_enemy(holder, owner.global_position + Vector2(10, 0))
	var close := _new_enemy(holder, owner.global_position + Vector2(70, 6))
	var mid := _new_enemy(holder, owner.global_position + Vector2(160, -30))
	var side := _new_enemy(holder, owner.global_position + Vector2(100, 0).rotated(deg_to_rad(80)))
	var behind := _new_enemy(holder, owner.global_position + Vector2(-110, 0))
	var far := _new_enemy(holder, owner.global_position + Vector2(float(weapon.attack_range) + 90.0, 0))
	await process_frame
	weapon.call("_fire_bayonet_cone", owner, Vector2.RIGHT)
	await process_frame
	if contact.total_damage <= EPS:
		errors.append("конус штыка не задел врага у самых ног (мёртвая зона)")
	if close.total_damage <= EPS or mid.total_damage <= EPS:
		errors.append("конус штыка не задел врагов внутри сектора (close %.2f, mid %.2f)" % [close.total_damage, mid.total_damage])
	if side.total_damage > EPS:
		errors.append("конус штыка бьёт вбок за пределами сектора (80°)")
	if behind.total_damage > EPS:
		errors.append("конус штыка бьёт назад")
	if far.total_damage > EPS:
		errors.append("конус штыка достаёт за attack_range")
	await _cleanup(holder)


# --- SCRUM-938: детерминированный редкий авто-выстрел --------------------------


func _test_bayonet_occasional_shot(errors: Array) -> void:
	var holder := _new_scene("SoldierBayonetShot")
	var owner := _soldier_owner(holder, 0.0)
	var weapon := _new_weapon(owner, "soldier_bayonet")
	# Пуши выключены: mock-враг без apply_knockback сдвигается фоллбеком и за
	# серию уколов «выехал» бы из конуса, став ложной целью для авто-выстрела.
	weapon.set("knockback", 0.0)
	weapon.set("melee_stagger_knockback_multiplier", 0.0)
	# 180 — вне melee_close_bonus_radius (150): один take_damage на укол.
	var cone_enemy := _new_enemy(holder, owner.global_position + Vector2(180, 0))
	# Цель ЗА конусом: дальше attack_range, в пределах bayonet_shot_range, в стороне
	# от направления укола — выстрел должен САМ довернуть на неё.
	var beyond := _new_enemy(holder, owner.global_position + Vector2(420, 190))
	await process_frame

	# chance = 0: за 30 уколов дальняя цель не тронута (редкость управляема).
	weapon.set("bayonet_auto_shot_chance", 0.0)
	for i in range(30):
		weapon.call("_fire_bayonet_cone", owner, Vector2.RIGHT)
	await process_frame
	if beyond.total_damage > EPS:
		errors.append("авто-выстрел стреляет при нулевом шансе")

	# chance = 1: выстрел гарантирован, доворачивает на цель за конусом,
	# урон = доля укола (bayonet_shot_damage_multiplier), одна цель.
	weapon.set("bayonet_auto_shot_chance", 1.0)
	var cone_damage_before := cone_enemy.total_damage
	weapon.call("_fire_bayonet_cone", owner, Vector2.RIGHT)
	await process_frame
	if beyond.total_damage <= EPS:
		errors.append("авто-выстрел с шансом 1.0 не поразил цель за конусом")
	var cone_hit := cone_enemy.total_damage - cone_damage_before
	if cone_hit > EPS and beyond.total_damage >= cone_hit - EPS:
		errors.append("авто-выстрел (%.2f) не слабее укола (%.2f) — должен быть бонус-акцентом" % [beyond.total_damage, cone_hit])
	await _cleanup(holder)
