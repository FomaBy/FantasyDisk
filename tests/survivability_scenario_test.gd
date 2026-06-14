extends SceneTree

# SCRUM-190: гейт сценариев выживаемости. Проверяет модель
# tools/survivability_harness.gd (детерминированную) на инвариантах И якорит её
# к реальному Player.take_damage, чтобы формула EHP не разошлась с боевым кодом.
#
# Жёсткие гейты (детерминированные, без флака):
#   1. TTD строго растёт по стойкости профиля (fragile<steady<sturdy<tank) в
#      каждом сценарии — иначе EHP-модель сломана.
#   2. Каждый слой митигейта срезает >=0 dps; absorb/defense/dodge у sturdy/tank > 0.
#   3. effective_dps > 0 и TTD конечен везде.
#   4. Доля absorb выше в рое мелких ударов, чем в бурсте (плоский absorb).
#   5. ЯКОРЬ: реальный Player.take_damage на НЕувёрнутом ударе снимает ровно
#      expected_hit_damage(amount, defense, absorb, 0) от его же derived_parameters.
#   6. Анти-вакуум: 4 профиля × 4 сценария = 16 строк.
#
# Запуск: Godot --headless --path . --script res://tests/survivability_scenario_test.gd

const Surv := preload("res://tools/survivability_harness.gd")
const ProgressionData := preload("res://scripts/progression_data.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")

const EPS := 0.01


func _initialize() -> void:
	seed(424242)
	var errors: Array = []
	var rows := Surv.build_model()

	# --- Анти-вакуум ---
	if Surv.PROFILES.size() != 4:
		errors.append("ожидалось 4 профиля, есть %d" % Surv.PROFILES.size())
	if rows.size() != Surv.PROFILES.size() * Surv.SCENARIOS.size():
		errors.append("строк модели %d != профили×сценарии %d" % [rows.size(), Surv.PROFILES.size() * Surv.SCENARIOS.size()])

	# Индексируем по (profile,scenario).
	var by_key := {}
	for row in rows:
		by_key["%s/%s" % [row["profile"], row["scenario"]]] = row

	# --- Гейт 2/3: слои митигейта и конечность ---
	for row in rows:
		if not is_finite(float(row["ttd"])) or float(row["ttd"]) <= 0.0:
			errors.append("%s/%s: TTD неконечен/неположителен (%s)" % [row["profile"], row["scenario"], row["ttd"]])
		if float(row["effective_dps"]) <= 0.0:
			errors.append("%s/%s: effective_dps <= 0" % [row["profile"], row["scenario"]])
		for layer in ["absorb_prev", "defense_prev", "dodge_prev", "regen_prev"]:
			if float(row[layer]) < -EPS:
				errors.append("%s/%s: %s отрицателен (%.3f)" % [row["profile"], row["scenario"], layer, float(row[layer])])
	for tough in ["sturdy", "tank"]:
		var r: Dictionary = by_key["%s/elite_burst" % tough]
		for layer in ["absorb_prev", "defense_prev", "dodge_prev"]:
			if float(r[layer]) <= 0.0:
				errors.append("%s: слой %s не вносит вклад (%.3f) — ожидался положительный" % [tough, layer, float(r[layer])])

	# --- Гейт 1: монотонность TTD по стойкости ---
	var order := ["fragile", "steady", "sturdy", "tank"]
	for scenario in Surv.SCENARIOS:
		var sid := str(scenario["id"])
		for i in range(order.size() - 1):
			var lo: float = float(by_key["%s/%s" % [order[i], sid]]["ttd"])
			var hi: float = float(by_key["%s/%s" % [order[i + 1], sid]]["ttd"])
			if not (hi > lo):
				errors.append("%s: TTD не растёт %s(%.1f) -> %s(%.1f)" % [sid, order[i], lo, order[i + 1], hi])

	# --- Гейт 4: absorb сильнее против роя, чем против бурста ---
	for profile in Surv.PROFILES:
		var pid := str(profile["id"])
		var swarm: Dictionary = by_key["%s/contact_swarm" % pid]
		var burst: Dictionary = by_key["%s/elite_burst" % pid]
		var swarm_share := float(swarm["absorb_prev"]) / maxf(float(swarm["raw_dps"]), 0.001)
		var burst_share := float(burst["absorb_prev"]) / maxf(float(burst["raw_dps"]), 0.001)
		if not (swarm_share > burst_share + EPS):
			errors.append("%s: доля absorb в рое (%.2f) не выше, чем в бурсте (%.2f)" % [pid, swarm_share, burst_share])

	# --- Гейт 5: якорь к реальному Player.take_damage ---
	await process_frame
	var holder := Node2D.new()
	root.add_child(holder)
	await process_frame
	var player := PLAYER_SCENE.instantiate() as Node2D
	holder.add_child(player)
	player.add_to_group("player")
	if not player.has_method("configure_character") or not player.has_method("take_damage"):
		errors.append("Player без configure_character/take_damage — якорь невозможен")
	else:
		player.configure_character("berserk", "")
		await process_frame
		var dp: Dictionary = player.get("derived_parameters")
		var defense := clampf(float(dp.get("defense", 0.0)), 0.0, ProgressionData.SURVIVABILITY_DEFENSE_CAP)
		var absorb := float(dp.get("absorb", 0.0))
		player.set("max_health", 1.0e9)
		player.set("health", 1.0e9)
		var amount := 40.0
		var expected := Surv.expected_hit_damage(amount, defense, absorb, 0.0)
		var checked_hits := 0
		for _i in range(80):
			player.set("_damage_invulnerability_left", 0.0)
			var before := float(player.get("health"))
			var landed: bool = player.take_damage(amount)
			var after := float(player.get("health"))
			if landed and after < before:
				var actual := before - after
				checked_hits += 1
				if absf(actual - expected) > 0.05:
					errors.append("якорь: реальный урон %.3f != формула %.3f (def=%.3f abs=%.3f)" % [actual, expected, defense, absorb])
					break
		if checked_hits == 0:
			errors.append("якорь: ни одного неувёрнутого удара за 80 попыток — проверка вакуумна")
		else:
			print("Якорь take_damage: %d неувёрнутых ударов, урон %.3f == формула %.3f" % [checked_hits, expected, expected])
	player.queue_free()
	holder.queue_free()
	await process_frame

	if not errors.is_empty():
		for e in errors:
			push_error("Survivability scenario: %s" % e)
		push_error("Survivability scenario test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Survivability scenario test passed (%d строк модели, монотонность/слои/absorb/якорь зелёные)." % rows.size())
	quit(0)
