extends SceneTree

## FAN-3985 editor pre-gate for release-build safety of the 51 weapon ultimates.
##
## Plays every canonical class/weapon pair through the shipped player path
## (`scenes/Main.tscn` -> `_start_combat()` -> real `Player.activate_ultimate()`
## -> executor, enemy deaths, victim impacts, authored presentation) and keeps
## the game running past the declared cancel of the presentation. A stored
## enemy reference that is read after the enemy was freed prints
## `Trying to cast a freed object` / `... previously freed instance` here and
## segfaults an exported release build (first FAN-3985 QA, 10 of 51 pairs).
## `tools/godot_gate.py` fails this suite on any such SCRIPT ERROR, and the
## suite itself fails when activation, the host presentation or the
## class-owned scene is missing for a pair. The exported-build counterpart is
## `tools/ultimate_export_probe.py` (player-path stage, on by default).
##
## Run:
## python3 tools/godot_gate.py --headless --path . \
##   --script res://tests/ultimates/player_path_release_safety_test.gd

const Probe := preload("res://tools/ultimate_player_path_probe.gd")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
const EXPECTED_PAIRS := 51

var _probe: Node2D = null


func _initialize() -> void:
	_probe = Probe.new()
	root.add_child(_probe)
	await process_frame
	_run()


func _run() -> void:
	var errors: Array[String] = []
	var registry = PlayerHost.shared_registry()
	var only := OS.get_environment("FAN3985_ONLY_PAIR").strip_edges()
	var pairs := 0
	for raw_class_id in registry.class_ids():
		var class_id := str(raw_class_id)
		for raw_weapon_id in registry.weapon_ids(class_id):
			var weapon_id := str(raw_weapon_id)
			if not only.is_empty() and only != "%s/%s" % [class_id, weapon_id]:
				continue
			pairs += 1
			var entry: Dictionary = await _probe.run_pair(class_id, weapon_id, {})
			if not bool(entry.get("pass", false)):
				errors.append("%s: %s" % [entry["key"], entry.get("failures", [])])
	if only.is_empty() and pairs != EXPECTED_PAIRS:
		errors.append("expected %d pairs, played %d" % [EXPECTED_PAIRS, pairs])
	_probe.queue_free()
	await process_frame
	if errors.is_empty():
		print("Player path release safety test passed: %d pairs activated through the shipped player path and survived past their declared cancel." % pairs)
		quit(0)
		return
	for error in errors:
		push_error("Player path release safety test: %s" % error)
	push_error("Player path release safety test: %d errors." % errors.size())
	quit(1)
