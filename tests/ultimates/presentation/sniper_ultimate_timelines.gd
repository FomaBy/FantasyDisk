extends SceneTree

const Schema := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_schema.gd")
const DirectionContract := preload("res://scripts/ultimates/presentation/ultimate_visual_direction_contract.gd")

const CLASS_ID := "sniper"
const WEAPONS := ["sniper_deadeye_rifle", "sniper_spotter_scope", "sniper_shatter_rounds"]
const ROOT := "res://scenes/vfx/ultimates/sniper"

## Sniper is v2 on presentation but still draws caster-side only: its three
## scenes are in the combat primitive ratchet, and the FAN-3002 retrofit that
## redraws them is what wires the per-victim impacts. Until that card lands the
## class stays in the victim_impact ratchet, so this package asserts every OTHER
## gate. The retrofit removes this constant together with its ratchet entry.
const PENDING_GATES: Array[String] = ["victim_impact"]

var _errors: Array[String] = []


func _initialize() -> void:
	var direction_manifest := DirectionContract.load_manifest(CLASS_ID)
	var direction_violations := DirectionContract.violations(CLASS_ID, direction_manifest).filter(
		func(violation: String) -> bool:
			return not PENDING_GATES.has(DirectionContract.gate_of(violation))
	)
	_check(direction_violations.is_empty(),
		"Sniper must satisfy every visual-direction gate: %s" % [str(direction_violations)])
	for gate in DirectionContract.GATES:
		if PENDING_GATES.has(gate):
			continue
		_check(not (DirectionContract.ADOPTION_GAPS.get(gate, {}) as Dictionary).has(CLASS_ID),
			"Sniper must not remain in the %s visual-direction allowlist" % gate)
	var timings := {}
	for weapon_id in WEAPONS:
		var definition := _definition(weapon_id)
		var manifest := definition.get("manifest", {}) as Dictionary
		_check(not manifest.is_empty(), "%s manifest must parse" % weapon_id)
		_check(not Schema.PRESENTATION_V2_MIGRATION_ALLOWLIST.has("%s/%s" % [CLASS_ID, weapon_id]),
			"%s must leave the presentation migration allowlist" % weapon_id)
		_check(Schema.v2_envelope_errors(manifest.get("timing", {}), weapon_id).is_empty(),
			"%s must fit the v2 timing envelope" % weapon_id)
		var presence := manifest.get("presence", {}) as Dictionary
		_check(presence.get("fullscreen_footprint") == true and presence.get("camera_shake") == true,
			"%s must declare its arena footprint and camera shake" % weapon_id)
		_check(float(presence.get("hitstop_ms", 0.0)) >= 80.0 and float(presence.get("hitstop_ms", 0.0)) <= 150.0,
			"%s must declare first-impact hitstop in the v2 range" % weapon_id)
		var identity := manifest.get("identity", {}) as Dictionary
		_check(not str(identity.get("cast_pose_id", "")).is_empty()
			and FileAccess.file_exists(str(identity.get("cast_pose_asset", "")))
			and FileAccess.file_exists(str(identity.get("weapon_silhouette_asset", "")))
			and str(identity.get("cast_pose_asset", "")) != str(identity.get("weapon_silhouette_asset", ""))
			and str(identity.get("class_palette_id", "")) == "sniper.glacial_crimson",
			"%s must bind separate Sniper hero pose art, weapon silhouette and palette" % weapon_id)
		timings[JSON.stringify(manifest.get("timing", {}), "", true)] = true
	_check(timings.size() == WEAPONS.size(), "Sniper ultimates must have distinct v2 timing rhythms")
	_report()


func _definition(weapon_id: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("%s/%s.timeline.json" % [ROOT, weapon_id]))
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("sniper_ultimate_timelines: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("sniper_ultimate_timelines: %s" % error)
	quit(1)
