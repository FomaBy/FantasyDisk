class_name ProgressionData
extends RefCounted

const CharacterData := preload("res://scripts/progression_data_characters.gd")
const STAT_NAMES := CharacterData.STAT_NAMES
const BASE_STATS := CharacterData.BASE_STATS
const CHARACTER_CONFIGS := CharacterData.CHARACTER_CONFIGS
const ULTIMATE_CONFIGS := CharacterData.ULTIMATE_CONFIGS
const CLASS_DAMAGE_PARAMETER := CharacterData.CLASS_DAMAGE_PARAMETER
const STAT_CLASS_RELEVANCE := CharacterData.STAT_CLASS_RELEVANCE
const CLASS_INTERPRETATIONS := CharacterData.CLASS_INTERPRETATIONS
const ATTRIBUTE_PRIORITIES := CharacterData.ATTRIBUTE_PRIORITIES
const ATTRIBUTE_PRIORITY_REASONS := CharacterData.ATTRIBUTE_PRIORITY_REASONS

const BalanceData := preload("res://scripts/progression_data_balance.gd")
const CLASS_BUDGET_PROFILES := BalanceData.CLASS_BUDGET_PROFILES
const BALANCE_BASE_SOLO_DPS := BalanceData.BALANCE_BASE_SOLO_DPS
const BALANCE_BASE_AOE_DPS := BalanceData.BALANCE_BASE_AOE_DPS
const BALANCE_WINDOW_SECONDS := BalanceData.BALANCE_WINDOW_SECONDS
const STAGE_SCALE_BASE := BalanceData.STAGE_SCALE_BASE
const STAGE_SCALE_LINEAR := BalanceData.STAGE_SCALE_LINEAR
const ECONOMY_PRICE_MULTIPLIER := BalanceData.ECONOMY_PRICE_MULTIPLIER
const XP_CURVE_MULTIPLIER := BalanceData.XP_CURVE_MULTIPLIER
const XP_CURVE_FLAT := BalanceData.XP_CURVE_FLAT
const DROP_CLASS_MULTIPLIERS := BalanceData.DROP_CLASS_MULTIPLIERS
const COST_BY_TIER := BalanceData.COST_BY_TIER
const TIER_WEIGHTS := BalanceData.TIER_WEIGHTS

const WeaponsData := preload("res://scripts/progression_data_weapons.gd")
const BERSERK_WEAPONS := WeaponsData.BERSERK_WEAPONS
const WEAPONS_BY_CLASS := WeaponsData.WEAPONS_BY_CLASS

const ContentData := preload("res://scripts/progression_data_content.gd")
const STAT_REWARDS := ContentData.STAT_REWARDS
const ARTIFACTS := ContentData.ARTIFACTS
const LEVEL_UP_REWARDS := ContentData.LEVEL_UP_REWARDS

const AscensionData := preload("res://scripts/progression_data_ascension.gd")
const ASCENSION_MODIFIERS := AscensionData.ASCENSION_MODIFIERS
const ASCENSION_DIFFICULTY_DEFAULTS := AscensionData.ASCENSION_DIFFICULTY_DEFAULTS
const ASCENSION_LEVELS := AscensionData.ASCENSION_LEVELS

const ShopData := preload("res://scripts/progression_data_shop.gd")
const SHOP_ITEMS := ShopData.SHOP_ITEMS

const EnemyData := preload("res://scripts/progression_data_enemies.gd")
const MINI_ELITE_KINDS := EnemyData.MINI_ELITE_KINDS

const MetaData := preload("res://scripts/progression_data_meta.gd")
static func mini_elite_kinds() -> Array:
	var kinds := []
	for kind in MINI_ELITE_KINDS:
		kinds.append(kind.duplicate(true))
	return kinds


static func mini_elite_kind_by_id(kind_id: String) -> Dictionary:
	for kind in MINI_ELITE_KINDS:
		if str(kind.get("id", "")) == kind_id:
			return kind.duplicate(true)
	return {}


static func shop_items(route_stage := 0) -> Array:
	var items := []
	for item in SHOP_ITEMS:
		var shop_item: Dictionary = item.duplicate(true)
		shop_item["cost"] = stage_scaled_cost(int(shop_item.get("cost", 0)), route_stage)
		items.append(shop_item)
	for artifact in ARTIFACTS:
		var shop_artifact: Dictionary = artifact.duplicate(true)
		shop_artifact["cost"] = stage_scaled_cost(int(shop_artifact.get("cost", COST_BY_TIER.get(int(shop_artifact.get("tier", 1)), 30))), route_stage)
		shop_artifact["kind"] = "artifact"
		shop_artifact["weight"] = TIER_WEIGHTS.get(int(shop_artifact.get("tier", 1)), 1.0)
		items.append(shop_artifact)
	return items


static func elite_artifact_choices(route_stage: int, count := 3) -> Array:
	var pool := []
	var scale := stage_scale(route_stage)
	for artifact in ARTIFACTS:
		var candidate: Dictionary = artifact.duplicate(true)
		var tier := int(candidate.get("tier", 1))
		var depth_weight := 1.0
		if tier == 2:
			depth_weight = 0.75 + scale * 0.25
		elif tier == 3:
			depth_weight = 0.22 + maxf(float(route_stage) - 2.0, 0.0) * 0.18
		candidate["kind"] = "artifact"
		candidate["weight"] = maxf(TIER_WEIGHTS.get(tier, 1.0) * depth_weight, 0.05)
		pool.append(candidate)
	var choices := []
	while choices.size() < count and not pool.is_empty():
		var total_weight := 0.0
		for reward in pool:
			total_weight += float(reward.get("weight", 1.0))
		var roll := randf() * maxf(total_weight, 0.001)
		var cursor := 0.0
		var selected_index := 0
		for index in range(pool.size()):
			cursor += float(pool[index].get("weight", 1.0))
			if roll <= cursor:
				selected_index = index
				break
		choices.append(pool[selected_index])
		pool.remove_at(selected_index)
	return choices


static func display_stats(stats: Dictionary) -> String:
	var parts := []
	for stat_id in STAT_NAMES.keys():
		parts.append("%s %.0f" % [STAT_NAMES[stat_id], float(stats.get(stat_id, 0.0))])
	return " | ".join(parts)


static func display_derived_parameters(parameters: Dictionary) -> String:
	return "Урон %.1f | Магия %.1f | Звук %.1f | Атаки %.2f | Крит %.0f%% | Защита %.0f%% | Дальность %.0f | Область %.0f | Подбор %.0f" % [
		float(parameters.get("damage", 0.0)),
		float(parameters.get("magic_damage", 0.0)),
		float(parameters.get("sound_wave_damage", 0.0)),
		float(parameters.get("attack_speed", 0.0)),
		float(parameters.get("crit_chance", 0.0)) * 100.0,
		float(parameters.get("defense", 0.0)) * 100.0,
		float(parameters.get("attack_range", 0.0)),
		float(parameters.get("aoe_radius", 0.0)),
		float(parameters.get("pickup_radius", 0.0)),
	]
