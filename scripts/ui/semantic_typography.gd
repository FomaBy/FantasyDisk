class_name SemanticTypography
extends RefCounted

## Canonical player-facing typography contract (SCRUM-1061).
##
## `resolve()` is the preferred semantic path for new UI. The `*_compat()`
## resolvers intentionally preserve accepted authored geometry while old call
## sites are assigned semantic roles by the machine inventory. Keeping that
## compatibility boundary here prevents local helpers from quietly inventing a
## second scale.

const ROLE_DISPLAY := &"display"
const ROLE_TITLE := &"title"
const ROLE_SECTION := &"section"
const ROLE_BODY := &"body"
const ROLE_DESCRIPTION := &"description"
const ROLE_ACTION := &"action"
const ROLE_TAB := &"tab"
const ROLE_FIELD := &"field"
const ROLE_VALUE := &"value"
const ROLE_TOOLTIP := &"tooltip"
const ROLE_CAPTION := &"caption"
const ROLE_HUD := &"hud"

const TARGET_DISPLAY := 44
const TARGET_TOOLTIP := 20

const READABILITY_FONT_SCALE_MIN := 1.32
const READABILITY_FONT_SCALE_TARGET := 1.45
const READABILITY_HEIGHT_MIN := 648.0
const READABILITY_HEIGHT_TARGET := 864.0

const TOKENS := {
	ROLE_DISPLAY: {"min": 32, "target": TARGET_DISPLAY, "max": 72, "overflow": "single_line_fit_or_expand_zone"},
	ROLE_TITLE: {"min": 24, "target": 34, "max": 54, "overflow": "wrap_two_lines_then_ellipsis"},
	ROLE_SECTION: {"min": 20, "target": 24, "max": 34, "overflow": "single_line_expand_then_ellipsis"},
	ROLE_BODY: {"min": 16, "target": 18, "max": 24, "overflow": "word_wrap_grow_or_scroll"},
	ROLE_DESCRIPTION: {"min": 14, "target": 17, "max": 22, "overflow": "word_wrap_grow_or_scroll"},
	ROLE_ACTION: {"min": 16, "target": 23, "max": 34, "overflow": "wrap_two_lines_never_shrink_below_min"},
	ROLE_TAB: {"min": 16, "target": 23, "max": 28, "overflow": "single_line_expand_plate_or_wrap_two_lines"},
	ROLE_FIELD: {"min": 16, "target": 20, "max": 28, "overflow": "single_line_expand_row_then_ellipsis"},
	ROLE_VALUE: {"min": 16, "target": 20, "max": 28, "overflow": "single_line_reserve_numeric_column"},
	ROLE_TOOLTIP: {"min": 18, "target": TARGET_TOOLTIP, "max": 24, "overflow": "word_wrap_widen_then_grow"},
	ROLE_CAPTION: {"min": 12, "target": 14, "max": 18, "overflow": "single_line_ellipsis_or_documented_exception"},
	ROLE_HUD: {"min": 14, "target": 22, "max": 34, "overflow": "single_line_fixed_feedback_zone"},
}


static func roles() -> Array[StringName]:
	return [
		ROLE_DISPLAY, ROLE_TITLE, ROLE_SECTION, ROLE_BODY, ROLE_DESCRIPTION,
		ROLE_ACTION, ROLE_TAB, ROLE_FIELD, ROLE_VALUE, ROLE_TOOLTIP,
		ROLE_CAPTION, ROLE_HUD,
	]


static func token(role: StringName) -> Dictionary:
	assert(TOKENS.has(role), "Unknown semantic typography role: %s" % role)
	return (TOKENS[role] as Dictionary).duplicate(true)


static func role_min(role: StringName) -> int:
	return int(token(role)["min"])


static func role_target(role: StringName) -> int:
	return int(token(role)["target"])


static func role_max(role: StringName) -> int:
	return int(token(role)["max"])


static func overflow_policy(role: StringName) -> String:
	return str(token(role)["overflow"])


static func resolve(role: StringName, viewport_height: float) -> int:
	var spec := token(role)
	var min_px := int(spec["min"])
	var target_px := int(spec["target"])
	var max_px := int(spec["max"])
	if viewport_height <= 1080.0:
		var compact_t := clampf((viewport_height - READABILITY_HEIGHT_MIN) / (1080.0 - READABILITY_HEIGHT_MIN), 0.0, 1.0)
		return int(roundf(lerpf(float(min_px), float(target_px), compact_t)))
	var large_t := clampf((viewport_height - 1080.0) / (2160.0 - 1080.0), 0.0, 1.0)
	return int(roundf(lerpf(float(target_px), float(max_px), large_t)))


static func readability_scale(viewport_height: float) -> float:
	var t := clampf(
		(viewport_height - READABILITY_HEIGHT_MIN) /
		(READABILITY_HEIGHT_TARGET - READABILITY_HEIGHT_MIN),
		0.0,
		1.0
	)
	return lerpf(READABILITY_FONT_SCALE_MIN, READABILITY_FONT_SCALE_TARGET, t)


static func resolve_authored_compat(
	role: StringName,
	authored_px: float,
	viewport_height: float,
	min_px := 0,
	max_px := 96
) -> int:
	# Role is deliberately required even though compatibility bounds remain
	# authored. The inventory can therefore trace every retained value to a
	# semantic purpose without changing accepted layout geometry.
	assert(TOKENS.has(role), "Unknown semantic typography role: %s" % role)
	var scaled := int(roundf(authored_px * readability_scale(viewport_height)))
	if min_px > 0:
		scaled = maxi(scaled, min_px)
	if max_px > 0:
		scaled = mini(scaled, max_px)
	return scaled


static func resolve_scaled_compat(
	role: StringName,
	authored_px: float,
	scale: float,
	min_px := 0,
	max_px := 96
) -> int:
	assert(TOKENS.has(role), "Unknown semantic typography role: %s" % role)
	var scaled := int(roundf(authored_px * scale))
	if min_px > 0:
		scaled = maxi(scaled, min_px)
	if max_px > 0:
		scaled = mini(scaled, max_px)
	return scaled


static func resolve_fixed(role: StringName, authored_px: float, min_px := 0, max_px := 96) -> int:
	return resolve_scaled_compat(role, authored_px, 1.0, min_px, max_px)


static func resolve_transform_aware(
	role: StringName,
	design_px: int,
	stage_scale: float,
	min_visual_px := -1,
	max_visual_px := -1
) -> int:
	# A transformed stage scales both the Control and its font. Return the local
	# design-space px that keeps the final visual result inside semantic bounds.
	var safe_scale := maxf(0.01, stage_scale)
	var visual_min := role_min(role) if min_visual_px < 0 else min_visual_px
	var visual_max := role_max(role) if max_visual_px < 0 else max_visual_px
	var raw_visual_px := float(design_px) * safe_scale
	if raw_visual_px < float(visual_min):
		return maxi(1, int(ceilf(float(visual_min) / safe_scale)))
	if raw_visual_px > float(visual_max):
		return maxi(1, int(floorf(float(visual_max) / safe_scale)))
	return design_px


static func apply(control: Control, role: StringName, viewport_height: float) -> int:
	var effective_px := resolve(role, viewport_height)
	control.add_theme_font_size_override("font_size", effective_px)
	control.set_meta("semantic_typography_role", str(role))
	control.set_meta("semantic_typography_overflow", overflow_policy(role))
	return effective_px
