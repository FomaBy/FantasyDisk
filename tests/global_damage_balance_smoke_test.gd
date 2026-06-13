extends SceneTree

# SCRUM-249 (опора патча 0.1.5): глобальный DAMAGE balance smoke. Прогон
# формульного бюджета по ВСЕМ парам класс×оружие (solo + 5-target DPS) и ассерт,
# что комбинированное отклонение от бюджет-цели класса (эталон — Берсерк-меч =
# 1.0 бюджета) лежит в коридоре. Выброс = красный тест с указанием пары.
# Это автоматический гейт, против которого проверяется КАЖДАЯ балансовая задача
# патча. Отдельный изолированный файл (только ЧИТАЕТ ProgressionData).
# Отчёт: build/global_damage_balance_report.md.
#
# Запуск: Godot --headless --path . --script res://tests/global_damage_balance_smoke_test.gd

const PD := preload("res://scripts/progression_data.gd")

# Целевой коридор комбинированного бюджет-отклонения (после авто-тюнинга
# budget_damage_multiplier пары держатся у цели; ±25% ловит реальные выбросы,
# не триггеря на мелкий шум модели).
const CORRIDOR := 0.25


func _initialize() -> void:
	var rows: Array = []
	var errors: Array = []
	var worst_dev := 0.0
	var worst_pair := ""

	for character_id in PD.character_ids():
		var cid := str(character_id)
		for weapon_id in PD.weapon_ids(cid):
			var wid := str(weapon_id)
			var tuned: Dictionary = PD.weapon(cid, wid)
			var after: Dictionary = PD.estimate_weapon_budget(cid, tuned, true)
			var tuning: Dictionary = tuned.get("budget_tuning", {})
			var solo_target := float(tuning.get("solo_target", PD.BALANCE_BASE_SOLO_DPS))
			var aoe_target := float(tuning.get("aoe_target", PD.BALANCE_BASE_AOE_DPS))
			if solo_target <= 0.001 or aoe_target <= 0.001:
				errors.append("%s/%s: нулевой бюджет-таргет" % [cid, wid])
				continue
			var solo_dps := float(after.get("solo_dps", 0.0))
			var aoe_dps := float(after.get("aoe_dps", 0.0))
			var combined := (solo_dps / solo_target + aoe_dps / aoe_target) * 0.5
			var dev := combined - 1.0
			rows.append({"pair": "%s/%s" % [cid, wid], "solo_dps": solo_dps, "aoe_dps": aoe_dps,
				"solo_target": solo_target, "aoe_target": aoe_target, "dev": dev})
			if absf(dev) > absf(worst_dev):
				worst_dev = dev
				worst_pair = "%s/%s" % [cid, wid]
			if absf(dev) > CORRIDOR:
				errors.append("%s/%s: бюджет-отклонение %+.0f%% вне коридора ±%.0f%% (solo %.1f/цель %.1f, 5t %.1f/цель %.1f)" % [
					cid, wid, dev * 100.0, CORRIDOR * 100.0, solo_dps, solo_target, aoe_dps, aoe_target])
			if solo_dps <= 0.01 and aoe_dps <= 0.01:
				errors.append("%s/%s: 0 урона по обеим осям" % [cid, wid])

	# Анти-вакуум.
	if rows.size() < 9:
		errors.append("пар класс×оружие подозрительно мало (%d)" % rows.size())

	_write_report(rows, worst_pair, worst_dev)

	if not errors.is_empty():
		for e in errors:
			push_error("Global damage balance: %s" % e)
		push_error("Global damage balance smoke: %d нарушений коридора (пар %d)." % [errors.size(), rows.size()])
		quit(1)
		return
	print("Global damage balance smoke passed (%d пар в коридоре ±%.0f%%, худшее %+.0f%% — %s)." % [
		rows.size(), CORRIDOR * 100.0, worst_dev * 100.0, worst_pair])
	quit(0)


func _write_report(rows: Array, worst_pair: String, worst_dev: float) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var lines := PackedStringArray()
	lines.append("# Глобальный DAMAGE balance smoke (SCRUM-249)")
	lines.append("")
	lines.append("Гейт патча 0.1.5: комбинированное бюджет-отклонение по парам класс×оружие в коридоре ±%.0f%%." % (CORRIDOR * 100.0))
	lines.append("Худшее отклонение: %+.0f%% (`%s`). Пар: %d." % [worst_dev * 100.0, worst_pair, rows.size()])
	lines.append("")
	lines.append("| Класс/Оружие | Solo DPS | Цель | 5t DPS | Цель | Бюджет-откл. |")
	lines.append("| --- | ---: | ---: | ---: | ---: | ---: |")
	for r in rows:
		lines.append("| %s | %.1f | %.1f | %.1f | %.1f | %+.0f%% |" % [
			r["pair"], r["solo_dps"], r["solo_target"], r["aoe_dps"], r["aoe_target"], float(r["dev"]) * 100.0])
	var f := FileAccess.open("res://build/global_damage_balance_report.md", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lines))
		f.close()
