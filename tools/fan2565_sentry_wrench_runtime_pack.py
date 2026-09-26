#!/usr/bin/env python3
"""FAN-2565: build the runtime sentry-pylon frames from the PixelLab source pack.

Every frame is cropped to the SAME rect — the union of all nine alpha bounding
boxes — so the pylon keeps one pivot for the whole animation, then downscaled by
an integer factor with nearest sampling so the pixel edges stay crisp and the
element lands in the size band the forged 49x112 pylon used.

The measured quality of the pack (binary alpha, canvas margin, pivot drift,
stray islands, distinct frames) is written back into the provenance manifest, so
the numbers a reviewer checks are produced by the same run that built the files.

    python3 tools/fan2565_sentry_wrench_runtime_pack.py \\
      --source-dir docs/design/references/weapon_ultimates/engineer/source/pixellab_sentry_wrench \\
      --runtime-dir assets/sprites/effects/ultimates/engineer/sentry_wrench_deploy \\
      --manifest docs/design/references/weapon_ultimates/engineer/provenance_manifest_sentry_wrench.json
"""
import argparse
import hashlib
import json
import os

from PIL import Image

FRAME_COUNT = 9
ALPHA_FLOOR = 8


def load_frames(source_dir):
    return [Image.open(os.path.join(source_dir, "sentry_pylon_f%02d.png" % index)).convert("RGBA")
            for index in range(FRAME_COUNT)]


def union_box(frames, padding):
    boxes = [frame.getchannel("A").getbbox() for frame in frames]
    left = min(box[0] for box in boxes) - padding
    top = min(box[1] for box in boxes) - padding
    right = max(box[2] for box in boxes) + padding
    bottom = max(box[3] for box in boxes) + padding
    width, height = right - left, bottom - top
    # An even crop keeps the integer downscale exact.
    return (left, top, right + width % 2, bottom + height % 2)


def islands(alpha):
    """Sizes of the connected alpha islands, largest first."""
    pixels = alpha.load()
    width, height = alpha.size
    seen = [[False] * width for _ in range(height)]
    sizes = []
    for y in range(height):
        for x in range(width):
            if pixels[x, y] <= ALPHA_FLOOR or seen[y][x]:
                continue
            stack, count = [(x, y)], 0
            seen[y][x] = True
            while stack:
                cx, cy = stack.pop()
                count += 1
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = cx + dx, cy + dy
                    if 0 <= nx < width and 0 <= ny < height and not seen[ny][nx] \
                            and pixels[nx, ny] > ALPHA_FLOOR:
                        seen[ny][nx] = True
                        stack.append((nx, ny))
            sizes.append(count)
    return sorted(sizes, reverse=True)


def centroid(alpha):
    pixels = alpha.load()
    width, height = alpha.size
    total = weighted_x = weighted_y = 0
    for y in range(height):
        for x in range(width):
            value = pixels[x, y]
            if value > ALPHA_FLOOR:
                total += value
                weighted_x += x * value
                weighted_y += y * value
    return (round(weighted_x / total, 2), round(weighted_y / total, 2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", required=True)
    parser.add_argument("--runtime-dir", required=True)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--padding", type=int, default=2)
    parser.add_argument("--downscale", type=int, default=2)
    args = parser.parse_args()

    frames = load_frames(args.source_dir)
    for frame in frames:
        if frame.size != frames[0].size:
            raise SystemExit("source frames must share one canvas size")
    crop = union_box(frames, args.padding)
    canvas = frames[0].size
    if crop[0] < 0 or crop[1] < 0 or crop[2] > canvas[0] or crop[3] > canvas[1]:
        raise SystemExit("content touches the canvas edge: %s in %s" % (crop, canvas))

    os.makedirs(args.runtime_dir, exist_ok=True)
    runtime_size = ((crop[2] - crop[0]) // args.downscale, (crop[3] - crop[1]) // args.downscale)
    records, digests, semi_total, centroids = [], set(), 0, []
    for index, frame in enumerate(frames):
        cropped = frame.crop(crop).resize(runtime_size, Image.NEAREST)
        path = os.path.join(args.runtime_dir, "sentry_pylon_%02d.png" % index)
        cropped.save(path)
        alpha = cropped.getchannel("A")
        blob = open(path, "rb").read()
        digests.add(hashlib.sha256(blob).hexdigest())
        semi = sum(1 for value in alpha.getdata() if 0 < value < 255)
        semi_total += semi
        point = centroid(alpha)
        centroids.append(point)
        records.append({
            "frame": index,
            "path": path,
            "sha256": hashlib.sha256(blob).hexdigest(),
            "used_rect": list(alpha.getbbox()),
            "semi_transparent_pixels": semi,
            "alpha_centroid": list(point),
            "islands": islands(alpha),
        })

    with open(args.manifest) as handle:
        manifest = json.load(handle)
    manifest["runtime_pack"] = {
        "directory": args.runtime_dir,
        "source_canvas": list(canvas),
        "shared_crop_rect": list(crop),
        "downscale": args.downscale,
        "runtime_canvas": list(runtime_size),
        "frames": records,
        "quality": {
            "distinct_frames": len(digests),
            "semi_transparent_pixels_total": semi_total,
            "pivot_drift_px": [
                round(max(p[0] for p in centroids) - min(p[0] for p in centroids), 2),
                round(max(p[1] for p in centroids) - min(p[1] for p in centroids), 2),
            ],
            "largest_stray_island_px": max(
                [sizes[1] for sizes in (record["islands"] for record in records) if len(sizes) > 1] or [0]
            ),
        },
    }
    with open(args.manifest, "w") as handle:
        json.dump(manifest, handle, indent=2, ensure_ascii=False)
        handle.write("\n")

    print("crop %s -> runtime %s from canvas %s" % (list(crop), list(runtime_size), list(canvas)))
    print("distinct frames %d/%d, semi-transparent pixels %d, pivot drift %s px, largest stray island %d px" % (
        len(digests), FRAME_COUNT, semi_total,
        manifest["runtime_pack"]["quality"]["pivot_drift_px"],
        manifest["runtime_pack"]["quality"]["largest_stray_island_px"]))


if __name__ == "__main__":
    main()
