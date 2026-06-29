#!/usr/bin/env python3
import argparse
from pathlib import Path

try:
    from PIL import Image
except ImportError as exc:
    raise SystemExit("Pillow is required: python3 -m pip install Pillow") from exc


DIRECTIONS = [
    "south",
    "south-east",
    "east",
    "north-east",
    "north",
    "north-west",
    "west",
    "south-west",
]


def anim_suffix(direction: str) -> str:
    return direction.replace("-", "_")


def find_source(source_dir: Path, character_id: str, stem: str) -> Path:
    candidates = [
        source_dir / f"{character_id}_{stem}.png",
        source_dir / f"{character_id}_{stem.replace('-', '_')}.png",
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate
    raise FileNotFoundError(f"Missing source frame for {stem}: tried {candidates}")


def normalize_frame(src: Path, dest: Path, cell_size: int, scale: int, bottom_padding: int) -> None:
    image = Image.open(src).convert("RGBA")
    image = image.resize((image.width * scale, image.height * scale), Image.Resampling.NEAREST)
    if image.width > cell_size or image.height + bottom_padding > cell_size:
        raise ValueError(
            f"{src} becomes {image.width}x{image.height}; it does not fit {cell_size}x{cell_size}"
        )
    canvas = Image.new("RGBA", (cell_size, cell_size), (0, 0, 0, 0))
    x = (cell_size - image.width) // 2
    y = cell_size - bottom_padding - image.height
    canvas.alpha_composite(image, (x, y))
    dest.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(dest)


def frame_block(resource_ids: list[str], speed: float, name: str) -> str:
    frames = []
    for resource_id in resource_ids:
        frames.append('{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % resource_id)
    return (
        "{\n"
        '"frames": [%s],\n'
        '"loop": true,\n'
        '"name": &"%s",\n'
        '"speed": %s\n'
        "}"
    ) % (", ".join(frames), name, speed)


def write_spriteframes(
    spriteframes_path: Path,
    runtime_dir: Path,
    project_root: Path,
    character_id: str,
    move_frame_count: int,
    move_speed: float,
) -> None:
    ext_lines = []
    resources: dict[str, str] = {}
    next_id = 1

    def add_resource(path: Path) -> str:
        nonlocal next_id
        key = str(path)
        if key in resources:
            return resources[key]
        resource_id = f"{next_id}_pixellab"
        next_id += 1
        rel = path.resolve().relative_to(project_root).as_posix()
        ext_lines.append(
            f'[ext_resource type="Texture2D" path="res://{rel}" id="{resource_id}"]'
        )
        resources[key] = resource_id
        return resource_id

    idle_ids: dict[str, str] = {}
    move_ids: dict[str, list[str]] = {}
    for direction in DIRECTIONS:
        idle_path = runtime_dir / f"{character_id}_idle_{direction}.png"
        idle_ids[direction] = add_resource(idle_path)
        move_ids[direction] = [
            add_resource(runtime_dir / f"{character_id}_move_{direction}_{index:02d}.png")
            for index in range(move_frame_count)
        ]

    animations = [
        frame_block([idle_ids["south"]], 1.0, "idle"),
        frame_block(move_ids["south"], move_speed, "move"),
        frame_block(move_ids["south"], move_speed, "walk"),
    ]
    for direction in DIRECTIONS:
        suffix = anim_suffix(direction)
        animations.append(frame_block([idle_ids[direction]], 1.0, f"idle_{suffix}"))
    for direction in DIRECTIONS:
        suffix = anim_suffix(direction)
        animations.append(frame_block(move_ids[direction], move_speed, f"move_{suffix}"))
    for direction in DIRECTIONS:
        suffix = anim_suffix(direction)
        animations.append(frame_block(move_ids[direction], move_speed, f"walk_{suffix}"))

    text = (
        '[gd_resource type="SpriteFrames" format=3]\n\n'
        + "\n".join(ext_lines)
        + "\n\n[resource]\nanimations = [\n"
        + ",\n".join(animations)
        + "\n]\n"
    )
    spriteframes_path.parent.mkdir(parents=True, exist_ok=True)
    spriteframes_path.write_text(text, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--character-id", required=True)
    parser.add_argument("--source-dir", required=True, type=Path)
    parser.add_argument("--runtime-dir", required=True, type=Path)
    parser.add_argument("--spriteframes", required=True, type=Path)
    parser.add_argument("--move-frame-count", type=int, default=6)
    parser.add_argument("--cell-size", type=int, default=512)
    parser.add_argument("--scale", type=int, default=4)
    parser.add_argument("--bottom-padding", type=int, default=32)
    parser.add_argument("--move-speed", type=float, default=10.0)
    parser.add_argument("--project-root", type=Path, default=Path.cwd())
    args = parser.parse_args()

    source_dir = args.source_dir
    runtime_dir = args.runtime_dir.resolve()
    project_root = args.project_root.resolve()

    for direction in DIRECTIONS:
        idle_src = find_source(source_dir, args.character_id, f"idle_{direction}")
        idle_dest = runtime_dir / f"{args.character_id}_idle_{direction}.png"
        normalize_frame(idle_src, idle_dest, args.cell_size, args.scale, args.bottom_padding)
        for index in range(args.move_frame_count):
            move_src = find_source(source_dir, args.character_id, f"move_{direction}_{index:02d}")
            move_dest = runtime_dir / f"{args.character_id}_move_{direction}_{index:02d}.png"
            normalize_frame(move_src, move_dest, args.cell_size, args.scale, args.bottom_padding)

    write_spriteframes(
        args.spriteframes,
        runtime_dir,
        project_root,
        args.character_id,
        args.move_frame_count,
        args.move_speed,
    )
    print(f"Wrote {args.spriteframes} and normalized frames in {runtime_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
