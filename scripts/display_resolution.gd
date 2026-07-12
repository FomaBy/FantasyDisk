extends RefCounted

# SCRUM-441 core: корректная HiDPI/Retina логика «влезает ли разрешение» и клэмпа.
# Корень бага: старый код сравнивал запрошенное разрешение с ЛОГИЧЕСКИМ usable-rect
# (на Retina 14" MBP ≈ 1512x982), из-за чего Full HD/2K отключались/клэмпались, хотя
# ФИЗИЧЕСКИ (usable * screen_scale, Retina scale=2.0 → 3024x1964) они влезают.
#
# Функции PURE (принимают usable_logical + scale параметрами, без вызовов
# DisplayServer) — поэтому юнит-тестируемы headless. UI на call-site передаёт
# DisplayServer.screen_get_usable_rect(screen).size и DisplayServer.screen_get_scale(screen).
# Без class_name (защита от « 2»-дубль-global-class ошибок, SCRUM-440).
#
# Доступ: const DisplayResolution := preload("res://scripts/display_resolution.gd")

# Физический доступный размер экрана: логический usable * scale (Retina=2.0).
# scale < 1.0 трактуем как 1.0 (страховка от мусорных значений драйвера).
static func physical_usable_size(usable_logical: Vector2i, scale: float) -> Vector2i:
	var s := maxf(scale, 1.0)
	return Vector2i(int(round(float(usable_logical.x) * s)), int(round(float(usable_logical.y) * s)))


# Влезает ли разрешение в ФИЗИЧЕСКОЕ пространство экрана (а не в логические точки).
# Именно эту проверку использовать для set_item_disabled — НЕ отключать то, что
# физически помещается (на Retina Full HD/2K проходят).
static func resolution_fits(resolution: Vector2i, usable_logical: Vector2i, scale: float) -> bool:
	var phys := physical_usable_size(usable_logical, scale)
	return resolution.x <= phys.x and resolution.y <= phys.y


# Клэмп запрошенного разрешения к ФИЗИЧЕСКОМУ размеру (по-осно), не к логическому.
# Разрешения, которые влезают, возвращаются без изменений (окно реально их применит).
static func clamp_to_physical(resolution: Vector2i, usable_logical: Vector2i, scale: float) -> Vector2i:
	var phys := physical_usable_size(usable_logical, scale)
	return Vector2i(mini(resolution.x, phys.x), mini(resolution.y, phys.y))


const DEFAULT_RESOLUTION := Vector2i(2560, 1440)
const FALLBACK_RESOLUTION := Vector2i(1920, 1080)
const ALLOWED_RESOLUTIONS := [
	DEFAULT_RESOLUTION,
	FALLBACK_RESOLUTION,
]


static func allowed_resolutions() -> Array:
	return ALLOWED_RESOLUTIONS.duplicate()


static func default_resolution_index(screen_size: Vector2i, scale: float) -> int:
	if resolution_fits(DEFAULT_RESOLUTION, screen_size, scale):
		return 0
	return 1


static func sanitize_resolution_index(index: int) -> int:
	return clampi(index, 0, ALLOWED_RESOLUTIONS.size() - 1)


# SCRUM-1012: pure monitor selector model. DisplayServer stays at the UI
# boundary; headless tests pass virtual screen sizes through these helpers.
static func sanitize_screen_index(screen_sizes: Array[Vector2i], requested_index: int) -> int:
	return clampi(requested_index, 0, maxi(screen_sizes.size() - 1, 0))


static func monitor_options(screen_sizes: Array[Vector2i], requested_index: int) -> Dictionary:
	var options: Array[Dictionary] = []
	for screen_index in range(screen_sizes.size()):
		var screen_size: Vector2i = screen_sizes[screen_index]
		options.append({
			"index": screen_index,
			"size": screen_size,
			"label": "Экран %d (%dx%d)" % [screen_index + 1, screen_size.x, screen_size.y],
		})
	return {
		"visible": options.size() > 1,
		"selected_index": sanitize_screen_index(screen_sizes, requested_index),
		"options": options,
	}
