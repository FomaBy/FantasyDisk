extends Node2D

const StatusEffects := preload("res://scripts/status_effects.gd")

const PROFILE_ID := "weapon_ultimate.profile.dark_mage.cursed_skull"
const EXECUTOR_ID := "weapon_ultimate.executor.dark_mage.cursed_skull"
const EFFECT_SCENE := "res://scripts/ultimates/classes/dark_mage/cursed_skull.tscn"

const CROWN_MARKER := Color(0.72, 0.28, 0.95, 0.85)

var ultimate_damage_sink: Callable = Callable()
var transfer_count_for_tests := 0
var harvest_count_for_tests := 0

var _activation = null
var _marked: Array = []
var _marked_ids := {}
var _transferred_from := {}
var _leased_statuses: Array[Dictionary] = []
var _settled := false


static func parameter_contract() -> Dictionary:
	return {
		"screen_radius": {"type": "number", "minimum": 0.0},
		"crowd_cap": {"type": "integer", "minimum": 1},
		"release_delay": {"type": "number", "minimum": 0.0},
		"active_delay": {"type": "number", "minimum": 0.0},
		"curse_duration": {"type": "number", "minimum": 0.1},
		"outgoing_damage_multiplier": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"pulse_count": {"type": "integer", "minimum": 1},
		"pulse_interval": {"type": "number", "minimum": 0.01},
		"curse_damage": {"type": "number", "minimum": 0.0},
		"transfer_radius": {"type": "number", "minimum": 0.0},
		"transfer_cap": {"type": "integer", "minimum": 0},
		"harvest_delay": {"type": "number", "minimum": 0.0},
		"harvest_damage": {"type": "number", "minimum": 0.0},
		"lifetime": {"type": "number", "minimum": 0.1},
	}


static func execute(activation) -> float:
	if not activation.set_control_resistance_policy(_control_policy()):
		return 0.0
	# Dead silhouettes may still be inside the screen radius; they must not
	# spend the 14-mark cap, so the cap is applied after the alive filter.
	var targets: Array = []
	for raw_target in activation.select_targets(
		activation.origin(),
		activation.param_float("screen_radius", 900.0),
		0,
		"nearest"
	):
		var candidate := raw_target as Node2D
		if candidate == null or not is_instance_valid(candidate) \
				or (candidate.get("health") != null and float(candidate.get("health")) <= 0.0):
			continue
		targets.append(candidate)
		if targets.size() >= activation.param_int("crowd_cap", 14):
			break
	var effect = activation.spawn(EFFECT_SCENE)
	if effect == null or not effect.has_method("configure"):
		return 0.0
	effect.call("configure", activation, targets)
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	# One lifecycle tween carries every beat; the cursor keeps the frozen
	# chronology exact: execute at release (0.85), the settled-crown `active`
	# beat at active_delay (1.35) between the pulse cadence points, harvest at
	# 5.55, natural end at 6.35.
	var release_delay: float = activation.param_float("release_delay", 0.85)
	var cursor := release_delay
	tween.tween_interval(release_delay)
	tween.tween_callback(Callable(effect, "crown_targets"))
	tween.tween_callback(Callable(effect, "curse_pulse").bind(0))
	var active_delay: float = maxf(activation.param_float("active_delay", 1.35), cursor)
	tween.tween_interval(active_delay - cursor)
	tween.tween_callback(Callable(effect, "settle"))
	cursor = active_delay
	var pulses: int = activation.param_int("pulse_count", 4)
	var pulse_interval: float = activation.param_float("pulse_interval", 0.85)
	for pulse in range(1, pulses):
		var pulse_at := maxf(release_delay + pulse_interval * float(pulse), cursor)
		tween.tween_interval(pulse_at - cursor)
		tween.tween_callback(Callable(effect, "curse_pulse").bind(pulse))
		cursor = pulse_at
	var harvest_delay: float = maxf(activation.param_float("harvest_delay", 5.55), cursor)
	tween.tween_interval(harvest_delay - cursor)
	tween.tween_callback(Callable(effect, "harvest"))
	var lifetime: float = activation.param_float("lifetime", 6.35)
	if lifetime > harvest_delay:
		tween.tween_interval(lifetime - harvest_delay)
	return lifetime


static func _control_policy() -> Dictionary:
	# Doc contract: no tier receives a movement lock or an execute.
	return {
		"normal": {
			"displacement_multiplier": 0.0,
			"duration_multiplier": 1.0,
			"allow_movement_lock": false,
			"allow_execute": false,
		},
		"epic": {
			"displacement_multiplier": 0.0,
			"duration_multiplier": 0.5,
			"allow_movement_lock": false,
			"allow_execute": false,
		},
		"boss": {
			"displacement_multiplier": 0.0,
			"duration_multiplier": 0.25,
			"allow_movement_lock": false,
			"allow_execute": false,
		},
	}


func configure(activation, targets: Array) -> void:
	_activation = activation
	_marked = targets.duplicate()
	global_position = activation.origin()


func crown_targets() -> void:
	if _activation == null or _activation.is_finished():
		return
	var pending := _marked.duplicate()
	_marked.clear()
	for raw_target in pending:
		_mark(raw_target as Node2D)
	_activation.present("weapon_ultimate.phase.dark_mage.cursed_skull.execute", {
		"position": global_position,
		"radius": _activation.param_float("screen_radius", 900.0) * 0.26,
		"shape": "ring_pulse",
	})


## Frozen `active` beat: the settled crown aura, once per cast.
func settle() -> void:
	if _activation == null or _activation.is_finished() or _settled:
		return
	_settled = true
	_activation.present("weapon_ultimate.phase.dark_mage.cursed_skull.active", {
		"position": global_position,
		"radius": _activation.param_float("screen_radius", 900.0) * 0.3,
		"shape": "ring_pulse",
	})


func curse_pulse(pulse: int) -> void:
	if _activation == null or _activation.is_finished():
		return
	for raw_target in _marked.duplicate():
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target):
			continue
		if not _alive(target):
			_transfer_curse(target, pulse)
			continue
		var result = _deal(
			target,
			_activation.scaled_damage("curse_damage", 0.0),
			"crown_curse:%d" % pulse,
			false,
			{"ultimate_mechanic": "crown_curse", "pulse": pulse}
		)
		if result != null and bool(result.killed):
			_transfer_curse(target, pulse)


func harvest() -> void:
	if _activation == null or _activation.is_finished():
		return
	harvest_count_for_tests += 1
	for raw_target in _marked:
		var target := raw_target as Node
		if target == null or not is_instance_valid(target) or not _alive(target as Node2D):
			continue
		_deal(
			target,
			_activation.scaled_damage("harvest_damage", 0.0),
			"crown_harvest",
			false,
			{"ultimate_mechanic": "crown_harvest"}
		)
	_activation.present("weapon_ultimate.phase.dark_mage.cursed_skull.recover", {
		"position": global_position,
		"radius": _activation.param_float("screen_radius", 900.0) * 0.22,
		"shape": "orb_burst",
	})


func _mark(target: Node2D) -> void:
	if target == null or not is_instance_valid(target) or _marked_ids.has(target.get_instance_id()):
		return
	# The marker slot is last-writer-wins shared metadata: remember what was
	# there before this lease so removal can hand the exact prior value back.
	var lease := {
		"target": target,
		"had_marker": target.has_meta(StatusEffects.MARKER_META_KEY),
		"prior_marker": target.get_meta(StatusEffects.MARKER_META_KEY) \
			if target.has_meta(StatusEffects.MARKER_META_KEY) else null,
	}
	var status_id := "dark_mage_ultimate_crown_%d_%d" % [get_instance_id(), target.get_instance_id()]
	var result: Dictionary = _activation.apply_control(target, Vector2.ZERO, status_id, {
		"duration": _activation.param_float("curse_duration", 5.5),
		"damage_multiplier": _activation.param_float("outgoing_damage_multiplier", 0.65),
		"crown_curse": true,
		"marker_color": CROWN_MARKER,
	})
	if not bool(result.get("status_applied", false)):
		return
	_marked_ids[target.get_instance_id()] = true
	_marked.append(target)
	lease["status_id"] = status_id
	_leased_statuses.append(lease)


func _transfer_curse(source: Node2D, pulse: int) -> void:
	if source == null or not is_instance_valid(source) or transfer_count_for_tests \
		>= _activation.param_int("transfer_cap", 8) or _transferred_from.has(source.get_instance_id()):
		return
	_transferred_from[source.get_instance_id()] = true
	for raw_target in _activation.select_targets(
		source.global_position,
		_activation.param_float("transfer_radius", 260.0),
		0,
		"nearest"
	):
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target) or not _alive(target) \
			or _marked_ids.has(target.get_instance_id()):
			continue
		_mark(target)
		transfer_count_for_tests += 1
		# Conditional runtime beat: executor-local id, not a frozen phase id —
		# the frozen `active` chronology belongs to the scheduled settle() beat.
		_activation.present(EXECUTOR_ID + ".transfer", {
			"position": target.global_position,
			"radius": _activation.param_float("transfer_radius", 260.0) * 0.3,
			"shape": "ring_pulse",
		})
		return


func _alive(target: Node2D) -> bool:
	return target != null and is_instance_valid(target) \
		and (target.get("health") == null or float(target.get("health")) > 0.0)


func _deal(target: Node, amount: float, event_id: String, secondary: bool, feedback: Dictionary):
	if not ultimate_damage_sink.is_valid():
		return null
	return ultimate_damage_sink.call(target, amount, feedback, event_id, secondary)


func _exit_tree() -> void:
	for lease in _leased_statuses:
		_remove_leased_status(lease)
	_leased_statuses.clear()
	_marked.clear()
	_marked_ids.clear()
	_transferred_from.clear()
	_activation = null


func _remove_leased_status(lease: Dictionary) -> void:
	var target := lease.get("target") as Node
	if target == null or not is_instance_valid(target):
		return
	if target.has_meta(StatusEffects.META_KEY):
		var statuses = target.get_meta(StatusEffects.META_KEY)
		if statuses is Dictionary:
			var owned := (statuses as Dictionary).duplicate(true)
			owned.erase(str(lease.get("status_id", "")))
			if owned.is_empty():
				target.remove_meta(StatusEffects.META_KEY)
			else:
				target.set_meta(StatusEffects.META_KEY, owned)
	_reconcile_marker(target, lease)


## The lease owns the marker slot only while the crown color is still the one
## on the target. Ours -> restore the exact prior value (or clear when there
## was none). A different color means a later foreign effect took the slot and
## must be preserved. Runs even after natural status expiry, because tick()
## drops the status entry without releasing the shared marker slot.
func _reconcile_marker(target: Node, lease: Dictionary) -> void:
	if not target.has_meta(StatusEffects.MARKER_META_KEY):
		return
	var current = target.get_meta(StatusEffects.MARKER_META_KEY)
	if not (current is Color and (current as Color) == CROWN_MARKER):
		return
	if bool(lease.get("had_marker", false)):
		target.set_meta(StatusEffects.MARKER_META_KEY, lease.get("prior_marker"))
	else:
		target.remove_meta(StatusEffects.MARKER_META_KEY)
