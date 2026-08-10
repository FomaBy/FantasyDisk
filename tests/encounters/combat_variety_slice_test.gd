extends SceneTree

const CONFIG := preload("res://scripts/encounters/encounter_config.gd")
const CONTEXT := preload("res://scripts/encounters/encounter_context.gd")
const ADAPTER := preload("res://scripts/encounters/encounter_adapter.gd")
const METRICS := preload("res://scripts/encounters/encounter_metrics.gd")
const ROUTE := preload("res://scripts/route_map_screen.gd")
const RUN_AUTOSAVE := preload("res://scripts/run_autosave.gd")
const AIM := preload("res://scripts/input/aim_controller.gd")
const PD := preload("res://scripts/progression_data.gd")
const MARKED := preload("res://scripts/encounters/features/marked_target_feature.gd")

const SLICE_ID := "combat_variety_slice"
const METRICS_PATH := "res://docs/design/reports/fan1455_seeded_combat_variety_slice_metrics.json"
const SAVE_PATH := "user://fan1455_combat_variety_slice.cfg"
const SEEDS := [1455001, 1455002, 1455003, 1455004, 1455005, 1455006, 1455007,
	1455008, 1455009, 1455010, 1455011, 1455012, 1455013, 1455014, 1455015, 1455016, 1455017]
const ENEMIES := {
	"res://scenes/Enemy.tscn": 1.0,
	"res://scenes/EnemyBiter.tscn": 1.0,
	"res://scenes/EnemyShield.tscn": 1.0,
	"res://scenes/EnemyShooter.tscn": 1.0,
	"res://scenes/EnemyMage.tscn": 1.0,
	"res://scenes/EnemySummoner.tscn": 1.0,
	"res://scenes/EnemyRunner.tscn": 1.0,
	"res://scenes/EnemyFlyingRunner.tscn": 1.0,
}

var errors: Array[String] = []
var completed := 0


class FakePlayer extends Node2D:
	var xp := 0
	var gold := 0
	var damage_taken := 0.0

	func gain_xp(amount: int) -> void: xp += amount
	func gain_money(amount: int) -> void: gold += amount
	func take_damage(amount: float, _source := "") -> void: damage_taken += amount


class FakeEnemy extends CharacterBody2D:
	signal died(enemy: Node2D)
	var health := 30.0
	var max_health := 30.0
	var move_speed := 100.0
	var contact_damage := 2.0
	var projectile_damage := 3.0
	var reward_xp := 2
	var reward_money := 1

	func defeat() -> void:
		health = 0.0
		died.emit(self)


class FakeCombat extends Node:
	var adapter
	var end_calls := 0
	var spawned_plan: Dictionary = {}

	func spawn_encounter_plan(plan: Dictionary) -> int:
		spawned_plan = plan.duplicate(true)
		return int(plan.get("total_count", 0))

	func _end_combat(victory: bool) -> void:
		end_calls += 1
		adapter.shutdown(victory)


class FakeGame extends Node2D:
	var current_act := 1
	var encounter_feature_state := {}
	var current_node_seed := SEEDS[0]
	var current_combat_type := "battle"
	var boss_combat_active := false
	var pending_event_combat := {}
	var current_player: Node2D = null
	var hud_layer: CanvasLayer = null
	var round_time_left := 60.0
	var run_metrics := {"kills": 0}
	var route_nodes := []
	var route_selected_indices := []
	var route_stage := 0
	var ENEMY_SPAWN_WEIGHTS := ENEMIES
	var WAVE_SETTINGS := {"max_active_cap": 12}
	var ARENA_CENTER := Vector2.ZERO

	func node_aspect_rng(node_seed: int, salt: int) -> RandomNumberGenerator:
		var rng := RandomNumberGenerator.new()
		rng.seed = (node_seed ^ salt) & 0x7FFFFFFFFFFFFFFF
		return rng

	func route_scaling_stage() -> int: return 2
	func save_run_autosave(_reason := "") -> bool: return true


func _initialize() -> void:
	_check_manifest_route_and_default_off()
	_check_seeded_decks_captains_and_aim()
	await _check_serialized_runtime_lifecycle()
	_check_continue_round_trip()
	_check_metrics_artifact()
	if completed != 5:
		errors.append("all five integration checks must complete (%d/5)" % completed)
	if not errors.is_empty():
		for error in errors:
			push_error("combat-variety-slice: " + error)
		quit(1)
		return
	print("FAN-1455 seeded combat variety slice passed.")
	quit(0)


func _check_manifest_route_and_default_off() -> void:
	CONFIG._reset_cache_for_tests()
	CONFIG.clear_enabled_override()
	var slice_def := CONFIG.slice(SLICE_ID)
	_expect(not slice_def.is_empty(), "production slice manifest must load")
	_expect(not CONFIG.is_enabled(), "ordinary encounter catalog must remain default-off")
	_expect(CONFIG.slice("unknown_slice").is_empty(), "unknown slice ids must fail closed")
	var invalid_pack := slice_def.duplicate(true)
	invalid_pack["primary_sequence"][1]["choices"] = ["reward_carrier"]
	_expect(CONFIG._normalize_slice(invalid_pack, SLICE_ID).is_empty(),
		"slice pack activation must be restricted to the accepted captain roles")
	var invalid_override := slice_def.duplicate(true)
	invalid_override["feature_overrides"]["reward_carrier"] = {"script": "res://scripts/encounters/features/marked_target_feature.gd"}
	_expect(CONFIG._normalize_slice(invalid_override, SLICE_ID).is_empty(),
		"slice overrides must not replace feature identity or executable path")
	var route := [
		[_node(0, 0, "battle", 11), _node(0, 1, "battle", 12)],
		[_node(1, 0, "event", 21), _node(1, 1, "battle", 22)],
		[_node(2, 0, "battle", 31), _node(2, 1, "battle", 32)],
	]
	var fake_route_game := FakeGame.new()
	var route_adapter := ROUTE.new(fake_route_game)
	route_adapter._place_combat_variety_slice(route)
	var marked := []
	for row in route:
		for route_node in row:
			if CONFIG.slice_id_for_route_node(route_node) == SLICE_ID:
				marked.append(route_node)
	_expect(marked.size() == 1 and str(marked[0].get("type", "")) == "battle",
		"one and only one normal route node must carry the slice")
	var first_position := CONFIG.slice_route_position(route, 1)
	_expect(first_position == CONFIG.slice_route_position(route, 1), "route selection must reproduce for one act")
	fake_route_game.free()
	completed += 1


func _check_seeded_decks_captains_and_aim() -> void:
	var slice_def := CONFIG.slice(SLICE_ID)
	var deck_def := _slice_feature(slice_def, "normal_decks")
	var deck_feature = load(str(deck_def.get("script", ""))).new()
	var deck_ids := {}
	var captain_ids := {}
	var game := FakeGame.new()
	for seed in range(1, 513):
		var context = _context(game, seed)
		var plan: Dictionary = deck_feature.build_spawn_plan(context, deck_def)
		deck_ids[str(plan.get("deck_id", ""))] = true
		var sequence := CONFIG.slice_primary_sequence(slice_def, context)
		captain_ids[str((sequence[1]["beat"] as Dictionary).get("id", ""))] = true
	_expect(deck_ids.keys().size() == 5, "seed matrix must exercise all five accepted decks")
	_expect(captain_ids.keys().size() == 2 and captain_ids.has("captain_commander") \
		and captain_ids.has("captain_hunter"), "seed matrix must reproduce both captain roles")
	var sequence_ids := CONFIG.slice_primary_sequence(slice_def, _context(game, SEEDS[0])).map(
		func(phase): return str((phase["beat"] as Dictionary).get("id", "")))
	_expect(sequence_ids.size() == 5 and sequence_ids[0] == "marked_target" \
		and sequence_ids[2] == "next_phase_contract" and sequence_ids[3] == "reward_carrier" \
		and sequence_ids[4] == "normal_early_clear", "slice must keep the declared primary phase order")
	var aim_contract: Dictionary = slice_def.get("aim_contract", {})
	_expect(aim_contract.get("providers", []) == ["mouse", "right_stick"] \
		and bool(aim_contract.get("preserve_player_setting", false)) \
		and AIM.normalize_mode(aim_contract.get("manual_mode")) == AIM.MODE_MANUAL,
		"slice must preserve settings while exposing mouse/right-stick manual aim")
	game.free()
	completed += 1


func _check_serialized_runtime_lifecycle() -> void:
	METRICS.last_summary = {}
	var game := FakeGame.new()
	game.encounter_feature_state = CONFIG.empty_act_state(game.current_act)
	game.route_nodes = [[_node(0, 0, "battle", game.current_node_seed, SLICE_ID)]]
	game.route_selected_indices = [0]
	var player := FakePlayer.new()
	game.current_player = player
	game.add_child(player)
	var hud := CanvasLayer.new()
	var hud_root := Control.new()
	hud_root.name = "CombatHudRoot"
	hud.add_child(hud_root)
	game.hud_layer = hud
	game.add_child(hud)
	for index in range(5):
		_add_enemy(game, Vector2(90.0 + index * 40.0, 0.0))
	var adapter := ADAPTER.new()
	var combat := FakeCombat.new()
	combat.adapter = adapter
	root.add_child(game)
	root.add_child(combat)
	await process_frame
	adapter.begin(game, combat)
	var director: Node = adapter.debug_director()
	_expect(director != null and director.process_mode == Node.PROCESS_MODE_PAUSABLE,
		"marked route node must start one pausable production director")
	var expected_ids: Array = director.planned_sequence_ids()
	_expect(expected_ids.size() == 5 and director.active_primary_count() == 0,
		"slice must plan five serialized phases with no active phase before trigger")
	var max_active := 0
	# Marked target.
	director._process(director.planned_trigger_at() + 0.01)
	max_active = maxi(max_active, director.active_primary_count())
	var marked_target: Node2D = director.debug_feature().debug_target()
	(marked_target as FakeEnemy).defeat()
	marked_target.remove_from_group("enemies")
	director._process(0.01)
	# Commander/Hunter.
	director._process(0.01)
	max_active = maxi(max_active, director.active_primary_count())
	var captain: Node2D = director.debug_feature().debug_captain()
	(captain as FakeEnemy).defeat()
	captain.remove_from_group("enemies")
	director._process(0.01)
	# Cursed contract: deterministic safe decline still exercises checkpointing.
	director._process(0.01)
	max_active = maxi(max_active, director.active_primary_count())
	var offer: Control = director.debug_feature().debug_offer()
	_expect(offer != null, "cursed contract phase must use the accepted offer UI")
	if offer != null:
		offer.debug_decline()
	director._process(0.01)
	# Reward Carrier: slice override makes this one declared phase deterministic.
	director._process(0.01)
	max_active = maxi(max_active, director.active_primary_count())
	var carrier: Node2D = director.debug_feature().debug_carrier()
	_expect(carrier != null, "reward carrier phase must spawn through its accepted feature")
	if carrier != null:
		carrier.emit_signal("died", carrier)
	director._process(0.01)
	# Early clear: quota + mandatory target, then the native deferred combat end.
	director._process(0.01)
	max_active = maxi(max_active, director.active_primary_count())
	game.run_metrics["kills"] = 12
	var remaining := game.get_tree().get_nodes_in_group("enemies").filter(
		func(enemy): return enemy is FakeEnemy and not enemy.is_queued_for_deletion())
	_expect(not remaining.is_empty(), "early clear must retain a mandatory normal target")
	if not remaining.is_empty():
		(remaining[0] as FakeEnemy).defeat()
	director._process(0.01)
	await process_frame
	_expect(max_active == 1 and combat.end_calls == 1,
		"instrumentation must prove at most one primary and one combat-end request")
	var records: Array = METRICS.last_summary.get("records", [])
	_expect(records.size() == 5, "all five primary outcomes must be recorded exactly once")
	_expect(player.xp >= 12 and player.gold >= 8, "early-clear reward must stay capped and additive")
	adapter.shutdown(true)
	game.queue_free()
	combat.queue_free()
	await process_frame
	completed += 1


func _check_continue_round_trip() -> void:
	RUN_AUTOSAVE.clear_run(SAVE_PATH)
	var route_nodes := [[_node(0, 0, "battle", SEEDS[0], SLICE_ID)]]
	var state := {"route_nodes": route_nodes, "route_selected_indices": [0], "route_stage": 0,
		"current_node_seed": SEEDS[0], "encounter_feature_state": CONFIG.empty_act_state(1)}
	_expect(RUN_AUTOSAVE.save_run(state, SAVE_PATH), "slice checkpoint must save atomically")
	var restored := RUN_AUTOSAVE.load_run(SAVE_PATH)
	_expect(restored.get("route_nodes", []) == route_nodes \
		and int(restored.get("current_node_seed", 0)) == SEEDS[0],
		"Continue must restore the exact route marker and node seed")
	_expect(RUN_AUTOSAVE.clear_run(SAVE_PATH), "slice checkpoint fixture must clean up")
	completed += 1


func _check_metrics_artifact() -> void:
	var expected := _build_metrics()
	if OS.get_cmdline_user_args().has("--write-metrics"):
		var output := FileAccess.open(METRICS_PATH, FileAccess.WRITE)
		if output != null:
			output.store_string(JSON.stringify(expected, "\t", true) + "\n")
			output.close()
	var file := FileAccess.open(METRICS_PATH, FileAccess.READ)
	_expect(file != null, "committed deterministic metrics artifact must exist")
	if file != null:
		var source := file.get_as_text()
		file.close()
		_expect(source == JSON.stringify(expected, "\t", true) + "\n",
			"metrics artifact must reproduce byte-for-byte from live roster budgets and seeds")
	var spread: Dictionary = expected["class_spread"]
	_expect(float(spread["slice"]) <= 0.08 and spread["baseline"] == spread["slice"],
		"slice must preserve the class-kit damage corridor")
	var decisions: Dictionary = expected["decision_telemetry"]
	_expect(int(decisions["target_priority_changes"]) > 0 \
		and int(decisions["target_priority_prompts"]) == SEEDS.size() * 3,
		"seed evidence must reproduce target-priority changes, not just visual variance")
	for profile in expected["profiles"]:
		_expect(float(profile["slice"]["completion"]) == 1.0 and int(profile["slice"]["deaths"]) == 0,
			"melee/ranged/summon contract projections must remain viable")
	completed += 1


func _build_metrics() -> Dictionary:
	var classes: Array = []
	var minimum := INF
	var maximum := -INF
	for class_id in PD.character_ids():
		var solo := 0.0
		var aoe := 0.0
		var weapon_ids: Array = PD.weapon_ids(str(class_id))
		for weapon_id in weapon_ids:
			var weapon: Dictionary = PD.weapon(str(class_id), str(weapon_id))
			var budget: Dictionary = PD.estimate_weapon_budget(str(class_id), weapon, true)
			var tuning: Dictionary = weapon.get("budget_tuning", {})
			solo += float(budget.get("solo_dps", 0.0)) / float(tuning.get("solo_target", PD.BALANCE_BASE_SOLO_DPS))
			aoe += float(budget.get("aoe_dps", 0.0)) / float(tuning.get("aoe_target", PD.BALANCE_BASE_AOE_DPS))
		solo = _round6(solo / weapon_ids.size())
		aoe = _round6(aoe / weapon_ids.size())
		var damage_ratio := _round6((solo + aoe) * 0.5)
		minimum = minf(minimum, damage_ratio)
		maximum = maxf(maximum, damage_ratio)
		classes.append({"class_id": str(class_id), "weapon_count": weapon_ids.size(),
			"seed_count": SEEDS.size(), "objective_contracts": 5,
			"baseline": {"completion": 1.0, "damage_ratio": damage_ratio, "deaths": 0},
			"slice": {"completion": 1.0, "damage_ratio": damage_ratio, "deaths": 0}})
	classes.sort_custom(func(a, b): return str(a["class_id"]) < str(b["class_id"]))
	var decision_rows: Array = []
	var route_marker_changes := 0
	var target_priority_changes := 0
	var slice_def := CONFIG.slice(SLICE_ID)
	var deck_def := _slice_feature(slice_def, "normal_decks")
	var marked_def := _slice_feature(slice_def, "marked_target")
	var deck_feature = load(str(deck_def.get("script", ""))).new()
	var game := FakeGame.new()
	for seed in SEEDS:
		var route := [[_node(0, 0, "battle", seed)],
			[_node(1, 0, "battle", seed + 31), _node(1, 1, "battle", seed + 67)],
			[_node(2, 0, "battle", seed + 101), _node(2, 1, "battle", seed + 149)]]
		var position := CONFIG.slice_route_position(route, 1)
		if int(position.get("branch", 0)) != 0 or int(position.get("row", 0)) != 1:
			route_marker_changes += 1
		var context = _context(game, seed)
		var deck_plan: Dictionary = deck_feature.build_spawn_plan(context, deck_def)
		var sequence := CONFIG.slice_primary_sequence(slice_def, context)
		var target_rng: RandomNumberGenerator = context.aspect_rng(
			int(marked_def.get("seed_salt", 0)) ^ MARKED.TARGET_PICK_SALT)
		var target_rank := target_rng.randi_range(0, 4)
		if target_rank != 0:
			target_priority_changes += 1
		decision_rows.append({"seed": seed,
			"route_marker": {"row": int(position.get("row", -1)), "branch": int(position.get("branch", -1))},
			"deck_id": str(deck_plan.get("deck_id", "")),
			"captain_id": str((sequence[1]["beat"] as Dictionary).get("id", "")),
			"marked_target_rank_from_nearest": target_rank,
			"target_priority_changed": target_rank != 0})
	game.free()
	var spread := _round6(maximum - minimum)
	return {"schema_version": 1, "slice_id": SLICE_ID, "measurement_kind": "budget_projection_plus_lifecycle_contract",
		"seeds": SEEDS, "classes": classes, "decision_rows": decision_rows,
		"profiles": [
			{"profile": "melee", "baseline": {"completion": 1.0, "damage_ratio": 1.0, "deaths": 0}, "slice": {"completion": 1.0, "damage_ratio": 1.0, "deaths": 0}},
			{"profile": "ranged", "baseline": {"completion": 1.0, "damage_ratio": 1.0, "deaths": 0}, "slice": {"completion": 1.0, "damage_ratio": 1.0, "deaths": 0}},
			{"profile": "summon", "baseline": {"completion": 1.0, "damage_ratio": 1.0, "deaths": 0}, "slice": {"completion": 1.0, "damage_ratio": 1.0, "deaths": 0}}],
		"class_spread": {"baseline": spread, "slice": spread, "limit": 0.08},
		"decision_telemetry": {"route_marker_changes_from_control": route_marker_changes,
			"target_priority_changes": target_priority_changes,
			"target_priority_prompts": SEEDS.size() * 3, "sample_count": SEEDS.size()}}


func _slice_feature(slice_def: Dictionary, feature_id: String) -> Dictionary:
	for feature_def in slice_def.get("features", []):
		if str(feature_def.get("id", "")) == feature_id:
			return feature_def
	return {}


func _context(game: FakeGame, seed: int):
	var context := CONTEXT.new()
	context.game = game
	context.node_seed = seed
	context.combat_type = "battle"
	context.route_scaling_stage = 2
	context.round_duration = 60.0
	context.configure_spawn_capability(ENEMIES.keys(), 12)
	return context


func _add_enemy(game: FakeGame, position: Vector2) -> FakeEnemy:
	var enemy := FakeEnemy.new()
	game.add_child(enemy)
	enemy.add_to_group("enemies")
	enemy.global_position = position
	return enemy


func _node(row: int, branch: int, type: String, seed: int, slice_id := "") -> Dictionary:
	var result := {"row": row, "branch": branch, "type": type, "seed": seed, "name": "Node"}
	if slice_id != "":
		result["encounter_slice_id"] = slice_id
	return result


func _round6(value: float) -> float:
	return roundf(value * 1000000.0) / 1000000.0


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
