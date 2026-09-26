extends SceneTree

## FAN-2527: the deterministic corridor proof for the three Chemist ultimates.
##
## The live instrument (`tools/ultimate_effectiveness_report.gd`) measures the
## same three rows by actually casting them; this test is its closed-form twin,
## so a coefficient or a weapon `damage_multiplier` that walks the trio out of
## its power corridor goes red in seconds instead of only in the 51-row run.
##
## The anchor is the RUNTIME one: `UltimatePlayerHost.ultimate_host_context()`
## reads the CLASS damage parameter, not the weapon's. For Chemist that matters —
## `blast_powder` attacks as physical but its ultimate scales from
## `magic_damage`, so reading the weapon key here would price one of the three
## rows against a channel the shipped cast never uses.
##
## Run:
## python3 tools/godot_gate.py --headless --path . \
##   --script res://tests/ultimates/chemist_balance_test.gd

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Harness := preload("res://scripts/ultimates/balance/ultimate_balance_harness.gd")
const Discovery := preload("res://scripts/ultimates/registry/weapon_ultimate_package_discovery.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Schema := preload("res://scripts/ultimates/schema/weapon_ultimate_schema.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "chemist"
const WEAPONS := ["blast_powder", "acid_flask", "homunculus_vial"]
const DATA_ROOT := "res://data/ultimates/classes"
const SCRIPT_ROOT := "res://scripts/ultimates/classes"

## Ultimate Direction v2: the Chemist trio reaches every live enemy, so each
## cast must retain a non-zero damage floor even when the crowd grows beyond
## the live runner's 20-target scenario.
const CROWD_COUNTS := [1, 2, 5, 10, 20, 100, 1000]
const COUNT_SHAPED_PATTERN := \
	"[A-Za-z0-9_]*(target_cap|target_count|target_limit|targets_per|max_targets|crowd_cap)[A-Za-z0-9_]*"
const COUNT_SHAPED_ALLOWED_SUFFIXES := ["_fraction", "_flat"]
const MAP_WIDE_OBSOLETE_PARAMS := {
	"blast_powder": ["charge_radius", "target_limit"],
	"acid_flask": ["start_ratio", "target_limit"],
	"homunculus_vial": ["wave_radius", "target_limit"],
}

var _errors: Array[String] = []


func _initialize() -> void:
	var rows := Budget.build_rows(PD.WEAPONS_BY_CLASS, PD)
	var report := Harness.measure(rows)
	_check(Harness.violations(report).is_empty(),
		"the inherited 51-row balance harness must remain clean")
	var profiles := _active_profiles()
	var metrics := {}
	for weapon_id in WEAPONS:
		var row := Budget.row_for(rows, CLASS_ID, weapon_id)
		metrics[weapon_id] = _measure(weapon_id, row, profiles.get(weapon_id, {}) as Dictionary)
		_test_weapon(weapon_id, row, profiles.get(weapon_id, {}) as Dictionary, metrics[weapon_id])
		_test_per_enemy_floor(weapon_id, row, metrics[weapon_id])
	_test_no_count_caps(profiles)
	_test_no_inert_targeting_params(profiles)
	_test_trio(metrics)
	_test_goes_red(profiles, rows)
	_report(metrics)


func _active_profiles() -> Dictionary:
	var shipped := Registry.new(PD.WEAPONS_BY_CLASS)
	_check(shipped.is_valid(), "the immutable catalog must remain valid")
	var discovery := Discovery.new(DATA_ROOT, SCRIPT_ROOT)
	discovery.discover(Schema.index_documents(shipped.documents_for_tests()))
	_check(discovery.validation_errors().is_empty(),
		"active balance discovery must stay valid: %s" % [discovery.validation_errors()])
	var profiles := {}
	for weapon_id in WEAPONS:
		profiles[weapon_id] = discovery.profile_for("%s/%s" % [CLASS_ID, weapon_id])
	return profiles


## The per-hit channel one shipped cast is priced against.
static func _base_damage(weapon_id: String) -> float:
	var derived: Dictionary = PD.derived_parameters(
		PD.base_stats(CLASS_ID), {}, PD.weapon(CLASS_ID, weapon_id)
	)
	var parameter := PD.damage_parameter_for(CLASS_ID)
	return float(derived.get(parameter, derived.get("damage", 0.0))) \
		* float(derived.get("ultimate_multiplier", 1.0))


## One solo activation, channel by channel, in the units the live instrument
## sums into `effect_total`. Every number is read from the shipped declaration,
## so the model cannot drift away from the data it is judging.
func _measure(weapon_id: String, row: Dictionary, profile: Dictionary) -> Dictionary:
	var params := (profile.get("executor", {}) as Dictionary).get("params", {}) as Dictionary
	var base := _base_damage(weapon_id)
	var damage := 0.0
	var floor_effect := 0.0
	var displacement := 0.0
	var control_seconds := 0.0
	var summons := 0.0
	var movement_locked := false
	match weapon_id:
		"blast_powder":
			# One capped blast on the crystallized set.
			var uncapped := base * float(params.get("damage", 0.0))
			var probe_health := float(row.get("reference_solo_dps", 0.0)) * Budget.POWER_SECONDS_MAX
			damage = minf(
				uncapped,
				probe_health * float(params.get("target_damage_cap", 0.0))
			)
			floor_effect = damage
			displacement = float(params.get("pull_force", 0.0))
			var crystal := params.get("crystal_status", {}) as Dictionary
			control_seconds = float(crystal.get("duration", 0.0))
			movement_locked = bool(crystal.get("movement_locked", false))
		"acid_flask":
			# Every tick escalates by the stacks the earlier ticks dissolved, and
			# the finale spends the capped charge those ticks converted.
			var unit := base * float(params.get("damage", 0.0))
			var cap := float(params.get("dissolve_stack_cap", 0))
			var bonus := float(params.get("dissolve_bonus", 0.0))
			for tick_index in int(params.get("tick_count", 0)):
				damage += unit * (1.0 + bonus * minf(float(tick_index), cap))
			# The finale spends one activation-wide charge across the whole crowd,
			# so only the repeated corrosion is guaranteed to every enemy.
			floor_effect = damage
			var charge := minf(
				damage * float(params.get("charge_conversion", 0.0)),
				unit * float(params.get("charge_cap_ratio", 0.0))
			)
			damage += charge * float(params.get("pillar_ratio", 0.0))
		"homunculus_vial":
			# Each stomp reads the cascade the earlier beats applied.
			var stomp := base * float(params.get("damage", 0.0))
			var toxin := float(params.get("wave_toxin_bonus", 0.0))
			for beat_index in int(params.get("beat_count", 0)):
				damage += stomp * (1.0 + toxin * float(beat_index))
			floor_effect = damage
			displacement = float(params.get("taunt_force", 0.0))
			control_seconds = float((params.get("taunt_status", {}) as Dictionary).get("duration", 0.0))
			summons = 1.0
	return {
		"damage": damage,
		"floor_effect": floor_effect,
		"displacement": displacement,
		"control_seconds": control_seconds,
		"summons": summons,
		"movement_locked": movement_locked,
		"solo_effect": damage + displacement + control_seconds + summons,
		"cast_seconds": float(params.get("recover_at", 0.0)),
	}


func _test_weapon(
	weapon_id: String, row: Dictionary, profile: Dictionary, metrics: Dictionary
) -> void:
	var effect := float(metrics["solo_effect"])
	_check(effect >= float(row["power_budget_min"]) and effect <= float(row["power_budget_max"]),
		"%s solo effect %.2f must stay inside %.2f..%.2f" % [
			weapon_id, effect, row["power_budget_min"], row["power_budget_max"],
		])
	_check(is_equal_approx(float(profile.get("total_boss_cap", 0.0)), float(row["total_boss_cap"])),
		"%s must keep its immutable whole-activation boss cap" % weapon_id)
	_check(str(row["power_archetype"]) == Budget.POWER_ARCHETYPE_BURST,
		"%s must preserve the Chemist frozen burst archetype" % weapon_id)
	# The pour and the beats only escalate while the cast is still running: a
	# ceiling below the beat count freezes the mechanic half-way through itself.
	var params := (profile.get("executor", {}) as Dictionary).get("params", {}) as Dictionary
	if weapon_id == "acid_flask":
		_check(int(params.get("dissolve_stack_cap", 0)) >= int(params.get("tick_count", 0)) - 1,
			"the dissolve ceiling must let the corrosion escalate across the whole pour")


## The guaranteed map-wide channel alone must remove meaningful HP from every
## enemy. Control and the shared acid finale may add value, but neither can
## stand in for damage on the least-favoured member of the crowd.
func _test_per_enemy_floor(weapon_id: String, row: Dictionary, metrics: Dictionary) -> void:
	var pool := Budget.live_standard_pool(float(row["reference_solo_dps"]))
	var delivered := float(metrics["floor_effect"])
	for count in CROWD_COUNTS:
		var floor_share := Budget.PER_ENEMY_FLOOR_FRACTION * pool / float(count)
		_check(delivered >= floor_share - 0.001,
			"%s leaves an enemy at %.2f against a %d-enemy floor of %.2f" % [
				weapon_id, delivered, count, floor_share,
			])
	_check(float(metrics["damage"]) > 0.0,
		"%s must remove HP from every enemy it reaches" % weapon_id)


## The shared coverage ratchet deliberately only understands `*target_cap*`.
## Chemist used the equally count-shaped `target_limit`, so prove the stronger
## class-local contract over both the executor declaration and shipped data.
func _test_no_count_caps(profiles: Dictionary) -> void:
	for weapon_id in WEAPONS:
		var executor = load("%s/%s/%s.gd" % [SCRIPT_ROOT, CLASS_ID, weapon_id])
		var contract: Dictionary = executor.parameter_contract() if executor is GDScript else {}
		_check(not contract.is_empty(), "%s must declare a parameter contract" % weapon_id)
		var shipped := (profiles.get(weapon_id, {}).get("executor", {}) as Dictionary) \
			.get("params", {}) as Dictionary
		for source in [contract.keys(), shipped.keys()]:
			for raw_key in source:
				var offenders := _count_shaped_names(str(raw_key))
				_check(offenders.is_empty(),
					"%s still carries the count-shaped parameter %s" % [weapon_id, str(offenders)])


## A map-wide cast must not retain a range-growth tuning value that no longer
## affects an executor. Keep both the shipped declaration and code contract
## honest when coverage removes a former selection boundary.
func _test_no_inert_targeting_params(profiles: Dictionary) -> void:
	for weapon_id in WEAPONS:
		var executor = load("%s/%s/%s.gd" % [SCRIPT_ROOT, CLASS_ID, weapon_id])
		var contract: Dictionary = executor.parameter_contract() if executor is GDScript else {}
		var shipped := (profiles.get(weapon_id, {}).get("executor", {}) as Dictionary) \
			.get("params", {}) as Dictionary
		for raw_parameter in MAP_WIDE_OBSOLETE_PARAMS.get(weapon_id, []):
			var parameter := str(raw_parameter)
			_check(not contract.has(parameter),
				"%s retains the inert map-wide contract parameter %s" % [weapon_id, parameter])
			_check(not shipped.has(parameter),
				"%s ships the inert map-wide parameter %s" % [weapon_id, parameter])


static func _count_shaped_names(text: String) -> Array[String]:
	var found: Array[String] = []
	var pattern := RegEx.create_from_string(COUNT_SHAPED_PATTERN)
	for raw_match in pattern.search_all(text):
		var name := str((raw_match as RegExMatch).get_string())
		var shaping := false
		for suffix in COUNT_SHAPED_ALLOWED_SUFFIXES:
			if name.ends_with(suffix):
				shaping = true
				break
		if not shaping and not found.has(name):
			found.append(name)
	return found


func _test_trio(metrics: Dictionary) -> void:
	var blast := metrics["blast_powder"] as Dictionary
	var acid := metrics["acid_flask"] as Dictionary
	var homunculus := metrics["homunculus_vial"] as Dictionary
	# Non-duplicated niches: exactly one decisive burst, one pure area denial and
	# one summon window. Sharing a channel would make the class choice cosmetic.
	_check(float(blast["damage"]) > 0.0 and bool(blast["movement_locked"])
		and not bool(homunculus["movement_locked"]),
		"only the transmutation burst may lock a target in place")
	_check(is_zero_approx(float(acid["displacement"])) and is_zero_approx(float(acid["control_seconds"]))
		and is_zero_approx(float(acid["summons"])),
		"the acid lake must stay pure area denial, with no control or summon channel")
	_check(float(homunculus["summons"]) > 0.0 and is_zero_approx(float(blast["summons"]))
		and is_zero_approx(float(acid["summons"])),
		"only the fused homunculus may open a summon window")
	# Distinct rhythms, so the three reads apart on screen as well as on paper.
	var lengths := [float(blast["cast_seconds"]), float(acid["cast_seconds"]),
		float(homunculus["cast_seconds"])]
	lengths.sort()
	_check(lengths[0] < lengths[1] and lengths[1] < lengths[2],
		"the trio must keep three distinct cast lengths, got %s" % str(lengths))


## A harness that cannot go red would be inherited green by every later retune.
func _test_goes_red(profiles: Dictionary, rows: Array) -> void:
	var altered := profiles.duplicate(true)
	var lake := (altered["acid_flask"] as Dictionary).duplicate(true)
	((lake["executor"] as Dictionary)["params"]["damage"]) = 400.0
	altered["acid_flask"] = lake
	var outside: Array[String] = []
	for weapon_id in WEAPONS:
		var row := Budget.row_for(rows, CLASS_ID, weapon_id)
		var measured := _measure(weapon_id, row, altered[weapon_id])
		if float(measured["solo_effect"]) < float(row["power_budget_min"]) \
				or float(measured["solo_effect"]) > float(row["power_budget_max"]):
			outside.append(weapon_id)
	_check(outside == ["acid_flask"],
		"the Chemist corridor proof must go red for a runaway lake coefficient, got %s" % str(outside))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report(metrics: Dictionary) -> void:
	for weapon_id in WEAPONS:
		var row := metrics[weapon_id] as Dictionary
		print("  %s solo_effect=%.2f (damage=%.2f floor=%.2f displacement=%.1f control=%.2fs summons=%.0f) cast=%.2fs" % [
			weapon_id, row["solo_effect"], row["damage"], row["floor_effect"], row["displacement"],
			row["control_seconds"], row["summons"], row["cast_seconds"],
		])
	if _errors.is_empty():
		print("chemist_balance_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("chemist_balance_test: %s" % error)
	print("chemist_balance_test: FAIL (%d)" % _errors.size())
	quit(1)
