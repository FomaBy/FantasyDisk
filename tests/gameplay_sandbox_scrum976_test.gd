extends SceneTree

const SANDBOX := preload("res://scripts/gameplay_sandbox.gd")
const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const MAIN := preload("res://scripts/main.gd")
const ENEMY := preload("res://scripts/enemy.gd")
const PROGRESSION := preload("res://scripts/progression_data.gd")
const META := preload("res://scripts/meta_progression.gd")
const RUN_AUTOSAVE := preload("res://scripts/run_autosave.gd")
const PLAYER := preload("res://scripts/player.gd")
const SUMMONER_WEAPON := preload("res://scripts/summoner_weapon.gd")


class SandboxOwner:
	extends Node
	var snapshot := SANDBOX.neutral_snapshot()

	func run_sandbox_multiplier(key: String) -> float:
		return float(snapshot.get(key, 1.0))


func _initialize() -> void:
	var errors: Array[String] = []
	_check_contract(errors)
	_check_settings_and_run_snapshot(errors)
	_check_player_exact_layer(errors)
	await _check_enemy_runtime(errors)
	_check_progression_guards(errors)
	_cleanup_scratch_files()
	if not errors.is_empty():
		for error in errors:
			push_error("SCRUM-976: %s" % error)
		quit(1)
		return
	print("SCRUM-976 gameplay sandbox passed: persistence/snapshot, neutral/easier/harder/custom, player/enemy/cadence, progression guards.")
	quit(0)


func _check_contract(errors: Array[String]) -> void:
	var neutral := SANDBOX.neutral_snapshot()
	if not SANDBOX.is_neutral(neutral):
		errors.append("neutral snapshot is custom")
	for key in SANDBOX.keys():
		if not is_equal_approx(float(neutral.get(key, 0.0)), 1.0):
			errors.append("neutral %s != 1.0" % key)
	var neutral_meta := SANDBOX.run_metadata(neutral)
	for flag in ["progression_eligible", "achievements_eligible", "release_balance_evidence_eligible"]:
		if not bool(neutral_meta.get(flag, false)):
			errors.append("neutral metadata %s must be true" % flag)

	var corrupt := {
		SANDBOX.MONSTER_HP: 9.0,
		SANDBOX.MONSTER_DAMAGE: -4.0,
		SANDBOX.PLAYER_DAMAGE: "broken",
		SANDBOX.PLAYER_ATTACK_SPEED: NAN,
		SANDBOX.MONSTER_ATTACK_SPEED: 1.64,
	}
	var normalized := SANDBOX.snapshot_from_settings(corrupt)
	_assert_approx(errors, float(normalized[SANDBOX.MONSTER_HP]), 3.0, "monster HP clamp")
	_assert_approx(errors, float(normalized[SANDBOX.MONSTER_DAMAGE]), 0.5, "monster damage clamp")
	_assert_approx(errors, float(normalized[SANDBOX.PLAYER_DAMAGE]), 1.0, "non-numeric reset")
	_assert_approx(errors, float(normalized[SANDBOX.PLAYER_ATTACK_SPEED]), 1.0, "NaN reset")
	_assert_approx(errors, float(normalized[SANDBOX.MONSTER_ATTACK_SPEED]), 1.6, "step snap")


func _check_settings_and_run_snapshot(errors: Array[String]) -> void:
	_cleanup_scratch_files()
	var persisted := GAME_SETTINGS.DEFAULTS.duplicate(true)
	persisted[SANDBOX.MONSTER_HP] = 1.7
	persisted[SANDBOX.MONSTER_DAMAGE] = 0.8
	persisted[SANDBOX.PLAYER_DAMAGE] = 1.3
	persisted[SANDBOX.PLAYER_ATTACK_SPEED] = 1.4
	persisted[SANDBOX.MONSTER_ATTACK_SPEED] = 1.6
	GAME_SETTINGS.save_settings(persisted)
	var loaded := GAME_SETTINGS.load_settings()
	for key in SANDBOX.keys():
		_assert_approx(errors, float(loaded[key]), float(persisted[key]), "settings roundtrip %s" % key)

	var game = MAIN.new()
	game.sandbox_settings = SANDBOX.snapshot_from_settings(loaded)
	game.begin_new_run_session()
	var active_before: Dictionary = game.run_sandbox_snapshot.duplicate(true)
	game.reset_sandbox_settings(false)
	if not game.sandbox_settings_are_neutral():
		errors.append("atomic reset did not restore configured neutral values")
	if game.run_sandbox_snapshot != active_before:
		errors.append("configured reset mutated immutable active-run snapshot")
	if game.run_progression_eligible():
		errors.append("custom active run remained progression eligible")
	var state: Dictionary = game.call("_run_autosave_state")
	if state.get("run_sandbox_snapshot", {}) != active_before:
		errors.append("autosave state omitted or changed active sandbox snapshot")
	game.route_nodes = [{"type": "battle"}]
	if not game.save_run_autosave("scrum976"):
		errors.append("autosave write failed")
	var restored := RUN_AUTOSAVE.load_run()
	var restored_snapshot: Dictionary = restored.get("run_sandbox_snapshot", {})
	for key in SANDBOX.keys():
		_assert_approx(errors, float(restored_snapshot.get(key, -1.0)), float(active_before[key]), "autosave roundtrip %s" % key)
	game.begin_new_run_session()
	if game.run_sandbox_is_custom():
		errors.append("next run did not adopt reset neutral configured values")
	game.free()


func _check_player_exact_layer(errors: Array[String]) -> void:
	var stats := PROGRESSION.base_stats("berserk")
	var weapon := PROGRESSION.weapon("berserk", "sword")
	var neutral_mods := {
		"damage_flat": 7.0,
		"sandbox_player_damage_multiplier": 1.0,
		"sandbox_player_attack_speed_multiplier": 1.0,
	}
	var custom_mods := {
		"damage_flat": 7.0,
		"sandbox_player_damage_multiplier": 1.3,
		"sandbox_player_attack_speed_multiplier": 1.4,
	}
	var neutral := PROGRESSION.derived_parameters(stats, neutral_mods, weapon)
	var custom := PROGRESSION.derived_parameters(stats, custom_mods, weapon)
	_assert_approx(errors, float(custom["damage"]) / float(neutral["damage"]), 1.3, "exact final player damage")
	_assert_approx(errors, float(custom["magic_damage"]) / float(neutral["magic_damage"]), 1.3, "exact final magic damage")
	_assert_approx(errors, float(custom["dot_damage"]) / float(neutral["dot_damage"]), 1.3, "exact final DoT damage")
	_assert_approx(errors, float(custom["attack_speed"]) / float(neutral["attack_speed"]), 1.4, "exact final player attack speed")

	var player = PLAYER.new()
	player.derived_parameters = {"attack_speed": 2.0}
	var summon = SUMMONER_WEAPON.new()
	summon.summon_interval = 4.0
	summon.summon_attack_interval = 0.6
	player.call("_capture_weapon_base_values", summon)
	player.call("_apply_weapon_scaling", summon)
	_assert_approx(errors, summon.summon_interval, 4.0, "neutral summon deploy parity")
	_assert_approx(errors, summon.summon_attack_interval, 0.6, "neutral summoned ally parity")
	player.run_modifiers["sandbox_player_attack_speed_multiplier"] = 2.0
	player.call("_apply_weapon_scaling", summon)
	_assert_approx(errors, summon.summon_interval, 2.0, "sandbox summon deploy cadence")
	_assert_approx(errors, summon.summon_attack_interval, 0.3, "sandbox summoned ally cadence")
	summon.free()
	player.free()


func _check_enemy_runtime(errors: Array[String]) -> void:
	var owner := SandboxOwner.new()
	owner.snapshot = {
		SANDBOX.MONSTER_HP: 3.0,
		SANDBOX.MONSTER_DAMAGE: 0.8,
		SANDBOX.MONSTER_ATTACK_SPEED: 1.6,
	}
	root.add_child(owner)
	var enemy = ENEMY.new()
	enemy.max_health = 10.0
	enemy.contact_damage = 4.0
	enemy.projectile_damage = 5.0
	enemy.elite_hazard_damage = 6.0
	owner.add_child(enemy)
	await process_frame
	_assert_approx(errors, enemy.max_health, 30.0, "ordinary/summoned enemy HP")
	_assert_approx(errors, enemy.contact_damage, 3.2, "enemy contact damage")
	_assert_approx(errors, enemy.projectile_damage, 4.0, "enemy projectile damage")
	_assert_approx(errors, enemy.elite_hazard_damage, 4.8, "elite hazard damage")
	_assert_approx(errors, float(enemy.call("_elite_reflect_damage", 10.0)), 2.0, "elite reflect-thorns damage")
	_assert_approx(errors, float(enemy.call("_sandbox_attack_delta", 0.25)), 0.4, "monster cooldown delta")

	# Attack speed changes cooldown, not the readable contact windup.
	enemy.set("_contact_cooldown", 1.0)
	var target := Node2D.new()
	owner.add_child(target)
	enemy.call("_update_contact_damage", 0.25, target, 999.0)
	_assert_approx(errors, float(enemy.get("_contact_cooldown")), 0.6, "contact cooldown scaled")
	enemy.set("_contact_cooldown", 0.0)
	enemy.set("_contact_windup_left", 0.22)
	enemy.call("_update_contact_damage", 0.10, target, 0.0)
	_assert_approx(errors, float(enemy.get("_contact_windup_left")), 0.12, "contact windup unchanged")
	owner.queue_free()
	await process_frame


func _check_progression_guards(errors: Array[String]) -> void:
	var game = MAIN.new()
	game.meta_state = META.default_state()
	game.selected_character_id = "berserk"
	game.selected_ascension_level = 0
	game.sandbox_settings[SANDBOX.MONSTER_HP] = 1.7
	game.begin_new_run_session()
	var before: Dictionary = game.meta_state.duplicate(true)
	game.record_boss_victory()
	game.record_codex_discovery("monsters", "rift_cutter")
	game.evaluate_run_achievements()
	if game.meta_state != before:
		errors.append("custom run changed persistent meta/codex/achievement state")
	game.reset_sandbox_settings(false)
	game.begin_new_run_session()
	if not game.run_progression_eligible():
		errors.append("neutral run is not progression eligible")
	game.record_codex_discovery("monsters", "rift_cutter")
	if not META.is_codex_discovered(game.meta_state, "monsters", "rift_cutter"):
		errors.append("neutral run codex progression was blocked")
	game.free()


func _assert_approx(errors: Array[String], actual: float, expected: float, label: String) -> void:
	if not is_equal_approx(actual, expected):
		errors.append("%s: expected %.4f, got %.4f" % [label, expected, actual])


func _cleanup_scratch_files() -> void:
	for path in [GAME_SETTINGS.SAVE_PATH, RUN_AUTOSAVE.DEFAULT_SAVE_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
