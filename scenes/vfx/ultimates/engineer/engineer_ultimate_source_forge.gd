extends SceneTree

## Deterministic forge for the engineer ultimate formation elements.
##
## PixelLab is the repository pipeline for hand-drawn source art, but this pack
## needs three interchangeable formation elements whose silhouettes are the
## acceptance criterion, so they are generated from committed geometry instead:
## the same script always produces the same bytes, and a reviewer can re-run it
## to reproduce every frame. The accepted 256x256 weapon bursts under
## `assets/sprites/effects/vfx_weapon_engineer_*.png` stay the VFX channel and
## are not modified.
##
## Run:
##   python3 tools/godot_gate.py --headless --path . \
##     --script res://scenes/vfx/ultimates/engineer/engineer_ultimate_source_forge.gd

const Pack := preload("res://scenes/vfx/ultimates/engineer/engineer_ultimate_presentation_pack.gd")

const CANVAS := 128
const RUNTIME_PADDING := 2

const PALETTES := {
	"engineer_sentry_pylon": {
		"dark": Color("2f5f58"),
		"body": Color("79b3a8"),
		"light": Color("cfe9e1"),
		"accent": Color("d9b070"),
		"lens": Color("eafff9"),
	},
	"engineer_repair_microdrone": {
		"dark": Color("4a3417"),
		"body": Color("b8892f"),
		"light": Color("e8c98a"),
		"accent": Color("e05fd0"),
		"lens": Color("fff0ff"),
	},
	"engineer_smart_mine": {
		"dark": Color("4a3122"),
		"body": Color("a86b41"),
		"light": Color("d9a679"),
		"accent": Color("4fd8d2"),
		"lens": Color("eafffe"),
	},
}


func _initialize() -> void:
	var errors: Array[String] = []
	for weapon_id in Pack.WEAPON_IDS:
		var element := str(Pack.weapon_config(weapon_id).get("element", ""))
		var image := _draw_element(element)
		if image == null:
			errors.append("no geometry for element %s" % element)
			continue
		_outline(image, Color(0.06, 0.07, 0.09, 1.0), 0.55)
		var source_path := Pack.element_source_path(weapon_id)
		var runtime_path := Pack.element_runtime_path(weapon_id)
		errors.append_array(_save(image, source_path))
		errors.append_array(_save(_trim(image, RUNTIME_PADDING), runtime_path))
		print("forged %s -> %s, %s" % [element, source_path, runtime_path])

	if not errors.is_empty():
		for error in errors:
			push_error("Engineer ultimate source forge: %s" % error)
		quit(1)
		return
	print("Engineer ultimate source forge wrote %d element pairs." % Pack.WEAPON_IDS.size())
	quit(0)


func _draw_element(element: String) -> Image:
	var palette = PALETTES.get(element, {})
	if not palette is Dictionary or (palette as Dictionary).is_empty():
		return null
	var image := Image.create_empty(CANVAS, CANVAS, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	match element:
		"engineer_sentry_pylon":
			_draw_sentry_pylon(image, palette)
		"engineer_repair_microdrone":
			_draw_repair_microdrone(image, palette)
		"engineer_smart_mine":
			_draw_smart_mine(image, palette)
		_:
			return null
	return image


## Tall narrow pylon: hexagonal turret head, tapered column, tripod feet.
func _draw_sentry_pylon(image: Image, palette: Dictionary) -> void:
	var cx := 64.0
	var dark: Color = palette["dark"]
	var body: Color = palette["body"]
	var light: Color = palette["light"]

	for side in [-1.0, 1.0]:
		_taper(image, cx + side * 10.5, 96, 116, 7.0, 5.0, body)
		_rect(image, int(cx + side * 17.0) - 5, 113, 11, 5, dark)
	_taper(image, cx, 44, 100, 24.0, 30.0, body)
	_taper(image, cx - 7.0, 46, 98, 5.0, 6.0, light)
	for seam_y in [58, 72, 86]:
		_rect(image, 50, seam_y, 28, 2, dark)
	_polygon(image, _hexagon(Vector2(cx, 36.0), 21.0), dark)
	_polygon(image, _hexagon(Vector2(cx, 34.0), 16.0), body)
	_ellipse(image, cx, 35.0, 8.0, 7.0, palette["lens"])
	_ellipse(image, cx - 1.0, 34.0, 4.0, 3.0, Color(1, 1, 1, 0.85))
	_rect(image, 61, 12, 6, 22, body)
	_rect(image, 59, 10, 10, 5, dark)
	for bolt in [Vector2(52, 52), Vector2(76, 52), Vector2(52, 92), Vector2(76, 92)]:
		_ellipse(image, bolt.x, bolt.y, 3.0, 3.0, palette["accent"])


## Wide flat microdrone: long rotor bar, small orb body, downward stinger.
func _draw_repair_microdrone(image: Image, palette: Dictionary) -> void:
	var cx := 64.0
	var dark: Color = palette["dark"]
	var body: Color = palette["body"]
	var light: Color = palette["light"]

	_rect(image, 16, 60, 96, 5, dark)
	_rect(image, 16, 60, 96, 2, light)
	for hub in [26.0, 102.0]:
		_ellipse(image, hub, 62.0, 16.0, 4.0, Color(light.r, light.g, light.b, 0.5))
		_ellipse(image, hub, 62.0, 4.0, 3.0, body)
	_ellipse(image, cx, 68.0, 17.0, 15.0, body)
	_ellipse(image, cx, 73.0, 15.0, 9.0, Color(dark.r, dark.g, dark.b, 0.45))
	_ellipse(image, cx - 5.0, 63.0, 8.0, 5.0, Color(light.r, light.g, light.b, 0.65))
	_ellipse(image, cx, 68.0, 7.0, 7.0, palette["accent"])
	_ellipse(image, cx, 68.0, 3.0, 3.0, palette["lens"])
	_taper(image, cx, 82, 96, 8.0, 2.0, dark)
	_rect(image, 63, 46, 2, 12, dark)
	_ellipse(image, cx, 45.0, 2.5, 2.5, palette["accent"])
	for clamp_x in [40, 81]:
		_rect(image, clamp_x, 64, 7, 5, body)


## Squat prong-topped dome on a wide base plate.
func _draw_smart_mine(image: Image, palette: Dictionary) -> void:
	var cx := 64.0
	var dark: Color = palette["dark"]
	var body: Color = palette["body"]
	var light: Color = palette["light"]

	_rect(image, 26, 96, 76, 8, dark)
	_rect(image, 26, 96, 76, 2, light)
	_ellipse(image, cx, 96.0, 36.0, 30.0, body, -9999, 95)
	_ellipse(image, cx, 96.0, 36.0, 30.0, Color(dark.r, dark.g, dark.b, 0.3), 85, 95)
	_ellipse(image, cx - 10.0, 80.0, 12.0, 8.0, Color(light.r, light.g, light.b, 0.55))
	_rect(image, 30, 88, 68, 3, dark)
	var prongs: Array[Vector2] = [Vector2(46, 78), Vector2(64, 74), Vector2(82, 78)]
	for prong in prongs:
		var tip_y: float = prong.y - (24.0 if is_equal_approx(prong.x, 64.0) else 20.0)
		_taper(image, prong.x, int(tip_y), int(prong.y), 3.0, 7.0, body)
		_ellipse(image, prong.x, tip_y, 3.0, 3.0, palette["accent"])
	_ellipse(image, cx, 88.0, 13.0, 9.0, palette["accent"])
	_ellipse(image, cx, 88.0, 6.0, 4.0, palette["lens"])
	for rivet in [Vector2(38, 90), Vector2(90, 90), Vector2(64, 70)]:
		_ellipse(image, rivet.x, rivet.y, 2.0, 2.0, dark)


# --- drawing primitives -------------------------------------------------------

func _blend(image: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height() or color.a <= 0.0:
		return
	var dst := image.get_pixel(x, y)
	var out_a := color.a + dst.a * (1.0 - color.a)
	if out_a <= 0.0:
		image.set_pixel(x, y, Color(0, 0, 0, 0))
		return
	var weight := dst.a * (1.0 - color.a)
	image.set_pixel(x, y, Color(
		(color.r * color.a + dst.r * weight) / out_a,
		(color.g * color.a + dst.g * weight) / out_a,
		(color.b * color.a + dst.b * weight) / out_a,
		out_a
	))


func _rect(image: Image, x: int, y: int, width: int, height: int, color: Color) -> void:
	for row in range(y, y + height):
		for column in range(x, x + width):
			_blend(image, column, row, color)


func _ellipse(
	image: Image,
	cx: float,
	cy: float,
	rx: float,
	ry: float,
	color: Color,
	clip_from := -9999,
	clip_to := 9999
) -> void:
	for row in range(int(floor(cy - ry)), int(ceil(cy + ry)) + 1):
		if row < clip_from or row > clip_to:
			continue
		for column in range(int(floor(cx - rx)), int(ceil(cx + rx)) + 1):
			var nx := (float(column) - cx) / maxf(rx, 0.001)
			var ny := (float(row) - cy) / maxf(ry, 0.001)
			if nx * nx + ny * ny <= 1.0:
				_blend(image, column, row, color)


## Vertical trapezoid: width interpolates linearly from `y0` to `y1`.
func _taper(image: Image, cx: float, y0: int, y1: int, width0: float, width1: float, color: Color) -> void:
	for row in range(y0, y1 + 1):
		var t := 0.0 if y1 == y0 else float(row - y0) / float(y1 - y0)
		var half := lerpf(width0, width1, t) * 0.5
		for column in range(int(round(cx - half)), int(round(cx + half))):
			_blend(image, column, row, color)


func _polygon(image: Image, points: PackedVector2Array, color: Color) -> void:
	if points.size() < 3:
		return
	var min_y := points[0].y
	var max_y := points[0].y
	for point in points:
		min_y = minf(min_y, point.y)
		max_y = maxf(max_y, point.y)
	for row in range(int(floor(min_y)), int(ceil(max_y)) + 1):
		var crossings: Array[float] = []
		for index in points.size():
			var a := points[index]
			var b := points[(index + 1) % points.size()]
			if (a.y <= float(row) and b.y > float(row)) or (b.y <= float(row) and a.y > float(row)):
				var t := (float(row) - a.y) / (b.y - a.y)
				crossings.append(a.x + t * (b.x - a.x))
		crossings.sort()
		var pair := 0
		while pair + 1 < crossings.size():
			for column in range(int(round(crossings[pair])), int(round(crossings[pair + 1])) + 1):
				_blend(image, column, row, color)
			pair += 2


func _hexagon(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in 6:
		var angle := TAU * float(index) / 6.0 - PI * 0.5
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


## Restrained selective outline: darken opaque pixels that touch transparency
## instead of growing the silhouette outwards.
func _outline(image: Image, color: Color, strength: float) -> void:
	var offsets: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var edges: Array[Vector2i] = []
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a < 0.5:
				continue
			for offset in offsets:
				var nx := x + offset.x
				var ny := y + offset.y
				var outside := nx < 0 or ny < 0 or nx >= image.get_width() or ny >= image.get_height()
				if outside or image.get_pixel(nx, ny).a < 0.5:
					edges.append(Vector2i(x, y))
					break
	for edge in edges:
		var pixel := image.get_pixel(edge.x, edge.y)
		image.set_pixel(edge.x, edge.y, Color(
			lerpf(pixel.r, color.r, strength),
			lerpf(pixel.g, color.g, strength),
			lerpf(pixel.b, color.b, strength),
			pixel.a
		))


## Alpha-trim the padded source frame into the tight runtime frame. No rescale,
## so the runtime frame keeps every source pixel.
func _trim(image: Image, padding: int) -> Image:
	var used := image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return image
	var box := used.grow(padding).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var trimmed := Image.create_empty(box.size.x, box.size.y, false, Image.FORMAT_RGBA8)
	trimmed.fill(Color(0, 0, 0, 0))
	trimmed.blit_rect(image, box, Vector2i.ZERO)
	return trimmed


func _save(image: Image, res_path: String) -> Array[String]:
	var errors: Array[String] = []
	var absolute := ProjectSettings.globalize_path(res_path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		errors.append("cannot create directory for %s" % res_path)
		return errors
	if image.save_png(absolute) != OK:
		errors.append("cannot write %s" % res_path)
	return errors
