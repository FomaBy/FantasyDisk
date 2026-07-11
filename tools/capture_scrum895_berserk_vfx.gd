extends SceneTree

const AXE_VFX := preload("res://scenes/vfx/BerserkAxeCleaveVfx.tscn")
const HAMMER_VFX := preload("res://scenes/vfx/BerserkHammerSlamVfx.tscn")
const OUTPUT := "res://docs/design/previews/scrum895_berserk_axe_hammer_runtime.png"


func _initialize() -> void:
	var host := Node2D.new(); root.add_child(host); current_scene = host
	await process_frame
	var size := Vector2(root.size)
	var backdrop := Polygon2D.new()
	backdrop.polygon = PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
	backdrop.color = Color(0.045, 0.035, 0.055, 1.0); backdrop.z_index = -20; host.add_child(backdrop)
	var axe_center := Vector2(size.x * 0.30, size.y * 0.52)
	var hammer_center := Vector2(size.x * 0.72, size.y * 0.52)
	for center in [axe_center, hammer_center]:
		var marker := Polygon2D.new(); marker.polygon = _circle_points(38.0); marker.color = Color(0.12, 0.10, 0.13, 0.95); marker.position = center; marker.z_index = 2; host.add_child(marker)

	var axe := AXE_VFX.instantiate() as BerserkAxeCleaveVfx; host.add_child(axe)
	axe.configure(axe_center, Vector2.RIGHT, 250.0, 180.0, 0.20, Color(1.0, 0.58, 0.24, 0.34))
	var hammer := HAMMER_VFX.instantiate() as BerserkHammerSlamVfx; host.add_child(hammer)
	hammer.configure(hammer_center, 150.0, Vector2.ONE, Color(0.82, 0.72, 1.0, 0.32))
	await create_timer(0.05).timeout
	(axe.get_node("WeaponPivot") as Node2D).rotation = 0.0
	(axe.get_node("WeaponPivot/AxeGhost") as AnimatedSprite2D).frame = 3
	(hammer.get_node("HammerGhost") as AnimatedSprite2D).frame = 5

	var title := Label.new(); title.text = "SCRUM-895  LIVE BERSERK WEAPON READABILITY"; title.position = Vector2(size.x * 0.5 - 310, size.y * 0.08); title.add_theme_font_size_override("font_size", 30); title.add_theme_color_override("font_color", Color(0.95, 0.84, 0.67)); host.add_child(title)
	var axe_label := Label.new(); axe_label.text = "AXE — actual weapon ghost across 180° / 250px cleave"; axe_label.position = axe_center + Vector2(-300, 330); axe_label.add_theme_font_size_override("font_size", 22); axe_label.add_theme_color_override("font_color", Color(1.0, 0.64, 0.34)); host.add_child(axe_label)
	var hammer_label := Label.new(); hammer_label.text = "HAMMER — authored impact frame 5 + exact 150px shock ring"; hammer_label.position = hammer_center + Vector2(-330, 330); hammer_label.add_theme_font_size_override("font_size", 22); hammer_label.add_theme_color_override("font_color", Color(0.84, 0.74, 1.0)); host.add_child(hammer_label)
	await process_frame; await process_frame
	var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT))
	if error != OK: push_error("SCRUM-895 capture failed: %s" % error_string(error)); quit(1); return
	print("SCRUM-895 runtime capture saved: %s" % OUTPUT); quit(0)


func _circle_points(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(32): points.append(Vector2.from_angle(TAU * float(index) / 32.0) * radius)
	return points
