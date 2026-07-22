extends SceneTree

# FAN-1438: reproducible A5 roster report. One canonical dataset renders the
# Markdown, CSV, and raw JSON artifacts; production balance values are read-only.

const PD := preload("res://scripts/progression_data.gd")
const Meta := preload("res://scripts/meta_progression.gd")
const PlayerScript := preload("res://scripts/player.gd")
const Schema6 := preload("res://scripts/constellation_schema6_data.gd")
const FinalRuntime := preload("res://scripts/constellation_final_runtime.gd")
const MainScript := preload("res://scripts/main.gd")
const DamageTable := preload("res://tools/class_damage_table_3variants.gd")
const CodexData := preload("res://scripts/codex_data.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")

const ISSUE_ID := "FAN-1438"
const REPORT_DIR := "res://docs/design/reports/fan1438_a5_balance"
const REPORT_PATH := REPORT_DIR + "/report.md"
const CSV_PATH := REPORT_DIR + "/per_weapon.csv"
const RAW_PATH := REPORT_DIR + "/raw.json"
const LEVELS := [1, 20]
const LEVEL20_POINTS := 19
const TARGET_COUNT := 10
const SCENARIO_IDS := ["no_meta", "class_constellation", "class_atlas50", "class_atlas59_upper"]
const ATLAS50_EXCLUSIONS := ["atlas_m2", "atlas_m3", "atlas_k0"]
const NON_PLAYABLE_LABEL := "NON-PLAYABLE: cap 50"
const LIVE_SEEDS := [143801, 143802, 143803]
const LIVE_WARMUP_SECONDS := 2.0
const LIVE_WINDOW_SECONDS := 6.0
const MAX_LIVE_FRAMES := 2400
const DUMMY_HP := 1.0e9
const PLAYER_POSITION := Vector2(1280.0, 720.0)
const SOLO_OFFSET := Vector2(80.0, 0.0)
const PACK_RADIUS := 42.0
const A5_NORMAL_CONTACT_DAMAGE := 6.0
const A5_NORMAL_CONTACT_RATE := 5.0
const PLAYER_IFRAME_SECONDS := 0.32

var _mode := "full"
var _source_commit := "UNSPECIFIED"
var _source_tree := ""
var _source_timestamp := ""
var _holder: Node2D
var _errors := PackedStringArray()


func _initialize() -> void:
	_parse_args()
	await process_frame
	if _mode == "full":
		_holder = Node2D.new()
		_holder.name = "FAN1438BalanceHolder"
		root.add_child(_holder)
		current_scene = _holder
		root.set_meta("aim_mode", "nearest")
		await process_frame
	var dataset := await generate_dataset()
	if not _errors.is_empty():
		for error in _errors:
			push_error(error)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_DIR))
	var csv_text := _csv(dataset)
	var markdown_text := _markdown(dataset)
	var raw_text := JSON.stringify(dataset, "\t", true, true) + "\n"
	_write_text(CSV_PATH, csv_text)
	_write_text(REPORT_PATH, markdown_text)
	_write_text(RAW_PATH, raw_text)
	if not _errors.is_empty():
		for error in _errors:
			push_error(error)
		quit(1)
		return
	print("FAN-1438 report generated: %d weapon rows, %d class rows, %d live parity rows." % [
		(dataset.get("weapon_rows", []) as Array).size(),
		(dataset.get("class_rows", []) as Array).size(),
		(dataset.get("formula_live_parity", []) as Array).size(),
	])
	quit(0)


func _parse_args() -> void:
	for raw_arg in OS.get_cmdline_user_args():
		var arg := str(raw_arg)
		if arg.begins_with("--mode="):
			_mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--source-commit="):
			_source_commit = arg.trim_prefix("--source-commit=")
		elif arg.begins_with("--source-tree=") or arg.begins_with("--source-timestamp="):
			_errors.append("%s is derived from --source-commit and cannot be overridden" % arg.get_slice("=", 0))
	if not ["formula", "full"].has(_mode):
		_errors.append("unsupported mode %s (expected formula or full)" % _mode)


func generate_dataset() -> Dictionary:
	if not _resolve_source_provenance():
		return {}
	var class_ids: Array = PD.character_ids()
	var pair_keys := []
	var builds := {}
	for class_id_value in class_ids:
		var class_id := str(class_id_value)
		for weapon_id_value in PD.weapon_ids(class_id):
			pair_keys.append("%s/%s" % [class_id, str(weapon_id_value)])
		var base_stats := PD.base_stats(class_id)
		var level20_stats := DamageTable.optimized_stats_for_class(class_id, base_stats)
		builds[class_id] = {
			"level1_stats": base_stats,
			"level20_stats": level20_stats,
			"level20_delta": _stat_delta(base_stats, level20_stats),
			"level20_points": _delta_sum(base_stats, level20_stats),
			"model": "synthetic shared class-trio allocation",
		}

	var scenarios := _scenario_manifest()
	var meta_builds := _meta_build_manifest(class_ids)
	var weapon_rows := []
	for class_id_value in class_ids:
		var class_id := str(class_id_value)
		for level in LEVELS:
			var stats: Dictionary = (builds[class_id]["level1_stats"] if level == 1 else builds[class_id]["level20_stats"]).duplicate(true)
			for scenario_id in SCENARIO_IDS:
				var state := _scenario_state(class_id, scenario_id)
				for weapon_id_value in PD.weapon_ids(class_id):
					weapon_rows.append(_weapon_row(class_id, str(weapon_id_value), level, scenario_id, stats, state, scenarios[scenario_id]))
	_apply_baseline_deltas(weapon_rows)
	_apply_atlas_deltas(weapon_rows)
	var class_rows := _class_rows(class_ids, weapon_rows)
	_apply_class_relative_scores(class_rows)
	var parity := []
	if _mode == "full":
		parity = await _live_parity(class_ids, builds, weapon_rows)
		_apply_live_evidence_to_rows(weapon_rows, parity)

	var methodology := {
		"ascension": "selected A5 and cumulative earned A1-A5 class rewards (reward tier 5)",
		"level1": "base stats; zero level-up points, artifacts, shop upgrades, boons, challenges, or sandbox modifiers",
		"level20": "exactly 19 nonnegative integer points across canonical base stats, greedily maximizing the mean normalized output of the class's three weapons; one shared allocation per class",
		"weapon_dpm": "canonical ProgressionData estimator with A5/meta run modifiers and include_ultimate=false; schema-6 owning-weapon flat/cadence/geometry/axis/final factors layered from the canonical profile",
		"modifier_order": "ascension reward multipliers multiply and flats add; A5 reward/healing/max-HP multipliers then apply; meta fractions become 1+sum and multiply the matching run modifier; flats add; owning-weapon profile remains isolated by exact weapon_id",
		"ultimate": "class-kit-only first-minute formula starts from unmodified level stats and applies class/Atlas attribute and run modifiers exactly once; it is never attributed to a weapon row",
		"targets": {"solo": [SOLO_OFFSET.x, SOLO_OFFSET.y], "pack_count": TARGET_COUNT, "pack_radius": PACK_RADIUS, "layout": "one primary east target plus deterministic compact golden-angle pack"},
		"live": {"mode": _mode, "seeds": LIVE_SEEDS, "runs": LIVE_SEEDS.size(), "warmup_seconds": LIVE_WARMUP_SECONDS, "measurement_seconds": LIVE_WINDOW_SECONDS, "dummy_hp": DUMMY_HP, "stationary": true},
		"survivability": {"threat": "normal-wave contact pressure only", "base_hit": A5_NORMAL_CONTACT_DAMAGE, "attempted_hits_per_second": A5_NORMAL_CONTACT_RATE, "player_iframe_seconds": PLAYER_IFRAME_SECONDS, "a5_enemy_damage_multiplier": PD.ascension_difficulty_mods(5).get("enemy_damage_mult", 1.0), "order": "flat absorb (42% hit floor), defense, expected dodge, sustain; one death-save event is added separately"},
	}
	var dataset := {
		"schema": "fan1438.a5-balance.v1",
		"issue_id": ISSUE_ID,
		"source": {"commit": _source_commit, "tree": _source_tree, "commit_timestamp": _source_timestamp, "godot": Engine.get_version_info().get("string", "unknown")},
		"generation_command": "python3 tools/godot_gate.py --headless --fixed-fps 60 --path . --script res://tools/a5_balance_report.gd -- --mode=full --source-commit=<A>",
		"roster": {"class_ids": class_ids, "pair_keys": pair_keys, "class_count": class_ids.size(), "weapon_pair_count": pair_keys.size()},
		"methodology": methodology,
		"builds": builds,
		"meta_builds": meta_builds,
		"scenarios": scenarios,
		"weapon_rows": weapon_rows,
		"class_rows": class_rows,
		"formula_live_parity": parity,
		"outliers": _outliers(class_rows, parity),
		"limitations": [
			"The level-20 model is a synthetic 19-base-stat-point balance convention, not a replay of 19 live reward-card choices.",
			"Selected A5 and earned reward tier are separate runtime states; this controlled report intentionally sets both to 5.",
			"The formula estimates persistent throughput. Live probes are authoritative for nonlinear mechanics, but infinite-HP dummies cannot exercise kill/execute/death-transfer cadence.",
			"Control, taunt, timed absorb, one-hit wards, and enemy damage suppression are reported as conditional utility and are not silently converted into permanent shield HP.",
			"A5 survival uses normal-wave global damage scaling. Bosses/elites have different runtime consumers and are not conflated with this threat.",
		],
	}
	dataset["dataset_digest_sha256"] = _sha256(JSON.stringify(dataset, "", true, true))
	_validate_dataset(dataset)
	return dataset


func _resolve_source_provenance() -> bool:
	var result := resolve_source_provenance(_source_commit)
	if not bool(result.get("ok", false)):
		_errors.append(str(result.get("error", "cannot resolve source provenance")))
		return false
	var source: Dictionary = result.get("source", {})
	_source_commit = str(source.get("commit", ""))
	_source_tree = str(source.get("tree", ""))
	_source_timestamp = str(source.get("commit_timestamp", ""))
	return true


static func resolve_source_provenance(source_commit: String) -> Dictionary:
	var requested := source_commit.strip_edges()
	if requested.is_empty() or requested == "UNSPECIFIED":
		return {"ok": false, "error": "--source-commit must name an exact Git commit"}
	var output := []
	var exit_code := OS.execute("git", ["show", "-s", "--format=%H%n%T%n%cI", requested], output, false)
	if exit_code != 0:
		return {"ok": false, "error": "cannot resolve Git source commit %s (git show exit %d)" % [requested, exit_code]}
	var fields := "".join(PackedStringArray(output)).strip_edges().split("\n", false)
	if fields.size() != 3:
		return {"ok": false, "error": "Git source provenance for %s is malformed" % requested}
	var source := {"commit": str(fields[0]), "tree": str(fields[1]), "commit_timestamp": str(fields[2])}
	if not _is_git_object_id(str(source["commit"])) or not _is_git_object_id(str(source["tree"])) or not _is_iso_timestamp(str(source["commit_timestamp"])):
		return {"ok": false, "error": "Git source provenance for %s is incomplete or malformed" % requested}
	return {"ok": true, "source": source}


static func verify_source_provenance(source: Dictionary) -> Dictionary:
	var result := resolve_source_provenance(str(source.get("commit", "")))
	if not bool(result.get("ok", false)):
		return result
	var expected: Dictionary = result.get("source", {})
	for field in ["commit", "tree", "commit_timestamp"]:
		if str(source.get(field, "")) != str(expected.get(field, "")):
			return {"ok": false, "error": "source %s does not match its Git commit" % field}
	return {"ok": true, "source": expected}


static func _is_git_object_id(value: String) -> bool:
	if value.length() != 40:
		return false
	for character in value:
		if not (character >= "0" and character <= "9") and not (character >= "a" and character <= "f"):
			return false
	return true


static func _is_iso_timestamp(value: String) -> bool:
	return value.length() >= 20 and value.contains("T") and (value.ends_with("Z") or value.contains("+"))


func _scenario_manifest() -> Dictionary:
	var atlas_paid := _atlas_paid_ids()
	var atlas50 := []
	for node_id in atlas_paid:
		if not ATLAS50_EXCLUSIONS.has(str(node_id)):
			atlas50.append(str(node_id))
	return {
		"no_meta": {"label": "No meta control", "playable": true, "class_spend": 0, "atlas_spend": 0, "atlas_ids": [], "hidden_conditions": []},
		"class_constellation": {"label": "Full class constellation (schema 6)", "playable": true, "class_spend": 20, "atlas_spend": 0, "atlas_ids": [], "hidden_conditions": ["both class hidden reveal facts explicitly true"]},
		"class_atlas50": {"label": "Full class + legal Guild Atlas 50", "playable": true, "class_spend": 20, "atlas_spend": _node_cost(atlas50), "atlas_ids": atlas50, "excluded_ids": ATLAS50_EXCLUSIONS, "hidden_conditions": ["all canonical monster Codex entries discovered", "secret boss defeated"]},
		"class_atlas59_upper": {"label": NON_PLAYABLE_LABEL, "playable": false, "class_spend": 20, "atlas_spend": _node_cost(atlas_paid), "atlas_ids": atlas_paid, "hidden_conditions": ["all canonical monster Codex entries discovered", "secret boss defeated"]},
	}


func _meta_build_manifest(class_ids: Array) -> Dictionary:
	var result := {}
	for class_id_value in class_ids:
		var class_id := str(class_id_value)
		var purchased := []
		var hidden := []
		var core := ""
		for raw_node in Meta.constellation_nodes(class_id):
			var node: Dictionary = raw_node
			var node_id := str(node.get("id", ""))
			if str(node.get("role", "")) == "core":
				core = node_id
			else:
				purchased.append(node_id)
			if str(node.get("role", "")) == "hidden":
				hidden.append(node_id)
		purchased.sort()
		hidden.sort()
		result[class_id] = {"free_core_id": core, "purchased_ids": purchased, "spend": _node_cost(purchased), "hidden_reveal_facts": hidden, "weapon_profile_node_ids": {}}
		var state := _scenario_state(class_id, "class_constellation")
		for weapon_id_value in PD.weapon_ids(class_id):
			var weapon_id := str(weapon_id_value)
			result[class_id]["weapon_profile_node_ids"][weapon_id] = Meta.skill_modifiers_for_weapon(state, class_id, weapon_id).get("node_ids", [])
	return result


func _scenario_state(class_id: String, scenario_id: String) -> Dictionary:
	var state := Meta.default_state()
	state["ascension_levels"] = {class_id: 5}
	if scenario_id == "no_meta":
		return state
	var purchased := []
	var hidden_ids := []
	for raw_node in Meta.constellation_nodes(class_id):
		var node: Dictionary = raw_node
		var node_id := str(node.get("id", ""))
		if str(node.get("role", "")) != "core":
			purchased.append(node_id)
		if str(node.get("role", "")) == "hidden":
			hidden_ids.append(node_id)
	state["hidden_reveal_facts"] = {class_id: hidden_ids}
	if scenario_id in ["class_atlas50", "class_atlas59_upper"]:
		var ids := _atlas_paid_ids()
		for node_id in ids:
			if scenario_id == "class_atlas50" and ATLAS50_EXCLUSIONS.has(str(node_id)):
				continue
			purchased.append(str(node_id))
		var monster_ids := []
		for raw_monster in CodexData.monsters():
			monster_ids.append(str((raw_monster as Dictionary).get("id", "")))
		state["discovered_monsters"] = monster_ids
		state["secret_boss_defeated"] = true
	state["skill_nodes"] = purchased
	return state


func _weapon_row(class_id: String, weapon_id: String, level: int, scenario_id: String, raw_stats: Dictionary, state: Dictionary, scenario: Dictionary) -> Dictionary:
	var stats := raw_stats.duplicate(true)
	var run_mods := _a5_run_modifiers(class_id)
	var skill_mods := {}
	var profile := {}
	if scenario_id != "no_meta":
		skill_mods = Meta.skill_modifiers_for_class(state, class_id)
		_apply_meta_formula_mods(stats, run_mods, skill_mods)
		profile = Meta.skill_modifiers_for_weapon(state, class_id, weapon_id)
	var config := PD.weapon(class_id, weapon_id)
	var base_metrics := PD.estimate_weapon_budget_for_stats(class_id, config, stats, true, run_mods, false)
	var crowd_metrics := PD.estimate_crowd_clear_budget_for_stats(class_id, config, TARGET_COUNT, stats, true, run_mods, false)
	var profile_factors := _profile_factors(class_id, weapon_id, config, stats, run_mods, profile)
	var solo_dps := float(base_metrics.get("solo_dps", 0.0)) * float(profile_factors.get("solo", 1.0))
	var crowd_dps := float(crowd_metrics.get("crowd_dps", 0.0)) * float(profile_factors.get("crowd", 1.0))
	var params := PD.derived_parameters(stats, run_mods, _config_with_class(config, class_id))
	var survival := _survival_metrics(config, params, run_mods, skill_mods, profile)
	var branch := _schema_branch(class_id, weapon_id)
	var final_node := _final_node(branch)
	return {
		"key": "%s|%s|%d|%s" % [class_id, weapon_id, level, scenario_id],
		"class_id": class_id,
		"weapon_id": weapon_id,
		"level": level,
		"scenario": scenario_id,
		"scenario_label": scenario.get("label", scenario_id),
		"playable": bool(scenario.get("playable", true)),
		"attack_mode": str(config.get("attack_mode", config.get("attack_shape", "single"))),
		"archetype": PD.weapon_archetype(config),
		"axis": str(branch.get("axis", "")),
		"identity": str(branch.get("identity", "")),
		"playstyle": str(branch.get("identity", "")),
		"strengths": _weapon_strength(str(branch.get("axis", "")), str(branch.get("identity", ""))),
		"weaknesses": _weapon_weakness(str(branch.get("axis", ""))),
		"final_mechanic": str(final_node.get("mechanic_id", "none")),
		"final_event": str(FinalRuntime.EVENT_BY_MECHANIC.get(str(final_node.get("mechanic_id", "")), "none")),
		"stats": stats,
		"stat_delta": _stat_delta(PD.base_stats(class_id), raw_stats),
		"solo_dpm": snappedf(solo_dps * 60.0, 0.01),
		"crowd_10_total_dpm": snappedf(crowd_dps * 60.0, 0.01),
		"crowd_10_per_target_dpm": snappedf(crowd_dps * 6.0, 0.01),
		"profile_factors": profile_factors,
		"ultimate_included": false,
		"hp": survival["hp"], "defense": survival["defense"], "dodge": survival["dodge"],
		"absorb_flat": survival["absorb_flat"], "conditional_shield_capacity": survival["conditional_shield_capacity"],
		"regeneration_per_second": survival["regeneration_per_second"], "lifesteal_per_second": survival["lifesteal_per_second"],
		"mitigation": survival["mitigation"], "ehp": survival["ehp"], "ttd_seconds": survival["ttd_seconds"],
		"conditional_defense_factor": survival["conditional_defense_factor"],
		"pickup_radius": snappedf(float(params.get("pickup_radius", 0.0)), 0.01),
		"move_speed": snappedf(float(params.get("move_speed", 0.0)), 0.01),
		"healing_multiplier": snappedf(float(run_mods.get("healing_multiplier", 1.0)) * (1.0 + float(skill_mods.get("healing_mult", 0.0))), 0.001),
		"xp_multiplier": snappedf(float(run_mods.get("xp_gain_multiplier", 1.0)) * (1.0 + float(skill_mods.get("xp_gain_mult", 0.0))), 0.001),
		"money_multiplier": snappedf(float(run_mods.get("money_gain_multiplier", 1.0)) * (1.0 + float(skill_mods.get("money_gain_mult", 0.0))), 0.001),
		"start_gold": snappedf(float(skill_mods.get("start_gold_flat", 0.0)), 0.01),
		"ult_start_charge": snappedf(float(skill_mods.get("ult_start_charge", 0.0)), 0.01),
		"death_save": float(skill_mods.get("death_save", 0.0)) > 0.0,
		"death_save_health_fraction": snappedf(float(skill_mods.get("death_save_health_fraction", 0.0)), 0.01),
		"measurement_method": "deterministic_formula_expected_value",
		"runs": 1,
		"solo_variance_dpm2": 0.0,
		"crowd_variance_dpm2": 0.0,
	}


func _a5_run_modifiers(class_id: String) -> Dictionary:
	var run_mods := {}
	for key_value in PD.ascension_mods(class_id, 5).keys():
		var key := str(key_value)
		var value := float(PD.ascension_mods(class_id, 5)[key_value])
		if key.ends_with("_multiplier"):
			run_mods[key] = float(run_mods.get(key, 1.0)) * value
		else:
			run_mods[key] = float(run_mods.get(key, 0.0)) + value
	var difficulty := PD.ascension_difficulty_mods(5)
	run_mods["xp_gain_multiplier"] = float(run_mods.get("xp_gain_multiplier", 1.0)) * float(difficulty.get("reward_mult", 1.0))
	run_mods["money_gain_multiplier"] = float(run_mods.get("money_gain_multiplier", 1.0)) * float(difficulty.get("reward_mult", 1.0))
	run_mods["healing_multiplier"] = float(run_mods.get("healing_multiplier", 1.0)) * float(difficulty.get("healing_mult", 1.0))
	run_mods["max_health_multiplier"] = float(run_mods.get("max_health_multiplier", 1.0)) * float(difficulty.get("player_max_hp_mult", 1.0))
	return run_mods


func _apply_meta_formula_mods(stats: Dictionary, run_mods: Dictionary, mods: Dictionary) -> void:
	for source_key in PlayerScript.META_SKILL_ATTRIBUTE_FLAT_MAP:
		if mods.has(source_key):
			var stat_key := str(PlayerScript.META_SKILL_ATTRIBUTE_FLAT_MAP[source_key])
			stats[stat_key] = float(stats.get(stat_key, 0.0)) + float(mods[source_key])
	for source_key in PlayerScript.META_SKILL_MULT_MAP:
		if mods.has(source_key):
			var run_key := str(PlayerScript.META_SKILL_MULT_MAP[source_key])
			run_mods[run_key] = float(run_mods.get(run_key, 1.0)) * (1.0 + float(mods[source_key]))
	for source_key in PlayerScript.META_SKILL_FLAT_MAP:
		if mods.has(source_key):
			var run_key := str(PlayerScript.META_SKILL_FLAT_MAP[source_key])
			run_mods[run_key] = float(run_mods.get(run_key, 0.0)) + float(mods[source_key])


func _profile_factors(class_id: String, weapon_id: String, config: Dictionary, stats: Dictionary, run_mods: Dictionary, profile: Dictionary) -> Dictionary:
	if profile.is_empty() or (profile.get("node_ids", []) as Array).is_empty():
		return {"solo": 1.0, "crowd": 1.0, "flat": 1.0, "cadence": 1.0, "geometry": 1.0, "axis": 1.0, "final": 1.0}
	var amounts: Dictionary = profile.get("amounts", {})
	var multipliers: Dictionary = profile.get("multipliers", {})
	var params := PD.derived_parameters(stats, run_mods, _config_with_class(config, class_id))
	var damage_parameter := str(config.get("damage_parameter", PD.damage_parameter_for(class_id)))
	var base_damage := maxf(float(params.get(damage_parameter, params.get("damage", 1.0))), 0.001)
	var flat_factor := (base_damage + float(amounts.get("weapon_damage_flat", 0.0))) / base_damage
	var cadence := float(multipliers.get("weapon_attack_speed_mult", 1.0))
	var identity := float(multipliers.get("weapon_prefinal_identity_mult", 1.0))
	var axis := str(profile.get("axis", ""))
	var axis_factor := 1.0
	if axis == "solo":
		axis_factor *= float(multipliers.get("precision_window_mult", 1.0))
		axis_factor *= float(multipliers.get("hidden_solo_mastery_mult", 1.0))
	var geometry := 1.0
	for key in ["range_or_precision_zone_mult", "arc_chain_or_zone_geometry_mult", "guard_control_zone_mult", "radius_or_blast_geometry_mult", "impact_area_mult"]:
		geometry *= float(multipliers.get(key, 1.0))
	if axis == "crowd":
		geometry *= float(multipliers.get("target_pattern_budget_mult", 1.0))
		geometry *= float(multipliers.get("hidden_crowd_mastery_mult", 1.0))
	elif axis == "aoe":
		geometry *= float(multipliers.get("hidden_aoe_mastery_mult", 1.0))
	var final_node := _final_node(_schema_branch(class_id, weapon_id))
	var final_factor := maxf(float(final_node.get("gain_over_order_5_min", 1.0)), 1.0)
	var solo_final := final_factor if axis == "solo" else 1.0
	var crowd_final := final_factor if axis in ["crowd", "aoe"] else 1.0
	return {
		"solo": snappedf(flat_factor * cadence * identity * axis_factor * solo_final, 0.0001),
		"crowd": snappedf(flat_factor * cadence * identity * geometry * crowd_final, 0.0001),
		"flat": snappedf(flat_factor, 0.0001), "cadence": snappedf(cadence, 0.0001),
		"geometry": snappedf(geometry, 0.0001), "axis": snappedf(axis_factor, 0.0001), "final": snappedf(final_factor, 0.0001),
	}


func _survival_metrics(config: Dictionary, params: Dictionary, run_mods: Dictionary, skill_mods: Dictionary, profile: Dictionary) -> Dictionary:
	var hp := maxf(float(params.get("health_point", 1.0)), 1.0)
	var defense := clampf(float(params.get("defense", 0.0)), 0.0, PD.SURVIVABILITY_DEFENSE_CAP)
	var dodge := clampf(float(params.get("dodge", 0.0)), 0.0, PD.SURVIVABILITY_DODGE_CAP)
	var absorb := maxf(float(params.get("absorb", 0.0)), 0.0)
	var difficulty := PD.ascension_difficulty_mods(5)
	var raw_hit := A5_NORMAL_CONTACT_DAMAGE * float(difficulty.get("enemy_damage_mult", 1.0))
	var landed_rate := minf(A5_NORMAL_CONTACT_RATE, 1.0 / PLAYER_IFRAME_SECONDS)
	var post_absorb := maxf(raw_hit - absorb, raw_hit * PD.SURVIVABILITY_ABSORB_MIN_DAMAGE_FRACTION)
	var incoming := post_absorb * (1.0 - defense) * (1.0 - dodge) * landed_rate
	var raw_dps := raw_hit * landed_rate
	var healing_multiplier := float(run_mods.get("healing_multiplier", 1.0)) * (1.0 + float(skill_mods.get("healing_mult", 0.0)))
	var regen := maxf(float(params.get("regeneration", 0.0)), 0.0) * healing_multiplier
	var interval := maxf(float(config.get("fire_interval", 1.0)) / maxf(float(params.get("attack_speed", 1.0)), 0.1), 0.18)
	var lifesteal := (
		float(config.get("heal_percent_of_damage", 0.0)) * maxf(float(params.get("damage", 0.0)), float(params.get("magic_damage", 0.0))) / interval
		+ float(config.get("heal_percent_on_attack", 0.0)) * hp / interval
	) * PD.WEAPON_DRAIN_HEAL_MULTIPLIER * healing_multiplier
	var sustain := regen + maxf(lifesteal, 0.0)
	var net_dps := maxf(incoming - sustain, 0.01)
	var death_fraction := float(skill_mods.get("death_save_health_fraction", 0.0)) if float(skill_mods.get("death_save", 0.0)) > 0.0 else 0.0
	var ttd := hp / net_dps + (2.0 + hp * death_fraction / net_dps if death_fraction > 0.0 else 0.0)
	var conditional_factor := 1.0
	var shield_capacity := 0.0
	if not profile.is_empty() and str(profile.get("axis", "")) == "defense":
		conditional_factor = maxf(float(_final_node(_schema_branch(str(profile.get("class_id", "")), str(profile.get("weapon_id", "")))).get("gain_over_order_5_min", 1.0)), 1.0)
	var mechanics: Dictionary = profile.get("mechanics", {})
	for mechanic_id in mechanics:
		var mechanic: Dictionary = mechanics[mechanic_id]
		var mechanic_params: Dictionary = mechanic.get("params", {})
		for cap_key in ["shield_cap", "absorb_cap", "stored_damage_cap"]:
			shield_capacity = maxf(shield_capacity, float(mechanic_params.get(cap_key, 0.0)))
	return {
		"hp": snappedf(hp, 0.01), "defense": snappedf(defense, 0.0001), "dodge": snappedf(dodge, 0.0001),
		"absorb_flat": snappedf(absorb, 0.01), "conditional_shield_capacity": snappedf(shield_capacity, 0.01),
		"regeneration_per_second": snappedf(regen, 0.01), "lifesteal_per_second": snappedf(lifesteal, 0.01),
		"mitigation": snappedf(1.0 - incoming / maxf(raw_dps, 0.001), 0.0001),
		"ehp": snappedf(hp * raw_dps / maxf(incoming, 0.01), 0.01),
		"ttd_seconds": snappedf(ttd, 0.01), "conditional_defense_factor": snappedf(conditional_factor, 0.01),
	}


func _apply_baseline_deltas(rows: Array) -> void:
	var baselines := {}
	for row in rows:
		if str(row.get("scenario", "")) == "no_meta":
			baselines["%s|%s|%d" % [row["class_id"], row["weapon_id"], row["level"]]] = row
	for row in rows:
		var baseline: Dictionary = baselines["%s|%s|%d" % [row["class_id"], row["weapon_id"], row["level"]]]
		for metric in ["solo_dpm", "crowd_10_total_dpm", "ehp", "ttd_seconds", "pickup_radius", "move_speed"]:
			var delta := float(row[metric]) - float(baseline[metric])
			row["%s_delta_abs" % metric] = snappedf(delta, 0.01)
			row["%s_delta_pct" % metric] = snappedf(delta / maxf(absf(float(baseline[metric])), 0.001) * 100.0, 0.01)


func _apply_atlas_deltas(rows: Array) -> void:
	var constellation_rows := {}
	for row in rows:
		if str(row.get("scenario", "")) == "class_constellation":
			constellation_rows["%s|%s|%d" % [row["class_id"], row["weapon_id"], row["level"]]] = row
	for row in rows:
		var reference: Dictionary = constellation_rows["%s|%s|%d" % [row["class_id"], row["weapon_id"], row["level"]]]
		var deltas := {}
		for metric in ["solo_dpm", "crowd_10_total_dpm", "pickup_radius", "move_speed", "ehp", "ttd_seconds", "healing_multiplier", "start_gold", "ult_start_charge"]:
			deltas[metric] = snappedf(float(row.get(metric, 0.0)) - float(reference.get(metric, 0.0)), 0.01)
		row["atlas_delta_vs_class_constellation"] = deltas
		row["atlas_delta_summary"] = _atlas_delta_summary(str(row.get("scenario", "")), deltas, bool(row.get("death_save", false)) and not bool(reference.get("death_save", false)))


func _atlas_delta_summary(scenario_id: String, deltas: Dictionary, adds_death_save: bool) -> String:
	if scenario_id not in ["class_atlas50", "class_atlas59_upper"]:
		return "n/a"
	var parts := PackedStringArray()
	for metric in ["solo_dpm", "crowd_10_total_dpm", "pickup_radius", "move_speed", "ehp", "ttd_seconds", "healing_multiplier", "start_gold", "ult_start_charge"]:
		var value := float(deltas.get(metric, 0.0))
		if not is_zero_approx(value):
			parts.append("%s %+.2f" % [metric, value])
	if adds_death_save:
		parts.append("death_save +1")
	return "no measured delta" if parts.is_empty() else "; ".join(parts)


func _class_rows(class_ids: Array, weapon_rows: Array) -> Array:
	var result := []
	for class_id_value in class_ids:
		var class_id := str(class_id_value)
		for level in LEVELS:
			# Weapon rows retain their scenario-adjusted stats for per-weapon metrics.
			# The class ultimate must instead begin with the controlled no-meta level
			# stats, then apply the class/Atlas modifier order once below.
			var level_stats: Dictionary = {}
			for candidate_value in weapon_rows:
				var candidate: Dictionary = candidate_value
				if candidate["class_id"] == class_id and candidate["level"] == level and candidate["scenario"] == "no_meta":
					level_stats = (candidate.get("stats", {}) as Dictionary).duplicate(true)
					break
			if level_stats.is_empty():
				_errors.append("missing no-meta level stats for class ultimate %s L%d" % [class_id, level])
				continue
			for scenario_id in SCENARIO_IDS:
				var rows := []
				for row in weapon_rows:
					if row["class_id"] == class_id and row["level"] == level and row["scenario"] == scenario_id:
						rows.append(row)
				var solo := _mean(rows, "solo_dpm")
				var crowd := _mean(rows, "crowd_10_total_dpm")
				var ehp := _mean(rows, "ehp")
				var ttd := _mean(rows, "ttd_seconds")
				var utility := _mean(rows, "pickup_radius") / 200.0 + _mean(rows, "move_speed") / 600.0
				var state := _scenario_state(class_id, scenario_id)
				var skill_mods := Meta.skill_modifiers_for_class(state, class_id) if scenario_id != "no_meta" else {}
				var first_weapon := str(PD.weapon_ids(class_id)[0])
				var stats: Dictionary = level_stats.duplicate(true)
				var run_mods := _a5_run_modifiers(class_id)
				if scenario_id != "no_meta":
					_apply_meta_formula_mods(stats, run_mods, skill_mods)
				var params := PD.derived_parameters(stats, run_mods, _config_with_class(PD.weapon(class_id, first_weapon), class_id))
				var ultimate := PD._budget_ultimate_dps(class_id, params)
				var start_charge := float(skill_mods.get("ult_start_charge", 0.0))
				var first_minute_ult := (float(ultimate.get("solo", 0.0)) + float(ultimate.get("aoe", 0.0))) * 30.0
				if start_charge > 0.0:
					first_minute_ult += _ultimate_activation_damage(class_id, params) * start_charge
				var roles := []
				for row in rows:
					roles.append("%s:%s" % [row["weapon_id"], row["axis"]])
				result.append({
					"key": "%s|%d|%s" % [class_id, level, scenario_id], "class_id": class_id, "level": level, "scenario": scenario_id,
					"roles": roles, "mean_solo_dpm": snappedf(solo, 0.01), "mean_crowd_10_dpm": snappedf(crowd, 0.01),
					"mean_ehp": snappedf(ehp, 0.01), "mean_ttd_seconds": snappedf(ttd, 0.01), "convenience_score": snappedf(utility, 0.001),
					"first_minute_ultimate_damage": snappedf(first_minute_ult, 0.01), "atlas_start_charge": snappedf(start_charge, 0.01),
					"strengths": _class_strengths(solo, crowd, ehp, utility), "weaknesses": _class_weaknesses(solo, crowd, ehp, utility),
				})
	return result


func _apply_class_relative_scores(rows: Array) -> void:
	for level in LEVELS:
		for scenario_id in SCENARIO_IDS:
			var scoped := []
			for row in rows:
				if int(row.get("level", 0)) == level and str(row.get("scenario", "")) == scenario_id:
					scoped.append(row)
			var solo_median := _median_metric(scoped, "mean_solo_dpm")
			var crowd_median := _median_metric(scoped, "mean_crowd_10_dpm")
			var defense_median := _median_metric(scoped, "mean_ehp")
			var convenience_median := _median_metric(scoped, "convenience_score")
			for row in scoped:
				row["solo_score"] = snappedf(float(row["mean_solo_dpm"]) / maxf(solo_median, 0.001), 0.001)
				row["aoe_score"] = snappedf(float(row["mean_crowd_10_dpm"]) / maxf(crowd_median, 0.001), 0.001)
				row["defense_score"] = snappedf(float(row["mean_ehp"]) / maxf(defense_median, 0.001), 0.001)
				row["convenience_relative"] = snappedf(float(row["convenience_score"]) / maxf(convenience_median, 0.001), 0.001)
				var ranked := [
					{"name": "solo", "value": float(row["solo_score"])},
					{"name": "AoE", "value": float(row["aoe_score"])},
					{"name": "survival", "value": float(row["defense_score"])},
					{"name": "convenience", "value": float(row["convenience_relative"])},
				]
				ranked.sort_custom(func(a, b): return float(a["value"]) > float(b["value"]))
				row["strengths"] = "%s %.2f× and %s %.2f× roster median." % [ranked[0]["name"], ranked[0]["value"], ranked[1]["name"], ranked[1]["value"]]
				row["weaknesses"] = "%s %.2f× and %s %.2f× roster median." % [ranked[3]["name"], ranked[3]["value"], ranked[2]["name"], ranked[2]["value"]]
				row["outlier_flag"] = "OUTLIER solo=%.2f× AoE=%.2f×" % [row["solo_score"], row["aoe_score"]] if float(row["solo_score"]) < 0.80 or float(row["solo_score"]) > 1.20 or float(row["aoe_score"]) < 0.80 or float(row["aoe_score"]) > 1.20 else "ok"


func _apply_live_evidence_to_rows(rows: Array, parity: Array) -> void:
	var by_pair := {}
	for parity_row in parity:
		by_pair[str(parity_row.get("pair", ""))] = parity_row
	for row in rows:
		if int(row.get("level", 0)) != 20 or str(row.get("scenario", "")) != "class_constellation":
			continue
		var parity_row: Dictionary = by_pair.get("%s/%s" % [row["class_id"], row["weapon_id"]], {})
		if parity_row.is_empty():
			continue
		row["measurement_method"] = "deterministic_formula_plus_live_scene_probe"
		row["runs"] = LIVE_SEEDS.size()
		row["solo_variance_dpm2"] = snappedf(pow(float(parity_row.get("live_solo_dpm_stddev", 0.0)), 2.0), 0.01)
		row["crowd_variance_dpm2"] = snappedf(pow(float(parity_row.get("live_pack_dpm_stddev", 0.0)), 2.0), 0.01)
		row["live_solo_dpm_mean"] = parity_row.get("live_solo_dpm_mean", 0.0)
		row["live_crowd_dpm_mean"] = parity_row.get("live_pack_dpm_mean", 0.0)


func _ultimate_activation_damage(class_id: String, params: Dictionary) -> float:
	var config := PD.ultimate_config(class_id)
	var base_damage := maxf(float(params.get("damage", 1.0)), float(params.get("magic_damage", 1.0)))
	return base_damage * float(config.get("damage", 1.0)) * float(params.get("ultimate_multiplier", 1.0))


func _live_parity(class_ids: Array, builds: Dictionary, weapon_rows: Array) -> Array:
	var result := []
	for class_id_value in class_ids:
		var class_id := str(class_id_value)
		var state := _scenario_state(class_id, "class_constellation")
		for weapon_id_value in PD.weapon_ids(class_id):
			var weapon_id := str(weapon_id_value)
			var solo_samples := []
			var pack_samples := []
			for seed_value in LIVE_SEEDS:
				solo_samples.append(await _measure_live(class_id, weapon_id, 1, builds[class_id]["level20_stats"], state, int(seed_value)))
				pack_samples.append(await _measure_live(class_id, weapon_id, TARGET_COUNT, builds[class_id]["level20_stats"], state, int(seed_value)))
			var formula := _find_weapon_row(weapon_rows, class_id, weapon_id, 20, "class_constellation")
			var solo_mean := _number_mean(solo_samples)
			var pack_mean := _number_mean(pack_samples)
			var final_mechanic := str(formula.get("final_mechanic", "none"))
			result.append({
				"pair": "%s/%s" % [class_id, weapon_id], "attack_mode": formula.get("attack_mode", ""),
				"final_mechanic": final_mechanic, "final_event": formula.get("final_event", ""),
				"seeds": LIVE_SEEDS, "solo_samples_dpm": solo_samples, "pack_samples_dpm": pack_samples,
				"live_solo_dpm_mean": snappedf(solo_mean, 0.01), "live_solo_dpm_stddev": snappedf(_stddev(solo_samples, solo_mean), 0.01),
				"live_pack_dpm_mean": snappedf(pack_mean, 0.01), "live_pack_dpm_stddev": snappedf(_stddev(pack_samples, pack_mean), 0.01),
				"formula_solo_dpm": formula.get("solo_dpm", 0.0), "formula_pack_dpm": formula.get("crowd_10_total_dpm", 0.0),
				"solo_delta_pct": snappedf((solo_mean - float(formula.get("solo_dpm", 0.0))) / maxf(float(formula.get("solo_dpm", 0.0)), 0.001) * 100.0, 0.01),
				"pack_delta_pct": snappedf((pack_mean - float(formula.get("crowd_10_total_dpm", 0.0))) / maxf(float(formula.get("crowd_10_total_dpm", 0.0)), 0.001) * 100.0, 0.01),
				"runtime_observation": "infinite-HP sustained probe" if str(formula.get("final_event", "")) not in ["kill", "execute", "summon_death"] else "final event not fully observable on infinite-HP dummies",
			})
			print("FAN-1438 live %s/%s: solo %.1f DPM, pack %.1f DPM" % [class_id, weapon_id, solo_mean, pack_mean])
	return result


func _measure_live(class_id: String, weapon_id: String, target_count: int, stats: Dictionary, state: Dictionary, seed_value: int) -> float:
	await _teardown()
	seed(seed_value)
	var player := PLAYER_SCENE.instantiate() as Node2D
	_holder.add_child(player)
	if player == null or player.get_script() == null:
		_errors.append("%s/%s live Player failed to instantiate" % [class_id, weapon_id])
		return -1.0
	player.add_to_group("player")
	player.global_position = PLAYER_POSITION
	player.call("configure_character", class_id, weapon_id)
	player.set("stats", stats.duplicate(true))
	player.call("_apply_stat_scaling", true)
	# Exercise the exact production composition order instead of recreating it:
	# earned ascension rewards -> selected A5 -> class/Guild mods -> profiles.
	var main := MainScript.new()
	main.set("selected_character_id", class_id)
	main.set("selected_ascension_level", 5)
	main.set("selected_start_boon_id", "")
	main.set("meta_state", state.duplicate(true))
	main.set("run_sandbox_captured", false)
	main.call("apply_ascension_bonuses", player)
	main.free()
	player.set("max_health", DUMMY_HP)
	player.set("health", DUMMY_HP)
	await process_frame
	var dummies := _spawn_dummies(target_count)
	var anchors := []
	for enemy in dummies:
		anchors.append((enemy as Node2D).global_position)
	await _advance_live(LIVE_WARMUP_SECONDS, dummies, anchors, class_id, weapon_id)
	var before := _total_health(dummies)
	var measured := await _advance_live(LIVE_WINDOW_SECONDS, dummies, anchors, class_id, weapon_id)
	var after := _total_health(dummies)
	if measured < LIVE_WINDOW_SECONDS:
		return -1.0
	return snappedf(maxf(before - after, 0.0) / measured * 60.0, 0.01)


func _advance_live(seconds: float, dummies: Array, anchors: Array, class_id: String, weapon_id: String) -> float:
	var elapsed := 0.0
	var frames := 0
	while elapsed < seconds and frames < MAX_LIVE_FRAMES:
		await process_frame
		frames += 1
		elapsed += maxf(_holder.get_process_delta_time(), 0.0)
		for index in range(dummies.size()):
			if is_instance_valid(dummies[index]):
				(dummies[index] as Node2D).global_position = anchors[index]
	if elapsed < seconds:
		_errors.append("%s/%s live simulation advanced %.2f/%.2fs" % [class_id, weapon_id, elapsed, seconds])
	return elapsed


func _spawn_dummies(target_count: int) -> Array:
	var result := []
	for index in range(target_count):
		var enemy := ENEMY_SCENE.instantiate() as Node2D
		_holder.add_child(enemy)
		if target_count == 1:
			enemy.global_position = PLAYER_POSITION + SOLO_OFFSET
		else:
			var radius := 0.0 if index == 0 else PACK_RADIUS * (0.55 + 0.45 * sqrt(float(index) / float(TARGET_COUNT - 1)))
			var angle := 0.0 if index == 0 else float(index - 1) * 2.3999632
			enemy.global_position = PLAYER_POSITION + SOLO_OFFSET + Vector2.RIGHT.rotated(angle) * radius
		enemy.set("max_health", DUMMY_HP)
		enemy.set("health", DUMMY_HP)
		enemy.set("move_speed", 0.0)
		enemy.set("contact_damage", 0.0)
		result.append(enemy)
	return result


func _total_health(nodes: Array) -> float:
	var total := 0.0
	for node in nodes:
		if is_instance_valid(node):
			total += float(node.get("health"))
	return total


func _teardown() -> void:
	if _holder == null:
		return
	for group_name in ["player_weapons", "allies", "engineer_devices", "player_weapon_effects"]:
		for member in get_nodes_in_group(group_name):
			if is_instance_valid(member):
				var node := member as Node
				node.process_mode = Node.PROCESS_MODE_DISABLED
				if node.has_method("cleanup_effects"):
					node.call("cleanup_effects")
	for child in _holder.get_children():
		if is_instance_valid(child):
			(child as Node).process_mode = Node.PROCESS_MODE_DISABLED
			(child as Node).queue_free()
	await process_frame
	await process_frame
	await process_frame


func _outliers(class_rows: Array, parity: Array) -> Dictionary:
	var class_outliers := []
	for level in LEVELS:
		for scenario_id in SCENARIO_IDS:
			var scoped := []
			for row in class_rows:
				if row["level"] == level and row["scenario"] == scenario_id:
					scoped.append(row)
			var solo_median := _median_metric(scoped, "mean_solo_dpm")
			var crowd_median := _median_metric(scoped, "mean_crowd_10_dpm")
			for row in scoped:
				var solo_ratio := float(row["mean_solo_dpm"]) / maxf(solo_median, 0.001)
				var crowd_ratio := float(row["mean_crowd_10_dpm"]) / maxf(crowd_median, 0.001)
				if solo_ratio < 0.80 or solo_ratio > 1.20 or crowd_ratio < 0.80 or crowd_ratio > 1.20:
					class_outliers.append({"key": row["key"], "solo_vs_median": snappedf(solo_ratio, 0.001), "crowd_vs_median": snappedf(crowd_ratio, 0.001)})
	var parity_outliers := []
	for row in parity:
		if absf(float(row.get("solo_delta_pct", 0.0))) > 35.0 or absf(float(row.get("pack_delta_pct", 0.0))) > 35.0:
			parity_outliers.append({"pair": row["pair"], "solo_delta_pct": row["solo_delta_pct"], "pack_delta_pct": row["pack_delta_pct"]})
	return {"class_corridor_80_120": class_outliers, "formula_live_delta_over_35pct": parity_outliers, "action": "investigation candidates only; FAN-1438 makes no balance changes"}


func _validate_dataset(dataset: Dictionary) -> void:
	var provenance := verify_source_provenance(dataset.get("source", {}))
	if not bool(provenance.get("ok", false)):
		_errors.append("source provenance verification failed: %s" % provenance.get("error", "unknown error"))
	var pairs: Array = dataset["roster"]["pair_keys"]
	var expected_rows := pairs.size() * LEVELS.size() * SCENARIO_IDS.size()
	var rows: Array = dataset["weapon_rows"]
	if rows.size() != expected_rows:
		_errors.append("expected %d weapon rows, got %d" % [expected_rows, rows.size()])
	var keys := {}
	for row in rows:
		var key := str(row.get("key", ""))
		if keys.has(key):
			_errors.append("duplicate weapon row %s" % key)
		keys[key] = true
		if bool(row.get("ultimate_included", true)):
			_errors.append("weapon row %s includes ultimate" % key)
		if not is_equal_approx(float(row.get("crowd_10_per_target_dpm", -1.0)), float(row.get("crowd_10_total_dpm", 0.0)) / TARGET_COUNT):
			_errors.append("per-target identity mismatch at %s" % key)
	for class_id in dataset["roster"]["class_ids"]:
		if int(dataset["builds"][class_id]["level20_points"]) != LEVEL20_POINTS:
			_errors.append("%s level20 build is not %d points" % [class_id, LEVEL20_POINTS])
	var scenarios: Dictionary = dataset["scenarios"]
	if int(scenarios["class_atlas50"]["atlas_spend"]) != 50 or scenarios["class_atlas50"]["excluded_ids"] != ATLAS50_EXCLUSIONS:
		_errors.append("legal Atlas scenario is not exact requested 50/exclusion set")
	if int(scenarios["class_atlas59_upper"]["atlas_spend"]) != 59 or bool(scenarios["class_atlas59_upper"]["playable"]) or scenarios["class_atlas59_upper"]["label"] != NON_PLAYABLE_LABEL:
		_errors.append("Atlas upper-bound contract mismatch")
	if _mode == "full" and (dataset["formula_live_parity"] as Array).size() != pairs.size():
		_errors.append("live parity does not cover every runtime pair")


func _csv(dataset: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("key,class_id,weapon_id,level,scenario,scenario_label,playable,attack_mode,archetype,axis,final_mechanic,playstyle,strengths,weaknesses,stat_delta,solo_dpm,crowd_10_total_dpm,crowd_10_per_target_dpm,hp,defense,dodge,absorb_flat,conditional_shield_capacity,regeneration_per_second,lifesteal_per_second,mitigation,ehp,ttd_seconds,conditional_defense_factor,pickup_radius,move_speed,healing_multiplier,xp_multiplier,money_multiplier,start_gold,ult_start_charge,death_save,solo_delta_abs,solo_delta_pct,crowd_delta_abs,crowd_delta_pct,ehp_delta_abs,ehp_delta_pct,ttd_delta_abs,ttd_delta_pct,atlas_delta,measurement_method,runs,solo_variance_dpm2,crowd_variance_dpm2")
	for row in dataset["weapon_rows"]:
		var cells := [row["key"], row["class_id"], row["weapon_id"], row["level"], row["scenario"], row["scenario_label"], row["playable"], row["attack_mode"], row["archetype"], row["axis"], row["final_mechanic"], row["playstyle"], row["strengths"], row["weaknesses"], JSON.stringify(row["stat_delta"], "", true, true), row["solo_dpm"], row["crowd_10_total_dpm"], row["crowd_10_per_target_dpm"], row["hp"], row["defense"], row["dodge"], row["absorb_flat"], row["conditional_shield_capacity"], row["regeneration_per_second"], row["lifesteal_per_second"], row["mitigation"], row["ehp"], row["ttd_seconds"], row["conditional_defense_factor"], row["pickup_radius"], row["move_speed"], row["healing_multiplier"], row["xp_multiplier"], row["money_multiplier"], row["start_gold"], row["ult_start_charge"], row["death_save"], row["solo_dpm_delta_abs"], row["solo_dpm_delta_pct"], row["crowd_10_total_dpm_delta_abs"], row["crowd_10_total_dpm_delta_pct"], row["ehp_delta_abs"], row["ehp_delta_pct"], row["ttd_seconds_delta_abs"], row["ttd_seconds_delta_pct"], row["atlas_delta_summary"], row["measurement_method"], row["runs"], row["solo_variance_dpm2"], row["crowd_variance_dpm2"]]
		var escaped := PackedStringArray()
		for cell in cells:
			escaped.append(_csv_cell(str(cell)))
		lines.append(",".join(escaped))
	return "\n".join(lines) + "\n"


func _markdown(dataset: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("# FAN-1438 — A5 character and weapon balance report")
	lines.append("")
	lines.append("Source commit `%s` (tree `%s`, timestamp `%s`), Godot `%s`. Dataset digest: `%s`." % [dataset["source"]["commit"], dataset["source"]["tree"], dataset["source"]["commit_timestamp"], dataset["source"]["godot"], dataset["dataset_digest_sha256"]])
	lines.append("")
	lines.append("The live roster is **%d classes / %d class-weapon pairs**. The primary matrix is **%d rows** = pairs × 2 levels × 4 meta scenarios. This report changes no balance values." % [dataset["roster"]["class_count"], dataset["roster"]["weapon_pair_count"], (dataset["weapon_rows"] as Array).size()])
	lines.append("")
	lines.append("## Method and controlled inputs")
	lines.append("")
	lines.append("- A5 means selected difficulty 5 plus cumulative earned A1-A5 class rewards. The distinction is explicit in raw data.")
	lines.append("- Level 1 uses base stats. Level 20 is the requested synthetic 19-point base-stat model, one shared allocation across all three weapons of a class; it is not represented as live reward-card history.")
	lines.append("- Per-weapon DPM is sustained output with `include_ultimate=false`. First-minute ultimate contribution appears only in the class-kit table.")
	lines.append("- Ten-target DPM is total throughput over a compact deterministic pack; per-target DPM is total / 10.")
	lines.append("- Formula rows use canonical `ProgressionData`, `MetaProgression`, schema-6 profiles, and the A5 runtime modifier order. The class-kit ultimate starts from unmodified level stats and applies class/Atlas attribute and run modifiers exactly once. Full-constellation L20 live probes instantiate real Player/Enemy scenes for every pair (%d seeds, %.1fs warm-up, %.1fs measured)." % [LIVE_SEEDS.size(), LIVE_WARMUP_SECONDS, LIVE_WINDOW_SECONDS])
	lines.append("- Survival is a normal-wave A5 contact-pressure model: %.1f base damage, %.1f attempted hits/s, actual 0.32s player i-frame; absorb → defense → expected dodge → sustain. Boss/elite multipliers are intentionally not substituted." % [A5_NORMAL_CONTACT_DAMAGE, A5_NORMAL_CONTACT_RATE])
	lines.append("")
	lines.append("## Meta legality")
	lines.append("")
	for scenario_id in SCENARIO_IDS:
		var scenario: Dictionary = dataset["scenarios"][scenario_id]
		lines.append("- `%s`: %s; class spend %d, Atlas spend %d, playable=%s." % [scenario_id, scenario["label"], scenario["class_spend"], scenario["atlas_spend"], scenario["playable"]])
	lines.append("- The legal 50-dust build purchases every paid Guild node except `atlas_m2`, `atlas_m3`, `atlas_k0` (2+2+5 dust). Guild hidden nodes use explicit all-monster-Codex and secret-boss facts and cost zero.")
	lines.append("- The 59-dust result is labeled **%s** everywhere and is only a conservative upper bound." % NON_PLAYABLE_LABEL)
	lines.append("- Raw `meta_builds` lists the free core, all 20 purchased class node IDs, both reveal facts, and the exact owning-weapon profile nodes for every class. Modifier rule: fractions become `1+sum` and multiply their runtime channel; flat values add; weapon profiles never cross weapon IDs.")
	lines.append("")
	lines.append("## Class-kit summary")
	lines.append("")
	lines.append("| Class | Lvl | Scenario | Weapon roles | Solo score | AoE score | Defense score | Convenience score | Ult first minute | Strengths | Weaknesses | Flag |")
	lines.append("| --- | ---: | --- | --- | ---: | ---: | ---: | ---: | ---: | --- | --- | --- |")
	for row in dataset["class_rows"]:
		lines.append("| %s | %d | %s | %s | %.3f | %.3f | %.3f | %.3f | %.2f | %s | %s | %s |" % [row["class_id"], row["level"], row["scenario"], "; ".join(row["roles"]), row["solo_score"], row["aoe_score"], row["defense_score"], row["convenience_relative"], row["first_minute_ultimate_damage"], row["strengths"], row["weaknesses"], row["outlier_flag"]])
	lines.append("")
	lines.append("## Per-weapon matrix")
	lines.append("")
	lines.append("Absolute and percent deltas are against the same class / weapon / level `no_meta` control. `Shield` is conditional capacity only and is not folded into permanent HP.")
	lines.append("")
	lines.append("| Class / weapon | Lvl | Scenario | Playstyle | Strengths | Weaknesses | Mode / axis / final | Stats Δ | Solo DPM (Δ%) | 10T total / per target DPM (Δ%) | HP / EHP / TTD | Mitigation / dodge / absorb / shield | Regen / lifesteal | Pickup / move | Atlas Δ | Runs / variance (solo;10T) |")
	lines.append("| --- | ---: | --- | --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |")
	for row in dataset["weapon_rows"]:
		lines.append("| %s/%s | %d | %s | %s | %s | %s | %s / %s / %s | %s | %.2f (%+.2f%%) | %.2f / %.2f (%+.2f%%) | %.2f / %.2f / %.2f | %.4f / %.4f / %.2f / %.2f | %.2f / %.2f | %.2f / %.2f | %s | %d / %.2f;%.2f |" % [row["class_id"], row["weapon_id"], row["level"], row["scenario_label"], row["playstyle"], row["strengths"], row["weaknesses"], row["attack_mode"], row["axis"], row["final_mechanic"], _delta_text(row["stat_delta"]), row["solo_dpm"], row["solo_dpm_delta_pct"], row["crowd_10_total_dpm"], row["crowd_10_per_target_dpm"], row["crowd_10_total_dpm_delta_pct"], row["hp"], row["ehp"], row["ttd_seconds"], row["mitigation"], row["dodge"], row["absorb_flat"], row["conditional_shield_capacity"], row["regeneration_per_second"], row["lifesteal_per_second"], row["pickup_radius"], row["move_speed"], row["atlas_delta_summary"], row["runs"], row["solo_variance_dpm2"], row["crowd_variance_dpm2"]])
	lines.append("")
	lines.append("## Formula / live parity")
	lines.append("")
	if (dataset["formula_live_parity"] as Array).is_empty():
		lines.append("Formula-only generation; final evidence requires `--mode=full`.")
	else:
		lines.append("| Pair | Attack mode | Final (event) | Formula solo / live mean±sd DPM | Δ | Formula 10T / live mean±sd DPM | Δ | Observation |")
		lines.append("| --- | --- | --- | ---: | ---: | ---: | ---: | --- |")
		for row in dataset["formula_live_parity"]:
			lines.append("| %s | %s | %s (%s) | %.2f / %.2f±%.2f | %+.2f%% | %.2f / %.2f±%.2f | %+.2f%% | %s |" % [row["pair"], row["attack_mode"], row["final_mechanic"], row["final_event"], row["formula_solo_dpm"], row["live_solo_dpm_mean"], row["live_solo_dpm_stddev"], row["solo_delta_pct"], row["formula_pack_dpm"], row["live_pack_dpm_mean"], row["live_pack_dpm_stddev"], row["pack_delta_pct"], row["runtime_observation"]])
	lines.append("")
	lines.append("## Outliers and conclusions")
	lines.append("")
	lines.append("- Class corridor flags (outside 80–120%% of the same level/scenario median): **%d**." % (dataset["outliers"]["class_corridor_80_120"] as Array).size())
	lines.append("- Formula/live differences over 35%% on either axis: **%d**. These are instrumentation/tuning investigation candidates, not automatic nerf/buff decisions." % (dataset["outliers"]["formula_live_delta_over_35pct"] as Array).size())
	lines.append("- Raw outlier keys and exact ratios are in `raw.json`; the complete numeric matrix is in `per_weapon.csv`.")
	lines.append("- No balance values or mechanics were changed by FAN-1438.")
	lines.append("")
	lines.append("## Limitations")
	lines.append("")
	for limitation in dataset["limitations"]:
		lines.append("- %s" % limitation)
	return "\n".join(lines) + "\n"


func _schema_branch(class_id: String, weapon_id: String) -> Dictionary:
	for raw_branch in Schema6.class_entry(class_id).get("weapon_branches", []):
		if str((raw_branch as Dictionary).get("weapon_id", "")) == weapon_id:
			return raw_branch as Dictionary
	return {}


func _final_node(branch: Dictionary) -> Dictionary:
	for raw_node in branch.get("nodes", []):
		if str((raw_node as Dictionary).get("role", "")) == "weapon_final":
			return raw_node as Dictionary
	return {}


func _atlas_paid_ids() -> Array:
	var ids := []
	for raw_node in Meta.atlas_nodes():
		var node: Dictionary = raw_node
		if int(node.get("cost", 0)) > 0 and str(node.get("role", "")) not in ["core", "hidden"]:
			ids.append(str(node.get("id", "")))
	ids.sort()
	return ids


func _node_cost(ids: Array) -> int:
	var total := 0
	for node_id in ids:
		total += int(Meta.node_by_id(str(node_id)).get("cost", 0))
	return total


func _config_with_class(config: Dictionary, class_id: String) -> Dictionary:
	var result := config.duplicate(true)
	result["character_id"] = class_id
	return result


func _stat_delta(base_stats: Dictionary, stats: Dictionary) -> Dictionary:
	var result := {}
	for stat_id in base_stats:
		var delta := int(round(float(stats.get(stat_id, 0.0)) - float(base_stats.get(stat_id, 0.0))))
		if delta != 0:
			result[stat_id] = delta
	return result


func _delta_sum(base_stats: Dictionary, stats: Dictionary) -> int:
	var total := 0
	for stat_id in base_stats:
		total += int(round(float(stats.get(stat_id, 0.0)) - float(base_stats.get(stat_id, 0.0))))
	return total


func _delta_text(delta: Dictionary) -> String:
	if delta.is_empty():
		return "base"
	var parts := PackedStringArray()
	var keys := delta.keys()
	keys.sort()
	for key in keys:
		parts.append("%s+%d" % [key, int(delta[key])])
	return "; ".join(parts)


func _find_weapon_row(rows: Array, class_id: String, weapon_id: String, level: int, scenario_id: String) -> Dictionary:
	for row in rows:
		if row["class_id"] == class_id and row["weapon_id"] == weapon_id and row["level"] == level and row["scenario"] == scenario_id:
			return row
	return {}


func _mean(rows: Array, key: String) -> float:
	var values := []
	for row in rows:
		values.append(float(row.get(key, 0.0)))
	return _number_mean(values)


func _number_mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += float(value)
	return total / values.size()


func _stddev(values: Array, mean: float) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += pow(float(value) - mean, 2.0)
	return sqrt(total / values.size())


func _median_metric(rows: Array, key: String) -> float:
	var values := []
	for row in rows:
		values.append(float(row.get(key, 0.0)))
	values.sort()
	if values.is_empty():
		return 0.0
	if values.size() % 2 == 1:
		return values[values.size() / 2]
	return (float(values[values.size() / 2 - 1]) + float(values[values.size() / 2])) * 0.5


func _class_strengths(solo: float, crowd: float, ehp: float, utility: float) -> String:
	var scores := [{"name": "solo", "value": solo / 7000.0}, {"name": "crowd", "value": crowd / 22000.0}, {"name": "survival", "value": ehp / 180.0}, {"name": "convenience", "value": utility}]
	scores.sort_custom(func(a, b): return float(a["value"]) > float(b["value"]))
	return "%s + %s" % [scores[0]["name"], scores[1]["name"]]


func _weapon_strength(axis: String, identity: String) -> String:
	var axis_text: String = {"solo": "durable-target pressure", "crowd": "compact-pack throughput", "aoe": "area coverage", "defense": "control/defensive utility"}.get(axis, "mixed output")
	return "%s; %s" % [axis_text, identity]


func _weapon_weakness(axis: String) -> String:
	match axis:
		"solo": return "Lower role budget for dense packs; kill-gated value is absent on immortal dummies."
		"crowd", "aoe": return "Compact-pack strength does not imply equal boss pressure."
		"defense": return "Conditional control/guard value is not converted into permanent shield HP."
	return "Mixed role; inspect live parity before tuning."


func _class_weaknesses(solo: float, crowd: float, ehp: float, utility: float) -> String:
	var scores := [{"name": "solo", "value": solo / 7000.0}, {"name": "crowd", "value": crowd / 22000.0}, {"name": "survival", "value": ehp / 180.0}, {"name": "convenience", "value": utility}]
	scores.sort_custom(func(a, b): return float(a["value"]) < float(b["value"]))
	return "%s + %s" % [scores[0]["name"], scores[1]["name"]]


func _csv_cell(value: String) -> String:
	return "\"%s\"" % value.replace("\"", "\"\"")


func _sha256(value: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value.to_utf8_buffer())
	return context.finish().hex_encode()


func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_errors.append("cannot write %s" % path)
		return
	file.store_string(content)
	file.close()
