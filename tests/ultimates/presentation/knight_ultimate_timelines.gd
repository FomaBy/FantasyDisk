extends SceneTree

const PROFILE_PATH := "res://data/ultimates/schema/v1/classes/knight.json"
const MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/knight/manifest.json"
const TIMELINE := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_timeline.gd")
const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")
const WEAPON_IDS := ["long_spear", "tower_shield", "holy_flail"]
const SCENES := {
	"long_spear": preload("res://scenes/vfx/ultimates/knight/KnightLongSpearSpearWall.tscn"),
	"tower_shield": preload("res://scenes/vfx/ultimates/knight/KnightTowerShieldImpassableLine.tscn"),
	"holy_flail": preload("res://scenes/vfx/ultimates/knight/KnightHolyFlailHeavenlySpiral.tscn"),
}
const EFFECT_SCENES := {
	"long_spear": preload("res://scripts/ultimates/classes/knight/long_spear.tscn"),
	"tower_shield": preload("res://scripts/ultimates/classes/knight/tower_shield.tscn"),
	"holy_flail": preload("res://scripts/ultimates/classes/knight/holy_flail.tscn"),
}
const VICTIM_FRAMES := {
	"long_spear": "res://assets/sprites/effects/knight/long_spear/long_spear_spriteframes.tres",
	"tower_shield": "res://assets/sprites/effects/knight/tower_shield/tower_shield_spriteframes.tres",
	"holy_flail": "res://assets/sprites/effects/knight/holy_flail/holy_flail_spriteframes.tres",
}
## Damaging beats one enemy takes across the driven cast: the three phalanx rows
## split the corridor snapshot one row apiece, the shield counters once, and the
## spiral re-resolves its whole ring on each of the two turns driven below.
const IMPACT_BEATS := {
	"long_spear": 1,
	"tower_shield": 1,
	"holy_flail": 2,
}
## Above UltimateVictimImpactPlayer.DEGRADE_VICTIM_THRESHOLD, so the crowd
## variant is exercised too.
const IMPACT_VICTIM_COUNT := 39
const PACKS := [
	{
		"weapon_id": "long_spear",
		"scene": preload("res://scenes/vfx/ultimates/knight/KnightLongSpearSpearWall.tscn"),
		"time": 2.4,
		"title": "LONG SPEAR — SPEAR WALL / phalanx corridor",
		"position": Vector2(0.18, 0.54),
		"color": Color(0.72, 0.82, 0.95),
		"required_nodes": ["CorridorGuide", "Phalanx/RankOne", "Phalanx/RankTwo", "Phalanx/RankThree"],
	},
	{
		"weapon_id": "tower_shield",
		"scene": preload("res://scenes/vfx/ultimates/knight/KnightTowerShieldImpassableLine.tscn"),
		"time": 5.6,
		"title": "TOWER SHIELD — IMPASSABLE LINE / wall push",
		"position": Vector2(0.5, 0.54),
		"color": Color(1.0, 0.84, 0.5),
		"required_nodes": ["GuardStance", "ShieldWall/WallCore", "ShieldWall/Rampart", "ShieldWall/SparkField"],
	},
	{
		"weapon_id": "holy_flail",
		"scene": preload("res://scenes/vfx/ultimates/knight/KnightHolyFlailHeavenlySpiral.tscn"),
		"time": 4.4,
		"title": "HOLY FLAIL — HEAVENLY SPIRAL / pull-launch",
		"position": Vector2(0.82, 0.54),
		"color": Color(1.0, 0.93, 0.7),
		"required_nodes": ["ChainRise", "FlailHead", "SpiralPath", "PullGlints/GlintEast"],
	},
]
const CAPTURES := [
	{"name": "648p", "path": "res://docs/design/references/weapon_ultimates/knight/knight_ultimate_timelines_648p.png", "size": Vector2i(1152, 648)},
	{"name": "720p", "path": "res://docs/design/references/weapon_ultimates/knight/knight_ultimate_timelines_720p.png", "size": Vector2i(1280, 720)},
	{"name": "1080p", "path": "res://docs/design/references/weapon_ultimates/knight/knight_ultimate_timelines_1080p.png", "size": Vector2i(1920, 1080)},
	{"name": "2k", "path": "res://docs/design/references/weapon_ultimates/knight/knight_ultimate_timelines_2k.png", "size": Vector2i(2560, 1440)},
]
const PANEL_HALF_WIDTH_RATIO := 0.145
const PANEL_HALF_HEIGHT_RATIO := 0.30
const PANEL_LABEL_Y_RATIO := 0.25
const PANEL_LABEL_X_OFFSET_RATIO := 0.14
const PANEL_LABEL_FONT_RATIO := 0.021
const PANEL_CONTENT_MARGIN_RATIO := 0.03
const SHEET_TITLE := "KNIGHT WEAPON ULTIMATES — DISTINCT PRESENTATION TIMELINES"
const SHEET_TITLE_Y_RATIO := 0.075
const SHEET_TITLE_FONT_RATIO := 0.036
const SHEET_TEXT_MARGIN := 8.0
const CAPTURE_ALPHA_EPSILON := 0.01
const REQUIRED_PHASES := ["windup", "release", "active", "recovery", "cancel"]
const MAX_TIMELINE_SECONDS := 10.0


class HandleProbe extends RefCounted:
	var released := 0

	func release() -> void:
		released += 1


class VictimProbe extends Node2D:
	var flashes := 0

	func _combat_feedback_enabled() -> bool:
		return true

	func _show_hit_flash() -> void:
		flashes += 1


class ImpactActivationProbe extends RefCounted:
	var targets: Array = []

	func origin() -> Vector2:
		return Vector2.ZERO

	func is_finished() -> bool:
		return false

	func composition_aborted() -> bool:
		return false

	func abort_composition() -> void:
		pass

	func composition_step(_step_id: String) -> void:
		pass

	func param_int(_key: String, fallback: int) -> int:
		return fallback

	func param_float(_key: String, fallback: float) -> float:
		return fallback

	func scaled_damage(_key: String, fallback: float) -> float:
		return fallback

	func aim_direction(_radius: float) -> Vector2:
		return Vector2.RIGHT

	func configure_guard_prevention(
		_owner_id: String, _resource_id: String, _cap: float,
		_direction: Vector2, _arc_degrees: float, _sources: Array
	) -> bool:
		return true

	func consume_owner_resource(_owner_id: String, _resource_id: String, _reason: String) -> Dictionary:
		return {"amount": 40.0}

	func select_targets(_origin: Vector2, _radius: float, _cap: int, _order: String) -> Array:
		return targets

	func record_target_value(_target: Node, _key: String, _value: int, _reason: String) -> bool:
		return true

	func apply_control(_target: Node, _impulse: Vector2, _status_id: String, _status: Dictionary) -> Dictionary:
		return {"status_applied": true, "tier": "normal", "displaced": true}

	func deal_damage(
		_target: Node, amount: float, _feedback: Dictionary, _event_id: String, _secondary: bool
	) -> Dictionary:
		return {"applied": amount, "killed": false}

	func present(_phase_id: String, _payload: Dictionary) -> void:
		pass


func _initialize() -> void:
	var errors: Array[String] = []
	var profile_root := _load_json(PROFILE_PATH, errors)
	var manifest := _load_json(MANIFEST_PATH, errors)
	if not errors.is_empty():
		_finish(errors)
		return
	_expect(str(manifest.get("class_id", "")) == "knight", "manifest must be class-local to Knight", errors)
	_expect(str((manifest.get("contract", {}) as Dictionary).get("headless_fallback", "")) == "no_op", "manifest must declare no_op headless fallback", errors)
	_expect(not str((manifest.get("contract", {}) as Dictionary).get("runtime_adapter_status", "")).is_empty(), "runtime adapter boundary must be documented", errors)
	_check_provenance(manifest, errors)
	var profiles := _profiles_by_weapon(profile_root)
	var packages := _packages_by_weapon(manifest)
	_expect(packages.size() == 3, "manifest must contain exactly three Knight weapon packages", errors)
	for weapon_id in WEAPON_IDS:
		_check_package(weapon_id, profiles.get(weapon_id, {}) as Dictionary, packages.get(weapon_id, {}) as Dictionary, errors)
	_check_distinction(packages, errors)
	_check_weapon_local_impacts(errors)
	_check_capture_composition(errors)
	_check_capture_text(errors)
	_check_capture_evidence(errors)
	if not errors.is_empty():
		_finish(errors)
		return
	print("Knight ultimate timelines passed (three distinct scenes, frozen phases, victim impacts, lifecycle, evidence, and crowd budgets).")
	quit(0)


func _check_provenance(manifest: Dictionary, errors: Array[String]) -> void:
	var provenance := manifest.get("generator_provenance", {}) as Dictionary
	_expect(str(provenance.get("route", "")) == "reused_approved_assets_no_new_raster_generation", "provenance route must explain why no new raster source was generated", errors)
	_expect((provenance.get("new_pixellab_assets", null) is Array) and (provenance.get("new_pixellab_assets") as Array).is_empty(), "provenance must record that no new PixelLab assets were generated", errors)
	var sources := provenance.get("reused_sources", {}) as Dictionary
	for weapon_id in WEAPON_IDS:
		var source := sources.get(weapon_id, {}) as Dictionary
		_expect(FileAccess.file_exists("res://%s" % str(source.get("runtime_scene", ""))), "%s runtime scene must be recorded and exist" % weapon_id, errors)
		_expect(FileAccess.file_exists("res://%s" % str(source.get("source_path", ""))), "%s reused source asset must be recorded and exist" % weapon_id, errors)


func _check_package(weapon_id: String, profile: Dictionary, package: Dictionary, errors: Array[String]) -> void:
	_expect(not profile.is_empty(), "%s frozen profile must exist" % weapon_id, errors)
	_expect(not package.is_empty(), "%s presentation package must exist" % weapon_id, errors)
	if profile.is_empty() or package.is_empty():
		return
	_expect(str(package.get("weapon_id", "")) == weapon_id, "%s package weapon ID must be exact" % weapon_id, errors)
	var timing := package.get("timing_seconds", {}) as Dictionary
	var phases := package.get("phase_ids", {}) as Dictionary
	var previous := -1.0
	for phase_name in REQUIRED_PHASES:
		var value = timing.get(phase_name, -1.0)
		_expect(value is float or value is int, "%s %s timing must be numeric" % [weapon_id, phase_name], errors)
		var seconds := float(value)
		_expect(seconds >= previous and seconds <= MAX_TIMELINE_SECONDS, "%s %s timing must be monotonic and within the ten-second cap" % [weapon_id, phase_name], errors)
		previous = seconds
		var expected_phase := str((profile.get("cast_phases", {}) as Dictionary).get(_cast_phase_name(phase_name), ""))
		_expect(str(phases.get(phase_name, "")) == expected_phase, "%s %s must bind to frozen Cast phase ID" % [weapon_id, phase_name], errors)
	_check_scene(weapon_id, package, errors)
	_check_lifecycle(weapon_id, timing, phases, errors)


func _check_scene(weapon_id: String, package: Dictionary, errors: Array[String]) -> void:
	var scene := SCENES.get(weapon_id) as PackedScene
	_expect(scene != null, "%s scene must load" % weapon_id, errors)
	if scene == null:
		return
	var instance := scene.instantiate() as Node2D
	root.add_child(instance)
	var timeline := instance.get_node_or_null("Timeline") as AnimationPlayer
	_expect(timeline != null and timeline.has_animation(&"ultimate"), "%s must expose an ultimate animation" % weapon_id, errors)
	if timeline != null and timeline.has_animation(&"ultimate"):
		_expect(is_equal_approx(timeline.get_animation(&"ultimate").length, float((package.get("timing_seconds", {}) as Dictionary).get("cancel", -1.0))), "%s scene animation length must end on its cancel phase" % weapon_id, errors)
	_expect(str(instance.get_meta("ultimate_id", "")) == "knight/%s" % weapon_id, "%s scene must retain its exact profile key" % weapon_id, errors)
	_expect(not str(instance.get_meta("silhouette", "")).is_empty(), "%s silhouette declaration missing" % weapon_id, errors)
	_expect(not str(instance.get_meta("motion_path", "")).is_empty(), "%s motion path declaration missing" % weapon_id, errors)
	_expect(not str(instance.get_meta("impact_language", "")).is_empty(), "%s impact language declaration missing" % weapon_id, errors)
	_expect(instance.get_child_count() <= int(instance.get_meta("crowd_cap", 0)), "%s visual-node count must stay within crowd cap" % weapon_id, errors)
	_expect(int(instance.get_meta("max_visual_nodes", 0)) <= int(instance.get_meta("crowd_cap", 0)), "%s declared visual budget must stay within crowd cap" % weapon_id, errors)
	instance.queue_free()


func _check_lifecycle(weapon_id: String, timing: Dictionary, phases: Dictionary, errors: Array[String]) -> void:
	var phase_entries: Array[Dictionary] = []
	for name in REQUIRED_PHASES:
		phase_entries.append({"name": name, "phase_id": str(phases.get(name, ""))})
	var fixture := {
		"timing": timing,
		"phases": phase_entries,
	}
	var timeline = TIMELINE.new(fixture, 0)
	var handles := {"animation": HandleProbe.new(), "vfx": HandleProbe.new(), "sfx": HandleProbe.new()}
	timeline.begin(handles)
	timeline.advance(0.05)
	var paused_time := timeline.elapsed_seconds()
	timeline.set_paused(true)
	timeline.advance(1.0)
	_expect(is_equal_approx(timeline.elapsed_seconds(), paused_time), "%s timeline pause must freeze elapsed time" % weapon_id, errors)
	timeline.set_paused(false)
	for reason in ["cancel", "death", "node_end"]:
		var cleanup_timeline = TIMELINE.new(fixture, 0)
		var cleanup_handles := {"animation": HandleProbe.new(), "vfx": HandleProbe.new(), "sfx": HandleProbe.new()}
		cleanup_timeline.begin(cleanup_handles)
		cleanup_timeline.finish(reason)
		_expect(cleanup_timeline.active_handle_count() == 0, "%s %s cleanup must release all handles" % [weapon_id, reason], errors)
		for handle in cleanup_handles.values():
			_expect((handle as HandleProbe).released == 1, "%s %s cleanup must release each handle exactly once" % [weapon_id, reason], errors)


func _check_distinction(packages: Dictionary, errors: Array[String]) -> void:
	for field in ["silhouette", "motion_path", "impact_language"]:
		var values := {}
		for weapon_id in WEAPON_IDS:
			values[str((packages.get(weapon_id, {}) as Dictionary).get(field, ""))] = true
		_expect(values.size() == 3 and not values.has(""), "all three weapons must have different %s values" % field, errors)


## Every Knight ultimate must route the enemies it actually hits through the
## shared per-victim impact service, with its own class flipbook. A weapon whose
## mapping is removed or broken reports no player here and fails the suite.
func _check_weapon_local_impacts(errors: Array[String]) -> void:
	for weapon_id in WEAPON_IDS:
		var effect := (EFFECT_SCENES[weapon_id] as PackedScene).instantiate() as Node2D
		root.add_child(effect)
		effect.set("ultimate_damage_sink", Callable(self, "_damage_sink"))
		var activation := ImpactActivationProbe.new()
		var victims: Array = []
		for index in IMPACT_VICTIM_COUNT:
			var victim := VictimProbe.new()
			victim.position = Vector2(40.0 + float(index) * 8.0, float(index % 3) * 18.0)
			root.add_child(victim)
			victims.append(victim)
		activation.targets = victims
		match weapon_id:
			"long_spear":
				effect.call("configure", activation, victims, Vector2.RIGHT)
				for row in 3:
					effect.call("advance_row", row)
			"tower_shield":
				_expect(bool(effect.call("configure", activation)), "tower_shield guard stance must configure", errors)
				effect.call("counter_burst")
			"holy_flail":
				effect.call("configure", activation, {
					"turns": [], "radii": [], "impulses": [], "direction_switches": 0,
				})
				effect.call("turn", 0)
				effect.call("turn", 1)
		var expected_victims: int = IMPACT_VICTIM_COUNT * int(IMPACT_BEATS[weapon_id])
		var impacts := _impact_player(effect)
		_expect(impacts != null, "%s must start the shared weapon-local victim impact" % weapon_id, errors)
		if impacts != null:
			var planned := impacts.call("snapshot") as Dictionary
			_expect(int(planned.get("victims", 0)) == expected_victims, "%s must enqueue each hit enemy once per damaging beat" % weapon_id, errors)
			_expect(bool(planned.get("degraded", false)), "%s must use the bounded crowd variant above 38 victims" % weapon_id, errors)
			_expect(float(planned.get("burst_seconds", 0.0)) >= 0.3 and float(planned.get("burst_seconds", 0.0)) <= 0.6, "%s victim impact must last 0.3-0.6 seconds" % weapon_id, errors)
			_expect(int(planned.get("stagger_frames", 0)) >= ImpactPlayer.STAGGER_MIN_FRAMES and int(planned.get("stagger_frames", 0)) <= ImpactPlayer.STAGGER_MAX_FRAMES, "%s victim ripple must stagger outward by 3-8 frames" % weapon_id, errors)
			impacts.call("advance", 10.0)
			var played := impacts.call("snapshot") as Dictionary
			_expect(int(played.get("flashes", 0)) == expected_victims, "%s degradation must never drop the existing white victim flash" % weapon_id, errors)
			_expect(int(played.get("created_nodes", 0)) <= ImpactPlayer.POOL_CAP, "%s burst node creation must stay inside the pool cap" % weapon_id, errors)
			var burst := impacts.find_child("VictimImpact0", true, false) as AnimatedSprite2D
			_expect(burst != null and burst.sprite_frames != null and burst.sprite_frames.resource_path == str(VICTIM_FRAMES[weapon_id]), "%s victim impact must use its own class flipbook" % weapon_id, errors)
		effect.queue_free()
		for victim in victims:
			(victim as Node).queue_free()


func _impact_player(effect: Node) -> Node:
	for child in effect.get_children():
		if child.get_script() == ImpactPlayer:
			return child
	return null


func _damage_sink(_target: Node, amount: float, _feedback: Dictionary, _event_id: String, _secondary: bool) -> Dictionary:
	return {"applied": amount, "killed": false}


func _check_capture_composition(errors: Array[String]) -> void:
	for raw_capture in CAPTURES:
		var capture := raw_capture as Dictionary
		var size := capture.get("size", Vector2i.ZERO) as Vector2i
		for raw_pack in PACKS:
			var pack := raw_pack as Dictionary
			var scene := (pack["scene"] as PackedScene).instantiate() as Node2D
			root.add_child(scene)
			seek_capture_frame(scene, pack)
			var bounds := layout_capture_scene(scene, size, pack)
			var content_zone := panel_content_rect(size, pack)
			var context := "%s %s" % [str(capture.get("name", "")), str(pack.get("weapon_id", ""))]
			_expect(bounds.has_area(), "%s capture must expose visible content bounds" % context, errors)
			_expect(content_zone.grow(0.5).encloses(bounds), "%s capture content %s must stay inside panel content zone %s" % [context, bounds, content_zone], errors)
			for raw_node_path in pack.get("required_nodes", []) as Array:
				var node_path := str(raw_node_path)
				var item := scene.get_node_or_null(node_path) as CanvasItem
				_expect(item != null, "%s required capture node missing: %s" % [context, node_path], errors)
				if item == null:
					continue
				_expect(is_capture_item_visible(item, scene), "%s required capture node must be visible: %s" % [context, node_path], errors)
				var item_bounds := capture_item_bounds(scene, item)
				var placed_item_bounds := transformed_capture_bounds(item_bounds, scene)
				_expect(placed_item_bounds.has_area(), "%s required capture node must have bounds: %s" % [context, node_path], errors)
				_expect(content_zone.grow(0.5).encloses(placed_item_bounds), "%s %s bounds %s must stay inside panel content zone %s" % [context, node_path, placed_item_bounds, content_zone], errors)
			scene.queue_free()


func _check_capture_text(errors: Array[String]) -> void:
	for raw_capture in CAPTURES:
		var capture := raw_capture as Dictionary
		var size := capture.get("size", Vector2i.ZERO) as Vector2i
		var sheet_zone := Rect2(Vector2.ZERO, Vector2(size)).grow(-SHEET_TEXT_MARGIN)
		var title_rect := sheet_title_rect(size)
		_expect(sheet_zone.encloses(title_rect), "%s sheet title \"%s\" bounds %s must stay inside sheet %s" % [str(capture.get("name", "")), SHEET_TITLE, title_rect, sheet_zone], errors)
		for raw_pack in PACKS:
			var pack := raw_pack as Dictionary
			var label_rect := panel_label_rect(size, pack)
			var panel := panel_rect(size, pack)
			_expect(panel.grow(0.5).encloses(label_rect), "%s panel label \"%s\" bounds %s must stay inside panel %s" % [str(capture.get("name", "")), str(pack["title"]), label_rect, panel], errors)


func _check_capture_evidence(errors: Array[String]) -> void:
	for raw_capture in CAPTURES:
		var capture := raw_capture as Dictionary
		var path := str(capture.get("path", ""))
		_expect(FileAccess.file_exists(path), "contact evidence is missing: %s" % path, errors)
		if not FileAccess.file_exists(path):
			continue
		var image := Image.load_from_file(path)
		_expect(image != null and not image.is_empty(), "contact evidence must decode: %s" % path, errors)
		if image != null:
			_expect(image.get_size() == capture.get("size", Vector2i.ZERO), "contact evidence resolution mismatch: %s" % path, errors)


static func panel_center(size: Vector2i, pack: Dictionary) -> Vector2:
	return Vector2(size) * (pack["position"] as Vector2)


static func panel_rect(size: Vector2i, pack: Dictionary) -> Rect2:
	var center := panel_center(size, pack)
	var half_size := Vector2(float(size.x) * PANEL_HALF_WIDTH_RATIO, float(size.y) * PANEL_HALF_HEIGHT_RATIO)
	return Rect2(center - half_size, half_size * 2.0)


static func sheet_title_font_size(size: Vector2i) -> int:
	return maxi(18, int(size.y * SHEET_TITLE_FONT_RATIO))


static func sheet_title_rect(size: Vector2i) -> Rect2:
	var text_size := ThemeDB.fallback_font.get_string_size(SHEET_TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, sheet_title_font_size(size))
	return Rect2(Vector2((float(size.x) - text_size.x) * 0.5, float(size.y) * SHEET_TITLE_Y_RATIO), text_size)


static func panel_label_font_size(size: Vector2i) -> int:
	return maxi(12, int(size.y * PANEL_LABEL_FONT_RATIO))


static func panel_label_rect(size: Vector2i, pack: Dictionary) -> Rect2:
	var text_size := ThemeDB.fallback_font.get_string_size(str(pack["title"]), HORIZONTAL_ALIGNMENT_LEFT, -1, panel_label_font_size(size))
	var position := panel_center(size, pack) + Vector2(-float(size.x) * PANEL_LABEL_X_OFFSET_RATIO, float(size.y) * PANEL_LABEL_Y_RATIO)
	return Rect2(position, text_size)


static func panel_content_rect(size: Vector2i, pack: Dictionary) -> Rect2:
	var panel := panel_rect(size, pack)
	var center := panel_center(size, pack)
	var margin := float(size.y) * PANEL_CONTENT_MARGIN_RATIO
	var content_position := panel.position + Vector2.ONE * margin
	var label_y := center.y + float(size.y) * PANEL_LABEL_Y_RATIO
	return Rect2(content_position, Vector2(panel.size.x - margin * 2.0, label_y - margin - content_position.y))


static func seek_capture_frame(scene: Node2D, pack: Dictionary) -> void:
	var timeline := scene.get_node("Timeline") as AnimationPlayer
	timeline.stop()
	timeline.play(&"ultimate")
	timeline.seek(float(pack["time"]), true)


static func layout_capture_scene(scene: Node2D, size: Vector2i, pack: Dictionary) -> Rect2:
	scene.position = Vector2.ZERO
	scene.scale = Vector2.ONE
	var bounds := capture_content_bounds(scene)
	if not bounds.has_area():
		return Rect2()
	var content_zone := panel_content_rect(size, pack)
	var base_scale := clampf(float(size.y) / 1040.0, 0.54, 1.28)
	var fit_scale := minf(content_zone.size.x / bounds.size.x, content_zone.size.y / bounds.size.y)
	var scale := minf(base_scale, fit_scale)
	scene.scale = Vector2.ONE * scale
	scene.position = content_zone.get_center() - bounds.get_center() * scale
	return transformed_capture_bounds(bounds, scene)


static func capture_content_bounds(scene: Node2D) -> Rect2:
	var bounds := Rect2()
	var found := false
	var pending: Array[Node] = [scene]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child in node.get_children():
			pending.append(child)
			if not child is CanvasItem:
				continue
			var item := child as CanvasItem
			if not is_capture_item_visible(item, scene):
				continue
			var item_bounds := capture_item_bounds(scene, item)
			if not item_bounds.has_area():
				continue
			bounds = item_bounds if not found else bounds.merge(item_bounds)
			found = true
	return bounds


static func capture_item_bounds(scene: Node2D, item: CanvasItem) -> Rect2:
	var local_rect := _capture_item_local_rect(item)
	if not local_rect.has_area():
		return Rect2()
	var transform := _transform_to_scene(scene, item)
	var corners := PackedVector2Array([
		transform * local_rect.position,
		transform * Vector2(local_rect.end.x, local_rect.position.y),
		transform * local_rect.end,
		transform * Vector2(local_rect.position.x, local_rect.end.y),
	])
	return _rect_from_points(corners)


static func transformed_capture_bounds(bounds: Rect2, scene: Node2D) -> Rect2:
	if not bounds.has_area():
		return Rect2()
	return Rect2(scene.position + bounds.position * scene.scale, bounds.size * scene.scale)


static func is_capture_item_visible(item: CanvasItem, scene: Node2D) -> bool:
	var cursor: Node = item
	while cursor != null and cursor != scene:
		if cursor is CanvasItem:
			var canvas_item := cursor as CanvasItem
			if not canvas_item.visible or canvas_item.modulate.a * canvas_item.self_modulate.a <= CAPTURE_ALPHA_EPSILON:
				return false
		cursor = cursor.get_parent()
	if item is Polygon2D and (item as Polygon2D).color.a <= CAPTURE_ALPHA_EPSILON:
		return false
	if item is Line2D and (item as Line2D).default_color.a <= CAPTURE_ALPHA_EPSILON:
		return false
	return true


static func _capture_item_local_rect(item: CanvasItem) -> Rect2:
	if item is Sprite2D:
		return (item as Sprite2D).get_rect()
	if item is AnimatedSprite2D:
		var sprite := item as AnimatedSprite2D
		var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		if texture == null:
			return Rect2()
		var size := texture.get_size()
		var position := sprite.offset - size * 0.5 if sprite.centered else sprite.offset
		return Rect2(position, size)
	if item is Line2D:
		var line := item as Line2D
		return _rect_from_points(line.points).grow(line.width * 0.5)
	if item is Polygon2D:
		return _rect_from_points((item as Polygon2D).polygon)
	return Rect2()


static func _transform_to_scene(scene: Node2D, item: CanvasItem) -> Transform2D:
	var transform := Transform2D.IDENTITY
	var cursor: Node = item
	while cursor != null and cursor != scene:
		if cursor is Node2D:
			transform = (cursor as Node2D).transform * transform
		cursor = cursor.get_parent()
	return transform


static func _rect_from_points(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var min_point := points[0]
	var max_point := points[0]
	for point in points:
		min_point = min_point.min(point)
		max_point = max_point.max(point)
	return Rect2(min_point, max_point - min_point)


func _profiles_by_weapon(root_data: Dictionary) -> Dictionary:
	var result := {}
	for raw_profile in root_data.get("profiles", []) as Array:
		if raw_profile is Dictionary:
			var profile := raw_profile as Dictionary
			result[str(profile.get("weapon_id", ""))] = profile
	return result


func _packages_by_weapon(manifest: Dictionary) -> Dictionary:
	var result := {}
	for raw_package in manifest.get("weapons", []) as Array:
		if raw_package is Dictionary:
			var package := raw_package as Dictionary
			result[str(package.get("weapon_id", ""))] = package
	return result


func _cast_phase_name(presentation_name: String) -> String:
	return {"windup": "windup", "release": "execute", "active": "active", "recovery": "recover", "cancel": "cleanup"}.get(presentation_name, "")


func _load_json(path: String, errors: Array[String]) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("missing JSON: %s" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		errors.append("invalid JSON: %s" % path)
		return {}
	return parsed as Dictionary


func _expect(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)


func _finish(errors: Array[String]) -> void:
	for error in errors:
		push_error("Knight ultimate timeline: %s" % error)
	quit(1)
