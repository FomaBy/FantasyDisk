extends SceneTree

# Integrity-тест контент-наград (progression_data_content.gd) — был непокрыт.
# STAT_REWARDS / ARTIFACTS / LEVEL_UP_REWARDS — это экономика и билд-контент
# (магазин, награды элиток, level-up). Битый артефакт (дубль id, нулевая цена,
# несогласованный tier→cost, affinity_mods без класса, неизвестный стат) тихо
# ломает магазин/награду. Самодостаточные инварианты + stats->базовые статы.
# Кросс-ссылку affinity->классы намеренно НЕ берём (тянет занятый файл классов).
# Изолированный файл.
#
# Запуск: Godot --headless --path . --script res://tests/content_rewards_integrity_test.gd

const Content := preload("res://scripts/progression_data_content.gd")
const StatFormulas := preload("res://scripts/stat_formulas.gd")

const VALID_TIERS := [1, 2, 3]


func _initialize() -> void:
	var errors: Array = []
	var valid_stats := {}
	for stat_id in StatFormulas.BASE_STAT_ORDER:
		valid_stats[str(stat_id)] = true

	_check_stat_rewards(errors, valid_stats)
	_check_artifacts(errors, valid_stats)
	_check_level_up_rewards(errors)

	if not errors.is_empty():
		for e in errors:
			push_error("Content rewards integrity: %s" % e)
		push_error("Content rewards integrity test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Content rewards integrity test passed (%d статов, %d артефактов, %d level-up)." % [
		Content.STAT_REWARDS.size(),
		Content.ARTIFACTS.size(),
		Content.LEVEL_UP_REWARDS.size(),
	])
	quit(0)


func _text_ok(text: String) -> bool:
	var t := text.strip_edges()
	return t != "" and not t.to_lower().begins_with("res://")


# Все значения словаря модификаторов — числа (опечатка-строка сломала бы расчёт).
func _check_numeric_values(errors: Array, dict: Dictionary, where: String) -> void:
	for key in dict:
		var v = dict[key]
		if not (v is int or v is float):
			errors.append("%s: значение '%s' не число" % [where, str(key)])


func _check_stat_rewards(errors: Array, valid_stats: Dictionary) -> void:
	var rewards: Array = Content.STAT_REWARDS
	var seen := {}
	var covered := {}
	for entry in rewards:
		var r: Dictionary = entry
		var rid := str(r.get("id", ""))
		if rid == "" or seen.has(rid):
			errors.append("stat-reward с пустым/дублирующимся id '%s'" % rid)
			continue
		seen[rid] = true
		if not _text_ok(str(r.get("title", ""))):
			errors.append("stat-reward '%s': пустой title" % rid)
		if not _text_ok(str(r.get("description", ""))):
			errors.append("stat-reward '%s': пустой description" % rid)
		var stats: Dictionary = r.get("stats", {})
		if stats.is_empty():
			errors.append("stat-reward '%s': пустой stats" % rid)
		for key in stats:
			if not valid_stats.has(str(key)):
				errors.append("stat-reward '%s': неизвестный стат '%s'" % [rid, str(key)])
			else:
				covered[str(key)] = true
		_check_numeric_values(errors, stats, "stat-reward '%s'" % rid)
	# Каждый базовый стат должен иметь свою награду «+1» (иначе пробел в докачке).
	for stat_id in valid_stats:
		if not covered.has(stat_id):
			errors.append("базовый стат '%s' без stat-reward" % stat_id)


func _check_artifacts(errors: Array, valid_stats: Dictionary) -> void:
	var artifacts: Array = Content.ARTIFACTS
	if artifacts.size() < 10:
		errors.append("ARTIFACTS подозрительно мал (%d)" % artifacts.size())
	var seen := {}
	var tier_cost := {}  # tier -> ожидаемая цена (согласованность прайсинга)
	for entry in artifacts:
		var a: Dictionary = entry
		var aid := str(a.get("id", ""))
		if aid == "" or seen.has(aid):
			errors.append("артефакт с пустым/дублирующимся id '%s'" % aid)
			continue
		seen[aid] = true
		if not _text_ok(str(a.get("title", ""))):
			errors.append("артефакт '%s': пустой title" % aid)
		if not _text_ok(str(a.get("description", ""))):
			errors.append("артефакт '%s': пустой description" % aid)
		var tier := int(a.get("tier", 0))
		if not VALID_TIERS.has(tier):
			errors.append("артефакт '%s': tier %d вне %s" % [aid, tier, str(VALID_TIERS)])
		var cost := int(a.get("cost", 0))
		if cost <= 0:
			errors.append("артефакт '%s': cost <= 0" % aid)
		# Согласованность tier->cost: все артефакты одного тира — одна цена.
		elif VALID_TIERS.has(tier):
			if tier_cost.has(tier) and tier_cost[tier] != cost:
				errors.append("артефакт '%s': cost %d != цены тира %d (%d)" % [aid, cost, tier, tier_cost[tier]])
			else:
				tier_cost[tier] = cost
		# class_affinity — массив строк-идентификаторов.
		var affinity = a.get("class_affinity", [])
		if not (affinity is Array):
			errors.append("артефакт '%s': class_affinity не массив" % aid)
			affinity = []
		else:
			for cls in affinity:
				if str(cls).strip_edges() == "":
					errors.append("артефакт '%s': пустой класс в class_affinity" % aid)
		# Артефакт обязан что-то давать.
		var has_stats := a.has("stats") and not (a["stats"] as Dictionary).is_empty()
		var has_mods := a.has("mods") and not (a["mods"] as Dictionary).is_empty()
		var has_aff_mods := a.has("affinity_mods") and not (a["affinity_mods"] as Dictionary).is_empty()
		if not (has_stats or has_mods or has_aff_mods):
			errors.append("артефакт '%s': нет ни stats, ни mods, ни affinity_mods (ничего не делает)" % aid)
		# affinity_mods без класса никогда не сработает.
		if has_aff_mods and (affinity as Array).is_empty():
			errors.append("артефакт '%s': affinity_mods при пустом class_affinity (не сработает)" % aid)
		if has_stats:
			for key in a["stats"]:
				if not valid_stats.has(str(key)):
					errors.append("артефакт '%s': stats неизвестный стат '%s'" % [aid, str(key)])
			_check_numeric_values(errors, a["stats"], "артефакт '%s'.stats" % aid)
		if has_mods:
			_check_numeric_values(errors, a["mods"], "артефакт '%s'.mods" % aid)
		if has_aff_mods:
			_check_numeric_values(errors, a["affinity_mods"], "артефакт '%s'.affinity_mods" % aid)


func _check_level_up_rewards(errors: Array) -> void:
	var rewards: Array = Content.LEVEL_UP_REWARDS
	if rewards.size() < 10:
		errors.append("LEVEL_UP_REWARDS подозрительно мал (%d)" % rewards.size())
	var seen := {}
	for entry in rewards:
		var r: Dictionary = entry
		var rid := str(r.get("id", ""))
		if rid == "" or seen.has(rid):
			errors.append("level-up с пустым/дублирующимся id '%s'" % rid)
			continue
		seen[rid] = true
		if not _text_ok(str(r.get("title", ""))):
			errors.append("level-up '%s': пустой title" % rid)
		if not _text_ok(str(r.get("description", ""))):
			errors.append("level-up '%s': пустой description" % rid)
		if str(r.get("kind", "")) != "upgrade":
			errors.append("level-up '%s': kind != 'upgrade' ('%s')" % [rid, str(r.get("kind", ""))])
		var mods: Dictionary = r.get("mods", {})
		if mods.is_empty():
			errors.append("level-up '%s': пустой mods (ничего не улучшает)" % rid)
		_check_numeric_values(errors, mods, "level-up '%s'.mods" % rid)
