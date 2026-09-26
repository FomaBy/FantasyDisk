extends SceneTree

## FAN-2525: the deterministic corridor proof for the three Berserk ultimates.
##
## The live instrument (`tools/ultimate_effectiveness_report.gd`) measures the
## same three rows by actually casting them; this test is its closed-form twin,
## so a coefficient or a cooldown that walks the trio out of its power corridor
## goes red in seconds instead of only in the 51-row run.
##
## Every channel is rebuilt from the SHIPPED statics: the whirlwind's bites come
## from walking the declared blade round-robin with its own per-blade cooldown,
## the loop's two passes come from the corridor geometry the executor walks, and
## the rift's lanes come from the same world-cardinal axes `beat()` uses. A model
## with its own copy of the numbers would agree with itself instead of the
## runtime.
##
## Ultimate Direction v2 (FAN-2953): reach is map-wide for all three — the
## whirlwind's sweeps and both rift lane beats bite every live enemy, the loop's
## outbound pass strikes and marks the whole map with the return leg as the
## aimed bonus. The models below therefore assert a per-enemy FLOOR under crowd
## pressure and prove no count-shaped parameter survives in the class's own
## vocabulary (`crowd_cap` — which the shared `*target_cap*` scan cannot see).
##
## Run:
## python3 tools/godot_gate.py --headless --path . \
##   --script res://tests/ultimates/berserk_balance_test.gd

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Harness := preload("res://scripts/ultimates/balance/ultimate_balance_harness.gd")
const Runner := preload("res://scripts/ultimates/balance/ultimate_effectiveness_runner.gd")
const Discovery := preload("res://scripts/ultimates/registry/weapon_ultimate_package_discovery.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Schema := preload("res://scripts/ultimates/schema/weapon_ultimate_schema.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "berserk"
const WEAPONS := ["sword", "axe", "hammer"]
const DATA_ROOT := "res://data/ultimates/classes"
const SCRIPT_ROOT := "res://scripts/ultimates/classes"

## The probe every scenario shares: probe 0 sits exactly on the aim point, one
## `UltimateEffectivenessRunner.FORMATION_DISTANCE` ahead of the host.
const SOLO_PROBE := Vector2.RIGHT * Runner.FORMATION_DISTANCE

## The axe is the class's finisher, so its boss-readable loop channel must keep
## a real share of the budget even though every probe tier denies the execute.
const AXE_BOSS_FLOOR := 0.33
## The hammer's identity is the stagger/launch; its damage-only channel alone
## must still keep a bounded share, exactly like venom_wire's boss exception.
const HAMMER_DAMAGE_FLOOR := 0.33
const LATERAL_EPS := 0.001

## FAN-2953 / Ultimate Direction v2. The per-enemy floor is asserted under real
## crowd pressure rather than assumed: at every count the weakest enemy in the
## encounter still has to clear `Budget.PER_ENEMY_FLOOR_FRACTION` of one
## standard monster's max HP. 1000 mirrors the count the shared harness proof
## walks to, so the class statement and the contract statement stop at the same
## place.
const CROWD_COUNTS := [1, 2, 5, 10, 20, 100, 1000]

## Count-shaped parameter names, in the vocabulary this class actually used.
## The shared FAN-2949 scan only recognises `*target_cap*` siblings, and the
## Berserk caps were named `crowd_cap` — so the conversion proves the statement
## over its own names too instead of inheriting a green the shared scan could
## not have produced.
const COUNT_SHAPED_PATTERN := \
	"[A-Za-z0-9_]*(target_cap|target_count|target_limit|targets_per|max_targets|crowd_cap)[A-Za-z0-9_]*"
const COUNT_SHAPED_ALLOWED_SUFFIXES := ["_fraction", "_flat"]


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
	# guaranteed map-wide channel, with every geometric bonus removed. Under
	# Ultimate Direction v2 this is the number the per-enemy floor is asserted
	# against, so it is derived here next to the solo channel it belongs to.
	var floor_damage := 0.0
	match weapon_id:
		"sword":
			# Every sweep bites every live enemy; a bite is admitted only when
			# the sweep's own blade has re-armed on this target. The
			# aim-oriented cross is the geometric bonus on top of that floor.
			var bites := _round_robin_bites(params)
			passes = bites + 1
			floor_damage = base * float(bites) * float(params.get("blade_damage", 0.0))
			damage = floor_damage + base * float(params.get("cross_damage", 0.0))
			control = float(params.get("vortex_duration", 0.0))
			cast_seconds = float(params.get("lifetime", 0.0))
		"axe":
			# The outbound pass strikes and marks every live enemy; the return
			# corridor is the aimed bonus the probe also sits inside. The
			# execute never fires on the instrument's probes: the solo probe is
			# at full health and epic/boss tiers are denied by the control
			# policy, so the corridor is priced by the loop's own passes.
			var return_reaches := _corridor_reaches(
				params, _edge(params, SOLO_PROBE), SOLO_PROBE
			)
			passes = 1 + int(return_reaches)
			floor_damage = base * float(params.get("outbound_damage", 0.0))
			damage = floor_damage \
				+ base * float(params.get("return_damage", 0.0)) * int(return_reaches)
			control = float(params.get("mark_duration", 0.0))
			cast_seconds = float(params.get("release_delay", 0.0)) \
				+ float(params.get("outbound_seconds", 0.0)) \
				+ float(params.get("return_seconds", 0.0))
		"hammer":
			# Every beat reaches every live enemy: both lane beats and the
			# central quake are the guaranteed floor, and the stagger launches
			# the full impulse. Lane membership is attribution, never reach.
			passes = 3
			damage = base * (float(params.get("cardinal_damage", 0.0))
				+ float(params.get("diagonal_damage", 0.0))
				+ float(params.get("quake_damage", 0.0)))
			floor_damage = damage
			displacement = float(params.get("stagger_impulse", 0.0))
			control = float(params.get("stagger_duration", 0.0))
			cast_seconds = float(params.get("release_delay", 0.0)) \
				+ 2.0 * float(params.get("beat_interval", 0.0))
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


## How many bites the declared round-robin admits on one target: sweep n belongs
## to blade n % blade_count, and a blade may not touch the same target again
## before its own cooldown has re-armed — the exact `blade_ready` contract.
static func _round_robin_bites(params: Dictionary) -> int:
	var blade_count := maxi(int(params.get("blade_count", 1)), 1)
	var sweep_count := int(params.get("sweep_count", 0))
	var interval := float(params.get("sweep_interval", 0.0))
	var cooldown := float(params.get("blade_hit_cooldown", 0.0))
	var last_hit: Array = []
	for blade in blade_count:
		last_hit.append(-1)
	var bites := 0
	for sweep in sweep_count:
		var blade := sweep % blade_count
		var gap := float(sweep - int(last_hit[blade])) * interval
		if int(last_hit[blade]) < 0 or gap >= cooldown - LATERAL_EPS:
			bites += 1
			last_hit[blade] = sweep
	return bites


## The arena edge the loop always reaches along the aim, never the aim point.
static func _edge(params: Dictionary, aim: Vector2) -> Vector2:
	var radius := float(params.get("arena_radius", 0.0))
	var axis := aim.normalized() if aim.length_squared() > 0.001 else Vector2.RIGHT
	return axis * radius


## Whether a corridor leg covers the probe — the same projection/lateral test
## `targets_in_corridor` applies. The outbound leg runs origin-to-edge along the
## aim; the return leg is the same corridor walked back from the edge.
static func _corridor_reaches(params: Dictionary, start: Vector2, probe: Vector2) -> bool:
	var half_width := float(params.get("corridor_half_width", 0.0))
	var edge := _edge(params, probe)
	var direction := edge if start.length_squared() < 0.001 else -edge
	return _in_corridor(start, direction, probe, half_width)


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
	_check(float(metrics["solo_effect"]) / float(row["reference_solo_dps"]) >= Budget.POWER_SECONDS_MIN,
		"%s effect channel must keep the corridor floor readable" % weapon_id)
	if weapon_id == "axe":
		# The bounded finisher exception: every probe tier denies the execute, so
		# the loop's own passes must carry a real share of the budget on their own.
		_check(float(metrics["damage"]) >= float(row["power_budget_max"]) * AXE_BOSS_FLOOR,
			"the axe loop's boss-readable damage %.2f must keep at least %.2f of the budget" % [
				metrics["damage"], float(row["power_budget_max"]) * AXE_BOSS_FLOOR,
			])
	if weapon_id == "hammer":
		# The bounded displacement exception: the rift's damage-only channel
		# sits below the floor by design; it may not also decay past this bound.
		_check(float(metrics["damage"]) >= float(row["power_budget_max"]) * HAMMER_DAMAGE_FLOOR,
			"the hammer's damage channel %.2f must keep at least %.2f of the budget" % [
				metrics["damage"], float(row["power_budget_max"]) * HAMMER_DAMAGE_FLOOR,
			])


## Ultimate Direction v2: with the whole corridor budget spread over `count`
## live standard monsters, no enemy may end below `PER_ENEMY_FLOOR_FRACTION` of
## one standard monster's max HP. The pool is the shipped one, so the floor
## moves with the corridor instead of being restated here as a literal.
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
	var sword := metrics["sword"] as Dictionary
	var axe := metrics["axe"] as Dictionary
	var hammer := metrics["hammer"] as Dictionary
	var sword_params := _params(profiles, "sword")
	var axe_params := _params(profiles, "axe")
	var hammer_params := _params(profiles, "hammer")
	# Non-duplicated niches: one long orbiting multi-hit crowd whirlwind, one
	# corridor finisher with the only low-health execute, one staggering launch
	# burst. Sharing a channel would make the class choice cosmetic. All three
	# now reach the whole map, so the crowd identity is the SHAPE of the
	# guaranteed channel, never a reach cap.
	_check(int(sword["passes"]) > int(hammer["passes"]) and int(sword["passes"]) > int(axe["passes"])
		and float(sword_params.get("lifetime", 0.0)) > float(axe_params.get("lifetime", 0.0))
		and float(sword_params.get("lifetime", 0.0)) > float(hammer_params.get("lifetime", 0.0)),
		"the whirlwind must remain the longest, multi-hit crowd option")
	_check(float(axe_params.get("return_damage", 0.0)) > float(sword_params.get("cross_damage", 0.0))
		and float(axe_params.get("return_damage", 0.0)) > float(hammer_params.get("quake_damage", 0.0))
		and float(axe_params.get("execute_damage", 0.0)) > 0.0
		and float(axe_params.get("execute_threshold", 0.0)) > 0.0
		and not sword_params.has("execute_threshold") and not hammer_params.has("execute_threshold"),
		"only the loop may carry the corridor finisher and the low-health execute")
	_check(float(hammer_params.get("lifetime", 0.0)) < float(axe_params.get("lifetime", 0.0))
		and float(hammer["displacement"]) > 0.0
		and is_zero_approx(float(sword["displacement"]))
		and is_zero_approx(float(axe["displacement"])),
		"only the rift may stagger and launch, and it must stay the shortest burst")
	_check(int(axe["passes"]) == 2,
		"the loop must land both its outbound and its return pass on the aim target")


## A harness that cannot go red would be inherited green by every later retune.
## The mutation is the corridor's own pricing rule in reverse: re-arming the
## blades early lets every sweep bite, and the whirlwind must blow past its
## ceiling while its two siblings stay inside.
func _test_goes_red(profiles: Dictionary, rows: Array) -> void:
	var altered := profiles.duplicate(true)
	var whirlwind := (altered["sword"] as Dictionary).duplicate(true)
	((whirlwind["executor"] as Dictionary)["params"])["blade_hit_cooldown"] = 1.65
	altered["sword"] = whirlwind
	var outside: Array[String] = []
	for weapon_id in WEAPONS:
		var row := Budget.row_for(rows, CLASS_ID, weapon_id)
		var measured := _measure(weapon_id, row, altered[weapon_id])
		if float(measured["solo_effect"]) < float(row["power_budget_min"]) \
				or float(measured["solo_effect"]) > float(row["power_budget_max"]):
			outside.append(weapon_id)
	_check(outside == ["sword"],
		"the Berserk corridor proof must go red for a round-robin that never re-arms, got %s" % str(outside))


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
		print("berserk_balance_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("berserk_balance_test: %s" % error)
	print("berserk_balance_test: FAIL (%d)" % _errors.size())
	quit(1)
