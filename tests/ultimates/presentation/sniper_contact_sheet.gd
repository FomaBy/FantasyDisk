extends SceneTree

const OUTPUT := "res://docs/design/references/weapon_ultimates/sniper/sniper_ultimates_contact_sheet.png"
const TEXTURES := [
	"res://assets/sprites/effects/ultimates/sniper/sniper_deadeye_rifle_ultimate.png",
	"res://assets/sprites/effects/ultimates/sniper/sniper_spotter_scope_ultimate.png",
	"res://assets/sprites/effects/ultimates/sniper/sniper_shatter_rounds_ultimate.png"
]


func _initialize() -> void:
	var contact_sheet := Image.create(768, 256, false, Image.FORMAT_RGBA8)
	contact_sheet.fill(Color(0.025, 0.035, 0.06, 1.0))
	for index in TEXTURES.size():
		var texture := load(TEXTURES[index]) as Texture2D
		var source := texture.get_image() if texture != null else null
		if source == null or source.is_empty():
			push_error("Missing sniper contact-sheet source: %s" % TEXTURES[index])
			quit(1)
			return
		source.resize(224, 224, Image.INTERPOLATE_NEAREST)
		contact_sheet.blend_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), Vector2i(16 + index * 256, 16))
		if index < 2:
			for divider_y in range(8, 248):
				contact_sheet.set_pixel(255 + index * 256, divider_y, Color(0.22, 0.32, 0.48, 1.0))
	var result := contact_sheet.save_png(ProjectSettings.globalize_path(OUTPUT))
	if result != OK:
		push_error("Sniper contact-sheet export failed: %s" % error_string(result))
		quit(1)
		return
	print("Sniper ultimate contact sheet exported: %s" % OUTPUT)
	quit(0)
