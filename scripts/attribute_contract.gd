class_name AttributeContract
extends RefCounted

# FAN-1887 (спека fan1883_attribute_clarity): канонический player-facing контракт
# атрибутов — view-model карточки (attribute_presentation), строгий eligibility-
# фильтр level-up пула, legacy-санитайзер сохранённых показов и чистые таблицы
# подписей/форматов осей. Данные реестра/матрицы/формул живут в ProgressionData;
# этот модуль — контракт их предъявления игроку.

# Единицы канонических осей и порог «нулевой фактической дельты» в масштабе
# отображаемой точности каждой оси.
const ATTRIBUTE_PRESENTATION_UNITS := {
	"damage_flat": "урон", "damage": "урон", "attack_speed": "атак/с",
	"max_health": "HP", "move_speed": "ед./с", "aoe_radius": "ед.",
	"pickup_radius": "ед.", "defense": "% снижения", "crit_chance": "%",
	"crit_damage": "×", "dodge": "%", "dot_damage": "урон/тик",
	"summon_amount": "сила", "regeneration": "HP/с",
	"vampiric": "HP при срабатывании", "ultimate_power": "×",
}
const ATTRIBUTE_PRESENTATION_QUANTUMS := {
	"defense": 0.005, "crit_chance": 0.005, "dodge": 0.005,
	"crit_damage": 0.005, "ultimate_power": 0.005, "attack_speed": 0.005,
	"regeneration": 0.05, "vampiric": 0.05,
}

# FAN-1927: статический список «производных для превью» удалён — блок
# «Влияет на: …» и предпросмотр докачки считаются динамически из canonical
# axis_snapshot (единый effective-value source, weapon-aware).

const DAMAGE_TYPE_PARAMETERS := ["damage", "magic_damage"]

# FAN-1927: attack_mode устройств Инженера, где player.gd возвращает max_summons
# к базе (парк считает сам кит от derived summon_amount) — run_modifiers.summon_bonus
# там не потребляется.
const ENGINEER_DEVICE_MODES := ["engineer_sentry_link", "engineer_orbit_drone"]


static func attribute_registry_entry(attr_id: String) -> Dictionary:
	for entry_value in ProgressionData.ATTRIBUTE_REGISTRY:
		if str((entry_value as Dictionary).get("id", "")) == attr_id:
			return (entry_value as Dictionary).duplicate(true)
	return {}


# FAN-1927: live-consumer правила текущего оружия. Признаки — те же, какими
# пользуется runtime (read-only oracle: player.gd/_apply_weapon_scaling,
# class_weapon.gd, summoner_weapon.gd): SummonerWeapon определяется по
# summon_roster/summon_pair_mode (его каденс живёт в summon_interval и generic
# attack_speed не читает), curse_only-кит не читает прямой damage-канал и крит,
# summon_bonus двигает парк только у «обычных» max_summons-китов.
static func weapon_is_summoner_script(weapon_config: Dictionary) -> bool:
	return weapon_config.get("summon_roster") != null or bool(weapon_config.get("summon_pair_mode", false))


static func weapon_consumes_summon_bonus(weapon_config: Dictionary) -> bool:
	if weapon_config.get("max_summons") == null:
		return false
	if bool(weapon_config.get("summon_pair_mode", false)):
		# Пара «танк + кастер» ведёт популяцию сама (summoner_weapon.gd) — +N не
		# меняет фактический счёт.
		return false
	if str(weapon_config.get("attack_mode", "")) in ENGINEER_DEVICE_MODES:
		return false
	return true


# Фактический runtime-канал урона текущего оружия (player.gd:3585-3591 читает
# weapon_config.damage_parameter с дефолтом "damage"); без weapon-контекста —
# классовый канал (legacy-вызовы без оружия).
static func weapon_damage_parameter(weapon_config: Dictionary, character_id: String) -> String:
	if weapon_config.is_empty():
		return ProgressionData.damage_parameter_for(character_id)
	if weapon_config.get("damage_parameter") == null:
		return "damage"
	return str(weapon_config.get("damage_parameter"))


# Потребляет ли ТЕКУЩЕЕ оружие ось вообще. Пустой weapon_config означает
# «нет weapon-контекста» — тогда решает только class-relevance.
static func weapon_consumes(attr_id: String, weapon_config: Dictionary) -> bool:
	if weapon_config.is_empty():
		return true
	match attr_id:
		"damage_flat":
			# curse-only кит (Проклятый череп) не вызывает _rolled_damage: плоская
			# добавка к каналам damage/magic_damage — реальный no-op.
			return not bool(weapon_config.get("curse_only", false))
		"attack_speed":
			return not weapon_is_summoner_script(weapon_config)
		"crit_chance", "crit_damage":
			return not bool(weapon_config.get("curse_only", false)) and not weapon_is_summoner_script(weapon_config)
		"summon_amount":
			return weapon_consumes_summon_bonus(weapon_config)
		_:
			return true


# Derived-параметр, чьим фактическим значением ось показывает before→after.
# Урон-оси идут по фактическому каналу ТЕКУЩЕГО ОРУЖИЯ (weapon_config.
# damage_parameter), а не по class-only хардкоду; curse-only кит потребляет
# процентный урон только через dot-пайплайн.
static func presentation_parameter_for(attr_id: String, character_id: String, weapon_config := {}) -> String:
	match attr_id:
		"damage_flat", "damage":
			if bool(weapon_config.get("curse_only", false)):
				return "dot_damage"
			return weapon_damage_parameter(weapon_config, character_id)
		"max_health":
			return "health_point"
		"crit_damage":
			return "crit_damage_multiplier"
		"vampiric":
			return "vampiric_amount"
		"ultimate_power":
			return "ultimate_multiplier"
		_:
			return attr_id


# Фактическая каденция текущего оружия в атак/с — то, что runtime реально
# потребляет из derived attack_speed (player.gd:3593-3597): интервал
# max(0.18, base_fire_interval / attack_speed). Возвращает -1.0, когда каденс
# оружия generic attack_speed не читает (SummonerWeapon / нет fire_interval).
static func weapon_attacks_per_second(weapon_config: Dictionary, attack_speed_value: float) -> float:
	if weapon_config.get("fire_interval") == null or weapon_is_summoner_script(weapon_config):
		return -1.0
	var base_interval := float(weapon_config.get("fire_interval"))
	return 1.0 / maxf(0.18, base_interval / maxf(attack_speed_value, 0.1))


# Единый exact-once слой общей каденции для периодических каналов оружия.
static func apply_weapon_cadence(weapon: Node, cadence_multiplier: float, meta_interval_multiplier := 1.0) -> void:
	var cadence := maxf(cadence_multiplier, 0.1)
	for property_id in ["pool_tick_interval", "pool_charge_tick_interval", "trap_bleed_tick_interval", "burst_interval", "amp_pulse_interval"]:
		if weapon.get(property_id) == null:
			continue
		var base_key := "base_%s" % property_id
		if not weapon.has_meta(base_key):
			weapon.set_meta(base_key, weapon.get(property_id))
		# The sentry consumes the owner's absolute attack speed in
		# SentryTurret.effective_pulse_interval(). Dividing its stored pulse here
		# as well would apply only the growth component twice.
		var property_cadence := 1.0 if property_id == "amp_pulse_interval" and str(weapon.get("attack_mode")) == "engineer_sentry_link" else cadence
		var interval := float(weapon.get_meta(base_key)) / property_cadence
		var floor := 0.1
		if property_id in ["pool_tick_interval", "amp_pulse_interval"]:
			interval *= meta_interval_multiplier
			floor = 0.08
		weapon.set(property_id, maxf(interval, floor))


# Фактический runtime-парк призывов/деплоя (player.gd:3668-3681): база +
# Лидерство/4 + summon_bonus, кап max_summons_cap (+amp_cap_bonus у amp-китов).
static func summon_runtime_count(weapon_config: Dictionary, stats: Dictionary, run_modifiers: Dictionary) -> float:
	var base := float(weapon_config.get("max_summons", 0.0))
	var count := base + floorf(float(stats.get("leadership", 0.0)) / 4.0) + floorf(float(run_modifiers.get("summon_bonus", 0.0)))
	var cap := summon_runtime_cap(weapon_config, run_modifiers)
	if cap >= 0.0:
		count = minf(count, cap)
	return count


static func summon_runtime_cap(weapon_config: Dictionary, run_modifiers: Dictionary) -> float:
	if weapon_config.get("max_summons_cap") == null or int(weapon_config.get("max_summons_cap")) <= 0:
		return -1.0
	var cap := float(int(weapon_config.get("max_summons_cap")))
	if str(weapon_config.get("attack_mode", "")) == "amp":
		cap += floorf(float(run_modifiers.get("amp_cap_bonus", 0.0)))
	return cap


# Жёсткий кап значения оси (или -1.0, если капа нет) — для availability=cap_reached.
static func _presentation_axis_cap(attr_id: String, character_id: String, stats := {}, weapon_config := {}, run_modifiers := {}) -> float:
	match attr_id:
		"crit_chance":
			var agility := float(stats.get("agility", ProgressionData.base_stats(character_id).get("agility", 0.0)))
			return float(ProgressionData.class_crit_profile(character_id, ProgressionData.ordinary_crit_chance_cap(agility)).get("cap", ProgressionData.CRIT_CHANCE_CAP))
		"dodge":
			return ProgressionData.SURVIVABILITY_DODGE_CAP
		"defense":
			return ProgressionData.SURVIVABILITY_DEFENSE_CAP
		"crit_damage":
			return -1.0
		"summon_amount":
			return summon_runtime_cap(weapon_config, run_modifiers)
		_:
			return -1.0


# Та же семантика применения модов, что у Player._apply_reward_mods: *_multiplier
# перемножается от 1.0, остальное суммируется от 0.0. Вход не мутируется.
static func _presentation_apply_mods(run_modifiers: Dictionary, mods: Dictionary) -> Dictionary:
	var merged := run_modifiers.duplicate(true)
	for key in mods.keys():
		if str(key).ends_with("_multiplier"):
			merged[key] = float(merged.get(key, 1.0)) * float(mods[key])
		else:
			merged[key] = float(merged.get(key, 0.0)) + float(mods[key])
	return merged


# Единый view-model карточки атрибута ПОСЛЕ relevance/capability/effective
# расчёта (Backend handoff спеки). before/after/delta — фактические значения
# derived_parameters после действующих diminishing/капов; availability !=
# "eligible" никогда не рисуется как выбор.
static func attribute_presentation(reward: Dictionary, character_id: String, stats: Dictionary, run_modifiers: Dictionary, weapon_config := {}) -> Dictionary:
	var attr_id := str(reward.get("attr", ""))
	var entry := attribute_registry_entry(attr_id)
	var presentation := {
		"axis_id": attr_id,
		"axis_name": str(entry.get("name", str(reward.get("title", attr_id)))),
		"unit": str(ATTRIBUTE_PRESENTATION_UNITS.get(attr_id, "")),
		"effect_sentence": str(reward.get("description", "")),
		"before": 0.0,
		"after": 0.0,
		"delta_effective": 0.0,
		"availability": "eligible",
	}
	if attr_id == "" or not ProgressionData.ATTRIBUTE_RELEVANCE.has(attr_id):
		# Стат-награды и артефакты — вне атрибутного контракта карточки.
		return presentation
	if ProgressionData.attribute_relevance(attr_id, character_id) == "optional":
		presentation["availability"] = "no_capability" if attr_id == "summon_amount" else "class_ineligible"
		return presentation
	if not weapon_consumes(attr_id, weapon_config):
		# FAN-1927: класс релевантен, но ТЕКУЩЕЕ оружие ось не потребляет
		# (curse-only канал, SummonerWeapon-каденс, pair/device-парк).
		presentation["availability"] = "no_capability"
		return presentation
	var mods: Dictionary = reward.get("mods", {}) as Dictionary
	var merged := _presentation_apply_mods(run_modifiers, mods)
	var before := 0.0
	var after := 0.0
	if attr_id == "summon_amount":
		if weapon_config.get("max_summons") != null:
			# FAN-1927: показываем и меняем фактический runtime-парк, а не сырой
			# summon_bonus — карта не обещает «+2» там, где кап уже достигнут.
			before = summon_runtime_count(weapon_config, stats, run_modifiers)
			after = summon_runtime_count(weapon_config, stats, merged)
		else:
			# Legacy-вызов без weapon-контекста: сырой модификатор.
			before = float(run_modifiers.get("summon_bonus", 0.0))
			after = float(merged.get("summon_bonus", 0.0))
	else:
		var parameter := presentation_parameter_for(attr_id, character_id, weapon_config)
		var before_params: Dictionary = ProgressionData.derived_parameters(stats, run_modifiers, weapon_config)
		var after_params: Dictionary = ProgressionData.derived_parameters(stats, merged, weapon_config)
		before = float(before_params.get(parameter, 0.0))
		after = float(after_params.get(parameter, 0.0))
		if attr_id == "attack_speed":
			# FAN-1927: показываем фактическую каденцию ТЕКУЩЕГО оружия; у
			# каденс-пола (0.18с) дельта честно нулевая и карта отсеивается.
			var before_aps := weapon_attacks_per_second(weapon_config, before)
			var after_aps := weapon_attacks_per_second(weapon_config, after)
			if before_aps >= 0.0:
				before = before_aps
				after = after_aps
		if attr_id == "vampiric":
			presentation["proc_chance_current"] = float(before_params.get("vampiric_chance", 0.0))
			presentation["proc_chance_cap"] = ProgressionData.VAMPIRIC_CHANCE_CAP
	presentation["before"] = before
	presentation["after"] = after
	presentation["delta_effective"] = after - before
	if attr_id == "damage_flat" or attr_id == "damage":
		var channel := presentation_parameter_for(attr_id, character_id, weapon_config)
		if channel in DAMAGE_TYPE_PARAMETERS:
			presentation["channel_label"] = "Магический урон" if channel == "magic_damage" else "Физический урон"
	var cap := _presentation_axis_cap(attr_id, character_id, stats, weapon_config, run_modifiers)
	if cap >= 0.0:
		presentation["current"] = before
		presentation["cap"] = cap
	# Порог «нулевой» дельты: у осей с явным квантом — он; у процентных осей без
	# кванта — относительный (множитель работает и на малых каналах, например
	# magic-канал pure-summon кита, где абсолютное значение канала невелико).
	var quantum: float
	if ATTRIBUTE_PRESENTATION_QUANTUMS.has(attr_id):
		quantum = float(ATTRIBUTE_PRESENTATION_QUANTUMS.get(attr_id))
	elif str(entry.get("value_type", "flat")) == "percent":
		quantum = maxf(0.01, absf(before) * 0.005)
	else:
		quantum = 0.5
	if absf(after - before) < quantum:
		presentation["availability"] = "cap_reached" if cap >= 0.0 and before >= cap - quantum else "zero_effective_delta"
	return presentation


# Пул level-up-карт класса ПОСЛЕ строгого фильтра. optional/weak, no_capability,
# cap_reached и zero_effective_delta отсеиваются ДО построения показа — плитки
# «слабый»/«0»/«не для вас» не существуют в ряду выбора.
static func eligible_level_up_rewards(character_id: String, stats: Dictionary, run_modifiers: Dictionary, weapon_config := {}) -> Array:
	var eligible: Array = []
	for reward in ProgressionData.level_up_rewards(character_id):
		var presentation := attribute_presentation(reward, character_id, stats, run_modifiers, weapon_config)
		if str(presentation.get("availability", "")) != "eligible":
			continue
		eligible.append(reward)
	return eligible


# Legacy-совместимость сохранений. Показ из старой версии может нести удалённые
# карты (magic_focus_up/range_up/buff_power_up/absorb_up) или оси, более не
# выдаваемые классу. Любая такая запись сбрасывает показ целиком — UI пересоберёт
# свежий по новым правилам; уже применённые legacy-ключи run_modifiers остаются
# внутренним compatibility-входом (id-agnostic Player._apply_reward_mods).
# FAN-1927: при переданном live-контексте (stats/mods/weapon) ИЗВЕСТНАЯ карта
# дополнительно перепроверяется по текущим effective-значениям, капам и
# weapon-потребителям: capped/no-op/ineligible показ сбрасывается и безопасно
# регенерируется, удалённые id не воскресают.
static func sanitize_level_up_offer(offer: Array, character_id: String, stats := {}, run_modifiers := {}, weapon_config := {}) -> Array:
	var known_by_id := {}
	for reward in ProgressionData.LEVEL_UP_REWARDS:
		known_by_id[str(reward.get("id", ""))] = reward
	var sanitized: Array = []
	for reward_value in offer:
		if not (reward_value is Dictionary):
			return []
		var reward := reward_value as Dictionary
		for modifier_id in (reward.get("mods", {}) as Dictionary).keys():
			if ProgressionData.is_removed_progression_modifier(str(modifier_id)):
				return []
		var attr := str(reward.get("attr", ""))
		if attr != "":
			var reward_id := str(reward.get("id", ""))
			if not known_by_id.has(reward_id):
				return []
			if not ProgressionData.ATTRIBUTE_RELEVANCE.has(attr) or ProgressionData.attribute_relevance(attr, character_id) == "optional":
				return []
			# Освежаем карту до актуального определения — старый сейв не может
			# показать устаревший титул/описание/моды под текущим id.
			var fresh := (known_by_id[reward_id] as Dictionary).duplicate(true)
			if not (stats as Dictionary).is_empty():
				var availability := str(attribute_presentation(fresh, character_id, stats, run_modifiers, weapon_config).get("availability", ""))
				if availability != "eligible":
					return []
			sanitized.append(fresh)
			continue
		var reward_stats: Dictionary = reward.get("stats", {}) as Dictionary
		if reward_stats.size() == 1 and not ProgressionData.is_base_stat_consumable(str(reward_stats.keys()[0]), character_id):
			return []
		sanitized.append(reward)
	return sanitized


# SCRUM-695/FAN-1887: ЕДИНАЯ (тестируемая) выборка level-up-наград (движок выдачи). СТРОГОЕ правило
# релевантности: optional-ось (нет настоящего потребителя у класса) не участвует в
# выдаче вовсе — «слабых» карт в показе не бывает. prefill — уже выбранные награды
# (например capstone «Озарение»). Пулы не мутируются (работаем на копиях).
# FAN-1031 S4 (random-floor, план §2.1-S4): КАЖДЫЙ показ гарантирует ≥1 карту, релевантную
# УРОНУ класса (reward_is_damage_relevant). Без этого слабые/дно-классы вынуждены в некоторых
# оферах брать не-урон (защита/утилита), и их random-билд-пол проседает (worst-класс v8 0.86).
# Форс — только на ПОСЛЕДНЕМ слоте и только если в regular-пуле реально есть damage-карта класса
# (иначе грациозно пропускаем). damage-релевантная карта non-optional по построению.
static func weighted_level_up_selection(regular_pool: Array, stat_pool: Array, count: int, character_id: String, rng: RandomNumberGenerator, rare_slot_chance := 0.05, prefill := []) -> Array:
	var rewards: Array = prefill.duplicate()
	# FAN-1887: строгий фильтр на входе — optional-награды класса исключены из
	# regular-пула до выборки; заполнение никогда не «доливает» их обратно.
	var reg: Array = []
	for reward in regular_pool:
		if character_id != "" and ProgressionData.reward_is_optional(reward, character_id):
			continue
		reg.append(reward)
	var stat: Array = stat_pool.duplicate()
	var damage_count := 0
	for reward in rewards:
		if ProgressionData.reward_is_damage_relevant(reward, character_id):
			damage_count += 1
	while rewards.size() < count and (not reg.is_empty() or not stat.is_empty()):
		var slots_left: int = count - rewards.size()
		# FAN-1031 S4: на последнем слоте, если урон-карты ещё нет и в regular-пуле она есть —
		# закрываем этот слот именно ей (не отдаём рарному стат-слоту, не фильтруем в не-урон).
		var must_secure_damage: bool = damage_count == 0 and slots_left <= 1 and ProgressionData._reg_has_damage_relevant(reg, character_id)
		var want_rare: bool = not stat.is_empty() and rng.randf() < rare_slot_chance
		if (want_rare or reg.is_empty()) and not must_secure_damage:
			var s_index: int = ProgressionData.weighted_level_up_index(stat, character_id, rng)
			rewards.append(stat[s_index])
			stat.remove_at(s_index)
			continue
		var candidates: Array = []
		for reward in reg:
			if must_secure_damage and not ProgressionData.reward_is_damage_relevant(reward, character_id):
				continue
			candidates.append(reward)
		if candidates.is_empty():
			candidates = reg
		if candidates.is_empty():
			break
		var picked: Dictionary = candidates[ProgressionData.weighted_level_up_index(candidates, character_id, rng)]
		reg.erase(picked)
		rewards.append(picked)
		if ProgressionData.reward_is_damage_relevant(picked, character_id):
			damage_count += 1
	return rewards


# FAN-1927: единственный canonical источник player-facing осей для ВСЕХ
# поверхностей (Level Up, Attribute Shop, Pause, Codex, Hero Select):
# id/порядок/название/единица — из ProgressionData.ATTRIBUTE_REGISTRY, без
# второго player-facing oracle (StatFormulas.PLAYER_FACING_ATTRIBUTE_ORDER
# удалён). parameters — derived-ключи, которыми ось живёт в runtime.
static func canonical_axes() -> Array:
	var axes: Array = []
	for entry_value in ProgressionData.ATTRIBUTE_REGISTRY:
		var entry := entry_value as Dictionary
		var axis_id := str(entry.get("id", ""))
		var parameters: Array = []
		if axis_id == "damage_flat" or axis_id == "damage":
			parameters = DAMAGE_TYPE_PARAMETERS.duplicate()
		else:
			parameters = [presentation_parameter_for(axis_id, "")]
		axes.append({
			"id": axis_id,
			"name": str(entry.get("name", axis_id)),
			"unit": str(ATTRIBUTE_PRESENTATION_UNITS.get(axis_id, "")),
			"value_type": str(entry.get("value_type", "flat")),
			"icon": str(entry.get("icon", axis_id)),
			"parameters": parameters,
		})
	return axes


# FAN-1927: текущее effective-значение оси для дословных поверхностей (Pause,
# Codex, Hero Select) — тот же контракт, что у карточек, но без награды.
# Урон-оси идут по фактическому каналу текущего оружия; «Увеличение урона»
# показывает набранный процент ПОСЛЕ действующих diminishing/soft-cap;
# «Сила призыва» — фактический runtime-парк.
static func axis_snapshot(axis_id: String, character_id: String, stats: Dictionary, run_modifiers: Dictionary, weapon_config := {}) -> Dictionary:
	var entry := attribute_registry_entry(axis_id)
	var parameter := presentation_parameter_for(axis_id, character_id, weapon_config)
	var snapshot := {
		"axis_id": axis_id,
		"axis_name": str(entry.get("name", axis_id)),
		"unit": str(ATTRIBUTE_PRESENTATION_UNITS.get(axis_id, "")),
		"parameter": parameter,
		"value": 0.0,
		"cap_reached": false,
		"eligible": ProgressionData.ATTRIBUTE_RELEVANCE.has(axis_id)
			and ProgressionData.attribute_relevance(axis_id, character_id) != "optional"
			and weapon_consumes(axis_id, weapon_config),
	}
	var params: Dictionary = ProgressionData.derived_parameters(stats, run_modifiers, weapon_config)
	if axis_id == "summon_amount" and weapon_config.get("max_summons") != null:
		snapshot["value"] = summon_runtime_count(weapon_config, stats, run_modifiers)
		snapshot["value_text"] = "%.0f" % float(snapshot["value"])
	elif axis_id == "damage":
		# Отношение фактического канала к каналу без забегового множителя оси.
		var neutral := run_modifiers.duplicate(true)
		neutral["damage_multiplier"] = 1.0
		var base_params: Dictionary = ProgressionData.derived_parameters(stats, neutral, weapon_config)
		var channel_now := float(params.get(parameter, 0.0))
		var channel_base := float(base_params.get(parameter, 0.0))
		snapshot["value"] = (channel_now / channel_base - 1.0) * 100.0 if channel_base > 0.0 else 0.0
		snapshot["value_text"] = "+%.0f%%" % float(snapshot["value"])
	else:
		snapshot["value"] = float(params.get(parameter, 0.0))
		if axis_id == "attack_speed":
			var aps := weapon_attacks_per_second(weapon_config, float(snapshot["value"]))
			if aps >= 0.0:
				snapshot["value"] = aps
		# Approved-обозначения досье: темповые оси с "/с", множители с "×".
		match axis_id:
			"attack_speed", "regeneration":
				snapshot["value_text"] = "%.2f/с" % float(snapshot["value"])
			"crit_damage", "ultimate_power":
				snapshot["value_text"] = "×%.2f" % float(snapshot["value"])
			_:
				snapshot["value_text"] = format_value(parameter, float(snapshot["value"]))
	if (axis_id == "damage_flat" or axis_id == "damage") and parameter in DAMAGE_TYPE_PARAMETERS:
		snapshot["channel_label"] = "Магический урон" if parameter == "magic_damage" else "Физический урон"
	if axis_id == "vampiric":
		snapshot["proc_chance_current"] = float(params.get("vampiric_chance", 0.0))
		snapshot["proc_chance_cap"] = ProgressionData.VAMPIRIC_CHANCE_CAP
	var cap := _presentation_axis_cap(axis_id, character_id, stats, weapon_config, run_modifiers)
	if cap >= 0.0:
		snapshot["cap"] = cap
		var quantum := float(ATTRIBUTE_PRESENTATION_QUANTUMS.get(axis_id, 0.5))
		var current_for_cap := float(snapshot["value"]) if axis_id == "summon_amount" else float(params.get(parameter, 0.0))
		snapshot["cap_reached"] = current_for_cap >= cap - quantum
	return snapshot


# FAN-1927: снапшоты всех осей класса в canonical-порядке реестра; ineligible
# оси (optional класс / нет weapon-потребителя) отфильтрованы — они не
# показываются «этому герою» как доступные.
static func class_axes_snapshot(character_id: String, stats: Dictionary, run_modifiers: Dictionary, weapon_config := {}) -> Array:
	var snapshots: Array = []
	for axis in canonical_axes():
		var snapshot := axis_snapshot(str((axis as Dictionary).get("id", "")), character_id, stats, run_modifiers, weapon_config)
		if bool(snapshot.get("eligible", false)):
			snapshots.append(snapshot)
	return snapshots


# FAN-1927: канонические оси как chip-entries досье паузы — id/название/
# единица/значение из axis_snapshot (weapon-aware канал урона, фактический
# runtime-парк призывов, кап-состояние без CTA). Ineligible оси (optional
# класс / нет weapon-потребителя) не показываются «этому герою».
static func axis_chip_entries(character_id: String, stats: Dictionary, run_modifiers: Dictionary, weapon_config: Dictionary) -> Dictionary:
	var result := {}
	var axes_by_id := {}
	for axis_value in canonical_axes():
		axes_by_id[str((axis_value as Dictionary).get("id", ""))] = axis_value
	for snapshot_value in class_axes_snapshot(character_id, stats, run_modifiers, weapon_config):
		var snapshot := snapshot_value as Dictionary
		var axis_id := str(snapshot.get("axis_id", ""))
		var axis: Dictionary = axes_by_id.get(axis_id, {})
		var value_text := str(snapshot.get("value_text", ""))
		if bool(snapshot.get("cap_reached", false)):
			value_text += " (макс.)"
		var description_lines := PackedStringArray()
		if snapshot.has("channel_label"):
			description_lines.append("Канал: %s." % str(snapshot.get("channel_label", "")))
		if snapshot.has("cap"):
			description_lines.append("Максимум: %s." % format_value(str(snapshot.get("parameter", axis_id)), float(snapshot.get("cap", 0.0))))
		if snapshot.has("proc_chance_current"):
			description_lines.append("Шанс срабатывания: сейчас %s · максимум %s." % [
				format_value("vampiric_chance", float(snapshot.get("proc_chance_current", 0.0))),
				format_value("vampiric_chance", float(snapshot.get("proc_chance_cap", 0.0))),
			])
		result[axis_id] = {
			"id": axis_id,
			"name_ru": str(snapshot.get("axis_name", axis_id)),
			"type": "derived",
			"value": snapshot.get("value", 0.0),
			"value_text": value_text,
			"unit": str(snapshot.get("unit", "")),
			"icon_id": str(axis.get("icon", axis_id)),
			"description": " ".join(description_lines),
			"formula": "",
			"influences": "",
		}
	return result


# RU-подпись производного параметра для карточек/превью (артефактные превью
# продолжают подписывать и внутренние параметры).
static func parameter_label(parameter_id: String) -> String:
	match parameter_id:
		"damage":
			return "Урон"
		"magic_damage":
			return "Маг. урон"
		"attack_speed":
			return "Скорость атаки"
		"health_point":
			return "Максимальное здоровье"
		"move_speed":
			return "Скорость движения"
		"dodge":
			return "Уклонение"
		"aoe_radius":
			return "Увеличение области атаки"
		"pickup_radius":
			return "Радиус подбора"
		"defense":
			return "Защита"
		"crit_chance":
			return "Шанс крита"
		"crit_damage_multiplier":
			return "Сила крита"
		"knockback_power":
			return "Отталкивание"
		"dot_damage":
			return "Периодический урон"
		"dot_speed":
			return "Скорость тиков"
		"summon_amount":
			return "Сила призыва"
		"absorb":
			return "Поглощение"
		"regeneration":
			return "Регенерация"
		"vampiric_amount":
			return "Вампиризм"
		"vampiric_chance":
			return "Шанс вампиризма"
		"ultimate_multiplier":
			return "Сила ультимейта"
		_:
			return parameter_id


static func format_value(parameter_id: String, value: float) -> String:
	if parameter_id in ["crit_chance", "defense", "dodge", "vampiric_chance"]:
		return "%.0f%%" % (value * 100.0)
	if parameter_id in ["attack_speed", "crit_damage_multiplier", "dot_speed", "ultimate_multiplier", "regeneration", "vampiric_amount"]:
		return "%.2f" % value
	return "%.0f" % value
