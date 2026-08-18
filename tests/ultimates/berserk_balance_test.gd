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
const Hammer := preload("res://scripts/ultimates/classes/berserk/hammer.gd")

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
	match weapon_id:
		"sword":
			# The orbit grows past the probe, so every admitted bite reaches it;
			# a bite is admitted only when the sweep's own blade has re-armed on
			# this target. The aim-oriented cross then lands once through it.
			var bites := _round_robin_bites(params)
			passes = bites + 1
			damage = base * (float(bites) * float(params.get("blade_damage", 0.0))
				+ float(params.get("cross_damage", 0.0)))
			control = float(params.get("vortex_duration", 0.0))
			cast_seconds = float(params.get("lifetime", 0.0))
		"axe":
			# The probe sits inside the corridor on both the outbound and the
			# return leg. The execute never fires on the instrument's probes: the
			# solo probe is at full health and epic/boss tiers are denied by the
			# control policy, so the corridor is priced by the loop's own passes.
			var outbound_reaches := _corridor_reaches(params, Vector2.ZERO, SOLO_PROBE)
			var return_reaches := _corridor_reaches(
				params, _edge(params, SOLO_PROBE), SOLO_PROBE
			)
			passes = int(outbound_reaches) + int(return_reaches)
			damage = base * (float(params.get("outbound_damage", 0.0)) * int(outbound_reaches)
				+ float(params.get("return_damage", 0.0)) * int(return_reaches))
			control = float(params.get("mark_duration", 0.0))
			cast_seconds = float(params.get("release_delay", 0.0)) \
				+ float(params.get("outbound_seconds", 0.0)) \
				+ float(params.get("return_seconds", 0.0))
		"hammer":
			# The lanes are world-cardinal, and the probe sits exactly on the
			# east cardinal lane; the diagonals miss it laterally, and the
			# central quake reaches it. The stagger launches it the full impulse.
			var cardinal_hit := false
			for axis in Hammer.lane_axes(0):
				if _in_corridor(Vector2.ZERO, axis * float(params.get("lane_length", 0.0)),
						SOLO_PROBE, float(params.get("lane_half_width", 0.0))):
					cardinal_hit = true
			var quake_hit := SOLO_PROBE.length() <= float(params.get("quake_radius", 0.0))
			passes = int(cardinal_hit) + int(quake_hit)
			damage = base * (float(params.get("cardinal_damage", 0.0)) * int(cardinal_hit)
				+ float(params.get("quake_damage", 0.0)) * int(quake_hit))
			displacement = float(params.get("stagger_impulse", 0.0))
			control = float(params.get("stagger_duration", 0.0))
			cast_seconds = float(params.get("release_delay", 0.0)) \
				+ 2.0 * float(params.get("beat_interval", 0.0))
	return {
		"damage": damage,
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


func _test_trio(profiles: Dictionary, metrics: Dictionary) -> void:
	var sword := metrics["sword"] as Dictionary
	var axe := metrics["axe"] as Dictionary
	var hammer := metrics["hammer"] as Dictionary
	var sword_params := _params(profiles, "sword")
	var axe_params := _params(profiles, "axe")
	var hammer_params := _params(profiles, "hammer")
	# Non-duplicated niches: one long orbiting crowd whirlwind, one corridor
	# finisher with the only low-health execute, one staggering launch burst.
	# Sharing a channel would make the class choice cosmetic.
	_check(int(sword_params.get("crowd_cap", 0)) > int(axe_params.get("crowd_cap", 0))
		and int(sword_params.get("crowd_cap", 0)) > int(hammer_params.get("crowd_cap", 0))
		and float(sword_params.get("lifetime", 0.0)) > float(axe_params.get("lifetime", 0.0)),
		"the whirlwind must remain the widest and longest crowd option")
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
		print("  %s solo_effect=%.2f (damage=%.2f control=%.2f displacement=%.1f passes=%d) cast=%.2fs" % [
			weapon_id, row["solo_effect"], row["damage"], row["control"],
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
