extends SceneTree

# FAN-2519: 8-направленный рантайм-контракт не-игровых акторов (monsters,
# elites, bosses, summons) в рантайм-резолвере FullFrameAnimationRegistry.
# Проверяем: именование направлений (октанты как у игрока), полный резолв всех
# восьми ракурсов по контрактным состояниям (idle/move/attack/hit/death +
# entity-specific skill/cast/hover), политику фолбэка без зеркальных
# суррогатов, персистентность последнего ракурса, правила переходов состояний
# (без рестартов играющей строки — тайминги игры не трогаем) и
# pause/death/despawn-очистку. Резолвер остаётся визуальным мостом: коллизии,
# AI и геймплей-тайминги им не владеют и здесь не меняются.
#
# Запуск: Godot --headless --path . --script res://tests/full_frame_eight_direction_contract_test.gd

const FullFrameAnimationRegistry := preload("res://scripts/full_frame_animation_registry.gd")

# Единичные векторы строго по центру октантов; порядок суффиксов — контракта
# (по часовой стрелке от востока), идентичен player.gd.
const OCTANTS := {
	"east": Vector2(1.0, 0.0),
	"south_east": Vector2(1.0, 1.0),
	"south": Vector2(0.0, 1.0),
	"south_west": Vector2(-1.0, 1.0),
	"west": Vector2(-1.0, 0.0),
	"north_west": Vector2(-1.0, -1.0),
	"north": Vector2(0.0, -1.0),
	"north_east": Vector2(1.0, -1.0),
}
const LOOP_STATES := ["idle", "move", "levitate"]
const ONE_SHOT_STATES := ["attack", "hit", "death", "cast", "skill_blink"]
const CORE_STATES := ["idle", "move", "attack", "hit", "death", "cast"]


func _initialize() -> void:
	_test_direction_naming()
	_test_all_eight_directions_resolve_explicit_rows()
	_test_last_facing_persistence()
	_test_fallback_policy_never_flips_or_crosses_identity()
	_test_state_transition_rules()
	_test_registry_meta_configuration_path()
	_test_pause_death_despawn_cleanup()
	_test_live_registry_packs_audit()
	print("Eight-direction runtime contract test passed.")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _make_texture() -> Texture2D:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0, 1.0))
	return ImageTexture.create_from_image(image)


func _make_frames(rows: Array) -> SpriteFrames:
	# rows — имена строк; loop выставляем по контрактному состоянию строки
	# (движение зациклено, действия one-shot) на манер живых паков.
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var texture := _make_texture()
	for row in rows:
		var row_name := str(row)
		var loop := LOOP_STATES.has(row_name.split("_")[0])
		frames.add_animation(row_name)
		frames.set_animation_speed(row_name, 12.0)
		frames.set_animation_loop(row_name, loop)
		for frame_index in range(2):
			frames.add_frame(row_name, texture)
	return frames


func _make_body(frames: SpriteFrames) -> AnimatedSprite2D:
	var body := AnimatedSprite2D.new()
	body.sprite_frames = frames
	body.set_meta("entity_kind", "enemy")
	body.set_meta("entity_id", "fan2519_test_actor")
	body.set_meta("source_faces_left", true)
	body.set_meta("explicit_eight_directions", true)
	root.add_child(body)
	return body


func _full_pack_rows(cover_suffixes: Array) -> Array:
	var rows := []
	for state in LOOP_STATES + ONE_SHOT_STATES:
		for suffix in cover_suffixes:
			rows.append("%s_%s" % [state, suffix])
	return rows


func _test_direction_naming() -> void:
	for suffix in OCTANTS.keys():
		var resolved := FullFrameAnimationRegistry.direction_suffix_for((OCTANTS[suffix] as Vector2).normalized())
		if resolved != suffix:
			_fail("Expected octant %s to name itself, got %s." % [suffix, resolved])
			return
	if FullFrameAnimationRegistry.direction_suffix_for(Vector2.ZERO) != "south":
		_fail("Expected zero vector to default to south like the player contract.")
		return
	# Внутриоктантный вектор не должен пересекать границу сектора.
	if FullFrameAnimationRegistry.direction_suffix_for(Vector2(3.0, 1.0)) != "east":
		_fail("Expected in-sector vector (3,1) to resolve to east.")
		return
	if FullFrameAnimationRegistry.direction_suffix_for(Vector2(-2.0, -2.5)) != "north_west":
		_fail("Expected in-sector vector (-2,-2.5) to resolve to north_west.")
		return


func _test_all_eight_directions_resolve_explicit_rows() -> void:
	var frames := _make_frames(_full_pack_rows(OCTANTS.keys()))
	var body := _make_body(frames)
	for state in LOOP_STATES + ONE_SHOT_STATES:
		for suffix in OCTANTS.keys():
			var direction := (OCTANTS[suffix] as Vector2).normalized()
			if not FullFrameAnimationRegistry.play_state(body, state, direction):
				_fail("Expected %s %s to resolve an explicit directional row." % [state, suffix])
				return
			if str(body.animation) != "%s_%s" % [state, suffix]:
				_fail("Expected %s to resolve explicit row %s_%s, got %s." % [state, state, suffix, str(body.animation)])
				return
			if body.flip_h:
				_fail("Expected explicit eight-direction contract to never mirror (state %s %s)." % [state, suffix])
				return
			if not bool(body.get_meta("directional_row_resolved", false)):
				_fail("Expected %s %s to mark directional_row_resolved." % [state, suffix])
				return
			if bool(body.get_meta("directional_fallback_used", true)):
				_fail("Expected %s %s to play without directional fallback." % [state, suffix])
				return
			if str(body.get_meta("last_resolved_direction_suffix", "")) != suffix:
				_fail("Expected %s %s to record last_resolved_direction_suffix." % [state, suffix])
				return

	# Псевдонимы состояний обязаны резолвиться в направленные строки: walk ->
	# move_<suffix>, shoot -> attack_<suffix> (существующая лестница алиасов).
	for alias_pair in [["walk", "move"], ["shoot", "attack"], ["run", "move"], ["attack_primary", "attack"], ["die", "move"]]:
		var requested := str(alias_pair[0])
		var expected_state := str(alias_pair[1])
		var direction := Vector2(1.0, 1.0).normalized()
		if not FullFrameAnimationRegistry.play_state(body, requested, direction):
			_fail("Expected alias %s to resolve through directional rows." % requested)
			return
		if str(body.animation) != "%s_south_east" % expected_state:
			_fail("Expected alias %s to resolve %s_south_east, got %s." % [requested, expected_state, str(body.animation)])
			return

	# Entity-specific skill/cast состояния элит/боссов: составной вариант
	# `<behavior>:<attack_id>:<phase>` резолвится в направленную строку фазы.
	var compound_rows := []
	for suffix in OCTANTS.keys():
		compound_rows.append("strike_%s" % suffix)
	var compound_frames := _make_frames(compound_rows)
	var compound_body := _make_body(compound_frames)
	for suffix in ["east", "north_west", "south"]:
		var direction := (OCTANTS[suffix] as Vector2).normalized()
		if not FullFrameAnimationRegistry.play_state(compound_body, "night_stalker:shadow_strike:strike", direction):
			_fail("Expected compound elite state to resolve directional row for %s." % suffix)
			return
		if str(compound_body.animation) != "strike_%s" % suffix or compound_body.flip_h:
			_fail("Expected compound elite state to play strike_%s without flip, got %s." % [suffix, str(compound_body.animation)])
			return


func _test_last_facing_persistence() -> void:
	var frames := _make_frames(_full_pack_rows(OCTANTS.keys()))
	var body := _make_body(frames)
	# Двигались на северо-восток — все последующие нулевые направления (стойка,
	# хит, смерть) обязаны держать запомненный ракурс, а не дефолт.
	if not FullFrameAnimationRegistry.play_state(body, "move", Vector2(1.0, -1.0)):
		_fail("Expected move north_east to resolve.")
		return
	for state in ["idle", "hit", "death", "cast"]:
		if not FullFrameAnimationRegistry.play_state(body, state, Vector2.ZERO):
			_fail("Expected %s with zero direction to resolve persisted facing row." % state)
			return
		if str(body.animation) != "%s_north_east" % state:
			_fail("Expected %s to persist north_east facing, got %s." % [state, str(body.animation)])
			return
	# Смена ракурса перезаписывает память; имеет_state до первого play
	# резолвится от дефолтного западного ракурса контракта.
	var fresh_body := _make_body(_make_frames(_full_pack_rows(OCTANTS.keys())))
	if not FullFrameAnimationRegistry.has_state(fresh_body, "death"):
		_fail("Expected fresh 8-direction body to resolve death from default west facing.")
		return
	if not FullFrameAnimationRegistry.play_state(fresh_body, "move", Vector2.LEFT):
		_fail("Expected move west to resolve.")
		return
	if not FullFrameAnimationRegistry.play_state(fresh_body, "death", Vector2.ZERO) or str(fresh_body.animation) != "death_west":
		_fail("Expected death to follow the last persisted west facing.")
		return


func _test_fallback_policy_never_flips_or_crosses_identity() -> void:
	# Частичный пак: move без north/north_west строк, но с безнаправленным
	# move и idle. Деградация обязана: (1) играть безнаправленную строку того
	# же состояния, (2) НЕ зеркалить соседний ракурс (запад есть, но flip
	# запрещён), (3) ставить явный флаг — фолбэк не молчаливый.
	var partial_suffixes := ["east", "south_east", "south", "south_west", "west", "north_east"]
	var partial_rows := ["move", "idle"]
	for suffix in partial_suffixes:
		partial_rows.append("move_%s" % suffix)
	var partial_body := _make_body(_make_frames(partial_rows))
	if not FullFrameAnimationRegistry.play_state(partial_body, "move", Vector2(-1.0, -1.0)):
		_fail("Expected missing move_north_west to fall back to undirected move row.")
		return
	if str(partial_body.animation) != "move" or partial_body.flip_h:
		_fail("Expected missing directional row to degrade to undirected move without mirroring, got %s flip=%s." % [str(partial_body.animation), str(partial_body.flip_h)])
		return
	if not bool(partial_body.get_meta("directional_fallback_used", false)):
		_fail("Expected missing directional row to mark directional_fallback_used.")
		return
	# Полный ракурс рядом есть (west) — но подмены чужим ракурсом быть не должно.
	if str(partial_body.animation) == "move_west":
		_fail("Expected fallback to stay on the undirected row, not a different direction's identity.")
		return

	# Отсутствующее состояние целиком: документированная лестница алиасов
	# (death -> die -> idle -> move) играется безнаправленно и остаётся
	# наблюдаемой через меты requested/resolved — молчаливой подмены
	# идентичности нет.
	var no_death_rows := ["move", "idle"]
	for suffix in OCTANTS.keys():
		no_death_rows.append("attack_%s" % suffix)
	var no_death_body := _make_body(_make_frames(no_death_rows))
	if not FullFrameAnimationRegistry.play_state(no_death_body, "death", Vector2.RIGHT):
		_fail("Expected missing death state to resolve through the documented alias ladder.")
		return
	if str(no_death_body.animation) != "idle":
		_fail("Expected missing death state to land on the documented idle alias row, got %s." % str(no_death_body.animation))
		return
	if str(no_death_body.get_meta("last_requested_state", "")) != "death" or str(no_death_body.get_meta("last_resolved_state", "")) != "idle":
		_fail("Expected requested/resolved metadata to expose the alias degradation.")
		return
	if not bool(no_death_body.get_meta("directional_fallback_used", false)):
		_fail("Expected alias degradation on a directional contract to stay flagged.")
		return

	# Неразрешимое состояние возвращает false и не меняет текущую строку:
	# фреймы без move/idle строк не дают лестнице алиасов за что-то зацепиться.
	var attack_only_rows := ["attack_east", "attack_west"]
	var attack_only_body := _make_body(_make_frames(attack_only_rows))
	if not FullFrameAnimationRegistry.play_state(attack_only_body, "attack", Vector2.RIGHT):
		_fail("Expected attack_only pack to play its attack row first.")
		return
	if FullFrameAnimationRegistry.play_state(attack_only_body, "death", Vector2(0.0, 1.0)):
		_fail("Expected unresolvable state to return false on a directional contract.")
		return
	if str(attack_only_body.animation) != "attack_east":
		_fail("Expected unresolvable state to leave the current row untouched.")
		return


func _test_state_transition_rules() -> void:
	var frames := _make_frames(_full_pack_rows(OCTANTS.keys()))
	var body := _make_body(frames)
	if not FullFrameAnimationRegistry.play_state(body, "move", Vector2.RIGHT):
		_fail("Expected move east to resolve.")
		return
	body.set_frame_and_progress(1, 0.5)
	# Повторный запрос той же строки НЕ перезапускает её — прогресс кадра
	# сохранён, геймплей-тайминг анимации не сдвигается.
	if not FullFrameAnimationRegistry.play_state(body, "move", Vector2.RIGHT):
		_fail("Expected repeated move east to stay resolved.")
		return
	if body.frame != 1 or absf(body.frame_progress - 0.5) > 0.001:
		_fail("Expected repeated play_state to preserve frame progress (no restart).")
		return
	# Переход в другое состояние переключает строку на тот же ракурс.
	if not FullFrameAnimationRegistry.play_state(body, "attack", Vector2.RIGHT) or str(body.animation) != "attack_east":
		_fail("Expected state transition to switch attack_east row.")
		return
	if not body.is_playing():
		_fail("Expected transitioned row to be playing.")
		return
	# Смена ракурса в том же состоянии переключает направленную строку.
	if not FullFrameAnimationRegistry.play_state(body, "attack", Vector2.LEFT) or str(body.animation) != "attack_west":
		_fail("Expected direction change to switch attack_west row.")
		return
	# One-shot death после завершения не откатывается резолвером сам: обратные
	# переходы — зона ответственности владельца актора (enemy/ally код).
	if not FullFrameAnimationRegistry.play_state(body, "death", Vector2.ZERO) or str(body.animation) != "death_west":
		_fail("Expected death to resolve persisted west row.")
		return
	if not FullFrameAnimationRegistry.play_state(body, "idle", Vector2.ZERO) or str(body.animation) != "idle_west":
		_fail("Expected resolver to switch rows only on explicit caller requests.")
		return


func _test_registry_meta_configuration_path() -> void:
	# Сценарный (meta) путь конфигурации: сущность вне таблицы реестра
	# декларирует 8-направленный контракт метой владельца — конфигуратор
	# обязан поднять флаг на тело и сыграть дефолтный западный ряд.
	var frames := _make_frames(["move", "move_west", "move_east"])
	# .res (бинарный): встроенная ImageTexture-подресурс надёжно сериализуется.
	var save_error := ResourceSaver.save(frames, "user://fan2519_contract_frames.res")
	if save_error != OK:
		_fail("Expected synthetic contract SpriteFrames to save (err %d)." % save_error)
		return
	var owner := Node2D.new()
	root.add_child(owner)
	owner.set_meta("full_frame_spriteframes_path", "user://fan2519_contract_frames.res")
	owner.set_meta("full_frame_scale", Vector2.ONE)
	owner.set_meta("full_frame_position", Vector2.ZERO)
	owner.set_meta("full_frame_source_faces_left", true)
	owner.set_meta("full_frame_explicit_eight_directions", true)
	var static_body := Sprite2D.new()
	static_body.name = "Body"
	owner.add_child(static_body)
	var body := FullFrameAnimationRegistry.configure_entity_visual(owner, "enemy", "__fan2519_meta_actor__")
	if body == null:
		_fail("Expected meta-configured entity to attach an animated body.")
		return
	if not FullFrameAnimationRegistry.uses_explicit_eight_directions(body):
		_fail("Expected configure_entity_visual to honor full_frame_explicit_eight_directions owner meta.")
		return
	if static_body.visible or not body.visible:
		_fail("Expected configuration to hide the static body and show the animated one.")
		return
	if str(body.animation) != "move_west" or body.flip_h:
		_fail("Expected configured body to start on default west directional row without flip, got %s." % str(body.animation))
		return
	if str(body.get_meta("entity_id", "")) != "__fan2519_meta_actor__":
		_fail("Expected configured body to carry entity identity metadata.")
		return
	owner.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://fan2519_contract_frames.res"))


func _test_pause_death_despawn_cleanup() -> void:
	# Pause-контракт: реестр не создаёт собственные часы анимации — тело
	# наследует process mode актора (враги/призывы PAUSABLE), значит пауза
	# комбат-мира замораживает и 8-направленный визуал вместе с владельцем.
	var body := _make_body(_make_frames(_full_pack_rows(OCTANTS.keys())))
	if not FullFrameAnimationRegistry.play_state(body, "move", Vector2.DOWN):
		_fail("Expected cleanup-scenario move south to resolve.")
		return
	if body.process_mode != Node.PROCESS_MODE_INHERIT:
		_fail("Expected animated body to inherit pause behavior from its actor.")
		return
	if body.get_child_count() != 0:
		_fail("Expected resolver to spawn no auxiliary nodes (cleanup stays actor-owned).")
		return

	# Death/despawn: death-строка последнего ракурса играется перед удалением;
	# всё состояние резолвера живёт в мете тела и умирает вместе с актором —
	# глобальных таймеров/твинов/реестров живых тел нет.
	if not FullFrameAnimationRegistry.play_state(body, "death", Vector2.ZERO) or str(body.animation) != "death_south":
		_fail("Expected death to resolve persisted south row before despawn.")
		return
	body.queue_free()
	if not body.is_queued_for_deletion():
		_fail("Expected despawn to schedule the animated body for deletion with its actor.")
		return
	body.free()
	if is_instance_valid(body):
		_fail("Expected freed body to release all resolver state with itself.")
		return


func _test_live_registry_packs_audit() -> void:
	# Аудит живой таблицы реестра: флаг 8-направленного контракта — bool, и
	# каждый пак, его объявивший, обязан иметь ПОЛНЫЙ набор восьми строк у
	# каждого заявленного основного состояния (частичное покрытие — нарушение
	# контракта актора). Сегодня паков с флагом нет — гейт вакуумно-зелёный и
	# активируется автоматически, когда 0.3.1-паки начнут приземляться.
	var table: Dictionary = FullFrameAnimationRegistry.FULL_FRAME_SPRITEFRAMES
	var directional_packs := 0
	for entity_kind in table.keys():
		var kind_table: Dictionary = table[entity_kind]
		for entity_id in kind_table.keys():
			var config: Dictionary = kind_table[entity_id]
			if not config.has("explicit_eight_directions"):
				continue
			if not (config.get("explicit_eight_directions") is bool):
				_fail("Registry %s/%s: explicit_eight_directions must be bool." % [str(entity_kind), str(entity_id)])
				return
			if not bool(config["explicit_eight_directions"]):
				continue
			directional_packs += 1
			var frames := FullFrameAnimationRegistry.sprite_frames_for(str(entity_kind), str(entity_id))
			if frames == null:
				_fail("Registry %s/%s declares an eight-direction contract but resolves no SpriteFrames." % [str(entity_kind), str(entity_id)])
				return
			for state in CORE_STATES:
				var exposes_state := frames.has_animation(state)
				if not exposes_state:
					for suffix in FullFrameAnimationRegistry.DIRECTION_SUFFIXES:
						if frames.has_animation("%s_%s" % [state, suffix]):
							exposes_state = true
							break
				if exposes_state and not FullFrameAnimationRegistry.has_full_directional_rows(frames, state):
					_fail("Registry %s/%s: state %s must expose all 8 explicit directional rows." % [str(entity_kind), str(entity_id), state])
					return
	if directional_packs > 0:
		print("Eight-direction live packs audited: %d." % directional_packs)
