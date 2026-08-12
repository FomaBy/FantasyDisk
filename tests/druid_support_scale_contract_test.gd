extends SceneTree

const ProgressionData := preload("res://scripts/progression_data.gd")

const MINION_SOURCE_PATH := "res://scripts/ally_minion.gd"
const PLAYER_SOURCE_PATH := "res://scripts/player.gd"
const FORBIDDEN_MINION_FRAGMENTS := [
	"_druid_summon_support_multiplier",
	"_druid_summon_aura_radius",
	"StatusEffects.apply_status(self, \"command_aura\"",
	"StatusEffects.apply_status(self, \"wild_force_aura\"",
	"StatusEffects.apply_status(target, \"command_pressure\"",
]
const REQUIRED_PLAYER_WRITERS := [
	"StatusEffects.apply_status(ally_node, \"command_aura\"",
	"StatusEffects.apply_status(enemy_node, \"command_pressure\"",
	"StatusEffects.apply_status(ally_node, \"wild_force_aura\"",
]


func _initialize() -> void:
	var errors: Array[String] = []
	var config: Dictionary = ProgressionData.weapon("druid", "summon_amulet")
	var stats: Dictionary = ProgressionData.base_stats("druid")
	var modifiers := {"damage_multiplier": 1.20, "aoe_radius_multiplier": 1.10}
	var parameters := ProgressionData.derived_parameters(stats, modifiers, config)
	var support_multiplier := float(parameters.get("support_multiplier", 0.0))
	var aura_radius := float(parameters.get("aura_radius", 0.0))
	var expected_support := 1.0 + float(parameters.get("leadership", 0.0)) * 0.025 + float(stats.get("knowledge", 0.0)) * 0.006 + float(stats.get("energy", 0.0)) * 0.004
	var expected_radius := float(config.get("aoe_radius", 0.0)) + float(parameters.get("leadership", 0.0)) * 5.0 + float(stats.get("perception", 0.0)) * 0.80 + float(stats.get("energy", 0.0)) * 0.65 + float(stats.get("knowledge", 0.0)) * 0.45
	if not is_equal_approx(support_multiplier, expected_support):
		errors.append("support_multiplier did not come from the canonical Druid contract")
	if not is_equal_approx(aura_radius, expected_radius):
		errors.append("aura_radius did not come from the canonical attack-area multiplier")

	var mutated_stats := stats.duplicate(true)
	mutated_stats["leadership"] = float(mutated_stats.get("leadership", 0.0)) + 100.0
	mutated_stats["knowledge"] = float(mutated_stats.get("knowledge", 0.0)) + 50.0
	mutated_stats["energy"] = float(mutated_stats.get("energy", 0.0)) + 50.0
	var mutated := ProgressionData.derived_parameters(mutated_stats, modifiers, config)
	var mutated_support := float(mutated.get("support_multiplier", 0.0))
	if mutated_support <= support_multiplier:
		errors.append("canonical support contract ignored Druid support inputs")
	var repeated_legacy_scale := float(mutated.get("aura_radius", 0.0)) + float(mutated.get("leadership", 0.0)) * 5.0 + float(mutated_stats["knowledge"]) * 0.45 + float(mutated_stats["energy"]) * 0.65
	if is_equal_approx(repeated_legacy_scale, float(mutated.get("aura_radius", 0.0))):
		errors.append("mutation oracle no longer distinguishes repeated local aura scaling")

	var minion_source := FileAccess.get_file_as_string(MINION_SOURCE_PATH)
	var player_source := FileAccess.get_file_as_string(PLAYER_SOURCE_PATH)
	for fragment in FORBIDDEN_MINION_FRAGMENTS:
		if minion_source.contains(fragment):
			errors.append("AllyMinion retains forbidden aura writer '%s'" % fragment)
	for writer in REQUIRED_PLAYER_WRITERS:
		if player_source.count(writer) != 1:
			errors.append("Player must be the sole writer for '%s'" % writer)

	if not errors.is_empty():
		for error in errors:
			push_error("Druid support-scale contract: %s" % error)
		quit(1)
		return
	print("Druid support-scale contract passed: canonical derived values and one status writer per aura.")
	quit(0)
