extends SceneTree

const MANIFEST_PATH := "res://docs/design/references/weapon_attack_animations/storm_longbow_pixellab_scrum912/manifest.json"
const STATIC_REPORT_PATH := "res://docs/design/references/weapon_attack_animations/storm_longbow_pixellab_scrum912/static_alpha_readability_report.json"
const SIGNATURE_PATH := "res://assets/sprites/effects/vfx_weapon_storm_longbow.png"
const SPRITEFRAMES_PATH := "res://assets/sprites/effects/storm_longbow/storm_longbow_release_spriteframes.tres"
const SCENE_PATH := "res://scenes/vfx/StormLongbowVolleyVfx.tscn"
const EXPECTED_OFFSETS := [-17.0, -8.5, 0.0, 8.5, 17.0]
const EXPECTED_PROBE_X := [96, 128, 160, 176, 192]


func _initialize() -> void:
	await process_frame
	var manifest := _load_manifest()
	if manifest.is_empty():
		return
	if not _test_manifest(manifest):
		return
	if not _test_signature_alpha_and_corridor_centers(manifest):
		return
	if not _test_spriteframes(manifest):
		return
	if not _test_visual_scene():
		return
	print("SCRUM-912 Storm Longbow PixelLab VFX smoke passed.")
	quit()


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false


func _load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		_fail("Missing SCRUM-912 PixelLab manifest: %s" % MANIFEST_PATH)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:
		_fail("SCRUM-912 manifest must parse as a Dictionary.")
		return {}
	return parsed as Dictionary


func _test_manifest(manifest: Dictionary) -> bool:
	if str(manifest.get("issue", "")) != "SCRUM-912":
		return _fail("Manifest issue must be SCRUM-912.")
	if str(manifest.get("weapon_id", "")) != "storm_longbow":
		return _fail("Manifest weapon_id must be storm_longbow.")
	var pixel_lab := manifest.get("pixel_lab", {}) as Dictionary
	if str(pixel_lab.get("source_object_id", "")).is_empty():
		return _fail("Manifest must record the PixelLab source object ID.")
	if str(pixel_lab.get("animation_group_id", "")).is_empty():
		return _fail("Manifest must record the PixelLab animation group ID.")
	if not bool(pixel_lab.get("config_smoke_passed", false)):
		return _fail("Manifest must record PixelLab MCP config smoke PASS.")
	if not bool(manifest.get("pixel_lab_only", false)):
		return _fail("SCRUM-912 must record PixelLab-only production.")
	if bool(manifest.get("openai_images_used", true)):
		return _fail("SCRUM-912 must not use OpenAI Images or legacy generators.")
	if str(manifest.get("fix_issue", "")) != "SCRUM-1038":
		return _fail("Storm Longbow visual manifest must record SCRUM-1038 geometry correction.")

	var geometry := manifest.get("geometry", {}) as Dictionary
	if int(geometry.get("arrow_count", 0)) != 5:
		return _fail("Storm Longbow visual geometry must declare exactly five arrows.")
	if not is_equal_approx(float(geometry.get("cone_degrees", 0.0)), 34.0):
		return _fail("Storm Longbow visual cone must be 34 degrees.")
	if not is_equal_approx(float(geometry.get("beam_width_px", 0.0)), 30.0):
		return _fail("Storm Longbow visual corridor width must be 30px.")
	if not is_equal_approx(float(geometry.get("attack_range_px", 0.0)), 980.0):
		return _fail("Storm Longbow visual range must be 980px.")
	if not is_equal_approx(float(geometry.get("origin_forward_px", 0.0)), 26.0):
		return _fail("Storm Longbow visual origin must be 26px forward.")
	if int(geometry.get("pierce_count", 0)) != 4:
		return _fail("Storm Longbow visual manifest must record pierce cap 4.")
	var offsets := geometry.get("arrow_offsets_degrees", []) as Array
	if offsets.size() != EXPECTED_OFFSETS.size():
		return _fail("Storm Longbow manifest must contain five exact arrow offsets.")
	for index in range(EXPECTED_OFFSETS.size()):
		if not is_equal_approx(float(offsets[index]), float(EXPECTED_OFFSETS[index])):
			return _fail("Storm Longbow arrow offset mismatch at %d." % index)
	return true


func _test_signature_alpha_and_corridor_centers(manifest: Dictionary) -> bool:
	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(SIGNATURE_PATH))
	if error != OK:
		return _fail("Could not load Storm Longbow signature PNG.")
	if image.get_size() != Vector2i(256, 256):
		return _fail("Storm Longbow signature must stay 256x256.")
	var visible_bbox := _visible_bbox(image)
	if visible_bbox.size == Vector2i.ZERO:
		return _fail("Storm Longbow signature has no visible pixels.")
	var margins := [visible_bbox.position.x, visible_bbox.position.y,
		image.get_width() - visible_bbox.end.x, image.get_height() - visible_bbox.end.y]
	for margin in margins:
		if int(margin) < 12:
			return _fail("Storm Longbow signature needs >=12px transparent gutter; got %s." % str(margins))
	for point in [Vector2i.ZERO, Vector2i(255, 0), Vector2i(0, 255), Vector2i(255, 255)]:
		if image.get_pixelv(point).a > 0.001:
			return _fail("Storm Longbow signature corners must be transparent.")
	var geometry := manifest.get("geometry", {}) as Dictionary
	var oracle := geometry.get("image_corridor_oracle", {}) as Dictionary
	var x_slices := oracle.get("x_slices", []) as Array
	var expected_centers := oracle.get("expected_centers_degrees", []) as Array
	var source_origin_values := geometry.get("source_origin_px", []) as Array
	if x_slices.size() != EXPECTED_PROBE_X.size():
		return _fail("SCRUM-1038 image oracle must probe five representative x slices.")
	for index in range(EXPECTED_PROBE_X.size()):
		if int(x_slices[index]) != int(EXPECTED_PROBE_X[index]):
			return _fail("SCRUM-1038 image oracle probe mismatch at index %d." % index)
	if expected_centers.size() != EXPECTED_OFFSETS.size():
		return _fail("SCRUM-1038 image oracle must define all five authored centers.")
	if source_origin_values.size() != 2:
		return _fail("SCRUM-1038 image oracle requires the authored source pivot.")
	var source_origin := Vector2(float(source_origin_values[0]), float(source_origin_values[1]))
	if source_origin != Vector2(26.0, 128.0):
		return _fail("SCRUM-1038 image oracle pivot must remain (26,128).")
	var alpha_threshold := int(oracle.get("alpha_threshold", 8))
	var minimum_weight := float(oracle.get("minimum_opaque_weight_per_corridor", 100))
	var angle_tolerance := float(oracle.get("maximum_absolute_center_error_degrees", 1.5))
	if angle_tolerance > 1.5:
		return _fail("SCRUM-1038 centerline tolerance must not exceed 1.5 degrees.")
	var measured_maximum_error := 0.0
	for x_value in x_slices:
		var probe_x := int(x_value)
		var measurements := _measure_real_corridor_centers(
			image, probe_x, source_origin, expected_centers, alpha_threshold
		)
		if measurements.size() != EXPECTED_OFFSETS.size():
			return _fail("SCRUM-1038 could not measure five real corridors at x=%d." % probe_x)
		for index in range(measurements.size()):
			var measurement := measurements[index] as Dictionary
			var opaque_weight := float(measurement.get("opaque_weight", 0.0))
			var measured_angle := float(measurement.get("measured_angle_degrees", 999.0))
			var expected_angle := float(EXPECTED_OFFSETS[index])
			if opaque_weight < minimum_weight:
				return _fail(
					"SCRUM-1038 corridor %d lacks real opacity at x=%d: %.1f < %.1f."
					% [index, probe_x, opaque_weight, minimum_weight]
				)
			var angle_error := absf(measured_angle - expected_angle)
			measured_maximum_error = maxf(measured_maximum_error, angle_error)
			if angle_error > angle_tolerance:
				return _fail(
					"SCRUM-1038 real corridor %d at x=%d measures %.3f degrees; expected %.3f +/- %.3f."
					% [index, probe_x, measured_angle, expected_angle, angle_tolerance]
				)
	# Keep a distinctness guard at representative flight slices in addition to
	# center-angle measurement. This prevents one thick alpha wedge from satisfying
	# the five midpoint bands.
	for probe_x in [96, 128, 160, 176]:
		var clusters := _vertical_alpha_clusters(image, probe_x, alpha_threshold, 2)
		if clusters != 5:
			return _fail("PixelLab signature must visibly separate five trails at x=%d; got %d." % [probe_x, clusters])
	var recorded_error := float(oracle.get("measured_maximum_absolute_center_error_degrees", -1.0))
	if not is_equal_approx(snappedf(measured_maximum_error, 0.001), recorded_error):
		return _fail(
			"SCRUM-1038 manifest measured error %.3f does not match image-derived %.3f."
			% [recorded_error, measured_maximum_error]
		)
	if not FileAccess.file_exists(STATIC_REPORT_PATH):
		return _fail("Missing SCRUM-1038 static image measurement report.")
	var report = JSON.parse_string(FileAccess.get_file_as_string(STATIC_REPORT_PATH))
	if not report is Dictionary or str((report as Dictionary).get("issue", "")) != "SCRUM-1038":
		return _fail("SCRUM-1038 static image measurement report is invalid.")
	return true


func _measure_real_corridor_centers(
	image: Image,
	x: int,
	source_origin: Vector2,
	expected_centers: Array,
	alpha_threshold: int
) -> Array:
	if x <= int(source_origin.x):
		return []
	var target_y: Array[float] = []
	for expected_angle in expected_centers:
		target_y.append(
			source_origin.y + tan(deg_to_rad(float(expected_angle))) * (float(x) - source_origin.x)
		)
	var boundaries: Array[float] = [-INF]
	for index in range(target_y.size() - 1):
		boundaries.append((target_y[index] + target_y[index + 1]) * 0.5)
	boundaries.append(INF)
	var measurements: Array = []
	for corridor_index in range(target_y.size()):
		var opaque_weight := 0.0
		var weighted_y := 0.0
		for y in range(image.get_height()):
			if float(y) < boundaries[corridor_index] or float(y) >= boundaries[corridor_index + 1]:
				continue
			var alpha_byte := float(int(round(image.get_pixel(x, y).a * 255.0)))
			if alpha_byte <= float(alpha_threshold):
				continue
			opaque_weight += alpha_byte
			weighted_y += float(y) * alpha_byte
		if opaque_weight <= 0.0:
			return []
		var center_y := weighted_y / opaque_weight
		measurements.append({
			"opaque_weight": opaque_weight,
			"center_y": center_y,
			"measured_angle_degrees": rad_to_deg(
				atan2(center_y - source_origin.y, float(x) - source_origin.x)
			),
		})
	return measurements


func _test_spriteframes(manifest: Dictionary) -> bool:
	if not ResourceLoader.exists(SPRITEFRAMES_PATH):
		return _fail("Missing SCRUM-912 SpriteFrames resource.")
	var frames := load(SPRITEFRAMES_PATH) as SpriteFrames
	if frames == null or not frames.has_animation(&"release"):
		return _fail("SCRUM-912 SpriteFrames must expose release animation.")
	var animation := manifest.get("animation", {}) as Dictionary
	var expected_count := int(animation.get("frame_count", 0))
	var expected_fps := float(animation.get("fps", 0.0))
	if expected_count != 8 or frames.get_frame_count(&"release") != expected_count:
		return _fail("Storm Longbow release must have exactly 8 frames.")
	if not is_equal_approx(expected_fps, 16.0) or not is_equal_approx(frames.get_animation_speed(&"release"), expected_fps):
		return _fail("Storm Longbow release must play at 16 FPS.")
	if frames.get_animation_loop(&"release"):
		return _fail("Storm Longbow release animation must be one-shot.")
	for index in range(expected_count):
		var texture := frames.get_frame_texture(&"release", index)
		if texture == null or texture.get_size() != Vector2(256, 256):
			return _fail("Storm Longbow release frame %d must be a 256x256 texture." % index)
	return true


func _test_visual_scene() -> bool:
	if not ResourceLoader.exists(SCENE_PATH):
		return _fail("Missing isolated Storm Longbow visual scene.")
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		return _fail("Storm Longbow visual scene must load as PackedScene.")
	var effect := packed.instantiate() as Node2D
	if effect == null:
		return _fail("Storm Longbow visual scene root must be Node2D.")
	effect.set("auto_free_on_finish", false)
	root.add_child(effect)
	if not effect.is_in_group("player_weapon_effects"):
		return _fail("Storm Longbow visual scene must join player_weapon_effects.")
	var contract := effect.call("geometry_contract") as Dictionary
	if int(contract.get("beam_count", 0)) != 5 or int(contract.get("pierce_count", 0)) != 4:
		return _fail("Storm Longbow visual scene geometry metadata is incomplete.")
	if float(contract.get("bow_silhouette_scale", 1.0)) > 0.50:
		return _fail("Storm Longbow bow silhouette must be reduced by at least 2x.")
	effect.call("configure", Vector2(100.0, 100.0), Vector2.DOWN, 980.0)
	if effect.global_position.distance_to(Vector2(100.0, 126.0)) > 0.01:
		return _fail("Storm Longbow visual pivot must start 26px forward.")
	if not is_equal_approx(effect.rotation, PI * 0.5):
		return _fail("Storm Longbow visual scene must rotate with aim direction.")
	var expected_scale := (980.0 - 26.0) / (float(contract.get("display_endpoint_x_px", 0.0)) - 26.0)
	if not is_equal_approx(effect.scale.x, expected_scale) or not is_equal_approx(effect.scale.y, expected_scale):
		return _fail("Storm Longbow compacted visual must still span the live attack range.")
	var sprite := effect.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null or sprite.animation != &"release" or not sprite.is_playing():
		return _fail("Storm Longbow visual scene must autoplay the release SpriteFrames.")
	if not sprite.material is ShaderMaterial:
		return _fail("Storm Longbow must compact only the bow region through the runtime shader.")
	effect.queue_free()
	return true


func _visible_bbox(image: Image) -> Rect2i:
	var min_point := Vector2i(image.get_width(), image.get_height())
	var max_point := Vector2i(-1, -1)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if int(round(image.get_pixel(x, y).a * 255.0)) <= 8:
				continue
			min_point.x = mini(min_point.x, x)
			min_point.y = mini(min_point.y, y)
			max_point.x = maxi(max_point.x, x)
			max_point.y = maxi(max_point.y, y)
	if max_point.x < 0:
		return Rect2i()
	return Rect2i(min_point, max_point - min_point + Vector2i.ONE)


func _vertical_alpha_clusters(image: Image, x: int, alpha_threshold: int, max_gap: int) -> int:
	var clusters := 0
	var previous_y := -1000
	for y in range(image.get_height()):
		if int(round(image.get_pixel(x, y).a * 255.0)) <= alpha_threshold:
			continue
		if y > previous_y + max_gap + 1:
			clusters += 1
		previous_y = y
	return clusters
