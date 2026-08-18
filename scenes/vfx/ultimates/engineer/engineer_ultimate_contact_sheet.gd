extends SceneTree

## Contact-sheet evidence renderer for the engineer ultimate pack.
##
## It samples `EngineerUltimatePresentationPack.formation_points()` — the same
## function the shipped scene driver uses — so the published sheet is the motion
## the scene plays, not a hand-drawn impression of it. The sheet is composited
## with the Image API instead of a viewport so it renders identically in a
## headless gate run.
##
## Run:
##   python3 tools/godot_gate.py --headless --path . \
##     --script res://scenes/vfx/ultimates/engineer/engineer_ultimate_contact_sheet.gd

const Pack := preload("res://scenes/vfx/ultimates/engineer/engineer_ultimate_presentation_pack.gd")

const OUTPUT_PATH := "res://docs/design/references/weapon_ultimates/engineer/contact_sheet_engineer_ultimates.png"
const PHASE_ORDER: Array[String] = ["windup", "release", "active", "recovery", "cancel"]
const SAMPLES_PER_PHASE := 3
const CELL := Vector2i(232, 184)
## Chosen so the widest formation (the 132px mine lattice plus its element
## width) still fits inside one cell; cells are clipped as well, so a future
## formation cannot silently bleed into its neighbour and misread as motion.
const VIEW_SCALE := 0.50

const BACKGROUND := Color(0.055, 0.062, 0.078, 1.0)
const CELL_TINT := Color(0.085, 0.098, 0.120, 1.0)
const GRID_LINE := Color(0.20, 0.23, 0.27, 1.0)
const PHASE_SEPARATOR := Color(0.42, 0.62, 0.58, 1.0)
const ORIGIN_MARK := Color(0.35, 0.40, 0.45, 1.0)


func _initialize() -> void:
	var columns := PHASE_ORDER.size() * SAMPLES_PER_PHASE
	var rows := Pack.WEAPON_IDS.size()
	var sheet := Image.create_empty(CELL.x * columns, CELL.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(BACKGROUND)

	var errors: Array[String] = []
	for row in rows:
		var weapon_id := str(Pack.WEAPON_IDS[row])
		var frames: Array[Image] = []
		for path in Pack.element_frame_paths(weapon_id):
			var texture: Texture2D = load(path)
			if texture == null:
				errors.append("missing runtime frame %s" % path)
				break
			var frame := texture.get_image()
			frame.convert(Image.FORMAT_RGBA8)
			frames.append(frame)
		if frames.size() != Pack.element_frame_paths(weapon_id).size():
			continue
		var pivot: Dictionary = Pack.weapon_config(weapon_id).get("pivot", {})
		for column in columns:
			var phase_name := PHASE_ORDER[column / SAMPLES_PER_PHASE]
			var progress := float(column % SAMPLES_PER_PHASE) / float(maxi(SAMPLES_PER_PHASE - 1, 1))
			var element := frames[mini(Pack.frame_index(weapon_id, phase_name, progress), frames.size() - 1)]
			_draw_cell(sheet, Vector2i(column, row), column % SAMPLES_PER_PHASE == 0)
			_draw_formation(sheet, Vector2i(column, row), element, pivot, weapon_id, phase_name, progress)

	if errors.is_empty():
		errors.append_array(_save(sheet, OUTPUT_PATH))
	if not errors.is_empty():
		for error in errors:
			push_error("Engineer ultimate contact sheet: %s" % error)
		quit(1)
		return
	print("Engineer ultimate contact sheet: %d columns x %d rows -> %s" % [columns, rows, OUTPUT_PATH])
	print("Column order: %s, %d samples each. Row order: %s." % [
		", ".join(PHASE_ORDER),
		SAMPLES_PER_PHASE,
		", ".join(Pack.WEAPON_IDS),
	])
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
	# Ultimate origin marker, so travel between cells is measurable.
	var center := origin + CELL / 2
	for offset in range(-4, 5):
		sheet.set_pixel(center.x + offset, center.y, ORIGIN_MARK)
		sheet.set_pixel(center.x, center.y + offset, ORIGIN_MARK)


func _draw_formation(
	sheet: Image,
	cell: Vector2i,
	element: Image,
	pivot: Dictionary,
	weapon_id: String,
	phase_name: String,
	progress: float
) -> void:
	var bounds := Rect2i(cell * CELL, CELL)
	var center := Vector2(bounds.position) + Vector2(CELL) * 0.5
	for point in Pack.formation_points(weapon_id, phase_name, progress):
		var alpha := float(point.get("alpha", 0.0))
		var scale := float(point.get("scale", 0.0)) * VIEW_SCALE
		if alpha <= 0.01 or scale <= 0.01:
			continue
		var position: Vector2 = point.get("position", Vector2.ZERO)
		_blit_element(
			sheet,
			element,
			center + position * VIEW_SCALE,
			scale,
			alpha,
			float(point.get("rotation", 0.0)),
			pivot,
			bounds
		)


## Nearest-neighbour blit with rotation, scale, and alpha, so the sheet keeps
## the crisp pixel edges the runtime frames were forged with.
func _blit_element(
	sheet: Image,
	element: Image,
	center: Vector2,
	scale: float,
	alpha: float,
	rotation: float,
	pivot: Dictionary,
	bounds: Rect2i
) -> void:
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
			var source := Vector2(
				local.x * cosine - local.y * sine,
				local.x * sine + local.y * cosine
			) + anchor
			var sx := int(floor(source.x))
			var sy := int(floor(source.y))
			if sx < 0 or sy < 0 or sx >= element.get_width() or sy >= element.get_height():
				continue
			var pixel := element.get_pixel(sx, sy)
			if pixel.a <= 0.0:
				continue
			pixel.a *= alpha
			_blend(sheet, x, y, pixel)


func _blend(image: Image, x: int, y: int, color: Color) -> void:
	var dst := image.get_pixel(x, y)
	var out_a := color.a + dst.a * (1.0 - color.a)
	if out_a <= 0.0:
		return
	var weight := dst.a * (1.0 - color.a)
	image.set_pixel(x, y, Color(
		(color.r * color.a + dst.r * weight) / out_a,
		(color.g * color.a + dst.g * weight) / out_a,
		(color.b * color.a + dst.b * weight) / out_a,
		out_a
	))


func _save(image: Image, res_path: String) -> Array[String]:
	var errors: Array[String] = []
	var absolute := ProjectSettings.globalize_path(res_path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		errors.append("cannot create directory for %s" % res_path)
		return errors
	if image.save_png(absolute) != OK:
		errors.append("cannot write %s" % res_path)
	return errors
