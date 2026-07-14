extends SceneTree

# FAN-1031 3c(a): data-driven кап ПУЛ-канала (тик лужи + прямая leaves_pool-ветка).
#
# Контекст. S1 (3a) сделал per-weapon кап только для ПРЯМОГО AoE-взрыва
# (_damage_aoe_projectile_explosion, поля aoe_full_targets/aoe_target_diminish). Но
# главный канал crowd-runaway периодики — ТИКИ ЛУЖ (_damage_enemies_in_pool) и прямая
# leaves_pool-ветка — оставался на КОНСТАНТАХ кода (POOL_*/POOL_PROJECTILE_*), а не на
# данных. Поэтому restore_potion в живом v3-замере упал только −24% вместо проектных
# −72%: капнутый F=1/D=4 ловил лишь основной взрыв, а vapor и pool-каналы — нет.
#
# 3c(a) добавляет per-weapon поля pool_full_targets/pool_target_diminish (сентинел <0 →
# per-channel default): узкий full + крутой diminish душат ХВОСТ лужи на толпе, не трогая
# ядро пака (rank0 = полный тик → одиночная/дуо-цель identity сохранена).
#
# Гейт — лёгкий и детерминированный (единичные вызовы урона, без 480-кадрового DPS-сима):
#   1. пул-тик: override diminish режет rank1 круче default'а, rank0 полный;
#   2. сентинел-контроль: без override — прежний default (нулевое изменение поведения);
#   3. leaves_pool-ветка: override уважается и на прямом взрыве лужи;
#   4. anti-silent-retune: реальные конфиги (acid_flask pool_target_diminish=3.0;
#      restore_potion aoe_full_targets/diminish=1/4.0 → vapor наследует сустейн-кап);
#   5. CONST-guard: дефолты пул-капа не сдвинуты молча.
#
# Запуск: Godot --headless --path . --script res://tests/pool_target_cap_gate.gd

const ClassWeapon := preload("res://scripts/class_weapon.gd")
const PD := preload("res://scripts/progression_data.gd")

const EPS := 0.05


class MockOwner extends CharacterBody2D:
	var derived_parameters := {
		"damage": 100.0,
		"magic_damage": 100.0,
		"dot_damage": 4.0,
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

	# Одноаргументный take_damage → _take_damage_accepts_feedback == false
	# (ветка без feedback), как у боевых заглушек прочих focused-гейтов.
	func take_damage(amount: float) -> void:
		total_damage += amount
		hit_count += 1


func _initialize() -> void:
	seed(20260713)
	# Sanity: если class_weapon.gd не скомпилировался (напр. непортированный ассет),
	# ClassWeapon.new() вернёт null — гейт обязан упасть громко, а не «пройти» вхолостую.
	var probe = ClassWeapon.new()
	if probe == null:
		push_error("Pool target cap (FAN-1031 3c-a): ClassWeapon.new() → null (class_weapon.gd не скомпилировался) — гейт недействителен, не зелёный.")
		quit(1)
		return
	probe.free()

	var errors: Array = []
	await _test_pool_tick_override_caps_crowd(errors)
	await _test_pool_tick_sentinel_control(errors)
	await _test_leaves_pool_branch_override(errors)
	_test_real_configs_and_constants(errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Pool target cap (FAN-1031 3c-a): %s" % str(error))
		push_error("Pool target cap gate failed with %d error(s)." % errors.size())
		quit(1)
		return
	print("Pool target cap gate passed (FAN-1031 3c-a: data-driven pool/leaves_pool cap, sentinel control, real configs).")
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


# Цели по лучу с растущим удалением от центра лужи: rank = удалённость.
func _spawn_ranks(holder: Node2D, origin: Vector2, count: int) -> Array:
	var ranks: Array = []
	for k in range(count):
		var enemy := MockEnemy.new()
		holder.add_child(enemy)
		enemy.global_position = origin + Vector2(float(k) * 24.0, 0.0)
		enemy.add_to_group("enemies")
		ranks.append(enemy)
	return ranks


func _cleanup(holder: Node2D) -> void:
	holder.queue_free()
	await process_frame


# --- tests --------------------------------------------------------------------


func _test_pool_tick_override_caps_crowd(errors: Array) -> void:
	var holder := _new_scene("PoolTickOverride")
	var owner := _new_owner(holder, Vector2(1000, 1000))
	# База — реальная колба; поверх кладём override diminish=5.0 (≠ обоих дефолтов
	# 1.5/3.0), full=1, чтобы срез был однозначно от per-weapon данных.
	var cfg: Dictionary = PD.weapon("chemist", "acid_flask").duplicate(true)
	cfg["pool_full_targets"] = 1
	cfg["pool_target_diminish"] = 5.0
	var weapon := _new_weapon(owner, cfg)
	if weapon.pool_full_targets != 1 or absf(weapon.pool_target_diminish - 5.0) > 0.001:
		errors.append("пул-override: конфиг не загрузился (full=%d, diminish=%.2f; ждали 1/5.0)" % [weapon.pool_full_targets, weapon.pool_target_diminish])
	var origin: Vector2 = owner.global_position + Vector2(300, 0)
	var ranks := _spawn_ranks(holder, origin, 4)
	await process_frame

	weapon.call("_damage_enemies_in_pool", origin, weapon.aoe_radius, 100.0)
	await process_frame
	var d0: float = ranks[0].total_damage
	var d1: float = ranks[1].total_damage
	var d2: float = ranks[2].total_damage
	# rank0 полный (ядро лужи), rank1 = 100/(1+1*5)=16.67, rank2 = 100/(1+2*5)=9.09.
	if absf(d0 - 100.0) > EPS:
		errors.append("пул-тик override: ядро %.2f != 100 (rank0 обязан быть полным — solo-тик лужи не должен страдать)" % d0)
	if absf(d1 - 100.0 / 6.0) > EPS:
		errors.append("пул-тик override: rank1 %.2f != 16.67 (data-driven кап D=5 не сработал на тике лужи)" % d1)
	if absf(d2 - 100.0 / 11.0) > EPS:
		errors.append("пул-тик override: rank2 %.2f != 9.09 (формула диминиша нарушена)" % d2)
	await _cleanup(holder)


func _test_pool_tick_sentinel_control(errors: Array) -> void:
	var holder := _new_scene("PoolTickControl")
	var owner := _new_owner(holder, Vector2(1000, 1000))
	# Тот же конфиг БЕЗ пул-override → сентинел → default POOL_TARGET_DIMINISH=1.5.
	var cfg: Dictionary = PD.weapon("chemist", "acid_flask").duplicate(true)
	cfg.erase("pool_full_targets")
	cfg.erase("pool_target_diminish")
	var weapon := _new_weapon(owner, cfg)
	if weapon.pool_full_targets != -1 or weapon.pool_target_diminish != -1.0:
		errors.append("пул-контроль: сентинел не -1 (full=%d, diminish=%.2f) — механика data-driven капа сломана" % [weapon.pool_full_targets, weapon.pool_target_diminish])
	var origin: Vector2 = owner.global_position + Vector2(300, 0)
	var ranks := _spawn_ranks(holder, origin, 4)
	await process_frame

	weapon.call("_damage_enemies_in_pool", origin, weapon.aoe_radius, 100.0)
	await process_frame
	var d0: float = ranks[0].total_damage
	var d1: float = ranks[1].total_damage
	# default POOL_FULL_TARGETS=1, POOL_TARGET_DIMINISH=1.5 → rank1 = 100/(1+1.5)=40.
	if absf(d0 - 100.0) > EPS:
		errors.append("пул-тик контроль: ядро %.2f != 100" % d0)
	if absf(d1 - 40.0) > EPS:
		errors.append("пул-тик контроль: rank1 %.2f != 40 — сентинел не откатился к default 1.5 (нулевое изменение поведения нарушено)" % d1)
	await _cleanup(holder)


func _test_leaves_pool_branch_override(errors: Array) -> void:
	# Прямая leaves_pool-ветка _damage_aoe_projectile_explosion: override diminish
	# уважается и здесь (иначе колба ловит кап только на тике лужи, а прямой взрыв — нет).
	var holder := _new_scene("LeavesPoolOverride")
	var owner := _new_owner(holder, Vector2(1000, 1000))
	var origin: Vector2 = owner.global_position + Vector2(300, 0)

	# A. override diminish=5.0.
	var cfg: Dictionary = PD.weapon("chemist", "acid_flask").duplicate(true)
	cfg["pool_full_targets"] = 1
	cfg["pool_target_diminish"] = 5.0
	var weapon := _new_weapon(owner, cfg)
	var ranks := _spawn_ranks(holder, origin, 4)
	await process_frame
	weapon.call("_damage_aoe_projectile_explosion", origin, weapon.aoe_radius, 100.0)
	await process_frame
	# base = 100 * POOL_PROJECTILE_DAMAGE_MULTIPLIER(0.55) * pool_direct_damage_multiplier(0.38).
	var base_hit := 100.0 * 0.55 * 0.38
	if absf(float(ranks[0].total_damage) - base_hit) > EPS:
		errors.append("leaves_pool override: ядро %.2f != %.2f (POOL_PROJECTILE mult изменён?)" % [float(ranks[0].total_damage), base_hit])
	if absf(float(ranks[1].total_damage) - base_hit / 6.0) > EPS:
		errors.append("leaves_pool override: rank1 %.2f != %.2f (override D=5 не дошёл до прямой ветки лужи)" % [float(ranks[1].total_damage), base_hit / 6.0])

	# B. контроль — без override → default POOL_PROJECTILE_TARGET_DIMINISH=3.0.
	var control_owner := _new_owner(holder, Vector2(1000, 1700))
	var control_origin: Vector2 = control_owner.global_position + Vector2(300, 0)
	var control_cfg: Dictionary = PD.weapon("chemist", "acid_flask").duplicate(true)
	control_cfg.erase("pool_full_targets")
	control_cfg.erase("pool_target_diminish")
	var control := _new_weapon(control_owner, control_cfg)
	var control_ranks := _spawn_ranks(holder, control_origin, 4)
	await process_frame
	control.call("_damage_aoe_projectile_explosion", control_origin, control.aoe_radius, 100.0)
	await process_frame
	# default D=3.0 → rank1 = base/(1+3) = base/4.
	if absf(float(control_ranks[1].total_damage) - base_hit / 4.0) > EPS:
		errors.append("leaves_pool контроль: rank1 %.2f != %.2f — сентинел не откатился к POOL_PROJECTILE default 3.0" % [float(control_ranks[1].total_damage), base_hit / 4.0])
	await _cleanup(holder)


func _test_real_configs_and_constants(errors: Array) -> void:
	# acid_flask: пул-тик по толпе теперь спадает круче (3c-a первичное сужение).
	var acid: Dictionary = PD.weapon("chemist", "acid_flask")
	if absf(float(acid.get("pool_target_diminish", -1.0)) - 3.0) > 0.001:
		errors.append("acid_flask.pool_target_diminish=%.2f != 3.0 (silent-retune пул-капа?)" % float(acid.get("pool_target_diminish", -1.0)))
	if not bool(acid.get("leaves_pool", false)):
		errors.append("acid_flask должен быть leaves_pool (регресс конфига колбы)")

	# restore_potion: основной взрыв И vapor-канал делят сустейн-кап F=1/D=4.
	var potion: Dictionary = PD.weapon("doctor", "restore_potion")
	if int(potion.get("aoe_full_targets", -1)) != 1 or absf(float(potion.get("aoe_target_diminish", -1.0)) - 4.0) > 0.001:
		errors.append("restore_potion aoe cap != 1/4.0 (vapor-канал наследует его — silent-retune S3?)")

	# CONST-guard: дефолты пул-капа не сдвинуты молча (проверяем через сентинел-путь).
	# Пустой конфиг → сентинел → default; сверяем известную формулу default'а на 2 целях.
	var holder := _new_scene("ConstGuard")
	var owner := _new_owner(holder, Vector2(1000, 2400))
	var weapon := _new_weapon(owner, {"id": "const_probe", "attack_mode": "aoe_projectile", "damage_parameter": "damage", "aoe_radius": 220.0})
	var origin: Vector2 = owner.global_position + Vector2(300, 0)
	var ranks := _spawn_ranks(holder, origin, 2)
	weapon.call("_damage_enemies_in_pool", origin, weapon.aoe_radius, 100.0)
	# default POOL_TARGET_DIMINISH=1.5 → rank1 = 100/2.5 = 40.
	if absf(float(ranks[1].total_damage) - 40.0) > EPS:
		errors.append("CONST-guard: default пул-тик rank1 %.2f != 40 — POOL_TARGET_DIMINISH сдвинут?" % float(ranks[1].total_damage))
	holder.queue_free()
