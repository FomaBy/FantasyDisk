extends SceneTree

## FAN-3940 production accessibility contract for the Sniper ultimate trio.
##
## Every Sniper `quality.reduced_motion_substitute` in the class manifest
## promises a static substitute and says the tracer/barrage/waves, the shake and
## the hitstop reduce. This suite casts the shipped scenes through the
## production presentation runtime and checks the behaviour that promise
## describes — never the label itself:
##
## - the declared static substitute really replaces the per-phase animation (one
##   steady backdrop dim, the hero pose held at its aimed size, the weapon
##   silhouette held as one static glint),
## - the release applies no hitstop at all and never dips `Engine.time_scale`,
## - normal presentation keeps its stepped backdrop, growing pose, camera shake
##   and declared hitstop,
## - the two runtime accessibility flags are observed on their own and together,
##   and the `screen_shake` mirror alone also selects the substitute — but the
##   photosensitivity-safe flag never does,
## - cancel, natural finish, teardown and a repeated cast restore the camera,
##   the time scale, the SFX bus and the reported state.
##
##     python3 tools/godot_gate.py --headless --path . \
##       --script res://tests/ultimates/presentation/sniper_reduced_motion_contract_test.gd
##
## A windowed invocation additionally proves the real camera and time-scale
## effects, which a headless display server suppresses by design:
##
##     FSD_GODOT_EXCLUSIVE=1 python3 tools/godot_gate.py --windowed --fixed-fps 60 \
##       --path . --script res://tests/ultimates/presentation/sniper_reduced_motion_contract_test.gd

const Runtime := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_runtime.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const PD := preload("res://scripts/progression_data.gd")
const Accessibility := preload("res://scripts/settings/ultimate_accessibility_settings.gd")
const Presentation := preload("res://scenes/vfx/ultimates/sniper/sniper_ultimate_presentation.gd")

const ISSUE := "FAN-3940"
const CLASS_ID := "sniper"
const CLASS_MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/sniper/manifest.json"
const SAMPLED_BEATS: Array[String] = ["release", "active", "recovery"]
const EPSILON := 0.0005

## The five combinations the acceptance asks for: the two runtime accessibility
## flags on their own, the two together, and the shipped `screen_shake` mirror
## that main.gd publishes for scripts without a game reference.
const MODES := [
	{"id": "normal", "screen_shake": true, "reduced_motion": false, "photosensitivity_safe": false},
	{"id": "reduced_motion", "screen_shake": true, "reduced_motion": true, "photosensitivity_safe": false},
	{"id": "photosensitivity_safe", "screen_shake": true, "reduced_motion": false, "photosensitivity_safe": true},
	{"id": "combined", "screen_shake": true, "reduced_motion": true, "photosensitivity_safe": true},
	{"id": "screen_shake_off", "screen_shake": false, "reduced_motion": false, "photosensitivity_safe": false},
]

## Normal per-phase presentation, as `_apply_presence_pose()` applies it. The
## substitute has to differ from this, not merely coexist with it.
const NORMAL_POSE_SCALE := {"windup": 0.30, "release": 0.40, "active": 0.40, "recovery": 0.40}
const NORMAL_SILHOUETTE_SCALE := {"windup": 0.46, "release": 0.72, "active": 0.72, "recovery": 0.72}


class Host extends Node2D:
	func ultimate_host_effect_parent() -> Node:
		return self

	func ultimate_host_position() -> Vector2:
		return global_position


var _errors: Array[String] = []
var _weapons: Dictionary = {}


func _initialize() -> void:
	_weapons = _load_weapons()
	if _weapons.size() != 3:
		_errors.append("the Sniper class manifest must declare its three canonical weapons")
		_report()
		return
	var holder := Node2D.new()
	holder.name = "SniperReducedMotionHarness"
	root.add_child(holder)
	current_scene = holder
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)

	for weapon_id in _weapons:
		_check_declaration(str(weapon_id))
		for raw_mode in MODES:
			await _check_cast(holder, registry, str(weapon_id), raw_mode as Dictionary)
		await _check_repeat_and_teardown(holder, registry, str(weapon_id))

	_check_negative_probes()

	_restore_production_defaults()
	holder.queue_free()
	await process_frame
	_report()


## The manifest label is a promise, not evidence: it must exist, and it must
## name what the runtime is then required to actually do.
func _check_declaration(weapon_id: String) -> void:
	var quality := (_weapons[weapon_id] as Dictionary).get("quality", {}) as Dictionary
	var substitute := str(quality.get("reduced_motion_substitute", ""))
	_check(not substitute.is_empty(), "%s must keep declaring a reduced-motion substitute" % weapon_id)
	_check(substitute.contains("hitstop"), "%s must keep declaring that its hitstop reduces" % weapon_id)
	_check(bool(quality.get("reduced_motion_preserves_timing", false)),
		"%s must keep declaring that reduced motion preserves its timing" % weapon_id)


func _check_cast(holder: Node2D, registry: Registry, weapon_id: String, mode: Dictionary) -> void:
	var mode_id := str(mode["id"])
	var label := "%s/%s" % [weapon_id, mode_id]
	var reduced := _expects_substitute(mode)
	_apply_mode(mode)

	var host := Host.new()
	holder.add_child(host)
	var camera := Camera2D.new()
	camera.offset = Vector2(3.0, -2.0)
	host.add_child(camera)
	await process_frame
	camera.make_current()
	await process_frame
	var camera_offset_before := camera.offset
	var sfx_index := AudioServer.get_bus_index("SFX")
	var sfx_db_before := AudioServer.get_bus_volume_db(sfx_index) if sfx_index >= 0 else 0.0

	var runtime := Runtime.new(0)
	if not runtime.begin(host, registry, registry.catalog_profile_for(CLASS_ID, weapon_id)):
		_errors.append("%s must instantiate its shipped presentation scene" % label)
		host.queue_free()
		await process_frame
		return
	var scene := _mounted_scene(runtime)
	if scene == null:
		_errors.append("%s must mount its shipped presentation scene" % label)
		runtime.finish("cancel")
		host.queue_free()
		await process_frame
		return

	var timing := (_weapons[weapon_id] as Dictionary).get("timing_seconds", {}) as Dictionary
	var states := {"windup": scene.call("presence_state_for_tests") as Dictionary}
	var elapsed := 0.0
	for beat in SAMPLED_BEATS:
		var target := float(timing.get(beat, 0.0)) + 0.01
		runtime.advance(maxf(target - elapsed, 0.0))
		elapsed = target
		_check(str(scene.call("visible_phase_name")) == beat, "%s must reach its declared %s beat" % [label, beat])
		states[beat] = scene.call("presence_state_for_tests") as Dictionary

	for beat in states:
		for violation in behaviour_violations(states[beat] as Dictionary, weapon_id, str(beat), mode):
			_errors.append("%s at %s: %s" % [label, beat, violation])
	for violation in envelope_violations(states, weapon_id, mode):
		_errors.append("%s: %s" % [label, violation])

	## A reduced-motion release must leave the arena running; the ordinary one
	## really does freeze it, which only a windowed run can observe.
	_check(not reduced or is_equal_approx(Engine.time_scale, 1.0),
		"%s must never dip Engine.time_scale (%.3f)" % [label, Engine.time_scale])
	if not reduced and DisplayServer.get_name() != "headless":
		_check(Engine.time_scale < 0.99,
			"%s must still freeze the arena on its declared hitstop (%.3f)" % [label, Engine.time_scale])
	_check(not reduced or camera.offset.distance_to(camera_offset_before) <= EPSILON,
		"%s must never move the camera" % label)

	## Read before the deferred free: the scene must have cleared its own report,
	## not merely stopped existing.
	runtime.finish("cancel")
	var cleared := (scene.call("presence_state_for_tests") as Dictionary) if is_instance_valid(scene) else {}
	_check(not cleared.is_empty()
		and not bool(cleared.get("reduced_motion_substitute_applied", true))
		and not bool(cleared.get("backdrop_visible", true)),
		"%s must report its presence cleared after cancel" % label)
	await process_frame
	_check(is_equal_approx(Engine.time_scale, 1.0), "%s cancel must restore the time scale" % label)
	_check(camera.offset.distance_to(camera_offset_before) <= EPSILON, "%s cancel must restore the camera" % label)
	if sfx_index >= 0:
		_check(is_equal_approx(AudioServer.get_bus_volume_db(sfx_index), sfx_db_before),
			"%s cancel must restore the SFX bus" % label)
	host.queue_free()
	await process_frame


## A second cast on the same scene, then a teardown in the middle of one: both
## must leave the substitute state and the owned effects clean.
func _check_repeat_and_teardown(holder: Node2D, registry: Registry, weapon_id: String) -> void:
	var timing := (_weapons[weapon_id] as Dictionary).get("timing_seconds", {}) as Dictionary
	var release := float(timing.get("release", 0.0)) + 0.01
	var host := Host.new()
	holder.add_child(host)
	await process_frame

	_apply_mode(MODES[1] as Dictionary)
	var runtime := Runtime.new(0)
	if not runtime.begin(host, registry, registry.catalog_profile_for(CLASS_ID, weapon_id)):
		_errors.append("%s repeat cast must instantiate its shipped scene" % weapon_id)
		host.queue_free()
		await process_frame
		return
	var scene := _mounted_scene(runtime)
	runtime.advance(release)
	_check(bool((scene.call("presence_state_for_tests") as Dictionary).get("reduced_motion_substitute_applied", false)),
		"%s must apply the substitute on its first reduced-motion cast" % weapon_id)
	runtime.finish("node_end")
	await process_frame

	## The same mounted scene, cast again with motion restored: the substitute
	## must not survive into a presentation that no longer asks for it.
	_apply_mode(MODES[0] as Dictionary)
	var repeat := Runtime.new(0)
	if not repeat.begin(host, registry, registry.catalog_profile_for(CLASS_ID, weapon_id)):
		_errors.append("%s must accept a repeated cast" % weapon_id)
		host.queue_free()
		await process_frame
		return
	var repeat_scene := _mounted_scene(repeat)
	repeat.advance(release)
	var repeat_state := repeat_scene.call("presence_state_for_tests") as Dictionary
	_check(not bool(repeat_state.get("reduced_motion_substitute_applied", true))
		and float(repeat_state.get("hitstop_ms", 0.0)) > 0.0,
		"%s must return to its normal presentation on a repeated cast" % weapon_id)

	## Teardown in the middle of the cast, without a finish() call.
	repeat_scene.queue_free()
	await process_frame
	_check(is_equal_approx(Engine.time_scale, 1.0), "%s teardown must restore the time scale" % weapon_id)
	repeat.finish("death")
	host.queue_free()
	await process_frame


## The whole judgement for one sampled beat, kept pure so the negative probes
## below can prove each rule really goes red.
func behaviour_violations(state: Dictionary, weapon_id: String, beat: String, mode: Dictionary) -> Array[String]:
	var violations: Array[String] = []
	var weapon := _weapons.get(weapon_id, {}) as Dictionary
	var presence := weapon.get("presence", {}) as Dictionary
	var reduced := _expects_substitute(mode)
	if bool(state.get("reduced_motion", not reduced)) != reduced:
		violations.append("the scene read reduced motion as %s" % str(state.get("reduced_motion", "")))
	if bool(state.get("photosensitivity_safe", false)) != bool(mode["photosensitivity_safe"]):
		violations.append("the scene read photosensitivity-safe as %s" % str(state.get("photosensitivity_safe", "")))
	if bool(state.get("reduced_motion_substitute_applied", false)) != reduced:
		violations.append("the declared static substitute was %sapplied" % ("not " if reduced else ""))
	if not bool(state.get("cast_pose_bound", false)) or not bool(state.get("silhouette_bound", false)):
		violations.append("the hero pose and weapon silhouette must stay bound in every mode")

	var expected_alpha := (
		Presentation.REDUCED_MOTION_BACKDROP_ALPHA if reduced
		else _normal_backdrop_alpha(presence, beat)
	)
	if not is_equal_approx(float(state.get("backdrop_alpha", -1.0)), expected_alpha):
		violations.append("backdrop alpha %.3f, expected the %s %.3f" % [
			float(state.get("backdrop_alpha", -1.0)), "steady substitute dim" if reduced else "declared step", expected_alpha])
	var expected_pose := Presentation.REDUCED_MOTION_POSE_SCALE if reduced else float(NORMAL_POSE_SCALE[beat])
	if not is_equal_approx(float(state.get("cast_pose_scale", -1.0)), expected_pose):
		violations.append("hero pose scale %.3f, expected %.3f" % [float(state.get("cast_pose_scale", -1.0)), expected_pose])
	var expected_glint := Presentation.REDUCED_MOTION_SILHOUETTE_SCALE if reduced else float(NORMAL_SILHOUETTE_SCALE[beat])
	if not is_equal_approx(float(state.get("silhouette_scale", -1.0)), expected_glint):
		violations.append("weapon silhouette scale %.3f, expected %.3f" % [float(state.get("silhouette_scale", -1.0)), expected_glint])

	if beat == "windup":
		return violations
	## Release weight, still reported at the later beats it was applied on.
	var declared_hitstop := float(presence.get("hitstop_ms", 0.0))
	var expected_hitstop := 0.0 if reduced else declared_hitstop
	if not is_equal_approx(float(state.get("hitstop_ms", -1.0)), expected_hitstop):
		violations.append("hitstop %.1f ms, expected %.1f ms" % [float(state.get("hitstop_ms", -1.0)), expected_hitstop])
	if bool(state.get("camera_shake_triggered", false)) == reduced:
		violations.append("camera shake was %s" % ("triggered" if reduced else "skipped"))
	if not bool(state.get("sfx_ducked", false)) and bool(presence.get("sfx_ducking", false)):
		violations.append("the declared SFX duck must survive every mode")
	return violations


## The substitute is a *static* treatment: its backdrop must hold one value
## across the sampled beats, and the ordinary presentation must not.
func envelope_violations(states: Dictionary, weapon_id: String, mode: Dictionary) -> Array[String]:
	var violations: Array[String] = []
	var alphas: Array[float] = []
	for beat in SAMPLED_BEATS:
		alphas.append(float((states.get(beat, {}) as Dictionary).get("backdrop_alpha", -1.0)))
	var steady := true
	for alpha in alphas:
		steady = steady and is_equal_approx(alpha, alphas[0])
	if _expects_substitute(mode) and not steady:
		violations.append("the substitute stepped its backdrop %s instead of holding one dim" % str(alphas))
	if not _expects_substitute(mode) and steady:
		violations.append("the ordinary presentation stopped stepping its backdrop %s" % str(alphas))
	if _weapons.get(weapon_id, {}).is_empty():
		violations.append("the class manifest no longer carries this weapon")
	return violations


## Each rule, shown red on a mutated reading of the package's own evidence. A
## substitute that is only declared, or a release that keeps its normal hitstop,
## must not be able to reach a PASS.
func _check_negative_probes() -> void:
	var weapon_id := "sniper_deadeye_rifle"
	var reduced_mode := MODES[1] as Dictionary
	var normal_mode := MODES[0] as Dictionary
	var reduced := _reference_state(weapon_id, "release", true)
	var normal := _reference_state(weapon_id, "release", false)

	_check(behaviour_violations(reduced, weapon_id, "release", reduced_mode).is_empty(),
		"the reduced-motion reference reading must itself pass")
	_check(behaviour_violations(normal, weapon_id, "release", normal_mode).is_empty(),
		"the normal reference reading must itself pass")

	var label_only := reduced.duplicate(true)
	label_only["reduced_motion_substitute_applied"] = false
	_check(not behaviour_violations(label_only, weapon_id, "release", reduced_mode).is_empty(),
		"a declared substitute that was never applied must fail closed")

	var animated := reduced.duplicate(true)
	animated["backdrop_alpha"] = _normal_backdrop_alpha(
		(_weapons[weapon_id] as Dictionary).get("presence", {}) as Dictionary, "release")
	animated["cast_pose_scale"] = float(NORMAL_POSE_SCALE["release"])
	_check(not behaviour_violations(animated, weapon_id, "release", reduced_mode).is_empty(),
		"a reduced-motion beat that kept the animated pose must fail closed")

	var frozen := reduced.duplicate(true)
	frozen["hitstop_ms"] = float((_weapons[weapon_id] as Dictionary).get("presence", {}).get("hitstop_ms", 0.0))
	_check(not behaviour_violations(frozen, weapon_id, "release", reduced_mode).is_empty(),
		"a reduced-motion release that kept its normal hitstop must fail closed")

	var shaken := reduced.duplicate(true)
	shaken["camera_shake_triggered"] = true
	_check(not behaviour_violations(shaken, weapon_id, "release", reduced_mode).is_empty(),
		"a reduced-motion release that still shook must fail closed")

	var muted := reduced.duplicate(true)
	muted["sfx_ducked"] = false
	_check(not behaviour_violations(muted, weapon_id, "release", reduced_mode).is_empty(),
		"a substitute that also dropped the declared SFX duck must fail closed")

	var pretended := normal.duplicate(true)
	pretended["reduced_motion_substitute_applied"] = true
	_check(not behaviour_violations(pretended, weapon_id, "release", normal_mode).is_empty(),
		"a normal cast that claims the substitute must fail closed")

	## The photosensitivity-safe flag must not be able to stand in for reduced
	## motion: the same substitute reading, judged under that mode, is a failure.
	_check(not behaviour_violations(reduced, weapon_id, "release", MODES[2] as Dictionary).is_empty(),
		"photosensitivity-safe alone must not enable the substitute")

	var flat := {}
	var stepped := {}
	for beat in SAMPLED_BEATS:
		flat[beat] = _reference_state(weapon_id, beat, true)
		stepped[beat] = _reference_state(weapon_id, beat, false)
	_check(envelope_violations(flat, weapon_id, reduced_mode).is_empty()
		and envelope_violations(stepped, weapon_id, normal_mode).is_empty(),
		"the reference envelopes must themselves pass")
	_check(not envelope_violations(stepped, weapon_id, reduced_mode).is_empty(),
		"a reduced-motion envelope that still steps must fail closed")
	_check(not envelope_violations(flat, weapon_id, normal_mode).is_empty(),
		"an ordinary envelope that stopped stepping must fail closed")


## A reading of what the shipped scene is required to report at one beat. The
## probes mutate this, so every rule is proved against the same shape the live
## assertions consume.
func _reference_state(weapon_id: String, beat: String, reduced: bool) -> Dictionary:
	var presence := (_weapons[weapon_id] as Dictionary).get("presence", {}) as Dictionary
	return {
		"backdrop_visible": true,
		"backdrop_alpha": Presentation.REDUCED_MOTION_BACKDROP_ALPHA if reduced else _normal_backdrop_alpha(presence, beat),
		"camera_shake_triggered": not reduced,
		"hitstop_ms": 0.0 if reduced else float(presence.get("hitstop_ms", 0.0)),
		"sfx_ducked": bool(presence.get("sfx_ducking", false)),
		"cast_pose_bound": true,
		"cast_pose_scale": Presentation.REDUCED_MOTION_POSE_SCALE if reduced else float(NORMAL_POSE_SCALE[beat]),
		"silhouette_bound": true,
		"silhouette_scale": Presentation.REDUCED_MOTION_SILHOUETTE_SCALE if reduced else float(NORMAL_SILHOUETTE_SCALE[beat]),
		"reduced_motion": reduced,
		"photosensitivity_safe": false,
		"reduced_motion_substitute_applied": reduced,
	}


func _normal_backdrop_alpha(presence: Dictionary, beat: String) -> float:
	match beat:
		"windup":
			return 0.16
		"release":
			return 0.34 if str(presence.get("backdrop", "")) == "flash" else 0.42
		"active":
			return 0.24
		"recovery":
			return 0.10
	return 0.0


## Either shipped switch selects the substitute; the photosensitivity-safe
## preference on its own never does.
func _expects_substitute(mode: Dictionary) -> bool:
	return bool(mode["reduced_motion"]) or not bool(mode["screen_shake"])


func _apply_mode(mode: Dictionary) -> void:
	root.set_meta("screen_shake", bool(mode["screen_shake"]))
	root.set_meta("combat_feedback", true)
	Accessibility.apply_snapshot(root, {
		Accessibility.REDUCED_MOTION_KEY: bool(mode["reduced_motion"]),
		Accessibility.PHOTOSENSITIVITY_SAFE_KEY: bool(mode["photosensitivity_safe"]),
	})


func _restore_production_defaults() -> void:
	root.set_meta("screen_shake", true)
	root.set_meta("combat_feedback", true)
	Accessibility.apply_snapshot(root, Accessibility.default_snapshot())
	Engine.time_scale = 1.0


## The scene this runtime just mounted, not whichever sibling a previous cast
## left parented to the same host.
func _mounted_scene(runtime: Runtime) -> Node:
	var scene := runtime.get("_scene") as Node
	return scene if scene != null and is_instance_valid(scene) else null


func _load_weapons() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CLASS_MANIFEST_PATH))
	var weapons := {}
	if not parsed is Dictionary:
		return weapons
	for raw_weapon in (parsed as Dictionary).get("weapons", []) as Array:
		if raw_weapon is Dictionary:
			var weapon := raw_weapon as Dictionary
			weapons[str(weapon.get("weapon_id", ""))] = weapon.duplicate(true)
	return weapons


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("%s Sniper reduced-motion contract: PASS (%d weapons x %d flag combinations)" % [
			ISSUE, _weapons.size(), MODES.size()])
		quit(0)
		return
	for error in _errors:
		push_error("%s Sniper reduced-motion contract: %s" % [ISSUE, error])
	quit(1)
