extends SceneTree

## FAN-2981 live visual acceptance: the five unified basic attacks (axe,
## hammer, holy flail, hydraulic press, elemental orb ring) with the shared
## textured layer + weapon ghosts only — no Line2D/Polygon2D zone markup.
## Run windowed (dummy renderer draws nothing):
##   $GODOT --path . --script res://tools/capture_fan2981_attack_vfx_unification.gd

const AXE_VFX := preload("res://scenes/vfx/BerserkAxeCleaveVfx.tscn")
const HAMMER_VFX := preload("res://scenes/vfx/BerserkHammerSlamVfx.tscn")
const FLAIL_VFX := preload("res://scenes/vfx/HolyFlailSpiralVfx.tscn")
const PRESS_VFX := preload("res://scenes/vfx/RobotHydraulicPressCompressionVfx.tscn")

const WEAPON_IDS := ["axe", "hammer", "holy_flail", "robot_hydraulic_press", "elementalist_orb_ring"]
const OUTPUT_DIR := "res://docs/qa/fan2981_attack_vfx_unification"


func _initialize() -> void:
	for index in range(2):
		var width := 1280 if index == 0 else 1920
		var height := 720 if index == 0 else 1080
		DisplayServer.window_set_size(Vector2i(width, height))
		await process_frame
		await _capture(width, height)
	quit(0)


func _capture(width: int, height: int) -> void:
	var host := Node2D.new()
	host.y_sort_enabled = true
	root.add_child(host)
	current_scene = host
	await process_frame
	var size := Vector2(width, height)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.045, 0.035, 0.055, 1.0)
	backdrop.size = size
	backdrop.z_index = -20
	host.add_child(backdrop)
	var title := Label.new()
	title.text = "FAN-2981  UNIFIED BASIC ATTACKS — textured sprites + weapon ghosts, no zone markup"
	title.position = Vector2(24, 12)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.84, 0.67))
	host.add_child(title)

	var centers := {
		"axe": size * Vector2(0.22, 0.42),
		"hammer": size * Vector2(0.62, 0.40),
		"holy_flail": size * Vector2(0.87, 0.42),
		"robot_hydraulic_press": size * Vector2(0.30, 0.80),
		"elementalist_orb_ring": size * Vector2(0.70, 0.82),
	}

	# Berserk axe: shared slash layer + PixelLab cleave ghost (no sector markup).
	var axe_anchor := Node2D.new()
	axe_anchor.position = centers["axe"]
	host.add_child(axe_anchor)
	AttackVfx.slash(axe_anchor, Vector2.RIGHT, 250.0, Color(1.0, 0.58, 0.24, 0.34), 0.0, 1.55, 180.0)
	var axe := AXE_VFX.instantiate() as BerserkAxeCleaveVfx
	host.add_child(axe)
	axe.configure(centers["axe"], Vector2.RIGHT, 250.0, 180.0, 0.20, Color(1.0, 0.58, 0.24, 0.34))

	# Berserk hammer: restored shared textured slam + impact-frame ghost.
	AttackVfx.hammer_slam(host, centers["hammer"], 150.0, Color(0.82, 0.72, 1.0, 0.32))
	var hammer := HAMMER_VFX.instantiate() as BerserkHammerSlamVfx
	host.add_child(hammer)
	hammer.configure(centers["hammer"], 150.0, Vector2.ONE, Color(0.82, 0.72, 1.0, 0.32))

	# Knight holy flail: spiral carried by the flail ghost alone.
	var flail := FLAIL_VFX.instantiate() as HolyFlailSpiralVfx
	host.add_child(flail)
	flail.auto_free_on_finish = false
	for step_index in range(4):
		flail.apply_step(
			centers["holy_flail"], 0.6 + TAU * float(step_index + 1) / 7.0,
			lerpf(52.0, 235.0, float(step_index + 1) / 7.0), 235.0, step_index,
			Color(1.0, 0.84, 0.32, 0.34)
		)

	# Robot hydraulic press: authored compression frames over the corridor.
	var press := PRESS_VFX.instantiate() as RobotHydraulicPressCompressionVfx
	host.add_child(press)
	press.auto_free_on_finish = false
	press.configure(centers["robot_hydraulic_press"] + Vector2(-215, 0), centers["robot_hydraulic_press"] + Vector2(215, 0), 300.0, 120.0, 0.20, Color(0.94, 0.72, 0.36, 0.42))

	# Elementalist orb ring: textured corner runes carry the square (no edges).
	_draw_rune_square(host, centers["elementalist_orb_ring"], 96.0)

	for weapon_id in WEAPON_IDS:
		var signature := _signature_icon(weapon_id)
		if signature == null:
			continue
		signature.position = centers[weapon_id] + Vector2(0, -170)
		host.add_child(signature)
		var label := Label.new()
		label.text = weapon_id
		label.position = centers[weapon_id] + Vector2(-90, 148)
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
		host.add_child(label)

	# Freeze every authored frame mid-attack for a stable comparison shot.
	(axe.get_node("WeaponPivot") as Node2D).rotation = 0.0
	(axe.get_node("WeaponPivot/AxeGhost") as AnimatedSprite2D).frame = 3
	(hammer.get_node("HammerGhost") as AnimatedSprite2D).frame = 5
	(press.get_node("AnimatedSprite2D") as AnimatedSprite2D).frame = 5

	await process_frame
	await process_frame
	var path := "%s/fan2981_unified_attacks_%dp.png" % [OUTPUT_DIR, height]
	var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("FAN-2981 capture failed: %s" % error_string(error))
		quit(1)
		return
	print("FAN-2981 runtime capture saved: %s" % path)


func _signature_icon(weapon_id: String) -> Sprite2D:
	var texture_path := "res://assets/sprites/effects/vfx_weapon_%s.png" % weapon_id
	if not ResourceLoader.exists(texture_path):
		return null
	var sprite := Sprite2D.new()
	sprite.texture = load(texture_path)
	sprite.scale = Vector2.ONE * 0.8
	return sprite


func _draw_rune_square(host: Node2D, center: Vector2, half_size: float) -> void:
	var field := Node2D.new()
	field.position = center
	field.z_index = 3
	host.add_child(field)
	var colors := [Color(1.0, 0.42, 0.30), Color(0.40, 0.75, 1.0), Color(1.0, 0.86, 0.34), Color(0.55, 1.0, 0.62)]
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for index in range(4):
		var rune := _signature_icon("elementalist_orb_ring")
		if rune == null:
			return
		rune.name = "ElementRune%d" % index
		rune.modulate = colors[index]
		rune.scale = Vector2.ONE * 0.16
		rune.position = corners[index] * half_size
		field.add_child(rune)
