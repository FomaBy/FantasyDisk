extends RefCounted

const RANDOM_EVENTS := [
	{
		# SCRUM-608: «Опасная развилка» — узел типа hazard на маршруте. Безопасный
		# обход (золото/лечение) ИЛИ рискованный срез (бой + награда за победу).
		# Рисковый апсайд держим выше безопасного (EV-инвариант SCRUM-495).
		"id": "sudden_fork",
		"title": "Опасная развилка",
		"story": "Тропа раздваивается: широкий безопасный обход петляет в сторону, а узкий срез ныряет в теснину, где между камней мелькают тени. Срез короче — но кто-то его уже стережёт.",
		"choices": [
			{"id": "safe_detour", "title": "Безопасный обход", "description": "Без риска: +14 золота и лечение 20% HP.", "money": 14, "heal_percent": 0.20},
			{"id": "risky_shortcut", "title": "Опасный срез", "description": "Риск: бой в теснине. Победа: +50% золота, +1 Сила и +6% урон на весь забег.", "risk": true, "combat": {"type": "battle", "enemy_health_multiplier": 1.16, "money_multiplier": 1.5}, "post_combat": {"stats": {"strength": 1}, "mods": {"damage_multiplier": 1.06}}},
			{"id": "scout_ahead", "title": "Разведать", "description": "Проверка Восприятия 7: успех +18 золота и +1 Восприятие, провал -10% HP.", "check": {"stat": "perception", "difficulty": 7}, "success": {"money": 18, "stats": {"perception": 1}}, "failure": {"health_percent_cost": 0.10}},
		],
	},
	{
		"id": "wandering_bard",
		"title": "Странствующий бард",
		"story": "У развилки сидит бард с лютней, струны которой светятся как тонкие лезвия. Он знает песни о каждом герое, но за хорошую балладу просит звонкую монету.",
		"choices": [
			{"id": "pay_ballad", "title": "Заплатить за балладу", "description": "Цена: 18 золота. На весь забег: +12% к скорости атаки.", "cost_money": 18, "mods": {"attack_speed_multiplier": 1.12}},
			{"id": "sing_yourself", "title": "Спеть самому", "description": "Проверка Знания 7: успех +1 Знание, +1 Восприятие и +1 Лидерство, провал -1 Знание.", "check": {"stat": "knowledge", "difficulty": 7}, "success": {"stats": {"knowledge": 1, "perception": 1, "leadership": 1}}, "failure": {"stats": {"knowledge": -1}}},
			{"id": "walk_away", "title": "Попросить припев на удачу", "description": "Без цены: +6 золота и немного вдохновения.", "money": 6, "mods": {"xp_gain_multiplier": 1.04}},
		],
	},
	{
		"id": "cursed_altar",
		"title": "Проклятый алтарь",
		"story": "Черный алтарь дышит теплым воздухом, хотя вокруг стелется холод. На камне видна выемка в форме ладони, и где-то под землей шевелятся цепи.",
		"choices": [
			{"id": "blood_price", "title": "Отдать кровь", "description": "Цена: 30% текущего HP. Получить случайный артефакт.", "health_percent_cost": 0.30, "random_artifact": true},
			{"id": "defile", "title": "Осквернить алтарь", "description": "Риск: элитный бой с тенью-стражем. Победа: элитная добыча, +50% золота, +25% опыта и +1 Сила/+1 Выносливость.", "risk": true, "combat": {"type": "elite", "enemy_health_multiplier": 1.12, "money_multiplier": 1.5, "xp_multiplier": 1.25}, "post_combat": {"stats": {"strength": 1, "endurance": 1}}},
			{"id": "quiet_prayer", "title": "Тихая молитва", "description": "Получить +1 Выносливость, но потерять 10% HP.", "stats": {"endurance": 1}, "health_percent_cost": 0.10},
		],
	},
	{
		"id": "road_ambush",
		"title": "Засада!",
		"story": "Сначала слышен только песок под ногами. Потом дорога раскрывается множеством глаз, и из мрака вываливается подготовленная стая.",
		"choices": [
			{"id": "stand_ground", "title": "Принять бой", "description": "Риск: усиленный бой. Победа дает +50% золота и +1 Сила за бой.", "risk": true, "combat": {"type": "battle", "enemy_health_multiplier": 1.18, "money_multiplier": 1.5}, "post_combat": {"stats": {"strength": 1}}},
			{"id": "break_through", "title": "Прорыв", "description": "Проверка Ловкости 8: успех +1 Ловкость и +6% скорость атаки, провал -15% HP.", "check": {"stat": "agility", "difficulty": 8}, "success": {"stats": {"agility": 1}, "mods": {"attack_speed_multiplier": 1.06}}, "failure": {"health_percent_cost": 0.15}},
		],
	},
	{
		"id": "old_well",
		"title": "Старый колодец",
		"story": "Колодец стоит посреди дороги так, будто дорогу построили вокруг него. Из глубины пахнет дождем, монетами и чем-то, что слишком долго ждало.",
		"choices": [
			{"id": "throw_coin", "title": "Бросить монету", "description": "Цена: 8 золота. Случайно: лечение 30% HP, 28 золота или бой.", "cost_money": 8, "random_outcomes": [{"heal_percent": 0.30}, {"money": 28}, {"combat": {"type": "battle", "enemy_health_multiplier": 1.10, "money_multiplier": 1.25}}]},
			{"id": "listen", "title": "Прислушаться", "description": "Проверка Восприятия 7: успех +1 Восприятие, провал +5 золота.", "check": {"stat": "perception", "difficulty": 7}, "success": {"stats": {"perception": 1}}, "failure": {"money": 5}},
		],
	},
	{
		"id": "wounded_mercenary",
		"title": "Раненый наемник",
		"story": "У обочины лежит наемник с пробитым щитом. Он не просит жалости, только воды и обещания, что его меч еще раз увидит бой.",
		"choices": [
			{"id": "help", "title": "Помочь", "description": "Цена: 20 золота. Следующие бои: +1 Лидерство и +1 призыв.", "cost_money": 20, "stats": {"leadership": 1}, "mods": {"summon_bonus": 1}},
			{"id": "loot", "title": "Обыскать сумку", "description": "Получить 30 золота, но -1 Знание.", "money": 30, "stats": {"knowledge": -1}},
			{"id": "bind_wounds", "title": "Перевязать раны", "description": "Проверка Выносливости 7: успех +1 Защита через артефактный мод, провал -6 золота.", "check": {"stat": "endurance", "difficulty": 7}, "success": {"mods": {"defense_flat": 0.06}}, "failure": {"cost_money": 6}},
		],
	},
	{
		"id": "goblin_lottery",
		"title": "Гоблин-лотерейщик",
		"story": "Гоблин в цилиндре трясет мешок, из которого то звенит стекло, то шепчет чужой голос. На табличке написано: «Возвратов нет, проклятий тоже почти нет».",
		"choices": [
			{"id": "buy_bag", "title": "Купить мешок вслепую", "description": "Цена: 8 золота. Риск: артефакт, 16 золота или мимик.", "risk": true, "cost_money": 8, "random_outcomes": [{"random_artifact": true}, {"money": 16}, {"combat": {"type": "battle", "enemy_health_multiplier": 1.20, "money_multiplier": 1.5}}]},
			{"id": "haggle", "title": "Торговаться", "description": "Проверка Восприятия 8: успех +30 золота, провал -10 золота.", "check": {"stat": "perception", "difficulty": 8}, "success": {"money": 30}, "failure": {"cost_money": 10}},
		],
	},
	{
		"id": "hot_spring",
		"title": "Горячий источник",
		"story": "В каменной чаше кипит вода цвета янтаря. Пар складывается в лица прежних путников, которые выглядят слишком довольными и слишком сонными.",
		"choices": [
			{"id": "full_rest", "title": "Отдохнуть", "description": "Полное лечение. Следующий бой: враги на 25% живучее.", "heal_percent": 1.0, "mods": {"enemy_health_multiplier": 1.25}},
			{"id": "quick_dip", "title": "Быстро окунуться", "description": "Лечение 35% HP без побочного эффекта.", "heal_percent": 0.35},
		],
	},
	{
		"id": "mirror_phantom",
		"title": "Зеркальный фантом",
		"story": "На дороге висит зеркало без рамы. В отражении твой герой улыбается первым, поднимает оружие и делает шаг наружу.",
		"choices": [
			{"id": "duel", "title": "Разбить отражение", "description": "Риск: элитный бой против фантома. Победа: элитная добыча, +30% золота, +1 Интеллект и +8% урон.", "risk": true, "combat": {"type": "elite", "enemy_health_multiplier": 1.05, "money_multiplier": 1.3}, "post_combat": {"stats": {"intelligence": 1}, "mods": {"damage_multiplier": 1.08}}},
			{"id": "study", "title": "Изучить отражение", "description": "Проверка Интеллекта 8: успех +1 Интеллект и +8% урон, провал -12% HP.", "check": {"stat": "intelligence", "difficulty": 8}, "success": {"stats": {"intelligence": 1}, "mods": {"damage_multiplier": 1.08}}, "failure": {"health_percent_cost": 0.12}},
		],
	},
	{
		"id": "stone_guardian",
		"title": "Каменный страж",
		"story": "Страж перегородил мост и произносит загадку голосом жернова. Каждое неправильное слово оставляет трещину не в камне, а в воздухе вокруг тебя.",
		"choices": [
			{"id": "answer_riddle", "title": "Ответить на загадку", "description": "Проверка Знания 8: успех сундук с артефактом, провал бой.", "check": {"stat": "knowledge", "difficulty": 8}, "success": {"random_artifact": true}, "failure": {"combat": {"type": "battle", "enemy_health_multiplier": 1.15}}},
			{"id": "fight_guardian", "title": "Сразу в бой", "description": "Риск: тяжелый бой. Победа дает +30% золота, +1 Сила и +1 Выносливость.", "risk": true, "combat": {"type": "battle", "enemy_health_multiplier": 1.25, "money_multiplier": 1.3}, "post_combat": {"stats": {"strength": 1, "endurance": 1}}},
		],
	},
	{
		"id": "heroes_graveyard",
		"title": "Кладбище героев",
		"story": "Старые клинки торчат из земли вместо крестов. На каждом имени есть свежая царапина, будто кто-то проверял, не освободилось ли место для нового.",
		"choices": [
			{"id": "dig", "title": "Раскопать могилу", "description": "Риск: артефакт павшего или гнев мертвеца (бой, но +1 Выносливость за победу).", "risk": true, "random_outcomes": [{"random_artifact": true}, {"combat": {"type": "battle", "enemy_health_multiplier": 1.22, "money_multiplier": 1.35}, "post_combat": {"stats": {"endurance": 1}}}]},
			{"id": "pay_respects", "title": "Почтить павших", "description": "+1 Выносливость и лечение 15% HP.", "stats": {"endurance": 1}, "heal_percent": 0.15},
		],
	},
	{
		"id": "fallen_star",
		"title": "Падшая звезда",
		"story": "В кратере лежит осколок неба, горячий как свежая рана. Он тянется к твоей руке, но трава вокруг уже сгорела до стекла.",
		"choices": [
			{"id": "take_shard", "title": "Взять осколок", "description": "+2 Энергия, но потерять 12% HP от звездного ожога.", "stats": {"energy": 2}, "health_percent_cost": 0.12},
			{"id": "observe", "title": "Изучить кратер", "description": "Проверка Интеллекта 7: успех +1 Энергия и +1 Знание, провал -8% HP.", "check": {"stat": "intelligence", "difficulty": 7}, "success": {"stats": {"energy": 1, "knowledge": 1}}, "failure": {"health_percent_cost": 0.08}},
		],
	},
	{
		"id": "training_dummies",
		"title": "Тренировочные манекены",
		"story": "На поляне стоят манекены с нарисованными оскалами. Когда ты подходишь ближе, они дружно поворачивают головы и ждут первого удара.",
		"choices": [
			{"id": "speed_trial", "title": "Испытание скорости", "description": "Проверка Ловкости 7: успех +1 Ловкость и +8% скорость атаки, провал -10% HP.", "check": {"stat": "agility", "difficulty": 7}, "success": {"stats": {"agility": 1}, "mods": {"attack_speed_multiplier": 1.08}}, "failure": {"health_percent_cost": 0.10}},
			{"id": "power_trial", "title": "Испытание силы", "description": "Проверка Силы 7: успех +1 Сила и +8% урон, провал -10% HP.", "check": {"stat": "strength", "difficulty": 7}, "success": {"stats": {"strength": 1}, "mods": {"damage_multiplier": 1.08}}, "failure": {"health_percent_cost": 0.10}},
		],
	},
	{
		"id": "warden_gate_trial",
		"title": "Врата Хранителя",
		"story": "Тройные врата перегораживают тропу: бронзовая плита, светящаяся руна и пустой трон с венцом. Хранитель шепчет, что каждый герой открывает свою створку — и платит свою цену за чужую.",
		"choices": [
			{"id": "brace_plate", "title": "Танк: упереться в плиту", "description": "Проверка Выносливости 7: танк держит вес — успех +1 Выносливость и +0.08 Защита, провал -12% HP.", "check": {"stat": "endurance", "difficulty": 7}, "success": {"stats": {"endurance": 1}, "mods": {"defense_flat": 0.08}}, "failure": {"health_percent_cost": 0.12}},
			{"id": "read_rune", "title": "Маг: распутать руну", "description": "Проверка Интеллекта 7: маг читает формулу — успех +1 Интеллект и +8% урон, провал -12% HP.", "check": {"stat": "intelligence", "difficulty": 7}, "success": {"stats": {"intelligence": 1}, "mods": {"damage_multiplier": 1.08}}, "failure": {"health_percent_cost": 0.12}},
			{"id": "claim_throne", "title": "Призыватель: занять трон", "description": "Проверка Лидерства 7: призыватель командует венцом — успех +1 Лидерство и +1 призыв, провал -12% HP.", "check": {"stat": "leadership", "difficulty": 7}, "success": {"stats": {"leadership": 1}, "mods": {"summon_bonus": 1}}, "failure": {"health_percent_cost": 0.12}},
		],
	},
	{
		"id": "abandoned_forge",
		"title": "Заброшенная кузница",
		"story": "Горн остыл века назад, но молот сам качается над наковальней, будто кто-то невидимый всё ещё кует. На стене висят три заготовки, и каждая отзывается на свою руку.",
		"choices": [
			{"id": "temper_armor", "title": "Танк: закалить броню", "description": "Проверка Выносливости 8: успех усиленная пластина (+0.10 Защита и +6% HP), провал -10% HP.", "check": {"stat": "endurance", "difficulty": 8}, "success": {"mods": {"defense_flat": 0.10, "max_health_multiplier": 1.06}}, "failure": {"health_percent_cost": 0.10}},
			{"id": "etch_sigil", "title": "Маг: вытравить сигил", "description": "Проверка Интеллекта 8: успех боевой сигил (+12% урон и +6% скорость атаки), провал -10% HP.", "check": {"stat": "intelligence", "difficulty": 8}, "success": {"mods": {"damage_multiplier": 1.12, "attack_speed_multiplier": 1.06}}, "failure": {"health_percent_cost": 0.10}},
			{"id": "salvage_scrap", "title": "Собрать лом", "description": "Без проверки: +22 золота из старых инструментов.", "money": 22},
		],
	},
	{
		"id": "merchant_caravan",
		"title": "Торговый караван",
		"story": "Из пыли выкатывается крытая повозка, увешанная амулетами и медными колокольчиками. Купец улыбается слишком широко и раскладывает товар прямо на дорожной пыли.",
		"choices": [
			{"id": "buy_relic", "title": "Купить реликвию", "description": "Цена: 26 золота. Получить случайный артефакт из запасов каравана.", "cost_money": 26, "random_artifact": true},
			{"id": "buy_tonic", "title": "Купить тоник", "description": "Цена: 14 золота. Лечение 45% HP и +4% к лечению на забег.", "cost_money": 14, "heal_percent": 0.45, "mods": {"healing_multiplier": 1.04}},
			{"id": "haggle_caravan", "title": "Сбить цену", "description": "Проверка Восприятия 8: успех +28 золота сдачи, провал -10 золота.", "check": {"stat": "perception", "difficulty": 8}, "success": {"money": 28}, "failure": {"cost_money": 10}},
		],
	},
	{
		"id": "whispering_grove",
		"title": "Шепчущая роща",
		"story": "Деревья смыкают кроны в зелёный купол, и листва шепчет имена на языке, который ты почти понимаешь. В центре поляны бьёт родник, а тени между стволами слишком уж осмысленны.",
		"choices": [
			{"id": "drink_spring", "title": "Испить из родника", "description": "Лечение 40% HP и +1 Знание от шёпота рощи.", "heal_percent": 0.40, "stats": {"knowledge": 1}},
			{"id": "follow_whisper", "title": "Пойти на шёпот", "description": "Проверка Знания 7: успех +1 Знание и +6% опыта, провал -8% HP.", "check": {"stat": "knowledge", "difficulty": 7}, "success": {"stats": {"knowledge": 1}, "mods": {"xp_gain_multiplier": 1.06}}, "failure": {"health_percent_cost": 0.08}},
			{"id": "disturb_grove", "title": "Потревожить тени", "description": "Риск: бой с лесными стражами. Победа: +35% золота и +1 Восприятие.", "risk": true, "combat": {"type": "battle", "enemy_health_multiplier": 1.16, "money_multiplier": 1.35}, "post_combat": {"stats": {"perception": 1}}},
		],
	},
	{
		"id": "collapsing_mineshaft",
		"title": "Обвалившаяся шахта",
		"story": "Вход в шахту наполовину завален, изнутри тянет рудной сыростью и слышен далёкий стук кирки. Балки скрипят, и пыль сыплется на ржавую вагонетку с чем-то блестящим внутри.",
		"choices": [
			{"id": "dig_through", "title": "Разобрать завал", "description": "Цена: 10% HP. Случайно: артефакт, 26 золота или обрушение в бой.", "health_percent_cost": 0.10, "random_outcomes": [{"random_artifact": true}, {"money": 26}, {"combat": {"type": "battle", "enemy_health_multiplier": 1.18, "money_multiplier": 1.3}}]},
			{"id": "brace_beams", "title": "Укрепить балки", "description": "Проверка Выносливости 7: успех вынести руду (+24 золота), провал -10% HP под обвалом.", "check": {"stat": "endurance", "difficulty": 7}, "success": {"money": 24}, "failure": {"health_percent_cost": 0.10}},
		],
	},
	# SCRUM-605: +5 сценариев риск/награды (data-driven, только существующие ключи
	# choice; рисковая ветка каждого события держит апсайд ≥ безопасной — EV-инвариант
	# SCRUM-495/508). Моды — только из VALID_MODS контракта (event_data_contract_check).
	{
		"id": "crystal_geode_vault",
		"title": "Кристальная жеода",
		"story": "В стене пещеры раскрылась исполинская жеода — частокол светящихся кристаллов в человеческий рост. Внутри пульсирует тёплый свет, но грани остры как бритвы, а в глубине что-то отзывается на каждый шаг.",
		"choices": [
			{"id": "chip_outer_shards", "title": "Отколоть с краю", "description": "Без риска: +16 золота кристальной крошки и лечение 18% HP от тёплого свечения.", "money": 16, "heal_percent": 0.18},
			{"id": "breach_the_core", "title": "Пробиться к ядру", "description": "Риск: бой с кристальным стражем жеоды. Победа: +60% золота, случайный артефакт, +1 Сила и +1 Выносливость.", "risk": true, "combat": {"type": "battle", "enemy_health_multiplier": 1.18, "money_multiplier": 1.6}, "post_combat": {"random_artifact": true, "stats": {"strength": 1, "endurance": 1}}},
			{"id": "pry_with_care", "title": "Аккуратно выломать", "description": "Проверка Силы 7: успех +1 Сила, +1 Выносливость и +14 золота, провал -12% HP о грани.", "check": {"stat": "strength", "difficulty": 7}, "success": {"stats": {"strength": 1, "endurance": 1}, "money": 14}, "failure": {"health_percent_cost": 0.12}},
		],
	},
	{
		"id": "starlit_observatory",
		"title": "Звёздная обсерватория",
		"story": "На вершине утёса стоит покинутая обсерватория. Огромная линза ловит свет давно погасших звёзд, и в её фокусе дрожит знание, к которому опасно прикасаться без подготовки.",
		"choices": [
			{"id": "copy_notes", "title": "Переписать заметки", "description": "Без риска: +1 Знание и +8 золота из оставленных журналов.", "stats": {"knowledge": 1}, "money": 8},
			{"id": "gaze_through_lens", "title": "Взглянуть сквозь линзу", "description": "Проверка Знания 8: успех +1 Знание, +1 Восприятие, +1 Интеллект и случайный артефакт, провал -1 Знание и -10% HP.", "check": {"stat": "knowledge", "difficulty": 8}, "success": {"stats": {"knowledge": 1, "perception": 1, "intelligence": 1}, "random_artifact": true}, "failure": {"stats": {"knowledge": -1}, "health_percent_cost": 0.10}},
			{"id": "align_the_mirrors", "title": "Настроить зеркала", "description": "Цена: 20 золота. На весь забег: +10% опыта и +1 Восприятие.", "cost_money": 20, "mods": {"xp_gain_multiplier": 1.10}, "stats": {"perception": 1}},
		],
	},
	{
		"id": "sunken_caravan",
		"title": "Затонувший караван",
		"story": "Болото поглотило торговый караван — над тиной торчат осями вверх повозки. Сундуки ещё видны под мутной водой, но в глубине что-то медленно ворочается и пускает пузыри.",
		"choices": [
			{"id": "skim_the_surface", "title": "Снять, что плавает", "description": "Без риска: +18 золота с поверхности трясины.", "money": 18},
			{"id": "dive_for_chest", "title": "Нырнуть за сундуком", "description": "Риск: бой с болотной тварью в воде. Победа: +50% золота, +35% опыта, случайный артефакт и +1 Ловкость.", "risk": true, "combat": {"type": "battle", "enemy_health_multiplier": 1.14, "money_multiplier": 1.5, "xp_multiplier": 1.35}, "post_combat": {"random_artifact": true, "stats": {"agility": 1}}},
			{"id": "probe_with_pole", "title": "Прощупать шестом", "description": "Проверка Восприятия 6: успех +20 золота и +1 Ловкость, провал -10% HP в трясине.", "check": {"stat": "perception", "difficulty": 6}, "success": {"money": 20, "stats": {"agility": 1}}, "failure": {"health_percent_cost": 0.10}},
		],
	},
	{
		"id": "war_drums_camp",
		"title": "Покинутый лагерь воинов",
		"story": "Догорающие костры брошенного лагеря ещё хранят тепло. На стойках висят боевые барабаны и точильные камни, а у поваленного знамени поблёскивает чей-то припрятанный паёк.",
		"choices": [
			{"id": "share_rations", "title": "Подкрепиться пайком", "description": "Без риска: лечение 22% HP и +6 золота из забытого кошеля.", "heal_percent": 0.22, "money": 6},
			{"id": "beat_the_drums", "title": "Ударить в барабаны", "description": "Риск: на грохот сбегается элитный загонщик. Победа: элитная добыча, +50% золота, +25% опыта, +1 Сила и +1 Лидерство.", "risk": true, "combat": {"type": "elite", "enemy_health_multiplier": 1.12, "money_multiplier": 1.5, "xp_multiplier": 1.25}, "post_combat": {"stats": {"strength": 1, "leadership": 1}}},
			{"id": "whet_your_blade", "title": "Наточить оружие", "description": "Цена: 16 золота за камни и масло. На весь забег: +8% скорости атаки и +6% урон.", "cost_money": 16, "mods": {"attack_speed_multiplier": 1.08, "damage_multiplier": 1.06}},
		],
	},
	{
		"id": "twin_offering_shrine",
		"title": "Святилище двойного подношения",
		"story": "Две каменные чаши стоят перед безликим идолом: одна просит монету, другая — кровь. Над ними мерцает наградной свет, но идол принимает дар лишь от того, кто действительно рискнёт.",
		"choices": [
			{"id": "leave_token_coin", "title": "Оставить монетку", "description": "Без риска: бросить +4 золота на удачу, +4% опыта на забег.", "money": 4, "mods": {"xp_gain_multiplier": 1.04}},
			{"id": "coin_offering", "title": "Подношение золотом", "description": "Цена: 26 золота. Получить случайный артефакт и +1 Лидерство.", "cost_money": 26, "random_artifact": true, "stats": {"leadership": 1}},
			{"id": "blood_offering", "title": "Подношение кровью", "description": "Цена: 22% текущего HP. Случайный исход: либо случайный артефакт и +1 Выносливость, либо +1 Сила и +12 золота.", "health_percent_cost": 0.22, "random_outcomes": [{"random_artifact": true, "stats": {"endurance": 1}}, {"stats": {"strength": 1}, "money": 12}]},
		],
	},
	# SCRUM-501: +5 сценариев, ≥2 класс-реактивны (несколько check-веток по разным
	# архетипным атрибутам — endurance=танк, intelligence=маг, leadership=призыватель,
	# strength=берсерк, knowledge=учёный). Только существующие ключи choice; difficulty
	# строго в 1..12; рисковый апсайд ≥ безопасного (EV-инвариант SCRUM-495/508).
	{
		"id": "oracle_crossroads",
		"title": "Перекрёсток оракула",
		"story": "На скрещении трёх дорог сидит слепой оракул и чертит на песке знаки. «Каждому — своя тропа, — шепчет он, — телу, разуму или воле. Чужая тропа покарает самозванца».",
		"choices": [
			{"id": "path_of_body", "title": "Танк: тропа тела", "description": "Проверка Выносливости 7: танк выдерживает испытание плоти — успех +1 Выносливость и +0.08 Защита, провал -12% HP.", "check": {"stat": "endurance", "difficulty": 7}, "success": {"stats": {"endurance": 1}, "mods": {"defense_flat": 0.08}}, "failure": {"health_percent_cost": 0.12}},
			{"id": "path_of_mind", "title": "Маг: тропа разума", "description": "Проверка Интеллекта 7: маг читает знаки на песке — успех +1 Интеллект и +8% урон, провал -12% HP.", "check": {"stat": "intelligence", "difficulty": 7}, "success": {"stats": {"intelligence": 1}, "mods": {"damage_multiplier": 1.08}}, "failure": {"health_percent_cost": 0.12}},
			{"id": "path_of_will", "title": "Призыватель: тропа воли", "description": "Проверка Лидерства 7: призыватель подчиняет видение — успех +1 Лидерство и +1 призыв, провал -12% HP.", "check": {"stat": "leadership", "difficulty": 7}, "success": {"stats": {"leadership": 1}, "mods": {"summon_bonus": 1}}, "failure": {"health_percent_cost": 0.12}},
		],
	},
	{
		"id": "runed_menhir",
		"title": "Рунный менгир",
		"story": "Среди вереска торчит замшелый камень выше человека, испещрённый рунами. Часть знаков можно выбить силой, часть — лишь прочитать; камень глухо гудит, ожидая, чем именно его потревожат.",
		"choices": [
			{"id": "shatter_menhir", "title": "Берсерк: расколоть силой", "description": "Проверка Силы 7: грубая сила вскрывает тайник — успех +1 Сила и +20 золота, провал -12% HP от отдачи.", "check": {"stat": "strength", "difficulty": 7}, "success": {"stats": {"strength": 1}, "money": 20}, "failure": {"health_percent_cost": 0.12}},
			{"id": "decipher_runes", "title": "Учёный: прочесть руны", "description": "Проверка Знания 7: знаток разбирает древнее письмо — успех +1 Знание и +8% опыта, провал -1 Знание.", "check": {"stat": "knowledge", "difficulty": 7}, "success": {"stats": {"knowledge": 1}, "mods": {"xp_gain_multiplier": 1.08}}, "failure": {"stats": {"knowledge": -1}}},
			{"id": "leave_offering_menhir", "title": "Оставить подношение", "description": "Цена: 10 золота. Камень благодарит лечением 25% HP.", "cost_money": 10, "heal_percent": 0.25},
		],
	},
	{
		"id": "gilded_gambler",
		"title": "Позолоченный шулер",
		"story": "За складным столиком сидит щёголь в золочёном плаще и тасует три карты быстрее, чем успевает глаз. «Удвою ставку или заберу всё, — мурлычет он, — выбор за тобой, герой».",
		"choices": [
			{"id": "place_bet", "title": "Сделать ставку", "description": "Цена: 12 золота. Удвоить или потерять: артефакт, 30 золота или подставной громила.", "risk": true, "cost_money": 12, "random_outcomes": [{"random_artifact": true}, {"money": 30}, {"combat": {"type": "battle", "enemy_health_multiplier": 1.18, "money_multiplier": 1.4}}]},
			{"id": "read_the_tell", "title": "Раскусить шулера", "description": "Проверка Восприятия 8: успех +26 золота с пойманного на жульничестве, провал -10 золота отступного.", "check": {"stat": "perception", "difficulty": 8}, "success": {"money": 26}, "failure": {"cost_money": 10}},
		],
	},
	{
		"id": "tidewater_grotto",
		"title": "Приливный грот",
		"story": "Морская пещера дышит в такт прибою: вода то отступает, обнажая жемчужный песок, то с рёвом врывается обратно. В дальнем гроте поблёскивает что-то, оставленное отливом.",
		"choices": [
			{"id": "bathe_in_pool", "title": "Омыться в заводи", "description": "Без риска: лечение 30% HP и +4% к лечению на забег от целебной соли.", "heal_percent": 0.30, "mods": {"healing_multiplier": 1.04}},
			{"id": "raid_the_grotto", "title": "Добраться до грота", "description": "Прилив запирает в бою с глубинной тварью. Победа: +50% золота, +30% опыта и случайный артефакт.", "risk": true, "combat": {"type": "battle", "enemy_health_multiplier": 1.16, "money_multiplier": 1.5, "xp_multiplier": 1.3}, "post_combat": {"random_artifact": true}},
			{"id": "time_the_waves", "title": "Поймать отлив", "description": "Проверка Ловкости 7: успех +18 золота с обнажённого дна, провал -10% HP под накатившей волной.", "check": {"stat": "agility", "difficulty": 7}, "success": {"money": 18}, "failure": {"health_percent_cost": 0.10}},
		],
	},
	{
		"id": "wandering_emberwisp",
		"title": "Блуждающий огонёк",
		"story": "В сумерках над болотом качается тёплый огонёк размером с кулак. Он манит в сторону от тропы, обещая то ли клад, то ли трясину, и подрагивает, стоит подойти чуть ближе.",
		"choices": [
			{"id": "follow_emberwisp", "title": "Пойти за огоньком", "description": "Цена: 8% HP по топкой тропе. Случайно: +28 золота, случайный артефакт или засада в трясине.", "health_percent_cost": 0.08, "random_outcomes": [{"money": 28}, {"random_artifact": true}, {"combat": {"type": "battle", "enemy_health_multiplier": 1.14, "money_multiplier": 1.3}}]},
			{"id": "snare_the_ember", "title": "Поймать искру", "description": "Проверка Интеллекта 7: успех приручённый огонёк даёт +8% урон на весь забег, провал -8% HP от ожога.", "check": {"stat": "intelligence", "difficulty": 7}, "success": {"mods": {"damage_multiplier": 1.08}}, "failure": {"health_percent_cost": 0.08}},
		],
	},
]


static func event_ids() -> Array:
	var ids := []
	for event in RANDOM_EVENTS:
		ids.append(str(event.get("id", "")))
	return ids


static func event_by_id(event_id: String) -> Dictionary:
	for event in RANDOM_EVENTS:
		if str(event.get("id", "")) == event_id:
			return event.duplicate(true)
	return {}


static func pick_event(used_ids: Array, rng: RandomNumberGenerator) -> Dictionary:
	var available := []
	for event in RANDOM_EVENTS:
		if not used_ids.has(str(event.get("id", ""))):
			available.append(event)
	if available.is_empty():
		used_ids.clear()
		for event in RANDOM_EVENTS:
			available.append(event)
	var index := 0
	if rng != null and available.size() > 1:
		index = rng.randi_range(0, available.size() - 1)
	return (available[index] as Dictionary).duplicate(true)
