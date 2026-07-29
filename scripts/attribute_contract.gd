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

# SCRUM-525/FAN-1887: производные, на которые влияет базовая характеристика
# (для блока «Влияет на: …» в тултипах докачки) — только канонические
# player-facing оси; внутренние параметры в превью не попадают.
const STAT_DERIVED_PREVIEW := {
	"strength": ["damage"],
	"intelligence": ["magic_damage"],
	"perception": ["aoe_radius", "pickup_radius"],
	"energy": ["ultimate_multiplier", "attack_speed"],
	"knowledge": ["dot_damage", "regeneration"],
	"agility": ["attack_speed", "crit_chance", "move_speed", "dodge"],
	"endurance": ["health_point", "defense"],
	"leadership": ["summon_amount"],
}

const DAMAGE_TYPE_PARAMETERS := ["damage", "magic_damage"]


static func attribute_registry_entry(attr_id: String) -> Dictionary:
	for entry_value in ProgressionData.ATTRIBUTE_REGISTRY:
		if str((entry_value as Dictionary).get("id", "")) == attr_id:
			return (entry_value as Dictionary).duplicate(true)
	return {}


# Derived-параметр, чьим фактическим значением ось показывает before→after.
# Урон-оси идут по фактическому каналу класса (damage_parameter_for), а не по
# грубому class-only хардкоду карточки.
static func presentation_parameter_for(attr_id: String, character_id: String) -> String:
	match attr_id:
		"damage_flat", "damage":
			return ProgressionData.damage_parameter_for(character_id)
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


# Жёсткий кап значения оси (или -1.0, если капа нет) — для availability=cap_reached.
static func _presentation_axis_cap(attr_id: String, character_id: String) -> float:
	match attr_id:
		"crit_chance":
			return float(ProgressionData.class_crit_profile(character_id).get("cap", ProgressionData.CRIT_CHANCE_CAP))
		"dodge":
			return ProgressionData.SURVIVABILITY_DODGE_CAP
		"defense":
			return ProgressionData.SURVIVABILITY_DEFENSE_CAP
		"crit_damage":
			return ProgressionData.CRIT_DAMAGE_CAP
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
	var mods: Dictionary = reward.get("mods", {}) as Dictionary
	var merged := _presentation_apply_mods(run_modifiers, mods)
	var before := 0.0
	var after := 0.0
	if attr_id == "summon_amount":
		# Ось «Сила призыва» живёт в run_modifiers.summon_bonus (потребители —
		# лимиты/темп призывов и deploy-устройств), derived-слой её не отражает.
		before = float(run_modifiers.get("summon_bonus", 0.0))
		after = float(merged.get("summon_bonus", 0.0))
	else:
		var parameter := presentation_parameter_for(attr_id, character_id)
		var before_params: Dictionary = ProgressionData.derived_parameters(stats, run_modifiers, weapon_config)
		var after_params: Dictionary = ProgressionData.derived_parameters(stats, merged, weapon_config)
		before = float(before_params.get(parameter, 0.0))
		after = float(after_params.get(parameter, 0.0))
		if attr_id == "vampiric":
			presentation["proc_chance_current"] = float(before_params.get("vampiric_chance", 0.0))
			presentation["proc_chance_cap"] = ProgressionData.VAMPIRIC_CHANCE_CAP
	presentation["before"] = before
	presentation["after"] = after
	presentation["delta_effective"] = after - before
	if attr_id == "damage_flat" or attr_id == "damage":
		presentation["channel_label"] = "Магический урон" if ProgressionData.damage_parameter_for(character_id) == "magic_damage" else "Физический урон"
	var cap := _presentation_axis_cap(attr_id, character_id)
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
static func sanitize_level_up_offer(offer: Array, character_id: String) -> Array:
	var known_by_id := {}
	for reward in ProgressionData.LEVEL_UP_REWARDS:
		known_by_id[str(reward.get("id", ""))] = reward
	var sanitized: Array = []
	for reward_value in offer:
		if not (reward_value is Dictionary):
			return []
		var reward := reward_value as Dictionary
		var attr := str(reward.get("attr", ""))
		if attr != "":
			var reward_id := str(reward.get("id", ""))
			if not known_by_id.has(reward_id):
				return []
			if not ProgressionData.ATTRIBUTE_RELEVANCE.has(attr) or ProgressionData.attribute_relevance(attr, character_id) == "optional":
				return []
			# Освежаем карту до актуального определения — старый сейв не может
			# показать устаревший титул/описание/моды под текущим id.
			sanitized.append((known_by_id[reward_id] as Dictionary).duplicate(true))
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
		"attack_range":
			return "Дальность"
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
		"projectile_speed":
			return "Скорость снарядов"
		"aura_radius":
			return "Радиус ауры"
		"buff_power":
			return "Сила баффов"
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
	if parameter_id in ["attack_speed", "crit_damage_multiplier", "dot_speed", "buff_power", "ultimate_multiplier", "regeneration", "vampiric_amount"]:
		return "%.2f" % value
	return "%.0f" % value
