extends RefCounted

## Proves class-local executable selection without changing the shipped catalog.
##
## Class tests supply the intended executor family per weapon. Optional params
## override the params already written into that class's declared profiles.
## All ready/bound state exists only in the copied dictionaries below.

const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")


static func resolve_class_contracts(
	registry,
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
		if not (params as Dictionary).is_empty():
			executor["params"] = (params as Dictionary).duplicate(true)
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
