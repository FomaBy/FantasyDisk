#!/usr/bin/env python3
"""SCRUM-694 — Settings v3 layout/geometry generator + fit gate.

Reproduces the live geometry of scripts/ui_screens.gd::_show_settings_menu and its
helpers (_settings_v2_modal_rect, _settings_v2_tab_switcher_size,
_settings_v2_switcher_top, _settings_v2_content_panel_rect,
_scaled_frame_margins_xy) so the PixelLab/OpenAI redraw targets the exact runtime
rects. Emits layout.json and prints a fit-gate verdict.

No image generation here — geometry only, fully deterministic.
"""
import json, math, os, sys

ROUND = lambda v: math.floor(v + 0.5)  # Godot roundf (round-half-up for .5)

# --- live constants mirrored from scripts/ui_screens.gd ---
MODAL_COORD = (1536.0, 924.0)              # reference coord system for scaled rects
MAIN_SOURCE_SIZE = (986.0, 900.0)          # SETTINGS_V2_MAIN_SOURCE_SIZE
MAIN_TEXTURE_MARGINS = (46.0, 62.0, 46.0, 58.0)   # l,t,r,b  SETTINGS_V2_MAIN_TEXTURE_MARGINS
MAIN_CONTENT_MARGINS = (72.0, 92.0, 72.0, 84.0)   # l,t,r,b  SETTINGS_V2_MAIN_CONTENT_MARGINS
APPLY_BTN = (240.0, 72.0)

VIEWPORTS = [(1280, 720), (1920, 1080), (2560, 1440), (3840, 2160)]


def scaled_frame_margins_xy(source, display, margins):
    sx = display[0] / source[0]
    sy = display[1] / source[1]
    l, t, r, b = margins
    return (ROUND(l * sx), ROUND(t * sy), ROUND(r * sx), ROUND(b * sy))


def modal_rect(vw, vh):
    width = min(max(ROUND(vw * 0.80), 1024.0), 2048.0)
    height = ROUND(width * 924.0 / 1536.0)
    max_height = ROUND(vh * 0.88)
    if height > max_height:
        height = max_height
        width = ROUND(height * 1536.0 / 924.0)
    x = ROUND((vw - width) * 0.5)
    y = ROUND((vh - height) * 0.5)
    return (x, y, width, height)


def tab_switcher_size(modal_w):
    width = min(max(ROUND(modal_w * 0.573), 640.0), 1100.0)
    height = ROUND(width / 5.0)
    return (width, height)


def switcher_top(modal_h):
    return ROUND(max(112.0, modal_h * 0.172))


def content_panel_rect(modal_w, modal_h):
    mm = scaled_frame_margins_xy(MAIN_SOURCE_SIZE, (modal_w, modal_h), MAIN_CONTENT_MARGINS)
    sw, sh = tab_switcher_size(modal_w)
    st = switcher_top(modal_h)
    top = st + sh + ROUND(max(18.0, modal_h * 0.028))
    back_top = modal_h - 64.0 - max(28.0, modal_h * 0.055)
    left = mm[0] + 24.0
    right = mm[2] + 24.0
    min_h = 180.0 if modal_h <= 590.0 else 248.0
    height = max(min_h, back_top - top - 24.0)
    width = max(640.0, modal_w - left - right)
    return (left, top, width, height)


def scaled_modal_rect(ref_rect, modal_size):
    sx = modal_size[0] / MODAL_COORD[0]
    sy = modal_size[1] / MODAL_COORD[1]
    return (ROUND(ref_rect[0] * sx), ROUND(ref_rect[1] * sy),
            ROUND(ref_rect[2] * sx), ROUND(ref_rect[3] * sy))


# Fixed-size controls (runtime custom_minimum_size, NOT scaled by modal) — px.
CONTROLS = {
    "option_dropdown": (520, 62),      # Screen/Resolution/WindowMode/Aim OptionButtons
    "rebind_button":   (420, 62),      # BindingButton_* + compact rebind
    "action_apply":    (240, 72),      # Применить / Отменить
    "action_back":     (280, 64),      # Назад
    "action_reset_audio": (420, 64),   # Сбросить звук по умолчанию
    "action_reset_binds": (560, 64),   # Сбросить управление по умолчанию
    "checkbox":        (42, 42),       # ScreenShake / Debug / CombatFeedback / volume toggles
    "volume_slider":   (300, 28),      # HSlider track (master/music/sfx)
}

PIXELLAB_MAX = 688  # create_ui_asset long-axis cap


def main():
    out = {
        "ticket": "SCRUM-694",
        "name": "settings_v3_full_redraw",
        "base_design_resolution": "2560x1440",
        "modal_native_source": "2048x1232",  # clamped max; covers 2K and 4K identically
        "modal_coord_system": list(MODAL_COORD),
        "pixellab_long_axis_cap": PIXELLAB_MAX,
        "scaling_policy": (
            "Frames (modal, tab switcher, content panel, buttons, dropdown field) ship as "
            "9-slice: native corners/ornaments + tileable flat center only. No one-axis "
            "stretch of ornaments. Fixed controls (checkbox, slider handle) ship exact-size."
        ),
        "viewports": {},
    }
    fit_fail = []
    for vw, vh in VIEWPORTS:
        mx, my, mw, mh = modal_rect(vw, vh)
        sw, sh = tab_switcher_size(mw)
        st = switcher_top(mh)
        sx = ROUND((mw - sw) * 0.5)
        cp = content_panel_rect(mw, mh)
        title = scaled_modal_rect((144.0, 94.0, 1248.0, 48.0), (mw, mh))
        tex_m = scaled_frame_margins_xy(MAIN_SOURCE_SIZE, (mw, mh), MAIN_TEXTURE_MARGINS)
        # bottom action row
        action_w = 784.0
        action_x = ROUND((mw - action_w) * 0.5)
        action_y = ROUND(mh - APPLY_BTN[1] - max(28.0, mh * 0.055))
        # content margin inside content panel (SettingsContentSafe): 18/14/18/14
        safe = (cp[0] + 18, cp[1] + 14, cp[2] - 36, cp[3] - 28)
        out["viewports"]["%dx%d" % (vw, vh)] = {
            "modal_rect_abs": [mx, my, mw, mh],
            "frame_texture_margins_lrtb": list(tex_m),
            "title_rect_local": list(title),
            "tab_switcher_local": [sx, st, sw, sh],
            "tab_switcher_aspect": round(sw / sh, 3),
            "content_panel_local": [round(v) for v in cp],
            "content_safe_zone_local": [round(v) for v in safe],
            "bottom_actions_local": [action_x, action_y, round(action_w), round(APPLY_BTN[1])],
        }
        # --- fit gate checks ---
        # 1) content panel must sit fully below the switcher (no overlap)
        if cp[1] < st + sh:
            fit_fail.append("%dx%d: content panel overlaps tab switcher" % (vw, vh))
        # 2) content panel bottom must clear the bottom action row
        if cp[1] + cp[3] > action_y:
            fit_fail.append("%dx%d: content panel bottom overlaps action row" % (vw, vh))
        # 3) title must sit above the switcher
        if title[1] + title[3] > st:
            fit_fail.append("%dx%d: title overlaps tab switcher" % (vw, vh))
        # 4) safe zone wide enough for the widest control (reset binds 560 + margins)
        if safe[2] < 560:
            fit_fail.append("%dx%d: content safe width %d < widest control 560" % (vw, vh, safe[2]))
        # 5) all generated frame assets respect PixelLab cap via 9-slice (informational)
    out["fixed_controls_px"] = CONTROLS
    out["pixellab_targets"] = {
        "modal_frame":   {"source_px": [688, 414], "aspect": "1.662 (2048x1232)", "nine_slice": True},
        "tab_switcher":  {"source_px": [688, 138], "aspect": "5.0 (1100x220)", "nine_slice": True},
        "content_panel": {"source_px": [688, 246], "aspect": "2.787 (1700x609)", "nine_slice": True},
        "dropdown_field":{"source_px": [520, 96],  "aspect": "8.39 (520x62 runtime)", "nine_slice": True},
        "action_button": {"source_px": [480, 120], "aspect": "4:1 family (covers 240-560 wide)", "nine_slice": True},
        "rebind_button": {"source_px": [520, 96],  "aspect": "shares dropdown_field family", "nine_slice": True},
        "slider_track":  {"source_px": [512, 64],  "aspect": "horizontal 9-slice", "nine_slice": True},
        "slider_handle": {"source_px": [64, 64],   "aspect": "square exact-size", "nine_slice": False},
        "toggle_off":    {"source_px": [64, 64],   "aspect": "square exact-size", "nine_slice": False},
        "toggle_on":     {"source_px": [64, 64],   "aspect": "square exact-size", "nine_slice": False},
        "scrollbar":     {"source_px": [48, 512],  "aspect": "vertical 9-slice grabber", "nine_slice": True},
    }
    out["fit_gate"] = {
        "checks": [
            "title above switcher", "switcher above content panel",
            "content panel above action row", "safe width >= widest control (560)",
        ],
        "result": "ready_for_image" if not fit_fail else "blocked",
        "failures": fit_fail,
    }
    dest = os.path.join(os.path.dirname(__file__), "..", "..", "..",
                        "docs", "design", "references", "settings_v3_full_redraw", "layout.json")
    dest = os.path.normpath(dest)
    with open(dest, "w") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
    print("wrote", dest)
    print("FIT GATE:", out["fit_gate"]["result"])
    for fail in fit_fail:
        print("  FAIL:", fail)
    return 0 if not fit_fail else 1


if __name__ == "__main__":
    sys.exit(main())
