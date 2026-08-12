extends RefCounted

# FAN-2287: защитный runtime (защита, уворот, поглощение, реген, вампиризм),
# вынесенный из progression_data.gd и player.gd под line-ratchet. Формулы, кривые и
# порядок вызовов не меняются: BalanceData остаётся единственным владельцем констант,
# а ProgressionData re-экспортирует каждую публичную точку делегатором.

const BalanceData := preload("res://scripts/progression_data_balance.gd")


static func _diminishing_percent(raw_value: float, curve: float) -> float:
	var raw := maxf(raw_value, 0.0)
	return raw / (1.0 + raw * maxf(curve, 0.0001))


static func effective_defense(raw_defense: float) -> float:
	return _diminishing_percent(raw_defense, BalanceData.SURVIVABILITY_DEFENSE_DIMINISH)


static func effective_dodge(raw_dodge: float) -> float:
	return _diminishing_percent(raw_dodge, BalanceData.SURVIVABILITY_DODGE_DIMINISH)


static func raw_defense_for_effective(effective_defense_value: float) -> float:
	return _raw_rating_for_effective_percent(effective_defense_value, BalanceData.SURVIVABILITY_DEFENSE_DIMINISH)


static func raw_dodge_for_effective(effective_dodge_value: float) -> float:
	return _raw_rating_for_effective_percent(effective_dodge_value, BalanceData.SURVIVABILITY_DODGE_DIMINISH)


static func _raw_rating_for_effective_percent(effective_value: float, curve: float) -> float:
	var effective := maxf(effective_value, 0.0)
	var denominator := 1.0 - effective * maxf(curve, 0.0001)
	return effective / maxf(denominator, 0.000001)


# Player складывает бонусы стойки/низкого HP/завесы в СЫРОЙ рейтинг до кривой,
# поэтому берёт raw_* из derived_parameters. Словари, собранные до FAN-2284,
# несут только эффективный процент — для них кривая обращается.
static func raw_defense_rating(derived_parameters: Dictionary) -> float:
	return _raw_rating(derived_parameters, "raw_defense", "defense", BalanceData.SURVIVABILITY_DEFENSE_DIMINISH)


static func raw_dodge_rating(derived_parameters: Dictionary) -> float:
	return _raw_rating(derived_parameters, "raw_dodge", "dodge", BalanceData.SURVIVABILITY_DODGE_DIMINISH)


static func _raw_rating(derived_parameters: Dictionary, raw_key: String, effective_key: String, curve: float) -> float:
	if derived_parameters.has(raw_key):
		return float(derived_parameters.get(raw_key, 0.0))
	return _raw_rating_for_effective_percent(float(derived_parameters.get(effective_key, 0.0)), curve)


static func effective_absorb(endurance: float, flat_absorb: float) -> float:
	var base_absorb := maxf(endurance, 0.0) * 0.145  # SCRUM-526: 0.16→0.145, поджать базовый absorb стойкости (танк остаётся крепче fragile)
	var positive_flat := maxf(flat_absorb, 0.0)
	var negative_flat := minf(flat_absorb, 0.0)
	var softened_flat := positive_flat / (1.0 + positive_flat * BalanceData.SURVIVABILITY_ABSORB_FLAT_DIMINISH)
	return maxf(0.0, base_absorb + softened_flat + negative_flat)


static func effective_regeneration(knowledge: float, flat_regeneration: float) -> float:
	var positive_flat := maxf(flat_regeneration, 0.0) * BalanceData.SURVIVABILITY_REGEN_FLAT_MULTIPLIER
	var negative_flat := minf(flat_regeneration, 0.0)
	var regen_base := maxf(0.0, 0.16 + positive_flat + negative_flat)  # SCRUM-526: база реген 0.22→0.16
	var knowledge_scale := 0.45 + maxf(knowledge, 0.0) / 12.0
	return regen_base * knowledge_scale


static func effective_vampiric_chance(raw_chance: float) -> float:
	return clampf(raw_chance, 0.0, BalanceData.VAMPIRIC_CHANCE_CAP)


# FAN-2286: вампиризм-лечение масштабируется Знанием, как и регенерация
# (см. effective_regeneration). Berserk's стартовое Knowledge=4 сохраняет прежний
# 0.48x baseline; выше 1,5 работает неограниченный убывающий хвост.
static func effective_vampiric_amount(knowledge: float, flat_amount: float) -> float:
	var raw := maxf(flat_amount, 0.0) * (0.40 + maxf(knowledge, 0.0) / 50.0)
	var negative_flat := minf(flat_amount, 0.0)
	if raw <= 1.5:
		return maxf(raw + negative_flat, 0.0)
	return maxf(1.5 + sqrt(raw - 1.5) + negative_flat, 0.0)


static func effective_vampiric_cap(raw_cap: float) -> float:
	return clampf(raw_cap, 0.0, BalanceData.VAMPIRIC_HEAL_CAP_HARD)
