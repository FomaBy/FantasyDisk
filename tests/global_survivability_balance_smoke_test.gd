extends SceneTree

# SCRUM-249 (опора патча 0.1.5): глобальный SURVIVABILITY balance smoke.
# Использует детерминированную модель tools/survivability_harness.gd (4 профиля
# fragile/steady/sturdy/tank × 4 сценария) и гейтит коридоры TTD/митигации +
# ГЛАВНОЕ для патча: БЕССМЕРТИЕ НЕДОСТИЖИМО (проверяемо числами) — входящий
# митигированный урон превышает реген (чистая потеря HP), TTD ограничен, нет
# полного иммунитета. Против этого гейта проверяется баланс регена/вампиризма/
# абсорба/уворота. Отдельный изолированный файл. Отчёт:
# build/global_survivability_balance_report.md.
#
# Запуск: Godot --headless --path . --script res://tests/global_survivability_balance_smoke_test.gd

const Surv := preload("res://tools/survivability_harness.gd")

const MAX_TTD := 600.0        # потолок: выше = эффективное бессмертие
const MAX_MITIG := 0.98       # < 100%: полный иммунитет недопустим
const NET_DAMAGE_FLOOR := 0.05 # входящее минус реген должно превышать пол (не зафлорено)
const ORDER := ["fragile", "steady", "sturdy", "tank"]


func _initialize() -> void:
	var rows := Surv.build_model()
	var errors: Array = []
	var by_key := {}

	for row in rows:
		var key := "%s/%s" % [row["profile"], row["scenario"]]
		by_key[key] = row
		var ttd := float(row["ttd"])
		var mitigated := float(row["mitigated_dps"])
		var regen := float(row["regen"])
		var effective := float(row["effective_dps"])
		var mitig_share := 1.0 - mitigated / maxf(float(row["raw_dps"]), 0.001)

		# Конечность/потолок TTD.
		if not is_finite(ttd) or ttd <= 0.0:
			errors.append("%s: TTD неконечен/<=0 (%s)" % [key, ttd])
		elif ttd > MAX_TTD:
			errors.append("%s: TTD %.0fс > потолка %.0fс — эффективное бессмертие" % [key, ttd, MAX_TTD])
		# Нет полного иммунитета.
		if mitig_share > MAX_MITIG:
			errors.append("%s: митигация %.0f%% > %.0f%% — почти полный иммунитет" % [key, mitig_share * 100.0, MAX_MITIG * 100.0])
		# БЕССМЕРТИЕ НЕДОСТИЖИМО: входящий митигированный урон > реген (+пол).
		if (mitigated - regen) <= NET_DAMAGE_FLOOR:
			errors.append("%s: митигированный входящий %.2f не превышает реген %.2f (+пол %.2f) — чистого урона нет, бессмертие" % [
				key, mitigated, regen, NET_DAMAGE_FLOOR])
		if effective <= 0.0:
			errors.append("%s: effective_dps <= 0" % key)

	# Монотонность TTD по стойкости в каждом сценарии (баланс не должен ломать порядок).
	for scenario in Surv.SCENARIOS:
		var sid := str(scenario["id"])
		for i in range(ORDER.size() - 1):
			var lo: float = float(by_key["%s/%s" % [ORDER[i], sid]]["ttd"])
			var hi: float = float(by_key["%s/%s" % [ORDER[i + 1], sid]]["ttd"])
			if not (hi > lo):
				errors.append("%s: TTD не растёт по стойкости %s(%.1f)->%s(%.1f)" % [sid, ORDER[i], lo, ORDER[i + 1], hi])

	if rows.size() != Surv.PROFILES.size() * Surv.SCENARIOS.size():
		errors.append("строк модели %d != ожидаемых %d (вакуум)" % [rows.size(), Surv.PROFILES.size() * Surv.SCENARIOS.size()])

	_write_report(rows)

	if not errors.is_empty():
		for e in errors:
			push_error("Global survivability balance: %s" % e)
		push_error("Global survivability balance smoke: %d нарушений (строк %d)." % [errors.size(), rows.size()])
		quit(1)
		return
	print("Global survivability balance smoke passed (%d строк: TTD<=%.0fс, митигация<%.0f%%, бессмертие недостижимо)." % [
		rows.size(), MAX_TTD, MAX_MITIG * 100.0])
	quit(0)


func _write_report(rows: Array) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var lines := PackedStringArray()
	lines.append("# Глобальный SURVIVABILITY balance smoke (SCRUM-249)")
	lines.append("")
	lines.append("Гейт патча 0.1.5: TTD<=%.0fс, митигация<%.0f%%, и БЕССМЕРТИЕ НЕДОСТИЖИМО (входящий митигированный урон > реген)." % [MAX_TTD, MAX_MITIG * 100.0])
	lines.append("")
	lines.append("| Профиль/Сценарий | TTD | raw dps | mitig dps | effective | reg | net(mitig-reg) |")
	lines.append("| --- | ---: | ---: | ---: | ---: | ---: | ---: |")
	for row in rows:
		lines.append("| %s/%s | %.1fс | %.1f | %.1f | %.1f | %.1f | %.2f |" % [
			row["profile"], row["scenario"], float(row["ttd"]), float(row["raw_dps"]),
			float(row["mitigated_dps"]), float(row["effective_dps"]), float(row["regen"]),
			float(row["mitigated_dps"]) - float(row["regen"])])
	var f := FileAccess.open("res://build/global_survivability_balance_report.md", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lines))
		f.close()
