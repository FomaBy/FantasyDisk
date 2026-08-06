extends SceneTree

# FAN-1551 / FAN-1641: f09 remains the executable numeric oracle. This compact
# digest covers the ordered 51-key manifest and all four live projection fields
# exactly as rendered. FAN-1641 makes the numeric/event parity contract
# lineage-aware and fail-closed: the historical f09 51x4 oracle is preserved
# unchanged, the three accepted druid/summon_amulet deltas from independently
# QA-passed FAN-1585/FAN-1596 summon geometry are encoded exactly, and a
# materialization candidate must show exact zero gameplay/event delta against its
# immediate current integration base.
const Generator := preload("res://tools/a5_balance_report.gd")
const F09_ORACLE_PROJECTION_SHA256 := "d81092333cdf6e3f4196b8c5ee9198e83ccef8bfe7530a8ef20f911a54d5efd1"
# FAN-1641: the current integration base (3f3788fd, FAN-1575) 51x4 digest is pinned here as
# an EXTERNAL constant, exactly like the f09 oracle above. This anchors the whole
# accepted-delta set: a self-consistent manifest tamper (drop/add/alter a delta and
# recompute its own counts + current sha) still changes the reconstructed digest,
# which then diverges from this committed constant and fails closed.
const CURRENT_BASE_PROJECTION_SHA256 := "a85a35d0430d5d520c2b0643870b762dff9285f00ae0b2b214b3ff96d01ef7cb"
# FAN-1649: external pin of the current integration-base (3f3788fd, FAN-1575) FULL canonical
# telemetry payload aggregate over the 309 per-sample digests. Like the projection
# constant above, it anchors the whole pinned map: a self-consistent manifest tamper
# (rewrite one sample digest AND recompute its own aggregate) still diverges from
# this committed constant and fails closed. The value is reproduced by two clean
# byte-identical current-base runs through Generator.canonical_full_telemetry (see docs).
const CURRENT_BASE_TELEMETRY_FULL_SHA256 := "c269edb122252e4ac35a46e24b531c26affcb071b69e1e20fe428b17c943b72a"
const LIVE_TELEMETRY_SCHEMA := "fan1511.runtime-telemetry.v2"

var _errors := PackedStringArray()


func _initialize() -> void:
	var raw_artifact := Generator.read_raw_artifact()
	_check(bool(raw_artifact.get("ok", false)), "immutable f09 A5 oracle must decode before parity verification")
	var raw_text := str(raw_artifact.get("text", ""))
	var dataset = JSON.parse_string(raw_text)
	_check(dataset is Dictionary, "immutable f09 A5 oracle must parse before parity verification")
	if dataset is Dictionary:
		_verify_historical_oracle(dataset as Dictionary)
		_verify_lineage_contract(dataset as Dictionary, raw_text)
		_verify_full_telemetry_contract(dataset as Dictionary)
		_verify_projection_duplicate_predicate(dataset as Dictionary)
		_verify_repeat_run_regression(dataset as Dictionary)
	_finish()


# FAN-1681: automatic regression on the original FAN-1672 symptom — a second
# consecutive `--mode=full` in the same checkout. A successful run rewrites
# docs/design/reports/fan1438_a5_balance/raw.json.gz with the CURRENT-BASE values, so
# the next run hands the gate exactly that artifact. Before FAN-1672 the gate took its
# historical baseline from that same file, so run 2 read the accepted `to` values as if
# they were the historical `from` values and failed closed. A real `--mode=full` costs
# ~12 minutes, so this works at the `verify_candidate_projection_against_current_base`
# level with the poisoned artifact a successful run leaves behind.
func _verify_repeat_run_regression(historical: Dictionary) -> void:
	var loaded := Generator.load_oracle_lineage()
	if not bool(loaded.get("ok", false)):
		_check(false, "oracle lineage manifest must load for the repeat-run regression")
		return
	var manifest: Dictionary = loaded.get("manifest", {})
	# Exactly what a successful --mode=full writes back to disk: f09 + accepted deltas.
	var regenerated := _candidate_with_accepted_deltas(historical, manifest)
	var regenerated_cells := Generator.projection_cell_map(regenerated)
	_check(bool(regenerated_cells.get("ok", false)), "the regenerated artifact must expose a valid projection")
	if not bool(regenerated_cells.get("ok", false)):
		return
	var cells: Dictionary = regenerated_cells.get("cells", {})
	var carries_current_base := false
	for delta_value in manifest.get("accepted_projection_deltas", []):
		var delta: Dictionary = delta_value
		var key := "%s|%s" % [str(delta.get("pair", "")), str(delta.get("field", ""))]
		if str(cells.get(key, "")) == "%.2f" % float(delta.get("to", NAN)):
			carries_current_base = true
		_check(str(cells.get(key, "")) != "%.2f" % float(delta.get("from", NAN)), "the regenerated artifact must no longer carry the historical 'from' value for %s" % key)
	_check(carries_current_base, "the regenerated artifact must carry the accepted current-base values")

	# 1. The pre-FAN-1672 baseline source reproduces the defect exactly: sourcing the
	#    historical oracle from the regenerated artifact makes the accepted 'from'
	#    values unmatchable, which is the non-zero run-2 exit FAN-1660 reported.
	var artifact_baseline := Generator._lineage_current_cells(manifest, regenerated)
	_check(not bool(artifact_baseline.get("ok", true)), "the pre-FAN-1672 artifact-sourced baseline must fail closed on a regenerated artifact")
	_check("; ".join(artifact_baseline.get("errors", [])).contains("does not match historical oracle"), "the reproduced FAN-1672 failure must cite the accepted-delta 'from' mismatch")

	# 2. The shipped baseline comes from the committed manifest, so the very same
	#    regenerated artifact leaves it untouched: still the immutable f09 51x4 matrix.
	var manifest_baseline := Generator.historical_oracle_cells(manifest)
	_check(bool(manifest_baseline.get("ok", false)), "the manifest-anchored baseline must stay valid while a current-base artifact is present")
	_check(str(manifest_baseline.get("digest", "")) == F09_ORACLE_PROJECTION_SHA256, "the manifest-anchored baseline must stay the immutable f09 oracle")

	# 3. Therefore the gate accepts the regenerated artifact, and keeps accepting it on
	#    every repeat: consecutive --mode=full runs no longer poison each other.
	for attempt in range(2):
		var repeat_gate := Generator.verify_candidate_projection_against_current_base(regenerated, manifest)
		_check(bool(repeat_gate.get("ok", false)), "consecutive run %d over a regenerated current-base artifact must pass the candidate gate: %s" % [attempt + 1, "; ".join(repeat_gate.get("errors", []))])


# FAN-1551: the historical f09 oracle is preserved exactly, including fail-closed
# behaviour on a 0.01 DPM mutation.
func _verify_historical_oracle(dataset: Dictionary) -> void:
	var oracle := Generator.projection_oracle_digest(dataset)
	_check(bool(oracle.get("ok", false)), "51x4 projection manifest is invalid: %s" % oracle.get("error", "unknown"))
	if not bool(oracle.get("ok", false)):
		return
	_check(str(oracle.get("digest", "")) == F09_ORACLE_PROJECTION_SHA256, "51x4 exact projection differs from executable f09 oracle")
	var mutated := dataset.duplicate(true)
	var rows: Array = mutated.get("weapon_rows", [])
	for row_value in rows:
		var row: Dictionary = row_value
		if int(row.get("level", 0)) == 20 and str(row.get("scenario", "")) == "class_constellation":
			row["live_solo_dpm_mean"] = float(row.get("live_solo_dpm_mean", 0.0)) + 0.01
			break
	var mutation_oracle := Generator.projection_oracle_digest(mutated)
	_check(str(mutation_oracle.get("digest", "")) != F09_ORACLE_PROJECTION_SHA256, "projection oracle must fail closed on a 0.01 DPM mutation")


# FAN-1641: the lineage-aware, fail-closed replacement for the impossible literal
# "candidate vs f09/ec15444e all-zero" gate.
func _verify_lineage_contract(historical: Dictionary, raw_text: String) -> void:
	var loaded := Generator.load_oracle_lineage()
	_check(bool(loaded.get("ok", false)), "oracle lineage manifest must load: %s" % loaded.get("error", "unknown"))
	if not bool(loaded.get("ok", false)):
		return
	var manifest: Dictionary = loaded.get("manifest", {})

	# 1. Manifest is self-consistent with the immutable committed oracle: exact
	#    201/204 equal cells plus the three enumerated accepted druid deltas.
	var lineage := Generator.verify_oracle_lineage(manifest, historical, raw_text)
	_check(bool(lineage.get("ok", false)), "oracle lineage manifest is inconsistent: %s" % "; ".join(lineage.get("errors", [])))
	# The reconstructed current digest (f09 oracle + accepted deltas) AND the
	# manifest's own pinned value must both equal the external committed constant.
	_check(str(lineage.get("current_digest", "")) == CURRENT_BASE_PROJECTION_SHA256, "reconstructed current digest differs from the externally pinned current base")
	_check(str((manifest.get("current_integration_base", {}) as Dictionary).get("projection_sha256", "")) == CURRENT_BASE_PROJECTION_SHA256, "manifest current-base digest differs from the externally pinned current base")

	# 2. Git-backed commit-level causality: pinned trees, the linear
	#    f09 -> ec15444e -> current chain, the exact inventory, and summon files.
	var ancestry := Generator.verify_oracle_lineage_ancestry(manifest)
	_check(bool(ancestry.get("ok", false)), "oracle lineage ancestry failed: %s" % "; ".join(ancestry.get("errors", [])))

	# 3. A faithful f09+accepted-deltas candidate matches the reconstructed
	#    current-base PROJECTION (51x4 + 309 sample-key set)...
	var candidate := _candidate_with_accepted_deltas(historical, manifest)
	var projection_ok := Generator.verify_candidate_projection_against_current_base(candidate, manifest)
	_check(bool(projection_ok.get("ok", false)), "faithful current-base projection candidate must pass the projection gate: %s" % "; ".join(projection_ok.get("errors", [])))
	# ...but it still carries the OLDER f09 event contract (the six measurement-contract
	# commits between f09 and b8909e30 changed the event stream for every sample), so
	# the FAN-1649 full-payload gate now REJECTS it. This is exactly the FAN-1642 defect
	# the FAN-1641 keys-only gate missed: identical 309 keys, different payload.
	var combined := Generator.verify_candidate_against_current_base(candidate, manifest)
	_check(not bool(combined.get("ok", true)), "f09-telemetry candidate must be rejected by the full-payload gate")
	_check("; ".join(combined.get("errors", [])).contains("telemetry sample"), "full-payload rejection must cite a telemetry payload difference")

	# 4. Negative projection mutations must all fail the projection gate.
	# extra projection-cell delta on an unrelated pair.
	_expect_projection_failure(_mutate_projection_cell(candidate, "assassin", "chakrams", "live_solo_dpm_mean", 0.01), manifest, "extra projection-cell delta must fail closed")
	# changed accepted value.
	_expect_projection_failure(_mutate_projection_cell(candidate, "druid", "summon_amulet", "live_crowd_dpm_mean", 0.01), manifest, "changed accepted value must fail closed")
	# false current-base zero: an unpatched f09 candidate is NOT the current base.
	_expect_projection_failure(historical.duplicate(true), manifest, "false current-base zero (candidate == historical f09) must fail closed")

	# FAN-1672: the candidate projection gate must take its historical baseline from
	# the COMMITTED manifest, not from the generated raw artifact the same --mode=full
	# run rewrites on success. Reading that artifact made the gate consume its own
	# output: run 1 on a checkout passed, run 2 failed closed because the accepted
	# druid 'from' values had already been replaced by their accepted 'to' values.
	var manifest_cells := Generator.historical_oracle_cells(manifest)
	_check(bool(manifest_cells.get("ok", false)), "manifest-anchored historical matrix must resolve: %s" % "; ".join(manifest_cells.get("errors", [])))
	_check(str(manifest_cells.get("digest", "")) == F09_ORACLE_PROJECTION_SHA256, "manifest-anchored historical matrix must reproduce the externally pinned f09 oracle digest")
	# A tampered published matrix must fail closed instead of silently becoming the new
	# baseline, so the manifest cannot substitute an alternative historical oracle.
	var tampered_matrix := manifest.duplicate(true)
	var published: Array = (tampered_matrix.get("historical_oracle", {}) as Dictionary).get("published_matrix", [])
	if published.size() > 0:
		(published[0] as Dictionary)["live_solo_dpm_mean"] = float((published[0] as Dictionary).get("live_solo_dpm_mean", 0.0)) + 0.01
	_check(not bool(Generator.historical_oracle_cells(tampered_matrix).get("ok", true)), "tampered published historical matrix must fail the immutable historical anchor")
	_expect_projection_failure(candidate, tampered_matrix, "tampered published historical matrix must fail the candidate projection gate")
	# A manifest that re-pins its own current-base digest still has to reproduce the
	# immutable runtime anchor, so the candidate gate stays closed.
	var repinned_current := manifest.duplicate(true)
	(repinned_current.get("current_integration_base", {}) as Dictionary)["projection_sha256"] = F09_ORACLE_PROJECTION_SHA256
	_expect_projection_failure(candidate, repinned_current, "re-pinned current-base projection digest must fail the candidate projection gate")

	# missing lineage entry: drop one accepted delta from the manifest.
	var missing_entry := manifest.duplicate(true)
	var deltas: Array = missing_entry.get("accepted_projection_deltas", [])
	if deltas.size() > 0:
		deltas.remove_at(deltas.size() - 1)
	_check(not bool(Generator.verify_oracle_lineage(missing_entry, historical, raw_text).get("ok", true)), "missing accepted-delta entry must fail the manifest consistency gate")
	_check(not bool(Generator.verify_candidate_projection_against_current_base(candidate, missing_entry).get("ok", true)), "missing accepted-delta entry must fail the candidate projection gate")

	# substituted oracle: mutate the historical dataset the manifest is pinned to.
	var substituted := historical.duplicate(true)
	for row_value in substituted.get("weapon_rows", []):
		var row: Dictionary = row_value
		if int(row.get("level", 0)) == 20 and str(row.get("scenario", "")) == "class_constellation" and str(row.get("class_id", "")) == "druid" and str(row.get("weapon_id", "")) == "summon_amulet":
			row["live_solo_dpm_mean"] = float(row.get("live_solo_dpm_mean", 0.0)) + 1.0
			break
	_check(not bool(Generator.verify_oracle_lineage(manifest, substituted, raw_text).get("ok", true)), "substituted oracle must fail the manifest consistency gate")

	# substituted commit/tree pin.
	var wrong_tree := manifest.duplicate(true)
	(wrong_tree.get("current_integration_base", {}) as Dictionary)["tree"] = "0000000000000000000000000000000000000000"
	_check(not bool(Generator.verify_oracle_lineage_ancestry(wrong_tree).get("ok", true)), "substituted current-base tree must fail the git ancestry gate")

	# substituted decoded raw text.
	_check(not bool(Generator.verify_oracle_lineage(manifest, historical, raw_text + " ").get("ok", true)), "substituted decoded raw text must fail the manifest consistency gate")

	# self-consistent tamper: drop an accepted delta AND re-pin the manifest's own
	# counts + current sha to the reduced reconstruction. It stays INTERNALLY
	# consistent, but its reconstructed digest must diverge from the external
	# current-base constant, which is what fails it closed.
	var self_consistent := manifest.duplicate(true)
	var sc_deltas: Array = self_consistent.get("accepted_projection_deltas", [])
	if sc_deltas.size() > 0:
		sc_deltas.remove_at(sc_deltas.size() - 1)
	self_consistent["changed_cell_count"] = int(self_consistent.get("changed_cell_count", 3)) - 1
	self_consistent["equal_cell_count"] = int(self_consistent.get("equal_cell_count", 201)) + 1
	var sc_digest := str(Generator.verify_oracle_lineage(self_consistent, historical, raw_text).get("current_digest", ""))
	(self_consistent.get("current_integration_base", {}) as Dictionary)["projection_sha256"] = sc_digest
	var sc_final := Generator.verify_oracle_lineage(self_consistent, historical, raw_text)
	_check(bool(sc_final.get("ok", false)), "reduced manifest should be internally self-consistent")
	_check(str(sc_final.get("current_digest", "")) != CURRENT_BASE_PROJECTION_SHA256, "self-consistent manifest tamper must diverge from the external current-base constant")

	# FAN-1681: isolate PROJECTION_ANCHOR_CURRENT_SHA256 itself. The `repinned_current`
	# negative above only moves the manifest's pin, so the RECONSTRUCTED base digest
	# still equals the runtime constant and the rejection comes from the pre-FAN-1672
	# "differs from the manifest current base" comparison — delete the constant and that
	# negative still passes. Here the manifest AND the candidate are moved together onto
	# the reduced lineage: the manifest drops one accepted delta and re-pins its own
	# counts and current sha, and the candidate materialises exactly that reduced base.
	# Every caller-owned comparison now agrees with itself, so the only thing left that
	# can reject the pair is the immutable runtime constant.
	var sc_candidate := _candidate_with_accepted_deltas(historical, self_consistent)
	var sc_gate := Generator.verify_candidate_projection_against_current_base(sc_candidate, self_consistent)
	_check(not bool(sc_gate.get("ok", true)), "self-consistent reduced lineage + matching candidate must fail the candidate projection gate")
	var sc_gate_errors: Array = sc_gate.get("errors", [])
	_check(not sc_gate_errors.is_empty(), "reduced-lineage rejection must report a reason")
	for error_value in sc_gate_errors:
		_check(str(error_value).contains("immutable current anchor"), "reduced-lineage rejection must come only from PROJECTION_ANCHOR_CURRENT_SHA256, got: %s" % str(error_value))

	# FAN-1709: isolate TELEMETRY_ANCHOR_SAMPLE_KEYS_SHA256 itself (the FAN-1681
	# deferred item). One telemetry sample of the faithful candidate is renamed —
	# the key COUNT stays 309, the projection cells are untouched — and the manifest
	# re-pins historical_oracle.telemetry_sample_key_count and
	# telemetry_sample_keys_sha256 consistently with that mutated key set, so every
	# caller-owned comparison agrees with itself. The only check left that can
	# reject the pair is the immutable sample-keys runtime anchor.
	var rekeyed := candidate.duplicate(true)
	var rekeyed_samples: Array = (rekeyed.get("live_telemetry", {}) as Dictionary).get("samples", [])
	_check(not rekeyed_samples.is_empty(), "sample-keys tamper must find live telemetry samples")
	if not rekeyed_samples.is_empty():
		var rekeyed_sample: Dictionary = rekeyed_samples[0]
		rekeyed_sample["sample_key"] = str(rekeyed_sample.get("sample_key", "")) + ":forged"
		var rekeyed_keys := Generator.telemetry_sample_keys_digest(rekeyed)
		_check(bool(rekeyed_keys.get("ok", false)), "mutated sample-key set must still digest cleanly")
		_check(int(rekeyed_keys.get("count", -1)) == 309, "sample-keys tamper must preserve the 309-key cardinality so only the digest anchor can discriminate")
		var rekeyed_manifest := manifest.duplicate(true)
		var rekeyed_oracle: Dictionary = rekeyed_manifest.get("historical_oracle", {})
		rekeyed_oracle["telemetry_sample_key_count"] = int(rekeyed_keys.get("count", -1))
		rekeyed_oracle["telemetry_sample_keys_sha256"] = str(rekeyed_keys.get("digest", ""))
		var rekeyed_gate := Generator.verify_candidate_projection_against_current_base(rekeyed, rekeyed_manifest)
		_check(not bool(rekeyed_gate.get("ok", true)), "self-consistent sample-keys re-pin + matching candidate must fail the candidate projection gate")
		var rekeyed_errors: Array = rekeyed_gate.get("errors", [])
		_check(not rekeyed_errors.is_empty(), "sample-keys re-pin rejection must report a reason")
		for error_value in rekeyed_errors:
			_check(str(error_value).contains("immutable sample-keys anchor"), "sample-keys re-pin rejection must come only from TELEMETRY_ANCHOR_SAMPLE_KEYS_SHA256, got: %s" % str(error_value))


func _candidate_with_accepted_deltas(historical: Dictionary, manifest: Dictionary) -> Dictionary:
	var candidate := historical.duplicate(true)
	var deltas: Array = manifest.get("accepted_projection_deltas", [])
	for row_value in candidate.get("weapon_rows", []):
		var row: Dictionary = row_value
		if int(row.get("level", 0)) != 20 or str(row.get("scenario", "")) != "class_constellation":
			continue
		var pair := "%s/%s" % [str(row.get("class_id", "")), str(row.get("weapon_id", ""))]
		for delta_value in deltas:
			var delta: Dictionary = delta_value
			if str(delta.get("pair", "")) == pair:
				row[str(delta.get("field", ""))] = float(delta.get("to", 0.0))
	return candidate


func _mutate_projection_cell(candidate: Dictionary, class_id: String, weapon_id: String, field: String, amount: float) -> Dictionary:
	var mutated := candidate.duplicate(true)
	for row_value in mutated.get("weapon_rows", []):
		var row: Dictionary = row_value
		if int(row.get("level", 0)) == 20 and str(row.get("scenario", "")) == "class_constellation" and str(row.get("class_id", "")) == class_id and str(row.get("weapon_id", "")) == weapon_id:
			row[field] = float(row.get(field, 0.0)) + amount
			break
	return mutated


func _expect_projection_failure(candidate: Dictionary, manifest: Dictionary, message: String) -> void:
	_check(not bool(Generator.verify_candidate_projection_against_current_base(candidate, manifest).get("ok", true)), message)


# FAN-1649/FAN-1658: the full canonical telemetry PAYLOAD contract. The current base
# is anchored by the IMMUTABLE runtime trust root inside the tool (anchor-base identity,
# 309 samples, aggregate constant). A faithful materialized map passes; a candidate +
# manifest pair that self-repins every controlled digest/aggregate still fails closed
# (FAN-1650); and every per-field payload mutation is detected.
func _verify_full_telemetry_contract(historical: Dictionary) -> void:
	var loaded := Generator.load_oracle_lineage()
	if not bool(loaded.get("ok", false)):
		_check(false, "oracle lineage manifest must load for the telemetry contract")
		return
	var manifest: Dictionary = loaded.get("manifest", {})
	var pinned: Dictionary = (manifest.get("current_integration_base", {}) as Dictionary).get("telemetry_full", {})

	# 1. The pinned current-base full-telemetry map is well formed and externally
	#    anchored: 309 samples, self-consistent aggregate == manifest full_sha256 ==
	#    external constant, and its key set equals the historical roster sample keys.
	_check(not pinned.is_empty(), "manifest must pin a current-base full telemetry payload")
	var pinned_digests: Dictionary = pinned.get("sample_digests", {})
	_check(int(pinned.get("sample_count", -1)) == 309, "pinned full telemetry must cover all 309 samples")
	_check(pinned_digests.size() == 309, "pinned full telemetry digest map must list all 309 samples")
	_check(str(pinned.get("telemetry_schema", "")) == LIVE_TELEMETRY_SCHEMA, "pinned full telemetry schema mismatch")
	var recomputed_aggregate := _aggregate_of(pinned_digests)
	_check(recomputed_aggregate == str(pinned.get("full_sha256", "")), "pinned full telemetry aggregate is internally inconsistent")
	_check(str(pinned.get("full_sha256", "")) == CURRENT_BASE_TELEMETRY_FULL_SHA256, "manifest full-telemetry digest differs from the externally pinned current base")
	# key set must equal the historical roster sample-key set (invariant f09<->current base).
	var historical_keys := {}
	for sample_value in (historical.get("live_telemetry", {}) as Dictionary).get("samples", []):
		historical_keys[str((sample_value as Dictionary).get("sample_key", ""))] = true
	var key_mismatch := historical_keys.size() != pinned_digests.size()
	for key in pinned_digests:
		if not historical_keys.has(str(key)):
			key_mismatch = true
	_check(not key_mismatch, "pinned full telemetry sample keys differ from the roster sample-key set")

	# 2. Self-consistent manifest/digest tamper: rewrite one pinned sample digest AND
	#    recompute the manifest's own aggregate. It stays internally consistent, but
	#    the recomputed aggregate diverges from the external committed constant.
	var tampered_digests := pinned_digests.duplicate(true)
	var first_key := ""
	for key in tampered_digests:
		first_key = str(key)
		break
	tampered_digests[first_key] = "0000000000000000000000000000000000000000000000000000000000000000"
	_check(_aggregate_of(tampered_digests) != CURRENT_BASE_TELEMETRY_FULL_SHA256, "self-consistent full-telemetry tamper must diverge from the external constant")

	# 2b. FAN-1658: the runtime gate anchors on immutable constants inside the tool, not
	#     on the caller/candidate-owned manifest. The real materialized current-base per-
	#     sample map (proven above: aggregate == the external committed constant) is a
	#     byte-identical materialization of the current base and passes the runtime
	#     anchor directly.
	var faithful_candidate := {"ok": true, "count": pinned_digests.size(), "sample_digests": pinned_digests.duplicate(true), "digest": _aggregate_of(pinned_digests)}
	_check(bool(Generator.verify_full_telemetry_against_anchor(faithful_candidate, pinned).get("ok", false)), "faithful materialized current-base telemetry map must pass the runtime anchor")

	# FAN-1650 self-repin reproduced on the REAL 309-sample materialized map: change one
	# per-sample digest (as an event-damage edit would) and self-repin EVERY candidate-
	# controlled field - the per-sample map AND the aggregate - AND the manifest's pinned
	# map + full_sha256. The candidate/manifest pair stays internally self-consistent, but
	# the runtime trust root is unchanged, so the gate must fail closed. This is the exact
	# fail-open FAN-1650 proved; the FAN-1649 synthetic gate could not catch it because it
	# derived its "pinned" map from the candidate.
	var repinned_map := pinned_digests.duplicate(true)
	repinned_map[first_key] = "0000000000000000000000000000000000000000000000000000000000000000"
	var repinned_aggregate := _aggregate_of(repinned_map)
	var repinned_candidate := {"ok": true, "count": repinned_map.size(), "sample_digests": repinned_map, "digest": repinned_aggregate}
	var repinned_pinned := {"telemetry_schema": LIVE_TELEMETRY_SCHEMA, "sample_count": repinned_map.size(), "full_sha256": repinned_aggregate, "sample_digests": repinned_map}
	var repin_result := Generator.verify_full_telemetry_against_anchor(repinned_candidate, repinned_pinned)
	_check(not bool(repin_result.get("ok", true)), "self-repinned candidate + manifest must fail the runtime anchor (FAN-1650)")
	_check("; ".join(repin_result.get("errors", [])).contains("runtime trust root"), "self-repin rejection must cite the runtime trust root")

	# 2c. FAN-1658: the manifest base identity is untrusted. Substituting the pinned
	#     current-base commit fails the production entry closed before any candidate map
	#     can be self-confirmed.
	var wrong_base := manifest.duplicate(true)
	(wrong_base.get("current_integration_base", {}) as Dictionary)["commit"] = "0000000000000000000000000000000000000000"
	var wrong_base_result := Generator.verify_candidate_full_telemetry_against_pinned({"live_telemetry": {"samples": _synthetic_samples()}}, wrong_base)
	_check(not bool(wrong_base_result.get("ok", true)), "substituted current-base commit must fail the telemetry gate")
	_check("; ".join(wrong_base_result.get("errors", [])).contains("current-base commit"), "substituted commit rejection must cite the base commit")

	# 3. Per-field payload sensitivity: a faithful synthetic candidate passes and every
	#    payload mutation type fails closed. These small samples cannot carry the full
	#    309-sample current-base anchor (covered by 2b), so they exercise the per-field
	#    comparison against a TEST-ONLY injected root. That seam is never reachable from
	#    any production/--mode=full path (see test_only_verify_full_telemetry_with_root).
	var samples := _synthetic_samples()
	var full := Generator.canonical_full_telemetry({"live_telemetry": {"samples": samples}})
	_check(bool(full.get("ok", false)), "synthetic faithful telemetry must be self-consistent: %s" % "; ".join(full.get("errors", [])))
	var synth_pinned := {
		"telemetry_schema": LIVE_TELEMETRY_SCHEMA,
		"sample_count": int(full.get("count", 0)),
		"full_sha256": str(full.get("digest", "")),
		"sample_digests": full.get("sample_digests", {}),
	}
	var faithful := {"live_telemetry": {"samples": _synthetic_samples()}}
	_check(bool(Generator.test_only_verify_full_telemetry_with_root(faithful, synth_pinned).get("ok", false)), "faithful synthetic telemetry candidate must pass the payload comparison")

	_expect_payload_failure(synth_pinned, func(s): s[0]["events"][1]["damage"] = float(s[0]["events"][1]["damage"]) + 0.01, "changed event damage must fail closed")
	_expect_payload_failure(synth_pinned, func(s): s[0]["events"][1]["target_id"] = "target_9", "changed event target must fail closed")
	_expect_payload_failure(synth_pinned, func(s): s[0]["events"][1]["frame"] = 999.0, "changed event frame/timing must fail closed")
	_expect_payload_failure(synth_pinned, func(s): s[0]["events"].append(s[0]["events"][0].duplicate(true)), "added event must fail closed")
	_expect_payload_failure(synth_pinned, func(s): s[0]["events"].remove_at(0), "removed event must fail closed")
	_expect_payload_failure(synth_pinned, func(s): _swap(s[0]["events"], 0, 1), "reordered events must fail closed")
	_expect_payload_failure(synth_pinned, func(s): s[0]["hp_ledger"]["rows"][0]["applied_damage"] = 12345.0, "changed HP ledger must fail closed")
	_expect_payload_failure(synth_pinned, func(s): s[0]["observer_probe"]["rng_probe"] = 424242, "changed RNG/observer probe must fail closed")
	_expect_payload_failure(synth_pinned, func(s): s[0]["counters"]["hits"] = 999, "changed counters must fail closed")
	_expect_payload_failure(synth_pinned, func(s): s[0]["dpm"] = 111.0, "changed DPM must fail closed")
	_expect_payload_failure(synth_pinned, func(s): s[0]["events"][1]["final_event_ids"] = ["forged"], "changed on-kill/final link must fail closed")
	_expect_payload_failure(synth_pinned, func(s): s[0]["trace_digest_sha256"] = "deadbeef", "tampered stored trace digest must fail closed")
	_expect_payload_failure(synth_pinned, func(s): s.append(s[0].duplicate(true)), "extra sample must fail closed")
	_expect_payload_failure(synth_pinned, func(s): s.remove_at(1), "missing sample must fail closed")
	_expect_payload_failure(synth_pinned, func(s): s[1]["sample_key"] = str(s[0]["sample_key"]), "duplicate sample key must fail closed")


func _expect_payload_failure(synth_pinned: Dictionary, mutate: Callable, message: String) -> void:
	var samples := _synthetic_samples()
	mutate.call(samples)
	var result := Generator.test_only_verify_full_telemetry_with_root({"live_telemetry": {"samples": samples}}, synth_pinned)
	_check(not bool(result.get("ok", true)), message)


# FAN-1649: two small but structurally faithful telemetry samples covering identity,
# an ordered event stream with an on-kill/final link, HP ledger, counters, DPM and
# the observer/RNG probe. Each carries a correctly recomputed trace digest.
func _synthetic_samples() -> Array:
	return [_synthetic_sample("druid/summon_amulet|143801|sustain_solo|sustain|1", "target_0"), _synthetic_sample("berserk/sword|143802|sustain_pack|sustain|10", "target_3")]


func _synthetic_sample(sample_key: String, target_id: String) -> Dictionary:
	var trace_id := "fan1511:%s" % sample_key
	var events := [
		{"kind": "cast", "source": "player_weapon", "phase": "windup", "action_id": "a", "cast_id": "c0", "attack_mode": "melee", "damage": 0.0, "event_id": "%s#0000" % trace_id, "trace_id": trace_id, "frame": 3.0, "probe_phase": "warmup"},
		{"kind": "hit", "source": "player_weapon", "phase": "damage_application", "target_id": target_id, "provenance_id": "p0", "cast_id": "c0", "damage": 485.25, "final_event_ids": ["%s#0002" % trace_id], "event_id": "%s#0001" % trace_id, "trace_id": trace_id, "frame": 15.0, "probe_phase": "measurement"},
		{"kind": "final_event", "source": "player_weapon", "phase": "target_death", "target_id": target_id, "event": "kill", "observed": true, "damage": 0.0, "related_hit_id": "%s#0001" % trace_id, "event_id": "%s#0002" % trace_id, "trace_id": trace_id, "frame": 15.0, "probe_phase": "measurement"},
	]
	var sample := {
		"telemetry_schema": LIVE_TELEMETRY_SCHEMA,
		"sample_key": sample_key,
		"trace_id": trace_id,
		"pair": sample_key.get_slice("|", 0),
		"seed": int(sample_key.get_slice("|", 1)),
		"scenario": sample_key.get_slice("|", 2),
		"fixture": sample_key.get_slice("|", 3),
		"target_cardinality": int(sample_key.get_slice("|", 4)),
		"fixture_target_ids": [target_id],
		"events": events,
		"hp_ledger": {"authority": "enemy_damage_applied_health_delta", "probe_phase": "measurement", "tolerance": 0.0001, "rows": [{"target_id": target_id, "applied_damage": 485.25, "entries": 1}], "total_applied_damage": 485.25},
		"counters": {"casts": 1, "hits": 1, "unique_target_ids": [target_id], "unique_target_count": 1, "damage_total": 485.25, "damage_by_source_phase": [{"source": "player_weapon", "phase": "damage_application", "damage": 485.25, "hits": 1}], "final_event_count": 1, "final_event_damage": 485.25},
		"observer_probe": {"mode": "enabled", "measurement_duration_seconds": 6.0, "measurement_frame_count": 360, "health_before": [1.0e9], "health_after": [1.0e9], "health_delta": 485.25, "rng_probe": 12345},
		"dpm": 4852.5,
	}
	sample["trace_digest_sha256"] = Generator._sha256(JSON.stringify(events, "", true, true))
	return sample


func _aggregate_of(sample_digests: Dictionary) -> String:
	var keys := sample_digests.keys()
	keys.sort()
	var aggregate := ""
	for key in keys:
		aggregate += "%s|%s\n" % [str(key), str(sample_digests[key])]
	return Generator._sha256(aggregate)


func _swap(arr: Array, i: int, j: int) -> void:
	var tmp = arr[i]
	arr[i] = arr[j]
	arr[j] = tmp


# FAN-1649 / AC5: predicate-based regression that a REAL projection row (level=20,
# scenario=class_constellation) duplicate is fail-closed, an extra unique projection
# pair is rejected, and a non-projection-row duplicate is NOT counted as a projection
# defect. The FAN-1642 QA report claimed a duplicate projection row was accepted; the
# exact-SHA audit showed _projection_rows already rejects real duplicates and requires
# exactly 51 pairs, so this proves the true predicate rather than a mislabeled row.
# FAN-1681 absorbs the FAN-1649 AC5 residual: FAN-1673 certified FAN-1672's defect
# scope, never this predicate, so the second half below re-states it against the
# production candidate gate and both halves are now proven by an executed mutation run.
func _verify_projection_duplicate_predicate(historical: Dictionary) -> void:
	var baseline := Generator.projection_oracle_digest(historical)
	_check(bool(baseline.get("ok", false)), "baseline projection must extract cleanly for the duplicate predicate")

	# Duplicate the real druid/summon_amulet L20 class_constellation projection row.
	var dup := historical.duplicate(true)
	var rows: Array = dup.get("weapon_rows", [])
	var real_row := {}
	for row_value in rows:
		var row: Dictionary = row_value
		if int(row.get("level", 0)) == 20 and str(row.get("scenario", "")) == "class_constellation" and str(row.get("class_id", "")) == "druid" and str(row.get("weapon_id", "")) == "summon_amulet":
			real_row = row.duplicate(true)
			break
	_check(not real_row.is_empty(), "duplicate predicate must find the real druid projection row")
	rows.append(real_row)
	var dup_result := Generator.projection_oracle_digest(dup)
	_check(not bool(dup_result.get("ok", true)), "a duplicated real projection row must be rejected")
	_check(str(dup_result.get("error", "")).contains("duplicate projection row"), "duplicate rejection must name the duplicate projection row")

	# An extra unique L20 class_constellation projection pair is rejected (breaks 51).
	var extra := historical.duplicate(true)
	var extra_rows: Array = extra.get("weapon_rows", [])
	var new_pair := real_row.duplicate(true)
	new_pair["class_id"] = "druid"
	new_pair["weapon_id"] = "phantom_totem"
	extra_rows.append(new_pair)
	var extra_result := Generator.projection_oracle_digest(extra)
	_check(not bool(extra_result.get("ok", true)), "an extra unique projection pair must be rejected")

	# A duplicated NON-projection row (level 1) is NOT a projection defect: the
	# projection stays valid and identical to the baseline.
	var non_proj := historical.duplicate(true)
	var non_proj_rows: Array = non_proj.get("weapon_rows", [])
	var level1_row := {}
	for row_value in non_proj_rows:
		var row: Dictionary = row_value
		if int(row.get("level", 0)) == 1 and str(row.get("scenario", "")) == "class_constellation" and str(row.get("class_id", "")) == "druid" and str(row.get("weapon_id", "")) == "summon_amulet":
			level1_row = row.duplicate(true)
			break
	if not level1_row.is_empty():
		non_proj_rows.append(level1_row)
		var non_proj_result := Generator.projection_oracle_digest(non_proj)
		_check(bool(non_proj_result.get("ok", false)), "a non-projection row duplicate must not be a projection defect")
		_check(str(non_proj_result.get("digest", "")) == str(baseline.get("digest", "")), "a non-projection row duplicate must not change the projection digest")
	else:
		_check(false, "duplicate predicate must find a level-1 non-projection druid row for the control case")

	# FAN-1681 (absorbed FAN-1649 AC5 residual): the same predicate at the PRODUCTION
	# GATE, not only at the digest helper. `verify_candidate_projection_against_current_base`
	# is what --mode=full actually runs before writing, so the discrimination has to hold
	# there: a faithful current-base candidate passes, duplicating its real level-20
	# class_constellation row is rejected as a duplicate projection row, an extra unique
	# projection pair is rejected, and duplicating a NON-projection row is still accepted
	# so the test cannot pass a mislabeled row off as a projection defect.
	var loaded := Generator.load_oracle_lineage()
	if not bool(loaded.get("ok", false)):
		_check(false, "oracle lineage manifest must load for the gate-level duplicate predicate")
		return
	var manifest: Dictionary = loaded.get("manifest", {})
	var faithful := _candidate_with_accepted_deltas(historical, manifest)
	_check(bool(Generator.verify_candidate_projection_against_current_base(faithful, manifest).get("ok", false)), "the faithful current-base candidate must pass the gate before the duplicate predicate means anything")

	var gate_dup := faithful.duplicate(true)
	var gate_dup_row := _find_row(gate_dup, "druid", "summon_amulet", 20, "class_constellation")
	_check(not gate_dup_row.is_empty(), "gate duplicate predicate must find the real druid projection row")
	(gate_dup.get("weapon_rows", []) as Array).append(gate_dup_row)
	var gate_dup_result := Generator.verify_candidate_projection_against_current_base(gate_dup, manifest)
	_check(not bool(gate_dup_result.get("ok", true)), "a duplicated real level-20 class_constellation projection row must be rejected by the gate")
	_check("; ".join(gate_dup_result.get("errors", [])).contains("duplicate projection row druid/summon_amulet"), "the gate must name the duplicated projection row")

	var gate_extra := faithful.duplicate(true)
	var gate_extra_row := gate_dup_row.duplicate(true)
	gate_extra_row["weapon_id"] = "phantom_totem"
	(gate_extra.get("weapon_rows", []) as Array).append(gate_extra_row)
	_check(not bool(Generator.verify_candidate_projection_against_current_base(gate_extra, manifest).get("ok", true)), "an extra unique level-20 class_constellation projection pair must be rejected by the gate")

	var gate_non_proj := faithful.duplicate(true)
	var gate_non_proj_row := _find_row(gate_non_proj, "druid", "summon_amulet", 1, "class_constellation")
	_check(not gate_non_proj_row.is_empty(), "gate duplicate predicate must find the level-1 control row")
	(gate_non_proj.get("weapon_rows", []) as Array).append(gate_non_proj_row)
	_check(bool(Generator.verify_candidate_projection_against_current_base(gate_non_proj, manifest).get("ok", false)), "a duplicated non-projection row must NOT be reported as a projection defect by the gate")


func _find_row(dataset: Dictionary, class_id: String, weapon_id: String, level: int, scenario: String) -> Dictionary:
	for row_value in dataset.get("weapon_rows", []):
		var row: Dictionary = row_value
		if int(row.get("level", 0)) == level and str(row.get("scenario", "")) == scenario and str(row.get("class_id", "")) == class_id and str(row.get("weapon_id", "")) == weapon_id:
			return row.duplicate(true)
	return {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _finish() -> void:
	if _errors.is_empty():
		print("FAN-1551/FAN-1641 A5 51x4 lineage-aware executable-oracle parity passed.")
		quit(0)
		return
	for error_value in _errors:
		push_error(error_value)
	quit(1)
