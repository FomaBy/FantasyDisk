class_name UltimateExecutorLibrary
extends RefCounted

## Strategy lookup for the executor families.
##
## The declaration's `executor.strategy_id` selects the family; nothing here or
## below it may branch on a class or a weapon.

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const BurstExecutor := preload("res://scripts/ultimates/executors/ultimate_burst_executor.gd")
const AimedSequenceExecutor := preload(
	"res://scripts/ultimates/executors/ultimate_aimed_sequence_executor.gd"
)
const TimedModifierExecutor := preload(
	"res://scripts/ultimates/executors/ultimate_timed_modifier_executor.gd"
)
const StatusZoneExecutor := preload(
	"res://scripts/ultimates/executors/ultimate_status_zone_executor.gd"
)
const ControlExecutor := preload("res://scripts/ultimates/executors/ultimate_control_executor.gd")
const DeploySummonExecutor := preload(
	"res://scripts/ultimates/executors/ultimate_deploy_summon_executor.gd"
)
const ChainedProjectileExecutor := preload(
	"res://scripts/ultimates/executors/ultimate_chained_projectile_executor.gd"
)
const TargetingPrimitives := preload(
	"res://scripts/ultimates/executors/ultimate_targeting_primitives.gd"
)

const COMPOSITION_ID := "ordered_step_composition"
const COMPOSITION_TAIL_SECONDS := 0.001

const EXECUTORS := {
	BurstExecutor.STRATEGY_ID: BurstExecutor,
	AimedSequenceExecutor.STRATEGY_ID: AimedSequenceExecutor,
	TimedModifierExecutor.STRATEGY_ID: TimedModifierExecutor,
	StatusZoneExecutor.STRATEGY_ID: StatusZoneExecutor,
	ControlExecutor.STRATEGY_ID: ControlExecutor,
	DeploySummonExecutor.STRATEGY_ID: DeploySummonExecutor,
	ChainedProjectileExecutor.STRATEGY_ID: ChainedProjectileExecutor,
}

const PRIMITIVE_PARAMETER_CONTRACTS := {
	"aim_context": {
		"max_range": {"type": "number", "minimum": 0.001},
		"target_mode": {"type": "string", "values": ["host_aim", "nearest_target"]},
	},
	"priority_target_selector": {
		"center": {"type": "string", "values": ["source", "target"]},
		"radius": {"type": "number", "minimum": 0.0},
		"limit": {"type": "integer", "minimum": 0},
		"priority": {
			"type": "string",
			"values": ["nearest", "aimed", "highest_hp", "marked", "densest_cluster"],
		},
		"hint": {"type": "dictionary"},
	},
	"line_pierce_geometry": {
		"start": {"type": "string", "values": ["source", "target"]},
		"direction": {"type": "string", "values": ["aim", "source_to_target"]},
		"length": {"type": "number", "minimum": 0.0},
		"half_width": {"type": "number", "minimum": 0.0},
		"limit": {"type": "integer", "minimum": 0},
	},
	"pattern_geometry": {
		"center": {"type": "string", "values": ["source", "target"]},
		"pattern": {
			"type": "string",
			"values": ["ring", "grid", "radial", "polygon", "seeded_annulus"],
		},
		"params": {"type": "dictionary"},
		"hit_radius": {"type": "number", "minimum": 0.0},
		"target_limit": {"type": "integer", "minimum": 0},
	},
	COMPOSITION_ID: {"steps": {"type": "array"}},
}

## The one parameter admission contract for every live executor family.
##
## Executors used to repair incomplete declaration data through their typed
## accessors. Ready profiles now enter through this contract instead, so runtime
## and in-memory proof share the exact same fail-closed semantics.
const PARAMETER_CONTRACTS := {
	"aimed_sequence": {
		"radius": {"type": "number", "minimum": 0.0},
		"damage": {"type": "number", "minimum": 0.0},
		"shot_count": {"type": "integer", "minimum": 1},
		"interval": {"type": "number", "minimum": 0.01},
	},
	"burst": {
		"radius": {"type": "number", "minimum": 0.0},
		"damage": {"type": "number", "minimum": 0.0},
		"target_limit": {"type": "integer", "minimum": 0},
	},
	"chained_projectile": {
		"radius": {"type": "number", "minimum": 0.0},
		"damage": {"type": "number", "minimum": 0.0},
		"jumps": {"type": "integer", "minimum": 1},
		"hop_delay": {"type": "number", "minimum": 0.01},
		"falloff": {"type": "number", "minimum": 0.0, "maximum": 1.0},
	},
	"control": {
		"radius": {"type": "number", "minimum": 0.0},
		"damage": {"type": "number", "minimum": 0.0},
		"target_limit": {"type": "integer", "minimum": 0},
		"knockback": {"type": "number", "minimum": 0.0},
		"status_id": {"type": "string"},
		"status": {"type": "dictionary"},
	},
	"deploy_summon": {
		"scene": {"type": "string"},
		"count": {"type": "integer", "minimum": 1},
		"spawn_radius": {"type": "number", "minimum": 0.0},
		"lifetime": {"type": "number", "minimum": 0.1},
		"damage": {"type": "number", "minimum": 0.0},
		"properties": {"type": "dictionary"},
	},
	"status_zone": {
		"radius": {"type": "number", "minimum": 0.0},
		"damage": {"type": "number", "minimum": 0.0},
		"duration": {"type": "number", "minimum": 0.1},
		"interval": {"type": "number", "minimum": 0.05},
		"follow_host": {"type": "bool"},
		"status_id": {"type": "string"},
		"status": {"type": "dictionary"},
	},
	"timed_modifier": {
		"duration": {"type": "number", "minimum": 0.1},
		"radius": {"type": "number", "minimum": 0.0},
		"modifiers": {"type": "dictionary"},
	},
}


static func has_strategy(strategy_id: String) -> bool:
	return EXECUTORS.has(strategy_id) or strategy_id == COMPOSITION_ID


static func strategy_ids() -> Array[String]:
	var ids: Array[String] = []
	for raw_id in EXECUTORS.keys():
		ids.append(str(raw_id))
	ids.sort()
	return ids


static func primitive_ids() -> Array[String]:
	var ids: Array[String] = []
	for raw_id in PRIMITIVE_PARAMETER_CONTRACTS.keys():
		ids.append(str(raw_id))
	ids.sort()
	return ids


static func parameter_keys(strategy_id: String) -> Array[String]:
	var keys: Array[String] = []
	var contracts := PARAMETER_CONTRACTS
	if strategy_id == COMPOSITION_ID:
		contracts = PRIMITIVE_PARAMETER_CONTRACTS
	if not contracts.has(strategy_id):
		return keys
	for raw_key in (contracts[strategy_id] as Dictionary).keys():
		keys.append(str(raw_key))
	keys.sort()
	return keys


static func validate_params(strategy_id: String, raw_params) -> Array[String]:
	return normalize_params(strategy_id, raw_params)["errors"] as Array[String]


static func validate_primitive_params(primitive_id: String, raw_params) -> Array[String]:
	return normalize_primitive_params(primitive_id, raw_params)["errors"] as Array[String]


## Returns a deep, deterministic parameter dictionary or stable error codes.
## Numeric executor coefficients canonicalize to float; count fields remain
## integers so no executor can silently truncate a declaration.
static func normalize_params(strategy_id: String, raw_params) -> Dictionary:
	if strategy_id == COMPOSITION_ID:
		return normalize_primitive_params(strategy_id, raw_params)
	if not EXECUTORS.has(strategy_id) or not PARAMETER_CONTRACTS.has(strategy_id):
		return {"params": {}, "errors": ["executor_family.unknown: %s" % strategy_id]}
	return _normalize_contract(raw_params, PARAMETER_CONTRACTS[strategy_id] as Dictionary)


static func normalize_primitive_params(primitive_id: String, raw_params) -> Dictionary:
	if not PRIMITIVE_PARAMETER_CONTRACTS.has(primitive_id):
		return {"params": {}, "errors": ["executor_primitive.unknown: %s" % primitive_id]}
	if primitive_id == COMPOSITION_ID:
		return _normalize_composition(raw_params)
	var result := _normalize_contract(
		raw_params, PRIMITIVE_PARAMETER_CONTRACTS[primitive_id] as Dictionary
	)
	var errors := result["errors"] as Array[String]
	if errors.is_empty() and primitive_id == "priority_target_selector":
		(result["params"] as Dictionary)["hint"] = _normalize_priority_hint(
			result["params"] as Dictionary, errors
		)
	elif errors.is_empty() and primitive_id == "pattern_geometry":
		(result["params"] as Dictionary)["params"] = _normalize_pattern_params(
			result["params"] as Dictionary, errors
		)
	if not errors.is_empty():
		return {"params": {}, "errors": errors}
	return result


static func _normalize_contract(raw_params, contract: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	if not raw_params is Dictionary:
		return {"params": {}, "errors": ["executor_params.type: params"]}

	var params := raw_params as Dictionary
	for raw_key in params.keys():
		if not raw_key is String:
			errors.append("executor_params.key_type: %s" % str(raw_key))
			continue
		var key := raw_key as String
		if not contract.has(key):
			errors.append("executor_params.unknown: %s" % key)
	var keys := _sorted_keys(contract)
	for key in keys:
		if not params.has(key):
			errors.append("executor_params.missing: %s" % key)
	if not errors.is_empty():
		return {"params": {}, "errors": errors}

	var normalized := {}
	for key in keys:
		var specification := contract[key] as Dictionary
		var value = _normalize_value(params[key], key, specification, errors)
		if str(specification["type"]) == "dictionary" and value is Dictionary:
			if key == "status":
				(value as Dictionary).erase("dot_damage")
			elif key == "modifiers":
				value = _normalize_modifiers(value as Dictionary, errors)
		if value != null:
			normalized[key] = value
	if not errors.is_empty():
		return {"params": {}, "errors": errors}
	return {"params": normalized, "errors": errors}


static func canonical_parameter_signature(strategy_id: String, raw_params) -> String:
	var result := normalize_params(strategy_id, raw_params)
	if not (result["errors"] as Array).is_empty():
		return ""
	return JSON.stringify(result["params"], "", true)


static func canonical_primitive_signature(primitive_id: String, raw_params) -> String:
	var result := normalize_primitive_params(primitive_id, raw_params)
	if not (result["errors"] as Array).is_empty():
		return ""
	return JSON.stringify(result["params"], "", true)


## Returns how long the activation stays live, which the controller only uses
## for families that schedule nothing themselves; 0.0 means it finished
## instantly. A family that creates its own tween expresses the whole cast
## length in that tween, and the controller completes the cast right after it.
static func execute(strategy_id: String, activation: Activation) -> float:
	if strategy_id == COMPOSITION_ID:
		return _execute_composition(activation)
	if not EXECUTORS.has(strategy_id):
		return 0.0
	return float(EXECUTORS[strategy_id].execute(activation))


static func execute_primitive(
	primitive_id: String, activation: Activation, raw_params
) -> bool:
	if primitive_id == COMPOSITION_ID:
		return false
	var normalized := normalize_primitive_params(primitive_id, raw_params)
	if not (normalized["errors"] as Array).is_empty():
		return false
	return TargetingPrimitives.execute(
		primitive_id, activation, normalized["params"] as Dictionary
	)


static func _normalize_value(value, key: String, specification: Dictionary, errors: Array[String]):
	match str(specification["type"]):
		"number":
			if not _is_number(value):
				errors.append("executor_params.type: %s" % key)
				return null
			var number := float(value)
			if not is_finite(number):
				errors.append("executor_params.non_finite: %s" % key)
				return null
			if _outside_range(number, specification):
				errors.append("executor_params.range: %s" % key)
				return null
			return number
		"integer":
			if not (value is int) or value is bool:
				errors.append("executor_params.integer: %s" % key)
				return null
			if _outside_range(float(value), specification):
				errors.append("executor_params.range: %s" % key)
				return null
			return value
		"string":
			if not value is String:
				errors.append("executor_params.type: %s" % key)
				return null
			if specification.has("values") and not (specification["values"] as Array).has(value):
				errors.append("executor_params.range: %s" % key)
				return null
			return value
		"bool":
			if not value is bool:
				errors.append("executor_params.type: %s" % key)
				return null
			return value
		"dictionary":
			if not value is Dictionary:
				errors.append("executor_params.type: %s" % key)
				return null
			return _normalize_nested(value as Dictionary, key, errors)
		"array":
			if not value is Array:
				errors.append("executor_params.type: %s" % key)
				return null
			var normalized: Array = []
			for index in (value as Array).size():
				var nested = _normalize_nested_value(
					(value as Array)[index], "%s[%d]" % [key, index], errors
				)
				if nested != null:
					normalized.append(nested)
			return normalized
	errors.append("executor_params.contract_unknown: %s" % key)
	return null


static func _normalize_nested(value: Dictionary, path: String, errors: Array[String]) -> Dictionary:
	var normalized := {}
	var keys: Array[String] = []
	for raw_key in value.keys():
		if not raw_key is String:
			errors.append("executor_params.nested_key_type: %s" % path)
			continue
		keys.append(raw_key as String)
	keys.sort()
	for key in keys:
		var nested = _normalize_nested_value(value[key], "%s.%s" % [path, key], errors)
		if nested != null:
			normalized[key] = nested
	return normalized


static func _normalize_nested_value(value, path: String, errors: Array[String]):
	if value is bool or value is String or value is int:
		return value
	if value is float:
		if not is_finite(value):
			errors.append("executor_params.non_finite: %s" % path)
			return null
		return value
	if value is Dictionary:
		return _normalize_nested(value as Dictionary, path, errors)
	if value is Array:
		var normalized: Array = []
		for index in (value as Array).size():
			var nested = _normalize_nested_value(
				(value as Array)[index], "%s[%d]" % [path, index], errors
			)
			if nested != null:
				normalized.append(nested)
		return normalized
	errors.append("executor_params.nested_type: %s" % path)
	return null


static func _normalize_modifiers(modifiers: Dictionary, errors: Array[String]) -> Dictionary:
	var normalized := {}
	for key in _sorted_keys(modifiers):
		if key.strip_edges().is_empty():
			errors.append("executor_params.range: modifiers.%s" % key)
			continue
		var entry = modifiers[key]
		if not entry is Dictionary:
			errors.append("executor_params.type: modifiers.%s" % key)
			continue
		var modifier := entry as Dictionary
		for field in modifier.keys():
			if field != "value" and field != "op":
				errors.append("executor_params.unknown: modifiers.%s.%s" % [key, field])
		for required in ["value", "op"]:
			if not modifier.has(required):
				errors.append("executor_params.missing: modifiers.%s.%s" % [key, required])
		if not modifier.has("value") or not modifier.has("op"):
			continue
		if not _is_number(modifier["value"]):
			errors.append("executor_params.type: modifiers.%s.value" % key)
			continue
		var amount := float(modifier["value"])
		if not is_finite(amount):
			errors.append("executor_params.non_finite: modifiers.%s.value" % key)
			continue
		if not (modifier["op"] is String):
			errors.append("executor_params.type: modifiers.%s.op" % key)
			continue
		var operation := modifier["op"] as String
		if operation != Activation.OP_ADD and operation != Activation.OP_MULTIPLY:
			errors.append("executor_params.range: modifiers.%s.op" % key)
			continue
		if operation == Activation.OP_MULTIPLY and is_zero_approx(amount):
			errors.append("executor_params.range: modifiers.%s.value" % key)
			continue
		normalized[key] = {"value": amount, "op": operation}
	return normalized


static func _sorted_keys(value: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for raw_key in value.keys():
		if raw_key is String:
			keys.append(raw_key as String)
	keys.sort()
	return keys


static func _is_number(value) -> bool:
	return (value is int or value is float) and not value is bool


static func _outside_range(value: float, specification: Dictionary) -> bool:
	return (specification.has("minimum") and value < float(specification["minimum"])) \
		or (specification.has("maximum") and value > float(specification["maximum"]))


static func _normalize_priority_hint(params: Dictionary, errors: Array[String]) -> Dictionary:
	var priority := str(params["priority"])
	var hint := params["hint"] as Dictionary
	if priority == "densest_cluster":
		return _normalize_exact_dictionary(
			hint,
			{"cluster_radius": {"type": "number", "minimum": 0.001}},
			"hint",
			errors
		)
	if priority == "marked":
		var normalized := _normalize_exact_dictionary(
			hint, {"group": {"type": "string"}}, "hint", errors
		)
		if str(normalized.get("group", "")).is_empty():
			errors.append("executor_params.range: hint.group")
		return normalized
	if not hint.is_empty():
		errors.append("executor_params.unknown: hint")
	return {}


static func _normalize_pattern_params(params: Dictionary, errors: Array[String]) -> Dictionary:
	var common := {
		"count": {"type": "integer", "minimum": 1},
		"radius": {"type": "number", "minimum": 0.0},
		"rotation_degrees": {"type": "number"},
		"arc_degrees": {"type": "number", "minimum": 0.001, "maximum": 360.0},
	}
	var contract: Dictionary
	match str(params["pattern"]):
		"ring", "radial", "polygon":
			contract = common
		"grid":
			contract = {
				"rows": {"type": "integer", "minimum": 1},
				"columns": {"type": "integer", "minimum": 1},
				"spacing": {"type": "number", "minimum": 0.0},
				"rotation_degrees": {"type": "number"},
			}
		"seeded_annulus":
			contract = {
				"count": {"type": "integer", "minimum": 1},
				"inner_radius": {"type": "number", "minimum": 0.0},
				"outer_radius": {"type": "number", "minimum": 0.0},
				"seed": {"type": "integer"},
			}
	var normalized := _normalize_exact_dictionary(
		params["params"] as Dictionary, contract, "params", errors
	)
	if str(params["pattern"]) == "seeded_annulus" \
			and float(normalized.get("outer_radius", 0.0)) < float(normalized.get("inner_radius", 0.0)):
		errors.append("executor_params.range: params.outer_radius")
	return normalized


static func _normalize_exact_dictionary(
	value: Dictionary,
	contract: Dictionary,
	path: String,
	errors: Array[String]
) -> Dictionary:
	for raw_key in value.keys():
		if not raw_key is String or not contract.has(raw_key):
			errors.append("executor_params.unknown: %s.%s" % [path, str(raw_key)])
	for key in _sorted_keys(contract):
		if not value.has(key):
			errors.append("executor_params.missing: %s.%s" % [path, key])
	if not errors.is_empty():
		return {}
	var normalized := {}
	for key in _sorted_keys(contract):
		var parsed = _normalize_value(value[key], "%s.%s" % [path, key], contract[key], errors)
		if parsed != null:
			normalized[key] = parsed
	return normalized


static func _normalize_composition(raw_params) -> Dictionary:
	if not raw_params is Dictionary:
		return {"params": {}, "errors": ["executor_params.type: params"]}
	var params := raw_params as Dictionary
	var errors: Array[String] = []
	for raw_key in params.keys():
		if raw_key != "steps":
			errors.append("executor_params.unknown: %s" % str(raw_key))
	if not params.has("steps"):
		errors.append("executor_params.missing: steps")
	elif not params["steps"] is Array:
		errors.append("executor_params.type: steps")
	elif (params["steps"] as Array).is_empty():
		errors.append("executor_params.range: steps")
	if not errors.is_empty():
		return {"params": {}, "errors": errors}

	var normalized_steps: Array = []
	var previous_at := 0.0
	for index in (params["steps"] as Array).size():
		var raw_step = (params["steps"] as Array)[index]
		var path := "steps[%d]" % index
		if not raw_step is Dictionary:
			errors.append("executor_step.type: %s" % path)
			continue
		var step := raw_step as Dictionary
		for raw_key in step.keys():
			if not ["at", "primitive_id", "family", "params"].has(raw_key):
				errors.append("executor_step.unknown_key: %s.%s" % [path, raw_key])
		for required in ["at", "params"]:
			if not step.has(required):
				errors.append("executor_step.missing: %s.%s" % [path, required])
		var has_primitive := step.has("primitive_id")
		var has_family := step.has("family")
		if has_primitive == has_family:
			errors.append("executor_step.kind: %s" % path)
			continue
		if step.has("params") and not step["params"] is Dictionary:
			errors.append("executor_step.type: %s.params" % path)
		if not step.has("at") or not step.has("params") or not step["params"] is Dictionary:
			continue
		if not _is_number(step["at"]) or not is_finite(float(step["at"])):
			errors.append("executor_step.type: %s.at" % path)
			continue
		var at := float(step["at"])
		if at < 0.0 or at < previous_at:
			errors.append("executor_step.order: %s.at" % path)
		previous_at = at
		var normalized := {"at": at}
		var nested: Dictionary
		if has_primitive:
			var primitive_id := str(step["primitive_id"])
			if primitive_id == COMPOSITION_ID:
				errors.append("executor_step.recursive: %s" % path)
				continue
			if not PRIMITIVE_PARAMETER_CONTRACTS.has(primitive_id):
				errors.append("executor_step.unknown: %s.%s" % [path, primitive_id])
				continue
			nested = normalize_primitive_params(primitive_id, step["params"])
			normalized["primitive_id"] = primitive_id
		else:
			var family := str(step["family"])
			if not EXECUTORS.has(family):
				errors.append("executor_step.unknown: %s.%s" % [path, family])
				continue
			nested = normalize_params(family, step["params"])
			normalized["family"] = family
		for nested_error in nested["errors"] as Array[String]:
			errors.append("executor_step.params: %s.%s" % [path, nested_error])
		if (nested["errors"] as Array).is_empty():
			normalized["params"] = nested["params"]
			normalized_steps.append(normalized)
	if not errors.is_empty():
		return {"params": {}, "errors": errors}
	return {"params": {"steps": normalized_steps}, "errors": errors}


static func _execute_composition(activation: Activation) -> float:
	var steps := activation.params.get("steps", []) as Array
	var total_duration := 0.0
	for step in steps:
		total_duration = maxf(
			total_duration,
			float(step["at"]) + _family_duration(str(step.get("family", "")), step["params"])
		)
	for step in steps:
		if float(step["at"]) > 0.0:
			break
		_run_composition_step(activation, step)
		if activation.composition_aborted():
			return 0.0
	if total_duration <= 0.0:
		return 0.0

	var tween := activation.track_tween()
	if tween == null:
		return 0.0
	var cursor := 0.0
	for step in steps:
		var at := float(step["at"])
		if at <= 0.0:
			continue
		tween.tween_interval(at - cursor)
		tween.tween_callback(func() -> void:
			if not activation.composition_aborted():
				_run_composition_step(activation, step)
		)
		cursor = at
	tween.tween_interval(maxf(total_duration - cursor, 0.0) + COMPOSITION_TAIL_SECONDS)
	return total_duration + COMPOSITION_TAIL_SECONDS


static func _run_composition_step(activation: Activation, step: Dictionary) -> void:
	var step_id := str(step.get("primitive_id", step.get("family", "")))
	activation.composition_step(step_id)
	if step.has("primitive_id"):
		if not TargetingPrimitives.execute(step_id, activation, step["params"]):
			activation.abort_composition()
		return
	# Executor families read their admitted dictionary from activation.params.
	# Swap only for the synchronous setup call; scheduled callbacks already close
	# over the values they need, and the shared ledger/context never changes.
	var composition_params := activation.params
	activation.params = step["params"]
	EXECUTORS[step_id].execute(activation)
	activation.params = composition_params


static func _family_duration(family: String, params: Dictionary) -> float:
	match family:
		"aimed_sequence":
			return float(params["shot_count"]) * float(params["interval"])
		"chained_projectile":
			return float(params["jumps"]) * float(params["hop_delay"])
		"deploy_summon":
			return float(params["lifetime"])
		"status_zone":
			return float(maxi(int(floor(float(params["duration"]) / float(params["interval"]))), 1)) \
				* float(params["interval"])
		"timed_modifier":
			return float(params["duration"])
	return 0.0
