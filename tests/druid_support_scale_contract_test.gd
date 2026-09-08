extends SceneTree

const ProgressionData := preload("res://scripts/progression_data.gd")

const MINION_SOURCE_PATH := "res://scripts/ally_minion.gd"
const PLAYER_SOURCE_PATH := "res://scripts/player.gd"
const PLAYER_COLLABORATOR_DIRECTORY_PATH := "res://scripts/player"
const PLAYER_CLASS_EFFECTS_SOURCE_PATH := "res://scripts/player/player_class_effects.gd"
const SIBLING_MUTATION_PATH := "res://scripts/player/player_damage_policy.gd"
const FORBIDDEN_MINION_FRAGMENTS := [
	"_druid_summon_support_multiplier",
	"_druid_summon_aura_radius",
	"StatusEffects.apply_status(self, \"command_aura\"",
	"StatusEffects.apply_status(self, \"wild_force_aura\"",
	"StatusEffects.apply_status(target, \"command_pressure\"",
]
const REQUIRED_AURA_WRITERS := [
	{
		"aura_id": "command_aura",
		"owner": PLAYER_CLASS_EFFECTS_SOURCE_PATH,
	},
	{
		"aura_id": "command_pressure",
		"owner": PLAYER_CLASS_EFFECTS_SOURCE_PATH,
	},
	{
		"aura_id": "wild_force_aura",
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
	var player_sources := _collect_player_ownership_sources(errors)
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
		var aura_id := str(requirement["aura_id"])
		var owner := str(requirement["owner"])
		var total := 0
		for path in sources:
			var count := _writer_count(str(sources[path]), aura_id)
			total += count
			if path == owner and count != 1:
				errors.append("Player-owned extracted implementation must contain exactly one writer for '%s'" % aura_id)
			elif path != owner and count != 0:
				errors.append("Player ownership surface has a duplicate writer for '%s' in %s" % [aura_id, path])
		if total != 1:
			errors.append("Player ownership surface must contain exactly one writer for '%s', found %d" % [aura_id, total])
	return errors


func _verify_aura_writer_mutations(sources: Dictionary, errors: Array[String]) -> void:
	if not sources.has(SIBLING_MUTATION_PATH):
		errors.append("Player ownership scanner did not discover sibling collaborator: %s" % SIBLING_MUTATION_PATH)
		return
	for requirement in REQUIRED_AURA_WRITERS:
		var aura_id := str(requirement["aura_id"])
		var deleted := sources.duplicate()
		deleted[PLAYER_CLASS_EFFECTS_SOURCE_PATH] = str(deleted[PLAYER_CLASS_EFFECTS_SOURCE_PATH]).replace("\"%s\"" % aura_id, "\"removed_%s\"" % aura_id)
		if _aura_writer_errors(deleted).is_empty():
			errors.append("mutation oracle accepted deletion of the extracted %s writer" % aura_id)
		var sibling_duplicate := sources.duplicate()
		sibling_duplicate[SIBLING_MUTATION_PATH] = str(sibling_duplicate[SIBLING_MUTATION_PATH]) + "\nStatusEffects.apply_status(sibling_alias, \"%s\", {})" % aura_id
		if _aura_writer_errors(sibling_duplicate).is_empty():
			errors.append("mutation oracle accepted sibling duplication of %s" % aura_id)
		var alias_duplicate := sources.duplicate()
		alias_duplicate[PLAYER_CLASS_EFFECTS_SOURCE_PATH] = str(alias_duplicate[PLAYER_CLASS_EFFECTS_SOURCE_PATH]) + "\nStatusEffects.apply_status(owner_alias, \"%s\", {})" % aura_id
		if _aura_writer_errors(alias_duplicate).is_empty():
			errors.append("mutation oracle accepted alias duplication of %s" % aura_id)


func _collect_player_ownership_sources(errors: Array[String]) -> Dictionary:
	var sources := {}
	_read_source(PLAYER_SOURCE_PATH, sources, errors)
	_collect_collaborator_sources(PLAYER_COLLABORATOR_DIRECTORY_PATH, sources, errors)
	return sources


func _collect_collaborator_sources(path: String, sources: Dictionary, errors: Array[String]) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		errors.append("Player ownership directory cannot be opened (fail closed): %s" % path)
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var child_path := path.path_join(entry)
			if directory.current_is_dir():
				_collect_collaborator_sources(child_path, sources, errors)
			elif entry.get_extension() == "gd":
				_read_source(child_path, sources, errors)
		entry = directory.get_next()
	directory.list_dir_end()


func _read_source(path: String, sources: Dictionary, errors: Array[String]) -> void:
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty():
		errors.append("Player ownership source cannot be read (fail closed): %s" % path)
		return
	sources[path] = source


func _writer_count(source: String, aura_id: String) -> int:
	var writer_regex := RegEx.new()
	writer_regex.compile("StatusEffects\\.apply_status\\s*\\(\\s*[^,\\n]+,\\s*\\\"%s\\\"" % aura_id)
	var count := 0
	for line in source.split("\n"):
		count += writer_regex.search_all(line.get_slice("#", 0)).size()
	return count
