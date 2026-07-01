extends SceneTree

const ProgressionData := preload("res://scripts/progression_data.gd")

const EXPECTED_SPRITES := {
	"berserk": "res://assets/sprites/characters/full_frame/berserk_pixellab/berserk_idle_south.png",
	"soldier": "res://assets/sprites/characters/full_frame/soldier_pixellab/soldier_idle_south.png",
	"thief": "res://assets/sprites/characters/full_frame/thief_pixellab/thief_idle_south.png",
	"elementalist": "res://assets/sprites/characters/full_frame/elementalist_pixellab/elementalist_idle_south.png",
	"sniper": "res://assets/sprites/characters/full_frame/sniper_pixellab/sniper_idle_south.png",
	"priest": "res://assets/sprites/characters/full_frame/priest_pixellab/priest_idle_south.png",
	"biologist": "res://assets/sprites/characters/full_frame/biologist/biologist_idle_00.png",
	"robot": "res://assets/sprites/characters/full_frame/robot_pixellab/robot_idle_south.png",
	"engineer": "res://assets/sprites/characters/full_frame/engineer_pixellab/engineer_idle_south.png",
	"dark_mage": "res://assets/sprites/characters/full_frame/dark_mage_pixellab/dark_mage_idle_south.png",
	"guitarist": "res://assets/sprites/characters/full_frame/guitarist_pixellab/guitarist_idle_south.png",
	"assassin": "res://assets/sprites/characters/full_frame/assassin_pixellab/assassin_idle_south.png",
	"ranger": "res://assets/sprites/characters/full_frame/ranger/ranger_idle_00.png",
	"doctor": "res://assets/sprites/characters/full_frame/doctor_pixellab/doctor_idle_south.png",
	"chemist": "res://assets/sprites/characters/full_frame/chemist_pixellab/chemist_idle_south.png",
	"knight": "res://assets/sprites/characters/full_frame/knight_pixellab/knight_idle_south.png",
	"druid": "res://assets/sprites/characters/full_frame/druid_pixellab/druid_idle_south.png",
}


func _initialize() -> void:
	var errors: Array[String] = []
	var dump_lines := PackedStringArray()
	dump_lines.append("# SCRUM-416 Character Portrait Registry Alignment")
	dump_lines.append("")
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
		if character_id == "assassin" or character_id == "berserk" or character_id == "chemist" or character_id == "dark_mage" or character_id == "doctor" or character_id == "druid" or character_id == "elementalist" or character_id == "engineer" or character_id == "guitarist" or character_id == "knight" or character_id == "priest" or character_id == "robot" or character_id == "sniper" or character_id == "soldier" or character_id == "thief":
			if not actual.contains("/full_frame/%s_pixellab/" % character_id) or not actual.ends_with("_idle_south.png"):
				errors.append("%s sprite_path must point to the PixelLab south idle portrait, got %s." % [character_id, actual])
		elif not actual.contains("/full_frame/%s/" % character_id) or not actual.ends_with("_idle_00.png"):
			errors.append("%s sprite_path must point to the cleaned full-frame idle portrait, got %s." % [character_id, actual])
		dump_lines.append("- `%s`: `%s`" % [character_id, actual])
	for character_id in EXPECTED_SPRITES.keys():
		if not ids.has(character_id):
			errors.append("Expected character '%s' is missing from ProgressionData.character_ids()." % character_id)
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum416")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var dump_file := FileAccess.open("%s/character_portrait_registry_alignment.md" % qa_dir, FileAccess.WRITE)
	if dump_file != null:
		dump_file.store_string("\n".join(dump_lines))
		dump_file.close()
	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("Character sprite registry alignment test passed (%d characters)." % EXPECTED_SPRITES.size())
	quit(0)
