extends SceneTree

# FAN-1031 3c(b2): data-driven кап FALLOFF/ORBIT крауд-fan-out каналов.
#
# Контекст. S1 (3a) капнул прямой AoE-взрыв; 3c(a) — пул-канал (тик лужи + leaves_pool);
# 3c(b) — крауд-раздачу периодических СТАТУСОВ. Оставались ДВА helper'а прямого урона,
# раздававших полный урон КАЖДОЙ цели без диминиша по ЧИСЛУ целей:
#   • `_damage_enemies_in_circle_falloff` — дистанционный сплэш (спад только по РАДИУСУ,
#     не по числу целей) → напр. burst черепа Тёмного мага;
#   • `_elemental_square_tick` (elementalist_orb_ring) — квадратный тик бьёт magic+phys+
#     ожог КАЖДОМУ врагу в зоне полным тиком → v3'' elemental_orbit 20t ≈197.8k (≈43×
#     медианы 4574), elementalist crowd 14.65 не двигался пул/status-капами (runaway жил ТУТ).
#
# 3c(b2) добавляет per-weapon поля falloff_full_targets/falloff_target_diminish и
# orbit_full_targets/orbit_target_diminish (сентинел <0 → *_FANOUT_* с diminish 0 →
# factor==1 для всех рангов → нулевое изменение без override). Оффендер задаёт узкий full
# + крутой diminish: ближние N целей — полный урон (1t/identity зоны целы), дальний хвост
# толпы душится. Ранг = дистанция от центра; формула единая с _status_fanout_factor / S1 / пул.
#
# Гейт — лёгкий, детерминированный (единичные вызовы helper'ов, без 480-кадрового DPS-сима):
#   1. helper _falloff_fanout_factor / _orbit_fanout_factor: override 4/1.0 → ядро полное,
#      rank4=0.5, rank5=1/3, rank6=1/4;
#   2. сентинел-контроль обоих helper'ов: без override — factor 1.0 для ВСЕХ рангов;
#   3. интеграция falloff: _damage_enemies_in_circle_falloff с minimum_factor=1.0 (радиальный
#      спад нейтрализован) на 6 ранжированных → урон хвоста режется по формуле, ядро полное;
#   4. интеграция falloff control (A/B): тот же вызов без override → все цели полный урон;
#   5. интеграция orbit: _elemental_square_tick на 6 ранжированных → magic+phys total И ожог
#      DoT хвоста режутся по формуле, ядро полное;
#   6. интеграция orbit control (A/B): orb_ring без orbit-полей → все цели полный тик;
#   7. anti-silent-retune: реальные конфиги (orb_ring orbit=3/1.0; blast_powder aoe=4/3.0 —
#      прямой AoE-путь, НЕ falloff; falloff-рычаг НЕ переопределён нигде → готов к калибровке);
#   8. CONST-guard: дефолты FALLOFF/ORBIT_FANOUT_TARGET_DIMINISH==0.0 (no-op) не сдвинуты молча.
#
# Запуск: Godot --headless --path . --script res://tests/orbit_falloff_cap_gate.gd

const ClassWeapon := preload("res://scripts/class_weapon.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")
const PD := preload("res://scripts/progression_data.gd")

const EPS := 0.02
const RATIO_EPS := 0.01


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
		push_error("Orbit/Falloff cap (FAN-1031 3c-b2): ClassWeapon.new() → null (class_weapon.gd не скомпилировался) — гейт недействителен.")
		quit(1)
		return
	probe.free()

	var errors: Array = []
	await _test_falloff_helper_override(errors)
	await _test_orbit_helper_override(errors)
	await _test_helpers_sentinel_control(errors)
	await _test_falloff_integration(errors)
	await _test_falloff_integration_control(errors)
	await _test_orbit_integration(errors)
	await _test_orbit_integration_control(errors)
	_test_real_configs_and_constants(errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Orbit/Falloff cap (FAN-1031 3c-b2): %s" % str(error))
		push_error("Orbit/Falloff cap gate failed with %d error(s)." % errors.size())
		quit(1)
		return
	print("Orbit/Falloff cap gate passed (FAN-1031 3c-b2: data-driven crowd fan-out cap on falloff & elemental-square channels, sentinel control, real configs).")
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


# Цели по лучу с растущим удалением от центра: rank = удалённость (шаг мал, чтобы
# все попадали в зону).
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


func _burn_dot(enemy: Node) -> float:
	var snap: Dictionary = StatusEffects.snapshot(enemy)
	return float((snap.get("four_elements_burn", {}) as Dictionary).get("dot_damage", -1.0))


# Ожидаемый диминиш-фактор для ранга при override full/diminish (формула — единый контракт).
func _expected_factor(rank: int, full: int, diminish: float) -> float:
	if diminish <= 0.0 or rank < full:
		return 1.0
	return 1.0 / (1.0 + float(rank - full + 1) * diminish)


# --- tests --------------------------------------------------------------------


# 1a. _falloff_fanout_factor: override full=4/diminish=1.0 → ядро полное, хвост душится.
func _test_falloff_helper_override(errors: Array) -> void:
	var holder := _new_scene("FalloffOverride")
	var owner := _new_owner(holder, Vector2(1000, 1000))
	var weapon := _new_weapon(owner, {
		"id": "probe", "attack_mode": "aoe_projectile", "damage_parameter": "damage",
		"falloff_full_targets": 4, "falloff_target_diminish": 1.0,
	})
	if weapon.falloff_full_targets != 4 or absf(weapon.falloff_target_diminish - 1.0) > 0.001:
		errors.append("falloff helper: конфиг не загрузился (full=%d diminish=%.2f; ждали 4/1.0)" % [weapon.falloff_full_targets, weapon.falloff_target_diminish])
	var expected := {0: 1.0, 1: 1.0, 2: 1.0, 3: 1.0, 4: 0.5, 5: 1.0 / 3.0, 6: 0.25}
	for rank in expected.keys():
		var got: float = weapon.call("_falloff_fanout_factor", rank)
		if absf(got - float(expected[rank])) > 0.001:
			errors.append("falloff factor override rank %d = %.4f != %.4f" % [rank, got, float(expected[rank])])
	await _cleanup(holder)


# 1b. _orbit_fanout_factor: override full=4/diminish=1.0 (тот же контракт).
func _test_orbit_helper_override(errors: Array) -> void:
	var holder := _new_scene("OrbitOverride")
	var owner := _new_owner(holder, Vector2(1000, 1000))
	var weapon := _new_weapon(owner, {
		"id": "probe", "attack_mode": "elemental_orbit", "damage_parameter": "magic_damage",
		"orbit_full_targets": 4, "orbit_target_diminish": 1.0,
	})
	if weapon.orbit_full_targets != 4 or absf(weapon.orbit_target_diminish - 1.0) > 0.001:
		errors.append("orbit helper: конфиг не загрузился (full=%d diminish=%.2f; ждали 4/1.0)" % [weapon.orbit_full_targets, weapon.orbit_target_diminish])
	var expected := {0: 1.0, 3: 1.0, 4: 0.5, 5: 1.0 / 3.0, 6: 0.25}
	for rank in expected.keys():
		var got: float = weapon.call("_orbit_fanout_factor", rank)
		if absf(got - float(expected[rank])) > 0.001:
			errors.append("orbit factor override rank %d = %.4f != %.4f" % [rank, got, float(expected[rank])])
	await _cleanup(holder)


# 2. Сентинел-контроль обоих helper'ов: без override — factor 1.0 для ВСЕХ рангов.
func _test_helpers_sentinel_control(errors: Array) -> void:
	var holder := _new_scene("SentinelControl")
	var owner := _new_owner(holder, Vector2(1000, 1000))
	var weapon := _new_weapon(owner, {
		"id": "probe", "attack_mode": "aoe_projectile", "damage_parameter": "damage",
	})
	if weapon.falloff_full_targets != -1 or weapon.falloff_target_diminish != -1.0 \
			or weapon.orbit_full_targets != -1 or weapon.orbit_target_diminish != -1.0:
		errors.append("сентинел-контроль: поля не -1 (falloff %d/%.2f orbit %d/%.2f) — data-driven контракт сломан" % [weapon.falloff_full_targets, weapon.falloff_target_diminish, weapon.orbit_full_targets, weapon.orbit_target_diminish])
	for rank in [0, 1, 4, 10, 19]:
		var gf: float = weapon.call("_falloff_fanout_factor", rank)
		var go: float = weapon.call("_orbit_fanout_factor", rank)
		if absf(gf - 1.0) > 0.001:
			errors.append("сентинел falloff rank %d = %.4f != 1.0 — дефолт душит без override" % [rank, gf])
		if absf(go - 1.0) > 0.001:
			errors.append("сентинел orbit rank %d = %.4f != 1.0 — дефолт душит без override" % [rank, go])
	await _cleanup(holder)


# 3. Интеграция falloff: minimum_factor=1.0 (радиальный спад нейтрален) → урон = amount *
#    fanout(rank). Проверяет РЕАЛЬНОЕ проведение (sort+rank+apply) на живом helper'е.
func _test_falloff_integration(errors: Array) -> void:
	var holder := _new_scene("FalloffIntegration")
	var owner := _new_owner(holder, Vector2(1000, 1000))
	var weapon := _new_weapon(owner, {
		"id": "probe", "attack_mode": "aoe_projectile", "damage_parameter": "damage",
		"falloff_full_targets": 4, "falloff_target_diminish": 1.0,
	})
	var center: Vector2 = owner.global_position
	var ranks := _spawn_ranks(holder, center, 6)
	await process_frame
	var amount := 200.0
	weapon.call("_damage_enemies_in_circle_falloff", center, 400.0, amount, 1.0)
	for rank in range(6):
		var expected := amount * _expected_factor(rank, 4, 1.0)
		var got: float = (ranks[rank] as MockEnemy).total_damage
		if absf(got - expected) > EPS:
			errors.append("falloff integration rank %d dmg=%.3f != %.3f (крауд-кап не проведён на helper'е)" % [rank, got, expected])
	await _cleanup(holder)


# 4. Интеграция falloff control (A/B): без override → все цели полный урон (радиальный спад
#    нейтрализован minimum_factor=1.0 → все равны amount).
func _test_falloff_integration_control(errors: Array) -> void:
	var holder := _new_scene("FalloffControl")
	var owner := _new_owner(holder, Vector2(1000, 1000))
	var weapon := _new_weapon(owner, {
		"id": "probe", "attack_mode": "aoe_projectile", "damage_parameter": "damage",
	})
	var center: Vector2 = owner.global_position
	var ranks := _spawn_ranks(holder, center, 6)
	await process_frame
	var amount := 200.0
	weapon.call("_damage_enemies_in_circle_falloff", center, 400.0, amount, 1.0)
	for rank in range(6):
		var got: float = (ranks[rank] as MockEnemy).total_damage
		if absf(got - amount) > EPS:
			errors.append("falloff control rank %d dmg=%.3f != %.3f — без override крауд-урон не должен диминишиться (A/B-регресс)" % [rank, got, amount])
	await _cleanup(holder)


# 5. Интеграция orbit: _elemental_square_tick с override 4/1.0 → magic+phys total И ожог DoT
#    хвоста режутся по формуле относительно ядра (ratio-проверка гасит абсолютный rolled).
func _test_orbit_integration(errors: Array) -> void:
	var holder := _new_scene("OrbitIntegration")
	var owner := _new_owner(holder, Vector2(1000, 1000))
	var cfg: Dictionary = PD.weapon("elementalist", "elementalist_orb_ring").duplicate(true)
	cfg["orbit_full_targets"] = 4
	cfg["orbit_target_diminish"] = 1.0
	cfg["orbit_max_targets"] = -1  # изолируем ДИМИНИШ-канал от ЖЁСТКОГО кап-ширины (coverage_cap_gate тестирует его отдельно; FAN-1031 3d real orbit_max=4)
	var weapon := _new_weapon(owner, cfg)
	var center: Vector2 = owner.global_position
	var half_size: float = float(weapon.get("aoe_radius")) * 0.72
	var ranks := _spawn_ranks(holder, center, 6)
	await process_frame
	weapon.call("_elemental_square_tick", owner, center, half_size, 4, 0)
	await process_frame
	var core_dmg: float = (ranks[0] as MockEnemy).total_damage
	var core_burn := _burn_dot(ranks[0])
	if core_dmg <= 0.0 or core_burn <= 0.0:
		errors.append("orbit integration: ядро не получило урон/ожог (dmg=%.3f burn=%.3f) — тик не проведён" % [core_dmg, core_burn])
		await _cleanup(holder)
		return
	for rank in range(6):
		var factor := _expected_factor(rank, 4, 1.0)
		var got_dmg: float = (ranks[rank] as MockEnemy).total_damage
		var got_burn := _burn_dot(ranks[rank])
		if absf(got_dmg - core_dmg * factor) > core_dmg * RATIO_EPS + EPS:
			errors.append("orbit integration rank %d magic+phys=%.3f != %.3f (crowd-кап тика не проведён)" % [rank, got_dmg, core_dmg * factor])
		if absf(got_burn - core_burn * factor) > core_burn * RATIO_EPS + EPS:
			errors.append("orbit integration rank %d burn dot=%.3f != %.3f (ожог-канал не скейлится)" % [rank, got_burn, core_burn * factor])
	await _cleanup(holder)


# 6. Интеграция orbit control (A/B): orb_ring без orbit-полей → все цели полный тик.
func _test_orbit_integration_control(errors: Array) -> void:
	var holder := _new_scene("OrbitControl")
	var owner := _new_owner(holder, Vector2(1000, 1000))
	var cfg: Dictionary = PD.weapon("elementalist", "elementalist_orb_ring").duplicate(true)
	cfg.erase("orbit_full_targets")
	cfg.erase("orbit_target_diminish")
	cfg["orbit_max_targets"] = -1  # A/B-контроль диминиша: снимаем и жёсткий кап-ширины (изоляция канала)
	var weapon := _new_weapon(owner, cfg)
	var center: Vector2 = owner.global_position
	var half_size: float = float(weapon.get("aoe_radius")) * 0.72
	var ranks := _spawn_ranks(holder, center, 6)
	await process_frame
	weapon.call("_elemental_square_tick", owner, center, half_size, 4, 0)
	await process_frame
	var core_dmg: float = (ranks[0] as MockEnemy).total_damage
	var core_burn := _burn_dot(ranks[0])
	for rank in range(6):
		var got_dmg: float = (ranks[rank] as MockEnemy).total_damage
		var got_burn := _burn_dot(ranks[rank])
		if absf(got_dmg - core_dmg) > core_dmg * RATIO_EPS + EPS:
			errors.append("orbit control rank %d magic+phys=%.3f != %.3f — без override тик не должен диминишиться (A/B-регресс)" % [rank, got_dmg, core_dmg])
		if absf(got_burn - core_burn) > core_burn * RATIO_EPS + EPS:
			errors.append("orbit control rank %d burn=%.3f != %.3f — без override ожог не должен диминишиться" % [rank, got_burn, core_burn])
	await _cleanup(holder)


# 7/8. Реальные конфиги + CONST-guard.
func _test_real_configs_and_constants(errors: Array) -> void:
	# orb_ring несёт orbit-кап 3/1.0 (v3''-калибровка; per-hit → 3c-c/validation).
	var orb: Dictionary = PD.weapon("elementalist", "elementalist_orb_ring")
	if int(orb.get("orbit_full_targets", -1)) != 3 or absf(float(orb.get("orbit_target_diminish", -1.0)) - 1.0) > 0.001:
		errors.append("orb_ring orbit cap != 3/1.0 (silent-retune?): full=%s diminish=%s" % [str(orb.get("orbit_full_targets", -1)), str(orb.get("orbit_target_diminish", -1.0))])
	# blast_powder — прямой AoE-путь (aoe_projectile → _damage_aoe_projectile_explosion), НЕ
	# falloff: его геометрию режем S1-полями aoe_full_targets/aoe_target_diminish = 4/3.0.
	var blast: Dictionary = PD.weapon("chemist", "blast_powder")
	if int(blast.get("aoe_full_targets", -1)) != 2 or absf(float(blast.get("aoe_target_diminish", -1.0)) - 3.0) > 0.001:
		errors.append("blast_powder aoe cap != 2/3.0 (silent-retune?): full=%s diminish=%s" % [str(blast.get("aoe_full_targets", -1)), str(blast.get("aoe_target_diminish", -1.0))])
	if blast.has("falloff_full_targets") or blast.has("orbit_full_targets"):
		errors.append("blast_powder НЕ должен нести falloff/orbit-override (его канал — прямой AoE); нашли falloff=%s orbit=%s" % [str(blast.get("falloff_full_targets")), str(blast.get("orbit_full_targets"))])
	# falloff-рычаг: FAN-1031 3d переопределён на priest_reliquary (крауд-драйвер Священника,
	# 4/1.5) — остальные оружия его НЕ несут (dark_mage burst де-эскалирован numeric'ом).
	for entry in [["dark_mage", "cursed_skull"], ["dark_mage", "dark_wand"]]:
		var cfg: Dictionary = PD.weapon(entry[0], entry[1])
		if cfg.has("falloff_full_targets") or cfg.has("falloff_target_diminish"):
			errors.append("%s НЕ должен нести falloff-override в 3c-b2 (deferred к калибровке); нашли %s/%s" % [entry[1], str(cfg.get("falloff_full_targets")), str(cfg.get("falloff_target_diminish"))])
	# CONST-guard: дефолты диминиша = 0.0 (no-op), full = 4 — не сдвинуты молча.
	if absf(ClassWeapon.FALLOFF_FANOUT_TARGET_DIMINISH - 0.0) > 0.0001:
		errors.append("CONST-guard: FALLOFF_FANOUT_TARGET_DIMINISH=%.4f != 0.0 — дефолт больше не no-op" % ClassWeapon.FALLOFF_FANOUT_TARGET_DIMINISH)
	if absf(ClassWeapon.ORBIT_FANOUT_TARGET_DIMINISH - 0.0) > 0.0001:
		errors.append("CONST-guard: ORBIT_FANOUT_TARGET_DIMINISH=%.4f != 0.0 — дефолт больше не no-op" % ClassWeapon.ORBIT_FANOUT_TARGET_DIMINISH)
	if ClassWeapon.FALLOFF_FANOUT_FULL_TARGETS != 4 or ClassWeapon.ORBIT_FANOUT_FULL_TARGETS != 4:
		errors.append("CONST-guard: FANOUT_FULL_TARGETS сдвинут (falloff=%d orbit=%d; ждали 4/4)" % [ClassWeapon.FALLOFF_FANOUT_FULL_TARGETS, ClassWeapon.ORBIT_FANOUT_FULL_TARGETS])
