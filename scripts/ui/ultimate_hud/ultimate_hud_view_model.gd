extends RefCounted

## FAN-1458 — сборка состояния ultimate-HUD из snapshot реестра ультимейтов.
##
## Вход — словарь-снапшот, который адаптер (или fixture) собирает из read-only
## источников: профиль `WeaponUltimateRegistry.catalog_profile_for`, источник
## `resolution_source`, конфиг оружия из `ProgressionData.WEAPONS_BY_CLASS` и
## человекочитаемый текст ульты. Ключевой инвариант карточки: идентичность в
## HUD — ВСЕГДА выбранное оружие из профиля реестра. Даже когда исполняемая
## ульта резолвится в legacy class fallback, виджет обязан показывать weapon
## icon/title выбранного оружия, а не класс.

const State := preload("res://scripts/ui/ultimate_hud/ultimate_hud_state.gd")

# Исторические имена файлов для стартовых оружий Берсерка (совпадает с
# конвенцией ассетов assets/sprites/weapons/*.png).
const WEAPON_ASSET_ALIASES := {
	"sword": "two_handed_sword",
	"axe": "two_handed_axe",
	"hammer": "two_handed_hammer",
}
const WEAPON_ICON_KEYS := ["icon_path", "sprite_path", "weapon_sprite_path"]
const WEAPON_ICON_DIR := "res://assets/sprites/weapons"


## snapshot: {
##   "profile": Dictionary,            # registry.catalog_profile_for(...)
##   "resolution_source": String,      # registry.resolution_source(...)
##   "weapon_config": Dictionary,      # WEAPONS_BY_CLASS[class_id][weapon_id]
##   "ultimate_text": Dictionary,      # {"title": ..., "description": ...}
##   "charge": Dictionary, "input": Dictionary, "aim": Dictionary,
## }
static func build(snapshot: Dictionary) -> Dictionary:
	var profile := _dictionary(snapshot.get("profile"))
	var identity := _dictionary(profile.get("identity"))
	var weapon_config := _dictionary(snapshot.get("weapon_config"))
	var ultimate_text := _dictionary(snapshot.get("ultimate_text"))
	var weapon_id := str(profile.get("weapon_id", ""))
	var weapon_title := str(weapon_config.get("title", ""))
	if weapon_title.is_empty():
		weapon_title = weapon_id
	return State.normalize(
		{
			"selection": {
				"class_id": str(profile.get("class_id", "")),
				"weapon_id": weapon_id,
				"profile_id": str(identity.get("profile_id", "")),
				"title_id": str(identity.get("title_id", "")),
				"weapon_title": weapon_title,
				"weapon_icon_path": weapon_icon_path(weapon_config, weapon_id),
				"source": snapshot.get("resolution_source", ""),
			},
			"ultimate": ultimate_text,
			"charge": snapshot.get("charge", {}),
			"input": snapshot.get("input", {}),
			"aim": snapshot.get("aim", {}),
		}
	)


## Путь иконки оружия: явные ключи конфига, затем конвенция ассетов.
## Существование ресурса здесь не проверяется — виджет грузит null-safe.
static func weapon_icon_path(weapon_config: Dictionary, weapon_id: String) -> String:
	for key in WEAPON_ICON_KEYS:
		var configured := str(weapon_config.get(key, ""))
		if not configured.is_empty():
			return configured
	if weapon_id.is_empty():
		return ""
	var asset_id := str(WEAPON_ASSET_ALIASES.get(weapon_id, weapon_id))
	return "%s/%s.png" % [WEAPON_ICON_DIR, asset_id]


static func _dictionary(raw: Variant) -> Dictionary:
	return raw if raw is Dictionary else {}
