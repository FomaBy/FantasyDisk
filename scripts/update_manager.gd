extends Node

signal check_started(manual: bool)
signal check_finished(result: Dictionary, manual: bool)
signal download_started(manifest: Dictionary)
signal download_finished(success: bool, installer_path: String, message: String)
signal state_changed(state: String, message: String)

const MANIFEST_SCHEMA_VERSION := 1
# Канал доверия macOS-артефактов. Обязан совпадать с каналом релизного
# пайплайна: tools/build_release.sh сверяет эту метку с FANTASYDISK_MACOS_CHANNEL
# и отказывается собирать релиз, если клиентские подсказки стали бы ложью.
# "unsigned" — принятое владельцем решение (FAN-1121): без Developer ID и
# нотаризации, с ручным подтверждением Gatekeeper при первом запуске.
const MACOS_UPDATE_CHANNEL := "unsigned"
const MACOS_UNSIGNED_NOTICE := "Сборка для macOS распространяется без подписи Apple Developer ID и без нотаризации. Если Gatekeeper заблокирует первый запуск, откройте Системные настройки → Конфиденциальность и безопасность и нажмите «Всё равно открыть» (Open Anyway)."
const DEFAULT_MANIFEST_URL := "https://github.com/FomaBy/FantasyDisk/releases/latest/download/update-manifest.json"
const DEFAULT_RELEASE_URL := "https://github.com/FomaBy/FantasyDisk/releases/latest"
const TRUSTED_RELEASE_PREFIX := "https://github.com/FomaBy/FantasyDisk/releases/"
const UPDATE_DIR := "user://updates"
const MANIFEST_BODY_LIMIT := 256 * 1024
const DOWNLOAD_BODY_LIMIT := 1024 * 1024 * 1024

const STATE_IDLE := "idle"
const STATE_CHECKING := "checking"
const STATE_CURRENT := "current"
const STATE_AVAILABLE := "available"
const STATE_DOWNLOADING := "downloading"
const STATE_VERIFIED := "verified"
const STATE_INSTALLER_OPENED := "installer_opened"
const STATE_ERROR := "error"

var latest_manifest := {}
var state := STATE_IDLE
var last_message := ""
var downloaded_installer_path := ""

var _manifest_request: HTTPRequest = null
var _download_request: HTTPRequest = null
var _manual_check := false
var _download_partial_path := ""
var _download_final_path := ""


func install(game: Node, presenter) -> void:
	name = "UpdateManager"
	game.add_child(self)
	presenter._connect_update_manager(self)
	if should_check_on_startup():
		call_deferred("check_for_updates", false)


func current_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


func manifest_url() -> String:
	return str(ProjectSettings.get_setting("updates/manifest_url", DEFAULT_MANIFEST_URL)).strip_edges()


func should_check_on_startup() -> bool:
	return bool(ProjectSettings.get_setting("updates/check_on_startup", true)) \
		and not OS.has_feature("editor") \
		and DisplayServer.get_name() != "headless"


func is_busy() -> bool:
	return _manifest_request != null or _download_request != null


func check_for_updates(manual := true) -> bool:
	if is_busy():
		if manual:
			check_finished.emit({
				"status": state,
				"message": "Проверка или загрузка уже выполняется.",
			}, true)
		return false

	var url := manifest_url()
	if not _is_trusted_manifest_url(url):
		_finish_check_error("Адрес обновлений не прошёл проверку безопасности.", manual)
		return false

	_manual_check = manual
	_set_state(STATE_CHECKING, "Проверяем обновления…")
	check_started.emit(manual)

	_manifest_request = HTTPRequest.new()
	_manifest_request.name = "UpdateManifestRequest"
	_manifest_request.timeout = 12.0
	_manifest_request.body_size_limit = MANIFEST_BODY_LIMIT
	_manifest_request.max_redirects = 8
	_manifest_request.use_threads = true
	add_child(_manifest_request)
	_manifest_request.request_completed.connect(_on_manifest_request_completed, CONNECT_ONE_SHOT)
	var error := _manifest_request.request(url, [
		"Accept: application/json",
		"User-Agent: FantasyDisk/%s" % current_version(),
	])
	if error != OK:
		_dispose_manifest_request()
		_finish_check_error("Не удалось начать проверку обновлений.", manual)
		return false
	return true


func download_installer() -> bool:
	if is_busy():
		download_finished.emit(false, "", "Проверка или загрузка уже выполняется.")
		return false
	if latest_manifest.is_empty():
		download_finished.emit(false, "", "Сначала проверьте наличие обновления.")
		return false
	if compare_versions(current_version(), str(latest_manifest.get("version", "0.0.0"))) >= 0:
		download_finished.emit(false, "", "Установлена актуальная версия.")
		return false

	var asset_result := asset_for_platform(latest_manifest, OS.get_name())
	if not bool(asset_result.get("ok", false)):
		download_finished.emit(false, "", str(asset_result.get("error", "Нет установщика для этой платформы.")))
		return false
	var asset: Dictionary = asset_result["asset"]
	var file_name := str(asset["name"])
	var expected_sha256 := str(asset["sha256"]).to_lower()
	var expected_size := int(asset["size"])

	var update_dir := ProjectSettings.globalize_path(UPDATE_DIR)
	if DirAccess.make_dir_recursive_absolute(update_dir) != OK:
		download_finished.emit(false, "", "Не удалось подготовить каталог обновлений.")
		return false
	_download_final_path = "%s/%s" % [UPDATE_DIR, file_name]
	_download_partial_path = "%s.partial" % _download_final_path
	_remove_file_if_present(_download_partial_path)
	if FileAccess.file_exists(_download_final_path) \
		and _file_size(_download_final_path) == expected_size \
		and FileAccess.get_sha256(_download_final_path).to_lower() == expected_sha256:
		downloaded_installer_path = _download_final_path
		_set_state(STATE_VERIFIED, "Установщик уже загружен и проверен.")
		download_finished.emit(true, downloaded_installer_path, last_message)
		return true

	_download_request = HTTPRequest.new()
	_download_request.name = "UpdateInstallerRequest"
	_download_request.timeout = 300.0
	_download_request.body_size_limit = mini(DOWNLOAD_BODY_LIMIT, expected_size + 1024 * 1024)
	_download_request.max_redirects = 8
	_download_request.use_threads = true
	_download_request.download_file = _download_partial_path
	_download_request.set_meta("expected_sha256", expected_sha256)
	_download_request.set_meta("expected_size", expected_size)
	add_child(_download_request)
	_download_request.request_completed.connect(_on_download_request_completed, CONNECT_ONE_SHOT)
	_set_state(STATE_DOWNLOADING, "Скачиваем официальный установщик с GitHub Releases…")
	download_started.emit(latest_manifest.duplicate(true))
	var error := _download_request.request(str(asset["url"]), [
		"Accept: application/octet-stream",
		"User-Agent: FantasyDisk/%s" % current_version(),
	])
	if error != OK:
		_dispose_download_request()
		_remove_file_if_present(_download_partial_path)
		_set_state(STATE_ERROR, "Не удалось начать загрузку установщика.")
		download_finished.emit(false, "", last_message)
		return false
	return true


func launch_installer() -> bool:
	if downloaded_installer_path == "" or not FileAccess.file_exists(downloaded_installer_path):
		_set_state(STATE_ERROR, "Проверенный установщик не найден.")
		return false
	var absolute_path := ProjectSettings.globalize_path(downloaded_installer_path)
	var error := OK
	match OS.get_name():
		"Windows":
			var pid := OS.create_process(absolute_path, PackedStringArray())
			if pid <= 0:
				error = ERR_CANT_FORK
		"macOS":
			error = OS.shell_open(absolute_path)
		_:
			error = OS.shell_open(str(latest_manifest.get("release_url", DEFAULT_RELEASE_URL)))
	if error != OK:
		_set_state(STATE_ERROR, "Не удалось открыть установщик. Откройте страницу релиза вручную.")
		return false
	_set_state(STATE_INSTALLER_OPENED, _installer_opened_message(OS.get_name()))
	return true


func open_release_page() -> bool:
	var url := str(latest_manifest.get("release_url", DEFAULT_RELEASE_URL))
	if not _is_trusted_release_url(url):
		url = DEFAULT_RELEASE_URL
	return OS.shell_open(url) == OK


func _on_manifest_request_completed(
		result: int,
		response_code: int,
		_response_headers: PackedStringArray,
		body: PackedByteArray) -> void:
	var manual := _manual_check
	_dispose_manifest_request()
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_finish_check_error("Сервер обновлений недоступен. Проверьте интернет и повторите.", manual)
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	var validation := validate_manifest(parsed)
	if not bool(validation.get("ok", false)):
		_finish_check_error("Файл обновления повреждён: %s" % str(validation.get("error", "неизвестная ошибка")), manual)
		return
	latest_manifest = (validation["manifest"] as Dictionary).duplicate(true)
	var latest_version := str(latest_manifest["version"])
	if compare_versions(current_version(), latest_version) < 0:
		_set_state(STATE_AVAILABLE, "Доступна версия %s." % latest_version)
		check_finished.emit({
			"status": STATE_AVAILABLE,
			"current_version": current_version(),
			"latest_version": latest_version,
			"manifest": latest_manifest.duplicate(true),
			"message": last_message,
		}, manual)
	else:
		_set_state(STATE_CURRENT, "Установлена актуальная версия %s." % current_version())
		check_finished.emit({
			"status": STATE_CURRENT,
			"current_version": current_version(),
			"latest_version": latest_version,
			"manifest": latest_manifest.duplicate(true),
			"message": last_message,
		}, manual)


func _on_download_request_completed(
		result: int,
		response_code: int,
		_response_headers: PackedStringArray,
		_body: PackedByteArray) -> void:
	var expected_sha256 := str(_download_request.get_meta("expected_sha256", "")) if _download_request != null else ""
	var expected_size := int(_download_request.get_meta("expected_size", 0)) if _download_request != null else 0
	_dispose_download_request()
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_remove_file_if_present(_download_partial_path)
		_set_state(STATE_ERROR, "Загрузка прервана. Проверьте интернет и повторите.")
		download_finished.emit(false, "", last_message)
		return
	if _file_size(_download_partial_path) != expected_size:
		_remove_file_if_present(_download_partial_path)
		_set_state(STATE_ERROR, "Размер установщика не совпал с данными релиза.")
		download_finished.emit(false, "", last_message)
		return
	if FileAccess.get_sha256(_download_partial_path).to_lower() != expected_sha256:
		_remove_file_if_present(_download_partial_path)
		_set_state(STATE_ERROR, "SHA-256 установщика не совпал. Файл удалён.")
		download_finished.emit(false, "", last_message)
		return
	_remove_file_if_present(_download_final_path)
	var rename_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(_download_partial_path),
		ProjectSettings.globalize_path(_download_final_path))
	if rename_error != OK:
		_remove_file_if_present(_download_partial_path)
		_set_state(STATE_ERROR, "Не удалось сохранить проверенный установщик.")
		download_finished.emit(false, "", last_message)
		return
	downloaded_installer_path = _download_final_path
	_set_state(STATE_VERIFIED, "Установщик загружен и проверен по SHA-256.")
	download_finished.emit(true, downloaded_installer_path, last_message)


func _finish_check_error(message: String, manual: bool) -> void:
	_set_state(STATE_ERROR, message)
	check_finished.emit({
		"status": STATE_ERROR,
		"current_version": current_version(),
		"message": message,
	}, manual)


func _set_state(next_state: String, message: String) -> void:
	state = next_state
	last_message = message
	state_changed.emit(state, last_message)


func _dispose_manifest_request() -> void:
	if _manifest_request == null:
		return
	_manifest_request.queue_free()
	_manifest_request = null


func _dispose_download_request() -> void:
	if _download_request == null:
		return
	_download_request.download_file = ""
	_download_request.queue_free()
	_download_request = null


func _remove_file_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var size := file.get_length()
	file.close()
	return size


static func compare_versions(left: String, right: String) -> int:
	var left_parts := _semver_parts(left)
	var right_parts := _semver_parts(right)
	if left_parts.is_empty() or right_parts.is_empty():
		return 0
	for index in range(3):
		if int(left_parts[index]) < int(right_parts[index]):
			return -1
		if int(left_parts[index]) > int(right_parts[index]):
			return 1
	return 0


static func validate_manifest(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {"ok": false, "error": "корень должен быть объектом"}
	var manifest := (raw as Dictionary).duplicate(true)
	if int(manifest.get("schema_version", 0)) != MANIFEST_SCHEMA_VERSION:
		return {"ok": false, "error": "неподдерживаемая версия схемы"}
	var version := str(manifest.get("version", ""))
	if _semver_parts(version).is_empty():
		return {"ok": false, "error": "version не является SemVer X.Y.Z"}
	var minimum_supported := str(manifest.get("minimum_supported_version", version))
	if _semver_parts(minimum_supported).is_empty():
		return {"ok": false, "error": "minimum_supported_version не является SemVer X.Y.Z"}
	if compare_versions(minimum_supported, version) > 0:
		return {"ok": false, "error": "minimum_supported_version новее самого релиза"}
	if str(manifest.get("release_url", "")) != \
			"https://github.com/FomaBy/FantasyDisk/releases/tag/v%s" % version:
		return {"ok": false, "error": "release_url не принадлежит FantasyDisk Releases"}
	var assets_value: Variant = manifest.get("assets", null)
	if typeof(assets_value) != TYPE_DICTIONARY:
		return {"ok": false, "error": "assets должен быть объектом"}
	var assets := assets_value as Dictionary
	for platform_key in ["macos", "windows"]:
		if typeof(assets.get(platform_key, null)) != TYPE_DICTIONARY:
			return {"ok": false, "error": "отсутствует assets.%s" % platform_key}
		var asset := assets[platform_key] as Dictionary
		var name := str(asset.get("name", ""))
		var expected_name := "FantasyDisk-%s-macos.dmg" % version if platform_key == "macos" \
			else "FantasyDisk-%s-windows-setup.exe" % version
		if name != expected_name or name.get_file() != name:
			return {"ok": false, "error": "некорректное имя assets.%s" % platform_key}
		if not _is_trusted_release_download_url(str(asset.get("url", "")), version):
			return {"ok": false, "error": "недоверенный URL assets.%s" % platform_key}
		if not _is_sha256(str(asset.get("sha256", ""))):
			return {"ok": false, "error": "некорректный SHA-256 assets.%s" % platform_key}
		if int(asset.get("size", 0)) <= 0 or int(asset.get("size", 0)) > DOWNLOAD_BODY_LIMIT:
			return {"ok": false, "error": "некорректный размер assets.%s" % platform_key}
	return {"ok": true, "manifest": manifest}


static func asset_for_platform(manifest: Dictionary, platform_name: String) -> Dictionary:
	var platform_key := ""
	match platform_name:
		"macOS":
			platform_key = "macos"
		"Windows":
			platform_key = "windows"
		_:
			return {"ok": false, "error": "Автоустановка пока поддерживает macOS и Windows."}
	var assets: Dictionary = manifest.get("assets", {})
	if typeof(assets.get(platform_key, null)) != TYPE_DICTIONARY:
		return {"ok": false, "error": "В релизе нет установщика для %s." % platform_name}
	return {"ok": true, "asset": (assets[platform_key] as Dictionary).duplicate(true)}


static func _semver_parts(version: String) -> PackedInt32Array:
	var raw_parts := version.strip_edges().split(".")
	if raw_parts.size() != 3:
		return PackedInt32Array()
	var parsed := PackedInt32Array()
	for raw_part in raw_parts:
		var part := str(raw_part)
		if part == "" or not part.is_valid_int() or int(part) < 0:
			return PackedInt32Array()
		if part.length() > 1 and part.begins_with("0"):
			return PackedInt32Array()
		parsed.append(int(part))
	return parsed


static func _is_sha256(value: String) -> bool:
	var digest := value.to_lower()
	if digest.length() != 64:
		return false
	for character in digest:
		if not "0123456789abcdef".contains(character):
			return false
	return true


static func _is_trusted_manifest_url(url: String) -> bool:
	return url == DEFAULT_MANIFEST_URL \
		or url.begins_with("https://github.com/FomaBy/FantasyDisk/releases/download/")


static func _is_trusted_release_url(url: String) -> bool:
	return url.begins_with(TRUSTED_RELEASE_PREFIX)


static func _is_trusted_release_download_url(url: String, version: String) -> bool:
	return url.begins_with("https://github.com/FomaBy/FantasyDisk/releases/download/v%s/" % version)


static func macos_update_is_unsigned() -> bool:
	return MACOS_UPDATE_CHANNEL == "unsigned"


static func _installer_opened_message(platform_name: String) -> String:
	if platform_name == "macOS":
		var message := "DMG открыт. Перетащите FantasyDisk в Applications и перезапустите игру."
		if macos_update_is_unsigned():
			message += " " + MACOS_UNSIGNED_NOTICE
		return message
	if platform_name == "Windows":
		return "Установщик открыт. Следуйте его шагам; при запросе закройте игру."
	return "Страница релиза открыта в браузере."
