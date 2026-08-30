extends "res://scripts/ui/screens/shop.gd"

# FAN-3824: модуль распределённого UI-класса — экраны узлов забега: событие, отдых, апгрейд и исходы событий.
# Часть линейной extends-цепочки scripts/ui/screens/** (сборка — фасад
# scripts/ui_screens.gd). Код перенесён из ui_screens.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в ui_screens_shared_api.gd.





func _show_rest_screen() -> void:
	var box := _create_menu_box("Костер", "Восстановись или подготовься перед следующим боем.", "campfire")
	box.name = "RestContent"
	var scroll := box.get_parent() as ScrollContainer
	if scroll != null:
		scroll.follow_focus = false
		scroll.scroll_vertical = 0
	var rest_title := box.find_child("MenuTitle_campfire", false, false) as Label
	if rest_title != null:
		rest_title.name = "RestTitle"
	var rest_subtitle := box.find_child("MenuSubtitle_campfire", false, false) as Label
	if rest_subtitle != null:
		rest_subtitle.name = "RestSubtitle"
	_create_menu_run_hud()
	# Escape = уйти от костра без бонуса (последовательно с пропуском магазина).
	game.ui_escape_action = game.route._advance_route_after_noncombat
	var rest_card_size := _gold_shell_economy_choice_display_size(2)
	var choices := _make_economy_choice_row("RestChoiceRow", rest_card_size, 2)
	box.add_child(choices)
	var heal_button := _make_economy_choice_card("Передышка", "Восстановить 35% максимального здоровья.", "Отдохнуть", "RestHealButton", rest_card_size)
	choices.add_child(heal_button)
	heal_button.pressed.connect(func() -> void:
		_apply_event_choice({"title": "Rest", "description": "Recover", "heal_percent": 0.35})
		game.route._advance_route_after_noncombat()
	)
	# SCRUM-968: отдых/подготовка — бесплатные подтверждения (не траты) → ui_click.
	_connect_ui_sfx(heal_button, "click")

	var guard_button := _make_economy_choice_card("Защитная стойка", "Получить +6% защиты до конца забега.", "Подготовиться", "RestGuardButton", rest_card_size)
	choices.add_child(guard_button)
	guard_button.pressed.connect(func() -> void:
		_apply_reward_to_run({"title": "Защитная стойка", "description": "+6% к защите.", "mods": {"defense_flat": 0.06}})
		game.route._advance_route_after_noncombat()
	)
	_connect_ui_sfx(guard_button, "click")
	var back_button := _make_button("Назад")
	back_button.name = "RestBackButton"
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_set_action_button_size(back_button, 380.0, 54.0)
	back_button.tooltip_text = "Вернуться на карту без отдыха."
	back_button.pressed.connect(game.route._advance_route_after_noncombat)
	# SCRUM-968: «Назад» от костра — выход/закрытие экрана → ui_back.
	_connect_ui_sfx(back_button, "back")
	box.add_child(back_button)

	# SCRUM-812: два выбора листаются лево/право, «Назад» доступна ui_down, старт — «Передышка».
	_wire_run_ui_focus([heal_button, guard_button], true, [back_button], heal_button)




func _show_upgrade_screen() -> void:
	# SCRUM-883: панель улучшения — чип Атласа (экономический фолбэк) вместо
	# upgrade_panel @2K-рамки; карточки — чип-ряды общей фабрики.
	var box := _create_menu_box("Улучшение", "Выбери усиление оружия или параметра.", "upgrade")
	_create_menu_run_hud()
	var upgrade_card_size := _gold_shell_economy_choice_display_size(3)
	var choices := _make_economy_choice_row("UpgradeChoiceRow", upgrade_card_size, 3)
	box.add_child(choices)
	var index := 0
	var upgrade_cards: Array = []
	for reward in _random_level_up_rewards(3):
		var button := _make_economy_choice_card(str(reward["title"]), str(reward["description"]), "Выбрать", "UpgradeChoiceButton%d" % index, upgrade_card_size)
		choices.add_child(button)
		button.pressed.connect(func() -> void:
			_apply_reward_to_run(reward)
			game.route._advance_route_after_noncombat()
		)
		upgrade_cards.append(button)
		index += 1

	# SCRUM-812: карточки улучшений листаются лево/право по кругу, старт — первая; A выбирает.
	_wire_run_ui_focus(upgrade_cards, true, [], upgrade_cards[0] if not upgrade_cards.is_empty() else null)




func _show_event_screen(route_node: Dictionary) -> void:
	var event_definition: Dictionary = {}
	if route_node.has("event_id"):
		event_definition = game.EVENT_DATA.event_by_id(str(route_node.get("event_id", "")))
	elif not game.current_event_definition.is_empty():
		# SCRUM-530: повторный вход в это же случайное (без event_id) событие — с карты,
		# после отложенного level-up или из автосейв-восстановления — НЕ рероллит набор
		# опций. current_event_definition очищается при выходе с события (выбор опции / «Назад»
		# / старт боя), поэтому непустое значение здесь = тот же незавершённый узел-событие.
		event_definition = game.current_event_definition.duplicate(true)
	if event_definition.is_empty():
		# SCRUM-996: контекст отбора — act-теги нового пака (SCRUM-995) фильтруются
		# по текущему акту; события без тегов (весь текущий пул) допустимы всюду.
		event_definition = game.EVENT_DATA.pick_event(game.used_event_ids, game.rng, {"act": int(game.current_act)})
	var event_id := str(event_definition.get("id", ""))
	if event_id != "" and not game.used_event_ids.has(event_id):
		game.used_event_ids.append(event_id)
	game.current_event_definition = event_definition.duplicate(true)

	# SCRUM-997: иллюстрированная встреча (спека docs/design/mockups/
	# scrum997_event_dialog/spec.md): фон-арт события на весь экран, диалог-панель
	# справа на полупрозрачном чипе Атласа, три карточки выбора внизу.
	var metrics := _event_dialog_metrics()
	var box := _create_menu_box(str(event_definition.get("title", route_node.get("name", "Событие"))), str(event_definition.get("story", "Странная возможность на дороге: риск, награда или оба сразу.")), "event", _atlas_chip_style(0.90, float(metrics["panel_pad"])))
	_configure_event_menu_layout(box)
	_apply_event_screen_background(box, event_id)
	var event_root := _event_screen_root(box)
	if event_root != null:
		event_root.name = "EventScreen"
	_create_menu_run_hud()
	# На событии докачка недоступна: повторный вход перегенерировал бы выборы события.
	# Не добавляем disabled-FAB внутрь MenuPanel_event: PanelContainer раскладывает всех
	# детей как контент панели, и лишняя кнопка ломает видимость title/story/choices.
	var event_choices: Array = event_definition.get("choices", _random_event_choices())
	# Защита от тупика: пустой/битый набор выборов не должен оставлять серый экран без
	# опций. Подставляем процедурные выборы, чтобы экран всегда был кликабельным.
	if event_choices.is_empty():
		event_choices = _random_event_choices()
	# SCRUM-997: нижняя полоса выборов — отдельная full-rect зона на корне экрана
	# (не в панели): ряд карточек слева + плита «Назад» у правого safe-края.
	var bottom_zone := Control.new()
	bottom_zone.name = "EventBottomZone"
	bottom_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_zone.set_anchors_preset(Control.PRESET_FULL_RECT)
	if event_root != null:
		event_root.add_child(bottom_zone)
	else:
		box.add_child(bottom_zone)
	var event_card_size: Vector2 = metrics["card_size"]
	var row_rect: Rect2 = metrics["row_rect"]
	var choices := HBoxContainer.new()
	choices.name = "EventChoiceRow"
	choices.alignment = BoxContainer.ALIGNMENT_BEGIN
	choices.add_theme_constant_override("separation", int(metrics["gap"]))
	bottom_zone.add_child(choices)
	choices.position = row_rect.position
	choices.size = row_rect.size
	var selectable_buttons: Array[Button] = []
	var index := 0
	for event_choice in event_choices:
		var title_text := str(event_choice.get("title", "Выбор"))
		var desc_text := _event_choice_description_text(event_choice)
		var action_text := _event_choice_action_text(event_choice)
		var button := _make_economy_choice_card(title_text, desc_text, action_text, "EventChoiceButton%d" % index, event_card_size)
		button.name = "EventChoiceButton%d" % index
		# SCRUM-883: карточки выбора носят единый atlas-чип общего хелпера
		# _make_economy_choice_card (StyleBoxFlat a>=0.8, hover — более яркий золотой
		# кант); SCRUM-997 добавляет строку награды/чек-хинта (спека §2).
		_add_event_choice_hint_line(button, event_choice, event_card_size)
		var required_money := _event_choice_scaled_cost(event_choice)
		if required_money > 0 and _run_money() < required_money:
			button.disabled = true
			button.tooltip_text += "\nНедостаточно золота: нужно %d, есть %d." % [required_money, _run_money()]
		choices.add_child(button)
		if not button.disabled:
			selectable_buttons.append(button)
		button.pressed.connect(func() -> void:
			if not _event_choice_is_affordable(event_choice):
				# SCRUM-968: платный выбор события без золота — отказ.
				game._play_sfx("ui_error")
				return
			# SCRUM-968: платный выбор события (трата золота) — purchase.
			if _event_choice_scaled_cost(event_choice) > 0:
				game._play_sfx("purchase")
			var resolution := _apply_event_choice_resolved(event_choice)
			if bool(resolution.get("starts_combat", false)):
				return  # бой стартовал, экран уже сменён; reveal не показывается — исход боя = сам бой
			var outcome: Dictionary = resolution.get("outcome", {})
			if not bool(resolution.get("applied", false)):
				# Гонка оплаты (spend_money не прошёл несмотря на предпроверку) —
				# прежняя семантика: событие завершается без исхода и без магазина.
				game.current_event_definition.clear()
				game.route._advance_route_after_noncombat()
				return
			# SCRUM-996: исходы с outcome_text / hidden-выбора / check-проверки показывают
			# reveal-шаг («что произошло» + кнопка продолжения); остальные — прежний
			# мгновенный переход на карту.
			if _event_outcome_needs_reveal(event_choice, outcome):
				_show_event_outcome_reveal(box, outcome)
			else:
				_finish_event_and_continue(outcome)
		)
		index += 1
	# Единый возврат (фидбек 2026-07-08): везде «Назад» на плите back_260x104, 260×action-height.
	# SCRUM-997: плита живёт в нижней полосе у правого safe-края (спека §2) —
	# не на иллюстрации (нижняя четверть арта — тёмная UI-зона по манифесту SCRUM-998).
	var back_button := _make_button("Назад")
	back_button.name = "EventBackButton"
	_set_action_button_size(back_button, 260.0, _atlas_action_button_height())
	var allow_skip := bool(event_definition.get("allow_skip", false))
	# Аварийный выход: если ни один выбор недоступен (например, не хватает золота на все
	# платные опции), кнопка «Назад» обязана работать, иначе забег застревает навсегда.
	var no_selectable_choice := selectable_buttons.is_empty()
	var back_enabled := allow_skip or no_selectable_choice
	back_button.disabled = not back_enabled
	if allow_skip:
		back_button.tooltip_text = "Вернуться на карту без исхода события."
	elif no_selectable_choice:
		back_button.tooltip_text = "Нет доступных выборов — вернуться на карту."
	else:
		back_button.tooltip_text = "Это событие требует выбрать исход."
	back_button.pressed.connect(func() -> void:
		if not back_enabled:
			return
		game.current_event_definition.clear()
		game.route._show_battle_map()
	)
	bottom_zone.add_child(back_button)
	var back_rect: Rect2 = metrics["back_rect"]
	back_button.position = back_rect.position
	back_button.size = back_rect.size

	# Клавиатура/геймпад: события должны выбираться не только мышью (AC SCRUM-477).
	# Замыкаем фокус по доступным карточкам стрелками влево/вправо и ставим фокус на
	# первую выбираемую опцию (иначе при сбое мыши забег невозможно пройти с клавиатуры).
	var focus_chain: Array[Button] = selectable_buttons.duplicate()
	if back_enabled:
		focus_chain.append(back_button)
	for focus_index in range(focus_chain.size()):
		var card := focus_chain[focus_index]
		var prev := focus_chain[(focus_index - 1 + focus_chain.size()) % focus_chain.size()]
		var next := focus_chain[(focus_index + 1) % focus_chain.size()]
		card.focus_neighbor_left = prev.get_path()
		card.focus_neighbor_right = next.get_path()
		card.focus_neighbor_top = prev.get_path()
		card.focus_neighbor_bottom = next.get_path()
	if not focus_chain.is_empty():
		focus_chain[0].grab_focus()

	# SCRUM-530: Escape на событии открывает run-pause поверх экрана (консистентно с боем/
	# другими забеговыми экранами). На практике Escape перехватывается раньше через
	# _can_open_pause_dossier() (EventScreen в списке), но _create_menu_box→_clear_ui сбрасывает
	# ui_escape_action в начале функции, поэтому ставим явный фолбэк — если экран события когда-
	# либо перестанет опознаваться dossier-проверкой, Escape всё равно не станет «тихим тупиком».
	game.ui_escape_action = _show_pause_menu




func _random_event_choices() -> Array:
	# SCRUM-597: пул наград может исчерпаться (_weighted_sample отдаёт меньше
	# count при пустом пуле) — индексировать rewards[0]/[1] вслепую нельзя
	# (Index out of bounds). Строим reward-варианты только под реально выпавшие
	# награды, иначе подставляем детерминированный фолбэк, чтобы всегда было
	# 3 осмысленных выбора и «Отдых» как гарантированный безопасный вариант.
	var rewards := _random_rewards(2)
	var choices := []
	if rewards.size() >= 1:
		choices.append({
			"title": "Тренировка",
			"description": "Получить случайное улучшение характеристики.",
			"reward": rewards[0],
		})
	else:
		# Фолбэк без награды из пула: маленький гарантированный прирост.
		choices.append({
			"title": "Тренировка",
			"description": "Небольшой прирост характеристики.",
			"mods": {"defense_flat": 0.04},
		})
	if rewards.size() >= 2:
		choices.append({
			"title": "Рискованная реликвия",
			"description": "Потерять 15% здоровья и получить артефакт или характеристику.",
			"reward": rewards[1],
			"health_percent_cost": 0.15,
		})
	else:
		# Нет второй награды — не берём плату за HP впустую; даём безопасный прирост.
		choices.append({
			"title": "Закалка",
			"description": "Небольшой прирост максимального здоровья.",
			"mods": {"max_health_flat": 8.0},
		})
	choices.append({
		"title": "Отдых",
		"description": "Восстановить 25% максимального здоровья.",
		"heal_percent": 0.25,
	})
	return choices




func _event_choice_description_text(event_choice: Dictionary) -> String:
	# SCRUM-996: скрытый выбор не раскрывает исход — вместо описания показываем
	# «загадочный» hint (unknown_hint или дефолт), без «Риск:»-префикса.
	if bool(event_choice.get("hidden", false)):
		var hint := str(event_choice.get("unknown_hint", "")).strip_edges()
		return hint if hint != "" else EVENT_HIDDEN_CHOICE_FALLBACK_HINT
	return _event_choice_risk_description(str(event_choice.get("description", "")), bool(event_choice.get("risk", false)))




func _event_choice_action_text(event_choice: Dictionary) -> String:
	# SCRUM-996: hidden-карточка зовёт «Рискнуть» (цену, если она есть, обязан
	# упоминать unknown_hint — см. контракт схемы в event_data.gd).
	if bool(event_choice.get("hidden", false)):
		return "Рискнуть"
	var cost := _event_choice_scaled_cost(event_choice)
	if cost > 0:
		return "%d зол." % cost
	return "Выбрать"




func _event_choice_scaled_cost(event_choice: Dictionary) -> int:
	if not event_choice.has("cost_money"):
		return 0
	return game.PROGRESSION_DATA.stage_scaled_cost(int(event_choice["cost_money"]), game.route_scaling_stage())




func _event_choice_is_affordable(event_choice: Dictionary) -> bool:
	var cost := _event_choice_scaled_cost(event_choice)
	return cost <= 0 or _run_money() >= cost




func _event_choice_risk_description(description: String, is_risk: bool) -> String:
	var text := description.strip_edges()
	if not is_risk:
		return text
	if text.to_lower().begins_with("риск:"):
		return text
	return "Риск: %s" % text




# SCRUM-997: фон-иллюстрация события — texture по event.id из пака SCRUM-998
# (маппинг main.event_background_path, кэш screen_background_cache под ключом
# "event:<id>"). Незамапленный id оставляет общий backdrop "event" и плотный шейд
# 0.44; над родным артом шейд облегчается до 0.14 — арт сам держит тёмные
# UI-зоны (правая треть/нижняя четверть, манифест events_backgrounds_pack).
func _apply_event_screen_background(box: VBoxContainer, event_id: String) -> void:
	var root := _event_screen_root(box)
	if root == null:
		return
	var background := root.find_child("ScreenBackground_event", false, false) as TextureRect
	if background == null:
		return
	var path := str(game.event_background_path(event_id))
	if path == "":
		return
	var cache_key := "event:%s" % event_id
	var texture: Texture2D = null
	if game.screen_background_cache.has(cache_key):
		texture = game.screen_background_cache[cache_key]
	else:
		texture = game._cached_texture(path)
		game.screen_background_cache[cache_key] = texture
	if texture == null:
		return
	background.texture = texture
	var shade := root.find_child("ScreenBackgroundReadableShade", false, false) as ColorRect
	if shade != null:
		shade.color = Color(0.0, 0.0, 0.0, 0.14)




# SCRUM-997: строка награды/чек-хинта на карточке выбора (спека §2, п.3):
# «Проверка: <Стат> <N>» | компактная видимая награда | для hidden — «Исход
# скрыт» (точный исход не раскрываем, детали цены — в unknown_hint по контракту
# SCRUM-996). Пустая строка = хинт не показываем.
func _event_choice_hint_text(event_choice: Dictionary) -> String:
	if bool(event_choice.get("hidden", false)):
		return "Исход скрыт"
	if event_choice.has("check"):
		var check: Dictionary = event_choice.get("check", {})
		var stat_id := str(check.get("stat", ""))
		var stat_name := str(game.PROGRESSION_DATA.STAT_NAMES.get(stat_id, stat_id))
		return "Проверка: %s %d" % [stat_name, int(check.get("difficulty", 0))]
	if event_choice.has("random_outcomes"):
		return "Случайный исход"
	if event_choice.has("combat"):
		return "Бой — награда за победу"
	var parts: Array[String] = []
	if event_choice.has("health_percent_cost"):
		parts.append("−%d%% HP" % int(roundf(float(event_choice["health_percent_cost"]) * 100.0)))
	if event_choice.has("damage_flat"):
		parts.append("−%d HP" % int(roundf(float(event_choice["damage_flat"]))))
	if event_choice.has("money"):
		parts.append("+%d зол." % int(event_choice["money"]))
	if event_choice.has("heal_percent"):
		parts.append("Лечение %d%%" % int(roundf(float(event_choice["heal_percent"]) * 100.0)))
	var stats: Dictionary = event_choice.get("stats", {})
	for stat_id in stats:
		parts.append("%+d %s" % [int(stats[stat_id]), str(game.PROGRESSION_DATA.STAT_NAMES.get(str(stat_id), str(stat_id)))])
	if bool(event_choice.get("random_artifact", false)):
		parts.append("Случайный артефакт")
	if bool(event_choice.get("shop_after", false)):
		parts.append("Лавка торговца")
	if not (event_choice.get("mods", {}) as Dictionary).is_empty():
		parts.append("Бонус забега")
	if event_choice.has("reward"):
		parts.append("Награда")
	if parts.is_empty():
		# Выбор без цены и исхода («Пройти мимо») — честный нейтральный хинт,
		# карточка не остаётся без строки (контракт матрицы SCRUM-997).
		return "Без последствий"
	return " · ".join(PackedStringArray(parts.slice(0, 3)))




# SCRUM-997: вставка hint-строки в контент карточки (между описанием и action).
# Канон клип-строк: без autowrap, TRIM_ELLIPSIS и ЯВНЫЙ min-width (клип без
# min-width рядом с EXPAND_FILL схлопывает метку — память проекта); полный текст
# дублируется в tooltip карточки.
func _add_event_choice_hint_line(button: Button, event_choice: Dictionary, card_size: Vector2) -> void:
	if button == null:
		return
	var hint := _event_choice_hint_text(event_choice)
	if hint == "":
		return
	var content := button.find_child("%sContent" % button.name, false, false) as BoxContainer
	if content == null:
		return
	var margins: Vector4 = button.get_meta("economy_content_margins", Vector4.ZERO)
	var hint_label := Label.new()
	hint_label.name = "%sHint" % button.name
	hint_label.text = hint
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hint_label.custom_minimum_size = Vector2(maxf(card_size.x - margins.x - margins.z, 60.0), 0.0)
	hint_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_CAPTION, 13, 12, 18))
	hint_label.add_theme_color_override("font_color", Color(0.94, 0.80, 0.46, 1.0))
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(hint_label)
	# После title (0) и description (1), перед action-строкой.
	content.move_child(hint_label, mini(2, content.get_child_count() - 1))
	button.tooltip_text = "%s\n%s" % [button.tooltip_text, hint]
	# Событийный пост-фит ОТЛОЖЕННО (после первого лейаута): ready-мерка врёт —
	# autowrap-лейблы при ещё нулевой ширине завышают мин-высоту, и базовый
	# фиттер премature-ужимает контент даже в просторных карточках. Deferred-фит
	# сбрасывает эти ужимки и меряет по реальной ширине.
	button.ready.connect(func() -> void:
		_fit_event_choice_card_content.call_deferred(button)
	, CONNECT_ONE_SHOT)




# SCRUM-997: честная доводка карточки события по высоте ПОСЛЕ первого лейаута.
# Сброс premature-ужимок ready-фиттера (шрифты/строки к базе спеки §2), жёсткий
# минимум «одна строка описания» (единственный EXPAND_FILL-ребёнок при плотном
# бюджете сжимается ниже строки и рисует 0 строк — описание «исчезает»), при
# оверфлоу ужимка: шрифт описания → титул → hint; в конце max_lines описания
# по фактическому остатку бюджета (честный ellipsis). Полные тексты — в tooltip.
func _fit_event_choice_card_content(button: Button) -> void:
	if button == null or not is_instance_valid(button):
		return
	var content := button.find_child("%sContent" % button.name, false, false) as BoxContainer
	if content == null:
		return
	var margins: Vector4 = button.get_meta("economy_content_margins", Vector4.ZERO)
	var avail_h: float = button.custom_minimum_size.y - margins.y - margins.w
	if avail_h <= 0.0:
		return
	# Four semantic text lanes (title/description/hint/action) replace legacy
	# undersized copy. Compact event cards keep all lanes by spending ornamental
	# inter-line whitespace inside the empty chip content zone.
	if button.custom_minimum_size.y < 190.0:
		content.add_theme_constant_override("separation", 3)
	var title_label := button.find_child("%sTitle" % button.name, true, false) as Label
	var desc_label := button.find_child("%sDescription" % button.name, true, false) as Label
	var hint_label := button.find_child("%sHint" % button.name, true, false) as Label
	var desc_font_obj: Font = null
	if desc_label != null:
		desc_font_obj = desc_label.get_theme_font("font")
		if desc_font_obj == null:
			desc_font_obj = ThemeDB.fallback_font
	if title_label != null:
		title_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_TITLE,
			_readable_font_size(SemanticTypography.ROLE_TITLE, 17, 12, 24),
			SemanticTypography.role_min(SemanticTypography.ROLE_TITLE),
			SemanticTypography.role_max(SemanticTypography.ROLE_TITLE)
		))
	var desc_font := 0
	if desc_label != null:
		desc_font = _readable_font_size(SemanticTypography.ROLE_DESCRIPTION, 13, 12, 20)
		desc_label.max_lines_visible = -1
		desc_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_DESCRIPTION,
			desc_font,
			SemanticTypography.role_min(SemanticTypography.ROLE_DESCRIPTION),
			SemanticTypography.role_max(SemanticTypography.ROLE_DESCRIPTION)
		))
		if desc_font_obj != null:
			desc_label.custom_minimum_size = Vector2(0.0, ceilf(desc_font_obj.get_height(desc_font)) + 2.0)
	if hint_label != null:
		hint_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_CAPTION, 13, 12, 18))
	if desc_label != null and desc_font_obj != null:
		while desc_font > 12 and content.get_combined_minimum_size().y > avail_h:
			desc_font -= 1
			desc_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
				SemanticTypography.ROLE_DESCRIPTION,
				desc_font,
				SemanticTypography.role_min(SemanticTypography.ROLE_DESCRIPTION),
				SemanticTypography.role_max(SemanticTypography.ROLE_DESCRIPTION)
			))
			desc_label.custom_minimum_size = Vector2(0.0, ceilf(desc_font_obj.get_height(desc_font)) + 2.0)
	if title_label != null:
		var title_font := title_label.get_theme_font_size("font_size")
		while title_font > 13 and content.get_combined_minimum_size().y > avail_h:
			title_font -= 1
			title_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
				SemanticTypography.ROLE_TITLE,
				title_font,
				SemanticTypography.role_min(SemanticTypography.ROLE_TITLE),
				SemanticTypography.role_max(SemanticTypography.ROLE_TITLE)
			))
	if hint_label != null:
		var hint_font := hint_label.get_theme_font_size("font_size")
		while hint_font > 11 and content.get_combined_minimum_size().y > avail_h:
			hint_font -= 1
			hint_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(SemanticTypography.ROLE_CAPTION, hint_font))
	if desc_label != null and desc_font_obj != null:
		# Сколько строк описания реально помещается в остаток бюджета.
		var line_h := ceilf(desc_font_obj.get_height(desc_font))
		var others := content.get_combined_minimum_size().y - desc_label.custom_minimum_size.y
		var lines_fit := maxi(1, int(floorf((avail_h - others) / maxf(line_h, 1.0))))
		var lines_shown := mini(lines_fit, maxi(desc_label.get_line_count(), 1))
		desc_label.max_lines_visible = lines_shown
		desc_label.custom_minimum_size = Vector2(0.0, line_h * float(lines_shown) + 2.0)




# Обратная совместимость (rest-экран, dev-фасад main._apply_event_choice, старые
# тесты): bool = «стартовал бой». Полная резолюция — _apply_event_choice_resolved.
func _apply_event_choice(event_choice: Dictionary) -> bool:
	return bool(_apply_event_choice_resolved(event_choice).get("starts_combat", false))




# SCRUM-996: применяет выбор события и возвращает полную резолюцию для reveal-шага:
# {"applied": bool — исход применён (false = не прошла оплата cost_money),
#  "starts_combat": bool — стартовал бой (экран уже сменён),
#  "outcome": Dictionary — развёрнутый исход (random_outcomes/check уже слиты,
#   check_passed проставлен) — источник outcome_text/shop_after для reveal}.
func _apply_event_choice_resolved(event_choice: Dictionary) -> Dictionary:
	var temp_player = game.player_scene.instantiate()
	game.add_child(temp_player)
	if game.run_player_snapshot.is_empty():
		temp_player.configure_character(game.selected_character_id, game.selected_weapon_id)
	else:
		game.combat._restore_player_snapshot(temp_player)

	var outcome := _resolve_event_choice_outcome(event_choice, temp_player)
	if not _apply_event_outcome_to_player(outcome, temp_player):
		temp_player.queue_free()
		return {"applied": false, "starts_combat": false, "outcome": outcome}
	var combat_payload: Dictionary = outcome.get("combat", {})

	game.combat._store_player_snapshot(temp_player)
	temp_player.queue_free()

	if not combat_payload.is_empty():
		game.pending_event_combat = combat_payload.duplicate(true)
		if outcome.has("post_combat"):
			game.pending_event_combat["post_combat"] = outcome["post_combat"]
		game.current_event_definition.clear()
		var combat_type := str(combat_payload.get("type", "battle"))
		game.combat._start_combat(false, "elite" if combat_type == "elite" else "battle")
		return {"applied": true, "starts_combat": true, "outcome": outcome}
	return {"applied": true, "starts_combat": false, "outcome": outcome}




func _resolve_event_choice_outcome(event_choice: Dictionary, temp_player: Node) -> Dictionary:
	var outcome := event_choice.duplicate(true)
	if outcome.has("random_outcomes"):
		var outcomes: Array = outcome.get("random_outcomes", [])
		if not outcomes.is_empty():
			var picked: Dictionary = outcomes[game.rng.randi_range(0, outcomes.size() - 1)]
			outcome.merge(picked.duplicate(true), true)
	if outcome.has("check"):
		var check: Dictionary = outcome.get("check", {})
		var stats: Dictionary = temp_player.get("stats")
		var stat_id := str(check.get("stat", "knowledge"))
		# SCRUM-633: при отсутствии difficulty НЕ давать тихий success — порог 0.0
		# проходит всегда (базовые статы положительны). Логируем и трактуем как провал.
		var passed: bool
		if not check.has("difficulty"):
			push_error("Event check missing 'difficulty' for stat '%s'; treating as failure" % stat_id)
			passed = false
		else:
			var difficulty := float(check.get("difficulty", 0.0))
			passed = float(stats.get(stat_id, 0.0)) >= difficulty
		var branch: Dictionary = outcome.get("success" if passed else "failure", {})
		outcome.merge(branch.duplicate(true), true)
		outcome["check_passed"] = passed
	return outcome




func _apply_event_outcome_to_player(outcome: Dictionary, temp_player: Node) -> bool:
	if outcome.has("cost_money"):
		if not temp_player.spend_money(game.PROGRESSION_DATA.stage_scaled_cost(int(outcome["cost_money"]), game.route_scaling_stage())):
			return false
	if outcome.has("money"):
		temp_player.gain_money(int(outcome["money"]))
	if outcome.has("reward"):
		temp_player.apply_reward(outcome["reward"])
		game.record_codex_artifact_discovery(outcome["reward"])
	if outcome.has("stats") or outcome.has("mods") or outcome.has("heal_percent"):
		temp_player.apply_reward({
			"kind": "event",
			"title": str(outcome.get("title", "Событие")),
			"stats": outcome.get("stats", {}),
			"mods": outcome.get("mods", {}),
			"heal_percent": outcome.get("heal_percent", 0.0),
		})
	if bool(outcome.get("random_artifact", false)):
		var artifacts := _weighted_sample(game.PROGRESSION_DATA.reward_pool(game.selected_character_id, _run_ascension_level(), _run_cross_class_artifact_ids()).filter(func(reward: Dictionary) -> bool:
			return str(reward.get("kind", "")) == "artifact"
		), 1)
		if not artifacts.is_empty():
			temp_player.apply_reward(artifacts[0])
			game.record_codex_artifact_discovery(artifacts[0])
		else:
			# SCRUM-634: пул артефактов пуст. Игрок уже мог заплатить цену события
			# (HP/золото выше/ниже), поэтому компенсируем золотом и пишем варн —
			# вместо тихой деградации «цена списана, награда не выдана».
			var fallback_money: int = game.PROGRESSION_DATA.stage_scaled_cost(EMPTY_ARTIFACT_POOL_FALLBACK_MONEY, game.route_scaling_stage())
			temp_player.gain_money(fallback_money)
			push_warning("Event random_artifact: пул артефактов пуст — выдана золотая компенсация %d вместо артефакта." % fallback_money)
	if outcome.has("health_percent_cost"):
		var cost := float(temp_player.get("max_health")) * float(outcome["health_percent_cost"])
		temp_player.set("health", max(1.0, float(temp_player.get("health")) - cost))
	if outcome.has("damage_flat"):
		# SCRUM-996: прямой урон события; как и health_percent_cost — не летален
		# (пол 1 HP). Не путать с mods.damage_flat (бонус урона атак игрока).
		var flat_damage := maxf(0.0, float(outcome["damage_flat"]))
		temp_player.set("health", max(1.0, float(temp_player.get("health")) - flat_damage))
	return true




# SCRUM-996: исходу нужен reveal-шаг, если есть текст «что произошло», выбор был
# скрытым или была check-проверка — игрок обязан увидеть результат до карты.
# Исходы-бои сюда не попадают (starts_combat обрывает обработчик раньше).
func _event_outcome_needs_reveal(event_choice: Dictionary, outcome: Dictionary) -> bool:
	if bool(event_choice.get("hidden", false)):
		return true
	if str(outcome.get("outcome_text", "")).strip_edges() != "":
		return true
	return outcome.has("check_passed")




# SCRUM-996: текст раскрытия исхода: outcome_text + строка результата проверки
# («Проверка Сила 7 — пройдена/провалена»). Для старых событий без outcome_text
# остаётся хотя бы строка проверки; совсем пустой reveal получает нейтральный текст.
func _event_outcome_reveal_text(outcome: Dictionary) -> String:
	var lines: Array[String] = []
	var outcome_text := str(outcome.get("outcome_text", "")).strip_edges()
	if outcome_text != "":
		lines.append(outcome_text)
	if outcome.has("check_passed"):
		var check: Dictionary = outcome.get("check", {})
		var stat_id := str(check.get("stat", ""))
		var stat_name := str(game.PROGRESSION_DATA.STAT_NAMES.get(stat_id, stat_id))
		lines.append("Проверка %s %d — %s." % [stat_name, int(check.get("difficulty", 0)), "пройдена" if bool(outcome.get("check_passed", false)) else "провалена"])
	if lines.is_empty():
		lines.append("Выбор сделан — последствия уже с тобой.")
	return "\n".join(lines)




# SCRUM-996: reveal-состояние экрана события — story-текст заменяется текстом
# исхода, карточки выбора и «Назад» прячутся, остаётся одна кнопка продолжения
# EventContinueButton («В путь»). Только она завершает событие (clear + advance,
# либо событийный магазин при shop_after). SCRUM-997: исход показывается в
# диалог-панели справа, кнопка «В путь» — по центру нижней полосы (спека §2).
func _show_event_outcome_reveal(box: VBoxContainer, outcome: Dictionary) -> void:
	if box == null or not is_instance_valid(box):
		return
	var root := _event_screen_root(box)
	var story_label := box.find_child("EventStory", false, false) as Label
	if story_label != null:
		story_label.text = _event_outcome_reveal_text(outcome)
	var choices_row: CanvasItem = null
	var back_button: Button = null
	if root != null:
		choices_row = root.find_child("EventChoiceRow", true, false) as CanvasItem
		back_button = root.find_child("EventBackButton", true, false) as Button
	if choices_row == null:
		choices_row = box.find_child("EventChoiceRow", false, false) as CanvasItem
	if back_button == null:
		back_button = box.find_child("EventBackButton", false, false) as Button
	if choices_row != null:
		choices_row.visible = false
	if back_button != null:
		back_button.visible = false
	var continue_button := _make_button("В путь")
	continue_button.name = "EventContinueButton"
	_set_action_button_size(continue_button, 260.0, _atlas_action_button_height())
	continue_button.tooltip_text = "Принять исход и продолжить маршрут."
	continue_button.pressed.connect(func() -> void:
		_finish_event_and_continue(outcome)
	)
	var bottom_zone := root.find_child("EventBottomZone", true, false) as Control if root != null else null
	if bottom_zone != null:
		bottom_zone.add_child(continue_button)
		var metrics := _event_dialog_metrics()
		var row_rect: Rect2 = metrics["row_rect"]
		var back_h := _atlas_action_button_height()
		continue_button.position = Vector2(
			roundf(((metrics["vp"] as Vector2).x - 260.0) * 0.5),
			row_rect.position.y + roundf((row_rect.size.y - back_h) * 0.5)
		)
		continue_button.size = Vector2(260.0, back_h)
	else:
		continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(continue_button)
	# Фокус-цепь SCRUM-477: в reveal-состоянии единственная цель — кнопка
	# продолжения; замыкаем её на себя, чтобы стрелки/стик не роняли фокус.
	continue_button.focus_neighbor_left = continue_button.get_path()
	continue_button.focus_neighbor_right = continue_button.get_path()
	continue_button.focus_neighbor_top = continue_button.get_path()
	continue_button.focus_neighbor_bottom = continue_button.get_path()
	continue_button.grab_focus()
	# Исход уже применён к снапшоту — меню-HUD (HP/золото) показывает честные цифры.
	_update_hud()




# SCRUM-996: единая точка завершения события без боя. shop_after открывает
# событийный магазин, выход из которого ведёт к штатному advance маршрута
# (route_stage+1 + автосейв) вместо обычного shop-узлового возврата на карту.
func _finish_event_and_continue(outcome: Dictionary) -> void:
	game.current_event_definition.clear()
	if bool(outcome.get("shop_after", false)):
		_open_event_shop(Callable(game.route, "_advance_route_after_noncombat"), float(outcome.get("shop_discount", 0.0)))
		return
	game.route._advance_route_after_noncombat()




# SCRUM-996: магазин из событийного пути (shop_after исхода события или
# post_combat победы событийного боя). Сток генерируется заново под этот визит
# (узел — не shop, старый сток был очищен при входе на узел), опциональная
# скидка применяется к ценам один раз (сток и цены живут в автосейв-полях,
# повторный вход через level-up FAB их не пересчитывает). exit_action
# подменяет штатный выход магазина и вызывается один раз при выходе.
func _open_event_shop(exit_action: Callable, discount := 0.0) -> void:
	_clear_current_shop_stock()
	_ensure_shop_stock_for_current_node()
	_apply_event_shop_discount(discount)
	game.event_shop_exit_action = exit_action
	_show_shop_screen()




# SCRUM-996: скидка событийного магазина — умножает цены текущего стока,
# clamp 0..EVENT_SHOP_DISCOUNT_MAX, пол цены 1 золото.
func _apply_event_shop_discount(discount: float) -> void:
	var clamped := clampf(discount, 0.0, EVENT_SHOP_DISCOUNT_MAX)
	if clamped <= 0.0:
		return
	for item in game.current_shop_items:
		if item is Dictionary and (item as Dictionary).has("cost"):
			item["cost"] = maxi(1, int(round(float((item as Dictionary).get("cost", 0)) * (1.0 - clamped))))




func _random_rewards(count: int) -> Array:
	return _weighted_sample(game.PROGRESSION_DATA.reward_pool(game.selected_character_id, _run_ascension_level(), _run_cross_class_artifact_ids()), count)




# SCRUM-961: аргументы классового гейта артефактов (artifact_system_matrix §1.4)
# для всех сэмплеров. Возвышение — МЕТОВОЕ (макс. достигнутый уровень класса,
# main.ascension_level_for), не выбранный на забег: прогресс-награда класса не
# должна пропадать при игре на низкой сложности.
func _run_ascension_level() -> int:
	return game.ascension_level_for(game.selected_character_id)




# SCRUM-961 (§5): активные cross-class слоты «Украденного герба» текущего забега.
# Вне боя игрока нет — Array живёт в run_player_snapshot.run_modifiers.
func _run_cross_class_artifact_ids() -> Array:
	var modifiers := {}
	if game.current_player != null and is_instance_valid(game.current_player):
		var live_raw = game.current_player.get("run_modifiers")
		if live_raw is Dictionary:
			modifiers = live_raw
	else:
		modifiers = game.run_player_snapshot.get("run_modifiers", {}) as Dictionary
	var ids = modifiers.get("cross_class_artifact_ids", [])
	return (ids as Array).duplicate() if ids is Array else []




func _weighted_sample(pool: Array, count: int) -> Array:
	# Выбор без возврата с учетом weight (редкость артефактов растет с тиром).
	var picked := []
	while picked.size() < count and not pool.is_empty():
		var total := 0.0
		for entry in pool:
			total += float(entry.get("weight", 1.0))
		var roll: float = game.rng.randf() * total
		var index := 0
		for entry_index in range(pool.size()):
			roll -= float(pool[entry_index].get("weight", 1.0))
			if roll <= 0.0:
				index = entry_index
				break
		picked.append(pool[index])
		pool.remove_at(index)
	return picked




func _random_level_up_rewards(count: int) -> Array:
	# Микс: улучшения оружия/класса/вторичных атрибутов + РЕДКО (~5% на слот)
	# основная характеристика. Набор уникален и фиксируется на уровень.
	# FAN-1887: строгий фильтр — optional/weak оси, оси без capability-потребителя
	# и карты с нулевой фактической дельтой (cap_reached/zero_effective_delta по
	# живым статам/модам) отсеяны ДО выборки; редкие базовые характеристики идут
	# через consumability-фильтр (Лидерство — только summon-способным классам).
	var regular_pool: Array = AttributeContract.eligible_level_up_rewards(
		game.selected_character_id, _active_stats_snapshot(), _active_modifiers_snapshot(), _active_weapon_config())
	var stat_pool: Array = game.PROGRESSION_DATA.main_stat_level_up_rewards(game.selected_character_id)
	var prefill: Array = []
	# Capstone «Озарение» (ветвь Знаний мета-древа, SCRUM-150): ПЕРВОЕ повышение
	# в забеге гарантированно даёт основную характеристику. Гейт по level<=2
	# (run-persistent через снапшот) — срабатывает один раз за забег.
	var skill_mods: Dictionary = game.META_PROGRESSION.skill_modifiers(game.meta_state)
	if float(skill_mods.get("first_levelup_rare", 0.0)) > 0.0 and not stat_pool.is_empty() \
			and game.current_player != null and is_instance_valid(game.current_player) \
			and int(game.current_player.get("level")) <= 2:
		var forced_index: int = game.rng.randi_range(0, stat_pool.size() - 1)
		prefill.append(stat_pool[forced_index])
		stat_pool.remove_at(forced_index)
	# SCRUM-695: правило релевантности (≤1 optional, ≥1 primary/secondary) и взвешивание
	# по матрице вынесены в тестируемую ProgressionData.weighted_level_up_selection.
	return AttributeContract.weighted_level_up_selection(
		regular_pool, stat_pool, count, game.selected_character_id, game.rng, MAIN_STAT_SLOT_CHANCE, prefill)




func _random_shop_items(count: int) -> Array:
	var scaling_stage: int = game.route_scaling_stage()
	var items := _weighted_sample(game.PROGRESSION_DATA.shop_items(scaling_stage, game.selected_character_id, _run_ascension_level(), _run_cross_class_artifact_ids()), count)
	var price_mult := float(game.ascension_difficulty()["price_mult"])
	# Ветвь Богатства мета-древа (SCRUM-150): скидка магазина (shop_price_mult ≤ 0).
	var skill_mods: Dictionary = game.META_PROGRESSION.skill_modifiers(game.meta_state)
	price_mult *= maxf(1.0 + float(skill_mods.get("shop_price_mult", 0.0)), 0.1)
	# SCRUM-835: class keystone downside может быть положительным штрафом к ценам
	# выбранного героя (thief «Джекпот»), поэтому читаем class-specific моды тоже.
	# QA-фикс: skill_modifiers_for_class = Атлас + созвездие класса, поэтому берём
	# только классовую ДЕЛЬТУ — иначе аккаунтная скидка Атласа применялась бы дважды.
	var class_skill_mods: Dictionary = game.META_PROGRESSION.skill_modifiers_for_class(game.meta_state, game.selected_character_id)
	var class_shop_price_delta := float(class_skill_mods.get("shop_price_mult", 0.0)) - float(skill_mods.get("shop_price_mult", 0.0))
	price_mult *= maxf(1.0 + class_shop_price_delta, 0.1)
	# Capstone «Связи в гильдии»: гарантированный эпический (tier 3) товар на стене.
	if float(skill_mods.get("guaranteed_rare_shop", 0.0)) > 0.0 and not items.is_empty():
		var has_rare := false
		for item in items:
			if int(item.get("tier", 1)) >= 3:
				has_rare = true
				break
		if not has_rare:
			var rares: Array = (game.PROGRESSION_DATA.shop_items(scaling_stage, game.selected_character_id, _run_ascension_level(), _run_cross_class_artifact_ids()) as Array).filter(
				func(it): return int((it as Dictionary).get("tier", 1)) >= 3)
			if not rares.is_empty():
				items[game.rng.randi_range(0, items.size() - 1)] = (rares[game.rng.randi_range(0, rares.size() - 1)] as Dictionary).duplicate(true)
	if not is_equal_approx(price_mult, 1.0):
		for item in items:
			item["cost"] = maxi(1, int(round(float(item.get("cost", 0)) * price_mult)))
	return items
