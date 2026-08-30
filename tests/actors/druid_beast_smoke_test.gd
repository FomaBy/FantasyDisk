extends "res://tests/animation_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): анимационный smoke актёра druid_beast (+SCRUM-336
# анимационная система всех призываемых существ волчьего типа).
# Домен владения: actor/druid_beast (docs/process/ownership_map.md).


func _initialize() -> void:
	_run_actor_suite("druid_beast")


func _run_actor_checks() -> void:
	_check_druid_beast_and_summons()


func _check_druid_beast_and_summons() -> void:
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
