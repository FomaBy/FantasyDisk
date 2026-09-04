extends Node2D

const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")
const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")
const VICTIM_FRAMES := preload("res://assets/sprites/effects/thief/shadow_cloak/shadow_cloak_spriteframes.tres")

const PROFILE_ID := "weapon_ultimate.profile.thief.thief_shadow_cloak"
const EXECUTOR_ID := "weapon_ultimate.executor.thief.thief_shadow_cloak"
const EFFECT_SCENE := "res://scripts/ultimates/classes/thief/thief_shadow_cloak.tscn"
const CONTROL_POLICY := {
	"normal": {"displacement_multiplier": 1.0, "duration_multiplier": 1.0, "allow_movement_lock": false, "allow_execute": true},
	"epic": {"displacement_multiplier": 0.25, "duration_multiplier": 0.5, "allow_movement_lock": false, "allow_execute": true},
	"boss": {"displacement_multiplier": 0.0, "duration_multiplier": 0.25, "allow_movement_lock": false, "allow_execute": false},
}

var ultimate_damage_sink: Callable = Callable()
var strike_count_for_tests := 0
var finish_line_for_tests := false

var _activation = null
var _marks: Array = []
var _strike_claims := {}
var _leases: Array[Dictionary] = []
var _impacts: Node2D = null
var _impacts_started := false


static func parameter_contract() -> Dictionary:
	return {
		"radius": {"type": "number", "minimum": 0.01},
		"strike_count": {"type": "integer", "minimum": 1, "maximum": 8},
		"strike_interval": {"type": "number", "minimum": 0.01},
		"mark_duration": {"type": "number", "minimum": 0.01},
		"stab_damage": {"type": "number", "minimum": 0.0},
		"escalation": {"type": "number", "minimum": 0.0},
	}


static func execute(activation) -> float:
	activation.set_primitive_state({"source": activation.origin()})
	if not Library.execute_primitive("control_resistance_policy", activation, CONTROL_POLICY):
		return 0.0
	if not Library.execute_primitive("priority_target_selector", activation, {
		"center": "source",
		"radius": 999999.0,
		"limit": 0,
		"priority": "highest_hp",
		"hint": {},
	}):
		return 0.0
	var marks = activation.primitive_value("targets", [])
	if not marks is Array or marks.is_empty():
		return 0.0
	var effect = activation.spawn(EFFECT_SCENE)
	if effect == null or not effect.has_method("configure"):
		return 0.0
	effect.call("configure", activation, marks as Array)
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var interval: float = activation.param_float("strike_interval", 0.16)
	for index in activation.param_int("strike_count", 8):
		tween.tween_callback(Callable(effect, "stab").bind(index))
		tween.tween_interval(interval)
	tween.tween_callback(Callable(effect, "finish_line"))
	return float(activation.param_int("strike_count", 8)) * interval


func configure(activation, marks: Array) -> void:
	_activation = activation
	_marks = marks.duplicate()
	global_position = activation.origin()
	for raw_target in _marks:
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var status_id := "thief_ultimate_shadow_%d_%d" % [get_instance_id(), target.get_instance_id()]
		var result: Dictionary = _activation.apply_control(target, Vector2.ZERO, status_id, {
			"duration": _activation.param_float("mark_duration", 2.1),
			"speed_multiplier": 1.0,
			"death_mark": true,
		})
		if bool(result.get("status_applied", false)):
			_leases.append({"target": target, "status_id": status_id})


func stab(index: int) -> void:
	if _activation == null or _activation.is_finished() or _strike_claims.has(index) or _marks.is_empty():
		return
	_strike_claims[index] = true
	var amount: float = _activation.scaled_damage("stab_damage", 0.0) \
		* (1.0 + _activation.param_float("escalation", 0.12) * float(index))
	var struck: Array = []
	for raw_target in _marks:
		var target := raw_target as Node
		if target == null or not is_instance_valid(target):
			continue
		strike_count_for_tests += 1
		_deal(target, amount, "shadow_stab:%d:%d" % [index, target.get_instance_id()], {
			"ultimate_mechanic": "shadow_backstab", "strike_index": index,
		})
		struck.append(target)
	_play_impacts(struck)


func finish_line() -> void:
	if finish_line_for_tests:
		return
	finish_line_for_tests = true
	if _activation != null:
		_activation.present("shadow_finish", {"shape": "beam", "from": global_position, "to": global_position})


func _deal(target: Node, amount: float, event_id: String, feedback: Dictionary):
	if not ultimate_damage_sink.is_valid():
		return null
	return ultimate_damage_sink.call(target, amount, feedback, event_id, false)


## Per-victim read (FAN-3886): every marked enemy pops its own burst on top of
## its white hit flash; later stabs join the ripple the first strike started.
## The ripple must outlive this effect: the activation frees its spawned nodes
## the moment the cast tween completes, which for the final stab is the same
## tick the burst is queued in, so the ripple lives on the current scene and
## releases itself once drained.
func _play_impacts(victims: Array) -> void:
	if victims.is_empty() or _activation == null:
		return
	if _impacts == null or not is_instance_valid(_impacts):
		_impacts = ImpactPlayer.new()
		# The damage path above already drew each victim's ordinary hit flash
		# (enemy.gd:_show_combat_feedback); the burst must not repeat it.
		_impacts.extra_hit_flash = false
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


## One scene-timer release covers the whole stab sequence plus the longest
## possible ripple. The timer's callable holds only the ripple node itself,
## because this effect — an activation-owned spawn — is already freed by then.
func _release_impacts_when_drained() -> void:
	var impacts: Node = _impacts
	var hold: float = float(_activation.param_int("strike_count", 8)) \
			* _activation.param_float("strike_interval", 0.16) + _ripple_bound_seconds()
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
	_marks.clear()
	_strike_claims.clear()
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
