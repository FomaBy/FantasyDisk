extends SceneTree

const ProgressionData := preload("res://scripts/progression_data.gd")

const MINION_SOURCE_PATH := "res://scripts/ally_minion.gd"
const PLAYER_SOURCE_PATH := "res://scripts/player.gd"
const PLAYER_CLASS_EFFECTS_SOURCE_PATH := "res://scripts/player/player_class_effects.gd"
const FORBIDDEN_MINION_FRAGMENTS := [
	"_druid_summon_support_multiplier",
	"_druid_summon_aura_radius",
	"StatusEffects.apply_status(self, \"command_aura\"",
	"StatusEffects.apply_status(self, \"wild_force_aura\"",
	"StatusEffects.apply_status(target, \"command_pressure\"",
]
const REQUIRED_AURA_WRITERS := [
	{
		"fragment": "StatusEffects.apply_status(ally_node, \"command_aura\"",
		"owner": PLAYER_CLASS_EFFECTS_SOURCE_PATH,
	},
	{
		"fragment": "StatusEffects.apply_status(enemy_node, \"command_pressure\"",
		"owner": PLAYER_CLASS_EFFECTS_SOURCE_PATH,
	},
	{
		"fragment": "StatusEffects.apply_status(ally_node, \"wild_force_aura\"",
		"owner": PLAYER_CLASS_EFFECTS_SOURCE_PATH,
	},
]


func _initialize() -> void:
	var errors: Array[String] = []
	var config: Dictionary = ProgressionData.weapon("druid", "summon_amulet")
	var stats: Dictionary = ProgressionData.base_stats("druid")
	var neutral_modifiers := {"damage_multiplier": 1.20}
	var modifiers := {"damage_multiplier": 1.20, "aoe_radius_multiplier": 1.10}
	var neutral := ProgressionData.derived_parameters(stats, neutral_modifiers, config)
	var parameters := ProgressionData.derived_parameters(stats, modifiers, config)
	var support_multiplier := float(parameters.get("support_multiplier", 0.0))
	var aura_radius := float(parameters.get("aura_radius", 0.0))
	var expected_support := 1.0 + float(parameters.get("leadership", 0.0)) * 0.025 + float(stats.get("knowledge", 0.0)) * 0.006 + float(stats.get("energy", 0.0)) * 0.004
	var expected_radius := float(config.get("aoe_radius", 0.0)) + float(parameters.get("leadership", 0.0)) * 5.0 + float(stats.get("perception", 0.0)) * 0.80 + float(stats.get("energy", 0.0)) * 0.65 + float(stats.get("knowledge", 0.0)) * 0.45
	# Общая область атаки — единственный источник масштаба радиуса: тот же
	# множитель, что двигает attack_area_multiplier, применяется ровно один раз.
	var area_ratio := float(parameters.get("attack_area_multiplier", 0.0)) / maxf(float(neutral.get("attack_area_multiplier", 1.0)), 0.0001)
	if not is_equal_approx(support_multiplier, expected_support):
		errors.append("support_multiplier did not come from the canonical Druid contract")
	if not is_equal_approx(float(neutral.get("aura_radius", 0.0)), expected_radius):
		errors.append("aura_radius did not come from the canonical Druid support-scale formula")
	if not is_equal_approx(aura_radius, expected_radius * area_ratio):
		errors.append("aura_radius did not apply the shared area multiplier exactly once")
	if is_equal_approx(expected_radius * area_ratio, expected_radius):
		errors.append("mutation oracle accepted a missing shared area multiplier")
	if is_equal_approx(expected_radius * area_ratio, expected_radius * area_ratio * area_ratio):
		errors.append("mutation oracle accepted a doubled shared area multiplier")
	if not is_equal_approx(float(ProgressionData.derived_parameters(stats, modifiers, config).get("aura_radius", 0.0)), aura_radius):
		errors.append("repeated derivation changed aura_radius")

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
	var player_sources := {
		PLAYER_SOURCE_PATH: FileAccess.get_file_as_string(PLAYER_SOURCE_PATH),
		PLAYER_CLASS_EFFECTS_SOURCE_PATH: FileAccess.get_file_as_string(PLAYER_CLASS_EFFECTS_SOURCE_PATH),
	}
	for fragment in FORBIDDEN_MINION_FRAGMENTS:
		if minion_source.contains(fragment):
			errors.append("AllyMinion retains forbidden aura writer '%s'" % fragment)
	errors.append_array(_aura_writer_errors(player_sources))
	_verify_aura_writer_mutations(player_sources, errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Druid support-scale contract: %s" % error)
		quit(1)
		return
	print("Druid support-scale contract passed: canonical derived values and one status writer per aura.")
	quit(0)


func _aura_writer_errors(sources: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for requirement in REQUIRED_AURA_WRITERS:
		var fragment := str(requirement["fragment"])
		var owner := str(requirement["owner"])
		var total := 0
		for path in sources:
			var count := str(sources[path]).count(fragment)
			total += count
			if path == owner and count != 1:
				errors.append("Player-owned extracted implementation must contain exactly one writer for '%s'" % fragment)
			elif path != owner and count != 0:
				errors.append("Player ownership surface has a duplicate writer for '%s' in %s" % [fragment, path])
		if total != 1:
			errors.append("Player ownership surface must contain exactly one writer for '%s', found %d" % [fragment, total])
	return errors


func _verify_aura_writer_mutations(sources: Dictionary, errors: Array[String]) -> void:
	var deleted := sources.duplicate()
	var first_fragment := str(REQUIRED_AURA_WRITERS[0]["fragment"])
	deleted[PLAYER_CLASS_EFFECTS_SOURCE_PATH] = str(deleted[PLAYER_CLASS_EFFECTS_SOURCE_PATH]).replace(first_fragment, "")
	if _aura_writer_errors(deleted).is_empty():
		errors.append("mutation oracle accepted deletion of the extracted command_aura writer")
	var duplicated := sources.duplicate()
	duplicated[PLAYER_SOURCE_PATH] = str(duplicated[PLAYER_SOURCE_PATH]) + "\n" + first_fragment
	if _aura_writer_errors(duplicated).is_empty():
		errors.append("mutation oracle accepted a duplicated command_aura writer")
