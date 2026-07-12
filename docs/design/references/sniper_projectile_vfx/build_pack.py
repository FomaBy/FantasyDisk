#!/usr/bin/env python3
"""Build the SCRUM-934 Sniper VFX component pack from PixelLab sources.

The four source PNGs are immutable PixelLab MCP downloads.  This script only
performs deterministic alpha cleanup, combat-alpha limiting, padding QA and
preview/report generation.  It does not paint replacement art.
"""

from __future__ import annotations

from hashlib import sha256
import json
import math
from pathlib import Path
import shutil

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[4]
REF = ROOT / "docs/design/references/sniper_projectile_vfx"
PREVIEW = ROOT / "docs/design/previews/sniper_projectile_vfx_contact.png"
RUNTIME = ROOT / "assets/sprites/effects"

ASSETS = {
    "sniper_shatter_rounds_projectile": {
        "weapon_id": "sniper_shatter_rounds",
        "role": "repeatable physical projectile, right-facing canonical source",
        "pixel_lab_id": "7da22aa9-112f-4f01-942b-4f6d9d85c380",
        "source": "pixellab_shatter_rounds_projectile_source.png",
        "accepted": "accepted_shatter_rounds_projectile.png",
        "runtime": "vfx_weapon_sniper_shatter_rounds_projectile.png",
        "size": [128, 64],
        "display_size": [48, 24],
        "prompt": (
            "One single small horizontal supersonic sniper projectile pointing right, "
            "blackened steel needle bullet with a tiny pale icy-cyan luminous tail, "
            "sharp readable silhouette at 16 to 24 pixels, D&D dark fantasy pixel art, "
            "restrained selective outline, centered with abundant empty transparent "
            "space. Object only: no gun, no shooter, no explosion, no text, no border, "
            "no background."
        ),
    },
    "sniper_deadeye_rifle_endpoint_impact": {
        "weapon_id": "sniper_deadeye_rifle",
        "role": "precise locked-shot endpoint hit flash",
        "pixel_lab_id": "371efe43-2f92-4c5d-9421-2d56b1eb4895",
        "source": "pixellab_deadeye_endpoint_impact_source.png",
        "accepted": "accepted_deadeye_endpoint_impact.png",
        "runtime": "vfx_weapon_sniper_deadeye_rifle_endpoint_impact.png",
        "size": [192, 192],
        "display_size": [96, 96],
        "prompt": (
            "Compact endpoint hit impact for a precision fantasy sniper shot, white-hot "
            "pinprick center with a narrow gold cross-flash and a few icy cyan steel "
            "shards, crisp directional burst readable at combat scale, D&D dark fantasy "
            "pixel art, centered with safe transparent gutter. Impact only: no gun, no "
            "bullet trail, no character, no magic circle, no text, no border, no background."
        ),
    },
    "sniper_spotter_scope_telegraph": {
        "weapon_id": "sniper_spotter_scope",
        "role": "semi-transparent pending artillery danger zone",
        "pixel_lab_id": "7d95f053-d8d2-4f26-abb9-deeb3c52b3a8",
        "source": "pixellab_spotter_scope_telegraph_source.png",
        "accepted": "accepted_spotter_scope_telegraph.png",
        "runtime": "vfx_weapon_sniper_spotter_scope_telegraph.png",
        "size": [256, 256],
        "display_size": [160, 160],
        "prompt": (
            "Flat top-down pending artillery targeting telegraph: one thin semi-transparent "
            "crimson red circular to slightly oval ring with four restrained black-iron "
            "gothic sight ticks, empty transparent center, calm readable danger-zone outline "
            "for a dark fantasy D&D game. Marker only: no explosion, no beam, no weapon, no "
            "runes, no text, no solid fill, no border, no background."
        ),
    },
    "sniper_spotter_scope_impact": {
        "weapon_id": "sniper_spotter_scope",
        "role": "high-damage shell impact after telegraph",
        "pixel_lab_id": "4fd616e6-1e86-4d7a-9498-ff1cc43980aa",
        "source": "pixellab_spotter_scope_impact_source.png",
        "accepted": "accepted_spotter_scope_impact.png",
        "runtime": "vfx_weapon_sniper_spotter_scope_impact.png",
        "size": [256, 256],
        "display_size": [144, 144],
        "prompt": (
            "Top-down high-damage fantasy artillery shell impact, compact white-hot center, "
            "crimson and ember-orange shock petals, blackened iron fragments and a restrained "
            "dark smoke crown, powerful but clean silhouette readable at combat scale, D&D "
            "dark fantasy pixel art, centered with safe transparent gutter. Impact only: no "
            "targeting ring, no gun, no character, no text, no border, no background."
        ),
    },
}


def _digest(path: Path) -> str:
    return sha256(path.read_bytes()).hexdigest()


def _border_color(image: Image.Image) -> tuple[int, int, int]:
    pixels = image.convert("RGB")
    samples = []
    for x in range(image.width):
        samples.extend((pixels.getpixel((x, 0)), pixels.getpixel((x, image.height - 1))))
    for y in range(image.height):
        samples.extend((pixels.getpixel((0, y)), pixels.getpixel((image.width - 1, y))))
    channels = list(zip(*samples))
    return tuple(sorted(channel)[len(channel) // 2] for channel in channels)


def _clean_flat_background(
    source: Image.Image,
    *,
    threshold: float,
    full_distance: float,
    max_alpha: int,
    radius_limit: float | None = None,
    telegraph_palette: bool = False,
) -> Image.Image:
    image = source.convert("RGBA")
    bg = _border_color(image)
    cx = (image.width - 1) * 0.5
    cy = (image.height - 1) * 0.5
    result = Image.new("RGBA", image.size, (0, 0, 0, 0))
    source_pixels = image.load()
    output_pixels = result.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, _ = source_pixels[x, y]
            if radius_limit is not None and math.hypot(x - cx, y - cy) > radius_limit:
                continue
            distance = math.sqrt((r - bg[0]) ** 2 + (g - bg[1]) ** 2 + (b - bg[2]) ** 2)
            if distance <= threshold:
                continue
            weight = min(1.0, (distance - threshold) / max(1.0, full_distance - threshold))
            alpha = int(round(max_alpha * weight))
            if telegraph_palette:
                is_crimson = r > max(g, b) * 1.45 and r > 110
                if is_crimson:
                    r, g, b = max(r, 168), min(g, 58), min(b, 68)
                    alpha = min(alpha, 104)
                else:
                    alpha = min(alpha, 168)
            if alpha > 0:
                output_pixels[x, y] = (r, g, b, alpha)
    return result


def _metrics(path: Path) -> dict:
    image = Image.open(path).convert("RGBA")
    alpha = image.getchannel("A")
    hist = alpha.histogram()
    bbox = alpha.getbbox()
    coverage = 1.0 - hist[0] / float(image.width * image.height)
    corners = [
        image.getpixel((0, 0))[3],
        image.getpixel((image.width - 1, 0))[3],
        image.getpixel((0, image.height - 1))[3],
        image.getpixel((image.width - 1, image.height - 1))[3],
    ]
    gutter = None
    if bbox:
        gutter = [bbox[0], bbox[1], image.width - bbox[2], image.height - bbox[3]]
    return {
        "path": path.relative_to(ROOT).as_posix(),
        "sha256": _digest(path),
        "size": list(image.size),
        "mode": image.mode,
        "alpha_bbox": list(bbox) if bbox else None,
        "transparent_corners": corners == [0, 0, 0, 0],
        "min_gutter_px": min(gutter) if gutter else 0,
        "coverage_alpha_gt_0": round(coverage, 6),
        "alpha_max": max(index for index, count in enumerate(hist) if count),
        "partial_alpha_pixels": sum(hist[1:255]),
    }


def _font(size: int) -> ImageFont.ImageFont:
    try:
        return ImageFont.truetype("DejaVuSans.ttf", size)
    except OSError:
        return ImageFont.load_default()


def _checker(size: tuple[int, int]) -> Image.Image:
    image = Image.new("RGBA", size, (21, 23, 31, 255))
    draw = ImageDraw.Draw(image)
    step = 16
    for y in range(0, size[1], step):
        for x in range(0, size[0], step):
            if (x // step + y // step) % 2:
                draw.rectangle((x, y, x + step - 1, y + step - 1), fill=(31, 34, 45, 255))
    return image


def _build_preview(accepted_paths: dict[str, Path]) -> None:
    cell = (420, 330)
    sheet = Image.new("RGBA", (cell[0] * 2, cell[1] * 2), (12, 13, 18, 255))
    draw = ImageDraw.Draw(sheet)
    title_font = _font(18)
    note_font = _font(14)
    for index, (asset_id, config) in enumerate(ASSETS.items()):
        ox = (index % 2) * cell[0]
        oy = (index // 2) * cell[1]
        panel = _checker((cell[0] - 24, 250))
        accepted = Image.open(accepted_paths[asset_id]).convert("RGBA")
        full = accepted.copy()
        full.thumbnail((230, 210), Image.Resampling.NEAREST)
        target_size = tuple(config["display_size"])
        combat = accepted.resize(target_size, Image.Resampling.NEAREST)
        panel.alpha_composite(full, ((230 - full.width) // 2, (230 - full.height) // 2 + 18))
        panel.alpha_composite(combat, (252 + (120 - combat.width) // 2, (250 - combat.height) // 2))
        sheet.alpha_composite(panel, (ox + 12, oy + 56))
        draw.text((ox + 16, oy + 14), asset_id, font=title_font, fill=(238, 218, 164, 255))
        draw.text((ox + 16, oy + 35), "source scale | intended combat scale", font=note_font, fill=(176, 184, 202, 255))
        draw.rectangle((ox + 4, oy + 4, ox + cell[0] - 4, oy + cell[1] - 4), outline=(93, 76, 48, 255), width=2)
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(PREVIEW, quality=95)


def main() -> int:
    RUNTIME.mkdir(parents=True, exist_ok=True)
    accepted_paths: dict[str, Path] = {}
    for asset_id, config in ASSETS.items():
        source_path = REF / config["source"]
        if not source_path.exists():
            raise FileNotFoundError(source_path)
        source = Image.open(source_path).convert("RGBA")
        if list(source.size) != config["size"]:
            raise ValueError(f"{source_path}: {source.size} != {config['size']}")
        if asset_id == "sniper_spotter_scope_telegraph":
            accepted = _clean_flat_background(
                source,
                threshold=14.0,
                full_distance=82.0,
                max_alpha=168,
                radius_limit=126.0,
                telegraph_palette=True,
            )
        elif asset_id == "sniper_spotter_scope_impact":
            accepted = _clean_flat_background(
                source,
                threshold=12.0,
                full_distance=76.0,
                max_alpha=235,
                radius_limit=121.0,
            )
        else:
            accepted = source
        accepted_path = REF / config["accepted"]
        accepted.save(accepted_path)
        accepted_paths[asset_id] = accepted_path
        shutil.copyfile(accepted_path, RUNTIME / config["runtime"])

    _build_preview(accepted_paths)

    qa_assets = {}
    failures = []
    for asset_id, config in ASSETS.items():
        source_metrics = _metrics(REF / config["source"])
        accepted_metrics = _metrics(accepted_paths[asset_id])
        runtime_metrics = _metrics(RUNTIME / config["runtime"])
        qa_assets[asset_id] = {
            "pixel_lab_id": config["pixel_lab_id"],
            "source": source_metrics,
            "accepted": accepted_metrics,
            "runtime": runtime_metrics,
            "display_size": config["display_size"],
        }
        if not runtime_metrics["transparent_corners"]:
            failures.append(f"{asset_id}: corners are not transparent")
        if runtime_metrics["min_gutter_px"] < 4:
            failures.append(f"{asset_id}: gutter below 4px")
        if runtime_metrics["coverage_alpha_gt_0"] <= 0.002:
            failures.append(f"{asset_id}: effectively empty")
        if asset_id == "sniper_spotter_scope_telegraph":
            if runtime_metrics["alpha_max"] > 168:
                failures.append(f"{asset_id}: telegraph alpha exceeds 168")
            if not 0.08 <= runtime_metrics["coverage_alpha_gt_0"] <= 0.55:
                failures.append(f"{asset_id}: telegraph coverage outside 0.08..0.55")
        if asset_id == "sniper_spotter_scope_impact" and runtime_metrics["alpha_bbox"]:
            if max(runtime_metrics["alpha_bbox"]) >= 248:
                failures.append(f"{asset_id}: possible edge mark/watermark remains")

    report = {
        "issue": "SCRUM-934",
        "pipeline": "PixelLab MCP create_map_object + deterministic alpha cleanup",
        "status": "PASS" if not failures else "FAIL",
        "failures": failures,
        "assets": qa_assets,
        "contact_sheet": PREVIEW.relative_to(ROOT).as_posix(),
        "visual_review": "PENDING_INDEPENDENT_QA",
    }
    (REF / "qa_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    manifest_assets = []
    for asset_id, config in ASSETS.items():
        manifest_assets.append({
            "asset_id": asset_id,
            "weapon_id": config["weapon_id"],
            "role": config["role"],
            "pixel_lab": {
                "tool": "create_map_object",
                "object_id": config["pixel_lab_id"],
                "prompt": config["prompt"],
                "source_sha256": _digest(REF / config["source"]),
            },
            "source_path": (REF / config["source"]).relative_to(ROOT).as_posix(),
            "accepted_path": accepted_paths[asset_id].relative_to(ROOT).as_posix(),
            "runtime_path": (RUNTIME / config["runtime"]).relative_to(ROOT).as_posix(),
            "canvas": config["size"],
            "intended_display_size": config["display_size"],
            "integration": "Backend-owned by related SCRUM-931/932/933; this Design package changes no gameplay scene or script.",
        })
    manifest = {
        "issue": "SCRUM-934",
        "name": "Sniper projectile and telegraph VFX component pack",
        "source_pipeline": "PixelLab MCP via fantasydisk-asset-generator",
        "pixel_lab_config_smoke": "PASS",
        "fallbacks_used": [],
        "godot_import": {
            "type": "CompressedTexture2D",
            "compression": "lossless",
            "mipmaps": False,
            "alpha_border_fix": True,
            "filtering": "use project pixel-art default; runtime Texture2D consumers must not enable smoothing",
        },
        "runtime_mapping": {
            "sniper_shatter_rounds": "rotate the right-facing projectile along travel; intended display 48x24; safe for repeated fan shots",
            "sniper_deadeye_rifle": "center endpoint impact at the locked hit position; intended display 96x96",
            "sniper_spotter_scope_telegraph": "scale the semi-transparent ring to the actual pending damage radius; do not force opaque modulation",
            "sniper_spotter_scope_impact": "center the shell impact after the telegraph delay; intended display 144x144",
        },
        "assets": manifest_assets,
        "preview": PREVIEW.relative_to(ROOT).as_posix(),
        "qa_report": (REF / "qa_report.json").relative_to(ROOT).as_posix(),
    }
    (REF / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"SCRUM-934 pack {report['status']}: {len(ASSETS)} assets; failures={len(failures)}")
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
