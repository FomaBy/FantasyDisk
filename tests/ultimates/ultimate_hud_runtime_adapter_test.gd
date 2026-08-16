extends SceneTree

## FAN-2360 — stable frames must not rebuild the ultimate HUD view-model.

const HudAdapter := preload("res://scripts/ui/ultimate_hud/ultimate_hud_runtime_adapter.gd")

var _errors: Array[String] = []


class CountingAdapter extends HudAdapter:
	var rebuild_count := 0
	var input_state_count := 0

	func _build_state(snapshot: Dictionary) -> Dictionary:
		rebuild_count += 1
		return super._build_state(snapshot)

	func _input_state(device: String) -> Dictionary:
		input_state_count += 1
		return super._input_state(device)


class HudPlayerFixture extends Node2D:
	var character_id := "soldier"
	var weapon_id := "soldier_rifle"
	var ultimate_charge := 100.0
	var ultimate_max_charge := 100.0
	var _ultimate_active := false
	var aim_mode := "nearest"

	func attack_aim_mode() -> String:
		return aim_mode


class HudGameFixture extends Node:
	var current_player: Node2D = null


func _initialize() -> void:
	var input_manager := root.get_node_or_null("InputDeviceManager")
	_expect(input_manager != null and input_manager.has_method("set_input_mode"),
		"InputDeviceManager autoload must expose input-mode switching")
	var original_input_mode := str(input_manager.call("input_mode")) if input_manager != null else "auto"

	var game := HudGameFixture.new()
	var hud_root := Control.new()
	hud_root.size = Vector2(1280.0, 720.0)
	game.add_child(hud_root)
	root.add_child(game)
	var adapter := CountingAdapter.new()
	adapter._game = game
	hud_root.add_child(adapter)
	adapter.set_process(true)
	var player := HudPlayerFixture.new()
	game.current_player = player
	game.add_child(player)

	await process_frame
	await process_frame
	input_manager.call("set_input_mode", "keyboard")
	await process_frame
	var widget := hud_root.get_node_or_null("UltimateHudWidget")
	_expect(widget != null, "adapter must mount the ultimate HUD")
	var initial_rebuilds := adapter.rebuild_count
	var initial_input_states := adapter.input_state_count
	_expect(initial_rebuilds == 1, "mount must build exactly once, got %d" % initial_rebuilds)

	const STABLE_FRAMES := 8
	for _frame in STABLE_FRAMES:
		await process_frame
	_expect(adapter.rebuild_count == initial_rebuilds,
		"stable interval rebuilt %d times" % (adapter.rebuild_count - initial_rebuilds))
	_expect(adapter.input_state_count == initial_input_states,
		"stable interval re-read InputMap %d times" % (adapter.input_state_count - initial_input_states))
	_expect(adapter.rebuild_count < initial_rebuilds + STABLE_FRAMES,
		"falsification: unconditional refresh would rebuild once per stable frame")
	_expect(adapter.input_state_count < initial_input_states + STABLE_FRAMES,
		"falsification: unconditional refresh would re-read InputMap once per stable frame")

	player.ultimate_charge = 50.0
	await process_frame
	_expect(adapter.rebuild_count == initial_rebuilds + 1, "charge change must rebuild by the next frame")

	player._ultimate_active = true
	await process_frame
	_expect(adapter.rebuild_count == initial_rebuilds + 2, "activity change must rebuild by the next frame")

	player.aim_mode = "cursor"
	await process_frame
	_expect(adapter.rebuild_count == initial_rebuilds + 3, "aim change must rebuild by the next frame")

	player.weapon_id = "soldier_grenade"
	await process_frame
	_expect(adapter.rebuild_count == initial_rebuilds + 4, "weapon change must rebuild by the next frame")

	input_manager.call("set_input_mode", "gamepad")
	await process_frame
	_expect(adapter.rebuild_count == initial_rebuilds + 5, "device switch must rebuild without stale input")
	_expect(adapter.input_state_count == initial_input_states + 1,
		"device switch must refresh the cached InputMap state exactly once")
	if widget != null:
		var state: Dictionary = widget.call("state")
		_expect(str((state.get("input", {}) as Dictionary).get("device", "")) == "gamepad",
			"device switch must reach the HUD state")

	game.queue_free()
	input_manager.call("set_input_mode", original_input_mode)
	await process_frame
	_report()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("ultimate_hud_runtime_adapter_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("ultimate_hud_runtime_adapter_test: %s" % error)
	print("ultimate_hud_runtime_adapter_test: FAIL (%d)" % _errors.size())
	quit(1)
