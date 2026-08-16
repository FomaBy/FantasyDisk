extends SceneTree

const PROBE_PATH := "user://fan1267_configfile_semantics.cfg"


func _initialize() -> void:
	var errors: Array[String] = []
	var file := FileAccess.open(PROBE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("FAN-1267: could not create ConfigFile semantics probe")
		quit(2)
		return
	file.store_string(
		'config/version="9.9.9"\n'
		+ "[options]\n"
		+ '#application/version="9.9.99"\n'
		+ ';application/file_version="9.9.99.9"\n'
	)
	file.close()

	var config := ConfigFile.new()
	if config.load(PROBE_PATH) != OK:
		errors.append("ConfigFile did not load the sectionless-assignment probe")
	else:
		_check(
			config.get_value("", "config/version", "") == "9.9.9",
			"sectionless assignment was not preserved in the empty section",
			errors
		)
		_check(
			config.get_value("options", "#application/version", "") == "9.9.99",
			"# prefix was not preserved as part of the assignment key",
			errors
		)
		_check(
			not config.has_section_key("options", "application/file_version"),
			"semicolon comment was parsed as an assignment",
			errors
		)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROBE_PATH))
	if not errors.is_empty():
		for error in errors:
			push_error("FAN-1267: %s" % error)
		quit(1)
		return
	print("FAN-1267 ConfigFile parser semantics test passed.")
	quit(0)


func _check(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)
