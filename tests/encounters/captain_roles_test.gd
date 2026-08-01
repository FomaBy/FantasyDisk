extends SceneTree

const CATALOG := preload("res://scripts/encounters/features/captains/captain_catalog.gd")
const CONTEXT := preload("res://scripts/encounters/encounter_context.gd")
const FEATURE := preload("res://scripts/encounters/features/captains/captain_feature.gd")

var errors: Array = []


class FakePlayer extends CharacterBody2D:
	var health := 10.0
	func take_damage(amount: float, _source = "") -> void: health -= amount


class FakeEnemy extends CharacterBody2D:
	signal died(enemy: Node2D)
	var health := 10.0
	var move_speed := 100.0
	var contact_damage := 2.0
	var projectile_damage := 3.0
	func defeat() -> void: died.emit(self)
	func _physics_process(_delta: float) -> void: pass


class FakeGame extends Node2D:
	var current_player: Node2D
	var ARENA_CENTER := Vector2.ZERO
	var hud_layer: CanvasLayer = null
	func node_aspect_rng(node_seed: int, salt: int) -> RandomNumberGenerator:
		var rng := RandomNumberGenerator.new()
		rng.seed = (node_seed ^ salt) & 0x7FFFFFFFFFFFFFFF
		return rng


class TickRunner extends Node:
	var feature
	var context
	func _process(delta: float) -> void:
		feature.on_tick(context, delta)


func _initialize() -> void:
	CATALOG.set_enabled_override(true)
	await _check_commander_ownership_and_death_cleanup()
	await _check_hunter_fair_phases_resist_pause_and_cleanup()
	CATALOG._reset_for_tests()
	if not errors.is_empty():
		for error in errors:
			push_error("captain-roles: %s" % str(error))
		quit(1)
		return
	print("FAN-1451 captain roles test passed.")
	quit(0)


func _check_commander_ownership_and_death_cleanup() -> void:
	var fixture := await _fixture([
		Vector2(60.0, 0.0), Vector2(90.0, 0.0), Vector2(120.0, 0.0), Vector2(900.0, 0.0),
	])
	var feature = FEATURE.new()
	var commander_def := CATALOG.role("captain_commander")
	_expect(feature.on_trigger(fixture["context"], commander_def), "Commander must trigger")
	var captain: FakeEnemy = feature.debug_captain()
	var retinue: Array = feature.debug_retinue()
	_expect(retinue.size() == 2, "Commander must bind only nearby living retinue")
	for enemy in retinue:
		_expect(int(enemy.get_meta("captain_aura_owner", 0)) == captain.get_instance_id(),
			"each aura member must name its Commander owner")
		_expect(is_equal_approx(enemy.move_speed, 118.0), "aura must buff bound retinue movement")
		_expect(is_equal_approx(enemy.contact_damage, 2.24), "aura must buff bound retinue threat")
	var outsider: FakeEnemy = fixture["enemies"][3]
	_expect(not outsider.has_meta("captain_aura_owner"), "unbound enemies must never receive the aura")
	var newcomer := FakeEnemy.new()
	newcomer.add_to_group("enemies")
	newcomer.global_position = Vector2(70.0, 20.0)
	fixture["game"].add_child(newcomer)
	feature.on_tick(fixture["context"], 0.1)
	_expect(not newcomer.has_meta("captain_aura_owner"), "new wave members must not join the bound retinue")
	captain.defeat()
	_expect(feature.is_resolved(), "Commander death must resolve the role")
	for enemy in retinue:
		_expect(not enemy.has_meta("captain_aura_owner"), "Commander death must remove owned aura immediately")
		_expect(is_equal_approx(enemy.move_speed, 100.0), "Commander death must restore movement")
		_expect(is_equal_approx(enemy.contact_damage, 2.0), "Commander death must restore damage")
	var outcome: Dictionary = feature.resolve(fixture["context"], "resolved")
	_expect(str(outcome.get("status", "")) == "completed" and str(outcome.get("reason", "")) == "captain_killed",
		"Commander kill must produce a captain-specific completed outcome")
	_expect(feature.debug_marker() == null, "resolve must release Commander presentation")
	await _cleanup_fixture(fixture)


func _check_hunter_fair_phases_resist_pause_and_cleanup() -> void:
	var fixture := await _fixture([Vector2.ZERO])
	var player: FakePlayer = fixture["player"]
	player.global_position = Vector2(300.0, 0.0)
	player.set_meta("captain_pursuit_resist", 0.5)
	var feature = FEATURE.new()
	var hunter_def := CATALOG.role("captain_hunter")
	_expect(feature.on_trigger(fixture["context"], hunter_def), "Hunter must trigger")
	var hunter: FakeEnemy = feature.debug_captain()
	_expect(feature.debug_phase() == "lock", "Hunter must start with readable lock")
	_expect(not hunter.is_physics_processing(), "Hunter native chase must pause while the fair sequence owns motion")
	feature.on_tick(fixture["context"], 0.66)
	_expect(feature.debug_phase() == "windup", "lock must be followed by windup")
	_expect(feature.debug_locked_target().is_equal_approx(Vector2(300.0, 0.0)), "windup must freeze the announced target")
	player.global_position = Vector2(300.0, 200.0)
	feature.on_tick(fixture["context"], 0.81)
	_expect(feature.debug_phase() == "pursuit", "windup must be followed by pursuit")
	feature.on_tick(fixture["context"], 0.1)
	_expect(hunter.global_position.is_equal_approx(Vector2(21.0, 0.0)),
		"50% target resist must halve pursuit speed toward the locked route point")

	var runner := TickRunner.new()
	runner.feature = feature
	runner.context = fixture["context"]
	runner.process_mode = Node.PROCESS_MODE_PAUSABLE
	root.add_child(runner)
	var time_before := feature.debug_active_time()
	paused = true
	await create_timer(0.08, true).timeout
	paused = false
	_expect(is_equal_approx(feature.debug_active_time(), time_before), "pause must freeze captain lifecycle time")
	runner.set_process(false)
	runner.queue_free()

	player.global_position = Vector2(2000.0, 0.0)
	feature.on_tick(fixture["context"], 0.01)
	_expect(feature.debug_phase() == "recovery" and feature.debug_disengaged(),
		"distance fail-safe must cancel pursuit into recovery")
	var marker := feature.debug_marker()
	var outcome: Dictionary = feature.resolve(fixture["context"], "combat_end")
	_expect(str(outcome.get("status", "")) == "failed", "living Hunter at combat end must fail cleanly")
	_expect(hunter.is_physics_processing(), "cleanup must restore native Hunter physics")
	_expect(not hunter.is_in_group("captain_enemies") and not hunter.has_meta("captain_role"),
		"cleanup must release captain identity")
	_expect(marker.is_queued_for_deletion(), "cleanup must queue temporary presentation for deletion")
	await _cleanup_fixture(fixture)


func _fixture(enemy_positions: Array) -> Dictionary:
	var game := FakeGame.new()
	var player := FakePlayer.new()
	game.current_player = player
	game.add_child(player)
	var enemies: Array = []
	for position in enemy_positions:
		var enemy := FakeEnemy.new()
		enemy.add_to_group("enemies")
		enemy.global_position = position
		game.add_child(enemy)
		enemies.append(enemy)
	var presentation := Node2D.new()
	root.add_child(game)
	root.add_child(presentation)
	await process_frame
	var context = CONTEXT.new()
	context.game = game
	context.node_seed = 123
	context.combat_type = "battle"
	context.round_duration = 60.0
	context.presentation_parent = presentation
	return {"game": game, "player": player, "enemies": enemies, "presentation": presentation, "context": context}


func _cleanup_fixture(fixture: Dictionary) -> void:
	fixture["game"].queue_free()
	fixture["presentation"].queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
