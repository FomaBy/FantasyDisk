extends SceneTree

## Fail-closed visual-node budget contract for presentation scenes.
##
## The Soldier scenes intentionally use their exact drawn-node count as the
## visual cap; that zero headroom is accepted only because each scene records
## the decision in metadata. Any later artistic addition must either receive a
## reviewed cap change or fail with an observable runtime diagnostic.

const Runtime := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_runtime.gd")
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


func _expect(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)
