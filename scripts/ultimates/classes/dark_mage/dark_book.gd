extends Node2D

const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")
const VICTIM_FRAMES := preload("res://assets/sprites/effects/dark_mage/dark_book/dark_book_spriteframes.tres")

const PROFILE_ID := "weapon_ultimate.profile.dark_mage.dark_book"
const EXECUTOR_ID := "weapon_ultimate.executor.dark_mage.dark_book"
const EFFECT_SCENE := "res://scripts/ultimates/classes/dark_mage/dark_book.tscn"

var ultimate_damage_sink: Callable = Callable()
var pair_count_for_tests := 0

var _activation = null
var _targets: Array = []
var _origin := Vector2.ZERO
var _impacts: Node2D = null
var _impacts_started := false


static func parameter_contract() -> Dictionary:
	return {
		"radius": {"type": "number", "minimum": 0.0},
		"release_delay": {"type": "number", "minimum": 0.0},
		"original_damage": {"type": "number", "minimum": 0.0},
		"reflection_radius": {"type": "number", "minimum": 0.0},
		"lifetime": {"type": "number", "minimum": 0.1},
	}


static func execute(activation) -> float:
	var targets: Array = activation.select_targets(
		activation.origin(),
		INF,
		0,
		"nearest"
	)
	var effect = activation.spawn(EFFECT_SCENE)
	if effect == null or not effect.has_method("configure"):
		return 0.0
	effect.call("configure", activation, targets)
	activation.present("weapon_ultimate.phase.dark_mage.dark_book.execute", {
		"position": activation.origin(),
		"radius": activation.param_float("radius", 620.0) * 0.32,
		"shape": "orb_burst",
	})
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var release_delay: float = activation.param_float("release_delay", 0.6)
	tween.tween_interval(release_delay)
	for index in targets.size():
		tween.tween_callback(Callable(effect, "detonate_pair").bind(index))
	var elapsed: float = release_delay
	var lifetime: float = activation.param_float("lifetime", 5.2)
	if lifetime > elapsed:
		tween.tween_interval(lifetime - elapsed)
	return lifetime


func configure(activation, targets: Array) -> void:
	_activation = activation
	_targets = targets.duplicate()
	_origin = activation.origin()
	global_position = _origin


## Every live enemy receives one floor hit. Its reflected point remains the
## signature visual read, never a reach gate or a recursive damage fanout.
func detonate_pair(index: int) -> void:
	if _activation == null or _activation.is_finished() or index < 0 or index >= _targets.size():
		return
	var original := _targets[index] as Node2D
	if not _alive(original):
		return
	var mirror_point := _origin * 2.0 - original.global_position
	pair_count_for_tests += 1
	_deal(
		original,
		_activation.scaled_damage("original_damage", 0.0),
		"abyss_original:%d" % index,
		false,
		{"ultimate_mechanic": "abyss_original", "pair": index}
	)
	_play_impacts([original])
	_activation.present("weapon_ultimate.phase.dark_mage.dark_book.active", {
		"position": mirror_point,
		"radius": _activation.param_float("reflection_radius", 150.0),
		"shape": "orb_burst",
	})


func _play_impacts(victims: Array) -> void:
	if victims.is_empty() or _activation == null:
		return
	if _impacts == null:
		_impacts = ImpactPlayer.new()
		add_child(_impacts)
	if _impacts_started:
		_impacts.enqueue(victims, _origin)
	else:
		_impacts.play(VICTIM_FRAMES, victims, _origin)
		_impacts_started = true


func _deal(target: Node, amount: float, event_id: String, secondary: bool, feedback: Dictionary):
	if not ultimate_damage_sink.is_valid():
		return null
	return ultimate_damage_sink.call(target, amount, feedback, event_id, secondary)


func _alive(target: Node2D) -> bool:
	return target != null and is_instance_valid(target) \
		and (target.get("health") == null or float(target.get("health")) > 0.0)


func _exit_tree() -> void:
	_targets.clear()
	_activation = null
