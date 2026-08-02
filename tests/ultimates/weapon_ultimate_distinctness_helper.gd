extends RefCounted

## Proves class-local executable selection without changing the shipped catalog.
##
## Class tests supply the intended executor family per weapon. Optional params
## override the params already written into that class's declared profiles.
## All ready/bound state exists only in the copied dictionaries below.

const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")

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
	var normalized_params := {}
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
		if family.is_empty():
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
		var validation := Library.normalize_params(family, params)
		for contract_error in validation["errors"]:
			errors.append("%s %s" % [key, contract_error])
		if (validation["errors"] as Array).is_empty():
			normalized_params[weapon_id] = validation["params"]
	if not errors.is_empty():
		return {"contracts": resolved, "errors": errors}

	for weapon_id in weapon_ids:
		var patch: Dictionary = executor_contracts[weapon_id]
		var family := str(patch["executor_family"])
		var params: Dictionary = normalized_params[weapon_id]
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
		executor["params"] = params.duplicate(true)
		profiles[key] = profile
	if not errors.is_empty():
		return {"contracts": resolved, "errors": errors}

	var signatures := {}
	var executable_pairs := {}
	for weapon_id in weapon_ids:
		executable_pairs[Resolver.profile_key(class_id, weapon_id)] = true
	for weapon_id in weapon_ids:
		var profile := Resolver.resolve_executable(
			profiles, pairs, class_id, weapon_id, {}, true, executable_pairs
		)
		if profile.is_empty() or str(profile.get("weapon_id", "")) != weapon_id:
			errors.append("%s/%s did not resolve its injected ready profile" % [class_id, weapon_id])
			continue
		var executor: Dictionary = profile.get("executor", {})
		var signature := "%s:%s" % [
			str(executor.get("strategy_id", "")),
			Library.canonical_parameter_signature(
				str(executor.get("strategy_id", "")), executor.get("params", {})
			),
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
	return Library.parameter_keys(family)


static func validate_executor_contract(family: String, params: Dictionary) -> Array[String]:
	return Library.validate_params(family, params)


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
