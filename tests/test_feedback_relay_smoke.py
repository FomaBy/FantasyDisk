from __future__ import annotations

import json
import sys
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from unittest import mock
from wsgiref.simple_server import WSGIRequestHandler, make_server


ROOT = Path(__file__).resolve().parents[1]
SERVICE_ROOT = ROOT / "services" / "feedback_proxy"
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(SERVICE_ROOT))

from feedback_proxy.app import Config, FeedbackProxyApp  # noqa: E402
from tools import feedback_relay_smoke as smoke  # noqa: E402


class _FakeDiscordHandler(BaseHTTPRequestHandler):
    requests: list[tuple[dict[str, str], bytes]] = []
    response_code = 204

    def do_POST(self) -> None:
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length)
        self.__class__.requests.append((dict(self.headers), body))
        try:
            self.send_response(self.__class__.response_code)
            self.end_headers()
        except BrokenPipeError:
            pass

    def log_message(self, _format: str, *_args: object) -> None:
        return


class _QuietWSGIHandler(WSGIRequestHandler):
    def log_message(self, _format: str, *_args: object) -> None:
        return


class FeedbackRelaySmokeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.upstream = ThreadingHTTPServer(("127.0.0.1", 0), _FakeDiscordHandler)
        cls.upstream_thread = threading.Thread(target=cls.upstream.serve_forever, daemon=True)
        cls.upstream_thread.start()

    @classmethod
    def tearDownClass(cls) -> None:
        cls.upstream.shutdown()
        cls.upstream.server_close()
        cls.upstream_thread.join(timeout=3)

    def setUp(self) -> None:
        _FakeDiscordHandler.requests = []
        _FakeDiscordHandler.response_code = 204
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        upstream_port = self.upstream.server_address[1]
        app = FeedbackProxyApp(
            Config(
                token_secret=b"T" * 32,
                log_salt=b"L" * 32,
                discord_webhook_url="http://127.0.0.1:%d/upstream" % upstream_port,
                database_path=str(Path(self.temp.name) / "relay.sqlite3"),
                upstream_timeout=0.05,
                allow_test_upstream=True,
            )
        )
        self.relay = make_server(
            "127.0.0.1", 0, app, handler_class=_QuietWSGIHandler
        )
        self.relay_thread = threading.Thread(target=self.relay.serve_forever, daemon=True)
        self.relay_thread.start()
        self.session_url = "http://127.0.0.1:%d/v1/session" % self.relay.server_port

    def tearDown(self) -> None:
        self.relay.shutdown()
        self.relay.server_close()
        self.relay_thread.join(timeout=3)

    def test_smoke_covers_relay_paths_and_fake_upstream(self) -> None:
        evidence = smoke.run_smoke(self.session_url, timeout=1.0)

        self.assertTrue(evidence["ok"], evidence)
        self.assertEqual(
            [check["name"] for check in evidence["checks"]],
            [
                "health",
                "session",
                "text_only",
                "same_key_duplicate",
                "same_key_conflict",
                "image",
            ],
        )
        self.assertEqual(len(_FakeDiscordHandler.requests), 2)
        content_types = [headers["Content-Type"] for headers, _body in _FakeDiscordHandler.requests]
        self.assertEqual(content_types[0], "application/json; charset=utf-8")
        self.assertTrue(content_types[1].startswith("multipart/form-data; boundary="))

    def test_upstream_error_is_a_redacted_smoke_failure(self) -> None:
        _FakeDiscordHandler.response_code = 500
        evidence = smoke.run_smoke(self.session_url, timeout=1.0)
        serialized = json.dumps(evidence)

        self.assertFalse(evidence["ok"])
        self.assertEqual(evidence["failure"], {
            "check": "text_only",
            "kind": "unexpected_status",
            "status": 502,
        })
        self.assertNotIn(self.session_url, serialized)
        self.assertNotIn("FantasyDisk staging smoke", serialized)
        self.assertEqual(len(_FakeDiscordHandler.requests), 1)

    def test_client_timeout_and_session_value_are_redacted(self) -> None:
        with mock.patch.object(smoke, "_request_json", side_effect=smoke._TransportFailure("timeout")):
            timed_out = smoke.run_smoke(self.session_url, timeout=1.0)
        self.assertEqual(timed_out["failure"], {"check": "health", "kind": "timeout"})

        session_value = "private-session-value.signature"
        responses = [
            (200, {"status": "ok"}),
            (200, {"token": session_value}),
            (202, {"accepted": True, "duplicate": False}),
            (200, {"accepted": True, "duplicate": True}),
            (409, {"error": "idempotency_payload_mismatch"}),
            (202, {"accepted": True, "duplicate": False}),
        ]
        with mock.patch.object(smoke, "_request_json", side_effect=responses):
            evidence = smoke.run_smoke(self.session_url, timeout=1.0)
        serialized = json.dumps(evidence)
        self.assertTrue(evidence["ok"])
        self.assertNotIn(session_value, serialized)
        self.assertNotIn(self.session_url, serialized)

    def test_endpoint_rejects_non_public_shapes(self) -> None:
        invalid = [
            "http://feedback.example.org/v1/session",
            "https://user@feedback.example.org/v1/session",
            "https://feedback.example.org/v1/session?debug=1",
            "https://feedback.example.org/other",
        ]
        for value in invalid:
            with self.subTest(value=value), self.assertRaises(ValueError):
                smoke._session_endpoint(value)
        self.assertEqual(
            smoke._session_endpoint("https://feedback.example.org/v1/session"),
            "https://feedback.example.org/v1/session",
        )


class FeedbackRelayDeployBundleTests(unittest.TestCase):
    def test_compose_and_environment_template_are_hardened_and_complete(self) -> None:
        compose = (SERVICE_ROOT / "compose.yaml").read_text(encoding="utf-8")
        for required in (
            '"127.0.0.1:8080:8080"',
            "read_only: true",
            "tmpfs:",
            "feedback-data:/data",
            "cpus: 1.0",
            "mem_limit: 128m",
            "pids_limit: 80",
            "replicas: 1",
            "no-new-privileges:true",
        ):
            self.assertIn(required, compose)

        values = {}
        for line in (SERVICE_ROOT / "relay.env.example").read_text(encoding="utf-8").splitlines():
            if line and not line.startswith("#"):
                name, value = line.split("=", 1)
                values[name] = value
        self.assertEqual(
            set(values),
            {
                "FEEDBACK_TOKEN_SECRET",
                "FEEDBACK_LOG_SALT",
                "FEEDBACK_DISCORD_WEBHOOK",
                "FEEDBACK_DATABASE_PATH",
                "FEEDBACK_LISTEN_HOST",
                "FEEDBACK_LISTEN_PORT",
                "FEEDBACK_UPSTREAM_TIMEOUT",
                "FEEDBACK_TRUSTED_PROXY_CIDRS",
                "FEEDBACK_SESSION_GLOBAL_LIMIT",
                "FEEDBACK_GLOBAL_LIMIT",
                "FEEDBACK_MAX_WORKERS",
                "FEEDBACK_READ_TIMEOUT",
                "FEEDBACK_LOG_LEVEL",
            },
        )
        self.assertEqual(values["FEEDBACK_TOKEN_SECRET"], "")
        self.assertEqual(values["FEEDBACK_LOG_SALT"], "")
        self.assertEqual(values["FEEDBACK_DISCORD_WEBHOOK"], "")


if __name__ == "__main__":
    unittest.main()
