extends SceneTree

## FAN-1460: charge-economy semantics and the persistence chain behind them.
##
## Run:
## Godot --headless --path . \
##   --script res://tests/ultimates/balance_charge_economy_test.gd
##
## The ledger blocks cover the rules; the persistence blocks drive the REAL
## runtime chain (CombatDirector snapshot -> act transition -> autosave), because
## a charge economy that survives only in its own unit test is not rare, it is
## imaginary.

const PD := preload("res://scripts/progression_data.gd")
const MAIN := preload("res://scripts/main.gd")
const RUN_AUTOSAVE := preload("res://scripts/run_autosave.gd")
const CombatDirector := preload("res://scripts/combat_director.gd")
const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Ledger := preload("res://scripts/ultimates/balance/ultimate_charge_ledger.gd")


class StubGame extends RefCounted:
	var run_player_snapshot := {}
	var selected_character_id := "berserk"
	var selected_weapon_id := ""


class StubPlayer extends Node:
	var character_id := "berserk"
	var weapon_id := ""
	var health := 60.0
	var max_health := 100.0
	var stats := {}
	var run_modifiers := {}
	var artifacts := []
	var xp := 0
	var xp_to_next := 5
	var level := 1
	var money := 0
	var ultimate_charge := 0.0
	var ultimate_max_charge := 100.0

	func configure_character(id: String, _weapon := "") -> void:
		character_id = id


func _initialize() -> void:
	var errors: Array[String] = []
	_test_encounter_budget(errors)
	_test_activation_is_the_only_spend(errors)
	_test_active_effect_earns_nothing(errors)
	_test_snapshot_contract(errors)
	_test_runtime_battle_to_battle(errors)
	_test_act_transition_and_continue(errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Ultimate charge economy: %s" % error)
		quit(1)
		return
	print("balance_charge_economy_test passed.")
	quit(0)


func _fixture() -> Dictionary:
	var rows := Budget.build_rows(PD.WEAPONS_BY_CLASS, PD)
	return Budget.row_for(rows, "berserk", "sword")


# --- ledger rules -------------------------------------------------------------

func _test_encounter_budget(errors: Array[String]) -> void:
	var row := _fixture()
	if row.is_empty():
		errors.append("berserk/sword fixture must resolve")
		return
	var reference_dps := float(row["reference_solo_dps"])
	var ledger := Ledger.new(row)
	ledger.begin_encounter(Budget.ENCOUNTER_NORMAL)

	# One canonical window of the weapon's own output.
	ledger.add_removed_health(reference_dps * Budget.NORMAL_ENCOUNTER_SECONDS)
	var window_charge := ledger.charge
	_expect(
		is_equal_approx(
			window_charge, Budget.CHARGE_PER_REFERENCE_SECOND * Budget.NORMAL_ENCOUNTER_SECONDS
		),
		"a canonical window must be worth %.1f charge, got %.2f"
		% [Budget.CHARGE_PER_REFERENCE_SECOND * Budget.NORMAL_ENCOUNTER_SECONDS, window_charge],
		errors
	)

	# Ten more windows in the same encounter buy nothing past the cap.
	ledger.add_removed_health(reference_dps * Budget.NORMAL_ENCOUNTER_SECONDS * 10.0)
	_expect(
		is_equal_approx(ledger.charge, Budget.NORMAL_ENCOUNTER_CAP),
		"the per-encounter cap must clamp a runaway encounter, got %.2f" % ledger.charge,
		errors
	)

	# The next encounter keeps the charge and opens a fresh budget.
	ledger.begin_encounter(Budget.ENCOUNTER_NORMAL)
	_expect(
		is_equal_approx(ledger.charge, Budget.NORMAL_ENCOUNTER_CAP),
		"charge must survive the encounter boundary",
		errors
	)
	_expect(
		is_zero_approx(ledger.encounter_charge()),
		"the per-encounter budget must reset at the encounter boundary",
		errors
	)

	# Taken damage is a capped side channel, not a second income stream.
	var tank := Ledger.new(row)
	tank.begin_encounter(Budget.ENCOUNTER_NORMAL)
	tank.add_taken_health(600.0, 100.0)
	_expect(
		is_equal_approx(tank.charge, Budget.taken_channel_cap(Budget.ENCOUNTER_NORMAL)),
		"six health bars must stop at the taken-channel cap, got %.2f" % tank.charge,
		errors
	)

	# An invested build reaches the cap sooner but never past it.
	var invested := Ledger.new(row)
	invested.set_build(24.0, 1.35)
	invested.begin_encounter(Budget.ENCOUNTER_NORMAL)
	_expect(
		is_equal_approx(invested.build_multiplier(), Budget.BUILD_CHARGE_MULTIPLIER_CAP),
		"stacked Energy and ult_charge_multiplier must clamp to the build cap",
		errors
	)
	invested.add_removed_health(reference_dps * Budget.NORMAL_ENCOUNTER_SECONDS * 10.0)
	_expect(
		is_equal_approx(invested.charge, Budget.NORMAL_ENCOUNTER_CAP),
		"an invested build must obey the same per-encounter cap",
		errors
	)


func _test_activation_is_the_only_spend(errors: Array[String]) -> void:
	var row := _fixture()
	var ledger := Ledger.new(row)
	ledger.begin_encounter(Budget.ENCOUNTER_NORMAL)
	ledger.apply_start_charge(1.0)

	_expect(ledger.try_activate(), "a full bar must activate", errors)
	_expect(is_zero_approx(ledger.charge), "activation must spend the whole bar", errors)

	ledger.apply_start_charge(1.0)
	_expect(
		not ledger.try_activate(),
		"a second activation inside the same encounter must be refused",
		errors
	)
	_expect(
		is_equal_approx(ledger.charge, Budget.MAX_CHARGE),
		"a refused activation must not spend charge",
		errors
	)

	ledger.begin_encounter(Budget.ENCOUNTER_NORMAL)
	_expect(ledger.try_activate(), "the next encounter must allow one activation again", errors)

	# An unready bar is refused and keeps everything it holds.
	ledger.begin_encounter(Budget.ENCOUNTER_NORMAL)
	ledger.apply_start_charge(0.5)
	_expect(not ledger.try_activate(), "a half bar must not activate", errors)
	_expect(
		is_equal_approx(ledger.charge, Budget.MAX_CHARGE * 0.5),
		"a refused activation must not spend charge",
		errors
	)

	# A new run is the other reset; a class/weapon change before the run uses it.
	ledger.reset_for_new_run()
	_expect(is_zero_approx(ledger.charge), "a new run must clear the bar", errors)
	_expect(
		is_equal_approx(ledger.build_multiplier(), 1.0),
		"a new run must clear the build multiplier",
		errors
	)


func _test_active_effect_earns_nothing(errors: Array[String]) -> void:
	var row := _fixture()
	var reference_dps := float(row["reference_solo_dps"])
	var ledger := Ledger.new(row)
	ledger.begin_encounter(Budget.ENCOUNTER_NORMAL)
	ledger.set_ultimate_active(true)
	ledger.add_removed_health(reference_dps * Budget.NORMAL_ENCOUNTER_SECONDS)
	ledger.add_taken_health(100.0, 100.0)
	_expect(
		is_zero_approx(ledger.charge),
		"an active ultimate must earn nothing, got %.2f" % ledger.charge,
		errors
	)
	ledger.set_ultimate_active(false)
	ledger.add_removed_health(reference_dps * Budget.NORMAL_ENCOUNTER_SECONDS)
	_expect(ledger.charge > 0.0, "charge must resume once the effect ends", errors)


func _test_snapshot_contract(errors: Array[String]) -> void:
	var row := _fixture()
	var ledger := Ledger.new(row)
	ledger.begin_encounter(Budget.ENCOUNTER_NORMAL)
	ledger.apply_start_charge(1.0)
	if not ledger.try_activate():
		errors.append("setup: a full bar must activate before the snapshot check")
	# Battle ends mid-cast with the encounter's single use already spent.
	ledger.apply_start_charge(0.635)
	ledger.set_ultimate_active(true)

	var snapshot := ledger.to_snapshot()
	_expect(
		snapshot.size() == 1 and snapshot.has(Ledger.SNAPSHOT_KEY),
		"only the accumulated charge is a run resource, got keys %s" % str(snapshot.keys()),
		errors
	)

	var restored := Ledger.new(row)
	restored.apply_snapshot(snapshot)
	_expect(
		is_equal_approx(restored.charge, Budget.MAX_CHARGE * 0.635),
		"restore must transfer the charge, got %.2f" % restored.charge,
		errors
	)
	_expect(
		not restored.is_ultimate_active(),
		"an active effect must not cross the battle boundary",
		errors
	)
	_expect(
		restored.encounter_activations() == 0,
		"the use flag must not cross the battle boundary",
		errors
	)

	var legacy := Ledger.new(row)
	legacy.apply_snapshot({"health": 42.0})
	_expect(
		is_zero_approx(legacy.charge),
		"a save without the field must restore to 0, got %.2f" % legacy.charge,
		errors
	)

	var overflow := Ledger.new(row)
	overflow.apply_snapshot({Ledger.SNAPSHOT_KEY: 400.0})
	_expect(
		is_equal_approx(overflow.charge, Budget.MAX_CHARGE),
		"restore must clamp to the maximum",
		errors
	)


# --- runtime persistence chain ------------------------------------------------

func _test_runtime_battle_to_battle(errors: Array[String]) -> void:
	# The shipped run snapshot must speak the same key the ledger persists,
	# otherwise the contract and the runtime drift apart silently.
	var game := StubGame.new()
	var combat := CombatDirector.new(game)
	var donor := StubPlayer.new()
	donor.ultimate_charge = 63.5
	combat._store_player_snapshot(donor)
	donor.free()

	_expect(
		game.run_player_snapshot.has(Ledger.SNAPSHOT_KEY),
		"the run snapshot must carry '%s'" % Ledger.SNAPSHOT_KEY,
		errors
	)
	_expect(
		not game.run_player_snapshot.has("ultimate_active"),
		"the run snapshot must not carry the active-effect flag",
		errors
	)

	var fresh := StubPlayer.new()
	combat._restore_player_snapshot(fresh)
	_expect(
		is_equal_approx(fresh.ultimate_charge, 63.5),
		"battle -> map -> battle must keep the charge, got %.2f" % fresh.ultimate_charge,
		errors
	)
	fresh.free()


func _test_act_transition_and_continue(errors: Array[String]) -> void:
	# Never clobber an operator's live run: restore whatever was on disk.
	var preserved: Dictionary = RUN_AUTOSAVE.load_run()

	var game = MAIN.new()
	game.route_nodes = [{"type": "battle"}]
	game.current_act = 1
	game.run_player_snapshot = {
		"character_id": "berserk",
		"weapon_id": "sword",
		"health": 30.0,
		"max_health": 100.0,
		"stats": {},
		"run_modifiers": {},
		"artifacts": [],
		"xp": 0,
		"xp_to_next": 5,
		"level": 1,
		"money": 0,
		Ledger.SNAPSHOT_KEY: 71.0,
	}

	_expect(game.advance_to_next_act(), "act transition must run", errors)
	_expect(
		is_equal_approx(float(game.run_player_snapshot.get(Ledger.SNAPSHOT_KEY, -1.0)), 71.0),
		"the act transition must keep the charge, got %.2f"
		% float(game.run_player_snapshot.get(Ledger.SNAPSHOT_KEY, -1.0)),
		errors
	)
	_expect(
		float(game.run_player_snapshot.get("health", 0.0)) > 30.0,
		"the act transition heal must still apply",
		errors
	)

	# Continue: the act transition wrote the checkpoint; read it back through the
	# real load path.
	var loaded: Dictionary = RUN_AUTOSAVE.load_run()
	var migrated: Dictionary = game.migrate_run_autosave_state(loaded)
	var restored_snapshot: Dictionary = game._autosave_dictionary(
		migrated.get("run_player_snapshot", {})
	)
	_expect(
		is_equal_approx(float(restored_snapshot.get(Ledger.SNAPSHOT_KEY, -1.0)), 71.0),
		"Continue must restore the charge, got %.2f"
		% float(restored_snapshot.get(Ledger.SNAPSHOT_KEY, -1.0)),
		errors
	)

	# A pre-FAN-1460 checkpoint has no field at all.
	var legacy_snapshot: Dictionary = game._autosave_dictionary(
		{"character_id": "berserk", "health": 30.0}
	)
	_expect(
		is_zero_approx(float(legacy_snapshot.get(Ledger.SNAPSHOT_KEY, 0.0))),
		"a legacy checkpoint must resume at 0 charge",
		errors
	)
	game.free()

	if preserved.is_empty():
		RUN_AUTOSAVE.clear_run()
	else:
		RUN_AUTOSAVE.save_run(preserved)


func _expect(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)
