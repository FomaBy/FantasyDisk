extends RefCounted

# The caller validates existing files for its schema before rotating them.
# Use same-directory renames without requiring POSIX replacement semantics.
# This is process-interruption recovery, not a disk-fsync promise.
static func save(config: ConfigFile, save_path: String, keep_backup := false) -> bool:
	var target := ProjectSettings.globalize_path(save_path)
	var temporary := target + ".tmp"
	var backup := target + ".bak"
	if config.save(temporary) != OK:
		return false
	var verified := ConfigFile.new()
	if verified.load(temporary) != OK or verified.get_sections() != config.get_sections():
		return false
	for section in config.get_sections():
		if verified.get_section_keys(section) != config.get_section_keys(section):
			return false
		for key in config.get_section_keys(section):
			if verified.get_value(section, key) != config.get_value(section, key):
				return false
	# Complete an interrupted old-to-backup move before rotating again.
	if not FileAccess.file_exists(target) and FileAccess.file_exists(backup):
		if DirAccess.rename_absolute(backup, target) != OK:
			return false
	elif FileAccess.file_exists(target) and FileAccess.file_exists(backup):
		if DirAccess.remove_absolute(backup) != OK:
			return false
	var had_previous := FileAccess.file_exists(target)
	if had_previous and DirAccess.rename_absolute(target, backup) != OK:
		return false
	if DirAccess.rename_absolute(temporary, target) != OK:
		# If rollback itself fails, the committed file is still at .bak.
		if had_previous:
			DirAccess.rename_absolute(backup, target)
		return false
	if had_previous and not keep_backup:
		DirAccess.remove_absolute(backup)
	return true
