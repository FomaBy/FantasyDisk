class_name UltimateVictimImpactPlayer
extends Node2D

## Shared per-victim impact reader for weapon ultimates (FAN-3008).
##
## The activation scene owns the caster-side spectacle; this service owns the
## victim-side read: a short flipbook burst on every hit enemy, played on top of
## the enemy's existing white hit flash. The flash is never replaced and never
## duplicated — the victim's own `show_ultimate_impact_flash()` is called.
##
## Usage from an ultimate scene:
##
##     var impacts := UltimateVictimImpactPlayer.new()
##     add_child(impacts)
##     impacts.play(impact_frames, hit_enemies, cast_position)
##
## The node ticks itself in `_process`; a headless fixture drives `advance()`
## directly instead. `finish()` releases every burst and frees the pool.
##
## Impact sprites are victim-side feedback in the same contour as the enemy hit
## flash, not part of the activation's declared `max_visual_nodes` budget. Their
## own ceiling is `pool_cap`: the pool is the budget, so a map-wide ultimate
## creates at most `pool_cap` nodes no matter how many enemies it hits.

## The burst window the direction mandates. The pack's own length is compressed
## into `BURST_SECONDS`, so the degraded window shows proportionally fewer frames.
const BURST_SECONDS := 0.45
const DEGRADED_BURST_SECONDS := 0.30
const DEGRADED_SCALE := 0.6

## Ripple stagger between distance waves, in 60 fps frames.
const STAGGER_MIN_FRAMES := 3
const STAGGER_MAX_FRAMES := 8

## Frames the whole ripple aims to span, and the number of distance waves it is
## split into. Both bound the ripple: more victims share a wave, they never
## stretch the ultimate.
const RIPPLE_BUDGET_FRAMES := 40
const MAX_WAVES := 8
const FRAME_SECONDS := 1.0 / 60.0

## Measured ceiling: the reduced variant peaks at 24 concurrent bursts on the
## largest scenario crowd (`max_active_cap` = 48 in main.gd WAVE_SETTINGS), and
## 24 stays inside the 32-node crowd ceiling one activation may already draw
## (UltimateVisualDirectionContract.CROWD_CAP_CEILING).
const POOL_CAP := 24

## Measured switchover: 38 is the largest crowd whose full-size bursts still
## peak inside POOL_CAP (39 victims peak at 25). Above it the reduced variant
## runs, so the pool never has to cut a live burst short at any crowd size.
## `weapon_ultimate_presentation_budget_test.gd` reprints the whole sweep.
const DEGRADE_VICTIM_THRESHOLD := 38

## The victim's existing flash, called by name rather than through a new public
## wrapper: `scripts/enemy.gd` sits exactly on its shrink-only line ratchet
## (tools/quality_static_guard.py), so the wrapper waits for the card that
## splits that monolith. The guard method keeps the global combat-feedback
## toggle honoured; a victim that answers neither simply gets no flash.
const FLASH_METHOD := "_show_hit_flash"
const FLASH_GUARD_METHOD := "_combat_feedback_enabled"

## Both knobs exist for the measurement that derives the two constants above;
## a scene uses the defaults.
var pool_cap := POOL_CAP
var degrade_threshold := DEGRADE_VICTIM_THRESHOLD

var _frames: SpriteFrames = null
var _pool: Array[AnimatedSprite2D] = []
var _active: Array[Dictionary] = []
var _pending: Array[Dictionary] = []
var _created := 0
var _recycled := 0
var _flashes := 0
var _peak_active := 0
var _degraded := false
var _stagger := 0
var _victims := 0


func _process(delta: float) -> void:
	advance(delta)


## Schedule one impact per victim, as a wave running outward from the cast
## point. Returns the same Dictionary as `snapshot()`, so a caller can log the
## plan (wave stagger, degradation) without reading this file.
func play(frames: SpriteFrames, victims: Array, cast_position: Vector2) -> Dictionary:
	_frames = frames
	_pending.clear()
	_peak_active = maxi(_peak_active, _active.size())
	var targets := _ordered_victims(victims, cast_position)
	_victims = targets.size()
	_degraded = _victims > degrade_threshold
	_stagger = stagger_frames(_victims)
	var waves := wave_count(_victims)
	for index in _victims:
		var wave := index * waves / _victims
		_pending.append({
			"victim": targets[index],
			"delay": float(wave * _stagger) * FRAME_SECONDS,
		})
	return snapshot()


## Drive the ripple. Pending entries are ordered by delay, so the ready ones are
## always a prefix.
func advance(delta: float) -> void:
	var step := maxf(delta, 0.0)
	var ready := 0
	for entry in _pending:
		entry["delay"] = float(entry["delay"]) - step
		if float(entry["delay"]) <= 0.0:
			ready += 1
	for index in ready:
		_spawn((_pending[index] as Dictionary)["victim"])
	if ready > 0:
		_pending = _pending.slice(ready)

	var running: Array[Dictionary] = []
	for burst in _active:
		burst["remaining"] = float(burst["remaining"]) - step
		if float(burst["remaining"]) > 0.0:
			running.append(burst)
		else:
			_release(burst["sprite"])
	_active = running


## Release every burst and free the pool. Safe to call twice.
func finish() -> void:
	for burst in _active:
		_release(burst["sprite"])
	_active.clear()
	_pending.clear()
	for sprite in _pool:
		if is_instance_valid(sprite):
			sprite.queue_free()
	_pool.clear()


## Counters are per player instance, not per call: `created_nodes` is what this
## service has ever allocated, so the pool cap bounds it for the instance's
## whole life.
func snapshot() -> Dictionary:
	return {
		"victims": _victims,
		"pending": _pending.size(),
		"active": _active.size(),
		"pooled": _pool.size(),
		"created_nodes": _created,
		"recycled": _recycled,
		"flashes": _flashes,
		"peak_active": _peak_active,
		"degraded": _degraded,
		"stagger_frames": _stagger,
		"burst_seconds": burst_seconds(),
	}


func burst_seconds() -> float:
	return DEGRADED_BURST_SECONDS if _degraded else BURST_SECONDS


## Distance waves for a victim count: one wave per victim until the ripple is
## split into `MAX_WAVES` bands, after which victims share a band.
static func wave_count(victim_count: int) -> int:
	return clampi(victim_count, 1, MAX_WAVES)


## The gap between two waves, always inside the mandated 3–8 frame window: a
## tight group pops with the widest readable gap, a full band ladder with the
## narrowest one that still reads as a wave.
static func stagger_frames(victim_count: int) -> int:
	var waves := wave_count(victim_count)
	if waves <= 1:
		return STAGGER_MIN_FRAMES
	return clampi(
		roundi(float(RIPPLE_BUDGET_FRAMES) / float(waves - 1)),
		STAGGER_MIN_FRAMES,
		STAGGER_MAX_FRAMES
	)


## Victims nearest the cast point first: the wave reads as leaving the hero.
func _ordered_victims(victims: Array, cast_position: Vector2) -> Array[Node2D]:
	var targets: Array[Node2D] = []
	for victim in victims:
		if victim is Node2D and is_instance_valid(victim):
			targets.append(victim as Node2D)
	targets.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(cast_position) \
			< b.global_position.distance_squared_to(cast_position))
	return targets


## The white flash is the floor of the read: it fires for every victim before
## the burst is even acquired, so pool pressure and degradation can never take
## it away.
func _spawn(victim: Variant) -> void:
	if not (victim is Node2D) or not is_instance_valid(victim):
		return
	var target := victim as Node2D
	if _flash(target):
		_flashes += 1
	var sprite := _acquire()
	if sprite == null:
		return
	sprite.global_position = target.global_position
	sprite.scale = Vector2.ONE * (DEGRADED_SCALE if _degraded else 1.0)
	sprite.visible = true
	sprite.frame = 0
	if _frames != null:
		sprite.sprite_frames = _frames
		var animation := _animation_name()
		sprite.speed_scale = _speed_scale(animation)
		sprite.play(animation)
	_active.append({"sprite": sprite, "remaining": burst_seconds()})
	_peak_active = maxi(_peak_active, _active.size())


## The victim's own white flash, never a second one drawn here.
func _flash(victim: Node2D) -> bool:
	if not victim.has_method(FLASH_METHOD):
		return false
	if victim.has_method(FLASH_GUARD_METHOD) and not bool(victim.call(FLASH_GUARD_METHOD)):
		return false
	victim.call(FLASH_METHOD)
	return true


## Pool first, a new node only while the cap allows one, and otherwise the
## oldest live burst — the one closest to ending anyway. Node creation therefore
## stops at `pool_cap` however large the crowd is.
func _acquire() -> AnimatedSprite2D:
	if not _pool.is_empty():
		return _pool.pop_back()
	if _created < pool_cap:
		var sprite := AnimatedSprite2D.new()
		sprite.name = "VictimImpact%d" % _created
		sprite.top_level = true
		sprite.z_index = 3000
		sprite.visible = false
		add_child(sprite)
		_created += 1
		return sprite
	if _active.is_empty():
		return null
	var oldest := _active.pop_front() as Dictionary
	_recycled += 1
	var reused := oldest["sprite"] as AnimatedSprite2D
	if not is_instance_valid(reused):
		return null
	reused.stop()
	return reused


func _release(sprite: Variant) -> void:
	if not (sprite is AnimatedSprite2D) or not is_instance_valid(sprite):
		return
	var released := sprite as AnimatedSprite2D
	released.stop()
	released.visible = false
	_pool.append(released)


func _animation_name() -> String:
	var names := _frames.get_animation_names()
	return str(names[0]) if names.size() > 0 else "default"


## Compress the pack's own length into the full burst window. The degraded
## variant keeps this rate and closes earlier, so it literally shows fewer
## frames at a smaller scale.
func _speed_scale(animation: String) -> float:
	var fps := _frames.get_animation_speed(animation)
	var count := _frames.get_frame_count(animation)
	if fps <= 0.0 or count <= 0:
		return 1.0
	return (float(count) / fps) / BURST_SECONDS
