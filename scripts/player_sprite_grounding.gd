extends RefCounted
class_name PlayerSpriteGrounding

# Visual-only full-frame footline adapter. Gameplay/world position remains on
# the owning Player; this helper only keeps AnimatedSprite2D alpha bottoms on it.

var _frame_ground_lift_cache: Dictionary = {}


func bind(body: AnimatedSprite2D, changed_callback: Callable) -> void:
	if body == null or not changed_callback.is_valid():
		return
	if not body.frame_changed.is_connected(changed_callback):
		body.frame_changed.connect(changed_callback)
	if not body.animation_changed.is_connected(changed_callback):
		body.animation_changed.connect(changed_callback)


func apply(body: AnimatedSprite2D, use_live_frame: bool, fallback_lift: float) -> void:
	if body == null:
		return
	var lift := fallback_lift
	if use_live_frame:
		var frame_lift := texture_ground_lift(current_frame_texture(body), body.scale.abs().y)
		if frame_lift >= 0.0:
			lift = frame_lift
	body.position = Vector2(0.0, -lift)


func idle_ground_lift(body: AnimatedSprite2D) -> float:
	if body == null or body.sprite_frames == null:
		return -1.0
	var animation_name := "idle" if body.sprite_frames.has_animation("idle") else str(body.animation)
	if not body.sprite_frames.has_animation(animation_name) or body.sprite_frames.get_frame_count(animation_name) <= 0:
		return -1.0
	var texture := body.sprite_frames.get_frame_texture(animation_name, 0)
	return texture_ground_lift(texture, body.scale.abs().y)


func current_frame_texture(body: AnimatedSprite2D) -> Texture2D:
	if body == null or body.sprite_frames == null:
		return null
	var animation_name := str(body.animation)
	if not body.sprite_frames.has_animation(animation_name):
		return null
	var frame_count := body.sprite_frames.get_frame_count(animation_name)
	if frame_count <= 0:
		return null
	return body.sprite_frames.get_frame_texture(animation_name, clampi(body.frame, 0, frame_count - 1))


func texture_ground_lift(texture: Texture2D, visual_scale: float) -> float:
	if texture == null:
		return -1.0
	var cache_key := texture.resource_path
	if cache_key.is_empty():
		cache_key = "rid:%s" % str(texture.get_rid())
	var unscaled_lift := -1.0
	if _frame_ground_lift_cache.has(cache_key):
		unscaled_lift = float(_frame_ground_lift_cache[cache_key])
	else:
		var image := texture.get_image()
		if image == null or image.is_empty():
			return -1.0
		var used_rect := image.get_used_rect()
		if used_rect.size.x <= 0 or used_rect.size.y <= 0:
			return -1.0
		var visible_bottom := float(used_rect.position.y + used_rect.size.y)
		unscaled_lift = maxf(visible_bottom - float(image.get_height()) * 0.5, 0.0)
		_frame_ground_lift_cache[cache_key] = unscaled_lift
	return unscaled_lift * absf(visual_scale)
