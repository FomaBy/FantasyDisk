extends SceneTree

const UPDATE_MANAGER := preload("res://scripts/update_manager.gd")
const STAGED_MANIFEST_PATH := "/releases/latest/download/update-manifest.json"
const WAIT_TIMEOUT_MS := 15000


# This subclass is the only staging seam. It lives under tests/, which both
# production export presets exclude, and changes only exact endpoint strings.
class StagedUpdateManager extends UPDATE_MANAGER:
	var staging_origin := ""
	var opened_paths := PackedStringArray()
	var opened_release_urls := PackedStringArray()

	func configure_staging(origin: String) -> bool:
		if not _is_loopback_origin(origin):
			staging_origin = ""
			return false
		staging_origin = origin
		return true

	func manifest_url() -> String:
		return "%s%s" % [staging_origin, STAGED_MANIFEST_PATH]

	func _is_allowed_manifest_url(url: String) -> bool:
		return staging_origin != "" and url == manifest_url()

	func _is_allowed_release_url(url: String) -> bool:
		return staging_origin != "" and url == _staged_release_url(str(latest_manifest.get("version", "")))

	func _validate_manifest(raw: Variant) -> Dictionary:
		if typeof(raw) != TYPE_DICTIONARY:
			return UPDATE_MANAGER.validate_manifest(raw)
		var staged := (raw as Dictionary).duplicate(true)
		var version := str(staged.get("version", ""))
		if staging_origin == "" or str(staged.get("release_url", "")) != _staged_release_url(version):
			return {"ok": false, "error": "staged release_url is not exact"}
		var staged_assets: Variant = staged.get("assets", null)
		if typeof(staged_assets) != TYPE_DICTIONARY:
			return {"ok": false, "error": "staged assets are missing"}
		var production := staged.duplicate(true)
		production["release_url"] = "https://github.com/FomaBy/FantasyDisk-Releases/releases/tag/v%s" % version
		var production_assets := production["assets"] as Dictionary
		for platform_key in ["macos", "windows"]:
			var staged_asset: Variant = (staged_assets as Dictionary).get(platform_key, null)
			if typeof(staged_asset) != TYPE_DICTIONARY:
				return {"ok": false, "error": "staged asset is missing"}
			var name := str((staged_asset as Dictionary).get("name", ""))
			if str((staged_asset as Dictionary).get("url", "")) != _staged_download_url(version, name):
				return {"ok": false, "error": "staged asset URL is not exact"}
			var production_asset := production_assets[platform_key] as Dictionary
			production_asset["url"] = "https://github.com/FomaBy/FantasyDisk-Releases/releases/download/v%s/%s" % [version, name]
		var validation := UPDATE_MANAGER.validate_manifest(production)
		if not bool(validation.get("ok", false)):
			return validation
		return {"ok": true, "manifest": staged}

	func _platform_name() -> String:
		return "Windows"

	func _open_installer(absolute_path: String, release_url: String) -> int:
		opened_paths.append(absolute_path)
		opened_release_urls.append(release_url)
		return OK

	func _staged_release_url(version: String) -> String:
		return "%s/releases/tag/v%s" % [staging_origin, version]

	func _staged_download_url(version: String, name: String) -> String:
		return "%s/releases/download/v%s/%s" % [staging_origin, version, name]

	func _is_loopback_origin(origin: String) -> bool:
		var prefix := "http://127.0.0.1:"
		if not origin.begins_with(prefix):
			return false
		var raw_port := origin.trim_prefix(prefix)
		if raw_port == "":
			return false
		for character in raw_port:
			if not "0123456789".contains(character):
				return false
		var port := int(raw_port)
		return port > 0 and port <= 65535 and origin == "%s%d" % [prefix, port]


class LoopbackServer:
	var _listener := TCPServer.new()
	var _connections: Array = []
	var routes := {}
	var requests := PackedStringArray()

	func start() -> String:
		if _listener.listen(0, "127.0.0.1") != OK:
			return ""
		return "http://127.0.0.1:%d" % _listener.get_local_port()

	func stop() -> void:
		for connection in _connections:
			var peer := (connection as Dictionary).get("peer", null) as StreamPeerTCP
			if peer != null:
				peer.disconnect_from_host()
		_connections.clear()
		_listener.stop()

	func set_response(path: String, code: int, body: PackedByteArray = PackedByteArray()) -> void:
		routes[path] = {"code": code, "body": body}

	func clear_routes() -> void:
		routes.clear()
		requests.clear()

	func poll() -> void:
		while _listener.is_connection_available():
			_connections.append({"peer": _listener.take_connection(), "buffer": PackedByteArray()})
		for index in range(_connections.size() - 1, -1, -1):
			var connection := _connections[index] as Dictionary
			var peer := connection.get("peer", null) as StreamPeerTCP
			if peer == null:
				_connections.remove_at(index)
				continue
			peer.poll()
			var status := peer.get_status()
			if status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
				_connections.remove_at(index)
				continue
			if status != StreamPeerTCP.STATUS_CONNECTED:
				continue
			var available := peer.get_available_bytes()
			if available <= 0:
				continue
			var received: Array = peer.get_data(available)
			if int(received[0]) != OK:
				peer.disconnect_from_host()
				_connections.remove_at(index)
				continue
			var buffer := connection.get("buffer", PackedByteArray()) as PackedByteArray
			buffer.append_array(received[1] as PackedByteArray)
			if buffer.get_string_from_utf8().find("\r\n\r\n") < 0:
				connection["buffer"] = buffer
				_connections[index] = connection
				continue
			_respond(peer, buffer)
			peer.disconnect_from_host()
			_connections.remove_at(index)

	func _respond(peer: StreamPeerTCP, request: PackedByteArray) -> void:
		var request_line := request.get_string_from_utf8().get_slice("\r\n", 0)
		var parts := request_line.split(" ")
		var path := str(parts[1]) if parts.size() >= 2 else ""
		requests.append(path)
		var response := routes.get(path, {"code": 404, "body": PackedByteArray()}) as Dictionary
		var code := int(response.get("code", 404))
		var body := response.get("body", PackedByteArray()) as PackedByteArray
		var reason := "OK" if code >= 200 and code < 300 else "Not Found"
		var packet := ("HTTP/1.1 %d %s\r\nContent-Type: application/octet-stream\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % [code, reason, body.size()]).to_utf8_buffer()
		packet.append_array(body)
		peer.put_data(packet)


var _errors: Array[String] = []


func _initialize() -> void:
	if not _require_scratch_user_dir():
		quit(2)
		return
	await _run()
	if not _errors.is_empty():
		for error in _errors:
			push_error("update_manager_staged_lifecycle_test: %s" % error)
		quit(1)
		return
	print("FAN-2492 staged updater HTTP lifecycle tests passed.")
	quit(0)


func _run() -> void:
	var server := LoopbackServer.new()
	var origin := server.start()
	_expect(origin != "", "loopback staging server did not start")
	if origin == "":
		return
	var version := _next_version(str(ProjectSettings.get_setting("application/config/version", "0.0.0")))
	var production_manifest := _production_manifest(version)
	var staged_manifest := _staged_manifest(production_manifest, origin)
	_check_policy_negative_controls(origin, production_manifest, staged_manifest)
	_check_endpoint_pins(production_manifest, staged_manifest)

	await _check_success_and_launch(server, origin, production_manifest, staged_manifest)
	await _check_hash_mismatch(server, origin, production_manifest, staged_manifest)
	await _check_size_mismatch(server, origin, production_manifest, staged_manifest)
	await _check_download_404(server, origin, production_manifest, staged_manifest)
	await _check_manifest_404(server, origin, production_manifest)
	server.stop()
	await _check_offline(origin, production_manifest)


func _check_policy_negative_controls(origin: String, production: Dictionary, staged: Dictionary) -> void:
	var base := UPDATE_MANAGER.new()
	_expect(base.manifest_url() == UPDATE_MANAGER.DEFAULT_MANIFEST_URL,
		"base manager no longer returns the production manifest policy")
	_expect(not base._is_allowed_manifest_url("%s%s" % [origin, STAGED_MANIFEST_PATH]),
		"production manager accepted a task-local staging endpoint")
	_expect(not bool(UPDATE_MANAGER.validate_manifest(staged).get("ok", true)),
		"production manifest validator accepted staged endpoint representation")
	base.free()
	for hostile_origin in [
		"https://example.com",
		"file:///tmp/staging",
		"http://localhost:8123",
		"http://127.0.0.1:8123/path",
		"http://127.0.0.1:0",
	]:
		var manager := StagedUpdateManager.new()
		_expect(not manager.configure_staging(hostile_origin), "test seam accepted %s" % hostile_origin)
		manager.free()
	var staged_manager := StagedUpdateManager.new()
	_expect(staged_manager.configure_staging(origin), "test seam rejected its exact loopback origin")
	var hostile_manifest := staged.duplicate(true)
	(hostile_manifest["assets"] as Dictionary)["windows"]["url"] = "file:///tmp/FantasyDisk.exe"
	_expect(not bool(staged_manager._validate_manifest(hostile_manifest).get("ok", true)),
		"test seam accepted a file URL")
	var traversal_manifest := staged.duplicate(true)
	var traversal_url := "%s/releases/download/v%s/FantasyDisk-%s-windows-setup.exe/../escape.exe" % [
		origin, str(production["version"]), str(production["version"]),
	]
	(traversal_manifest["assets"] as Dictionary)["windows"]["url"] = traversal_url
	_expect(not bool(staged_manager._validate_manifest(traversal_manifest).get("ok", true)),
		"test seam accepted a traversal-like asset URL")
	staged_manager.free()
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	_expect(presets.count("tests/*") >= 2, "both production export presets must exclude tests/*")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	_expect(main_source.contains("UPDATE_MANAGER_SCRIPT := preload(\"res://scripts/update_manager.gd\")"),
		"production main must preload the base update manager")
	_expect(main_source.contains("UPDATE_MANAGER_SCRIPT.new()"),
		"production main must instantiate the base update manager")


func _check_endpoint_pins(production: Dictionary, staged: Dictionary) -> void:
	_expect(str(production.get("version", "")) == str(staged.get("version", "")), "staging changed the release version")
	for platform_key in ["macos", "windows"]:
		var production_asset := (production["assets"] as Dictionary)[platform_key] as Dictionary
		var staged_asset := (staged["assets"] as Dictionary)[platform_key] as Dictionary
		for key in ["name", "size", "sha256"]:
			_expect(production_asset.get(key) == staged_asset.get(key), "staging changed %s.%s" % [platform_key, key])


func _check_success_and_launch(server: LoopbackServer, origin: String, production: Dictionary, staged: Dictionary) -> void:
	server.clear_routes()
	var version := str(production["version"])
	var windows_asset := ((production["assets"] as Dictionary)["windows"] as Dictionary)
	server.set_response(STAGED_MANIFEST_PATH, 200, JSON.stringify(staged).to_utf8_buffer())
	server.set_response("/releases/download/v%s/%s" % [version, str(windows_asset["name"])], 200, _package_bytes("windows"))
	_clean_update_paths(version)
	var manager := await _new_manager(origin)
	var check := await _request_check(manager, server)
	_expect(bool(check.get("done", false)) and manager.state == manager.STATE_AVAILABLE,
		"real staged manifest did not enter available state")
	var download := await _request_download(manager, server)
	var final_path := str(download.get("path", ""))
	_expect(bool(download.get("done", false)) and bool(download.get("success", false)),
		"real staged installer download did not succeed")
	_expect(final_path != "" and FileAccess.file_exists(final_path), "verified staged installer was not retained")
	_expect(not FileAccess.file_exists("%s.partial" % final_path), "verified staged installer retained a partial file")
	_expect(FileAccess.get_sha256(final_path).to_lower() == str(windows_asset["sha256"]),
		"retained staged installer SHA pin changed")
	_expect(manager.launch_installer(), "verified staged installer did not reach launcher boundary")
	_expect(manager.opened_paths.size() == 1 and manager.opened_release_urls[0] == str(staged["release_url"]),
		"launcher boundary did not receive the staged verified installer")
	var replaced := _different_bytes(_package_bytes("windows"))
	var file := FileAccess.open(final_path, FileAccess.WRITE)
	if file == null:
		_expect(false, "could not replace cached installer for stale-byte control")
	else:
		file.store_buffer(replaced)
		file.close()
		_expect(not manager.launch_installer(), "stale installer bytes reached the launch boundary")
		_expect(manager.opened_paths.size() == 1, "stale installer invoked the launch boundary")
		_expect(not FileAccess.file_exists(final_path) and manager.downloaded_installer_path == "",
			"stale installer was not removed and cleared")
	_expect(server.requests.has(STAGED_MANIFEST_PATH), "success case did not use real HTTP manifest fetch")
	_expect(server.requests.has("/releases/download/v%s/%s" % [version, str(windows_asset["name"])]),
		"success case did not use real HTTP installer download")
	await _dispose_manager(manager)


func _check_hash_mismatch(server: LoopbackServer, origin: String, production: Dictionary, staged: Dictionary) -> void:
	server.clear_routes()
	var version := str(production["version"])
	var windows_asset := ((production["assets"] as Dictionary)["windows"] as Dictionary)
	server.set_response(STAGED_MANIFEST_PATH, 200, JSON.stringify(staged).to_utf8_buffer())
	server.set_response("/releases/download/v%s/%s" % [version, str(windows_asset["name"])], 200, _different_bytes(_package_bytes("windows")))
	_clean_update_paths(version)
	var manager := await _new_manager(origin)
	await _request_check(manager, server)
	var download := await _request_download(manager, server)
	_expect(bool(download.get("done", false)) and not bool(download.get("success", true)) and manager.state == manager.STATE_ERROR,
		"hash mismatch did not fail the real download")
	_expect(not FileAccess.file_exists(_installer_path(version)) and not FileAccess.file_exists("%s.partial" % _installer_path(version)),
		"hash mismatch left staged installer bytes behind")
	_expect(manager.opened_paths.is_empty(), "hash mismatch reached launcher boundary")
	await _dispose_manager(manager)


func _check_size_mismatch(server: LoopbackServer, origin: String, production: Dictionary, staged: Dictionary) -> void:
	server.clear_routes()
	var version := str(production["version"])
	var windows_asset := ((production["assets"] as Dictionary)["windows"] as Dictionary)
	server.set_response(STAGED_MANIFEST_PATH, 200, JSON.stringify(staged).to_utf8_buffer())
	server.set_response("/releases/download/v%s/%s" % [version, str(windows_asset["name"])], 200, _package_bytes("windows").slice(0, 7))
	_clean_update_paths(version)
	var manager := await _new_manager(origin)
	await _request_check(manager, server)
	var download := await _request_download(manager, server)
	_expect(bool(download.get("done", false)) and not bool(download.get("success", true)) and manager.state == manager.STATE_ERROR,
		"size mismatch did not fail the real download")
	_expect(not FileAccess.file_exists(_installer_path(version)) and not FileAccess.file_exists("%s.partial" % _installer_path(version)),
		"size mismatch left staged installer bytes behind")
	_expect(manager.opened_paths.is_empty(), "size mismatch reached launcher boundary")
	await _dispose_manager(manager)


func _check_download_404(server: LoopbackServer, origin: String, production: Dictionary, staged: Dictionary) -> void:
	server.clear_routes()
	var version := str(production["version"])
	server.set_response(STAGED_MANIFEST_PATH, 200, JSON.stringify(staged).to_utf8_buffer())
	_clean_update_paths(version)
	var manager := await _new_manager(origin)
	await _request_check(manager, server)
	var download := await _request_download(manager, server)
	_expect(bool(download.get("done", false)) and not bool(download.get("success", true)) and manager.state == manager.STATE_ERROR,
		"installer 404 did not fail the real download")
	_expect(not FileAccess.file_exists(_installer_path(version)) and not FileAccess.file_exists("%s.partial" % _installer_path(version)),
		"installer 404 left partial or stale bytes behind")
	_expect(manager.opened_paths.is_empty(), "installer 404 reached launcher boundary")
	await _dispose_manager(manager)


func _check_manifest_404(server: LoopbackServer, origin: String, production: Dictionary) -> void:
	server.clear_routes()
	var version := str(production["version"])
	_clean_update_paths(version)
	var manager := await _new_manager(origin)
	var check := await _request_check(manager, server)
	_expect(bool(check.get("done", false)) and manager.state == manager.STATE_ERROR,
		"manifest 404 did not finish in the error state")
	_expect(not FileAccess.file_exists(_installer_path(version)) and not FileAccess.file_exists("%s.partial" % _installer_path(version)),
		"manifest 404 created installer bytes")
	await _dispose_manager(manager)


func _check_offline(origin: String, production: Dictionary) -> void:
	var version := str(production["version"])
	_clean_update_paths(version)
	var manager := await _new_manager(origin)
	var server := LoopbackServer.new()
	var check := await _request_check(manager, server)
	_expect(bool(check.get("done", false)) and manager.state == manager.STATE_ERROR and not manager.is_busy(),
		"offline staged endpoint did not cleanly finish in the error state")
	_expect(not FileAccess.file_exists(_installer_path(version)) and not FileAccess.file_exists("%s.partial" % _installer_path(version)),
		"offline staged endpoint left installer bytes")
	await _dispose_manager(manager)


func _new_manager(origin: String) -> StagedUpdateManager:
	var manager := StagedUpdateManager.new()
	_expect(manager.configure_staging(origin), "could not configure exact staging origin")
	root.add_child(manager)
	await process_frame
	return manager


func _dispose_manager(manager: Node) -> void:
	manager.queue_free()
	await process_frame


func _request_check(manager: StagedUpdateManager, server: LoopbackServer) -> Dictionary:
	var captured := {"done": false}
	manager.check_finished.connect(func(result: Dictionary, manual: bool) -> void:
		captured["done"] = true
		captured["result"] = result.duplicate(true)
		captured["manual"] = manual
	)
	_expect(manager.check_for_updates(true), "staged manifest request did not start")
	await _wait_until(server, func() -> bool: return bool(captured.get("done", false)), "manifest request")
	_expect(not manager.is_busy(), "manifest request remained active after completion")
	return captured


func _request_download(manager: StagedUpdateManager, server: LoopbackServer) -> Dictionary:
	var captured := {"done": false}
	manager.download_finished.connect(func(success: bool, installer_path: String, message: String) -> void:
		captured["done"] = true
		captured["success"] = success
		captured["path"] = installer_path
		captured["message"] = message
	)
	_expect(manager.download_installer(), "staged installer request did not start")
	await _wait_until(server, func() -> bool: return bool(captured.get("done", false)), "installer request")
	_expect(not manager.is_busy(), "installer request remained active after completion")
	return captured


func _wait_until(server: LoopbackServer, predicate: Callable, label: String) -> void:
	var deadline := Time.get_ticks_msec() + WAIT_TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		server.poll()
		if bool(predicate.call()):
			return
		await process_frame
	server.poll()
	_expect(bool(predicate.call()), "%s timed out" % label)


func _production_manifest(version: String) -> Dictionary:
	var macos_bytes := _package_bytes("macos")
	var windows_bytes := _package_bytes("windows")
	return {
		"schema_version": 1,
		"version": version,
		"minimum_supported_version": str(ProjectSettings.get_setting("application/config/version", "0.0.0")),
		"release_url": "https://github.com/FomaBy/FantasyDisk-Releases/releases/tag/v%s" % version,
		"assets": {
			"macos": _production_asset(version, "macos", "dmg", macos_bytes),
			"windows": _production_asset(version, "windows-setup", "exe", windows_bytes),
		},
	}


func _production_asset(version: String, suffix: String, extension: String, bytes: PackedByteArray) -> Dictionary:
	var name := "FantasyDisk-%s-%s.%s" % [version, suffix, extension]
	return {
		"name": name,
		"url": "https://github.com/FomaBy/FantasyDisk-Releases/releases/download/v%s/%s" % [version, name],
		"sha256": _sha256(bytes),
		"size": bytes.size(),
	}


func _staged_manifest(production: Dictionary, origin: String) -> Dictionary:
	var staged := production.duplicate(true)
	var version := str(staged["version"])
	staged["release_url"] = "%s/releases/tag/v%s" % [origin, version]
	for platform_key in ["macos", "windows"]:
		var asset := (staged["assets"] as Dictionary)[platform_key] as Dictionary
		asset["url"] = "%s/releases/download/v%s/%s" % [origin, version, str(asset["name"])]
	return staged


func _package_bytes(platform_key: String) -> PackedByteArray:
	return ("FAN-2492 task-local %s installer bytes\\n" % platform_key).to_utf8_buffer()


func _different_bytes(bytes: PackedByteArray) -> PackedByteArray:
	var changed := bytes.duplicate()
	if changed.is_empty():
		changed.append(1)
	else:
		changed[0] = (int(changed[0]) + 1) % 256
	return changed


func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func _installer_path(version: String) -> String:
	return "user://updates/FantasyDisk-%s-windows-setup.exe" % version


func _clean_update_paths(version: String) -> void:
	for suffix in ["macos.dmg", "windows-setup.exe"]:
		var path := "user://updates/FantasyDisk-%s-%s" % [version, suffix]
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if FileAccess.file_exists("%s.partial" % path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("%s.partial" % path))


func _next_version(version: String) -> String:
	var parts := version.split(".")
	var major := int(parts[0]) if parts.size() > 0 else 0
	var minor := int(parts[1]) if parts.size() > 1 else 0
	var patch := int(parts[2]) if parts.size() > 2 else 0
	if patch < UPDATE_MANAGER.MAX_RELEASE_PATCH:
		patch += 1
	elif minor < UPDATE_MANAGER.MAX_RELEASE_MINOR:
		minor += 1
		patch = 0
	else:
		major += 1
		minor = 0
		patch = 0
	return "%d.%d.%d" % [major, minor, patch]


func _require_scratch_user_dir() -> bool:
	var requested := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--user-data-dir="):
			requested = argument.trim_prefix("--user-data-dir=").simplify_path()
			break
	var actual := OS.get_user_data_dir().simplify_path()
	if requested == "" or requested == "/" or not actual.begins_with(requested.rstrip("/") + "/"):
		_expect(false, "test requires an isolated --user-data-dir")
		return false
	return true


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
