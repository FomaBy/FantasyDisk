class_name UIButtonFamily
extends RefCounted

const UIThemePaths := preload("res://scripts/ui/ui_theme_paths.gd")

const META_FAMILY := "ui_button_family"
const META_FAMILY_EXPLICIT := "ui_button_family_explicit"
const STATES := ["normal", "hover", "pressed", "focus", "disabled"]

const FAMILY_CONTENT_ROW := "content_row"
const FAMILY_CHOICE_CARD := "choice_card"
const FAMILY_LEVEL_UP_CARD := "level_up_card"
const FAMILY_REWARD_CARD := "reward_card"
const FAMILY_WEAPON_CARD := "weapon_card"
const FAMILY_SETTINGS_FIELD := "settings_field"
const FAMILY_SLIM_ACTION := "slim_action"
const FAMILY_MAIN_MENU := "text/main_menu_380x104"
const MAIN_MENU_SOURCE_SIZE := Vector2(380.0, 104.0)

# Families which deliberately do not use the shared text-action plate. Runtime
# inventory tests accept them only when their owning screen helper tags them.
const SPECIALTY_FAMILIES := [
	FAMILY_CONTENT_ROW,
	FAMILY_CHOICE_CARD,
	FAMILY_LEVEL_UP_CARD,
	FAMILY_REWARD_CARD,
	FAMILY_WEAPON_CARD,
	FAMILY_SETTINGS_FIELD,
	"settings_toggle",
	"checkbox",
	FAMILY_SLIM_ACTION,
	"hero_carousel_arrow",
	"route_node",
	"atlas_medallion",
	"atlas_socket",
	"combat_level_up_plus",
	"battle_prayer_card",
	"invisible_catcher",
	"credits_icon",
	"overhaul_2k/cr_btn",
	"overhaul_2k/rc_btn",
]


static func assign(button: BaseButton, family: String, explicit := true) -> String:
	if button == null:
		return family
	button.set_meta(META_FAMILY, family)
	button.set_meta(META_FAMILY_EXPLICIT, explicit)
	return family


static func resolve(button: Button, variant := "default", explicit_family := "") -> String:
	if button == null:
		return ""
	if explicit_family != "":
		return assign(button, explicit_family, true)
	if bool(button.get_meta(META_FAMILY_EXPLICIT, false)):
		return str(button.get_meta(META_FAMILY, ""))
	return assign(button, infer(button, variant), false)


static func infer(button: Button, variant := "default") -> String:
	if button == null:
		return "minimal/standard"
	var text_id := text_family_id(button)
	if text_id != "":
		return "text/%s" % text_id
	var minimal_type := minimal_family_type(button, variant)
	if minimal_type == "combat_level_up_plus":
		return minimal_type
	return "minimal/%s" % minimal_type


static func text_family_id(button: Button) -> String:
	if button == null:
		return ""
	var button_name := str(button.name)
	var size := button.custom_minimum_size
	if button_name == "LevelUpPlusButton":
		return ""
	if button_name.begins_with("CodexTab_"):
		return "main_menu_380x104"
	if button_name in ["AscensionMinusButton", "AscensionPlusButton"] or size.x <= 70.0:
		return ""
	if button_name.begins_with("MainMenu"):
		if size.y <= 76.0:
			return "continue_run_long_420x72"
		return "main_menu_380x104"
	if button_name == "HS4ChooseButton":
		return "main_menu_380x104"
	if button_name.begins_with("RunPause"):
		return "pause_280x60"
	if button_name.begins_with("QuitConfirm"):
		return "quit_220x72"
	if button_name == "ContinueRunButton":
		return "continue_run_long_420x72" if size.x >= 360.0 else "continue_240x72"
	if button_name == "ContinueRunNewGameButton":
		return "continue_240x72"
	if button_name == "LevelUpLaterButton":
		return "later_260x72"
	if button_name == "SettingsBackButton":
		return "back_260x104"
	if button_name == "SettingsResetBindingsButton":
		return "reset_bindings_long_560x104" if size.x >= 540.0 else "wide_440x104"
	if button_name == "SettingsResetAudioButton":
		return "standard_420x104"
	if button_name == "FeedbackSendButton":
		return "feedback_260x64"
	if button_name == "FeedbackCancelButton":
		return "feedback_cancel_220x64"
	if button_name == "EventBackButton":
		return "back_260x104"
	if button_name.begins_with("BindingButton_") or button_name == "SettingsAimModeOption":
		return "rebind_420x62"
	if button_name in ["RebindConflictRetryButton", "RebindConflictBackButton"]:
		return ""
	if button_name in ["WeaponSelectBackButton", "StartBoonBackButton", "SkillTreeBackButton", "PatchNotesBackButton"]:
		return "back_260x104"
	if button_name in ["AttributeRerollButton", "AttributeSkipButton", "VictoryNewRunButton", "DeathRetryButton"]:
		return "standard_420x104"
	if size.y <= 56.0 and size.x >= 340.0:
		return "event_back_380x54"
	if size.y <= 66.0 and size.x >= 360.0:
		return "rebind_420x62"
	if size.y <= 66.0 and size.x >= 240.0:
		return "settings_back_280x64"
	if size.y <= 76.0 and size.x <= 230.0:
		return "quit_220x72"
	if size.y <= 76.0 and size.x <= 250.0:
		return "continue_240x72"
	if size.y <= 76.0 and size.x <= 300.0:
		return "later_260x72"
	if size.y >= 96.0 and size.x >= 430.0:
		return "wide_440x104"
	if size.y >= 96.0 and size.x >= 400.0:
		return "standard_420x104"
	if size.y >= 96.0 and size.x >= 240.0:
		return "back_260x104"
	return ""


static func minimal_family_type(button: Button, variant := "default") -> String:
	var button_name := str(button.name) if button != null else ""
	var button_text := button.text.to_lower() if button != null else ""
	var size := button.custom_minimum_size if button != null else Vector2(420.0, 104.0)
	if button_name == "LevelUpPlusButton":
		return "combat_level_up_plus"
	if button_name.begins_with("MainMenu"):
		return "main_menu"
	if button_name in ["HeroSelectChooseButton", "HS4ChooseButton"]:
		return "hero_confirm"
	if button_name == "SettingsResetAudioButton":
		return "reset_audio"
	if button_name == "SettingsResetBindingsButton":
		return "reset_bindings"
	if button_name.begins_with("AttributeOffer_"):
		return "attr_selector"
	if button_name.begins_with("RunPause") or button_name.begins_with("QuitConfirm"):
		return "pause"
	if button_name.begins_with("BindingButton_") or button_name == "SettingsAimModeOption":
		return "rebind"
	if button_name in ["AscensionMinusButton", "AscensionPlusButton"] or size.x <= 64.0:
		return "utility"
	if variant == "level_up" or button_name == "LevelUpButton":
		return "back_l"
	if button_text == "назад":
		if size.x <= 180.0:
			return "back_s"
		if size.x <= 300.0:
			return "back_m"
		return "back_l"
	if variant in ["reward", "primary"] and size.x >= 540.0:
		return "attr_selector"
	if size.y <= 66.0:
		if size.x <= 70.0:
			return "utility"
		if size.x <= 300.0:
			return "pause"
		return "rebind"
	if size.x >= 540.0:
		return "max"
	if size.x >= 430.0:
		return "reset_bindings"
	if size.x >= 400.0:
		return "standard"
	if size.x >= 360.0:
		return "back_l"
	if size.x >= 300.0:
		return "hero_confirm"
	if size.x >= 240.0:
		return "back_m"
	return "back_s"


static func descriptor(family: String, state: String) -> Dictionary:
	var texture_state := state if STATES.has(state) else "normal"
	if family.begins_with("text/"):
		var text_id := family.trim_prefix("text/")
		var textures: Dictionary = UIThemePaths.TEXT_BUTTON_UNIQUE_TEXTURES.get(text_id, {})
		if textures.is_empty():
			return {}
		return {
			"path": str(textures.get(texture_state, textures.get("normal", ""))),
			"margins": UIThemePaths.TEXT_BUTTON_UNIQUE_MARGINS.get(text_id, UIThemePaths.TEXT_BUTTON_UNIQUE_MARGINS["standard_420x104"]),
			"content": UIThemePaths.TEXT_BUTTON_UNIQUE_CONTENT.get(text_id, UIThemePaths.TEXT_BUTTON_UNIQUE_CONTENT["standard_420x104"]),
		}
	var minimal_type := family.trim_prefix("minimal/")
	if family == FAMILY_SLIM_ACTION:
		# Semantic action family. It intentionally reuses the accepted slim metal
		# source until a dedicated production export replaces it.
		minimal_type = "rebind"
	var suffix := "" if texture_state == "normal" else "_%s" % texture_state
	return {
		"path": "%sui_btn_minimal_metal_%s%s.png" % [UIThemePaths.MINIMAL_METAL_BUTTON_DIR, minimal_type, suffix],
		"margins": Vector4(34.0, 14.0, 34.0, 14.0) if family == FAMILY_SLIM_ACTION else UIThemePaths.MINIMAL_METAL_BUTTON_MARGINS.get(minimal_type, UIThemePaths.MINIMAL_METAL_BUTTON_MARGINS["standard"]),
		"content": Vector4(46.0, 18.0, 46.0, 18.0) if family == FAMILY_SLIM_ACTION else UIThemePaths.MINIMAL_METAL_BUTTON_CONTENT.get(minimal_type, UIThemePaths.MINIMAL_METAL_BUTTON_CONTENT["standard"]),
	}


static func descriptor_for_size(family: String, state: String, target_size: Vector2) -> Dictionary:
	var result := descriptor(family, state)
	if result.is_empty() or family != FAMILY_MAIN_MENU:
		return result
	var uniform_scale := minf(
		target_size.x / MAIN_MENU_SOURCE_SIZE.x,
		target_size.y / MAIN_MENU_SOURCE_SIZE.y
	)
	result["margins"] = (result["margins"] as Vector4) * uniform_scale
	result["content"] = (result["content"] as Vector4) * uniform_scale
	result["source_scale"] = uniform_scale
	return result


static func is_registered(family: String) -> bool:
	if family.begins_with("text/"):
		return UIThemePaths.TEXT_BUTTON_UNIQUE_TEXTURES.has(family.trim_prefix("text/"))
	if family.begins_with("minimal/"):
		return UIThemePaths.MINIMAL_METAL_BUTTON_MARGINS.has(family.trim_prefix("minimal/"))
	return SPECIALTY_FAMILIES.has(family)
