extends Node2D

## Shared driver of the three Soldier ultimate scenes.
##
## The authored AnimationPlayer timeline plays the formation. On top of it this
## driver runs the victim impacts for every beat that names victims, the
## grenade payoff drawn from the executor's own `.detonate` / `.crater` beats
## with the scene's existing nodes (FAN-3941), and — also FAN-3941 — the
## Ultimate Direction v2 weight devices the class manifest declares: the
## authored arena-wide backdrop veil (darken or single-shot flash), the hero
## cast pose, camera shake, the first-impact hitstop with its time-scale dip,
## and SFX ducking across the release window. The production accessibility
## policy is honoured: with `ultimate_reduced_motion` (or the shipped
## `screen_shake` toggle off) no device moves the camera, and with
## `ultimate_photosensitivity_safe` the arena-wide surface is never drawn.
## No node is allocated at runtime; every tween, dip and duck is tracked and
## restored on finish/exit so pause, cancel, death and node end leave nothing
## behind. Scenes without the payoff nodes ignore the payoff beats.

const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")
const PresentationManifest := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_manifest.gd")
const Accessibility := preload("res://scripts/settings/ultimate_accessibility_settings.gd")

const DETONATE_SUFFIX := ".detonate"
const CRATER_SUFFIX := ".crater"
const BLAST_NODE := "ChainBlast"
const CRATER_NODE := "FireColumn"
const BACKDROP_NODE := "BackdropVeil"
const HERO_POSE_NODE := "HeroPose"
const TIMELINE_NODE := "Timeline"
## The seeded props, consumed in detonation order as the outside-in chain runs.
const GRENADE_NODES: Array[String] = [
	"GrenadeOne", "GrenadeTwo", "GrenadeThree", "GrenadeFour", "GrenadeFive", "GrenadeSix", "GrenadeSeven",
]
const BLAST_RING_RADIUS := 218.0
const BLAST_SECONDS := 0.28
const BLAST_START_SCALE := 0.35
const CRATER_RISE_SECONDS := 0.25
const CRATER_PULSE_SECONDS := 0.2
const CRATER_FADE_SECONDS := 0.5
const CRATER_RING_ALPHA := 0.45
const CRATER_PULSE_ALPHA := 0.6
## Presence envelope: the darken veil swells to its peak by the active edge and
## holds to recovery; the flash veil is one shot at release with a decaying
## tail, so a single activation never repeats a full-screen surface.
const BACKDROP_PEAK_ALPHA := {"darken": 0.30, "flash": 0.28}
const FLASH_RISE_SECONDS := 0.06
const FLASH_TAIL_RATIO := 0.25
const BACKDROP_TINTS := {
	"soldier_rifle": Color(0.10, 0.11, 0.06),
	"soldier_grenade": Color(1.0, 0.78, 0.42),
	"soldier_bayonet": Color(0.07, 0.09, 0.12),
}
const SHAKE := {
	"soldier_rifle": {"seconds": 0.40, "amplitude": 7.0, "duck_db": -6.0},
	"soldier_grenade": {"seconds": 0.55, "amplitude": 10.0, "duck_db": -8.0},
	"soldier_bayonet": {"seconds": 0.60, "amplitude": 11.0, "duck_db": -7.0},
}
const CLASS_PALETTE := Color(0.82, 0.86, 0.62)
const BACKDROP_OVERSCAN := 1.02

@export var victim_frames: SpriteFrames

static var _duck_refs := 0
static var _duck_volume_before_db := 0.0
static var _duck_applied_db := 0.0
static var _dip_owner_id := 0

var _impacts: Node2D = null
var _impacts_started := false
var _payoff_tweens: Array[Tween] = []
var _detonations := 0
var _record: Dictionary = {}
var _elapsed := 0.0
var _impact_fired := false
var _hitstop_remaining := 0.0
var _shake_remaining := 0.0
var _camera: Camera2D = null
var _camera_offset_before_shake := Vector2.ZERO
var _duck_active := false
var _sfx_bus_index := -1
var _dip_active := false
var _dip_before := 1.0
var _dip_timer: SceneTreeTimer = null


func _enter_tree() -> void:
	_ensure_record()
	_reset_presence_nodes()


## The class record is read on first use as well as on enter_tree, so a
## headless contract tree that never runs the node lifecycle drives the same
## envelope the live game does.
func _ensure_record() -> Dictionary:
	if _record.is_empty():
		_record = _class_record()
	return _record


func _process(delta: float) -> void:
	_ensure_record()
	var timeline := get_node_or_null(TIMELINE_NODE) as AnimationPlayer
	if timeline != null and timeline.is_playing() and _hitstop_remaining <= 0.0:
		_elapsed = timeline.current_animation_position
	else:
		_elapsed += delta
	_advance_weight_devices(delta, _elapsed)
	_apply_presence(_elapsed)


func present(event_id: String, payload: Dictionary) -> void:
	# Payoff first: an explosion over an empty patch of arena is still an
	# explosion, so it must not depend on the victim list below.
	_present_payoff(event_id, payload)
	var raw_victims: Variant = payload.get("victims")
	if not raw_victims is Array or (raw_victims as Array).is_empty() or victim_frames == null:
		return
	if _impacts == null or not is_instance_valid(_impacts):
		_impacts = ImpactPlayer.new()
		add_child(_impacts)
		_impacts_started = false
	if _impacts_started:
		_impacts.enqueue(raw_victims as Array, global_position)
	else:
		_impacts.play(victim_frames, raw_victims as Array, global_position)
		_impacts_started = true


func finish(_reason: String) -> void:
	if _impacts != null and is_instance_valid(_impacts):
		_impacts.finish()
	_reset_payoff()
	_end_camera_shake()
	_end_sfx_ducking()
	_end_time_dip()
	_reset_presence_nodes()
	_impact_fired = false
	_hitstop_remaining = 0.0
	_shake_remaining = 0.0


func _exit_tree() -> void:
	_impacts = null
	_impacts_started = false
	_reset_payoff()
	_end_camera_shake()
	_end_sfx_ducking()
	_end_time_dip()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_end_camera_shake()
		_end_sfx_ducking()
		_end_time_dip()


## Live payoff and presence state, so a gate can read what the scene draws.
func payoff_snapshot() -> Dictionary:
	var ring := get_node_or_null(BLAST_NODE) as CanvasItem
	var column := get_node_or_null(CRATER_NODE) as CanvasItem
	var veil := get_node_or_null(BACKDROP_NODE) as CanvasItem
	return {
		"detonations": _detonations,
		"blast_alpha": ring.modulate.a if ring != null else 0.0,
		"blast_position": to_global((ring as Node2D).position) if ring != null else Vector2.ZERO,
		"crater_alpha": column.modulate.a if column != null else 0.0,
		"crater_position": to_global((column as Node2D).position) if column != null else Vector2.ZERO,
		"live_tweens": _live_tween_count(),
		"veil_alpha": veil.self_modulate.a if veil != null and veil.visible else 0.0,
		"hitstop_remaining": _hitstop_remaining,
		"elapsed": _elapsed,
	}


# --- class record ------------------------------------------------------------


## The class manifest is the timing and presence source, read through the same
## bridge the runtime uses; the scene's ultimate_id metadata names the pair.
func _class_record() -> Dictionary:
	var pair := str(get_meta("ultimate_id", "")).split("/")
	if pair.size() != 2:
		return {}
	return PresentationManifest.class_weapon_record(pair[0], pair[1])


func _weapon_id() -> String:
	var pair := str(get_meta("ultimate_id", "")).split("/")
	return pair[1] if pair.size() == 2 else ""


func _timing(key: String, fallback: float) -> float:
	return float((_record.get("timing", {}) as Dictionary).get(key, fallback))


func _presence() -> Dictionary:
	return _record.get("presence", {}) as Dictionary


# --- production accessibility policy ----------------------------------------


## The node the production policy is published on: the tree root in the game,
## the topmost ancestor in a headless contract tree that never runs the node
## lifecycle (get_tree() is null there while root already parents the scene).
func _policy_root() -> Node:
	var node: Node = self
	while node.get_parent() != null:
		node = node.get_parent()
	return node


func _motion_allowed() -> bool:
	var policy_root := _policy_root()
	if policy_root == self:
		return true
	if not bool(policy_root.get_meta("screen_shake", true)):
		return false
	return not bool(Accessibility.read_snapshot(policy_root).get(Accessibility.REDUCED_MOTION_KEY, false))


func _fullscreen_allowed() -> bool:
	var policy_root := _policy_root()
	if policy_root == self:
		return true
	return not bool(Accessibility.read_snapshot(policy_root).get(Accessibility.PHOTOSENSITIVITY_SAFE_KEY, false))


# --- presence devices --------------------------------------------------------


func _reset_presence_nodes() -> void:
	for node_name in [BACKDROP_NODE, HERO_POSE_NODE]:
		var node := get_node_or_null(node_name) as CanvasItem
		if node != null:
			node.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
			node.visible = false


## Arena-wide backdrop weight over the timeline, by the declared treatment.
func backdrop_alpha(elapsed: float) -> float:
	if _ensure_record().is_empty():
		return 0.0
	var release := _timing("release", 0.0)
	var active := _timing("active", 0.0)
	var recovery := _timing("recovery", 0.0)
	var cancel := _timing("cancel", 0.0)
	var treatment := str(_presence().get("backdrop", "darken"))
	var peak := float(BACKDROP_PEAK_ALPHA.get(treatment, 0.0))
	if elapsed <= 0.0 or elapsed >= cancel:
		return 0.0
	if treatment == "flash":
		if elapsed < release:
			return 0.0
		if elapsed < release + FLASH_RISE_SECONDS:
			return peak * _ratio(elapsed - release, FLASH_RISE_SECONDS)
		if elapsed < active:
			return lerpf(peak, peak * FLASH_TAIL_RATIO, _ratio(elapsed - release - FLASH_RISE_SECONDS, active - release - FLASH_RISE_SECONDS))
		return peak * FLASH_TAIL_RATIO * (1.0 - _ratio(elapsed - active, cancel - active))
	if elapsed < active:
		return peak * _ratio(elapsed, active)
	if elapsed < recovery:
		return peak
	return peak * (1.0 - _ratio(elapsed - recovery, cancel - recovery))


## Hero cast pose: the raised banner holds through the ceremony and fades out
## shortly after the release beat.
func hero_pose_alpha(elapsed: float) -> float:
	if _ensure_record().is_empty() or elapsed <= 0.0:
		return 0.0
	var release := _timing("release", 0.0)
	var active := _timing("active", 0.0)
	if elapsed < release:
		return 0.35 + 0.55 * _ratio(elapsed, release)
	if elapsed < active:
		return 0.90 * (1.0 - _ratio(elapsed - release, active - release))
	return 0.0


static func _ratio(value: float, span: float) -> float:
	return clampf(value / maxf(span, 0.0001), 0.0, 1.0)


func _apply_presence(elapsed: float) -> void:
	var veil := get_node_or_null(BACKDROP_NODE) as Sprite2D
	if veil != null:
		var alpha := backdrop_alpha(elapsed) if _fullscreen_allowed() else 0.0
		var tint: Color = BACKDROP_TINTS.get(_weapon_id(), Color.BLACK)
		veil.self_modulate = Color(tint.r, tint.g, tint.b, alpha)
		veil.visible = alpha > 0.0
		_fit_backdrop_to_viewport(veil)
	var pose := get_node_or_null(HERO_POSE_NODE) as Sprite2D
	if pose != null:
		var pose_alpha := hero_pose_alpha(elapsed)
		pose.self_modulate = Color(CLASS_PALETTE.r, CLASS_PALETTE.g, CLASS_PALETTE.b, pose_alpha)
		pose.visible = pose_alpha > 0.0


func _fit_backdrop_to_viewport(veil: Sprite2D) -> void:
	if veil.texture == null or not is_inside_tree():
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var rect := viewport.get_visible_rect()
	var camera := viewport.get_camera_2d()
	var visible_size: Vector2 = rect.size / camera.zoom if camera != null else rect.size
	var overscan := visible_size * (BACKDROP_OVERSCAN - 1.0) * 0.5
	veil.top_level = true
	veil.position = viewport.get_canvas_transform().affine_inverse() * rect.position - overscan
	veil.scale = (visible_size + overscan * 2.0) / Vector2(veil.texture.get_size())


## First impact at the declared active edge: the authored timeline pauses for
## the hitstop (the drawn pose freezes, the envelope clock keeps counting in
## the executor), the camera shakes, the time-scale dips, and SFX duck across
## the release window.
func _advance_weight_devices(delta: float, elapsed: float) -> void:
	if _record.is_empty():
		return
	var presence := _presence()
	var shake: Dictionary = SHAKE.get(_weapon_id(), {})
	var timeline := get_node_or_null(TIMELINE_NODE) as AnimationPlayer
	if _hitstop_remaining > 0.0:
		_hitstop_remaining = maxf(_hitstop_remaining - delta, 0.0)
		if _hitstop_remaining <= 0.0 and timeline != null and not timeline.is_playing() and timeline.has_animation(&"ultimate") and _elapsed < timeline.get_animation(&"ultimate").length:
			timeline.play(&"ultimate")
	elif not _impact_fired and elapsed >= _timing("active", INF):
		_impact_fired = true
		_hitstop_remaining = float(presence.get("hitstop_ms", 0.0)) / 1000.0
		_shake_remaining = float(shake.get("seconds", 0.0))
		if timeline != null and timeline.is_playing():
			timeline.pause()
		_begin_time_dip(float(presence.get("time_scale_dip", 1.0)), _hitstop_remaining)
	if elapsed >= _timing("release", INF) and elapsed < _timing("recovery", 0.0):
		_begin_sfx_ducking(float(shake.get("duck_db", 0.0)))
	elif _duck_active:
		_end_sfx_ducking()
	if _shake_remaining > 0.0:
		_shake_remaining = maxf(_shake_remaining - delta, 0.0)
		_apply_camera_shake(_shake_remaining, float(shake.get("seconds", 1.0)), float(shake.get("amplitude", 0.0)))


func _apply_camera_shake(remaining: float, window: float, amplitude: float) -> void:
	if not _motion_allowed() or amplitude <= 0.0:
		return
	if _camera == null or not is_instance_valid(_camera):
		_camera = _find_current_camera()
		if _camera == null:
			return
		_camera_offset_before_shake = _camera.offset
	var strength := amplitude * (remaining / maxf(window, 0.0001))
	_camera.offset = _camera_offset_before_shake + Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
	if remaining <= 0.0:
		_end_camera_shake()


func _end_camera_shake() -> void:
	if _camera != null and is_instance_valid(_camera):
		_camera.offset = _camera_offset_before_shake
	_camera = null


func _find_current_camera() -> Camera2D:
	if not is_inside_tree():
		return null
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	for node in tree.root.find_children("*", "Camera2D", true, false):
		var camera := node as Camera2D
		if camera != null and camera.is_current() and camera.enabled:
			return camera
	return null


func _begin_time_dip(dip: float, seconds: float) -> void:
	if _dip_active or dip <= 0.0 or dip >= 1.0 or seconds <= 0.0 or not is_inside_tree():
		return
	if Engine.time_scale < 0.99 or _dip_owner_id != 0:
		return
	_dip_active = true
	_dip_owner_id = get_instance_id()
	_dip_before = Engine.time_scale
	Engine.time_scale = dip
	_dip_timer = get_tree().create_timer(seconds, true, false, true)
	_dip_timer.timeout.connect(_end_time_dip)


func _end_time_dip() -> void:
	if not _dip_active:
		return
	_dip_active = false
	if _dip_owner_id == get_instance_id():
		_dip_owner_id = 0
		if is_equal_approx(Engine.time_scale, float(_presence().get("time_scale_dip", 1.0))):
			Engine.time_scale = _dip_before
	_dip_timer = null


func _begin_sfx_ducking(duck_db: float) -> void:
	if _duck_active or duck_db >= 0.0:
		return
	_sfx_bus_index = AudioServer.get_bus_index("SFX")
	if _sfx_bus_index == -1:
		return
	_duck_active = true
	if _duck_refs == 0:
		_duck_volume_before_db = AudioServer.get_bus_volume_db(_sfx_bus_index)
		_duck_applied_db = _duck_volume_before_db + duck_db
		AudioServer.set_bus_volume_db(_sfx_bus_index, _duck_applied_db)
	_duck_refs += 1


func _end_sfx_ducking() -> void:
	if not _duck_active:
		return
	_duck_active = false
	_duck_refs = maxi(_duck_refs - 1, 0)
	if _duck_refs == 0 and _sfx_bus_index != -1 \
			and is_equal_approx(AudioServer.get_bus_volume_db(_sfx_bus_index), _duck_applied_db):
		AudioServer.set_bus_volume_db(_sfx_bus_index, _duck_volume_before_db)
	_sfx_bus_index = -1


# --- grenade payoff ------------------------------------------------------------


func _present_payoff(event_id: String, payload: Dictionary) -> void:
	if event_id.ends_with(DETONATE_SUFFIX):
		_present_blast(payload)
	elif event_id.ends_with(CRATER_SUFFIX):
		_present_crater(payload)


func _present_blast(payload: Dictionary) -> void:
	var ring := get_node_or_null(BLAST_NODE) as Node2D
	if ring == null:
		return
	var center: Variant = payload.get("position")
	var radius := float(payload.get("radius", BLAST_RING_RADIUS))
	ring.position = to_local(center as Vector2) if center is Vector2 else Vector2.ZERO
	var target_scale := Vector2.ONE * maxf(radius, 1.0) / BLAST_RING_RADIUS
	ring.scale = target_scale * BLAST_START_SCALE
	ring.modulate = Color(1.0, 1.0, 1.0, 1.0)
	var tween := _payoff_tween()
	if tween == null:
		return
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", target_scale, BLAST_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, BLAST_SECONDS * 0.65).set_delay(BLAST_SECONDS * 0.35)
	if _detonations < GRENADE_NODES.size():
		var prop := get_node_or_null(GRENADE_NODES[_detonations]) as CanvasItem
		if prop != null:
			tween.tween_property(prop, "modulate:a", 0.0, BLAST_SECONDS)
	_detonations += 1


func _present_crater(payload: Dictionary) -> void:
	var column := get_node_or_null(CRATER_NODE) as Node2D
	var ring := get_node_or_null(BLAST_NODE) as Node2D
	if column == null:
		return
	var center: Variant = payload.get("position")
	var local := to_local(center as Vector2) if center is Vector2 else Vector2.ZERO
	var tick := int(payload.get("tick", 0))
	var ticks := maxi(int(payload.get("ticks", 1)), 1)
	var tween := _payoff_tween()
	if tween == null:
		return
	tween.set_parallel(true)
	if tick == 0:
		column.position = local
		column.scale = Vector2.ONE * 0.1
		column.modulate = Color(1.0, 1.0, 1.0, 0.0)
		tween.tween_property(column, "scale", Vector2.ONE, CRATER_RISE_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(column, "modulate:a", 1.0, CRATER_RISE_SECONDS)
		if ring != null:
			ring.position = local
			ring.scale = Vector2.ONE * maxf(float(payload.get("radius", BLAST_RING_RADIUS)), 1.0) / BLAST_RING_RADIUS
			ring.modulate = Color(1.0, 1.0, 1.0, 0.0)
			tween.tween_property(ring, "modulate:a", CRATER_RING_ALPHA, CRATER_RISE_SECONDS)
	else:
		tween.tween_property(column, "modulate:a", CRATER_PULSE_ALPHA, CRATER_PULSE_SECONDS * 0.5)
		tween.chain().tween_property(column, "modulate:a", 1.0, CRATER_PULSE_SECONDS * 0.5)
	if tick >= ticks - 1:
		var fade := _payoff_tween()
		if fade == null:
			return
		fade.set_parallel(true)
		fade.tween_property(column, "scale", Vector2.ONE * 1.15, CRATER_FADE_SECONDS).set_delay(CRATER_PULSE_SECONDS)
		fade.tween_property(column, "modulate:a", 0.0, CRATER_FADE_SECONDS).set_delay(CRATER_PULSE_SECONDS)
		if ring != null:
			fade.tween_property(ring, "modulate:a", 0.0, CRATER_FADE_SECONDS).set_delay(CRATER_PULSE_SECONDS)


func _payoff_tween() -> Tween:
	if not is_inside_tree():
		return null
	var tween := create_tween()
	_payoff_tweens.append(tween)
	return tween


func _live_tween_count() -> int:
	var live := 0
	for tween in _payoff_tweens:
		if tween != null and tween.is_valid() and tween.is_running():
			live += 1
	return live


func _reset_payoff() -> void:
	for tween in _payoff_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_payoff_tweens.clear()
	_detonations = 0
	for node_name in [BLAST_NODE, CRATER_NODE]:
		var node := get_node_or_null(node_name) as CanvasItem
		if node != null:
			node.modulate = Color(1.0, 1.0, 1.0, 0.0)
