extends SceneTree

const CATALOG := preload("res://scripts/encounters/features/captains/captain_catalog.gd")
const CONTEXT := preload("res://scripts/encounters/encounter_context.gd")
const FEATURE := preload("res://scripts/encounters/features/captains/captain_feature.gd")
const DIRECTOR := preload("res://scripts/encounters/encounter_beat_director.gd")
const ENCOUNTER_CONFIG := preload("res://scripts/encounters/encounter_config.gd")

var errors: Array = []
# Скрипт-ошибка внутри проверки обрывает её функцию молча, поэтому сюита считает
# дошедшие до конца проверки: пропущенная проверка не может прочитаться как pass.
var completed := 0


class FakePlayer extends Node2D:
	pass


class FakeEnemy extends CharacterBody2D:
	signal died(enemy: Node2D)
	var health := 10.0
	var move_speed := 100.0
	var contact_damage := 2.0
	var projectile_damage := 3.0
	var reward_xp := 7
	var reward_money := 5


class FakeGame extends Node2D:
	var current_player: Node2D
	var ARENA_CENTER := Vector2.ZERO
	var hud_layer: CanvasLayer = null
	var current_node_seed := 91
	var current_combat_type := "battle"
	var boss_combat_active := false
	var pending_event_combat := {}
	var round_time_left := 60.0

	func node_aspect_rng(node_seed: int, salt: int) -> RandomNumberGenerator:
		var rng := RandomNumberGenerator.new()
		rng.seed = (node_seed ^ salt) & 0x7FFFFFFFFFFFFFFF
		return rng


func _initialize() -> void:
	_check_catalog_contract()
	await _check_lifecycle_boundaries()
	await _check_isolated_director_load()
	CATALOG._reset_for_tests()
	if completed != 3:
		errors.append("all three captain checks must run to completion (%d/3)" % completed)
	if not errors.is_empty():
		for error in errors:
			push_error("captain-contract: %s" % str(error))
		quit(1)
		return
	print("FAN-1451 captain contract test passed.")
	quit(0)


func _check_catalog_contract() -> void:
	CATALOG._reset_for_tests()
	var catalog := CATALOG.catalog()
	_expect(int(catalog.get("schema_version", 0)) == 1, "catalog schema must be v1")
	_expect(str(catalog.get("contract", "")) == "captain-wave-roles-v1", "captain contract must be separate")
	_expect(not CATALOG.is_enabled(), "captain pack must remain default-off")
	var roles := CATALOG.all_roles()
	_expect(roles.size() == 2, "catalog must expose exactly Commander and Hunter")
	_expect(str(roles[0].get("id", "")) == "captain_commander", "roles must be sorted by stable captain id")
	_expect(str(roles[1].get("id", "")) == "captain_hunter", "Hunter id must be stable")
	_expect(CATALOG.compatible_roles(["normal_battle", "deck:swarm"]).size() == 2,
		"normal deck tags must admit both roles")
	_expect(CATALOG.compatible_roles(["normal_battle", "deck:unknown"]).is_empty(),
		"unknown decks must opt in explicitly")
	_expect(CATALOG.compatible_roles(["normal_battle", "deck:swarm", "route_elite"]).is_empty(),
		"route elite tags must exclude captains")
	for role in roles:
		_expect(bool(role.get("primary", false)), "each captain must occupy the one primary slot")
		_expect(str(role.get("reward_contract", "")) == "normal_enemy_unchanged",
			"captains must not alter boss/elite reward contracts")
		_expect(str(role.get("priority_contract", "")) != "" \
			and not (role.get("counterplay_tags", []) as Array).is_empty(),
			"each captain must publish readable priority and counterplay tags")
	completed += 1


func _check_lifecycle_boundaries() -> void:
	var fixture := await _fixture()
	var context = fixture["context"]
	var commander = FEATURE.new()
	var commander_def := CATALOG.role("captain_commander")
	CATALOG.set_enabled_override(true)
	_expect(commander.is_eligible(context), "enabled pack must admit a normal battle")
	_expect(not commander.plan(context, commander_def).is_empty(), "normal battle must plan a captain")
	var xp_before: int = fixture["enemy"].reward_xp
	var gold_before: int = fixture["enemy"].reward_money
	_expect(commander.on_trigger(context, commander_def), "first captain must start")
	_expect(fixture["enemy"].is_in_group("captain_enemies"), "captain must use its own group")
	_expect(str(fixture["enemy"].get_meta("captain_lifecycle", "")) == "normal_wave_captain",
		"captain must expose its own lifecycle contract")
	_expect(commander.debug_marker().name == "CaptainRoleMarker" \
		and commander.debug_marker().process_mode == Node.PROCESS_MODE_PAUSABLE,
		"captain presentation must be separate and pause-aware")
	_expect(commander.debug_hud_label().name == "CaptainHudLabel" \
		and commander.debug_hud_label().process_mode == Node.PROCESS_MODE_PAUSABLE,
		"captain HUD must remain separate from boss/elite HUD contracts")
	_expect(not fixture["enemy"].is_in_group("elite_enemies") and not fixture["enemy"].is_in_group("bosses"),
		"captain lifecycle must stay outside elite/boss groups")
	_expect(fixture["enemy"].reward_xp == xp_before and fixture["enemy"].reward_money == gold_before,
		"captain activation must preserve normal rewards")
	var second = FEATURE.new()
	_expect(not second.on_trigger(context, CATALOG.role("captain_hunter")),
		"a normal battle must never own a second live captain")
	var outcome: Dictionary = commander.resolve(context, "combat_end")
	_expect(str(outcome.get("beat_id", "")) == "captain_commander", "outcome must keep captain-specific id")
	_expect(str(outcome.get("reward_contract", "")) == "normal_enemy_unchanged",
		"outcome must expose the separate unchanged-reward contract")
	_expect(not fixture["enemy"].is_in_group("captain_enemies"), "resolve must release the captain slot")
	context.boss_active = true
	_expect(not FEATURE.new().is_eligible(context), "boss battle must reject captain roles")
	context.boss_active = false
	context.combat_type = "elite"
	_expect(not FEATURE.new().is_eligible(context), "major elite battle must reject captain roles")
	fixture["game"].queue_free()
	fixture["presentation"].queue_free()
	await process_frame
	completed += 1


func _check_isolated_director_load() -> void:
	var fixture := await _fixture()
	CATALOG.set_enabled_override(true)
	var hunter_def := CATALOG.role("captain_hunter")
	# Регрессия FAN-2040: реальная запись captain-wave-roles-v1 обязана пройти
	# валидацию EncounterFeature-реестра, а не исчезнуть из него молча.
	var validated: Array = ENCOUNTER_CONFIG._validated_feature_definitions_for_tests([hunter_def])
	_expect(validated.size() == 1 and str(validated[0].get("id", "")) == "captain_hunter",
		"the real captain pack must survive EncounterFeature registry validation")
	var malformed := hunter_def.duplicate(true)
	malformed["capabilities"] = ["unknown_capability"]
	_expect(ENCOUNTER_CONFIG._validated_feature_definitions_for_tests([malformed]).is_empty(),
		"a malformed captain definition must still fail closed")
	ENCOUNTER_CONFIG._set_catalog_for_tests({
		"schema_version": ENCOUNTER_CONFIG.CONTRACT_VERSION,
		"contract": ENCOUNTER_CONFIG.CONTRACT,
		"enabled": false,
		"feature_roots": [],
		"beats": [hunter_def],
	})
	_expect(ENCOUNTER_CONFIG.feature_ids() == ["captain_hunter"],
		"all_features() must expose the registered captain role")
	_expect(ENCOUNTER_CONFIG.enabled_features().size() == 1,
		"enabled_features() must keep the registered captain role")
	_expect(ENCOUNTER_CONFIG.primary_beats().map(func(entry): return str(entry.get("id", ""))) \
		== ["captain_hunter"], "primary_beats() must offer the registered captain role")
	var director = DIRECTOR.new()
	fixture["game"].add_child(director)
	director.setup(fixture["game"], null)
	director.set_process(false)
	director.begin()
	_expect(director.state() == "planned" and director.planned_beat_id() == "captain_hunter",
		"injected catalog must load the isolated pack through EncounterFeature API v1")
	director.shutdown(true)
	ENCOUNTER_CONFIG._reset_cache_for_tests()
	_expect(not ENCOUNTER_CONFIG.is_enabled(), "production encounter catalog must remain default-off")
	CATALOG.clear_enabled_override()
	# Per-role enabled=true — это registry-запись, а не активация: боевой гейт
	# пакета остаётся pack-level default-off.
	_expect(not CATALOG.is_enabled(), "registered captain roles must keep the pack default-off")
	fixture["game"].queue_free()
	fixture["presentation"].queue_free()
	await process_frame
	completed += 1


func _fixture() -> Dictionary:
	var game := FakeGame.new()
	var player := FakePlayer.new()
	game.current_player = player
	game.add_child(player)
	var hud_layer := CanvasLayer.new()
	var hud_root := Control.new()
	hud_root.name = "CombatHudRoot"
	hud_layer.add_child(hud_root)
	game.add_child(hud_layer)
	game.hud_layer = hud_layer
	var enemy := FakeEnemy.new()
	enemy.add_to_group("enemies")
	enemy.global_position = Vector2(80.0, 0.0)
	game.add_child(enemy)
	var presentation := Node2D.new()
	root.add_child(game)
	root.add_child(presentation)
	await process_frame
	var context = CONTEXT.new()
	context.game = game
	context.node_seed = 91
	context.combat_type = "battle"
	context.round_duration = 60.0
	context.presentation_parent = presentation
	return {"game": game, "player": player, "enemy": enemy, "presentation": presentation, "context": context}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
