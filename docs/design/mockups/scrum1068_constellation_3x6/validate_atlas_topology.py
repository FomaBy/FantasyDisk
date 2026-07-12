#!/usr/bin/env python3
"""Pixel-level SCRUM-1084 guard for the generated Atlas socket topology."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image


GRAPH_BOUNDS = (145, 95, 435, 270)
RADIUS_RANGE = range(7, 15)
EDGE_THRESHOLD = 50.0
RING_SCORE_THRESHOLD = 90.0
ANGULAR_COVERAGE_MIN = 0.70
MIN_CENTER_DISTANCE = 15.0
EXPECTED_SOCKET_COUNT = 21


def _edge_map(image: Image.Image) -> np.ndarray:
    rgb = np.asarray(image.convert("RGB"), dtype=np.float32)
    gray = rgb.mean(axis=2)
    grad_x = np.zeros_like(gray)
    grad_y = np.zeros_like(gray)
    grad_x[:, 1:-1] = np.abs(gray[:, 2:] - gray[:, :-2])
    grad_y[1:-1] = np.abs(gray[2:] - gray[:-2])
    return np.hypot(grad_x, grad_y)


def detect_socket_centers(image: Image.Image) -> list[dict]:
    edge = _edge_map(image)
    best_score = np.zeros_like(edge)
    best_coverage = np.zeros_like(edge)

    for radius in RADIUS_RANGE:
        offsets = list({
            (
                int(round(math.sin(math.tau * index / 48.0) * radius)),
                int(round(math.cos(math.tau * index / 48.0) * radius)),
            )
            for index in range(48)
        })
        samples = np.stack([np.roll(edge, (dy, dx), axis=(0, 1)) for dy, dx in offsets])
        score = samples.mean(axis=0)
        coverage = (samples > EDGE_THRESHOLD).mean(axis=0)
        replace = score > best_score
        best_score[replace] = score[replace]
        best_coverage[replace] = coverage[replace]

    left, top, right, bottom = GRAPH_BOUNDS
    eligible = np.zeros_like(best_score, dtype=bool)
    eligible[top:bottom, left:right] = True
    best_score[~eligible] = 0.0

    centers: list[dict] = []
    for flat_index in np.argsort(best_score.ravel())[::-1]:
        y, x = np.unravel_index(flat_index, best_score.shape)
        score = float(best_score[y, x])
        coverage = float(best_coverage[y, x])
        if score < RING_SCORE_THRESHOLD:
            break
        if coverage < ANGULAR_COVERAGE_MIN:
            continue
        if any((x - item["x"]) ** 2 + (y - item["y"]) ** 2 <= MIN_CENTER_DISTANCE ** 2 for item in centers):
            continue
        centers.append({"x": int(x), "y": int(y), "score": round(score, 3), "coverage": round(coverage, 3)})
    centers.sort(key=lambda item: (item["y"], item["x"]))
    return centers


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--image", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()

    image = Image.open(args.image)
    centers = detect_socket_centers(image)
    report = {
        "schema": "fantasydisk.atlas_topology_pixel_gate.v1",
        "issue": "SCRUM-1084",
        "image": str(args.image),
        "image_size": list(image.size),
        "graph_bounds": list(GRAPH_BOUNDS),
        "expected_socket_count": EXPECTED_SOCKET_COUNT,
        "detected_socket_count": len(centers),
        "detected_centers": centers,
        "rules": {
            "core": 1,
            "weapon_rays": 3,
            "sockets_per_ray_including_final": 6,
            "side_spurs_total": 2,
            "keystone_or_extra_junctions": 0,
        },
        "ok": len(centers) == EXPECTED_SOCKET_COUNT,
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if not report["ok"]:
        print(f"Atlas topology FAIL: expected {EXPECTED_SOCKET_COUNT}, detected {len(centers)}")
        return 1
    print(f"Atlas topology PASS: detected exactly {len(centers)} sockets in the native PixelLab graph.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
