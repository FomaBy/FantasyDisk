extends SceneTree

const PD := preload("res://scripts/progression_data.gd")
const EPS := 0.0001

func _init() -> void:
	var errors: Array[String] = []
	if absf(PD.ordinary_crit_chance_cap(0.0) - 0.55) > EPS or absf(PD.ordinary_crit_chance_cap(100.0) - 0.75) > EPS:
		errors.append("ordinary crit cap must span 55%..75%")
	var raw := PD.CRIT_DAMAGE_CAP + 4.0
	if absf(PD.effective_crit_damage_multiplier(0.0, (raw - PD.CRIT_DAMAGE_BASE_MULTIPLIER) / PD.CRIT_DAMAGE_FLAT_EFFECTIVENESS) - (PD.CRIT_DAMAGE_CAP + 2.0)) > EPS:
		errors.append("crit tail must be continuous sqrt(raw - 2.75)")
	var config: Dictionary = PD.weapon("berserk", "sword")
	var base := PD.derived_parameters(PD.base_stats("berserk"), {}, config)
	var fast := PD.derived_parameters(PD.base_stats("berserk"), {"attack_speed_multiplier": 1.5}, config)
	if float(fast.get("attack_cadence_multiplier", 0.0)) <= float(base.get("attack_cadence_multiplier", 0.0)) or float(fast.get("dot_speed", 0.0)) <= float(base.get("dot_speed", 0.0)):
		errors.append("attack speed must raise common periodic cadence")
	for reward in PD.LEVEL_UP_REWARDS:
		if (reward.get("mods", {}) as Dictionary).has("dot_speed_flat"):
			errors.append("selectable dot_speed_flat source remains: %s" % str(reward.get("id", "")))
	if errors.is_empty():
		print("Offensive scaling contract passed.")
		quit(0)
		return
	for error in errors:
		push_error(error)
	quit(1)
