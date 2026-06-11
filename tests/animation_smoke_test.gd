extends SceneTree


func _initialize() -> void:
	_test_player_animation()
	_test_enemy_projectile_sprite()
	_test_enemy_sprite_paths()
	_test_enemy_animation()
	_test_flying_elite_boss_rigs()
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

	player.configure_character("guitarist")
	_assert_sliced_rig(player, "VisualRoot/RigRoot", "characters/cutout", ["Torso", "ArmL", "ArmR"], ["LegL", "LegR"], "guitarist")
	player.call("play_action_animation", "shoot", Vector2.RIGHT)
	player.call("_update_movement_animation", 0.10)
	var guitarist_pelvis := player.get_node("VisualRoot/RigRoot/Pelvis") as Node2D
	if guitarist_pelvis.position.x >= -0.01:
		_fail("Expected ranged action animation to recoil the rig pelvis.")

	player.configure_character("dark_mage")
	_assert_sliced_rig(player, "VisualRoot/RigRoot", "characters/cutout", ["Torso", "ArmL", "ArmR"], ["LegL", "LegR"], "dark mage")
	player.call("play_action_animation", "cast", Vector2.UP)
	player.call("_update_movement_animation", 0.15)
	var mage_arm_l := player.get_node("VisualRoot/RigRoot/Pelvis/Figure/Torso/ArmL") as Node2D
	var mage_arm_r := player.get_node("VisualRoot/RigRoot/Pelvis/Figure/Torso/ArmR") as Node2D
	if abs(mage_arm_l.rotation - mage_arm_r.rotation) <= 0.25:
		_fail("Expected cast action animation to raise the rig arms.")
	player.queue_free()


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
