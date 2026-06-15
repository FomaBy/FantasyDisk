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

# Целевой коридор комбинированного бюджет-отклонения (legacy gate SCRUM-249).
const CORRIDOR := 0.25


func _initialize() -> void:
	var rows: Array = []
	var errors: Array = []
	var worst_dev := 0.0
	var worst_pair := ""
	var worst_solo_dev := 0.0
	var worst_solo_pair := ""
	var worst_cct_dev := 0.0
	var worst_cct_pair := ""
	var worst_cct_count := 0
	var class_best_crowd := {}

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
			var solo_dev := solo_dps / solo_target - 1.0
			var crowd_metrics := {}
			var worst_pair_cct_abs := 0.0
			for count in PD.crowd_clear_counts():
				var crowd: Dictionary = PD.estimate_crowd_clear_budget(cid, tuned, int(count), true)
				crowd_metrics[int(count)] = crowd
				var cct_dev := float(crowd.get("cct_dev", 0.0))
				worst_pair_cct_abs = maxf(worst_pair_cct_abs, absf(cct_dev))
				if absf(cct_dev) > absf(worst_cct_dev):
					worst_cct_dev = cct_dev
					worst_cct_pair = "%s/%s" % [cid, wid]
					worst_cct_count = int(count)
				if absf(cct_dev) > PD.CROWD_CLEAR_CORRIDOR:
					errors.append("%s/%s: %d-target CCT отклонение %+.0f%% вне коридора ±%.0f%% (%.1fs/цель %.1fs)" % [
						cid,
						wid,
						int(count),
						cct_dev * 100.0,
						PD.CROWD_CLEAR_CORRIDOR * 100.0,
						float(crowd.get("cct", 0.0)),
						float(crowd.get("target_cct", 0.0)),
					])
			var viability_dev := maxf(absf(solo_dev), worst_pair_cct_abs)
			if not class_best_crowd.has(cid) or viability_dev < float(class_best_crowd[cid].get("dev", 999.0)):
				class_best_crowd[cid] = {"weapon": wid, "dev": viability_dev}
			rows.append({"pair": "%s/%s" % [cid, wid], "solo_dps": solo_dps, "aoe_dps": aoe_dps,
				"solo_target": solo_target, "aoe_target": aoe_target, "dev": dev,
				"solo_dev": solo_dev, "crowd": crowd_metrics})
			if absf(dev) > absf(worst_dev):
				worst_dev = dev
				worst_pair = "%s/%s" % [cid, wid]
			if absf(solo_dev) > absf(worst_solo_dev):
				worst_solo_dev = solo_dev
				worst_solo_pair = "%s/%s" % [cid, wid]
			if absf(dev) > CORRIDOR:
				errors.append("%s/%s: бюджет-отклонение %+.0f%% вне коридора ±%.0f%% (solo %.1f/цель %.1f, 5t %.1f/цель %.1f)" % [
					cid, wid, dev * 100.0, CORRIDOR * 100.0, solo_dps, solo_target, aoe_dps, aoe_target])
			if absf(solo_dev) > PD.CROWD_CLEAR_SOLO_CORRIDOR:
				errors.append("%s/%s: solo DPS %+.0f%% вне финального коридора ±%.0f%% (%.1f/цель %.1f)" % [
					cid,
					wid,
					solo_dev * 100.0,
					PD.CROWD_CLEAR_SOLO_CORRIDOR * 100.0,
					solo_dps,
					solo_target,
				])
			if solo_dps <= 0.01 and aoe_dps <= 0.01:
				errors.append("%s/%s: 0 урона по обеим осям" % [cid, wid])
	for cid in class_best_crowd.keys():
		var best: Dictionary = class_best_crowd[cid]
		if float(best.get("dev", 999.0)) > PD.CROWD_CLEAR_CORRIDOR:
			errors.append("%s: нет жизнеспособного crowd-clear оружия в коридоре ±%.0f%% (лучшее %s, худшее откл. %.0f%%)" % [
				cid,
				PD.CROWD_CLEAR_CORRIDOR * 100.0,
				str(best.get("weapon", "")),
				float(best.get("dev", 0.0)) * 100.0,
			])

	# Анти-вакуум.
	if rows.size() < 9:
		errors.append("пар класс×оружие подозрительно мало (%d)" % rows.size())

	_write_report(rows, worst_pair, worst_dev, worst_solo_pair, worst_solo_dev, worst_cct_pair, worst_cct_dev, worst_cct_count)

	if not errors.is_empty():
		for e in errors:
			push_error("Global damage balance: %s" % e)
		push_error("Global damage balance smoke: %d нарушений коридора (пар %d)." % [errors.size(), rows.size()])
		quit(1)
		return
	print("Global damage balance smoke passed (%d пар; combined ±%.0f%%, solo ±%.0f%%, CCT ±%.0f%%; худшее CCT %+.0f%% — %s/%d)." % [
		rows.size(),
		CORRIDOR * 100.0,
		PD.CROWD_CLEAR_SOLO_CORRIDOR * 100.0,
		PD.CROWD_CLEAR_CORRIDOR * 100.0,
		worst_cct_dev * 100.0,
		worst_cct_pair,
		worst_cct_count,
	])
	quit(0)


func _write_report(rows: Array, worst_pair: String, worst_dev: float, worst_solo_pair: String, worst_solo_dev: float, worst_cct_pair: String, worst_cct_dev: float, worst_cct_count: int) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var lines := PackedStringArray()
	lines.append("# Глобальный DAMAGE balance smoke (SCRUM-249)")
	lines.append("")
	lines.append("Гейт патча 0.1.5: комбинированное бюджет-отклонение по парам класс×оружие в коридоре ±%.0f%%; финальный solo corridor ±%.0f%%; crowd-clear 5/10/20 CCT corridor ±%.0f%%." % [
		CORRIDOR * 100.0,
		PD.CROWD_CLEAR_SOLO_CORRIDOR * 100.0,
		PD.CROWD_CLEAR_CORRIDOR * 100.0,
	])
	lines.append("Худшее combined: %+.0f%% (`%s`). Худшее solo: %+.0f%% (`%s`). Худшее CCT: %+.0f%% (`%s`, %d targets). Пар: %d." % [
		worst_dev * 100.0,
		worst_pair,
		worst_solo_dev * 100.0,
		worst_solo_pair,
		worst_cct_dev * 100.0,
		worst_cct_pair,
		worst_cct_count,
		rows.size(),
	])
	lines.append("")
	lines.append("| Класс/Оружие | Solo DPS | Цель | Solo откл. | 5t DPS | Цель | Бюджет-откл. | CCT 5 | CCT 10 | CCT 20 |")
	lines.append("| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |")
	for r in rows:
		var c5: Dictionary = r["crowd"].get(5, {})
		var c10: Dictionary = r["crowd"].get(10, {})
		var c20: Dictionary = r["crowd"].get(20, {})
		lines.append("| %s | %.1f | %.1f | %+.0f%% | %.1f | %.1f | %+.0f%% | %.1fs (%+.0f%%) | %.1fs (%+.0f%%) | %.1fs (%+.0f%%) |" % [
			r["pair"],
			r["solo_dps"],
			r["solo_target"],
			float(r["solo_dev"]) * 100.0,
			r["aoe_dps"],
			r["aoe_target"],
			float(r["dev"]) * 100.0,
			float(c5.get("cct", 0.0)),
			float(c5.get("cct_dev", 0.0)) * 100.0,
			float(c10.get("cct", 0.0)),
			float(c10.get("cct_dev", 0.0)) * 100.0,
			float(c20.get("cct", 0.0)),
			float(c20.get("cct_dev", 0.0)) * 100.0,
		])
	var f := FileAccess.open("res://build/global_damage_balance_report.md", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lines))
		f.close()
