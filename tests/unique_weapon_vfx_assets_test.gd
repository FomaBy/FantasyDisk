extends SceneTree

## SCRUM-258/FAN-1079 smoke: every current class weapon has a live textured,
## compact and self-cleaning weapon-release cue.

const AttackVfxScript := preload("res://scripts/attack_vfx.gd")
const ProgressionData := preload("res://scripts/progression_data.gd")


func _initialize() -> void:
	await process_frame
	var host := Node2D.new()
	root.add_child(host)
	var checked := 0
	for class_id in ProgressionData.WEAPONS_BY_CLASS.keys():
		var weapons: Dictionary = ProgressionData.WEAPONS_BY_CLASS[class_id]
		for weapon_id in weapons.keys():
			var texture_path := "res://assets/sprites/effects/vfx_weapon_%s.png" % weapon_id
			if not ResourceLoader.exists(texture_path):
				push_error("Missing SCRUM-258 weapon VFX plate: %s" % texture_path)
				quit(1)
				return
			var node := AttackVfxScript.weapon_signature(host, Vector2(checked * 3, 0), str(weapon_id), 120.0, Color(0.8, 0.7, 1.0, 0.45), 0.0)
			if node == null or not is_instance_valid(node):
				push_error("AttackVfx.weapon_signature did not spawn for %s." % weapon_id)
				quit(1)
				return
			if not bool(node.get_meta("release_motion", false)) \
					or bool(node.get_meta("damage_zone_overlay", true)) \
					or float(node.get_meta("release_diameter_px", 0.0)) > 100.0:
				push_error("Weapon signature for %s must be a compact moving release cue, never a damage-zone plate." % weapon_id)
				quit(1)
				return
			var has_sprite := false
			for child in node.get_children():
				if child is Sprite2D and (child as Sprite2D).texture != null:
					has_sprite = true
			if not has_sprite:
				push_error("Weapon signature for %s must use textured sprites." % weapon_id)
				quit(1)
				return
			checked += 1
	if checked != 51:
		push_error("Expected 51 weapon VFX plates, checked %d." % checked)
		quit(1)
		return
	host.queue_free()
	print("Unique weapon VFX assets smoke passed: %d compact release cues." % checked)
	quit()
