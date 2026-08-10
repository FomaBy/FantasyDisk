extends SceneTree

## Focused contract test for FAN-1456.
##
## Run:
## Godot --headless --path . \
##   --script res://tests/ultimates/registry_contract_test.gd

const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")

const READY_CLASS := "sniper"
const READY_WEAPONS := [
	"sniper_deadeye_rifle",
	"sniper_spotter_scope",
	"sniper_shatter_rounds",
]


func _initialize() -> void:
	var errors: Array[String] = []
	var registry = Registry.new(PD.WEAPONS_BY_CLASS)
	var package_pairs := {}
	for key in registry.package_pair_keys():
		package_pairs[str(key)] = true

	_expect(
		registry.is_valid(),
		"registry must be valid: %s" % str(registry.validation_errors()),
		errors
	)
	_expect(registry.validation_errors().is_empty(), "validation errors must be empty", errors)
	_expect(registry.class_ids() == _expected_class_ids(), "class order must match canonical inventory", errors)
	_expect(registry.profile_count() == 51, "catalog must contain exactly 51 profiles", errors)
	_expect(registry.package_validation_errors().is_empty(),
		"discovered packages must satisfy the exact data/executor contract: %s"
		% str(registry.package_validation_errors()), errors)

	var selected_checks := 0
	var sibling_negative_controls := 0
	for raw_class_id in PD.WEAPONS_BY_CLASS.keys():
		var class_id := str(raw_class_id)
		var canonical_weapons: Dictionary = PD.WEAPONS_BY_CLASS[class_id]
		var weapon_ids: Array[String] = []
		var profile_ids := {}
		for raw_weapon_id in canonical_weapons.keys():
			weapon_ids.append(str(raw_weapon_id))
		_expect(
			registry.weapon_ids(class_id) == weapon_ids,
			"%s weapon order must match canonical inventory" % class_id,
			errors
		)
		_expect(weapon_ids.size() == 3, "%s must expose exactly three weapons" % class_id, errors)
		for weapon_id in weapon_ids:
			var selected: Dictionary = registry.catalog_profile_for(class_id, weapon_id)
			var profile_key := Resolver.profile_key(class_id, weapon_id)
			var has_exact_package := package_pairs.has(profile_key)
			var is_ready := str(selected.get("implementation_state", "")) == "ready"
			_expect(not selected.is_empty(), "%s/%s profile must resolve" % [class_id, weapon_id], errors)
			_expect(str(selected.get("class_id", "")) == class_id, "selected class must match", errors)
			_expect(str(selected.get("weapon_id", "")) == weapon_id, "selected weapon must match", errors)
			_expect(is_ready, "%s active profile must be explicitly ready" % profile_key, errors)
			_expect(has_exact_package, "%s active profile must have an exact package pair" % profile_key, errors)
			selected_checks += 1

			var selected_identity: Dictionary = selected.get("identity", {})
			var selected_presentation: Dictionary = selected.get("presentation", {})
			var profile_id := str(selected_identity.get("profile_id", ""))
			_expect(not profile_ids.has(profile_id), "%s profile IDs must be unique" % class_id, errors)
			profile_ids[profile_id] = true
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
				registry.resolution_source(class_id, weapon_id, false) == Resolver.SOURCE_WEAPON_PROFILE,
				"%s/%s must not fall back from its exact ready package state" % [class_id, weapon_id],
				errors
			)
			var executable: Dictionary = registry.resolve_executable(class_id, weapon_id, legacy, false)
			_expect(executable == selected,
				"%s/%s must return its selected executable contract" % [class_id, weapon_id], errors)
			executable["__mutation_probe"] = true
			_expect(
				not registry.resolve_executable(class_id, weapon_id, legacy, false).has("__mutation_probe"),
				"resolved contract must be a deep copy",
				errors
			)
		_expect(profile_ids.size() == 3, "%s must expose three unique weapon profiles" % class_id, errors)

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
	# FAN-1541 ships the complete 17 x 3 active roster: the catalog and exact
	# package set must contain the same canonical pairs, with no fallback probe.
	var catalog_pairs := {}
	for raw_key in registry.profile_keys():
		catalog_pairs[str(raw_key)] = true
	_expect(catalog_pairs == registry.canonical_pairs_for_tests(),
		"catalog must contain exactly the canonical 51 pairs", errors)
	_expect(package_pairs == registry.canonical_pairs_for_tests(),
		"active packages must cover exactly the canonical 51 pairs", errors)

	_test_ready_package_matrix(registry, errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Weapon ultimate registry contract: %s" % error)
		push_error("Weapon ultimate registry contract test: %d errors." % errors.size())
		quit(1)
		return
	print(
		"Weapon ultimate registry contract passed "
		+ "(17 classes, 51 selections, 102 sibling negative controls, exact ready pairs admitted)."
	)
	quit(0)


func _test_ready_package_matrix(registry, errors: Array[String]) -> void:
	var profiles: Dictionary = registry.profiles_for_tests()
	var pairs: Dictionary = registry.canonical_pairs_for_tests()
	var executable_pairs := {}
	for weapon_id in READY_WEAPONS:
		var key := Resolver.profile_key(READY_CLASS, weapon_id)
		var ready_profile: Dictionary = profiles[key]
		ready_profile["implementation_state"] = "ready"
		ready_profile["total_boss_cap"] = 0.25
		for binding_field in ["targeting", "charge", "executor", "cleanup_policy"]:
			var binding: Dictionary = ready_profile[binding_field]
			binding["strategy_id"] = "test_bound_%s" % binding_field
		profiles[key] = ready_profile
		executable_pairs[key] = true

	var legacy_pairs := 0
	for raw_class_id in PD.WEAPONS_BY_CLASS.keys():
		var class_id := str(raw_class_id)
		for raw_weapon_id in (PD.WEAPONS_BY_CLASS[class_id] as Dictionary).keys():
			var weapon_id := str(raw_weapon_id)
			var key := Resolver.profile_key(class_id, weapon_id)
			var source := Resolver.resolution_source(
				profiles, pairs, class_id, weapon_id, true, executable_pairs
			)
			if executable_pairs.has(key):
				_expect(source == Resolver.SOURCE_WEAPON_PROFILE,
					"%s exact ready pair must resolve to its weapon profile" % key, errors)
				var resolved: Dictionary = Resolver.resolve_executable(
					profiles, pairs, class_id, weapon_id, PD.ultimate_config(class_id), true, executable_pairs
				)
				_expect(str(resolved.get("weapon_id", "")) == weapon_id,
					"%s exact ready pair must retain weapon identity" % key, errors)
			else:
				legacy_pairs += 1
				_expect(source == Resolver.SOURCE_LEGACY_CLASS_FALLBACK,
					"%s declared or unbound pair must keep legacy fallback" % key, errors)
	_expect(legacy_pairs == 48, "all 48 non-ready pairs must keep legacy fallback", errors)

	var partial_pairs := {}
	_expect(
		Resolver.resolution_source(profiles, pairs, READY_CLASS, READY_WEAPONS[0], true, partial_pairs)
			== Resolver.SOURCE_LEGACY_CLASS_FALLBACK,
		"ready data without its exact executor pair must fail closed to legacy fallback", errors)
	var declared_profiles := profiles.duplicate(true)
	var declared_key := Resolver.profile_key(READY_CLASS, READY_WEAPONS[0])
	(declared_profiles[declared_key] as Dictionary)["implementation_state"] = "declared"
	_expect(
		Resolver.resolution_source(
			declared_profiles, pairs, READY_CLASS, READY_WEAPONS[0], true, executable_pairs
		) == Resolver.SOURCE_LEGACY_CLASS_FALLBACK,
		"a malformed non-ready pair must fail closed to legacy fallback", errors)
	var orphan_pairs := {Resolver.profile_key("__orphan__", "__orphan__"): true}
	_expect(
		Resolver.resolution_source(
			profiles, pairs, "__orphan__", "__orphan__", true, orphan_pairs
		) == Resolver.SOURCE_INVALID_PAIR,
		"orphan package pairs must stay invalid", errors)


func _expected_class_ids() -> Array[String]:
	var result: Array[String] = []
	for raw_class_id in PD.WEAPONS_BY_CLASS.keys():
		result.append(str(raw_class_id))
	return result


func _expect(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)
