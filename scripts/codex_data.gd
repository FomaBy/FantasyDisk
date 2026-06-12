extends RefCounted

# Данные внутриигрового Кодекса (энциклопедии). Единственное место, где живут
# описания и КАНОНИЧЕСКИЕ имена умений монстров — они зарегистрированы в
# docs/design/content_registry.md и используются как ссылочные в задачах.
# Персонажи, оружие, артефакты и характеристики собираются из
# progression_data.gd / stat_formulas.gd, а не дублируются строками.

const PROGRESSION_DATA := preload("res://scripts/progression_data.gd")
const STAT_FORMULAS := preload("res://scripts/stat_formulas.gd")

# Канонические умения монстров: ability id -> игровое имя (RU).
# Источник истины имен: docs/design/content_registry.md, раздел «Умения Монстров».
const MONSTERS := [
	{
		"id": "rift_cutter", "title": "Рубака Разлома", "kind": "standard",
		"sprite": "res://assets/sprites/enemies/enemy_melee.png",
		"behavior": "Основа любой волны: упрямо идет к герою и рубит в упор. По одному не страшен — страшен строй.",
		"abilities": [
			{"id": "ragged_lunge", "title": "Рваный Выпад", "description": "Контактный удар с коротким замахом — окно, чтобы выйти из-под лезвия."},
		],
	},
	{
		"id": "ash_marksman", "title": "Пепельный Стрелок", "kind": "standard",
		"sprite": "res://assets/sprites/enemies/enemy_ranged.png",
		"behavior": "Держит дистанцию и наказывает за прямые забеги. Редок, но заставляет двигаться.",
		"abilities": [
			{"id": "ash_shot", "title": "Пепельный Выстрел", "description": "Одиночный снаряд по герою с заметным полетом — уворачивается движением вбок."},
		],
	},
	{
		"id": "spark_runner", "title": "Искровой Беглец", "kind": "standard",
		"sprite": "res://assets/sprites/enemies/enemy_suicide_runner.png",
		"behavior": "Быстрый преследователь. Появляется пачками и сжимает кольцо, пока герой отвлечен.",
		"abilities": [
			{"id": "spark_rush", "title": "Искровой Натиск", "description": "Высокая скорость сближения: догоняет зазевавшегося героя раньше остальных."},
		],
	},
	{
		"id": "stone_bruiser", "title": "Каменный Громила", "kind": "standard",
		"sprite": "res://assets/sprites/enemies/enemy_bruiser_slow.png",
		"behavior": "Живая стена: медленный, но почти не продавливается. Запирает коридоры отступления.",
		"abilities": [
			{"id": "stone_press", "title": "Каменный Напор", "description": "Тяжелый контактный удар; высокий запас здоровья держит фронт волны."},
		],
	},
	{
		"id": "bone_caller", "title": "Костяной Зовущий", "kind": "standard",
		"sprite": "res://assets/sprites/enemies/enemy_summoner.png",
		"behavior": "Прячется за чужими спинами и множит толпу. Приоритетная цель.",
		"abilities": [
			{"id": "bone_call", "title": "Зов Костей", "description": "Призывает малых кусателей, пока жив — толпа не кончается."},
		],
	},
	{
		"id": "void_mage", "title": "Маг Пустоты", "kind": "standard",
		"sprite": "res://assets/sprites/enemies/enemy_void_mage.png",
		"behavior": "Магический стрелок: осторожная походка, злые снаряды. Дальняя угроза второй линии.",
		"abilities": [
			{"id": "void_bolt", "title": "Сгусток Пустоты", "description": "Магический снаряд по герою; летит дальше и злее обычной стрелы."},
		],
	},
	{
		"id": "venom_spitter", "title": "Ядовитый Плеватель", "kind": "standard",
		"sprite": "res://assets/sprites/enemies/enemy_venom_spitter.png",
		"behavior": "Плюется издали и продавливает позицию героя, вынуждая уступать землю.",
		"abilities": [
			{"id": "venom_spit", "title": "Ядовитый Плевок", "description": "Дальнобойный плевок; в связке со стрелками лишает героя спокойных углов."},
		],
	},
	{
		"id": "rift_shieldbearer", "title": "Щитоносец Разлома", "kind": "standard",
		"sprite": "res://assets/sprites/enemies/enemy_rift_shieldbearer.png",
		"behavior": "Передняя линия разлома: живучий, медленный, прикрывает стрелков и зовущих.",
		"abilities": [
			{"id": "rift_wall", "title": "Стена Разлома", "description": "Повышенная живучесть: дольше всех стоит под ударами и тянет время волны."},
		],
	},
	{
		"id": "small_biter", "title": "Малый Кусатель", "kind": "standard",
		"sprite": "res://assets/sprites/enemies/enemy_small_biter.png",
		"behavior": "Мелочь, которой всегда много. По одиночке — ничто, стаей — смерть от тысячи укусов.",
		"abilities": [
			{"id": "swarm_bite", "title": "Укус Стаи", "description": "Быстрые слабые укусы; опасен количеством и скоростью, а не силой."},
		],
	},
	{
		"id": "bone_shaman", "title": "Костяной Шаман", "kind": "standard",
		"sprite": "res://assets/sprites/enemies/enemy_bone_shaman.png",
		"behavior": "Старший зовущий: ритуальная походка, костяная свита. Чем дольше жив — тем гуще толпа.",
		"abilities": [
			{"id": "bone_rite", "title": "Костяной Ритуал", "description": "Ритуальный призыв свиты; усиливает давление волны, пока шамана не заткнут."},
		],
	},
	{
		"id": "winged_spark", "title": "Крылатая Искра", "kind": "standard",
		"sprite": "res://assets/sprites/enemies/enemy_winged_spark.png",
		"behavior": "Летающий преследователь: игнорирует толкучку на земле и заходит с неудобной стороны.",
		"abilities": [
			{"id": "spark_dive", "title": "Пикирование Искры", "description": "Hover-полет и быстрый заход на героя поверх наземной свалки."},
		],
	},
	{
		"id": "iron_bastion", "title": "Железный Оплот", "kind": "elite",
		"sprite": "res://assets/sprites/elites/iron_bastion.png",
		"behavior": "Ходячая крепость. Перебить его в лоб — затея для тех, кому некуда спешить.",
		"abilities": [
			{"id": "iron_shield", "title": "Железный Щит", "description": "Периодически накрывается щитом, резко снижающим входящий урон."},
			{"id": "quaking_slam", "title": "Сотрясающий Удар", "description": "Замах и кольцевая ударная волна: урон и отбрасывание. Телеграф — круг под ногами; выходи из кольца."},
		],
	},
	{
		"id": "night_stalker", "title": "Ночной Сталкер", "kind": "elite",
		"sprite": "res://assets/sprites/elites/night_stalker.png",
		"behavior": "Охотится перебежками и исчезает из виду, когда решил убивать.",
		"abilities": [
			{"id": "predator_dash", "title": "Хищный Рывок", "description": "Резкое сближение рывком — наказывает за дистанцию по прямой."},
			{"id": "shadow_strike", "title": "Теневой Удар", "description": "Уходит в тень и выныривает за спиной героя. Метка тени показывает точку удара — шаг в сторону спасает."},
		],
	},
	{
		"id": "plague_prophet", "title": "Чумной Пророк", "kind": "elite",
		"sprite": "res://assets/sprites/elites/plague_prophet.png",
		"behavior": "Проповедует гниль: размечает землю знамениями и засеивает ее ядом.",
		"abilities": [
			{"id": "rot_omen", "title": "Гнилое Знамение", "description": "Отмечает зону под героем и взрывает ее ядом после задержки."},
			{"id": "venom_volley", "title": "Ядовитый Залп", "description": "Три навесных снаряда по меткам; в точках падения остаются ядовитые лужи с тикающим уроном."},
		],
	},
	{
		"id": "shard_marshal", "title": "Маршал Осколков", "kind": "elite",
		"sprite": "res://assets/sprites/elites/shard_marshal.png",
		"behavior": "Командир волны: рядом с ним обычные монстры злее, а воздух полон кристальных осколков.",
		"abilities": [
			{"id": "shard_aura", "title": "Аура Осколков", "description": "Единожды усиливает скорость и урон обычных монстров поблизости."},
			{"id": "shard_fan", "title": "Веер Осколков", "description": "После замаха выпускает веер из пяти кристальных снарядов в сторону героя."},
		],
	},
	{
		"id": "rift_warden", "title": "Страж Разлома", "kind": "boss",
		"sprite": "res://assets/sprites/bosses/boss_rift_warden.png",
		"behavior": "Финал акта: страж, который не подпускает и не отпускает. Бой идет до смерти — его или твоей.",
		"abilities": [
			{"id": "rift_volley", "title": "Залп Разлома", "description": "Веерный залп снарядов по герою."},
			{"id": "rift_zone", "title": "Зона Разлома", "description": "Размечает землю и взрывает ее энергией разлома после задержки."},
			{"id": "riftling_call", "title": "Призыв Осколышей", "description": "Призывает свиту малых тварей, тройками."},
			{"id": "warden_shield", "title": "Щит Стража", "description": "Периодический щит, режущий входящий урон."},
			{"id": "flicker_step", "title": "Мерцающий Уход", "description": "Шанс полностью уйти от удара, мерцая в разломе."},
		],
	},
	{
		"id": "disk_devourer", "title": "Пожиратель Диска", "kind": "boss",
		"sprite": "res://assets/sprites/bosses/boss_disk_devourer.png",
		"behavior": "Голод в форме зверя. Чем меньше у него здоровья, тем быстрее он хочет есть.",
		"abilities": [
			{"id": "devourer_dash", "title": "Рывок Пожирателя", "description": "Стремительный бросок к герою через пол-арены."},
			{"id": "disk_slam", "title": "Удар Диска", "description": "Прыжок с приземлением: круговая зона удара по площади."},
			{"id": "radial_burst", "title": "Радиальный Взрыв", "description": "Кольцо снарядов во все стороны разом."},
			{"id": "devourer_frenzy", "title": "Ярость Пожирателя", "description": "На последней трети здоровья ускоряется и бьет чаще."},
		],
	},
	{
		"id": "mini_scavenger_reaper", "title": "Жнец-Падальщик", "kind": "mini_elite",
		"sprite": "res://assets/sprites/elites/night_stalker.png",
		"behavior": "Свита Возвышения. Быстрый падальщик: рывками косит по дуге, добивая раненых первыми.",
		"abilities": [
			{"id": "reaping_dash", "title": "Косящий Рывок", "description": "Серия рывков по дуге — держи дистанцию и не подставляй спину."},
		],
	},
	{
		"id": "mini_plague_bellringer", "title": "Чумной Звонарь", "kind": "mini_elite",
		"sprite": "res://assets/sprites/elites/plague_prophet.png",
		"behavior": "Свита Возвышения. Медлительный звонарь чумы: сеет ядовитые лужи вокруг себя.",
		"abilities": [
			{"id": "toxic_peal", "title": "Ядовитый Звон", "description": "Оставляет расходящиеся лужи яда — не стой в зелёном."},
		],
	},
	{
		"id": "mini_bone_warden", "title": "Костяной Страж", "kind": "mini_elite",
		"sprite": "res://assets/sprites/elites/iron_bastion.png",
		"behavior": "Свита Возвышения. Костяной танк: бьёт ударной волной и держит строй, прикрывая свиту.",
		"abilities": [
			{"id": "warden_slam", "title": "Удар Стража", "description": "Кольцевая ударная волна с телеграфом — выйди из круга."},
		],
	},
	{
		"id": "mini_spark_wight", "title": "Искровик", "kind": "mini_elite",
		"sprite": "res://assets/sprites/elites/shard_marshal.png",
		"behavior": "Свита Возвышения. Дальнобойный дух искр: бьёт залпом веером с предупреждающим телеграфом.",
		"abilities": [
			{"id": "spark_volley", "title": "Залп Искр", "description": "Веер искр по направлению к герою — шагни вбок до выстрела."},
		],
	},
	{
		"id": "mini_rot_hound", "title": "Гнилая Гончая", "kind": "mini_elite",
		"sprite": "res://assets/sprites/elites/night_stalker.png",
		"behavior": "Свита Возвышения. Стайная гончая гнили: налетает рывком, оставляя кровоточащие раны.",
		"abilities": [
			{"id": "rabid_lunge", "title": "Бешеный Бросок", "description": "Резкий рывок в упор; опасна в стае — не давай окружить."},
		],
	},
	{
		"id": "mini_shadow_devourer", "title": "Теневой Пожиратель", "kind": "mini_elite",
		"sprite": "res://assets/sprites/elites/night_stalker.png",
		"behavior": "Свита Возвышения. Тень-пожиратель: телепортируется к жертве после короткого телеграфа.",
		"abilities": [
			{"id": "shadow_blink", "title": "Теневой Скачок", "description": "Метка тени показывает точку выхода — сместись до удара."},
		],
	},
]

const CHARACTER_PLAYSTYLE := {
	"berserk": "Игра в упор: води толпу, выбирай момент и руби. Меч — точная полоса, топор — широкая дуга, молот — слабый старт и страшный финал.",
	"dark_mage": "Хрупкий повелитель площадей: лучи, взрывы и проклятия делают работу, пока ты держишь дистанцию.",
	"guitarist": "Ритм и контроль: волны и пульсы расталкивают толпу, усилители держат сцену, пока ты двигаешься.",
	"assassin": "Танец на лезвии: возвращающиеся чакрамы и критовые рывки держат темп, но ошибка быстро стоит здоровья.",
	"ranger": "Стойка охотника: чем дольше не двигаешься, тем сильнее заряженный пробивающий выстрел.",
	"doctor": "Лечит то, что ранит других: drain-связи вытягивают жизнь из цели и превращают урон в sustain.",
	"chemist": "Земля после него не родит: газовые облака разных элементов накладываются и взрываются комбо.",
	"knight": "Стена с копьем: принимает удар щитом и отвечает контратакой, выигрывая время тяжелым контролем.",
	"druid": "Лес воюет за него: стая получает команды атаковать цель или держать охрану, а сила растет с Лидерством.",
}


static func characters() -> Array:
	var result := []
	for character_id in PROGRESSION_DATA.character_ids():
		var config: Dictionary = PROGRESSION_DATA.character_config(character_id)
		var weapons := []
		var class_weapons: Dictionary = PROGRESSION_DATA.WEAPONS_BY_CLASS.get(character_id, {})
		for weapon_id in class_weapons.keys():
			var weapon: Dictionary = class_weapons[weapon_id]
			weapons.append({
				"id": str(weapon.get("id", weapon_id)),
				"title": str(weapon.get("title", "")),
				"description": str(weapon.get("description", "")),
			})
		result.append({
			"id": character_id,
			"title": str(config.get("title", "")),
			"sprite": str(config.get("sprite_path", "")),
			"description": str(config.get("description", "")),
			"playstyle": str(CHARACTER_PLAYSTYLE.get(character_id, "")),
			"strengths": str(config.get("strengths", "")),
			"weaknesses": str(config.get("weaknesses", "")),
			"ultimate": PROGRESSION_DATA.ultimate_config(character_id),
			"weapons": weapons,
		})
	return result


static func monsters() -> Array:
	return MONSTERS


static func artifacts() -> Array:
	var result := []
	for artifact in PROGRESSION_DATA.ARTIFACTS:
		result.append({
			"id": str(artifact.get("id", "")),
			"title": str(artifact.get("title", "")),
			"description": str(artifact.get("description", "")),
			"tier": int(artifact.get("tier", 1)),
			"class_affinity": artifact.get("class_affinity", []),
			"source": "artifact",
		})
	for item in PROGRESSION_DATA.SHOP_ITEMS:
		result.append({
			"id": str(item.get("id", "")),
			"title": str(item.get("title", "")),
			"description": str(item.get("description", "")),
			"source": "shop",
		})
	return result


static func ascensions() -> Array:
	var result := []
	for entry in PROGRESSION_DATA.ascension_modifiers():
		result.append({
			"id": str(entry.get("id", "")),
			"level": int(entry.get("level", 0)),
			"title": str(entry.get("title", "")),
			"description": str(entry.get("description", "")),
		})
	return result


static func stats() -> Array:
	var result := []
	for stat_id in STAT_FORMULAS.STAT_DEFINITIONS.keys():
		var definition: Dictionary = STAT_FORMULAS.STAT_DEFINITIONS[stat_id]
		result.append({
			"id": str(stat_id),
			"title": str(definition.get("name_ru", str(stat_id))),
			"type": str(definition.get("type", "base")),
			"description": str(definition.get("description", "")),
			"influences": str(definition.get("influences", "")),
		})
	return result
