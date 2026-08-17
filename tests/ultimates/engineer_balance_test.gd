extends SceneTree

## FAN-2532: the deterministic corridor proof for the three Engineer ultimates.
##
## The live instrument (`tools/ultimate_effectiveness_report.gd`) measures the
## same three rows by actually casting them; this test is its closed-form twin,
## so a coefficient or a weapon `damage_multiplier` that walks the trio out of
## its power corridor goes red in seconds instead of only in the 51-row run.
##
## Unlike the Chemist trio, two of the three Engineer casts only reach a target
## through geometry — the sentry hex fires along fixed chords and the mine field
## is a seeded annulus — so the model rebuilds those formations with the SHIPPED
## `pattern_points` primitive and walks them against the probe the instrument
## places one `FORMATION_DISTANCE` ahead. A model with its own copy of the
## placement would agree with itself instead of with the runtime.
##
## Run:
## python3 tools/godot_gate.py --headless --path . \
##   --script res://tests/ultimates/engineer_balance_test.gd

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Harness := preload("res://scripts/ultimates/balance/ultimate_balance_harness.gd")
const Runner := preload("res://scripts/ultimates/balance/ultimate_effectiveness_runner.gd")
const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const Discovery := preload("res://scripts/ultimates/registry/weapon_ultimate_package_discovery.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Schema := preload("res://scripts/ultimates/schema/weapon_ultimate_schema.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "engineer"
const WEAPONS := ["engineer_sentry_wrench", "engineer_repair_drone", "engineer_pressure_mines"]
const DATA_ROOT := "res://data/ultimates/classes"
const SCRIPT_ROOT := "res://scripts/ultimates/classes"

## The probe every scenario shares: probe 0 sits exactly on the aim point, one
## `UltimateEffectivenessRunner.FORMATION_DISTANCE` ahead of the host.
const SOLO_PROBE := Vector2.RIGHT * Runner.FORMATION_DISTANCE
## The host enters at half health, so that — not the declared repair budget — is
## the most a solo cast can actually restore.
const HOST_HEALTH_FRACTION := 0.5
## Deploy counts the two executors hold as their own identity rather than as a
## declared parameter.
const SENTRY_PYLONS := 6
const SENTRY_CHORDS := 3

## `engineer_repair_drone` is the class's defensive save, and the instrument adds
## raw knockback impulse to HP-denominated channels, so its `effect_total` sits
## above the nominal ceiling by construction. The exception is bounded here so it
## can never quietly grow into a second damage ultimate.
const DRONE_CEILING_EXCEPTION := 1.10

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
		_test_weapon(weapon_id, row, profiles.get(weapon_id, {}) as Dictionary, metrics[weapon_id])
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
	# The probe carries one whole power budget, which is what the per-target cap
	# below is a fraction of.
	var probe_health := float(row.get("reference_solo_dps", 0.0)) * Budget.POWER_SECONDS_MAX
	var damage := 0.0
	var uncapped := 0.0
	var target_cap := INF
	var healing := 0.0
	var modifier := 0.0
	var displacement := 0.0
	var summons := 0.0
	var cast_seconds := 0.0
	match weapon_id:
		"engineer_sentry_wrench":
			# Every volley fires all three chords of the fixed hex at once, so what
			# a single target takes is how many of those chords cross it.
			var crossings := _hex_chords_crossing(params, SOLO_PROBE)
			uncapped = float(params.get("volley_count", 0)) * float(crossings) \
				* base * float(params.get("damage", 0.0))
			damage = uncapped
			summons = float(SENTRY_PYLONS)
			cast_seconds = float(params.get("duration", 0.0))
		"engineer_repair_drone":
			var waves := float(params.get("wave_count", 0))
			uncapped = waves * base * float(params.get("ram_damage", 0.0))
			damage = uncapped
			displacement = waves * float(params.get("knockback", 0.0))
			modifier = base * float(params.get("shield", 0.0))
			# Repair is metered three ways: the pulse cadence, the activation-wide
			# budget, and the HP the hero is actually missing. Overheal spends none.
			healing = minf(
				minf(waves * base * float(params.get("repair_pulse", 0.0)),
					base * float(params.get("repair_total", 0.0))),
				float(row.get("reference_ehp", 0.0)) * HOST_HEALTH_FRACTION
			)
			summons = float(params.get("drone_count", 0))
			cast_seconds = float(params.get("final_pulse_at", 0.0)) \
				+ float(params.get("shield_duration", 0.0))
		"engineer_pressure_mines":
			# Only the mines whose blast actually covers the probe reach it, and the
			# field's own per-target cap is what bounds the total.
			uncapped = float(_mines_covering(params, SOLO_PROBE)) * base \
				* float(params.get("damage", 0.0))
			target_cap = probe_health * float(params.get("target_cap_fraction", 0.0)) \
				+ float(params.get("target_cap_flat", 0.0))
			damage = minf(uncapped, target_cap)
			summons = float(params.get("mine_count", 0))
			cast_seconds = float(params.get("finale_delay", 0.0)) \
				+ float(params.get("finale_interval", 0.0)) * float(summons - 1.0) \
				+ float(params.get("finale_tail", 0.0))
	return {
		"damage": damage,
		"uncapped_damage": uncapped,
		"target_cap": target_cap,
		"healing": healing,
		"modifier": modifier,
		"displacement": displacement,
		"summons": summons,
		"solo_effect": damage + healing + modifier + displacement + summons,
		"cast_seconds": cast_seconds,
	}


## How many of the hex's three chords pass within `corridor_half_width` of a
## point — the same projection/lateral test `targets_in_corridor` applies.
func _hex_chords_crossing(params: Dictionary, point: Vector2) -> int:
	var points := _geometry.pattern_points(Vector2.ZERO, "ring", {
		"count": SENTRY_PYLONS,
		"radius": params.get("formation_radius", 0.0),
		"rotation_degrees": 0.0,
		"arc_degrees": 360.0,
	})
	if points.size() != SENTRY_PYLONS:
		return 0
	var half_width := float(params.get("corridor_half_width", 0.0))
	var crossings := 0
	for chord in SENTRY_CHORDS:
		var start := points[chord]
		var finish := points[chord + SENTRY_CHORDS]
		var axis := (finish - start).normalized()
		var offset := point - start
		var forward := offset.dot(axis)
		var lateral := absf(offset.dot(Vector2(-axis.y, axis.x)))
		if forward >= 0.0 and forward <= start.distance_to(finish) and lateral <= half_width:
			crossings += 1
	return crossings


## How many seeded mines detonate close enough to cover a point. The smart chain
## is deliberately not modelled: no mine of this field sits inside `trigger_radius`
## of the solo probe, so nothing detonates before the finale, and the assertion
## below is what keeps that statement true rather than assumed.
func _mines_covering(params: Dictionary, point: Vector2) -> int:
	var points := _geometry.pattern_points(Vector2.ZERO, "seeded_annulus", {
		"count": params.get("mine_count", 0),
		"inner_radius": params.get("inner_radius", 0.0),
		"outer_radius": params.get("outer_radius", 0.0),
		"seed": params.get("seed", 0),
	})
	var blast_radius := float(params.get("blast_radius", 0.0))
	var trigger_radius := float(params.get("trigger_radius", 0.0))
	var covering := 0
	var armed := 0
	for mine in points:
		if mine.distance_to(point) <= blast_radius:
			covering += 1
		if mine.distance_to(point) <= trigger_radius:
			armed += 1
	_check(armed == 0,
		"a mine now sits inside the trigger radius of the solo probe, so the chain " \
		+ "falloff this model skips has become live")
	return covering


func _test_weapon(
	weapon_id: String, row: Dictionary, profile: Dictionary, metrics: Dictionary
) -> void:
	var effect := float(metrics["solo_effect"])
	var ceiling := float(row["power_budget_max"])
	if weapon_id == "engineer_repair_drone":
		# The declared exception, bounded: the row may sit above the ceiling only
		# because the instrument counts raw knockback impulse next to HP, and its
		# save must stay a real save rather than the overshoot itself.
		_check(effect <= ceiling * DRONE_CEILING_EXCEPTION,
			"%s solo effect %.2f must stay inside its declared %.2fx ceiling exception (%.2f)" % [
				weapon_id, effect, DRONE_CEILING_EXCEPTION, ceiling * DRONE_CEILING_EXCEPTION,
			])
		_check(float(metrics["healing"]) + float(metrics["modifier"])
				>= float(row["reference_ehp"]),
			"%s must keep a defensive save worth at least one hero health bar" % weapon_id)
	else:
		_check(effect >= float(row["power_budget_min"]) and effect <= ceiling,
			"%s solo effect %.2f must stay inside %.2f..%.2f" % [
				weapon_id, effect, row["power_budget_min"], ceiling,
			])
	_check(is_equal_approx(float(profile.get("total_boss_cap", 0.0)), float(row["total_boss_cap"])),
		"%s must keep its immutable whole-activation boss cap" % weapon_id)
	_check(str(row["power_archetype"]) == Budget.POWER_ARCHETYPE_CONTROL_SAVE,
		"%s must preserve the Engineer frozen control_save archetype" % weapon_id)
	_check(float(metrics["cast_seconds"]) >= Budget.CONTROL_SAVE_MIN_SECONDS,
		"%s cast %.2fs must clear the control_save minimum of %.2fs" % [
			weapon_id, metrics["cast_seconds"], Budget.CONTROL_SAVE_MIN_SECONDS,
		])
	# The mine field's single-target ceiling is its own declared anti-one-shot cap,
	# not its coefficient. Losing that would turn the cap into flat damage.
	if weapon_id == "engineer_pressure_mines":
		_check(float(metrics["uncapped_damage"]) > float(metrics["target_cap"]),
			"the mine field must stay bounded by its declared per-target cap")


func _test_trio(metrics: Dictionary) -> void:
	var sentry := metrics["engineer_sentry_wrench"] as Dictionary
	var drone := metrics["engineer_repair_drone"] as Dictionary
	var mines := metrics["engineer_pressure_mines"] as Dictionary
	# Non-duplicated niches: one uncapped sustained crossfire, one defensive save,
	# one bounded field. Sharing a channel would make the class choice cosmetic.
	_check(is_inf(float(sentry["target_cap"])) and float(sentry["damage"]) > 0.0,
		"only the sentry crossfire may spend its whole budget on a single target")
	_check(float(drone["healing"]) > 0.0 and float(drone["displacement"]) > 0.0
		and is_zero_approx(float(sentry["healing"])) and is_zero_approx(float(mines["healing"])),
		"only the microdrone swarm may repair and displace")
	_check(float(mines["target_cap"]) < float(mines["uncapped_damage"])
		and is_zero_approx(float(mines["displacement"])),
		"the mine field must stay pure bounded damage, with no control channel")
	# Distinct rhythms, so the three read apart on screen as well as on paper.
	var lengths := [float(sentry["cast_seconds"]), float(drone["cast_seconds"]),
		float(mines["cast_seconds"])]
	lengths.sort()
	_check(lengths[0] < lengths[1] and lengths[1] < lengths[2],
		"the trio must keep three distinct cast lengths, got %s" % str(lengths))


## A harness that cannot go red would be inherited green by every later retune.
func _test_goes_red(profiles: Dictionary, rows: Array) -> void:
	var altered := profiles.duplicate(true)
	var hex := (altered["engineer_sentry_wrench"] as Dictionary).duplicate(true)
	((hex["executor"] as Dictionary)["params"]["damage"]) = 400.0
	altered["engineer_sentry_wrench"] = hex
	var outside: Array[String] = []
	for weapon_id in WEAPONS:
		var row := Budget.row_for(rows, CLASS_ID, weapon_id)
		var measured := _measure(weapon_id, row, altered[weapon_id])
		var ceiling := float(row["power_budget_max"])
		if weapon_id == "engineer_repair_drone":
			ceiling *= DRONE_CEILING_EXCEPTION
		if float(measured["solo_effect"]) < float(row["power_budget_min"]) \
				or float(measured["solo_effect"]) > ceiling:
			outside.append(weapon_id)
	_check(outside == ["engineer_sentry_wrench"],
		"the Engineer corridor proof must go red for a runaway hex coefficient, got %s" % str(outside))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report(metrics: Dictionary) -> void:
	for weapon_id in WEAPONS:
		var row := metrics[weapon_id] as Dictionary
		print("  %s solo_effect=%.2f (damage=%.2f heal=%.2f modifier=%.2f displacement=%.1f summons=%.0f) cast=%.2fs" % [
			weapon_id, row["solo_effect"], row["damage"], row["healing"],
			row["modifier"], row["displacement"], row["summons"], row["cast_seconds"],
		])
	if _errors.is_empty():
		print("engineer_balance_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("engineer_balance_test: %s" % error)
	print("engineer_balance_test: FAIL (%d)" % _errors.size())
	quit(1)
