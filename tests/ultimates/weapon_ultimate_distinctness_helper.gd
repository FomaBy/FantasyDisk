extends RefCounted

## Proves class-local executable selection without changing the shipped catalog.
##
## Class tests supply the intended executor family per weapon. Optional params
## override the params already written into that class's declared profiles.
## All ready/bound state exists only in the copied dictionaries below.

const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")

## Mirrors the typed accessors used by the live executor classes. This stays in
## test code because the shipped library intentionally owns strategy lookup only.
const PARAMETER_CONTRACTS := {
	"aimed_sequence": {
		"radius": "number", "damage": "number", "shot_count": "number", "interval": "number",
	},
	"burst": {"radius": "number", "damage": "number", "target_limit": "number"},
	"chained_projectile": {
		"radius": "number", "damage": "number", "jumps": "number", "hop_delay": "number",
		"falloff": "number",
	},
	"control": {
		"radius": "number", "damage": "number", "target_limit": "number", "knockback": "number",
		"status_id": "string", "status": "dictionary",
	},
	"deploy_summon": {
		"scene": "string", "count": "number", "spawn_radius": "number", "lifetime": "number",
		"damage": "number", "properties": "dictionary",
	},
	"status_zone": {
		"radius": "number", "damage": "number", "duration": "number", "interval": "number",
		"follow_host": "bool", "status_id": "string", "status": "dictionary",
	},
	"timed_modifier": {"duration": "number", "radius": "number", "modifiers": "dictionary"},
}


static func resolve_class_contracts(
	registry,
	audit: Dictionary,
	class_id: String,
	executor_contracts: Dictionary
) -> Dictionary:
	var errors: Array[String] = []
	var resolved := {}
	var weapon_ids: Array[String] = registry.weapon_ids(class_id)
	if weapon_ids.size() != 3:
		errors.append("%s must have exactly three canonical weapons" % class_id)
		return {"contracts": resolved, "errors": errors}

	for raw_weapon_id in executor_contracts.keys():
		if not weapon_ids.has(str(raw_weapon_id)):
			errors.append("%s/%s is not a canonical class weapon" % [class_id, raw_weapon_id])
	for weapon_id in weapon_ids:
		if not executor_contracts.has(weapon_id):
			errors.append("%s/%s is missing an executor contract" % [class_id, weapon_id])
	if not errors.is_empty():
		return {"contracts": resolved, "errors": errors}

	var profiles: Dictionary = registry.profiles_for_tests()
	var pairs: Dictionary = registry.canonical_pairs_for_tests()
	for weapon_id in weapon_ids:
		var patch = executor_contracts[weapon_id]
		if not patch is Dictionary:
			errors.append("%s/%s executor contract must be a Dictionary" % [class_id, weapon_id])
			continue
		var family := str((patch as Dictionary).get("executor_family", ""))
		var params = (patch as Dictionary).get("params", {})
		if family.is_empty() or not params is Dictionary:
			errors.append("%s/%s must declare executor_family and params" % [class_id, weapon_id])
			continue
		var key := Resolver.profile_key(class_id, weapon_id)
		var audit_family := _audit_family(audit, key)
		if audit_family.is_empty():
			errors.append("%s executor_family.audit_missing" % key)
			continue
		if family != audit_family:
			errors.append(
				"%s executor_family.audit_mismatch: expected %s, got %s"
				% [key, audit_family, family]
			)
		for contract_error in validate_executor_contract(family, params as Dictionary):
			errors.append("%s %s" % [key, contract_error])
	if not errors.is_empty():
		return {"contracts": resolved, "errors": errors}

	for weapon_id in weapon_ids:
		var patch: Dictionary = executor_contracts[weapon_id]
		var family := str(patch["executor_family"])
		var params: Dictionary = patch["params"]
		var key := Resolver.profile_key(class_id, weapon_id)
		var profile: Dictionary = (profiles.get(key, {}) as Dictionary).duplicate(true)
		if profile.is_empty():
			errors.append("%s/%s catalog profile is missing" % [class_id, weapon_id])
			continue
		profile["implementation_state"] = "ready"
		profile["total_boss_cap"] = 0.25
		for binding_field in ["targeting", "charge", "cleanup_policy"]:
			var binding: Dictionary = profile[binding_field]
			binding["strategy_id"] = "test_bound_%s" % binding_field
		var executor: Dictionary = profile["executor"]
		executor["strategy_id"] = family
		if not params.is_empty():
			executor["params"] = params.duplicate(true)
		profiles[key] = profile
	if not errors.is_empty():
		return {"contracts": resolved, "errors": errors}

	var signatures := {}
	for weapon_id in weapon_ids:
		var profile := Resolver.resolve_executable(profiles, pairs, class_id, weapon_id, {})
		if profile.is_empty() or str(profile.get("weapon_id", "")) != weapon_id:
			errors.append("%s/%s did not resolve its injected ready profile" % [class_id, weapon_id])
			continue
		var executor: Dictionary = profile.get("executor", {})
		var signature := "%s:%s" % [
			str(executor.get("strategy_id", "")),
			JSON.stringify(executor.get("params", {})),
		]
		if signatures.has(signature):
			errors.append(
				"%s/%s aliases the executable contract of %s"
				% [class_id, weapon_id, signatures[signature]]
			)
			continue
		signatures[signature] = weapon_id
		resolved[weapon_id] = profile
	return {"contracts": resolved, "errors": errors}


static func parameter_keys(family: String) -> Array[String]:
	var keys: Array[String] = []
	if not Library.has_strategy(family) or not PARAMETER_CONTRACTS.has(family):
		return keys
	for raw_key in (PARAMETER_CONTRACTS[family] as Dictionary).keys():
		keys.append(str(raw_key))
	keys.sort()
	return keys


static func validate_executor_contract(family: String, params: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not Library.has_strategy(family):
		return ["executor_family.unknown: %s" % family]
	if not PARAMETER_CONTRACTS.has(family):
		return ["executor_params.contract_unknown: %s" % family]
	var contract: Dictionary = PARAMETER_CONTRACTS[family]
	for raw_key in params.keys():
		var key := str(raw_key)
		if not contract.has(key):
			errors.append("executor_params.unknown: %s" % key)
		elif not _matches_shape(params[raw_key], str(contract[key])):
			errors.append("executor_params.invalid: %s" % key)
	return errors


static func _audit_family(audit: Dictionary, key: String) -> String:
	var profiles = audit.get("profiles", [])
	if not profiles is Array:
		return ""
	for raw_entry in profiles:
		if not raw_entry is Dictionary:
			continue
		var entry := raw_entry as Dictionary
		if Resolver.profile_key(str(entry.get("class_id", "")), str(entry.get("weapon_id", ""))) == key:
			return str(entry.get("executor_family", ""))
	return ""


static func _matches_shape(value, shape: String) -> bool:
	match shape:
		"number":
			return (value is int or value is float) and not value is bool
		"string":
			return value is String
		"dictionary":
			return value is Dictionary
		"bool":
			return value is bool
	return false
