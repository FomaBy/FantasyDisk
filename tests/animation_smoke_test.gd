extends SceneTree


func _initialize() -> void:
	_test_player_animation()
	_test_enemy_projectile_sprite()
	_test_enemy_sprite_paths()
	_test_enemy_animation()
	_test_flying_elite_boss_rigs()
	_test_elite_attack_phase_animation()
	_test_death_ghost()
	print("Animation smoke test passed.")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _test_player_animation() -> void:
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)
	player.configure_character("berserk")
	var body := player.get_node("VisualRoot/Body") as AnimatedSprite2D
	if body.visible:
		_fail("Expected player fallback AnimatedSprite2D to be hidden behind RigRoot.")
	_assert_sliced_rig(player, "VisualRoot/RigRoot", "characters/cutout", ["Torso", "ArmL", "ArmR"], ["LegL", "LegR"], "player")

	var rig := player.get_node("VisualRoot/RigRoot") as Node2D
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

	player.configure_character("guitarist")
	_assert_sliced_rig(player, "VisualRoot/RigRoot", "characters/cutout", ["Torso", "ArmL", "ArmR"], ["LegL", "LegR"], "guitarist")
	player.call("play_action_animation", "shoot", Vector2.RIGHT)
	player.call("_update_movement_animation", 0.10)
	var guitarist_pelvis := player.get_node("VisualRoot/RigRoot/Pelvis") as Node2D
	if guitarist_pelvis.position.x >= -0.01:
		_fail("Expected ranged action animation to recoil the rig pelvis.")

	player.configure_character("dark_mage")
	_assert_sliced_rig(player, "VisualRoot/RigRoot", "characters/cutout", ["Torso", "ArmL", "ArmR"], ["LegL", "LegR"], "dark mage")
	player.set("velocity", Vector2(100, 0))
	player.call("_update_movement_animation", 0.18)
	var mage_pelvis := player.get_node("VisualRoot/RigRoot/Pelvis") as Node2D
	var mage_leg_l := player.get_node("VisualRoot/RigRoot/Pelvis/Figure/LegL") as Node2D
	var mage_leg_r := player.get_node("VisualRoot/RigRoot/Pelvis/Figure/LegR") as Node2D
	if abs(mage_leg_l.rotation - mage_leg_r.rotation) <= 0.04:
		_fail("Expected Dark Mage walk to use readable alternating leg motion.")
	if abs(mage_leg_l.position.y - mage_leg_r.position.y) <= 0.02:
		_fail("Expected Dark Mage walk to show foot contact through subtle lift.")
	if abs(mage_pelvis.rotation) >= 0.08:
		_fail("Expected Dark Mage walk to keep a controlled robe/body lean.")
	player.set("velocity", Vector2.ZERO)
	player.call("play_action_animation", "cast", Vector2.UP)
	player.call("_update_movement_animation", 0.15)
	var mage_arm_l := player.get_node("VisualRoot/RigRoot/Pelvis/Figure/Torso/ArmL") as Node2D
	var mage_arm_r := player.get_node("VisualRoot/RigRoot/Pelvis/Figure/Torso/ArmR") as Node2D
	if abs(mage_arm_l.rotation - mage_arm_r.rotation) <= 0.25:
		_fail("Expected cast action animation to raise the rig arms.")

	var new_class_profiles := {
		"assassin": 0.08,
		"ranger": 0.06,
		"doctor": 0.035,
		"chemist": 0.045,
		"knight": 0.035,
		"druid": 0.035,
		"soldier": 0.04,
		"thief": 0.05,
		"elementalist": 0.03,
		"sniper": 0.03,
		"priest": 0.025,
		"biologist": 0.025,
		"robot": 0.02,
	}
	for character_id in new_class_profiles.keys():
		player.configure_character(character_id)
		_assert_sliced_rig(player, "VisualRoot/RigRoot", "characters/cutout", ["Torso", "ArmL", "ArmR"], ["LegL", "LegR"], character_id)
		player.set("velocity", Vector2(120, 0))
		player.call("_update_movement_animation", 0.20)
		var class_rig := player.get_node("VisualRoot/RigRoot") as Node2D
		var class_pelvis := class_rig.get_node("Pelvis") as Node2D
		var class_leg_l := class_rig.get_node("Pelvis/Figure/LegL") as Node2D
		var class_leg_r := class_rig.get_node("Pelvis/Figure/LegR") as Node2D
		if abs(class_pelvis.position.y) <= 0.01:
			_fail("Expected %s movement profile to move the pelvis." % character_id)
		if abs(class_leg_l.rotation - class_leg_r.rotation) <= float(new_class_profiles[character_id]):
			_fail("Expected %s to use a distinct readable walk profile." % character_id)

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
		if float(sniper_pose["socket_x"]) <= 8.0 or abs(float(sniper_pose["socket_y"])) >= 36.0:
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
		if float(priest_pose["socket_x"]) <= 8.0 or abs(float(priest_pose["socket_y"])) >= 38.0:
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
		if float(biologist_pose["socket_x"]) <= 8.0 or abs(float(biologist_pose["socket_y"])) >= 40.0:
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
		if float(robot_pose["socket_x"]) <= 8.0 or abs(float(robot_pose["socket_y"])) >= 42.0:
			_fail("Expected robot weapon socket to stay readable near the construct hand.")
	player.queue_free()


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

	var boss_scene := load("res://scenes/BossWarden.tscn") as PackedScene
	var boss := boss_scene.instantiate()
	root.add_child(boss)
	var boss_body := boss.get_node("Sprite2D") as Sprite2D
	if boss_body.texture == null or boss_body.texture.resource_path != "res://assets/sprites/bosses/boss_rift_warden.png":
		_fail("Expected BossWarden to use res://assets/sprites/bosses/boss_rift_warden.png.")
	boss.queue_free()

	var disk_boss_scene := load("res://scenes/BossDiskDevourer.tscn") as PackedScene
	var disk_boss := disk_boss_scene.instantiate()
	root.add_child(disk_boss)
	var disk_boss_body := disk_boss.get_node("Sprite2D") as Sprite2D
	if disk_boss_body.texture == null or disk_boss_body.texture.resource_path != "res://assets/sprites/bosses/boss_disk_devourer.png":
		_fail("Expected BossDiskDevourer to use res://assets/sprites/bosses/boss_disk_devourer.png.")
	disk_boss.queue_free()


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


func _test_death_ghost() -> void:
	var holder := Node2D.new()
	holder.name = "GhostTestScene"
	root.add_child(holder)
	current_scene = holder

	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	var enemy := enemy_scene.instantiate()
	holder.add_child(enemy)
	enemy.call("_update_movement_animation", 0.1)
	enemy.call("take_damage", 9999.0)
	var ghost := holder.get_node_or_null("DeathGhostRig") as Node2D
	if ghost == null:
		_fail("Expected dying enemy to leave a death ghost rig behind.")
	if str(ghost.get("state")) != "death":
		_fail("Expected the death ghost to play the death animation.")
	holder.queue_free()
	current_scene = null
