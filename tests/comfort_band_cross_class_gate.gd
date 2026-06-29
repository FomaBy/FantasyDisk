extends SceneTree

# SCRUM-601: формульный гейт кросс-классовой DPS-полосы по comfort-норме.
#
# Comfort-band модель (SCRUM-544) задумана свести comfort_normalized_dps ВСЕХ
# классов в ±COMFORT_BAND_TOLERANCE от медианы среза, но раньше это никто не
# ассертил: budget выравнивает DPS только ВНУТРИ класса (solo/aoe_target), а
# кросс-класс мог вылетать за полосу. Этот гейт замеряет полосу детерминированно
# (без live-CSV-арбитра): для каждого class+weapon на base_stats берёт
# аналитический crowd_dps (estimate_crowd_clear_budget_for_stats) на срезах
# 1/5/20 целей, нормирует через comfort_weight, считает медиану среза и
# ассертит каждое нормированное значение в [median*(1-tol), median*(1+tol)].
#
# Аутлаеры чинятся ТОЛЬКО через COMFORT_WEIGHTS/COMFORT_WEIGHT_OVERRIDES в
# progression_data_balance.gd (solo/aoe_target НЕ трогаем — они держат
# внутриклассовый budget). comfort_weight влияет лишь на band-измерение.
#
# Запуск: Godot --headless --path . --script res://tests/comfort_band_cross_class_gate.gd

const PD := preload("res://scripts/progression_data.gd")
const PDB := preload("res://scripts/progression_data_balance.gd")

const SLICES := [1, 5, 20]


func _median(values: Array) -> float:
	var v := values.duplicate()
	v.sort()
	var n := v.size()
	if n == 0:
		return 0.0
	if n % 2 == 1:
		return float(v[n / 2])
	return (float(v[n / 2 - 1]) + float(v[n / 2])) * 0.5


func _crowd_dps(cid: String, wid: String, target_count: int) -> float:
	var cfg: Dictionary = PD.weapon(cid, wid)
	var b: Dictionary = PD.estimate_crowd_clear_budget_for_stats(cid, cfg, target_count, PD.base_stats(cid), true)
	return float(b.get("crowd_dps", 0.0))


func _initialize() -> void:
	var errors: Array = []
	var tol: float = float(PDB.COMFORT_BAND_TOLERANCE)

	# Анти-вакуум: должно быть достаточно классов/оружий для осмысленной медианы.
	var class_ids: Array = PD.character_ids()
	if class_ids.size() < 10:
		errors.append("слишком мало классов (%d) — медиана среза невалидна" % class_ids.size())

	var total_entries := 0
	for tc in SLICES:
		var entries: Array = []   # {key, raw, norm}
		for cid in class_ids:
			for wid in PD.weapon_ids(cid):
				var raw := _crowd_dps(str(cid), str(wid), tc)
				if not is_finite(raw) or raw <= 0.0:
					errors.append("%s/%s [%dt]: crowd_dps неконечен/неположителен (%s)" % [cid, wid, tc, raw])
					continue
				var norm: float = PD.comfort_normalized_dps(str(cid), str(wid), raw)
				entries.append({"key": "%s/%s" % [cid, wid], "raw": raw, "norm": norm})
		if entries.is_empty():
			errors.append("срез %dt: нет валидных оружий" % tc)
			continue
		total_entries += entries.size()
		var norms: Array = []
		for e in entries:
			norms.append(float(e["norm"]))
		var median: float = _median(norms)
		var lo: float = median * (1.0 - tol)
		var hi: float = median * (1.0 + tol)
		# Разброс среза.
		var nmin: float = float(norms.min())
		var nmax: float = float(norms.max())
		var violations: Array = []
		for e in entries:
			var v := float(e["norm"])
			if v < lo or v > hi:
				violations.append("%s norm=%.1f (×%.2f медианы)" % [e["key"], v, v / maxf(median, 0.001)])
		print("[BAND %dt] n=%d median=%.1f band=[%.1f..%.1f] min=%.1f max=%.1f spread=%.2fx нарушений=%d" % [
			tc, entries.size(), median, lo, hi, nmin, nmax, nmax / maxf(nmin, 0.001), violations.size()])
		for v in violations:
			errors.append("срез %dt вне ±%.0f%%: %s" % [tc, tol * 100.0, v])

	# Анти-вакуум по объёму.
	if total_entries < SLICES.size() * 30:
		errors.append("подозрительно мало замеров (%d) — гейт вакуумен" % total_entries)

	if not errors.is_empty():
		for e in errors:
			push_error("Comfort band cross-class gate: %s" % e)
		push_error("Comfort band cross-class gate: %d нарушений полосы." % errors.size())
		quit(1)
		return
	print("Comfort band cross-class gate passed (все классы/оружия в ±%.0f%% медианы на срезах 1/5/20, %d замеров)." % [tol * 100.0, total_entries])
	quit(0)
