extends SceneTree

# FAN-1893: certifying-гейт явного capability-контракта оружий.
#
# 1) 51-row матрица (17 классов × 3 оружия): каждый конфиг ЯВНО объявляет
#    real_projectile_count и summon_semantics; объявления сверяются со
#    структурными ключами боевого пути (projectile_count/beam_count/roster/
#    pair/device/deploy) — этикетка не может разойтись с рантаймом молча.
# 2) Capability-derived summon/Leadership set == {guitarist, chemist, druid,
#    engineer} и совпадает с config-derived ProgressionData.class_summon_capable;
#    только эти классы получают summon/Leadership-предложения (production-путь
#    level_up_rewards / eligible_level_up_rewards / is_base_stat_consumable).
# 3) «+1 снаряд» — ИСПОЛНЯЕМЫЕ probes, не labels: у каждого capability-оружия
#    (production seam _extra_projectiles + полные выстрелы по mock-врагам)
#    +1 extra_projectile создаёт ровно один дополнительный реальный снаряд;
#    у Часовой турели это один снаряд на каждый залп каждой активной сущности;
#    у каждого не-capability оружия generic-ключ доказуемо инертен
#    (цепи/рикошеты/ловушки/тики/ширина/зеркальная пара/лучи/melee).
#    Семантические мета-ключи (trap_extra_count/mine_extra_count/
#    elemental_orb_extra_count) остаются рабочими — проверяется исполнением.
# 4) summon_bonus входит в единый capped-парк ровно один раз
#    (player._apply_weapon_scaling), «pair»/«device» его не читают
#    (исполняемая популяция пары, reset устройств), derived summon_amount
#    его НЕ содержит (анти-двойное-применение). FAN-2250: advisor-прогноз
#    «Силы призыва» сверяется с фактическим парком живого Player, а bounded
#    мутация конфига доказывает, что сравнение способно падать.
# 5) Legacy-входы мигрируют fail-closed: конфиг без ключей → 0/"none" без
#    крэша; неизвестная семантика → "none"; сейв-показ с summon-картой у
#    класса без потребителя сбрасывается.
# 6) FAN-2249: ВЕСЬ реестр прогоняется живым Player'ом — фактическая ветка
#    player._apply_weapon_scaling обязана совпасть с объявленной
#    summon_semantics ("device" игнорирует summon_bonus, остальные считают
#    ровно AttributeContract.summon_runtime_count вместе с amp_cap_bonus и
#    «Полевым чертежом»), а «Сила призыва» появляется строкой досье только у
#    настоящих потребителей (намеренные pair/device/mine_field — нет).
#
# Запуск: python3 tools/godot_gate.py --headless --path . --script res://tests/fan1893_capability_contract_test.gd

const PD := preload("res://scripts/progression_data.gd")
const ClassWeaponScript := preload("res://scripts/class_weapon.gd")
const BerserkWeaponScript := preload("res://scripts/berserk_weapon.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")

# Ожидаемая 51-row матрица: не перечисленное оружие обязано объявлять 0/"none".
const EXPECTED_PROJECTILE_CAPABILITY := {
	"soldier_rifle": 1,
	"sniper_shatter_rounds": 6,
	"storm_longbow": 5,
	"plague_syringe": 1,
	"engineer_sentry_wrench": 2,
	"restore_potion": 1,
	"blast_powder": 2,
	"acid_flask": 1,
	"briar_staff": 1,
}
const EXPECTED_SUMMON_SEMANTICS := {
	"sound_amp": "deploy",
	"raven_totem": "deploy",
	"summon_amulet": "pack",
	"homunculus_vial": "pair",
	"engineer_sentry_wrench": "device",
	"engineer_repair_drone": "device",
	"engineer_pressure_mines": "mine_field",
}
const EXPECTED_SUMMON_CLASSES := ["chemist", "druid", "engineer", "guitarist"]
const ENGINEER_DEVICE_MODES := ["engineer_sentry_link", "engineer_orbit_drone"]
# Berserk/Knight — BerserkWeapon (melee, без attack_mode), Druid amulet и
# Chemist vial — SummonerWeapon: у этих скриптов generic-шва «+1 снаряд» нет.
const BERSERK_WEAPON_IDS := ["sword", "axe", "hammer", "long_spear", "tower_shield", "holy_flail"]
const SUMMONER_WEAPON_IDS := ["summon_amulet", "homunculus_vial"]

var _failed := false
var _holder: Node2D


func _fail(message: String) -> void:
	push_error("[fan1893-capability] FAIL: %s" % message)
	_failed = true


class MockOwner extends CharacterBody2D:
	var character_id := "soldier"
	var level := 1
	var derived_parameters := {
		"damage": 100.0,
		"magic_damage": 100.0,
		"crit_chance": 0.0,
		"crit_damage_multiplier": 1.0,
		"dot_damage": 5.0,
		"dot_speed": 1.0,
		"summon_amount": 0.0,
	}
	var run_modifiers := {}
	var stats := {}
	var health := 80.0
	var max_health := 100.0
	var money := 0
	# Семантический мета-канал (player.meta_extra_projectiles): по умолчанию 0;
	# probe семантики включает его точечно.
	var semantic_extra := {}

	func class_trait_value(key: String, default_value := 0.0) -> float:
		var trait_config: Dictionary = PD.CLASS_TRAITS.get(character_id, {})
		return float(trait_config.get(key, default_value))

	func gain_money(amount: int) -> void:
		money += amount

	func apply_drain_heal(amount: float) -> float:
		var before := health
		health = minf(max_health, health + amount)
		return health - before

	func heal_percent_capped(percent: float) -> void:
		apply_drain_heal(max_health * percent)

	func heal_percent(percent: float) -> void:
		apply_drain_heal(max_health * percent)

	func meta_extra_projectiles(context := {}) -> int:
		var ctx: Dictionary = context if context is Dictionary else {}
		return int(semantic_extra.get(str(ctx.get("attack_mode", "")), 0))


class MockEnemy extends Node2D:
	var total_damage := 0.0
	var hit_count := 0

	func take_damage(amount: float, _feedback := {}) -> void:
		total_damage += amount
		hit_count += 1

	func _show_combat_feedback(_amount: float, _feedback: Dictionary) -> void:
		pass


func _initialize() -> void:
	_test_matrix_shape()
	_test_capability_class_set_and_offers()
	_test_projectile_seam_all_class_weapons()
	await _test_positive_projectile_probes()
	await _test_negative_projectile_probes()
	await _test_summon_bonus_single_capped_application()
	await _test_runtime_branch_matches_declared_semantics()
	_test_fail_closed_migration()

	if _failed:
		push_error("FAN-1893 capability contract test FAILED.")
		quit(1)
		return
	print("FAN-1893 capability contract test passed: 51/51 explicit matrix, capability-derived summon set %s, executed +1-projectile positive/negative probes, single capped summon_bonus application, advisor forecast == live Player park with mutation control (FAN-2250), 51/51 runtime summon branch == declared semantics (FAN-2249), fail-closed legacy migration." % str(EXPECTED_SUMMON_CLASSES))
	quit(0)


func _all_weapon_rows() -> Array:
	var rows: Array = []
	for character_id_raw in PD.character_ids():
		var cid := str(character_id_raw)
		for weapon_id_raw in PD.weapon_ids(cid):
			rows.append({"cid": cid, "wid": str(weapon_id_raw), "config": PD.weapon(cid, str(weapon_id_raw))})
	return rows


# --- 1) 51-row матрица: явные объявления + структурная согласованность ------------


func _test_matrix_shape() -> void:
	var rows := _all_weapon_rows()
	if rows.size() != 51:
		_fail("registry must expose exactly 51 weapon configs, got %d" % rows.size())
	for row in rows:
		var cid: String = row["cid"]
		var wid: String = row["wid"]
		var config: Dictionary = row["config"]
		var context := "%s/%s" % [cid, wid]
		if not config.has("real_projectile_count") or not config.has("summon_semantics"):
			_fail("%s: config must EXPLICITLY declare real_projectile_count and summon_semantics" % context)
			continue
		var declared_count := int(config.get("real_projectile_count", -1))
		var declared_semantics := str(config.get("summon_semantics", ""))
		if declared_count != int(EXPECTED_PROJECTILE_CAPABILITY.get(wid, 0)):
			_fail("%s: real_projectile_count %d != expected %d" % [context, declared_count, int(EXPECTED_PROJECTILE_CAPABILITY.get(wid, 0))])
		if declared_semantics != str(EXPECTED_SUMMON_SEMANTICS.get(wid, "none")):
			_fail("%s: summon_semantics '%s' != expected '%s'" % [context, declared_semantics, str(EXPECTED_SUMMON_SEMANTICS.get(wid, "none"))])
		if not (declared_semantics in AttributeContract.SUMMON_SEMANTICS_VALUES):
			_fail("%s: unknown summon_semantics '%s'" % [context, declared_semantics])
		# Контракт чтения: AttributeContract видит ровно объявленное.
		if AttributeContract.weapon_real_projectile_count(config) != declared_count:
			_fail("%s: AttributeContract.weapon_real_projectile_count mismatch" % context)
		if AttributeContract.weapon_summon_semantics(config) != declared_semantics:
			_fail("%s: AttributeContract.weapon_summon_semantics mismatch" % context)
		# Структурная согласованность projectile-объявления с боевым путём:
		# число снарядов, которым руководит ось, обязано совпадать с фактической
		# базой режима; ловушки/тики/цепи/ширина/пара/melee объявляют 0.
		var mode := str(config.get("attack_mode", ""))
		var structural_count := 0
		match mode:
			"aoe_projectile":
				structural_count = int(config.get("projectile_count", 1))
			"arquebus_shot":
				structural_count = 1
			"plague_dart":
				structural_count = 1
			"sniper_split_round", "engineer_sentry_link":
				structural_count = int(config.get("projectile_count", 1))
			"storm_pierce_cone":
				structural_count = int(config.get("beam_count", 1))
			_:
				structural_count = 0
		if declared_count != structural_count:
			_fail("%s: real_projectile_count %d diverges from production base %d (mode '%s')" % [context, declared_count, structural_count, mode])
		# Структурная согласованность summon-семантики.
		var has_roster: bool = (config.get("summon_roster", []) as Array).size() > 0
		var is_pair := bool(config.get("summon_pair_mode", false))
		match declared_semantics:
			"pack":
				if not has_roster or is_pair:
					_fail("%s: 'pack' requires summon_roster without pair mode" % context)
			"pair":
				if not is_pair:
					_fail("%s: 'pair' requires summon_pair_mode" % context)
			"device":
				if not (mode in ENGINEER_DEVICE_MODES):
					_fail("%s: 'device' requires engineer device attack_mode" % context)
			"deploy":
				if mode != "amp" or config.get("max_summons") == null or config.get("max_summons_cap") == null:
					_fail("%s: 'deploy' requires amp mode with capped max_summons" % context)
			"mine_field":
				if mode != "engineer_pressure_mines":
					_fail("%s: 'mine_field' requires pressure mines mode" % context)
			"none":
				if has_roster or is_pair or config.get("max_summons") != null or str(config.get("deploy_role", "")) != "":
					_fail("%s: 'none' contradicts structural summon keys" % context)


# --- 2) Capability-derived класс-набор и предложения -------------------------------


func _test_capability_class_set_and_offers() -> void:
	var capability_classes: Array = []
	for character_id_raw in PD.character_ids():
		var cid := str(character_id_raw)
		var capable := false
		for weapon_id_raw in PD.weapon_ids(cid):
			if AttributeContract.weapon_summon_semantics(PD.weapon(cid, str(weapon_id_raw))) != "none":
				capable = true
		if capable:
			capability_classes.append(cid)
		# Единый источник: explicit-семантика и config-derived class_summon_capable
		# обязаны совпадать для всех 17 классов.
		if capable != PD.class_summon_capable(cid):
			_fail("%s: explicit capability set diverges from class_summon_capable" % cid)
		# Leadership-предложения (rare stat слот / Attribute Shop) — только
		# summon-способным классам.
		if PD.is_base_stat_consumable("leadership", cid) != capable:
			_fail("%s: leadership consumability must equal summon capability" % cid)
		# Production-пул level-up: summon_amount-карта существует только у
		# capability-классов (никакого universal echo/fake consumer у остальных 13).
		var has_summon_card := false
		for reward in PD.level_up_rewards(cid):
			if str((reward as Dictionary).get("attr", "")) == "summon_amount":
				has_summon_card = true
		if has_summon_card != capable:
			_fail("%s: summon_amount card offered=%s but capability=%s" % [cid, str(has_summon_card), str(capable)])
	capability_classes.sort()
	if capability_classes != EXPECTED_SUMMON_CLASSES:
		_fail("capability-derived summon classes %s != %s" % [str(capability_classes), str(EXPECTED_SUMMON_CLASSES)])
	# Per-weapon consumer: summon_bonus двигает парк только у "pack"/"deploy".
	for row in _all_weapon_rows():
		var config: Dictionary = row["config"]
		var semantics := AttributeContract.weapon_summon_semantics(config)
		var expected_consumer: bool = semantics in ["pack", "deploy"]
		if AttributeContract.weapon_consumes_summon_bonus(config) != expected_consumer:
			_fail("%s/%s: weapon_consumes_summon_bonus != (semantics in pack/deploy)" % [row["cid"], row["wid"]])
	# Исполняемый production-фильтр карточек: у consumer-оружия карта призыва
	# eligible, у прочих оружий тех же классов — нет.
	for probe in [
		{"cid": "guitarist", "wid": "sound_amp", "expected": true},
		{"cid": "guitarist", "wid": "electric_guitar", "expected": false},
		{"cid": "druid", "wid": "raven_totem", "expected": true},
		{"cid": "chemist", "wid": "homunculus_vial", "expected": false},
		{"cid": "engineer", "wid": "engineer_sentry_wrench", "expected": false},
	]:
		var cid := str(probe["cid"])
		var config := PD.weapon(cid, str(probe["wid"]))
		var offered := false
		for reward in AttributeContract.eligible_level_up_rewards(cid, PD.base_stats(cid), {}, config):
			if str((reward as Dictionary).get("attr", "")) == "summon_amount":
				offered = true
		if offered != bool(probe["expected"]):
			_fail("%s/%s: summon card eligibility %s != expected %s" % [cid, str(probe["wid"]), str(offered), str(probe["expected"])])


# --- 3) Production seam «+1 снаряд» для всех ClassWeapon-оружий --------------------


func _test_projectile_seam_all_class_weapons() -> void:
	var holder := _new_scene("Fan1893SeamScene")
	for row in _all_weapon_rows():
		var wid: String = row["wid"]
		if wid in BERSERK_WEAPON_IDS or wid in SUMMONER_WEAPON_IDS:
			continue
		var config: Dictionary = row["config"]
		var owner := _new_owner(holder, str(row["cid"]))
		owner.run_modifiers = {"extra_projectile": 3.0}
		var weapon := _new_class_weapon(owner, config)
		var expected := 3 if int(EXPECTED_PROJECTILE_CAPABILITY.get(wid, 0)) > 0 else 0
		var actual := int(weapon.call("_extra_projectiles"))
		if actual != expected:
			_fail("%s/%s: _extra_projectiles()==%d, expected %d under extra_projectile=3" % [row["cid"], wid, actual, expected])
		owner.queue_free()
	# У SummonerWeapon generic-шва нет вовсе — ключ физически не читается.
	for wid_raw in SUMMONER_WEAPON_IDS:
		var summoner := Node2D.new()
		summoner.set_script(load("res://scripts/summoner_weapon.gd"))
		if summoner.has_method("_extra_projectiles"):
			_fail("%s: SummonerWeapon must not expose an extra_projectile seam" % str(wid_raw))
		summoner.free()
	_cleanup_now(holder)


# --- 4) Полные исполняемые probes: «+1 снаряд» = ровно один реальный снаряд --------


func _test_positive_projectile_probes() -> void:
	# a) Аркебуза (site _fire_arquebus_shot): +1 пуля в СЛЕДУЮЩУЮ ближайшую цель.
	var hits0 := await _fire_and_count("soldier", "soldier_rifle", 0, [Vector2(300, 0), Vector2(0, 350), Vector2(-380, 0)], 0.8)
	var hits1 := await _fire_and_count("soldier", "soldier_rifle", 1, [Vector2(300, 0), Vector2(0, 350), Vector2(-380, 0)], 0.8)
	if _distinct(hits0) != 1 or _distinct(hits1) != 2:
		_fail("arquebus: distinct targets %d -> %d, expected 1 -> 2 (+1 real bullet)" % [_distinct(hits0), _distinct(hits1)])
	# b) Прямой AoE-снаряд (site _fire_aoe_projectile): projectile_count 2 -> 3 целей.
	var blast0 := await _fire_and_count("chemist", "blast_powder", 0, [Vector2(260, 0), Vector2(0, 300), Vector2(-320, 40)], 0.9)
	var blast1 := await _fire_and_count("chemist", "blast_powder", 1, [Vector2(260, 0), Vector2(0, 300), Vector2(-320, 40)], 0.9)
	if _distinct(blast0) != 2 or _distinct(blast1) != 3:
		_fail("blast_powder: distinct targets %d -> %d, expected 2 -> 3 (+1 real orb)" % [_distinct(blast0), _distinct(blast1)])
	# c) Split-round (site _fire_sniper_split_round): залп 6 -> 7 пуль (<=2 на цель).
	var split_positions := [Vector2(220, 0), Vector2(0, 240), Vector2(-260, 0), Vector2(0, -230)]
	var split0 := await _fire_and_count("sniper", "sniper_shatter_rounds", 0, split_positions, 1.0)
	var split1 := await _fire_and_count("sniper", "sniper_shatter_rounds", 1, split_positions, 1.0)
	if _total(split0) != 6 or _total(split1) != 7:
		_fail("split_round: total hits %d -> %d, expected 6 -> 7 (+1 real bullet)" % [_total(split0), _total(split1)])
	# d) Чумной дротик (site _fire_plague_dart): +1 дротик в соседа первичной цели.
	var dart0 := await _fire_and_count("doctor", "plague_syringe", 0, [Vector2(280, 0), Vector2(280, 150)], 0.8)
	var dart1 := await _fire_and_count("doctor", "plague_syringe", 1, [Vector2(280, 0), Vector2(280, 150)], 0.8)
	if _distinct(dart0) != 1 or _distinct(dart1) != 2:
		_fail("plague_dart: distinct targets %d -> %d, expected 1 -> 2 (+1 real dart)" % [_distinct(dart0), _distinct(dart1)])
	# e) Конус стрел (site _fire_storm_pierce_cone): +1 стрела = ровно +2
	#    зарегистрированных эффекта стрелы (beam + trace) за каст.
	var holder := _new_scene("Fan1893StormCone")
	var storm_owner := _new_owner(holder, "ranger")
	var storm_weapon := _new_class_weapon(storm_owner, PD.weapon("ranger", "storm_longbow"))
	var before0: int = (storm_weapon.get("_spawned_effects") as Array).size()
	storm_weapon.call("_fire_storm_pierce_cone", storm_owner, Vector2.RIGHT)
	var arrows_base: int = (storm_weapon.get("_spawned_effects") as Array).size() - before0
	storm_owner.run_modifiers = {"extra_projectile": 1.0}
	var before1: int = (storm_weapon.get("_spawned_effects") as Array).size()
	storm_weapon.call("_fire_storm_pierce_cone", storm_owner, Vector2.RIGHT)
	var arrows_extra: int = (storm_weapon.get("_spawned_effects") as Array).size() - before1
	if arrows_extra - arrows_base != 2:
		_fail("storm_pierce_cone: effect delta %d -> %d, expected exactly +2 (one more real arrow)" % [arrows_base, arrows_extra])
	await _cleanup(holder)
	# f) Две активные турели: production deploy -> try_fire у КАЖДОЙ. Один
	# modifier point добавляет по снаряду в каждый entity volley, не в парк.
	var sentry0 := await _sentry_park_volley_hits(0)
	var sentry1 := await _sentry_park_volley_hits(1)
	var firing_entities := int(sentry0.get("entities", 0))
	if firing_entities < 2 or int(sentry1.get("entities", 0)) != firing_entities:
		_fail("sentry park: expected the same >=2 active firing entities, got %s -> %s" % [str(sentry0), str(sentry1)])
	elif int(sentry0.get("hits", 0)) != firing_entities * 2 or int(sentry1.get("hits", 0)) - int(sentry0.get("hits", 0)) != firing_entities:
		_fail("sentry park: aggregate hits %s -> %s, expected base %d and +%d (one shot per firing entity)" % [str(sentry0), str(sentry1), firing_entities * 2, firing_entities])


func _test_negative_projectile_probes() -> void:
	# a) Цепь палочки: extra=9 не удлиняет (3 цели), артефакт wand_extra_chain — да.
	var line := [Vector2(200, 0), Vector2(350, 0), Vector2(500, 0), Vector2(650, 0), Vector2(800, 0), Vector2(950, 0)]
	var chain_inert := await _fire_and_count("dark_mage", "dark_wand", 9, line, 1.4)
	if _distinct(chain_inert) != 3:
		_fail("dark_wand: extra_projectile must not extend the chain (distinct %d != 3)" % _distinct(chain_inert))
	var chain_artifact := await _fire_and_count("dark_mage", "dark_wand", 0, line, 1.4, {"wand_extra_chain": 1.0})
	if _distinct(chain_artifact) != 4:
		_fail("dark_wand: wand_extra_chain artifact must still extend the chain (distinct %d != 4)" % _distinct(chain_artifact))
	# b) Рикошет монеты: extra=9 не удлиняет (6 звеньев), coin_extra_bounces — да.
	var cluster: Array = []
	for coin_index in range(8):
		cluster.append(Vector2(180 + 190 * coin_index, 0))
	var coin_inert := await _fire_and_count("thief", "thief_coin_pouch", 9, cluster, 0.3)
	if _distinct(coin_inert) != 6:
		_fail("coin_ricochet: extra_projectile must not extend the chain (distinct %d != 6)" % _distinct(coin_inert))
	var coin_artifact := await _fire_and_count("thief", "thief_coin_pouch", 0, cluster, 0.3, {"coin_extra_bounces": 1.0})
	if _distinct(coin_artifact) != 7:
		_fail("coin_ricochet: coin_extra_bounces artifact must still extend the chain (distinct %d != 7)" % _distinct(coin_artifact))
	# c) Капкан: extra=9 не добавляет капканов; семантический trap_extra_count — да.
	var traps_inert := await _deploy_and_count_nodes("ranger", "hunter_trap", 9, {}, "hunter_trap_meta")
	if traps_inert != 1:
		_fail("hunter_trap: extra_projectile must not add traps (%d != 1)" % traps_inert)
	var traps_semantic := await _deploy_and_count_nodes("ranger", "hunter_trap", 0, {"trap": 1}, "hunter_trap_meta")
	if traps_semantic != 2:
		_fail("hunter_trap: semantic trap_extra_count must still add a trap (%d != 2)" % traps_semantic)
	# d) Мины: extra=9 не добавляет мин; семантический mine_extra_count — да.
	var mines_inert := await _deploy_and_count_nodes("engineer", "engineer_pressure_mines", 9, {}, "mine_node")
	if mines_inert != 2:
		_fail("pressure_mines: extra_projectile must not add mines (%d != 2)" % mines_inert)
	var mines_semantic := await _deploy_and_count_nodes("engineer", "engineer_pressure_mines", 0, {"engineer_pressure_mines": 1}, "mine_node")
	if mines_semantic != 3:
		_fail("pressure_mines: semantic mine_extra_count must still add a mine (%d != 3)" % mines_semantic)
	# e) Тики квадрата: extra=9 инертен; семантический elemental_orb_extra_count работает.
	var ticks_base := await _orbit_tick_hits(0, 0)
	var ticks_inert := await _orbit_tick_hits(9, 0)
	var ticks_semantic := await _orbit_tick_hits(0, 2)
	if ticks_inert != ticks_base:
		_fail("elemental_orbit: extra_projectile must not add field ticks (%d != %d)" % [ticks_inert, ticks_base])
	if ticks_semantic <= ticks_base:
		_fail("elemental_orbit: semantic elemental_orb_extra_count must add ticks (%d <= %d)" % [ticks_semantic, ticks_base])
	# f) Зеркальная пара книги: extra=9 не создаёт вторую пару — дальняя цель цела.
	var mirror_hits := await _fire_and_count("dark_mage", "dark_book", 9, [Vector2(300, 0), Vector2(300, 420)], 1.2)
	if mirror_hits[0] < 1 or mirror_hits[1] != 0:
		_fail("dark_mirror_blast: extra_projectile must not add mirror pairs (hits %s)" % str(mirror_hits))
	# g) Луч (dot_beam): extra=9 не создаёт веер — на пустой арене каст с extra
	#    регистрирует ровно столько же эффектов луча, сколько базовый (1 струна).
	#    Геометрию по врагам тут не считаем: у venom_wire есть честный
	#    spread-канал яда вне линии (dot_beam_spread_ratio), он не про число лучей.
	var beam_holder := _new_scene("Fan1893DotBeam")
	var beam_owner := _new_owner(beam_holder, "assassin")
	var beam_weapon := _new_class_weapon(beam_owner, PD.weapon("assassin", "venom_wire"))
	var beam_before0: int = (beam_weapon.get("_spawned_effects") as Array).size()
	beam_weapon.call("_fire_dot_beam", beam_owner, Vector2.RIGHT)
	var beam_effects_base: int = (beam_weapon.get("_spawned_effects") as Array).size() - beam_before0
	beam_owner.run_modifiers = {"extra_projectile": 9.0}
	var beam_before1: int = (beam_weapon.get("_spawned_effects") as Array).size()
	beam_weapon.call("_fire_dot_beam", beam_owner, Vector2.RIGHT)
	var beam_effects_extra: int = (beam_weapon.get("_spawned_effects") as Array).size() - beam_before1
	if beam_effects_extra != beam_effects_base:
		_fail("dot_beam: extra_projectile must not fan out beams (effects %d != %d)" % [beam_effects_extra, beam_effects_base])
	await _cleanup(beam_holder)
	# h) Melee (BerserkWeapon): у скрипта нет шва — удары идентичны при extra=9.
	var melee_base := await _berserk_swing_hits(0)
	var melee_inert := await _berserk_swing_hits(9)
	if melee_base <= 0 or melee_inert != melee_base:
		_fail("berserk melee: extra_projectile must be inert (%d != %d)" % [melee_inert, melee_base])
	# Ширина вентилей реактора: инертность extra_projectile для robot_reactor_core
	# закреплена дискриминирующей пробой tests/robot_kit_test.gd
	# (_test_reactor_blade_width_and_reset): враг на side 55 — вне базовой
	# полулопасти 48, но внутри удалённой расширенной 61.4 — обязан получить
	# ноль хитов, поэтому возврат width-бонуса роняет тот гейт.


# --- 5) summon_bonus: единый capped-парк, ровно одно применение --------------------


func _test_summon_bonus_single_capped_application() -> void:
	# Анти-двойное-применение: derived summon_amount НЕ содержит summon_bonus.
	var druid_stats := PD.base_stats("druid")
	var druid_config := PD.weapon("druid", "summon_amulet")
	var derived_plain: Dictionary = PD.derived_parameters(druid_stats, {}, druid_config)
	var derived_bonus: Dictionary = PD.derived_parameters(druid_stats, {"summon_bonus": 99.0}, druid_config)
	if absf(float(derived_plain.get("summon_amount", 0.0)) - float(derived_bonus.get("summon_amount", 0.0))) > 0.0001:
		_fail("derived summon_amount must not consume summon_bonus (single application lives in _apply_weapon_scaling)")

	# pack: парк = база + Лидерство/4 + summon_bonus; популяция исполняется до лимита.
	var pack := await _player_with("druid", "summon_amulet", {"summon_bonus": 2.0})
	var pack_weapon: Node = pack["weapon"]
	var leadership := float(PD.base_stats("druid").get("leadership", 0.0))
	var expected_pack := int(druid_config.get("max_summons", 0)) + int(floor(leadership / 4.0)) + 2
	if int(pack_weapon.get("max_summons")) != expected_pack:
		_fail("summon_amulet: max_summons %d != base+leadership/4+bonus %d" % [int(pack_weapon.get("max_summons")), expected_pack])
	while bool(pack_weapon.call("_summon", false)):
		pass
	var live_pack: int = (pack_weapon.call("_active_weapon_summons", pack["player"]) as Array).size()
	if live_pack != expected_pack:
		_fail("summon_amulet: executed population %d != scaled park %d" % [live_pack, expected_pack])
	await _cleanup(pack["holder"])

	# deploy (amp): кап max_summons_cap держит парк; amp_cap_bonus поднимает кап.
	var amp := await _player_with("guitarist", "sound_amp", {"summon_bonus": 99.0})
	if int((amp["weapon"] as Node).get("max_summons")) != int(PD.weapon("guitarist", "sound_amp").get("max_summons_cap")):
		_fail("sound_amp: summon_bonus must clamp to max_summons_cap")
	await _cleanup(amp["holder"])
	var amp_bonus := await _player_with("guitarist", "sound_amp", {"summon_bonus": 99.0, "amp_cap_bonus": 1.0})
	if int((amp_bonus["weapon"] as Node).get("max_summons")) != int(PD.weapon("guitarist", "sound_amp").get("max_summons_cap")) + 1:
		_fail("sound_amp: amp_cap_bonus must lift the cap by exactly one")
	await _cleanup(amp_bonus["holder"])

	# device: summon_bonus НЕ читается — max_summons остаётся базой, лимит кита
	# считает derived summon_amount (только статы).
	var sentry := await _player_with("engineer", "engineer_sentry_wrench", {"summon_bonus": 99.0})
	var sentry_weapon: Node = sentry["weapon"]
	if int(sentry_weapon.get("max_summons")) != int(PD.weapon("engineer", "engineer_sentry_wrench").get("max_summons")):
		_fail("sentry: device kit must reset max_summons to base under summon_bonus")
	var limit_bonus := int(sentry_weapon.call("_engineer_turret_limit", sentry["player"]))
	(sentry["player"] as Node).set("run_modifiers", {})
	var limit_plain := int(sentry_weapon.call("_engineer_turret_limit", sentry["player"]))
	if limit_bonus != limit_plain:
		_fail("sentry: turret limit must ignore summon_bonus (%d != %d)" % [limit_bonus, limit_plain])
	await _cleanup(sentry["holder"])

	# pair: популяция фиксирована парой независимо от summon_bonus.
	var pair := await _player_with("chemist", "homunculus_vial", {"summon_bonus": 99.0})
	for _frame in range(6):
		await process_frame
	var tanks := get_nodes_in_group("chemist_tank_homunculi").size()
	if tanks != 1:
		_fail("homunculus pair: exactly one tank regardless of summon_bonus (got %d)" % tanks)
	await _cleanup(pair["holder"])

	# Advisor (AC4, FAN-2250): прогноз «Силы призыва» сверяется с ФАКТИЧЕСКИМ
	# runtime-парком живого Player (configure_character → _apply_weapon_scaling
	# → weapon.max_summons), а не с helper'ом summon_runtime_count, который
	# advisor вызывает сам — самосравнение не ловило бы расхождение с рантаймом.
	var summon_card := {}
	for reward in PD.LEVEL_UP_REWARDS:
		if str((reward as Dictionary).get("attr", "")) == "summon_amount":
			summon_card = reward
	var amp_config := PD.weapon("guitarist", "sound_amp")
	var card_mods: Dictionary = summon_card.get("mods", {}) as Dictionary
	var advisor_before := await _player_with("guitarist", "sound_amp", {})
	var park_before := float((advisor_before["weapon"] as Node).get("max_summons"))
	var live_stats: Dictionary = ((advisor_before["player"] as Node).get("stats") as Dictionary).duplicate(true)
	var live_mods: Dictionary = ((advisor_before["player"] as Node).get("run_modifiers") as Dictionary).duplicate(true)
	await _cleanup(advisor_before["holder"])
	var advisor_after := await _player_with("guitarist", "sound_amp", card_mods.duplicate(true))
	var park_after := float((advisor_after["weapon"] as Node).get("max_summons"))
	await _cleanup(advisor_after["holder"])
	var forecast: Dictionary = LevelUpAdvisor.forecast_reward(summon_card, live_stats, live_mods, amp_config)
	if absf(float((forecast["before"] as Dictionary).get("summon_amount", -1.0)) - park_before) > 0.0001 \
			or absf(float((forecast["after"] as Dictionary).get("summon_amount", -1.0)) - park_after) > 0.0001:
		_fail("advisor: summon_amount forecast must match the live production park (park %.1f -> %.1f)" % [park_before, park_after])
	# Bounded mutation (анти-vacuous): конфиг со сдвинутыми парком и капом (+1)
	# обязан развести forecast с фактическим парком — равенство выше способно падать.
	var mutated_config: Dictionary = amp_config.duplicate(true)
	mutated_config["max_summons"] = int(amp_config.get("max_summons", 0)) + 1
	mutated_config["max_summons_cap"] = int(amp_config.get("max_summons_cap", 0)) + 1
	var mutated: Dictionary = LevelUpAdvisor.forecast_reward(summon_card, live_stats, live_mods, mutated_config)
	if absf(float((mutated["after"] as Dictionary).get("summon_amount", -1.0)) - park_after) <= 0.0001:
		_fail("advisor probe is vacuous: a +1 park/cap config mutation must diverge from the live runtime park")
	var electric_forecast: Dictionary = LevelUpAdvisor.forecast_reward(summon_card, live_stats, live_mods, PD.weapon("guitarist", "electric_guitar"))
	if (electric_forecast["before"] as Dictionary).has("summon_amount"):
		_fail("advisor: non-consumer weapon must not surface a phantom summon_amount delta")


# --- 6) FAN-2249: рантайм-ветка парка == объявленная summon_semantics --------------


# Моды, двигающие ОБЕ ветки: summon_bonus (парк), amp_cap_bonus и «Полевой
# чертеж» (кап deploy). Лидерство поднято так, чтобы чертеж давал +2 к капу.
const RUNTIME_BRANCH_MODS := {"summon_bonus": 3.0, "amp_cap_bonus": 1.0, "blueprint_leadership_scaling": 1.0}
const RUNTIME_BRANCH_LEADERSHIP := 12.0


func _test_runtime_branch_matches_declared_semantics() -> void:
	# Весь реестр против ФАКТИЧЕСКОЙ ветки player._apply_weapon_scaling: конфиг
	# не может молча разойтись с рантаймом. Один живой Player переэкипируется на
	# каждое оружие (production-путь configure_character → equip_weapon).
	var holder := _new_scene("Fan2249RuntimeBranch")
	var player := PLAYER_SCENE.instantiate()
	holder.add_child(player)
	player.global_position = Vector2(900, 700)
	await process_frame
	for row in _all_weapon_rows():
		var context := "%s/%s" % [row["cid"], row["wid"]]
		var config: Dictionary = row["config"]
		var semantics := AttributeContract.weapon_summon_semantics(config)
		# Чистый прогон и прогон под модами: «device» обязан игнорировать оба.
		var plain := await _runtime_park(player, str(row["cid"]), str(row["wid"]), false)
		var boosted := await _runtime_park(player, str(row["cid"]), str(row["wid"]), true)
		if plain.is_empty() or boosted.is_empty():
			# Скрипт оружия вовсе не держит парк — объявлять призыв ему нечем.
			if semantics != "none":
				_fail("%s: semantics '%s' declared, but the runtime weapon has no max_summons" % [context, semantics])
			continue
		for probe in [plain, boosted]:
			var expected := float(config.get("max_summons", 0.0)) if semantics == "device" \
				else AttributeContract.summon_runtime_count(config, probe["stats"], probe["mods"])
			if float(probe["park"]) != expected:
				_fail("%s: runtime max_summons %.0f != %.0f for semantics '%s' (summon_bonus %.0f)" % [
					context, float(probe["park"]), expected, semantics, float(probe["mods"].get("summon_bonus", 0.0))])
		if semantics == "device" and float(plain["park"]) != float(boosted["park"]):
			_fail("%s: 'device' park must ignore summon_bonus/cap mods (%.0f -> %.0f)" % [context, float(plain["park"]), float(boosted["park"])])
		# Кап предъявления == кап рантайма. Оракул теста — литеральная формула
		# (amp_cap_bonus + «Полевой чертеж» поверх max_summons_cap), а не вызов
		# того же production-кода, который она проверяет.
		if semantics == "deploy":
			var cap := AttributeContract.summon_runtime_cap(config, boosted["mods"], boosted["stats"])
			var expected_cap := float(int(config.get("max_summons_cap", 0))) + float(RUNTIME_BRANCH_MODS["amp_cap_bonus"]) + floorf(RUNTIME_BRANCH_LEADERSHIP / 6.0)
			var uncapped := float(config.get("max_summons", 0.0)) + floorf(RUNTIME_BRANCH_LEADERSHIP / 4.0) + float(RUNTIME_BRANCH_MODS["summon_bonus"])
			if cap != expected_cap:
				_fail("%s: summon_runtime_cap %.0f != %.0f (amp_cap_bonus + blueprint scaling)" % [context, cap, expected_cap])
			if float(boosted["park"]) != minf(uncapped, expected_cap):
				_fail("%s: production park %.0f != capped %.0f" % [context, float(boosted["park"]), minf(uncapped, expected_cap)])
		# Намеренные pair/device/mine_field не создают строку «Силы призыва».
		var has_axis_row := false
		for snapshot in AttributeContract.class_axes_snapshot(str(row["cid"]), boosted["stats"], boosted["mods"], config):
			if str((snapshot as Dictionary).get("axis_id", "")) == "summon_amount":
				has_axis_row = true
		if has_axis_row != AttributeContract.weapon_consumes_summon_bonus(config):
			_fail("%s: summon axis row=%s but consumer=%s (semantics '%s')" % [
				context, str(has_axis_row), str(AttributeContract.weapon_consumes_summon_bonus(config)), semantics])
	await _cleanup(holder)


# Один production-прогон: экипирует оружие, применяет моды и полный rescale;
# возвращает фактический парк вместе со статами/модами этого прогона.
func _runtime_park(player: Node, cid: String, wid: String, boosted: bool) -> Dictionary:
	player.call("configure_character", cid, wid)
	await process_frame
	var stats: Dictionary = player.get("stats")
	var mods: Dictionary = player.get("run_modifiers")
	if boosted:
		stats["leadership"] = RUNTIME_BRANCH_LEADERSHIP
		for mod_key in RUNTIME_BRANCH_MODS.keys():
			mods[str(mod_key)] = RUNTIME_BRANCH_MODS[mod_key]
		player.set("stats", stats)
		player.set("run_modifiers", mods)
	player.call("_apply_stat_scaling")
	for weapon in (player.call("_equipped_weapons") as Array):
		player.call("_apply_weapon_scaling", weapon)
		if weapon.get("max_summons") == null:
			continue
		return {"park": float(weapon.get("max_summons")), "stats": stats.duplicate(true), "mods": mods.duplicate(true)}
	return {}


# --- 7) Fail-closed миграция legacy-входов ----------------------------------------


func _test_fail_closed_migration() -> void:
	# Конфиг без capability-ключей: 0/"none" без крэша.
	var legacy_config := {"id": "legacy", "attack_mode": "trap", "max_summons": 3}
	if AttributeContract.weapon_real_projectile_count(legacy_config) != 0:
		_fail("legacy config without keys must fail closed to 0 projectiles")
	if AttributeContract.weapon_summon_semantics(legacy_config) != "none":
		_fail("legacy config without keys must fail closed to 'none'")
	if AttributeContract.weapon_consumes_summon_bonus(legacy_config):
		_fail("legacy config without explicit semantics must not consume summon_bonus")
	if AttributeContract.weapon_summon_semantics({"summon_semantics": "everything"}) != "none":
		_fail("unknown summon_semantics must fail closed to 'none'")
	# ClassWeapon с legacy-конфигом: шов закрыт.
	var holder := _new_scene("Fan1893LegacyScene")
	var owner := _new_owner(holder, "ranger")
	owner.run_modifiers = {"extra_projectile": 5.0}
	var weapon := _new_class_weapon(owner, legacy_config)
	if int(weapon.call("_extra_projectiles")) != 0:
		_fail("ClassWeapon with legacy config must keep the generic seam closed")
	_cleanup_now(holder)
	# Сейв-показ с summon-картой у класса без потребителя сбрасывается целиком.
	var stale_offer := [{"id": "summon_amount_up", "attr": "summon_amount", "title": "Сила призыва", "mods": {"summon_bonus": 2.0}}]
	if not (AttributeContract.sanitize_level_up_offer(stale_offer, "berserk") as Array).is_empty():
		_fail("stale saved offer with a summon card must reset for a non-capability class")


# --- харнесс ----------------------------------------------------------------------


func _new_scene(scene_name: String) -> Node2D:
	var holder := Node2D.new()
	holder.name = scene_name
	root.add_child(holder)
	current_scene = holder
	_holder = holder
	return holder


func _new_owner(holder: Node2D, cid: String, position := Vector2(900, 700)) -> MockOwner:
	var owner := MockOwner.new()
	owner.character_id = cid
	holder.add_child(owner)
	owner.global_position = position
	return owner


func _new_class_weapon(owner: CharacterBody2D, config: Dictionary) -> Node:
	var weapon := Node2D.new()
	weapon.set_script(ClassWeaponScript)
	owner.add_child(weapon)
	weapon.call("configure_weapon", config)
	weapon.set_process(false)
	weapon.set("_cooldown", 1.0e9)
	return weapon


func _new_enemy(holder: Node2D, position: Vector2) -> MockEnemy:
	var enemy := MockEnemy.new()
	enemy.add_to_group("enemies")
	holder.add_child(enemy)
	enemy.global_position = position
	return enemy


func _cleanup(holder: Node2D) -> void:
	holder.queue_free()
	current_scene = null
	await process_frame
	await process_frame


func _cleanup_now(holder: Node2D) -> void:
	holder.queue_free()
	current_scene = null


func _distinct(hits: Array) -> int:
	var count := 0
	for hit in hits:
		if int(hit) > 0:
			count += 1
	return count


func _total(hits: Array) -> int:
	var count := 0
	for hit in hits:
		count += int(hit)
	return count


# Полный исполняемый выстрел режима по mock-врагам; возвращает hit_count по
# каждому врагу в порядке размещения (позиции — относительно владельца).
func _fire_and_count(cid: String, wid: String, extra: int, offsets: Array, settle_seconds: float, extra_mods := {}) -> Array:
	var holder := _new_scene("Fan1893Probe_%s_%d" % [wid, extra])
	var owner := _new_owner(holder, cid)
	var config := PD.weapon(cid, wid)
	var weapon := _new_class_weapon(owner, config)
	owner.run_modifiers = {"extra_projectile": float(extra)}
	for mod_key in extra_mods.keys():
		owner.run_modifiers[str(mod_key)] = extra_mods[mod_key]
	var enemies: Array = []
	for offset in offsets:
		enemies.append(_new_enemy(holder, owner.global_position + (offset as Vector2)))
	await process_frame
	var mode := str(config.get("attack_mode", ""))
	var primary := enemies[0] as Node2D
	match mode:
		"arquebus_shot":
			weapon.call("_fire_arquebus_shot", owner, primary, Vector2.RIGHT)
		"aoe_projectile":
			weapon.call("_fire_aoe_projectile", owner, primary, Vector2.RIGHT)
		"sniper_split_round":
			weapon.call("_fire_sniper_split_round", owner, primary, Vector2.RIGHT)
		"plague_dart":
			weapon.call("_fire_plague_dart", owner, primary, Vector2.RIGHT)
		"dark_chain_burst":
			weapon.call("_fire_dark_chain_burst", owner, primary, Vector2.RIGHT)
		"coin_ricochet":
			weapon.call("_fire_coin_ricochet", owner, primary, Vector2.RIGHT)
		"dark_mirror_blast":
			weapon.call("_fire_dark_mirror_blast", owner, primary, Vector2.RIGHT)
		"dot_beam":
			weapon.call("_fire_dot_beam", owner, Vector2.RIGHT)
		_:
			_fail("probe for mode '%s' is not wired" % mode)
	if settle_seconds > 0.0:
		await create_timer(settle_seconds).timeout
	var hits: Array = []
	for enemy in enemies:
		hits.append((enemy as MockEnemy).hit_count)
	await _cleanup(holder)
	return hits


# Деплой-режимы: считает поставленные узлы (капканы по meta, мины по имени).
func _deploy_and_count_nodes(cid: String, wid: String, extra: int, semantic_extra: Dictionary, kind: String) -> int:
	var holder := _new_scene("Fan1893Deploy_%s_%d_%d" % [wid, extra, semantic_extra.size()])
	var owner := _new_owner(holder, cid)
	var weapon := _new_class_weapon(owner, PD.weapon(cid, wid))
	owner.run_modifiers = {"extra_projectile": float(extra)}
	owner.semantic_extra = semantic_extra
	await process_frame
	var mode := str(PD.weapon(cid, wid).get("attack_mode", ""))
	if mode == "trap":
		weapon.call("_fire_trap", owner, Vector2.RIGHT)
	else:
		weapon.call("_fire_engineer_pressure_mines", owner, Vector2.RIGHT)
	await process_frame
	var count := 0
	for child in holder.get_children():
		if kind == "hunter_trap_meta" and child.has_meta("hunter_trap"):
			count += 1
		elif kind == "mine_node" and child.has_meta("persistent_mine"):
			# По production-мете: дубликаты имён Godot переименовывает в "@Node2D@N".
			count += 1
	await _cleanup(holder)
	return count


func _orbit_tick_hits(extra: int, semantic_ticks: int) -> int:
	var holder := _new_scene("Fan1893Orbit_%d_%d" % [extra, semantic_ticks])
	var owner := _new_owner(holder, "elementalist")
	var weapon := _new_class_weapon(owner, PD.weapon("elementalist", "elementalist_orb_ring"))
	owner.run_modifiers = {"extra_projectile": float(extra)}
	if semantic_ticks > 0:
		owner.semantic_extra = {"elemental_orbit": semantic_ticks}
	var enemy := _new_enemy(holder, owner.global_position + Vector2(30, 0))
	await process_frame
	weapon.call("_fire_elemental_orbit", owner, Vector2.RIGHT)
	await create_timer(2.4).timeout
	var hits := enemy.hit_count
	await _cleanup(holder)
	return hits


func _berserk_swing_hits(extra: int) -> int:
	var holder := _new_scene("Fan1893Melee_%d" % extra)
	var owner := _new_owner(holder, "berserk")
	owner.run_modifiers = {"extra_projectile": float(extra)}
	var weapon := Node2D.new()
	weapon.set_script(BerserkWeaponScript)
	owner.add_child(weapon)
	weapon.call("configure_weapon", PD.weapon("berserk", "sword"))
	weapon.set_process(false)
	weapon.set("_cooldown", 1.0e9)
	var enemies := [
		_new_enemy(holder, owner.global_position + Vector2(180, 0)),
		_new_enemy(holder, owner.global_position + Vector2(240, 60)),
		_new_enemy(holder, owner.global_position + Vector2(240, -60)),
	]
	await process_frame
	weapon.call("_attack")
	await create_timer(0.6).timeout
	var total := 0
	for enemy in enemies:
		total += (enemy as MockEnemy).hit_count
	await _cleanup(holder)
	return total


func _sentry_park_volley_hits(extra: int) -> Dictionary:
	var holder := _new_scene("Fan1893Sentry_%d" % extra)
	var owner := _new_owner(holder, "engineer")
	owner.run_modifiers = {"extra_projectile": float(extra)}
	var weapon := _new_class_weapon(owner, PD.weapon("engineer", "engineer_sentry_wrench"))
	var enemies := [
		_new_enemy(holder, owner.global_position + Vector2(260, 0)),
		_new_enemy(holder, owner.global_position + Vector2(0, 300)),
		_new_enemy(holder, owner.global_position + Vector2(-340, 0)),
	]
	# Реальный deploy-path запускает try_fire сразу; два deployment-а создают
	# две независимо стреляющие сущности без ручной подмены volley formula.
	weapon.call("_fire_engineer_sentry_link", owner, Vector2.RIGHT)
	weapon.call("_fire_engineer_sentry_link", owner, Vector2.RIGHT)
	var firing_entities := 0
	for turret in (weapon.get("_deployed_amps") as Array):
		if turret != null and is_instance_valid(turret):
			turret.set_physics_process(false)
			firing_entities += 1
	await create_timer(1.0).timeout
	var hits := 0
	for enemy in enemies:
		hits += (enemy as MockEnemy).hit_count
	await _cleanup(holder)
	return {"entities": firing_entities, "hits": hits}


# Реальный Player + реальная сцена оружия: применяет run_modifiers и полный
# rescale (player._apply_stat_scaling + _apply_weapon_scaling), как apply_reward.
func _player_with(cid: String, wid: String, run_modifiers: Dictionary) -> Dictionary:
	var holder := _new_scene("Fan1893Player_%s_%s" % [cid, wid])
	var player := PLAYER_SCENE.instantiate()
	holder.add_child(player)
	player.global_position = Vector2(900, 700)
	await process_frame
	player.call("configure_character", cid, wid)
	await process_frame
	var mods: Dictionary = player.get("run_modifiers")
	for mod_key in run_modifiers.keys():
		mods[str(mod_key)] = run_modifiers[mod_key]
	player.set("run_modifiers", mods)
	player.call("_apply_stat_scaling")
	var weapon_node: Node = null
	for weapon in (player.call("_equipped_weapons") as Array):
		player.call("_apply_weapon_scaling", weapon)
		weapon_node = weapon
	return {"holder": holder, "player": player, "weapon": weapon_node}
