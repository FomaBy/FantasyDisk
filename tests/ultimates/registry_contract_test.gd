extends SceneTree

## Focused contract test for FAN-1456.
##
## Run:
## Godot --headless --path . \
##   --script res://tests/ultimates/registry_contract_test.gd

const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")


func _initialize() -> void:
	var errors: Array[String] = []
	var registry = Registry.new(PD.WEAPONS_BY_CLASS)

	_expect(
		registry.is_valid(),
		"registry must be valid: %s" % str(registry.validation_errors()),
		errors
	)
	_expect(registry.validation_errors().is_empty(), "validation errors must be empty", errors)
	_expect(registry.class_ids() == _expected_class_ids(), "class order must match canonical inventory", errors)
	_expect(registry.profile_count() == 51, "catalog must contain exactly 51 profiles", errors)
	_expect(registry.package_validation_errors().is_empty(),
		"empty production package roots must not report errors", errors)
	_expect(registry.package_pair_keys().is_empty(),
		"no production package may become executable in the foundation change", errors)

	var selected_checks := 0
	var sibling_negative_controls := 0
	for raw_class_id in PD.WEAPONS_BY_CLASS.keys():
		var class_id := str(raw_class_id)
		var canonical_weapons: Dictionary = PD.WEAPONS_BY_CLASS[class_id]
		var weapon_ids: Array[String] = []
		for raw_weapon_id in canonical_weapons.keys():
			weapon_ids.append(str(raw_weapon_id))
		_expect(
			registry.weapon_ids(class_id) == weapon_ids,
			"%s weapon order must match canonical inventory" % class_id,
			errors
		)
		for weapon_id in weapon_ids:
			var selected: Dictionary = registry.catalog_profile_for(class_id, weapon_id)
			_expect(not selected.is_empty(), "%s/%s profile must resolve" % [class_id, weapon_id], errors)
			_expect(str(selected.get("class_id", "")) == class_id, "selected class must match", errors)
			_expect(str(selected.get("weapon_id", "")) == weapon_id, "selected weapon must match", errors)
			_expect(str(selected.get("implementation_state", "")) == "declared", "v1 profile must be declared", errors)
			selected_checks += 1

			var selected_identity: Dictionary = selected.get("identity", {})
			var selected_presentation: Dictionary = selected.get("presentation", {})
			for sibling_weapon_id in weapon_ids:
				if sibling_weapon_id == weapon_id:
					continue
				var sibling: Dictionary = registry.catalog_profile_for(class_id, sibling_weapon_id)
				var sibling_identity: Dictionary = sibling.get("identity", {})
				var sibling_presentation: Dictionary = sibling.get("presentation", {})
				_expect(
					str(sibling_identity.get("profile_id", "")) != str(selected_identity.get("profile_id", "")),
					"%s sibling profile IDs must not alias" % class_id,
					errors
				)
				_expect(
					str(sibling_identity.get("title_id", "")) != str(selected_identity.get("title_id", "")),
					"%s sibling title IDs must not alias" % class_id,
					errors
				)
				_expect(
					str(sibling_identity.get("mechanic_id", "")) != str(selected_identity.get("mechanic_id", "")),
					"%s sibling mechanic IDs must not alias" % class_id,
					errors
				)
				_expect(
					str(sibling_presentation.get("presentation_id", ""))
					!= str(selected_presentation.get("presentation_id", "")),
					"%s sibling presentation IDs must not alias" % class_id,
					errors
				)
				sibling_negative_controls += 1

			var legacy: Dictionary = PD.ultimate_config(class_id)
			_expect(
				registry.resolution_source(class_id, weapon_id)
				== Resolver.SOURCE_LEGACY_CLASS_FALLBACK,
				"%s/%s declared profile must select legacy fallback" % [class_id, weapon_id],
				errors
			)
			var executable: Dictionary = registry.resolve_executable(class_id, weapon_id, legacy)
			_expect(
				executable == legacy,
				"%s/%s fallback must preserve exact current class ultimate" % [class_id, weapon_id],
				errors
			)
			executable["__mutation_probe"] = true
			_expect(
				not registry.resolve_executable(class_id, weapon_id, legacy).has("__mutation_probe"),
				"fallback result must be a deep copy",
				errors
			)

	_expect(selected_checks == 51, "resolver must exercise all 51 selected weapon pairs", errors)
	_expect(
		sibling_negative_controls == 102,
		"resolver must exercise both sibling negative controls for all 51 pairs",
		errors
	)
	_expect(
		registry.resolution_source("berserk", "__unknown_weapon__")
			== Resolver.SOURCE_INVALID_PAIR,
		"unknown weapon pair must fail closed",
		errors
	)
	_expect(
		registry.resolve_executable(
			"berserk",
			"__unknown_weapon__",
			PD.ultimate_config("berserk")
		).is_empty(),
		"unknown weapon pair must not fall back",
		errors
	)
	_expect(
		registry.resolution_source("berserk", "sword", false) == Resolver.SOURCE_UNAVAILABLE,
		"migration gate must be able to disable legacy fallback",
		errors
	)
	_expect(
		registry.resolve_executable("berserk", "sword", PD.ultimate_config("berserk"), false).is_empty(),
		"disabled fallback must return no executable contract",
		errors
	)

	_test_ready_profile_is_weapon_local(registry, errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Weapon ultimate registry contract: %s" % error)
		push_error("Weapon ultimate registry contract test: %d errors." % errors.size())
		quit(1)
		return
	print(
		"Weapon ultimate registry contract passed "
		+ "(17 classes, 51 selections, 102 sibling negative controls, legacy fallback preserved)."
	)
	quit(0)


func _test_ready_profile_is_weapon_local(registry, errors: Array[String]) -> void:
	var profiles: Dictionary = registry.profiles_for_tests()
	var pairs: Dictionary = registry.canonical_pairs_for_tests()
	var ready_key := Resolver.profile_key("berserk", "sword")
	var ready_profile: Dictionary = profiles[ready_key]
	ready_profile["implementation_state"] = "ready"
	ready_profile["total_boss_cap"] = 0.25
	for binding_field in ["targeting", "charge", "executor", "cleanup_policy"]:
		var binding: Dictionary = ready_profile[binding_field]
		binding["strategy_id"] = "test_bound_%s" % binding_field
	profiles[ready_key] = ready_profile
	var executable_pairs := {ready_key: true}

	_expect(
		Resolver.resolution_source(profiles, pairs, "berserk", "sword")
			== Resolver.SOURCE_LEGACY_CLASS_FALLBACK,
		"ready data without its exact executor pair must stay legacy-safe",
		errors
	)

	_expect(
		Resolver.resolution_source(
			profiles, pairs, "berserk", "sword", true, executable_pairs
		)
			== Resolver.SOURCE_WEAPON_PROFILE,
		"ready selected profile with its exact executor pair must be executable",
		errors
	)
	var resolved: Dictionary = Resolver.resolve_executable(
		profiles,
		pairs,
		"berserk",
		"sword",
		PD.ultimate_config("berserk"),
		true,
		executable_pairs
	)
	_expect(
		str(resolved.get("weapon_id", "")) == "sword",
		"ready selected profile must resolve by weapon ID",
		errors
	)
	_expect(
		Resolver.resolution_source(
			profiles, pairs, "berserk", "axe", true, executable_pairs
		)
			== Resolver.SOURCE_LEGACY_CLASS_FALLBACK,
		"ready selected profile must not activate a sibling declaration",
		errors
	)


func _expected_class_ids() -> Array[String]:
	var result: Array[String] = []
	for raw_class_id in PD.WEAPONS_BY_CLASS.keys():
		result.append(str(raw_class_id))
	return result


func _expect(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)
