extends SceneTree

const Meta := preload("res://scripts/meta_progression.gd")
const Schema6 := preload("res://scripts/constellation_schema6_data.gd")
const FinalRuntime := preload("res://scripts/constellation_final_runtime.gd")

var errors := PackedStringArray()


func _initialize() -> void:
	var positive_count := 0
	var negative_count := 0
	for mechanic_id_value in Schema6.all_mechanics_by_id().keys():
		var mechanic_id := str(mechanic_id_value)
		var node: Dictionary = Schema6.mechanic(mechanic_id)
		var event := str(FinalRuntime.EVENT_BY_MECHANIC.get(mechanic_id, ""))
		_check(event != "", "%s missing explicit required event" % mechanic_id)
		var mechanic := {
			"mechanic_id": mechanic_id,
			"params": (node.get("effect_profile", {}) as Dictionary).get("params", {}),
			"caps": node.get("caps", {}),
		}
		var state := {}
		var wrong_event := "wrong_event" if event == "hit" else "hit"
		var wrong := FinalRuntime.resolve_event(mechanic, state, wrong_event, {"target_id": "wrong"})
		_check(bool(wrong.get("valid", false)) and not bool(wrong.get("triggered", false)), "%s triggered from wrong event %s" % [mechanic_id, wrong_event])
		_check(state.is_empty(), "%s mutated lifecycle state on wrong event" % mechanic_id)
		var result := {}
		var mode := str(FinalRuntime.MODE_BY_MECHANIC.get(mechanic_id, ""))
		for event_index in range(8):
			var target_id := "target_%d" % event_index if mode in ["unique_target_return", "return_shield", "priority_mark", "prey_distribution"] else "target"
			var event_context := {"target_id": target_id, "health_fraction": 0.2}
			if event == "hit":
				event_context["constellation_consumer_event"] = true
			if mode == "phase_resonance":
				event_context["phase"] = ["fire", "water", "air", "earth"][event_index % 4]
			result = FinalRuntime.resolve_event(mechanic, state, event, event_context)
			if bool(result.get("triggered", false)):
				break
		_check(bool(result.get("triggered", false)), "%s positive fixture never triggered from %s" % [mechanic_id, event])
		_check(str(result.get("mode", "")) == mode and str(result.get("event", "")) == event, "%s lost unique mode/event attribution" % mechanic_id)
		_check(float(result.get("axis_gain", 1.0)) >= 1.2 - 0.000001, "%s final gain is below 1.20" % mechanic_id)
		_check(str((result.get("side_effect", {}) as Dictionary).get("kind", "")) == mode, "%s emitted no semantic side-effect action" % mechanic_id)
		positive_count += 1

		var class_id := str(node.get("class_id", ""))
		var weapon_id := str(node.get("weapon_id", ""))
		var fixture_state := Meta.default_state()
		fixture_state["skill_nodes"] = [str(node.get("node_id", ""))]
		var own_profile := Meta.skill_modifiers_for_weapon(fixture_state, class_id, weapon_id)
		_check((own_profile.get("mechanics", {}) as Dictionary).has(mechanic_id), "%s missing from owning weapon profile" % mechanic_id)
		var negatives: Array = node.get("negative_controls", [])
		_check(negatives.size() == 2, "%s must declare exactly two same-class negatives" % mechanic_id)
		for foreign_weapon_value in negatives:
			var foreign_weapon := str(foreign_weapon_value)
			var foreign_profile := Meta.skill_modifiers_for_weapon(fixture_state, class_id, foreign_weapon)
			_check(bool(foreign_profile.get("valid", false)), "%s negative weapon %s is not canonical for class" % [mechanic_id, foreign_weapon])
			_check((foreign_profile.get("mechanics", {}) as Dictionary).is_empty(), "%s leaked into foreign weapon %s" % [mechanic_id, foreign_weapon])
			negative_count += 1

	var unknown := FinalRuntime.resolve_event({"mechanic_id": "unknown_final", "params": {}}, {}, "hit", {})
	_check(not bool(unknown.get("valid", true)), "unknown mechanic id did not fail closed")
	_check(positive_count == 51, "expected 51 positive fixtures, got %d" % positive_count)
	_check(negative_count == 102, "expected 102 foreign negatives, got %d" % negative_count)
	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("SCRUM-1068 final event matrix passed 51 positive fixtures, 102 foreign negatives, wrong-event neutrality and unknown-id failure.")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
