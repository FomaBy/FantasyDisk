class_name EngineerUltimateAccessibilityDriver
extends Node2D

## Production presentation owner for the three Engineer ultimates.
##
## The executor subclasses retain every gameplay primitive. This base reads the
## coherent Main-applied accessibility snapshot and owns only class-local
## presentation: the authored Timeline, steady safety substitutes, backdrop,
## first-impact weight, temporary-device appearance, and victim feedback.

const Accessibility := preload("res://scripts/settings/ultimate_accessibility_settings.gd")
const PresentationManifest := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_manifest.gd")
const SharedImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")

const CLASS_ID := "engineer"
const VICTIMS_KEY := "victims"
const COMBAT_FEEDBACK_FLASH_GROUP := "combat_feedback_flashes"
const NORMAL_BACKDROP_ALPHA := 0.20
const STEADY_BACKDROP_ALPHA := 0.14
const BACKDROP_OVERSCAN := 1.02
const SFX_DUCK_DB := -8.0
const HITSTOP_TIME_SCALE := 0.40
const SHAKE_SECONDS := 0.42
const SHAKE_AMPLITUDE := 7.0
const HELD_FADE_SECONDS := 0.35
const PHOTOSAFE_MARKER_ALPHA := 0.10
const PHOTOSAFE_MARKER_REACH := 22.0
const PHOTOSAFE_IMPACT_ALPHA := 0.12
const PHOTOSAFE_IMPACT_SCALE := 0.24

static var _duck_refs := 0
static var _duck_volume_before_db := 0.0

var _manifest: Dictionary = {}
var _modes: Dictionary = Accessibility.default_snapshot()
var _weapon_id := ""
var _elapsed := 0.0
var _paused := false
var _release_fired := false
var _visual_complete := false
var _headless_mode := -1
var _timeline: AnimationPlayer = null
var _presentation_sprite: AnimatedSprite2D = null
var _backdrop: Sprite2D = null
var _identity: Sprite2D = null
var _impacts: Node2D = null
var _camera: Camera2D = null
var _camera_offset_before_shake := Vector2.ZERO
var _shake_remaining := 0.0
var _hitstop_remaining := 0.0
var _hitstop_previous_scale := 1.0
var _hitstop_active := false
var _duck_active := false
var _sfx_bus_index := -1


func _ready() -> void:
	_resolve_scene_contract()
	_apply_live_snapshot()
	_build_presence()
	_apply_mode_visuals()


## Called by WeaponUltimatePresentationRuntime after the scene is mounted.
## Re-reading here closes the gap between scene construction and a deliberately
## applied live snapshot without inventing another metadata convention.
func begin(registry, _handles := {}, headless_mode := -1) -> Dictionary:
	_ensure_scene_contract()
	_headless_mode = headless_mode
	if registry != null and registry.has_method("catalog_profile_for"):
		var profile: Dictionary = registry.call("catalog_profile_for", CLASS_ID, _weapon_id)
		var resolved := PresentationManifest.manifest_for_profile(profile)
		if not resolved.is_empty():
			_manifest = resolved
	_apply_live_snapshot()
	_reset_runtime_state()
	_apply_mode_visuals()
	return accessibility_state_for_tests()


func advance(delta_seconds: float) -> Array[Dictionary]:
	if _paused:
		return []
	var step := maxf(delta_seconds, 0.0)
	if _visual_complete:
		# Gameplay lifetimes intentionally outlive the shorter presentation
		# envelope. Late executor beats still need their bounded victim feedback.
		if _impacts != null and is_instance_valid(_impacts):
			_impacts.call("advance", step)
			if _photosensitivity_safe():
				_apply_photosafe_impacts()
		return []
	_elapsed += step
	_fit_backdrop_to_viewport()
	_update_backdrop(step)
	if _uses_held_visuals():
		_hold_visuals()
	if _impacts != null and is_instance_valid(_impacts):
		_impacts.call("advance", step)
		if _photosensitivity_safe():
			_apply_photosafe_impacts()
	var timing := _timing()
	if not _release_fired and _elapsed >= float(timing.get("release", INF)):
		_release_fired = true
		_apply_release_presence()
	if _duck_active and _elapsed >= float(timing.get("recovery", INF)):
		_end_sfx_ducking()
	_advance_hitstop(step)
	_advance_camera_shake(step)
	if _elapsed >= float(timing.get("cancel", INF)):
		_complete_visual_envelope()
	return []


func set_paused(value: bool) -> void:
	_paused = value
	if _timeline != null:
		if value:
			_timeline.pause()
		elif not _uses_held_visuals() and not _visual_complete \
				and not _timeline.assigned_animation.is_empty():
			_timeline.play()
	if _impacts != null and is_instance_valid(_impacts):
		_impacts.call("set_paused", value)
	if value:
		_restore_hitstop()
		_end_camera_shake()
		_end_sfx_ducking()
	elif _release_fired and _elapsed < float(_timing().get("recovery", INF)):
		_begin_sfx_ducking()


func finish(_reason: String) -> void:
	_restore_hitstop()
	_end_camera_shake()
	_end_sfx_ducking()
	if _impacts != null and is_instance_valid(_impacts):
		_impacts.call("finish")
	_impacts = null
	if _timeline != null:
		_timeline.stop()
	_hide_owned_visuals()
	_elapsed = 0.0
	_release_fired = false
	_visual_complete = true


func present(_event_id: String, payload: Dictionary) -> void:
	_ensure_scene_contract()
	var raw_victims: Variant = payload.get(VICTIMS_KEY, [])
	if not raw_victims is Array or (raw_victims as Array).is_empty():
		return
	if _impacts == null or not is_instance_valid(_impacts):
		var scene_script := get_script() as Script
		_impacts = scene_script.call("new_victim_impact_player") \
			if scene_script != null and scene_script.has_method("new_victim_impact_player") \
			else SharedImpactPlayer.new()
		# Normal mode preserves the pre-existing class contract for callers that
		# route only presentation beats. Photosafe production damage has already
		# passed through deal_damage_with_accessibility(), which retains exactly
		# one bounded ordinary marker and must not add another white flash here.
		_impacts.set("extra_hit_flash", not _photosensitivity_safe())
		_impacts.set_process(false)
		add_child(_impacts)
		var frames := _presentation_sprite.sprite_frames if _presentation_sprite != null else null
		_impacts.call("play", frames, raw_victims as Array, global_position)
	else:
		_impacts.call("enqueue", raw_victims as Array, global_position)
	if _photosensitivity_safe():
		# Spawn all entries that are ready in this frame, then freeze their actual
		# AnimatedSprite2D clocks before the renderer can display a rapid cycle.
		_impacts.call("advance", 0.0)
		_apply_photosafe_impacts()


func accessibility_state_for_tests() -> Dictionary:
	return {
		"weapon_id": _weapon_id,
		"modes": _modes.duplicate(true),
		"held_visuals": _uses_held_visuals(),
		"timeline_playing": _timeline != null and _timeline.is_playing(),
		"timeline_process_mode": _timeline.process_mode if _timeline != null else -1,
		"frame": _presentation_sprite.frame if _presentation_sprite != null else -1,
		"sprite_playing": _presentation_sprite.is_playing() if _presentation_sprite != null else false,
		"backdrop_alpha": _backdrop.modulate.a if _backdrop != null else 0.0,
		"camera_shake_active": _shake_remaining > 0.0,
		"hitstop_active": _hitstop_active,
		"sfx_ducked": _duck_active,
		"elapsed_seconds": _elapsed,
		"visual_complete": _visual_complete,
		"ordinary_feedback_enabled": _combat_feedback_enabled(),
		"impact_snapshot": _impacts.call("snapshot") if _impacts != null and is_instance_valid(_impacts) else {},
	}


## Executes the unchanged damage primitive, then adapts only feedback created
## synchronously by this Engineer hit. Damage numbers remain untouched and the
## root combat-feedback setting is never changed, so unrelated feedback keeps
## its normal path.
static func deal_damage_with_accessibility(
	activation,
	target: Node,
	amount: float,
	extra_feedback: Dictionary,
	event_id: String,
	secondary := false
):
	var modes := modes_for_activation(activation)
	if not bool(modes.get(Accessibility.PHOTOSENSITIVITY_SAFE_KEY, false)):
		return activation.deal_damage(target, amount, extra_feedback, event_id, secondary)
	var tree := target.get_tree() if target != null and is_instance_valid(target) else null
	var known_flashes := _group_instance_ids(tree, COMBAT_FEEDBACK_FLASH_GROUP)
	var body := target.call("_feedback_flash_body") as CanvasItem \
		if target != null and target.has_method("_feedback_flash_body") else null
	var body_modulate := body.modulate if body != null else Color.WHITE
	var result = activation.deal_damage(target, amount, extra_feedback, event_id, secondary)
	if body != null and is_instance_valid(body):
		# The ordinary tween captures its initial value on its first process tick.
		# Restoring synchronously therefore makes both its start and destination
		# the original tint, with no rendered body flash.
		body.modulate = body_modulate
	_adapt_new_hit_ticks(tree, known_flashes, target)
	return result


## Temporary devices remain at the exact executor-owned positions and follow
## the same movement calls. Only their class-local sprite presentation changes.
static func configure_device_visual(activation, device: Node2D, sprite: Sprite2D) -> void:
	var modes := modes_for_activation(activation)
	device.set_meta("ultimate_accessibility_modes", modes.duplicate(true))
	if bool(modes.get(Accessibility.REDUCED_MOTION_KEY, false)):
		sprite.set_meta("steady_lens", true)
		sprite.modulate = Color(0.78, 0.96, 0.92, 0.78)
	if bool(modes.get(Accessibility.PHOTOSENSITIVITY_SAFE_KEY, false)):
		sprite.set_meta("photosensitivity_safe", true)
		sprite.modulate.a = minf(sprite.modulate.a, 0.62)


static func modes_for_activation(activation) -> Dictionary:
	if activation == null:
		return Accessibility.default_snapshot()
	var host := activation.get("host") as Node
	if host == null or not is_instance_valid(host) or host.get_tree() == null:
		return Accessibility.default_snapshot()
	return Accessibility.read_snapshot(host.get_tree().root)


func _resolve_scene_contract() -> void:
	_weapon_id = str(get_meta("ultimate_id", "")).get_slice("/", 1)
	_manifest = {
		"runtime": PresentationManifest.class_weapon_record(CLASS_ID, _weapon_id),
	}
	var record := PresentationManifest.class_weapon_record(CLASS_ID, _weapon_id)
	if not record.is_empty():
		_manifest = {
			"timing": record.get("timing", {}),
			"presence": record.get("presence", {}),
			"identity": record.get("identity", {}),
			"quality": record.get("quality", {}),
		}
	_timeline = get_node_or_null("Timeline") as AnimationPlayer
	_presentation_sprite = get_node_or_null(get_meta("accessibility_sprite", NodePath(""))) as AnimatedSprite2D


func _ensure_scene_contract() -> void:
	# SceneTree script tests can call the public presentation surface in the
	# same tick in which they mount the PackedScene, before NOTIFICATION_READY.
	# Production reaches ready first, but resolving lazily keeps that public
	# surface deterministic in both lifecycles.
	if _weapon_id.is_empty() or _presentation_sprite == null:
		_resolve_scene_contract()


func _apply_live_snapshot() -> void:
	_modes = Accessibility.read_snapshot(get_tree().root if get_tree() != null else null)


func _reset_runtime_state() -> void:
	_restore_hitstop()
	_end_camera_shake()
	_end_sfx_ducking()
	_elapsed = 0.0
	_paused = false
	_release_fired = false
	_visual_complete = false
	if _backdrop != null:
		_backdrop.visible = true
	if _identity != null:
		_identity.visible = true
	if _presentation_sprite != null:
		_presentation_sprite.visible = true


func _apply_mode_visuals() -> void:
	if not _uses_held_visuals():
		return
	if _timeline != null:
		_timeline.stop()
		_timeline.process_mode = Node.PROCESS_MODE_DISABLED
	_hold_visuals()
	if _backdrop != null:
		_backdrop.modulate.a = STEADY_BACKDROP_ALPHA


func _hold_visuals() -> void:
	if _timeline != null and _timeline.is_playing():
		_timeline.stop()
	if _presentation_sprite != null:
		_presentation_sprite.stop()
		_presentation_sprite.frame = clampi(int(get_meta("accessibility_hold_frame", 4)), 0, 8)
		_presentation_sprite.scale = get_meta("accessibility_steady_scale", Vector2.ONE) as Vector2
		var fade := smoothstep(0.0, HELD_FADE_SECONDS, _elapsed)
		_presentation_sprite.modulate = Color(0.86, 0.96, 0.93, 0.84 * fade)
		_presentation_sprite.visible = not _visual_complete
	if _identity != null:
		_identity.modulate = Color(0.58, 0.92, 0.86, 0.52 * smoothstep(0.0, HELD_FADE_SECONDS, _elapsed))
		_identity.visible = not _visual_complete


func _build_presence() -> void:
	if _backdrop != null:
		return
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(0.72, 0.92, 0.88, 1.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.width = 64
	texture.height = 64
	_backdrop = Sprite2D.new()
	_backdrop.name = "EngineerBackdrop"
	_backdrop.texture = texture
	_backdrop.centered = false
	_backdrop.top_level = true
	_backdrop.z_index = -20
	_backdrop.modulate = Color(0.015, 0.040, 0.050, STEADY_BACKDROP_ALPHA if _uses_held_visuals() else 0.04)
	add_child(_backdrop)
	_fit_backdrop_to_viewport()
	var identity_path := str((_manifest.get("identity", {}) as Dictionary).get("weapon_silhouette_asset", ""))
	var identity_texture := load(identity_path) as Texture2D if not identity_path.is_empty() else null
	if identity_texture != null:
		_identity = Sprite2D.new()
		_identity.name = "EngineerWeaponSigil"
		_identity.texture = identity_texture
		_identity.scale = Vector2.ONE * 0.42
		_identity.modulate = Color(0.60, 0.95, 0.88, 0.62)
		_identity.z_index = 1
		add_child(_identity)


func _fit_backdrop_to_viewport() -> void:
	if _backdrop == null or _backdrop.texture == null or get_viewport() == null:
		return
	var viewport := get_viewport()
	var rect := viewport.get_visible_rect()
	var camera := viewport.get_camera_2d()
	var visible_size: Vector2 = rect.size / camera.zoom if camera != null else rect.size
	var overscan := visible_size * (BACKDROP_OVERSCAN - 1.0) * 0.5
	var size := visible_size + overscan * 2.0
	_backdrop.position = viewport.get_canvas_transform().affine_inverse() * rect.position - overscan
	_backdrop.scale = size / _backdrop.texture.get_size()


func _update_backdrop(delta_seconds: float) -> void:
	if _backdrop == null:
		return
	var target := STEADY_BACKDROP_ALPHA
	if not _uses_held_visuals():
		var timing := _timing()
		if _elapsed < float(timing.get("release", 0.0)):
			target = 0.10
		elif _elapsed < float(timing.get("recovery", INF)):
			target = NORMAL_BACKDROP_ALPHA
		else:
			target = 0.08
	_backdrop.modulate.a = move_toward(_backdrop.modulate.a, target, delta_seconds * 0.45)


func _apply_release_presence() -> void:
	_begin_sfx_ducking()
	if _reduced_motion():
		return
	_start_hitstop(float((_manifest.get("presence", {}) as Dictionary).get("hitstop_ms", 0.0)))
	_start_camera_shake()


func _start_hitstop(milliseconds: float) -> void:
	if milliseconds <= 0.0 or _is_headless() or _hitstop_active or Engine.time_scale < 0.99:
		return
	_hitstop_previous_scale = Engine.time_scale
	Engine.time_scale = HITSTOP_TIME_SCALE
	_hitstop_remaining = milliseconds / 1000.0
	_hitstop_active = true


func _advance_hitstop(delta_seconds: float) -> void:
	if not _hitstop_active:
		return
	_hitstop_remaining = maxf(_hitstop_remaining - delta_seconds, 0.0)
	if _hitstop_remaining <= 0.0:
		_restore_hitstop()


func _restore_hitstop() -> void:
	if _hitstop_active and is_equal_approx(Engine.time_scale, HITSTOP_TIME_SCALE):
		Engine.time_scale = _hitstop_previous_scale
	_hitstop_active = false
	_hitstop_remaining = 0.0


func _start_camera_shake() -> void:
	if _is_headless() or not _screen_shake_enabled() or get_viewport() == null:
		return
	_camera = get_viewport().get_camera_2d()
	if _camera == null:
		return
	_camera_offset_before_shake = _camera.offset
	_shake_remaining = SHAKE_SECONDS


func _advance_camera_shake(delta_seconds: float) -> void:
	if _shake_remaining <= 0.0 or _camera == null or not is_instance_valid(_camera):
		return
	_shake_remaining = maxf(_shake_remaining - delta_seconds, 0.0)
	var strength := SHAKE_AMPLITUDE * (_shake_remaining / SHAKE_SECONDS)
	_camera.offset = _camera_offset_before_shake + Vector2(
		sin(_elapsed * 73.0) * strength,
		cos(_elapsed * 59.0) * strength * 0.72
	)
	if _shake_remaining <= 0.0:
		_end_camera_shake()


func _end_camera_shake() -> void:
	if _camera != null and is_instance_valid(_camera):
		_camera.offset = _camera_offset_before_shake
	_camera = null
	_shake_remaining = 0.0


func _begin_sfx_ducking() -> void:
	if _duck_active or _is_headless():
		return
	_sfx_bus_index = AudioServer.get_bus_index("SFX")
	if _sfx_bus_index == -1:
		return
	_duck_active = true
	if _duck_refs == 0:
		_duck_volume_before_db = AudioServer.get_bus_volume_db(_sfx_bus_index)
		AudioServer.set_bus_volume_db(_sfx_bus_index, _duck_volume_before_db + SFX_DUCK_DB)
	_duck_refs += 1


func _end_sfx_ducking() -> void:
	if not _duck_active:
		return
	_duck_active = false
	_duck_refs = maxi(_duck_refs - 1, 0)
	if _duck_refs == 0 and _sfx_bus_index != -1 \
			and is_equal_approx(AudioServer.get_bus_volume_db(_sfx_bus_index), _duck_volume_before_db + SFX_DUCK_DB):
		AudioServer.set_bus_volume_db(_sfx_bus_index, _duck_volume_before_db)
	_sfx_bus_index = -1


func _complete_visual_envelope() -> void:
	_visual_complete = true
	_restore_hitstop()
	_end_camera_shake()
	_end_sfx_ducking()
	if _timeline != null:
		_timeline.stop()
	_hide_owned_visuals()


func _hide_owned_visuals() -> void:
	if _backdrop != null:
		_backdrop.visible = false
	if _identity != null:
		_identity.visible = false
	if _presentation_sprite != null:
		_presentation_sprite.visible = false


func _apply_photosafe_impacts() -> void:
	if _impacts == null or not is_instance_valid(_impacts):
		return
	for raw_sprite in _impacts.find_children("*", "AnimatedSprite2D", true, false):
		var sprite := raw_sprite as AnimatedSprite2D
		if sprite == null or not sprite.visible:
			continue
		sprite.stop()
		sprite.frame = clampi(int(get_meta("accessibility_hold_frame", 4)), 0, 8)
		sprite.scale = Vector2.ONE * PHOTOSAFE_IMPACT_SCALE
		sprite.modulate.a = PHOTOSAFE_IMPACT_ALPHA
		sprite.set_meta("photosensitivity_safe", true)


func _timing() -> Dictionary:
	return _manifest.get("timing", {}) as Dictionary


func _reduced_motion() -> bool:
	return bool(_modes.get(Accessibility.REDUCED_MOTION_KEY, false))


func _photosensitivity_safe() -> bool:
	return bool(_modes.get(Accessibility.PHOTOSENSITIVITY_SAFE_KEY, false))


func _uses_held_visuals() -> bool:
	return _reduced_motion() or _photosensitivity_safe()


func _screen_shake_enabled() -> bool:
	return get_tree() == null or bool(get_tree().root.get_meta("screen_shake", true))


func _combat_feedback_enabled() -> bool:
	return get_tree() == null or bool(get_tree().root.get_meta("combat_feedback", true))


func _is_headless() -> bool:
	return _headless_mode == 1 if _headless_mode >= 0 else DisplayServer.get_name() == "headless"


static func _group_instance_ids(tree: SceneTree, group_name: String) -> Dictionary:
	var ids := {}
	if tree == null:
		return ids
	for node in tree.get_nodes_in_group(group_name):
		if node != null and is_instance_valid(node):
			ids[node.get_instance_id()] = true
	return ids


static func _adapt_new_hit_ticks(tree: SceneTree, known: Dictionary, target: Node) -> void:
	if tree == null:
		return
	for raw_tick in tree.get_nodes_in_group(COMBAT_FEEDBACK_FLASH_GROUP):
		var tick := raw_tick as Sprite2D
		if tick == null or known.has(tick.get_instance_id()):
			continue
		var texture_size := tick.texture.get_size() if tick.texture != null else Vector2(128.0, 128.0)
		var longest := maxf(texture_size.x, texture_size.y)
		tick.scale = Vector2.ONE * (PHOTOSAFE_MARKER_REACH / longest if longest > 0.0 else 0.16)
		tick.modulate.a = PHOTOSAFE_MARKER_ALPHA
		tick.set_meta("engineer_photosensitivity_safe_feedback", true)


func _exit_tree() -> void:
	_restore_hitstop()
	_end_camera_shake()
	_end_sfx_ducking()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_restore_hitstop()
		_end_camera_shake()
		_end_sfx_ducking()
