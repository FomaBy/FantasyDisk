extends RefCounted

const PROFILE_ID := "weapon_ultimate.profile.engineer.engineer_sentry_wrench"
const EXECUTOR_ID := "weapon_ultimate.executor.engineer.engineer_sentry_wrench"
const SELF_PATH := "res://scripts/ultimates/classes/engineer/engineer_sentry_wrench.gd"
const DEVICE_SCENE := preload(
	"res://scripts/ultimates/classes/engineer/temporary_engineer_device.tscn"
)
const DEVICE_TEXTURE := preload(
	"res://assets/sprites/effects/ultimates/engineer/engineer_sentry_pylon.png"
)


static func parameter_contract() -> Dictionary:
	return {
		"formation_radius": {"type": "number", "minimum": 1.0},
		"duration": {"type": "number", "minimum": 0.1},
		"volley_count": {"type": "integer", "minimum": 1},
		"volley_interval": {"type": "number", "minimum": 0.01},
		"corridor_half_width": {"type": "number", "minimum": 1.0},
		"damage": {"type": "number", "minimum": 0.0},
		"target_limit": {"type": "integer", "minimum": 0},
	}


static func execute(activation) -> float:
	var devices: Array[Node] = activation.deploy_temporary(DEVICE_SCENE, {}, 6)
	if devices.size() != 6:
		return 0.0
	var points: PackedVector2Array = activation.pattern_points(activation.origin(), "ring", {
		"count": 6,
		"radius": activation.param_float("formation_radius", 210.0),
		"rotation_degrees": 0.0,
		"arc_degrees": 360.0,
	})
	decorate_and_place(devices, points)
	activation.present(EXECUTOR_ID + ".deploy", {
		"position": activation.origin(),
		"radius": activation.param_float("formation_radius", 210.0),
		"shape": "ring_pulse",
	})
	fire_volley(activation, points, 0)
	var tween = activation.track_tween()
	if tween == null:
		return 0.0
	var interval: float = activation.param_float("volley_interval", 0.55)
	var volley_count: int = activation.param_int("volley_count", 8)
	var script := load(SELF_PATH)
	for volley in range(1, volley_count):
		tween.tween_interval(interval)
		tween.tween_callback(Callable(script, "fire_volley").bind(activation, points, volley))
	var duration: float = activation.param_float("duration", 4.6)
	var elapsed: float = interval * float(maxi(volley_count - 1, 0))
	if duration > elapsed:
		tween.tween_interval(duration - elapsed)
	return maxf(duration, elapsed)


static func fire_volley(activation, points: PackedVector2Array, volley: int) -> void:
	if activation == null or activation.is_finished() or points.size() != 6:
		return
	var damage: float = activation.scaled_damage("damage", 0.55)
	for chord in 3:
		var start := points[chord]
		var finish := points[chord + 3]
		var direction := (finish - start).normalized()
		for raw_target in activation.targets_in_corridor(
			start,
			direction,
			start.distance_to(finish),
			activation.param_float("corridor_half_width", 76.0),
			activation.param_int("target_limit", 0)
		):
			var target := raw_target as Node
			if target != null and is_instance_valid(target):
				activation.deal_damage(
					target,
					damage,
					{"source": "engineer_hex_crossfire"},
					"sentry:%d:%d" % [volley, chord]
				)
		activation.present(EXECUTOR_ID + ".volley", {
			"from": start,
			"to": finish,
			"position": finish,
			"shape": "beam",
		})


static func decorate_and_place(devices: Array[Node], points: PackedVector2Array) -> void:
	for index in mini(devices.size(), points.size()):
		var device := devices[index] as Node2D
		if device == null or not is_instance_valid(device):
			continue
		device.global_position = points[index]
		device.set_meta("engineer_ultimate_device", "sentry")
		var sprite := Sprite2D.new()
		sprite.texture = DEVICE_TEXTURE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2.ONE * 0.34
		sprite.modulate.a = 0.88
		device.add_child(sprite)
