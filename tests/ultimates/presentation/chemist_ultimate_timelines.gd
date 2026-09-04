extends SceneTree

const PROFILE_PATH := "res://data/ultimates/schema/v1/classes/chemist.json"
const MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/chemist/manifest.json"
const TIMELINE := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_timeline.gd")
const V2_SCHEMA := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_schema.gd")
const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")
const WEAPON_IDS := ["blast_powder", "acid_flask", "homunculus_vial"]
const SCENES := {
	"blast_powder": preload("res://scenes/vfx/ultimates/chemist/ChemistBlastPowderPhilosophersExplosion.tscn"),
	"acid_flask": preload("res://scenes/vfx/ultimates/chemist/ChemistAcidFlaskTsarFlask.tscn"),
	"homunculus_vial": preload("res://scenes/vfx/ultimates/chemist/ChemistHomunculusVialPerfectHomunculus.tscn"),
}
const PACKS := [
	{
		"weapon_id": "blast_powder",
		"scene": SCENES["blast_powder"],
		"time": 1.45,
		"title": "BLAST POWDER — PHILOSOPHERS' EXPLOSION",
		"position": Vector2(0.18, 0.54),
		"color": Color(1.0, 0.78, 0.28),
		"required_nodes": ["BackdropVeil", "PhilosophersRitual"],
	},
	{
		"weapon_id": "acid_flask",
		"scene": SCENES["acid_flask"],
		"time": 3.3,
		"title": "ACID FLASK — TSAR LAKE",
		"position": Vector2(0.5, 0.54),
		"color": Color(0.58, 1.0, 0.34),
		"required_nodes": ["TsarFlask", "LakeRing", "ChargePillars/PillarTwo", "EvaporationSmoke"],
	},
	{
		"weapon_id": "homunculus_vial",
		"scene": SCENES["homunculus_vial"],
		# Just after the second stomp beat rather than on it: the sheet has to
		# show the arena-wide ring sweeping outward, and on the beat itself the
		# ring has only just reset to its smallest scale.
		"time": 2.85,
		"title": "HOMUNCULUS VIAL — FUSION",
		"position": Vector2(0.82, 0.54),
		"color": Color(0.48, 1.0, 0.52),
		"required_nodes": ["BackdropVeil", "FusionGlow", "AlchemicalCircle", "Avatar", "TauntHalo", "StompWave", "ToxicCascade"],
	},
]
const CAPTURES := [
	{"name": "648p", "path": "res://docs/design/references/weapon_ultimates/chemist/chemist_ultimate_timelines_648p.png", "size": Vector2i(1152, 648)},
	{"name": "720p", "path": "res://docs/design/references/weapon_ultimates/chemist/chemist_ultimate_timelines_720p.png", "size": Vector2i(1280, 720)},
	{"name": "1080p", "path": "res://docs/design/references/weapon_ultimates/chemist/chemist_ultimate_timelines_1080p.png", "size": Vector2i(1920, 1080)},
	{"name": "2k", "path": "res://docs/design/references/weapon_ultimates/chemist/chemist_ultimate_timelines_2k.png", "size": Vector2i(2560, 1440)},
]
const SHEET_TITLE := "CHEMIST WEAPON ULTIMATES — DISTINCT PRESENTATION TIMELINES"
const SHEET_TITLE_Y_RATIO := 0.075
const SHEET_TITLE_FONT_RATIO := 0.036
const SHEET_TEXT_MARGIN := 8.0
const PANEL_HALF_WIDTH_RATIO := 0.145
const PANEL_HALF_HEIGHT_RATIO := 0.30
const PANEL_CONTENT_MARGIN_RATIO := 0.03
const CAPTURE_ALPHA_EPSILON := 0.01
const REQUIRED_PHASES := ["windup", "release", "active", "recovery", "cancel"]
const MAX_TIMELINE_SECONDS := 10.0
const AVATAR_FRAME_COUNT := 9
const AVATAR_SLAM_BEATS := [1.75, 2.6, 3.45]
## Manual stepping budget for the blast_powder driver gate: one step is finer
## than every device window, and the shake window is the driver's own constant.
const DRIVER_STEP := 0.01
const DRIVER_SHAKE_WINDOW := 0.55
const DRIVER_DUCK_DB := -9.0


var _blast_package := {}
var _acid_package := {}
var _homunculus_package := {}
var _failed := false


class HandleProbe extends RefCounted:
	var released := 0

	func release() -> void:
		released += 1


## Stands in for a hit enemy: the impact service calls the victim's own white
## flash by name, so the probe answers exactly the two methods it looks for.
class VictimProbe extends Node2D:
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
	_expect(str(manifest.get("class_id", "")) == "chemist", "manifest must be class-local to Chemist", errors)
	var contract := manifest.get("contract", {}) as Dictionary
	_expect(str(contract.get("headless_fallback", "")) == "no_op", "manifest must declare no_op headless fallback", errors)
	_expect(not str(contract.get("runtime_adapter_status", "")).is_empty(), "runtime adapter boundary must be documented", errors)
	_check_provenance(manifest, errors)
	var packages := _packages_by_weapon(manifest)
	_expect(packages.size() == 3, "manifest must contain exactly three Chemist packages", errors)
	for weapon_id in WEAPON_IDS:
		_check_package(weapon_id, profiles.get(weapon_id, {}) as Dictionary, packages.get(weapon_id, {}) as Dictionary, errors)
	_check_blast_v2(packages.get("blast_powder", {}) as Dictionary, errors)
	_check_blast_primitive_budget(errors)
	_check_acid_v2(packages.get("acid_flask", {}) as Dictionary, errors)
	_check_homunculus_v2(packages.get("homunculus_vial", {}) as Dictionary, errors)
	_check_distinction(packages, errors)
	_check_capture_composition(errors)
	_check_capture_text(errors)
	_check_capture_evidence(errors)
	if not errors.is_empty():
		_finish(errors)
		return
	_blast_package = packages.get("blast_powder", {}) as Dictionary
	_acid_package = packages.get("acid_flask", {}) as Dictionary
	_homunculus_package = packages.get("homunculus_vial", {}) as Dictionary


## _initialize runs before the root window joins the tree, so nothing added
## there gets _ready, autoplay or a current camera. The driver gate needs all
## three, so it runs on the first real frame instead.
func _process(_delta: float) -> bool:
	if _failed:
		return true
	var errors: Array[String] = []
	_check_blast_driver(_blast_package, errors)
	_check_acid_driver(_acid_package, errors)
	_check_homunculus_driver(_homunculus_package, errors)
	for weapon_id in WEAPON_IDS:
		_check_victim_impacts(weapon_id, errors)
	if not errors.is_empty():
		_finish(errors)
		return true
	print("Chemist ultimate timelines passed (distinct scenes, frozen phases, lifecycle, driver devices, text fit, and evidence).")
	quit(0)
	return true


func _check_provenance(manifest: Dictionary, errors: Array[String]) -> void:
	var provenance := manifest.get("generator_provenance", {}) as Dictionary
	var route := str(provenance.get("route", ""))
	var new_assets := provenance.get("new_pixellab_assets", []) as Array
	_expect(route.contains("pixellab"), "provenance route must own the new PixelLab frames", errors)
	var pixellab_weapons := {}
	for raw_asset in new_assets:
		var asset := raw_asset as Dictionary
		var weapon_id := str(asset.get("weapon_id", ""))
		pixellab_weapons[weapon_id] = true
		var frame_count := int(asset.get("frame_count", 0))
		_expect(frame_count >= 4, "%s PixelLab animation must declare a real frame count" % weapon_id, errors)
		if weapon_id == "homunculus_vial":
			_expect(not str(asset.get("job_id", "")).is_empty() and asset.get("seed", null) != null, "the homunculus_vial PixelLab pack must record its job id and seed", errors)
			for index in AVATAR_FRAME_COUNT:
				_expect(
					FileAccess.file_exists("res://%s/avatar_stomp_%02d.png" % [str(asset.get("frames_dir", "")), index]),
					"avatar stomp frame %02d must exist" % index,
					errors
				)
			_expect(FileAccess.file_exists("res://%s" % str(asset.get("asset_manifest", ""))), "avatar pack asset manifest must exist", errors)
		else:
			_expect(not str(asset.get("pixel_lab_object_id", "")).is_empty(), "%s PixelLab object id must be recorded" % weapon_id, errors)
			_expect(not str(asset.get("pixel_lab_animation_group_id", "")).is_empty(), "%s PixelLab animation group id must be recorded" % weapon_id, errors)
			_expect(FileAccess.file_exists("res://%s" % str(asset.get("runtime_spriteframes", ""))), "%s runtime SpriteFrames must exist" % weapon_id, errors)
			_expect(FileAccess.file_exists("res://%s" % str(asset.get("runtime_scene", ""))), "%s runtime scene must exist" % weapon_id, errors)
			_expect(FileAccess.file_exists("res://%s" % str(asset.get("provenance_manifest", ""))), "%s provenance manifest must exist" % weapon_id, errors)
	for weapon_id in WEAPON_IDS:
		_expect(pixellab_weapons.has(weapon_id), "%s PixelLab pack must be declared" % weapon_id, errors)
	var sources := provenance.get("reused_sources", {}) as Dictionary
	for weapon_id in WEAPON_IDS:
		var source := sources.get(weapon_id, {}) as Dictionary
		if source.is_empty():
			continue
		_expect(FileAccess.file_exists("res://%s" % str(source.get("source_path", ""))), "%s reused source must exist" % weapon_id, errors)
		_expect(FileAccess.file_exists("res://%s" % str(source.get("runtime_scene", ""))), "%s runtime scene must exist" % weapon_id, errors)


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
		_expect(seconds >= previous and seconds <= MAX_TIMELINE_SECONDS, "%s %s timing must be monotonic and capped" % [weapon_id, phase_name], errors)
		previous = seconds
		var expected := str((profile.get("cast_phases", {}) as Dictionary).get(_cast_phase_name(phase_name), ""))
		_expect(str(phases.get(phase_name, "")) == expected, "%s %s must bind to its frozen Cast phase ID" % [weapon_id, phase_name], errors)
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
		_expect(is_equal_approx(timeline.get_animation(&"ultimate").length, float((package.get("timing_seconds", {}) as Dictionary).get("cancel", -1.0))), "%s scene animation must end at cancel" % weapon_id, errors)
		if weapon_id == "homunculus_vial":
			_check_avatar_frame_track(timeline.get_animation(&"ultimate"), errors)
	_expect(str(instance.get_meta("ultimate_id", "")) == "chemist/%s" % weapon_id, "%s scene must retain exact profile key" % weapon_id, errors)
	for field in ["silhouette", "motion_path", "impact_language"]:
		_expect(not str(instance.get_meta(field, "")).is_empty(), "%s %s declaration missing" % [weapon_id, field], errors)
	_expect(instance.get_child_count() <= int(instance.get_meta("crowd_cap", 0)), "%s visible scene nodes must stay within crowd cap" % weapon_id, errors)
	_expect(int(instance.get_meta("max_visual_nodes", 0)) <= int(instance.get_meta("crowd_cap", 0)), "%s declared visual budget must stay within crowd cap" % weapon_id, errors)
	instance.queue_free()


## The FAN-2552 avatar plays its PixelLab stomp cycle through a discrete
## texture track, and each slam frame lands exactly on a mechanics beat
## (fuse_at + beat_interval * n), so presentation and damage read as one hit.
func _check_avatar_frame_track(animation: Animation, errors: Array[String]) -> void:
	var track := animation.find_track("Avatar:texture", Animation.TYPE_VALUE)
	_expect(track != -1, "homunculus avatar must animate its stomp frames", errors)
	if track == -1:
		return
	_expect(animation.value_track_get_update_mode(track) == Animation.UPDATE_DISCRETE, "avatar frame track must switch textures discretely", errors)
	var distinct := {}
	for key_index in animation.track_get_key_count(track):
		var texture := animation.track_get_key_value(track, key_index) as Texture2D
		if texture != null:
			distinct[texture.resource_path] = true
	_expect(distinct.size() == AVATAR_FRAME_COUNT, "avatar frame track must play all %d stomp frames" % AVATAR_FRAME_COUNT, errors)
	for beat_time in AVATAR_SLAM_BEATS:
		var key := animation.track_find_key(track, float(beat_time), Animation.FIND_MODE_NEAREST)
		var on_beat := key != -1 and absf(animation.track_get_key_time(track, key) - float(beat_time)) < 0.01
		_expect(on_beat, "an avatar frame key must land on the %.2fs stomp beat" % float(beat_time), errors)


func _check_lifecycle(weapon_id: String, timing: Dictionary, phases: Dictionary, errors: Array[String]) -> void:
	var phase_entries: Array[Dictionary] = []
	for name in REQUIRED_PHASES:
		phase_entries.append({"name": name, "phase_id": str(phases.get(name, ""))})
	var fixture := {"timing": timing, "phases": phase_entries}
	var timeline = TIMELINE.new(fixture, 0)
	timeline.begin({"animation": HandleProbe.new(), "vfx": HandleProbe.new(), "sfx": HandleProbe.new()})
	timeline.advance(0.05)
	var paused_time := timeline.elapsed_seconds()
	timeline.set_paused(true)
	timeline.advance(1.0)
	_expect(is_equal_approx(timeline.elapsed_seconds(), paused_time), "%s pause must freeze elapsed timeline time" % weapon_id, errors)
	for reason in ["cancel", "death", "node_end"]:
		var cleanup_timeline = TIMELINE.new(fixture, 0)
		var handles := {"animation": HandleProbe.new(), "vfx": HandleProbe.new(), "sfx": HandleProbe.new()}
		cleanup_timeline.begin(handles)
		cleanup_timeline.finish(reason)
		_expect(cleanup_timeline.active_handle_count() == 0, "%s %s cleanup must release every handle" % [weapon_id, reason], errors)
		for handle in handles.values():
			_expect((handle as HandleProbe).released == 1, "%s %s must release each handle once" % [weapon_id, reason], errors)


## FAN-2957: the v2 presentation contract for the migrated blast_powder pair.
## The envelope itself is asserted by the shared distinctness test once the
## allowlist entry is gone; this gate owns the class-local declarations that
## make the effect full-screen and identity-bearing.
func _check_blast_v2(package: Dictionary, errors: Array[String]) -> void:
	_check_weapon_v2("blast_powder", package, errors)


func _check_blast_primitive_budget(errors: Array[String]) -> void:
	var scene := SCENES["blast_powder"].instantiate() as Node2D
	_expect(scene != null, "blast_powder scene must instantiate for its primitive budget", errors)
	if scene == null:
		return
	root.add_child(scene)
	_expect(_naked_primitive_count(scene) == 1, "blast_powder must retain only its one ratcheted backdrop primitive", errors)
	_expect(scene.get_node_or_null("BackdropVeil") is Polygon2D, "blast_powder must retain its fitted backdrop veil", errors)
	for retired_node in ["AlchemistGlow", "PentagramSigil", "GoldRadiance"]:
		_expect(scene.get_node_or_null(retired_node) == null, "blast_powder must not restore naked primitive %s" % retired_node, errors)
	scene.queue_free()


func _naked_primitive_count(node: Node) -> int:
	var count := 1 if node is Polygon2D or (node is Line2D and (node as Line2D).texture == null) else 0
	for child in node.get_children():
		count += _naked_primitive_count(child)
	return count


## FAN-2958: the same v2 contract for the migrated acid_flask pair, plus the
## pair-local proof that its own PixelLab frames are the visual core and that
## the migration ratchet entry is really gone.
func _check_acid_v2(package: Dictionary, errors: Array[String]) -> void:
	_check_weapon_v2("acid_flask", package, errors)
	_expect(
		not V2_SCHEMA.PRESENTATION_V2_MIGRATION_ALLOWLIST.has("chemist/acid_flask"),
		"chemist/acid_flask must have left the v2 migration allowlist",
		errors
	)
	var silhouette := str((package.get("identity", {}) as Dictionary).get("weapon_silhouette_asset", ""))
	_expect(
		silhouette.contains("fan2551_acid_flask_ultimate"),
		"acid_flask weapon silhouette must be its own FAN-2551 PixelLab frame: %s" % silhouette,
		errors
	)


## FAN-2959: the same v2 contract for the migrated homunculus_vial pair. This
## pair is the one whose presentation had to shrink (5.40s -> 3.80s) to reach the
## v2 envelope while the mechanics beats stayed frozen, so on top of the shared
## gate it proves the retimed envelope still covers every stomp the executor
## deals: all three mechanics beats stay inside the active window, and the
## avatar is the visual core rather than a reusable burst.
func _check_homunculus_v2(package: Dictionary, errors: Array[String]) -> void:
	_check_weapon_v2("homunculus_vial", package, errors)
	_expect(
		not V2_SCHEMA.PRESENTATION_V2_MIGRATION_ALLOWLIST.has("chemist/homunculus_vial"),
		"chemist/homunculus_vial must have left the v2 migration allowlist",
		errors
	)
	var silhouette := str((package.get("identity", {}) as Dictionary).get("weapon_silhouette_asset", ""))
	_expect(
		silhouette.contains("ultimates/chemist/homunculus_vial"),
		"homunculus_vial weapon silhouette must be its own FAN-2552 PixelLab frame: %s" % silhouette,
		errors
	)
	# The executor keeps fuse_at/beat_interval/beat_count: shortening the drawn
	# envelope may never leave a stomp that still damages without a drawn hit.
	var timing := package.get("timing_seconds", {}) as Dictionary
	var release := float(timing.get("release", -1.0))
	var recovery := float(timing.get("recovery", -1.0))
	for beat_time in AVATAR_SLAM_BEATS:
		_expect(
			float(beat_time) >= release and float(beat_time) <= recovery,
			"mechanics stomp beat %.2fs must stay inside the drawn active window %.2f-%.2fs"
				% [float(beat_time), release, recovery],
			errors
		)


func _check_weapon_v2(weapon_id: String, package: Dictionary, errors: Array[String]) -> void:
	_expect(not package.is_empty(), "%s package must exist for the v2 gate" % weapon_id, errors)
	if package.is_empty():
		return
	var scene := SCENES[weapon_id].instantiate() as Node2D
	root.add_child(scene)
	var presence := package.get("presence", {}) as Dictionary
	_expect(presence.get("fullscreen_footprint") == true, "%s must declare a fullscreen footprint" % weapon_id, errors)
	_expect(str(presence.get("backdrop", "")) == "darken", "%s must declare the darken backdrop" % weapon_id, errors)
	_expect(presence.get("camera_shake") == true, "%s must declare camera shake" % weapon_id, errors)
	var hitstop := float(presence.get("hitstop_ms", 0.0))
	_expect(hitstop >= 80.0 and hitstop <= 150.0, "%s hitstop must stay in the 80-150ms corridor" % weapon_id, errors)
	_expect(presence.get("sfx_ducking") == true, "%s must declare SFX ducking" % weapon_id, errors)
	var identity := package.get("identity", {}) as Dictionary
	_expect(not str(identity.get("cast_pose_id", "")).is_empty(), "%s must declare its hero cast pose" % weapon_id, errors)
	var silhouette := str(identity.get("weapon_silhouette_asset", ""))
	_expect(not silhouette.is_empty() and FileAccess.file_exists(silhouette), "%s weapon silhouette asset must exist: %s" % [weapon_id, silhouette], errors)
	_expect(not str(identity.get("class_palette_id", "")).is_empty(), "%s must resolve its class palette" % weapon_id, errors)
	var performance := package.get("performance", {}) as Dictionary
	_expect(int(performance.get("max_unique_materials", 0)) > 0, "%s must declare a positive material budget" % weapon_id, errors)
	_expect(int(performance.get("max_fullscreen_materials", 0)) > 0, "%s must declare its full-screen material budget" % weapon_id, errors)
	var veil := scene.get_node_or_null("BackdropVeil") as CanvasItem
	_expect(veil != null and veil.visible, "%s must carry a backdrop veil node" % weapon_id, errors)
	if veil != null:
		_expect(bool(veil.get_meta("fullscreen_layer", false)), "the backdrop veil must be marked as the fullscreen layer", errors)
	for budget_key in ["max_unique_materials", "max_fullscreen_materials"]:
		_expect(
			int(scene.get_meta(budget_key, 0)) == int(performance.get(budget_key, -1)),
			"scene and manifest must agree on %s" % budget_key,
			errors
		)
	var timing := package.get("timing_seconds", {}) as Dictionary
	var driver := scene.get_script() as GDScript
	_expect(is_equal_approx(float(timing.get("release", -1.0)), float(driver.get_script_constant_map().get("RELEASE_AT", -1.0))), "scene driver release beat must match the manifest", errors)
	_expect(is_equal_approx(float(timing.get("active", -1.0)), float(driver.get_script_constant_map().get("IMPACT_AT", -1.0))), "scene driver impact beat must match the manifest", errors)
	_expect(is_equal_approx(float(timing.get("recovery", -1.0)), float(driver.get_script_constant_map().get("RECOVERY_AT", -1.0))), "scene driver recovery beat must match the manifest", errors)
	_expect(is_equal_approx(float(timing.get("cancel", -1.0)), float(driver.get_script_constant_map().get("CANCEL_AT", -1.0))), "scene driver cancel beat must match the manifest", errors)
	_expect(is_equal_approx(float(driver.get_script_constant_map().get("HITSTOP_MS", -1.0)), hitstop), "scene driver hitstop must match the declared presence value", errors)
	scene.queue_free()


## FAN-2987: the four driver-owned devices the manifest cannot assert, proven by
## stepping the live scene. Each one shipped broken once, so each one is gated:
## pause must not touch a property AnimationPlayer does not have, the shake must
## obey the player's setting, overlapping casts must hand the SFX bus back, and
## the envelope must end where the manifest says it does.
func _check_weapon_driver(weapon_id: String, package: Dictionary, errors: Array[String]) -> void:
	if package.is_empty():
		return
	var timing := package.get("timing_seconds", {}) as Dictionary
	_check_driver_pause(weapon_id, errors)
	_check_driver_shake_setting(weapon_id, float(timing.get("active", 1.3)), errors)
	_check_driver_sfx_overlap(weapon_id, float(timing.get("release", 0.95)), errors)
	_check_driver_envelope(weapon_id, float(timing.get("cancel", 3.6)), errors)


func _check_blast_driver(package: Dictionary, errors: Array[String]) -> void:
	_check_weapon_driver("blast_powder", package, errors)


func _check_acid_driver(package: Dictionary, errors: Array[String]) -> void:
	_check_weapon_driver("acid_flask", package, errors)


func _check_homunculus_driver(package: Dictionary, errors: Array[String]) -> void:
	_check_weapon_driver("homunculus_vial", package, errors)


func _check_driver_pause(weapon_id: String, errors: Array[String]) -> void:
	var scene := _driver_scene(weapon_id)
	var timeline := scene.get_node("Timeline") as AnimationPlayer
	_expect(timeline.is_playing(), "the %s timeline must autoplay" % weapon_id, errors)
	scene.set_paused(true)
	_expect(not timeline.is_playing(), "pause must hold the drawn timeline", errors)
	scene.set_paused(false)
	_expect(timeline.is_playing(), "unpause must resume the drawn timeline", errors)
	_release_driver_scene(scene)


## The player's screen_shake toggle is the whole gate: with it off the effect may
## not move the camera by a single pixel, exactly like enemy.gd slam shake.
func _check_driver_shake_setting(weapon_id: String, impact_at: float, errors: Array[String]) -> void:
	var camera := Camera2D.new()
	root.add_child(camera)
	camera.make_current()
	var restore: Variant = root.get_meta("screen_shake") if root.has_meta("screen_shake") else null
	for shake_enabled in [true, false]:
		root.set_meta("screen_shake", shake_enabled)
		camera.offset = Vector2.ZERO
		var scene := _driver_scene(weapon_id)
		var veil := scene.get_node("BackdropVeil") as CanvasItem
		_expect(
			is_equal_approx(veil.self_modulate.a, 1.0) == shake_enabled,
			"the declared reduced-motion fade must follow the screen_shake setting",
			errors
		)
		var peak := 0.0
		var elapsed := 0.0
		while elapsed < impact_at + DRIVER_SHAKE_WINDOW:
			scene._process(DRIVER_STEP)
			elapsed += DRIVER_STEP
			peak = maxf(peak, camera.offset.length())
		if shake_enabled:
			_expect(peak > 0.0, "the impact must shake the camera while screen_shake is on", errors)
		else:
			_expect(is_zero_approx(peak), "screen_shake off must leave the camera at 0.000 px, saw %.3f px" % peak, errors)
		_release_driver_scene(scene)
	if restore == null:
		root.remove_meta("screen_shake")
	else:
		root.set_meta("screen_shake", restore)
	root.remove_child(camera)
	camera.free()


## Two casts crossing over: the second one must not record the already-ducked
## level as the value to restore, and the earlier one finishing first must not
## strand the bus below its pre-cast volume.
func _check_driver_sfx_overlap(weapon_id: String, release_at: float, errors: Array[String]) -> void:
	var created := AudioServer.get_bus_index("SFX") == -1
	if created:
		AudioServer.add_bus(AudioServer.bus_count)
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
	var bus := AudioServer.get_bus_index("SFX")
	var before := AudioServer.get_bus_volume_db(bus)
	var first := _driver_scene(weapon_id)
	var second := _driver_scene(weapon_id)
	first._process(release_at + DRIVER_STEP)
	second._process(release_at + DRIVER_STEP)
	_expect(
		is_equal_approx(AudioServer.get_bus_volume_db(bus), before + DRIVER_DUCK_DB),
		"overlapping casts must duck the SFX bus once, saw %.2f dB" % AudioServer.get_bus_volume_db(bus),
		errors
	)
	_release_driver_scene(first)
	_release_driver_scene(second)
	_expect(
		is_equal_approx(AudioServer.get_bus_volume_db(bus), before),
		"overlapping casts must hand the SFX bus back at %.2f dB, saw %.2f dB" % [before, AudioServer.get_bus_volume_db(bus)],
		errors
	)
	if created:
		AudioServer.remove_bus(bus)


## The hitstop freeze may not be added on top of the declared envelope: the
## driver stops exactly at the manifest cancel, freeze included.
func _check_driver_envelope(weapon_id: String, cancel_at: float, errors: Array[String]) -> void:
	var scene := _driver_scene(weapon_id)
	var elapsed := 0.0
	while scene.is_processing() and elapsed < cancel_at * 2.0:
		scene._process(DRIVER_STEP)
		elapsed += DRIVER_STEP
	_expect(
		absf(elapsed - cancel_at) <= DRIVER_STEP * 2.0,
		"the driver envelope must end at the declared %.2fs cancel, ended at %.3fs" % [cancel_at, elapsed],
		errors
	)
	_release_driver_scene(scene)


func _driver_scene(weapon_id: String) -> Node2D:
	var scene := SCENES[weapon_id].instantiate() as Node2D
	root.add_child(scene)
	return scene


## queue_free() only lands at the end of the frame, long after the next check
## reads the SFX bus, so every stepped instance releases its devices explicitly.
func _release_driver_scene(scene: Node2D) -> void:
	scene.finish("node_end")
	root.remove_child(scene)
	scene.free()


## Per-victim impacts (FAN-3879). Chemist spawns no separate effect scene, so
## the v2 driver is the only live effect channel: a beat naming the enemies it
## actually hit bursts the weapon's own victim-impact pack on exactly those
## enemies, a beat naming none draws nothing at all, and the whole ripple is
## released with the scene — the runtime-contour half of the mapping this card
## wires (FAN-3879 acceptance #3/#4), on top of the source-level gate the
## roster ratchet (`ADOPTION_GAPS["victim_impact"]`) already fails closed on.
func _check_victim_impacts(weapon_id: String, errors: Array[String]) -> void:
	var scene := _driver_scene(weapon_id)
	var declared := scene.get_child_count()

	scene.present("fixture.beat", {"position": Vector2.ZERO})
	_expect(scene.get_child_count() == declared, "%s must draw no impact for a beat that hit nobody" % weapon_id, errors)

	var victims: Array[Node2D] = []
	for index in 3:
		var victim := VictimProbe.new()
		victim.global_position = Vector2(80.0 + float(index) * 120.0, 0.0)
		root.add_child(victim)
		victims.append(victim)
	scene.present("fixture.beat", {"position": Vector2.ZERO, "victims": victims})
	var impacts := _impact_player(scene)
	_expect(impacts != null, "%s must start its own victim-impact burst" % weapon_id, errors)
	if impacts != null:
		var planned := impacts.call("snapshot") as Dictionary
		_expect(int(planned.get("victims", 0)) == victims.size(), "%s must enqueue every actually affected enemy" % weapon_id, errors)
		# A later beat joins the running ripple instead of restarting it.
		scene.present("fixture.beat", {"victims": [victims[0]]})
		_expect(int((impacts.call("snapshot") as Dictionary).get("victims", 0)) == victims.size() + 1,
			"%s later beats must join the running ripple" % weapon_id, errors)
		impacts.call("advance", 1.0)
		_expect(int((impacts.call("snapshot") as Dictionary).get("flashes", 0)) == victims.size() + 1,
			"%s must keep the white victim flash on every hit enemy" % weapon_id, errors)
		var expected := "res://assets/sprites/effects/chemist/%s/victim_impact_spriteframes.tres" % weapon_id
		var burst := impacts.find_child("VictimImpact0", true, false) as AnimatedSprite2D
		_expect(burst != null and burst.sprite_frames != null and burst.sprite_frames.resource_path == expected,
			"%s victim impact must use its own integrated pack" % weapon_id, errors)
		for victim in victims:
			_expect((victim as VictimProbe).flashes > 0, "%s must burst on every affected enemy" % weapon_id, errors)

	scene.finish("node_end")
	_expect(scene.get_child_count() == declared, "%s must release every impact node with the scene" % weapon_id, errors)
	root.remove_child(scene)
	scene.free()
	for victim in victims:
		victim.free()


func _impact_player(scene: Node) -> Node:
	for child in scene.get_children():
		if child.get_script() == ImpactPlayer:
			return child
	return null


func _check_distinction(packages: Dictionary, errors: Array[String]) -> void:
	for field in ["silhouette", "motion_path", "timing_rhythm", "impact_language"]:
		var values := {}
		for weapon_id in WEAPON_IDS:
			values[str((packages.get(weapon_id, {}) as Dictionary).get(field, ""))] = true
		_expect(values.size() == 3 and not values.has(""), "all three weapons must have different %s values" % field, errors)


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
			var zone := panel_content_rect(size, pack)
			var context := "%s %s" % [str(capture.get("name", "")), str(pack.get("weapon_id", ""))]
			_expect(bounds.has_area() and zone.grow(0.5).encloses(bounds), "%s content must fit its panel" % context, errors)
			for raw_path in pack.get("required_nodes", []) as Array:
				var item := scene.get_node_or_null(str(raw_path)) as CanvasItem
				_expect(item != null and is_capture_item_visible(item, scene), "%s required item must be visible: %s" % [context, raw_path], errors)
				var is_fullscreen_layer := item != null and bool(item.get_meta("fullscreen_layer", false))
				if item != null and not is_fullscreen_layer:
					_expect(zone.grow(0.5).encloses(transformed_capture_bounds(capture_item_bounds(scene, item), scene)), "%s item must fit its panel: %s" % [context, raw_path], errors)
			scene.queue_free()


func _check_capture_text(errors: Array[String]) -> void:
	for raw_capture in CAPTURES:
		var capture := raw_capture as Dictionary
		var size := capture.get("size", Vector2i.ZERO) as Vector2i
		var sheet_zone := Rect2(Vector2.ZERO, Vector2(size)).grow(-SHEET_TEXT_MARGIN)
		_expect(sheet_zone.encloses(sheet_title_rect(size)), "%s sheet title must fit measured bounds" % str(capture.get("name", "")), errors)
		for raw_pack in PACKS:
			var pack := raw_pack as Dictionary
			_expect(panel_rect(size, pack).grow(0.5).encloses(panel_label_rect(size, pack)), "%s panel label must fit: %s" % [str(capture.get("name", "")), str(pack.get("title", ""))], errors)


func _check_capture_evidence(errors: Array[String]) -> void:
	for raw_capture in CAPTURES:
		var capture := raw_capture as Dictionary
		var path := str(capture.get("path", ""))
		_expect(FileAccess.file_exists(path), "contact evidence is missing: %s" % path, errors)
		if FileAccess.file_exists(path):
			var image := Image.load_from_file(path)
			_expect(image != null and not image.is_empty() and image.get_size() == capture.get("size", Vector2i.ZERO), "contact evidence must decode at the declared resolution: %s" % path, errors)


static func panel_center(size: Vector2i, pack: Dictionary) -> Vector2:
	return Vector2(size) * (pack["position"] as Vector2)


static func panel_rect(size: Vector2i, pack: Dictionary) -> Rect2:
	var half_size := Vector2(float(size.x) * PANEL_HALF_WIDTH_RATIO, float(size.y) * PANEL_HALF_HEIGHT_RATIO)
	return Rect2(panel_center(size, pack) - half_size, half_size * 2.0)


static func panel_content_rect(size: Vector2i, pack: Dictionary) -> Rect2:
	var panel := panel_rect(size, pack)
	var margin := float(size.y) * PANEL_CONTENT_MARGIN_RATIO
	return Rect2(panel.position + Vector2.ONE * margin, Vector2(panel.size.x - margin * 2.0, panel.size.y - margin * 2.0 - sheet_title_font_size(size)))


static func sheet_title_font_size(size: Vector2i) -> int:
	return maxi(18, int(size.y * SHEET_TITLE_FONT_RATIO))


static func sheet_title_rect(size: Vector2i) -> Rect2:
	var text_size := ThemeDB.fallback_font.get_string_size(SHEET_TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, sheet_title_font_size(size))
	return Rect2(Vector2((float(size.x) - text_size.x) * 0.5, float(size.y) * SHEET_TITLE_Y_RATIO), text_size)


static func panel_label_rect(size: Vector2i, pack: Dictionary) -> Rect2:
	var panel := panel_rect(size, pack)
	var font_size := maxi(12, int(size.y * 0.021))
	var text_size := ThemeDB.fallback_font.get_string_size(str(pack["title"]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	return Rect2(Vector2(panel.get_center().x - text_size.x * 0.5, panel.end.y - text_size.y - float(size.y) * 0.018), text_size)


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
	var zone := panel_content_rect(size, pack)
	var scale := minf(float(size.y) / 1040.0, minf(zone.size.x / bounds.size.x, zone.size.y / bounds.size.y))
	scene.scale = Vector2.ONE * scale
	scene.position = zone.get_center() - bounds.get_center() * scale
	return transformed_capture_bounds(bounds, scene)


static func capture_content_bounds(scene: Node2D) -> Rect2:
	var bounds := Rect2()
	var found := false
	var pending: Array[Node] = [scene]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child in node.get_children():
			pending.append(child)
			if child is CanvasItem and is_capture_item_visible(child as CanvasItem, scene) \
					and not bool(child.get_meta("fullscreen_layer", false)):
				var item_bounds := capture_item_bounds(scene, child as CanvasItem)
				if item_bounds.has_area():
					bounds = item_bounds if not found else bounds.merge(item_bounds)
					found = true
	return bounds


static func capture_item_bounds(scene: Node2D, item: CanvasItem) -> Rect2:
	var local_rect := Rect2()
	if item is Sprite2D:
		local_rect = (item as Sprite2D).get_rect()
	elif item is AnimatedSprite2D:
		local_rect = _animated_sprite_rect(item as AnimatedSprite2D)
	elif item is Line2D:
		local_rect = _rect_from_points((item as Line2D).points).grow((item as Line2D).width * 0.5)
	elif item is Polygon2D:
		local_rect = _rect_from_points((item as Polygon2D).polygon)
	if not local_rect.has_area():
		return Rect2()
	var transform := Transform2D.IDENTITY
	var cursor: Node = item
	while cursor != null and cursor != scene:
		if cursor is Node2D:
			transform = (cursor as Node2D).transform * transform
		cursor = cursor.get_parent()
	return _rect_from_points(PackedVector2Array([transform * local_rect.position, transform * Vector2(local_rect.end.x, local_rect.position.y), transform * local_rect.end, transform * Vector2(local_rect.position.x, local_rect.end.y)]))


static func transformed_capture_bounds(bounds: Rect2, scene: Node2D) -> Rect2:
	return Rect2(scene.position + bounds.position * scene.scale, bounds.size * scene.scale) if bounds.has_area() else Rect2()


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


static func _animated_sprite_rect(sprite: AnimatedSprite2D) -> Rect2:
	var frames := sprite.sprite_frames
	if frames == null or not frames.has_animation(sprite.animation):
		return Rect2()
	var texture := frames.get_frame_texture(sprite.animation, sprite.frame)
	if texture == null:
		return Rect2()
	var size := texture.get_size()
	return Rect2(-size * 0.5, size)


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
			result[str((raw_profile as Dictionary).get("weapon_id", ""))] = raw_profile
	return result


func _packages_by_weapon(manifest: Dictionary) -> Dictionary:
	var result := {}
	for raw_package in manifest.get("weapons", []) as Array:
		if raw_package is Dictionary:
			result[str((raw_package as Dictionary).get("weapon_id", ""))] = raw_package
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
	_failed = true
	for error in errors:
		push_error("Chemist ultimate timeline: %s" % error)
	quit(1)
