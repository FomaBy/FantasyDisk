extends SceneTree

# Integrity-тест данных наград (был непокрыт). Артефакт/награда без эффекта
# (пустые stats И mods) — молчаливый no-op: куплен/выбран, но ничего не делает,
# и это НЕ ловится ничем. Также: дубли id, битый tier без веса, неположительная
# цена. content_registry_consistency_test сверяет ИКОНКИ, не структуру эффектов.
# Отдельный изолированный файл (только ЧИТАЕТ progression_data.gd).
#
# Запуск: Godot --headless --path . --script res://tests/rewards_data_integrity_test.gd

const PD := preload("res://scripts/progression_data.gd")


func _initialize() -> void:
	var errors: Array = []

	_check_artifacts(errors)
	_check_shop_items(errors)
	_check_stat_rewards(errors)
	_check_level_up_rewards(errors)
	_check_ascension_modifiers(errors)
	_check_tier_weights(errors)

	if not errors.is_empty():
		for e in errors:
			push_error("Rewards data integrity: %s" % e)
		push_error("Rewards data integrity test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Rewards data integrity test passed (%d артефактов, %d магазин, %d stat-наград, %d level-up, %d вознесений)." % [
		PD.ARTIFACTS.size(), PD.SHOP_ITEMS.size(), PD.STAT_REWARDS.size(),
		PD.LEVEL_UP_REWARDS.size(), PD.ASCENSION_MODIFIERS.size()])
	quit(0)


# Непустой Dictionary под ключом.
func _has_effect(entry: Dictionary, key: String) -> bool:
	var v = entry.get(key, null)
	return v is Dictionary and not (v as Dictionary).is_empty()


func _check_artifacts(errors: Array) -> void:
	if PD.ARTIFACTS.size() < 40:
		errors.append("ARTIFACTS подозрительно мал (%d)" % PD.ARTIFACTS.size())
	var seen := {}
	for entry in PD.ARTIFACTS:
		var art: Dictionary = entry
		var aid := str(art.get("id", ""))
		if aid == "" or seen.has(aid):
			errors.append("артефакт с пустым/дублирующимся id '%s'" % aid)
			continue
		seen[aid] = true
		if str(art.get("title", "")).strip_edges() == "":
			errors.append("артефакт '%s': пустой title" % aid)
		var tier := int(art.get("tier", 0))
		if not PD.TIER_WEIGHTS.has(tier):
			errors.append("артефакт '%s': tier %d без веса в TIER_WEIGHTS" % [aid, tier])
		if int(art.get("cost", 0)) <= 0:
			errors.append("артефакт '%s': cost <= 0" % aid)
		# КЛЮЧЕВОЕ: эффект обязателен (иначе no-op). Артефакты бьют через
		# stats / mods / affinity_mods (классовый бонус по class_affinity).
		if not (_has_effect(art, "stats") or _has_effect(art, "mods") or _has_effect(art, "affinity_mods")):
			errors.append("артефакт '%s': нет эффекта (пустые stats/mods/affinity_mods) — молчаливый no-op" % aid)
		if not (art.get("class_affinity", []) is Array):
			errors.append("артефакт '%s': class_affinity не Array" % aid)
		# affinity_mods применяется только к классам class_affinity — пустой
		# список делает классовый бонус неприменимым (фактический no-op).
		elif _has_effect(art, "affinity_mods") and (art.get("class_affinity", []) as Array).is_empty():
			errors.append("артефакт '%s': affinity_mods при пустом class_affinity — бонус не применится" % aid)


func _check_shop_items(errors: Array) -> void:
	if PD.SHOP_ITEMS.is_empty():
		errors.append("SHOP_ITEMS пуст")
	var seen := {}
	# У товаров шире словарь эффектов (mods/stats/heal_percent/...), эффект строго
	# не проверяем — гейтим id/title/цену.
	for entry in PD.SHOP_ITEMS:
		var item: Dictionary = entry
		var iid := str(item.get("id", ""))
		if iid == "" or seen.has(iid):
			errors.append("товар с пустым/дублирующимся id '%s'" % iid)
			continue
		seen[iid] = true
		if str(item.get("title", "")).strip_edges() == "":
			errors.append("товар '%s': пустой title" % iid)
		if int(item.get("cost", 0)) <= 0:
			errors.append("товар '%s': cost <= 0" % iid)


func _check_stat_rewards(errors: Array) -> void:
	if PD.STAT_REWARDS.is_empty():
		errors.append("STAT_REWARDS пуст")
	var seen := {}
	for entry in PD.STAT_REWARDS:
		var reward: Dictionary = entry
		var rid := str(reward.get("id", ""))
		if rid == "" or seen.has(rid):
			errors.append("stat-награда с пустым/дублирующимся id '%s'" % rid)
			continue
		seen[rid] = true
		if str(reward.get("title", "")).strip_edges() == "":
			errors.append("stat-награда '%s': пустой title" % rid)
		if not _has_effect(reward, "stats"):
			errors.append("stat-награда '%s': пустые stats — no-op" % rid)


func _check_level_up_rewards(errors: Array) -> void:
	if PD.LEVEL_UP_REWARDS.is_empty():
		errors.append("LEVEL_UP_REWARDS пуст")
	var seen := {}
	for entry in PD.LEVEL_UP_REWARDS:
		var reward: Dictionary = entry
		var rid := str(reward.get("id", ""))
		if rid == "" or seen.has(rid):
			errors.append("level-up награда с пустым/дублирующимся id '%s'" % rid)
			continue
		seen[rid] = true
		if str(reward.get("title", "")).strip_edges() == "":
			errors.append("level-up '%s': пустой title" % rid)
		if not (_has_effect(reward, "mods") or _has_effect(reward, "stats")):
			errors.append("level-up '%s': нет эффекта (пустые mods И stats) — no-op" % rid)


func _check_ascension_modifiers(errors: Array) -> void:
	if PD.ASCENSION_MODIFIERS.is_empty():
		errors.append("ASCENSION_MODIFIERS пуст")
	var seen := {}
	for entry in PD.ASCENSION_MODIFIERS:
		var mod: Dictionary = entry
		var mid := str(mod.get("id", ""))
		if mid == "" or seen.has(mid):
			errors.append("вознесение с пустым/дублирующимся id '%s'" % mid)
			continue
		seen[mid] = true
		if int(mod.get("level", 0)) <= 0:
			errors.append("вознесение '%s': level <= 0" % mid)
		if str(mod.get("title", "")).strip_edges() == "":
			errors.append("вознесение '%s': пустой title" % mid)
		if not _has_effect(mod, "mods"):
			errors.append("вознесение '%s': пустые mods — no-op" % mid)


func _check_tier_weights(errors: Array) -> void:
	if PD.TIER_WEIGHTS.is_empty():
		errors.append("TIER_WEIGHTS пуст")
	for tier in PD.TIER_WEIGHTS:
		if float(PD.TIER_WEIGHTS[tier]) <= 0.0:
			errors.append("TIER_WEIGHTS[%s] <= 0" % tier)
