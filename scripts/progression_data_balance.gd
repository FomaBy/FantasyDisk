extends RefCounted

# SCRUM-198: balance model, economy curve and drop-scaling constants. No value changes.

const CLASS_BUDGET_PROFILES := {
	"berserk": {"profile": "balanced", "survival": "sturdy", "damage_budget": 1.00, "solo_target": 1.00, "aoe_target": 1.00},
	"soldier": {"profile": "balanced", "survival": "steady", "damage_budget": 1.00, "solo_target": 1.00, "aoe_target": 1.00},
	"thief": {"profile": "balanced", "survival": "fragile", "damage_budget": 1.08, "solo_target": 1.00, "aoe_target": 1.00},
	"elementalist": {"profile": "aoe", "survival": "fragile", "damage_budget": 1.08, "solo_target": 0.95, "aoe_target": 1.10},
	"sniper": {"profile": "solo", "survival": "steady", "damage_budget": 1.00, "solo_target": 1.15, "aoe_target": 0.80},
	"priest": {"profile": "balanced", "survival": "steady", "damage_budget": 0.92, "solo_target": 0.95, "aoe_target": 1.05},
	"biologist": {"profile": "aoe", "survival": "fragile", "damage_budget": 1.08, "solo_target": 0.82, "aoe_target": 1.18},
	"robot": {"profile": "balanced", "survival": "tank", "damage_budget": 0.88, "solo_target": 0.95, "aoe_target": 1.05},
	"engineer": {"profile": "balanced", "survival": "steady", "damage_budget": 0.96, "solo_target": 0.90, "aoe_target": 1.12},
	"dark_mage": {"profile": "aoe", "survival": "fragile", "damage_budget": 1.15, "solo_target": 0.70, "aoe_target": 1.30},
	"guitarist": {"profile": "aoe", "survival": "control", "damage_budget": 1.00, "solo_target": 0.70, "aoe_target": 1.30},
	"assassin": {"profile": "solo", "survival": "fragile", "damage_budget": 1.15, "solo_target": 1.30, "aoe_target": 0.70},
	"ranger": {"profile": "solo", "survival": "fragile", "damage_budget": 1.15, "solo_target": 1.30, "aoe_target": 0.70},
	"doctor": {"profile": "balanced", "survival": "tank", "damage_budget": 0.85, "solo_target": 1.00, "aoe_target": 1.00},
	"chemist": {"profile": "aoe", "survival": "fragile", "damage_budget": 1.15, "solo_target": 0.70, "aoe_target": 1.30},
	"knight": {"profile": "balanced", "survival": "tank", "damage_budget": 0.85, "solo_target": 1.00, "aoe_target": 1.00},
	"druid": {"profile": "balanced", "survival": "steady", "damage_budget": 1.00, "solo_target": 1.00, "aoe_target": 1.00},
}

const BALANCE_BASE_SOLO_DPS := 48.0

const BALANCE_BASE_AOE_DPS := 150.0

const BALANCE_WINDOW_SECONDS := 30.0

const STAGE_SCALE_BASE := 1.18

const STAGE_SCALE_LINEAR := 0.075

const ECONOMY_PRICE_MULTIPLIER := 1.10

const XP_CURVE_MULTIPLIER := 1.42

const XP_CURVE_FLAT := 3.0

const DROP_CLASS_MULTIPLIERS := {
	"ordinary": {"xp": 1.0, "money": 1.0, "money_chance": 0.75},
	"complex": {"xp": 1.3, "money": 1.35, "money_chance": 0.85},
	"heavy": {"xp": 1.75, "money": 1.85, "money_chance": 0.95},
	"mini_elite": {"xp": 3.6, "money": 3.8, "money_chance": 1.0},
	"elite": {"xp": 8.0, "money": 8.5, "money_chance": 1.0},
	"boss": {"xp": 24.0, "money": 92.0, "money_chance": 1.0},
}

const COST_BY_TIER := {1: 30, 2: 55, 3: 95}
# Вес появления артефакта в наградах/магазине по тиру (выше тир — реже).

const TIER_WEIGHTS := {1: 1.0, 2: 0.45, 3: 0.12}
