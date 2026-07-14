"""Run the relay with a small threaded WSGI server.

Terminate TLS and restrict direct access at the deployment proxy. For multiple
replicas replace the SQLite Store with shared transactional storage first.
"""
from __future__ import annotations

import logging
import os
import threading
from socketserver import ThreadingMixIn
from wsgiref.simple_server import WSGIRequestHandler, WSGIServer, make_server

from .app import create_app


class ThreadingWSGIServer(ThreadingMixIn, WSGIServer):
    daemon_threads = True
    request_queue_size = 64

    def __init__(self, *args, **kwargs) -> None:
        workers = _positive_int_env("FEEDBACK_MAX_WORKERS", 24)
        self._worker_slots = threading.BoundedSemaphore(workers)
        super().__init__(*args, **kwargs)

    def process_request(self, request, client_address) -> None:
        if not self._worker_slots.acquire(blocking=False):
            request.close()
            return
        try:
            super().process_request(request, client_address)
        except Exception:
            self._worker_slots.release()
            raise

    def process_request_thread(self, request, client_address) -> None:
        try:
            super().process_request_thread(request, client_address)
        finally:
            self._worker_slots.release()


class PrivacyRequestHandler(WSGIRequestHandler):
    def setup(self) -> None:
        self.request.settimeout(float(os.environ.get("FEEDBACK_READ_TIMEOUT", "15")))
        super().setup()

    def log_message(self, _format: str, *_args: object) -> None:
        # The application emits structured pseudonymous events. The stdlib
        # access logger would otherwise write the raw peer IP for every request.
        return


def _positive_int_env(name: str, default: int) -> int:
    try:
        value = int(os.environ.get(name, str(default)))
    except ValueError:
        raise RuntimeError("%s must be a positive integer" % name)
    if value <= 0:
        raise RuntimeError("%s must be a positive integer" % name)
    return value


def main() -> None:
    logging.basicConfig(
        level=os.environ.get("FEEDBACK_LOG_LEVEL", "INFO").upper(),
        format="%(message)s",
    )
    host = os.environ.get("FEEDBACK_LISTEN_HOST", "127.0.0.1")
    port = int(os.environ.get("FEEDBACK_LISTEN_PORT", "8080"))
    with make_server(
        host,
        port,
        create_app(),
        server_class=ThreadingWSGIServer,
        handler_class=PrivacyRequestHandler,
    ) as server:
        server.serve_forever()


if __name__ == "__main__":
    main()
