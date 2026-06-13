extends SceneTree

## Live Combat Balance Harness (SCRUM-176).
##
## Дополняет ФОРМУЛЬНЫЙ tools/balance_harness.gd: инстанцирует реального Player +
## оружие + стационарных врагов-болванок и МЕРЯЕТ фактический урон за окно
## (solo и 5-target), затем оценивает practical TTK и сверяет с целью профиля
## класса. Ловит грубые рантайм-выбросы, которые формула может не заметить
## (мимо-промахи снарядов, геометрия AoE, сломанный режим оружия).
##
## Запуск: Godot --headless --path . --script res://tools/live_combat_harness.gd
## Вывод: build/live_combat_report.md
##
## Оговорки: измеряется СУСТЕЙН-DPS оружия БЕЗ ультимейта (ульта требует заряда/
## ввода) — у ульт-зависимых классов живой DPS читается ниже формульного на
## вклад ульты. Допуск сравнения широкий (±40%): цель — ловить поломки, а не
## точная сверка формулы.

const ProgressionData := preload("res://scripts/progression_data.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")

const WINDOW_SECONDS := 8.0
const FRAMES := 480              # 8с * 60fps
const DUMMY_HP := 1.0e9          # болванки не умирают — меряем чистый DPS
const TTK_REFERENCE_HP := 90.0   # типовой враг среднего этапа для practical TTK
const TOLERANCE := 0.40          # ±40%: ловим грубые выбросы
const REPORT_PATH := "res://build/live_combat_report.md"


func _initialize() -> void:
	await process_frame
	var holder := Node2D.new()
	holder.name = "LiveHarnessHolder"
	root.add_child(holder)
	current_scene = holder
	await process_frame

	var rows: Array = []
	for character_id in ProgressionData.character_ids():
		var cid := str(character_id)
		var profile: Dictionary = ProgressionData.class_budget_profile(cid)
		var solo_target := ProgressionData.BALANCE_BASE_SOLO_DPS * float(profile.get("solo_target", 1.0)) * float(profile.get("damage_budget", 1.0))
		var aoe_target := ProgressionData.BALANCE_BASE_AOE_DPS * float(profile.get("aoe_target", 1.0)) * float(profile.get("damage_budget", 1.0))
		for weapon_id in ProgressionData.weapon_ids(cid):
			var wid := str(weapon_id)
			var solo_dps: float = await _measure_dps(holder, cid, wid, 1)
			var aoe_dps: float = await _measure_dps(holder, cid, wid, 5)
			var ttk := TTK_REFERENCE_HP / maxf(solo_dps, 0.001)
			rows.append({
				"class": cid, "weapon": wid,
				"solo_dps": solo_dps, "solo_target": solo_target, "solo_ratio": solo_dps / maxf(solo_target, 0.001),
				"aoe_dps": aoe_dps, "aoe_target": aoe_target, "aoe_ratio": aoe_dps / maxf(aoe_target, 0.001),
				"ttk": ttk,
			})
			print("%s/%s: solo=%.1f (target %.1f) aoe=%.1f (target %.1f) ttk=%.1fs" % [cid, wid, solo_dps, solo_target, aoe_dps, aoe_target, ttk])

	_write_report(rows)
	holder.queue_free()
	await process_frame
	quit(0)


func _measure_dps(holder: Node2D, character_id: String, weapon_id: String, target_count: int) -> float:
	# Чистим арену.
	for child in holder.get_children():
		child.queue_free()
	await process_frame

	var player := PLAYER_SCENE.instantiate() as Node2D
	holder.add_child(player)
	player.add_to_group("player")
	player.global_position = Vector2(1280, 720)
	if player.has_method("configure_character"):
		player.configure_character(character_id, weapon_id)
	# Игрок неуязвим/неподвижен — меряем только его исходящий урон.
	player.set("max_health", 1.0e9)
	player.set("health", 1.0e9)
	await process_frame

	# Стационарные болванки рядом (в радиусе типового оружия), кластером для AoE.
	var dummies: Array = []
	for i in range(target_count):
		var enemy := ENEMY_SCENE.instantiate() as Node2D
		holder.add_child(enemy)
		var angle := TAU * float(i) / float(maxi(target_count, 1))
		var radius := 0.0 if target_count == 1 else 56.0
		enemy.global_position = player.global_position + Vector2(150, 0) + Vector2.RIGHT.rotated(angle) * radius
		enemy.set("max_health", DUMMY_HP)
		enemy.set("health", DUMMY_HP)
		enemy.set("move_speed", 0.0)       # стоят на месте
		enemy.set("contact_damage", 0.0)   # не бьют игрока
		dummies.append(enemy)
	await process_frame

	var hp_before := 0.0
	for enemy in dummies:
		hp_before += float(enemy.get("health"))

	for _frame in range(FRAMES):
		await process_frame

	var hp_after := 0.0
	for enemy in dummies:
		if is_instance_valid(enemy):
			hp_after += float(enemy.get("health"))
	var damage := maxf(hp_before - hp_after, 0.0)
	return damage / WINDOW_SECONDS


func _write_report(rows: Array) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var lines := PackedStringArray()
	lines.append("# FantasyDisk Live Combat Balance Report")
	lines.append("")
	lines.append("Сгенерировано `tools/live_combat_harness.gd` (SCRUM-176).")
	lines.append("")
	lines.append("Метод: реальный Player+оружие авто-атакует стационарных болванок %.0fс; измерен фактический исходящий урон." % WINDOW_SECONDS)
	lines.append("Цели — `CLASS_BUDGET_PROFILES` (база solo %.0f / 5-target %.0f DPS). Допуск ±%.0f%%." % [
		ProgressionData.BALANCE_BASE_SOLO_DPS, ProgressionData.BALANCE_BASE_AOE_DPS, TOLERANCE * 100.0])
	lines.append("Оговорка: измеряется сустейн БЕЗ ультимейта — ульт-зависимые классы читаются ниже формульной цели.")
	lines.append("")
	lines.append("| Класс | Оружие | Solo DPS | Цель | Δ | 5-target DPS | Цель | Δ | TTK(%.0fHP) | Флаг |" % TTK_REFERENCE_HP)
	lines.append("| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | :---: |")
	var outliers := 0
	for row in rows:
		var solo_off: float = row["solo_ratio"] - 1.0
		var aoe_off: float = row["aoe_ratio"] - 1.0
		var flag := "ok"
		if absf(solo_off) > TOLERANCE or absf(aoe_off) > TOLERANCE:
			flag = "⚠ выброс"
			outliers += 1
		lines.append("| %s | %s | %.1f | %.1f | %+.0f%% | %.1f | %.1f | %+.0f%% | %.1fс | %s |" % [
			row["class"], row["weapon"], row["solo_dps"], row["solo_target"], solo_off * 100.0,
			row["aoe_dps"], row["aoe_target"], aoe_off * 100.0, row["ttk"], flag])
	lines.append("")
	lines.append("Пар проверено: %d; выбросов вне ±%.0f%%: %d." % [rows.size(), TOLERANCE * 100.0, outliers])
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Не удалось записать отчёт: %s" % REPORT_PATH)
		return
	file.store_string("\n".join(lines))
	file.close()
	print("Live combat report: %s (пар %d, выбросов %d)" % [ProjectSettings.globalize_path(REPORT_PATH), rows.size(), outliers])
