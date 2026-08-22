@tool
extends Node2D

enum Variant {
	WORLD_MYCELIUM,
	PERFECT_SAMPLE,
	SYMBIONT_MATRIARCH,
}

const LENS_VFX := preload("res://assets/sprites/effects/vfx_weapon_biologist_spore_lens.png")
const INJECTOR_VFX := preload("res://assets/sprites/effects/vfx_weapon_biologist_sample_injector.png")
const SEED_VFX := preload("res://assets/sprites/effects/vfx_weapon_biologist_symbiote_seed.png")
const LENS_WEAPON := preload("res://assets/sprites/weapons/biologist_spore_lens.png")
const INJECTOR_WEAPON := preload("res://assets/sprites/weapons/biologist_sample_injector.png")
const SEED_WEAPON := preload("res://assets/sprites/weapons/biologist_symbiote_seed.png")
const LENS_CAST_POSE := preload("res://assets/sprites/characters/full_frame/biologist/biologist_attack_primary_00.png")
const INJECTOR_CAST_POSE := preload("res://assets/sprites/characters/full_frame/biologist/biologist_attack_primary_02.png")
const SEED_CAST_POSE := preload("res://assets/sprites/characters/full_frame/biologist/biologist_attack_primary_04.png")

const PALE_GREEN := Color(0.72, 1.0, 0.68)
const MYCELIUM_GREEN := Color(0.22, 0.92, 0.48)
const SAMPLE_CYAN := Color(0.45, 1.0, 0.84)
const SAMPLE_WHITE := Color(0.94, 1.0, 0.95)
const ANALYSIS_GREEN := Color(0.3, 1.0, 0.5)
const SYMBIOTE_MAGENTA := Color(0.92, 0.2, 0.86)
const SYMBIOTE_GREEN := Color(0.22, 0.95, 0.46)
const HITSTOP_TIME_SCALE := 0.12
const SFX_DUCK_DB := -8.0

@export var variant: Variant = Variant.WORLD_MYCELIUM
@export var duration := 8.6
@export var progress := 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		if _prepared:
			_update_visuals()

var _prepared := false
var _playing := false
var _impact_triggered := false
var _owns_time_scale := false
var _ducked_bus_index := -1
var _ducked_prev_db := 0.0
var _presence_state := {}


func _ready() -> void:
	prepare()


func prepare() -> void:
	if _prepared:
		return
	_prepared = true
	_build_visuals()
	_build_timeline()
	_update_visuals()


func begin(registry, _handles: Dictionary = {}, headless_mode := -1) -> Dictionary:
	if registry == null:
		return {}
	prepare()
	_playing = true
	_impact_triggered = false
	_presence_state = {
		"impact_triggered": false,
		"camera_shake_triggered": false,
		"hitstop_ms": _hitstop_ms(),
		"cast_pose_bound": get_node_or_null("HeroCastPose") != null,
		"silhouette_bound": true,
	}
	var timeline := get_node_or_null("Timeline") as AnimationPlayer
	if timeline != null:
		timeline.play(&"ultimate")
	return {"state": "active", "headless": headless_mode == 1}


func finish(_reason := "cancel") -> Dictionary:
	_playing = false
	var timeline := get_node_or_null("Timeline") as AnimationPlayer
	if timeline != null:
		timeline.stop()
	_restore_presence()
	return {"state": "finished"}


func presence_state_for_tests() -> Dictionary:
	return _presence_state.duplicate(true)


func _build_visuals() -> void:
	_build_backdrop()
	match variant:
		Variant.WORLD_MYCELIUM:
			_build_world_mycelium()
		Variant.PERFECT_SAMPLE:
			_build_perfect_sample()
		Variant.SYMBIONT_MATRIARCH:
			_build_symbiont_matriarch()


func _build_timeline() -> void:
	var animation := Animation.new()
	animation.length = duration
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(".:progress"))
	animation.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
	animation.track_insert_key(track, 0.0, 0.0)
	animation.track_insert_key(track, duration, 1.0)
	var library := AnimationLibrary.new()
	library.add_animation(&"ultimate", animation)
	var player := AnimationPlayer.new()
	player.name = "Timeline"
	player.add_animation_library(&"", library)
	add_child(player)


func _build_world_mycelium() -> void:
	set_meta("ultimate_id", "biologist/biologist_spore_lens")
	set_meta("silhouette", "opened spore lens feeding a branching ground mycelium with three mushroom blooms")
	set_meta("motion_path", "fungal veins crawl from the lens toward three separated clusters before the network dries inward")
	set_meta("impact_language", "root flashes travel along veins, infected deaths become three capped non-recursive secondary blooms")
	set_meta("max_visual_nodes", 10)
	set_meta("crowd_cap", 18)
	set_meta("max_unique_materials", 1)
	set_meta("max_fullscreen_materials", 1)

	_cast_pose(LENS_CAST_POSE, Color(0.62, 1.0, 0.58))
	var lens := _sprite(self, "LensCore", LENS_WEAPON, Vector2(-172.0, 48.0), 0.42)
	lens.rotation = -0.45
	var spore_gate := _sprite(self, "SporeGate", LENS_VFX, Vector2(-112.0, 24.0), 0.34)
	spore_gate.modulate = PALE_GREEN
	var graph := Node2D.new()
	graph.name = "MyceliumGraph"
	add_child(graph)
	var paths := [
		PackedVector2Array([Vector2(-92, 24), Vector2(-30, 4), Vector2(34, -52), Vector2(112, -66)]),
		PackedVector2Array([Vector2(-92, 24), Vector2(-24, 30), Vector2(42, 18), Vector2(142, 4)]),
		PackedVector2Array([Vector2(-92, 24), Vector2(-28, 54), Vector2(28, 88), Vector2(104, 96)]),
	]
	for index in paths.size():
		_line(graph, ["VeinNorth", "VeinEast", "VeinSouth"][index], paths[index], 8.0 - index, MYCELIUM_GREEN.lightened(float(index) * 0.09))
	var blooms := Node2D.new()
	blooms.name = "MushroomBlooms"
	add_child(blooms)
	for index in 3:
		var bloom := _sprite(blooms, ["BloomA", "BloomB", "BloomC"][index], LENS_VFX, [Vector2(112, -66), Vector2(142, 4), Vector2(104, 96)][index], 0.18)
		bloom.modulate = [PALE_GREEN, Color(0.42, 1.0, 0.76), Color(0.84, 1.0, 0.52)][index]


func _build_perfect_sample() -> void:
	set_meta("ultimate_id", "biologist/biologist_sample_injector")
	set_meta("silhouette", "long needle rail and extraction beam ending in a rotating double DNA helix")
	set_meta("motion_path", "needle charges on a straight priority-target rail, then scan pulses revisit the sampled endpoint")
	set_meta("impact_language", "green-white extraction flash records a helix mark followed by three capped analysis pulses")
	set_meta("max_visual_nodes", 11)
	set_meta("crowd_cap", 16)
	set_meta("max_unique_materials", 1)
	set_meta("max_fullscreen_materials", 1)

	_cast_pose(INJECTOR_CAST_POSE, SAMPLE_CYAN)
	var rail := _sprite(self, "NeedleRail", INJECTOR_WEAPON, Vector2(-158.0, 54.0), 0.43)
	rail.rotation = -2.28
	_line(self, "BeamHalo", PackedVector2Array([Vector2(-92, 8), Vector2(186, 8)]), 17.0, Color(0.18, 0.95, 0.62, 0.3))
	_line(self, "ExtractionBeam", PackedVector2Array([Vector2(-92, 8), Vector2(186, 8)]), 5.0, SAMPLE_WHITE)
	var target := _sprite(self, "SampleTarget", INJECTOR_VFX, Vector2(188.0, 8.0), 0.32)
	target.modulate = SAMPLE_CYAN
	var helix := Node2D.new()
	helix.name = "DNAHelix"
	helix.position = Vector2(188.0, 8.0)
	add_child(helix)
	var strand_a := PackedVector2Array()
	var strand_b := PackedVector2Array()
	for index in 17:
		var x := -62.0 + float(index) * 7.75
		var y := sin(float(index) * PI * 0.5) * 20.0
		strand_a.append(Vector2(x, y))
		strand_b.append(Vector2(x, -y))
	_line(helix, "StrandA", strand_a, 4.0, SAMPLE_CYAN)
	_line(helix, "StrandB", strand_b, 4.0, Color(0.72, 0.42, 1.0))
	var pulses := Node2D.new()
	pulses.name = "AnalysisPulses"
	pulses.position = Vector2(188.0, 8.0)
	add_child(pulses)
	_line(pulses, "PulseA", _circle_points(58.0), 4.0, ANALYSIS_GREEN)
	_line(pulses, "PulseB", _circle_points(86.0), 3.0, Color(0.72, 0.42, 1.0))
	_line(pulses, "PulseC", _circle_points(112.0), 3.0, Color(0.82, 1.0, 0.58))


func _build_symbiont_matriarch() -> void:
	set_meta("ultimate_id", "biologist/biologist_symbiote_seed")
	set_meta("silhouette", "falling seed becomes one giant pod with six radial tendrils and orbiting larvae")
	set_meta("motion_path", "seed drops vertically, pod swells in place, tendrils snap outward, larvae orbit, membrane ruptures")
	set_meta("impact_language", "six pull-root lashes frame a larval barrage and one terminal hatch burst")
	set_meta("max_visual_nodes", 17)
	set_meta("crowd_cap", 22)
	set_meta("max_unique_materials", 1)
	set_meta("max_fullscreen_materials", 1)

	_cast_pose(SEED_CAST_POSE, Color(0.86, 0.46, 1.0))
	_sprite(self, "FallingSeed", SEED_WEAPON, Vector2(0.0, -176.0), 0.22)
	var pod := _sprite(self, "Pod", SEED_VFX, Vector2.ZERO, 0.58)
	pod.modulate = Color(1.0, 0.82, 1.0)
	var tendrils := Node2D.new()
	tendrils.name = "Tendrils"
	add_child(tendrils)
	for index in 6:
		var angle := TAU * float(index) / 6.0
		var tangent := Vector2.from_angle(angle + 0.5) * 34.0
		var end := Vector2.from_angle(angle) * 174.0
		_line(tendrils, "Tendril%d" % index, PackedVector2Array([Vector2.from_angle(angle) * 32.0, tangent, end]), 7.0, SYMBIOTE_MAGENTA.lerp(SYMBIOTE_GREEN, float(index % 2)))
	var larvae := Node2D.new()
	larvae.name = "Larvae"
	add_child(larvae)
	for index in 6:
		var larva := _sprite(larvae, "Larva%d" % index, SEED_WEAPON, Vector2.ZERO, 0.095)
		larva.modulate = Color(0.6, 1.0, 0.64)
	_line(self, "HatchBurst", _circle_points(124.0), 9.0, Color(1.0, 0.46, 0.92))


func _update_visuals() -> void:
	var backdrop := get_node_or_null("BackdropVeil") as Polygon2D
	if backdrop != null:
		backdrop.color.a = sin(progress * PI) * 0.24
	if _playing and not _impact_triggered and progress >= _impact_progress():
		_apply_first_impact()
	match variant:
		Variant.WORLD_MYCELIUM:
			_update_world_mycelium()
		Variant.PERFECT_SAMPLE:
			_update_perfect_sample()
		Variant.SYMBIONT_MATRIARCH:
			_update_symbiont_matriarch()


func _build_backdrop() -> void:
	var backdrop := Polygon2D.new()
	backdrop.name = "BackdropVeil"
	backdrop.z_index = -100
	backdrop.polygon = PackedVector2Array([
		Vector2(-2800.0, -1800.0), Vector2(2800.0, -1800.0),
		Vector2(2800.0, 1800.0), Vector2(-2800.0, 1800.0),
	])
	backdrop.color = _backdrop_color()
	backdrop.set_meta("fullscreen_layer", true)
	add_child(backdrop)


func _cast_pose(texture: Texture2D, tint: Color) -> void:
	var hero := _sprite(self, "HeroCastPose", texture, Vector2(-22.0, -58.0), 0.24)
	hero.z_index = -2
	hero.modulate = tint


func _impact_progress() -> float:
	match variant:
		Variant.WORLD_MYCELIUM:
			return 1.1 / 3.4
		Variant.PERFECT_SAMPLE:
			return 1.0 / 3.0
		Variant.SYMBIONT_MATRIARCH:
			return 1.3 / 3.8
	return 0.33


func _hitstop_ms() -> float:
	return [100.0, 120.0, 140.0][int(variant)]


func _backdrop_color() -> Color:
	match variant:
		Variant.WORLD_MYCELIUM:
			return Color(0.025, 0.08, 0.055, 0.0)
		Variant.PERFECT_SAMPLE:
			return Color(0.24, 0.62, 0.52, 0.0)
		Variant.SYMBIONT_MATRIARCH:
			return Color(0.12, 0.025, 0.14, 0.0)
	return Color(0.0, 0.0, 0.0, 0.0)


func _apply_first_impact() -> void:
	_impact_triggered = true
	_presence_state["impact_triggered"] = true
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	_shake_player_camera()
	_presence_state["camera_shake_triggered"] = true
	if Engine.time_scale >= 0.99:
		_owns_time_scale = true
		Engine.time_scale = HITSTOP_TIME_SCALE
		var timer := get_tree().create_timer(_hitstop_ms() / 1000.0, true, false, true)
		timer.timeout.connect(_restore_hitstop)
	_duck_sfx()


func _shake_player_camera() -> void:
	if not bool(get_tree().root.get_meta("screen_shake", true)):
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	var tween := camera.create_tween()
	for index in 5:
		var falloff := 1.0 - float(index) / 5.0
		tween.tween_property(camera, "offset", Vector2(6.0, -4.0) * falloff, 0.035)
		tween.tween_property(camera, "offset", Vector2(-5.0, 3.0) * falloff, 0.035)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.035)


func _duck_sfx() -> void:
	var bus_index := AudioServer.get_bus_index("SFX")
	if bus_index == -1 or _ducked_bus_index != -1:
		return
	_ducked_bus_index = bus_index
	_ducked_prev_db = AudioServer.get_bus_volume_db(bus_index)
	AudioServer.set_bus_volume_db(bus_index, _ducked_prev_db + SFX_DUCK_DB)


func _restore_hitstop() -> void:
	if _owns_time_scale:
		Engine.time_scale = 1.0
		_owns_time_scale = false


func _restore_presence() -> void:
	_restore_hitstop()
	if _ducked_bus_index != -1:
		AudioServer.set_bus_volume_db(_ducked_bus_index, _ducked_prev_db)
		_ducked_bus_index = -1


func _exit_tree() -> void:
	_restore_presence()


func _update_world_mycelium() -> void:
	var windup := _range(progress, 0.0, 0.16)
	var spread := _range(progress, 0.12, 0.36)
	var active := _range(progress, 0.30, 0.76)
	var recovery := _range(progress, 0.76, 1.0)
	var lens := get_node_or_null("LensCore") as Sprite2D
	var gate := get_node_or_null("SporeGate") as Sprite2D
	var graph := get_node_or_null("MyceliumGraph") as Node2D
	var blooms := get_node_or_null("MushroomBlooms") as Node2D
	if lens == null or gate == null or graph == null or blooms == null:
		return
	lens.scale = Vector2.ONE * (0.34 + windup * 0.12)
	lens.rotation = -0.45 + sin(progress * TAU * 2.0) * 0.08
	gate.scale = Vector2.ONE * (0.12 + windup * 0.32)
	gate.modulate.a = (0.18 + windup * 0.82) * (1.0 - recovery)
	graph.scale = Vector2(0.08 + spread * 0.92, 0.62 + spread * 0.38)
	graph.modulate = Color(0.72 + recovery * 0.18, 1.0 - recovery * 0.55, 0.68 - recovery * 0.5, spread * (1.0 - recovery * 0.65))
	for index in blooms.get_child_count():
		var bloom := blooms.get_child(index) as Sprite2D
		var reveal := _range(active, float(index) * 0.17, float(index) * 0.17 + 0.35)
		var pulse := 1.0 + sin((active * 5.0 - float(index)) * PI) * 0.14
		bloom.scale = Vector2.ONE * (0.05 + reveal * 0.25) * pulse
		bloom.modulate.a = reveal * (1.0 - recovery * 0.72)


func _update_perfect_sample() -> void:
	var charge := _range(progress, 0.0, 0.20)
	var extract := _range(progress, 0.16, 0.36)
	var analysis := _range(progress, 0.32, 0.80)
	var recovery := _range(progress, 0.80, 1.0)
	var rail := get_node_or_null("NeedleRail") as Sprite2D
	var halo := get_node_or_null("BeamHalo") as Line2D
	var beam := get_node_or_null("ExtractionBeam") as Line2D
	var target := get_node_or_null("SampleTarget") as Sprite2D
	var helix := get_node_or_null("DNAHelix") as Node2D
	var pulses := get_node_or_null("AnalysisPulses") as Node2D
	if rail == null or halo == null or beam == null or target == null or helix == null or pulses == null:
		return
	rail.position = Vector2(-168.0 + charge * 10.0, 54.0)
	rail.scale = Vector2.ONE * (0.36 + charge * 0.08)
	rail.modulate.a = 0.48 + charge * 0.52
	halo.scale.x = maxf(0.01, extract)
	beam.scale.x = maxf(0.01, extract)
	halo.modulate.a = extract * (1.0 - recovery)
	beam.modulate.a = extract * (1.0 - recovery)
	target.scale = Vector2.ONE * (0.08 + extract * 0.26)
	target.modulate.a = extract * (1.0 - recovery * 0.85)
	helix.scale = Vector2.ONE * (0.12 + analysis * 0.88)
	helix.rotation = analysis * 0.48
	helix.modulate.a = analysis * (1.0 - recovery)
	for index in pulses.get_child_count():
		var pulse := pulses.get_child(index) as Line2D
		var beat := _pulse(analysis, 0.18 + float(index) * 0.28, 0.20)
		pulse.scale = Vector2.ONE * (0.45 + beat * 0.82)
		pulse.modulate.a = beat * (1.0 - recovery)


func _update_symbiont_matriarch() -> void:
	var fall := _range(progress, 0.0, 0.18)
	var grow := _range(progress, 0.14, 0.38)
	var lash := _range(progress, 0.34, 0.56)
	var hatch := _range(progress, 0.48, 0.84)
	var recovery := _range(progress, 0.84, 1.0)
	var seed := get_node_or_null("FallingSeed") as Sprite2D
	var pod := get_node_or_null("Pod") as Sprite2D
	var tendrils := get_node_or_null("Tendrils") as Node2D
	var larvae := get_node_or_null("Larvae") as Node2D
	var burst := get_node_or_null("HatchBurst") as Line2D
	if seed == null or pod == null or tendrils == null or larvae == null or burst == null:
		return
	seed.position = Vector2(0.0, lerpf(-176.0, -8.0, fall))
	seed.rotation = fall * 2.8
	seed.modulate.a = (1.0 - _range(progress, 0.16, 0.28)) * (0.35 + fall * 0.65)
	pod.scale = Vector2(0.18 + grow * 0.48, 0.22 + grow * 0.62)
	pod.modulate.a = grow * (1.0 - recovery * 0.7)
	tendrils.scale = Vector2.ONE * maxf(0.02, lash)
	tendrils.rotation = sin(hatch * PI) * 0.08
	tendrils.modulate.a = lash * (1.0 - recovery * 0.72)
	larvae.rotation = hatch * TAU * 0.62
	larvae.modulate.a = hatch * (1.0 - recovery)
	for index in larvae.get_child_count():
		var larva := larvae.get_child(index) as Sprite2D
		var angle := TAU * float(index) / float(larvae.get_child_count()) + hatch * TAU
		var radius := 74.0 + sin(hatch * PI) * 50.0
		larva.position = Vector2.from_angle(angle) * radius
		larva.rotation = angle + PI * 0.5
		larva.scale = Vector2.ONE * (0.055 + hatch * 0.055)
	var rupture := _pulse(hatch, 0.76, 0.23)
	burst.scale = Vector2.ONE * (0.28 + rupture * 1.15)
	burst.modulate.a = rupture * (1.0 - recovery)


func _sprite(parent: Node, node_name: String, texture: Texture2D, position: Vector2, scale_factor: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = texture
	sprite.position = position
	sprite.scale = Vector2.ONE * scale_factor
	parent.add_child(sprite)
	return sprite


func _line(parent: Node, node_name: String, points: PackedVector2Array, width: float, color: Color) -> Line2D:
	var line := Line2D.new()
	line.name = node_name
	line.points = points
	line.width = width
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	parent.add_child(line)
	return line


func _circle_points(radius: float, segments := 40) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in segments + 1:
		points.append(Vector2.from_angle(TAU * float(index) / float(segments)) * radius)
	return points


func _range(value: float, start: float, end: float) -> float:
	return clampf((value - start) / maxf(end - start, 0.0001), 0.0, 1.0)


func _pulse(value: float, center: float, width: float) -> float:
	return maxf(0.0, 1.0 - absf(value - center) / maxf(width, 0.0001))
