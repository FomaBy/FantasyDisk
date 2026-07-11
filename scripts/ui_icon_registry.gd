extends RefCounted

const SemanticTypography := preload("res://scripts/ui/semantic_typography.gd")

const BASE_STAT_IDS := [
	"strength",
	"agility",
	"intelligence",
	"perception",
	"energy",
	"knowledge",
	"endurance",
	"leadership",
]

const DERIVED_ATTRIBUTE_IDS := [
	"damage",
	"magic_damage",
	"attack_speed",
	"crit_chance",
	"crit_damage_multiplier",
	"move_speed",
	"dodge",
	"defense",
	"absorb",
	"health_point",
	"knockback_distance",
	"attack_range",
	"range_multiplier",
	"aoe_radius",
	"pickup_radius",
	"regeneration",
	"vampiric_amount",
	"vampiric_chance",
	"dot_damage",
	"dot_speed",
	"projectile_speed",
	"aura_radius",
	"buff_power",
	"knockback_power",
	"summon_amount",
	"ultimate_multiplier",
]

const HUD_IDS := [
	"hp",
	"xp",
	"money",
]

const ICON_PATHS := {
	"strength": "res://assets/sprites/ui/icons/stats/stat_strength.png",
	"agility": "res://assets/sprites/ui/icons/stats/stat_agility.png",
	"intelligence": "res://assets/sprites/ui/icons/stats/stat_intelligence.png",
	"perception": "res://assets/sprites/ui/icons/stats/stat_perception.png",
	"energy": "res://assets/sprites/ui/icons/stats/stat_energy.png",
	"knowledge": "res://assets/sprites/ui/icons/stats/stat_knowledge.png",
	"endurance": "res://assets/sprites/ui/icons/stats/stat_endurance.png",
	"leadership": "res://assets/sprites/ui/icons/stats/stat_leadership.png",
	"damage": "res://assets/sprites/ui/icons/derived/attr_damage.png",
	"magic_damage": "res://assets/sprites/ui/icons/derived/attr_magic_damage.png",
	"attack_speed": "res://assets/sprites/ui/icons/derived/attr_attack_speed.png",
	"crit_chance": "res://assets/sprites/ui/icons/derived/attr_crit_chance.png",
	"crit_damage_multiplier": "res://assets/sprites/ui/icons/derived/attr_crit_damage_multiplier.png",
	"move_speed": "res://assets/sprites/ui/icons/derived/attr_move_speed.png",
	"dodge": "res://assets/sprites/ui/icons/derived/attr_dodge.png",
	"defense": "res://assets/sprites/ui/icons/derived/attr_defense.png",
	"absorb": "res://assets/sprites/ui/icons/derived/attr_absorb.png",
	"health_point": "res://assets/sprites/ui/icons/derived/attr_health_point.png",
	"knockback_distance": "res://assets/sprites/ui/icons/derived/attr_knockback_distance.png",
	"attack_range": "res://assets/sprites/ui/icons/derived/attr_attack_range.png",
	"range_multiplier": "res://assets/sprites/ui/icons/derived/attr_range_multiplier.png",
	"aoe_radius": "res://assets/sprites/ui/icons/derived/attr_aoe_radius.png",
	"pickup_radius": "res://assets/sprites/ui/icons/derived/attr_pickup_radius.png",
	"regeneration": "res://assets/sprites/ui/icons/derived/attr_regeneration.png",
	"vampiric_amount": "res://assets/sprites/ui/icons/derived/attr_vampiric_amount.png",
	"vampiric_chance": "res://assets/sprites/ui/icons/derived/attr_vampiric_chance.png",
	"dot_damage": "res://assets/sprites/ui/icons/derived/attr_dot_damage.png",
	"dot_speed": "res://assets/sprites/ui/icons/derived/attr_dot_speed.png",
	"projectile_speed": "res://assets/sprites/ui/icons/derived/attr_projectile_speed.png",
	"aura_radius": "res://assets/sprites/ui/icons/derived/attr_aura_radius.png",
	"buff_power": "res://assets/sprites/ui/icons/derived/attr_buff_power.png",
	"knockback_power": "res://assets/sprites/ui/icons/derived/attr_knockback_power.png",
	"summon_amount": "res://assets/sprites/ui/icons/derived/attr_summon_amount.png",
	"ultimate_multiplier": "res://assets/sprites/ui/icons/derived/attr_ultimate_multiplier.png",
	"hp": "res://assets/sprites/ui/hud/hud_hp.png",
	"xp": "res://assets/sprites/ui/hud/hud_xp.png",
	"money": "res://assets/sprites/ui/hud/hud_money.png",
	"artifact": "res://assets/sprites/ui/icons/derived/attr_buff_power.png",
	"system_close": "res://assets/sprites/ui/icons/system/ui_close.png",
	"system_back": "res://assets/sprites/ui/icons/system/ui_back.png",
	"system_settings": "res://assets/sprites/ui/icons/system/ui_settings.png",
	"system_arrow_left": "res://assets/sprites/ui/icons/system/ui_arrow_left.png",
	"system_arrow_right": "res://assets/sprites/ui/icons/system/ui_arrow_right.png",
	"system_arrow_up": "res://assets/sprites/ui/icons/system/ui_arrow_up.png",
	"system_arrow_down": "res://assets/sprites/ui/icons/system/ui_arrow_down.png",
	"system_checkbox_unchecked": "res://assets/sprites/ui/icons/system/ui_checkbox_unchecked.png",
	"system_checkbox_checked": "res://assets/sprites/ui/icons/system/ui_checkbox_checked.png",
	"system_slider_track": "res://assets/sprites/ui/icons/system/ui_slider_track.png",
	"system_slider_grabber": "res://assets/sprites/ui/icons/system/ui_slider_grabber.png",
}

const ICON_ABBREVIATIONS := {
	"strength": "STR",
	"agility": "AGI",
	"intelligence": "INT",
	"perception": "PER",
	"energy": "ENG",
	"knowledge": "KNW",
	"endurance": "END",
	"leadership": "LDR",
	"damage": "DMG",
	"magic_damage": "MAG",
	"attack_speed": "ASP",
	"crit_chance": "CRT",
	"crit_damage_multiplier": "CRD",
	"move_speed": "MOV",
	"dodge": "DGE",
	"defense": "DEF",
	"absorb": "ABS",
	"health_point": "HP",
	"knockback_distance": "KBD",
	"attack_range": "RNG",
	"range_multiplier": "RNG",
	"aoe_radius": "AOE",
	"pickup_radius": "PCK",
	"regeneration": "REG",
	"vampiric_amount": "VMP",
	"vampiric_chance": "VCH",
	"dot_damage": "DOT",
	"dot_speed": "TIC",
	"projectile_speed": "PRJ",
	"aura_radius": "AUR",
	"buff_power": "BUF",
	"knockback_power": "KB",
	"summon_amount": "SUM",
	"ultimate_multiplier": "ULT",
	"hp": "HP",
	"xp": "XP",
	"money": "G",
	"artifact": "ART",
	"system_close": "X",
	"system_back": "<",
	"system_settings": "SET",
	"system_arrow_left": "<",
	"system_arrow_right": ">",
	"system_arrow_up": "^",
	"system_arrow_down": "v",
	"system_checkbox_unchecked": "OFF",
	"system_checkbox_checked": "ON",
	"system_slider_track": "SLD",
	"system_slider_grabber": "KNB",
}

const ICON_COLORS := {
	"strength": Color(0.82, 0.20, 0.18, 1.0),
	"agility": Color(0.24, 0.78, 0.42, 1.0),
	"intelligence": Color(0.44, 0.38, 0.95, 1.0),
	"perception": Color(0.28, 0.72, 0.95, 1.0),
	"energy": Color(1.0, 0.58, 0.18, 1.0),
	"knowledge": Color(0.72, 0.54, 0.98, 1.0),
	"endurance": Color(0.78, 0.82, 0.88, 1.0),
	"leadership": Color(1.0, 0.80, 0.24, 1.0),
	"hp": Color(0.92, 0.08, 0.08, 1.0),
	"xp": Color(0.25, 0.78, 1.0, 1.0),
	"money": Color(1.0, 0.78, 0.22, 1.0),
}

const READABILITY_SMALL_ICON_LIMIT := 72.0
const READABILITY_MEDIUM_ICON_LIMIT := 100.0
const READABILITY_SMALL_ICON_SCALE := 1.45
const READABILITY_MEDIUM_ICON_SCALE := 1.20

static var _texture_cache := {}


static func path_for(icon_id: String) -> String:
	return str(ICON_PATHS.get(icon_id, ""))


static func has_texture(icon_id: String) -> bool:
	var path := path_for(icon_id)
	return path != "" and ResourceLoader.exists(path)


static func texture_for(icon_id: String) -> Texture2D:
	var path := path_for(icon_id)
	if path == "":
		return null
	if _texture_cache.has(path):
		return _texture_cache[path]
	if not ResourceLoader.exists(path):
		_texture_cache[path] = null
		return null
	var texture := load(path) as Texture2D
	_texture_cache[path] = texture
	return texture


static func make_icon(icon_id: String, size: Vector2 = Vector2(42, 42), apply_readability_scale := true) -> Control:
	var display_size := _readable_icon_size(size) if apply_readability_scale else size
	var texture := texture_for(icon_id)
	if texture != null:
		var texture_rect := TextureRect.new()
		texture_rect.name = "UIIcon_%s" % icon_id
		texture_rect.texture = texture
		texture_rect.custom_minimum_size = display_size
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return texture_rect

	var panel := PanelContainer.new()
	panel.name = "UIIcon_%s" % icon_id
	panel.custom_minimum_size = display_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _fallback_style(icon_id))

	var label := Label.new()
	label.text = str(ICON_ABBREVIATIONS.get(icon_id, icon_id.substr(0, min(3, icon_id.length())).to_upper()))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# SCRUM-883: пол фолбэк-бейджа 14 → 16 (аббревиатура ≤3 букв читаема и в мелком слоте).
	label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_HUD, 18 if display_size.x >= 55.0 else 16
	))
	label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.86, 1.0))
	panel.add_child(label)
	return panel


static func _readable_icon_size(size: Vector2) -> Vector2:
	var max_dim := maxf(size.x, size.y)
	if max_dim <= 0.0:
		return size
	if max_dim <= READABILITY_SMALL_ICON_LIMIT:
		return Vector2(roundf(size.x * READABILITY_SMALL_ICON_SCALE), roundf(size.y * READABILITY_SMALL_ICON_SCALE))
	if max_dim <= READABILITY_MEDIUM_ICON_LIMIT:
		return Vector2(roundf(size.x * READABILITY_MEDIUM_ICON_SCALE), roundf(size.y * READABILITY_MEDIUM_ICON_SCALE))
	return size


static func _fallback_style(icon_id: String) -> StyleBoxFlat:
	var base: Color = ICON_COLORS.get(icon_id, Color(0.30, 0.52, 0.68, 1.0))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(base.r * 0.34, base.g * 0.34, base.b * 0.34, 0.96)
	style.border_color = base
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 4
	style.content_margin_top = 4
	style.content_margin_right = 4
	style.content_margin_bottom = 4
	return style
