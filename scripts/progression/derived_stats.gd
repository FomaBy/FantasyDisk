extends RefCounted

# FAN-3924 (FD17, program:agent-ready-refactor): pure derived-stat formulas
# extracted from ProgressionData. The facade resolves class data and passes it
# through `context`; this module never preloads ProgressionData, so the runtime
# dependency stays one-way and the model can be characterized independently.
#
# Context keys:
#   character_id                  class id used for the Druid support branch
#   base_stats                    class base values for positive growth scaling
#   class_stat_growth_scalars     scalar or per-stat dictionary
#   magic_bonus_effectiveness     Elementalist magic-delta effectiveness
#   pickup_radius_multiplier      Thief starting pickup-radius multiplier
#   generic_sustain_blocked       class gate for passive regeneration
#   crit_profile                  resolved cap/diminish/overflow profile
#   trait_config                  fallback source for crit_profile in direct use

const BalanceData := preload("res://scripts/progression_data_balance.gd")
const DefensiveAttributeRuntime := preload("res://scripts/defensive_attribute_runtime.gd")

const SURVIVABILITY_DEFENSE_DIMINISH := BalanceData.SURVIVABILITY_DEFENSE_DIMINISH
const SURVIVABILITY_DODGE_DIMINISH := BalanceData.SURVIVABILITY_DODGE_DIMINISH
const SURVIVABILITY_ABSORB_FLAT_DIMINISH := BalanceData.SURVIVABILITY_ABSORB_FLAT_DIMINISH
const SURVIVABILITY_REGEN_FLAT_MULTIPLIER := BalanceData.SURVIVABILITY_REGEN_FLAT_MULTIPLIER
const VAMPIRIC_CHANCE_CAP := BalanceData.VAMPIRIC_CHANCE_CAP
const VAMPIRIC_HEAL_CAP_HARD := BalanceData.VAMPIRIC_HEAL_CAP_HARD
const CRIT_CHANCE_CAP := BalanceData.CRIT_CHANCE_CAP
const CRIT_CHANCE_CAP_MAX := BalanceData.CRIT_CHANCE_CAP_MAX
const CRIT_CHANCE_CAP_AGILITY_SCALE := BalanceData.CRIT_CHANCE_CAP_AGILITY_SCALE
const CRIT_CHANCE_DIMINISH := BalanceData.CRIT_CHANCE_DIMINISH
const CRIT_FLAT_EFFECTIVENESS := BalanceData.CRIT_FLAT_EFFECTIVENESS
const CRIT_DAMAGE_BASE_MULTIPLIER := BalanceData.CRIT_DAMAGE_BASE_MULTIPLIER
const CRIT_DAMAGE_AGILITY_SCALE := BalanceData.CRIT_DAMAGE_AGILITY_SCALE
const CRIT_DAMAGE_FLAT_EFFECTIVENESS := BalanceData.CRIT_DAMAGE_FLAT_EFFECTIVENESS
const CRIT_DAMAGE_CAP := BalanceData.CRIT_DAMAGE_CAP
const RUN_DAMAGE_MULT_SOFTCAP := BalanceData.RUN_DAMAGE_MULT_SOFTCAP
const RUN_DAMAGE_MULT_KNEE := BalanceData.RUN_DAMAGE_MULT_KNEE
const RUN_ATTACK_SPEED_MULT_SOFTCAP := BalanceData.RUN_ATTACK_SPEED_MULT_SOFTCAP
const RUN_ATTACK_SPEED_MULT_KNEE := BalanceData.RUN_ATTACK_SPEED_MULT_KNEE


# SCRUM-503: diminishing returns на ЗАБЕГОВЫЙ боевой множитель. Сжимает ТОЛЬКО
# избыток множителя над 1.0 по кривой excess/(1+excess*knee), клампит избыток к
# (softcap-1.0) и возвращает 1.0 + сжатый_избыток. Тождественно при multiplier
# <= 1.0 (excess<=0 → возвращает сам множитель): при пустых run_modifiers
# (estimate_weapon_budget) и на базе lvl1 cap нейтрален, поэтому формульные гейты
# и стартовые числа не меняются — нерф строго «сверху базы». Понижение множителя
# (<1.0, напр. замедление атаки оружием) проходит без сжатия.
static func _soft_capped_run_multiplier(multiplier: float, softcap: float, knee: float) -> float:
	if multiplier <= 1.0:
		return multiplier
	var excess := multiplier - 1.0
	var softened := excess / (1.0 + excess * knee)
	return 1.0 + clampf(softened, 0.0, maxf(softcap - 1.0, 0.0))


# Усиливает БОНУСНУЮ часть множителя: 1.15 → 1.0 + 0.15*effectiveness. Штрафы
# (multiplier <= 1.0) проходят без изменения — trait усиливает бонусы, не дебаффы.
static func _amplified_bonus_multiplier(multiplier: float, effectiveness: float) -> float:
	if effectiveness == 1.0 or multiplier <= 1.0:
		return multiplier
	return 1.0 + (multiplier - 1.0) * effectiveness


static func _class_stat_growth_scalar(growth_scalars: Variant, stat_id: String) -> float:
	if growth_scalars is Dictionary:
		return float((growth_scalars as Dictionary).get(stat_id, 1.0))
	return float(growth_scalars)


static func _scaled_stat_growth(growth_scalars: Variant, stat_id: String, value: float, base_stats_map: Dictionary) -> float:
	var base_value := float(base_stats_map.get(stat_id, value))
	var delta := value - base_value
	if delta <= 0.0:
		return value
	return base_value + delta * _class_stat_growth_scalar(growth_scalars, stat_id)


static func effective_defense(raw_defense: float) -> float:
	return DefensiveAttributeRuntime.effective_defense(raw_defense)


static func effective_dodge(raw_dodge: float) -> float:
	return DefensiveAttributeRuntime.effective_dodge(raw_dodge)


static func raw_defense_for_effective(effective_defense_value: float) -> float:
	return DefensiveAttributeRuntime.raw_defense_for_effective(effective_defense_value)


static func raw_dodge_for_effective(effective_dodge_value: float) -> float:
	return DefensiveAttributeRuntime.raw_dodge_for_effective(effective_dodge_value)


static func effective_absorb(endurance: float, flat_absorb: float) -> float:
	return DefensiveAttributeRuntime.effective_absorb(endurance, flat_absorb)


static func effective_regeneration(knowledge: float, flat_regeneration: float) -> float:
	return DefensiveAttributeRuntime.effective_regeneration(knowledge, flat_regeneration)


# SCRUM-900 «Клятва чумного доктора»: реген класса с generic_sustain_blocked =
# только дельта от явно применённых flat'ов (base-константа+knowledge отрезаны).
# Для остальных классов — прежняя формула без изменений.
static func _class_gated_regeneration(generic_sustain_blocked: bool, knowledge: float, flat_regeneration: float) -> float:
	if not generic_sustain_blocked:
		return effective_regeneration(knowledge, flat_regeneration)
	return maxf(effective_regeneration(knowledge, flat_regeneration) - effective_regeneration(knowledge, 0.0), 0.0)


static func effective_vampiric_chance(raw_chance: float) -> float:
	return DefensiveAttributeRuntime.effective_vampiric_chance(raw_chance)


static func effective_vampiric_amount(knowledge: float, flat_amount: float) -> float:
	return DefensiveAttributeRuntime.effective_vampiric_amount(knowledge, flat_amount)


static func effective_vampiric_cap(raw_cap: float) -> float:
	return DefensiveAttributeRuntime.effective_vampiric_cap(raw_cap)


# SCRUM-894: кап/diminish параметризованы под class trait «Хладнокровие».
static func effective_crit_chance(raw_chance: float, cap := CRIT_CHANCE_CAP, diminish := CRIT_CHANCE_DIMINISH) -> float:
	var raw := maxf(raw_chance, 0.0)
	var softened := raw / (1.0 + raw * maxf(diminish, 0.0))
	return clampf(softened, 0.0, clampf(cap, 0.0, 1.0))


static func ordinary_crit_chance_cap(agility: float) -> float:
	return clampf(CRIT_CHANCE_CAP + maxf(agility, 0.0) * CRIT_CHANCE_CAP_AGILITY_SCALE, CRIT_CHANCE_CAP, CRIT_CHANCE_CAP_MAX)


static func effective_crit_damage_multiplier(agility: float, flat_bonus: float) -> float:
	var positive_flat := maxf(flat_bonus, 0.0) * CRIT_DAMAGE_FLAT_EFFECTIVENESS
	var negative_flat := minf(flat_bonus, 0.0)
	var raw := CRIT_DAMAGE_BASE_MULTIPLIER + maxf(agility, 0.0) * CRIT_DAMAGE_AGILITY_SCALE + positive_flat + negative_flat
	if raw <= CRIT_DAMAGE_CAP:
		return maxf(raw, 1.0)
	return CRIT_DAMAGE_CAP + sqrt(raw - CRIT_DAMAGE_CAP)


static func _fallback_crit_profile(trait_config: Dictionary, agility: float) -> Dictionary:
	var ordinary_cap := ordinary_crit_chance_cap(agility)
	return {
		"cap": clampf(float(trait_config.get("crit_chance_cap", ordinary_cap)), 0.0, 1.0),
		"diminish": maxf(float(trait_config.get("crit_chance_diminish", CRIT_CHANCE_DIMINISH)), 0.0),
		"overflow": clampf(float(trait_config.get("crit_overflow_to_crit_damage", 0.0)), 0.0, 1.0),
	}


static func derived_parameters(stats: Dictionary, run_modifiers: Dictionary, weapon_config: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	var character_id := str(context.get("character_id", weapon_config.get("character_id", "")))
	var base_for_growth: Dictionary = context.get("base_stats", {}) as Dictionary
	var growth_scalars: Variant = context.get("class_stat_growth_scalars", 1.0)
	var trait_config: Dictionary = context.get("trait_config", {}) as Dictionary
	var generic_sustain_blocked := bool(context.get("generic_sustain_blocked", false))
	var magic_bonus_effectiveness := maxf(float(context.get("magic_bonus_effectiveness", 1.0)), 1.0)
	var pickup_radius_trait_multiplier := maxf(float(context.get("pickup_radius_multiplier", 1.0)), 1.0)

	var strength := float(stats.get("strength", 0.0))
	var agility := float(stats.get("agility", 0.0))
	var intelligence := float(stats.get("intelligence", 0.0))
	var perception := float(stats.get("perception", 0.0))
	var energy := float(stats.get("energy", 0.0))
	var knowledge := float(stats.get("knowledge", 0.0))
	var endurance := float(stats.get("endurance", 0.0))
	var leadership := float(stats.get("leadership", 0.0))
	if character_id != "":
		strength = _scaled_stat_growth(growth_scalars, "strength", strength, base_for_growth)
		agility = _scaled_stat_growth(growth_scalars, "agility", agility, base_for_growth)
		intelligence = _scaled_stat_growth(growth_scalars, "intelligence", intelligence, base_for_growth)
		perception = _scaled_stat_growth(growth_scalars, "perception", perception, base_for_growth)
		energy = _scaled_stat_growth(growth_scalars, "energy", energy, base_for_growth)
		knowledge = _scaled_stat_growth(growth_scalars, "knowledge", knowledge, base_for_growth)
		endurance = _scaled_stat_growth(growth_scalars, "endurance", endurance, base_for_growth)
		leadership = _scaled_stat_growth(growth_scalars, "leadership", leadership, base_for_growth)
	var weapon_damage_multiplier := float(weapon_config.get("damage_multiplier", 1.0)) * float(weapon_config.get("budget_damage_multiplier", 1.0))
	var passive_mods: Dictionary = weapon_config.get("passive_mods", {})

	# upgrade_*_exponent (>1 у молота) усиливает рост именно от апгрейдов забега,
	# не трогая пассивы оружия и стартовые значения.
	var upgrade_damage_exponent := float(weapon_config.get("upgrade_damage_exponent", 1.0))
	var upgrade_aoe_exponent := float(weapon_config.get("upgrade_aoe_exponent", 1.0))
	# SCRUM-503: diminishing returns на ЗАБЕГОВУЮ часть боевых множителей (до экспоненты
	# апгрейда и до пассивов оружия) — гасит мультипликативный runaway идеального билда.
	# Тождественно при множителе 1.0 (пустые run_modifiers формульного гейта) → база и
	# формульные коридоры не меняются. Пассивы оружия (passive_mods) НЕ капятся — это база.
	var run_damage_multiplier := _soft_capped_run_multiplier(float(run_modifiers.get("damage_multiplier", 1.0)), RUN_DAMAGE_MULT_SOFTCAP, RUN_DAMAGE_MULT_KNEE)
	var run_magic_damage_multiplier := _soft_capped_run_multiplier(float(run_modifiers.get("magic_damage_multiplier", 1.0)), RUN_DAMAGE_MULT_SOFTCAP, RUN_DAMAGE_MULT_KNEE)
	var run_attack_speed_multiplier := _soft_capped_run_multiplier(float(run_modifiers.get("attack_speed_multiplier", 1.0)), RUN_ATTACK_SPEED_MULT_SOFTCAP, RUN_ATTACK_SPEED_MULT_KNEE)
	# SCRUM-947 «Проводник стихий»: magic-tagged бонусы Элементалиста на 30%
	# эффективнее. Каждый источник усиливается ровно один раз здесь.
	run_magic_damage_multiplier = _amplified_bonus_multiplier(run_magic_damage_multiplier, magic_bonus_effectiveness)
	var damage_multiplier := pow(run_damage_multiplier, upgrade_damage_exponent) * float(passive_mods.get("damage_multiplier", 1.0))
	var magic_damage_multiplier := pow(run_magic_damage_multiplier, upgrade_damage_exponent) * _amplified_bonus_multiplier(float(passive_mods.get("magic_damage_multiplier", 1.0)), magic_bonus_effectiveness)
	# SCRUM-961 «Четки молитвы»: открывающий бафф первых секунд боя усиливает
	# магический канал (prayer_opening_active ставит player.on_battle_start).
	magic_damage_multiplier *= 1.0 + float(run_modifiers.get("prayer_opening_power", 0.0)) * float(run_modifiers.get("prayer_opening_active", 0.0)) * magic_bonus_effectiveness
	var kill_momentum_attack_speed_bonus := clampf(float(run_modifiers.get("kill_momentum_attack_speed_bonus", 0.0)), 0.0, 0.12)
	var kill_momentum_crit_damage_bonus := clampf(float(run_modifiers.get("kill_momentum_crit_damage_bonus", 0.0)), 0.0, 0.09)
	# SCRUM-961 «Багровая рукоять»: стаки ярости за melee-удары — пишет player
	# ._refresh_rage_hit_modifiers по образцу kill_momentum; капы = пик 5 стаков.
	var rage_hit_damage_bonus := clampf(float(run_modifiers.get("rage_hit_damage_bonus", 0.0)), 0.0, 0.10)
	var rage_hit_attack_speed_bonus := clampf(float(run_modifiers.get("rage_hit_attack_speed_bonus", 0.0)), 0.0, 0.075)
	damage_multiplier *= 1.0 + rage_hit_damage_bonus
	# «Кровавый Рубеж» (tier 3): бонус урона активен, пока HP ниже порога (low_hp_active ставит player).
	damage_multiplier *= 1.0 + float(run_modifiers.get("low_hp_damage_bonus", 0.0)) * float(run_modifiers.get("low_hp_active", 0.0))
	# SCRUM-834 (Мета 4.1): условные keystone — бонус урона по типу условия.
	damage_multiplier *= 1.0 \
		+ float(run_modifiers.get("hurt_damage_bonus", 0.0)) * float(run_modifiers.get("hurt_active", 0.0)) \
		+ float(run_modifiers.get("stance_damage_bonus", 0.0)) * float(run_modifiers.get("stance_active", 0.0)) \
		+ float(run_modifiers.get("rush_damage_bonus", 0.0)) * float(run_modifiers.get("rush_window_active", 0.0)) \
		+ float(run_modifiers.get("swarm_damage_bonus", 0.0)) * float(run_modifiers.get("swarm_fraction", 0.0))
	var attack_speed_multiplier := run_attack_speed_multiplier * float(passive_mods.get("attack_speed_multiplier", 1.0))
	attack_speed_multiplier *= 1.0 + kill_momentum_attack_speed_bonus
	attack_speed_multiplier *= 1.0 + rage_hit_attack_speed_bonus
	# SCRUM-834a: условный keystone «стойка → скорострельность» (soldier «Шквал»).
	attack_speed_multiplier *= 1.0 + float(run_modifiers.get("stance_attack_speed_bonus", 0.0)) * float(run_modifiers.get("stance_active", 0.0))
	# SCRUM-961 «Медиатор овердрайва»: темп-бонус активной рифф-серии.
	attack_speed_multiplier *= 1.0 + float(run_modifiers.get("riff_streak_attack_speed_bonus", 0.0)) * float(run_modifiers.get("riff_streak_active", 0.0))
	# SCRUM-976: sandbox — final exact layer, intentionally outside release
	# softcaps/exponents so 0.5/2.0 remain exact and do not retune canonical data.
	var sandbox_damage_multiplier := clampf(float(run_modifiers.get("sandbox_player_damage_multiplier", 1.0)), 0.5, 2.0)
	attack_speed_multiplier *= clampf(float(run_modifiers.get("sandbox_player_attack_speed_multiplier", 1.0)), 0.5, 2.0)
	var move_speed_multiplier := float(run_modifiers.get("move_speed_multiplier", 1.0)) * float(passive_mods.get("move_speed_multiplier", 1.0))
	# «Призрачный Шаг» (tier 3): рывок скорости после уворота.
	move_speed_multiplier *= 1.0 + float(run_modifiers.get("dodge_rush_bonus", 0.0)) * float(run_modifiers.get("dodge_rush_active", 0.0))
	# SCRUM-500 «Импульс Крита»: короткий рывок скорости по криту.
	move_speed_multiplier *= 1.0 + float(run_modifiers.get("crit_speed_burst", 0.0)) * float(run_modifiers.get("crit_speed_burst_active", 0.0))
	# SCRUM-894 «Рывок темпа»: короткий бафф скорости+уворота после серии Теневых
	# кинжалов (flurry_tempo_active ставит Player.trigger_flurry_tempo).
	var flurry_tempo_active := clampf(float(run_modifiers.get("flurry_tempo_active", 0.0)), 0.0, 1.0)
	move_speed_multiplier *= 1.0 + clampf(float(run_modifiers.get("flurry_tempo_speed_bonus", 0.0)), 0.0, 0.25) * flurry_tempo_active
	var max_health_multiplier := float(run_modifiers.get("max_health_multiplier", 1.0)) * float(passive_mods.get("max_health_multiplier", 1.0))
	var aoe_radius_multiplier := pow(float(run_modifiers.get("aoe_radius_multiplier", 1.0)), upgrade_aoe_exponent) * float(passive_mods.get("aoe_radius_multiplier", 1.0))
	var knockback_multiplier := float(run_modifiers.get("knockback_multiplier", 1.0)) * float(passive_mods.get("knockback_multiplier", 1.0))
	var defense_flat := float(run_modifiers.get("defense_flat", 0.0)) + float(passive_mods.get("defense_flat", 0.0))
	var absorb_flat := float(run_modifiers.get("absorb_flat", 0.0)) + float(passive_mods.get("absorb_flat", 0.0))
	var regeneration_flat := float(run_modifiers.get("regeneration_flat", 0.0)) + float(passive_mods.get("regeneration_flat", 0.0))
	var pickup_radius_flat := float(run_modifiers.get("pickup_radius_flat", 0.0)) + float(passive_mods.get("pickup_radius_flat", 0.0))
	var max_health_flat := float(run_modifiers.get("max_health_flat", 0.0)) + float(passive_mods.get("max_health_flat", 0.0))
	var run_dot_damage_flat := float(run_modifiers.get("dot_damage_flat", 0.0))
	var dot_damage_flat := run_dot_damage_flat + float(passive_mods.get("dot_damage_flat", 0.0))
	# SCRUM-834a: условный keystone «рывок → крит-шанс» (thief «Из тени»).
	var crit_chance_flat := (float(run_modifiers.get("crit_chance_flat", 0.0)) + float(run_modifiers.get("rush_crit_bonus", 0.0)) * float(run_modifiers.get("rush_window_active", 0.0)) + float(passive_mods.get("crit_chance_flat", 0.0))) * CRIT_FLAT_EFFECTIVENESS
	var crit_damage_flat := float(run_modifiers.get("crit_damage_flat", 0.0)) + kill_momentum_crit_damage_bonus + float(passive_mods.get("crit_damage_flat", 0.0))
	if passive_mods.has("crit_damage_multiplier"):
		crit_damage_flat += float(passive_mods.get("crit_damage_multiplier", 1.0)) - 1.0
	# SCRUM-894 «Хладнокровие»: per-class крит-профиль. Direct model callers
	# may pass trait_config instead of a pre-resolved profile.
	var crit_profile: Dictionary = context.get("crit_profile", {}) as Dictionary
	if crit_profile.is_empty():
		crit_profile = _fallback_crit_profile(trait_config, agility)
	var crit_chance_raw := 0.04 + agility * 0.0075 + crit_chance_flat
	var crit_overflow_ratio := float(crit_profile.get("overflow", 0.0))
	if crit_overflow_ratio > 0.0:
		crit_damage_flat += maxf(crit_chance_raw - float(crit_profile.get("cap", CRIT_CHANCE_CAP)), 0.0) * crit_overflow_ratio
	# SCRUM-524: урон каждого ТИПА масштабируется ТОЛЬКО от своего атрибута.
	var universal_damage_flat := float(run_modifiers.get("damage_flat", 0.0))
	var physical_base := 15.0 * strength / 10.0
	# SCRUM-947: атрибутный источник магического бонуса — дельта интеллекта НАД
	# базой класса (после growth-скаляра) на 30% эффективнее для Элементалиста.
	var magic_intelligence := intelligence
	if magic_bonus_effectiveness != 1.0 and not base_for_growth.is_empty():
		var base_intelligence := float(base_for_growth.get("intelligence", intelligence))
		var intelligence_delta := intelligence - base_intelligence
		# A below-base value is a penalty and passes through unchanged.
		if intelligence_delta > 0.0:
			magic_intelligence = base_intelligence + intelligence_delta * magic_bonus_effectiveness
	var magic_base := 14.0 * magic_intelligence / 10.0
	var universal_attack_stat := agility + energy * 0.18 + perception * 0.10 + endurance * 0.04
	var attack_speed := maxf(0.1, (9.0 * 3.0 * universal_attack_stat / 100.0) * attack_speed_multiplier)
	var base_attack_stat := universal_attack_stat
	if not base_for_growth.is_empty():
		base_attack_stat = float(base_for_growth.get("agility", agility)) + float(base_for_growth.get("energy", energy)) * 0.18 + float(base_for_growth.get("perception", perception)) * 0.10 + float(base_for_growth.get("endurance", endurance)) * 0.04
	var base_attack_speed := maxf(9.0 * 3.0 * base_attack_stat / 100.0, 0.1)
	var attack_cadence_multiplier := maxf(attack_speed / base_attack_speed, 0.1)
	var dot_attribute_base := 4.0 + knowledge * 0.65 + dot_damage_flat
	var base_dot_speed := maxf(0.45, 0.65 + knowledge * 0.08 + energy * 0.015 + agility * 0.010)
	var radius_perception := perception
	var radius_intelligence := intelligence
	var radius_knowledge := knowledge
	var radius_leadership := leadership
	if bool(weapon_config.get("geometry_stat_growth_from_delta", false)) and not base_for_growth.is_empty():
		radius_perception = maxf(0.0, perception - float(base_for_growth.get("perception", 0.0)))
		radius_intelligence = maxf(0.0, intelligence - float(base_for_growth.get("intelligence", 0.0)))
		radius_knowledge = maxf(0.0, knowledge - float(base_for_growth.get("knowledge", 0.0)))
		radius_leadership = maxf(0.0, leadership - float(base_for_growth.get("leadership", 0.0)))
	var aoe_intelligence_weight := float(weapon_config.get("aoe_radius_intelligence_weight", 0.45))
	var base_area := maxf(float(weapon_config.get("aoe_radius", 190.0)), 1.0)
	var attack_area_multiplier := (base_area + radius_perception * 3.5 + radius_intelligence * aoe_intelligence_weight + radius_knowledge * 0.35 + radius_leadership * 0.30) * aoe_radius_multiplier / base_area
	var aura_radius := base_area * attack_area_multiplier
	# Support effects derive at one aggregation point. Druid's existing summon
	# support inputs live here too, so Player and summons cannot scale them twice.
	var support_multiplier := maxf(run_damage_multiplier, 0.0)
	if character_id == "druid":
		support_multiplier = 1.0 + leadership * 0.025 + float(stats.get("knowledge", 0.0)) * 0.006 + float(stats.get("energy", 0.0)) * 0.004
		# Друид считает свой радиус ауры от собственных support-атрибутов, но общий
		# множитель области применяется ровно один раз — как и у остальной геометрии.
		aura_radius = (base_area + leadership * 5.0 + float(stats.get("perception", 0.0)) * 0.80 + float(stats.get("energy", 0.0)) * 0.65 + float(stats.get("knowledge", 0.0)) * 0.45) * aoe_radius_multiplier
	var raw_dodge := 0.02 + agility * 0.010 + float(run_modifiers.get("dodge_flat", 0.0)) + clampf(float(run_modifiers.get("flurry_tempo_dodge_bonus", 0.0)), 0.0, 0.20) * flurry_tempo_active
	var raw_defense := 0.04 + endurance * 0.018 + defense_flat

	return {
		"damage": (physical_base * weapon_damage_multiplier * damage_multiplier + universal_damage_flat) * sandbox_damage_multiplier,
		"magic_damage": (magic_base * weapon_damage_multiplier * damage_multiplier * magic_damage_multiplier + universal_damage_flat) * sandbox_damage_multiplier,
		"attack_speed": attack_speed,
		"attack_cadence_multiplier": attack_cadence_multiplier,
		"crit_chance": effective_crit_chance(crit_chance_raw, float(crit_profile.get("cap", CRIT_CHANCE_CAP)), float(crit_profile.get("diminish", CRIT_CHANCE_DIMINISH))),
		"crit_damage_multiplier": effective_crit_damage_multiplier(agility, crit_damage_flat),
		"move_speed": (282.0 + agility * 6.2) * move_speed_multiplier,
		"raw_dodge": raw_dodge,
		"dodge": effective_dodge(raw_dodge),
		"raw_defense": raw_defense,
		"defense": effective_defense(raw_defense),
		"health_point": (50.0 * endurance / 4.0 + max_health_flat) * max_health_multiplier,
		"attack_range": float(weapon_config.get("attack_range", 240.0)),
		"attack_area_multiplier": attack_area_multiplier,
		"aoe_radius": base_area * attack_area_multiplier,
		# SCRUM-897 «Воровская хватка»: стартовая часть радиуса подбора усилена
		# trait-множителем (у Вора ×1.85); flat-добавки — поверх без усиления.
		"pickup_radius": (105.0 + perception * 7.0) * pickup_radius_trait_multiplier + pickup_radius_flat,
		"dot_damage": max(1.0, dot_attribute_base * damage_multiplier) * sandbox_damage_multiplier,
		"dot_speed": base_dot_speed * attack_cadence_multiplier,
		"projectile_speed": float(weapon_config.get("projectile_speed", 460.0)),
		"aura_radius": aura_radius,
		"support_multiplier": support_multiplier,
		"knockback_power": (float(weapon_config.get("knockback", 60.0)) + strength * 4.0) * knockback_multiplier,
		"summon_amount": leadership + knowledge * 0.18 + intelligence * 0.12 + energy * 0.10,
		# SCRUM-546: профильное (growth-масштабированное) Лидерство как драйвер силы
		# саммонов — читается runtime deploy/sentry-пайплайном и саммон-профилем.
		"leadership": leadership,
		# Подключение полного набора атрибутов (аудит 2026-06-11):
		"absorb": effective_absorb(endurance, absorb_flat),
		# SCRUM-900 «Клятва чумного доктора»: при generic_sustain_blocked базовый
		# пассивный реген (константа 0.16 + скейл knowledge) отрезан — остаётся
		# только вклад явно применённых flat'ов.
		"regeneration": _class_gated_regeneration(generic_sustain_blocked, knowledge, regeneration_flat),
		"vampiric_chance": effective_vampiric_chance(float(run_modifiers.get("vampiric_chance_flat", 0.0))),
		"vampiric_amount": effective_vampiric_amount(knowledge, float(run_modifiers.get("vampiric_amount_flat", 0.0))),
		# Усиливает классовую ульту: урон, радиус, длительность или число целей.
		"ultimate_multiplier": 1.0 + energy * 0.02 + (strength + agility + intelligence + perception + knowledge + endurance + leadership) * 0.002 + float(run_modifiers.get("ultimate_flat", 0.0)),
	}
