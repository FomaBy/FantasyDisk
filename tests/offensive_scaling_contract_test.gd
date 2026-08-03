extends SceneTree

const PD := preload("res://scripts/progression_data.gd")
const META_TREE := preload("res://scripts/meta_progression_tree_data.gd")
const EPS := 0.0001

func _init() -> void:
	var errors: Array[String] = []
	var cap_anchors := {0.0: 0.55, 20.0: 0.59, 50.0: 0.65, 99.0: 0.748, 100.0: 0.75}
	var previous_cap := -1.0
	for agility in cap_anchors:
		var cap := PD.ordinary_crit_chance_cap(float(agility))
		if absf(cap - float(cap_anchors[agility])) > EPS:
			errors.append("ordinary crit cap at Agility %.0f: %.3f != %.3f" % [agility, cap, cap_anchors[agility]])
		if cap + EPS < previous_cap:
			errors.append("ordinary crit cap must be monotonic")
		previous_cap = cap
	if PD.ordinary_crit_chance_cap(99.0) >= 0.75 or absf(PD.ordinary_crit_chance_cap(100.0) - 0.75) > EPS:
		errors.append("ordinary crit cap must first reach 75% at Agility 100")
	var raw := PD.CRIT_DAMAGE_CAP + 4.0
	if absf(PD.effective_crit_damage_multiplier(0.0, (raw - PD.CRIT_DAMAGE_BASE_MULTIPLIER) / PD.CRIT_DAMAGE_FLAT_EFFECTIVENESS) - (PD.CRIT_DAMAGE_CAP + 2.0)) > EPS:
		errors.append("crit tail must be continuous sqrt(raw - 2.75)")
	var config: Dictionary = PD.weapon("berserk", "sword")
	var base := PD.derived_parameters(PD.base_stats("berserk"), {}, config)
	var fast := PD.derived_parameters(PD.base_stats("berserk"), {"attack_speed_multiplier": 1.5}, config)
	if float(fast.get("attack_cadence_multiplier", 0.0)) <= float(base.get("attack_cadence_multiplier", 0.0)) or float(fast.get("dot_speed", 0.0)) <= float(base.get("dot_speed", 0.0)):
		errors.append("attack speed must raise common periodic cadence")
	var selectable_registries := {
		"LEVEL_UP_REWARDS": PD.LEVEL_UP_REWARDS,
		"STAT_REWARDS": PD.STAT_REWARDS,
		"ARTIFACTS": PD.ARTIFACTS,
		"SHOP_ITEMS": PD.SHOP_ITEMS,
		"START_BOONS": PD.START_BOONS,
		"WEAPONS_BY_CLASS": PD.WEAPONS_BY_CLASS,
		"META_STAR_ATTRS": META_TREE.STAR_ATTRS,
		"META_CONSTELLATION_SPECS": META_TREE.CONSTELLATION_SPECS,
		"META_ATLAS_NODES": META_TREE.ATLAS_NODES,
	}
	for registry_name in selectable_registries:
		var serialized := JSON.stringify(selectable_registries[registry_name])
		for forbidden in ["dot_speed_flat", "plague_metronome"]:
			if serialized.contains('"%s"' % forbidden):
				errors.append("selectable %s source remains in %s" % [forbidden, registry_name])
	if errors.is_empty():
		print("Offensive scaling contract passed.")
		quit(0)
		return
	for error in errors:
		push_error(error)
	quit(1)
