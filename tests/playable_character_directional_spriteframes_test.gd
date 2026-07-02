extends SceneTree

const ProgressionData := preload("res://scripts/progression_data.gd")

const DIRECTIONS := [
	"south",
	"south_east",
	"east",
	"north_east",
	"north",
	"north_west",
	"west",
	"south_west",
]


func _initialize() -> void:
	var errors: Array[String] = []
	var report := PackedStringArray()
	report.append("# Playable Character Directional SpriteFrames Audit")
	report.append("")
	report.append("| Character | Idle dirs | Walk dirs | Move dirs | Fallback |")
	report.append("| --- | ---: | ---: | ---: | --- |")
	for character_id in ProgressionData.character_ids():
		var frames_path := "res://assets/sprites/characters/%s_spriteframes.tres" % character_id
		if not ResourceLoader.exists(frames_path):
			errors.append("%s missing SpriteFrames resource at %s." % [character_id, frames_path])
			continue
		var frames := load(frames_path) as SpriteFrames
		if frames == null:
			errors.append("%s SpriteFrames failed to load from %s." % [character_id, frames_path])
			continue
		var idle_count := 0
		var walk_count := 0
		var move_count := 0
		for direction in DIRECTIONS:
			var idle_name := "idle_%s" % direction
			var walk_name := "walk_%s" % direction
			var move_name := "move_%s" % direction
			if frames.has_animation(idle_name) and frames.get_frame_count(idle_name) >= 1:
				idle_count += 1
			else:
				errors.append("%s missing 1+ frame %s animation." % [character_id, idle_name])
			if frames.has_animation(walk_name) and frames.get_frame_count(walk_name) >= 5:
				walk_count += 1
			else:
				errors.append("%s missing 5+ frame %s animation." % [character_id, walk_name])
			if frames.has_animation(move_name) and frames.get_frame_count(move_name) >= 5:
				move_count += 1
			else:
				errors.append("%s missing 5+ frame %s animation." % [character_id, move_name])
		var fallback := "%d/%d/%d" % [
			frames.get_frame_count("idle") if frames.has_animation("idle") else 0,
			frames.get_frame_count("walk") if frames.has_animation("walk") else 0,
			frames.get_frame_count("move") if frames.has_animation("move") else 0,
		]
		if fallback != "1/6/6":
			errors.append("%s fallback idle/walk/move counts expected 1/6/6, got %s." % [character_id, fallback])
		if frames.has_animation("attack") or frames.has_animation("attack_primary"):
			errors.append("%s body SpriteFrames must keep weapon-owned attack rows out of playable body pack." % character_id)
		report.append("| `%s` | %d/8 | %d/8 | %d/8 | %s |" % [character_id, idle_count, walk_count, move_count, fallback])
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum421")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var report_file := FileAccess.open("%s/playable_character_directional_spriteframes_audit.md" % qa_dir, FileAccess.WRITE)
	if report_file != null:
		report_file.store_string("\n".join(report))
		report_file.close()
	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("Playable character directional SpriteFrames audit passed (%d characters)." % ProgressionData.character_ids().size())
	quit(0)
