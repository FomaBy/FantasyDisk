class_name UltimateActivation
extends RefCounted

## One live ultimate cast — the ledger every executor writes through.
##
## Executors never touch the host directly. They ask the activation for targets,
## damage, modifiers, spawns and presentation, so a single shutdown() undoes the
## whole cast and a single budget caps the whole activation on one boss.
##
## The host contract is the eight `ultimate_host_*` methods listed in
## HOST_METHODS; `scripts/player.gd` implements them as a narrow adapter.

const DamageResult := preload("res://scripts/ultimates/controller/ultimate_damage_result.gd")

const BOSS_GROUP := "bosses"
const OP_ADD := "add"
const OP_MULTIPLY := "mul"
const DAMAGE_SINK_PROPERTY := "ultimate_damage_sink"
const HOST_METHODS := [
	"ultimate_host_context",
	"ultimate_host_position",
	"ultimate_host_targets",
	"ultimate_host_apply_damage",
	"ultimate_host_modifier",
	"ultimate_host_effect_parent",
	"ultimate_host_present",
	"ultimate_host_set_active",
]

var host: Node = null
var params: Dictionary = {}
var context: Dictionary = {}
var total_boss_cap: float = 0.0
var applied_total: float = 0.0

var _boss_budget: Dictionary = {}
var _tweens: Array[Tween] = []
var _spawned: Array[Node] = []
var _presentation: Array[Node] = []
var _modifiers: Array = []
var _finished := false


static func host_supports(candidate: Node) -> bool:
	if candidate == null or not is_instance_valid(candidate):
		return false
	for method in HOST_METHODS:
		if not candidate.has_method(str(method)):
			return false
	return true


func _init(host_node: Node, executor_params: Dictionary, boss_cap: float) -> void:
	host = host_node
	params = executor_params.duplicate(true)
	total_boss_cap = clampf(boss_cap, 0.0, 1.0)
	context = host.call("ultimate_host_context") if host != null else {}
	if not context is Dictionary:
		context = {}


func is_finished() -> bool:
	return _finished


# --- declaration access -------------------------------------------------------

func param_float(key: String, fallback: float) -> float:
	var value = params.get(key, fallback)
	return float(value) if (value is int or value is float) and not value is bool else fallback


func param_int(key: String, fallback: int) -> int:
	var value = params.get(key, fallback)
	return int(value) if (value is int or value is float) and not value is bool else fallback


func param_string(key: String, fallback := "") -> String:
	var value = params.get(key, fallback)
	return str(value) if value is String else fallback


func param_dictionary(key: String) -> Dictionary:
	var value = params.get(key, {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func param_bool(key: String, fallback := false) -> bool:
	var value = params.get(key, fallback)
	return bool(value) if value is bool else fallback


## Per-hit damage: the host's ultimate damage channel scaled by the declaration
## coefficient. Executors multiply this by their own falloff, never by a class.
func scaled_damage(coefficient_key := "damage", fallback_coefficient := 1.0) -> float:
	var base := float(context.get("damage", 0.0)) * float(context.get("multiplier", 1.0))
	return maxf(base * param_float(coefficient_key, fallback_coefficient), 0.0)


func damage_feedback(extra: Dictionary = {}) -> Dictionary:
	var feedback := {
		"damage_type": str(context.get("damage_type", "physical")),
		"player_owned": true,
	}
	feedback.merge(extra, true)
	return feedback


# --- world access -------------------------------------------------------------

func origin() -> Vector2:
	if host == null or not is_instance_valid(host):
		return Vector2.ZERO
	return host.call("ultimate_host_position")


## `limit <= 0` means every target inside the radius; otherwise the nearest N.
func targets(center: Vector2, radius: float, limit := 0) -> Array:
	if _finished or host == null or not is_instance_valid(host):
		return []
	var found = host.call("ultimate_host_targets", center, maxf(radius, 0.0), limit)
	return found if found is Array else []


func deal_damage(target: Node, amount: float, extra_feedback: Dictionary = {}) -> DamageResult:
	if _finished or target == null or not is_instance_valid(target):
		return DamageResult.new()
	var target_id := target.get_instance_id()
	var attempted := maxf(amount, 0.0)
	var requested := attempted
	var capped := false
	var budgeted := _has_boss_budget(target)
	if budgeted:
		var remaining := _boss_budget_for(target, target_id)
		if requested > remaining:
			requested = maxf(remaining, 0.0)
			capped = true
	if requested <= 0.0:
		return DamageResult.new(target_id, attempted, 0.0, capped, false)
	var applied := _apply_and_measure(target, requested, extra_feedback)
	if budgeted:
		_boss_budget[target_id] = maxf(float(_boss_budget.get(target_id, 0.0)) - applied, 0.0)
	applied_total += applied
	var killed := is_instance_valid(target) and target.get("health") != null \
		and float(target.get("health")) <= 0.0
	return DamageResult.new(target_id, attempted, applied, capped, killed)


func remaining_boss_budget(target: Node) -> float:
	if not _has_boss_budget(target):
		return INF
	return _boss_budget_for(target, target.get_instance_id())


# --- tracked resources --------------------------------------------------------

func track_tween() -> Tween:
	if _finished or host == null or not is_instance_valid(host) or not host.is_inside_tree():
		return null
	var tween := host.create_tween()
	_tweens.append(tween)
	return tween


func apply_modifier(key: String, value: float, op := OP_ADD) -> void:
	if _finished or key.is_empty() or host == null or not is_instance_valid(host):
		return
	if op == OP_MULTIPLY and is_zero_approx(value):
		return
	host.call("ultimate_host_modifier", key, value, op)
	_modifiers.append([key, value, op])


## Instantiate a declared scene into the host's effect parent and own its
## lifetime: shutdown() frees whatever is still alive.
func spawn(scene_path: String) -> Node:
	if _finished or scene_path.is_empty() or host == null or not is_instance_valid(host):
		return null
	var parent = host.call("ultimate_host_effect_parent")
	if not parent is Node or not is_instance_valid(parent):
		return null
	var scene = load(scene_path)
	if not scene is PackedScene:
		return null
	var node := (scene as PackedScene).instantiate()
	if node == null:
		return null
	(parent as Node).add_child(node)
	_spawned.append(node)
	bind_damage_sink(node)
	return node


## Deferred damage sources (summons, deploys) opt into the activation budget by
## exposing an `ultimate_damage_sink` property; anything else is left untouched.
func bind_damage_sink(node: Node) -> void:
	if node == null or not is_instance_valid(node) or not DAMAGE_SINK_PROPERTY in node:
		return
	node.set(DAMAGE_SINK_PROPERTY, Callable(self, "deal_damage"))


func present(event_id: String, payload: Dictionary = {}) -> Node:
	if _finished or host == null or not is_instance_valid(host):
		return null
	var node = host.call("ultimate_host_present", event_id, payload)
	if node is Node and is_instance_valid(node):
		_presentation.append(node)
		return node
	return null


## `free_presentation` separates the two endings: a cast that ran to completion
## lets its last VFX fade, a cancelled one (death, node end, new run) clears the
## screen immediately. Both revert modifiers and drop tweens and spawns.
func shutdown(free_presentation: bool) -> void:
	if _finished:
		return
	_finished = true
	for tween in _tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_tweens.clear()
	for node in _spawned:
		if node != null and is_instance_valid(node):
			node.queue_free()
	_spawned.clear()
	if free_presentation:
		for node in _presentation:
			if node != null and is_instance_valid(node):
				node.queue_free()
	_presentation.clear()
	# Reverse order so stacked multiplicative modifiers unwind to the exact
	# value they had before the cast.
	for index in range(_modifiers.size() - 1, -1, -1):
		var entry: Array = _modifiers[index]
		var value := float(entry[1])
		if str(entry[2]) == OP_MULTIPLY:
			_revert_modifier(str(entry[0]), 1.0 / value, OP_MULTIPLY)
		else:
			_revert_modifier(str(entry[0]), -value, OP_ADD)
	_modifiers.clear()


## The tween an executor scheduled its own work on, if any. The controller
## chains cast completion onto it instead of racing it with a parallel timer.
func last_tween() -> Tween:
	for index in range(_tweens.size() - 1, -1, -1):
		var tween := _tweens[index]
		if tween != null and tween.is_valid():
			return tween
	return null


func tweens_for_tests() -> Array[Tween]:
	return _tweens.duplicate()


func spawned_for_tests() -> Array[Node]:
	return _spawned.duplicate()


func presentation_for_tests() -> Array[Node]:
	return _presentation.duplicate()


func _revert_modifier(key: String, value: float, op: String) -> void:
	if host == null or not is_instance_valid(host):
		return
	host.call("ultimate_host_modifier", key, value, op)


func _has_boss_budget(target: Node) -> bool:
	return total_boss_cap > 0.0 and target.is_in_group(BOSS_GROUP) \
		and target.get("max_health") != null


## Opened once per boss per activation. `Dictionary.get(key, default)` evaluates
## its default eagerly, so the lookup has to stay an explicit `has` check —
## otherwise every hit would re-open a full budget and the cap would never bind.
func _boss_budget_for(target: Node, target_id: int) -> float:
	if not _boss_budget.has(target_id):
		_boss_budget[target_id] = maxf(float(target.get("max_health")) * total_boss_cap, 0.0)
	return float(_boss_budget[target_id])


## Mirrors enemy.gd: the authoritative delta is the overkill-clamped HP loss, so
## a lethal hit contributes only the HP that existed, not the number requested.
func _apply_and_measure(target: Node, amount: float, extra_feedback: Dictionary) -> float:
	var tracks_health := target.get("health") != null
	var before := float(target.get("health")) if tracks_health else 0.0
	host.call("ultimate_host_apply_damage", target, amount, damage_feedback(extra_feedback))
	if not tracks_health or not is_instance_valid(target):
		return amount
	return maxf(before - maxf(float(target.get("health")), 0.0), 0.0)
