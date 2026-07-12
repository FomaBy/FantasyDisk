extends SceneTree

# Combat Feel Rework (этап A): «точка отсчёта» персонажа — круг под ногами.
# Контракты:
#  (a) визуал игрока поднят per-class: Body.position.y ≈ -(foot_y - size.y/2) * 0.64
#      (foot_y из sliced_rig_manifest), у игрока есть GroundCircle (заливка + ободок),
#      орбита оружия/камера сдвинуты к торсу поднятого силуэта;
#  (b) у врага (Enemy.tscn) создаётся GroundCircle-тень под ногами;
#  (c) корень Main.tscn — Node2D с y_sort_enabled (актёры сортируются по Y);
#  (d) origin-математика не тронута: pickup_radius/коллизии прежние.

const SlicedRigManifest := preload("res://scripts/sliced_rig_manifest.gd")
const EXPECTED_PLAYER_VISUAL_SCALE := 0.64
const LIFT_TOLERANCE := 0.75


func _initialize() -> void:
	var errors: Array[String] = []
	await _test_player_feet_anchor_and_circle(errors)
	await _test_enemy_ground_circle(errors)
	_test_main_root_y_sort(errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Feet anchor / ground circle: %s" % error)
		quit(1)
		return
	print("Feet anchor ground circle test passed.")
	quit(0)


func _test_player_feet_anchor_and_circle(errors: Array[String]) -> void:
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)
	await process_frame

	for class_id in ["berserk", "ranger"]:
		player.configure_character(class_id)
		var entry: Dictionary = SlicedRigManifest.DATA.get(class_id, {})
		if entry.is_empty():
			errors.append("Manifest entry missing for %s (test precondition)." % class_id)
			continue
		var art_size: Vector2 = entry["size"]
		var expected_lift: float = (float(entry["foot_y"]) - art_size.y * 0.5) * EXPECTED_PLAYER_VISUAL_SCALE

		var body := player.get_node_or_null("VisualRoot/Body") as AnimatedSprite2D
		if body == null:
			errors.append("%s: VisualRoot/Body missing." % class_id)
			continue
		if absf(body.position.y + expected_lift) > LIFT_TOLERANCE:
			errors.append("%s: Body.position.y = %.2f, expected %.2f (feet on origin)." % [class_id, body.position.y, -expected_lift])
		if absf(body.position.x) > 0.01:
			errors.append("%s: Body.position.x must stay 0, got %.2f." % [class_id, body.position.x])
		var stored_lift := float(player.get("_feet_visual_lift"))
		if absf(stored_lift - expected_lift) > LIFT_TOLERANCE:
			errors.append("%s: _feet_visual_lift = %.2f, expected %.2f." % [class_id, stored_lift, expected_lift])

		# Подъём переживает по-кадровый ресет трансформов (VisualRoot обнуляется).
		player.call("_apply_sprite_transform")
		body = player.get_node_or_null("VisualRoot/Body") as AnimatedSprite2D
		if body != null and absf(body.position.y + expected_lift) > LIFT_TOLERANCE:
			errors.append("%s: feet lift wiped by _apply_sprite_transform (Body.y=%.2f)." % [class_id, body.position.y])

		# Круг-«точка отсчёта»: заливка + ободок, ниже тела по z.
		var circle := player.get_node_or_null("GroundCircle") as Node2D
		if circle == null:
			errors.append("%s: GroundCircle child missing on player." % class_id)
		else:
			if circle.z_index != -8:
				errors.append("%s: GroundCircle z_index = %d, expected -8." % [class_id, circle.z_index])
			var fill := circle.get_node_or_null("Fill") as Polygon2D
			var rim := circle.get_node_or_null("Rim") as Line2D
			if fill == null or fill.polygon.size() < 16:
				errors.append("%s: GroundCircle fill ellipse missing/degenerate." % class_id)
			if rim == null or rim.points.size() < 16 or not rim.closed:
				errors.append("%s: GroundCircle rim outline missing/degenerate." % class_id)

		# Орбита оружия: вертикальный bias уводит сокет к торсу (−8 − lift/2).
		var socket := player.get_node_or_null("VisualRoot/WeaponSocket") as Node2D
		if socket == null:
			errors.append("%s: WeaponSocket missing." % class_id)
		else:
			var bias := float(socket.get_meta("weapon_orbit_vertical_bias", 0.0))
			var expected_bias := -8.0 - expected_lift * 0.5
			if absf(bias - expected_bias) > LIFT_TOLERANCE:
				errors.append("%s: weapon orbit bias = %.2f, expected %.2f." % [class_id, bias, expected_bias])

		# Камера: силуэт по центру, ноги чуть ниже центра экрана.
		var camera := player.get_node_or_null("Camera2D") as Camera2D
		if camera == null:
			errors.append("%s: Camera2D missing." % class_id)
		elif absf(camera.offset.y + expected_lift * 0.45) > LIFT_TOLERANCE:
			errors.append("%s: camera offset.y = %.2f, expected %.2f." % [class_id, camera.offset.y, -expected_lift * 0.45])

	# (d) Origin-математика не тронута: подъём чисто визуальный, хёртбокс прежний.
	# pickup_radius сверяется НЕ с константой (мета-сейв легитимно даёт бонусы),
	# а на инвариантность к визуальным пересборкам feet-origin.
	var pickup_before := float(player.get("pickup_radius"))
	player.call("_apply_sprite_transform")
	player.call("_ensure_ground_circle")
	if absf(float(player.get("pickup_radius")) - pickup_before) > 0.001:
		errors.append("pickup_radius drifted after visual-only reconfiguration (%.2f -> %.2f)." % [pickup_before, float(player.get("pickup_radius"))])
	var player_shape := (player.get_node_or_null("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	if player_shape == null or absf(player_shape.radius - 8.9) > 0.001:
		errors.append("Player collision radius changed, expected 8.9.")

	player.queue_free()
	await process_frame


func _test_enemy_ground_circle(errors: Array[String]) -> void:
	var enemy := (load("res://scenes/Enemy.tscn") as PackedScene).instantiate() as Node2D
	root.add_child(enemy)
	await process_frame

	var circle := enemy.get_node_or_null("GroundCircle") as Node2D
	if circle == null:
		errors.append("Enemy: GroundCircle child missing.")
	else:
		if circle.z_index != -8:
			errors.append("Enemy: GroundCircle z_index = %d, expected -8." % circle.z_index)
		var fill := circle.get_node_or_null("Fill") as Polygon2D
		if fill == null or fill.polygon.size() < 16:
			errors.append("Enemy: GroundCircle fill ellipse missing/degenerate.")
		elif fill.color.a > 0.30:
			errors.append("Enemy: shadow alpha %.2f too strong (subtle shadow expected)." % fill.color.a)

	# Коллизия врага не тронута (визуальный этап).
	var enemy_shape := (enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	if enemy_shape == null or absf(enemy_shape.radius - 24.0) > 0.001:
		errors.append("Enemy collision radius changed, expected 24.0.")

	# Информационная строка для отчёта (auto-fit по живому full-frame визуалу).
	print("INFO: standard Enemy contact_range after live-visual fit = %.2f" % float(enemy.get("contact_range")))

	enemy.queue_free()
	await process_frame


func _test_main_root_y_sort(errors: Array[String]) -> void:
	var main := (load("res://scenes/Main.tscn") as PackedScene).instantiate() as Node2D
	if main == null:
		errors.append("Main.tscn root failed to instantiate as Node2D.")
		return
	if not main.y_sort_enabled:
		errors.append("Main root must have y_sort_enabled for actor Y-sorting.")
	main.free()
