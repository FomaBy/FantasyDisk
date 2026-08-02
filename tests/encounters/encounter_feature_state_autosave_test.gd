extends SceneTree

const CONFIG := preload("res://scripts/encounters/encounter_config.gd")
const CONTEXT := preload("res://scripts/encounters/encounter_context.gd")
const RUN_AUTOSAVE := preload("res://scripts/run_autosave.gd")
const TEST_PATH := "user://fan2022_encounter_state.cfg"

var errors: Array[String] = []


class FakeCheckpointGame extends RefCounted:
	var current_act := 1
	var encounter_feature_state := {}
	var persist_ok := true

	func save_run_autosave(_reason := "") -> bool:
		return persist_ok


func _initialize() -> void:
	RUN_AUTOSAVE.clear_run(TEST_PATH)
	_check_normalization_and_checkpoint()
	_check_autosave_round_trip()
	await _check_main_restore_and_new_run_reset()
	RUN_AUTOSAVE.clear_run(TEST_PATH)
	if not errors.is_empty():
		for error in errors:
			push_error("encounter-act-state: " + error)
		quit(1)
		return
	print("FAN-2022 encounter act-state autosave contract passed.")
	quit(0)


func _accepted_record(risk := "armed", claim_count := 0) -> Dictionary:
	return {
		"decision": "accepted",
		"offer_count": 1,
		"risk": risk,
		"claim_count": claim_count,
		"checkpoint_ids": ["offer:act1"],
	}


func _declined_record() -> Dictionary:
	return {
		"decision": "declined",
		"offer_count": 1,
		"risk": "",
		"claim_count": 0,
		"checkpoint_ids": ["decline:act1"],
	}


func _check_normalization_and_checkpoint() -> void:
	var legacy := CONFIG.normalize_act_state(null, 1)
	_expect(not bool(legacy.get("quarantined", true)) and (legacy.get("entries", {}) as Dictionary).is_empty(),
		"missing legacy section must normalize to a fresh optional envelope")

	var game := FakeCheckpointGame.new()
	game.encounter_feature_state = legacy
	var context := CONTEXT.new()
	context.game = game
	_expect(context.checkpoint_act_feature_state("marked_target", _accepted_record(), false),
		"valid accepted state must checkpoint")
	var accepted := game.encounter_feature_state.duplicate(true)
	var read_copy := context.act_feature_state("marked_target")
	read_copy["decision"] = "declined"
	_expect(str(context.act_feature_state("marked_target").get("decision", "")) == "accepted",
		"feature state reads must be copy-isolated")
	_expect(not context.checkpoint_act_feature_state("marked_target", _declined_record(), false),
		"an accepted decision must not be downgraded to decline")

	game.persist_ok = false
	_expect(not context.checkpoint_act_feature_state("marked_target", _accepted_record("succeeded", 1), true),
		"failed pre-risk persistence must reject the transition")
	_expect(game.encounter_feature_state == accepted, "failed persistence must roll memory back exactly")
	game.persist_ok = true
	game.encounter_feature_state = legacy
	_expect(context.checkpoint_act_feature_state("marked_target", _declined_record(), true),
		"decline checkpoint must persist through the same atomic seam")

	var progressed := CONFIG.checkpoint_act_state(legacy, 1, "marked_target", _accepted_record())
	progressed = CONFIG.checkpoint_act_state(progressed, 1, "marked_target", _accepted_record("succeeded", 1))
	_expect(not progressed.is_empty(), "risk and claim may advance monotonically")
	_expect(CONFIG.checkpoint_act_state(progressed, 1, "marked_target", _accepted_record()).is_empty(),
		"succeeded risk and claimed reward must not reset on quit/retry")

	var wrong_version := accepted.duplicate(true); wrong_version["schema_version"] = "1"
	var wrong_act := accepted.duplicate(true); wrong_act["act"] = 2
	var unknown := accepted.duplicate(true)
	unknown["entries"] = {"unknown_feature": _accepted_record()}
	var malformed := accepted.duplicate(true)
	malformed["entries"] = {"marked_target": _accepted_record("armed", 1)}
	var ui_payload := accepted.duplicate(true)
	var payload_record := _accepted_record(); payload_record["ui_node"] = "forbidden"
	ui_payload["entries"] = {"marked_target": payload_record}
	for invalid in [wrong_version, wrong_act, unknown, malformed, ui_payload]:
		var normalized := CONFIG.normalize_act_state(invalid, 1)
		_expect(bool(normalized.get("quarantined", false)) and (normalized.get("entries", {}) as Dictionary).is_empty(),
			"unknown/malformed state must quarantine the act without reward/risk facts")


func _check_autosave_round_trip() -> void:
	var state := CONFIG.empty_act_state(1)
	state = CONFIG.checkpoint_act_state(state, 1, "marked_target", _accepted_record("succeeded", 1))
	_expect(not state.is_empty(), "valid succeeded/claimed record must normalize")
	_expect(RUN_AUTOSAVE.SCHEMA_VERSION == 1, "outer autosave schema must remain backward compatible")
	_expect(RUN_AUTOSAVE.save_run({"current_act": 1, "encounter_feature_state": state}, TEST_PATH),
		"nested feature state must save through the existing atomic autosave")
	var loaded := RUN_AUTOSAVE.load_run(TEST_PATH)
	var restored := CONFIG.normalize_act_state(loaded.get("encounter_feature_state", null), 1)
	_expect(restored == state, "feature state must round-trip without UI/payload loss or widening")


func _check_main_restore_and_new_run_reset() -> void:
	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	var game := main_scene.instantiate()
	root.add_child(game)
	await process_frame
	var state := CONFIG.empty_act_state(1)
	state = CONFIG.checkpoint_act_state(state, 1, "marked_target", _accepted_record())
	game.current_act = 1
	game.encounter_feature_state = state
	var run_state: Dictionary = game._run_autosave_state()
	_expect(run_state.get("encounter_feature_state", {}) == state,
		"Main checkpoint must include the normalized optional state")
	game.encounter_feature_state = {}
	game._apply_run_autosave_state(run_state)
	_expect(game.encounter_feature_state == state, "Main restore must rehydrate the exact valid act state")

	var migrated_legacy: Dictionary = game.migrate_run_autosave_state({"current_act": 1})
	_expect(not bool((migrated_legacy.get("encounter_feature_state", {}) as Dictionary).get("quarantined", true)),
		"legacy Main save without the section must continue loading")
	var malformed := run_state.duplicate(true)
	malformed["encounter_feature_state"] = {"schema_version": 99}
	var migrated_bad: Dictionary = game.migrate_run_autosave_state(malformed)
	_expect(bool((migrated_bad.get("encounter_feature_state", {}) as Dictionary).get("quarantined", false)),
		"Main migration must persist fail-closed quarantine for malformed state")

	game.encounter_feature_state = state
	game.begin_new_run_session()
	_expect((game.encounter_feature_state.get("entries", {}) as Dictionary).is_empty(),
		"new run must reset act-scoped feature state")
	game.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
