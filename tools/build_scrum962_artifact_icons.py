#!/usr/bin/env python3
"""SCRUM-962: batch-generate artifact icons for the redesigned artifact system.

Pipeline per icon (follows the SCRUM-690 OpenAI precedent):
  1. Generate a 1024x1024 source via OpenAI Images (gpt-image-2) using
     `fantasydisk-asset-generator/scripts/generate_asset.py` (explicit Jira
     override of the PixelLab-first rule: SCRUM-962 label `openai-image-generator`).
     Source saved to docs/design/references/icons/artifacts/<id>/<id>_source.png.
  2. Postprocess: baked-matte removal (border-connected flood fill) when the
     source has no real alpha, keep the largest alpha component, crop to alpha
     bbox, fit into 256x256 RGBA with ~28px padding, save runtime PNG to
     assets/sprites/ui/icons/artifacts/artifact_<id>.png.
  3. Report per-icon rows (padding, alpha bbox, sha) for the QA report.

Manifest: JSON list of {"id": str, "motif": str} where motif is a short
English visual description (no style words needed - template adds them).

Usage:
  python3 tools/build_scrum962_artifact_icons.py --manifest <path.json> \
      [--workers 4] [--quality high] [--only id1,id2] [--skip-existing] \
      [--postprocess-only] [--contact-sheet docs/design/previews/out.png]
"""

from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import json
import subprocess
import sys
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
GEN_SCRIPT = Path.home() / ".codex/skills/fantasydisk-asset-generator/scripts/generate_asset.py"
REF_DIR = ROOT / "docs/design/references/icons/artifacts"
RUNTIME_DIR = ROOT / "assets/sprites/ui/icons/artifacts"
SIZE = 256
TARGET_SUBJECT = 200  # max subject dimension in the 256 canvas => ~28px padding

PROMPT_TEMPLATE = (
    "D&D + Dark Fantasy Dragon game icon, transparent background, isolated artifact item "
    "for a dark fantasy roguelite. {motif}. Single centered object, full subject visible, "
    "readable silhouette at 32px and 64px, strong material contrast, subtle painterly "
    "highlights, muted dark palette with one accent color, no frame, no text, no letters, "
    "no numbers, no UI panel, no background scenery, no watermark, no cropping."
)


def log(msg: str) -> None:
    print(msg, flush=True)


def generate_source(icon_id: str, motif: str, quality: str) -> Path:
    out = REF_DIR / icon_id / f"{icon_id}_source.png"
    prompt = PROMPT_TEMPLATE.format(motif=motif.strip().rstrip("."))
    cmd = [
        sys.executable, str(GEN_SCRIPT),
        "--prompt", prompt,
        "--output", str(out),
        "--size", "1024x1024",
        "--quality", quality,
        "--no-task",
    ]
    last_err = ""
    for attempt in (1, 2, 3):
        proc = subprocess.run(cmd, capture_output=True, text=True)
        if proc.returncode == 0 and out.exists():
            (REF_DIR / icon_id / "prompt_notes.md").write_text(
                f"# {icon_id}\n\nPrompt:\n\n```\n{prompt}\n```\n\nQuality: {quality}. "
                f"Size: 1024x1024. Generator: gpt-image-2 via generate_asset.py "
                f"(SCRUM-962 OpenAI override).\n",
                encoding="utf-8",
            )
            return out
        last_err = (proc.stderr or proc.stdout or "").strip()[-400:]
        if "content policy" in last_err or "moderation" in last_err.lower():
            break  # retrying identical prompt will not help
    raise RuntimeError(f"generation failed for {icon_id}: {last_err}")


def _border_flood_mask(img: Image.Image, tol: int = 26) -> Image.Image:
    """Mask (L, 255=background) of border-connected pixels close to border colors."""
    rgb = img.convert("RGB")
    w, h = rgb.size
    px = rgb.load()
    border = [px[x, 0] for x in range(w)] + [px[x, h - 1] for x in range(w)] + \
             [px[0, y] for y in range(h)] + [px[w - 1, y] for y in range(h)]
    # up to two dominant background colors (handles checkerboard mattes)
    counts: dict[tuple[int, int, int], int] = {}
    for c in border:
        key = (c[0] // 8 * 8, c[1] // 8 * 8, c[2] // 8 * 8)
        counts[key] = counts.get(key, 0) + 1
    bg_colors = [k for k, _ in sorted(counts.items(), key=lambda kv: -kv[1])[:2]]

    def is_bg(c: tuple[int, int, int]) -> bool:
        return any(abs(c[0] - b[0]) <= tol and abs(c[1] - b[1]) <= tol and abs(c[2] - b[2]) <= tol
                   for b in bg_colors)

    mask = Image.new("L", (w, h), 0)
    mpx = mask.load()
    seen = bytearray(w * h)
    queue: deque[tuple[int, int]] = deque()
    for x in range(w):
        for y in (0, h - 1):
            queue.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            queue.append((x, y))
    while queue:
        x, y = queue.popleft()
        idx = y * w + x
        if seen[idx]:
            continue
        seen[idx] = 1
        if not is_bg(px[x, y]):
            continue
        mpx[x, y] = 255
        if x > 0:
            queue.append((x - 1, y))
        if x < w - 1:
            queue.append((x + 1, y))
        if y > 0:
            queue.append((x, y - 1))
        if y < h - 1:
            queue.append((x, y + 1))
    return mask


def _largest_component_bbox(alpha: Image.Image, threshold: int = 8):
    """(bbox, mask) of the largest connected alpha component (downscaled BFS for speed)."""
    scale = 4
    small = alpha.resize((alpha.width // scale, alpha.height // scale), Image.Resampling.BOX)
    w, h = small.size
    px = small.load()
    seen = bytearray(w * h)
    best_pts: list[tuple[int, int]] = []
    for sy in range(h):
        for sx in range(w):
            idx = sy * w + sx
            if seen[idx] or px[sx, sy] <= threshold:
                continue
            queue = deque([(sx, sy)])
            seen[idx] = 1
            pts = []
            while queue:
                x, y = queue.popleft()
                pts.append((x, y))
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if 0 <= nx < w and 0 <= ny < h:
                        nidx = ny * w + nx
                        if not seen[nidx] and px[nx, ny] > threshold:
                            seen[nidx] = 1
                            queue.append((nx, ny))
            if len(pts) > len(best_pts):
                best_pts = pts
    if not best_pts:
        return None, None
    xs = [p[0] for p in best_pts]
    ys = [p[1] for p in best_pts]
    bbox = (max(0, min(xs) * scale - scale), max(0, min(ys) * scale - scale),
            min(alpha.width, (max(xs) + 1) * scale + scale),
            min(alpha.height, (max(ys) + 1) * scale + scale))
    comp_mask = Image.new("L", (w, h), 0)
    cpx = comp_mask.load()
    for x, y in best_pts:
        cpx[x, y] = 255
    comp_mask = comp_mask.resize(alpha.size, Image.Resampling.NEAREST)
    return bbox, comp_mask


def postprocess(icon_id: str) -> dict:
    src_path = REF_DIR / icon_id / f"{icon_id}_source.png"
    img = Image.open(src_path).convert("RGBA")
    alpha = img.getchannel("A")
    lo, hi = alpha.getextrema()
    if lo >= 250:  # no real alpha -> baked matte, remove it
        bg_mask = _border_flood_mask(img)
        new_alpha = alpha.point(lambda a: a)
        new_alpha.paste(0, mask=bg_mask)
        img.putalpha(new_alpha)
        alpha = img.getchannel("A")
    bbox, comp_mask = _largest_component_bbox(alpha)
    if bbox is None:
        raise RuntimeError(f"{icon_id}: empty alpha after matte removal")
    cleaned_alpha = alpha.point(lambda a: a)
    inverse = comp_mask.point(lambda v: 255 - v)
    cleaned_alpha.paste(0, mask=inverse)
    img.putalpha(cleaned_alpha)
    subject = img.crop(bbox)
    scale = min(TARGET_SUBJECT / subject.width, TARGET_SUBJECT / subject.height)
    new_w = max(1, int(round(subject.width * scale)))
    new_h = max(1, int(round(subject.height * scale)))
    subject = subject.resize((new_w, new_h), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ox = (SIZE - new_w) // 2
    oy = (SIZE - new_h) // 2
    canvas.paste(subject, (ox, oy), subject)
    out = RUNTIME_DIR / f"artifact_{icon_id}.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out)
    final_alpha = canvas.getchannel("A")
    fb = final_alpha.getbbox()
    corners = [final_alpha.getpixel(p) for p in
               ((0, 0), (SIZE - 1, 0), (0, SIZE - 1), (SIZE - 1, SIZE - 1))]
    return {
        "id": icon_id,
        "runtime": str(out.relative_to(ROOT)),
        "source": str(src_path.relative_to(ROOT)),
        "alpha_bbox": fb,
        "padding": (fb[0], fb[1], SIZE - fb[2], SIZE - fb[3]) if fb else None,
        "corner_alpha_max": max(corners),
        "sha": hashlib.sha1(out.read_bytes()).hexdigest()[:12],
    }


def build_contact_sheet(ids: list[str], out_path: Path, cols: int = 10) -> None:
    cell = 96
    label_h = 14
    small = 40
    rows = (len(ids) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell, rows * (cell + label_h + small + 6) + 8),
                      (24, 22, 28, 255))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 9)
    except OSError:
        font = ImageFont.load_default()
    for i, icon_id in enumerate(ids):
        cx = (i % cols) * cell
        cy = (i // cols) * (cell + label_h + small + 6) + 4
        p = RUNTIME_DIR / f"artifact_{icon_id}.png"
        if not p.exists():
            draw.text((cx + 4, cy + 40), "MISSING", fill=(255, 80, 80, 255), font=font)
        else:
            icon = Image.open(p).convert("RGBA")
            big = icon.resize((cell - 8, cell - 8), Image.Resampling.LANCZOS)
            sheet.paste(big, (cx + 4, cy), big)
            tiny = icon.resize((small, small), Image.Resampling.LANCZOS)
            sheet.paste(tiny, (cx + (cell - small) // 2, cy + cell + label_h), tiny)
        draw.text((cx + 4, cy + cell + 1), icon_id[:18], fill=(220, 210, 190, 255), font=font)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out_path)
    log(f"contact sheet: {out_path}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", required=True)
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--quality", default="high")
    ap.add_argument("--only", default="")
    ap.add_argument("--skip-existing", action="store_true")
    ap.add_argument("--postprocess-only", action="store_true")
    ap.add_argument("--contact-sheet", default="")
    args = ap.parse_args()

    entries = json.loads(Path(args.manifest).read_text(encoding="utf-8"))
    if args.only:
        keep = set(args.only.split(","))
        entries = [e for e in entries if e["id"] in keep]
    if args.skip_existing:
        entries = [e for e in entries
                   if not (RUNTIME_DIR / f"artifact_{e['id']}.png").exists()]

    results: list[dict] = []
    failures: list[tuple[str, str]] = []

    def run_one(entry: dict) -> dict:
        icon_id = entry["id"]
        if not args.postprocess_only:
            generate_source(icon_id, entry["motif"], args.quality)
        return postprocess(icon_id)

    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        futs = {pool.submit(run_one, e): e["id"] for e in entries}
        done = 0
        for fut in concurrent.futures.as_completed(futs):
            icon_id = futs[fut]
            done += 1
            try:
                row = fut.result()
                results.append(row)
                log(f"[{done}/{len(entries)}] OK {icon_id} pad={row['padding']} "
                    f"corner={row['corner_alpha_max']}")
            except Exception as exc:  # noqa: BLE001
                failures.append((icon_id, str(exc)[-300:]))
                log(f"[{done}/{len(entries)}] FAIL {icon_id}: {exc}")

    # duplicate check across the whole runtime dir
    sha_map: dict[str, list[str]] = {}
    for p in sorted(RUNTIME_DIR.glob("artifact_*.png")):
        sha_map.setdefault(hashlib.sha1(p.read_bytes()).hexdigest(), []).append(p.name)
    dups = {k: v for k, v in sha_map.items() if len(v) > 1}
    if dups:
        log(f"DUPLICATE runtime icons: {dups}")

    report = {
        "generated": sorted(results, key=lambda r: r["id"]),
        "failures": failures,
        "duplicates": dups,
    }
    report_path = Path(args.manifest).with_suffix(".result.json")
    report_path.write_text(json.dumps(report, indent=1, ensure_ascii=False), encoding="utf-8")
    log(f"report: {report_path} | ok={len(results)} fail={len(failures)}")

    if args.contact_sheet:
        build_contact_sheet([e["id"] for e in entries], ROOT / args.contact_sheet)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
