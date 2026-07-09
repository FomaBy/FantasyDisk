extends RefCounted
class_name FullFrameAnimationRegistry

# Back-end runtime registry for optional full-frame SpriteFrames.
# Gameplay remains source of truth: this helper only chooses/plays visual states
# when Animator/Design assets exist, and returns false/null for safe fallback.

const DEFAULT_ANIMATED_BODY_NAME := "FullFrameBody"
const DEFAULT_STATIC_BODY_NAME := "Body"

const FULL_FRAME_SPRITEFRAMES := {
	"ally": {
		"druid_beast": {
			"frames": "res://assets/sprites/allies/ally_druid_wolf_spriteframes.tres",
			"scale": Vector2(0.37, 0.37),
			"position": Vector2(0.0, -37.0),
			"source_faces_left": true,
		},
		"druid_pack_spirit": {
			"frames": "res://assets/sprites/allies/ally_pack_spirit_spriteframes.tres",
			"scale": Vector2(0.34, 0.34),
			"position": Vector2(0.0, -10.0),
			"source_faces_left": true,
		},
		"homunculus": {
			"frames": "res://assets/sprites/allies/ally_homunculus_spriteframes.tres",
			"scale": Vector2(0.34, 0.34),
			"position": Vector2(0.0, -10.0),
			"source_faces_left": true,
		},
		"leadership_echo": {
			"frames": "res://assets/sprites/allies/ally_leadership_echo_spriteframes.tres",
			"scale": Vector2(0.34, 0.34),
			"position": Vector2(0.0, -10.0),
			"source_faces_left": true,
		},
		"druid_ghost_wolf": {
			"frames": "res://assets/sprites/allies/ally_druid_ghost_wolf_spriteframes.tres",
			"scale": Vector2(0.42, 0.42),
			"position": Vector2(0.0, -44.0),
			"explicit_horizontal_directions": true,
		},
		"druid_ghost_bear": {
			"frames": "res://assets/sprites/allies/ally_druid_ghost_bear_spriteframes.tres",
			"scale": Vector2(0.40, 0.40),
			"position": Vector2(0.0, -42.0),
			"explicit_horizontal_directions": true,
		},
		"druid_ghost_panther": {
			"frames": "res://assets/sprites/allies/ally_druid_ghost_panther_spriteframes.tres",
			"scale": Vector2(0.43, 0.43),
			"position": Vector2(0.0, -45.0),
			"explicit_horizontal_directions": true,
		},
		"druid_ghost_stag": {
			"frames": "res://assets/sprites/allies/ally_druid_ghost_stag_spriteframes.tres",
			"scale": Vector2(0.40, 0.40),
			"position": Vector2(0.0, -42.0),
			"explicit_horizontal_directions": true,
		},
		"druid_ghost_lion": {
			"frames": "res://assets/sprites/allies/ally_druid_ghost_lion_spriteframes.tres",
			"scale": Vector2(0.41, 0.41),
			"position": Vector2(0.0, -43.0),
			"explicit_horizontal_directions": true,
		},
	},
	"enemy": {
		"rift_cutter": {
			"frames": "res://assets/sprites/enemies/full_frame/rift_cutter_spriteframes.tres",
			"scale": Vector2(0.38, 0.38),
			"position": Vector2(0.0, -44.0),
			"source_faces_left": true,
		},
		"ash_marksman": {
			"frames": "res://assets/sprites/enemies/full_frame/ash_marksman_spriteframes.tres",
			"scale": Vector2(0.36, 0.36),
			"position": Vector2(0.0, -42.0),
			"source_faces_left": true,
		},
		"spark_runner": {
			"frames": "res://assets/sprites/enemies/full_frame/spark_runner_spriteframes.tres",
			"scale": Vector2(0.34, 0.34),
			"position": Vector2(0.0, -38.0),
			"source_faces_left": true,
		},
		"stone_bruiser": {
			"frames": "res://assets/sprites/enemies/full_frame/stone_bruiser_spriteframes.tres",
			"scale": Vector2(0.42, 0.42),
			"position": Vector2(0.0, -52.0),
			"source_faces_left": true,
		},
		"bone_caller": {
			"frames": "res://assets/sprites/enemies/full_frame/bone_caller_spriteframes.tres",
			"scale": Vector2(0.36, 0.36),
			"position": Vector2(0.0, -44.0),
			"source_faces_left": true,
		},
		"void_mage": {
			"frames": "res://assets/sprites/enemies/full_frame/void_mage_spriteframes.tres",
			"scale": Vector2(0.36, 0.36),
			"position": Vector2(0.0, -44.0),
			"source_faces_left": true,
		},
		"venom_spitter": {
			"frames": "res://assets/sprites/enemies/full_frame/venom_spitter_spriteframes.tres",
			"scale": Vector2(0.36, 0.36),
			"position": Vector2(0.0, -42.0),
			"source_faces_left": true,
		},
		"rift_shieldbearer": {
			"frames": "res://assets/sprites/enemies/full_frame/rift_shieldbearer_spriteframes.tres",
			"scale": Vector2(0.42, 0.42),
			"position": Vector2(0.0, -50.0),
			"source_faces_left": true,
		},
		"small_biter": {
			"frames": "res://assets/sprites/enemies/full_frame/small_biter_spriteframes.tres",
			"scale": Vector2(0.30, 0.30),
			"position": Vector2(0.0, -32.0),
			"source_faces_left": true,
		},
		"bone_shaman": {
			"frames": "res://assets/sprites/enemies/full_frame/bone_shaman_spriteframes.tres",
			"scale": Vector2(0.36, 0.36),
			"position": Vector2(0.0, -44.0),
			"source_faces_left": true,
		},
		"winged_spark": {
			"frames": "res://assets/sprites/enemies/full_frame/winged_spark_spriteframes.tres",
			"scale": Vector2(0.32, 0.32),
			"position": Vector2(0.0, -42.0),
			"source_faces_left": true,
		},
	},
	"elite": {
		"iron_bastion": {
			"frames": "res://assets/sprites/elites/full_frame/iron_bastion_spriteframes.tres",
			"scale": Vector2(0.70, 0.70),
			"position": Vector2(0.0, -82.0),
			"source_faces_left": true,
		},
		"night_stalker": {
			"frames": "res://assets/sprites/elites/full_frame/night_stalker_spriteframes.tres",
			"scale": Vector2(0.62, 0.62),
			"position": Vector2(0.0, -76.0),
			"source_faces_left": true,
		},
		"plague_prophet": {
			"frames": "res://assets/sprites/elites/full_frame/plague_prophet_spriteframes.tres",
			"scale": Vector2(0.66, 0.66),
			"position": Vector2(0.0, -78.0),
			"source_faces_left": true,
		},
		"shard_marshal": {
			"frames": "res://assets/sprites/elites/full_frame/shard_marshal_spriteframes.tres",
			"scale": Vector2(0.66, 0.66),
			"position": Vector2(0.0, -78.0),
			"source_faces_left": true,
		},
		"mini_scavenger_reaper": {
			"frames": "res://assets/sprites/elites/full_frame/mini_scavenger_reaper_spriteframes.tres",
			"scale": Vector2(0.50, 0.50),
			"position": Vector2(0.0, -58.0),
			"source_faces_left": true,
		},
		"mini_plague_bellringer": {
			"frames": "res://assets/sprites/elites/full_frame/mini_plague_bellringer_spriteframes.tres",
			"scale": Vector2(0.50, 0.50),
			"position": Vector2(0.0, -60.0),
			"source_faces_left": true,
		},
		"mini_bone_warden": {
			"frames": "res://assets/sprites/elites/full_frame/mini_bone_warden_spriteframes.tres",
			"scale": Vector2(0.52, 0.52),
			"position": Vector2(0.0, -62.0),
			"source_faces_left": true,
		},
		"mini_spark_wight": {
			"frames": "res://assets/sprites/elites/full_frame/mini_spark_wight_spriteframes.tres",
			"scale": Vector2(0.50, 0.50),
			"position": Vector2(0.0, -58.0),
			"source_faces_left": true,
		},
		"mini_rot_hound": {
			"frames": "res://assets/sprites/elites/full_frame/mini_rot_hound_spriteframes.tres",
			"scale": Vector2(0.48, 0.48),
			"position": Vector2(0.0, -54.0),
			"source_faces_left": true,
		},
		"mini_shadow_devourer": {
			"frames": "res://assets/sprites/elites/full_frame/mini_shadow_devourer_spriteframes.tres",
			"scale": Vector2(0.50, 0.50),
			"position": Vector2(0.0, -58.0),
			"source_faces_left": true,
		},
	},
	"boss": {
		"rift_warden": {
			"frames": "res://assets/sprites/bosses/full_frame/rift_warden_spriteframes.tres",
			"scale": Vector2(0.74, 0.74),
			"position": Vector2(0.0, -86.0),
			"source_faces_left": true,
		},
		"disk_devourer": {
			"frames": "res://assets/sprites/bosses/full_frame/disk_devourer_spriteframes.tres",
			"scale": Vector2(0.78, 0.78),
			"position": Vector2(0.0, -90.0),
			"source_faces_left": true,
		},
		"bone_archon": {
			"frames": "res://assets/sprites/bosses/full_frame/bone_archon_spriteframes.tres",
			"scale": Vector2(0.76, 0.76),
			"position": Vector2(0.0, -88.0),
			"source_faces_left": true,
		},
		"brood_mother": {
			"frames": "res://assets/sprites/bosses/full_frame/brood_mother_spriteframes.tres",
			"scale": Vector2(0.78, 0.78),
			"position": Vector2(0.0, -88.0),
			"source_faces_left": true,
		},
		"ashen_colossus": {
			"frames": "res://assets/sprites/bosses/full_frame/ashen_colossus_spriteframes.tres",
			"scale": Vector2(0.82, 0.82),
			"position": Vector2(0.0, -94.0),
			"source_faces_left": true,
		},
		"bloodthorn_lion": {
			"frames": "res://assets/sprites/bosses/full_frame/bloodthorn_lion_spriteframes.tres",
			"scale": Vector2(0.78, 0.78),
			"position": Vector2(0.0, -88.0),
			"source_faces_left": true,
		},
	},
	"hero": {},
}

const STATE_ALIASES := {
	"idle": ["idle", "move", "walk"],
	"move": ["move", "walk", "run", "levitate", "idle"],
	"walk": ["walk", "move", "run", "levitate", "idle"],
	"run": ["run", "move", "walk", "levitate", "idle"],
	"attack": ["attack", "attack_primary", "cast", "shoot", "move"],
	"attack_primary": ["attack_primary", "attack", "cast", "shoot", "move"],
	"cast": ["cast", "attack", "attack_primary", "move"],
	"shoot": ["shoot", "attack", "attack_primary", "move"],
	"hit": ["hit", "hurt", "damage", "idle", "move"],
	"death": ["death", "die", "idle", "move"],
}


static func registry_config(entity_kind: String, entity_id: String) -> Dictionary:
	var kind_table: Dictionary = FULL_FRAME_SPRITEFRAMES.get(entity_kind, {})
	return (kind_table.get(entity_id, {}) as Dictionary).duplicate(true)


static func sprite_frames_for(entity_kind: String, entity_id: String) -> SpriteFrames:
	var config := registry_config(entity_kind, entity_id)
	var frames_path := str(config.get("frames", ""))
	if frames_path == "" or not ResourceLoader.exists(frames_path):
		return null
	return load(frames_path) as SpriteFrames


static func configure_entity_visual(owner: Node2D, entity_kind: String, entity_id: String, animated_body_name := DEFAULT_ANIMATED_BODY_NAME, static_body_name := DEFAULT_STATIC_BODY_NAME) -> AnimatedSprite2D:
	if owner == null:
		return null
	var config := registry_config(entity_kind, entity_id)
	if config.is_empty() and owner.has_meta("full_frame_spriteframes_path"):
		config = {
			"frames": str(owner.get_meta("full_frame_spriteframes_path")),
			"scale": owner.get_meta("full_frame_scale", Vector2.ONE),
			"position": owner.get_meta("full_frame_position", Vector2.ZERO),
			"source_faces_left": bool(owner.get_meta("full_frame_source_faces_left", true)),
		}
	if config.is_empty():
		return null

	var frames_path := str(config.get("frames", ""))
	if frames_path == "" or not ResourceLoader.exists(frames_path):
		return null
	var frames := load(frames_path) as SpriteFrames
	if frames == null:
		return null

	var animated_body := owner.get_node_or_null(animated_body_name) as AnimatedSprite2D
	if animated_body == null:
		animated_body = AnimatedSprite2D.new()
		animated_body.name = animated_body_name
		owner.add_child(animated_body)
	animated_body.sprite_frames = frames
	animated_body.scale = config.get("scale", Vector2.ONE)
	animated_body.position = config.get("position", Vector2.ZERO)
	animated_body.visible = true
	animated_body.set_meta("entity_kind", entity_kind)
	animated_body.set_meta("entity_id", entity_id)
	animated_body.set_meta("source_faces_left", bool(config.get("source_faces_left", true)))
	animated_body.set_meta("explicit_horizontal_directions", bool(config.get("explicit_horizontal_directions", false)))

	var static_body := owner.get_node_or_null(static_body_name) as CanvasItem
	if static_body != null:
		static_body.visible = false

	play_state(animated_body, "move", Vector2.ZERO)
	return animated_body


static func play_state(animated_body: AnimatedSprite2D, requested_state: String, direction := Vector2.ZERO) -> bool:
	if animated_body == null or animated_body.sprite_frames == null:
		return false
	var uses_explicit_horizontal := bool(animated_body.get_meta("explicit_horizontal_directions", false))
	var state_name := ""
	if uses_explicit_horizontal and absf(direction.x) > 0.001:
		state_name = _resolve_horizontal_animation_name(animated_body.sprite_frames, requested_state, direction.x > 0.0)
	if state_name == "":
		state_name = _resolve_animation_name(animated_body.sprite_frames, requested_state)
	if state_name == "":
		return false
	if uses_explicit_horizontal:
		animated_body.flip_h = false
	elif direction.length_squared() > 0.001:
		var source_faces_left := bool(animated_body.get_meta("source_faces_left", true))
		animated_body.flip_h = direction.x > 0.0 if source_faces_left else direction.x < 0.0
	animated_body.set_meta("last_requested_state", requested_state)
	animated_body.set_meta("last_resolved_state", state_name)
	if animated_body.animation != state_name or not animated_body.is_playing():
		animated_body.play(state_name)
	return true


static func has_state(animated_body: AnimatedSprite2D, requested_state: String) -> bool:
	if animated_body == null or animated_body.sprite_frames == null:
		return false
	return _resolve_animation_name(animated_body.sprite_frames, requested_state) != ""


static func uses_explicit_horizontal_directions(animated_body: AnimatedSprite2D) -> bool:
	return animated_body != null and bool(animated_body.get_meta("explicit_horizontal_directions", false))


static func _resolve_horizontal_animation_name(frames: SpriteFrames, requested_state: String, faces_right: bool) -> String:
	if frames == null:
		return ""
	var suffix := "right" if faces_right else "left"
	for candidate in _state_candidates(requested_state):
		var directional_candidate := "%s_%s" % [candidate, suffix]
		if frames.has_animation(directional_candidate):
			return directional_candidate
	return ""


static func _resolve_animation_name(frames: SpriteFrames, requested_state: String) -> String:
	if frames == null:
		return ""
	var candidates := _state_candidates(requested_state)
	for candidate in candidates:
		if frames.has_animation(candidate):
			return candidate
	return ""


static func _state_candidates(requested_state: String) -> Array:
	var normalized := requested_state.strip_edges().to_lower()
	var candidates := []
	if normalized != "":
		candidates.append(normalized)
	if normalized.contains(":"):
		for part in normalized.split(":", false):
			if part != "":
				candidates.append(part)
				candidates.append("skill_%s" % part)
				candidates.append("attack_%s" % part)
	if normalized.begins_with("attack_"):
		candidates.append("attack")
		candidates.append("attack_primary")
	if normalized.begins_with("skill_"):
		candidates.append("cast")
		candidates.append("attack")
	if STATE_ALIASES.has(normalized):
		candidates.append_array(STATE_ALIASES[normalized])
	for generic_state in ["attack", "cast", "shoot", "hit", "death", "move", "idle"]:
		if normalized.contains(generic_state):
			candidates.append_array(STATE_ALIASES.get(generic_state, [generic_state]))
	candidates.append_array(["move", "idle"])
	var deduped := []
	for candidate in candidates:
		if candidate != "" and not deduped.has(candidate):
			deduped.append(candidate)
	return deduped
