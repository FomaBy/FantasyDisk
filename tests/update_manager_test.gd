extends SceneTree

const UPDATE_MANAGER := preload("res://scripts/update_manager.gd")
const HASH_A := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const HASH_B := "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"


func _initialize() -> void:
	if not _check_version_ordering():
		quit(1)
		return
	if not _check_manifest_contract():
		quit(1)
		return
	if not _check_manifest_response_state():
		quit(1)
		return
	if not _check_unsigned_channel_trust_labeling():
		quit(1)
		return
	print("FAN-1112/FAN-1121 update manager manifest/SemVer/trust-labeling tests passed.")
	quit(0)


func _check_unsigned_channel_trust_labeling() -> bool:
	# FAN-1121: до возвращения Developer ID клиент обязан честно помечать
	# macOS-канал как unsigned и давать ручную Gatekeeper-инструкцию.
	if UPDATE_MANAGER.MACOS_UPDATE_CHANNEL != "unsigned":
		return _fail("macOS update channel label must be 'unsigned' (FAN-1121), got '%s'." % UPDATE_MANAGER.MACOS_UPDATE_CHANNEL)
	if not UPDATE_MANAGER.macos_update_is_unsigned():
		return _fail("macos_update_is_unsigned() must reflect the unsigned channel.")
	var opened: String = UPDATE_MANAGER._installer_opened_message("macOS")
	if not opened.contains("без подписи Apple Developer ID"):
		return _fail("macOS installer-opened message must disclose the unsigned build: %s" % opened)
	if not opened.contains("Конфиденциальность и безопасность") or not opened.contains("Всё равно открыть"):
		return _fail("macOS installer-opened message must give the manual Gatekeeper Open Anyway path: %s" % opened)
	if opened.contains("нотаризован") or opened.contains("notarized"):
		return _fail("macOS installer-opened message must not claim notarization: %s" % opened)
	var windows_opened: String = UPDATE_MANAGER._installer_opened_message("Windows")
	if windows_opened.contains("Gatekeeper") or windows_opened.contains("Всё равно открыть"):
		return _fail("Windows installer-opened message must not carry macOS Gatekeeper guidance: %s" % windows_opened)
	return true


func _check_version_ordering() -> bool:
	var cases := [
		["0.2.2", "0.2.2", 0],
		["0.2.1", "0.2.2", -1],
		["0.10.0", "0.2.99", 1],
		["1.0.0", "0.99.99", 1],
		["invalid", "0.2.2", 0],
	]
	for case in cases:
		var actual: int = UPDATE_MANAGER.compare_versions(case[0], case[1])
		if actual != case[2]:
			return _fail("SemVer ordering failed for %s vs %s: %d" % [case[0], case[1], actual])
	return true


func _check_manifest_contract() -> bool:
	var manifest := _valid_manifest()
	var validation: Dictionary = UPDATE_MANAGER.validate_manifest(manifest)
	if not bool(validation.get("ok", false)):
		return _fail("Valid manifest rejected: %s" % str(validation))
	var macos: Dictionary = UPDATE_MANAGER.asset_for_platform(manifest, "macOS")
	var windows: Dictionary = UPDATE_MANAGER.asset_for_platform(manifest, "Windows")
	if not bool(macos.get("ok", false)) or str((macos["asset"] as Dictionary).get("name", "")) != "FantasyDisk-0.2.4-macos.dmg":
		return _fail("macOS asset selection failed.")
	if not bool(windows.get("ok", false)) or str((windows["asset"] as Dictionary).get("name", "")) != "FantasyDisk-0.2.4-windows-setup.exe":
		return _fail("Windows asset selection failed.")
	if bool(UPDATE_MANAGER.asset_for_platform(manifest, "Linux").get("ok", true)):
		return _fail("Unsupported platform was accepted.")

	var hostile := manifest.duplicate(true)
	hostile["assets"]["windows"]["url"] = "https://example.com/FantasyDisk.exe"
	if bool(UPDATE_MANAGER.validate_manifest(hostile).get("ok", true)):
		return _fail("Untrusted installer URL was accepted.")
	var bad_hash := manifest.duplicate(true)
	bad_hash["assets"]["macos"]["sha256"] = "not-a-hash"
	if bool(UPDATE_MANAGER.validate_manifest(bad_hash).get("ok", true)):
		return _fail("Malformed SHA-256 was accepted.")
	var bad_version := manifest.duplicate(true)
	bad_version["version"] = "0.2.3-beta"
	if bool(UPDATE_MANAGER.validate_manifest(bad_version).get("ok", true)):
		return _fail("Non-strict SemVer was accepted.")
	var future_minimum := manifest.duplicate(true)
	future_minimum["minimum_supported_version"] = "0.2.5"
	if bool(UPDATE_MANAGER.validate_manifest(future_minimum).get("ok", true)):
		return _fail("A minimum version newer than the release was accepted.")
	return true


func _valid_manifest() -> Dictionary:
	return {
		"schema_version": 1,
		"version": "0.2.4",
		"minimum_supported_version": "0.2.2",
		"release_url": "https://github.com/FomaBy/FantasyDisk/releases/tag/v0.2.4",
		"assets": {
			"macos": {
				"name": "FantasyDisk-0.2.4-macos.dmg",
				"url": "https://github.com/FomaBy/FantasyDisk/releases/download/v0.2.4/FantasyDisk-0.2.4-macos.dmg",
				"sha256": HASH_A,
				"size": 123456,
			},
			"windows": {
				"name": "FantasyDisk-0.2.4-windows-setup.exe",
				"url": "https://github.com/FomaBy/FantasyDisk/releases/download/v0.2.4/FantasyDisk-0.2.4-windows-setup.exe",
				"sha256": HASH_B,
				"size": 654321,
			},
		},
	}


func _check_manifest_response_state() -> bool:
	var manager := UPDATE_MANAGER.new()
	root.add_child(manager)
	var captured := {"result": {}}
	manager.check_finished.connect(func(result: Dictionary, manual: bool) -> void:
		captured["result"] = result.duplicate(true)
		captured["result"]["manual"] = manual
	)
	manager._manual_check = false
	var body := JSON.stringify(_valid_manifest()).to_utf8_buffer()
	manager._on_manifest_request_completed(
		HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), body)
	if manager.state != manager.STATE_AVAILABLE:
		manager.free()
		return _fail("New manifest did not enter available state.")
	var captured_result := captured["result"] as Dictionary
	if str(captured_result.get("latest_version", "")) != "0.2.4" or bool(captured_result.get("manual", true)):
		manager.free()
		return _fail("Available response signal lost version/manual state: %s" % str(captured))
	manager.free()
	return true


func _fail(message: String) -> bool:
	push_error(message)
	return false
