extends SceneTree

## FAN-2524: the deterministic corridor proof for the three Assassin ultimates.
##
## The live instrument (`tools/ultimate_effectiveness_report.gd`) measures the
## same three rows by actually casting them; this test is its closed-form twin,
## so a coefficient or a geometry parameter that walks the trio out of its
## power corridor goes red in seconds instead of only in the 51-row run.
##
## The Assassin's structural risk is geometric, not arithmetic: Eight Moons only
## deals its second hit if the curved return path re-enters the lane corridor of
## the marked target, and the Black Web only cuts where a wire segment crosses
## the probe. Both are therefore rebuilt here from the SHIPPED statics —
## `curved_return_path`, `web_segments` and the `pattern_points` primitive —
## and walked with the same projection/lateral test `targets_in_corridor`
## applies. A model with its own copy of the geometry would agree with itself
## instead of with the runtime.
##
## Run:
## python3 tools/godot_gate.py --headless --path . \
##   --script res://tests/ultimates/assassin_balance_test.gd

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Harness := preload("res://scripts/ultimates/balance/ultimate_balance_harness.gd")
const Runner := preload("res://scripts/ultimates/balance/ultimate_effectiveness_runner.gd")
const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const Discovery := preload("res://scripts/ultimates/registry/weapon_ultimate_package_discovery.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Schema := preload("res://scripts/ultimates/schema/weapon_ultimate_schema.gd")
const PD := preload("res://scripts/progression_data.gd")
const Chakrams := preload("res://scripts/ultimates/classes/assassin/chakrams.gd")
const VenomWire := preload("res://scripts/ultimates/classes/assassin/venom_wire.gd")

const CLASS_ID := "assassin"
const WEAPONS := ["chakrams", "shadow_daggers", "venom_wire"]
const DATA_ROOT := "res://data/ultimates/classes"
const SCRIPT_ROOT := "res://scripts/ultimates/classes"

## The probe every scenario shares: probe 0 sits exactly on the aim point, one
## `UltimateEffectivenessRunner.FORMATION_DISTANCE` ahead of the host.
const SOLO_PROBE := Vector2.RIGHT * Runner.FORMATION_DISTANCE
const COMPASS_LANES := 8

## `venom_wire` is the class's crowd-control specialist, and its declared boss
## policy rejects displacement and shortens control by construction, so a boss
## admits only the cut/burst damage channel. The exception is bounded here so
## the boss-readable share can never quietly decay below a third of the budget.
const VENOM_BOSS_FLOOR := 0.33

## FAN-2952 / Ultimate Direction v2. The per-enemy floor is asserted under real
## crowd pressure rather than assumed: at every count the weakest enemy in the
## encounter still has to clear `Budget.PER_ENEMY_FLOOR_FRACTION` of one
## standard monster's max HP. 1000 mirrors the count the shared harness proof
## walks to, so the class statement and the contract statement stop at the same
## place.
const CROWD_COUNTS := [1, 2, 5, 10, 20, 100, 1000]

## Count-shaped parameter names, in the vocabulary this class actually used.
## The shared FAN-2949 scan only recognises `*target_cap*` siblings, and the
## Assassin's caps were named `target_count`, `targets_per_lane` and
## `target_limit` — so the conversion proves the statement over its own names
## too instead of inheriting a green the shared scan could not have produced.
const COUNT_SHAPED_PATTERN := \
	"[A-Za-z0-9_]*(target_cap|target_count|target_limit|targets_per|max_targets)[A-Za-z0-9_]*"
const COUNT_SHAPED_ALLOWED_SUFFIXES := ["_fraction", "_flat"]

var _errors: Array[String] = []
var _geometry := Activation.new(null, {}, 0.0)


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
		_test_weapon(weapon_id, row, metrics[weapon_id])
		_test_per_enemy_floor(weapon_id, row, metrics[weapon_id])
	_test_no_count_caps(profiles)
	_test_trio(profiles, metrics)
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


## The per-hit channel one shipped cast is priced against. The anchor is the
## RUNTIME one: `ultimate_host_context()` reads the CLASS damage parameter.
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
	var control := 0.0
	var displacement := 0.0
	var passes := 0
	var cast_seconds := 0.0
	# The damage the WEAKEST enemy of a crowd takes from one activation — the
	# guaranteed part of the cast, with every geometric bonus removed. Under
	# Ultimate Direction v2 this is the number the per-enemy floor is asserted
	# against, so it is derived here next to the solo channel it belongs to.
	var floor_damage := 0.0
	match weapon_id:
		"chakrams":
			# The aim-lane chakram marks the probe on the way out; the second,
			# full-ratio hit exists only if the curved return re-enters the
			# probe's corridor. Before FAN-2524 the shipped curve offset kept
			# the return outside its own lane width, so the marquee out-and-back
			# duel silently halved.
			passes = 1 + (1 if _return_reaches(params, SOLO_PROBE) else 0)
			damage = float(passes) * base * float(params.get("pass_damage", 0.0))
			# A silhouette no return path re-enters still takes the outbound
			# pass at the secondary ratio: v2 reach with the curve as the bonus.
			floor_damage = base * float(params.get("pass_damage", 0.0)) \
				* float(params.get("secondary_damage_ratio", 0.0))
			cast_seconds = float(params.get("orbit_duration", 0.0)) \
				+ float(params.get("outbound_duration", 0.0)) \
				+ float(params.get("return_steps", 0)) \
				* float(params.get("return_step_interval", 0.0))
		"shadow_daggers":
			# Solo, only the focused mark exists: one stored backstab revealed
			# once. The cast is the FIXED wave sequence, so it no longer moves
			# with the size of the crowd.
			passes = 1
			damage = base * float(params.get("backstab_damage", 0.0))
			floor_damage = damage * float(params.get("secondary_damage_ratio", 0.0))
			cast_seconds = float(params.get("mark_delay", 0.0)) \
				+ float(_activation_int(params, "backstab_waves")) \
				* float(params.get("backstab_interval", 0.0)) \
				+ float(params.get("reveal_delay", 0.0))
		"venom_wire":
			# Every live enemy takes one cut per pulse wherever it stands; the
			# wires it actually crosses raise that, bounded by the per-pulse
			# shaping cap. The burst consumes the accumulated stacks.
			var pulses := _activation_int(params, "cut_pulses")
			var cuts_per_pulse := clampi(
				maxi(_wires_crossing(params, SOLO_PROBE), 1),
				1,
				_activation_int(params, "max_cuts_per_pulse")
			)
			passes = cuts_per_pulse
			damage = _venom_damage(params, base, pulses, cuts_per_pulse)
			floor_damage = _venom_damage(params, base, pulses, 1)
			control = float(params.get("poison_duration", 0.0))
			displacement = float(pulses) * minf(
				float(params.get("pull_strength", 0.0)), SOLO_PROBE.length()
			)
			cast_seconds = float(pulses) * float(params.get("cut_interval", 0.0))
	return {
		"damage": damage,
		"floor_damage": floor_damage,
		"control": control,
		"displacement": displacement,
		"passes": passes,
		# Every cast spawns exactly one mechanics scene the instrument counts.
		"solo_effect": damage + control + displacement + 1.0,
		"cast_seconds": cast_seconds,
	}


## The Black Web's damage channel for a target cut `cuts_per_pulse` times in
## each of `pulses` pulses: the cuts themselves plus the stack-scaled burst.
static func _venom_damage(
	params: Dictionary, base: float, pulses: int, cuts_per_pulse: int
) -> float:
	var stacks := float(pulses * cuts_per_pulse)
	if stacks <= 0.0:
		return 0.0
	return stacks * base * float(params.get("cut_damage", 0.0)) \
		+ base * float(params.get("burst_damage", 0.0)) \
		* (1.0 + (stacks - 1.0) * float(params.get("stack_bonus", 0.0)))


static func _activation_int(params: Dictionary, key: String) -> int:
	return int(float(params.get(key, 0)))


## Whether the shipped curved return re-enters the corridor of a point marked on
## the aim lane — the same chord walk `return_step` performs, against the same
## `targets_in_corridor` projection/lateral test.
static func _return_reaches(params: Dictionary, point: Vector2) -> bool:
	var half_width := float(params.get("lane_half_width", 0.0))
	var length := float(params.get("trajectory_length", 0.0))
	var steps := int(float(params.get("return_steps", 0)))
	for lane in COMPASS_LANES:
		var direction := Vector2.RIGHT.rotated(TAU * float(lane) / float(COMPASS_LANES))
		var path := Chakrams.curved_return_path(
			Vector2.ZERO, direction * length,
			float(params.get("return_curve_offset", 0.0)), steps
		)
		for step in range(1, path.size()):
			if _in_corridor(path[step - 1], path[step] - path[step - 1], point, half_width):
				return true
	return false


## How many of the nine Black Web wires cross a point. The hex comes from the
## shipped `pattern_points` primitive and the segment split from the shipped
## `web_segments`, so the model walks the exact runtime formation.
func _wires_crossing(params: Dictionary, point: Vector2) -> int:
	var points := _geometry.pattern_points(Vector2.ZERO, "polygon", {
		"count": 6,
		"radius": params.get("web_radius", 0.0),
		"rotation_degrees": -90.0,
		"arc_degrees": 360.0,
	})
	var crossings := 0
	for segment in VenomWire.web_segments(points):
		if _in_corridor(segment[0], segment[1] - segment[0],
				point, float(params.get("wire_half_width", 0.0))):
			crossings += 1
	return crossings


static func _in_corridor(
	start: Vector2, direction: Vector2, point: Vector2, half_width: float
) -> bool:
	if direction.length_squared() <= 0.001:
		return false
	var axis := direction.normalized()
	var offset := point - start
	var forward := offset.dot(axis)
	var lateral := absf(offset.dot(Vector2(-axis.y, axis.x)))
	return forward >= 0.0 and forward <= direction.length() and lateral <= half_width


func _test_weapon(weapon_id: String, row: Dictionary, metrics: Dictionary) -> void:
	var effect := float(metrics["solo_effect"])
	_check(effect >= float(row["power_budget_min"]) and effect <= float(row["power_budget_max"]),
		"%s solo effect %.2f must stay inside %.2f..%.2f" % [
			weapon_id, effect, row["power_budget_min"], row["power_budget_max"],
		])
	_check(str(row["power_archetype"]) == Budget.POWER_ARCHETYPE_BURST,
		"%s must preserve the Assassin frozen burst archetype" % weapon_id)
	if weapon_id == "venom_wire":
		# The bounded boss exception: a boss admits only the damage channel, and
		# that channel alone must keep a real share of the budget.
		_check(float(metrics["damage"]) >= float(row["power_budget_max"]) * VENOM_BOSS_FLOOR,
			"venom_wire's boss-readable damage %.2f must keep at least %.2f of the budget" % [
				metrics["damage"], float(row["power_budget_max"]) * VENOM_BOSS_FLOOR,
			])


## Ultimate Direction v2: with the whole corridor budget spread over `count`
## live standard monsters, no enemy may end below `PER_ENEMY_FLOOR_FRACTION` of
## one standard monster's max HP. The pool is the shipped one, so the floor moves
## with the corridor instead of being restated here as a literal.
func _test_per_enemy_floor(weapon_id: String, row: Dictionary, metrics: Dictionary) -> void:
	var pool := Budget.live_standard_pool(float(row["reference_solo_dps"]))
	for count in CROWD_COUNTS:
		# At a count of one the weakest enemy IS the focused target; from two up
		# it is a silhouette carrying only the guaranteed channel.
		var delivered := float(metrics["damage"]) if count == 1 else float(metrics["floor_damage"])
		var floor_share := Budget.PER_ENEMY_FLOOR_FRACTION * pool / float(count)
		_check(delivered >= floor_share - 0.001,
			"%s leaves an enemy at %.2f against a %d-enemy floor of %.2f" % [
				weapon_id, delivered, count, floor_share,
			])


## No count-shaped parameter may survive the conversion, in the executor's own
## declared contract or in the parameters actually shipped for it.
func _test_no_count_caps(profiles: Dictionary) -> void:
	for weapon_id in WEAPONS:
		var executor = load("%s/%s/%s.gd" % [SCRIPT_ROOT, CLASS_ID, weapon_id])
		var contract: Dictionary = executor.parameter_contract() if executor is GDScript else {}
		_check(not contract.is_empty(), "%s must declare a parameter contract" % weapon_id)
		for source in [contract.keys(), _params(profiles, weapon_id).keys()]:
			for raw_key in source:
				var offenders := _count_shaped_names(str(raw_key))
				_check(offenders.is_empty(),
					"%s still carries the count-shaped parameter %s" % [weapon_id, str(offenders)])


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


func _test_trio(profiles: Dictionary, metrics: Dictionary) -> void:
	var chakrams := metrics["chakrams"] as Dictionary
	var daggers := metrics["shadow_daggers"] as Dictionary
	var venom := metrics["venom_wire"] as Dictionary
	# Non-duplicated niches: one out-and-back double pass with an execute, one
	# focused boss burst behind an owner-defense lease, one control web. Sharing
	# a channel would make the class choice cosmetic.
	_check(int(chakrams["passes"]) == 2,
		"Eight Moons must land both its outbound and its curved-return pass on the aim target")
	var chakram_params := _params(profiles, "chakrams")
	var dagger_params := _params(profiles, "shadow_daggers")
	var venom_params := _params(profiles, "venom_wire")
	_check(float(chakram_params.get("execute_threshold", 0.0)) > 0.0
		and not dagger_params.has("execute_threshold") and not venom_params.has("execute_threshold"),
		"only Eight Moons may carry the low-health execute")
	_check(float(dagger_params.get("untargetable_duration", 0.0)) > 0.0,
		"only Moment Before Death may lease the owner untargetable gate")
	_check(float(daggers["damage"]) > float(chakrams["damage"]) * 0.5
		and is_zero_approx(float(daggers["control"])) and is_zero_approx(float(daggers["displacement"])),
		"Moment Before Death must stay the pure focused burst")
	_check(float(venom["control"]) > 0.0 and float(venom["displacement"]) > 0.0
		and is_zero_approx(float(chakrams["control"])) and is_zero_approx(float(chakrams["displacement"])),
		"only the Black Web may control and displace")
	# All three now reach the whole map, so crowd identity is no longer a cap but
	# the SHAPE of the guaranteed channel: the Black Web hands every enemy the
	# same full cut/burst it hands the one in front of it, while the two burst
	# weapons concentrate on their focused mark and leave the rest a fraction.
	_check(is_equal_approx(float(venom["floor_damage"]), float(venom["damage"]))
		and float(daggers["floor_damage"]) < float(daggers["damage"]) * 0.5
		and float(chakrams["floor_damage"]) < float(chakrams["damage"]) * 0.5,
		"the Black Web must keep the evenest crowd spread in the trio")


## A harness that cannot go red would be inherited green by every later retune.
## The mutation is the exact FAN-2524 finding in reverse: widening the return
## curve back past the lane corridor must drop Eight Moons below its floor.
func _test_goes_red(profiles: Dictionary, rows: Array) -> void:
	var altered := profiles.duplicate(true)
	var moons := (altered["chakrams"] as Dictionary).duplicate(true)
	((moons["executor"] as Dictionary)["params"])["return_curve_offset"] = 132.0
	altered["chakrams"] = moons
	var outside: Array[String] = []
	for weapon_id in WEAPONS:
		var row := Budget.row_for(rows, CLASS_ID, weapon_id)
		var measured := _measure(weapon_id, row, altered[weapon_id])
		if float(measured["solo_effect"]) < float(row["power_budget_min"]) \
				or float(measured["solo_effect"]) > float(row["power_budget_max"]):
			outside.append(weapon_id)
	_check(outside == ["chakrams"],
		"the Assassin corridor proof must go red for a return curve that misses its own lane, got %s" % str(outside))


func _params(profiles: Dictionary, weapon_id: String) -> Dictionary:
	return ((profiles.get(weapon_id, {}) as Dictionary).get("executor", {}) as Dictionary) \
		.get("params", {}) as Dictionary


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report(metrics: Dictionary) -> void:
	for weapon_id in WEAPONS:
		var row := metrics[weapon_id] as Dictionary
		print("  %s solo_effect=%.2f (damage=%.2f floor=%.2f control=%.2f displacement=%.1f passes=%d) cast=%.2fs" % [
			weapon_id, row["solo_effect"], row["damage"], row["floor_damage"], row["control"],
			row["displacement"], row["passes"], row["cast_seconds"],
		])
	if _errors.is_empty():
		print("assassin_balance_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("assassin_balance_test: %s" % error)
	print("assassin_balance_test: FAIL (%d)" % _errors.size())
	quit(1)
