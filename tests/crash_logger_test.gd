extends SceneTree

const CrashLoggerScript := preload("res://scripts/crash_logger.gd")
const TEST_ROOT := "user://logs/fan3905-unit"
const CONCURRENT_RECORDS := 16


class CaptureWorker:
	var service: Node


	func _init(target: Node) -> void:
		service = target


	func run(index: int) -> void:
		var frames: Array[Dictionary] = [{
			"file": "res://tests/crash_logger_test.gd",
			"function": "CaptureWorker.run",
			"line": index + 1,
		}]
		service.call(
			"capture_error_for_tests",
			"concurrent-%02d" % index,
			frames,
		)


class SignalPlayer:
	extends Node

	signal weapon_cast_observed(event: Dictionary)
	signal weapon_animation_event(event: Dictionary)

	var character_id := "signal_class"
	var weapon_id := "signal_weapon"


var _errors: Array[String] = []


func _init() -> void:
	_clean_directory(TEST_ROOT)
	call_deferred("_start_tests")


func _start_tests() -> void:
	var service: Node = root.get_node_or_null("CrashLogger")
	if service == null:
		service = CrashLoggerScript.new()
		root.add_child(service)
	_run_tests(service)


func _run_tests(service: Node) -> void:
	_check(service.configure_output_directory_for_tests(TEST_ROOT), "test output directory was not accepted")

	_check(service.incident_paths_for_tests().is_empty(), "a clean session created an incident file")
	_test_short_breadcrumb_ring(service)
	_test_full_breadcrumb_ring(service)
	_test_real_player_signal_path(service)
	_check(service.incident_paths_for_tests().is_empty(), "breadcrumb-only activity created an incident file")
	_test_unavailable_stack_and_redaction(service)
	_test_credential_field_families(service)
	_test_quoted_authorization_batches(service)
	_test_concurrent_records_and_rotation(service)

	_clean_directory(TEST_ROOT)
	if _errors.is_empty():
		print("crash_logger_test: PASS (clean session, signal breadcrumbs, ordered 50-ring, bounds, redaction, credential families, quoted authorization batches, concurrency, rotation)")
		quit(0)
		return
	for error in _errors:
		push_error("crash_logger_test: %s" % error)
	print("crash_logger_test: FAIL (%d)" % _errors.size())
	quit(1)


func _test_short_breadcrumb_ring(service: Node) -> void:
	service.clear_breadcrumbs_for_tests()
	for index in range(3):
		service.record_breadcrumb_for_tests("class_%d" % index, "weapon_%d" % index, "event_%d" % index, 10 + index)
	var snapshot: Array = service.breadcrumb_snapshot_for_tests()
	_check(snapshot.size() == 3, "short session did not preserve every breadcrumb")
	for index in range(snapshot.size()):
		var entry: Dictionary = snapshot[index]
		_check(int(entry.get("frame", -1)) == 10 + index, "short-session frame order changed at %d" % index)


func _test_full_breadcrumb_ring(service: Node) -> void:
	service.clear_breadcrumbs_for_tests()
	for index in range(55):
		service.record_breadcrumb_for_tests("berserk", "weapon_%02d" % index, "event_%02d" % index, index)
	var snapshot: Array = service.breadcrumb_snapshot_for_tests()
	_check(snapshot.size() == 50, "55 events retained %d entries instead of exactly 50" % snapshot.size())
	for index in range(snapshot.size()):
		var expected := index + 5
		var entry: Dictionary = snapshot[index]
		_check(int(entry.get("frame", -1)) == expected, "ring frame %d is not ordered newest-50 value %d" % [index, expected])
		_check(str(entry.get("event", "")) == "event_%02d" % expected, "ring event %d changed identity" % index)


func _test_real_player_signal_path(service: Node) -> void:
	service.clear_breadcrumbs_for_tests()
	var player := SignalPlayer.new()
	root.add_child(player)
	player.weapon_cast_observed.emit({"weapon_id": "signal_cast_weapon", "phase": "windup"})
	player.weapon_animation_event.emit({
		"character_id": "signal_animation_class",
		"weapon_id": "signal_animation_weapon",
		"phase": "release",
	})
	var snapshot: Array = service.breadcrumb_snapshot_for_tests()
	_check(snapshot.size() == 2, "real player signals produced %d breadcrumbs instead of 2" % snapshot.size())
	if snapshot.size() == 2:
		var activation: Dictionary = snapshot[0]
		var finish: Dictionary = snapshot[1]
		_check(str(activation.get("class", "")) == "signal_class", "cast signal lost the player class")
		_check(str(activation.get("weapon", "")) == "signal_cast_weapon", "cast signal lost the event weapon")
		_check(str(activation.get("event", "")) == "activation:windup", "cast signal did not record activation")
		_check(str(finish.get("class", "")) == "signal_animation_class", "animation signal lost the event class")
		_check(str(finish.get("weapon", "")) == "signal_animation_weapon", "animation signal lost the event weapon")
		_check(str(finish.get("event", "")) == "finish:release", "release signal did not record finish")
	root.remove_child(player)
	player.free()


func _test_unavailable_stack_and_redaction(service: Node) -> void:
	var no_frames: Array[Dictionary] = []
	service.clear_breadcrumbs_for_tests()
	service.record_breadcrumb_for_tests(
		"\"access_token\":\"TEST_ACCESS_TOKEN_CREDENTIAL\" token=TEST_CLASS_CREDENTIAL class=berserk",
		"Authorization: Basic TEST_BASIC_CREDENTIAL Bearer TEST_WEAPON_CREDENTIAL weapon=axe",
		"X-Api-Key: TEST_X_API_KEY_CREDENTIAL secret=TEST_EVENT_CREDENTIAL event=activation",
		77,
	)
	service.capture_error_for_tests(
		"{\"Authorization\": \"Basic TEST_JSON_AUTHORIZATION_CREDENTIAL\"} context=json-visible Bearer TEST_TEXT_CREDENTIAL refresh_token=TEST_REFRESH_TOKEN_CREDENTIAL context=visible Failed res://scenes/Main.tscn, user://saves/slot1.save and https://example.invalid/help; /Users/example/private/file,",
		no_frames,
		"\"token\": \"TEST_CODE_CREDENTIAL\", operation=cast resource='res://assets/test.png' save=\"user://logs/godot.log\" drive=\"C:\\Users\\Example\\WindowsProfileSecret.txt\"",
		"{\"authorization\":\"Bearer TEST_JSON_COMPACT_CREDENTIAL\"} reason=json-compact-visible Authorization: Bearer TEST_RATIONALE_CREDENTIAL reason=timeout drive=(D:/private/DriveProfileSecret.bin) home=/home/example/HomeProfileSecret.cfg;",
	)
	service.flush_pending_for_tests()
	var paths: PackedStringArray = service.incident_paths_for_tests()
	_check(paths.size() == 1, "one captured error produced %d files" % paths.size())
	if paths.is_empty():
		return
	var path := str(paths[0])
	var payload := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(payload)
	_check(parsed is Dictionary, "incident is not complete JSON")
	if not parsed is Dictionary:
		return
	var record: Dictionary = parsed
	var error: Dictionary = record.get("error", {})
	var redacted_fields := " ".join([
		str(error.get("text", "")),
		str(error.get("code", "")),
		str(error.get("rationale", "")),
	])
	var backtrace: Dictionary = record.get("script_backtrace", {})
	_check(not bool(backtrace.get("available", true)), "missing engine stack was presented as available")
	_check("unavailable" in str(backtrace.get("status", "")), "missing stack has no honest unavailable status")
	_check(str(record.get("timestamp_utc", "")).ends_with("Z"), "incident lacks a UTC timestamp")
	_check(str(record.get("build_version", "")) == str(ProjectSettings.get_setting("application/config/version")), "incident build version differs from project version")
	_check(str(record.get("build_sha256", "")).length() == 64, "incident lacks a 64-character immutable SHA-256")
	for credential in [
		"TEST_ACCESS_TOKEN_CREDENTIAL",
		"TEST_BASIC_CREDENTIAL",
		"TEST_X_API_KEY_CREDENTIAL",
		"TEST_REFRESH_TOKEN_CREDENTIAL",
		"TEST_CLASS_CREDENTIAL",
		"TEST_WEAPON_CREDENTIAL",
		"TEST_EVENT_CREDENTIAL",
		"TEST_TEXT_CREDENTIAL",
		"TEST_CODE_CREDENTIAL",
		"TEST_RATIONALE_CREDENTIAL",
		"TEST_JSON_AUTHORIZATION_CREDENTIAL",
		"TEST_JSON_COMPACT_CREDENTIAL",
	]:
		_check(payload.find(credential) == -1, "credential remainder persisted from %s" % credential)
	for benign_context in [
		"class=berserk",
		"weapon=axe",
		"event=activation",
		"context=visible",
		"operation=cast",
		"reason=timeout",
		"context=json-visible",
		"reason=json-compact-visible",
	]:
		_check(payload.find(benign_context) >= 0, "benign context was removed: %s" % benign_context)
	_check(payload.find("/Users/example") == -1, "personal home path was not redacted")
	for preserved_path in [
		"res://scenes/Main.tscn",
		"user://saves/slot1.save",
		"https://example.invalid/help",
		"res://assets/test.png",
		"user://logs/godot.log",
	]:
		_check(redacted_fields.find(preserved_path) >= 0, "diagnostic path was over-redacted: %s" % preserved_path)
	for hidden_path_marker in [
		"/Users/example/private/file",
		"WindowsProfileSecret",
		"DriveProfileSecret",
		"HomeProfileSecret",
	]:
		_check(redacted_fields.find(hidden_path_marker) == -1, "private path persisted: %s" % hidden_path_marker)
	for preserved_delimiter in [
		"<redacted-path>,",
		"\"<redacted-path>\"",
		"(<redacted-path>)",
		"<redacted-path>;",
	]:
		_check(redacted_fields.find(preserved_delimiter) >= 0, "path redaction removed punctuation: %s" % preserved_delimiter)
	_check(payload.to_utf8_buffer().size() <= CrashLoggerScript.MAX_RECORD_BYTES, "incident exceeded the record byte limit")
	_clean_incident_files(TEST_ROOT)


const CREDENTIAL_FAMILY_TEXT := "client_secret=TEST_CLIENT_SECRET_CREDENTIAL context=text-visible " \
	+ "Client-Secret: TEST_CLIENT_SECRET_HEADER_CREDENTIAL clientSecret='TEST_CAMEL_SECRET_CREDENTIAL' " \
	+ "CLIENT.SECRET=\"TEST_DOTTED_SECRET_CREDENTIAL\" {\"CLIENT_SECRET\": \"TEST_JSON_UPPER_SECRET_CREDENTIAL\", \"scene\": \"res://scenes/Main.tscn\"} " \
	+ "reroll_tokens=3 author=studio key=ui_accept secret_boss_active=true token_count=2 " \
	+ "password: TEST_PASSWORD_CREDENTIAL passwd=TEST_PASSWD_CREDENTIAL api_key=TEST_API_KEY_CREDENTIAL " \
	+ "X-API-KEY: TEST_X_API_KEY_HEADER_CREDENTIAL private_key=TEST_PRIVATE_KEY_CREDENTIAL " \
	+ "-----BEGIN RSA PRIVATE KEY-----\nTEST_PEM_PRIVATE_KEY_CREDENTIAL\n-----END RSA PRIVATE KEY-----\n" \
	+ "Failed to load res://assets/test.png after user://saves/slot1.save"
const CREDENTIAL_FAMILY_CODE := "Cookie: session=TEST_COOKIE_SESSION_CREDENTIAL; theme=TEST_COOKIE_THEME_CREDENTIAL context=cookie-visible " \
	+ "cookie=TEST_COOKIE_BARE_CREDENTIAL operation=cast Set-Cookie: sid=TEST_SET_COOKIE_CREDENTIAL; Path=/; HttpOnly " \
	+ "{\"cookies\": {\"session\": \"TEST_NESTED_COOKIE_CREDENTIAL\"}, \"scene\": \"res://scenes/Main.tscn\"} " \
	+ "{\\\"cookie\\\": \\\"TEST_ESCAPED_COOKIE_CREDENTIAL\\\", \\\"context\\\": \\\"escaped-visible\\\"} " \
	+ "COOKIES=\"TEST_UPPER_COOKIE_CREDENTIAL\" session=3 relay_session=alpha"
const CREDENTIAL_FAMILY_RATIONALE := "auth-token=TEST_AUTH_TOKEN_CREDENTIAL X-Auth-Token: TEST_X_AUTH_TOKEN_CREDENTIAL " \
	+ "authToken: 'TEST_CAMEL_AUTH_TOKEN_CREDENTIAL' AUTH_TOKEN=TEST_UPPER_AUTH_TOKEN_CREDENTIAL " \
	+ "{\"auth_token\":\"TEST_JSON_AUTH_TOKEN_CREDENTIAL\",\"reason\":\"json-auth-visible\"} " \
	+ "{\"auth\": {\"client_secret\": \"TEST_NESTED_SECRET_CREDENTIAL\", \"nested\": [{\"cookie\": \"TEST_DEEP_COOKIE_CREDENTIAL\"}]}, " \
	+ "\"level\": 3, \"config\": {\"inner\": {\"private_key\": \"TEST_INNER_PRIVATE_KEY_CREDENTIAL\"}, \"seed\": 42}} " \
	+ "auth=TEST_BARE_AUTH_CREDENTIAL credentials: [\"TEST_LIST_CREDENTIAL_A\", \"TEST_LIST_CREDENTIAL_B\"] session_id=TEST_SESSION_ID_CREDENTIAL " \
	+ "Authorization: Digest username=\"tester\", response=\"TEST_DIGEST_CREDENTIAL\"\n" \
	+ "https://tester:TEST_URL_PASSWORD_CREDENTIAL@example.invalid/help reason=timeout token_expires=3600"
const AUTHORIZATION_SCHEME_TEXT := "Authorization: DPoP TEST_DPOP_CREDENTIAL context=dpop-visible " \
	+ "Proxy-Authorization: Signature keyId=\"tester\", algorithm=\"hs2019\", signature=\"TEST_SIGNATURE_CREDENTIAL\" context=signature-visible " \
	+ "Authorization: X-Custom-Scheme TEST_EXTENSION_CREDENTIAL context=extension-visible " \
	+ "Authorization: Mutual user=\"tester\", realm=\"game\", proof=TEST_MUTUAL_CREDENTIAL context=mutual-visible " \
	+ "Authorization: TEST_SCHEMELESS_CREDENTIAL context=schemeless-visible " \
	+ "PROXY-AUTHORIZATION: SCRAM-SHA-256 TEST_SCRAM_CREDENTIAL== context=scram-visible " \
	+ "proxy_authorization=Concealed TEST_CONCEALED_CREDENTIAL operation=cast " \
	+ "proxyAuthorization: 'HOBA TEST_HOBA_CREDENTIAL' reason=hoba-visible " \
	+ "Authorization: Negotiate TEST_NEGOTIATE_CREDENTIAL, extra=TEST_NEGOTIATE_PARAM_CREDENTIAL Failed to load res://scenes/Main.tscn"
const AUTHORIZATION_SCHEME_CODE := "{\"Authorization\": \"DPoP TEST_JSON_DPOP_CREDENTIAL\", \"reason\": \"json-dpop-visible\"} " \
	+ "{\"headers\": {\"Proxy-Authorization\": \"Signature keyId=\\\"k\\\", signature=\\\"TEST_NESTED_SIGNATURE_CREDENTIAL\\\"\", \"Accept\": \"application/json\"}, \"level\": 7} " \
	+ "{\\\"Proxy-Authorization\\\": \\\"Negotiate TEST_ESCAPED_NEGOTIATE_CREDENTIAL\\\", \\\"context\\\": \\\"escaped-auth-visible\\\"} " \
	+ "Authorization: Bearer TEST_KNOWN_BEARER_CREDENTIAL weapon=axe Authorization: Basic TEST_KNOWN_BASIC_CREDENTIAL event=activation"
const CREDENTIAL_FAMILY_MARKERS: Array[String] = [
	"TEST_CLIENT_SECRET_CREDENTIAL",
	"TEST_CLIENT_SECRET_HEADER_CREDENTIAL",
	"TEST_CAMEL_SECRET_CREDENTIAL",
	"TEST_DOTTED_SECRET_CREDENTIAL",
	"TEST_JSON_UPPER_SECRET_CREDENTIAL",
	"TEST_PASSWORD_CREDENTIAL",
	"TEST_PASSWD_CREDENTIAL",
	"TEST_API_KEY_CREDENTIAL",
	"TEST_X_API_KEY_HEADER_CREDENTIAL",
	"TEST_PRIVATE_KEY_CREDENTIAL",
	"TEST_PEM_PRIVATE_KEY_CREDENTIAL",
	"TEST_COOKIE_SESSION_CREDENTIAL",
	"TEST_COOKIE_THEME_CREDENTIAL",
	"TEST_COOKIE_BARE_CREDENTIAL",
	"TEST_SET_COOKIE_CREDENTIAL",
	"TEST_NESTED_COOKIE_CREDENTIAL",
	"TEST_ESCAPED_COOKIE_CREDENTIAL",
	"TEST_UPPER_COOKIE_CREDENTIAL",
	"TEST_AUTH_TOKEN_CREDENTIAL",
	"TEST_X_AUTH_TOKEN_CREDENTIAL",
	"TEST_CAMEL_AUTH_TOKEN_CREDENTIAL",
	"TEST_UPPER_AUTH_TOKEN_CREDENTIAL",
	"TEST_JSON_AUTH_TOKEN_CREDENTIAL",
	"TEST_NESTED_SECRET_CREDENTIAL",
	"TEST_DEEP_COOKIE_CREDENTIAL",
	"TEST_INNER_PRIVATE_KEY_CREDENTIAL",
	"TEST_BARE_AUTH_CREDENTIAL",
	"TEST_LIST_CREDENTIAL_A",
	"TEST_LIST_CREDENTIAL_B",
	"TEST_SESSION_ID_CREDENTIAL",
	"TEST_DIGEST_CREDENTIAL",
	"TEST_URL_PASSWORD_CREDENTIAL",
	"TEST_BREADCRUMB_SECRET_CREDENTIAL",
	"TEST_BREADCRUMB_COOKIE_CREDENTIAL",
	"TEST_BREADCRUMB_TOKEN_CREDENTIAL",
	"TEST_DPOP_CREDENTIAL",
	"TEST_SIGNATURE_CREDENTIAL",
	"TEST_EXTENSION_CREDENTIAL",
	"TEST_MUTUAL_CREDENTIAL",
	"TEST_SCHEMELESS_CREDENTIAL",
	"TEST_SCRAM_CREDENTIAL",
	"TEST_CONCEALED_CREDENTIAL",
	"TEST_HOBA_CREDENTIAL",
	"TEST_NEGOTIATE_CREDENTIAL",
	"TEST_NEGOTIATE_PARAM_CREDENTIAL",
	"TEST_JSON_DPOP_CREDENTIAL",
	"TEST_NESTED_SIGNATURE_CREDENTIAL",
	"TEST_ESCAPED_NEGOTIATE_CREDENTIAL",
	"TEST_KNOWN_BEARER_CREDENTIAL",
	"TEST_KNOWN_BASIC_CREDENTIAL",
	"TEST_BREADCRUMB_DPOP_CREDENTIAL",
]
const CREDENTIAL_FAMILY_BENIGN: Array[String] = [
	"context=dpop-visible",
	"context=signature-visible",
	"context=extension-visible",
	"context=mutual-visible",
	"context=schemeless-visible",
	"context=scram-visible",
	"proxy_authorization=<redacted> operation=cast",
	"proxyAuthorization: '<redacted>' reason=hoba-visible",
	"Failed to load res://scenes/Main.tscn",
	"\"reason\": \"json-dpop-visible\"",
	"\"Accept\": \"application/json\"",
	"\"level\": 7",
	"\\\"context\\\": \\\"escaped-auth-visible\\\"",
	"weapon=axe",
	"event=activation",
	"context=text-visible",
	"\"scene\": \"res://scenes/Main.tscn\"",
	"reroll_tokens=3",
	"author=studio",
	"key=ui_accept",
	"secret_boss_active=true",
	"token_count=2",
	"Failed to load res://assets/test.png after user://saves/slot1.save",
	"context=cookie-visible",
	"operation=cast",
	"HttpOnly",
	"\\\"context\\\": \\\"escaped-visible\\\"",
	"session=3",
	"relay_session=alpha",
	"\"reason\":\"json-auth-visible\"",
	"\"level\": 3",
	"\"seed\": 42",
	"https://tester:<redacted>@example.invalid/help",
	"reason=timeout",
	"token_expires=3600",
	"<redacted-private-key>",
	"clientSecret='<redacted>'",
	"CLIENT.SECRET=\"<redacted>\"",
]


func _test_credential_field_families(service: Node) -> void:
	var no_frames: Array[Dictionary] = []
	service.clear_breadcrumbs_for_tests()
	service.record_breadcrumb_for_tests(
		"client_secret=TEST_BREADCRUMB_SECRET_CREDENTIAL class=berserk",
		"Cookie: token=TEST_BREADCRUMB_COOKIE_CREDENTIAL weapon=axe",
		"x_auth_token=TEST_BREADCRUMB_TOKEN_CREDENTIAL event=activation",
		78,
	)
	service.record_breadcrumb_for_tests(
		"Authorization: DPoP TEST_BREADCRUMB_DPOP_CREDENTIAL class=berserk",
		"weapon=axe",
		"event=activation",
		79,
	)
	service.capture_error_for_tests(
		CREDENTIAL_FAMILY_TEXT + "\n" + AUTHORIZATION_SCHEME_TEXT,
		no_frames,
		CREDENTIAL_FAMILY_CODE + "\n" + AUTHORIZATION_SCHEME_CODE,
		CREDENTIAL_FAMILY_RATIONALE,
	)
	service.flush_pending_for_tests()
	var paths: PackedStringArray = service.incident_paths_for_tests()
	_check(paths.size() == 1, "credential-family capture produced %d files" % paths.size())
	if paths.is_empty():
		return
	var payload := FileAccess.get_file_as_string(str(paths[0]))
	var parsed = JSON.parse_string(payload)
	_check(parsed is Dictionary, "credential-family incident is not complete JSON")
	if not parsed is Dictionary:
		return
	for marker in CREDENTIAL_FAMILY_MARKERS:
		_check(payload.find(marker) == -1, "credential marker reached the incident: %s" % marker)
	var record: Dictionary = parsed
	var error: Dictionary = record.get("error", {})
	var fields := "\n".join([
		str(error.get("text", "")),
		str(error.get("code", "")),
		str(error.get("rationale", "")),
	])
	for benign in CREDENTIAL_FAMILY_BENIGN:
		_check(fields.find(benign) >= 0, "benign diagnostic context was removed: %s" % benign)
	var breadcrumbs: Array = record.get("breadcrumbs", [])
	_check(breadcrumbs.size() == 2, "credential-family record carried %d breadcrumbs instead of 2" % breadcrumbs.size())
	for breadcrumb_value in breadcrumbs:
		var breadcrumb: Dictionary = breadcrumb_value
		_check(str(breadcrumb.get("class", "")).ends_with("class=berserk"), "breadcrumb class context was removed")
		_check(str(breadcrumb.get("weapon", "")).ends_with("weapon=axe"), "breadcrumb weapon context was removed")
		_check(str(breadcrumb.get("event", "")).ends_with("event=activation"), "breadcrumb event context was removed")
	_check(payload.to_utf8_buffer().size() <= CrashLoggerScript.MAX_RECORD_BYTES, "credential-family incident exceeded the record byte limit")
	_clean_incident_files(TEST_ROOT)


# Each case is captured as its own isolated incident (one file, checked, then
# removed) so normal rotation can never hide a leak. `field` selects which
# _redact path carries the input: error text/code/rationale, a backtrace frame
# function name, or a breadcrumb class/weapon/event field.
const QUOTED_AUTHORIZATION_CASES: Array[Dictionary] = [
	{"field": "text", "input": "Authorization: Bearer \"TEST_QB_DQ_CREDENTIAL\" context=visible", "markers": ["TEST_QB_DQ_CREDENTIAL"], "benign": ["Authorization: <redacted> context=visible"]},
	{"field": "text", "input": "Authorization: Basic \"TEST_QBASIC_DQ_CREDENTIAL\" context=visible", "markers": ["TEST_QBASIC_DQ_CREDENTIAL"], "benign": ["context=visible"]},
	{"field": "text", "input": "Authorization: X-Ext-Scheme \"TEST_QEXT_DQ_CREDENTIAL\" context=visible", "markers": ["TEST_QEXT_DQ_CREDENTIAL"], "benign": ["context=visible"]},
	{"field": "text", "input": "Authorization: HOBA \"TEST_QHOBA_DQ_CREDENTIAL\" context=visible", "markers": ["TEST_QHOBA_DQ_CREDENTIAL"], "benign": ["context=visible"]},
	{"field": "text", "input": "Authorization: DPoP \"TEST_QDPOP_DQ_CREDENTIAL\" context=visible", "markers": ["TEST_QDPOP_DQ_CREDENTIAL"], "benign": ["context=visible"]},
	{"field": "text", "input": "Proxy-Authorization: Bearer \"TEST_QB_PROXY_CREDENTIAL\" context=visible", "markers": ["TEST_QB_PROXY_CREDENTIAL"], "benign": ["Proxy-Authorization: <redacted> context=visible"]},
	{"field": "text", "input": "Proxy-Authorization: Basic 'TEST_QBASIC_PROXY_SQ_CREDENTIAL' context=visible", "markers": ["TEST_QBASIC_PROXY_SQ_CREDENTIAL"], "benign": ["context=visible"]},
	{"field": "text", "input": "Proxy-Authorization: X-Ext-Scheme \"TEST_QEXT_PROXY_CREDENTIAL\" context=visible", "markers": ["TEST_QEXT_PROXY_CREDENTIAL"], "benign": ["context=visible"]},
	{"field": "text", "input": "Authorization: Bearer 'TEST_QB_SQ_CREDENTIAL' context=visible", "markers": ["TEST_QB_SQ_CREDENTIAL"], "benign": ["context=visible"]},
	{"field": "text", "input": "Authorization: Basic \\\"TEST_QBASIC_ESC_CREDENTIAL\\\" context=visible", "markers": ["TEST_QBASIC_ESC_CREDENTIAL"], "benign": ["context=visible"]},
	{"field": "text", "input": "Authorization: X-Ext-Scheme \\\"TEST_QEXT_ESC_CREDENTIAL\\\" context=visible", "markers": ["TEST_QEXT_ESC_CREDENTIAL"], "benign": ["context=visible"]},
	{"field": "text", "input": "Authorization: \"Bearer TEST_WHOLE_DQ_CREDENTIAL\" context=visible", "markers": ["TEST_WHOLE_DQ_CREDENTIAL"], "benign": ["Authorization: \"<redacted>\" context=visible"]},
	{"field": "text", "input": "Proxy-Authorization: 'Basic TEST_WHOLE_SQ_CREDENTIAL' context=visible", "markers": ["TEST_WHOLE_SQ_CREDENTIAL"], "benign": ["Proxy-Authorization: '<redacted>' context=visible"]},
	{"field": "text", "input": "Authorization: Bearer TEST_T68_CREDENTIAL== context=visible", "markers": ["TEST_T68_CREDENTIAL"], "benign": ["context=visible"]},
	{"field": "text", "input": "Authorization: X-Ext-Scheme keyId=\"k\", proof=\"TEST_PARAM_DQ_CREDENTIAL\", nonce=TEST_PARAM_BARE_CREDENTIAL context=visible", "markers": ["TEST_PARAM_DQ_CREDENTIAL", "TEST_PARAM_BARE_CREDENTIAL"], "benign": ["context=visible"]},
	{"field": "text", "input": "Authorization: X-Ext-Scheme \"TEST_LIST_Q1_CREDENTIAL\", \"TEST_LIST_Q2_CREDENTIAL\" context=visible", "markers": ["TEST_LIST_Q1_CREDENTIAL", "TEST_LIST_Q2_CREDENTIAL"], "benign": ["context=visible"]},
	{"field": "text", "input": "Authorization: Bearer \"TEST_LINE_CREDENTIAL\"\nnext_line=visible res://scenes/Main.tscn", "markers": ["TEST_LINE_CREDENTIAL"], "benign": ["next_line=visible res://scenes/Main.tscn"]},
	{"field": "text", "input": "Failed to load user://saves/slot1.save Authorization: Basic \"TEST_END_CREDENTIAL\"", "markers": ["TEST_END_CREDENTIAL"], "benign": ["Failed to load user://saves/slot1.save Authorization: <redacted>"]},
	{"field": "text", "input": "Authorization: Bearer \"TEST_UNTERMINATED_CREDENTIAL context=lost", "markers": ["TEST_UNTERMINATED_CREDENTIAL"], "benign": ["Authorization: <redacted>"]},
	{"field": "text", "input": "Authorization: Bearer \"TEST_SPACED_QUOTE_CREDENTIAL with space\" context=visible", "markers": ["TEST_SPACED_QUOTE_CREDENTIAL"], "benign": ["context=visible"]},
	{"field": "text", "input": "{\"headers\": {\"Authorization\": \"Bearer \\\"TEST_NESTED_Q_CREDENTIAL\\\"\", \"Accept\": \"text/plain\"}, \"level\": 5}", "markers": ["TEST_NESTED_Q_CREDENTIAL"], "benign": ["\"Accept\": \"text/plain\"", "\"level\": 5"]},
	{"field": "text", "input": "{\\\"Authorization\\\": \\\"Bearer TEST_ESCJSON_CREDENTIAL\\\", \\\"context\\\": \\\"escaped-visible\\\"}", "markers": ["TEST_ESCJSON_CREDENTIAL"], "benign": ["\\\"context\\\": \\\"escaped-visible\\\""]},
	{"field": "text", "input": "auth: Bearer \"TEST_AUTHKEY_Q_CREDENTIAL\" context=visible https://example.invalid/help", "markers": ["TEST_AUTHKEY_Q_CREDENTIAL"], "benign": ["context=visible https://example.invalid/help"]},
	{"field": "text", "input": "proxy_authorization=Basic \"TEST_SNAKE_Q_CREDENTIAL\" operation=cast", "markers": ["TEST_SNAKE_Q_CREDENTIAL"], "benign": ["operation=cast"]},
	{"field": "code", "input": "Authorization: Bearer \"TEST_CODE_Q_CREDENTIAL\" operation=cast", "markers": ["TEST_CODE_Q_CREDENTIAL"], "benign": ["operation=cast"]},
	{"field": "rationale", "input": "Proxy-Authorization: Basic 'TEST_RATIONALE_Q_CREDENTIAL' reason=timeout", "markers": ["TEST_RATIONALE_Q_CREDENTIAL"], "benign": ["reason=timeout"]},
	{"field": "function", "input": "Authorization: Bearer \"TEST_FRAME_Q_CREDENTIAL\" fn=visible", "markers": ["TEST_FRAME_Q_CREDENTIAL"], "benign": ["fn=visible"]},
	{"field": "class", "input": "Authorization: Basic \"TEST_CLASS_Q_CREDENTIAL\" class=berserk", "markers": ["TEST_CLASS_Q_CREDENTIAL"], "benign": ["class=berserk"]},
	{"field": "weapon", "input": "Proxy-Authorization: X-Ext-Scheme 'TEST_WEAPON_Q_CREDENTIAL' weapon=axe", "markers": ["TEST_WEAPON_Q_CREDENTIAL"], "benign": ["weapon=axe"]},
	{"field": "event", "input": "Authorization: Bearer \\\"TEST_EVENT_Q_CREDENTIAL\\\" event=activation", "markers": ["TEST_EVENT_Q_CREDENTIAL"], "benign": ["event=activation"]},
]


func _test_quoted_authorization_batches(service: Node) -> void:
	for entry_value in QUOTED_AUTHORIZATION_CASES:
		var entry: Dictionary = entry_value
		var field := str(entry.get("field", "text"))
		var sample := str(entry.get("input", ""))
		var label := str((entry.get("markers", []) as Array)[0])
		service.clear_breadcrumbs_for_tests()
		_clean_incident_files(TEST_ROOT)
		var frames: Array[Dictionary] = []
		if field == "function":
			frames.append({"file": "res://tests/crash_logger_test.gd", "function": sample, "line": 1})
		if field == "class" or field == "weapon" or field == "event":
			service.record_breadcrumb_for_tests(
				sample if field == "class" else "class=berserk",
				sample if field == "weapon" else "weapon=axe",
				sample if field == "event" else "event=activation",
				80,
			)
		service.capture_error_for_tests(
			sample if field == "text" else "isolated quoted authorization case",
			frames,
			sample if field == "code" else "",
			sample if field == "rationale" else "",
		)
		service.flush_pending_for_tests()
		var paths: PackedStringArray = service.incident_paths_for_tests()
		_check(paths.size() == 1, "%s: isolated case produced %d files" % [label, paths.size()])
		if paths.size() != 1:
			continue
		var payload := FileAccess.get_file_as_string(str(paths[0]))
		var parsed = JSON.parse_string(payload)
		_check(parsed is Dictionary, "%s: incident is not complete JSON" % label)
		for marker in entry.get("markers", []):
			_check(payload.find(str(marker)) == -1, "%s: quoted credential reached the incident" % str(marker))
		if parsed is Dictionary:
			var redacted := _redacted_fields_text(parsed)
			for benign in entry.get("benign", []):
				_check(redacted.find(str(benign)) >= 0, "%s: benign context was removed: %s" % [label, str(benign)])
	_clean_incident_files(TEST_ROOT)


func _redacted_fields_text(record: Dictionary) -> String:
	var error: Dictionary = record.get("error", {})
	var parts: Array[String] = [
		str(error.get("text", "")),
		str(error.get("code", "")),
		str(error.get("rationale", "")),
	]
	var backtrace: Dictionary = record.get("script_backtrace", {})
	for trace_value in backtrace.get("traces", []):
		var trace: Dictionary = trace_value
		for frame_value in trace.get("frames", []):
			var frame: Dictionary = frame_value
			parts.append(str(frame.get("function", "")))
	for breadcrumb_value in record.get("breadcrumbs", []):
		var breadcrumb: Dictionary = breadcrumb_value
		parts.append(str(breadcrumb.get("class", "")))
		parts.append(str(breadcrumb.get("weapon", "")))
		parts.append(str(breadcrumb.get("event", "")))
	return "\n".join(parts)


func _test_concurrent_records_and_rotation(service: Node) -> void:
	var threads: Array[Thread] = []
	var workers: Array[CaptureWorker] = []
	for index in range(CONCURRENT_RECORDS):
		var worker := CaptureWorker.new(service)
		var thread := Thread.new()
		workers.append(worker)
		threads.append(thread)
		_check(thread.start(worker.run.bind(index)) == OK, "thread %d did not start" % index)
	for thread in threads:
		thread.wait_to_finish()
	service.flush_pending_for_tests()

	var paths: PackedStringArray = service.incident_paths_for_tests()
	_check(paths.size() == CONCURRENT_RECORDS, "concurrent callbacks produced %d/%d complete records" % [paths.size(), CONCURRENT_RECORDS])
	var seen := {}
	for path_value in paths:
		var path := str(path_value)
		var payload := FileAccess.get_file_as_string(path)
		var parsed = JSON.parse_string(payload)
		_check(parsed is Dictionary, "concurrent record %s is interleaved or incomplete" % path.get_file())
		_check(payload.to_utf8_buffer().size() <= CrashLoggerScript.MAX_RECORD_BYTES, "concurrent record exceeded byte limit")
		if parsed is Dictionary:
			seen[str((parsed as Dictionary).get("error", {}).get("text", ""))] = true
	for index in range(CONCURRENT_RECORDS):
		_check(seen.has("concurrent-%02d" % index), "concurrent record %d was lost" % index)

	for index in range(10):
		service.capture_error_for_tests("rotation-%02d" % index)
	service.flush_pending_for_tests()
	paths = service.incident_paths_for_tests()
	_check(paths.size() == CrashLoggerScript.MAX_INCIDENTS, "rotation retained %d files instead of %d" % [paths.size(), CrashLoggerScript.MAX_INCIDENTS])
	var retained_bytes := 0
	for path_value in paths:
		var file := FileAccess.open(str(path_value), FileAccess.READ)
		if file != null:
			retained_bytes += file.get_length()
			file.close()
	_check(retained_bytes <= CrashLoggerScript.MAX_RETAINED_BYTES, "rotation retained %d bytes above the limit" % retained_bytes)


func _clean_incident_files(directory: String) -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(directory)):
		return
	for filename in DirAccess.get_files_at(directory):
		if filename.begins_with(CrashLoggerScript.INCIDENT_PREFIX):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(directory.path_join(filename)))


func _clean_directory(directory: String) -> void:
	_clean_incident_files(directory)
	var absolute := ProjectSettings.globalize_path(directory)
	if DirAccess.dir_exists_absolute(absolute):
		DirAccess.remove_absolute(absolute)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
