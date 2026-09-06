class_name PlayerDamagePolicy
extends RefCounted

## FAN-3920 (FD13): decision logic for incoming damage, extracted from
## Player.take_damage as a collaborator (no inheritance, no owned state).
## The Player node keeps every state field, signal, owner-event dispatch and
## effect; this policy only classifies, rolls and computes. The pipeline is
## deliberately split into small steps so the caller can interleave its
## synchronous owner-event dispatches at the exact original boundaries:
## owner-event callbacks run synchronously into the equipped weapon and may
## mutate Player state that later steps read, so no step may read state ahead
## of its original position. The single dodge randf() stays the only RNG call
## and happens at the same pipeline point as before.

const DefensiveAttributeRuntime := preload("res://scripts/defensive_attribute_runtime.gd")
const ProgressionData := preload("res://scripts/progression_data.gd")

enum Prevention {
	NONE,
	GODMODE,
	INVULNERABILITY,
	INVISIBILITY,
	KNIGHT_ULTIMATE,
}


## Gate order is behavior: godmode → i-frames → invisibility → Knight ultimate.
## Everything before the dodge roll is a fully prevented event and must not
## reset the warmup no-hit stack or grant retaliation.
static func prevention_gate(player) -> int:
	if player.debug_godmode:
		return Prevention.GODMODE
	if player._damage_invulnerability_left > 0.0:
		return Prevention.INVULNERABILITY
	if player._shadow_invisible_left > 0.0:
		return Prevention.INVISIBILITY
	if player._ultimate_active and player.character_id == "knight":
		return Prevention.KNIGHT_ULTIMATE
	return Prevention.NONE


## SCRUM-897 + SCRUM-894: the dodge roll — a single randf() against
## _current_dodge_chance (base asymptote 0.55, Thief smoke cloud bonus on top
## capped at 0.90 in smoke, Assassin veil under close pressure below the cap).
static func roll_dodge(player) -> bool:
	return randf() < player._current_dodge_chance()


## Reactor-heat amplifier on the already-countered amount (runs after the
## Knight counter passive, before the constellation ward).
static func apply_reactor_heat(player, countered_amount: float) -> float:
	if player._reactor_heat_active and float(player.run_modifiers.get("reactor_heat_incoming_damage", 0.0)) > 0.0:
		return countered_amount * (1.0 + float(player.run_modifiers.get("reactor_heat_incoming_damage", 0.0)))
	return countered_amount


## SCRUM-1068 Censer final: a ward cast owns exactly one proportional absorb.
## It is consumed before generic flat absorb and carries its source through the
## owner-event bridge, so unrelated shields cannot trigger retaliation. The
## caller emits the ward "damage_absorbed" event (if anything was absorbed)
## BEFORE calling apply_defense_and_absorb, because that event runs
## synchronously and its callback may mutate state the next step reads.
## Returns {defended_amount, ward_absorbed, ward_source}.
static func apply_ward(player, incoming_defended_amount: float) -> Dictionary:
	var defended_amount := incoming_defended_amount
	var ward: Dictionary = player.constellation_consume_single_hit_ward()
	var ward_absorbed := 0.0
	if not ward.is_empty():
		ward_absorbed = defended_amount * clampf(float(ward.get("ratio", 0.0)), 0.0, 0.80)
		defended_amount = maxf(defended_amount - ward_absorbed, 0.0)
	return {
		"defended_amount": defended_amount,
		"ward_absorbed": ward_absorbed,
		"ward_source": str(ward.get("source_id", "")),
	}


## Defense and flat absorb, read at the original point: after the ward
## damage_absorbed event. Bastion stance and the «Покров мученика» low-HP
## artifact add their bonuses to the RAW rating before the shared diminishing
## curve. Flat absorb slices the hit before defense, but after SCRUM-255 it
## always lets a noticeable share of small hits through.
## Returns {damage_after_defense, post_absorb_amount, actually_absorbed}.
static func apply_defense_and_absorb(player, defended_amount: float) -> Dictionary:
	var raw_defense := DefensiveAttributeRuntime.raw_defense_rating(player.derived_parameters)
	if player._stance_active and float(player.run_modifiers.get("bastion_defense_bonus", 0.0)) > 0.0:
		raw_defense += float(player.run_modifiers.get("bastion_defense_bonus", 0.0))
	if player._low_hp_active and float(player.run_modifiers.get("lowhp_defense_bonus", 0.0)) > 0.0:
		raw_defense += float(player.run_modifiers.get("lowhp_defense_bonus", 0.0))
	var defense := ProgressionData.effective_defense(raw_defense)
	var absorb := float(player.derived_parameters.get("absorb", 0.0))
	var absorbed_amount: float = maxf(defended_amount - absorb, defended_amount * ProgressionData.SURVIVABILITY_ABSORB_MIN_DAMAGE_FRACTION)
	var actually_absorbed := maxf(defended_amount - absorbed_amount, 0.0)
	return {
		"damage_after_defense": absorbed_amount * (1.0 - defense),
		"post_absorb_amount": absorbed_amount,
		"actually_absorbed": actually_absorbed,
	}


## Final class multipliers, read at the original point: after the flat-absorb
## damage_absorbed event and repair-subroutine charging. SCRUM-914
## «Бронекорпус» is the LAST pipeline multiplier (after block/absorb/defense;
## the dodge was rolled earlier). Data-driven from CLASS_TRAITS.robot
## (incoming_damage_multiplier 0.8: 100 post-mitigation → 80, 5 → 4); classes
## without the trait get 1.0 — no leak. The 0.5 floor guards against stacking
## future discounts into full immunity; Robot's worst total mitigation cap
## ≈ 94% < the 98% gate (global_survivability smoke). SCRUM-925
## «Молитва защиты» is the same-rank final class multiplier, mutually
## exclusive by class (Priest only, while active). Pipeline order:
## dodge → counter → reactor-heat → absorb → defense → final class discounts.
static func apply_final_multipliers(player, post_absorb_amount: float) -> float:
	var final_damage := post_absorb_amount
	final_damage *= clampf(player.class_trait_value("incoming_damage_multiplier", 1.0), 0.5, 1.0)
	if player._battle_prayer_protection > 0.0:
		final_damage *= 1.0 - clampf(player._battle_prayer_protection, 0.0, 0.9)
	return final_damage
