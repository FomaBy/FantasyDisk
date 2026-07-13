extends SceneTree

# FAN-1031 3c(final): data-driven ЖЁСТКИЙ кап ШИРИНЫ (coverage) крауд-fan-out каналов.
#
# Контекст. Диминиш-капы (S1 прямой AoE, 3c-a пул, 3c-b status, 3c-b2 orbit/falloff) режут
# PER-HIT дальних целей, но урон/статус ещё РАЗДАЁТСЯ каждой цели в зоне (N событий).
# Профилировка перекормленных AoE-верхов (build/stage3c_final_coverage_fan1031.md) показала,
# что их crowd-runaway — это ШИРИНА: у blast_powder число событий взрыва на окно растёт
# 6→2585 при 1→20 целях, а PER-HIT УЖЕ капнут диминишем (230→38). Продуктовое решение
# координатора (2026-07-13): «резать ШИРИНУ, не выгрызать per-hit».
#
# Механизм. Per-weapon поля aoe_max_targets / pool_max_targets / status_max_targets /
# orbit_max_targets кладут ЖЁСТКИЙ потолок: ближние N целей (по дистанции от центра) получают
# урон/статус, дальше — НОЛЬ. Сентинел <0 → без потолка → нулевое изменение поведения (A/B).
# Ортогонален диминиш-капам (те режут per-hit хвоста ДО потолка). 1t / малый пак (rank<N) целы.
#
# Гейт — лёгкий, детерминированный (единичные вызовы helper'ов/пайплайнов, без 480-кадрового
# DPS-сима):
#   1. _status_fanout_factor / _orbit_fanout_factor: *_max_targets=3 → rank<3 полный, rank>=3
#      НОЛЬ; кап композится с диминишем (full=1/diminish=1.0 → rank1=0.5, rank2=0.333, rank3+=0);
#   2. сентинел-контроль: без *_max_targets — factor НИКОГДА не 0 от капа (все ранги >0);
#   3. интеграция _damage_enemies_in_circle_capped: aoe_max_targets=3 → ровно 3 ближайших
#      получают урон, дальний хвост НОЛЬ; control (A/B) без override → все получают;
#   4. интеграция _damage_enemies_in_pool: pool_max_targets=3 (те же 3 + zero-tail); control;
#   5. реальные конфиги: blast aoe_max=6, acid pool_max=6, spore/symbiote status_max=6,
#      orb_ring orbit_max=6 — и НЕ затёрты существующие диминиш-капы (composable);
#   6. дефолт-guard: свежее оружие несёт *_max_targets == -1 (нет молчаливого потолка).
#
# Запуск: Godot --headless --path . --script res://tests/coverage_cap_gate.gd

const ClassWeapon := preload("res://scripts/class_weapon.gd")
const PD := preload("res://scripts/progression_data.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")

const EPS := 0.02


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
	var health := 100.0
	var max_health := 100.0

	func class_trait_value(_key: String, default_value := 0.0) -> float:
		return default_value


class MockEnemy extends Node2D:
	var total_damage := 0.0
	var hit_count := 0

	func take_damage(amount: float) -> void:
		total_damage += amount
		hit_count += 1


func _initialize() -> void:
	seed(20260713)
	# Sanity: непортированный ассет → class_weapon.gd не скомпилируется → ClassWeapon.new()
	# вернёт null; гейт обязан упасть громко, а не «пройти» вхолостую (урок 3c-a).
	var probe = ClassWeapon.new()
	if probe == null:
		push_error("Coverage cap (FAN-1031 3c-final): ClassWeapon.new() → null (class_weapon.gd не скомпилировался) — гейт недействителен.")
		quit(1)
		return
	probe.free()

	var errors: Array = []
	await _test_status_helper_hardcap(errors)
	await _test_orbit_helper_hardcap(errors)
	await _test_helpers_sentinel_control(errors)
	await _test_aoe_integration(errors)
	await _test_aoe_integration_control(errors)
	await _test_pool_integration(errors)
	await _test_pool_integration_control(errors)
	await _test_orbit_hardcap_skip(errors)
	await _test_fast_path_honors_max(errors)
	await _test_censer_width_integration(errors)
	_test_real_configs_and_defaults(errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Coverage cap (FAN-1031 3c-final): %s" % str(error))
		push_error("Coverage cap gate failed with %d error(s)." % errors.size())
		quit(1)
		return
	print("Coverage cap gate passed (FAN-1031 3c-final: data-driven hard WIDTH cap on aoe/pool/status/orbit crowd channels, composes with diminish, sentinel control, real configs).")
	quit(0)


# --- helpers ------------------------------------------------------------------


func _new_scene(name: String) -> Node2D:
	var holder := Node2D.new()
	holder.name = name
	root.add_child(holder)
	current_scene = holder
	return holder


func _new_owner(holder: Node2D, position: Vector2) -> MockOwner:
	var owner := MockOwner.new()
	holder.add_child(owner)
	owner.global_position = position
	return owner


func _new_weapon(owner: MockOwner, config: Dictionary) -> ClassWeapon:
	var weapon := ClassWeapon.new()
	owner.add_child(weapon)
	weapon.configure_weapon(config)
	weapon.set_process(false)
	return weapon


# Цели с растущим удалением от центра: rank = удалённость (шаг мал, все в зоне).
func _spawn_ranks(holder: Node2D, origin: Vector2, count: int) -> Array:
	var ranks: Array = []
	for k in range(count):
		var enemy := MockEnemy.new()
		holder.add_child(enemy)
		enemy.global_position = origin + Vector2(float(k) * 16.0, 0.0)
		enemy.add_to_group("enemies")
		ranks.append(enemy)
	return ranks


func _cleanup(holder: Node2D) -> void:
	holder.queue_free()
	await process_frame


# --- tests --------------------------------------------------------------------


# 1a. _status_fanout_factor: hard-cap 3, composes with diminish full=1/1.0.
func _test_status_helper_hardcap(errors: Array) -> void:
	var holder := _new_scene("StatusHardCap")
	var owner := _new_owner(holder, Vector2(1000, 1000))
	var weapon := _new_weapon(owner, {
		"id": "probe", "attack_mode": "aoe_projectile", "damage_parameter": "magic_damage",
		"status_full_targets": 1, "status_target_diminish": 1.0, "status_max_targets": 3,
	})
	if weapon.status_max_targets != 3:
		errors.append("status hard-cap: конфиг не загрузился (status_max_targets=%d; ждали 3)" % weapon.status_max_targets)
	# rank0=1.0 (full), rank1=1/(1+1)=0.5, rank2=1/(1+2)=0.333, rank3+=0.0 (hard-cap).
	var expected := {0: 1.0, 1: 0.5, 2: 1.0 / 3.0, 3: 0.0, 4: 0.0, 10: 0.0}
	for rank in expected.keys():
		var got: float = weapon.call("_status_fanout_factor", rank)
		if absf(got - float(expected[rank])) > 0.001:
			errors.append("status factor rank %d = %.4f != %.4f (hard-cap+diminish композиция)" % [rank, got, float(expected[rank])])
	await _cleanup(holder)


# 1b. _orbit_fanout_factor: hard-cap 3 без диминиша (default 0) → rank<3 = 1.0, rank>=3 = 0.
func _test_orbit_helper_hardcap(errors: Array) -> void:
	var holder := _new_scene("OrbitHardCap")
	var owner := _new_owner(holder, Vector2(1000, 1000))
	var weapon := _new_weapon(owner, {
		"id": "probe", "attack_mode": "elemental_orbit", "damage_parameter": "magic_damage",
		"orbit_max_targets": 3,
	})
	if weapon.orbit_max_targets != 3:
		errors.append("orbit hard-cap: конфиг не загрузился (orbit_max_targets=%d; ждали 3)" % weapon.orbit_max_targets)
	var expected := {0: 1.0, 1: 1.0, 2: 1.0, 3: 0.0, 4: 0.0, 19: 0.0}
	for rank in expected.keys():
		var got: float = weapon.call("_orbit_fanout_factor", rank)
		if absf(got - float(expected[rank])) > 0.001:
			errors.append("orbit factor rank %d = %.4f != %.4f (hard-cap без диминиша)" % [rank, got, float(expected[rank])])
	await _cleanup(holder)


# 2. Сентинел-контроль: без *_max_targets — factor НИКОГДА не обнуляется капом.
func _test_helpers_sentinel_control(errors: Array) -> void:
	var holder := _new_scene("SentinelControl")
	var owner := _new_owner(holder, Vector2(1000, 1000))
	var weapon := _new_weapon(owner, {
		"id": "probe", "attack_mode": "aoe_projectile", "damage_parameter": "damage",
	})
	if weapon.status_max_targets != -1 or weapon.orbit_max_targets != -1 \
			or weapon.aoe_max_targets != -1 or weapon.pool_max_targets != -1:
		errors.append("сентинел-контроль: *_max_targets не -1 (aoe %d pool %d status %d orbit %d) — контракт сломан" % [weapon.aoe_max_targets, weapon.pool_max_targets, weapon.status_max_targets, weapon.orbit_max_targets])
	for rank in [0, 1, 3, 10, 19]:
		var gs: float = weapon.call("_status_fanout_factor", rank)
		var go: float = weapon.call("_orbit_fanout_factor", rank)
		if gs <= 0.0:
			errors.append("сентинел status rank %d = %.4f (кап душит без override)" % [rank, gs])
		if go <= 0.0:
			errors.append("сентинел orbit rank %d = %.4f (кап душит без override)" % [rank, go])
	await _cleanup(holder)


# 3. Интеграция _damage_enemies_in_circle_capped: aoe_max=3 → 3 ближайших получают, хвост НОЛЬ.
#    full=1/diminish=0 → у 3 нетронутых полный amount (изолируем именно кап ширины).
func _test_aoe_integration(errors: Array) -> void:
	var holder := _new_scene("AoeIntegration")
	var owner := _new_owner(holder, Vector2(1000, 1000))
	var weapon := _new_weapon(owner, {
		"id": "probe", "attack_mode": "aoe_projectile", "damage_parameter": "damage",
		"aoe_max_targets": 3,
	})
	var center: Vector2 = owner.global_position
	var ranks := _spawn_ranks(holder, center, 6)
	await process_frame
	var amount := 200.0
	weapon.call("_damage_enemies_in_circle_capped", center, 400.0, amount, 1, 0.0)
	for rank in range(6):
		var got: float = (ranks[rank] as MockEnemy).total_damage
		var want := amount if rank < 3 else 0.0
		if absf(got - want) > EPS:
			errors.append("aoe integration rank %d dmg=%.3f != %.3f (жёсткий кап ширины не проведён)" % [rank, got, want])
	await _cleanup(holder)


# 4. Интеграция aoe control (A/B): без override → ВСЕ 6 целей получают полный amount.
func _test_aoe_integration_control(errors: Array) -> void:
	var holder := _new_scene("AoeControl")
	var owner := _new_owner(holder, Vector2(1000, 1000))
	var weapon := _new_weapon(owner, {
		"id": "probe", "attack_mode": "aoe_projectile", "damage_parameter": "damage",
	})
	var center: Vector2 = owner.global_position
	var ranks := _spawn_ranks(holder, center, 6)
	await process_frame
	var amount := 200.0
	weapon.call("_damage_enemies_in_circle_capped", center, 400.0, amount, 1, 0.0)
	for rank in range(6):
		var got: float = (ranks[rank] as MockEnemy).total_damage
		if absf(got - amount) > EPS:
			errors.append("aoe control rank %d dmg=%.3f != %.3f — без override ширина не должна капиться (A/B-регресс)" % [rank, got, amount])
	await _cleanup(holder)


# 5. Интеграция _damage_enemies_in_pool: pool_max=3 → 3 ближайших тикают, хвост НОЛЬ.
#    pool_full=1/diminish=0 → нетронутые получают полный amount (изолируем кап ширины).
func _test_pool_integration(errors: Array) -> void:
	var holder := _new_scene("PoolIntegration")
	var owner := _new_owner(holder, Vector2(1000, 1000))
	var weapon := _new_weapon(owner, {
		"id": "probe", "attack_mode": "aoe_projectile", "damage_parameter": "damage",
		"pool_full_targets": 1, "pool_target_diminish": 0.0, "pool_max_targets": 3,
	})
	var center: Vector2 = owner.global_position
	var ranks := _spawn_ranks(holder, center, 6)
	await process_frame
	var amount := 150.0
	weapon.call("_damage_enemies_in_pool", center, 400.0, amount, null)
	for rank in range(6):
		var got: float = (ranks[rank] as MockEnemy).total_damage
		var want := amount if rank < 3 else 0.0
		if absf(got - want) > EPS:
			errors.append("pool integration rank %d dmg=%.3f != %.3f (жёсткий кап ширины лужи не проведён)" % [rank, got, want])
	await _cleanup(holder)


# 6. Интеграция pool control (A/B): без override → ВСЕ 6 целей тикают полным amount.
func _test_pool_integration_control(errors: Array) -> void:
	var holder := _new_scene("PoolControl")
	var owner := _new_owner(holder, Vector2(1000, 1000))
	var weapon := _new_weapon(owner, {
		"id": "probe", "attack_mode": "aoe_projectile", "damage_parameter": "damage",
		"pool_full_targets": 1, "pool_target_diminish": 0.0,
	})
	var center: Vector2 = owner.global_position
	var ranks := _spawn_ranks(holder, center, 6)
	await process_frame
	var amount := 150.0
	weapon.call("_damage_enemies_in_pool", center, 400.0, amount, null)
	for rank in range(6):
		var got: float = (ranks[rank] as MockEnemy).total_damage
		if absf(got - amount) > EPS:
			errors.append("pool control rank %d dmg=%.3f != %.3f — без override ширина лужи не должна капиться (A/B-регресс)" % [rank, got, amount])
	await _cleanup(holder)


func _burn_dot(enemy: Node) -> float:
	var snap: Dictionary = StatusEffects.snapshot(enemy)
	return float((snap.get("four_elements_burn", {}) as Dictionary).get("dot_damage", -1.0))


# 5b. Orbit hard-cap = SKIP, не ×0 (peer review MAJOR). Цель за orbit_max_targets НЕ должна
# получать прокси-хит (_damage_enemy: он-хит пайплайн) и НЕ должна затирать живой ожог 0-статусом.
func _test_orbit_hardcap_skip(errors: Array) -> void:
	var holder := _new_scene("OrbitHardCapSkip")
	var owner := _new_owner(holder, Vector2(1000, 1000))
	var cfg: Dictionary = PD.weapon("elementalist", "elementalist_orb_ring").duplicate(true)
	cfg["orbit_max_targets"] = 2
	cfg.erase("orbit_full_targets")    # изолируем hard-cap: 2 ближних полным, дальше НОЛЬ (skip)
	cfg.erase("orbit_target_diminish")
	var weapon := _new_weapon(owner, cfg)
	var center: Vector2 = owner.global_position
	var half_size: float = float(weapon.get("aoe_radius")) * 0.72
	var ranks := _spawn_ranks(holder, center, 5)
	await process_frame
	weapon.call("_elemental_square_tick", owner, center, half_size, 4, 0)
	await process_frame
	for rank in range(5):
		var e := ranks[rank] as MockEnemy
		var burn := _burn_dot(e)
		if rank < 2:
			if e.hit_count == 0 or e.total_damage <= 0.0:
				errors.append("orbit hard-cap: rank %d (в капе) не получил урон (hits=%d dmg=%.2f)" % [rank, e.hit_count, e.total_damage])
			if burn <= 0.0:
				errors.append("orbit hard-cap: rank %d (в капе) не получил ожог (dot=%.2f)" % [rank, burn])
		else:
			if e.hit_count != 0 or e.total_damage > EPS:
				errors.append("orbit hard-cap: rank %d (за капом) получил прокси-хит (hits=%d dmg=%.2f) — SKIP не работает, 0-хит фаирит он-хит пайплайн МИМО капа (MAJOR)" % [rank, e.hit_count, e.total_damage])
			if burn > 0.0:
				errors.append("orbit hard-cap: rank %d (за капом) получил ожог dot=%.2f — 0-статус затирает живой burn refresh-ом (MAJOR)" % [rank, burn])
	await _cleanup(holder)


# 5c. Fast-path чтит max (peer review MINOR). size ≤ full НЕ должен обходить жёсткий кап ШИРИНЫ.
func _test_fast_path_honors_max(errors: Array) -> void:
	var holder := _new_scene("FastPathMax")
	var owner := _new_owner(holder, Vector2(1000, 1000))
	var weapon := _new_weapon(owner, {
		"id": "probe", "attack_mode": "aoe_projectile", "damage_parameter": "damage",
		"aoe_max_targets": 2,
	})
	var center: Vector2 = owner.global_position
	var ranks := _spawn_ranks(holder, center, 4)
	await process_frame
	var amount := 200.0
	# full=5/diminish=0 → без капа все 4 (≤ full) полным через fast-path; aoe_max=2 → только 2 ближних.
	weapon.call("_damage_enemies_in_circle_capped", center, 400.0, amount, 5, 0.0)
	for rank in range(4):
		var e := ranks[rank] as MockEnemy
		var want := amount if rank < 2 else 0.0
		if absf(e.total_damage - want) > EPS:
			errors.append("fast-path max: rank %d dmg=%.2f != %.2f — fast-path (size 4 ≤ full 5) обошёл жёсткий кап aoe_max=2" % [rank, e.total_damage, want])
	await _cleanup(holder)


# 6. Интеграция кадила Жреца (FAN-1031 v8-микротрим): _fire_priest_ward льёт волну через
#    _damage_enemies_in_circle_capped на РЕАЛЬНОМ конфиге кадила (aoe_full/diminish). Ближние
#    full — полный урон, хвост толпы душится по формуле, но НЕ обнуляется (жёсткого max нет →
#    identity «выжигают ВСЁ вокруг» цела). A/B-сентинел (full=huge/diminish=0) → весь ряд полный.
func _test_censer_width_integration(errors: Array) -> void:
	var censer: Dictionary = PD.weapon("priest", "priest_censer")
	var full := int(censer.get("aoe_full_targets", -1))
	var diminish := float(censer.get("aoe_target_diminish", -1.0))
	if full < 1 or diminish <= 0.0:
		errors.append("censer integration: конфиг без width-опт-ина (full=%d diminish=%.2f) — крауд-добор не режется" % [full, diminish])
		return
	var holder := _new_scene("CenserWidth")
	var owner := _new_owner(holder, Vector2(1000, 1000))
	var weapon := _new_weapon(owner, {
		"id": "priest_censer", "attack_mode": "priest_ward", "damage_parameter": "magic_damage",
		"aoe_full_targets": full, "aoe_target_diminish": diminish,
	})
	var center: Vector2 = owner.global_position
	var count := full + 4
	var ranks := _spawn_ranks(holder, center, count)
	await process_frame
	var amount := 200.0
	# Реальный кап: ближние full — полный, дальний хвост — по формуле диминиша, но НЕ ноль (нет max).
	weapon.call("_damage_enemies_in_circle_capped", center, 800.0, amount, full, diminish)
	for rank in range(count):
		var e := ranks[rank] as MockEnemy
		if rank < full:
			if absf(e.total_damage - amount) > EPS:
				errors.append("censer integration: ближняя цель rank %d dmg=%.2f != %.2f (в full — полный)" % [rank, e.total_damage, amount])
		else:
			var want := amount / (1.0 + float(rank - full + 1) * diminish)
			if e.total_damage <= 0.0:
				errors.append("censer integration: rank %d за full ОБНУЛЁН — жёсткий max сломал identity «всё вокруг»" % rank)
			elif absf(e.total_damage - want) > EPS:
				errors.append("censer integration: хвост rank %d dmg=%.3f != %.3f (диминиш толпы не по формуле)" % [rank, e.total_damage, want])
	# A/B-сентинел: full=огромный / diminish=0 → весь ряд полный (режет ИМЕННО кап ширины, не геометрия).
	for e in ranks:
		(e as MockEnemy).total_damage = 0.0
		(e as MockEnemy).hit_count = 0
	weapon.call("_damage_enemies_in_circle_capped", center, 800.0, amount, 9999, 0.0)
	for rank in range(count):
		if absf((ranks[rank] as MockEnemy).total_damage - amount) > EPS:
			errors.append("censer A/B: rank %d dmg=%.2f != %.2f — без диминиша ширина не должна резаться" % [rank, (ranks[rank] as MockEnemy).total_damage, amount])
	await _cleanup(holder)


# 7/8. Реальные конфиги (width-кап проведён + композится с диминишем) + дефолт-guard.
func _test_real_configs_and_defaults(errors: Array) -> void:
	# blast_powder: FAN-1031 3d aoe_max=3 ПОВЕРХ диминиш-капа 2/3.0 (оба живы; ужато с 6+4/3.0 —
	# v6 honest всё ещё держал blast aoe 8.78×; см. no-silent-retune лог).
	var blast: Dictionary = PD.weapon("chemist", "blast_powder")
	if int(blast.get("aoe_max_targets", -1)) != 3:
		errors.append("blast_powder aoe_max_targets != 3 (silent-retune?): %s" % str(blast.get("aoe_max_targets", -1)))
	if int(blast.get("aoe_full_targets", -1)) != 2 or absf(float(blast.get("aoe_target_diminish", -1.0)) - 3.0) > 0.001:
		errors.append("blast_powder диминиш-кап затёрт width-капом (ждали 2/3.0): %s/%s" % [str(blast.get("aoe_full_targets")), str(blast.get("aoe_target_diminish"))])
	# acid_flask: FAN-1031 3d pool_max=4 ПОВЕРХ pool_target_diminish=3.0 (ужато с 6).
	var acid: Dictionary = PD.weapon("chemist", "acid_flask")
	if int(acid.get("pool_max_targets", -1)) != 4:
		errors.append("acid_flask pool_max_targets != 4: %s" % str(acid.get("pool_max_targets", -1)))
	if absf(float(acid.get("pool_target_diminish", -1.0)) - 3.0) > 0.001:
		errors.append("acid_flask pool_target_diminish затёрт (ждали 3.0): %s" % str(acid.get("pool_target_diminish")))
	# biologist spore/symbiote: status_max=6 ПОВЕРХ status 4/1.0.
	for wid in ["biologist_spore_lens", "biologist_symbiote_seed"]:
		var bio: Dictionary = PD.weapon("biologist", wid)
		if int(bio.get("status_max_targets", -1)) != 6:
			errors.append("%s status_max_targets != 6: %s" % [wid, str(bio.get("status_max_targets", -1))])
		if int(bio.get("status_full_targets", -1)) != 4 or absf(float(bio.get("status_target_diminish", -1.0)) - 1.0) > 0.001:
			errors.append("%s status диминиш-кап затёрт (ждали 4/1.0): %s/%s" % [wid, str(bio.get("status_full_targets")), str(bio.get("status_target_diminish"))])
	# elementalist orb_ring: FAN-1031 3d orbit_max=4 ПОВЕРХ orbit 3/1.0 (ужато с 6).
	var orb: Dictionary = PD.weapon("elementalist", "elementalist_orb_ring")
	if int(orb.get("orbit_max_targets", -1)) != 4:
		errors.append("orb_ring orbit_max_targets != 4: %s" % str(orb.get("orbit_max_targets", -1)))
	if int(orb.get("orbit_full_targets", -1)) != 3 or absf(float(orb.get("orbit_target_diminish", -1.0)) - 1.0) > 0.001:
		errors.append("orb_ring orbit диминиш-кап затёрт (ждали 3/1.0): %s/%s" % [str(orb.get("orbit_full_targets")), str(orb.get("orbit_target_diminish"))])
	# priest_censer: FAN-1031 v8-микротрим — width-кап крауд-ХВОСТА кадила (aoe_full/diminish 4/1.2),
	# БЕЗ жёсткого max (identity «выжигают ВСЁ вокруг»: все в радиусе задеты, дальние слабее).
	var censer: Dictionary = PD.weapon("priest", "priest_censer")
	if int(censer.get("aoe_full_targets", -1)) != 4 or absf(float(censer.get("aoe_target_diminish", -1.0)) - 1.2) > 0.001:
		errors.append("priest_censer width-кап затёрт (ждали 4/1.2): %s/%s" % [str(censer.get("aoe_full_targets")), str(censer.get("aoe_target_diminish"))])
	if int(censer.get("aoe_max_targets", -1)) >= 0:
		errors.append("priest_censer несёт aoe_max_targets=%s — жёсткий обрез ломает identity «большой AoE вокруг» (нужен лишь диминиш хвоста)" % str(censer.get("aoe_max_targets")))
	# Дефолт-guard: оружие БЕЗ override не несёт молчаливого потолка.
	var plain: Dictionary = PD.weapon("berserk", "sword")
	for field in ["aoe_max_targets", "pool_max_targets", "status_max_targets", "orbit_max_targets"]:
		if plain.has(field):
			errors.append("berserk/sword несёт %s=%s — нецелевое оружие не должно иметь width-кап" % [field, str(plain.get(field))])
