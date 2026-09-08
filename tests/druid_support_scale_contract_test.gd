extends SceneTree

const ProgressionData := preload("res://scripts/progression_data.gd")

const MINION_SOURCE_PATH := "res://scripts/ally_minion.gd"
const PLAYER_SOURCE_PATH := "res://scripts/player.gd"
const PLAYER_COLLABORATOR_DIRECTORY_PATH := "res://scripts/player"
const PLAYER_CLASS_EFFECTS_SOURCE_PATH := "res://scripts/player/player_class_effects.gd"
const SIBLING_MUTATION_PATH := "res://scripts/player/player_damage_policy.gd"
const STATUS_WRITER_ENTRY_POINTS := ["apply_status", "apply_status_from"]
const STATUS_CALL_INVENTORY := {
	PLAYER_SOURCE_PATH: {
		"apply_status|enemy_node|\"knight_counter_stagger\"": 1,
		"apply_status|enemy_node|\"bastion_taunt\"": 1,
		"apply_status|enemy|\"soldier_suppressed_fire\"": 1,
		"apply_status|other_node|str(status.get(\"id\",\"spread_dot\"))": 1,
	},
	PLAYER_CLASS_EFFECTS_SOURCE_PATH: {
		"apply_status|enemy|\"constellation_suppression\"": 1,
		"apply_status|enemy|\"constellation_control\"": 1,
		"apply_status|enemy|\"arcane_vulnerability\"": 1,
		"apply_status_from|player|enemy|\"toxic_debuff\"": 1,
		"apply_status|enemy|\"staggered\"": 1,
		"apply_status|player|\"class_aura_focus\"": 1,
		"apply_status|ally_node|\"command_aura\"": 1,
		"apply_status|enemy_node|\"command_pressure\"": 1,
		"apply_status|ally_node|\"wild_force_aura\"": 1,
	},
}
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
	errors.append_array(_ownership_errors(player_sources))
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


func _ownership_errors(sources: Dictionary) -> Array[String]:
	var errors := _aura_writer_errors(sources)
	for expected_path in STATUS_CALL_INVENTORY:
		if not sources.has(expected_path):
			errors.append("Player status inventory source was not discovered: %s" % expected_path)
	for path in sources:
		var actual := _status_call_counts(str(sources[path]), errors, path)
		var expected: Dictionary = STATUS_CALL_INVENTORY.get(path, {})
		for identity in actual:
			if not expected.has(identity):
				errors.append("unaccounted Player status writer in %s: %s" % [path, identity])
			elif actual[identity] != expected[identity]:
				errors.append("changed Player status writer multiplicity in %s: %s is %d, inventory says %d" % [path, identity, actual[identity], expected[identity]])
		for identity in expected:
			if not actual.has(identity):
				errors.append("stale Player status inventory entry in %s: %s" % [path, identity])
	return errors


func _verify_aura_writer_mutations(sources: Dictionary, errors: Array[String]) -> void:
	if not sources.has(SIBLING_MUTATION_PATH):
		errors.append("Player ownership scanner did not discover sibling collaborator: %s" % SIBLING_MUTATION_PATH)
		return
	for requirement in REQUIRED_AURA_WRITERS:
		var aura_id := str(requirement["aura_id"])
		var deleted := sources.duplicate()
		deleted[PLAYER_CLASS_EFFECTS_SOURCE_PATH] = str(deleted[PLAYER_CLASS_EFFECTS_SOURCE_PATH]).replace("\"%s\"" % aura_id, "\"removed_%s\"" % aura_id)
		if _ownership_errors(deleted).is_empty():
			errors.append("mutation oracle accepted deletion of the extracted %s writer" % aura_id)
		var sibling_duplicate := sources.duplicate()
		sibling_duplicate[SIBLING_MUTATION_PATH] = str(sibling_duplicate[SIBLING_MUTATION_PATH]) + "\nStatusEffects.apply_status(sibling_alias, \"%s\", {})" % aura_id
		if _ownership_errors(sibling_duplicate).is_empty():
			errors.append("mutation oracle accepted sibling duplication of %s" % aura_id)
		var alias_duplicate := sources.duplicate()
		alias_duplicate[PLAYER_CLASS_EFFECTS_SOURCE_PATH] = str(alias_duplicate[PLAYER_CLASS_EFFECTS_SOURCE_PATH]) + "\nStatusEffects.apply_status(owner_alias, \"%s\", {})" % aura_id
		if _ownership_errors(alias_duplicate).is_empty():
			errors.append("mutation oracle accepted alias duplication of %s" % aura_id)
		var sourced_duplicate := sources.duplicate()
		sourced_duplicate[SIBLING_MUTATION_PATH] = str(sourced_duplicate[SIBLING_MUTATION_PATH]) + "\nStatusEffects.apply_status_from(source_alias, sibling_alias, \"%s\", {})" % aura_id
		if _ownership_errors(sourced_duplicate).is_empty():
			errors.append("mutation oracle accepted sourced duplication of %s" % aura_id)
		var multiline_duplicate := sources.duplicate()
		multiline_duplicate[SIBLING_MUTATION_PATH] = str(multiline_duplicate[SIBLING_MUTATION_PATH]) + "\nStatusEffects.apply_status(\n\tmultiline_alias,\n\t\"%s\",\n\t{}\n)" % aura_id
		if _ownership_errors(multiline_duplicate).is_empty():
			errors.append("mutation oracle accepted multiline duplication of %s" % aura_id)
		var multiline_sourced_duplicate := sources.duplicate()
		multiline_sourced_duplicate[SIBLING_MUTATION_PATH] = str(multiline_sourced_duplicate[SIBLING_MUTATION_PATH]) + "\nStatusEffects.apply_status_from(\n\tsource_alias,\n\tmultiline_alias,\n\t\"%s\",\n\t{}\n)" % aura_id
		if _ownership_errors(multiline_sourced_duplicate).is_empty():
			errors.append("mutation oracle accepted multiline sourced duplication of %s" % aura_id)
		var commented_duplicate := sources.duplicate()
		commented_duplicate[SIBLING_MUTATION_PATH] = str(commented_duplicate[SIBLING_MUTATION_PATH]) + "\n# StatusEffects.apply_status(alias, \"%s\", {})" % aura_id
		if not _ownership_errors(commented_duplicate).is_empty():
			errors.append("writer scanner stopped stripping comments for %s" % aura_id)
		var constant_duplicate := sources.duplicate()
		constant_duplicate[PLAYER_CLASS_EFFECTS_SOURCE_PATH] = str(constant_duplicate[PLAYER_CLASS_EFFECTS_SOURCE_PATH]) + "\nconst QA_%s := \"%s\"\nStatusEffects.apply_status(constant_target, QA_%s, {})" % [aura_id.to_upper(), aura_id, aura_id.to_upper()]
		if _ownership_errors(constant_duplicate).is_empty():
			errors.append("inventory accepted constant status ID duplication of %s" % aura_id)
		var runtime_duplicate := sources.duplicate()
		runtime_duplicate[SIBLING_MUTATION_PATH] = str(runtime_duplicate[SIBLING_MUTATION_PATH]) + "\nStatusEffects.apply_status(runtime_target, runtime_status_id, {})"
		if _ownership_errors(runtime_duplicate).is_empty():
			errors.append("inventory accepted runtime status ID beside %s" % aura_id)
		var comma_target_duplicate := sources.duplicate()
		comma_target_duplicate[SIBLING_MUTATION_PATH] = str(comma_target_duplicate[SIBLING_MUTATION_PATH]) + "\nStatusEffects.apply_status(get_node(\"a\", \"b\"), \"%s\", {})" % aura_id
		if _ownership_errors(comma_target_duplicate).is_empty():
			errors.append("inventory accepted comma-target duplication of %s" % aura_id)
	var non_aura_duplicate := sources.duplicate()
	non_aura_duplicate[PLAYER_CLASS_EFFECTS_SOURCE_PATH] = str(non_aura_duplicate[PLAYER_CLASS_EFFECTS_SOURCE_PATH]) + "\nStatusEffects.apply_status(enemy, \"staggered\", {})"
	if _ownership_errors(non_aura_duplicate).is_empty():
		errors.append("inventory accepted duplication beside accounted non-aura writer")
	var changed_non_aura := sources.duplicate()
	changed_non_aura[PLAYER_CLASS_EFFECTS_SOURCE_PATH] = str(changed_non_aura[PLAYER_CLASS_EFFECTS_SOURCE_PATH]).replace("StatusEffects.apply_status(enemy, \"staggered\"", "StatusEffects.apply_status(enemy, \"changed_staggered\"")
	if _ownership_errors(changed_non_aura).is_empty():
		errors.append("inventory accepted a changed accounted non-aura writer")


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
	var comment_free_source := _without_comments(source)
	var count := 0
	for entry_point in STATUS_WRITER_ENTRY_POINTS:
		var writer_regex := RegEx.new()
		var leading_arguments := "[^,]+,\\s*" if entry_point == "apply_status" else "[^,]+,\\s*[^,]+,\\s*"
		writer_regex.compile("StatusEffects\\.%s\\s*\\(\\s*%s\\\"%s\\\"" % [entry_point, leading_arguments, aura_id])
		count += writer_regex.search_all(comment_free_source).size()
	return count


func _status_call_counts(source: String, errors: Array[String], path: String) -> Dictionary:
	var counts := {}
	var comment_free_source := _without_comments(source)
	var call_regex := RegEx.new()
	call_regex.compile("StatusEffects\\.(apply_status_from|apply_status)\\s*\\(")
	for match in call_regex.search_all(comment_free_source):
		var entry_point := match.get_string(1)
		var open_parenthesis := comment_free_source.find("(", match.get_start())
		var close_parenthesis := _matching_parenthesis(comment_free_source, open_parenthesis)
		if close_parenthesis < 0:
			errors.append("unterminated Player status writer in %s" % path)
			continue
		var arguments := _split_top_level_arguments(comment_free_source.substr(open_parenthesis + 1, close_parenthesis - open_parenthesis - 1))
		var identity_argument_count := 2 if entry_point == "apply_status" else 3
		if arguments.size() != identity_argument_count + 1:
			errors.append("unexpected Player status writer arity in %s: %s" % [path, entry_point])
			continue
		var identity := entry_point
		for argument_index in range(identity_argument_count):
			identity += "|" + _normalized_argument(str(arguments[argument_index]))
		counts[identity] = int(counts.get(identity, 0)) + 1
	return counts


func _matching_parenthesis(source: String, opening_index: int) -> int:
	var depth := 0
	var quote := ""
	var escaped := false
	for index in range(opening_index, source.length()):
		var character := source[index]
		if not quote.is_empty():
			if escaped:
				escaped = false
			elif character == "\\\\":
				escaped = true
			elif character == quote:
				quote = ""
			continue
		if character == "\"" or character == "'":
			quote = character
		elif character == "(":
			depth += 1
		elif character == ")":
			depth -= 1
			if depth == 0:
				return index
	return -1


func _split_top_level_arguments(arguments_source: String) -> Array[String]:
	var arguments: Array[String] = []
	var current_argument := ""
	var depth := 0
	var quote := ""
	var escaped := false
	for index in range(arguments_source.length()):
		var character := arguments_source[index]
		if not quote.is_empty():
			current_argument += character
			if escaped:
				escaped = false
			elif character == "\\\\":
				escaped = true
			elif character == quote:
				quote = ""
			continue
		if character == "\"" or character == "'":
			quote = character
			current_argument += character
		elif character == "(" or character == "[" or character == "{":
			depth += 1
			current_argument += character
		elif character == ")" or character == "]" or character == "}":
			depth -= 1
			current_argument += character
		elif character == "," and depth == 0:
			arguments.append(current_argument.strip_edges())
			current_argument = ""
		else:
			current_argument += character
	arguments.append(current_argument.strip_edges())
	return arguments


func _normalized_argument(argument: String) -> String:
	var whitespace_regex := RegEx.new()
	whitespace_regex.compile("\\s+")
	return whitespace_regex.sub(argument, "", true)


func _without_comments(source: String) -> String:
	var comment_free_lines: Array[String] = []
	for line in source.split("\n"):
		comment_free_lines.append(line.get_slice("#", 0))
	return " ".join(comment_free_lines)
