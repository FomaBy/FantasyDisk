extends SceneTree

const Reporter := preload("res://scripts/feedback_reporter.gd")

var _errors: Array[String] = []


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _init() -> void:
	var relay_url := "https://feedback.fantasydisk.example/v1/session"
	_check(Reporter._is_valid_relay_session_url(relay_url), "Canonical HTTPS relay URL was rejected.")
	for invalid in [
		"http://feedback.fantasydisk.example/v1/session",
		"https://feedback.fantasydisk.example/v1/feedback",
		"https://user@feedback.fantasydisk.example/v1/session",
		"https://feedback.fantasydisk.example/v1/session?next=evil",
		"https://feedback.fantasydisk.example/v1/session#fragment",
		"https://feedback.fantasydisk.example\r\n.evil/v1/session",
	]:
		_check(not Reporter._is_valid_relay_session_url(invalid), "Unsafe relay URL accepted: %s" % invalid)

	var discord := "https://discord.com/api/webhooks/123456789012345678/abcdefghijklmnopqrstuvwxyz_123456"
	var release_direct := Reporter._resolve_delivery_from([], [discord, "", ""], false)
	_check(str(release_direct.get("url", "")) == "",
		"Release routing must ignore every raw Discord credential source.")
	var debug_direct := Reporter._resolve_delivery_from([], [discord, "", ""], true)
	_check(str(debug_direct.get("mode", "")) == "discord_debug",
		"Explicit debug routing should retain the developer-only Discord transport.")
	var relay_wins := Reporter._resolve_delivery_from([relay_url, "", ""], [discord, "", ""], true)
	_check(str(relay_wins.get("mode", "")) == "relay" and str(relay_wins.get("url", "")) == relay_url,
		"Relay must win over debug Discord when both are configured.")
	var privacy_blocks := Reporter._resolve_delivery_from(
		[relay_url, "", ""], [discord, "", ""], true, false)
	_check(str(privacy_blocks.get("url", "")) == "" \
		and str(privacy_blocks.get("error", "")) == "privacy_incomplete",
		"Relay routing must fail closed while public privacy settings are incomplete.")
	var privacy_blocks_debug := Reporter._resolve_delivery_from(
		[], [discord, "", ""], true, false)
	_check(str(privacy_blocks_debug.get("url", "")) == "" \
		and str(privacy_blocks_debug.get("error", "")) == "privacy_incomplete",
		"Debug Discord routing must not bypass the player-facing privacy gate.")

	var first_uuid := Reporter._new_report_uuid()
	var second_uuid := Reporter._new_report_uuid()
	_check(Reporter._is_uuid_v4(first_uuid), "Generated report id is not UUIDv4: %s" % first_uuid)
	_check(Reporter._is_uuid_v4(second_uuid) and second_uuid != first_uuid,
		"Generated report ids must be valid and unique.")
	var deterministic := PackedByteArray(range(16))
	var formatted := Reporter._format_uuid_v4(deterministic)
	_check(formatted == "00010203-0405-4607-8809-0a0b0c0d0e0f",
		"UUID formatter did not set RFC 4122 version/variant bits: %s" % formatted)
	var timestamp := "20260713_120000"
	_check(Reporter._local_report_folder(timestamp, first_uuid) != Reporter._local_report_folder(timestamp, second_uuid),
		"Same-second local fallbacks must not collide.")

	var image := Image.create(32, 18, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.1, 0.2, 0.3, 1.0))
	var upload_bytes := Reporter._relay_upload_body(first_uuid, "relay body", image, {
		"version": "0.2.1", "os": "macOS",
	})
	var parsed = JSON.parse_string(upload_bytes.get_string_from_utf8())
	_check(parsed is Dictionary, "Relay upload body is not a JSON object.")
	if parsed is Dictionary:
		var upload := parsed as Dictionary
		_check(int(upload.get("schema_version", 0)) == Reporter.RELAY_SCHEMA_VERSION,
			"Relay upload schema version mismatch.")
		_check(str(upload.get("report_id", "")) == first_uuid,
			"Relay payload report_id differs from idempotency identity.")
		_check(not upload.has("token") and not upload.has("webhook_url"),
			"Relay payload must never contain credentials.")
		var jpeg := Marshalls.base64_to_raw(str(upload.get("screenshot_jpeg_base64", "")))
		_check(jpeg.size() > 2 and jpeg[0] == 0xff and jpeg[1] == 0xd8,
			"Relay screenshot is not base64-encoded JPEG.")
	var text_only_bytes := Reporter._relay_upload_body(first_uuid, "text only", image, {
		"version": "0.2.1", "password": "must be dropped",
	}, false)
	var text_only = JSON.parse_string(text_only_bytes.get_string_from_utf8())
	_check(text_only is Dictionary, "Text-only relay upload body is not JSON.")
	if text_only is Dictionary:
		var upload := text_only as Dictionary
		_check(upload.has("screenshot_jpeg_base64") \
			and upload["screenshot_jpeg_base64"] == null,
			"Schema v2 text-only payload must use an explicit null screenshot.")
		_check(not (upload.get("metadata", {}) as Dictionary).has("password"),
			"Client relay payload leaked metadata outside the allowlist.")
	_check(text_only_bytes.size() < 2048,
		"Text-only relay body unexpectedly contains encoded image data.")
	var direct_text = JSON.parse_string(
		Reporter.discord_json_payload("text only", {"version": "0.2.1"}).get_string_from_utf8())
	_check(direct_text is Dictionary \
		and (direct_text as Dictionary).get("attachments", ["unsafe"]) == [],
		"Debug text-only transport must declare no Discord attachments.")

	var session_body = JSON.parse_string(Reporter._relay_session_body(first_uuid, "0.2.1").get_string_from_utf8())
	_check(session_body is Dictionary and str((session_body as Dictionary).get("installation_id", "")) == first_uuid,
		"Relay session request lost the installation identity.")
	var token_response := JSON.stringify({
		"schema_version": Reporter.RELAY_SCHEMA_VERSION,
		"expires_in": 600,
		"token": "short-lived.token_123",
	}).to_utf8_buffer()
	_check(Reporter._parse_relay_session_token(token_response) == "short-lived.token_123",
		"Valid session token response was rejected.")
	_check(Reporter._is_description_within_limit("x".repeat(4000)),
		"4000-character description must match the relay boundary.")
	_check(not Reporter._is_description_within_limit("x".repeat(4001)),
		"4001-character description must be rejected before network delivery.")
	_check(Reporter._is_submission_content_valid("", true),
		"Screenshot-only reports should remain valid.")
	_check(not Reporter._is_submission_content_valid("  ", false) \
		and Reporter._is_submission_content_valid("details", false),
		"Text-only reports must require a non-empty description.")
	_check(Reporter._privacy_configuration_complete(
		"FantasyDisk operator", "https://example.com/contact",
		"Reports are retained under the published policy.", "https://example.com/privacy"),
		"Complete public privacy configuration was rejected.")
	_check(not Reporter._privacy_configuration_complete(
		"FantasyDisk operator", "", "retention", "https://example.com/privacy"),
		"Incomplete public privacy configuration was accepted.")
	_check(not Reporter._privacy_configuration_complete(
		"FantasyDisk operator", "https://", "retention", "https://example.com/privacy"),
		"Hostless public privacy URL was accepted.")
	_check(Reporter._parse_relay_session_token(JSON.stringify({
		"schema_version": Reporter.RELAY_SCHEMA_VERSION,
		"expires_in": 600,
		"token": "bad\r\ntoken",
	}).to_utf8_buffer()) == "", "CR/LF-bearing token was accepted into request headers.")
	_check(not Reporter._is_safe_session_token("segment.snowman_☃"),
		"Non-base64url session token was accepted into Authorization.")

	if _errors.is_empty():
		print("Feedback relay contract test passed (v2 image/text-only, privacy routing, token safety).")
		quit(0)
	else:
		for error in _errors:
			push_error("Feedback relay contract: %s" % error)
		quit(1)
