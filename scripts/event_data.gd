extends RefCounted

# ============================================================================
# СХЕМА СОБЫТИЯ (контракт SCRUM-996 для пака SCRUM-995 и UI SCRUM-997).
# Все ключи, кроме id/title/story/choices, ОПЦИОНАЛЬНЫ; старые события без
# новых ключей работают как раньше (мгновенный переход без reveal-шага).
#
# Событие (элемент RANDOM_EVENTS):
#   id: String            — уникальный id события.
#   title: String         — заголовок экрана.
#   story: String         — вводный текст (>= 40 символов).
#   allow_skip: bool      — «Назад» на карту без исхода (по умолчанию false).
#   tags: Dictionary      — future-ready теги отбора (SCRUM-996):
#       {"acts": Array[int], "biomes": Array[String]}
#     acts: событие допустимо только в перечисленных актах, ЕСЛИ pick_event
#       получил context.act; пустой массив/нет ключа = любой акт.
#     biomes: зарезервировано под биомный отбор (фильтр пока не применяется).
#   choices: Array[Dictionary] — 2+ выборов.
#
# Выбор (choice) — сам является исходом-корнем (см. «Исход» ниже) плюс:
#   id: String, title: String, description: String — карточка выбора.
#   risk: bool            — префикс «Риск:» в описании карточки.
#   hidden: bool          — загадочный выбор (SCRUM-996): карточка НЕ раскрывает
#     исход — вместо description показывается unknown_hint (или «Исход
#     неизвестен…»), action-текст кнопки — «Рискнуть». Исходы hidden-выбора
#     обязаны нести outcome_text (честное раскрытие ПОСЛЕ выбора).
#     NB: цена cost_money у hidden-выбора не видна на кнопке — упоминай её
#     в unknown_hint. description у hidden-выбора не нужен (UI его не покажет).
#   unknown_hint: String  — «загадочное» описание для hidden-карточки.
#   check: {"stat": String, "difficulty": int 1..12} — детерминированная
#     проверка стата (порог: stat >= difficulty), ветвит success/failure.
#   success / failure: Dictionary — исход-ветка проверки (мержится в корень).
#   random_outcomes: Array[Dictionary] — случайный исход (мержится в корень).
#
# Исход (choice-корень / success / failure / элемент random_outcomes):
#   outcome_text: String  — рус. текст «что произошло» (SCRUM-996). Если исход
#     имеет outcome_text ЛИБО выбор hidden ЛИБО была check-проверка — экран
#     события показывает reveal-шаг (текст исхода + кнопка «В путь») вместо
#     мгновенного перехода на карту. Обязателен для hidden-исходов и веток
#     check в новом паке (SCRUM-995). У исхода-боя ветки check reveal не
#     показывается (исход — сам бой), но текст храним для честности данных
#     и будущего пре-боевого флейвора UI.
#   money: int            — выдать золото.
#   cost_money: int       — цена (масштабируется по этапу маршрута).
#   stats: {stat_id: int} — перманентные статы забега.
#   mods: {mod_id: float} — перманентные моды забега (VALID_MODS контракта).
#   heal_percent: float   — лечение долей от max HP (0..1).
#   health_percent_cost: float — цена HP долей от max HP (пол 1 HP, не летально).
#   damage_flat: int      — прямой урон HP (SCRUM-996; пол 1 HP, не летально).
#     Не путать с mods.damage_flat (плоский бонус урона атак игрока).
#   random_artifact: bool — случайный артефакт (пустой пул → золотая компенсация).
#   reward: Dictionary    — готовый reward-объект (apply_reward).
#   shop_after: true      — после применения исхода (и reveal-подтверждения)
#     открыть магазин; выход из него ведёт к штатному advance маршрута
#     (SCRUM-996). Работает и внутри post_combat (магазин после победы).
#   shop_discount: float  — скидка 0..0.9 на товары событийного магазина
#     (применяется к ценам стока один раз при открытии; SCRUM-996).
#   combat: {"type": "battle"|"elite", "enemy_health_multiplier": float,
#            "money_multiplier": float, "xp_multiplier": float}
#     — исход-бой (reveal-шаг не показывается: исход боя — сам бой).
#   post_combat: Dictionary — награда за победу в исходе-бое. ТОЛЬКО
#     stats/mods/heal_percent (+ опц. shop_after/shop_discount): рантайм
#     применяет post_combat через Player.apply_reward, а money/random_artifact
#     он молча игнорирует (гард — event_data_contract_check). «Больше добычи»
#     за событийный бой выражай combat.money_multiplier/xp_multiplier.
# ============================================================================
# SCRUM-995: полированный стартовый пак — ровно 12 событий, 3 выбора у каждого
# (безопасный / рискованный / умный-чековый либо моральная альтернатива).
# id закреплены оркестратором: на них завязаны фоны SCRUM-998 и UI SCRUM-997
# (sudden_fork/sacrifice_altar дополнительно штампуются узлами hazard/altar в
# route_map_screen.gd). Балансовая голден-таблица EV — progression_balance.md
# §Random Events EV; инварианты — event_data_smoke_test / event_risk_reward_ev_test.
const RANDOM_EVENTS := [
	{
		# Флагман AC SCRUM-995: три стороны одного налёта — караван, бандиты или
		# собственный карман. Обе боевые ветки ведут к разной добыче (лавка со
		# скидкой vs жирный кошель с проклятием молвы), чек — добыча без боя.
		"id": "caravan_bandits",
		"title": "Караван под ударом",
		"story": "Головная повозка каравана завалилась набок, в борту дрожат стрелы. Бандиты стягивают кольцо, охрана торговца пятится к обозу. Главарь машет тебе: «Вставай к нам — добра хватит на всех». Торговец кричит, что заплатит вдвое.",
		"tags": {"acts": [], "biomes": []},
		"choices": [
			{
				"id": "defend_caravan", "title": "Вступиться за караван",
				"description": "Бой с бандитами: победа — +30% золота за бой, +1 Лидерство и лавка торговца со скидкой 25%.",
				"risk": true,
				"combat": {"type": "battle", "enemy_health_multiplier": 1.15, "money_multiplier": 1.3},
				"post_combat": {"stats": {"leadership": 1}, "shop_after": true, "shop_discount": 0.25},
			},
			{
				"id": "join_bandits", "title": "Встать за бандитов",
				"description": "Бой с охраной: +75% золота за бой и +1 Сила, но дурная слава — враги на 6% живучее до конца забега.",
				"risk": true,
				"combat": {"type": "battle", "enemy_health_multiplier": 1.22, "money_multiplier": 1.75, "xp_multiplier": 1.2},
				"post_combat": {"stats": {"strength": 1}, "mods": {"enemy_health_multiplier": 1.06}},
			},
			{
				"id": "rob_and_run", "title": "Ограбить и сбежать",
				"description": "Проверка Ловкости 7: успех — +45 золота из бесхозных сундуков без боя, провал — стрела (10 урона) и бой.",
				"check": {"stat": "agility", "difficulty": 7},
				"success": {"money": 45, "outcome_text": "Пока сталь звенит о сталь, ты срезаешь кошели с обеих сторон и растворяешься в пыли."},
				"failure": {"damage_flat": 10, "combat": {"type": "battle", "enemy_health_multiplier": 1.15, "money_multiplier": 1.2}, "outcome_text": "Стрела находит тебя раньше, чем тень. Теперь придётся драться."},
			},
		],
	},
	{
		# SCRUM-608→995: узел hazard штампует event_id sudden_fork (route_map_screen).
		# Дух сохранён: безопасный обход / рискованный срез / чек-разведка.
		"id": "sudden_fork",
		"title": "Опасная развилка",
		"story": "Тропа расходится у гнилого верстового столба: широкая дуга обхода уводит в сторону, узкий срез ныряет в тёмную теснину. Между камней мелькают тени — срез явно кем-то облюбован. Решай, чем платить: временем или кровью.",
		"tags": {"acts": [], "biomes": []},
		"choices": [
			{
				"id": "safe_detour", "title": "Пойти в обход",
				"description": "Без риска: +12 золота попутной торговлей и передышка (лечение 15% HP).",
				"money": 12, "heal_percent": 0.15,
			},
			{
				"id": "risky_shortcut", "title": "Срезать через теснину",
				"description": "Бой в теснине: победа — +50% золота за бой, +1 Сила и +6% урона до конца забега.",
				"risk": true,
				"combat": {"type": "battle", "enemy_health_multiplier": 1.16, "money_multiplier": 1.5},
				"post_combat": {"stats": {"strength": 1}, "mods": {"damage_multiplier": 1.06}},
			},
			{
				"id": "scout_ahead", "title": "Разведать тропу",
				"description": "Проверка Восприятия 6: успех — тайник дозорных (+16 золота, +1 Восприятие), провал — растяжка (−10% HP).",
				"check": {"stat": "perception", "difficulty": 6},
				"success": {"money": 16, "stats": {"perception": 1}, "outcome_text": "Ты замечаешь растяжку, а за ней — тайник дозорных: монеты и добрая примета, что тени ушли."},
				"failure": {"health_percent_cost": 0.10, "outcome_text": "Щёлкает растяжка — камнепад оставляет ссадины, но тропа впереди свободна."},
			},
		],
	},
	{
		# SCRUM-610→995: узел altar штампует event_id sacrifice_altar (route_map_screen).
		# Постоянная сделка тело/золото-за-силу, allow_skip сохранён (уйти можно).
		"id": "sacrifice_altar",
		"title": "Алтарь жертвы",
		"story": "Алтарь сложен из костей тех, кто уже заключал сделку. Он не торгуется и не лжёт: за плоть и золото платит силой, и платёж этот навсегда. Чем страшнее цена, тем тяжелее дар.",
		"allow_skip": true,
		"tags": {"acts": [], "biomes": []},
		"choices": [
			{
				"id": "offer_blood", "title": "Отдать кровь",
				"description": "Цена: 18% макс. HP — навсегда +2 Сила и +8% урона.",
				"health_percent_cost": 0.18, "stats": {"strength": 2}, "mods": {"damage_multiplier": 1.08},
				"outcome_text": "Кровь уходит в кость, как вода в песок. Взамен в мышцы вливается чужая, злая сила.",
			},
			{
				"id": "offer_flesh", "title": "Отдать плоть",
				"description": "Цена: 28% макс. HP — навсегда +2 Ловкость и +12% скорости атаки.",
				"health_percent_cost": 0.28, "stats": {"agility": 2}, "mods": {"attack_speed_multiplier": 1.12},
				"outcome_text": "Алтарь берёт своё без ножа. Тело становится легче — и быстрее, чем когда-либо.",
			},
			{
				"id": "offer_gold", "title": "Выкупить чужой дар",
				"description": "Цена: 26 золота — навсегда +1 Выносливость, +1 Энергия и +4% защиты.",
				"cost_money": 26, "stats": {"endurance": 1, "energy": 1}, "mods": {"defense_flat": 0.04},
				"outcome_text": "Монеты плавятся на костях. Чей-то недоплаченный дар переходит к тебе — без крови, но и без размаха.",
			},
		],
	},
	{
		# Магазин без боя: платный вход / чек-лазейка с подарком и скидкой / уйти.
		"id": "night_market",
		"title": "Ночной рынок",
		"story": "Под обрушенным мостом мерцают воровские фонари: контрабандисты разложили товар, какого не сыщешь днём. Вход стережёт вышибала с пудовыми кулаками. Чужаков здесь не любят, но золото любят сильнее.",
		"tags": {"acts": [], "biomes": []},
		"choices": [
			{
				"id": "pay_entry", "title": "Заплатить за вход",
				"description": "Цена: 20 золота — пропуск к прилавкам контрабандистов.",
				"cost_money": 20, "shop_after": true,
				"outcome_text": "Монеты исчезают в перчатке вышибалы. Перед тобой раскладывают товар, какого не увидишь при свете дня.",
			},
			{
				"id": "find_gap", "title": "Найти лазейку",
				"description": "Проверка Восприятия 7: успех — внутрь без платы, кошель «за молчание» (+12 золота) и скидка 15%, провал — кулаки вышибалы (8 урона).",
				"check": {"stat": "perception", "difficulty": 7},
				"success": {"money": 12, "shop_after": true, "shop_discount": 0.15, "outcome_text": "Ты находишь дыру в ограждении и знакомое лицо: тебя проводят как своего и суют кошель «за молчание»."},
				"failure": {"damage_flat": 8, "outcome_text": "Вышибала замечает тебя первым. Аргументов у него два, и оба пудовые."},
			},
			{
				"id": "walk_on", "title": "Пройти мимо",
				"description": "Ночные сделки не для тебя — уйти, ничего не потеряв.",
			},
		],
	},
	{
		# Hidden-молитва (2 честных исхода) / чек-крипта (артефакт или проклятие
		# с боем) / безопасный обыск.
		"id": "cursed_chapel",
		"title": "Заброшенная часовня",
		"story": "Часовня давно забыла своего бога: скамьи сгнили, фрески выцвели до пятен. Под алтарём — плита крипты в цепях, и на ней свежие царапины. Изнутри.",
		"tags": {"acts": [], "biomes": []},
		"choices": [
			{
				"id": "whisper_prayer", "title": "Помолиться во тьме",
				"hidden": true,
				"unknown_hint": "Молитва в осквернённом месте — кто-нибудь да ответит. Вопрос — кто.",
				"random_outcomes": [
					{"stats": {"endurance": 1}, "heal_percent": 0.20, "outcome_text": "Отвечает не тот, кому молились, но дар настоящий: раны затягиваются, плоть каменеет."},
					{"damage_flat": 6, "mods": {"xp_gain_multiplier": 1.08}, "outcome_text": "Голос из-под плиты дерёт уши до крови — зато теперь ты понимаешь этот мир чуть лучше."},
				],
			},
			{
				"id": "break_crypt", "title": "Вскрыть крипту",
				"description": "Проверка Силы 8: успех — реликвия из гроба, провал — проклятие (+5% HP врагов) и бой с нежитью.",
				"check": {"stat": "strength", "difficulty": 8},
				"success": {"random_artifact": true, "outcome_text": "Цепи лопаются. Среди костей лежит то, что хоронили старательнее покойника."},
				"failure": {"mods": {"enemy_health_multiplier": 1.05}, "combat": {"type": "battle", "enemy_health_multiplier": 1.2, "money_multiplier": 1.25}, "outcome_text": "Плита трескается не туда: проклятие расползается по округе, а мертвецы встают размяться."},
			},
			{
				"id": "search_nave", "title": "Обыскать неф",
				"description": "Без риска: собрать по углам утварь и монеты (+14 золота).",
				"money": 14,
			},
		],
	},
	{
		# 2 из 3 выборов hidden (ставки с честным раскрытием), чек — поймать шулера.
		"id": "gilded_gambler",
		"title": "Позолоченный шулер",
		"story": "За складным столиком под фонарём сидит щёголь в золочёном плаще. Три карты порхают в его пальцах быстрее, чем успевает глаз. «Ставь, герой, — мурлычет он. — Сегодня удача пахнет твоими деньгами».",
		"tags": {"acts": [], "biomes": []},
		"choices": [
			{
				"id": "small_bet", "title": "Малая ставка",
				"hidden": true,
				"unknown_hint": "Ставка 10 золотых на три карты. Втрое — или в рукав шулера.",
				"cost_money": 10,
				"random_outcomes": [
					{"money": 30, "outcome_text": "Дама! Шулер морщится, отсчитывая тридцать монет, — и тасует быстрее."},
					{"outcome_text": "Пустышка. Десять монет ныряют в золочёный рукав, шулер разводит руками."},
				],
			},
			{
				"id": "big_bet", "title": "Всё или ничего",
				"hidden": true,
				"unknown_hint": "Ставка 25 золотых. Шулер обещает утроить — или заберёт всё с улыбкой.",
				"cost_money": 25,
				"random_outcomes": [
					{"money": 75, "outcome_text": "Три туза. Шулер бледнеет под пудрой и отдаёт втрое — руки его больше не танцуют."},
					{"outcome_text": "Крап был на твоей карте с самого начала. Двадцать пять монет уходят за стол."},
				],
			},
			{
				"id": "catch_the_hand", "title": "Схватить за руку",
				"description": "Проверка Восприятия 8: успех — поймать крап и стрясти 30 золота отступных, провал — громила бьёт первым (6 урона).",
				"check": {"stat": "perception", "difficulty": 8},
				"success": {"money": 30, "outcome_text": "Ты перехватываешь ладонь с краплёной картой. Отступные шулер отсчитывает молча."},
				"failure": {"damage_flat": 6, "outcome_text": "Пальцы шулера чисты как слеза. Зато у его громилы тяжёлая рука."},
			},
		],
	},
	{
		# Моральная развилка: помочь за золото / обобрать / пройти мимо («ничего»).
		"id": "wounded_mercenary",
		"title": "Раненый наёмник",
		"story": "У обочины сидит наёмник, зажимая разрубленный бок. Он не просит о жалости — просто смотрит, как ты подходишь, и прикидывает, что ты за человек. Рядом лежит его сумка с добычей за целый сезон.",
		"tags": {"acts": [], "biomes": []},
		"choices": [
			{
				"id": "patch_him_up", "title": "Перевязать и помочь",
				"description": "Цена: 18 золота на снадобья — наёмник в долгу: +1 Лидерство и +1 к призванным союзникам.",
				"cost_money": 18, "stats": {"leadership": 1}, "mods": {"summon_bonus": 1},
				"outcome_text": "Наёмник встаёт, пробует плечо и коротко кивает. Такие долги возвращают сталью — его выучка теперь при тебе.",
			},
			{
				"id": "rob_him", "title": "Обобрать раненого",
				"description": "Забрать сумку (+26 золота), но такое не забывается: −1 Знание.",
				"money": 26, "stats": {"knowledge": -1},
				"outcome_text": "Кошель тяжёлый, а взгляд раненого — ещё тяжелее. Что-то в тебе стало проще и глуше.",
			},
			{
				"id": "pass_by", "title": "Пройти мимо",
				"description": "Не твоя война — идти дальше, ничего не тратя.",
			},
		],
	},
	{
		# Класс-реактивное событие №1: три чека под разные архетипы
		# (endurance/intelligence/strength), провал любого — бой со стражем.
		"id": "stone_guardian",
		"title": "Каменный страж",
		"story": "Древние врата перегорожены исполином из серого камня. Глаза его вспыхивают: «Докажи, что достоин пройти, — телом, разумом или силой». Голос — как жернова, и неверный ответ он засчитывает в свою пользу.",
		"tags": {"acts": [], "biomes": []},
		"choices": [
			{
				"id": "hold_the_gate", "title": "Упереться в створ",
				"description": "Проверка Выносливости 7: успех — +1 Выносливость и +6% защиты, провал — страж нападает.",
				"check": {"stat": "endurance", "difficulty": 7},
				"success": {"stats": {"endurance": 1}, "mods": {"defense_flat": 0.06}, "outcome_text": "Ты держишь вес створа, пока страж считает до ста. Камень отступает — тело запоминает урок."},
				"failure": {"combat": {"type": "battle", "enemy_health_multiplier": 1.2, "money_multiplier": 1.25}, "outcome_text": "Колени подгибаются. Страж делает шаг вперёд — экзамен продолжится сталью."},
			},
			{
				"id": "read_the_glyphs", "title": "Прочесть глифы",
				"description": "Проверка Интеллекта 7: успех — +1 Интеллект и +6% урона, провал — страж нападает.",
				"check": {"stat": "intelligence", "difficulty": 7},
				"success": {"stats": {"intelligence": 1}, "mods": {"damage_multiplier": 1.06}, "outcome_text": "Глифы складываются в формулу пробоя. Страж скрипит — засчитано."},
				"failure": {"combat": {"type": "battle", "enemy_health_multiplier": 1.2, "money_multiplier": 1.25}, "outcome_text": "Глифы плывут перед глазами. Страж расценивает запинку как вызов."},
			},
			{
				"id": "test_of_arms", "title": "Испытание силой",
				"description": "Проверка Силы 9: успех — страж выносит реликвию прежних победителей, провал — бой всерьёз.",
				"check": {"stat": "strength", "difficulty": 9},
				"success": {"random_artifact": true, "outcome_text": "Ты сдвигаешь стража на пядь — этого достаточно. Из-за врат он выносит реликвию прежних победителей."},
				"failure": {"combat": {"type": "battle", "enemy_health_multiplier": 1.25, "money_multiplier": 1.3}, "outcome_text": "Страж не двигается с места. Зато двигается его кулак."},
			},
		],
	},
	{
		# Риск/награда с random_outcomes: могила (артефакт или урон+бой) /
		# безопасное почтение / чек-эпитафии.
		"id": "heroes_graveyard",
		"title": "Кладбище павших героев",
		"story": "Вместо крестов из земли торчат старые клинки — по рукоять. На ближайшем выцарапано имя и свежая зарубка: кто-то проверял, не освободилось ли место. Говорят, героев здесь хоронили вместе с добычей.",
		"tags": {"acts": [], "biomes": []},
		"choices": [
			{
				"id": "dig_the_grave", "title": "Раскопать могилу",
				"description": "Потревожить павшего: в гробу либо его реликвия, либо он сам — злой и при оружии.",
				"risk": true,
				"random_outcomes": [
					{"random_artifact": true, "outcome_text": "Гроб пуст — почти. Оружие павшего ещё помнит, как драться, и не против сменить хозяина."},
					{"damage_flat": 8, "combat": {"type": "battle", "enemy_health_multiplier": 1.2, "money_multiplier": 1.35}, "post_combat": {"stats": {"endurance": 1}}},
				],
			},
			{
				"id": "honor_the_fallen", "title": "Почтить павших",
				"description": "Поклониться клинкам: +1 Выносливость и лечение 15% HP — мёртвые ценят уважение.",
				"stats": {"endurance": 1}, "heal_percent": 0.15,
			},
			{
				"id": "read_epitaphs", "title": "Прочесть эпитафии",
				"description": "Проверка Знания 7: успех — уроки чужих смертей (+1 Знание, +6% опыта), провал — порез о ржавый клинок (6 урона).",
				"check": {"stat": "knowledge", "difficulty": 7},
				"success": {"stats": {"knowledge": 1}, "mods": {"xp_gain_multiplier": 1.06}, "outcome_text": "Эпитафии складываются в одну науку: как не лечь рядом. Читается быстро, запоминается навсегда."},
				"failure": {"damage_flat": 6, "outcome_text": "Имена стёрты дождями. Зато ржавый клинок под ладонью — вполне настоящий."},
			},
		],
	},
	{
		# Hidden-монетка (3 честных исхода, включая «ничего») / хил / чек-нырок.
		"id": "old_well",
		"title": "Колодец желаний",
		"story": "Колодец стоит посреди тропы так, будто тропу проложили вокруг него. Из глубины тянет дождём и мокрой медью, на дне что-то поблёскивает. Табличка стёрта до двух слов: «…сбудется. Наверное».",
		"tags": {"acts": [], "biomes": []},
		"choices": [
			{
				"id": "toss_a_coin", "title": "Бросить монету",
				"hidden": true,
				"unknown_hint": "Одна монета (6 золотых) — и колодец сам решит, чем ответить.",
				"cost_money": 6,
				"random_outcomes": [
					{"money": 24, "outcome_text": "Колодец возвращает пригоршню чужих монет. Чьё-то желание, видимо, отменили."},
					{"heal_percent": 0.30, "outcome_text": "Вода вспыхивает тёплым светом, и раны затягиваются на глазах."},
					{"outcome_text": "Монета падает беззвучно. Сегодня колодец глух к желаниям."},
				],
			},
			{
				"id": "draw_water", "title": "Набрать воды",
				"description": "Без риска: студёная вода лечит 25% HP.",
				"heal_percent": 0.25,
			},
			{
				"id": "dive_down", "title": "Нырнуть за блеском",
				"description": "Проверка Ловкости 8: успех — вещь, которую загадали до тебя, провал — 9 урона о тесные стены.",
				"check": {"stat": "agility", "difficulty": 8},
				"success": {"random_artifact": true, "outcome_text": "На дне, среди ила и монет, лежит вещь, которую кто-то пожелал слишком сильно."},
				"failure": {"damage_flat": 9, "outcome_text": "Стены уже, чем казались, а дно — твёрже. Блеск оказался водой на камне."},
			},
		],
	},
	{
		# Elite-бой с жирным post_combat / обход с потерей / чек-диверсия.
		"id": "war_drums_camp",
		"title": "Барабаны за холмом",
		"story": "За холмом дымит военный лагерь орды: частокол, дозорные, барабаны в самом сердце. Утром они снимутся и пойдут жечь тракт, а пока — пьют. Лучшего случая ударить, проскользнуть или напакостить не будет.",
		"tags": {"acts": [], "biomes": []},
		"choices": [
			{
				"id": "storm_the_camp", "title": "Ударить по лагерю",
				"description": "Элитный бой с вожаком орды: победа — +60% золота и +30% опыта за бой, +1 Сила, +1 Лидерство и +6% урона.",
				"risk": true,
				"combat": {"type": "elite", "enemy_health_multiplier": 1.12, "money_multiplier": 1.6, "xp_multiplier": 1.3},
				"post_combat": {"stats": {"strength": 1, "leadership": 1}, "mods": {"damage_multiplier": 1.06}},
			},
			{
				"id": "slip_past", "title": "Обойти оврагом",
				"description": "Тихо уйти по колючему оврагу, оставив лагерь за спиной (−6% HP о терновник).",
				"health_percent_cost": 0.06,
			},
			{
				"id": "cut_the_drums", "title": "Порезать барабаны",
				"description": "Проверка Ловкости 8: успех — унести походную кассу (+22 золота, +6% опыта), провал — стрела дозорного (10 урона) и бой.",
				"check": {"stat": "agility", "difficulty": 8},
				"success": {"money": 22, "mods": {"xp_gain_multiplier": 1.06}, "outcome_text": "Кожа барабанов расходится беззвучно, а походная касса сама напрашивается в руки. Утром орда проспит."},
				"failure": {"damage_flat": 10, "combat": {"type": "battle", "enemy_health_multiplier": 1.15, "money_multiplier": 1.2}, "outcome_text": "Дозорный оказывается трезвее, чем выглядел. Стрела — и тревога поднимает лагерь."},
			},
		],
	},
	{
		# Класс-реактивное событие №2 (intelligence/strength): статы/моды за HP-цену,
		# осколок как артефакт через силовой чек.
		"id": "fallen_star",
		"title": "Упавшая звезда",
		"story": "В дымящемся кратере остывает осколок неба — горячий, как свежая рана, и будто живой. Трава вокруг сгорела в стекло. Он тянется к руке — или это рука сама тянется к нему.",
		"tags": {"acts": [], "biomes": []},
		"choices": [
			{
				"id": "grab_the_shard", "title": "Схватить голыми руками",
				"description": "Стерпеть звёздный ожог (−12% HP) — осколок отдаст силу: +2 Энергия.",
				"health_percent_cost": 0.12, "stats": {"energy": 2},
				"outcome_text": "Ладони шипят, но жар уходит внутрь и остаётся там силой чужого неба.",
			},
			{
				"id": "study_the_light", "title": "Изучить свечение",
				"description": "Проверка Интеллекта 7: успех — +1 Энергия и +1 Знание, провал — вспышка (7 урона).",
				"check": {"stat": "intelligence", "difficulty": 7},
				"success": {"stats": {"energy": 1, "knowledge": 1}, "outcome_text": "Свечение пульсирует, как чужой код. Ты читаешь его — и часть прочитанного остаётся в тебе."},
				"failure": {"damage_flat": 7, "outcome_text": "Осколок огрызается вспышкой. Перед глазами долго стоит белое."},
			},
			{
				"id": "pry_it_loose", "title": "Выломать из кратера",
				"description": "Проверка Силы 8: успех — остывший осколок становится реликвией, провал — ожог о стеклянные края (8 урона).",
				"check": {"stat": "strength", "difficulty": 8},
				"success": {"random_artifact": true, "outcome_text": "Осколок поддаётся и остывает в руках. Теперь это оружие — или почти оружие."},
				"failure": {"damage_flat": 8, "outcome_text": "Стеклянные края крошатся под пальцами и режут глубже, чем звёздный жар."},
			},
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


# SCRUM-996: context — опциональный контекст отбора ({"act": int, ...}).
# Событие с непустым tags.acts допустимо только при совпадении context.act;
# события без тегов (весь текущий пул) и вызовы без context работают как раньше.
static func pick_event(used_ids: Array, rng: RandomNumberGenerator, context: Dictionary = {}) -> Dictionary:
	var pool := []
	for event in RANDOM_EVENTS:
		if _event_allowed_in_context(event, context):
			pool.append(event)
	if pool.is_empty():
		# Ни одно событие не подходит под контекст (например, все act-теги чужие) —
		# безопасный фолбэк на весь пул: событие лучше пустого экрана.
		pool = RANDOM_EVENTS.duplicate()
	var available := []
	for event in pool:
		if not used_ids.has(str(event.get("id", ""))):
			available.append(event)
	if available.is_empty():
		used_ids.clear()
		available = pool.duplicate()
	var index := 0
	if rng != null and available.size() > 1:
		index = rng.randi_range(0, available.size() - 1)
	return (available[index] as Dictionary).duplicate(true)


# SCRUM-996: фильтр контекста отбора. Пустые теги = событие всюду допустимо.
# tags.biomes зарезервировано (фильтр по биому пока не применяется).
static func _event_allowed_in_context(event: Dictionary, context: Dictionary) -> bool:
	if context.is_empty():
		return true
	var tags_raw = event.get("tags", {})
	if not (tags_raw is Dictionary):
		return true
	var acts_raw = (tags_raw as Dictionary).get("acts", [])
	if context.has("act") and acts_raw is Array and not (acts_raw as Array).is_empty():
		return (acts_raw as Array).has(int(context.get("act", 0)))
	return true
