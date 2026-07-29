extends SceneTree

# SCRUM-695/FAN-1034/FAN-1887: data-валидатор матрицы релевантности атрибутов +
# правила level-up-наград. FAN-1887 контракт: ровно 2 primary на ось, полное
# разбиение 17 классов, optional = «нет настоящего потребителя» (может быть
# пустым) и СТРОГО не участвует в выдаче; summon-ось точно совпадает с
# config-derived множеством class_summon_capable; Лидерство не предлагается
# классам без summon/deploy-потребителя; титулы карт = имена реестра.
#
# Запуск: Godot --headless --path . --script res://tests/attribute_relevance_test.gd
# Отдельный изолированный файл (анти-коллизия с занятыми runtime_smoke/harness).

const ProgressionData := preload("res://scripts/progression_data.gd")

const EXPECT_PRIMARY := 2
const MIN_CLASS_PRIMARY := 1
const MAX_CLASS_PRIMARY := 3
const OFFER_SIZE := 3
const SAMPLE_SEEDS := 200
const EXPECTED_SUMMON_CAPABLE := ["chemist", "druid", "engineer", "guitarist"]

var _failed := false


func _fail(message: String) -> void:
	push_error("[attr-relevance] FAIL: %s" % message)
	_failed = true


func _initialize() -> void:
	var classes: Array = ProgressionData.character_ids()
	var class_count := classes.size()
	if class_count != 17:
		_fail("Ожидалось 17 классов, получено %d." % class_count)

	# A) Инвариант по каждой оси (FAN-1887): ровно 2 primary, разбиение всех 17
	# классов без дублей и пропусков, валидные id классов. Optional допустимо
	# пустое (универсальные оси работают каждому классу).
	var matrix: Dictionary = ProgressionData.ATTRIBUTE_RELEVANCE
	var class_primary_counts := {}
	for attr in matrix.keys():
		var row: Dictionary = matrix[attr]
		var primary: Array = row.get("primary", [])
		var secondary: Array = row.get("secondary", [])
		if primary.size() != EXPECT_PRIMARY:
			_fail("%s: primary=%d (ожидалось %d)." % [attr, primary.size(), EXPECT_PRIMARY])
		for character_id in primary + secondary:
			if not classes.has(str(character_id)):
				_fail("%s: неизвестный класс '%s' в матрице." % [attr, character_id])
		for character_id in primary:
			class_primary_counts[str(character_id)] = int(class_primary_counts.get(str(character_id), 0)) + 1
			if secondary.has(character_id):
				_fail("%s: класс '%s' одновременно primary и secondary." % [attr, character_id])
		if primary.size() + secondary.size() > class_count:
			_fail("%s: primary+secondary больше числа классов." % attr)

	# A2) На класс приходится 1..3 primary-атрибута: у каждого класса есть
	# сигнатурные оси, и ни один класс не монополизирует primary-слоты.
	for character_id in classes:
		var primary_count := int(class_primary_counts.get(str(character_id), 0))
		if primary_count < MIN_CLASS_PRIMARY or primary_count > MAX_CLASS_PRIMARY:
			_fail("%s: %d primary-атрибутов (ожидалось %d..%d)." % [character_id, primary_count, MIN_CLASS_PRIMARY, MAX_CLASS_PRIMARY])

	# A3) Capability-ось призыва: множество классов с реальным summon/deploy
	# потребителем выводится из конфигов оружий (class_summon_capable) и должно
	# точно совпадать и с ожидаемым составом, и с non-optional частью матрицы.
	var capable := []
	for character_id in classes:
		if ProgressionData.class_summon_capable(str(character_id)):
			capable.append(str(character_id))
	capable.sort()
	if capable != EXPECTED_SUMMON_CAPABLE:
		_fail("class_summon_capable=%s (ожидалось %s)." % [str(capable), str(EXPECTED_SUMMON_CAPABLE)])
	for character_id in classes:
		var is_capable := ProgressionData.class_summon_capable(str(character_id))
		var rel := ProgressionData.attribute_relevance("summon_amount", str(character_id))
		if is_capable and rel == "optional":
			_fail("summon_amount: capable-класс '%s' помечен optional." % character_id)
		if not is_capable and rel != "optional":
			_fail("summon_amount: класс '%s' без потребителя не optional (fake echo?)." % character_id)
		if ProgressionData.is_base_stat_consumable("leadership", str(character_id)) != is_capable:
			_fail("leadership consumability рассинхронизирована с capability у '%s'." % character_id)

	# B) Реестр ↔ матрица ↔ LEVEL_UP_REWARDS — единый источник правды: id, размер
	# и player-facing имена (титул карты = имя оси реестра, AC-1 FAN-1887).
	var registry: Array = ProgressionData.ATTRIBUTE_REGISTRY
	var registry_ids := {}
	var registry_names := {}
	for entry in registry:
		var attr_id := str(entry.get("id", ""))
		if attr_id == "":
			_fail("В реестре есть запись без id.")
			continue
		if registry_ids.has(attr_id):
			_fail("Дубль id '%s' в реестре." % attr_id)
		registry_ids[attr_id] = true
		registry_names[attr_id] = str(entry.get("name", ""))
		if not matrix.has(attr_id):
			_fail("Реестр: '%s' отсутствует в матрице релевантности." % attr_id)
	for attr in matrix.keys():
		if not registry_ids.has(str(attr)):
			_fail("Матрица: '%s' отсутствует в каноничном реестре." % attr)
	if registry.size() != matrix.size():
		_fail("Размер реестра (%d) != размер матрицы (%d)." % [registry.size(), matrix.size()])
	for removed_attr in ["magic_focus", "range", "buff_power", "absorb"]:
		if registry_ids.has(removed_attr):
			_fail("Снятая ось '%s' всё ещё в реестре." % removed_attr)
	var reward_attrs := {}
	for reward in ProgressionData.LEVEL_UP_REWARDS:
		var attr_id := str(reward.get("attr", ""))
		if attr_id == "":
			_fail("Награда '%s' без поля attr." % str(reward.get("id", "?")))
			continue
		if not registry_ids.has(attr_id):
			_fail("Награда '%s': attr '%s' не в реестре." % [reward.get("id", "?"), attr_id])
		if reward_attrs.has(attr_id):
			_fail("Два LEVEL_UP_REWARDS ссылаются на один attr '%s'." % attr_id)
		reward_attrs[attr_id] = true
		if str(reward.get("title", "")) != str(registry_names.get(attr_id, "")):
			_fail("Награда '%s': титул '%s' != имени реестра '%s'." % [reward.get("id", "?"), reward.get("title", ""), registry_names.get(attr_id, "")])
	for attr_id in registry_ids.keys():
		if not reward_attrs.has(str(attr_id)):
			_fail("Ось '%s' реестра без level-up карты." % attr_id)

	# C) Порядок весов внутри выдаваемых категорий: primary > secondary.
	for attr in matrix.keys():
		var row: Dictionary = matrix[attr]
		var p_class := str((row.get("primary", []) as Array)[0])
		var s_class := str((row.get("secondary", []) as Array)[0])
		var reward := {"attr": str(attr), "mods": {}}
		var wp: float = ProgressionData.level_up_reward_weight(reward, p_class)
		var ws: float = ProgressionData.level_up_reward_weight(reward, s_class)
		if not (wp > ws):
			_fail("%s: вес не упорядочен primary>secondary (%.2f/%.2f)." % [attr, wp, ws])

	# D) СТРОГОЕ правило показа (FAN-1887): на многих сэмплах по каждому классу
	# набор из 3 наград уникален и содержит НОЛЬ optional-карт; summon-карты и
	# чисто лидерские stat-карты не приходят классам без capability.
	for character_id in classes:
		var regular_pool: Array = ProgressionData.level_up_rewards(character_id)
		var stat_pool: Array = ProgressionData.main_stat_level_up_rewards(character_id)
		var is_capable := ProgressionData.class_summon_capable(str(character_id))
		for seed_index in range(SAMPLE_SEEDS):
			var rng := RandomNumberGenerator.new()
			rng.seed = 770000 + seed_index
			var offer: Array = AttributeContract.weighted_level_up_selection(
				regular_pool, stat_pool, OFFER_SIZE, character_id, rng)
			if offer.size() != OFFER_SIZE:
				_fail("%s seed %d: набор %d != %d." % [character_id, seed_index, offer.size(), OFFER_SIZE])
				break
			var ids := {}
			var broke := false
			for reward in offer:
				var rid := str(reward.get("id", ""))
				if ids.has(rid):
					_fail("%s seed %d: дубль награды '%s'." % [character_id, seed_index, rid])
				ids[rid] = true
				if ProgressionData.reward_is_optional(reward, character_id):
					_fail("%s seed %d: optional-карта '%s' в наборе." % [character_id, seed_index, rid])
					broke = true
				if not is_capable and (str(reward.get("attr", "")) == "summon_amount" or rid == "levelup_stat_leadership"):
					_fail("%s seed %d: summon/leadership-карта '%s' без capability." % [character_id, seed_index, rid])
					broke = true
			if broke:
				break

	if _failed:
		push_error("Attribute relevance validator FAILED.")
		quit(1)
		return
	print("Attribute relevance validator passed: %d осей × %d классов, контракт FAN-1887 (2 primary, строгий optional-фильтр, config-derived summon capability) соблюдён." % [matrix.size(), class_count])
	quit(0)
