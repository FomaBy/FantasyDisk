extends "res://tests/runtime_smoke_test.gd"

# SCRUM-508: EV-инвариант риск/награды random-событий считается ТЕМ ЖЕ калькулятором,
# что и отчёт route_economy_xp_model.md (единый источник истины, без расхождений).
const RouteEconomyModel := preload("res://tools/route_economy_xp_model.gd")


func _initialize() -> void:
	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main scene did not load for progression/economy smoke.")
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	if ProgressionData.reward_pool().size() < 28:
		_fail("Expected expanded artifact/reward pool in progression smoke.")
		return
	if ProgressionData.shop_items().size() <= ProgressionData.reward_pool().size() / 2:
		_fail("Expected expanded shop pool in progression smoke.")
		return

	_test_stat_artifact_recording()
	_test_settings_persistence_and_audio()
	await _test_full_attribute_wiring()
	await _test_universal_attribute_interpretations()
	await _test_class_relevance_and_offer_fixation(main_scene)
	await _test_economy_tiers_and_fab(main_scene)
	await _test_ascension_difficulty_ladder(main_scene)
	_test_class_budget_profiles()
	_test_event_ev_risk_reward_invariant()

	main.queue_free()
	await process_frame
	_finish("Runtime progression/economy smoke suite passed.")


func _test_event_ev_risk_reward_invariant() -> void:
	# SCRUM-508: для каждого события с парой ветвей EV(risk/combat) >= EV(лучшей безопасной).
	# Использует общий калькулятор RouteEconomyModel.event_ev_rows (тот же, что и отчёт).
	# SCRUM-995 сжал пул до полированного пака 12×3: пар риск/безопасно в каноне ровно 4
	# (progression_balance.md §Random Events EV) — порог голден-гейта обновлён с 10.
	var rows: Array = RouteEconomyModel.event_ev_rows()
	if rows.size() < 4:
		_fail("Expected EV invariant rows for risk events (got %d, canon SCRUM-995 = 4) — calculator or event pack regressed." % rows.size())
		return
	for row in rows:
		var risk_ev := float(row["risk_ev"])
		var safe_ev := float(row["safe_ev"])
		if risk_ev < safe_ev - 0.01:
			_fail("Event '%s' violates risk/reward EV invariant: EV(risk %s)=%.1f < EV(safe %s)=%.1f (SCRUM-508)." % [
				str(row["event"]), str(row["risk_id"]), risk_ev, str(row["safe_id"]), safe_ev,
			])
			return
	print("Event risk/reward EV invariant passed (%d events, all EV(risk) >= EV(safe))." % rows.size())
