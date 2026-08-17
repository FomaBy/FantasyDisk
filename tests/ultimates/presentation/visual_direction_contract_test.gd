extends SceneTree

## Focused gate for the ultimate visual-direction and live-capture contract.
##
## It proves three things: the reference Doctor package satisfies every gate,
## the live roster matches the declared adoption ratchet exactly, and each gate
## can still go red. Fixtures mutate a copy of the reference manifest, so a red
## path never depends on a package that is allowed to be behind.

const Contract := preload("res://scripts/ultimates/presentation/ultimate_visual_direction_contract.gd")
const REFERENCE_CLASS := "doctor"
const EXPECTED_CLASS_COUNT := 17
const EXPECTED_WEAPON_COUNT := 51


func _initialize() -> void:
	var errors: Array[String] = []
	_check_reference_implementation(errors)
	_check_roster(errors)
	_check_gates_go_red(errors)
	_finish(errors)


## The reference implementation carries the whole contract, so every later class
## package has one in-repo example of a conforming declaration.
func _check_reference_implementation(errors: Array[String]) -> void:
	var manifest := Contract.load_manifest(REFERENCE_CLASS)
	if manifest.is_empty():
		errors.append("reference class %s has no manifest" % REFERENCE_CLASS)
		return
	for violation in Contract.violations(REFERENCE_CLASS, manifest):
		errors.append("reference class %s must satisfy every gate: %s" % [REFERENCE_CLASS, violation])


## Roster coverage against the ratchet: no unlisted class may fail a gate, and
## no listed class may already pass it.
func _check_roster(errors: Array[String]) -> void:
	var class_ids := Contract.class_ids()
	if class_ids.size() != EXPECTED_CLASS_COUNT:
		errors.append("expected %d class packages, found %d" % [EXPECTED_CLASS_COUNT, class_ids.size()])

	var weapon_count := 0
	var failures_by_gate := {}
	for gate in Contract.GATES:
		failures_by_gate[gate] = {}
	for class_id in class_ids:
		var manifest := Contract.load_manifest(class_id)
		if manifest.is_empty():
			errors.append("class %s has no readable manifest" % class_id)
			continue
		var weapons: Variant = manifest.get("weapons", [])
		weapon_count += (weapons as Array).size() if weapons is Array else 0
		for violation in Contract.violations(class_id, manifest):
			var gate := Contract.gate_of(violation)
			if not failures_by_gate.has(gate):
				errors.append("class %s reported unknown gate %s" % [class_id, gate])
				continue
			if not (failures_by_gate[gate] as Dictionary).has(class_id):
				failures_by_gate[gate][class_id] = violation
	if weapon_count != EXPECTED_WEAPON_COUNT:
		errors.append("expected %d weapon ultimates, found %d" % [EXPECTED_WEAPON_COUNT, weapon_count])

	for gate in Contract.GATES:
		var gaps: Dictionary = Contract.ADOPTION_GAPS.get(gate, {})
		var failures: Dictionary = failures_by_gate[gate]
		for class_id in gaps:
			if not class_ids.has(str(class_id)):
				errors.append("adoption gap names unknown class %s/%s" % [gate, class_id])
			elif not failures.has(class_id):
				errors.append(
					"stale adoption gap: class %s already satisfies the %s gate" % [class_id, gate]
				)
		for class_id in failures:
			if not gaps.has(class_id):
				errors.append("class %s fails the %s gate: %s" % [class_id, gate, failures[class_id]])
		var conforming := class_ids.size() - failures.size()
		var pending: Array = failures.keys()
		pending.sort()
		print("Ultimate visual direction gate %-11s %2d/%d classes conform; pending: %s" % [
			gate,
			conforming,
			class_ids.size(),
			", ".join(pending) if not pending.is_empty() else "none",
		])


## Every gate must be able to reject. A gate that cannot go red certifies nothing.
func _check_gates_go_red(errors: Array[String]) -> void:
	var baseline := Contract.load_manifest(REFERENCE_CLASS)
	if baseline.is_empty():
		return

	var no_phase_id := _fixture(baseline)
	_weapon(no_phase_id, 0)["phase_ids"]["cancel"] = ""
	_expect_violation(no_phase_id, "phases.phase_id_empty", errors)

	var wrong_binding := _fixture(baseline)
	_weapon(wrong_binding, 0)["phase_ids"]["release"] = "weapon_ultimate.phase.doctor.restore_potion.release"
	_expect_violation(wrong_binding, "phases.phase_id_binding", errors)

	var late_start := _fixture(baseline)
	_weapon(late_start, 0)["timing_seconds"]["windup"] = 0.5
	_expect_violation(late_start, "phases.windup_origin", errors)

	var backwards := _fixture(baseline)
	_weapon(backwards, 0)["timing_seconds"]["recovery"] = 0.1
	_expect_violation(backwards, "phases.timing_order", errors)

	var overlong := _fixture(baseline)
	_weapon(overlong, 0)["timing_seconds"]["cancel"] = Contract.MAX_TIMELINE_SECONDS + 0.5
	_expect_violation(overlong, "phases.timing_range", errors)

	var no_cleanup_window := _fixture(baseline)
	var cleanup_weapon := _weapon(no_cleanup_window, 0)
	cleanup_weapon["timing_seconds"]["cancel"] = cleanup_weapon["timing_seconds"]["recovery"]
	_expect_violation(no_cleanup_window, "cleanup.window", errors)

	var inverted_budget := _fixture(baseline)
	_weapon(inverted_budget, 0)["performance"]["crowd_cap"] = 1
	_expect_violation(inverted_budget, "budget.relation", errors)

	var over_budget := _fixture(baseline)
	_weapon(over_budget, 0)["performance"]["max_visual_nodes"] = Contract.MAX_VISUAL_NODES_CEILING + 1
	_weapon(over_budget, 0)["performance"]["crowd_cap"] = Contract.CROWD_CAP_CEILING
	_expect_violation(over_budget, "budget.max_visual_nodes_ceiling", errors)

	var over_crowd_cap := _fixture(baseline)
	_weapon(over_crowd_cap, 0)["performance"]["crowd_cap"] = Contract.CROWD_CAP_CEILING + 1
	_expect_violation(over_crowd_cap, "budget.crowd_cap_ceiling", errors)

	var cloned_silhouette := _fixture(baseline)
	_weapon(cloned_silhouette, 1)["silhouette"] = str(_weapon(cloned_silhouette, 0)["silhouette"])
	_expect_violation(cloned_silhouette, "direction.silhouette_duplicate", errors)

	var no_motion := _fixture(baseline)
	_weapon(no_motion, 2)["motion_path"] = "   "
	_expect_violation(no_motion, "direction.motion_path_missing", errors)

	var missing_viewport := _fixture(baseline)
	(missing_viewport["evidence"]["contact_sheets"] as Array).remove_at(0)
	_expect_violation(missing_viewport, "capture.viewport_missing", errors)

	var absent_viewport := _fixture(baseline)
	(absent_viewport["evidence"]["contact_sheets"] as Array)[1] = \
		"docs/design/references/weapon_ultimates/doctor/never_captured_720p.png"
	_expect_violation(absent_viewport, "capture.file_absent", errors)

	# A real PNG in the 720p slot at the wrong size: what a stale re-capture,
	# or a sheet taken at the editor window size, actually leaves behind.
	var wrong_viewport := _fixture(baseline)
	(wrong_viewport["evidence"]["contact_sheets"] as Array)[1] = _write_undersized_sheet()
	_expect_violation(wrong_viewport, "capture.viewport_size", errors)

	var absent_script := _fixture(baseline)
	absent_script["evidence"]["capture_script"] = ""
	_expect_violation(absent_script, "capture.script_missing", errors)

	var undeclared_generation := _fixture(baseline)
	undeclared_generation["generator_provenance"]["new_pixellab_assets"] = ["assets/sprites/effects/new_frame.png"]
	_expect_violation(undeclared_generation, "provenance.route_pixellab", errors)

	var unevidenced_reuse := _fixture(baseline)
	unevidenced_reuse["generator_provenance"]["reused_sources"] = {}
	_expect_violation(unevidenced_reuse, "provenance.reuse_unevidenced", errors)

	var transparent_exception := _fixture(baseline)
	transparent_exception["generator_provenance"]["full_canvas_exception"] = {
		"weapon_id": "restore_potion",
		"reason": "cinematic underlay",
		"full_canvas": true,
		"transparent_frames": true,
	}
	_expect_violation(transparent_exception, "provenance.exception_transparency", errors)

	var unscoped_exception := _fixture(baseline)
	unscoped_exception["generator_provenance"]["full_canvas_exception"] = {
		"weapon_id": "restore_potion",
		"reason": "",
		"full_canvas": false,
		"transparent_frames": false,
	}
	_expect_violation(unscoped_exception, "provenance.exception_scope", errors)
	_expect_violation(unscoped_exception, "provenance.exception_reason", errors)

	var opaque := _fixture(baseline)
	_weapon(opaque, 0)["quality"]["max_viewport_coverage_ratio"] = Contract.MAX_VIEWPORT_COVERAGE_RATIO + 0.01
	_expect_violation(opaque, "quality.coverage", errors)

	var hud_covered := _fixture(baseline)
	_weapon(hud_covered, 0)["quality"]["hud_bands_clear"] = false
	_expect_violation(hud_covered, "quality.hud_bands", errors)

	var no_substitute := _fixture(baseline)
	_weapon(no_substitute, 0)["quality"]["reduced_motion_substitute"] = ""
	_expect_violation(no_substitute, "quality.reduced_motion_substitute", errors)

	var retimed_variant := _fixture(baseline)
	_weapon(retimed_variant, 0)["quality"]["reduced_motion_preserves_timing"] = false
	_expect_violation(retimed_variant, "quality.reduced_motion_timing", errors)

	var strobing := _fixture(baseline)
	_weapon(strobing, 0)["quality"]["full_screen_flash_hz"] = Contract.MAX_FLASH_HZ + 1.0
	_expect_violation(strobing, "quality.flash_hz", errors)

	var wide_repeat_flash := _fixture(baseline)
	_weapon(wide_repeat_flash, 0)["quality"]["full_screen_flash_hz"] = 2.0
	_weapon(wide_repeat_flash, 0)["quality"]["max_flash_coverage_ratio"] = \
		Contract.MAX_REPEAT_FLASH_COVERAGE_RATIO + 0.05
	_expect_violation(wide_repeat_flash, "quality.flash_repeat", errors)

	var undeclared_quality := _fixture(baseline)
	_weapon(undeclared_quality, 0).erase("quality")
	_expect_violation(undeclared_quality, "quality.missing", errors)


func _fixture(baseline: Dictionary) -> Dictionary:
	return baseline.duplicate(true)


## A throwaway PNG that is a valid image but not a supported capture viewport.
func _write_undersized_sheet() -> String:
	var path := "user://fan2517_undersized_720p.png"
	Image.create(320, 200, false, Image.FORMAT_RGBA8).save_png(path)
	return path


func _weapon(manifest: Dictionary, index: int) -> Dictionary:
	return (manifest["weapons"] as Array)[index] as Dictionary


func _expect_violation(manifest: Dictionary, expected_code: String, errors: Array[String]) -> void:
	var reported := Contract.violations(REFERENCE_CLASS, manifest)
	for violation in reported:
		if violation.begins_with("%s:" % expected_code):
			return
	errors.append("expected %s, got: %s" % [expected_code, ", ".join(reported) if not reported.is_empty() else "no violation"])


func _finish(errors: Array[String]) -> void:
	if errors.is_empty():
		print("Ultimate visual direction contract passed (reference %s package, roster ratchet, and every gate red-path)." % REFERENCE_CLASS)
		quit(0)
		return
	for error in errors:
		push_error("Ultimate visual direction contract: %s" % error)
	quit(1)
