extends SceneTree

const ProgressionData := preload("res://scripts/progression_data.gd")

const EXPECTED_SPRITES := {
	"berserk": "res://assets/sprites/characters/full_frame/berserk/berserk_idle_00.png",
	"soldier": "res://assets/sprites/characters/full_frame/soldier/soldier_idle_00.png",
	"thief": "res://assets/sprites/characters/full_frame/thief/thief_idle_00.png",
	"elementalist": "res://assets/sprites/characters/full_frame/elementalist/elementalist_idle_00.png",
	"sniper": "res://assets/sprites/characters/full_frame/sniper/sniper_idle_00.png",
	"priest": "res://assets/sprites/characters/full_frame/priest/priest_idle_00.png",
	"biologist": "res://assets/sprites/characters/full_frame/biologist/biologist_idle_00.png",
	"robot": "res://assets/sprites/characters/full_frame/robot/robot_idle_00.png",
	"engineer": "res://assets/sprites/characters/full_frame/engineer/engineer_idle_00.png",
	"dark_mage": "res://assets/sprites/characters/full_frame/dark_mage/dark_mage_idle_00.png",
	"guitarist": "res://assets/sprites/characters/full_frame/guitarist/guitarist_idle_00.png",
	"assassin": "res://assets/sprites/characters/full_frame/assassin/assassin_idle_00.png",
	"ranger": "res://assets/sprites/characters/full_frame/ranger/ranger_idle_00.png",
	"doctor": "res://assets/sprites/characters/full_frame/doctor/doctor_idle_00.png",
	"chemist": "res://assets/sprites/characters/full_frame/chemist/chemist_idle_00.png",
	"knight": "res://assets/sprites/characters/full_frame/knight/knight_idle_00.png",
	"druid": "res://assets/sprites/characters/full_frame/druid/druid_idle_00.png",
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
		if not actual.contains("/full_frame/%s/" % character_id) or not actual.ends_with("_idle_00.png"):
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
