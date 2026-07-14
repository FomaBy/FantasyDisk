extends SceneTree

# FAN-1031 S2 (Stage 3a): live-регресс на ваншот ЛЮБОГО класса зоной/сламом/хазардом
# босса. Контактный урон уже капится 20% max HP (enemy._update_contact_damage,
# SCRUM-599), элитный — 25% (enemy._elite_attack_damage), но урон ЗОН/СЛАМОВ/УКУСОВ
# босса (rift_zone, disk_slam, brood_web, ash_ember, gravity_well, molten_armor,
# bloodthorn_spike, secret_* , boss_phase, devourer_vampiric_bite) шёл в
# player.take_damage БЕЗ фракционного капа. Baseline v2 (FAN-1029): hazard фазы 4 на
# A5 ≈ 164 урона против typ HP 50–157 → «ваншот-вердикт — все 17 классов». Фикс:
# enemy._hazard_hit(base, player) = minf(_outgoing_damage(base), max_health *
# BOSS_HAZARD_MAX_HP_FRACTION). Все 11 хазард-сайтов boss.gd зовут этот чокпоинт.
#
# Гейт гоняет НАСТОЯЩИЕ Boss/Enemy + Player на боевом коде через общий чокпоинт:
#   A. CAP: гигантский hazard-тик капится РОВНО в 80% max HP (64 при max_health=80) —
#      full-HP герой переживает один тик даже с нулевой митигацией.
#   B. PASSTHROUGH: слабый hazard-тик (ниже капа) проходит без срезки — кап не ломает
#      ранние фазы.
#   C. E2E: доставка капнутого тика через player.take_damage роняет <= 80% max HP.
#   D. CONST: BOSS_HAZARD_MAX_HP_FRACTION == 0.80 (анти-silent-retune, DoD FAN-1031).
#
# Митигацию (dodge/defense/absorb) обнуляем, чтобы HP-дроп == доставленному урону.
#
# Запуск: Godot --headless --path . --script res://tests/boss_hazard_cap_gate.gd

const ProgressionData := preload("res://scripts/progression_data.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
# _hazard_hit определён на enemy.gd (родитель boss.gd) — тестируем общий чокпоинт
# через реальный Enemy (boss наследует ровно эту функцию, все 11 хазард-сайтов зовут её).
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")

const EPS := 0.05
const MAX_HP := 80.0
const EXPECTED_FRACTION := 0.80  # должно совпадать с ProgressionData.BOSS_HAZARD_MAX_HP_FRACTION


func _neutralize_mitigation(player: Node2D) -> void:
	var dp: Dictionary = player.get("derived_parameters")
	if dp == null:
		dp = {}
	dp["dodge"] = 0.0
	dp["defense"] = 0.0
	dp["absorb"] = 0.0
	player.set("derived_parameters", dp)
	player.set("_damage_invulnerability_left", 0.0)


func _initialize() -> void:
	seed(1031103)
	var errors: Array = []

	await process_frame
	var holder := Node2D.new()
	root.add_child(holder)
	await process_frame

	var boss := ENEMY_SCENE.instantiate() as Node2D
	holder.add_child(boss)
	boss.add_to_group("enemies")
	var player := PLAYER_SCENE.instantiate() as Node2D
	holder.add_child(player)
	player.add_to_group("player")
	await process_frame

	if not boss.has_method("_hazard_hit") or not player.has_method("take_damage"):
		push_error("Boss hazard cap: нет _hazard_hit/take_damage — гейт невозможен.")
		quit(1)
		return

	player.set("max_health", MAX_HP)
	player.set("health", MAX_HP)
	var cap_value := MAX_HP * EXPECTED_FRACTION  # 64.0

	# --- D. CONST ---
	var frac: float = ProgressionData.BOSS_HAZARD_MAX_HP_FRACTION
	if absf(frac - EXPECTED_FRACTION) > 0.0001:
		errors.append("CONST: BOSS_HAZARD_MAX_HP_FRACTION=%.4f != %.2f (silent-retune без задокументированного решения)" % [frac, EXPECTED_FRACTION])

	# --- A. CAP: огромный hazard-тик капится ровно в 80% max HP ---
	var capped: float = boss.call("_hazard_hit", 1.0e9, player)
	if absf(capped - cap_value) > EPS:
		errors.append("CAP: _hazard_hit(1e9) = %.2f, ожидали %.2f (%.0f%% от %.0f)" % [capped, cap_value, EXPECTED_FRACTION * 100.0, MAX_HP])
	print("[hazard-gate] CAP: _hazard_hit(1e9) → %.2f (cap %.2f)" % [capped, cap_value])

	# --- B. PASSTHROUGH: слабый тик ниже капа не пинуется в кап ---
	var weak_base := MAX_HP * 0.10  # 8.0, заведомо ниже капа 64
	var weak: float = boss.call("_hazard_hit", weak_base, player)
	if weak <= EPS:
		errors.append("PASSTHROUGH: слабый тик обнулён (%.2f)" % weak)
	if weak >= cap_value - EPS:
		errors.append("PASSTHROUGH: слабый тик %.2f подтянут к капу %.2f — кап ломает ранние фазы" % [weak, cap_value])
	print("[hazard-gate] PASSTHROUGH: _hazard_hit(%.1f) → %.2f (< cap %.2f)" % [weak_base, weak, cap_value])

	# --- C. E2E: доставка капнутого тика роняет <= 80% max HP ---
	player.set("health", MAX_HP)
	player.set("max_health", MAX_HP)
	_neutralize_mitigation(player)
	var hp_before := float(player.get("health"))
	var delivered: float = boss.call("_hazard_hit", 1.0e9, player)
	player.take_damage(delivered, "rift_zone")
	var drop := hp_before - float(player.get("health"))
	if drop > cap_value + EPS:
		errors.append("E2E: hazard-тик уронил %.2f HP > капа %.2f — ваншот full-HP всё ещё возможен" % [drop, cap_value])
	if drop <= EPS:
		errors.append("E2E: hazard-тик не нанёс урона (drop=%.2f) — доставка сломана" % drop)
	print("[hazard-gate] E2E: full-HP %.0f → drop %.2f (<= %.2f, выжил)" % [MAX_HP, drop, cap_value])

	boss.queue_free()
	player.queue_free()
	holder.queue_free()
	await process_frame

	if not errors.is_empty():
		for e in errors:
			push_error("Boss hazard cap gate: %s" % e)
		push_error("Boss hazard cap gate: %d ошибок." % errors.size())
		quit(1)
		return
	print("Boss hazard cap gate passed: зоны/сламы/хазарды босса капятся 80%% max HP, full-HP герой переживает тик, слабый тик проходит без срезки.")
	quit(0)
