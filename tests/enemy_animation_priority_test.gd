extends SceneTree

const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const PLAGUE_PROPHET_SCENE := preload("res://scenes/ElitePoisoned.tscn")


func _initialize() -> void:
	var errors: Array[String] = []
	await _test_elite_attack_blocks_locomotion(errors)
	await _test_hit_blocks_locomotion_then_recovers(errors)
	if not errors.is_empty():
		for error in errors:
			push_error("Enemy animation priority: %s" % error)
		quit(1)
		return
	print("Enemy animation priority test passed.")
	quit(0)


func _test_elite_attack_blocks_locomotion(errors: Array[String]) -> void:
	var elite := PLAGUE_PROPHET_SCENE.instantiate() as Node2D
	root.add_child(elite)
	await process_frame
	var body := elite.get_node_or_null("FullFrameBody") as AnimatedSprite2D
	if body == null or not body.visible:
		errors.append("fixture lacks visible full-frame Plague Prophet body")
		elite.queue_free()
		return
	elite.call("_set_elite_attack_phase", "windup", 0.6)
	elite.set("velocity", Vector2.RIGHT * 100.0)
	elite.call("_update_movement_animation", 0.01)
	if body.animation != &"skill_poison_volley":
		errors.append("windup was replaced by %s instead of skill_poison_volley" % body.animation)
	elite.call("_set_elite_attack_phase", "idle", 0.0)
	elite.call("_update_movement_animation", 0.01)
	if body.animation != &"move":
		errors.append("locomotion did not resume after elite attack: %s" % body.animation)
	elite.queue_free()
	await process_frame


func _test_hit_blocks_locomotion_then_recovers(errors: Array[String]) -> void:
	var enemy := ENEMY_SCENE.instantiate() as Node2D
	root.add_child(enemy)
	await process_frame
	var body := enemy.get_node_or_null("FullFrameBody") as AnimatedSprite2D
	if body == null or not body.visible:
		errors.append("fixture lacks visible full-frame enemy body")
		enemy.queue_free()
		return
	enemy.set("velocity", Vector2.RIGHT * 100.0)
	enemy.call("_update_movement_animation", 0.01)
	enemy.call("take_damage", 1.0)
	enemy.call("_update_movement_animation", 0.01)
	if not str(body.animation).begins_with("hit"):
		errors.append("hit reaction was replaced by %s in its protected window" % body.animation)
	enemy.call("_update_movement_animation", 0.2)
	if not str(body.animation).begins_with("move"):
		errors.append("locomotion did not resume after hit window: %s" % body.animation)
	enemy.queue_free()
	await process_frame
