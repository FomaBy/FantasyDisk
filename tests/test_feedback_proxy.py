from __future__ import annotations

import base64
import io
import json
import logging
import os
import struct
import sys
import tempfile
import threading
import unittest
import uuid
from dataclasses import replace
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
SERVICE_ROOT = ROOT / "services" / "feedback_proxy"
sys.path.insert(0, str(SERVICE_ROOT))

from feedback_proxy.app import Config, FeedbackProxyApp, _report_digest  # noqa: E402


class _UpstreamHandler(BaseHTTPRequestHandler):
    requests = []
    response_codes = []

    def do_POST(self) -> None:
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length)
        self.__class__.requests.append((self.path, dict(self.headers), body))
        code = self.__class__.response_codes.pop(0) if self.__class__.response_codes else 204
        self.send_response(code)
        if code == 429:
            self.send_header("Retry-After", "4")
        self.end_headers()

    def log_message(self, _format: str, *_args: object) -> None:
        return


def _jpeg(width: int = 32, height: int = 18) -> bytes:
    # Minimal SOF0 structure sufficient for the relay's format/dimension parser.
    return (
        b"\xff\xd8\xff\xc0"
        + struct.pack(">H", 11)
        + bytes([8])
        + struct.pack(">HH", height, width)
        + bytes([1, 1, 0x11, 0])
        + b"\xff\xd9"
    )


class FeedbackProxyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        _UpstreamHandler.requests = []
        _UpstreamHandler.response_codes = []
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), _UpstreamHandler)
        cls.server_thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.server_thread.start()

    @classmethod
    def tearDownClass(cls) -> None:
        cls.server.shutdown()
        cls.server.server_close()
        cls.server_thread.join(timeout=3)

    def setUp(self) -> None:
        _UpstreamHandler.requests.clear()
        _UpstreamHandler.response_codes.clear()
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.clock = [1_700_000_000]
        self.log_stream = io.StringIO()
        logger = logging.getLogger("feedback-proxy-test-" + uuid.uuid4().hex)
        logger.setLevel(logging.INFO)
        logger.propagate = False
        logger.addHandler(logging.StreamHandler(self.log_stream))
        port = self.server.server_address[1]
        config = Config(
            token_secret=b"t" * 32,
            log_salt=b"l" * 32,
            discord_webhook_url="http://127.0.0.1:%d/upstream" % port,
            database_path=str(Path(self.temp.name) / "relay.sqlite3"),
            allow_test_upstream=True,
            now=lambda: self.clock[0],
        )
        self.app = FeedbackProxyApp(config, logger=logger)
        self.installation_id = str(uuid.uuid4())

    def _request(
        self, path: str, payload: object, headers=None, remote_addr="203.0.113.10", app=None
    ):
        raw = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        environ = {
            "REQUEST_METHOD": "POST",
            "PATH_INFO": path,
            "CONTENT_TYPE": "application/json",
            "CONTENT_LENGTH": str(len(raw)),
            "REMOTE_ADDR": remote_addr,
            "wsgi.input": io.BytesIO(raw),
        }
        environ.update(headers or {})
        response = {}

        def start_response(status, response_headers):
            response["status"] = status
            response["headers"] = dict(response_headers)

        body = b"".join((app or self.app)(environ, start_response))
        response["json"] = json.loads(body.decode("utf-8"))
        return response

    def _session(self, installation_id=None):
        response = self._request(
            "/v1/session",
            {
                "schema_version": 2,
                "installation_id": installation_id or self.installation_id,
                "client_version": "0.2.3",
            },
        )
        self.assertEqual(response["status"], "200 OK")
        self.assertEqual(response["headers"].get("Cache-Control"), "no-store")
        return response["json"]["token"]

    def _feedback_payload(
        self, report_id, description="enemy froze @everyone", metadata=None, screenshot=True
    ):
        return {
            "schema_version": 2,
            "report_id": report_id,
            "description": description,
            "metadata": metadata or {"version": "0.2.3", "os": "macOS", "combat_active": True},
            "screenshot_jpeg_base64": (
                base64.b64encode(_jpeg()).decode("ascii") if screenshot else None
            ),
        }

    def _feedback_headers(self, token, report_id, installation_id=None):
        return {
            "HTTP_AUTHORIZATION": "Bearer " + token,
            "HTTP_X_FEEDBACK_INSTALLATION": installation_id or self.installation_id,
            "HTTP_IDEMPOTENCY_KEY": report_id,
        }

    def test_authenticated_delivery_disables_mentions_and_deduplicates(self) -> None:
        token = self._session()
        report_id = str(uuid.uuid4())
        payload = self._feedback_payload(report_id)
        headers = self._feedback_headers(token, report_id)

        first = self._request("/v1/feedback", payload, headers)
        duplicate = self._request("/v1/feedback", payload, headers)

        self.assertEqual(first["status"], "202 Accepted")
        self.assertEqual(duplicate["status"], "200 OK")
        self.assertTrue(duplicate["json"]["duplicate"])
        self.assertEqual(len(_UpstreamHandler.requests), 1)
        path, upstream_headers, body = _UpstreamHandler.requests[0]
        self.assertEqual(path, "/upstream")
        self.assertIn("multipart/form-data", upstream_headers["Content-Type"])
        self.assertIn(b'"allowed_mentions":{"parse":[]}', body)
        self.assertIn(b"@everyone", body)
        self.assertIn(_jpeg(), body)
        self.assertNotIn(token.encode("ascii"), body)

        changed = dict(payload)
        changed["description"] = "different body under the same key"
        mismatch = self._request("/v1/feedback", changed, headers)
        self.assertEqual(mismatch["status"], "409 Conflict")
        self.assertEqual(mismatch["json"]["error"], "idempotency_payload_mismatch")
        self.assertEqual(len(_UpstreamHandler.requests), 1)

        changed_transport = dict(payload)
        changed_transport["screenshot_jpeg_base64"] = None
        mismatch = self._request("/v1/feedback", changed_transport, headers)
        self.assertEqual(mismatch["status"], "409 Conflict")
        self.assertEqual(mismatch["json"]["error"], "idempotency_payload_mismatch")
        self.assertEqual(len(_UpstreamHandler.requests), 1)

    def test_text_only_delivery_uses_json_without_attachment(self) -> None:
        token = self._session()
        report_id = str(uuid.uuid4())
        payload = self._feedback_payload(
            report_id, description="text-only report @everyone", screenshot=False
        )
        response = self._request(
            "/v1/feedback", payload, self._feedback_headers(token, report_id)
        )

        self.assertEqual(response["status"], "202 Accepted")
        self.assertEqual(len(_UpstreamHandler.requests), 1)
        _path, upstream_headers, body = _UpstreamHandler.requests[0]
        self.assertEqual(upstream_headers["Content-Type"], "application/json; charset=utf-8")
        forwarded = json.loads(body.decode("utf-8"))
        self.assertEqual(forwarded["allowed_mentions"], {"parse": []})
        self.assertEqual(forwarded["attachments"], [])
        self.assertIn("text-only report @everyone", forwarded["content"])
        self.assertNotIn(_jpeg(), body)

    def test_token_is_bound_to_installation_and_expires(self) -> None:
        token = self._session()
        report_id = str(uuid.uuid4())
        other_installation = str(uuid.uuid4())
        mismatch = self._request(
            "/v1/feedback",
            self._feedback_payload(report_id),
            self._feedback_headers(token, report_id, other_installation),
        )
        self.assertEqual(mismatch["status"], "401 Unauthorized")
        self.assertEqual(mismatch["json"]["error"], "session_subject_mismatch")

        self.clock[0] += 601
        expired = self._request(
            "/v1/feedback",
            self._feedback_payload(report_id),
            self._feedback_headers(token, report_id),
        )
        self.assertEqual(expired["status"], "401 Unauthorized")
        self.assertEqual(expired["json"]["error"], "expired_session_token")

        invalid_unicode = self._request(
            "/v1/feedback",
            self._feedback_payload(report_id),
            {
                "HTTP_AUTHORIZATION": "Bearer snowman.☃",
                "HTTP_X_FEEDBACK_INSTALLATION": self.installation_id,
                "HTTP_IDEMPOTENCY_KEY": report_id,
            },
        )
        self.assertEqual(invalid_unicode["status"], "401 Unauthorized")
        self.assertEqual(invalid_unicode["json"]["error"], "invalid_session_token")

    def test_schema_image_and_idempotency_validation_fail_closed(self) -> None:
        token = self._session()
        report_id = str(uuid.uuid4())
        headers = self._feedback_headers(token, report_id)

        unknown_metadata = self._feedback_payload(report_id, metadata={"password": "nope"})
        response = self._request("/v1/feedback", unknown_metadata, headers)
        self.assertEqual(response["status"], "400 Bad Request")
        self.assertEqual(response["json"]["error"], "invalid_metadata")

        invalid_image = self._feedback_payload(report_id)
        invalid_image["screenshot_jpeg_base64"] = base64.b64encode(b"not-a-jpeg").decode("ascii")
        response = self._request("/v1/feedback", invalid_image, headers)
        self.assertEqual(response["json"]["error"], "invalid_screenshot_jpeg")

        invalid_type = self._feedback_payload(report_id)
        invalid_type["screenshot_jpeg_base64"] = False
        response = self._request("/v1/feedback", invalid_type, headers)
        self.assertEqual(response["json"]["error"], "invalid_screenshot_type")

        empty_text_only = self._feedback_payload(report_id, description="  ", screenshot=False)
        response = self._request("/v1/feedback", empty_text_only, headers)
        self.assertEqual(response["json"]["error"], "text_only_description_required")

        other_report = self._feedback_payload(str(uuid.uuid4()))
        response = self._request("/v1/feedback", other_report, headers)
        self.assertEqual(response["json"]["error"], "report_id_mismatch")
        self.assertEqual(_UpstreamHandler.requests, [])

    def test_upstream_failure_becomes_ambiguous_without_duplicate(self) -> None:
        token = self._session()
        report_id = str(uuid.uuid4())
        payload = self._feedback_payload(report_id)
        headers = self._feedback_headers(token, report_id)
        _UpstreamHandler.response_codes.extend([500, 204])

        failed = self._request("/v1/feedback", payload, headers)
        retried = self._request("/v1/feedback", payload, headers)

        self.assertEqual(failed["status"], "502 Bad Gateway")
        self.assertEqual(retried["status"], "422 Unprocessable Entity")
        self.assertEqual(retried["json"]["error"], "delivery_ambiguous")
        self.assertEqual(len(_UpstreamHandler.requests), 1)

    def test_pending_delivery_returns_retryable_conflict(self) -> None:
        token = self._session()
        report_id = str(uuid.uuid4())
        install_hash = self.app._install_hash(self.installation_id)
        payload = self._feedback_payload(report_id)
        report = self.app._validate_feedback(payload, report_id)
        self.assertEqual(
            self.app.store.begin_delivery(report_id, install_hash, _report_digest(report), self.clock[0]),
            "new",
        )

        response = self._request(
            "/v1/feedback",
            payload,
            self._feedback_headers(token, report_id),
        )
        self.assertEqual(response["status"], "409 Conflict")
        self.assertEqual(response["headers"]["Retry-After"], "2")
        self.assertEqual(_UpstreamHandler.requests, [])

    def test_stale_pending_crash_window_becomes_ambiguous_without_resend(self) -> None:
        token = self._session()
        report_id = str(uuid.uuid4())
        payload = self._feedback_payload(report_id)
        report = self.app._validate_feedback(payload, report_id)
        install_hash = self.app._install_hash(self.installation_id)
        self.assertEqual(
            self.app.store.begin_delivery(report_id, install_hash, _report_digest(report), self.clock[0]),
            "new",
        )
        self.clock[0] += 91

        response = self._request(
            "/v1/feedback", payload, self._feedback_headers(token, report_id)
        )
        self.assertEqual(response["status"], "422 Unprocessable Entity")
        self.assertEqual(response["json"]["error"], "delivery_ambiguous")
        self.assertEqual(_UpstreamHandler.requests, [])

    def test_server_side_rate_limit_cannot_be_bypassed_by_report_id(self) -> None:
        token = self._session()
        statuses = []
        for _index in range(6):
            report_id = str(uuid.uuid4())
            response = self._request(
                "/v1/feedback",
                self._feedback_payload(report_id),
                self._feedback_headers(token, report_id),
            )
            statuses.append(response["status"])
        self.assertEqual(statuses[:5], ["202 Accepted"] * 5)
        self.assertEqual(statuses[5], "429 Too Many Requests")
        self.assertGreater(int(response["headers"]["Retry-After"]), 0)
        self.assertEqual(len(_UpstreamHandler.requests), 5)

    def test_global_circuit_breaker_survives_ip_and_installation_rotation(self) -> None:
        limited = FeedbackProxyApp(
            replace(
                self.app.config,
                database_path=str(Path(self.temp.name) / "global.sqlite3"),
                feedback_global_limit=2,
            )
        )
        statuses = []
        for index in range(3):
            installation_id = str(uuid.uuid4())
            remote = "198.51.100.%d" % (index + 1)
            session = self._request(
                "/v1/session",
                {
                    "schema_version": 2,
                    "installation_id": installation_id,
                    "client_version": "0.2.3",
                },
                remote_addr=remote,
                app=limited,
            )
            self.assertEqual(session["status"], "200 OK")
            report_id = str(uuid.uuid4())
            response = self._request(
                "/v1/feedback",
                self._feedback_payload(report_id),
                self._feedback_headers(session["json"]["token"], report_id, installation_id),
                remote_addr=remote,
                app=limited,
            )
            statuses.append(response["status"])
        self.assertEqual(statuses, ["202 Accepted", "202 Accepted", "429 Too Many Requests"])
        self.assertEqual(len(_UpstreamHandler.requests), 2)

    def test_session_global_admission_runs_before_body_parser(self) -> None:
        limited = FeedbackProxyApp(
            replace(
                self.app.config,
                database_path=str(Path(self.temp.name) / "admission.sqlite3"),
                session_global_limit=1,
            )
        )
        first = self._request(
            "/v1/session",
            {
                "schema_version": 2,
                "installation_id": str(uuid.uuid4()),
                "client_version": "0.2.3",
            },
            app=limited,
        )
        self.assertEqual(first["status"], "200 OK")
        with mock.patch.object(limited, "_read_json", side_effect=AssertionError("body parsed")):
            rejected = self._request(
                "/v1/session", {"large": "x" * 100_000}, app=limited
            )
        self.assertEqual(rejected["status"], "429 Too Many Requests")

    def test_logs_exclude_content_network_identity_and_credentials(self) -> None:
        token = self._session()
        report_id = str(uuid.uuid4())
        sentinel = "PRIVATE-PLAYER-TEXT-7f13"
        response = self._request(
            "/v1/feedback",
            self._feedback_payload(report_id, description=sentinel),
            self._feedback_headers(token, report_id),
        )
        self.assertEqual(response["status"], "202 Accepted")
        logs = self.log_stream.getvalue()
        self.assertNotIn(sentinel, logs)
        self.assertNotIn(token, logs)
        self.assertNotIn(self.installation_id, logs)
        self.assertNotIn("203.0.113.10", logs)
        self.assertNotIn("/upstream", logs)

    def test_forwarded_ip_requires_trusted_peer_and_is_canonicalized(self) -> None:
        untrusted = {
            "REMOTE_ADDR": "203.0.113.10",
            "HTTP_X_FORWARDED_FOR": "198.51.100.44",
        }
        self.assertEqual(self.app._client_ip(untrusted), "203.0.113.10")

        trusted = FeedbackProxyApp(
            replace(
                self.app.config,
                database_path=str(Path(self.temp.name) / "trusted-proxy.sqlite3"),
                trusted_proxy_cidrs=("10.0.0.0/8", "2001:db8:feed::/48"),
            )
        )
        self.assertEqual(
            trusted._client_ip(
                {"REMOTE_ADDR": "10.2.3.4", "HTTP_X_FORWARDED_FOR": "2001:0db8::0001"}
            ),
            "2001:db8::1",
        )
        self.assertEqual(
            trusted._client_ip(
                {"REMOTE_ADDR": "203.0.113.10", "HTTP_X_FORWARDED_FOR": "198.51.100.44"}
            ),
            "203.0.113.10",
        )
        self.assertEqual(
            trusted._client_ip(
                {"REMOTE_ADDR": "10.2.3.4", "HTTP_X_FORWARDED_FOR": "not-an-ip"}
            ),
            "10.2.3.4",
        )
        self.assertEqual(
            trusted._ip_hash("203.0.113.10"),
            trusted._ip_hash(trusted._client_ip({"REMOTE_ADDR": "::ffff:203.0.113.10"})),
        )

    def test_environment_config_rejects_short_secrets_and_non_discord_upstream(self) -> None:
        valid = {
            "FEEDBACK_TOKEN_SECRET": "t" * 32,
            "FEEDBACK_LOG_SALT": "l" * 16,
            "FEEDBACK_DISCORD_WEBHOOK": "https://example.com/collect",
        }
        with mock.patch.dict(os.environ, valid, clear=True):
            with self.assertRaisesRegex(RuntimeError, "official HTTPS Discord"):
                Config.from_env()
        valid["FEEDBACK_TOKEN_SECRET"] = "short"
        with mock.patch.dict(os.environ, valid, clear=True):
            with self.assertRaisesRegex(RuntimeError, "at least 32"):
                Config.from_env()

        valid["FEEDBACK_TOKEN_SECRET"] = "t" * 32
        valid["FEEDBACK_DISCORD_WEBHOOK"] = (
            "https://discord.com/api/webhooks/123456789012345678/abcdefghijklmnopqrstuvwxyz_123456"
        )
        valid["FEEDBACK_TRUSTED_PROXY_CIDRS"] = "10.0.0.0/8,not-a-network"
        with mock.patch.dict(os.environ, valid, clear=True):
            with self.assertRaisesRegex(RuntimeError, "invalid network"):
                Config.from_env()


if __name__ == "__main__":
    unittest.main()
