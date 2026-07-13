extends SceneTree

# FAN-1031 S1 (3a) + 3c-final (peer review MAJOR): anti-silent-retune замок прямого AoE-капа.
#
# S1 ввёл per-weapon data-driven кап прямого AoE-взрыва — поля aoe_full_targets/aoe_target_diminish
# (сентинел <0 → общие дефолты AOE_PROJECTILE_FULL_TARGETS=5 / AOE_PROJECTILE_TARGET_DIMINISH=2.0).
# Это первый и самый широкий крауд-канал, но до сих пор он был ЕДИНСТВЕННЫМ без anti-silent-retune
# гейта: обещанный tests/aoe_target_cap_gate.gd не существовал, а глобальные дефолты 5/2.0 не были
# запинены ни одним CONST-guard (peer review MAJOR, class_weapon.gd:306). Этот гейт закрывает дыру.
#
# Гейт — лёгкий, детерминированный (единичные вызовы _damage_aoe_projectile_explosion):
#   1. override 2/1.0 → 2 ближних полным, дальше 1/(1+(rank−full+1)·diminish);
#   2. сентинел-контроль (без override) → дефолт 5/2.0: 5 ближних полным, rank5 срезан;
#   3. CONST-guard: AOE_PROJECTILE_FULL_TARGETS==5, AOE_PROJECTILE_TARGET_DIMINISH==2.0 (не сдвинуты молча);
#   4. реальный конфиг blast_powder aoe=4/3.0 (S1-калибровка 3c-b2) не перекалиброван молча.
#
# Запуск: Godot --headless --path . --script res://tests/aoe_target_cap_gate.gd

const ClassWeapon := preload("res://scripts/class_weapon.gd")
const PD := preload("res://scripts/progression_data.gd")

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
	var probe = ClassWeapon.new()
	if probe == null:
		push_error("AoE cap (FAN-1031 S1): ClassWeapon.new() → null (class_weapon.gd не скомпилировался) — гейт недействителен.")
		quit(1)
		return
	probe.free()

	var errors: Array = []
	await _test_override(errors)
	await _test_sentinel_control(errors)
	_test_constants_and_real_config(errors)

	if not errors.is_empty():
		for error in errors:
			push_error("AoE cap (FAN-1031 S1): %s" % str(error))
		push_error("AoE target cap gate failed with %d error(s)." % errors.size())
		quit(1)
		return
	print("AoE target cap gate passed (FAN-1031 S1: direct-AoE diminish A/B, sentinel default, CONST-guard 5/2.0, blast_powder 4/3.0 pinned).")
	quit(0)


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


func _expected_factor(rank: int, full: int, diminish: float) -> float:
	if diminish <= 0.0 or rank < full:
		return 1.0
	return 1.0 / (1.0 + float(rank - full + 1) * diminish)


# 1. override 2/1.0 → 2 ближних полным, хвост душится по формуле.
func _test_override(errors: Array) -> void:
	var holder := _new_scene("AoeOverride")
	var owner := _new_owner(holder, Vector2(1000, 1000))
	var weapon := _new_weapon(owner, {
		"id": "probe", "attack_mode": "aoe_projectile", "damage_parameter": "damage",
		"aoe_radius": 400.0, "aoe_full_targets": 2, "aoe_target_diminish": 1.0,
	})
	if weapon.aoe_full_targets != 2 or absf(weapon.aoe_target_diminish - 1.0) > 0.001:
		errors.append("override: конфиг не загрузился (full=%d diminish=%.2f; ждали 2/1.0)" % [weapon.aoe_full_targets, weapon.aoe_target_diminish])
	var origin: Vector2 = owner.global_position
	var ranks := _spawn_ranks(holder, origin, 6)
	await process_frame
	var amount := 200.0
	weapon.call("_damage_aoe_projectile_explosion", origin, 400.0, amount)
	for rank in range(6):
		var expected := amount * _expected_factor(rank, 2, 1.0)
		var got: float = (ranks[rank] as MockEnemy).total_damage
		if absf(got - expected) > EPS:
			errors.append("override rank %d dmg=%.3f != %.3f (S1 диминиш не проведён через _damage_aoe_projectile_explosion)" % [rank, got, expected])
	await _cleanup(holder)


# 2. Сентинел-контроль (без override) → дефолт 5/2.0: 5 ближних полным, rank5 срезан.
func _test_sentinel_control(errors: Array) -> void:
	var holder := _new_scene("AoeSentinel")
	var owner := _new_owner(holder, Vector2(1000, 1000))
	var weapon := _new_weapon(owner, {
		"id": "probe", "attack_mode": "aoe_projectile", "damage_parameter": "damage",
		"aoe_radius": 400.0,
	})
	if weapon.aoe_full_targets != -1 or weapon.aoe_target_diminish != -1.0:
		errors.append("сентинел: поля не -1 (full=%d diminish=%.2f) — data-driven контракт сломан" % [weapon.aoe_full_targets, weapon.aoe_target_diminish])
	var origin: Vector2 = owner.global_position
	var ranks := _spawn_ranks(holder, origin, 6)
	await process_frame
	var amount := 200.0
	weapon.call("_damage_aoe_projectile_explosion", origin, 400.0, amount)
	for rank in range(6):
		var expected := amount * _expected_factor(rank, ClassWeapon.AOE_PROJECTILE_FULL_TARGETS, ClassWeapon.AOE_PROJECTILE_TARGET_DIMINISH)
		var got: float = (ranks[rank] as MockEnemy).total_damage
		if absf(got - expected) > EPS:
			errors.append("сентинел rank %d dmg=%.3f != %.3f — без override дефолт 5/2.0 не применён" % [rank, got, expected])
	await _cleanup(holder)


# 3/4. CONST-guard дефолтов + реальный конфиг blast_powder.
func _test_constants_and_real_config(errors: Array) -> void:
	if ClassWeapon.AOE_PROJECTILE_FULL_TARGETS != 5:
		errors.append("CONST-guard: AOE_PROJECTILE_FULL_TARGETS=%d != 5 — дефолт прямого AoE-капа сдвинут молча" % ClassWeapon.AOE_PROJECTILE_FULL_TARGETS)
	if absf(ClassWeapon.AOE_PROJECTILE_TARGET_DIMINISH - 2.0) > 0.0001:
		errors.append("CONST-guard: AOE_PROJECTILE_TARGET_DIMINISH=%.3f != 2.0 — дефолт прямого AoE-капа сдвинут молча" % ClassWeapon.AOE_PROJECTILE_TARGET_DIMINISH)
	# blast_powder несёт калибровку 2/3.0 (FAN-1031 3d: ужато с 4/3.0 — v6 honest всё ещё держал
	# blast aoe 8.78×/crowd 3.96×; см. no-silent-retune лог) — не перекалибрована молча.
	var blast: Dictionary = PD.weapon("chemist", "blast_powder")
	if int(blast.get("aoe_full_targets", -1)) != 2 or absf(float(blast.get("aoe_target_diminish", -1.0)) - 3.0) > 0.001:
		errors.append("blast_powder aoe cap != 2/3.0 (silent-retune?): full=%s diminish=%s" % [str(blast.get("aoe_full_targets", -1)), str(blast.get("aoe_target_diminish", -1.0))])
