"""Dependency-free WSGI feedback relay.

The desktop client is untrusted. This service owns the Discord credential,
validates a small versioned request schema, issues short-lived anonymous
session tokens, and applies server-side replay/rate controls before forwarding.
"""
from __future__ import annotations

import base64
import binascii
import hashlib
import hmac
import ipaddress
import io
import json
import logging
import os
import re
import secrets
import sqlite3
import struct
import time
import urllib.error
import urllib.request
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Iterable, Mapping, Optional, Tuple
from urllib.parse import urlparse


SCHEMA_VERSION = 2
MAX_REQUEST_BYTES = 2_000_000
MAX_SESSION_REQUEST_BYTES = 2_048
MAX_DESCRIPTION_CHARS = 4_000
MAX_SCREENSHOT_BYTES = 1_500_000
MAX_SCREENSHOT_DIMENSION = 2_048
TOKEN_TTL_SECONDS = 10 * 60
RATE_WINDOW_SECONDS = 60 * 60
SESSION_IP_LIMIT = 30
SESSION_INSTALL_LIMIT = 12
FEEDBACK_IP_LIMIT = 8
FEEDBACK_INSTALL_LIMIT = 5
SESSION_GLOBAL_LIMIT = 500
FEEDBACK_GLOBAL_LIMIT = 120
PENDING_TTL_SECONDS = 90
IDEMPOTENCY_TTL_SECONDS = 7 * 24 * 60 * 60
RATE_TTL_SECONDS = 2 * RATE_WINDOW_SECONDS
DISCORD_CONTENT_LIMIT = 1_800
UPLOAD_FILENAME = "fantasydisk_feedback.jpg"
INSTALL_HEADER = "HTTP_X_FEEDBACK_INSTALLATION"
IDEMPOTENCY_HEADER = "HTTP_IDEMPOTENCY_KEY"
AUTH_HEADER = "HTTP_AUTHORIZATION"
METADATA_KEYS = (
    "version",
    "character",
    "weapon",
    "ascension",
    "current_act",
    "route_stage",
    "route_scaling_stage",
    "current_node_type",
    "combat_active",
    "boss_active",
    "screen",
    "resolution",
    "os",
    "timestamp",
)
CLIENT_VERSION_RE = re.compile(r"^[A-Za-z0-9._+\-]{1,64}$")
DISCORD_WEBHOOK_RE = re.compile(
    r"^https://(?:discord(?:app)?\.com)/api/webhooks/[0-9]{15,}/[A-Za-z0-9_-]{20,}$"
)


class ClientError(Exception):
    def __init__(self, status: str, code: str, retry_after: int = 0) -> None:
        super().__init__(code)
        self.status = status
        self.code = code
        self.retry_after = retry_after


@dataclass(frozen=True)
class Config:
    token_secret: bytes
    log_salt: bytes
    discord_webhook_url: str
    database_path: str
    upstream_timeout: float = 10.0
    trusted_proxy_cidrs: Tuple[str, ...] = ()
    allow_test_upstream: bool = False
    session_global_limit: int = SESSION_GLOBAL_LIMIT
    feedback_global_limit: int = FEEDBACK_GLOBAL_LIMIT
    now: Callable[[], float] = time.time

    @classmethod
    def from_env(cls) -> "Config":
        token_secret = os.environ.get("FEEDBACK_TOKEN_SECRET", "").encode("utf-8")
        log_salt = os.environ.get("FEEDBACK_LOG_SALT", "").encode("utf-8")
        webhook = os.environ.get("FEEDBACK_DISCORD_WEBHOOK", "").strip()
        if len(token_secret) < 32:
            raise RuntimeError("FEEDBACK_TOKEN_SECRET must contain at least 32 bytes")
        if len(log_salt) < 16:
            raise RuntimeError("FEEDBACK_LOG_SALT must contain at least 16 bytes")
        if not DISCORD_WEBHOOK_RE.fullmatch(webhook):
            raise RuntimeError("FEEDBACK_DISCORD_WEBHOOK must be an official HTTPS Discord webhook")
        return cls(
            token_secret=token_secret,
            log_salt=log_salt,
            discord_webhook_url=webhook,
            database_path=os.environ.get("FEEDBACK_DATABASE_PATH", "/data/feedback_proxy.sqlite3"),
            upstream_timeout=float(os.environ.get("FEEDBACK_UPSTREAM_TIMEOUT", "10")),
            trusted_proxy_cidrs=_trusted_proxy_cidrs(
                os.environ.get("FEEDBACK_TRUSTED_PROXY_CIDRS", "")
            ),
            session_global_limit=_positive_env("FEEDBACK_SESSION_GLOBAL_LIMIT", SESSION_GLOBAL_LIMIT),
            feedback_global_limit=_positive_env("FEEDBACK_GLOBAL_LIMIT", FEEDBACK_GLOBAL_LIMIT),
        )


class Store:
    def __init__(self, path: str) -> None:
        self.path = path
        parent = Path(path).expanduser().resolve().parent
        parent.mkdir(parents=True, exist_ok=True)
        with self._connect() as db:
            db.execute("PRAGMA journal_mode=WAL")
            db.execute(
                "CREATE TABLE IF NOT EXISTS rate_limits ("
                "key TEXT PRIMARY KEY, window_start INTEGER NOT NULL, count INTEGER NOT NULL)"
            )
            db.execute(
                "CREATE TABLE IF NOT EXISTS idempotency ("
                "key TEXT PRIMARY KEY, install_hash TEXT NOT NULL, body_digest TEXT NOT NULL, state TEXT NOT NULL, "
                "updated_at INTEGER NOT NULL)"
            )

    def _connect(self) -> sqlite3.Connection:
        db = sqlite3.connect(self.path, timeout=5.0, isolation_level=None)
        db.execute("PRAGMA busy_timeout=5000")
        return db

    def consume_rate(self, key: str, limit: int, window: int, now: int) -> Tuple[bool, int]:
        with self._connect() as db:
            db.execute("BEGIN IMMEDIATE")
            row = db.execute(
                "SELECT window_start, count FROM rate_limits WHERE key = ?", (key,)
            ).fetchone()
            if row is None or now - int(row[0]) >= window:
                db.execute(
                    "INSERT INTO rate_limits(key, window_start, count) VALUES(?, ?, 1) "
                    "ON CONFLICT(key) DO UPDATE SET window_start=excluded.window_start, count=1",
                    (key, now),
                )
                db.commit()
                return True, 0
            window_start, count = int(row[0]), int(row[1])
            if count >= limit:
                db.rollback()
                return False, max(1, window - (now - window_start))
            db.execute("UPDATE rate_limits SET count = count + 1 WHERE key = ?", (key,))
            db.commit()
            return True, 0

    def begin_delivery(self, key: str, install_hash: str, body_digest: str, now: int) -> str:
        with self._connect() as db:
            db.execute("BEGIN IMMEDIATE")
            row = db.execute(
                "SELECT install_hash, body_digest, state, updated_at FROM idempotency WHERE key = ?", (key,)
            ).fetchone()
            if row is not None:
                if not hmac.compare_digest(str(row[0]), install_hash):
                    db.rollback()
                    raise ClientError("409 Conflict", "idempotency_owner_mismatch")
                if not hmac.compare_digest(str(row[1]), body_digest):
                    db.rollback()
                    raise ClientError("409 Conflict", "idempotency_payload_mismatch")
                state, updated_at = str(row[2]), int(row[3])
                if state == "delivered":
                    db.rollback()
                    return "duplicate"
                if state == "ambiguous":
                    db.rollback()
                    return "ambiguous"
                if now - updated_at < PENDING_TTL_SECONDS:
                    db.rollback()
                    return "pending"
                db.execute(
                    "UPDATE idempotency SET state='ambiguous', updated_at=? WHERE key=?",
                    (now, key),
                )
                db.commit()
                return "ambiguous"
            else:
                db.execute(
                    "INSERT INTO idempotency(key, install_hash, body_digest, state, updated_at) "
                    "VALUES(?, ?, ?, 'pending', ?)",
                    (key, install_hash, body_digest, now),
                )
            db.commit()
            return "new"

    def mark_delivered(self, key: str, now: int) -> None:
        with self._connect() as db:
            db.execute(
                "UPDATE idempotency SET state='delivered', updated_at=? WHERE key=?",
                (now, key),
            )

    def mark_ambiguous(self, key: str, now: int) -> None:
        with self._connect() as db:
            db.execute(
                "UPDATE idempotency SET state='ambiguous', updated_at=? WHERE key=?",
                (now, key),
            )

    def release_delivery(self, key: str) -> None:
        with self._connect() as db:
            db.execute("DELETE FROM idempotency WHERE key=? AND state='pending'", (key,))

    def cleanup(self, now: int) -> None:
        with self._connect() as db:
            db.execute("DELETE FROM rate_limits WHERE window_start < ?", (now - RATE_TTL_SECONDS,))
            db.execute("DELETE FROM idempotency WHERE updated_at < ?", (now - IDEMPOTENCY_TTL_SECONDS,))


class FeedbackProxyApp:
    def __init__(self, config: Config, logger: Optional[logging.Logger] = None) -> None:
        self.config = config
        self.store = Store(config.database_path)
        self.logger = logger or logging.getLogger("fantasydisk.feedback_proxy")
        self._trusted_proxy_networks = tuple(
            ipaddress.ip_network(value, strict=False) for value in config.trusted_proxy_cidrs
        )
        self._validate_upstream()

    def _validate_upstream(self) -> None:
        if DISCORD_WEBHOOK_RE.fullmatch(self.config.discord_webhook_url):
            return
        parsed = urlparse(self.config.discord_webhook_url)
        if self.config.allow_test_upstream and parsed.scheme == "http" and parsed.hostname in {
            "127.0.0.1", "localhost"
        }:
            return
        raise RuntimeError("Discord upstream must be an official webhook; loopback is test-only")

    def __call__(self, environ: Mapping[str, object], start_response: Callable) -> Iterable[bytes]:
        request_tag = secrets.token_hex(6)
        try:
            method = str(environ.get("REQUEST_METHOD", "GET")).upper()
            path = str(environ.get("PATH_INFO", "/"))
            if method == "GET" and path == "/healthz":
                return self._respond(start_response, "200 OK", {"status": "ok"})
            if method == "POST" and path == "/v1/session":
                return self._session(environ, start_response, request_tag)
            if method == "POST" and path == "/v1/feedback":
                return self._feedback(environ, start_response, request_tag)
            raise ClientError("404 Not Found", "not_found")
        except ClientError as exc:
            headers = [("Retry-After", str(exc.retry_after))] if exc.retry_after else []
            self._log("rejected", request_tag, code=exc.code)
            return self._respond(start_response, exc.status, {"error": exc.code}, headers)
        except Exception:
            self.logger.exception(json.dumps({"event": "internal_error", "request": request_tag}))
            return self._respond(start_response, "500 Internal Server Error", {"error": "internal_error"})

    def _session(
        self, environ: Mapping[str, object], start_response: Callable, request_tag: str
    ) -> Iterable[bytes]:
        now = int(self.config.now())
        ip_hash = self._ip_hash(self._client_ip(environ))
        self._rate_or_raise("session:global", self.config.session_global_limit, now)
        self._rate_or_raise("session:ip:" + ip_hash, SESSION_IP_LIMIT, now)
        payload = self._read_json(environ, MAX_SESSION_REQUEST_BYTES)
        if not isinstance(payload, dict):
            raise ClientError("400 Bad Request", "invalid_json_object")
        if set(payload) != {"schema_version", "installation_id", "client_version"}:
            raise ClientError("400 Bad Request", "invalid_session_schema")
        if payload.get("schema_version") != SCHEMA_VERSION:
            raise ClientError("400 Bad Request", "unsupported_schema")
        if not isinstance(payload.get("installation_id"), str) or not isinstance(
            payload.get("client_version"), str
        ):
            raise ClientError("400 Bad Request", "invalid_session_types")
        install_id = self._installation_id(payload["installation_id"])
        client_version = payload["client_version"]
        if not CLIENT_VERSION_RE.fullmatch(client_version):
            raise ClientError("400 Bad Request", "invalid_client_version")
        install_hash = self._install_hash(install_id)
        self._rate_or_raise("session:install:" + install_hash, SESSION_INSTALL_LIMIT, now)
        token = self._issue_token(install_hash, now)
        self.store.cleanup(now)
        self._log("session_issued", request_tag, subject=install_hash[:12])
        return self._respond(
            start_response,
            "200 OK",
            {"token": token, "expires_in": TOKEN_TTL_SECONDS, "schema_version": SCHEMA_VERSION},
            [("Cache-Control", "no-store")],
        )

    def _feedback(
        self, environ: Mapping[str, object], start_response: Callable, request_tag: str
    ) -> Iterable[bytes]:
        install_id = self._installation_id(str(environ.get(INSTALL_HEADER, "")))
        install_hash = self._install_hash(install_id)
        self._verify_authorization(str(environ.get(AUTH_HEADER, "")), install_hash)
        idempotency_key = self._uuid(str(environ.get(IDEMPOTENCY_HEADER, "")), "invalid_idempotency_key")
        now = int(self.config.now())
        ip_hash = self._ip_hash(self._client_ip(environ))
        self._rate_or_raise("feedback:global", self.config.feedback_global_limit, now)
        self._rate_or_raise("feedback:ip:" + ip_hash, FEEDBACK_IP_LIMIT, now)
        self._rate_or_raise("feedback:install:" + install_hash, FEEDBACK_INSTALL_LIMIT, now)
        payload = self._read_json(environ)
        report = self._validate_feedback(payload, idempotency_key)
        delivery_state = self.store.begin_delivery(
            idempotency_key, install_hash, _report_digest(report), now
        )
        if delivery_state == "duplicate":
            self._log("duplicate", request_tag, report=idempotency_key)
            return self._respond(start_response, "200 OK", {"accepted": True, "duplicate": True})
        if delivery_state == "pending":
            raise ClientError("409 Conflict", "delivery_pending", retry_after=2)
        if delivery_state == "ambiguous":
            raise ClientError("422 Unprocessable Entity", "delivery_ambiguous")

        try:
            response_code, retry_after = self._forward(report, idempotency_key)
            if response_code < 200 or response_code >= 300:
                if response_code == 429:
                    raise ClientError("503 Service Unavailable", "upstream_rate_limited", retry_after)
                raise ClientError("502 Bad Gateway", "upstream_rejected")
        except Exception:
            # Discord has no idempotency key. A transport error or non-2xx may
            # happen after the upstream consumed the body, so retrying could
            # duplicate a private report. Preserve an ambiguous tombstone and
            # make the client fall back locally instead of resending.
            self.store.mark_ambiguous(idempotency_key, now)
            raise
        self.store.mark_delivered(idempotency_key, now)
        self._log("delivered", request_tag, report=idempotency_key, subject=install_hash[:12])
        return self._respond(start_response, "202 Accepted", {"accepted": True, "duplicate": False})

    def _validate_feedback(self, payload: object, idempotency_key: str) -> dict:
        if not isinstance(payload, dict):
            raise ClientError("400 Bad Request", "invalid_json_object")
        expected = {"schema_version", "report_id", "description", "metadata", "screenshot_jpeg_base64"}
        if set(payload) != expected:
            raise ClientError("400 Bad Request", "invalid_feedback_schema")
        if payload.get("schema_version") != SCHEMA_VERSION:
            raise ClientError("400 Bad Request", "unsupported_schema")
        report_id = self._uuid(str(payload.get("report_id", "")), "invalid_report_id")
        if not hmac.compare_digest(report_id, idempotency_key):
            raise ClientError("400 Bad Request", "report_id_mismatch")
        if not isinstance(payload.get("description"), str):
            raise ClientError("400 Bad Request", "invalid_description")
        description = payload["description"].strip()
        if len(description) > MAX_DESCRIPTION_CHARS:
            raise ClientError("413 Payload Too Large", "description_too_large")
        metadata = payload.get("metadata")
        if not isinstance(metadata, dict) or any(key not in METADATA_KEYS for key in metadata):
            raise ClientError("400 Bad Request", "invalid_metadata")
        normalized_metadata = {}
        for key, value in metadata.items():
            if isinstance(value, (dict, list)) or value is None:
                raise ClientError("400 Bad Request", "invalid_metadata_value")
            text = str(value)
            if len(text) > 160:
                raise ClientError("413 Payload Too Large", "metadata_value_too_large")
            normalized_metadata[str(key)] = value
        encoded = payload.get("screenshot_jpeg_base64")
        screenshot: Optional[bytes]
        if encoded is None:
            if not description:
                raise ClientError("400 Bad Request", "text_only_description_required")
            screenshot = None
        else:
            if not isinstance(encoded, str):
                raise ClientError("400 Bad Request", "invalid_screenshot_type")
            if len(encoded) > (MAX_SCREENSHOT_BYTES * 4 // 3 + 8):
                raise ClientError("413 Payload Too Large", "screenshot_too_large")
            try:
                screenshot = base64.b64decode(encoded, validate=True)
            except ValueError:
                raise ClientError("400 Bad Request", "invalid_screenshot_base64")
            if not screenshot or len(screenshot) > MAX_SCREENSHOT_BYTES:
                raise ClientError("413 Payload Too Large", "screenshot_too_large")
            if not screenshot.startswith(b"\xff\xd8") or not screenshot.endswith(b"\xff\xd9"):
                raise ClientError("400 Bad Request", "invalid_screenshot_jpeg")
            width, height = _jpeg_dimensions(screenshot)
            if width <= 0 or height <= 0:
                raise ClientError("400 Bad Request", "invalid_screenshot_jpeg")
            if max(width, height) > MAX_SCREENSHOT_DIMENSION:
                raise ClientError("413 Payload Too Large", "screenshot_dimensions_too_large")
        return {"description": description, "metadata": normalized_metadata, "screenshot": screenshot}

    def _read_json(self, environ: Mapping[str, object], max_bytes: int = MAX_REQUEST_BYTES) -> object:
        content_type = str(environ.get("CONTENT_TYPE", "")).split(";", 1)[0].strip().lower()
        if content_type != "application/json":
            raise ClientError("415 Unsupported Media Type", "content_type_must_be_json")
        try:
            length = int(str(environ.get("CONTENT_LENGTH", "0")))
        except ValueError:
            raise ClientError("400 Bad Request", "invalid_content_length")
        if length <= 0 or length > max_bytes:
            raise ClientError("413 Payload Too Large", "request_too_large")
        stream = environ.get("wsgi.input")
        if stream is None or not hasattr(stream, "read"):
            raise ClientError("400 Bad Request", "missing_body")
        raw = stream.read(length)  # type: ignore[union-attr]
        if len(raw) != length:
            raise ClientError("400 Bad Request", "truncated_body")
        try:
            return json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            raise ClientError("400 Bad Request", "invalid_json")

    def _issue_token(self, install_hash: str, now: int) -> str:
        payload = json.dumps(
            {"v": 1, "sub": install_hash, "exp": now + TOKEN_TTL_SECONDS, "nonce": secrets.token_hex(12)},
            separators=(",", ":"),
            sort_keys=True,
        ).encode("utf-8")
        encoded = _base64url(payload)
        signature = hmac.new(self.config.token_secret, encoded.encode("ascii"), hashlib.sha256).digest()
        return encoded + "." + _base64url(signature)

    def _verify_authorization(self, header: str, install_hash: str) -> None:
        if not header.startswith("Bearer "):
            raise ClientError("401 Unauthorized", "missing_session_token")
        token = header[7:].strip()
        parts = token.split(".")
        if len(parts) != 2:
            raise ClientError("401 Unauthorized", "invalid_session_token")
        encoded, encoded_signature = parts
        try:
            signature = _base64url_decode(encoded_signature)
            expected = hmac.new(self.config.token_secret, encoded.encode("ascii"), hashlib.sha256).digest()
            if not hmac.compare_digest(signature, expected):
                raise ValueError
            payload = json.loads(_base64url_decode(encoded).decode("utf-8"))
        except (ValueError, UnicodeEncodeError, UnicodeDecodeError, json.JSONDecodeError, binascii.Error):
            raise ClientError("401 Unauthorized", "invalid_session_token")
        now = int(self.config.now())
        if payload.get("v") != 1 or int(payload.get("exp", 0)) < now:
            raise ClientError("401 Unauthorized", "expired_session_token")
        if not hmac.compare_digest(str(payload.get("sub", "")), install_hash):
            raise ClientError("401 Unauthorized", "session_subject_mismatch")

    def _forward(self, report: dict, report_id: str) -> Tuple[int, int]:
        screenshot = report.get("screenshot")
        if screenshot is None:
            body = _discord_json(report)
            content_type = "application/json; charset=utf-8"
        else:
            boundary = "----FantasyDiskRelay" + secrets.token_hex(12)
            body = _discord_multipart(report, report_id, boundary)
            content_type = "multipart/form-data; boundary=" + boundary
        request = urllib.request.Request(
            self.config.discord_webhook_url,
            data=body,
            headers={
                "Content-Type": content_type,
                "User-Agent": "FantasyDisk-Feedback-Relay/1.0",
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=self.config.upstream_timeout) as response:
                return int(response.status), _retry_after(response.headers)
        except urllib.error.HTTPError as exc:
            return int(exc.code), _retry_after(exc.headers)
        except (urllib.error.URLError, TimeoutError):
            return 0, 0

    def _client_ip(self, environ: Mapping[str, object]) -> str:
        remote = _canonical_ip(str(environ.get("REMOTE_ADDR", "")))
        if remote != "unknown" and self._trusted_proxy_networks:
            remote_address = ipaddress.ip_address(remote)
            if any(remote_address in network for network in self._trusted_proxy_networks):
                forwarded = str(environ.get("HTTP_X_FORWARDED_FOR", "")).split(",", 1)[0].strip()
                canonical_forwarded = _canonical_ip(forwarded)
                if canonical_forwarded != "unknown":
                    return canonical_forwarded
        return remote

    def _ip_hash(self, ip: str) -> str:
        return hmac.new(self.config.log_salt, ip.encode("utf-8"), hashlib.sha256).hexdigest()

    def _install_hash(self, install_id: str) -> str:
        return hmac.new(self.config.log_salt, install_id.encode("ascii"), hashlib.sha256).hexdigest()

    def _rate_or_raise(self, key: str, limit: int, now: int) -> None:
        allowed, retry_after = self.store.consume_rate(key, limit, RATE_WINDOW_SECONDS, now)
        if not allowed:
            raise ClientError("429 Too Many Requests", "rate_limited", retry_after)

    @staticmethod
    def _installation_id(value: str) -> str:
        return FeedbackProxyApp._uuid(value, "invalid_installation_id")

    @staticmethod
    def _uuid(value: str, code: str) -> str:
        try:
            parsed = uuid.UUID(value)
        except ValueError:
            raise ClientError("400 Bad Request", code)
        if parsed.version != 4 or str(parsed) != value.lower():
            raise ClientError("400 Bad Request", code)
        return str(parsed)

    def _log(self, event: str, request_tag: str, **fields: object) -> None:
        record = {"event": event, "request": request_tag}
        record.update(fields)
        self.logger.info(json.dumps(record, separators=(",", ":"), sort_keys=True))

    @staticmethod
    def _respond(
        start_response: Callable,
        status: str,
        payload: Mapping[str, object],
        extra_headers: Optional[list] = None,
    ) -> Iterable[bytes]:
        body = json.dumps(payload, separators=(",", ":"), sort_keys=True).encode("utf-8")
        headers = [
            ("Content-Type", "application/json; charset=utf-8"),
            ("Content-Length", str(len(body))),
            ("X-Content-Type-Options", "nosniff"),
        ]
        headers.extend(extra_headers or [])
        start_response(status, headers)
        return [body]


def _base64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _positive_env(name: str, default: int) -> int:
    raw = os.environ.get(name, str(default))
    try:
        value = int(raw)
    except ValueError:
        raise RuntimeError("%s must be a positive integer" % name)
    if value <= 0:
        raise RuntimeError("%s must be a positive integer" % name)
    return value


def _trusted_proxy_cidrs(raw: str) -> Tuple[str, ...]:
    values = tuple(value.strip() for value in raw.split(",") if value.strip())
    try:
        for value in values:
            ipaddress.ip_network(value, strict=False)
    except ValueError as exc:
        raise RuntimeError("FEEDBACK_TRUSTED_PROXY_CIDRS contains an invalid network") from exc
    return values


def _canonical_ip(value: str) -> str:
    try:
        address = ipaddress.ip_address(value.strip())
    except ValueError:
        return "unknown"
    if isinstance(address, ipaddress.IPv6Address) and address.ipv4_mapped is not None:
        return str(address.ipv4_mapped)
    return address.compressed


def _base64url_decode(value: str) -> bytes:
    return base64.urlsafe_b64decode(value + "=" * (-len(value) % 4))


def _retry_after(headers: Mapping[str, str]) -> int:
    try:
        return max(0, min(30, int(headers.get("Retry-After", "0"))))
    except (TypeError, ValueError):
        return 0


def _jpeg_dimensions(data: bytes) -> Tuple[int, int]:
    if len(data) < 4 or data[:2] != b"\xff\xd8":
        return 0, 0
    index = 2
    sof_markers = {0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF}
    while index + 4 <= len(data):
        if data[index] != 0xFF:
            index += 1
            continue
        while index < len(data) and data[index] == 0xFF:
            index += 1
        if index >= len(data):
            break
        marker = data[index]
        index += 1
        if marker in {0x01, 0xD8, 0xD9} or 0xD0 <= marker <= 0xD7:
            continue
        if index + 2 > len(data):
            break
        length = struct.unpack(">H", data[index:index + 2])[0]
        if length < 2 or index + length > len(data):
            break
        if marker in sof_markers and length >= 7:
            height, width = struct.unpack(">HH", data[index + 3:index + 7])
            return int(width), int(height)
        index += length
    return 0, 0


def _discord_content(description: str, metadata: Mapping[str, object]) -> str:
    lines = [
        "FantasyDisk feedback report",
        "",
        "Описание:",
        description if description else "(без описания)",
        "",
        "Метаданные:",
    ]
    for key in METADATA_KEYS:
        if key in metadata:
            lines.append("- %s: %s" % (key, metadata[key]))
    text = "\n".join(lines)
    return text if len(text) <= DISCORD_CONTENT_LIMIT else text[: DISCORD_CONTENT_LIMIT - 4] + "\n..."


def _report_digest(report: Mapping[str, object]) -> str:
    screenshot = report["screenshot"]
    assert screenshot is None or isinstance(screenshot, bytes)
    canonical = json.dumps(
        {"description": report["description"], "metadata": report["metadata"]},
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    digest = hashlib.sha256()
    digest.update(canonical)
    digest.update(b"\x01" if screenshot is not None else b"\x00")
    if screenshot is not None:
        digest.update(screenshot)
    return digest.hexdigest()


def _discord_json(report: Mapping[str, object]) -> bytes:
    return json.dumps(
        {
            "content": _discord_content(str(report["description"]), report["metadata"]),
            "allowed_mentions": {"parse": []},
            "attachments": [],
        },
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")


def _discord_multipart(report: Mapping[str, object], report_id: str, boundary: str) -> bytes:
    screenshot = report["screenshot"]
    assert isinstance(screenshot, bytes)
    payload = json.dumps(
        {
            "content": _discord_content(str(report["description"]), report["metadata"]),
            "allowed_mentions": {"parse": []},
            "attachments": [{"id": 0, "filename": UPLOAD_FILENAME, "description": report_id}],
        },
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")
    parts = [
        ("--%s\r\n" % boundary).encode("ascii"),
        b'Content-Disposition: form-data; name="payload_json"\r\n',
        b"Content-Type: application/json; charset=utf-8\r\n\r\n",
        payload,
        b"\r\n",
        ("--%s\r\n" % boundary).encode("ascii"),
        ('Content-Disposition: form-data; name="files[0]"; filename="%s"\r\n' % UPLOAD_FILENAME).encode("ascii"),
        b"Content-Type: image/jpeg\r\n\r\n",
        screenshot,
        ("\r\n--%s--\r\n" % boundary).encode("ascii"),
    ]
    return b"".join(parts)


def create_app() -> FeedbackProxyApp:
    return FeedbackProxyApp(Config.from_env())
