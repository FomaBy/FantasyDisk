extends SceneTree

const CONFIG := preload("res://scripts/encounters/encounter_config.gd")
const CONTEXT := preload("res://scripts/encounters/encounter_context.gd")
const DIRECTOR := preload("res://scripts/encounters/encounter_beat_director.gd")
const ADAPTER := preload("res://scripts/encounters/encounter_adapter.gd")
const COMBAT_DIRECTOR := preload("res://scripts/combat_director.gd")
const ROUTE := preload("res://scripts/route_map_screen.gd")
const TARGET_QUERY := preload("res://scripts/combat_target_query.gd")

const ENEMY := "res://scenes/Enemy.tscn"
const SHOOTER := "res://scenes/EnemyShooter.tscn"
const BRUISER := "res://scenes/EnemyBruiser.tscn"

var errors: Array[String] = []


class FakeCombat extends RefCounted:
	var received: Dictionary = {}

	func spawn_encounter_plan(plan: Dictionary) -> int:
		received = plan.duplicate(true)
		return int(plan.get("total_count", 0))


class FakeProgression extends RefCounted:
	func stage_scale(_stage: int) -> float:
		return 1.0


class FakeGame extends Node2D:
	var current_node_seed := 4242
	var current_combat_type := "battle"
	var pending_event_combat := {}
	var boss_combat_active := false
	var round_time_left := 60.0
	var current_act := 1
	var current_player: Node2D = null
	var hud_layer: CanvasLayer = null
	var ARENA_CENTER := Vector2(960, 540)
	var ENEMY_SPAWN_WEIGHTS := {ENEMY: 1.0, SHOOTER: 1.0, BRUISER: 1.0}
	var WAVE_SETTINGS := {"max_active_cap": 12, "base_active_cap": 8, "active_cap_per_stage": 0, "active_cap_per_wave_step": 0}
	var PROGRESSION_DATA := FakeProgression.new()
	var spawn_wave_index := 0
	var route_stage := 0
	var ACT_COUNT := 2
	var ACT_SCALING_STAGE_OFFSET := 8
	var stage := 3

	func node_aspect_rng(node_seed: int, salt: int) -> RandomNumberGenerator:
		var generator := RandomNumberGenerator.new()
		generator.seed = (node_seed ^ salt) & 0x7FFFFFFFFFFFFFFF
		return generator

	func route_scaling_stage() -> int:
		return stage


class FakeEnemy extends Node2D:
	var health := 10.0

	func take_damage(amount: float) -> void:
		health -= amount


func _initialize() -> void:
	CONFIG.set_enabled_override(true)
	CONFIG._set_catalog_for_tests(_spawn_catalog())
	await _check_plan_parity()
	await _check_full_capacity_guard()
	await _check_quota_contract()
	CONFIG.clear_enabled_override()
	CONFIG._reset_cache_for_tests()
	if not errors.is_empty():
		for error in errors:
			push_error("encounter-plan-quota: " + error)
		quit(1)
		return
	print("FAN-2022 spawn-plan parity and quota contract passed.")
	quit(0)


func _spawn_catalog() -> Dictionary:
	return {
		"schema_version": CONFIG.CONTRACT_VERSION,
		"contract": CONFIG.CONTRACT,
		"enabled": false,
		"feature_roots": [],
		"beats": [{
			"schema_version": CONFIG.CONTRACT_VERSION,
			"id": "marked_target",
			"type": CONFIG.FEATURE_TYPE,
			"enabled": true,
			"primary": false,
			"capabilities": ["spawn_plan"],
			"script": "res://scripts/encounters/features/marked_target_feature.gd",
			"seed_salt": 918273,
			"spawn_plans": [
				_plan_request([{"scene": ENEMY, "count": 3}, {"scene": SHOOTER, "count": 1}]),
				_plan_request([{"scene": BRUISER, "count": 2}, {"scene": SHOOTER, "count": 3}]),
			],
		}],
	}


func _plan_request(entries: Array) -> Dictionary:
	return {
		"schema_version": CONTEXT.SPAWN_PLAN_SCHEMA_VERSION,
		"min_stage": 0,
		"max_stage": 8,
		"active_cap": 8,
		"safe_radius": CONTEXT.MIN_SAFE_RADIUS,
		"entries": entries,
	}


func _check_plan_parity() -> void:
	var game := FakeGame.new()
	root.add_child(game)
	var combat := FakeCombat.new()
	var director := DIRECTOR.new()
	game.add_child(director)
	director.setup(game, combat)
	director.set_process(false)
	director.begin()
	var live_plan: Dictionary = director.spawn_plan_projection()
	var route_plan: Dictionary = ADAPTER.project_spawn_plan(game, game.current_node_seed, game.stage, "battle")
	_expect(not live_plan.is_empty(), "normal battle must produce an enabled canonical plan")
	_expect(live_plan == route_plan, "combat and route must read the same canonical plan")
	_expect(int(live_plan.get("node_seed", -1)) == game.current_node_seed, "plan must carry the committed node seed")

	var route := ROUTE.new(game)
	var hint: String = route._wave_threat_hint({"type": "battle", "row": game.stage}, game.current_node_seed)
	_expect(hint.contains(route._enemy_archetype_name(str(live_plan.get("threat_scene", "")))),
		"route hint must render the canonical plan threat scene")

	var mutated := route_plan
	mutated["active_cap"] = 999
	_expect(int(director.spawn_plan_projection().get("active_cap", 0)) == 8,
		"route projection must be a read-only deep copy")

	var variants := {}
	for seed_value in range(1, 25):
		var projected := ADAPTER.project_spawn_plan(game, seed_value, game.stage, "battle")
		variants[str(projected.get("entries", []))] = true
	_expect(variants.size() == 2, "node seed must deterministically select both declared plan variants")
	_expect(ADAPTER.project_spawn_plan(game, 7, game.stage, "battle") \
		== ADAPTER.project_spawn_plan(game, 7, game.stage, "battle"), "same seed must reproduce the same plan")
	_expect(ADAPTER.project_spawn_plan(game, 7, game.stage, "boss").is_empty(), "boss projection must fail closed")
	_expect(ADAPTER.project_spawn_plan(game, 7, game.stage, "elite").is_empty(), "elite projection must fail closed")
	_expect(ADAPTER.project_spawn_plan(game, 7, game.stage, "hazard").is_empty(), "event/hazard projection must fail closed")

	var context := CONTEXT.new()
	context.game = game
	context.node_seed = 77
	context.route_scaling_stage = game.stage
	context.configure_spawn_capability(game.ENEMY_SPAWN_WEIGHTS.keys(), 8, Callable(combat, "spawn_encounter_plan"))
	var valid := context.canonical_spawn_plan(_plan_request([{"scene": ENEMY, "count": 2}]), "probe")
	context.set_spawn_plan(valid)
	_expect(context.execute_spawn_plan() == 2 and combat.received == valid,
		"sanctioned executor must receive only the canonical copy")
	var bad_count := _plan_request([{"scene": ENEMY, "count": CONTEXT.MAX_COUNT_PER_ENTRY + 1}])
	var bad_cap := _plan_request([{"scene": ENEMY, "count": 1}]); bad_cap["active_cap"] = 99
	var bad_radius := _plan_request([{"scene": ENEMY, "count": 1}]); bad_radius["safe_radius"] = 419.0
	var bad_stage := _plan_request([{"scene": ENEMY, "count": 1}]); bad_stage["min_stage"] = game.stage + 1
	for invalid in [bad_count, bad_cap, bad_radius, bad_stage]:
		_expect(context.canonical_spawn_plan(invalid, "probe").is_empty(),
			"out-of-contract count/cap/radius/stage must fail closed")
	director.shutdown(true)
	route = null
	director = null
	combat = null
	game.queue_free()
	await process_frame
	await process_frame


func _check_full_capacity_guard() -> void:
	var game := FakeGame.new()
	root.add_child(game)
	var combat := COMBAT_DIRECTOR.new(game)
	combat._encounters.begin(game, combat)
	var plan: Dictionary = combat._encounters.spawn_plan_projection()
	_expect(not plan.is_empty(), "prepared normal battle must retain its canonical plan")
	var preparation_resolutions := combat._encounters.debug_scene_resolution_count()
	_expect(preparation_resolutions == int(plan.get("entries", []).size()),
		"cold encounter preparation must resolve each plan scene once")
	for _index in range(8):
		var enemy := FakeEnemy.new()
		enemy.add_to_group("enemies")
		game.add_child(enemy)
	await process_frame
	_expect(combat.spawn_encounter_plan(plan) == 0,
		"a full normal-wave cap must preserve the exact zero-spawn quota")
	_expect(combat._encounters.debug_scene_resolution_count() == preparation_resolutions,
		"a full-cap wave must not resolve any scene after preparation")
	combat._encounters.shutdown(true)
	game.queue_free()
	await process_frame


func _check_quota_contract() -> void:
	var host := Node2D.new()
	root.add_child(host)
	var ordinary := FakeEnemy.new()
	var carrier := FakeEnemy.new()
	for enemy in [ordinary, carrier]:
		enemy.add_to_group("enemies")
		host.add_child(enemy)
	await process_frame
	var context := CONTEXT.new()
	context.game = host
	_expect(CONTEXT.wave_quota_count(get_nodes_in_group("enemies")) == 2,
		"unmarked enemies must keep legacy quota counting")
	_expect(context.exclude_from_wave_quota(carrier), "one ordinary carrier may opt out of wave quota")
	_expect(CONTEXT.wave_quota_count(get_nodes_in_group("enemies")) == 1,
		"typed marker must exclude only the carrier from quota")
	_expect(TARGET_QUERY.enemies(host).has(carrier), "quota-excluded carrier must remain targetable")
	carrier.take_damage(3.0)
	_expect(is_equal_approx(carrier.health, 7.0), "quota marker must not alter the normal damage contract")
	_expect(not context.exclude_from_wave_quota(ordinary), "per-context exclusion cap must prevent unbounded bypass")

	var elite := FakeEnemy.new()
	elite.add_to_group("enemies")
	elite.add_to_group("elite_enemies")
	host.add_child(elite)
	_expect(not context.exclude_from_wave_quota(elite), "elite protection must reject quota exclusion")
	elite.set_meta(CONTEXT.WAVE_QUOTA_EXCLUDED_META, true)
	_expect(CONTEXT.counts_toward_wave_quota(elite), "elite must count even with a forged marker")
	ordinary.set_meta(CONTEXT.WAVE_QUOTA_EXCLUDED_META, "true")
	_expect(CONTEXT.counts_toward_wave_quota(ordinary), "non-bool marker must fail closed")
	host.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
