extends SceneTree

# SCRUM-960: универсальный артефакт-пул с роллом редкости (семьи rarity_scaling).
# Контракт: docs/design/systems/artifact_system_matrix.md §1-2.
# Гейтит:
#   а) каждая семья материализуется во ВСЕ 3 тира с валидными tier/cost/description
#      и непустыми stats|mods (кост строго по COST_BY_TIER);
#   б) значения следуют правилу §1.2 на выборочных семьях
#      (warrior_charm 2/4/7; splinter_gloves ×1.10/×1.18/×1.30; sturdy_amulet 15/25/40);
#   в) elite_artifact_choices(0, 3, "berserk") — 3 УНИКАЛЬНЫХ id;
#   г) boss_completion_*: семьи — фиксированно тир 3 (эпический, cost 95);
#   д) reward_pool: все 28 семей присутствуют материализованными (без tiers-ключа),
#      ролл на ~300 выборок даёт все три тира с убыванием частоты т1 > т2 > т3;
#   е) player.apply_reward пишет tier в player.artifacts из материализованного
#      оффера и переживает legacy-награды без tier.
#
# Запуск: Godot --headless --path . --script res://tests/artifact_family_roll_test.gd

const PD := preload("res://scripts/progression_data.gd")

# FAN-1038: 32 → 29 после удаления семей мёртвых осей battle_fan / ram_horn /
# falcon_feather (follow-up FAN-1034); FAN-1889: 29 → 28 после того, как общий
# cadence-контракт убрал отдельную dot-speed семью plague_metronome.
const EXPECTED_FAMILY_COUNT := 28
const ROLL_SAMPLES := 300

var _errors: Array = []


func _initialize() -> void:
	seed(90125)  # детерминированный прогон ролла

	var families := _collect_families()
	_check_family_count(families)
	_check_materialization_all_tiers(families)
	_check_scaling_rule_samples()
	_check_elite_unique_choices()
	_check_boss_families_tier3()
	_check_reward_pool_families_and_distribution(families)
	_check_player_tier_recording()

	if not _errors.is_empty():
		for e in _errors:
			push_error("Artifact family roll: %s" % str(e))
		push_error("Artifact family roll test: %d ошибок." % _errors.size())
		quit(1)
		return
	print("Artifact family roll test passed (%d семей, %d роллов)." % [EXPECTED_FAMILY_COUNT, ROLL_SAMPLES])
	quit(0)


func _collect_families() -> Array:
	var families := []
	for entry in PD.ARTIFACTS:
		if bool((entry as Dictionary).get("rarity_scaling", false)):
			families.append(entry)
	return families


func _check_family_count(families: Array) -> void:
	if families.size() != EXPECTED_FAMILY_COUNT:
		_errors.append("ожидалось %d семей rarity_scaling, найдено %d" % [EXPECTED_FAMILY_COUNT, families.size()])


# (а) Материализация каждой семьи во все 3 тира.
func _check_materialization_all_tiers(families: Array) -> void:
	for entry in families:
		var family: Dictionary = entry
		var fid := str(family.get("id", ""))
		for tier in [1, 2, 3]:
			var offer := PD.materialize_family_offer(family, tier)
			if int(offer.get("tier", 0)) != tier:
				_errors.append("'%s' т%d: материализованный tier %d" % [fid, tier, int(offer.get("tier", 0))])
			var expected_cost := int(PD.COST_BY_TIER.get(tier, 0))
			if int(offer.get("cost", 0)) != expected_cost:
				_errors.append("'%s' т%d: cost %d != COST_BY_TIER %d" % [fid, tier, int(offer.get("cost", 0)), expected_cost])
			if str(offer.get("description", "")).strip_edges() == "":
				_errors.append("'%s' т%d: пустой description" % [fid, tier])
			var stats: Dictionary = offer.get("stats", {}) as Dictionary
			var mods: Dictionary = offer.get("mods", {}) as Dictionary
			if stats.is_empty() and mods.is_empty():
				_errors.append("'%s' т%d: пустые stats и mods (no-op оффер)" % [fid, tier])
			if offer.has("tiers"):
				_errors.append("'%s' т%d: оффер несёт сырой tiers-словарь (не плоский)" % [fid, tier])
			if not bool(offer.get("rarity_scaling", false)):
				_errors.append("'%s' т%d: оффер потерял маркер rarity_scaling" % [fid, tier])
		# Неизвестный тир откатывается на т1-базу (без крэша).
		var fallback := PD.materialize_family_offer(family, 5)
		if int(fallback.get("tier", 0)) != 1:
			_errors.append("'%s': неизвестный тир 5 должен падать в т1, получен %d" % [fid, int(fallback.get("tier", 0))])


# (б) Единое правило скейла §1.2 на выборочных семьях.
func _check_scaling_rule_samples() -> void:
	var strength_family := PD.artifact_definition("warrior_charm")
	for pair in [[1, 2.0], [2, 4.0], [3, 7.0]]:
		var offer := PD.materialize_family_offer(strength_family, int(pair[0]))
		var value := float((offer.get("stats", {}) as Dictionary).get("strength", 0.0))
		if absf(value - float(pair[1])) > 0.0001:
			_errors.append("warrior_charm т%d: strength %s != %s (правило +2/+4/+7)" % [int(pair[0]), str(value), str(pair[1])])
	var percent_family := PD.artifact_definition("splinter_gloves")
	for pair in [[1, 1.10], [2, 1.18], [3, 1.30]]:
		var offer := PD.materialize_family_offer(percent_family, int(pair[0]))
		var value := float((offer.get("mods", {}) as Dictionary).get("damage_multiplier", 0.0))
		if absf(value - float(pair[1])) > 0.0001:
			_errors.append("splinter_gloves т%d: damage_multiplier %s != %s (правило ×1.10/×1.18/×1.30)" % [int(pair[0]), str(value), str(pair[1])])
	var flat_family := PD.artifact_definition("sturdy_amulet")
	for pair in [[1, 15.0], [2, 25.0], [3, 40.0]]:
		var offer := PD.materialize_family_offer(flat_family, int(pair[0]))
		var value := float((offer.get("mods", {}) as Dictionary).get("max_health_flat", 0.0))
		if absf(value - float(pair[1])) > 0.0001:
			_errors.append("sturdy_amulet т%d: max_health_flat %s != %s (плоский флет 15/25/40)" % [int(pair[0]), str(value), str(pair[1])])


# (в) Элитка: три уникальных выбора живы.
func _check_elite_unique_choices() -> void:
	for attempt in range(20):
		var choices: Array = PD.elite_artifact_choices(0, 3, "berserk")
		if choices.size() != 3:
			_errors.append("elite_artifact_choices попытка %d: %d вариантов вместо 3" % [attempt, choices.size()])
			return
		var seen := {}
		for choice in choices:
			var cid := str((choice as Dictionary).get("id", ""))
			if cid == "" or seen.has(cid):
				_errors.append("elite_artifact_choices попытка %d: дубль/пустой id '%s'" % [attempt, cid])
				return
			seen[cid] = true
			var tier := int((choice as Dictionary).get("tier", 0))
			if tier < 1 or tier > 3:
				_errors.append("elite_artifact_choices попытка %d: '%s' с битым tier %d" % [attempt, cid, tier])
				return


# (г) Босс: семьи в boss-пуле — только тир 3.
func _check_boss_families_tier3() -> void:
	var rewards: Array = PD.boss_completion_artifact_rewards()
	if rewards.is_empty():
		_errors.append("boss_completion_artifact_rewards пуст")
		return
	var family_count := 0
	for reward_entry in rewards:
		var reward: Dictionary = reward_entry
		var rid := str(reward.get("id", ""))
		if bool(reward.get("rarity_scaling", false)):
			family_count += 1
			if int(reward.get("tier", 0)) != 3:
				_errors.append("boss-пул: семья '%s' тиром %d вместо 3" % [rid, int(reward.get("tier", 0))])
			if int(reward.get("cost", 0)) != int(PD.COST_BY_TIER.get(3, 95)):
				_errors.append("boss-пул: семья '%s' с ценой %d вместо эпической" % [rid, int(reward.get("cost", 0))])
		elif int(reward.get("tier", 0)) < 3:
			_errors.append("boss-пул: плоский артефакт '%s' тиром %d (< 3)" % [rid, int(reward.get("tier", 0))])
	if family_count != EXPECTED_FAMILY_COUNT:
		_errors.append("boss-пул: %d семей вместо %d" % [family_count, EXPECTED_FAMILY_COUNT])
	for attempt in range(10):
		var choices: Array = PD.boss_completion_artifact_choices(3)
		for choice in choices:
			if bool((choice as Dictionary).get("rarity_scaling", false)) and int((choice as Dictionary).get("tier", 0)) != 3:
				_errors.append("boss-выбор попытка %d: семья '%s' не т3" % [attempt, str((choice as Dictionary).get("id", ""))])
				return


# (д) reward_pool: материализованные семьи присутствуют; распределение ролла.
func _check_reward_pool_families_and_distribution(families: Array) -> void:
	var pool: Array = PD.reward_pool()
	var pool_by_id := {}
	for reward_entry in pool:
		var reward: Dictionary = reward_entry
		if str(reward.get("kind", "")) == "artifact":
			pool_by_id[str(reward.get("id", ""))] = reward
	for entry in families:
		var fid := str((entry as Dictionary).get("id", ""))
		if not pool_by_id.has(fid):
			_errors.append("reward_pool: семья '%s' отсутствует" % fid)
			continue
		var offer: Dictionary = pool_by_id[fid]
		if offer.has("tiers"):
			_errors.append("reward_pool: '%s' не материализован (сырой tiers)" % fid)
		var tier := int(offer.get("tier", 0))
		if tier < 1 or tier > 3:
			_errors.append("reward_pool: '%s' битый tier %d" % [fid, tier])
		if int(offer.get("cost", 0)) != int(PD.COST_BY_TIER.get(tier, 0)):
			_errors.append("reward_pool: '%s' cost %d не соответствует тиру %d" % [fid, int(offer.get("cost", 0)), tier])
		if absf(float(offer.get("weight", 0.0)) - 1.0) > 0.0001:
			_errors.append("reward_pool: '%s' вес семьи %s != 1.0" % [fid, str(offer.get("weight"))])

	# Распределение ролла (~300 пулов, следим за warrior_charm): все три тира
	# присутствуют, частота убывает т1 > т2 > т3 (нормализованные TIER_WEIGHTS
	# ≈ 0.64/0.29/0.08 — при 300 выборках зазор статистически железный).
	var counts := {1: 0, 2: 0, 3: 0}
	for _sample in range(ROLL_SAMPLES):
		for reward_entry in PD.reward_pool():
			var reward: Dictionary = reward_entry
			if str(reward.get("id", "")) == "warrior_charm":
				var tier := int(reward.get("tier", 0))
				if counts.has(tier):
					counts[tier] = int(counts[tier]) + 1
				break
	if int(counts[1]) == 0 or int(counts[2]) == 0 or int(counts[3]) == 0:
		_errors.append("ролл %d выборок не дал все три тира: %s" % [ROLL_SAMPLES, str(counts)])
	if not (int(counts[1]) > int(counts[2]) and int(counts[2]) > int(counts[3])):
		_errors.append("частота роллов не убывает т1>т2>т3: %s" % str(counts))


# (е) player.artifacts: tier пишется из материализованного оффера; legacy без tier живёт.
func _check_player_tier_recording() -> void:
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	if player_scene == null:
		_errors.append("Player.tscn не загрузилась")
		return
	var player := player_scene.instantiate()
	root.add_child(player)
	player.call("configure_character", "berserk")
	player.call("equip_weapon", "sword")
	var offer := PD.materialize_family_offer(PD.artifact_definition("warrior_charm"), 2)
	offer["kind"] = "artifact"
	player.call("apply_reward", offer)
	# Legacy-награда без tier (старый сейв/оффер) — запись без ключа tier.
	player.call("apply_reward", {"kind": "artifact", "id": "legacy_relic", "title": "Legacy Relic", "mods": {"damage_multiplier": 1.05}})
	var artifacts: Array = player.get("artifacts")
	if artifacts.size() != 2:
		_errors.append("player.artifacts: %d записей вместо 2" % artifacts.size())
	else:
		var family_entry: Dictionary = artifacts[0]
		if int(family_entry.get("tier", 0)) != 2:
			_errors.append("player.artifacts: tier оффера не записан (%s)" % str(family_entry))
		if str(family_entry.get("id", "")) != "warrior_charm" or str(family_entry.get("title", "")) == "":
			_errors.append("player.artifacts: id/title записи семьи битые (%s)" % str(family_entry))
		var legacy_entry: Dictionary = artifacts[1]
		if legacy_entry.has("tier"):
			_errors.append("player.artifacts: legacy-награда без tier получила tier (%s)" % str(legacy_entry))
	player.free()
