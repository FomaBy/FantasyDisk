extends SceneTree

# FAN-1887/FAN-1927: certifying-гейт canonical player-facing контракта атрибутов
# с НЕЗАВИСИМЫМ live-consumer oracle.
#
# 1) 51 путь (17 классов × 3 оружия, живой Player + реальная сцена оружия):
#    oracle НЕ использует AttributeContract — потребляемые значения снимаются с
#    живых узлов (weapon.damage / fire_interval / summon_interval / max_summons,
#    player.max_health / speed / pickup_radius) и derived-слоя, по тем же
#    duck-typing признакам, что и runtime (player.gd:3585-3681, read-only oracle):
#    - канал урона доказывается живым probe (magic_damage_multiplier ×2 двигает
#      weapon.damage только у магического кита);
#    - каждая eligible-карта обязана изменить ≥1 живое потребляемое значение;
#    - каждая карта, отфильтрованная weapon-правилом (no_capability), обязана
#      НЕ менять ни одно живое потребляемое значение (нет ложных отсевов);
#    - у урон-осей presentation before/after == живой weapon.damage;
#    - у «Силы призыва» presentation before/after == живой max_summons.
# 2) 17 × 1000 сидированных 3-карточных показов через production-путь
#    (eligible_level_up_rewards + weighted_level_up_selection), оружие ротируется
#    по seed: ноль optional / no-op / ineligible карт — проверка по live-набору
#    осей из №1, а не по самому контракту.
# 3) Контракт представления (спека fan1883_attribute_clarity): фактический
#    канал урона, current/cap у шанса крита, отдельный proc-chance вампиризма,
#    cap_reached-фильтр.
# 4) Сейвы: удалённые/неизвестные id сбрасывают показ и не воскресают; известная
#    карта, ставшая capped/no-op/ineligible в ТЕКУЩЕМ контексте (stats/cap/
#    weapon), сбрасывается context-aware санитайзером; валидный показ выживает;
#    старые run_modifiers-ключи остаются рабочим внутренним compatibility-входом.
#
# Запуск: Godot --headless --path . --script res://tests/attribute_consumability_fan1887_test.gd

const ProgressionData := preload("res://scripts/progression_data.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")

const OFFER_SIZE := 3
const SEEDED_OFFERS_PER_CLASS := 1000
# Зеркало player.gd:3661 (устройства Инженера сбрасывают max_summons к базе).
const ORACLE_ENGINEER_DEVICE_MODES := ["engineer_sentry_link", "engineer_orbit_drone"]
# FAN-2474: принятый контракт считает митигацию из СЫРЫХ рейтингов
# (effective_defense / effective_dodge), поэтому фикстура, изолирующая уворот или
# защиту, обязана писать legacy-ключ И парный raw_*. FAN-2476: каждая фикстура
# ниже теперь ДОПОЛНИТЕЛЬНО самостоятельно проверяет свою raw/legacy пару
# (_raw_pair_defect/_assert_raw_pair в самом файле фикстуры) — удаление
# одиночной raw-строки валит именно ЕЁ сюиту напрямую. Этот ратчет остаётся
# вторым, aggregate-слоем защиты: любое расхождение legacy/raw в списке ниже
# ВСЁ РАВНО валит certifying-гейт с точным путём фикстуры, даже если локальная
# проверка в самой фикстуре когда-нибудь будет ослаблена или удалена.
const DEFENSIVE_FIXTURES := [
	"res://tests/boss_hazard_cap_gate.gd",
	"res://tests/contact_damage_softcap_test.gd",
	"res://tests/constellation_schema6_live_runtime_test.gd",
	"res://tests/knight_kit_test.gd",
	"res://tests/melee_unique_mechanics_test.gd",
	"res://tests/meta_keystone_behavioral_smoke_test.gd",
	"res://tests/meta_skill_tree_smoke_test.gd",
	"res://tests/priest_kit_test.gd",
	"res://tests/priest_sustain_softcap_test.gd",
	"res://tests/robot_kit_test.gd",
	"res://tests/runtime_smoke_combat_test.gd",
	"res://tests/runtime_smoke_test.gd",
	"res://tests/runtime_smoke_triggered_artifacts_test.gd",
	"res://tests/thief_kit_test.gd",
	"res://tests/ultimates/guard_prevention_resource_test.gd",
	"res://tests/ultimates/mechanics/priest_live_test.gd",
]

var _failed := false
var _holder: Node2D
# (cid, wid) -> { attr -> true } — live-доказанный набор осей с реальным
# потребителем и ненулевой живой дельтой (oracle для №2).
var _live_eligible_axes := {}


func _fail(message: String) -> void:
	push_error("[fan1887-consumability] FAIL: %s" % message)
	_failed = true


func _reward_for_attr(attr_id: String) -> Dictionary:
	for reward in ProgressionData.LEVEL_UP_REWARDS:
		if str(reward.get("attr", "")) == attr_id:
			return reward
	return {}


func _weapon_node_of(player: Node) -> Node:
	for child in player.get_children():
		if child.is_in_group("player_weapons"):
			return child
	for child in player.find_children("*", "Node2D", true, false):
		if child.is_in_group("player_weapons"):
			return child
	return null


# Живой снимок потребляемых значений — только то, что runtime реально читает
# для ДАННОГО оружия. Признаки потребителя — те же, что в player.gd/оружейных
# скриптах: наличие свойства узла, curse_only, summon_pair_mode, engineer-mode.
func _live_observables(player: Node, weapon_node: Node, config: Dictionary) -> Dictionary:
	var derived: Dictionary = ProgressionData.derived_parameters(
		player.get("stats"), player.get("run_modifiers"), config)
	var out := {}
	var curse_only := bool(config.get("curse_only", false))
	var is_summoner := weapon_node != null and weapon_node.get("summon_interval") != null
	if curse_only:
		# Проклятый череп: единственный канал урона — dot-пайплайн
		# (class_weapon.gd:1453 читает parameters.dot_damage).
		out["damage_channel"] = float(derived.get("dot_damage", 0.0))
	elif weapon_node != null and weapon_node.get("damage") != null:
		# player.gd:3585-3591: weapon.damage = derived[фактический канал].
		out["damage_channel"] = float(weapon_node.get("damage"))
	if weapon_node != null:
		if is_summoner:
			# SummonerWeapon живёт от summon_interval; generic attack_speed
			# каденс НЕ читает (player.gd:3599-3604).
			out["cadence"] = float(weapon_node.get("summon_interval"))
		elif weapon_node.get("fire_interval") != null:
			out["cadence"] = float(weapon_node.get("fire_interval"))
		# Парк читают только киты, ОБЪЯВИВШИЕ max_summons в конфиге (узел
		# ClassWeapon экспортирует свойство всегда, но amp-лимит читает его
		# только при config-значении — class_weapon.gd:2361/4425); пара и
		# устройства Инженера исключены (summoner_weapon.gd:170, player.gd:3661).
		var device_mode := str(config.get("attack_mode", "")) in ORACLE_ENGINEER_DEVICE_MODES
		if config.get("max_summons") != null and weapon_node.get("max_summons") != null and not bool(config.get("summon_pair_mode", false)) and not device_mode:
			out["summon_count"] = float(weapon_node.get("max_summons"))
	out["max_health"] = float(player.get("max_health"))
	out["move_speed"] = float(player.get("speed"))
	out["pickup_radius"] = float(player.get("pickup_radius"))
	out["aoe_radius"] = float(derived.get("aoe_radius", 0.0))
	out["defense"] = float(derived.get("defense", 0.0))
	out["dodge"] = float(derived.get("dodge", 0.0))
	out["dot_damage"] = float(derived.get("dot_damage", 0.0))
	out["regeneration"] = float(derived.get("regeneration", 0.0))
	out["ultimate_multiplier"] = float(derived.get("ultimate_multiplier", 0.0))
	if not curse_only:
		# Вампиризм требует реального on_weapon_hit; curse-кит его не даёт
		# (player.gd:3287-3292).
		out["vampiric_amount"] = float(derived.get("vampiric_amount", 0.0))
	if not curse_only and not is_summoner:
		# Крит существует только в _rolled_damage-пути (class_weapon.gd:5621).
		out["crit_chance"] = float(derived.get("crit_chance", 0.0))
		out["crit_damage_multiplier"] = float(derived.get("crit_damage_multiplier", 0.0))
	return out


# Ось -> ключи живого снимка, которые её потребляют у ДАННОГО оружия.
# Пустой список = у текущего оружия нет живого потребителя оси.
func _axis_observable_keys(attr_id: String, config: Dictionary, weapon_node: Node) -> Array:
	var curse_only := bool(config.get("curse_only", false))
	var is_summoner := weapon_node != null and weapon_node.get("summon_interval") != null
	match attr_id:
		"damage_flat":
			return [] if curse_only else ["damage_channel"]
		"damage":
			return ["damage_channel", "dot_damage"]
		"attack_speed":
			return [] if is_summoner else ["cadence"]
		"max_health":
			return ["max_health"]
		"move_speed":
			return ["move_speed"]
		"aoe_radius":
			return ["aoe_radius"]
		"pickup_radius":
			return ["pickup_radius"]
		"defense":
			return ["defense"]
		"crit_chance":
			return [] if curse_only or is_summoner else ["crit_chance"]
		"crit_damage":
			return [] if curse_only or is_summoner else ["crit_damage_multiplier"]
		"dodge":
			return ["dodge"]
		"dot_damage":
			return ["dot_damage"]
		"summon_amount":
			return ["summon_count"] if config.get("max_summons") != null and not bool(config.get("summon_pair_mode", false)) and not (str(config.get("attack_mode", "")) in ORACLE_ENGINEER_DEVICE_MODES) else []
		"regeneration":
			return ["regeneration"]
		"vampiric":
			return [] if curse_only else ["vampiric_amount"]
		"ultimate_power":
			return ["ultimate_multiplier"]
	return []


func _observable_delta(before: Dictionary, after: Dictionary, keys: Array) -> float:
	var best := 0.0
	for key in keys:
		if not before.has(key) or not after.has(key):
			continue
		best = maxf(best, absf(float(after.get(key, 0.0)) - float(before.get(key, 0.0))))
	return best


# Полный live-rescale: player-уровень + КАЖДЫЙ узел оружия (у Player эти пути
# раздельны — apply_reward зовёт оба, player.gd:1874).
func _rescale_player(player: Node) -> void:
	player._apply_stat_scaling()
	for weapon in player._equipped_weapons():
		player._apply_weapon_scaling(weapon)


# Живой probe канала: magic_damage_multiplier ×2 двигает weapon.damage только у
# магического кита. Возвращает "magic_damage" / "damage" / "" (нет канала).
func _live_damage_channel(player: Node, weapon_node: Node, config: Dictionary) -> String:
	if weapon_node == null or weapon_node.get("damage") == null or bool(config.get("curse_only", false)):
		return ""
	var baseline_mods: Dictionary = (player.get("run_modifiers") as Dictionary).duplicate(true)
	var before := float(weapon_node.get("damage"))
	var probe_mods := baseline_mods.duplicate(true)
	probe_mods["magic_damage_multiplier"] = float(probe_mods.get("magic_damage_multiplier", 1.0)) * 2.0
	player.set("run_modifiers", probe_mods)
	_rescale_player(player)
	var after := float(weapon_node.get("damage"))
	player.set("run_modifiers", baseline_mods)
	_rescale_player(player)
	return "magic_damage" if absf(after - before) > 0.001 else "damage"


func _check_live_path(character_id: String, weapon_id: String) -> void:
	var config: Dictionary = ProgressionData.weapon(character_id, weapon_id)
	if str(config.get("id", "")) != weapon_id:
		_fail("%s/%s: реестр вернул другое оружие '%s'." % [character_id, weapon_id, config.get("id", "")])
		return
	var player := PLAYER_SCENE.instantiate() as Node2D
	_holder.add_child(player)
	player.add_to_group("player")
	player.global_position = Vector2(1280, 720)
	player.configure_character(character_id, weapon_id)
	var weapon_node := _weapon_node_of(player)
	if weapon_node == null:
		_fail("%s/%s: живой узел оружия не найден." % [character_id, weapon_id])
		player.queue_free()
		return

	var stats: Dictionary = (player.get("stats") as Dictionary).duplicate(true)
	var baseline_mods: Dictionary = (player.get("run_modifiers") as Dictionary).duplicate(true)
	var live_channel := _live_damage_channel(player, weapon_node, config)
	var live_axes := {}

	for reward in ProgressionData.LEVEL_UP_REWARDS:
		var attr := str(reward.get("attr", ""))
		if attr == "":
			continue
		var relevance := ProgressionData.attribute_relevance(attr, character_id)
		var presentation: Dictionary = AttributeContract.attribute_presentation(
			reward, character_id, stats, baseline_mods, config)
		var availability := str(presentation.get("availability", ""))
		var keys := _axis_observable_keys(attr, config, weapon_node)

		# Живой замер: применяем награду настоящим потребительским путём
		# (Player.apply_reward), снимаем дельту, откатываем.
		var before := _live_observables(player, weapon_node, config)
		player.apply_reward(reward.duplicate(true))
		var after := _live_observables(player, weapon_node, config)
		player.set("stats", stats.duplicate(true))
		player.set("run_modifiers", baseline_mods.duplicate(true))
		_rescale_player(player)
		var live_delta := _observable_delta(before, after, keys)
		var live_changed := not keys.is_empty() and live_delta > 0.001

		if live_changed:
			live_axes[attr] = true

		if relevance == "optional":
			if availability == "eligible":
				_fail("%s/%s/%s: optional-ось прошла как eligible." % [character_id, weapon_id, attr])
			continue
		if availability == "eligible":
			if not live_changed:
				_fail("%s/%s/%s: eligible-карта не изменила НИ ОДНО живое потребляемое значение (false positive)." % [character_id, weapon_id, attr])
			if absf(float(presentation.get("delta_effective", 0.0))) <= 0.0:
				_fail("%s/%s/%s: нулевая заявленная дельта у выдаваемой карты." % [character_id, weapon_id, attr])
		elif availability in ["no_capability", "zero_effective_delta", "cap_reached"]:
			# zero_effective_delta покрывает и каденс-пол 0.18с (например
			# assassin/shadow_daggers): live-oracle обязан подтвердить ноль.
			if live_changed:
				_fail("%s/%s/%s: карта отфильтрована как %s, но живое значение изменилось на %.4f (false negative)." % [character_id, weapon_id, attr, availability, live_delta])
		else:
			_fail("%s/%s/%s: неожиданная availability '%s' на свежем билде." % [character_id, weapon_id, attr, availability])

		# Правдивость канала и значений у урон-осей.
		if availability == "eligible" and attr == "damage_flat" and live_channel != "":
			var claimed := "magic_damage" if str(presentation.get("channel_label", "")) == "Магический урон" else "damage"
			if claimed != live_channel:
				_fail("%s/%s: канал карточки '%s' != живому каналу '%s' (probe magic_damage_multiplier)." % [character_id, weapon_id, presentation.get("channel_label", ""), live_channel])
			if absf(float(presentation.get("before", 0.0)) - float(before.get("damage_channel", 0.0))) > 0.01:
				_fail("%s/%s: presentation.before %.2f != живому weapon.damage %.2f." % [character_id, weapon_id, presentation.get("before", 0.0), before.get("damage_channel", 0.0)])
			if absf(float(presentation.get("after", 0.0)) - float(after.get("damage_channel", 0.0))) > 0.01:
				_fail("%s/%s: presentation.after %.2f != живому weapon.damage %.2f." % [character_id, weapon_id, presentation.get("after", 0.0), after.get("damage_channel", 0.0)])
		# Правдивость фактического парка у «Силы призыва».
		if availability == "eligible" and attr == "summon_amount":
			if absf(float(presentation.get("before", 0.0)) - float(before.get("summon_count", -1.0))) > 0.01:
				_fail("%s/%s: summon before %.0f != живому max_summons %.0f." % [character_id, weapon_id, presentation.get("before", 0.0), before.get("summon_count", -1.0)])
			if absf(float(presentation.get("after", 0.0)) - float(after.get("summon_count", -1.0))) > 0.01:
				_fail("%s/%s: summon after %.0f != живому max_summons %.0f (ложный «+2»)." % [character_id, weapon_id, presentation.get("after", 0.0), after.get("summon_count", -1.0)])

	_live_eligible_axes["%s/%s" % [character_id, weapon_id]] = live_axes
	player.queue_free()


# Считает ЗАПИСИ ключа в фикстуре: `dp["dodge"] = ...` и `{"dodge": ...}`.
# `raw_dodge`/`raw_defense` под эти шаблоны не попадают (перед именем не кавычка).
func _fixture_key_writes(source: String, key: String) -> int:
	return source.count("[\"%s\"] =" % key) + source.count("\"%s\":" % key)


func _verify_defensive_fixture_raw_writes() -> void:
	for fixture_path in DEFENSIVE_FIXTURES:
		var source := FileAccess.get_file_as_string(str(fixture_path))
		if source.is_empty():
			_fail("%s: фикстура не прочиталась, raw-контракт не проверен." % fixture_path)
			continue
		for attribute in ["dodge", "defense"]:
			var legacy_writes := _fixture_key_writes(source, attribute)
			var raw_writes := _fixture_key_writes(source, "raw_%s" % attribute)
			if legacy_writes != raw_writes:
				_fail("%s: %d записей '%s' против %d парных 'raw_%s' — фикстура снова изолирует митигацию только legacy-ключом." % [fixture_path, legacy_writes, attribute, raw_writes, attribute])


func _initialize() -> void:
	await process_frame
	_verify_defensive_fixture_raw_writes()
	_holder = Node2D.new()
	_holder.name = "Fan1927ConsumabilityHolder"
	root.add_child(_holder)
	current_scene = _holder
	await process_frame

	var classes: Array = ProgressionData.character_ids()
	if classes.size() != 17:
		_fail("Ожидалось 17 классов, получено %d." % classes.size())

	# 1) 51 живой путь класс × оружие.
	var path_count := 0
	for character_id_value in classes:
		var character_id := str(character_id_value)
		for weapon_id_value in ProgressionData.weapon_ids(character_id):
			_check_live_path(character_id, str(weapon_id_value))
			path_count += 1
			await process_frame
	if path_count != 51:
		_fail("Покрыт %d путь(ей) класс×оружие вместо 51." % path_count)

	# Прицельные негативы четырёх ложноположительных семейств FAN-1888.
	for expectation in [
		["doctor", "bone_saw", "damage_flat", true],
		["chemist", "blast_powder", "damage_flat", true],
		["druid", "briar_staff", "damage_flat", true],
		["dark_mage", "cursed_skull", "damage_flat", false],
		["dark_mage", "cursed_skull", "crit_chance", false],
		["druid", "summon_amulet", "attack_speed", false],
		["chemist", "homunculus_vial", "attack_speed", false],
		["chemist", "homunculus_vial", "summon_amount", false],
		["engineer", "engineer_sentry_wrench", "summon_amount", false],
		["engineer", "engineer_repair_drone", "summon_amount", false],
		["engineer", "engineer_pressure_mines", "summon_amount", false],
		["guitarist", "sound_amp", "summon_amount", true],
		["druid", "summon_amulet", "summon_amount", true],
		["druid", "raven_totem", "summon_amount", true],
	]:
		var cid := str(expectation[0])
		var wid := str(expectation[1])
		var attr := str(expectation[2])
		var expect_live := bool(expectation[3])
		var live_axes: Dictionary = _live_eligible_axes.get("%s/%s" % [cid, wid], {})
		if bool(live_axes.get(attr, false)) != expect_live:
			_fail("%s/%s/%s: live-oracle=%s, ожидалось %s." % [cid, wid, attr, live_axes.get(attr, false), expect_live])

	# 2) 17 × 1000 сидированных показов, оружие ротируется по seed; каждая карта
	# сверяется с live-набором осей №1 (независимый oracle), не с контрактом.
	for character_id_value in classes:
		var character_id := str(character_id_value)
		var weapon_ids: Array = ProgressionData.weapon_ids(character_id)
		var stats: Dictionary = ProgressionData.base_stats(character_id)
		var stat_pool: Array = ProgressionData.main_stat_level_up_rewards(character_id)
		for seed_index in range(SEEDED_OFFERS_PER_CLASS):
			var weapon_id := str(weapon_ids[seed_index % weapon_ids.size()])
			var weapon_config: Dictionary = ProgressionData.weapon(character_id, weapon_id)
			var live_axes: Dictionary = _live_eligible_axes.get("%s/%s" % [character_id, weapon_id], {})
			var regular_pool: Array = AttributeContract.eligible_level_up_rewards(
				character_id, stats, {}, weapon_config)
			if regular_pool.size() < OFFER_SIZE:
				_fail("%s/%s: eligible-пул %d < %d." % [character_id, weapon_id, regular_pool.size(), OFFER_SIZE])
				break
			var rng := RandomNumberGenerator.new()
			rng.seed = 990000 + seed_index
			var offer: Array = AttributeContract.weighted_level_up_selection(
				regular_pool, stat_pool, OFFER_SIZE, character_id, rng)
			if offer.size() != OFFER_SIZE:
				_fail("%s/%s seed %d: показ %d карт != %d." % [character_id, weapon_id, seed_index, offer.size(), OFFER_SIZE])
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
				var attr := str(reward.get("attr", ""))
				if attr != "":
					if not bool(live_axes.get(attr, false)):
						_fail("%s/%s seed %d: карта '%s' без живого потребителя у текущего оружия (no-op/ineligible в показе)." % [character_id, weapon_id, seed_index, rid])
						broke = true
				elif not rid.begins_with("levelup_stat_"):
					_fail("%s seed %d: неатрибутная карта вне контракта '%s'." % [character_id, seed_index, rid])
					broke = true
			if broke:
				break

	# 3) Контракт представления по спеке (фиксированные литералы-oracle).
	var berserk_stats: Dictionary = ProgressionData.base_stats("berserk")
	var berserk_weapon: Dictionary = ProgressionData.weapon("berserk", "sword")
	var damage_flat_reward := _reward_for_attr("damage_flat")
	var crit_reward := _reward_for_attr("crit_chance")
	var vamp_reward := _reward_for_attr("vampiric")
	var berserk_flat: Dictionary = AttributeContract.attribute_presentation(
		damage_flat_reward, "berserk", berserk_stats, {}, berserk_weapon)
	if str(berserk_flat.get("channel_label", "")) != "Физический урон":
		_fail("berserk damage_flat: канал '%s' != 'Физический урон'." % berserk_flat.get("channel_label", ""))
	var dark_stats: Dictionary = ProgressionData.base_stats("dark_mage")
	var dark_book: Dictionary = ProgressionData.weapon("dark_mage", "dark_book")
	var dark_flat: Dictionary = AttributeContract.attribute_presentation(
		damage_flat_reward, "dark_mage", dark_stats, {}, dark_book)
	if str(dark_flat.get("channel_label", "")) != "Магический урон":
		_fail("dark_mage/dark_book damage_flat: канал '%s' != 'Магический урон'." % dark_flat.get("channel_label", ""))
	var sniper_stats: Dictionary = ProgressionData.base_stats("sniper")
	sniper_stats["agility"] = 50.0
	var sniper_weapon: Dictionary = ProgressionData.weapon("sniper", "sniper_deadeye_rifle")
	var sniper_crit: Dictionary = AttributeContract.attribute_presentation(
		crit_reward, "sniper", sniper_stats, {}, sniper_weapon)
	if not sniper_crit.has("cap") or not sniper_crit.has("current"):
		_fail("crit_chance presentation без current/cap.")
	elif absf(float(sniper_crit.get("cap", 0.0)) - 0.65) > 0.0001:
		_fail("sniper live-Agility crit cap %.3f != 0.65." % float(sniper_crit.get("cap", 0.0)))
	var assassin_crit: Dictionary = AttributeContract.attribute_presentation(
		crit_reward, "assassin", ProgressionData.base_stats("assassin"), {}, ProgressionData.weapon("assassin", "chakrams"))
	if absf(float(assassin_crit.get("cap", 0.0)) - 1.0) > 0.0001:
		_fail("assassin crit cap %.3f != 1.0 (Хладнокровие)." % float(assassin_crit.get("cap", 0.0)))
	var berserk_vamp: Dictionary = AttributeContract.attribute_presentation(
		vamp_reward, "berserk", berserk_stats, {}, berserk_weapon)
	if not berserk_vamp.has("proc_chance_current") or absf(float(berserk_vamp.get("proc_chance_cap", 0.0)) - ProgressionData.VAMPIRIC_CHANCE_CAP) > 0.0001:
		_fail("vampiric presentation без отдельного proc-chance current/cap=20%.")
	# Cap-reached фильтр: крит на капе не предлагается.
	var capped_mods := {"crit_chance_flat": 5.0}
	var capped_crit: Dictionary = AttributeContract.attribute_presentation(
		crit_reward, "sniper", sniper_stats, capped_mods, sniper_weapon)
	if str(capped_crit.get("availability", "")) != "cap_reached":
		_fail("Крит на капе: availability '%s' != 'cap_reached'." % capped_crit.get("availability", ""))
	var capped_pool: Array = AttributeContract.eligible_level_up_rewards(
		"sniper", sniper_stats, capped_mods, sniper_weapon)
	for reward in capped_pool:
		if str(reward.get("attr", "")) == "crit_chance":
			_fail("Крит-карта на капе осталась в eligible-пуле.")

	# 4) Сейвы: static-санитайзер (без контекста) + context-aware перепроверка.
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
	# FAN-1927: context-aware перепроверка ИЗВЕСТНЫХ карт.
	var skull_config: Dictionary = ProgressionData.weapon("dark_mage", "cursed_skull")
	var known_flat_offer := [damage_flat_reward.duplicate(true)]
	if not AttributeContract.sanitize_level_up_offer(known_flat_offer, "dark_mage", dark_stats, {}, skull_config).is_empty():
		_fail("Известная карта damage_flat с cursed_skull (no-op) не сброшена context-aware санитайзером.")
	var known_crit_offer := [crit_reward.duplicate(true)]
	if not AttributeContract.sanitize_level_up_offer(known_crit_offer, "sniper", sniper_stats, capped_mods, sniper_weapon).is_empty():
		_fail("Известная крит-карта на капе не сброшена context-aware санитайзером.")
	var healthy_offer := [damage_flat_reward.duplicate(true), crit_reward.duplicate(true)]
	if AttributeContract.sanitize_level_up_offer(healthy_offer, "sniper", sniper_stats, {}, sniper_weapon).size() != 2:
		_fail("Валидный показ незаслуженно сброшен context-aware санитайзером.")
	# Удалённый id не воскресает и при переданном контексте.
	if not AttributeContract.sanitize_level_up_offer(legacy_offer, "dark_mage", dark_stats, {}, skull_config).is_empty():
		_fail("Удалённая карта воскресла при context-aware вызове.")
	# Старые run_modifiers-ключи — рабочий внутренний compatibility-вход.
	var legacy_mods := {"magic_damage_multiplier": 1.5, "range_multiplier": 1.2, "buff_power_flat": 0.2, "absorb_flat": 3.0}
	var legacy_params: Dictionary = ProgressionData.derived_parameters(dark_stats, legacy_mods, dark_book)
	var clean_params: Dictionary = ProgressionData.derived_parameters(dark_stats, {}, dark_book)
	if float(legacy_params.get("magic_damage", 0.0)) <= float(clean_params.get("magic_damage", 0.0)):
		_fail("Legacy magic_damage_multiplier перестал применяться (compatibility-вход сломан).")
	if float(legacy_params.get("absorb", 0.0)) <= float(clean_params.get("absorb", 0.0)):
		_fail("Legacy absorb_flat перестал применяться (compatibility-вход сломан).")

	_holder.queue_free()
	await process_frame

	if _failed:
		push_error("FAN-1887/FAN-1927 consumability gate FAILED.")
		quit(1)
		return
	print("FAN-1887/FAN-1927 consumability gate passed: 51 живой путь класс×оружие с независимым live-consumer oracle, %d×17 сидированных показов без optional/no-op/ineligible, context-aware сейвы совместимы." % SEEDED_OFFERS_PER_CLASS)
	quit(0)
