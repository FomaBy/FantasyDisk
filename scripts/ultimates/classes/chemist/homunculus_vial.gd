extends RefCounted

## Chemist / Склянка гомункула — «Совершенный Гомункул».
##
## The persistent tank/caster pair fuses into one temporary avatar: the shared
## summon-interaction contract snapshots and parks the player-owned pair, the
## activation spawns exactly one avatar in their place, and the avatar taunts,
## stomps and cascades toxic waves until the cast ends.
##
## The split back is the activation's own teardown, not a second construction
## step: `shutdown()` frees the avatar and restores the parked pair from the
## snapshot it took. Nothing is instantiated to replace them, so the pair cannot
## be duplicated and cannot be lost — a cancel, a death or an encounter end
## reaches the same restore path as a completed cast.
##
## `temporary_cap` is 1 on purpose: the activation refuses any spawn beyond it,
## so a retriggered execute can never stack a second avatar.
##
## Declaration params: summon_group, avatar_scene, fuse_at, taunt_radius,
## taunt_force, beat_count, beat_interval, stomp_radius, damage, wave_radius,
## wave_dot_damage, wave_dot_interval, wave_stack_cap, target_limit, recover_at,
## control_policy, taunt_status.

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")

const PROFILE_ID := "weapon_ultimate.profile.chemist.homunculus_vial"
const EXECUTOR_ID := "weapon_ultimate.executor.chemist.homunculus_vial"

## SCRUM-946 owns this status: the avatar's cascade feeds the same permanent
## charge the persistent caster does, so the two cannot exceed one ceiling.
const CASTER_WAVE_STATUS_ID := "homunculus_caster_dot"
const CASTER_WAVE_PERSIST_SECONDS := 999999.0
const TAUNT_STATUS_ID := "chemist_homunculus_taunt"
const AVATAR_CAP := 1


static func parameter_contract() -> Dictionary:
	return {
		"summon_group": {"type": "string"},
		"avatar_scene": {"type": "string"},
		"fuse_at": {"type": "number", "minimum": 0.0},
		"taunt_radius": {"type": "number", "minimum": 0.0},
		"taunt_force": {"type": "number", "minimum": 0.0},
		"beat_count": {"type": "integer", "minimum": 1},
		"beat_interval": {"type": "number", "minimum": 0.05},
		"stomp_radius": {"type": "number", "minimum": 0.0},
		"damage": {"type": "number", "minimum": 0.0},
		"wave_radius": {"type": "number", "minimum": 0.0},
		"wave_dot_damage": {"type": "number", "minimum": 0.0},
		"wave_dot_interval": {"type": "number", "minimum": 0.05},
		"wave_stack_cap": {"type": "integer", "minimum": 1},
		"target_limit": {"type": "integer", "minimum": 0},
		"recover_at": {"type": "number", "minimum": 0.0},
		"control_policy": {"type": "dictionary"},
		"taunt_status": {"type": "dictionary"},
	}


## Park the player-owned pair and place the avatar. Reported separately so the
## mechanics test can assert the shipped declaration is admitted before a live
## cast depends on it.
static func fuse(activation: Activation) -> Node:
	var configured := Library.execute_primitive(
		"summon_interaction_contract",
		activation,
		{
			"group_id": activation.param_string("summon_group"),
			"temporary_cap": AVATAR_CAP,
			"snapshot_properties": [],
			"setup": {},
		}
	)
	configured = Library.execute_primitive(
		"control_resistance_policy", activation, activation.param_dictionary("control_policy")
	) and configured
	if not configured:
		return null
	var avatar := activation.spawn(activation.param_string("avatar_scene"))
	if avatar is Node2D:
		(avatar as Node2D).global_position = activation.origin()
	return avatar


static func execute(activation: Activation) -> float:
	var avatar := fuse(activation)
	activation.present(EXECUTOR_ID, {
		"shape": "ring_pulse",
		"position": activation.origin(),
		"radius": activation.param_float("taunt_radius", 0.0),
		"duration": activation.param_float("recover_at", 0.0),
	})
	var tween := activation.track_tween()
	if tween == null:
		return 0.0
	var fuse_at := activation.param_float("fuse_at", 0.0)
	var beats := maxi(activation.param_int("beat_count", 1), 1)
	var interval := maxf(activation.param_float("beat_interval", 0.05), 0.05)
	tween.tween_interval(fuse_at)
	tween.tween_callback(func() -> void: _taunt(activation, avatar))
	for _beat_index in beats:
		tween.tween_interval(interval)
		tween.tween_callback(func() -> void: _beat(activation, avatar))
	var acted := fuse_at + interval * float(beats)
	tween.tween_interval(maxf(activation.param_float("recover_at", 0.0) - acted, 0.0))
	return maxf(activation.param_float("recover_at", 0.0), acted)


## The avatar holds the field while it exists; once it is gone the remaining
## beats fall back to the caster so a freed VFX node cannot silently stop the
## cast half-way.
static func _centre(activation: Activation, avatar: Node) -> Vector2:
	if avatar is Node2D and is_instance_valid(avatar):
		return (avatar as Node2D).global_position
	return activation.origin()


## Taunt halo: drag the crowd onto the avatar and slow it there. The pull runs
## through `apply_control`, so the declared tier policy shrinks it for elites
## and bosses instead of yanking them like trash mobs.
static func _taunt(activation: Activation, avatar: Node) -> void:
	var centre := _centre(activation, avatar)
	var force := activation.param_float("taunt_force", 0.0)
	var status := activation.param_dictionary("taunt_status")
	for raw_target in activation.targets(
		centre, activation.param_float("taunt_radius", 0.0), activation.param_int("target_limit", 0)
	):
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var inward := centre - target.global_position
		var impulse := inward.normalized() * force \
			if force > 0.0 and inward.length_squared() > 0.001 else Vector2.ZERO
		activation.apply_control(target, impulse, TAUNT_STATUS_ID, status)


## One avatar beat: a broad stomp that spends the activation budget, then the
## narrower toxic cascade that leaves the permanent charge behind.
static func _beat(activation: Activation, avatar: Node) -> void:
	var centre := _centre(activation, avatar)
	var stomp_damage := activation.scaled_damage()
	var target_limit := activation.param_int("target_limit", 0)
	activation.present(EXECUTOR_ID, {
		"shape": "orb_burst",
		"position": centre,
		"radius": activation.param_float("stomp_radius", 0.0),
	})
	for raw_target in activation.targets(
		centre, activation.param_float("stomp_radius", 0.0), target_limit
	):
		var target := raw_target as Node
		if target != null and is_instance_valid(target):
			activation.deal_damage(target, stomp_damage)
	for raw_target in activation.targets(
		centre, activation.param_float("wave_radius", 0.0), target_limit
	):
		var target := raw_target as Node
		if target == null or not is_instance_valid(target):
			continue
		StatusEffects.apply_status(target, CASTER_WAVE_STATUS_ID, {
			"duration": CASTER_WAVE_PERSIST_SECONDS,
			"dot_damage": activation.param_float("wave_dot_damage", 0.0),
			"dot_interval": activation.param_float("wave_dot_interval", 0.05),
			"stack_mode": "add",
			"max_stacks": maxi(activation.param_int("wave_stack_cap", 1), 1),
		})
