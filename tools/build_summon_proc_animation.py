"""Build functional move/attack animation for the static summon creatures
(pack_spirit, homunculus, leadership_echo) following the druid-wolf system.

We do not have drawn frames for these creatures (and no image API key in this
env), so we synthesize *procedural* frames from each creature's single base PNG:
- move  (8 frames): vertical bob + squash/stretch + slight sway -> reads as a
  lively idle/locomotion loop.
- attack(6 frames): anticipation pull-back -> forward lunge -> contact -> recover.

Frames inherit the white contour glow already baked into the base sprite. Output
mirrors the wolf layout and a SpriteFrames .tres per creature is written so
ally_minion.gd can drive them exactly like the wolf. Codex can later replace
these procedural frames with hand-drawn ones (same paths) for higher fidelity.

Run from project root:  python3 tools/build_summon_proc_animation.py
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ALLIES = ROOT / "assets" / "sprites" / "allies"

CREATURES = {
    "pack_spirit": "ally_druid_pack_spirit.png",
    "homunculus": "ally_homunculus.png",
    "leadership_echo": "ally_leadership_echo.png",
}

MOVE_FRAMES = 8
ATTACK_FRAMES = 6


def transform(base: Image.Image, dx: float, dy: float, sx: float, sy: float, rot: float) -> Image.Image:
    """Scale around centre, rotate, translate, recompose onto same-size canvas."""
    W, H = base.size
    bb = base.getbbox() or (0, 0, W, H)
    sprite = base.crop(bb)
    sw, sh = sprite.size
    sprite = sprite.resize((max(1, int(sw * sx)), max(1, int(sh * sy))), Image.LANCZOS)
    if abs(rot) > 0.01:
        sprite = sprite.rotate(rot, resample=Image.BICUBIC, expand=True)
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    # keep original bbox centre, then apply dx/dy
    cx = (bb[0] + bb[2]) / 2 + dx
    cy = (bb[1] + bb[3]) / 2 + dy
    px = int(round(cx - sprite.width / 2))
    py = int(round(cy - sprite.height / 2))
    canvas.alpha_composite(sprite, (px, py))
    return canvas


def move_params(i: int):
    ph = math.tau * i / MOVE_FRAMES
    dy = -3.0 * math.sin(ph)
    sy = 1.0 - 0.045 * math.cos(ph)
    sx = 1.0 + 0.035 * math.cos(ph)
    rot = 2.2 * math.sin(ph)
    return 0.0, dy, sx, sy, rot


# anticipation -> lunge -> recover (dx forward = +x; code flips for facing)
ATTACK_KEYS = [
    (-6.0, 0.0, 0.97, 0.99, -3.0),
    (-9.0, -1.0, 0.96, 0.98, -4.5),
    (2.0, 0.0, 1.03, 1.02, 1.0),
    (14.0, -2.0, 1.09, 1.06, 5.0),
    (10.0, -1.0, 1.05, 1.03, 3.0),
    (2.0, 0.0, 1.0, 1.0, 0.0),
]


def esc(p: Path) -> str:
    return f"res://{p.relative_to(ROOT).as_posix()}"


def build_tres(creature: str, folder: Path) -> Path:
    attack = [folder / f"ally_{creature}_attack_{i:02d}.png" for i in range(ATTACK_FRAMES)]
    move = [folder / f"ally_{creature}_move_{i:02d}.png" for i in range(MOVE_FRAMES)]
    all_frames = attack + move
    ids = {p: f"{i+1}_{creature[:4]}{i}" for i, p in enumerate(all_frames)}
    lines = ['[gd_resource type="SpriteFrames" format=3]', ""]
    for p in all_frames:
        lines.append(f'[ext_resource type="Texture2D" path="{esc(p)}" id="{ids[p]}"]')
    lines += ["", "[resource]", "animations = [{"]

    def frames_block(seq):
        out = ['"frames": [']
        for j, p in enumerate(seq):
            comma = "," if j < len(seq) - 1 else ""
            out.append('{')
            out.append('"duration": 1.0,')
            out.append(f'"texture": ExtResource("{ids[p]}")')
            out.append('}' + comma)
        out.append("],")
        return out

    lines += frames_block(attack)
    lines += ['"loop": false,', '"name": &"attack",', '"speed": 14.0', "}, {"]
    lines += frames_block(move)
    lines += ['"loop": true,', '"name": &"move",', '"speed": 12.0', "}]"]
    tres = ALLIES / f"ally_{creature}_spriteframes.tres"
    tres.write_text("\n".join(lines) + "\n")
    return tres


def main() -> None:
    for creature, base_name in CREATURES.items():
        base = Image.open(ALLIES / base_name).convert("RGBA")
        folder = ALLIES / creature
        folder.mkdir(exist_ok=True)
        for i in range(MOVE_FRAMES):
            transform(base, *move_params(i)).save(folder / f"ally_{creature}_move_{i:02d}.png")
        for i in range(ATTACK_FRAMES):
            transform(base, *ATTACK_KEYS[i]).save(folder / f"ally_{creature}_attack_{i:02d}.png")
        tres = build_tres(creature, folder)
        print(f"{creature}: {MOVE_FRAMES} move + {ATTACK_FRAMES} attack -> {tres.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
