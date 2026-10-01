extends SceneTree

## FAN-3991 single-process regression gate: several classes, several combats,
## Doctor after other classes, one game process.
##
## The native Windows check of 0.3.1.1 (FAN-3990) crashed with memory
## corruption in long sessions: combats for another class, then Doctor
## ultimates. The engine had printed `Parent node is busy adding/removing
## children` and `~Node: Condition "data.parent" is true` first — a node freed
## synchronously while its parent was in the middle of an exit-tree
## propagation, destroyed with the parent still pointing at it. The FAN-3985
## gates play every pair in a fresh process and finish the presentation
## explicitly before tearing the game down, so they never reach that state.
##
## This suite runs `tools/ultimate_session_lifecycle_probe.gd` in a child
## Godot process per sequence — one `Main`, combat after combat through the
## shipped `_start_combat()` / `ultimate` action / `_end_combat()` path — and
## fails when the child's output carries any engine lifecycle error, a
## freed-object access, a script error, when the child crashes or exits
## non-zero, or when the probe reports a pair that did not activate.
##
## Run:
## python3 tools/godot_gate.py --headless --path . \
##   --script res://tests/ultimates/multi_class_session_lifecycle_test.gd
##
## `FAN3991_SEQUENCES=<label,label>` limits the run to the named sequences.

const PROBE_PATH := "res://tools/ultimate_session_lifecycle_probe.gd"
const EXPECTED_ALL_PAIRS := 51
## Generous bounds: a pair takes about 4-10 s of game time here; a child that
## outlives them is hung (or symbolizing a crash) and is killed and failed.
const SEQUENCE_TIMEOUT_BASE_SECONDS := 120.0
const SEQUENCE_TIMEOUT_PER_PAIR_SECONDS := 30.0
## Every engine message the FAN-3990 crash sessions printed before dying, plus
## the freed-object accesses the FAN-3985 release build turned into SIGSEGV.
const LIFECYCLE_ERROR_PATTERNS: Array[String] = [
	"Parent node is busy adding/removing children",
	"Parent node is busy setting up children",
	"Condition \"data.parent\" is true",
	"Condition \"!data.tree\" is true",
	"Condition \"p_node->data.tree != data.tree\" is true",
	"Parameter \"canvas_item\" is null",
	"previously freed",
	"Trying to cast a freed object",
	"SCRIPT ERROR",
]
const SEQUENCES: Array[Dictionary] = [
	{"label": "dark_mage_then_doctor", "args": ["--classes=dark_mage,doctor", "--end=during_cast"], "pairs": 6},
	{"label": "chemist_then_doctor", "args": ["--classes=chemist,doctor", "--end=during_cast"], "pairs": 6},
	{"label": "dark_mage_then_doctor_natural_end", "args": ["--classes=dark_mage,doctor", "--end=natural"], "pairs": 6},
	{"label": "all_17_classes", "args": ["--all", "--end=during_cast"], "pairs": EXPECTED_ALL_PAIRS},
]


func _initialize() -> void:
	var only := OS.get_environment("FAN3991_SEQUENCES").strip_edges()
	var selected: Array[String] = []
	for raw in only.split(",", false):
		selected.append(str(raw).strip_edges())
	var errors: Array[String] = []
	var ran := 0
	for sequence in SEQUENCES:
		var label := str(sequence["label"])
		if not selected.is_empty() and label not in selected:
			continue
		ran += 1
		errors.append_array(_run_sequence(label, sequence["args"], int(sequence["pairs"])))
	if ran == 0:
		errors.append("FAN3991_SEQUENCES=%s selected no sequence" % only)
	if errors.is_empty():
		print("Multi-class session lifecycle test passed: %d sequences, one process each, zero lifecycle errors, clean exits." % ran)
		quit(0)
		return
	for error in errors:
		push_error("Multi-class session lifecycle test: %s" % error)
	push_error("Multi-class session lifecycle test: %d errors." % errors.size())
	quit(1)


func _run_sequence(label: String, args: Array, expected_pairs: int) -> Array[String]:
	var errors: Array[String] = []
	var report_path := "%s/fan3991_session_%s.json" % [OS.get_user_data_dir(), label]
	var log_path := "%s/fan3991_session_%s.log" % [OS.get_user_data_dir(), label]
	for stale in [report_path, log_path]:
		if FileAccess.file_exists(stale):
			DirAccess.remove_absolute(stale)
	# The crash handler is off on purpose: a release build dies by signal at
	# once, while the editor binary's handler symbolizes the corrupted stack
	# for minutes. The child writes its own engine log, so a crash mid-session
	# still leaves every error it printed on disk.
	var command: Array = [
		"--headless",
		"--disable-crash-handler",
		"--log-file", log_path,
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", ProjectSettings.globalize_path(PROBE_PATH),
		"--",
	]
	command.append_array(args)
	command.append("--report=%s" % report_path)
	var started := Time.get_ticks_msec()
	var timeout_seconds := SEQUENCE_TIMEOUT_BASE_SECONDS + SEQUENCE_TIMEOUT_PER_PAIR_SECONDS * expected_pairs
	var pid := OS.create_process(OS.get_executable_path(), PackedStringArray(command))
	if pid <= 0:
		errors.append("%s: could not start the child Godot process" % label)
		return errors
	var timed_out := false
	while OS.is_process_running(pid):
		if float(Time.get_ticks_msec() - started) / 1000.0 > timeout_seconds:
			timed_out = true
			OS.kill(pid)
			break
		OS.delay_msec(250)
	var seconds := float(Time.get_ticks_msec() - started) / 1000.0
	var exit_code := -1 if timed_out else OS.get_process_exit_code(pid)
	var text := FileAccess.get_file_as_string(log_path) if FileAccess.file_exists(log_path) else ""
	var offending: Array[String] = []
	var counts := {}
	for line in text.split("\n"):
		for pattern in LIFECYCLE_ERROR_PATTERNS:
			if line.contains(pattern):
				counts[pattern] = int(counts.get(pattern, 0)) + 1
				if offending.size() < 12:
					offending.append(line.strip_edges())
				break
	var report := _load_report(report_path)
	var pairs_total := int(report.get("pairs_total", -1))
	var pairs_passing := int(report.get("pairs_passing", -1))
	print("Multi-class session [%s]: exit %d in %.1fs, pairs %d/%d, lifecycle errors %s, log %s" % [
		label, exit_code, seconds, pairs_passing, pairs_total, JSON.stringify(counts), log_path])
	if timed_out:
		errors.append("%s: child Godot did not finish within %.0fs and was killed" % [label, timeout_seconds])
	elif exit_code != 0:
		errors.append("%s: child Godot exited %d (a negative or >128 code is a crash)" % [label, exit_code])
	if text.is_empty():
		errors.append("%s: the child wrote no engine log (%s)" % [label, log_path])
	if not counts.is_empty():
		errors.append("%s: engine lifecycle errors in the session log: %s" % [label, JSON.stringify(counts)])
		for line in offending:
			errors.append("%s:   %s" % [label, line])
	if report.is_empty():
		errors.append("%s: the probe wrote no report (%s)" % [label, report_path])
	else:
		if pairs_total != expected_pairs:
			errors.append("%s: played %d pairs, expected %d" % [label, pairs_total, expected_pairs])
		for raw_entry in report.get("pairs", []):
			var entry := raw_entry as Dictionary
			if not bool(entry.get("pass", false)):
				errors.append("%s: %s %s" % [label, entry.get("key", "?"), entry.get("failures", [])])
	return errors


func _load_report(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
