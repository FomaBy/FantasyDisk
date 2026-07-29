class_name UltimateChargeBudget
extends RefCounted

## FAN-1460: the frozen charge-economy and power contract for the 51 weapon
## ultimates.
##
## One card fixes the numeric corridor; the 17 class mechanics packs consume the
## fixtures and never re-derive them. Like the registry foundation, the canonical
## weapon inventory and the budget model are injected by the caller, so the
## balance layer stays independent from the ProgressionData facade and no
## facade <-> balance preload cycle can appear later.
##
## Every returned Dictionary/Array is a deep copy: consumers cannot mutate the
## contract they were handed.

const EXPECTED_CLASS_COUNT := 17
const EXPECTED_ROW_COUNT := 51

const MAX_CHARGE := 100.0

const ENCOUNTER_NORMAL := "normal"
const ENCOUNTER_ELITE := "elite"
const ENCOUNTER_BOSS := "boss"

# Charge earned in a single encounter. The corridor is what a NEUTRAL build must
# land inside; the cap is the hard clamp every build is subject to, so investment
# buys "ready one encounter sooner", never "ready every round".
const NORMAL_CORRIDOR_MIN := 25.0
const NORMAL_CORRIDOR_MAX := 35.0
const ELITE_CORRIDOR_MIN := 35.0
const ELITE_CORRIDOR_MAX := 45.0
const NORMAL_ENCOUNTER_CAP := 35.0
const ELITE_ENCOUNTER_CAP := 45.0

# ceil(MAX_CHARGE / NORMAL_ENCOUNTER_CAP) == ceil(MAX_CHARGE / ELITE_ENCOUNTER_CAP)
# == 3: the caps alone guarantee the floor, no scenario has to be trusted for it.
const MIN_ENCOUNTERS_TO_READY := 3
const NEUTRAL_ENCOUNTERS_TO_READY_MAX := 4

# One charge point per CHARGE_PER_REFERENCE_SECOND seconds of the weapon's OWN
# reference output. Normalizing per weapon is what makes the corridor a single
# number for all 51 rows: a slow high-hit weapon and a fast low-hit weapon reach
# readiness at the same pace. The ledger is fed HP actually removed (the
# UltimateDamageResult.applied channel), never damage attempted, so overkill
# cannot inflate the pace either.
const CHARGE_PER_REFERENCE_SECOND := 0.95
# Mirrors ProgressionData.BALANCE_WINDOW_SECONDS — the canonical measurement
# window every other budget in the project is expressed in.
const NORMAL_ENCOUNTER_SECONDS := 30.0
const ELITE_ENCOUNTER_SECONDS := 34.0

# Taken-damage channel: losing one full health bar across an encounter is worth
# TAKEN_CHARGE_PER_HEALTH_BAR before the per-class taken_charge_rate, and the
# channel can never contribute more than its share of the encounter cap — a tank
# cannot farm readiness by standing in damage.
const TAKEN_CHARGE_PER_HEALTH_BAR := 8.0
const TAKEN_CHANNEL_ENCOUNTER_SHARE := 0.35
const NEUTRAL_NORMAL_HEALTH_BARS_LOST := 0.5
const NEUTRAL_ELITE_HEALTH_BARS_LOST := 1.0

# Build channel. The scale mirrors the shipped Player._gain_ultimate_charge, but
# it reads Energy INVESTED above the class base: the shipped formula counted base
# Energy too, which silently moved the neutral corridor by up to 7.5% between
# classes (base Energy spans 3..6). The cap is the audit answer to
# ult_charge_multiplier stacking.
const ENERGY_CHARGE_PER_POINT := 0.025
const BUILD_CHARGE_MULTIPLIER_CAP := 1.60

# Power corridor: one activation is worth POWER_SECONDS_MIN..POWER_SECONDS_MAX
# seconds of the weapon's own normal output, or an equally decisive control /
# defensive save of at least CONTROL_SAVE_MIN_SECONDS.
const POWER_SECONDS_MIN := 20.0
const POWER_SECONDS_MAX := 35.0
const POWER_ARCHETYPE_BURST := "burst"
const POWER_ARCHETYPE_CONTROL_SAVE := "control_save"
const CONTROL_SAVE_MIN_SECONDS := 4.0

# Whole-activation share of a boss health pool. Declared per class today; the
# fixtures publish it per row so a class pack can never widen it per weapon.
const BOSS_CAP_MIN := 0.05
const BOSS_CAP_MAX := 0.15
const BOSS_CAP_FALLBACK := 0.08

const MAX_ACTIVATIONS_PER_ENCOUNTER := 1


static func encounter_cap(kind: String) -> float:
	return NORMAL_ENCOUNTER_CAP if kind == ENCOUNTER_NORMAL else ELITE_ENCOUNTER_CAP


static func taken_channel_cap(kind: String) -> float:
	return encounter_cap(kind) * TAKEN_CHANNEL_ENCOUNTER_SHARE


static func encounter_seconds(kind: String) -> float:
	return NORMAL_ENCOUNTER_SECONDS if kind == ENCOUNTER_NORMAL else ELITE_ENCOUNTER_SECONDS


static func neutral_health_bars_lost(kind: String) -> float:
	return NEUTRAL_NORMAL_HEALTH_BARS_LOST if kind == ENCOUNTER_NORMAL else NEUTRAL_ELITE_HEALTH_BARS_LOST


static func corridor(kind: String) -> Vector2:
	if kind == ENCOUNTER_NORMAL:
		return Vector2(NORMAL_CORRIDOR_MIN, NORMAL_CORRIDOR_MAX)
	return Vector2(ELITE_CORRIDOR_MIN, ELITE_CORRIDOR_MAX)


## Energy is the amount INVESTED above the class base, so a neutral build is
## exactly 1.0 for every class.
static func build_multiplier(invested_energy: float, ult_charge_multiplier := 1.0) -> float:
	var raw := (1.0 + maxf(invested_energy, 0.0) * ENERGY_CHARGE_PER_POINT) * maxf(ult_charge_multiplier, 0.0)
	return clampf(raw, 1.0, BUILD_CHARGE_MULTIPLIER_CAP)


## The 51 immutable fixture rows, ordered by canonical class order and then by
## the class's own weapon order.
##
## `weapons_by_class` is the canonical inventory (ProgressionData.WEAPONS_BY_CLASS);
## `progression` is the budget model providing base_stats / weapon /
## ultimate_config / estimate_weapon_budget_for_stats.
static func build_rows(weapons_by_class: Dictionary, progression) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if progression == null:
		return rows
	var class_order := 0
	for raw_class_id in weapons_by_class.keys():
		var class_id := str(raw_class_id)
		var raw_weapons = weapons_by_class.get(raw_class_id)
		if not raw_weapons is Dictionary:
			continue
		var stats: Dictionary = progression.base_stats(class_id)
		var ultimate: Dictionary = progression.ultimate_config(class_id)
		var weapon_order := 0
		for raw_weapon_id in (raw_weapons as Dictionary).keys():
			var weapon_id := str(raw_weapon_id)
			rows.append(
				_row(class_id, class_order, weapon_id, weapon_order, stats, ultimate, progression)
			)
			weapon_order += 1
		class_order += 1
	return rows


static func row_key(class_id: String, weapon_id: String) -> String:
	return "%s/%s" % [class_id, weapon_id]


static func row_for(rows: Array, class_id: String, weapon_id: String) -> Dictionary:
	var key := row_key(class_id, weapon_id)
	for raw_row in rows:
		if raw_row is Dictionary and str((raw_row as Dictionary).get("key", "")) == key:
			return (raw_row as Dictionary).duplicate(true)
	return {}


static func _row(
	class_id: String,
	class_order: int,
	weapon_id: String,
	weapon_order: int,
	stats: Dictionary,
	ultimate: Dictionary,
	progression
) -> Dictionary:
	var config: Dictionary = progression.weapon(class_id, weapon_id)
	# include_ultimate=false: the reference output is the weapon's NORMAL output.
	# Folding the ultimate back in would make the charge rate depend on the very
	# ultimate the rate is meant to price.
	var budget: Dictionary = progression.estimate_weapon_budget_for_stats(
		class_id, config, stats, true, {}, false
	)
	var reference_dps := maxf(float(budget.get("solo_dps", 0.0)), 0.01)
	var duration := float(ultimate.get("duration", 0.0))
	var archetype := POWER_ARCHETYPE_CONTROL_SAVE if duration > 0.0 else POWER_ARCHETYPE_BURST
	return {
		"key": row_key(class_id, weapon_id),
		"class_id": class_id,
		"class_order": class_order,
		"weapon_id": weapon_id,
		"weapon_order": weapon_order,
		"reference_solo_dps": reference_dps,
		"reference_aoe_dps": maxf(float(budget.get("aoe_dps", 0.0)), 0.0),
		"reference_ehp": maxf(float(budget.get("ehp", 0.0)), 0.0),
		# Charge credited per point of HP actually removed from a target.
		"charge_per_removed_hp": CHARGE_PER_REFERENCE_SECOND / reference_dps,
		"taken_charge_rate": maxf(float(ultimate.get("taken_charge_rate", 1.0)), 0.0),
		"total_boss_cap": clampf(
			float(ultimate.get("boss_cap", BOSS_CAP_FALLBACK)), BOSS_CAP_MIN, BOSS_CAP_MAX
		),
		"power_archetype": archetype,
		"power_budget_min": reference_dps * POWER_SECONDS_MIN,
		"power_budget_max": reference_dps * POWER_SECONDS_MAX,
		"control_save_seconds": duration,
	}
