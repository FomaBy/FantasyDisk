extends SceneTree

const CONTEXT := preload("res://scripts/encounters/encounter_context.gd")
const FEATURE := preload("res://scripts/encounters/features/early_clear/early_clear_feature.gd")
const DIRECTOR := preload("res://scripts/encounters/encounter_beat_director.gd")
const CONFIG := preload("res://scripts/encounters/encounter_config.gd")
const METRICS := preload("res://scripts/encounters/encounter_metrics.gd")

var errors: Array = []
# Скрипт-ошибка внутри проверки обрывает её функцию молча, поэтому сюита считает
# дошедшие до конца проверки: пропущенная проверка не может прочитаться как pass.
var completed := 0


class FakePlayer extends Node2D:
	var xp := 0
	var gold := 0

	func gain_xp(amount: int) -> void:
		xp += amount

	func gain_money(amount: int) -> void:
		gold += amount


class FakeEnemy extends Node2D:
	signal died(enemy: Node2D)

	func defeat() -> void:
		died.emit(self)


class FakeCombat extends Node:
	var end_calls := 0
	var victory := false
	var director: Node = null

	func _end_combat(value: bool) -> void:
		end_calls += 1
		victory = value
		if director != null:
			director.shutdown(value)


class FakeGame extends Node2D:
	var current_node_seed := 77
	var current_combat_type := "battle"
	var boss_combat_active := false
	var pending_event_combat := {}
	var current_player: Node2D
	var run_metrics := {"kills": 0}
	var round_time_left := 60.0

	func node_aspect_rng(node_seed: int, salt: int) -> RandomNumberGenerator:
		var generator := RandomNumberGenerator.new()
		generator.seed = (node_seed ^ salt) & 0x7FFFFFFFFFFFFFFF
		return generator


func _initialize() -> void:
	await _check_early_clear_once()
	await _check_timer_survival_fallback()
	await _check_director_metrics()
	_check_non_normal_contract()
	if completed != 4:
		errors.append("all four lifecycle checks must run to completion (%d/4)" % completed)
	if not errors.is_empty():
		for error in errors:
			push_error("early-clear-feature: %s" % str(error))
		quit(1)
		return
	print("FAN-1454 early-clear feature lifecycle test passed.")
	quit(0)


func _new_context() -> Dictionary:
	var game := FakeGame.new()
	var player := FakePlayer.new()
	game.current_player = player
	game.add_child(player)
	var captain := FakeEnemy.new()
	captain.add_to_group("enemies")
	game.add_child(captain)
	var combat := FakeCombat.new()
	root.add_child(game)
	root.add_child(combat)
	await process_frame
	var context = CONTEXT.new()
	context.game = game
	# Consumer contract: фича читает боевой терминал только через context.combat.
	context.combat = combat
	context.combat_type = "battle"
	context.round_duration = 60.0
	context.elapsed = 0.0
	return {"game": game, "player": player, "captain": captain, "combat": combat, "context": context}


func _check_early_clear_once() -> void:
	var fixture: Dictionary = await _new_context()
	var feature = FEATURE.new()
	var context = fixture["context"]
	_expect(not feature.plan(context, {}).is_empty(), "normal battle must plan early clear")
	_expect(feature.on_trigger(context, {}), "normal battle must select a mandatory captain")
	fixture["game"].run_metrics["kills"] = 12
	fixture["captain"].defeat()
	context.elapsed = 30.0
	feature.on_tick(context, 0.1)
	feature.on_tick(context, 0.1)
	await process_frame
	_expect(fixture["combat"].end_calls == 1 and fixture["combat"].victory,
		"ready objective must request the native victory path exactly once")
	_expect(fixture["player"].xp == 12 and fixture["player"].gold == 8,
		"only capped performance rewards may be added to earned base rewards")
	var outcome: Dictionary = feature.resolve(context, "combat_end")
	_expect(str(outcome.get("reason", "")) == "early_clear", "early request must report early_clear")
	fixture["game"].queue_free()
	fixture["combat"].queue_free()
	await process_frame
	completed += 1


func _check_timer_survival_fallback() -> void:
	var fixture: Dictionary = await _new_context()
	var feature = FEATURE.new()
	var context = fixture["context"]
	feature.plan(context, {})
	feature.on_trigger(context, {})
	fixture["game"].run_metrics["kills"] = 12
	context.elapsed = 30.0
	fixture["game"].set("round_time_left", 0.0)
	feature.on_tick(context, 0.1)
	var outcome: Dictionary = feature.resolve(context, "combat_end")
	_expect(fixture["combat"].end_calls == 0, "timer fallback must not request a second combat end")
	_expect(str(outcome.get("reason", "")) == "timer_survival", "timer survival must remain a victory fallback")
	_expect(fixture["player"].xp == 0 and fixture["player"].gold == 0,
		"timer survival must not deduct or replace base rewards")
	fixture["game"].queue_free()
	fixture["combat"].queue_free()
	await process_frame
	completed += 1


func _check_director_metrics() -> void:
	CONFIG._set_catalog_for_tests({
		"schema_version": CONFIG.CONTRACT_VERSION,
		"contract": CONFIG.CONTRACT,
		"enabled": false,
		"feature_roots": [],
		"beats": [{
			"schema_version": CONFIG.CONTRACT_VERSION,
			"id": "normal_early_clear",
			"type": CONFIG.FEATURE_TYPE,
			"enabled": true,
			"primary": true,
			"capabilities": ["primary_beat"],
			"script": "res://scripts/encounters/features/early_clear/early_clear_feature.gd",
		}],
	})
	METRICS.last_summary = {}
	var fixture: Dictionary = await _new_context()
	var director = DIRECTOR.new()
	fixture["game"].add_child(director)
	director.setup(fixture["game"], fixture["combat"])
	director.set_process(false)
	fixture["combat"].director = director
	director.begin()
	_expect(director.state() == "planned", "isolated catalog must plan the early-clear pack")
	director._process(30.0)
	fixture["game"].run_metrics["kills"] = 12
	fixture["captain"].defeat()
	director._process(0.1)
	await process_frame
	_expect(fixture["combat"].end_calls == 1, "director must forward exactly one deferred combat end")
	# Регрессия FAN-2040: директор обязан прокинуть боевой узел в context.combat,
	# иначе early-clear никогда не доходит до нативного _end_combat(true).
	_expect(fixture["combat"].victory, "director-wired context.combat must reach the native victory path")
	var records: Array = METRICS.last_summary.get("records", [])
	_expect(records.size() == 1 and str(records[0].get("reason", "")) == "early_clear",
		"director shutdown must record the early-clear outcome exactly once")
	fixture["game"].queue_free()
	fixture["combat"].queue_free()
	CONFIG._reset_cache_for_tests()
	_expect(not CONFIG.is_enabled(), "production encounter catalog must remain default-off")
	await process_frame
	completed += 1


func _check_non_normal_contract() -> void:
	var feature = FEATURE.new()
	var context = CONTEXT.new()
	context.combat_type = "elite"
	_expect(not feature.is_eligible(context), "elite contract must remain outside early clear")
	context.combat_type = "battle"
	context.boss_active = true
	_expect(not feature.is_eligible(context), "boss contract must remain outside early clear")
	completed += 1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
