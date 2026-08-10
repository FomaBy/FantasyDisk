extends SceneTree

## FAN-1458 — контрактный тест ultimate-HUD виджета (AC1, AC2, AC6).
##
## Изолированная сцена + versioned contract fixtures из настоящего реестра:
##  - selected-weapon identity для ОБОИХ источников (weapon_profile и
##    legacy_class_fallback) — фолбэк рисуется как выбранное оружие, не класс;
##  - контракт восстановления заряда: тот же заряд рисуется тем же, overlay
##    активной ульты не восстанавливается из persistent_snapshot;
##  - декларативный aim/ready контракт по канонической семантике AimController;
##  - fail-closed нормализация пустого состояния.
##
## Запуск: Godot --headless --path . \
##   --script res://tests/ultimates/hud_state_contract_test.gd

const PD := preload("res://scripts/progression_data.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const State := preload("res://scripts/ui/ultimate_hud/ultimate_hud_state.gd")
const ViewModel := preload("res://scripts/ui/ultimate_hud/ultimate_hud_view_model.gd")
const FixtureLibrary := preload("res://tests/ultimates/hud_fixture_library.gd")
const WIDGET_SCENE := preload("res://scenes/ui/ultimate_hud/ultimate_hud_widget.tscn")

const CLASS_ID := "assassin"
const WEAPON_ID := "chakrams"

var _errors: Array[String] = []


func _initialize() -> void:
	var fixtures := FixtureLibrary.new()
	_expect(fixtures.registry.is_valid(), "fixture registry must be valid: %s" % str(fixtures.registry.validation_errors()))
	_expect(fixtures.registry.profile_count() == 51, "fixture registry must hold 51 profiles")

	await _check_selected_weapon_identity(fixtures)
	await _check_charge_restore_contract(fixtures)
	await _check_aim_ready_contract(fixtures)
	await _check_fail_closed()

	if _errors.is_empty():
		print("FAN-1458 ultimate HUD state contract test passed.")
		quit(0)
	else:
		for error in _errors:
			push_error(error)
		print("FAN-1458 ultimate HUD state contract test FAILED (%d errors)." % _errors.size())
		quit(1)


func _check_selected_weapon_identity(fixtures) -> void:
	var weapon_title := str(((PD.WEAPONS_BY_CLASS[CLASS_ID] as Dictionary)[WEAPON_ID] as Dictionary)["title"])
	var class_title := str((PD.CHARACTER_CONFIGS[CLASS_ID] as Dictionary)["title"])
	var legacy_title := str(PD.ultimate_config(CLASS_ID).get("title", ""))
	var expected_profile_id := "weapon_ultimate.profile.%s.%s" % [CLASS_ID, WEAPON_ID]

	# Случай A: синтетический legacy source поверх настоящего профиля. После
	# активации 51/51 реестр больше не содержит реального fallback-профиля, но
	# view-model по-прежнему обязан безопасно отрисовать старый snapshot.
	var fallback_snapshot: Dictionary = fixtures.fallback_snapshot(CLASS_ID, WEAPON_ID)
	fallback_snapshot["resolution_source"] = Resolver.SOURCE_LEGACY_CLASS_FALLBACK
	_expect(
		str(fallback_snapshot["resolution_source"]) == Resolver.SOURCE_LEGACY_CLASS_FALLBACK,
		"legacy snapshot fixture must use legacy_class_fallback"
	)
	# Случай B: настоящий ready-профиль -> источник weapon_profile.
	var profile_snapshot: Dictionary = fixtures.weapon_profile_snapshot(CLASS_ID, WEAPON_ID)
	_expect(
		str(profile_snapshot["resolution_source"]) == Resolver.SOURCE_WEAPON_PROFILE,
		"fixture ready profile must use weapon_profile source"
	)

	for snapshot in [fallback_snapshot, profile_snapshot]:
		var state: Dictionary = ViewModel.build(snapshot)
		var source := str((state["selection"] as Dictionary)["source"])
		var widget = await _make_widget()
		widget.apply_state(state)
		await process_frame

		var selection := state["selection"] as Dictionary
		_expect(str(selection["weapon_title"]) == weapon_title, "[%s] view model must carry the selected weapon title" % source)
		_expect(str(selection["profile_id"]) == expected_profile_id, "[%s] view model must carry the selected weapon profile id" % source)

		var title_label := widget.find_child("WeaponTitle", true, false) as Label
		var tooltip_weapon := widget.find_child("TooltipWeaponLine", true, false) as Label
		var tooltip_title := widget.find_child("TooltipUltimateTitle", true, false) as Label
		var tooltip_description := widget.find_child("TooltipUltimateDescription", true, false) as Label
		_expect(title_label != null and title_label.text == weapon_title, "[%s] HUD title must be the selected weapon, got '%s'" % [source, "" if title_label == null else title_label.text])
		_expect(title_label != null and title_label.text != class_title, "[%s] HUD title must not collapse to the class title" % source)
		_expect(tooltip_weapon != null and tooltip_weapon.text == weapon_title, "[%s] Codex tooltip must name the selected weapon" % source)
		_expect(tooltip_title != null and tooltip_title.text == str((state["ultimate"] as Dictionary)["title"]), "[%s] tooltip must show the ultimate title" % source)
		_expect(tooltip_description != null and tooltip_description.text == str((state["ultimate"] as Dictionary)["description"]), "[%s] tooltip must show the ultimate description" % source)
		_expect(is_equal_approx(widget.charge_ratio(), 0.5), "[%s] charge fraction must render as given" % source)
		widget.queue_free()
		await process_frame

	# Фолбэк-текст исполняемой ульты остаётся классовым, но идентичность — нет.
	var fallback_state: Dictionary = ViewModel.build(fallback_snapshot)
	_expect(str((fallback_state["ultimate"] as Dictionary)["title"]) == legacy_title, "fallback ultimate text comes from the legacy class config")


func _check_charge_restore_contract(fixtures) -> void:
	var widget = await _make_widget()
	var snapshot: Dictionary = fixtures.fallback_snapshot(
		CLASS_ID, WEAPON_ID, {"charge": {"fraction": 0.62, "active": true}}
	)
	widget.apply_state(ViewModel.build(snapshot))
	await process_frame
	_expect(is_equal_approx(widget.charge_ratio(), 0.62), "runtime charge must render 0.62")
	_expect(widget.active_overlay_visible(), "runtime active state must show the overlay")

	var persisted: Dictionary = widget.persistent_snapshot()
	_expect(is_equal_approx(float((persisted["charge"] as Dictionary)["fraction"]), 0.62), "persistent snapshot must keep the charge fraction")
	_expect(not bool((persisted["charge"] as Dictionary)["active"]), "persistent snapshot must strip the active overlay state")

	# Повторная подача того же сохранённого состояния в свежий виджет.
	var restored = await _make_widget()
	restored.apply_state(persisted)
	await process_frame
	_expect(is_equal_approx(restored.charge_ratio(), 0.62), "restored widget must draw the same charge")
	_expect(not restored.active_overlay_visible(), "active overlay must never be restored")

	# И в тот же виджет: рендер идемпотентен по сохранённому состоянию.
	restored.apply_state(persisted)
	await process_frame
	_expect(is_equal_approx(restored.charge_ratio(), 0.62), "re-applied snapshot must keep the same charge")
	_expect(not restored.active_overlay_visible(), "re-applied snapshot must keep the overlay hidden")

	widget.queue_free()
	restored.queue_free()
	await process_frame


func _check_aim_ready_contract(fixtures) -> void:
	var widget = await _make_widget()
	var aim_hint := widget.find_child("AimHint", true, false) as Label
	var ready_badge := widget.find_child("ReadyBadge", true, false) as Label

	# Ручной режим + геймпад: canonical AimController preview (правый стик).
	widget.apply_state(ViewModel.build(fixtures.fallback_snapshot(CLASS_ID, WEAPON_ID, {
		"input": fixtures.gamepad_input(),
		"aim": {"mode": State.AIM_MODE_MANUAL, "aiming": true},
	})))
	_expect(widget.aim_preview_visible(), "manual+gamepad aiming must expose the aim preview")
	_expect(aim_hint != null and aim_hint.visible and aim_hint.text == "Прицел: правый стик", "gamepad aim hint must follow AimController semantics")

	# Ручной режим + мышь: превью-маркера нет, курсор ведёт мышь.
	widget.apply_state(ViewModel.build(fixtures.fallback_snapshot(CLASS_ID, WEAPON_ID, {
		"aim": {"mode": State.AIM_MODE_MANUAL, "aiming": true},
	})))
	_expect(not widget.aim_preview_visible(), "manual+mouse must not draw the stick preview")
	_expect(aim_hint != null and aim_hint.visible and aim_hint.text == "Прицел: курсор мыши", "mouse aim hint must follow AimController semantics")

	# Автонаводка: подсказки нет вовсе.
	widget.apply_state(ViewModel.build(fixtures.fallback_snapshot(CLASS_ID, WEAPON_ID, {
		"aim": {"mode": State.AIM_MODE_AUTO, "aiming": true},
	})))
	_expect(not widget.aim_preview_visible(), "auto aim must not draw a preview")
	_expect(aim_hint != null and not aim_hint.visible, "auto aim must hide the aim hint")

	# Ready-контракт: редкий одноразовый пульс на переходе в готовность.
	widget.apply_state(ViewModel.build(fixtures.fallback_snapshot(CLASS_ID, WEAPON_ID, {
		"charge": {"fraction": 0.4, "active": false},
	})))
	_expect(not widget.is_ultimate_ready(), "partial charge must not be ready")
	_expect(ready_badge != null and not ready_badge.visible, "ready badge must stay hidden below full charge")
	_expect(not widget.consume_ready_pulse(), "no ready pulse below full charge")

	widget.apply_state(ViewModel.build(fixtures.fallback_snapshot(CLASS_ID, WEAPON_ID, {
		"charge": {"fraction": 1.0, "active": false},
	})))
	_expect(widget.is_ultimate_ready(), "full charge with input must be ready")
	_expect(ready_badge != null and ready_badge.visible, "ready badge must show at full charge")
	_expect(widget.consume_ready_pulse(), "transition to ready must emit exactly one pulse")
	_expect(not widget.consume_ready_pulse(), "ready pulse must be one-shot")

	widget.apply_state(ViewModel.build(fixtures.fallback_snapshot(CLASS_ID, WEAPON_ID, {
		"charge": {"fraction": 1.0, "active": false},
	})))
	_expect(not widget.consume_ready_pulse(), "staying ready must not re-pulse")

	# Активация: сигнал уходит ровно один раз на запрос и несёт profile_id.
	var received: Array[String] = []
	widget.activation_requested.connect(func(profile_id: String) -> void: received.append(profile_id))
	_expect(widget.request_activation(), "ready widget must emit activation")
	_expect(received == ["weapon_ultimate.profile.%s.%s" % [CLASS_ID, WEAPON_ID]], "activation must carry the selected profile id")

	# Во время активной ульты повторная активация не эмитится.
	widget.apply_state(ViewModel.build(fixtures.fallback_snapshot(CLASS_ID, WEAPON_ID, {
		"charge": {"fraction": 1.0, "active": true},
	})))
	_expect(not widget.request_activation(), "active ultimate must reject re-activation")
	_expect(received.size() == 1, "no extra activation signals while active")

	widget.queue_free()
	await process_frame


func _check_fail_closed() -> void:
	var widget = await _make_widget()
	widget.apply_state({})
	await process_frame
	var received := []
	widget.activation_requested.connect(func(profile_id: String) -> void: received.append(profile_id))
	_expect(not widget.is_ultimate_ready(), "empty state must not be ready")
	_expect(not widget.request_activation(), "empty state must not activate")
	_expect(received.is_empty(), "empty state must emit no signals")
	var title_label := widget.find_child("WeaponTitle", true, false) as Label
	_expect(title_label != null and title_label.text == "—", "empty state must render the inert placeholder")
	widget.queue_free()
	await process_frame


func _make_widget():
	var widget = WIDGET_SCENE.instantiate()
	root.add_child(widget)
	await process_frame
	return widget


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
