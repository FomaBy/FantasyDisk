extends SceneTree

# SCRUM-714 (refactor wave 0.1.8): per-character cross-slice data-contract validation
# for the ProgressionData facade. The existing api_surface test spot-checks a single
# character; this sweeps EVERY character so a newly added or edited class missing
# ascension/budget/ultimate/damage-parameter data is caught instead of failing at
# runtime. Pure read-only validation — it does not modify any balance data.

const PD := preload("res://scripts/progression_data.gd")


func _initialize() -> void:
	var errors: Array = []
	var ids: Array = PD.character_ids()
	if ids.is_empty():
		push_error("character_ids() empty.")
		quit(1)
		return

	# Facade key sets must agree with the canonical character list (no orphan/missing data).
	_check_keyset(errors, PD.CHARACTER_CONFIGS, ids, "CHARACTER_CONFIGS")
	_check_keyset(errors, PD.BASE_STATS, ids, "BASE_STATS")
	for character_id_raw in ids:
		var cid := str(character_id_raw)
		if not PD.WEAPONS_BY_CLASS.has(cid):
			errors.append("%s: missing in WEAPONS_BY_CLASS" % cid)

		_nonempty_dict(errors, PD.character_config(cid), "%s.character_config" % cid)
		var stats: Dictionary = PD.base_stats(cid)
		_nonempty_dict(errors, stats, "%s.base_stats" % cid)
		_nonempty_array(errors, PD.weapon_ids(cid), "%s.weapon_ids" % cid)
		_nonempty_dict(errors, PD.ultimate_config(cid), "%s.ultimate_config" % cid)
		_nonempty_dict(errors, PD.class_budget_profile(cid), "%s.class_budget_profile" % cid)
		_nonempty_dict(errors, PD.class_mechanic_identity(cid), "%s.class_mechanic_identity" % cid)
		if str(PD.class_main_attribute(cid)) == "":
			errors.append("%s: class_main_attribute empty" % cid)

		# The class's primary damage parameter must be a key derived_parameters actually
		# produces — player.gd reads derived_parameters[damage_parameter_for(cid)] for
		# echo/summon damage, so a stale parameter id would silently fall back to default.
		var damage_param := str(PD.damage_parameter_for(cid))
		if damage_param == "":
			errors.append("%s: damage_parameter_for empty" % cid)
		elif not stats.is_empty():
			var derived: Dictionary = PD.derived_parameters(stats, {}, {})
			if not derived.has(damage_param):
				errors.append("%s: derived_parameters missing damage parameter '%s'" % [cid, damage_param])
			for required in ["damage", "health_point", "move_speed"]:
				if not derived.has(required):
					errors.append("%s: derived_parameters missing '%s'" % [cid, required])

	# Reverse direction: no WEAPONS_BY_CLASS entry for a non-existent character.
	for class_key in PD.WEAPONS_BY_CLASS.keys():
		if not (str(class_key) in ids):
			errors.append("WEAPONS_BY_CLASS has orphan class '%s'" % str(class_key))

	if not errors.is_empty():
		for e in errors:
			push_error("ProgressionData character contract: %s" % e)
		push_error("ProgressionData character contract test: %d errors." % errors.size())
		quit(1)
		return
	print("ProgressionData character contract test passed (%d characters)." % ids.size())
	quit(0)


func _check_keyset(errors: Array, data: Dictionary, ids: Array, name: String) -> void:
	for character_id_raw in ids:
		if not data.has(str(character_id_raw)):
			errors.append("%s: missing entry for '%s'" % [name, str(character_id_raw)])
	for key in data.keys():
		if not (str(key) in ids):
			errors.append("%s: orphan entry '%s' (not a character_id)" % [name, str(key)])


func _nonempty_dict(errors: Array, v, name: String) -> void:
	if not (v is Dictionary) or (v as Dictionary).is_empty():
		errors.append("%s: empty/not a Dictionary" % name)


func _nonempty_array(errors: Array, v, name: String) -> void:
	if not (v is Array) or (v as Array).is_empty():
		errors.append("%s: empty/not an Array" % name)
