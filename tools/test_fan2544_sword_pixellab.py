#!/usr/bin/env python3
"""FAN-2544 — тест выбора нужной группы анимации в
tools/fan2544_sword_pixellab.py на реальных ответах PixelLab (без сети).

Именно этот выбор решает, чьи кадры будут скачаны, и он дал сбой на живом
прогоне, поэтому закреплён тестом:

  1. Пока задание в очереди, у новой группы ещё нет шаблона кадров — НЕ готово.
  2. Когда объект несёт ДВЕ группы, берётся шаблон запрошенной группы, а не
     первый в отчёте: старая отклонённая группа не должна подменять новую.
  3. Неизвестный group_id не даёт шаблона — вместо тихой подмены пустой ответ.
  4. Из готового отчёта разворачивается ровно 9 URL кадров.

Запуск: python3 tools/test_fan2544_sword_pixellab.py
"""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools" / "fan2544_sword_pixellab.py"

OBJECT_ID = "7d9d666b-bb9a-438b-ba5a-7fea130c9681"
REJECTED_GROUP = "908bfb62-0d57-481b-962f-053d4a84717a"
ACCEPTED_GROUP = "385cfae2-cc60-4e7f-b3fe-9bc42c0b4890"
REJECTED_TEMPLATE = (
    "https://backblaze.pixellab.ai/file/pixellab-characters/objects/"
    "7a9fb7cd-0060-48a4-a4dc-50f7b1124b0c/%s/"
    "animations/c6b1368a-767f-4815-be78-04d3540f5277/unknown/{i}.png" % OBJECT_ID
)
ACCEPTED_TEMPLATE = (
    "https://backblaze.pixellab.ai/file/pixellab-characters/objects/"
    "7a9fb7cd-0060-48a4-a4dc-50f7b1124b0c/%s/"
    "animations/6a5a186a-79ee-45c7-960f-b740f03f1c03/unknown/{i}.png" % OBJECT_ID
)

QUEUED_REPORT = """status: completed
id: %s
size: 256x256px

animations (1 groups):
  the greatsword keeps exactly the same sh  [group: %s]
    directions: unknown (1/1)
    frames: 9
    unknown: %s  (i=0..8)

pending jobs (1):
  every frame shows the same burning red spectral bl(unknown): 17%% ~326s
""" % (OBJECT_ID, REJECTED_GROUP, REJECTED_TEMPLATE)

TWO_GROUP_REPORT = """status: completed
id: %s
size: 256x256px

animations (2 groups):
  the greatsword keeps exactly the same sh  [group: %s]
    directions: unknown (1/1)
    frames: 9
    unknown: %s  (i=0..8)
  every frame shows the same burning red s  [group: %s]
    directions: unknown (1/1)
    frames: 9
    unknown: %s  (i=0..8)
""" % (OBJECT_ID, REJECTED_GROUP, REJECTED_TEMPLATE, ACCEPTED_GROUP, ACCEPTED_TEMPLATE)


def load_module():
    spec = importlib.util.spec_from_file_location("fan2544_sword_pixellab", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def case_queued_is_not_ready(module):
    assert module.pending_job_count(QUEUED_REPORT) == 1
    template, count = module.frame_template(QUEUED_REPORT, ACCEPTED_GROUP)
    assert template is None and count == 0, (template, count)
    print("  ok: пока задание в очереди, у новой группы нет шаблона кадров")


def case_named_group_wins(module):
    assert module.pending_job_count(TWO_GROUP_REPORT) == 0
    template, count = module.frame_template(TWO_GROUP_REPORT, ACCEPTED_GROUP)
    assert template == ACCEPTED_TEMPLATE, template
    assert count == 9, count
    print("  ok: из двух групп берётся запрошенная, а не первая в отчёте")


def case_unknown_group(module):
    template, count = module.frame_template(TWO_GROUP_REPORT, "00000000-0000-0000-0000-000000000000")
    assert template is None and count == 0, (template, count)
    print("  ok: неизвестная группа не подменяется чужим шаблоном")


def case_frame_urls(module):
    template, count = module.frame_template(TWO_GROUP_REPORT, ACCEPTED_GROUP)
    urls = [template.replace("{i}", str(i)) for i in range(count)]
    assert len(urls) == 9, len(urls)
    assert urls[0].endswith("/unknown/0.png"), urls[0]
    assert urls[8].endswith("/unknown/8.png"), urls[8]
    print("  ok: из готового отчёта разворачиваются 9 URL кадров")


def main():
    module = load_module()
    print("FAN-2544 sword PixelLab group-selection tests:")
    case_queued_is_not_ready(module)
    case_named_group_wins(module)
    case_unknown_group(module)
    case_frame_urls(module)
    print("all cases passed")


if __name__ == "__main__":
    main()
