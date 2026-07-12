extends SceneTree

# SCRUM-827: смок экрана «Атлас героев» (Мета 4.0, дизайн §7 + мокап
# meta40_atlas_mockup). Headless-прогон по образцу meta_skill_tree_smoke_test:
# открытие экрана, лента 17 классов и переключение класса, click=preview-only
# для class/guild/locked/hidden/final ячеек, покупка узла только через
# панель («Вложить эмблему»), три weapon final работают одновременно без
# legacy activation toggle, вкладка «Гильдия» (Атлас на звёздной пыли),
# церемония рассеивания тумана скрытой звезды (0.6с, скип кликом).

const Meta := preload("res://scripts/meta_progression.gd")
const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _initialize() -> void:
	await _test_open_atlas_default()
	await _test_class_strip_switch()
	await _test_available_class_cell_click_is_preview_only()
	await _test_locked_and_hidden_cell_clicks_are_preview_only()
	await _test_purchase_flow()
	await _test_available_final_click_is_preview_only()
	await _test_simultaneous_finals_have_no_toggle()
	await _test_guild_locked_click_is_preview_only()
	await _test_guild_tab()
	await _test_hidden_star_fog_ceremony()
	print("Meta40 atlas screen smoke test passed.")
	quit(0)


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)


func _spawn_main(state_patch: Dictionary = {}) -> Node:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	var state: Dictionary = main.get("meta_state")
	state["skill_nodes"] = []
	state["active_keystones"] = {}
	state["meta_point_awards"] = {}
	state["ascension_levels"] = {}
	state["class_boss_wins"] = {}
	state["class_challenge_progress"] = {}
	state["class_challenges_done"] = {}
	state["secret_boss_defeated"] = false
	state["achievements"] = []
	state["discovered_monsters"] = []
	state["discovered_bosses"] = []
	state["discovered_artifacts"] = []
	for key in state_patch.keys():
		state[key] = state_patch[key]
	main.set("meta_state", state)
	main.set("selected_character_id", "berserk")
	return main


func _teardown(main: Node) -> void:
	main.queue_free()
	await process_frame


# --- 1. Открытие: каркас §7 целиком (небо, рама, лента, холст, панель, низ) ---

func _test_open_atlas_default() -> void:
	var main := await _spawn_main()
	main.ui._show_atlas_screen()
	await process_frame
	await process_frame

	if main.find_child("AtlasScreen", true, false) == null:
		_fail("Атлас: экран не открылся.")
		return
	var sky := main.find_child("AtlasSky", true, false) as TextureRect
	if sky == null or sky.texture == null or not sky.texture.resource_path.ends_with("meta40/bg_sky.png"):
		_fail("Атлас: фон-небо должен быть bg_sky из кита meta40.")
		return
	var frame := main.find_child("AtlasFrame", true, false) as Panel
	if frame == null:
		_fail("Атлас: нет орнаментной рамы.")
		return
	var medallions := main.find_children("AtlasMedallion_*", "TextureButton", true, false)
	if medallions.size() != 17:
		_fail("Атлас: в ленте должно быть 17 медальонов, найдено %d." % medallions.size())
		return
	var nodes := main.find_children("AtlasNode_*", "TextureButton", true, false)
	if nodes.size() != 21:
		_fail("Атлас: schema-6 созвездие класса должно рендериться целиком (21 узел), найдено %d." % nodes.size())
		return
	var node_overlap := _first_node_circle_overlap(nodes, 2.0)
	if node_overlap != "":
		_fail("Атлас: круги созвездия не должны наслаиваться, найдено %s." % node_overlap)
		return
	var emblems := main.find_child("AtlasEmblemsLabel", true, false) as Label
	if emblems == null or not emblems.text.begins_with("Эмблемы Берсерка:"):
		_fail("Атлас: шапка должна показывать эмблемы выбранного класса, получено: %s" % (emblems.text if emblems != null else "null"))
		return
	var stardust := main.find_child("AtlasStardustLabel", true, false) as Label
	if stardust == null or not stardust.text.begins_with("Звёздная пыль:"):
		_fail("Атлас: шапка должна показывать звёздную пыль.")
		return
	var respec := main.find_child("AtlasRespecButton", true, false) as Button
	if respec == null or not respec.text.contains("Сброс умений"):
		_fail("Атлас: внизу должна быть кнопка «Сброс умений».")
		return
	if main.find_child("AtlasLegend", true, false) == null:
		_fail("Атлас: внизу должна быть легенда состояний.")
		return
	# Ядро класса всегда куплено: у ядра герб класса и статус panel по умолчанию.
	var core := main.find_child("AtlasNode_berserk_core", true, false) as TextureButton
	if core == null or core.texture_normal == null or not core.texture_normal.resource_path.ends_with("crest_berserk.png"):
		_fail("Атлас: ядро созвездия должно рисоваться гербом класса.")
		return
	await _teardown(main)


# --- 2. Лента классов: переключение класса в 1 клик ---

func _test_class_strip_switch() -> void:
	var main := await _spawn_main()
	main.ui._show_atlas_screen()
	await process_frame
	var knight := main.find_child("AtlasMedallion_knight", true, false) as TextureButton
	if knight == null:
		_fail("Лента: нет медальона рыцаря.")
		return
	knight.pressed.emit()
	await process_frame
	if main.find_child("AtlasNode_knight_core", true, false) == null:
		_fail("Лента: клик по медальону должен показать созвездие рыцаря.")
		return
	if main.find_children("AtlasNode_*", "TextureButton", true, false).size() != 21:
		_fail("Лента: созвездие рыцаря должно рендериться целиком.")
		return
	var node_overlap := _first_node_circle_overlap(main.find_children("AtlasNode_*", "TextureButton", true, false), 2.0)
	if node_overlap != "":
		_fail("Лента: круги созвездия рыцаря не должны наслаиваться, найдено %s." % node_overlap)
		return
	var emblems := main.find_child("AtlasEmblemsLabel", true, false) as Label
	if emblems == null or not emblems.text.begins_with("Эмблемы Рыцаря:"):
		_fail("Лента: шапка должна переключиться на эмблемы рыцаря, получено: %s" % (emblems.text if emblems != null else "null"))
		return
	var progress := main.find_child("AtlasMedallionProgress_knight", true, false) as Label
	if progress == null or not progress.text.contains("/"):
		_fail("Лента: на медальоне должен быть прогресс x/N.")
		return
	await _teardown(main)


# --- 3. Клик по ячейке: только предпросмотр; покупка — только кнопкой панели ---

func _test_available_class_cell_click_is_preview_only() -> void:
	var main := await _spawn_main({"meta_point_awards": {"berserk": [0, 1, 2, 3]}})
	main.ui._show_atlas_screen()
	await process_frame

	var star := main.find_child("AtlasNode_berserk_sword_b1", true, false) as TextureButton
	if star == null:
		_fail("Preview-only: нет доступного узла berserk_sword_b1.")
		return
	var before := _meta_snapshot(main, "berserk")
	star.pressed.emit()
	await process_frame
	if not _expect_meta_snapshot(main, before, "berserk", "Preview-only: первый клик по доступной классовой звезде"):
		return
	if Meta.is_node_purchased(main.get("meta_state"), "berserk_sword_b1"):
		_fail("Preview-only: клик по доступной звезде не должен покупать berserk_sword_b1.")
		return
	var title := main.find_child("AtlasNodeTitle", true, false) as Label
	var price := main.find_child("AtlasNodePriceLabel", true, false) as Label
	var buy := main.find_child("AtlasBuyButton", true, false) as Button
	if title == null or title.text.strip_edges() == "":
		_fail("Preview-only: клик обязан показать описание выбранной звезды.")
		return
	if price == null or not price.is_visible_in_tree() or not price.text.begins_with("Цена:"):
		_fail("Preview-only: клик обязан показать цену выбранной звезды.")
		return
	if buy == null or not buy.visible or buy.disabled:
		_fail("Preview-only: для доступной звезды action-кнопка должна быть активной, но отдельной от клика.")
		return
	star.pressed.emit()
	await process_frame
	if not _expect_meta_snapshot(main, before, "berserk", "Preview-only: повторный клик по уже выбранной звезде"):
		return
	await _teardown(main)


func _test_locked_and_hidden_cell_clicks_are_preview_only() -> void:
	var main := await _spawn_main()
	main.ui._show_atlas_screen()
	await process_frame

	var locked := main.find_child("AtlasNode_berserk_sword_b1", true, false) as TextureButton
	if locked == null:
		_fail("Preview-only locked: нет узла berserk_sword_b1.")
		return
	var locked_before := _meta_snapshot(main, "berserk")
	locked.pressed.emit()
	await process_frame
	if not _expect_meta_snapshot(main, locked_before, "berserk", "Preview-only: клик по too-expensive/locked звезде"):
		return
	var locked_buy := main.find_child("AtlasBuyButton", true, false) as Button
	var locked_condition := main.find_child("AtlasNodeCondition", true, false) as Label
	if locked_buy == null or not locked_buy.visible or not locked_buy.disabled:
		_fail("Preview-only locked: action-кнопка должна быть видимой, но disabled для недоступной звезды.")
		return
	if locked_condition == null or not locked_condition.is_visible_in_tree() or not locked_condition.text.contains("Не хватает"):
		_fail("Preview-only locked: панель должна объяснить, почему звезда недоступна.")
		return

	var hidden := main.find_child("AtlasNode_berserk_h0", true, false) as TextureButton
	if hidden == null:
		_fail("Preview-only hidden: нет узла berserk_h0.")
		return
	var hidden_before := _meta_snapshot(main, "berserk")
	hidden.pressed.emit()
	await process_frame
	if not _expect_meta_snapshot(main, hidden_before, "berserk", "Preview-only: клик по скрытой звезде"):
		return
	var hidden_buy := main.find_child("AtlasBuyButton", true, false) as Button
	var hidden_condition := main.find_child("AtlasNodeCondition", true, false) as Label
	if hidden_buy == null or hidden_buy.visible:
		_fail("Preview-only hidden: скрытая звезда не должна показывать кнопку покупки.")
		return
	if hidden_condition == null or not hidden_condition.is_visible_in_tree() or not hidden_condition.text.contains("Прогресс:"):
		_fail("Preview-only hidden: панель должна показать условие и прогресс скрытой звезды.")
		return
	await _teardown(main)


# --- 4. Покупка узла: панель (титул/числа/цена) + «Вложить эмблему» ---

func _test_purchase_flow() -> void:
	var main := await _spawn_main({"meta_point_awards": {"berserk": [0, 1, 2, 3]}})
	main.ui._show_atlas_screen()
	await process_frame

	# Бейдж непотраченных эмблем на медальоне виден при available > 0.
	var badge := main.find_child("AtlasMedallionBadge_berserk", true, false) as PanelContainer
	if badge == null or not badge.visible:
		_fail("Покупка: медальон должен показывать бейдж непотраченных эмблем.")
		return

	var star := main.find_child("AtlasNode_berserk_sword_b1", true, false) as TextureButton
	if star == null:
		_fail("Покупка: нет узла berserk_sword_b1.")
		return
	star.pressed.emit()
	await process_frame
	var title := main.find_child("AtlasNodeTitle", true, false) as Label
	var desc := main.find_child("AtlasNodeDesc", true, false) as Label
	var price := main.find_child("AtlasNodePriceLabel", true, false) as Label
	if title == null or title.text.strip_edges() == "":
		_fail("Покупка: панель узла должна показать титул.")
		return
	if desc == null or not _has_digit(desc.text):
		_fail("Покупка: описание узла обязано содержать ЧИСЛА, получено: %s" % (desc.text if desc != null else "null"))
		return
	if price == null or not price.is_visible_in_tree() or not price.text.begins_with("Цена:"):
		_fail("Покупка: панель должна показывать цену узла.")
		return
	var buy := main.find_child("AtlasBuyButton", true, false) as Button
	if buy == null or not buy.visible or buy.disabled or buy.text != "Вложить эмблему":
		_fail("Покупка: должна быть активная кнопка «Вложить эмблему».")
		return
	var before: int = Meta.class_sigils_available(main.get("meta_state"), "berserk")
	buy.pressed.emit()
	await process_frame
	if not Meta.is_node_purchased(main.get("meta_state"), "berserk_sword_b1"):
		_fail("Покупка: узел должен купиться.")
		return
	if Meta.class_sigils_available(main.get("meta_state"), "berserk") != before - 1:
		_fail("Покупка: должна списаться 1 эмблема класса.")
		return
	var star_overlay := star.get_node_or_null("Star") as TextureRect
	if star_overlay == null or not star_overlay.visible:
		_fail("Покупка: на купленном сокете должна загореться золотая звезда.")
		return
	await _teardown(main)


# --- 5. Schema 6 finals: preview-only, permanent and simultaneous ---

func _test_available_final_click_is_preview_only() -> void:
	var path_to_final := [
		"berserk_sword_b1", "berserk_sword_b2", "berserk_sword_b3",
		"berserk_sword_b4", "berserk_sword_b5",
	]
	var main := await _spawn_main({
		"meta_point_awards": {"berserk": [0, 1, 2, 3, 4, 5]},
		"skill_nodes": path_to_final,
	})
	main.ui._show_atlas_screen()
	await process_frame

	var final_button := main.find_child("AtlasNode_berserk_sword_final", true, false) as TextureButton
	if final_button == null:
		_fail("Final preview-only: нет узла berserk_sword_final.")
		return
	var before := _meta_snapshot(main, "berserk")
	final_button.pressed.emit()
	await process_frame
	if not _expect_meta_snapshot(main, before, "berserk", "Preview-only: клик по доступному weapon final"):
		return
	if Meta.is_node_purchased(main.get("meta_state"), "berserk_sword_final"):
		_fail("Final preview-only: клик не должен покупать финал.")
		return
	var callout := main.find_child("AtlasNodeFinalCallout", true, false) as Label
	var toggle := main.find_child("AtlasKeystoneToggle", true, false) as Button
	var buy := main.find_child("AtlasBuyButton", true, false) as Button
	if callout == null or not callout.is_visible_in_tree() or callout.text != "УНИКАЛЬНЫЙ ФИНАЛ":
		_fail("Final preview-only: нет точного callout.")
		return
	if toggle == null or toggle.visible:
		_fail("Final preview-only: weapon final не должен показывать activation toggle.")
		return
	if buy == null or not buy.visible or buy.disabled or buy.text != "Вложить эмблему":
		_fail("Final preview-only: доступный финал должен покупаться только action-кнопкой.")
		return
	buy.pressed.emit()
	await process_frame
	if not Meta.is_node_purchased(main.get("meta_state"), "berserk_sword_final"):
		_fail("Final action: кнопка должна купить финал.")
		return
	if toggle.visible or Meta.active_keystone(main.get("meta_state"), "berserk") != "":
		_fail("Final action: покупка не должна создавать legacy active_keystone.")
		return
	await _teardown(main)


func _test_simultaneous_finals_have_no_toggle() -> void:
	var all_paths := [
		"berserk_sword_b1", "berserk_sword_b2", "berserk_sword_b3", "berserk_sword_b4", "berserk_sword_b5", "berserk_sword_final",
		"berserk_axe_b1", "berserk_axe_b2", "berserk_axe_b3", "berserk_axe_b4", "berserk_axe_b5", "berserk_axe_final",
		"berserk_hammer_b1", "berserk_hammer_b2", "berserk_hammer_b3", "berserk_hammer_b4", "berserk_hammer_b5", "berserk_hammer_final",
	]
	var main := await _spawn_main({"skill_nodes": all_paths})
	main.ui._show_atlas_screen()
	await process_frame
	var toggle := main.find_child("AtlasKeystoneToggle", true, false) as Button
	for final_id in ["berserk_sword_final", "berserk_axe_final", "berserk_hammer_final"]:
		var final_button := main.find_child("AtlasNode_%s" % final_id, true, false) as TextureButton
		if final_button == null or not Meta.is_node_purchased(main.get("meta_state"), final_id):
			_fail("Simultaneous finals: отсутствует купленный %s." % final_id)
			return
		final_button.pressed.emit()
		await process_frame
		if toggle == null or toggle.visible:
			_fail("Simultaneous finals: %s показывает legacy toggle." % final_id)
			return
	if Meta.active_keystone(main.get("meta_state"), "berserk") != "":
		_fail("Simultaneous finals: schema 6 не должна иметь active_keystone.")
		return
	await _teardown(main)


# --- 6. Вкладка «Гильдия»: клик preview-only, покупка на звёздной пыли ---

func _test_guild_locked_click_is_preview_only() -> void:
	var main := await _spawn_main()
	main.ui._show_atlas_screen()
	await process_frame
	var guild_tab := main.find_child("AtlasTabGuild", true, false) as Button
	if guild_tab == null:
		_fail("Гильдия locked preview-only: нет вкладки.")
		return
	guild_tab.pressed.emit()
	await process_frame
	var m0 := main.find_child("AtlasNode_atlas_m0", true, false) as TextureButton
	if m0 == null:
		_fail("Гильдия locked preview-only: нет узла atlas_m0.")
		return
	var before := _meta_snapshot(main, "berserk")
	m0.pressed.emit()
	await process_frame
	if not _expect_meta_snapshot(main, before, "berserk", "Preview-only: клик по недоступному узлу Гильдии"):
		return
	var buy := main.find_child("AtlasBuyButton", true, false) as Button
	var condition := main.find_child("AtlasNodeCondition", true, false) as Label
	if buy == null or not buy.visible or not buy.disabled or buy.text != "Вложить пыль":
		_fail("Гильдия locked preview-only: action-кнопка должна быть disabled и работать с пылью.")
		return
	if condition == null or not condition.is_visible_in_tree() or not condition.text.contains("Не хватает"):
		_fail("Гильдия locked preview-only: панель должна объяснить нехватку пыли.")
		return
	await _teardown(main)


func _test_guild_tab() -> void:
	# Первая победа классом даёт пыль (STARDUST_FIRST_WIN) — хватает на atlas_m0.
	var main := await _spawn_main({"meta_point_awards": {"berserk": [0]}})
	main.ui._show_atlas_screen()
	await process_frame
	var guild_tab := main.find_child("AtlasTabGuild", true, false) as Button
	if guild_tab == null:
		_fail("Гильдия: нет вкладки.")
		return
	guild_tab.pressed.emit()
	await process_frame
	var atlas_count := Meta.atlas_nodes().size()
	var nodes := main.find_children("AtlasNode_*", "TextureButton", true, false)
	if nodes.size() != atlas_count:
		_fail("Гильдия: должен рендериться весь Атлас (%d узлов), найдено %d." % [atlas_count, nodes.size()])
		return
	var node_overlap := _first_node_circle_overlap(nodes, 2.0)
	if node_overlap != "":
		_fail("Гильдия: круги Атласа не должны наслаиваться, найдено %s." % node_overlap)
		return
	var strip := main.find_child("AtlasClassStrip", true, false) as ScrollContainer
	if strip != null and strip.visible:
		_fail("Гильдия: лента классов на вкладке Атласа скрыта.")
		return
	var m0 := main.find_child("AtlasNode_atlas_m0", true, false) as TextureButton
	if m0 == null:
		_fail("Гильдия: нет раннего узла atlas_m0.")
		return
	var before := _meta_snapshot(main, "berserk")
	m0.pressed.emit()
	await process_frame
	if not _expect_meta_snapshot(main, before, "berserk", "Preview-only: клик по доступному узлу Гильдии"):
		return
	if Meta.is_node_purchased(main.get("meta_state"), "atlas_m0"):
		_fail("Гильдия: клик по atlas_m0 не должен покупать узел.")
		return
	var buy := main.find_child("AtlasBuyButton", true, false) as Button
	if buy == null or not buy.visible or buy.text != "Вложить пыль":
		_fail("Гильдия: кнопка покупки должна вкладывать пыль.")
		return
	if buy.disabled:
		_fail("Гильдия: atlas_m0 за 1 пыль должен быть доступен после первой победы.")
		return
	var dust_before: int = Meta.stardust_available(main.get("meta_state"))
	buy.pressed.emit()
	await process_frame
	if not Meta.is_node_purchased(main.get("meta_state"), "atlas_m0"):
		_fail("Гильдия: покупка узла Атласа должна пройти.")
		return
	if Meta.stardust_available(main.get("meta_state")) >= dust_before:
		_fail("Гильдия: покупка обязана списать звёздную пыль.")
		return
	await _teardown(main)


# --- 7. Скрытая звезда: туман «?», условие в панели, церемония 0.6с со скипом ---

func _test_hidden_star_fog_ceremony() -> void:
	# Сначала — заперта: туман «?» и условие с прогрессом.
	var locked_main := await _spawn_main()
	locked_main.ui._show_atlas_screen()
	await process_frame
	var locked_node := locked_main.find_child("AtlasNode_berserk_h0", true, false) as TextureButton
	if locked_node == null:
		_fail("Скрытая: нет узла berserk_h0.")
		return
	var qmark := locked_node.get_node_or_null("QMark") as Label
	if qmark == null or not qmark.visible:
		_fail("Скрытая: запертая звезда должна прятаться в тумане с «?».")
		return
	var locked_before := _meta_snapshot(locked_main, "berserk")
	locked_node.pressed.emit()
	await process_frame
	if not _expect_meta_snapshot(locked_main, locked_before, "berserk", "Скрытая: клик по запертому туману"):
		return
	var condition := locked_main.find_child("AtlasNodeCondition", true, false) as Label
	if condition == null or not condition.is_visible_in_tree() or not condition.text.contains("Прогресс:"):
		_fail("Скрытая: панель должна показывать условие и прогресс подвига.")
		return
	await _teardown(locked_main)

	# Подвиг совершён (2 оружия) — reveal ещё не активирует эффект. Сначала
	# explicit cost-1 purchase, затем запускается церемония тумана 0.6с.
	var main := await _spawn_main({
		"meta_point_awards": {"berserk": [0, 1, 2, 3, 4, 5]},
		"skill_nodes": ["berserk_sword_b1", "berserk_sword_b2", "berserk_sword_b3"],
		"hidden_reveal_facts": {"berserk": ["berserk_h0"]},
		"class_challenge_progress": {"berserk": {"weapons": ["sword", "axe"], "best_ascension": 0, "no_shop_wins": 0}},
	})
	main.ui._show_atlas_screen()
	await process_frame
	var node := main.find_child("AtlasNode_berserk_h0", true, false) as TextureButton
	if node == null:
		_fail("Скрытая: нет узла berserk_h0 после подвига.")
		return
	var fog := node.get_node_or_null("Fog") as TextureRect
	if fog == null or fog.visible:
		_fail("Скрытая: reveal без покупки не должен запускать церемонию или эффект.")
		return
	node.pressed.emit()
	await process_frame
	var buy := main.find_child("AtlasBuyButton", true, false) as Button
	var revealed_condition := main.find_child("AtlasNodeCondition", true, false) as Label
	if buy == null or not buy.visible or buy.disabled or revealed_condition == null or not revealed_condition.text.contains("можно купить"):
		_fail("Скрытая: после подвига должна быть explicit cost-1 purchase с объяснением reveal-state.")
		return
	buy.pressed.emit()
	await process_frame
	if not Meta.is_node_purchased(main.get("meta_state"), "berserk_h0") or not fog.visible:
		_fail("Скрытая: покупка должна активировать звезду и запустить церемонию тумана.")
		return
	# Скип кликом: туман гаснет сразу.
	main.ui._atlas_skip_fog_ceremonies()
	await process_frame
	if fog.visible:
		_fail("Скрытая: клик обязан скипать церемонию рассеивания.")
		return
	var star_overlay := node.get_node_or_null("Star") as TextureRect
	if star_overlay == null or not star_overlay.visible:
		_fail("Скрытая: открытая подвигом звезда должна гореть золотом.")
		return
	var unlocked_before := _meta_snapshot(main, "berserk")
	node.pressed.emit()
	await process_frame
	if not _expect_meta_snapshot(main, unlocked_before, "berserk", "Скрытая: клик по открытой скрытой звезде"):
		return
	var done_condition := main.find_child("AtlasNodeCondition", true, false) as Label
	if done_condition == null or not done_condition.text.contains("Звезда зажжена"):
		_fail("Скрытая: панель должна отметить купленную активную звезду.")
		return
	await _teardown(main)


func _has_digit(text: String) -> bool:
	for i in range(text.length()):
		var code := text.unicode_at(i)
		if code >= 48 and code <= 57:
			return true
	return false


func _meta_snapshot(main: Node, class_id: String) -> Dictionary:
	var state: Dictionary = main.get("meta_state")
	var raw_nodes = state.get("skill_nodes", [])
	var nodes: Array = []
	if raw_nodes is Array:
		nodes = (raw_nodes as Array).duplicate()
		nodes.sort()
	return {
		"skill_nodes": nodes,
		"active_keystone": Meta.active_keystone(state, class_id),
		"sigils": Meta.class_sigils_available(state, class_id),
		"stardust": Meta.stardust_available(state),
		"challenge_progress": str(state.get("class_challenge_progress", {})),
	}


func _expect_meta_snapshot(main: Node, before: Dictionary, class_id: String, context: String) -> bool:
	var after := _meta_snapshot(main, class_id)
	for key in before.keys():
		if str(after.get(key)) != str(before.get(key)):
			_fail("%s: клик по ячейке должен быть только preview; поле %s изменилось с %s на %s." % [context, str(key), str(before.get(key)), str(after.get(key))])
			return false
	return true


func _first_node_circle_overlap(nodes: Array, tolerance_px: float) -> String:
	for first_index in range(nodes.size()):
		var first := nodes[first_index] as TextureButton
		if first == null or not first.visible:
			continue
		var first_rect := first.get_global_rect()
		var first_radius := minf(first_rect.size.x, first_rect.size.y) * 0.5 - tolerance_px
		for second_index in range(first_index + 1, nodes.size()):
			var second := nodes[second_index] as TextureButton
			if second == null or not second.visible:
				continue
			var second_rect := second.get_global_rect()
			var second_radius := minf(second_rect.size.x, second_rect.size.y) * 0.5 - tolerance_px
			var distance := first_rect.get_center().distance_to(second_rect.get_center())
			if distance < first_radius + second_radius:
				return "%s/%s distance %.1f < %.1f" % [first.name, second.name, distance, first_radius + second_radius]
	return ""
