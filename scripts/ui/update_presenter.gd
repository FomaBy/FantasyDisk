extends RefCounted

const UpdateDialog := preload("res://scripts/ui/update_dialog.gd")

var _ui_ref: WeakRef
var update_manager
var _previous_escape_action := Callable()


func _init(owner_ui, manager) -> void:
	_ui_ref = weakref(owner_ui)
	update_manager = manager
	update_manager.check_started.connect(_on_check_started)
	update_manager.check_finished.connect(_on_check_finished)
	update_manager.download_started.connect(_on_download_started)
	update_manager.download_finished.connect(_on_download_finished)
	update_manager.tree_exiting.connect(_release_connections, CONNECT_ONE_SHOT)


func _release_connections() -> void:
	if update_manager != null:
		for binding in [
			[update_manager.check_started, _on_check_started],
			[update_manager.check_finished, _on_check_finished],
			[update_manager.download_started, _on_download_started],
			[update_manager.download_finished, _on_download_finished],
		]:
			var signal_value: Signal = binding[0]
			var callback: Callable = binding[1]
			if signal_value.is_connected(callback):
				signal_value.disconnect(callback)
	update_manager = null


func request_check() -> void:
	if update_manager == null or not is_instance_valid(update_manager):
		show_dialog("error", {}, "Служба обновлений не запущена.")
		return
	update_manager.check_for_updates(true)


func _on_check_started(manual: bool) -> void:
	if manual:
		show_dialog("checking", {
			"current_version": update_manager.current_version(),
		}, "Подключаемся к GitHub Releases…")


func _on_check_finished(result: Dictionary, manual: bool) -> void:
	var status := str(result.get("status", "error"))
	# Offline startup checks do not interrupt play. Manual checks always report.
	if status == "available" or manual:
		show_dialog(status, result, str(result.get("message", "")))


func _on_download_started(manifest: Dictionary) -> void:
	show_dialog("downloading", {
		"current_version": update_manager.current_version(),
		"latest_version": str(manifest.get("version", "")),
		"manifest": manifest,
	}, "Загрузка выполняется в защищённый каталог игры.")


func _on_download_finished(success: bool, _installer_path: String, message: String) -> void:
	if not success:
		show_dialog("error", {"current_version": update_manager.current_version()}, message)
		return
	if update_manager.launch_installer():
		show_dialog("installer_opened", {
			"current_version": update_manager.current_version(),
			"manifest": update_manager.latest_manifest,
		}, update_manager.last_message)
	else:
		show_dialog("error", {
			"current_version": update_manager.current_version(),
		}, update_manager.last_message)


func show_dialog(mode: String, payload: Dictionary, message: String) -> void:
	var owner_ui = _ui_ref.get_ref()
	if owner_ui == null or owner_ui.game.ui_layer == null or not is_instance_valid(owner_ui.game.ui_layer):
		return
	var existing: Node = owner_ui.game.ui_layer.find_child("GameUpdateDialog", true, false)
	if existing == null:
		_previous_escape_action = owner_ui.game.ui_escape_action
	else:
		existing.free()
	var dialog := UpdateDialog.new()
	dialog.configure(owner_ui, update_manager, mode, payload, message)
	dialog.close_requested.connect(close_dialog)
	owner_ui.game.ui_layer.add_child(dialog)
	owner_ui.game.ui_escape_action = close_dialog


func close_dialog() -> void:
	var owner_ui = _ui_ref.get_ref()
	if owner_ui == null:
		return
	if owner_ui.game.ui_layer != null and is_instance_valid(owner_ui.game.ui_layer):
		var dialog: Node = owner_ui.game.ui_layer.find_child("GameUpdateDialog", true, false)
		if dialog != null:
			dialog.queue_free()
	owner_ui.game.ui_escape_action = _previous_escape_action
	_previous_escape_action = Callable()
