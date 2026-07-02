extends SceneTree

# SCRUM-717 (refactor wave 0.2.0): exhaustive existence + anti-drift validation for the
# UIThemePaths theme-path collections. ui_icon_registry_smoke covers ICON_PATHS and
# dark_fantasy_ui_theme covers the minimal_metal frame/button + text_button_unique kits,
# but the active OVERHAUL_2K / LEVEL_UP_SCRUM682 / RED_GOLD / UNIFIED / GLOBAL collections
# were not exhaustively checked. A stale path here = a missing texture at runtime. This is
# read-only validation; no theme path was changed.

const UIThemePaths := preload("res://scripts/ui/ui_theme_paths.gd")


func _initialize() -> void:
	var errors: Array = []

	# Flat path dicts (id -> path).
	_check_path_dict(errors, UIThemePaths.LEVEL_UP_SCRUM682_FRAME_PATHS, "LEVEL_UP_SCRUM682_FRAME_PATHS")
	_check_path_dict(errors, UIThemePaths.OVERHAUL_2K_FRAME_PATHS, "OVERHAUL_2K_FRAME_PATHS")
	_check_path_dict(errors, UIThemePaths.MINIMAL_METAL_FRAME_PATHS, "MINIMAL_METAL_FRAME_PATHS")

	# Nested state dicts (id -> {state -> path}).
	_check_nested_path_dict(errors, UIThemePaths.RED_GOLD_BUTTON_TEXTURES, "RED_GOLD_BUTTON_TEXTURES")
	_check_nested_path_dict(errors, UIThemePaths.TEXT_BUTTON_UNIQUE_TEXTURES, "TEXT_BUTTON_UNIQUE_TEXTURES")

	# Standalone path consts (unified master kit + global aliases + minimal-metal singles).
	var single_paths := {
		"UNIFIED_MASTER_FRAME_PATH": UIThemePaths.UNIFIED_MASTER_FRAME_PATH,
		"UNIFIED_MASTER_FILL_FRAME_PATH": UIThemePaths.UNIFIED_MASTER_FILL_FRAME_PATH,
		"UNIFIED_INNER_FILL_PATH": UIThemePaths.UNIFIED_INNER_FILL_PATH,
		"UNIFIED_ORNAMENT_TOP_PATH": UIThemePaths.UNIFIED_ORNAMENT_TOP_PATH,
		"UNIFIED_ORNAMENT_BOTTOM_PATH": UIThemePaths.UNIFIED_ORNAMENT_BOTTOM_PATH,
		"UNIFIED_HOVER_OVERLAY_PATH": UIThemePaths.UNIFIED_HOVER_OVERLAY_PATH,
		"GLOBAL_PANEL_FRAME_PATH": UIThemePaths.GLOBAL_PANEL_FRAME_PATH,
		"GLOBAL_BUTTON_FRAME_PATH": UIThemePaths.GLOBAL_BUTTON_FRAME_PATH,
		"GLOBAL_CARD_FRAME_PATH": UIThemePaths.GLOBAL_CARD_FRAME_PATH,
		"GLOBAL_HUD_PANEL_FRAME_PATH": UIThemePaths.GLOBAL_HUD_PANEL_FRAME_PATH,
		"GLOBAL_HUD_CARD_FRAME_PATH": UIThemePaths.GLOBAL_HUD_CARD_FRAME_PATH,
		"GLOBAL_TOOLTIP_FRAME_PATH": UIThemePaths.GLOBAL_TOOLTIP_FRAME_PATH,
		"GLOBAL_TIMER_PANEL_FRAME_PATH": UIThemePaths.GLOBAL_TIMER_PANEL_FRAME_PATH,
	}
	for name in single_paths:
		var path := str(single_paths[name])
		if path == "" or not ResourceLoader.exists(path):
			errors.append("%s -> missing resource '%s'" % [name, path])

	# Anti-drift: every OVERHAUL_2K frame path must carry a source-size and 9-slice margin
	# (the file documents these as a single source verified together) so a new slot can't
	# ship a texture with no margin profile (which would render an unstyled stretch).
	for key in UIThemePaths.OVERHAUL_2K_FRAME_PATHS.keys():
		if not UIThemePaths.OVERHAUL_2K_FRAME_SOURCE_SIZE.has(key):
			errors.append("OVERHAUL_2K_FRAME_SOURCE_SIZE missing key '%s'" % str(key))
		if not UIThemePaths.OVERHAUL_2K_FRAME_TEXTURE_MARGINS.has(key):
			errors.append("OVERHAUL_2K_FRAME_TEXTURE_MARGINS missing key '%s'" % str(key))

	if not errors.is_empty():
		for e in errors:
			push_error("UIThemePaths existence: %s" % e)
		push_error("UIThemePaths existence test: %d errors." % errors.size())
		quit(1)
		return
	print("UIThemePaths existence test passed (all theme-path collections resolve).")
	quit()


func _check_path_dict(errors: Array, dict: Dictionary, name: String) -> void:
	for key in dict.keys():
		var path := str(dict[key])
		if path == "" or not ResourceLoader.exists(path):
			errors.append("%s['%s'] -> missing resource '%s'" % [name, str(key), path])


func _check_nested_path_dict(errors: Array, dict: Dictionary, name: String) -> void:
	for key in dict.keys():
		var states: Dictionary = dict[key]
		for state in states.keys():
			var path := str(states[state])
			if path == "" or not ResourceLoader.exists(path):
				errors.append("%s['%s']['%s'] -> missing resource '%s'" % [name, str(key), str(state), path])
