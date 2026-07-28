extends SceneTree

## Headless evidence renderer. It samples the same motion function as the
## runtime scene, so the committed sheet is not a separate illustrative mockup.
const Pack := preload("res://scenes/vfx/ultimates/thief/thief_ultimate_presentation_pack.gd")

const OUTPUT_PATH := "res://docs/design/references/weapon_ultimates/thief/contact_sheet_thief_ultimates.png"
const PHASE_ORDER: Array[String] = ["windup", "release", "active", "recovery", "cancel"]
const SAMPLES_PER_PHASE := 3
const CELL := Vector2i(240, 184)
const VIEW_SCALE := 0.42
const BACKGROUND := Color(0.045, 0.05, 0.065, 1.0)
const CELL_TINT := Color(0.075, 0.085, 0.108, 1.0)
const GRID_LINE := Color(0.22, 0.24, 0.30, 1.0)
const PHASE_SEPARATOR := Color(0.68, 0.55, 0.22, 1.0)
const ORIGIN_MARK := Color(0.45, 0.48, 0.55, 1.0)


func _initialize() -> void:
	var columns := PHASE_ORDER.size() * SAMPLES_PER_PHASE
	var sheet := Image.create_empty(CELL.x * columns, CELL.y * Pack.WEAPON_IDS.size(), false, Image.FORMAT_RGBA8)
	sheet.fill(BACKGROUND)
	var errors: Array[String] = []
	for row in Pack.WEAPON_IDS.size():
		var weapon_id := str(Pack.WEAPON_IDS[row])
		var texture: Texture2D = load(Pack.asset_path(weapon_id))
		if texture == null:
			errors.append("missing accepted asset for %s" % weapon_id)
			continue
		var element := texture.get_image()
		element.convert(Image.FORMAT_RGBA8)
		var pivot: Dictionary = Pack.weapon_config(weapon_id).get("pivot", {})
		for column in columns:
			var phase_name := PHASE_ORDER[column / SAMPLES_PER_PHASE]
			var progress := float(column % SAMPLES_PER_PHASE) / float(SAMPLES_PER_PHASE - 1)
			_draw_cell(sheet, Vector2i(column, row), column % SAMPLES_PER_PHASE == 0)
			_draw_formation(sheet, Vector2i(column, row), element, pivot, weapon_id, phase_name, progress)
	if errors.is_empty():
		errors.append_array(_save(sheet, OUTPUT_PATH))
	if not errors.is_empty():
		for error in errors:
			push_error("Thief ultimate contact sheet: %s" % error)
		quit(1)
		return
	print("Thief ultimate contact sheet: %d columns x %d rows -> %s" % [columns, Pack.WEAPON_IDS.size(), OUTPUT_PATH])
	quit(0)


func _draw_cell(sheet: Image, cell: Vector2i, phase_start: bool) -> void:
	var origin := cell * CELL
	for y in CELL.y:
		for x in CELL.x:
			sheet.set_pixel(origin.x + x, origin.y + y, CELL_TINT)
	var edge := PHASE_SEPARATOR if phase_start else GRID_LINE
	for y in CELL.y:
		sheet.set_pixel(origin.x, origin.y + y, edge)
	for x in CELL.x:
		sheet.set_pixel(origin.x + x, origin.y, GRID_LINE)
	var center := origin + CELL / 2
	for offset in range(-4, 5):
		sheet.set_pixel(center.x + offset, center.y, ORIGIN_MARK)
		sheet.set_pixel(center.x, center.y + offset, ORIGIN_MARK)


func _draw_formation(sheet: Image, cell: Vector2i, element: Image, pivot: Dictionary, weapon_id: String, phase_name: String, progress: float) -> void:
	var bounds := Rect2i(cell * CELL, CELL)
	var center := Vector2(bounds.position) + Vector2(CELL) * 0.5
	for point in Pack.formation_points(weapon_id, phase_name, progress):
		var alpha := float(point.get("alpha", 0.0))
		var scale := float(point.get("scale", 0.0)) * VIEW_SCALE
		if alpha > 0.01 and scale > 0.01:
			_blit(sheet, element, center + (point.get("position", Vector2.ZERO) as Vector2) * VIEW_SCALE, scale, alpha, float(point.get("rotation", 0.0)), pivot, bounds)


func _blit(sheet: Image, element: Image, center: Vector2, scale: float, alpha: float, rotation: float, pivot: Dictionary, bounds: Rect2i) -> void:
	var size := Vector2(element.get_size())
	var anchor := Vector2(size.x * float(pivot.get("x", 0.5)), size.y * float(pivot.get("y", 0.5)))
	var reach := size.length() * scale * 0.5 + 2.0
	var cosine := cos(-rotation)
	var sine := sin(-rotation)
	for y in range(int(floor(center.y - reach)), int(ceil(center.y + reach)) + 1):
		if y < bounds.position.y or y >= bounds.end.y or y >= sheet.get_height():
			continue
		for x in range(int(floor(center.x - reach)), int(ceil(center.x + reach)) + 1):
			if x < bounds.position.x or x >= bounds.end.x or x >= sheet.get_width():
				continue
			var local := (Vector2(x, y) - center) / scale
			var source := Vector2(local.x * cosine - local.y * sine, local.x * sine + local.y * cosine) + anchor
			var sx := int(floor(source.x))
			var sy := int(floor(source.y))
			if sx < 0 or sy < 0 or sx >= element.get_width() or sy >= element.get_height():
				continue
			var pixel := element.get_pixel(sx, sy)
			if pixel.a > 0.0:
				pixel.a *= alpha
				_blend(sheet, x, y, pixel)


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
	elif image.save_png(absolute) != OK:
		errors.append("cannot write %s" % res_path)
	return errors
