extends SceneTree

## FAN-2985 gate: executor beats reach the live authored presentation and the
## controller's fallback primitive never draws over it.
##
## Machine checks, all against the real Player adapter and the real manifest
## documents:
##   1. every registry class/weapon pair begins its authored presentation, a
##      beat during it draws nothing and is recorded on the timeline;
##   2. a weapon whose manifest declares a zero flash budget
##      (`quality.full_screen_flash_hz = 0.0`,
##      `quality.max_flash_coverage_ratio = 0.0`) never sees a controller
##      flash, live presentation or not;
##   3. the fallback primitive exists only for weapons that declared a
##      non-zero flash budget, and an unknown shape is refused loudly;
##   4. the unconditional pale-blue `Color(0.86, 0.92, 1.0, ...)` constants
##      are gone from the host source.
##
## Run:
## python3 tools/godot_gate.py --headless --path . \
##   --script res://tests/ultimates/presentation/beat_routing_gate_test.gd

const PlayerScene := preload("res://scenes/Player.tscn")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
const PresentationManifest := preload(
	"res://scripts/ultimates/presentation/weapon_ultimate_presentation_manifest.gd")

const HOST_SOURCE_PATH := "res://scripts/ultimates/controller/ultimate_player_host.gd"
const EXPECTED_PAIR_COUNT := 51
## FAN-3015: the pairs whose ready package spawns nothing, so the authored
## scene is the only live effect channel their cast owns. Kept explicit —
## these are exactly the pairs the ownership contract now leans on.
const PRESENTATION_ONLY_PAIRS := [
	["chemist", "acid_flask"],
	["chemist", "blast_powder"],
	["doctor", "bone_saw"],
	["doctor", "plague_syringe"],
	["doctor", "restore_potion"],
	["guitarist", "bass_guitar"],
	["guitarist", "electric_guitar"],
	["guitarist", "sound_amp"],
	["robot", "robot_hydraulic_press"],
	["robot", "robot_magnetic_anchor"],
	["robot", "robot_reactor_core"],
	["soldier", "soldier_rifle"],
]


var _errors: Array[String] = []
var _holder: Node2D = null
var _player: Node2D = null
var _host: Node = null


func _initialize() -> void:
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	root.set_meta("combat_feedback", false)
	await process_frame

	_player = PlayerScene.instantiate() as Node2D
	_holder.add_child(_player)
	await process_frame
	_player.call("configure_character", "berserk", "sword")
	await process_frame
	_player.set_process(false)
	_player.set_physics_process(false)
	_host = PlayerHost.for_player(_player)
	# The berserk/sword equip flourish (WeaponSignatureVfx_*) self-frees ~0.28s
	# after configure_character. Left alive it races the per-pair baselines
	# below: its queue_free can land inside a release-check window and shift
	# the child count for a pair that leaked nothing (FAN-3061 hit exactly
	# this on soldier/soldier_rifle). Removing the unrelated transient keeps
	# every assertion below byte-identical and deterministic.
	for child in (_host.ultimate_host_effect_parent() as Node).get_children():
		if str((child as Node).name).begins_with("WeaponSignatureVfx"):
			(child as Node).free()

	_test_quality_block_reaches_the_runtime_manifest()
	_test_no_pale_blue_constants_left_in_host_source()
	_test_all_pairs_draw_nothing_over_the_live_presentation()
	_test_zero_budget_weapons_never_flash()
	_test_fallback_only_with_declared_budget()
	_test_unknown_shape_is_refused()
	await _test_authored_scene_is_the_live_channel_and_is_released()

	_player.queue_free()
	_holder.queue_free()
	await process_frame
	_report()


func _registry():
	return PlayerHost.shared_registry()


func _pairs() -> Array:
	var pairs: Array = []
	for class_id in _registry().class_ids():
		for weapon_id in _registry().weapon_ids(class_id):
			pairs.append([str(class_id), str(weapon_id)])
	return pairs


# --- checks ---------------------------------------------------------------------

func _test_quality_block_reaches_the_runtime_manifest() -> void:
	var berserk: Dictionary = PresentationManifest.manifest_for_profile(
		{"class_id": "berserk", "weapon_id": "sword"})
	var berserk_quality: Dictionary = berserk.get("quality", {})
	_check(is_equal_approx(float(berserk_quality.get("full_screen_flash_hz", -1.0)), 0.0),
		"berserk/sword must expose quality.full_screen_flash_hz = 0.0")
	_check(is_equal_approx(float(berserk_quality.get("max_flash_coverage_ratio", -1.0)), 0.0),
		"berserk/sword must expose quality.max_flash_coverage_ratio = 0.0")

	var chemist: Dictionary = PresentationManifest.manifest_for_profile(
		{"class_id": "chemist", "weapon_id": "blast_powder"})
	var chemist_quality: Dictionary = chemist.get("quality", {})
	# The pin tracks the class-local declaration, not a favorite number: FAN-2957
	# re-declared the release flash at full coverage (a single non-repeating
	# flash; the WCAG general-flash threshold governs repeats only), so the
	# pass-through is pinned to that accepted value. Exact-match strength is
	# unchanged — any manifest/runtime drift from 1.0 still reddens here.
	_check(is_equal_approx(float(chemist_quality.get("max_flash_coverage_ratio", 0.0)), 1.0),
		"chemist/blast_powder must pass its declared flash coverage through")


func _test_no_pale_blue_constants_left_in_host_source() -> void:
	var source := FileAccess.get_file_as_string(HOST_SOURCE_PATH)
	_check(not source.contains("0.86, 0.92, 1.0"),
		"the pale-blue controller colors must be gone from ultimate_player_host.gd")


func _test_all_pairs_draw_nothing_over_the_live_presentation() -> void:
	var pairs := _pairs()
	_check(pairs.size() == EXPECTED_PAIR_COUNT,
		"expected %d registry pairs, found %d" % [EXPECTED_PAIR_COUNT, pairs.size()])
	var parent = _host.ultimate_host_effect_parent()
	for pair in pairs:
		var class_id := str(pair[0])
		var weapon_id := str(pair[1])
		var profile: Dictionary = _registry().catalog_profile_for(class_id, weapon_id)
		if not _host.ultimate_host_begin_presentation(profile):
			_errors.append("%s/%s: the authored presentation must begin" % [class_id, weapon_id])
			continue
		var event_id := "weapon_ultimate.phase.%s.%s.execute" % [class_id, weapon_id]
		var children_before: int = parent.get_child_count()
		var node = _host.ultimate_host_present(event_id, {"shape": "ring_pulse", "radius": 240.0})
		_check(node == null,
			"%s/%s: no controller primitive may be drawn over the live presentation" % [class_id, weapon_id])
		_check(parent.get_child_count() == children_before,
			"%s/%s: a beat over the live presentation must not add nodes" % [class_id, weapon_id])
		var runtime = _host._presentation
		var beats: Array = runtime.recorded_beats()
		var delivered := false
		for beat in beats:
			if str(beat.get("event_id", "")) == event_id:
				delivered = true
		_check(delivered,
			"%s/%s: the beat event_id must reach the live presentation timeline" % [class_id, weapon_id])
		_host.ultimate_host_finish_presentation("cancel")


func _test_zero_budget_weapons_never_flash() -> void:
	var checked := 0
	var parent = _host.ultimate_host_effect_parent()
	for pair in _pairs():
		var class_id := str(pair[0])
		var weapon_id := str(pair[1])
		var record: Dictionary = PresentationManifest.class_weapon_record(class_id, weapon_id)
		var quality: Dictionary = record.get("quality", {})
		if not quality.has("full_screen_flash_hz") and not quality.has("max_flash_coverage_ratio"):
			continue
		if float(quality.get("full_screen_flash_hz", 0.0)) > 0.0 \
				or float(quality.get("max_flash_coverage_ratio", 0.0)) > 0.0:
			continue
		checked += 1
		_host._presentation = null
		_host._presentation_profile = {"class_id": class_id, "weapon_id": weapon_id}
		var children_before: int = parent.get_child_count()
		for shape in ["ring_pulse", "orb_burst", "beam", "moon_mark"]:
			var node = _host.ultimate_host_present("fixture.beat", {"shape": shape, "radius": 240.0})
			if node != null:
				_errors.append("%s/%s declared a zero flash budget, yet shape '%s' drew" % [class_id, weapon_id, shape])
		_check(parent.get_child_count() == children_before,
			"%s/%s: a zero flash budget must produce no controller nodes" % [class_id, weapon_id])
	_host._presentation_profile = {}
	_check(checked > 0, "the manifest scan must find at least one zero-flash weapon")


func _test_fallback_only_with_declared_budget() -> void:
	var parent = _host.ultimate_host_effect_parent()
	_host._presentation = null
	_host._presentation_profile = {}

	var node = _host.ultimate_host_present("fixture.beat", {"shape": "ring_pulse"})
	_check(node == null,
		"without a live presentation and a declared budget nothing may be drawn")

	_host._presentation_profile = {"class_id": "berserk", "weapon_id": "sword"}
	_check(_host.ultimate_host_present("fixture.beat", {"shape": "ring_pulse"}) == null,
		"berserk/sword declared a zero flash budget; the fallback must stay dark")

	_host._presentation_profile = {"class_id": "chemist", "weapon_id": "blast_powder"}
	var children_before: int = parent.get_child_count()
	for shape in ["ring_pulse", "orb_burst", "beam"]:
		var drawn = _host.ultimate_host_present("fixture.beat", {"shape": shape, "radius": 120.0})
		if drawn == null:
			_errors.append("chemist/blast_powder declared flash coverage; shape '%s' must draw" % shape)
	_check(parent.get_child_count() > children_before,
		"the declared-budget fallback must place its primitives under the effect parent")
	while parent.get_child_count() > children_before:
		var child = parent.get_child(parent.get_child_count() - 1)
		parent.remove_child(child)
		child.queue_free()
	_host._presentation_profile = {}


## FAN-3015: a spawnless pair owns exactly one live effect channel — the
## authored scene — so that scene has to be a real node under the effect parent
## while the cast runs, and it has to be gone once the host finishes it. Forced
## non-headless presentation mode instantiates it for real under the headless
## display server, where the runtime would otherwise take its no-op timeline.
func _test_authored_scene_is_the_live_channel_and_is_released() -> void:
	var parent = _host.ultimate_host_effect_parent()
	_host._presentation = null
	_host.set("_presentation_headless_mode", 0)
	for pair in PRESENTATION_ONLY_PAIRS:
		var class_id := str(pair[0])
		var weapon_id := str(pair[1])
		var label := "%s/%s" % [class_id, weapon_id]
		var baseline: int = parent.get_child_count()
		var profile: Dictionary = _registry().catalog_profile_for(class_id, weapon_id)
		if not _host.ultimate_host_begin_presentation(profile):
			_errors.append("%s: the authored presentation must begin non-headless" % label)
			continue
		var scene = _host._presentation._scene as Node
		_check(scene != null and scene.get_parent() == parent,
			"%s: the authored scene must be a live node under the effect parent" % label)
		_check(_host.ultimate_host_presentation_active(),
			"%s: the host must report the authored scene as a live channel" % label)
		var children_before: int = parent.get_child_count()
		_check(_host.ultimate_host_present("fixture.beat", {"shape": "ring_pulse"}) == null \
				and parent.get_child_count() == children_before,
			"%s: a beat must not add a node over the live authored scene" % label)
		_host.ultimate_host_finish_presentation("node_end")
		_check(not _host.ultimate_host_presentation_active(),
			"%s: the channel must close when the host finishes the presentation" % label)
		await process_frame
		await process_frame
		_check(scene == null or not is_instance_valid(scene),
			"%s: the authored scene node must be freed after the cast" % label)
		_check(parent.get_child_count() == baseline,
			"%s: no presentation node may outlive the cast" % label)
	_host.set("_presentation_headless_mode", -1)


func _test_unknown_shape_is_refused() -> void:
	_host._presentation = null
	_host._presentation_profile = {"class_id": "chemist", "weapon_id": "blast_powder"}
	for shape in ["axe_detonation", "axe_pass", "axe_turn", "chain_net", "corridor_beat",
			"cross_slash", "jaw_ring", "moon_mark", "quake_ring", "rift_lanes"]:
		var node = _host.ultimate_host_present("fixture.beat", {"shape": shape})
		if node != null:
			_errors.append("unknown shape '%s' must be refused, not silently drawn" % shape)
	_host._presentation_profile = {}


# --- fixture plumbing --------------------------------------------------------

func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("beat_routing_gate_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("beat_routing_gate_test: %s" % error)
	print("beat_routing_gate_test: FAIL (%d)" % _errors.size())
	quit(1)
