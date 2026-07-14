extends SceneTree

# FAN-1032 (Stage 4): дамп аналитических crowd_dps по всем парам × срезам 1/5/20
# для перекалибровки comfort-весов (см. tools/recalibrate_comfort_weights.py).
# Зеркалит измерение tests/comfort_band_cross_class_gate.gd (base_stats, budget on).

const PD := preload("res://scripts/progression_data.gd")

func _init() -> void:
	var data := {}
	for cid in PD.character_ids():
		var per_class := {}
		for wid in PD.weapon_ids(cid):
			var cfg: Dictionary = PD.weapon(str(cid), str(wid))
			var slices := {}
			for tc in [1, 5, 20]:
				var b: Dictionary = PD.estimate_crowd_clear_budget_for_stats(str(cid), cfg, tc, PD.base_stats(str(cid)), true)
				slices[str(tc)] = float(b.get("crowd_dps", 0.0))
			per_class[str(wid)] = slices
		data[str(cid)] = per_class
	var f := FileAccess.open("res://build/comfort_raw_dump.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	print("Comfort raw dump written: build/comfort_raw_dump.json")
	quit(0)
