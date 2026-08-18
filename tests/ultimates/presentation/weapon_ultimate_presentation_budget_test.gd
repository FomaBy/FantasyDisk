extends SceneTree

## Fail-closed visual-node and material budget contract for presentation scenes.
##
## The Soldier scenes intentionally use their exact drawn-node count as the
## visual cap; that zero headroom is accepted only because each scene records
## the decision in metadata. Any later artistic addition must either receive a
## reviewed cap change or fail with an observable runtime diagnostic.
##
## The material budget rides the existing PRESENTATION_V2_MIGRATION_ALLOWLIST,
## so it binds a pair the moment its rework card takes it out of the ratchet.
## The Soldier packs are still v1, so the migrated behaviour is proven by
## reading the same packs against an empty allowlist.

const Runtime := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_runtime.gd")
const Contract := preload("res://scripts/ultimates/presentation/ultimate_visual_direction_contract.gd")
const Schema := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_schema.gd")
const REFERENCE_CLASS := "soldier"
const PACKS := [
	{
		"id": "soldier_rifle",
		"scene": preload("res://scenes/vfx/ultimates/soldier/SoldierRifleSuppressiveOrder.tscn"),
	},
	{
		"id": "soldier_grenade",
		"scene": preload("res://scenes/vfx/ultimates/soldier/SoldierGrenadeSevenSeconds.tscn"),
	},
	{
		"id": "soldier_bayonet",
		"scene": preload("res://scenes/vfx/ultimates/soldier/SoldierBayonetLastCharge.tscn"),
	},
]


class BudgetProbe extends Runtime:
	func evaluate(scene: Node, runtime: Dictionary) -> Dictionary:
		set("_scene", scene)
		var accepted := _within_declared_budget(runtime)
		var diagnostic := last_budget_diagnostic()
		set("_scene", null)
		return {"accepted": accepted, "diagnostic": diagnostic}


func _initialize() -> void:
	var errors: Array[String] = []
	for raw_pack in PACKS:
		var pack := raw_pack as Dictionary
		_test_declared_budget(pack, errors)
		_test_failure_modes(pack, errors)
		_test_material_budget(pack, errors)
	_test_manifest_material_gate(errors)
	if errors.is_empty():
		print("Weapon ultimate presentation budget contract passed (explicit Soldier decisions and fail-closed diagnostics).")
		quit(0)
		return
	for error in errors:
		push_error("Weapon ultimate presentation budget: %s" % error)
	quit(1)


func _test_declared_budget(pack: Dictionary, errors: Array[String]) -> void:
	var scene := (pack["scene"] as PackedScene).instantiate()
	var drawn := Runtime._drawing_node_count(scene)
	var max_visual_nodes := int(scene.get_meta("max_visual_nodes", 0))
	var crowd_cap := int(scene.get_meta("crowd_cap", 0))
	var decision := str(scene.get_meta("visual_node_budget_decision", "")).strip_edges()
	_expect(max_visual_nodes > 0, "%s must declare a positive visual-node budget" % pack["id"], errors)
	_expect(crowd_cap >= max_visual_nodes, "%s crowd cap must cover its visual budget" % pack["id"], errors)
	_expect(drawn <= max_visual_nodes, "%s drawn-node count %d must fit its cap %d" % [pack["id"], drawn, max_visual_nodes], errors)
	if drawn == max_visual_nodes:
		_expect(not decision.is_empty(), "%s exact visual budget requires an explicit decision" % pack["id"], errors)
	var result := (BudgetProbe.new()).evaluate(scene, {"max_visual_nodes": max_visual_nodes, "crowd_cap": crowd_cap})
	_expect(bool(result.get("accepted", false)), "%s declared budget must be accepted" % pack["id"], errors)
	_expect(str(result.get("diagnostic", "")).is_empty(), "%s accepted budget must not retain a diagnostic" % pack["id"], errors)
	scene.free()


func _test_failure_modes(pack: Dictionary, errors: Array[String]) -> void:
	var scene := (pack["scene"] as PackedScene).instantiate()
	var drawn := Runtime._drawing_node_count(scene)
	var crowd_cap := int(scene.get_meta("crowd_cap", 0))
	var probe := BudgetProbe.new()
	var exceeded := probe.evaluate(scene, {"max_visual_nodes": drawn - 1, "crowd_cap": crowd_cap})
	_expect(not bool(exceeded.get("accepted", true)), "%s exceeded budget must fail closed" % pack["id"], errors)
	_expect(str(exceeded.get("diagnostic", "")).contains("exceed"), "%s exceeded budget must expose a diagnostic" % pack["id"], errors)

	scene.remove_meta("max_visual_nodes")
	scene.remove_meta("crowd_cap")
	var missing := probe.evaluate(scene, {})
	_expect(not bool(missing.get("accepted", true)), "%s missing budget must fail closed" % pack["id"], errors)
	_expect(str(missing.get("diagnostic", "")).contains("missing"), "%s missing budget must expose a diagnostic" % pack["id"], errors)

	for invalid in [
		{"max_visual_nodes": 0, "crowd_cap": crowd_cap},
		{"max_visual_nodes": -1, "crowd_cap": crowd_cap},
		{"max_visual_nodes": crowd_cap + 1, "crowd_cap": crowd_cap},
	]:
		var invalid_result := probe.evaluate(scene, invalid)
		_expect(not bool(invalid_result.get("accepted", true)), "%s invalid budget must fail closed" % pack["id"], errors)
		_expect(str(invalid_result.get("diagnostic", "")).contains("invalid"), "%s invalid budget must expose a diagnostic" % pack["id"], errors)
	scene.free()


## The material half of the same per-activation budget, gated by the existing
## v2 migration ratchet: an allowlisted v1 pack owes no material declaration,
## while the same pack read as a migrated pair owes one its actual materials fit.
func _test_material_budget(pack: Dictionary, errors: Array[String]) -> void:
	var scene := (pack["scene"] as PackedScene).instantiate()
	var key := str(scene.get_meta("ultimate_id", ""))
	var counts := Contract.material_counts(scene)
	var unique := int(counts["unique"])
	_expect(unique == 1, "%s shares one canvas material across its drawn nodes" % pack["id"], errors)
	_expect(int(counts["fullscreen"]) == 0, "%s draws in world space: no screen-space material" % pack["id"], errors)
	_expect(Schema.PRESENTATION_V2_MIGRATION_ALLOWLIST.has(key), "%s must still be an allowlisted v1 pair" % key, errors)
	_expect(
		Contract.scene_material_violations(scene, key).is_empty(),
		"%s is allowlisted v1 and must not owe a material declaration" % key,
		errors
	)

	_expect_code(
		Contract.scene_material_violations(scene, key, {}),
		"budget.max_unique_materials",
		"%s must fail closed on a missing material declaration" % key,
		errors
	)

	scene.set_meta("max_unique_materials", unique)
	scene.set_meta("max_fullscreen_materials", 1)
	_expect(
		Contract.scene_material_violations(scene, key, {}).is_empty(),
		"%s actual materials must fit the budget it declares" % key,
		errors
	)

	scene.set_meta("max_unique_materials", Contract.MAX_UNIQUE_MATERIALS_CEILING + 1)
	_expect_code(
		Contract.scene_material_violations(scene, key, {}),
		"budget.max_unique_materials_ceiling",
		"%s must fail closed above the unique-material ceiling" % key,
		errors
	)

	scene.set_meta("max_unique_materials", unique)
	scene.set_meta("max_fullscreen_materials", Contract.MAX_FULLSCREEN_MATERIALS_CEILING + 1)
	_expect_code(
		Contract.scene_material_violations(scene, key, {}),
		"budget.max_fullscreen_materials_ceiling",
		"%s must fail closed above the full-screen material ceiling" % key,
		errors
	)

	scene.set_meta("max_unique_materials", 1)
	scene.set_meta("max_fullscreen_materials", Contract.MAX_FULLSCREEN_MATERIALS_CEILING)
	_expect_code(
		Contract.scene_material_violations(scene, key, {}),
		"budget.material_relation",
		"%s must fail closed when more materials cover the viewport than exist" % key,
		errors
	)

	scene.set_meta("max_unique_materials", unique)
	scene.set_meta("max_fullscreen_materials", 1)
	scene.add_child(_with_material(Sprite2D.new()))
	_expect_code(
		Contract.scene_material_violations(scene, key, {}),
		"budget.unique_materials_actual",
		"%s must fail closed when it carries more materials than it declared" % key,
		errors
	)

	var backdrop := CanvasLayer.new()
	backdrop.add_child(_with_material(Polygon2D.new()))
	backdrop.add_child(_with_material(Polygon2D.new()))
	scene.add_child(backdrop)
	scene.set_meta("max_unique_materials", Contract.MAX_UNIQUE_MATERIALS_CEILING)
	_expect_code(
		Contract.scene_material_violations(scene, key, {}),
		"budget.fullscreen_materials_actual",
		"%s must fail closed when more screen-space layers cover the viewport than it declared" % key,
		errors
	)
	scene.free()


## The declaration side of the same gate, read off the class reference manifest.
func _test_manifest_material_gate(errors: Array[String]) -> void:
	var manifest := Contract.load_manifest(REFERENCE_CLASS)
	_expect(not manifest.is_empty(), "%s reference manifest must load" % REFERENCE_CLASS, errors)
	_expect(
		_budget_violations(Contract.violations(REFERENCE_CLASS, manifest)).is_empty(),
		"%s is allowlisted v1 and must owe no declared material budget" % REFERENCE_CLASS,
		errors
	)
	_expect_code(
		_budget_violations(Contract.violations(REFERENCE_CLASS, manifest, {})),
		"budget.max_unique_materials",
		"%s read as a migrated pair must fail closed on the missing declaration" % REFERENCE_CLASS,
		errors
	)

	var declared := manifest.duplicate(true)
	for raw_weapon in declared.get("weapons", []) as Array:
		var performance := (raw_weapon as Dictionary)["performance"] as Dictionary
		performance["max_unique_materials"] = Contract.MAX_UNIQUE_MATERIALS_CEILING
		performance["max_fullscreen_materials"] = Contract.MAX_FULLSCREEN_MATERIALS_CEILING
	_expect(
		_budget_violations(Contract.violations(REFERENCE_CLASS, declared, {})).is_empty(),
		"a declared material budget inside both ceilings must be accepted",
		errors
	)


## A drawn node carrying its own material, so a control grows the measured
## material count by exactly one.
func _with_material(node: CanvasItem) -> CanvasItem:
	node.material = CanvasItemMaterial.new()
	return node


func _budget_violations(violations: Array[String]) -> Array[String]:
	var found: Array[String] = []
	for violation in violations:
		if Contract.gate_of(violation) == "budget":
			found.append(violation)
	return found


func _expect_code(violations: Array[String], code: String, message: String, errors: Array[String]) -> void:
	for violation in violations:
		if violation.begins_with("%s:" % code):
			return
	errors.append("%s (reported %s)" % [message, str(violations)])


func _expect(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)
