extends SceneTree

## Combat Feel Rework (2026-07-12): оконный капчер визуальной приёмки.
## Кадр 1 — игрок (knight) с кругом-якорем под ногами + враги на engage-кольце
## (не прилипшие) + элитная телеграф-зона в фазе urgent-пульса.
## Запускать ОКОННО (headless dummy-рендерер ничего не рисует):
##   $GODOT --path . --script res://tools/capture_combat_feel_rework.gd

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const BITER_SCENE := preload("res://scenes/EnemyBiter.tscn")
const HazardVfxLib := preload("res://scripts/hazard_vfx.gd")
const OUTPUT := "res://docs/qa/combat_feel_rework/combat_feel_rework_windowed.png"


func _initialize() -> void:
	var host := Node2D.new()
	host.y_sort_enabled = true
	root.add_child(host)
	current_scene = host
	await process_frame

	var size := Vector2(root.size)
	var backdrop := Polygon2D.new()
	backdrop.polygon = PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
	backdrop.color = Color(0.10, 0.12, 0.09, 1.0)
	backdrop.z_index = -100
	host.add_child(backdrop)

	var center := size * 0.5

	# Игрок: камера отключена, чтобы кадр не уехал от координат host.
	var player := PLAYER_SCENE.instantiate()
	host.add_child(player)
	player.global_position = center
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.enabled = false
	if player.has_method("configure_character"):
		player.call("configure_character", "knight")
	await process_frame

	# Крест-маркер точки отсчёта (origin) — должен совпасть с кругом под ногами.
	var marker := Node2D.new()
	marker.z_index = 50
	marker.position = center
	host.add_child(marker)
	var line_h := Line2D.new()
	line_h.points = PackedVector2Array([Vector2(-14, 0), Vector2(14, 0)])
	line_h.width = 2.0
	line_h.default_color = Color(1.0, 0.3, 0.3, 0.9)
	marker.add_child(line_h)
	var line_v := Line2D.new()
	line_v.points = PackedVector2Array([Vector2(0, -14), Vector2(0, 14)])
	line_v.width = 2.0
	line_v.default_color = Color(1.0, 0.3, 0.3, 0.9)
	marker.add_child(line_v)

	# Враги вокруг на своих engage-дистанциях (движение выключено — постановка).
	var placements := [
		{"scene": ENEMY_SCENE, "angle": 0.35},
		{"scene": BITER_SCENE, "angle": 2.30},
		{"scene": ENEMY_SCENE, "angle": 4.10},
	]
	for entry in placements:
		var enemy := (entry["scene"] as PackedScene).instantiate() as CharacterBody2D
		host.add_child(enemy)
		enemy.set_physics_process(false)
		await process_frame
		var contact_range := float(enemy.get("contact_range"))
		var engage := contact_range * 0.8
		enemy.global_position = center + Vector2.from_angle(float(entry["angle"])) * engage
	await process_frame

	# Телеграф-зона в urgent-фазе (последние 25% windup).
	var hazard := Node2D.new()
	hazard.name = "ElitePoisonZone"
	hazard.global_position = center + Vector2(430, 40)
	host.add_child(hazard)
	HazardVfxLib.telegraph(hazard, 96.0, Color(0.55, 0.95, 0.30, 1.0), 1.0)

	var title := Label.new()
	title.text = "COMBAT FEEL REWORK — feet anchor + engage ring + telegraph"
	title.position = Vector2(size.x * 0.5 - 380, size.y * 0.06)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.70))
	host.add_child(title)

	# Даём телеграфу дойти до urgent-пульса (>75% windup) и пульснуть.
	await create_timer(0.85).timeout
	await process_frame
	await process_frame

	var dir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/qa/combat_feel_rework"))
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		push_error("Capture dir error: %s" % error_string(dir_error))
		quit(1)
		return
	var image := root.get_texture().get_image()
	if image == null:
		push_error("Capture failed: null image (headless run?)")
		quit(1)
		return
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT))
	if error != OK:
		push_error("Capture save failed: %s" % error_string(error))
		quit(1)
		return
	print("Combat feel rework capture saved: %s" % OUTPUT)
	quit(0)
