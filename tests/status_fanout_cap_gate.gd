extends SceneTree

# FAN-1031 3c(b): data-driven кап STATUS fan-out канала (крауд-раздача DoT-статусов).
#
# Контекст. S1 (3a) капнул прямой AoE-взрыв; 3c(a) — пул-канал (тик лужи + leaves_pool).
# Оставался ТРЕТИЙ throughput-канал периодики: крауд-раздача ПЕРИОДИЧЕСКИХ СТАТУСОВ.
# skull_curse (Тёмный маг) и bio_infection (Биолог) кладут ПОЛНЫЙ per-target DoT на
# КАЖДОГО врага в зоне — на 20 целях = ×20 к throughput без всякого диминиша. По v3 это
# главный остаток crowd-runaway верхов: lvl20_ideal_20t cursed_skull 96.9k (≈21× медианы
# 4574) при 1t=270; spore_lens 114.5k (≈25×); symbiote_seed 69.1k (≈15×).
#
# 3c(b) добавляет per-weapon поля status_full_targets/status_target_diminish (сентинел <0 →
# STATUS_FANOUT_* с diminish 0 → factor==1 для всех → нулевое изменение без override).
# Оффендер задаёт узкий full + крутой diminish: ближние N носителей прогорают полным тиком
# (identity зоны + пак 1t/5t целы), дальний хвост толпы получает ослабленный DoT. Ранг =
# дистанция от центра каста; формула та же, что _damage_enemies_in_circle_capped / S1 / пул.
#
# Гейт — лёгкий, детерминированный (единичные применения статуса, без 480-кадрового DPS-сима):
#   1. helper _status_fanout_factor: override 4/1.0 → rank0-3 полные, rank4=0.5, rank5=1/3;
#   2. сентинел-контроль: без override — factor 1.0 для ВСЕХ рангов (нулевое изменение);
#   3. интеграция skull_curse: _apply_skull_curse_zone на 6 ранжированных → снапшот
#      dot_damage режет хвост по формуле, ядро (rank0-3) полное;
#   4. интеграция control: тот же кит БЕЗ status-полей → все носители полный тик (A/B);
#   5. интеграция bio_infection: fanout_factor масштабирует применённый dot_damage;
#   6. anti-silent-retune: реальные конфиги (cursed_skull/spore_lens/symbiote_seed =4/1.0;
#      acid_flask — рычаг проведён, но НЕ переопределён → сентинел, deferred к v3');
#   7. CONST-guard: дефолт STATUS_FANOUT_TARGET_DIMINISH==0.0 (no-op) не сдвинут молча.
#
# Запуск: Godot --headless --path . --script res://tests/status_fanout_cap_gate.gd

const ClassWeapon := preload("res://scripts/class_weapon.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")
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
	# Sanity: непортированный ассет → class_weapon.gd не скомпилируется → ClassWeapon.new()
	# вернёт null; гейт обязан упасть громко, а не «пройти» вхолостую (урок 3c-a).
	var probe = ClassWeapon.new()
	if probe == null:
		push_error("Status fan-out cap (FAN-1031 3c-b): ClassWeapon.new() → null (class_weapon.gd не скомпилировался) — гейт недействителен.")
		quit(1)
		return
	probe.free()

	var errors: Array = []
	await _test_factor_helper_override(errors)
	await _test_factor_helper_sentinel_control(errors)
	await _test_skull_curse_zone_integration(errors)
	await _test_skull_curse_zone_control(errors)
	await _test_bio_infection_factor(errors)
	_test_real_configs_and_constants(errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Status fan-out cap (FAN-1031 3c-b): %s" % str(error))
		push_error("Status fan-out cap gate failed with %d error(s)." % errors.size())
		quit(1)
		return
	print("Status fan-out cap gate passed (FAN-1031 3c-b: data-driven crowd-DoT cap, sentinel control, real configs).")
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
# все попадали в aoe_radius черепа).
func _spawn_ranks(holder: Node2D, origin: Vector2, count: int) -> Array:
	var ranks: Array = []
	for k in range(count):
		var enemy := MockEnemy.new()
		holder.add_child(enemy)
		enemy.global_position = origin + Vector2(float(k) * 18.0, 0.0)
		enemy.add_to_group("enemies")
		ranks.append(enemy)
	return ranks


func _cleanup(holder: Node2D) -> void:
	holder.queue_free()
	await process_frame


func _curse_dot(enemy: Node) -> float:
	var snap: Dictionary = StatusEffects.snapshot(enemy)
	return float((snap.get("skull_curse", {}) as Dictionary).get("dot_damage", -1.0))


func _infection_dot(enemy: Node) -> float:
	var snap: Dictionary = StatusEffects.snapshot(enemy)
	return float((snap.get("bio_infection", {}) as Dictionary).get("dot_damage", -1.0))


# --- tests --------------------------------------------------------------------


# 1. Helper напрямую: override full=4/diminish=1.0 → ядро полное, хвост душится.
func _test_factor_helper_override(errors: Array) -> void:
	var holder := _new_scene("FactorOverride")
	var owner := _new_owner(holder, Vector2(1000, 1000))
	var weapon := _new_weapon(owner, {
		"id": "probe", "attack_mode": "aoe_projectile", "damage_parameter": "damage",
		"status_full_targets": 4, "status_target_diminish": 1.0,
	})
	if weapon.status_full_targets != 4 or absf(weapon.status_target_diminish - 1.0) > 0.001:
		errors.append("helper override: конфиг не загрузился (full=%d diminish=%.2f; ждали 4/1.0)" % [weapon.status_full_targets, weapon.status_target_diminish])
	# rank0..3 = 1.0 (ядро), rank4 = 1/(1+1*1)=0.5, rank5 = 1/(1+2*1)=1/3, rank6 = 1/4.
	var expected := {0: 1.0, 1: 1.0, 2: 1.0, 3: 1.0, 4: 0.5, 5: 1.0 / 3.0, 6: 0.25}
	for rank in expected.keys():
		var got: float = weapon.call("_status_fanout_factor", rank)
		if absf(got - float(expected[rank])) > 0.001:
			errors.append("factor override rank %d = %.4f != %.4f (формула диминиша хвоста нарушена)" % [rank, got, float(expected[rank])])
	await _cleanup(holder)


# 2. Сентинел-контроль: без override — factor 1.0 для ВСЕХ рангов (нулевое изменение).
func _test_factor_helper_sentinel_control(errors: Array) -> void:
	var holder := _new_scene("FactorSentinel")
	var owner := _new_owner(holder, Vector2(1000, 1000))
	var weapon := _new_weapon(owner, {
		"id": "probe", "attack_mode": "aoe_projectile", "damage_parameter": "damage",
	})
	if weapon.status_full_targets != -1 or weapon.status_target_diminish != -1.0:
		errors.append("сентинел-контроль: поля не -1 (full=%d diminish=%.2f) — data-driven контракт сломан" % [weapon.status_full_targets, weapon.status_target_diminish])
	for rank in [0, 1, 4, 10, 19]:
		var got: float = weapon.call("_status_fanout_factor", rank)
		if absf(got - 1.0) > 0.001:
			errors.append("сентинел rank %d = %.4f != 1.0 — дефолт STATUS_FANOUT душит без override (нулевое изменение нарушено)" % [rank, got])
	await _cleanup(holder)


# 3. Интеграция: _apply_skull_curse_zone на 6 ранжированных → снапшот dot_damage
#    режет хвост по формуле, ядро полное. Проверяет РЕАЛЬНОЕ проведение (sort+rank+apply).
func _test_skull_curse_zone_integration(errors: Array) -> void:
	var holder := _new_scene("SkullZoneOverride")
	var owner := _new_owner(holder, Vector2(1000, 1000))
	owner.derived_parameters["dot_damage"] = 10.0
	var weapon := _new_weapon(owner, PD.weapon("dark_mage", "cursed_skull"))
	var center: Vector2 = owner.global_position + Vector2(260, 0)
	var ranks := _spawn_ranks(holder, center, 6)
	await process_frame
	weapon.call("_apply_skull_curse_zone", center)
	await process_frame
	# base_tick = dot_damage(10) * curse_tick_multiplier(0.58) * curse_depth(int=0 → 1.0).
	var mult := float(weapon.get("curse_tick_multiplier"))
	var base_tick := 10.0 * mult
	var expected := {0: base_tick, 1: base_tick, 2: base_tick, 3: base_tick, 4: base_tick * 0.5, 5: base_tick / 3.0}
	for rank in expected.keys():
		var got := _curse_dot(ranks[rank])
		if absf(got - float(expected[rank])) > EPS:
			errors.append("skull-zone override rank %d dot=%.3f != %.3f (крауд-DoT кап не проведён на реальном ките)" % [rank, got, float(expected[rank])])
	await _cleanup(holder)


# 4. Интеграция control (A/B): тот же кит БЕЗ status-полей → ВСЕ носители полный тик.
func _test_skull_curse_zone_control(errors: Array) -> void:
	var holder := _new_scene("SkullZoneControl")
	var owner := _new_owner(holder, Vector2(1000, 1000))
	owner.derived_parameters["dot_damage"] = 10.0
	var cfg: Dictionary = PD.weapon("dark_mage", "cursed_skull").duplicate(true)
	cfg.erase("status_full_targets")
	cfg.erase("status_target_diminish")
	var weapon := _new_weapon(owner, cfg)
	var center: Vector2 = owner.global_position + Vector2(260, 0)
	var ranks := _spawn_ranks(holder, center, 6)
	await process_frame
	weapon.call("_apply_skull_curse_zone", center)
	await process_frame
	var base_tick := 10.0 * float(weapon.get("curse_tick_multiplier"))
	for rank in range(6):
		var got := _curse_dot(ranks[rank])
		if absf(got - base_tick) > EPS:
			errors.append("skull-zone control rank %d dot=%.3f != %.3f — без override крауд-DoT не должен диминишиться (A/B-регресс)" % [rank, got, base_tick])
	await _cleanup(holder)


# 5. Интеграция bio_infection: fanout_factor масштабирует применённый dot_damage.
func _test_bio_infection_factor(errors: Array) -> void:
	var holder := _new_scene("BioInfectionFactor")
	var owner := _new_owner(holder, Vector2(1000, 1000))
	owner.derived_parameters["dot_damage"] = 10.0
	# spore_lens: curse_tick_multiplier=1.0 → base = dot_damage.
	var weapon := _new_weapon(owner, PD.weapon("biologist", "biologist_spore_lens"))
	var full_enemy := MockEnemy.new(); holder.add_child(full_enemy); full_enemy.add_to_group("enemies"); full_enemy.global_position = owner.global_position + Vector2(120, 0)
	var half_enemy := MockEnemy.new(); holder.add_child(half_enemy); half_enemy.add_to_group("enemies"); half_enemy.global_position = owner.global_position + Vector2(160, 0)
	await process_frame
	weapon.call("_apply_bio_infection", full_enemy, owner, 1.0)
	weapon.call("_apply_bio_infection", half_enemy, owner, 0.5)
	var base := 10.0 * float(weapon.get("curse_tick_multiplier"))
	var full_dot := _infection_dot(full_enemy)
	var half_dot := _infection_dot(half_enemy)
	if absf(full_dot - base) > EPS:
		errors.append("bio_infection factor=1.0 dot=%.3f != %.3f (полный тик искажён)" % [full_dot, base])
	if absf(half_dot - base * 0.5) > EPS:
		errors.append("bio_infection factor=0.5 dot=%.3f != %.3f (fanout_factor не масштабирует тик)" % [half_dot, base * 0.5])
	await _cleanup(holder)


# 6/7. Реальные конфиги + CONST-guard.
func _test_real_configs_and_constants(errors: Array) -> void:
	# Крауд-DoT оффендеры несут первичный кап 4/1.0 (v3-калибровка; величина → 3c-c/validation).
	for entry in [["dark_mage", "cursed_skull"], ["biologist", "biologist_spore_lens"], ["biologist", "biologist_symbiote_seed"]]:
		var cfg: Dictionary = PD.weapon(entry[0], entry[1])
		if int(cfg.get("status_full_targets", -1)) != 4 or absf(float(cfg.get("status_target_diminish", -1.0)) - 1.0) > 0.001:
			errors.append("%s status cap != 4/1.0 (silent-retune крауд-DoT капа?): full=%s diminish=%s" % [entry[1], str(cfg.get("status_full_targets", -1)), str(cfg.get("status_target_diminish", -1.0))])
	# acid_flask: рычаг проведён в _apply_pool_contact_statuses, но НЕ переопределён —
	# сентинел (заряды уже пул-капнуты в 3c-a; величину charge-fanout калибрует v3').
	var acid: Dictionary = PD.weapon("chemist", "acid_flask")
	if acid.has("status_full_targets") or acid.has("status_target_diminish"):
		errors.append("acid_flask НЕ должен нести status-override в 3c-b (deferred к v3'); нашли %s/%s" % [str(acid.get("status_full_targets")), str(acid.get("status_target_diminish"))])
	# CONST-guard: дефолт диминиша = 0.0 (no-op), full = 4 — не сдвинуты молча.
	if absf(ClassWeapon.STATUS_FANOUT_TARGET_DIMINISH - 0.0) > 0.0001:
		errors.append("CONST-guard: STATUS_FANOUT_TARGET_DIMINISH=%.4f != 0.0 — дефолт больше не no-op (нулевое изменение без override сломано)" % ClassWeapon.STATUS_FANOUT_TARGET_DIMINISH)
	if ClassWeapon.STATUS_FANOUT_FULL_TARGETS != 4:
		errors.append("CONST-guard: STATUS_FANOUT_FULL_TARGETS=%d != 4 (молчаливый сдвиг дефолта)" % ClassWeapon.STATUS_FANOUT_FULL_TARGETS)
