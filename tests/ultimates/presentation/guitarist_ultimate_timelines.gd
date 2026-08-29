extends SceneTree

const PROFILE_PATH := "res://data/ultimates/schema/v1/classes/guitarist.json"
const MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/guitarist/manifest.json"
const TIMELINE := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_timeline.gd")
const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")
const WEAPON_IDS := ["electric_guitar", "bass_guitar", "sound_amp"]
const SCENES := {
	"electric_guitar": preload("res://scenes/vfx/ultimates/guitarist/GuitaristElectricGuitarLastChord.tscn"),
	"bass_guitar": preload("res://scenes/vfx/ultimates/guitarist/GuitaristBassGuitarHellSubwoofer.tscn"),
	"sound_amp": preload("res://scenes/vfx/ultimates/guitarist/GuitaristSoundAmpWallOfSound.tscn"),
}
const FLIPBOOKS := {
	"electric_guitar": {
		"node": "LastChord",
		"path": "res://assets/sprites/effects/guitarist/electric_guitar/electric_guitar_spriteframes.tres",
		"animation": &"electric_guitar_last_chord",
		"times": [0.0, 0.52, 0.68, 0.84, 1.0, 1.16, 1.4, 2.6, 4.7],
		"beats": [
			"weapon_ultimate.executor.guitarist.electric_guitar.riff:0",
			"weapon_ultimate.executor.guitarist.electric_guitar.final",
		],
	},
	"bass_guitar": {
		"node": "Subwoofer",
		"path": "res://assets/sprites/effects/guitarist/bass_guitar/bass_guitar_spriteframes.tres",
		"animation": &"bass_guitar_hell_subwoofer",
		"times": [0.0, 0.35, 0.7, 1.23, 1.76, 2.29, 3.3, 4.2, 5.0],
		"beats": [
			"weapon_ultimate.executor.guitarist.bass_guitar.pull",
			"weapon_ultimate.executor.guitarist.bass_guitar.shock",
		],
	},
	"sound_amp": {
		"node": "WallOfSound",
		"path": "res://assets/sprites/effects/guitarist/sound_amp/sound_amp_spriteframes.tres",
		"animation": &"guitarist_sound_amp_wall_of_sound",
		"times": [0.0, 0.68, 0.95, 1.22, 1.49, 1.94, 3.1, 4.3, 5.25],
		"beats": [
			"weapon_ultimate.executor.guitarist.sound_amp.feedback:0",
			"weapon_ultimate.executor.guitarist.sound_amp.overload",
		],
	},
}
const PACKS := [
	{"weapon_id": "electric_guitar", "scene": SCENES["electric_guitar"], "time": 1.72, "position": Vector2(0.18, 0.55), "title": "ELECTRIC GUITAR — LAST CHORD", "color": Color(0.36, 0.86, 1.0), "required_nodes": ["LastChord"]},
	{"weapon_id": "bass_guitar", "scene": SCENES["bass_guitar"], "time": 2.85, "position": Vector2(0.50, 0.55), "title": "BASS GUITAR — HELL SUBWOOFER", "color": Color(0.84, 0.44, 1.0), "required_nodes": ["Subwoofer"]},
	{"weapon_id": "sound_amp", "scene": SCENES["sound_amp"], "time": 3.64, "position": Vector2(0.82, 0.55), "title": "SOUND AMP — WALL OF SOUND", "color": Color(1.0, 0.76, 0.34), "required_nodes": ["WallOfSound"]},
]
const CAPTURES := [
	{"name": "648p", "file": "guitarist_ultimate_timelines_648p.png", "size": Vector2i(1152, 648)},
	{"name": "720p", "file": "guitarist_ultimate_timelines_720p.png", "size": Vector2i(1280, 720)},
	{"name": "1080p", "file": "guitarist_ultimate_timelines_1080p.png", "size": Vector2i(1920, 1080)},
	{"name": "2K", "file": "guitarist_ultimate_timelines_2k.png", "size": Vector2i(2560, 1440)},
]
const REQUIRED_PHASES := ["windup", "release", "active", "recovery", "cancel"]
const PHASE_BINDINGS := {"windup": "windup", "release": "execute", "active": "active", "recovery": "recover", "cancel": "cleanup"}
const SHEET_TITLE := "GUITARIST WEAPON ULTIMATES — DISTINCT PRESENTATION TIMELINES"
const SHEET_TITLE_Y_RATIO := 0.075
const SHEET_TITLE_FONT_RATIO := 0.036
const SHEET_TEXT_MARGIN := 8.0
const PANEL_HALF_WIDTH_RATIO := 0.145
const PANEL_HALF_HEIGHT_RATIO := 0.30
const PANEL_LABEL_Y_RATIO := 0.245
const PANEL_LABEL_FONT_RATIO := 0.021
const IMPACT_CROWD := 39


class HandleProbe extends RefCounted:
	var released := 0

	func release() -> void:
		released += 1


class VictimProbe extends Node2D:
	var health := 100.0
	var flashes := 0

	func _combat_feedback_enabled() -> bool:
		return true

	func _show_hit_flash() -> void:
		flashes += 1


func _initialize() -> void:
	var errors: Array[String] = []
	var profiles := _profiles_by_weapon(_load_json(PROFILE_PATH, errors))
	var manifest := _load_json(MANIFEST_PATH, errors)
	if not errors.is_empty():
		_finish(errors)
		return
	_expect(str(manifest.get("class_id", "")) == "guitarist", "manifest must be class-local to Guitarist", errors)
	var contract := manifest.get("contract", {}) as Dictionary
	_expect(str(contract.get("headless_fallback", "")) == "no_op", "manifest must declare no-op headless fallback", errors)
	_expect(float(contract.get("max_timeline_seconds", 0.0)) == 10.0, "manifest must retain the ten-second cap", errors)
	_expect(not str(contract.get("runtime_adapter_status", "")).is_empty(), "runtime adapter boundary must be documented", errors)
	_check_provenance(manifest, errors)
	var packages := _packages_by_weapon(manifest)
	_expect(packages.size() == WEAPON_IDS.size(), "manifest must contain exactly three Guitarist weapon packages", errors)
	for weapon_id in WEAPON_IDS:
		_check_package(weapon_id, profiles.get(weapon_id, {}) as Dictionary, packages.get(weapon_id, {}) as Dictionary, errors)
	_check_distinction(packages, errors)
	_check_weapon_local_impacts(errors)
	_check_capture_text(errors)
	if not errors.is_empty():
		_finish(errors)
		return
	print("Guitarist ultimate timelines passed (three exact flipbooks, frozen phases, per-victim beat impacts, lifecycle, and crowd budgets).")
	quit(0)


func _check_provenance(manifest: Dictionary, errors: Array[String]) -> void:
	var provenance := manifest.get("generator_provenance", {}) as Dictionary
	_expect(str(provenance.get("route", "")) == "integrated_approved_pixellab_animation_frames", "provenance route must identify the admitted PixelLab animation packs", errors)
	var assets := provenance.get("new_pixellab_assets", []) as Array
	_expect(assets == WEAPON_IDS, "provenance must list exactly the three admitted Guitarist packs", errors)
	_expect(str(provenance.get("integrated_art_candidate", "")) == "616662417a595fbf91d536f2fe02a151714c12b9", "provenance must pin the accepted art candidate", errors)
	var sources := provenance.get("reused_sources", {}) as Dictionary
	for weapon_id in WEAPON_IDS:
		var source := sources.get(weapon_id, {}) as Dictionary
		_expect(FileAccess.file_exists("res://%s" % str(source.get("runtime_scene", ""))), "%s runtime scene must be recorded and exist" % weapon_id, errors)
		_expect(FileAccess.file_exists("res://%s" % str(source.get("spriteframes", ""))), "%s SpriteFrames must be recorded and exist" % weapon_id, errors)
		_expect(FileAccess.file_exists("res://%s" % str(source.get("provenance_manifest", ""))), "%s pack provenance must be recorded and exist" % weapon_id, errors)


func _check_package(weapon_id: String, profile: Dictionary, package: Dictionary, errors: Array[String]) -> void:
	_expect(not profile.is_empty(), "%s frozen profile must exist" % weapon_id, errors)
	_expect(not package.is_empty(), "%s package must exist" % weapon_id, errors)
	if profile.is_empty() or package.is_empty():
		return
	_expect(str(package.get("weapon_id", "")) == weapon_id, "%s package must retain its exact weapon ID" % weapon_id, errors)
	var timing := package.get("timing_seconds", {}) as Dictionary
	var phases := package.get("phase_ids", {}) as Dictionary
	var previous := -1.0
	for phase_name in REQUIRED_PHASES:
		var timestamp := float(timing.get(phase_name, -1.0))
		_expect(timestamp >= previous and timestamp <= 10.0, "%s %s timing must be monotonic and capped" % [weapon_id, phase_name], errors)
		previous = timestamp
		var frozen_phase := str((profile.get("cast_phases", {}) as Dictionary).get(str(PHASE_BINDINGS[phase_name]), ""))
		_expect(str(phases.get(phase_name, "")) == frozen_phase, "%s %s must bind the frozen cast phase" % [weapon_id, phase_name], errors)
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
		_expect(is_equal_approx(timeline.get_animation(&"ultimate").length, float((package.get("timing_seconds", {}) as Dictionary).get("cancel", -1.0))), "%s animation must end at cancel" % weapon_id, errors)
		var sample := _pack_for(weapon_id)
		timeline.stop()
		timeline.play(&"ultimate")
		timeline.seek(float(sample.get("time", 0.0)), true)
		for node_path in sample.get("required_nodes", []) as Array:
			var item := instance.get_node_or_null(str(node_path)) as CanvasItem
			_expect(item != null and item.visible and item.modulate.a * item.self_modulate.a > 0.01, "%s required visual node must be visible: %s" % [weapon_id, node_path], errors)
	_expect(str(instance.get_meta("ultimate_id", "")) == "guitarist/%s" % weapon_id, "%s scene must retain its exact profile key" % weapon_id, errors)
	for field in ["silhouette", "motion_path", "impact_language"]:
		_expect(str(instance.get_meta(field, "")) == str(package.get(field, "")), "%s scene %s must match manifest" % [weapon_id, field], errors)
	var performance := package.get("performance", {}) as Dictionary
	_expect(int(instance.get_meta("max_visual_nodes", 0)) == int(performance.get("max_visual_nodes", -1)), "%s visual-node budget must match manifest" % weapon_id, errors)
	_expect(int(instance.get_meta("crowd_cap", 0)) == int(performance.get("crowd_cap", -1)), "%s crowd cap must match manifest" % weapon_id, errors)
	_expect(_visual_node_count(instance) <= int(instance.get_meta("max_visual_nodes", 0)), "%s scene must stay within its visual-node budget" % weapon_id, errors)
	_check_scene_flipbook(weapon_id, package, instance, timeline, errors)
	instance.queue_free()


func _check_scene_flipbook(weapon_id: String, package: Dictionary, instance: Node2D, timeline: AnimationPlayer, errors: Array[String]) -> void:
	var expected := FLIPBOOKS[weapon_id] as Dictionary
	var sprite := instance.get_node_or_null(str(expected["node"])) as AnimatedSprite2D
	_expect(sprite != null, "%s must expose its exact flipbook node" % weapon_id, errors)
	if sprite == null:
		return
	var frames := sprite.sprite_frames
	var animation := expected["animation"] as StringName
	_expect(frames != null and frames.resource_path == str(expected["path"]), "%s must bind its admitted SpriteFrames" % weapon_id, errors)
	_expect(sprite.animation == animation, "%s must bind its admitted animation identity" % weapon_id, errors)
	if frames != null:
		_expect(frames.get_frame_count(animation) == 9, "%s flipbook must expose all nine frames" % weapon_id, errors)
		_expect(not frames.get_animation_loop(animation), "%s flipbook must not loop through a seam" % weapon_id, errors)
		var texture_paths := {}
		for frame in 9:
			var texture := frames.get_frame_texture(animation, frame)
			_expect(texture != null and texture.get_size() == Vector2(256, 256), "%s frame %d must be a visible 256x256 texture" % [weapon_id, frame], errors)
			if texture != null:
				texture_paths[texture.resource_path] = true
		_expect(texture_paths.size() == 9, "%s flipbook frames must be distinct and non-empty" % weapon_id, errors)
	if timeline != null and timeline.has_animation(&"ultimate"):
		timeline.stop()
		timeline.play(&"ultimate")
		for frame in 9:
			timeline.seek(float((expected["times"] as Array)[frame]), true)
			_expect(sprite.frame == frame, "%s timeline must reach frame %d at its authored beat" % [weapon_id, frame], errors)
	var pending: Array[Node] = [instance]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child in node.get_children():
			pending.append(child)
			_expect(not (child is ColorRect or child is Polygon2D or child is Line2D), "%s must not retain flat-geometry stand-in %s" % [weapon_id, child.name], errors)
	var flipbook := ((package.get("channels", {}) as Dictionary).get("flipbook", {}) as Dictionary)
	_expect("res://%s" % str(flipbook.get("spriteframes", "")) == str(expected["path"]), "%s manifest must pin its SpriteFrames path" % weapon_id, errors)
	_expect(StringName(str(flipbook.get("animation", ""))) == animation, "%s manifest must pin its animation identity" % weapon_id, errors)
	var frame_size := flipbook.get("frame_size", []) as Array
	_expect(int(flipbook.get("frame_count", 0)) == 9 and frame_size.size() == 2 \
			and int(frame_size[0]) == 256 and int(frame_size[1]) == 256,
		"%s manifest must pin nine 256x256 frames" % weapon_id, errors)


## The authored scene is the guitarist trio's only live effect channel
## (beat_routing_gate_test PRESENTATION_ONLY_PAIRS): every damaging beat routes
## its actually affected victims through present(), and the scene plays the
## shared bounded per-victim impact for exactly those enemies.
func _check_weapon_local_impacts(errors: Array[String]) -> void:
	for weapon_id in WEAPON_IDS:
		var expected := FLIPBOOKS[weapon_id] as Dictionary
		var scene := (SCENES[weapon_id] as PackedScene).instantiate() as Node2D
		root.add_child(scene)
		scene.call("present", "%s.probe" % weapon_id, {"shape": "ring_pulse", "radius": 240.0})
		_expect(_impact_player(scene) == null, "%s victimless beat must not start a victim impact" % weapon_id, errors)
		var victims: Array = []
		for index in IMPACT_CROWD:
			var victim := VictimProbe.new()
			victim.position = Vector2(40.0 + float(index) * 8.0, float(index % 3) * 18.0)
			root.add_child(victim)
			victims.append(victim)
		for beat in expected["beats"] as Array:
			scene.call("present", str(beat), {"shape": "ring_pulse", "radius": 240.0, "victims": victims})
		var impacts := _impact_player(scene)
		_expect(impacts != null, "%s must start the shared weapon-local victim impact" % weapon_id, errors)
		if impacts != null:
			var planned := impacts.call("snapshot") as Dictionary
			_expect(int(planned.get("victims", 0)) == victims.size() * 2, "%s must enqueue each affected enemy once per damaging beat" % weapon_id, errors)
			_expect(bool(planned.get("degraded", false)), "%s must use the bounded crowd variant above 38 victims" % weapon_id, errors)
			_expect(float(planned.get("burst_seconds", 0.0)) >= 0.3 and float(planned.get("burst_seconds", 0.0)) <= 0.6, "%s victim impact must last 0.3-0.6 seconds" % weapon_id, errors)
			_expect(int(planned.get("stagger_frames", 0)) >= ImpactPlayer.STAGGER_MIN_FRAMES and int(planned.get("stagger_frames", 0)) <= ImpactPlayer.STAGGER_MAX_FRAMES, "%s victim ripple must stagger outward by 3-8 frames" % weapon_id, errors)
			impacts.call("advance", 10.0)
			var played := impacts.call("snapshot") as Dictionary
			_expect(int(played.get("flashes", 0)) == victims.size() * 2, "%s degradation must never drop the existing white victim flash" % weapon_id, errors)
			_expect(int(played.get("created_nodes", 0)) <= ImpactPlayer.POOL_CAP, "%s burst node creation must stay inside the pool cap" % weapon_id, errors)
			var burst := impacts.find_child("VictimImpact0", true, false) as AnimatedSprite2D
			_expect(burst != null and burst.sprite_frames != null and burst.sprite_frames.resource_path == str(expected["path"]), "%s victim impact must use its own integrated flipbook" % weapon_id, errors)
			scene.call("finish", "cancel")
			var cleaned := impacts.call("snapshot") as Dictionary
			_expect(int(cleaned.get("active", 0)) == 0 and int(cleaned.get("pending", 0)) == 0 and int(cleaned.get("pooled", 0)) == 0, "%s cancel must release every burst deterministically" % weapon_id, errors)
		scene.queue_free()
		for victim in victims:
			(victim as Node).queue_free()


func _impact_player(scene: Node) -> Node:
	for child in scene.get_children():
		if child.get_script() == ImpactPlayer:
			return child
	return null


func _check_lifecycle(weapon_id: String, timing: Dictionary, phase_ids: Dictionary, errors: Array[String]) -> void:
	var phases: Array[Dictionary] = []
	for phase_name in REQUIRED_PHASES:
		phases.append({"name": phase_name, "phase_id": str(phase_ids.get(phase_name, ""))})
	var fixture := {"timing": timing, "phases": phases}
	var timeline = TIMELINE.new(fixture, 0)
	timeline.begin(_handles())
	timeline.advance(0.3)
	var paused_time := timeline.elapsed_seconds()
	timeline.set_paused(true)
	timeline.advance(1.0)
	_expect(is_equal_approx(timeline.elapsed_seconds(), paused_time), "%s pause must freeze the presentation timeline" % weapon_id, errors)
	timeline.set_paused(false)
	for reason in ["cancel", "death", "node_end"]:
		var cleanup = TIMELINE.new(fixture, 0)
		var handles := _handles()
		cleanup.begin(handles)
		cleanup.finish(reason)
		_expect(cleanup.active_handle_count() == 0, "%s %s cleanup must release all handles" % [weapon_id, reason], errors)
		for handle in handles.values():
			_expect((handle as HandleProbe).released == 1, "%s %s must release each handle once" % [weapon_id, reason], errors)
	var headless = TIMELINE.new(fixture, 1)
	var snapshot := headless.begin(_handles()) as Dictionary
	_expect(str(snapshot.get("state", "")) == TIMELINE.HEADLESS_STATE, "%s headless timeline must no-op" % weapon_id, errors)
	_expect(int(snapshot.get("active_handle_count", -1)) == 0, "%s headless timeline must attach no handles" % weapon_id, errors)


func _check_distinction(packages: Dictionary, errors: Array[String]) -> void:
	for field in ["silhouette", "motion_path", "impact_language", "timing_seconds"]:
		var values := {}
		for weapon_id in WEAPON_IDS:
			values[str((packages.get(weapon_id, {}) as Dictionary).get(field, ""))] = true
		_expect(values.size() == WEAPON_IDS.size() and not values.has(""), "all Guitarist weapons must have unique %s" % field, errors)
	var flipbook_paths := {}
	var flipbook_animations := {}
	for weapon_id in WEAPON_IDS:
		var expected := FLIPBOOKS[weapon_id] as Dictionary
		flipbook_paths[str(expected["path"])] = true
		flipbook_animations[expected["animation"]] = true
	_expect(flipbook_paths.size() == WEAPON_IDS.size(), "all Guitarist weapons must bind distinct flipbook packs", errors)
	_expect(flipbook_animations.size() == WEAPON_IDS.size(), "all Guitarist weapons must bind distinct flipbook animations", errors)


func _check_capture_text(errors: Array[String]) -> void:
	for raw_capture in CAPTURES:
		var capture := raw_capture as Dictionary
		var size := capture.get("size", Vector2i.ZERO) as Vector2i
		var sheet_zone := Rect2(Vector2.ZERO, Vector2(size)).grow(-SHEET_TEXT_MARGIN)
		_expect(sheet_zone.encloses(sheet_title_rect(size)), "%s sheet title must stay inside the measured sheet zone" % str(capture.get("name", "")), errors)
		_expect(sheet_title_font_size(size) >= 18 and panel_label_font_size(size) >= 12, "%s typography must remain readable" % str(capture.get("name", "")), errors)
		for raw_pack in PACKS:
			var pack := raw_pack as Dictionary
			_expect(panel_rect(size, pack).grow(-4.0).encloses(panel_label_rect(size, pack)), "%s label must stay inside its panel" % str(pack.get("weapon_id", "")), errors)


static func sheet_title_font_size(size: Vector2i) -> int:
	return maxi(18, int(size.y * SHEET_TITLE_FONT_RATIO))


static func sheet_title_rect(size: Vector2i) -> Rect2:
	var text_size := ThemeDB.fallback_font.get_string_size(SHEET_TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, sheet_title_font_size(size))
	return Rect2(Vector2((float(size.x) - text_size.x) * 0.5, float(size.y) * SHEET_TITLE_Y_RATIO), text_size)


static func panel_center(size: Vector2i, pack: Dictionary) -> Vector2:
	return Vector2(size) * (pack.get("position", Vector2.ZERO) as Vector2)


static func panel_rect(size: Vector2i, pack: Dictionary) -> Rect2:
	var half_size := Vector2(float(size.x) * PANEL_HALF_WIDTH_RATIO, float(size.y) * PANEL_HALF_HEIGHT_RATIO)
	return Rect2(panel_center(size, pack) - half_size, half_size * 2.0)


static func panel_label_font_size(size: Vector2i) -> int:
	return maxi(10, int(size.y * PANEL_LABEL_FONT_RATIO))


static func panel_label_rect(size: Vector2i, pack: Dictionary) -> Rect2:
	var text_size := ThemeDB.fallback_font.get_string_size(str(pack.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, panel_label_font_size(size))
	var panel := panel_rect(size, pack)
	return Rect2(Vector2(panel.position.x + 8.0, panel_center(size, pack).y + float(size.y) * PANEL_LABEL_Y_RATIO), text_size)


func _pack_for(weapon_id: String) -> Dictionary:
	for raw_pack in PACKS:
		var pack := raw_pack as Dictionary
		if str(pack.get("weapon_id", "")) == weapon_id:
			return pack
	return {}


func _visual_node_count(root_node: Node) -> int:
	var count := 0
	var pending: Array[Node] = [root_node]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		for child in current.get_children():
			pending.append(child)
			if child is CanvasItem:
				count += 1
	return count


func _profiles_by_weapon(data: Dictionary) -> Dictionary:
	var result := {}
	for raw_profile in data.get("profiles", []) as Array:
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


func _load_json(path: String, errors: Array[String]) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("missing JSON: %s" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		errors.append("invalid JSON: %s" % path)
		return {}
	return parsed as Dictionary


func _handles() -> Dictionary:
	return {"animation": HandleProbe.new(), "vfx": HandleProbe.new(), "sfx": HandleProbe.new()}


func _expect(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)


func _finish(errors: Array[String]) -> void:
	for error in errors:
		push_error("Guitarist ultimate timeline: %s" % error)
	quit(1)
