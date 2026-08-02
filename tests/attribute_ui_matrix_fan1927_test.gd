extends SceneTree

# FAN-1927: полная runtime-матрица визуальной приёмки атрибутного контракта —
# 4 surface-группы × 3 viewport × 4 состояния = 48 живых состояний с PNG-
# evidence (build/qa/fan1927/) и проверками содержимого/геометрии:
#
#   surfaces:  level_up, attribute_shop, pause_codex (живые значения досье;
#              canonical-паритет Кодекса держат codex_data_smoke_test и
#              codex_scrum954_layout_test), hero_select
#   viewports: 1280×720, 1920×1080, 2560×1440
#   states:    normal / ineligible / capped / long_copy
#
# Контракты состояний — спека fan1883_attribute_clarity: ineligible-карта
# отсутствует до раскладки (ряд перецентрован), capped-ось не предлагается и
# читаема как «максимум», длинная русская копия доступна через approved
# scroll-зоны (LU.DetailDrawer / AS.DetailDrawer / dossier / tooltip), без
# ellipsis на presentation-данных; before→after/delta не удаляются compact-режимом.
#
# Запуск: Godot --headless --path . --script res://tests/attribute_ui_matrix_fan1927_test.gd

const ProgressionData := preload("res://scripts/progression_data.gd")
const AttributeSurfaces := preload("res://scripts/ui/attribute_surfaces.gd")
const QACaptureTeardown := preload("res://tools/qa_capture_teardown.gd")
const MAIN_SCENE := preload("res://scenes/Main.tscn")

const VIEWPORTS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const STATES := ["normal", "ineligible", "capped", "long_copy"]
const EVIDENCE_DIR := "res://build/qa/fan1927"
const GLOBAL_TOOLTIP_CONTROL_PATH := "res://scripts/ui/global_tooltip_control.gd"
const NATIVE_TOOLTIP_MUTATION_ARG := "--fan1973-native-tooltip-mutation"
const NATIVE_TOOLTIP_ITERATIONS := 3
const NATIVE_WINDOW_READY_FRAMES := 180
const NATIVE_POPUP_SETTLE_FRAMES := 12
# Test-owned fail-closed oracle. Reward IDs, eligibility profiles and every
# expected before/after/delta line are literals: this fixture deliberately does
# not call the production AttributeContract that renders the cards.
const LEVEL_UP_ORACLE := {
	"normal": {
		"character": "berserk",
		"weapon": "sword",
		"mods": {},
		"rewards": [
			{"id": "crit_chance_up", "attr": "crit_chance", "mods": {"crit_chance_flat": 0.07}, "rows": ["Шанс крита: 7% -> 12% · реально: +5%", "сейчас 7% · максимум 55%"]},
			{"id": "vampiric_up", "attr": "vampiric", "mods": {"vampiric_amount_flat": 0.8, "vampiric_chance_flat": 0.05, "vampiric_heal_per_second_cap": 0.8}, "rows": ["Вампиризм: 0.00 -> 0.38 · реально: +0.38", "шанс срабатывания: сейчас 0% · максимум 20%", "Шанс срабатывания: 0% -> 5% (+5 пп)"]},
			{"id": "regeneration_up", "attr": "regeneration", "mods": {"regeneration_flat": 1.3}, "rows": ["Регенерация: 0.13 -> 0.48 · реально: +0.36"]},
		],
	},
	"ineligible": {
		"character": "dark_mage",
		"weapon": "cursed_skull",
		"mods": {},
		"rewards": [
			{"id": "damage_up", "attr": "damage", "mods": {"damage_multiplier": 1.15}, "rows": ["Увеличение урона: 8 -> 9 · реально: +1", "DoT/тик: 7.9 -> 9.1 (+15%)"]},
			{"id": "max_hp_up", "attr": "max_health", "mods": {"max_health_flat": 18.0}, "rows": ["Максимальное здоровье: 38 -> 56 · реально: +18"]},
			{"id": "regeneration_up", "attr": "regeneration", "mods": {"regeneration_flat": 1.3}, "rows": ["Регенерация: 0.15 -> 0.58 · реально: +0.43"]},
		],
	},
	"capped": {
		"character": "sniper",
		"weapon": "sniper_deadeye_rifle",
		"mods": {"crit_chance_flat": 5.0},
		"rewards": [
			{"id": "damage_up", "attr": "damage", "mods": {"damage_multiplier": 1.15}, "rows": ["Физический урон: 14 -> 16 · реально: +2", "DoT/тик: 6.0 -> 6.8 (+15%)"]},
			{"id": "max_hp_up", "attr": "max_health", "mods": {"max_health_flat": 18.0}, "rows": ["Максимальное здоровье: 88 -> 106 · реально: +18"]},
			{"id": "regeneration_up", "attr": "regeneration", "mods": {"regeneration_flat": 1.3}, "rows": ["Регенерация: 0.11 -> 0.43 · реально: +0.32"]},
		],
	},
}

const FORBIDDEN_LEVEL_UP_SELECTION := [
	{
		"name": "capped",
		"character": "sniper",
		"weapon": "sniper_deadeye_rifle",
		"mods": {"crit_chance_flat": 5.0},
		"candidate": {"id": "crit_chance_up", "attr": "crit_chance", "mods": {"crit_chance_flat": 0.07}},
	},
	{
		"name": "ineligible",
		"character": "dark_mage",
		"weapon": "cursed_skull",
		"mods": {},
		"candidate": {"id": "summon_amount_up", "attr": "summon_amount", "mods": {"summon_bonus": 2.0}},
	},
	{
		"name": "no_op",
		"character": "dark_mage",
		"weapon": "cursed_skull",
		"mods": {},
		"candidate": {"id": "damage_flat_up", "attr": "damage_flat", "mods": {"damage_flat": 4.0}},
	},
	{
		"name": "before_equals_after",
		"character": "assassin",
		"weapon": "shadow_daggers",
		"mods": {},
		"candidate": {"id": "attack_speed_up", "attr": "attack_speed", "mods": {"attack_speed_multiplier": 1.12}},
	},
	{
		"name": "zero_effective_delta",
		"character": "assassin",
		"weapon": "shadow_daggers",
		"mods": {},
		"candidate": {"id": "attack_speed_up", "attr": "attack_speed", "mods": {"attack_speed_multiplier": 1.12}},
	},
]

var _errors := PackedStringArray()
var _validated := 0
var _captured := 0
var _capture_hashes := {}
var _capture_names := {}
var _semantic_hashes := {}
var _long_copy_sentinels := {}
var _capture_teardown := QACaptureTeardown.new()
var _native_popup_observations := 0
var _native_popup_instance_ids := {}


func _fail(message: String) -> void:
	_errors.append(message)


func _initialize() -> void:
	var mutation_only := OS.get_cmdline_user_args().has(NATIVE_TOOLTIP_MUTATION_ARG)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVIDENCE_DIR))
	if mutation_only:
		if DisplayServer.get_name() == "headless":
			_fail("native popup mutation probe was started headless.")
		else:
			await _run_native_engine_popup_probe()
	else:
		if DisplayServer.get_name() == "headless":
			print("SKIPPED_HEADLESS_NATIVE_ONLY: engine-popup lifecycle requires a real root Window.")
		else:
			_clean_capture_evidence()
			await _run_native_engine_popup_probe()
			if _native_popup_observations <= 0:
				_fail("native popup probe never observed the positive-control engine popup.")
			await _assert_native_popup_source_mutation()
		await _run_forbidden_level_up_selection()
		for viewport_size in VIEWPORTS:
			for state in STATES:
				await _run_level_up(viewport_size, str(state))
				await _run_attribute_shop(viewport_size, str(state))
				await _run_pause_codex(viewport_size, str(state))
				await _run_hero_select(viewport_size, str(state))
		await _capture_teardown.release_windowed_audio(self)
		if _validated != 48:
			_fail("Validated %d runtime states instead of 48." % _validated)
		if _long_copy_sentinels.size() != 12:
			_fail("Injected %d unique long-copy sentinels instead of 12." % _long_copy_sentinels.size())
		if DisplayServer.get_name() != "headless":
			_validate_capture_inventory()
			_write_capture_manifest()
	if not _errors.is_empty():
		for error in _errors:
			push_error("[fan1927-matrix] %s" % error)
		push_error("FAN-1927 48-state UI matrix FAILED (%d/48 states, %d captures)." % [_validated, _captured])
		quit(1)
		return
	if mutation_only:
		_fail("native tooltip source mutation unexpectedly passed.")
		push_error("FAN-1927 native tooltip mutation unexpectedly passed.")
		quit(1)
		return
	print("FAN-1927 48-state UI matrix passed: %d/48 runtime states validated, %d PNG captures in %s (4 surfaces × 3 viewports × 4 states)." % [_validated, _captured, EVIDENCE_DIR])
	quit(0)


func _configured_tooltip_delay() -> float:
	return maxf(0.0, float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec", 0.7)))


func _node_script_path(node: Node) -> String:
	var script := node.get_script() as Script if node != null else null
	return script.resource_path if script != null else "<native>"


func _node_ancestry(node: Node) -> String:
	var parts := PackedStringArray()
	var current := node
	while current != null:
		parts.insert(0, "%s<%s>" % [current.name, current.get_class()])
		current = current.get_parent()
	return "/".join(parts)


func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	var current := node
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false


func _move_native_cursor(window: Window, position: Vector2) -> void:
	window.warp_mouse(position)
	await _settle(2)
	var motion := InputEventMouseMotion.new()
	motion.window_id = window.get_window_id()
	motion.position = position
	motion.global_position = position
	window.push_input(motion, true)
	await _settle(3)


func _popup_candidates(window: Window) -> Array:
	var candidates: Array = []
	if window == null:
		return candidates
	for node in window.find_children("*", "Window", true, false):
		var popup := node as Window
		if popup != null and popup != window:
			candidates.append(popup)
	return candidates


func _expected_tooltip_labels(expected_text: String) -> PackedStringArray:
	var stripped := expected_text.strip_edges()
	var newline := stripped.find("\n")
	var labels := PackedStringArray([stripped if newline == -1 else stripped.substr(0, newline)])
	if newline != -1:
		var body := stripped.substr(newline + 1).strip_edges()
		if not body.is_empty():
			labels.append(body)
	return labels


func _popup_label_texts(parent: Node) -> PackedStringArray:
	var texts := PackedStringArray()
	for node in parent.find_children("*", "Label", true, false):
		var label := node as Label
		if label != null and label.is_visible_in_tree() and not label.text.strip_edges().is_empty():
			texts.append(label.text)
	return texts


func _matching_global_tooltip_content(popup: Window, expected_text: String) -> Control:
	var expected_labels := _expected_tooltip_labels(expected_text)
	for node in popup.find_children("*", "Control", true, false):
		var content := node as Control
		if content == null or content.name != "GlobalTooltipContent" or not content.is_visible_in_tree():
			continue
		var actual_labels := _popup_label_texts(content)
		var matches := true
		for expected_label in expected_labels:
			if not actual_labels.has(expected_label):
				matches = false
				break
		if matches:
			return content
	return null


func _engine_tooltip_observations(window: Window, anchor: Control, expected_text: String) -> Array:
	var observations: Array = []
	for popup_value in _popup_candidates(window):
		var popup := popup_value as Window
		if not _is_descendant_of(popup, anchor):
			continue
		var labels := _popup_label_texts(popup)
		if popup == null or not popup.visible or labels.is_empty():
			continue
		observations.append({
			"content": _matching_global_tooltip_content(popup, expected_text),
			"labels": labels,
			"popup": popup,
		})
	return observations


func _native_popup_diagnostics(
	window: Window,
	anchor: Control,
	target_rect: Rect2,
	input_position: Vector2,
	elapsed_frames: int,
	phase: String
) -> String:
	var focused_window := Window.get_focused_window()
	var hovered := window.gui_get_hovered_control() if window != null else null
	var lines := PackedStringArray([
		"phase=%s focus(window=%s display=%s focused_window=%s)" % [
			phase,
			str(window.has_focus()) if window != null else "<none>",
			str(DisplayServer.window_is_focused(window.get_window_id())) if window != null else "<none>",
			"%s#%d" % [focused_window.name, focused_window.get_instance_id()] if focused_window != null else "<none>",
		],
		"window(instance=%d id=%d embedded=%s visible=%s size=%s path=%s) viewport(rid=%s instance=%d)" % [
			window.get_instance_id() if window != null else -1,
			window.get_window_id() if window != null else -1,
			str(window.is_embedded()) if window != null else "<none>",
			str(window.visible) if window != null else "<none>",
			str(window.size) if window != null else "<none>",
			str(window.get_path()) if window != null and window.is_inside_tree() else "<none>",
			str(window.get_viewport_rid()) if window != null else "<none>",
			window.get_instance_id() if window != null else -1,
		],
		"target_rect=%s input=%s configured_delay=%.3fs elapsed_frames=%d hovered=%s" % [
			target_rect,
			input_position,
			_configured_tooltip_delay(),
			elapsed_frames,
			_node_ancestry(hovered) if hovered != null else "<none>",
		],
	])
	var candidates := _popup_candidates(window)
	lines.append("popup_candidates=%d" % candidates.size())
	for popup_value in candidates:
		var popup := popup_value as Window
		lines.append("candidate instance=%d window_id=%d class=%s visible=%s path=%s ancestry=%s script=%s labels=%s" % [
			popup.get_instance_id(),
			popup.get_window_id(),
			popup.get_class(),
			str(popup.visible),
			str(popup.get_path()),
			_node_ancestry(popup),
			_node_script_path(popup),
			_popup_label_texts(popup),
		])
		for node in popup.find_children("*", "Control", true, false):
			var control := node as Control
			lines.append("  control class=%s path=%s ancestry=%s script=%s" % [
				control.get_class(),
				str(control.get_path()),
				_node_ancestry(control),
				_node_script_path(control),
			])
	return "\n".join(lines)


func _await_native_popup_state(
	window: Window,
	anchor: Control,
	expected_text: String,
	expect_exact: bool,
	input_position: Vector2,
	phase: String
) -> Dictionary:
	var start_frame := Engine.get_process_frames()
	await create_timer(_configured_tooltip_delay()).timeout
	var observed_by_id := {}
	for _frame in range(NATIVE_POPUP_SETTLE_FRAMES):
		var current := _engine_tooltip_observations(window, anchor, expected_text)
		for observation_value in current:
			var observation := observation_value as Dictionary
			var popup := observation["popup"] as Window
			observed_by_id[popup.get_instance_id()] = observation
			if expect_exact and observation["content"] != null:
				return {
					"elapsed_frames": Engine.get_process_frames() - start_frame,
					"observations": [observation],
				}
		if not expect_exact and not current.is_empty():
			break
		await process_frame
	var result: Array = []
	result.assign(observed_by_id.values())
	var elapsed_frames := Engine.get_process_frames() - start_frame
	if (expect_exact and result.all(func(observation: Dictionary) -> bool: return observation["content"] == null)) \
			or (not expect_exact and not result.is_empty()):
		print("NATIVE_POPUP_DIAGNOSTICS:\n%s" % _native_popup_diagnostics(
			window, anchor, anchor.get_global_rect(), input_position, elapsed_frames, phase))
	return {"elapsed_frames": elapsed_frames, "observations": result}


func _await_native_window_ready(window: Window) -> bool:
	window.show()
	window.grab_focus()
	for frame in range(NATIVE_WINDOW_READY_FRAMES):
		if frame % 15 == 0:
			window.grab_focus()
		if window.visible and window.can_draw() and not window.is_embedded() \
				and window.size.x > 0 and window.size.y > 0 \
				and window.has_focus() and DisplayServer.window_is_focused(window.get_window_id()):
			await _settle(3)
			return true
		await process_frame
	return false


func _teardown_native_popup_window(window: Window, popup_ids: Array, iteration: int) -> void:
	var window_instance_id := window.get_instance_id()
	window.hide()
	window.queue_free()
	await _settle(4)
	if instance_from_id(window_instance_id) != null:
		_fail("native popup iteration %d did not free its root Window." % iteration)
	for popup_id in popup_ids:
		if instance_from_id(int(popup_id)) != null:
			_fail("native popup iteration %d leaked popup instance %d." % [iteration, popup_id])


func _run_native_engine_popup_iteration(iteration: int) -> void:
	var window := Window.new()
	window.name = "FAN1975NativeTooltipWindow%d" % iteration
	window.title = "FantasyDisk FAN-1975 native tooltip probe %d" % iteration
	window.visible = false
	window.force_native = true
	window.unresizable = true
	window.size = Vector2i(1280, 720)
	root.add_child(window)
	if not await _await_native_window_ready(window):
		_fail("native popup iteration %d did not reach a visible focused native Window.\n%s" % [
			iteration,
			_native_popup_diagnostics(window, null, Rect2(), Vector2.ZERO, NATIVE_WINDOW_READY_FRAMES, "window_ready"),
		])
		await _teardown_native_popup_window(window, [], iteration)
		return

	var main := MAIN_SCENE.instantiate()
	window.add_child(main)
	await _settle(6)
	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", str(ProgressionData.weapon_ids("berserk")[0]))
	main.set("attribute_offer", ["strength", "agility"])
	main.ui._show_attribute_shop(Callable())
	await _settle(8)
	var offers := main.find_child("AttributeOffers", true, false) as Container
	var anchor := offers.get_child(0) as Control if offers != null and offers.get_child_count() > 0 else null
	if anchor == null:
		_fail("native popup iteration %d is missing the production Attribute Shop offer." % iteration)
		await _teardown_native_popup_window(window, [], iteration)
		return
	var tooltip_script := anchor.get_script() as Script
	if not bool(anchor.get_meta("global_tooltip_skin", false)) or tooltip_script == null \
			or tooltip_script.resource_path != GLOBAL_TOOLTIP_CONTROL_PATH:
		_fail("native popup iteration %d did not install GlobalTooltipControl on the production offer." % iteration)

	var target_position := anchor.get_global_rect().get_center()
	var outside_position := Vector2(8.0, 8.0)
	var original_has_host_route := anchor.has_meta("production_tooltip_host")
	var original_host_route = anchor.get_meta("production_tooltip_host", false)
	var original_tooltip_text := anchor.tooltip_text
	var popup_ids: Array = []

	await _move_native_cursor(window, outside_position)
	await _move_native_cursor(window, target_position)
	var baseline := await _await_native_popup_state(
		window, anchor, original_tooltip_text, false, target_position, "iteration_%d_baseline" % iteration)
	if not (baseline["observations"] as Array).is_empty():
		_fail("native baseline suppression observed an engine-created popup/window/content in iteration %d." % iteration)

	await _move_native_cursor(window, outside_position)
	anchor.set_meta("production_tooltip_host", false)
	var expected_tooltip_text := "%s\nFAN1975_NATIVE_ENGINE_POPUP_%d" % [original_tooltip_text, iteration]
	anchor.tooltip_text = expected_tooltip_text
	await _move_native_cursor(window, target_position)
	var positive := await _await_native_popup_state(
		window, anchor, expected_tooltip_text, true, target_position, "iteration_%d_positive" % iteration)
	var positive_observations := positive["observations"] as Array
	var exact_observations := positive_observations.filter(
		func(observation: Dictionary) -> bool: return observation["content"] != null)
	if exact_observations.is_empty():
		_fail("native popup positive control did not observe exact non-empty GlobalTooltipContent in iteration %d.\n%s" % [
			iteration,
			_native_popup_diagnostics(window, anchor, anchor.get_global_rect(), target_position,
				int(positive["elapsed_frames"]), "iteration_%d_positive" % iteration),
		])
	else:
		for observation_value in exact_observations:
			var observation := observation_value as Dictionary
			var popup := observation["popup"] as Window
			var popup_id := popup.get_instance_id()
			if _native_popup_instance_ids.has(popup_id):
				_fail("native popup iteration %d reused stale popup instance %d." % [iteration, popup_id])
			_native_popup_instance_ids[popup_id] = true
			popup_ids.append(popup_id)
		_native_popup_observations += 1
		print("NATIVE_ENGINE_POPUP_OBSERVED: iteration=%d popup=%d elapsed_frames=%d" % [
			iteration,
			popup_ids[0],
			int(positive["elapsed_frames"]),
		])

	if original_has_host_route:
		anchor.set_meta("production_tooltip_host", original_host_route)
	else:
		anchor.remove_meta("production_tooltip_host")
	anchor.tooltip_text = original_tooltip_text
	await _move_native_cursor(window, outside_position)
	await _move_native_cursor(window, target_position)
	var restored := await _await_native_popup_state(
		window, anchor, original_tooltip_text, false, target_position, "iteration_%d_restored" % iteration)
	if not (restored["observations"] as Array).is_empty():
		_fail("native popup remained after production_tooltip_host was restored in iteration %d." % iteration)
	await _move_native_cursor(window, outside_position)
	await _teardown_native_popup_window(window, popup_ids, iteration)


func _run_native_engine_popup_probe() -> void:
	if root as Window == null:
		_fail("native popup probe requires SceneTree.root to be a Window.")
		return
	for iteration in range(1, NATIVE_TOOLTIP_ITERATIONS + 1):
		await _run_native_engine_popup_iteration(iteration)


func _assert_native_popup_source_mutation() -> void:
	var path := ProjectSettings.globalize_path(GLOBAL_TOOLTIP_CONTROL_PATH)
	var source := FileAccess.get_file_as_string(path)
	var suppressed := "if bool(get_meta(\"production_tooltip_host\", false)):\n\t\treturn Control.new()"
	var escaped := "if bool(get_meta(\"production_tooltip_host\", false)):\n\t\treturn GlobalTooltip.make_tooltip_content(for_text, self)"
	if source.count(suppressed) != 1:
		_fail("native popup source mutation could not locate the single suppression branch.")
		return
	var mutation_file := FileAccess.open(path, FileAccess.WRITE)
	if mutation_file == null:
		_fail("native popup source mutation could not open GlobalTooltipControl for a disposable write.")
		return
	mutation_file.store_string(source.replace(suppressed, escaped))
	mutation_file.close()
	var output: Array = []
	var exit_code := OS.execute(OS.get_executable_path(), [
		"--path", ProjectSettings.globalize_path("res://"),
		"--script", ProjectSettings.globalize_path("res://tests/attribute_ui_matrix_fan1927_test.gd"),
		"--", NATIVE_TOOLTIP_MUTATION_ARG,
	], output, true)
	var restore_file := FileAccess.open(path, FileAccess.WRITE)
	if restore_file == null:
		_fail("native popup source mutation could not restore GlobalTooltipControl.")
		return
	restore_file.store_string(source)
	restore_file.close()
	var mutation_output := "\n".join(output)
	if exit_code == 0 or not mutation_output.contains("native baseline suppression observed an engine-created popup/window/content"):
		_fail("native popup source mutation did not make the matrix fail on the observed engine popup (exit %d)." % exit_code)
	else:
		print("NATIVE_POPUP_SOURCE_MUTATION_REJECTED: observed engine popup, child exit=%d" % exit_code)


func _clean_capture_evidence() -> void:
	var directory := DirAccess.open(EVIDENCE_DIR)
	if directory == null:
		return
	for file_name in directory.get_files():
		if file_name.ends_with(".png") or file_name == "manifest.json":
			directory.remove(file_name)


func _expected_capture_names() -> Dictionary:
	var expected := {}
	for viewport_size in VIEWPORTS:
		for state in STATES:
			for surface in ["level_up", "attribute_shop", "pause_codex", "hero_select"]:
				expected["%s_%dx%d_%s.png" % [surface, viewport_size.x, viewport_size.y, state]] = true
	return expected


func _validate_capture_inventory() -> void:
	var expected := _expected_capture_names()
	if _captured != 48 or _capture_names.size() != 48:
		_fail("Native matrix produced %d captures/%d unique names instead of 48." % [_captured, _capture_names.size()])
	for file_name in expected:
		if not _capture_names.has(file_name):
			_fail("Capture manifest is missing '%s'." % file_name)
	for file_name in _capture_names:
		if not expected.has(file_name):
			_fail("Capture manifest contains unexpected PNG '%s'." % file_name)
	var directory := DirAccess.open(EVIDENCE_DIR)
	if directory == null:
		_fail("Capture evidence directory cannot be opened.")
		return
	var disk_names := {}
	for file_name in directory.get_files():
		if file_name.ends_with(".png"):
			disk_names[file_name] = true
	if disk_names.size() != 48:
		_fail("Capture evidence directory contains %d PNGs instead of 48." % disk_names.size())
	for file_name in disk_names:
		if not expected.has(file_name):
			_fail("Capture evidence directory contains stale PNG '%s'." % file_name)


func _write_capture_manifest() -> void:
	var records: Array = []
	var capture_keys: Array = _capture_hashes.keys()
	capture_keys.sort()
	for key in capture_keys:
		records.append({"state": key, "sha256": _capture_hashes[key]})
	var semantic_records: Array = []
	var semantic_keys: Array = _semantic_hashes.keys()
	semantic_keys.sort()
	for key in semantic_keys:
		semantic_records.append({"state": key, "sha256": _semantic_hashes[key]})
	var sentinel_values: Array = _long_copy_sentinels.keys()
	sentinel_values.sort()
	var manifest_path := ProjectSettings.globalize_path("%s/manifest.json" % EVIDENCE_DIR)
	var manifest := FileAccess.open(manifest_path, FileAccess.WRITE)
	if manifest == null:
		_fail("Could not write capture manifest '%s'." % manifest_path)
		return
	manifest.store_string(JSON.stringify({
		"captures": records,
		"semantic_states": semantic_records,
		"long_copy_sentinels": sentinel_values,
	}, "\t"))


func _long_copy_fixture(surface: String, viewport_size: Vector2i) -> Dictionary:
	var sentinel := "FAN1945_%s_%dx%d_LONG_COPY_END." % [surface.to_upper(), viewport_size.x, viewport_size.y]
	if _long_copy_sentinels.has(sentinel):
		_fail("%s %s: duplicate long-copy sentinel." % [surface, viewport_size])
	_long_copy_sentinels[sentinel] = true
	var paragraph := "Длинное русское описание сохраняет все числа, условия и объяснения без сокращения. "
	return {
		"sentinel": sentinel,
		"text": "%s\n%s" % [paragraph.repeat(48), sentinel],
	}


func _new_fixture(viewport_size: Vector2i) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	for _index in range(3):
		await process_frame
	return {"viewport": viewport, "main": main}


func _teardown(fixture: Dictionary) -> void:
	var viewport := fixture.get("viewport") as SubViewport
	for error in await _capture_teardown.release_viewport(self, viewport):
		_fail(str(error))


func _settle(frames := 4) -> void:
	for _index in range(frames):
		await process_frame


func _terminal_scroll_errors(scroll: ScrollContainer, label: Label, sentinel: String, maximum: float) -> Array:
	var errors: Array = []
	if absf(float(scroll.scroll_vertical) - maximum) > 0.01:
		errors.append("scroll stopped at %d instead of the exact end %.1f" % [scroll.scroll_vertical, maximum])
	errors.append_array(_sentinel_readability_errors(label, sentinel, _effective_scroll_rect(scroll)))
	return errors


func _assert_scroll_reaches_sentinel(scroll: ScrollContainer, label: Label, sentinel: String, context: String) -> void:
	if scroll == null or label == null:
		_fail("%s: long-copy scroll/label is missing." % context)
		return
	await _settle(3)
	var scrollbar := scroll.get_v_scroll_bar()
	var max_scroll := maxf(0.0, scrollbar.max_value - scrollbar.page)
	if max_scroll <= 1.0:
		_fail("%s: long copy has no positive scroll range (max %.1f, page %.1f)." % [context, scrollbar.max_value, scrollbar.page])
		return
	if not label.text.ends_with(sentinel):
		_fail("%s: unique sentinel is absent from the preconstructed disclosure." % context)
		return
	scroll.scroll_vertical = int(ceilf(max_scroll))
	await _settle(2)
	var settled_max := int(ceilf(maxf(0.0, scrollbar.max_value - scrollbar.page)))
	for error in _terminal_scroll_errors(scroll, label, sentinel, float(settled_max)):
		_fail("%s: %s." % [context, error])
	var one_pixel_short := settled_max - 1
	if one_pixel_short >= 0:
		scroll.scroll_vertical = one_pixel_short
		await _settle(2)
		if _terminal_scroll_errors(scroll, label, sentinel, float(settled_max)).is_empty():
			_fail("%s: one-pixel maximum-scroll shortfall did not fail the exact terminal oracle." % context)
		scroll.scroll_vertical = settled_max
		await _settle(2)


func _image_has_variance(image: Image) -> bool:
	var first := image.get_pixel(0, 0)
	var step_x := maxi(1, image.get_width() / 16)
	var step_y := maxi(1, image.get_height() / 16)
	for y in range(0, image.get_height(), step_y):
		for x in range(0, image.get_width(), step_x):
			if not image.get_pixel(x, y).is_equal_approx(first):
				return true
	return false


func _read_capture_image(viewport: SubViewport) -> Image:
	var image: Image = null
	for _attempt in range(4):
		RenderingServer.force_draw(false)
		await _settle(2)
		image = viewport.get_texture().get_image()
		if image != null and not image.is_empty() and _image_has_variance(image):
			return image
	return image


func _capture(fixture: Dictionary, surface: String, viewport_size: Vector2i, state: String, semantic_text: String, sentinel := "") -> void:
	_validated += 1
	var pair_key := "%s_%dx%d" % [surface, viewport_size.x, viewport_size.y]
	if state == "normal" or state == "long_copy":
		var semantic_key := "%s_%s" % [pair_key, state]
		_semantic_hashes[semantic_key] = semantic_text.sha256_text()
		if state == "long_copy":
			if sentinel == "" or not semantic_text.contains(sentinel):
				_fail("%s: long-copy semantic state lacks its unique sentinel." % pair_key)
			var normal_semantic_key := "%s_normal" % pair_key
			if not _semantic_hashes.has(normal_semantic_key):
				_fail("%s: normal semantic state was not recorded before long-copy." % pair_key)
			elif _semantic_hashes[normal_semantic_key] == _semantic_hashes[semantic_key]:
				_fail("%s: normal/long-copy semantic hashes are identical." % pair_key)
	# Канон repo (hero_select_scrum1064): headless-гейт проверяет контент/
	# геометрию всех состояний; PNG-evidence рендерится при живом DisplayServer
	# (Metal): Godot --path . --script res://tests/attribute_ui_matrix_fan1927_test.gd
	if DisplayServer.get_name() == "headless":
		return
	var viewport := fixture.get("viewport") as SubViewport
	if viewport == null:
		return
	# Даём intro-твинам поверхности завершиться перед снимком.
	await _settle(40)
	var image := await _read_capture_image(viewport)
	if image == null or image.is_empty():
		_fail("%s %s %s: Metal capture returned no image." % [surface, viewport_size, state])
		return
	if image.get_size() != viewport_size:
		_fail("%s %s %s: capture size %s does not match viewport." % [surface, viewport_size, state, image.get_size()])
	if not _image_has_variance(image):
		_fail("%s %s %s: capture is a uniform frame, not reviewable UI evidence." % [surface, viewport_size, state])
	var file_name := "%s_%dx%d_%s.png" % [surface, viewport_size.x, viewport_size.y, state]
	var absolute_path := ProjectSettings.globalize_path("%s/%s" % [EVIDENCE_DIR, file_name])
	var save_error := image.save_png(absolute_path)
	if save_error != OK:
		_fail("%s: save_png failed with %s." % [file_name, error_string(save_error)])
		return
	if _capture_names.has(file_name):
		_fail("Duplicate capture name '%s'." % file_name)
	_capture_names[file_name] = true
	var capture_key := "%s_%s" % [pair_key, state]
	_capture_hashes[capture_key] = FileAccess.get_sha256(absolute_path)
	if state == "long_copy":
		var normal_capture_key := "%s_normal" % pair_key
		if not _capture_hashes.has(normal_capture_key):
			_fail("%s: normal capture hash was not recorded before long-copy." % pair_key)
		elif _capture_hashes[normal_capture_key] == _capture_hashes[capture_key]:
			_fail("%s: normal/long-copy PNG hashes are identical." % pair_key)
	_captured += 1


func _reward_for_attr(attr_id: String) -> Dictionary:
	for reward in ProgressionData.LEVEL_UP_REWARDS:
		if str(reward.get("attr", "")) == attr_id:
			return reward.duplicate(true)
	return {}


func _reward_for_id(reward_id: String) -> Dictionary:
	for reward in ProgressionData.LEVEL_UP_REWARDS:
		if str(reward.get("id", "")) == reward_id:
			return reward.duplicate(true)
	return {}


func _offer_attrs(offer: Array) -> Array:
	var attrs: Array = []
	for reward in offer:
		attrs.append(str((reward as Dictionary).get("attr", "")))
	return attrs


func _level_up_oracle_for_state(state: String) -> Dictionary:
	return LEVEL_UP_ORACLE["normal" if state == "long_copy" else state]


func _oracle_level_up_offer(state: String, first_description := "") -> Array:
	var oracle := _level_up_oracle_for_state(state)
	var offer: Array = []
	for index in range((oracle["rewards"] as Array).size()):
		var expected_value = (oracle["rewards"] as Array)[index]
		var expected := expected_value as Dictionary
		var reward := _reward_for_id(str(expected["id"]))
		if reward.is_empty():
			_fail("level_up %s: oracle reward '%s' is missing from the registry." % [state, expected["id"]])
			continue
		if str(reward.get("attr", "")) != str(expected["attr"]) or reward.get("mods", {}) != expected["mods"]:
			_fail("level_up %s: oracle reward '%s' contract drifted (attr/mods)." % [state, expected["id"]])
		if index == 0 and first_description != "":
			reward["description"] = first_description
		offer.append(reward)
	return offer


func _no_trim(label: Label, context: String) -> void:
	if label == null:
		_fail("%s: label missing." % context)
		return
	if label.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
		_fail("%s: presentation label must use OVERRUN_NO_TRIMMING." % context)


func _run_forbidden_level_up_selection() -> void:
	for scenario_value in FORBIDDEN_LEVEL_UP_SELECTION:
		var scenario := scenario_value as Dictionary
		var fixture := await _new_fixture(Vector2i(1280, 720))
		var main: Node = fixture["main"]
		var character_id := str(scenario["character"])
		var candidate := (scenario["candidate"] as Dictionary).duplicate(true)
		main.set("selected_character_id", character_id)
		main.set("selected_weapon_id", str(scenario["weapon"]))
		main.set("run_player_snapshot", {
			"stats": ProgressionData.base_stats(character_id),
			"run_modifiers": (scenario["mods"] as Dictionary).duplicate(true),
		})
		main.set("pending_level_ups", 1)
		main.set("level_up_offer", [candidate])
		main.ui._show_level_up_screen(false)
		await _settle()
		var selected: Array = main.get("level_up_offer")
		var candidate_id := str(candidate["id"])
		if selected.any(func(reward: Dictionary) -> bool: return str(reward.get("id", "")) == candidate_id):
			_fail("level_up %s: forbidden candidate '%s' reached the production selection path." % [scenario["name"], candidate_id])
		if selected.size() != 3:
			_fail("level_up %s: rejected candidate did not regenerate a complete three-card offer." % scenario["name"])
		await _teardown(fixture)


func _sentinel_glyph_rect(label: Label, sentinel: String) -> Rect2:
	if label == null or sentinel == "":
		return Rect2()
	var start := label.text.find(sentinel)
	if start < 0:
		return Rect2()
	var glyph_rect := label.get_character_bounds(start)
	for index in range(start + 1, start + sentinel.length()):
		glyph_rect = glyph_rect.merge(label.get_character_bounds(index))
	return Rect2(label.get_global_rect().position + glyph_rect.position, glyph_rect.size).grow(1.0)


func _sentinel_readability_errors(label: Label, sentinel: String, effective_rect: Rect2) -> Array:
	var errors: Array = []
	if label == null or sentinel == "":
		return ["terminal sentinel label is missing"]
	var start := label.text.find(sentinel)
	if start < 0:
		return ["terminal sentinel is absent"]
	for index in range(start, start + sentinel.length()):
		var local_rect := label.get_character_bounds(index)
		var glyph_rect := Rect2(label.get_global_rect().position + local_rect.position, local_rect.size)
		if not glyph_rect.has_area() or not effective_rect.encloses(glyph_rect):
			errors.append("terminal sentinel glyph %d %s is not fully readable in %s" % [index - start, glyph_rect, effective_rect])
	return errors


func _effective_scroll_rect(scroll: ScrollContainer) -> Rect2:
	if scroll == null:
		return Rect2()
	var effective := scroll.get_global_rect()
	var scrollbar := scroll.get_v_scroll_bar()
	if scrollbar != null and scrollbar.visible and scrollbar.get_global_rect().has_area():
		effective.size.x = maxf(0.0, scrollbar.get_global_rect().position.x - effective.position.x)
	return effective


func _visible_glyph_errors(label: Label, clip_rect: Rect2, effective_rect: Rect2) -> Array:
	var errors: Array = []
	if label == null:
		return ["tooltip label is missing"]
	for index in range(label.text.length()):
		var local_rect := label.get_character_bounds(index)
		var glyph_rect := Rect2(label.get_global_rect().position + local_rect.position, local_rect.size)
		var visible_part := glyph_rect.intersection(clip_rect)
		if visible_part.has_area() and not effective_rect.encloses(visible_part):
			errors.append("visible glyph %d %s leaves effective clip %s" % [index, visible_part, effective_rect])
	return errors


func _reserve_contract_errors(texture_safe: Rect2, strict_inner: Rect2, viewport_size: Vector2) -> Array:
	var reserve := 32.0 if viewport_size.y >= 1200.0 else 24.0
	var expected := texture_safe.grow(-reserve)
	if expected.is_equal_approx(strict_inner):
		return []
	return ["strict inner %s does not match %dpx reserve inside %s" % [strict_inner, reserve, texture_safe]]


func _engine_tooltip_errors(anchor: Control) -> Array:
	if anchor != null and anchor.tooltip_text.is_empty():
		return []
	if anchor != null and bool(anchor.get_meta("production_tooltip_host", false)) \
			and bool(anchor.get_meta("global_tooltip_skin", false)) \
			and anchor.get_script() != null \
			and anchor.get_script().resource_path == GLOBAL_TOOLTIP_CONTROL_PATH:
		return []
	return ["engine tooltip popup route is not suppressed by the installed production control"]


func _control_is_within(candidate: Control, ancestor: Control) -> bool:
	var current: Node = candidate
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false


func _first_button(control: Control) -> Control:
	if control == null:
		return null
	for child in control.find_children("*", "Button", true, false):
		var button := child as Button
		if button != null and button.visible and not button.disabled:
			return button
	return null


func _push_mouse_motion(viewport: Viewport, position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	viewport.push_input(motion, true)
	await _settle(3)


func _push_mouse_wheel(viewport: Viewport, position: Vector2) -> void:
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.factor = 1.0
	wheel.position = position
	wheel.global_position = position
	viewport.push_input(wheel, true)
	await _settle(3)


func _tooltip_host_errors(host: Control, scroll: ScrollContainer, label: Label, sentinel: String, strict_inner: Rect2, safe_parent: Rect2, protected_rects: Array[Rect2]) -> Array:
	var errors: Array = []
	if host == null or scroll == null or label == null:
		errors.append("production tooltip host/scroll/label is missing")
		return errors
	var host_rect := host.get_global_rect()
	var scroll_rect := scroll.get_global_rect()
	var effective_rect := _effective_scroll_rect(scroll)
	if not strict_inner.encloses(host_rect) or not safe_parent.encloses(host_rect):
		errors.append("host %s leaves strict content zone %s" % [host_rect, strict_inner])
	if not strict_inner.encloses(effective_rect) or not safe_parent.encloses(effective_rect):
		errors.append("effective scroll %s leaves strict content zone %s" % [effective_rect, strict_inner])
	if host.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		errors.append("passive tooltip host must ignore mouse input")
	if scroll.mouse_filter != Control.MOUSE_FILTER_STOP:
		errors.append("interactive tooltip scroll must stop mouse input")
	if label.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		errors.append("tooltip label must ignore mouse input")
	if label.text.count(sentinel) != 1 or not label.text.ends_with(sentinel):
		errors.append("terminal sentinel must occur exactly once at the disclosure tail")
	var glyph_rect := _sentinel_glyph_rect(label, sentinel)
	if not glyph_rect.has_area() or not effective_rect.encloses(glyph_rect):
		errors.append("terminal sentinel glyphs %s are not fully visible in %s" % [glyph_rect, effective_rect])
	errors.append_array(_visible_glyph_errors(label, scroll_rect, effective_rect))
	for protected_rect in protected_rects:
		for rect in [host_rect, effective_rect, glyph_rect]:
			if rect.has_area() and rect.intersects(protected_rect):
				errors.append("tooltip rect %s intersects protected rect %s" % [rect, protected_rect])
	return errors


func _assert_production_tooltip_host(host: Control, scroll: ScrollContainer, label: Label, sentinel: String, texture_safe: Rect2, strict_inner: Rect2, safe_parent: Rect2, protected_rects: Array[Rect2], context: String) -> void:
	for error in _reserve_contract_errors(texture_safe, strict_inner, host.get_viewport_rect().size):
		_fail("%s: %s." % [context, error])
	for error in _tooltip_host_errors(host, scroll, label, sentinel, strict_inner, safe_parent, protected_rects):
		_fail("%s: %s." % [context, error])
	if host == null or scroll == null:
		return
	if _reserve_contract_errors(texture_safe, strict_inner.grow(1.0), host.get_viewport_rect().size).is_empty():
		_fail("%s: incorrect ornament reserve did not fail the oracle." % context)
	var original_position := host.global_position
	host.global_position = Vector2.ZERO
	await _settle(2)
	if _tooltip_host_errors(host, scroll, label, sentinel, strict_inner, safe_parent, protected_rects).is_empty():
		_fail("%s: moving the production host into a forbidden zone did not fail the oracle." % context)
	host.global_position = original_position
	await _settle(2)
	if not protected_rects.is_empty():
		host.global_position = protected_rects[0].get_center() - host.size * 0.5
		await _settle(2)
		if _tooltip_host_errors(host, scroll, label, sentinel, strict_inner, safe_parent, protected_rects).is_empty():
			_fail("%s: full protected-band overlap did not fail the oracle." % context)
		host.global_position = original_position
		await _settle(2)
	var scrollbar := scroll.get_v_scroll_bar()
	var end_scroll := int(ceilf(maxf(0.0, scrollbar.max_value - scrollbar.page)))
	scroll.scroll_vertical = 0
	await _settle(2)
	if _tooltip_host_errors(host, scroll, label, sentinel, strict_inner, safe_parent, protected_rects).is_empty():
		_fail("%s: clipping the terminal sentinel glyphs did not fail the oracle." % context)
	scroll.scroll_vertical = end_scroll
	await _settle(2)
	var original_text := label.text
	label.text += sentinel
	await _settle(2)
	if _tooltip_host_errors(host, scroll, label, sentinel, strict_inner, safe_parent, protected_rects).is_empty():
		_fail("%s: duplicate sentinel did not fail the oracle." % context)
	label.text = original_text
	await _settle(2)
	var scrollbar_lane := scroll.get_v_scroll_bar()
	if scrollbar_lane == null or not scrollbar_lane.visible or not scrollbar_lane.get_global_rect().has_area():
		_fail("%s: long-copy scrollbar lane is not visible for the glyph mutation." % context)
	else:
		var original_label_position := label.global_position
		var terminal_glyph := _sentinel_glyph_rect(label, sentinel)
		label.global_position = original_label_position + Vector2(
			scrollbar_lane.get_global_rect().get_center().x - terminal_glyph.get_center().x, 0.0)
		await _settle(2)
		if _tooltip_host_errors(host, scroll, label, sentinel, strict_inner, safe_parent, protected_rects).is_empty():
			_fail("%s: visible glyph in the scrollbar lane did not fail the production oracle." % context)
		label.global_position = original_label_position
		await _settle(2)
	for error in _tooltip_host_errors(host, scroll, label, sentinel, strict_inner, safe_parent, protected_rects):
		_fail("%s: restored production host failed: %s." % [context, error])


func _assert_real_hover_and_input(viewport: Viewport, anchor: Control, host: Control, scroll: ScrollContainer, action: Control, require_host_open: bool, wheel_at_anchor: bool, context: String) -> void:
	if viewport == null or anchor == null or host == null or scroll == null or action == null:
		_fail("%s: production input nodes are missing." % context)
		return
	await _push_mouse_motion(viewport, Vector2(1.0, 1.0))
	var original_filter := anchor.mouse_filter
	if require_host_open:
		host.visible = false
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	await _push_mouse_motion(viewport, anchor.get_global_rect().get_center())
	if require_host_open and host.visible:
		_fail("%s: broken hover wiring did not fail the oracle." % context)
	anchor.mouse_filter = original_filter
	await _push_mouse_motion(viewport, anchor.get_global_rect().get_center())
	if not _control_is_within(viewport.gui_get_hovered_control(), anchor):
		_fail("%s: coordinate hit-testing did not reach the production hover control." % context)
	if not host.visible:
		_fail("%s: real hover did not open the production tooltip host." % context)
	for error in _engine_tooltip_errors(anchor):
		_fail("%s: %s." % [context, error])
	var original_tooltip := anchor.tooltip_text
	var original_host_route := bool(anchor.get_meta("production_tooltip_host", false))
	var original_skin := bool(anchor.get_meta("global_tooltip_skin", false))
	var original_script: Script = anchor.get_script()
	if original_tooltip.is_empty():
		anchor.tooltip_text = "FAN1973_ENGINE_POPUP_MUTATION"
	else:
		anchor.set_meta("production_tooltip_host", false)
	if _engine_tooltip_errors(anchor).is_empty():
		_fail("%s: restored engine-tooltip route did not fail the oracle." % context)
	anchor.tooltip_text = original_tooltip
	anchor.set_meta("production_tooltip_host", original_host_route)
	if not original_tooltip.is_empty():
		anchor.set_meta("global_tooltip_skin", false)
		if _engine_tooltip_errors(anchor).is_empty():
			_fail("%s: manual-host mutation did not fail the oracle." % context)
		anchor.set_meta("global_tooltip_skin", original_skin)
		anchor.set_script(null)
		if _engine_tooltip_errors(anchor).is_empty():
			_fail("%s: preload-bypass mutation did not fail the oracle." % context)
		anchor.set_script(original_script)
	var before_scroll := scroll.scroll_vertical
	var wheel_position := anchor.get_global_rect().get_center() if wheel_at_anchor else scroll.get_global_rect().get_center()
	if not wheel_at_anchor:
		await _push_mouse_motion(viewport, wheel_position)
	await _push_mouse_wheel(viewport, wheel_position)
	if scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page + 1.0 and scroll.scroll_vertical <= before_scroll:
		_fail("%s: real wheel input did not scroll the production host." % context)
	await _push_mouse_motion(viewport, action.get_global_rect().get_center())
	var hovered_action := viewport.gui_get_hovered_control()
	if not _control_is_within(hovered_action, action):
		_fail("%s: action/control coordinate input was intercepted (action=%s rect=%s hovered=%s)." % [
			context,
			action.name,
			action.get_global_rect(),
			hovered_action.name if hovered_action != null else "<none>",
		])
	await _push_mouse_motion(viewport, anchor.get_global_rect().get_center())


func _attribute_shop_detail_copy(main: Node, offer: Button) -> String:
	var stat_id := offer.name.trim_prefix("AttributeOffer_")
	var interpretation := ProgressionData.class_interpretation_text(str(main.get("selected_character_id")), stat_id)
	var active_offers: Array = main.get("attribute_offer")
	for offer_value in active_offers:
		if offer_value is Dictionary and str((offer_value as Dictionary).get("id", "")) == stat_id:
			interpretation = str((offer_value as Dictionary).get("interpretation", interpretation))
	var detail := AttributeSurfaces.shop_card_detail_text(
		str(ProgressionData.STAT_NAMES.get(stat_id, stat_id)),
		int(main.ui._attribute_buy_cost()),
		"",
		str(main.ui._attribute_influence_text(stat_id)),
		main.ui._attribute_upgrade_preview_lines(stat_id, 1.0, 99)
	)
	return "%s\n%s" % [detail, interpretation] if interpretation != "" else detail


func _assert_attribute_shop_hover_transition(viewport: Viewport, anchor: Button, drawer: Control, label: Label, baseline_copy: String, expected_copy: String, compact: bool, context: String) -> void:
	if viewport == null or anchor == null or drawer == null or label == null:
		_fail("%s: Attribute Shop causal hover nodes are missing." % context)
		return
	if baseline_copy.strip_edges() == "" or expected_copy.strip_edges() == "" or baseline_copy == expected_copy:
		_fail("%s: Attribute Shop baseline/hovered exact copies are not distinct." % context)
		return
	await _push_mouse_motion(viewport, Vector2(1.0, 1.0))
	if compact:
		drawer.set_meta("detail_drawer_open", false)
		drawer.visible = false
	elif not drawer.visible:
		_fail("%s: persistent Attribute Shop drawer was closed before the hover probe." % context)
	var original_filter := anchor.mouse_filter
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	await _push_mouse_motion(viewport, anchor.get_global_rect().get_center())
	if compact:
		if drawer.visible or label.text != baseline_copy:
			_fail("%s: broken hover wiring changed the compact closed baseline." % context)
	elif not drawer.visible or label.text != baseline_copy:
		_fail("%s: broken hover wiring changed the persistent drawer baseline." % context)
	anchor.mouse_filter = original_filter
	await _push_mouse_motion(viewport, anchor.get_global_rect().get_center())
	if not _control_is_within(viewport.gui_get_hovered_control(), anchor):
		_fail("%s: coordinate hit-testing did not reach the alternate Attribute Shop offer." % context)
	if not drawer.visible or label.text != expected_copy:
		_fail("%s: real hover did not cause the exact expected Attribute Shop disclosure transition." % context)


func _install_translation(message: String) -> Translation:
	var translation := Translation.new()
	translation.locale = TranslationServer.get_locale()
	translation.add_message("hero_select_capability_format", "%%s\n%s" % message)
	TranslationServer.add_translation(translation)
	return translation


func _content_safe_rect(control: Control, style_name: String) -> Rect2:
	var style := control.get_theme_stylebox(style_name)
	var rect := control.get_global_rect()
	return Rect2(
		rect.position + Vector2(style.get_content_margin(SIDE_LEFT), style.get_content_margin(SIDE_TOP)),
		rect.size - Vector2(
			style.get_content_margin(SIDE_LEFT) + style.get_content_margin(SIDE_RIGHT),
			style.get_content_margin(SIDE_TOP) + style.get_content_margin(SIDE_BOTTOM)
		)
	).grow(1.0)


func _level_up_geometry_errors(
		row_rect: Rect2,
		viewport_rect: Rect2,
		panel_safe: Rect2,
		card_safe: Rect2,
		drawer_rect: Rect2
) -> PackedStringArray:
	var errors := PackedStringArray()
	if not viewport_rect.encloses(row_rect):
		errors.append("row leaves viewport")
	if not panel_safe.encloses(row_rect):
		errors.append("row leaves LevelUpPanel safe area")
	if not card_safe.encloses(row_rect):
		errors.append("row leaves reward-card safe area")
	if drawer_rect.has_area() and drawer_rect.intersects(row_rect):
		errors.append("LU.DetailDrawer intersects mandatory effect row")
	return errors


# ---------------------------------------------------------------- Level Up ---

func _run_level_up(viewport_size: Vector2i, state: String) -> void:
	var fixture := await _new_fixture(viewport_size)
	var main: Node = fixture["main"]
	var context := "level_up %s %s" % [viewport_size, state]
	var oracle := _level_up_oracle_for_state(state)
	var character_id := str(oracle["character"])
	var weapon_id := str(oracle["weapon"])
	var sentinel := ""
	var long_fixture_text := ""
	if state == "long_copy":
		var long_fixture := _long_copy_fixture("level_up", viewport_size)
		sentinel = str(long_fixture["sentinel"])
		long_fixture_text = str(long_fixture["text"])
	main.set("selected_character_id", character_id)
	main.set("selected_weapon_id", weapon_id)
	main.set("run_player_snapshot", {
		"stats": ProgressionData.base_stats(character_id),
		"run_modifiers": (oracle["mods"] as Dictionary).duplicate(true),
	})
	main.set("pending_level_ups", 1)
	main.set("level_up_offer", _oracle_level_up_offer(state, long_fixture_text))
	main.ui._show_level_up_screen(false)
	await _settle()

	var offer: Array = main.get("level_up_offer")
	if offer.size() != 3:
		_fail("%s: offer has %d cards, expected 3." % [context, offer.size()])
	var actual_ids: Array = offer.map(func(reward: Dictionary) -> String: return str(reward.get("id", "")))
	var expected_ids: Array = (oracle["rewards"] as Array).map(func(reward: Dictionary) -> String: return str(reward["id"]))
	if actual_ids != expected_ids:
		_fail("%s: fail-closed oracle expected rewards %s, got %s." % [context, expected_ids, actual_ids])

	var drawer := main.find_child("LevelUpDetailDrawer", true, false) as PanelContainer
	var drawer_scroll := main.find_child("LevelUpDetailScroll", true, false) as ScrollContainer
	var drawer_label := main.find_child("LevelUpDetailLabel", true, false) as Label
	if drawer == null or drawer_scroll == null or drawer_label == null:
		_fail("%s: LU.DetailDrawer (panel/scroll/label) is missing." % context)
	else:
		_no_trim(drawer_label, "%s drawer" % context)
		if not drawer.visible and bool(drawer.get_meta("lu_drawer_overlay", false)):
			var first_card := main.find_child("LevelUpRewardButton0", true, false) as Button
			if first_card != null:
				first_card.grab_focus()
				await _settle(2)
		if not drawer.visible:
			_fail("%s: LU.DetailDrawer is hidden at an approved viewport." % context)
		elif str(drawer_label.text).strip_edges() == "":
			_fail("%s: LU.DetailDrawer has no focused-card copy." % context)

	var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
	var level_panel := main.find_child("LevelUpPanel", true, false) as Control
	var panel_safe := _content_safe_rect(level_panel, "panel") if level_panel != null else Rect2()
	var drawer_rect := drawer.get_global_rect() if drawer != null and drawer.visible else Rect2()
	var overlap_probe_run := false
	# Enumerate every mandatory row, including LevelUpRewardEffectText2/3.
	for card_index in range(3):
		var card := main.find_child("LevelUpRewardButton%d" % card_index, true, false) as Button
		if card == null:
			_fail("%s: card %d missing." % [context, card_index])
			continue
		var title := card.find_child("LevelUpRewardTitle", true, false) as Label
		if title == null or title.text.strip_edges() == "" or not title.is_visible_in_tree() \
				or not title.get_global_rect().has_area() or title.get_visible_line_count() < 1:
			_fail("%s: card %d mandatory title is not visibly rendered (rect %s, font %d, lines %d/%d)." % [
				context,
				card_index,
				str(title.get_global_rect()) if title != null else "<missing>",
				title.get_theme_font_size("font_size") if title != null else 0,
				title.get_visible_line_count() if title != null else 0,
				title.get_line_count() if title != null else 0,
			])
		var expected_rows: Array = oracle["rewards"][card_index]["rows"]
		var rows := card.find_children("LevelUpRewardEffectText*", "Label", true, false)
		if rows.size() != expected_rows.size():
			_fail("%s: card %d rendered %d/%d mandatory effect rows." % [context, card_index, rows.size(), expected_rows.size()])
		var card_safe := _content_safe_rect(card, "normal")
		var effect_panel := card.find_child("LevelUpRewardEffectPreview", true, false) as PanelContainer
		if effect_panel == null or (drawer_rect.has_area() and drawer_rect.intersects(effect_panel.get_global_rect())):
			_fail("%s: card %d effect block %s is missing or intersects LU.DetailDrawer %s." % [
				context,
				card_index,
				str(effect_panel.get_global_rect()) if effect_panel != null else "<missing>",
				str(drawer_rect),
			])
		for row_index in range(rows.size()):
			var row := rows[row_index] as Label
			if row_index >= expected_rows.size():
				_fail("%s: card %d has unexpected effect row '%s'." % [context, card_index, row.text])
				continue
			if row.text != str(expected_rows[row_index]):
				_fail("%s: card %d row %d oracle mismatch: expected '%s', got '%s'." % [context, card_index, row_index, expected_rows[row_index], row.text])
			if not row.is_visible_in_tree() or not row.get_global_rect().has_area():
				_fail("%s: card %d row %d is not visibly rendered." % [context, card_index, row_index])
			_no_trim(row, "%s card %d row %d" % [context, card_index, row_index])
			if row.clip_text or row.max_lines_visible != -1:
				_fail("%s: card %d row %d uses clipping/line truncation." % [context, card_index, row_index])
			var row_font := row.get_theme_font("font")
			if row_font == null:
				row_font = ThemeDB.fallback_font
			var required_height := row_font.get_multiline_string_size(
				row.text, HORIZONTAL_ALIGNMENT_CENTER, row.size.x, row.get_theme_font_size("font_size")).y
			if required_height > row.size.y + 2.0 or row.get_visible_line_count() < row.get_line_count():
				_fail("%s: card %d row %d is not fully visible (needs %.1fpx, has %.1fpx)." % [context, card_index, row_index, required_height, row.size.y])
			for geometry_error in _level_up_geometry_errors(
					row.get_global_rect(), viewport_rect, panel_safe, card_safe, drawer_rect):
				_fail("%s: card %d row %d %s." % [context, card_index, row_index, geometry_error])
			if not overlap_probe_run:
				overlap_probe_run = true
				if _level_up_geometry_errors(
						row.get_global_rect(), viewport_rect, panel_safe, card_safe, row.get_global_rect()).is_empty():
					_fail("%s: known-overlap negative probe did not reject a drawer covering an effect row." % context)
	if state == "long_copy" and drawer_label != null:
		var first_description := str((offer[0] as Dictionary).get("description", ""))
		if not drawer_label.text.contains(first_description):
			_fail("%s: drawer lacks the full preconstructed long description." % context)
		await _assert_scroll_reaches_sentinel(drawer_scroll, drawer_label, sentinel, context)
	var semantic_text := drawer_label.text if drawer_label != null else "\n".join(_offer_attrs(offer))
	await _capture(fixture, "level_up", viewport_size, state, semantic_text, sentinel)
	await _teardown(fixture)


# ---------------------------------------------------------- Attribute Shop ---

func _run_attribute_shop(viewport_size: Vector2i, state: String) -> void:
	var fixture := await _new_fixture(viewport_size)
	var main: Node = fixture["main"]
	var context := "attribute_shop %s %s" % [viewport_size, state]
	var character_id := "berserk"
	var sentinel := ""
	var long_fixture_text := ""
	if state == "long_copy":
		var long_fixture := _long_copy_fixture("attribute_shop", viewport_size)
		sentinel = str(long_fixture["sentinel"])
		long_fixture_text = str(long_fixture["text"])
	match state:
		"capped":
			character_id = "sniper"
			main.set("run_player_snapshot", {
				"stats": ProgressionData.base_stats("sniper"),
				"run_modifiers": {"crit_chance_flat": 5.0},
			})
	main.set("selected_character_id", character_id)
	main.set("selected_weapon_id", str(ProgressionData.weapon_ids(character_id)[0]))
	match state:
		"ineligible":
			# Leadership незаслуженно сохранён старым сейвом — normalize обязан
			# убрать его до построения AttributeOffers.
			main.set("attribute_offer", ["strength", "leadership"])
		"capped":
			main.set("attribute_offer", ["agility", "strength"])
		"long_copy":
			main.set("attribute_offer", [{"id": "strength", "interpretation": long_fixture_text}, "agility"])
		_:
			main.set("attribute_offer", ["strength", "agility"])
	main.ui._show_attribute_shop(Callable())
	await _settle(6)

	var offers_box := main.find_child("AttributeOffers", true, false) as Container
	if offers_box == null:
		_fail("%s: AttributeOffers missing." % context)
		await _teardown(fixture)
		return
	if state == "ineligible":
		if main.find_child("AttributeOffer_leadership", true, false) != null:
			_fail("%s: ineligible leadership card is rendered." % context)
		if offers_box.get_child_count() < 2:
			_fail("%s: row not refilled/recentered after filtering (got %d cards)." % [context, offers_box.get_child_count()])
	# Compact-режим НЕ удаляет before→after: у каждой карточки в Preview есть "->".
	for offer_node in offers_box.get_children():
		var preview := (offer_node as Control).find_child("%sPreview" % (offer_node as Control).name, false, false) as Label
		if preview == null or not preview.text.contains("->"):
			_fail("%s: %s preview lost before->after values (text '%s')." % [context, (offer_node as Control).name, preview.text if preview != null else "<none>"])
	if state == "capped":
		var agility_preview := main.find_child("AttributeOffer_agilityPreview", true, false) as Label
		if agility_preview != null:
			var full_preview := str(agility_preview.get_meta("full_text", agility_preview.text))
			if full_preview.contains("Шанс крита"):
				_fail("%s: crit-capped context still promises 'Шанс крита' growth in the +1 preview." % context)
	# AS.DetailDrawer is the real tooltip host at every tier; compact mode reserves
	# its own left content zone instead of constructing a test-owned replacement.
	var drawer := main.find_child("AttributeShopDetailDrawer", true, false) as PanelContainer
	var drawer_scroll := main.find_child("AttributeShopDetailScroll", true, false) as ScrollContainer
	var drawer_label := main.find_child("AttributeShopDetailLabel", true, false) as Label
	var semantic_text := drawer_label.text if drawer_label != null else ""
	if drawer == null or drawer_label == null:
		_fail("%s: AS.DetailDrawer missing." % context)
	if state == "long_copy" and offers_box.get_child_count() > 0:
		var shop_root := main.find_child("AttributeShopScreen", true, false) as Control
		var actions := main.find_child("AttributeShopActions", true, false) as Control
		var first_offer := offers_box.get_child(0) as Button
		var alternate_offer := offers_box.get_child(1) as Button if offers_box.get_child_count() > 1 else null
		var baseline_copy := drawer_label.text if drawer_label != null else ""
		if alternate_offer == null:
			_fail("%s: Attribute Shop needs a second real offer for the causal hover probe." % context)
		else:
			await _assert_attribute_shop_hover_transition(
				fixture["viewport"] as Viewport, alternate_offer, drawer, drawer_label,
				baseline_copy, _attribute_shop_detail_copy(main, alternate_offer), viewport_size.y < 1000, context)
			await _push_mouse_motion(fixture["viewport"] as Viewport, first_offer.get_global_rect().get_center())
			if drawer_label.text != baseline_copy:
				_fail("%s: returning to the baseline offer did not restore its exact disclosure copy." % context)
		await _assert_real_hover_and_input(
			fixture["viewport"] as Viewport, first_offer, drawer, drawer_scroll,
			_first_button(actions),
			viewport_size.y < 1000, false, context)
		if not drawer.visible or str(drawer_label.text).strip_edges() == "":
			_fail("%s: production Attribute Shop tooltip host is hidden/empty at %s." % [context, viewport_size])
		semantic_text = drawer_label.text
		_no_trim(drawer_label, "%s production tooltip" % context)
		await _assert_scroll_reaches_sentinel(drawer_scroll, drawer_label, sentinel, context)
		var protected_rects: Array[Rect2] = []
		protected_rects.append(offers_box.get_global_rect())
		if actions != null:
			protected_rects.append(actions.get_global_rect())
		var texture_safe: Rect2 = shop_root.get_meta("gold_shell_content_rect", Rect2()) if shop_root != null else Rect2()
		var strict_inner: Rect2 = shop_root.get_meta("gold_shell_inner_rect", Rect2()) if shop_root != null else Rect2()
		await _assert_production_tooltip_host(drawer, drawer_scroll, drawer_label, sentinel, texture_safe, strict_inner, strict_inner, protected_rects, context)
	await _capture(fixture, "attribute_shop", viewport_size, state, semantic_text, sentinel)
	await _teardown(fixture)


# ------------------------------------------------------------- Pause/Codex ---

func _run_pause_codex(viewport_size: Vector2i, state: String) -> void:
	var fixture := await _new_fixture(viewport_size)
	var main: Node = fixture["main"]
	var context := "pause_codex %s %s" % [viewport_size, state]
	var character_id := "berserk"
	var weapon_id := "sword"
	var sentinel := ""
	var long_fixture_text := ""
	if state == "long_copy":
		var long_fixture := _long_copy_fixture("pause_codex", viewport_size)
		sentinel = str(long_fixture["sentinel"])
		long_fixture_text = str(long_fixture["text"])
	match state:
		"ineligible":
			character_id = "druid"
			weapon_id = "summon_amulet"
		"capped":
			character_id = "sniper"
			weapon_id = "sniper_deadeye_rifle"
	main.set("selected_character_id", character_id)
	main.set("selected_weapon_id", weapon_id)
	main.set("route_stage", 2)
	main.call("_start_combat")
	await _settle(4)
	if state == "capped":
		var player: Node = main.get("current_player")
		if player != null and is_instance_valid(player):
			var mods: Dictionary = player.get("run_modifiers")
			mods["crit_chance_flat"] = float(mods.get("crit_chance_flat", 0.0)) + 5.0
			player._apply_stat_scaling()
	main.ui._show_pause_menu(true)
	await _settle(6)

	var pause := main.find_child("PauseStatsMenu", true, false) as Control
	if pause == null:
		pause = main.get("pause_stats_menu") as Control
	if pause == null:
		_fail("%s: pause dossier did not open." % context)
		await _teardown(fixture)
		return
	var semantic_chip := pause.find_child("DerivedStatChip_damage_flat", true, false) as Control
	var semantic_text := str(semantic_chip.get_meta("dossier_tooltip_text", "")) if semantic_chip != null else ""
	var artifact_chip: Control = null
	match state:
		"normal":
			for axis_id in ["damage_flat", "damage", "attack_speed", "crit_chance", "vampiric", "ultimate_power"]:
				var chip_value := pause.find_child("DerivedStatValue_%s" % axis_id, true, false) as Label
				if chip_value == null or chip_value.text.strip_edges() == "":
					_fail("%s: canonical axis chip '%s' missing/empty." % [context, axis_id])
		"ineligible":
			# SummonerWeapon: generic attack_speed мёртв, «Сила призыва» —
			# фактический integer-парк.
			if pause.find_child("DerivedStatChip_attack_speed", true, false) != null:
				_fail("%s: dead attack_speed axis rendered for summon_amulet." % context)
			var summon_value := pause.find_child("DerivedStatValue_summon_amount", true, false) as Label
			if summon_value == null or not summon_value.text.strip_edges().is_valid_int():
				_fail("%s: summon chip must show the integer runtime pack." % context)
		"capped":
			var crit_value := pause.find_child("DerivedStatValue_crit_chance", true, false) as Label
			if crit_value == null or not crit_value.text.contains("макс"):
				_fail("%s: capped crit chip lacks the readable 'макс.' state (text '%s')." % [context, crit_value.text if crit_value != null else "<none>"])
		"long_copy":
			artifact_chip = pause.find_child("DerivedStatChip_damage_flat", true, false) as Control
			if artifact_chip != null:
				artifact_chip.set_meta("dossier_tooltip_text", long_fixture_text)
	if state == "long_copy":
		if artifact_chip == null:
			_fail("%s: production disclosure chip is missing." % context)
		else:
			var tooltip_host := pause.find_child("DossierFocusTooltip", true, false) as PanelContainer
			var tooltip_scroll := pause.find_child("DossierFocusTooltipScroll", true, false) as ScrollContainer
			var tooltip_label := pause.find_child("DossierFocusTooltipLabel", true, false) as Label
			var pause_actions := pause.find_child("PauseControlButtons", true, false) as Control
			await _assert_real_hover_and_input(
				fixture["viewport"] as Viewport, artifact_chip, tooltip_host, tooltip_scroll,
				_first_button(pause_actions),
				true, true, context)
			semantic_text = tooltip_label.text if tooltip_label != null else ""
			_no_trim(tooltip_label, "%s production tooltip" % context)
			await _assert_scroll_reaches_sentinel(tooltip_scroll, tooltip_label, sentinel, context)
			var contract: Dictionary = pause.call("_responsive_contract", Vector2(viewport_size))
			var protected_rects: Array[Rect2] = []
			if pause_actions != null:
				protected_rects.append(pause_actions.get_global_rect())
			await _assert_production_tooltip_host(tooltip_host, tooltip_scroll, tooltip_label, sentinel,
				contract["safe_rect"], contract["inner_rect"], contract["body_rect"], protected_rects, context)
	await _capture(fixture, "pause_codex", viewport_size, state, semantic_text, sentinel)
	await _teardown(fixture)


# ------------------------------------------------------------- Hero Select ---

func _run_hero_select(viewport_size: Vector2i, state: String) -> void:
	var fixture := await _new_fixture(viewport_size)
	var main: Node = fixture["main"]
	var context := "hero_select %s %s" % [viewport_size, state]
	var character_id := "guitarist"
	var sentinel := ""
	var content_translation: Translation = null
	if state == "long_copy":
		var long_fixture := _long_copy_fixture("hero_select", viewport_size)
		sentinel = str(long_fixture["sentinel"])
		content_translation = _install_translation(str(long_fixture["text"]))
	match state:
		"ineligible":
			character_id = "chemist"
		"capped":
			character_id = "assassin"
	main.set("selected_character_id", character_id)
	main.ui._show_character_select()
	await _settle(6)

	var cap_label := main.find_child("HS4BuildGuidance_cap_potential", true, false) as Label
	var capability_label := main.find_child("HS4BuildGuidance_capability", true, false) as Label
	var dossier_scroll := main.find_child("HS4DossierScroll", true, false) as ScrollContainer
	var trait_label := main.find_child("HS4TraitHeading", true, false) as Label
	var semantic_text := trait_label.text if trait_label != null else ""
	if dossier_scroll == null:
		_fail("%s: HS4DossierScroll missing." % context)
	if cap_label == null or capability_label == null:
		_fail("%s: HS.CapPotential/HS.CapabilityLine labels missing." % context)
		await _capture(fixture, "hero_select", viewport_size, state, semantic_text, sentinel)
		await _teardown(fixture)
		if content_translation != null:
			TranslationServer.remove_translation(content_translation)
		return
	_no_trim(cap_label, "%s cap potential" % context)
	_no_trim(capability_label, "%s capability" % context)
	match state:
		"normal":
			# Гитарист: вампиризм-потенциал и реальный summon-потребитель.
			if not cap_label.visible or not cap_label.text.contains("Вампиризм"):
				_fail("%s: guitarist cap potential lacks vampiric proc data (text '%s')." % [context, cap_label.text])
			var amp_title := str(ProgressionData.weapon("guitarist", "sound_amp").get("title", "sound_amp"))
			if not capability_label.visible or not capability_label.text.contains(amp_title):
				_fail("%s: capability line must name the real summon consumer '%s' (text '%s')." % [context, amp_title, capability_label.text])
		"ineligible":
			# Химик: ни одно оружие не потребляет summon_bonus — линия скрыта.
			if capability_label.visible:
				_fail("%s: chemist has no real summon consumer but capability line is visible ('%s')." % [context, capability_label.text])
		"capped":
			if not cap_label.visible or not cap_label.text.contains("максимум 100%"):
				_fail("%s: assassin cap potential must state 'максимум 100%%' (text '%s')." % [context, cap_label.text])
			if cap_label.text.containsn("повы") or cap_label.text.containsn("купить"):
				_fail("%s: cap potential must not carry a CTA." % context)
		"long_copy":
			if dossier_scroll != null and capability_label.text.contains(sentinel):
				semantic_text = capability_label.text
				await _assert_scroll_reaches_sentinel(dossier_scroll, capability_label, sentinel, context)
			else:
				_fail("%s: production capability line lacks the preconstructed long-copy sentinel." % context)
	await _capture(fixture, "hero_select", viewport_size, state, semantic_text, sentinel)
	await _teardown(fixture)
	if content_translation != null:
		TranslationServer.remove_translation(content_translation)
