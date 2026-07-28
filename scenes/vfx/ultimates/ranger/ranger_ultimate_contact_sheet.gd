extends SceneTree

## Headless contact-sheet renderer. It consumes the same formation function as
## the shipped scenes, so this is direct timeline evidence rather than a mockup.

const Pack := preload("res://scenes/vfx/ultimates/ranger/ranger_ultimate_presentation_pack.gd")

const OUTPUT_PATH := "res://docs/design/references/weapon_ultimates/ranger/ranger_ultimate_timelines_contact_sheet.png"
const PHASE_ORDER: Array[String] = ["windup", "release", "active", "recovery", "cancel"]
const SAMPLES_PER_PHASE := 3
## A non-zero value is only for the fail-closed regression probe. Normal
## rendering derives the cell from the actual opaque element bounds.
const CELL := Vector2i.ZERO
const MIN_CELL := Vector2i(232, 184)
const VIEW_SCALE := 0.46
const CONTENT_INSET := 1
const ALPHA_EPSILON := 0.01

const BACKGROUND := Color(0.045, 0.058, 0.076, 1.0)
const CELL_TINT := Color(0.075, 0.098, 0.122, 1.0)
const GRID_LINE := Color(0.18, 0.24, 0.29, 1.0)
const PHASE_SEPARATOR := Color(0.42, 0.72, 0.78, 1.0)
const ORIGIN_MARK := Color(0.48, 0.58, 0.64, 1.0)


func _initialize() -> void:
	var layout := layout_for_current_assets()
	var errors: Array[String] = []
	for error in layout.get("errors", []) as Array:
		errors.append(str(error))
	errors.append_array(layout_violations(layout))
	if not errors.is_empty():
		for error in errors:
			push_error("Ranger ultimate contact sheet: %s" % error)
		quit(1)
		return

	var cell: Vector2i = layout.get("cell", Vector2i.ZERO)
	var view_scale := float(layout.get("view_scale", 0.0))
	var columns := PHASE_ORDER.size() * SAMPLES_PER_PHASE
	var rows := Pack.WEAPON_IDS.size()
	var sheet := Image.create_empty(cell.x * columns, cell.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(BACKGROUND)
	for row in rows:
		var weapon_id := str(Pack.WEAPON_IDS[row])
		var texture: Texture2D = load(Pack.element_runtime_path(weapon_id))
		if texture == null:
			errors.append("missing runtime frame for %s" % weapon_id)
			continue
		var element := texture.get_image()
		element.convert(Image.FORMAT_RGBA8)
		var pivot: Dictionary = Pack.weapon_config(weapon_id).get("pivot", {})
		for column in columns:
			var phase_name := PHASE_ORDER[column / SAMPLES_PER_PHASE]
			var sample := column % SAMPLES_PER_PHASE
			var progress := float(sample) / float(maxi(SAMPLES_PER_PHASE - 1, 1))
			_draw_cell(sheet, Vector2i(column, row), cell, column % SAMPLES_PER_PHASE == 0)
			_draw_formation(sheet, Vector2i(column, row), cell, element, pivot, weapon_id, phase_name, sample, progress, view_scale, errors)
	if errors.is_empty():
		errors.append_array(_save(sheet, OUTPUT_PATH))
	if not errors.is_empty():
		for error in errors:
			push_error("Ranger ultimate contact sheet: %s" % error)
		quit(1)
		return
	print("Ranger ultimate contact sheet: %d columns x %d rows -> %s" % [columns, rows, OUTPUT_PATH])
	quit(0)


func _draw_cell(sheet: Image, cell_index: Vector2i, cell: Vector2i, phase_start: bool) -> void:
	var origin := cell_index * cell
	for y in cell.y:
		for x in cell.x:
			sheet.set_pixel(origin.x + x, origin.y + y, CELL_TINT)
	var edge := PHASE_SEPARATOR if phase_start else GRID_LINE
	for y in cell.y:
		sheet.set_pixel(origin.x, origin.y + y, edge)
	for x in cell.x:
		sheet.set_pixel(origin.x + x, origin.y, GRID_LINE)
	var center := origin + cell / 2
	for offset in range(-4, 5):
		sheet.set_pixel(center.x + offset, center.y, ORIGIN_MARK)
		sheet.set_pixel(center.x, center.y + offset, ORIGIN_MARK)


func _draw_formation(sheet: Image, cell_index: Vector2i, cell: Vector2i, element: Image, pivot: Dictionary, weapon_id: String, phase_name: String, sample: int, progress: float, view_scale: float, errors: Array[String]) -> void:
	var center := Vector2(cell_index * cell) + Vector2(cell) * 0.5
	var content_rect := content_rect_for(cell_index, cell)
	var element_index := 0
	for point in Pack.formation_points(weapon_id, phase_name, progress):
		var alpha := float(point.get("alpha", 0.0))
		var scale := float(point.get("scale", 0.0)) * view_scale
		if alpha <= ALPHA_EPSILON or scale <= ALPHA_EPSILON:
			element_index += 1
			continue
		var violation := _blit_element(sheet, element, center + (point.get("position", Vector2.ZERO) as Vector2) * view_scale, scale, alpha, float(point.get("rotation", 0.0)), pivot, content_rect)
		if not violation.is_empty():
			errors.append("%s/%s sample %d element %d: %s" % [weapon_id, phase_name, sample, element_index, violation])
			return
		element_index += 1


func _blit_element(sheet: Image, element: Image, center: Vector2, scale: float, alpha: float, rotation: float, pivot: Dictionary, content_rect: Rect2i) -> String:
	var size := Vector2(element.get_size())
	var anchor := Vector2(size.x * float(pivot.get("x", 0.5)), size.y * float(pivot.get("y", 0.5)))
	var reach := size.length() * scale * 0.5 + 2.0
	var cosine := cos(-rotation)
	var sine := sin(-rotation)
	for y in range(int(floor(center.y - reach)), int(ceil(center.y + reach)) + 1):
		if y < 0 or y >= sheet.get_height():
			continue
		for x in range(int(floor(center.x - reach)), int(ceil(center.x + reach)) + 1):
			if x < 0 or x >= sheet.get_width():
				continue
			var local := (Vector2(x, y) - center) / scale
			var source := Vector2(local.x * cosine - local.y * sine, local.x * sine + local.y * cosine) + anchor
			var sx := int(floor(source.x))
			var sy := int(floor(source.y))
			if sx < 0 or sy < 0 or sx >= element.get_width() or sy >= element.get_height():
				continue
			var pixel := element.get_pixel(sx, sy)
			if pixel.a <= 0.0:
				continue
			pixel.a *= alpha
			var violation := pixel_content_violation(content_rect, Vector2i(x, y))
			if not violation.is_empty():
				return violation
			_blend(sheet, x, y, pixel)
	return ""


static func content_rect_for(cell_index: Vector2i, cell: Vector2i) -> Rect2i:
	return Rect2i(cell_index * cell + Vector2i.ONE * CONTENT_INSET, cell - Vector2i.ONE * CONTENT_INSET * 2)


static func pixel_content_violation(content_rect: Rect2i, destination: Vector2i) -> String:
	if content_rect.has_point(destination):
		return ""
	return "drawn pixel %s escapes content rect %s" % [destination, content_rect]


static func layout_for_current_assets() -> Dictionary:
	var errors: Array[String] = []
	var entries: Array[Dictionary] = []
	var maximum_extent := Vector2.ZERO
	var sample_count := 0
	for weapon_id in Pack.WEAPON_IDS:
		var key := str(weapon_id)
		var texture: Texture2D = load(Pack.element_runtime_path(key))
		if texture == null:
			errors.append("missing runtime frame for %s" % key)
			continue
		var element := texture.get_image()
		element.convert(Image.FORMAT_RGBA8)
		var pivot: Dictionary = Pack.weapon_config(key).get("pivot", {})
		for phase_name in PHASE_ORDER:
			for sample in SAMPLES_PER_PHASE:
				sample_count += 1
				var progress := float(sample) / float(maxi(SAMPLES_PER_PHASE - 1, 1))
				var element_index := 0
				for raw_point in Pack.formation_points(key, phase_name, progress):
					var point := raw_point as Dictionary
					var bounds := element_bounds(element, pivot, point, VIEW_SCALE)
					if bounds.has_area():
						entries.append({
							"weapon_id": key,
							"phase_name": phase_name,
							"sample": sample,
							"element": element_index,
							"bounds": bounds,
						})
						maximum_extent.x = maxf(maximum_extent.x, maxf(absf(bounds.position.x), absf(bounds.end.x)))
						maximum_extent.y = maxf(maximum_extent.y, maxf(absf(bounds.position.y), absf(bounds.end.y)))
					element_index += 1
	var measured_cell := Vector2i(
		maxi(MIN_CELL.x, (ceili(maximum_extent.x) + CONTENT_INSET) * 2),
		maxi(MIN_CELL.y, (ceili(maximum_extent.y) + CONTENT_INSET) * 2)
	)
	return {
		"cell": CELL if CELL != Vector2i.ZERO else measured_cell,
		"entries": entries,
		"errors": errors,
		"sample_count": sample_count,
		"view_scale": VIEW_SCALE,
	}


static func element_bounds(element: Image, pivot: Dictionary, point: Dictionary, view_scale: float) -> Rect2:
	var used := element.get_used_rect()
	var scale := float(point.get("scale", 0.0)) * view_scale
	if not used.has_area() or float(point.get("alpha", 0.0)) <= ALPHA_EPSILON or scale <= ALPHA_EPSILON:
		return Rect2()
	var size := Vector2(element.get_size())
	var anchor := Vector2(size.x * float(pivot.get("x", 0.5)), size.y * float(pivot.get("y", 0.5)))
	var source_start := Vector2(used.position)
	var source_end := Vector2(used.end)
	var corners: Array[Vector2] = [
		source_start,
		Vector2(source_end.x, source_start.y),
		source_end,
		Vector2(source_start.x, source_end.y),
	]
	var center := (point.get("position", Vector2.ZERO) as Vector2) * view_scale
	var cosine := cos(float(point.get("rotation", 0.0)))
	var sine := sin(float(point.get("rotation", 0.0)))
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for corner in corners:
		var offset := corner - anchor
		var transformed := center + Vector2(
			(offset.x * cosine - offset.y * sine) * scale,
			(offset.x * sine + offset.y * cosine) * scale
		)
		minimum.x = minf(minimum.x, transformed.x)
		minimum.y = minf(minimum.y, transformed.y)
		maximum.x = maxf(maximum.x, transformed.x)
		maximum.y = maxf(maximum.y, transformed.y)
	return Rect2(minimum, maximum - minimum)


static func layout_violations(layout: Dictionary) -> Array[String]:
	var violations: Array[String] = []
	var cell: Vector2i = layout.get("cell", Vector2i.ZERO)
	if cell.x <= CONTENT_INSET * 2 or cell.y <= CONTENT_INSET * 2:
		return ["derived cell %s cannot contain the required %dpx inset" % [cell, CONTENT_INSET]]
	var safe_zone := Rect2(Vector2.ONE * CONTENT_INSET, Vector2(cell) - Vector2.ONE * CONTENT_INSET * 2.0)
	for raw_entry in layout.get("entries", []) as Array:
		var entry := raw_entry as Dictionary
		var relative_bounds: Rect2 = entry.get("bounds", Rect2())
		var bounds := Rect2(relative_bounds.position + Vector2(cell) * 0.5, relative_bounds.size)
		var left := maxf(safe_zone.position.x - bounds.position.x, 0.0)
		var top := maxf(safe_zone.position.y - bounds.position.y, 0.0)
		var right := maxf(bounds.end.x - safe_zone.end.x, 0.0)
		var bottom := maxf(bounds.end.y - safe_zone.end.y, 0.0)
		if maxf(maxf(left, top), maxf(right, bottom)) > 0.0:
			violations.append("%s/%s sample %d element %d exceeds the %dpx inset (left %.3f, top %.3f, right %.3f, bottom %.3f)" % [
				str(entry.get("weapon_id", "")),
				str(entry.get("phase_name", "")),
				int(entry.get("sample", -1)),
				int(entry.get("element", -1)),
				CONTENT_INSET,
				left,
				top,
				right,
				bottom,
			])
	return violations


func _blend(image: Image, x: int, y: int, color: Color) -> void:
	var dst := image.get_pixel(x, y)
	var out_a := color.a + dst.a * (1.0 - color.a)
	if out_a <= 0.0:
		return
	var weight := dst.a * (1.0 - color.a)
	image.set_pixel(x, y, Color((color.r * color.a + dst.r * weight) / out_a, (color.g * color.a + dst.g * weight) / out_a, (color.b * color.a + dst.b * weight) / out_a, out_a))


func _save(image: Image, res_path: String) -> Array[String]:
	var errors: Array[String] = []
	var absolute := ProjectSettings.globalize_path(res_path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		errors.append("cannot create directory for %s" % res_path)
		return errors
	if image.save_png(absolute) != OK:
		errors.append("cannot write %s" % res_path)
	return errors
