extends SceneTree
## FAN-1450 — seeded normal-wave deck selection and shared plan projection.

const CONFIG := preload("res://scripts/encounters/encounter_config.gd")
const CONTEXT := preload("res://scripts/encounters/encounter_context.gd")
const DIRECTOR := preload("res://scripts/encounters/encounter_beat_director.gd")
const ADAPTER := preload("res://scripts/encounters/encounter_adapter.gd")
const ROUTE := preload("res://scripts/route_map_screen.gd")
const FEATURE := preload("res://scripts/encounters/features/decks/deck_feature.gd")
const CHARACTERS := preload("res://scripts/progression_data_characters.gd")

const ENEMY := "res://scenes/Enemy.tscn"
const BITER := "res://scenes/EnemyBiter.tscn"
const SHIELD := "res://scenes/EnemyShield.tscn"
const SHOOTER := "res://scenes/EnemyShooter.tscn"
const MAGE := "res://scenes/EnemyMage.tscn"
const SUMMONER := "res://scenes/EnemySummoner.tscn"
const RUNNER := "res://scenes/EnemyRunner.tscn"
const FLYING_RUNNER := "res://scenes/EnemyFlyingRunner.tscn"
const DECK_IDS := ["swarm", "shield_wall", "shooter_crossfire", "summoner_siege", "runner_hunt"]

var errors: Array[String] = []


class FakeCombat extends RefCounted:
	var received: Dictionary = {}

	func spawn_encounter_plan(plan: Dictionary) -> int:
		received = plan.duplicate(true)
		return int(plan.get("total_count", 0))


class FakeGame extends Node2D:
	var current_node_seed := 1
	var current_combat_type := "battle"
	var pending_event_combat := {}
	var boss_combat_active := false
	var round_time_left := 60.0
	var current_act := 1
	var current_player: Node2D = null
	var hud_layer: CanvasLayer = null
	var ARENA_CENTER := Vector2(960, 540)
	var ENEMY_SPAWN_WEIGHTS := {
		ENEMY: 1.0, BITER: 1.0, SHIELD: 1.0, SHOOTER: 1.0, MAGE: 1.0,
		SUMMONER: 1.0, RUNNER: 1.0, FLYING_RUNNER: 1.0,
	}
	var WAVE_SETTINGS := {"max_active_cap": 12}
	var ACT_COUNT := 2
	var ACT_SCALING_STAGE_OFFSET := 8
	var stage := 2

	func node_aspect_rng(node_seed: int, salt: int) -> RandomNumberGenerator:
		var rng := RandomNumberGenerator.new()
		rng.seed = (node_seed ^ salt) & 0x7FFFFFFFFFFFFFFF
		return rng

	func route_scaling_stage() -> int:
		return stage


func _initialize() -> void:
	_check_default_off_discovery()
	_check_seeded_decks_and_budgets()
	await _check_canonical_execution_and_hint()
	CONFIG.clear_enabled_override()
	CONFIG._reset_cache_for_tests()
	if not errors.is_empty():
		for error in errors:
			push_error("deck-feature: " + error)
		quit(1)
		return
	print("FAN-1450 seeded deck feature contract passed.")
	quit(0)


func _deck_definition() -> Dictionary:
	for entry in CONFIG.all_features():
		if str(entry.get("id", "")) == "normal_decks":
			return entry
	return {}


func _check_default_off_discovery() -> void:
	CONFIG.clear_enabled_override()
	CONFIG._reset_cache_for_tests()
	var definition := _deck_definition()
	_expect(not CONFIG.is_enabled(), "the encounter package must remain default-off")
	_expect(not definition.is_empty(), "decks must be discovered from their isolated feature root")
	_expect(not bool(definition.get("primary", true)) and definition.get("capabilities", []) == ["spawn_plan"],
		"decks must only use the sanctioned spawn-plan capability")
	_expect(str(definition.get("script", "")) == "res://scripts/encounters/features/decks/deck_feature.gd",
		"decks must stay inside the owned script path")


func _check_seeded_decks_and_budgets() -> void:
	var definition := _deck_definition()
	var feature := FEATURE.new()
	var game := FakeGame.new()
	var all_classes: Array = CHARACTERS.CHARACTER_CONFIGS.keys()
	all_classes.sort()
	_expect(all_classes.size() == 17, "the current class matrix must contain 17 classes")
	var supported: Array = definition.get("supported_class_ids", []).duplicate()
	supported.sort()
	_expect(supported == all_classes, "the deck pack must admit the full 17-class matrix")
	for stage in [0, 1, 2]:
		var seen := {}
		for seed_value in range(1, 257):
			var context: Variant = _context(game, seed_value, stage)
			var plan: Dictionary = feature.build_spawn_plan(context, definition)
			_expect(not plan.is_empty(), "stage %d must always select an eligible deck" % stage)
			_expect(plan == feature.build_spawn_plan(_context(game, seed_value, stage), definition),
				"same node seed must reproduce deck and mandatory role")
			_check_plan_contract(plan, stage, game)
			seen[str(plan.get("deck_id", ""))] = true
		if stage == 0:
			_expect(seen.keys().all(func(deck_id): return deck_id in ["swarm", "shield_wall", "runner_hunt"]),
				"stage 0 must exclude later shooter and summoner spikes")
		if stage == 1:
			_expect(seen.has("shooter_crossfire") and not seen.has("summoner_siege"),
				"stage 1 must admit crossfire but keep summoner siege locked")
		if stage == 2:
			_expect(seen.keys().size() == DECK_IDS.size() and DECK_IDS.all(func(deck_id): return seen.has(deck_id)),
				"stage 2 must expose all five tactical decks")
	game.free()


func _check_plan_contract(plan: Dictionary, stage: int, game: FakeGame) -> void:
	_expect(str(plan.get("deck_id", "")) in DECK_IDS, "deck id must be stable")
	_expect(str(plan.get("mandatory_role", "")) != "", "every deck must name a mandatory role")
	_expect(int(plan.get("role_weight", 0)) > 0, "every deck must have a positive deterministic role weight")
	_expect(stage >= int(plan.get("min_stage", 0)) and stage <= int(plan.get("max_stage", -1)),
		"selected deck must respect its stage eligibility")
	_expect(plan.get("class_profiles", []) == ["melee", "ranged", "summon"],
		"no melee, ranged, or summon playstyle may be structurally excluded")
	var total := 0
	var mandatory_present := false
	for entry in plan.get("entries", []):
		total += int(entry.get("count", 0))
		var scene := str(entry.get("scene", ""))
		mandatory_present = mandatory_present or scene == str(plan.get("mandatory_scene", ""))
		_expect(game.ENEMY_SPAWN_WEIGHTS.has(scene), "deck scene must remain in the normal enemy pool")
		_expect(not scene.contains("Boss") and not scene.contains("Elite"), "decks must not touch boss or elite pools")
	_expect(mandatory_present, "selected deck must contain its mandatory role")
	_expect(total <= int(plan.get("active_cap", 0)) and total <= 7,
		"per-deck count must stay within its anti-spike active cap")
	_expect(float(plan.get("safe_radius", 0.0)) >= CONTEXT.MIN_SAFE_RADIUS \
		and float(plan.get("safe_radius", 0.0)) <= CONTEXT.MAX_SAFE_RADIUS,
		"deck safe radius must stay inside the canonical safety bounds")


func _check_canonical_execution_and_hint() -> void:
	CONFIG.set_enabled_override(true)
	var game := FakeGame.new()
	game.current_node_seed = 17
	var combat := FakeCombat.new()
	root.add_child(game)
	var director := DIRECTOR.new()
	game.add_child(director)
	director.setup(game, combat)
	director.set_process(false)
	director.begin()
	var live_plan: Dictionary = director.spawn_plan_projection()
	var route_plan: Dictionary = ADAPTER.project_spawn_plan(game, game.current_node_seed, game.stage, "battle")
	_expect(not live_plan.is_empty() and live_plan == route_plan,
		"combat and route must project the same canonical deck plan")

	var execution_context: Variant = _context(game, game.current_node_seed, game.stage, Callable(combat, "spawn_encounter_plan"))
	var request: Dictionary = FEATURE.new().build_spawn_plan(execution_context, _deck_definition())
	var canonical: Dictionary = execution_context.canonical_spawn_plan(request, "normal_decks")
	execution_context.set_spawn_plan(canonical)
	_expect(execution_context.execute_spawn_plan() == int(canonical.get("total_count", 0)) and combat.received == canonical,
		"combat execution must receive the canonical deck plan unchanged")

	var route := ROUTE.new(game)
	var hint: String = route._wave_threat_hint({"type": "battle", "row": game.stage}, game.current_node_seed)
	_expect(hint.contains(route._enemy_archetype_name(str(live_plan.get("threat_scene", "")))),
		"route hint must render the threat from the same canonical deck plan")
	director.shutdown(true)
	route = null
	execution_context = null
	director = null
	combat = null
	game.queue_free()
	await process_frame
	await process_frame


func _context(game: FakeGame, seed_value: int, stage: int, executor := Callable()):
	var context := CONTEXT.new()
	context.game = game
	context.node_seed = seed_value
	context.combat_type = "battle"
	context.route_scaling_stage = stage
	context.configure_spawn_capability(game.ENEMY_SPAWN_WEIGHTS.keys(), 12, executor)
	return context


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
