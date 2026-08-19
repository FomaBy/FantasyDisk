extends SceneTree

## Basic-attack flipbook ratchet (Combat VFX Art Standard v1.2, FAN-3006/FAN-3010).
##
## Every basic-attack effect must be a drawn PixelLab flipbook resolved by the
## convention path
## res://assets/sprites/effects/<class>/<weapon>/<effect>/<effect>_spriteframes.tres.
## Effects still showing the temporary static stand-in live in the shrink-only
## allowlists below — same ratchet rules as
## `tests/combat_primitive_ratchet_test.gd`; the target state is empty.
## Standard: docs/design/systems/weapon_ultimate_presentation.md.

const AttackVfxScript := preload("res://scripts/attack_vfx.gd")
const ProgressionDataScript := preload("res://scripts/progression_data.gd")

# Оружие, чья сигнатура релиза всё ещё берётся из статичной vfx_weapon_*.png.
# Ключ — "<class>/<weapon>"; арт-карта класса удаляет свои три записи вместе с
# паком <class>/<weapon>/weapon_signature/. Список только сокращается.
const SIGNATURE_FALLBACK_ALLOWLIST: Array[String] = [
	"assassin/chakrams",
	"assassin/shadow_daggers",
	"assassin/venom_wire",
	"berserk/axe",
	"berserk/hammer",
	"berserk/sword",
	"biologist/biologist_sample_injector",
	"biologist/biologist_spore_lens",
	"biologist/biologist_symbiote_seed",
	"chemist/acid_flask",
	"chemist/blast_powder",
	"chemist/homunculus_vial",
	"dark_mage/cursed_skull",
	"dark_mage/dark_book",
	"dark_mage/dark_wand",
	"doctor/bone_saw",
	"doctor/plague_syringe",
	"doctor/restore_potion",
	"druid/briar_staff",
	"druid/raven_totem",
	"druid/summon_amulet",
	"elementalist/elementalist_meteor_core",
	"elementalist/elementalist_orb_ring",
	"elementalist/elementalist_prism_focus",
	"engineer/engineer_pressure_mines",
	"engineer/engineer_repair_drone",
	"engineer/engineer_sentry_wrench",
	"guitarist/bass_guitar",
	"guitarist/electric_guitar",
	"guitarist/sound_amp",
	"knight/holy_flail",
	"knight/long_spear",
	"knight/tower_shield",
	"priest/priest_censer",
	"priest/priest_chime",
	"priest/priest_reliquary",
	"ranger/hunter_trap",
	"ranger/moon_crossbow",
	"ranger/storm_longbow",
	"robot/robot_hydraulic_press",
	"robot/robot_magnetic_anchor",
	"robot/robot_reactor_core",
	"sniper/sniper_deadeye_rifle",
	"sniper/sniper_shatter_rounds",
	"sniper/sniper_spotter_scope",
	"soldier/soldier_bayonet",
	"soldier/soldier_grenade",
	"soldier/soldier_rifle",
	"thief/thief_coin_pouch",
	"thief/thief_shadow_cloak",
	"thief/thief_smoke_bomb",
]

# Общие семейства эффектов, для которых ещё ни одна пара класс/оружие не имеет
# пака. Запись снимается первой арт-картой, нарисовавшей это семейство.
const FAMILY_FALLBACK_ALLOWLIST: Array[String] = [
	"beam",
	"curse_skull",
	"hammer_slam",
	"orb_burst",
	"orb_projectile",
	"projectile_trace",
	"ring_pulse",
	"slash",
	"sound_wave_blast",
]

var _errors: Array[String] = []


func _init() -> void:
	var pairs := _class_weapon_pairs()
	_check_ratchet(
		"weapon signature",
		SIGNATURE_FALLBACK_ALLOWLIST,
		_signature_fallbacks(pairs),
		"pack %s/weapon_signature/"
	)
	_check_ratchet(
		"effect family",
		FAMILY_FALLBACK_ALLOWLIST,
		_family_fallbacks(pairs),
		"a <class>/<weapon>/%s/ pack"
	)
	_check_family_coverage()

	if _errors.is_empty():
		print("Basic-attack flipbook ratchet passed: %d/%d weapon signatures and %d/%d effect families still on the static stand-in, 0 fallbacks outside the ratchet." % [
			SIGNATURE_FALLBACK_ALLOWLIST.size(),
			pairs.size(),
			FAMILY_FALLBACK_ALLOWLIST.size(),
			AttackVfxScript.EFFECT_FAMILIES.size(),
		])
		quit(0)
	else:
		for error in _errors:
			push_error("Basic-attack flipbook ratchet: %s" % error)
		quit(1)


func _check_ratchet(kind: String, allowlist: Array[String], on_fallback: Array[String], retired_hint: String) -> void:
	for key in on_fallback:
		if not allowlist.has(key):
			_errors.append("new static fallback %s outside the ratchet: %s. The standard requires a PixelLab flipbook; the allowlist never grows." % [kind, key])
	for key in allowlist:
		if not on_fallback.has(key):
			_errors.append("stale ratchet entry: %s %s no longer falls back (%s exists, or the entry no longer matches live content). Remove its allowlist entry." % [
				kind, key, retired_hint % key,
			])


# Список семейств в коде и в храповике обязан совпадать: новое семейство без
# записи иначе просочилось бы мимо проверки.
func _check_family_coverage() -> void:
	for family in AttackVfxScript.EFFECT_FAMILIES:
		if not AttackVfxScript.START_FRAME_VARIATION.has(family):
			_errors.append("effect family %s has no START_FRAME_VARIATION entry; the per-family switch must be explicit." % family)
	for family in FAMILY_FALLBACK_ALLOWLIST:
		if not AttackVfxScript.EFFECT_FAMILIES.has(family):
			_errors.append("stale ratchet entry: effect family %s no longer exists in AttackVfx.EFFECT_FAMILIES." % family)


func _class_weapon_pairs() -> Array[String]:
	var pairs: Array[String] = []
	for class_id in ProgressionDataScript.character_ids():
		for weapon_id in ProgressionDataScript.weapon_ids(str(class_id)):
			pairs.append("%s/%s" % [class_id, weapon_id])
	pairs.sort()
	return pairs


func _signature_fallbacks(pairs: Array[String]) -> Array[String]:
	var fallbacks: Array[String] = []
	for pair in pairs:
		var parts := pair.split("/")
		if AttackVfxScript.effect_pack(parts[0], parts[1], AttackVfxScript.WEAPON_SIGNATURE_EFFECT) == null:
			fallbacks.append(pair)
	return fallbacks


func _family_fallbacks(pairs: Array[String]) -> Array[String]:
	var fallbacks: Array[String] = []
	for family in AttackVfxScript.EFFECT_FAMILIES:
		var drawn := false
		for pair in pairs:
			var parts := pair.split("/")
			if AttackVfxScript.effect_pack(parts[0], parts[1], str(family)) != null:
				drawn = true
				break
		if not drawn:
			fallbacks.append(str(family))
	fallbacks.sort()
	return fallbacks
