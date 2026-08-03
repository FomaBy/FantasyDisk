extends RefCounted

# FAN-1891: контракт run-модификаторов после консолидации геометрии и саппорта.
# Вынесен из progression_data.gd под line-ratchet (FAN-2171). Снятые оси не
# приезжают из сейвов/наград; конфигурация оружия может по-прежнему содержать
# внутренние attack_range/projectile_speed — их значения модификаторы не меняют.

const REMOVED_PROGRESSION_MODIFIER_KEYS := [
	"range_multiplier",
	"sector_multiplier",
	"projectile_speed_flat",
	"aura_radius_flat",
	"buff_power_flat",
]
const SUPPORT_AURA_CHARACTER_IDS := ["assassin", "guitarist", "druid", "engineer", "priest"]


static func geometry_capabilities(character_id: String, config: Dictionary) -> Array:
	var capabilities: Array = []
	for dimension in ["aoe_radius", "beam_width", "wave_width", "suppression_width", "inner_width", "outer_width"]:
		if config.has(dimension):
			capabilities.append(dimension)
	var attack_shape := str(config.get("attack_shape", ""))
	if config.has("sweep_degrees") and attack_shape != "circle":
		capabilities.append("sweep_degrees")
	if config.has("cone_degrees") and float(config.get("cone_degrees", 360.0)) < 360.0:
		capabilities.append("cone_degrees")
	if SUPPORT_AURA_CHARACTER_IDS.has(character_id):
		capabilities.append("aura_radius")
	return capabilities


static func is_removed_progression_modifier(key: String) -> bool:
	return REMOVED_PROGRESSION_MODIFIER_KEYS.has(key)


static func sanitize_run_modifiers(modifiers: Dictionary) -> Dictionary:
	var sanitized := modifiers.duplicate(true)
	for key in REMOVED_PROGRESSION_MODIFIER_KEYS:
		sanitized.erase(key)
	return sanitized
