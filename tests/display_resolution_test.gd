extends SceneTree

# Тест HiDPI/Retina resolution-логики (scripts/display_resolution.gd, SCRUM-441 core).
# Демонстрирует фикс бага: на Retina (scale=2.0) Full HD и 2K ВЛЕЗАЮТ в физпространство
# и НЕ должны отключаться/клэмпаться; на обычном экране (scale=1.0) поведение не сломано.
# Изолированный файл (pure-функции, headless).
#
# Запуск: Godot --headless --path . --script res://tests/display_resolution_test.gd

const DisplayResolution := preload("res://scripts/display_resolution.gd")

const FULL_HD := Vector2i(1920, 1080)
const K2 := Vector2i(2560, 1440)
# 14" MBP Retina: логический usable ≈ 1512x982, scale 2.0 → физ 3024x1964.
const MAC_LOGICAL := Vector2i(1512, 982)
const RETINA_SCALE := 2.0


func _initialize() -> void:
	var errors: Array = []
	_test_physical_size(errors)
	_test_retina_fits(errors)
	_test_non_retina_not_broken(errors)
	_test_clamp(errors)
	_test_scale_guard(errors)
	_test_allowed_policy(errors)
	_write_scrum441_dump()

	if not errors.is_empty():
		for e in errors:
			push_error("Display resolution: %s" % e)
		push_error("Display resolution test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Display resolution test passed.")
	quit(0)


func _expect(errors: Array, cond: bool, msg: String) -> void:
	if not cond:
		errors.append(msg)


func _test_physical_size(errors: Array) -> void:
	var phys := DisplayResolution.physical_usable_size(MAC_LOGICAL, RETINA_SCALE)
	_expect(errors, phys == Vector2i(3024, 1964), "physical_usable_size Retina: ожидалось 3024x1964, получено %s" % phys)
	var phys1 := DisplayResolution.physical_usable_size(FULL_HD, 1.0)
	_expect(errors, phys1 == FULL_HD, "physical_usable_size scale=1: ожидалось 1920x1080, получено %s" % phys1)


func _test_retina_fits(errors: Array) -> void:
	# КОРЕНЬ БАГА: на Retina Full HD и 2K физически влезают → НЕ отключать.
	_expect(errors, DisplayResolution.resolution_fits(FULL_HD, MAC_LOGICAL, RETINA_SCALE),
		"Full HD должно влезать на Retina (1512x982 @2.0 = 3024x1964)")
	_expect(errors, DisplayResolution.resolution_fits(K2, MAC_LOGICAL, RETINA_SCALE),
		"2K должно влезать на Retina")


func _test_non_retina_not_broken(errors: Array) -> void:
	# Обычный 1080p-монитор (scale=1.0): Full HD влезает, 2K — нет (корректно недоступно).
	_expect(errors, DisplayResolution.resolution_fits(FULL_HD, FULL_HD, 1.0),
		"Full HD должно влезать на 1080p-экране")
	_expect(errors, not DisplayResolution.resolution_fits(K2, FULL_HD, 1.0),
		"2K НЕ должно влезать на 1080p-экране (scale=1.0) — не-Mac поведение цело")
	# SCRUM-591: на мониторе 2560×1440 (Windows, scale=1.0) 2K влезает в ПОЛНЫЙ размер
	# экрана — call-site обязан сравнивать с screen_get_size, а не usable-rect минус таскбар.
	_expect(errors, DisplayResolution.resolution_fits(K2, K2, 1.0),
		"2K должно влезать на 2K-мониторе (full screen size, scale=1.0)")
	_expect(errors, DisplayResolution.resolution_fits(FULL_HD, K2, 1.0),
		"Full HD должно влезать на 2K-мониторе (scale=1.0)")


func _test_clamp(errors: Array) -> void:
	# Влезающее — без изменений; невлезающее — клэмп к физразмеру.
	_expect(errors, DisplayResolution.clamp_to_physical(K2, MAC_LOGICAL, RETINA_SCALE) == K2,
		"2K на Retina не должно клэмпаться (влезает)")
	var clamped := DisplayResolution.clamp_to_physical(Vector2i(4000, 3000), MAC_LOGICAL, RETINA_SCALE)
	_expect(errors, clamped == Vector2i(3024, 1964),
		"оверсайз должно клэмпаться к физразмеру 3024x1964, получено %s" % clamped)


func _test_scale_guard(errors: Array) -> void:
	# Мусорный scale < 1.0 трактуется как 1.0 (не «схлопывает» экран).
	var phys := DisplayResolution.physical_usable_size(FULL_HD, 0.0)
	_expect(errors, phys == FULL_HD, "scale=0 должен трактоваться как 1.0, получено %s" % phys)


func _test_allowed_policy(errors: Array) -> void:
	var allowed := DisplayResolution.allowed_resolutions()
	_expect(errors, allowed.size() == 2, "allowed_resolutions должен содержать только 2 варианта")
	_expect(errors, allowed[0] == K2 and allowed[1] == FULL_HD,
		"allowed_resolutions должен быть [2560x1440, 1920x1080], получено %s" % str(allowed))
	_expect(errors, DisplayResolution.default_resolution_index(K2, 1.0) == 0,
		"default_resolution_index должен выбирать 2K, когда он помещается")
	_expect(errors, DisplayResolution.default_resolution_index(FULL_HD, 1.0) == 1,
		"default_resolution_index должен fallback'иться на Full HD, когда 2K не помещается")
	_expect(errors, DisplayResolution.sanitize_resolution_index(-10) == 0,
		"sanitize_resolution_index должен клэмпить отрицательный индекс в 0")
	_expect(errors, DisplayResolution.sanitize_resolution_index(999) == 1,
		"sanitize_resolution_index должен клэмпить высокий индекс в Full HD")


func _write_scrum441_dump() -> void:
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum441")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var lines := PackedStringArray()
	lines.append("# SCRUM-441 HiDPI Resolution Evidence")
	lines.append("")
	lines.append("- mac_logical_usable: `%s`" % str(MAC_LOGICAL))
	lines.append("- retina_scale: `%.1f`" % RETINA_SCALE)
	lines.append("- physical_usable: `%s`" % str(DisplayResolution.physical_usable_size(MAC_LOGICAL, RETINA_SCALE)))
	lines.append("- full_hd_fits_retina: `%s`" % str(DisplayResolution.resolution_fits(FULL_HD, MAC_LOGICAL, RETINA_SCALE)))
	lines.append("- k2_fits_retina: `%s`" % str(DisplayResolution.resolution_fits(K2, MAC_LOGICAL, RETINA_SCALE)))
	lines.append("- allowed_resolutions: `%s`" % str(DisplayResolution.allowed_resolutions()))
	lines.append("- default_retina_index: `%d`" % DisplayResolution.default_resolution_index(MAC_LOGICAL, RETINA_SCALE))
	lines.append("- oversized_clamp: `%s`" % str(DisplayResolution.clamp_to_physical(Vector2i(4000, 3000), MAC_LOGICAL, RETINA_SCALE)))
	var file := FileAccess.open("%s/hidpi_resolution_evidence.md" % qa_dir, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
