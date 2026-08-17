extends RefCounted

const PROFILE_ID := "weapon_ultimate.profile.engineer.engineer_repair_drone"
const EXECUTOR_ID := "weapon_ultimate.executor.engineer.engineer_repair_drone"
const SELF_PATH := "res://scripts/ultimates/classes/engineer/engineer_repair_drone.gd"
const DEVICE_SCENE := preload(
	"res://scripts/ultimates/classes/engineer/temporary_engineer_device.tscn"
)
const DEVICE_TEXTURE := preload(
	"res://assets/sprites/effects/ultimates/engineer/engineer_repair_microdrone.png"
)


static func parameter_contract() -> Dictionary:
	return {
		"drone_count": {"type": "integer", "minimum": 1, "maximum": 16},
		"formation_radius": {"type": "number", "minimum": 1.0},
		"wave_count": {"type": "integer", "minimum": 1},
		"wave_interval": {"type": "number", "minimum": 0.01},
		"radius": {"type": "number", "minimum": 1.0},
		"intercept_target_cap": {"type": "integer", "minimum": 1},
		"ram_damage": {"type": "number", "minimum": 0.0},
		"knockback": {"type": "number", "minimum": 0.0},
		"repair_total": {"type": "number", "minimum": 0.0},
		"repair_pulse": {"type": "number", "minimum": 0.0},
		"final_pulse_at": {"type": "number", "minimum": 0.0},
		"shield": {"type": "number", "minimum": 0.0},
		"shield_duration": {"type": "number", "minimum": 0.1},
		"epic_displacement": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"boss_displacement": {"type": "number", "minimum": 0.0, "maximum": 1.0},
	}


static func execute(activation) -> float:
	var drone_count: int = activation.param_int("drone_count", 12)
	var devices: Array[Node] = activation.deploy_temporary(DEVICE_SCENE, {}, drone_count)
	if devices.size() != drone_count:
		return 0.0
	var formation_radius: float = activation.param_float("formation_radius", 150.0)
	decorate_and_place(devices, ring_points(activation.origin(), drone_count, formation_radius))
	if not activation.configure_repair(activation.scaled_damage("repair_total", 8.0)):
		return 0.0
	if not activation.set_control_resistance_policy({
		"normal": {
			"displacement_multiplier": 1.0, "duration_multiplier": 1.0,
			"allow_movement_lock": false, "allow_execute": false,
		},
		"epic": {
			"displacement_multiplier": activation.param_float("epic_displacement", 0.35),
			"duration_multiplier": 0.35, "allow_movement_lock": false, "allow_execute": false,
		},
		"boss": {
			"displacement_multiplier": activation.param_float("boss_displacement", 0.10),
			"duration_multiplier": 0.10, "allow_movement_lock": false, "allow_execute": false,
		},
	}):
		return 0.0
	ram_wave(activation, devices, 0)
	var tween = activation.track_tween()
	if tween == null:
		return 0.0
	var script := load(SELF_PATH)
	var interval: float = activation.param_float("wave_interval", 0.55)
	var wave_count: int = activation.param_int("wave_count", 6)
	for wave in range(1, wave_count):
		tween.tween_interval(interval)
		tween.tween_callback(Callable(script, "ram_wave").bind(activation, devices, wave))
	var elapsed: float = interval * float(maxi(wave_count - 1, 0))
	var final_at: float = maxf(activation.param_float("final_pulse_at", 4.3), elapsed)
	if final_at > elapsed:
		tween.tween_interval(final_at - elapsed)
	tween.tween_callback(Callable(script, "shield_pulse").bind(activation))
	var shield_duration: float = activation.param_float("shield_duration", 1.2)
	tween.tween_interval(shield_duration)
	return final_at + shield_duration


static func ram_wave(activation, devices: Array[Node], wave: int) -> void:
	if activation == null or activation.is_finished():
		return
	var center: Vector2 = activation.origin()
	var selected: Array = activation.select_targets(
		center,
		activation.param_float("radius", 430.0),
		activation.param_int("intercept_target_cap", 4),
		"nearest"
	)
	for raw_target in selected:
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var direction: Vector2 = target.global_position - center
		if direction.length_squared() <= 0.001:
			direction = Vector2.RIGHT
		activation.apply_control(
			target,
			direction.normalized() * activation.param_float("knockback", 260.0),
			"",
			{}
		)
		activation.deal_damage(
			target,
			activation.scaled_damage("ram_damage", 0.65),
			{"source": "engineer_microdrone_ram"},
			"drone_ram:%d" % wave
		)
	var repair_amount: float = activation.scaled_damage("repair_pulse", 1.0)
	for target in repair_targets(activation):
		activation.repair(target, repair_amount, "drone_repair:%d" % wave)
	var points := ring_points(
		center,
		devices.size(),
		activation.param_float("formation_radius", 150.0),
		float(wave) * 0.37
	)
	place(devices, points)


static func shield_pulse(activation) -> void:
	if activation == null or activation.is_finished():
		return
	activation.apply_modifier("absorb_flat", activation.scaled_damage("shield", 5.0), "add")
	activation.present(EXECUTOR_ID + ".shield", {
		"position": activation.origin(),
		"radius": activation.param_float("radius", 430.0),
		"shape": "ring_pulse",
	})


static func ring_points(
	center: Vector2, count: int, radius: float, rotation := 0.0
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in count:
		points.append(center + Vector2.RIGHT.rotated(rotation + TAU * float(index) / float(count)) * radius)
	return points


static func place(devices: Array[Node], points: PackedVector2Array) -> void:
	for index in mini(devices.size(), points.size()):
		var device := devices[index] as Node2D
		if device != null and is_instance_valid(device):
			device.global_position = points[index]


static func decorate_and_place(devices: Array[Node], points: PackedVector2Array) -> void:
	place(devices, points)
	for raw_device in devices:
		var device := raw_device as Node2D
		if device == null or not is_instance_valid(device):
			continue
		device.set_meta("engineer_ultimate_device", "microdrone")
		var sprite := Sprite2D.new()
		sprite.texture = DEVICE_TEXTURE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2.ONE * 0.42
		sprite.modulate.a = 0.88
		device.add_child(sprite)


## Target discovery is read-only. Repair mutation remains inside the accepted
## activation primitive, which owns eligibility, caps and actual-HP accounting.
static func repair_targets(activation) -> Array[Node]:
	var targets: Array[Node] = []
	var host := activation.get("host") as Node
	if host == null or not is_instance_valid(host):
		return targets
	# `player` is the Player adapter's own field, not part of the host contract, so
	# a host that stands in for the hero itself must still be offered the pulse —
	# ultimate_host_repair() is what decides eligibility, and it fails closed.
	var hero := host.get("player") as Node
	if hero == null or not is_instance_valid(hero):
		hero = host
	targets.append(hero)
	if host.has_method("ultimate_host_summons"):
		for raw_device in host.call("ultimate_host_summons", "engineer_devices") as Array:
			var device := raw_device as Node
			if device != null and is_instance_valid(device) and not targets.has(device):
				targets.append(device)
	return targets
