extends SceneTree

# SCRUM-277: сквозной contract-test для оружия всех классов.
# Ловит подмены вида "Священник/Колокол Молитвы показывает усилитель" на уровне
# данных, сцен, attack mode и фактической выдачи Player.configure_character().
#
# Запуск: Godot --headless --path . --script res://tests/weapon_integrity_test.gd

const PD := preload("res://scripts/progression_data.gd")
const ClassWeaponScript := preload("res://scripts/class_weapon.gd")

const EXPECTED_CLASSES := [
	"berserk", "soldier", "thief", "elementalist", "sniper", "priest",
	"biologist", "robot", "engineer", "dark_mage", "guitarist", "assassin",
	"ranger", "doctor", "chemist", "knight", "druid",
]

const TEXTURE_ID_ALIASES := {
	"sword": "two_handed_sword",
	"axe": "two_handed_axe",
	"hammer": "two_handed_hammer",
}

const ACTIVE_DAMAGE_PARAMETERS := ["damage", "magic_damage"]


func _initialize() -> void:
	var errors: Array = []
	var passive_ids := _passive_item_ids()
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	if player_scene == null:
		_fail(["Player scene did not load."])
		return

	var character_ids: Array = PD.character_ids()
	for expected_id in EXPECTED_CLASSES:
		if not (expected_id in character_ids):
			errors.append("missing character_id '%s'" % expected_id)

	var total_weapons := 0
	for character_id_raw in character_ids:
		var character_id := str(character_id_raw)
		var weapon_ids: Array = PD.weapon_ids(character_id)
		if weapon_ids.size() != 3:
			errors.append("%s: expected exactly 3 weapons, got %d" % [character_id, weapon_ids.size()])
			continue
		var seen := {}
		for weapon_id_raw in weapon_ids:
			var weapon_id := str(weapon_id_raw)
			total_weapons += 1
			if seen.has(weapon_id):
				errors.append("%s/%s: duplicate weapon id in class list" % [character_id, weapon_id])
			seen[weapon_id] = true

			var config: Dictionary = PD.weapon(character_id, weapon_id)
			_check_weapon_config(errors, passive_ids, character_id, weapon_id, config)
			if not errors.is_empty() and config.is_empty():
				continue

			var scene := load(str(config.get("scene_path", ""))) as PackedScene
			if scene == null:
				errors.append("%s/%s: scene did not load: %s" % [character_id, weapon_id, str(config.get("scene_path", ""))])
				continue
			var weapon_node := scene.instantiate()
			_check_weapon_scene(errors, character_id, weapon_id, config, weapon_node)
			weapon_node.free()

			var player := player_scene.instantiate()
			root.add_child(player)
			player.call("configure_character", character_id, weapon_id)
			await process_frame
			_check_player_equips_weapon(errors, character_id, weapon_id, player)
			player.queue_free()
			await process_frame

	if total_weapons != EXPECTED_CLASSES.size() * 3:
		errors.append("expected %d total weapons, got %d" % [EXPECTED_CLASSES.size() * 3, total_weapons])

	if not errors.is_empty():
		_fail(errors)
		return
	print("Weapon integrity test passed (%d classes, %d weapons)." % [character_ids.size(), total_weapons])
	quit(0)


func _check_weapon_config(errors: Array, passive_ids: Dictionary, character_id: String, weapon_id: String, config: Dictionary) -> void:
	if config.is_empty():
		errors.append("%s/%s: empty weapon config" % [character_id, weapon_id])
		return
	if str(config.get("id", "")) != weapon_id:
		errors.append("%s/%s: config id mismatch '%s'" % [character_id, weapon_id, str(config.get("id", ""))])
	if passive_ids.has(weapon_id):
		errors.append("%s/%s: weapon id collides with passive/shop/reward id" % [character_id, weapon_id])
	var scene_path := str(config.get("scene_path", ""))
	if scene_path == "" or not FileAccess.file_exists(scene_path):
		errors.append("%s/%s: missing scene_path '%s'" % [character_id, weapon_id, scene_path])
	if _expected_attack_mode(config) == "":
		errors.append("%s/%s: missing attack_mode/attack_shape marker" % [character_id, weapon_id])
	var config_damage_parameter := str(config.get("damage_parameter", "damage"))
	if not config_damage_parameter in ACTIVE_DAMAGE_PARAMETERS:
		errors.append("%s/%s: invalid active damage_parameter '%s'" % [character_id, weapon_id, config_damage_parameter])
	var expected_texture := _expected_texture_path(weapon_id)
	if not FileAccess.file_exists(expected_texture):
		errors.append("%s/%s: missing canonical weapon texture '%s'" % [character_id, weapon_id, expected_texture])


func _check_weapon_scene(errors: Array, character_id: String, weapon_id: String, config: Dictionary, weapon_node: Node) -> void:
	var scene_weapon_id := str(weapon_node.get("weapon_id"))
	if scene_weapon_id != weapon_id:
		errors.append("%s/%s: scene weapon_id is '%s'" % [character_id, weapon_id, scene_weapon_id])
	var script_ref = weapon_node.get_script()
	var script_path := str(script_ref.resource_path) if script_ref != null else ""
	var marker := _expected_attack_mode(config)
	if script_path.ends_with("class_weapon.gd") or script_path.ends_with("summoner_weapon.gd"):
		var config_damage_parameter := str(config.get("damage_parameter", "damage"))
		var scene_damage_parameter := str(weapon_node.get("damage_parameter"))
		if scene_damage_parameter != config_damage_parameter:
			errors.append("%s/%s: scene damage_parameter '%s' != config '%s'" % [
				character_id, weapon_id, scene_damage_parameter, config_damage_parameter])
		if not scene_damage_parameter in ACTIVE_DAMAGE_PARAMETERS:
			errors.append("%s/%s: scene retains invalid damage_parameter '%s'" % [
				character_id, weapon_id, scene_damage_parameter])
	if script_path.ends_with("class_weapon.gd"):
		var scene_mode := str(weapon_node.get("attack_mode"))
		if scene_mode != marker:
			errors.append("%s/%s: scene attack_mode '%s' != config '%s'" % [character_id, weapon_id, scene_mode, marker])
		if not ClassWeaponScript.has_attack_mode_executor(marker):
			errors.append("%s/%s: invalid ClassWeapon attack_mode '%s'" % [character_id, weapon_id, marker])
	elif script_path.ends_with("berserk_weapon.gd"):
		var scene_shape := str(weapon_node.get("attack_shape"))
		if scene_shape != marker:
			errors.append("%s/%s: scene attack_shape '%s' != config '%s'" % [character_id, weapon_id, scene_shape, marker])
	elif script_path.ends_with("summoner_weapon.gd"):
		if marker != "summon":
			errors.append("%s/%s: SummonerWeapon must use attack_mode marker 'summon', got '%s'" % [character_id, weapon_id, marker])
	else:
		errors.append("%s/%s: unexpected weapon script '%s'" % [character_id, weapon_id, script_path])

	var visual := weapon_node.find_child("WeaponVisual", true, false) as Sprite2D
	if visual == null or visual.texture == null:
		errors.append("%s/%s: missing WeaponVisual texture" % [character_id, weapon_id])
		return
	var texture_path := str(visual.texture.resource_path)
	var expected_texture := _expected_texture_path(weapon_id)
	if texture_path != expected_texture:
		errors.append("%s/%s: WeaponVisual texture '%s' != '%s'" % [character_id, weapon_id, texture_path, expected_texture])


func _check_player_equips_weapon(errors: Array, character_id: String, weapon_id: String, player: Node) -> void:
	var equipped = player.get("equipped_weapon")
	if equipped == null or not is_instance_valid(equipped):
		errors.append("%s/%s: Player did not equip a weapon" % [character_id, weapon_id])
		return
	var equipped_id := str(equipped.get("weapon_id"))
	if equipped_id != weapon_id:
		errors.append("%s/%s: Player equipped '%s'" % [character_id, weapon_id, equipped_id])
	var visual := (equipped as Node).find_child("WeaponVisual", true, false) as Sprite2D
	if visual == null or visual.texture == null:
		errors.append("%s/%s: equipped weapon has no visual texture" % [character_id, weapon_id])
		return
	var texture_path := str(visual.texture.resource_path)
	var expected_texture := _expected_texture_path(weapon_id)
	if texture_path != expected_texture:
		errors.append("%s/%s: equipped texture '%s' != '%s'" % [character_id, weapon_id, texture_path, expected_texture])


func _expected_attack_mode(config: Dictionary) -> String:
	if config.has("attack_mode"):
		return str(config.get("attack_mode", ""))
	if config.has("summon_damage_multiplier") or int(config.get("max_summons", 0)) > 0:
		return "summon"
	return str(config.get("attack_shape", ""))


func _expected_texture_path(weapon_id: String) -> String:
	var texture_id := str(TEXTURE_ID_ALIASES.get(weapon_id, weapon_id))
	return "res://assets/sprites/weapons/%s.png" % texture_id


func _passive_item_ids() -> Dictionary:
	var ids := {}
	for collection in [PD.ARTIFACTS, PD.SHOP_ITEMS, PD.LEVEL_UP_REWARDS, PD.STAT_REWARDS]:
		for item_raw in collection:
			var item: Dictionary = item_raw
			var item_id := str(item.get("id", ""))
			if item_id != "":
				ids[item_id] = true
	return ids


func _fail(errors: Array) -> void:
	for error in errors:
		push_error("Weapon integrity: %s" % str(error))
	push_error("Weapon integrity test failed with %d error(s)." % errors.size())
	quit(1)
