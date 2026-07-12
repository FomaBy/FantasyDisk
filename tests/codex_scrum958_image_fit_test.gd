extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const CodexData := preload("res://scripts/codex_data.gd")
const CodexImageFit := preload("res://scripts/ui/codex_image_fit.gd")
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const LIST_TARGET := Vector2(88.0, 96.0)
const DETAIL_TARGET := Vector2(236.0, 248.0)
const SCRUM957_IDS := ["red_whetstone", "field_kit", "magnetic_buckle", "fast_boots", "hawk_lens"]
const RESERVE_BY_POLICY := {
	CodexImageFit.POLICY_CHARACTER: 0.08,
	CodexImageFit.POLICY_MONSTER: 0.04,
	CodexImageFit.POLICY_ARTIFACT: 0.10,
}

var errors := PackedStringArray()
var report := PackedStringArray(["# SCRUM-958 Codex image-fit matrix", ""])


func _initialize() -> void:
	CodexImageFit.clear_cache()
	for viewport_size in VIEWPORT_SIZES:
		await _check_viewport(viewport_size)
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum958")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var report_file := FileAccess.open("%s/codex_image_fit_matrix.md" % qa_dir, FileAccess.WRITE)
	if report_file != null:
		report.append("")
		report.append("Cached immutable views: %d" % CodexImageFit.cache_size())
		report_file.store_string("\n".join(report))
		report_file.close()
	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("SCRUM-958 Codex image-fit test passed (%d cached views)." % CodexImageFit.cache_size())
	quit(0)


func _check_viewport(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await process_frame
	main.ui._show_codex_screen()
	for _frame_index in range(5):
		await process_frame

	var context := "Codex %s" % str(viewport_size)
	report.append("## %s" % context)
	var scrum957_seen := {}
	for section_spec in _section_specs():
		var section_id := str(section_spec["id"])
		var expected: Array = section_spec["entries"]
		var tab := main.find_child("CodexTab_%s" % section_id, true, false) as Button
		if tab == null:
			errors.append("%s: missing %s tab." % [context, section_id])
			continue
		tab.pressed.emit()
		await process_frame
		var list := main.find_child("CodexSectionList_%s" % section_id, true, false) as VBoxContainer
		if list == null:
			errors.append("%s: missing %s list." % [context, section_id])
			continue
		var cards := list.get_children()
		if cards.size() != expected.size():
			errors.append("%s %s: %d rows != %d canonical entries." % [context, section_id, cards.size(), expected.size()])
		var checked := mini(cards.size(), expected.size())
		for entry_index in range(checked):
			var card := cards[entry_index] as Button
			var spec := expected[entry_index] as Dictionary
			var entry_context := "%s %s[%d] %s" % [context, section_id, entry_index, str(spec["id"])]
			_check_card(card, spec, entry_context)
			if SCRUM957_IDS.has(str(spec["id"])):
				scrum957_seen[str(spec["id"])] = true
			if card != null:
				card.pressed.emit()
				await process_frame
				var detail := main.find_child("CodexDetailPortraitTexture", true, false) as TextureRect
				_check_texture(detail, spec, DETAIL_TARGET, "%s detail" % entry_context)
		report.append("- %s: %d list and %d detail images checked" % [section_id, checked, checked])

	for artifact_id in SCRUM957_IDS:
		if not scrum957_seen.has(artifact_id):
			errors.append("%s: requested SCRUM-957 artifact %s was not rendered in Codex." % [context, artifact_id])
	if DisplayServer.get_name() != "headless":
		for evidence_section in ["characters", "monsters", "artifacts"]:
			await _save_clean_section_screenshot(main, viewport, viewport_size, evidence_section)
		for _frame_index in range(3):
			await process_frame
		var image := viewport.get_texture().get_image()
		if image != null:
			var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum958")
			DirAccess.make_dir_recursive_absolute(qa_dir)
			image.save_png("%s/codex_%dx%d.png" % [qa_dir, viewport_size.x, viewport_size.y])
	viewport.queue_free()
	await process_frame


func _save_clean_section_screenshot(main: Node, viewport: SubViewport, viewport_size: Vector2i, section_id: String) -> void:
	# The all-entry contract intentionally replaces hundreds of dossier nodes.
	# Reopen a clean screen before each screenshot so the compatibility renderer
	# never captures an intermediate buffer from that stress pass.
	main.ui._show_codex_screen()
	for _frame_index in range(8):
		await process_frame
	if section_id != "characters":
		var tab := main.find_child("CodexTab_%s" % section_id, true, false) as Button
		if tab != null:
			tab.pressed.emit()
		for _frame_index in range(8):
			await process_frame
	var image := viewport.get_texture().get_image()
	if image == null:
		return
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum958")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	image.save_png("%s/codex_%s_%dx%d.png" % [qa_dir, section_id, viewport_size.x, viewport_size.y])


func _section_specs() -> Array:
	var characters := []
	for entry in CodexData.characters():
		characters.append(_entry_spec(entry, str(entry["sprite"]), CodexImageFit.POLICY_CHARACTER))
	var monsters := []
	for kind in ["standard", "elite", "mini_elite", "boss"]:
		for entry in CodexData.monsters():
			if str(entry["kind"]) == kind:
				monsters.append(_entry_spec(entry, str(entry["sprite"]), CodexImageFit.POLICY_MONSTER))
	var artifacts := []
	for entry in CodexData.artifacts():
		var artifact_id := str(entry["id"])
		var path := "res://assets/sprites/ui/icons/artifacts/artifact_%s.png" % artifact_id
		if artifact_id.begins_with("shop_"):
			path = "res://assets/sprites/ui/icons/shop/shop_%s.png" % artifact_id
		artifacts.append(_entry_spec(entry, path, CodexImageFit.POLICY_ARTIFACT))
	return [
		{"id": "characters", "entries": characters},
		{"id": "monsters", "entries": monsters},
		{"id": "artifacts", "entries": artifacts},
	]


func _entry_spec(entry: Dictionary, path: String, policy: String) -> Dictionary:
	return {
		"id": str(entry["id"]),
		"title": str(entry["title"]),
		"path": path,
		"policy": policy,
	}


func _check_card(card: Button, spec: Dictionary, context: String) -> void:
	if card == null:
		errors.append("%s: missing card." % context)
		return
	var names := card.find_children("CodexEntryName", "Label", true, false)
	var textures := card.find_children("*Texture", "TextureRect", true, false)
	if names.size() != 1 or textures.size() != 1:
		errors.append("%s: expected one canonical name and one actual image, got %d/%d." % [context, names.size(), textures.size()])
		return
	var name := names[0] as Label
	if name.text != str(spec["title"]) or name.text.contains(str(spec["id"])) or name.horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER:
		errors.append("%s: player-facing row name '%s' is not the exact centered Russian title '%s'." % [context, name.text, str(spec["title"])])
	_check_texture(textures[0] as TextureRect, spec, LIST_TARGET, "%s list" % context)


func _check_texture(texture_rect: TextureRect, spec: Dictionary, target_size: Vector2, context: String) -> void:
	if texture_rect == null or texture_rect.texture == null:
		errors.append("%s: missing actual entry image." % context)
		return
	if texture_rect.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
		errors.append("%s: image is not centered contain." % context)
	var view := texture_rect.texture as AtlasTexture
	if view == null:
		errors.append("%s: image is not an immutable AtlasTexture fit view." % context)
		return
	var expected_path := str(spec["path"])
	if expected_path.is_empty() or not ResourceLoader.exists(expected_path):
		errors.append("%s: canonical source path does not exist: %s." % [context, expected_path])
	var atlas_path := view.atlas.resource_path if view.atlas != null else ""
	if CodexImageFit.canonical_path(view) != expected_path or atlas_path != expected_path:
		errors.append("%s: resolved source %s/%s != %s; generic fallback is forbidden." % [context, CodexImageFit.canonical_path(view), atlas_path, expected_path])
	if str(view.get_meta("codex_image_policy", "")) != str(spec["policy"]):
		errors.append("%s: policy %s != %s." % [context, str(view.get_meta("codex_image_policy", "")), str(spec["policy"])])
	var virtual_region: Rect2i = view.get_meta("codex_view_region", Rect2i())
	var metadata_atlas_region: Rect2i = view.get_meta("codex_atlas_region", Rect2i())
	var actual_atlas_region := Rect2i(view.region)
	var visible: Rect2i = view.get_meta("codex_visible_rect", Rect2i())
	var source_size: Vector2i = view.get_meta("codex_source_size", Vector2i.ZERO)
	var source_image := view.atlas.get_image() if view.atlas != null else null
	var actual_visible := source_image.get_used_rect() if source_image != null and not source_image.is_empty() else Rect2i(Vector2i.ZERO, source_size)
	if virtual_region.size.x <= 0 or virtual_region.size.y <= 0 or visible.size.x <= 0 or visible.size.y <= 0:
		errors.append("%s: empty fit/alpha region." % context)
		return
	if source_size != Vector2i(view.atlas.get_width(), view.atlas.get_height()) or visible != actual_visible:
		errors.append("%s: source-size/alpha metadata does not match independently derived atlas data." % context)
	if metadata_atlas_region != actual_atlas_region:
		errors.append("%s: metadata atlas region %s != actual %s." % [context, str(metadata_atlas_region), str(actual_atlas_region)])
	if not _rect_contains(actual_atlas_region, actual_visible):
		errors.append("%s: physical atlas region %s crops visible alpha %s." % [context, str(actual_atlas_region), str(actual_visible)])
	if not _rect_contains(virtual_region, actual_visible):
		errors.append("%s: virtual fit region %s crops visible alpha %s." % [context, str(virtual_region), str(actual_visible)])
	var reserve_ratio := float(RESERVE_BY_POLICY.get(str(spec["policy"]), 0.0))
	var required_x := int(ceilf(float(actual_visible.size.x) * reserve_ratio))
	var required_y := int(ceilf(float(actual_visible.size.y) * reserve_ratio))
	var reserves := PackedInt32Array([
		actual_visible.position.x - virtual_region.position.x,
		actual_visible.position.y - virtual_region.position.y,
		virtual_region.end.x - actual_visible.end.x,
		virtual_region.end.y - actual_visible.end.y,
	])
	if reserves[0] < required_x or reserves[2] < required_x or reserves[1] < required_y or reserves[3] < required_y:
		errors.append("%s: reserve L/T/R/B %s is below required %d/%d/%d/%d." % [context, str(reserves), required_x, required_y, required_x, required_y])
	var expected_margin := Rect2(
		Vector2(actual_atlas_region.position - virtual_region.position),
		Vector2(virtual_region.size - actual_atlas_region.size)
	)
	if not view.margin.is_equal_approx(expected_margin) or not view.get_size().is_equal_approx(Vector2(virtual_region.size)):
		errors.append("%s: actual margin/output %s/%s != virtual canvas %s/%s." % [context, str(view.margin), str(view.get_size()), str(expected_margin), str(virtual_region.size)])
	var expected_aspect := target_size.x / target_size.y
	var region_aspect := float(virtual_region.size.x) / float(virtual_region.size.y)
	if absf(region_aspect - expected_aspect) > 0.02:
		errors.append("%s: fit aspect %.3f does not follow target %.3f." % [context, region_aspect, expected_aspect])
	var scale := minf(target_size.x / float(virtual_region.size.x), target_size.y / float(virtual_region.size.y))
	var visible_size := Vector2(actual_visible.size) * scale
	match str(spec["policy"]):
		CodexImageFit.POLICY_CHARACTER:
			if visible_size.x < target_size.x * 0.48 or visible_size.y < target_size.y * 0.72:
				errors.append("%s: character remains a micro-preview at %s inside %s." % [context, str(visible_size), str(target_size)])
			if str(view.get_meta("codex_anchor", "")) != "bottom_center":
				errors.append("%s: character view lost bottom-center anchoring." % context)
		CodexImageFit.POLICY_MONSTER:
			if visible_size.x < target_size.x * 0.58 or visible_size.y < target_size.y * 0.50:
				errors.append("%s: monster remains unreadably small at %s." % [context, str(visible_size)])
		CodexImageFit.POLICY_ARTIFACT:
			if maxf(visible_size.x / target_size.x, visible_size.y / target_size.y) < 0.68:
				errors.append("%s: artifact does not use the readable long axis: %s." % [context, str(visible_size)])
	var slot := texture_rect.get_parent() as Control
	if slot == null or not _rect_contains_float(slot.get_global_rect(), texture_rect.get_global_rect(), 1.5):
		errors.append("%s: image leaves its empty frame content zone." % context)


func _rect_contains(outer: Rect2i, inner: Rect2i) -> bool:
	return inner.position.x >= outer.position.x and inner.position.y >= outer.position.y \
		and inner.end.x <= outer.end.x and inner.end.y <= outer.end.y


func _rect_contains_float(outer: Rect2, inner: Rect2, tolerance: float) -> bool:
	return inner.position.x >= outer.position.x - tolerance and inner.position.y >= outer.position.y - tolerance \
		and inner.end.x <= outer.end.x + tolerance and inner.end.y <= outer.end.y + tolerance
