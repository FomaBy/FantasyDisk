extends SceneTree

# SCRUM-897: фокусный гейт редизайна кита Вора.
#
# Trait «Воровская хватка»: сильно увеличенный СТАРТОВЫЙ радиус подбора — Вор
#   заметно (>=1.5x) магнитит добычу против любого другого класса; flat-источники
#   забега идут поверх БЕЗ усиления (анти-runaway).
# «Кошель Рикошета»: цепь из 6 прыжков (кап прогрессии COIN_CHAIN_HARD_CAP=8),
#   урон убывает МОНОТОННО до ровно 50% ролла на последнем задуманном прыжке;
#   золото начисляется мгновенно (gain_money, без спавна пикапа) детерминированно
#   с первых steal_hits целей.
# «Отравленный Кинжал»: фантомный удар из тени БЕЗ движения героя; встроенное
#   короткое окно паралича-яда (кап, босс/элита-резист); позиционный
#   backstab-пейофф x1.35, когда цель отдаёт спину фантому.
# «Дымовая Бомба»: брошенный снаряд с отложенной детонацией; на взрыве ОДНО
#   AoE-событие урона, затем НЕдамажащее облако; уклонение действует только
#   внутри облака, суммарный шанс в дыму капится SMOKE_CLOUD_DODGE_CAP=0.90.
#
# Запуск: Godot --headless --path . --script res://tests/thief_kit_test.gd

const ClassWeapon := preload("res://scripts/class_weapon.gd")
const PD := preload("res://scripts/progression_data.gd")

const EPS := 0.001


class MockOwner extends CharacterBody2D:
	var derived_parameters := {
		"damage": 40.0,
		"magic_damage": 25.0,
		"crit_chance": 0.0,
		"crit_damage_multiplier": 1.0,
		"dot_damage": 5.0,
		"dot_speed": 2.0,
	}
	var run_modifiers := {}
	var stats := {}
	var health := 70.0
	var max_health := 100.0
	var money := 0
	var smoke_cloud_registrations: Array = []

	func gain_money(amount: int) -> void:
		money += amount

	# Рекордер регистрации дым-облака (контракт ClassWeapon._detonate_smoke_bomb):
	# сам позиционный расчёт уклонения проверяется на настоящем Player ниже.
	func register_smoke_cloud(center: Vector2, radius: float, duration: float, cloud_dodge_bonus: float) -> void:
		smoke_cloud_registrations.append({
			"center": center,
			"radius": radius,
			"duration": duration,
			"dodge_bonus": cloud_dodge_bonus,
		})


class TypedEnemy extends Node2D:
	var total_damage := 0.0
	var hits: Array = []

	func take_damage(amount: float, feedback: Dictionary = {}) -> void:
		total_damage += amount
		hits.append({"amount": amount, "type": str(feedback.get("damage_type", ""))})

	# Маркер для ClassWeapon._take_damage_accepts_feedback: без него оружие шлёт
	# 1-арг take_damage и тип канала теряется.
	func _show_combat_feedback(_amount: float = 0.0, _feedback: Dictionary = {}) -> void:
		pass


# Враг с живой скоростью: направление velocity = направление «взгляда» для
# позиционного backstab-условия (_is_backstab_hit).
class MovingEnemy extends CharacterBody2D:
	var total_damage := 0.0
	var hits: Array = []

	func take_damage(amount: float, feedback: Dictionary = {}) -> void:
		total_damage += amount
		hits.append({"amount": amount, "type": str(feedback.get("damage_type", ""))})

	func _show_combat_feedback(_amount: float = 0.0, _feedback: Dictionary = {}) -> void:
		pass


func _initialize() -> void:
	var errors: Array = []
	_test_trait_registry_contract(errors)
	_test_trait_pickup_magnet(errors)
	_test_kit_data_contracts(errors)
	await _test_coin_chain_falloff_and_instant_money(errors)
	await _test_coin_chain_hard_cap(errors)
	await _test_poison_dagger_control_and_backstab(errors)
	await _test_poison_dagger_boss_resist_and_cap(errors)
	await _test_smoke_bomb_detonation_and_cloud(errors)
	await _test_smoke_cloud_player_dodge(errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Thief kit: %s" % str(error))
		push_error("Thief kit test failed with %d error(s)." % errors.size())
		quit(1)
		return
	print("Thief kit test passed (SCRUM-897).")
	quit(0)


# --- Trait «Воровская хватка» ---


func _test_trait_registry_contract(errors: Array) -> void:
	var trait_config: Dictionary = PD.CLASS_TRAITS.get("thief", {})
	if trait_config.is_empty():
		errors.append("trait: нет записи CLASS_TRAITS.thief")
		return
	if str(trait_config.get("title", "")) != "Воровская хватка":
		errors.append("trait: title '%s' != 'Воровская хватка'" % str(trait_config.get("title", "")))
	if float(trait_config.get("pickup_radius_multiplier", 0.0)) < 1.5:
		errors.append("trait: pickup_radius_multiplier %.2f < 1.5 — «сильно увеличенный» радиус не читается" % float(trait_config.get("pickup_radius_multiplier", 0.0)))


func _thief_pickup_radius(run_modifiers: Dictionary) -> float:
	var config: Dictionary = PD.weapon("thief", "thief_coin_pouch")
	return float(PD.derived_parameters(PD.base_stats("thief"), run_modifiers, config).get("pickup_radius", 0.0))


func _test_trait_pickup_magnet(errors: Array) -> void:
	var thief_pickup := _thief_pickup_radius({})
	# AC: стартовый радиус Вора ЗАМЕТНО больше любого обычного класса.
	for character_id in PD.character_ids():
		if str(character_id) == "thief":
			continue
		var other_config: Dictionary = PD.weapon(str(character_id), str(PD.weapon_ids(str(character_id))[0]))
		var other_pickup := float(PD.derived_parameters(PD.base_stats(str(character_id)), {}, other_config).get("pickup_radius", 0.0))
		if thief_pickup < other_pickup * 1.5:
			errors.append("trait: pickup Вора %.1f < 1.5x pickup %s (%.1f)" % [thief_pickup, character_id, other_pickup])
	# Flat-источники (артефакт «Магнитный кошель» +90) добавляются линейно,
	# БЕЗ trait-усиления: рост ограничен, множитель только на стартовую часть.
	var flat_delta := _thief_pickup_radius({"pickup_radius_flat": 90.0}) - thief_pickup
	if absf(flat_delta - 90.0) > EPS:
		errors.append("trait: flat +90 дал дельту %.2f (ожидалось ровно 90 — без усиления множителем)" % flat_delta)


# --- Контракты данных кита ---


func _test_kit_data_contracts(errors: Array) -> void:
	var coin: Dictionary = PD.weapon("thief", "thief_coin_pouch")
	var dagger: Dictionary = PD.weapon("thief", "thief_shadow_cloak")
	var smoke: Dictionary = PD.weapon("thief", "thief_smoke_bomb")
	# Три различных режима — ниши кита не слипаются.
	var modes := {}
	for config in [coin, dagger, smoke]:
		modes[str(config.get("attack_mode", ""))] = true
	if modes.size() != 3:
		errors.append("кит: attack_mode не уникальны: %s" % str(modes.keys()))
	# Монета: базовая цепь в полосе AC 5..8, хвост ровно 50%, детерминированное воровство.
	var chain := int(coin.get("projectile_count", 0))
	if chain < 5 or chain > 8:
		errors.append("монета: базовая цепь %d вне полосы 5..8" % chain)
	if absf(float(coin.get("damage_falloff", 0.0)) - 0.5) > EPS:
		errors.append("монета: damage_falloff %.2f != 0.5 (доля последнего прыжка)" % float(coin.get("damage_falloff", 0.0)))
	if int(coin.get("steal_hits", 0)) < 1 or int(coin.get("steal_money", 0)) < 1:
		errors.append("монета: steal_hits/steal_money не заданы — мгновенная экономика потеряна")
	if ClassWeapon.COIN_CHAIN_HARD_CAP > 8 or ClassWeapon.COIN_CHAIN_HARD_CAP < chain:
		errors.append("монета: COIN_CHAIN_HARD_CAP %d вне полосы [projectile_count..8]" % ClassWeapon.COIN_CHAIN_HARD_CAP)
	# Кинжал: player-facing rename + встроенное КОРОТКОЕ окно контроля.
	if str(dagger.get("title", "")) != "Отравленный Кинжал":
		errors.append("кинжал: title '%s' != 'Отравленный Кинжал'" % str(dagger.get("title", "")))
	var paralysis := float(dagger.get("poison_paralysis_duration", 0.0))
	if paralysis <= 0.0:
		errors.append("кинжал: poison_paralysis_duration не задан — контроль не встроен")
	if paralysis >= float(dagger.get("fire_interval", 0.0)):
		errors.append("кинжал: базовое окно паралича %.2f >= fire_interval %.2f — контроль без вложений не должен быть непрерывным" % [paralysis, float(dagger.get("fire_interval", 0.0))])
	if ClassWeapon.POISON_PARALYSIS_CAP > 2.0:
		errors.append("кинжал: POISON_PARALYSIS_CAP %.2f > 2.0 — окно контроля не ограничено коротким" % ClassWeapon.POISON_PARALYSIS_CAP)
	if ClassWeapon.POISON_PARALYSIS_BOSS_FACTOR >= 1.0:
		errors.append("кинжал: нет босс/элита-резиста контроля")
	# Дым: отложенный бросок, живучее облако, весомый бонус только-в-облаке.
	if float(smoke.get("grenade_delay", 0.0)) < 0.4:
		errors.append("дым: grenade_delay %.2f < 0.4 — бросок/фитиль не читается" % float(smoke.get("grenade_delay", 0.0)))
	if float(smoke.get("smoke_duration", 0.0)) < 2.0:
		errors.append("дым: smoke_duration %.2f < 2.0 — позиционное облако слишком короткое" % float(smoke.get("smoke_duration", 0.0)))
	if float(smoke.get("dodge_bonus", 0.0)) < 0.3:
		errors.append("дым: dodge_bonus %.2f < 0.3 — облако не ощущается защитным" % float(smoke.get("dodge_bonus", 0.0)))
	# Кап в дыму: 0.90, достижим при тяжёлом dodge-билде (базовый кап + облако +
	# артефакт «Дымный тайник» +0.12 покрывают кап), но не превышаем.
	if absf(PD.SMOKE_CLOUD_DODGE_CAP - 0.90) > EPS:
		errors.append("дым: SMOKE_CLOUD_DODGE_CAP %.2f != 0.90" % PD.SMOKE_CLOUD_DODGE_CAP)
	if PD.SURVIVABILITY_DODGE_CAP + float(smoke.get("dodge_bonus", 0.0)) + 0.12 < PD.SMOKE_CLOUD_DODGE_CAP:
		errors.append("дым: кап 0.90 недостижим даже при полном вложении (база %.2f + облако %.2f + артефакт 0.12)" % [PD.SURVIVABILITY_DODGE_CAP, float(smoke.get("dodge_bonus", 0.0))])
	# Тюнинг не в клэмп-сатурации: кит реально балансируется бюджетом.
	for config in [coin, dagger, smoke]:
		var tuned := float(config.get("budget_damage_multiplier", 1.0))
		if tuned <= 0.30 or tuned >= 2.75:
			errors.append("%s: budget_damage_multiplier %.3f у границы клэмпа [0.28..2.80]" % [str(config.get("id")), tuned])


# --- Общий стенд ---


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


func _new_weapon(owner: MockOwner, weapon_id: String) -> ClassWeapon:
	var weapon := ClassWeapon.new()
	owner.add_child(weapon)
	weapon.configure_weapon(PD.weapon("thief", weapon_id))
	weapon.set_process(false)
	# Квирк headless-прогона: ПЕРВОМУ ClassWeapon рана движок может вернуть
	# включённый _process на первом кадре (несмотря на set_process(false)) —
	# авто-атака задваивает выстрел. Глушим гигантским кулдауном: тесты зовут
	# _fire_* напрямую и _cooldown не трогают.
	weapon.set("_cooldown", 1.0e9)
	return weapon


func _new_enemy(holder: Node2D, position: Vector2) -> TypedEnemy:
	var enemy := TypedEnemy.new()
	enemy.add_to_group("enemies")
	holder.add_child(enemy)
	enemy.global_position = position
	return enemy


func _new_moving_enemy(holder: Node2D, position: Vector2, velocity: Vector2) -> MovingEnemy:
	var enemy := MovingEnemy.new()
	enemy.add_to_group("enemies")
	holder.add_child(enemy)
	enemy.global_position = position
	enemy.velocity = velocity
	return enemy


func _cleanup(holder: Node2D) -> void:
	holder.queue_free()
	current_scene = null
	await process_frame
	await process_frame


func _paralysis_window(enemy: Node) -> float:
	if not enemy.has_meta("status_effects"):
		return 0.0
	var statuses: Dictionary = enemy.get_meta("status_effects")
	var status: Dictionary = statuses.get("poison_paralysis", {})
	return float(status.get("duration", 0.0))


# --- «Кошель Рикошета»: цепь, спад, мгновенное золото ---


func _test_coin_chain_falloff_and_instant_money(errors: Array) -> void:
	var holder := _new_scene("Scrum897CoinChain")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "thief_coin_pouch")
	var enemies: Array = []
	for enemy_index in range(8):
		enemies.append(_new_enemy(holder, owner.global_position + Vector2(140.0 + 90.0 * enemy_index, 0.0)))
	await process_frame

	var pickups_before := get_nodes_in_group("pickups").size()
	weapon.call("_fire_coin_ricochet", owner, enemies[0], Vector2.RIGHT)
	await process_frame

	# Ровно projectile_count (6) целей цепи: 5..8 прыжков по AC, дальше цепь обрывается.
	var hit_count := 0
	for enemy in enemies:
		if (enemy as TypedEnemy).total_damage > EPS:
			hit_count += 1
	if hit_count != 6:
		errors.append("монета: цепь задела %d целей, ожидалось 6 (projectile_count)" % hit_count)
	if (enemies[6] as TypedEnemy).total_damage > EPS or (enemies[7] as TypedEnemy).total_damage > EPS:
		errors.append("монета: урон за пределами задуманной цепи (7-я/8-я цель)")
	# Монотонный спад и хвост ровно 50% ролла (мок: ролл = 40, крита нет).
	var previous_damage := INF
	for hit_index in range(6):
		var hit_damage := (enemies[hit_index] as TypedEnemy).total_damage
		if hit_damage >= previous_damage - EPS:
			errors.append("монета: спад не монотонный на прыжке %d (%.2f -> %.2f)" % [hit_index, previous_damage, hit_damage])
		previous_damage = hit_damage
	if absf((enemies[0] as TypedEnemy).total_damage - 40.0) > EPS:
		errors.append("монета: первый прыжок %.2f != полного ролла 40" % (enemies[0] as TypedEnemy).total_damage)
	if absf((enemies[5] as TypedEnemy).total_damage - 20.0) > EPS:
		errors.append("монета: последний прыжок %.2f != 50%% ролла (20)" % (enemies[5] as TypedEnemy).total_damage)
	# Экономика: золото начислено МГНОВЕННО (без пикапов), детерминированно
	# steal_hits (3) x steal_money (1).
	if owner.money != 3:
		errors.append("монета: мгновенное золото %d != 3 (steal_hits x steal_money)" % owner.money)
	if get_nodes_in_group("pickups").size() != pickups_before:
		errors.append("монета: воровство заспавнило money-пикап — золото обязано начисляться напрямую")
	# SCRUM-961 «Счастливая монета»: +1 золото с каждой обворованной цели.
	owner.money = 0
	owner.run_modifiers = {"coin_steal_bonus": 1.0}
	weapon.call("_fire_coin_ricochet", owner, enemies[0], Vector2.RIGHT)
	await process_frame
	if owner.money != 6:
		errors.append("монета: с coin_steal_bonus золото %d != 6 ((1+1) x 3 цели)" % owner.money)
	weapon.cleanup_effects()
	await _cleanup(holder)


func _test_coin_chain_hard_cap(errors: Array) -> void:
	var holder := _new_scene("Scrum897CoinCap")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "thief_coin_pouch")
	# Прогрессия пытается раздуть цепь до 6+99: кап обязан удержать 8.
	owner.run_modifiers = {"coin_extra_bounces": 99.0}
	var enemies: Array = []
	for enemy_index in range(12):
		enemies.append(_new_enemy(holder, owner.global_position + Vector2(140.0 + 80.0 * enemy_index, 0.0)))
	await process_frame

	weapon.call("_fire_coin_ricochet", owner, enemies[0], Vector2.RIGHT)
	await process_frame
	var hit_count := 0
	for enemy in enemies:
		if (enemy as TypedEnemy).total_damage > EPS:
			hit_count += 1
	if hit_count != ClassWeapon.COIN_CHAIN_HARD_CAP:
		errors.append("монета: с раздутой прогрессией цепь задела %d целей, ожидался кап %d" % [hit_count, ClassWeapon.COIN_CHAIN_HARD_CAP])
	# Хвост капнутой цепи держит те же 50% ролла — спад пересчитан на полную длину.
	if absf((enemies[ClassWeapon.COIN_CHAIN_HARD_CAP - 1] as TypedEnemy).total_damage - 20.0) > EPS:
		errors.append("монета: хвост капнутой цепи %.2f != 20 (50%% ролла)" % (enemies[ClassWeapon.COIN_CHAIN_HARD_CAP - 1] as TypedEnemy).total_damage)
	weapon.cleanup_effects()
	await _cleanup(holder)


# --- «Отравленный Кинжал»: контроль без телепорта, backstab-условие ---


func _test_poison_dagger_control_and_backstab(errors: Array) -> void:
	var holder := _new_scene("Scrum897PoisonDagger")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "thief_shadow_cloak")
	# Чейзер: идёт НА героя (скорость влево) — отдаёт спину фантому за собой.
	var chaser := _new_moving_enemy(holder, owner.global_position + Vector2(200.0, 0.0), Vector2(-60.0, 0.0))
	# Сосед в сплэш-радиусе точки удара (фантом на 46px за целью).
	var neighbor := _new_enemy(holder, owner.global_position + Vector2(276.0, 0.0))
	await process_frame

	var owner_position_before: Vector2 = owner.global_position
	weapon.call("_fire_shadow_backstab", owner, chaser, Vector2.RIGHT)
	await process_frame
	# Герой НЕ двигается и НЕ телепортируется.
	if owner.global_position.distance_to(owner_position_before) > EPS:
		errors.append("кинжал: герой сместился на %.3f (движение/телепорт запрещены)" % owner.global_position.distance_to(owner_position_before))
	# Удар в спину: 40 x 1.22 x 1.35 (цель смотрит прочь от фантома).
	var expected_backstab := 40.0 * ClassWeapon.BACKSTAB_STRIKE_MULTIPLIER * ClassWeapon.BACKSTAB_POSITIONAL_MULTIPLIER
	if absf(chaser.total_damage - expected_backstab) > EPS:
		errors.append("кинжал: удар в спину %.2f != %.2f (1.22 x 1.35 ролла)" % [chaser.total_damage, expected_backstab])
	# Встроенный контроль: окно паралича на цели и соседе, скорость к минимуму движка.
	if absf(_paralysis_window(chaser) - 0.85) > EPS:
		errors.append("кинжал: окно паралича цели %.2f != 0.85 (базовое, без артефакта)" % _paralysis_window(chaser))
	if absf(StatusEffects.speed_multiplier(chaser) - 0.25) > EPS:
		errors.append("кинжал: множитель скорости в параличе %.2f != 0.25 (кламп движка)" % StatusEffects.speed_multiplier(chaser))
	var expected_neighbor := 40.0 * ClassWeapon.BACKSTAB_NEIGHBOR_SHARE
	if absf(neighbor.total_damage - expected_neighbor) > EPS:
		errors.append("кинжал: сосед получил %.2f, ожидалось %.2f (0.35 ролла)" % [neighbor.total_damage, expected_neighbor])
	if _paralysis_window(neighbor) <= EPS:
		errors.append("кинжал: сосед не получил окно паралича")
	weapon.cleanup_effects()
	await _cleanup(holder)

	# Контраст: жертва СМОТРИТ на фантом (бежит от героя) — позиционного бонуса нет.
	var holder_flee := _new_scene("Scrum897DaggerNoBackstab")
	var owner_flee := _new_owner(holder_flee)
	var weapon_flee := _new_weapon(owner_flee, "thief_shadow_cloak")
	var fleeing := _new_moving_enemy(holder_flee, owner_flee.global_position + Vector2(200.0, 0.0), Vector2(60.0, 0.0))
	await process_frame
	weapon_flee.call("_fire_shadow_backstab", owner_flee, fleeing, Vector2.RIGHT)
	await process_frame
	var expected_plain := 40.0 * ClassWeapon.BACKSTAB_STRIKE_MULTIPLIER
	if absf(fleeing.total_damage - expected_plain) > EPS:
		errors.append("кинжал: жертва лицом к фантому получила %.2f, ожидалось %.2f (без x1.35)" % [fleeing.total_damage, expected_plain])
	weapon_flee.cleanup_effects()
	await _cleanup(holder_flee)


func _test_poison_dagger_boss_resist_and_cap(errors: Array) -> void:
	var holder := _new_scene("Scrum897DaggerBoss")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "thief_shadow_cloak")
	var boss := _new_enemy(holder, owner.global_position + Vector2(200.0, 0.0))
	boss.add_to_group("bosses")
	await process_frame
	weapon.call("_fire_shadow_backstab", owner, boss, Vector2.RIGHT)
	await process_frame
	# Босс-резист: окно срезано POISON_PARALYSIS_BOSS_FACTOR (0.85 x 0.35).
	var expected_boss_window := 0.85 * ClassWeapon.POISON_PARALYSIS_BOSS_FACTOR
	if absf(_paralysis_window(boss) - expected_boss_window) > EPS:
		errors.append("кинжал: окно паралича босса %.3f != %.3f (босс-резист)" % [_paralysis_window(boss), expected_boss_window])
	weapon.cleanup_effects()
	await _cleanup(holder)

	# Артефакт «Парализующее лезвие» продлевает окно, кап держит границу.
	var holder_cap := _new_scene("Scrum897DaggerCap")
	var owner_cap := _new_owner(holder_cap)
	var weapon_cap := _new_weapon(owner_cap, "thief_shadow_cloak")
	owner_cap.run_modifiers = {"backstab_root_duration": 0.7}
	var enemy_extended := _new_enemy(holder_cap, owner_cap.global_position + Vector2(200.0, 0.0))
	await process_frame
	weapon_cap.call("_fire_shadow_backstab", owner_cap, enemy_extended, Vector2.RIGHT)
	await process_frame
	if absf(_paralysis_window(enemy_extended) - 1.55) > EPS:
		errors.append("кинжал: окно с артефактом %.2f != 1.55 (0.85 + 0.7)" % _paralysis_window(enemy_extended))
	weapon_cap.cleanup_effects()
	await _cleanup(holder_cap)

	var holder_hard := _new_scene("Scrum897DaggerHardCap")
	var owner_hard := _new_owner(holder_hard)
	var weapon_hard := _new_weapon(owner_hard, "thief_shadow_cloak")
	owner_hard.run_modifiers = {"backstab_root_duration": 99.0}
	var enemy_capped := _new_enemy(holder_hard, owner_hard.global_position + Vector2(200.0, 0.0))
	await process_frame
	weapon_hard.call("_fire_shadow_backstab", owner_hard, enemy_capped, Vector2.RIGHT)
	await process_frame
	if absf(_paralysis_window(enemy_capped) - ClassWeapon.POISON_PARALYSIS_CAP) > EPS:
		errors.append("кинжал: раздутое окно %.2f != капа %.2f — пермалок обязан быть отрезан" % [_paralysis_window(enemy_capped), ClassWeapon.POISON_PARALYSIS_CAP])
	weapon_hard.cleanup_effects()
	await _cleanup(holder_hard)


# --- «Дымовая Бомба»: отложенная детонация, одно AoE-событие, облако ---


func _test_smoke_bomb_detonation_and_cloud(errors: Array) -> void:
	var holder := _new_scene("Scrum897SmokeBomb")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "thief_smoke_bomb")
	var enemy := _new_enemy(holder, owner.global_position + Vector2(150.0, 0.0))
	await process_frame

	var fuse: float = float(weapon.get("grenade_delay"))
	weapon.call("_fire_smoke_bomb", owner, enemy, Vector2.RIGHT)
	# Отложенная детонация: до конца фитиля урона нет.
	await create_timer(fuse * 0.55).timeout
	if enemy.total_damage > EPS:
		errors.append("дым: урон до детонации (%.2f) — бросок обязан быть отложенным" % enemy.total_damage)
	await create_timer(fuse * 0.55 + 0.15).timeout
	# Ровно ОДНО AoE-событие урона от ролла владельца (скейл от урона билда).
	if absf(enemy.total_damage - 40.0) > EPS:
		errors.append("дым: взрыв дал %.2f, ожидался полный ролл 40" % enemy.total_damage)
	if enemy.hits.size() != 1:
		errors.append("дым: %d событий урона, ожидалось ровно 1 (взрыв)" % enemy.hits.size())
	# Облако зарегистрировано на владельце с контрактными параметрами.
	if owner.smoke_cloud_registrations.size() != 1:
		errors.append("дым: %d регистраций облака, ожидалась 1" % owner.smoke_cloud_registrations.size())
	else:
		var cloud: Dictionary = owner.smoke_cloud_registrations[0]
		if (cloud.get("center", Vector2.ZERO) as Vector2).distance_to(enemy.global_position) > 1.0:
			errors.append("дым: облако село в %s, ожидалось на цели %s" % [str(cloud.get("center")), str(enemy.global_position)])
		if absf(float(cloud.get("radius", 0.0)) - float(weapon.get("aoe_radius"))) > EPS:
			errors.append("дым: радиус облака %.1f != aoe_radius %.1f" % [float(cloud.get("radius", 0.0)), float(weapon.get("aoe_radius"))])
		if absf(float(cloud.get("duration", 0.0)) - 2.6) > EPS:
			errors.append("дым: длительность облака %.2f != 2.6" % float(cloud.get("duration", 0.0)))
		if absf(float(cloud.get("dodge_bonus", 0.0)) - 0.35) > EPS:
			errors.append("дым: бонус облака %.2f != 0.35" % float(cloud.get("dodge_bonus", 0.0)))
	# Облако после взрыва НЕ дамажит: новых событий урона нет.
	await create_timer(0.6).timeout
	if enemy.hits.size() != 1:
		errors.append("дым: облако тикает уроном после взрыва (%d событий)" % enemy.hits.size())
	# SCRUM-961 «Дымный тайник»: облако плотнее и дольше.
	owner.run_modifiers = {"smoke_dodge_bonus": 0.12, "smoke_duration_mult": 0.40}
	weapon.call("_fire_smoke_bomb", owner, enemy, Vector2.RIGHT)
	await create_timer(fuse + 0.15).timeout
	if owner.smoke_cloud_registrations.size() != 2:
		errors.append("дым: вторая детонация не зарегистрировала облако")
	else:
		var invested_cloud: Dictionary = owner.smoke_cloud_registrations[1]
		if absf(float(invested_cloud.get("dodge_bonus", 0.0)) - 0.47) > EPS:
			errors.append("дым: бонус с артефактом %.2f != 0.47 (0.35 + 0.12)" % float(invested_cloud.get("dodge_bonus", 0.0)))
		if absf(float(invested_cloud.get("duration", 0.0)) - 2.6 * 1.4) > EPS:
			errors.append("дым: длительность с артефактом %.2f != 3.64 (2.6 x 1.4)" % float(invested_cloud.get("duration", 0.0)))
	weapon.cleanup_effects()
	await _cleanup(holder)


func _test_smoke_cloud_player_dodge(errors: Array) -> void:
	var holder := _new_scene("Scrum897SmokePlayerDodge")
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	if player_scene == null:
		errors.append("дым: Player.tscn не загрузился")
		await _cleanup(holder)
		return
	var player := player_scene.instantiate()
	holder.add_child(player)
	player.call("configure_character", "thief", "thief_smoke_bomb")
	await process_frame
	var player_node := player as Node2D
	player_node.global_position = Vector2(900, 700)
	# Авто-атаки оружия выключены: тест проверяет ТОЛЬКО позиционную математику
	# облаков (register_smoke_cloud / smoke_cloud_dodge_bonus / _current_dodge_chance).
	var equipped: Node = player.get("equipped_weapon")
	if equipped != null:
		equipped.set_process(false)
		equipped.set("_cooldown", 1.0e9)

	# Тяжёлый, но ДОСТИЖИМЫЙ сырой рейтинг уворота: 1.20 ниже колена капа, поэтому
	# базовый шанс обязан быть ровно effective_dodge(1.20) ≈ 0.504 — оракул проверяет
	# саму кривую, а не асимптоту 0.55, в которую упирался бы любой рейтинг ≥ 1.50.
	var params: Dictionary = player.get("derived_parameters")
	var heavy_raw_dodge := 1.20
	var heavy_dodge := PD.effective_dodge(heavy_raw_dodge)
	params["raw_dodge"] = heavy_raw_dodge
	params["dodge"] = heavy_dodge
	player.set("derived_parameters", params)
	if absf(float(player.call("_current_dodge_chance")) - heavy_dodge) > EPS:
		errors.append("дым: базовый шанс вне облака %.3f != effective_dodge(%.2f)=%.3f" % [float(player.call("_current_dodge_chance")), heavy_raw_dodge, heavy_dodge])
	# В облаке: 0.504 + 0.35 (+0.12 артефакт) режется капом дыма 0.90 — «почти
	# неуязвим в дыму», но не бессмертен.
	player.call("register_smoke_cloud", player_node.global_position, 170.0, 5.0, 0.47)
	if absf(float(player.call("smoke_cloud_dodge_bonus")) - 0.47) > EPS:
		errors.append("дым: бонус внутри облака %.2f != 0.47" % float(player.call("smoke_cloud_dodge_bonus")))
	if absf(float(player.call("_current_dodge_chance")) - PD.SMOKE_CLOUD_DODGE_CAP) > EPS:
		errors.append("дым: шанс в облаке %.2f != капа дыма %.2f" % [float(player.call("_current_dodge_chance")), PD.SMOKE_CLOUD_DODGE_CAP])
	# Вне облака бонус исчезает мгновенно: уклонение позиционное.
	var inside_position: Vector2 = player_node.global_position
	player_node.global_position = inside_position + Vector2(4000.0, 0.0)
	if float(player.call("smoke_cloud_dodge_bonus")) > EPS:
		errors.append("дым: бонус действует вне облака")
	if absf(float(player.call("_current_dodge_chance")) - heavy_dodge) > EPS:
		errors.append("дым: шанс вне облака %.3f != effective_dodge(%.2f)" % [float(player.call("_current_dodge_chance")), heavy_raw_dodge])
	player_node.global_position = inside_position
	# Перекрывающиеся облака НЕ стакаются: берётся максимальный бонус (0.47).
	var modest_raw_dodge := 0.20
	var modest_dodge := PD.effective_dodge(modest_raw_dodge)
	params["raw_dodge"] = modest_raw_dodge
	params["dodge"] = modest_dodge
	player.set("derived_parameters", params)
	player.call("register_smoke_cloud", player_node.global_position, 170.0, 5.0, 0.35)
	if absf(float(player.call("_current_dodge_chance")) - (modest_dodge + 0.47)) > EPS:
		errors.append("дым: перекрытие облаков дало %.3f, ожидалось %.3f (база + max(0.47, 0.35))" % [float(player.call("_current_dodge_chance")), modest_dodge + 0.47])
	# Скромный билд в одиночном облаке: база + 0.35 — до капа дыма далеко.
	var solo_position := inside_position + Vector2(2400.0, 0.0)
	player_node.global_position = solo_position
	player.call("register_smoke_cloud", solo_position, 170.0, 5.0, 0.35)
	if absf(float(player.call("_current_dodge_chance")) - (modest_dodge + 0.35)) > EPS:
		errors.append("дым: скромный билд в облаке %.3f != %.3f (база + 0.35)" % [float(player.call("_current_dodge_chance")), modest_dodge + 0.35])
	# Истечение: короткое облако умирает — бонус пропадает по таймеру.
	player_node.global_position = inside_position + Vector2(8000.0, 0.0)
	player.call("register_smoke_cloud", player_node.global_position, 170.0, 0.25, 0.35)
	if float(player.call("smoke_cloud_dodge_bonus")) <= EPS:
		errors.append("дым: свежее короткое облако не даёт бонус")
	# Player хранит время жизни облака в Time.get_ticks_msec() (реальное монотонное
	# время), а headless-таймер может отработать 0.40 игрового времени раньше
	# 250 мс реального. Ждём по тому же источнику времени, иначе gate флапает.
	var expiry_deadline_msec := Time.get_ticks_msec() + 400
	while Time.get_ticks_msec() < expiry_deadline_msec:
		await process_frame
	if float(player.call("smoke_cloud_dodge_bonus")) > EPS:
		errors.append("дым: бонус пережил истечение облака")
	player.queue_free()
	await _cleanup(holder)
