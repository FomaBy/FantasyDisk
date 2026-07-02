extends SceneTree

# SCRUM-707 (refactor wave 0.2.0): focused coverage for the Main coordinator pause
# reference-counting lifecycle. The run-state pause system (push_pause/pop_pause/
# _clear_all_game_pauses) is core fragile state with no dedicated test before this.
# Semantics under test:
#   - pause_reasons is a SET of reasons; the tree stays paused while any remain.
#   - push/pop with an empty reason is a no-op guard (never pauses on "").
#   - pushing the same reason twice is idempotent (set, not a counter): one pop clears it.
#   - _clear_all_game_pauses() force-unpauses and empties the reason set.

func _initialize() -> void:
	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	if main_scene == null:
		push_error("Main scene did not load.")
		quit(1)
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame

	if not _run_assertions(main):
		# Always leave the tree unpaused so the harness can quit cleanly.
		main.call("_clear_all_game_pauses")
		main.queue_free()
		await process_frame
		quit(1)
		return

	main.call("_clear_all_game_pauses")
	main.queue_free()
	await process_frame
	print("Main pause-lifecycle test passed.")
	quit()


func _run_assertions(main: Node) -> bool:
	# Fresh coordinator: nothing paused.
	if bool(main.call("_is_gameplay_paused")) or bool(paused):
		push_error("Expected a fresh Main to start unpaused.")
		return false

	# Empty-reason guard: must never pause on "".
	main.call("push_pause", "")
	if bool(main.call("_is_gameplay_paused")) or bool(paused):
		push_error("Expected push_pause(\"\") to be a no-op guard.")
		return false

	# Single reason pauses the tree.
	main.call("push_pause", "level_up")
	if not bool(main.call("_is_gameplay_paused")) or not bool(paused):
		push_error("Expected push_pause(\"level_up\") to pause gameplay.")
		return false
	if not bool(main.call("_has_pause_reason", "level_up")):
		push_error("Expected _has_pause_reason(\"level_up\") after push.")
		return false

	# Second distinct reason keeps the tree paused (set holds both).
	main.call("push_pause", "escape_menu")
	if not bool(main.call("_has_pause_reason", "escape_menu")) or not bool(paused):
		push_error("Expected a second reason to keep gameplay paused.")
		return false

	# Popping one reason while another remains must NOT unpause.
	main.call("pop_pause", "level_up")
	if bool(main.call("_has_pause_reason", "level_up")):
		push_error("Expected level_up reason to be cleared after pop.")
		return false
	if not bool(main.call("_has_pause_reason", "escape_menu")) or not bool(paused):
		push_error("Expected gameplay to stay paused while escape_menu remains.")
		return false

	# Empty-reason pop is also a guard and must not disturb the live reason.
	main.call("pop_pause", "")
	if not bool(main.call("_has_pause_reason", "escape_menu")) or not bool(paused):
		push_error("Expected pop_pause(\"\") to leave existing reasons untouched.")
		return false

	# Popping the last reason unpauses.
	main.call("pop_pause", "escape_menu")
	if bool(main.call("_is_gameplay_paused")) or bool(paused):
		push_error("Expected gameplay to resume once the last reason is popped.")
		return false

	# Set semantics (not a counter): pushing the same reason twice then popping once
	# fully clears it.
	main.call("push_pause", "shop")
	main.call("push_pause", "shop")
	main.call("pop_pause", "shop")
	if bool(main.call("_has_pause_reason", "shop")) or bool(paused):
		push_error("Expected duplicate push to be idempotent (single pop clears it).")
		return false

	# _clear_all_game_pauses force-resets a multi-reason pause stack.
	main.call("push_pause", "a")
	main.call("push_pause", "b")
	main.call("_clear_all_game_pauses")
	if bool(main.call("_is_gameplay_paused")) or bool(paused):
		push_error("Expected _clear_all_game_pauses to drop every reason and unpause.")
		return false

	return true
