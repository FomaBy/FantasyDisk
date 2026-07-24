extends SceneTree

# FAN-1438: reproducible A5 roster report. One canonical dataset renders the
# Markdown, CSV, and raw JSON artifacts; production balance values are read-only.

const PD := preload("res://scripts/progression_data.gd")
const Meta := preload("res://scripts/meta_progression.gd")
const PlayerScript := preload("res://scripts/player.gd")
const Schema6 := preload("res://scripts/constellation_schema6_data.gd")
const FinalRuntime := preload("res://scripts/constellation_final_runtime.gd")
const MainScript := preload("res://scripts/main.gd")
const DamageTable := preload("res://tools/class_damage_table_3variants.gd")
const CodexData := preload("res://scripts/codex_data.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")

const ISSUE_ID := "FAN-1438"
const REPORT_DIR := "res://docs/design/reports/fan1438_a5_balance"
const REPORT_PATH := REPORT_DIR + "/report.md"
const CSV_PATH := REPORT_DIR + "/per_weapon.csv"
const RAW_PATH := REPORT_DIR + "/raw.json.gz"
const LEGACY_RAW_PATH := REPORT_DIR + "/raw.json"
const GZIP_ARTIFACT_SCRIPT := "res://tools/a5_gzip_artifact.py"
const LEVELS := [1, 20]
const LEVEL20_POINTS := 19
const TARGET_COUNT := 10
const SCENARIO_IDS := ["no_meta", "class_constellation", "class_atlas50", "class_atlas59_upper"]
const ATLAS50_EXCLUSIONS := ["atlas_m2", "atlas_m3", "atlas_k0"]
const NON_PLAYABLE_LABEL := "NON-PLAYABLE: cap 50"
const LIVE_SEEDS := [143801, 143802, 143803]
const LIVE_WARMUP_SECONDS := 2.0
const LIVE_WINDOW_SECONDS := 6.0
const DETERMINISTIC_MAX_FPS := 60
const LIVE_FIXED_DELTA := 1.0 / float(DETERMINISTIC_MAX_FPS)
const LIVE_WARMUP_FRAMES := 120
const LIVE_MEASUREMENT_FRAMES := 360
const OBSERVER_AB_SAMPLE_COUNT := 309
const MAX_LIVE_FRAMES := 2400
const DUMMY_HP := 1.0e9
const PLAYER_POSITION := Vector2(1280.0, 720.0)
const SOLO_OFFSET := Vector2(80.0, 0.0)
const PACK_RADIUS := 42.0
const A5_NORMAL_CONTACT_DAMAGE := 6.0
const A5_NORMAL_CONTACT_RATE := 5.0
const PLAYER_IFRAME_SECONDS := 0.32
const CLASS_CORRIDOR_LOWER := 0.80
const CLASS_CORRIDOR_UPPER := 1.20
const LIVE_TELEMETRY_SCHEMA := "fan1511.runtime-telemetry.v2"
const LIVE_TRACE_PREFIX := "fan1511"
const ORACLE_LINEAGE_PATH := "res://tests/fixtures/a5_oracle_lineage.json"
const ORACLE_LINEAGE_SCHEMA := "fan1641.a5-oracle-lineage.v1"
const PROJECTION_FIELDS := ["live_solo_dpm_mean", "live_crowd_dpm_mean", "solo_variance_dpm2", "crowd_variance_dpm2"]
const REPRESENTATIVE_CLASS_ID := "berserk"
const REPRESENTATIVE_WEAPON_ID := "sword"
const REPRESENTATIVE_SEED := 1511001
const MORTAL_TARGET_HP := 1.0

var _mode := "full"
var _source_commit := "UNSPECIFIED"
var _source_tree := ""
var _source_timestamp := ""
var _observer_mode := "enabled"
var _holder: Node2D
var _errors := PackedStringArray()


class A5TelemetryCollector extends RefCounted:
	var trace_id := ""
	var sample_key := ""
	var phase := "warmup"
	var frame := 0
	var events: Array = []
	var _target_labels := {}
	var _pending_final_events_by_provenance := {}
	var _last_hit_by_target := {}
	var _measurement_ledger_by_target := {}
	var _canonical_batches_by_target := {}
	var _incoming_fixture_active := false

	func _init(trace_id_value: String, sample_key_value: String) -> void:
		trace_id = trace_id_value
		sample_key = sample_key_value

	func bind_target(target: Node2D, label: String) -> void:
		if target != null:
			_target_labels[target.get_instance_id()] = label

	func set_phase(value: String) -> void:
		if phase != value:
			_flush_canonical_batches()
		phase = value

	func advance_frame() -> void:
		frame += 1

	func enable_incoming_fixture() -> void:
		_incoming_fixture_active = true

	func on_weapon_cast(raw_event: Dictionary) -> void:
		if str(raw_event.get("phase_source", "")) != "class_weapon" or str(raw_event.get("phase", "")) != "windup":
			return
		_append_event({
			"kind": "cast",
			"source": "player_weapon",
			"phase": "windup",
			"action_id": str(raw_event.get("action_id", "")),
			"cast_id": str(raw_event.get("telemetry_cast_id", "")),
			"attack_mode": str(raw_event.get("attack_mode", "")),
			"damage": 0.0,
		})

	func on_damage_applied(target: Node2D, _attempted_amount: float, applied_amount: float, feedback: Dictionary) -> void:
		if target == null or applied_amount <= 0.0:
			return
		var target_label := _target_label(target)
		if phase == "measurement":
			var ledger: Dictionary = _measurement_ledger_by_target.get(target_label, {"target_id": target_label, "applied_damage": 0.0, "entries": 0})
			ledger["applied_damage"] = float(ledger.get("applied_damage", 0.0)) + applied_amount
			ledger["entries"] = int(ledger.get("entries", 0)) + 1
			_measurement_ledger_by_target[target_label] = ledger
		var direct_final_mechanic := str(feedback.get("constellation_final", ""))
		# FAN-1539: the fixture is player-only. Legacy-unmarked secondary damage is
		# retained as an exact target/phase batch; tagged weapon hits remain individual.
		if not bool(feedback.get("player_owned", false)):
			_record_canonical_batch(target_label, applied_amount)
			if direct_final_mechanic != "":
				var batched_hit_id := _flush_canonical_batch(target_label)
				if batched_hit_id != "":
					var final_id := _append_event({"kind": "final_event", "source": "player_weapon", "phase": "final_damage_application", "target_id": target_label, "event": "damage_application", "mechanic_id": direct_final_mechanic, "related_hit_id": batched_hit_id, "observed": true, "damage": 0.0})
					_append_final_id_to_hit(batched_hit_id, final_id)
			return
		var provenance_id := str(feedback.get("telemetry_provenance_id", ""))
		if provenance_id == "":
			provenance_id = "canonical_%06d" % events.size()
		var event := {
			"kind": "hit",
			"source": "player_weapon",
			"phase": "damage_application",
			"target_id": target_label,
			"provenance_id": provenance_id,
			"cast_id": str(feedback.get("telemetry_cast_id", "")),
			# Preserve the canonical HP delta exactly; the ledger's 0.0001 tolerance
			# applies to the aggregate, not to a lossy per-hit projection.
			"damage": applied_amount,
		}
		var pending: Array = _pending_final_events_by_provenance.get(provenance_id, [])
		if not pending.is_empty():
			event["final_event_ids"] = pending.duplicate()
		var event_id := _append_event(event)
		_last_hit_by_target[target_label] = event_id
		if not pending.is_empty():
			for final_event_id_value in pending:
				_link_final_to_hit(str(final_event_id_value), event_id, target_label)
			_pending_final_events_by_provenance.erase(provenance_id)
		if direct_final_mechanic != "":
			var direct_final_id := _append_event({
				"kind": "final_event",
				"source": "player_weapon",
				"phase": "final_damage_application",
				"target_id": target_label,
				"event": "damage_application",
				"mechanic_id": direct_final_mechanic,
				"related_hit_id": event_id,
				"observed": true,
				"damage": 0.0,
			})
			_append_final_id_to_hit(event_id, direct_final_id)

	func _record_canonical_batch(target_label: String, applied_amount: float) -> void:
		var batch: Dictionary = _canonical_batches_by_target.get(target_label, {"damage": 0.0, "entries": 0})
		batch["damage"] = float(batch.get("damage", 0.0)) + applied_amount
		batch["entries"] = int(batch.get("entries", 0)) + 1
		_canonical_batches_by_target[target_label] = batch

	func _flush_canonical_batch(target_label: String) -> String:
		if not _canonical_batches_by_target.has(target_label):
			return ""
		var batch: Dictionary = _canonical_batches_by_target[target_label]
		_canonical_batches_by_target.erase(target_label)
		if float(batch.get("damage", 0.0)) <= 0.0:
			return ""
		var event_id := _append_event({"kind": "hit", "source": "player_weapon", "phase": "damage_application", "target_id": target_label, "provenance_id": "canonical_batch_%06d" % events.size(), "cast_id": "", "damage": float(batch["damage"]), "canonical_entry_count": int(batch["entries"])})
		_last_hit_by_target[target_label] = event_id
		return event_id

	func _flush_canonical_batches() -> void:
		for target_label_value in _canonical_batches_by_target.keys():
			_flush_canonical_batch(str(target_label_value))

	func on_final_resolution(_weapon_id: String, event_name: String, target: Node2D, context: Dictionary, resolution: Dictionary) -> void:
		if not bool(resolution.get("valid", false)) or not bool(resolution.get("triggered", false)):
			return
		var provenance_id := str(context.get("telemetry_provenance_id", ""))
		# Targetless/deferred resolver observations are not damage evidence. Their
		# later canonical payout is recorded from feedback.constellation_final.
		if target == null or provenance_id == "":
			return
		var target_label := _target_label(target)
		var event_id := _append_event({
			"kind": "final_event",
			"source": "player_weapon",
			"phase": "final_resolution",
			"target_id": target_label,
			"event": event_name,
			"mechanic_id": str(resolution.get("mechanic_id", "")),
			"final_activation_id": str(resolution.get("telemetry_final_activation_id", "")),
			"observed": true,
			"damage": 0.0,
		})
		var pending: Array = _pending_final_events_by_provenance.get(provenance_id, [])
		pending.append(event_id)
		_pending_final_events_by_provenance[provenance_id] = pending

	func on_target_died(target: Node2D) -> void:
		var target_label := _target_label(target)
		_flush_canonical_batch(target_label)
		var event := {
			"kind": "final_event",
			"source": "player_weapon",
			"phase": "target_death",
			"target_id": target_label,
			"event": "kill",
			"observed": true,
			"damage": 0.0,
		}
		if _last_hit_by_target.has(target_label):
			event["related_hit_id"] = str(_last_hit_by_target[target_label])
		var event_id := _append_event(event)
		if _last_hit_by_target.has(target_label):
			_append_final_id_to_hit(str(_last_hit_by_target[target_label]), event_id)

	func _link_final_to_hit(final_event_id: String, hit_event_id: String, target_label: String) -> void:
		for index in range(events.size()):
			var event: Dictionary = events[index]
			if str(event.get("event_id", "")) != final_event_id:
				continue
			event["related_hit_id"] = hit_event_id
			event["target_id"] = target_label
			events[index] = event
			_append_final_id_to_hit(hit_event_id, final_event_id)
			return

	func _append_final_id_to_hit(hit_event_id: String, final_event_id: String) -> void:
		for index in range(events.size()):
			var event: Dictionary = events[index]
			if str(event.get("event_id", "")) != hit_event_id:
				continue
			var final_ids: Array = event.get("final_event_ids", [])
			if not final_ids.has(final_event_id):
				final_ids.append(final_event_id)
				event["final_event_ids"] = final_ids
				events[index] = event
			return

	func on_player_damaged(applied_amount: float) -> void:
		if not _incoming_fixture_active or applied_amount <= 0.0:
			return
		_append_event({
			"kind": "hit",
			"source": "incoming_fixture",
			"phase": "incoming_damage",
			"target_id": "player",
			"damage": snappedf(applied_amount, 0.0001),
		})

	func build_sample(pair: String, seed_value: int, scenario_key: String, fixture: String, target_cardinality: int) -> Dictionary:
		_flush_canonical_batches()
		var hit_events := []
		var casts := 0
		var target_ids := {}
		var buckets := {}
		var final_events := []
		var event_by_id := {}
		for raw_event in events:
			var event: Dictionary = raw_event
			event_by_id[str(event.get("event_id", ""))] = event
			if str(event.get("kind", "")) == "cast":
				casts += 1
			if str(event.get("kind", "")) == "hit":
				hit_events.append(event)
				target_ids[str(event.get("target_id", ""))] = true
				var bucket_key := "%s|%s" % [event.get("source", ""), event.get("phase", "")]
				var bucket: Dictionary = buckets.get(bucket_key, {"source": event.get("source", ""), "phase": event.get("phase", ""), "damage": 0.0, "hits": 0})
				bucket["damage"] = float(bucket.get("damage", 0.0)) + float(event.get("damage", 0.0))
				bucket["hits"] = int(bucket.get("hits", 0)) + 1
				buckets[bucket_key] = bucket
			if str(event.get("kind", "")) == "final_event":
				final_events.append(event)
		var bucket_rows := buckets.values()
		bucket_rows.sort_custom(func(a, b): return "%s|%s" % [a["source"], a["phase"]] < "%s|%s" % [b["source"], b["phase"]])
		var unique_target_ids := target_ids.keys()
		unique_target_ids.sort()
		var final_damage := 0.0
		var tagged_hits := {}
		for final_event_value in final_events:
			var final_event: Dictionary = final_event_value
			var related_hit_id := str(final_event.get("related_hit_id", ""))
			if related_hit_id != "" and event_by_id.has(related_hit_id):
				tagged_hits[related_hit_id] = true
		for tagged_id in tagged_hits:
			if event_by_id.has(tagged_id) and str((event_by_id[tagged_id] as Dictionary).get("kind", "")) == "hit":
				final_damage += float((event_by_id[tagged_id] as Dictionary).get("damage", 0.0))
		var fixture_target_ids := []
		for index in range(target_cardinality):
			fixture_target_ids.append("player" if fixture == "incoming_hit" else "target_%d" % index)
		var ledger_rows := []
		var ledger_total := 0.0
		for target_id_value in fixture_target_ids:
			var target_id := str(target_id_value)
			var ledger: Dictionary = _measurement_ledger_by_target.get(target_id, {"target_id": target_id, "applied_damage": 0.0, "entries": 0})
			# Keep the ledger numerator at simulation precision. Rounding here used to
			# change a DPM projection after aggregation; presentation code owns rounding.
			ledger["applied_damage"] = float(ledger.get("applied_damage", 0.0))
			ledger_total += float(ledger["applied_damage"])
			ledger_rows.append(ledger)
		var result := {
			"telemetry_schema": LIVE_TELEMETRY_SCHEMA,
			"sample_key": sample_key,
			"trace_id": trace_id,
			"pair": pair,
			"seed": seed_value,
			"scenario": scenario_key,
			"fixture": fixture,
			"target_cardinality": target_cardinality,
			"fixture_target_ids": fixture_target_ids,
			"events": events,
			"hp_ledger": {
				"authority": "enemy_damage_applied_health_delta",
				"probe_phase": "measurement",
				"tolerance": 0.0001,
				"rows": ledger_rows,
				"total_applied_damage": ledger_total,
			},
			"counters": {
				"casts": casts,
				"hits": hit_events.size(),
				"unique_target_ids": unique_target_ids,
				"unique_target_count": unique_target_ids.size(),
				"damage_total": snappedf(_damage_total(bucket_rows), 0.0001),
				"damage_by_source_phase": bucket_rows,
				"final_event_count": final_events.size(),
				"final_event_damage": snappedf(final_damage, 0.0001),
			},
		}
		result["trace_digest_sha256"] = _digest(JSON.stringify(events, "", true, true))
		return result

	func _append_event(raw_event: Dictionary) -> String:
		var event := raw_event.duplicate(true)
		var event_id := "%s#%04d" % [trace_id, events.size()]
		event["event_id"] = event_id
		event["trace_id"] = trace_id
		event["frame"] = frame
		event["probe_phase"] = phase
		events.append(event)
		return event_id

	func _target_label(target: Node2D) -> String:
		if target == null:
			return "target_unknown"
		return str(_target_labels.get(target.get_instance_id(), "target_unknown"))

	func _damage_total(bucket_rows: Array) -> float:
		var total := 0.0
		for bucket_value in bucket_rows:
			total += float((bucket_value as Dictionary).get("damage", 0.0))
		return total

	func _digest(value: String) -> String:
		var context := HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		context.update(value.to_utf8_buffer())
		return context.finish().hex_encode()


func _initialize() -> void:
	_parse_args()
	await process_frame
	if _mode in ["full", "telemetry_probe", "observer_neutrality"]:
		# The live probe advances production _process callbacks. Cap that clock so
		# telemetry callback cost cannot change the number or duration of frames.
		Engine.max_fps = DETERMINISTIC_MAX_FPS
		_holder = Node2D.new()
		_holder.name = "FAN1438BalanceHolder"
		root.add_child(_holder)
		current_scene = _holder
		root.set_meta("aim_mode", "nearest")
		await process_frame
	if _mode == "telemetry_probe":
		await _run_representative_telemetry_probe()
		return
	if _mode == "observer_neutrality":
		await _run_observer_neutrality()
		return
	var dataset := await generate_dataset()
	if not _errors.is_empty():
		for error in _errors:
			push_error(error)
		quit(1)
		return
	# JSON is the canonical artifact. Normalize through the exact serializer before
	# calculating its digest or rendering projections so float representation cannot
	# make the canonical raw JSON disagree with CSV/Markdown after a parse round-trip.
	var normalized = JSON.parse_string(JSON.stringify(dataset, "\t", true, true))
	if not normalized is Dictionary:
		push_error("FAN-1511 cannot normalize the generated dataset through JSON")
		quit(1)
		return
	dataset = normalized as Dictionary
	var telemetry: Dictionary = dataset.get("live_telemetry", {})
	for sample_value in telemetry.get("samples", []):
		var sample: Dictionary = sample_value
		sample["trace_digest_sha256"] = _sha256(JSON.stringify(sample.get("events", []), "", true, true))
	dataset.erase("dataset_digest_sha256")
	dataset["dataset_digest_sha256"] = _sha256(JSON.stringify(dataset, "", true, true))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_DIR))
	var csv_text := render_csv(dataset)
	var markdown_text := render_markdown(dataset)
	var raw_text := JSON.stringify(dataset, "\t", true, true) + "\n"
	_write_text(CSV_PATH, csv_text)
	_write_text(REPORT_PATH, markdown_text)
	_write_raw_artifact(raw_text)
	if not _errors.is_empty():
		for error in _errors:
			push_error(error)
		quit(1)
		return
	print("FAN-1438 report generated: %d weapon rows, %d class rows, %d live parity rows." % [
		(dataset.get("weapon_rows", []) as Array).size(),
		(dataset.get("class_rows", []) as Array).size(),
		(dataset.get("formula_live_parity", []) as Array).size(),
	])
	quit(0)


func _parse_args() -> void:
	for raw_arg in OS.get_cmdline_user_args():
		var arg := str(raw_arg)
		if arg.begins_with("--mode="):
			_mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--source-commit="):
			_source_commit = arg.trim_prefix("--source-commit=")
		elif arg.begins_with("--source-tree=") or arg.begins_with("--source-timestamp="):
			_errors.append("%s is derived from --source-commit and cannot be overridden" % arg.get_slice("=", 0))
	if not ["formula", "full", "telemetry_probe", "observer_neutrality"].has(_mode):
		_errors.append("unsupported mode %s (expected formula, full, telemetry_probe, or observer_neutrality)" % _mode)


func _run_representative_telemetry_probe() -> void:
	var base_stats := PD.base_stats(REPRESENTATIVE_CLASS_ID)
	var stats := DamageTable.optimized_stats_for_class(REPRESENTATIVE_CLASS_ID, base_stats)
	var state := _scenario_state(REPRESENTATIVE_CLASS_ID, "class_constellation")
	var offensive: Dictionary = await _measure_live(REPRESENTATIVE_CLASS_ID, REPRESENTATIVE_WEAPON_ID, 1, stats, state, REPRESENTATIVE_SEED, "representative_offensive", "offensive")
	var mortal: Dictionary = await _measure_live(REPRESENTATIVE_CLASS_ID, REPRESENTATIVE_WEAPON_ID, 1, stats, state, REPRESENTATIVE_SEED, "representative_mortal", "mortal", MORTAL_TARGET_HP)
	var incoming: Dictionary = await _measure_incoming_fixture(stats, state)
	for sample_value in [offensive, mortal, incoming]:
		var sample: Dictionary = sample_value
		var verification := verify_live_telemetry_sample(sample)
		if not bool(verification.get("ok", false)):
			_errors.append("telemetry probe contract failed for %s: %s" % [sample.get("sample_key", "?"), "; ".join(verification.get("errors", []))])
	print("FAN-1511 telemetry probe: %s" % JSON.stringify({
		"offensive": {"dpm": offensive.get("dpm", -1.0), "counters": offensive.get("counters", {})},
		"mortal": {"dpm": mortal.get("dpm", -1.0), "counters": mortal.get("counters", {})},
		"incoming": {"dpm": incoming.get("dpm", -1.0), "counters": incoming.get("counters", {})},
	}, "", false, true))
	if not _errors.is_empty():
		for error in _errors:
			push_error(error)
		quit(1)
		return
	quit(0)


func _run_observer_neutrality() -> void:
	# FAN-1574: keep the authoritative applied-HP measurement witness wired in both
	# arms. The observer under test is a second, real production-signal subscriber
	# that exists only in the enabled arm. This preserves one ledger numerator and
	# one fixed-step schedule while proving the extra observer delivery is neutral.
	var enabled_samples := []
	var disabled_samples := []
	for class_id_value in PD.character_ids():
		var class_id := str(class_id_value)
		var state := _scenario_state(class_id, "class_constellation")
		var stats := DamageTable.optimized_stats_for_class(class_id, PD.base_stats(class_id))
		for weapon_id_value in PD.weapon_ids(class_id):
			var weapon_id := str(weapon_id_value)
			for seed_value in LIVE_SEEDS:
				for fixture_spec in [{"scenario": "observer_solo", "fixture": "sustain", "targets": 1}, {"scenario": "observer_pack", "fixture": "sustain", "targets": TARGET_COUNT}]:
					var scenario_key := str(fixture_spec["scenario"])
					var fixture := str(fixture_spec["fixture"])
					var targets := int(fixture_spec["targets"])
					disabled_samples.append(await _measure_observer_live(class_id, weapon_id, targets, stats, state, int(seed_value), scenario_key, fixture, false))
					enabled_samples.append(await _measure_observer_live(class_id, weapon_id, targets, stats, state, int(seed_value), scenario_key, fixture, true))
	var representative_state := _scenario_state(REPRESENTATIVE_CLASS_ID, "class_constellation")
	var representative_stats := DamageTable.optimized_stats_for_class(REPRESENTATIVE_CLASS_ID, PD.base_stats(REPRESENTATIVE_CLASS_ID))
	for fixture_spec in [
		{"scenario": "observer_representative_offensive", "fixture": "offensive", "targets": 1, "hp": DUMMY_HP},
		{"scenario": "observer_representative_mortal", "fixture": "mortal", "targets": 1, "hp": MORTAL_TARGET_HP},
	]:
		disabled_samples.append(await _measure_observer_live(REPRESENTATIVE_CLASS_ID, REPRESENTATIVE_WEAPON_ID, int(fixture_spec["targets"]), representative_stats, representative_state, REPRESENTATIVE_SEED, str(fixture_spec["scenario"]), str(fixture_spec["fixture"]), false, float(fixture_spec["hp"])))
		enabled_samples.append(await _measure_observer_live(REPRESENTATIVE_CLASS_ID, REPRESENTATIVE_WEAPON_ID, int(fixture_spec["targets"]), representative_stats, representative_state, REPRESENTATIVE_SEED, str(fixture_spec["scenario"]), str(fixture_spec["fixture"]), true, float(fixture_spec["hp"])))
	disabled_samples.append(await _measure_observer_incoming(representative_stats, representative_state, false))
	enabled_samples.append(await _measure_observer_incoming(representative_stats, representative_state, true))
	var verification := verify_observer_ab({"mode": "enabled", "samples": enabled_samples}, {"mode": "disabled", "samples": disabled_samples})
	if not bool(verification.get("ok", false)):
		for error_value in verification.get("errors", []):
			_errors.append("observer neutrality: %s" % error_value)
	else:
		print("FAN-1574 production observer A/B passed: %d enabled/disabled fixed-step samples, digest %s." % [
			enabled_samples.size(), verification.get("canonical_digest", "unknown"),
		])
	if not _errors.is_empty():
		for error_value in _errors:
			push_error(error_value)
		quit(1)
		return
	quit(0)


func _measure_observer_live(class_id: String, weapon_id: String, target_count: int, stats: Dictionary, state: Dictionary, seed_value: int, scenario_key: String, fixture: String, observer_enabled: bool, initial_target_hp := DUMMY_HP) -> Dictionary:
	await _teardown()
	seed(seed_value)
	var pair := "%s/%s" % [class_id, weapon_id]
	var sample_key := _telemetry_sample_key(pair, seed_value, scenario_key, fixture, target_count)
	var trace_id := "fan1574:%s" % sample_key
	var witness := A5TelemetryCollector.new(trace_id, sample_key)
	var observer: A5TelemetryCollector = A5TelemetryCollector.new(trace_id, sample_key) if observer_enabled else null
	var player := PLAYER_SCENE.instantiate() as Node2D
	_holder.add_child(player)
	if player == null or player.get_script() == null:
		_errors.append("%s/%s observer live Player failed to instantiate" % [class_id, weapon_id])
		return _failed_telemetry_sample(pair, seed_value, scenario_key, fixture, target_count, sample_key)
	player.add_to_group("player")
	player.global_position = PLAYER_POSITION
	player.call("configure_character", class_id, weapon_id)
	player.set("stats", stats.duplicate(true))
	player.call("_apply_stat_scaling", true)
	var main := MainScript.new()
	main.set("selected_character_id", class_id)
	main.set("selected_ascension_level", 5)
	main.set("selected_start_boon_id", "")
	main.set("meta_state", state.duplicate(true))
	main.set("run_sandbox_captured", false)
	main.call("apply_ascension_bonuses", player)
	main.free()
	player.set("max_health", DUMMY_HP)
	player.set("health", DUMMY_HP)
	player.connect("weapon_cast_observed", witness.on_weapon_cast)
	player.connect("constellation_final_resolved", witness.on_final_resolution)
	if observer != null:
		player.connect("weapon_cast_observed", observer.on_weapon_cast)
		player.connect("constellation_final_resolved", observer.on_final_resolution)
	await process_frame
	var dummies := _spawn_dummies(target_count)
	var anchors := []
	var observer_connected := observer != null
	for index in range(dummies.size()):
		var enemy := dummies[index] as Node2D
		witness.bind_target(enemy, "target_%d" % index)
		enemy.connect("damage_applied", witness.on_damage_applied)
		enemy.connect("died", witness.on_target_died)
		if observer != null:
			observer.bind_target(enemy, "target_%d" % index)
			enemy.connect("damage_applied", observer.on_damage_applied)
			enemy.connect("died", observer.on_target_died)
			observer_connected = observer_connected and enemy.is_connected("damage_applied", observer.on_damage_applied) and enemy.is_connected("died", observer.on_target_died)
		if initial_target_hp < DUMMY_HP:
			enemy.set("max_health", initial_target_hp)
			enemy.set("health", initial_target_hp)
		anchors.append(enemy.global_position)
	if observer != null:
		observer_connected = observer_connected and player.is_connected("weapon_cast_observed", observer.on_weapon_cast) and player.is_connected("constellation_final_resolved", observer.on_final_resolution)
	var collectors := [witness]
	if observer != null:
		collectors.append(observer)
	await _advance_fixed_live(LIVE_WARMUP_FRAMES, dummies, anchors, collectors, "warmup", "%s/%s" % [class_id, weapon_id])
	var before_health := _health_snapshot(dummies)
	var before := _total_health(dummies)
	var measurement: Dictionary = await _advance_fixed_live(LIVE_MEASUREMENT_FRAMES, dummies, anchors, collectors, "measurement", "%s/%s" % [class_id, weapon_id])
	var after_health := _health_snapshot(dummies)
	var after := _total_health(dummies)
	var sample := _finalize_observer_sample(witness.build_sample(pair, seed_value, scenario_key, fixture, target_count), before_health, after_health, before, after, measurement, observer_enabled)
	var observer_events := 0
	var observer_matches_witness := false
	if observer != null:
		var observer_sample := observer.build_sample(pair, seed_value, scenario_key, fixture, target_count)
		observer_events = (observer_sample.get("events", []) as Array).size()
		observer_matches_witness = _observer_callback_signature(observer_sample) == _observer_callback_signature(sample)
		if not observer_matches_witness:
			_errors.append("%s observer callback trace differs from production witness" % sample_key)
	sample["observer_delivery"] = {
		"mode": "enabled" if observer_enabled else "disabled",
		"enabled": observer_enabled,
		"subscription_count": 2 + target_count * 2 if observer_enabled else 0,
		"callback_event_count": observer_events,
		"callback_matches_witness": observer_matches_witness,
		"wiring_verified": observer_connected,
	}
	return sample


func _measure_observer_incoming(stats: Dictionary, state: Dictionary, observer_enabled: bool) -> Dictionary:
	await _teardown()
	seed(REPRESENTATIVE_SEED)
	var pair := "%s/%s" % [REPRESENTATIVE_CLASS_ID, REPRESENTATIVE_WEAPON_ID]
	var sample_key := _telemetry_sample_key(pair, REPRESENTATIVE_SEED, "observer_representative_incoming", "incoming_hit", 1)
	var trace_id := "fan1574:%s" % sample_key
	var witness := A5TelemetryCollector.new(trace_id, sample_key)
	var observer: A5TelemetryCollector = A5TelemetryCollector.new(trace_id, sample_key) if observer_enabled else null
	var player := PLAYER_SCENE.instantiate() as Node2D
	_holder.add_child(player)
	if player == null or player.get_script() == null:
		_errors.append("observer incoming fixture Player failed to instantiate")
		return _failed_telemetry_sample(pair, REPRESENTATIVE_SEED, "observer_representative_incoming", "incoming_hit", 1, sample_key)
	player.add_to_group("player")
	player.global_position = PLAYER_POSITION
	player.call("configure_character", REPRESENTATIVE_CLASS_ID, REPRESENTATIVE_WEAPON_ID)
	player.set("stats", stats.duplicate(true))
	player.call("_apply_stat_scaling", true)
	var main := MainScript.new()
	main.set("selected_character_id", REPRESENTATIVE_CLASS_ID)
	main.set("selected_ascension_level", 5)
	main.set("selected_start_boon_id", "")
	main.set("meta_state", state.duplicate(true))
	main.set("run_sandbox_captured", false)
	main.call("apply_ascension_bonuses", player)
	main.free()
	player.set("max_health", DUMMY_HP)
	player.set("health", DUMMY_HP)
	var parameters: Dictionary = player.get("derived_parameters")
	parameters["dodge"] = 0.0
	player.set("derived_parameters", parameters)
	witness.enable_incoming_fixture()
	player.connect("damaged", witness.on_player_damaged)
	var observer_connected := observer != null
	if observer != null:
		observer.enable_incoming_fixture()
		player.connect("damaged", observer.on_player_damaged)
		observer_connected = player.is_connected("damaged", observer.on_player_damaged)
	var collectors := [witness]
	if observer != null:
		collectors.append(observer)
	await _advance_fixed_live(LIVE_WARMUP_FRAMES, [], [], collectors, "warmup", "incoming fixture")
	for collector_value in collectors:
		(collector_value as A5TelemetryCollector).set_phase("measurement")
	var before_health := [float(player.get("health"))]
	player.call("take_damage", A5_NORMAL_CONTACT_DAMAGE, "fan1574_deterministic_incoming")
	var measurement: Dictionary = await _advance_fixed_live(LIVE_MEASUREMENT_FRAMES, [], [], collectors, "measurement", "incoming fixture")
	var after_health := [float(player.get("health"))]
	var before := float(before_health[0])
	var after := float(after_health[0])
	var sample := _finalize_observer_sample(witness.build_sample(pair, REPRESENTATIVE_SEED, "observer_representative_incoming", "incoming_hit", 1), before_health, after_health, before, after, measurement, observer_enabled)
	var observer_events := 0
	var observer_matches_witness := false
	if observer != null:
		var observer_sample := observer.build_sample(pair, REPRESENTATIVE_SEED, "observer_representative_incoming", "incoming_hit", 1)
		observer_events = (observer_sample.get("events", []) as Array).size()
		observer_matches_witness = _observer_callback_signature(observer_sample) == _observer_callback_signature(sample)
		if not observer_matches_witness:
			_errors.append("%s observer callback trace differs from production witness" % sample_key)
	sample["observer_delivery"] = {
		"mode": "enabled" if observer_enabled else "disabled",
		"enabled": observer_enabled,
		"subscription_count": 1 if observer_enabled else 0,
		"callback_event_count": observer_events,
		"callback_matches_witness": observer_matches_witness,
		"wiring_verified": observer_connected,
	}
	return sample


func _advance_fixed_live(frame_count: int, dummies: Array, anchors: Array, collectors: Array, probe_phase: String, label: String) -> Dictionary:
	for collector_value in collectors:
		(collector_value as A5TelemetryCollector).set_phase(probe_phase)
	for _frame in range(frame_count):
		await process_frame
		var process_delta := _holder.get_process_delta_time()
		if absf(process_delta - LIVE_FIXED_DELTA) > 0.00001:
			_errors.append("%s fixed-step delta %.8f differs from 1/%d" % [label, process_delta, DETERMINISTIC_MAX_FPS])
		for collector_value in collectors:
			(collector_value as A5TelemetryCollector).advance_frame()
		for index in range(dummies.size()):
			if is_instance_valid(dummies[index]):
				(dummies[index] as Node2D).global_position = anchors[index]
	return {"duration_seconds": frame_count * LIVE_FIXED_DELTA, "frame_count": frame_count}


func _finalize_observer_sample(sample: Dictionary, before_health: Array, after_health: Array, before: float, after: float, measurement: Dictionary, observer_enabled: bool) -> Dictionary:
	var hp_ledger: Dictionary = sample.get("hp_ledger", {})
	var ledger_rows: Array = hp_ledger.get("rows", [])
	var snapshot_count := mini(ledger_rows.size(), mini(before_health.size(), after_health.size()))
	for index in range(snapshot_count):
		var row: Dictionary = ledger_rows[index]
		row["health_before"] = float(before_health[index])
		row["health_after"] = float(after_health[index])
		row["health_loss"] = maxf(float(before_health[index]) - float(after_health[index]), 0.0)
		ledger_rows[index] = row
	var measurement_duration := float(measurement.get("duration_seconds", 0.0))
	var health_delta := maxf(before - after, 0.0)
	var ledger_total := float(hp_ledger.get("total_applied_damage", 0.0))
	hp_ledger["rows"] = ledger_rows
	hp_ledger["canonical_numerator"] = "ledger_total"
	hp_ledger["measurement_duration_seconds"] = measurement_duration
	hp_ledger["measurement_duration_snapped_seconds"] = snappedf(measurement_duration, 0.0001)
	hp_ledger["measurement_frame_count"] = int(measurement.get("frame_count", 0))
	hp_ledger["legacy_health_delta_numerator"] = health_delta
	hp_ledger["dpm_projections"] = {
		"legacy_hp_delta_raw_duration_dpm": _project_dpm(health_delta, measurement_duration),
		"ledger_raw_duration_dpm": _project_dpm(ledger_total, measurement_duration),
		"ledger_snapped_duration_dpm": _project_dpm(ledger_total, snappedf(measurement_duration, 0.0001)),
		"ledger_minus_legacy_numerator": ledger_total - health_delta,
	}
	sample["hp_ledger"] = hp_ledger
	sample["observer_probe"] = {
		"mode": "enabled" if observer_enabled else "disabled",
		"measurement_duration_seconds": measurement_duration,
		"measurement_frame_count": int(measurement.get("frame_count", 0)),
		"health_before": before_health,
		"health_after": after_health,
		"health_delta": health_delta,
		"rng_probe": randi(),
	}
	# Disabled never substitutes health_delta: both arms project from the same
	# authoritative applied-HP ledger captured by the invariant witness.
	sample["dpm"] = _project_dpm(ledger_total, measurement_duration)
	return sample


static func _observer_callback_signature(sample: Dictionary) -> String:
	# This checks the optional subscriber's actual production callback input. The
	# witness alone owns the later snapshot/window enrichment of its HP ledger.
	return JSON.stringify({"events": sample.get("events", []), "counters": sample.get("counters", {})}, "", true, true)


static func _observer_canonical_signature(sample: Dictionary) -> String:
	var observer_probe: Dictionary = (sample.get("observer_probe", {}) as Dictionary).duplicate(true)
	observer_probe.erase("mode")
	return JSON.stringify({
		"sample_key": sample.get("sample_key", ""), "pair": sample.get("pair", ""), "seed": sample.get("seed", -1),
		"scenario": sample.get("scenario", ""), "fixture": sample.get("fixture", ""), "target_cardinality": sample.get("target_cardinality", -1),
		"events": sample.get("events", []), "hp_ledger": sample.get("hp_ledger", {}), "counters": sample.get("counters", {}),
		"dpm": sample.get("dpm", NAN), "observer_probe": observer_probe,
	}, "", true, true)


static func observer_expected_sample_keys() -> Dictionary:
	# Keep the 309-sample observer oracle tied to the same canonical roster,
	# seeds, fixtures, and target cardinalities that _run_observer_neutrality
	# executes. A count-only check could otherwise accept a substituted manifest.
	var expected := {}
	for class_id_value in PD.character_ids():
		var class_id := str(class_id_value)
		for weapon_id_value in PD.weapon_ids(class_id):
			var pair := "%s/%s" % [class_id, str(weapon_id_value)]
			for seed_value in LIVE_SEEDS:
				expected[_telemetry_sample_key(pair, int(seed_value), "observer_solo", "sustain", 1)] = true
				expected[_telemetry_sample_key(pair, int(seed_value), "observer_pack", "sustain", TARGET_COUNT)] = true
	var representative_pair := "%s/%s" % [REPRESENTATIVE_CLASS_ID, REPRESENTATIVE_WEAPON_ID]
	expected[_telemetry_sample_key(representative_pair, REPRESENTATIVE_SEED, "observer_representative_offensive", "offensive", 1)] = true
	expected[_telemetry_sample_key(representative_pair, REPRESENTATIVE_SEED, "observer_representative_mortal", "mortal", 1)] = true
	expected[_telemetry_sample_key(representative_pair, REPRESENTATIVE_SEED, "observer_representative_incoming", "incoming_hit", 1)] = true
	return expected


static func _observer_sample_identity_key(sample: Dictionary) -> String:
	return _telemetry_sample_key(
		str(sample.get("pair", "")),
		int(sample.get("seed", -1)),
		str(sample.get("scenario", "")),
		str(sample.get("fixture", "")),
		int(sample.get("target_cardinality", -1)),
	)


static func verify_observer_ab(enabled: Dictionary, disabled: Dictionary) -> Dictionary:
	var errors := PackedStringArray()
	if str(enabled.get("mode", "")) != "enabled" or str(disabled.get("mode", "")) != "disabled":
		errors.append("enabled and disabled observer baselines are required")
	var enabled_samples: Array = enabled.get("samples", [])
	var disabled_samples: Array = disabled.get("samples", [])
	if enabled_samples.size() != OBSERVER_AB_SAMPLE_COUNT or disabled_samples.size() != OBSERVER_AB_SAMPLE_COUNT:
		errors.append("observer A/B requires exactly %d samples per arm" % [OBSERVER_AB_SAMPLE_COUNT])
	var sample_count := mini(enabled_samples.size(), disabled_samples.size())
	var enabled_keys := {}
	var disabled_keys := {}
	var expected_keys := observer_expected_sample_keys()
	var canonical := ""
	for index in range(sample_count):
		var enabled_sample: Dictionary = enabled_samples[index]
		var disabled_sample: Dictionary = disabled_samples[index]
		var enabled_key := str(enabled_sample.get("sample_key", ""))
		var disabled_key := str(disabled_sample.get("sample_key", ""))
		if enabled_key.is_empty() or enabled_key != disabled_key or enabled_keys.has(enabled_key) or disabled_keys.has(disabled_key):
			errors.append("observer A/B sample identity is missing, duplicated, or mismatched at index %d" % index)
		enabled_keys[enabled_key] = true
		disabled_keys[disabled_key] = true
		if enabled_key != _observer_sample_identity_key(enabled_sample) or disabled_key != _observer_sample_identity_key(disabled_sample):
			errors.append("observer A/B sample key does not match its production identity at index %d" % index)
		for arm_value in [{"sample": enabled_sample, "enabled": true, "name": "enabled"}, {"sample": disabled_sample, "enabled": false, "name": "disabled"}]:
			var sample: Dictionary = arm_value["sample"]
			var expected_enabled := bool(arm_value["enabled"])
			var delivery: Dictionary = sample.get("observer_delivery", {})
			if bool(delivery.get("enabled", not expected_enabled)) != expected_enabled or str(delivery.get("mode", "")) != str(arm_value["name"]):
				errors.append("%s observer delivery mode is not explicit for %s" % [arm_value["name"], enabled_key])
			if expected_enabled and (int(delivery.get("subscription_count", 0)) <= 0 or int(delivery.get("callback_event_count", 0)) <= 0 or not bool(delivery.get("callback_matches_witness", false)) or not bool(delivery.get("wiring_verified", false))):
				errors.append("enabled observer has no verified production signal delivery for %s" % enabled_key)
			if not expected_enabled and (int(delivery.get("subscription_count", -1)) != 0 or int(delivery.get("callback_event_count", -1)) != 0 or bool(delivery.get("wiring_verified", true))):
				errors.append("disabled observer still receives production signal delivery for %s" % disabled_key)
			var ledger: Dictionary = sample.get("hp_ledger", {})
			var duration := float(ledger.get("measurement_duration_seconds", -1.0))
			if str(ledger.get("canonical_numerator", "")) != "ledger_total" or int(ledger.get("measurement_frame_count", -1)) != LIVE_MEASUREMENT_FRAMES or not is_equal_approx(duration, LIVE_MEASUREMENT_FRAMES * LIVE_FIXED_DELTA):
				errors.append("%s does not preserve the canonical fixed ledger window" % enabled_key)
			var projections: Dictionary = ledger.get("dpm_projections", {})
			if not is_equal_approx(float(sample.get("dpm", NAN)), _project_dpm(float(ledger.get("total_applied_damage", NAN)), duration)) or not is_equal_approx(float(projections.get("ledger_raw_duration_dpm", NAN)), float(sample.get("dpm", NAN))):
				errors.append("%s canonical DPM is not ledger/raw-duration" % enabled_key)
			var probe: Dictionary = sample.get("observer_probe", {})
			if not probe.has("rng_probe") or int(probe.get("measurement_frame_count", -1)) != LIVE_MEASUREMENT_FRAMES or not is_equal_approx(float(probe.get("measurement_duration_seconds", -1.0)), duration):
				errors.append("%s lacks fixed-step RNG/timing evidence" % enabled_key)
		var enabled_signature := _observer_canonical_signature(enabled_sample)
		var disabled_signature := _observer_canonical_signature(disabled_sample)
		if enabled_signature != disabled_signature:
			errors.append("production observer A/B drifted for %s" % enabled_key)
		canonical += enabled_signature + "\n"
	for expected_key_value in expected_keys:
		var expected_key := str(expected_key_value)
		if not enabled_keys.has(expected_key):
			errors.append("enabled observer A/B manifest is missing %s" % expected_key)
		if not disabled_keys.has(expected_key):
			errors.append("disabled observer A/B manifest is missing %s" % expected_key)
	for enabled_key_value in enabled_keys:
		if not expected_keys.has(enabled_key_value):
			errors.append("enabled observer A/B manifest has unexpected %s" % enabled_key_value)
	for disabled_key_value in disabled_keys:
		if not expected_keys.has(disabled_key_value):
			errors.append("disabled observer A/B manifest has unexpected %s" % disabled_key_value)
	return {"ok": errors.is_empty(), "errors": errors, "canonical_digest": _sha256(canonical) if not canonical.is_empty() else ""}


func generate_dataset() -> Dictionary:
	if not _resolve_source_provenance():
		return {}
	var class_ids: Array = PD.character_ids()
	var pair_keys := []
	var builds := {}
	for class_id_value in class_ids:
		var class_id := str(class_id_value)
		for weapon_id_value in PD.weapon_ids(class_id):
			pair_keys.append("%s/%s" % [class_id, str(weapon_id_value)])
		var base_stats := PD.base_stats(class_id)
		var level20_stats := DamageTable.optimized_stats_for_class(class_id, base_stats)
		builds[class_id] = {
			"level1_stats": base_stats,
			"level20_stats": level20_stats,
			"level20_delta": _stat_delta(base_stats, level20_stats),
			"level20_points": _delta_sum(base_stats, level20_stats),
			"model": "synthetic shared class-trio allocation",
		}

	var scenarios := _scenario_manifest()
	var meta_builds := _meta_build_manifest(class_ids)
	var weapon_rows := []
	for class_id_value in class_ids:
		var class_id := str(class_id_value)
		for level in LEVELS:
			var stats: Dictionary = (builds[class_id]["level1_stats"] if level == 1 else builds[class_id]["level20_stats"]).duplicate(true)
			for scenario_id in SCENARIO_IDS:
				var state := _scenario_state(class_id, scenario_id)
				for weapon_id_value in PD.weapon_ids(class_id):
					weapon_rows.append(_weapon_row(class_id, str(weapon_id_value), level, scenario_id, stats, state, scenarios[scenario_id]))
	_apply_baseline_deltas(weapon_rows)
	_apply_atlas_deltas(weapon_rows)
	var class_rows := _class_rows(class_ids, weapon_rows)
	_apply_class_relative_scores(class_rows)
	var parity := []
	var live_telemetry := {
		"schema": LIVE_TELEMETRY_SCHEMA,
		"trace_id_format": "%s:<pair>|<seed>|<scenario>|<fixture>|<target-cardinality>" % LIVE_TRACE_PREFIX,
		"samples": [],
		"representative_fixtures": [],
	}
	if _mode == "full":
		var live_evidence: Dictionary = await _live_parity(class_ids, builds, weapon_rows)
		parity = live_evidence.get("parity", [])
		live_telemetry = live_evidence.get("telemetry", live_telemetry)
		_apply_live_evidence_to_rows(weapon_rows, parity)

	var methodology := {
		"ascension": "selected A5 and cumulative earned A1-A5 class rewards (reward tier 5)",
		"level1": "base stats; zero level-up points, artifacts, shop upgrades, boons, challenges, or sandbox modifiers",
		"level20": "exactly 19 nonnegative integer points across canonical base stats, greedily maximizing the mean normalized output of the class's three weapons; one shared allocation per class",
		"weapon_dpm": "canonical ProgressionData estimator with A5/meta run modifiers and include_ultimate=false; schema-6 owning-weapon flat/cadence/geometry/axis/final factors layered from the canonical profile",
		"modifier_order": "ascension reward multipliers multiply and flats add; A5 reward/healing/max-HP multipliers then apply; meta fractions become 1+sum and multiply the matching run modifier; flats add; owning-weapon profile remains isolated by exact weapon_id",
		"ultimate": "class-kit-only first-minute formula starts from unmodified level stats and applies class/Atlas attribute and run modifiers exactly once; it is never attributed to a weapon row",
		"targets": {"solo": [SOLO_OFFSET.x, SOLO_OFFSET.y], "pack_count": TARGET_COUNT, "pack_radius": PACK_RADIUS, "layout": "one primary east target plus deterministic compact golden-angle pack"},
		"live": {"mode": _mode, "seeds": LIVE_SEEDS, "runs": LIVE_SEEDS.size(), "warmup_seconds": LIVE_WARMUP_SECONDS, "measurement_seconds": LIVE_WINDOW_SECONDS, "dummy_hp": DUMMY_HP, "stationary": true, "telemetry_schema": LIVE_TELEMETRY_SCHEMA, "telemetry_source": "runtime signals: weapon phase, applied enemy damage, final resolution, player damage"},
		"survivability": {"threat": "normal-wave contact pressure only", "base_hit": A5_NORMAL_CONTACT_DAMAGE, "attempted_hits_per_second": A5_NORMAL_CONTACT_RATE, "player_iframe_seconds": PLAYER_IFRAME_SECONDS, "a5_enemy_damage_multiplier": PD.ascension_difficulty_mods(5).get("enemy_damage_mult", 1.0), "order": "flat absorb (42% hit floor), defense, expected dodge, sustain; one death-save event is added separately"},
	}
	var dataset := {
		"schema": "fan1438.a5-balance.v2",
		"issue_id": ISSUE_ID,
		"source": {"commit": _source_commit, "tree": _source_tree, "commit_timestamp": _source_timestamp, "godot": Engine.get_version_info().get("string", "unknown")},
		"generation_command": "python3 tools/godot_gate.py --headless --fixed-fps 60 --path . --script res://tools/a5_balance_report.gd -- --mode=full --source-commit=<A>",
		"roster": {"class_ids": class_ids, "pair_keys": pair_keys, "class_count": class_ids.size(), "weapon_pair_count": pair_keys.size()},
		"methodology": methodology,
		"builds": builds,
		"meta_builds": meta_builds,
		"scenarios": scenarios,
		"weapon_rows": weapon_rows,
		"class_rows": class_rows,
		"formula_live_parity": parity,
		"live_telemetry": live_telemetry,
		"outliers": _outliers(class_rows, parity),
		"limitations": [
			"The level-20 model is a synthetic 19-base-stat-point balance convention, not a replay of 19 live reward-card choices.",
			"Selected A5 and earned reward tier are separate runtime states; this controlled report intentionally sets both to 5.",
			"Sustained parity probes use infinite-HP dummies; the separate mortal-target representative fixture records an observed kill event, but it is not a full final-mechanic reconciliation across all 51 pairs.",
			"Control, taunt, timed absorb, one-hit wards, and enemy damage suppression are reported as conditional utility and are not silently converted into permanent shield HP.",
			"A5 survival uses normal-wave global damage scaling. Bosses/elites have different runtime consumers and are not conflated with this threat.",
		],
	}
	dataset["dataset_digest_sha256"] = _sha256(JSON.stringify(dataset, "", true, true))
	_validate_dataset(dataset)
	return dataset


func _resolve_source_provenance() -> bool:
	var result := resolve_source_provenance(_source_commit)
	if not bool(result.get("ok", false)):
		_errors.append(str(result.get("error", "cannot resolve source provenance")))
		return false
	var source: Dictionary = result.get("source", {})
	_source_commit = str(source.get("commit", ""))
	_source_tree = str(source.get("tree", ""))
	_source_timestamp = str(source.get("commit_timestamp", ""))
	return true


static func resolve_source_provenance(source_commit: String) -> Dictionary:
	var requested := source_commit.strip_edges()
	if requested.is_empty() or requested == "UNSPECIFIED":
		return {"ok": false, "error": "--source-commit must name an exact Git commit"}
	var output := []
	var exit_code := OS.execute("git", ["show", "-s", "--format=%H%n%T%n%cI", requested], output, false)
	if exit_code != 0:
		return {"ok": false, "error": "cannot resolve Git source commit %s (git show exit %d)" % [requested, exit_code]}
	var fields := "".join(PackedStringArray(output)).strip_edges().split("\n", false)
	if fields.size() != 3:
		return {"ok": false, "error": "Git source provenance for %s is malformed" % requested}
	var source := {"commit": str(fields[0]), "tree": str(fields[1]), "commit_timestamp": str(fields[2])}
	if not _is_git_object_id(str(source["commit"])) or not _is_git_object_id(str(source["tree"])) or not _is_iso_timestamp(str(source["commit_timestamp"])):
		return {"ok": false, "error": "Git source provenance for %s is incomplete or malformed" % requested}
	return {"ok": true, "source": source}


static func verify_source_provenance(source: Dictionary) -> Dictionary:
	var result := resolve_source_provenance(str(source.get("commit", "")))
	if not bool(result.get("ok", false)):
		return result
	var expected: Dictionary = result.get("source", {})
	for field in ["commit", "tree", "commit_timestamp"]:
		if str(source.get(field, "")) != str(expected.get(field, "")):
			return {"ok": false, "error": "source %s does not match its Git commit" % field}
	return {"ok": true, "source": expected}


static func _is_git_object_id(value: String) -> bool:
	if value.length() != 40:
		return false
	for character in value:
		if not (character >= "0" and character <= "9") and not (character >= "a" and character <= "f"):
			return false
	return true


static func _is_iso_timestamp(value: String) -> bool:
	return value.length() >= 20 and value.contains("T") and (value.ends_with("Z") or value.contains("+"))


func _scenario_manifest() -> Dictionary:
	var atlas_paid := _atlas_paid_ids()
	var atlas50 := []
	for node_id in atlas_paid:
		if not ATLAS50_EXCLUSIONS.has(str(node_id)):
			atlas50.append(str(node_id))
	return {
		"no_meta": {"label": "No meta control", "playable": true, "class_spend": 0, "atlas_spend": 0, "atlas_ids": [], "hidden_conditions": []},
		"class_constellation": {"label": "Full class constellation (schema 6)", "playable": true, "class_spend": 20, "atlas_spend": 0, "atlas_ids": [], "hidden_conditions": ["both class hidden reveal facts explicitly true"]},
		"class_atlas50": {"label": "Full class + legal Guild Atlas 50", "playable": true, "class_spend": 20, "atlas_spend": _node_cost(atlas50), "atlas_ids": atlas50, "excluded_ids": ATLAS50_EXCLUSIONS, "hidden_conditions": ["all canonical monster Codex entries discovered", "secret boss defeated"]},
		"class_atlas59_upper": {"label": NON_PLAYABLE_LABEL, "playable": false, "class_spend": 20, "atlas_spend": _node_cost(atlas_paid), "atlas_ids": atlas_paid, "hidden_conditions": ["all canonical monster Codex entries discovered", "secret boss defeated"]},
	}


func _meta_build_manifest(class_ids: Array) -> Dictionary:
	var result := {}
	for class_id_value in class_ids:
		var class_id := str(class_id_value)
		var purchased := []
		var hidden := []
		var core := ""
		for raw_node in Meta.constellation_nodes(class_id):
			var node: Dictionary = raw_node
			var node_id := str(node.get("id", ""))
			if str(node.get("role", "")) == "core":
				core = node_id
			else:
				purchased.append(node_id)
			if str(node.get("role", "")) == "hidden":
				hidden.append(node_id)
		purchased.sort()
		hidden.sort()
		result[class_id] = {"free_core_id": core, "purchased_ids": purchased, "spend": _node_cost(purchased), "hidden_reveal_facts": hidden, "weapon_profile_node_ids": {}}
		var state := _scenario_state(class_id, "class_constellation")
		for weapon_id_value in PD.weapon_ids(class_id):
			var weapon_id := str(weapon_id_value)
			result[class_id]["weapon_profile_node_ids"][weapon_id] = Meta.skill_modifiers_for_weapon(state, class_id, weapon_id).get("node_ids", [])
	return result


func _scenario_state(class_id: String, scenario_id: String) -> Dictionary:
	var state := Meta.default_state()
	state["ascension_levels"] = {class_id: 5}
	if scenario_id == "no_meta":
		return state
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
	if scenario_id in ["class_atlas50", "class_atlas59_upper"]:
		var ids := _atlas_paid_ids()
		for node_id in ids:
			if scenario_id == "class_atlas50" and ATLAS50_EXCLUSIONS.has(str(node_id)):
				continue
			purchased.append(str(node_id))
		var monster_ids := []
		for raw_monster in CodexData.monsters():
			monster_ids.append(str((raw_monster as Dictionary).get("id", "")))
		state["discovered_monsters"] = monster_ids
		state["secret_boss_defeated"] = true
	state["skill_nodes"] = purchased
	return state


func _weapon_row(class_id: String, weapon_id: String, level: int, scenario_id: String, raw_stats: Dictionary, state: Dictionary, scenario: Dictionary) -> Dictionary:
	var stats := raw_stats.duplicate(true)
	var run_mods := _a5_run_modifiers(class_id)
	var skill_mods := {}
	var profile := {}
	if scenario_id != "no_meta":
		skill_mods = Meta.skill_modifiers_for_class(state, class_id)
		_apply_meta_formula_mods(stats, run_mods, skill_mods)
		profile = Meta.skill_modifiers_for_weapon(state, class_id, weapon_id)
	var config := PD.weapon(class_id, weapon_id)
	var base_metrics := PD.estimate_weapon_budget_for_stats(class_id, config, stats, true, run_mods, false)
	var crowd_metrics := PD.estimate_crowd_clear_budget_for_stats(class_id, config, TARGET_COUNT, stats, true, run_mods, false)
	var profile_factors := _profile_factors(class_id, weapon_id, config, stats, run_mods, profile)
	var solo_dps := float(base_metrics.get("solo_dps", 0.0)) * float(profile_factors.get("solo", 1.0))
	var crowd_dps := float(crowd_metrics.get("crowd_dps", 0.0)) * float(profile_factors.get("crowd", 1.0))
	var params := PD.derived_parameters(stats, run_mods, _config_with_class(config, class_id))
	var survival := _survival_metrics(config, params, run_mods, skill_mods, profile)
	var branch := _schema_branch(class_id, weapon_id)
	var final_node := _final_node(branch)
	return {
		"key": "%s|%s|%d|%s" % [class_id, weapon_id, level, scenario_id],
		"class_id": class_id,
		"weapon_id": weapon_id,
		"level": level,
		"scenario": scenario_id,
		"scenario_label": scenario.get("label", scenario_id),
		"playable": bool(scenario.get("playable", true)),
		"attack_mode": str(config.get("attack_mode", config.get("attack_shape", "single"))),
		"archetype": PD.weapon_archetype(config),
		"axis": str(branch.get("axis", "")),
		"identity": str(branch.get("identity", "")),
		"playstyle": str(branch.get("identity", "")),
		"strengths": _weapon_strength(str(branch.get("axis", "")), str(branch.get("identity", ""))),
		"weaknesses": _weapon_weakness(str(branch.get("axis", ""))),
		"final_mechanic": str(final_node.get("mechanic_id", "none")),
		"final_event": str(FinalRuntime.EVENT_BY_MECHANIC.get(str(final_node.get("mechanic_id", "")), "none")),
		"stats": stats,
		"stat_delta": _stat_delta(PD.base_stats(class_id), raw_stats),
		"solo_dpm": snappedf(solo_dps * 60.0, 0.01),
		"crowd_10_total_dpm": snappedf(crowd_dps * 60.0, 0.01),
		"crowd_10_per_target_dpm": snappedf(crowd_dps * 6.0, 0.01),
		"profile_factors": profile_factors,
		"ultimate_included": false,
		"hp": survival["hp"], "defense": survival["defense"], "dodge": survival["dodge"],
		"absorb_flat": survival["absorb_flat"], "conditional_shield_capacity": survival["conditional_shield_capacity"],
		"regeneration_per_second": survival["regeneration_per_second"], "lifesteal_per_second": survival["lifesteal_per_second"],
		"mitigation": survival["mitigation"], "ehp": survival["ehp"], "ttd_seconds": survival["ttd_seconds"],
		"conditional_defense_factor": survival["conditional_defense_factor"],
		"pickup_radius": snappedf(float(params.get("pickup_radius", 0.0)), 0.01),
		"move_speed": snappedf(float(params.get("move_speed", 0.0)), 0.01),
		"healing_multiplier": snappedf(float(run_mods.get("healing_multiplier", 1.0)) * (1.0 + float(skill_mods.get("healing_mult", 0.0))), 0.001),
		"xp_multiplier": snappedf(float(run_mods.get("xp_gain_multiplier", 1.0)) * (1.0 + float(skill_mods.get("xp_gain_mult", 0.0))), 0.001),
		"money_multiplier": snappedf(float(run_mods.get("money_gain_multiplier", 1.0)) * (1.0 + float(skill_mods.get("money_gain_mult", 0.0))), 0.001),
		"start_gold": snappedf(float(skill_mods.get("start_gold_flat", 0.0)), 0.01),
		"ult_start_charge": snappedf(float(skill_mods.get("ult_start_charge", 0.0)), 0.01),
		"death_save": float(skill_mods.get("death_save", 0.0)) > 0.0,
		"death_save_health_fraction": snappedf(float(skill_mods.get("death_save_health_fraction", 0.0)), 0.01),
		"measurement_method": "deterministic_formula_expected_value",
		"runs": 1,
		"solo_variance_dpm2": 0.0,
		"crowd_variance_dpm2": 0.0,
	}


func _a5_run_modifiers(class_id: String) -> Dictionary:
	var run_mods := {}
	for key_value in PD.ascension_mods(class_id, 5).keys():
		var key := str(key_value)
		var value := float(PD.ascension_mods(class_id, 5)[key_value])
		if key.ends_with("_multiplier"):
			run_mods[key] = float(run_mods.get(key, 1.0)) * value
		else:
			run_mods[key] = float(run_mods.get(key, 0.0)) + value
	var difficulty := PD.ascension_difficulty_mods(5)
	run_mods["xp_gain_multiplier"] = float(run_mods.get("xp_gain_multiplier", 1.0)) * float(difficulty.get("reward_mult", 1.0))
	run_mods["money_gain_multiplier"] = float(run_mods.get("money_gain_multiplier", 1.0)) * float(difficulty.get("reward_mult", 1.0))
	run_mods["healing_multiplier"] = float(run_mods.get("healing_multiplier", 1.0)) * float(difficulty.get("healing_mult", 1.0))
	run_mods["max_health_multiplier"] = float(run_mods.get("max_health_multiplier", 1.0)) * float(difficulty.get("player_max_hp_mult", 1.0))
	return run_mods


func _apply_meta_formula_mods(stats: Dictionary, run_mods: Dictionary, mods: Dictionary) -> void:
	for source_key in PlayerScript.META_SKILL_ATTRIBUTE_FLAT_MAP:
		if mods.has(source_key):
			var stat_key := str(PlayerScript.META_SKILL_ATTRIBUTE_FLAT_MAP[source_key])
			stats[stat_key] = float(stats.get(stat_key, 0.0)) + float(mods[source_key])
	for source_key in PlayerScript.META_SKILL_MULT_MAP:
		if mods.has(source_key):
			var run_key := str(PlayerScript.META_SKILL_MULT_MAP[source_key])
			run_mods[run_key] = float(run_mods.get(run_key, 1.0)) * (1.0 + float(mods[source_key]))
	for source_key in PlayerScript.META_SKILL_FLAT_MAP:
		if mods.has(source_key):
			var run_key := str(PlayerScript.META_SKILL_FLAT_MAP[source_key])
			run_mods[run_key] = float(run_mods.get(run_key, 0.0)) + float(mods[source_key])


func _profile_factors(class_id: String, weapon_id: String, config: Dictionary, stats: Dictionary, run_mods: Dictionary, profile: Dictionary) -> Dictionary:
	if profile.is_empty() or (profile.get("node_ids", []) as Array).is_empty():
		return {"solo": 1.0, "crowd": 1.0, "flat": 1.0, "cadence": 1.0, "geometry": 1.0, "axis": 1.0, "final": 1.0}
	var amounts: Dictionary = profile.get("amounts", {})
	var multipliers: Dictionary = profile.get("multipliers", {})
	var params := PD.derived_parameters(stats, run_mods, _config_with_class(config, class_id))
	var damage_parameter := str(config.get("damage_parameter", PD.damage_parameter_for(class_id)))
	var base_damage := maxf(float(params.get(damage_parameter, params.get("damage", 1.0))), 0.001)
	var flat_factor := (base_damage + float(amounts.get("weapon_damage_flat", 0.0))) / base_damage
	var cadence := float(multipliers.get("weapon_attack_speed_mult", 1.0))
	var identity := float(multipliers.get("weapon_prefinal_identity_mult", 1.0))
	var axis := str(profile.get("axis", ""))
	var axis_factor := 1.0
	if axis == "solo":
		axis_factor *= float(multipliers.get("precision_window_mult", 1.0))
		axis_factor *= float(multipliers.get("hidden_solo_mastery_mult", 1.0))
	var geometry := 1.0
	for key in ["range_or_precision_zone_mult", "arc_chain_or_zone_geometry_mult", "guard_control_zone_mult", "radius_or_blast_geometry_mult", "impact_area_mult"]:
		geometry *= float(multipliers.get(key, 1.0))
	if axis == "crowd":
		geometry *= float(multipliers.get("target_pattern_budget_mult", 1.0))
		geometry *= float(multipliers.get("hidden_crowd_mastery_mult", 1.0))
	elif axis == "aoe":
		geometry *= float(multipliers.get("hidden_aoe_mastery_mult", 1.0))
	var final_node := _final_node(_schema_branch(class_id, weapon_id))
	var final_factor := maxf(float(final_node.get("gain_over_order_5_min", 1.0)), 1.0)
	var solo_final := final_factor if axis == "solo" else 1.0
	var crowd_final := final_factor if axis in ["crowd", "aoe"] else 1.0
	return {
		"solo": snappedf(flat_factor * cadence * identity * axis_factor * solo_final, 0.0001),
		"crowd": snappedf(flat_factor * cadence * identity * geometry * crowd_final, 0.0001),
		"flat": snappedf(flat_factor, 0.0001), "cadence": snappedf(cadence, 0.0001),
		"geometry": snappedf(geometry, 0.0001), "axis": snappedf(axis_factor, 0.0001), "final": snappedf(final_factor, 0.0001),
	}


func _survival_metrics(config: Dictionary, params: Dictionary, run_mods: Dictionary, skill_mods: Dictionary, profile: Dictionary) -> Dictionary:
	var hp := maxf(float(params.get("health_point", 1.0)), 1.0)
	var defense := clampf(float(params.get("defense", 0.0)), 0.0, PD.SURVIVABILITY_DEFENSE_CAP)
	var dodge := clampf(float(params.get("dodge", 0.0)), 0.0, PD.SURVIVABILITY_DODGE_CAP)
	var absorb := maxf(float(params.get("absorb", 0.0)), 0.0)
	var difficulty := PD.ascension_difficulty_mods(5)
	var raw_hit := A5_NORMAL_CONTACT_DAMAGE * float(difficulty.get("enemy_damage_mult", 1.0))
	var landed_rate := minf(A5_NORMAL_CONTACT_RATE, 1.0 / PLAYER_IFRAME_SECONDS)
	var post_absorb := maxf(raw_hit - absorb, raw_hit * PD.SURVIVABILITY_ABSORB_MIN_DAMAGE_FRACTION)
	var incoming := post_absorb * (1.0 - defense) * (1.0 - dodge) * landed_rate
	var raw_dps := raw_hit * landed_rate
	var healing_multiplier := float(run_mods.get("healing_multiplier", 1.0)) * (1.0 + float(skill_mods.get("healing_mult", 0.0)))
	var regen := maxf(float(params.get("regeneration", 0.0)), 0.0) * healing_multiplier
	var interval := maxf(float(config.get("fire_interval", 1.0)) / maxf(float(params.get("attack_speed", 1.0)), 0.1), 0.18)
	var lifesteal := (
		float(config.get("heal_percent_of_damage", 0.0)) * maxf(float(params.get("damage", 0.0)), float(params.get("magic_damage", 0.0))) / interval
		+ float(config.get("heal_percent_on_attack", 0.0)) * hp / interval
	) * PD.WEAPON_DRAIN_HEAL_MULTIPLIER * healing_multiplier
	var sustain := regen + maxf(lifesteal, 0.0)
	var net_dps := maxf(incoming - sustain, 0.01)
	var death_fraction := float(skill_mods.get("death_save_health_fraction", 0.0)) if float(skill_mods.get("death_save", 0.0)) > 0.0 else 0.0
	var ttd := hp / net_dps + (2.0 + hp * death_fraction / net_dps if death_fraction > 0.0 else 0.0)
	var conditional_factor := 1.0
	var shield_capacity := 0.0
	if not profile.is_empty() and str(profile.get("axis", "")) == "defense":
		conditional_factor = maxf(float(_final_node(_schema_branch(str(profile.get("class_id", "")), str(profile.get("weapon_id", "")))).get("gain_over_order_5_min", 1.0)), 1.0)
	var mechanics: Dictionary = profile.get("mechanics", {})
	for mechanic_id in mechanics:
		var mechanic: Dictionary = mechanics[mechanic_id]
		var mechanic_params: Dictionary = mechanic.get("params", {})
		for cap_key in ["shield_cap", "absorb_cap", "stored_damage_cap"]:
			shield_capacity = maxf(shield_capacity, float(mechanic_params.get(cap_key, 0.0)))
	return {
		"hp": snappedf(hp, 0.01), "defense": snappedf(defense, 0.0001), "dodge": snappedf(dodge, 0.0001),
		"absorb_flat": snappedf(absorb, 0.01), "conditional_shield_capacity": snappedf(shield_capacity, 0.01),
		"regeneration_per_second": snappedf(regen, 0.01), "lifesteal_per_second": snappedf(lifesteal, 0.01),
		"mitigation": snappedf(1.0 - incoming / maxf(raw_dps, 0.001), 0.0001),
		"ehp": snappedf(hp * raw_dps / maxf(incoming, 0.01), 0.01),
		"ttd_seconds": snappedf(ttd, 0.01), "conditional_defense_factor": snappedf(conditional_factor, 0.01),
	}


func _apply_baseline_deltas(rows: Array) -> void:
	var baselines := {}
	for row in rows:
		if str(row.get("scenario", "")) == "no_meta":
			baselines["%s|%s|%d" % [row["class_id"], row["weapon_id"], row["level"]]] = row
	for row in rows:
		var baseline: Dictionary = baselines["%s|%s|%d" % [row["class_id"], row["weapon_id"], row["level"]]]
		for metric in ["solo_dpm", "crowd_10_total_dpm", "ehp", "ttd_seconds", "pickup_radius", "move_speed"]:
			var delta := float(row[metric]) - float(baseline[metric])
			row["%s_delta_abs" % metric] = snappedf(delta, 0.01)
			row["%s_delta_pct" % metric] = snappedf(delta / maxf(absf(float(baseline[metric])), 0.001) * 100.0, 0.01)


func _apply_atlas_deltas(rows: Array) -> void:
	var constellation_rows := {}
	for row in rows:
		if str(row.get("scenario", "")) == "class_constellation":
			constellation_rows["%s|%s|%d" % [row["class_id"], row["weapon_id"], row["level"]]] = row
	for row in rows:
		var reference: Dictionary = constellation_rows["%s|%s|%d" % [row["class_id"], row["weapon_id"], row["level"]]]
		var deltas := {}
		for metric in ["solo_dpm", "crowd_10_total_dpm", "pickup_radius", "move_speed", "ehp", "ttd_seconds", "healing_multiplier", "start_gold", "ult_start_charge"]:
			deltas[metric] = snappedf(float(row.get(metric, 0.0)) - float(reference.get(metric, 0.0)), 0.01)
		row["atlas_delta_vs_class_constellation"] = deltas
		row["atlas_delta_summary"] = _atlas_delta_summary(str(row.get("scenario", "")), deltas, bool(row.get("death_save", false)) and not bool(reference.get("death_save", false)))


func _atlas_delta_summary(scenario_id: String, deltas: Dictionary, adds_death_save: bool) -> String:
	if scenario_id not in ["class_atlas50", "class_atlas59_upper"]:
		return "n/a"
	var parts := PackedStringArray()
	for metric in ["solo_dpm", "crowd_10_total_dpm", "pickup_radius", "move_speed", "ehp", "ttd_seconds", "healing_multiplier", "start_gold", "ult_start_charge"]:
		var value := float(deltas.get(metric, 0.0))
		if not is_zero_approx(value):
			parts.append("%s %+.2f" % [metric, value])
	if adds_death_save:
		parts.append("death_save +1")
	return "no measured delta" if parts.is_empty() else "; ".join(parts)


func _class_rows(class_ids: Array, weapon_rows: Array) -> Array:
	var result := []
	for class_id_value in class_ids:
		var class_id := str(class_id_value)
		for level in LEVELS:
			# Weapon rows retain their scenario-adjusted stats for per-weapon metrics.
			# The class ultimate must instead begin with the controlled no-meta level
			# stats, then apply the class/Atlas modifier order once below.
			var level_stats: Dictionary = {}
			for candidate_value in weapon_rows:
				var candidate: Dictionary = candidate_value
				if candidate["class_id"] == class_id and candidate["level"] == level and candidate["scenario"] == "no_meta":
					level_stats = (candidate.get("stats", {}) as Dictionary).duplicate(true)
					break
			if level_stats.is_empty():
				_errors.append("missing no-meta level stats for class ultimate %s L%d" % [class_id, level])
				continue
			for scenario_id in SCENARIO_IDS:
				var rows := []
				for row in weapon_rows:
					if row["class_id"] == class_id and row["level"] == level and row["scenario"] == scenario_id:
						rows.append(row)
				var solo := _mean(rows, "solo_dpm")
				var crowd := _mean(rows, "crowd_10_total_dpm")
				var ehp := _mean(rows, "ehp")
				var ttd := _mean(rows, "ttd_seconds")
				var utility := _mean(rows, "pickup_radius") / 200.0 + _mean(rows, "move_speed") / 600.0
				var state := _scenario_state(class_id, scenario_id)
				var skill_mods := Meta.skill_modifiers_for_class(state, class_id) if scenario_id != "no_meta" else {}
				var first_weapon := str(PD.weapon_ids(class_id)[0])
				var stats: Dictionary = level_stats.duplicate(true)
				var run_mods := _a5_run_modifiers(class_id)
				if scenario_id != "no_meta":
					_apply_meta_formula_mods(stats, run_mods, skill_mods)
				var params := PD.derived_parameters(stats, run_mods, _config_with_class(PD.weapon(class_id, first_weapon), class_id))
				var ultimate := PD._budget_ultimate_dps(class_id, params)
				var start_charge := float(skill_mods.get("ult_start_charge", 0.0))
				var first_minute_ult := (float(ultimate.get("solo", 0.0)) + float(ultimate.get("aoe", 0.0))) * 30.0
				if start_charge > 0.0:
					first_minute_ult += _ultimate_activation_damage(class_id, params) * start_charge
				var roles := []
				for row in rows:
					roles.append("%s:%s" % [row["weapon_id"], row["axis"]])
				result.append({
					"key": "%s|%d|%s" % [class_id, level, scenario_id], "class_id": class_id, "level": level, "scenario": scenario_id,
					"roles": roles, "mean_solo_dpm": snappedf(solo, 0.01), "mean_crowd_10_dpm": snappedf(crowd, 0.01),
					"mean_ehp": snappedf(ehp, 0.01), "mean_ttd_seconds": snappedf(ttd, 0.01), "convenience_score": snappedf(utility, 0.001),
					"first_minute_ultimate_damage": snappedf(first_minute_ult, 0.01), "atlas_start_charge": snappedf(start_charge, 0.01),
					"strengths": _class_strengths(solo, crowd, ehp, utility), "weaknesses": _class_weaknesses(solo, crowd, ehp, utility),
				})
	return result


func _apply_class_relative_scores(rows: Array) -> void:
	for level in LEVELS:
		for scenario_id in SCENARIO_IDS:
			var scoped := []
			for row in rows:
				if int(row.get("level", 0)) == level and str(row.get("scenario", "")) == scenario_id:
					scoped.append(row)
			var solo_median := _median_metric(scoped, "mean_solo_dpm")
			var crowd_median := _median_metric(scoped, "mean_crowd_10_dpm")
			var defense_median := _median_metric(scoped, "mean_ehp")
			var convenience_median := _median_metric(scoped, "convenience_score")
			for row in scoped:
				row["solo_score"] = snappedf(float(row["mean_solo_dpm"]) / maxf(solo_median, 0.001), 0.001)
				row["aoe_score"] = snappedf(float(row["mean_crowd_10_dpm"]) / maxf(crowd_median, 0.001), 0.001)
				row["defense_score"] = snappedf(float(row["mean_ehp"]) / maxf(defense_median, 0.001), 0.001)
				row["convenience_relative"] = snappedf(float(row["convenience_score"]) / maxf(convenience_median, 0.001), 0.001)
				var ranked := [
					{"name": "solo", "value": float(row["solo_score"])},
					{"name": "AoE", "value": float(row["aoe_score"])},
					{"name": "survival", "value": float(row["defense_score"])},
					{"name": "convenience", "value": float(row["convenience_relative"])},
				]
				ranked.sort_custom(func(a, b): return float(a["value"]) > float(b["value"]))
				row["strengths"] = "%s %.2f× and %s %.2f× roster median." % [ranked[0]["name"], ranked[0]["value"], ranked[1]["name"], ranked[1]["value"]]
				row["weaknesses"] = "%s %.2f× and %s %.2f× roster median." % [ranked[3]["name"], ranked[3]["value"], ranked[2]["name"], ranked[2]["value"]]
				row["outlier_flag"] = str(class_corridor_status(float(row["solo_score"]), float(row["aoe_score"]), float(row["defense_score"])).get("flag", "ok"))


static func class_corridor_status(solo_score: float, aoe_score: float, defense_score: float) -> Dictionary:
	var axes := []
	for axis in [
		{"name": "solo", "value": solo_score},
		{"name": "AoE", "value": aoe_score},
		{"name": "defense", "value": defense_score},
	]:
		var value := float(axis["value"])
		if value < CLASS_CORRIDOR_LOWER or value > CLASS_CORRIDOR_UPPER:
			axes.append(axis)
	var parts := PackedStringArray()
	for axis_value in axes:
		var axis: Dictionary = axis_value
		parts.append("%s=%.2f×" % [axis["name"], axis["value"]])
	return {
		"is_outlier": not axes.is_empty(),
		"axes": axes,
		"flag": "OUTLIER %s" % "; ".join(parts) if not axes.is_empty() else "ok",
	}


static func _class_corridor_entry(row: Dictionary, status: Dictionary) -> Dictionary:
	var axis_names := []
	for axis_value in status.get("axes", []):
		axis_names.append(str((axis_value as Dictionary).get("name", "")))
	return {
		"key": row["key"],
		"axes": axis_names,
		"solo_vs_median": snappedf(float(row["solo_score"]), 0.001),
		"crowd_vs_median": snappedf(float(row["aoe_score"]), 0.001),
		"defense_vs_median": snappedf(float(row["defense_score"]), 0.001),
	}


static func _class_corridor_entry_matches(actual: Dictionary, expected: Dictionary) -> bool:
	if str(actual.get("key", "")) != str(expected.get("key", "")) or actual.get("axes", []) != expected.get("axes", []):
		return false
	for ratio_key in ["solo_vs_median", "crowd_vs_median", "defense_vs_median"]:
		if not actual.has(ratio_key) or not is_equal_approx(float(actual[ratio_key]), float(expected[ratio_key])):
			return false
	return true


static func verify_class_corridor_artifacts(dataset: Dictionary) -> Dictionary:
	var errors := PackedStringArray()
	var expected_entries := []
	for row_value in dataset.get("class_rows", []):
		var row: Dictionary = row_value
		var status := class_corridor_status(float(row.get("solo_score", 0.0)), float(row.get("aoe_score", 0.0)), float(row.get("defense_score", 0.0)))
		var expected_flag := str(status["flag"])
		if str(row.get("outlier_flag", "")) != expected_flag:
			errors.append("%s corridor flag differs from canonical status" % row.get("key", "?"))
		if bool(status["is_outlier"]):
			expected_entries.append(_class_corridor_entry(row, status))
	var outliers: Dictionary = dataset.get("outliers", {})
	var actual_entries = outliers.get("class_corridor_80_120", [])
	if not actual_entries is Array:
		errors.append("class corridor summary is not an array")
		return {"ok": false, "errors": errors}
	if actual_entries.size() != expected_entries.size():
		errors.append("class corridor summary count %d differs from canonical %d" % [actual_entries.size(), expected_entries.size()])
	var actual_by_key := {}
	for entry_value in actual_entries:
		var entry: Dictionary = entry_value
		var key := str(entry.get("key", ""))
		if actual_by_key.has(key):
			errors.append("class corridor summary duplicates %s" % key)
		actual_by_key[key] = entry
	for expected_value in expected_entries:
		var expected: Dictionary = expected_value
		var key := str(expected["key"])
		if not actual_by_key.has(key):
			errors.append("class corridor summary misses %s" % key)
		elif not _class_corridor_entry_matches(actual_by_key[key], expected):
			errors.append("class corridor summary differs for %s" % key)
	return {"ok": errors.is_empty(), "errors": errors}


func _apply_live_evidence_to_rows(rows: Array, parity: Array) -> void:
	var by_pair := {}
	for parity_row in parity:
		by_pair[str(parity_row.get("pair", ""))] = parity_row
	for row in rows:
		if int(row.get("level", 0)) != 20 or str(row.get("scenario", "")) != "class_constellation":
			continue
		var parity_row: Dictionary = by_pair.get("%s/%s" % [row["class_id"], row["weapon_id"]], {})
		if parity_row.is_empty():
			continue
		row["measurement_method"] = "deterministic_formula_plus_live_scene_probe"
		row["runs"] = LIVE_SEEDS.size()
		row["solo_variance_dpm2"] = snappedf(pow(float(parity_row.get("live_solo_dpm_stddev", 0.0)), 2.0), 0.01)
		row["crowd_variance_dpm2"] = snappedf(pow(float(parity_row.get("live_pack_dpm_stddev", 0.0)), 2.0), 0.01)
		row["live_solo_dpm_mean"] = parity_row.get("live_solo_dpm_mean", 0.0)
		row["live_crowd_dpm_mean"] = parity_row.get("live_pack_dpm_mean", 0.0)


func _ultimate_activation_damage(class_id: String, params: Dictionary) -> float:
	var config := PD.ultimate_config(class_id)
	var base_damage := maxf(float(params.get("damage", 1.0)), float(params.get("magic_damage", 1.0)))
	return base_damage * float(config.get("damage", 1.0)) * float(params.get("ultimate_multiplier", 1.0))


func _live_parity(class_ids: Array, builds: Dictionary, weapon_rows: Array) -> Dictionary:
	var result := []
	var telemetry_samples := []
	for class_id_value in class_ids:
		var class_id := str(class_id_value)
		var state := _scenario_state(class_id, "class_constellation")
		for weapon_id_value in PD.weapon_ids(class_id):
			var weapon_id := str(weapon_id_value)
			var solo_samples := []
			var pack_samples := []
			for seed_value in LIVE_SEEDS:
				var solo_sample: Dictionary = await _measure_live(class_id, weapon_id, 1, builds[class_id]["level20_stats"], state, int(seed_value), "sustain_solo", "sustain")
				var pack_sample: Dictionary = await _measure_live(class_id, weapon_id, TARGET_COUNT, builds[class_id]["level20_stats"], state, int(seed_value), "sustain_pack", "sustain")
				telemetry_samples.append(solo_sample)
				telemetry_samples.append(pack_sample)
				solo_samples.append(float(solo_sample.get("dpm", -1.0)))
				pack_samples.append(float(pack_sample.get("dpm", -1.0)))
			var formula := _find_weapon_row(weapon_rows, class_id, weapon_id, 20, "class_constellation")
			var solo_mean := _number_mean(solo_samples)
			var pack_mean := _number_mean(pack_samples)
			var final_mechanic := str(formula.get("final_mechanic", "none"))
			result.append({
				"pair": "%s/%s" % [class_id, weapon_id], "attack_mode": formula.get("attack_mode", ""),
				"final_mechanic": final_mechanic, "final_event": formula.get("final_event", ""),
				"seeds": LIVE_SEEDS, "solo_samples_dpm": solo_samples, "pack_samples_dpm": pack_samples,
				"live_solo_dpm_mean": snappedf(solo_mean, 0.01), "live_solo_dpm_stddev": snappedf(_stddev(solo_samples, solo_mean), 0.01),
				"live_pack_dpm_mean": snappedf(pack_mean, 0.01), "live_pack_dpm_stddev": snappedf(_stddev(pack_samples, pack_mean), 0.01),
				"formula_solo_dpm": formula.get("solo_dpm", 0.0), "formula_pack_dpm": formula.get("crowd_10_total_dpm", 0.0),
				"solo_delta_pct": snappedf((solo_mean - float(formula.get("solo_dpm", 0.0))) / maxf(float(formula.get("solo_dpm", 0.0)), 0.001) * 100.0, 0.01),
				"pack_delta_pct": snappedf((pack_mean - float(formula.get("crowd_10_total_dpm", 0.0))) / maxf(float(formula.get("crowd_10_total_dpm", 0.0)), 0.001) * 100.0, 0.01),
				"runtime_observation": "infinite-HP sustained probe" if str(formula.get("final_event", "")) not in ["kill", "execute", "summon_death"] else "final event not fully observable on infinite-HP dummies",
			})
			print("FAN-1438 live %s/%s: solo %.1f DPM, pack %.1f DPM" % [class_id, weapon_id, solo_mean, pack_mean])
	var representative_state := _scenario_state(REPRESENTATIVE_CLASS_ID, "class_constellation")
	var representative_stats: Dictionary = builds[REPRESENTATIVE_CLASS_ID]["level20_stats"]
	var offensive_fixture: Dictionary = await _measure_live(REPRESENTATIVE_CLASS_ID, REPRESENTATIVE_WEAPON_ID, 1, representative_stats, representative_state, REPRESENTATIVE_SEED, "representative_offensive", "offensive")
	var mortal_fixture: Dictionary = await _measure_live(REPRESENTATIVE_CLASS_ID, REPRESENTATIVE_WEAPON_ID, 1, representative_stats, representative_state, REPRESENTATIVE_SEED, "representative_mortal", "mortal", MORTAL_TARGET_HP)
	var incoming_fixture: Dictionary = await _measure_incoming_fixture(representative_stats, representative_state)
	telemetry_samples.append(offensive_fixture)
	telemetry_samples.append(mortal_fixture)
	telemetry_samples.append(incoming_fixture)
	return {
		"parity": result,
		"telemetry": {
			"schema": LIVE_TELEMETRY_SCHEMA,
			"trace_id_format": "%s:<pair>|<seed>|<scenario>|<fixture>|<target-cardinality>" % LIVE_TRACE_PREFIX,
			"samples": telemetry_samples,
			"representative_fixtures": [
				{"fixture": "offensive", "sample_key": offensive_fixture.get("sample_key", "")},
				{"fixture": "mortal", "sample_key": mortal_fixture.get("sample_key", "")},
				{"fixture": "incoming_hit", "sample_key": incoming_fixture.get("sample_key", "")},
			],
		},
	}


func _measure_live(class_id: String, weapon_id: String, target_count: int, stats: Dictionary, state: Dictionary, seed_value: int, scenario_key: String, fixture: String, initial_target_hp := DUMMY_HP) -> Dictionary:
	await _teardown()
	seed(seed_value)
	var pair := "%s/%s" % [class_id, weapon_id]
	var sample_key := _telemetry_sample_key(pair, seed_value, scenario_key, fixture, target_count)
	var collector := A5TelemetryCollector.new("%s:%s" % [LIVE_TRACE_PREFIX, sample_key], sample_key)
	var player := PLAYER_SCENE.instantiate() as Node2D
	_holder.add_child(player)
	if player == null or player.get_script() == null:
		_errors.append("%s/%s live Player failed to instantiate" % [class_id, weapon_id])
		return _failed_telemetry_sample(pair, seed_value, scenario_key, fixture, target_count, sample_key)
	player.add_to_group("player")
	player.global_position = PLAYER_POSITION
	player.call("configure_character", class_id, weapon_id)
	player.set("stats", stats.duplicate(true))
	player.call("_apply_stat_scaling", true)
	# Exercise the exact production composition order instead of recreating it:
	# earned ascension rewards -> selected A5 -> class/Guild mods -> profiles.
	var main := MainScript.new()
	main.set("selected_character_id", class_id)
	main.set("selected_ascension_level", 5)
	main.set("selected_start_boon_id", "")
	main.set("meta_state", state.duplicate(true))
	main.set("run_sandbox_captured", false)
	main.call("apply_ascension_bonuses", player)
	main.free()
	player.set("max_health", DUMMY_HP)
	player.set("health", DUMMY_HP)
	if _observer_mode == "enabled":
		player.connect("weapon_cast_observed", collector.on_weapon_cast)
		player.connect("constellation_final_resolved", collector.on_final_resolution)
	await process_frame
	var dummies := _spawn_dummies(target_count)
	var anchors := []
	for index in range(dummies.size()):
		var enemy = dummies[index]
		collector.bind_target(enemy as Node2D, "target_%d" % index)
		if _observer_mode == "enabled":
			(enemy as Node2D).connect("damage_applied", collector.on_damage_applied)
			(enemy as Node2D).connect("died", collector.on_target_died)
		if initial_target_hp < DUMMY_HP:
			enemy.set("max_health", initial_target_hp)
			enemy.set("health", initial_target_hp)
		anchors.append((enemy as Node2D).global_position)
	await _advance_live(LIVE_WARMUP_SECONDS, dummies, anchors, class_id, weapon_id, collector, "warmup")
	var before_health := _health_snapshot(dummies)
	var before := _total_health(dummies)
	var measurement: Dictionary = await _advance_live(LIVE_WINDOW_SECONDS, dummies, anchors, class_id, weapon_id, collector, "measurement")
	var measured := float(measurement.get("duration_seconds", 0.0))
	var measurement_frame_count := int(measurement.get("frame_count", 0))
	var after_health := _health_snapshot(dummies)
	var after := _total_health(dummies)
	var sample := collector.build_sample(pair, seed_value, scenario_key, fixture, target_count)
	var hp_ledger: Dictionary = sample.get("hp_ledger", {})
	var ledger_rows: Array = hp_ledger.get("rows", [])
	var snapshot_count := mini(ledger_rows.size(), mini(before_health.size(), after_health.size()))
	for index in range(snapshot_count):
		var row: Dictionary = ledger_rows[index]
		row["health_before"] = float(before_health[index])
		row["health_after"] = float(after_health[index])
		row["health_loss"] = maxf(float(before_health[index]) - float(after_health[index]), 0.0)
		ledger_rows[index] = row
	hp_ledger["rows"] = ledger_rows
	var health_delta := maxf(before - after, 0.0)
	var measurement_duration := measured
	var measurement_duration_snapped := snappedf(measured, 0.0001)
	var ledger_total := float(hp_ledger.get("total_applied_damage", 0.0))
	# The raw frame-stepped duration is canonical. The snapped value is retained
	# only to account for the FAN-1546 regression and must never be reused as a
	# DPM denominator.
	hp_ledger["measurement_duration_seconds"] = measurement_duration
	hp_ledger["measurement_duration_snapped_seconds"] = measurement_duration_snapped
	hp_ledger["measurement_frame_count"] = measurement_frame_count
	hp_ledger["legacy_health_delta_numerator"] = health_delta
	hp_ledger["dpm_projections"] = {
		"legacy_hp_delta_raw_duration_dpm": _project_dpm(health_delta, measurement_duration),
		"ledger_raw_duration_dpm": _project_dpm(ledger_total, measurement_duration),
		"ledger_snapped_duration_dpm": _project_dpm(ledger_total, measurement_duration_snapped),
		"ledger_minus_legacy_numerator": ledger_total - health_delta,
	}
	sample["hp_ledger"] = hp_ledger
	sample["observer_probe"] = {
		"mode": _observer_mode,
		"measurement_duration_seconds": measurement_duration,
		"measurement_frame_count": measurement_frame_count,
		"health_before": before_health,
		"health_after": after_health,
		"health_delta": health_delta,
		# Every next fixture reseeds explicitly, so this probe cannot change a later
		# measurement. It makes global RNG consumption observable to the A/B gate.
		"rng_probe": randi(),
	}
	if measured < LIVE_WINDOW_SECONDS:
		sample["dpm"] = -1.0
		return sample
	# FAN-1539: DPM and telemetry reconciliation share the same authoritative
	# canonical HP ledger, avoiding a second floating-point aggregation path.
	sample["dpm"] = _project_dpm(health_delta if _observer_mode == "disabled" else ledger_total, measurement_duration)
	return sample


func _measure_incoming_fixture(stats: Dictionary, state: Dictionary) -> Dictionary:
	await _teardown()
	seed(REPRESENTATIVE_SEED)
	var pair := "%s/%s" % [REPRESENTATIVE_CLASS_ID, REPRESENTATIVE_WEAPON_ID]
	var sample_key := _telemetry_sample_key(pair, REPRESENTATIVE_SEED, "representative_incoming_hit", "incoming_hit", 1)
	var collector := A5TelemetryCollector.new("%s:%s" % [LIVE_TRACE_PREFIX, sample_key], sample_key)
	var player := PLAYER_SCENE.instantiate() as Node2D
	_holder.add_child(player)
	if player == null or player.get_script() == null:
		_errors.append("incoming fixture Player failed to instantiate")
		return _failed_telemetry_sample(pair, REPRESENTATIVE_SEED, "representative_incoming_hit", "incoming_hit", 1, sample_key)
	player.add_to_group("player")
	player.global_position = PLAYER_POSITION
	player.call("configure_character", REPRESENTATIVE_CLASS_ID, REPRESENTATIVE_WEAPON_ID)
	player.set("stats", stats.duplicate(true))
	player.call("_apply_stat_scaling", true)
	var main := MainScript.new()
	main.set("selected_character_id", REPRESENTATIVE_CLASS_ID)
	main.set("selected_ascension_level", 5)
	main.set("selected_start_boon_id", "")
	main.set("meta_state", state.duplicate(true))
	main.set("run_sandbox_captured", false)
	main.call("apply_ascension_bonuses", player)
	main.free()
	player.set("max_health", DUMMY_HP)
	player.set("health", DUMMY_HP)
	var parameters: Dictionary = player.get("derived_parameters")
	parameters["dodge"] = 0.0
	player.set("derived_parameters", parameters)
	if _observer_mode == "enabled":
		collector.enable_incoming_fixture()
		player.connect("damaged", collector.on_player_damaged)
	await process_frame
	player.call("take_damage", A5_NORMAL_CONTACT_DAMAGE, "fan1511_deterministic_incoming")
	await process_frame
	var sample := collector.build_sample(pair, REPRESENTATIVE_SEED, "representative_incoming_hit", "incoming_hit", 1)
	sample["dpm"] = 0.0
	sample["observer_probe"] = {
		"mode": _observer_mode,
		"measurement_duration_seconds": 0.0,
		"measurement_frame_count": 0,
		"health_before": [DUMMY_HP],
		"health_after": [float(player.get("health"))],
		"health_delta": maxf(DUMMY_HP - float(player.get("health")), 0.0),
		"rng_probe": randi(),
	}
	return sample


func _advance_live(seconds: float, dummies: Array, anchors: Array, class_id: String, weapon_id: String, collector: A5TelemetryCollector, probe_phase: String) -> Dictionary:
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
		_errors.append("%s/%s live simulation advanced %.2f/%.2fs" % [class_id, weapon_id, elapsed, seconds])
	return {"duration_seconds": elapsed, "frame_count": frames}


static func _project_dpm(numerator: float, duration_seconds: float) -> float:
	return snappedf(numerator / maxf(duration_seconds, 0.0000001) * 60.0, 0.01)


static func _projection_rows(dataset: Dictionary) -> Dictionary:
	var roster: Dictionary = dataset.get("roster", {})
	var pair_keys: Array = roster.get("pair_keys", [])
	var rows_by_pair := {}
	for row_value in dataset.get("weapon_rows", []):
		var row: Dictionary = row_value
		if int(row.get("level", 0)) != 20 or str(row.get("scenario", "")) != "class_constellation":
			continue
		var pair := "%s/%s" % [row.get("class_id", ""), row.get("weapon_id", "")]
		if rows_by_pair.has(pair):
			return {"ok": false, "error": "duplicate projection row %s" % pair}
		rows_by_pair[pair] = row
	if pair_keys.size() != 51 or rows_by_pair.size() != pair_keys.size():
		return {"ok": false, "error": "projection manifest must contain exactly 51 L20 class-constellation rows"}
	for pair_value in pair_keys:
		if not rows_by_pair.has(str(pair_value)):
			return {"ok": false, "error": "projection manifest is missing %s" % str(pair_value)}
	return {"ok": true, "pair_keys": pair_keys, "rows_by_pair": rows_by_pair}


static func projection_oracle_digest(dataset: Dictionary) -> Dictionary:
	var extraction := _projection_rows(dataset)
	if not bool(extraction.get("ok", false)):
		return {"ok": false, "error": extraction.get("error", "unknown")}
	var pair_keys: Array = extraction["pair_keys"]
	var rows_by_pair: Dictionary = extraction["rows_by_pair"]
	var canonical := ""
	for pair_value in pair_keys:
		var pair := str(pair_value)
		var row: Dictionary = rows_by_pair[pair]
		canonical += "%s|%.2f|%.2f|%.2f|%.2f\n" % [pair, float(row.get("live_solo_dpm_mean", NAN)), float(row.get("live_crowd_dpm_mean", NAN)), float(row.get("solo_variance_dpm2", NAN)), float(row.get("crowd_variance_dpm2", NAN))]
	return {"ok": true, "digest": _sha256(canonical), "canonical": canonical}


# FAN-1641: exposes the 51x4 projection as a per-cell map of the exact %.2f text
# rendered into the oracle canonical string, keyed by "pair|field".
static func projection_cell_map(dataset: Dictionary) -> Dictionary:
	var extraction := _projection_rows(dataset)
	if not bool(extraction.get("ok", false)):
		return {"ok": false, "error": extraction.get("error", "unknown")}
	var pair_keys: Array = extraction["pair_keys"]
	var rows_by_pair: Dictionary = extraction["rows_by_pair"]
	var cells := {}
	for pair_value in pair_keys:
		var pair := str(pair_value)
		var row: Dictionary = rows_by_pair[pair]
		for field_value in PROJECTION_FIELDS:
			var field := str(field_value)
			cells["%s|%s" % [pair, field]] = "%.2f" % float(row.get(field, NAN))
	return {"ok": true, "cells": cells, "pair_keys": pair_keys}


static func _projection_canonical_from_cells(pair_keys: Array, cells: Dictionary) -> String:
	var canonical := ""
	for pair_value in pair_keys:
		var pair := str(pair_value)
		canonical += "%s|%s|%s|%s|%s\n" % [pair, str(cells["%s|live_solo_dpm_mean" % pair]), str(cells["%s|live_crowd_dpm_mean" % pair]), str(cells["%s|solo_variance_dpm2" % pair]), str(cells["%s|crowd_variance_dpm2" % pair])]
	return canonical


# FAN-1641: deterministic digest of the sorted telemetry sample-key set. Summon
# geometry changes projection values, never the roster x seed x fixture key set,
# so this is the "event" dimension of the lineage-aware parity contract.
static func telemetry_sample_keys_digest(dataset: Dictionary) -> Dictionary:
	var samples: Array = (dataset.get("live_telemetry", {}) as Dictionary).get("samples", [])
	var keys := []
	var seen := {}
	for sample_value in samples:
		var key := str((sample_value as Dictionary).get("sample_key", ""))
		if seen.has(key):
			return {"ok": false, "error": "duplicate telemetry sample key %s" % key}
		seen[key] = true
		keys.append(key)
	keys.sort()
	var canonical := ""
	for key in keys:
		canonical += "%s\n" % str(key)
	return {"ok": true, "count": keys.size(), "digest": _sha256(canonical)}


# FAN-1649: deterministic canonical serialization of one live telemetry sample.
# It covers the whole sample - identity (schema/sample_key/trace_id/pair/seed/
# scenario/fixture/target cardinality/target ids), the ORDERED event stream
# (kind, source, phase, target, damage, frame, provenance/cast ids, mechanic and
# observed feedback, on-kill/final-event links via related_hit_id/final_event_ids),
# the HP ledger (rows with health snapshots, totals, fixed measurement window and
# dpm_projections), the counters/DPM block, and the observer/RNG probe. Godot's
# JSON.stringify(value, "", true, true) sorts dictionary keys recursively and keeps
# array order at full float precision, so an event reorder, an added/removed event
# or any numeric edit changes the canonical text; two independent clean runs of the
# same base commit reproduce byte-identical output (verified on b8909e30). The
# stored trace_digest_sha256 is a DERIVED field: it is recomputed from the event
# array and independently verified, so a lone trace-digest edit cannot pass.
static func canonical_telemetry_sample(sample: Dictionary) -> Dictionary:
	var events: Array = sample.get("events", [])
	var recomputed_trace := _sha256(JSON.stringify(events, "", true, true))
	var stored_trace := str(sample.get("trace_digest_sha256", ""))
	var canonical := JSON.stringify(sample, "", true, true)
	return {
		"ok": recomputed_trace == stored_trace,
		"canonical": canonical,
		"digest": _sha256(canonical),
		"trace_digest_recomputed": recomputed_trace,
		"trace_digest_stored": stored_trace,
	}


# FAN-1649: full canonical telemetry payload of a dataset as a per-sample digest
# map (sample_key -> sha256 of the canonical sample) plus a single aggregate digest
# over the sorted "sample_key|digest" lines. The map is keyed and sorted by
# sample_key, so the aggregate is order-independent across samples while the event
# stream inside each sample stays ordered. This is the event-payload dimension the
# FAN-1641 sample-key digest missed: it only proved the 309 roster x seed x fixture
# keys, so a payload mutation that preserved those keys stayed ok=true (FAN-1642).
static func canonical_full_telemetry(dataset: Dictionary) -> Dictionary:
	var samples: Array = (dataset.get("live_telemetry", {}) as Dictionary).get("samples", [])
	var sample_digests := {}
	var errors := PackedStringArray()
	for sample_value in samples:
		if not sample_value is Dictionary:
			errors.append("telemetry sample is not an object")
			continue
		var sample: Dictionary = sample_value
		var key := str(sample.get("sample_key", ""))
		if key == "":
			errors.append("telemetry sample is missing its sample_key")
			continue
		if sample_digests.has(key):
			errors.append("duplicate telemetry sample key %s" % key)
			continue
		var canonical := canonical_telemetry_sample(sample)
		if not bool(canonical.get("ok", false)):
			errors.append("telemetry sample %s trace digest is not reproducible from its events" % key)
		sample_digests[key] = str(canonical.get("digest", ""))
	var keys := sample_digests.keys()
	keys.sort()
	var aggregate := ""
	for key in keys:
		aggregate += "%s|%s\n" % [str(key), str(sample_digests[key])]
	return {"ok": errors.is_empty(), "errors": errors, "count": keys.size(), "sample_digests": sample_digests, "digest": _sha256(aggregate)}


# FAN-1649: fail-closed exact equality of a candidate's full canonical telemetry
# payload against the current integration base pinned in the lineage manifest under
# current_integration_base.telemetry_full. The pinned map is independent of any
# candidate-owned digest; the parity/integrity tests additionally assert its
# aggregate against an external committed constant, so a self-consistent tamper
# (rewrite a pinned sample digest AND its own aggregate) still fails against that
# constant. The historical f09 oracle is NOT a valid baseline here: the six
# measurement-contract commits between f09 and b8909e30 changed the event contract
# for every sample, so full-payload parity is anchored directly on b8909e30.
static func verify_candidate_full_telemetry_against_pinned(candidate_dataset: Dictionary, manifest: Dictionary) -> Dictionary:
	var errors := PackedStringArray()
	var pinned: Dictionary = (manifest.get("current_integration_base", {}) as Dictionary).get("telemetry_full", {})
	if pinned.is_empty():
		return {"ok": false, "errors": PackedStringArray(["manifest current base does not pin a full telemetry payload"])}
	if str(pinned.get("telemetry_schema", "")) != LIVE_TELEMETRY_SCHEMA:
		errors.append("pinned current-base telemetry schema differs from %s" % LIVE_TELEMETRY_SCHEMA)
	var pinned_digests: Dictionary = pinned.get("sample_digests", {})
	var pinned_keys := pinned_digests.keys()
	pinned_keys.sort()
	var pinned_aggregate := ""
	for key in pinned_keys:
		pinned_aggregate += "%s|%s\n" % [str(key), str(pinned_digests[key])]
	if _sha256(pinned_aggregate) != str(pinned.get("full_sha256", "")):
		errors.append("pinned current-base telemetry aggregate is internally inconsistent")
	if int(pinned.get("sample_count", -1)) != pinned_digests.size():
		errors.append("pinned current-base telemetry sample_count differs from its digest map")
	var candidate := canonical_full_telemetry(candidate_dataset)
	if not bool(candidate.get("ok", false)):
		for error_value in candidate.get("errors", []):
			errors.append("candidate telemetry payload is invalid: %s" % str(error_value))
	var candidate_digests: Dictionary = candidate.get("sample_digests", {})
	if int(candidate.get("count", -1)) != int(pinned.get("sample_count", -2)):
		errors.append("candidate telemetry sample count %d differs from the pinned current base %d" % [int(candidate.get("count", -1)), int(pinned.get("sample_count", -1))])
	for key in pinned_digests:
		if not candidate_digests.has(key):
			errors.append("candidate is missing telemetry sample %s" % str(key))
		elif str(candidate_digests[key]) != str(pinned_digests[key]):
			errors.append("candidate telemetry sample %s payload differs from the pinned current base" % str(key))
	for key in candidate_digests:
		if not pinned_digests.has(key):
			errors.append("candidate has an unexpected telemetry sample %s" % str(key))
	if str(candidate.get("digest", "")) != str(pinned.get("full_sha256", "")):
		errors.append("candidate full telemetry digest differs from the pinned current base")
	return {"ok": errors.is_empty(), "errors": errors}


static func load_oracle_lineage(path := ORACLE_LINEAGE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "oracle lineage manifest is missing"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "cannot open oracle lineage manifest"}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		return {"ok": false, "error": "oracle lineage manifest is not a JSON object"}
	var manifest: Dictionary = parsed
	if str(manifest.get("schema", "")) != ORACLE_LINEAGE_SCHEMA:
		return {"ok": false, "error": "oracle lineage schema mismatch"}
	return {"ok": true, "manifest": manifest}


# FAN-1641: reconstruct the current integration-base 51x4 matrix from the immutable
# historical oracle plus the exactly-enumerated accepted deltas. No wildcard,
# tolerance, or hand-written baseline value is ever introduced here.
static func _lineage_current_cells(manifest: Dictionary, historical_dataset: Dictionary) -> Dictionary:
	var base := projection_cell_map(historical_dataset)
	if not bool(base.get("ok", false)):
		return {"ok": false, "errors": PackedStringArray(["historical projection is invalid: %s" % base.get("error", "unknown")])}
	var cells: Dictionary = (base.get("cells", {}) as Dictionary).duplicate(true)
	var errors := PackedStringArray()
	var changed := {}
	for delta_value in manifest.get("accepted_projection_deltas", []):
		var delta: Dictionary = delta_value
		var key := "%s|%s" % [str(delta.get("pair", "")), str(delta.get("field", ""))]
		if not cells.has(key):
			errors.append("accepted delta names unknown projection cell %s" % key)
			continue
		if changed.has(key):
			errors.append("accepted delta %s is listed more than once" % key)
		var from_text := "%.2f" % float(delta.get("from", NAN))
		var to_text := "%.2f" % float(delta.get("to", NAN))
		if str(cells[key]) != from_text:
			errors.append("accepted delta %s 'from' %s does not match historical oracle %s" % [key, from_text, str(cells[key])])
		if to_text == from_text:
			errors.append("accepted delta %s does not change the value" % key)
		cells[key] = to_text
		changed[key] = true
	return {"ok": errors.is_empty(), "errors": errors, "cells": cells, "changed": changed, "pair_keys": base.get("pair_keys", [])}


# FAN-1641: fail-closed self-consistency of the checked-in lineage manifest against
# the immutable committed historical oracle. Preserves the f09 oracle unchanged,
# proves the exact 201/204 equal + three accepted druid deltas, and derives the
# current-base digest without relaxing any check.
static func verify_oracle_lineage(manifest: Dictionary, historical_dataset: Dictionary, historical_raw_text := "") -> Dictionary:
	var errors := PackedStringArray()
	var oracle: Dictionary = manifest.get("historical_oracle", {})
	var projection := projection_oracle_digest(historical_dataset)
	if not bool(projection.get("ok", false)):
		errors.append("historical projection is invalid: %s" % projection.get("error", "unknown"))
	elif str(projection.get("digest", "")) != str(oracle.get("projection_sha256", "")):
		errors.append("historical projection digest differs from the checked-in oracle")
	var digest_check := verify_dataset_digest(historical_dataset)
	if not bool(digest_check.get("ok", false)):
		errors.append("historical dataset digest is invalid: %s" % digest_check.get("error", "unknown"))
	elif str(historical_dataset.get("dataset_digest_sha256", "")) != str(oracle.get("dataset_digest_sha256", "")):
		errors.append("historical dataset digest differs from the checked-in oracle")
	if historical_raw_text != "" and _sha256(historical_raw_text) != str(oracle.get("raw_decoded_sha256", "")):
		errors.append("historical decoded raw digest differs from the checked-in oracle")
	var telemetry := telemetry_sample_keys_digest(historical_dataset)
	if not bool(telemetry.get("ok", false)):
		errors.append("historical telemetry keys are invalid: %s" % telemetry.get("error", "unknown"))
	else:
		if int(telemetry.get("count", -1)) != int(oracle.get("telemetry_sample_key_count", -2)):
			errors.append("historical telemetry sample-key count differs from the checked-in oracle")
		if str(telemetry.get("digest", "")) != str(oracle.get("telemetry_sample_keys_sha256", "")):
			errors.append("historical telemetry sample-key digest differs from the checked-in oracle")
	var cell_map := projection_cell_map(historical_dataset)
	var base_cells: Dictionary = cell_map.get("cells", {}) if bool(cell_map.get("ok", false)) else {}
	if bool(cell_map.get("ok", false)):
		var published: Array = oracle.get("published_matrix", [])
		if published.size() != 51:
			errors.append("published oracle matrix must list all 51 pairs")
		var seen_pairs := {}
		for entry_value in published:
			var entry: Dictionary = entry_value
			var pair := str(entry.get("pair", ""))
			seen_pairs[pair] = true
			for field_value in PROJECTION_FIELDS:
				var field := str(field_value)
				var key := "%s|%s" % [pair, field]
				if not base_cells.has(key):
					errors.append("published matrix names unknown cell %s" % key)
					continue
				if "%.2f" % float(entry.get(field, NAN)) != str(base_cells[key]):
					errors.append("published matrix cell %s differs from the live historical oracle" % key)
		if seen_pairs.size() != base_cells.size() / PROJECTION_FIELDS.size():
			errors.append("published matrix pair set differs from the historical oracle roster")
	var current := _lineage_current_cells(manifest, historical_dataset)
	for error_value in current.get("errors", []):
		errors.append(str(error_value))
	var current_digest := ""
	if bool(current.get("ok", false)) and bool(cell_map.get("ok", false)):
		var changed: Dictionary = current.get("changed", {})
		var total: int = (current.get("cells", {}) as Dictionary).size()
		if total != int((manifest.get("projection", {}) as Dictionary).get("cell_count", -1)):
			errors.append("projection cell count %d differs from manifest cell_count" % total)
		if changed.size() != int(manifest.get("changed_cell_count", -1)):
			errors.append("changed cell count %d differs from manifest changed_cell_count" % changed.size())
		if total - changed.size() != int(manifest.get("equal_cell_count", -1)):
			errors.append("equal cell count %d differs from manifest equal_cell_count" % (total - changed.size()))
		for invariant_value in manifest.get("invariant_projection_cells", []):
			var invariant: Dictionary = invariant_value
			var key := "%s|%s" % [str(invariant.get("pair", "")), str(invariant.get("field", ""))]
			if changed.has(key):
				errors.append("invariant cell %s is also listed as an accepted delta" % key)
			if not base_cells.has(key):
				errors.append("invariant cell %s is not part of the projection" % key)
			elif "%.2f" % float(invariant.get("value", NAN)) != str(base_cells[key]):
				errors.append("invariant cell %s differs from the historical oracle" % key)
		current_digest = _sha256(_projection_canonical_from_cells(current.get("pair_keys", []), current.get("cells", {})))
		if current_digest != str((manifest.get("current_integration_base", {}) as Dictionary).get("projection_sha256", "")):
			errors.append("reconstructed current-base projection digest differs from the manifest")
		if current_digest == str(oracle.get("projection_sha256", "")):
			errors.append("current base must differ from the historical oracle by the accepted deltas")
	var gameplay_issues := {}
	for commit_value in (manifest.get("historical_inventory", {}) as Dictionary).get("ordered_commits", []):
		var commit: Dictionary = commit_value
		if str(commit.get("segment", "")) == "gameplay":
			gameplay_issues[str(commit.get("issue", ""))] = true
	for delta_value in manifest.get("accepted_projection_deltas", []):
		var delta: Dictionary = delta_value
		var causes: Array = delta.get("cause_issues", [])
		if causes.is_empty():
			errors.append("accepted delta %s|%s has no causal gameplay issue" % [str(delta.get("pair", "")), str(delta.get("field", ""))])
		for cause_value in causes:
			if not gameplay_issues.has(str(cause_value)):
				errors.append("accepted delta cause %s is not a gameplay commit in the inventory" % str(cause_value))
	for node_key in ["historical_oracle", "historical_integration_base", "current_integration_base"]:
		var node: Dictionary = manifest.get(node_key, {})
		if not _is_git_object_id(str(node.get("commit", ""))):
			errors.append("%s commit is not a 40-hex Git object id" % node_key)
		if not _is_git_object_id(str(node.get("tree", ""))):
			errors.append("%s tree is not a 40-hex Git object id" % node_key)
	return {"ok": errors.is_empty(), "errors": errors, "current_digest": current_digest}


# FAN-1641/FAN-1649: replaces the impossible "candidate vs ec15444e all-zero" gate
# with an exact zero gameplay/event delta between a materialization candidate and
# its immediate current integration base. FAN-1641 covered the 51x4 projection and
# the 309 telemetry sample-KEY set; FAN-1649 adds exact equality of the full
# canonical telemetry PAYLOAD (events, damage, target/order, frame/timing, HP
# ledger, counters/DPM, RNG/observer state, feedback, on-kill/final links) against
# the b8909e30 payload pinned in the manifest, so a payload edit that preserves the
# 309 keys (e.g. a +0.01 damage mutation, FAN-1642) can no longer self-confirm.
static func verify_candidate_against_current_base(candidate_dataset: Dictionary, manifest: Dictionary) -> Dictionary:
	var errors := PackedStringArray()
	# 51x4 projection cells + 309 sample-KEY identity set (roster x seed x fixture).
	var projection := verify_candidate_projection_against_current_base(candidate_dataset, manifest)
	for error_value in projection.get("errors", []):
		errors.append(str(error_value))
	# FAN-1649: the projection and sample-KEY digests above only prove the numeric
	# matrix and the roster identity set. Require exact equality of the full
	# canonical telemetry PAYLOAD against the current integration base pinned in the
	# manifest, so a payload edit that preserves the 309 keys (FAN-1642) fails closed.
	var telemetry_parity := verify_candidate_full_telemetry_against_pinned(candidate_dataset, manifest)
	for error_value in telemetry_parity.get("errors", []):
		errors.append(str(error_value))
	return {"ok": errors.is_empty(), "errors": errors}


# FAN-1641: the 51x4 projection + 309 sample-KEY dimension of the candidate gate,
# split out from verify_candidate_against_current_base so the projection-only
# negatives stay meaningful now that the full-payload check (FAN-1649) rejects any
# candidate carrying the older f09 event contract.
static func verify_candidate_projection_against_current_base(candidate_dataset: Dictionary, manifest: Dictionary) -> Dictionary:
	var errors := PackedStringArray()
	var raw := read_raw_artifact()
	if not bool(raw.get("ok", false)):
		return {"ok": false, "errors": PackedStringArray(["cannot read historical oracle: %s" % raw.get("error", "unknown")])}
	var historical = JSON.parse_string(str(raw.get("text", "")))
	if not historical is Dictionary:
		return {"ok": false, "errors": PackedStringArray(["historical oracle did not parse"])}
	var base := _lineage_current_cells(manifest, historical)
	if not bool(base.get("ok", false)):
		for error_value in base.get("errors", []):
			errors.append(str(error_value))
		return {"ok": false, "errors": errors}
	var base_cells: Dictionary = base.get("cells", {})
	var candidate := projection_cell_map(candidate_dataset)
	if not bool(candidate.get("ok", false)):
		return {"ok": false, "errors": PackedStringArray(["candidate projection is invalid: %s" % candidate.get("error", "unknown")])}
	var candidate_cells: Dictionary = candidate.get("cells", {})
	for key in base_cells:
		if not candidate_cells.has(key):
			errors.append("candidate is missing projection cell %s" % str(key))
		elif str(candidate_cells[key]) != str(base_cells[key]):
			errors.append("candidate cell %s differs from current base (%s vs %s)" % [str(key), str(candidate_cells[key]), str(base_cells[key])])
	for key in candidate_cells:
		if not base_cells.has(key):
			errors.append("candidate has an extra projection cell %s" % str(key))
	var candidate_digest := projection_oracle_digest(candidate_dataset)
	if bool(candidate_digest.get("ok", false)) and str(candidate_digest.get("digest", "")) != str((manifest.get("current_integration_base", {}) as Dictionary).get("projection_sha256", "")):
		errors.append("candidate projection digest differs from the pinned current base")
	var oracle: Dictionary = manifest.get("historical_oracle", {})
	var candidate_keys := telemetry_sample_keys_digest(candidate_dataset)
	if not bool(candidate_keys.get("ok", false)):
		errors.append("candidate telemetry keys are invalid: %s" % candidate_keys.get("error", "unknown"))
	else:
		if int(candidate_keys.get("count", -1)) != int(oracle.get("telemetry_sample_key_count", -2)):
			errors.append("candidate telemetry sample-key count differs from the current base")
		if str(candidate_keys.get("digest", "")) != str(oracle.get("telemetry_sample_keys_sha256", "")):
			errors.append("candidate telemetry event key set differs from the current base")
	return {"ok": errors.is_empty(), "errors": errors}


static func _git_is_ancestor(ancestor: String, descendant: String) -> bool:
	var output := []
	return OS.execute("git", ["merge-base", "--is-ancestor", ancestor, descendant], output, false) == 0


static func _git_lines(args: Array) -> Dictionary:
	var output := []
	var exit_code := OS.execute("git", args, output, false)
	if exit_code != 0:
		return {"ok": false, "error": "git command failed (exit %d)" % exit_code}
	var joined := "".join(PackedStringArray(output))
	return {"ok": true, "lines": Array(joined.split("\n", false))}


# FAN-1641: proves the manifest's commit-level causality against real Git ancestry
# (not runtime ObjectID/allocation state). Confirms the pinned trees, the linear
# f09 -> ec15444e -> current chain, the exact ec15444e..current inventory, and that
# each gameplay commit touches the summon causal files.
static func verify_oracle_lineage_ancestry(manifest: Dictionary) -> Dictionary:
	var errors := PackedStringArray()
	var oracle: Dictionary = manifest.get("historical_oracle", {})
	var ec: Dictionary = manifest.get("historical_integration_base", {})
	var current: Dictionary = manifest.get("current_integration_base", {})
	for node_value in [oracle, ec, current]:
		var node: Dictionary = node_value
		var resolved := resolve_source_provenance(str(node.get("commit", "")))
		if not bool(resolved.get("ok", false)):
			errors.append("cannot resolve pinned commit %s: %s" % [str(node.get("commit", "")), resolved.get("error", "unknown")])
			continue
		if str((resolved.get("source", {}) as Dictionary).get("tree", "")) != str(node.get("tree", "")):
			errors.append("pinned tree for %s differs from git" % str(node.get("commit", "")))
	var oracle_resolved := resolve_source_provenance(str(oracle.get("commit", "")))
	if bool(oracle_resolved.get("ok", false)) and str((oracle_resolved.get("source", {}) as Dictionary).get("commit_timestamp", "")) != str(oracle.get("commit_timestamp", "")):
		errors.append("historical oracle commit timestamp differs from git")
	if not _git_is_ancestor(str(oracle.get("commit", "")), str(ec.get("commit", ""))):
		errors.append("historical oracle is not an ancestor of the historical integration base")
	if not _git_is_ancestor(str(ec.get("commit", "")), str(current.get("commit", ""))):
		errors.append("historical integration base is not an ancestor of the current base")
	var inventory: Dictionary = manifest.get("historical_inventory", {})
	var ordered: Array = inventory.get("ordered_commits", [])
	var revlist := _git_lines(["rev-list", "--reverse", "%s..%s" % [str(ec.get("commit", "")), str(current.get("commit", ""))]])
	if not bool(revlist.get("ok", false)):
		errors.append(str(revlist.get("error", "git rev-list failed")))
	else:
		var actual: Array = revlist.get("lines", [])
		if actual.size() != ordered.size():
			errors.append("historical inventory size %d differs from git rev-list %d" % [ordered.size(), actual.size()])
		else:
			for index in range(ordered.size()):
				if str((ordered[index] as Dictionary).get("commit", "")) != str(actual[index]):
					errors.append("historical inventory commit %d differs from git rev-list" % index)
	var gameplay_files: Array = inventory.get("gameplay_causal_files", [])
	var gameplay_count := 0
	for commit_value in ordered:
		var commit: Dictionary = commit_value
		if str(commit.get("segment", "")) != "gameplay":
			continue
		gameplay_count += 1
		var sha := str(commit.get("commit", ""))
		if not _git_is_ancestor(str(ec.get("commit", "")), sha) or not _git_is_ancestor(sha, str(current.get("commit", ""))):
			errors.append("gameplay commit %s is not between the integration bases" % sha)
		var names := _git_lines(["show", "--name-only", "--format=", sha])
		var touches := false
		if bool(names.get("ok", false)):
			for causal_file in gameplay_files:
				if str(causal_file) in Array(names.get("lines", [])):
					touches = true
		if not touches:
			errors.append("gameplay commit %s does not touch the summon causal files" % sha)
	if gameplay_count != int(inventory.get("gameplay_commit_count", -1)):
		errors.append("gameplay commit count %d differs from manifest" % gameplay_count)
	return {"ok": errors.is_empty(), "errors": errors}


static func _telemetry_sample_key(pair: String, seed_value: int, scenario_key: String, fixture: String, target_cardinality: int) -> String:
	return "%s|%d|%s|%s|%d" % [pair, seed_value, scenario_key, fixture, target_cardinality]


func _failed_telemetry_sample(pair: String, seed_value: int, scenario_key: String, fixture: String, target_cardinality: int, sample_key: String) -> Dictionary:
	var collector := A5TelemetryCollector.new("%s:%s" % [LIVE_TRACE_PREFIX, sample_key], sample_key)
	var sample := collector.build_sample(pair, seed_value, scenario_key, fixture, target_cardinality)
	sample["dpm"] = -1.0
	return sample


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


func _total_health(nodes: Array) -> float:
	var total := 0.0
	for node in nodes:
		if is_instance_valid(node):
			total += float(node.get("health"))
	return total


func _health_snapshot(nodes: Array) -> Array:
	var snapshot := []
	for node in nodes:
		snapshot.append(maxf(float(node.get("health")), 0.0) if is_instance_valid(node) else 0.0)
	return snapshot


func _teardown() -> void:
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
	await process_frame
	await process_frame
	await process_frame


func _outliers(class_rows: Array, parity: Array) -> Dictionary:
	var class_outliers := []
	for row_value in class_rows:
		var row: Dictionary = row_value
		var status := class_corridor_status(float(row["solo_score"]), float(row["aoe_score"]), float(row["defense_score"]))
		if bool(status["is_outlier"]):
			class_outliers.append(_class_corridor_entry(row, status))
	var parity_outliers := []
	for row in parity:
		if absf(float(row.get("solo_delta_pct", 0.0))) > 35.0 or absf(float(row.get("pack_delta_pct", 0.0))) > 35.0:
			parity_outliers.append({"pair": row["pair"], "solo_delta_pct": row["solo_delta_pct"], "pack_delta_pct": row["pack_delta_pct"]})
	return {"class_corridor_80_120": class_outliers, "formula_live_delta_over_35pct": parity_outliers, "action": "investigation candidates only; FAN-1438 makes no balance changes"}


func _validate_dataset(dataset: Dictionary) -> void:
	var provenance := verify_source_provenance(dataset.get("source", {}))
	if not bool(provenance.get("ok", false)):
		_errors.append("source provenance verification failed: %s" % provenance.get("error", "unknown error"))
	var digest_verification := verify_dataset_digest(dataset)
	if not bool(digest_verification.get("ok", false)):
		_errors.append("dataset digest verification failed: %s" % digest_verification.get("error", "unknown error"))
	var pairs: Array = dataset["roster"]["pair_keys"]
	var expected_rows := pairs.size() * LEVELS.size() * SCENARIO_IDS.size()
	var rows: Array = dataset["weapon_rows"]
	if rows.size() != expected_rows:
		_errors.append("expected %d weapon rows, got %d" % [expected_rows, rows.size()])
	var keys := {}
	for row in rows:
		var key := str(row.get("key", ""))
		if keys.has(key):
			_errors.append("duplicate weapon row %s" % key)
		keys[key] = true
		if bool(row.get("ultimate_included", true)):
			_errors.append("weapon row %s includes ultimate" % key)
		if not is_equal_approx(float(row.get("crowd_10_per_target_dpm", -1.0)), float(row.get("crowd_10_total_dpm", 0.0)) / TARGET_COUNT):
			_errors.append("per-target identity mismatch at %s" % key)
	for class_id in dataset["roster"]["class_ids"]:
		if int(dataset["builds"][class_id]["level20_points"]) != LEVEL20_POINTS:
			_errors.append("%s level20 build is not %d points" % [class_id, LEVEL20_POINTS])
	var scenarios: Dictionary = dataset["scenarios"]
	if int(scenarios["class_atlas50"]["atlas_spend"]) != 50 or scenarios["class_atlas50"]["excluded_ids"] != ATLAS50_EXCLUSIONS:
		_errors.append("legal Atlas scenario is not exact requested 50/exclusion set")
	if int(scenarios["class_atlas59_upper"]["atlas_spend"]) != 59 or bool(scenarios["class_atlas59_upper"]["playable"]) or scenarios["class_atlas59_upper"]["label"] != NON_PLAYABLE_LABEL:
		_errors.append("Atlas upper-bound contract mismatch")
	if _mode == "full" and (dataset["formula_live_parity"] as Array).size() != pairs.size():
		_errors.append("live parity does not cover every runtime pair")
	if _mode == "full":
		var telemetry_verification := verify_live_telemetry_artifacts(dataset)
		if not bool(telemetry_verification.get("ok", false)):
			for error_value in telemetry_verification.get("errors", []):
				_errors.append("live telemetry verification failed: %s" % error_value)
	var corridor_verification := verify_class_corridor_artifacts(dataset)
	if not bool(corridor_verification.get("ok", false)):
		for error_value in corridor_verification.get("errors", []):
			_errors.append(str(error_value))


static func verify_dataset_digest(dataset: Dictionary) -> Dictionary:
	var digest := str(dataset.get("dataset_digest_sha256", ""))
	if not digest.is_valid_hex_number() or digest.length() != 64 or digest != digest.to_lower():
		return {"ok": false, "error": "digest is not a lowercase SHA-256 hex string"}
	var payload := dataset.duplicate(true)
	payload.erase("dataset_digest_sha256")
	var expected := _sha256(JSON.stringify(payload, "", true, true))
	if digest != expected:
		return {"ok": false, "error": "digest differs from canonical payload"}
	return {"ok": true}


static func verify_live_telemetry_artifacts(dataset: Dictionary) -> Dictionary:
	var errors := PackedStringArray()
	var telemetry: Dictionary = dataset.get("live_telemetry", {})
	if str(telemetry.get("schema", "")) != LIVE_TELEMETRY_SCHEMA:
		errors.append("telemetry schema mismatch")
	var samples: Array = telemetry.get("samples", [])
	var expected_samples := {}
	var pair_keys: Array = (dataset.get("roster", {}) as Dictionary).get("pair_keys", [])
	for pair_value in pair_keys:
		var pair := str(pair_value)
		for seed_value in LIVE_SEEDS:
			expected_samples[_telemetry_key(pair, int(seed_value), "sustain_solo", "sustain", 1)] = true
			expected_samples[_telemetry_key(pair, int(seed_value), "sustain_pack", "sustain", TARGET_COUNT)] = true
	var actual_samples := {}
	for sample_value in samples:
		if not sample_value is Dictionary:
			errors.append("telemetry sample is not an object")
			continue
		var sample: Dictionary = sample_value
		var sample_key := str(sample.get("sample_key", ""))
		if actual_samples.has(sample_key):
			errors.append("duplicate telemetry sample %s" % sample_key)
		actual_samples[sample_key] = true
		var sample_verification := verify_live_telemetry_sample(sample)
		if not bool(sample_verification.get("ok", false)):
			for error_value in sample_verification.get("errors", []):
				errors.append("%s: %s" % [sample_key, error_value])
	for key in expected_samples:
		if not actual_samples.has(key):
			errors.append("missing sustained telemetry sample %s" % key)
	for key in actual_samples:
		if not expected_samples.has(key) and not str(key).contains("|representative_"):
			errors.append("unexpected telemetry sample %s" % key)
	var fixtures: Array = telemetry.get("representative_fixtures", [])
	var fixture_keys := {}
	for fixture_value in fixtures:
		var fixture: Dictionary = fixture_value
		fixture_keys[str(fixture.get("fixture", ""))] = str(fixture.get("sample_key", ""))
	for fixture_id in ["offensive", "mortal", "incoming_hit"]:
		if not fixture_keys.has(fixture_id):
			errors.append("missing representative fixture %s" % fixture_id)
		elif not actual_samples.has(fixture_keys[fixture_id]):
			errors.append("representative fixture %s does not point at a sample" % fixture_id)
	if fixture_keys.has("offensive") and actual_samples.has(fixture_keys["offensive"]):
		var offensive := _sample_by_key(samples, fixture_keys["offensive"])
		var offensive_counters: Dictionary = offensive.get("counters", {})
		if int(offensive_counters.get("casts", 0)) < 1 or int(offensive_counters.get("hits", 0)) < 1 or float(offensive_counters.get("damage_total", 0.0)) <= 0.0:
			errors.append("offensive fixture does not contain an observed cast and hit")
	if fixture_keys.has("mortal") and actual_samples.has(fixture_keys["mortal"]):
		var mortal := _sample_by_key(samples, fixture_keys["mortal"])
		if not _has_observed_event(mortal.get("events", []), "kill"):
			errors.append("mortal fixture does not contain an observed kill event")
	if fixture_keys.has("incoming_hit") and actual_samples.has(fixture_keys["incoming_hit"]):
		var incoming := _sample_by_key(samples, fixture_keys["incoming_hit"])
		if str(incoming.get("fixture", "")) != "incoming_hit" or not _has_damage_bucket(incoming, "incoming_fixture", "incoming_damage"):
			errors.append("incoming-hit fixture lacks deterministic defensive damage")
	return {"ok": errors.is_empty(), "errors": errors}


static func verify_live_telemetry_sample(sample: Dictionary) -> Dictionary:
	var errors := PackedStringArray()
	var pair := str(sample.get("pair", ""))
	var seed_value := int(sample.get("seed", 0))
	var scenario := str(sample.get("scenario", ""))
	var fixture := str(sample.get("fixture", ""))
	var target_cardinality := int(sample.get("target_cardinality", 0))
	var sample_key := str(sample.get("sample_key", ""))
	if str(sample.get("telemetry_schema", "")) != LIVE_TELEMETRY_SCHEMA:
		errors.append("sample schema mismatch")
	if target_cardinality < 1 or sample_key != _telemetry_key(pair, seed_value, scenario, fixture, target_cardinality):
		errors.append("sample identity does not match pair/seed/scenario/fixture/cardinality")
	var trace_id := str(sample.get("trace_id", ""))
	if trace_id != "%s:%s" % [LIVE_TRACE_PREFIX, sample_key]:
		errors.append("trace id does not match sample identity")
	var fixture_target_ids: Array = sample.get("fixture_target_ids", [])
	if fixture_target_ids.size() != target_cardinality:
		errors.append("fixture target cardinality mismatch")
	var expected_target_ids := []
	for index in range(target_cardinality):
		expected_target_ids.append("player" if fixture == "incoming_hit" else "target_%d" % index)
	if fixture_target_ids != expected_target_ids:
		errors.append("fixture target labels are not deterministic")
	var events: Array = sample.get("events", [])
	var event_by_id := {}
	var event_index_by_id := {}
	var casts := 0
	var hits := []
	var unique_targets := {}
	var buckets := {}
	var final_events := []
	var provenance_ids := {}
	var cast_ids := {}
	for index in range(events.size()):
		var raw_event = events[index]
		if not raw_event is Dictionary:
			errors.append("trace event %d is not an object" % index)
			continue
		var event: Dictionary = raw_event
		var event_id := str(event.get("event_id", ""))
		if event_id != "%s#%04d" % [trace_id, index] or str(event.get("trace_id", "")) != trace_id:
			errors.append("trace event identity mismatch at %d" % index)
		if event_by_id.has(event_id):
			errors.append("duplicate trace event id %s" % event_id)
		event_by_id[event_id] = event
		event_index_by_id[event_id] = index
		var kind := str(event.get("kind", ""))
		if kind == "cast":
			casts += 1
			if str(event.get("source", "")) != "player_weapon" or str(event.get("phase", "")) != "windup":
				errors.append("cast event is not a canonical weapon windup")
			var cast_id := str(event.get("cast_id", ""))
			if cast_id == "" or cast_ids.has(cast_id):
				errors.append("cast provenance id is missing or duplicated")
			cast_ids[cast_id] = true
		elif kind == "hit":
			var source := str(event.get("source", ""))
			var phase := str(event.get("phase", ""))
			var target_id := str(event.get("target_id", ""))
			if source not in ["player_weapon", "incoming_fixture"] or phase not in ["damage_application", "incoming_damage"]:
				errors.append("hit has an untrusted source/phase bucket")
			if not expected_target_ids.has(target_id) or float(event.get("damage", 0.0)) <= 0.0:
				errors.append("hit target or damage is invalid")
			if source == "player_weapon":
				var provenance_id := str(event.get("provenance_id", ""))
				if provenance_id == "" or provenance_ids.has(provenance_id):
					errors.append("canonical hit provenance id is missing or duplicated")
				provenance_ids[provenance_id] = true
			hits.append(event)
			unique_targets[target_id] = true
			var bucket_key := "%s|%s" % [source, phase]
			var bucket: Dictionary = buckets.get(bucket_key, {"source": source, "phase": phase, "damage": 0.0, "hits": 0})
			bucket["damage"] = float(bucket.get("damage", 0.0)) + float(event.get("damage", 0.0))
			bucket["hits"] = int(bucket.get("hits", 0)) + 1
			buckets[bucket_key] = bucket
		elif kind == "final_event":
			if not bool(event.get("observed", false)) or str(event.get("event", "")) == "" or str(event.get("source", "")) != "player_weapon":
				errors.append("final event is not observed runtime evidence")
			if str(event.get("phase", "")) not in ["final_resolution", "final_damage_application", "target_death"]:
				errors.append("final event has an invalid causal phase")
			if not expected_target_ids.has(str(event.get("target_id", ""))):
				errors.append("final event target is invalid")
			final_events.append(event)
		elif kind != "weapon_phase":
			errors.append("unknown trace event kind %s" % kind)
	var counters: Dictionary = sample.get("counters", {})
	var target_ids := unique_targets.keys()
	target_ids.sort()
	if int(counters.get("casts", -1)) != casts or int(counters.get("hits", -1)) != hits.size():
		errors.append("cast/hit counters do not reconstruct from trace")
	if counters.get("unique_target_ids", []) != target_ids or int(counters.get("unique_target_count", -1)) != target_ids.size():
		errors.append("unique target cardinality does not reconstruct from trace")
	var actual_buckets: Array = counters.get("damage_by_source_phase", [])
	var expected_buckets := buckets.values()
	expected_buckets.sort_custom(func(a, b): return "%s|%s" % [a["source"], a["phase"]] < "%s|%s" % [b["source"], b["phase"]])
	if not _bucket_rows_match(actual_buckets, expected_buckets):
		errors.append("source/phase buckets do not reconstruct from trace")
	var total_damage := 0.0
	for bucket_value in expected_buckets:
		total_damage += float((bucket_value as Dictionary).get("damage", 0.0))
	if not is_equal_approx(float(counters.get("damage_total", -1.0)), snappedf(total_damage, 0.0001)):
		errors.append("damage total is not the exclusive source/phase partition")
	if int(counters.get("final_event_count", -1)) != final_events.size():
		errors.append("final event count does not reconstruct from trace")
	var tagged_hits := {}
	for final_event_value in final_events:
		var final_event: Dictionary = final_event_value
		var related_hit_id := str(final_event.get("related_hit_id", ""))
		var final_event_id := str(final_event.get("event_id", ""))
		if related_hit_id == "" or not event_by_id.has(related_hit_id) or str((event_by_id.get(related_hit_id, {}) as Dictionary).get("kind", "")) != "hit":
			errors.append("final event is not linked to a runtime hit")
			continue
		var related_hit: Dictionary = event_by_id[related_hit_id]
		var reciprocal_ids: Array = related_hit.get("final_event_ids", [])
		if reciprocal_ids.count(final_event_id) != 1:
			errors.append("final event reciprocal link is missing or duplicated")
		if str(related_hit.get("target_id", "")) != str(final_event.get("target_id", "")):
			errors.append("final event target does not match related hit")
		var final_index := int(event_index_by_id.get(final_event_id, -1))
		var hit_index := int(event_index_by_id.get(related_hit_id, -1))
		var final_phase := str(final_event.get("phase", ""))
		if (final_phase == "final_resolution" and final_index >= hit_index) or (final_phase in ["final_damage_application", "target_death"] and final_index <= hit_index):
			errors.append("final event causal order is invalid")
		tagged_hits[related_hit_id] = true
	for hit_value in hits:
		var hit: Dictionary = hit_value
		var hit_id := str(hit.get("event_id", ""))
		var final_ids: Array = hit.get("final_event_ids", [])
		var seen_final_ids := {}
		for final_id_value in final_ids:
			var final_id := str(final_id_value)
			if seen_final_ids.has(final_id):
				errors.append("hit repeats a final event id")
			seen_final_ids[final_id] = true
			if not event_by_id.has(final_id) or str((event_by_id[final_id] as Dictionary).get("kind", "")) != "final_event":
				errors.append("hit references a fabricated final event id")
			elif str((event_by_id[final_id] as Dictionary).get("related_hit_id", "")) != hit_id:
				errors.append("hit/final reciprocal reference mismatch")
	var final_damage := 0.0
	for hit_id in tagged_hits:
		final_damage += float((event_by_id[hit_id] as Dictionary).get("damage", 0.0))
	if not is_equal_approx(float(counters.get("final_event_damage", -1.0)), snappedf(final_damage, 0.0001)):
		errors.append("final event damage does not reconstruct from tagged hits")
	if not is_equal_approx(float(counters.get("damage_total", 0.0)), total_damage):
		errors.append("final event metrics must not be added to total damage")
	var ledger: Dictionary = sample.get("hp_ledger", {})
	if str(ledger.get("authority", "")) != "enemy_damage_applied_health_delta" or str(ledger.get("probe_phase", "")) != "measurement":
		errors.append("hp ledger authority or phase is invalid")
	var tolerance := float(ledger.get("tolerance", -1.0))
	if tolerance < 0.0 or tolerance > 0.001:
		errors.append("hp ledger tolerance is invalid")
	var ledger_rows: Array = ledger.get("rows", [])
	var ledger_by_target := {}
	var measurement_hits := {}
	for hit_value in hits:
		var hit: Dictionary = hit_value
		if str(hit.get("source", "")) == "player_weapon" and str(hit.get("probe_phase", "")) == "measurement":
			var target_id := str(hit.get("target_id", ""))
			measurement_hits[target_id] = float(measurement_hits.get(target_id, 0.0)) + float(hit.get("damage", 0.0))
	for row_value in ledger_rows:
		if not row_value is Dictionary:
			errors.append("hp ledger row is not an object")
			continue
		var row: Dictionary = row_value
		var target_id := str(row.get("target_id", ""))
		if not expected_target_ids.has(target_id) or ledger_by_target.has(target_id):
			errors.append("hp ledger target is invalid or duplicated")
			continue
		ledger_by_target[target_id] = row
		var applied := float(row.get("applied_damage", -1.0))
		if applied < 0.0 or absf(applied - float(measurement_hits.get(target_id, 0.0))) > tolerance:
			errors.append("measurement hit damage does not reconcile to hp ledger")
		if fixture != "incoming_hit":
			var health_loss := float(row.get("health_loss", -1.0))
			if health_loss < 0.0 or absf(applied - health_loss) > tolerance:
				errors.append("authoritative health loss does not reconcile to hp ledger")
	for target_id_value in expected_target_ids:
		if not ledger_by_target.has(str(target_id_value)):
			errors.append("hp ledger is missing a fixture target")
	var ledger_total := 0.0
	for row_value in ledger_rows:
		if row_value is Dictionary:
			ledger_total += float((row_value as Dictionary).get("applied_damage", 0.0))
	if absf(ledger_total - float(ledger.get("total_applied_damage", -1.0))) > tolerance:
		errors.append("hp ledger total does not reconstruct from rows")
	if fixture != "incoming_hit":
		var measurement_duration := float(ledger.get("measurement_duration_seconds", 0.0))
		var snapped_duration := float(ledger.get("measurement_duration_snapped_seconds", -1.0))
		var frame_count := int(ledger.get("measurement_frame_count", 0))
		var legacy_numerator := float(ledger.get("legacy_health_delta_numerator", -1.0))
		var projections: Dictionary = ledger.get("dpm_projections", {})
		var expected_dpm := _project_dpm(ledger_total, measurement_duration)
		if measurement_duration <= 0.0 or not is_equal_approx(float(sample.get("dpm", -1.0)), expected_dpm):
			errors.append("reported dpm does not reconcile to measurement hp ledger")
		if frame_count < 1 or snapped_duration <= 0.0 or not is_equal_approx(snapped_duration, snappedf(measurement_duration, 0.0001)):
			errors.append("measurement duration/frame metadata is invalid")
		if legacy_numerator < 0.0:
			errors.append("legacy health delta is invalid")
		var health_loss_total := 0.0
		for row_value in ledger_rows:
			health_loss_total += float((row_value as Dictionary).get("health_loss", 0.0))
		if absf(legacy_numerator - health_loss_total) > tolerance * maxf(1.0, float(ledger_rows.size())):
			errors.append("legacy health delta does not reconstruct from per-target health loss")
		if not is_equal_approx(float(projections.get("legacy_hp_delta_raw_duration_dpm", -1.0)), _project_dpm(legacy_numerator, measurement_duration)):
			errors.append("legacy raw-duration DPM projection is invalid")
		if not is_equal_approx(float(projections.get("ledger_raw_duration_dpm", -1.0)), expected_dpm):
			errors.append("canonical ledger raw-duration DPM projection is invalid")
		if not is_equal_approx(float(projections.get("ledger_snapped_duration_dpm", -1.0)), _project_dpm(ledger_total, snapped_duration)):
			errors.append("snapped-duration diagnostic DPM projection is invalid")
		if not is_equal_approx(float(projections.get("ledger_minus_legacy_numerator", NAN)), ledger_total - legacy_numerator):
			errors.append("ledger/legacy numerator delta is invalid")
		var observer_probe: Dictionary = sample.get("observer_probe", {})
		if str(observer_probe.get("mode", "")) != "enabled" or int(observer_probe.get("measurement_frame_count", 0)) != frame_count or not is_equal_approx(float(observer_probe.get("measurement_duration_seconds", -1.0)), measurement_duration) or not is_equal_approx(float(observer_probe.get("health_delta", -1.0)), legacy_numerator):
			errors.append("observer diagnostic does not reproduce the canonical measurement boundary")
	if str(sample.get("trace_digest_sha256", "")) != _sha256(JSON.stringify(events, "", true, true)):
		errors.append("trace digest mismatch")
	return {"ok": errors.is_empty(), "errors": errors}


static func _telemetry_key(pair: String, seed_value: int, scenario: String, fixture: String, target_cardinality: int) -> String:
	return "%s|%d|%s|%s|%d" % [pair, seed_value, scenario, fixture, target_cardinality]


static func _sample_by_key(samples: Array, sample_key: String) -> Dictionary:
	for sample_value in samples:
		var sample: Dictionary = sample_value
		if str(sample.get("sample_key", "")) == sample_key:
			return sample
	return {}


static func _bucket_rows_match(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for index in range(actual.size()):
		var actual_row: Dictionary = actual[index]
		var expected_row: Dictionary = expected[index]
		if str(actual_row.get("source", "")) != str(expected_row.get("source", "")) or str(actual_row.get("phase", "")) != str(expected_row.get("phase", "")) or int(actual_row.get("hits", -1)) != int(expected_row.get("hits", -1)) or not is_equal_approx(float(actual_row.get("damage", 0.0)), float(expected_row.get("damage", 0.0))):
			return false
	return true


static func _has_observed_event(events: Array, event_name: String) -> bool:
	for event_value in events:
		var event: Dictionary = event_value
		if str(event.get("kind", "")) == "final_event" and str(event.get("event", "")) == event_name and bool(event.get("observed", false)):
			return true
	return false


static func _has_damage_bucket(sample: Dictionary, source: String, phase: String) -> bool:
	var counters: Dictionary = sample.get("counters", {})
	for bucket_value in counters.get("damage_by_source_phase", []):
		var bucket: Dictionary = bucket_value
		if str(bucket.get("source", "")) == source and str(bucket.get("phase", "")) == phase and float(bucket.get("damage", 0.0)) > 0.0:
			return true
	return false


static func render_csv(dataset: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("key,class_id,weapon_id,level,scenario,scenario_label,playable,attack_mode,archetype,axis,final_mechanic,playstyle,strengths,weaknesses,stat_delta,solo_dpm,crowd_10_total_dpm,crowd_10_per_target_dpm,hp,defense,dodge,absorb_flat,conditional_shield_capacity,regeneration_per_second,lifesteal_per_second,mitigation,ehp,ttd_seconds,conditional_defense_factor,pickup_radius,move_speed,healing_multiplier,xp_multiplier,money_multiplier,start_gold,ult_start_charge,death_save,solo_delta_abs,solo_delta_pct,crowd_delta_abs,crowd_delta_pct,ehp_delta_abs,ehp_delta_pct,ttd_delta_abs,ttd_delta_pct,atlas_delta,measurement_method,runs,solo_variance_dpm2,crowd_variance_dpm2")
	for row in dataset["weapon_rows"]:
		var cells := [row["key"], row["class_id"], row["weapon_id"], row["level"], row["scenario"], row["scenario_label"], row["playable"], row["attack_mode"], row["archetype"], row["axis"], row["final_mechanic"], row["playstyle"], row["strengths"], row["weaknesses"], JSON.stringify(row["stat_delta"], "", true, true), row["solo_dpm"], row["crowd_10_total_dpm"], row["crowd_10_per_target_dpm"], row["hp"], row["defense"], row["dodge"], row["absorb_flat"], row["conditional_shield_capacity"], row["regeneration_per_second"], row["lifesteal_per_second"], row["mitigation"], row["ehp"], row["ttd_seconds"], row["conditional_defense_factor"], row["pickup_radius"], row["move_speed"], row["healing_multiplier"], row["xp_multiplier"], row["money_multiplier"], row["start_gold"], row["ult_start_charge"], row["death_save"], row["solo_dpm_delta_abs"], row["solo_dpm_delta_pct"], row["crowd_10_total_dpm_delta_abs"], row["crowd_10_total_dpm_delta_pct"], row["ehp_delta_abs"], row["ehp_delta_pct"], row["ttd_seconds_delta_abs"], row["ttd_seconds_delta_pct"], row["atlas_delta_summary"], row["measurement_method"], row["runs"], row["solo_variance_dpm2"], row["crowd_variance_dpm2"]]
		var escaped := PackedStringArray()
		for cell in cells:
			escaped.append(_csv_cell(str(cell)))
		lines.append(",".join(escaped))
	return "\n".join(lines) + "\n"


static func render_markdown(dataset: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("# FAN-1438 — A5 character and weapon balance report")
	lines.append("")
	lines.append("Source commit `%s` (tree `%s`, timestamp `%s`), Godot `%s`. Dataset digest: `%s`." % [dataset["source"]["commit"], dataset["source"]["tree"], dataset["source"]["commit_timestamp"], dataset["source"]["godot"], dataset["dataset_digest_sha256"]])
	lines.append("")
	lines.append("The live roster is **%d classes / %d class-weapon pairs**. The primary matrix is **%d rows** = pairs × 2 levels × 4 meta scenarios. This report changes no balance values." % [dataset["roster"]["class_count"], dataset["roster"]["weapon_pair_count"], (dataset["weapon_rows"] as Array).size()])
	lines.append("")
	lines.append("## Method and controlled inputs")
	lines.append("")
	lines.append("- A5 means selected difficulty 5 plus cumulative earned A1-A5 class rewards. The distinction is explicit in raw data.")
	lines.append("- Level 1 uses base stats. Level 20 is the requested synthetic 19-point base-stat model, one shared allocation across all three weapons of a class; it is not represented as live reward-card history.")
	lines.append("- Per-weapon DPM is sustained output with `include_ultimate=false`. First-minute ultimate contribution appears only in the class-kit table.")
	lines.append("- Ten-target DPM is total throughput over a compact deterministic pack; per-target DPM is total / 10.")
	lines.append("- Formula rows use canonical `ProgressionData`, `MetaProgression`, schema-6 profiles, and the A5 runtime modifier order. The class-kit ultimate starts from unmodified level stats and applies class/Atlas attribute and run modifiers exactly once. Full-constellation L20 live probes instantiate real Player/Enemy scenes for every pair (%d seeds, %.1fs warm-up, %.1fs measured)." % [LIVE_SEEDS.size(), LIVE_WARMUP_SECONDS, LIVE_WINDOW_SECONDS])
	lines.append("- Survival is a normal-wave A5 contact-pressure model: %.1f base damage, %.1f attempted hits/s, actual 0.32s player i-frame; absorb → defense → expected dodge → sustain. Boss/elite multipliers are intentionally not substituted." % [A5_NORMAL_CONTACT_DAMAGE, A5_NORMAL_CONTACT_RATE])
	lines.append("")
	lines.append("## Meta legality")
	lines.append("")
	for scenario_id in SCENARIO_IDS:
		var scenario: Dictionary = dataset["scenarios"][scenario_id]
		lines.append("- `%s`: %s; class spend %d, Atlas spend %d, playable=%s." % [scenario_id, scenario["label"], scenario["class_spend"], scenario["atlas_spend"], scenario["playable"]])
	lines.append("- The legal 50-dust build purchases every paid Guild node except `atlas_m2`, `atlas_m3`, `atlas_k0` (2+2+5 dust). Guild hidden nodes use explicit all-monster-Codex and secret-boss facts and cost zero.")
	lines.append("- The 59-dust result is labeled **%s** everywhere and is only a conservative upper bound." % NON_PLAYABLE_LABEL)
	lines.append("- Raw `meta_builds` lists the free core, all 20 purchased class node IDs, both reveal facts, and the exact owning-weapon profile nodes for every class. Modifier rule: fractions become `1+sum` and multiply their runtime channel; flat values add; weapon profiles never cross weapon IDs.")
	lines.append("")
	lines.append("## Class-kit summary")
	lines.append("")
	lines.append("| Class | Lvl | Scenario | Weapon roles | Solo score | AoE score | Defense score | Convenience score | Ult first minute | Strengths | Weaknesses | Flag |")
	lines.append("| --- | ---: | --- | --- | ---: | ---: | ---: | ---: | ---: | --- | --- | --- |")
	for row in dataset["class_rows"]:
		lines.append("| %s | %d | %s | %s | %.3f | %.3f | %.3f | %.3f | %.2f | %s | %s | %s |" % [row["class_id"], row["level"], row["scenario"], "; ".join(row["roles"]), row["solo_score"], row["aoe_score"], row["defense_score"], row["convenience_relative"], row["first_minute_ultimate_damage"], row["strengths"], row["weaknesses"], row["outlier_flag"]])
	lines.append("")
	lines.append("## Per-weapon matrix")
	lines.append("")
	lines.append("Absolute and percent deltas are against the same class / weapon / level `no_meta` control. `Shield` is conditional capacity only and is not folded into permanent HP.")
	lines.append("")
	lines.append("| Class / weapon | Lvl | Scenario | Playstyle | Strengths | Weaknesses | Mode / axis / final | Stats Δ | Solo DPM (Δ%) | 10T total / per target DPM (Δ%) | HP / EHP / TTD | Mitigation / dodge / absorb / shield | Regen / lifesteal | Pickup / move | Atlas Δ | Runs / variance (solo;10T) |")
	lines.append("| --- | ---: | --- | --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |")
	for row in dataset["weapon_rows"]:
		lines.append("| %s/%s | %d | %s | %s | %s | %s | %s / %s / %s | %s | %.2f (%+.2f%%) | %.2f / %.2f (%+.2f%%) | %.2f / %.2f / %.2f | %.4f / %.4f / %.2f / %.2f | %.2f / %.2f | %.2f / %.2f | %s | %d / %.2f;%.2f |" % [row["class_id"], row["weapon_id"], row["level"], row["scenario_label"], row["playstyle"], row["strengths"], row["weaknesses"], row["attack_mode"], row["axis"], row["final_mechanic"], _delta_text(row["stat_delta"]), row["solo_dpm"], row["solo_dpm_delta_pct"], row["crowd_10_total_dpm"], row["crowd_10_per_target_dpm"], row["crowd_10_total_dpm_delta_pct"], row["hp"], row["ehp"], row["ttd_seconds"], row["mitigation"], row["dodge"], row["absorb_flat"], row["conditional_shield_capacity"], row["regeneration_per_second"], row["lifesteal_per_second"], row["pickup_radius"], row["move_speed"], row["atlas_delta_summary"], row["runs"], row["solo_variance_dpm2"], row["crowd_variance_dpm2"]])
	lines.append("")
	lines.append("## Formula / live parity")
	lines.append("")
	if (dataset["formula_live_parity"] as Array).is_empty():
		lines.append("Formula-only generation; final evidence requires `--mode=full`.")
	else:
		lines.append("| Pair | Attack mode | Final (event) | Formula solo / live mean±sd DPM | Δ | Formula 10T / live mean±sd DPM | Δ | Observation |")
		lines.append("| --- | --- | --- | ---: | ---: | ---: | ---: | --- |")
		for row in dataset["formula_live_parity"]:
			lines.append("| %s | %s | %s (%s) | %.2f / %.2f±%.2f | %+.2f%% | %.2f / %.2f±%.2f | %+.2f%% | %s |" % [row["pair"], row["attack_mode"], row["final_mechanic"], row["final_event"], row["formula_solo_dpm"], row["live_solo_dpm_mean"], row["live_solo_dpm_stddev"], row["solo_delta_pct"], row["formula_pack_dpm"], row["live_pack_dpm_mean"], row["live_pack_dpm_stddev"], row["pack_delta_pct"], row["runtime_observation"]])
	lines.append("")
	lines.append("## Live event telemetry")
	lines.append("")
	var telemetry: Dictionary = dataset.get("live_telemetry", {})
	var telemetry_samples: Array = telemetry.get("samples", [])
	if telemetry_samples.is_empty():
		lines.append("Formula-only generation; runtime telemetry requires `--mode=full`.")
	else:
		lines.append("Schema `%s`: every live sample has a deterministic pair/seed/scenario/fixture trace identifier, unique cast and canonical-hit provenance IDs, stable target labels, exclusive source×phase damage buckets, reciprocal final-event-to-hit links with target/order validation, and an HP ledger from canonical enemy health deltas. The representative offensive and incoming fixtures require observed events; a short sustained window may validly record a zero counter for a delayed deploy/summon action. Final-event damage is a deduplicated tagged subset of those buckets and is not added to total damage again." % telemetry.get("schema", ""))
		lines.append("")
		lines.append("| Representative fixture | Trace | Casts | Hits | Unique targets | Total damage | Final events / tagged damage |")
		lines.append("| --- | --- | ---: | ---: | --- | ---: | ---: |")
		for fixture_value in telemetry.get("representative_fixtures", []):
			var fixture: Dictionary = fixture_value
			var sample := _sample_by_key(telemetry_samples, str(fixture.get("sample_key", "")))
			var counters: Dictionary = sample.get("counters", {})
			lines.append("| %s | `%s` | %d | %d | %s | %.4f | %d / %.4f |" % [fixture.get("fixture", ""), sample.get("trace_id", ""), counters.get("casts", 0), counters.get("hits", 0), ", ".join(counters.get("unique_target_ids", [])), counters.get("damage_total", 0.0), counters.get("final_event_count", 0), counters.get("final_event_damage", 0.0)])
	lines.append("")
	lines.append("## Outliers and conclusions")
	lines.append("")
	lines.append("- Class corridor flags (outside 80–120%% of the same level/scenario median across solo, AoE, or defense): **%d**." % (dataset["outliers"]["class_corridor_80_120"] as Array).size())
	lines.append("- Formula/live differences over 35%% on either axis: **%d**. These are instrumentation/tuning investigation candidates, not automatic nerf/buff decisions." % (dataset["outliers"]["formula_live_delta_over_35pct"] as Array).size())
	lines.append("- Raw outlier keys and exact ratios are in `raw.json.gz`; the complete numeric matrix is in `per_weapon.csv`.")
	lines.append("- No balance values or mechanics were changed by FAN-1438.")
	lines.append("")
	lines.append("## Limitations")
	lines.append("")
	for limitation in dataset["limitations"]:
		lines.append("- %s" % limitation)
	return "\n".join(lines) + "\n"


func _schema_branch(class_id: String, weapon_id: String) -> Dictionary:
	for raw_branch in Schema6.class_entry(class_id).get("weapon_branches", []):
		if str((raw_branch as Dictionary).get("weapon_id", "")) == weapon_id:
			return raw_branch as Dictionary
	return {}


func _final_node(branch: Dictionary) -> Dictionary:
	for raw_node in branch.get("nodes", []):
		if str((raw_node as Dictionary).get("role", "")) == "weapon_final":
			return raw_node as Dictionary
	return {}


func _atlas_paid_ids() -> Array:
	var ids := []
	for raw_node in Meta.atlas_nodes():
		var node: Dictionary = raw_node
		if int(node.get("cost", 0)) > 0 and str(node.get("role", "")) not in ["core", "hidden"]:
			ids.append(str(node.get("id", "")))
	ids.sort()
	return ids


func _node_cost(ids: Array) -> int:
	var total := 0
	for node_id in ids:
		total += int(Meta.node_by_id(str(node_id)).get("cost", 0))
	return total


func _config_with_class(config: Dictionary, class_id: String) -> Dictionary:
	var result := config.duplicate(true)
	result["character_id"] = class_id
	return result


func _stat_delta(base_stats: Dictionary, stats: Dictionary) -> Dictionary:
	var result := {}
	for stat_id in base_stats:
		var delta := int(round(float(stats.get(stat_id, 0.0)) - float(base_stats.get(stat_id, 0.0))))
		if delta != 0:
			result[stat_id] = delta
	return result


func _delta_sum(base_stats: Dictionary, stats: Dictionary) -> int:
	var total := 0
	for stat_id in base_stats:
		total += int(round(float(stats.get(stat_id, 0.0)) - float(base_stats.get(stat_id, 0.0))))
	return total


static func _delta_text(delta: Dictionary) -> String:
	if delta.is_empty():
		return "base"
	var parts := PackedStringArray()
	var keys := delta.keys()
	keys.sort()
	for key in keys:
		parts.append("%s+%d" % [key, int(delta[key])])
	return "; ".join(parts)


func _find_weapon_row(rows: Array, class_id: String, weapon_id: String, level: int, scenario_id: String) -> Dictionary:
	for row in rows:
		if row["class_id"] == class_id and row["weapon_id"] == weapon_id and row["level"] == level and row["scenario"] == scenario_id:
			return row
	return {}


func _mean(rows: Array, key: String) -> float:
	var values := []
	for row in rows:
		values.append(float(row.get(key, 0.0)))
	return _number_mean(values)


func _number_mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += float(value)
	return total / values.size()


func _stddev(values: Array, mean: float) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += pow(float(value) - mean, 2.0)
	return sqrt(total / values.size())


func _median_metric(rows: Array, key: String) -> float:
	var values := []
	for row in rows:
		values.append(float(row.get(key, 0.0)))
	values.sort()
	if values.is_empty():
		return 0.0
	if values.size() % 2 == 1:
		return values[values.size() / 2]
	return (float(values[values.size() / 2 - 1]) + float(values[values.size() / 2])) * 0.5


func _class_strengths(solo: float, crowd: float, ehp: float, utility: float) -> String:
	var scores := [{"name": "solo", "value": solo / 7000.0}, {"name": "crowd", "value": crowd / 22000.0}, {"name": "survival", "value": ehp / 180.0}, {"name": "convenience", "value": utility}]
	scores.sort_custom(func(a, b): return float(a["value"]) > float(b["value"]))
	return "%s + %s" % [scores[0]["name"], scores[1]["name"]]


func _weapon_strength(axis: String, identity: String) -> String:
	var axis_text: String = {"solo": "durable-target pressure", "crowd": "compact-pack throughput", "aoe": "area coverage", "defense": "control/defensive utility"}.get(axis, "mixed output")
	return "%s; %s" % [axis_text, identity]


func _weapon_weakness(axis: String) -> String:
	match axis:
		"solo": return "Lower role budget for dense packs; kill-gated value is absent on immortal dummies."
		"crowd", "aoe": return "Compact-pack strength does not imply equal boss pressure."
		"defense": return "Conditional control/guard value is not converted into permanent shield HP."
	return "Mixed role; inspect live parity before tuning."


func _class_weaknesses(solo: float, crowd: float, ehp: float, utility: float) -> String:
	var scores := [{"name": "solo", "value": solo / 7000.0}, {"name": "crowd", "value": crowd / 22000.0}, {"name": "survival", "value": ehp / 180.0}, {"name": "convenience", "value": utility}]
	scores.sort_custom(func(a, b): return float(a["value"]) < float(b["value"]))
	return "%s + %s" % [scores[0]["name"], scores[1]["name"]]


static func _csv_cell(value: String) -> String:
	return "\"%s\"" % value.replace("\"", "\"\"")


static func _sha256(value: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value.to_utf8_buffer())
	return context.finish().hex_encode()


func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_errors.append("cannot write %s" % path)
		return
	file.store_string(content)
	file.close()


func _write_raw_artifact(content: String) -> void:
	var staging_path := "user://fan1438_a5_raw_staging.json"
	_write_text(staging_path, content)
	if not _errors.is_empty():
		return
	var output: Array = []
	var exit_code := OS.execute("python3", [ProjectSettings.globalize_path(GZIP_ARTIFACT_SCRIPT), "pack", ProjectSettings.globalize_path(staging_path), ProjectSettings.globalize_path(RAW_PATH)], output, true)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(staging_path))
	if exit_code != 0:
		_errors.append("cannot write deterministic gzip raw artifact: %s" % "\n".join(output))
		return
	if FileAccess.file_exists(LEGACY_RAW_PATH):
		var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(LEGACY_RAW_PATH))
		if remove_error != OK:
			_errors.append("cannot remove replaced legacy raw artifact %s" % LEGACY_RAW_PATH)


static func read_raw_artifact(path := RAW_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "raw gzip artifact is missing"}
	var staging_path := "user://fan1438_a5_raw_integrity.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(staging_path))
	var output: Array = []
	var exit_code := OS.execute("python3", [ProjectSettings.globalize_path(GZIP_ARTIFACT_SCRIPT), "unpack", ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(staging_path)], output, true)
	if exit_code != 0:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(staging_path))
		return {"ok": false, "error": "\n".join(output)}
	var file := FileAccess.open(staging_path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "cannot read decoded raw artifact"}
	var text := file.get_as_text()
	file.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(staging_path))
	return {"ok": true, "text": text}
