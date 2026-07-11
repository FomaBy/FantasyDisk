extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const VIEWPORTS := [
	Vector2i(1152, 648),
	Vector2i(1280, 720),
	Vector2i(1536, 864),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const PREVIEW_MIN_SIZE := 320.0
# SCRUM-882: CTA «Выбрать» переехал в низ левой колонны — на 720p вертикальный
# бюджет делится с плитой CTA и степпером возвышения (≥42px), портрет ужимается.
const PREVIEW_MIN_SIZE_720 := 270.0
const PREVIEW_MIN_SIZE_648 := 240.0
const SLOT_MIN_SIZE := 180.0
const SLOT_MIN_SIZE_720 := 132.0
const SLOT_MIN_SIZE_648 := 116.0
const CHOOSE_PLATE_RATIO := 380.0 / 104.0
const SLOT_BASELINE_TOLERANCE := 3.0
const PREVIEW_VISIBLE_MIN_RATIO := 0.68
const SLOT_VISIBLE_HEIGHT_MIN_RATIO := 0.48
const LABEL_MIN_HEIGHT := 24.0


func _initialize() -> void:
	for viewport_size in VIEWPORTS:
		await _assert_layout_at_size(viewport_size)
	await _assert_directional_preview("berserk")
	await _assert_directional_preview("assassin")
	await _assert_directional_preview("chemist")
	await _assert_directional_preview("dark_mage")
	await _assert_directional_preview("biologist")
	await _assert_directional_preview("doctor")
	await _assert_directional_preview("druid")
	await _assert_directional_preview("elementalist")
	await _assert_directional_preview("engineer")
	await _assert_directional_preview("guitarist")
	await _assert_directional_preview("knight")
	await _assert_directional_preview("robot")
	await _assert_directional_preview("ranger")
	await _assert_directional_preview("sniper")
	await _assert_directional_preview("soldier")
	await _assert_directional_preview("thief")
	print("Hero Select PixelLab layout smoke test passed.")
	quit(0)


func _assert_layout_at_size(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame

	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await process_frame
	main.set("selected_character_id", "berserk")
	main.call("_show_character_select")
	await process_frame
	await process_frame

	# SCRUM-879: единый атлас-стиль — фон-зал героев вместо чёрной заливки.
	var bg := main.find_child("UnifiedBackground_hero_select", true, false) as TextureRect
	if bg == null or bg.texture == null:
		_fail("Expected Hero Select to use the unified hero hall background at %s." % str(viewport_size))
		return
	if bg.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_COVERED or bg.expand_mode != TextureRect.EXPAND_IGNORE_SIZE:
		_fail("Expected unified Hero Select background to cover the viewport without axis stretch at %s." % str(viewport_size))
		return
	if main.find_child("HS4BlackBackground", true, false) != null:
		_fail("Hero Select must not keep the legacy pure black backdrop at %s." % str(viewport_size))
		return
	var unified_frame := main.find_child("HeroSelectFrame", true, false) as Panel
	if unified_frame == null:
		_fail("Expected HeroSelectFrame hollow border overlay at %s." % str(viewport_size))
		return
	var unified_frame_style := unified_frame.get_theme_stylebox("panel") as StyleBoxTexture
	if unified_frame_style == null or unified_frame_style.texture == null:
		_fail("Expected HeroSelectFrame to use a StyleBoxTexture border at %s." % str(viewport_size))
		return
	if unified_frame_style.draw_center:
		_fail("Expected HeroSelectFrame border to keep draw_center disabled at %s." % str(viewport_size))
		return
	if not unified_frame_style.texture.resource_path.ends_with("meta40/frame_border.png"):
		_fail("Expected HeroSelectFrame to use the meta40 frame_border asset at %s, got %s." % [str(viewport_size), unified_frame_style.texture.resource_path])
		return
	if main.find_child("HS4Radar", true, false) != null or main.find_child("HS4RadarFrame", true, false) != null:
		_fail("Hero Select must not render the old stat radar/windrose at %s." % str(viewport_size))
		return
	if main.find_child("HS4PixelLabBackground", true, false) != null:
		_fail("Hero Select must not render the old PixelLab background at %s." % str(viewport_size))
		return

	var portrait := main.find_child("HS4Portrait", true, false) as TextureRect
	var portrait_frame := main.find_child("HS4PortraitFrame", true, false) as Control
	if portrait == null or portrait.texture == null:
		_fail("Expected HS4Portrait texture at %s." % str(viewport_size))
		return
	if portrait_frame == null:
		_fail("Expected HS4PortraitFrame at %s." % str(viewport_size))
		return
	var portrait_frame_rect := portrait_frame.get_global_rect()
	var preview_min := PREVIEW_MIN_SIZE if viewport_size.y >= 864 else (PREVIEW_MIN_SIZE_648 if viewport_size.y <= 648 else PREVIEW_MIN_SIZE_720)
	if portrait_frame_rect.size.x < preview_min or portrait_frame_rect.size.y < preview_min:
		_fail("Expected HS4PortraitFrame to use enlarged footprint at %s, got %s." % [str(viewport_size), str(portrait_frame_rect.size)])
		return
	var portrait_visible_rect := _visible_alpha_global_rect(portrait)
	if portrait_visible_rect.size.y < portrait_frame_rect.size.y * PREVIEW_VISIBLE_MIN_RATIO:
		_fail("Expected selected preview visible silhouette to be enlarged at %s, got visible %s in frame %s." % [str(viewport_size), str(portrait_visible_rect), str(portrait_frame_rect)])
		return
	if not portrait_frame_rect.grow(4.0).encloses(portrait_visible_rect):
		_fail("Expected selected preview visible silhouette to stay inside clipped frame at %s, got visible %s frame %s." % [str(viewport_size), str(portrait_visible_rect), str(portrait_frame_rect)])
		return
	# SCRUM-879: пьедестал-подиум под героем — аспект-бокс 676:148 у низа фрейма,
	# герой floor-align на верхнюю площадку (верх бокса + 22% высоты).
	var pedestal := main.find_child("HS4Pedestal", true, false) as TextureRect
	if pedestal == null or pedestal.texture == null:
		_fail("Expected HS4Pedestal dais under the hero portrait at %s." % str(viewport_size))
		return
	var pedestal_rect := pedestal.get_global_rect()
	var pedestal_expected_ratio := 676.0 / 148.0
	if pedestal_rect.size.y <= 0.0 or absf(pedestal_rect.size.x / pedestal_rect.size.y - pedestal_expected_ratio) > pedestal_expected_ratio * 0.02:
		_fail("Expected HS4Pedestal box to keep the 676:148 dais aspect at %s, got %s." % [str(viewport_size), str(pedestal_rect.size)])
		return
	if not portrait_frame_rect.grow(2.0).encloses(pedestal_rect):
		_fail("Expected HS4Pedestal to stay inside the portrait frame at %s, got %s in %s." % [str(viewport_size), str(pedestal_rect), str(portrait_frame_rect)])
		return
	var preview_expected_bottom := pedestal_rect.position.y + roundf(pedestal_rect.size.y * 0.22)
	if absf(portrait_visible_rect.end.y - preview_expected_bottom) > 4.0:
		_fail("Expected selected preview visible bottom to sit on the pedestal top platform at %s; got %.2f vs %.2f." % [str(viewport_size), portrait_visible_rect.end.y, preview_expected_bottom])
		return

	var ascension := main.find_child("HS4AscensionFrame", true, false) as Control
	var choose := main.find_child("HS4ChooseButton", true, false) as Button
	var asc_mods := main.find_child("AscensionModsLabel", true, false) as Label
	var asc_value := main.find_child("HS4AscensionValue", true, false) as Label
	if ascension == null or choose == null or asc_mods == null or asc_value == null \
			or not asc_value.text.begins_with("Возвышение ") or asc_value.text.contains("/") \
			or asc_mods.visible:
		_fail("Expected centered tooltip-only Ascension chooser at %s." % str(viewport_size))
		return

	# SCRUM-887/951: фиксированная зона характеристик у правого края досье,
	# без скролла. 720p reflows to 2x4 so names/values remain visible; larger
	# targets retain the original single vertical column.
	var dossier_frame := main.find_child("HS4DossierFrame", true, false) as Control
	if dossier_frame == null:
		_fail("Expected HS4DossierFrame at %s." % str(viewport_size))
		return
	var dossier_frame_rect := dossier_frame.get_global_rect()
	var stats_column := main.find_child("HS4StatsColumn", true, false) as Control
	if stats_column == null:
		_fail("Expected HS4StatsColumn right stats column at %s." % str(viewport_size))
		return
	var stats_column_rect := stats_column.get_global_rect()
	if stats_column_rect.size.x < 200.0 or stats_column_rect.size.x > 340.0:
		_fail("Expected stats column width within [200, 340] at %s, got %s." % [str(viewport_size), str(stats_column_rect.size)])
		return
	if stats_column_rect.end.x > dossier_frame_rect.end.x or dossier_frame_rect.end.x - stats_column_rect.end.x > 64.0:
		_fail("Expected stats column flush to the dossier right edge at %s, got column %s dossier %s." % [str(viewport_size), str(stats_column_rect), str(dossier_frame_rect)])
		return
	if stats_column_rect.position.x < dossier_frame_rect.position.x + dossier_frame_rect.size.x * 0.45:
		_fail("Expected stats column in the right part of the dossier at %s, got column %s dossier %s." % [str(viewport_size), str(stats_column_rect), str(dossier_frame_rect)])
		return
	var dossier_text_scroll := main.find_child("HS4DossierScroll", true, false) as Control
	if dossier_text_scroll == null or dossier_text_scroll.get_global_rect().end.x > stats_column_rect.position.x + 2.0:
		_fail("Expected scrollable text column left of the stats column at %s." % str(viewport_size))
		return
	var prev_stat_bottom := -INF
	var stat_column_left := INF
	var stat_rects: Array[Rect2] = []
	for stat_id in ["strength", "agility", "intelligence", "perception", "energy", "knowledge", "endurance", "leadership"]:
		var stat_button := main.find_child("HS4Stat_%s" % stat_id, true, false) as Button
		var stat_bar := main.find_child("HS4StatBarFill_%s" % stat_id, true, false) as ColorRect
		if stat_button == null or stat_bar == null or stat_button.tooltip_text.strip_edges() == "" or not stat_button.tooltip_text.contains(" — ") or stat_button.tooltip_text.contains("Формула:"):
			_fail("Expected line bar + concise hover tooltip for base stat %s at %s." % [stat_id, str(viewport_size)])
			return
		if not stat_button.is_visible_in_tree() or not stat_bar.is_visible_in_tree():
			_fail("Expected all 8 stat bars visible without scrolling at %s, %s hidden." % [str(viewport_size), stat_id])
			return
		var stat_rect := stat_button.get_global_rect()
		stat_rects.append(stat_rect)
		if not dossier_frame_rect.grow(2.0).encloses(stat_rect):
			_fail("Expected stat row %s inside the dossier at %s, got %s dossier %s." % [stat_id, str(viewport_size), str(stat_rect), str(dossier_frame_rect)])
			return
		if not stats_column_rect.grow(2.0).encloses(stat_rect):
			_fail("Expected stat row %s inside the stats column at %s, got %s column %s." % [stat_id, str(viewport_size), str(stat_rect), str(stats_column_rect)])
			return
		if viewport_size.y >= 800 and stat_rect.position.y < prev_stat_bottom - 1.0:
			_fail("Expected stat rows stacked vertically (one column) at %s, %s overlaps previous row." % [str(viewport_size), stat_id])
			return
		prev_stat_bottom = stat_rect.end.y
		if viewport_size.y < 800:
			continue
		if stat_column_left == INF:
			stat_column_left = stat_rect.position.x
		elif absf(stat_rect.position.x - stat_column_left) > 2.0:
			_fail("Expected stat rows aligned in one vertical column at %s, %s misaligned." % [str(viewport_size), stat_id])
			return
	if viewport_size.y < 800:
		var compact_x := {}
		var compact_y := {}
		for stat_rect in stat_rects:
			compact_x[int(roundf(stat_rect.position.x))] = true
			compact_y[int(roundf(stat_rect.position.y))] = true
		if compact_x.size() != 2 or compact_y.size() != 4:
			_fail("Expected SCRUM-951 compact stats to use 2 columns x 4 rows at %s, got %d x-values and %d y-values." % [str(viewport_size), compact_x.size(), compact_y.size()])
			return
		for i in range(stat_rects.size()):
			for j in range(i + 1, stat_rects.size()):
				if stat_rects[i].grow(-0.5).intersects(stat_rects[j].grow(-0.5)):
					_fail("Expected compact stat cells not to overlap at %s: %s vs %s." % [str(viewport_size), stat_rects[i], stat_rects[j]])
					return
	# SCRUM-887: строка «Основные атрибуты: <A>, <B>» из данных — после слабых сторон.
	var main_attrs := main.find_child("HS4MainAttributes", true, false) as Label
	if main_attrs == null or not main_attrs.text.begins_with("Основные атрибуты:"):
		_fail("Expected the 'Основные атрибуты:' data line in the dossier text column at %s." % str(viewport_size))
		return
	var listed_stat_names := 0
	for stat_name in ProgressionData.STAT_NAMES.values():
		if main_attrs.text.contains(str(stat_name)):
			listed_stat_names += 1
	if listed_stat_names < 2:
		_fail("Expected >=2 base stat names in the main attributes line at %s, got '%s'." % [str(viewport_size), main_attrs.text])
		return
	for relevance in ["primary", "secondary", "optional"]:
		var guidance := main.find_child("HS4BuildGuidance_%s" % relevance, true, false) as Label
		if guidance == null or guidance.text.strip_edges() == "":
			_fail("Expected data-driven build guidance section %s at %s." % [relevance, str(viewport_size)])
			return

	var carousel := main.find_child("HS4Carousel", true, false) as Control
	if carousel == null:
		_fail("Expected HS4Carousel at %s." % str(viewport_size))
		return
	var visible_slots := []
	for child in carousel.get_children():
		var slot := child as Button
		if slot == null or not slot.visible or not slot.name.begins_with("HS4CarouselSlot_"):
			continue
		var slot_min := SLOT_MIN_SIZE_648 if viewport_size.y <= 648 else (SLOT_MIN_SIZE_720 if viewport_size.y <= 720 else SLOT_MIN_SIZE)
		if slot.get_global_rect().size.x < slot_min or slot.get_global_rect().size.y < slot_min:
			_fail("Expected enlarged carousel slot at %s, got %s." % [str(viewport_size), str(slot.get_global_rect().size)])
			return
		var slot_portrait := slot.find_child("HS4CarouselPortrait_*", false, false) as TextureRect
		if slot_portrait == null or slot_portrait.texture == null:
			_fail("Expected carousel portrait child inside %s at %s." % [slot.name, str(viewport_size)])
			return
		var slot_label := slot.find_child("HS4CarouselLabel_*", false, false) as Label
		if slot_label == null or slot_label.text.strip_edges() == "":
			_fail("Expected readable carousel label inside %s at %s." % [slot.name, str(viewport_size)])
			return
		if not slot.clip_contents:
			_fail("Expected carousel slot to clip bottom-aligned portrait overflow at %s." % str(viewport_size))
			return
		var slot_rect := slot.get_global_rect()
		var label_rect := slot_label.get_global_rect()
		var label_min_height := 18.0 if viewport_size.y <= 648 else (20.0 if viewport_size.y <= 720 else LABEL_MIN_HEIGHT)
		if label_rect.size.y < label_min_height or not slot_rect.grow(2.0).encloses(label_rect):
			_fail("Expected carousel label to stay inside slot at %s, got label %s slot %s." % [str(viewport_size), str(label_rect), str(slot_rect)])
			return
		var visible_rect := _visible_alpha_global_rect(slot_portrait)
		var portrait_area_h := label_rect.position.y - slot_rect.position.y
		if visible_rect.size.y < maxf(slot_rect.size.y * SLOT_VISIBLE_HEIGHT_MIN_RATIO, portrait_area_h * 0.54):
			_fail("Expected carousel visible silhouette to be enlarged/cropped at %s, got visible %s slot %s label %s." % [str(viewport_size), str(visible_rect), str(slot_rect), str(label_rect)])
			return
		if not Rect2(slot_rect.position, Vector2(slot_rect.size.x, portrait_area_h)).grow(4.0).encloses(visible_rect):
			_fail("Expected carousel visible silhouette to stay in portrait area above label at %s, got visible %s slot %s label %s." % [str(viewport_size), str(visible_rect), str(slot_rect), str(label_rect)])
			return
		var expected_bottom := label_rect.position.y - maxf(3.0, roundf(slot_rect.size.y * 0.02))
		if absf(visible_rect.end.y - expected_bottom) > SLOT_BASELINE_TOLERANCE:
			_fail("Expected carousel portrait visible bottoms to align above label at %s; got %.2f vs %.2f." % [str(viewport_size), visible_rect.end.y, expected_bottom])
			return
		visible_slots.append(slot)
	if visible_slots.size() < 3:
		_fail("Expected at least 3 visible enlarged carousel slots at %s, got %d." % [str(viewport_size), visible_slots.size()])
		return

	var portrait_rect := portrait_frame.get_global_rect()
	var dossier_rect := (main.find_child("HS4DossierFrame", true, false) as Control).get_global_rect()
	var asc_rect := ascension.get_global_rect()
	var carousel_rect := carousel.get_global_rect()
	var choose_rect := choose.get_global_rect()
	var counter := main.find_child("HS4CarouselCounter", true, false) as Control
	if counter == null:
		_fail("Expected HS4CarouselCounter chip at %s." % str(viewport_size))
		return
	var counter_rect := counter.get_global_rect()
	for pair in [
		["portrait", portrait_rect, "dossier", dossier_rect], ["dossier", dossier_rect, "ascension", asc_rect],
		["portrait", portrait_rect, "carousel", carousel_rect], ["ascension", asc_rect, "carousel", carousel_rect],
		["ascension", asc_rect, "choose", choose_rect], ["choose", choose_rect, "carousel", carousel_rect],
		["portrait", portrait_rect, "choose", choose_rect], ["choose", choose_rect, "dossier", dossier_rect],
		["counter", counter_rect, "dossier", dossier_rect], ["counter", counter_rect, "carousel", carousel_rect],
		["counter", counter_rect, "choose", choose_rect],
	]:
		if (pair[1] as Rect2).grow(-2.0).intersects((pair[3] as Rect2).grow(-2.0)):
			_fail("Expected major Hero Select zones not to overlap at %s: %s %s vs %s %s." % [str(viewport_size), pair[0], str(pair[1]), pair[2], str(pair[3])])
			return

	# SCRUM-882: CTA «Выбрать» — в левой колонне под возвышением, во всю ширину
	# колонны (плита main_menu 380×104, только пропорциональный даунскейл),
	# прижат к низу safe-зоны.
	if choose_rect.position.x < portrait_rect.position.x - 2.0 or choose_rect.end.x > portrait_rect.end.x + 2.0:
		_fail("Expected HS4ChooseButton to stay inside the left column at %s, got %s vs portrait %s." % [str(viewport_size), str(choose_rect), str(portrait_rect)])
		return
	if choose_rect.position.y < asc_rect.end.y - 2.0:
		_fail("Expected HS4ChooseButton below HS4AscensionFrame at %s, got %s vs ascension %s." % [str(viewport_size), str(choose_rect), str(asc_rect)])
		return
	if choose_rect.size.x < portrait_rect.size.x * 0.9:
		_fail("Expected HS4ChooseButton width >= 0.9x portrait column at %s, got %s vs portrait %s." % [str(viewport_size), str(choose_rect.size), str(portrait_rect.size)])
		return
	var choose_ratio_tolerance := 0.10 if viewport_size.y <= 648 else 0.04
	if choose_rect.size.y <= 0.0 or absf(choose_rect.size.x / choose_rect.size.y - CHOOSE_PLATE_RATIO) > CHOOSE_PLATE_RATIO * choose_ratio_tolerance:
		_fail("Expected HS4ChooseButton to keep the 380:104 main-menu plate aspect at %s, got %s." % [str(viewport_size), str(choose_rect.size)])
		return
	# SCRUM-882: досье вровень с портретом (одна верхняя линия), его низ поднят —
	# между досье и каруселью остаётся воздух под счётчик.
	if absf(dossier_rect.position.y - portrait_rect.position.y) > 2.0:
		_fail("Expected HS4DossierFrame top to align with HS4PortraitFrame top at %s, got %.1f vs %.1f." % [str(viewport_size), dossier_rect.position.y, portrait_rect.position.y])
		return
	if carousel_rect.position.y - dossier_rect.end.y < dossier_rect.size.y * 0.08:
		_fail("Expected >=8%% air between dossier bottom and carousel top at %s, got gap %.1f for dossier %s." % [str(viewport_size), carousel_rect.position.y - dossier_rect.end.y, str(dossier_rect)])
		return
	# SCRUM-882: счётчик карусели «N–M из K» + число скрытых героев на стрелках.
	var counter_label := main.find_child("HS4CarouselCounterLabel", true, false) as Label
	if counter_label == null:
		_fail("Expected HS4CarouselCounterLabel at %s." % str(viewport_size))
		return
	var counter_regex := RegEx.new()
	counter_regex.compile("^(\\d+)–(\\d+) из (\\d+)$")
	var counter_match := counter_regex.search(counter_label.text)
	if counter_match == null:
		_fail("Expected carousel counter to match 'N–M из K' at %s, got '%s'." % [str(viewport_size), counter_label.text])
		return
	var total_classes: int = ProgressionData.character_ids().size()
	if int(counter_match.get_string(3)) != total_classes:
		_fail("Expected carousel counter K == %d playable classes at %s, got '%s'." % [total_classes, str(viewport_size), counter_label.text])
		return
	var window_first := int(counter_match.get_string(1))
	var window_last := int(counter_match.get_string(2))
	if window_first < 1 or window_last < window_first or window_last > total_classes:
		_fail("Expected sane carousel counter window at %s, got '%s'." % [str(viewport_size), counter_label.text])
		return
	var prev_arrow := main.find_child("HS4CarouselPrevButton", true, false) as Button
	var next_arrow := main.find_child("HS4CarouselNextButton", true, false) as Button
	if prev_arrow == null or next_arrow == null:
		_fail("Expected carousel arrows at %s." % str(viewport_size))
		return
	var expected_prev := "‹" if window_first <= 1 else "‹%d" % (window_first - 1)
	var expected_next := "›" if window_last >= total_classes else "%d›" % (total_classes - window_last)
	if prev_arrow.text != expected_prev or next_arrow.text != expected_next:
		_fail("Expected arrows to show hidden hero counts at %s: want '%s'/'%s', got '%s'/'%s'." % [str(viewport_size), expected_prev, expected_next, prev_arrow.text, next_arrow.text])
		return
	# SCRUM-979: the first press must shift the window by exactly one. Retrying
	# until any counter change would hide the former adjacent-selection behavior.
	if window_first != 1:
		_fail("Expected explicit Berserk baseline window to start at 1, got '%s'." % counter_label.text)
		return
	next_arrow.pressed.emit()
	var expected_after_next := "2–%d из %d" % [mini(window_last + 1, total_classes), total_classes]
	if counter_label.text != expected_after_next or int(carousel.get_meta("window_offset", -1)) != 1:
		_fail("Expected first Next press to shift carousel exactly +1 at %s: want '%s', got '%s' offset %d." % [
			str(viewport_size), expected_after_next, counter_label.text, int(carousel.get_meta("window_offset", -1))])
		return
	if str(main.get("selected_character_id")) != "soldier":
		_fail("Expected Soldier to replace Berserk in the anchored first slot at %s, got %s." % [viewport_size, str(main.get("selected_character_id"))])
		return

	# SCRUM-879: весь контент — строго в safe-зоне рамы (маргины 160px от базы
	# 1536x1024, масштабированные к вьюпорту; допуск 2px).
	var back_button := main.find_child("HS4BackButton", true, false) as Button
	if back_button == null:
		_fail("Expected HS4BackButton at %s." % str(viewport_size))
		return
	var safe_margin := Vector2(roundf(160.0 * float(viewport_size.x) / 1536.0), roundf(160.0 * float(viewport_size.y) / 1024.0))
	var safe_rect := Rect2(safe_margin, Vector2(viewport_size) - safe_margin * 2.0).grow(2.0)
	var safe_zone_entries := {
		"HS4PortraitFrame": portrait_rect,
		"HS4DossierFrame": dossier_rect,
		"HS4AscensionFrame": asc_rect,
		"HS4Carousel": carousel_rect,
		"HS4BackButton": back_button.get_global_rect(),
		"HS4ChooseButton": choose.get_global_rect(),
		"HS4CarouselCounter": counter.get_global_rect(),
	}
	for zone_name in safe_zone_entries:
		if not safe_rect.encloses(safe_zone_entries[zone_name] as Rect2):
			_fail("Expected %s to stay inside the unified frame safe margins at %s, got %s vs safe %s." % [zone_name, str(viewport_size), str(safe_zone_entries[zone_name]), str(safe_rect)])
			return

	main.queue_free()
	viewport.queue_free()
	await process_frame


func _assert_directional_preview(character_id: String) -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	main.set("selected_character_id", character_id)
	main.call("_show_character_select")
	await process_frame
	await process_frame

	var portrait := main.find_child("HS4Portrait", true, false) as TextureRect
	if portrait == null or portrait.texture == null:
		_fail("Expected %s Hero Select preview texture." % character_id)
		return
	var first_texture := portrait.texture
	if first_texture.get_size() != Vector2(512, 512):
		_fail("Expected %s Hero Select preview to use actual 512x512 PixelLab frame, got %s." % [character_id, str(first_texture.get_size())])
		return
	await create_timer(0.24).timeout
	if portrait.texture == null or portrait.texture == first_texture:
		_fail("Expected %s Hero Select preview to rotate through directional frames." % character_id)
		return
	main.queue_free()
	await process_frame


func _size_close(actual: Vector2, expected: Vector2, tolerance: float) -> bool:
	return absf(actual.x - expected.x) <= tolerance and absf(actual.y - expected.y) <= tolerance


func _alpha_bbox(texture: Texture2D) -> Rect2:
	if texture == null:
		return Rect2()
	var image := texture.get_image()
	if image == null or image.is_empty():
		return Rect2(Vector2.ZERO, texture.get_size())
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.02:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2(Vector2.ZERO, texture.get_size())
	return Rect2(Vector2(float(min_x), float(min_y)), Vector2(float(max_x - min_x + 1), float(max_y - min_y + 1)))


func _visible_alpha_global_rect(texture_rect: TextureRect) -> Rect2:
	if texture_rect == null or texture_rect.texture == null:
		return Rect2()
	var texture := texture_rect.texture
	var texture_size := texture.get_size()
	var control_rect := texture_rect.get_global_rect()
	var draw_scale := minf(control_rect.size.x / texture_size.x, control_rect.size.y / texture_size.y)
	var draw_size := texture_size * draw_scale
	var draw_origin := control_rect.position + (control_rect.size - draw_size) * 0.5
	var bbox := _alpha_bbox(texture)
	return Rect2(draw_origin + bbox.position * draw_scale, bbox.size * draw_scale)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
