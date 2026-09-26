extends SceneTree

# SCRUM-930..933: фокусный гейт редизайна кита Снайпера.
#
# Trait «Дальний расчёт» (SCRUM-930, CLASS_TRAITS.sniper): исходящий урон оружия
#   Снайпера растёт с дистанцией владелец→цель, замеренной В МОМЕНТ применения
#   урона (ClassWeapon._damage_enemy → _class_distance_trait_multiplier). Формула
#   ProgressionData.distance_trait_multiplier: ×1.0 в пределах free_range(120px),
#   далее +per_100px(0.10) за каждые 100px, ЖЁСТКИЙ кап +cap_bonus(0.60) → ×1.60
#   на 720px и дальше. Тики DoT (hit_type "dot") НЕ скейлятся (документированное
#   исключение AC). Классам без distance-ключей множитель ровно 1.0 (нет утечки).
# «Винтовка Мертвого Глаза» (SCRUM-931, sniper_lockshot) — PREFERRED-вариант:
#   всегда САМАЯ ДАЛЬНЯЯ валидная цель, тяжёлый прямой хит (×1.34) + терминальный
#   взрыв на конце линии (0.35) + ближний самоподрыв ~80% урона выстрела по
#   врагам вплотную (close_burst_ratio). Всё физическое, всё скейлит trait.
# «Прицел Наводчика» (SCRUM-932, sniper_kill_zone): красный телеграф → задержка
#   ~1с (grenade_delay) → тяжёлый артиллерийский AoE по всей зоне (falloff), урон
#   каждого врага скейлит trait по дистанции ДО НЕГО; телеграф чистится при
#   свапе/смерти/ресете (cleanup_effects → _effects_shutdown гасит снаряд).
# «Осколочные Патроны» (SCRUM-933, sniper_split_round): скорострельный круговой
#   веер projectile_count пуль по ближним монстрам (round-robin, не больше
#   SHATTER_VOLLEY_HIT_LIMIT пуль в одного); пули без цели уходят радиальным
#   веером без урона; каждая летит с projectile_speed (видимый полёт).
#
# Запуск: Godot --headless --path . --script res://tests/sniper_kit_test.gd

const ClassWeapon := preload("res://scripts/class_weapon.gd")
const PD := preload("res://scripts/progression_data.gd")

const EPS := 0.001
const BASE_DAMAGE := 50.0


class MockOwner extends CharacterBody2D:
	var character_id := "sniper"
	var derived_parameters := {
		"damage": BASE_DAMAGE,
		"magic_damage": 20.0,
		"crit_chance": 0.0,
		"crit_damage_multiplier": 1.0,
		"dot_damage": 5.0,
		"dot_speed": 2.0,
	}
	var run_modifiers := {}
	var stats := {}
	var health := 70.0
	var max_health := 100.0

	# Зеркало Player.class_trait_value: data-driven чтение trait'а по character_id
	# — тест переключает класс для проверки отсутствия утечки другим классам.
	func class_trait_value(key: String, default_value := 0.0) -> float:
		var trait_config: Dictionary = PD.CLASS_TRAITS.get(character_id, {})
		return float(trait_config.get(key, default_value))


class TypedEnemy extends Node2D:
	var total_damage := 0.0
	var hits: Array = []

	func take_damage(amount: float, feedback: Dictionary = {}) -> void:
		total_damage += amount
		hits.append({"amount": amount, "type": str(feedback.get("damage_type", ""))})

	# Маркер для ClassWeapon._take_damage_accepts_feedback (2-арг take_damage).
	func _show_combat_feedback(_amount: float = 0.0, _feedback: Dictionary = {}) -> void:
		pass


func _initialize() -> void:
	# Гейт компиляции: если class_weapon.gd не собрался, ClassWeapon.new() в
	# стендах молча возвращает null и сценарии абортятся ДО ассертов — вышел бы
	# ложный PASS с пустым errors. Красним сразу и громко.
	var weapon_script: Script = ClassWeapon
	if not weapon_script.can_instantiate():
		push_error("Sniper kit: class_weapon.gd не компилируется — стенды мертвы, см. Parse Error выше.")
		quit(1)
		return

	var errors: Array = []
	_test_trait_registry_contract(errors)
	_test_trait_formula_and_cap(errors)
	_test_kit_data_contracts(errors)
	await _test_trait_distance_scaling_runtime(errors)
	await _test_trait_dot_exception(errors)
	await _test_trait_no_class_leak(errors)
	await _test_deadeye_far_target_and_bursts(errors)
	await _test_deadeye_without_final_does_not_mark(errors)
	await _test_spotter_delay_zone_and_scaling(errors)
	await _test_spotter_cleanup_on_shutdown(errors)
	await _test_shatter_solo_hit_cap(errors)
	await _test_shatter_crowd_spread(errors)
	await _test_shatter_radial_fallback_and_artifact(errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Sniper kit: %s" % str(error))
		push_error("Sniper kit test failed with %d error(s)." % errors.size())
		quit(1)
		return
	print("Sniper kit test passed (SCRUM-930 trait, SCRUM-931 deadeye, SCRUM-932 spotter, SCRUM-933 shatter).")
	quit(0)


# --- Контракты данных ---------------------------------------------------------


func _test_trait_registry_contract(errors: Array) -> void:
	var trait_config: Dictionary = PD.CLASS_TRAITS.get("sniper", {})
	if trait_config.is_empty():
		errors.append("trait: нет записи CLASS_TRAITS.sniper")
		return
	if str(trait_config.get("title", "")) != "Дальний расчёт":
		errors.append("trait: title '%s' != 'Дальний расчёт'" % str(trait_config.get("title", "")))
	var per_100 := float(trait_config.get("distance_damage_per_100px", 0.0))
	var cap_bonus := float(trait_config.get("distance_damage_cap_bonus", 0.0))
	var free_range := float(trait_config.get("distance_damage_free_range", -1.0))
	if per_100 <= 0.0:
		errors.append("trait: distance_damage_per_100px %.3f не задан — рост урона мёртв" % per_100)
	if cap_bonus <= 0.0:
		errors.append("trait: distance_damage_cap_bonus %.3f не задан — нет жёсткого капа" % cap_bonus)
	if free_range < 0.0:
		errors.append("trait: distance_damage_free_range не задан — грация вплотную не читается")


func _test_trait_formula_and_cap(errors: Array) -> void:
	# ×1.0 строго вплотную и в пределах free_range.
	if absf(PD.class_distance_multiplier_at("sniper", 0.0) - 1.0) > EPS:
		errors.append("формула: вплотную множитель != 1.0 (AC: близкая цель — базовый урон)")
	var trait_config: Dictionary = PD.CLASS_TRAITS.get("sniper", {})
	var free_range := float(trait_config.get("distance_damage_free_range", 120.0))
	if absf(PD.class_distance_multiplier_at("sniper", free_range) - 1.0) > EPS:
		errors.append("формула: на границе free_range множитель != 1.0")
	# Дальше цель — выше множитель (монотонность до капа).
	var near := PD.class_distance_multiplier_at("sniper", free_range + 50.0)
	var mid := PD.class_distance_multiplier_at("sniper", free_range + 300.0)
	if not (mid > near and near > 1.0):
		errors.append("формула: множитель не растёт с дистанцией (near=%.3f mid=%.3f)" % [near, mid])
	# Жёсткий кап: 1.0 + cap_bonus, достигается и ДЕРЖИТСЯ дальше (screen-edge не ломает).
	var cap_bonus := float(trait_config.get("distance_damage_cap_bonus", 0.60))
	var per_100 := float(trait_config.get("distance_damage_per_100px", 0.10))
	var cap_distance := free_range + cap_bonus / maxf(per_100, EPS) * 100.0
	var at_cap := PD.class_distance_multiplier_at("sniper", cap_distance)
	var far_beyond := PD.class_distance_multiplier_at("sniper", cap_distance + 3000.0)
	if absf(at_cap - (1.0 + cap_bonus)) > EPS:
		errors.append("формула: на дистанции капа множитель %.3f != %.3f" % [at_cap, 1.0 + cap_bonus])
	if absf(far_beyond - (1.0 + cap_bonus)) > EPS:
		errors.append("формула: кап НЕ держится за дистанцией капа (%.3f) — босс/край экрана ломает баланс" % far_beyond)


func _test_kit_data_contracts(errors: Array) -> void:
	var rifle: Dictionary = PD.weapon("sniper", "sniper_deadeye_rifle")
	var scope: Dictionary = PD.weapon("sniper", "sniper_spotter_scope")
	var shatter: Dictionary = PD.weapon("sniper", "sniper_shatter_rounds")
	# Весь кит физический — trait скейлит физ-ось, магия/DoT его не трогают.
	for config in [rifle, scope, shatter]:
		if str(config.get("damage_parameter", "")) != "damage":
			errors.append("%s: damage_parameter '%s' != 'damage' (кит физический)" % [str(config.get("id")), str(config.get("damage_parameter", ""))])
	# Attack-mode маркеры.
	if str(rifle.get("attack_mode", "")) != "sniper_lockshot":
		errors.append("винтовка: attack_mode '%s' != 'sniper_lockshot'" % str(rifle.get("attack_mode", "")))
	for charge_key in ["charge_seconds", "charge_max_multiplier"]:
		if rifle.has(charge_key):
			errors.append("винтовка: %s не должен задаваться — weakpoint открывает завершённый lockshot, не Ranger-style charge" % charge_key)
	if str(scope.get("attack_mode", "")) != "sniper_kill_zone":
		errors.append("наводчик: attack_mode '%s' != 'sniper_kill_zone'" % str(scope.get("attack_mode", "")))
	if str(shatter.get("attack_mode", "")) != "sniper_split_round":
		errors.append("осколочные: attack_mode '%s' != 'sniper_split_round'" % str(shatter.get("attack_mode", "")))
	# SCRUM-931: ближний самоподрыв ~80% урона выстрела.
	var burst_ratio := float(rifle.get("close_burst_ratio", 0.0))
	if burst_ratio < 0.6 or burst_ratio > 1.0:
		errors.append("винтовка: close_burst_ratio %.2f вне полосы «~80%%» (0.6..1.0)" % burst_ratio)
	if float(rifle.get("close_burst_radius", 0.0)) < 100.0:
		errors.append("винтовка: close_burst_radius %.0f < 100 — страховка вплотную не читается" % float(rifle.get("close_burst_radius", 0.0)))
	# SCRUM-932: задержка ~1с + высокий урон компенсирует избегаемость.
	var scope_delay := float(scope.get("grenade_delay", 0.0))
	if scope_delay < 0.7 or scope_delay > 1.6:
		errors.append("наводчик: grenade_delay %.2f вне «~1с» (0.7..1.6) — телеграф не тот" % scope_delay)
	if float(scope.get("damage_multiplier", 0.0)) < 1.6:
		errors.append("наводчик: damage_multiplier %.2f < 1.6 — задержка не окуплена тяжёлым уроном" % float(scope.get("damage_multiplier", 0.0)))
	if float(scope.get("aoe_radius", 0.0)) < 200.0:
		errors.append("наводчик: aoe_radius %.0f < 200 — «большая зона» не читается" % float(scope.get("aoe_radius", 0.0)))
	# SCRUM-933: много пуль, быстрый темп, важна скорость снаряда.
	if int(shatter.get("projectile_count", 0)) < 4:
		errors.append("осколочные: projectile_count %d < 4 — «много пуль» не читается" % int(shatter.get("projectile_count", 0)))
	if float(shatter.get("projectile_speed", 0.0)) <= 0.0:
		errors.append("осколочные: projectile_speed не задан — полёт пуль не настраивается")
	if float(shatter.get("fire_interval", 999.0)) > 0.7:
		errors.append("осколочные: fire_interval %.2f > 0.7 — «очень быстрый темп» не читается" % float(shatter.get("fire_interval", 999.0)))
	if ClassWeapon.SHATTER_VOLLEY_HIT_LIMIT < 1 or ClassWeapon.SHATTER_VOLLEY_HIT_LIMIT > 4:
		errors.append("осколочные: SHATTER_VOLLEY_HIT_LIMIT %d вне разумной полосы 1..4" % ClassWeapon.SHATTER_VOLLEY_HIT_LIMIT)
	# Тюнинг не в клэмп-сатурации: кит реально балансируется бюджетом.
	for config in [rifle, scope, shatter]:
		var tuned := float(config.get("budget_damage_multiplier", 1.0))
		if tuned <= 0.30 or tuned >= 2.75:
			errors.append("%s: budget_damage_multiplier %.3f у границы клэмпа" % [str(config.get("id")), tuned])


# --- Общий стенд --------------------------------------------------------------


func _new_scene(name: String) -> Node2D:
	var holder := Node2D.new()
	holder.name = name
	root.add_child(holder)
	current_scene = holder
	return holder


func _new_owner(holder: Node2D, position := Vector2(1400, 1200)) -> MockOwner:
	var owner := MockOwner.new()
	holder.add_child(owner)
	owner.global_position = position
	return owner


func _new_weapon(owner: MockOwner, weapon_id: String) -> ClassWeapon:
	var weapon := ClassWeapon.new()
	owner.add_child(weapon)
	weapon.configure_weapon(PD.weapon("sniper", weapon_id))
	weapon.set_process(false)
	# Глушим авто-атаку кулдауном — тесты зовут _fire_* напрямую (см. ranger/thief).
	weapon.set("_cooldown", 1.0e9)
	return weapon


func _new_enemy(holder: Node2D, position: Vector2) -> TypedEnemy:
	var enemy := TypedEnemy.new()
	enemy.add_to_group("enemies")
	holder.add_child(enemy)
	enemy.global_position = position
	return enemy


func _cleanup(holder: Node2D) -> void:
	holder.queue_free()
	current_scene = null
	await process_frame
	await process_frame


# --- SCRUM-930: trait «Дальний расчёт» в рантайме -----------------------------


func _test_trait_distance_scaling_runtime(errors: Array) -> void:
	# Прямой прогон _damage_enemy на разных дистанциях: гейт в точке применения
	# урона обязан домножать на канонический множитель дистанции.
	var holder := _new_scene("TraitDistanceScene")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "sniper_deadeye_rifle")
	await process_frame
	for distance in [0.0, 60.0, 420.0, 720.0, 1500.0]:
		var enemy := _new_enemy(holder, owner.global_position + Vector2(distance, 0.0))
		await process_frame
		weapon.call("_damage_enemy", enemy, BASE_DAMAGE, false, "")
		var expected := BASE_DAMAGE * PD.class_distance_multiplier_at("sniper", distance)
		if absf(enemy.total_damage - expected) > 0.01:
			errors.append("trait рантайм: на %.0fpx урон %.2f != %.2f (множитель дистанции не применён)" % [distance, enemy.total_damage, expected])
		enemy.free()
		await process_frame
	await _cleanup(holder)


func _test_trait_dot_exception(errors: Array) -> void:
	# Тик DoT (hit_type "dot") на дальней дистанции НЕ скейлится — усиление только
	# физической оси выстрелов (документированное исключение AC).
	var holder := _new_scene("TraitDotScene")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "sniper_deadeye_rifle")
	var enemy := _new_enemy(holder, owner.global_position + Vector2(1000.0, 0.0))
	await process_frame
	weapon.call("_damage_enemy", enemy, BASE_DAMAGE, false, "dot")
	if absf(enemy.total_damage - BASE_DAMAGE) > 0.01:
		errors.append("trait DoT: тик на 1000px = %.2f != %.2f (DoT не должен скейлиться дистанцией)" % [enemy.total_damage, BASE_DAMAGE])
	await _cleanup(holder)


func _test_trait_no_class_leak(errors: Array) -> void:
	# Класс без distance-ключей (солдат) — множитель ровно 1.0 на любой дистанции.
	var holder := _new_scene("TraitLeakScene")
	var owner := _new_owner(holder)
	owner.character_id = "soldier"
	var weapon := _new_weapon(owner, "sniper_deadeye_rifle")
	var enemy := _new_enemy(holder, owner.global_position + Vector2(1500.0, 0.0))
	await process_frame
	weapon.call("_damage_enemy", enemy, BASE_DAMAGE, false, "")
	if absf(enemy.total_damage - BASE_DAMAGE) > 0.01:
		errors.append("trait утечка: чужой класс на 1500px получил ×%.3f (ожидалась нейтраль 1.0)" % (enemy.total_damage / BASE_DAMAGE))
	await _cleanup(holder)


# --- SCRUM-931: «Винтовка Мертвого Глаза» -------------------------------------


func _test_deadeye_far_target_and_bursts(errors: Array) -> void:
	var holder := _new_scene("DeadeyeScene")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "sniper_deadeye_rifle")
	var far := _new_enemy(holder, owner.global_position + Vector2(500.0, 0.0))    # самая дальняя — цель
	var mid := _new_enemy(holder, owner.global_position + Vector2(300.0, 0.0))    # на линии — overpen
	var near_off := _new_enemy(holder, owner.global_position + Vector2(0.0, 80.0)) # вплотную, вне линии — самоподрыв
	var outside := _new_enemy(holder, owner.global_position + Vector2(0.0, 400.0)) # вне всех зон — изоляция
	await process_frame
	weapon._attack()
	# До конца фиксации (grenade_delay) урона быть не должно — выстрел отложен.
	if far.total_damage > EPS:
		errors.append("винтовка: урон нанесён до конца фиксации (выстрел не отложен)")
	await create_timer(0.4).timeout
	# Самая дальняя цель ловит тяжёлый хит (×1.34) + терминальный взрыв (0.35),
	# оба скейлятся trait'ом по её дистанции.
	var far_mult := PD.class_distance_multiplier_at("sniper", 500.0)
	var far_expected := BASE_DAMAGE * (ClassWeapon.DEADEYE_LOCK_MAIN_MULT + ClassWeapon.DEADEYE_ENDPOINT_BLAST_RATIO) * far_mult
	if absf(far.total_damage - far_expected) > 0.5:
		errors.append("винтовка: дальняя цель %.2f != %.2f (хит ×1.34 + endpoint 0.35 × дистанция)" % [far.total_damage, far_expected])
	if far.hits.size() > 0 and str(far.hits[0]["type"]) != "physical":
		errors.append("винтовка: тип урона '%s' != physical" % str(far.hits[0]["type"]))
	# Самая дальняя действительно выбрана целью: mid (на линии) — лишь overpen-доля, меньше far.
	if not (mid.total_damage > EPS and mid.total_damage < far.total_damage):
		errors.append("винтовка: mid=%.2f far=%.2f — не выцелена самая дальняя цель / нет overpen" % [mid.total_damage, far.total_damage])
	# Ближний самоподрыв достаёт врага вплотную (страховка «беззащитен в упор»).
	if near_off.total_damage <= EPS:
		errors.append("винтовка: враг вплотную (80px) не получил ближний самоподрыв")
	# Изоляция: враг вне линии, вне close_burst и вне endpoint — цел.
	if outside.total_damage > EPS:
		errors.append("винтовка: враг вне всех зон получил урон %.2f (нет изоляции)" % outside.total_damage)
	await _cleanup(holder)


func _test_deadeye_without_final_does_not_mark(errors: Array) -> void:
	var holder := _new_scene("DeadeyeNoFinalScene")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "sniper_deadeye_rifle")
	var target := _new_enemy(holder, owner.global_position + Vector2(500.0, 0.0))
	await process_frame
	weapon._attack()
	await create_timer(weapon.grenade_delay + 0.08).timeout
	if target.total_damage <= EPS:
		errors.append("винтовка без финала: production lockshot не нанёс основной урон")
	var mark_key := "constellation_weakpoint_%d" % owner.get_instance_id()
	if target.has_meta(mark_key):
		errors.append("винтовка без финала: lockshot открыл weakpoint без active final")
	await _cleanup(holder)


# --- SCRUM-932: «Прицел Наводчика» --------------------------------------------


func _test_spotter_delay_zone_and_scaling(errors: Array) -> void:
	var holder := _new_scene("SpotterScene")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "sniper_spotter_scope")
	var zone_radius := float(weapon.get("aoe_radius"))
	var mark := _new_enemy(holder, owner.global_position + Vector2(400.0, 0.0)) # цель = центр метки
	var inside := mark
	var outside := _new_enemy(holder, mark.global_position + Vector2(zone_radius + 60.0, 0.0))
	await process_frame
	weapon.call("_fire_sniper_kill_zone", owner, mark, Vector2.RIGHT)
	# Задержка ~1с: сразу после каста урона нет (только красный телеграф).
	if inside.total_damage > EPS:
		errors.append("наводчик: урон лёг мгновенно — задержки/телеграфа нет")
	await create_timer(float(weapon.get("grenade_delay")) + 0.35).timeout
	# После задержки снаряд накрывает зону; жертва в центре — полный ролл × дистанция.
	var center_mult := PD.class_distance_multiplier_at("sniper", 400.0)
	var inside_expected := BASE_DAMAGE * center_mult
	if absf(inside.total_damage - inside_expected) > 0.5:
		errors.append("наводчик: центр зоны %.2f != %.2f (полный урон × дистанция)" % [inside.total_damage, inside_expected])
	if inside.hits.size() > 0 and str(inside.hits[0]["type"]) != "physical":
		errors.append("наводчик: тип урона '%s' != physical" % str(inside.hits[0]["type"]))
	if outside.total_damage > EPS:
		errors.append("наводчик: враг вне финальной зоны получил урон %.2f" % outside.total_damage)
	await _cleanup(holder)


func _test_spotter_cleanup_on_shutdown(errors: Array) -> void:
	# Свап оружия / смерть игрока = cleanup_effects → телеграф гаснет, а
	# отложенный снаряд, сработав после, видит _effects_shutdown и НЕ бьёт.
	var holder := _new_scene("SpotterCleanupScene")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "sniper_spotter_scope")
	var victim := _new_enemy(holder, owner.global_position + Vector2(400.0, 0.0))
	await process_frame
	weapon.call("_fire_sniper_kill_zone", owner, victim, Vector2.RIGHT)
	var telegraphs_before := get_nodes_in_group("player_weapon_effects").size()
	if telegraphs_before <= 0:
		errors.append("наводчик: телеграф не зарегистрирован (нечего чистить)")
	weapon.call("cleanup_effects")
	await process_frame
	if not bool(weapon.get("_effects_shutdown")):
		errors.append("наводчик: cleanup_effects не выставил _effects_shutdown")
	# Прямой вызов посадки снаряда после shutdown обязан быть no-op (без урона/краша).
	weapon.call("_land_spotter_shell", owner.get_instance_id(), victim.global_position, float(weapon.get("aoe_radius")), 0, Vector2.RIGHT)
	if victim.total_damage > EPS:
		errors.append("наводчик: снаряд ударил после cleanup_effects (утечка отложенного колбэка)")
	await _cleanup(holder)


# --- SCRUM-933: «Осколочные Патроны» ------------------------------------------


func _test_shatter_solo_hit_cap(errors: Array) -> void:
	# Одна цель ловит не больше SHATTER_VOLLEY_HIT_LIMIT пуль за залп (анти-runaway).
	var holder := _new_scene("ShatterSoloScene")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "sniper_shatter_rounds")
	var solo := _new_enemy(holder, owner.global_position + Vector2(120.0, 0.0))
	await process_frame
	weapon.call("_fire_sniper_split_round", owner, null, Vector2.RIGHT)
	# Пули в полёте — мгновенного урона нет (важна скорость снаряда).
	if solo.total_damage > EPS:
		errors.append("осколочные: урон мгновенный — пули не летят (projectile_speed игнорируется)")
	await create_timer(0.7).timeout
	if solo.hits.size() != ClassWeapon.SHATTER_VOLLEY_HIT_LIMIT:
		errors.append("осколочные: одна цель поймала %d пуль != кап %d" % [solo.hits.size(), ClassWeapon.SHATTER_VOLLEY_HIT_LIMIT])
	for hit in solo.hits:
		if str(hit["type"]) != "physical":
			errors.append("осколочные: тип пули '%s' != physical" % str(hit["type"]))
	await _cleanup(holder)


func _test_shatter_crowd_spread(errors: Array) -> void:
	# Веер распределяется round-robin по ближним монстрам; дальний вне радиуса цел.
	var holder := _new_scene("ShatterCrowdScene")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "sniper_shatter_rounds")
	var bullet_count := int(weapon.get("projectile_count"))
	var crowd: Array = []
	for enemy_index in range(bullet_count):
		var angle := TAU * float(enemy_index) / float(bullet_count)
		crowd.append(_new_enemy(holder, owner.global_position + Vector2.RIGHT.rotated(angle) * 200.0))
	var spray_radius := maxf(float(weapon.get("aoe_radius")), 160.0)
	var beyond := _new_enemy(holder, owner.global_position + Vector2(spray_radius + 120.0, 0.0))
	await process_frame
	weapon.call("_fire_sniper_split_round", owner, null, Vector2.RIGHT)
	await create_timer(0.7).timeout
	var hit_enemies := 0
	for enemy_raw in crowd:
		var enemy := enemy_raw as TypedEnemy
		if enemy.hits.size() > ClassWeapon.SHATTER_VOLLEY_HIT_LIMIT:
			errors.append("осколочные: враг поймал %d пуль > кап %d (runaway наложения)" % [enemy.hits.size(), ClassWeapon.SHATTER_VOLLEY_HIT_LIMIT])
		if enemy.hits.size() > 0:
			hit_enemies += 1
	# bullet_count пуль на bullet_count раскиданных врагов → каждый под прицелом.
	if hit_enemies < bullet_count:
		errors.append("осколочные: поражено %d/%d ближних врагов — веер не находит цели round-robin'ом" % [hit_enemies, bullet_count])
	if beyond.total_damage > EPS:
		errors.append("осколочные: враг вне радиуса разлёта (%.0fpx) получил урон" % (spray_radius + 120.0))
	await _cleanup(holder)


func _test_shatter_radial_fallback_and_artifact(errors: Array) -> void:
	# Без целей — ровно projectile_count видимых пуль радиальным веером, урона нет.
	var holder := _new_scene("ShatterFanScene")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "sniper_shatter_rounds")
	var bullet_count := int(weapon.get("projectile_count"))
	await process_frame
	var before := holder.get_child_count()
	weapon.call("_fire_sniper_split_round", owner, null, Vector2.RIGHT)
	var spawned := holder.get_child_count() - before
	if spawned != bullet_count:
		errors.append("осколочные: без целей заспавнено %d пуль != projectile_count %d (нет радиального веера)" % [spawned, bullet_count])
	await _cleanup(holder)

	# Артефакт «Барабан осколков»: +2 пули к вееру.
	holder = _new_scene("ShatterArtifactScene")
	owner = _new_owner(holder)
	owner.run_modifiers = {"shatter_extra_splits": 2.0}
	weapon = _new_weapon(owner, "sniper_shatter_rounds")
	await process_frame
	var art_before := holder.get_child_count()
	weapon.call("_fire_sniper_split_round", owner, null, Vector2.RIGHT)
	var art_spawned := holder.get_child_count() - art_before
	if art_spawned != bullet_count + 2:
		errors.append("осколочные: с артефактом %d пуль != %d (база %d + 2)" % [art_spawned, bullet_count + 2, bullet_count])
	await _cleanup(holder)
