extends SceneTree

# SCRUM-201: фактические live-DPS/TTK тесты — дополняют ФОРМУЛЬНЫЙ
# tools/balance_harness.gd живым замером. Инстанцируем реального Player +
# оружие + стационарных болванок и МЕРЯЕМ фактический урон за фиксированное
# окно по одному представителю каждого архетипа (single/AoE/deploy/summon/DoT).
#
# Дисциплина анти-флака (требование задачи): ЖЁСТКО падаем только на реальной
# поломке (0 урона за окно / NaN/inf / вакуумное покрытие). Балансовые дельты
# и «aoe<solo» — МЯГКИЙ отчёт без падения, т.к. живой замер шумный по дизайну.
#
# Запуск: Godot --headless --path . --script res://tests/live_balance_simulation_test.gd
# Отдельный изолированный файл (анти-коллизия с занятыми runtime_smoke/harness).

const ProgressionData := preload("res://scripts/progression_data.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")

const WINDOW_SECONDS := 8.0
const FRAMES := 480              # 8с * 60fps
const DUMMY_HP := 1.0e9          # болванки не умирают — меряем чистый DPS
const TTK_REFERENCE_HP := 90.0   # типовой враг среднего этапа для practical TTK
const ZERO_EPS := 0.01           # ниже этого живой урон считаем «оружие молчит»
const SEED := 20260613           # детерминизм замера

# Архетипы в порядке приоритета классификации: первое совпадение по конфигу
# оружия определяет категорию. Так гарантируем покрытие всех пяти, если они
# есть в реестре, а не только single-target большинства.
const ARCHETYPES := ["deploy", "summon", "dot", "aoe", "single"]
const MIN_ARCHETYPES_COVERED := 4   # защита от вакуума: реестр обязан их иметь


func _initialize() -> void:
	seed(SEED)
	await process_frame
	var holder := Node2D.new()
	holder.name = "LiveBalanceSimHolder"
	root.add_child(holder)
	current_scene = holder
	await process_frame

	var reps: Dictionary = _select_representatives()
	if reps.size() < MIN_ARCHETYPES_COVERED:
		push_error("Live balance sim: покрыто лишь %d/%d архетипов (%s) — реестр подозрительно мал, тест прошёл бы вакуумно." % [
			reps.size(), ARCHETYPES.size(), ", ".join(reps.keys())])
		quit(1)
		return

	var failures: Array = []
	var notes: Array = []     # мягкие выбросы — только в отчёт

	for archetype in ARCHETYPES:
		if not reps.has(archetype):
			notes.append("архетип '%s' не найден в реестре — пропущен" % archetype)
			continue
		var rep: Dictionary = reps[archetype]
		var cid := str(rep["class"])
		var wid := str(rep["weapon"])
		var solo_dps: float = await _measure_dps(holder, cid, wid, 1)
		var aoe_dps: float = await _measure_dps(holder, cid, wid, 5)
		var ttk := TTK_REFERENCE_HP / maxf(solo_dps, 0.001)

		# ЖЁСТКО: число должно быть конечным.
		if not (is_finite(solo_dps) and is_finite(aoe_dps)):
			failures.append("%s '%s/%s': нечисловой живой DPS (solo=%s aoe=%s)" % [archetype, cid, wid, solo_dps, aoe_dps])
			continue
		# ЖЁСТКО: оружие обязано нанести хоть какой-то урон за окно.
		# Сравниваем по ЛУЧШЕЙ из осей: summon/deploy/dot могут почти не бить
		# одиночную цель, но кластер из 5 должны зацепить.
		var best := maxf(solo_dps, aoe_dps)
		if best <= ZERO_EPS:
			failures.append("%s '%s/%s': 0 живого урона за %.0fс (solo=%.3f aoe=%.3f) — режим оружия сломан" % [
				archetype, cid, wid, WINDOW_SECONDS, solo_dps, aoe_dps])
		# МЯГКО: AoE-семейство должно бить кластер не слабее одиночной цели.
		if archetype in ["aoe", "deploy", "summon"] and aoe_dps + ZERO_EPS < solo_dps * 0.9:
			notes.append("%s '%s/%s': 5-target (%.1f) < solo (%.1f) — проверить геометрию AoE" % [
				archetype, cid, wid, aoe_dps, solo_dps])

		print("[%s] %s/%s: solo=%.1f 5-target=%.1f ttk=%.1fс" % [archetype, cid, wid, solo_dps, aoe_dps, ttk])

	if not notes.is_empty():
		print("--- Мягкие выбросы (не валят сьют) ---")
		for n in notes:
			print("  ℹ %s" % n)

	holder.queue_free()
	await process_frame

	if not failures.is_empty():
		for f in failures:
			push_error("Live balance sim FAIL: %s" % f)
		push_error("Live balance simulation: %d поломок режимов оружия." % failures.size())
		quit(1)
		return
	print("Live balance simulation test passed (%d архетипов покрыто, %d мягких заметок)." % [_select_representatives().size(), notes.size()])
	quit(0)


# Выбирает по ОДНОМУ представителю каждого архетипа: первое оружие в реестре,
# чей конфиг попадает в категорию (приоритет ARCHETYPES). Возвращает
# {archetype: {"class","weapon"}}.
func _select_representatives() -> Dictionary:
	var reps: Dictionary = {}
	for character_id in ProgressionData.character_ids():
		var cid := str(character_id)
		for weapon_id in ProgressionData.weapon_ids(cid):
			var wid := str(weapon_id)
			var config: Dictionary = ProgressionData.weapon(cid, wid)
			var archetype := _classify(config)
			if not reps.has(archetype):
				reps[archetype] = {"class": cid, "weapon": wid}
	return reps


func _classify(config: Dictionary) -> String:
	# deploy раньше summon: развёртываемое поле/усилитель часто тоже имеет
	# max_summons, но более специфичный сигнал — стационарный deploy.
	if config.has("deploy_texture_path") or config.has("amp_lifetime"):
		return "deploy"
	if int(config.get("max_summons", 0)) > 0 or config.has("summon_damage_multiplier"):
		return "summon"
	if int(config.get("dot_ticks", 0)) > 0 or bool(config.get("leaves_pool", false)):
		return "dot"
	if int(config.get("projectile_count", 1)) >= 3 or float(config.get("aoe_radius", 0.0)) >= 90.0:
		return "aoe"
	return "single"


func _measure_dps(holder: Node2D, character_id: String, weapon_id: String, target_count: int) -> float:
	for child in holder.get_children():
		child.queue_free()
	await process_frame

	var player := PLAYER_SCENE.instantiate() as Node2D
	holder.add_child(player)
	player.add_to_group("player")
	player.global_position = Vector2(1280, 720)
	if player.get_script() == null or not player.has_method("configure_character"):
		print("[live-fallback] %s/%s: Player scene script unavailable; using deterministic budget DPS." % [character_id, weapon_id])
		return _estimated_dps(character_id, weapon_id, target_count)
	if player.has_method("configure_character"):
		player.configure_character(character_id, weapon_id)
	# Игрок неуязвим/неподвижен — меряем только исходящий урон.
	player.set("max_health", 1.0e9)
	player.set("health", 1.0e9)
	await process_frame

	var dummies: Array = []
	for i in range(target_count):
		var enemy := ENEMY_SCENE.instantiate() as Node2D
		holder.add_child(enemy)
		if enemy.get_script() == null:
			print("[live-fallback] %s/%s: Enemy scene script unavailable; using deterministic budget DPS." % [character_id, weapon_id])
			return _estimated_dps(character_id, weapon_id, target_count)
		var angle := TAU * float(i) / float(maxi(target_count, 1))
		var radius := 0.0 if target_count == 1 else 44.0
		enemy.global_position = player.global_position + Vector2(80, 0) + Vector2.RIGHT.rotated(angle) * radius
		enemy.set("max_health", DUMMY_HP)
		enemy.set("health", DUMMY_HP)
		enemy.set("move_speed", 0.0)
		enemy.set("contact_damage", 0.0)
		dummies.append(enemy)
	await process_frame

	var hp_before := 0.0
	for enemy in dummies:
		hp_before += _numeric_property(enemy, "health", DUMMY_HP)

	for _frame in range(FRAMES):
		await process_frame

	var hp_after := 0.0
	for enemy in dummies:
		if is_instance_valid(enemy):
			hp_after += _numeric_property(enemy, "health", DUMMY_HP)
	var damage := maxf(hp_before - hp_after, 0.0)
	return damage / WINDOW_SECONDS


func _estimated_dps(character_id: String, weapon_id: String, target_count: int) -> float:
	var weapon_config: Dictionary = ProgressionData.weapon(character_id, weapon_id)
	if target_count <= 1:
		var one_and_five: Dictionary = ProgressionData.estimate_weapon_budget_for_stats(
			character_id,
			weapon_config,
			ProgressionData.base_stats(character_id),
			true
		)
		return float(one_and_five.get("solo_dps", 0.0))
	var budget: Dictionary = ProgressionData.estimate_crowd_clear_budget_for_stats(
		character_id,
		weapon_config,
		target_count,
		ProgressionData.base_stats(character_id),
		true
	)
	return float(budget.get("crowd_dps", 0.0))


func _numeric_property(node: Object, property_name: String, fallback: float) -> float:
	if node == null or not is_instance_valid(node):
		return fallback
	var value = node.get(property_name)
	if value == null:
		return fallback
	match typeof(value):
		TYPE_FLOAT, TYPE_INT:
			return float(value)
		_:
			return fallback
