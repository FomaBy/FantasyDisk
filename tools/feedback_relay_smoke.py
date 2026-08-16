#!/usr/bin/env python3
"""Exercise a public feedback relay endpoint and emit redacted JSON evidence."""
from __future__ import annotations

import argparse
import base64
import json
import re
import socket
import struct
import sys
import urllib.error
import urllib.request
import uuid
from typing import Mapping, Optional, Sequence
from urllib.parse import urlsplit, urlunsplit


CLIENT_VERSION_RE = re.compile(r"^[A-Za-z0-9._+\-]{1,64}$")


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *_args: object, **_kwargs: object) -> None:
        return None


_OPENER = urllib.request.build_opener(_NoRedirect)


class _TransportFailure(Exception):
    def __init__(self, kind: str) -> None:
        super().__init__(kind)
        self.kind = kind


class _CheckFailure(Exception):
    def __init__(self, check: str, kind: str, status: Optional[int] = None) -> None:
        super().__init__(kind)
        self.check = check
        self.kind = kind
        self.status = status


def _session_endpoint(value: str) -> str:
    parsed = urlsplit(value)
    try:
        port = parsed.port
    except ValueError as exc:
        raise ValueError("endpoint port is invalid") from exc
    if (
        not parsed.hostname
        or parsed.username is not None
        or parsed.password is not None
        or parsed.path != "/v1/session"
        or parsed.query
        or parsed.fragment
        or port == 0
    ):
        raise ValueError("endpoint must be an origin URL ending in /v1/session")
    loopback = parsed.hostname in {"127.0.0.1", "localhost", "::1"}
    if parsed.scheme != "https" and not (parsed.scheme == "http" and loopback):
        raise ValueError("endpoint must use HTTPS (HTTP is allowed only on loopback)")
    return urlunsplit((parsed.scheme, parsed.netloc, parsed.path, "", ""))


def _positive_timeout(value: str) -> float:
    try:
        timeout = float(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("timeout must be a positive number") from exc
    if timeout <= 0:
        raise argparse.ArgumentTypeError("timeout must be a positive number")
    return timeout


def _client_version(value: str) -> str:
    if not CLIENT_VERSION_RE.fullmatch(value):
        raise argparse.ArgumentTypeError("client version must contain 1-64 safe characters")
    return value


def _request_json(
    method: str,
    url: str,
    payload: Optional[Mapping[str, object]],
    headers: Optional[Mapping[str, str]],
    timeout: float,
) -> tuple[int, object]:
    data = None
    request_headers = dict(headers or {})
    if payload is not None:
        data = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        request_headers["Content-Type"] = "application/json"
    request = urllib.request.Request(url, data=data, headers=request_headers, method=method)
    try:
        with _OPENER.open(request, timeout=timeout) as response:
            status = int(response.status)
            raw = response.read(64 * 1024)
    except urllib.error.HTTPError as exc:
        status = int(exc.code)
        raw = exc.read(64 * 1024)
    except (TimeoutError, socket.timeout) as exc:
        raise _TransportFailure("timeout") from exc
    except urllib.error.URLError as exc:
        if isinstance(exc.reason, (TimeoutError, socket.timeout)):
            raise _TransportFailure("timeout") from exc
        raise _TransportFailure("network_error") from exc
    try:
        return status, json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return status, None


def _call(
    check: str,
    method: str,
    url: str,
    payload: Optional[Mapping[str, object]],
    headers: Optional[Mapping[str, str]],
    timeout: float,
) -> tuple[int, object]:
    try:
        return _request_json(method, url, payload, headers, timeout)
    except _TransportFailure as exc:
        raise _CheckFailure(check, exc.kind) from exc


def _require(
    checks: list[dict[str, object]],
    name: str,
    status: int,
    body: object,
    expected_status: int,
    expected_fields: Mapping[str, object],
) -> None:
    if status != expected_status:
        raise _CheckFailure(name, "unexpected_status", status)
    if not isinstance(body, dict) or any(body.get(key) != value for key, value in expected_fields.items()):
        raise _CheckFailure(name, "invalid_response", status)
    checks.append({"name": name, "ok": True, "status": status})


def _jpeg() -> bytes:
    return (
        b"\xff\xd8\xff\xc0"
        + struct.pack(">H", 11)
        + bytes([8])
        + struct.pack(">HH", 18, 32)
        + bytes([1, 1, 0x11, 0])
        + b"\xff\xd9"
    )


def _feedback_payload(report_id: str, client_version: str, image: bool) -> dict[str, object]:
    kind = "image" if image else "text-only"
    return {
        "schema_version": 2,
        "report_id": report_id,
        "description": "FantasyDisk staging smoke: " + kind,
        "metadata": {"version": client_version, "os": "staging-smoke"},
        "screenshot_jpeg_base64": base64.b64encode(_jpeg()).decode("ascii") if image else None,
    }


def run_smoke(session_url: str, client_version: str = "staging-smoke", timeout: float = 10.0) -> dict:
    session_url = _session_endpoint(session_url)
    if not CLIENT_VERSION_RE.fullmatch(client_version):
        raise ValueError("invalid client version")
    if timeout <= 0:
        raise ValueError("timeout must be positive")
    parsed = urlsplit(session_url)
    origin = urlunsplit((parsed.scheme, parsed.netloc, "", "", ""))
    health_url = origin + "/healthz"
    feedback_url = origin + "/v1/feedback"
    checks: list[dict[str, object]] = []
    evidence: dict[str, object] = {
        "schema_version": 1,
        "tool": "feedback_relay_smoke",
        "ok": False,
        "checks": checks,
    }

    try:
        status, body = _call("health", "GET", health_url, None, None, timeout)
        _require(checks, "health", status, body, 200, {"status": "ok"})

        installation_id = str(uuid.uuid4())
        status, body = _call(
            "session",
            "POST",
            session_url,
            {
                "schema_version": 2,
                "installation_id": installation_id,
                "client_version": client_version,
            },
            None,
            timeout,
        )
        if status != 200:
            raise _CheckFailure("session", "unexpected_status", status)
        if not isinstance(body, dict) or not isinstance(body.get("token"), str) or not body["token"]:
            raise _CheckFailure("session", "invalid_response", status)
        token = body["token"]
        checks.append({"name": "session", "ok": True, "status": status})

        text_report_id = str(uuid.uuid4())
        text_payload = _feedback_payload(text_report_id, client_version, image=False)
        text_headers = {
            "Authorization": "Bearer " + token,
            "X-Feedback-Installation": installation_id,
            "Idempotency-Key": text_report_id,
        }
        status, body = _call(
            "text_only", "POST", feedback_url, text_payload, text_headers, timeout
        )
        _require(checks, "text_only", status, body, 202, {"accepted": True, "duplicate": False})

        status, body = _call(
            "same_key_duplicate", "POST", feedback_url, text_payload, text_headers, timeout
        )
        _require(
            checks,
            "same_key_duplicate",
            status,
            body,
            200,
            {"accepted": True, "duplicate": True},
        )

        changed_payload = dict(text_payload)
        changed_payload["description"] = "FantasyDisk staging smoke: changed same-key payload"
        status, body = _call(
            "same_key_conflict", "POST", feedback_url, changed_payload, text_headers, timeout
        )
        _require(
            checks,
            "same_key_conflict",
            status,
            body,
            409,
            {"error": "idempotency_payload_mismatch"},
        )

        image_report_id = str(uuid.uuid4())
        image_payload = _feedback_payload(image_report_id, client_version, image=True)
        image_headers = {
            "Authorization": "Bearer " + token,
            "X-Feedback-Installation": installation_id,
            "Idempotency-Key": image_report_id,
        }
        status, body = _call(
            "image", "POST", feedback_url, image_payload, image_headers, timeout
        )
        _require(checks, "image", status, body, 202, {"accepted": True, "duplicate": False})
    except _CheckFailure as exc:
        failed_check: dict[str, object] = {"name": exc.check, "ok": False, "failure": exc.kind}
        failure: dict[str, object] = {"check": exc.check, "kind": exc.kind}
        if exc.status is not None:
            failed_check["status"] = exc.status
            failure["status"] = exc.status
        checks.append(failed_check)
        evidence["failure"] = failure
        return evidence

    evidence["ok"] = True
    return evidence


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)

    def endpoint(value: str) -> str:
        try:
            return _session_endpoint(value)
        except ValueError as exc:
            raise argparse.ArgumentTypeError(str(exc)) from exc

    parser.add_argument("session_url", type=endpoint, help="public HTTPS /v1/session endpoint")
    parser.add_argument("--client-version", type=_client_version, default="staging-smoke")
    parser.add_argument("--timeout", type=_positive_timeout, default=10.0, help="request timeout in seconds")
    return parser


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = build_parser().parse_args(argv)
    evidence = run_smoke(args.session_url, args.client_version, args.timeout)
    print(json.dumps(evidence, separators=(",", ":"), sort_keys=True))
    return 0 if evidence["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
