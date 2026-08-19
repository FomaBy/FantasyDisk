extends SceneTree

const FullFrameAnimationRegistry := preload("res://scripts/full_frame_animation_registry.gd")
const ProgressionData := preload("res://scripts/progression_data.gd")
const EXPECTED_PLAYER_COMBAT_VISUAL_SCALE := Vector2(0.64, 0.64)  # SCRUM-823: lock-step with player.gd visual-only bump.


var _failed := false


func _initialize() -> void:
	_test_player_animation()
	_test_enemy_projectile_sprite()
	_test_enemy_sprite_paths()
	_test_druid_wolf_ally_animation()
	_test_druid_ghost_horizontal_ally_animations()
	_test_character_full_frame_alpha_matte()
	_test_full_frame_animation_registry()
	_test_enemy_animation()
	_test_flying_elite_boss_rigs()
	_test_elite_attack_phase_animation()
	_test_hit_death_states()
	_test_death_ghost()
	if _failed:
		quit(1)
		return
	print("Animation smoke test passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	_failed = true


func _test_character_full_frame_alpha_matte() -> void:
	for character_id in ProgressionData.character_ids():
		var path := "res://assets/sprites/characters/full_frame/%s/%s_idle_00.png" % [character_id, character_id]
		var image := Image.new()
		var err := image.load(ProjectSettings.globalize_path(path))
		if err != OK:
			_fail("Expected representative full-frame alpha smoke image to load: %s." % path)
			return
		var edge_white := _alpha_smoke_edge_white_pixels(image)
		var floodable_matte := _alpha_smoke_floodable_background(image)
		if edge_white != 0 or floodable_matte > 1500:
			_fail("Expected %s to have transparent matte-free edges; edge_white=%d floodable_matte=%d." % [path, edge_white, floodable_matte])
			return


func _alpha_smoke_background_candidate(color: Color) -> bool:
	var alpha := int(round(color.a * 255.0))
	if alpha <= 8:
		return false
	var r := int(round(color.r * 255.0))
	var g := int(round(color.g * 255.0))
	var b := int(round(color.b * 255.0))
	var hi := maxi(r, maxi(g, b))
	var lo := mini(r, mini(g, b))
	var neutral_white := hi >= 224 and lo >= 216 and hi - lo <= 42
	var checker_black := alpha >= 220 and hi <= 20 and hi - lo <= 8
	return neutral_white or checker_black


func _alpha_smoke_visible_bbox(image: Image) -> Array:
	var x0 := image.get_width()
	var y0 := image.get_height()
	var x1 := -1
	var y1 := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if int(round(image.get_pixel(x, y).a * 255.0)) <= 8:
				continue
			x0 = mini(x0, x)
			y0 = mini(y0, y)
			x1 = maxi(x1, x + 1)
			y1 = maxi(y1, y + 1)
	if x1 < 0 or y1 < 0:
		return []
	return [x0, y0, x1, y1]


func _alpha_smoke_neighbors(point: Vector2i, width: int, height: int) -> Array:
	var neighbors := []
	if point.x > 0:
		neighbors.append(Vector2i(point.x - 1, point.y))
	if point.x + 1 < width:
		neighbors.append(Vector2i(point.x + 1, point.y))
	if point.y > 0:
		neighbors.append(Vector2i(point.x, point.y - 1))
	if point.y + 1 < height:
		neighbors.append(Vector2i(point.x, point.y + 1))
	return neighbors


func _alpha_smoke_seed_points(image: Image, bbox: Array) -> Array:
	var width := image.get_width()
	var height := image.get_height()
	var x0: int = bbox[0]
	var y0: int = bbox[1]
	var x1: int = bbox[2]
	var y1: int = bbox[3]
	var seeds := []
	var seen := {}
	for x in range(x0, x1):
		for y in [y0, y1 - 1]:
			var point := Vector2i(x, y)
			if not seen.has(point) and _alpha_smoke_background_candidate(image.get_pixel(x, y)):
				seeds.append(point)
				seen[point] = true
	for y in range(y0, y1):
		for x in [x0, x1 - 1]:
			var point := Vector2i(x, y)
			if not seen.has(point) and _alpha_smoke_background_candidate(image.get_pixel(x, y)):
				seeds.append(point)
				seen[point] = true
	for y in range(y0, y1):
		for x in range(x0, x1):
			var point := Vector2i(x, y)
			if seen.has(point) or not _alpha_smoke_background_candidate(image.get_pixel(x, y)):
				continue
			for neighbor in _alpha_smoke_neighbors(point, width, height):
				var neighbor_point := neighbor as Vector2i
				if int(round(image.get_pixel(neighbor_point.x, neighbor_point.y).a * 255.0)) <= 8:
					seeds.append(point)
					seen[point] = true
					break
	return seeds


func _alpha_smoke_floodable_background(image: Image) -> int:
	var bbox := _alpha_smoke_visible_bbox(image)
	if bbox.is_empty():
		return 0
	var width := image.get_width()
	var height := image.get_height()
	var seen := {}
	var queue := []
	for point in _alpha_smoke_seed_points(image, bbox):
		var seed := point as Vector2i
		if not seen.has(seed):
			seen[seed] = true
			queue.append(seed)
	while not queue.is_empty():
		var point := queue.pop_front() as Vector2i
		for neighbor in _alpha_smoke_neighbors(point, width, height):
			var neighbor_point := neighbor as Vector2i
			if seen.has(neighbor_point):
				continue
			if _alpha_smoke_background_candidate(image.get_pixel(neighbor_point.x, neighbor_point.y)):
				seen[neighbor_point] = true
				queue.append(neighbor_point)
	return seen.size()


func _alpha_smoke_edge_white_pixels(image: Image, ring_width := 8) -> int:
	var total := 0
	var width := image.get_width()
	var height := image.get_height()
	for y in range(height):
		for x in range(width):
			if not (x < ring_width or y < ring_width or x >= width - ring_width or y >= height - ring_width):
				continue
			if _alpha_smoke_background_candidate(image.get_pixel(x, y)):
				total += 1
	return total


func _test_player_animation() -> void:
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)
	player.configure_character("berserk")
	var body := player.get_node("VisualRoot/Body") as AnimatedSprite2D
	var rig := player.get_node("VisualRoot/RigRoot") as Node2D
	if not body.visible:
		_fail("Expected Berserk full-frame AnimatedSprite2D to be visible.")
	if rig.visible:
		_fail("Expected Berserk cutout RigRoot to be hidden behind the full-frame AnimatedSprite2D.")
	if body.scale != EXPECTED_PLAYER_COMBAT_VISUAL_SCALE:
		_fail("Expected Berserk full-frame visual to use SCRUM-823 combat scale %s, got %s." % [str(EXPECTED_PLAYER_COMBAT_VISUAL_SCALE), str(body.scale)])
	if rig.get("base_scale") != EXPECTED_PLAYER_COMBAT_VISUAL_SCALE:
		_fail("Expected hidden fallback cutout rig to receive SCRUM-823 combat scale %s, got %s." % [str(EXPECTED_PLAYER_COMBAT_VISUAL_SCALE), str(rig.get("base_scale"))])
	if body.sprite_frames == null:
		_fail("Expected Berserk player SpriteFrames to load.")
	if body.sprite_frames.resource_path != "res://assets/sprites/characters/berserk_spriteframes.tres":
		_fail("Expected Berserk to use the accepted PixelLab directional SpriteFrames resource.")
	if not body.sprite_frames.has_animation("idle") or not body.sprite_frames.has_animation("walk") or not body.sprite_frames.has_animation("move"):
		_fail("Expected Berserk PixelLab SpriteFrames to expose idle/walk/move fallback animations.")
	if body.sprite_frames.has_animation("attack") or body.sprite_frames.has_animation("attack_primary"):
		_fail("Expected Berserk PixelLab SpriteFrames to omit attack animations by task scope.")
	var berserk_directions := ["south", "south_east", "east", "north_east", "north", "north_west", "west", "south_west"]
	for direction_name in berserk_directions:
		if not body.sprite_frames.has_animation("idle_%s" % direction_name):
			_fail("Expected Berserk PixelLab SpriteFrames to expose idle_%s." % direction_name)
		if not body.sprite_frames.has_animation("walk_%s" % direction_name) or not body.sprite_frames.has_animation("move_%s" % direction_name):
			_fail("Expected Berserk PixelLab SpriteFrames to expose walk/move_%s." % direction_name)
			return
		if body.sprite_frames.get_frame_count("walk_%s" % direction_name) != 6 or body.sprite_frames.get_frame_count("move_%s" % direction_name) != 6:
			_fail("Expected Berserk PixelLab walk/move_%s to expose 6 frames." % direction_name)
			return
	if body.sprite_frames.get_frame_count("idle") != 1 or body.sprite_frames.get_frame_count("walk") != 6 or body.sprite_frames.get_frame_count("move") != 6:
		_fail("Expected Berserk PixelLab fallback idle/walk/move frame counts to be 1/6/6.")
	if not body.sprite_frames.get_animation_loop("idle") or not body.sprite_frames.get_animation_loop("walk") or not body.sprite_frames.get_animation_loop("move"):
		_fail("Expected Berserk PixelLab idle/walk/move animations to loop.")
	player.call("play_action_animation", "attack", Vector2.RIGHT)
	var last_event := player.get("last_weapon_animation_event") as Dictionary
	if str(last_event.get("action_id", "")) != "attack":
		_fail("Expected player action playback to emit an attack weapon animation event.")
	player.set("velocity", Vector2(100, 0))
	player.call("_update_movement_animation", 0.01)
	if body.animation != &"walk_east":
		_fail("Expected rightward Berserk movement to play walk_east, got %s." % str(body.animation))
	player.set("velocity", Vector2(0, -100))
	player.call("_update_movement_animation", 0.01)
	if body.animation != &"walk_north":
		_fail("Expected upward Berserk movement to play walk_north, got %s." % str(body.animation))
	player.set("velocity", Vector2(-100, 100))
	player.call("_update_movement_animation", 0.01)
	if body.animation != &"walk_south_west":
		_fail("Expected diagonal Berserk movement to play walk_south_west, got %s." % str(body.animation))
	if body.animation == "attack" or body.animation == "attack_primary":
		_fail("Expected player body attack SpriteFrames to stay disabled while weapon/rig action events run.")
	player.call("_update_movement_animation", 1.0)
	if body.animation == "attack" or body.animation == "attack_primary":
		_fail("Expected player movement animation to remain in a non-attack state after the action window.")
	var synthetic_sheet := _make_synthetic_character_sheet()
	var synthetic_frames := player.call("_sprite_frames_from_character_sheet", synthetic_sheet) as SpriteFrames
	if synthetic_frames == null:
		_fail("Expected player character sheet builder to accept a 5x3 runtime sheet.")
	if synthetic_frames.get_frame_count("idle") != 5 or synthetic_frames.get_frame_count("walk") != 5 or synthetic_frames.get_frame_count("attack") != 5:
		_fail("Expected synthetic character sheet to produce 5 idle/walk/attack frames.")
	if not synthetic_frames.get_animation_loop("walk") or synthetic_frames.get_animation_loop("attack"):
		_fail("Expected character sheet walk to loop and attack to be one-shot.")
	_assert_sliced_rig(player, "VisualRoot/RigRoot", "characters/cutout", ["Torso", "ArmL", "ArmR"], ["LegL", "LegR"], "player")

	var pelvis := rig.get_node("Pelvis") as Node2D
	var leg_l := rig.get_node("Pelvis/Figure/LegL") as Node2D
	var leg_r := rig.get_node("Pelvis/Figure/LegR") as Node2D

	player.set("velocity", Vector2(100, 0))
	player.call("_update_movement_animation", 0.2)
	if abs(pelvis.position.y) <= 0.01 and abs(pelvis.rotation) <= 0.01:
		_fail("Expected player movement to affect rig pelvis transform.")
	if abs(leg_l.rotation - leg_r.rotation) <= 0.05:
		_fail("Expected player walk to use opposing leg rotations.")
	if pelvis.scale.x <= 0.0:
		_fail("Expected rightward movement to face right (positive pelvis scale.x).")

	player.set("velocity", Vector2(-100, 0))
	player.call("_update_movement_animation", 0.2)
	if pelvis.scale.x >= 0.0:
		_fail("Expected leftward movement to mirror the rig (negative pelvis scale.x).")

	player.set("velocity", Vector2(0, -100))
	player.call("_update_movement_animation", 0.2)
	if pelvis.scale.x >= 0.0:
		_fail("Expected vertical movement to preserve horizontal facing.")

	player.set("velocity", Vector2.ZERO)
	player.call("_update_movement_animation", 0.2)
	if pelvis.scale.x >= 0.0:
		_fail("Expected stopped player to keep facing left.")

	player.call("play_action_animation", "attack", Vector2.RIGHT)
	player.call("_update_movement_animation", 0.12)
	var arm_r := rig.get_node("Pelvis/Figure/Torso/ArmR") as Node2D
	if abs(arm_r.rotation) <= 0.08:
		_fail("Expected melee attack to swing the attack arm.")
	var weapon_socket := player.get_node("VisualRoot/WeaponSocket") as Node2D
	if weapon_socket.position.x <= 8.0:
		_fail("Expected melee attack to keep the WeaponSocket on the weapon hand.")

	var sword_pose: Dictionary = _sample_berserk_attack_pose(player, "sword", 0.12)
	var axe_pose: Dictionary = _sample_berserk_attack_pose(player, "axe", 0.12)
	var hammer_pose: Dictionary = _sample_berserk_attack_pose(player, "hammer", 0.13)
	if sword_pose["variant"] != "sword" or axe_pose["variant"] != "axe" or hammer_pose["variant"] != "hammer":
		_fail("Expected Berserk attack rig to receive the equipped weapon animation variant.")
	if float(sword_pose["arm_r_x"]) <= float(axe_pose["arm_r_x"]) + 3.0:
		_fail("Expected sword attack pose to read as a forward thrust compared with axe arc.")
	if float(axe_pose["arm_r_rot"]) <= float(sword_pose["arm_r_rot"]) + 0.03:
		_fail("Expected axe attack pose to use a wider arm arc than sword thrust.")
	if float(hammer_pose["arm_r_y"]) >= float(sword_pose["arm_r_y"]) - 3.0 or float(hammer_pose["pelvis_y"]) >= float(sword_pose["pelvis_y"]) - 2.0:
		_fail("Expected hammer attack pose to lift into an overhead slam silhouette.")

	var fallback_texture := load("res://assets/sprites/characters/berserk_unarmed.png") as Texture2D
	var fallback_frames := player.call("_single_texture_sprite_frames", fallback_texture) as SpriteFrames
	if fallback_frames == null or fallback_frames.get_frame_count("attack") != 1:
		_fail("Expected non-sheet character fallback attack animation to be safe and static.")
	_assert_sliced_rig(player, "VisualRoot/RigRoot", "characters/cutout", ["Torso", "ArmL", "ArmR"], ["LegL", "LegR"], "guitarist")
	player.call("play_action_animation", "shoot", Vector2.RIGHT)
	player.call("_update_movement_animation", 0.10)
	var guitarist_pelvis := player.get_node("VisualRoot/RigRoot/Pelvis") as Node2D
	if guitarist_pelvis.position.x >= -0.01:
		_fail("Expected ranged action animation to recoil the rig pelvis.")

	var accepted_character_spriteframes := {
		"assassin": "res://assets/sprites/characters/assassin_spriteframes.tres",
		"berserk": "res://assets/sprites/characters/berserk_spriteframes.tres",
		"biologist": "res://assets/sprites/characters/biologist_spriteframes.tres",
		"chemist": "res://assets/sprites/characters/chemist_spriteframes.tres",
		"dark_mage": "res://assets/sprites/characters/dark_mage_spriteframes.tres",
		"doctor": "res://assets/sprites/characters/doctor_spriteframes.tres",
		"druid": "res://assets/sprites/characters/druid_spriteframes.tres",
		"elementalist": "res://assets/sprites/characters/elementalist_spriteframes.tres",
		"engineer": "res://assets/sprites/characters/engineer_spriteframes.tres",
		"guitarist": "res://assets/sprites/characters/guitarist_spriteframes.tres",
		"knight": "res://assets/sprites/characters/knight_spriteframes.tres",
		"priest": "res://assets/sprites/characters/priest_spriteframes.tres",
		"ranger": "res://assets/sprites/characters/ranger_spriteframes.tres",
		"robot": "res://assets/sprites/characters/robot_spriteframes.tres",
		"sniper": "res://assets/sprites/characters/sniper_spriteframes.tres",
		"soldier": "res://assets/sprites/characters/soldier_spriteframes.tres",
		"thief": "res://assets/sprites/characters/thief_spriteframes.tres",
	}
	for sheet_character_id in accepted_character_spriteframes.keys():
		player.configure_character(sheet_character_id)
		body = player.get_node("VisualRoot/Body") as AnimatedSprite2D
		rig = player.get_node("VisualRoot/RigRoot") as Node2D
		if body.sprite_frames == null or body.sprite_frames.resource_path != str(accepted_character_spriteframes[sheet_character_id]):
			_fail("Expected %s to use its accepted SpriteFrames resource." % sheet_character_id)
		if not body.visible or rig.visible:
			_fail("Expected %s full-frame AnimatedSprite2D visible with hidden cutout RigRoot." % sheet_character_id)
		if sheet_character_id == "knight":
			# SCRUM-919: бой Рыцаря рендерит принятый PixelLab-пак; легаси
			# скелетный риг (skeleton_parts) больше не подключается к рантайму.
			_assert_knight_pixellab_combat_visual(player, body)
		if body.scale != EXPECTED_PLAYER_COMBAT_VISUAL_SCALE or rig.get("base_scale") != EXPECTED_PLAYER_COMBAT_VISUAL_SCALE:
			_fail("Expected %s visual paths to use SCRUM-823 combat scale %s." % [sheet_character_id, str(EXPECTED_PLAYER_COMBAT_VISUAL_SCALE)])
		if sheet_character_id == "assassin" or sheet_character_id == "berserk" or sheet_character_id == "biologist" or sheet_character_id == "chemist" or sheet_character_id == "dark_mage" or sheet_character_id == "doctor" or sheet_character_id == "druid" or sheet_character_id == "elementalist" or sheet_character_id == "engineer" or sheet_character_id == "guitarist" or sheet_character_id == "knight" or sheet_character_id == "priest" or sheet_character_id == "ranger" or sheet_character_id == "robot" or sheet_character_id == "sniper" or sheet_character_id == "soldier" or sheet_character_id == "thief":
			var v2_label := "PixelLab directional"
			if not body.sprite_frames.has_animation("idle") or not body.sprite_frames.has_animation("walk") or not body.sprite_frames.has_animation("move"):
				_fail("Expected %s %s SpriteFrames to expose idle/walk/move fallback frames." % [sheet_character_id, v2_label])
				return
			if body.sprite_frames.has_animation("attack") or body.sprite_frames.has_animation("attack_primary"):
				_fail("Expected %s %s SpriteFrames to omit weapon-owned attack animations." % [sheet_character_id, v2_label])
				return
			for direction_name in ["south", "south_east", "east", "north_east", "north", "north_west", "west", "south_west"]:
				if not body.sprite_frames.has_animation("idle_%s" % direction_name) or body.sprite_frames.get_frame_count("idle_%s" % direction_name) != 1:
					_fail("Expected %s PixelLab directional SpriteFrames to expose 1-frame idle_%s." % [sheet_character_id, direction_name])
					return
				if not body.sprite_frames.has_animation("walk_%s" % direction_name) or body.sprite_frames.get_frame_count("walk_%s" % direction_name) != 6:
					_fail("Expected %s PixelLab directional SpriteFrames to expose 6-frame walk_%s." % [sheet_character_id, direction_name])
					return
				if not body.sprite_frames.has_animation("move_%s" % direction_name) or body.sprite_frames.get_frame_count("move_%s" % direction_name) != 6:
					_fail("Expected %s PixelLab directional SpriteFrames to expose 6-frame move_%s." % [sheet_character_id, direction_name])
					return
			if body.sprite_frames.get_frame_count("idle") != 1 or body.sprite_frames.get_frame_count("walk") != 6 or body.sprite_frames.get_frame_count("move") != 6:
				_fail("Expected %s PixelLab fallback idle/walk/move frame counts to be 1/6/6." % sheet_character_id)
				return
			if not body.sprite_frames.get_animation_loop("idle") or not body.sprite_frames.get_animation_loop("walk") or not body.sprite_frames.get_animation_loop("move"):
				_fail("Expected %s PixelLab fallback idle/walk/move animations to loop." % sheet_character_id)
				return
			continue
		else:
			if body.sprite_frames.get_frame_count("idle") != 5 or body.sprite_frames.get_frame_count("walk") != 5 or body.sprite_frames.get_frame_count("attack") != 5 or body.sprite_frames.get_frame_count("attack_primary") != 5:
				_fail("Expected %s accepted SpriteFrames to expose 5 idle/walk/attack/attack_primary frames." % sheet_character_id)
			if not body.sprite_frames.get_animation_loop("idle") or not body.sprite_frames.get_animation_loop("walk") or body.sprite_frames.get_animation_loop("attack") or body.sprite_frames.get_animation_loop("attack_primary"):
				_fail("Expected %s idle/walk to loop and attacks to be one-shot." % sheet_character_id)
	player.configure_character("missing_full_frame_test")
	body = player.get_node("VisualRoot/Body") as AnimatedSprite2D
	rig = player.get_node("VisualRoot/RigRoot") as Node2D
	if body.visible or not rig.visible:
		_fail("Expected missing full-frame fallback to hide Body and show cutout RigRoot.")

	var new_class_profiles := {
		"assassin": 0.08,
		"ranger": 0.06,
		"doctor": 0.035,
		"chemist": 0.045,
		"druid": 0.035,
		"soldier": 0.04,
		"thief": 0.05,
		"elementalist": 0.03,
		"sniper": 0.03,
		"priest": 0.025,
		"biologist": 0.025,
		"robot": 0.02,
		"engineer": 0.025,
	}
	for character_id in new_class_profiles.keys():
		player.configure_character(character_id)
		player.set("_animation_time", 0.0)
		_assert_sliced_rig(player, "VisualRoot/RigRoot", "characters/cutout", ["Torso", "ArmL", "ArmR"], ["LegL", "LegR"], character_id)
		player.set("velocity", Vector2(120, 0))
		player.call("_update_movement_animation", 0.20)
		var class_rig := player.get_node("VisualRoot/RigRoot") as Node2D
		var class_pelvis := class_rig.get_node("Pelvis") as Node2D
		var class_leg_l := class_rig.get_node("Pelvis/Figure/LegL") as Node2D
		var class_leg_r := class_rig.get_node("Pelvis/Figure/LegR") as Node2D
		if abs(class_pelvis.position.y) <= 0.01:
			_fail("Expected %s movement profile to move the pelvis." % character_id)
		var leg_delta: float = abs(class_leg_l.rotation - class_leg_r.rotation)
		var min_leg_delta: float = float(new_class_profiles[character_id])
		if leg_delta <= min_leg_delta:
			_fail("Expected %s to use a distinct readable walk profile; leg_delta=%.4f min=%.4f." % [character_id, leg_delta, min_leg_delta])

	var rifle_pose: Dictionary = _sample_player_weapon_action_pose(player, "soldier", "soldier_rifle", "shoot", 0.12)
	var grenade_pose: Dictionary = _sample_player_weapon_action_pose(player, "soldier", "soldier_grenade", "shoot", 0.12)
	var bayonet_pose: Dictionary = _sample_player_weapon_action_pose(player, "soldier", "soldier_bayonet", "shoot", 0.12)
	if rifle_pose["variant"] != "soldier_rifle" or grenade_pose["variant"] != "soldier_grenade" or bayonet_pose["variant"] != "soldier_bayonet":
		_fail("Expected Soldier rig to receive the equipped weapon id as animation variant.")
	if float(rifle_pose["pelvis_x"]) >= -2.0:
		_fail("Expected soldier rifle pose to recoil backward.")
	if float(grenade_pose["arm_r_y"]) >= float(rifle_pose["arm_r_y"]) - 2.0:
		_fail("Expected soldier grenade pose to lift the throwing arm.")
	if float(bayonet_pose["pelvis_x"]) <= float(grenade_pose["pelvis_x"]) + 1.0 or float(bayonet_pose["arm_r_x"]) <= float(rifle_pose["arm_r_x"]) + 8.0:
		_fail("Expected soldier bayonet pose to brace forward.")

	var coin_pose: Dictionary = _sample_player_weapon_action_pose(player, "thief", "thief_coin_pouch", "shoot", 0.12)
	var shadow_pose: Dictionary = _sample_player_weapon_action_pose(player, "thief", "thief_shadow_cloak", "shoot", 0.12)
	var smoke_pose: Dictionary = _sample_player_weapon_action_pose(player, "thief", "thief_smoke_bomb", "shoot", 0.12)
	if coin_pose["variant"] != "thief_coin_pouch" or shadow_pose["variant"] != "thief_shadow_cloak" or smoke_pose["variant"] != "thief_smoke_bomb":
		_fail("Expected Thief rig to receive the equipped weapon id as animation variant.")
	if float(coin_pose["arm_r_rot"]) <= 0.25 or float(coin_pose["arm_r_x"]) <= float(smoke_pose["arm_r_x"]) + 5.0:
		_fail("Expected thief coin pouch pose to read as a quick forward coin flick.")
	if float(shadow_pose["pelvis_x"]) <= float(coin_pose["pelvis_x"]) + 4.0:
		_fail("Expected thief shadow cloak pose to lunge farther forward than coin toss.")
	if float(smoke_pose["pelvis_x"]) >= -3.0 or float(smoke_pose["arm_r_y"]) <= float(coin_pose["arm_r_y"]) + 5.0:
		_fail("Expected thief smoke bomb pose to dodge back and throw low.")

	var orbit_pose: Dictionary = _sample_player_weapon_action_pose(player, "elementalist", "elementalist_orb_ring", "shoot", 0.12)
	var prism_pose: Dictionary = _sample_player_weapon_action_pose(player, "elementalist", "elementalist_prism_focus", "shoot", 0.12)
	var meteor_pose: Dictionary = _sample_player_weapon_action_pose(player, "elementalist", "elementalist_meteor_core", "shoot", 0.12)
	if orbit_pose["variant"] != "elementalist_orb_ring" or prism_pose["variant"] != "elementalist_prism_focus" or meteor_pose["variant"] != "elementalist_meteor_core":
		_fail("Expected Elementalist rig to receive the equipped weapon id as animation variant.")
	if float(orbit_pose["arm_l_rot"]) >= -0.25 or float(orbit_pose["arm_r_rot"]) <= 0.25:
		_fail("Expected elementalist orb ring pose to channel with both arms spread.")
	if float(prism_pose["arm_r_x"]) <= float(orbit_pose["arm_r_x"]) + 6.0:
		_fail("Expected elementalist prism focus pose to focus forward.")
	if float(meteor_pose["arm_l_y"]) >= float(orbit_pose["arm_l_y"]) - 3.0 or float(meteor_pose["pelvis_y"]) >= float(orbit_pose["pelvis_y"]) - 2.0:
		_fail("Expected elementalist meteor core pose to lift into an overhead summon.")

	var lockshot_pose: Dictionary = _sample_player_weapon_action_pose(player, "sniper", "sniper_deadeye_rifle", "shoot", 0.12)
	var kill_zone_pose: Dictionary = _sample_player_weapon_action_pose(player, "sniper", "sniper_spotter_scope", "shoot", 0.12)
	var split_pose: Dictionary = _sample_player_weapon_action_pose(player, "sniper", "sniper_shatter_rounds", "shoot", 0.12)
	if lockshot_pose["variant"] != "sniper_deadeye_rifle" or kill_zone_pose["variant"] != "sniper_spotter_scope" or split_pose["variant"] != "sniper_shatter_rounds":
		_fail("Expected Sniper rig to receive the equipped weapon id as animation variant.")
	if float(lockshot_pose["arm_r_x"]) <= float(kill_zone_pose["arm_r_x"]) + 1.0:
		_fail("Expected sniper lockshot pose to brace the rifle forward.")
	if float(kill_zone_pose["arm_l_y"]) >= float(lockshot_pose["arm_l_y"]) - 2.0:
		_fail("Expected sniper spotter scope pose to raise the off hand for marking.")
	if float(split_pose["pelvis_x"]) >= float(lockshot_pose["pelvis_x"]) - 1.0:
		_fail("Expected sniper shatter rounds pose to recoil harder than lockshot.")
	for sniper_pose in [lockshot_pose, kill_zone_pose, split_pose]:
		if float(sniper_pose["socket_x"]) <= 8.0 or abs(float(sniper_pose["socket_y"]) - float(sniper_pose["socket_bias"])) >= 36.0:
			_fail("Expected sniper weapon socket to stay readable near the firing hand.")

	var sanctify_pose: Dictionary = _sample_player_weapon_action_pose(player, "priest", "priest_reliquary", "shoot", 0.12)
	var ward_pose: Dictionary = _sample_player_weapon_action_pose(player, "priest", "priest_censer", "shoot", 0.12)
	var prayer_pose: Dictionary = _sample_player_weapon_action_pose(player, "priest", "priest_chime", "shoot", 0.12)
	if sanctify_pose["variant"] != "priest_reliquary" or ward_pose["variant"] != "priest_censer" or prayer_pose["variant"] != "priest_chime":
		_fail("Expected Priest rig to receive the equipped weapon id as animation variant.")
	if float(sanctify_pose["arm_l_y"]) >= float(ward_pose["arm_l_y"]) - 2.0:
		_fail("Expected priest sanctify pose to raise the blessing hand.")
	if float(ward_pose["arm_r_x"]) <= float(sanctify_pose["arm_r_x"]) + 2.0:
		_fail("Expected priest ward pose to open outward for a pulse.")
	if float(prayer_pose["arm_r_y"]) >= float(ward_pose["arm_r_y"]) - 4.0:
		_fail("Expected priest prayer chain pose to lift into a chime/chant.")
	for priest_pose in [sanctify_pose, ward_pose, prayer_pose]:
		if float(priest_pose["socket_x"]) <= 8.0 or abs(float(priest_pose["socket_y"]) - float(priest_pose["socket_bias"])) >= 38.0:
			_fail("Expected priest weapon socket to stay readable near the casting hand.")

	var spore_pose: Dictionary = _sample_player_weapon_action_pose(player, "biologist", "biologist_spore_lens", "shoot", 0.12)
	var sample_pose: Dictionary = _sample_player_weapon_action_pose(player, "biologist", "biologist_sample_injector", "shoot", 0.12)
	var symbiote_pose: Dictionary = _sample_player_weapon_action_pose(player, "biologist", "biologist_symbiote_seed", "shoot", 0.12)
	if spore_pose["variant"] != "biologist_spore_lens" or sample_pose["variant"] != "biologist_sample_injector" or symbiote_pose["variant"] != "biologist_symbiote_seed":
		_fail("Expected Biologist rig to receive the equipped weapon id as animation variant.")
	if float(spore_pose["arm_l_y"]) >= float(symbiote_pose["arm_l_y"]) - 4.0:
		_fail("Expected biologist spore lens pose to lift into an inspection/bloom stance.")
	if float(sample_pose["arm_r_x"]) <= float(spore_pose["arm_r_x"]) + 3.0:
		_fail("Expected biologist sample injector pose to make a precise forward dart.")
	if float(symbiote_pose["pelvis_y"]) <= float(spore_pose["pelvis_y"]) + 2.0 or float(symbiote_pose["arm_r_y"]) <= float(sample_pose["arm_r_y"]) + 2.0:
		_fail("Expected biologist symbiote seed pose to plant low into a web gesture.")
	for biologist_pose in [spore_pose, sample_pose, symbiote_pose]:
		if float(biologist_pose["socket_x"]) <= 8.0 or abs(float(biologist_pose["socket_y"]) - float(biologist_pose["socket_bias"])) >= 40.0:
			_fail("Expected biologist weapon socket to stay readable near the specimen hand.")

	var anchor_pose: Dictionary = _sample_player_weapon_action_pose(player, "robot", "robot_magnetic_anchor", "shoot", 0.12)
	var press_pose: Dictionary = _sample_player_weapon_action_pose(player, "robot", "robot_hydraulic_press", "shoot", 0.12)
	var reactor_pose: Dictionary = _sample_player_weapon_action_pose(player, "robot", "robot_reactor_core", "shoot", 0.12)
	if anchor_pose["variant"] != "robot_magnetic_anchor" or press_pose["variant"] != "robot_hydraulic_press" or reactor_pose["variant"] != "robot_reactor_core":
		_fail("Expected Robot rig to receive the equipped weapon id as animation variant.")
	if float(anchor_pose["pelvis_x"]) >= -1.0 or float(anchor_pose["arm_r_y"]) <= float(press_pose["arm_r_y"]) + 2.0:
		_fail("Expected robot magnetic anchor pose to plant heavy and pull low.")
	if float(press_pose["arm_r_x"]) <= float(anchor_pose["arm_r_x"]) + 2.0:
		_fail("Expected robot hydraulic press pose to drive both arms forward.")
	if float(reactor_pose["arm_l_x"]) >= float(anchor_pose["arm_l_x"]) - 2.0 or float(reactor_pose["arm_r_x"]) <= float(anchor_pose["arm_r_x"]) + 1.0:
		_fail("Expected robot reactor core pose to open both arms for venting.")
	for robot_pose in [anchor_pose, press_pose, reactor_pose]:
		if float(robot_pose["socket_x"]) <= 8.0 or abs(float(robot_pose["socket_y"]) - float(robot_pose["socket_bias"])) >= 42.0:
			_fail("Expected robot weapon socket to stay readable near the construct hand.")

	var wrench_pose: Dictionary = _sample_player_weapon_action_pose(player, "engineer", "engineer_sentry_wrench", "shoot", 0.12)
	var drone_pose: Dictionary = _sample_player_weapon_action_pose(player, "engineer", "engineer_repair_drone", "shoot", 0.12)
	var mines_pose: Dictionary = _sample_player_weapon_action_pose(player, "engineer", "engineer_pressure_mines", "shoot", 0.12)
	if wrench_pose["variant"] != "engineer_sentry_wrench" or drone_pose["variant"] != "engineer_repair_drone" or mines_pose["variant"] != "engineer_pressure_mines":
		_fail("Expected Engineer rig to receive the equipped weapon id as animation variant.")
	if float(wrench_pose["arm_r_y"]) >= float(mines_pose["arm_r_y"]) - 4.0:
		_fail("Expected engineer sentry wrench pose to lift the tool for deployment.")
	if float(drone_pose["arm_l_y"]) >= float(mines_pose["arm_l_y"]) - 4.0 or float(drone_pose["pelvis_y"]) >= float(mines_pose["pelvis_y"]) - 2.0:
		_fail("Expected engineer repair drone pose to launch upward.")
	if float(mines_pose["pelvis_y"]) <= float(wrench_pose["pelvis_y"]) + 2.0 or float(mines_pose["arm_r_y"]) <= float(wrench_pose["arm_r_y"]) + 3.0:
		_fail("Expected engineer pressure mines pose to crouch and place low.")
	for engineer_pose in [wrench_pose, drone_pose, mines_pose]:
		if float(engineer_pose["socket_x"]) <= 8.0 or abs(float(engineer_pose["socket_y"]) - float(engineer_pose["socket_bias"])) >= 42.0:
			_fail("Expected engineer weapon socket to stay readable near the tool hand.")

	_test_weapon_animation_timing_events(player)
	_test_legacy_player_weapon_pose_hooks(player)
	_test_unique_attack_phase_pose_hooks(player)
	player.queue_free()


func _make_synthetic_character_sheet() -> Texture2D:
	var image := Image.create(384 * 5, 384 * 3, false, Image.FORMAT_RGBA8)
	for row in range(3):
		for column in range(5):
			var color := Color(0.12 + 0.18 * column, 0.16 + 0.22 * row, 0.35, 1.0)
			image.fill_rect(Rect2i(column * 384, row * 384, 384, 384), color)
	return ImageTexture.create_from_image(image)


func _test_weapon_animation_timing_events(player: Node) -> void:
	var events: Array[Dictionary] = []
	player.connect("weapon_animation_event", func(event: Dictionary) -> void:
		events.append(event)
	)

	player.configure_character("soldier", "soldier_grenade")
	var grenade_weapon: Node = player.get("equipped_weapon")
	grenade_weapon.set_process(false)
	grenade_weapon.call("_emit_weapon_animation_event", player, "windup", 0.42, Vector2.RIGHT, {"delayed": true})
	_assert_weapon_timing_event(events, "grenade_fuse", "windup")

	player.configure_character("guitarist", "sound_amp")
	var amp_weapon: Node = player.get("equipped_weapon")
	amp_weapon.set_process(false)
	amp_weapon.call("_emit_weapon_animation_event", player, "deploy", 7.0, Vector2.RIGHT, {"pulse_interval": 1.1})
	amp_weapon.call("_emit_weapon_animation_event", player, "pulse", 1.1, Vector2.RIGHT, {"index": 0, "count": 6})
	_assert_weapon_timing_event(events, "amp", "deploy")
	_assert_weapon_timing_event(events, "amp", "pulse")

	# SCRUM-939: dark_wand — цепной снаряд (dark_chain_burst), каст даёт windup.
	player.configure_character("dark_mage", "dark_wand")
	var chain_weapon: Node = player.get("equipped_weapon")
	chain_weapon.set_process(false)
	chain_weapon.call("_emit_weapon_animation_event", player, "windup", 0.12, Vector2.RIGHT, {"chain_targets": 3})
	_assert_weapon_timing_event(events, "dark_chain_burst", "windup")

	var last_event: Dictionary = player.get("last_weapon_animation_event")
	if str(last_event.get("phase", "")) == "" or not last_event.has("duration") or not (last_event.get("metadata", {}) is Dictionary):
		_fail("Expected Player to retain the last weapon animation timing event payload.")


func _assert_weapon_timing_event(events: Array[Dictionary], attack_mode: String, phase: String) -> void:
	for event in events:
		var metadata: Dictionary = event.get("metadata", {})
		if str(event.get("phase", "")) == phase and str(metadata.get("attack_mode", "")) == attack_mode and float(event.get("duration", 0.0)) >= 0.0:
			return
	_fail("Expected weapon animation timing event phase=%s attack_mode=%s." % [phase, attack_mode])


func _test_legacy_player_weapon_pose_hooks(player: Node) -> void:
	# Dark Mage/Knight cartoon2 body attack rows intentionally stay absent:
	# weapon visuals own attacks while hidden rig hooks still support legacy classes.

	var electric_pose: Dictionary = _sample_player_weapon_action_pose(player, "guitarist", "electric_guitar", "shoot", 0.12)
	var bass_pose: Dictionary = _sample_player_weapon_action_pose(player, "guitarist", "bass_guitar", "shoot", 0.18)
	var amp_pose: Dictionary = _sample_player_weapon_action_pose(player, "guitarist", "sound_amp", "shoot", 0.18)
	_assert_three_pose_variants("guitarist", electric_pose, bass_pose, amp_pose)
	if _pose_distance(bass_pose, electric_pose) <= 3.0 or _pose_distance(amp_pose, electric_pose) <= 3.0:
		_fail("Expected Guitarist bass pulse and amp deploy poses to separate from strum.")

	var chakram_pose: Dictionary = _sample_player_weapon_action_pose(player, "assassin", "chakrams", "shoot", 0.12)
	var dagger_pose: Dictionary = _sample_player_weapon_action_pose(player, "assassin", "shadow_daggers", "shoot", 0.12)
	var wire_pose: Dictionary = _sample_player_weapon_action_pose(player, "assassin", "venom_wire", "shoot", 0.12)
	_assert_three_pose_variants("assassin", chakram_pose, dagger_pose, wire_pose)
	if float(dagger_pose["pelvis_x"]) <= float(wire_pose["pelvis_x"]) + 6.0 or float(wire_pose["arm_l_x"]) >= float(chakram_pose["arm_l_x"]) - 2.0:
		_fail("Expected Assassin dagger lunge and venom-wire draw to be distinct.")

	var moon_pose: Dictionary = _sample_player_weapon_action_pose(player, "ranger", "moon_crossbow", "cast", 0.12)
	var storm_pose: Dictionary = _sample_player_weapon_action_pose(player, "ranger", "storm_longbow", "cast", 0.12)
	var trap_pose: Dictionary = _sample_player_weapon_action_pose(player, "ranger", "hunter_trap", "shoot", 0.12)
	_assert_three_pose_variants("ranger", moon_pose, storm_pose, trap_pose)
	if float(trap_pose["pelvis_y"]) <= float(moon_pose["pelvis_y"]) + 3.0 or float(storm_pose["arm_l_y"]) >= float(trap_pose["arm_l_y"]) - 6.0:
		_fail("Expected Ranger trap placement and charged bow poses to be distinct.")

	var potion_pose: Dictionary = _sample_player_weapon_action_pose(player, "doctor", "restore_potion", "cast", 0.12)
	var syringe_pose: Dictionary = _sample_player_weapon_action_pose(player, "doctor", "plague_syringe", "cast", 0.12)
	var saw_pose: Dictionary = _sample_player_weapon_action_pose(player, "doctor", "bone_saw", "shoot", 0.12)
	_assert_three_pose_variants("doctor", potion_pose, syringe_pose, saw_pose)
	if float(saw_pose["arm_r_rot"]) <= float(syringe_pose["arm_r_rot"]) + 0.35 or float(syringe_pose["arm_r_x"]) <= float(potion_pose["arm_r_x"]) + 2.0:
		_fail("Expected Doctor syringe jab and bone saw pose to differ from restore link.")

	var powder_pose: Dictionary = _sample_player_weapon_action_pose(player, "chemist", "blast_powder", "cast", 0.12)
	var acid_pose: Dictionary = _sample_player_weapon_action_pose(player, "chemist", "acid_flask", "cast", 0.18)
	var vial_pose: Dictionary = _sample_player_weapon_action_pose(player, "chemist", "homunculus_vial", "cast", 0.16)
	_assert_three_pose_variants("chemist", powder_pose, acid_pose, vial_pose)
	if _pose_distance(acid_pose, powder_pose) <= 5.0 or _pose_distance(vial_pose, powder_pose) <= 5.0:
		_fail("Expected Chemist powder/flask/vial casts to use different arm heights.")

	var summon_pose: Dictionary = _sample_player_weapon_action_pose(player, "druid", "summon_amulet", "cast", 0.14)
	var briar_pose: Dictionary = _sample_player_weapon_action_pose(player, "druid", "briar_staff", "cast", 0.14)
	var raven_pose: Dictionary = _sample_player_weapon_action_pose(player, "druid", "raven_totem", "shoot", 0.14)
	_assert_three_pose_variants("druid", summon_pose, briar_pose, raven_pose)
	if float(summon_pose["arm_l_y"]) >= float(briar_pose["arm_l_y"]) - 5.0 or float(briar_pose["pelvis_y"]) <= float(summon_pose["pelvis_y"]) + 3.0:
		_fail("Expected Druid summon, briar, and raven totem poses to be distinct.")

	var legacy_samples := [
		electric_pose, bass_pose, amp_pose,
		chakram_pose, dagger_pose, wire_pose, moon_pose, storm_pose, trap_pose,
		potion_pose, syringe_pose, saw_pose, powder_pose, acid_pose, vial_pose,
		summon_pose, briar_pose, raven_pose,
	]
	for sample in legacy_samples:
		if float(sample["socket_x"]) <= -120.0 or float(sample["socket_x"]) >= 180.0 or abs(float(sample["socket_y"]) - float(sample["socket_bias"])) >= 180.0:
			_fail("Expected legacy player weapon socket to stay readable near the acting hand.")


func _test_unique_attack_phase_pose_hooks(player: Node) -> void:
	# Dark Mage/Knight body attack animation is out of scope here; their weapons
	# still emit timing events, and body SpriteFrames stay idle/walk/move only.
	var phase_samples := [
		["guitarist", "electric_guitar", "riff_strip", "shoot", "windup"],
		["guitarist", "bass_guitar", "pulse", "shoot", "pulse"],
		["guitarist", "sound_amp", "amp", "shoot", "deploy"],
		["assassin", "chakrams", "boomerang", "shoot", "windup"],
		["assassin", "shadow_daggers", "stab_flurry", "shoot", "burst"],
		["assassin", "venom_wire", "dot_beam", "cast", "channel"],
		# SCRUM-910/911: кит Рейнджера ушёл с beam на собственные режимы.
		["ranger", "moon_crossbow", "moon_split_shot", "cast", "channel"],
		["ranger", "storm_longbow", "storm_pierce_cone", "cast", "channel"],
		["ranger", "hunter_trap", "trap", "shoot", "deploy"],
		["doctor", "restore_potion", "drain_link", "cast", "channel"],
		["doctor", "plague_syringe", "drain_link", "cast", "channel"],
		["doctor", "bone_saw", "stab_flurry", "shoot", "burst"],
		["chemist", "blast_powder", "aoe_projectile", "cast", "windup"],
		["chemist", "acid_flask", "aoe_projectile", "cast", "windup"],
		["chemist", "homunculus_vial", "summon", "cast", "deploy"],
		["druid", "summon_amulet", "summon", "cast", "deploy"],
		["druid", "briar_staff", "aoe_projectile", "cast", "windup"],
		["druid", "raven_totem", "amp", "shoot", "deploy"],
		["soldier", "soldier_rifle", "arquebus_shot", "shoot", "windup"],
		["soldier", "soldier_grenade", "grenade_fuse", "shoot", "windup"],
		["soldier", "soldier_bayonet", "bayonet_cone", "shoot", "windup"],
		["thief", "thief_coin_pouch", "coin_ricochet", "shoot", "windup"],
		["thief", "thief_shadow_cloak", "shadow_backstab", "shoot", "windup"],
		["thief", "thief_smoke_bomb", "smoke_bomb", "shoot", "windup"],
		["elementalist", "elementalist_orb_ring", "elemental_orbit", "shoot", "channel"],
		["elementalist", "elementalist_prism_focus", "prism_rift", "shoot", "windup"],
		["elementalist", "elementalist_meteor_core", "meteor_shards", "shoot", "windup"],
		["sniper", "sniper_deadeye_rifle", "sniper_lockshot", "shoot", "windup"],
		["sniper", "sniper_spotter_scope", "sniper_kill_zone", "shoot", "windup"],
		["sniper", "sniper_shatter_rounds", "sniper_split_round", "shoot", "windup"],
		["priest", "priest_reliquary", "priest_sanctify", "shoot", "windup"],
		["priest", "priest_censer", "priest_ward", "shoot", "pulse"],
		["priest", "priest_chime", "priest_dual_toll", "cast", "channel"],
		["biologist", "biologist_spore_lens", "bio_spore_bloom", "shoot", "pulse"],
		["biologist", "biologist_sample_injector", "bio_sample_dart", "shoot", "pulse"],
		["biologist", "biologist_symbiote_seed", "bio_symbiote_web", "cast", "channel"],
		["robot", "robot_magnetic_anchor", "robot_magnetic_anchor", "shoot", "windup"],
		["robot", "robot_hydraulic_press", "robot_compression_line", "shoot", "windup"],
		["robot", "robot_reactor_core", "robot_reactor_vent", "shoot", "windup"],
		["engineer", "engineer_sentry_wrench", "engineer_sentry_link", "shoot", "deploy"],
		["engineer", "engineer_repair_drone", "engineer_orbit_drone", "shoot", "deploy"],  # SCRUM-906
		["engineer", "engineer_pressure_mines", "engineer_pressure_mines", "shoot", "deploy"],
	]

	for sample in phase_samples:
		var pose: Dictionary = _sample_player_weapon_phase_pose(
			player,
			str(sample[0]),
			str(sample[1]),
			str(sample[2]),
			str(sample[3]),
			str(sample[4]),
			0.14
		)
		var variant := str(pose["variant"])
		if not variant.contains(str(sample[1])) or not variant.contains(str(sample[2])) or not variant.contains(str(sample[4])):
			_fail("Expected unique attack phase variant to include weapon/mode/phase for %s/%s." % [sample[0], sample[1]])
		if _pose_distance(pose, _idle_pose(player, str(sample[0]), str(sample[1]))) <= 1.8:
			_fail("Expected unique attack phase to move rig silhouette for %s/%s." % [sample[0], sample[1]])


func _assert_three_pose_variants(label: String, pose_a: Dictionary, pose_b: Dictionary, pose_c: Dictionary) -> void:
	if str(pose_a["variant"]) == "" or str(pose_b["variant"]) == "" or str(pose_c["variant"]) == "":
		_fail("Expected %s pose samples to preserve weapon variants." % label)
	var distance_ab := _pose_distance(pose_a, pose_b)
	var distance_bc := _pose_distance(pose_b, pose_c)
	var distance_ac := _pose_distance(pose_a, pose_c)
	if minf(distance_ab, minf(distance_bc, distance_ac)) <= 3.0:
		_fail("Expected %s weapon poses to have clearly distinct silhouettes." % label)


func _pose_distance(pose_a: Dictionary, pose_b: Dictionary) -> float:
	var total := 0.0
	for key in ["pelvis_x", "pelvis_y", "arm_l_x", "arm_l_y", "arm_l_rot", "arm_r_x", "arm_r_y", "arm_r_rot"]:
		total += abs(float(pose_a[key]) - float(pose_b[key]))
	return total


func _sample_berserk_attack_pose(player: Node, weapon_id: String, elapsed: float) -> Dictionary:
	player.configure_character("berserk", weapon_id)
	player.set("velocity", Vector2.ZERO)
	player.call("play_action_animation", "attack", Vector2.RIGHT)
	player.call("_update_movement_animation", elapsed)
	var rig := player.get_node("VisualRoot/RigRoot") as Node2D
	var pelvis := rig.get_node("Pelvis") as Node2D
	var arm_r := rig.get_node("Pelvis/Figure/Torso/ArmR") as Node2D
	return {
		"variant": str(rig.get("action_variant")),
		"arm_r_rot": arm_r.rotation,
		"arm_r_x": arm_r.position.x,
		"arm_r_y": arm_r.position.y,
		"pelvis_y": pelvis.position.y,
	}


func _sample_player_weapon_action_pose(player: Node, character_id: String, weapon_id: String, action_id: String, elapsed: float) -> Dictionary:
	player.configure_character(character_id, weapon_id)
	player.set("velocity", Vector2.ZERO)
	player.call("play_action_animation", action_id, Vector2.RIGHT)
	player.call("_update_movement_animation", elapsed)
	var rig := player.get_node("VisualRoot/RigRoot") as Node2D
	var pelvis := rig.get_node("Pelvis") as Node2D
	var arm_l := rig.get_node("Pelvis/Figure/Torso/ArmL") as Node2D
	var arm_r := rig.get_node("Pelvis/Figure/Torso/ArmR") as Node2D
	var weapon_socket := player.get_node("VisualRoot/WeaponSocket") as Node2D
	return {
		"variant": str(rig.get("action_variant")),
		"pelvis_x": pelvis.position.x,
		"pelvis_y": pelvis.position.y,
		"socket_x": weapon_socket.position.x,
		"socket_y": weapon_socket.position.y,
		# Этап A (feet-origin): штатный вертикальный bias орбиты (−8 − lift/2) —
		# проверки «сокет у руки» вычитают его, оценивая только отклонение позы.
		"socket_bias": float(weapon_socket.get_meta("weapon_orbit_vertical_bias", 0.0)),
		"arm_l_x": arm_l.position.x,
		"arm_l_y": arm_l.position.y,
		"arm_l_rot": arm_l.rotation,
		"arm_r_x": arm_r.position.x,
		"arm_r_y": arm_r.position.y,
		"arm_r_rot": arm_r.rotation,
	}


func _sample_player_weapon_phase_pose(player: Node, character_id: String, weapon_id: String, attack_mode: String, action_id: String, phase: String, elapsed: float) -> Dictionary:
	player.configure_character(character_id, weapon_id)
	player.set("velocity", Vector2.ZERO)
	player.call("play_action_animation", action_id, Vector2.RIGHT, phase, 0.28, {
		"attack_mode": attack_mode,
		"weapon_id": weapon_id,
	})
	player.call("_update_movement_animation", elapsed)
	var rig := player.get_node("VisualRoot/RigRoot") as Node2D
	var pelvis := rig.get_node("Pelvis") as Node2D
	var arm_l := rig.get_node("Pelvis/Figure/Torso/ArmL") as Node2D
	var arm_r := rig.get_node("Pelvis/Figure/Torso/ArmR") as Node2D
	var weapon_socket := player.get_node("VisualRoot/WeaponSocket") as Node2D
	return {
		"variant": str(rig.get("action_variant")),
		"pelvis_x": pelvis.position.x,
		"pelvis_y": pelvis.position.y,
		"socket_x": weapon_socket.position.x,
		"socket_y": weapon_socket.position.y,
		"arm_l_x": arm_l.position.x,
		"arm_l_y": arm_l.position.y,
		"arm_l_rot": arm_l.rotation,
		"arm_r_x": arm_r.position.x,
		"arm_r_y": arm_r.position.y,
		"arm_r_rot": arm_r.rotation,
	}


func _idle_pose(player: Node, character_id: String, weapon_id: String) -> Dictionary:
	player.configure_character(character_id, weapon_id)
	player.set("velocity", Vector2.ZERO)
	player.call("_update_movement_animation", 0.0)
	var rig := player.get_node("VisualRoot/RigRoot") as Node2D
	var pelvis := rig.get_node("Pelvis") as Node2D
	var arm_l := rig.get_node("Pelvis/Figure/Torso/ArmL") as Node2D
	var arm_r := rig.get_node("Pelvis/Figure/Torso/ArmR") as Node2D
	var weapon_socket := player.get_node("VisualRoot/WeaponSocket") as Node2D
	return {
		"variant": "",
		"pelvis_x": pelvis.position.x,
		"pelvis_y": pelvis.position.y,
		"socket_x": weapon_socket.position.x,
		"socket_y": weapon_socket.position.y,
		"arm_l_x": arm_l.position.x,
		"arm_l_y": arm_l.position.y,
		"arm_l_rot": arm_l.rotation,
		"arm_r_x": arm_r.position.x,
		"arm_r_y": arm_r.position.y,
		"arm_r_rot": arm_r.rotation,
	}


func _assert_sliced_rig(root_node: Node, rig_path: String, texture_fragment: String, torso_parts: Array, figure_parts: Array, label: String) -> void:
	var rig := root_node.get_node_or_null(rig_path) as Node2D
	if rig == null:
		_fail("Expected %s rig at %s." % [label, rig_path])
	for node_name in ["Pelvis", "Pelvis/Figure", "Pelvis/Figure/Torso", "GroundShadow"]:
		if rig.get_node_or_null(node_name) == null:
			_fail("Expected %s rig node %s." % [label, node_name])
	for part_name in torso_parts:
		var part := rig.get_node_or_null("Pelvis/Figure/Torso/%s" % part_name) if part_name != "Torso" else rig.get_node_or_null("Pelvis/Figure/Torso")
		if part == null:
			_fail("Expected %s rig part %s." % [label, part_name])
		var sprite := part.get_node_or_null("Sprite") as Sprite2D
		if sprite == null or sprite.texture == null:
			_fail("Expected %s rig part %s to have a sprite texture." % [label, part_name])
		if not sprite.texture.resource_path.contains(texture_fragment):
			_fail("Expected %s rig part %s texture from %s, got %s." % [label, part_name, texture_fragment, sprite.texture.resource_path])
		if not sprite.visible:
			_fail("Expected %s rig part %s to be visible." % [label, part_name])
	for part_name in figure_parts:
		if rig.get_node_or_null("Pelvis/Figure/%s" % part_name) == null:
			_fail("Expected %s rig leg part %s." % [label, part_name])
	if rig.get_node_or_null("Pelvis/Figure/Torso/WeaponSocketMount") == null:
		_fail("Expected %s rig WeaponSocketMount." % label)


func _assert_knight_pixellab_combat_visual(player: Node, body: AnimatedSprite2D) -> void:
	# SCRUM-919 (follow-up SCRUM-430/869/885): бой Рыцаря обязан рендерить принятый
	# PixelLab full-frame пак, а не легаси-скелетный риг из skeleton_parts.
	var previous_velocity = player.get("velocity")
	var previous_animation_time := float(player.get("_animation_time"))
	var skeletal_rig := player.get_node_or_null("VisualRoot/SkeletalRigRoot") as Node2D
	if skeletal_rig != null and skeletal_rig.visible:
		_fail("Expected knight combat visual to drop the legacy SkeletalRigRoot (SCRUM-919).")
	var idle_texture := body.sprite_frames.get_frame_texture(str(body.animation), 0)
	if idle_texture == null or not idle_texture.resource_path.contains("assets/sprites/characters/full_frame/knight_pixellab/"):
		_fail("Expected knight combat idle frame from the accepted PixelLab pack, got %s." % (idle_texture.resource_path if idle_texture != null else "<null>"))
	player.set("velocity", Vector2(120, 0))
	player.call("_update_movement_animation", 0.20)
	var move_animation := str(body.animation)
	if move_animation != "walk_east" and move_animation != "move_east":
		_fail("Expected knight combat movement to play a directional PixelLab walk/move animation, got %s." % move_animation)
	if not body.sprite_frames.get_animation_loop(move_animation):
		_fail("Expected knight combat move animation %s to loop." % move_animation)
	if body.sprite_frames.get_frame_count(move_animation) < 5:
		_fail("Expected knight combat move animation %s to keep >=5 frames." % move_animation)
	if body.flip_h:
		_fail("Expected knight directional PixelLab animation to render without mirror flip.")
	var move_texture := body.sprite_frames.get_frame_texture(move_animation, 0)
	if move_texture == null or not move_texture.resource_path.contains("assets/sprites/characters/full_frame/knight_pixellab/"):
		_fail("Expected knight combat move frames from the accepted PixelLab pack, got %s." % (move_texture.resource_path if move_texture != null else "<null>"))
	player.set("velocity", Vector2.ZERO)
	player.call("_update_movement_animation", 0.20)
	var idle_animation := str(body.animation)
	if not idle_animation.begins_with("idle"):
		_fail("Expected knight to return to a looping PixelLab idle when stopped, got %s." % idle_animation)
	if not body.sprite_frames.get_animation_loop(idle_animation):
		_fail("Expected knight combat idle animation %s to loop." % idle_animation)
	var weapon_socket := player.get_node_or_null("VisualRoot/WeaponSocket") as Node2D
	if weapon_socket == null or not weapon_socket.has_meta("weapon_orbit_radius"):
		_fail("Expected knight weapon socket orbit behavior to remain configured.")
	player.set("velocity", previous_velocity)
	player.set("_animation_time", previous_animation_time)


func _test_enemy_projectile_sprite() -> void:
	var projectile_scene := load("res://scenes/EnemyProjectile.tscn") as PackedScene
	var projectile := projectile_scene.instantiate()
	root.add_child(projectile)
	var visual := projectile.get_node("Shape") as Sprite2D
	if visual.texture == null or visual.texture.resource_path != "res://assets/sprites/projectiles/enemy_projectile_magic_64.png":
		_fail("Expected enemy projectile to use the new 64px magic sprite.")
	if visual.scale.x < 0.45 or visual.scale.x > 0.65:
		_fail("Expected enemy projectile sprite to be readable but not oversized.")
	projectile.queue_free()


func _test_enemy_sprite_paths() -> void:
	var expected_paths := {
		"res://scenes/Enemy.tscn": "res://assets/sprites/enemies/enemy_melee.png",
		"res://scenes/EnemyShooter.tscn": "res://assets/sprites/enemies/enemy_ranged.png",
		"res://scenes/EnemySummoner.tscn": "res://assets/sprites/enemies/enemy_summoner.png",
		"res://scenes/EnemyRunner.tscn": "res://assets/sprites/enemies/enemy_suicide_runner.png",
		"res://scenes/EnemyBruiser.tscn": "res://assets/sprites/enemies/enemy_bruiser_slow.png",
		"res://scenes/EnemyMage.tscn": "res://assets/sprites/enemies/enemy_void_mage.png",
		"res://scenes/EnemySpitter.tscn": "res://assets/sprites/enemies/enemy_venom_spitter.png",
		"res://scenes/EnemyShield.tscn": "res://assets/sprites/enemies/enemy_rift_shieldbearer.png",
		"res://scenes/EnemyBiter.tscn": "res://assets/sprites/enemies/enemy_small_biter.png",
		"res://scenes/EnemyBoneShaman.tscn": "res://assets/sprites/enemies/enemy_bone_shaman.png",
		"res://scenes/EnemyFlyingRunner.tscn": "res://assets/sprites/enemies/enemy_winged_spark.png",
		"res://scenes/EliteArmored.tscn": "res://assets/sprites/elites/iron_bastion.png",
		"res://scenes/EliteStalker.tscn": "res://assets/sprites/elites/night_stalker.png",
		"res://scenes/ElitePoisoned.tscn": "res://assets/sprites/elites/plague_prophet.png",
		"res://scenes/EliteCommander.tscn": "res://assets/sprites/elites/shard_marshal.png",
	}

	for scene_path in expected_paths.keys():
		var scene := load(scene_path) as PackedScene
		var enemy := scene.instantiate()
		root.add_child(enemy)
		var body := enemy.get_node("Body") as Sprite2D
		if body.texture == null or body.texture.resource_path != expected_paths[scene_path]:
			_fail("Expected %s to use %s." % [scene_path, expected_paths[scene_path]])
		enemy.queue_free()

	var expected_boss_paths := {
		"res://scenes/BossWarden.tscn": "res://assets/sprites/bosses/boss_rift_warden.png",
		"res://scenes/BossDiskDevourer.tscn": "res://assets/sprites/bosses/boss_disk_devourer.png",
		"res://scenes/BossBoneArchon.tscn": "res://assets/sprites/bosses/boss_bone_archon.png",
		"res://scenes/BossBroodMother.tscn": "res://assets/sprites/bosses/boss_brood_mother.png",
		"res://scenes/BossAshenColossus.tscn": "res://assets/sprites/bosses/boss_ashen_colossus.png",
		"res://scenes/BossBloodthornLion.tscn": "res://assets/sprites/bosses/boss_bloodthorn_lion.png",
	}
	for boss_scene_path in expected_boss_paths.keys():
		var boss_scene := load(boss_scene_path) as PackedScene
		var boss := boss_scene.instantiate()
		root.add_child(boss)
		var boss_body := boss.get_node("Sprite2D") as Sprite2D
		if boss_body.texture == null or boss_body.texture.resource_path != expected_boss_paths[boss_scene_path]:
			_fail("Expected %s to use %s." % [boss_scene_path, expected_boss_paths[boss_scene_path]])
		boss.queue_free()


func _test_druid_wolf_ally_animation() -> void:
	var ally_scene := load("res://scenes/AllyMinion.tscn") as PackedScene
	var ally := ally_scene.instantiate()
	root.add_child(ally)
	ally.call("set_visual_id", "druid_beast")

	var body := ally.get_node("Body") as Sprite2D
	var animated_body := ally.get_node("AnimatedBody") as AnimatedSprite2D
	if body.visible:
		_fail("Expected druid_beast to hide the static ally fallback body.")
	if not animated_body.visible or not ally.call("is_using_animated_ally_visual"):
		_fail("Expected druid_beast to use AnimatedSprite2D.")
	if animated_body.sprite_frames == null:
		_fail("Expected druid_beast AnimatedSprite2D to have SpriteFrames.")
	for animation_name in ["move", "attack", "attack_primary", "death"]:
		if not animated_body.sprite_frames.has_animation(animation_name):
			_fail("Expected druid_beast SpriteFrames to expose %s animation." % animation_name)
	if animated_body.sprite_frames.get_frame_count("move") != 8 or animated_body.sprite_frames.get_frame_count("attack") != 6 \
			or animated_body.sprite_frames.get_frame_count("attack_primary") != 6 or animated_body.sprite_frames.get_frame_count("death") != 6:
		_fail("Expected druid_beast move/attack/death frame counts to match the Design handoff.")
	if not animated_body.sprite_frames.get_animation_loop("move") or animated_body.sprite_frames.get_animation_loop("attack") \
			or animated_body.sprite_frames.get_animation_loop("attack_primary") or animated_body.sprite_frames.get_animation_loop("death"):
		_fail("Expected druid_beast move to loop and attack/death to be one-shot.")
	if animated_body.animation != "move" or not animated_body.is_playing():
		_fail("Expected druid_beast to start in playing move animation.")

	ally.set("velocity", Vector2(120, 0))
	ally.call("_update_visual_animation")
	if not animated_body.flip_h:
		_fail("Expected druid_beast to flip horizontally when moving right.")
	ally.call("_play_attack_animation", Vector2.LEFT)
	if animated_body.animation != "attack" or animated_body.flip_h:
		_fail("Expected druid_beast attack animation to face the attack direction.")

	# SCRUM-336: all summon creatures are now animated like the wolf (move+attack).
	for summon_visual in ["druid_pack_spirit", "homunculus", "leadership_echo"]:
		ally.call("set_visual_id", summon_visual)
		if not animated_body.visible or body.visible or not ally.call("is_using_animated_ally_visual"):
			_fail("Expected summon '%s' to use the animated AnimatedSprite2D visual." % summon_visual)
		if animated_body.sprite_frames == null:
			_fail("Expected summon '%s' AnimatedSprite2D to have SpriteFrames." % summon_visual)
		for animation_name in ["move", "attack", "attack_primary", "death"]:
			if not animated_body.sprite_frames.has_animation(animation_name):
				_fail("Expected summon '%s' SpriteFrames to expose %s animation." % [summon_visual, animation_name])
		if animated_body.sprite_frames.get_frame_count("move") != 8 or animated_body.sprite_frames.get_frame_count("attack") != 6 \
				or animated_body.sprite_frames.get_frame_count("attack_primary") != 6 or animated_body.sprite_frames.get_frame_count("death") != 6:
			_fail("Expected summon '%s' move/attack/death frame counts to match the wolf system (8/6/6)." % summon_visual)
		if not animated_body.sprite_frames.get_animation_loop("move") or animated_body.sprite_frames.get_animation_loop("attack") \
				or animated_body.sprite_frames.get_animation_loop("attack_primary") or animated_body.sprite_frames.get_animation_loop("death"):
			_fail("Expected summon '%s' move to loop and attack/death to be one-shot." % summon_visual)
	ally.queue_free()


func _test_druid_ghost_horizontal_ally_animations() -> void:
	var ally_scene := load("res://scenes/AllyMinion.tscn") as PackedScene
	var expected_ids := [
		"druid_ghost_wolf",
		"druid_ghost_bear",
		"druid_ghost_panther",
		"druid_ghost_stag",
		"druid_ghost_lion",
	]
	var allowed_animations := [
		"attack",
		"attack_left",
		"attack_right",
		"move",
		"move_left",
		"move_right",
	]
	for ghost_id in expected_ids:
		var frames := FullFrameAnimationRegistry.sprite_frames_for("ally", ghost_id)
		if frames == null:
			_fail("Expected %s to resolve through FullFrameAnimationRegistry." % ghost_id)
			return
		var animation_names := []
		for animation_name in frames.get_animation_names():
			animation_names.append(str(animation_name))
		animation_names.sort()
		if animation_names != allowed_animations:
			_fail("Expected %s to expose only horizontal move/attack rows, got %s." % [ghost_id, str(animation_names)])
			return
		for animation_name in allowed_animations:
			if frames.get_frame_count(animation_name) != 6:
				_fail("Expected %s %s to expose exactly 6 PixelLab frames." % [ghost_id, animation_name])
				return
			var should_loop: bool = str(animation_name).begins_with("move")
			if frames.get_animation_loop(animation_name) != should_loop:
				_fail("Expected %s %s loop=%s." % [ghost_id, animation_name, str(should_loop)])
				return
			for frame_index in range(frames.get_frame_count(animation_name)):
				var texture := frames.get_frame_texture(animation_name, frame_index)
				if texture == null or texture.get_image() == null or texture.get_image().get_size() != Vector2i(256, 256):
					_fail("Expected %s %s frame %d to use a 256x256 runtime texture." % [ghost_id, animation_name, frame_index])
					return
				var expected_direction := "right" if animation_name.ends_with("_right") else "left"
				var expected_kind := "attack" if animation_name.begins_with("attack") else "move"
				var expected_prefix := "res://assets/sprites/allies/%s/runtime/%s_%s_%s_" % [ghost_id, ghost_id, expected_kind, expected_direction]
				if not texture.resource_path.begins_with(expected_prefix):
					_fail("Expected %s %s frame %d to resolve from %s, got %s." % [ghost_id, animation_name, frame_index, expected_prefix, texture.resource_path])
					return
		var runtime_files := []
		for file_name in DirAccess.get_files_at("res://assets/sprites/allies/%s/runtime" % ghost_id):
			if file_name.ends_with(".png"):
				runtime_files.append(file_name)
		if runtime_files.size() != 24:
			_fail("Expected %s runtime folder to contain exactly 24 west/east PNGs, got %d." % [ghost_id, runtime_files.size()])
			return
		for file_name in runtime_files:
			for forbidden_direction in ["north", "south", "up", "down"]:
				if str(file_name).contains(forbidden_direction):
					_fail("Expected %s runtime folder to omit %s direction assets: %s." % [ghost_id, forbidden_direction, file_name])
					return
		if ghost_id == "druid_ghost_bear":
			var smallest_alpha_area := 1 << 30
			var largest_alpha_area := 0
			for frame_index in range(frames.get_frame_count(&"move_right")):
				var texture := frames.get_frame_texture(&"move_right", frame_index)
				var image := texture.get_image() if texture != null else null
				var meaningful_alpha_area := _meaningful_alpha_pixel_count(image, 4.0 / 255.0)
				if meaningful_alpha_area <= 0:
					_fail("Expected druid_ghost_bear move_right frame %d to contain meaningful alpha." % frame_index)
					return
				smallest_alpha_area = mini(smallest_alpha_area, meaningful_alpha_area)
				largest_alpha_area = maxi(largest_alpha_area, meaningful_alpha_area)
			var alpha_area_ratio := float(largest_alpha_area) / float(maxi(smallest_alpha_area, 1))
			if alpha_area_ratio > 1.65:
				_fail("Expected druid_ghost_bear move_right silhouette continuity <=1.65x, got %.3fx." % alpha_area_ratio)
				return

		var ally := ally_scene.instantiate()
		root.add_child(ally)
		ally.call("set_visual_id", ghost_id)
		var body := ally.get_node("Body") as Sprite2D
		var animated_body := ally.get_node("AnimatedBody") as AnimatedSprite2D
		if body.visible or not animated_body.visible or not ally.call("is_using_animated_ally_visual"):
			_fail("Expected %s to use its directional AnimatedSprite2D visual." % ghost_id)
			ally.queue_free()
			return
		if not FullFrameAnimationRegistry.uses_explicit_horizontal_directions(animated_body):
			_fail("Expected %s to declare explicit horizontal direction rows." % ghost_id)
			ally.queue_free()
			return

		ally.set("velocity", Vector2.LEFT * 120.0)
		ally.call("_update_visual_animation")
		if animated_body.animation != &"move_left" or animated_body.flip_h:
			_fail("Expected %s left movement to play move_left without horizontal flip." % ghost_id)
			ally.queue_free()
			return
		ally.set("velocity", Vector2.RIGHT * 120.0)
		ally.call("_update_visual_animation")
		if animated_body.animation != &"move_right" or animated_body.flip_h:
			_fail("Expected %s right movement to play move_right without horizontal flip." % ghost_id)
			ally.queue_free()
			return
		ally.call("_play_attack_animation", Vector2.LEFT)
		if animated_body.animation != &"attack_left" or animated_body.flip_h:
			_fail("Expected %s left action to play attack_left without horizontal flip." % ghost_id)
			ally.queue_free()
			return
		ally.call("_play_attack_animation", Vector2.RIGHT)
		if animated_body.animation != &"attack_right" or animated_body.flip_h:
			_fail("Expected %s right action to play attack_right without horizontal flip." % ghost_id)
			ally.queue_free()
			return
		if float(ally.get("_attack_anim_time")) < 0.5:
			_fail("Expected %s action visual window to cover all 6 frames at 12fps." % ghost_id)
			ally.queue_free()
			return
		if ghost_id in ["druid_ghost_stag", "druid_ghost_lion"]:
			if not FullFrameAnimationRegistry.play_state(animated_body, "cast", Vector2.LEFT) or animated_body.animation != &"attack_left" or animated_body.flip_h:
				_fail("Expected %s cast alias to resolve to attack_left without flip." % ghost_id)
				ally.queue_free()
				return
			if not FullFrameAnimationRegistry.play_state(animated_body, "cast", Vector2.RIGHT) or animated_body.animation != &"attack_right" or animated_body.flip_h:
				_fail("Expected %s cast alias to resolve to attack_right without flip." % ghost_id)
				ally.queue_free()
				return
		ally.call("_play_attack_animation", Vector2.UP)
		if animated_body.animation != &"attack_right" or animated_body.flip_h:
			_fail("Expected %s vertical target action to preserve the last horizontal facing without flip." % ghost_id)
			ally.queue_free()
			return
		ally.queue_free()


func _meaningful_alpha_pixel_count(image: Image, threshold: float) -> int:
	if image == null or image.is_empty():
		return 0
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > threshold:
				count += 1
	return count


func _test_full_frame_animation_registry() -> void:
	var frames := FullFrameAnimationRegistry.sprite_frames_for("ally", "druid_beast")
	if frames == null or not frames.has_animation("move") or not frames.has_animation("attack") \
			or not frames.has_animation("attack_primary") or not frames.has_animation("death"):
		_fail("Expected full-frame registry to resolve druid_beast move/attack/death SpriteFrames.")
	var standard_enemy_scenes := {
		"rift_cutter": "res://scenes/Enemy.tscn",
		"ash_marksman": "res://scenes/EnemyShooter.tscn",
		"spark_runner": "res://scenes/EnemyRunner.tscn",
		"stone_bruiser": "res://scenes/EnemyBruiser.tscn",
		"bone_caller": "res://scenes/EnemySummoner.tscn",
		"void_mage": "res://scenes/EnemyMage.tscn",
		"venom_spitter": "res://scenes/EnemySpitter.tscn",
		"rift_shieldbearer": "res://scenes/EnemyShield.tscn",
		"small_biter": "res://scenes/EnemyBiter.tscn",
		"bone_shaman": "res://scenes/EnemyBoneShaman.tscn",
		"winged_spark": "res://scenes/EnemyFlyingRunner.tscn",
	}
	# FAN-3040: octant row lengths are pack-authored art, not a shared contract —
	# the single hardcoded shape below expected 1/6/6/4/6 for every directional
	# enemy, which only ever matched bone_caller (FAN-2613). Declare the length
	# each pack actually ships so the per-octant assertion stays exact.
	var directional_enemy_row_frames := {
		"rift_cutter": {"idle": 4, "move": 6, "attack": 6, "hit": 6, "death": 6},
		"ash_marksman": {"idle": 1, "move": 6, "attack": 7, "hit": 5, "death": 7},
		"bone_caller": {"idle": 1, "move": 6, "attack": 6, "hit": 4, "death": 6},
	}
	for enemy_id in standard_enemy_scenes.keys():
		var enemy_frames := FullFrameAnimationRegistry.sprite_frames_for("enemy", enemy_id)
		if enemy_frames == null:
			_fail("Expected full-frame registry to resolve %s SpriteFrames." % enemy_id)
			continue
		# FAN-2613: branch on the registry's own explicit_eight_directions flag,
		# not a hardcoded ID list, so the next converted standard_monster falls
		# into the directional contract automatically instead of re-breaking
		# this test (mirrors the FAN-2901 mini-elite pattern below).
		var enemy_is_directional := bool(FullFrameAnimationRegistry.registry_config("enemy", enemy_id).get("explicit_eight_directions", false))
		if enemy_is_directional:
			var enemy_row_frames: Dictionary = directional_enemy_row_frames.get(enemy_id, {})
			if enemy_row_frames.is_empty():
				_fail("Expected %s to declare its directional row lengths in directional_enemy_row_frames." % enemy_id)
			for state_name in ["idle", "move", "attack", "hit", "death"]:
				var enemy_state_should_loop: bool = state_name in ["idle", "move"]
				var enemy_expected_frames := int(enemy_row_frames.get(state_name, 0))
				for dir_suffix in FullFrameAnimationRegistry.DIRECTION_SUFFIXES:
					var enemy_directional_row := "%s_%s" % [state_name, dir_suffix]
					if not enemy_frames.has_animation(enemy_directional_row):
						_fail("Expected %s SpriteFrames to expose %s." % [enemy_id, enemy_directional_row])
					else:
						if enemy_frames.get_animation_loop(enemy_directional_row) != enemy_state_should_loop:
							_fail("Expected %s %s loop to be %s." % [enemy_id, enemy_directional_row, str(enemy_state_should_loop)])
						if enemy_frames.get_frame_count(enemy_directional_row) != enemy_expected_frames:
							_fail("Expected %s %s to have %d frames." % [enemy_id, enemy_directional_row, enemy_expected_frames])
		else:
			for animation_name in ["move", "attack", "attack_primary", "hit", "death"]:
				if not enemy_frames.has_animation(animation_name):
					_fail("Expected %s SpriteFrames to expose %s animation." % [enemy_id, animation_name])
				elif enemy_frames.get_frame_count(animation_name) != 6:
					_fail("Expected %s %s to have 6 frames." % [enemy_id, animation_name])
			if not enemy_frames.get_animation_loop("move"):
				_fail("Expected %s move to loop." % enemy_id)
			for one_shot_name in ["attack", "attack_primary", "hit", "death"]:
				if enemy_frames.get_animation_loop(one_shot_name):
					_fail("Expected %s %s to be one-shot." % [enemy_id, one_shot_name])
		if enemy_id == "winged_spark":
			if not enemy_frames.has_animation("hover_flap") or enemy_frames.get_frame_count("hover_flap") != 6:
				_fail("Expected winged_spark hover_flap to have 6 frames.")
			elif not enemy_frames.get_animation_loop("hover_flap"):
				_fail("Expected winged_spark hover_flap to loop.")
		if enemy_id == "rift_cutter":
			# FAN-2609: explicit 8-direction runtime contract — every state must
			# expose all eight `<state>_<suffix>` rows, never a mirrored fallback.
			for state_name in ["idle", "move", "attack_primary", "hit", "death"]:
				if not FullFrameAnimationRegistry.has_full_directional_rows(enemy_frames, state_name):
					_fail("Expected rift_cutter %s to expose all eight directional rows." % state_name)
			for suffix in FullFrameAnimationRegistry.DIRECTION_SUFFIXES:
				if enemy_frames.get_frame_count("idle_%s" % suffix) != 4:
					_fail("Expected rift_cutter idle_%s to have 4 frames." % suffix)
				for state_name in ["move", "attack_primary", "hit", "death"]:
					if enemy_frames.get_frame_count("%s_%s" % [state_name, suffix]) != 6:
						_fail("Expected rift_cutter %s_%s to have 6 frames." % [state_name, suffix])
	if FullFrameAnimationRegistry.sprite_frames_for("enemy", "missing_test_enemy") != null:
		_fail("Expected missing full-frame registry entries to return null.")

	var owner := Node2D.new()
	root.add_child(owner)
	owner.set_meta("full_frame_spriteframes_path", "res://assets/sprites/allies/ally_druid_wolf_spriteframes.tres")
	owner.set_meta("full_frame_scale", Vector2(0.34, 0.34))
	owner.set_meta("full_frame_position", Vector2(0.0, -31.0))
	owner.set_meta("full_frame_source_faces_left", true)
	var static_body := Sprite2D.new()
	static_body.name = "Body"
	static_body.visible = true
	owner.add_child(static_body)
	var animated_body := FullFrameAnimationRegistry.configure_entity_visual(owner, "enemy", "runtime_dummy")
	if animated_body == null or not animated_body.visible or static_body.visible:
		_fail("Expected registry to create visible FullFrameBody and hide static Body.")
	if str(animated_body.get_meta("entity_kind", "")) != "enemy" or str(animated_body.get_meta("entity_id", "")) != "runtime_dummy":
		_fail("Expected registry to tag entity kind/id on FullFrameBody.")
	if not FullFrameAnimationRegistry.play_state(animated_body, "attack_slam_wave", Vector2.RIGHT):
		_fail("Expected registry to accept boss/elite-style skill state names.")
	if animated_body.animation != "attack":
		_fail("Expected attack_slam_wave to resolve to existing attack animation.")
	if not animated_body.flip_h:
		_fail("Expected source-left full-frame art to flip when facing right.")
	if str(animated_body.get_meta("last_requested_state", "")) != "attack_slam_wave" or str(animated_body.get_meta("last_resolved_state", "")) != "attack":
		_fail("Expected FullFrameBody metadata to expose requested/resolved state.")
	owner.queue_free()

	for enemy_id in standard_enemy_scenes.keys():
		var enemy_scene := load(str(standard_enemy_scenes[enemy_id])) as PackedScene
		var enemy := enemy_scene.instantiate()
		root.add_child(enemy)
		if enemy.get_node_or_null("FullFrameBody") == null:
			enemy.call("_configure_full_frame_animation")
		enemy.call("_update_movement_animation", 0.1)
		var enemy_full_frame_body := enemy.get_node_or_null("FullFrameBody") as AnimatedSprite2D
		if enemy_full_frame_body == null or not enemy_full_frame_body.visible:
			_fail("Expected %s enemies to create a visible FullFrameBody." % enemy_id)
		if enemy_full_frame_body != null:
			var enemy_scene_is_directional := bool(FullFrameAnimationRegistry.registry_config("enemy", enemy_id).get("explicit_eight_directions", false))
			if enemy_scene_is_directional:
				for state_name in ["idle", "move", "hit", "death"]:
					if not enemy_full_frame_body.sprite_frames.has_animation("%s_west" % state_name):
						_fail("Expected %s enemy FullFrameBody to use registry SpriteFrames." % enemy_id)
				if enemy_full_frame_body.animation != "idle_west":
					_fail("Expected %s enemy FullFrameBody to start in idle_west (last-facing default)." % enemy_id)
				if not FullFrameAnimationRegistry.play_state(enemy_full_frame_body, "attack", Vector2.RIGHT):
					_fail("Expected %s FullFrameBody to play attack." % enemy_id)
				if enemy_full_frame_body.animation != "attack_east":
					_fail("Expected %s attack to resolve to attack_east, got %s." % [enemy_id, enemy_full_frame_body.animation])
				if enemy_full_frame_body.flip_h:
					_fail("Expected %s eight-direction full-frame art to never mirror via flip_h." % enemy_id)
				# FAN-2609/FAN-2889: a pack that also ships the attack_primary alias per
				# octant must resolve that alias through its own east row, never through
				# a mirrored surrogate of another facing.
				if enemy_full_frame_body.sprite_frames.has_animation("attack_primary_east"):
					if not FullFrameAnimationRegistry.play_state(enemy_full_frame_body, "attack_primary", Vector2.RIGHT):
						_fail("Expected %s FullFrameBody to play attack_primary." % enemy_id)
					if enemy_full_frame_body.animation != "attack_primary_east" or enemy_full_frame_body.flip_h:
						_fail("Expected %s attack_primary to resolve to attack_primary_east without flip." % enemy_id)
			else:
				for animation_name in ["move", "attack_primary", "hit", "death"]:
					if not enemy_full_frame_body.sprite_frames.has_animation(animation_name):
						_fail("Expected %s enemy FullFrameBody to use registry SpriteFrames." % enemy_id)
				if enemy_full_frame_body.animation != "move":
					_fail("Expected %s enemy FullFrameBody to start in move animation." % enemy_id)
				if not FullFrameAnimationRegistry.play_state(enemy_full_frame_body, "attack_primary", Vector2.RIGHT):
					_fail("Expected %s FullFrameBody to play attack_primary." % enemy_id)
				if enemy_full_frame_body.animation != "attack_primary" or not enemy_full_frame_body.flip_h:
					_fail("Expected %s attack_primary to resolve and face right." % enemy_id)
		var enemy_static_body := enemy.get_node_or_null("Body") as CanvasItem
		if enemy_static_body != null and enemy_static_body.visible:
			_fail("Expected %s full-frame visual to hide the static body fallback." % enemy_id)
		enemy.queue_free()

	var elite_full_frame_scenes := {
		"iron_bastion": {
			"path": "res://scenes/EliteArmored.tscn",
			"skill_states": ["skill_shield_block", "skill_slam_wave"],
			"phase_state": "iron_bastion:slam_wave:windup",
			"phase_resolved": "skill_slam_wave",
		},
		"night_stalker": {
			"path": "res://scenes/EliteStalker.tscn",
			"skill_states": ["skill_shadow_strike", "skill_phase_dash"],
			"phase_state": "night_stalker:shadow_strike:windup",
			"phase_resolved": "skill_shadow_strike",
		},
		"plague_prophet": {
			"path": "res://scenes/ElitePoisoned.tscn",
			"skill_states": ["skill_poison_volley", "skill_plague_aura"],
			"phase_state": "plague_prophet:poison_volley:windup",
			"phase_resolved": "skill_poison_volley",
		},
		"shard_marshal": {
			"path": "res://scenes/EliteCommander.tscn",
			"skill_states": ["skill_shard_fan", "skill_command_pulse"],
			"phase_state": "shard_marshal:shard_fan:windup",
			"phase_resolved": "skill_shard_fan",
		},
	}
	for elite_id in elite_full_frame_scenes.keys():
		var elite_info: Dictionary = elite_full_frame_scenes[elite_id]
		var elite_frames := FullFrameAnimationRegistry.sprite_frames_for("elite", elite_id)
		if elite_frames == null:
			_fail("Expected full-frame registry to resolve %s elite SpriteFrames." % elite_id)
			continue
		for animation_name in ["move", "attack", "attack_primary"]:
			if not elite_frames.has_animation(animation_name):
				_fail("Expected %s elite SpriteFrames to expose %s animation." % [elite_id, animation_name])
			elif elite_frames.get_frame_count(animation_name) != 6:
				_fail("Expected %s elite %s to have 6 frames." % [elite_id, animation_name])
		if not elite_frames.get_animation_loop("move"):
			_fail("Expected %s elite move to loop." % elite_id)
		if elite_id in ["iron_bastion", "night_stalker", "plague_prophet", "shard_marshal"]:
			if not elite_frames.has_animation("death"):
				_fail("Expected %s elite SpriteFrames to expose death after SCRUM-370 death integration." % elite_id)
			elif elite_frames.get_frame_count("death") != 6:
				_fail("Expected %s elite death to have 6 frames." % elite_id)
		for one_shot_name in ["attack", "attack_primary", "death"]:
			if not elite_frames.has_animation(one_shot_name):
				continue
			if elite_frames.get_animation_loop(one_shot_name):
				_fail("Expected %s elite %s to be one-shot." % [elite_id, one_shot_name])
		for skill_state in elite_info["skill_states"]:
			var skill_name := str(skill_state)
			var attack_alias := "attack_%s" % skill_name.trim_prefix("skill_")
			if not elite_frames.has_animation(skill_name):
				_fail("Expected %s elite SpriteFrames to expose %s." % [elite_id, skill_name])
			elif elite_frames.get_frame_count(skill_name) != 6:
				_fail("Expected %s elite %s to have 6 frames." % [elite_id, skill_name])
			if elite_frames.has_animation(skill_name) and elite_frames.get_animation_loop(skill_name):
				_fail("Expected %s elite %s to be one-shot." % [elite_id, skill_name])
			if not elite_frames.has_animation(attack_alias):
				_fail("Expected %s elite SpriteFrames to expose %s validator alias." % [elite_id, attack_alias])
			elif elite_frames.get_frame_count(attack_alias) != 6:
				_fail("Expected %s elite %s alias to have 6 frames." % [elite_id, attack_alias])
			if elite_frames.has_animation(attack_alias) and elite_frames.get_animation_loop(attack_alias):
				_fail("Expected %s elite %s alias to be one-shot." % [elite_id, attack_alias])

		var elite_scene := load(str(elite_info["path"])) as PackedScene
		var elite := elite_scene.instantiate()
		root.add_child(elite)
		if elite.get_node_or_null("FullFrameBody") == null:
			elite.call("_configure_full_frame_animation")
		elite.call("_update_movement_animation", 0.1)
		var elite_full_frame_body := elite.get_node_or_null("FullFrameBody") as AnimatedSprite2D
		if elite_full_frame_body == null or not elite_full_frame_body.visible:
			_fail("Expected %s elite scene to create a visible FullFrameBody." % elite_id)
		if elite_full_frame_body != null:
			if not FullFrameAnimationRegistry.play_state(elite_full_frame_body, str(elite_info["phase_state"]), Vector2.RIGHT):
				_fail("Expected %s elite phase state to resolve through the full-frame registry." % elite_id)
			if elite_full_frame_body.animation != str(elite_info["phase_resolved"]):
				_fail("Expected %s elite phase to resolve to %s, got %s." % [elite_id, str(elite_info["phase_resolved"]), elite_full_frame_body.animation])
			if not elite_full_frame_body.flip_h:
				_fail("Expected %s elite full-frame art to face right via flip_h." % elite_id)
		var elite_static_body := elite.get_node_or_null("Body") as CanvasItem
		if elite_static_body != null and elite_static_body.visible:
			_fail("Expected %s elite full-frame visual to hide the static body fallback." % elite_id)
		elite.queue_free()

	var mini_elite_full_frame_scenes := {
		"mini_scavenger_reaper": {
			"path": "res://scenes/EliteStalker.tscn",
			"skill_states": ["skill_reaping_dash", "skill_bleed_finish"],
			"phase_state": "mini_scavenger_reaper:reaping_dash:windup",
			"phase_resolved": "skill_reaping_dash",
		},
		"mini_plague_bellringer": {
			"path": "res://scenes/ElitePoisoned.tscn",
			"skill_states": ["skill_bell_toll", "skill_poison_pool"],
			"phase_state": "mini_plague_bellringer:bell_toll:windup",
			"phase_resolved": "skill_bell_toll",
		},
		"mini_bone_warden": {
			"path": "res://scenes/EliteArmored.tscn",
			"skill_states": ["skill_bone_guard", "skill_slam_wave"],
			"phase_state": "mini_bone_warden:slam_wave:windup",
			"phase_resolved": "skill_slam_wave",
		},
		"mini_spark_wight": {
			"path": "res://scenes/EliteCommander.tscn",
			"skill_states": ["skill_spark_fan", "skill_static_field"],
			"phase_state": "mini_spark_wight:spark_fan:windup",
			"phase_resolved": "skill_spark_fan",
		},
		"mini_rot_hound": {
			"path": "res://scenes/EliteStalker.tscn",
			"skill_states": ["skill_shadow_strike"],
			"phase_state": "mini_rot_hound:shadow_strike:windup",
			"phase_resolved": "skill_shadow_strike",
		},
		"mini_shadow_devourer": {
			"path": "res://scenes/EliteStalker.tscn",
			"skill_states": ["skill_shadow_blink", "skill_devour_bite"],
			"phase_state": "mini_shadow_devourer:shadow_blink:windup",
			"phase_resolved": "skill_shadow_blink",
		},
	}
	for mini_id in mini_elite_full_frame_scenes.keys():
		var mini_info: Dictionary = mini_elite_full_frame_scenes[mini_id]
		var mini_frames := FullFrameAnimationRegistry.sprite_frames_for("elite", mini_id)
		if mini_frames == null:
			_fail("Expected full-frame registry to resolve %s mini-elite SpriteFrames." % mini_id)
			continue
		# FAN-2901: branch on the registry's own explicit_eight_directions flag,
		# not a hardcoded ID list, so the next converted mini-elite falls into
		# the directional contract automatically instead of re-breaking this test.
		var mini_is_directional := bool(FullFrameAnimationRegistry.registry_config("elite", mini_id).get("explicit_eight_directions", false))
		if mini_is_directional:
			for state_name in ["idle", "move", "attack", "hit", "death"]:
				var state_should_loop: bool = state_name in ["idle", "move"]
				for dir_suffix in FullFrameAnimationRegistry.DIRECTION_SUFFIXES:
					var directional_row := "%s_%s" % [state_name, dir_suffix]
					if not mini_frames.has_animation(directional_row):
						_fail("Expected %s mini-elite SpriteFrames to expose %s." % [mini_id, directional_row])
					elif mini_frames.get_animation_loop(directional_row) != state_should_loop:
						_fail("Expected %s mini-elite %s loop to be %s." % [mini_id, directional_row, str(state_should_loop)])
			for skill_state in mini_info["skill_states"]:
				var mini_skill_base := str(skill_state)
				for dir_suffix in FullFrameAnimationRegistry.DIRECTION_SUFFIXES:
					var mini_skill_row := "%s_%s" % [mini_skill_base, dir_suffix]
					if not mini_frames.has_animation(mini_skill_row):
						_fail("Expected %s mini-elite SpriteFrames to expose %s." % [mini_id, mini_skill_row])
					elif mini_frames.get_animation_loop(mini_skill_row):
						_fail("Expected %s mini-elite %s to be one-shot." % [mini_id, mini_skill_row])
		else:
			for animation_name in ["move", "attack", "attack_primary"]:
				if not mini_frames.has_animation(animation_name):
					_fail("Expected %s mini-elite SpriteFrames to expose %s animation." % [mini_id, animation_name])
				elif mini_frames.get_frame_count(animation_name) != 6:
					_fail("Expected %s mini-elite %s to have 6 frames." % [mini_id, animation_name])
			if not mini_frames.get_animation_loop("move"):
				_fail("Expected %s mini-elite move to loop." % mini_id)
			if not mini_frames.has_animation("death"):
				_fail("Expected %s mini-elite SpriteFrames to expose death after SCRUM-370 death integration." % mini_id)
			elif mini_frames.get_frame_count("death") != 6:
				_fail("Expected %s mini-elite death to have 6 frames." % mini_id)
			for one_shot_name in ["attack", "attack_primary", "death"]:
				if not mini_frames.has_animation(one_shot_name):
					continue
				if mini_frames.get_animation_loop(one_shot_name):
					_fail("Expected %s mini-elite %s to be one-shot." % [mini_id, one_shot_name])
			for skill_state in mini_info["skill_states"]:
				var mini_skill_name := str(skill_state)
				var mini_attack_alias := "attack_%s" % mini_skill_name.trim_prefix("skill_")
				if not mini_frames.has_animation(mini_skill_name):
					_fail("Expected %s mini-elite SpriteFrames to expose %s." % [mini_id, mini_skill_name])
				elif mini_frames.get_frame_count(mini_skill_name) != 6:
					_fail("Expected %s mini-elite %s to have 6 frames." % [mini_id, mini_skill_name])
				if mini_frames.has_animation(mini_skill_name) and mini_frames.get_animation_loop(mini_skill_name):
					_fail("Expected %s mini-elite %s to be one-shot." % [mini_id, mini_skill_name])
				if not mini_frames.has_animation(mini_attack_alias):
					_fail("Expected %s mini-elite SpriteFrames to expose %s validator alias." % [mini_id, mini_attack_alias])
				elif mini_frames.get_frame_count(mini_attack_alias) != 6:
					_fail("Expected %s mini-elite %s alias to have 6 frames." % [mini_id, mini_attack_alias])
				if mini_frames.has_animation(mini_attack_alias) and mini_frames.get_animation_loop(mini_attack_alias):
					_fail("Expected %s mini-elite %s alias to be one-shot." % [mini_id, mini_attack_alias])

		var mini_scene := load(str(mini_info["path"])) as PackedScene
		var mini := mini_scene.instantiate()
		root.add_child(mini)
		mini.set_meta("mini_elite_kind", mini_id)
		mini.call("refresh_full_frame_visual")
		mini.call("_update_movement_animation", 0.1)
		var mini_body := mini.get_node_or_null("FullFrameBody") as AnimatedSprite2D
		if mini_body == null or not mini_body.visible:
			_fail("Expected %s mini-elite scene to create a visible FullFrameBody." % mini_id)
		if mini_body != null:
			if str(mini_body.get_meta("entity_id", "")) != mini_id:
				_fail("Expected %s mini_elite_kind to select mini-specific SpriteFrames, got %s." % [mini_id, str(mini_body.get_meta("entity_id", ""))])
			if not FullFrameAnimationRegistry.play_state(mini_body, str(mini_info["phase_state"]), Vector2.RIGHT):
				_fail("Expected %s mini-elite phase state to resolve through the full-frame registry." % mini_id)
			if mini_is_directional:
				var mini_expected_directional_animation := "%s_east" % str(mini_info["phase_resolved"])
				if mini_body.animation != mini_expected_directional_animation:
					_fail("Expected %s mini-elite phase to resolve to %s, got %s." % [mini_id, mini_expected_directional_animation, mini_body.animation])
				if mini_body.flip_h:
					_fail("Expected %s mini-elite eight-direction full-frame art to never mirror via flip_h." % mini_id)
			else:
				if mini_body.animation != str(mini_info["phase_resolved"]):
					_fail("Expected %s mini-elite phase to resolve to %s, got %s." % [mini_id, str(mini_info["phase_resolved"]), mini_body.animation])
				if not mini_body.flip_h:
					_fail("Expected %s mini-elite full-frame art to face right via flip_h." % mini_id)
		var mini_static_body := mini.get_node_or_null("Body") as CanvasItem
		if mini_static_body != null and mini_static_body.visible:
			_fail("Expected %s mini-elite full-frame visual to hide the static body fallback." % mini_id)
		mini.queue_free()

	var mini_visual_scene := load("res://scenes/EliteStalker.tscn") as PackedScene
	var mini_visual_elite := mini_visual_scene.instantiate()
	root.add_child(mini_visual_elite)
	mini_visual_elite.set_meta("mini_elite_kind", "mini_scavenger_reaper")
	mini_visual_elite.call("refresh_full_frame_visual")
	var mini_visual_body := mini_visual_elite.get_node_or_null("FullFrameBody") as AnimatedSprite2D
	if mini_visual_body == null:
		_fail("Expected mini-elite metadata refresh to preserve a FullFrameBody.")
	elif str(mini_visual_body.get_meta("entity_id", "")) != "mini_scavenger_reaper":
		_fail("Expected mini_elite_kind with registered SpriteFrames to override the base elite visual id.")
	mini_visual_elite.set_meta("mini_elite_kind", "missing_mini_visual_test")
	mini_visual_elite.call("refresh_full_frame_visual")
	mini_visual_body = mini_visual_elite.get_node_or_null("FullFrameBody") as AnimatedSprite2D
	if mini_visual_body == null:
		_fail("Expected missing mini-elite visual id to keep the route elite fallback FullFrameBody.")
	elif str(mini_visual_body.get_meta("entity_id", "")) != "night_stalker":
		_fail("Expected missing mini_elite_kind SpriteFrames to fall back to elite_behavior visual id.")
	mini_visual_elite.queue_free()

	var boss_full_frame_scenes := {
		"rift_warden": {
			"path": "res://scenes/BossWarden.tscn",
			"skill_states": ["skill_gravity_well", "skill_rift_zone"],
			"phase_state": "rift_warden:gravity_well:windup",
			"phase_resolved": "skill_gravity_well",
			"hook_method": "_play_boss_skill_visual",
			"hook_args": ["skill_gravity_well", "cast", Vector2.RIGHT],
			"hook_expected": "skill_gravity_well",
		},
		"disk_devourer": {
			"path": "res://scenes/BossDiskDevourer.tscn",
			"skill_states": ["skill_vampiric_bite", "skill_rift_zone"],
			"phase_state": "disk_devourer:vampiric_bite:windup",
			"phase_resolved": "skill_vampiric_bite",
			"hook_method": "_play_boss_skill_visual",
			"hook_args": ["skill_rift_zone", "cast", Vector2.RIGHT],
			"hook_expected": "skill_rift_zone",
		},
		"bone_archon": {
			"path": "res://scenes/BossBoneArchon.tscn",
			"skill_states": ["skill_skull_volley", "skill_bone_prison"],
			"phase_state": "bone_archon:skull_volley:windup",
			"phase_resolved": "skill_skull_volley",
			"hook_method": "_play_boss_skill_visual",
			"hook_args": ["skill_bone_prison", "cast", Vector2.RIGHT],
			"hook_expected": "skill_bone_prison",
		},
		"brood_mother": {
			"path": "res://scenes/BossBroodMother.tscn",
			"skill_states": ["skill_brood_spawn", "skill_web_zone"],
			"phase_state": "brood_mother:brood_spawn:windup",
			"phase_resolved": "skill_brood_spawn",
			"hook_method": "_play_boss_skill_visual",
			"hook_args": ["skill_web_zone", "cast", Vector2.RIGHT],
			"hook_expected": "skill_web_zone",
		},
		"ashen_colossus": {
			"path": "res://scenes/BossAshenColossus.tscn",
			"skill_states": ["skill_molten_slam", "skill_armor_pulse"],
			"phase_state": "ashen_colossus:molten_slam:windup",
			"phase_resolved": "skill_molten_slam",
			"hook_method": "_play_boss_skill_visual",
			"hook_args": ["skill_molten_slam", "attack", Vector2.RIGHT],
			"hook_expected": "skill_molten_slam",
		},
		"bloodthorn_lion": {
			"path": "res://scenes/BossBloodthornLion.tscn",
			"skill_states": ["skill_spike_ring", "skill_rift_zone"],
			"phase_state": "bloodthorn_lion:spike_ring:windup",
			"phase_resolved": "skill_spike_ring",
			"hook_method": "_play_boss_skill_visual",
			"hook_args": ["skill_spike_ring", "cast", Vector2.RIGHT],
			"hook_expected": "skill_spike_ring",
		},
	}
	# FAN-2635: same explicit_eight_directions branch as the enemy/mini-elite
	# loops above — declare the directional boss's per-state row length so the
	# next converted boss falls into the directional contract automatically.
	var directional_boss_row_frames := {
		"disk_devourer": {"idle": 1, "move": 7, "attack": 7, "hit": 5, "death": 7, "skill_vampiric_bite": 7, "skill_rift_zone": 7},
	}
	for boss_id in boss_full_frame_scenes.keys():
		var boss_info: Dictionary = boss_full_frame_scenes[boss_id]
		var boss_frames := FullFrameAnimationRegistry.sprite_frames_for("boss", boss_id)
		if boss_frames == null:
			_fail("Expected full-frame registry to resolve %s boss SpriteFrames." % boss_id)
			continue
		var boss_is_directional := bool(FullFrameAnimationRegistry.registry_config("boss", boss_id).get("explicit_eight_directions", false))
		if boss_is_directional:
			var boss_row_frames: Dictionary = directional_boss_row_frames.get(boss_id, {})
			if boss_row_frames.is_empty():
				_fail("Expected %s to declare its directional row lengths in directional_boss_row_frames." % boss_id)
			var boss_state_names: Array = ["idle", "move", "attack", "hit", "death"]
			for skill_state in boss_info["skill_states"]:
				boss_state_names.append(str(skill_state))
			for state_name in boss_state_names:
				var boss_state_should_loop: bool = state_name in ["idle", "move"]
				var boss_expected_frames := int(boss_row_frames.get(state_name, 0))
				for dir_suffix in FullFrameAnimationRegistry.DIRECTION_SUFFIXES:
					var boss_directional_row := "%s_%s" % [state_name, dir_suffix]
					if not boss_frames.has_animation(boss_directional_row):
						_fail("Expected %s boss SpriteFrames to expose %s." % [boss_id, boss_directional_row])
					else:
						if boss_frames.get_animation_loop(boss_directional_row) != boss_state_should_loop:
							_fail("Expected %s boss %s loop to be %s." % [boss_id, boss_directional_row, str(boss_state_should_loop)])
						if boss_frames.get_frame_count(boss_directional_row) != boss_expected_frames:
							_fail("Expected %s boss %s to have %d frames." % [boss_id, boss_directional_row, boss_expected_frames])
		else:
			for animation_name in ["move", "attack", "attack_primary"]:
				if not boss_frames.has_animation(animation_name):
					_fail("Expected %s boss SpriteFrames to expose %s animation." % [boss_id, animation_name])
				elif boss_frames.get_frame_count(animation_name) != 6:
					_fail("Expected %s boss %s to have 6 frames." % [boss_id, animation_name])
			if not boss_frames.get_animation_loop("move"):
				_fail("Expected %s boss move to loop." % boss_id)
			if not boss_frames.has_animation("death"):
				_fail("Expected %s boss SpriteFrames to expose death after SCRUM-370 death integration." % boss_id)
			elif boss_frames.get_frame_count("death") != 6:
				_fail("Expected %s boss death to have 6 frames." % boss_id)
			for one_shot_name in ["attack", "attack_primary", "death"]:
				if not boss_frames.has_animation(one_shot_name):
					continue
				if boss_frames.get_animation_loop(one_shot_name):
					_fail("Expected %s boss %s to be one-shot." % [boss_id, one_shot_name])
			for skill_state in boss_info["skill_states"]:
				var boss_skill_name := str(skill_state)
				var boss_attack_alias := "attack_%s" % boss_skill_name.trim_prefix("skill_")
				if not boss_frames.has_animation(boss_skill_name):
					_fail("Expected %s boss SpriteFrames to expose %s." % [boss_id, boss_skill_name])
				elif boss_frames.get_frame_count(boss_skill_name) != 6:
					_fail("Expected %s boss %s to have 6 frames." % [boss_id, boss_skill_name])
				if boss_frames.has_animation(boss_skill_name) and boss_frames.get_animation_loop(boss_skill_name):
					_fail("Expected %s boss %s to be one-shot." % [boss_id, boss_skill_name])
				if not boss_frames.has_animation(boss_attack_alias):
					_fail("Expected %s boss SpriteFrames to expose %s validator alias." % [boss_id, boss_attack_alias])
				elif boss_frames.get_frame_count(boss_attack_alias) != 6:
					_fail("Expected %s boss %s alias to have 6 frames." % [boss_id, boss_attack_alias])
				if boss_frames.has_animation(boss_attack_alias) and boss_frames.get_animation_loop(boss_attack_alias):
					_fail("Expected %s boss %s alias to be one-shot." % [boss_id, boss_attack_alias])

		var boss_scene := load(str(boss_info["path"])) as PackedScene
		var boss := boss_scene.instantiate()
		root.add_child(boss)
		if boss.get_node_or_null("FullFrameBody") == null:
			boss.call("_configure_full_frame_animation")
		boss.call("_update_movement_animation", 0.1)
		var boss_body := boss.get_node_or_null("FullFrameBody") as AnimatedSprite2D
		if boss_body == null or not boss_body.visible:
			_fail("Expected %s boss scene to create a visible FullFrameBody." % boss_id)
		if boss_body != null:
			if str(boss_body.get_meta("entity_id", "")) != boss_id:
				_fail("Expected %s boss scene to select boss-specific SpriteFrames, got %s." % [boss_id, str(boss_body.get_meta("entity_id", ""))])
			if not FullFrameAnimationRegistry.play_state(boss_body, str(boss_info["phase_state"]), Vector2.RIGHT):
				_fail("Expected %s boss phase state to resolve through the full-frame registry." % boss_id)
			# FAN-2635: directional bosses resolve to the `_east` row for
			# Vector2.RIGHT and never flip (the whole point of the contract).
			var boss_expected_phase_resolved: String = "%s_east" % str(boss_info["phase_resolved"]) if boss_is_directional else str(boss_info["phase_resolved"])
			if boss_body.animation != boss_expected_phase_resolved:
				_fail("Expected %s boss phase to resolve to %s, got %s." % [boss_id, boss_expected_phase_resolved, boss_body.animation])
			if boss_is_directional:
				if boss_body.flip_h:
					_fail("Expected %s boss directional full-frame art to never flip." % boss_id)
			elif not boss_body.flip_h:
				_fail("Expected %s boss full-frame art to face right via flip_h." % boss_id)
			boss.global_position = Vector2(420.0, 420.0)
			boss.callv(str(boss_info["hook_method"]), boss_info["hook_args"] as Array)
			var boss_expected_hook_state := str(boss_info["hook_expected"])
			if str(boss_body.get_meta("last_requested_state", "")) != boss_expected_hook_state:
				_fail("Expected %s boss skill hook to request %s, got %s." % [boss_id, boss_expected_hook_state, str(boss_body.get_meta("last_requested_state", ""))])
			var boss_expected_hook_resolved: String = "%s_east" % boss_expected_hook_state if boss_is_directional else boss_expected_hook_state
			if boss_body.animation != boss_expected_hook_resolved:
				_fail("Expected %s boss skill hook to play %s, got %s." % [boss_id, boss_expected_hook_resolved, boss_body.animation])
		var boss_static_body := boss.get_node_or_null("Sprite2D") as CanvasItem
		if boss_static_body != null and boss_static_body.visible:
			_fail("Expected %s boss full-frame visual to hide the static sprite fallback." % boss_id)
		boss.queue_free()
		for hazard in get_nodes_in_group("enemy_hazards"):
			var hazard_node := hazard as Node
			if hazard_node != null and is_instance_valid(hazard_node):
				hazard_node.queue_free()


func _test_enemy_animation() -> void:
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	var enemy := enemy_scene.instantiate()
	root.add_child(enemy)
	enemy.set("velocity", Vector2(100, 0))
	enemy.call("_update_movement_animation", 0.2)
	var body := enemy.get_node("Body") as Sprite2D
	if body.visible:
		_fail("Expected enemy source Body to be hidden behind RigRoot.")
	_assert_sliced_rig(enemy, "RigRoot", "enemies/cutout", ["Torso", "ArmL", "ArmR"], ["LegL", "LegR"], "rift cutter")

	var rig := enemy.get_node("RigRoot") as Node2D
	var pelvis := rig.get_node("Pelvis") as Node2D
	var leg_l := rig.get_node("Pelvis/Figure/LegL") as Node2D
	var leg_r := rig.get_node("Pelvis/Figure/LegR") as Node2D
	if abs(pelvis.position.y) <= 0.01 and abs(pelvis.rotation) <= 0.01:
		_fail("Expected enemy movement animation to affect rig pelvis transform.")
	if abs(leg_l.rotation - leg_r.rotation) <= 0.05:
		_fail("Expected enemy walk to animate opposing legs.")
	if abs(leg_l.position.y - leg_r.position.y) <= 0.02:
		_fail("Expected enemy walk to lift feet on alternating phases.")
	if pelvis.scale.x >= 0.0:
		_fail("Expected left-facing enemy art to mirror when moving right (negative pelvis scale.x).")
	enemy.set("velocity", Vector2(-100, 0))
	enemy.call("_update_movement_animation", 0.2)
	if pelvis.scale.x <= 0.0:
		_fail("Expected left-facing enemy art to stay unmirrored when moving left.")
	enemy.set("velocity", Vector2(100, 0))
	enemy.call("_update_movement_animation", 0.2)

	enemy.call("_play_rig_action", "attack", Vector2.RIGHT)
	enemy.call("_update_movement_animation", 0.15)
	var arm_r := rig.get_node("Pelvis/Figure/Torso/ArmR") as Node2D
	if abs(arm_r.rotation) <= 0.08:
		_fail("Expected enemy attack to swing the claw arm.")
	enemy.queue_free()

	var shooter_scene := load("res://scenes/EnemyShooter.tscn") as PackedScene
	var shooter := shooter_scene.instantiate()
	root.add_child(shooter)
	shooter.call("_update_movement_animation", 0.1)
	var weapon := shooter.get_node_or_null("RigRoot/Pelvis/Figure/Torso/Weapon") as Node2D
	if weapon == null:
		_fail("Expected marksman rig to carry the crossbow as a separate part.")
	shooter.call("_play_rig_action", "shoot", Vector2.RIGHT)
	shooter.call("_update_movement_animation", 0.13)
	var shooter_pelvis := shooter.get_node("RigRoot/Pelvis") as Node2D
	if shooter_pelvis.position.x >= -0.01:
		_fail("Expected shoot action to recoil the marksman.")
	shooter.queue_free()

	_test_enemy_archetype_pose("res://scenes/EnemyRunner.tscn", "attack", "spark runner", "RigRoot/Pelvis/Figure/Torso/Tail")
	_test_enemy_archetype_pose("res://scenes/EnemyBruiser.tscn", "attack", "stone bruiser", "RigRoot/Pelvis/Figure/Torso/ArmR")
	_test_enemy_archetype_pose("res://scenes/EnemySummoner.tscn", "cast", "bone caller", "RigRoot/Pelvis/Figure/Torso/ArmR")
	_test_enemy_archetype_pose("res://scenes/EnemyMage.tscn", "cast", "void mage", "RigRoot/Pelvis/Figure/Torso/ArmR")
	_test_enemy_archetype_pose("res://scenes/EnemySpitter.tscn", "shoot", "venom spitter", "")
	_test_enemy_archetype_pose("res://scenes/EnemyShield.tscn", "attack", "rift shieldbearer", "RigRoot/Pelvis/Figure/Torso/Shield")
	_test_enemy_archetype_pose("res://scenes/EnemyBiter.tscn", "attack", "small biter", "RigRoot/Pelvis/Figure/Torso/ArmR")
	_test_enemy_archetype_pose("res://scenes/EnemyBoneShaman.tscn", "cast", "bone shaman", "RigRoot/Pelvis/Figure/Torso/ArmR")
	_test_enemy_archetype_pose("res://scenes/EnemyFlyingRunner.tscn", "attack", "winged spark", "RigRoot/Pelvis/Figure/Torso/WingL")
	_test_enemy_archetype_pose("res://scenes/BossDiskDevourer.tscn", "attack", "disk devourer", "")


func _test_enemy_archetype_pose(scene_path: String, action_id: String, label: String, part_path: String) -> void:
	var scene := load(scene_path) as PackedScene
	var enemy := scene.instantiate()
	root.add_child(enemy)
	enemy.set("velocity", Vector2(100, 0))
	enemy.call("_update_movement_animation", 0.18)
	var rig := enemy.get_node("RigRoot") as Node2D
	var pelvis := rig.get_node("Pelvis") as Node2D
	if abs(pelvis.position.y) <= 0.01 and abs(pelvis.rotation) <= 0.01:
		_fail("Expected %s movement to animate the rig pelvis." % label)
	var before_pelvis: Vector2 = pelvis.position
	var part: Node2D = null
	if part_path != "":
		part = enemy.get_node_or_null(part_path) as Node2D
	var before_part_pos: Vector2 = Vector2.ZERO if part == null else part.position
	var before_part_rot: float = 0.0 if part == null else part.rotation
	enemy.call("_play_rig_action", action_id, Vector2.RIGHT)
	enemy.call("_update_movement_animation", 0.14)
	var pelvis_delta: float = pelvis.position.distance_to(before_pelvis) + abs(pelvis.rotation)
	var part_delta := 0.0
	if part != null:
		part_delta = part.position.distance_to(before_part_pos) + abs(part.rotation - before_part_rot)
	if pelvis_delta + part_delta <= 1.0:
		_fail("Expected %s %s pose to produce a readable action silhouette." % [label, action_id])
	enemy.queue_free()


func _test_flying_elite_boss_rigs() -> void:
	var flying_scene := load("res://scenes/EnemyFlyingRunner.tscn") as PackedScene
	var flying := flying_scene.instantiate()
	root.add_child(flying)
	flying.set("velocity", Vector2(100, 0))
	flying.call("_update_movement_animation", 0.2)
	var wing_l := flying.get_node_or_null("RigRoot/Pelvis/Figure/Torso/WingL") as Node2D
	var wing_r := flying.get_node_or_null("RigRoot/Pelvis/Figure/Torso/WingR") as Node2D
	if wing_l == null or wing_r == null:
		_fail("Expected flying enemy rig to use sliced wing parts.")
	if maxf(abs(wing_l.rotation), abs(wing_r.rotation)) <= 0.04:
		_fail("Expected flying enemy wings to flap.")
	flying.queue_free()

	var elite_scene := load("res://scenes/EliteArmored.tscn") as PackedScene
	var elite := elite_scene.instantiate()
	root.add_child(elite)
	elite.call("_update_movement_animation", 0.2)
	if elite.get_node_or_null("RigRoot/Pelvis/Figure/Torso/Shield") == null:
		_fail("Expected Iron Bastion rig to carry its shield as a separate part.")
	if elite.get_node_or_null("RigRoot/Pelvis/Figure/Torso/WeaponSocketMount") == null:
		_fail("Expected elite enemy to use the shared rig architecture.")
	elite.queue_free()

	var boss_scene := load("res://scenes/BossWarden.tscn") as PackedScene
	var boss := boss_scene.instantiate()
	root.add_child(boss)
	boss.call("_update_movement_animation", 0.2)
	if boss.get_node_or_null("RigRoot/Pelvis/Figure/Torso/Vortex") == null:
		_fail("Expected Rift Warden rig to animate its vortex as a separate part.")
	boss.call("_play_rig_action", "cast", Vector2.UP)
	boss.call("_update_movement_animation", 0.2)
	var boss_arm_l := boss.get_node("RigRoot/Pelvis/Figure/Torso/ArmL") as Node2D
	var boss_arm_r := boss.get_node("RigRoot/Pelvis/Figure/Torso/ArmR") as Node2D
	if abs(boss_arm_l.rotation - boss_arm_r.rotation) <= 0.2:
		_fail("Expected boss cast to raise both fists.")
	boss.queue_free()


func _test_elite_attack_phase_animation() -> void:
	var elite_scenes := {
		"iron_bastion": {"path": "res://scenes/EliteArmored.tscn", "attack": "slam_wave"},
		"night_stalker": {"path": "res://scenes/EliteStalker.tscn", "attack": "shadow_strike"},
		"plague_prophet": {"path": "res://scenes/ElitePoisoned.tscn", "attack": "poison_volley"},
		"shard_marshal": {"path": "res://scenes/EliteCommander.tscn", "attack": "shard_fan"},
	}

	for behavior_id in elite_scenes.keys():
		var info: Dictionary = elite_scenes[behavior_id]
		var elite := (load(str(info["path"])) as PackedScene).instantiate()
		root.add_child(elite)
		elite.call("_set_elite_attack_phase", "windup", 0.6)
		elite.call("_update_movement_animation", 0.3)
		var full_frame_body := elite.get_node_or_null("FullFrameBody") as AnimatedSprite2D
		if full_frame_body != null and full_frame_body.visible:
			var expected_full_frame_state := "skill_%s" % str(info["attack"])
			if full_frame_body.animation != expected_full_frame_state:
				_fail("Expected %s windup to resolve to full-frame %s, got %s." % [behavior_id, expected_full_frame_state, full_frame_body.animation])
			if abs(float(full_frame_body.get_meta("phase_duration", 0.0)) - 0.6) > 0.01:
				_fail("Expected %s windup to store full-frame phase duration." % behavior_id)
			elite.call("_set_elite_attack_phase", "strike", 0.25)
			elite.call("_update_movement_animation", 0.125)
			if full_frame_body.animation != expected_full_frame_state:
				_fail("Expected %s strike to keep full-frame %s, got %s." % [behavior_id, expected_full_frame_state, full_frame_body.animation])
			if abs(float(full_frame_body.get_meta("phase_duration", 0.0)) - 0.25) > 0.01:
				_fail("Expected %s strike to update full-frame phase duration." % behavior_id)
			elite.queue_free()
			continue
		var rig := elite.get_node("RigRoot") as Node2D
		var expected_variant := "%s:%s:windup" % [behavior_id, str(info["attack"])]
		if str(rig.get("action_variant")) != expected_variant:
			_fail("Expected %s windup to drive rig variant %s, got %s." % [behavior_id, expected_variant, str(rig.get("action_variant"))])
		var windup_pelvis := rig.get_node("Pelvis") as Node2D
		var windup_arm_r := rig.get_node_or_null("Pelvis/Figure/Torso/ArmR") as Node2D
		var windup_arm_l := rig.get_node_or_null("Pelvis/Figure/Torso/ArmL") as Node2D

		match behavior_id:
			"iron_bastion":
				if windup_pelvis.position.y >= -1.0 or windup_arm_r == null or windup_arm_r.position.y >= -2.0:
					_fail("Expected Iron Bastion windup to lift into a slam pose.")
			"night_stalker":
				if windup_pelvis.position.y <= 2.0 or windup_pelvis.scale.y >= 0.94:
					_fail("Expected Night Stalker windup to crouch before shadow strike.")
			"plague_prophet":
				if windup_arm_l == null or windup_arm_r == null or abs(windup_arm_l.rotation - windup_arm_r.rotation) <= 0.6:
					_fail("Expected Plague Prophet windup to read as a ritual arm raise.")
			"shard_marshal":
				if windup_arm_l == null or windup_arm_r == null or abs(windup_arm_l.position.x - windup_arm_r.position.x) <= 6.0:
					_fail("Expected Shard Marshal windup to spread both arms.")

		elite.call("_set_elite_attack_phase", "strike", 0.25)
		elite.call("_update_movement_animation", 0.125)
		var strike_variant := "%s:%s:strike" % [behavior_id, str(info["attack"])]
		if str(rig.get("action_variant")) != strike_variant:
			_fail("Expected %s strike to drive rig variant %s, got %s." % [behavior_id, strike_variant, str(rig.get("action_variant"))])
		var strike_pelvis := rig.get_node("Pelvis") as Node2D
		if behavior_id == "iron_bastion":
			if strike_pelvis.position.y <= 2.0:
				_fail("Expected Iron Bastion strike to drop into the slam.")
		elif behavior_id != "plague_prophet" and strike_pelvis.position.x <= 1.0:
			_fail("Expected %s strike to lunge/gesture forward." % behavior_id)
		elite.queue_free()


func _test_hit_death_states() -> void:
	_assert_hit_and_death_state("res://scenes/Player.tscn", "player", "player")
	_assert_hit_and_death_state("res://scenes/Enemy.tscn", "enemy", "enemy")
	_assert_hit_and_death_state("res://scenes/EliteArmored.tscn", "elite", "elite")
	_assert_hit_and_death_state("res://scenes/BossWarden.tscn", "boss", "boss")


func _assert_hit_and_death_state(scene_path: String, rig_kind: String, label: String) -> void:
	var scene := load(scene_path) as PackedScene
	var node := scene.instantiate()
	root.add_child(node)
	if rig_kind == "player":
		node.configure_character("berserk")
	node.call("_update_movement_animation", 0.1)
	var rig_path := "VisualRoot/RigRoot" if rig_kind == "player" else "RigRoot"
	var rig := node.get_node(rig_path) as Node2D
	var pelvis := rig.get_node("Pelvis") as Node2D
	rig.call("play_hit")
	rig.call("update_animation", 0.02, Vector2.ZERO, Vector2.RIGHT)
	if str(rig.get("state")) != "hit":
		_fail("Expected %s rig to enter hit state." % label)
	if abs(pelvis.position.x) <= 0.01:
		_fail("Expected %s hit state to shake the pelvis." % label)
	rig.call("play_death")
	rig.call("update_animation", 0.22, Vector2.ZERO, Vector2.RIGHT)
	if str(rig.get("state")) != "death":
		_fail("Expected %s rig to enter death state." % label)
	if rig.modulate.a >= 0.98:
		_fail("Expected %s death state to fade or collapse the rig." % label)
	node.queue_free()


func _test_death_ghost() -> void:
	var holder := Node2D.new()
	holder.name = "GhostTestScene"
	root.add_child(holder)
	current_scene = holder

	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	var enemy := enemy_scene.instantiate()
	holder.add_child(enemy)
	if enemy.get_node_or_null("FullFrameBody") == null:
		enemy.call("_configure_full_frame_animation")
	enemy.call("_update_movement_animation", 0.1)
	enemy.call("take_damage", 9999.0)
	var full_frame_body := enemy.get_node_or_null("FullFrameBody") as AnimatedSprite2D
	# FAN-2609: Enemy.tscn drives rift_cutter, an explicit 8-direction actor, so
	# death resolves through a directional `death_<suffix>` row, not the flat literal.
	var death_is_directional := bool(FullFrameAnimationRegistry.registry_config("enemy", "rift_cutter").get("explicit_eight_directions", false))
	var death_row_ok := full_frame_body != null and (full_frame_body.animation.begins_with("death_") if death_is_directional else full_frame_body.animation == "death")
	if not death_row_ok:
		_fail("Expected full-frame enemy death to play explicit death animation before cleanup.")
	if holder.get_node_or_null("DeathGhostRig") != null:
		_fail("Expected full-frame enemy death to avoid duplicate death ghost fallback.")
	if enemy.is_in_group("enemies"):
		_fail("Expected full-frame dying enemy to leave combat groups before delayed cleanup.")
	if enemy.is_queued_for_deletion():
		_fail("Expected full-frame enemy to delay queue_free until death animation playback ends.")
	enemy.queue_free()

	var fallback_enemy := enemy_scene.instantiate()
	fallback_enemy.set("enemy_type_name", "Missing Test Enemy")
	holder.add_child(fallback_enemy)
	fallback_enemy.call("_configure_enemy_rig")
	fallback_enemy.call("_update_movement_animation", 0.1)
	fallback_enemy.call("take_damage", 9999.0)
	var ghost := holder.get_node_or_null("DeathGhostRig") as Node2D
	if ghost == null:
		_fail("Expected dying fallback enemy to leave a death ghost rig behind.")
	if str(ghost.get("state")) != "death":
		_fail("Expected the death ghost to play the death animation.")
	holder.queue_free()
	current_scene = null
