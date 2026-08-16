extends SceneTree
## FAN-1452 focused runtime contract: checkpoint before risk, retry persistence,
## default-off discovery, capped depth reward and failure without a reward.

const CONFIG := preload("res://scripts/encounters/encounter_config.gd")
const CONTEXT := preload("res://scripts/encounters/encounter_context.gd")
const DIRECTOR := preload("res://scripts/encounters/encounter_beat_director.gd")
const FEATURE := preload("res://scripts/encounters/features/contracts/next_phase_contract_feature.gd")
const LEDGER := preload("res://scripts/encounters/features/contracts/contract_reward_ledger.gd")

var errors: Array[String] = []
var completed := 0


class FakePlayer extends Node2D:
	var xp := 0
	var gold := 0

	func gain_xp(amount: int) -> void:
		xp += amount

	func gain_money(amount: int) -> void:
		gold += amount


class FakeGame extends Node2D:
	var current_act := 1
	var encounter_feature_state := {}
	var current_combat_type := "battle"
	var boss_combat_active := false
	var pending_event_combat := {}
	var current_player: Node2D = null
	var hud_layer: CanvasLayer = null
	var current_node_seed := 77
	var round_time_left := 60.0
	var ARENA_CENTER := Vector2.ZERO
	var save_calls := 0
	var persist_ok := true

	func save_run_autosave(_reason := "") -> bool:
		save_calls += 1
		return persist_ok

	func node_aspect_rng(node_seed: int, salt: int) -> RandomNumberGenerator:
		var rng := RandomNumberGenerator.new()
		rng.seed = (node_seed ^ salt) & 0x7FFFFFFFFFFFFFFF
		return rng


func _initialize() -> void:
	_check_default_off_manifest_and_reward_curve()
	await _check_decline_is_safe()
	await _check_retry_preserves_armed_risk_and_claims_once()
	await _check_failure_is_persisted_without_reward()
	await _check_director_runtime_path()
	_check_non_normal_exclusions()
	if completed != 6:
		errors.append("all six contract checks must run (%d/6)" % completed)
	if not errors.is_empty():
		for error in errors:
			push_error("contract-feature: " + error)
		quit(1)
		return
	print("FAN-1452 encounter contract feature lifecycle passed.")
	quit(0)


func _check_default_off_manifest_and_reward_curve() -> void:
	CONFIG._reset_cache_for_tests()
	CONFIG.clear_enabled_override()
	var entries: Array = CONFIG.all_features().filter(func(entry): return str(entry.get("id", "")) == "next_phase_contract")
	_expect(entries.size() == 1 and not bool(entries[0].get("enabled", true)),
		"one contract-local manifest must be discovered default-off")
	_expect(bool(entries[0].get("primary", false)) and (entries[0].get("capabilities", []) as Array).has("act_state"),
		"manifest must declare the primary and act-state contract without shared registry edits")
	var settings := LEDGER.settings(_definition())
	var shallow := LEDGER.reward_for_stage(settings, 0)
	var deep := LEDGER.reward_for_stage(settings, 99)
	_expect(int(shallow["xp"]) == 4 and int(shallow["gold"]) == 5,
		"visible shallow reward must start from the manifest values")
	_expect(int(deep["xp"]) == 12 and int(deep["gold"]) == 12 and bool(deep["capped"]),
		"reward must grow by depth and stop at its explicit cap")
	completed += 1


func _check_decline_is_safe() -> void:
	var fixture := await _fixture(2)
	var feature := FEATURE.new()
	_expect(not feature.plan(fixture["context"], _definition()).is_empty(), "normal battle must plan the first offer")
	_expect(feature.on_trigger(fixture["context"], _definition()), "first eligible battle must show the offer")
	var offer: Control = feature.debug_offer()
	_expect(offer != null, "offer UI must exist before a decision")
	if offer != null:
		offer.debug_decline()
	await process_frame
	var state: Dictionary = fixture["context"].act_feature_state("next_phase_contract")
	_expect(str(state.get("decision", "")) == "declined" and str(state.get("risk", "")) == "" \
			and fixture["player"].xp == 0 and fixture["player"].gold == 0,
		"decline must checkpoint no risk and no reward")
	_expect(feature.is_resolved(), "safe decline must resolve the feature")
	feature.resolve(fixture["context"], "resolved")
	await _free_fixture(fixture)
	completed += 1


func _check_retry_preserves_armed_risk_and_claims_once() -> void:
	var fixture := await _fixture(3)
	var first := FEATURE.new()
	first.plan(fixture["context"], _definition())
	_expect(first.on_trigger(fixture["context"], _definition()), "offer must start before contract risk")
	var offer: Control = first.debug_offer()
	if offer != null:
		offer.debug_accept()
	await process_frame
	var armed: Dictionary = fixture["context"].act_feature_state("next_phase_contract")
	_expect(str(armed.get("decision", "")) == "accepted" and str(armed.get("risk", "")) == "armed" \
			and first.debug_risk_enemies().size() > 0,
		"accept must persist armed risk before the phase begins")
	first.resolve(fixture["context"], "combat_end")
	await process_frame

	var retry := FEATURE.new()
	_expect(retry.is_eligible(fixture["context"]), "retry must remain eligible only to finish the armed risk")
	_expect(retry.on_trigger(fixture["context"], _definition()) and retry.debug_offer() == null,
		"retry must resume risk directly and never present a second offer")
	for enemy in retry.debug_risk_enemies():
		enemy.emit_signal("died", enemy)
	await process_frame
	var succeeded: Dictionary = fixture["context"].act_feature_state("next_phase_contract")
	_expect(str(succeeded.get("risk", "")) == "succeeded" and int(succeeded.get("claim_count", 0)) == 1,
		"clearing every marked enemy must persist success and the one claim")
	_expect(fixture["player"].xp == 10 and fixture["player"].gold == 11,
		"stage-three reward must be depth-aware and paid exactly once")
	for enemy in retry.debug_risk_enemies():
		enemy.emit_signal("died", enemy)
	_expect(fixture["player"].xp == 10 and fixture["player"].gold == 11,
		"duplicate death signals cannot duplicate the reward")
	_expect(not FEATURE.new().is_eligible(fixture["context"]), "claimed success cannot be retried for a second reward")
	retry.resolve(fixture["context"], "resolved")
	await _free_fixture(fixture)
	completed += 1


func _check_failure_is_persisted_without_reward() -> void:
	var fixture := await _fixture(1)
	var feature := FEATURE.new()
	feature.plan(fixture["context"], _definition())
	feature.on_trigger(fixture["context"], _definition())
	var offer: Control = feature.debug_offer()
	if offer != null:
		offer.debug_accept()
	await process_frame
	var enemies := feature.debug_risk_enemies()
	_expect(not enemies.is_empty(), "accepted contract must create a concrete risk phase")
	if not enemies.is_empty():
		enemies[0].queue_free()
		await process_frame
		feature.on_tick(fixture["context"], 0.1)
	var state: Dictionary = fixture["context"].act_feature_state("next_phase_contract")
	var outcome: Dictionary = feature.resolve(fixture["context"], "resolved")
	_expect(str(state.get("risk", "")) == "failed" and fixture["player"].xp == 0 and fixture["player"].gold == 0,
		"lost risk must persist failure and never pay a reward")
	_expect(str(outcome.get("status", "")) == FEATURE.STATUS_FAILED and str(outcome.get("reason", "")) == "risk_interrupted",
		"failure outcome must remain machine-checkable")
	await _free_fixture(fixture)
	completed += 1


func _check_director_runtime_path() -> void:
	CONFIG._set_catalog_for_tests({
		"schema_version": CONFIG.CONTRACT_VERSION,
		"contract": CONFIG.CONTRACT,
		"enabled": false,
		"feature_roots": [],
		"beats": [_definition()],
	})
	var fixture := await _fixture(2)
	var director := DIRECTOR.new()
	fixture["game"].add_child(director)
	director.setup(fixture["game"], null)
	director.set_process(false)
	director.begin()
	_expect(director.state() == "planned" and director.planned_beat_id() == "next_phase_contract",
		"local manifest definition must run through the unmodified primary director")
	director._process(0.01)
	var offer: Control = director.debug_feature().debug_offer()
	_expect(offer != null, "director trigger must present the contract before risk")
	if offer != null:
		offer.debug_decline()
	director._process(0.01)
	_expect(director.state() == "done", "safe decline must complete the director lifecycle")
	director.shutdown(true)
	CONFIG._reset_cache_for_tests()
	await _free_fixture(fixture)
	completed += 1


func _check_non_normal_exclusions() -> void:
	var feature := FEATURE.new()
	var context := CONTEXT.new()
	context.combat_type = "elite"
	_expect(not feature.is_eligible(context), "elite encounters must stay excluded")
	context.combat_type = "battle"
	context.boss_active = true
	_expect(not feature.is_eligible(context), "boss encounters must stay excluded")
	context.boss_active = false
	context.event_active = true
	_expect(not feature.is_eligible(context), "event encounters must stay excluded")
	completed += 1


func _fixture(stage: int) -> Dictionary:
	var game := FakeGame.new()
	game.encounter_feature_state = CONFIG.empty_act_state(game.current_act)
	var player := FakePlayer.new()
	game.current_player = player
	game.add_child(player)
	var hud := CanvasLayer.new()
	var hud_root := Control.new()
	hud_root.name = "CombatHudRoot"
	hud.add_child(hud_root)
	game.hud_layer = hud
	game.add_child(hud)
	root.add_child(game)
	await process_frame
	var context := CONTEXT.new()
	context.game = game
	context.combat_type = "battle"
	context.route_scaling_stage = stage
	return {"game": game, "player": player, "context": context}


func _free_fixture(fixture: Dictionary) -> void:
	(fixture["game"] as Node).queue_free()
	await process_frame


func _definition() -> Dictionary:
	return {
		"schema_version": CONFIG.CONTRACT_VERSION,
		"id": "next_phase_contract",
		"type": CONFIG.FEATURE_TYPE,
		"enabled": true,
		"primary": true,
		"capabilities": ["primary_beat", "act_state"],
		"script": "res://scripts/encounters/features/contracts/next_phase_contract_feature.gd",
		"payload": {
			"timeout_seconds": 12.0,
			"risk_multiplier": 1.35,
			"risk_base_enemies": 2,
			"risk_max_enemies": 5,
			"reward": {"base_xp": 4, "base_gold": 5, "per_stage": 2, "xp_cap": 12, "gold_cap": 12},
		},
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
