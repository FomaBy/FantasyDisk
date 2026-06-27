extends Node2D

const SOURCE_CANVAS_SIZE := Vector2(512.0, 512.0)
const SOURCE_CENTER := SOURCE_CANVAS_SIZE * 0.5

@export var entity_id := ""
@export var manifest_path := ""
@export var base_scale := Vector2(0.5, 0.5)

var active_animation := ""
var _manifest := {}
var _skeleton: Skeleton2D = null
var _animation_player: AnimationPlayer = null
var _bones := {}
var _bone_rest_positions := {}
var _bone_rest_rotations := {}
var _z_order := {}
var _facing_sign := 1.0


func _ready() -> void:
	if manifest_path != "":
		configure(manifest_path, entity_id, base_scale)


func configure(new_manifest_path: String, new_entity_id := "", new_base_scale := Vector2(0.5, 0.5)) -> void:
	manifest_path = new_manifest_path
	entity_id = new_entity_id
	base_scale = new_base_scale
	_manifest = _load_manifest(manifest_path)
	if _manifest.is_empty():
		visible = false
		return
	if entity_id == "":
		entity_id = str(_manifest.get("entity_id", ""))
	_build_rig()
	_build_animation_player()
	update_animation(0.0, Vector2.ZERO, Vector2.RIGHT)


func update_animation(delta: float, velocity: Vector2, facing_direction := Vector2.RIGHT) -> void:
	if _animation_player == null:
		return
	if abs(facing_direction.x) > 0.05:
		_facing_sign = -1.0 if facing_direction.x < 0.0 else 1.0
	scale = Vector2(base_scale.x * _facing_sign, base_scale.y)
	var target_animation := "walk" if velocity.length_squared() > 0.001 else "idle"
	if target_animation != active_animation:
		active_animation = target_animation
		_animation_player.play(target_animation)
	_animation_player.advance(maxf(delta, 0.0))


func play_hit() -> void:
	var tween := create_tween()
	modulate = Color(1.0, 0.45, 0.45, 1.0)
	tween.tween_property(self, "modulate", Color.WHITE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func play_action(_action_id: String, _direction := Vector2.RIGHT, _variant := "", _duration := 0.0) -> void:
	# SCRUM-474 explicitly keeps body attack animation out of scope: weapon
	# scenes own attack visuals and the player weapon socket keeps orbiting.
	pass


func animation_player() -> AnimationPlayer:
	return _animation_player


func bone_names() -> Array:
	return _bones.keys()


func _load_manifest(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		push_warning("Skeleton source manifest missing: %s" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		push_warning("Skeleton source manifest is not a dictionary: %s" % path)
		return {}
	return parsed as Dictionary


func _build_rig() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_bones.clear()
	_bone_rest_positions.clear()
	_bone_rest_rotations.clear()
	_z_order.clear()
	visible = true
	modulate = Color.WHITE
	scale = base_scale

	var order: Array = _manifest.get("z_order_hint_back_to_front", [])
	for index in range(order.size()):
		_z_order[str(order[index])] = index

	_skeleton = Skeleton2D.new()
	_skeleton.name = "Skeleton2D"
	add_child(_skeleton)

	var root_source := _source_point("root_pivot_source", SOURCE_CENTER)
	var root := _spawn_bone("root", "Root", _skeleton, root_source - SOURCE_CENTER)
	root.set_meta("root_pivot_source", root_source)

	var pelvis := _spawn_part_bone("pelvis", "Pelvis", root, root_source)
	var torso := _spawn_part_bone("torso", "Torso", pelvis, _source_point("pelvis", root_source))
	_spawn_part_bone("head", "Head", torso, _source_point("torso", root_source))

	_spawn_limb("l", torso, pelvis)
	_spawn_limb("r", torso, pelvis)
	_spawn_optional_parts(torso, pelvis)

	var marker := Node2D.new()
	marker.name = "WeaponSocketMarker"
	marker.position = _source_point("hand_r", _source_point("torso", root_source)) - _source_point("torso", root_source)
	torso.add_child(marker)
	marker.set_meta("socket_behavior", "runtime_orbit_preserved")


func _spawn_limb(side: String, torso: Bone2D, pelvis: Bone2D) -> void:
	var suffix := "_%s" % side
	var upper_arm := _spawn_part_bone("upper_arm%s" % suffix, "UpperArm%s" % side.to_upper(), torso, _source_point("torso", Vector2.ZERO))
	var lower_arm := _spawn_part_bone("lower_arm%s" % suffix, "LowerArm%s" % side.to_upper(), upper_arm, _source_point("upper_arm%s" % suffix, Vector2.ZERO))
	_spawn_part_bone("hand%s" % suffix, "Hand%s" % side.to_upper(), lower_arm, _source_point("lower_arm%s" % suffix, Vector2.ZERO))

	var thigh := _spawn_part_bone("thigh%s" % suffix, "Thigh%s" % side.to_upper(), pelvis, _source_point("pelvis", Vector2.ZERO))
	var shin := _spawn_part_bone("shin%s" % suffix, "Shin%s" % side.to_upper(), thigh, _source_point("thigh%s" % suffix, Vector2.ZERO))
	_spawn_part_bone("foot%s" % suffix, "Foot%s" % side.to_upper(), shin, _source_point("shin%s" % suffix, Vector2.ZERO))


func _spawn_optional_parts(torso: Bone2D, pelvis: Bone2D) -> void:
	var parts: Dictionary = _manifest.get("parts", {})
	for part_name in parts.keys():
		var key := str(part_name)
		if _bones.has(key):
			continue
		var parent := torso
		var parent_key := "torso"
		if key.begins_with("robe") or key.begins_with("cape") or key.begins_with("cloak"):
			parent = pelvis if key.begins_with("robe") else torso
			parent_key = "pelvis" if key.begins_with("robe") else "torso"
		elif key.begins_with("hood"):
			parent = _bones.get("head", torso)
			parent_key = "head"
		_spawn_part_bone(key, _node_name_for_part(key), parent, _source_point(parent_key, Vector2.ZERO))


func _spawn_part_bone(part_name: String, node_name: String, parent: Node, parent_source: Vector2) -> Bone2D:
	var source := _source_point(part_name, parent_source)
	var bone := _spawn_bone(part_name, node_name, parent, source - parent_source)
	_attach_part_sprite(part_name, bone)
	return bone


func _spawn_bone(part_name: String, node_name: String, parent: Node, position: Vector2) -> Bone2D:
	var bone := Bone2D.new()
	bone.name = node_name
	bone.position = position
	bone.z_index = int(_z_order.get(part_name, 0))
	parent.add_child(bone)
	_bones[part_name] = bone
	_bone_rest_positions[part_name] = bone.position
	_bone_rest_rotations[part_name] = bone.rotation
	return bone


func _attach_part_sprite(part_name: String, bone: Bone2D) -> void:
	var parts: Dictionary = _manifest.get("parts", {})
	if not parts.has(part_name):
		return
	var texture_path := "%s/%s" % [manifest_path.get_base_dir(), str(parts[part_name])]
	var texture := load(texture_path) as Texture2D
	if texture == null:
		push_warning("Skeleton rig part texture missing: %s" % texture_path)
		return
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	sprite.centered = false
	sprite.position = -_local_pivot(part_name)
	sprite.z_index = int(_z_order.get(part_name, 0))
	bone.add_child(sprite)
	bone.set_meta("part_texture", texture_path)
	bone.set_meta("source_pivot", _source_point(part_name, Vector2.ZERO))
	bone.set_meta("local_pivot", _local_pivot(part_name))


func _build_animation_player() -> void:
	_animation_player = AnimationPlayer.new()
	_animation_player.name = "AnimationPlayer"
	_animation_player.root_node = NodePath("..")
	add_child(_animation_player)

	var library := AnimationLibrary.new()
	library.add_animation("idle", _make_idle_animation())
	library.add_animation("walk", _make_walk_animation("walk"))
	library.add_animation("move", _make_walk_animation("move"))
	_animation_player.add_animation_library("", library)
	_animation_player.play("idle")


func _make_idle_animation() -> Animation:
	var anim := Animation.new()
	anim.length = 1.0
	anim.loop_mode = Animation.LOOP_LINEAR
	_add_vector_track(anim, _bone("root"), "position", [
		[0.00, _rest_pos("root")],
		[0.25, _rest_pos("root") + Vector2(0.0, -2.0)],
		[0.50, _rest_pos("root") + Vector2(0.0, -3.0)],
		[0.75, _rest_pos("root") + Vector2(0.0, -2.0)],
		[1.00, _rest_pos("root")],
	])
	_add_float_track(anim, _bone("torso"), "rotation", [[0.0, 0.0], [0.5, 0.025], [1.0, 0.0]])
	_add_float_track(anim, _bone("head"), "rotation", [[0.0, 0.0], [0.5, -0.018], [1.0, 0.0]])
	for part_name in ["cloak_back_l", "cloak_back_r", "cape_l", "cape_r", "robe_front"]:
		if _bones.has(part_name):
			_add_float_track(anim, _bone(part_name), "rotation", [[0.0, -0.02], [0.5, 0.025], [1.0, -0.02]])
	return anim


func _make_walk_animation(_name: String) -> Animation:
	var anim := Animation.new()
	anim.length = 0.8
	anim.loop_mode = Animation.LOOP_LINEAR
	var keys := [0.0, 0.2, 0.4, 0.6, 0.8]
	_add_vector_track(anim, _bone("root"), "position", [
		[keys[0], _rest_pos("root") + Vector2(0.0, 0.0)],
		[keys[1], _rest_pos("root") + Vector2(1.5, -4.0)],
		[keys[2], _rest_pos("root") + Vector2(0.0, -1.5)],
		[keys[3], _rest_pos("root") + Vector2(-1.5, -4.0)],
		[keys[4], _rest_pos("root") + Vector2(0.0, 0.0)],
	])
	_add_float_track(anim, _bone("torso"), "rotation", [[0.0, -0.035], [0.2, 0.025], [0.4, 0.035], [0.6, -0.025], [0.8, -0.035]])
	_add_float_track(anim, _bone("head"), "rotation", [[0.0, 0.02], [0.2, -0.018], [0.4, -0.02], [0.6, 0.018], [0.8, 0.02]])
	_add_walk_limb_tracks(anim, "l", 1.0)
	_add_walk_limb_tracks(anim, "r", -1.0)
	for part_name in ["cloak_back_l", "cloak_back_r", "cape_l", "cape_r", "robe_front"]:
		if _bones.has(part_name):
			_add_float_track(anim, _bone(part_name), "rotation", [[0.0, 0.05], [0.2, -0.035], [0.4, -0.05], [0.6, 0.035], [0.8, 0.05]])
	return anim


func _add_walk_limb_tracks(anim: Animation, side: String, phase: float) -> void:
	var suffix := "_%s" % side
	var upper_arm := "upper_arm%s" % suffix
	var lower_arm := "lower_arm%s" % suffix
	var thigh := "thigh%s" % suffix
	var shin := "shin%s" % suffix
	var foot := "foot%s" % suffix
	if _bones.has(upper_arm):
		_add_float_track(anim, _bone(upper_arm), "rotation", [[0.0, 0.20 * phase], [0.2, -0.15 * phase], [0.4, -0.20 * phase], [0.6, 0.15 * phase], [0.8, 0.20 * phase]])
	if _bones.has(lower_arm):
		_add_float_track(anim, _bone(lower_arm), "rotation", [[0.0, -0.08 * phase], [0.2, 0.10 * phase], [0.4, 0.08 * phase], [0.6, -0.10 * phase], [0.8, -0.08 * phase]])
	if _bones.has(thigh):
		_add_float_track(anim, _bone(thigh), "rotation", [[0.0, -0.18 * phase], [0.2, 0.26 * phase], [0.4, 0.18 * phase], [0.6, -0.26 * phase], [0.8, -0.18 * phase]])
	if _bones.has(shin):
		_add_float_track(anim, _bone(shin), "rotation", [[0.0, 0.16 * phase], [0.2, -0.12 * phase], [0.4, -0.16 * phase], [0.6, 0.12 * phase], [0.8, 0.16 * phase]])
	if _bones.has(foot):
		_add_float_track(anim, _bone(foot), "rotation", [[0.0, 0.05 * phase], [0.2, -0.10 * phase], [0.4, -0.05 * phase], [0.6, 0.10 * phase], [0.8, 0.05 * phase]])


func _add_vector_track(anim: Animation, node: Node, property_name: String, keys: Array) -> void:
	if node == null:
		return
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath("%s:%s" % [str(get_path_to(node)), property_name]))
	for key in keys:
		anim.track_insert_key(track, float(key[0]), key[1])


func _add_float_track(anim: Animation, node: Node, property_name: String, keys: Array) -> void:
	if node == null:
		return
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath("%s:%s" % [str(get_path_to(node)), property_name]))
	for key in keys:
		anim.track_insert_key(track, float(key[0]), float(key[1]))


func _source_point(key: String, fallback: Vector2) -> Vector2:
	if key == "root_pivot_source":
		return _dict_point(_manifest.get("root_pivot_source", {}), fallback)
	var source_pivots: Dictionary = _manifest.get("source_pivots", {})
	return _dict_point(source_pivots.get(key, {}), fallback)


func _local_pivot(part_name: String) -> Vector2:
	var pivots: Dictionary = _manifest.get("pivots", {})
	return _dict_point(pivots.get(part_name, {}), Vector2.ZERO)


func _dict_point(value, fallback: Vector2) -> Vector2:
	if not (value is Dictionary):
		return fallback
	var point := value as Dictionary
	return Vector2(float(point.get("x", fallback.x)), float(point.get("y", fallback.y)))


func _node_name_for_part(part_name: String) -> String:
	var output := ""
	for chunk in part_name.split("_", false):
		output += chunk.capitalize()
	return output


func _bone(part_name: String) -> Bone2D:
	return _bones.get(part_name) as Bone2D


func _rest_pos(part_name: String) -> Vector2:
	return _bone_rest_positions.get(part_name, Vector2.ZERO)
