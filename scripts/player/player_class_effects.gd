class_name PlayerClassEffects
extends RefCounted

## FAN-3922 (FD15): constellation state transitions and recurring class aura
## effects extracted from Player. Player remains the state owner and keeps the
## public API/signals used by weapons, saves, tests, and UI. This collaborator
## preserves synchronous event ordering while keeping inactive classes out of
## scene-tree aura work.

const ProgressionData := preload("res://scripts/progression_data.gd")
const TARGET_QUERY := preload("res://scripts/combat_target_query.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")
const AttackVfx := preload("res://scripts/attack_vfx.gd")
const ConstellationFinalRuntime := preload("res://scripts/constellation_final_runtime.gd")
const SCHEMA6_DATA := preload("res://scripts/constellation_schema6_data.gd")

const COMMAND_AURA_CLASSES := ["guitarist", "druid", "engineer", "priest"]
const PRESSURE_AURA_CLASSES := ["guitarist", "druid", "engineer"]
const STATUS_AURA_INTERVAL := 0.55
const WILD_AURA_RING_NAME := "WildForceAuraRing"
const WILD_AURA_COLOR := Color(0.46, 0.84, 0.34, 1.0)


class WildForceAuraRing extends Node2D:
	var radius := 0.0:
		set(value):
			if not is_equal_approx(radius, value):
				radius = value
				queue_redraw()

	func _draw() -> void:
		if radius <= 0.0:
			return
		draw_circle(Vector2.ZERO, radius, Color(0.46, 0.84, 0.34, 0.045))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, Color(0.46, 0.84, 0.34, 0.20), 2.5, true)


## Starts a new character/run epoch. Token increments invalidate every expiry
## callback scheduled by the prior epoch; clearing state keeps the Player save
## representation unchanged. Aura visuals are removed synchronously from the
## old class lifecycle instead of waiting for a later physics tick.
static func reset(player) -> void:
	player._constellation_absorb_token += 1
	player._constellation_dodge_token += 1
	player._constellation_final_state.clear()
	player._constellation_absorb_sources.clear()
	player._constellation_dodge_sources.clear()
	player._constellation_single_hit_ward.clear()
	player._status_aura_cooldown_left = 0.0
	var ring := player.get_node_or_null(WILD_AURA_RING_NAME) as WildForceAuraRing
	if ring != null:
		ring.queue_free()


static func apply_constellation_weapon_profiles(player, raw_profiles: Dictionary) -> void:
	var accepted := {}
	for raw_weapon_id in raw_profiles.keys():
		var weapon_id_value := str(raw_weapon_id)
		var raw_profile = raw_profiles[raw_weapon_id]
		if not raw_profile is Dictionary:
			continue
		var profile := canonical_constellation_weapon_profile(player, raw_profile as Dictionary, weapon_id_value)
		if profile.is_empty():
			push_error("SCRUM-1068 rejected invalid constellation profile for %s/%s." % [player.character_id, weapon_id_value])
			continue
		accepted[weapon_id_value] = profile
	player.run_modifiers["constellation_weapon_profiles"] = accepted
	for weapon in player._equipped_weapons():
		player._apply_weapon_scaling(weapon)


static func canonical_constellation_weapon_profile(player, raw_profile: Dictionary, weapon_id_value: String) -> Dictionary:
	if (
		int(raw_profile.get("schema", 0)) != SCHEMA6_DATA.EXPECTED_SCHEMA
		or str(raw_profile.get("class_id", "")) != player.character_id
		or str(raw_profile.get("weapon_id", "")) != weapon_id_value
		or not bool(raw_profile.get("valid", false))
	):
		return {}
	var class_entry := SCHEMA6_DATA.class_entry(player.character_id)
	var canonical_branch := {}
	for raw_branch in class_entry.get("weapon_branches", []):
		var branch: Dictionary = raw_branch
		if str(branch.get("weapon_id", "")) == weapon_id_value:
			canonical_branch = branch
			break
	if canonical_branch.is_empty():
		return {}
	var result := {
		"schema": SCHEMA6_DATA.EXPECTED_SCHEMA,
		"class_id": player.character_id,
		"weapon_id": weapon_id_value,
		"axis": str(canonical_branch.get("axis", "")),
		"identity": str(canonical_branch.get("identity", "")),
		"valid": true,
		"node_ids": [],
		"entries": [],
		"amounts": {},
		"multipliers": {},
		"mechanics": {},
		"errors": [],
	}
	var raw_node_ids = raw_profile.get("node_ids", [])
	if not raw_node_ids is Array:
		return {}
	for raw_node_id in raw_node_ids:
		var node_id := str(raw_node_id)
		if (result["node_ids"] as Array).has(node_id):
			return {}
		var node := SCHEMA6_DATA.node(node_id)
		var node_weapon_id := str(node.get("weapon_id", node.get("attach_weapon_id", "")))
		if node.is_empty() or str(node.get("class_id", "")) != player.character_id or node_weapon_id != weapon_id_value:
			return {}
		var effect_profile: Dictionary = node.get("effect_profile", {})
		if str(effect_profile.get("scope", "")) != "owning_weapon_only":
			return {}
		var effect_key := str(effect_profile.get("effect_key", ""))
		var params: Dictionary = effect_profile.get("params", {})
		(result["node_ids"] as Array).append(node_id)
		(result["entries"] as Array).append({
			"node_id": node_id,
			"effect_key": effect_key,
			"params": params.duplicate(true),
			"caps": (node.get("caps", {}) as Dictionary).duplicate(true),
		})
		if str(node.get("role", "")) == "weapon_final":
			if SCHEMA6_DATA.mechanic(effect_key).is_empty() or not (result["mechanics"] as Dictionary).is_empty():
				return {}
			(result["mechanics"] as Dictionary)[effect_key] = {
				"node_id": node_id,
				"params": params.duplicate(true),
				"caps": (node.get("caps", {}) as Dictionary).duplicate(true),
				"runtime_consumer": str(node.get("runtime_consumer", "")),
			}
		elif params.has("amount"):
			var amounts: Dictionary = result["amounts"]
			amounts[effect_key] = float(amounts.get(effect_key, 0.0)) + float(params["amount"])
		elif params.has("multiplier"):
			var multipliers: Dictionary = result["multipliers"]
			multipliers[effect_key] = float(multipliers.get(effect_key, 1.0)) * float(params["multiplier"])
	return result


static func constellation_weapon_profile(player, weapon_id_value: String) -> Dictionary:
	var profiles = player.run_modifiers.get("constellation_weapon_profiles", {})
	if not profiles is Dictionary:
		return {}
	var profile = (profiles as Dictionary).get(weapon_id_value, {})
	return profile if profile is Dictionary else {}


static func constellation_weapon_amount(player, weapon_id_value: String, effect_key: String) -> float:
	var amounts = constellation_weapon_profile(player, weapon_id_value).get("amounts", {})
	return float((amounts as Dictionary).get(effect_key, 0.0)) if amounts is Dictionary else 0.0


static func constellation_weapon_multiplier(player, weapon_id_value: String, effect_key: String) -> float:
	var multipliers = constellation_weapon_profile(player, weapon_id_value).get("multipliers", {})
	return float((multipliers as Dictionary).get(effect_key, 1.0)) if multipliers is Dictionary else 1.0


static func constellation_weapon_mechanic(player, weapon_id_value: String, mechanic_id: String) -> Dictionary:
	var mechanics = constellation_weapon_profile(player, weapon_id_value).get("mechanics", {})
	var mechanic = (mechanics as Dictionary).get(mechanic_id, {}) if mechanics is Dictionary else {}
	return mechanic if mechanic is Dictionary else {}


static func constellation_weapon_event(player, weapon_id_value: String, event: String, context := {}, enemy: Node2D = null) -> Dictionary:
	var profile := constellation_weapon_profile(player, weapon_id_value)
	var mechanics = profile.get("mechanics", {})
	if not mechanics is Dictionary or (mechanics as Dictionary).is_empty():
		return {"valid": true, "triggered": false, "damage_multiplier": 1.0, "axis_gain": 1.0}
	if (mechanics as Dictionary).size() != 1:
		push_error("SCRUM-1068 expected exactly one final for %s/%s." % [player.character_id, weapon_id_value])
		return {"valid": false, "triggered": false, "damage_multiplier": 1.0, "axis_gain": 1.0}
	var mechanic_id := str((mechanics as Dictionary).keys()[0])
	var mechanic: Dictionary = ((mechanics as Dictionary)[mechanic_id] as Dictionary).duplicate(true)
	mechanic["mechanic_id"] = mechanic_id
	var runtime_context: Dictionary = context.duplicate(true) if context is Dictionary else {}
	runtime_context["target_id"] = str(enemy.get_instance_id()) if enemy != null and is_instance_valid(enemy) else str(runtime_context.get("target_id", "target"))
	var resolution := ConstellationFinalRuntime.resolve_event(mechanic, player._constellation_final_state, event, runtime_context)
	if not bool(resolution.get("valid", false)):
		push_error("SCRUM-1068 final runtime rejected %s." % mechanic_id)
		return {"valid": false, "triggered": false, "damage_multiplier": 1.0, "axis_gain": 1.0}
	if bool(resolution.get("triggered", false)):
		player._telemetry_sequence["final"] += 1
		resolution["telemetry_final_activation_id"] = "final_%06d" % player._telemetry_sequence["final"]
	player.constellation_final_resolved.emit(weapon_id_value, event, enemy, runtime_context.duplicate(true), resolution.duplicate(true))
	if bool(resolution.get("triggered", false)):
		player.run_modifiers["constellation_last_final_action"] = resolution.duplicate(true)
		if enemy != null and is_instance_valid(enemy):
			enemy.set_meta("constellation_final_action", resolution.duplicate(true))
		apply_constellation_final_side_effect(player, resolution.get("side_effect", {}), enemy, resolution)
	return resolution


static func dispatch_constellation_owner_event(player, event: String, context := {}, enemy: Node2D = null) -> Dictionary:
	var active_weapon: Variant = player.equipped_weapon
	if active_weapon != null and is_instance_valid(active_weapon) and active_weapon.has_method("constellation_owner_event"):
		return active_weapon.call("constellation_owner_event", event, context, enemy)
	return constellation_weapon_event(player, player.weapon_id, event, context, enemy)


static func apply_constellation_final_side_effect(player, raw_effect, enemy: Node2D = null, resolution := {}) -> void:
	if not raw_effect is Dictionary:
		return
	var effect: Dictionary = raw_effect
	if enemy != null and is_instance_valid(enemy):
		var reduction := clampf(float(effect.get("enemy_damage_reduction", 0.0)), 0.0, 0.35)
		if reduction > 0.0 and TARGET_QUERY.is_epic_displacement_immune(enemy):
			reduction *= clampf(float(effect.get("boss_factor", 1.0)), 0.0, 1.0)
		if reduction > 0.0:
			StatusEffects.apply_status(enemy, "constellation_suppression", {
				"duration": maxf(float(effect.get("duration_seconds", 0.0)), 0.1),
				"damage_multiplier": 1.0 - reduction,
			})
		var control_seconds := maxf(float(effect.get("control_seconds", 0.0)), 0.0)
		if control_seconds > 0.0:
			StatusEffects.apply_status(enemy, "constellation_control", {
				"duration": control_seconds, "speed_multiplier": 0.6,
			})
		enemy.set_meta("constellation_%s_owner" % str((resolution as Dictionary).get("mechanic_id", effect.get("kind", "final"))), player.get_instance_id())


static func set_timed_absorb(player, source_id: String, amount: float, duration: float) -> float:
	if source_id == "":
		return 0.0
	var normalized := clampf(amount, 0.0, 30.0)
	var previous_entry = player._constellation_absorb_sources.get(source_id, {})
	var previous := float((previous_entry as Dictionary).get("amount", 0.0)) if previous_entry is Dictionary else 0.0
	player._constellation_absorb_token += 1
	var token: int = player._constellation_absorb_token
	player._constellation_absorb_sources[source_id] = {"amount": normalized, "token": token}
	player.run_modifiers["absorb_flat"] = maxf(float(player.run_modifiers.get("absorb_flat", 0.0)) + normalized - previous, 0.0)
	player._apply_stat_scaling(false, player.max_health)
	if duration > 0.0 and player.is_inside_tree():
		var expiry: Tween = player.create_tween()
		expiry.tween_interval(duration)
		expiry.tween_callback(Callable(player, "_expire_constellation_absorb").bind(source_id, token))
	return normalized


static func remove_timed_absorb(player, source_id: String) -> void:
	var entry = player._constellation_absorb_sources.get(source_id, {})
	if not entry is Dictionary or (entry as Dictionary).is_empty():
		return
	var amount := float((entry as Dictionary).get("amount", 0.0))
	player._constellation_absorb_sources.erase(source_id)
	player.run_modifiers["absorb_flat"] = maxf(float(player.run_modifiers.get("absorb_flat", 0.0)) - amount, 0.0)
	player._apply_stat_scaling(false, player.max_health)


static func expire_timed_absorb(player, source_id: String, token: int) -> void:
	var entry = player._constellation_absorb_sources.get(source_id, {})
	if entry is Dictionary and int((entry as Dictionary).get("token", -1)) == token:
		remove_timed_absorb(player, source_id)


static func timed_absorb(player, source_id: String) -> float:
	var entry = player._constellation_absorb_sources.get(source_id, {})
	return float((entry as Dictionary).get("amount", 0.0)) if entry is Dictionary else 0.0


static func set_timed_dodge(player, source_id: String, amount: float, duration: float) -> float:
	if source_id == "":
		return 0.0
	var normalized := clampf(amount, 0.0, 0.30)
	var previous_entry = player._constellation_dodge_sources.get(source_id, {})
	var previous := float((previous_entry as Dictionary).get("amount", 0.0)) if previous_entry is Dictionary else 0.0
	player._constellation_dodge_token += 1
	var token: int = player._constellation_dodge_token
	player._constellation_dodge_sources[source_id] = {"amount": normalized, "token": token}
	player.run_modifiers["dodge_flat"] = maxf(float(player.run_modifiers.get("dodge_flat", 0.0)) + normalized - previous, 0.0)
	player._apply_stat_scaling(false, player.max_health)
	if duration > 0.0 and player.is_inside_tree():
		var expiry: Tween = player.create_tween()
		expiry.tween_interval(duration)
		expiry.tween_callback(Callable(player, "_expire_constellation_dodge").bind(source_id, token))
	return normalized


static func set_single_hit_ward(player, source_id: String, ratio: float, duration: float) -> float:
	if source_id == "" or duration <= 0.0:
		player._constellation_single_hit_ward.clear()
		return 0.0
	var normalized := clampf(ratio, 0.0, 0.80)
	if normalized <= 0.0:
		player._constellation_single_hit_ward.clear()
		return 0.0
	player._constellation_single_hit_ward = {
		"source_id": source_id,
		"ratio": normalized,
		"until_msec": Time.get_ticks_msec() + int(duration * 1000.0),
	}
	return normalized


static func consume_single_hit_ward(player) -> Dictionary:
	if player._constellation_single_hit_ward.is_empty():
		return {}
	var ward: Dictionary = player._constellation_single_hit_ward.duplicate(true)
	player._constellation_single_hit_ward.clear()
	if Time.get_ticks_msec() > int(ward.get("until_msec", 0)):
		return {}
	return ward


static func remove_timed_dodge(player, source_id: String) -> void:
	var entry = player._constellation_dodge_sources.get(source_id, {})
	if not entry is Dictionary or (entry as Dictionary).is_empty():
		return
	var amount := float((entry as Dictionary).get("amount", 0.0))
	player._constellation_dodge_sources.erase(source_id)
	player.run_modifiers["dodge_flat"] = maxf(float(player.run_modifiers.get("dodge_flat", 0.0)) - amount, 0.0)
	player._apply_stat_scaling(false, player.max_health)


static func expire_timed_dodge(player, source_id: String, token: int) -> void:
	var entry = player._constellation_dodge_sources.get(source_id, {})
	if entry is Dictionary and int((entry as Dictionary).get("token", -1)) == token:
		remove_timed_dodge(player, source_id)


static func constellation_weapon_geometry_multiplier(player, weapon_id_value: String) -> float:
	var result := 1.0
	for effect_key in [
		"range_or_precision_zone_mult",
		"arc_chain_or_zone_geometry_mult",
		"guard_control_zone_mult",
		"radius_or_blast_geometry_mult",
		"impact_area_mult",
	]:
		result *= constellation_weapon_multiplier(player, weapon_id_value, effect_key)
	var axis := str(constellation_weapon_profile(player, weapon_id_value).get("axis", ""))
	match axis:
		"crowd":
			result *= constellation_weapon_multiplier(player, weapon_id_value, "target_pattern_budget_mult")
			result *= constellation_weapon_multiplier(player, weapon_id_value, "hidden_crowd_mastery_mult")
		"aoe":
			result *= constellation_weapon_multiplier(player, weapon_id_value, "hidden_aoe_mastery_mult")
		"defense":
			result *= constellation_weapon_multiplier(player, weapon_id_value, "control_sustain_value_mult")
			result *= constellation_weapon_multiplier(player, weapon_id_value, "hidden_defense_mastery_mult")
	return result


static func constellation_weapon_axis_multiplier(player, weapon_id_value: String) -> float:
	var profile := constellation_weapon_profile(player, weapon_id_value)
	var axis := str(profile.get("axis", ""))
	var result := constellation_weapon_multiplier(player, weapon_id_value, "weapon_prefinal_identity_mult")
	if axis == "solo":
		result *= constellation_weapon_multiplier(player, weapon_id_value, "precision_window_mult")
		result *= constellation_weapon_multiplier(player, weapon_id_value, "hidden_solo_mastery_mult")
	return result


static func trigger_class_status_effects(player, enemy: Node2D) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var support_multiplier := float(player.derived_parameters.get("support_multiplier", 1.0))
	match player.character_id:
		"dark_mage", "elementalist":
			StatusEffects.apply_status(enemy, "arcane_vulnerability", {
				"duration": 2.6,
				"max_stacks": 2,
				"stack_mode": "add",
				"damage_taken_multiplier": 1.0 + minf(0.045 * support_multiplier, 0.075),
				"marker_color": Color(0.72, 0.42, 1.0, 1.0),
			})
		"chemist", "doctor", "assassin", "biologist":
			StatusEffects.apply_status_from(player, enemy, "toxic_debuff", {
				"duration": 2.4,
				"max_stacks": 2,
				"stack_mode": "add",
				"dot_damage": maxf(float(player.derived_parameters.get("dot_damage", 1.0)) * 0.08, 0.35),
				"dot_interval": 0.75,
				"marker_color": Color(0.45, 1.0, 0.35, 1.0),
			})
		"soldier", "knight", "robot":
			StatusEffects.apply_status(enemy, "staggered", {
				"duration": 1.4,
				"speed_multiplier": 0.90,
				"marker_color": Color(0.90, 0.88, 0.72, 1.0),
			})


## Inactive classes return before any node or group query. Druid remains on the
## same shared 0.55-second cadence as its wild and command aura effects.
static func update_class_status_auras(player) -> void:
	if player._status_aura_cooldown_left > 0.0 or not player.is_inside_tree():
		return
	var aura_bonus := wild_aura_damage_bonus(player)
	var has_command_aura: bool = player.character_id in COMMAND_AURA_CLASSES
	if aura_bonus <= 0.0 and not has_command_aura:
		return
	if aura_bonus > 0.0:
		update_wild_force_aura(player, aura_bonus)
	if not has_command_aura:
		return
	var aura_radius := clampf(float(player.derived_parameters.get("aura_radius", 160.0)) * 0.62, 120.0, 280.0)
	var support_multiplier := float(player.derived_parameters.get("support_multiplier", 1.0))
	var applied := false
	StatusEffects.apply_status(player, "class_aura_focus", {
		"duration": 0.85,
		"speed_multiplier": 1.0 + minf(0.018 * support_multiplier, 0.035),
	})
	for ally in player.get_tree().get_nodes_in_group("allies"):
		var ally_node := ally as Node2D
		if ally_node == null or not is_instance_valid(ally_node):
			continue
		if ally_node.get("owner_node") != player:
			continue
		if ally_node.global_position.distance_to(player.global_position) > aura_radius:
			continue
		StatusEffects.apply_status(ally_node, "command_aura", {
			"duration": 0.85,
			"damage_multiplier": 1.0 + minf(0.055 * support_multiplier, 0.12),
			"speed_multiplier": 1.0 + minf(0.025 * support_multiplier, 0.05),
			"marker_color": Color(0.50, 0.88, 1.0, 1.0),
		})
		applied = true
	if player.character_id in PRESSURE_AURA_CLASSES:
		for enemy_node in TARGET_QUERY.in_radius(player, player.global_position, aura_radius):
			StatusEffects.apply_status(enemy_node, "command_pressure", {
				"duration": 0.85,
				"speed_multiplier": 0.93,
				"damage_taken_multiplier": 1.0 + minf(0.018 * support_multiplier, 0.035),
				"marker_color": Color(0.42, 0.78, 1.0, 1.0),
			})
			applied = true
	if player.character_id == "priest":
		player.heal_percent(minf(0.0015 * support_multiplier, 0.004))
		applied = true
	if applied:
		AttackVfx.ring_pulse(player._vfx_parent(), player.global_position, aura_radius, Color(0.44, 0.82, 1.0, 0.20), false)
	player._status_aura_cooldown_left = STATUS_AURA_INTERVAL


static func wild_aura_damage_bonus(player) -> float:
	return ProgressionData.class_wild_aura_damage_bonus(player.character_id, float(player.derived_parameters.get("support_multiplier", 1.0)))


static func wild_aura_damage_multiplier(player) -> float:
	return 1.0 + wild_aura_damage_bonus(player)


static func wild_aura_radius(player) -> float:
	if wild_aura_damage_bonus(player) <= 0.0:
		return 0.0
	var ratio := clampf(player.class_trait_value("wild_aura_radius_ratio", 1.0), 0.1, 2.0)
	return maxf(float(player.derived_parameters.get("aura_radius", 0.0)) * ratio, 0.0)


static func update_wild_force_aura(player, aura_bonus := -1.0) -> void:
	var resolved_bonus: float = aura_bonus if aura_bonus >= 0.0 else wild_aura_damage_bonus(player)
	var ring := player.get_node_or_null(WILD_AURA_RING_NAME) as WildForceAuraRing
	if resolved_bonus <= 0.0:
		if ring != null:
			ring.queue_free()
		return
	var radius := wild_aura_radius(player)
	if ring == null:
		ring = WildForceAuraRing.new()
		ring.name = WILD_AURA_RING_NAME
		ring.z_as_relative = false
		ring.z_index = -2
		player.add_child(ring)
	ring.radius = radius
	for ally in player.get_tree().get_nodes_in_group("allies"):
		var ally_node := ally as Node2D
		if ally_node == null or not is_instance_valid(ally_node):
			continue
		if ally_node.get("owner_node") != player:
			continue
		if ally_node.global_position.distance_to(player.global_position) > radius:
			continue
		StatusEffects.apply_status(ally_node, "wild_force_aura", {
			"duration": 0.85,
			"damage_multiplier": 1.0 + resolved_bonus,
			"marker_color": WILD_AURA_COLOR,
		})
