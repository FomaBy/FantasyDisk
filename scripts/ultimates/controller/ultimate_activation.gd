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
	"ultimate_host_aim",
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
var _aim_cache: Dictionary = {}
var _primitive_state: Dictionary = {}
var _composition_trace: Array[String] = []
var _composition_aborted := false
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


## Capture one immutable aim sample for a range. Missing or malformed host data
## stays empty; callers decide which declared target mode they requested and do
## not fall through to another one.
func aim_context(max_range: float) -> Dictionary:
	var range_limit := maxf(max_range, 0.0)
	if _finished or host == null or not is_instance_valid(host) or range_limit <= 0.0:
		return {}
	var cache_key := range_limit
	if _aim_cache.has(cache_key):
		return (_aim_cache[cache_key] as Dictionary).duplicate(true)
	var raw = host.call("ultimate_host_aim", range_limit)
	if not raw is Dictionary:
		return {}
	var source := origin()
	var point = (raw as Dictionary).get("point")
	var direction = (raw as Dictionary).get("direction")
	if not point is Vector2 or not direction is Vector2:
		return {}
	var resolved_point := point as Vector2
	var offset := resolved_point - source
	if offset.length() > range_limit:
		resolved_point = source + offset.normalized() * range_limit
	var resolved_direction := direction as Vector2
	if resolved_direction.length_squared() <= 0.001:
		return {}
	var snapshot := {
		"source": source,
		"target": resolved_point,
		"direction": resolved_direction.normalized(),
	}
	_aim_cache[cache_key] = snapshot
	return snapshot.duplicate(true)


func aim_point(max_range: float) -> Vector2:
	return aim_context(max_range).get("target", Vector2.ZERO)


func aim_direction(max_range: float) -> Vector2:
	return aim_context(max_range).get("direction", Vector2.ZERO)


## `limit <= 0` means every target inside the radius; otherwise the nearest N.
func targets(center: Vector2, radius: float, limit := 0) -> Array:
	if _finished or host == null or not is_instance_valid(host):
		return []
	if _primitive_state.has("targets"):
		var selected: Array = []
		for raw_target in _primitive_state["targets"] as Array:
			var target := raw_target as Node2D
			if target != null and is_instance_valid(target) \
					and target.global_position.distance_to(center) <= maxf(radius, 0.0):
				selected.append(target)
				if limit > 0 and selected.size() >= limit:
					break
		return selected
	return _host_targets(center, radius, limit)


## Generic deterministic policies. A policy with missing hints returns an empty
## set; it never degrades to nearest or another targeting mode.
func select_targets(
	center: Vector2,
	radius: float,
	limit: int,
	priority: String,
	hint: Dictionary = {}
) -> Array:
	var raw_targets := _host_targets(center, radius, 0)
	var candidates: Array[Dictionary] = []
	var seen := {}
	var aimed_point = hint.get("point")
	if priority == "aimed" and not aimed_point is Vector2:
		return []
	var cluster_radius := float(hint.get("cluster_radius", 0.0))
	if priority == "densest_cluster" and cluster_radius <= 0.0:
		return []
	if priority == "marked" and not _valid_mark_hint(hint):
		return []
	for raw_target in raw_targets:
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var target_id := target.get_instance_id()
		if seen.has(target_id) or (priority == "marked" and not _matches_mark(target, hint)):
			continue
		seen[target_id] = true
		var distance := center.distance_squared_to(target.global_position)
		var primary := distance
		match priority:
			"aimed":
				primary = (aimed_point as Vector2).distance_squared_to(target.global_position)
			"highest_hp":
				primary = -float(target.get("health") if target.get("health") != null else 0.0)
			"densest_cluster":
				primary = -float(_neighbor_count(target, raw_targets, cluster_radius))
			"marked", "nearest":
				pass
			_:
				return []
		candidates.append({
			"node": target,
			"primary": primary,
			"distance": distance,
			"x": target.global_position.x,
			"y": target.global_position.y,
			"id": target_id,
		})
	candidates.sort_custom(_candidate_before)
	var result: Array = []
	for candidate in candidates:
		result.append(candidate["node"])
		if limit > 0 and result.size() >= limit:
			break
	return result


## Ordered corridor hits: projection first, lateral distance second, then a
## stable positional/id tie-break. Duplicate host entries are removed.
func targets_in_corridor(
	start: Vector2,
	direction: Vector2,
	length: float,
	half_width: float,
	limit := 0
) -> Array:
	if direction.length_squared() <= 0.001 or length < 0.0 or half_width < 0.0:
		return []
	var axis := direction.normalized()
	var perpendicular := Vector2(-axis.y, axis.x)
	var query_radius := sqrt(length * length + half_width * half_width)
	var candidates: Array[Dictionary] = []
	var seen := {}
	for raw_target in _host_targets(start, query_radius, 0):
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var target_id := target.get_instance_id()
		if seen.has(target_id):
			continue
		var offset := target.global_position - start
		var forward := offset.dot(axis)
		var lateral := absf(offset.dot(perpendicular))
		if forward < 0.0 or forward > length or lateral > half_width:
			continue
		seen[target_id] = true
		candidates.append({
			"node": target,
			"primary": forward,
			"distance": lateral,
			"x": target.global_position.x,
			"y": target.global_position.y,
			"id": target_id,
		})
	candidates.sort_custom(_candidate_before)
	var result: Array = []
	for candidate in candidates:
		result.append(candidate["node"])
		if limit > 0 and result.size() >= limit:
			break
	return result


## Deterministic class-agnostic point formations. Pattern-specific dictionaries
## reach this method only after library admission, but direct callers still get
## an empty result for malformed bounds.
func pattern_points(center: Vector2, pattern: String, pattern_params: Dictionary) -> PackedVector2Array:
	var points := PackedVector2Array()
	match pattern:
		"ring", "polygon", "radial":
			var count := int(pattern_params.get("count", 0))
			var radius := float(pattern_params.get("radius", -1.0))
			var rotation := deg_to_rad(float(pattern_params.get("rotation_degrees", 0.0)))
			var arc := deg_to_rad(float(pattern_params.get("arc_degrees", 360.0)))
			if count <= 0 or radius < 0.0 or arc <= 0.0 or arc > TAU + 0.001:
				return points
			var divisor := float(count) if is_equal_approx(arc, TAU) else float(maxi(count - 1, 1))
			for index in count:
				points.append(center + Vector2.RIGHT.rotated(rotation + arc * float(index) / divisor) * radius)
		"grid":
			var rows := int(pattern_params.get("rows", 0))
			var columns := int(pattern_params.get("columns", 0))
			var spacing := float(pattern_params.get("spacing", -1.0))
			var rotation := deg_to_rad(float(pattern_params.get("rotation_degrees", 0.0)))
			if rows <= 0 or columns <= 0 or spacing < 0.0:
				return points
			for row in rows:
				for column in columns:
					var local := Vector2(
						(float(column) - float(columns - 1) * 0.5) * spacing,
						(float(row) - float(rows - 1) * 0.5) * spacing
					)
					points.append(center + local.rotated(rotation))
		"seeded_annulus":
			var count := int(pattern_params.get("count", 0))
			var inner_radius := float(pattern_params.get("inner_radius", -1.0))
			var outer_radius := float(pattern_params.get("outer_radius", -1.0))
			var state := int(pattern_params.get("seed", 0)) & 0x7fffffff
			if count <= 0 or inner_radius < 0.0 or outer_radius < inner_radius:
				return points
			for _index in count:
				state = (1103515245 * state + 12345) & 0x7fffffff
				var angle := TAU * float(state) / 2147483648.0
				state = (1103515245 * state + 12345) & 0x7fffffff
				var unit := float(state) / 2147483648.0
				var radius := sqrt(lerpf(inner_radius * inner_radius, outer_radius * outer_radius, unit))
				points.append(center + Vector2.RIGHT.rotated(angle) * radius)
	return points


func targets_at_points(points: PackedVector2Array, hit_radius: float, limit := 0) -> Array:
	if hit_radius < 0.0:
		return []
	var result: Array = []
	var seen := {}
	for point in points:
		for target in select_targets(point, hit_radius, 0, "nearest"):
			var target_id := (target as Node).get_instance_id()
			if seen.has(target_id):
				continue
			seen[target_id] = true
			result.append(target)
			if limit > 0 and result.size() >= limit:
				return result
	return result


func set_primitive_state(values: Dictionary) -> void:
	for key in values:
		_primitive_state[key] = values[key]


func primitive_value(key: String, fallback = null):
	return _primitive_state.get(key, fallback)


func set_primitive_targets(selected: Array) -> void:
	_primitive_state["targets"] = selected.duplicate()


func composition_step(step_id: String) -> void:
	_composition_trace.append(step_id)


func composition_trace_for_tests() -> Array[String]:
	return _composition_trace.duplicate()


func abort_composition() -> void:
	_composition_aborted = true


func composition_aborted() -> bool:
	return _composition_aborted


func _host_targets(center: Vector2, radius: float, limit: int) -> Array:
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
	_aim_cache.clear()
	_primitive_state.clear()
	_composition_trace.clear()
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


static func _candidate_before(left: Dictionary, right: Dictionary) -> bool:
	for key in ["primary", "distance", "x", "y"]:
		var left_value := float(left[key])
		var right_value := float(right[key])
		if not is_equal_approx(left_value, right_value):
			return left_value < right_value
	return int(left["id"]) < int(right["id"])


static func _neighbor_count(target: Node2D, raw_targets: Array, radius: float) -> int:
	var count := 0
	var radius_squared := radius * radius
	var seen := {}
	for raw_neighbor in raw_targets:
		var neighbor := raw_neighbor as Node2D
		if neighbor == null or not is_instance_valid(neighbor):
			continue
		var neighbor_id := neighbor.get_instance_id()
		if seen.has(neighbor_id):
			continue
		seen[neighbor_id] = true
		if target.global_position.distance_squared_to(neighbor.global_position) <= radius_squared:
			count += 1
	return count


static func _valid_mark_hint(hint: Dictionary) -> bool:
	return (hint.get("group") is String and not str(hint["group"]).is_empty()) \
		or (hint.get("meta_key") is String and not str(hint["meta_key"]).is_empty())


static func _matches_mark(target: Node, hint: Dictionary) -> bool:
	if hint.get("group") is String and not str(hint["group"]).is_empty():
		return target.is_in_group(str(hint["group"]))
	var key := str(hint.get("meta_key", ""))
	if key.is_empty() or not target.has_meta(key):
		return false
	return not hint.has("meta_value") or target.get_meta(key) == hint["meta_value"]
