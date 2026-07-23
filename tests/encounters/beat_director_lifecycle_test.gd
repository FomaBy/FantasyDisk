extends SceneTree
## FAN-1447 — жизненный цикл Encounter Beat Director на изолированном fake game.
##
## Прогон:
##   python3 tools/godot_gate.py --headless --path . \
##     --script res://tests/encounters/beat_director_lifecycle_test.gd
##
## Проверяет: ровно один primary-бит; trigger → active c маркером и HUD-таймером;
## успех при убийстве цели; провал при истечении окна; терминальная очистка узлов/
## твинов/колбэков на конце боя (+ death-метрика); заморозку на паузе (PAUSABLE);
## отсутствие бита в не-нормальном бою; локальные метрики.

const DIRECTOR := preload("res://scripts/encounters/encounter_beat_director.gd")
const METRICS := preload("res://scripts/encounters/encounter_metrics.gd")

var errors: Array = []


class FakeEnemy extends Node2D:
	signal died(enemy: Node2D)
	var health := 12.0

	func _init(pos: Vector2) -> void:
		global_position = pos
		add_to_group("enemies")


# Мини-двойник Main: ровно та поверхность, что читают director/context/feature.
class FakeGame extends Node2D:
	var current_node_seed := 0
	var current_combat_type := "battle"
	var boss_combat_active := false
	var pending_event_combat := {}
	var round_time_left := 60.0
	var current_player: Node2D = null
	var hud_layer: CanvasLayer = null

	func node_aspect_rng(node_seed: int, salt: int) -> RandomNumberGenerator:
		var generator := RandomNumberGenerator.new()
		generator.seed = (int(node_seed) ^ int(salt)) & 0x7FFFFFFFFFFFFFFF
		return generator

	func build(host: Node) -> void:
		current_player = Node2D.new()
		current_player.global_position = Vector2(960, 540)
		current_player.add_to_group("player")
		add_child(current_player)
		hud_layer = CanvasLayer.new()
		var root := Control.new()
		root.name = "CombatHudRoot"
		hud_layer.add_child(root)
		add_child(hud_layer)
		host.add_child(self)

	func spawn_enemies(count: int) -> Array:
		var result: Array = []
		for i in range(count):
			var enemy := FakeEnemy.new(Vector2(300 + i * 120, 300 + i * 40))
			add_child(enemy)
			result.append(enemy)
		return result


func _initialize() -> void:
	preload("res://scripts/encounters/encounter_config.gd").set_enabled_override(true)
	await _scenario_completed()
	await _scenario_window_expired()
	await _scenario_combat_end_death()
	await _scenario_non_normal_battle()
	await _scenario_pause_freeze()
	preload("res://scripts/encounters/encounter_config.gd").clear_enabled_override()

	if not errors.is_empty():
		for e in errors:
			push_error("beat-lifecycle: %s" % str(e))
		quit(1)
		return
	print("FAN-1447 beat director lifecycle test passed.")
	quit(0)


func _new_director(game: Node, manual := true) -> Node:
	var director = DIRECTOR.new()
	director.name = "EncounterBeatDirector"
	game.add_child(director)
	director.setup(game, null)
	if manual:
		director.set_process(false)  # шагаем вручную детерминированными дельтами
	director.begin()
	return director


func _scenario_completed() -> void:
	var game := FakeGame.new()
	game.current_node_seed = 4242
	game.build(root)
	var enemies := game.spawn_enemies(3)
	await process_frame

	var director := _new_director(game)
	_expect(director.state() == "planned", "A: exactly one primary beat must be planned")
	_expect(director.planned_beat_id() == "marked_target", "A: planned beat must be marked_target")
	var trig: float = director.planned_trigger_at()
	_expect(trig >= 20.0 and trig <= 48.0, "A: trigger must sit inside the fitted window (got %f)" % trig)

	director._process(trig + 0.05)  # пересечь момент триггера
	_expect(director.state() == "active", "A: beat must be active after trigger")
	var marker := director.find_child("MarkedTargetMarker", true, false)
	_expect(marker != null, "A: world marker must exist while active")
	var hud_root := game.hud_layer.find_child("CombatHudRoot", true, false)
	var hud_label := hud_root.find_child("MarkedTargetHudLabel", true, false) if hud_root != null else null
	_expect(hud_label != null, "A: HUD countdown label must exist while active")

	var feature = director.debug_feature()
	var target: Node2D = feature.debug_target()
	_expect(target != null and enemies.has(target), "A: marked target must be one of the live normal enemies")

	# Убить помеченную цель → completed, урон = стартовый HP.
	target.died.emit(target)
	director._process(0.1)
	_expect(director.state() == "done", "A: beat must resolve after target death")
	var m = director.metrics()
	var counters: Dictionary = m.counters()
	_expect(int(counters.get("offered", 0)) == 1, "A: offered must be 1")
	_expect(int(counters.get("triggered", 0)) == 1, "A: triggered must be 1")
	_expect(int(counters.get("completed", 0)) == 1, "A: completed must be 1")
	var recs: Array = m.records()
	_expect(recs.size() == 1 and str(recs[0].get("status", "")) == "completed", "A: outcome status must be completed")
	_expect(is_equal_approx(float(recs[0].get("damage_to_target", -1.0)), 12.0), "A: damage_to_target must equal start HP")

	await process_frame
	_expect(not is_instance_valid(marker) or marker.is_queued_for_deletion(), "A: marker must be freed on resolve")
	_expect(not is_instance_valid(hud_label) or hud_label.is_queued_for_deletion(), "A: HUD label must be freed on resolve")

	director.shutdown(true)
	game.queue_free()
	await process_frame


func _scenario_window_expired() -> void:
	var game := FakeGame.new()
	game.current_node_seed = 777
	game.build(root)
	game.spawn_enemies(2)
	await process_frame

	var director := _new_director(game)
	director._process(director.planned_trigger_at() + 0.05)
	_expect(director.state() == "active", "B: beat active after trigger")
	# Прожать окно целиком без убийства цели.
	director._process(6.0)
	director._process(6.0)
	_expect(director.state() == "done", "B: beat must resolve when window expires")
	var recs: Array = director.metrics().records()
	_expect(recs.size() == 1 and str(recs[0].get("status", "")) == "failed", "B: expired beat must be failed")
	_expect(str(recs[0].get("reason", "")) == "window_expired", "B: failure reason must be window_expired")
	_expect(int(director.metrics().counters().get("failed", 0)) == 1, "B: failed counter must be 1")

	director.shutdown(true)
	game.queue_free()
	await process_frame


func _scenario_combat_end_death() -> void:
	var game := FakeGame.new()
	game.current_node_seed = 5150
	game.build(root)
	game.spawn_enemies(2)
	await process_frame

	var director := _new_director(game)
	director._process(director.planned_trigger_at() + 0.05)
	_expect(director.state() == "active", "C: beat active before combat end")
	var marker := director.find_child("MarkedTargetMarker", true, false)

	# Смерть игрока → _end_combat(false) → shutdown(false).
	director.shutdown(false)
	_expect(METRICS.last_summary.has("records"), "C: shutdown must snapshot metrics")
	var recs: Array = METRICS.last_summary.get("records", [])
	_expect(recs.size() >= 1, "C: a terminal outcome must be recorded on combat end")
	var last: Dictionary = recs[recs.size() - 1]
	_expect(str(last.get("status", "")) == "failed", "C: unfinished beat at combat end is failed")
	_expect(bool(last.get("player_died", false)), "C: player_died must be recorded on death end")
	_expect(director.is_queued_for_deletion(), "C: director node must be freed on shutdown")

	await process_frame
	_expect(not is_instance_valid(marker) or marker.is_queued_for_deletion(), "C: marker must be freed on combat-end cleanup")
	game.queue_free()
	await process_frame


func _scenario_non_normal_battle() -> void:
	var game := FakeGame.new()
	game.current_node_seed = 4242
	game.current_combat_type = "boss"
	game.boss_combat_active = true
	game.build(root)
	await process_frame

	var director := _new_director(game)
	_expect(director.state() == "done", "D: no beat may be planned in a boss battle")
	_expect(director.planned_beat_id() == "", "D: boss battle must not select a beat")
	director._process(45.0)  # никакого триггера произойти не должно
	_expect(director.find_child("MarkedTargetMarker", true, false) == null, "D: boss battle must not spawn a marker")

	director.shutdown(true)
	game.queue_free()
	await process_frame


func _scenario_pause_freeze() -> void:
	var game := FakeGame.new()
	game.current_node_seed = 31337
	game.build(root)
	game.spawn_enemies(2)
	await process_frame

	# Авто-процессинг включён (manual=false) — проверяем PAUSABLE-заморозку.
	var director := _new_director(game, false)
	_expect(director.state() == "planned", "E: beat planned")

	paused = true
	for i in range(4):
		await process_frame
	_expect(is_equal_approx(director.elapsed_seconds(), 0.0), "E: elapsed must stay frozen while tree is paused")

	paused = false
	for i in range(4):
		await process_frame
	_expect(director.elapsed_seconds() > 0.0, "E: elapsed must advance once unpaused")

	director.shutdown(true)
	game.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
