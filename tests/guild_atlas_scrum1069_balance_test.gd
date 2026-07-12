extends SceneTree

const Meta := preload("res://scripts/meta_progression.gd")
const TreeData := preload("res://scripts/meta_progression_tree_data.gd")
const ProgressionData := preload("res://scripts/progression_data.gd")

const BRANCHES := {
	"treasury": ["atlas_m0", "atlas_m1", "atlas_m2", "atlas_m3", "atlas_n0", "atlas_k0"],
	"shop": ["atlas_m4", "atlas_m5", "atlas_m6", "atlas_m7", "atlas_n1", "atlas_k1"],
	"knowledge": ["atlas_m8", "atlas_m9", "atlas_m10", "atlas_n2", "atlas_k2"],
	"road": ["atlas_m11", "atlas_m12", "atlas_m13", "atlas_n3", "atlas_k3"],
}

# Frozen SCRUM-1068 identity/graph contract. SCRUM-1069 may tune outcomes only.
const EXPECTED_TOPOLOGY := {
	"atlas_hub": [0, ["atlas_m0", "atlas_m2", "atlas_m4", "atlas_m6", "atlas_m8", "atlas_m10", "atlas_m11", "atlas_m13"]],
	"atlas_m0": [1, ["atlas_hub", "atlas_m1"]],
	"atlas_m1": [2, ["atlas_m0", "atlas_n0"]],
	"atlas_m2": [2, ["atlas_hub", "atlas_m3"]],
	"atlas_m3": [2, ["atlas_m2", "atlas_n0"]],
	"atlas_n0": [3, ["atlas_m1", "atlas_m3", "atlas_k0"]],
	"atlas_k0": [5, ["atlas_n0"]],
	"atlas_m4": [2, ["atlas_hub", "atlas_m5"]],
	"atlas_m5": [2, ["atlas_m4", "atlas_n1"]],
	"atlas_m6": [2, ["atlas_hub", "atlas_m7"]],
	"atlas_m7": [2, ["atlas_m6", "atlas_n1"]],
	"atlas_n1": [3, ["atlas_m5", "atlas_m7", "atlas_k1"]],
	"atlas_k1": [5, ["atlas_n1"]],
	"atlas_m8": [2, ["atlas_hub", "atlas_m9"]],
	"atlas_m9": [2, ["atlas_m8", "atlas_n2", "atlas_h0"]],
	"atlas_m10": [2, ["atlas_hub", "atlas_n2"]],
	"atlas_n2": [3, ["atlas_m9", "atlas_m10", "atlas_k2"]],
	"atlas_k2": [5, ["atlas_n2"]],
	"atlas_h0": [0, ["atlas_m9"]],
	"atlas_m11": [2, ["atlas_hub", "atlas_m12"]],
	"atlas_m12": [2, ["atlas_m11", "atlas_n3", "atlas_h1"]],
	"atlas_m13": [2, ["atlas_hub", "atlas_n3"]],
	"atlas_n3": [3, ["atlas_m12", "atlas_m13", "atlas_k3"]],
	"atlas_k3": [5, ["atlas_n3"]],
	"atlas_h1": [0, ["atlas_m12"]],
}

var _errors := PackedStringArray()


func _initialize() -> void:
	_check_identity_cost_and_descriptions()
	_check_role_floors()
	_check_branch_targets_and_value()
	_check_exact_50_build_competitiveness()
	_check_hidden_positive_negative()
	_check_power_economy_and_a5_caps()
	if not _errors.is_empty():
		for error in _errors:
			push_error(error)
		quit(1)
		return
	print("SCRUM-1069 Guild Atlas 24-node floors, branch budgets, hidden gates, power/economy caps and A5 pressure passed.")
	quit(0)


func _state_for(ids: Array) -> Dictionary:
	var state := Meta.default_state()
	state["skill_nodes"] = ids.duplicate()
	return state


func _mods_for(ids: Array) -> Dictionary:
	return Meta.skill_modifiers(_state_for(ids))


func _check_identity_cost_and_descriptions() -> void:
	var atlas := Meta.atlas_nodes()
	if atlas.size() != 25:
		_errors.append("Guild Atlas must preserve exactly 25 IDs, got %d." % atlas.size())
	if Meta.atlas_total_cost() != 59 or Meta.STARDUST_CAP != 50:
		_errors.append("Guild scarcity changed: cost=%d cap=%d, expected 59>50." % [Meta.atlas_total_cost(), Meta.STARDUST_CAP])
	var non_core := 0
	var seen := {}
	for raw_node in atlas:
		var node := raw_node as Dictionary
		var node_id := str(node.get("id", ""))
		seen[node_id] = true
		if not EXPECTED_TOPOLOGY.has(node_id):
			_errors.append("Unexpected Guild node ID %s." % node_id)
		else:
			var expected := EXPECTED_TOPOLOGY[node_id] as Array
			var actual_edges := (node.get("adj", []) as Array).duplicate()
			var expected_edges := (expected[1] as Array).duplicate()
			actual_edges.sort()
			expected_edges.sort()
			if int(node.get("cost", -1)) != int(expected[0]) or actual_edges != expected_edges:
				_errors.append("%s cost/edges changed: expected %s, got [%s, %s]." % [node_id, expected, node.get("cost", -1), node.get("adj", [])])
		if str(node.get("role", "")) == "core":
			continue
		non_core += 1
		var effects := node.get("effects", {}) as Dictionary
		if effects.is_empty():
			_errors.append("%s has no measurable runtime effect." % str(node.get("id", "")))
			continue
		var numeric := TreeData.effects_desc(effects)
		if numeric.is_empty() or not str(node.get("desc", "")).contains(numeric):
			_errors.append("%s player description does not expose exact runtime values: %s." % [node.get("id", ""), node.get("desc", "")])
	if non_core != 24:
		_errors.append("Expected 24 non-core Guild nodes, got %d." % non_core)
	for node_id in EXPECTED_TOPOLOGY:
		if not seen.has(node_id):
			_errors.append("Frozen Guild node ID %s disappeared." % node_id)


func _check_role_floors() -> void:
	for index in range(14):
		var node_id := "atlas_m%d" % index
		var effects := Meta.node_by_id(node_id).get("effects", {}) as Dictionary
		for key in effects:
			var value := absf(float(effects[key]))
			match str(key):
				"money_gain_mult", "xp_gain_mult", "shop_price_mult", "attr_cost_mult":
					if value < 0.05:
						_errors.append("%s %s %.3f is below 5%% minor floor." % [node_id, key, value])
				"start_gold_flat":
					if value < 25.0:
						_errors.append("%s start gold %.1f is below 25." % [node_id, value])
				"pickup_radius_flat":
					if value < 30.0:
						_errors.append("%s pickup %.1f is below 30." % [node_id, value])
				"healing_mult":
					if value < 0.08:
						_errors.append("%s healing %.3f is below 8%%." % [node_id, value])
	for node_id in ["atlas_n0", "atlas_n1", "atlas_n2", "atlas_n3"]:
		var effects := Meta.node_by_id(node_id).get("effects", {}) as Dictionary
		var notable_grade := false
		for key in effects:
			var value := absf(float(effects[key]))
			notable_grade = notable_grade or (str(key) in ["money_gain_mult", "shop_price_mult", "attr_cost_mult"] and value >= 0.10)
			notable_grade = notable_grade or (str(key) == "start_gold_flat" and value >= 50.0)
			notable_grade = notable_grade or (str(key) == "pickup_radius_flat" and value >= 40.0)
			notable_grade = notable_grade or (str(key) == "healing_mult" and value >= 0.12)
			notable_grade = notable_grade or str(key) == "attr_extra_options"
		if not notable_grade:
			_errors.append("%s is below notable-grade impact." % node_id)


func _branch_utility(ids: Array) -> float:
	var utility := 0.0
	for node_id in ids:
		for key in (Meta.node_by_id(str(node_id)).get("effects", {}) as Dictionary):
			var value := absf(float(Meta.node_by_id(str(node_id))["effects"][key]))
			match str(key):
				"money_gain_mult", "xp_gain_mult", "shop_price_mult", "attr_cost_mult": utility += value / 0.05
				"start_gold_flat": utility += value / 25.0
				"pickup_radius_flat": utility += value / 30.0
				"healing_mult": utility += value / 0.08
				"guaranteed_rare_shop": utility += 2.0
				"first_levelup_rare": utility += 2.5
				"attr_extra_options": utility += 2.0
				"ult_start_charge": utility += value * 4.0
				"death_save": utility += 4.5
				"death_save_health_fraction": pass # Included in death-save grade.
	return utility


func _check_branch_targets_and_value() -> void:
	var treasury := _mods_for(BRANCHES["treasury"])
	if not is_equal_approx(float(treasury.get("money_gain_mult", 0.0)), 0.20) or int(treasury.get("start_gold_flat", 0)) != 100:
		_errors.append("Treasury target must be +20% gold/+100 start, got %s." % str(treasury))
	var shop := _mods_for(BRANCHES["shop"])
	if not is_equal_approx(float(shop.get("shop_price_mult", 0.0)), -0.20) or not is_equal_approx(float(shop.get("attr_cost_mult", 0.0)), -0.20):
		_errors.append("Shop target must be -20%/-20%, got %s." % str(shop))
	var knowledge := _mods_for(BRANCHES["knowledge"])
	if not is_equal_approx(float(knowledge.get("xp_gain_mult", 0.0)), 0.15) or int(knowledge.get("attr_extra_options", 0)) != 1 or not is_equal_approx(float(knowledge.get("ult_start_charge", 0.0)), 1.0):
		_errors.append("Knowledge target must be +15% XP/+1 option/100% ult, got %s." % str(knowledge))
	var road := _mods_for(BRANCHES["road"])
	if int(road.get("pickup_radius_flat", 0)) != 60 or not is_equal_approx(float(road.get("healing_mult", 0.0)), 0.20) or not is_equal_approx(float(road.get("death_save_health_fraction", 0.0)), 0.30):
		_errors.append("Road target must be +60 pickup/+20% healing/30% death-save, got %s." % str(road))
	for branch in BRANCHES:
		var cost := 0
		for node_id in BRANCHES[branch]:
			cost += int(Meta.node_by_id(str(node_id)).get("cost", 0))
		var value_per_dust := _branch_utility(BRANCHES[branch]) / float(cost)
		if value_per_dust < 0.64 or value_per_dust > 0.68:
			_errors.append("%s value/dust %.3f escapes competitive 0.64..0.68 corridor." % [branch, value_per_dust])


func _connected_branch_builds(ids: Array) -> Array:
	var builds := []
	for mask in range(1 << ids.size()):
		var selected := []
		for index in range(ids.size()):
			if mask & (1 << index):
				selected.append(str(ids[index]))
		var reachable := {"atlas_hub": true}
		var frontier := ["atlas_hub"]
		while not frontier.is_empty():
			var current := str(frontier.pop_back())
			for neighbor in Meta.node_by_id(current).get("adj", []):
				var neighbor_id := str(neighbor)
				if selected.has(neighbor_id) and not reachable.has(neighbor_id):
					reachable[neighbor_id] = true
					frontier.append(neighbor_id)
		var valid := true
		for node_id in selected:
			if not reachable.has(node_id):
				valid = false
				break
		if valid:
			builds.append(selected)
	return builds


func _enumerate_exact_50(branch_index: int, branch_builds: Array, selected: Array, cost: int, scores: Array) -> void:
	if cost > Meta.STARDUST_CAP:
		return
	if branch_index >= branch_builds.size():
		if cost == Meta.STARDUST_CAP:
			scores.append(_branch_utility(selected))
		return
	for build in branch_builds[branch_index]:
		var next_selected := selected.duplicate()
		next_selected.append_array(build)
		var next_cost := cost
		for node_id in build:
			next_cost += int(Meta.node_by_id(str(node_id)).get("cost", 0))
		_enumerate_exact_50(branch_index + 1, branch_builds, next_selected, next_cost, scores)


func _check_exact_50_build_competitiveness() -> void:
	var branch_builds := []
	for branch in ["treasury", "shop", "knowledge", "road"]:
		branch_builds.append(_connected_branch_builds(BRANCHES[branch]))
	var scores := []
	_enumerate_exact_50(0, branch_builds, [], 0, scores)
	if scores.size() != 384:
		_errors.append("Expected 384 connectivity-valid exact-50 builds, got %d." % scores.size())
		return
	var low := INF
	var high := 0.0
	for score in scores:
		low = minf(low, float(score))
		high = maxf(high, float(score))
	if not is_equal_approx(low, 31.0) or not is_equal_approx(high, 34.0) or high / low > 1.10:
		_errors.append("Exact-50 Guild build score spread %.3f exceeds 1.10 (%.2f..%.2f)." % [high / low, low, high])


func _check_hidden_positive_negative() -> void:
	var locked := Meta.default_state()
	if Meta.hidden_star_unlocked(locked, "atlas_h0") or Meta.skill_modifiers(locked).has("money_gain_mult"):
		_errors.append("Codex hidden node activates before its milestone.")
	var codex := locked.duplicate(true)
	codex["discovered_monsters"] = Meta._canonical_codex_ids("monsters").keys()
	if not Meta.hidden_star_unlocked(codex, "atlas_h0") or not is_equal_approx(float(Meta.skill_modifiers(codex).get("money_gain_mult", 0.0)), 0.10):
		_errors.append("Codex hidden node must positively grant +10% gold at four milestones.")
	if Meta.hidden_star_unlocked(locked, "atlas_h1") or Meta.skill_modifiers(locked).has("start_gold_flat"):
		_errors.append("Secret-boss hidden node activates before victory.")
	var secret := locked.duplicate(true)
	secret["secret_boss_defeated"] = true
	if not Meta.hidden_star_unlocked(secret, "atlas_h1") or int(Meta.skill_modifiers(secret).get("start_gold_flat", 0)) != 50:
		_errors.append("Secret-boss hidden node must positively grant +50 start gold.")


func _check_power_economy_and_a5_caps() -> void:
	var full := Meta.default_state()
	var purchases := []
	for raw_node in Meta.atlas_nodes():
		var node := raw_node as Dictionary
		if int(node.get("cost", 0)) > 0:
			purchases.append(str(node["id"]))
	full["skill_nodes"] = purchases
	full["discovered_monsters"] = Meta._canonical_codex_ids("monsters").keys()
	full["secret_boss_defeated"] = true
	var mods := Meta.skill_modifiers(full)
	var account_power := Meta.estimated_power_multiplier(full)
	if account_power >= Meta.GUILD_ATLAS_ACCOUNT_POWER_CAP:
		_errors.append("Full-Atlas upper bound breaks account power cap: %.4f." % account_power)
	var expected_class_delta := -1.0
	for class_id in Meta.constellation_class_ids():
		var class_delta := Meta.estimated_class_power_multiplier(full, str(class_id)) \
			- Meta.estimated_class_power_multiplier(Meta.default_state(), str(class_id))
		if class_delta > Meta.GUILD_ATLAS_CLASS_POWER_DELTA_CAP + 0.0001:
			_errors.append("Full Atlas breaks %.0f%% class cap for %s: %.4f." % [Meta.GUILD_ATLAS_CLASS_POWER_DELTA_CAP * 100.0, class_id, class_delta])
		if expected_class_delta < 0.0:
			expected_class_delta = class_delta
		elif not is_equal_approx(class_delta, expected_class_delta):
			_errors.append("Guild contribution must be class-neutral: %s %.4f vs %.4f." % [class_id, class_delta, expected_class_delta])
	if float(mods.get("money_gain_mult", 0.0)) > 0.3001 or float(mods.get("xp_gain_mult", 0.0)) > 0.1501:
		_errors.append("Guild gain caps allow economy/XP runaway: %s." % str(mods))
	if float(mods.get("shop_price_mult", 0.0)) < -0.2001 or float(mods.get("attr_cost_mult", 0.0)) < -0.2001:
		_errors.append("Guild price discounts exceed safe 20%% cap: %s." % str(mods))
	if int(mods.get("start_gold_flat", 0)) > 150:
		_errors.append("Guild start-gold upper bound exceeds 150: %s." % str(mods))
	var a5 := ProgressionData.ascension_difficulty_mods(5)
	if float(a5.get("enemy_hp_mult", 1.0)) <= 1.5 or float(a5.get("enemy_damage_mult", 1.0)) <= 1.5:
		_errors.append("A5 monster pressure no longer exceeds A0 after Guild changes: %s." % str(a5))
	if float(a5.get("healing_mult", 1.0)) * (1.0 + float(mods.get("healing_mult", 0.0))) >= 1.0:
		_errors.append("Full Guild healing cancels the A5 healing penalty.")
	if float(a5.get("reward_mult", 1.0)) * (1.0 + float(mods.get("money_gain_mult", 0.0))) > 1.05:
		_errors.append("Full Guild gold turns A5 reward pressure into runaway.")
