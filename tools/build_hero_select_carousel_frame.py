from __future__ import annotations

from collections import deque
from pathlib import Path
import shutil

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs/design/references/carusel/ChatGPT Image Jun 14, 2026, 10_57_24 AM.png"
LIVE = ROOT / "assets/sprites/ui/frames/hero_select/ui_frame_hero_select_thumbnail_strip.png"
BACKUP_DIR = ROOT / "build/cleanup_backup_hero_select_carousel_2026_06_14"
PREVIEW = ROOT / "docs/design/previews/hero_select_carousel_frame_contact.png"
TARGET_SIZE = (1536, 255)
PREVIEW_SIZES = (
    ("1280x720 proportional 1024x170", (1024, 170)),
    ("1920x1080 proportional 1536x255", (1536, 255)),
    ("2560x1440 proportional 2048x340", (2048, 340)),
)


def _is_background(rgb: tuple[int, int, int]) -> bool:
    r, g, b = rgb
    return r > 224 and g > 224 and b > 224 and max(rgb) - min(rgb) < 20


def _flood_background(image: Image.Image) -> set[tuple[int, int]]:
    rgb = image.convert("RGB")
    width, height = rgb.size
    pixels = rgb.load()
    seen: set[tuple[int, int]] = set()
    queue: deque[tuple[int, int]] = deque()

    def add_if_background(x: int, y: int) -> None:
        point = (x, y)
        if point not in seen and _is_background(pixels[x, y]):
            seen.add(point)
            queue.append(point)

    for x in range(width):
        add_if_background(x, 0)
        add_if_background(x, height - 1)
    for y in range(height):
        add_if_background(0, y)
        add_if_background(width - 1, y)

    while queue:
        x, y = queue.popleft()
        for next_x, next_y in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= next_x < width and 0 <= next_y < height:
                add_if_background(next_x, next_y)
    return seen


def _transparent_frame(source: Path) -> Image.Image:
    original = Image.open(source).convert("RGBA")
    width, height = original.size
    background = _flood_background(original)
    pixels = original.load()
    foreground_bounds: list[int] = []

    for y in range(height):
        for x in range(width):
            if (x, y) in background:
                pixels[x, y] = (0, 0, 0, 0)
                continue
            r, g, b, _a = pixels[x, y]
            if r > 235 and g > 235 and b > 235 and max(r, g, b) - min(r, g, b) < 10:
                pixels[x, y] = (0, 0, 0, 0)
                continue
            foreground_bounds.extend([x, y])

    xs = foreground_bounds[0::2]
    ys = foreground_bounds[1::2]
    box = (
        max(min(xs) - 8, 0),
        max(min(ys) - 8, 0),
        min(max(xs) + 9, width),
        min(max(ys) + 9, height),
    )
    cropped = original.crop(box)
    return cropped.resize(TARGET_SIZE, Image.Resampling.LANCZOS)


def _checker(size: tuple[int, int], cell: int = 24) -> Image.Image:
    image = Image.new("RGBA", size, (228, 228, 228, 255))
    draw = ImageDraw.Draw(image)
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            color = (196, 196, 196, 255) if (x // cell + y // cell) % 2 == 0 else (238, 238, 238, 255)
            draw.rectangle((x, y, x + cell - 1, y + cell - 1), fill=color)
    return image


def _paste_center(canvas: Image.Image, image: Image.Image, top: int) -> None:
    x = (canvas.size[0] - image.size[0]) // 2
    canvas.alpha_composite(image, (x, top))


def _build_preview(frame: Image.Image) -> None:
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    variants = [
        ("natural 1536x255", frame),
        *[
            (label, frame.resize(size, Image.Resampling.LANCZOS))
            for label, size in PREVIEW_SIZES
        ],
    ]
    width = 2600
    height = 72 + sum(image.size[1] + 58 for _label, image in variants)
    canvas = _checker((width, height), 32)
    draw = ImageDraw.Draw(canvas)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 24)
    except OSError:
        font = ImageFont.load_default()
    y = 24
    for label, image in variants:
        draw.text((44, y), label, fill=(30, 24, 18, 255), font=font)
        y += 34
        _paste_center(canvas, image, y)
        y += image.size[1] + 24
    canvas.convert("RGB").save(PREVIEW)


def main() -> None:
    if not SOURCE.exists():
        raise FileNotFoundError(SOURCE)
    if not LIVE.exists():
        raise FileNotFoundError(LIVE)

    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    backup = BACKUP_DIR / "ui_frame_hero_select_thumbnail_strip_scrum281.png"
    if not backup.exists():
        shutil.copy2(LIVE, backup)
    import_sidecar = LIVE.with_suffix(LIVE.suffix + ".import")
    if import_sidecar.exists():
        backup_import = BACKUP_DIR / "ui_frame_hero_select_thumbnail_strip_scrum281.png.import"
        if not backup_import.exists():
            shutil.copy2(import_sidecar, backup_import)

    frame = _transparent_frame(SOURCE)
    frame.save(LIVE)
    _build_preview(frame)
    print(f"wrote {LIVE.relative_to(ROOT)} {frame.size[0]}x{frame.size[1]}")
    print(f"backup {backup.relative_to(ROOT)}")
    print(f"preview {PREVIEW.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
