extends SceneTree

# Combat Feel Rework (этап A): «точка отсчёта» персонажа — круг под ногами.
# Контракты:
#  (a) все 17 live full-frame персонажей сажают фактическую нижнюю alpha-границу
#      КАЖДОГО idle/move/walk кадра на gameplay origin; legacy foot_y не может
#      увести PixelLab pack вверх/вниз. GroundCircle остаётся на origin, а
#      орбита оружия/камера сдвинуты к торсу canonical idle-силуэта;
#  (b) у врага (Enemy.tscn) создаётся GroundCircle-тень под ногами;
#  (c) корень Main.tscn — Node2D с y_sort_enabled (актёры сортируются по Y);
#  (d) origin-математика не тронута: pickup_radius/коллизии прежние.

const ProgressionData := preload("res://scripts/progression_data.gd")
const EXPECTED_PLAYER_VISUAL_SCALE := 0.64
const LIFT_TOLERANCE := 0.75
var _texture_bottom_cache: Dictionary = {}


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

	for class_id in ProgressionData.character_ids():
		player.configure_character(class_id)
		var body := player.get_node_or_null("VisualRoot/Body") as AnimatedSprite2D
		if body == null:
			errors.append("%s: VisualRoot/Body missing." % class_id)
			continue
		if not body.visible or body.sprite_frames == null:
			errors.append("%s: live full-frame Body/SpriteFrames missing." % class_id)
			continue
		if absf(body.scale.y - EXPECTED_PLAYER_VISUAL_SCALE) > 0.001:
			errors.append("%s: Body scale %.3f, expected %.3f." % [class_id, body.scale.y, EXPECTED_PLAYER_VISUAL_SCALE])
		var idle_texture := body.sprite_frames.get_frame_texture("idle", 0)
		var expected_lift := _texture_ground_lift(idle_texture, body.scale.y)
		if absf(body.position.y + expected_lift) > LIFT_TOLERANCE:
			errors.append("%s: Body.position.y = %.2f, expected %.2f (feet on origin)." % [class_id, body.position.y, -expected_lift])
		if absf(body.position.x) > 0.01:
			errors.append("%s: Body.position.x must stay 0, got %.2f." % [class_id, body.position.x])
		var stored_lift := float(player.get("_feet_visual_lift"))
		if absf(stored_lift - expected_lift) > LIFT_TOLERANCE:
			errors.append("%s: _feet_visual_lift = %.2f, expected %.2f." % [class_id, stored_lift, expected_lift])

		# FAN-1071 regression: force every live locomotion frame. The frame_changed
		# signal must synchronously re-ground the body; rendered alpha bottom stays
		# on local y=0 even for packs whose footline differs from legacy art.
		for animation_name in body.sprite_frames.get_animation_names():
			var name := str(animation_name)
			if name != "idle" and name != "move" and name != "walk" and not name.begins_with("idle_") and not name.begins_with("move_") and not name.begins_with("walk_"):
				continue
			body.animation = animation_name
			for frame_index in range(body.sprite_frames.get_frame_count(animation_name)):
				body.frame = frame_index
				var texture := body.sprite_frames.get_frame_texture(animation_name, frame_index)
				var frame_lift := _texture_ground_lift(texture, body.scale.y)
				var rendered_bottom := body.position.y + frame_lift
				if absf(rendered_bottom) > LIFT_TOLERANCE:
					errors.append("%s/%s[%d]: rendered footline y=%.2f, expected origin 0." % [class_id, name, frame_index, rendered_bottom])
					break
		# Restore canonical idle so camera/socket checks use the stable reference.
		body.animation = "idle"
		body.frame = 0

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


func _texture_ground_lift(texture: Texture2D, visual_scale: float) -> float:
	if texture == null:
		return 0.0
	var key := texture.resource_path
	if _texture_bottom_cache.has(key):
		return float(_texture_bottom_cache[key]) * visual_scale
	var image := texture.get_image()
	if image == null or image.is_empty():
		return 0.0
	var used_rect := image.get_used_rect()
	var unscaled_lift := maxf(float(used_rect.position.y + used_rect.size.y) - float(image.get_height()) * 0.5, 0.0)
	_texture_bottom_cache[key] = unscaled_lift
	return unscaled_lift * visual_scale


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
