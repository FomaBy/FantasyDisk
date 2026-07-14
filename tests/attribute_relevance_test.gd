extends SceneTree

# SCRUM-695/FAN-1034: data-валидатор матрицы релевантности атрибутов + правила
# level-up-наград. Инвариант по каждому атрибуту: ровно 2 primary, 5..8 secondary,
# минимум 1 optional, полное разбиение 17 классов; на класс 1..3 primary-атрибута.
# Плюс рассинхрон каноничного реестра/матрицы/LEVEL_UP_REWARDS, порядок весов и
# правило показа наград (≤1 optional, ≥1 primary/secondary).
#
# Запуск: Godot --headless --path . --script res://tests/attribute_relevance_test.gd
# Отдельный изолированный файл (анти-коллизия с занятыми runtime_smoke/harness).

const ProgressionData := preload("res://scripts/progression_data.gd")

const EXPECT_PRIMARY := 2
const MIN_SECONDARY := 5
const MAX_SECONDARY := 8
const MIN_OPTIONAL := 1
const MIN_CLASS_PRIMARY := 1
const MAX_CLASS_PRIMARY := 3
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

	# A) Инвариант по каждому атрибуту (FAN-1034): ровно 2 primary, 5..8 secondary,
	# минимум 1 optional, разбиение всех 17 классов без дублей и пропусков,
	# валидные id классов. Жёсткое «ровно 8/7» снято: гейтнутые оси
	# (magic_focus/buff_power) не должны врать про мёртвые для класса оси.
	var matrix: Dictionary = ProgressionData.ATTRIBUTE_RELEVANCE
	var class_primary_counts := {}
	for attr in matrix.keys():
		var row: Dictionary = matrix[attr]
		var primary: Array = row.get("primary", [])
		var secondary: Array = row.get("secondary", [])
		if primary.size() != EXPECT_PRIMARY:
			_fail("%s: primary=%d (ожидалось %d)." % [attr, primary.size(), EXPECT_PRIMARY])
		if secondary.size() < MIN_SECONDARY or secondary.size() > MAX_SECONDARY:
			_fail("%s: secondary=%d (ожидалось %d..%d)." % [attr, secondary.size(), MIN_SECONDARY, MAX_SECONDARY])
		var seen := {}
		var optional_count := 0
		for character_id in classes:
			if not classes.has(character_id):
				continue
			var rel: String = ProgressionData.attribute_relevance(str(attr), character_id)
			if rel == "optional":
				optional_count += 1
			seen[character_id] = rel
		if optional_count < MIN_OPTIONAL:
			_fail("%s: optional=%d (< %d, порядок весов не проверяем)." % [attr, optional_count, MIN_OPTIONAL])
		for character_id in primary + secondary:
			if not classes.has(str(character_id)):
				_fail("%s: неизвестный класс '%s' в матрице." % [attr, character_id])
		for character_id in primary:
			class_primary_counts[str(character_id)] = int(class_primary_counts.get(str(character_id), 0)) + 1
		# Нет пересечения primary/secondary.
		for character_id in primary:
			if secondary.has(character_id):
				_fail("%s: класс '%s' одновременно primary и secondary." % [attr, character_id])

	# A2) На класс приходится 1..3 primary-атрибута: у каждого класса есть
	# сигнатурные оси, и ни один класс не монополизирует primary-слоты.
	for character_id in classes:
		var primary_count := int(class_primary_counts.get(str(character_id), 0))
		if primary_count < MIN_CLASS_PRIMARY or primary_count > MAX_CLASS_PRIMARY:
			_fail("%s: %d primary-атрибутов (ожидалось %d..%d)." % [character_id, primary_count, MIN_CLASS_PRIMARY, MAX_CLASS_PRIMARY])

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
	print("Attribute relevance validator passed: %d атрибутов × %d классов, инвариант 2 primary / 5..8 secondary / ≥1 optional и правило наград соблюдены." % [matrix.size(), class_count])
	quit(0)


func _first_optional(attr: String, classes: Array) -> String:
	for character_id in classes:
		if ProgressionData.attribute_relevance(attr, character_id) == "optional":
			return character_id
	return str(classes[0])
