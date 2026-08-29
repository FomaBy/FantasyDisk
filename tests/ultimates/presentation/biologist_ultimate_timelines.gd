extends SceneTree

const PROFILE_PATH := "res://data/ultimates/schema/v1/classes/biologist.json"
const MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/biologist/manifest.json"
const TIMELINE := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_timeline.gd")
const V2_SCHEMA := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_schema.gd")
const VISUAL_CONTRACT := preload("res://scripts/ultimates/presentation/ultimate_visual_direction_contract.gd")
const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")
const WEAPON_IDS := ["biologist_spore_lens", "biologist_sample_injector", "biologist_symbiote_seed"]
const SCENES := {
	"biologist_spore_lens": preload("res://scenes/vfx/ultimates/biologist/BiologistSporeLensWorldMycelium.tscn"),
	"biologist_sample_injector": preload("res://scenes/vfx/ultimates/biologist/BiologistSampleInjectorPerfectSample.tscn"),
	"biologist_symbiote_seed": preload("res://scenes/vfx/ultimates/biologist/BiologistSymbioteSeedMatriarch.tscn"),
}
const FLIPBOOKS := {
	"biologist_spore_lens": {
		"node": "Mycelium",
		"path": "res://assets/sprites/effects/biologist/spore_lens/spore_lens_spriteframes.tres",
		"animation": &"biologist_spore_lens_ultimate",
		"times": [0.0, 0.4, 0.8, 1.1, 1.5, 1.95, 2.4, 2.8, 3.1],
		"beats": [
			"weapon_ultimate.executor.biologist.biologist_spore_lens.propagate:0",
			"weapon_ultimate.executor.biologist.biologist_spore_lens.propagate:2",
		],
	},
	"biologist_sample_injector": {
		"node": "PerfectSample",
		"path": "res://assets/sprites/effects/biologist/sample_injector/sample_injector_spriteframes.tres",
		"animation": &"biologist_sample_injector_ultimate",
		"times": [0.0, 0.35, 0.7, 1.0, 1.3, 1.65, 2.05, 2.5, 2.75],
		"beats": [
			"weapon_ultimate.executor.biologist.biologist_sample_injector.extract",
			"weapon_ultimate.executor.biologist.biologist_sample_injector.analysis:0",
		],
	},
	"biologist_symbiote_seed": {
		"node": "Matriarch",
		"path": "res://assets/sprites/effects/biologist/symbiote_seed/symbiote_seed_spriteframes.tres",
		"animation": &"biologist_symbiote_seed_ultimate",
		"times": [0.0, 0.45, 0.9, 1.3, 1.75, 2.2, 2.7, 3.2, 3.5],
		"beats": [
			"weapon_ultimate.executor.biologist.biologist_symbiote_seed.pull",
			"weapon_ultimate.executor.biologist.biologist_symbiote_seed.hatch",
		],
	},
}
const PACKS := [
	{"weapon_id": "biologist_spore_lens", "scene": SCENES["biologist_spore_lens"], "time": 1.8, "position": Vector2(0.18, 0.55), "title": "SPORE LENS — WORLD MYCELIUM", "color": Color(0.68, 1.0, 0.52), "required_nodes": ["Mycelium"]},
	{"weapon_id": "biologist_sample_injector", "scene": SCENES["biologist_sample_injector"], "time": 1.6, "position": Vector2(0.50, 0.55), "title": "SAMPLE INJECTOR — PERFECT SAMPLE", "color": Color(0.55, 1.0, 0.86), "required_nodes": ["PerfectSample"]},
	{"weapon_id": "biologist_symbiote_seed", "scene": SCENES["biologist_symbiote_seed"], "time": 2.0, "position": Vector2(0.82, 0.55), "title": "SYMBIOTE SEED — SYMBIONT MATRIARCH", "color": Color(1.0, 0.48, 0.92), "required_nodes": ["Matriarch"]},
]
const CAPTURES := [
	{"name": "648p", "path": "res://docs/design/references/weapon_ultimates/biologist/biologist_ultimate_timelines_648p.png", "size": Vector2i(1152, 648)},
	{"name": "720p", "path": "res://docs/design/references/weapon_ultimates/biologist/biologist_ultimate_timelines_720p.png", "size": Vector2i(1280, 720)},
	{"name": "1080p", "path": "res://docs/design/references/weapon_ultimates/biologist/biologist_ultimate_timelines_1080p.png", "size": Vector2i(1920, 1080)},
	{"name": "2k", "path": "res://docs/design/references/weapon_ultimates/biologist/biologist_ultimate_timelines_2k.png", "size": Vector2i(2560, 1440)},
]
const REQUIRED_PHASES := ["windup", "release", "active", "recovery", "cancel"]
const PHASE_BINDINGS := {"windup": "windup", "release": "execute", "active": "active", "recovery": "recover", "cancel": "cleanup"}
const SHEET_TITLE := "BIOLOGIST WEAPON ULTIMATES — DISTINCT PRESENTATION TIMELINES"
const SHEET_TITLE_Y_RATIO := 0.075
const SHEET_TITLE_FONT_RATIO := 0.036
const SHEET_TEXT_MARGIN := 8.0
const PANEL_HALF_WIDTH_RATIO := 0.145
const PANEL_HALF_HEIGHT_RATIO := 0.30
const PANEL_LABEL_Y_RATIO := 0.245
const PANEL_LABEL_FONT_RATIO := 0.021
const MAX_TIMELINE_SECONDS := 10.0
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
	_expect(str(manifest.get("class_id", "")) == "biologist", "manifest must be class-local to Biologist", errors)
	var contract := manifest.get("contract", {}) as Dictionary
	_expect(str(contract.get("headless_fallback", "")) == "no_op", "manifest must declare no_op headless fallback", errors)
	_expect(float(contract.get("max_timeline_seconds", 0.0)) == MAX_TIMELINE_SECONDS, "manifest must retain the ten-second cap", errors)
	_expect(not str(contract.get("runtime_adapter_status", "")).is_empty(), "runtime adapter boundary must be documented", errors)
	_check_provenance(manifest, errors)
	var packages := _packages_by_weapon(manifest)
	_check_v2_ratchets(errors)
	_expect(packages.size() == WEAPON_IDS.size(), "manifest must contain exactly three Biologist packages", errors)
	for weapon_id in WEAPON_IDS:
		_check_package(weapon_id, profiles.get(weapon_id, {}) as Dictionary, packages.get(weapon_id, {}) as Dictionary, errors)
	_check_distinction(packages, errors)
	_check_timing_distinctness(packages, errors)
	_check_weapon_local_impacts(errors)
	_check_capture_text(errors)
	_check_capture_evidence(errors)
	if not errors.is_empty():
		_finish(errors)
		return
	print("Biologist ultimate timelines passed (three exact flipbooks, frozen phases, per-victim beat impacts, lifecycle, and crowd budgets).")
	quit(0)


func _check_provenance(manifest: Dictionary, errors: Array[String]) -> void:
	var provenance := manifest.get("generator_provenance", {}) as Dictionary
	_expect(str(provenance.get("route", "")) == "integrated_approved_pixellab_animation_frames", "provenance route must identify the admitted PixelLab animation packs", errors)
	var assets := provenance.get("new_pixellab_assets", []) as Array
	_expect(assets == WEAPON_IDS, "provenance must list exactly the three admitted Biologist packs", errors)
	_expect(str(provenance.get("integrated_art_candidate", "")) == "9fe188e08990c81b527630dd374f64dd8106115c", "provenance must pin the accepted art candidate", errors)
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
		_expect(timestamp >= previous and timestamp <= MAX_TIMELINE_SECONDS, "%s %s timing must be monotonic and capped" % [weapon_id, phase_name], errors)
		previous = timestamp
		var frozen_phase := str((profile.get("cast_phases", {}) as Dictionary).get(str(PHASE_BINDINGS[phase_name]), ""))
		_expect(str(phases.get(phase_name, "")) == frozen_phase, "%s %s must bind the frozen cast phase" % [weapon_id, phase_name], errors)
	_check_scene(weapon_id, package, errors)
	_check_v2_package(weapon_id, package, errors)
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
		_expect(timeline.process_mode == Node.PROCESS_MODE_INHERIT, "%s AnimationPlayer must inherit pause state" % weapon_id, errors)
		var sample := _pack_for(weapon_id)
		timeline.stop()
		timeline.play(&"ultimate")
		timeline.seek(float(sample.get("time", 0.0)), true)
		for node_path in sample.get("required_nodes", []) as Array:
			var item := instance.get_node_or_null(str(node_path)) as CanvasItem
			_expect(item != null and item.visible and item.modulate.a * item.self_modulate.a > 0.01, "%s required visual node must be visible: %s" % [weapon_id, node_path], errors)
	_expect(str(instance.get_meta("ultimate_id", "")) == "biologist/%s" % weapon_id, "%s scene must retain its exact profile key" % weapon_id, errors)
	for field in ["silhouette", "motion_path", "impact_language"]:
		_expect(str(instance.get_meta(field, "")) == str(package.get(field, "")), "%s scene %s must match manifest" % [weapon_id, field], errors)
	var performance := package.get("performance", {}) as Dictionary
	_expect(int(instance.get_meta("max_visual_nodes", 0)) == int(performance.get("max_visual_nodes", -1)), "%s visual-node budget must match manifest" % weapon_id, errors)
	_expect(int(instance.get_meta("crowd_cap", 0)) == int(performance.get("crowd_cap", -1)), "%s crowd cap must match manifest" % weapon_id, errors)
	for material_key in ["max_unique_materials", "max_fullscreen_materials"]:
		_expect(int(instance.get_meta(material_key, 0)) == int(performance.get(material_key, -1)),
			"%s scene %s must match manifest" % [weapon_id, material_key], errors)
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


## The authored scene is the Biologist trio's live visual channel: every
## damaging/control beat routes its actually affected victims through
## present(), and the scene plays the shared bounded per-victim impact for
## exactly those enemies.
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


func _check_v2_package(weapon_id: String, package: Dictionary, errors: Array[String]) -> void:
	var key := "biologist/%s" % weapon_id
	_expect(V2_SCHEMA.v2_envelope_errors(package.get("timing_seconds", {}), key).is_empty(),
		"%s must stay inside the 2.5-4.0s v2 envelope" % weapon_id, errors)
	var pivot := package.get("pivot", {}) as Dictionary
	_expect(float(pivot.get("x", -1.0)) >= 0.0 and float(pivot.get("x", 2.0)) <= 1.0, "%s pivot x must be normalized" % weapon_id, errors)
	_expect(float(pivot.get("y", -1.0)) >= 0.0 and float(pivot.get("y", 2.0)) <= 1.0, "%s pivot y must be normalized" % weapon_id, errors)
	var presence := package.get("presence", {}) as Dictionary
	_expect(presence.get("fullscreen_footprint") == true,
		"%s must declare arena-wide footprint" % weapon_id, errors)
	_expect(V2_SCHEMA.V2_BACKDROP_TREATMENTS.has(str(presence.get("backdrop", ""))),
		"%s must declare a v2 backdrop" % weapon_id, errors)
	_expect(presence.get("camera_shake") == true and presence.get("sfx_ducking") == true,
		"%s must declare camera shake and SFX ducking" % weapon_id, errors)
	var hitstop := float(presence.get("hitstop_ms", 0.0))
	_expect(hitstop >= 80.0 and hitstop <= 150.0,
		"%s first-impact hitstop must stay in 80-150ms" % weapon_id, errors)
	var identity := package.get("identity", {}) as Dictionary
	_expect(str(identity.get("cast_pose_id", "")).begins_with("cast_pose.biologist."),
		"%s must declare a Biologist cast pose" % weapon_id, errors)
	var silhouette := str(identity.get("weapon_silhouette_asset", ""))
	_expect(not silhouette.is_empty() and FileAccess.file_exists(silhouette),
		"%s central weapon silhouette must exist" % weapon_id, errors)
	_expect(str(identity.get("class_palette_id", "")).begins_with("palette.biologist."),
		"%s must declare a Biologist palette" % weapon_id, errors)
	var quality := package.get("quality", {}) as Dictionary
	_expect(float(quality.get("max_viewport_coverage_ratio", 1.0)) <= 0.35
		and quality.get("hud_bands_clear") == true
		and quality.get("reduced_motion_preserves_timing") == true,
		"%s must declare HUD-safe reduced-motion readability" % weapon_id, errors)


func _check_v2_ratchets(errors: Array[String]) -> void:
	for weapon_id in WEAPON_IDS:
		_expect(not V2_SCHEMA.PRESENTATION_V2_MIGRATION_ALLOWLIST.has("biologist/%s" % weapon_id),
			"%s must leave the presentation v2 allowlist" % weapon_id, errors)
	_expect(not (VISUAL_CONTRACT.ADOPTION_GAPS.get("quality", {}) as Dictionary).has("biologist"),
		"Biologist must leave the visual-quality adoption gap", errors)


func _check_timing_distinctness(packages: Dictionary, errors: Array[String]) -> void:
	var rhythms: Array[Dictionary] = []
	for weapon_id in WEAPON_IDS:
		var timing := ((packages.get(weapon_id, {}) as Dictionary).get("timing_seconds", {}) as Dictionary)
		rhythms.append({
			"weapon_id": weapon_id,
			"total": float(timing.get("cancel", 0.0)),
			"active_window": float(timing.get("recovery", 0.0)) - float(timing.get("active", 0.0)),
		})
	for first_index in range(rhythms.size() - 1):
		for second_index in range(first_index + 1, rhythms.size()):
			for axis in ["total", "active_window"]:
				_expect(absf(float(rhythms[first_index][axis]) - float(rhythms[second_index][axis])) >= 0.1 - 0.000001,
					"%s/%s %s rhythms must differ by at least 0.1s" % [
						rhythms[first_index]["weapon_id"], rhythms[second_index]["weapon_id"], axis,
					], errors)


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
		_expect(values.size() == WEAPON_IDS.size() and not values.has(""), "all Biologist weapons must have unique %s" % field, errors)
	var flipbook_paths := {}
	var flipbook_animations := {}
	for weapon_id in WEAPON_IDS:
		var expected := FLIPBOOKS[weapon_id] as Dictionary
		flipbook_paths[str(expected["path"])] = true
		flipbook_animations[expected["animation"]] = true
	_expect(flipbook_paths.size() == WEAPON_IDS.size(), "all Biologist weapons must bind distinct flipbook packs", errors)
	_expect(flipbook_animations.size() == WEAPON_IDS.size(), "all Biologist weapons must bind distinct flipbook animations", errors)


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


func _check_capture_evidence(errors: Array[String]) -> void:
	for raw_capture in CAPTURES:
		var capture := raw_capture as Dictionary
		var path := str(capture.get("path", ""))
		_expect(FileAccess.file_exists(path), "contact evidence missing: %s" % path, errors)
		if not FileAccess.file_exists(path):
			continue
		var image := Image.load_from_file(path)
		_expect(image != null and not image.is_empty(), "contact evidence must decode: %s" % path, errors)
		if image != null:
			_expect(image.get_size() == capture.get("size", Vector2i.ZERO), "contact evidence resolution mismatch: %s" % path, errors)


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
	return maxi(12, int(size.y * PANEL_LABEL_FONT_RATIO))


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
		push_error("Biologist ultimate timeline: %s" % error)
	quit(1)
