extends "res://scripts/ui/screens/input_bindings.gd"

# FAN-3824: модуль распределённого UI-класса — оверлей обратной связи.
# Часть линейной extends-цепочки scripts/ui/screens/** (сборка — фасад
# scripts/ui_screens.gd). Код перенесён из ui_screens.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в ui_screens_shared_api.gd.





# FAN-1057: runtime-builder формы фидбэка вынесен в FeedbackOverlayController.
# Актуальная responsive-геометрия, safe zones и 720p/1080p/2K контрольные размеры
# зафиксированы в docs/design/mockups/FAN-1057_feedback_privacy/spec.md и
# tests/feedback_privacy_ui_test.gd; фасад ниже сохраняет публичный API UIScreens.


func _show_feedback_overlay(screenshot: Image = null) -> void:
	FeedbackOverlayController.show(self, game, screenshot)




func _is_feedback_overlay_open() -> bool:
	return game.feedback_overlay_layer != null and is_instance_valid(game.feedback_overlay_layer)




func _close_feedback_overlay() -> void:
	if _feedback_request_id > 0:
		var reporter := game.get_node_or_null("FeedbackReporter") as Node
		if reporter != null and is_instance_valid(reporter):
			reporter.call("cancel_active_report", _feedback_request_id)
		_feedback_request_id = 0
	if game.feedback_overlay_layer != null and is_instance_valid(game.feedback_overlay_layer):
		game.feedback_overlay_layer.queue_free()
	game.feedback_overlay_layer = null
	# Снять паузу, поставленную при открытии формы фидбека (no-op, если не стояла).
	game.pop_pause("feedback")




func _feedback_reporter() -> Node:
	var reporter: Node = game.get_node_or_null("FeedbackReporter")
	if reporter != null and is_instance_valid(reporter):
		return reporter
	reporter = FEEDBACK_REPORTER_SCRIPT.new()
	reporter.name = "FeedbackReporter"
	reporter.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(reporter)
	return reporter




func _feedback_privacy_configuration() -> Dictionary:
	var operator_name := str(ProjectSettings.get_setting(
		FEEDBACK_REPORTER_SCRIPT.PRIVACY_OPERATOR_SETTING, "")).strip_edges()
	var contact_url := str(ProjectSettings.get_setting(
		FEEDBACK_REPORTER_SCRIPT.PRIVACY_CONTACT_SETTING, "")).strip_edges()
	var retention_notice := str(ProjectSettings.get_setting(
		FEEDBACK_REPORTER_SCRIPT.PRIVACY_RETENTION_SETTING, "")).strip_edges()
	var policy_url := str(ProjectSettings.get_setting(
		FEEDBACK_REPORTER_SCRIPT.PRIVACY_POLICY_SETTING, "")).strip_edges()
	return {
		"operator": operator_name,
		"contact": contact_url,
		"retention": retention_notice,
		"policy": policy_url,
		"complete": FEEDBACK_REPORTER_SCRIPT._privacy_configuration_complete(
			operator_name, contact_url, retention_notice, policy_url),
	}




func _feedback_metadata() -> Dictionary:
	var viewport_size: Vector2 = game.get_viewport().get_visible_rect().size
	return {
		"version": str(ProjectSettings.get_setting("application/config/version", "dev")),
		"character": str(game.selected_character_id),
		"weapon": str(game.selected_weapon_id),
		"ascension": int(game.selected_ascension_level),
		"current_act": int(game.current_act),
		"route_stage": int(game.route_stage),
		"route_scaling_stage": int(game.route_scaling_stage()),
		"current_node_type": str(game.current_node_type),
		"combat_active": bool(game.combat_active),
		"boss_active": bool(game.boss_combat_active),
		"screen": _current_ui_screen_name(),
		"resolution": "%dx%d" % [int(viewport_size.x), int(viewport_size.y)],
		"os": OS.get_name(),
		"timestamp": Time.get_datetime_string_from_system(),
	}
