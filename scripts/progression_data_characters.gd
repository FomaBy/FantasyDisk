extends RefCounted

# SCRUM-198: character, stat and class identity data. ProgressionData keeps compatibility aliases.

const STAT_NAMES := {
	"strength": "Сила",
	"agility": "Ловкость",
	"intelligence": "Интеллект",
	"perception": "Восприятие",
	"energy": "Энергия",
	"knowledge": "Знание",
	"endurance": "Выносливость",
	"leadership": "Лидерство",
}

const BASE_STATS := {
	"berserk": {
		"strength": 10.0,
		"agility": 5.0,
		"intelligence": 2.0,
		"perception": 5.0,
		"energy": 4.0,
		"knowledge": 4.0,
		"endurance": 7.0,
		"leadership": 3.0,
	},
	"soldier": {
		"strength": 7.0,
		"agility": 6.0,
		"intelligence": 2.0,
		"perception": 8.0,
		"energy": 4.0,
		"knowledge": 5.0,
		"endurance": 6.0,
		"leadership": 5.0,
	},
	"thief": {
		"strength": 5.0,
		"agility": 9.0,
		"intelligence": 3.0,
		"perception": 8.0,
		"energy": 5.0,
		"knowledge": 4.0,
		"endurance": 4.0,
		"leadership": 5.0,
	},
	"elementalist": {
		"strength": 2.0,
		"agility": 4.0,
		"intelligence": 9.0,
		"perception": 7.0,
		"energy": 8.0,
		"knowledge": 6.0,
		"endurance": 3.0,
		"leadership": 5.0,
	},
	"sniper": {
		"strength": 6.0,
		"agility": 8.0,
		"intelligence": 2.0,
		"perception": 10.0,
		"energy": 3.0,
		"knowledge": 3.0,
		"endurance": 7.0,
		"leadership": 1.0,
	},
	"priest": {
		"strength": 2.0,
		"agility": 4.0,
		"intelligence": 8.0,
		"perception": 6.0,
		"energy": 7.0,
		"knowledge": 9.0,
		"endurance": 5.0,
		"leadership": 6.0,
	},
	"biologist": {
		"strength": 2.0,
		"agility": 5.0,
		"intelligence": 8.0,
		"perception": 7.0,
		"energy": 6.0,
		"knowledge": 10.0,
		"endurance": 4.0,
		"leadership": 4.0,
	},
	"robot": {
		"strength": 8.0,
		"agility": 3.0,
		"intelligence": 5.0,
		"perception": 5.0,
		"energy": 7.0,
		"knowledge": 4.0,
		"endurance": 10.0,
		"leadership": 4.0,
	},
	"engineer": {
		"strength": 4.0,
		"agility": 5.0,
		"intelligence": 7.0,
		"perception": 6.0,
		"energy": 6.0,
		"knowledge": 6.0,
		"endurance": 5.0,
		"leadership": 10.0,
	},
	"dark_mage": {
		"strength": 2.0,
		"agility": 3.0,
		"intelligence": 10.0,
		"perception": 5.0,
		"energy": 7.0,
		"knowledge": 6.0,
		"endurance": 3.0,  # SCRUM-783: 2.0→3.0 — поднять пол выживаемости (EHP ~34.6→~50,
		# уровень aoe-стекла elementalist/chemist). Остаётся самым хрупким aoe-классом, но
		# не умирает от одного касания. survival-tier/damage-таргеты НЕ затронуты (отдельный label).
		"leadership": 5.0,
	},
	"guitarist": {
		"strength": 4.0,
		"agility": 6.0,
		"intelligence": 4.0,
		"perception": 7.0,
		"energy": 6.0,
		"knowledge": 5.0,
		"endurance": 4.0,
		"leadership": 7.0,
	},
	"assassin": {"strength": 6.0, "agility": 10.0, "intelligence": 2.0, "perception": 6.0, "energy": 3.0, "knowledge": 4.0, "endurance": 5.0, "leadership": 4.0},
	"ranger": {"strength": 7.0, "agility": 7.0, "intelligence": 2.0, "perception": 9.0, "energy": 4.0, "knowledge": 4.0, "endurance": 4.0, "leadership": 3.0},
	"doctor": {"strength": 2.0, "agility": 4.0, "intelligence": 8.0, "perception": 5.0, "energy": 6.0, "knowledge": 8.0, "endurance": 5.0, "leadership": 2.0},
	"chemist": {"strength": 2.0, "agility": 4.0, "intelligence": 9.0, "perception": 6.0, "energy": 7.0, "knowledge": 7.0, "endurance": 3.0, "leadership": 2.0},
	"knight": {"strength": 8.0, "agility": 3.0, "intelligence": 2.0, "perception": 4.0, "energy": 3.0, "knowledge": 4.0, "endurance": 10.0, "leadership": 6.0},
	"druid": {"strength": 3.0, "agility": 4.0, "intelligence": 4.0, "perception": 7.0, "energy": 6.0, "knowledge": 5.0, "endurance": 5.0, "leadership": 9.0},
}

const CHARACTER_CONFIGS := {
	# SCRUM-887: описания = что ожидать от геймплея (дистанция, темп, риск, за
	# счет чего убивает/выживает); сильные/слабые — только правда по механикам.
	"berserk": {
		"id": "berserk",
		"title": "Берсерк",
		"description": "Ближний рубака: тяжелые двуручные замахи кладут толпу вокруг. Живет в гуще боя — риск велик, но и запас крови огромен.",
		"strengths": "тяжелый урон по толпе, большой запас здоровья, широкие дуги ударов.",
		"weaknesses": "должен подойти вплотную, дальних ответов нет.",
		"sprite_path": "res://assets/sprites/characters/full_frame/berserk_pixellab/berserk_idle_south.png",
	},
	"soldier": {
		"id": "soldier",
		"title": "Солдат",
		"description": "Стрелок средней дистанции с двойным спуском: каждое действие может произойти дважды. Взрывные пули, тяжелые гранаты с фитилем и штыковой конус вблизи.",
		"strengths": "шанс 50% на второе действие, взрывные пули с малым AoE, тяжелые гранаты по скоплениям, штыковой конус вблизи.",
		"weaknesses": "граната требует ждать фитиль, по боссу пули слабее.",
		"sprite_path": "res://assets/sprites/characters/full_frame/soldier_pixellab/soldier_idle_south.png",
	},
	"thief": {
		# SCRUM-897: экономико-уклонительный трикстер — trait «Воровская
		# хватка» (магнит подбора) + монета с мгновенным золотом + яд-кинжал
		# контроля + дым-облако уклонения.
		"id": "thief",
		"title": "Вор",
		"description": "Плут-добытчик: добыча сама тянется к нему, монеты скачут рикошетом и тут же пополняют кошель, яд-кинжал сковывает жертву, а дымовое облако укрывает от ударов. Хрупок, но верток.",
		"strengths": "магнит добычи (радиус подбора), рикошеты с мгновенным золотом, паралич-яд, уклонение в дыму.",
		"weaknesses": "мало здоровья, ошибку вплотную не прощает.",
		"sprite_path": "res://assets/sprites/characters/full_frame/thief_pixellab/thief_idle_south.png",
	},
	"elementalist": {
		# SCRUM-947..950: чистый маг зон — trait «Проводник стихий» (магические
		# бонусы на 30% эффективнее) + кит квадрат/полнокартный X/тяжёлый метеор.
		"id": "elementalist",
		"title": "Элементалист",
		"description": "Проводник стихий: бонусы магического урона для него на 30% эффективнее. Квадрат четырёх стихий, X-разлом во всю карту и тяжёлый метеор накрывают области — смертоносен в своих зонах и хрупок вне их.",
		"strengths": "усиленный рост магии (бонусы ×1.3), огромные зоны, контроль отбросом.",
		"weaknesses": "хрупкий, медленные тяжёлые касты, требует позиции и расчета.",
		"sprite_path": "res://assets/sprites/characters/full_frame/elementalist_pixellab/elementalist_idle_south.png",
	},
	"sniper": {
		"id": "sniper",
		"title": "Снайпер",
		"description": "Дальнобойный ликвидатор: выцеливает жертву, пробивает ее насквозь и размечает зоны смерти. Смертелен издали, беззащитен вплотную.",
		"strengths": "огромная дальность, тяжелые точные выстрелы, криты, фокус элит.",
		"weaknesses": "слаб против толпы вплотную.",
		"sprite_path": "res://assets/sprites/characters/full_frame/sniper_pixellab/sniper_idle_south.png",
	},
	"priest": {
		"id": "priest",
		"title": "Священник",
		"description": "Боевой пастырь: печати и молитвы жгут нечисть на средней дистанции, а часть причиненной боли возвращается ему лечением.",
		"strengths": "постоянное самолечение, защитные волны, цепные молитвы, ровный урон.",
		"weaknesses": "нет взрывного урона по одной цели.",
		"sprite_path": "res://assets/sprites/characters/full_frame/priest_pixellab/priest_idle_south.png",
	},
	"biologist": {
		"id": "biologist",
		"title": "Биолог",
		"description": "Испытатель плоти: споры замедляют толпу вплотную, луч-инъектор пробивает ряды насквозь, а дальнее семя прорастает заразой. Заражённые получают от него больше прямого урона.",
		"strengths": "урон со временем, замедление толпы, гибкие оси сборки (физика/магия/DoT), добивание заражённых.",
		"weaknesses": "хрупкость, медленный разгон, споры бьют только рядом.",
		"sprite_path": "res://assets/sprites/characters/full_frame/biologist_pixellab/biologist_idle_south.png",
	},
	"robot": {
		"id": "robot",
		"title": "Робот",
		"description": "Ходячая крепость: стягивает врагов магнитом, давит прессом и жжет выбросами реактора. Медлителен, зато почти неубиваем.",
		"strengths": "огромная живучесть, стягивание врагов, контроль толпы, ровный урон.",
		"weaknesses": "медлителен, любит верную позицию.",
		"sprite_path": "res://assets/sprites/characters/full_frame/robot_pixellab/robot_idle_south.png",
	},
	"engineer": {
		"id": "engineer",
		"title": "Инженер",
		"description": "Мастер расстановки: турели бьют сами, дроны чинят, мины стерегут подходы. Побеждает подготовкой поля, а не собственной рукой.",
		"strengths": "самостоятельные турели, ремонт на ходу, минный контроль подходов.",
		"weaknesses": "слаб, пока устройства не расставлены.",
		"sprite_path": "res://assets/sprites/characters/full_frame/engineer_pixellab/engineer_idle_south.png",
	},
	"dark_mage": {
		"id": "dark_mage",
		"title": "Темный маг",
		# SCRUM-939..941/1007: кит = цепной снаряд / curse-прожиг / зеркальные
		# взрывы; trait «Тёмный распад» — убитые магом взрываются сами.
		"description": "Стеклянная пушка: цепные снаряды, проклятия и парные взрывы выжигают целые области издали, а убитые им враги взрываются сами. Убивает раньше, чем до него дойдут, — иначе умрет сам.",
		"strengths": "мощный урон по области, цепные рикошеты, быстрые проклятия, взрывы убитых врагов.",
		"weaknesses": "самый хрупкий, вблизи обречен.",
		"sprite_path": "res://assets/sprites/characters/full_frame/dark_mage_pixellab/dark_mage_idle_south.png",
	},
	"guitarist": {
		"id": "guitarist",
		# SCRUM-899/SCRUM-1006: магический кастер с деплой-геймплеем и trait'ом
		# «Разогрев» — тексты без звука-как-стата (звук = флейвор магии).
		"title": "Гитарист",
		"description": "Магический кастер сцены: узкий рифф бьет вперед, бас-кольцо расталкивает, усилители гремят сами. Пока не ловит удары — разогревается и бьет магией больнее.",
		"strengths": "магический AoE-контроль, деплой-усилители, разогрев без урона, кайт.",
		"weaknesses": "по боссам заметно слабее; полученный удар сбрасывает разогрев.",
		"sprite_path": "res://assets/sprites/characters/full_frame/guitarist_pixellab/guitarist_idle_south.png",
	},
	"assassin": {
		"id": "assassin", "title": "Ассасин",
		# SCRUM-894: описание обязано явно заявлять кап крита 100% и опору на
		# крит-урон + уворот/позиционирование (копирайт-пасс — SCRUM-952).
		"description": "Хладнокровие: единственный класс, разгоняющий шанс крита до 100% — и каждый крит жиреет от крит-урона. Чакрамы режут туда и обратно дугой, кинжалы шинкуют в упор, струна душит ядом. Выживает уворотом и позиционированием, не здоровьем.",
		"strengths": "кап крита 100%, рост от крит-урона, темп, уворот и теневая завеса, яд.",
		"weaknesses": "мало здоровья, промах стоит крови.",
		"sprite_path": "res://assets/sprites/characters/full_frame/assassin_pixellab/assassin_idle_south.png",
	},
	"ranger": {
		"id": "ranger", "title": "Рейнджер",
		"description": "Терпеливый охотник: стоит на месте — выстрел заряжается и пробивает ряд насквозь. Капканы стерегут тех, кто подберется.",
		"strengths": "дальние пробивающие выстрелы, награда за стойку, капканы.",
		"weaknesses": "вблизи и на бегу заметно слабее.",
		"sprite_path": "res://assets/sprites/characters/full_frame/ranger_pixellab/ranger_idle_south.png",
	},
	"doctor": {
		"id": "doctor", "title": "Доктор",
		"description": "Врач без жалости: лечит себя зельем, чумой и пилой — и только ими. Каждая рана врага — его лекарство; не бьет — не лечится, а чужие снадобья на него не действуют.",
		"strengths": "лечение собственным уроном, чума на всю карту, живучесть в затяжном бою.",
		"weaknesses": "низкий разовый урон; внешние регенерация и вампиризм не работают.",
		"sprite_path": "res://assets/sprites/characters/full_frame/doctor_pixellab/doctor_idle_south.png",
	},
	"chemist": {
		"id": "chemist", "title": "Химик",
		"description": "Алхимик выжженной земли: взрывы, кислотные лужи и пара гомункулов превращают арену в отраву. Хрупок — пусть работает химия.",
		"strengths": "перманентные кислотные заряды, усиленная периодика («Катализатор»: +50%), быстрые взрывы по области, гомункулы танк и кастер.",
		"weaknesses": "хрупкий, урону нужно время.",
		"sprite_path": "res://assets/sprites/characters/full_frame/chemist_pixellab/chemist_idle_south.png",
	},
	"knight": {
		"id": "knight", "title": "Рыцарь",
		"description": "Латная стена: держит удар щитом, отвечает контрударом и достает копьем через ряд. Медленный, зато почти не продавливается.",
		"strengths": "отличная защита и здоровье, блок с контрударом, контроль строя.",
		"weaknesses": "медленный, догоняет плохо.",
		"sprite_path": "res://assets/sprites/characters/full_frame/knight_pixellab/knight_idle_south.png",
	},
	"druid": {
		"id": "druid", "title": "Друид",
		"description": "Пастырь дикой стаи: звери рвут добычу по его слову, тернии и тотемы стерегут землю. Сам слаб — сила в своре и корнях.",
		"strengths": "стая зверей, терновые зоны, тотемы поддержки.",
		"weaknesses": "без стаи почти беспомощен.",
		"sprite_path": "res://assets/sprites/characters/full_frame/druid_pixellab/druid_idle_south.png",
	},
}

const ULTIMATE_CONFIGS := {
	"berserk": {"title": "Неистовство", "description": "На несколько секунд ускоряется и каждый удар поднимает эхо-волну.", "duration": 5.5, "radius": 180.0, "damage": 0.75, "damage_charge_rate": 0.030, "taken_charge_rate": 1.35, "boss_cap": 0.10},
	"soldier": {"title": "Приказ: Огонь", "description": "Серия прицельных залпов по ближайшим целям; сильнее по плотной толпе, но ограничена по боссу.", "duration": 0.0, "radius": 560.0, "damage": 1.08, "target_count": 9, "damage_charge_rate": 0.033, "taken_charge_rate": 1.12, "boss_cap": 0.09},
	"thief": {"title": "Большой Куш", "description": "Мгновенный налет по ближайшим целям: урон, золотые нити и небольшой денежный выигрыш.", "duration": 0.0, "radius": 500.0, "damage": 1.02, "target_count": 8, "damage_charge_rate": 0.036, "taken_charge_rate": 1.00, "boss_cap": 0.08},
	"elementalist": {"title": "Стихийная Сверхнова", "description": "Сверхнова четырех стихий взрывается вокруг героя и оставляет вторичные вспышки по ближайшим целям.", "duration": 0.0, "radius": 430.0, "damage": 1.18, "target_count": 6, "damage_charge_rate": 0.035, "taken_charge_rate": 1.04, "boss_cap": 0.10},
	"sniper": {"title": "Последний Выстрел", "description": "Снайпер отмечает опасные цели и выпускает серию смертельных дальних попаданий.", "duration": 0.0, "radius": 760.0, "damage": 1.35, "target_count": 5, "damage_charge_rate": 0.034, "taken_charge_rate": 0.95, "boss_cap": 0.10},
	"priest": {"title": "Хор Искупления", "description": "Священная волна поражает врагов вокруг и превращает часть урона в лечение.", "duration": 0.0, "radius": 410.0, "damage": 1.05, "target_count": 8, "heal_ratio": 0.45, "damage_charge_rate": 0.031, "taken_charge_rate": 1.22, "boss_cap": 0.08},
	"biologist": {"title": "Пробуждение Колонии", "description": "Биолог запускает рост живой колонии: несколько биоимпульсов поражают ближайших врагов и оставляют слабый реген.", "duration": 0.0, "radius": 440.0, "damage": 1.10, "target_count": 9, "heal_ratio": 0.18, "damage_charge_rate": 0.033, "taken_charge_rate": 1.05, "boss_cap": 0.09},
	"robot": {"title": "Аварийная Перегрузка", "description": "Робот включает аварийный контур: получает временное поглощение, выпускает ударную волну и несколько раз прожигает ближайших врагов.", "duration": 4.5, "radius": 380.0, "damage": 0.78, "target_count": 8, "damage_charge_rate": 0.030, "taken_charge_rate": 1.55, "boss_cap": 0.08},
	"engineer": {"title": "Аварийная Мастерская", "description": "Инженер быстро разворачивает временную сеть устройств: лучи, ремонт и взрывные узлы вокруг себя.", "duration": 4.2, "radius": 430.0, "damage": 0.92, "target_count": 9, "heal_ratio": 0.12, "damage_charge_rate": 0.031, "taken_charge_rate": 1.18, "boss_cap": 0.08},
	"dark_mage": {"title": "Темная буря", "description": "Вихрь темной магии проклинает всех врагов вокруг.", "duration": 0.0, "radius": 360.0, "damage": 1.35, "damage_charge_rate": 0.034, "taken_charge_rate": 1.05, "boss_cap": 0.11},
	"guitarist": {"title": "Соло", "description": "Гигантская волна магического резонанса отбрасывает и глушит толпу.", "duration": 0.0, "radius": 430.0, "damage": 1.15, "damage_charge_rate": 0.033, "taken_charge_rate": 1.10, "boss_cap": 0.09},
	"assassin": {"title": "Танец клинков", "description": "Серия мгновенных рывков-ударов по ближайшим целям.", "duration": 0.0, "radius": 520.0, "damage": 1.05, "target_count": 7, "damage_charge_rate": 0.036, "taken_charge_rate": 1.05, "boss_cap": 0.08},
	"ranger": {"title": "Лунный залп", "description": "Дождь болтов поражает большую область вокруг героя.", "duration": 0.0, "radius": 480.0, "damage": 1.18, "target_count": 14, "damage_charge_rate": 0.034, "taken_charge_rate": 1.0, "boss_cap": 0.09},
	"doctor": {"title": "Переливание", "description": "Массовый drain врагов вокруг; избыток лечения становится щитом-поглощением.", "duration": 0.0, "radius": 360.0, "damage": 0.95, "damage_charge_rate": 0.032, "taken_charge_rate": 1.25, "boss_cap": 0.08},
	"chemist": {"title": "Цепная реакция", "description": "Алхимический каскад детонирует ближайшие зоны и врагов.", "duration": 0.0, "radius": 420.0, "damage": 1.25, "damage_charge_rate": 0.034, "taken_charge_rate": 1.05, "boss_cap": 0.10},
	"knight": {"title": "Бастион", "description": "Короткая непробиваемость, таунт давления и усиленная контратака.", "duration": 5.0, "radius": 260.0, "damage": 0.70, "damage_charge_rate": 0.029, "taken_charge_rate": 1.55, "boss_cap": 0.07},
	"druid": {"title": "Зов стаи", "description": "Временно призывает сверхлимитную стаю союзников.", "duration": 6.0, "radius": 260.0, "damage": 0.80, "target_count": 4, "damage_charge_rate": 0.031, "taken_charge_rate": 1.10, "boss_cap": 0.08},
}

# SCRUM-935: data-driven реестр class traits (канон — docs/design/class_traits_registry.md).
# Ключи читаются generic-хуком Player.class_trait_value(key) без хардкода класса:
#   action_echo_chance — «Двойное действие»: шанс, что действие оружия создаст ОДНУ
#     полную копию себя (второй выстрел/бросок/укол). Копия помечена и НЕ роллит
#     новую копию — цепочки невозможны (см. ClassWeapon._maybe_fire_action_echo).
#   action_echo_delay — читаемый сдвиг копии в секундах (QA видит два действия).
#   on_kill_blast_radius / on_kill_blast_magic_ratio — «Тёмный распад»: он-килл
#     магический AoE вокруг жертвы (см. Player._trigger_class_on_kill_trait);
#     классы без этих ключей он-килл взрыва не имеют.
# Матожидание выхода оружия ×(1+chance) учтено в budget-модели
# (estimate_weapon_budget_for_stats) — budget_tuning_for компенсирует урон кита.
# Новые классы волны SCRUM-894..952 добавляют СВОИ записи сюда.
const CLASS_TRAITS := {
	"soldier": {
		"id": "double_action",
		"title": "Двойное действие",
		"description": "Каждое действие оружия с шансом 50% происходит дважды; копия не создает новых копий.",
		"action_echo_chance": 0.5,
		"action_echo_delay": 0.18,
	},
	"elementalist": {
		# SCRUM-947 «Проводник стихий»: bonus-effectiveness scaling — каждый
		# magic-tagged источник бонуса на 30% эффективнее (+15% → ~+19.5%).
		# Потребитель — точка агрегации magic-бонусов
		# ProgressionData.derived_parameters (порядок стакинга задокументирован
		# в docs/design/systems/characters_weapons.md, покрыт
		# tests/elementalist_kit_test.gd).
		"id": "elemental_conduit",
		"title": "Проводник стихий",
		"description": "Все бонусы к магическому урону на 30% эффективнее: источник «+15%» даёт около +20%. Каждый источник усиливается ровно один раз.",
		"magic_bonus_effectiveness": 1.30,
	},
	"dark_mage": {
		# SCRUM-1007 «Тёмный распад»: КВАЛИФИЦИРОВАННЫЕ убийства (killing-hit
		# feedback с player_owned=true: оружие класса, тики проклятия черепа,
		# ульта) взрываются магическим AoE вокруг жертвы. Урон = derived
		# magic_damage * on_kill_blast_magic_ratio — ФИКС ОТ СТАТОВ, а не доля
		# убившего хита: кит черепа добивает мелкими dot-тиками, и «доля хита»
		# обесценила бы trait (решение задокументировано в реестре).
		# АНТИ-РЕКУРСИЯ: урон взрыва помечен dark_decay=true, жертвы взрыва
		# новых взрывов не порождают. Покрыт tests/dark_mage_kit_test.gd.
		"id": "dark_decay",
		"title": "Тёмный распад",
		"description": "Убитые Тёмным магом враги взрываются магическим уроном по области; взрывы не порождают новых взрывов.",
		"on_kill_blast_radius": 120.0,
		"on_kill_blast_magic_ratio": 0.85,
	},
	"chemist": {
		# SCRUM-942 «Катализатор»: рантайм (player.periodic_damage_multiplier) и
		# формульный бюджет (_budget_dot_dps/_budget_pool_dps/_budget_pool_charge_dps/
		# _budget_summon_wave_dps) читают множитель ОТСЮДА — trait не «зашит» в
		# пайплайн и не протекает другим классам. «Периодическим» считается урон,
		# чей источник помечен damage_type="dot" в hit-контексте (тики луж /
		# DoT-тики оружия) либо навешен статусом с dot_damage через
		# StatusEffects.apply_status_from(источник, ...) — будущие оружия
		# опт-инятся этим же тегированием. Прямые хиты (physical/magic) множитель
		# НЕ трогает. Покрыто tests/chemist_kit_test.gd.
		"id": "catalyst",
		"title": "Катализатор",
		"description": "Весь периодический урон Химика усилен на +50%: DoT-тики, тики кислотных луж, перманентные кислотные заряды и волны гомункула-кастера. Прямые попадания (включая взрыв Взрывной пыли) не усиливаются.",
		"periodic_damage_multiplier": 1.5,
	},
	"thief": {
		# SCRUM-897 «Воровская хватка»: сильно увеличенный СТАРТОВЫЙ радиус
		# подбора — деньги, опыт и материалы сами тянутся к Вору (identity
		# класса, не бонус одного оружия). Потребитель — множитель базовой
		# (105 + perception×7) части pickup_radius в
		# ProgressionData.derived_parameters; flat-источники забега
		# (pickup_radius_flat) идут поверх БЕЗ усиления — рост ограничен.
		# Покрыт tests/thief_kit_test.gd.
		"id": "thief_grip",
		"title": "Воровская хватка",
		"description": "Стартовый радиус подбора почти вдвое больше обычного: деньги, опыт и материалы сами тянутся к Вору.",
		"pickup_radius_multiplier": 1.85,
	},
	"assassin": {
		# SCRUM-894 «Хладнокровие»: кап шанса крита Ассасина — 100% (у остальных
		# глобальный CRIT_CHANCE_CAP 55%), и крит-вложения не размываются
		# (diminishing-делитель CRIT_CHANCE_DIMINISH выключен). Избыток raw-крита
		# сверх капа переливается в крит-урон (crit_overflow_to_crit_damage;
		# итог всё равно ограничен CRIT_DAMAGE_CAP). Потребители —
		# ProgressionData.class_crit_profile → derived_parameters (crit_chance /
		# crit_damage_multiplier). veil_* — «Теневая завеса»: самоцентричная
		# аура уворота против ближнего прессинга (Player.current_dodge_chance:
		# бонус только когда враг внутри derived aura_radius; величина =
		# veil_dodge_bonus × buff_power, кап veil_dodge_cap; суммарный уворот
		# по-прежнему ≤ SURVIVABILITY_DODGE_CAP — бессмертия нет).
		# Покрыто tests/assassin_kit_test.gd.
		"id": "cold_blood",
		"title": "Хладнокровие",
		"description": "Кап шанса крита — 100% вместо 55%, крит-вложения окупаются полностью: избыток шанса сверх капа переходит в критический урон. Теневая завеса добавляет уворот, пока враги рядом.",
		"crit_chance_cap": 1.0,
		"crit_chance_diminish": 0.0,
		"crit_overflow_to_crit_damage": 0.5,
		"veil_dodge_bonus": 0.10,
		"veil_dodge_cap": 0.18,
	},
	"doctor": {
		# SCRUM-900 «Клятва чумного доктора»: сустейн ТОЛЬКО от собственного
		# оружия (heal_percent_of_damage → apply_drain_heal, per-second бюджет).
		# generic_sustain_blocked — точки отсечки generic-сустейна:
		#   1) пул наград: ProgressionData.is_reward_relevant не предлагает
		#      regen/vampirism/kill-heal/room-clear/low-HP regen (SCRUM-862 +
		#      trait-гейт; пометка reward["doctor_friendly"]=true пропускает);
		#   2) применение: Player._apply_reward_mods / apply_meta_skill_modifiers
		#      молча гасят запрещённые sustain-моды (см.
		#      ProgressionData.is_blocked_sustain_mod_key) для не-friendly наград;
		#   3) формула: derived_parameters отрезает базовый пассивный реген
		#      (константа+knowledge) — остаётся только doctor-friendly flat;
		#   4) рантайм: Player._apply_regeneration не добавляет lowhp_regen_bonus.
		# Doctor-friendly предметы применяются в обычные run-ключи и работают
		# штатными формулами (см. tests/doctor_kit_test.gd).
		"id": "plague_oath",
		"title": "Клятва чумного доктора",
		"description": "Лечится только собственным оружием: общие регенерация, вампиризм, лечение за убийства и зачистку боя на Доктора не действуют.",
		"generic_sustain_blocked": 1.0,
	},
	"biologist": {
		# SCRUM-1005 «Разбор образцов»: пока на цели живёт периодический эффект
		# САМОГО Биолога (status bio_infection с source_id владельца — см.
		# ClassWeapon._apply_bio_infection), его ПРЯМЫЕ хиты по этой цели
		# усилены ×infected_direct_hit_multiplier. Потребитель — generic-гейт в
		# ClassWeapon._damage_enemy: тики DoT (hit_type "dot") НЕ усиливаются
		# (не дублирует «Катализатор» Химика — у того сами тики), чужой или
		# истёкший статус бонуса не даёт (StatusEffects.has_dot_from_source).
		# Покрыт tests/biologist_kit_test.gd.
		"id": "sample_analysis",
		"title": "Разбор образцов",
		"description": "Враги под периодическим уроном Биолога получают на 20% больше его прямого урона: сначала заражай — потом добивай.",
		"infected_direct_hit_multiplier": 1.20,
	},
	"guitarist": {
		# SCRUM-1006 «Разогрев» (реестр SCRUM-953): пока Гитарист НЕ получает
		# фактического урона, его МАГИЧЕСКИЙ урон растёт на no_hit_magic_bonus_per_second
		# в секунду (линейно, детерминированно: 0→кап ровно за cap/ramp = 10с)
		# до капа no_hit_magic_bonus_cap. КВАЛИФИЦИРОВАННЫЙ удар (прошедший
		# гейты предотвращения в Player.take_damage) сбрасывает стек в 0;
		# полностью предотвращенные события — godmode, i-frames, невидимость,
		# уворот — НЕ сбрасывают (явное правило, покрыто тестом). Потребитель —
		# Player.meta_damage_multiplier ТОЛЬКО для hit-контекстов
		# damage_type=="magic": physical/dot оси и другие классы не затронуты;
		# деплой-ампы бьют через владельца → бонус покрывает весь кит SCRUM-899
		# и награждает кайт-петлю «бегай и расставляй усилители».
		# Покрыт tests/guitarist_kit_test.gd.
		"id": "warm_up",
		"title": "Разогрев",
		"description": "Пока Гитарист не получает урона, его магический урон растёт на +2% в секунду — до +20%. Полученный удар сбрасывает разогрев.",
		"no_hit_magic_bonus_per_second": 0.02,
		"no_hit_magic_bonus_cap": 0.20,
	},
	"druid": {
		# SCRUM-902 «Аура дикой силы»: ПОСТОЯННАЯ классовая аура урона с видимым
		# полупрозрачным радиусом (Player.WildForceAuraRing). Баффает ТОЛЬКО
		# Друида и его призывы (группа "allies" с owner_node == друид) внутри
		# derived aura_radius × wild_aura_radius_ratio; враги/чужие сущности не
		# затрагиваются. Величина = wild_aura_damage_bonus × buff_power, кап
		# wild_aura_damage_cap. Потребители:
		#   - призывы: статус "wild_force_aura" (damage_multiplier) в
		#     Player._update_class_status_auras → StatusEffects.damage_multiplier
		#     в ally_minion._try_attack (позиционный — призыв вне ауры не баффнут);
		#   - сам Друид: он всегда в центре собственной ауры, поэтому его хиты
		#     усиливаются безусловно через Player.meta_damage_multiplier
		#     (wild_aura_damage_multiplier).
		# Матожидание аура-баффа учтено budget-моделью
		# (ProgressionData.class_wild_aura_damage_factor в
		# estimate_weapon_budget_for_stats) — budget_tuning_for компенсирует урон
		# кита, инвестиции в buff_power/aura_radius сверх базы остаются наградой.
		# Покрыт tests/druid_kit_test.gd.
		"id": "wild_force_aura",
		"title": "Аура дикой силы",
		"description": "Постоянная аура с видимым радиусом усиливает урон Друида и его призывов; сила растёт от мощи баффов, радиус — от радиуса ауры.",
		"wild_aura_damage_bonus": 0.10,
		"wild_aura_damage_cap": 0.30,
		"wild_aura_radius_ratio": 0.85,
	},
}

const CLASS_MECHANIC_IDENTITIES := {
	"berserk": {
		"main_attribute": "strength",
		"identity_title": "Телесный напор",
			"summary": "Сила наливает двуручные замахи весом: чем она выше, тем шире и смертоноснее каждый удар по толпе.",
			"mechanic_tags": ["melee_geometry", "frontal_pressure", "crowd_control", "echo_weapon"],
			"weapon_identities": {
				"sword": "длинный узкий сектор 100 градусов для позиционирования",
				"axe": "широкий сектор 180 градусов для чистки толпы рядом",
				"hammer": "центральный круговой slam радиуса 150 с ростом от Radius",
			},
	},
	"soldier": {
		"main_attribute": "perception",
		"identity_title": "Двойное действие",
		"summary": "Каждое действие оружия Солдата с шансом 50% происходит дважды: второй выстрел, вторая граната, второй укол. Копия не создает новых копий.",
		"mechanic_tags": ["double_action", "explosive_bullet", "delayed_nuke", "melee_cone"],
		"weapon_identities": {
			"soldier_rifle": "быстрая взрывная пуля с малым AoE",
			"soldier_grenade": "медленная граната с длинным фитилем и тяжелым взрывом",
			"soldier_bayonet": "ближний штыковой конус с редкими выстрелами вдаль",
		},
	},
	"thief": {
		# SCRUM-897: trait «Воровская хватка» — источник истины в
		# docs/design/class_traits_registry.md; механика — запись CLASS_TRAITS
		# (pickup_radius_multiplier), потребитель — derived_parameters.
		"main_attribute": "agility",
		"identity_title": "Воровская хватка",
		"summary": "Ловкость — его монета, а хватка — его кошель: добыча сама тянется к Вору (стартовый радиус подбора почти вдвое выше), монеты рикошетят с мгновенной прибылью, яд-кинжал и дым дают окно на побег или добивание.",
		"mechanic_tags": ["pickup_magnet", "ricochet", "poison_control", "smoke_evasion"],
		"weapon_identities": {
			"thief_coin_pouch": "золотой рикошет по цепи целей с мгновенным воровством золота",
			"thief_shadow_cloak": "яд-кинжал из тени: паралич-окно и удар в спину без смещения героя",
			"thief_smoke_bomb": "бросок дыма: взрыв по области и облако уклонения",
		},
	},
	"elementalist": {
		# SCRUM-947: trait «Проводник стихий» — источник истины в
		# docs/design/class_traits_registry.md; механика — запись CLASS_TRAITS
		# (magic_bonus_effectiveness), потребитель — derived_parameters.
		"main_attribute": "intelligence",
		"identity_title": "Проводник стихий",
		"summary": "Интеллект складывает стихии в формулы, а трейт проводит их без потерь: каждый бонус магического урона на 30% эффективнее (+15% источник даёт ~+20%).",
		"mechanic_tags": ["magic_conduit", "square_field", "map_rift", "meteor_nuke"],
		"weapon_identities": {
			"elementalist_orb_ring": "квадрат четырёх стихий: три канала урона и отброс от центра",
			"elementalist_prism_focus": "полнокартный X-разлом с центральным пересечением",
			"elementalist_meteor_core": "самый медленный тяжёлый метеор с догорающей зоной",
		},
	},
	"sniper": {
		"main_attribute": "perception",
		"identity_title": "Точная ликвидация",
		"summary": "Восприятие — его прицел: чем зорче глаз, тем дальше бьет винтовка и тем шире зона, где врагу не выжить.",
		"mechanic_tags": ["precision", "marking", "long_range", "kill_zone"],
		"weapon_identities": {
			"sniper_deadeye_rifle": "дальний lockshot по приоритетной цели",
			"sniper_spotter_scope": "зона смерти, наказывающая проходящих врагов",
			"sniper_shatter_rounds": "разделяющийся выстрел по нескольким линиям",
		},
	},
	"priest": {
		"main_attribute": "knowledge",
		"identity_title": "Священная формула",
		"summary": "Знание — его псалтырь: чем оно глубже, тем крепче печати, злее кара и щедрее лечение от каждого удара.",
		"mechanic_tags": ["sanctify", "ward", "heal_conversion", "holy_chain"],
		"weapon_identities": {
			"priest_reliquary": "освящение зоны вокруг цели",
			"priest_censer": "ward-пульсы защиты и урона",
			"priest_chime": "цепная молитва между врагами",
		},
	},
	"biologist": {
		# SCRUM-896: кит редизайна — локальные споры+замедление / пирсинг-луч
		# с бурстом анализа / дальнее темпоральное семя; SCRUM-1005: trait
		# «Разбор образцов» — источник истины docs/design/class_traits_registry.md,
		# механика — запись CLASS_TRAITS (infected_direct_hit_multiplier).
		"main_attribute": "knowledge",
		"identity_title": "Биореакция",
		"summary": "Знание превращает врага в подопытного: споры замедляют, инъекции заражают, а по заражённым Биолог бьёт на 20% больнее.",
		"mechanic_tags": ["sample_analysis", "spores", "local_aoe_slow", "pierce_beam", "temporal_dot"],
		"weapon_identities": {
			"biologist_spore_lens": "локальные споровые кольца у персонажа: заражение + замедление",
			"biologist_sample_injector": "длинный пирсинг-луч с малым бурстом анализа на конце",
			"biologist_symbiote_seed": "дальнее семя: прорастание с задержкой и главный урон со временем",
		},
	},
	"robot": {
		"main_attribute": "endurance",
		"identity_title": "Бронеконтур",
		"summary": "Выносливость питает броню и реактор: чем крепче корпус, тем дольше машина держит натиск и давит в ответ.",
		"mechanic_tags": ["armor_loop", "magnet", "compression", "reactor_heat"],
		"weapon_identities": {
			"robot_magnetic_anchor": "магнитный якорь, стягивающий цель",
			"robot_hydraulic_press": "гидравлическая линия компрессии",
			"robot_reactor_core": "реакторная зона перегрева",
		},
	},
	"engineer": {
		"main_attribute": "leadership",
		"identity_title": "Мастерская приказов",
		"summary": "Лидерство командует железом: чем тверже рука мастера, тем больше турелей, дронов и мин служат ему разом.",
		"mechanic_tags": ["deployable_network", "device_command", "repair_support", "minefield"],
		"weapon_identities": {
			"engineer_sentry_wrench": "развёртка стационарных турелей и удержание зоны",
			"engineer_repair_drone": "repair drone с поддержкой",
			"engineer_pressure_mines": "pressure mines для контроля маршрутов",
		},
	},
	"dark_mage": {
		"main_attribute": "intelligence",
		"identity_title": "Темная формула",
		"summary": "Интеллект кормит тьму: чем острее ум, тем шире области распада и глубже вгрызаются проклятия.",
		# SCRUM-939..941/1007: кит редизайна — цепь/curse-прожиг/зеркало + он-килл распад.
		"mechanic_tags": ["curse", "chain", "dot", "aoe_burst", "mirror_blast", "on_kill_decay"],
		"weapon_identities": {
			"dark_book": "зеркальные парные AoE-взрывы вокруг мага",
			"cursed_skull": "curse-зона с быстрым тикающим прожигом (только dot-ось)",
			"dark_wand": "цепной рикошет-снаряд: до 3 целей, бурст на каждом попадании",
		},
	},
	"guitarist": {
		# SCRUM-899/SCRUM-1006: trait «Разогрев» — источник истины в
		# docs/design/class_traits_registry.md; механика — запись CLASS_TRAITS
		# (no_hit_magic_bonus_*), потребитель — Player.meta_damage_multiplier.
		"main_attribute": "leadership",
		"identity_title": "Разогрев",
		"summary": "Магический кастер сцены: пока не ловит удары — разогрев копит до +20% магического урона (+2%/сек), полученный удар обнуляет кураж. Лидерство держит на сцене больше усилителей и дольше.",
		"mechanic_tags": ["warm_up", "magic_caster", "kiting", "deploy_amp"],
		"weapon_identities": {
			"electric_guitar": "узкая передняя полоса частых магических риффов",
			"bass_guitar": "большое кольцо слабых частых бас-пульсов под кайт",
			"sound_amp": "деплой-усилители: магические AoE-турели на земле",
		},
	},
	"assassin": {
		# SCRUM-894: trait «Хладнокровие» — источник истины в
		# docs/design/class_traits_registry.md; механика — запись CLASS_TRAITS
		# (crit_chance_cap/diminish/overflow + veil_*), потребители —
		# derived_parameters и Player.current_dodge_chance.
		"main_attribute": "agility",
		"identity_title": "Хладнокровие",
		"summary": "Ловкость — его клинок: только Ассасин разгоняет шанс крита до 100%, избыток переливает в крит-урон, а теневая завеса помогает уворачиваться, пока враги дышат в спину.",
		"mechanic_tags": ["crit_cap_100", "boomerang_arc", "point_blank_flurry", "poison_line", "dodge_veil"],
		"weapon_identities": {
			"chakrams": "boomerang: прямой коридор туда, левая дуга обратно (двойной проход при позиционировании)",
			"shadow_daggers": "point-blank flurry вокруг себя + рывок темпа (скорость и уворот) после серии",
			"venom_wire": "ядовитая pierce-линия от самого героя: душит и тех, кто вплотную",
		},
	},
	"ranger": {
		"main_attribute": "perception",
		"identity_title": "Охотничья стойка",
		"summary": "Восприятие — взгляд охотника: чем он острее, тем дальше летит болт и тем глубже пробивает строй.",
		"mechanic_tags": ["stance_charge", "long_range", "trap", "piercing_shot"],
		"weapon_identities": {
			"moon_crossbow": "заряжаемый одиночный piercing shot",
			"storm_longbow": "веер дальних charged beams",
			"hunter_trap": "deploy trap с burst и knockback",
		},
	},
	"doctor": {
		# SCRUM-900: кит «чумного доктора» — сустейн только от своего оружия
		# (trait plague_oath), три разных петли лечения-от-урона.
		"main_attribute": "knowledge",
		"identity_title": "Клятва чумного доктора",
		"summary": "Лечится только собственным оружием: зелье и чума возвращают часть нанесенного урона, пила лечит сильнее всех — пока враги перед зубьями. Чужой реген и вампиризм на него не действуют.",
		"mechanic_tags": ["weapon_only_sustain", "plague_spread", "aoe_potion", "sector_saw"],
		"weapon_identities": {
			"restore_potion": "бросок зелья: магический AoE-взрыв, лечит от нанесенного урона",
			"plague_syringe": "чумной дротик: долгая зараза 24с, перескакивает на соседей, тики лечат",
			"bone_saw": "сектор 135° перед собой: сильнейший селф-хил при верном позиционировании",
		},
	},
	"chemist": {
		"main_attribute": "intelligence",
		"identity_title": "Алхимическая цепь",
		"summary": "Интеллект смешивает реагенты без промаха, а «Катализатор» разгоняет всю периодику Химика на +50%: едкие заряды и волны гомункула догрызают то, что не добил взрыв.",
		"mechanic_tags": ["catalyst_trait", "acid_pool", "explosion", "homunculus_pair"],
		"weapon_identities": {
			"blast_powder": "быстрый прямой физический AoE-удар",
			"acid_flask": "долгие лужи с перманентными кислотными зарядами",
			"homunculus_vial": "постоянная пара: гомункул-танк и неуязвимый кастер",
		},
	},
	"knight": {
		"main_attribute": "endurance",
		"identity_title": "Щитовая клятва",
		"summary": "Выносливость — его клятва: чем крепче рыцарь, тем тверже блок и тяжелее ответный удар.",
		"mechanic_tags": ["block", "counter", "frontal_control", "tank_pressure"],
		"weapon_identities": {
			"long_spear": "длинный strip-контроль копьем",
			"tower_shield": "shield bash и frontal block",
			"holy_flail": "круговой тяжелый holy control",
		},
	},
	"druid": {
		"main_attribute": "leadership",
		"identity_title": "Командование стаей",
		"summary": "Лидерство — голос леса: чем тверже воля друида, тем больше зверей идет на зов и злее рвет добычу.",
		"mechanic_tags": ["commanded_pets", "briar_zone", "totem", "pack_support"],
		"weapon_identities": {
			"summon_amulet": "commanded pet attack target",
			"briar_staff": "терновая зона контроля",
			"raven_totem": "raven/totem support pulses",
		},
	},
}

const CLASS_DAMAGE_PARAMETER := {
	"berserk": "damage",
	"soldier": "damage",
	"thief": "damage",
	"elementalist": "magic_damage",
	"sniper": "damage",
	"priest": "magic_damage",
	"biologist": "magic_damage",
	"robot": "damage",
	"engineer": "damage",
	"dark_mage": "magic_damage",
	"guitarist": "magic_damage",
	"assassin": "damage",
	"ranger": "damage",
	"knight": "damage",
	"doctor": "magic_damage",
	"chemist": "magic_damage",
	"druid": "magic_damage",
}

const STAT_CLASS_RELEVANCE := {}

const CLASS_INTERPRETATIONS := {
	"berserk": {
		"strength": "Прямо усиливает двуручное оружие.",
		"intelligence": "Почти не влияет на двуручное оружие: физический урон Берсерка остается завязан на Силу.",
		"energy": "Ускоряет темп уникальных срабатываний, но не превращает двуручные удары в магический урон.",
		"leadership": "Каждые несколько ударов вызывает призрачное эхо-оружие.",
		"magic_damage": "Не усиливает двуручные физические удары Берсерка; полезность минимальна без отдельного магического источника.",
		"dot_damage": "Добавляет малое кровотечение к ударам.",
		"summon_amount": "Повышает частоту эхо-оружия.",
	},
	"soldier": {
		"strength": "Усиливает залпы, штык и вес гранат.",
		"intelligence": "Добавляет рунический воспламенитель к гранатам и выстрелам.",
		"energy": "Ускоряет тактические циклы: фитиль, залп и готовность ульты.",
		"knowledge": "Добавляет горение/кровотечение к пораженным целям.",
		"leadership": "Командный клич периодически вызывает эхо-залп строя.",
		"magic_damage": "Работает как зачарованный порох и руническая осколочная искра.",
		"dot_damage": "Добавляет малый burn/bleed от пороха и штыка.",
		"summon_amount": "Повышает частоту эхо-залпов и поддержку строя.",
	},
	"thief": {
		"strength": "Добавляет вес ударам кинжала и рикошетам.",
		"agility": "Главный стат: ускоряет темп уловок, крит и выживание через движение.",
		"intelligence": "Зачаровывает дым и монеты теневой искрой.",
		"perception": "Расширяет цепь рикошета, дальность кинжала, зону дыма и магнит добычи.",
		"energy": "Быстрее заряжает Большой Куш и снижает темп провалов.",
		"knowledge": "Добавляет яд/кровотечение к скрытым ударам.",
		"endurance": "Компенсирует низкое HP через устойчивость к ошибкам.",
		"leadership": "Подкупленная тень периодически повторяет удар.",
		"magic_damage": "Работает как теневое зачарование монет и клинков.",
		"dot_damage": "Добавляет малый яд/bleed к backstab и дыму.",
		"summon_amount": "Учащает подкупленные эхо-удары.",
	},
	"elementalist": {
		# SCRUM-948: физическая и периодическая оси — реальные каналы квадрата
		# четырёх стихий; SCRUM-950 — ожог догорающей зоны метеора.
		"strength": "Питает физический канал квадрата стихий и утяжеляет отброс.",
		"agility": "Ускоряет цикл тяжёлых кастов, движение и шанс крита.",
		"intelligence": "Главный стат: усиливает магический урон всех стихий, а трейт проводит его бонусы на 30% эффективнее.",
		"perception": "Расширяет квадрат, центр разлома и зону метеора.",
		"energy": "Ускоряет заряд Сверхновы и питает длительность стихийных паттернов.",
		"knowledge": "Усиливает ожог квадрата и догорающую зону метеора.",
		"endurance": "Компенсирует хрупкость защитой и HP.",
		"leadership": "Фамильяр-искра периодически повторяет малую стихийную вспышку.",
		"damage": "Работает как физический канал квадрата четырёх стихий.",
		"dot_damage": "Питает ожог квадрата и тики метеорной зоны.",
		"summon_amount": "Учащает фамильярные эхо-вспышки.",
	},
	"sniper": {
		"strength": "Усиливает отдачу тяжелых патронов и knockback lockshot.",
		"agility": "Ускоряет перезарядку, смену позиции и шанс крита.",
		"intelligence": "Зачаровывает патроны малым arcane splash.",
		"perception": "Главный стат: дальность, точность, радиус kill-zone и pickup.",
		"energy": "Быстрее заряжает Последний Выстрел и стабилизирует прицел.",
		"knowledge": "Добавляет bleed/armor-pierce DoT к marked shots.",
		"endurance": "Позволяет пережить ошибку при игре на дистанции.",
		"leadership": "Корректировщик периодически повторяет малый прицельный выстрел.",
		"magic_damage": "Работает как зачарованный наконечник пули.",
		"dot_damage": "Добавляет кровотечение к lockshot и split-round.",
		"summon_amount": "Учащает корректировочные эхо-выстрелы.",
	},
	"priest": {
		"strength": "Придает вес кадилу и усиливает knockback священных волн.",
		"agility": "Ускоряет чтение молитв, движение и шанс крита.",
		"intelligence": "Усиливает священный магический урон печатей и молитв.",
		"perception": "Расширяет зоны печатей, дальность реликвария и радиус подбора.",
		"energy": "Быстрее заряжает Хор Искупления и поддерживает частые благословения.",
		"knowledge": "Главный стат: усиливает священные формулы, DoT-покаяние и эффективность лечения.",
		"endurance": "Дает HP/защиту, чтобы удерживать ближнюю ward-зону.",
		"leadership": "Приходская поддержка периодически повторяет малую молитву.",
		"damage": "Работает как физический импульс кадила и реликвария.",
		"dot_damage": "Добавляет покаянное горение к освященным целям.",
		"summon_amount": "Учащает эхо-молитвы прихожан.",
	},
	"biologist": {
		"strength": "Утяжеляет капсулы и повышает knockback биореакций.",
		"agility": "Ускоряет сбор образцов, смену позиции и шанс крита.",
		"intelligence": "Усиливает магическую биохимию спор и симбионтов.",
		"perception": "Расширяет зоны роста, дальность инъектора и радиус подбора.",
		"energy": "Быстрее заряжает Пробуждение Колонии и ускоряет реакционные циклы.",
		"knowledge": "Главный стат: усиливает анализ образцов, DoT и точность биореакций.",
		"endurance": "Компенсирует хрупкость HP/защитой при игре рядом с зонами.",
		"leadership": "Лабораторный ассистент периодически повторяет малую биореакцию.",
		"damage": "Работает как давление капсул и механический импульс инъектора.",
		"dot_damage": "Усиливает споры, инфекционные тики и остаточную биомассу.",
		"summon_amount": "Учащает ассистентские эхо-реакции без добавления отдельного питомца.",
	},
	"robot": {
		"strength": "Главный стат: усиливает сервоприводы, гидравлику и физический импульс оружия.",
		"agility": "Сокращает инерцию корпуса: быстрее перезарядка, движение и шанс крита.",
		"intelligence": "Улучшает боевой алгоритм и добавляет маготехнический splash.",
		"perception": "Расширяет магнитные зоны, дальность захвата и радиус подбора.",
		"energy": "Питает реактор, быстрее заряжает Перегрузку и ускоряет контуры оружия.",
		"knowledge": "Стабилизирует перегрев: усиливает DoT/реген и снижает цену ошибок.",
		"endurance": "Ключевой защитный стат: HP, броня, поглощение и выдержка под давлением.",
		"leadership": "Автопилотный протокол периодически повторяет малый механический импульс.",
		"magic_damage": "Работает как рунический аккумулятор внутри механизма.",
		"dot_damage": "Добавляет перегрев/искрение к реакторным и прессовым ударам.",
		"summon_amount": "Учащает эхо-протоколы сервоприводов без отдельного питомца.",
	},
	"engineer": {
		"strength": "Усиливает тяжелые инструменты, мины и отдачу турелей.",
		"agility": "Ускоряет сборку устройств, перезарядку и смену позиции.",
		"intelligence": "Улучшает схемы, target-logic и маготехнические импульсы.",
		"perception": "Расширяет сетку датчиков, радиус мин и дальность турелей.",
		"energy": "Питает мастерскую, ускоряет ультимейт и длительность активных контуров.",
		"knowledge": "Повышает качество ремонта, DoT-перегрев и стабильность устройств.",
		"endurance": "Дает запас прочности, чтобы успеть развернуть устройства под давлением.",
		"leadership": "Главный стат: повышает лимит/частоту устройств и протоколы поддержки.",
		"magic_damage": "Работает как руническая схема внутри механизмов.",
		"dot_damage": "Добавляет перегрев, искрение и шрапнель к устройствам.",
		"summon_amount": "Усиливает количество активных инженерных устройств и эхо-сборок.",
	},
	"dark_mage": {
		"strength": "Придает вес снарядам: больше knockback и физическая устойчивость.",
		"leadership": "Усиливает фамильярные эхо-касты и поддержку.",
		"summon_amount": "Учащает вспомогательные эхо-срабатывания.",
	},
	"guitarist": {
		# SCRUM-899: тексты соответствуют magic-caster идентичности и правилам
		# саммонер-скейлинга ампов (см. GUITARIST_WEAPONS в progression_data_weapons.gd).
		"strength": "Делает рифф и пульсы тяжелее и сильнее отталкивает.",
		"intelligence": "Основной драйвер урона: рифф, бас и усилители бьют магией.",
		"magic_damage": "Главный канал урона Гитариста: весь кит бьёт магией, и именно её усиливает «Разогрев».",
		"dot_damage": "Добавляет жгучий feedback-DoT.",
		"leadership": "Больше активных усилителей на сцене и дольше их жизнь.",
		"summon_amount": "Учащает пульс усилителей — сценический темп турелей.",
	},
	"assassin": {
		"intelligence": "Зачаровывает лезвия фиолетовой искрой по области.",
		"leadership": "Фантом-двойник периодически повторяет удар.",
		"summon_amount": "Повышает частоту фантомного повторного удара.",
	},
	"ranger": {
		"intelligence": "Зачаровывает болты магическим splash.",
		"energy": "Быстрее заряжает стойку охотника.",
		"leadership": "Сокол-метка периодически повторяет урон по цели.",
	},
	"doctor": {
		"strength": "Утяжеляет инструменты и повышает контроль ближней пилы.",
		"leadership": "Санитарная команда усиливает эхо-лечение/повтор ударов.",
	},
	"chemist": {
		"strength": "Утяжеляет колбы и повышает knockback.",
		"leadership": "Автономный помощник/эхо-реакция чаще повторяет удар.",
	},
	"knight": {
		"intelligence": "Зачаровывает сталь магическим splash.",
		"energy": "Сокращает cooldown контратаки.",
		"leadership": "Знаменосец-аура чаще вызывает эхо-контроль.",
	},
	"druid": {
		"strength": "Усиливает когти/тернии и knockback.",
		"magic_damage": "Подпитывает природные заклинания и зачарованные зоны.",
		"energy": "Ускоряет природные циклы и уникальные cooldown.",
	},
}

const ATTRIBUTE_PRIORITIES := {
	"berserk": ["strength", "endurance", "agility", "perception", "leadership"],
	"soldier": ["perception", "strength", "agility", "endurance", "leadership"],
	"thief": ["agility", "perception", "strength", "energy", "leadership"],
	"elementalist": ["intelligence", "energy", "perception", "knowledge", "leadership"],
	"sniper": ["perception", "agility", "strength", "endurance", "knowledge"],
	"priest": ["knowledge", "intelligence", "energy", "leadership", "endurance"],
	"biologist": ["knowledge", "intelligence", "perception", "energy", "agility"],
	"robot": ["endurance", "strength", "energy", "perception", "knowledge"],
	"engineer": ["leadership", "intelligence", "perception", "energy", "knowledge"],
	"dark_mage": ["intelligence", "energy", "knowledge", "perception", "leadership"],
	"guitarist": ["leadership", "intelligence", "perception", "energy", "agility"],
	"assassin": ["agility", "strength", "perception", "energy", "leadership"],
	"ranger": ["perception", "agility", "strength", "knowledge", "energy"],
	"doctor": ["knowledge", "intelligence", "energy", "endurance", "perception"],
	"chemist": ["intelligence", "knowledge", "energy", "perception", "agility"],
	"knight": ["endurance", "strength", "leadership", "knowledge", "agility"],
	"druid": ["leadership", "intelligence", "perception", "knowledge", "endurance"],
}

const ATTRIBUTE_PRIORITY_REASONS := {
	"strength": "усиливает физический урон, контроль оружия и классовые физические интерпретации",
	"agility": "ускоряет атаки и движение, повышает критический шанс и уворот",
	"intelligence": "усиливает магический урон, зачарования и магические классовые механики",
	"perception": "увеличивает дальность, радиусы, pickup и точность позиционирования",
	"energy": "ускоряет уникальные механики, ультимейт и темп атак",
	"knowledge": "усиливает DoT, лечение, регенерацию и стабильность билда",
	"endurance": "дает HP, защиту, поглощение и устойчивость под давлением",
	"leadership": "усиливает призывы, эхо-оружие, поддержку и ауры",
}

# SCRUM-695: КАНОНИЧЕСКИЙ реестр боевых атрибутов — единственный источник правды для
# набора прокачиваемых атрибутов (id, RU-имя, иконка-папка, тип значения). Раньше
# список фактически дублировался в трёх местах (папки иконок, LEVEL_UP_REWARDS и
# маппинг reward_attribute_dependency). Теперь LEVEL_UP_REWARDS ссылается на эти id
# через поле "attr", а матрица релевантности ниже строится по этим же id.
#   value_type: "percent" — множитель/доля, "flat" — плоская добавка.
#   icon — имя папки в docs/design/references/icons/attributes/ (трассируемость арта).
const ATTRIBUTE_REGISTRY := [
	{"id": "damage", "name": "Урон", "icon": "damage", "value_type": "percent"},
	{"id": "attack_speed", "name": "Скорость атаки", "icon": "attack_speed", "value_type": "percent"},
	{"id": "max_health", "name": "Макс. здоровье", "icon": "health_point", "value_type": "flat"},
	{"id": "move_speed", "name": "Скорость движения", "icon": "move_speed", "value_type": "percent"},
	{"id": "aoe_radius", "name": "Ширина сектора", "icon": "aoe_radius", "value_type": "percent"},
	{"id": "pickup_radius", "name": "Радиус подбора", "icon": "pickup_radius", "value_type": "flat"},
	{"id": "defense", "name": "Защита", "icon": "defense", "value_type": "percent"},
	{"id": "magic_focus", "name": "Магический фокус", "icon": "magic_damage", "value_type": "percent"},
	{"id": "knockback", "name": "Отталкивание", "icon": "knockback_power", "value_type": "percent"},
	{"id": "crit_chance", "name": "Шанс крита", "icon": "crit_chance", "value_type": "percent"},
	{"id": "crit_damage", "name": "Урон крита", "icon": "crit_damage_multiplier", "value_type": "percent"},
	{"id": "dodge", "name": "Уклонение", "icon": "dodge", "value_type": "percent"},
	{"id": "range", "name": "Дальность атаки", "icon": "attack_range", "value_type": "percent"},
	{"id": "dot_damage", "name": "Периодический урон", "icon": "dot_damage", "value_type": "flat"},
	{"id": "dot_speed", "name": "Скорость тиков", "icon": "dot_speed", "value_type": "flat"},
	{"id": "projectile_speed", "name": "Скорость снарядов", "icon": "projectile_speed", "value_type": "flat"},
	{"id": "aura_radius", "name": "Радиус", "icon": "aura_radius", "value_type": "percent"},
	{"id": "buff_power", "name": "Сила поддержки", "icon": "buff_power", "value_type": "percent"},
	{"id": "summon_amount", "name": "Сила призыва", "icon": "summon_amount", "value_type": "flat"},
	{"id": "absorb", "name": "Поглощение", "icon": "absorb", "value_type": "flat"},
	{"id": "regeneration", "name": "Регенерация", "icon": "regeneration", "value_type": "flat"},
	{"id": "vampiric_amount", "name": "Вампиризм (лечение)", "icon": "vampiric_amount", "value_type": "flat"},
	{"id": "vampiric_chance", "name": "Вампиризм (шанс)", "icon": "vampiric_chance", "value_type": "percent"},
	{"id": "ultimate_power", "name": "Сила ультимейта", "icon": "ultimate_multiplier", "value_type": "percent"},
]

# SCRUM-695: ПРЯМАЯ матрица релевантности (атрибут × 17 классов), первоисточник
# полезности атрибута для класса (заменяет косвенный расчёт через 8 базовых
# характеристик в level-up-наградах). ЖЁСТКИЙ ИНВАРИАНТ по каждому атрибуту:
# ровно 2 primary + 8 secondary + 7 optional = 17 классов (проверяется
# tests/attribute_relevance_test.gd). optional выводится как «все остальные».
# primary = сигнатурный геймплей класса; secondary = ощутимо полезно; optional =
# профильно мимо. Раскладка осмысленна (берсерк — урон/отталкивание/вампиризм,
# снайпер — крит/дальность, жрец — защита/аура/поддержка, друид — аура/призыв/реген).
const ATTRIBUTE_RELEVANCE := {
	"damage": {"primary": ["berserk", "soldier"], "secondary": ["thief", "elementalist", "sniper", "dark_mage", "assassin", "ranger", "chemist", "knight"]},
	"attack_speed": {"primary": ["guitarist", "soldier"], "secondary": ["thief", "elementalist", "sniper", "dark_mage", "assassin", "ranger", "doctor", "chemist"]},
	"max_health": {"primary": ["knight", "robot"], "secondary": ["berserk", "thief", "sniper", "priest", "engineer", "assassin", "ranger", "doctor"]},
	"move_speed": {"primary": ["thief", "ranger"], "secondary": ["berserk", "elementalist", "sniper", "biologist", "dark_mage", "assassin", "chemist", "knight"]},
	"aoe_radius": {"primary": ["elementalist", "chemist"], "secondary": ["berserk", "thief", "sniper", "priest", "robot", "engineer", "dark_mage", "ranger"]},
	# SCRUM-897: pickup_radius — первичная сила Вора (trait «Воровская хватка»).
	"pickup_radius": {"primary": ["thief", "robot", "engineer"], "secondary": ["berserk", "elementalist", "sniper", "assassin", "ranger", "chemist", "knight"]},
	"defense": {"primary": ["knight", "priest"], "secondary": ["thief", "elementalist", "sniper", "engineer", "assassin", "ranger", "doctor", "chemist"]},
	"magic_focus": {"primary": ["dark_mage", "elementalist"], "secondary": ["sniper", "priest", "robot", "engineer", "assassin", "ranger", "doctor", "chemist"]},
	"knockback": {"primary": ["berserk", "guitarist"], "secondary": ["soldier", "elementalist", "sniper", "priest", "biologist", "chemist", "knight", "druid"]},
	"crit_chance": {"primary": ["thief", "sniper"], "secondary": ["berserk", "soldier", "biologist", "robot", "dark_mage", "assassin", "ranger", "druid"]},
	"crit_damage": {"primary": ["sniper", "assassin"], "secondary": ["berserk", "soldier", "thief", "robot", "dark_mage", "guitarist", "ranger", "druid"]},
	"dodge": {"primary": ["thief", "assassin"], "secondary": ["berserk", "soldier", "sniper", "biologist", "guitarist", "ranger", "doctor", "druid"]},
	"range": {"primary": ["sniper", "ranger"], "secondary": ["soldier", "elementalist", "priest", "biologist", "engineer", "dark_mage", "chemist", "druid"]},
	"dot_damage": {"primary": ["biologist", "dark_mage"], "secondary": ["elementalist", "priest", "engineer", "guitarist", "assassin", "doctor", "chemist", "druid"]},
	"dot_speed": {"primary": ["biologist", "chemist"], "secondary": ["elementalist", "priest", "engineer", "dark_mage", "guitarist", "assassin", "doctor", "druid"]},
	"projectile_speed": {"primary": ["soldier", "ranger"], "secondary": ["thief", "elementalist", "sniper", "robot", "engineer", "dark_mage", "guitarist", "chemist"]},
	"aura_radius": {"primary": ["priest", "druid"], "secondary": ["berserk", "soldier", "biologist", "robot", "engineer", "guitarist", "doctor", "knight"]},
	"buff_power": {"primary": ["priest", "engineer"], "secondary": ["berserk", "soldier", "biologist", "robot", "guitarist", "doctor", "knight", "druid"]},
	"summon_amount": {"primary": ["engineer", "druid"], "secondary": ["elementalist", "priest", "biologist", "robot", "dark_mage", "guitarist", "doctor", "knight"]},
	"absorb": {"primary": ["knight", "robot"], "secondary": ["berserk", "soldier", "priest", "biologist", "engineer", "guitarist", "doctor", "druid"]},
	"regeneration": {"primary": ["doctor", "druid"], "secondary": ["berserk", "soldier", "priest", "biologist", "robot", "engineer", "guitarist", "knight"]},
	"vampiric_amount": {"primary": ["berserk", "doctor"], "secondary": ["soldier", "thief", "biologist", "robot", "guitarist", "assassin", "knight", "druid"]},
	"vampiric_chance": {"primary": ["assassin", "doctor"], "secondary": ["berserk", "soldier", "thief", "biologist", "robot", "guitarist", "knight", "druid"]},
	"ultimate_power": {"primary": ["elementalist", "guitarist"], "secondary": ["berserk", "soldier", "priest", "robot", "engineer", "dark_mage", "doctor", "druid"]},
}
