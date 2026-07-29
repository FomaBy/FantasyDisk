extends SceneTree

# SCRUM-983 focused acceptance for the real Escape/pause dossier. The oracle
# validates authored content zones, semantic stat rows, compact values,
# complete tooltips, focus reachability and live responsive relayout.

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const FRAME_PATH_SUFFIX := "meta40/frame_border.png"
const TARGETS := [
	Vector2i(1152, 648),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const BASE_IDS := [
	"strength", "agility", "intelligence", "perception",
	"energy", "knowledge", "endurance", "leadership",
]
# FAN-1887/FAN-1927: досье показывает только канонические оси реестра
# (axis id, канонический порядок/названия). DERIVED_IDS — оси berserk/sword
# базовой fixture (dot_damage и summon_amount этому киту ineligible и
# отсутствуют — проверяется отдельно). Derived-алиасы старого досье
# (damage/magic_damage/crit_damage_multiplier/vampiric_amount/...) запрещены.
const DERIVED_IDS := [
	"damage_flat", "damage", "attack_speed", "move_speed", "aoe_radius",
	"pickup_radius", "crit_chance", "crit_damage", "vampiric", "ultimate_power",
]
const BERSERK_INELIGIBLE_AXES := ["dot_damage", "summon_amount"]
const REMOVED_DERIVED_IDS := [
	"knockback_power", "projectile_speed", "attack_range", "range_multiplier",
	"aura_radius", "buff_power", "knockback_distance", "dot_speed", "vampiric_chance", "absorb",
	"magic_damage", "crit_damage_multiplier", "vampiric_amount", "ultimate_multiplier",
]
const DERIVED_COMPACT_LABELS := {
	"damage_flat": "Доб. урона",
	"damage": "Ув. урона",
	"attack_speed": "Скор. атаки",
	"move_speed": "Скор. движ.",
	"aoe_radius": "Область",
	"pickup_radius": "Подбор",
	"crit_chance": "Шанс крита",
	"crit_damage": "Сила крита",
	"dot_damage": "Период. урон",
	"summon_amount": "Сила призыва",
	"vampiric": "Вампиризм",
	"ultimate_power": "Ультимейт",
}
const DERIVED_TIGHT_LABELS := {
	"damage_flat": "Д. ур.", "damage": "У. ур.", "attack_speed": "Скор.",
	"crit_chance": "Крит", "crit_damage": "К×",
	"aoe_radius": "Обл.", "ultimate_power": "Ульт",
	"move_speed": "Движ.", "pickup_radius": "Подб.",
	"dot_damage": "Пер.", "summon_amount": "Приз.",
	"vampiric": "Вамп.",
}
const DERIVED_ULTRA_TIGHT_LABELS := {
	"damage_flat": "Д+", "damage": "Д%", "attack_speed": "Ск.",
	"crit_chance": "Кр.", "crit_damage": "К×",
	"aoe_radius": "О", "ultimate_power": "У",
	"move_speed": "Дв.", "pickup_radius": "Пд.",
	"dot_damage": "П", "summon_amount": "Пр.",
	"vampiric": "В",
}
const SURVIVAL_IDS := ["health_point", "defense", "dodge", "regeneration"]
const ACTION_NAMES := [
	"PauseResumeButton", "PauseSettingsButton", "PauseEndRunButton", "PauseMainMenuButton",
]
const DOSSIER_TOOLTIP_META := "dossier_tooltip_text"

var _errors := PackedStringArray()
var _tooltip_scroll_exercised := false


func _initialize() -> void:
	for viewport_size in TARGETS:
		await _validate_resolution(viewport_size)
	await _validate_summoner_target()
	await _validate_live_resize()
	if not _tooltip_scroll_exercised:
		_errors.append("No long tooltip exercised the physical gamepad scroll path.")
	if not _errors.is_empty():
		for error in _errors:
			push_error(error)
		quit(1)
		return
	print("SCRUM-983 Escape dossier passed 1152x648/720p/900p/1080p/2K geometry, content, tooltip, focus and live-resize gates.")
	quit(0)


func _validate_resolution(viewport_size: Vector2i) -> void:
	var fixture := await _open_fixture(viewport_size)
	var viewport := fixture["viewport"] as SubViewport
	var main := fixture["main"] as Node
	var pause := fixture["pause"] as Control
	var context := "%dx%d" % [viewport_size.x, viewport_size.y]
	if pause == null:
		_errors.append("%s: pause dossier did not open." % context)
		await _cleanup_fixture(viewport, main, context)
		return

	var contract := _expected_contract(Vector2(viewport_size))
	_assert_frame(pause, contract, context)
	_assert_reserve_masks(pause, viewport_size, contract, context)
	_assert_major_geometry(pause, contract, context)
	_assert_header_identity(pause, contract, context)
	_assert_semantic_stats(pause, viewport_size, contract, context)
	await _assert_focus_contract(pause, contract, context)
	_assert_action_styles(pause, context)
	await _cleanup_fixture(viewport, main, context)


func _validate_live_resize() -> void:
	var fixture := await _open_fixture(Vector2i(2560, 1440))
	var viewport := fixture["viewport"] as SubViewport
	var main := fixture["main"] as Node
	var pause := fixture["pause"] as Control
	viewport.size = Vector2i(1280, 720)
	await _settle()
	var contract := _expected_contract(Vector2(1280, 720))
	_assert_frame(pause, contract, "live 2560x1440 -> 1280x720")
	_assert_reserve_masks(pause, Vector2i(1280, 720), contract, "live 2560x1440 -> 1280x720")
	_assert_major_geometry(pause, contract, "live 2560x1440 -> 1280x720")
	_assert_header_identity(pause, contract, "live 2560x1440 -> 1280x720")
	var base_grid := pause.find_child("BaseStatsGrid", true, false) as GridContainer
	if base_grid == null or base_grid.columns != 2:
		_errors.append("live resize: BaseStatsGrid must keep the no-scroll two-column layout.")
	await _cleanup_fixture(viewport, main, "live 2560x1440 -> 1280x720")


func _validate_summoner_target() -> void:
	var fixture := await _open_fixture(Vector2i(1920, 1080), "druid", "summon_amulet")
	var viewport := fixture["viewport"] as SubViewport
	var main := fixture["main"] as Node
	var pause := fixture["pause"] as Control
	var context := "1920x1080 summoner"
	# FAN-1927: «Сила призыва» живёт каноническим чипом секции призыва и
	# показывает ФАКТИЧЕСКИЙ runtime-парк (max_summons с Лидерством/бонусом).
	var summon_chip := pause.find_child("DerivedStatChip_summon_amount", true, false) as Control
	var summon_name := pause.find_child("DerivedStatName_summon_amount", true, false) as Label
	var summon_value := pause.find_child("DerivedStatValue_summon_amount", true, false) as Label
	if summon_chip == null or summon_name == null or summon_value == null:
		_errors.append("%s: summon kit must expose canonical summon_amount chip." % context)
	else:
		var targets: Array[Control] = []
		_validate_stat_target(pause, summon_chip.name, summon_name.name, summon_value.name, _expected_contract(Vector2(1920, 1080))["inner"], context, targets)
		await _assert_single_tooltip_target(pause, summon_chip, _expected_contract(Vector2(1920, 1080))["inner"], context)
		if summon_value.text.strip_edges() == "" or not summon_value.text.strip_edges().is_valid_int():
			_errors.append("%s: summon chip must show the integer runtime pack, got '%s'." % [context, summon_value.text])
	# FAN-1927: generic attack_speed не потребляется SummonerWeapon-каденсом —
	# ось отсутствует у druid/summon_amulet.
	if pause.find_child("DerivedStatChip_attack_speed", true, false) != null:
		_errors.append("%s: attack_speed axis is dead for summon_amulet but rendered." % context)
	await _cleanup_fixture(viewport, main, context)


func _open_fixture(viewport_size: Vector2i, character_id := "berserk", weapon_id := "sword") -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await _settle()
	main.set("selected_character_id", character_id)
	main.set("selected_weapon_id", weapon_id)
	main.set("route_stage", 2)
	main.call("_start_combat")
	await _settle()
	main.ui._show_pause_menu(true)
	await _settle()
	return {
		"viewport": viewport,
		"main": main,
		"pause": main.find_child("PauseStatsMenuRoot", true, false) as Control,
	}


func _cleanup_fixture(viewport: SubViewport, main: Node, context: String) -> void:
	var main_ref: WeakRef = weakref(main) if main != null else null
	var viewport_ref: WeakRef = weakref(viewport) if viewport != null else null
	if main != null and is_instance_valid(main):
		main.queue_free()
	if viewport != null and is_instance_valid(viewport):
		viewport.queue_free()
	for _frame in range(4):
		await process_frame
	if main_ref != null and main_ref.get_ref() != null:
		_errors.append("%s: fixture Main leaked after queue_free." % context)
	if viewport_ref != null and viewport_ref.get_ref() != null:
		_errors.append("%s: fixture SubViewport leaked after queue_free." % context)


func _assert_frame(pause: Control, contract: Dictionary, context: String) -> void:
	var frame := pause.find_child("EscapeStatsPanelFrame", true, false) as PanelContainer
	if frame == null:
		_errors.append("%s: missing EscapeStatsPanelFrame." % context)
		return
	var style := frame.get_theme_stylebox("panel") as StyleBoxTexture
	if style == null or style.texture == null or style.draw_center:
		_errors.append("%s: frame must be a hollow StyleBoxTexture." % context)
		return
	if not style.texture.resource_path.ends_with(FRAME_PATH_SUFFIX):
		_errors.append("%s: frame uses %s." % [context, style.texture.resource_path])
	if style.texture_margin_left != 160.0 or style.texture_margin_top != 160.0 \
		or style.texture_margin_right != 160.0 or style.texture_margin_bottom != 160.0:
		_errors.append("%s: frame source margins must remain 160 on every edge." % context)
	if frame.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_errors.append("%s: decorative frame must ignore mouse input." % context)
	_assert_rect(frame.get_meta("gold_shell_content_rect", Rect2()) as Rect2, contract["safe"], "%s safe meta" % context)
	_assert_rect(frame.get_meta("dossier_inner_content_rect", Rect2()) as Rect2, contract["inner"], "%s inner meta" % context)
	var content := pause.find_child("DossierContentRoot", true, false) as Control
	if content == null or frame.get_index() <= content.get_index():
		_errors.append("%s: decorative frame must remain the final dossier layer." % context)


func _assert_reserve_masks(pause: Control, viewport_size: Vector2i, contract: Dictionary, context: String) -> void:
	var inner: Rect2 = contract["inner"]
	var content := pause.find_child("DossierContentRoot", true, false) as Control
	var frame := pause.find_child("EscapeStatsPanelFrame", true, false) as Control
	var expected := [
		Rect2(Vector2.ZERO, Vector2(viewport_size.x, inner.position.y)),
		Rect2(Vector2(0.0, inner.end.y), Vector2(viewport_size.x, viewport_size.y - inner.end.y)),
		Rect2(Vector2(0.0, inner.position.y), Vector2(inner.position.x, inner.size.y)),
		Rect2(Vector2(inner.end.x, inner.position.y), Vector2(viewport_size.x - inner.end.x, inner.size.y)),
	]
	var total_area := 0.0
	for index in range(expected.size()):
		var side: String = ["Top", "Bottom", "Left", "Right"][index]
		var mask := pause.find_child("DossierReserveMask%s" % side, true, false) as ColorRect
		if mask == null:
			_errors.append("%s: missing opaque %s reserve mask." % [context, side])
			continue
		_assert_rect(mask.get_global_rect(), expected[index], "%s %s reserve mask" % [context, side])
		if mask.color.a < 0.999 or mask.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			_errors.append("%s: %s reserve mask must be opaque and mouse-ignore." % [context, side])
		if content == null or frame == null or mask.get_index() >= content.get_index() or mask.get_index() >= frame.get_index():
			_errors.append("%s: %s reserve mask must render below dossier content and final frame." % [context, side])
		total_area += mask.get_global_rect().size.x * mask.get_global_rect().size.y
	var expected_area := float(viewport_size.x * viewport_size.y) - inner.size.x * inner.size.y
	if absf(total_area - expected_area) > 1.0:
		_errors.append("%s: reserve masks cover %.1fpx², expected viewport-minus-inner %.1fpx²." % [context, total_area, expected_area])


func _assert_major_geometry(pause: Control, contract: Dictionary, context: String) -> void:
	var header := pause.find_child("DossierHeader", true, false) as Control
	var body := pause.find_child("DossierBody", true, false) as Control
	var hero := pause.find_child("HeroCard", true, false) as Control
	var right := pause.find_child("DerivedStatsPanel", true, false) as Control
	var actions := pause.find_child("PauseControlButtons", true, false) as GridContainer
	if header == null or body == null or hero == null or right == null or actions == null:
		_errors.append("%s: incomplete header/body/footer hierarchy." % context)
		return
	_assert_rect(header.get_global_rect(), contract["header"], "%s header" % context)
	_assert_rect(body.get_global_rect(), contract["body"], "%s body" % context)
	_assert_rect(hero.get_global_rect(), contract["hero"], "%s hero" % context)
	_assert_rect(right.get_global_rect(), contract["derived"], "%s derived" % context)
	_assert_rect(actions.get_global_rect(), contract["actions"], "%s actions" % context)
	var actions_vertical := bool(contract["actions_vertical"])
	if actions.columns != (1 if actions_vertical else 4):
		_errors.append("%s: action topology columns %d do not match %s contract." % [context, actions.columns, "vertical" if actions_vertical else "horizontal"])
	for node in [header, hero, right, actions]:
		_assert_inside(node.get_global_rect(), contract["inner"], "%s %s" % [context, node.name])
	if hero.get_global_rect().intersects(right.get_global_rect()) or body.get_global_rect().intersects(actions.get_global_rect()):
		_errors.append("%s: body siblings/footer overlap." % context)
	var buttons: Array[Button] = []
	for index in range(ACTION_NAMES.size()):
		var button_name: String = ACTION_NAMES[index]
		var button := pause.find_child(button_name, true, false) as Button
		if button == null:
			_errors.append("%s: missing %s." % [context, button_name])
			continue
		buttons.append(button)
		_assert_inside(button.get_global_rect(), contract["inner"], "%s %s" % [context, button_name])
		var action_size: Vector2 = contract["action_size"]
		var expected_position := (contract["actions"] as Rect2).position
		if actions_vertical:
			expected_position.y += index * (action_size.y + float(contract["action_gap"]))
		else:
			expected_position.x += index * (action_size.x + float(contract["action_gap"]))
		_assert_rect(button.get_global_rect(), Rect2(expected_position, action_size), "%s %s exact action" % [context, button_name])
		var aspect_error := absf(button.size.x / button.size.y - 380.0 / 104.0) / (380.0 / 104.0)
		if aspect_error > 0.02:
			_errors.append("%s: %s aspect %.4f clips the 380x104 main-menu ornament." % [context, button_name, button.size.x / button.size.y])
	for i in range(buttons.size()):
		for j in range(i + 1, buttons.size()):
			if buttons[i].get_global_rect().intersects(buttons[j].get_global_rect()):
				_errors.append("%s: %s overlaps %s." % [context, buttons[i].name, buttons[j].name])
	var hero_scroll := pause.find_child("HeroCardScroll", true, false) as ScrollContainer
	var derived_scroll := pause.find_child("DerivedStatsScroll", true, false) as ScrollContainer
	for scroll in [hero_scroll, derived_scroll]:
		if scroll == null or scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED \
			or scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			_errors.append("%s: dossier content containers must expose no scrollbars." % context)
			continue
		var content := scroll.get_child(0) as Control if scroll.get_child_count() > 0 else null
		if content == null or content.get_combined_minimum_size().y > scroll.size.y + 1.0:
			_errors.append("%s: %s hides overflow instead of fitting content (content %.1f, viewport %.1f)." % [context, scroll.name, content.get_combined_minimum_size().y if content != null else -1.0, scroll.size.y])


func _assert_header_identity(pause: Control, contract: Dictionary, context: String) -> void:
	var summary := pause.find_child("DossierHeaderSummary", true, false) as Label
	if summary == null:
		_errors.append("%s: missing DossierHeaderSummary." % context)
		return
	var expected := "Берсерк · Двуручный меч"
	if summary.text != expected:
		_errors.append("%s: header identity '%s' != full '%s'." % [context, summary.text, expected])
	if summary.text.contains("…") or summary.text.ends_with("..."):
		_errors.append("%s: header identity must never contain an ellipsis." % context)
	if summary.clip_text or summary.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
		_errors.append("%s: header identity must disable clipping/overrun trimming." % context)
	var rendered_width := _rendered_width(summary, summary.text)
	if summary.size.x + 0.5 < rendered_width:
		_errors.append("%s: full header identity needs %.1fpx but its content lane is %.1fpx." % [context, rendered_width, summary.size.x])
	_assert_inside(summary.get_global_rect(), contract["header"], "%s full header identity lane" % context)
	var right_reserve := (contract["header"] as Rect2).end.x - summary.get_global_rect().end.x
	if right_reserve < 23.5:
		_errors.append("%s: full header identity leaves only %.1fpx at the right safe edge, expected 24px." % [context, right_reserve])


func _assert_semantic_stats(pause: Control, viewport_size: Vector2i, contract: Dictionary, context: String) -> void:
	var base_list := pause.find_child("BaseStatsList", true, false) as VBoxContainer
	var base_grid := pause.find_child("BaseStatsGrid", true, false) as GridContainer
	if base_list == null or base_grid == null:
		_errors.append("%s: missing semantic BaseStatsList/BaseStatsGrid." % context)
		return
	if base_grid.get_child_count() != BASE_IDS.size():
		_errors.append("%s: BaseStatsGrid has %d rows, expected %d real rows." % [context, base_grid.get_child_count(), BASE_IDS.size()])
	if base_list.find_children("BaseStatsCompatibilitySlot_*", "Control", true, false).size() != 0:
		_errors.append("%s: compatibility/dummy stat nodes are forbidden." % context)
	var expected_columns := 2
	if base_grid.columns != expected_columns:
		_errors.append("%s: BaseStatsGrid columns %d != %d." % [context, base_grid.columns, expected_columns])
	var stat_targets: Array[Control] = []
	for stat_id in BASE_IDS:
		_validate_stat_target(pause, "BaseStatRow_%s" % stat_id, "BaseStatName_%s" % stat_id, "BaseStatValue_%s" % stat_id, contract["inner"], context, stat_targets)
		if viewport_size == Vector2i(1920, 1080):
			var base_name := pause.find_child("BaseStatName_%s" % stat_id, true, false) as Label
			if base_name != null:
				var font := base_name.get_theme_font("font")
				var short_name_width := font.get_string_size(
					"Сила", HORIZONTAL_ALIGNMENT_LEFT, -1.0,
					base_name.get_theme_font_size("font_size")
				).x
				if base_name.size.x + 0.5 < short_name_width:
					_errors.append("%s: %s name lane %.1fpx cannot render even short localized label 'Сила' (%.1fpx)." % [context, stat_id, base_name.size.x, short_name_width])
	for stat_id in SURVIVAL_IDS:
		_validate_stat_target(pause, "SurvivalStatRow_%s" % stat_id, "SurvivalStatName_%s" % stat_id, "SurvivalStatValue_%s" % stat_id, contract["inner"], context, stat_targets)
	for stat_id in DERIVED_IDS:
		_validate_stat_target(pause, "DerivedStatChip_%s" % stat_id, "DerivedStatName_%s" % stat_id, "DerivedStatValue_%s" % stat_id, contract["inner"], context, stat_targets)
		var compact_name := pause.find_child("DerivedStatName_%s" % stat_id, true, false) as Label
		var compact_value := pause.find_child("DerivedStatValue_%s" % stat_id, true, false) as Label
		var expected_alias := str(DERIVED_ULTRA_TIGHT_LABELS.get(stat_id, DERIVED_TIGHT_LABELS[stat_id])) if viewport_size.y <= 648 else (str(DERIVED_TIGHT_LABELS.get(stat_id, DERIVED_COMPACT_LABELS[stat_id])) if viewport_size.y <= 900 else str(DERIVED_COMPACT_LABELS[stat_id]))
		if compact_name == null or compact_name.text != expected_alias:
			_errors.append("%s: %s compact label must be deterministic alias '%s'." % [context, stat_id, expected_alias])
		elif compact_name.size.x + 0.5 < _rendered_width(compact_name, expected_alias):
			_errors.append("%s: %s alias '%s' needs %.1fpx but lane is %.1fpx." % [context, stat_id, expected_alias, _rendered_width(compact_name, expected_alias), compact_name.size.x])
		if compact_value != null and compact_value.size.x + 0.5 < _rendered_width(compact_value, compact_value.text):
			_errors.append("%s: %s value '%s' needs %.1fpx but lane is %.1fpx." % [context, stat_id, compact_value.text, _rendered_width(compact_value, compact_value.text), compact_value.size.x])
		if viewport_size == Vector2i(1920, 1080) and compact_value != null and compact_value.custom_minimum_size.x > 64.0:
			_errors.append("%s: %s value reserve %.1fpx steals the readable alias lane." % [context, stat_id, compact_value.custom_minimum_size.x])
	var attack_speed := pause.find_child("DerivedStatValue_attack_speed", true, false) as Label
	var crit_chance := pause.find_child("DerivedStatValue_crit_chance", true, false) as Label
	var crit_power := pause.find_child("DerivedStatValue_crit_damage", true, false) as Label
	var damage_percent := pause.find_child("DerivedStatValue_damage", true, false) as Label
	if attack_speed == null or not attack_speed.text.ends_with("/с"):
		_errors.append("%s: attack speed must use localized /с units." % context)
	if crit_chance == null or not crit_chance.text.ends_with("%"):
		_errors.append("%s: crit chance must use percent units." % context)
	if crit_power == null or not crit_power.text.begins_with("×"):
		_errors.append("%s: crit multiplier must use × prefix." % context)
	# FAN-1927: ось «Увеличение урона» показывает набранный процент в СВОЕЙ
	# единице, а не дублирует значение канала.
	if damage_percent == null or not damage_percent.text.ends_with("%"):
		_errors.append("%s: damage axis must use its own percent unit." % context)
	# FAN-1887/FAN-1927: снятые оси и derived-алиасы не рисуются в досье.
	for removed_id in REMOVED_DERIVED_IDS:
		if pause.find_child("DerivedStatChip_%s" % removed_id, true, false) != null:
			_errors.append("%s: removed internal axis %s is still rendered in the dossier." % [context, removed_id])
	# FAN-1927: ineligible оси базовой fixture (berserk/sword) отсутствуют —
	# class/weapon-недоступная ось не показывается «этому герою».
	for absent_id in BERSERK_INELIGIBLE_AXES:
		if pause.find_child("DerivedStatChip_%s" % absent_id, true, false) != null:
			_errors.append("%s: axis %s is ineligible for berserk/sword but rendered." % [context, absent_id])


func _validate_stat_target(pause: Control, row_name: String, label_name: String, value_name: String, inner: Rect2, context: String, out: Array[Control]) -> void:
	var row := pause.find_child(row_name, true, false) as Control
	var label := pause.find_child(label_name, true, false) as Label
	var value := pause.find_child(value_name, true, false) as Label
	if row == null or label == null or value == null:
		_errors.append("%s: incomplete %s semantic row." % [context, row_name])
		return
	if row.focus_mode != Control.FOCUS_ALL:
		_errors.append("%s: %s is not keyboard/gamepad focusable." % [context, row_name])
	var tooltip_text := str(row.get_meta(DOSSIER_TOOLTIP_META, ""))
	if tooltip_text.strip_edges() == "" or not tooltip_text.contains("Формула / источник:") or not tooltip_text.contains("Влияет:"):
		_errors.append("%s: %s lacks complete StatFormulas tooltip data." % [context, row_name])
	if row.tooltip_text != "":
		_errors.append("%s: %s must disable the unbounded engine/global hover popup." % [context, row_name])
	if label.text.strip_edges() == "" or value.text.strip_edges() == "":
		_errors.append("%s: %s has an empty compact label/value." % [context, row_name])
	var visible_rect := _clipped_visible_rect(row)
	if visible_rect.has_area():
		_assert_inside(visible_rect, inner, "%s %s visible rect" % [context, row_name])
	out.append(row)


func _assert_focus_contract(pause: Control, contract: Dictionary, context: String) -> void:
	var resume := pause.find_child("PauseResumeButton", true, false) as Button
	await process_frame
	if pause.get_viewport().gui_get_focus_owner() != resume:
		_errors.append("%s: initial focus is not Continue." % context)
	var required: Array[Control] = []
	for button_name in ACTION_NAMES:
		required.append(pause.find_child(button_name, true, false) as Control)
	for stat_id in BASE_IDS:
		required.append(pause.find_child("BaseStatRow_%s" % stat_id, true, false) as Control)
	for stat_id in SURVIVAL_IDS:
		required.append(pause.find_child("SurvivalStatRow_%s" % stat_id, true, false) as Control)
	for stat_id in DERIVED_IDS:
		required.append(pause.find_child("DerivedStatChip_%s" % stat_id, true, false) as Control)
	var reachable := _focus_reachable(resume)
	for target in required:
		if target == null or not reachable.has(target.get_instance_id()):
			_errors.append("%s: focus graph cannot reach %s." % [context, target.name if target != null else "missing target"])
	var base_grid := pause.find_child("BaseStatsGrid", true, false) as GridContainer
	if base_grid != null and base_grid.columns == 2:
		var rows: Array[Control] = []
		for child in base_grid.get_children():
			rows.append(child as Control)
		for row_index in range(0, rows.size(), 2):
			var left := rows[row_index]
			var right := rows[row_index + 1]
			if _resolved_neighbor(left, left.focus_neighbor_right) != right or _resolved_neighbor(right, right.focus_neighbor_left) != left:
				_errors.append("%s: base-stat left/right focus does not cross its geometric row." % context)
		for row_index in range(2, rows.size()):
			var current := rows[row_index]
			var expected_up := rows[row_index - 2]
			if _resolved_neighbor(current, current.focus_neighbor_top) != expected_up:
				_errors.append("%s: base-stat up focus changes logical column at %s." % [context, current.name])
	var tooltip := pause.find_child("DossierFocusTooltip", true, false) as PanelContainer
	var tooltip_scroll := pause.find_child("DossierFocusTooltipScroll", true, false) as ScrollContainer
	if tooltip_scroll == null or tooltip_scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		_errors.append("%s: focus tooltip must use a vertically clipped scroll viewport." % context)
	for focus_target in required.slice(ACTION_NAMES.size()):
		if focus_target == null:
			continue
		await _assert_single_tooltip_target(pause, focus_target, contract["inner"], context)

	# The longest available text must either fit or scroll through a physical
	# gamepad shoulder path while focus remains on the stat row.
	var longest_target: Control = null
	for focus_target in required.slice(ACTION_NAMES.size()):
		if focus_target != null and (longest_target == null or str(focus_target.get_meta(DOSSIER_TOOLTIP_META, "")).length() > str(longest_target.get_meta(DOSSIER_TOOLTIP_META, "")).length()):
			longest_target = focus_target
	if longest_target != null and tooltip_scroll != null:
		await _assert_single_tooltip_target(pause, longest_target, contract["inner"], "%s longest" % context)
		var scroll_bar := tooltip_scroll.get_v_scroll_bar()
		if scroll_bar.max_value > scroll_bar.page + 1.0:
			var shoulder := InputEventJoypadButton.new()
			shoulder.button_index = JOY_BUTTON_RIGHT_SHOULDER
			shoulder.pressed = true
			pause.get_viewport().push_input(shoulder, true)
			await process_frame
			if tooltip_scroll.scroll_vertical <= 0:
				_errors.append("%s: right shoulder does not scroll long focus tooltip." % context)
			else:
				_tooltip_scroll_exercised = true
		elif tooltip.find_child("DossierFocusTooltipLabel", true, false).get_combined_minimum_size().y > tooltip_scroll.size.y + 1.0:
			_errors.append("%s: longest tooltip neither fits nor exposes a scroll range." % context)

	# Exercise real pointer hover. Stat rows have engine tooltip_text disabled,
	# so mouse and focus must resolve the same bounded internal panel.
	var hover_target := required[ACTION_NAMES.size()] as Control
	if hover_target != null:
		# Focus may keep its tooltip open while the pointer is elsewhere. The
		# dossier itself is now no-scroll, so wheel input must leave both the
		# dossier and the focus-only tooltip at zero.
		hover_target.grab_focus()
		for _frame in range(3):
			await process_frame
		var hero_scroll_for_wheel := pause.find_child("HeroCardScroll", true, false) as ScrollContainer
		var outside_target := pause.find_child("DossierTitleChip", true, false) as Control
		if hero_scroll_for_wheel != null and outside_target != null:
			hero_scroll_for_wheel.scroll_vertical = 0
			tooltip_scroll.scroll_vertical = 0
			for _frame in range(3):
				await process_frame
			var outside_motion := InputEventMouseMotion.new()
			outside_motion.position = _clipped_visible_rect(outside_target).get_center()
			outside_motion.global_position = outside_motion.position
			pause.get_viewport().push_input(outside_motion, true)
			for _frame in range(2):
				await process_frame
			var dossier_wheel := InputEventMouseButton.new()
			dossier_wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
			dossier_wheel.pressed = true
			dossier_wheel.factor = 1.0
			dossier_wheel.position = outside_motion.position
			dossier_wheel.global_position = outside_motion.position
			pause.get_viewport().push_input(dossier_wheel, true)
			for _frame in range(10):
				await process_frame
			if hero_scroll_for_wheel.scroll_vertical != 0:
				_errors.append("%s: no-scroll hero dossier moved after wheel input." % context)
			if tooltip_scroll.scroll_vertical != 0:
				_errors.append("%s: focus-only tooltip hijacks wheel after pointer leaves stat rows." % context)

		hover_target.grab_focus()
		for _frame in range(3):
			await process_frame
		resume.grab_focus()
		await process_frame
		var motion := InputEventMouseMotion.new()
		motion.position = _clipped_visible_rect(hover_target).get_center()
		motion.global_position = motion.position
		pause.get_viewport().push_input(motion, true)
		for _frame in range(3):
			await process_frame
		var hovered := pause.get_viewport().gui_get_hovered_control()
		if not _is_control_within(hovered, hover_target):
			_errors.append("%s: physical pointer did not hover %s." % [context, hover_target.name])
		if tooltip == null or not tooltip.visible or str(tooltip.get_meta("dossier_anchor_name", "")) != str(hover_target.name):
			_errors.append("%s: mouse hover did not use bounded dossier tooltip path." % context)
		elif tooltip.get_global_rect().size.x > 430.1 or tooltip.get_global_rect().size.y > 288.1:
			_errors.append("%s: mouse-hover tooltip exceeds 430x288." % context)
		elif tooltip_scroll != null and tooltip_scroll.get_v_scroll_bar().max_value > tooltip_scroll.get_v_scroll_bar().page + 1.0:
			var wheel := InputEventMouseButton.new()
			wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
			wheel.pressed = true
			wheel.position = motion.position
			wheel.global_position = motion.position
			pause.get_viewport().push_input(wheel, true)
			await process_frame
			if tooltip_scroll.scroll_vertical <= 0:
				_errors.append("%s: mouse wheel cannot reach the hover tooltip tail." % context)

	# Move both content columns away from their initial scroll position, then
	# focus each footer action so its deferred neighbor rebuild sees live clipping.
	var hero_scroll := pause.find_child("HeroCardScroll", true, false) as ScrollContainer
	var derived_scroll := pause.find_child("DerivedStatsScroll", true, false) as ScrollContainer
	if hero_scroll != null:
		hero_scroll.scroll_vertical = int(hero_scroll.get_v_scroll_bar().max_value)
	if derived_scroll != null:
		derived_scroll.scroll_vertical = int(derived_scroll.get_v_scroll_bar().max_value)
	for _frame in range(4):
		await process_frame
	for button_name in ACTION_NAMES:
		var button := pause.find_child(button_name, true, false) as Button
		button.grab_focus()
		for _frame in range(3):
			await process_frame
		var up_target := _resolved_neighbor(button, button.focus_neighbor_top)
		if up_target == null or not _clipped_visible_rect(up_target).has_area():
			_errors.append("%s: %s Up neighbor is stale/offscreen after live scroll." % [context, button_name])
	resume.grab_focus()
	for _frame in range(3):
		await process_frame
	var physical_target := _resolved_neighbor(resume, resume.focus_neighbor_top)
	var up_event := InputEventAction.new()
	up_event.action = "ui_up"
	up_event.pressed = true
	pause.get_viewport().push_input(up_event, true)
	for _frame in range(3):
		await process_frame
	if physical_target == null or pause.get_viewport().gui_get_focus_owner() != physical_target or not _clipped_visible_rect(physical_target).has_area():
		_errors.append("%s: physical footer Up did not land on its clipped-visible neighbor." % context)
	resume.grab_focus()
	await process_frame


func _assert_single_tooltip_target(pause: Control, focus_target: Control, inner: Rect2, context: String) -> void:
	var tooltip := pause.find_child("DossierFocusTooltip", true, false) as PanelContainer
	var tooltip_label := pause.find_child("DossierFocusTooltipLabel", true, false) as Label
	focus_target.grab_focus()
	for _frame in range(4):
		await process_frame
	if tooltip == null or not tooltip.visible or tooltip_label == null \
		or not tooltip_label.text.contains("Формула / источник:") or not tooltip_label.text.contains("Влияет:"):
		_errors.append("%s: %s focus does not expose its complete tooltip." % [context, focus_target.name])
		return
	var tooltip_rect := tooltip.get_global_rect()
	if tooltip_rect.size.x > 430.1 or tooltip_rect.size.y > 288.1:
		_errors.append("%s: %s tooltip %s exceeds 430x288." % [context, focus_target.name, str(tooltip_rect.size)])
	else:
		_assert_inside(tooltip_rect, inner, "%s %s focus tooltip" % [context, focus_target.name])
	if not _clipped_visible_rect(focus_target).has_area():
		_errors.append("%s: focus-follow did not reveal %s in its scroll viewport." % [context, focus_target.name])


func _is_control_within(candidate: Control, ancestor: Control) -> bool:
	var current: Node = candidate
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false


func _rendered_width(label: Label, text: String) -> float:
	return label.get_theme_font("font").get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		label.get_theme_font_size("font_size")
	).x


func _resolved_neighbor(source: Control, path: NodePath) -> Control:
	if source == null or path.is_empty():
		return null
	return source.get_node_or_null(path) as Control


func _focus_reachable(start: Control) -> Dictionary:
	var result := {}
	var queue: Array[Control] = [start]
	while not queue.is_empty():
		var current := queue.pop_front() as Control
		if current == null or result.has(current.get_instance_id()):
			continue
		result[current.get_instance_id()] = true
		for path in [current.focus_neighbor_left, current.focus_neighbor_right, current.focus_neighbor_top, current.focus_neighbor_bottom]:
			if path.is_empty():
				continue
			var neighbor := current.get_node_or_null(path) as Control
			if neighbor != null and not result.has(neighbor.get_instance_id()):
				queue.append(neighbor)
	return result


func _assert_action_styles(pause: Control, context: String) -> void:
	for index in range(ACTION_NAMES.size()):
		var button := pause.find_child(ACTION_NAMES[index], true, false) as Button
		if button == null:
			continue
		if str(button.get_meta("ui_button_family", "")) != "text/main_menu_380x104":
			_errors.append("%s: %s is not tagged with the main-menu button family." % [context, button.name])
		var scale := minf(button.custom_minimum_size.x / 380.0, button.custom_minimum_size.y / 104.0)
		var expected_texture_margins := Vector4(54.0, 21.0, 54.0, 21.0) * scale
		var expected_content_margins := Vector4(69.0, 21.0, 69.0, 21.0) * scale
		var rendered_text_width := button.get_theme_font("font").get_string_size(
			button.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, button.get_theme_font_size("font_size")
		).x
		if rendered_text_width > button.size.x - expected_content_margins.x - expected_content_margins.z + 1.0:
			_errors.append("%s: %s label does not fit the main-menu content lane." % [context, button.name])
		for state in ["normal", "hover", "focus", "pressed", "disabled"]:
			var style := button.get_theme_stylebox(state) as StyleBoxTexture
			if style == null:
				_errors.append("%s: %s missing %s texture state." % [context, button.name, state])
				continue
			var expected_suffix := "ui_btn_text_unique_main_menu_380x104_%s.png" % state
			if style.texture == null or not style.texture.resource_path.ends_with(expected_suffix):
				_errors.append("%s: %s %s does not use %s." % [context, button.name, state, expected_suffix])
			if style.modulate_color != Color.WHITE:
				_errors.append("%s: %s %s adds a non-main-menu tint." % [context, button.name, state])
			var actual_texture_margins := Vector4(style.texture_margin_left, style.texture_margin_top, style.texture_margin_right, style.texture_margin_bottom)
			var actual_content_margins := Vector4(style.content_margin_left, style.content_margin_top, style.content_margin_right, style.content_margin_bottom)
			if not actual_texture_margins.is_equal_approx(expected_texture_margins):
				_errors.append("%s: %s %s texture margins %s are not uniformly scaled %s." % [context, button.name, state, actual_texture_margins, expected_texture_margins])
			if not actual_content_margins.is_equal_approx(expected_content_margins):
				_errors.append("%s: %s %s content margins %s are not uniformly scaled %s." % [context, button.name, state, actual_content_margins, expected_content_margins])


func _expected_contract(viewport_size: Vector2) -> Dictionary:
	var margin_x := roundf(160.0 * viewport_size.x / 1536.0)
	var margin_y := roundf(160.0 * viewport_size.y / 1024.0)
	var safe := Rect2(Vector2(margin_x, margin_y), viewport_size - Vector2(margin_x * 2.0, margin_y * 2.0))
	var compact := viewport_size.y <= 900.0
	var large := viewport_size.y >= 1200.0
	var reserve := 32.0 if large else 24.0
	var inner := safe.grow(-reserve)
	var header_h := (48.0 if viewport_size.y >= 900.0 else 46.0) if compact else (104.0 if large else 72.0)
	var header_gap := 4.0 if compact else (24.0 if large else 12.0)
	var footer_bottom := 4.0 if compact else (16.0 if large else 12.0)
	var hero_w := 348.0 if compact else (520.0 if large else 420.0)
	var column_gap := 12.0 if compact else (24.0 if large else 20.0)
	var body_y := inner.position.y + header_h + header_gap
	var action_h := 60.0 if viewport_size.y <= 648.0 else (72.0 if compact else (104.0 if large else 88.0))
	var action_w := 219.0 if viewport_size.y <= 648.0 else (263.0 if compact else (380.0 if large else 320.0))
	var action_gap := (6.0 if viewport_size.y <= 648.0 else (10.0 if viewport_size.y >= 900.0 else 8.0)) if compact else (20.0 if large else 16.0)
	var actions: Rect2
	var body: Rect2
	if compact:
		var body_h := inner.end.y - footer_bottom - body_y
		var action_total_h := action_h * 4.0 + action_gap * 3.0
		actions = Rect2(Vector2(inner.end.x - action_w, body_y + maxf(0.0, (body_h - action_total_h) * 0.5)), Vector2(action_w, action_total_h))
		body = Rect2(Vector2(inner.position.x, body_y), Vector2(inner.size.x - column_gap - action_w, body_h))
	else:
		var footer_gap := 24.0 if large else 12.0
		var action_total_w := action_w * 4.0 + action_gap * 3.0
		actions = Rect2(Vector2(inner.get_center().x - action_total_w * 0.5, inner.end.y - footer_bottom - action_h), Vector2(action_total_w, action_h))
		body = Rect2(Vector2(inner.position.x, body_y), Vector2(inner.size.x, actions.position.y - footer_gap - body_y))
	return {
		"safe": safe,
		"inner": inner,
		"header": Rect2(inner.position, Vector2(inner.size.x, header_h)),
		"body": body,
		"hero": Rect2(body.position, Vector2(hero_w, body.size.y)),
		"derived": Rect2(Vector2(body.position.x + hero_w + column_gap, body.position.y), Vector2(body.size.x - hero_w - column_gap, body.size.y)),
		"actions": actions,
		"action_size": Vector2(action_w, action_h),
		"action_gap": action_gap,
		"actions_vertical": compact,
	}


func _clipped_visible_rect(control: Control) -> Rect2:
	var rect := control.get_global_rect()
	var ancestor := control.get_parent()
	while ancestor != null:
		var ancestor_control := ancestor as Control
		if ancestor_control != null and (ancestor_control.clip_contents or ancestor_control is ScrollContainer):
			rect = rect.intersection(ancestor_control.get_global_rect())
		ancestor = ancestor.get_parent()
	return rect


func _assert_rect(actual: Rect2, expected: Rect2, label: String) -> void:
	if actual.position.distance_to(expected.position) > 1.1 or actual.size.distance_to(expected.size) > 1.1:
		_errors.append("%s rect %s != %s." % [label, str(actual), str(expected)])


func _assert_inside(rect: Rect2, outer: Rect2, label: String) -> void:
	if rect.has_area() and not outer.grow(1.0).encloses(rect):
		_errors.append("%s rect %s escapes %s." % [label, str(rect), str(outer)])


func _settle() -> void:
	for _frame in range(10):
		await process_frame
