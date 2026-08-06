extends SceneTree

# FAN-1730: fail-closed lineage guard for the IMMUTABLE f09 oracle.
#
# This suite owns the committed-oracle <-> lineage-manifest contract that used to
# live at the end of tests/a5_balance_report_integrity_test.gd. It reads ONLY
# tests/fixtures/a5_f09_oracle.json.gz (via Generator.read_raw_artifact()'s default
# path) and tests/fixtures/a5_oracle_lineage.json. It never touches
# Generator.RAW_PATH, so deleting or corrupting the regenerable
# docs/design/reports/fan1438_a5_balance/raw.json.gz cannot influence this verdict.
#
# The mirror-image contract lives in tests/a5_balance_report_integrity_test.gd,
# which keeps validating the CURRENT regenerable report/CSV/raw artifacts and still
# fails closed when RAW_PATH is missing or corrupted. Neither suite skips a check
# when its input is absent: each one fails closed on its own input.
#
# The full git-backed commit-level causality (ancestry, inventory segmentation,
# candidate zero-delta gate, and the negative mutation matrix) lives in
# tests/a5_balance_report_parity_test.gd.
const Generator := preload("res://tools/a5_balance_report.gd")
# FAN-1641: external pin of the current integration-base (3f3788fd, FAN-1575) 51x4 digest,
# so a self-consistent lineage-manifest tamper cannot pass the lineage gate.
const CURRENT_BASE_PROJECTION_SHA256 := "a85a35d0430d5d520c2b0643870b762dff9285f00ae0b2b214b3ff96d01ef7cb"
# FAN-1649: external pin of the current integration-base full canonical telemetry
# payload aggregate over the 309 per-sample digests, anchoring the pinned map the
# same way as the projection digest above.
const CURRENT_BASE_TELEMETRY_FULL_SHA256 := "c269edb122252e4ac35a46e24b531c26affcb071b69e1e20fe428b17c943b72a"
const LIVE_TELEMETRY_SCHEMA := "fan1511.runtime-telemetry.v2"

var _errors := PackedStringArray()


func _initialize() -> void:
	_validate_oracle_lineage()
	_finish()


# FAN-1641: the committed oracle and the checked-in lineage manifest must stay
# fail-closed consistent.
func _validate_oracle_lineage() -> void:
	var historical_artifact := Generator.read_raw_artifact()
	_check(bool(historical_artifact.get("ok", false)), "immutable f09 oracle must decode before lineage verification: %s" % historical_artifact.get("error", "unknown error"))
	var historical_raw_text := str(historical_artifact.get("text", ""))
	var historical_raw = JSON.parse_string(historical_raw_text)
	_check(historical_raw is Dictionary, "immutable f09 oracle must parse as an object")
	if not historical_raw is Dictionary:
		return
	var historical_dataset := historical_raw as Dictionary
	var loaded := Generator.load_oracle_lineage()
	_check(bool(loaded.get("ok", false)), "oracle lineage manifest must load: %s" % loaded.get("error", "unknown"))
	if not bool(loaded.get("ok", false)):
		return
	var manifest: Dictionary = loaded.get("manifest", {})
	var lineage := Generator.verify_oracle_lineage(manifest, historical_dataset, historical_raw_text)
	_check(bool(lineage.get("ok", false)), "committed oracle must match the lineage manifest: %s" % "; ".join(lineage.get("errors", [])))
	_check(str(lineage.get("current_digest", "")) == CURRENT_BASE_PROJECTION_SHA256, "reconstructed current digest differs from the externally pinned current base")
	_check(str((manifest.get("current_integration_base", {}) as Dictionary).get("projection_sha256", "")) == CURRENT_BASE_PROJECTION_SHA256, "manifest current-base digest differs from the externally pinned current base")
	_check(str((manifest.get("historical_oracle", {}) as Dictionary).get("dataset_digest_sha256", "")) == str(historical_dataset.get("dataset_digest_sha256", "")), "lineage manifest historical dataset digest differs from immutable f09 oracle")
	var drifted := manifest.duplicate(true)
	(drifted.get("current_integration_base", {}) as Dictionary)["projection_sha256"] = "0000000000000000000000000000000000000000000000000000000000000000"
	_check(not bool(Generator.verify_oracle_lineage(drifted, historical_dataset, historical_raw_text).get("ok", true)), "drifted manifest current-base digest must fail closed")
	# FAN-1649: the pinned current-base FULL telemetry payload is externally anchored
	# and internally self-consistent (309 samples, aggregate == full_sha256 == const).
	var pinned: Dictionary = (manifest.get("current_integration_base", {}) as Dictionary).get("telemetry_full", {})
	_check(not pinned.is_empty(), "manifest must pin a current-base full telemetry payload")
	var pinned_digests: Dictionary = pinned.get("sample_digests", {})
	_check(int(pinned.get("sample_count", -1)) == 309 and pinned_digests.size() == 309, "pinned full telemetry must cover all 309 samples")
	_check(str(pinned.get("telemetry_schema", "")) == LIVE_TELEMETRY_SCHEMA, "pinned full telemetry schema mismatch")
	var keys := pinned_digests.keys()
	keys.sort()
	var aggregate := ""
	for key in keys:
		aggregate += "%s|%s\n" % [str(key), str(pinned_digests[key])]
	_check(Generator._sha256(aggregate) == str(pinned.get("full_sha256", "")), "pinned full telemetry aggregate is internally inconsistent")
	_check(str(pinned.get("full_sha256", "")) == CURRENT_BASE_TELEMETRY_FULL_SHA256, "manifest full-telemetry digest differs from the externally pinned current base")
	# A self-consistent tamper (rewrite a sample digest AND recompute the aggregate)
	# stays internally consistent but diverges from the external committed constant.
	var tampered := pinned_digests.duplicate(true)
	tampered[str(keys[0])] = "0000000000000000000000000000000000000000000000000000000000000000"
	var tampered_keys := tampered.keys()
	tampered_keys.sort()
	var tampered_aggregate := ""
	for key in tampered_keys:
		tampered_aggregate += "%s|%s\n" % [str(key), str(tampered[key])]
	_check(Generator._sha256(tampered_aggregate) != CURRENT_BASE_TELEMETRY_FULL_SHA256, "self-consistent full-telemetry tamper must diverge from the external constant")
	# FAN-1658: the RUNTIME gate anchors on the immutable trust root in the tool, not on
	# the caller manifest. The faithful materialized current-base map passes the runtime
	# anchor, and the self-consistent tamper above (per-sample map + its own aggregate,
	# both self-repinned) still fails closed against the unchanged runtime constant.
	var faithful_candidate := {"ok": true, "count": pinned_digests.size(), "sample_digests": pinned_digests.duplicate(true), "digest": Generator._sha256(aggregate)}
	_check(bool(Generator.verify_full_telemetry_against_anchor(faithful_candidate, pinned).get("ok", false)), "faithful materialized current-base telemetry map must pass the runtime anchor")
	var tamper_candidate := {"ok": true, "count": tampered.size(), "sample_digests": tampered, "digest": Generator._sha256(tampered_aggregate)}
	var tamper_pinned := {"telemetry_schema": LIVE_TELEMETRY_SCHEMA, "sample_count": tampered.size(), "full_sha256": Generator._sha256(tampered_aggregate), "sample_digests": tampered}
	_check(not bool(Generator.verify_full_telemetry_against_anchor(tamper_candidate, tamper_pinned).get("ok", true)), "self-repinned current-base telemetry must fail the runtime anchor")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _finish() -> void:
	if not _errors.is_empty():
		for error in _errors:
			push_error(error)
		push_error("FAN-1730 A5 immutable f09 oracle lineage test failed (%d errors)." % _errors.size())
		quit(1)
		return
	print("FAN-1730 A5 immutable f09 oracle lineage passed the committed-oracle/manifest tie, the externally pinned 51x4 and 309-sample telemetry anchors, and their fail-closed tampers.")
	quit(0)
