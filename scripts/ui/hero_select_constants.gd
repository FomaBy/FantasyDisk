class_name HeroSelectConstants
extends RefCounted

const HERO_RADAR_STATS := ["strength", "agility", "intelligence", "perception", "energy", "knowledge", "endurance", "leadership"]
const HERO_BASE_STATS := ["strength", "agility", "intelligence", "perception", "energy", "knowledge", "endurance", "leadership"]
const HERO_BUILD_RELEVANCE_ORDER := ["primary", "secondary", "optional"]
const HERO_BUILD_RELEVANCE_TITLES := {
	"primary": "Основные атрибуты",
	"secondary": "Второстепенные атрибуты",
	"optional": "Дополнительные атрибуты",
}

# SCRUM-951: semantic attribute identity belongs to the stat, never to the
# selected class. `accent` is the canonical task palette for bars/markers;
# `text` is the readable label/value companion. Strength alone is lightened for
# normal-size text because #D84A3A measures 4.27:1 on the live #171613 row,
# while #E05B4C reaches 4.97:1. Keep this map reusable by future UI surfaces.
const HERO_STAT_COLORS := {
	"strength": {
		"accent": Color(0.847059, 0.290196, 0.227451, 1.0),
		"text": Color(0.878431, 0.356863, 0.298039, 1.0),
	},
	"agility": {
		"accent": Color(0.298039, 0.776471, 0.415686, 1.0),
		"text": Color(0.298039, 0.776471, 0.415686, 1.0),
	},
	"intelligence": {
		"accent": Color(0.298039, 0.552941, 1.0, 1.0),
		"text": Color(0.298039, 0.552941, 1.0, 1.0),
	},
	"perception": {
		"accent": Color(0.956863, 0.772549, 0.258824, 1.0),
		"text": Color(0.956863, 0.772549, 0.258824, 1.0),
	},
	"energy": {
		"accent": Color(0.219608, 0.839216, 0.909804, 1.0),
		"text": Color(0.219608, 0.839216, 0.909804, 1.0),
	},
	"knowledge": {
		"accent": Color(0.650980, 0.458824, 1.0, 1.0),
		"text": Color(0.650980, 0.458824, 1.0, 1.0),
	},
	"endurance": {
		"accent": Color(0.850980, 0.509804, 0.211765, 1.0),
		"text": Color(0.850980, 0.509804, 0.211765, 1.0),
	},
	"leadership": {
		"accent": Color(0.847059, 0.698039, 0.290196, 1.0),
		"text": Color(0.847059, 0.698039, 0.290196, 1.0),
	},
}
const HERO_STAT_FALLBACK_ACCENT := Color(0.92, 0.70, 0.28, 0.95)
const HERO_STAT_FALLBACK_TEXT := Color(0.96, 0.90, 0.70, 1.0)


static func stat_accent_color(stat_id: String) -> Color:
	var entry: Dictionary = HERO_STAT_COLORS.get(stat_id, {})
	return entry.get("accent", HERO_STAT_FALLBACK_ACCENT) as Color


static func stat_text_color(stat_id: String) -> Color:
	var entry: Dictionary = HERO_STAT_COLORS.get(stat_id, {})
	return entry.get("text", HERO_STAT_FALLBACK_TEXT) as Color


const HERO_CLASS_COLORS := {
	"berserk": Color(1.00, 0.38, 0.22, 0.82),
	"soldier": Color(0.84, 0.74, 0.46, 0.82),
	"thief": Color(0.92, 0.68, 0.30, 0.82),
	"elementalist": Color(0.30, 0.82, 1.00, 0.82),
	"sniper": Color(0.82, 0.88, 1.00, 0.82),
	"priest": Color(1.00, 0.90, 0.54, 0.82),
	"biologist": Color(0.48, 0.95, 0.42, 0.82),
	"robot": Color(0.42, 0.82, 1.00, 0.82),
	"engineer": Color(0.86, 0.70, 0.32, 0.82),
	"dark_mage": Color(0.66, 0.32, 1.00, 0.82),
	"guitarist": Color(0.26, 0.72, 1.00, 0.82),
	"assassin": Color(0.95, 0.22, 0.44, 0.82),
	"ranger": Color(0.34, 0.84, 0.34, 0.82),
	"doctor": Color(0.36, 0.96, 0.80, 0.82),
	"chemist": Color(0.74, 0.95, 0.26, 0.82),
	"knight": Color(0.86, 0.80, 0.58, 0.82),
	"druid": Color(0.48, 0.78, 0.36, 0.82),
}
