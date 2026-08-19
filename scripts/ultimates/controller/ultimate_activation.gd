class_name UltimateActivation
extends RefCounted

signal owner_resource_emitted(event: Dictionary)

## One live ultimate cast — the ledger every executor writes through.
##
## Executors never touch the host directly. They ask the activation for targets,
## damage, modifiers, spawns and presentation, so a single shutdown() undoes the
## whole cast and a single budget caps the whole activation on one boss.
##
## The host contract is the ten `ultimate_host_*` methods listed in
## HOST_METHODS; `scripts/player.gd` implements them as a narrow adapter.
## Repair is an optional extra channel: a host that exposes
## HOST_REPAIR_METHOD opts in, every other host keeps repair failing closed.

const DamageResult := preload("res://scripts/ultimates/controller/ultimate_damage_result.gd")
const GuardPreventionLedger := preload("res://scripts/ultimates/controller/ultimate_guard_prevention_ledger.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")

const BOSS_GROUP := "bosses"
const EPIC_GROUP := "elite_enemies"
const OP_ADD := "add"
const OP_MULTIPLY := "mul"
const DAMAGE_SINK_PROPERTY := "ultimate_damage_sink"
const DAMAGE_PROVENANCE_KEY := "ultimate_provenance"
const DAMAGE_PROVENANCE_VALUE := "activation"
const DAMAGE_PROVENANCE_EVENT_KEY := "ultimate_provenance_event_id"
# Optional host channel: deliberately not part of HOST_METHODS, so existing
# hosts keep passing host_supports() and repair stays default-off for them.
const HOST_REPAIR_METHOD := "ultimate_host_repair"
# Optional host channel too: a host that runs an authored presentation reports
# it here, and one that does not simply owns no presentation channel.
const HOST_PRESENTATION_ACTIVE_METHOD := "ultimate_host_presentation_active"
# The whole generic init contract of deploy_temporary(); unknown keys fail
# the deploy closed before any node is created.
const DEPLOY_INIT_KEYS := ["properties", "setup_method", "setup_args"]
const HOST_METHODS := [
	"ultimate_host_context",
	"ultimate_host_position",
	"ultimate_host_aim",
	"ultimate_host_targets",
	"ultimate_host_summons",
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
var _target_damage_cap: Dictionary = {}
var _target_damage_budget: Dictionary = {}
var _target_ledger: Dictionary = {}
var _claimed_events: Dictionary = {}
var _guard_prevention_ledger := GuardPreventionLedger.new()
var _control_policy: Dictionary = {}
var _repair_cap := 0.0
var _repair_budget := 0.0
var _summon_contract: Dictionary = {}
var _summon_snapshots: Array = []
var _tweens: Array[Tween] = []
var _spawned: Array[Node] = []
var _presentation: Array[Node] = []
var _modifiers: Array = []
var _aim_cache: Dictionary = {}
var _primitive_state: Dictionary = {}
var _composition_trace: Array[String] = []
var _composition_aborted := false
var _finished := false
var _damage_provenance_sequence := 0


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
	_guard_prevention_ledger.owner_resource_emitted.connect(_on_owner_resource_emitted)


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


static func is_ultimate_damage_feedback(feedback: Dictionary) -> bool:
	return str(feedback.get(DAMAGE_PROVENANCE_KEY, "")) == DAMAGE_PROVENANCE_VALUE


func damage_feedback(extra: Dictionary = {}) -> Dictionary:
	var feedback := {
		"damage_type": str(context.get("damage_type", "physical")),
		"player_owned": true,
	}
	feedback.merge(extra, true)
	_damage_provenance_sequence += 1
	# This is set after executor feedback so no executor can accidentally erase
	# the lifecycle provenance used by runtime attribution.
	feedback[DAMAGE_PROVENANCE_KEY] = DAMAGE_PROVENANCE_VALUE
	feedback[DAMAGE_PROVENANCE_EVENT_KEY] = "%d:%d" % [get_instance_id(), _damage_provenance_sequence]
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


# --- measured guard prevention and owner resources --------------------------

## The activation stays a lifecycle adapter; its focused ledger owns strict
## attribution, cap and one-shot counter semantics without class branches.
func configure_guard_prevention(owner_id: String, resource_id: String, cap: float, facing: Vector2, arc_degrees: float, sources: Array[String]) -> bool:
	return not _finished and _guard_prevention_ledger.configure(owner_id, resource_id, cap, facing, arc_degrees, sources)


func guard_prevention_owner_id() -> String:
	return _guard_prevention_ledger.owner_id() if not _finished else ""


func record_guard_prevention(event: Dictionary) -> float:
	return _guard_prevention_ledger.record(event) if not _finished else 0.0


func apply_owner_resource(owner_id: String, resource_id: String, amount: float, cap: float, event_id: String) -> float:
	return _guard_prevention_ledger.apply(owner_id, resource_id, amount, cap, event_id) if not _finished else 0.0


func owner_resource_amount(owner_id: String, resource_id: String) -> float:
	return _guard_prevention_ledger.amount(owner_id, resource_id) if not _finished else 0.0


func consume_owner_resource(owner_id: String, resource_id: String, event_id: String) -> Dictionary:
	return _guard_prevention_ledger.consume(owner_id, resource_id, event_id) if not _finished else {
		"owner_id": owner_id.strip_edges(), "resource_id": resource_id.strip_edges(),
		"event_id": event_id.strip_edges(), "amount": 0.0,
	}


func _on_owner_resource_emitted(event: Dictionary) -> void:
	owner_resource_emitted.emit(event)


# --- activation-local interaction state --------------------------------------

func record_target_value(
	target: Node, key: String, value, event_id: String
) -> bool:
	if not _valid_target_event(target, key, event_id) \
			or not _claim_event("ledger:%d:%s" % [target.get_instance_id(), event_id]):
		return false
	var target_id := target.get_instance_id()
	var values: Dictionary = _target_ledger.get(target_id, {})
	values[key] = _duplicate_value(value)
	_target_ledger[target_id] = values
	return true


func add_target_value(
	target: Node, key: String, amount: float, event_id: String
) -> bool:
	if not is_finite(amount) or not _valid_target_event(target, key, event_id):
		return false
	var target_id := target.get_instance_id()
	var values: Dictionary = _target_ledger.get(target_id, {})
	var current = values.get(key, 0.0)
	if not (current is int or current is float) or current is bool:
		return false
	if not _claim_event("ledger:%d:%s" % [target_id, event_id]):
		return false
	values[key] = float(current) + amount
	_target_ledger[target_id] = values
	return true


func target_value(target: Node, key: String, fallback = null):
	if target == null or not is_instance_valid(target) or key.is_empty():
		return fallback
	var values = _target_ledger.get(target.get_instance_id())
	if not values is Dictionary:
		return fallback
	return _duplicate_value((values as Dictionary).get(key, fallback))


func consume_target_value(target: Node, key: String, event_id: String, fallback = null):
	if not _valid_target_event(target, key, event_id):
		return fallback
	var target_id := target.get_instance_id()
	var values = _target_ledger.get(target_id)
	if not values is Dictionary or not (values as Dictionary).has(key):
		return fallback
	if not _claim_event("ledger:%d:%s" % [target_id, event_id]):
		return fallback
	var consumed = _duplicate_value((values as Dictionary)[key])
	(values as Dictionary).erase(key)
	if (values as Dictionary).is_empty():
		_target_ledger.erase(target_id)
	return consumed


func transfer_target_value(
	source: Node, destination: Node, key: String, event_id: String
) -> bool:
	if not _valid_target_event(source, key, event_id) or destination == null \
			or not is_instance_valid(destination):
		return false
	var source_id := source.get_instance_id()
	var destination_id := destination.get_instance_id()
	var source_values = _target_ledger.get(source_id)
	if not source_values is Dictionary or not (source_values as Dictionary).has(key):
		return false
	if not _claim_event("ledger:%d:%d:%s" % [source_id, destination_id, event_id]):
		return false
	var destination_values: Dictionary = _target_ledger.get(destination_id, {})
	destination_values[key] = _duplicate_value((source_values as Dictionary)[key])
	_target_ledger[destination_id] = destination_values
	(source_values as Dictionary).erase(key)
	if (source_values as Dictionary).is_empty():
		_target_ledger.erase(source_id)
	return true


func set_per_target_damage_cap(cap_fraction: float, cap_flat := 0.0) -> bool:
	if _finished or not is_finite(cap_fraction) or not is_finite(cap_flat) \
			or cap_fraction < 0.0 or cap_fraction > 1.0 or cap_flat < 0.0 \
			or (is_zero_approx(cap_fraction) and is_zero_approx(cap_flat)):
		return false
	var requested := {"fraction": cap_fraction, "flat": cap_flat}
	if not _target_damage_cap.is_empty():
		return _target_damage_cap == requested
	_target_damage_cap = requested
	return true


func remaining_target_damage_budget(target: Node) -> float:
	if _target_damage_cap.is_empty():
		return INF
	if target == null or not is_instance_valid(target):
		return 0.0
	return _target_budget_for(target, target.get_instance_id())


func set_control_resistance_policy(policy: Dictionary) -> bool:
	if _finished or policy.is_empty():
		return false
	if not _control_policy.is_empty():
		return _control_policy == policy
	_control_policy = policy.duplicate(true)
	return true


func apply_control(
	target: Node,
	impulse: Vector2,
	status_id: String,
	status_config: Dictionary
) -> Dictionary:
	if _finished or target == null or not is_instance_valid(target):
		return {"applied": false}
	var tier := _target_tier(target)
	var policy := {
		"displacement_multiplier": 1.0,
		"duration_multiplier": 1.0,
		"allow_movement_lock": true,
		"allow_execute": true,
	}
	if not _control_policy.is_empty():
		var declared = _control_policy.get(tier)
		if not declared is Dictionary:
			return {"applied": false, "tier": tier}
		policy = declared as Dictionary
	var scaled_impulse := impulse * float(policy["displacement_multiplier"])
	var displaced := false
	if scaled_impulse.length_squared() > 0.001 and target.has_method("apply_knockback"):
		target.call("apply_knockback", scaled_impulse)
		displaced = true
	var admitted_status := status_config.duplicate(true)
	admitted_status.erase("dot_damage")
	if not bool(policy["allow_movement_lock"]):
		admitted_status.erase("movement_locked")
		admitted_status.erase("movement_lock")
	if admitted_status.has("duration"):
		admitted_status["duration"] = maxf(
			float(admitted_status["duration"]) * float(policy["duration_multiplier"]), 0.0
		)
	var status_applied := not status_id.is_empty() \
		and (not admitted_status.has("duration") or float(admitted_status["duration"]) > 0.0)
	if status_applied:
		StatusEffects.apply_status(target, status_id, admitted_status)
	return {
		"applied": displaced or status_applied,
		"tier": tier,
		"displaced": displaced,
		"status_applied": status_applied,
		"execute_allowed": bool(policy["allow_execute"]),
	}


## Opens the bounded repair budget for this activation. Declared once, like
## the per-target damage cap: a repeat only agrees with the same value, and
## without a configured cap every repair() fails closed.
func configure_repair(total_cap: float) -> bool:
	if _finished or not is_finite(total_cap) or total_cap <= 0.0:
		return false
	if _repair_cap > 0.0:
		return is_equal_approx(_repair_cap, total_cap)
	_repair_cap = total_cap
	_repair_budget = total_cap
	return true


## Capped repair through the optional host channel. The host decides whether
## the target is the hero or one of its own devices; the activation only
## meters the budget. `applied` is the HP the target actually regained —
## mirroring the applied-damage attribution — so overheal and a refused
## foreign target spend nothing.
func repair(target: Node, amount: float, event_id := "") -> Dictionary:
	var requested := maxf(amount, 0.0) if is_finite(amount) else 0.0
	var result := {"requested": requested, "applied": 0.0}
	if _finished or requested <= 0.0 or _repair_budget <= 0.0 \
			or target == null or not is_instance_valid(target) \
			or host == null or not is_instance_valid(host) \
			or not host.has_method(HOST_REPAIR_METHOD) \
			or target.get("health") == null:
		return result
	if not event_id.is_empty() \
			and not _claim_event("repair:%d:%s" % [target.get_instance_id(), event_id]):
		return result
	var granted := minf(requested, _repair_budget)
	var before := maxf(float(target.get("health")), 0.0)
	host.call(HOST_REPAIR_METHOD, target, granted)
	if not is_instance_valid(target):
		return result
	var applied := clampf(float(target.get("health")) - before, 0.0, granted)
	_repair_budget = maxf(_repair_budget - applied, 0.0)
	result["applied"] = applied
	return result


func configure_summon_interaction(
	group_id: String,
	temporary_cap: int,
	snapshot_properties: Array,
	setup: Dictionary
) -> bool:
	if _finished or group_id.is_empty() or temporary_cap < 0 or host == null \
			or not is_instance_valid(host):
		return false
	var requested := {
		"group_id": group_id,
		"temporary_cap": temporary_cap,
		"snapshot_properties": snapshot_properties.duplicate(),
		"setup": setup.duplicate(true),
	}
	if not _summon_contract.is_empty():
		return _summon_contract == requested
	var found = host.call("ultimate_host_summons", group_id)
	if not found is Array:
		return false
	var snapshots: Array = []
	var seen := {}
	for raw_node in found as Array:
		var node := raw_node as Node
		if node == null or not is_instance_valid(node):
			continue
		var node_id := node.get_instance_id()
		if seen.has(node_id):
			continue
		seen[node_id] = true
		var properties := {}
		for raw_property in snapshot_properties:
			var property_name := str(raw_property)
			if not property_name in node:
				return false
			properties[property_name] = _duplicate_value(node.get(property_name))
		snapshots.append({
			"node": node,
			"visible": node.visible if node is CanvasItem else null,
			"process_mode": node.process_mode,
			"properties": properties,
		})
	_summon_contract = requested
	_summon_snapshots = snapshots
	for snapshot in _summon_snapshots:
		var node: Node = snapshot["node"]
		if node is CanvasItem:
			(node as CanvasItem).hide()
		node.process_mode = Node.PROCESS_MODE_DISABLED
	return true


func target_ledger_size_for_tests() -> int:
	return _target_ledger.size()


func summon_snapshot_count_for_tests() -> int:
	return _summon_snapshots.size()


func _host_targets(center: Vector2, radius: float, limit: int) -> Array:
	var found = host.call("ultimate_host_targets", center, maxf(radius, 0.0), limit)
	return found if found is Array else []


func deal_damage(
	target: Node,
	amount: float,
	extra_feedback: Dictionary = {},
	event_id := "",
	secondary := false
) -> DamageResult:
	if _finished or target == null or not is_instance_valid(target):
		return DamageResult.new()
	var target_id := target.get_instance_id()
	var attempted := maxf(amount, 0.0)
	if not event_id.is_empty() and not _claim_event("damage:%d:%s" % [target_id, event_id]):
		return DamageResult.new(target_id, attempted, 0.0, false, false, false, event_id, secondary)
	var requested := attempted
	var boss_capped := false
	var target_capped := false
	var budgeted := _has_boss_budget(target)
	if budgeted:
		var remaining := _boss_budget_for(target, target_id)
		boss_capped = attempted > remaining
		requested = minf(requested, maxf(remaining, 0.0))
	if not _target_damage_cap.is_empty():
		var target_remaining := _target_budget_for(target, target_id)
		target_capped = requested > target_remaining
		requested = minf(requested, maxf(target_remaining, 0.0))
	if requested <= 0.0:
		return DamageResult.new(
			target_id, attempted, 0.0, boss_capped, false, target_capped, event_id, secondary
		)
	var applied := _apply_and_measure(target, requested, extra_feedback)
	if budgeted:
		_boss_budget[target_id] = maxf(float(_boss_budget.get(target_id, 0.0)) - applied, 0.0)
	if not _target_damage_cap.is_empty():
		_target_damage_budget[target_id] = maxf(
			float(_target_damage_budget.get(target_id, 0.0)) - applied, 0.0
		)
	applied_total += applied
	var killed := is_instance_valid(target) and target.get("health") != null \
		and float(target.get("health")) <= 0.0
	return DamageResult.new(
		target_id,
		attempted,
		applied,
		boss_capped,
		killed,
		target_capped,
		event_id,
		secondary
	)


func remaining_boss_budget(target: Node) -> float:
	if not _has_boss_budget(target):
		return INF
	return _boss_budget_for(target, target.get_instance_id())


# --- tracked resources --------------------------------------------------------

func track_tween() -> Tween:
	if _finished or host == null or not is_instance_valid(host) or not host.is_inside_tree():
		return null
	var tween := host.create_tween()
	tween.set_ignore_time_scale(true)
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
	if not _summon_contract.is_empty() \
			and _spawned.size() >= int(_summon_contract["temporary_cap"]):
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
	var setup: Dictionary = _summon_contract.get("setup", {})
	if not setup.is_empty():
		if not node.has_method("ultimate_spawn_setup") \
				or node.call(
					"ultimate_spawn_setup", setup.duplicate(true), host, Callable(self, "deal_damage")
				) != true:
			_spawned.erase(node)
			node.queue_free()
			return null
	return node


## Fail-closed temporary deploy: `count` instances of a declared scene, each
## fully initialized off-tree through the generic init contract — ownership
## attribution, declared `properties`, then the optional `setup_method` called
## with `setup_args` (only an explicit `false` return rejects, so plain void
## setup methods qualify). Any failure frees everything this call created and
## nothing reaches the world; on success every node enters the host effect
## parent, is registered like any other spawn and binds the damage sink, so
## shutdown() removes the whole deploy with the rest of the cast.
func deploy_temporary(scene: PackedScene, init: Dictionary = {}, count := 1) -> Array[Node]:
	var created: Array[Node] = []
	if _finished or count < 1 or scene == null \
			or host == null or not is_instance_valid(host):
		return created
	for raw_key in init.keys():
		if not DEPLOY_INIT_KEYS.has(str(raw_key)):
			return created
	var properties = init.get("properties", {})
	var setup_method = init.get("setup_method", "")
	var setup_args = init.get("setup_args", [])
	if not properties is Dictionary or not setup_method is String or not setup_args is Array:
		return created
	if not _summon_contract.is_empty() \
			and _spawned.size() + count > int(_summon_contract["temporary_cap"]):
		return created
	var parent = host.call("ultimate_host_effect_parent")
	if not parent is Node or not is_instance_valid(parent):
		return created
	for _index in count:
		var node := scene.instantiate()
		if node != null:
			created.append(node)
		if node == null or not _initialize_deploy(
			node, properties as Dictionary, str(setup_method), setup_args as Array
		):
			# Nothing entered the tree yet, so partial failure leaves no orphan.
			for partial in created:
				partial.free()
			created.clear()
			return created
	for node in created:
		(parent as Node).add_child(node)
		_spawned.append(node)
		bind_damage_sink(node)
	return created


# A typed property silently ignores a mismatched set(), so every write is
# read back: a deploy whose ownership or declared setup did not actually land
# is rejected instead of entering the world half-initialized.
func _initialize_deploy(
	node: Node, properties: Dictionary, setup_method: String, setup_args: Array
) -> bool:
	if "owner_node" in node:
		node.set("owner_node", host)
		if node.get("owner_node") != host:
			return false
	for raw_key in properties.keys():
		var key := str(raw_key)
		if not key in node:
			return false
		node.set(key, properties[raw_key])
		if node.get(key) != properties[raw_key]:
			return false
	if setup_method.is_empty():
		return true
	if not node.has_method(setup_method):
		return false
	var outcome = node.callv(setup_method, setup_args)
	return not (outcome is bool and outcome == false)


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
	_restore_summons()
	if free_presentation:
		for node in _presentation:
			if node != null and is_instance_valid(node):
				node.queue_free()
	_presentation.clear()
	_aim_cache.clear()
	_primitive_state.clear()
	_composition_trace.clear()
	_boss_budget.clear()
	_target_damage_cap.clear()
	_target_damage_budget.clear()
	_target_ledger.clear()
	_claimed_events.clear()
	_guard_prevention_ledger.clear()
	_control_policy.clear()
	_repair_cap = 0.0
	_repair_budget = 0.0
	_summon_contract.clear()
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


## Presentation channels this cast is showing right now: the nodes it created
## itself plus the host's authored presentation while that one is live. The
## authored scene stays host-owned — `ultimate_host_finish_presentation` frees
## it before `shutdown()` runs — so it is counted here, never claimed.
func live_presentation_count() -> int:
	if _finished:
		return 0
	var host_presentation := host != null and is_instance_valid(host) \
		and host.has_method(HOST_PRESENTATION_ACTIVE_METHOD) \
		and bool(host.call(HOST_PRESENTATION_ACTIVE_METHOD))
	return _presentation.size() + (1 if host_presentation else 0)


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


func _target_budget_for(target: Node, target_id: int) -> float:
	if not _target_damage_budget.has(target_id):
		if target.get("max_health") == null:
			_target_damage_budget[target_id] = 0.0
		else:
			_target_damage_budget[target_id] = maxf(
				float(target.get("max_health")) * float(_target_damage_cap["fraction"])
					+ float(_target_damage_cap["flat"]),
				0.0
			)
	return float(_target_damage_budget[target_id])


func _claim_event(event_id: String) -> bool:
	if _finished or event_id.is_empty() or _claimed_events.has(event_id):
		return false
	_claimed_events[event_id] = true
	return true


func _valid_target_event(target: Node, key: String, event_id: String) -> bool:
	return not _finished and target != null and is_instance_valid(target) \
		and not key.is_empty() and not event_id.is_empty()


func _target_tier(target: Node) -> String:
	if target.is_in_group(BOSS_GROUP):
		return "boss"
	if target.is_in_group(EPIC_GROUP):
		return "epic"
	return "normal"


func _restore_summons() -> void:
	for snapshot in _summon_snapshots:
		var node = snapshot.get("node")
		if not node is Node or not is_instance_valid(node):
			continue
		var summon := node as Node
		for raw_property in (snapshot.get("properties", {}) as Dictionary).keys():
			summon.set(str(raw_property), _duplicate_value(snapshot["properties"][raw_property]))
		if summon is CanvasItem and snapshot.get("visible") is bool:
			(summon as CanvasItem).visible = bool(snapshot["visible"])
		summon.process_mode = int(snapshot["process_mode"])
	_summon_snapshots.clear()


static func _duplicate_value(value):
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	if value is PackedByteArray or value is PackedInt32Array or value is PackedInt64Array \
			or value is PackedFloat32Array or value is PackedFloat64Array \
			or value is PackedStringArray or value is PackedVector2Array \
			or value is PackedVector3Array or value is PackedColorArray:
		return value.duplicate()
	return value


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
