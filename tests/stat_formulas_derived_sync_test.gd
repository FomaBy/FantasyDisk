extends SceneTree

# SCRUM-715 (refactor wave 0.1.8): cross-module sync between the StatFormulas codex
# (DERIVED_STAT_ORDER / STAT_DEFINITIONS — what the player stat screen lists) and the
# runtime values ProgressionData.derived_parameters() actually produces. The existing
# stat_formulas_smoke_test checks the codex is self-consistent; this guards the seam
# that lets a displayed stat silently render "N/A": a DERIVED_STAT_ORDER entry with no
# default_value that derived_parameters stops producing. Read-only; no formula changes.

const SF := preload("res://scripts/stat_formulas.gd")
const PD := preload("res://scripts/progression_data.gd")

# range_multiplier is intentionally sourced from run_modifiers, not derived_parameters
# (see StatFormulas.stat_sections_for_player) — exempt from the produced-value contract.
const RUN_MODIFIER_SOURCED := ["range_multiplier"]


func _initialize() -> void:
	var errors: Array = []
	var ids: Array = PD.character_ids()
	if ids.is_empty():
		push_error("character_ids() empty.")
		quit(1)
		return

	# Build derived params the same way the runtime does: base stats + a real weapon
	# config so weapon-dependent stats (attack_range, aoe_radius, ...) are present.
	for character_id_raw in ids:
		var cid := str(character_id_raw)
		var stats: Dictionary = PD.base_stats(cid)
		var weapon_ids: Array = PD.weapon_ids(cid)
		var weapon_cfg: Dictionary = PD.weapon(cid, str(weapon_ids[0])) if not weapon_ids.is_empty() else {}
		var derived: Dictionary = PD.derived_parameters(stats, {}, weapon_cfg)

		for stat_id_raw in SF.DERIVED_STAT_ORDER:
			var stat_id := str(stat_id_raw)
			if stat_id in RUN_MODIFIER_SOURCED:
				continue
			var definition: Dictionary = SF.STAT_DEFINITIONS.get(stat_id, {})
			var has_default := definition.has("default_value")
			# A listed derived stat must resolve to a real runtime value OR a documented
			# default; otherwise the stat screen shows "N/A" for it.
			if not derived.has(stat_id) and not has_default:
				errors.append("%s: derived stat '%s' is listed (no default_value) but NOT produced by derived_parameters -> would render N/A" % [cid, stat_id])

	# Every produced derived value that the codex also describes must carry the metadata
	# the stat screen renders (name/format), so live values never fall back to placeholders.
	var probe_stats: Dictionary = PD.base_stats(str(ids[0]))
	var probe_derived: Dictionary = PD.derived_parameters(probe_stats, {}, {})
	for stat_id_raw in SF.DERIVED_STAT_ORDER:
		var stat_id := str(stat_id_raw)
		if not SF.STAT_DEFINITIONS.has(stat_id):
			errors.append("DERIVED_STAT_ORDER '%s' missing from STAT_DEFINITIONS" % stat_id)
			continue
		var definition: Dictionary = SF.STAT_DEFINITIONS[stat_id]
		for required_meta in ["name_ru", "name_en", "description", "formula", "format"]:
			if str(definition.get(required_meta, "")) == "":
				errors.append("STAT_DEFINITIONS['%s'] missing '%s'" % [stat_id, required_meta])

	if not errors.is_empty():
		for e in errors:
			push_error("StatFormulas derived sync: %s" % e)
		push_error("StatFormulas derived sync test: %d errors." % errors.size())
		quit(1)
		return
	print("StatFormulas derived sync test passed (%d characters, %d derived stats)." % [ids.size(), SF.DERIVED_STAT_ORDER.size()])
	quit(0)
