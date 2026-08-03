extends "res://scripts/encounters/encounter_feature.gd"
## Default-off normal-wave decks selected from the committed node seed.


func id() -> String:
	return "normal_decks"


func is_eligible(context) -> bool:
	return context.is_normal_battle()


func build_spawn_plan(context, feature_def: Dictionary) -> Dictionary:
	var choices: Array = []
	var total_weight := 0.0
	for value in feature_def.get("spawn_plans", []):
		if not (value is Dictionary):
			continue
		var plan := value as Dictionary
		var weight = plan.get("role_weight", 0)
		if not (weight is int or weight is float) or float(weight) <= 0.0 \
				or not _stage_allows(plan, context.route_scaling_stage):
			continue
		choices.append(plan)
		total_weight += float(weight)
	if choices.is_empty():
		return {}

	var roll: float = context.aspect_rng(int(feature_def.get("seed_salt", 0))).randf() * total_weight
	for plan in choices:
		roll -= float(plan["role_weight"])
		if roll <= 0.0:
			return plan.duplicate(true)
	return choices.back().duplicate(true)


func _stage_allows(plan: Dictionary, stage: int) -> bool:
	var minimum = plan.get("min_stage", 0)
	var maximum = plan.get("max_stage", 64)
	return (minimum is int or minimum is float) and (maximum is int or maximum is float) \
		and float(minimum) == floorf(float(minimum)) and float(maximum) == floorf(float(maximum)) \
		and stage >= int(minimum) and stage <= int(maximum)
