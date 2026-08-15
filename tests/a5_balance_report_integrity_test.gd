extends SceneTree

# FAN-1438: fail-closed integrity guard for the CURRENT regenerable A5 report
# artifacts (report.md, per_weapon.csv, raw.json.gz under Generator.REPORT_DIR).
#
# FAN-1730: this suite deliberately reads Generator.RAW_PATH unconditionally and
# fails closed when that artifact is missing or corrupted — that is its contract.
# The immutable f09 oracle/lineage contract is therefore NOT here: it lives in
# tests/a5_balance_report_lineage_test.gd, which reads only
# tests/fixtures/a5_f09_oracle.json.gz and never opens RAW_PATH. Splitting the two
# keeps both fail-closed and makes the lineage verdict independent of the state of
# the artifact a successful `--mode=full` run rewrites.

const PD := preload("res://scripts/progression_data.gd")
const Meta := preload("res://scripts/meta_progression.gd")
const PlayerScript := preload("res://scripts/player.gd")
const CodexData := preload("res://scripts/codex_data.gd")
const Schema6 := preload("res://scripts/constellation_schema6_data.gd")
const Generator := preload("res://tools/a5_balance_report.gd")
const A5_SCHEMA := Generator.A5_ARTIFACT_SCHEMA_V4
const LEGACY_FINAL_EXECUTION_MUTATION_COUNT := 14
const LEGACY_DISPOSITION_MUTATION_COUNT := 7
const REQUIRED_DISPOSITION_MUTATION_COUNT := 8
const SHIPPED_FINAL_EXECUTION_MUTATION_COUNT := 6
# FAN-2504: the axis labels the class-ratio sentences and corridor flags publish,
# mapped back to the numeric class-row field each one renders.
const CLASS_RATIO_AXIS_FIELDS := {
	"solo": "solo_score",
	"AoE": "aoe_score",
	"survival": "defense_score",
	"defense": "defense_score",
	"convenience": "convenience_relative",
}
const ROBOT_REACTOR_PAIR := "robot/robot_reactor_core"
const ROBOT_REACTOR_MECHANIC := "reactor_vent_cycle_pulse"
const ROBOT_REACTOR_PULSE_RATIO := 0.40
const ROBOT_REACTOR_MINIMUM_MEASURED_RATIO := 0.25
# FAN-2388: pinned independently of Generator.production_formula_basis so the
# disposition fixture cannot silently mirror a regression in that function —
# captured once from the current berserk/sword L20/ascension-5 production
# build; see docs/design/systems/progression_balance.md.
const PINNED_BERSERK_SWORD_FORMULA_BASIS := {
	"damage_parameter": "damage",
	"fire_interval_seconds": 0.18,
	"cast_rate_per_second": 5.555556,
	"hit_damage": 27.103674,
	"direct_dpm": 9034.558061,
}

var _errors := PackedStringArray()


func _initialize() -> void:
	var raw_artifact := Generator.read_raw_artifact(Generator.RAW_PATH)
	_check(bool(raw_artifact.get("ok", false)), "raw.json.gz must decode and validate: %s" % raw_artifact.get("error", "unknown error"))
	var raw_text := str(raw_artifact.get("text", ""))
	var report_text := _read_text(Generator.REPORT_PATH)
	var raw = JSON.parse_string(raw_text)
	_check(raw is Dictionary, "raw.json.gz must parse as an object")
	if not raw is Dictionary:
		_finish()
		return
	var dataset := raw as Dictionary
	_check(str(dataset.get("schema", "")) == str(A5_SCHEMA.get("raw_schema", "")), "raw schema mismatch")
	_check(str(dataset.get("issue_id", "")) == "FAN-1438", "issue id mismatch")
	_check(str((dataset.get("source", {}) as Dictionary).get("commit", "")) not in ["", "UNSPECIFIED", "TEST"], "source commit is not pinned")
	_check(str((dataset.get("source", {}) as Dictionary).get("tree", "")) not in ["", "UNSPECIFIED", "TEST"], "source tree is not pinned")
	_validate_source_provenance(dataset)
	_validate_supplemental_provenance_gate(dataset)
	_validate_raw_artifact(dataset, raw_text)
	_validate_independent_artifact_contract(dataset, report_text)
	_validate_roster(dataset)
	_validate_builds(dataset)
	_validate_meta(dataset)
	_validate_weapon_rows(dataset)
	_validate_class_rows(dataset)
	_validate_class_corridor(dataset, report_text)
	_validate_class_ratio_formatting(dataset)
	_validate_class_ultimate_oracle(dataset)
	_validate_live_coverage(dataset)
	_validate_csv(dataset)
	_validate_markdown(dataset, report_text)
	_validate_censer_final_execution_fixture()
	_validate_final_execution_falsification(dataset)
	_validate_shipped_final_execution(dataset)
	_validate_independent_reactor_amplification_oracle(dataset)
	_finish()


# FAN-2224: the anti-false-green suite. A structurally valid production-shaped row
# is built once, asserted admissible, and then mutated the way a forged candidate
# would be: a trace lifted from another pair, a relabelled ladder, a substituted or
# missing event, a harness-authored fallback hit, a foreign executor, a tampered
# aggregate. Every mutation recomputes the digests that the previous evidence model
# relied on, so passing this suite means the digests are no longer the guard.
func _validate_final_execution_falsification(dataset: Dictionary) -> void:
	var baseline := _final_execution_fixture()
	var baseline_errors := Generator.verify_final_execution_row(baseline)
	_check(baseline_errors.is_empty(), "the production-shaped final-execution fixture must be admissible: %s" % "; ".join(baseline_errors))
	if not baseline_errors.is_empty():
		return
	var status_trace := baseline.duplicate(true)
	var status_event: Dictionary = ((status_trace["telemetry"] as Dictionary)["events"] as Array)[3]
	status_event["phase"] = "target_status_transition"
	status_event["event"] = "status_transition"
	status_event["status_marker"] = "constellation_sword_repeat_execute_owner"
	var status_payoff: Dictionary = status_trace["payoff"]
	status_payoff["kind"] = "target_status_transition"
	status_payoff["binding"] = "frame_ordered"
	status_payoff["provenance_bound_hits"] = 0
	status_payoff["provenance_bound_damage"] = 0.0
	status_payoff["post_activation_hits"] = 1
	status_payoff["post_activation_damage"] = 14.0
	status_payoff["target_status_markers"] = ["constellation_sword_repeat_execute_owner"]
	status_payoff["amplified_hit_mean"] = 0.0
	status_payoff["observed_damage_ratio"] = 0.0
	(status_trace["telemetry"] as Dictionary)["trace_digest_sha256"] = Generator.canonical_trace_digest((status_trace["telemetry"] as Dictionary).get("events", []))
	_check(Generator.verify_final_execution_row(status_trace).is_empty(), "the phase-bound target-status fixture must be admissible")
	var named_marker_only := status_trace.duplicate(true)
	var forged_status_event: Dictionary = ((named_marker_only["telemetry"] as Dictionary)["events"] as Array)[3]
	forged_status_event["phase"] = "final_resolution"
	forged_status_event.erase("status_marker")
	(named_marker_only["telemetry"] as Dictionary)["trace_digest_sha256"] = Generator.canonical_trace_digest((named_marker_only["telemetry"] as Dictionary).get("events", []))
	_check("; ".join(Generator.verify_final_execution_row(named_marker_only)).contains("status payoff does not reconstruct"), "a named target marker without a phase-bound trace transition must fail")
	var owner_trace := baseline.duplicate(true)
	var owner_event: Dictionary = ((owner_trace["telemetry"] as Dictionary)["events"] as Array)[3]
	owner_event["source"] = "player"
	owner_event["phase"] = "owner_state_transition"
	owner_event["target_id"] = "player"
	owner_event["event"] = "owner_state_transition"
	owner_event.erase("related_hit_id")
	owner_event["owner_state_before"] = {"health": 10.0}
	owner_event["owner_state_after"] = {"health": 11.0}
	owner_event["owner_state_delta"] = {"health": 1.0}
	owner_event["owner_final_marker"] = true
	var owner_payoff: Dictionary = owner_trace["payoff"]
	owner_payoff["kind"] = "owner_state_transition"
	owner_payoff["binding"] = "frame_ordered"
	owner_payoff["provenance_bound_hits"] = 0
	owner_payoff["provenance_bound_damage"] = 0.0
	owner_payoff["post_activation_hits"] = 1
	owner_payoff["post_activation_damage"] = 14.0
	owner_payoff["owner_state_delta"] = {"health": 1.0}
	owner_payoff["owner_final_marker"] = true
	owner_payoff["amplified_hit_mean"] = 0.0
	owner_payoff["observed_damage_ratio"] = 0.0
	(owner_trace["telemetry"] as Dictionary)["trace_digest_sha256"] = Generator.canonical_trace_digest((owner_trace["telemetry"] as Dictionary).get("events", []))
	_check(Generator.verify_final_execution_row(owner_trace).is_empty(), "the trace-backed owner-state fixture must be admissible")
	var forged_owner := owner_trace.duplicate(true)
	(forged_owner["payoff"] as Dictionary)["owner_state_delta"] = {}
	_check("; ".join(Generator.verify_final_execution_row(forged_owner)).contains("owner-state payoff does not reconstruct"), "owner payoff fields must not override the owner trace")
	var legacy_mutations := _final_execution_mutations(baseline)
	_check(legacy_mutations.size() == LEGACY_FINAL_EXECUTION_MUTATION_COUNT, "final-execution mutation catalog is unexpectedly short")
	# FAN-2388 negative control: prove the guard above is reachable, not just an
	# identity between two literals written together — a catalog one case short
	# of the pinned count must actually flip the comparison to false.
	var shrunk_legacy_mutations: Array = legacy_mutations.duplicate()
	shrunk_legacy_mutations.remove_at(0)
	_check(shrunk_legacy_mutations.size() != LEGACY_FINAL_EXECUTION_MUTATION_COUNT, "a final-execution mutation catalog short one legacy case must trip the count guard")
	for mutation_value in legacy_mutations:
		var mutation: Dictionary = mutation_value
		var mutated: Dictionary = mutation.get("row", {})
		_check(not Generator.verify_final_execution_row(mutated).is_empty(), "final-execution verification accepts a forged row: %s" % mutation.get("name", "?"))
	var disposition_dataset := _disposition_dataset(baseline)
	_check(bool(Generator.verify_formula_live_dispositions(disposition_dataset).get("ok", false)), "the production-shaped disposition fixture must be admissible: %s" % "; ".join(Generator.verify_formula_live_dispositions(disposition_dataset).get("errors", [])))
	var json_round_trip: Variant = JSON.parse_string(JSON.stringify(disposition_dataset, "", true, true))
	_check(json_round_trip is Dictionary and bool(Generator.verify_formula_live_dispositions(json_round_trip as Dictionary).get("ok", false)), "formula/live disposition verification must admit its JSON round trip")
	# This artifact deliberately claims a single-pair roster: it only probes JSON
	# round-trip encoding of one row, never a shipped dataset, so it opts out of
	# the full-roster coverage gate explicitly instead of relying on it being
	# silently skipped.
	var execution_artifact := {
		"roster": {"pair_keys": [baseline["pair"]]},
		"final_execution": {
			"schema": Generator.FINAL_EXECUTION_SCHEMA,
			"seeds": Generator.FINAL_EXECUTION_SEEDS,
			"warmup_seconds": Generator.FINAL_EXECUTION_WARMUP_SECONDS,
			"window_seconds": Generator.FINAL_EXECUTION_WINDOW_SECONDS,
			"payoff_kinds": Generator.FINAL_EXECUTION_PAYOFF_KINDS,
			"rows": [baseline],
		},
	}
	var execution_round_trip: Variant = JSON.parse_string(JSON.stringify(execution_artifact, "", true, true))
	if execution_round_trip is Dictionary:
		var round_rows: Array = ((execution_round_trip as Dictionary).get("final_execution", {}) as Dictionary).get("rows", [])
		if not round_rows.is_empty():
			var round_sample: Dictionary = (round_rows[0] as Dictionary).get("telemetry", {})
			round_sample["trace_digest_sha256"] = Generator.canonical_trace_digest(round_sample.get("events", []))
	var execution_round_trip_verification: Dictionary = Generator.verify_final_execution_artifacts(execution_round_trip as Dictionary, false) if execution_round_trip is Dictionary else {"ok": false, "errors": ["JSON round trip is not an object"]}
	_check(bool(execution_round_trip_verification.get("ok", false)), "final-execution verification must admit its JSON round trip: %s" % "; ".join(execution_round_trip_verification.get("errors", [])))
	var forged_seed_ladder: Dictionary = execution_artifact.duplicate(true)
	((forged_seed_ladder["final_execution"] as Dictionary)["seeds"] as Array)[0] = int(Generator.FINAL_EXECUTION_SEEDS[0]) + 1
	_check(not bool(Generator.verify_final_execution_artifacts(forged_seed_ladder, false).get("ok", true)), "final-execution verification accepts a substituted seed ladder")
	_validate_final_execution_roster_guard(dataset)
	var disposition_mutations := _disposition_mutations(disposition_dataset)
	_check(disposition_mutations.size() == REQUIRED_DISPOSITION_MUTATION_COUNT, "formula/live mutation catalog is unexpectedly short")
	# LEGACY_DISPOSITION_MUTATION_COUNT is the pre-FAN-2316 catalog; exactly one
	# case (the pinned production-basis provenance check) was added on top of it.
	# Both the count and the added case's identity are checked against the actual
	# runtime catalog, not against another hardcoded literal.
	_check(disposition_mutations.size() - LEGACY_DISPOSITION_MUTATION_COUNT == 1, "formula/live mutation catalog gained or lost cases beyond the FAN-2316 basis-provenance addition")
	_check(str((disposition_mutations[disposition_mutations.size() - 1] as Dictionary).get("name", "")) == "self-consistent but non-production formula basis", "formula/live mutation catalog lost its FAN-2316 production-basis provenance case")
	var shrunk_disposition_mutations: Array = disposition_mutations.duplicate()
	shrunk_disposition_mutations.remove_at(0)
	_check(shrunk_disposition_mutations.size() != REQUIRED_DISPOSITION_MUTATION_COUNT, "a formula/live mutation catalog short one legacy case must trip the count guard")
	for mutation_value in disposition_mutations:
		var mutation: Dictionary = mutation_value
		_check(not bool(Generator.verify_formula_live_dispositions(mutation.get("dataset", {})).get("ok", false)), "formula/live disposition verification accepts a forged dataset: %s" % mutation.get("name", "?"))
	_validate_shipped_final_execution_falsification(dataset)


# FAN-2388 negative control: an internally self-consistent (rows match their
# own claimed pair_keys) but truncated or reordered roster is exactly the shape
# a forged shipped artifact would take. verify_final_execution_artifacts must
# reject both explicitly instead of silently skipping binding-kind/baseline
# coverage the way it used to for any non-full roster.
func _validate_final_execution_roster_guard(dataset: Dictionary) -> void:
	if not dataset.has("final_execution"):
		return
	var pairs: Array = (dataset.get("roster", {}) as Dictionary).get("pair_keys", [])
	var rows: Array = (dataset.get("final_execution", {}) as Dictionary).get("rows", [])
	if pairs.size() < 2 or rows.size() < 2:
		return
	var truncated := dataset.duplicate(true)
	var truncated_pairs: Array = (truncated["roster"] as Dictionary)["pair_keys"]
	truncated_pairs.remove_at(truncated_pairs.size() - 1)
	var truncated_rows: Array = (truncated["final_execution"] as Dictionary)["rows"]
	truncated_rows.remove_at(truncated_rows.size() - 1)
	var truncated_verification := Generator.verify_final_execution_artifacts(truncated)
	_check(not bool(truncated_verification.get("ok", true)), "a final-execution roster truncated by one pair must fail closed")
	_check("; ".join(truncated_verification.get("errors", [])).contains("truncated or reordered"), "a truncated final-execution roster must report the explicit roster guard")
	var reordered := dataset.duplicate(true)
	var reordered_pairs: Array = (reordered["roster"] as Dictionary)["pair_keys"]
	var reordered_rows: Array = (reordered["final_execution"] as Dictionary)["rows"]
	var pair_swap = reordered_pairs[0]
	reordered_pairs[0] = reordered_pairs[1]
	reordered_pairs[1] = pair_swap
	var row_swap = reordered_rows[0]
	reordered_rows[0] = reordered_rows[1]
	reordered_rows[1] = row_swap
	var reordered_verification := Generator.verify_final_execution_artifacts(reordered)
	_check(not bool(reordered_verification.get("ok", true)), "a reordered final-execution roster must fail closed")
	_check("; ".join(reordered_verification.get("errors", [])).contains("truncated or reordered"), "a reordered final-execution roster must report the explicit roster guard")


func _validate_shipped_final_execution(dataset: Dictionary) -> void:
	var is_v4 := str(dataset.get("schema", "")) == "fan2224.a5-balance.v4"
	if is_v4:
		_check(dataset.has("final_execution"), "v4 raw artifact must carry final-execution evidence")
		_check(dataset.has("formula_live_dispositions"), "v4 raw artifact must carry formula/live dispositions")
		var missing_execution := dataset.duplicate(true)
		missing_execution.erase("final_execution")
		_check(not bool(Generator.verify_final_execution_artifacts(missing_execution).get("ok", true)), "v4 artifact without final_execution must fail closed")
		_check(not bool(Generator.verify_formula_live_dispositions(missing_execution).get("ok", true)), "v4 artifact without final_execution dispositions must fail closed")
	if not dataset.has("final_execution") or not dataset.has("formula_live_dispositions"):
		return
	var verification := Generator.verify_final_execution_artifacts(dataset)
	_check(bool(verification.get("ok", false)), "shipped final-execution evidence is not admissible: %s" % "; ".join(verification.get("errors", [])))
	var dispositions := Generator.verify_formula_live_dispositions(dataset)
	_check(bool(dispositions.get("ok", false)), "shipped formula/live dispositions are not admissible: %s" % "; ".join(dispositions.get("errors", [])))


func _validate_shipped_final_execution_falsification(dataset: Dictionary) -> void:
	var rows: Array = (dataset.get("final_execution", {}) as Dictionary).get("rows", [])
	var by_kind := {}
	var by_binding := {}
	var baseline := {}
	for row_value in rows:
		var row: Dictionary = row_value
		var payoff: Dictionary = row.get("payoff", {})
		by_kind[str(payoff.get("kind", ""))] = row
		by_binding[str(payoff.get("binding", ""))] = row
		if str(row.get("pair", "")) == Generator.FINAL_EXECUTION_REPRESENTATIVE_BASELINE_PAIR:
			baseline = row
	_check(by_kind.keys().size() == Generator.FINAL_EXECUTION_PAYOFF_KINDS.size(), "shipped final-execution matrix must cover every payoff kind")
	_check(by_binding.keys().size() == Generator.FINAL_EXECUTION_BINDING_KINDS.size(), "shipped final-execution matrix must cover every binding kind")
	if baseline.is_empty():
		_check(false, "shipped final-execution matrix lacks the representative baseline row")
		return
	var baseline_payoff: Dictionary = baseline.get("payoff", {})
	_check(int(baseline_payoff.get("pre_activation_hits", 0)) > 0 and float(baseline_payoff.get("pre_activation_damage", 0.0)) > 0.0, "representative final-execution baseline must precede activation")
	for multiplier in [0.5, 1.5]:
		var altered := baseline.duplicate(true)
		(altered["payoff"] as Dictionary)["amplified_hit_mean"] = float((altered["payoff"] as Dictionary).get("amplified_hit_mean", 0.0)) * multiplier
		_check(not Generator.verify_final_execution_row(altered).is_empty(), "baseline amplification %0.1fx must fail final-execution verification" % multiplier)
	var mutations := []
	for payoff_kind_value in Generator.FINAL_EXECUTION_PAYOFF_KINDS:
		var payoff_kind := str(payoff_kind_value)
		_check(by_kind.has(payoff_kind), "shipped final-execution matrix lacks %s" % payoff_kind)
		if not by_kind.has(payoff_kind):
			continue
		var kind_mutation: Dictionary = (by_kind[payoff_kind] as Dictionary).duplicate(true)
		var payoff: Dictionary = kind_mutation["payoff"]
		match payoff_kind:
			"typed_damage":
				payoff["post_activation_damage"] = float(payoff.get("post_activation_damage", 0.0)) + 1.0
			"target_death":
				payoff["target_deaths"] = int(payoff.get("target_deaths", 0)) + 1
			"target_status_transition":
				payoff["target_status_markers"] = []
			"owner_state_transition":
				payoff["owner_state_delta"] = {}
		mutations.append({"name": "%s payoff mutation on a shipped row" % payoff_kind, "row": kind_mutation})
	for binding_value in Generator.FINAL_EXECUTION_BINDING_KINDS:
		var binding := str(binding_value)
		_check(by_binding.has(binding), "shipped final-execution matrix lacks %s" % binding)
		if not by_binding.has(binding):
			continue
		var binding_mutation: Dictionary = (by_binding[binding] as Dictionary).duplicate(true)
		(binding_mutation["payoff"] as Dictionary)["binding"] = "frame_ordered" if binding == "resolver_provenance" else "resolver_provenance"
		mutations.append({"name": "%s binding mutation on a shipped row" % binding, "row": binding_mutation})
	_check(mutations.size() == SHIPPED_FINAL_EXECUTION_MUTATION_COUNT, "shipped final-execution mutation catalog is unexpectedly short")
	for mutation_value in mutations:
		var mutation: Dictionary = mutation_value
		_check(not Generator.verify_final_execution_row(mutation.get("row", {})).is_empty(), "final-execution verification accepts a forged shipped row: %s" % mutation.get("name", "?"))


# This deliberately does not call Generator's amplification policy. It is a
# small independent oracle for the reactor's production shape: tagged cycle
# pulses and ordinary vent hits share the same cast/frame, while their geometry
# permits a conservative 0.25 floor for the manifest's 0.40 pulse ratio.
func _validate_independent_reactor_amplification_oracle(dataset: Dictionary) -> void:
	var reactor := _find_final_execution_row(dataset, ROBOT_REACTOR_PAIR)
	_check(not reactor.is_empty(), "shipped final-execution matrix lacks the reactor amplification row")
	if reactor.is_empty():
		return
	_check(_reactor_amplification_oracle(reactor), "independent reactor amplification oracle rejects the shipped production trace")
	var halved := reactor.duplicate(true)
	_halve_reactor_bound_damage_coherently(halved)
	_check(not _reactor_amplification_oracle(halved), "independent reactor amplification oracle accepts coherently halved resolver-bound damage")
	var verification := Generator.verify_final_execution_row(halved)
	_check(not verification.is_empty() and "; ".join(verification).contains("measured resolver payoff"), "generator verifier must reject coherently halved reactor resolver damage through its mechanic-aware oracle")


func _find_final_execution_row(dataset: Dictionary, pair: String) -> Dictionary:
	for row_value in (dataset.get("final_execution", {}) as Dictionary).get("rows", []):
		var row: Dictionary = row_value
		if str(row.get("pair", "")) == pair:
			return row.duplicate(true)
	return {}


func _reactor_amplification_oracle(row: Dictionary) -> bool:
	var sample: Dictionary = row.get("telemetry", {})
	var events: Array = sample.get("events", [])
	var event_by_id := {}
	var bound_ids := {}
	for event_value in events:
		var event: Dictionary = event_value
		event_by_id[str(event.get("event_id", ""))] = event
	for event_value in events:
		var event: Dictionary = event_value
		if str(event.get("kind", "")) != "final_event" or str(event.get("mechanic_id", "")) != ROBOT_REACTOR_MECHANIC:
			continue
		var related_hit_id := str(event.get("related_hit_id", ""))
		if related_hit_id != "" and event_by_id.has(related_hit_id):
			bound_ids[related_hit_id] = true
	var bound_by_cast := {}
	var peer_by_cast := {}
	for event_value in events:
		var event: Dictionary = event_value
		if str(event.get("kind", "")) != "hit" or str(event.get("source", "")) != "player_weapon" or str(event.get("probe_phase", "")) != "measurement":
			continue
		var cast_id := str(event.get("cast_id", ""))
		if cast_id == "":
			continue
		var key := "%d|%s" % [int(event.get("frame", -1)), cast_id]
		var bucket: Dictionary = bound_by_cast if bound_ids.has(str(event.get("event_id", ""))) else peer_by_cast
		var aggregate: Dictionary = bucket.get(key, {"damage": 0.0, "hits": 0})
		aggregate["damage"] = float(aggregate["damage"]) + float(event.get("damage", 0.0))
		aggregate["hits"] = int(aggregate["hits"]) + 1
		bucket[key] = aggregate
	var bound_damage := 0.0
	var bound_hits := 0
	var peer_damage := 0.0
	var peer_hits := 0
	for key_value in bound_by_cast:
		var key := str(key_value)
		if not peer_by_cast.has(key):
			continue
		var bound: Dictionary = bound_by_cast[key]
		var peer: Dictionary = peer_by_cast[key]
		bound_damage += float(bound["damage"])
		bound_hits += int(bound["hits"])
		peer_damage += float(peer["damage"])
		peer_hits += int(peer["hits"])
	if bound_hits <= 0 or peer_hits <= 0:
		return false
	var measured_ratio := (bound_damage / float(bound_hits)) / maxf(peer_damage / float(peer_hits), 0.0001)
	return measured_ratio + 0.0001 >= ROBOT_REACTOR_MINIMUM_MEASURED_RATIO and ROBOT_REACTOR_MINIMUM_MEASURED_RATIO == ROBOT_REACTOR_PULSE_RATIO * 0.625


func _halve_reactor_bound_damage_coherently(row: Dictionary) -> void:
	var sample: Dictionary = row.get("telemetry", {})
	var events: Array = sample.get("events", [])
	var bound_ids := _reactor_bound_hit_ids(events)
	for index in range(events.size()):
		var event: Dictionary = events[index]
		if bound_ids.has(str(event.get("event_id", ""))):
			event["damage"] = float(event.get("damage", 0.0)) * 0.5
			events[index] = event
	sample["events"] = events
	var measurement_by_target := {}
	var total_damage := 0.0
	var final_damage := 0.0
	var damage_buckets := {}
	for event_value in events:
		var event: Dictionary = event_value
		if str(event.get("kind", "")) != "hit":
			continue
		var damage := float(event.get("damage", 0.0))
		total_damage += damage
		var bucket_key := "%s|%s" % [str(event.get("source", "")), str(event.get("phase", ""))]
		var bucket: Dictionary = damage_buckets.get(bucket_key, {"source": str(event.get("source", "")), "phase": str(event.get("phase", "")), "damage": 0.0, "hits": 0})
		bucket["damage"] = float(bucket["damage"]) + damage
		bucket["hits"] = int(bucket["hits"]) + 1
		damage_buckets[bucket_key] = bucket
		if bound_ids.has(str(event.get("event_id", ""))):
			final_damage += damage
		if str(event.get("source", "")) == "player_weapon" and str(event.get("probe_phase", "")) == "measurement":
			var target_id := str(event.get("target_id", ""))
			measurement_by_target[target_id] = float(measurement_by_target.get(target_id, 0.0)) + damage
	var ledger: Dictionary = sample.get("hp_ledger", {})
	var ledger_total := 0.0
	var rows: Array = ledger.get("rows", [])
	for index in range(rows.size()):
		var ledger_row: Dictionary = rows[index]
		var applied := float(measurement_by_target.get(str(ledger_row.get("target_id", "")), 0.0))
		ledger_row["applied_damage"] = applied
		if ledger_row.has("health_before"):
			ledger_row["health_after"] = float(ledger_row["health_before"]) - applied
			ledger_row["health_loss"] = applied
		ledger_total += applied
		rows[index] = ledger_row
	ledger["rows"] = rows
	ledger["total_applied_damage"] = ledger_total
	sample["hp_ledger"] = ledger
	var counters: Dictionary = sample.get("counters", {})
	counters["damage_total"] = snappedf(total_damage, 0.0001)
	counters["final_event_damage"] = snappedf(final_damage, 0.0001)
	var bucket_rows := damage_buckets.values()
	bucket_rows.sort_custom(func(a, b): return "%s|%s" % [a["source"], a["phase"]] < "%s|%s" % [b["source"], b["phase"]])
	counters["damage_by_source_phase"] = bucket_rows
	sample["counters"] = counters
	sample["trace_digest_sha256"] = Generator.canonical_trace_digest(events)
	row["telemetry"] = sample
	var payoff: Dictionary = row.get("payoff", {})
	var bound_damage := 0.0
	var bound_hits := 0
	var warmup_damage := 0.0
	var warmup_hits := 0
	var post_damage := 0.0
	var post_hits := 0
	var first_activation := int(((row.get("activations", []) as Array)[0] as Dictionary).get("frame", -1))
	for event_value in events:
		var event: Dictionary = event_value
		if str(event.get("kind", "")) != "hit" or str(event.get("source", "")) != "player_weapon":
			continue
		var damage := float(event.get("damage", 0.0))
		if bound_ids.has(str(event.get("event_id", ""))):
			bound_damage += damage
			bound_hits += 1
		elif first_activation >= 0 and int(event.get("frame", 0)) >= first_activation:
			post_damage += damage
			post_hits += 1
		elif first_activation >= 0 and str(event.get("probe_phase", "")) == "warmup":
			warmup_damage += damage
			warmup_hits += 1
	payoff["provenance_bound_damage"] = snappedf(bound_damage, 0.0001)
	payoff["provenance_bound_hits"] = bound_hits
	payoff["post_activation_damage"] = snappedf(post_damage, 0.0001)
	payoff["post_activation_hits"] = post_hits
	payoff["pre_activation_damage"] = snappedf(warmup_damage, 0.0001)
	payoff["pre_activation_hits"] = warmup_hits
	payoff["amplified_hit_mean"] = snappedf(bound_damage / maxf(float(bound_hits), 1.0), 0.0001)
	payoff["unamplified_hit_mean"] = snappedf(warmup_damage / maxf(float(warmup_hits), 1.0), 0.0001)
	payoff["observed_damage_ratio"] = snappedf(float(payoff["amplified_hit_mean"]) / maxf(float(payoff["unamplified_hit_mean"]), 0.0001), 0.0001) if bound_hits > 0 and warmup_hits > 0 else 0.0
	payoff["applied_hp_total"] = snappedf(ledger_total, 0.0001)
	row["payoff"] = payoff
	var duration := float(ledger.get("measurement_duration_seconds", 0.0))
	sample["dpm"] = snappedf(ledger_total * 60.0 / duration, 0.01) if duration > 0.0 else 0.0
	row["telemetry"] = sample


func _reactor_bound_hit_ids(events: Array) -> Dictionary:
	var event_ids := {}
	var bound_ids := {}
	for event_value in events:
		event_ids[str((event_value as Dictionary).get("event_id", ""))] = true
	for event_value in events:
		var event: Dictionary = event_value
		if str(event.get("kind", "")) == "final_event" and str(event.get("mechanic_id", "")) == ROBOT_REACTOR_MECHANIC:
			var related_hit_id := str(event.get("related_hit_id", ""))
			if related_hit_id != "" and event_ids.has(related_hit_id):
				bound_ids[related_hit_id] = true
	return bound_ids


func _final_execution_fixture() -> Dictionary:
	var pair := "berserk/sword"
	var mechanic_id := "sword_repeat_execute"
	var seed_value := int(Generator.FINAL_EXECUTION_SEEDS[0])
	var sample_key := "%s|%d|final_execution|autofire|%d" % [pair, seed_value, Generator.FINAL_EXECUTION_TARGET_COUNT]
	var trace_id := "fan1511:%s" % sample_key
	var events := [
		_trace_event(trace_id, 0, {"kind": "cast", "source": "player_weapon", "phase": "windup", "cast_id": "cast_000001", "attack_mode": "sweep", "damage": 0.0}, 1, "measurement"),
		_trace_event(trace_id, 1, {"kind": "hit", "source": "player_weapon", "phase": "damage_application", "target_id": "target_0", "provenance_id": "hit_000001", "cast_id": "cast_000001", "damage": 10.0}, 2, "warmup"),
		_trace_event(trace_id, 2, {"kind": "hit", "source": "player_weapon", "phase": "damage_application", "target_id": "target_0", "provenance_id": "hit_000002", "cast_id": "cast_000001", "damage": 10.0}, 3, "warmup"),
		_trace_event(trace_id, 3, {"kind": "final_event", "source": "player_weapon", "phase": "final_resolution", "target_id": "target_0", "event": "hit", "mechanic_id": mechanic_id, "final_activation_id": "final_000001", "observed": true, "related_hit_id": "%s#0004" % trace_id, "damage": 0.0}, 4, "measurement"),
		_trace_event(trace_id, 4, {"kind": "hit", "source": "player_weapon", "phase": "damage_application", "target_id": "target_0", "provenance_id": "hit_000003", "cast_id": "cast_000001", "damage": 14.0, "final_event_ids": ["%s#0003" % trace_id]}, 4, "measurement"),
	]
	var ladder := []
	for index in range(3):
		ladder.append({
			"index": index,
			"event": "hit",
			"mode": "repeat_execute",
			"phase": "measurement",
			"frame": index + 2,
			"target_id": "target_0",
			"progress": index + 1,
			"required": 3,
			"triggered": index == 2,
			"activation_id": "final_000001" if index == 2 else "",
			"consumer_event": false,
		})
	var sample := {
		"telemetry_schema": "fan1511.runtime-telemetry.v2",
		"sample_key": sample_key,
		"trace_id": trace_id,
		"pair": pair,
		"seed": seed_value,
		"scenario": "final_execution",
		"fixture": "autofire",
		"target_cardinality": Generator.FINAL_EXECUTION_TARGET_COUNT,
		"events": events,
		"hp_ledger": {
			"authority": "enemy_damage_applied_health_delta",
			"probe_phase": "measurement",
			"tolerance": 0.0001,
			"rows": [{"target_id": "target_0", "applied_damage": 14.0, "entries": 1}],
			"total_applied_damage": 14.0,
		},
		"counters": {"casts": 1, "hits": 3, "final_event_count": 1, "damage_total": 34.0},
		"trace_digest_sha256": Generator.canonical_trace_digest(events),
	}
	return {
		"pair": pair,
		"class_id": "berserk",
		"weapon_id": "sword",
		"final_mechanic": mechanic_id,
		"final_mode": "repeat_execute",
		"final_event": "hit",
		"required_progress": 3,
		"consumer": {
			"executor_script": "res://scripts/player.gd",
			"executor_method": "constellation_weapon_event",
			"resolver_script": "res://scripts/constellation_final_runtime.gd",
			"resolver_method": "resolve_event",
			"runtime_consumer": "scripts/berserk_weapon.gd",
			"observation_signals": ["constellation_final_resolved", "damage_applied", "died", "damaged"],
			"payoff_owner": "consumer_weapon",
		},
		"stimulus": {
			"kind": "autofire",
			"fixture": "sustain",
			"layout": "pack",
			"target_count": Generator.FINAL_EXECUTION_TARGET_COUNT,
			"initial_target_hp": Generator.DUMMY_HP,
			"stats_build": "level20_optimized",
			"seed": seed_value,
			"warmup_seconds": Generator.FINAL_EXECUTION_WARMUP_SECONDS,
			"window_seconds": Generator.FINAL_EXECUTION_WINDOW_SECONDS,
		},
		"resolution_ladder": ladder,
		"dispatch_count": 3,
		"event_dispatch_count": 3,
		"resolved_dispatch_count": 3,
		"consumer_gated_dispatch_count": 0,
		"weapon_runtime": {"weapon_script": "res://scripts/berserk_weapon.gd"},
		"activations": [ladder[2]],
		"owner_state_before": {},
		"owner_state_after": {},
		"payoff": {
			"kind": "typed_damage",
			"binding": "resolver_provenance",
			"activation_count": 1,
			"first_activation_frame": 4,
			"provenance_bound_hits": 1,
			"provenance_bound_damage": 14.0,
			"post_activation_hits": 0,
			"post_activation_damage": 0.0,
			"pre_activation_hits": 2,
			"pre_activation_damage": 20.0,
			"target_deaths": 0,
			"target_status_markers": [],
			"owner_state_delta": {},
			"owner_final_marker": false,
			"applied_hp_total": 14.0,
			"amplified_hit_mean": 14.0,
			"unamplified_hit_mean": 10.0,
			"observed_damage_ratio": 1.4,
			"resolver_damage_ratio": 0.0,
		},
		"observed": true,
		"telemetry": sample,
	}


func _trace_event(trace_id: String, index: int, payload: Dictionary, frame: int, probe_phase: String) -> Dictionary:
	var event := payload.duplicate(true)
	event["event_id"] = "%s#%04d" % [trace_id, index]
	event["trace_id"] = trace_id
	event["frame"] = frame
	event["probe_phase"] = probe_phase
	return event


func _final_execution_mutations(baseline: Dictionary) -> Array:
	var mutations := []
	# A whole trace lifted from another pair and relabelled onto this row, with the
	# trace digest recomputed exactly as the previous evidence model allowed.
	var copied := baseline.duplicate(true)
	var copied_sample: Dictionary = copied["telemetry"]
	var foreign_key := "berserk/axe|%d|final_execution|autofire|%d" % [int(Generator.FINAL_EXECUTION_SEEDS[0]), Generator.FINAL_EXECUTION_TARGET_COUNT]
	copied_sample["sample_key"] = foreign_key
	copied_sample["trace_id"] = "fan1511:%s" % foreign_key
	copied_sample["pair"] = "berserk/axe"
	copied_sample["events"] = _relabel_events(copied_sample.get("events", []), "fan1511:%s" % foreign_key, "axe_outer_followthrough")
	copied_sample["trace_digest_sha256"] = Generator.canonical_trace_digest(copied_sample["events"])
	mutations.append({"name": "trace copied from another pair with recomputed digest", "row": copied})

	var relabelled := baseline.duplicate(true)
	(relabelled["resolution_ladder"] as Array)[2]["event"] = "kill"
	relabelled["activations"] = [(relabelled["resolution_ladder"] as Array)[2]]
	mutations.append({"name": "ladder step relabelled to a foreign event", "row": relabelled})

	var threshold := baseline.duplicate(true)
	threshold["required_progress"] = 5
	mutations.append({"name": "foreign trigger threshold", "row": threshold})

	var early := baseline.duplicate(true)
	(early["resolution_ladder"] as Array)[0]["triggered"] = true
	mutations.append({"name": "ladder activates before its production threshold", "row": early})

	var missing := baseline.duplicate(true)
	var missing_sample: Dictionary = missing["telemetry"]
	var missing_events: Array = missing_sample["events"]
	missing_events.remove_at(2)
	missing_sample["events"] = missing_events
	missing_sample["trace_digest_sha256"] = Generator.canonical_trace_digest(missing_events)
	mutations.append({"name": "missing trace event with recomputed digest", "row": missing})

	var substituted := baseline.duplicate(true)
	var substituted_sample: Dictionary = substituted["telemetry"]
	(substituted_sample["events"] as Array)[4]["damage"] = 99.0
	substituted_sample["trace_digest_sha256"] = Generator.canonical_trace_digest(substituted_sample["events"])
	mutations.append({"name": "substituted hit damage with recomputed digest", "row": substituted})

	var stale_digest := baseline.duplicate(true)
	var stale_sample: Dictionary = stale_digest["telemetry"]
	(stale_sample["events"] as Array)[1]["damage"] = 11.0
	mutations.append({"name": "tampered event with a stale digest", "row": stale_digest})

	# The exact FAN-2119 defect: a harness-authored 1.0 witness hit appended to the
	# trace instead of a production payoff.
	var synthetic := baseline.duplicate(true)
	var synthetic_sample: Dictionary = synthetic["telemetry"]
	var synthetic_events: Array = synthetic_sample["events"]
	synthetic_events.append(_trace_event(str(synthetic_sample["trace_id"]), synthetic_events.size(), {"kind": "hit", "source": "player_weapon", "phase": "damage_application", "target_id": "target_0", "provenance_id": "", "damage": 1.0}, 5, "measurement"))
	synthetic_sample["events"] = synthetic_events
	synthetic_sample["counters"]["hits"] = 4
	synthetic_sample["counters"]["damage_total"] = 35.0
	synthetic_sample["trace_digest_sha256"] = Generator.canonical_trace_digest(synthetic_events)
	mutations.append({"name": "harness-authored 1.0 witness hit without production provenance", "row": synthetic})

	var executor := baseline.duplicate(true)
	(executor["consumer"] as Dictionary)["runtime_consumer"] = "scripts/class_weapon.gd"
	mutations.append({"name": "foreign runtime consumer", "row": executor})

	var target := baseline.duplicate(true)
	var target_sample: Dictionary = target["telemetry"]
	(target_sample["hp_ledger"] as Dictionary)["rows"] = [{"target_id": "target_3", "applied_damage": 34.0, "entries": 3}]
	mutations.append({"name": "ledger attributed to a foreign target", "row": target})

	var aggregate := baseline.duplicate(true)
	(aggregate["payoff"] as Dictionary)["provenance_bound_damage"] = 140.0
	mutations.append({"name": "tampered payoff aggregate", "row": aggregate})

	var ratio := baseline.duplicate(true)
	(ratio["payoff"] as Dictionary)["resolver_damage_ratio"] = 1.5
	mutations.append({"name": "payoff relation that is not the production mechanic's", "row": ratio})

	var unobserved := baseline.duplicate(true)
	unobserved["observed"] = false
	mutations.append({"name": "observation flag out of step with the derived payoff", "row": unobserved})

	var stimulus := baseline.duplicate(true)
	(stimulus["stimulus"] as Dictionary)["kind"] = "mortal_targets"
	mutations.append({"name": "stimulus that is not the production-derived profile", "row": stimulus})

	return mutations


func _relabel_events(events: Array, trace_id: String, mechanic_id: String) -> Array:
	var relabelled := []
	for index in range(events.size()):
		var event: Dictionary = (events[index] as Dictionary).duplicate(true)
		event["event_id"] = "%s#%04d" % [trace_id, index]
		event["trace_id"] = trace_id
		if event.has("mechanic_id"):
			event["mechanic_id"] = mechanic_id
		if event.has("related_hit_id"):
			event["related_hit_id"] = "%s#0004" % trace_id
		if event.has("final_event_ids"):
			event["final_event_ids"] = ["%s#0003" % trace_id]
		relabelled.append(event)
	return relabelled


func _disposition_dataset(row: Dictionary) -> Dictionary:
	var pair := str(row.get("pair", ""))
	var duration := 6.0
	var sample := {
		"pair": pair,
		"scenario": "sustain_solo",
		"counters": {"casts": 30.0, "hits": 30.0, "unique_target_count": 1.0},
		"hp_ledger": {"total_applied_damage": 300.0, "measurement_duration_seconds": duration},
	}
	var pack_sample := {
		"pair": pair,
		"scenario": "sustain_pack",
		"counters": {"casts": 30.0, "hits": 300.0, "unique_target_count": 10.0},
		"hp_ledger": {"total_applied_damage": 3000.0, "measurement_duration_seconds": duration},
	}
	var live_telemetry := {"samples": [sample, pack_sample]}
	# FAN-2388: the fixture's basis is the pinned literal, not a fresh call into
	# Generator.production_formula_basis — _verify_disposition_row makes that same
	# call independently to check the row, so deriving both sides from the same
	# function would make admissibility a tautology instead of a real check.
	_check(pair == "berserk/sword", "the disposition fixture's pinned formula basis only covers berserk/sword")
	var basis := PINNED_BERSERK_SWORD_FORMULA_BASIS.duplicate(true)
	var solo_observed := Generator.observed_axis_terms(live_telemetry, pair, "sustain_solo")
	var pack_observed := Generator.observed_axis_terms(live_telemetry, pair, "sustain_pack")
	var formula_solo := 6000.0
	var formula_pack := 12000.0
	var axes := {
		"solo": Generator.decompose_axis(basis, solo_observed, formula_solo),
		"pack": Generator.decompose_axis(basis, pack_observed, formula_pack),
	}
	var parity_row := {
		"pair": pair,
		"formula_solo_dpm": formula_solo,
		"formula_pack_dpm": formula_pack,
		"solo_delta_pct": float((axes["solo"] as Dictionary).get("recomputed_delta_pct", 0.0)),
		"pack_delta_pct": float((axes["pack"] as Dictionary).get("recomputed_delta_pct", 0.0)),
	}
	var payoff: Dictionary = row.get("payoff", {})
	var disposition_row := {
		"pair": pair,
		"solo_delta_pct": parity_row["solo_delta_pct"],
		"pack_delta_pct": parity_row["pack_delta_pct"],
		"disposition": "explained_divergence",
		"final_execution": {
			"final_mechanic": str(row.get("final_mechanic", "")),
			"final_mode": str(row.get("final_mode", "")),
			"final_event": str(row.get("final_event", "")),
			"runtime_consumer": str((row.get("consumer", {}) as Dictionary).get("runtime_consumer", "")),
			"payoff_kind": str(payoff.get("kind", "")),
			"payoff_binding": str(payoff.get("binding", "")),
			"activation_count": int(payoff.get("activation_count", 0)),
			"applied_hp_total": float(payoff.get("applied_hp_total", 0.0)),
			"resolver_bound_payoff_share_pct": snappedf(100.0 * float(payoff.get("provenance_bound_damage", 0.0)) / maxf(float(payoff.get("applied_hp_total", 0.0)), 0.0001), 0.01),
			"telemetry_sample_key": str((row.get("telemetry", {}) as Dictionary).get("sample_key", "")),
		},
		"formula_basis": basis,
		"axes": axes,
		"explanation": "fixture accounting",
	}
	return {
		"roster": {"pair_keys": [pair]},
		"formula_live_parity": [parity_row],
		"live_telemetry": live_telemetry,
		"final_execution": {"rows": [row]},
		"formula_live_dispositions": {
			"schema": "fan2224.formula-live-disposition.v2",
			"tolerance_pct": Generator.FORMULA_LIVE_TOLERANCE_PCT,
			"rows": [disposition_row],
		},
		"weapon_rows": [{
			"key": "berserk|sword|20|class_constellation",
			"formula_live_disposition": "explained_divergence",
			"final_execution_payoff_kind": str(payoff.get("kind", "")),
		}],
	}


func _disposition_mutations(dataset: Dictionary) -> Array:
	var mutations := []
	var tolerance := dataset.duplicate(true)
	(tolerance["formula_live_dispositions"] as Dictionary)["tolerance_pct"] = 500.0
	mutations.append({"name": "tampered acceptance tolerance", "dataset": tolerance})

	var disposition := dataset.duplicate(true)
	((disposition["formula_live_dispositions"] as Dictionary)["rows"] as Array)[0]["disposition"] = "within_tolerance"
	mutations.append({"name": "disposition relabelled against its own deltas", "dataset": disposition})

	var unresolved := dataset.duplicate(true)
	((unresolved["formula_live_dispositions"] as Dictionary)["rows"] as Array)[0]["disposition"] = "unresolved"
	mutations.append({"name": "unresolved row in a certifying dataset", "dataset": unresolved})

	var factors := dataset.duplicate(true)
	var factor_axes: Dictionary = ((factors["formula_live_dispositions"] as Dictionary)["rows"] as Array)[0]["axes"]
	((factor_axes["solo"] as Dictionary)["factors"] as Dictionary)["cadence"] = 42.0
	mutations.append({"name": "tampered consumer factor", "dataset": factors})

	var observation := dataset.duplicate(true)
	var observation_axes: Dictionary = ((observation["formula_live_dispositions"] as Dictionary)["rows"] as Array)[0]["axes"]
	((observation_axes["pack"] as Dictionary)["observed"] as Dictionary)["damage_per_hit"] = 1.0
	mutations.append({"name": "observation that does not reconstruct from the anchored telemetry", "dataset": observation})

	var evidence := dataset.duplicate(true)
	((evidence["formula_live_dispositions"] as Dictionary)["rows"] as Array)[0]["final_execution"]["payoff_kind"] = "target_death"
	mutations.append({"name": "evidence relabelled away from the final-execution row", "dataset": evidence})

	var matrix := dataset.duplicate(true)
	(matrix["weapon_rows"] as Array)[0]["formula_live_disposition"] = "within_tolerance"
	mutations.append({"name": "weapon matrix drifted from the disposition rows", "dataset": matrix})

	var forged_basis := dataset.duplicate(true)
	var forged_row: Dictionary = ((forged_basis["formula_live_dispositions"] as Dictionary)["rows"] as Array)[0]
	var forged: Dictionary = (forged_row["formula_basis"] as Dictionary).duplicate(true)
	forged["fire_interval_seconds"] = float(forged["fire_interval_seconds"]) * 2.0
	forged["cast_rate_per_second"] = snappedf(1.0 / float(forged["fire_interval_seconds"]), 0.000001)
	forged["hit_damage"] = float(forged["hit_damage"]) * 2.0
	forged["direct_dpm"] = snappedf(60.0 * float(forged["hit_damage"]) * float(forged["cast_rate_per_second"]), 0.000001)
	forged_row["formula_basis"] = forged
	var forged_live: Dictionary = forged_basis["live_telemetry"]
	var forged_parity: Dictionary = (forged_basis["formula_live_parity"] as Array)[0]
	var forged_axes: Dictionary = forged_row["axes"]
	forged_axes["solo"] = Generator.decompose_axis(forged, Generator.observed_axis_terms(forged_live, "berserk/sword", "sustain_solo"), float(forged_parity["formula_solo_dpm"]))
	forged_axes["pack"] = Generator.decompose_axis(forged, Generator.observed_axis_terms(forged_live, "berserk/sword", "sustain_pack"), float(forged_parity["formula_pack_dpm"]))
	mutations.append({"name": "self-consistent but non-production formula basis", "dataset": forged_basis})

	return mutations


func _validate_source_provenance(dataset: Dictionary) -> void:
	var source: Dictionary = dataset.get("source", {})
	_check(_independent_source_matches_git(source), "source provenance is not the exact Git commit/tree/timestamp tuple")
	var mismatched := source.duplicate(true)
	mismatched["commit_timestamp"] = "1970-01-01T00:00:00Z"
	if str(source.get("commit_timestamp", "")) == str(mismatched["commit_timestamp"]):
		mismatched["commit_timestamp"] = "1970-01-01T00:00:01Z"
	_check(not _independent_source_matches_git(mismatched), "source provenance accepts a deliberately mismatched commit_timestamp")


# FAN-2511: --presentation-only republishes the anchored artifact's supplemental
# tuple, and the artifact is untrusted input. A forged tree used to reach a
# rewritten report because the generator compared only the commit string. Drive the
# production gate the generator now runs before it opens any tracked output, and
# re-hash the tracked artifacts after every refusal: a rejection that rewrote
# anything is the same defect wearing a non-zero exit code.
func _validate_supplemental_provenance_gate(dataset: Dictionary) -> void:
	var supplemental: Dictionary = dataset.get("supplemental_execution", {})
	var anchored_commit := str(supplemental.get("commit", ""))
	var legacy_commit := str((dataset.get("source", {}) as Dictionary).get("commit", ""))
	var baseline := _tracked_artifact_digests()
	_check(bool(Generator.verify_artifact_provenance(dataset).get("ok", false)), "the shipped artifact provenance must still pass the production pre-write gate")
	_check(bool(Generator.verify_presentation_pin(dataset, anchored_commit).get("ok", false)), "the anchored supplemental commit must still satisfy the presentation-only pin")
	_check(legacy_commit != anchored_commit, "the mismatched-pin fixture needs a legacy commit distinct from the supplemental commit")
	# Each forgery keeps every numeric, telemetry and legacy-source field of the
	# shipped dataset — exactly the shape the rejected candidate published with a
	# recomputed digest and a zeroed supplemental tree.
	var forgeries := [
		{"name": "forged supplemental tree", "field": "tree", "value": "0".repeat(40)},
		{"name": "forged supplemental commit_timestamp", "field": "commit_timestamp", "value": "1970-01-01T00:00:00Z"},
		{"name": "unresolvable supplemental commit", "field": "commit", "value": "0".repeat(40)},
		{"name": "missing supplemental commit", "field": "commit", "value": ""},
	]
	for forgery_value in forgeries:
		var forgery: Dictionary = forgery_value
		var name := str(forgery["name"])
		var mutation := dataset.duplicate(true)
		var mutated_supplemental: Dictionary = mutation["supplemental_execution"]
		mutated_supplemental[str(forgery["field"])] = forgery["value"]
		_check(mutated_supplemental != supplemental, "%s fixture did not mutate the shipped tuple" % name)
		var verdict := Generator.verify_artifact_provenance(mutation)
		_check(not bool(verdict.get("ok", false)), "%s must fail the production pre-write gate" % name)
		_check("; ".join(verdict.get("errors", [])).contains("supplemental provenance"), "%s must be rejected as supplemental provenance, not by an unrelated check" % name)
		_check(_tracked_artifact_digests() == baseline, "%s rejection must leave the tracked A5 artifacts byte-identical" % name)
	_check(not bool(Generator.verify_presentation_pin(dataset, legacy_commit).get("ok", false)), "a --source-commit that mismatches the anchored supplemental pin must fail before any write")
	_check(_tracked_artifact_digests() == baseline, "mismatched-pin rejection must leave the tracked A5 artifacts byte-identical")


func _tracked_artifact_digests() -> PackedStringArray:
	var digests := PackedStringArray()
	for path in [Generator.RAW_PATH, Generator.REPORT_PATH, Generator.CSV_PATH]:
		digests.append(FileAccess.get_sha256(path))
	return digests


func _validate_raw_artifact(dataset: Dictionary, raw_text: String) -> void:
	_check(not FileAccess.file_exists(Generator.LEGACY_RAW_PATH), "legacy uncompressed raw.json must not remain tracked")
	_check(raw_text == JSON.stringify(dataset, "\t", true, true) + "\n", "decoded raw.json.gz is not canonical JSON serialization")
	var source := FileAccess.open(Generator.RAW_PATH, FileAccess.READ)
	_check(source != null, "raw.json.gz must be readable for corruption test")
	if source == null:
		return
	var bytes := source.get_buffer(source.get_length())
	source.close()
	_check(bytes.size() > 10, "raw.json.gz is unexpectedly short")
	if bytes.size() <= 10:
		return
	bytes[bytes.size() - 1] = int(bytes[bytes.size() - 1]) ^ 1
	var corrupt_path := "user://fan1438_a5_corrupt_raw.json.gz"
	var corrupt := FileAccess.open(corrupt_path, FileAccess.WRITE)
	_check(corrupt != null, "cannot create corrupt gzip validation fixture")
	if corrupt == null:
		return
	corrupt.store_buffer(bytes)
	corrupt.close()
	var corrupt_result := Generator.read_raw_artifact(corrupt_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(corrupt_path))
	_check(not bool(corrupt_result.get("ok", true)), "corrupted raw.json.gz must fail closed")


func _validate_roster(dataset: Dictionary) -> void:
	var expected_classes: Array = PD.character_ids()
	var expected_pairs := []
	for class_id_value in expected_classes:
		var class_id := str(class_id_value)
		for weapon_id_value in PD.weapon_ids(class_id):
			expected_pairs.append("%s/%s" % [class_id, str(weapon_id_value)])
	var roster: Dictionary = dataset.get("roster", {})
	_check(roster.get("class_ids", []) == expected_classes, "raw class roster differs from ProgressionData.character_ids()")
	_check(roster.get("pair_keys", []) == expected_pairs, "raw pair roster differs from WEAPONS_BY_CLASS")
	_check(int(roster.get("weapon_pair_count", -1)) == expected_pairs.size(), "raw pair count mismatch")


func _validate_builds(dataset: Dictionary) -> void:
	var builds: Dictionary = dataset.get("builds", {})
	for class_id_value in PD.character_ids():
		var class_id := str(class_id_value)
		var build: Dictionary = builds.get(class_id, {})
		_check(int(build.get("level20_points", -1)) == Generator.LEVEL20_POINTS, "%s level20 allocation is not 19 points" % class_id)
		var base: Dictionary = build.get("level1_stats", {})
		var level20: Dictionary = build.get("level20_stats", {})
		var sum := 0
		for stat_id in base:
			var delta := float(level20.get(stat_id, 0.0)) - float(base.get(stat_id, 0.0))
			_check(delta >= 0.0 and is_equal_approx(delta, round(delta)), "%s/%s delta is not a nonnegative integer" % [class_id, stat_id])
			sum += int(round(delta))
		_check(sum == Generator.LEVEL20_POINTS, "%s recomputed point sum is %d" % [class_id, sum])


func _validate_meta(dataset: Dictionary) -> void:
	for class_id_value in PD.character_ids():
		var class_id := str(class_id_value)
		var nodes := Meta.constellation_nodes(class_id)
		var spend := 0
		var hidden := 0
		for raw_node in nodes:
			var node: Dictionary = raw_node
			spend += int(node.get("cost", 0))
			if str(node.get("role", "")) == "hidden":
				hidden += 1
		_check(nodes.size() == 21, "%s constellation must have 21 nodes" % class_id)
		_check(spend == 20, "%s constellation spend must be 20" % class_id)
		_check(hidden == 2, "%s constellation must have two hidden purchases" % class_id)
	var scenarios: Dictionary = dataset.get("scenarios", {})
	var meta_builds: Dictionary = dataset.get("meta_builds", {})
	var legal: Dictionary = scenarios.get("class_atlas50", {})
	var upper: Dictionary = scenarios.get("class_atlas59_upper", {})
	_check(int(legal.get("atlas_spend", -1)) == Meta.STARDUST_CAP, "legal Atlas spend is not 50")
	_check(legal.get("excluded_ids", []) == Generator.ATLAS50_EXCLUSIONS, "legal Atlas exclusion set changed")
	_check(bool(legal.get("playable", false)), "legal Atlas is not marked playable")
	_check(int(upper.get("atlas_spend", -1)) == Meta.atlas_total_cost(), "upper Atlas spend is not the canonical total")
	_check(not bool(upper.get("playable", true)), "59-dust upper bound is marked playable")
	_check(str(upper.get("label", "")) == Generator.NON_PLAYABLE_LABEL, "59-dust upper-bound label mismatch")
	_check(_connected(legal.get("atlas_ids", [])), "legal Atlas node set is disconnected")
	_check(_connected(upper.get("atlas_ids", [])), "full Atlas node set is disconnected")
	for class_id_value in PD.character_ids():
		var class_id := str(class_id_value)
		var build: Dictionary = meta_builds.get(class_id, {})
		_check((build.get("purchased_ids", []) as Array).size() == 20, "%s raw meta build does not list all 20 purchases" % class_id)
		_check(int(build.get("spend", -1)) == 20, "%s raw meta spend is not 20" % class_id)
		_check((build.get("hidden_reveal_facts", []) as Array).size() == 2, "%s raw hidden reveal facts incomplete" % class_id)
		_check((build.get("weapon_profile_node_ids", {}) as Dictionary).size() == PD.weapon_ids(class_id).size(), "%s raw weapon profile map incomplete" % class_id)


func _connected(ids_value) -> bool:
	var ids: Array = ids_value if ids_value is Array else []
	var selected := {}
	for node_id in ids:
		selected[str(node_id)] = true
	var reached := {"atlas_hub": true}
	var frontier := ["atlas_hub"]
	while not frontier.is_empty():
		var current := str(frontier.pop_back())
		for neighbor_value in Meta.node_by_id(current).get("adj", []):
			var neighbor := str(neighbor_value)
			if selected.has(neighbor) and not reached.has(neighbor):
				reached[neighbor] = true
				frontier.append(neighbor)
	for node_id in ids:
		if not reached.has(str(node_id)):
			return false
	return true


func _validate_weapon_rows(dataset: Dictionary) -> void:
	var rows: Array = dataset.get("weapon_rows", [])
	var pair_count := int((dataset.get("roster", {}) as Dictionary).get("weapon_pair_count", 0))
	var expected_count := pair_count * Generator.LEVELS.size() * Generator.SCENARIO_IDS.size()
	_check(rows.size() == expected_count, "weapon row count %d != %d" % [rows.size(), expected_count])
	var keys := {}
	var baselines := {}
	for row_value in rows:
		var row: Dictionary = row_value
		var key := str(row.get("key", ""))
		_check(not keys.has(key), "duplicate weapon key %s" % key)
		keys[key] = true
		_check(not bool(row.get("ultimate_included", true)), "%s includes ultimate in weapon output" % key)
		_check(str(row.get("playstyle", "")).length() > 4, "%s lacks playstyle" % key)
		_check(str(row.get("strengths", "")).length() > 4, "%s lacks strengths" % key)
		_check(str(row.get("weaknesses", "")).length() > 4, "%s lacks weaknesses" % key)
		_check(int(row.get("runs", 0)) >= 1, "%s lacks run count" % key)
		_check(float(row.get("solo_variance_dpm2", -1.0)) >= 0.0 and float(row.get("crowd_variance_dpm2", -1.0)) >= 0.0, "%s lacks nonnegative variance" % key)
		for metric in ["solo_dpm", "crowd_10_total_dpm", "crowd_10_per_target_dpm", "hp", "ehp", "ttd_seconds", "pickup_radius", "move_speed"]:
			var value := float(row.get(metric, -1.0))
			_check(is_finite(value) and value >= 0.0, "%s %s is invalid" % [key, metric])
		_check(is_equal_approx(float(row.get("crowd_10_per_target_dpm", -1.0)), float(row.get("crowd_10_total_dpm", 0.0)) / Generator.TARGET_COUNT), "%s per-target DPM identity failed" % key)
		if str(row.get("scenario", "")) == "no_meta":
			baselines["%s|%s|%d" % [row["class_id"], row["weapon_id"], row["level"]]] = row
	var expected_keys := {}
	for pair_value in dataset["roster"]["pair_keys"]:
		var pair := str(pair_value).split("/", true, 1)
		for level in Generator.LEVELS:
			for scenario_id in Generator.SCENARIO_IDS:
				expected_keys["%s|%s|%d|%s" % [pair[0], pair[1], level, scenario_id]] = true
	_check(keys == expected_keys, "weapon key cross-product mismatch")
	for row_value in rows:
		var row: Dictionary = row_value
		var baseline: Dictionary = baselines["%s|%s|%d" % [row["class_id"], row["weapon_id"], row["level"]]]
		for metric in ["solo_dpm", "crowd_10_total_dpm", "ehp", "ttd_seconds", "pickup_radius", "move_speed"]:
			var expected_abs := snappedf(float(row[metric]) - float(baseline[metric]), 0.01)
			_check(is_equal_approx(float(row.get("%s_delta_abs" % metric, INF)), expected_abs), "%s %s absolute delta mismatch" % [row["key"], metric])


func _validate_class_rows(dataset: Dictionary) -> void:
	var rows: Array = dataset.get("class_rows", [])
	var expected := PD.character_ids().size() * Generator.LEVELS.size() * Generator.SCENARIO_IDS.size()
	_check(rows.size() == expected, "class-kit row count %d != %d" % [rows.size(), expected])
	var keys := {}
	for row_value in rows:
		var row: Dictionary = row_value
		keys[str(row.get("key", ""))] = true
		_check((row.get("roles", []) as Array).size() == 3, "%s must list exactly three weapon roles" % row.get("key", "?"))
		_check(str(row.get("strengths", "")).length() > 3, "%s lacks strengths" % row.get("key", "?"))
		_check(str(row.get("weaknesses", "")).length() > 3, "%s lacks weaknesses" % row.get("key", "?"))
		for score_key in ["solo_score", "aoe_score", "defense_score", "convenience_relative"]:
			_check(float(row.get(score_key, 0.0)) > 0.0, "%s lacks %s" % [row.get("key", "?"), score_key])
	_check(keys.size() == expected, "class-kit keys are not unique")


func _validate_class_corridor(dataset: Dictionary, report_text: String) -> void:
	var verifier := Generator.verify_class_corridor_artifacts(dataset)
	_check(bool(verifier.get("ok", false)), "class corridor artifacts must match canonical three-axis status: %s" % "; ".join(verifier.get("errors", [])))
	var expected_count := 0
	var defense_only_rows := []
	for row_value in dataset.get("class_rows", []):
		var row: Dictionary = row_value
		var expected_axes := _strict_corridor_axes(row)
		var actual_status := Generator.class_corridor_status(float(row["solo_score"]), float(row["aoe_score"]), float(row["defense_score"]))
		_check(_axis_names(actual_status.get("axes", [])) == expected_axes, "%s corridor axes differ from strict three-axis oracle" % row.get("key", "?"))
		_check((str(row.get("outlier_flag", "")) != "ok") == not expected_axes.is_empty(), "%s outlier flag does not agree with strict three-axis oracle" % row.get("key", "?"))
		if not expected_axes.is_empty():
			expected_count += 1
		if expected_axes == ["defense"]:
			defense_only_rows.append(row)
			_check(str(row.get("outlier_flag", "")) != "ok", "%s defense-only outlier is marked ok" % row.get("key", "?"))
	_check(expected_count == 120, "three-axis class corridor union is %d, expected 120" % expected_count)
	_check(defense_only_rows.size() == 15, "defense-only class corridor count is %d, expected 15" % defense_only_rows.size())
	var summary: Array = (dataset.get("outliers", {}) as Dictionary).get("class_corridor_80_120", [])
	_check(summary.size() == 120, "raw class corridor summary count is %d, expected 120" % summary.size())
	for row_value in defense_only_rows:
		var row: Dictionary = row_value
		var matching_entries := []
		for entry_value in summary:
			var entry: Dictionary = entry_value
			if str(entry.get("key", "")) == str(row["key"]):
				matching_entries.append(entry)
		_check(matching_entries.size() == 1, "%s defense-only row must have exactly one raw summary entry" % row["key"])
		if matching_entries.size() == 1:
			var entry: Dictionary = matching_entries[0]
			_check(entry.get("axes", []) == ["defense"], "%s summary must explicitly list defense as its only outlier axis" % row["key"])
			_check(is_equal_approx(float(entry.get("defense_vs_median", 0.0)), float(row["defense_score"])), "%s summary defense ratio differs from class row" % row["key"])
	var lower_boundary := Generator.class_corridor_status(0.80, 1.0, 1.0)
	var upper_boundary := Generator.class_corridor_status(1.0, 1.0, 1.20)
	_check(not bool(lower_boundary.get("is_outlier", true)) and str(lower_boundary.get("flag", "")) == "ok", "0.80 must remain inside the class corridor")
	_check(not bool(upper_boundary.get("is_outlier", true)) and str(upper_boundary.get("flag", "")) == "ok", "1.20 must remain inside the class corridor")
	var multi_axis := Generator.class_corridor_status(0.799, 1.201, 0.799)
	_check(_axis_names(multi_axis.get("axes", [])) == ["solo", "AoE", "defense"], "multi-axis corridor status must keep solo/AoE/defense order")
	_check(str(multi_axis.get("flag", "")).contains("solo=0.80×") and str(multi_axis.get("flag", "")).contains("AoE=1.20×") and str(multi_axis.get("flag", "")).contains("defense=0.80×"), "multi-axis flag must name every triggered axis")
	_check(report_text.contains("- Class corridor flags (outside 80–120% of the same level/scenario median across solo, AoE, or defense): **120**."), "Markdown class corridor counter does not publish the three-axis total")
	if defense_only_rows.is_empty():
		return
	var defense_only_key := str((defense_only_rows[0] as Dictionary)["key"])
	var score_mutation := dataset.duplicate(true)
	for row_value in score_mutation["class_rows"]:
		var row: Dictionary = row_value
		if str(row["key"]) == defense_only_key:
			row["defense_score"] = 1.0
			break
	_check(not bool(Generator.verify_class_corridor_artifacts(score_mutation).get("ok", true)), "defense-score mutation must fail closed when flag and summary are stale")
	var flag_mutation := dataset.duplicate(true)
	for row_value in flag_mutation["class_rows"]:
		var row: Dictionary = row_value
		if str(row["key"]) == defense_only_key:
			row["outlier_flag"] = "ok"
			break
	_check(not bool(Generator.verify_class_corridor_artifacts(flag_mutation).get("ok", true)), "defense-only flag mutation must fail closed")
	var summary_mutation := dataset.duplicate(true)
	var mutated_summary: Array = (summary_mutation.get("outliers", {}) as Dictionary).get("class_corridor_80_120", [])
	for index in range(mutated_summary.size()):
		if str((mutated_summary[index] as Dictionary).get("key", "")) == defense_only_key:
			mutated_summary.remove_at(index)
			break
	_check(not bool(Generator.verify_class_corridor_artifacts(summary_mutation).get("ok", true)), "defense-only summary-count mutation must fail closed")


# FAN-2504: the rejected FAN-2491 candidate rounded class ratios with
# floor(value * 100.0 + 0.5) and shipped a test that recomputed the very same
# expression, so implementation and oracle agreed on the same wrong text. Every
# expectation below is a hand-computed literal of the documented decimal
# half-up policy — never a value obtained from Generator — and the two ties the
# old arithmetic gets wrong (1.015, 1.035) are covered explicitly alongside the
# values immediately below and above them.
func _validate_class_ratio_formatting(dataset: Dictionary) -> void:
	for expectation in [
		[1.014, "1.01"], [1.0149, "1.01"], [1.015, "1.02"], [1.0151, "1.02"], [1.016, "1.02"],
		[1.034, "1.03"], [1.035, "1.04"], [1.036, "1.04"],
		[1.624, "1.62"], [1.625, "1.63"], [1.626, "1.63"],
		[0.855, "0.86"], [0.995, "1.00"], [1.095, "1.10"], [1.615, "1.62"],
		[0.80, "0.80"], [1.20, "1.20"], [0.0, "0.00"], [-0.004, "0.00"],
		[-1.0149, "-1.01"], [-1.015, "-1.02"], [-1.035, "-1.04"], [-1.625, "-1.63"],
	]:
		var value := float(expectation[0])
		var expected := str(expectation[1])
		_check(Generator.format_class_ratio(value) == expected, "%.4f must format as %s under the documented decimal half-up policy, got %s" % [value, expected, Generator.format_class_ratio(value)])
	# The published surfaces must go through that formatter, not host printf:
	# 1.625 is exactly representable, so "%.2f" still splits macOS ("1.62") from
	# Windows ("1.63") wherever a call site was missed.
	_check(str(Generator.class_corridor_status(1.625, 1.0, 1.0).get("flag", "")) == "OUTLIER solo=1.63×", "corridor flag must publish the 1.625 tie as 1.63× on every host, got: %s" % str(Generator.class_corridor_status(1.625, 1.0, 1.0).get("flag", "")))
	_check(str(Generator.class_corridor_status(-1.015, 1.0, 1.0).get("flag", "")) == "OUTLIER solo=-1.02×", "corridor flag must round a negative tie away from zero, got: %s" % str(Generator.class_corridor_status(-1.015, 1.0, 1.0).get("flag", "")))
	var multi_tie := Generator.class_corridor_status(1.625, 0.375, 1.615)
	_check(_axis_names(multi_tie.get("axes", [])) == ["solo", "AoE", "defense"], "tie-valued multi-axis corridor status must keep solo/AoE/defense order")
	_check(str(multi_tie.get("flag", "")) == "OUTLIER solo=1.63×; AoE=0.38×; defense=1.62×", "tie-valued multi-axis flag text must match the independent literals, got: %s" % str(multi_tie.get("flag", "")))
	var ratio_pattern := RegEx.create_from_string("([A-Za-z]+)=?\\s?(-?[0-9]+\\.[0-9]{2})×")
	for row_value in dataset.get("class_rows", []):
		var row: Dictionary = row_value
		for field in ["strengths", "weaknesses", "outlier_flag"]:
			for regex_match in ratio_pattern.search_all(str(row.get(field, ""))):
				var axis_field := str(CLASS_RATIO_AXIS_FIELDS.get(regex_match.get_string(1), ""))
				_check(not axis_field.is_empty(), "%s %s names an unknown ratio axis %s" % [row.get("key", "?"), field, regex_match.get_string(1)])
				if axis_field.is_empty():
					continue
				var expected_text := _oracle_two_decimals(float(row.get(axis_field, 0.0)))
				_check(regex_match.get_string(2) == expected_text, "%s %s publishes %s for %s, independent decimal rounding says %s" % [row.get("key", "?"), field, regex_match.get_string(2), axis_field, expected_text])
	# Negative control: the literals above have to be discriminating rather than
	# tautological, so the shipped rows must still contain ties where the
	# rejected arithmetic disagrees with the policy. Deleting those edge cases
	# from the dataset turns this red instead of quietly weakening the suite.
	var discriminating := 0
	for row_value in dataset.get("class_rows", []):
		var row: Dictionary = row_value
		for axis_field in ["solo_score", "aoe_score", "defense_score", "convenience_relative"]:
			var value := float(row.get(axis_field, 0.0))
			var legacy_cents := int(floor(absf(value) * 100.0 + 0.5))
			if "%d.%02d" % [legacy_cents / 100, legacy_cents % 100] != Generator.format_class_ratio(value):
				discriminating += 1
	_check(discriminating >= 2, "class rows must still carry the binary-inexact ties that separate decimal half-up from floor(value * 100 + 0.5); found %d" % discriminating)


# FAN-2504: independent of Generator.format_class_ratio — it neither calls it nor
# repeats its arithmetic. This renders the magnitude as decimal digits first (at
# six decimals no host disagrees about these values) and only then rounds those
# digits half-up with integer maths, while the generator decides entirely in
# scaled integers without ever producing digits. A regression to either platform
# "%.2f" or floor(value * 100.0 + 0.5) therefore disagrees with this oracle.
func _oracle_two_decimals(value: float) -> String:
	var digits := String.num(absf(value), 6).split(".")
	# String.num strips trailing zeroes, so restore the fixed six-digit scale
	# before the fraction can be read as an integer number of micro units.
	var fraction := str(digits[1]).rpad(6, "0") if digits.size() > 1 else "000000"
	var cents := int(str(digits[0])) * 100 + (int(fraction) + 5000) / 10000
	return "%s%d.%02d" % ["-" if value < 0.0 and cents > 0 else "", cents / 100, cents % 100]


func _strict_corridor_axes(row: Dictionary) -> Array:
	var axes := []
	for axis in [
		{"name": "solo", "score": float(row["solo_score"])},
		{"name": "AoE", "score": float(row["aoe_score"])},
		{"name": "defense", "score": float(row["defense_score"])},
	]:
		var score := float(axis["score"])
		if score < 0.80 or score > 1.20:
			axes.append(str(axis["name"]))
	return axes


func _axis_names(axes: Array) -> Array:
	var names := []
	for axis_value in axes:
		names.append(str((axis_value as Dictionary).get("name", "")))
	return names


func _validate_class_ultimate_oracle(dataset: Dictionary) -> void:
	# This deliberately does not call the report generator's modifier helper or
	# class-row implementation. It rebuilds every class ultimate from raw level
	# stats and canonical runtime APIs, which catches a second attribute-flat pass.
	var rows: Array = dataset.get("class_rows", [])
	var meta_rows := 0
	var numerically_distinct_double_rows := 0
	var numerically_neutral_double_rows := 0
	for row_value in rows:
		var row: Dictionary = row_value
		var class_id := str(row.get("class_id", ""))
		var level := int(row.get("level", 0))
		var scenario_id := str(row.get("scenario", ""))
		var build: Dictionary = (dataset.get("builds", {}) as Dictionary).get(class_id, {})
		var stats: Dictionary = (build.get("level1_stats", {}) if level == 1 else build.get("level20_stats", {})).duplicate(true)
		var state := _oracle_state(dataset, class_id, scenario_id)
		var mods: Dictionary = Meta.skill_modifiers_for_class(state, class_id) if scenario_id != "no_meta" else {}
		var run_mods := _oracle_a5_run_modifiers(class_id)
		_apply_meta_once(stats, run_mods, mods)
		var expected := _oracle_first_minute_ultimate(class_id, stats, run_mods, mods)
		_check(is_equal_approx(float(row.get("first_minute_ultimate_damage", -1.0)), expected), "%s class ultimate is not the single-application runtime value" % row.get("key", "?"))
		_check(is_equal_approx(float(row.get("atlas_start_charge", -1.0)), snappedf(float(mods.get("ult_start_charge", 0.0)), 0.01)), "%s Atlas ultimate charge attribution differs from canonical meta state" % row.get("key", "?"))
		if scenario_id == "no_meta":
			continue
		meta_rows += 1
		var double_stats := stats.duplicate(true)
		_apply_attribute_flats(double_stats, mods)
		var double_applied := _oracle_first_minute_ultimate(class_id, double_stats, run_mods, mods)
		if is_equal_approx(expected, double_applied):
			numerically_neutral_double_rows += 1
		else:
			numerically_distinct_double_rows += 1
			_check(not is_equal_approx(float(row.get("first_minute_ultimate_damage", -1.0)), double_applied), "%s still stores a double-applied meta ultimate" % row.get("key", "?"))
	_check(meta_rows == 102, "meta ultimate oracle covers %d rows, expected 102" % meta_rows)
	_check(numerically_distinct_double_rows == 99 and numerically_neutral_double_rows == 3, "double-application regression shape changed: distinct=%d neutral=%d" % [numerically_distinct_double_rows, numerically_neutral_double_rows])


func _oracle_state(dataset: Dictionary, class_id: String, scenario_id: String) -> Dictionary:
	var state := Meta.default_state()
	state["ascension_levels"] = {class_id: 5}
	if scenario_id == "no_meta":
		return state
	var build: Dictionary = (dataset.get("meta_builds", {}) as Dictionary).get(class_id, {})
	var purchased: Array = (build.get("purchased_ids", []) as Array).duplicate()
	state["hidden_reveal_facts"] = {class_id: (build.get("hidden_reveal_facts", []) as Array).duplicate()}
	if scenario_id in ["class_atlas50", "class_atlas59_upper"]:
		var scenario: Dictionary = (dataset.get("scenarios", {}) as Dictionary).get(scenario_id, {})
		for atlas_id in scenario.get("atlas_ids", []):
			purchased.append(str(atlas_id))
		var monster_ids := []
		for raw_monster in CodexData.monsters():
			monster_ids.append(str((raw_monster as Dictionary).get("id", "")))
		state["discovered_monsters"] = monster_ids
		state["secret_boss_defeated"] = true
	state["skill_nodes"] = purchased
	return state


func _oracle_a5_run_modifiers(class_id: String) -> Dictionary:
	var run_mods := {}
	var ascension: Dictionary = PD.ascension_mods(class_id, 5)
	for key_value in ascension:
		var key := str(key_value)
		var value := float(ascension[key_value])
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


func _apply_meta_once(stats: Dictionary, run_mods: Dictionary, mods: Dictionary) -> void:
	_apply_attribute_flats(stats, mods)
	for source_key in PlayerScript.META_SKILL_MULT_MAP:
		if mods.has(source_key):
			var run_key := str(PlayerScript.META_SKILL_MULT_MAP[source_key])
			run_mods[run_key] = float(run_mods.get(run_key, 1.0)) * (1.0 + float(mods[source_key]))
	for source_key in PlayerScript.META_SKILL_FLAT_MAP:
		if mods.has(source_key):
			var run_key := str(PlayerScript.META_SKILL_FLAT_MAP[source_key])
			run_mods[run_key] = float(run_mods.get(run_key, 0.0)) + float(mods[source_key])


func _apply_attribute_flats(stats: Dictionary, mods: Dictionary) -> void:
	for source_key in PlayerScript.META_SKILL_ATTRIBUTE_FLAT_MAP:
		if mods.has(source_key):
			var stat_key := str(PlayerScript.META_SKILL_ATTRIBUTE_FLAT_MAP[source_key])
			stats[stat_key] = float(stats.get(stat_key, 0.0)) + float(mods[source_key])


func _oracle_first_minute_ultimate(class_id: String, stats: Dictionary, run_mods: Dictionary, mods: Dictionary) -> float:
	var first_weapon := str(PD.weapon_ids(class_id)[0])
	var config := PD.weapon(class_id, first_weapon)
	config["character_id"] = class_id
	var params := PD.derived_parameters(stats, run_mods, config)
	var ultimate := PD._budget_ultimate_dps(class_id, params)
	var result := (float(ultimate.get("solo", 0.0)) + float(ultimate.get("aoe", 0.0))) * 30.0
	var start_charge := float(mods.get("ult_start_charge", 0.0))
	if start_charge > 0.0:
		var ultimate_config := PD.ultimate_config(class_id)
		var base_damage := maxf(float(params.get("damage", 1.0)), float(params.get("magic_damage", 1.0)))
		var activation_damage := base_damage * float(ultimate_config.get("damage", 1.0)) * float(params.get("ultimate_multiplier", 1.0))
		result += activation_damage * start_charge
	return snappedf(result, 0.01)


func _validate_live_coverage(dataset: Dictionary) -> void:
	var parity: Array = dataset.get("formula_live_parity", [])
	var expected_pairs: Array = dataset["roster"]["pair_keys"]
	_check(parity.size() == expected_pairs.size(), "live parity must cover every runtime pair")
	var actual_pairs := []
	var actual_modes := {}
	var actual_finals := {}
	for row_value in parity:
		var row: Dictionary = row_value
		actual_pairs.append(str(row.get("pair", "")))
		actual_modes[str(row.get("attack_mode", ""))] = true
		actual_finals[str(row.get("final_mechanic", ""))] = true
		_check((row.get("solo_samples_dpm", []) as Array).size() == Generator.LIVE_SEEDS.size(), "%s solo sample count mismatch" % row.get("pair", "?"))
		_check((row.get("pack_samples_dpm", []) as Array).size() == Generator.LIVE_SEEDS.size(), "%s pack sample count mismatch" % row.get("pair", "?"))
	_check(actual_pairs == expected_pairs, "live parity pair order/set mismatch")
	var expected_modes := {}
	var expected_finals := {}
	for pair_value in expected_pairs:
		var pair := str(pair_value).split("/", true, 1)
		var config := PD.weapon(str(pair[0]), str(pair[1]))
		expected_modes[str(config.get("attack_mode", config.get("attack_shape", "single")))] = true
		for raw_branch in Schema6.class_entry(str(pair[0])).get("weapon_branches", []):
			if str((raw_branch as Dictionary).get("weapon_id", "")) != str(pair[1]):
				continue
			for raw_node in (raw_branch as Dictionary).get("nodes", []):
				if str((raw_node as Dictionary).get("role", "")) == "weapon_final":
					expected_finals[str((raw_node as Dictionary).get("mechanic_id", ""))] = true
	_check(actual_modes == expected_modes, "live attack-mode coverage set mismatch")
	_check(actual_finals == expected_finals, "live nonlinear final coverage set mismatch")
	_validate_live_telemetry(dataset)


func _validate_live_telemetry(dataset: Dictionary) -> void:
	var verification := Generator.verify_live_telemetry_artifacts(dataset)
	_check(bool(verification.get("ok", false)), "live telemetry contract failed: %s" % "; ".join(verification.get("errors", [])))
	if not bool(verification.get("ok", false)):
		return
	var telemetry: Dictionary = dataset.get("live_telemetry", {})
	var samples: Array = telemetry.get("samples", [])
	var expected_count := int((dataset.get("roster", {}) as Dictionary).get("weapon_pair_count", 0)) * Generator.LIVE_SEEDS.size() * 2 + 3
	_check(samples.size() == expected_count, "telemetry sample count does not cover every parity probe plus three fixtures")
	if samples.is_empty():
		return
	var missing_counter := dataset.duplicate(true)
	var missing_samples: Array = (missing_counter.get("live_telemetry", {}) as Dictionary).get("samples", [])
	var missing_counters: Dictionary = (missing_samples[0] as Dictionary).get("counters", {})
	missing_counters.erase("hits")
	_check(not bool(Generator.verify_live_telemetry_artifacts(missing_counter).get("ok", true)), "missing hit counter must fail closed")
	var duplicate_event := dataset.duplicate(true)
	var duplicate_samples: Array = (duplicate_event.get("live_telemetry", {}) as Dictionary).get("samples", [])
	var duplicate_events: Array = (duplicate_samples[0] as Dictionary).get("events", [])
	duplicate_events.append(duplicate_events[0].duplicate(true))
	_check(not bool(Generator.verify_live_telemetry_artifacts(duplicate_event).get("ok", true)), "duplicated trace event must fail closed")
	var target_cardinality := dataset.duplicate(true)
	var target_samples: Array = (target_cardinality.get("live_telemetry", {}) as Dictionary).get("samples", [])
	var target_counters: Dictionary = (target_samples[0] as Dictionary).get("counters", {})
	target_counters["unique_target_count"] = int(target_counters.get("unique_target_count", 0)) + 1
	_check(not bool(Generator.verify_live_telemetry_artifacts(target_cardinality).get("ok", true)), "target cardinality mismatch must fail closed")
	var source_phase := dataset.duplicate(true)
	var source_samples: Array = (source_phase.get("live_telemetry", {}) as Dictionary).get("samples", [])
	var source_counters: Dictionary = (source_samples[0] as Dictionary).get("counters", {})
	var buckets: Array = source_counters.get("damage_by_source_phase", [])
	buckets[0]["source"] = "formula_label"
	_check(not bool(Generator.verify_live_telemetry_artifacts(source_phase).get("ok", true)), "source/phase misattribution must fail closed")
	var final_count := dataset.duplicate(true)
	var final_count_samples: Array = (final_count.get("live_telemetry", {}) as Dictionary).get("samples", [])
	var final_count_counters: Dictionary = (final_count_samples[0] as Dictionary).get("counters", {})
	final_count_counters["final_event_count"] = int(final_count_counters.get("final_event_count", 0)) + 1
	_check(not bool(Generator.verify_live_telemetry_artifacts(final_count).get("ok", true)), "final event count mismatch must fail closed")
	var final_damage := dataset.duplicate(true)
	var final_damage_samples: Array = (final_damage.get("live_telemetry", {}) as Dictionary).get("samples", [])
	var final_damage_counters: Dictionary = (final_damage_samples[0] as Dictionary).get("counters", {})
	final_damage_counters["final_event_damage"] = float(final_damage_counters.get("final_event_damage", 0.0)) + 1.0
	_check(not bool(Generator.verify_live_telemetry_artifacts(final_damage).get("ok", true)), "final event damage mismatch must fail closed")
	var trace_id := dataset.duplicate(true)
	var trace_samples: Array = (trace_id.get("live_telemetry", {}) as Dictionary).get("samples", [])
	var trace_sample: Dictionary = trace_samples[0]
	trace_sample["trace_id"] = "fan1511:wrong"
	_check(not bool(Generator.verify_live_telemetry_artifacts(trace_id).get("ok", true)), "trace identifier mismatch must fail closed")
	var digest_mutation := dataset.duplicate(true)
	var methodology: Dictionary = digest_mutation.get("methodology", {})
	methodology["telemetry_mutation"] = true
	_check(not bool(Generator.verify_dataset_digest(digest_mutation).get("ok", true)), "raw payload mutation must fail digest verification")
	var final_location := _find_final_event(dataset)
	_check(not final_location.is_empty(), "telemetry evidence must include a linked final event for relationship rejection cases")
	if final_location.is_empty():
		return
	var sample_index := int(final_location["sample_index"])
	var final_index := int(final_location["event_index"])
	var related_hit_id := str(final_location["related_hit_id"])
	var fabricated_final := dataset.duplicate(true)
	var fabricated_samples: Array = (fabricated_final.get("live_telemetry", {}) as Dictionary).get("samples", [])
	var fabricated_events: Array = (fabricated_samples[sample_index] as Dictionary).get("events", [])
	for raw_event in fabricated_events:
		var event: Dictionary = raw_event
		if str(event.get("event_id", "")) == related_hit_id:
			var final_ids: Array = event.get("final_event_ids", [])
			final_ids.append("forged-final-event")
			event["final_event_ids"] = final_ids
			break
	_expect_telemetry_rejection(fabricated_final, "hit references a fabricated final event id", "fabricated final relation must fail closed")
	var missing_reciprocal := dataset.duplicate(true)
	var reciprocal_samples: Array = (missing_reciprocal.get("live_telemetry", {}) as Dictionary).get("samples", [])
	var reciprocal_events: Array = (reciprocal_samples[sample_index] as Dictionary).get("events", [])
	var reciprocal_final: Dictionary = reciprocal_events[final_index]
	reciprocal_final.erase("related_hit_id")
	_expect_telemetry_rejection(missing_reciprocal, "final event is not linked to a runtime hit", "missing final-to-hit relation must fail closed")
	var final_phase_mutation := dataset.duplicate(true)
	var phase_samples: Array = (final_phase_mutation.get("live_telemetry", {}) as Dictionary).get("samples", [])
	var phase_events: Array = (phase_samples[sample_index] as Dictionary).get("events", [])
	var phase_final: Dictionary = phase_events[final_index]
	phase_final["phase"] = "untrusted_final_phase"
	_expect_telemetry_rejection(final_phase_mutation, "final event has an invalid causal phase", "final source/phase mutation must fail closed")
	var causal_location := _find_post_hit_final_event(dataset)
	_check(not causal_location.is_empty(), "telemetry evidence must include a post-hit final event for causal-order rejection")
	if not causal_location.is_empty():
		var causal_mutation := dataset.duplicate(true)
		var causal_samples: Array = (causal_mutation.get("live_telemetry", {}) as Dictionary).get("samples", [])
		var causal_events: Array = (causal_samples[int(causal_location["sample_index"])] as Dictionary).get("events", [])
		var causal_final: Dictionary = causal_events[int(causal_location["event_index"])]
		causal_final["phase"] = "final_resolution"
		_expect_telemetry_rejection(causal_mutation, "final event causal order is invalid", "causal-order mutation must fail closed")
	var target_location := _find_target_mismatch_final_event(dataset)
	_check(not target_location.is_empty(), "telemetry evidence must include a multi-target final event for target-parity rejection")
	if not target_location.is_empty():
		var target_mutation := dataset.duplicate(true)
		var target_mutation_samples: Array = (target_mutation.get("live_telemetry", {}) as Dictionary).get("samples", [])
		var target_events: Array = (target_mutation_samples[int(target_location["sample_index"])] as Dictionary).get("events", [])
		var target_final: Dictionary = target_events[int(target_location["event_index"])]
		target_final["target_id"] = str(target_location["other_target_id"])
		_expect_telemetry_rejection(target_mutation, "final event target does not match related hit", "final target parity mutation must fail closed")
	var measurement_location := _find_measurement_hit(dataset)
	_check(not measurement_location.is_empty(), "telemetry evidence must include a measured player hit for HP-ledger rejection")
	if not measurement_location.is_empty():
		var missing_applied := dataset.duplicate(true)
		var applied_samples: Array = (missing_applied.get("live_telemetry", {}) as Dictionary).get("samples", [])
		var applied_events: Array = (applied_samples[int(measurement_location["sample_index"])] as Dictionary).get("events", [])
		var applied_hit: Dictionary = applied_events[int(measurement_location["event_index"])]
		applied_hit["damage"] = 0.0
		_expect_telemetry_rejection(missing_applied, "measurement hit damage does not reconcile to hp ledger", "missing applied damage must fail the HP ledger")


func _find_final_event(dataset: Dictionary) -> Dictionary:
	var samples: Array = (dataset.get("live_telemetry", {}) as Dictionary).get("samples", [])
	for sample_index in range(samples.size()):
		var events: Array = (samples[sample_index] as Dictionary).get("events", [])
		for event_index in range(events.size()):
			var event: Dictionary = events[event_index]
			if str(event.get("kind", "")) == "final_event" and str(event.get("related_hit_id", "")) != "":
				return {"sample_index": sample_index, "event_index": event_index, "related_hit_id": str(event["related_hit_id"])}
	return {}


func _find_post_hit_final_event(dataset: Dictionary) -> Dictionary:
	var samples: Array = (dataset.get("live_telemetry", {}) as Dictionary).get("samples", [])
	for sample_index in range(samples.size()):
		var events: Array = (samples[sample_index] as Dictionary).get("events", [])
		var event_indices := {}
		for event_index in range(events.size()):
			event_indices[str((events[event_index] as Dictionary).get("event_id", ""))] = event_index
		for event_index in range(events.size()):
			var event: Dictionary = events[event_index]
			var related_hit_id := str(event.get("related_hit_id", ""))
			if str(event.get("kind", "")) == "final_event" and event_indices.has(related_hit_id) and event_index > int(event_indices[related_hit_id]):
				return {"sample_index": sample_index, "event_index": event_index}
	return {}


func _find_target_mismatch_final_event(dataset: Dictionary) -> Dictionary:
	var samples: Array = (dataset.get("live_telemetry", {}) as Dictionary).get("samples", [])
	for sample_index in range(samples.size()):
		var sample: Dictionary = samples[sample_index]
		var targets: Array = sample.get("fixture_target_ids", [])
		if targets.size() < 2:
			continue
		var events: Array = sample.get("events", [])
		for event_index in range(events.size()):
			var event: Dictionary = events[event_index]
			if str(event.get("kind", "")) != "final_event" or str(event.get("related_hit_id", "")) == "":
				continue
			for target_value in targets:
				if str(target_value) != str(event.get("target_id", "")):
					return {"sample_index": sample_index, "event_index": event_index, "other_target_id": str(target_value)}
	return {}


func _find_measurement_hit(dataset: Dictionary) -> Dictionary:
	var samples: Array = (dataset.get("live_telemetry", {}) as Dictionary).get("samples", [])
	for sample_index in range(samples.size()):
		var events: Array = (samples[sample_index] as Dictionary).get("events", [])
		for event_index in range(events.size()):
			var event: Dictionary = events[event_index]
			if str(event.get("kind", "")) == "hit" and str(event.get("source", "")) == "player_weapon" and str(event.get("probe_phase", "")) == "measurement":
				return {"sample_index": sample_index, "event_index": event_index}
	return {}


func _expect_telemetry_rejection(candidate: Dictionary, expected_error: String, message: String) -> void:
	var verification := Generator.verify_live_telemetry_artifacts(candidate)
	_check(not bool(verification.get("ok", true)), message)
	_check("; ".join(verification.get("errors", [])).contains(expected_error), "%s (missing error: %s)" % [message, expected_error])


func _validate_csv(dataset: Dictionary) -> void:
	var file := FileAccess.open(Generator.CSV_PATH, FileAccess.READ)
	_check(file != null, "per_weapon.csv is missing")
	if file == null:
		return
	var header := file.get_csv_line()
	var indices := {}
	var valid_header := true
	for column in ["key", "class_id", "weapon_id", "level", "scenario", "solo_dpm", "crowd_10_total_dpm", "hp", "ehp", "ttd_seconds", "ult_start_charge"]:
		var index := Array(header).find(column)
		_check(index >= 0, "CSV lacks %s column" % column)
		indices[column] = index
		valid_header = valid_header and index >= 0
	if not valid_header:
		file.close()
		return
	var rows_by_key := {}
	while not file.eof_reached():
		var cells := file.get_csv_line()
		if cells.size() == 1 and str(cells[0]) == "":
			continue
		var key_index := int(indices["key"])
		if cells.size() > key_index:
			rows_by_key[str(cells[key_index])] = cells
	file.close()
	_check(rows_by_key.size() == (dataset.get("weapon_rows", []) as Array).size(), "CSV row/key count mismatch")
	for row_value in dataset["weapon_rows"]:
		var row: Dictionary = row_value
		var key := str(row.get("key", ""))
		_check(rows_by_key.has(key), "CSV missing key %s" % key)
		if not rows_by_key.has(key):
			continue
		var cells = rows_by_key[key]
		_check(str(cells[int(indices["class_id"])]) == str(row.get("class_id", "")), "CSV class differs for %s" % key)
		_check(str(cells[int(indices["weapon_id"])]) == str(row.get("weapon_id", "")), "CSV weapon differs for %s" % key)
		_check(int(cells[int(indices["level"])]) == int(row.get("level", -1)), "CSV level differs for %s" % key)
		_check(str(cells[int(indices["scenario"])]) == str(row.get("scenario", "")), "CSV scenario differs for %s" % key)
		for metric in ["solo_dpm", "crowd_10_total_dpm", "hp", "ehp", "ttd_seconds", "ult_start_charge"]:
			_check(is_equal_approx(float(cells[int(indices[metric])]), float(row.get(metric, INF))), "CSV %s differs for %s" % [metric, key])
	_check(_read_text(Generator.CSV_PATH) == _independent_render_csv(dataset), "CSV is not the exact independent projection of raw.json.gz")


func _validate_markdown(dataset: Dictionary, report_text: String) -> void:
	_check(report_text.contains("## Per-weapon matrix"), "Markdown lacks per-weapon matrix")
	_check(report_text.contains("## Formula / live parity"), "Markdown lacks formula/live section")
	_check(report_text.contains(Generator.NON_PLAYABLE_LABEL), "Markdown lacks mandatory non-playable label")
	_check(report_text.contains("changes no balance values") or report_text.contains("No balance values"), "Markdown does not state the no-balance-change scope")
	_check(report_text.contains("applies class/Atlas attribute and run modifiers exactly once"), "Markdown does not state the single-application ultimate rule")
	var source: Dictionary = dataset.get("source", {})
	_check(report_text.contains("Source commit `%s` (tree `%s`, timestamp `%s`)" % [source.get("commit", ""), source.get("tree", ""), source.get("commit_timestamp", "")]), "Markdown source provenance differs from raw.json.gz")
	_check(report_text.contains("Dataset digest: `%s`" % dataset.get("dataset_digest_sha256", "")), "Markdown dataset digest differs from raw.json.gz")
	for row_value in dataset.get("class_rows", []):
		var row: Dictionary = row_value
		var prefix := "| %s | %d | %s | %s | %.3f | %.3f | %.3f | %.3f | %.2f |" % [row["class_id"], row["level"], row["scenario"], "; ".join(row["roles"]), row["solo_score"], row["aoe_score"], row["defense_score"], row["convenience_relative"], row["first_minute_ultimate_damage"]]
		_check(report_text.contains(prefix), "Markdown class row differs from raw.json.gz for %s" % row.get("key", "?"))
	_check(report_text.contains("## Live event telemetry"), "Markdown lacks live telemetry projection")
	_check(report_text.contains("Final-event damage is a deduplicated tagged subset"), "Markdown does not state final-event non-additivity")
	_validate_independent_markdown_projection(dataset, report_text)


func _validate_independent_artifact_contract(dataset: Dictionary, report_text: String) -> void:
	var required_top_level := ["schema", "issue_id", "source", "legacy_source", "supplemental_execution", "run_identity", "generation_command", "roster", "builds", "meta_builds", "scenarios", "weapon_rows", "class_rows", "formula_live_parity", "live_telemetry", "final_execution", "formula_live_dispositions", "outliers", "dataset_digest_sha256"]
	for key_value in required_top_level:
		_check(dataset.has(str(key_value)), "schema-v4 raw artifact lacks required top-level field %s" % key_value)
	var columns: Array = A5_SCHEMA.get("csv_columns", [])
	_check(not columns.is_empty(), "versioned A5 schema registry has no CSV columns")
	for row_value in dataset.get("weapon_rows", []):
		var row: Dictionary = row_value
		for column_value in columns:
			var column: Dictionary = column_value
			_check(row.has(str(column.get("field", ""))), "%s lacks schema-v4 CSV field %s" % [row.get("key", "?"), column.get("field", "?")])
	var source: Dictionary = dataset.get("source", {})
	var legacy_source: Dictionary = dataset.get("legacy_source", {})
	var supplemental_source: Dictionary = dataset.get("supplemental_execution", {})
	_check(_independent_source_matches_git(source), "raw source provenance must resolve to an exact ancestor commit/tree/timestamp")
	_check(_independent_source_matches_git(legacy_source), "legacy source provenance must resolve to an exact ancestor commit/tree/timestamp")
	_check(_independent_source_matches_git(supplemental_source), "supplemental source provenance must resolve to an exact ancestor commit/tree/timestamp")
	_check(source == legacy_source, "schema-v4 legacy source must preserve the original raw source tuple")
	_check(str(dataset.get("generation_command", "")).contains("--source-commit=%s" % supplemental_source.get("commit", "")), "generation command must pin supplemental source commit")
	var persisted_digest := str(dataset.get("dataset_digest_sha256", ""))
	_check(persisted_digest == _independent_dataset_digest(dataset), "dataset digest does not match the independent canonical raw payload")
	_validate_independent_derived_semantics(dataset)
	_validate_named_artifact_corruptions(dataset, report_text)


func _independent_source_matches_git(source: Dictionary) -> bool:
	var commit := str(source.get("commit", ""))
	if commit.length() != 40:
		return false
	var output := []
	if OS.execute("git", ["show", "-s", "--format=%H%n%T%n%cI", commit], output, false) != 0:
		return false
	var fields := "".join(PackedStringArray(output)).strip_edges().split("\n", false)
	if fields.size() != 3:
		return false
	for index in range(fields.size()):
		if str(fields[index]) != str(source.get(["commit", "tree", "commit_timestamp"][index], "")):
			return false
	return OS.execute("git", ["merge-base", "--is-ancestor", commit, "HEAD"], [], false) == 0


func _independent_dataset_digest(dataset: Dictionary) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	_independent_append_digest_value(context, dataset, "dataset_digest_sha256")
	return context.finish().hex_encode()


func _independent_append_digest_value(context: HashingContext, value: Variant, excluded_key := "") -> void:
	if value is Dictionary:
		var dictionary: Dictionary = value
		var keys := dictionary.keys()
		keys.sort()
		context.update("{".to_utf8_buffer())
		var first := true
		for key_value in keys:
			if str(key_value) == excluded_key:
				continue
			if not first:
				context.update(",".to_utf8_buffer())
			first = false
			context.update(JSON.stringify(str(key_value)).to_utf8_buffer())
			context.update(":".to_utf8_buffer())
			_independent_append_digest_value(context, dictionary[key_value])
		context.update("}".to_utf8_buffer())
		return
	if value is Array:
		var array: Array = value
		context.update("[".to_utf8_buffer())
		for index in range(array.size()):
			if index > 0:
				context.update(",".to_utf8_buffer())
			_independent_append_digest_value(context, array[index])
		context.update("]".to_utf8_buffer())
		return
	context.update(JSON.stringify(value, "", true, true).to_utf8_buffer())


func _independent_render_csv(dataset: Dictionary) -> String:
	var lines := PackedStringArray()
	var columns: Array = (A5_SCHEMA.get("csv_columns", []) as Array).duplicate(true)
	var headers := PackedStringArray()
	for column_value in columns:
		headers.append(str((column_value as Dictionary).get("name", "")))
	lines.append(",".join(headers))
	for row_value in dataset.get("weapon_rows", []):
		var row: Dictionary = row_value
		var escaped := PackedStringArray()
		for column_value in columns:
			var column: Dictionary = column_value
			var field := str(column.get("field", ""))
			var cell: Variant = JSON.stringify(row[field], "", true, true) if bool(column.get("canonical_json", false)) else row[field]
			escaped.append("\"%s\"" % str(cell).replace("\"", "\"\""))
		lines.append(",".join(escaped))
	return "\n".join(lines) + "\n"


func _validate_independent_derived_semantics(dataset: Dictionary) -> void:
	_validate_independent_weapon_deltas(dataset)
	_validate_independent_class_aggregates(dataset)
	_validate_independent_live_verdicts(dataset)


func _validate_independent_weapon_deltas(dataset: Dictionary) -> void:
	var baselines := {}
	var constellation_rows := {}
	for row_value in dataset.get("weapon_rows", []):
		var row: Dictionary = row_value
		var identity := "%s|%s|%d" % [row.get("class_id", ""), row.get("weapon_id", ""), int(row.get("level", 0))]
		if str(row.get("scenario", "")) == "no_meta":
			baselines[identity] = row
		if str(row.get("scenario", "")) == "class_constellation":
			constellation_rows[identity] = row
	for row_value in dataset.get("weapon_rows", []):
		var row: Dictionary = row_value
		var identity := "%s|%s|%d" % [row.get("class_id", ""), row.get("weapon_id", ""), int(row.get("level", 0))]
		var baseline: Dictionary = baselines.get(identity, {})
		var constellation: Dictionary = constellation_rows.get(identity, {})
		_check(not baseline.is_empty() and not constellation.is_empty(), "%s lacks a required baseline or constellation row" % row.get("key", "?"))
		if baseline.is_empty() or constellation.is_empty():
			continue
		for metric in ["solo_dpm", "crowd_10_total_dpm", "ehp", "ttd_seconds", "pickup_radius", "move_speed"]:
			var delta := float(row.get(metric, 0.0)) - float(baseline.get(metric, 0.0))
			_check(is_equal_approx(float(row.get("%s_delta_abs" % metric, INF)), snappedf(delta, 0.01)), "%s %s absolute delta differs from independent baseline arithmetic" % [row.get("key", "?"), metric])
			var percent := snappedf(delta / maxf(absf(float(baseline.get(metric, 0.0))), 0.001) * 100.0, 0.01)
			_check(is_equal_approx(float(row.get("%s_delta_pct" % metric, INF)), percent), "%s %s percent delta differs from independent baseline arithmetic" % [row.get("key", "?"), metric])
		_check(is_equal_approx(float(row.get("crowd_10_per_target_dpm", -1.0)), float(row.get("crowd_10_total_dpm", 0.0)) / 10.0), "%s ten-target per-target DPM differs from independent division" % row.get("key", "?"))
		var expected_atlas := {}
		for metric in ["solo_dpm", "crowd_10_total_dpm", "pickup_radius", "move_speed", "ehp", "ttd_seconds", "healing_multiplier", "start_gold", "ult_start_charge"]:
			expected_atlas[metric] = snappedf(float(row.get(metric, 0.0)) - float(constellation.get(metric, 0.0)), 0.01)
		var actual_atlas: Dictionary = row.get("atlas_delta_vs_class_constellation", {})
		_check(actual_atlas.size() == expected_atlas.size(), "%s Atlas delta field set differs from the independent projection" % row.get("key", "?"))
		for metric in expected_atlas:
			_check(actual_atlas.has(metric) and is_equal_approx(float(actual_atlas.get(metric, INF)), float(expected_atlas[metric])), "%s Atlas deltas differ from independent class-constellation arithmetic" % row.get("key", "?"))
		_check(str(row.get("atlas_delta_summary", "")) == _independent_atlas_summary(str(row.get("scenario", "")), expected_atlas, bool(row.get("death_save", false)) and not bool(constellation.get("death_save", false))), "%s Atlas summary differs from independent deltas" % row.get("key", "?"))


func _independent_atlas_summary(scenario: String, deltas: Dictionary, adds_death_save: bool) -> String:
	if scenario not in ["class_atlas50", "class_atlas59_upper"]:
		return "n/a"
	var parts := PackedStringArray()
	for metric in ["solo_dpm", "crowd_10_total_dpm", "pickup_radius", "move_speed", "ehp", "ttd_seconds", "healing_multiplier", "start_gold", "ult_start_charge"]:
		var value := float(deltas.get(metric, 0.0))
		if not is_zero_approx(value):
			parts.append("%s %+.2f" % [metric, value])
	if adds_death_save:
		parts.append("death_save +1")
	return "no measured delta" if parts.is_empty() else "; ".join(parts)


func _validate_independent_class_aggregates(dataset: Dictionary) -> void:
	var class_rows: Array = dataset.get("class_rows", [])
	var actual_by_key := {}
	for row_value in class_rows:
		var row: Dictionary = row_value
		actual_by_key[str(row.get("key", ""))] = row
	for class_id_value in PD.character_ids():
		var class_id := str(class_id_value)
		for level_value in Generator.LEVELS:
			var level := int(level_value)
			for scenario_value in Generator.SCENARIO_IDS:
				var scenario := str(scenario_value)
				var key := "%s|%d|%s" % [class_id, level, scenario]
				var row: Dictionary = actual_by_key.get(key, {})
				_check(not row.is_empty(), "class aggregate is missing %s" % key)
				if row.is_empty():
					continue
				var weapon_rows := []
				for weapon_row_value in dataset.get("weapon_rows", []):
					var weapon_row: Dictionary = weapon_row_value
					if str(weapon_row.get("class_id", "")) == class_id and int(weapon_row.get("level", 0)) == level and str(weapon_row.get("scenario", "")) == scenario:
						weapon_rows.append(weapon_row)
				_check(weapon_rows.size() == PD.weapon_ids(class_id).size(), "%s class aggregate has incomplete weapon input" % key)
				var expected_roles := []
				for weapon_row_value in weapon_rows:
					var weapon_row: Dictionary = weapon_row_value
					expected_roles.append("%s:%s" % [weapon_row.get("weapon_id", ""), weapon_row.get("axis", "")])
				_check(row.get("roles", []) == expected_roles, "%s aggregate roles differ from runtime roster rows" % key)
				_check(is_equal_approx(float(row.get("mean_solo_dpm", INF)), snappedf(_independent_row_mean(weapon_rows, "solo_dpm"), 0.01)), "%s mean solo aggregate differs from raw rows" % key)
				_check(is_equal_approx(float(row.get("mean_crowd_10_dpm", INF)), snappedf(_independent_row_mean(weapon_rows, "crowd_10_total_dpm"), 0.01)), "%s mean crowd aggregate differs from raw rows" % key)
				_check(is_equal_approx(float(row.get("mean_ehp", INF)), snappedf(_independent_row_mean(weapon_rows, "ehp"), 0.01)), "%s mean EHP aggregate differs from raw rows" % key)
				_check(is_equal_approx(float(row.get("mean_ttd_seconds", INF)), snappedf(_independent_row_mean(weapon_rows, "ttd_seconds"), 0.01)), "%s mean TTD aggregate differs from raw rows" % key)
				var convenience := _independent_row_mean(weapon_rows, "pickup_radius") / 200.0 + _independent_row_mean(weapon_rows, "move_speed") / 600.0
				_check(is_equal_approx(float(row.get("convenience_score", INF)), snappedf(convenience, 0.001)), "%s convenience aggregate differs from raw rows" % key)
	for level_value in Generator.LEVELS:
		for scenario_value in Generator.SCENARIO_IDS:
			var level := int(level_value)
			var scenario := str(scenario_value)
			var scoped := []
			for row_value in class_rows:
				var row: Dictionary = row_value
				if int(row.get("level", 0)) == level and str(row.get("scenario", "")) == scenario:
					scoped.append(row)
			var medians := {"mean_solo_dpm": _independent_row_median(scoped, "mean_solo_dpm"), "mean_crowd_10_dpm": _independent_row_median(scoped, "mean_crowd_10_dpm"), "mean_ehp": _independent_row_median(scoped, "mean_ehp"), "convenience_score": _independent_row_median(scoped, "convenience_score")}
			for row_value in scoped:
				var row: Dictionary = row_value
				_check(is_equal_approx(float(row.get("solo_score", INF)), snappedf(float(row.get("mean_solo_dpm", 0.0)) / maxf(float(medians["mean_solo_dpm"]), 0.001), 0.001)), "%s solo score differs from independent median" % row.get("key", "?"))
				_check(is_equal_approx(float(row.get("aoe_score", INF)), snappedf(float(row.get("mean_crowd_10_dpm", 0.0)) / maxf(float(medians["mean_crowd_10_dpm"]), 0.001), 0.001)), "%s AoE score differs from independent median" % row.get("key", "?"))
				_check(is_equal_approx(float(row.get("defense_score", INF)), snappedf(float(row.get("mean_ehp", 0.0)) / maxf(float(medians["mean_ehp"]), 0.001), 0.001)), "%s defense score differs from independent median" % row.get("key", "?"))
				_check(is_equal_approx(float(row.get("convenience_relative", INF)), snappedf(float(row.get("convenience_score", 0.0)) / maxf(float(medians["convenience_score"]), 0.001), 0.001)), "%s convenience score differs from independent median" % row.get("key", "?"))
				_check(str(row.get("outlier_flag", "")) == _independent_corridor_flag(row), "%s corridor verdict differs from independent three-axis rule" % row.get("key", "?"))
	_validate_independent_corridor_summary(dataset)


func _independent_row_mean(rows: Array, field: String) -> float:
	if rows.is_empty():
		return 0.0
	var total := 0.0
	for row_value in rows:
		total += float((row_value as Dictionary).get(field, 0.0))
	return total / float(rows.size())


func _independent_row_median(rows: Array, field: String) -> float:
	var values := []
	for row_value in rows:
		values.append(float((row_value as Dictionary).get(field, 0.0)))
	values.sort()
	if values.is_empty():
		return 0.0
	if values.size() % 2 == 1:
		return float(values[values.size() / 2])
	return (float(values[values.size() / 2 - 1]) + float(values[values.size() / 2])) * 0.5


func _independent_corridor_axes(row: Dictionary) -> Array:
	var axes := []
	for axis in [{"name": "solo", "value": float(row.get("solo_score", 0.0))}, {"name": "AoE", "value": float(row.get("aoe_score", 0.0))}, {"name": "defense", "value": float(row.get("defense_score", 0.0))}]:
		var value := float(axis["value"])
		if value < 0.80 or value > 1.20:
			axes.append(str(axis["name"]))
	return axes


func _independent_corridor_flag(row: Dictionary) -> String:
	var parts := PackedStringArray()
	for axis_name in _independent_corridor_axes(row):
		var score := float(row.get("solo_score", 0.0)) if axis_name == "solo" else (float(row.get("aoe_score", 0.0)) if axis_name == "AoE" else float(row.get("defense_score", 0.0)))
		parts.append("%s=%s×" % [axis_name, _oracle_two_decimals(score)])
	return "ok" if parts.is_empty() else "OUTLIER %s" % "; ".join(parts)


func _validate_independent_corridor_summary(dataset: Dictionary) -> void:
	var actual_by_key := {}
	for entry_value in (dataset.get("outliers", {}) as Dictionary).get("class_corridor_80_120", []):
		var entry: Dictionary = entry_value
		actual_by_key[str(entry.get("key", ""))] = entry
	var expected_count := 0
	for row_value in dataset.get("class_rows", []):
		var row: Dictionary = row_value
		var axes := _independent_corridor_axes(row)
		if axes.is_empty():
			continue
		expected_count += 1
		var entry: Dictionary = actual_by_key.get(str(row.get("key", "")), {})
		_check(not entry.is_empty(), "outlier summary misses %s" % row.get("key", "?"))
		if entry.is_empty():
			continue
		_check(entry.get("axes", []) == axes, "outlier summary axes differ for %s" % row.get("key", "?"))
		_check(is_equal_approx(float(entry.get("solo_vs_median", INF)), float(row.get("solo_score", 0.0))), "outlier summary solo ratio differs for %s" % row.get("key", "?"))
		_check(is_equal_approx(float(entry.get("crowd_vs_median", INF)), float(row.get("aoe_score", 0.0))), "outlier summary crowd ratio differs for %s" % row.get("key", "?"))
		_check(is_equal_approx(float(entry.get("defense_vs_median", INF)), float(row.get("defense_score", 0.0))), "outlier summary defense ratio differs for %s" % row.get("key", "?"))
	_check(actual_by_key.size() == expected_count, "outlier summary contains unexpected or duplicate rows")


func _validate_independent_live_verdicts(dataset: Dictionary) -> void:
	var formula_rows := {}
	for weapon_row_value in dataset.get("weapon_rows", []):
		var weapon_row: Dictionary = weapon_row_value
		if int(weapon_row.get("level", 0)) == 20 and str(weapon_row.get("scenario", "")) == "class_constellation":
			formula_rows["%s/%s" % [weapon_row.get("class_id", ""), weapon_row.get("weapon_id", "")]] = weapon_row
	var parity_by_pair := {}
	var expected_outliers := {}
	for parity_value in dataset.get("formula_live_parity", []):
		var parity: Dictionary = parity_value
		var pair := str(parity.get("pair", ""))
		parity_by_pair[pair] = parity
		var formula: Dictionary = formula_rows.get(pair, {})
		_check(not formula.is_empty(), "live parity has no formula row for %s" % pair)
		if formula.is_empty():
			continue
		_check(is_equal_approx(float(parity.get("formula_solo_dpm", INF)), float(formula.get("solo_dpm", 0.0))), "%s formula solo value differs from L20 class-constellation row" % pair)
		_check(is_equal_approx(float(parity.get("formula_pack_dpm", INF)), float(formula.get("crowd_10_total_dpm", 0.0))), "%s formula pack value differs from L20 class-constellation row" % pair)
		for probe in [{"samples": "solo_samples_dpm", "mean": "live_solo_dpm_mean", "stddev": "live_solo_dpm_stddev", "formula": "formula_solo_dpm", "delta": "solo_delta_pct"}, {"samples": "pack_samples_dpm", "mean": "live_pack_dpm_mean", "stddev": "live_pack_dpm_stddev", "formula": "formula_pack_dpm", "delta": "pack_delta_pct"}]:
			var samples: Array = parity.get(str(probe["samples"]), [])
			var mean := _independent_number_mean(samples)
			_check(is_equal_approx(float(parity.get(str(probe["mean"]), INF)), snappedf(mean, 0.01)), "%s %s mean differs from recorded samples" % [pair, probe["samples"]])
			_check(is_equal_approx(float(parity.get(str(probe["stddev"]), INF)), snappedf(_independent_stddev(samples, mean), 0.01)), "%s %s stddev differs from recorded samples" % [pair, probe["samples"]])
			var expected_delta := snappedf((mean - float(parity.get(str(probe["formula"]), 0.0))) / maxf(float(parity.get(str(probe["formula"]), 0.0)), 0.001) * 100.0, 0.01)
			_check(is_equal_approx(float(parity.get(str(probe["delta"]), INF)), expected_delta), "%s %s delta differs from independent formula/live arithmetic" % [pair, probe["samples"]])
		if absf(float(parity.get("solo_delta_pct", 0.0))) > 35.0 or absf(float(parity.get("pack_delta_pct", 0.0))) > 35.0:
			expected_outliers[pair] = true
	var actual_outliers := {}
	for entry_value in (dataset.get("outliers", {}) as Dictionary).get("formula_live_delta_over_35pct", []):
		actual_outliers[str((entry_value as Dictionary).get("pair", ""))] = true
	_check(actual_outliers == expected_outliers, "formula/live outlier verdict set differs from independent tolerance arithmetic")
	var final_by_pair := {}
	for final_value in ((dataset.get("final_execution", {}) as Dictionary).get("rows", [])):
		var final_row: Dictionary = final_value
		final_by_pair[str(final_row.get("pair", ""))] = final_row
	var dispositions: Array = ((dataset.get("formula_live_dispositions", {}) as Dictionary).get("rows", []))
	_check(dispositions.size() == parity_by_pair.size(), "formula/live verdict coverage differs from parity roster")
	for disposition_value in dispositions:
		var disposition: Dictionary = disposition_value
		var pair := str(disposition.get("pair", ""))
		var parity: Dictionary = parity_by_pair.get(pair, {})
		var final_row: Dictionary = final_by_pair.get(pair, {})
		_check(not parity.is_empty() and not final_row.is_empty(), "formula/live verdict has no parity/final evidence for %s" % pair)
		if parity.is_empty() or final_row.is_empty():
			continue
		var expected_verdict := _independent_disposition_verdict(parity, final_row, disposition)
		_check(str(disposition.get("disposition", "")) == expected_verdict, "%s formula/live verdict differs from independently reconstructed evidence" % pair)
		_check(expected_verdict != "unresolved", "%s unresolved formula/live verdict must fail certification" % pair)
		var payoff: Dictionary = final_row.get("payoff", {})
		var evidence: Dictionary = disposition.get("final_execution", {})
		var expected_share := snappedf(100.0 * float(payoff.get("provenance_bound_damage", 0.0)) / maxf(float(payoff.get("applied_hp_total", 0.0)), 0.0001), 0.01)
		_check(is_equal_approx(float(evidence.get("resolver_bound_payoff_share_pct", INF)), expected_share), "%s resolver payoff share differs from final raw evidence" % pair)
		_check(str(evidence.get("payoff_kind", "")) == str(payoff.get("kind", "")), "%s disposition payoff kind differs from final raw evidence" % pair)


func _independent_number_mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += float(value)
	return total / float(values.size())


func _independent_stddev(values: Array, mean: float) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += pow(float(value) - mean, 2.0)
	return sqrt(total / float(values.size()))


func _independent_disposition_verdict(parity: Dictionary, final_row: Dictionary, disposition: Dictionary) -> String:
	if absf(float(parity.get("solo_delta_pct", 0.0))) <= 35.0 and absf(float(parity.get("pack_delta_pct", 0.0))) <= 35.0:
		return "within_tolerance"
	var payoff: Dictionary = final_row.get("payoff", {})
	var axes: Dictionary = disposition.get("axes", {})
	return "explained_divergence" if str(payoff.get("kind", "")) != "" and not (axes.get("solo", {}) as Dictionary).is_empty() and not (axes.get("pack", {}) as Dictionary).is_empty() else "unresolved"


func _validate_independent_markdown_projection(dataset: Dictionary, report_text: String) -> void:
	var source: Dictionary = dataset.get("source", {})
	var supplemental: Dictionary = dataset.get("supplemental_execution", {})
	_check(report_text.contains("Source commit `%s` (tree `%s`, timestamp `%s`)" % [source.get("commit", ""), source.get("tree", ""), source.get("commit_timestamp", "")]), "Markdown raw source provenance differs from independent projection")
	_check(report_text.contains("Supplemental final-execution source commit `%s` (tree `%s`, timestamp `%s`)" % [supplemental.get("commit", ""), supplemental.get("tree", ""), supplemental.get("commit_timestamp", "")]), "Markdown supplemental provenance differs from independent projection")
	for row_value in dataset.get("class_rows", []):
		var row: Dictionary = row_value
		var line := "| %s | %d | %s | %s | %.3f | %.3f | %.3f | %.3f | %.2f | %s | %s | %s |" % [row["class_id"], row["level"], row["scenario"], "; ".join(row["roles"]), row["solo_score"], row["aoe_score"], row["defense_score"], row["convenience_relative"], row["first_minute_ultimate_damage"], row["strengths"], row["weaknesses"], row["outlier_flag"]]
		_check(report_text.contains(line), "Markdown class aggregate differs from raw row %s" % row.get("key", "?"))
	for row_value in dataset.get("weapon_rows", []):
		var row: Dictionary = row_value
		var line := "| %s/%s | %d | %s | %s | %s | %s | %s / %s / %s | %s | %.2f (%+.2f%%) | %.2f / %.2f (%+.2f%%) | %.2f / %.2f / %.2f | %.4f / %.4f / %.2f / %.2f | %.2f / %.2f | %.2f / %.2f | %s | %d / %.2f;%.2f |" % [row["class_id"], row["weapon_id"], row["level"], row["scenario_label"], row["playstyle"], row["strengths"], row["weaknesses"], row["attack_mode"], row["axis"], row["final_mechanic"], _independent_delta_text(row["stat_delta"]), row["solo_dpm"], row["solo_dpm_delta_pct"], row["crowd_10_total_dpm"], row["crowd_10_per_target_dpm"], row["crowd_10_total_dpm_delta_pct"], row["hp"], row["ehp"], row["ttd_seconds"], row["mitigation"], row["dodge"], row["absorb_flat"], row["conditional_shield_capacity"], row["regeneration_per_second"], row["lifesteal_per_second"], row["pickup_radius"], row["move_speed"], row["atlas_delta_summary"], row["runs"], row["solo_variance_dpm2"], row["crowd_variance_dpm2"]]
		_check(report_text.contains(line), "Markdown weapon matrix differs from raw row %s" % row.get("key", "?"))
	var dispositions := {}
	for disposition_value in ((dataset.get("formula_live_dispositions", {}) as Dictionary).get("rows", [])):
		var disposition: Dictionary = disposition_value
		dispositions[str(disposition.get("pair", ""))] = disposition
	for parity_value in dataset.get("formula_live_parity", []):
		var parity: Dictionary = parity_value
		var disposition: Dictionary = dispositions.get(str(parity.get("pair", "")), {})
		var line := "| %s | %s | %s (%s) | %.2f / %.2f±%.2f | %+.2f%% | %.2f / %.2f±%.2f | %+.2f%% | %s | %s |" % [parity["pair"], parity["attack_mode"], parity["final_mechanic"], parity["final_event"], parity["formula_solo_dpm"], parity["live_solo_dpm_mean"], parity["live_solo_dpm_stddev"], parity["solo_delta_pct"], parity["formula_pack_dpm"], parity["live_pack_dpm_mean"], parity["live_pack_dpm_stddev"], parity["pack_delta_pct"], disposition.get("disposition", ""), parity["runtime_observation"]]
		_check(report_text.contains(line), "Markdown formula/live row differs from raw pair %s" % parity.get("pair", "?"))
	for final_value in ((dataset.get("final_execution", {}) as Dictionary).get("rows", [])):
		var final_row: Dictionary = final_value
		var payoff: Dictionary = final_row.get("payoff", {})
		var sample: Dictionary = final_row.get("telemetry", {})
		var line := "| %s | %s (%s) | `%s` | %s | %d → %d | %d | %s | %s | %.2f | `%s` |" % [final_row.get("pair", ""), final_row.get("final_mechanic", ""), final_row.get("final_event", ""), (final_row.get("consumer", {}) as Dictionary).get("runtime_consumer", ""), (final_row.get("stimulus", {}) as Dictionary).get("kind", ""), (final_row.get("resolution_ladder", []) as Array).size(), int(payoff.get("activation_count", 0)), int(final_row.get("required_progress", 0)), payoff.get("kind", "unobserved"), payoff.get("binding", ""), float(payoff.get("applied_hp_total", 0.0)), sample.get("trace_id", "")]
		_check(report_text.contains(line), "Markdown final-execution row differs from raw pair %s" % final_row.get("pair", "?"))
	for disposition_value in dispositions.values():
		var disposition: Dictionary = disposition_value
		var solo_axis: Dictionary = (disposition.get("axes", {}) as Dictionary).get("solo", {})
		var pack_axis: Dictionary = (disposition.get("axes", {}) as Dictionary).get("pack", {})
		var line := "| %s | %s | %s | %+.2f%% (%s %+.2f%%) | %+.2f%% (%s %+.2f%%) | %s |" % [disposition.get("pair", ""), disposition.get("disposition", ""), (disposition.get("final_execution", {}) as Dictionary).get("payoff_kind", ""), float(solo_axis.get("recomputed_delta_pct", 0.0)), solo_axis.get("dominant_factor", ""), float(solo_axis.get("dominant_factor_deviation_pct", 0.0)), float(pack_axis.get("recomputed_delta_pct", 0.0)), pack_axis.get("dominant_factor", ""), float(pack_axis.get("dominant_factor_deviation_pct", 0.0)), disposition.get("explanation", "")]
		_check(report_text.contains(line), "Markdown disposition differs from raw pair %s" % disposition.get("pair", "?"))
	_check(report_text.contains("- Class corridor flags (outside 80–120%% of the same level/scenario median across solo, AoE, or defense): **%d**." % ((dataset.get("outliers", {}) as Dictionary).get("class_corridor_80_120", []) as Array).size()), "Markdown corridor count differs from raw outliers")


func _independent_delta_text(delta: Dictionary) -> String:
	if delta.is_empty():
		return "base"
	var parts := PackedStringArray()
	var keys := delta.keys()
	keys.sort()
	for key_value in keys:
		parts.append("%s+%d" % [key_value, int(delta[key_value])])
	return "; ".join(parts)


func _validate_named_artifact_corruptions(dataset: Dictionary, report_text: String) -> void:
	var digest_mutation := dataset.duplicate(true)
	digest_mutation["issue_id"] = "FAN-1510"
	_check(_independent_dataset_digest(digest_mutation) != str(dataset.get("dataset_digest_sha256", "")), "named raw payload mutation must fail the independent digest")
	var source_mutation := (dataset.get("supplemental_execution", {}) as Dictionary).duplicate(true)
	source_mutation["tree"] = "0".repeat(40)
	_check(not _independent_source_matches_git(source_mutation), "named supplemental provenance mutation must fail closed")
	var csv_text := _independent_render_csv(dataset)
	var csv_mutation := csv_text.replace("\"berserk|sword|1|no_meta\"", "\"forged|sword|1|no_meta\"")
	_check(csv_mutation != csv_text, "named CSV key corruption fixture did not mutate")
	_check(csv_mutation != _independent_render_csv(dataset), "named CSV key corruption must fail the independent projection")
	var markdown_mutation := report_text.replace("Dataset digest: `%s`" % dataset.get("dataset_digest_sha256", ""), "Dataset digest: `%s`" % "0".repeat(64))
	_check(not markdown_mutation.contains("Dataset digest: `%s`" % dataset.get("dataset_digest_sha256", "")), "named Markdown digest corruption must fail the independent projection")
	var first_weapon: Dictionary = (dataset.get("weapon_rows", []) as Array)[0]
	var baseline_key := "%s|%s|%d" % [first_weapon.get("class_id", ""), first_weapon.get("weapon_id", ""), int(first_weapon.get("level", 0))]
	_check(is_equal_approx(float(first_weapon.get("solo_dpm_delta_abs", INF)), snappedf(float(first_weapon.get("solo_dpm", 0.0)) - float(first_weapon.get("solo_dpm", 0.0)), 0.01)), "unchanged baseline delta must remain green")
	var delta_mutation := first_weapon.duplicate(true)
	delta_mutation["solo_dpm_delta_abs"] = float(delta_mutation.get("solo_dpm_delta_abs", 0.0)) + 1.0
	_check(not is_equal_approx(float(delta_mutation.get("solo_dpm_delta_abs", INF)), snappedf(float(delta_mutation.get("solo_dpm", 0.0)) - float(first_weapon.get("solo_dpm", 0.0)), 0.01)), "named derived delta mutation must fail independent baseline arithmetic for %s" % baseline_key)
	var first_disposition: Dictionary = (((dataset.get("formula_live_dispositions", {}) as Dictionary).get("rows", []) as Array)[0] as Dictionary)
	var parity_by_pair := {}
	for parity_value in dataset.get("formula_live_parity", []):
		var parity: Dictionary = parity_value
		parity_by_pair[str(parity.get("pair", ""))] = parity
	var final_by_pair := {}
	for final_value in ((dataset.get("final_execution", {}) as Dictionary).get("rows", [])):
		var final_row: Dictionary = final_value
		final_by_pair[str(final_row.get("pair", ""))] = final_row
	var expected_verdict := _independent_disposition_verdict(parity_by_pair.get(str(first_disposition.get("pair", "")), {}), final_by_pair.get(str(first_disposition.get("pair", "")), {}), first_disposition)
	var verdict_mutation := first_disposition.duplicate(true)
	verdict_mutation["disposition"] = "unresolved" if expected_verdict != "unresolved" else "within_tolerance"
	_check(str(verdict_mutation.get("disposition", "")) != expected_verdict, "named derived verdict mutation must fail independent disposition arithmetic")


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var result := file.get_as_text()
	file.close()
	return result


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _finish() -> void:
	if not _errors.is_empty():
		for error in _errors:
			push_error(error)
		push_error("FAN-1438 A5 balance report integrity test failed (%d errors)." % _errors.size())
		quit(1)
		return
	print("FAN-1438 A5 report integrity passed dynamic roster, 19-point builds, 50/59 Atlas legality, 408-row matrix, class kits, live mechanic coverage, and CSV/Markdown evidence.")
	quit(0)

# FAN-2319: the censer counter uses nearest-target/capped-AoE production paths,
# so the A5 fixture must never leave rank order to a group traversal tie.
func _validate_censer_final_execution_fixture() -> void:
	var expected := Generator._expected_final_for_pair("priest/priest_censer")
	var profile := Generator.final_execution_profile(expected)
	_check(str(profile.get("layout", "")) == "staggered_pack", "censer final-execution fixture must use deterministic staggered geometry")
	_check(Generator.final_execution_incoming_interval(profile) == Generator.FINAL_EXECUTION_CENSER_PRESSURE_INTERVAL_FRAMES, "censer final-execution fixture must keep pressure outside the real-clock cooldown")
	var distances := {}
	for index in range(int(profile.get("target_count", 0))):
		var position := Generator.final_execution_target_position(profile, index)
		var distance := "%.6f" % Generator.PLAYER_POSITION.distance_squared_to(position)
		_check(not distances.has(distance), "censer final-execution fixture repeats a target rank distance")
		distances[distance] = true
	_check(distances.size() == int(profile.get("target_count", 0)), "censer final-execution fixture must retain every target")
