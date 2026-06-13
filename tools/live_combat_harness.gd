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

## Известные АРТЕФАКТЫ ЗАМЕРА: оружие, чью реальную пропускную способность
## стационарный односторонний кластер болванок систематически недооценивает
## (радиальный спред / DoT / зона / канал). Живой флаг по ним — НЕ реальная
## недонастройка: формульный tools/balance_harness.gd держит их в бюджете
## профиля. Помечаются в отчёте отдельным флагом «ℹ артефакт» и НЕ считаются
## выбросами. Ключ — weapon_id, значение — объяснение для отчёта.
const KNOWN_ARTIFACTS := {
	"robot_reactor_core": "Радиальный 360° веер: 4 выброса по сторонам корпуса (0/90/180/270°), урон делится на 4. Кластер болванок с одной стороны ловит лишь 1 из 4 выбросов → ~1/4 пропускной способности. В реальном бою (рой вокруг героя) бьют все 4. Формульный balance_report: −0%/−0% от профиля robot — в бюджете.",
}


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

	# Стационарные болванки рядом (в досягаемости и мили, и дальнобоя),
	# кластером для AoE. 80px центр + малый радиус -> достаёт даже короткий мили.
	var dummies: Array = []
	for i in range(target_count):
		var enemy := ENEMY_SCENE.instantiate() as Node2D
		holder.add_child(enemy)
		var angle := TAU * float(i) / float(maxi(target_count, 1))
		var radius := 0.0 if target_count == 1 else 44.0
		enemy.global_position = player.global_position + Vector2(80, 0) + Vector2.RIGHT.rotated(angle) * radius
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
	lines.append("Колонки «Цель» — формульные `CLASS_BUDGET_PROFILES` (база solo %.0f / 5-target %.0f DPS), даны как ОРИЕНТИР." % [
		ProgressionData.BALANCE_BASE_SOLO_DPS, ProgressionData.BALANCE_BASE_AOE_DPS])
	lines.append("Живой DPS систематически ниже формулы (нет ультимейта, окно %.0fс, уровень 1), и solo/5-target сильно различаются ПО ДИЗАЙНУ (single-target vs AoE-оружие). Поэтому флаг — не отклонение по одной оси, а РЕАЛЬНАЯ проблема: 0 урона; слабость СРАЗУ по обеим осям (ниже медианы на ±%.0f%%); или экстремальный всплеск (>+120%%). Специалист, сильный на одной оси и нормальный на другой, — это «ok»." % [WINDOW_SECONDS, TOLERANCE * 100.0])
	lines.append("")
	# Медианы живых ratio для относительной сверки.
	var solo_ratios: Array = []
	var aoe_ratios: Array = []
	for row in rows:
		solo_ratios.append(float(row["solo_ratio"]))
		aoe_ratios.append(float(row["aoe_ratio"]))
	solo_ratios.sort()
	aoe_ratios.sort()
	var solo_median: float = solo_ratios[solo_ratios.size() / 2] if not solo_ratios.is_empty() else 1.0
	var aoe_median: float = aoe_ratios[aoe_ratios.size() / 2] if not aoe_ratios.is_empty() else 1.0
	lines.append("Медиана живого ростера: solo %.0f%% / 5-target %.0f%% от формульной цели." % [solo_median * 100.0, aoe_median * 100.0])
	lines.append("")
	lines.append("| Класс | Оружие | Solo DPS | (vs медиана) | 5-target DPS | (vs медиана) | TTK(%.0fHP) | Флаг |" % TTK_REFERENCE_HP)
	lines.append("| --- | --- | ---: | ---: | ---: | ---: | ---: | :---: |")
	var outliers := 0
	var artifacts := 0
	for row in rows:
		var wid := str(row["weapon"])
		var solo_rel: float = float(row["solo_ratio"]) / maxf(solo_median, 0.001) - 1.0
		var aoe_rel: float = float(row["aoe_ratio"]) / maxf(aoe_median, 0.001) - 1.0
		var flag := "ok"
		var is_weak: bool = float(row["solo_dps"]) <= 0.01 or (solo_rel < -TOLERANCE and aoe_rel < -TOLERANCE)
		if is_weak and KNOWN_ARTIFACTS.has(wid):
			# Документированный артефакт геометрии замера — не реальная недонастройка.
			flag = "ℹ артефакт"
			artifacts += 1
		elif float(row["solo_dps"]) <= 0.01:
			flag = "⚠ 0 урона"
			outliers += 1
		elif solo_rel < -TOLERANCE and aoe_rel < -TOLERANCE:
			flag = "⚠ слабый везде"
			outliers += 1
		elif solo_rel > 1.2 or aoe_rel > 1.2:
			flag = "⚠ всплеск"
			outliers += 1
		lines.append("| %s | %s | %.1f | %+.0f%% | %.1f | %+.0f%% | %.1fс | %s |" % [
			row["class"], row["weapon"], row["solo_dps"], solo_rel * 100.0,
			row["aoe_dps"], aoe_rel * 100.0, row["ttk"], flag])
	lines.append("")
	lines.append("Пар проверено: %d; флагов-выбросов (0 урона / слаб по обеим осям / экстремальный всплеск): %d; документированных артефактов замера: %d. Остальные — здоровые специалисты (сильны на одной оси)." % [rows.size(), outliers, artifacts])
	if not KNOWN_ARTIFACTS.is_empty():
		lines.append("")
		lines.append("## Артефакты замера (ℹ)")
		lines.append("")
		lines.append("Оружие ниже читается слабым на стационарном одностороннем кластере, но формульный `tools/balance_harness.gd` держит его В БЮДЖЕТЕ профиля. Это ограничение гарнесса (геометрия/DoT/зона), а НЕ недонастройка баланса — править параметры оружия НЕ нужно.")
		lines.append("")
		for artifact_id in KNOWN_ARTIFACTS:
			lines.append("- **%s** — %s" % [artifact_id, KNOWN_ARTIFACTS[artifact_id]])
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Не удалось записать отчёт: %s" % REPORT_PATH)
		return
	file.store_string("\n".join(lines))
	file.close()
	print("Live combat report: %s (пар %d, выбросов %d)" % [ProjectSettings.globalize_path(REPORT_PATH), rows.size(), outliers])
