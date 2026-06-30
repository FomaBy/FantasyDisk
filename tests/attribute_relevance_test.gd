extends SceneTree

# SCRUM-695: data-валидатор матрицы релевантности атрибутов + правила level-up-наград.
# Ловит любое нарушение жёсткого инварианта 2/8/7 по каждому атрибуту, рассинхрон
# каноничного реестра/матрицы/LEVEL_UP_REWARDS, неверный порядок весов и нарушение
# правила показа наград (≤1 optional, ≥1 primary/secondary).
#
# Запуск: Godot --headless --path . --script res://tests/attribute_relevance_test.gd
# Отдельный изолированный файл (анти-коллизия с занятыми runtime_smoke/harness).

const ProgressionData := preload("res://scripts/progression_data.gd")

const EXPECT_PRIMARY := 2
const EXPECT_SECONDARY := 8
const EXPECT_OPTIONAL := 7
const OFFER_SIZE := 3
const SAMPLE_SEEDS := 200

var _failed := false


func _fail(message: String) -> void:
	push_error("[attr-relevance] FAIL: %s" % message)
	_failed = true


func _initialize() -> void:
	var classes: Array = ProgressionData.character_ids()
	var class_count := classes.size()
	if class_count != 17:
		_fail("Ожидалось 17 классов, получено %d." % class_count)

	# A) Жёсткий инвариант по каждому атрибуту: 2 primary / 8 secondary / 7 optional,
	# разбиение всех 17 классов без дублей и пропусков, валидные id классов.
	var matrix: Dictionary = ProgressionData.ATTRIBUTE_RELEVANCE
	for attr in matrix.keys():
		var row: Dictionary = matrix[attr]
		var primary: Array = row.get("primary", [])
		var secondary: Array = row.get("secondary", [])
		if primary.size() != EXPECT_PRIMARY:
			_fail("%s: primary=%d (ожидалось %d)." % [attr, primary.size(), EXPECT_PRIMARY])
		if secondary.size() != EXPECT_SECONDARY:
			_fail("%s: secondary=%d (ожидалось %d)." % [attr, secondary.size(), EXPECT_SECONDARY])
		var seen := {}
		var optional_count := 0
		for character_id in classes:
			if not classes.has(character_id):
				continue
			var rel: String = ProgressionData.attribute_relevance(str(attr), character_id)
			if rel == "optional":
				optional_count += 1
			seen[character_id] = rel
		if optional_count != EXPECT_OPTIONAL:
			_fail("%s: optional=%d (ожидалось %d)." % [attr, optional_count, EXPECT_OPTIONAL])
		for character_id in primary + secondary:
			if not classes.has(str(character_id)):
				_fail("%s: неизвестный класс '%s' в матрице." % [attr, character_id])
		# Нет пересечения primary/secondary.
		for character_id in primary:
			if secondary.has(character_id):
				_fail("%s: класс '%s' одновременно primary и secondary." % [attr, character_id])

	# B) Реестр ↔ матрица ↔ LEVEL_UP_REWARDS — единый источник правды без расхождений.
	var registry: Array = ProgressionData.ATTRIBUTE_REGISTRY
	var registry_ids := {}
	for entry in registry:
		var attr_id := str(entry.get("id", ""))
		if attr_id == "":
			_fail("В реестре есть запись без id.")
			continue
		if registry_ids.has(attr_id):
			_fail("Дубль id '%s' в реестре." % attr_id)
		registry_ids[attr_id] = true
		if not matrix.has(attr_id):
			_fail("Реестр: '%s' отсутствует в матрице релевантности." % attr_id)
	for attr in matrix.keys():
		if not registry_ids.has(str(attr)):
			_fail("Матрица: '%s' отсутствует в каноничном реестре." % attr)
	if registry.size() != matrix.size():
		_fail("Размер реестра (%d) != размер матрицы (%d)." % [registry.size(), matrix.size()])
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

	# C) Порядок весов: primary > secondary > optional, optional держится > 0.3
	# (контракт «небазовые атрибуты остаются доступны»).
	for attr in matrix.keys():
		var row: Dictionary = matrix[attr]
		var p_class := str((row.get("primary", []) as Array)[0])
		var s_class := str((row.get("secondary", []) as Array)[0])
		var o_class := _first_optional(str(attr), classes)
		var reward := {"attr": str(attr), "mods": {}}
		var wp: float = ProgressionData.level_up_reward_weight(reward, p_class)
		var ws: float = ProgressionData.level_up_reward_weight(reward, s_class)
		var wo: float = ProgressionData.level_up_reward_weight(reward, o_class)
		if not (wp > ws and ws > wo):
			_fail("%s: вес не упорядочен primary>secondary>optional (%.2f/%.2f/%.2f)." % [attr, wp, ws, wo])
		if wo <= 0.3:
			_fail("%s: optional-вес %.2f <= 0.3 (награда выпадает из пула)." % [attr, wo])

	# D) Правило показа: на многих сэмплах по каждому классу набор из 3 наград
	# содержит НЕ БОЛЕЕ 1 optional и МИНИМУМ 1 primary/secondary; варианты уникальны.
	for character_id in classes:
		var regular_pool: Array = ProgressionData.level_up_rewards(character_id)
		var stat_pool: Array = ProgressionData.main_stat_level_up_rewards(character_id)
		for seed_index in range(SAMPLE_SEEDS):
			var rng := RandomNumberGenerator.new()
			rng.seed = 770000 + seed_index
			var offer: Array = ProgressionData.weighted_level_up_selection(
				regular_pool, stat_pool, OFFER_SIZE, character_id, rng)
			if offer.size() != OFFER_SIZE:
				_fail("%s seed %d: набор %d != %d." % [character_id, seed_index, offer.size(), OFFER_SIZE])
				break
			var optional_in_offer := 0
			var non_optional_in_offer := 0
			var ids := {}
			for reward in offer:
				var rid := str(reward.get("id", ""))
				if ids.has(rid):
					_fail("%s seed %d: дубль награды '%s'." % [character_id, seed_index, rid])
				ids[rid] = true
				if ProgressionData.reward_is_optional(reward, character_id):
					optional_in_offer += 1
				else:
					non_optional_in_offer += 1
			if optional_in_offer > 1:
				_fail("%s seed %d: %d optional в наборе (>1)." % [character_id, seed_index, optional_in_offer])
				break
			if non_optional_in_offer < 1:
				_fail("%s seed %d: набор без primary/secondary." % [character_id, seed_index])
				break

	if _failed:
		push_error("Attribute relevance validator FAILED.")
		quit(1)
		return
	print("Attribute relevance validator passed: %d атрибутов × %d классов, инвариант 2/8/7 и правило наград соблюдены." % [matrix.size(), class_count])
	quit(0)


func _first_optional(attr: String, classes: Array) -> String:
	for character_id in classes:
		if ProgressionData.attribute_relevance(attr, character_id) == "optional":
			return character_id
	return str(classes[0])
