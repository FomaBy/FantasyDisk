extends SceneTree

const MANIFEST_PATH := "res://docs/design/references/weapon_attack_animations/storm_longbow_pixellab_scrum912/manifest.json"
const SIGNATURE_PATH := "res://assets/sprites/effects/vfx_weapon_storm_longbow.png"
const SPRITEFRAMES_PATH := "res://assets/sprites/effects/storm_longbow/storm_longbow_release_spriteframes.tres"
const SCENE_PATH := "res://scenes/vfx/StormLongbowVolleyVfx.tscn"
const EXPECTED_OFFSETS := [-17.0, -8.5, 0.0, 8.5, 17.0]


func _initialize() -> void:
	await process_frame
	var manifest := _load_manifest()
	if manifest.is_empty():
		return
	if not _test_manifest(manifest):
		return
	if not _test_signature_alpha_and_five_trails(manifest):
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


func _test_signature_alpha_and_five_trails(manifest: Dictionary) -> bool:
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
	var probe := (manifest.get("geometry", {}) as Dictionary).get("source_cluster_probe", {}) as Dictionary
	var probe_x := int(probe.get("x", 96))
	var alpha_threshold := int(probe.get("alpha_threshold", 8))
	var max_gap := int(probe.get("max_gap", 2))
	var clusters := _vertical_alpha_clusters(image, probe_x, alpha_threshold, max_gap)
	if clusters != 5:
		return _fail("PixelLab signature must visibly separate five trails at x=%d; got %d." % [probe_x, clusters])
	return true


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
	effect.call("configure", Vector2(100.0, 100.0), Vector2.DOWN, 980.0)
	if effect.global_position.distance_to(Vector2(100.0, 126.0)) > 0.01:
		return _fail("Storm Longbow visual pivot must start 26px forward.")
	if not is_equal_approx(effect.rotation, PI * 0.5):
		return _fail("Storm Longbow visual scene must rotate with aim direction.")
	var expected_scale := (980.0 - 26.0) / (230.0 - 26.0)
	if not is_equal_approx(effect.scale.x, expected_scale) or not is_equal_approx(effect.scale.y, expected_scale):
		return _fail("Storm Longbow visual scene must preserve uniform cone scaling.")
	var sprite := effect.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null or sprite.animation != &"release" or not sprite.is_playing():
		return _fail("Storm Longbow visual scene must autoplay the release SpriteFrames.")
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
