#!/usr/bin/env python3
"""Generate a FantasyDisk reference PNG and a Multica-linked task mirror."""

from __future__ import annotations

import argparse
import base64
import os
import re
import sys
from datetime import date
from pathlib import Path
from textwrap import dedent


MODEL = "gpt-image-2"
QUALITY_VALUES = {"low", "medium", "high", "auto"}
FUTURE_REFERENCE_ROOT = Path("docs/design/reference-assets-lfs")

# gpt-image-2 pixel budget (empirical): requests below ~1.0 MP are rejected with
# "below the current minimum pixel budget"; very large requests are rejected too.
# Aspect must stay within 1:3..3:1 and each side divisible by 16.
MIN_PIXELS = 1024 * 1024          # ~1.05 MP floor
MAX_PIXELS = 3840 * 2160          # conservative ceiling
MAX_SIDE = 3840
MIN_RATIO, MAX_RATIO = 1.0 / 3.0, 3.0

# Where to look for an OpenAI key if it is not already exported in the shell.
ENV_FILES = (
    Path.home() / ".codex" / ".env",
    Path.cwd() / ".env",
)


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(2)


def load_api_key() -> None:
    """Ensure OPENAI_API_KEY is set; source it from known .env files if needed.

    The generator only reads os.environ, but the key usually lives in
    ~/.codex/.env (as `export OPENAI_API_KEY=...`). Load it transparently so
    callers don't have to `source` the file first.
    """
    if os.environ.get("OPENAI_API_KEY"):
        return
    key_re = re.compile(r"""^\s*(?:export\s+)?OPENAI_API_KEY\s*=\s*['"]?([^'"\s]+)['"]?\s*$""")
    for env_file in ENV_FILES:
        try:
            for line in env_file.read_text(encoding="utf-8").splitlines():
                m = key_re.match(line)
                if m:
                    os.environ["OPENAI_API_KEY"] = m.group(1)
                    return
        except OSError:
            continue


def find_project_root(start: Path) -> Path:
    for path in (start, *start.parents):
        if (path / "project.godot").exists() and (path / "docs/design").is_dir():
            return path
    fail("run this script from the FantasyDisk project, or a child directory")


def _round16(v: float) -> int:
    return max(16, int(round(v / 16.0)) * 16)


def normalize_size(value: str) -> str:
    """Validate and AUTO-CORRECT a size to a gpt-image-2-acceptable value.

    Rather than failing on the common mistakes (too small for the pixel budget,
    aspect outside 1:3..3:1, not divisible by 16), this clamps/scales the request
    to the nearest valid size and prints what it changed. Hard-invalid input
    (non WIDTHxHEIGHT) still fails fast.
    """
    if value == "auto":
        return value
    match = re.fullmatch(r"([1-9]\d*)x([1-9]\d*)", value)
    if not match:
        fail("--size must be auto or WIDTHxHEIGHT, for example 1024x1024")
    w, h = int(match.group(1)), int(match.group(2))

    # 1) clamp aspect into [1:3, 3:1]
    ratio = w / h
    if ratio > MAX_RATIO:
        h = int(round(w / MAX_RATIO))
    elif ratio < MIN_RATIO:
        w = int(round(h * MIN_RATIO))

    # 2) scale up to the minimum pixel budget (keep aspect)
    if w * h < MIN_PIXELS:
        scale = (MIN_PIXELS / float(w * h)) ** 0.5
        w, h = w * scale, h * scale

    # 3) scale down under the max budget / max side (keep aspect)
    if w * h > MAX_PIXELS:
        scale = (MAX_PIXELS / float(w * h)) ** 0.5
        w, h = w * scale, h * scale
    if max(w, h) > MAX_SIDE:
        scale = MAX_SIDE / float(max(w, h))
        w, h = w * scale, h * scale

    # 4) round to multiples of 16, then re-check the floor once more
    nw, nh = _round16(w), _round16(h)
    if nw * nh < MIN_PIXELS:
        nw, nh = _round16(nw + 16), _round16(nh + 16)

    corrected = f"{nw}x{nh}"
    if corrected != value:
        print(f"note: --size {value} auto-corrected to {corrected} "
              f"(gpt-image-2 needs >=~1MP, aspect 1:3..3:1, /16)", file=sys.stderr)
    return corrected


def slugify(value: str) -> str:
    value = value.lower()
    value = re.sub(r"[^a-z0-9]+", "_", value)
    value = re.sub(r"_+", "_", value).strip("_")
    return value[:64] or "generated_asset"


def _inside(candidate: Path, root: Path) -> bool:
    try:
        candidate.resolve().relative_to(root)
    except ValueError:
        return False
    return True


def resolve_output(project_root: Path, output_arg: str) -> Path:
    # Containment is anchored at the real (symlink-resolved) project root with
    # an unresolved expected path below it: if any component of
    # docs/design/reference-assets-lfs is itself a symlink pointing outside
    # the project, output.resolve() will leave the anchor and the check fails
    # closed instead of silently following the escape.
    project_real = project_root.resolve()
    references_root = project_root / FUTURE_REFERENCE_ROOT
    anchor = project_real / FUTURE_REFERENCE_ROOT
    raw = Path(output_arg).expanduser()

    if raw.is_absolute():
        output = raw
        if not _inside(output, anchor):
            fail("absolute --output must be inside docs/design/reference-assets-lfs/<issue-or-pack>/")
    else:
        parts = raw.parts
        if len(parts) >= 3 and Path(*parts[:3]) == FUTURE_REFERENCE_ROOT:
            output = project_root / raw
        elif len(parts) >= 3 and parts[:2] == ("docs", "design"):
            fail("--output design path must use docs/design/reference-assets-lfs/<issue-or-pack>/")
        elif len(parts) > 1:
            output = references_root / raw
        else:
            output = references_root / "generated_assets" / date.today().strftime("%Y_%m_%d") / raw

    if output.suffix != ".png":
        output = output.with_suffix(".png")
    if not _inside(output, anchor):
        fail("--output must remain inside docs/design/reference-assets-lfs/<issue-or-pack>/")
    relative = output.resolve().relative_to(anchor)
    if len(relative.parts) < 2:
        fail("--output must include <issue-or-pack>/<file> under docs/design/reference-assets-lfs/")
    output.parent.mkdir(parents=True, exist_ok=True)
    return output


def unique_task_path(project_root: Path, slug: str) -> Path:
    tasks_root = project_root / "docs/tasks"
    base = tasks_root / f"design_integrate_generated_{slug}_task.md"
    if not base.exists():
        return base
    for index in range(2, 1000):
        candidate = tasks_root / f"design_integrate_generated_{slug}_{index}_task.md"
        if not candidate.exists():
            return candidate
    fail(f"too many existing task files for slug {slug}")


def generate_image(prompt: str, size: str, quality: str) -> bytes:
    try:
        from openai import OpenAI
    except ImportError:
        fail("Python package 'openai' is not installed in this interpreter")

    load_api_key()
    if not os.environ.get("OPENAI_API_KEY"):
        fail("OPENAI_API_KEY is not set (looked in env and "
             + ", ".join(str(p) for p in ENV_FILES) + ")")

    client = OpenAI()
    try:
        result = client.images.generate(
            model=MODEL,
            prompt=prompt,
            size=size,
            quality=quality,
            output_format="png",
        )
    except Exception as exc:  # noqa: BLE001 - surface a clean, actionable message
        msg = str(exc)
        if "moderation" in msg.lower() or "safety" in msg.lower():
            fail(f"OpenAI rejected the prompt (content policy): {msg}")
        if "billing" in msg.lower() or "quota" in msg.lower() or "insufficient" in msg.lower():
            fail(f"OpenAI billing/quota problem — mark the task blocked, do not hand-draw a substitute: {msg}")
        fail(f"OpenAI Images API call failed: {msg}")
    if not result.data or not result.data[0].b64_json:
        fail("OpenAI Images API returned no base64 image data")
    return base64.b64decode(result.data[0].b64_json)


def write_task(
    project_root: Path,
    output_path: Path,
    prompt: str,
    size: str,
    quality: str,
    issue_id: str,
) -> Path:
    references_root = project_root / FUTURE_REFERENCE_ROOT
    rel_output = output_path.relative_to(project_root)
    ref_rel = output_path.relative_to(references_root)
    slug_source = ref_rel.parent.name if ref_rel.parent != Path(".") else output_path.stem
    slug = slugify(slug_source if slug_source else output_path.stem)
    task_path = unique_task_path(project_root, slug)
    created = date.today().isoformat()

    title_name = ref_rel.parent.name if ref_rel.parent != Path(".") else output_path.stem
    title_name = title_name.replace("_", " ").replace("-", " ").strip() or output_path.stem
    body = f"""# Задача Для Design-Агента: Внедрить сгенерированный ассет {title_name}

Статус: specification
Создано: {created}
Автор: Codex asset generator
Исполнитель: Design / Codex. Интеграция в код — через Back-end handoff при необходимости.
Версия: 0.1.5
Multica: {issue_id}

## Autonomy / Approval
Пользователь заранее одобрил изменения в рамках этой задачи. Работать автономно, не ждать дополнительных подтверждений.

## Контекст
Сгенерирован новый PNG-референс через OpenAI Images API для FantasyDisk. Файл лежит в проектной папке референсов и должен быть оценен, доведен до production-ассета или использован как source/reference для внедрения.

## Source Asset
- PNG: `{rel_output.as_posix()}`
- Model: `{MODEL}`
- Size: `{size}`
- Quality: `{quality}`
- Prompt:

```text
{prompt}
```

## Что Нужно Сделать
1. Проверить визуальное качество, соответствие текущему dark fantasy art direction и читаемость в целевом размере.
2. Подготовить финальный ассет в нужной runtime-папке `assets/sprites/...` или оставить как approved reference, если прямое внедрение пока не требуется.
3. Если нужны Godot-сцены, скрипты, импорт, theme mapping или логика подключения — создать/передать Back-end handoff с точными путями и acceptance criteria.
4. Обновить `docs/design/content_registry.md`, релевантные domain docs и `CHANGELOG.md`, если ассет вошел в игру.

## Acceptance Criteria
- [ ] PNG из `docs/design/reference-assets-lfs/<issue-or-pack>/` просмотрен и принят/доработан перед runtime-интеграцией.
- [ ] Финальный ассет, если создается, имеет стабильное имя и лежит в правильной `assets/sprites/...` папке.
- [ ] Не тронуты `.import` файлы без необходимости.
- [ ] При runtime-интеграции пройдены релевантные Godot smoke/UI checks.
- [ ] Multica issue обновлена evidence и актуальным статусом после интеграции.
"""
    task_path.write_text(body, encoding="utf-8")
    return task_path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate a FantasyDisk reference PNG and implementation task."
    )
    parser.add_argument("--prompt", required=True, help="Prompt for the OpenAI Images API.")
    parser.add_argument(
        "--output",
        required=True,
        help="PNG output path or name under docs/design/reference-assets-lfs/<issue-or-pack>/.",
    )
    parser.add_argument("--size", required=True, help="auto or WIDTHxHEIGHT.")
    parser.add_argument("--quality", required=True, choices=sorted(QUALITY_VALUES), help="Image quality.")
    parser.add_argument(
        "--issue",
        help="Existing Multica issue identifier (FAN-123); required when creating a task mirror.",
    )
    parser.add_argument("--no-task", action="store_true",
                        help="Only generate the PNG; skip the integration task mirror. "
                             "Use for batch frame sets to avoid duplicate task spam.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.no_task and not re.fullmatch(r"FAN-[1-9]\d*", args.issue or ""):
        fail("--issue FAN-<number> is required when creating a task mirror")
    project_root = find_project_root(Path.cwd().resolve())
    size = normalize_size(args.size)
    output_path = resolve_output(project_root, args.output)

    image_bytes = generate_image(args.prompt, size, args.quality)
    output_path.write_bytes(image_bytes)

    rel_output = output_path.relative_to(project_root).as_posix()
    print(f"saved: {rel_output}")

    if args.no_task:
        return 0

    task_path = write_task(
        project_root,
        output_path,
        args.prompt,
        size,
        args.quality,
        args.issue,
    )
    print(f"task: {task_path.relative_to(project_root).as_posix()}")
    print(f"multica: {args.issue}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
