extends SceneTree

const PD := preload("res://scripts/progression_data.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")

const EPS := 0.0001


func _initialize() -> void:
	var errors: Array = []
	_test_strict_asymptotes(errors)
	await _test_runtime_composition(errors)
	if not errors.is_empty():
		for error in errors:
			push_error("FAN-1895 defensive contract: %s" % str(error))
		quit(1)
		return
	print("FAN-1895 defensive contract passed.")
	quit(0)


func _test_strict_asymptotes(errors: Array) -> void:
	var previous_defense := -1.0
	var previous_dodge := -1.0
	for stacks in [0, 1, 5, 10, 100000]:
		var defense := PD.effective_defense(0.04 + float(stacks) * 0.05)
		var dodge := PD.effective_dodge(0.02 + float(stacks) * 0.05)
		if not (defense > previous_defense and defense < PD.SURVIVABILITY_DEFENSE_CAP):
			errors.append("defense stack %d is not a positive strict-asymptote gain (%.6f)" % [stacks, defense])
		if not (dodge > previous_dodge and dodge < PD.SURVIVABILITY_DODGE_CAP):
			errors.append("dodge stack %d is not a positive strict-asymptote gain (%.6f)" % [stacks, dodge])
		previous_defense = defense
		previous_dodge = dodge
	var robot_pass := PD.SURVIVABILITY_ABSORB_MIN_DAMAGE_FRACTION * (1.0 - PD.effective_defense(100000.0)) * 0.8
	var robot_mitigation := 1.0 - (1.0 - PD.effective_dodge(100000.0)) * robot_pass
	if robot_mitigation >= 0.98:
		errors.append("aggregate robot mitigation %.6f reaches the 0.98 immunity gate" % robot_mitigation)


func _test_runtime_composition(errors: Array) -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var bastion := await _new_player(holder, "berserk")
	_prepare_player(bastion, 10.0)
	var bastion_modifiers: Dictionary = bastion.get("run_modifiers")
	bastion_modifiers["bastion_defense_bonus"] = 0.25
	bastion.set("_stance_active", true)
	var bastion_hit := _take_hit(bastion, 100.0)
	var bastion_expected := 100.0 * (1.0 - PD.effective_defense(10.25))
	if bastion_hit <= EPS or absf(bastion_hit - bastion_expected) > EPS:
		errors.append("Bastion hit %.6f != diminishing result %.6f" % [bastion_hit, bastion_expected])

	var low_hp := await _new_player(holder, "priest")
	_prepare_player(low_hp, 10.0)
	var low_hp_modifiers: Dictionary = low_hp.get("run_modifiers")
	low_hp_modifiers["lowhp_defense_bonus"] = 0.12
	low_hp.set("_low_hp_active", true)
	var low_hp_hit := _take_hit(low_hp, 100.0)
	var low_hp_expected := 100.0 * (1.0 - PD.effective_defense(10.12))
	if low_hp_hit <= EPS or absf(low_hp_hit - low_hp_expected) > EPS:
		errors.append("low-HP hit %.6f != diminishing result %.6f" % [low_hp_hit, low_hp_expected])

	var assassin := await _new_player(holder, "assassin")
	_prepare_player(assassin, 0.0, 10.0)
	var enemy := Node2D.new()
	enemy.add_to_group("enemies")
	holder.add_child(enemy)
	enemy.global_position = assassin.global_position + Vector2(30.0, 0.0)
	await process_frame
	var veil_bonus := float(assassin.call("assassin_veil_dodge_bonus"))
	var assassin_dodge := float(assassin.call("current_dodge_chance"))
	if absf(assassin_dodge - PD.effective_dodge(10.0 + veil_bonus)) > EPS or assassin_dodge >= PD.SURVIVABILITY_DODGE_CAP:
		errors.append("Assassin veil %.6f escaped the ordinary dodge contract" % assassin_dodge)

	var thief := await _new_player(holder, "thief")
	_prepare_player(thief, 0.0, 10.0)
	var outside_dodge := float(thief.call("current_dodge_chance"))
	if outside_dodge >= PD.SURVIVABILITY_DODGE_CAP:
		errors.append("Thief outside smoke %.6f reached ordinary dodge asymptote" % outside_dodge)
	thief.call("register_smoke_cloud", thief.global_position, 170.0, 5.0, 0.47)
	var smoke_dodge := float(thief.call("current_dodge_chance"))
	if absf(smoke_dodge - PD.SMOKE_CLOUD_DODGE_CAP) > EPS:
		errors.append("Thief smoke %.6f != separate smoke contract %.2f" % [smoke_dodge, PD.SMOKE_CLOUD_DODGE_CAP])

	holder.queue_free()
	await process_frame


func _new_player(holder: Node2D, character_id: String) -> Node2D:
	var player := PLAYER_SCENE.instantiate() as Node2D
	holder.add_child(player)
	player.global_position = Vector2(4000.0, 4000.0)
	player.call("configure_character", character_id, str(PD.weapon_ids(character_id)[0]))
	await process_frame
	var weapon: Node = player.get("equipped_weapon")
	if weapon != null:
		weapon.set_process(false)
		weapon.set("_cooldown", 1.0e9)
	return player


func _prepare_player(player: Node2D, raw_defense: float, raw_dodge := 0.0) -> void:
	var parameters: Dictionary = player.get("derived_parameters")
	parameters["raw_defense"] = raw_defense
	parameters["defense"] = PD.effective_defense(raw_defense)
	parameters["raw_dodge"] = raw_dodge
	parameters["dodge"] = PD.effective_dodge(raw_dodge)
	parameters["absorb"] = 0.0
	player.set("derived_parameters", parameters)
	player.set("run_modifiers", {})
	player.set("health", 400.0)
	player.set("max_health", 400.0)


func _take_hit(player: Node2D, amount: float) -> float:
	var before := float(player.get("health"))
	player.set("_damage_invulnerability_left", 0.0)
	player.call("take_damage", amount)
	return before - float(player.get("health"))
