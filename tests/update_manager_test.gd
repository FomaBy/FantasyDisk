extends SceneTree

const UPDATE_MANAGER := preload("res://scripts/update_manager.gd")
const HASH_A := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const HASH_B := "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
const VERSION_CONTRACT_PATH := "res://tests/release_version_contract.json"


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
	if not _check_macos_channel_trust_labeling():
		quit(1)
		return
	print("FAN-1112/FAN-1121/FAN-2307 update manager manifest/SemVer/trust-labeling tests passed.")
	quit(0)


func _check_macos_channel_trust_labeling() -> bool:
	if UPDATE_MANAGER.MACOS_UPDATE_CHANNEL != "signed":
		return _fail("Current macOS update channel label must be 'signed' (FAN-2307), got '%s'." % UPDATE_MANAGER.MACOS_UPDATE_CHANNEL)
	if UPDATE_MANAGER.macos_update_is_unsigned():
		return _fail("macos_update_is_unsigned() must be false for the signed current channel.")
	# FAN-1121 remains the truthful contract for an explicitly relabelled
	# unsigned tag even though it is no longer the current product channel.
	if not UPDATE_MANAGER.MACOS_UNSIGNED_NOTICE.contains("без подписи Apple Developer ID") \
			or not UPDATE_MANAGER.MACOS_UNSIGNED_NOTICE.contains("Конфиденциальность и безопасность") \
			or not UPDATE_MANAGER.MACOS_UNSIGNED_NOTICE.contains("Всё равно открыть"):
		return _fail("Explicit unsigned fallback notice lost its Gatekeeper disclosure.")
	var opened: String = UPDATE_MANAGER._installer_opened_message("macOS")
	if opened.contains("без подписи Apple Developer ID") \
			or opened.contains("Конфиденциальность и безопасность") \
			or opened.contains("Всё равно открыть"):
		return _fail("Signed macOS installer-opened message must not carry unsigned/Open Anyway disclosure: %s" % opened)
	var windows_opened: String = UPDATE_MANAGER._installer_opened_message("Windows")
	if windows_opened != "Установщик открыт. Следуйте его шагам; при запросе закройте игру.":
		return _fail("Windows installer-opened copy changed: %s" % windows_opened)
	return true


func _check_version_ordering() -> bool:
	var cases := [
		["0.2.2", "0.2.2", 0],
		["0.2.1", "0.2.2", -1],
		["0.2.3", "0.2.3.1", -1],
		["0.2.3.1", "0.2.4", -1],
		["0.2.3.1", "0.2.3", 1],
		["0.2.3.0", "0.2.3", 0],
		["0.10.0", "0.2.9", 1],
		["1.0.0", "0.99.9", 1],
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
	var manager := UPDATE_MANAGER.new()
	if manager.manifest_url() != UPDATE_MANAGER.DEFAULT_MANIFEST_URL:
		manager.free()
		return _fail("Production manifest URL changed from the canonical default.")
	manager.free()
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
	for hostile_url in [
		"file:///tmp/FantasyDisk-0.2.4-windows-setup.exe",
		"https://github.com/FomaBy/FantasyDisk-Releases/releases/download/v0.2.4/other.exe",
		"https://github.com/FomaBy/FantasyDisk-Releases/releases/download/v0.2.4/FantasyDisk-0.2.4-windows-setup.exe/../other.exe",
		"https://github.com/FomaBy/FantasyDisk-Releases/releases/download/v0.2.4/FantasyDisk-0.2.4-windows-setup.exe?stale=1",
		"https://github.com/FomaBy/FantasyDisk-Releases/releases/download/v0.2.4/FantasyDisk-0.2.4-windows-setup.exe#fragment",
	]:
		var malformed_url := manifest.duplicate(true)
		malformed_url["assets"]["windows"]["url"] = hostile_url
		if bool(UPDATE_MANAGER.validate_manifest(malformed_url).get("ok", true)):
			return _fail("Non-canonical installer URL was accepted: %s" % hostile_url)
	var wrong_release := manifest.duplicate(true)
	wrong_release["release_url"] = "https://github.com/FomaBy/FantasyDisk-Releases/releases/tag/v0.2.3"
	if bool(UPDATE_MANAGER.validate_manifest(wrong_release).get("ok", true)):
		return _fail("Mismatched release URL was accepted.")
	var bad_hash := manifest.duplicate(true)
	bad_hash["assets"]["macos"]["sha256"] = "not-a-hash"
	if bool(UPDATE_MANAGER.validate_manifest(bad_hash).get("ok", true)):
		return _fail("Malformed SHA-256 was accepted.")
	var bad_version := manifest.duplicate(true)
	bad_version["version"] = "0.2.3-beta"
	if bool(UPDATE_MANAGER.validate_manifest(bad_version).get("ok", true)):
		return _fail("Malformed release version was accepted.")
	var invalid_versions := _version_contract_values("invalid")
	if invalid_versions.is_empty():
		return _fail("Shared release-version invalid matrix is missing.")
	for invalid_version in invalid_versions:
		var invalid_manifest := manifest.duplicate(true)
		invalid_manifest["version"] = invalid_version
		if bool(UPDATE_MANAGER.validate_manifest(invalid_manifest).get("ok", true)):
			return _fail("Non-canonical release version was accepted: %s" % invalid_version)
	var valid_versions := _version_contract_values("valid")
	if valid_versions.is_empty():
		return _fail("Shared release-version valid matrix is missing.")
	for valid_version in valid_versions:
		if UPDATE_MANAGER._release_version_parts(valid_version).is_empty():
			return _fail("Canonical release version was rejected: %s" % valid_version)
	var hotfix := manifest.duplicate(true)
	hotfix["version"] = "0.2.3.1"
	hotfix["release_url"] = "https://github.com/FomaBy/FantasyDisk-Releases/releases/tag/v0.2.3.1"
	for platform_key in ["macos", "windows"]:
		var asset := hotfix["assets"][platform_key] as Dictionary
		var extension := "dmg" if platform_key == "macos" else "exe"
		var suffix := "macos" if platform_key == "macos" else "windows-setup"
		asset["name"] = "FantasyDisk-0.2.3.1-%s.%s" % [suffix, extension]
		asset["url"] = "https://github.com/FomaBy/FantasyDisk-Releases/releases/download/v0.2.3.1/%s" % asset["name"]
	if not bool(UPDATE_MANAGER.validate_manifest(hotfix).get("ok", false)):
		return _fail("Four-component technical hotfix manifest was rejected.")
	var too_many_parts := manifest.duplicate(true)
	too_many_parts["version"] = "0.2.3.1.1"
	if bool(UPDATE_MANAGER.validate_manifest(too_many_parts).get("ok", true)):
		return _fail("Five-component release version was accepted.")
	var future_minimum := manifest.duplicate(true)
	future_minimum["minimum_supported_version"] = "0.2.5"
	if bool(UPDATE_MANAGER.validate_manifest(future_minimum).get("ok", true)):
		return _fail("A minimum version newer than the release was accepted.")
	return true


func _version_contract_values(key: String) -> PackedStringArray:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(VERSION_CONTRACT_PATH))
	if typeof(raw) != TYPE_DICTIONARY:
		return PackedStringArray()
	var values: Variant = (raw as Dictionary).get(key, null)
	if typeof(values) != TYPE_ARRAY:
		return PackedStringArray()
	var result := PackedStringArray()
	for value in values as Array:
		if typeof(value) != TYPE_STRING:
			return PackedStringArray()
		result.append(value)
	return result


func _valid_manifest() -> Dictionary:
	return {
		"schema_version": 1,
		"version": "0.2.4",
		"minimum_supported_version": "0.2.2",
		"release_url": "https://github.com/FomaBy/FantasyDisk-Releases/releases/tag/v0.2.4",
		"assets": {
			"macos": {
				"name": "FantasyDisk-0.2.4-macos.dmg",
				"url": "https://github.com/FomaBy/FantasyDisk-Releases/releases/download/v0.2.4/FantasyDisk-0.2.4-macos.dmg",
				"sha256": HASH_A,
				"size": 123456,
			},
			"windows": {
				"name": "FantasyDisk-0.2.4-windows-setup.exe",
				"url": "https://github.com/FomaBy/FantasyDisk-Releases/releases/download/v0.2.4/FantasyDisk-0.2.4-windows-setup.exe",
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
	# Derive a canonical release strictly newer than the manager's own
	# current_version() (project.godot) instead of a hard-coded synthetic
	# version, so this state-machine test keeps exercising STATE_AVAILABLE
	# across future version bumps (FAN-2469).
	var future_version := _next_canonical_version(manager.current_version())
	var manifest := _valid_manifest()
	manifest["version"] = future_version
	manifest["release_url"] = "https://github.com/FomaBy/FantasyDisk-Releases/releases/tag/v%s" % future_version
	for platform_key in ["macos", "windows"]:
		var asset := manifest["assets"][platform_key] as Dictionary
		var extension := "dmg" if platform_key == "macos" else "exe"
		var suffix := "macos" if platform_key == "macos" else "windows-setup"
		asset["name"] = "FantasyDisk-%s-%s.%s" % [future_version, suffix, extension]
		asset["url"] = "https://github.com/FomaBy/FantasyDisk-Releases/releases/download/v%s/%s" % [future_version, asset["name"]]
	var body := JSON.stringify(manifest).to_utf8_buffer()
	manager._on_manifest_request_completed(
		HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), body)
	if manager.state != manager.STATE_AVAILABLE:
		manager.free()
		return _fail("New manifest did not enter available state.")
	var captured_result := captured["result"] as Dictionary
	if str(captured_result.get("latest_version", "")) != future_version or bool(captured_result.get("manual", true)):
		manager.free()
		return _fail("Available response signal lost version/manual state: %s" % str(captured))
	manager.free()
	return true


func _next_canonical_version(version: String) -> String:
	# Bump the lowest canonical component that has headroom under
	# UPDATE_MANAGER's own limits, carrying over otherwise, so the result
	# always parses as a strictly newer X.Y.Z release per compare_versions().
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


func _fail(message: String) -> bool:
	push_error(message)
	return false
