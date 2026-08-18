#!/usr/bin/env python3
"""FAN-2924 — smoke/unit тест полинга tools/pixellab_generate_pack.py на моках.

Проверки (без токена и сети):
  1. Успех: create -> poll -> animate -> poll -> download -> манифест, код 0.
  2. Таймаут: потолок исчерпан, задание не завершено — ненулевой код EXIT_TIMEOUT
     и сообщение о незавершённом задании.
  3. Ошибка API (JSON-RPC error) — ненулевой код EXIT_API_ERROR.
  4. Неполный пак (кадров меньше --frame-count) — ненулевой код EXIT_INCOMPLETE.

Запуск: python3 tools/test_pixellab_generate_pack.py
"""

from __future__ import annotations

import importlib.util
import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools" / "pixellab_generate_pack.py"

FRAME_COUNT = 4


def load_module():
    spec = importlib.util.spec_from_file_location("pixellab_generate_pack", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class FakeClock:
    def __init__(self):
        self.now = 1000.0

    def __call__(self):
        return self.now

    def sleep(self, seconds):
        self.now += seconds


def make_call_fn(script, clock):
    """script: list of (tool_name -> response dict). Raises if called beyond script."""
    calls = {"count": 0, "log": []}

    def call_fn(tool_name, arguments, bearer, call_id):
        calls["count"] += 1
        calls["log"].append(tool_name)
        if tool_name not in script:
            raise AssertionError("unexpected tool call: %s" % tool_name)
        entry = script[tool_name]
        if isinstance(entry, Exception):
            raise entry
        if callable(entry):
            return entry(clock)
        return entry

    return call_fn, calls


def completed_object(frame_count=FRAME_COUNT):
    return {
        "status": "completed",
        "animations": [{
            "id": "anim-1",
            "frames": [{"url": "https://img.example/f%d.png" % i} for i in range(frame_count)],
        }],
    }


class Args:
    def __init__(self, tmp, frame_count=FRAME_COUNT):
        self.source_dir = str(tmp / "frames")
        self.manifest_out = str(tmp / "manifest.json")
        self.description = "test object"
        self.animation_description = "test animation"
        self.object_id = None
        self.frame_prefix = "test_f"
        self.frame_count = frame_count
        self.size = 256
        self.view = "top-down"
        self.animate_mode = "v3"
        self.poll_interval = 30.0
        self.timeout = 900.0


def run_case(module, script, frame_count=FRAME_COUNT):
    tmp = tempfile.mkdtemp(prefix="pixellab_gen_test_")
    clock = FakeClock()
    call_fn, calls = make_call_fn(script, clock)

    downloaded = []

    def download_fn(url, path):
        downloaded.append((url, path))
        with open(path, "wb") as fh:
            fh.write(b"png")
        return 3

    args = Args(Path(tmp), frame_count=frame_count)
    token = os.environ.get("PIXELLAB_BEARER_TOKEN")
    os.environ["PIXELLAB_BEARER_TOKEN"] = "test-token"
    try:
        code = module.run(args, call_fn=call_fn, download_fn=download_fn,
                          sleep_fn=clock.sleep, clock=clock, log=lambda *_: None)
    finally:
        if token is None:
            del os.environ["PIXELLAB_BEARER_TOKEN"]
        else:
            os.environ["PIXELLAB_BEARER_TOKEN"] = token
    return code, calls, Path(tmp), downloaded


def case_success(module):
    pending_then_done = {"iter": 0}

    def get_object(clock):
        pending_then_done["iter"] += 1
        if pending_then_done["iter"] % 2 == 1:
            return {"status": "generating", "progress": "50%"}
        return completed_object()

    script = {
        "create_1_direction_object": {"object_id": "obj-123"},
        "get_object": get_object,
        "animate_object": {"job": "anim"},
    }
    code, calls, tmp, downloaded = run_case(module, script)
    assert code == 0, "expected exit 0, got %s" % code
    assert len(downloaded) == FRAME_COUNT, downloaded
    manifest = json.loads((tmp / "manifest.json").read_text())
    assert manifest["frame_count"] == FRAME_COUNT
    assert manifest["object"]["pixel_lab_object_id"] == "obj-123"
    assert manifest["tool_version"] == module.TOOL_VERSION
    assert "test-token" not in json.dumps(manifest), "token leaked into manifest"
    shutil.rmtree(tmp)
    print("  ok: success path (exit 0, manifest written, %d frames)" % FRAME_COUNT)


def case_timeout(module):
    script = {
        "create_1_direction_object": {"object_id": "obj-timeout"},
        "get_object": {"status": "generating", "progress": "10%"},
        "animate_object": {"job": "anim"},
    }
    tmp = tempfile.mkdtemp(prefix="pixellab_gen_test_")
    clock = FakeClock()
    call_fn, calls = make_call_fn(script, clock)
    args = Args(Path(tmp))
    args.timeout = 100.0
    args.poll_interval = 30.0
    os.environ["PIXELLAB_BEARER_TOKEN"] = "test-token"
    messages = []
    try:
        code = module.run(args, call_fn=call_fn, download_fn=lambda u, p: 0,
                          sleep_fn=clock.sleep, clock=clock, log=messages.append)
    finally:
        del os.environ["PIXELLAB_BEARER_TOKEN"]
    assert code == module.EXIT_TIMEOUT, "expected EXIT_TIMEOUT, got %s" % code
    assert any("obj-timeout" in m and "generating" in m for m in messages), messages
    shutil.rmtree(tmp)
    print("  ok: timeout -> exit %d, unfinished job named in output" % module.EXIT_TIMEOUT)


def case_api_error(module):
    script = {
        "create_1_direction_object": module.ApiError("JSON-RPC error: quota exceeded"),
        "get_object": completed_object(),
        "animate_object": {"job": "anim"},
    }
    code, calls, tmp, downloaded = run_case(module, script)
    assert code == module.EXIT_API_ERROR, "expected EXIT_API_ERROR, got %s" % code
    assert not downloaded
    shutil.rmtree(tmp)
    print("  ok: API error -> exit %d" % module.EXIT_API_ERROR)


def case_incomplete_pack(module):
    script = {
        "create_1_direction_object": {"object_id": "obj-short"},
        "get_object": completed_object(frame_count=FRAME_COUNT - 1),
        "animate_object": {"job": "anim"},
    }
    code, calls, tmp, downloaded = run_case(module, script)
    assert code == module.EXIT_INCOMPLETE, "expected EXIT_INCOMPLETE, got %s" % code
    assert len(downloaded) == FRAME_COUNT - 1
    shutil.rmtree(tmp)
    print("  ok: incomplete pack -> exit %d" % module.EXIT_INCOMPLETE)


def main():
    module = load_module()
    print("FAN-2924 pixellab_generate_pack mocked polling tests:")
    case_success(module)
    case_timeout(module)
    case_api_error(module)
    case_incomplete_pack(module)
    print("all cases passed")


if __name__ == "__main__":
    main()
