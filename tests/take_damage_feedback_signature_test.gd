extends SceneTree

const ClassWeaponScript := preload("res://scripts/class_weapon.gd")
const BerserkWeaponScript := preload("res://scripts/berserk_weapon.gd")
const PlayerScene := preload("res://scenes/Player.tscn")
const EnemyScene := preload("res://scenes/Enemy.tscn")
const BossScene := preload("res://scenes/BossWarden.tscn")


func _initialize() -> void:
	var errors: Array = []
	var class_weapon := ClassWeaponScript.new()
	var berserk_weapon := BerserkWeaponScript.new()
	var player := PlayerScene.instantiate()
	var enemy := EnemyScene.instantiate()
	var boss := BossScene.instantiate()
	root.add_child(player)
	root.add_child(enemy)
	root.add_child(boss)
	await process_frame

	for weapon in [class_weapon, berserk_weapon]:
		if bool(weapon.call("_take_damage_accepts_feedback", player)):
			errors.append("%s must not treat Player.take_damage(amount, source) as enemy feedback API." % weapon.get_class())
		if not bool(weapon.call("_take_damage_accepts_feedback", enemy)):
			errors.append("%s must accept Enemy.take_damage(amount, feedback)." % weapon.get_class())
		if not bool(weapon.call("_take_damage_accepts_feedback", boss)):
			errors.append("%s must accept Boss.take_damage(amount, feedback)." % weapon.get_class())

	player.queue_free()
	enemy.queue_free()
	boss.queue_free()
	class_weapon.free()
	berserk_weapon.free()
	await process_frame

	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("take_damage_feedback_signature_test passed.")
	quit(0)
