extends SceneTree

const BERSERK_WEAPON := preload("res://scripts/berserk_weapon.gd")
const EPSILON := 0.01

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := Node2D.new()
	scene.name = "Scrum1043GeometryScene"
	root.add_child(scene)
	current_scene = scene

	var owner := Node2D.new()
	owner.name = "Owner"
	owner.global_position = Vector2(500.0, 300.0)
	scene.add_child(owner)

	var hammer := BERSERK_WEAPON.new()
	hammer.name = "Hammer"
	hammer.weapon_id = "hammer"
	hammer.attack_shape = "circle"
	hammer.aoe_radius = 150.0
	owner.add_child(hammer)

	var expected_center := owner.global_position + Vector2(0.0, 16.0)
	_assert_vec2(hammer.call("_circle_attack_center", owner), expected_center, "hammer center must move 16 px toward the footline")
	_assert_vec2(hammer.call("_circle_attack_visual_scale"), Vector2(1.0, 1.12), "hammer visual scale must mirror the vertically stretched hit query")

	# Cardinal owner-space probes. The former upper reach stays valid, the lower
	# side gains clearance before contact, and left/right remain close to 150 px.
	_assert_membership(hammer, owner, Vector2(0.0, -150.0), true, "top 150 px boundary regressed")
	_assert_membership(hammer, owner, Vector2(0.0, 180.0), true, "bottom 180 px must be inside the corrected slam")
	_assert_membership(hammer, owner, Vector2(0.0, 185.0), false, "bottom correction must remain a close-AoE, not an unbounded radius buff")
	_assert_membership(hammer, owner, Vector2(-149.0, 0.0), true, "left cardinal reach regressed")
	_assert_membership(hammer, owner, Vector2(149.0, 0.0), true, "right cardinal reach regressed")
	_assert_membership(hammer, owner, Vector2(-151.0, 0.0), false, "left horizontal radius expanded unexpectedly")
	_assert_membership(hammer, owner, Vector2(151.0, 0.0), false, "right horizontal radius expanded unexpectedly")

	# Existing VFX consumes the exact protected center/scale contract. Animator's
	# scene-specific bridge can call the same two hooks without copying constants.
	hammer.call("_show_circle_area", owner)
	var slam := scene.get_node_or_null("HammerSlamVfx") as Node2D
	if slam == null:
		_failures.append("HammerSlamVfx was not created")
	else:
		_assert_vec2(slam.global_position, expected_center, "visible hammer slam center diverges from damage center")
		_assert_vec2(slam.scale, Vector2(1.0, 1.12), "visible hammer slam shape diverges from damage scale")

	# Holy Flail is also a circle in BerserkWeapon but must retain its original
	# centered circular membership and visual contract.
	var flail := BERSERK_WEAPON.new()
	flail.name = "HolyFlail"
	flail.weapon_id = "holy_flail"
	flail.attack_shape = "circle"
	flail.aoe_radius = 150.0
	owner.add_child(flail)
	_assert_vec2(flail.call("_circle_attack_center", owner), owner.global_position, "Holy Flail center changed")
	_assert_vec2(flail.call("_circle_attack_visual_scale"), Vector2.ONE, "Holy Flail circle was stretched")
	_assert_membership(flail, owner, Vector2(0.0, -150.0), true, "Holy Flail top boundary changed")
	_assert_membership(flail, owner, Vector2(0.0, 150.0), true, "Holy Flail bottom boundary changed")
	_assert_membership(flail, owner, Vector2(0.0, 151.0), false, "Holy Flail radius expanded")

	if _failures.is_empty():
		print("SCRUM-1043 hammer lower hit-zone test passed: top=150, bottom=180 inside, horizontal=149, VFX aligned; Holy Flail unchanged.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _assert_membership(weapon: Node2D, owner: Node2D, owner_space_position: Vector2, expected: bool, message: String) -> void:
	var enemy := Node2D.new()
	enemy.global_position = owner.global_position + owner_space_position
	var actual := bool(weapon.call("_is_enemy_inside_attack", owner, enemy, Vector2.RIGHT))
	if actual != expected:
		_failures.append("%s (probe=%s expected=%s actual=%s)" % [message, owner_space_position, expected, actual])
	enemy.free()


func _assert_vec2(actual: Vector2, expected: Vector2, message: String) -> void:
	if actual.distance_to(expected) > EPSILON:
		_failures.append("%s (expected=%s actual=%s)" % [message, expected, actual])
