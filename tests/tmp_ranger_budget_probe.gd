extends SceneTree

# Временная проба бюджета кита Рейнджера (SCRUM-909..913) — не коммитить.

const PD := preload("res://scripts/progression_data.gd")


func _initialize() -> void:
	for weapon_id in ["moon_crossbow", "storm_longbow", "hunter_trap"]:
		var raw: Dictionary = (PD.WEAPONS_BY_CLASS["ranger"] as Dictionary)[weapon_id]
		var tuning := PD.budget_tuning_for("ranger", raw)
		var tuned: Dictionary = PD.weapon("ranger", weapon_id)
		var metrics := PD.estimate_weapon_budget("ranger", tuned, true)
		print("%s tuning=%s" % [weapon_id, str(tuning)])
		print("%s tuned_metrics=%s" % [weapon_id, str(metrics)])
	quit(0)
