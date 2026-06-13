extends SceneTree

const ProgressionData := preload("res://scripts/progression_data.gd")

const EXPECTED_SPRITES := {
	"berserk": "res://assets/sprites/characters/berserk_unarmed.png",
	"soldier": "res://assets/sprites/characters/soldier.png",
	"thief": "res://assets/sprites/characters/thief.png",
	"elementalist": "res://assets/sprites/characters/elementalist.png",
	"sniper": "res://assets/sprites/characters/sniper.png",
	"priest": "res://assets/sprites/characters/priest.png",
	"biologist": "res://assets/sprites/characters/biologist.png",
	"robot": "res://assets/sprites/characters/robot.png",
	"engineer": "res://assets/sprites/characters/engineer.png",
	"dark_mage": "res://assets/sprites/characters/dark_mage.png",
	"guitarist": "res://assets/sprites/characters/guitarist.png",
	"assassin": "res://assets/sprites/characters/assassin.png",
	"ranger": "res://assets/sprites/characters/ranger.png",
	"doctor": "res://assets/sprites/characters/doctor.png",
	"chemist": "res://assets/sprites/characters/chemist.png",
	"knight": "res://assets/sprites/characters/knight.png",
	"druid": "res://assets/sprites/characters/druid.png",
}


func _initialize() -> void:
	var errors: Array[String] = []
	var ids := ProgressionData.character_ids()
	for character_id in ids:
		if not EXPECTED_SPRITES.has(character_id):
			errors.append("No canonical sprite expectation for character '%s'." % character_id)
			continue
		var config := ProgressionData.character_config(character_id)
		var actual := str(config.get("sprite_path", ""))
		var expected := str(EXPECTED_SPRITES[character_id])
		if actual != expected:
			errors.append("%s sprite_path mismatch: got %s, expected %s." % [character_id, actual, expected])
		if actual.is_empty() or not ResourceLoader.exists(actual):
			errors.append("%s sprite_path does not exist: %s." % [character_id, actual])
	for character_id in EXPECTED_SPRITES.keys():
		if not ids.has(character_id):
			errors.append("Expected character '%s' is missing from ProgressionData.character_ids()." % character_id)
	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("Character sprite registry alignment test passed (%d characters)." % EXPECTED_SPRITES.size())
	quit(0)
