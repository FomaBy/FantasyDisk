class_name PlayerDamagePolicy
extends RefCounted

## FAN-3920 (FD13): decision logic for incoming damage, extracted from
## Player.take_damage as a collaborator (no inheritance, no owned state).
## The Player node keeps every state field, signal, owner-event dispatch and
## effect; this policy only classifies, rolls and computes, in the exact order
## the inline pipeline used: prevention gates → dodge roll → mitigation
## (knight counter is applied by the Player before mitigate() because it is an
## effectful weapon passive). The single dodge randf() stays the only RNG call
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


## Pure mitigation pipeline applied to the already-countered amount, in the
## original order: reactor-heat amplifier → constellation single-hit ward →
## defense (bastion/low-HP raw bonuses + curve) → flat absorb with the
## guaranteed min-damage fraction → class incoming multiplier → battle prayer.
## Consumes the ward through the Player-owned pop and returns every value the
## caller needs to emit the same owner events in the same order:
##   defended_amount   post-reactor-heat, post-counter amount
##   absorbed_amount   amount surviving flat absorb
##   actually_absorbed flat-absorb share actually eaten
##   ward              the consumed ward record ({} when none)
##   ward_absorbed     ward absorb share (0.0 when none)
##   ward_source       ward source_id ("" when none)
##   final_damage      final post-mitigation damage
static func mitigate(player, incoming_amount: float, countered_amount: float) -> Dictionary:
	var defended_amount := countered_amount
	if player._reactor_heat_active and float(player.run_modifiers.get("reactor_heat_incoming_damage", 0.0)) > 0.0:
		defended_amount *= 1.0 + float(player.run_modifiers.get("reactor_heat_incoming_damage", 0.0))
	# SCRUM-1068 Censer final: a ward cast owns exactly one proportional absorb.
	# It is consumed before generic flat absorb and carries its source through the
	# owner-event bridge, so unrelated shields cannot trigger retaliation.
	var constellation_ward: Dictionary = player.constellation_consume_single_hit_ward()
	var constellation_ward_absorbed := 0.0
	if not constellation_ward.is_empty():
		constellation_ward_absorbed = defended_amount * clampf(float(constellation_ward.get("ratio", 0.0)), 0.0, 0.80)
		defended_amount = maxf(defended_amount - constellation_ward_absorbed, 0.0)
	var raw_defense := DefensiveAttributeRuntime.raw_defense_rating(player.derived_parameters)
	if player._stance_active and float(player.run_modifiers.get("bastion_defense_bonus", 0.0)) > 0.0:
		raw_defense += float(player.run_modifiers.get("bastion_defense_bonus", 0.0))
	# SCRUM-961 «Покров мученика»: на низком HP защита временно выше по общей diminishing curve.
	if player._low_hp_active and float(player.run_modifiers.get("lowhp_defense_bonus", 0.0)) > 0.0:
		raw_defense += float(player.run_modifiers.get("lowhp_defense_bonus", 0.0))
	var defense := ProgressionData.effective_defense(raw_defense)
	# Поглощение плоско срезает часть удара до защиты, но после SCRUM-255
	# гарантированно пропускает заметную долю мелких ударов.
	var absorb := float(player.derived_parameters.get("absorb", 0.0))
	var absorbed_amount: float = maxf(defended_amount - absorb, defended_amount * ProgressionData.SURVIVABILITY_ABSORB_MIN_DAMAGE_FRACTION)
	var actually_absorbed := maxf(defended_amount - absorbed_amount, 0.0)
	var final_damage := absorbed_amount * (1.0 - defense)
	# SCRUM-914 «Бронекорпус»: классовый финальный игнор входящего урона —
	# ПОСЛЕДНИЙ множитель пайплайна (после блока/absorb/defense; dodge отроллен
	# выше). Data-driven из CLASS_TRAITS.robot (incoming_damage_multiplier 0.8:
	# 100 post-mitigation → 80, 5 → 4); классы без trait'а получают 1.0 —
	# утечки нет. Кламп-пол 0.5 страхует от стакинга будущих скидок в полный
	# иммунитет; худший суммарный кап митигации Робота ≈ 94% < гейта 98%
	# (tests/robot_kit_test.gd + global_survivability smoke).
	final_damage *= clampf(player.class_trait_value("incoming_damage_multiplier", 1.0), 0.5, 1.0)
	# SCRUM-925 «Молитва защиты»: −20% входящего финальным классовым множителем
	# того же ранга, что «Бронекорпус» (взаимоисключимы по классам: молитва —
	# только Священник и только пока активна). Порядок пайплайна:
	# уворот → контр → reactor-heat → absorb → defense → финальные классовые скидки.
	if player._battle_prayer_protection > 0.0:
		final_damage *= 1.0 - clampf(player._battle_prayer_protection, 0.0, 0.9)
	return {
		"defended_amount": defended_amount,
		"absorbed_amount": absorbed_amount,
		"actually_absorbed": actually_absorbed,
		"ward": constellation_ward,
		"ward_absorbed": constellation_ward_absorbed,
		"ward_source": str(constellation_ward.get("source_id", "")),
		"final_damage": final_damage,
	}


