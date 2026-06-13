extends Node2D

## Cutout rig that animates characters assembled from slices of the polished
## full-art sprites (see tools/slice_rig_cutouts.py). At rest the assembled
## parts are pixel-identical to the source art; in motion the limbs swing,
## the body bobs and leans into the movement direction, and actions (attack,
## shoot, cast, hit, death) play readable gestures.

const MANIFEST_PATH := "res://scripts/sliced_rig_manifest.gd"

const RIG_PART_ALIASES := {
	"basic": "rift_cutter",
	"shooter": "ash_marksman",
	"runner": "spark_runner",
	"bruiser": "stone_bruiser",
	"summoner": "bone_caller",
	"mage": "void_mage",
	"spitter": "venom_spitter",
	"shield": "rift_shieldbearer",
	"biter": "small_biter",
	"flying_runner": "winged_spark",
	"elite_armored": "iron_bastion",
	"elite_stalker": "night_stalker",
	"elite_poisoned": "plague_prophet",
	"elite_commander": "shard_marshal",
	"boss_warden": "rift_warden",
	"boss_disk_devourer": "disk_devourer",
}

const ACTION_STATES := ["attack", "cast", "shoot", "death"]

var source_texture: Texture2D
var profile_id := "default"
var base_scale := Vector2.ONE
var state := "idle"
var is_player_rig := false
var is_flying_rig := false
var is_elite_rig := false
var is_boss_rig := false
var facing_sign := 1.0
var animation_time := 0.0
var action_id := ""
var action_variant := ""
var action_time_left := 0.0
var action_duration := 0.001
var hit_time_left := 0.0
var status_tint := Color.WHITE

var _rig_data := {}
var _style := "humanoid"
var _attack_part_name := ""
# Куда смотрит исходный арт: +1 вправо (герои), -1 влево (мобы).
var _base_facing := 1.0
var _center := Vector2.ZERO
var _walk_blend := 0.0
var _direction_pose := Vector2.RIGHT
var _death_started := false

var is_death_ghost := false

var _pelvis: Node2D
var _figure: Node2D
var _torso: Node2D
var _shadow: Polygon2D
var _socket_mount: Node2D
var _hero_full: Sprite2D
var _parts := {}
var _part_rest := {}


func configure(texture: Texture2D, visual_scale: Vector2, new_profile_id: String, options := {}) -> void:
	source_texture = texture
	base_scale = visual_scale
	profile_id = new_profile_id
	is_player_rig = bool(options.get("is_player", false))
	is_flying_rig = bool(options.get("is_flying", false))
	is_elite_rig = bool(options.get("is_elite", false))
	is_boss_rig = bool(options.get("is_boss", false))
	_walk_blend = 0.0
	_direction_pose = Vector2.RIGHT
	_death_started = false
	state = "idle"
	action_id = ""
	action_variant = ""
	action_time_left = 0.0
	hit_time_left = 0.0

	var manifest_data := _manifest_data()
	var key := _profile_asset_key()
	if manifest_data.has(key):
		_rig_data = manifest_data[key]
		_build_sliced_rig()
	else:
		_rig_data = {}
		_build_legacy_rig()
	update_animation(0.0, Vector2.ZERO, Vector2.RIGHT)


func _manifest_data() -> Dictionary:
	var script_resource := load(MANIFEST_PATH)
	if script_resource == null:
		return {}
	var constants = script_resource.get_script_constant_map()
	if constants is Dictionary:
		return constants.get("DATA", {})
	return {}


func set_state(new_state: String) -> void:
	state = new_state


func play_action(new_action_id: String, direction := Vector2.ZERO, variant := "", duration := 0.0) -> void:
	if state == "death":
		return
	action_id = new_action_id
	action_variant = variant
	if direction.length_squared() > 0.0:
		if abs(direction.x) > 0.05:
			facing_sign = signf(direction.x)
		_direction_pose = direction.normalized()
	action_duration = duration if duration > 0.0 else _action_duration(new_action_id)
	action_time_left = action_duration
	set_state(new_action_id)


func play_hit() -> void:
	if state == "death":
		return
	hit_time_left = 0.18
	set_state("hit")


func set_status_tint(color: Color) -> void:
	# Статусный цвет (щит, аура, windup, ярость) поверх видимого слоя;
	# hit/death-тинты имеют приоритет в _apply_hit_feedback.
	status_tint = color


func play_death() -> void:
	if _death_started:
		return
	_death_started = true
	action_id = "death"
	action_duration = 0.55
	action_time_left = action_duration
	set_state("death")
	set_process(true)


func spawn_death_ghost() -> void:
	## The owner frees itself right after dying; leave behind a standalone copy
	## of the rig that plays the collapse-and-fade animation on its own.
	var scene: Node = null
	if is_inside_tree():
		scene = get_tree().current_scene
		if scene == null:
			scene = get_tree().root
	else:
		scene = _top_available_parent()
	if scene == null:
		return
	var ghost := Node2D.new()
	ghost.name = "DeathGhostRig"
	ghost.set_script(get_script())
	scene.add_child(ghost)
	ghost.global_position = global_position
	ghost.configure(source_texture, base_scale, profile_id, {
		"is_player": is_player_rig,
		"is_flying": is_flying_rig,
		"is_elite": is_elite_rig,
		"is_boss": is_boss_rig,
	})
	ghost.facing_sign = facing_sign
	ghost.is_death_ghost = true
	ghost.play_death()


func weapon_socket_position() -> Vector2:
	if _socket_mount == null or _pelvis == null:
		return Vector2(18.0 * facing_sign, 2.0)
	var chain := _socket_chain_transform()
	var kick := _socket_action_kick()
	# forward (x) follows facing; vertical (y) is screen-space up/down.
	return chain * _socket_mount.position + Vector2(kick.x * facing_sign, kick.y)


func weapon_socket_rotation() -> float:
	var spin := _socket_action_kick().z
	var attack_part := _attack_part()
	var arm_rot := 0.0 if attack_part == null else attack_part.rotation * 0.55
	return (arm_rot + spin) * _render_sign()


## Snappy weapon kick in the socket itself (independent of the arm) so the held
## weapon has anticipation/thrust on melee, recoil on ranged, and a raise on
## casts — gives ranged/caster weapons life where the arm barely moves.
## Returns Vector3(forward, vertical, spin).
func _socket_action_kick() -> Vector3:
	if action_time_left <= 0.0 or state == "death" or action_id == "":
		return Vector3.ZERO
	var p: float = clampf(1.0 - action_time_left / maxf(action_duration, 0.001), 0.0, 1.0)
	match action_id:
		"attack":
			# anticipation back, then thrust forward with a follow-through tilt
			var windup: float = sin(minf(p / 0.3, 1.0) * PI)
			var swing: float = sin(maxf((p - 0.3) / 0.7, 0.0) * PI)
			return Vector3(-3.0 * windup + 8.0 * swing, -1.0 * windup, 0.22 * swing)
		"shoot":
			# sharp recoil back along facing + slight muzzle rise, quick return
			var recoil: float = pow(1.0 - p, 1.6) if p < 0.5 else 0.0
			var kick: float = sin(minf(p / 0.18, 1.0) * PI) * 0.6 + recoil * 0.4
			return Vector3(-9.0 * kick, -3.0 * kick, -0.16 * kick)
		"cast":
			# raise and glow build, small forward push at release
			var raise: float = sin(minf(p / 0.45, 1.0) * PI * 0.5)
			var fade: float = 1.0 - maxf((p - 0.78) / 0.22, 0.0)
			var amp: float = raise * fade
			var release: float = sin(maxf((p - 0.7) / 0.3, 0.0) * PI)
			return Vector3(3.0 * release, -7.0 * amp, -0.18 * amp + 0.12 * release)
		_:
			return Vector3.ZERO


func update_animation(delta: float, movement_velocity: Vector2, desired_facing := Vector2.ZERO) -> void:
	if _pelvis == null:
		return

	if state != "death" and desired_facing.length_squared() > 0.0:
		var desired_direction := desired_facing.normalized()
		var direction_blend_rate: float = float(_motion_profile().get("direction_blend_rate", 8.0))
		_direction_pose = _direction_pose.lerp(desired_direction, clamp(delta * direction_blend_rate, 0.0, 1.0)).normalized()
		if abs(desired_direction.x) > 0.05:
			facing_sign = signf(desired_direction.x)

	var moving := movement_velocity.length_squared() > 0.01
	var profile := _motion_profile()
	var walk_blend_rate: float = float(profile.get("walk_blend_rate", 6.4))
	_walk_blend = lerpf(_walk_blend, 1.0 if moving else 0.0, clamp(delta * walk_blend_rate, 0.0, 1.0))
	if state not in ACTION_STATES and state != "hit":
		state = "walk" if moving else "idle"

	var speed_factor: float = clamp(movement_velocity.length() / float(profile.get("speed_reference", 120.0)), 0.35, 1.8)
	var frequency: float = lerpf(float(profile.get("idle_frequency", 1.6)), float(profile.get("walk_frequency", 8.0)) * speed_factor, _walk_blend)
	animation_time += delta * frequency

	action_time_left = max(action_time_left - delta, 0.0)
	hit_time_left = max(hit_time_left - delta, 0.0)
	if action_time_left <= 0.0 and state in ACTION_STATES:
		if state == "death":
			return
		action_id = ""
		action_variant = ""
		state = "walk" if moving else "idle"
	if hit_time_left <= 0.0 and state == "hit":
		state = "walk" if moving else "idle"

	if _rig_data.is_empty():
		_pose_legacy(profile)
	else:
		_pose_sliced(profile)
	_apply_hit_feedback()


func _process(delta: float) -> void:
	# Self-drive the rig only while the owner no longer updates it (death ghost).
	if state == "death":
		update_animation(delta, Vector2.ZERO, Vector2.ZERO)
		if is_death_ghost and action_time_left <= 0.0:
			queue_free()
	else:
		set_process(false)


## --- rig construction -------------------------------------------------------

func _clear_children() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_parts.clear()
	_part_rest.clear()
	_torso = null
	_hero_full = null
	_socket_mount = null


func _build_sliced_rig() -> void:
	_clear_children()
	var size: Vector2 = _rig_data.get("size", Vector2(192.0, 192.0))
	_center = size * 0.5
	_style = str(_rig_data.get("style", "humanoid"))
	_attack_part_name = str(_rig_data.get("attack_part", ""))
	_base_facing = float(_rig_data.get("base_facing", 1.0))

	var foot_y := float(_rig_data.get("foot_y", size.y * 0.92))
	_shadow = Polygon2D.new()
	_shadow.name = "GroundShadow"
	var shadow_width: float = size.x * base_scale.x * 0.30
	_shadow.polygon = _ellipse_points(shadow_width, shadow_width * 0.30, 24)
	_shadow.color = Color(0.0, 0.0, 0.0, 0.20 if is_boss_rig else 0.16)
	_shadow.position = Vector2(0.0, (foot_y - _center.y) * base_scale.y + 2.0)
	_shadow.z_index = -8
	add_child(_shadow)

	_pelvis = Node2D.new()
	_pelvis.name = "Pelvis"
	add_child(_pelvis)

	_figure = Node2D.new()
	_figure.name = "Figure"
	_figure.scale = base_scale
	_pelvis.add_child(_figure)

	var parts: Dictionary = _rig_data.get("parts", {})
	var torso_info: Dictionary = parts.get("torso", {})
	_torso = _spawn_part("torso", torso_info, _figure, Vector2.ZERO)

	for part_name in parts.keys():
		if part_name == "torso":
			continue
		var info: Dictionary = parts[part_name]
		var parent: Node2D = _figure if part_name.begins_with("leg") else _torso
		var parent_origin: Vector2 = Vector2.ZERO if part_name.begins_with("leg") else _torso_pivot_offset()
		_spawn_part(part_name, info, parent, parent_origin)

	_socket_mount = Node2D.new()
	_socket_mount.name = "WeaponSocketMount"
	var socket: Vector2 = _rig_data.get("socket", _center)
	_socket_mount.position = socket - _center - _torso_pivot_offset()
	_torso.add_child(_socket_mount)


func _spawn_part(part_name: String, info: Dictionary, parent: Node2D, parent_origin: Vector2) -> Node2D:
	var node := Node2D.new()
	node.name = _node_name_for_part(part_name)
	var pivot: Vector2 = info.get("pivot", _center)
	node.position = pivot - _center - parent_origin
	node.z_index = int(info.get("z", 0))
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = info.get("texture")
	sprite.centered = false
	sprite.position = Vector2(info.get("pos", Vector2.ZERO)) - pivot
	parent.add_child(node)
	node.add_child(sprite)
	_parts[part_name] = node
	_part_rest[part_name] = {"position": node.position, "rotation": 0.0}
	return node


func _torso_pivot_offset() -> Vector2:
	var parts: Dictionary = _rig_data.get("parts", {})
	var torso_info: Dictionary = parts.get("torso", {})
	return Vector2(torso_info.get("pivot", _center)) - _center


func _build_legacy_rig() -> void:
	_clear_children()
	_style = "legacy"
	_attack_part_name = ""
	_base_facing = 1.0
	var width: float = 48.0
	if source_texture != null:
		width = source_texture.get_width() * base_scale.x * 0.5
	_shadow = Polygon2D.new()
	_shadow.name = "GroundShadow"
	_shadow.polygon = _ellipse_points(width * 0.6, width * 0.18, 24)
	_shadow.color = Color(0.0, 0.0, 0.0, 0.16)
	_shadow.position = Vector2(0.0, width * 0.55)
	_shadow.z_index = -8
	add_child(_shadow)

	_pelvis = Node2D.new()
	_pelvis.name = "Pelvis"
	add_child(_pelvis)

	if source_texture != null:
		_hero_full = Sprite2D.new()
		_hero_full.name = "HeroFull"
		_hero_full.texture = source_texture
		_hero_full.scale = base_scale
		_pelvis.add_child(_hero_full)

	_socket_mount = Node2D.new()
	_socket_mount.name = "WeaponSocketMount"
	_socket_mount.position = Vector2(width * 0.55, -width * 0.1)
	_pelvis.add_child(_socket_mount)


## --- posing -----------------------------------------------------------------

func _pose_sliced(profile: Dictionary) -> void:
	var phase: float = animation_time
	var step: float = sin(phase)
	var counter_step: float = sin(phase + PI)
	var bob_amp: float = float(profile.get("bob", 2.5))
	var breath: float = sin(phase * 0.45) * float(profile.get("idle_breath", 1.0)) * (1.0 - _walk_blend)
	var render_sign := _render_sign()
	var lean: float = (_direction_pose.x * float(profile.get("sway", 0.06)) + _direction_pose.y * 0.02) * _walk_blend * render_sign

	var pelvis_pos: Vector2 = Vector2.ZERO
	var pelvis_rot: float = lean
	var squash: Vector2 = Vector2.ONE

	match _style:
		"flyer":
			pelvis_pos.y = sin(phase * 0.72) * bob_amp
			squash = Vector2(1.0 + sin(phase) * 0.015, 1.0 - sin(phase) * 0.012)
		"floating_robed":
			pelvis_pos.y = sin(phase * 0.6) * bob_amp
			squash = Vector2(1.0 + sin(phase * 0.6) * 0.012, 1.0 - sin(phase * 0.6) * 0.015)
		"colossus":
			pelvis_pos.y = sin(phase * 0.5) * bob_amp
			squash = Vector2(1.0 + sin(phase * 0.5) * 0.01, 1.0 - sin(phase * 0.5) * 0.012)
		"blob":
			var hop: float = max(step, 0.0)
			pelvis_pos.y = -hop * bob_amp * _walk_blend + breath * 0.6
			squash = Vector2(
				1.0 + (0.5 - hop) * 0.07 * _walk_blend + breath * 0.012,
				1.0 - (0.5 - hop) * 0.09 * _walk_blend - breath * 0.012
			)
		_:
			pelvis_pos.y = -abs(step) * bob_amp * _walk_blend + breath
			pelvis_pos.x = sin(phase * 0.5) * float(profile.get("weight_shift", 0.6)) * _walk_blend
			squash = Vector2(
				1.0 + abs(step) * float(profile.get("squash_x", 0.010)) * _walk_blend,
				1.0 - abs(step) * float(profile.get("squash_y", 0.008)) * _walk_blend
			)

	var action_pose := _action_pose()
	pelvis_pos += Vector2(float(action_pose.get("push_x", 0.0)) * facing_sign, float(action_pose.get("push_y", 0.0)))
	pelvis_rot += float(action_pose.get("body_rot", 0.0)) * render_sign
	squash *= Vector2(float(action_pose.get("squash_x", 1.0)), float(action_pose.get("squash_y", 1.0)))

	if state == "death":
		var death_p: float = 1.0 - action_time_left / maxf(action_duration, 0.001)
		pelvis_rot += 1.15 * death_p * render_sign
		squash *= Vector2(1.0 + 0.10 * death_p, 1.0 - 0.30 * death_p)
		modulate.a = 1.0 - death_p * 0.9

	_pelvis.position = pelvis_pos
	_pelvis.rotation = pelvis_rot
	_pelvis.scale = squash * Vector2(render_sign, 1.0)

	if _torso != null:
		_torso.rotation = step * float(profile.get("body_counter", 0.03)) * _walk_blend \
			+ sin(phase * 0.5) * float(profile.get("idle_sway", 0.015)) * (1.0 - _walk_blend) \
			+ float(action_pose.get("torso_rot", 0.0))

	_pose_limbs(profile, step, counter_step, action_pose)


func _pose_limbs(profile: Dictionary, step: float, counter_step: float, action_pose: Dictionary) -> void:
	var stride: float = lerpf(float(profile.get("idle_stride", 0.05)), float(profile.get("stride", 0.45)), _walk_blend)
	var arm_swing: float = lerpf(float(profile.get("idle_arm", 0.05)), float(profile.get("arm_swing", 0.35)), _walk_blend)
	var lift: float = float(profile.get("foot_lift", 2.5)) * _walk_blend
	var flap_rate: float = float(profile.get("flap_rate", 1.4))
	var phase: float = animation_time

	for part_name in _parts.keys():
		if part_name == "torso":
			continue
		var node: Node2D = _parts[part_name]
		var rest: Dictionary = _part_rest[part_name]
		var rotation_offset: float = 0.0
		var position_offset: Vector2 = Vector2.ZERO

		match part_name:
			"leg_l":
				rotation_offset = _soft_signed(step) * stride
				position_offset.y = -max(step, 0.0) * lift
			"leg_r":
				rotation_offset = _soft_signed(counter_step) * stride
				position_offset.y = -max(counter_step, 0.0) * lift
			"arm_l":
				rotation_offset = _soft_signed(counter_step) * arm_swing + sin(phase * 0.5) * 0.04 * (1.0 - _walk_blend)
			"arm_r":
				rotation_offset = _soft_signed(step) * arm_swing - sin(phase * 0.5) * 0.04 * (1.0 - _walk_blend)
			"wing_l":
				var flap: float = sin(phase * flap_rate)
				rotation_offset = -0.10 + flap * 0.42
				position_offset.y = -max(flap, 0.0) * 2.0
			"wing_r":
				var flap_r: float = sin(phase * flap_rate)
				rotation_offset = 0.10 - flap_r * 0.42
				position_offset.y = -max(-flap_r, 0.0) * 2.0
			"weapon":
				rotation_offset = sin(phase * 0.5) * 0.02
			"shield":
				rotation_offset = sin(phase * 0.55) * 0.03
				position_offset.y = sin(phase * 0.55) * 0.8
			"tail":
				rotation_offset = sin(phase * 0.8) * 0.18
			"vortex":
				rotation_offset = sin(phase * 0.35) * 0.16
				var vortex_sprite := node.get_node_or_null("Sprite") as Sprite2D
				if vortex_sprite != null:
					vortex_sprite.modulate.a = 0.92 + sin(phase * 0.9) * 0.08

		if _style == "flyer" and part_name.begins_with("leg"):
			rotation_offset = sin(phase * 0.5 + (0.0 if part_name == "leg_l" else 0.9)) * 0.14
			position_offset = Vector2.ZERO
		if (_style == "beast" or _style == "stalker") and part_name.begins_with("arm"):
			rotation_offset *= 0.7
			position_offset.y = -max(step if part_name == "arm_l" else counter_step, 0.0) * lift * 0.7

		var action_parts: Dictionary = action_pose.get("parts", {})
		if action_parts.has(part_name):
			var override: Dictionary = action_parts[part_name]
			rotation_offset += float(override.get("rotation", 0.0))
			position_offset += Vector2(override.get("position", Vector2.ZERO))

		node.rotation = float(rest["rotation"]) + rotation_offset
		node.position = Vector2(rest["position"]) + position_offset


func _action_pose() -> Dictionary:
	var pose := {"parts": {}}
	if action_time_left <= 0.0 or state == "death" or action_id == "":
		return pose
	var p: float = 1.0 - action_time_left / maxf(action_duration, 0.001)
	if is_elite_rig and action_variant.contains(":"):
		var elite_pose: Dictionary = _elite_action_pose(p)
		if not elite_pose.is_empty():
			return elite_pose
	if is_player_rig and profile_id == "soldier":
		var soldier_pose: Dictionary = _soldier_action_pose(p)
		if not soldier_pose.is_empty():
			return soldier_pose
	if is_player_rig and profile_id == "thief":
		var thief_pose: Dictionary = _thief_action_pose(p)
		if not thief_pose.is_empty():
			return thief_pose
	if is_player_rig and profile_id == "elementalist":
		var elementalist_pose: Dictionary = _elementalist_action_pose(p)
		if not elementalist_pose.is_empty():
			return elementalist_pose
	if is_player_rig and profile_id == "sniper":
		var sniper_pose: Dictionary = _sniper_action_pose(p)
		if not sniper_pose.is_empty():
			return sniper_pose
	if is_player_rig and profile_id == "priest":
		var priest_pose: Dictionary = _priest_action_pose(p)
		if not priest_pose.is_empty():
			return priest_pose
	if is_player_rig and profile_id == "biologist":
		var biologist_pose: Dictionary = _biologist_action_pose(p)
		if not biologist_pose.is_empty():
			return biologist_pose
	if is_player_rig and profile_id == "robot":
		var robot_pose: Dictionary = _robot_action_pose(p)
		if not robot_pose.is_empty():
			return robot_pose
	if is_player_rig and profile_id == "engineer":
		var engineer_pose: Dictionary = _engineer_action_pose(p)
		if not engineer_pose.is_empty():
			return engineer_pose

	match action_id:
		"attack":
			var windup: float = sin(minf(p / 0.3, 1.0) * PI)
			var swing: float = sin(maxf((p - 0.3) / 0.7, 0.0) * PI)
			var variant: String = action_variant.to_lower()
			if is_player_rig and profile_id == "berserk" and _is_thrust_variant(variant):
				var thrust: float = sin(p * PI)
				pose["push_x"] = -1.5 * windup + 12.0 * thrust
				pose["body_rot"] = -0.02 * windup + 0.045 * thrust
				pose["squash_x"] = 1.0 + 0.035 * thrust
				pose["squash_y"] = 1.0 - 0.025 * thrust
				if _parts.has("arm_r"):
					pose["parts"]["arm_r"] = {
						"rotation": -0.10 * windup + 0.34 * thrust,
						"position": Vector2(11.0 * thrust, -1.0 * windup),
					}
				if _parts.has("arm_l"):
					pose["parts"]["arm_l"] = {
						"rotation": 0.18 * windup - 0.12 * thrust,
						"position": Vector2(2.0 * thrust, -1.5 * windup),
					}
			elif is_player_rig and profile_id == "berserk" and _is_slam_variant(variant):
				var lift: float = sin(minf(p / 0.38, 1.0) * PI * 0.5)
				var slam: float = sin(maxf((p - 0.38) / 0.62, 0.0) * PI)
				pose["push_x"] = -2.0 * lift + 5.0 * slam
				pose["push_y"] = -5.5 * lift + 7.0 * slam
				pose["body_rot"] = -0.035 * lift + 0.07 * slam
				pose["squash_x"] = 1.0 + 0.08 * slam
				pose["squash_y"] = 1.0 - 0.09 * slam
				for arm_name in ["arm_l", "arm_r"]:
					if _parts.has(arm_name):
						pose["parts"][arm_name] = {
							"rotation": -0.90 * lift + 0.52 * slam,
							"position": Vector2(3.0 * slam, -7.0 * lift + 8.0 * slam),
						}
			else:
				var arc_scale: float = 1.18 if is_player_rig and profile_id == "berserk" and _is_arc_variant(variant) else 1.0
				pose["push_x"] = -3.0 * windup + 11.0 * swing
				pose["body_rot"] = -0.05 * windup + 0.12 * swing * arc_scale
				pose["squash_x"] = 1.0 + 0.06 * swing
				pose["squash_y"] = 1.0 - 0.05 * swing
				if _style == "colossus":
					# Кулаки колосса бьют выпадом-слэмом, а не широким вращением.
					for fist in ["arm_l", "arm_r"]:
						if _parts.has(fist):
							pose["parts"][fist] = {
								"rotation": -0.18 * windup + 0.35 * swing,
								"position": Vector2(10.0 * swing, -6.0 * windup + 9.0 * swing),
							}
				elif _attack_part_name != "" and _parts.has(_attack_part_name):
					pose["parts"][_attack_part_name] = {
						"rotation": -0.65 * windup + 1.55 * swing * arc_scale,
						"position": Vector2(2.0 * swing * arc_scale, -1.5 * windup),
					}
					var off_arm := "arm_l" if _attack_part_name == "arm_r" else "arm_r"
					if _parts.has(off_arm):
						pose["parts"][off_arm] = {"rotation": 0.30 * windup - 0.55 * swing * arc_scale}
				else:
					pose["squash_x"] = 1.0 + 0.14 * swing
					pose["squash_y"] = 1.0 - 0.12 * swing
		"shoot":
			var recoil: float = sin(p * PI)
			pose["push_x"] = -6.0 * recoil
			pose["body_rot"] = -0.05 * recoil
			var shoot_part := _attack_part_name if _parts.has(_attack_part_name) else "arm_r"
			if _parts.has(shoot_part):
				pose["parts"][shoot_part] = {"rotation": -0.22 * recoil, "position": Vector2(-3.0 * recoil, -1.0 * recoil)}
		"cast":
			var raise: float = sin(minf(p / 0.4, 1.0) * PI * 0.5)
			var fade: float = 1.0 - maxf((p - 0.78) / 0.22, 0.0)
			var amp: float = raise * fade
			pose["push_y"] = -3.5 * amp
			pose["torso_rot"] = -0.04 * amp
			if _parts.has("arm_l"):
				pose["parts"]["arm_l"] = {"rotation": -0.85 * amp, "position": Vector2(0.0, -2.0 * amp)}
			if _parts.has("arm_r"):
				pose["parts"]["arm_r"] = {"rotation": 0.85 * amp, "position": Vector2(0.0, -2.0 * amp)}
			if _parts.has("weapon"):
				pose["parts"]["weapon"] = {"rotation": -0.30 * amp}
			if _parts.has("shield"):
				pose["parts"]["shield"] = {"rotation": -0.22 * amp, "position": Vector2(2.0 * amp, -3.0 * amp)}
			if _parts.has("vortex"):
				pose["parts"]["vortex"] = {"rotation": 0.6 * amp}
		_:
			pass
	return pose


func _engineer_action_pose(p: float) -> Dictionary:
	var variant: String = action_variant.to_lower()
	if action_id != "shoot" or not variant.begins_with("engineer_"):
		return {}
	var pose := {"parts": {}}
	var parts: Dictionary = pose["parts"]

	if variant == "engineer_sentry_wrench" or variant.contains("sentry") or variant.contains("wrench") or variant.contains("link"):
		var ready: float = sin(minf(p / 0.34, 1.0) * PI * 0.5)
		var deploy: float = sin(maxf((p - 0.28) / 0.58, 0.0) * PI)
		pose["push_x"] = 2.0 * ready + 3.0 * deploy
		pose["push_y"] = -1.0 * ready
		pose["body_rot"] = 0.030 * ready + 0.045 * deploy
		pose["torso_rot"] = 0.020 * ready
		pose["squash_x"] = 1.0 + 0.022 * deploy
		pose["squash_y"] = 1.0 - 0.018 * deploy
		if _parts.has("arm_r"):
			parts["arm_r"] = {
				"rotation": -0.52 * ready + 0.30 * deploy,
				"position": Vector2(8.0 * ready + 4.0 * deploy, -4.5 * ready),
			}
		if _parts.has("arm_l"):
			parts["arm_l"] = {
				"rotation": 0.20 * ready - 0.18 * deploy,
				"position": Vector2(2.0 * ready, -1.0 * ready),
			}
	elif variant == "engineer_repair_drone" or variant.contains("repair") or variant.contains("drone"):
		var launch: float = sin(minf(p / 0.40, 1.0) * PI * 0.5)
		var guide: float = sin(maxf((p - 0.32) / 0.58, 0.0) * PI)
		pose["push_y"] = -3.0 * launch
		pose["push_x"] = 1.5 * guide
		pose["body_rot"] = -0.030 * launch + 0.035 * guide
		pose["torso_rot"] = -0.025 * launch
		pose["squash_x"] = 1.0 + 0.018 * guide
		pose["squash_y"] = 1.0 - 0.016 * guide
		if _parts.has("arm_l"):
			parts["arm_l"] = {
				"rotation": -0.58 * launch - 0.12 * guide,
				"position": Vector2(-2.5 * launch - 2.0 * guide, -5.0 * launch),
			}
		if _parts.has("arm_r"):
			parts["arm_r"] = {
				"rotation": 0.42 * launch + 0.12 * guide,
				"position": Vector2(5.0 * launch + 2.0 * guide, -4.0 * launch),
			}
	elif variant == "engineer_pressure_mines" or variant.contains("pressure") or variant.contains("mine"):
		var crouch: float = sin(minf(p / 0.38, 1.0) * PI * 0.5)
		var place: float = sin(maxf((p - 0.30) / 0.60, 0.0) * PI)
		pose["push_y"] = 4.0 * crouch
		pose["push_x"] = 2.5 * place
		pose["body_rot"] = 0.050 * crouch - 0.035 * place
		pose["torso_rot"] = 0.040 * crouch
		pose["squash_x"] = 1.0 + 0.028 * crouch
		pose["squash_y"] = 1.0 - 0.024 * crouch
		if _parts.has("arm_l"):
			parts["arm_l"] = {
				"rotation": 0.32 * crouch - 0.18 * place,
				"position": Vector2(-3.0 * crouch - 2.0 * place, 4.0 * crouch + 1.0 * place),
			}
		if _parts.has("arm_r"):
			parts["arm_r"] = {
				"rotation": 0.60 * crouch + 0.18 * place,
				"position": Vector2(5.0 * crouch + 4.0 * place, 5.0 * crouch + 1.0 * place),
			}
	else:
		return {}
	return pose


func _robot_action_pose(p: float) -> Dictionary:
	var variant: String = action_variant.to_lower()
	if action_id != "shoot" or not variant.begins_with("robot_"):
		return {}
	var pose := {"parts": {}}
	var parts: Dictionary = pose["parts"]

	if variant == "robot_magnetic_anchor" or variant.contains("magnetic") or variant.contains("anchor"):
		var plant: float = sin(minf(p / 0.38, 1.0) * PI * 0.5)
		var pull: float = sin(maxf((p - 0.30) / 0.58, 0.0) * PI)
		pose["push_x"] = -3.2 * plant - 2.0 * pull
		pose["push_y"] = 2.8 * plant
		pose["body_rot"] = -0.028 * plant - 0.035 * pull
		pose["squash_x"] = 1.0 + 0.026 * pull
		pose["squash_y"] = 1.0 - 0.024 * pull
		if _parts.has("arm_r"):
			parts["arm_r"] = {
				"rotation": 0.38 * plant + 0.18 * pull,
				"position": Vector2(8.0 * plant + 3.0 * pull, 5.0 * plant),
			}
		if _parts.has("arm_l"):
			parts["arm_l"] = {
				"rotation": -0.24 * plant - 0.12 * pull,
				"position": Vector2(-2.0 * plant - 3.0 * pull, 2.0 * plant),
			}
	elif variant == "robot_hydraulic_press" or variant.contains("hydraulic") or variant.contains("press"):
		var brace: float = sin(minf(p / 0.30, 1.0) * PI * 0.5)
		var crush: float = sin(maxf((p - 0.24) / 0.56, 0.0) * PI)
		pose["push_x"] = 1.0 * brace + 5.0 * crush
		pose["push_y"] = 1.4 * brace
		pose["body_rot"] = 0.030 * brace + 0.055 * crush
		pose["squash_x"] = 1.0 + 0.036 * crush
		pose["squash_y"] = 1.0 - 0.030 * crush
		if _parts.has("arm_l"):
			parts["arm_l"] = {
				"rotation": -0.30 * brace + 0.24 * crush,
				"position": Vector2(5.0 * brace + 9.0 * crush, -1.0 * brace),
			}
		if _parts.has("arm_r"):
			parts["arm_r"] = {
				"rotation": 0.30 * brace - 0.24 * crush,
				"position": Vector2(6.0 * brace + 10.0 * crush, -1.0 * brace),
			}
	elif variant == "robot_reactor_core" or variant.contains("reactor") or variant.contains("core") or variant.contains("vent"):
		var charge: float = sin(minf(p / 0.42, 1.0) * PI * 0.5)
		var vent: float = sin(maxf((p - 0.32) / 0.54, 0.0) * PI)
		pose["push_y"] = -3.5 * charge + 2.0 * vent
		pose["body_rot"] = sin(p * TAU) * 0.040 * charge
		pose["torso_rot"] = -0.030 * charge + 0.045 * vent
		pose["squash_x"] = 1.0 + 0.040 * vent
		pose["squash_y"] = 1.0 - 0.034 * vent
		if _parts.has("arm_l"):
			parts["arm_l"] = {
				"rotation": -0.44 * charge - 0.18 * vent,
				"position": Vector2(-9.0 * charge - 3.0 * vent, -3.5 * charge + 1.5 * vent),
			}
		if _parts.has("arm_r"):
			parts["arm_r"] = {
				"rotation": 0.44 * charge + 0.18 * vent,
				"position": Vector2(10.0 * charge + 3.0 * vent, -3.5 * charge + 1.5 * vent),
			}
	else:
		return {}
	return pose


func _biologist_action_pose(p: float) -> Dictionary:
	var variant: String = action_variant.to_lower()
	if action_id != "shoot" or not variant.begins_with("biologist_"):
		return {}
	var pose := {"parts": {}}
	var parts: Dictionary = pose["parts"]

	if variant == "biologist_spore_lens" or variant.contains("spore") or variant.contains("bloom"):
		var inspect: float = sin(minf(p / 0.42, 1.0) * PI * 0.5)
		var bloom: float = sin(maxf((p - 0.32) / 0.58, 0.0) * PI)
		pose["push_y"] = -2.2 * inspect
		pose["push_x"] = 1.6 * bloom
		pose["body_rot"] = -0.030 * inspect + 0.040 * bloom
		pose["torso_rot"] = -0.025 * inspect
		pose["squash_x"] = 1.0 + 0.024 * bloom
		pose["squash_y"] = 1.0 - 0.020 * bloom
		if _parts.has("arm_l"):
			parts["arm_l"] = {
				"rotation": -0.48 * inspect - 0.20 * bloom,
				"position": Vector2(-3.0 * inspect - 2.0 * bloom, -4.0 * inspect),
			}
		if _parts.has("arm_r"):
			parts["arm_r"] = {
				"rotation": 0.34 * inspect + 0.24 * bloom,
				"position": Vector2(5.0 * inspect + 4.0 * bloom, -3.0 * inspect),
			}
	elif variant == "biologist_sample_injector" or variant.contains("sample") or variant.contains("injector"):
		var aim: float = sin(minf(p / 0.34, 1.0) * PI * 0.5)
		var dart: float = sin(maxf((p - 0.28) / 0.54, 0.0) * PI)
		pose["push_x"] = -1.2 * aim - 3.5 * dart
		pose["push_y"] = 0.8 * aim
		pose["body_rot"] = -0.025 * aim - 0.035 * dart
		pose["squash_x"] = 1.0 - 0.018 * dart
		pose["squash_y"] = 1.0 + 0.014 * dart
		if _parts.has("arm_r"):
			parts["arm_r"] = {
				"rotation": -0.18 * aim - 0.12 * dart,
				"position": Vector2(11.0 * aim + 2.0 * dart, -1.0 * aim - 1.0 * dart),
			}
		if _parts.has("arm_l"):
			parts["arm_l"] = {
				"rotation": 0.18 * aim - 0.08 * dart,
				"position": Vector2(5.0 * aim, -0.5 * aim),
			}
	elif variant == "biologist_symbiote_seed" or variant.contains("symbiote") or variant.contains("web"):
		var plant: float = sin(minf(p / 0.40, 1.0) * PI * 0.5)
		var weave: float = sin(maxf((p - 0.30) / 0.60, 0.0) * PI)
		pose["push_y"] = 3.5 * plant
		pose["push_x"] = 2.8 * weave
		pose["body_rot"] = 0.045 * plant - 0.050 * weave
		pose["torso_rot"] = 0.035 * plant
		pose["squash_x"] = 1.0 + 0.030 * plant
		pose["squash_y"] = 1.0 - 0.026 * plant
		if _parts.has("arm_l"):
			parts["arm_l"] = {
				"rotation": 0.30 * plant - 0.32 * weave,
				"position": Vector2(-3.0 * plant - 3.0 * weave, 4.0 * plant + 1.5 * weave),
			}
		if _parts.has("arm_r"):
			parts["arm_r"] = {
				"rotation": 0.64 * plant + 0.24 * weave,
				"position": Vector2(4.0 * plant + 4.0 * weave, 5.0 * plant + 1.5 * weave),
			}
	else:
		return {}
	return pose


func _priest_action_pose(p: float) -> Dictionary:
	var variant: String = action_variant.to_lower()
	if action_id != "shoot" or not variant.begins_with("priest_"):
		return {}
	var pose := {"parts": {}}
	var parts: Dictionary = pose["parts"]

	if variant == "priest_reliquary" or variant.contains("reliquary") or variant.contains("sanctify"):
		var bless: float = sin(minf(p / 0.42, 1.0) * PI * 0.5)
		var release: float = sin(maxf((p - 0.34) / 0.58, 0.0) * PI)
		pose["push_y"] = -2.8 * bless
		pose["push_x"] = 2.5 * release
		pose["body_rot"] = -0.035 * bless + 0.045 * release
		pose["torso_rot"] = -0.025 * bless
		pose["squash_x"] = 1.0 + 0.020 * release
		pose["squash_y"] = 1.0 - 0.016 * release
		if _parts.has("arm_l"):
			parts["arm_l"] = {
				"rotation": -0.72 * bless + 0.20 * release,
				"position": Vector2(-2.5 * bless + 2.0 * release, -5.0 * bless),
			}
		if _parts.has("arm_r"):
			parts["arm_r"] = {
				"rotation": 0.34 * bless + 0.18 * release,
				"position": Vector2(3.0 * bless + 4.0 * release, -2.0 * bless),
			}
	elif variant == "priest_censer" or variant.contains("censer") or variant.contains("ward"):
		var ward: float = sin(minf(p / 0.40, 1.0) * PI * 0.5)
		var pulse: float = sin(maxf((p - 0.28) / 0.62, 0.0) * PI)
		pose["push_y"] = -1.5 * ward + 1.5 * pulse
		pose["body_rot"] = sin(p * TAU) * 0.028 * ward
		pose["squash_x"] = 1.0 + 0.035 * pulse
		pose["squash_y"] = 1.0 - 0.030 * pulse
		if _parts.has("arm_l"):
			parts["arm_l"] = {
				"rotation": -0.26 * ward - 0.22 * pulse,
				"position": Vector2(-3.5 * ward - 4.0 * pulse, 1.5 * pulse - 1.0 * ward),
			}
		if _parts.has("arm_r"):
			parts["arm_r"] = {
				"rotation": 0.42 * ward + 0.30 * pulse,
				"position": Vector2(6.0 * ward + 5.0 * pulse, 1.5 * pulse - 1.0 * ward),
			}
	elif variant == "priest_chime" or variant.contains("chime") or variant.contains("prayer"):
		var chant: float = sin(minf(p / 0.48, 1.0) * PI * 0.5)
		var chain: float = sin(maxf((p - 0.36) / 0.58, 0.0) * PI)
		pose["push_y"] = -4.2 * chant
		pose["push_x"] = 3.5 * chain
		pose["body_rot"] = -0.045 * chant + 0.060 * chain
		pose["torso_rot"] = -0.035 * chant
		pose["squash_x"] = 1.0 + 0.026 * chain
		pose["squash_y"] = 1.0 - 0.022 * chain
		if _parts.has("arm_l"):
			parts["arm_l"] = {
				"rotation": -0.88 * chant + 0.25 * chain,
				"position": Vector2(-1.5 * chant + 3.0 * chain, -7.0 * chant),
			}
		if _parts.has("arm_r"):
			parts["arm_r"] = {
				"rotation": 0.78 * chant + 0.34 * chain,
				"position": Vector2(3.0 * chant + 5.0 * chain, -6.0 * chant),
			}
	else:
		return {}
	return pose


func _sniper_action_pose(p: float) -> Dictionary:
	var variant: String = action_variant.to_lower()
	if action_id != "shoot" or not variant.begins_with("sniper_"):
		return {}
	var pose := {"parts": {}}
	var parts: Dictionary = pose["parts"]

	if variant == "sniper_deadeye_rifle" or variant.contains("deadeye") or variant.contains("lockshot"):
		var aim: float = sin(minf(p / 0.36, 1.0) * PI * 0.5)
		var shot: float = sin(maxf((p - 0.30) / 0.52, 0.0) * PI)
		pose["push_x"] = -1.8 * aim - 5.0 * shot
		pose["push_y"] = 1.2 * aim
		pose["body_rot"] = -0.030 * aim - 0.040 * shot
		pose["squash_x"] = 1.0 - 0.018 * shot
		pose["squash_y"] = 1.0 + 0.014 * shot
		if _parts.has("arm_r"):
			parts["arm_r"] = {
				"rotation": -0.25 * aim - 0.18 * shot,
				"position": Vector2(11.0 * aim - 3.0 * shot, -1.0 * aim - 1.5 * shot),
			}
		if _parts.has("arm_l"):
			parts["arm_l"] = {
				"rotation": 0.16 * aim - 0.08 * shot,
				"position": Vector2(10.0 * aim - 2.0 * shot, -0.5 * aim),
			}
	elif variant == "sniper_spotter_scope" or variant.contains("spotter") or variant.contains("kill_zone"):
		var mark: float = sin(minf(p / 0.45, 1.0) * PI * 0.5)
		var call: float = sin(maxf((p - 0.34) / 0.58, 0.0) * PI)
		pose["push_y"] = -2.4 * mark
		pose["push_x"] = -1.0 * mark + 2.0 * call
		pose["body_rot"] = -0.050 * mark + 0.030 * call
		pose["torso_rot"] = -0.035 * mark
		pose["squash_x"] = 1.0 + 0.018 * call
		pose["squash_y"] = 1.0 - 0.014 * call
		if _parts.has("arm_l"):
			parts["arm_l"] = {
				"rotation": -0.52 * mark + 0.14 * call,
				"position": Vector2(3.0 * mark, -4.5 * mark),
			}
		if _parts.has("arm_r"):
			parts["arm_r"] = {
				"rotation": -0.18 * mark + 0.18 * call,
				"position": Vector2(4.5 * mark + 2.0 * call, -2.0 * mark),
			}
	elif variant == "sniper_shatter_rounds" or variant.contains("shatter") or variant.contains("split"):
		var brace: float = sin(minf(p / 0.26, 1.0) * PI * 0.5)
		var burst: float = sin(maxf((p - 0.22) / 0.58, 0.0) * PI)
		pose["push_x"] = -2.5 * brace - 7.0 * burst
		pose["push_y"] = 1.8 * brace + 0.8 * burst
		pose["body_rot"] = -0.045 * brace - 0.060 * burst
		pose["squash_x"] = 1.0 - 0.024 * burst
		pose["squash_y"] = 1.0 + 0.018 * burst
		if _parts.has("arm_r"):
			parts["arm_r"] = {
				"rotation": -0.18 * brace - 0.24 * burst,
				"position": Vector2(8.0 * brace - 4.0 * burst, -0.6 * brace - 2.0 * burst),
			}
		if _parts.has("arm_l"):
			parts["arm_l"] = {
				"rotation": 0.22 * brace - 0.12 * burst,
				"position": Vector2(8.5 * brace - 2.0 * burst, 0.8 * brace),
			}
	else:
		return {}
	return pose


func _elementalist_action_pose(p: float) -> Dictionary:
	var variant: String = action_variant.to_lower()
	if action_id != "shoot" or not variant.begins_with("elementalist_"):
		return {}
	var pose := {"parts": {}}
	var parts: Dictionary = pose["parts"]

	if variant == "elementalist_orb_ring" or variant.contains("orb") or variant.contains("orbit"):
		var gather: float = sin(minf(p / 0.34, 1.0) * PI * 0.5)
		var channel: float = sin(p * PI)
		pose["push_y"] = -3.5 * gather
		pose["body_rot"] = sin(p * TAU) * 0.035 * channel
		pose["torso_rot"] = -0.035 * gather
		pose["squash_x"] = 1.0 + 0.020 * channel
		pose["squash_y"] = 1.0 - 0.018 * channel
		if _parts.has("arm_l"):
			parts["arm_l"] = {
				"rotation": -0.78 * gather - 0.18 * channel,
				"position": Vector2(-4.0 * channel, -5.0 * gather),
			}
		if _parts.has("arm_r"):
			parts["arm_r"] = {
				"rotation": 0.78 * gather + 0.18 * channel,
				"position": Vector2(4.0 * channel, -5.0 * gather),
			}
	elif variant == "elementalist_prism_focus" or variant.contains("prism") or variant.contains("rift"):
		var focus: float = sin(minf(p / 0.42, 1.0) * PI * 0.5)
		var release: float = sin(maxf((p - 0.36) / 0.56, 0.0) * PI)
		pose["push_x"] = -1.5 * focus + 5.5 * release
		pose["push_y"] = -2.5 * focus
		pose["body_rot"] = -0.040 * focus + 0.070 * release
		pose["torso_rot"] = 0.030 * release
		pose["squash_x"] = 1.0 + 0.030 * release
		pose["squash_y"] = 1.0 - 0.024 * release
		if _parts.has("arm_r"):
			parts["arm_r"] = {
				"rotation": -0.48 * focus + 0.30 * release,
				"position": Vector2(8.0 * focus + 5.0 * release, -3.0 * focus),
			}
		if _parts.has("arm_l"):
			parts["arm_l"] = {
				"rotation": 0.42 * focus - 0.24 * release,
				"position": Vector2(5.5 * focus + 2.0 * release, -2.0 * focus),
			}
	elif variant == "elementalist_meteor_core" or variant.contains("meteor") or variant.contains("shard"):
		var summon: float = sin(minf(p / 0.50, 1.0) * PI * 0.5)
		var drop: float = sin(maxf((p - 0.44) / 0.54, 0.0) * PI)
		pose["push_y"] = -6.5 * summon + 4.0 * drop
		pose["push_x"] = -1.0 * summon + 3.0 * drop
		pose["body_rot"] = -0.060 * summon + 0.085 * drop
		pose["squash_x"] = 1.0 + 0.045 * drop
		pose["squash_y"] = 1.0 - 0.038 * drop
		if _parts.has("arm_l"):
			parts["arm_l"] = {
				"rotation": -1.05 * summon + 0.45 * drop,
				"position": Vector2(-1.0 * summon + 3.0 * drop, -10.5 * summon + 5.0 * drop),
			}
		if _parts.has("arm_r"):
			parts["arm_r"] = {
				"rotation": 1.05 * summon + 0.38 * drop,
				"position": Vector2(2.0 * summon + 5.0 * drop, -10.5 * summon + 5.0 * drop),
			}
	else:
		return {}
	return pose


func _thief_action_pose(p: float) -> Dictionary:
	var variant: String = action_variant.to_lower()
	if action_id != "shoot" or not variant.begins_with("thief_"):
		return {}
	var pose := {"parts": {}}
	var parts: Dictionary = pose["parts"]

	if variant == "thief_coin_pouch" or variant.contains("coin") or variant.contains("ricochet"):
		var prep: float = sin(minf(p / 0.28, 1.0) * PI)
		var flick: float = sin(maxf((p - 0.20) / 0.52, 0.0) * PI)
		pose["push_x"] = -2.0 * prep + 4.5 * flick
		pose["push_y"] = -1.2 * prep
		pose["body_rot"] = -0.035 * prep + 0.055 * flick
		pose["squash_x"] = 1.0 + 0.018 * flick
		pose["squash_y"] = 1.0 - 0.014 * flick
		if _parts.has("arm_r"):
			parts["arm_r"] = {
				"rotation": -0.55 * prep + 1.02 * flick,
				"position": Vector2(6.0 * flick - 2.0 * prep, -3.0 * prep + 0.8 * flick),
			}
		if _parts.has("arm_l"):
			parts["arm_l"] = {
				"rotation": 0.25 * prep - 0.18 * flick,
				"position": Vector2(-1.5 * prep, -1.0 * prep),
			}
	elif variant == "thief_shadow_cloak" or variant.contains("shadow") or variant.contains("backstab"):
		var coil: float = sin(minf(p / 0.36, 1.0) * PI * 0.5)
		var lunge: float = sin(maxf((p - 0.28) / 0.58, 0.0) * PI)
		pose["push_x"] = -5.0 * coil + 17.0 * lunge
		pose["push_y"] = 4.0 * coil - 1.5 * lunge
		pose["body_rot"] = -0.075 * coil + 0.135 * lunge
		pose["squash_x"] = 1.0 + 0.075 * coil + 0.040 * lunge
		pose["squash_y"] = 1.0 - 0.110 * coil - 0.020 * lunge
		if _parts.has("arm_r"):
			parts["arm_r"] = {
				"rotation": -0.40 * coil + 0.72 * lunge,
				"position": Vector2(-3.0 * coil + 14.0 * lunge, 3.0 * coil - 1.0 * lunge),
			}
		if _parts.has("arm_l"):
			parts["arm_l"] = {
				"rotation": 0.35 * coil - 0.42 * lunge,
				"position": Vector2(-4.0 * coil + 4.0 * lunge, 2.0 * coil),
			}
	elif variant == "thief_smoke_bomb" or variant.contains("smoke"):
		var dodge: float = sin(minf(p / 0.34, 1.0) * PI * 0.5)
		var toss: float = sin(maxf((p - 0.24) / 0.62, 0.0) * PI)
		pose["push_x"] = -7.0 * dodge + 3.0 * toss
		pose["push_y"] = 3.0 * dodge + 2.0 * toss
		pose["body_rot"] = -0.100 * dodge + 0.045 * toss
		pose["squash_x"] = 1.0 + 0.055 * dodge
		pose["squash_y"] = 1.0 - 0.060 * dodge
		if _parts.has("arm_r"):
			parts["arm_r"] = {
				"rotation": -0.82 * dodge + 0.38 * toss,
				"position": Vector2(-4.0 * dodge + 4.0 * toss, 3.0 * dodge + 8.0 * toss),
			}
		if _parts.has("arm_l"):
			parts["arm_l"] = {
				"rotation": 0.30 * dodge - 0.16 * toss,
				"position": Vector2(-3.0 * dodge, 2.0 * dodge),
			}
	else:
		return {}
	return pose


func _soldier_action_pose(p: float) -> Dictionary:
	var variant: String = action_variant.to_lower()
	if action_id != "shoot" or not variant.begins_with("soldier_"):
		return {}
	var pose := {"parts": {}}
	var parts: Dictionary = pose["parts"]

	if variant == "soldier_rifle" or variant.contains("rifle") or variant.contains("suppression"):
		var brace: float = sin(minf(p / 0.35, 1.0) * PI * 0.5)
		var recoil: float = sin(p * PI)
		pose["push_x"] = -5.5 * recoil
		pose["body_rot"] = -0.035 * recoil
		pose["squash_x"] = 1.0 - 0.025 * recoil
		pose["squash_y"] = 1.0 + 0.020 * recoil
		if _parts.has("arm_r"):
			parts["arm_r"] = {
				"rotation": -0.28 * brace - 0.18 * recoil,
				"position": Vector2(-4.0 * recoil, -1.5 * brace),
			}
		if _parts.has("arm_l"):
			parts["arm_l"] = {
				"rotation": 0.22 * brace - 0.06 * recoil,
				"position": Vector2(3.0 * brace - 2.0 * recoil, -1.0 * brace),
			}
	elif variant == "soldier_grenade" or variant.contains("grenade"):
		var cook: float = sin(minf(p / 0.45, 1.0) * PI * 0.5)
		var throw: float = sin(maxf((p - 0.32) / 0.68, 0.0) * PI)
		pose["push_y"] = -3.0 * cook + 2.0 * throw
		pose["push_x"] = -2.0 * cook + 8.0 * throw
		pose["body_rot"] = -0.06 * cook + 0.10 * throw
		pose["squash_x"] = 1.0 + 0.035 * throw
		pose["squash_y"] = 1.0 - 0.030 * throw
		if _parts.has("arm_r"):
			parts["arm_r"] = {
				"rotation": -0.95 * cook + 1.08 * throw,
				"position": Vector2(8.0 * throw, -6.0 * cook + 2.0 * throw),
			}
		if _parts.has("arm_l"):
			parts["arm_l"] = {
				"rotation": 0.20 * cook - 0.22 * throw,
				"position": Vector2(-2.0 * cook, -2.0 * cook),
			}
	elif variant == "soldier_bayonet" or variant.contains("bayonet"):
		var brace: float = sin(minf(p / 0.22, 1.0) * PI * 0.5)
		var hold: float = 1.0 - clamp((p - 0.82) / 0.18, 0.0, 1.0)
		var amp: float = brace * hold
		pose["push_x"] = 8.0 * amp
		pose["push_y"] = 2.0 * amp
		pose["body_rot"] = 0.055 * amp
		pose["squash_x"] = 1.0 + 0.045 * amp
		pose["squash_y"] = 1.0 - 0.035 * amp
		if _parts.has("arm_r"):
			parts["arm_r"] = {
				"rotation": 0.22 * amp,
				"position": Vector2(11.0 * amp, -0.5 * amp),
			}
		if _parts.has("arm_l"):
			parts["arm_l"] = {
				"rotation": -0.18 * amp,
				"position": Vector2(7.0 * amp, 1.5 * amp),
			}
	else:
		return {}
	return pose


func _elite_action_pose(p: float) -> Dictionary:
	var fields := action_variant.split(":")
	if fields.size() < 3:
		return {}
	var behavior: String = fields[0]
	var phase: String = fields[2]
	var pose := {"parts": {}}
	var parts: Dictionary = pose["parts"]
	var windup: float = sin(minf(p, 1.0) * PI * 0.5)
	var strike: float = sin(p * PI)
	var settle: float = 1.0 - p

	match behavior:
		"iron_bastion":
			match phase:
				"windup":
					pose["push_y"] = -5.0 * windup
					pose["body_rot"] = -0.05 * windup
					pose["squash_x"] = 1.0 - 0.03 * windup
					pose["squash_y"] = 1.0 + 0.04 * windup
					if _parts.has("arm_r"):
						parts["arm_r"] = {"rotation": -0.95 * windup, "position": Vector2(-2.0 * windup, -8.0 * windup)}
					if _parts.has("shield"):
						parts["shield"] = {"rotation": -0.30 * windup, "position": Vector2(-2.0 * windup, -5.0 * windup)}
				"strike":
					pose["push_y"] = 8.0 * strike
					pose["push_x"] = 4.0 * strike
					pose["body_rot"] = 0.08 * strike
					pose["squash_x"] = 1.0 + 0.10 * strike
					pose["squash_y"] = 1.0 - 0.12 * strike
					if _parts.has("arm_r"):
						parts["arm_r"] = {"rotation": 0.65 * strike, "position": Vector2(7.0 * strike, 9.0 * strike)}
					if _parts.has("shield"):
						parts["shield"] = {"rotation": 0.24 * strike, "position": Vector2(2.0 * strike, 5.0 * strike)}
				"recover":
					pose["push_y"] = 2.0 * settle
					pose["body_rot"] = 0.03 * settle
		"night_stalker":
			match phase:
				"windup":
					pose["push_y"] = 5.0 * windup
					pose["push_x"] = -4.0 * windup
					pose["squash_x"] = 1.0 + 0.12 * windup
					pose["squash_y"] = 1.0 - 0.16 * windup
					if _parts.has("arm_l"):
						parts["arm_l"] = {"rotation": 0.55 * windup, "position": Vector2(-4.0 * windup, 3.0 * windup)}
					if _parts.has("arm_r"):
						parts["arm_r"] = {"rotation": -0.55 * windup, "position": Vector2(-5.0 * windup, 3.0 * windup)}
				"strike":
					pose["push_x"] = 16.0 * strike
					pose["body_rot"] = 0.14 * strike
					pose["squash_x"] = 1.0 + 0.08 * strike
					pose["squash_y"] = 1.0 - 0.05 * strike
					if _parts.has("arm_r"):
						parts["arm_r"] = {"rotation": 0.80 * strike, "position": Vector2(10.0 * strike, -1.0 * strike)}
					if _parts.has("arm_l"):
						parts["arm_l"] = {"rotation": -0.35 * strike, "position": Vector2(4.0 * strike, 2.0 * strike)}
				"recover":
					pose["push_x"] = -5.0 * settle
					pose["push_y"] = 2.0 * settle
		"plague_prophet":
			match phase:
				"windup":
					pose["push_y"] = -3.0 * windup
					pose["torso_rot"] = -0.06 * windup
					if _parts.has("arm_l"):
						parts["arm_l"] = {"rotation": -0.95 * windup, "position": Vector2(-2.0 * windup, -5.0 * windup)}
					if _parts.has("arm_r"):
						parts["arm_r"] = {"rotation": 0.65 * windup, "position": Vector2(3.0 * windup, -4.0 * windup)}
				"strike":
					pose["push_x"] = 7.0 * strike
					pose["body_rot"] = 0.09 * strike
					if _parts.has("arm_l"):
						parts["arm_l"] = {"rotation": -0.25 * strike, "position": Vector2(4.0 * strike, 1.0 * strike)}
					if _parts.has("arm_r"):
						parts["arm_r"] = {"rotation": 1.05 * strike, "position": Vector2(9.0 * strike, -2.0 * strike)}
				"recover":
					pose["torso_rot"] = sin(p * TAU) * 0.035 * settle
					pose["push_y"] = -1.5 * settle
		"shard_marshal":
			match phase:
				"windup":
					pose["push_y"] = -2.5 * windup
					pose["squash_x"] = 1.0 + 0.04 * windup
					pose["squash_y"] = 1.0 - 0.03 * windup
					if _parts.has("arm_l"):
						parts["arm_l"] = {"rotation": -1.05 * windup, "position": Vector2(-7.0 * windup, -2.0 * windup)}
					if _parts.has("arm_r"):
						parts["arm_r"] = {"rotation": 1.05 * windup, "position": Vector2(7.0 * windup, -2.0 * windup)}
				"strike":
					pose["push_x"] = 8.0 * strike
					pose["body_rot"] = 0.08 * strike
					if _parts.has("arm_l"):
						parts["arm_l"] = {"rotation": -0.35 * strike, "position": Vector2(7.0 * strike, -1.0 * strike)}
					if _parts.has("arm_r"):
						parts["arm_r"] = {"rotation": 0.35 * strike, "position": Vector2(9.0 * strike, -1.0 * strike)}
				"recover":
					pose["push_y"] = -1.0 * settle
					pose["body_rot"] = -0.02 * settle
		_:
			return {}
	return pose


func _pose_legacy(profile: Dictionary) -> void:
	var phase: float = animation_time
	var step: float = sin(phase)
	var breath: float = sin(phase * 0.45) * (1.0 - _walk_blend)
	var render_sign := _render_sign()
	_pelvis.position = Vector2(0.0, -abs(step) * float(profile.get("bob", 2.2)) * _walk_blend + breath)
	_pelvis.rotation = _direction_pose.x * 0.05 * _walk_blend * render_sign
	_pelvis.scale = Vector2(render_sign, 1.0)
	if state == "death":
		var death_p: float = 1.0 - action_time_left / maxf(action_duration, 0.001)
		_pelvis.rotation += 1.1 * death_p * render_sign
		modulate.a = 1.0 - death_p * 0.9


func _apply_hit_feedback() -> void:
	var tint := status_tint
	if hit_time_left > 0.0:
		tint = Color(1.0, 0.42, 0.36, 1.0)
		_pelvis.position.x += sin(hit_time_left * 60.0) * 1.4
	elif state == "death":
		tint = Color(0.74, 0.72, 0.78, 1.0)
	for part_name in _parts.keys():
		if part_name == "vortex":
			continue
		var sprite := (_parts[part_name] as Node2D).get_node_or_null("Sprite") as Sprite2D
		if sprite != null:
			sprite.modulate = Color(tint.r, tint.g, tint.b, sprite.modulate.a)
	if _hero_full != null:
		_hero_full.modulate = tint


## --- helpers ----------------------------------------------------------------

func _socket_chain_transform() -> Transform2D:
	var chain: Transform2D = _pelvis.transform
	if _figure != null:
		chain = chain * _figure.transform
	if _torso != null:
		chain = chain * _torso.transform
	return chain


func _top_available_parent() -> Node:
	var owner_node := get_parent()
	if owner_node != null and owner_node.get_parent() != null:
		return owner_node.get_parent()
	return owner_node


func _render_sign() -> float:
	# Итоговый знак зеркалирования: куда движется существо × куда смотрит арт.
	return facing_sign * _base_facing


func _attack_part() -> Node2D:
	if _attack_part_name != "" and _parts.has(_attack_part_name):
		return _parts[_attack_part_name]
	return _parts.get("arm_r")


func _is_thrust_variant(variant: String) -> bool:
	return variant.contains("sword") or variant == "strip" or variant == "thrust"


func _is_arc_variant(variant: String) -> bool:
	return variant.contains("axe") or variant == "frustum" or variant == "arc"


func _is_slam_variant(variant: String) -> bool:
	return variant.contains("hammer") or variant == "circle" or variant == "slam"


func _node_name_for_part(part_name: String) -> String:
	match part_name:
		"torso":
			return "Torso"
		"arm_l":
			return "ArmL"
		"arm_r":
			return "ArmR"
		"leg_l":
			return "LegL"
		"leg_r":
			return "LegR"
		"wing_l":
			return "WingL"
		"wing_r":
			return "WingR"
		_:
			return part_name.capitalize()


func _motion_profile() -> Dictionary:
	var profile := {
		"walk_frequency": 7.6,
		"idle_frequency": 1.6,
		"speed_reference": 120.0,
		"bob": 2.4,
		"sway": 0.06,
		"stride": 0.45,
		"arm_swing": 0.34,
		"body_counter": 0.03,
		"foot_lift": 2.6,
		"weight_shift": 0.6,
		"idle_breath": 1.0,
		"squash_x": 0.010,
		"squash_y": 0.008,
		"walk_blend_rate": 6.4,
		"direction_blend_rate": 8.0,
	}
	match _style:
		"heavy", "guard":
			profile.merge({"walk_frequency": 4.8, "bob": 3.6, "stride": 0.30, "arm_swing": 0.18, "foot_lift": 3.2, "squash_x": 0.018, "squash_y": 0.015, "speed_reference": 90.0, "walk_blend_rate": 5.2}, true)
		"beast", "stalker":
			profile.merge({"walk_frequency": 12.0, "bob": 1.8, "stride": 0.50, "arm_swing": 0.42, "foot_lift": 2.2, "speed_reference": 170.0}, true)
		"robed":
			profile.merge({"walk_frequency": 5.0, "bob": 3.0, "stride": 0.0, "arm_swing": 0.14, "idle_breath": 1.3, "walk_blend_rate": 5.0, "direction_blend_rate": 6.0}, true)
		"robed_walker":
			profile.merge({"walk_frequency": 6.6, "bob": 2.6, "stride": 0.28, "arm_swing": 0.20, "walk_blend_rate": 5.4, "direction_blend_rate": 6.8}, true)
		"floating_robed":
			profile.merge({"walk_frequency": 4.2, "idle_frequency": 2.4, "bob": 4.0, "stride": 0.0, "arm_swing": 0.12, "idle_breath": 1.4}, true)
		"flyer":
			profile.merge({"walk_frequency": 9.0, "idle_frequency": 6.0, "bob": 4.6, "stride": 0.0, "arm_swing": 0.16, "flap_rate": 1.4}, true)
		"blob":
			profile.merge({"walk_frequency": 8.6, "bob": 4.2, "stride": 0.22, "arm_swing": 0.0, "speed_reference": 100.0}, true)
		"colossus":
			profile.merge({"walk_frequency": 3.6, "idle_frequency": 1.8, "bob": 4.5, "stride": 0.0, "arm_swing": 0.10, "speed_reference": 70.0}, true)
	match profile_id:
		"berserk":
			profile.merge({"walk_frequency": 5.9, "bob": 3.1, "stride": 0.32, "arm_swing": 0.21, "foot_lift": 2.55, "weight_shift": 0.95, "body_counter": 0.050, "walk_blend_rate": 4.9, "direction_blend_rate": 5.7}, true)
		"soldier":
			profile.merge({"walk_frequency": 6.1, "bob": 2.35, "stride": 0.30, "arm_swing": 0.18, "foot_lift": 2.10, "weight_shift": 0.66, "body_counter": 0.026, "sway": 0.038, "walk_blend_rate": 5.6, "direction_blend_rate": 6.4}, true)
		"thief":
			profile.merge({"walk_frequency": 8.4, "bob": 1.25, "stride": 0.36, "arm_swing": 0.24, "foot_lift": 1.75, "weight_shift": 0.34, "body_counter": 0.044, "sway": 0.062, "idle_breath": 0.84, "walk_blend_rate": 7.3, "direction_blend_rate": 9.0}, true)
		"elementalist":
			profile.merge({"walk_frequency": 6.7, "bob": 1.35, "stride": 0.20, "arm_swing": 0.15, "foot_lift": 1.25, "weight_shift": 0.30, "body_counter": 0.025, "sway": 0.050, "idle_breath": 1.50, "walk_blend_rate": 5.8, "direction_blend_rate": 7.2}, true)
		"sniper":
			profile.merge({"walk_frequency": 5.7, "bob": 1.20, "stride": 0.24, "arm_swing": 0.12, "foot_lift": 1.35, "weight_shift": 0.46, "body_counter": 0.018, "sway": 0.028, "idle_breath": 0.78, "walk_blend_rate": 5.0, "direction_blend_rate": 6.1}, true)
		"priest":
			profile.merge({"walk_frequency": 5.2, "bob": 1.45, "stride": 0.18, "arm_swing": 0.12, "foot_lift": 1.20, "weight_shift": 0.34, "body_counter": 0.020, "sway": 0.036, "idle_breath": 1.42, "walk_blend_rate": 4.8, "direction_blend_rate": 5.8}, true)
		"biologist":
			profile.merge({"walk_frequency": 6.0, "bob": 1.70, "stride": 0.25, "arm_swing": 0.17, "foot_lift": 1.65, "weight_shift": 0.42, "body_counter": 0.030, "sway": 0.034, "idle_breath": 1.18, "walk_blend_rate": 5.3, "direction_blend_rate": 6.4}, true)
		"robot":
			profile.merge({"walk_frequency": 3.8, "bob": 3.85, "stride": 0.22, "arm_swing": 0.10, "foot_lift": 3.10, "weight_shift": 0.92, "body_counter": 0.032, "sway": 0.020, "idle_breath": 0.42, "squash_x": 0.014, "squash_y": 0.012, "speed_reference": 82.0, "walk_blend_rate": 4.0, "direction_blend_rate": 4.6}, true)
		"engineer":
			profile.merge({"walk_frequency": 5.9, "bob": 2.05, "stride": 0.27, "arm_swing": 0.18, "foot_lift": 1.85, "weight_shift": 0.54, "body_counter": 0.032, "sway": 0.040, "idle_breath": 1.05, "walk_blend_rate": 5.2, "direction_blend_rate": 6.2}, true)
		"dark_mage":
			profile.merge({"walk_frequency": 5.0, "bob": 1.55, "stride": 0.18, "arm_swing": 0.11, "foot_lift": 1.35, "weight_shift": 0.38, "idle_breath": 1.28, "sway": 0.032, "walk_blend_rate": 4.4, "direction_blend_rate": 5.1}, true)
		"guitarist":
			profile.merge({"walk_frequency": 7.4, "bob": 1.85, "stride": 0.34, "arm_swing": 0.30, "foot_lift": 1.95, "weight_shift": 0.58, "walk_blend_rate": 6.8, "direction_blend_rate": 7.6}, true)
		"assassin":
			profile.merge({"walk_frequency": 9.2, "bob": 1.45, "stride": 0.46, "arm_swing": 0.39, "foot_lift": 2.15, "weight_shift": 0.48, "body_counter": 0.055, "sway": 0.075, "walk_blend_rate": 8.0, "direction_blend_rate": 9.2}, true)
		"ranger":
			profile.merge({"walk_frequency": 6.9, "bob": 1.75, "stride": 0.39, "arm_swing": 0.24, "foot_lift": 1.85, "weight_shift": 0.52, "body_counter": 0.035, "sway": 0.045, "walk_blend_rate": 6.2, "direction_blend_rate": 7.4}, true)
		"doctor":
			profile.merge({"walk_frequency": 5.4, "bob": 1.65, "stride": 0.22, "arm_swing": 0.16, "foot_lift": 1.55, "weight_shift": 0.36, "idle_breath": 1.34, "sway": 0.030, "walk_blend_rate": 4.7, "direction_blend_rate": 5.6}, true)
		"chemist":
			profile.merge({"walk_frequency": 6.4, "bob": 2.15, "stride": 0.29, "arm_swing": 0.22, "foot_lift": 1.90, "weight_shift": 0.50, "idle_breath": 1.22, "sway": 0.046, "walk_blend_rate": 5.9, "direction_blend_rate": 6.6}, true)
		"knight":
			profile.merge({"walk_frequency": 4.4, "bob": 3.45, "stride": 0.25, "arm_swing": 0.14, "foot_lift": 3.05, "weight_shift": 0.88, "body_counter": 0.040, "squash_x": 0.016, "squash_y": 0.013, "speed_reference": 92.0, "walk_blend_rate": 4.4, "direction_blend_rate": 4.9}, true)
		"druid":
			profile.merge({"walk_frequency": 5.8, "bob": 2.05, "stride": 0.24, "arm_swing": 0.18, "foot_lift": 1.75, "weight_shift": 0.44, "idle_breath": 1.42, "sway": 0.040, "walk_blend_rate": 5.2, "direction_blend_rate": 6.0}, true)
	if is_elite_rig:
		profile["bob"] = float(profile["bob"]) * 1.12
		profile["arm_swing"] = float(profile["arm_swing"]) * 1.12
	return profile


func _profile_asset_key() -> String:
	var normalized := profile_id.to_lower().replace(" ", "_")
	return str(RIG_PART_ALIASES.get(normalized, normalized))


func _action_duration(new_action_id: String) -> float:
	match new_action_id:
		"attack":
			return 0.34
		"cast":
			return 0.52
		"shoot":
			return 0.26
		"death":
			return 0.55
		_:
			return 0.2


func _soft_signed(value: float) -> float:
	var amount: float = abs(value)
	return signf(value) * (1.0 - pow(1.0 - amount, 2.0))


func _ellipse_points(radius_x: float, radius_y: float, point_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(point_count):
		var angle := TAU * float(index) / float(point_count)
		points.append(Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points
