extends SceneTree

## Fail-closed visual-node and material budget contract for presentation scenes.
##
## The Soldier scenes intentionally use their exact drawn-node count as the
## visual cap; that zero headroom is accepted only because each scene records
## the decision in metadata. Any later artistic addition must either receive a
## reviewed cap change or fail with an observable runtime diagnostic.
##
## The material budget rides the existing PRESENTATION_V2_MIGRATION_ALLOWLIST,
## so it binds a pair the moment its rework card takes it out of the ratchet.
## The Soldier packs are still v1, so the migrated behaviour is proven by
## reading the same packs against an empty allowlist.

const Runtime := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_runtime.gd")
const Contract := preload("res://scripts/ultimates/presentation/ultimate_visual_direction_contract.gd")
const Schema := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_schema.gd")
const Manifest := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_manifest.gd")
const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")
const ImpactFrames := preload("res://tests/ultimates/presentation/victim_impact_frames_fixture.gd")
const REFERENCE_CLASS := "soldier"

## The largest crowd a scenario can put on the map: main.gd
## WAVE_SETTINGS.max_active_cap. The impact budget is proven at exactly it.
const MAX_SCENARIO_ENEMIES := 48

## 60 fps steps, long enough for the whole ripple plus the last burst.
const IMPACT_STEPS := 180
const IMPACT_STEP_SECONDS := 1.0 / 60.0
const UNBOUNDED_POOL := 4096
const PACKS := [
	{
		"id": "soldier_rifle",
		"scene": preload("res://scenes/vfx/ultimates/soldier/SoldierRifleSuppressiveOrder.tscn"),
	},
	{
		"id": "soldier_grenade",
		"scene": preload("res://scenes/vfx/ultimates/soldier/SoldierGrenadeSevenSeconds.tscn"),
	},
	{
		"id": "soldier_bayonet",
		"scene": preload("res://scenes/vfx/ultimates/soldier/SoldierBayonetLastCharge.tscn"),
	},
]


## A victim answering the same two entry points the live enemy does, recording
## the order it was hit in so the ripple order is observable.
class ImpactVictim extends Node2D:
	var flashes := 0
	var feedback_enabled := true
	var flash_log: Array = []

	func _combat_feedback_enabled() -> bool:
		return feedback_enabled

	func _show_hit_flash() -> void:
		flashes += 1
		flash_log.append(self)


class BudgetProbe extends Runtime:
	func evaluate(scene: Node, runtime: Dictionary, key := "") -> Dictionary:
		set("_scene", scene)
		var accepted := _within_declared_budget(runtime, key)
		var diagnostic := last_budget_diagnostic()
		set("_scene", null)
		return {"accepted": accepted, "diagnostic": diagnostic}


func _initialize() -> void:
	var errors: Array[String] = []
	for raw_pack in PACKS:
		var pack := raw_pack as Dictionary
		_test_declared_budget(pack, errors)
		_test_failure_modes(pack, errors)
		_test_material_budget(pack, errors)
	_test_manifest_material_gate(errors)
	_test_material_cap_resolution(errors)
	_test_victim_impact_budget(errors)
	_test_victim_impact_degradation(errors)
	_test_area_telegraph_demotion(errors)
	if errors.is_empty():
		print("Weapon ultimate presentation budget contract passed (explicit Soldier decisions and fail-closed diagnostics).")
		quit(0)
		return
	for error in errors:
		push_error("Weapon ultimate presentation budget: %s" % error)
	quit(1)


func _test_declared_budget(pack: Dictionary, errors: Array[String]) -> void:
	var scene := (pack["scene"] as PackedScene).instantiate()
	var drawn := Runtime._drawing_node_count(scene)
	var max_visual_nodes := int(scene.get_meta("max_visual_nodes", 0))
	var crowd_cap := int(scene.get_meta("crowd_cap", 0))
	var decision := str(scene.get_meta("visual_node_budget_decision", "")).strip_edges()
	_expect(max_visual_nodes > 0, "%s must declare a positive visual-node budget" % pack["id"], errors)
	_expect(crowd_cap >= max_visual_nodes, "%s crowd cap must cover its visual budget" % pack["id"], errors)
	_expect(drawn <= max_visual_nodes, "%s drawn-node count %d must fit its cap %d" % [pack["id"], drawn, max_visual_nodes], errors)
	if drawn == max_visual_nodes:
		_expect(not decision.is_empty(), "%s exact visual budget requires an explicit decision" % pack["id"], errors)
	var result := (BudgetProbe.new()).evaluate(scene, {"max_visual_nodes": max_visual_nodes, "crowd_cap": crowd_cap})
	_expect(bool(result.get("accepted", false)), "%s declared budget must be accepted" % pack["id"], errors)
	_expect(str(result.get("diagnostic", "")).is_empty(), "%s accepted budget must not retain a diagnostic" % pack["id"], errors)
	scene.free()


func _test_failure_modes(pack: Dictionary, errors: Array[String]) -> void:
	var scene := (pack["scene"] as PackedScene).instantiate()
	var drawn := Runtime._drawing_node_count(scene)
	var crowd_cap := int(scene.get_meta("crowd_cap", 0))
	var probe := BudgetProbe.new()
	var exceeded := probe.evaluate(scene, {"max_visual_nodes": drawn - 1, "crowd_cap": crowd_cap})
	_expect(not bool(exceeded.get("accepted", true)), "%s exceeded budget must fail closed" % pack["id"], errors)
	_expect(str(exceeded.get("diagnostic", "")).contains("exceed"), "%s exceeded budget must expose a diagnostic" % pack["id"], errors)

	scene.remove_meta("max_visual_nodes")
	scene.remove_meta("crowd_cap")
	var missing := probe.evaluate(scene, {})
	_expect(not bool(missing.get("accepted", true)), "%s missing budget must fail closed" % pack["id"], errors)
	_expect(str(missing.get("diagnostic", "")).contains("missing"), "%s missing budget must expose a diagnostic" % pack["id"], errors)

	for invalid in [
		{"max_visual_nodes": 0, "crowd_cap": crowd_cap},
		{"max_visual_nodes": -1, "crowd_cap": crowd_cap},
		{"max_visual_nodes": crowd_cap + 1, "crowd_cap": crowd_cap},
	]:
		var invalid_result := probe.evaluate(scene, invalid)
		_expect(not bool(invalid_result.get("accepted", true)), "%s invalid budget must fail closed" % pack["id"], errors)
		_expect(str(invalid_result.get("diagnostic", "")).contains("invalid"), "%s invalid budget must expose a diagnostic" % pack["id"], errors)
	scene.free()


## The material half of the same per-activation budget, gated by the existing
## v2 migration ratchet: an allowlisted v1 pack owes no material declaration,
## while the same pack read as a migrated pair owes one its actual materials fit.
func _test_material_budget(pack: Dictionary, errors: Array[String]) -> void:
	var scene := (pack["scene"] as PackedScene).instantiate()
	var key := str(scene.get_meta("ultimate_id", ""))
	var counts := Contract.material_counts(scene)
	var unique := int(counts["unique"])
	_expect(unique == 1, "%s shares one canvas material across its drawn nodes" % pack["id"], errors)
	_expect(int(counts["fullscreen"]) == 0, "%s draws in world space: no screen-space material" % pack["id"], errors)
	_expect(not Schema.PRESENTATION_V2_MIGRATION_ALLOWLIST.has(key), "%s must have left the v2 migration allowlist" % key, errors)
	_expect(
		Contract.scene_material_violations(scene, key).is_empty(),
		"%s migrated scene must declare a valid material budget" % key,
		errors
	)

	scene.remove_meta("max_unique_materials")
	scene.remove_meta("max_fullscreen_materials")
	_expect_code(
		Contract.scene_material_violations(scene, key, {}),
		"budget.max_unique_materials",
		"%s must fail closed on a missing material declaration" % key,
		errors
	)

	scene.set_meta("max_unique_materials", unique)
	scene.set_meta("max_fullscreen_materials", 1)
	_expect(
		Contract.scene_material_violations(scene, key, {}).is_empty(),
		"%s actual materials must fit the budget it declares" % key,
		errors
	)

	scene.set_meta("max_unique_materials", Contract.MAX_UNIQUE_MATERIALS_CEILING + 1)
	_expect_code(
		Contract.scene_material_violations(scene, key, {}),
		"budget.max_unique_materials_ceiling",
		"%s must fail closed above the unique-material ceiling" % key,
		errors
	)

	scene.set_meta("max_unique_materials", unique)
	scene.set_meta("max_fullscreen_materials", Contract.MAX_FULLSCREEN_MATERIALS_CEILING + 1)
	_expect_code(
		Contract.scene_material_violations(scene, key, {}),
		"budget.max_fullscreen_materials_ceiling",
		"%s must fail closed above the full-screen material ceiling" % key,
		errors
	)

	scene.set_meta("max_unique_materials", 1)
	scene.set_meta("max_fullscreen_materials", Contract.MAX_FULLSCREEN_MATERIALS_CEILING)
	_expect_code(
		Contract.scene_material_violations(scene, key, {}),
		"budget.material_relation",
		"%s must fail closed when more materials cover the viewport than exist" % key,
		errors
	)

	scene.set_meta("max_unique_materials", unique)
	scene.set_meta("max_fullscreen_materials", 1)
	scene.add_child(_with_material(Sprite2D.new()))
	_expect_code(
		Contract.scene_material_violations(scene, key, {}),
		"budget.unique_materials_actual",
		"%s must fail closed when it carries more materials than it declared" % key,
		errors
	)

	var backdrop := CanvasLayer.new()
	backdrop.add_child(_with_material(Polygon2D.new()))
	backdrop.add_child(_with_material(Polygon2D.new()))
	scene.add_child(backdrop)
	scene.set_meta("max_unique_materials", Contract.MAX_UNIQUE_MATERIALS_CEILING)
	_expect_code(
		Contract.scene_material_violations(scene, key, {}),
		"budget.fullscreen_materials_actual",
		"%s must fail closed when more screen-space layers cover the viewport than it declared" % key,
		errors
	)
	scene.free()


## The declaration side of the same gate, read off the class reference manifest.
func _test_manifest_material_gate(errors: Array[String]) -> void:
	var manifest := Contract.load_manifest(REFERENCE_CLASS)
	_expect(not manifest.is_empty(), "%s reference manifest must load" % REFERENCE_CLASS, errors)
	_expect(
		_budget_violations(Contract.violations(REFERENCE_CLASS, manifest)).is_empty(),
		"%s migrated manifest must declare a valid material budget" % REFERENCE_CLASS,
		errors
	)
	var missing := manifest.duplicate(true)
	for raw_weapon in missing.get("weapons", []) as Array:
		var performance := (raw_weapon as Dictionary)["performance"] as Dictionary
		performance.erase("max_unique_materials")
		performance.erase("max_fullscreen_materials")
	_expect_code(
		_budget_violations(Contract.violations(REFERENCE_CLASS, missing, {})),
		"budget.max_unique_materials",
		"%s read as a migrated pair must fail closed on the missing declaration" % REFERENCE_CLASS,
		errors
	)

	var declared := manifest.duplicate(true)
	for raw_weapon in declared.get("weapons", []) as Array:
		var performance := (raw_weapon as Dictionary)["performance"] as Dictionary
		performance["max_unique_materials"] = Contract.MAX_UNIQUE_MATERIALS_CEILING
		performance["max_fullscreen_materials"] = Contract.MAX_FULLSCREEN_MATERIALS_CEILING
	_expect(
		_budget_violations(Contract.violations(REFERENCE_CLASS, declared, {})).is_empty(),
		"a declared material budget inside both ceilings must be accepted",
		errors
	)


func _test_material_cap_resolution(errors: Array[String]) -> void:
	var probe := BudgetProbe.new()
	var node_budget := {"max_visual_nodes": 4, "crowd_cap": 8}

	var scene := _material_probe_scene()
	var manifest_only := node_budget.duplicate()
	manifest_only["max_unique_materials"] = 2
	manifest_only["max_fullscreen_materials"] = 1
	var result := probe.evaluate(scene, manifest_only, "probe/manifest_only")
	_expect(bool(result.get("accepted", false)), "manifest-declared material caps must be enforced from the runtime block", errors)

	var manifest_too_low := node_budget.duplicate()
	manifest_too_low["max_unique_materials"] = 1
	manifest_too_low["max_fullscreen_materials"] = 1
	result = probe.evaluate(scene, manifest_too_low, "probe/manifest_only")
	_expect(not bool(result.get("accepted", true)), "a manifest cap below the actual material count must fail closed", errors)
	_expect(str(result.get("diagnostic", "")).contains("unique_materials_actual"), "the manifest-cap rejection must name the exceeded cap", errors)
	scene.free()

	scene = _material_probe_scene()
	scene.set_meta("max_unique_materials", 2)
	scene.set_meta("max_fullscreen_materials", 1)
	var undeclared := node_budget.duplicate()
	undeclared["max_unique_materials"] = null
	undeclared["max_fullscreen_materials"] = null
	result = probe.evaluate(scene, undeclared, "probe/scene_meta")
	_expect(bool(result.get("accepted", false)), "an undeclared manifest cap must fall back to scene metadata", errors)

	var invalid := node_budget.duplicate()
	invalid["max_unique_materials"] = 0
	invalid["max_fullscreen_materials"] = 1
	result = probe.evaluate(scene, invalid, "probe/scene_meta")
	_expect(not bool(result.get("accepted", true)), "a declared invalid manifest cap must fail closed, never fall back to scene metadata", errors)
	scene.free()

	scene = _material_probe_scene()
	var allowlisted_key := "doctor/bone_saw"
	_expect(Schema.PRESENTATION_V2_MIGRATION_ALLOWLIST.has(allowlisted_key), "%s must still be on the migration allowlist" % allowlisted_key, errors)
	result = probe.evaluate(scene, node_budget, allowlisted_key)
	_expect(bool(result.get("accepted", false)), "an allowlisted legacy pair must activate without a material declaration", errors)

	result = probe.evaluate(scene, node_budget, "probe/missing")
	_expect(not bool(result.get("accepted", true)), "a migrated pair without any material declaration must fail closed", errors)
	_expect(str(result.get("diagnostic", "")).contains("max_unique_materials"), "the missing-declaration rejection must name the cap", errors)
	scene.free()

	var legacy_record := Manifest.class_weapon_record("doctor", "bone_saw")
	_expect(not legacy_record.is_empty() and legacy_record.get("max_unique_materials") == null,
		"an undeclared manifest material cap must stay null, not coerce to 0", errors)
	var sniper_record := Manifest.class_weapon_record("sniper", "sniper_deadeye_rifle")
	_expect(int(sniper_record.get("max_unique_materials", 0)) == 2 and int(sniper_record.get("max_fullscreen_materials", 0)) == 1,
		"a declared manifest material cap must pass through to the runtime block", errors)


func _material_probe_scene() -> Node2D:
	var root := Node2D.new()
	root.add_child(_with_material(Sprite2D.new()))
	root.add_child(_with_material(Sprite2D.new()))
	return root


## The per-victim impact budget (FAN-3008), printed as the sweep the two
## service constants are derived from: node creation stops at the pool cap at
## every crowd size, the white flash fires once per victim, the ripple runs
## outward from the cast point, and its stagger stays in the 3-8 frame window.
func _test_victim_impact_budget(errors: Array[String]) -> void:
	print("Victim impact sweep (%d fps steps, pool cap %d, degrade above %d victims):" % [
		int(round(1.0 / IMPACT_STEP_SECONDS)), ImpactPlayer.POOL_CAP, ImpactPlayer.DEGRADE_VICTIM_THRESHOLD,
	])
	for victims in [1, 8, 24, ImpactPlayer.DEGRADE_VICTIM_THRESHOLD, MAX_SCENARIO_ENEMIES]:
		var run := _run_impacts(int(victims), ImpactPlayer.DEGRADE_VICTIM_THRESHOLD, ImpactPlayer.POOL_CAP)
		print("  victims=%2d created=%2d peak_active=%2d recycled=%d stagger=%d degraded=%s" % [
			int(victims),
			int(run["created_nodes"]),
			int(run["peak_active"]),
			int(run["recycled"]),
			int(run["stagger_frames"]),
			str(bool(run["degraded"])),
		])
		_expect(
			int(run["created_nodes"]) <= ImpactPlayer.POOL_CAP,
			"%d victims created %d impact nodes over the pool cap %d"
				% [int(victims), int(run["created_nodes"]), ImpactPlayer.POOL_CAP],
			errors
		)
		_expect(
			int(run["flashes"]) == int(victims),
			"%d victims flashed %d times: the white flash is never dropped"
				% [int(victims), int(run["flashes"])],
			errors
		)
		_expect(
			int(run["stagger_frames"]) >= ImpactPlayer.STAGGER_MIN_FRAMES
				and int(run["stagger_frames"]) <= ImpactPlayer.STAGGER_MAX_FRAMES,
			"%d victims stagger %d frames outside the %d-%d window"
				% [
					int(victims),
					int(run["stagger_frames"]),
					ImpactPlayer.STAGGER_MIN_FRAMES,
					ImpactPlayer.STAGGER_MAX_FRAMES,
				],
			errors
		)
		_expect(bool(run["ordered"]), "%d victims must be hit outward from the cast point" % int(victims), errors)
		_expect(int(run["pooled_after_finish"]) == 0, "%d victims must leave no pooled node behind" % int(victims), errors)

	# The live victim answers the same entry points the fixture victim does, so
	# the flash the service plays over is the enemy's existing one.
	var enemy_script := load("res://scripts/enemy.gd") as Script
	var answered := {}
	for raw_method in enemy_script.get_script_method_list():
		answered[str((raw_method as Dictionary).get("name", ""))] = true
	for method in [ImpactPlayer.FLASH_METHOD, ImpactPlayer.FLASH_GUARD_METHOD]:
		_expect(answered.has(method), "enemy.gd must still answer %s()" % method, errors)

	# The same crowd with combat feedback switched off keeps its impacts and
	# drops only the flash the setting owns.
	var muted := _run_impacts(8, ImpactPlayer.DEGRADE_VICTIM_THRESHOLD, ImpactPlayer.POOL_CAP, false)
	_expect(int(muted["flashes"]) == 0, "the combat-feedback setting must still gate the flash", errors)

	# FAN-3012: a multi-beat activation enqueues later beats into the running
	# ripple. No queued burst may be dropped by the join, and the merged spawn
	# order must still run outward from the hero.
	var joined := _run_joined_impacts()
	_expect(int(joined["flashes"]) == 12, "a joined beat must keep every queued burst: %d flashes" % int(joined["flashes"]), errors)
	_expect(bool(joined["ordered"]), "a joined beat must not break the outward ripple", errors)
	_expect(int(muted["created_nodes"]) > 0, "a muted flash must not cancel the impact burst", errors)

	# The map-wide case is the one the card is about: the crowd grows six-fold
	# over the 8-victim case while node creation stays under one constant.
	var crowd := _run_impacts(MAX_SCENARIO_ENEMIES, ImpactPlayer.DEGRADE_VICTIM_THRESHOLD, ImpactPlayer.POOL_CAP)
	_expect(
		int(crowd["created_nodes"]) < MAX_SCENARIO_ENEMIES,
		"a map-wide ultimate must not create one impact node per enemy (created %d for %d)"
			% [int(crowd["created_nodes"]), MAX_SCENARIO_ENEMIES],
		errors
	)
	_expect(
		int(crowd["recycled"]) == 0,
		"the pool must cover the largest scenario crowd without cutting a live burst (recycled %d)"
			% int(crowd["recycled"]),
		errors
	)


## The degradation threshold is a measurement, not a preference: at the declared
## threshold the full-size bursts still peak inside the pool, one victim later
## they would not, and the reduced variant brings the peak back under it while
## keeping the flash and shortening the burst.
func _test_victim_impact_degradation(errors: Array[String]) -> void:
	var threshold := ImpactPlayer.DEGRADE_VICTIM_THRESHOLD
	var at_threshold := _run_impacts(threshold, threshold, UNBOUNDED_POOL)
	_expect(
		not bool(at_threshold["degraded"]) and int(at_threshold["peak_active"]) <= ImpactPlayer.POOL_CAP,
		"full-size bursts at the %d-victim threshold must peak inside the pool cap (peak %d)"
			% [threshold, int(at_threshold["peak_active"])],
		errors
	)
	var over_threshold_full := _run_impacts(threshold + 1, threshold + 1, UNBOUNDED_POOL)
	_expect(
		int(over_threshold_full["peak_active"]) > ImpactPlayer.POOL_CAP,
		"the threshold must be the measured switchover: %d victims still peak at %d inside the cap %d"
			% [threshold + 1, int(over_threshold_full["peak_active"]), ImpactPlayer.POOL_CAP],
		errors
	)
	var degraded := _run_impacts(MAX_SCENARIO_ENEMIES, threshold, UNBOUNDED_POOL)
	print("  degradation: threshold=%d full_peak_at_threshold=%d full_peak_at_%d=%d degraded_peak_at_%d=%d" % [
		threshold,
		int(at_threshold["peak_active"]),
		threshold + 1,
		int(over_threshold_full["peak_active"]),
		MAX_SCENARIO_ENEMIES,
		int(degraded["peak_active"]),
	])
	_expect(
		bool(degraded["degraded"]) and int(degraded["peak_active"]) <= ImpactPlayer.POOL_CAP,
		"the reduced variant must bring the largest crowd back inside the pool cap (peak %d)"
			% int(degraded["peak_active"]),
		errors
	)
	_expect(
		float(degraded["burst_seconds"]) < float(at_threshold["burst_seconds"]),
		"the reduced variant must show fewer frames than the full burst",
		errors
	)
	_expect(
		is_equal_approx(float(degraded["burst_scale"]), ImpactPlayer.DEGRADED_SCALE),
		"the reduced variant must draw at %.2f scale, drew %.2f"
			% [ImpactPlayer.DEGRADED_SCALE, float(degraded["burst_scale"])],
		errors
	)
	_expect(
		int(degraded["flashes"]) == MAX_SCENARIO_ENEMIES,
		"degradation must never take the white flash away (%d of %d victims flashed)"
			% [int(degraded["flashes"]), MAX_SCENARIO_ENEMIES],
		errors
	)


## Area telegraphs are demoted to flavour: the shipped packs already read
## through their own effects, a scene whose blinking area frame is the read
## fails, and the same frame beside real effects passes.
func _test_area_telegraph_demotion(errors: Array[String]) -> void:
	for raw_pack in PACKS:
		var pack := raw_pack as Dictionary
		var scene := (pack["scene"] as PackedScene).instantiate()
		_expect(
			Contract.scene_telegraph_violations(scene, str(pack["id"])).is_empty(),
			"%s must not read through an area telegraph: %s"
				% [pack["id"], str(Contract.scene_telegraph_violations(scene, str(pack["id"])))],
			errors
		)
		scene.free()

	var primary := _area_frame_scene(true)
	var primary_violations := Contract.scene_telegraph_violations(primary, "fixture/area_frame")
	_expect_code(primary_violations, "telegraph.only_read", "an area frame as the whole read must fail closed", errors)
	_expect_code(primary_violations, "telegraph.blink", "a blinking area frame must fail closed", errors)
	primary.free()

	var flavour := _area_frame_scene(false)
	_expect(
		Contract.scene_telegraph_violations(flavour, "fixture/flavour").is_empty(),
		"a short area flavour beside real effects must stay allowed: %s"
			% str(Contract.scene_telegraph_violations(flavour, "fixture/flavour")),
		errors
	)
	flavour.free()


## One activation of the impact service, driven at a fixed step so the result is
## the same on every machine. Victims are placed farthest-first, so a correct
## ripple has to reorder them by distance from the cast point.
func _run_impacts(victims: int, threshold: int, cap: int, feedback_enabled := true) -> Dictionary:
	var player := ImpactPlayer.new()
	player.pool_cap = cap
	player.degrade_threshold = threshold
	var flash_log: Array = []
	var targets: Array = []
	for index in victims:
		var victim := ImpactVictim.new()
		victim.flash_log = flash_log
		victim.feedback_enabled = feedback_enabled
		victim.position = Vector2(float(victims - index) * 37.0, 0.0)
		targets.append(victim)
	var plan := player.play(ImpactFrames.make(), targets, Vector2.ZERO)
	var burst_scale := 0.0
	for step in IMPACT_STEPS:
		player.advance(IMPACT_STEP_SECONDS)
		for child in player.get_children():
			var sprite := child as AnimatedSprite2D
			if sprite != null and sprite.visible:
				burst_scale = maxf(burst_scale, sprite.scale.x)
	var result := player.snapshot()
	result["stagger_frames"] = int(plan["stagger_frames"])
	result["ordered"] = _is_outward(flash_log)
	result["burst_scale"] = burst_scale
	player.finish()
	result["pooled_after_finish"] = int(player.snapshot()["pooled"])
	player.free()
	for victim in targets:
		(victim as Node).free()
	return result


## Two beats of one activation sharing one ripple: the first beat pops six
## victims, the ripple is advanced halfway, then the second beat's six victims
## join the still-running queue.
func _run_joined_impacts() -> Dictionary:
	var player := ImpactPlayer.new()
	var flash_log: Array = []
	var beat_one: Array = []
	var beat_two: Array = []
	for index in 6:
		var near := ImpactVictim.new()
		near.flash_log = flash_log
		near.position = Vector2(40.0 + float(index) * 30.0, 0.0)
		beat_one.append(near)
		var far := ImpactVictim.new()
		far.flash_log = flash_log
		far.position = Vector2(400.0 + float(index) * 30.0, 0.0)
		beat_two.append(far)
	player.play(ImpactFrames.make(), beat_one, Vector2.ZERO)
	var halfway := player.burst_seconds() * 0.5
	while halfway > 0.0:
		player.advance(IMPACT_STEP_SECONDS)
		halfway -= IMPACT_STEP_SECONDS
	player.enqueue(beat_two, Vector2.ZERO)
	var remaining := player.burst_seconds() + 1.0
	while remaining > 0.0:
		player.advance(IMPACT_STEP_SECONDS)
		remaining -= IMPACT_STEP_SECONDS
	var result := player.snapshot()
	result["ordered"] = _is_outward(flash_log)
	player.finish()
	player.free()
	for victim in beat_one + beat_two:
		(victim as Node).free()
	return result


## Every victim was hit no earlier than a nearer one.
func _is_outward(flash_log: Array) -> bool:
	for index in range(1, flash_log.size()):
		var previous := (flash_log[index - 1] as Node2D).position.length()
		if (flash_log[index] as Node2D).position.length() < previous - 0.01:
			return false
	return true


## An area frame with a blink animation. As the primary read it is the only
## drawn node and blinks four times; as flavour it fades in and out once beside
## three real effect sprites.
func _area_frame_scene(primary: bool) -> Node2D:
	var root := Node2D.new()
	var frame := Line2D.new()
	frame.name = "AreaFrame"
	frame.points = PackedVector2Array([
		Vector2(-96.0, -64.0),
		Vector2(96.0, -64.0),
		Vector2(96.0, 64.0),
		Vector2(-96.0, 64.0),
		Vector2(-96.0, -64.0),
	])
	root.add_child(frame)

	var animation := Animation.new()
	animation.length = 1.0
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath("AreaFrame:modulate:a"))
	var keys: Array = [1.0, 0.0, 1.0, 0.0, 1.0] if primary else [0.0, 0.9, 0.0]
	for index in keys.size():
		animation.track_insert_key(track, float(index) * 0.2, keys[index])
	var library := AnimationLibrary.new()
	library.add_animation("ultimate", animation)
	var player := AnimationPlayer.new()
	player.add_animation_library("", library)
	root.add_child(player)

	if not primary:
		for index in 3:
			var effect := Sprite2D.new()
			effect.name = "Effect%d" % index
			root.add_child(effect)
	return root


## A drawn node carrying its own material, so a control grows the measured
## material count by exactly one.
func _with_material(node: CanvasItem) -> CanvasItem:
	node.material = CanvasItemMaterial.new()
	return node


func _budget_violations(violations: Array[String]) -> Array[String]:
	var found: Array[String] = []
	for violation in violations:
		if Contract.gate_of(violation) == "budget":
			found.append(violation)
	return found


func _expect_code(violations: Array[String], code: String, message: String, errors: Array[String]) -> void:
	for violation in violations:
		if violation.begins_with("%s:" % code):
			return
	errors.append("%s (reported %s)" % [message, str(violations)])


func _expect(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)
