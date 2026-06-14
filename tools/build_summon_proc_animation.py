"""Build functional move/attack animation for the static summon creatures
following the druid-wolf system.

MOVE is animated through LIMB articulation for pets that have legs/paws (user
request): the lower "legs" band of the sprite is split into two halves which
swing in OPPOSITE phase (front/back pair for the quadruped boar, left/right foot
for the biped homunculus), each rotating about its hip pivot and lifting on the
forward swing — a real stepping gait, not a whole-body bob. Legless spirits
(leadership_echo) keep a gentle hover bob.

ATTACK is a short anticipation -> forward lunge -> recover (whole body).

Frames inherit the white contour glow baked into the base sprite. Output mirrors
the wolf layout; a SpriteFrames .tres per creature is (re)written. Codex can
later replace these with hand-drawn frames on the same paths.

Run from project root:  python3 tools/build_summon_proc_animation.py
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ALLIES = ROOT / "assets" / "sprites" / "allies"

# mode "legs": stepping gait via limb split | mode "hover": floating bob
CREATURES = {
    "pack_spirit": {"base": "ally_druid_pack_spirit.png", "mode": "legs",
                    "hip_frac": 0.66, "leg_rot": 8.0, "leg_lift": 3.5, "body_bob": 1.2},
    "homunculus": {"base": "ally_homunculus.png", "mode": "legs",
                   "hip_frac": 0.80, "leg_rot": 6.0, "leg_lift": 2.5, "body_bob": 1.0},
    "leadership_echo": {"base": "ally_leadership_echo.png", "mode": "hover",
                        "bob": 3.5},
}

MOVE_FRAMES = 8
ATTACK_FRAMES = 6


def shift(img: Image.Image, dx: int, dy: int) -> Image.Image:
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (dx, dy), img)
    return out


def rotate_about(layer: Image.Image, pivot: tuple[float, float], angle: float) -> Image.Image:
    return layer.rotate(angle, resample=Image.BICUBIC, expand=False,
                        center=(pivot[0], pivot[1]))


def move_frame_legs(base: Image.Image, cfg: dict, i: int) -> Image.Image:
    W, H = base.size
    bb = base.getbbox() or (0, 0, W, H)
    sprite = base.crop(bb)
    w, h = sprite.size
    hip = int(cfg["hip_frac"] * h)
    mid = w // 2

    body = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    body.paste(sprite.crop((0, 0, w, hip)), (0, 0))

    legs = sprite.crop((0, hip, w, h))
    left_piece = legs.crop((0, 0, mid, h - hip))
    right_piece = legs.crop((mid, 0, w, h - hip))

    def leg_layer(piece: Image.Image, x0: int, pivot_x: float) -> Image.Image:
        lyr = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        lyr.paste(piece, (x0, hip))
        return lyr

    left = leg_layer(left_piece, 0, w * 0.25)
    right = leg_layer(right_piece, mid, w * 0.75)

    ph = math.tau * i / MOVE_FRAMES
    rot = cfg["leg_rot"]
    lift = cfg["leg_lift"]
    a_l = rot * math.sin(ph)
    a_r = rot * math.sin(ph + math.pi)
    lift_l = -int(round(lift * max(0.0, math.sin(ph))))
    lift_r = -int(round(lift * max(0.0, math.sin(ph + math.pi))))
    body_dy = -int(round(cfg["body_bob"] * abs(math.sin(ph))))

    left = shift(rotate_about(left, (w * 0.25, hip), a_l), 0, lift_l)
    right = shift(rotate_about(right, (w * 0.75, hip), a_r), 0, lift_r)

    frame = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    frame.alpha_composite(left)
    frame.alpha_composite(right)
    frame.alpha_composite(shift(body, 0, body_dy))

    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.paste(frame, (bb[0], bb[1]))
    return out


def move_frame_hover(base: Image.Image, cfg: dict, i: int) -> Image.Image:
    ph = math.tau * i / MOVE_FRAMES
    dy = int(round(-cfg["bob"] * math.sin(ph)))
    return shift(base, 0, dy)


# anticipation -> lunge -> contact -> recover (whole body; dx forward = +x)
ATTACK_KEYS = [(-6, 0, -3.0), (-9, -1, -4.5), (2, 0, 1.0), (14, -2, 5.0), (10, -1, 3.0), (2, 0, 0.0)]


def attack_frame(base: Image.Image, i: int) -> Image.Image:
    W, H = base.size
    bb = base.getbbox() or (0, 0, W, H)
    sprite = base.crop(bb)
    dx, dy, rot = ATTACK_KEYS[i]
    if abs(rot) > 0.01:
        sprite = sprite.rotate(rot, resample=Image.BICUBIC, expand=True)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cx = (bb[0] + bb[2]) / 2 + dx
    cy = (bb[1] + bb[3]) / 2 + dy
    out.alpha_composite(sprite, (int(round(cx - sprite.width / 2)), int(round(cy - sprite.height / 2))))
    return out


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
            out += ['{', '"duration": 1.0,', f'"texture": ExtResource("{ids[p]}")', '}' + comma]
        out.append("],")
        return out

    lines += frames_block(attack) + ['"loop": false,', '"name": &"attack",', '"speed": 14.0', "}, {"]
    lines += frames_block(move) + ['"loop": true,', '"name": &"move",', '"speed": 12.0', "}]"]
    tres = ALLIES / f"ally_{creature}_spriteframes.tres"
    tres.write_text("\n".join(lines) + "\n")
    return tres


def main() -> None:
    for creature, cfg in CREATURES.items():
        base = Image.open(ALLIES / cfg["base"]).convert("RGBA")
        folder = ALLIES / creature
        folder.mkdir(exist_ok=True)
        for i in range(MOVE_FRAMES):
            if cfg["mode"] == "legs":
                frame = move_frame_legs(base, cfg, i)
            else:
                frame = move_frame_hover(base, cfg, i)
            frame.save(folder / f"ally_{creature}_move_{i:02d}.png")
        for i in range(ATTACK_FRAMES):
            attack_frame(base, i).save(folder / f"ally_{creature}_attack_{i:02d}.png")
        build_tres(creature, folder)
        print(f"{creature} [{cfg['mode']}]: {MOVE_FRAMES} move + {ATTACK_FRAMES} attack")


if __name__ == "__main__":
    main()
