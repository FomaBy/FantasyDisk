#!/usr/bin/env python3
"""FAN-2924 — smoke/unit тест полинга tools/pixellab_generate_pack.py на моках.

Проверки (без токена и сети):
  1. Успех: create -> poll -> animate -> poll -> download -> манифест, код 0.
  2. Таймаут: потолок исчерпан, задание не завершено — ненулевой код EXIT_TIMEOUT
     и сообщение о незавершённом задании.
  3. Ошибка API (JSON-RPC error) — ненулевой код EXIT_API_ERROR.
  4. Неполный пак (кадров меньше --frame-count) — ненулевой код EXIT_INCOMPLETE.

FAN-2929 — регрессия трёх дефектов, найденных на живом сервисе:
  5. Объект "completed", группа анимации ещё "queued" — polling обязан
     продолжаться, а не завершаться по статусу объекта.
  6. Строка отчёта "<direction>: <url>" — извлекать URL кадра, а не подпись
     направления.
  7. Кадров на один больше --frame-count (референсный кадр режима v3) — код 0,
     а не EXIT_INCOMPLETE.

Запуск: python3 tools/test_pixellab_generate_pack.py
"""

from __future__ import annotations

import importlib.util
import io
import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools" / "pixellab_generate_pack.py"
LIVE_RESPONSE_FIXTURE = ROOT / "tools" / "fixtures" / "pixellab_completed_object_response.txt"

FRAME_COUNT = 4


def _fake_png_bytes(fill=(10, 20, 30, 255)):
    """A tiny real PNG, decodable and re-encodable, standing in for a downloaded frame."""
    buf = io.BytesIO()
    Image.new("RGBA", (2, 2), fill).save(buf, format="PNG")
    return buf.getvalue()


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


def completed_text_response(include_pending=False):
    raw = LIVE_RESPONSE_FIXTURE.read_text()
    if include_pending:
        return raw.replace(
            "    unknown: https://fixture.invalid/animations/<animation-group-id>/unknown/{i}.png  (i=0..4)\n",
            "",
        )
    return raw.replace(
        "pending jobs (1):\n  sanitized animation [group: <animation-group-id>]\n"
        "    status: pending\n    progress: 50%\n\n",
        "",
    )


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
        data = _fake_png_bytes()
        with open(path, "wb") as fh:
            fh.write(data)
        return len(data)

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
    assert manifest["encoder"]["library"] == "Pillow"
    assert manifest["encoder"]["library_version"], manifest["encoder"]
    assert manifest["encoder"]["builder_version"] == module.TOOL_VERSION
    for frame in manifest["frames"]:
        assert frame["encoded_sha256"], frame
        assert frame["pixel_sha256"], frame
    ok = module.check_pack(str(tmp / "manifest.json"), str(tmp / "frames"), log=lambda *_: None)
    assert ok, "check_pack must pass right after generation"
    shutil.rmtree(tmp)
    print("  ok: success path (exit 0, manifest written with encoder/frame hashes, %d frames)" % FRAME_COUNT)


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


def case_defect1_animation_group_not_ready(module):
    """Object status flips to "completed" while its animation group is still queued.

    Regresses wait_status returning on object status alone (dev HEAD line 119):
    the group has no frames yet, so polling must continue.
    """
    state = {"iter": 0}

    def get_object(clock):
        state["iter"] += 1
        if state["iter"] == 1:
            return {"status": "completed"}  # initial object creation, no animation yet
        if state["iter"] == 2:
            return {
                "status": "completed",
                "animations": [{"id": "anim-1", "status": "queued"}],
            }
        return completed_object()

    script = {
        "create_1_direction_object": {"object_id": "obj-slow"},
        "get_object": get_object,
        "animate_object": {"job": "anim"},
    }
    code, calls, tmp, downloaded = run_case(module, script)
    assert code == 0, "expected exit 0, got %s" % code
    assert calls["log"].count("get_object") == 3, (
        "expected polling to continue past the queued animation group, calls=%r"
        % calls["log"]
    )
    shutil.rmtree(tmp)
    print("  ok: animation group still queued -> polling continues past object status")


def case_defect2_template_extraction(module):
    """Template report line "<direction>: <url>" must yield the frame URL, not the label."""
    obj = {
        "animations": [{
            "_raw": "unknown: https://img.example/anim/{i}.png (i=0..3)",
        }],
    }
    urls, kind = module.extract_frame_urls(obj, FRAME_COUNT)
    assert kind == "template", kind
    assert urls, "expected extracted frame urls, got none"
    assert all(u.startswith("https://img.example/anim/") for u in urls), urls
    assert not any(u.startswith("unknown:") for u in urls), urls
    print("  ok: report line direction label not mistaken for the frame URL")


def case_defect3_reference_frame_extra(module):
    """v3 returns one reference frame on top of --frame-count; that is success, not incomplete."""
    def get_object(clock):
        return completed_object(frame_count=FRAME_COUNT + 1)

    script = {
        "create_1_direction_object": {"object_id": "obj-extra"},
        "get_object": get_object,
        "animate_object": {"job": "anim"},
    }
    code, calls, tmp, downloaded = run_case(module, script, frame_count=FRAME_COUNT)
    assert code == 0, "expected exit 0 with one extra reference frame, got %s" % code
    assert len(downloaded) == FRAME_COUNT + 1
    shutil.rmtree(tmp)
    print("  ok: frame_count+1 frames (v3 reference frame) -> exit 0")


def case_live_text_response_waits_for_frames(module):
    """A completed base object can still list a pending animation job."""
    state = {"polls": 0}

    def get_object(clock):
        state["polls"] += 1
        raw = completed_text_response(include_pending=state["polls"] == 1)
        return {"_raw": raw}

    script = {
        "create_1_direction_object": {"object_id": "obj-text"},
        "get_object": get_object,
        "animate_object": {"job": "anim"},
    }
    code, calls, tmp, downloaded = run_case(module, script)
    assert code == 0, "expected exit 0 for live text response, got %s" % code
    assert calls["log"].count("get_object") == 3, calls["log"]
    assert len(downloaded) == 5, downloaded
    shutil.rmtree(tmp)
    print("  ok: completed text response waits for pending job, then downloads all frames")


def case_empty_completed_response(module):
    """A terminal response without frame URLs must never produce a manifest."""
    script = {
        "create_1_direction_object": {"object_id": "obj-empty"},
        "get_object": {"_raw": "status: completed\nan..."},
        "animate_object": {"job": "anim"},
    }
    code, calls, tmp, downloaded = run_case(module, script)
    assert code == module.EXIT_INCOMPLETE, "expected EXIT_INCOMPLETE, got %s" % code
    assert not downloaded
    assert not (tmp / "manifest.json").exists()
    shutil.rmtree(tmp)
    print("  ok: empty completed response -> exit %d without false manifest" % module.EXIT_INCOMPLETE)


def _write_check_fixture(module, tmp, fill=(10, 20, 30, 255), library_version=None):
    """A one-frame pack (frames dir + manifest) matching what run() would write."""
    frames_dir = tmp / "frames"
    frames_dir.mkdir()
    path = frames_dir / "f00.png"
    path.write_bytes(_fake_png_bytes(fill))
    encoded_sha256, pixel_sha256 = module.frame_hashes(str(path))
    manifest = {
        "encoder": {
            "library": "Pillow",
            "library_version": library_version or module.Image.__version__,
            "builder_version": module.TOOL_VERSION,
        },
        "frames": [{"file": "f00.png", "encoded_sha256": encoded_sha256, "pixel_sha256": pixel_sha256}],
    }
    manifest_path = tmp / "manifest.json"
    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
    return str(manifest_path), str(frames_dir)


def case_check_pack_unchanged(module):
    tmp = Path(tempfile.mkdtemp(prefix="pixellab_check_test_"))
    manifest_path, frames_dir = _write_check_fixture(module, tmp)
    messages = []
    ok = module.check_pack(manifest_path, frames_dir, log=messages.append)
    assert ok, messages
    assert not any(m.startswith("FAIL") for m in messages), messages
    shutil.rmtree(tmp)
    print("  ok: unchanged pack -> check_pack passes")


def case_check_pack_encoder_version_drift_warns(module):
    """Same decoded pixels, different recorded Pillow version, different encoded bytes -> WARN, not FAIL."""
    tmp = Path(tempfile.mkdtemp(prefix="pixellab_check_test_"))
    manifest_path, frames_dir = _write_check_fixture(module, tmp, library_version="1.0.0-fixture-old")
    frame_path = Path(frames_dir) / "f00.png"
    with Image.open(frame_path) as im:
        im.convert("RGBA").save(frame_path, format="PNG", compress_level=1)
    messages = []
    ok = module.check_pack(manifest_path, frames_dir, log=messages.append)
    assert ok, "an encoder-version-only mismatch must not fail: %r" % messages
    warnings = [m for m in messages if m.startswith("WARN")]
    assert warnings, messages
    assert "1.0.0-fixture-old" in warnings[0] and module.Image.__version__ in warnings[0], warnings
    shutil.rmtree(tmp)
    print("  ok: encoder version differs, pixels identical -> warns with both versions, exit 0")


def case_check_pack_real_pixel_drift_fails(module):
    tmp = Path(tempfile.mkdtemp(prefix="pixellab_check_test_"))
    manifest_path, frames_dir = _write_check_fixture(module, tmp)
    (tmp / "frames" / "f00.png").write_bytes(_fake_png_bytes(fill=(200, 5, 5, 255)))
    messages = []
    ok = module.check_pack(manifest_path, frames_dir, log=messages.append)
    assert not ok, "real pixel drift must fail, not warn: %r" % messages
    assert any("decoded pixels changed" in m for m in messages), messages
    shutil.rmtree(tmp)
    print("  ok: real decoded-pixel drift -> check_pack fails closed")


def case_check_pack_missing_encoder_fails(module):
    tmp = Path(tempfile.mkdtemp(prefix="pixellab_check_test_"))
    manifest_path, frames_dir = _write_check_fixture(module, tmp)
    manifest = json.loads(Path(manifest_path).read_text())
    del manifest["encoder"]
    Path(manifest_path).write_text(json.dumps(manifest), encoding="utf-8")
    messages = []
    ok = module.check_pack(manifest_path, frames_dir, log=messages.append)
    assert not ok, "a manifest without encoder provenance must never pass: %r" % messages
    shutil.rmtree(tmp)
    print("  ok: manifest missing \"encoder\" block -> check_pack fails closed")


def case_check_pack_missing_pixel_hash_fails(module):
    tmp = Path(tempfile.mkdtemp(prefix="pixellab_check_test_"))
    manifest_path, frames_dir = _write_check_fixture(module, tmp)
    manifest = json.loads(Path(manifest_path).read_text())
    del manifest["frames"][0]["pixel_sha256"]
    Path(manifest_path).write_text(json.dumps(manifest), encoding="utf-8")
    messages = []
    ok = module.check_pack(manifest_path, frames_dir, log=messages.append)
    assert not ok, "a frame entry without pixel_sha256 must never pass: %r" % messages
    shutil.rmtree(tmp)
    print("  ok: manifest frame missing pixel_sha256 -> check_pack fails closed")


def case_check_pack_corrupt_manifest_json_fails(module):
    tmp = Path(tempfile.mkdtemp(prefix="pixellab_check_test_"))
    manifest_path, frames_dir = _write_check_fixture(module, tmp)
    Path(manifest_path).write_text("{not valid json", encoding="utf-8")
    messages = []
    ok = module.check_pack(manifest_path, frames_dir, log=messages.append)
    assert not ok, "a corrupt manifest must never pass: %r" % messages
    shutil.rmtree(tmp)
    print("  ok: corrupt manifest JSON -> check_pack fails closed")


def case_check_pack_missing_frame_file_fails(module):
    tmp = Path(tempfile.mkdtemp(prefix="pixellab_check_test_"))
    manifest_path, frames_dir = _write_check_fixture(module, tmp)
    (tmp / "frames" / "f00.png").unlink()
    messages = []
    ok = module.check_pack(manifest_path, frames_dir, log=messages.append)
    assert not ok, "a missing frame file must never pass: %r" % messages
    shutil.rmtree(tmp)
    print("  ok: frame file missing on disk -> check_pack fails closed")


def main():
    module = load_module()
    print("FAN-2924 pixellab_generate_pack mocked polling tests:")
    case_success(module)
    case_timeout(module)
    case_api_error(module)
    case_incomplete_pack(module)
    print("FAN-2929 regression tests:")
    case_defect1_animation_group_not_ready(module)
    case_defect2_template_extraction(module)
    case_defect3_reference_frame_extra(module)
    case_live_text_response_waits_for_frames(module)
    case_empty_completed_response(module)
    print("FAN-2921 encoder-provenance check_pack tests:")
    case_check_pack_unchanged(module)
    case_check_pack_encoder_version_drift_warns(module)
    case_check_pack_real_pixel_drift_fails(module)
    case_check_pack_missing_encoder_fails(module)
    case_check_pack_missing_pixel_hash_fails(module)
    case_check_pack_corrupt_manifest_json_fails(module)
    case_check_pack_missing_frame_file_fails(module)
    print("all cases passed")


if __name__ == "__main__":
    main()
