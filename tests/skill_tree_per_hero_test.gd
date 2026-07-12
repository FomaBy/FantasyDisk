extends SceneTree

# SCRUM-1068: per-hero contract for schema 6 constellations. Every class owns
# one free core, three six-node weapon paths, and two revealed-then-purchased
# hidden side boons. Weapon finals are independent and may all be active.

const Meta := preload("res://scripts/meta_progression.gd")
const CharacterData := preload("res://scripts/progression_data_characters.gd")

const EXPECTED_BRANCH_X := [0.20, 0.50, 0.80]
const EXPECTED_BRANCH_Y := [0.22, 0.34, 0.46, 0.58, 0.70, 0.82]


func _initialize() -> void:
	_test_constellation_anatomy()
	_test_three_linear_weapon_paths()
	_test_weapon_profiles_are_strictly_scoped()
	_test_all_finals_are_coactive()
	_test_hidden_stars_require_reveal_and_purchase()
	print("Skill tree per-hero test passed.")
	quit(0)


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)


func _class_ids() -> Array:
	var ids: Array = CharacterData.CHARACTER_CONFIGS.keys()
	ids.sort()
	return ids


func _purchasable_weapon_node_ids(class_id: String) -> Array:
	var ids := []
	for raw_node in Meta.constellation_nodes(class_id):
		var node: Dictionary = raw_node
		if str(node.get("role", "")) in ["weapon_boon", "weapon_final"]:
			ids.append(str(node.get("id", "")))
	return ids


func _test_constellation_anatomy() -> void:
	if _class_ids().size() != 17:
		_fail("Schema 6 requires exactly 17 class constellations.")
		return
	for class_value in _class_ids():
		var class_id := str(class_value)
		var nodes := Meta.constellation_nodes(class_id)
		if nodes.size() != 21:
			_fail("Constellation '%s' must contain 21 nodes, got %d." % [class_id, nodes.size()])
			return
		var role_counts := {}
		var spend := 0
		for raw_node in nodes:
			var node: Dictionary = raw_node
			var role := str(node.get("role", ""))
			role_counts[role] = int(role_counts.get(role, 0)) + 1
			var cost := int(node.get("cost", -1))
			if role == "core":
				if cost != 0:
					_fail("Core '%s' must be free." % str(node.get("id", "")))
					return
			else:
				if cost != 1:
					_fail("Schema-6 node '%s' must cost one sigil, got %d." % [str(node.get("id", "")), cost])
					return
				spend += cost
			if not (node.get("npos") is Vector2) or not (node.get("pos") is Vector2):
				_fail("Node '%s' must expose normalized and world positions." % str(node.get("id", "")))
				return
			if str(node.get("title", "")) == "" or str(node.get("desc", "")) == "":
				_fail("Node '%s' is missing localized title/description." % str(node.get("id", "")))
				return
		if role_counts != {"core": 1, "weapon_boon": 15, "weapon_final": 3, "hidden": 2}:
			_fail("Constellation '%s' must have roles 1/15/3/2, got %s." % [class_id, str(role_counts)])
			return
		if spend != 20 or Meta.constellation_total_cost(class_id) != 20:
			_fail("Constellation '%s' must have exact spend 20, got %d/%d." % [class_id, spend, Meta.constellation_total_cost(class_id)])
			return
		var core := Meta.node_by_id(str(Meta.CLASS_ENTRY_NODES.get(class_id, "")))
		if core.is_empty() or str(core.get("role", "")) != "core" or core.get("npos") != Vector2(0.50, 0.08):
			_fail("Constellation '%s' has an invalid free core." % class_id)
			return
		var core_profile: Dictionary = core.get("effect_profile", {})
		var core_params: Dictionary = core_profile.get("params", {})
		if str(core_profile.get("effect_key", "")) != "primary_attribute_flat" \
				or str(core_profile.get("scope", "")) != "owning_class" \
				or not is_equal_approx(float(core_params.get("amount", 0.0)), 1.0):
			_fail("Core '%s' must grant exactly +1 primary attribute to its class." % class_id)
			return
		if Meta.node_status(Meta.default_state(), str(core.get("id", ""))) != "purchased":
			_fail("Core '%s' must be active on a fresh account." % class_id)
			return


func _test_three_linear_weapon_paths() -> void:
	for class_value in _class_ids():
		var class_id := str(class_value)
		var by_weapon := {}
		for raw_node in Meta.constellation_nodes(class_id):
			var node: Dictionary = raw_node
			if str(node.get("role", "")) not in ["weapon_boon", "weapon_final"]:
				continue
			var weapon_id := str(node.get("weapon_id", ""))
			if weapon_id == "":
				_fail("Weapon node '%s' is missing owning weapon id." % str(node.get("id", "")))
				return
			if not by_weapon.has(weapon_id):
				by_weapon[weapon_id] = []
			(by_weapon[weapon_id] as Array).append(node)
		if by_weapon.size() != 3:
			_fail("Constellation '%s' must expose exactly three weapon paths." % class_id)
			return
		var branch_index := 0
		var weapon_ids: Array = by_weapon.keys()
		weapon_ids.sort_custom(func(a, b):
			var an: Dictionary = (by_weapon[a] as Array)[0]
			var bn: Dictionary = (by_weapon[b] as Array)[0]
			return float((an.get("npos") as Vector2).x) < float((bn.get("npos") as Vector2).x)
		)
		for weapon_value in weapon_ids:
			var weapon_id := str(weapon_value)
			var branch: Array = by_weapon[weapon_id]
			branch.sort_custom(func(a, b): return int((a as Dictionary).get("branch_order", 0)) < int((b as Dictionary).get("branch_order", 0)))
			if branch.size() != 6:
				_fail("Path '%s/%s' must contain six nodes." % [class_id, weapon_id])
				return
			var previous_id := str(Meta.CLASS_ENTRY_NODES[class_id])
			for index in range(6):
				var node: Dictionary = branch[index]
				var expected_order := index + 1
				if int(node.get("branch_order", 0)) != expected_order:
					_fail("Path '%s/%s' has a missing order %d." % [class_id, weapon_id, expected_order])
					return
				var expected_role := "weapon_final" if expected_order == 6 else "weapon_boon"
				if str(node.get("role", "")) != expected_role:
					_fail("Path '%s/%s' order %d must be %s." % [class_id, weapon_id, expected_order, expected_role])
					return
				var npos: Vector2 = node["npos"]
				if not is_equal_approx(npos.x, float(EXPECTED_BRANCH_X[branch_index])) \
						or not is_equal_approx(npos.y, float(EXPECTED_BRANCH_Y[index])):
					_fail("Path '%s/%s' order %d has wrong normalized position %s." % [class_id, weapon_id, expected_order, str(npos)])
					return
				if not (node.get("adj", []) as Array).has(previous_id):
					_fail("Path '%s/%s' is not linear at order %d." % [class_id, weapon_id, expected_order])
					return
				var profile: Dictionary = node.get("effect_profile", {})
				if str(profile.get("scope", "")) != "owning_weapon_only" or str(profile.get("effect_key", "")) == "":
					_fail("Node '%s' lacks an owning-weapon effect profile." % str(node.get("id", "")))
					return
				previous_id = str(node.get("id", ""))
			branch_index += 1


func _test_weapon_profiles_are_strictly_scoped() -> void:
	for class_value in _class_ids():
		var class_id := str(class_value)
		var state := Meta.default_state()
		state["skill_nodes"] = _purchasable_weapon_node_ids(class_id)
		var profiles: Dictionary = Meta.skill_profiles_for_class(state, class_id)
		if profiles.size() != 3:
			_fail("Class '%s' must return exactly three typed weapon profiles." % class_id)
			return
		for weapon_value in profiles.keys():
			var weapon_id := str(weapon_value)
			var profile: Dictionary = profiles[weapon_id]
			if not bool(profile.get("valid", false)) or str(profile.get("class_id", "")) != class_id \
					or str(profile.get("weapon_id", "")) != weapon_id:
				_fail("Typed profile '%s/%s' is invalid." % [class_id, weapon_id])
				return
			if (profile.get("node_ids", []) as Array).size() != 6:
				_fail("Typed profile '%s/%s' must contain its six path nodes only." % [class_id, weapon_id])
				return
			for node_value in profile.get("node_ids", []):
				var node := Meta.node_by_id(str(node_value))
				if str(node.get("weapon_id", "")) != weapon_id:
					_fail("Weapon profile '%s/%s' leaked node '%s'." % [class_id, weapon_id, str(node_value)])
					return
		var foreign := Meta.skill_modifiers_for_weapon(state, class_id, "__foreign_weapon__")
		if bool(foreign.get("valid", true)) or (foreign.get("errors", []) as Array).is_empty():
			_fail("Class '%s' must reject a foreign weapon id." % class_id)
			return


func _test_all_finals_are_coactive() -> void:
	for class_value in _class_ids():
		var class_id := str(class_value)
		var state := Meta.default_state()
		state["skill_nodes"] = _purchasable_weapon_node_ids(class_id)
		if state.has("active_keystones"):
			_fail("Schema-6 state must not require active_keystones.")
			return
		var finals_seen := 0
		for profile_value in Meta.skill_profiles_for_class(state, class_id).values():
			var profile: Dictionary = profile_value
			var mechanics: Dictionary = profile.get("mechanics", {})
			if mechanics.size() != 1:
				_fail("Each full path of '%s' must expose exactly one active final mechanic." % class_id)
				return
			finals_seen += mechanics.size()
		if finals_seen != 3:
			_fail("All three weapon finals of '%s' must be simultaneously active." % class_id)
			return


func _test_hidden_stars_require_reveal_and_purchase() -> void:
	var state := Meta.default_state()
	for hidden_id in ["berserk_h0", "berserk_h1"]:
		if Meta.node_status(state, hidden_id) != "hidden" or Meta.hidden_star_unlocked(state, hidden_id):
			_fail("Hidden node '%s' must start concealed." % hidden_id)
			return
	# Six unique first-clear facts yield the exact 20-sigil schema-6 cap and
	# reveal both Berserk side boons through diversity and best ascension.
	var weapons := ["sword", "axe", "hammer", "sword", "axe", "hammer"]
	for ascension in range(6):
		state = Meta.record_boss_victory(state, "berserk", ascension, {"weapon_id": weapons[ascension]})
	if Meta.class_sigils_earned(state, "berserk") != 20:
		_fail("Six first clears must award exactly 20 spendable sigils.")
		return
	for hidden_id in ["berserk_h0", "berserk_h1"]:
		if not Meta.hidden_star_unlocked(state, hidden_id):
			_fail("Challenge facts must reveal hidden node '%s'." % hidden_id)
			return
		if Meta.is_node_purchased(state, hidden_id):
			_fail("Reveal must not auto-purchase hidden node '%s'." % hidden_id)
			return
	# Buy all three paths first (18), then both revealed side boons (2).
	for weapon_id in ["sword", "axe", "hammer"]:
		for order in range(1, 7):
			var node_id := "berserk_%s_final" % weapon_id if order == 6 else "berserk_%s_b%d" % [weapon_id, order]
			state = Meta.allocate_node(state, node_id)
	for hidden_id in ["berserk_h0", "berserk_h1"]:
		if Meta.node_status(state, hidden_id) != "available":
			_fail("Revealed hidden node '%s' must become purchasable after its b3 anchor." % hidden_id)
			return
		state = Meta.allocate_node(state, hidden_id)
		if not Meta.is_node_purchased(state, hidden_id):
			_fail("Hidden node '%s' must activate only after purchase." % hidden_id)
			return
	if Meta.class_sigils_spent(state, "berserk") != 20 or Meta.class_sigils_available(state, "berserk") != 0:
		_fail("Full schema-6 Berserk constellation must spend exactly 20 sigils.")
		return
	for hidden_id in ["berserk_h0", "berserk_h1"]:
		var hidden := Meta.node_by_id(hidden_id)
		var weapon_id := str(hidden.get("weapon_id", ""))
		var own_profile := Meta.skill_modifiers_for_weapon(state, "berserk", weapon_id)
		if not (own_profile.get("node_ids", []) as Array).has(hidden_id):
			_fail("Purchased hidden node '%s' must affect only its owning weapon profile." % hidden_id)
			return
		for foreign_id in ["sword", "axe", "hammer"]:
			if foreign_id != weapon_id and (Meta.skill_modifiers_for_weapon(state, "berserk", foreign_id).get("node_ids", []) as Array).has(hidden_id):
				_fail("Hidden node '%s' leaked into foreign weapon '%s'." % [hidden_id, foreign_id])
				return
