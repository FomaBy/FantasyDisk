extends RefCounted

# SCRUM-958: immutable, cached AtlasTexture views for Codex entity artwork.
# Source PNGs stay canonical and untouched; only transparent outer canvas is
# trimmed. Every policy keeps the complete non-transparent silhouette inside a
# reserve and expands that reserve to the destination aspect ratio.

const POLICY_CONTAIN := "contain"
const POLICY_CHARACTER := "character_bottom_center"
const POLICY_MONSTER := "monster_center"
const POLICY_ARTIFACT := "artifact_center"

const _RESERVE_BY_POLICY := {
	POLICY_CHARACTER: 0.08,
	POLICY_MONSTER: 0.04,
	POLICY_ARTIFACT: 0.10,
}

static var _view_cache: Dictionary = {}
static var _alpha_rect_cache: Dictionary = {}


static func texture_view(texture: Texture2D, canonical_path: String, policy: String, target_size: Vector2) -> Texture2D:
	if texture == null:
		return null
	var resolved_path := canonical_path
	if resolved_path.is_empty():
		resolved_path = texture.resource_path
	var target_aspect := target_size.x / maxf(1.0, target_size.y)
	var identity := resolved_path
	if identity.is_empty():
		identity = "rid:%d" % texture.get_rid().get_id()
	var cache_key := "%s|%s|%.4f" % [identity, policy, target_aspect]
	if _view_cache.has(cache_key):
		return _view_cache[cache_key] as Texture2D

	var source_size := Vector2i(texture.get_width(), texture.get_height())
	if source_size.x <= 0 or source_size.y <= 0:
		return texture
	var source_rect := Rect2i(Vector2i.ZERO, source_size)
	var visible_rect := source_rect
	if _alpha_rect_cache.has(identity):
		visible_rect = _alpha_rect_cache[identity]
	else:
		var image := texture.get_image()
		if image != null and not image.is_empty():
			var used_rect := image.get_used_rect()
			if used_rect.size.x > 0 and used_rect.size.y > 0:
				visible_rect = used_rect
		_alpha_rect_cache[identity] = visible_rect

	var virtual_rect := source_rect
	if policy != POLICY_CONTAIN:
		var reserve_ratio := float(_RESERVE_BY_POLICY.get(policy, 0.08))
		virtual_rect = _padded_rect(visible_rect, reserve_ratio)
		virtual_rect = _expand_to_aspect(virtual_rect, target_aspect, policy == POLICY_CHARACTER)
	# AtlasTexture.region cannot address pixels outside the source atlas. Keep the
	# physical intersection in region and use margin as a virtual transparent
	# canvas. This preserves the promised reserve even for alpha touching an edge.
	var atlas_rect := _intersect_rect(virtual_rect, source_rect)
	var virtual_offset := atlas_rect.position - virtual_rect.position
	var virtual_extra := virtual_rect.size - atlas_rect.size

	var view := AtlasTexture.new()
	view.atlas = texture
	view.region = Rect2(atlas_rect)
	# AtlasTexture.margin.size is the additional transparent extent, not the
	# final output size; get_size() becomes region.size + margin.size.
	view.margin = Rect2(Vector2(virtual_offset), Vector2(virtual_extra))
	view.filter_clip = true
	view.set_meta("codex_source_path", resolved_path)
	view.set_meta("codex_image_policy", policy)
	view.set_meta("codex_source_size", source_size)
	view.set_meta("codex_visible_rect", visible_rect)
	view.set_meta("codex_view_region", virtual_rect)
	view.set_meta("codex_atlas_region", atlas_rect)
	view.set_meta("codex_margin", view.margin)
	view.set_meta("codex_target_aspect", target_aspect)
	view.set_meta("codex_anchor", "bottom_center" if policy == POLICY_CHARACTER else "center")
	_view_cache[cache_key] = view
	return view


static func clear_cache() -> void:
	_view_cache.clear()
	_alpha_rect_cache.clear()


static func cache_size() -> int:
	return _view_cache.size()


static func canonical_path(texture: Texture2D) -> String:
	if texture == null:
		return ""
	if texture.has_meta("codex_source_path"):
		return str(texture.get_meta("codex_source_path"))
	if texture is AtlasTexture:
		var atlas := (texture as AtlasTexture).atlas
		return atlas.resource_path if atlas != null else ""
	return texture.resource_path


static func _padded_rect(visible: Rect2i, reserve_ratio: float) -> Rect2i:
	var pad_x := maxi(2, int(ceilf(float(visible.size.x) * reserve_ratio)))
	var pad_y := maxi(2, int(ceilf(float(visible.size.y) * reserve_ratio)))
	var start := visible.position - Vector2i(pad_x, pad_y)
	var finish := visible.end + Vector2i(pad_x, pad_y)
	return Rect2i(start, finish - start)


static func _expand_to_aspect(rect: Rect2i, target_aspect: float, bottom_anchor: bool) -> Rect2i:
	var expanded := Rect2(rect)
	var current_aspect := expanded.size.x / maxf(1.0, expanded.size.y)
	if current_aspect < target_aspect:
		var new_width := expanded.size.y * target_aspect
		expanded.position.x -= (new_width - expanded.size.x) * 0.5
		expanded.size.x = new_width
	elif current_aspect > target_aspect:
		var new_height := expanded.size.x / maxf(0.001, target_aspect)
		if bottom_anchor:
			expanded.position.y = expanded.end.y - new_height
		else:
			expanded.position.y -= (new_height - expanded.size.y) * 0.5
		expanded.size.y = new_height

	var integer_start := Vector2i(floori(expanded.position.x), floori(expanded.position.y))
	var integer_end := Vector2i(ceili(expanded.end.x), ceili(expanded.end.y))
	return Rect2i(integer_start, integer_end - integer_start)


static func _intersect_rect(a: Rect2i, b: Rect2i) -> Rect2i:
	var start := Vector2i(maxi(a.position.x, b.position.x), maxi(a.position.y, b.position.y))
	var finish := Vector2i(mini(a.end.x, b.end.x), mini(a.end.y, b.end.y))
	return Rect2i(start, Vector2i(maxi(0, finish.x - start.x), maxi(0, finish.y - start.y)))
