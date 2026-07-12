extends SceneTree

# SCRUM-902/903: гейт редизайна кита Друида.
#
#  - SCRUM-902 Амулет призыва: случайный ростер призраков (3 melee physical +
#    2 magic ranged, арт SCRUM-901/1015/1016), baseline-стая ≥5 активных
#    призывов с ПОЛНОГО прифилла, семьи урона растут от СВОЕГО стата
#    (physical ← damage/Сила, magic ← magic_damage/Интеллект), стая
#    РАСПРЕДЕЛЯЕТСЯ по нескольким целям и фокусит единственную.
#  - SCRUM-902 «Аура дикой силы»: постоянный классовый бафф урона Друида и его
#    призывов с видимым полупрозрачным кольцом радиуса (WildForceAuraRing);
#    враги/чужие сущности не баффаются; другим классам trait не протекает;
#    budget-фактор един с рантаймом (class_wild_aura_damage_bonus).
#  - SCRUM-903 Посох терний: полупрозрачная зона, слоу внутри, повторные
#    ФИЗИЧЕСКИЕ хиты с капом briar_hit_cap на врага/зону (не dot-ось).
#  - SCRUM-903 Вороний тотем: ≥3-4 активных тотемов baseline (жизнь 6-10с),
#    стационарность, самонаводящиеся вороны (кривая, живое доведение) со
#    взрывом по области; лимит тотемов капится; cleanup без хвостов.
#
# Запуск: Godot --headless --path . --script res://tests/druid_kit_test.gd

const PD := preload("res://scripts/progression_data.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")
const FullFrameAnimationRegistry := preload("res://scripts/full_frame_animation_registry.gd")

const EXPECTED_ROSTER := {
	"druid_ghost_wolf": {"family": "physical", "attack_kind": "melee"},
	"druid_ghost_bear": {"family": "physical", "attack_kind": "melee"},
	"druid_ghost_panther": {"family": "physical", "attack_kind": "melee"},
	"druid_ghost_stag": {"family": "magic", "attack_kind": "ranged"},
	"druid_ghost_lion": {"family": "magic", "attack_kind": "ranged"},
}

var _errors: Array = []
var _holder: Node2D = null


func _initialize() -> void:
	seed(20260710)
	await process_frame

	_check_trait_registry_and_budget_mirror()
	_check_roster_config()
	await _check_trait_hooks_isolation()
	await _check_baseline_pack_and_random_roster()
	await _check_family_stat_scaling()
	await _check_target_distribution()
	await _check_wild_aura_runtime()
	await _check_briar_zone()
	await _check_raven_totem()

	if not _errors.is_empty():
		for e in _errors:
			push_error("Druid kit: %s" % str(e))
		push_error("Druid kit test: %d ошибок." % _errors.size())
		quit(1)
		return
	print("Druid kit test passed (roster 3+2, pack >=5, spread, wild aura, briar phys-hits, raven homing).")
	quit(0)


# --- SCRUM-902: data-driven trait + budget-зеркало ---------------------------------

func _check_trait_registry_and_budget_mirror() -> void:
	var trait_config: Dictionary = PD.class_trait("druid")
	if str(trait_config.get("id", "")) != "wild_force_aura" or str(trait_config.get("title", "")).is_empty():
		_errors.append("trait: у Друида нет trait'а wild_force_aura в CLASS_TRAITS")
	var bonus := PD.class_wild_aura_damage_bonus("druid", 1.279)
	if bonus <= 0.0 or bonus > float(trait_config.get("wild_aura_damage_cap", 0.30)) + 0.0001:
		_errors.append("trait: аура-бонус Друида вне контракта (%.3f)" % bonus)
	if not is_equal_approx(bonus, minf(float(trait_config.get("wild_aura_damage_bonus", 0.0)) * 1.279, float(trait_config.get("wild_aura_damage_cap", 0.30)))):
		_errors.append("trait: формула аура-бонуса разошлась с CLASS_TRAITS")
	for other_class in ["berserk", "soldier", "chemist", "priest", "guitarist", "engineer"]:
		if PD.class_wild_aura_damage_bonus(other_class, 2.0) != 0.0:
			_errors.append("trait: аура протекла классу %s" % other_class)
	# Budget-фактор един с рантаймом: 1 + бонус.
	var factor := PD.class_wild_aura_damage_factor("druid", {"buff_power": 1.279})
	if not is_equal_approx(factor, 1.0 + bonus):
		_errors.append("trait: budget-фактор %.3f != 1+бонус %.3f" % [factor, 1.0 + bonus])
	if not is_equal_approx(PD.class_wild_aura_damage_factor("berserk", {"buff_power": 2.0}), 1.0):
		_errors.append("trait: budget-фактор протёк Берсерку")


func _check_roster_config() -> void:
	var config: Dictionary = PD.weapon("druid", "summon_amulet")
	var roster: Array = config.get("summon_roster", [])
	if roster.size() != 5:
		_errors.append("roster: ожидалось 5 записей, есть %d" % roster.size())
	var melee_physical := 0
	var ranged_magic := 0
	for entry_raw in roster:
		var entry: Dictionary = entry_raw if entry_raw is Dictionary else {}
		var visual_id := str(entry.get("visual_id", ""))
		var expected: Dictionary = EXPECTED_ROSTER.get(visual_id, {})
		if expected.is_empty():
			_errors.append("roster: неизвестная запись '%s'" % visual_id)
			continue
		if str(entry.get("family", "")) != str(expected.get("family")) or str(entry.get("attack_kind", "")) != str(expected.get("attack_kind")):
			_errors.append("roster: %s семья/вид атаки не канон SCRUM-1016" % visual_id)
		if str(entry.get("family", "")) == "physical" and str(entry.get("attack_kind", "")) == "melee":
			melee_physical += 1
		if str(entry.get("family", "")) == "magic" and str(entry.get("attack_kind", "")) == "ranged":
			ranged_magic += 1
		# Арт SCRUM-901/1015/1016 подключён: id резолвится в реестре анимаций.
		if FullFrameAnimationRegistry.sprite_frames_for("ally", visual_id) == null:
			_errors.append("roster: %s не резолвится в FullFrameAnimationRegistry" % visual_id)
	if melee_physical != 3 or ranged_magic != 2:
		_errors.append("roster: состав %d melee-physical / %d ranged-magic вместо 3/2" % [melee_physical, ranged_magic])
	if int(config.get("max_summons", 0)) < 5:
		_errors.append("roster: base max_summons %d < 5 (AC baseline)" % int(config.get("max_summons", 0)))
	# SCRUM-898: никакого звукового канала в kit'е Друида.
	for weapon_id in ["summon_amulet", "briar_staff", "raven_totem"]:
		var wc: Dictionary = PD.weapon("druid", weapon_id)
		if str(wc).find("sound_wave") != -1:
			_errors.append("roster: %s тянет sound_wave-зависимость" % weapon_id)
	# SCRUM-903: терновая зона — физическая, тотем — магический.
	if str(PD.weapon("druid", "briar_staff").get("damage_parameter", "")) != "damage":
		_errors.append("briar: damage_parameter не физический")
	if str(PD.weapon("druid", "raven_totem").get("damage_parameter", "")) != "magic_damage":
		_errors.append("raven: damage_parameter не магический")


func _check_trait_hooks_isolation() -> void:
	var druid := _make_player("druid", "summon_amulet")
	await process_frame
	var aura_mult := float(druid.call("wild_aura_damage_multiplier"))
	if aura_mult <= 1.0:
		_errors.append("trait: wild_aura_damage_multiplier Друида %.3f <= 1.0" % aura_mult)
	var meta_mult := float(druid.call("meta_damage_multiplier", {"damage_type": "magic"}))
	if not is_equal_approx(meta_mult, aura_mult):
		_errors.append("trait: meta_damage_multiplier Друида %.3f != аура %.3f" % [meta_mult, aura_mult])
	_free_player(druid)
	var soldier := _make_player("soldier", "soldier_rifle")
	await process_frame
	if not is_equal_approx(float(soldier.call("wild_aura_damage_multiplier")), 1.0):
		_errors.append("trait: аура протекла Солдату в рантайме")
	soldier.call("_update_class_status_auras")
	if soldier.get_node_or_null("WildForceAuraRing") != null:
		_errors.append("trait: кольцо ауры появилось у Солдата")
	_free_player(soldier)
	await process_frame


# --- SCRUM-902: baseline-стая, случайный ростер ------------------------------------

func _check_baseline_pack_and_random_roster() -> void:
	var druid := _make_player("druid", "summon_amulet")
	var weapon: Node = druid.get("equipped_weapon")
	if weapon == null:
		_errors.append("pack: амулет не выдан")
		_free_player(druid)
		return
	weapon.set_process(false)
	if int(weapon.get("max_summons")) < 5:
		_errors.append("pack: рантайм-лимит %d < 5 без прокачки" % int(weapon.get("max_summons")))
	weapon.call("_prefill_starting_summons")
	await process_frame
	var active: Array = weapon.call("_active_weapon_summons", druid)
	if active.size() < 5:
		_errors.append("pack: прифилл дал %d активных призывов (< 5)" % active.size())
	# Случайность ростера видна между призывами: и семьи, и визуалы различаются.
	var seen_visuals := {}
	var seen_families := {}
	for ally in active:
		seen_visuals[str(ally.get("ally_visual_id"))] = true
		seen_families[str(ally.get("damage_family"))] = true
	for _i in range(60):
		var entry: Dictionary = weapon.call("_selected_roster_entry")
		seen_visuals[str(entry.get("visual_id", ""))] = true
		seen_families[str(entry.get("family", ""))] = true
	if seen_visuals.size() < 5:
		_errors.append("pack: за 60+ выборов выпало %d визуалов из 5" % seen_visuals.size())
	if not (seen_families.has("physical") and seen_families.has("magic")):
		_errors.append("pack: в выборке нет обеих семей урона")
	# Призраки — на живом AnimatedBody (арт SCRUM-1016), не статичный fallback.
	var animated := 0
	for ally in active:
		if bool(ally.call("is_using_animated_ally_visual")):
			animated += 1
	if animated != active.size():
		_errors.append("pack: %d/%d призраков без AnimatedBody-визуала" % [active.size() - animated, active.size()])
	_free_player(druid)
	await process_frame
	if not get_nodes_in_group("allies").is_empty():
		_errors.append("pack: после ресета сцены остались призывы (%d)" % get_nodes_in_group("allies").size())


func _check_family_stat_scaling() -> void:
	var druid := _make_player("druid", "summon_amulet")
	var weapon: Node = druid.get("equipped_weapon")
	weapon.set_process(false)
	await process_frame
	var melee_entry := {"visual_id": "druid_ghost_wolf", "family": "physical", "attack_kind": "melee"}
	var ranged_entry := {"visual_id": "druid_ghost_stag", "family": "magic", "attack_kind": "ranged"}
	var melee_base := float((weapon.call("_summon_profile", druid, melee_entry) as Dictionary).get("damage", 0.0))
	var ranged_base := float((weapon.call("_summon_profile", druid, ranged_entry) as Dictionary).get("damage", 0.0))
	var stats: Dictionary = druid.get("stats")
	stats["strength"] = float(stats.get("strength", 3.0)) + 30.0
	druid.set("stats", stats)
	druid.call("_apply_stat_scaling", false, druid.get("max_health"))
	var melee_str := float((weapon.call("_summon_profile", druid, melee_entry) as Dictionary).get("damage", 0.0))
	var ranged_str := float((weapon.call("_summon_profile", druid, ranged_entry) as Dictionary).get("damage", 0.0))
	if melee_str <= melee_base * 1.5:
		_errors.append("family: +30 Силы не подняли melee-урон (%.2f -> %.2f)" % [melee_base, melee_str])
	if absf(ranged_str - ranged_base) > ranged_base * 0.05:
		_errors.append("family: Сила протекла в magic-духов (%.2f -> %.2f)" % [ranged_base, ranged_str])
	stats["strength"] = float(stats.get("strength", 33.0)) - 30.0
	stats["intelligence"] = float(stats.get("intelligence", 4.0)) + 30.0
	druid.set("stats", stats)
	druid.call("_apply_stat_scaling", false, druid.get("max_health"))
	var melee_int := float((weapon.call("_summon_profile", druid, melee_entry) as Dictionary).get("damage", 0.0))
	var ranged_int := float((weapon.call("_summon_profile", druid, ranged_entry) as Dictionary).get("damage", 0.0))
	if ranged_int <= ranged_base * 1.5:
		_errors.append("family: +30 Интеллекта не подняли magic-урон (%.2f -> %.2f)" % [ranged_base, ranged_int])
	# Интеллект легитимно чуть питает ВСЮ стаю через generic summon-атрибуты
	# (summon_amount/attribute_damage, SCRUM-546, кап +40%), но НЕ через канал
	# семьи: melee-прирост обязан быть кратно меньше magic-прироста.
	if melee_int > melee_base * 1.30:
		_errors.append("family: Интеллект протёк в melee-зверей сверх generic-скейла (%.2f -> %.2f)" % [melee_base, melee_int])
	if (melee_int / maxf(melee_base, 0.01)) > (ranged_int / maxf(ranged_base, 0.01)) * 0.75:
		_errors.append("family: интеллект-прирост melee сравним с magic (семьи не различаются)")
	# Ranged-профиль: дистанция снаряда и одиночный (без splash) удар.
	var ranged_profile: Dictionary = weapon.call("_summon_profile", druid, ranged_entry)
	if float(ranged_profile.get("attack_range", 0.0)) < 120.0:
		_errors.append("family: ranged-дух без дистанции (%.0f)" % float(ranged_profile.get("attack_range", 0.0)))
	if float(ranged_profile.get("aoe_radius", 99.0)) != 0.0:
		_errors.append("family: ranged-дух получил melee-splash")
	_free_player(druid)
	await process_frame


func _check_target_distribution() -> void:
	var druid := _make_player("druid", "summon_amulet")
	var weapon: Node = druid.get("equipped_weapon")
	weapon.set_process(false)
	var enemy_a := _make_dummy_enemy(druid.global_position + Vector2(220, 0))
	var enemy_b := _make_dummy_enemy(druid.global_position + Vector2(-200, 120))
	var enemy_c := _make_dummy_enemy(druid.global_position + Vector2(60, -230))
	await process_frame
	for _i in range(5):
		weapon.call("_summon", false)
	weapon.call("_command_existing_summons")
	var assigned := {}
	var owned := 0
	for ally in get_nodes_in_group("allies"):
		if ally.get("owner_node") != druid:
			continue
		owned += 1
		var target = ally.get("command_target")
		if target != null and is_instance_valid(target):
			assigned[(target as Node).get_instance_id()] = true
	if owned < 5:
		_errors.append("spread: призвано %d духов вместо 5" % owned)
	if assigned.size() < 2:
		_errors.append("spread: стая догпайлит одну цель (%d уникальных из 3)" % assigned.size())
	# Единственная цель — весь фокус в неё.
	enemy_b.queue_free()
	enemy_c.queue_free()
	await process_frame
	weapon.call("_command_existing_summons")
	for ally in get_nodes_in_group("allies"):
		if ally.get("owner_node") != druid:
			continue
		var target = ally.get("command_target")
		if target == null or not is_instance_valid(target) or target != enemy_a:
			_errors.append("spread: при единственной цели дух не сфокусился")
			break
	enemy_a.queue_free()
	_free_player(druid)
	await process_frame


# --- SCRUM-902: аура дикой силы в рантайме -----------------------------------------

func _check_wild_aura_runtime() -> void:
	var druid := _make_player("druid", "summon_amulet")
	var weapon: Node = druid.get("equipped_weapon")
	weapon.set_process(false)
	await process_frame
	weapon.call("_summon", false)
	var near_ally: Node2D = null
	for ally in get_nodes_in_group("allies"):
		if ally.get("owner_node") == druid:
			near_ally = ally
	if near_ally == null:
		_errors.append("aura: не удалось призвать духа для проверки")
		_free_player(druid)
		return
	near_ally.global_position = druid.global_position + Vector2(60, 0)
	var enemy := _make_dummy_enemy(druid.global_position + Vector2(90, 0))
	var foreign_ally := _make_dummy_ally(druid.global_position + Vector2(40, 40))
	await process_frame
	druid.set("_status_aura_cooldown_left", 0.0)
	druid.call("_update_class_status_auras")
	var ring := druid.get_node_or_null("WildForceAuraRing")
	if ring == null:
		_errors.append("aura: нет видимого кольца радиуса WildForceAuraRing")
	else:
		var ring_radius := float(ring.get("radius"))
		if not is_equal_approx(ring_radius, float(druid.call("wild_aura_radius"))) or ring_radius <= 0.0:
			_errors.append("aura: радиус кольца %.1f != эффективному" % ring_radius)
	if not StatusEffects.has_status(near_ally, "wild_force_aura"):
		_errors.append("aura: свой призыв в радиусе не получил бафф")
	elif StatusEffects.damage_multiplier(near_ally) <= 1.0:
		_errors.append("aura: бафф призыва не усиливает урон (%.3f)" % StatusEffects.damage_multiplier(near_ally))
	if StatusEffects.has_status(enemy, "wild_force_aura"):
		_errors.append("aura: бафф протёк ВРАГУ внутри радиуса")
	if StatusEffects.has_status(foreign_ally, "wild_force_aura"):
		_errors.append("aura: бафф протёк чужому союзнику")
	# Призыв ЗА радиусом не баффается (позиционный контракт).
	var far_radius := float(druid.call("wild_aura_radius")) + 200.0
	near_ally.global_position = druid.global_position + Vector2(far_radius, 0)
	await _wait_status_expiry()
	druid.set("_status_aura_cooldown_left", 0.0)
	druid.call("_update_class_status_auras")
	if StatusEffects.has_status(near_ally, "wild_force_aura"):
		_errors.append("aura: бафф держится на призыве вне радиуса")
	enemy.queue_free()
	foreign_ally.queue_free()
	_free_player(druid)
	await process_frame


# --- SCRUM-903: терновая зона ------------------------------------------------------

func _check_briar_zone() -> void:
	var druid := _make_player("druid", "briar_staff")
	var weapon: Node = druid.get("equipped_weapon")
	weapon.set_process(false)
	await process_frame
	if not bool(weapon.get("briar_zone")):
		_errors.append("briar: сцена/конфиг не включили briar_zone")
	if not bool(weapon.get("pool_translucent")):
		_errors.append("briar: зона не полупрозрачна (pool_translucent)")
	var zone_center: Vector2 = druid.global_position + Vector2(240, 0)
	var inside := _make_dummy_enemy(zone_center + Vector2(30, 0))
	var outside := _make_dummy_enemy(zone_center + Vector2(float(weapon.get("aoe_radius")) * 0.7 + 150.0, 0))
	weapon.call("_spawn_damage_pool", zone_center, 1.0)
	await process_frame
	var pool: Node2D = null
	for cloud in get_nodes_in_group("chemist_clouds"):
		pool = cloud
	if pool == null:
		_errors.append("briar: зона не заспавнилась")
		_free_player(druid)
		return
	var pool_sprite := pool.get_node_or_null("PoolVisual/PoolSprite") as Sprite2D
	if pool_sprite == null or pool_sprite.modulate.a > 0.55:
		_errors.append("briar: спрайт зоны не полупрозрачный (a=%.2f)" % (pool_sprite.modulate.a if pool_sprite != null else -1.0))
	var hit_cap := int(weapon.get("briar_hit_cap"))
	var expected_hit := float(weapon.get("damage")) * float(weapon.get("briar_hit_multiplier")) * float(druid.call("meta_damage_multiplier", {"damage_type": "physical"}))
	weapon.call("_briar_zone_tick", pool)
	var after_one := float(inside.get_meta("damage_taken"))
	if absf(after_one - expected_hit) > expected_hit * 0.02 or after_one <= 0.0:
		_errors.append("briar: первый хит %.2f != ожидаемого физ-хита %.2f" % [after_one, expected_hit])
	if not StatusEffects.has_status(inside, "briar_zone_slow"):
		_errors.append("briar: враг в зоне не замедлен")
	elif StatusEffects.speed_multiplier(inside) >= 1.0:
		_errors.append("briar: слоу не снижает скорость (%.2f)" % StatusEffects.speed_multiplier(inside))
	if float(outside.get_meta("damage_taken")) > 0.0 or StatusEffects.has_status(outside, "briar_zone_slow"):
		_errors.append("briar: зона зацепила врага снаружи")
	# КАП повторных хитов: cap+3 тика дают ровно cap хитов с одной зоны.
	for _i in range(hit_cap + 3):
		weapon.call("_briar_zone_tick", pool)
	var total := float(inside.get_meta("damage_taken"))
	if absf(total - expected_hit * float(hit_cap)) > expected_hit * 0.05:
		_errors.append("briar: кап не сработал — %.2f вместо %.2f (cap %d)" % [total, expected_hit * float(hit_cap), hit_cap])
	# Физическая ось: хиты растут от Силы, dot-стат Знание их не трогает.
	var stats: Dictionary = druid.get("stats")
	stats["knowledge"] = float(stats.get("knowledge", 5.0)) + 30.0
	druid.set("stats", stats)
	druid.call("_apply_stat_scaling", false, druid.get("max_health"))
	var hit_after_knowledge := float(weapon.get("damage")) * float(weapon.get("briar_hit_multiplier"))
	if absf(hit_after_knowledge - expected_hit / float(druid.call("meta_damage_multiplier", {"damage_type": "physical"}))) > expected_hit * 0.05:
		_errors.append("briar: Знание (dot-ось) изменило физ-хит зоны")
	inside.queue_free()
	outside.queue_free()
	_free_player(druid)
	await process_frame


# --- SCRUM-903: вороний тотем ------------------------------------------------------

func _check_raven_totem() -> void:
	var druid := _make_player("druid", "raven_totem")
	var weapon: Node = druid.get("equipped_weapon")
	weapon.set_process(false)
	await process_frame
	var lifetime := float(weapon.get("amp_lifetime"))
	if lifetime < 6.0 or lifetime > 10.0:
		_errors.append("raven: baseline-жизнь тотема %.1f вне 6-10с" % lifetime)
	var totem_limit := int(weapon.get("max_summons"))
	if totem_limit < 3:
		_errors.append("raven: baseline-лимит тотемов %d < 3" % totem_limit)
	var enemy := _make_dummy_enemy(druid.global_position + Vector2(260, 40))
	var neighbor := _make_dummy_enemy(druid.global_position + Vector2(260, 40) + Vector2(60, 0))
	var far := _make_dummy_enemy(druid.global_position + Vector2(260, 40) + Vector2(float(weapon.get("raven_explosion_radius")) + 220.0, 0))
	await process_frame
	for _i in range(totem_limit + 2):
		weapon.call("_attack")
	await process_frame
	var totems: Array = []
	for deployable in get_nodes_in_group("deployed_sound_amps"):
		totems.append(deployable)
	if totems.size() != totem_limit:
		_errors.append("raven: активных тотемов %d вместо капа %d" % [totems.size(), totem_limit])
	# Стационарность: тотем не двигается между кадрами.
	if not totems.is_empty():
		var totem := totems[0] as Node2D
		var anchor := totem.global_position
		await process_frame
		await process_frame
		if totem.global_position.distance_to(anchor) > 0.5:
			_errors.append("raven: тотем уехал с точки деплоя")
	# Самонаведение: кривая полёта отклоняется от прямой и ведёт в живую цель.
	var start: Vector2 = druid.global_position + Vector2(120, -60)
	var raven := _spawn_probe_raven(weapon, druid, start, enemy)
	if raven != null:
		weapon.call("_step_raven_flight", 0.5, raven.get_instance_id(), enemy.get_instance_id(), start, 1.0)
		var straight_mid: Vector2 = (start + enemy.global_position) * 0.5
		if raven.global_position.distance_to(straight_mid) < 12.0:
			_errors.append("raven: полёт прямой, кривизна не видна (%.1fpx)" % raven.global_position.distance_to(straight_mid))
		# Живое доведение: цель сместилась — конец кривой пошёл за ней.
		enemy.global_position += Vector2(0, 140)
		weapon.call("_step_raven_flight", 1.0, raven.get_instance_id(), enemy.get_instance_id(), start, 1.0)
		if raven.global_position.distance_to(enemy.global_position) > 4.0:
			_errors.append("raven: ворон не довёлся до сместившейся цели")
		# Сосед — вплотную к ТОЧКЕ ВЗРЫВА (цель уже доведена), дальний — за радиусом.
		neighbor.global_position = enemy.global_position + Vector2(50, 0)
		far.global_position = enemy.global_position + Vector2(float(weapon.get("raven_explosion_radius")) + 220.0, 0)
		weapon.call("_resolve_raven_impact", raven.get_instance_id(), druid.get_instance_id())
		if float(enemy.get_meta("damage_taken")) <= 0.0:
			_errors.append("raven: взрыв не задел цель")
		if float(neighbor.get_meta("damage_taken")) <= 0.0:
			_errors.append("raven: взрыв не задел соседа в радиусе")
		if float(far.get_meta("damage_taken")) > 0.0:
			_errors.append("raven: взрыв достал врага за радиусом")
		await process_frame
		if is_instance_valid(raven) and not raven.is_queued_for_deletion():
			_errors.append("raven: снаряд не освободился после взрыва")
	# Нет целей — тотем молчит (без воронов в пустоту).
	enemy.queue_free()
	neighbor.queue_free()
	far.queue_free()
	await process_frame
	var effects_before: Array = get_nodes_in_group("player_weapon_effects")
	weapon.call("_launch_totem_raven", druid, druid.global_position + Vector2(100, 0))
	if get_nodes_in_group("player_weapon_effects").size() != effects_before.size():
		_errors.append("raven: выстрел без целей породил эффект")
	# Cleanup: смена/снятие оружия зачищает тотемы и воронов.
	weapon.call("cleanup_effects")
	await process_frame
	await process_frame
	if not get_nodes_in_group("deployed_sound_amps").is_empty():
		_errors.append("raven: после cleanup остались тотемы")
	_free_player(druid)
	await process_frame


func _spawn_probe_raven(weapon: Node, druid: Node2D, start: Vector2, target: Node2D) -> Node2D:
	var before: Array = get_nodes_in_group("player_weapon_effects")
	weapon.call("_launch_totem_raven", druid, start)
	for effect in get_nodes_in_group("player_weapon_effects"):
		if not before.has(effect) and effect is Node2D:
			return effect
	_errors.append("raven: ворон не заспавнился по живой цели")
	return null


# --- helpers -----------------------------------------------------------------------

func _ensure_holder() -> Node2D:
	if _holder == null or not is_instance_valid(_holder):
		_holder = Node2D.new()
		_holder.name = "DruidKitScene"
		root.add_child(_holder)
		current_scene = _holder
	return _holder


func _make_player(character_id: String, weapon_id := "") -> Node2D:
	var holder := _ensure_holder()
	var player := (load("res://scenes/Player.tscn") as PackedScene).instantiate() as Node2D
	holder.add_child(player)
	player.global_position = Vector2(600, 400)
	player.call("configure_character", character_id, weapon_id)
	return player


# Полный сброс «сцены» между блоками — заодно проверяет AC про отсутствие
# хвостов (призывы/зоны/тотемы паренчены в current_scene и уходят с ним).
func _free_player(player: Node2D) -> void:
	if player != null and is_instance_valid(player):
		player.queue_free()
	if _holder != null and is_instance_valid(_holder):
		_holder.queue_free()
	_holder = null
	current_scene = null


func _wait_status_expiry() -> void:
	# Статусы ауры живут 0.85с; тикаем их вручную до спадания.
	for ally in get_nodes_in_group("allies"):
		if is_instance_valid(ally):
			StatusEffects.tick(ally, 1.0)
	await process_frame


func _make_dummy_enemy(pos: Vector2) -> Node2D:
	var enemy := Area2D.new()
	enemy.add_to_group("enemies")
	enemy.set_meta("damage_taken", 0.0)
	enemy.set_script(_dummy_enemy_script())
	_ensure_holder().add_child(enemy)
	enemy.global_position = pos
	return enemy


func _make_dummy_ally(pos: Vector2) -> Node2D:
	# Чужой союзник (owner_node == null) — аура не должна его баффать.
	var ally := Node2D.new()
	ally.add_to_group("allies")
	_ensure_holder().add_child(ally)
	ally.global_position = pos
	return ally


func _dummy_enemy_script() -> GDScript:
	var src := """
extends Area2D
var health := 600.0
var max_health := 600.0
func take_damage(amount: float, _feedback := {}) -> bool:
	set_meta(\"damage_taken\", float(get_meta(\"damage_taken\", 0.0)) + amount)
	health -= amount
	return true
func apply_knockback(_impulse: Vector2) -> void:
	pass
"""
	var gd := GDScript.new()
	gd.source_code = src
	gd.reload()
	return gd
