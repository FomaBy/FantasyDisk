#!/usr/bin/env python3
"""FAN-2541 — тест разбора текстового отчёта get_object в
tools/fan2541_chakrams_pixellab.py на реальных ответах PixelLab (без сети).

Именно этот разбор решает, готовы кадры или нет, и он дважды дал сбой на живом
прогоне, поэтому закреплён тестом:

  1. Задание в очереди ("pending jobs (1)", "animations: none") — НЕ готово:
     собственный статус объекта уже "completed", и ранний выход тут даёт
     EXIT_INCOMPLETE, как у tools/pixellab_generate_pack.py.
  2. Задание досчитало до 100%, но кадров ещё нет — НЕ готово.
  3. Кадры готовы: заголовок звучит как "animations (1 groups):", а не
     "animations:", и опора на двоеточие в заголовке ждёт вечно.
  4. Готовый отчёт отдаёт ровно 9 URL кадров через общий extract_frame_urls.

Запуск: python3 tools/test_fan2541_chakrams_pixellab.py
"""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools" / "fan2541_chakrams_pixellab.py"

FRAME_TEMPLATE = (
    "https://backblaze.pixellab.ai/file/pixellab-characters/objects/"
    "7a9fb7cd-0060-48a4-a4dc-50f7b1124b0c/defd0c32-6ceb-47aa-b791-02edaa7f93c5/"
    "animations/1f23d1a8-522b-4e27-9cf2-4453eebb5b52/unknown/{i}.png"
)

QUEUED_REPORT = """status: completed
id: defd0c32-6ceb-47aa-b791-02edaa7f93c5
size: 256x256px

animations: none

pending jobs (1):
  the chakram ring keeps exactly the same shape, siz(unknown): 12% ~231s
"""

ALMOST_DONE_REPORT = """status: completed
id: defd0c32-6ceb-47aa-b791-02edaa7f93c5

animations: none

pending jobs (1):
  the chakram ring keeps exactly the same shape, siz(unknown): 100% ~60s
"""

READY_REPORT = """status: completed
id: defd0c32-6ceb-47aa-b791-02edaa7f93c5

animations (1 groups):
  the chakram ring keeps exactly the same  [group: b8cddfa4-f173-4785-a4b1-afb7f4ab8986]
    directions: unknown (1/1)
    frames: 9
    unknown: %s  (i=0..8)
""" % FRAME_TEMPLATE


def load_module():
    spec = importlib.util.spec_from_file_location("fan2541_chakrams_pixellab", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def case_queued_is_not_ready(module):
    assert module.pending_job_count(QUEUED_REPORT) == 1
    assert module.animations_ready(QUEUED_REPORT) is False
    print("  ok: задание в очереди не считается готовым")


def case_almost_done_is_not_ready(module):
    assert module.animations_ready(ALMOST_DONE_REPORT) is False
    print("  ok: 100% без кадров не считается готовым")


def case_ready_report(module):
    assert module.pending_job_count(READY_REPORT) == 0
    assert module.animations_ready(READY_REPORT) is True
    print("  ok: заголовок 'animations (1 groups):' распознан как готовый")


def case_frame_urls(module):
    urls, kind = module.extract_frame_urls({"_raw": READY_REPORT}, 9)
    assert kind == "template", kind
    assert len(urls) == 9, len(urls)
    assert urls[0].endswith("/unknown/0.png"), urls[0]
    assert urls[8].endswith("/unknown/8.png"), urls[8]
    print("  ok: из готового отчёта извлекаются 9 URL кадров")


def main():
    module = load_module()
    print("FAN-2541 chakrams PixelLab report-parsing tests:")
    case_queued_is_not_ready(module)
    case_almost_done_is_not_ready(module)
    case_ready_report(module)
    case_frame_urls(module)
    print("all cases passed")


if __name__ == "__main__":
    main()
