extends Node2D

const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")
const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")
const VICTIM_FRAMES := preload("res://assets/sprites/effects/thief/smoke_bomb/smoke_bomb_spriteframes.tres")

const PROFILE_ID := "weapon_ultimate.profile.thief.thief_smoke_bomb"
const EXECUTOR_ID := "weapon_ultimate.executor.thief.thief_smoke_bomb"
const EFFECT_SCENE := "res://scripts/ultimates/classes/thief/thief_smoke_bomb.tscn"
const CONTROL_POLICY := {
	"normal": {"displacement_multiplier": 1.0, "duration_multiplier": 1.0, "allow_movement_lock": false, "allow_execute": true},
	"epic": {"displacement_multiplier": 0.25, "duration_multiplier": 0.5, "allow_movement_lock": false, "allow_execute": true},
	"boss": {"displacement_multiplier": 0.0, "duration_multiplier": 0.25, "allow_movement_lock": false, "allow_execute": false},
}

var ultimate_damage_sink: Callable = Callable()
var collapse_count_for_tests := 0

var _activation = null
var _outlined: Array = []
var _collapse_claims := {}
var _leases: Array[Dictionary] = []
var _impacts: Node2D = null
var _impacts_started := false


static func parameter_contract() -> Dictionary:
	return {
		"radius": {"type": "number", "minimum": 0.01},
		"duration": {"type": "number", "minimum": 0.01},
		"evasion_bonus": {"type": "number", "minimum": 0.0, "maximum": 0.90},
		"pressure_damage": {"type": "number", "minimum": 0.0},
		"outline_slow": {"type": "number", "minimum": 0.25, "maximum": 1.0},
	}


static func execute(activation) -> float:
	activation.set_primitive_state({"source": activation.origin()})
	if not Library.execute_primitive("control_resistance_policy", activation, CONTROL_POLICY):
		return 0.0
	if not Library.execute_primitive("priority_target_selector", activation, {
		"center": "source",
		"radius": 999999.0,
		"limit": 0,
		"priority": "nearest",
		"hint": {},
	}):
		return 0.0
	var outlined = activation.primitive_value("targets", [])
	var effect = activation.spawn(EFFECT_SCENE)
	if effect == null or not effect.has_method("configure"):
		return 0.0
	effect.call("configure", activation, outlined as Array if outlined is Array else [])
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var duration: float = activation.param_float("duration", 4.0)
	tween.tween_interval(duration)
	tween.tween_callback(Callable(effect, "collapse"))
	return duration


func configure(activation, outlined: Array) -> void:
	_activation = activation
	_outlined = outlined.duplicate()
	global_position = activation.origin()
	_activation.apply_modifier("dodge_flat", _activation.param_float("evasion_bonus", 0.34), "add")
	for raw_target in _outlined:
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var status_id := "thief_ultimate_smoke_%d_%d" % [get_instance_id(), target.get_instance_id()]
		var result: Dictionary = _activation.apply_control(target, Vector2.ZERO, status_id, {
			"duration": _activation.param_float("duration", 4.0),
			"speed_multiplier": _activation.param_float("outline_slow", 0.72),
			"decoy_taunt": true,
			"ranged_lock_blocked": true,
			"smoke_outlined": true,
		})
		if bool(result.get("status_applied", false)):
			_leases.append({"target": target, "status_id": status_id})


func collapse() -> void:
	if _activation == null or _activation.is_finished():
		return
	var crushed: Array = []
	for index in _outlined.size():
		if _collapse_claims.has(index):
			continue
		_collapse_claims[index] = true
		var target := _outlined[index] as Node
		if target == null or not is_instance_valid(target):
			continue
		collapse_count_for_tests += 1
		_deal(target, _activation.scaled_damage("pressure_damage", 0.0), "smoke_collapse:%d" % index, {
			"ultimate_mechanic": "stolen_pressure", "outline_index": index,
		})
		crushed.append(target)
	_play_impacts(crushed)


func _deal(target: Node, amount: float, event_id: String, feedback: Dictionary):
	if not ultimate_damage_sink.is_valid():
		return null
	return ultimate_damage_sink.call(target, amount, feedback, event_id, false)


## Per-victim read (FAN-3886): the closing pressure pops one burst per outlined
## enemy on top of its white hit flash, rippling outward from the thrown bomb.
## The ripple must outlive this effect: collapse is the cast tween's last step,
## so the activation frees this dome the same tick the bursts are queued in;
## the ripple therefore lives on the current scene and releases itself once
## drained.
func _play_impacts(victims: Array) -> void:
	if victims.is_empty() or _activation == null:
		return
	if _impacts == null or not is_instance_valid(_impacts):
		_impacts = ImpactPlayer.new()
		var parent := get_tree().current_scene
		if parent == null:
			parent = get_tree().root
		parent.add_child(_impacts)
		_impacts_started = false
	if _impacts_started:
		_impacts.enqueue(victims, _activation.origin())
	else:
		_impacts.play(VICTIM_FRAMES, victims, _activation.origin())
		_impacts_started = true
		_release_impacts_when_drained()


## One scene-timer release covers the dome's whole duration plus the longest
## possible ripple. The timer's callable holds only the ripple node itself,
## because this effect — an activation-owned spawn — is freed the same tick
## collapse queues the bursts.
func _release_impacts_when_drained() -> void:
	var impacts: Node = _impacts
	var hold: float = _activation.param_float("duration", 4.0) + _ripple_bound_seconds()
	var release := func() -> void:
		if is_instance_valid(impacts):
			impacts.call("finish")
			impacts.queue_free()
	get_tree().create_timer(hold).timeout.connect(release)


## The longest ripple the shared service can plan: every wave at the widest
## stagger, then one full burst.
static func _ripple_bound_seconds() -> float:
	return float(ImpactPlayer.MAX_WAVES) * float(ImpactPlayer.STAGGER_MAX_FRAMES) \
			* float(ImpactPlayer.FRAME_SECONDS) + ImpactPlayer.BURST_SECONDS + 0.2


func _exit_tree() -> void:
	for lease in _leases:
		_remove_lease(lease)
	_leases.clear()
	_outlined.clear()
	_collapse_claims.clear()
	_activation = null


func _remove_lease(lease: Dictionary) -> void:
	var target := lease.get("target") as Node
	if target == null or not is_instance_valid(target) or not target.has_meta(StatusEffects.META_KEY):
		return
	var statuses = target.get_meta(StatusEffects.META_KEY)
	if not statuses is Dictionary:
		return
	var owned := (statuses as Dictionary).duplicate(true)
	owned.erase(str(lease.get("status_id", "")))
	if owned.is_empty():
		target.remove_meta(StatusEffects.META_KEY)
	else:
		target.set_meta(StatusEffects.META_KEY, owned)
