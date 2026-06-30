extends SceneTree

# SCRUM-721: целостность реестра full-frame SpriteFrames (был покрыт лишь точечно —
# animation_smoke гоняет ХАРДКОД-списки сущностей, а не сам реестр). Здесь итерируем
# КАЖДУЮ запись FullFrameAnimationRegistry.FULL_FRAME_SPRITEFRAMES и гарантируем, что
# зарегистрированный ресурс реально существует, грузится как SpriteFrames и несёт ≥1
# анимацию. Иначе протухший/опечатанный путь молча отдаёт null → сущность теряет
# визуал БЕЗ ошибки (silent fallback). Также проверяем типы полей конфигурации.
# Реестр опционален (нет записи = ок, рантайм падает в статик-фолбэк), но ЕСЛИ запись
# есть — она обязана быть валидной. Арт/тайминги/клипы НЕ трогаем (вне scope SCRUM-721).
#
# Запуск: Godot --headless --path . --script res://tests/full_frame_registry_integrity_test.gd

const FullFrameAnimationRegistry := preload("res://scripts/full_frame_animation_registry.gd")


func _initialize() -> void:
	var errors: Array = []
	var table: Dictionary = FullFrameAnimationRegistry.FULL_FRAME_SPRITEFRAMES
	var total := 0

	for entity_kind in table.keys():
		var kind_table: Dictionary = table[entity_kind]
		for entity_id in kind_table.keys():
			total += 1
			var config: Dictionary = kind_table[entity_id]
			var where := "%s/%s" % [str(entity_kind), str(entity_id)]

			var frames_path := str(config.get("frames", ""))
			if frames_path == "":
				errors.append("%s: пустой 'frames' путь." % where)
				continue
			if not ResourceLoader.exists(frames_path):
				errors.append("%s: ресурс не существует — %s (протухший/опечатанный путь, silent fallback)." % [where, frames_path])
				continue

			# Грузим через тот же путь, что и рантайм (sprite_frames_for), чтобы поймать
			# битый/пустой .tres, который ResourceLoader.exists пропустит.
			var frames := FullFrameAnimationRegistry.sprite_frames_for(str(entity_kind), str(entity_id))
			if frames == null:
				errors.append("%s: sprite_frames_for вернул null при существующем пути %s." % [where, frames_path])
				continue
			if not (frames is SpriteFrames):
				errors.append("%s: ресурс %s не SpriteFrames." % [where, frames_path])
				continue
			if frames.get_animation_names().is_empty():
				errors.append("%s: SpriteFrames без анимаций — play_state не сможет ничего разрешить." % where)

			# Типы полей конфигурации (configure_entity_visual читает их без коэрции).
			if not (config.get("scale") is Vector2):
				errors.append("%s: 'scale' не Vector2." % where)
			if not (config.get("position") is Vector2):
				errors.append("%s: 'position' не Vector2." % where)
			if not (config.get("source_faces_left") is bool):
				errors.append("%s: 'source_faces_left' не bool." % where)

	if total < 20:
		errors.append("Реестр подозрительно мал (%d записей) — гейт прошёл бы вакуумно." % total)

	# Контракт безопасного фолбэка: незарегистрированная сущность → null, без краша.
	if FullFrameAnimationRegistry.sprite_frames_for("enemy", "__does_not_exist__") != null:
		errors.append("Незарегистрированный id обязан давать null (safe fallback), а не ресурс.")

	if not errors.is_empty():
		for e in errors:
			push_error("Full-frame registry integrity: %s" % e)
		push_error("Full-frame registry integrity test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Full-frame registry integrity test passed (%d записей реестра, все ресурсы грузятся с ≥1 анимацией)." % total)
	quit(0)
