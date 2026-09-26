extends "res://tests/runtime_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): балансовый smoke класса berserk.
# Домен владения: class/berserk (docs/process/ownership_map.md).


func _initialize() -> void:
	_test_berserk_weapon_configs()
	_finish("[balance/berserk] PASSED")


func _test_berserk_weapon_configs() -> void:
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var expected := {
		"sword": {"shape": "sweep", "scene": "TwoHandedSword", "sprite": "res://assets/sprites/weapons/two_handed_sword.png"},
		"axe": {"shape": "sweep", "scene": "TwoHandedAxe", "sprite": "res://assets/sprites/weapons/two_handed_axe.png"},
		"hammer": {"shape": "circle", "scene": "TwoHandedHammer", "sprite": "res://assets/sprites/weapons/two_handed_hammer.png"},
	}

	var base_player := player_scene.instantiate()
	root.add_child(base_player)
	base_player.configure_character("berserk")
	if _find_player_weapon(base_player) != null:
		_fail("Expected base Berserk to spawn without a default weapon.")
		return
	base_player.queue_free()

	for weapon_id in expected.keys():
		var player := player_scene.instantiate()
		root.add_child(player)
		player.configure_character("berserk")
		player.equip_weapon(weapon_id)
		var weapon := _find_player_weapon(player)
		if weapon == null:
			_fail("Expected Berserk weapon for %s." % weapon_id)
			return
		if weapon.name != expected[weapon_id]["scene"] or weapon.get_parent().name != "WeaponSocket":
			_fail("Expected %s to attach its own weapon scene to WeaponSocket." % weapon_id)
			return
		if str(weapon.get("attack_shape")) != expected[weapon_id]["shape"]:
			_fail("Expected %s shape to match config." % weapon_id)
			return
		var weapon_visual := weapon.get_node_or_null("WeaponVisual") as Sprite2D
		if weapon_visual == null or weapon_visual.texture == null or weapon_visual.texture.resource_path != expected[weapon_id]["sprite"]:
			_fail("Expected %s to use its weapon sprite." % weapon_id)
			return
		player.queue_free()
