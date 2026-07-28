extends RefCounted

## FAN-1458 — версионированный декларативный контракт состояния ultimate-HUD.
##
## Виджет `ultimate_hud_widget.gd` потребляет ТОЛЬКО нормализованное состояние
## этого контракта: до появления runtime-адаптера (FAN-1457) его подают
## fixtures, после — адаптер живого боя (монтаж владеет FAN-1541). Семантика
## aim/ready не изобретается здесь: режимы и устройства зеркалят канонический
## AimController (FAN-1449, read-only источник), glyph-имена — реестр глифов.
##
## Персистентность: между узлами UI восстанавливается только `charge.fraction`.
## `charge.active` (overlay активной ульты) — runtime-only и НИКОГДА не
## восстанавливается из снапшота; `persistent_snapshot()` стирает его.

# Канонические источники семантики (read-only, править их эта карточка не может).
const AimController := preload("res://scripts/input/aim_controller.gd")

const CONTRACT_VERSION := 1

# Источник резолюции профиля — зеркало констант WeaponUltimateResolver.
const SOURCE_WEAPON_PROFILE := "weapon_profile"
const SOURCE_LEGACY_CLASS_FALLBACK := "legacy_class_fallback"

const DEVICE_KEYBOARD := "keyboard"
const DEVICE_GAMEPAD := "gamepad"
# «Ввод недоступен»: виджет рисует ульту неактивной и не выдаёт activation.
const DEVICE_NONE := "none"

# Режимы наводки — исторические значения AimController ("nearest"/"cursor").
const AIM_MODE_AUTO := AimController.MODE_AUTO
const AIM_MODE_MANUAL := AimController.MODE_MANUAL

# Дефолтная раскладка активации ульты: Y на геймпаде (InputDeviceManager
# GAMEPLAY_ACTION_BINDINGS["ultimate"]), R на клавиатуре (main.gd rebind-таблица).
const DEFAULT_JOY_BUTTON := JOY_BUTTON_Y
const DEFAULT_KEY_LABEL := "R"
const DEFAULT_KEY_GLYPH := "generic"


## Нормализация fail-closed: любой мусор сводится к валидному состоянию,
## в худшем случае — к нерендерируемому (пустая selection → инертный виджет).
static func normalize(raw: Dictionary) -> Dictionary:
	var selection := _dictionary(raw.get("selection"))
	var ultimate := _dictionary(raw.get("ultimate"))
	var charge := _dictionary(raw.get("charge"))
	var input := _dictionary(raw.get("input"))
	var aim := _dictionary(raw.get("aim"))
	return {
		"contract_version": CONTRACT_VERSION,
		"selection": {
			"class_id": str(selection.get("class_id", "")),
			"weapon_id": str(selection.get("weapon_id", "")),
			"profile_id": str(selection.get("profile_id", "")),
			"title_id": str(selection.get("title_id", "")),
			"weapon_title": str(selection.get("weapon_title", "")),
			"weapon_icon_path": str(selection.get("weapon_icon_path", "")),
			"source": _normalize_source(selection.get("source")),
		},
		"ultimate": {
			"title": str(ultimate.get("title", "")),
			"description": str(ultimate.get("description", "")),
		},
		"charge": {
			"fraction": clampf(float(charge.get("fraction", 0.0)), 0.0, 1.0),
			"active": bool(charge.get("active", false)),
		},
		"input": {
			"device": _normalize_device(input.get("device")),
			"joy_button": int(input.get("joy_button", DEFAULT_JOY_BUTTON)),
			"key_label": str(input.get("key_label", DEFAULT_KEY_LABEL)),
			"key_glyph": str(input.get("key_glyph", DEFAULT_KEY_GLYPH)),
		},
		"aim": {
			"mode": AimController.normalize_mode(aim.get("mode", AIM_MODE_AUTO)),
			"aiming": bool(aim.get("aiming", false)),
		},
	}


## Состояние рендерируемо только с полной идентичностью выбранного оружия.
static func is_renderable(state: Dictionary) -> bool:
	var selection := _dictionary(state.get("selection"))
	return str(selection.get("class_id", "")) != "" \
		and str(selection.get("weapon_id", "")) != "" \
		and str(selection.get("profile_id", "")) != ""


static func input_available(state: Dictionary) -> bool:
	var device := str(_dictionary(state.get("input")).get("device", DEVICE_NONE))
	return device == DEVICE_KEYBOARD or device == DEVICE_GAMEPAD


## Готовность = полный заряд при доступном вводе и валидной идентичности.
static func is_ready(state: Dictionary) -> bool:
	if not is_renderable(state) or not input_available(state):
		return false
	return float(_dictionary(state.get("charge")).get("fraction", 0.0)) >= 1.0


## Aim-preview зеркалит AimController.reticle_visible: маркер рисуется только
## в ручном режиме на геймпаде; мышь ведёт собственный курсор, автонаводке
## превью не нужно вовсе.
static func aim_preview_visible(state: Dictionary) -> bool:
	var aim := _dictionary(state.get("aim"))
	if str(aim.get("mode", AIM_MODE_AUTO)) != AIM_MODE_MANUAL:
		return false
	if not bool(aim.get("aiming", false)):
		return false
	return str(_dictionary(state.get("input")).get("device", "")) == DEVICE_GAMEPAD


## Персистентная проекция состояния: тот же заряд, но overlay активной ульты
## принудительно сброшен — active-state не переживает переход между узлами UI.
static func persistent_snapshot(state: Dictionary) -> Dictionary:
	var snapshot := normalize(state)
	(snapshot["charge"] as Dictionary)["active"] = false
	return snapshot


static func _normalize_source(raw: Variant) -> String:
	var source := str(raw)
	if source == SOURCE_WEAPON_PROFILE or source == SOURCE_LEGACY_CLASS_FALLBACK:
		return source
	return ""


static func _normalize_device(raw: Variant) -> String:
	var device := str(raw)
	if device == DEVICE_KEYBOARD or device == DEVICE_GAMEPAD:
		return device
	return DEVICE_NONE


static func _dictionary(raw: Variant) -> Dictionary:
	return raw if raw is Dictionary else {}
