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
# FAN-1641: the current integration base (b8909e30) 51x4 digest is pinned here as
# an EXTERNAL constant, exactly like the f09 oracle above. This anchors the whole
# accepted-delta set: a self-consistent manifest tamper (drop/add/alter a delta and
# recompute its own counts + current sha) still changes the reconstructed digest,
# which then diverges from this committed constant and fails closed.
const CURRENT_BASE_PROJECTION_SHA256 := "ac7710a043848eb4fe895237092c3aa2458ab4c1092258a6ba03d5f02b635494"

var _errors := PackedStringArray()


func _initialize() -> void:
	var raw_artifact := Generator.read_raw_artifact()
	_check(bool(raw_artifact.get("ok", false)), "raw A5 artifact must decode before parity verification")
	var raw_text := str(raw_artifact.get("text", ""))
	var dataset = JSON.parse_string(raw_text)
	_check(dataset is Dictionary, "raw A5 artifact must parse before parity verification")
	if dataset is Dictionary:
		_verify_historical_oracle(dataset as Dictionary)
		_verify_lineage_contract(dataset as Dictionary, raw_text)
	_finish()


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

	# 3. A faithful materialization candidate (f09 + accepted deltas) passes the
	#    exact zero gameplay/event delta gate against the current integration base.
	var candidate := _candidate_with_accepted_deltas(historical, manifest)
	var candidate_ok := Generator.verify_candidate_against_current_base(candidate, manifest)
	_check(bool(candidate_ok.get("ok", false)), "faithful current-base candidate must pass the zero-delta gate: %s" % "; ".join(candidate_ok.get("errors", [])))

	# 4. Negative mutations must all fail closed.
	# extra projection-cell delta on an unrelated pair.
	_expect_candidate_failure(_mutate_projection_cell(candidate, "assassin", "chakrams", "live_solo_dpm_mean", 0.01), manifest, "extra projection-cell delta must fail closed")
	# changed accepted value.
	_expect_candidate_failure(_mutate_projection_cell(candidate, "druid", "summon_amulet", "live_crowd_dpm_mean", 0.01), manifest, "changed accepted value must fail closed")
	# false current-base zero: an unpatched f09 candidate is NOT the current base.
	_expect_candidate_failure(historical.duplicate(true), manifest, "false current-base zero (candidate == historical f09) must fail closed")

	# missing lineage entry: drop one accepted delta from the manifest.
	var missing_entry := manifest.duplicate(true)
	var deltas: Array = missing_entry.get("accepted_projection_deltas", [])
	if deltas.size() > 0:
		deltas.remove_at(deltas.size() - 1)
	_check(not bool(Generator.verify_oracle_lineage(missing_entry, historical, raw_text).get("ok", true)), "missing accepted-delta entry must fail the manifest consistency gate")
	_check(not bool(Generator.verify_candidate_against_current_base(candidate, missing_entry).get("ok", true)), "missing accepted-delta entry must fail the candidate gate")

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


func _expect_candidate_failure(candidate: Dictionary, manifest: Dictionary, message: String) -> void:
	_check(not bool(Generator.verify_candidate_against_current_base(candidate, manifest).get("ok", true)), message)


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
