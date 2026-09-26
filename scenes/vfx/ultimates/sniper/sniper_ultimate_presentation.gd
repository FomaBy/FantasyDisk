class_name SniperUltimatePresentationScene
extends Node2D

## Class-local visual runner for a frozen sniper ultimate timeline.
##
## FAN-1541 owns the shared adapter which will instantiate these scenes. This
## runner deliberately owns only its presentation nodes and delegates timing,
## pause, headless behavior, and handle cleanup to the frozen contract class.

const Timeline := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_timeline.gd")
const Accessibility := preload("res://scripts/settings/ultimate_accessibility_settings.gd")

const BACKDROP_OVERSCAN := 1.08
const SFX_DUCK_DB := -8.0

## Reduced motion, as every Sniper `quality.reduced_motion_substitute` in
## docs/design/references/weapon_ultimates/sniper/manifest.json declares it: the
## backdrop holds one steady dim instead of stepping per phase, the hero pose and
## weapon silhouette hold their aimed size, the named arena progression collapses
## into one held treatment, and the camera shake and the hitstop drop out. Phase
## timing, SFX ducking, gameplay and balance are identical to the ordinary path.
const REDUCED_MOTION_BACKDROP_ALPHA := 0.16
const REDUCED_MOTION_POSE_SCALE := 0.30
const REDUCED_MOTION_SILHOUETTE_SCALE := 0.46

## The declared treatment, per weapon, built only from nodes the shipped scene
## already authors — no new art and no new timing. From the release beat onward
## exactly these nodes are drawn and they never change again, so what each
## declaration names as reducing is simply never drawn: the arena and muzzle
## tracer and the sonic crack for Deadeye, the three barrage columns for Spotter,
## the five wave fronts and echoes for Shatter.
##
## - `sniper_deadeye_rifle` — the endpoint flash alone is the "one static glint";
##   the rifle silhouette that holds its aimed pose beside it is the code-owned
##   `WeaponSilhouette`, held at `REDUCED_MOTION_SILHOUETTE_SCALE`.
## - `sniper_spotter_scope` — the sky-grid crown holds "one calm crimson frame"
##   and the arena impact core is the "single pulse".
## - `sniper_shatter_rounds` — the five fan trajectories hold "a single pale
##   formation" and the crystal wave core is the "one non-flashing bloom"; the
##   near-white muzzle flash is dropped with the waves.
const REDUCED_MOTION_TREATMENT := {
	"sniper_deadeye_rifle": [
		"Active/EndpointFlash",
	],
	"sniper_spotter_scope": [
		"Release/SkyGridCrown",
		"Active/ArenaImpactCore",
	],
	"sniper_shatter_rounds": [
		"Release/FanTrajectory1",
		"Release/FanTrajectory2",
		"Release/FanTrajectory3",
		"Release/FanTrajectory4",
		"Release/FanTrajectory5",
		"Active/CrystalWaveCore",
	],
}

## The beats the held treatment covers. Windup is the aimed charge, which is one
## authored state already, and cancel is the teardown the timeline owns.
const REDUCED_MOTION_HELD_PHASES := ["release", "active", "recovery"]

@export_file("*.json") var definition_path := ""

var _definition: Dictionary = {}
var _timeline: RefCounted
var _visible_phase := ""
var _headless_mode := -1
var _presence: Dictionary = {}
var _identity: Dictionary = {}
var _backdrop: Sprite2D = null
var _cast_pose: Sprite2D = null
var _silhouette: Sprite2D = null
var _camera: Camera2D = null
var _camera_offset_before_shake := Vector2.ZERO
var _shake_tween: Tween = null
var _ducked_bus_index := -1
var _ducked_previous_db := 0.0
var _hitstop_previous_scale := 1.0
var _hitstop_active := false
var _reduced_motion := false
var _photosensitivity_safe := false
var _authored_phase_visibility := {}
var _presence_state := _empty_presence_state()


func _ready() -> void:
	_load_definition_if_needed()
	_reset_phase_nodes()


func definition() -> Dictionary:
	_load_definition_if_needed()
	return _definition.duplicate(true)


func manifest() -> Dictionary:
	return definition().get("manifest", {}).duplicate(true)


func begin(handles: Dictionary, headless_mode := -1) -> Dictionary:
	_load_definition_if_needed()
	_clear_presence()
	_reset_phase_nodes()
	_headless_mode = headless_mode
	_presence = manifest().get("presence", {}) as Dictionary
	_identity = manifest().get("identity", {}) as Dictionary
	## Latched once per cast: a substitute that swapped in halfway through would
	## be neither the animated presentation nor the declared static one.
	_reduced_motion = _reduced_motion_enabled()
	_photosensitivity_safe = _photosensitivity_safe_enabled()
	_build_presence_nodes()
	_timeline = Timeline.new(manifest(), headless_mode)
	var snapshot: Dictionary = _timeline.begin(handles)
	if str(snapshot.get("state", "")) == Timeline.ACTIVE_STATE:
		_apply_emitted_phases(_timeline.advance(0.0))
	return snapshot


func advance(delta_seconds: float) -> Array[Dictionary]:
	if _timeline == null:
		return []
	_fit_backdrop_to_viewport()
	var emitted: Array[Dictionary] = _timeline.advance(delta_seconds)
	_apply_emitted_phases(emitted)
	return emitted


func set_paused(value: bool) -> void:
	if _timeline != null:
		_timeline.set_paused(value)


func finish(reason: String) -> Dictionary:
	if _timeline == null:
		_clear_presence()
		_reset_phase_nodes()
		return {}
	var snapshot: Dictionary = _timeline.finish(reason)
	_reset_phase_nodes()
	_clear_presence()
	return snapshot


func visible_phase_name() -> String:
	return _visible_phase


## Runtime-facing proof that the authored V2 weight, rather than manifest-only
## declarations, is active. The focused headless test reads this state while
## actual camera, time-scale, and mix changes stay guarded below.
func presence_state_for_tests() -> Dictionary:
	return _presence_state.duplicate(true)


func _load_definition_if_needed() -> void:
	if not _definition.is_empty() or definition_path.is_empty():
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(definition_path))
	if parsed is Dictionary:
		_definition = (parsed as Dictionary).duplicate(true)


func _apply_emitted_phases(emitted: Array[Dictionary]) -> void:
	for phase in emitted:
		var phase_name := str(phase.get("name", ""))
		_show_phase(phase_name)
		if phase_name == "release":
			_apply_release_presence()


func _show_phase(phase_name: String) -> void:
	var phase_nodes := get_node_or_null("PhaseNodes")
	if phase_nodes == null:
		return
	_visible_phase = phase_name
	if _reduced_motion and REDUCED_MOTION_HELD_PHASES.has(phase_name):
		_show_reduced_motion_treatment(phase_nodes)
	else:
		for node in phase_nodes.get_children():
			if node is CanvasItem:
				(node as CanvasItem).visible = node.name.to_lower() == phase_name
	_apply_presence_pose(phase_name)


## The held treatment, drawn from the release beat onward. The authored group a
## beat would have stepped to is not shown at all, so the tracer, the barrage
## columns and the wave fronts each declaration names never reach the frame.
func _show_reduced_motion_treatment(phase_nodes: Node) -> void:
	var treatment: Array = REDUCED_MOTION_TREATMENT.get(_weapon_id(), [])
	for group in phase_nodes.get_children():
		var group_item := group as CanvasItem
		if group_item == null:
			continue
		var drawn := false
		for child in group.get_children():
			var child_item := child as CanvasItem
			if child_item == null:
				continue
			child_item.visible = treatment.has("%s/%s" % [group.name, child.name])
			drawn = drawn or child_item.visible
		group_item.visible = drawn


func _reset_phase_nodes() -> void:
	_visible_phase = ""
	var phase_nodes := get_node_or_null("PhaseNodes")
	if phase_nodes == null:
		return
	_remember_authored_phase_visibility(phase_nodes)
	for node in phase_nodes.get_children():
		if node is CanvasItem:
			(node as CanvasItem).visible = false
		for child in node.get_children():
			var child_item := child as CanvasItem
			if child_item != null:
				child_item.visible = bool(_authored_phase_visibility.get("%s/%s" % [node.name, child.name], true))


## The reduced-motion treatment hides individual authored children, so the next
## cast on the same instance has to start from what the scene authored rather
## than from what the previous mode left behind.
func _remember_authored_phase_visibility(phase_nodes: Node) -> void:
	if not _authored_phase_visibility.is_empty():
		return
	for node in phase_nodes.get_children():
		for child in node.get_children():
			var child_item := child as CanvasItem
			if child_item != null:
				_authored_phase_visibility["%s/%s" % [node.name, child.name]] = child_item.visible


## Every phase node actually on screen right now, as "Group/Child". This is the
## runtime answer to what the presentation drew, not what a manifest promised.
func _drawn_phase_nodes() -> PackedStringArray:
	var drawn := PackedStringArray()
	var phase_nodes := get_node_or_null("PhaseNodes")
	if phase_nodes == null:
		return drawn
	for group in phase_nodes.get_children():
		var group_item := group as CanvasItem
		if group_item == null or not group_item.visible:
			continue
		for child in group.get_children():
			var child_item := child as CanvasItem
			if child_item != null and child_item.visible:
				drawn.append("%s/%s" % [group.name, child.name])
	return drawn


## Applied presentation weight, as this cast actually ran it. Every value is
## written where the effect is applied, so a reader cannot mistake a manifest
## declaration for shipped behavior.
func _empty_presence_state() -> Dictionary:
	return {
		"backdrop_visible": false,
		"backdrop_alpha": 0.0,
		"camera_shake_triggered": false,
		"hitstop_ms": 0.0,
		"sfx_ducked": false,
		"cast_pose_id": str(_identity.get("cast_pose_id", "")),
		"cast_pose_asset": str(_identity.get("cast_pose_asset", "")),
		"cast_pose_bound": false,
		"cast_pose_scale": 0.0,
		"silhouette_asset": str(_identity.get("weapon_silhouette_asset", "")),
		"silhouette_bound": false,
		"silhouette_scale": 0.0,
		"reduced_motion": _reduced_motion,
		"photosensitivity_safe": _photosensitivity_safe,
		"reduced_motion_substitute_applied": false,
		"phase_nodes_drawn": PackedStringArray(),
	}


func _build_presence_nodes() -> void:
	_presence_state = _empty_presence_state()
	if _presence.is_empty() or _identity.is_empty():
		return
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 0.82), Color.WHITE])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.width = 64
	texture.height = 64
	_backdrop = Sprite2D.new()
	_backdrop.name = "BackdropTreatment"
	_backdrop.texture = texture
	_backdrop.centered = false
	_backdrop.modulate = _backdrop_color(0.0)
	_backdrop.z_index = -2
	_backdrop.top_level = true
	add_child(_backdrop)
	_fit_backdrop_to_viewport()

	var pose_texture := load(str(_identity.get("cast_pose_asset", ""))) as Texture2D
	if pose_texture != null:
		_cast_pose = Sprite2D.new()
		_cast_pose.name = "HeroCastPose"
		_cast_pose.texture = pose_texture
		_cast_pose.scale = Vector2.ONE * 0.30
		_cast_pose.modulate = _palette_color(0.0)
		_cast_pose.z_index = 1
		add_child(_cast_pose)
		_presence_state["cast_pose_bound"] = true

	var silhouette := load(str(_identity.get("weapon_silhouette_asset", ""))) as Texture2D
	if silhouette != null:
		_silhouette = Sprite2D.new()
		_silhouette.name = "WeaponSilhouette"
		_silhouette.texture = silhouette
		_silhouette.scale = Vector2.ONE * 0.46
		_silhouette.modulate = _palette_color(0.0)
		_silhouette.z_index = 2
		add_child(_silhouette)
		_presence_state["silhouette_bound"] = true


## Under reduced motion the three declared static substitutes replace the
## per-phase animation: one steady backdrop dim in the same class hue, the hero
## pose held at its aimed size and the weapon silhouette held as a single static
## glint. The phase still changes underneath, so the declared timing and the
## `cancel` teardown are unchanged.
func _apply_presence_pose(phase_name: String) -> void:
	if _backdrop == null:
		return
	var alpha := _phase_backdrop_alpha(phase_name)
	if _reduced_motion and alpha > 0.0:
		alpha = REDUCED_MOTION_BACKDROP_ALPHA
	_backdrop.modulate = _backdrop_color(alpha)
	_backdrop.visible = alpha > 0.0
	_presence_state["backdrop_visible"] = _backdrop.visible
	_presence_state["backdrop_alpha"] = alpha
	if _cast_pose != null:
		_cast_pose.visible = phase_name != "cancel"
		_cast_pose.modulate = _palette_color(0.9 if _cast_pose.visible else 0.0)
		var pose_scale := REDUCED_MOTION_POSE_SCALE if _reduced_motion else (0.30 if phase_name == "windup" else 0.40)
		_cast_pose.scale = Vector2.ONE * pose_scale
		_presence_state["cast_pose_scale"] = pose_scale if _cast_pose.visible else 0.0
	if _silhouette != null:
		_silhouette.visible = phase_name != "cancel"
		_silhouette.modulate = _palette_color(0.9 if _silhouette.visible else 0.0)
		var glint_scale := REDUCED_MOTION_SILHOUETTE_SCALE if _reduced_motion else (0.46 if phase_name == "windup" else 0.72)
		_silhouette.scale = Vector2.ONE * glint_scale
		_presence_state["silhouette_scale"] = glint_scale if _silhouette.visible else 0.0
	_presence_state["phase_nodes_drawn"] = _drawn_phase_nodes()
	## Every part of the declaration at once, or none: a held pose with no steady
	## dim, or a steady dim with the tracer still sweeping, is not what the class
	## manifest promises.
	_presence_state["reduced_motion_substitute_applied"] = (
		_reduced_motion
		and _backdrop.visible
		and bool(_presence_state["cast_pose_bound"])
		and bool(_presence_state["silhouette_bound"])
		and _holds_declared_treatment(phase_name)
	)


## True when the phase nodes on screen are exactly the declared held treatment.
## A beat that still stepped its authored group fails this, so the substitute
## cannot be reported from the backdrop alone.
func _holds_declared_treatment(phase_name: String) -> bool:
	if not REDUCED_MOTION_HELD_PHASES.has(phase_name):
		return true
	var treatment: Array = REDUCED_MOTION_TREATMENT.get(_weapon_id(), [])
	if treatment.is_empty():
		return false
	var drawn := _presence_state["phase_nodes_drawn"] as PackedStringArray
	if drawn.size() != treatment.size():
		return false
	for path in treatment:
		if not drawn.has(str(path)):
			return false
	return true


func _phase_backdrop_alpha(phase_name: String) -> float:
	match phase_name:
		"windup":
			return 0.16
		"release":
			return 0.34 if str(_presence.get("backdrop", "")) == "flash" else 0.42
		"active":
			return 0.24
		"recovery":
			return 0.10
	return 0.0


## The texture treatment is top-level and re-fitted to the actual camera every
## step. A player-centred treatment leaves gaps whenever the camera reaches an
## arena limit, because the player is then offset from the viewport centre.
func _fit_backdrop_to_viewport() -> void:
	if _backdrop == null:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var rect := viewport.get_visible_rect()
	var camera := viewport.get_camera_2d()
	var visible_size: Vector2 = rect.size / camera.zoom if camera != null else rect.size
	var overscan := visible_size * (BACKDROP_OVERSCAN - 1.0) * 0.5
	var size := visible_size + overscan * 2.0
	_backdrop.position = viewport.get_canvas_transform().affine_inverse() * rect.position - overscan
	if _backdrop.texture != null:
		_backdrop.scale = size / _backdrop.texture.get_size()


func _apply_release_presence() -> void:
	if _presence.is_empty():
		return
	if _presence.get("camera_shake") == true and _camera_shake_allowed():
		_presence_state["camera_shake_triggered"] = true
		_shake_camera()
	## The declared reduction of the hitstop is zero: reduced motion never dips
	## Engine.time_scale, so the release lands on an unfrozen arena.
	var hitstop_ms := 0.0 if _reduced_motion else float(_presence.get("hitstop_ms", 0.0))
	_presence_state["hitstop_ms"] = hitstop_ms
	if hitstop_ms > 0.0:
		_start_hitstop(hitstop_ms)
	## Audio is not motion: the manifest reduces the tracer, the shake and the
	## hitstop, never the mix.
	if _presence.get("sfx_ducking") == true:
		_presence_state["sfx_ducked"] = true
		_duck_sfx()


func _backdrop_color(alpha: float) -> Color:
	if str(_presence.get("backdrop", "")) == "flash":
		return Color(0.64, 0.06, 0.12, alpha)
	return Color(0.015, 0.035, 0.08, alpha)


func _weapon_id() -> String:
	return str((manifest().get("key", {}) as Dictionary).get("weapon_id", ""))


func _palette_color(alpha: float) -> Color:
	var weapon_id := _weapon_id()
	if weapon_id == "sniper_spotter_scope":
		return Color(1.0, 0.38, 0.32, alpha)
	if weapon_id == "sniper_shatter_rounds":
		return Color(0.64, 0.90, 1.0, alpha)
	return Color(0.68, 0.90, 1.0, alpha)


func _is_headless() -> bool:
	return not is_inside_tree() or DisplayServer.get_name() == "headless" or _headless_mode == 1


## The node the production accessibility policy is published on: the tree root
## in the game, the topmost ancestor in a contract tree that never runs the node
## lifecycle (get_tree() is null there while a parent already holds the scene).
func _policy_root() -> Node:
	var node: Node = self
	while node.get_parent() != null:
		node = node.get_parent()
	return node


## The declared substitute belongs to the dedicated reduced-motion preference
## published by scripts/settings/ultimate_accessibility_settings.gd, and to
## nothing else. The ordinary `screen_shake` setting is a camera toggle: turning
## it off must leave the visual treatment, the hitstop and the time-scale dip
## exactly as they are.
func _reduced_motion_enabled() -> bool:
	var policy_root := _policy_root()
	if policy_root == self:
		return false
	return bool(Accessibility.read_snapshot(policy_root).get(Accessibility.REDUCED_MOTION_KEY, false))


## Camera shake, held by either switch: the shipped `screen_shake` setting
## main.gd mirrors onto the tree root, or reduced motion, which removes the
## camera move along with the rest of the declared reduction.
func _camera_shake_allowed() -> bool:
	if _reduced_motion:
		return false
	var policy_root := _policy_root()
	if policy_root == self:
		return true
	return bool(policy_root.get_meta("screen_shake", true))


## Photosensitivity-safe preference. Sniper declares no separate substitute for
## it — its flash ceilings are met by the shipped presentation — so the scene
## only observes it, and the flag never stands in for reduced motion.
func _photosensitivity_safe_enabled() -> bool:
	var policy_root := _policy_root()
	if policy_root == self:
		return false
	return bool(Accessibility.read_snapshot(policy_root).get(Accessibility.PHOTOSENSITIVITY_SAFE_KEY, false))


## The motion policy is resolved once in `begin()`; this only keeps the camera
## out of a run that owns no framebuffer.
func _shake_camera() -> void:
	if _is_headless():
		return
	_camera = get_viewport().get_camera_2d()
	if _camera == null:
		return
	_camera_offset_before_shake = _camera.offset
	_shake_tween = _camera.create_tween()
	for index in 4:
		var strength := 7.0 * (1.0 - float(index) / 4.0)
		_shake_tween.tween_property(_camera, "offset", Vector2(randf_range(-strength, strength), randf_range(-strength, strength)), 0.04)
	_shake_tween.tween_property(_camera, "offset", _camera_offset_before_shake, 0.04)


func _start_hitstop(hitstop_ms: float) -> void:
	if _is_headless() or _hitstop_active or Engine.time_scale < 0.99:
		return
	_hitstop_previous_scale = Engine.time_scale
	Engine.time_scale = float(_presence.get("time_scale_dip", 0.4))
	_hitstop_active = true
	var timer := get_tree().create_timer(hitstop_ms / 1000.0, true, false, true)
	timer.timeout.connect(_restore_hitstop)


func _restore_hitstop() -> void:
	if not _hitstop_active:
		return
	if is_equal_approx(Engine.time_scale, float(_presence.get("time_scale_dip", 0.4))):
		Engine.time_scale = _hitstop_previous_scale
	_hitstop_active = false


func _duck_sfx() -> void:
	if _is_headless() or _ducked_bus_index != -1:
		return
	var bus_index := AudioServer.get_bus_index("SFX")
	if bus_index == -1:
		return
	_ducked_bus_index = bus_index
	_ducked_previous_db = AudioServer.get_bus_volume_db(bus_index)
	AudioServer.set_bus_volume_db(bus_index, _ducked_previous_db + SFX_DUCK_DB)


func _clear_presence() -> void:
	_restore_hitstop()
	_presence_state["backdrop_visible"] = false
	_presence_state["backdrop_alpha"] = 0.0
	_presence_state["cast_pose_scale"] = 0.0
	_presence_state["silhouette_scale"] = 0.0
	_presence_state["reduced_motion_substitute_applied"] = false
	_presence_state["phase_nodes_drawn"] = PackedStringArray()
	if _ducked_bus_index != -1 and AudioServer.get_bus_index("SFX") == _ducked_bus_index:
		AudioServer.set_bus_volume_db(_ducked_bus_index, _ducked_previous_db)
	_ducked_bus_index = -1
	## The shake tween outlives an early cancel and would keep writing the offset
	## after it was restored, so the scene kills what it started.
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = null
	if _camera != null and is_instance_valid(_camera):
		_camera.offset = _camera_offset_before_shake
	_camera = null
	if _backdrop != null and is_instance_valid(_backdrop):
		_backdrop.queue_free()
	_backdrop = null
	if _cast_pose != null and is_instance_valid(_cast_pose):
		_cast_pose.queue_free()
	_cast_pose = null
	if _silhouette != null and is_instance_valid(_silhouette):
		_silhouette.queue_free()
	_silhouette = null


func _exit_tree() -> void:
	_clear_presence()
