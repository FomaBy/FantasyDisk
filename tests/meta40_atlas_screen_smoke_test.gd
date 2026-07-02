extends SceneTree

# SCRUM-827: смок экрана «Атлас героев» (Мета 4.0, дизайн §7 + мокап
# meta40_atlas_mockup). Headless-прогон по образцу meta_skill_tree_smoke_test:
# открытие экрана, лента 17 классов и переключение класса, покупка узла через
# панель («Вложить эмблему»), keystone-переключение (бесплатно, ≤1 активна),
# вкладка «Гильдия» (Атлас на звёздной пыли), церемония рассеивания тумана
# скрытой звезды (0.6с, скип кликом).

const Meta := preload("res://scripts/meta_progression.gd")
const MAIN_SCENE := preload("res://scenes/Main.tscn")


func _initialize() -> void:
	await _test_open_atlas_default()
	await _test_class_strip_switch()
	await _test_purchase_flow()
	await _test_keystone_toggle()
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
	if nodes.size() != 22:
		_fail("Атлас: созвездие класса должно рендериться целиком (22 узла), найдено %d." % nodes.size())
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
	if respec == null or not respec.text.contains("бесплатно"):
		_fail("Атлас: внизу должна быть кнопка «Респек — бесплатно».")
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
	if main.find_children("AtlasNode_*", "TextureButton", true, false).size() != 22:
		_fail("Лента: созвездие рыцаря должно рендериться целиком.")
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


# --- 3. Покупка узла: панель (титул/числа/цена) + «Вложить эмблему» ---

func _test_purchase_flow() -> void:
	var main := await _spawn_main({"meta_point_awards": {"berserk": [0, 1, 2, 3]}})
	main.ui._show_atlas_screen()
	await process_frame

	# Бейдж непотраченных эмблем на медальоне виден при available > 0.
	var badge := main.find_child("AtlasMedallionBadge_berserk", true, false) as PanelContainer
	if badge == null or not badge.visible:
		_fail("Покупка: медальон должен показывать бейдж непотраченных эмблем.")
		return

	var star := main.find_child("AtlasNode_berserk_m0", true, false) as TextureButton
	if star == null:
		_fail("Покупка: нет узла berserk_m0.")
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
	if not Meta.is_node_purchased(main.get("meta_state"), "berserk_m0"):
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


# --- 4. Keystone: переключение купленных бесплатно, активна ≤1 ---

func _test_keystone_toggle() -> void:
	var path_to_k0 := ["berserk_m0", "berserk_m1", "berserk_m2", "berserk_t0", "berserk_k0"]
	var path_to_k1 := ["berserk_m3", "berserk_m4", "berserk_m5", "berserk_t1", "berserk_k1"]
	var main := await _spawn_main({
		"skill_nodes": path_to_k0 + path_to_k1,
		"active_keystones": {"berserk": "berserk_k0"},
	})
	main.ui._show_atlas_screen()
	await process_frame

	var k1 := main.find_child("AtlasNode_berserk_k1", true, false) as TextureButton
	if k1 == null:
		_fail("Keystone: нет узла berserk_k1.")
		return
	k1.pressed.emit()
	await process_frame
	var toggle := main.find_child("AtlasKeystoneToggle", true, false) as Button
	if toggle == null or not toggle.visible or toggle.text != "Сделать активной":
		_fail("Keystone: у купленной неактивной ключевой должен быть переключатель «Сделать активной».")
		return
	var sigils_before: int = Meta.class_sigils_available(main.get("meta_state"), "berserk")
	toggle.pressed.emit()
	await process_frame
	if Meta.active_keystone(main.get("meta_state"), "berserk") != "berserk_k1":
		_fail("Keystone: переключение должно активировать k1.")
		return
	if Meta.is_keystone_active(main.get("meta_state"), "berserk_k0"):
		_fail("Keystone: активна может быть лишь одна ключевая звезда.")
		return
	if Meta.class_sigils_available(main.get("meta_state"), "berserk") != sigils_before:
		_fail("Keystone: переключение купленных обязано быть бесплатным.")
		return
	var ring := k1.get_node_or_null("Ring") as TextureRect
	if ring == null or not ring.visible:
		_fail("Keystone: активная ключевая должна сиять сапфировым кольцом.")
		return
	if toggle.text != "Активна — погасить":
		_fail("Keystone: переключатель должен показать активное состояние.")
		return
	await _teardown(main)


# --- 5. Вкладка «Гильдия»: Атлас на звёздной пыли ---

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
	var strip := main.find_child("AtlasClassStrip", true, false) as ScrollContainer
	if strip != null and strip.visible:
		_fail("Гильдия: лента классов на вкладке Атласа скрыта.")
		return
	var m0 := main.find_child("AtlasNode_atlas_m0", true, false) as TextureButton
	if m0 == null:
		_fail("Гильдия: нет раннего узла atlas_m0.")
		return
	m0.pressed.emit()
	await process_frame
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


# --- 6. Скрытая звезда: туман «?», условие в панели, церемония 0.6с со скипом ---

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
	locked_node.pressed.emit()
	await process_frame
	var condition := locked_main.find_child("AtlasNodeCondition", true, false) as Label
	if condition == null or not condition.is_visible_in_tree() or not condition.text.contains("Прогресс:"):
		_fail("Скрытая: панель должна показывать условие и прогресс подвига.")
		return
	await _teardown(locked_main)

	# Подвиг совершён (2 оружия) — при открытии экрана туман рассеивается 0.6с.
	var main := await _spawn_main({
		"class_challenge_progress": {"berserk": {"weapons": ["sword", "axe"], "best_ascension": 0, "no_shop_wins": 0}},
	})
	main.ui._show_atlas_screen()
	await process_frame
	var node := main.find_child("AtlasNode_berserk_h0", true, false) as TextureButton
	if node == null:
		_fail("Скрытая: нет узла berserk_h0 после подвига.")
		return
	var fog := node.get_node_or_null("Fog") as TextureRect
	if fog == null or not fog.visible:
		_fail("Скрытая: при первом показе открытой звезды должна идти церемония тумана.")
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
	node.pressed.emit()
	await process_frame
	var done_condition := main.find_child("AtlasNodeCondition", true, false) as Label
	if done_condition == null or not done_condition.text.contains("Подвиг совершён"):
		_fail("Скрытая: панель должна отметить совершённый подвиг.")
		return
	await _teardown(main)


func _has_digit(text: String) -> bool:
	for i in range(text.length()):
		var code := text.unicode_at(i)
		if code >= 48 and code <= 57:
			return true
	return false
