extends Node2D

const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")
const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")
const VICTIM_FRAMES := preload("res://assets/sprites/effects/thief/coin_pouch/coin_pouch_spriteframes.tres")

const PROFILE_ID := "weapon_ultimate.profile.thief.thief_coin_pouch"
const EXECUTOR_ID := "weapon_ultimate.executor.thief.thief_coin_pouch"
const EFFECT_SCENE := "res://scripts/ultimates/classes/thief/thief_coin_pouch.tscn"

var ultimate_damage_sink: Callable = Callable()
var gold_awarded_for_tests := 0
var return_burst_for_tests := false

var _activation = null
var _targets: Array = []
var _hit_claims := {}
var _impacts: Node2D = null
var _impacts_started := false
var _impact_marker_pool: Array = []


static func parameter_contract() -> Dictionary:
	return {
		"radius": {"type": "number", "minimum": 0.01},
		"coin_wave_count": {"type": "integer", "minimum": 1, "maximum": 13},
		"hop_delay": {"type": "number", "minimum": 0.01},
		"coin_damage": {"type": "number", "minimum": 0.0},
		"damage_falloff": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"gold_every": {"type": "integer", "minimum": 1},
		"gold_amount": {"type": "integer", "minimum": 1},
		"gold_cap": {"type": "integer", "minimum": 0},
	}


static func execute(activation) -> float:
	activation.set_primitive_state({"source": activation.origin()})
	if not Library.execute_primitive("priority_target_selector", activation, {
		"center": "source",
		"radius": 999999.0,
		"limit": activation.param_int("coin_wave_count", 13),
		"priority": "nearest",
		"hint": {},
	}):
		return 0.0
	var targets = activation.primitive_value("targets", [])
	if not targets is Array or targets.is_empty():
		return 0.0
	var effect = activation.spawn(EFFECT_SCENE)
	if effect == null or not effect.has_method("configure"):
		return 0.0
	effect.call("configure", activation, targets as Array)
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var delay: float = activation.param_float("hop_delay", 0.10)
	for index in (targets as Array).size():
		tween.tween_callback(Callable(effect, "hit").bind(index))
		tween.tween_interval(delay)
	tween.tween_callback(Callable(effect, "return_home"))
	return float((targets as Array).size()) * delay


func configure(activation, targets: Array) -> void:
	_activation = activation
	_targets = targets.duplicate()
	global_position = activation.origin()


func hit(index: int) -> void:
	if _activation == null or _activation.is_finished() or _hit_claims.has(index) or index >= _targets.size():
		return
	_hit_claims[index] = true
	if not is_instance_valid(_targets[index]):
		return
	var target := _targets[index] as Node
	var amount: float = _activation.scaled_damage("coin_damage", 0.0) \
		* pow(_activation.param_float("damage_falloff", 0.90), float(index))
	_deal(target, amount, "jackpot_coin:%d" % index, {
		"ultimate_mechanic": "jackpot_ricochet", "coin_index": index,
	})
	if (index + 1) % _activation.param_int("gold_every", 3) == 0:
		_award_gold()
	_play_impacts([target])


func return_home() -> void:
	if return_burst_for_tests:
		return
	return_burst_for_tests = true
	if _activation != null:
		_activation.present("jackpot_return", {"shape": "orb_burst", "position": global_position, "radius": 120.0})


func _award_gold() -> void:
	var cap: int = _activation.param_int("gold_cap", 4)
	var amount: int = _activation.param_int("gold_amount", 1)
	if gold_awarded_for_tests >= cap or amount <= 0:
		return
	amount = mini(amount, cap - gold_awarded_for_tests)
	var recipient = _activation.host
	if recipient != null and not recipient.has_method("gain_money"):
		recipient = recipient.get("player")
	if recipient != null and recipient.has_method("gain_money"):
		recipient.call("gain_money", amount)
		gold_awarded_for_tests += amount


func _deal(target: Node, amount: float, event_id: String, feedback: Dictionary):
	if not ultimate_damage_sink.is_valid():
		return null
	return ultimate_damage_sink.call(target, amount, feedback, event_id, false)


## Per-victim read (FAN-3886): each ricochet hop pops its own burst on top of
## the victim's white hit flash; later hops join the ripple the first started.
## The ripple must outlive this effect: the activation frees its spawned nodes
## the moment the cast tween completes, which for the final hop is the same
## tick the burst is queued in, so the ripple lives on the current scene and
## releases itself once drained.
func _play_impacts(victims: Array) -> void:
	if victims.is_empty() or _activation == null:
		return
	# Markers first: an empty beat must not create a player it would then keep.
	var markers := _impact_markers(victims)
	if markers.is_empty():
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
		_impacts.enqueue(markers, _activation.origin())
	else:
		_impacts.play(VICTIM_FRAMES, markers, _activation.origin())
		_impacts_started = true
		_release_impacts_when_drained()


## One scene-timer release covers the whole ricochet chain plus the longest
## possible ripple. The timer's callable holds only the ripple node itself,
## because this effect — an activation-owned spawn — is already freed by then.
func _release_impacts_when_drained() -> void:
	var impacts: Node = _impacts
	var hold: float = float(_targets.size()) * _activation.param_float("hop_delay", 0.10) \
			+ _ripple_bound_seconds()
	# The shared container (not a copy) is captured: beats scheduled after the
	# timer was armed still add their markers, and all of them are freed here.
	var markers := _impact_marker_pool
	var release := func() -> void:
		if is_instance_valid(impacts):
			impacts.call("finish")
			impacts.queue_free()
		for marker in markers:
			if is_instance_valid(marker):
				(marker as Node2D).queue_free()
	get_tree().create_timer(hold).timeout.connect(release)


## The longest ripple the shared service can plan: every wave at the widest
## stagger, then one full burst.
static func _ripple_bound_seconds() -> float:
	return float(ImpactPlayer.MAX_WAVES) * float(ImpactPlayer.STAGGER_MAX_FRAMES) \
			* float(ImpactPlayer.FRAME_SECONDS) + ImpactPlayer.BURST_SECONDS + 0.2


func _exit_tree() -> void:
	_targets.clear()
	_hit_claims.clear()
	_activation = null

## The ripple reads each victim only on its next `_process`, but a lethal hit
## frees the enemy at the end of this very frame (enemy.gd's death fallback),
## so a killed target never survives to its own burst. The ordinary flash is
## already drawn by the damage path and this ripple runs with it off, so a
## burst needs exactly the victim's position: every beat rides stable position
## markers, released together with the ripple.
func _impact_markers(victims: Array) -> Array:
	var markers: Array = []
	for raw_victim in victims:
		var victim := raw_victim as Node2D
		if victim == null or not is_instance_valid(victim):
			continue
		var marker := Node2D.new()
		marker.global_position = victim.global_position
		_impact_marker_pool.append(marker)
		markers.append(marker)
	return markers
