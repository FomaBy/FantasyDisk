extends SceneTree

# FAN-1887: exhaustive-гейт canonical player-facing контракта атрибутов.
# 1) 17 классов × каждая level-up награда: любая карта, которую класс может
#    получить (non-optional), меняет минимум одно фактическое значение
#    (attribute_presentation delta) или capability-потребителя призыва.
# 2) 1000 сидированных 3-карточных показов на класс через production-путь
#    (eligible_level_up_rewards + weighted_level_up_selection): ноль optional
#    и ноль no-op карт.
# 3) Контракт представления (спека fan1883_attribute_clarity): фактический
#    канал урона, current/cap у шанса крита, отдельный proc-chance вампиризма.
# 4) Legacy-сейвы: удалённые/недоступные карты сбрасывают показ; старые
#    run_modifiers-ключи остаются рабочим внутренним compatibility-входом.
#
# Запуск: Godot --headless --path . --script res://tests/attribute_consumability_fan1887_test.gd

const ProgressionData := preload("res://scripts/progression_data.gd")

const OFFER_SIZE := 3
const SEEDED_OFFERS_PER_CLASS := 1000

var _failed := false


func _fail(message: String) -> void:
	push_error("[fan1887-consumability] FAIL: %s" % message)
	_failed = true


func _class_context(character_id: String) -> Dictionary:
	var stats: Dictionary = ProgressionData.base_stats(character_id)
	var weapon_ids: Array = ProgressionData.weapon_ids(character_id)
	var weapon_config: Dictionary = {}
	if not weapon_ids.is_empty():
		weapon_config = ProgressionData.weapon(character_id, str(weapon_ids[0]))
	return {"stats": stats, "mods": {}, "weapon": weapon_config}


func _initialize() -> void:
	var classes: Array = ProgressionData.character_ids()
	if classes.size() != 17:
		_fail("Ожидалось 17 классов, получено %d." % classes.size())

	# 1) Exhaustive: класс × каждая награда реестра.
	for character_id_value in classes:
		var character_id := str(character_id_value)
		var context := _class_context(character_id)
		for reward in ProgressionData.LEVEL_UP_REWARDS:
			var attr := str(reward.get("attr", ""))
			var relevance := ProgressionData.attribute_relevance(attr, character_id)
			var presentation: Dictionary = AttributeContract.attribute_presentation(
				reward, character_id, context["stats"], context["mods"], context["weapon"])
			var availability := str(presentation.get("availability", ""))
			if relevance == "optional":
				if availability == "eligible":
					_fail("%s/%s: optional-ось прошла как eligible." % [character_id, attr])
				continue
			# Non-optional карта на свежем билде обязана давать ненулевую
			# фактическую дельту (капы на старте не достигнуты).
			if availability != "eligible":
				_fail("%s/%s: ожидалась eligible, получено '%s'." % [character_id, attr, availability])
				continue
			if absf(float(presentation.get("delta_effective", 0.0))) <= 0.0:
				_fail("%s/%s: нулевая фактическая дельта у выдаваемой карты." % [character_id, attr])
			if attr == "summon_amount" and not ProgressionData.class_summon_capable(character_id):
				_fail("%s: summon-карта без capability-потребителя." % character_id)

	# 2) 1000 сидированных показов на класс — production-путь фильтра+выборки.
	for character_id_value in classes:
		var character_id := str(character_id_value)
		var context := _class_context(character_id)
		var regular_pool: Array = AttributeContract.eligible_level_up_rewards(
			character_id, context["stats"], context["mods"], context["weapon"])
		if regular_pool.size() < OFFER_SIZE:
			_fail("%s: eligible-пул %d < %d." % [character_id, regular_pool.size(), OFFER_SIZE])
			continue
		var stat_pool: Array = ProgressionData.main_stat_level_up_rewards(character_id)
		var no_op_ids := {}
		for seed_index in range(SEEDED_OFFERS_PER_CLASS):
			var rng := RandomNumberGenerator.new()
			rng.seed = 990000 + seed_index
			var offer: Array = AttributeContract.weighted_level_up_selection(
				regular_pool, stat_pool, OFFER_SIZE, character_id, rng)
			if offer.size() != OFFER_SIZE:
				_fail("%s seed %d: показ %d карт != %d." % [character_id, seed_index, offer.size(), OFFER_SIZE])
				break
			var ids := {}
			var broke := false
			for reward in offer:
				var rid := str(reward.get("id", ""))
				if ids.has(rid):
					_fail("%s seed %d: дубль '%s'." % [character_id, seed_index, rid])
					broke = true
				ids[rid] = true
				if ProgressionData.reward_is_optional(reward, character_id):
					_fail("%s seed %d: optional-карта '%s'." % [character_id, seed_index, rid])
					broke = true
				# Карты атрибутов пришли из eligible-пула (delta уже доказана в №1);
				# no-op возможен только у неизвестных id — фиксируем их.
				if str(reward.get("attr", "")) == "" and not str(rid).begins_with("levelup_stat_"):
					no_op_ids[rid] = true
			if broke:
				break
		if not no_op_ids.is_empty():
			_fail("%s: неатрибутные карты вне контракта: %s." % [character_id, str(no_op_ids.keys())])

	# 3) Контракт представления по спеке.
	var berserk_context := _class_context("berserk")
	var damage_flat_reward := {}
	var crit_reward := {}
	var vamp_reward := {}
	for reward in ProgressionData.LEVEL_UP_REWARDS:
		match str(reward.get("attr", "")):
			"damage_flat":
				damage_flat_reward = reward
			"crit_chance":
				crit_reward = reward
			"vampiric":
				vamp_reward = reward
	var berserk_flat: Dictionary = AttributeContract.attribute_presentation(
		damage_flat_reward, "berserk", berserk_context["stats"], berserk_context["mods"], berserk_context["weapon"])
	if str(berserk_flat.get("channel_label", "")) != "Физический урон":
		_fail("berserk damage_flat: канал '%s' != 'Физический урон'." % berserk_flat.get("channel_label", ""))
	var dark_context := _class_context("dark_mage")
	var dark_flat: Dictionary = AttributeContract.attribute_presentation(
		damage_flat_reward, "dark_mage", dark_context["stats"], dark_context["mods"], dark_context["weapon"])
	if str(dark_flat.get("channel_label", "")) != "Магический урон":
		_fail("dark_mage damage_flat: канал '%s' != 'Магический урон'." % dark_flat.get("channel_label", ""))
	var sniper_context := _class_context("sniper")
	var sniper_crit: Dictionary = AttributeContract.attribute_presentation(
		crit_reward, "sniper", sniper_context["stats"], sniper_context["mods"], sniper_context["weapon"])
	if not sniper_crit.has("cap") or not sniper_crit.has("current"):
		_fail("crit_chance presentation без current/cap.")
	elif absf(float(sniper_crit.get("cap", 0.0)) - 0.55) > 0.0001:
		_fail("sniper crit cap %.3f != 0.55." % float(sniper_crit.get("cap", 0.0)))
	var assassin_context := _class_context("assassin")
	var assassin_crit: Dictionary = AttributeContract.attribute_presentation(
		crit_reward, "assassin", assassin_context["stats"], assassin_context["mods"], assassin_context["weapon"])
	if absf(float(assassin_crit.get("cap", 0.0)) - 1.0) > 0.0001:
		_fail("assassin crit cap %.3f != 1.0 (Хладнокровие)." % float(assassin_crit.get("cap", 0.0)))
	var berserk_vamp: Dictionary = AttributeContract.attribute_presentation(
		vamp_reward, "berserk", berserk_context["stats"], berserk_context["mods"], berserk_context["weapon"])
	if not berserk_vamp.has("proc_chance_current") or absf(float(berserk_vamp.get("proc_chance_cap", 0.0)) - ProgressionData.VAMPIRIC_CHANCE_CAP) > 0.0001:
		_fail("vampiric presentation без отдельного proc-chance current/cap=20%.")
	# Cap-reached фильтр: крит на капе не предлагается.
	var capped_mods := {"crit_chance_flat": 5.0}
	var capped_crit: Dictionary = AttributeContract.attribute_presentation(
		crit_reward, "sniper", sniper_context["stats"], capped_mods, sniper_context["weapon"])
	if str(capped_crit.get("availability", "")) != "cap_reached":
		_fail("Крит на капе: availability '%s' != 'cap_reached'." % capped_crit.get("availability", ""))
	var capped_pool: Array = AttributeContract.eligible_level_up_rewards(
		"sniper", sniper_context["stats"], capped_mods, sniper_context["weapon"])
	for reward in capped_pool:
		if str(reward.get("attr", "")) == "crit_chance":
			_fail("Крит-карта на капе осталась в eligible-пуле.")

	# 4) Legacy-сейвы.
	var legacy_offer := [
		{"id": "magic_focus_up", "attr": "magic_focus", "title": "+Маг. урон", "mods": {"magic_damage_multiplier": 1.14}},
		{"id": "damage_up", "attr": "damage", "title": "+Урон", "mods": {"damage_multiplier": 1.15}},
	]
	if not AttributeContract.sanitize_level_up_offer(legacy_offer, "dark_mage").is_empty():
		_fail("Показ с удалённой картой magic_focus_up не сброшен.")
	var stale_current := [
		{"id": "damage_up", "attr": "damage", "title": "+Урон", "description": "старое", "mods": {"damage_multiplier": 1.15}},
	]
	var refreshed: Array = AttributeContract.sanitize_level_up_offer(stale_current, "berserk")
	if refreshed.size() != 1 or str((refreshed[0] as Dictionary).get("title", "")) != "Увеличение урона":
		_fail("Валидная карта старого сейва не освежена до актуального определения.")
	var leadership_offer := [{"id": "levelup_stat_leadership", "title": "Лидерство +1", "kind": "stat", "stats": {"leadership": 1.0}, "rare": true}]
	if not AttributeContract.sanitize_level_up_offer(leadership_offer, "berserk").is_empty():
		_fail("Лидерство-карта из старого сейва не сброшена для класса без capability.")
	if AttributeContract.sanitize_level_up_offer(leadership_offer, "druid").size() != 1:
		_fail("Лидерство-карта незаслуженно сброшена для druid.")
	# Старые run_modifiers-ключи — рабочий внутренний compatibility-вход.
	var legacy_mods := {"magic_damage_multiplier": 1.5, "range_multiplier": 1.2, "buff_power_flat": 0.2, "absorb_flat": 3.0}
	var legacy_params: Dictionary = ProgressionData.derived_parameters(dark_context["stats"], legacy_mods, dark_context["weapon"])
	var clean_params: Dictionary = ProgressionData.derived_parameters(dark_context["stats"], {}, dark_context["weapon"])
	if float(legacy_params.get("magic_damage", 0.0)) <= float(clean_params.get("magic_damage", 0.0)):
		_fail("Legacy magic_damage_multiplier перестал применяться (compatibility-вход сломан).")
	if float(legacy_params.get("absorb", 0.0)) <= float(clean_params.get("absorb", 0.0)):
		_fail("Legacy absorb_flat перестал применяться (compatibility-вход сломан).")

	if _failed:
		push_error("FAN-1887 consumability gate FAILED.")
		quit(1)
		return
	print("FAN-1887 consumability gate passed: 17 классов × %d наград exhaustive, %d×17 сидированных показов без optional/no-op, legacy-сейвы совместимы." % [ProgressionData.LEVEL_UP_REWARDS.size(), SEEDED_OFFERS_PER_CLASS])
	quit(0)
