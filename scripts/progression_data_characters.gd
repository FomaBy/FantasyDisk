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
		# SCRUM-1004: trait «Ярость» — низкое HP непрерывно усиливает удары
		# (до +40%); источник истины docs/design/class_traits_registry.md,
		# механика — запись CLASS_TRAITS (rage_damage_bonus_cap).
		"id": "berserk",
		"title": "Берсерк",
		"description": "Ближний бой, большой запас HP. Урон растёт при низком здоровье — до +40% у порога смерти. Дальнобойных атак нет.",
		"strengths": "ближний AoE, много здоровья, до +40% урона на низком HP.",
		"weaknesses": "только ближний бой; риск ошибок высок.",
		"sprite_path": "res://assets/sprites/characters/full_frame/berserk_pixellab/berserk_idle_south.png",
	},
	"soldier": {
		"id": "soldier",
		"title": "Солдат",
		"description": "Стрелок средней дистанции. Двойной спуск: каждое действие с шансом 50% срабатывает дважды. Огонь и взрывчатка по толпе и по одиночкам; в долгой дуэли с боссом слабее.",
		"strengths": "50% шанс повтора, взрывные пули, гранаты и штык.",
		"weaknesses": "гранате нужен фитиль; слабее в долгой дуэли с боссом.",
		"sprite_path": "res://assets/sprites/characters/full_frame/soldier_pixellab/soldier_idle_south.png",
	},
	"thief": {
		# SCRUM-897: экономико-уклонительный трикстер — trait «Воровская
		# хватка» (магнит подбора) + монета с мгновенным золотом + яд-кинжал
		# контроля + дым-облако уклонения.
		"id": "thief",
		"title": "Вор",
		"description": "Ближне-средняя дистанция, мало HP. Магнит добычи, золото с ударов, яд для контроля, дым для уклонения. Уязвим к урону в упор.",
		"strengths": "магнит добычи, золотые рикошеты, паралич и дым.",
		"weaknesses": "мало здоровья; контактные ошибки смертельны.",
		"sprite_path": "res://assets/sprites/characters/full_frame/thief_pixellab/thief_idle_south.png",
	},
	"elementalist": {
		# SCRUM-947..950: чистый маг зон — trait «Проводник стихий» (магические
		# бонусы на 30% эффективнее) + кит квадрат/полнокартный X/тяжёлый метеор.
		"id": "elementalist",
		"title": "Элементалист",
		"description": "Маг зон. Магические бонусы ×1.30. Крупные AoE-заклинания по площади. Хрупкий, слаб вблизи.",
		"strengths": "магические бонусы ×1.3, огромные зоны, отброс.",
		"weaknesses": "хрупок; медленные касты требуют точной позиции.",
		"sprite_path": "res://assets/sprites/characters/full_frame/elementalist_pixellab/elementalist_idle_south.png",
	},
	"sniper": {
		"id": "sniper",
		"title": "Снайпер",
		# SCRUM-930..933: редизайн кита — trait «Дальний расчёт» (чем дальше цель,
		# тем выше урон: ×1.0 вплотную, кап +60%), винтовка бьёт самую дальнюю
		# цель с ближним самоподрывом, наводчик кладёт отложенный артиллерийский
		# снаряд по красной метке, осколочные патроны — скорострельный круговой
		# веер пуль по ближним монстрам.
		"description": "Дальний бой. Урон растёт с дистанцией до цели, до +60% на максимуме. В упор бонус пропадает; от толпы защищён слабо.",
		"strengths": "до +60% за дистанцию, огромная дальность, криты.",
		"weaknesses": "в упор теряет бонус; от толпы спасает только веер.",
		"sprite_path": "res://assets/sprites/characters/full_frame/sniper_pixellab/sniper_idle_south.png",
	},
	"priest": {
		"id": "priest",
		"title": "Священник",
		"description": "Средняя дистанция. В начале боя — выбор одной из трёх молитв: кара, лечение или защита. Расчищает толпу; выбор один на бой.",
		"strengths": "молитва на раунд, дальний бурст, волна и двойной взрыв.",
		"weaknesses": "одна молитва за бой; оружие не лечит.",
		"sprite_path": "res://assets/sprites/characters/full_frame/priest_pixellab/priest_idle_south.png",
	},
	"biologist": {
		"id": "biologist",
		"title": "Биолог",
		"description": "Дистанционный, урон по времени. Споры и яд заражают цели; +20% прямого урона по заражённым. Медленный разгон, мало HP.",
		"strengths": "DoT, замедление, пирсинг и +20% по заражённым.",
		"weaknesses": "хрупок; медленно разгоняется; споры бьют вблизи.",
		"sprite_path": "res://assets/sprites/characters/full_frame/biologist_pixellab/biologist_idle_south.png",
	},
	"robot": {
		"id": "robot",
		"title": "Робот",
		# SCRUM-914..918: редизайн кита — trait «Бронекорпус» (игнор 20% любого
		# входящего урона последним множителем), тяжёлый якорь-пулл, коридорный
		# пресс-компрессор, вращающийся реакторный веер.
		"description": "Танк. Бронекорпус снижает любой входящий урон на 20%. Стягивает и контролирует толпу. Медленный.",
		"strengths": "−20% входящего урона, стягивание и контроль зон.",
		"weaknesses": "медлителен; требует верной позиции.",
		"sprite_path": "res://assets/sprites/characters/full_frame/robot_pixellab/robot_idle_south.png",
	},
	"engineer": {
		"id": "engineer",
		"title": "Инженер",
		# SCRUM-905..908: кит устройств — турели с боезапасом, орбитальные дроны,
		# персистентные мины; trait «Сеть мастерской» (описание игроку — в
		# CLASS_TRAITS.engineer).
		"description": "Расстановка устройств: турели, дроны, мины. Урон устройств растёт с их количеством. В начале боя, без развёртывания, слаб.",
		"strengths": "турели, дроны, вечные мины и сеть от Лидерства.",
		"weaknesses": "слаб без подготовки; боезапас турелей конечен.",
		"sprite_path": "res://assets/sprites/characters/full_frame/engineer_pixellab/engineer_idle_south.png",
	},
	"dark_mage": {
		"id": "dark_mage",
		"title": "Темный маг",
		# SCRUM-939..941/1007: кит = цепной снаряд / curse-прожиг / зеркальные
		# взрывы; trait «Тёмный распад» — убитые магом взрываются сами.
		"description": "AoE-маг, стеклянная пушка. Цепные снаряды и проклятия по площади; убитые им враги взрываются. Почти нет защиты, гибнет вблизи.",
		"strengths": "AoE, цепные рикошеты, проклятия и взрывы убитых.",
		"weaknesses": "самый хрупкий; почти беззащитен вблизи.",
		"sprite_path": "res://assets/sprites/characters/full_frame/dark_mage_pixellab/dark_mage_idle_south.png",
	},
	"guitarist": {
		"id": "guitarist",
		# SCRUM-899/SCRUM-1006: магический кастер с деплой-геймплеем и trait'ом
		# «Разогрев» — тексты без звука-как-стата (звук = флейвор магии).
		"title": "Гитарист",
		"description": "Маг-кастер, кайт. Разогрев: +2% магического урона в секунду без полученного урона, кап +20%; удар обнуляет. Против боссов слаб.",
		"strengths": "магический AoE, усилители, разогрев и кайт.",
		"weaknesses": "слабее против боссов; удар сбрасывает разогрев.",
		"sprite_path": "res://assets/sprites/characters/full_frame/guitarist_pixellab/guitarist_idle_south.png",
	},
	"assassin": {
		"id": "assassin", "title": "Ассасин",
		# SCRUM-894: описание обязано явно заявлять кап крита 100% и опору на
		# крит-урон + уворот/позиционирование (копирайт-пасс — SCRUM-952).
		"description": "Ближний бой, мало HP. Шанс крита можно довести до 100%; избыток идёт в крит-урон. Выживает за счёт уворота и позиции.",
		"strengths": "крит до 100%, темп, уворот, теневая завеса и яд.",
		"weaknesses": "мало здоровья; промахи дорого стоят.",
		"sprite_path": "res://assets/sprites/characters/full_frame/assassin_pixellab/assassin_idle_south.png",
	},
	"ranger": {
		"id": "ranger", "title": "Рейнджер",
		"description": "Дальний бой. Каждое попадание отбрасывает цель, удерживая дистанцию. Ставит капканы. Слабее вблизи и в движении.",
		"strengths": "отброс стрел, сплит-болт, пробивающий конус и капканы.",
		"weaknesses": "слабее вблизи и во время движения.",
		"sprite_path": "res://assets/sprites/characters/full_frame/ranger_pixellab/ranger_idle_south.png",
	},
	"doctor": {
		"id": "doctor", "title": "Доктор",
		"description": "Средняя дистанция. Лечится только собственным уроном; внешнее лечение не действует. Низкий бурст, высокая живучесть в долгом бою.",
		"strengths": "лечение своим уроном, чума и затяжная живучесть.",
		"weaknesses": "низкий бурст; внешний сустейн отключён.",
		"sprite_path": "res://assets/sprites/characters/full_frame/doctor_pixellab/doctor_idle_south.png",
	},
	"chemist": {
		"id": "chemist", "title": "Химик",
		"description": "Дистанционный. Кислотные лужи, взрывы, пара гомункулов; периодический урон +50%. Хрупкий, убивает не сразу.",
		"strengths": "кислотные стаки, +50% периодики, AoE и гомункулы.",
		"weaknesses": "хрупок; урону нужно время.",
		"sprite_path": "res://assets/sprites/characters/full_frame/chemist_pixellab/chemist_idle_south.png",
	},
	"knight": {
		# SCRUM-920: player-facing текст читает identity тяжёлого танка,
		# отбрасывающего атакующих при получении удара (trait «Возмездие»).
		"id": "knight", "title": "Рыцарь",
		"description": "Танк ближнего боя. Ударивший его враг отбрасывается. Высокие броня и HP, контроль отбросом. Медленный; боссы к отбросу иммунны.",
		"strengths": "броня, здоровье, ответный отброс, блок и контроль.",
		"weaknesses": "медленный; боссы не отбрасываются.",
		"sprite_path": "res://assets/sprites/characters/full_frame/knight_pixellab/knight_idle_south.png",
	},
	"druid": {
		"id": "druid", "title": "Друид",
		"description": "Призыватель. Аура усиливает его и призванных зверей; тернии и тотемы держат зоны. Вне ауры и без стаи слаб.",
		"strengths": "аура урона, стая, терновые зоны и тотемы.",
		"weaknesses": "вне ауры призывы слабее; без стаи уязвим.",
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
	"berserk": {
		# SCRUM-1004 «Ярость» (реестр SCRUM-953): исходящий урон Берсерка растёт
		# НЕПРЕРЫВНО от недостающего здоровья — бонус = rage_damage_bonus_cap ×
		# missing_ratio (полное HP → +0%, половина → +20%, почти пустое → ровно
		# +40%); линейная шкала без ступенек, невалидные значения HP зажимаются
		# (health<0 → полный кап, health>max или max<=0 → без бонуса). ЕДИНАЯ
		# точка формулы — ProgressionData.class_rage_damage_bonus →
		# Player.rage_damage_multiplier; потребители: BerserkWeapon._rolled_damage
		# (все ТРИ оружия кита — меч/топор/молот; вторичные melee-эффекты
		# close/execute/followup наследуют уже усиленный dealt ровно один раз —
		# рекурсивного стака нет) и эхо-волна ульты
		# (Player._trigger_berserk_ultimate_echo). Слой ПОСЛЕ обычных
		# модификаторов урона/крита; артефактные low-HP эффекты (SCRUM-500:
		# «Кровавый Рубеж»/«Второе Дыхание») — отдельный стакующийся слой и не
		# меняются. Матожидание учтено budget-моделью
		# (class_rage_expected_damage_factor, RAGE_BUDGET_EXPECTED_MISSING_HP) —
		# budget_tuning_for компенсирует кит. Покрыт tests/berserk_rage_trait_test.gd.
		"id": "rage",
		"title": "Ярость",
		"description": "Чем меньше здоровья, тем сильнее удары: урон растёт непрерывно от недостающего запаса крови — до +40% на почти пустом.",
		"short_description": "Недостающее здоровье непрерывно усиливает урон — до +40%.",
		"rage_damage_bonus_cap": 0.40,
	},
	"soldier": {
		"id": "double_action",
		"title": "Двойное действие",
		"description": "Каждое действие оружия с шансом 50% происходит дважды; копия не создает новых копий.",
		"short_description": "Каждое действие оружия с шансом 50% повторяется один раз.",
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
		"short_description": "Бонусы к магическому урону на 30% эффективнее.",
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
		"short_description": "Убитые им враги взрываются магическим AoE без цепной рекурсии.",
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
		"short_description": "Весь периодический урон усилен на 50%; прямые хиты — нет.",
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
		"short_description": "Стартовый радиус подбора почти вдвое больше обычного.",
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
		"short_description": "Кап крита — 100%; избыток шанса превращается в крит-урон.",
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
		"short_description": "Лечится только собственным оружием; общий сустейн не работает.",
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
		"short_description": "По заражённым им целям прямой урон выше на 20%.",
		"infected_direct_hit_multiplier": 1.20,
	},
	"sniper": {
		# SCRUM-930 «Дальний расчёт»: исходящий урон оружия Снайпера растёт с
		# дистанцией Снайпер→цель, замеренной В МОМЕНТ ПРИМЕНЕНИЯ урона (гейт в
		# ClassWeapon._damage_enemy — отложенные атаки вроде снаряда Наводчика
		# честны по AC: не «угадывание» на спавне снаряда). Формула:
		#   ×1.0 вплотную (до distance_damage_free_range = 120px — грация,
		#   близкая цель получает РОВНО базовый урон),
		#   далее +distance_damage_per_100px за каждые 100px,
		#   жёсткий кап +distance_damage_cap_bonus (итог ×1.60 на 720px и дальше).
		# Тики DoT (hit_type "dot") НЕ скейлятся — усиление физической оси
		# выстрелов, документированное исключение AC. Боссы/элиты исключений
		# НЕ имеют (дистанция — честная плата позиционированием). Артефакт
		# «Дальнобойный прицел» (longshot_scaling) стакуется ПОВЕРХ отдельным
		# множителем — двойная ставка на дальнюю дуэль. Матожидание по типовой
		# дистанции боя каждого оружия учтено budget-моделью
		# (ProgressionData._budget_distance_trait_factors) — кит компенсирован
		# budget_tuning_for. Покрыт tests/sniper_kit_test.gd.
		"id": "long_range_calculus",
		"title": "Дальний расчёт",
		"description": "Чем дальше цель, тем сильнее выстрел: вплотную урон обычный, дальше 120 пикселей — +10% за каждые 100 пикселей дистанции, максимум +60%.",
		"short_description": "Чем дальше цель, тем выше урон — до +60%.",
		"distance_damage_free_range": 120.0,
		"distance_damage_per_100px": 0.10,
		"distance_damage_cap_bonus": 0.60,
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
		"short_description": "Без полученного урона копит до +20% магии; удар сбрасывает бонус.",
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
		"short_description": "Постоянная аура усиливает урон Друида и его призывов.",
		"wild_aura_damage_bonus": 0.10,
		"wild_aura_damage_cap": 0.30,
		"wild_aura_radius_ratio": 0.85,
	},
	"robot": {
		# SCRUM-914 «Бронекорпус»: Робот игнорирует 20% ЛЮБОГО входящего урона.
		# incoming_damage_multiplier — ПОСЛЕДНИЙ множитель пайплайна
		# Player.take_damage: применяется после dodge-ролла, блока Рыцаря,
		# absorb и defense (100 post-mitigation → 80, 5 → 4), ко ВСЕМ
		# источникам, идущим через take_damage: контакт/мили, снаряды, атаки
		# элиток и боссов, хазарды и тики (poison_zone, elite_poison_puddle
		# и т.п.). Не скейлится статами. Рантайм зажимает множитель полом 0.5
		# (анти-стакинг будущих скидок в полный иммунитет); худший суммарный
		# кап митигации Робота ≈ 94% < глобального гейта 98%
		# (global_survivability smoke). Покрыт tests/robot_kit_test.gd.
		"id": "armored_hull",
		"title": "Бронекорпус",
		"description": "Игнорирует 20% любого входящего урона — последним множителем, после брони, поглощения и уворота. Действует и на удары, и на периодический урон.",
		"short_description": "Последним множителем снижает любой входящий урон на 20%.",
		"incoming_damage_multiplier": 0.8,
	},
	"ranger": {
		# SCRUM-909 «Сторожевой лук»: попадания ЛУЧНЫХ оружий Рейнджера
		# (конфиг-флаг bow_knockback_trait у moon_crossbow/storm_longbow;
		# hunter_trap в trait НЕ входит — капкан держит жертву параличом)
		# отбрасывают жертву ОТ ИГРОКА на момент хита: вектор игрок→монстр,
		# а НЕ направление полёта снаряда — расщепление/пирс/удар в спину
		# всё равно толкают прочь от героя. Потребитель —
		# ClassWeapon._apply_ranger_bow_knockback (хук в _damage_enemy).
		# СИЛА отброса = derived knockback_power оружия (конфиг knockback +
		# endurance×4 + leadership×3, множится knockback_multiplier —
		# артефакт «Ударная тетива») × bow_hit_knockback; уроном/статами
		# урона НЕ скейлится (анти-runaway контроль). Боссы/элиты
		# сопротивляются: общий контроль-резист ×POISON_PARALYSIS_BOSS_FACTOR
		# (0.25, прецедент Вора SCRUM-897). Покрыт tests/ranger_kit_test.gd.
		"id": "warden_bow",
		"title": "Сторожевой лук",
		"description": "Каждое попадание лука и арбалета отбрасывает врага прочь от Рейнджера — всегда от героя, даже при расщеплении болта и сквозном пробитии. Боссы и элиты сопротивляются отбросу.",
		"short_description": "Попадания лука и арбалета отбрасывают врагов от героя.",
		"bow_hit_knockback": 1.0,
	},
	"engineer": {
		# SCRUM-908 «Сеть мастерской» (workshop_network, подтверждён реестром
		# docs/design/class_traits_registry.md): активные устройства дают стеки
		# сети — турель/дрон = 1.0, персистентная мина = 0.5 (мета network_weight
		# на узле устройства; пониженный вес мин — предохранитель от мин-спама,
		# вечные мины не дают uncapped-силы). Кап стеков = network_stack_cap_base
		# + floor(Лидерство / network_cap_leadership_step) — Лидерство буквально
		# «поднимает кап сети» (командир устройств). Каждый стек даёт
		# +network_damage_per_stack к урону ТОЛЬКО устройств (потребитель —
		# ClassWeapon._workshop_network_factor в _rolled_damage: снаряды турелей,
		# контакт дронов, взрывы мин); generic-урон игрока и ульту не трогает.
		# Бюджет-зеркало — ProgressionData._budget_network_factor. Покрыт
		# tests/engineer_kit_test.gd.
		"id": "workshop_network",
		"title": "Сеть мастерской",
		"description": "Каждое активное устройство даёт стек сети (мины — половину стека); каждый стек усиливает урон устройств на 6%. Лидерство поднимает предел сети: чем твёрже рука мастера, тем громче гремит вся мастерская.",
		"short_description": "Активные устройства дают стеки урона; Лидерство поднимает предел.",
		"network_damage_per_stack": 0.06,
		"network_stack_cap_base": 3.0,
		"network_cap_leadership_step": 6.0,
		"network_mine_weight": 0.5,
	},
	"priest": {
		# SCRUM-925 «Молитва боя»: на старте КАЖДОГО боя Священник выбирает одну
		# из трёх молитв на раунд (пул — BATTLE_PRAYERS ниже, доступ через
		# ProgressionData.class_battle_prayers). Ровно ОДИН выбор за бой; молитва
		# живёт инстанс-состоянием Player (_battle_prayer_*) и честно очищается
		# на конец боя/смерть/рестарт: player-узел пересоздаётся каждым боем, а
		# снапшот между узлами (_store_player_snapshot) инстанс-поля не тащит.
		# Потребители: Player.meta_damage_multiplier (+весь урон хитов) и
		# Player._apply_ultimate_damage (+ульта), Player._apply_regeneration
		# (+HP/с штатным regen-пайплайном), Player.take_damage (−входящий
		# ПОСЛЕДНИМ множителем после поглощения/защиты — концепт «Бронекорпуса»
		# Робота SCRUM-914, но только на текущий бой и только у Священника).
		# Обязательный UI SCRUM-926 завершает выбор молитвы до Player.on_battle_start.
		# Budget-модель
		# молитвы НЕ зеркалит: условный/выборный бафф (прецедент «Разогрева»
		# Гитариста); сравнение веток — docs/design/class_traits_registry.md.
		# Покрыт tests/priest_kit_test.gd.
		"id": "battle_prayer",
		"title": "Молитва боя",
		"description": "В начале каждого боя Священник выбирает одну из трёх молитв на раунд: +20% урона, +2 HP/сек или −20% входящего урона.",
		"short_description": "Перед боем выбирает +20% урона, +2 HP/с или −20% входящего урона.",
		"battle_prayer_damage_bonus": 0.20,
		"battle_prayer_regen_flat": 2.0,
		"battle_prayer_incoming_reduction": 0.20,
	},
	"knight": {
		# SCRUM-920 «Возмездие» (реестр class_traits_registry.md, строка 16):
		# нанёсший Рыцарю КОНТАКТНЫЙ удар враг отбрасывается прочь от Рыцаря —
		# melee-контроль, прерывающий серию контактных тычков (contact-цикл
		# сбрасывается выходом за contact_range). Потребитель —
		# Player._try_retaliation_knockback (generic class_trait_value, у классов
		# без ключей отброс = 0 — утечки нет). Атакующий приходит 3-м аргументом
		# take_damage ТОЛЬКО из контактного пути (enemy._update_contact_damage);
		# снаряды/зоны/элитные страйки атакующего не передают — дальнобой трейтом
		# не отбрасывается (AC: monster hit/contact attack). Таксономия исключений —
		# CombatTargetQuery.is_epic_displacement_immune: боссы и главные элиты
		# карты НЕ смещаются, мини-элиты волн отбрасываются как обычные монстры.
		# retaliation_knockback — импульс apply_knockback (декей 2400 px/s² в
		# enemy._consume_knockback ⇒ смещение ≈ v²/4800 ≈ 120px — за пределы
		# типового contact_range 40-90px, серия контактных ударов рвётся).
		# retaliation_cooldown — внутренний интервал против физ/пафинг-раскачки
		# паков (i-frames 0.32с и так ограничивают частоту событий урона; кулдаун
		# 0.4с — документированный предохранитель поверх, AC «cooldown/cap»).
		# Покрыт tests/knight_kit_test.gd.
		"id": "retaliation",
		"title": "Возмездие",
		"description": "Ударивший Рыцаря враг отбрасывается прочь: обычные монстры и мини-элиты теряют контактный прессинг. Боссы и главные элиты не смещаются.",
		"short_description": "Контактный атакующий отбрасывается; боссы и главные элиты невосприимчивы.",
		"retaliation_knockback": 760.0,
		"retaliation_cooldown": 0.4,
	},
}

# SCRUM-925 «Молитва боя»: пул молитв выбора на старте боя. Player-facing
# русский текст для UI SCRUM-926 берётся ОТСЮДА (id/title/description);
# численный эффект — trait-ключ класса в CLASS_TRAITS (value подставляет
# ProgressionData.class_battle_prayers; молитва без ключа у класса в пул не
# попадает — другим классам пул пуст). Порядок записей = порядок в UI;
# ПЕРВАЯ запись — временный автовыбор до SCRUM-926.
const BATTLE_PRAYERS := [
	{"id": "prayer_wrath", "title": "Молитва кары", "description": "+20% ко всему урону Священника до конца боя.", "trait_key": "battle_prayer_damage_bonus"},
	{"id": "prayer_mending", "title": "Молитва исцеления", "description": "+2 HP в секунду до конца боя.", "trait_key": "battle_prayer_regen_flat"},
	{"id": "prayer_aegis", "title": "Молитва защиты", "description": "−20% входящего урона до конца боя.", "trait_key": "battle_prayer_incoming_reduction"},
]

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
		# SCRUM-925/927/928/929: trait «Молитва боя» — источник истины в
		# docs/design/class_traits_registry.md; механика — запись CLASS_TRAITS
		# (battle_prayer_*), потребители — meta_damage_multiplier /
		# _apply_regeneration / take_damage. Оружейный сустейн кита выпилен.
		"main_attribute": "knowledge",
		"identity_title": "Молитва боя",
		"summary": "Знание — его псалтырь, молитва — его оружие: перед каждым боем Священник выбирает одну из трёх молитв (кара, исцеление или защита), а кит бьет чистой святой магией — без лечения от ударов.",
		"mechanic_tags": ["battle_prayer", "sanctify_burst", "close_ward_aoe", "dual_toll"],
		"weapon_identities": {
			"priest_reliquary": "быстрый дальний бурст из трех святых вспышек по цели",
			"priest_censer": "редкая широкая волна вокруг Священника",
			"priest_chime": "двойной звон: взрыв у цели и у самого Священника",
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
		"identity_title": "Сеть мастерской",
		"summary": "Лидерство командует железом: живые турели, дроны и мины дают стеки сети и бьют сильнее разом; чем твёрже рука мастера — тем больше устройств и выше предел сети.",
		"mechanic_tags": ["deployable_network", "device_command", "orbit_drones", "minefield"],
		"weapon_identities": {
			"engineer_sentry_wrench": "турели с боезапасом 15 выстрелов, предел парка растёт от Лидерства",
			"engineer_repair_drone": "орбитальные боевые дроны: спираль контактного физического урона",
			"engineer_pressure_mines": "пары вечных нажимных мин в случайных точках рядом",
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
		# SCRUM-909..913: кит «сторожевого лука» — контроль дистанции. Trait
		# «Сторожевой лук» (CLASS_TRAITS.ranger) отбрасывает врагов от героя
		# каждым лучным попаданием; сплит/конус/капкан — три разных паттерна.
		"main_attribute": "perception",
		"identity_title": "Сторожевой лук",
		"summary": "Восприятие — взгляд охотника: стойка заряжает выстрел, а каждое попадание лука отбрасывает врагов прочь от героя — Рейнджер держит дистанцию, которую сам и назначил.",
		"mechanic_tags": ["stance_charge", "long_range", "knockback_identity", "split_shot", "piercing_cone", "permanent_trap"],
		"weapon_identities": {
			"moon_crossbow": "заряжаемый болт с расщеплением 1→4 по соседям цели",
			"storm_longbow": "дальнобойный конус пробивающих насквозь стрел",
			"hunter_trap": "перманентный капкан: физический хлопок, паралич и кровотечение",
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
		# SCRUM-920..923: trait «Возмездие» — источник истины в
		# docs/design/class_traits_registry.md; механика — запись CLASS_TRAITS
		# (retaliation_knockback/retaliation_cooldown), потребитель —
		# Player._try_retaliation_knockback. Кит редизайна: тройной секвенс-укол
		# копья / конус-баш щита к ближайшей цели с масштабируемым отбросом /
		# расширяющаяся спираль кистеня (BerserkWeapon, data-driven конфиги).
		"main_attribute": "endurance",
		"identity_title": "Возмездие",
		"summary": "Латный танк-отражатель: ударивший его враг отлетает прочь (боссы и главные элиты стоят), копьё колет веером из трёх уколов, щит бьёт конусом в ближайшую цель с отбросом, а кистень раскручивает спираль от центра наружу.",
		"mechanic_tags": ["retaliation_knockback", "block", "counter", "triple_thrust", "cone_bash", "expanding_spiral", "tank_pressure"],
		"weapon_identities": {
			"long_spear": "тройной секвенс-укол лево-центр-право широким веером полос",
			"tower_shield": "конусный баш в направлении ближайшего врага с масштабируемым отбросом",
			"holy_flail": "расширяющаяся от центра спираль с прогрессивным уроном по радиусу",
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
	# FAN-1034: единственная ось геометрии поражения — растит aoe_radius, aura_radius
	# и melee-дальность (range_scales_with_aoe). Прежние отдельные оси «Ширина
	# сектора» (sector_multiplier, no-op для 46/51 оружий) и «Радиус» слиты сюда.
	{"id": "aoe_radius", "name": "Область поражения", "icon": "aoe_radius", "value_type": "percent"},
	{"id": "pickup_radius", "name": "Радиус подбора", "icon": "pickup_radius", "value_type": "flat"},
	{"id": "defense", "name": "Защита", "icon": "defense", "value_type": "percent"},
	{"id": "magic_focus", "name": "Магический фокус", "icon": "magic_damage", "value_type": "percent"},
	{"id": "crit_chance", "name": "Шанс крита", "icon": "crit_chance", "value_type": "percent"},
	{"id": "crit_damage", "name": "Урон крита", "icon": "crit_damage_multiplier", "value_type": "percent"},
	{"id": "dodge", "name": "Уклонение", "icon": "dodge", "value_type": "percent"},
	{"id": "range", "name": "Дальность атаки", "icon": "attack_range", "value_type": "percent"},
	# FAN-1034: поглотил ось «Скорость тиков» (dot_speed) — карта качает и магнитуду,
	# и темп периодики одним пиком.
	{"id": "dot_damage", "name": "Периодический урон", "icon": "dot_damage", "value_type": "flat"},
	{"id": "buff_power", "name": "Сила поддержки", "icon": "buff_power", "value_type": "percent"},
	{"id": "summon_amount", "name": "Сила призыва", "icon": "summon_amount", "value_type": "flat"},
	{"id": "absorb", "name": "Поглощение", "icon": "absorb", "value_type": "flat"},
	{"id": "regeneration", "name": "Регенерация", "icon": "regeneration", "value_type": "flat"},
	# FAN-1034: мерж «Вампиризм (шанс)» + «Вампиризм (лечение)»: обе оси лили в одно
	# ведро heal-бюджета 1.1 HP/с, две отдельные карты были избыточны.
	{"id": "vampiric", "name": "Вампиризм", "icon": "vampiric_amount", "value_type": "flat"},
	{"id": "ultimate_power", "name": "Сила ультимейта", "icon": "ultimate_multiplier", "value_type": "percent"},
]

# SCRUM-695/FAN-1034: ПРЯМАЯ матрица релевантности (атрибут × 17 классов),
# первоисточник полезности атрибута для класса. ИНВАРИАНТ по каждому атрибуту
# (проверяется tests/attribute_relevance_test.gd): ровно 2 primary,
# 5..8 secondary, минимум 1 optional, разбиение всех 17 классов полное;
# на класс приходится 1..3 primary-атрибута. Жёсткое «ровно 8 secondary»
# снято: у гейтнутых осей (magic_focus, buff_power) честных secondary меньше,
# и матрица не должна врать про мёртвые для класса оси.
# primary = сигнатурный геймплей класса; secondary = ощутимо полезно; optional =
# профильно мимо (Hero Select показывает как «Слабые атрибуты»).
const ATTRIBUTE_RELEVANCE := {
	# `damage` is also consumed by the active per-hero generic damage star, so the
	# Dark Mage remains secondary despite its three direct weapon channels being
	# magic/DoT. Doctor's physical Bone Saw branch alone does not displace that
	# full-build progression contract.
	"damage": {"primary": ["berserk", "soldier"], "secondary": ["thief", "elementalist", "sniper", "dark_mage", "assassin", "ranger", "chemist", "knight"]},
	"attack_speed": {"primary": ["guitarist", "soldier"], "secondary": ["thief", "elementalist", "sniper", "dark_mage", "assassin", "ranger", "doctor", "chemist"]},
	"max_health": {"primary": ["knight", "robot"], "secondary": ["berserk", "thief", "sniper", "priest", "engineer", "assassin", "ranger", "doctor"]},
	"move_speed": {"primary": ["thief", "ranger"], "secondary": ["berserk", "elementalist", "sniper", "biologist", "dark_mage", "assassin", "chemist", "knight"]},
	# FAN-1034: единая ось геометрии (бывшие «Ширина сектора»+«Радиус»). Secondary —
	# классы, где радиус зон/аур/melee-охвата ощутим: свипы берсерка
	# (range_scales_with_aoe), граната солдата, ауры жреца/друида, зоны робота,
	# мины инженера, взрывы тёмного мага, волны гитариста.
	"aoe_radius": {"primary": ["elementalist", "chemist"], "secondary": ["berserk", "soldier", "priest", "robot", "engineer", "dark_mage", "guitarist", "druid"]},
	# Thief owns the pickup trait. Engineer's remote device field is the second
	# strongest fit.
	"pickup_radius": {"primary": ["thief", "engineer"], "secondary": ["berserk", "elementalist", "sniper", "robot", "assassin", "ranger", "chemist", "knight"]},
	# Armored Hull is an always-on mitigation mechanic; dodge specialists do not
	# treat the separate armor/defense axis as kit-defining.
	"defense": {"primary": ["knight", "priest"], "secondary": ["robot", "elementalist", "sniper", "engineer", "assassin", "ranger", "doctor", "chemist"]},
	# FAN-1034: карта гейтнута class_affinity на 8 маг-классов — у физ-классов ось
	# magic_damage мертва (ни одно их оружие не читает magic-канал), держать их
	# в secondary было ложью матрицы.
	"magic_focus": {"primary": ["dark_mage", "elementalist"], "secondary": ["priest", "biologist", "guitarist", "doctor", "chemist", "druid"]},
	# Assassin owns the unique 100% crit cap/overflow trait and must be primary.
	# FAN-1034: биолог/друид выведены из secondary — тики DoT и тела призывов
	# не критуют; инженер/рыцарь введены (устройства и melee критуют штатно).
	"crit_chance": {"primary": ["assassin", "sniper"], "secondary": ["berserk", "soldier", "thief", "robot", "engineer", "dark_mage", "ranger", "knight"]},
	"crit_damage": {"primary": ["sniper", "assassin"], "secondary": ["berserk", "soldier", "thief", "robot", "engineer", "dark_mage", "ranger", "knight"]},
	"dodge": {"primary": ["thief", "assassin"], "secondary": ["berserk", "soldier", "sniper", "biologist", "guitarist", "ranger", "doctor", "druid"]},
	"range": {"primary": ["sniper", "ranger"], "secondary": ["soldier", "elementalist", "priest", "biologist", "engineer", "dark_mage", "chemist", "druid"]},
	# Catalyst multiplies every periodic branch by 1.5. Plague Oath makes the
	# Doctor's long plague DoT the sole scalable source of weapon-only sustain,
	# so it is kit-defining. FAN-1034: ось поглотила dot_speed; гитарист (нет
	# DoT-оружия) заменён рейнджером (кровотечение капкана).
	"dot_damage": {"primary": ["doctor", "chemist"], "secondary": ["elementalist", "priest", "biologist", "engineer", "dark_mage", "assassin", "ranger", "druid"]},
	# FAN-1034: карта гейтнута class_affinity на 7 классов с реальными
	# потребителями buff_power (veil ассасина, ауры жреца/друида/гитариста/
	# инженера, arcane_vulnerability тёмного мага/элементалиста).
	"buff_power": {"primary": ["priest", "druid"], "secondary": ["guitarist", "engineer", "assassin", "dark_mage", "elementalist"]},
	# FAN-1034: химик введён в secondary (гомункул — призыв), рыцарь выведен.
	"summon_amount": {"primary": ["engineer", "druid"], "secondary": ["elementalist", "priest", "biologist", "robot", "dark_mage", "guitarist", "doctor", "chemist"]},
	"absorb": {"primary": ["knight", "robot"], "secondary": ["berserk", "soldier", "priest", "biologist", "engineer", "guitarist", "doctor", "druid"]},
	# Plague Oath explicitly blocks generic regen/vampirism. Priest's selectable
	# Mending prayer and Druid sustain remain the true regeneration primaries.
	"regeneration": {"primary": ["priest", "druid"], "secondary": ["berserk", "soldier", "biologist", "robot", "engineer", "guitarist", "knight", "chemist"]},
	# FAN-1034: мерж двух вампиризм-осей. Берсерк (rage-сустейн) и биолог
	# (infection loop) — владельцы; друид выведен (удары призывов не проксят
	# on_weapon_hit), рейнджер введён (высокая частота хитов).
	"vampiric": {"primary": ["berserk", "biologist"], "secondary": ["soldier", "thief", "assassin", "robot", "guitarist", "priest", "knight", "ranger"]},
	"ultimate_power": {"primary": ["elementalist", "guitarist"], "secondary": ["berserk", "soldier", "priest", "robot", "engineer", "dark_mage", "doctor", "druid"]},
}
