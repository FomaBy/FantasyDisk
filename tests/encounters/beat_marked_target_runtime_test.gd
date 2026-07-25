extends SceneTree
## FAN-1447 — runtime smoke: адаптер CombatDirector поднимает Encounter Beat
## Director в реальном нормальном бою и соблюдает default-off parity.
##
## Прогон:
##   python3 tools/godot_gate.py --headless --path . \
##     --script res://tests/encounters/beat_marked_target_runtime_test.gd
##
## Enabled → директор-узел существует, спланирован ровно один primary-бит
## marked_target, узел PAUSABLE. Disabled (default) → директор не создаётся,
## бой идентичен baseline. Скрипты пакета не должны выдавать SCRIPT ERROR.

const CONFIG := preload("res://scripts/encounters/encounter_config.gd")

var errors: Array = []


func _initialize() -> void:
	await _run_enabled_case()
	await _run_default_off_case()
	CONFIG.clear_enabled_override()

	if not errors.is_empty():
		for e in errors:
			push_error("beat-runtime: %s" % str(e))
		quit(1)
		return
	print("FAN-1447 marked_target runtime smoke passed.")
	quit(0)


func _boot_main() -> Node:
	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	if main_scene == null:
		_expect(false, "Main.tscn must load")
		return null
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "axe")
	main.call("_start_combat")
	await create_timer(1.0).timeout
	return main


func _run_enabled_case() -> void:
	CONFIG.set_enabled_override(true)
	var main = await _boot_main()
	if main == null:
		return
	_expect(bool(main.get("combat_active")), "enabled: normal battle must be active")

	var director := main.find_child("EncounterBeatDirector", true, false)
	_expect(director != null, "enabled: adapter must create the EncounterBeatDirector node")
	if director != null:
		_expect(director.process_mode == Node.PROCESS_MODE_PAUSABLE, "enabled: director must be PAUSABLE")
		_expect(director.state() == "planned", "enabled: exactly one primary beat must be planned")
		_expect(director.planned_beat_id() == "marked_target", "enabled: planned beat must be marked_target")
		var trig: float = director.planned_trigger_at()
		_expect(trig >= 20.0 and trig <= 60.0, "enabled: trigger must sit inside the battle window (got %f)" % trig)
		# За ~1с боя триггер ещё не должен сработать (окно 20-40с).
		_expect(main.find_child("MarkedTargetMarker", true, false) == null, "enabled: marker must not appear before trigger")

	# Терминальная очистка на конце боя проверяется в lifecycle-тесте; здесь конец
	# боя гоняем через combat-директора (у Main нет собственного _end_combat).
	# Отсутствие combat — это провал, а не повод молча пропустить единственную
	# проверку финального teardown.
	var combat = main.get("combat")
	_expect(combat != null, "enabled: Main must expose its combat director for the teardown check")
	if combat != null:
		combat.call("_end_combat", true)
		await process_frame
		_expect(main.find_child("EncounterBeatDirector", true, false) == null, "enabled: director must be gone after combat end")

	main.queue_free()
	await process_frame


func _run_default_off_case() -> void:
	CONFIG.set_enabled_override(false)
	var main = await _boot_main()
	if main == null:
		return
	_expect(bool(main.get("combat_active")), "default-off: normal battle must still run")
	_expect(main.find_child("EncounterBeatDirector", true, false) == null,
		"default-off: no beat director may be created (baseline parity)")

	var combat = main.get("combat")
	_expect(combat != null, "default-off: Main must expose its combat director for the baseline teardown")
	if combat != null:
		combat.call("_end_combat", true)
		await process_frame
	main.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
