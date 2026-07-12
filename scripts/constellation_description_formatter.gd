class_name ConstellationDescriptionFormatter
extends RefCounted

# SCRUM-1091: one fail-closed, data-driven Russian dossier contract for every
# schema-6 class node. Runtime mechanics and balance numbers remain owned by the
# schema manifest; this module only turns that authoritative data into exact,
# auditable player-facing copy.

const AXIS_RU := {
	"solo": "одиночная цель и босс",
	"aoe": "урон по области",
	"crowd": "контроль толпы",
	"defense": "защита и выживаемость",
	"primary_attribute": "основная характеристика класса",
}

const ATTRIBUTE_RU := {
	"strength": "Сила", "agility": "Ловкость", "intelligence": "Интеллект",
	"perception": "Восприятие", "energy": "Энергия", "knowledge": "Знание",
	"endurance": "Выносливость", "leadership": "Лидерство",
}

const FAILURE_TEXT := "Описание недоступно: контракт данных этого узла повреждён. Покупка заблокирована."

const EFFECT_RU := {
	"weapon_damage_flat": "базовый урон оружия",
	"weapon_attack_speed_mult": "множитель темпа атак",
	"range_or_precision_zone_mult": "дальность и точная зона поражения",
	"precision_window_mult": "окно точного попадания",
	"target_pattern_budget_mult": "эффективность схемы выбора целей",
	"arc_chain_or_zone_geometry_mult": "геометрия дуги, цепи или зоны",
	"guard_control_zone_mult": "защитная зона контроля",
	"control_sustain_value_mult": "длительность и ценность контроля",
	"radius_or_blast_geometry_mult": "радиус и геометрия взрыва",
	"impact_area_mult": "площадь удара",
	"weapon_prefinal_identity_mult": "ключевой боевой приём оружия",
	"hidden_solo_mastery_mult": "тайное мастерство против одиночной цели",
	"hidden_defense_mastery_mult": "тайное защитное мастерство",
	"hidden_crowd_mastery_mult": "тайное мастерство контроля толпы",
	"hidden_aoe_mastery_mult": "тайное мастерство урона по области",
}

const PREFINAL_IDENTITY_RU := {
	"long narrow committed sweep and durable-target execute": "длинный узкий замах с обязательством и добиванием стойкой цели",
	"broad close cleave and follow-through": "широкий ближний раскол с внешним продолжением дуги",
	"close danger-zone slam, stagger and delayed ground crack": "удар в опасной ближней зоне с оглушением и отложенной трещиной",
	"rapid explosive shot and suppression": "быстрый взрывной выстрел с подавлением",
	"slow fuse nuke with falloff": "медленный фитильный взрыв со спадом от центра",
	"close brace, knockback and conditional rear shot": "ближняя стойка, отбрасывание и условный ответный выстрел",
	"unique-target ricochet and capped economy tempo": "рикошет по разным целям с ограниченным темпом добычи",
	"non-teleport positional backstab and paralysis": "позиционный удар в спину без телепортации с параличом",
	"blind control zone and dodge window": "ослепляющая зона контроля с окном уклонения",
	"four-step orbit cycle around a risky caster": "цикл четырёх стихий вокруг уязвимого заклинателя",
	"full-map crossing rift geometry": "перекрёстная геометрия разлома через всю карту",
	"long setup impact, shards and burning crater": "долгая подготовка удара, осколки и горящий кратер",
	"telegraphed durable-target lockshot": "телеграфируемая фиксация стойкой одиночной цели",
	"persistent priority kill-zone and precision beams": "постоянная приоритетная зона поражения с точными лучами",
	"deterministic split trajectories and pierce": "детерминированное расщепление траекторий с пробитием",
	"sanctify mark with damage and heal payoff": "метка освящения с совместной отдачей уроном и лечением",
	"close protective ward pulses": "ближние защитные волны обета",
	"enemy chain that returns sustain to the owner": "цепь по врагам, возвращающая поддержку владельцу",
	"expanding rings and secondary blooms": "расширяющиеся кольца со вторичными цветениями",
	"direct sample and delayed analysis ramp": "прямой образец с отложенным нарастающим анализом",
	"capped damage-sharing web": "ограниченная сеть разделения урона",
	"pull and grouped-target setup": "притяжение и подготовка сгруппированных целей",
	"edge-to-axis line compression": "сжатие линии от края к оси",
	"four directional vent cycle": "цикл четырёх направленных выбросов",
	"owned turret with marked-target overclock": "своя турель с разгоном по отмеченной цели",
	"owner repair tether and capped excess shield": "ремонтная связь владельца с ограниченным щитом избытка",
	"spaced triggers and capped chain detonation": "разнесённые триггеры с ограниченной цепной детонацией",
	"mirrored blasts and midpoint geometry": "зеркальные взрывы с геометрией схлопывания середины",
	"curse-only burn and death spread": "проклятый ожог без прямого урона с переносом после смерти",
	"pierce chain with void decay": "цепь пробитий с затухающим эхом Бездны",
	"directed riff strip and streak": "направленная полоса риффа с поддержанием серии",
	"rhythmic close control pulse": "ритмический ближний импульс контроля",
	"placed stage pulse that echoes the active instrument": "сценический импульс, повторяющий активный инструмент",
	"boomerang outward and return paths": "расходящийся и возвратный пути бумеранга",
	"close crit flurry and brief shadow safety": "ближняя критическая серия с короткой теневой защитой",
	"capped poison ramp and garrote snap": "ограниченное нарастание яда с разрядом удавки",
	"fully charged precision pierce": "полностью заряженное точное пробитие",
	"charged fan and deterministic storm branch": "заряженный веер с детерминированной грозовой ветвью",
	"owned trigger zone and prey mark": "своя зона срабатывания с меткой добычи",
	"drain recovery and capped overheal protection": "восстановление от вытягивания с ограниченной защитой перелечения",
	"infection ramp and capped spread": "нарастание инфекции с ограниченным переносом",
	"close wound stacks and capped execute drain": "ближние заряды ран с ограниченным лечащим добиванием",
	"reagent burst and cross-reagent combo": "всплеск реагента с комбинацией разных реагентов",
	"persistent corrosive pool and stack detonation": "стойкая едкая лужа с детонацией зарядов",
	"single tank-control summon and intercept": "единственный защитный призыв с перехватом",
	"long brace line and counter thrust": "длинная линия стойки с контрвыпадом",
	"timed block that stores capped incoming force": "своевременный блок с ограниченным запасом входящей силы",
	"orbit-return swing and holy control pulse": "орбитально-возвратный замах со святым импульсом контроля",
	"commanded beast pack with pounce and guard": "управляемая стая со скачком и защитой владельца",
	"persistent thorn denial and delayed root": "стойкое терновое перекрытие с отложенным укоренением",
	"support totem pulse and commanded raven strike": "импульс тотема с командным ударом ворона",
}

# Each final has its own trigger/payoff sentence. Exact caps stay data-driven
# below, so changing the manifest cannot leave a believable but stale number.
const FINAL_MECHANIC_RU := {
	"sword_repeat_execute": "Три последовательных попадания по одной стойкой цели открывают усиленное окно добивания.",
	"axe_outer_followthrough": "После основного взмаха внешняя дуга один раз ищет врагов, которых первый взмах не задел.",
	"hammer_stagger_aftershock": "Ближний удар оглушает и выпускает одну отложенную трещину-последействие.",
	"rifle_suppression_mark": "Повторные попадания из аркебузы накладывают подавление и снижают исходящий урон цели.",
	"grenade_shrapnel_second_wave": "Взрыв фитиля выпускает одну отложенную ограниченную волну осколков.",
	"bayonet_brace_countershot": "Успешное отбрасывание из стойки выпускает один контрвыстрел сквозь линию цели.",
	"coin_unique_target_return": "После серии рикошетов по разным целям монета один раз возвращается сквозь первую цель.",
	"dagger_backstab_execute_mark": "Настоящий удар в спину ставит метку для одного ограниченного добивания.",
	"smoke_dodge_triggered_burst": "Первое успешное уклонение внутри каждой дымовой зоны вызывает одну волну контроля.",
	"orb_four_element_resonance": "Полный цикл четырёх разных стихий выпускает один импульс резонанса.",
	"prism_intersection_rift": "Пересечение лучей оставляет короткий удерживающий разлом с ограниченными тиками.",
	"meteor_shard_recall": "После появления кратера уцелевшие осколки один раз возвращаются к его центру.",
	"deadeye_weakpoint_cycle": "Полная фиксация открывает одну уязвимость, которую расходует следующий выстрел.",
	"spotter_highest_hp_priority": "Зона наведения резервирует один луч для отмеченной цели с наибольшим здоровьем.",
	"shatter_extra_pierce_falloff": "Каждый осколок получает дополнительное пробитие со строгим ослаблением повторных попаданий.",
	"reliquary_mark_expiry_burst": "Завершение освящения или смерть отмеченной цели выпускает одну волну лечения и урона.",
	"censer_absorb_retaliation": "Каждая волна обета поглощает один ограниченный удар и отвечает импульсом возмездия.",
	"chime_owner_return_shield": "После обхода разных врагов молитва возвращается к владельцу ограниченным щитом.",
	"spore_final_ring_blooms": "Финальное кольцо выращивает малые цветения на ограниченном числе разных врагов.",
	"injector_sample_analysis_ramp": "Повторные образцы на одной цели усиливают анализ до заданного предела.",
	"symbiote_link_transfer": "Связанные враги делят ограниченную долю урона, а связь переносится после смерти носителя.",
	"anchor_next_heavy_hit_setup": "Притянутая цель получает якорную метку для одного усиленного тяжёлого удара.",
	"press_axis_second_jaw": "Сжатие от края коридора вызывает вторую, более узкую челюсть пресса.",
	"reactor_vent_cycle_pulse": "Полный цикл направленных выбросов выпускает один отталкивающий импульс реактора.",
	"sentry_marked_target_overclock": "Турель разгоняется против одной отмеченной стойкой цели до предела нагрева.",
	"drone_excess_repair_shield": "Избыточный ремонт по связи владельца превращается в короткий ограниченный щит.",
	"mine_adjacency_chain": "Сработавшая мина поджигает соседнюю свою мину и продолжает ограниченную цепь.",
	"book_mirror_midpoint_collapse": "После разрешения двух зеркальных взрывов их середина один раз схлопывается.",
	"skull_death_curse_transfer": "Смерть проклятой цели переносит сокращённое проклятие на ближайших врагов.",
	"wand_pierce_decay_echo": "Повторные пробития одной отмеченной цели выпускают одно ослабленное эхо Бездны.",
	"guitar_riff_harmony_lane": "Непрерывная серия риффов добавляет одну параллельную дорожку гармонии.",
	"bass_every_nth_stagger": "Каждый четвёртый импульс баса превращается в усиленный ограниченный удар с оглушением.",
	"amp_instrument_echo": "Единственный усилитель повторяет ослабленный рисунок текущего инструмента без рекурсии.",
	"chakram_return_execute_mark": "Прямой пролёт ставит метку, а возврат чакрама расходует её на усиленное добивание.",
	"dagger_execute_shadow_window": "Ближнее добивание даёт короткое, не складывающееся окно теневого уклонения.",
	"wire_poison_ramp_snap": "Яд на одной связанной цели нарастает до предела и один раз разряжается без лечения.",
	"crossbow_full_charge_mark": "Полностью заряженное пробитие ставит одну лунную метку для следующего выстрела.",
	"longbow_outer_storm_branch": "Два крайних луча веера один раз ветвятся к разным ближайшим врагам.",
	"trap_prey_mark_distribution": "Пойманная цель становится добычей и делит часть попаданий с соседними пленниками.",
	"potion_overheal_absorb_pool": "Избыточное лечение только этим оружием превращается в короткий запас поглощения.",
	"syringe_infection_threshold_spread": "Инфекция на пороге переносит сокращённую копию на разных ближайших врагов.",
	"saw_wound_execute_heal": "Ближние удары пилой копят раны; добивание расходует их на лечение только этого оружия.",
	"powder_cross_reagent_combo": "Следующий другой реагент в облаке пороха вызывает единственную комбинированную реакцию.",
	"acid_stack_detonation": "Цель на пределе коррозии вызывает одну ослабленную детонацию кислотной лужи.",
	"homunculus_intercept_death_burst": "Свой гомункул перехватывает один тяжёлый удар и единожды взрывается при смерти.",
	"spear_block_counter_line": "Успешный блок рыцаря открывает одно окно длинного контрвыпада.",
	"shield_stored_damage_bash": "Своевременные блоки сохраняют долю входящего урона для следующего удара щитом.",
	"flail_return_control_pulse": "Возвращающаяся головка кистеня выпускает один ослабленный святой импульс контроля.",
	"pack_alpha_pounce_guard": "Команда стае чередует ограниченный прыжок вожака и защитный ответ владельца.",
	"briar_sustained_root_burst": "Задержавшийся в терниях враг укореняется и выпускает всплеск при выходе или смерти.",
	"totem_every_nth_raven_strike": "Каждый четвёртый импульс тотема вызывает один удар ворона и короткое окно поддержки.",
}

const PARAM_WORD_RU := {
	"absorb": "поглощение", "absorbs": "поглощения", "active": "активный", "aftershock": "последействие",
	"arc": "дуга", "beams": "лучи", "block": "блок", "brace": "стойка", "branches": "ветви",
	"bursts": "всплески", "cast": "применение", "collapses": "схлопывания", "command": "команда",
	"counters": "контрудары", "countershots": "контрвыстрелы", "cycle": "цикл", "delay": "задержка",
	"detonations": "детонации", "echoes": "эхо", "hit": "попадание", "intercepts": "перехваты",
	"knockback": "отталкивание", "lane": "дорожка", "loop": "цикл", "pierce": "пробитие",
	"pounces": "прыжки", "reaction": "реакция", "reduction": "снижение", "second": "второй",
	"secondary": "вторичные", "shards": "осколки", "shared": "разделённый", "speed": "скорость",
	"strikes": "удары", "total": "суммарный", "wave": "волна",
	"amount": "величина", "attack": "атака", "bonus": "бонус", "boss": "босс",
	"branch": "ветвь", "burst": "всплеск", "cap": "предел", "casts": "применения",
	"chain": "цепь", "collapse": "схлопывание", "combo": "комбинация",
	"conversion": "преобразование", "cooldown": "перезарядка", "counter": "контрудар",
	"countershot": "контрвыстрел", "damage": "урон", "death": "смерть",
	"deploy": "размещение", "detonation": "детонация", "direct": "прямой",
	"displacement": "смещение", "dodge": "уклонение", "duration": "длительность",
	"echo": "эхо", "enemy": "враг", "execute": "добивание", "expiry": "истечение",
	"external": "внешнее", "extra": "дополнительный", "factor": "коэффициент",
	"followthrough": "внешняя дуга", "followup": "продолжение", "gold": "золото",
	"guard": "защита", "heal": "лечение", "healing": "лечение", "heat": "нагрев",
	"hits": "попадания", "identity": "боевой приём", "intercept": "перехват",
	"interval": "интервал", "lanes": "дорожки", "linked": "связанные",
	"mark": "метка", "marks": "метки", "mine": "мина", "multiplier": "множитель",
	"neighbor": "соседние", "no": "без", "one": "один", "overlap": "перекрытие",
	"per": "на", "phases": "стихии", "pin": "удержание", "pool": "лужа",
	"pounce": "прыжок", "prey": "добыча", "priority": "приоритет",
	"pulse": "импульс", "pulses": "импульсы", "pull": "притяжение",
	"ratio": "доля", "reactions": "реакции", "recall": "возврат", "recursive": "рекурсивное",
	"repeat": "повтор", "required": "требуется", "reserved": "зарезервировано",
	"resonance": "резонанс", "retaliation": "возмездие", "return": "возврат",
	"returns": "возвраты", "rift": "разлом", "root": "укоренение", "same": "одинаковый",
	"seconds": "секунды", "self": "собственный", "shield": "щит", "shots": "выстрелы",
	"shrapnel": "осколки", "slow": "замедление", "snap": "разряд", "spread": "перенос",
	"stack": "заряд", "stacks": "заряды", "stagger": "оглушение", "storage": "сохранение",
	"stored": "сохранённый", "streak": "серия", "strike": "удар", "summon": "призыв",
	"support": "поддержка", "target": "цель", "targets": "цели", "tick": "тик",
	"trap": "капкан", "transfer": "перенос", "transfers": "переносы", "true": "да",
	"turret": "турель", "unchanged": "без изменений", "unique": "разные",
	"waves": "волны", "weakpoint": "уязвимость", "window": "окно", "wound": "рана",
	"zone": "зона", "depth": "глубина", "count": "число", "bloom": "цветение", "blooms": "цветения",
	"jaws": "челюсти", "jaw": "челюсть", "reagent": "реагент", "allowed": "разрешено",
	"heavy": "тяжёлый", "line": "линия", "owner": "владелец", "full": "полный",
	"charge": "заряд", "raven": "ворон", "amp": "усилитель", "instrument": "инструмент",
	"cloud": "облако", "corrosion": "коррозия", "threshold": "порог",
}


static func build(node: Dictionary) -> Dictionary:
	if not _valid_contract_input(node):
		return {}
	var role := str(node.get("role", ""))
	var class_id := str(node.get("class_affinity", node.get("class_id", "")))
	var weapon_title := str(node.get("weapon_title", ""))
	var weapon_id := str(node.get("weapon_id", ""))
	var axis := str(node.get("axis", node.get("affected_axis", "primary_attribute")))
	var profile: Dictionary = node.get("effect_profile", {})
	var effect_key := str(profile.get("effect_key", ""))
	var params: Dictionary = profile.get("params", {})
	var scope := str(profile.get("scope", ""))
	var result := {
		"contract_version": 1,
		"node_id": str(node.get("id", node.get("node_id", ""))),
		"role": role,
		"class_id": class_id,
		"weapon_id": weapon_id,
		"weapon_title": weapon_title,
		"scope": scope,
		"axis": axis,
		"axis_text": str(AXIS_RU.get(axis, "профиль оружия")),
		"mechanic_id": str(node.get("mechanic_id", "")),
	}
	if role == "core":
		result.merge(_core_copy(node, params), true)
	elif role == "weapon_final":
		result.merge(_final_copy(node, params), true)
	elif role in ["weapon_boon", "hidden"]:
		result.merge(_weapon_copy(node, effect_key, params), true)
	else:
		return {}
	result["full_text"] = "%s\n\n%s\n\n%s\n\n%s" % [
		str(result.get("scope_text", "")), str(result.get("effect_text", "")),
		str(result.get("result_text", "")), str(result.get("progress_text", "")),
	]
	return result


static func apply_to_node(node: Dictionary) -> Dictionary:
	var decorated := node.duplicate(true)
	var dossier := build(decorated)
	decorated["dossier"] = dossier
	decorated["dossier_valid"] = not dossier.is_empty()
	decorated["desc"] = str(dossier.get("full_text", FAILURE_TEXT))
	return decorated


static func _valid_contract_input(node: Dictionary) -> bool:
	var role := str(node.get("role", ""))
	var node_id := str(node.get("id", node.get("node_id", "")))
	var class_id := str(node.get("class_affinity", node.get("class_id", "")))
	if role not in ["core", "weapon_boon", "weapon_final", "hidden"] or node_id == "" or class_id == "":
		return false
	var profile = node.get("effect_profile", {})
	if not profile is Dictionary:
		return false
	var profile_value := profile as Dictionary
	var effect_key := str(profile_value.get("effect_key", ""))
	var scope := str(profile_value.get("scope", ""))
	var params = profile_value.get("params", {})
	if effect_key == "" or not params is Dictionary or (params as Dictionary).is_empty():
		return false
	var param_values := params as Dictionary
	if role == "core":
		var attribute := str(param_values.get("attribute", ""))
		return (
			effect_key == "primary_attribute_flat"
			and scope == "owning_class"
			and ATTRIBUTE_RU.has(attribute)
			and param_values.has("amount")
			and float(param_values.get("amount", 0.0)) > 0.0
		)
	var weapon_id := str(node.get("weapon_id", ""))
	var weapon_title := str(node.get("weapon_title", ""))
	var axis := str(node.get("axis", node.get("affected_axis", "")))
	if weapon_id == "" or weapon_title == "" or not AXIS_RU.has(axis) or scope != "owning_weapon_only":
		return false
	if role in ["weapon_boon", "hidden"]:
		if not EFFECT_RU.has(effect_key):
			return false
		if role == "weapon_boon" and (int(node.get("branch_order", 0)) < 1 or int(node.get("branch_order", 0)) > 5):
			return false
		if param_values.has("amount"):
			return float(param_values.get("amount", 0.0)) > 0.0
		if param_values.has("multiplier"):
			if float(param_values.get("multiplier", 0.0)) <= 1.0:
				return false
			if effect_key == "weapon_prefinal_identity_mult":
				var identity: Variant = param_values.get("identity", null)
				return identity is String and str(identity).strip_edges() != "" and PREFINAL_IDENTITY_RU.has(str(identity))
			return true
		return false
	var mechanic_id := str(node.get("mechanic_id", ""))
	var caps = node.get("caps", {})
	if (
		int(node.get("branch_order", 0)) != 6
		or mechanic_id == ""
		or effect_key != mechanic_id
		or not FINAL_MECHANIC_RU.has(mechanic_id)
		or float(node.get("gain_over_order_5_min", 0.0)) < 1.20
		or not caps is Dictionary
		or (caps as Dictionary).is_empty()
		or (caps as Dictionary) != param_values
	):
		return false
	for raw_key in param_values.keys():
		if str(raw_key) == "identity":
			return false
		var raw_value = param_values[raw_key]
		if not (raw_value is bool or raw_value is int or raw_value is float):
			return false
		if (raw_value is int or raw_value is float) and (not is_finite(float(raw_value)) or float(raw_value) < 0.0):
			return false
		for token in str(raw_key).split("_"):
			if not PARAM_WORD_RU.has(token):
				return false
	return true


static func _core_copy(node: Dictionary, params: Dictionary) -> Dictionary:
	var attribute := str(params.get("attribute", ""))
	var amount := float(params.get("amount", 0.0))
	var attribute_title := str(ATTRIBUTE_RU.get(attribute, attribute.capitalize()))
	return {
		"scope_text": "Охват: весь класс; все три оружия получают основу созвездия.",
		"effect_text": "Ось: основная характеристика класса. Параметр «%s»: 0 → %s (изменение +%s)." % [attribute_title, _number(amount), _number(amount)],
		"result_text": "Ядро открыто бесплатно и всегда активно; стоимость и переключатель отсутствуют.",
		"progress_text": "Прогресс созвездия: старт 0/20; ядро 0 → 0 эмблем.",
		"is_final": false,
	}


static func _weapon_copy(node: Dictionary, effect_key: String, params: Dictionary) -> Dictionary:
	var role := str(node.get("role", ""))
	var weapon_title := str(node.get("weapon_title", node.get("weapon_id", "")))
	var axis := str(node.get("axis", ""))
	var effect_title := str(EFFECT_RU.get(effect_key, ""))
	if effect_title == "":
		return {}
	var before_after := _ordinary_before_after(effect_key, params)
	var identity_text := ""
	if effect_key == "weapon_prefinal_identity_mult":
		identity_text = str(PREFINAL_IDENTITY_RU.get(str(params.get("identity", "")), ""))
	var order := int(node.get("branch_order", 3 if role == "hidden" else 0))
	var progress := "Ответвление «%s»: путь 3/6; тайная звезда 0/1 → 1/1 после покупки." % weapon_title if role == "hidden" else "Путь «%s»: %d/6 → %d/6." % [weapon_title, maxi(order - 1, 0), order]
	return {
		"scope_text": "Оружие: «%s». Охват: только это оружие; другие два оружия класса не меняются." % weapon_title,
		"effect_text": "Ось: %s. Параметр «%s»: %s.%s" % [str(AXIS_RU.get(axis, "профиль оружия")), effect_title, before_after, " Приём: %s." % identity_text if identity_text != "" else ""],
		"result_text": "Точное изменение применяется после покупки этой звезды; эффект не является общеклассовым.",
		"progress_text": progress,
		"is_final": false,
		"identity_text": identity_text,
	}


static func _final_copy(node: Dictionary, params: Dictionary) -> Dictionary:
	var mechanic_id := str(node.get("mechanic_id", ""))
	var mechanic_text := str(FINAL_MECHANIC_RU.get(mechanic_id, ""))
	if mechanic_text == "":
		return {}
	var weapon_title := str(node.get("weapon_title", node.get("weapon_id", "")))
	var axis := str(node.get("axis", ""))
	var floor := float(node.get("gain_over_order_5_min", 0.0))
	var cap_parts := PackedStringArray()
	var sorted_keys := params.keys()
	sorted_keys.sort()
	for raw_key in sorted_keys:
		var key := str(raw_key)
		if key == "identity":
			continue
		cap_parts.append("%s — %s" % [_parameter_title(key), _parameter_value(key, params[key])])
	var boss_parts := PackedStringArray()
	for raw_key in sorted_keys:
		var key := str(raw_key)
		if key.begins_with("boss_") or key == "no_boss_execute":
			boss_parts.append("%s — %s" % [_parameter_title(key), _parameter_value(key, params[key])])
	var boss_text := "Против босса: тот же триггер и те же ограничители; отдельного скрытого множителя нет."
	if not boss_parts.is_empty():
		boss_text = "Против босса: %s." % "; ".join(boss_parts)
	return {
		"scope_text": "Оружие: «%s». Охват: только это оружие; финал не включает и не выключает другие пути." % weapon_title,
		"effect_text": "Ось: %s. Триггер и механика: %s\nОграничители: %s." % [str(AXIS_RU.get(axis, "профиль оружия")), mechanic_text, "; ".join(cap_parts)],
		"result_text": "%s\nСила относительно узла 5/6: ×1,00 → не менее ×%s (изменение не менее +%d%%)." % [boss_text, _decimal_comma(floor, 2), int(roundf((floor - 1.0) * 100.0))],
		"progress_text": "Путь «%s»: 5/6 → 6/6. УНИКАЛЬНЫЙ ФИНАЛ всегда активен после покупки; переключателя активации нет." % weapon_title,
		"is_final": true,
		"final_callout": "УНИКАЛЬНЫЙ ФИНАЛ",
	}


static func _ordinary_before_after(effect_key: String, params: Dictionary) -> String:
	if params.has("amount"):
		var amount := float(params.get("amount", 0.0))
		return "0 → %s (изменение +%s)" % [_number(amount), _number(amount)]
	if params.has("multiplier"):
		var multiplier := float(params.get("multiplier", 1.0))
		return "×1,00 → ×%s (изменение +%d%%)" % [_decimal_comma(multiplier, 2), int(roundf((multiplier - 1.0) * 100.0))]
	return ""


static func _parameter_title(key: String) -> String:
	var words := PackedStringArray()
	for token in key.split("_"):
		words.append(str(PARAM_WORD_RU.get(token, token)))
	var title := " ".join(words)
	return title.left(1).to_upper() + title.substr(1)


static func _parameter_value(key: String, raw_value) -> String:
	if raw_value is bool:
		return "да" if bool(raw_value) else "нет"
	if raw_value is String:
		return str(raw_value)
	var value := float(raw_value)
	if key.ends_with("_seconds"):
		return "%s с" % _number(value)
	if key.contains("ratio") or key.contains("factor") or key.contains("threshold") or key.contains("bonus") or key.contains("reduction") or key == "stack_bonus" or key == "dodge_bonus":
		return "%s%%" % _number(value * 100.0)
	return _number(value)


static func _number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return _decimal_comma(value, 2).trim_suffix("0")


static func _decimal_comma(value: float, digits: int) -> String:
	return ("%.*f" % [digits, value]).replace(".", ",")
