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

const EXECUTORS := {
	BurstExecutor.STRATEGY_ID: BurstExecutor,
	AimedSequenceExecutor.STRATEGY_ID: AimedSequenceExecutor,
	TimedModifierExecutor.STRATEGY_ID: TimedModifierExecutor,
	StatusZoneExecutor.STRATEGY_ID: StatusZoneExecutor,
	ControlExecutor.STRATEGY_ID: ControlExecutor,
	DeploySummonExecutor.STRATEGY_ID: DeploySummonExecutor,
	ChainedProjectileExecutor.STRATEGY_ID: ChainedProjectileExecutor,
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
	return EXECUTORS.has(strategy_id)


static func strategy_ids() -> Array[String]:
	var ids: Array[String] = []
	for raw_id in EXECUTORS.keys():
		ids.append(str(raw_id))
	ids.sort()
	return ids


static func parameter_keys(strategy_id: String) -> Array[String]:
	var keys: Array[String] = []
	if not PARAMETER_CONTRACTS.has(strategy_id):
		return keys
	for raw_key in (PARAMETER_CONTRACTS[strategy_id] as Dictionary).keys():
		keys.append(str(raw_key))
	keys.sort()
	return keys


static func validate_params(strategy_id: String, raw_params) -> Array[String]:
	return normalize_params(strategy_id, raw_params)["errors"] as Array[String]


## Returns a deep, deterministic parameter dictionary or stable error codes.
## Numeric executor coefficients canonicalize to float; count fields remain
## integers so no executor can silently truncate a declaration.
static func normalize_params(strategy_id: String, raw_params) -> Dictionary:
	var errors: Array[String] = []
	if not has_strategy(strategy_id) or not PARAMETER_CONTRACTS.has(strategy_id):
		return {"params": {}, "errors": ["executor_family.unknown: %s" % strategy_id]}
	if not raw_params is Dictionary:
		return {"params": {}, "errors": ["executor_params.type: params"]}

	var params := raw_params as Dictionary
	var contract := PARAMETER_CONTRACTS[strategy_id] as Dictionary
	for raw_key in params.keys():
		if not raw_key is String:
			errors.append("executor_params.key_type: %s" % str(raw_key))
			continue
		var key := raw_key as String
		if not contract.has(key):
			errors.append("executor_params.unknown: %s" % key)
	for key in parameter_keys(strategy_id):
		if not params.has(key):
			errors.append("executor_params.missing: %s" % key)
	if not errors.is_empty():
		return {"params": {}, "errors": errors}

	var normalized := {}
	for key in parameter_keys(strategy_id):
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


## Returns how long the activation stays live, which the controller only uses
## for families that schedule nothing themselves; 0.0 means it finished
## instantly. A family that creates its own tween expresses the whole cast
## length in that tween, and the controller completes the cast right after it.
static func execute(strategy_id: String, activation: Activation) -> float:
	if not EXECUTORS.has(strategy_id):
		return 0.0
	return float(EXECUTORS[strategy_id].execute(activation))


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
