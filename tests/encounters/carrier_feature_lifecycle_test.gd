extends SceneTree

const CONFIG := preload("res://scripts/encounters/encounter_config.gd")
const CONTEXT := preload("res://scripts/encounters/encounter_context.gd")
const DIRECTOR := preload("res://scripts/encounters/encounter_beat_director.gd")
const FEATURE := preload("res://scripts/encounters/features/reward_carrier/reward_carrier_feature.gd")
const TARGET_QUERY := preload("res://scripts/combat_target_query.gd")

var errors: Array[String] = []
var completed := 0


class FakePlayer extends Node2D:
	var xp := 0
	var money := 0

	func gain_xp(amount: int) -> void:
		xp += amount

	func gain_money(amount: int) -> void:
		money += amount


class FakeGame extends Node2D:
	var current_player: Node2D
	var current_node_seed := 771
	var current_combat_type := "battle"
	var boss_combat_active := false
	var pending_event_combat := {}
	var round_time_left := 60.0
	var ARENA_CENTER := Vector2.ZERO

	func node_aspect_rng(node_seed: int, salt: int) -> RandomNumberGenerator:
		var rng := RandomNumberGenerator.new()
		rng.seed = (node_seed ^ salt) & 0x7FFFFFFFFFFFFFFF
		return rng


func _initialize() -> void:
	_check_registry_default_off()
	await _check_reward_and_quota_contract()
	await _check_failure_and_determinism()
	await _check_director_runtime()
	if completed != 4:
		errors.append("all four carrier checks must run (%d/4)" % completed)
	if not errors.is_empty():
		for error in errors:
			push_error("reward-carrier: " + error)
		quit(1)
		return
	print("FAN-1453 reward carrier lifecycle passed.")
	quit(0)


func _check_registry_default_off() -> void:
	CONFIG._reset_cache_for_tests()
	CONFIG.clear_enabled_override()
	var carrier := CONFIG.all_features().filter(func(entry): return str(entry.get("id", "")) == "reward_carrier")
	_expect(carrier.size() == 1 and not bool(carrier[0].get("enabled", true)),
		"production registry must discover exactly one explicitly disabled carrier")
	_expect(not CONFIG.is_enabled(), "encounter package must stay default-off")
	var malformed: Dictionary = carrier[0].duplicate(true) if carrier.size() == 1 else {}
	if not malformed.is_empty():
		malformed["payload"]["reward_xp"] = 999
		var feature = FEATURE.new()
		var context = CONTEXT.new()
		context.combat_type = "battle"
		context.round_duration = 60.0
		context.game = _new_game()
		_expect(feature.plan(context, malformed).is_empty() and not feature.on_trigger(context, malformed),
			"malformed reward config must fail closed before spawning")
		context.game.queue_free()
	completed += 1


func _check_reward_and_quota_contract() -> void:
	var fixture := await _fixture()
	var feature = FEATURE.new()
	var plan := feature.plan(fixture["context"], _definition())
	_expect(not plan.is_empty(), "normal battle must deterministically plan a carrier")
	_expect(feature.on_trigger(fixture["context"], _definition()), "normal battle must spawn a carrier")
	var carrier := feature.debug_carrier()
	_expect(carrier != null and TARGET_QUERY.enemies(fixture["game"]).has(carrier),
		"carrier must remain on ordinary target queries")
	_expect(CONTEXT.wave_quota_count(fixture["game"].get_tree().get_nodes_in_group("enemies")) == 0,
		"carrier must not consume the normal wave quota")
	var before := carrier.global_position
	feature.on_tick(fixture["context"], 0.5)
	_expect(carrier.global_position.distance_to(fixture["player"].global_position) > before.distance_to(fixture["player"].global_position),
		"carrier must flee from the player")
	carrier.died.emit(carrier)
	carrier.died.emit(carrier)
	var outcome := feature.resolve(fixture["context"], "combat_end")
	_expect(fixture["player"].xp == 8 and fixture["player"].money == 6,
		"confirmed defeat must transfer the capped reward exactly once")
	_expect(str(outcome.get("status", "")) == FEATURE.STATUS_COMPLETED and bool(outcome.get("reward_transferred", false)),
		"confirmed defeat must remain completed through interruption cleanup")
	await _free_fixture(fixture)
	completed += 1


func _check_failure_and_determinism() -> void:
	var first := await _fixture()
	var second := await _fixture()
	var first_feature = FEATURE.new()
	var second_feature = FEATURE.new()
	var definition := _definition()
	_expect(first_feature.plan(first["context"], definition) == second_feature.plan(second["context"], definition),
		"same seed must reproduce the carrier trigger")
	_expect(first_feature.on_trigger(first["context"], definition), "failure fixture must spawn carrier")
	var lost := first_feature.debug_carrier()
	lost.queue_free()
	await process_frame
	first_feature.on_tick(first["context"], 0.1)
	var lost_outcome := first_feature.resolve(first["context"], "combat_end")
	_expect(first["player"].xp == 0 and first["player"].money == 0 and str(lost_outcome.get("reason", "")) == "carrier_lost",
		"despawn without confirmed defeat must not grant a reward")
	var escape := await _fixture()
	var escape_feature = FEATURE.new()
	_expect(escape_feature.on_trigger(escape["context"], definition), "escape fixture must spawn carrier")
	escape_feature.on_tick(escape["context"], 10.0)
	var escape_outcome := escape_feature.resolve(escape["context"], "combat_end")
	_expect(escape["player"].xp == 0 and escape["player"].money == 0 and str(escape_outcome.get("reason", "")) == "carrier_escaped",
		"escape must fail closed without a reward")
	first["context"].combat_type = "elite"
	_expect(not FEATURE.new().is_eligible(first["context"]), "elite pools must remain excluded")
	first["context"].combat_type = "battle"
	first["context"].boss_active = true
	_expect(not FEATURE.new().is_eligible(first["context"]), "boss pools must remain excluded")
	first["context"].boss_active = false
	first["context"].event_active = true
	_expect(not FEATURE.new().is_eligible(first["context"]), "event pools must remain excluded")
	await _free_fixture(first)
	await _free_fixture(second)
	await _free_fixture(escape)
	completed += 1


func _check_director_runtime() -> void:
	CONFIG._set_catalog_for_tests({
		"schema_version": CONFIG.CONTRACT_VERSION,
		"contract": CONFIG.CONTRACT,
		"enabled": false,
		"feature_roots": [],
		"beats": [_definition()],
	})
	var fixture := await _fixture()
	var director = DIRECTOR.new()
	fixture["game"].add_child(director)
	director.setup(fixture["game"], null)
	director.set_process(false)
	director.begin()
	_expect(director.state() == "planned" and director.planned_beat_id() == "reward_carrier",
		"an explicitly registered carrier must plan through the live director")
	director._process(60.0)
	var carrier: Node2D = director.debug_feature().debug_carrier()
	_expect(carrier != null, "director trigger must create the registered carrier scene")
	if carrier != null:
		carrier.emit_signal("died", carrier)
		director._process(0.1)
	_expect(director.state() == "done" and fixture["player"].xp == 8 and fixture["player"].money == 6,
		"director lifecycle must preserve the one confirmed reward transfer")
	director.shutdown(true)
	CONFIG._reset_cache_for_tests()
	await _free_fixture(fixture)
	completed += 1


func _definition() -> Dictionary:
	return {
		"schema_version": CONFIG.CONTRACT_VERSION,
		"id": "reward_carrier",
		"type": CONFIG.FEATURE_TYPE,
		"enabled": true,
		"primary": true,
		"capabilities": ["primary_beat", "quota_exclusion"],
		"script": "res://scripts/encounters/features/reward_carrier/reward_carrier_feature.gd",
		"trigger_window": {"min_seconds": 18.0, "max_seconds": 32.0},
		"duration_seconds": 10.0,
		"seed_salt": 982451653,
		"spawn_chance": 1.0,
		"payload": {"safe_radius": 680.0, "flee_speed": 240.0, "reward_xp": 8, "reward_money": 6},
	}


func _fixture() -> Dictionary:
	var game := _new_game()
	root.add_child(game)
	await process_frame
	var context = CONTEXT.new()
	context.game = game
	context.node_seed = game.current_node_seed
	context.combat_type = game.current_combat_type
	context.round_duration = game.round_time_left
	return {"game": game, "player": game.current_player, "context": context}


func _new_game() -> FakeGame:
	var game := FakeGame.new()
	var player := FakePlayer.new()
	game.current_player = player
	game.add_child(player)
	return game


func _free_fixture(fixture: Dictionary) -> void:
	fixture["game"].queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
