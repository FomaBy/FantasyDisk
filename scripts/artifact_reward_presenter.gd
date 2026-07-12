class_name ArtifactRewardPresenter
extends RefCounted

# SCRUM-991: pure presentation model for elite/chest/boss artifact cards.
# It reuses LevelUpAdvisor's dry-run and ProgressionData formulas, then applies
# stricter artifact rules: only one unique positive winner gets an axis badge;
# ties and effects outside the derived-parameter model are left unbadged.

const LevelUpAdvisorRef := preload("res://scripts/level_up_advisor.gd")
const ProgressionDataRef := preload("res://scripts/progression_data.gd")

const BADGE_DAMAGE := "Лучший урон"
const BADGE_SURVIVAL := "Лучшая выживаемость"
const MIN_GAIN := 0.001
const TIE_EPSILON := 0.000001
# Longest canonical artifact condition is currently 125 chars. Keep the whole
# condition/cooldown visible instead of clipping the mechanically decisive tail.
const MAX_VISIBLE_DESCRIPTION := 132


static func build_offer_presentations(
		rewards: Array,
		character_id: String,
		stats: Dictionary,
		run_modifiers: Dictionary,
		weapon_config := {}) -> Array:
	var effective_rewards: Array = []
	var forecasts: Array = []
	for reward_raw in rewards:
		var reward := reward_raw as Dictionary
		var effective := _effective_reward_for_class(reward, character_id)
		effective_rewards.append(effective)
		forecasts.append(LevelUpAdvisorRef.forecast_reward(effective, stats, run_modifiers, weapon_config))

	var damage_winner := _unique_positive_winner(forecasts, "dps_before", "dps_after")
	var survival_winner := _unique_positive_winner(forecasts, "surv_before", "surv_after")
	var result: Array = []
	for index in range(rewards.size()):
		var badge_labels := PackedStringArray()
		if index == damage_winner:
			badge_labels.append(BADGE_DAMAGE)
		if index == survival_winner:
			badge_labels.append(BADGE_SURVIVAL)
		result.append(_presentation(
			rewards[index] as Dictionary,
			character_id,
			forecasts[index] as Dictionary,
			badge_labels
		))
	return result


# Standalone card construction is used by tooltips/tests. In that context the
# card reports which axes it improves, without claiming that it beat an offer
# set. Real three-card screens always call build_offer_presentations() above.
static func build_single_presentation(
		reward: Dictionary,
		character_id: String,
		stats: Dictionary,
		run_modifiers: Dictionary,
		weapon_config := {}) -> Dictionary:
	var effective := _effective_reward_for_class(reward, character_id)
	var forecast := LevelUpAdvisorRef.forecast_reward(effective, stats, run_modifiers, weapon_config)
	var badge_labels := PackedStringArray()
	if _positive_gain(forecast, "dps_before", "dps_after") > MIN_GAIN:
		badge_labels.append(BADGE_DAMAGE)
	if _positive_gain(forecast, "surv_before", "surv_after") > MIN_GAIN:
		badge_labels.append(BADGE_SURVIVAL)
	return _presentation(reward, character_id, forecast, badge_labels)


static func _presentation(
		reward: Dictionary,
		character_id: String,
		forecast: Dictionary,
		badge_labels: PackedStringArray) -> Dictionary:
	return {
		"resolved_effect": _resolved_effect_text(reward, character_id, forecast),
		"badge_labels": badge_labels,
		"badge_text": " · ".join(badge_labels),
		"forecast": forecast,
	}


static func _resolved_effect_text(reward: Dictionary, character_id: String, forecast: Dictionary) -> String:
	var class_title := str(ProgressionDataRef.character_config(character_id).get("title", character_id))
	var lines := PackedStringArray()
	lines.append("Для %s:" % class_title)
	var deltas: Array = forecast.get("deltas", []) as Array
	for index in range(mini(deltas.size(), 2)):
		lines.append(LevelUpAdvisorRef.delta_line(deltas[index] as Dictionary))

	var description := str(reward.get("description", "")).strip_edges()
	var sustain_blocked := _sustain_is_blocked_for_class(reward, character_id)
	if sustain_blocked and not _has_effective_payload(_effective_reward_for_class(reward, character_id)):
		# Do not repeat source copy that promises healing the class trait rejects.
		lines.append("Внешнее лечение заблокировано клятвой Доктора; бонус не применяется.")
	else:
		# The derived forecast is intentionally finite. Preserve the canonical source
		# effect as well so mixed rewards never lose an unmodelled proc, condition,
		# bonus or penalty when their first one/two numeric deltas are available.
		var compact := _compact_description(description)
		if compact != "":
			lines.append(compact)
		if sustain_blocked:
			lines.append("Внешнее лечение из артефакта заблокировано клятвой Доктора.")
	if lines.size() == 1:
		lines.append("Эффект применится к текущему классу без сравнимой числовой дельты.")
	return "\n".join(lines)


static func _compact_description(description: String) -> String:
	if description.length() <= MAX_VISIBLE_DESCRIPTION:
		return description
	var clipped := description.left(MAX_VISIBLE_DESCRIPTION).strip_edges()
	var last_space := clipped.rfind(" ")
	if last_space >= int(MAX_VISIBLE_DESCRIPTION * 0.72):
		clipped = clipped.left(last_space)
	return "%s…" % clipped.strip_edges()


static func _unique_positive_winner(forecasts: Array, before_key: String, after_key: String) -> int:
	var best_gain := MIN_GAIN
	var winners: Array[int] = []
	for index in range(forecasts.size()):
		var gain := _positive_gain(forecasts[index] as Dictionary, before_key, after_key)
		if gain > best_gain + TIE_EPSILON:
			best_gain = gain
			winners = [index]
		elif gain > MIN_GAIN and absf(gain - best_gain) <= TIE_EPSILON:
			winners.append(index)
	return winners[0] if winners.size() == 1 else -1


static func _positive_gain(forecast: Dictionary, before_key: String, after_key: String) -> float:
	var before := float(forecast.get(before_key, 0.0))
	var after := float(forecast.get(after_key, before))
	return (after - before) / maxf(absf(before), 0.001)


static func _effective_reward_for_class(reward: Dictionary, character_id: String) -> Dictionary:
	var effective := reward.duplicate(true)
	if not ProgressionDataRef.class_blocks_generic_sustain(character_id) or bool(reward.get("doctor_friendly", false)):
		return effective
	for mods_key in ["mods", "affinity_mods"]:
		if not effective.has(mods_key):
			continue
		var filtered := (effective.get(mods_key, {}) as Dictionary).duplicate(true)
		for modifier_id in filtered.keys():
			if ProgressionDataRef.is_blocked_sustain_mod_key(str(modifier_id)):
				filtered.erase(modifier_id)
		effective[mods_key] = filtered
	effective.erase("heal_percent")
	return effective


static func _sustain_is_blocked_for_class(reward: Dictionary, character_id: String) -> bool:
	if not ProgressionDataRef.class_blocks_generic_sustain(character_id) or bool(reward.get("doctor_friendly", false)):
		return false
	if reward.has("heal_percent"):
		return true
	for mods_key in ["mods", "affinity_mods"]:
		var mods := reward.get(mods_key, {}) as Dictionary
		for modifier_id in mods.keys():
			if ProgressionDataRef.is_blocked_sustain_mod_key(str(modifier_id)):
				return true
	return false


static func _has_effective_payload(effective_reward: Dictionary) -> bool:
	if not (effective_reward.get("stats", {}) as Dictionary).is_empty():
		return true
	for mods_key in ["mods", "affinity_mods"]:
		if not (effective_reward.get(mods_key, {}) as Dictionary).is_empty():
			return true
	return false
