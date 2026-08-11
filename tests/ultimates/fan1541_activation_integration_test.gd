extends SceneTree

## FAN-1541 acceptance gate: the shipped catalog is a complete exact-pair
## runtime, with no ready selection falling through to legacy behavior.

const PD := preload("res://scripts/progression_data.gd")
const Discovery := preload("res://scripts/ultimates/registry/weapon_ultimate_package_discovery.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const Schema := preload("res://scripts/ultimates/schema/weapon_ultimate_schema.gd")
const Manifest := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_manifest.gd")
const PresentationSchema := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_schema.gd")
const PresentationRuntime := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_runtime.gd")
const HudAdapter := preload("res://scripts/ui/ultimate_hud/ultimate_hud_runtime_adapter.gd")

const INVALID_DATA_ROOT := "res://tests/ultimates/fixtures/packages_invalid/data"
const INVALID_SCRIPT_ROOT := "res://tests/ultimates/fixtures/packages_invalid/scripts"

var _errors: Array[String] = []


class HudPlayerFixture extends Node2D:
	var character_id := "soldier"
	var weapon_id := "soldier_rifle"
	var ultimate_charge := 100.0
	var ultimate_max_charge := 100.0
	var _ultimate_active := false
	var activations := 0

	func attack_aim_mode() -> String:
		return "nearest"

	func activate_ultimate() -> bool:
		activations += 1
		return true


class HudGameFixture extends Node:
	var current_player: Node2D = null


class PresentationHost extends Node2D:
	var effects := Node2D.new()

	func _init() -> void:
		add_child(effects)

	func ultimate_host_effect_parent() -> Node:
		return effects

	func ultimate_host_position() -> Vector2:
		return global_position


func _initialize() -> void:
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	_check(registry.is_valid(), "the 51-profile catalog must validate", registry.validation_errors())
	_check(registry.class_ids().size() == 17, "catalog must expose 17 classes")
	_check(registry.profile_count() == 51, "catalog must expose 51 exact profiles")
	_check(registry.package_validation_errors().is_empty(),
		"active package discovery must be clean", registry.package_validation_errors())
	_check(registry.package_pair_keys().size() == 51,
		"every canonical profile must have an admitted exact executor pair")

	var profiles := registry.profiles_for_tests()
	var presentation_ids := {}
	for key in registry.profile_keys():
		var parts := key.split("/", false, 1)
		_check(parts.size() == 2, "%s must be a class/weapon key" % key)
		if parts.size() != 2:
			continue
		var class_id := parts[0]
		var weapon_id := parts[1]
		var profile: Dictionary = registry.catalog_profile_for(class_id, weapon_id)
		_check(str(registry.resolution_source(class_id, weapon_id, false)) == Resolver.SOURCE_WEAPON_PROFILE,
			"%s must resolve to its exact weapon profile without legacy fallback" % key)
		_check(registry.has_exact_executor_pair(class_id, weapon_id),
			"%s must retain its exact executor" % key)
		_check(registry.executor_for(class_id, weapon_id) is GDScript,
			"%s executor must load" % key)
		var executable: Dictionary = registry.resolve_executable(class_id, weapon_id, {}, false)
		_check(not executable.is_empty() and str(executable.get("weapon_id", "")) == weapon_id,
			"%s must resolve an exact executable profile" % key)
		var identity: Dictionary = profile.get("identity", {})
		var profile_id := str(identity.get("profile_id", ""))
		_check(not profile_id.is_empty() and not presentation_ids.has(profile_id),
			"%s must keep a unique immutable profile identity" % key)
		presentation_ids[profile_id] = true
		_test_presentation(registry, profile, key)

	_check(presentation_ids.size() == 51, "all 51 immutable profile IDs must be unique")
	_test_fail_closed_package_admission(registry)
	_test_invalid_discovery(profiles)
	await _test_live_hud_adapter()
	_report()


func _test_presentation(registry, profile: Dictionary, key: String) -> void:
	var manifest: Dictionary = Manifest.manifest_for_profile(profile)
	_check(not manifest.is_empty(), "%s must have an exact presentation manifest" % key)
	if manifest.is_empty():
		return
	_check(PresentationSchema.validate_manifest(manifest, profile).is_empty(),
		"%s presentation manifest must validate" % key,
		PresentationSchema.validate_manifest(manifest, profile))
	var runtime: Dictionary = manifest.get("runtime", {})
	var scene_path := str(runtime.get("scene_path", ""))
	_check(scene_path.begins_with("res://scenes/vfx/ultimates/"),
		"%s must use a class-local scene, never a bootstrap texture" % key)
	_check(ResourceLoader.exists(scene_path), "%s scene must exist" % key)
	for channel in ["animation", "vfx"]:
		var asset: Dictionary = manifest.get(channel, {})
		_check(str(asset.get("runtime_path", "")) == scene_path,
			"%s %s must bind the exact class-local scene" % [key, channel])
	var max_visual_nodes := int(runtime.get("max_visual_nodes", 0))
	var crowd_cap := int(runtime.get("crowd_cap", 0))
	_check(max_visual_nodes <= 0 or crowd_cap <= 0 or max_visual_nodes <= crowd_cap,
		"%s documented visual budget must not exceed its crowd cap" % key)
	var host := PresentationHost.new()
	root.add_child(host)
	var presentation := PresentationRuntime.new(0)
	_check(presentation.begin(host, registry, profile),
		"%s must enter the real presentation branch under the headless gate" % key)
	presentation.set_paused(true)
	presentation.advance(1.0)
	presentation.finish("node_end")
	_check(not presentation.is_active(), "%s presentation must clean up" % key)
	host.free()


func _test_fail_closed_package_admission(registry) -> void:
	var base_profiles := Schema.index_documents(registry.documents_for_tests())
	var discovery := Discovery.new()
	var path := "res://data/ultimates/classes/soldier/soldier_grenade.json"
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	var executor = load("res://scripts/ultimates/classes/soldier/soldier_grenade.gd")
	_check(parsed is Dictionary and executor is GDScript, "active Soldier mutation fixture must load")
	if not parsed is Dictionary or not executor is GDScript:
		return
	var mismatch: Dictionary = (parsed as Dictionary).duplicate(true)
	mismatch["class_id"] = "sniper"
	var result: Dictionary = discovery.validate_pair(
		mismatch, "soldier/soldier_grenade.json", executor, base_profiles["soldier/soldier_grenade"]
	)
	_check(_has_error(result.get("errors", []) as Array, "package.path_identity"),
		"a class/path mismatch must be rejected")
	_check(Manifest.class_weapon_record("soldier", "missing_weapon").is_empty(),
		"a missing exact presentation asset must fail closed")


func _test_invalid_discovery(profiles: Dictionary) -> void:
	var invalid := Discovery.new(INVALID_DATA_ROOT, INVALID_SCRIPT_ROOT)
	invalid.discover(profiles)
	var errors := invalid.validation_errors()
	_check(invalid.pair_keys().is_empty(), "duplicate or incomplete package fixture must admit no pair")
	for prefix in ["package.pair.duplicate", "package.pair.executor_missing", "package.pair.data_missing"]:
		_check(_has_error(errors, prefix), "%s must fail closed" % prefix, errors)


func _test_live_hud_adapter() -> void:
	var game := HudGameFixture.new()
	var root := Control.new()
	root.size = Vector2(1280.0, 720.0)
	root.name = "Fan1541HudRoot"
	game.add_child(root)
	self.root.add_child(game)
	var adapter := HudAdapter.attach(root, game)
	await process_frame
	var player := HudPlayerFixture.new()
	game.current_player = player
	game.add_child(player)
	await process_frame
	var widget := root.get_node_or_null("UltimateHudWidget")
	_check(widget != null and widget.has_method("state"), "live HUD widget must be present")
	if widget != null:
		var state: Dictionary = widget.call("state")
		var selection: Dictionary = state.get("selection", {})
		_check(str(selection.get("class_id", "")) == "soldier"
			and str(selection.get("weapon_id", "")) == "soldier_rifle",
			"HUD must retain the selected exact weapon identity")
		_check(is_equal_approx(float((state.get("charge", {}) as Dictionary).get("fraction", 0.0)), 1.0),
			"HUD must reflect the Player-owned full charge")
		_check(bool(widget.call("request_activation")), "ready HUD request must be accepted")
		_check(player.activations == 1, "HUD request must route through Player.activate_ultimate")
	game.queue_free()
	await process_frame


func _has_error(errors: Array, prefix: String) -> bool:
	for raw_error in errors:
		if str(raw_error).contains(prefix):
			return true
	return false


func _check(condition: bool, message: String, details: Variant = null) -> void:
	if not condition:
		_errors.append("%s%s" % [message, " (%s)" % details if details != null else ""])


func _report() -> void:
	if _errors.is_empty():
		print("fan1541_activation_integration_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("fan1541_activation_integration_test: %s" % error)
	print("fan1541_activation_integration_test: FAIL (%d)" % _errors.size())
	quit(1)
