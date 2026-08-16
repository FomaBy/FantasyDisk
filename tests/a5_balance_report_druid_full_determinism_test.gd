extends SceneTree

# FAN-1672: repeat-determinism contract for the REAL A5 `--mode=full` Druid
# summon fixture.
#
# tools/a5_balance_report.gd measures druid/summon_amulet with the natural
# `_measure_live` seam: level-20 `class_constellation` build, seeds
# 143801/143802/143803, one solo and one 10-target pack sample per seed, a 2 s
# (120-frame) warmup and a 6 s (360-frame) measurement window at a fixed 1/60
# step. The shorter FAN-1585 observer fixture drives `_try_attack` by hand for
# six frames, so it cannot see a divergence that only appears once summons run
# their own production `_physics_process` for a full window. This fixture keeps
# the production path untouched and asserts that every one of the six samples
# reproduces byte-identical events, HP ledger and DPM projection when it is
# measured twice in the same process.
#
# `_advance_live` closes on accumulated `get_process_delta_time()` rather than on
# a frame counter, so the 6.0 s window settles on 361 frames, not the nominal 360
# of the fixed-step observer A/B path. That offset is itself deterministic and is
# baked into every accepted value, so the fixture records the measured count and
# requires all six samples to agree instead of silently normalising it.
#
# FAN-1681: repeat-identity is necessary but not sufficient. A deterministic drift to
# a NEW stable value keeps every pass-A/pass-B comparison green, so both passes are
# additionally aggregated exactly as `_live_parity` + `_apply_live_evidence_to_rows`
# do and asserted against the committed accepted projection cells
# (`68101.14` / `394715.33` / `51498851.11` / `36324029697.05`), which are themselves
# cross-checked against tests/fixtures/a5_oracle_lineage.json.

const Generator := preload("res://tools/a5_balance_report.gd")
const PD := preload("res://scripts/progression_data.gd")
const Meta := preload("res://scripts/meta_progression.gd")
const MainScript := preload("res://scripts/main.gd")
const DamageTable := preload("res://tools/class_damage_table_3variants.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")

const SELF_SCRIPT_PATH := "res://tests/a5_balance_report_druid_full_determinism_test.gd"
const RERUN_SENTINEL := "--fan1672-fixed-step-rerun"
const CLASS_ID := "druid"
const WEAPON_ID := "summon_amulet"
const LIVE_SEEDS := [143801, 143802, 143803]
const LIVE_WARMUP_SECONDS := 2.0
const LIVE_WINDOW_SECONDS := 6.0
const DETERMINISTIC_MAX_FPS := 60
const LIVE_FIXED_DELTA := 1.0 / float(DETERMINISTIC_MAX_FPS)
# `--fixed-fps 60` reports a bit-identical 1/60; a wall-clock step never is.
const FIXED_STEP_TOLERANCE := 1.0e-9
const LIVE_MEASUREMENT_FRAMES := 360
const MAX_LIVE_FRAMES := 2400
const TARGET_COUNT := 10
const DUMMY_HP := 1.0e9
const PLAYER_POSITION := Vector2(1280.0, 720.0)
const SOLO_OFFSET := Vector2(80.0, 0.0)
const PACK_RADIUS := 42.0

# FAN-1681: the accepted current-base druid/summon_amulet projection cells, pinned as
# literals. Until now the fixture only compared its own first pass with its own second
# pass and the single absolute DPM assertion was `dpm <= 0.0`, so a DETERMINISTIC drift
# to a NEW stable value stayed green while docs/design/systems/progression_balance.md
# claimed the fixture reproduces the accepted values. These four literals are exactly
# the level-20 / class_constellation cells the A5 candidate gate compares
# (tools/a5_balance_report.gd PROJECTION_FIELDS, anchored by
# PROJECTION_ANCHOR_CURRENT_SHA256), and _assert_accepted_values_match_lineage below
# cross-checks them against tests/fixtures/a5_oracle_lineage.json so the fixture can
# never anchor on a value the gate does not enforce.
const ACCEPTED_SOLO_DPM_MEAN := 68101.14
const ACCEPTED_CROWD_DPM_MEAN := 394715.33
const ACCEPTED_SOLO_VARIANCE_DPM2 := 51498851.11
const ACCEPTED_CROWD_VARIANCE_DPM2 := 36324029697.05

var _holder: Node2D
var _errors := PackedStringArray()


class LiveCollector extends RefCounted:
	var phase := "warmup"
	var frame := 0
	var events: Array = []
	var measurement_damage_by_target := {}
	var _target_labels := {}

	func bind_target(target: Node2D, label: String) -> void:
		if target != null:
			_target_labels[target.get_instance_id()] = label

	func set_phase(value: String) -> void:
		phase = value

	func advance_frame() -> void:
		frame += 1

	func on_weapon_cast(raw_event: Dictionary) -> void:
		if str(raw_event.get("phase_source", "")) != "class_weapon" or str(raw_event.get("phase", "")) != "windup":
			return
		events.append({
			"kind": "cast", "frame": frame, "probe_phase": phase,
			"action_id": str(raw_event.get("action_id", "")),
			"attack_mode": str(raw_event.get("attack_mode", "")),
		})

	func on_damage_applied(target: Node2D, _attempted_amount: float, applied_amount: float, feedback: Dictionary) -> void:
		if target == null or applied_amount <= 0.0:
			return
		var label := _target_label(target)
		if phase == "measurement":
			measurement_damage_by_target[label] = float(measurement_damage_by_target.get(label, 0.0)) + applied_amount
		events.append({
			"kind": "hit", "frame": frame, "probe_phase": phase, "target_id": label,
			"damage": applied_amount,
			"damage_type": str(feedback.get("damage_type", "")),
			"player_owned": bool(feedback.get("player_owned", false)),
			"constellation_final": str(feedback.get("constellation_final", "")),
		})

	func on_final_resolution(_weapon_id: String, event_name: String, target: Node2D, _context: Dictionary, resolution: Dictionary) -> void:
		events.append({
			"kind": "final", "frame": frame, "probe_phase": phase,
			"event": event_name, "target_id": _target_label(target),
			"mechanic_id": str(resolution.get("mechanic_id", "")),
			"triggered": bool(resolution.get("triggered", false)),
		})

	func on_target_died(target: Node2D) -> void:
		events.append({"kind": "died", "frame": frame, "probe_phase": phase, "target_id": _target_label(target)})

	func _target_label(target: Node2D) -> String:
		if target == null or not is_instance_valid(target):
			return "target_released"
		return str(_target_labels.get(target.get_instance_id(), "target_unknown"))


func _initialize() -> void:
	Engine.max_fps = DETERMINISTIC_MAX_FPS
	_holder = Node2D.new()
	_holder.name = "FAN1672DruidHolder"
	root.add_child(_holder)
	current_scene = _holder
	root.set_meta("aim_mode", "nearest")
	await process_frame

	# The whole A5 live-measurement contract is defined at a fixed 1/60 process step
	# (`generation_command` in tools/a5_balance_report.gd pins `--fixed-fps 60`), so a
	# repeat-determinism assertion is only meaningful under that step: with wall-clock
	# deltas the summon cadence itself drifts by a frame or two. tools/quality_gate.py
	# launches Godot tests without the flag, so when the step is not fixed the fixture
	# re-executes itself ONCE through the shared gate with `--fixed-fps 60` and
	# propagates that exit code, instead of silently asserting on wall-clock frames.
	if not await _has_fixed_process_step():
		if _is_fixed_step_rerun():
			# Hard recursion guard. `--fixed-fps` is an engine flag, so it never shows
			# up in OS.get_cmdline_args(); the RERUN_SENTINEL user arg below is the only
			# reliable "this is already the child" signal.
			push_error("FAN-1672 fixed-step rerun still did not get a fixed %.8fs process step; refusing to spawn another Godot" % LIVE_FIXED_DELTA)
			quit(1)
			return
		await _rerun_under_fixed_step()
		return

	var base_stats: Dictionary = PD.base_stats(CLASS_ID)
	var level20_stats: Dictionary = DamageTable.optimized_stats_for_class(CLASS_ID, base_stats)
	var state := _scenario_state(CLASS_ID)

	# Pass A measures all six samples in the canonical --mode=full order; pass B
	# repeats them after every sample has already run once, so a divergence that
	# only appears with warm process state is still caught.
	var first_pass := {}
	var second_pass := {}
	for pass_index in range(2):
		for seed_value in LIVE_SEEDS:
			for target_count in [1, TARGET_COUNT]:
				var fixture := "sustain_solo" if target_count == 1 else "sustain_pack"
				var sample: Dictionary = await _measure_live(level20_stats, state, int(seed_value), fixture, int(target_count))
				var key := "%s|%d|%s" % [WEAPON_ID, int(seed_value), fixture]
				if pass_index == 0:
					first_pass[key] = sample
				else:
					second_pass[key] = sample

	if first_pass.size() != 6 or second_pass.size() != 6:
		_errors.append("fixture must produce six druid samples per pass, got %d/%d" % [first_pass.size(), second_pass.size()])
	for key_value in first_pass.keys():
		var key := str(key_value)
		var expected: Dictionary = first_pass[key]
		var actual: Dictionary = second_pass.get(key, {})
		if float(expected.get("dpm", -1.0)) <= 0.0:
			_errors.append("%s produced no live damage; the fixture is not exercising the production summon path" % key)
		if int(expected.get("measurement_frame_count", 0)) < LIVE_MEASUREMENT_FRAMES:
			_errors.append("%s measured %d frames, expected at least the %d-frame window" % [key, int(expected.get("measurement_frame_count", 0)), LIVE_MEASUREMENT_FRAMES])
		_assert_identical(key, expected, actual)

	# FAN-1681: repeat-identity alone cannot see a deterministic drift to a new stable
	# value, so both passes are additionally anchored on the committed accepted cells,
	# and the seam parameters this fixture copies are pinned to production.
	_assert_seam_matches_production()
	_assert_accepted_values_match_lineage()
	_assert_accepted_projection(first_pass, "pass A")
	_assert_accepted_projection(second_pass, "pass B")

	_teardown_holder()
	# One compact cross-process witness: two clean processes of the same commit must
	# print the same line, so a divergence that only appears between runs is visible
	# without re-deriving the whole 309-sample report.
	var witness_keys := first_pass.keys()
	witness_keys.sort()
	var witness := ""
	var window_frames := -1
	for key_value in witness_keys:
		var sample: Dictionary = first_pass[str(key_value)]
		var frames := int(sample.get("measurement_frame_count", 0))
		if window_frames < 0:
			window_frames = frames
		elif frames != window_frames:
			_errors.append("%s measured a %d-frame window while another sample measured %d" % [str(key_value), frames, window_frames])
		witness += "%s|%d|%.2f|%s\n" % [str(key_value), frames, float(sample.get("dpm", -1.0)), JSON.stringify(sample.get("events", []), "", true, true).sha256_text()]
	print("FAN-1672 druid full-seam witness sha256=%s window_frames=%d" % [witness.sha256_text(), window_frames])
	print(witness.strip_edges())
	if not _errors.is_empty():
		for error_value in _errors:
			push_error(error_value)
		quit(1)
		return
	print("FAN-1672 A5 full-seam druid determinism regression passed: 3 seeds x solo/pack, natural _measure_live, 2 s warmup + 6 s measurement window (%d frames), each sample repeated and byte-identical." % window_frames)
	print("FAN-1681 accepted-projection anchor passed: both passes reproduce solo mean %.2f, crowd mean %.2f, solo variance %.2f, crowd variance %.2f." % [
		ACCEPTED_SOLO_DPM_MEAN, ACCEPTED_CROWD_DPM_MEAN, ACCEPTED_SOLO_VARIANCE_DPM2, ACCEPTED_CROWD_VARIANCE_DPM2,
	])
	quit(0)


# The child is launched with RERUN_SENTINEL after `--`, which lands in
# OS.get_cmdline_user_args(). Engine flags such as `--fixed-fps` are consumed by the
# engine and never appear in OS.get_cmdline_args(), so they cannot be used as the
# recursion guard.
func _is_fixed_step_rerun() -> bool:
	for raw_arg in OS.get_cmdline_user_args():
		if str(raw_arg) == RERUN_SENTINEL:
			return true
	return false


# `--fixed-fps <n>` makes Godot report exactly 1/n for every process delta. Probing
# the real delta is both the precondition the fixture needs and a direct check that
# the flag actually took effect.
func _has_fixed_process_step() -> bool:
	for _index in range(8):
		await process_frame
		if absf(_holder.get_process_delta_time() - LIVE_FIXED_DELTA) > FIXED_STEP_TOLERANCE:
			return false
	return true


func _rerun_under_fixed_step() -> void:
	# One extra semaphore slot for the nested run; the parent still holds its own.
	OS.set_environment("FSD_GODOT_SLOTS", str(maxi(int(OS.get_environment("FSD_GODOT_SLOTS")), 3) + 1))
	var output := []
	var exit_code := OS.execute("python3", [
		ProjectSettings.globalize_path("res://tools/godot_gate.py"),
		"--headless",
		"--fixed-fps", "60",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", SELF_SCRIPT_PATH,
		"--", RERUN_SENTINEL,
	], output, true)
	for line in output:
		print(str(line).strip_edges())
	if exit_code != 0:
		push_error("FAN-1672 fixed-step rerun of %s failed with exit %d" % [SELF_SCRIPT_PATH, exit_code])
	quit(exit_code)


func _assert_identical(key: String, expected: Dictionary, actual: Dictionary) -> void:
	for field in ["events", "measurement_damage_by_target", "health_after", "measurement_frame_count", "dpm"]:
		var expected_text := JSON.stringify(expected.get(field, null), "", true, true)
		var actual_text := JSON.stringify(actual.get(field, null), "", true, true)
		if expected_text == actual_text:
			continue
		if field == "events":
			_errors.append("%s repeat diverged on events: %s" % [key, _first_event_difference(expected.get("events", []), actual.get("events", []))])
		else:
			_errors.append("%s repeat diverged on %s: %s vs %s" % [key, field, expected_text, actual_text])


func _first_event_difference(expected: Array, actual: Array) -> String:
	var limit := mini(expected.size(), actual.size())
	for index in range(limit):
		var expected_text := JSON.stringify(expected[index], "", true, true)
		var actual_text := JSON.stringify(actual[index], "", true, true)
		if expected_text != actual_text:
			return "event %d of %d/%d: %s vs %s" % [index, expected.size(), actual.size(), expected_text, actual_text]
	return "event counts %d vs %d" % [expected.size(), actual.size()]


# FAN-1681 / anchored assertion. Reproduces the production aggregation exactly:
# `_live_parity` snaps the per-seed mean and stddev to 0.01, and
# `_apply_live_evidence_to_rows` squares the ALREADY snapped stddev into the variance
# cell. Comparison uses the same `%.2f` rendering the candidate gate compares
# (`projection_cell_map`), so this assertion is true at exactly the precision the gate
# enforces — no tolerance is introduced.
func _assert_accepted_projection(samples: Dictionary, pass_label: String) -> void:
	var solo := []
	var pack := []
	for seed_value in LIVE_SEEDS:
		solo.append(_sample_dpm(samples, int(seed_value), "sustain_solo", pass_label))
		pack.append(_sample_dpm(samples, int(seed_value), "sustain_pack", pass_label))
	if solo.size() != LIVE_SEEDS.size() or pack.size() != LIVE_SEEDS.size():
		return
	var solo_mean := _seed_mean(solo)
	var pack_mean := _seed_mean(pack)
	var solo_stddev := snappedf(_seed_stddev(solo, solo_mean), 0.01)
	var pack_stddev := snappedf(_seed_stddev(pack, pack_mean), 0.01)
	_assert_cell(pass_label, "live_solo_dpm_mean", snappedf(solo_mean, 0.01), ACCEPTED_SOLO_DPM_MEAN)
	_assert_cell(pass_label, "live_crowd_dpm_mean", snappedf(pack_mean, 0.01), ACCEPTED_CROWD_DPM_MEAN)
	_assert_cell(pass_label, "solo_variance_dpm2", snappedf(pow(solo_stddev, 2.0), 0.01), ACCEPTED_SOLO_VARIANCE_DPM2)
	_assert_cell(pass_label, "crowd_variance_dpm2", snappedf(pow(pack_stddev, 2.0), 0.01), ACCEPTED_CROWD_VARIANCE_DPM2)


func _sample_dpm(samples: Dictionary, seed_value: int, fixture: String, pass_label: String) -> float:
	var key := "%s|%d|%s" % [WEAPON_ID, seed_value, fixture]
	if not samples.has(key):
		_errors.append("%s is missing sample %s for the accepted-projection assertion" % [pass_label, key])
		return -1.0
	return float((samples[key] as Dictionary).get("dpm", -1.0))


func _assert_cell(pass_label: String, field: String, measured: float, accepted: float) -> void:
	if "%.2f" % measured == "%.2f" % accepted:
		return
	_errors.append("%s %s/%s %s drifted from the accepted current-base value: measured %.2f, accepted %.2f. The live seam is still deterministic but no longer reproduces the committed A5 projection cell; re-running --mode=full will fail the candidate gate." % [
		pass_label, CLASS_ID, WEAPON_ID, field, measured, accepted,
	])


# Mirrors tools/a5_balance_report.gd `_number_mean`.
func _seed_mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += float(value)
	return total / values.size()


# Mirrors tools/a5_balance_report.gd `_stddev` (population, not sample).
func _seed_stddev(values: Array, mean: float) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += pow(float(value) - mean, 2.0)
	return sqrt(total / values.size())


# FAN-1681: the anchor above must be the SAME accepted value the A5 candidate gate
# enforces, not a private copy that could be re-pinned on its own. Solo mean is the
# manifest's invariant f09 cell; the other three are the `to` sides of the accepted
# FAN-1585/FAN-1596 deltas.
func _assert_accepted_values_match_lineage() -> void:
	var loaded := Generator.load_oracle_lineage()
	if not bool(loaded.get("ok", false)):
		_errors.append("oracle lineage manifest must load to cross-check the accepted druid values: %s" % loaded.get("error", "unknown"))
		return
	var manifest: Dictionary = loaded.get("manifest", {})
	var pair := "%s/%s" % [CLASS_ID, WEAPON_ID]
	var expected := {
		"live_solo_dpm_mean": ACCEPTED_SOLO_DPM_MEAN,
		"live_crowd_dpm_mean": ACCEPTED_CROWD_DPM_MEAN,
		"solo_variance_dpm2": ACCEPTED_SOLO_VARIANCE_DPM2,
		"crowd_variance_dpm2": ACCEPTED_CROWD_VARIANCE_DPM2,
	}
	var covered := {}
	for delta_value in manifest.get("accepted_projection_deltas", []):
		var delta: Dictionary = delta_value
		if str(delta.get("pair", "")) != pair:
			continue
		var field := str(delta.get("field", ""))
		if not expected.has(field):
			continue
		covered[field] = true
		if "%.2f" % float(delta.get("to", NAN)) != "%.2f" % float(expected[field]):
			_errors.append("accepted delta %s|%s pins %.2f, but this fixture anchors on %.2f" % [pair, field, float(delta.get("to", NAN)), float(expected[field])])
	for cell_value in manifest.get("invariant_projection_cells", []):
		var cell: Dictionary = cell_value
		if str(cell.get("pair", "")) != pair:
			continue
		var field := str(cell.get("field", ""))
		if not expected.has(field):
			continue
		covered[field] = true
		if "%.2f" % float(cell.get("value", NAN)) != "%.2f" % float(expected[field]):
			_errors.append("invariant cell %s|%s pins %.2f, but this fixture anchors on %.2f" % [pair, field, float(cell.get("value", NAN)), float(expected[field])])
	for field_value in expected.keys():
		if not covered.has(str(field_value)):
			_errors.append("%s|%s is anchored by this fixture but is neither an accepted delta nor an invariant cell in the lineage manifest" % [pair, str(field_value)])


# FAN-1681: this fixture reproduces the `_measure_live` seam with its own copy (see the
# header note). Nothing used to stop the two copies from drifting apart. The numeric
# seam parameters are now pinned to production, and any BEHAVIOURAL divergence of the
# copy shows up in the anchored assertion above, because a diverged copy can no longer
# reproduce the committed accepted cells.
func _assert_seam_matches_production() -> void:
	var pinned := [
		["LIVE_SEEDS", str(LIVE_SEEDS), str(Generator.LIVE_SEEDS)],
		["LIVE_WARMUP_SECONDS", str(LIVE_WARMUP_SECONDS), str(Generator.LIVE_WARMUP_SECONDS)],
		["LIVE_WINDOW_SECONDS", str(LIVE_WINDOW_SECONDS), str(Generator.LIVE_WINDOW_SECONDS)],
		["DETERMINISTIC_MAX_FPS", str(DETERMINISTIC_MAX_FPS), str(Generator.DETERMINISTIC_MAX_FPS)],
		["LIVE_FIXED_DELTA", str(LIVE_FIXED_DELTA), str(Generator.LIVE_FIXED_DELTA)],
		["LIVE_MEASUREMENT_FRAMES", str(LIVE_MEASUREMENT_FRAMES), str(Generator.LIVE_MEASUREMENT_FRAMES)],
		["MAX_LIVE_FRAMES", str(MAX_LIVE_FRAMES), str(Generator.MAX_LIVE_FRAMES)],
		["TARGET_COUNT", str(TARGET_COUNT), str(Generator.TARGET_COUNT)],
		["DUMMY_HP", str(DUMMY_HP), str(Generator.DUMMY_HP)],
		["PLAYER_POSITION", str(PLAYER_POSITION), str(Generator.PLAYER_POSITION)],
		["SOLO_OFFSET", str(SOLO_OFFSET), str(Generator.SOLO_OFFSET)],
		["PACK_RADIUS", str(PACK_RADIUS), str(Generator.PACK_RADIUS)],
	]
	for entry_value in pinned:
		var entry: Array = entry_value
		if str(entry[1]) != str(entry[2]):
			_errors.append("fixture copy of %s (%s) drifted from tools/a5_balance_report.gd (%s)" % [str(entry[0]), str(entry[1]), str(entry[2])])


# Mirrors tools/a5_balance_report.gd `_scenario_state(class_id, "class_constellation")`.
func _scenario_state(class_id: String) -> Dictionary:
	var state := Meta.default_state()
	state["ascension_levels"] = {class_id: 5}
	var purchased := []
	var hidden_ids := []
	for raw_node in Meta.constellation_nodes(class_id):
		var node: Dictionary = raw_node
		var node_id := str(node.get("id", ""))
		if str(node.get("role", "")) != "core":
			purchased.append(node_id)
		if str(node.get("role", "")) == "hidden":
			hidden_ids.append(node_id)
	state["hidden_reveal_facts"] = {class_id: hidden_ids}
	state["skill_nodes"] = purchased
	return state


# Mirrors tools/a5_balance_report.gd `_measure_live` for the druid sustain fixtures.
func _measure_live(stats: Dictionary, state: Dictionary, seed_value: int, fixture: String, target_count: int) -> Dictionary:
	await _teardown()
	seed(seed_value)
	var collector := LiveCollector.new()
	var player := PLAYER_SCENE.instantiate() as Node2D
	_holder.add_child(player)
	player.add_to_group("player")
	player.global_position = PLAYER_POSITION
	player.call("configure_character", CLASS_ID, WEAPON_ID)
	player.set("stats", stats.duplicate(true))
	player.call("_apply_stat_scaling", true)
	var main := MainScript.new()
	main.set("selected_character_id", CLASS_ID)
	main.set("selected_ascension_level", 5)
	main.set("selected_start_boon_id", "")
	main.set("meta_state", state.duplicate(true))
	main.set("run_sandbox_captured", false)
	main.call("apply_ascension_bonuses", player)
	main.free()
	player.set("max_health", DUMMY_HP)
	player.set("health", DUMMY_HP)
	player.connect("weapon_cast_observed", collector.on_weapon_cast)
	player.connect("constellation_final_resolved", collector.on_final_resolution)
	await process_frame
	var dummies := _spawn_dummies(target_count)
	var anchors := []
	for index in range(dummies.size()):
		var enemy := dummies[index] as Node2D
		collector.bind_target(enemy, "target_%d" % index)
		enemy.connect("damage_applied", collector.on_damage_applied)
		enemy.connect("died", collector.on_target_died)
		anchors.append(enemy.global_position)
	await _advance_live(LIVE_WARMUP_SECONDS, dummies, anchors, collector, "warmup")
	var measurement: Dictionary = await _advance_live(LIVE_WINDOW_SECONDS, dummies, anchors, collector, "measurement")
	var duration := float(measurement.get("duration_seconds", 0.0))
	var ledger_total := 0.0
	for damage_value in collector.measurement_damage_by_target.values():
		ledger_total += float(damage_value)
	return {
		"seed": seed_value,
		"fixture": fixture,
		"target_count": target_count,
		"events": collector.events,
		"measurement_damage_by_target": collector.measurement_damage_by_target,
		"health_after": _health_snapshot(dummies),
		"measurement_frame_count": int(measurement.get("frame_count", 0)),
		# FAN-1681: call the production projection instead of restating it, so the DPM
		# step of this copied seam cannot drift away from tools/a5_balance_report.gd.
		"dpm": Generator._project_dpm(ledger_total, duration),
	}


func _advance_live(seconds: float, dummies: Array, anchors: Array, collector: LiveCollector, probe_phase: String) -> Dictionary:
	collector.set_phase(probe_phase)
	var elapsed := 0.0
	var frames := 0
	while elapsed < seconds and frames < MAX_LIVE_FRAMES:
		await process_frame
		frames += 1
		elapsed += maxf(_holder.get_process_delta_time(), 0.0)
		collector.advance_frame()
		for index in range(dummies.size()):
			if is_instance_valid(dummies[index]):
				(dummies[index] as Node2D).global_position = anchors[index]
	if elapsed < seconds:
		_errors.append("%s live simulation advanced %.2f/%.2fs" % [probe_phase, elapsed, seconds])
	return {"duration_seconds": elapsed, "frame_count": frames}


func _spawn_dummies(target_count: int) -> Array:
	var result := []
	for index in range(target_count):
		var enemy := ENEMY_SCENE.instantiate() as Node2D
		_holder.add_child(enemy)
		if target_count == 1:
			enemy.global_position = PLAYER_POSITION + SOLO_OFFSET
		else:
			var radius := 0.0 if index == 0 else PACK_RADIUS * (0.55 + 0.45 * sqrt(float(index) / float(TARGET_COUNT - 1)))
			var angle := 0.0 if index == 0 else float(index - 1) * 2.3999632
			enemy.global_position = PLAYER_POSITION + SOLO_OFFSET + Vector2.RIGHT.rotated(angle) * radius
		enemy.set("max_health", DUMMY_HP)
		enemy.set("health", DUMMY_HP)
		enemy.set("move_speed", 0.0)
		enemy.set("contact_damage", 0.0)
		result.append(enemy)
	return result


func _health_snapshot(nodes: Array) -> Array:
	var snapshot := []
	for node in nodes:
		snapshot.append(maxf(float(node.get("health")), 0.0) if is_instance_valid(node) else 0.0)
	return snapshot


# Mirrors tools/a5_balance_report.gd `_teardown`.
func _teardown() -> void:
	_teardown_holder()
	await process_frame
	await process_frame
	await process_frame


func _teardown_holder() -> void:
	if _holder == null:
		return
	for group_name in ["player_weapons", "allies", "engineer_devices", "player_weapon_effects"]:
		for member in get_nodes_in_group(group_name):
			if is_instance_valid(member):
				var node := member as Node
				node.process_mode = Node.PROCESS_MODE_DISABLED
				if node.has_method("cleanup_effects"):
					node.call("cleanup_effects")
	for child in _holder.get_children():
		if is_instance_valid(child):
			(child as Node).process_mode = Node.PROCESS_MODE_DISABLED
			(child as Node).queue_free()
