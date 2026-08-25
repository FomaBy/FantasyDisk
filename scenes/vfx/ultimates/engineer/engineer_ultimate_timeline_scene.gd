class_name EngineerUltimateTimelineScene
extends Node2D

## Class-local scene driver for one engineer weapon ultimate timeline.
##
## The driver owns only the formation sprites it creates itself. It never
## touches shared VFX pools, and it delegates the whole lifecycle to
## `WeaponUltimatePresentationTimeline`, so pause, cancel, death, and node
## teardown behave exactly as the frozen presentation contract requires.
##
## FAN-1541 owns the shared runtime adapter that will eventually select this
## scene for a ready weapon; until then the scene is driven by tests and by the
## contact-sheet renderer.

const Pack := preload("res://scenes/vfx/ultimates/engineer/engineer_ultimate_presentation_pack.gd")
const Timeline := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_timeline.gd")

## Cleanup reasons the frozen timeline contract requires this scene to survive.
const CLEANUP_REASONS: Array[String] = ["cancel", "death", "node_end"]

## Draw order of one v2 activation: backdrop dim under everything the ultimate
## owns, chords under the pylons, the weapon sigil on top as the identity core.
const V2_BACKDROP_Z := 4
const V2_CHORD_Z := 5
const V2_ELEMENT_Z := 6
const V2_SIGIL_Z := 7
const V2_CHORD_WIDTH := 6.0
## How far past the pylon seats the crossfire chords reach, so the web reads
## arena-wide instead of stopping at the formation ring.
const V2_CHORD_REACH := 2.2
## First-impact hitstop slows real time this hard for presence.hitstop_ms.
const V2_HITSTOP_TIME_SCALE := 0.12
const V2_SFX_DUCK_DB := -8.0

@export var weapon_id: String = Pack.SENTRY_WRENCH

signal phase_entered(phase: Dictionary)
signal timeline_finished(reason: String)

var _timeline = null
var _manifest: Dictionary = {}
var _elements: Array[Sprite2D] = []
var _frames: Array[Texture2D] = []
var _backdrop: Sprite2D = null
var _sigil: Sprite2D = null
var _chords: Array[Sprite2D] = []
# Cached at begin() so the per-frame overlay pose allocates nothing.
var _v2_overlay: Dictionary = {}
var _presence: Dictionary = {}
var _ducked_bus_index := -1
var _ducked_prev_db := 0.0


func _ready() -> void:
	set_process(false)


## Start the timeline for the configured weapon.
##
## `handles` are the animation/VFX/SFX handles the caller owns; the timeline
## releases every one of them on any cleanup reason. Pass `headless_mode` 1 or
## 0 to force deterministic behavior in tests.
func begin(registry, handles: Dictionary = {}, headless_mode := -1) -> Dictionary:
	finish("node_end")
	_manifest = Pack.manifest_for(registry, weapon_id)
	if _manifest.is_empty():
		push_error("EngineerUltimateTimelineScene: no manifest for %s" % weapon_id)
		return {}
	_timeline = Timeline.new(_manifest, headless_mode)
	var snapshot: Dictionary = _timeline.begin(handles)
	if str(snapshot.get("state", "")) == Timeline.ACTIVE_STATE:
		_cache_v2_config()
		_build_elements()
		_build_v2_overlay()
		_apply_formation(0.0)
		set_process(true)
	return snapshot


func set_paused(value: bool) -> void:
	if _timeline == null:
		return
	_timeline.set_paused(value)


func is_active() -> bool:
	return _timeline != null and str(_timeline.snapshot().get("state", "")) == Timeline.ACTIVE_STATE


## Release every handle, every sprite and every overlay this scene created.
func finish(reason: String) -> Dictionary:
	if _timeline == null:
		return {}
	var snapshot := _release_handles(reason)
	_clear_elements()
	set_process(false)
	timeline_finished.emit(reason)
	return snapshot


## Hand every owned handle back to the timeline without touching nodes.
##
## Kept separate from `finish` so the predelete path can run during destruction,
## where freeing children or emitting signals is not safe.
func _release_handles(reason: String) -> Dictionary:
	if _timeline == null:
		return {}
	_restore_sfx_duck()
	var snapshot: Dictionary = _timeline.finish(reason)
	_timeline = null
	return snapshot


func _process(delta: float) -> void:
	# The presentation clock stays unscaled through its own hitstop, the same
	# compensation the ultimate host applies to its presentation timeline.
	step(delta / maxf(Engine.time_scale, 0.05))


## Advance the timeline by `delta` seconds and restate the formation.
##
## Exposed so tests and the contact-sheet renderer drive the same code the
## frame loop drives, instead of a second copy of the motion.
func step(delta: float) -> void:
	if _timeline == null:
		return
	for event in _timeline.advance(delta):
		match str((event as Dictionary).get("name", "")):
			"release":
				_apply_release_weight()
			"recovery":
				_restore_sfx_duck()
		phase_entered.emit(event)
	var elapsed: float = _timeline.elapsed_seconds()
	_apply_formation(elapsed)
	if elapsed >= Pack.timeline_seconds(weapon_id):
		finish("node_end")


func _exit_tree() -> void:
	# Node teardown must never orphan a handle, even mid-timeline.
	finish("node_end")


func _notification(what: int) -> void:
	# A scene freed before it ever entered the tree never gets `_exit_tree`, so
	# predelete is the last guaranteed chance to release the owned handles.
	if what == NOTIFICATION_PREDELETE:
		_release_handles("node_end")


func _build_elements() -> void:
	_clear_elements()
	_frames.clear()
	for path in Pack.element_frame_paths(weapon_id):
		var frame: Texture2D = load(path)
		if frame == null:
			push_error("EngineerUltimateTimelineScene: missing runtime frame %s" % path)
			return
		_frames.append(frame)
	var texture: Texture2D = _frames[0]
	var pivot: Dictionary = _manifest.get("pivot", {})
	var formation: Dictionary = Pack.weapon_config(weapon_id).get("formation", {})
	var count := mini(int(formation.get("count", 0)), Pack.MAX_ELEMENTS_PER_ULTIMATE)
	var v2_active := not _v2_overlay_config().is_empty()
	for index in count:
		var sprite := Sprite2D.new()
		sprite.name = "Pylon%d" % index
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.centered = false
		sprite.offset = -Vector2(
			texture.get_width() * float(pivot.get("x", 0.5)),
			texture.get_height() * float(pivot.get("y", 0.5))
		)
		if v2_active:
			sprite.z_index = V2_ELEMENT_Z
		add_child(sprite)
		_elements.append(sprite)


func _clear_elements() -> void:
	for sprite in _elements:
		if is_instance_valid(sprite):
			sprite.queue_free()
	_elements.clear()
	for chord in _chords:
		if is_instance_valid(chord):
			chord.queue_free()
	_chords.clear()
	if _backdrop != null and is_instance_valid(_backdrop):
		_backdrop.queue_free()
	_backdrop = null
	if _sigil != null and is_instance_valid(_sigil):
		_sigil.queue_free()
	_sigil = null


func _apply_formation(elapsed: float) -> void:
	if _elements.is_empty():
		return
	var phase := Pack.phase_at(weapon_id, elapsed)
	var phase_name := str(phase.get("name", ""))
	var progress := float(phase.get("progress", 0.0))
	_apply_v2_overlay(phase_name, progress)
	var points := Pack.formation_points(weapon_id, phase_name, progress)
	# The frame is a pure function of the timeline, so a paused timeline holds
	# its frame and the contact sheet shows the frame the scene plays.
	var frame: Texture2D = _frames[mini(Pack.frame_index(weapon_id, phase_name, progress), _frames.size() - 1)]
	for index in _elements.size():
		var sprite := _elements[index]
		if index >= points.size():
			sprite.visible = false
			continue
		var point: Dictionary = points[index]
		var alpha := float(point.get("alpha", 1.0))
		sprite.texture = frame
		sprite.visible = alpha > 0.0
		sprite.position = point.get("position", Vector2.ZERO)
		sprite.scale = Vector2.ONE * float(point.get("scale", 1.0))
		sprite.rotation = float(point.get("rotation", 0.0))
		sprite.modulate = Color(1.0, 1.0, 1.0, alpha)


# --- Ultimate Direction v2 overlay and weight (FAN-2960) ----------------------


func _v2_overlay_config() -> Dictionary:
	return _v2_overlay


func _presence_config() -> Dictionary:
	return _presence


func _cache_v2_config() -> void:
	var config := Pack.weapon_config(weapon_id)
	_v2_overlay = config.get("v2_overlay", {}) if config.get("v2_overlay") is Dictionary else {}
	_presence = config.get("presence", {}) if config.get("presence") is Dictionary else {}


## Build the declared full-screen layers of a migrated weapon: one translucent
## backdrop dim, the arena-wide crossfire chords, and the weapon-silhouette
## sigil that is the identity core of the effect. A weapon without a
## `v2_overlay` block keeps its exact v1 scene shape.
func _build_v2_overlay() -> void:
	var overlay := _v2_overlay_config()
	if overlay.is_empty():
		return
	var half: Dictionary = overlay.get("backdrop_half_size", {})
	var half_size := Vector2(float(half.get("x", 1400.0)), float(half.get("y", 800.0)))
	var overlay_texture := _v2_overlay_texture()
	_backdrop = Sprite2D.new()
	_backdrop.name = "BackdropDim"
	_backdrop.texture = overlay_texture
	_backdrop.centered = false
	_backdrop.position = -half_size
	_backdrop.scale = half_size * 2.0 / Vector2(overlay_texture.get_width(), overlay_texture.get_height())
	_backdrop.modulate = _v2_color(overlay.get("backdrop_color", {}), 0.0)
	_backdrop.z_index = V2_BACKDROP_Z
	add_child(_backdrop)

	var formation: Dictionary = Pack.weapon_config(weapon_id).get("formation", {})
	var count := int(formation.get("count", 0))
	var radius := float(formation.get("radius", 0.0))
	# Opposite hex seats mirror through the origin, so each chord is one line
	# through the hero, extended past the seats to read arena-wide.
	for index in count / 2:
		var chord := Sprite2D.new()
		chord.name = "CrossfireChord%d" % index
		var seat := _v2_seat(index, count, radius)
		var endpoint := seat * V2_CHORD_REACH
		chord.texture = overlay_texture
		chord.position = Vector2.ZERO
		chord.rotation = endpoint.angle()
		chord.scale = Vector2(endpoint.length() * 2.0 / float(overlay_texture.get_width()), V2_CHORD_WIDTH / float(overlay_texture.get_height()))
		chord.modulate = _v2_color(overlay.get("chord_color", {}), 0.0)
		chord.z_index = V2_CHORD_Z
		add_child(chord)
		_chords.append(chord)

	var identity: Dictionary = Pack.weapon_config(weapon_id).get("identity", {})
	var texture: Texture2D = load(str(identity.get("weapon_silhouette_asset", "")))
	if texture != null:
		_sigil = Sprite2D.new()
		_sigil.name = "WrenchSigil"
		_sigil.texture = texture
		_sigil.z_index = V2_SIGIL_Z
		_sigil.modulate = Color(1.0, 1.0, 1.0, 0.0)
		add_child(_sigil)


func _v2_seat(index: int, count: int, radius: float) -> Vector2:
	var angle := TAU * float(index) / float(maxi(count, 1)) - PI * 0.5
	return Vector2(cos(angle), sin(angle) * 0.62) * radius


func _v2_overlay_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 64
	return texture


func _v2_color(raw, alpha: float) -> Color:
	var channels: Dictionary = raw as Dictionary if raw is Dictionary else {}
	return Color(
		float(channels.get("r", 1.0)),
		float(channels.get("g", 1.0)),
		float(channels.get("b", 1.0)),
		alpha
	)


## Overlay pose for one timeline sample. Every alpha and transform derives only
## from (phase, progress), so a paused timeline holds its frame and the capture
## sheet shows the frames the scene plays.
func _apply_v2_overlay(phase_name: String, progress: float) -> void:
	if _backdrop == null:
		return
	var overlay := _v2_overlay_config()
	var peak := float(overlay.get("backdrop_peak_alpha", 0.42))
	var t := clampf(progress, 0.0, 1.0)
	var backdrop_alpha := 0.0
	var chord_alpha := 0.0
	var sigil_alpha := 0.0
	var sigil_scale := 1.0
	var sigil_position := Vector2.ZERO
	var sigil_rotation := 0.0
	match phase_name:
		"windup":
			# Cast ceremony: the frame dims, the wrench sigil rises over the
			# hero, and faint chords call out the arena the nest will hold.
			backdrop_alpha = peak * ease(t, 0.6)
			chord_alpha = 0.12 * t
			sigil_alpha = lerpf(0.22, 0.92, t)
			sigil_scale = lerpf(0.9, 3.4, ease(t, 0.55))
			sigil_position = Vector2(0.0, lerpf(-46.0, -150.0, ease(t, 0.55)))
			sigil_rotation = sin(t * TAU) * 0.06
		"release":
			backdrop_alpha = peak
			chord_alpha = lerpf(0.12, 0.55, t)
			sigil_alpha = 1.0
			sigil_scale = lerpf(3.4, 4.3, ease(t, 0.3))
			sigil_position = Vector2(0.0, lerpf(-150.0, -12.0, ease(t, 0.3)))
		"active":
			var volley := absf(sin(t * float(Pack.SENTRY_VOLLEY_BEATS) * PI))
			backdrop_alpha = peak
			chord_alpha = 0.30 + 0.25 * volley
			sigil_alpha = 0.80 + 0.15 * volley
			sigil_scale = 4.3 + 0.06 * volley
			sigil_position = Vector2(0.0, -12.0)
			sigil_rotation = t * PI * 0.5
		"recovery":
			backdrop_alpha = lerpf(peak, 0.10, t)
			chord_alpha = lerpf(0.40, 0.06, t)
			sigil_alpha = lerpf(0.95, 0.35, t)
			sigil_scale = lerpf(4.3, 2.0, t)
			sigil_position = Vector2(0.0, lerpf(-12.0, -60.0, t))
			sigil_rotation = PI * 0.5
		"cancel":
			backdrop_alpha = lerpf(0.10, 0.0, t)
			sigil_alpha = lerpf(0.35, 0.0, t)
			sigil_scale = lerpf(2.0, 1.2, t)
			sigil_position = Vector2(0.0, lerpf(-60.0, -90.0, t))
			sigil_rotation = PI * 0.5
	_backdrop.modulate.a = backdrop_alpha
	_backdrop.visible = backdrop_alpha > 0.0
	for chord in _chords:
		chord.modulate.a = chord_alpha
		chord.visible = chord_alpha > 0.0
	if _sigil != null:
		_sigil.modulate.a = sigil_alpha
		_sigil.visible = sigil_alpha > 0.0
		_sigil.scale = Vector2.ONE * sigil_scale
		_sigil.position = sigil_position
		_sigil.rotation = sigil_rotation


## Presence weight at the first impact: camera shake, hitstop, SFX ducking.
## Node-free runtime effects per the v2 contract; skipped in headless gates so
## the focused tests stay deterministic.
func _apply_release_weight() -> void:
	var presence := _presence_config()
	if presence.is_empty() or DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	if presence.get("camera_shake") == true:
		_shake_player_camera(7.0, 0.22)
	var hitstop_ms := float(presence.get("hitstop_ms", 0.0))
	# Hitstop idiom from combat_director: dip real time once, restore on a
	# timer that ignores time_scale and survives pause. Never stack a dip.
	if hitstop_ms > 0.0 and Engine.time_scale >= 0.99:
		Engine.time_scale = V2_HITSTOP_TIME_SCALE
		var timer: SceneTreeTimer = get_tree().create_timer(hitstop_ms / 1000.0, true, false, true)
		timer.timeout.connect(func() -> void: Engine.time_scale = 1.0)
	if presence.get("sfx_ducking") == true:
		_duck_sfx_bus()


## Player-camera shake, gated by the same screen_shake setting every other
## shake in the game honours.
func _shake_player_camera(intensity: float, duration: float) -> void:
	if not bool(get_tree().root.get_meta("screen_shake", true)):
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	var tween := camera.create_tween()
	var steps := 5
	for i in range(steps):
		var falloff := 1.0 - float(i) / float(steps)
		var off := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * intensity * falloff
		tween.tween_property(camera, "offset", off, duration / float(steps))
	tween.tween_property(camera, "offset", Vector2.ZERO, duration / float(steps))


## ponytail: ducks the whole SFX bus, including this ultimate's own impact SFX
## (-8 dB, still audible); a dedicated ultimate bus is the upgrade path if the
## mix ever needs the release beat fully separated.
func _duck_sfx_bus() -> void:
	if _ducked_bus_index != -1:
		return
	var bus_index := AudioServer.get_bus_index("SFX")
	if bus_index == -1:
		return
	_ducked_bus_index = bus_index
	_ducked_prev_db = AudioServer.get_bus_volume_db(bus_index)
	AudioServer.set_bus_volume_db(bus_index, _ducked_prev_db + V2_SFX_DUCK_DB)


func _restore_sfx_duck() -> void:
	if _ducked_bus_index == -1:
		return
	if AudioServer.get_bus_index("SFX") == _ducked_bus_index:
		AudioServer.set_bus_volume_db(_ducked_bus_index, _ducked_prev_db)
	_ducked_bus_index = -1
