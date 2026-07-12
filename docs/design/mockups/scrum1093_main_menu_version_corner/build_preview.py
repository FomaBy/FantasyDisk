#!/usr/bin/env python3
"""Build SCRUM-1093 source-reuse plans and Main Menu previews.

No production art is generated here. The script reuses the accepted
PixelLab-lineage SCRUM-1081 Main Menu package and changes only the authored
lower-right utility geometry requested by the user.
"""

from __future__ import annotations

import argparse
import importlib.util
from pathlib import Path

from PIL import ImageFont


ROOT = Path(__file__).resolve().parents[4]
LEGACY_PATH = ROOT / "docs/design/mockups/scrum1081_main_menu_bottom_corners/build_preview.py"
SPEC = importlib.util.spec_from_file_location("scrum1081_preview", LEGACY_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"Unable to load {LEGACY_PATH}")
legacy = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(legacy)
legacy_geometry = legacy.geometry
legacy_plan_for = legacy.plan_for

TARGETS = [(1152, 648), (1280, 720), (1600, 900), (1920, 1080), (2048, 1152), (2560, 1440)]
OUT = Path(__file__).resolve().parent
PREVIEW = ROOT / "docs/design/previews/scrum1093_main_menu_version_corner"
VERSION_PREVIEW = "v0.2.0"
UTILITY_RESERVE = 8
CLUSTER_GAP = 2
# SCRUM-1095: keep the unchanged Button hitbox inside the bounded glow but bias
# it two pixels toward the adjacent version.  The accepted icon's alpha-aware
# square crop then leaves 14..18 px from visible art to the version glyphs.
BUTTON_X_BIAS = 3
GRATITUDE_ALPHA_BBOX = (55, 48, 201, 208)


def alpha_square_crop(source):
    """Return a square crop that preserves all used alpha and faces right.

    The accepted PixelLab asset is 256x256 but its real used-alpha rectangle is
    146x160.  The spare 14 px needed for a square crop belongs on the left so
    the visible right edge, which faces the version, is a deterministic content
    edge rather than 55 transparent source pixels.
    """
    used = source.getbbox()
    if used != GRATITUDE_ALPHA_BBOX:
        raise RuntimeError(f"Gratitude alpha bbox drifted: {used} != {GRATITUDE_ALPHA_BBOX}")
    left, top, right, bottom = used
    side = max(right - left, bottom - top)
    crop_left = max(0, right - side)
    crop_top = max(0, min(source.height - side, top + (bottom - top - side) // 2))
    return source.crop((crop_left, crop_top, crop_left + side, crop_top + side))


def geometry(width: int, height: int) -> dict:
    geom = legacy_geometry(width, height)
    frame_x, frame_y, frame_w, frame_h = geom["frame_safe"]
    utility_right = frame_x + frame_w - UTILITY_RESERVE
    utility_bottom = frame_y + frame_h - UTILITY_RESERVE
    version_font = ImageFont.truetype(str(legacy.FONT), geom["version_font"])
    bounds = version_font.getbbox(VERSION_PREVIEW, stroke_width=2)
    version_width = bounds[2] - bounds[0] + 6
    old_version = geom["version"]
    version = (
        utility_right - version_width,
        utility_bottom - old_version[3],
        version_width,
        old_version[3],
    )
    glow_w = geom["gratitude_glow"][2]
    glow_h = geom["gratitude_glow"][3]
    gratitude_glow = (
        version[0] - CLUSTER_GAP - glow_w,
        utility_bottom - glow_h,
        glow_w,
        glow_h,
    )
    inset = geom["glow_inset"]
    icon_side = geom["gratitude"][2]
    gratitude = (
        gratitude_glow[0] + inset + BUTTON_X_BIAS,
        gratitude_glow[1] + inset,
        icon_side,
        icon_side,
    )
    geom.update({
        "utility_anchor": (utility_right, utility_bottom),
        "utility_reserve": UTILITY_RESERVE,
        "cluster_gap": CLUSTER_GAP,
        "button_x_bias": BUTTON_X_BIAS,
        "version": version,
        "gratitude_glow": gratitude_glow,
        "gratitude": gratitude,
    })
    return geom


def plan_for(width: int, height: int, geom: dict) -> dict:
    """Expose the tighter utility-only safe zone to the planning validator.

    SCRUM-1093 intentionally moves only the compact corner utilities beyond the
    conservative authored_inner rectangle used by large action controls.  They
    still remain inside frame_safe with an explicit eight-pixel reserve.
    """
    plan = legacy_plan_for(width, height, geom)
    frame_x, frame_y, frame_w, frame_h = geom["frame_safe"]
    plan["elements"].insert(1, {
        "id": "frame_safe_opening",
        "kind": "panel",
        "x": frame_x,
        "y": frame_y,
        "w": frame_w,
        "h": frame_h,
        "content_zone": True,
        "collision": False,
    })
    for element in plan["elements"]:
        if element["id"] in {"gratitude_glow", "runtime_version"}:
            element["parent"] = "frame_safe_opening"
    icon_x, icon_y, icon_w, icon_h = geom["gratitude"]
    # The runtime Button style owns a stable four-pixel content margin.  After
    # the 160x160 right-facing crop, the accepted art's alpha ends exactly at
    # the right edge of this content rectangle.
    plan["elements"].append({
        "id": "gratitude_visible_alpha",
        "kind": "icon",
        "parent": "gratitude_icon",
        "x": icon_x + 4,
        "y": icon_y + 4,
        "w": icon_w - 8,
        "h": icon_h - 8,
        "content_zone": True,
        "collision": False,
    })
    return plan


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--plans-only", action="store_true")
    args = parser.parse_args()
    legacy.TARGETS = TARGETS
    legacy.OUT = OUT
    legacy.PREVIEW = PREVIEW
    legacy.geometry = geometry
    legacy.plan_for = plan_for
    original_contain = legacy.contain

    def alpha_aware_contain(source, size):
        if source.size == (256, 256) and source.getbbox() == GRATITUDE_ALPHA_BBOX:
            source = alpha_square_crop(source)
        return original_contain(source, size)

    legacy.contain = alpha_aware_contain
    legacy.write_plans()
    if not args.plans_only:
        for target in TARGETS:
            legacy.build_preview(*target)


if __name__ == "__main__":
    main()
