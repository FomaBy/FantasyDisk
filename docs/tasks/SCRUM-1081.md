# SCRUM-1080 Design: нижние углы Main Menu, glow и version zone

Статус: done
Версия: 0.2.1
Jira: SCRUM-1081
Контур: Codex
Owner: Design main
Thread: /root/main_menu_corner_design
Locked paths: `docs/design/mockups/scrum1081_main_menu_bottom_corners/**`, `docs/design/previews/scrum1081_main_menu_bottom_corners*`, design result in this mirror

## Scope

Reuse the accepted PixelLab Main Menu/gold-shell/gratitude sources. Create and
validate exact content zones for a slightly larger gratitude control with a
restrained glow immediately left of the bottom-right runtime version label.
The original bottom-left proposal is superseded by the user's follow-up. New
bitmap art is not required.

## Design Result

Result: ready for Back-end integration / QA review.

- Spec: `docs/design/mockups/scrum1081_main_menu_bottom_corners/spec.md`.
- Base geometry: `ui_plan.json` and `layout.json`; exact per-target plans/layouts
  are recorded for 1152×648, 1280×720, 1600×900, 1920×1080 and 2560×1440.
- Preview:
  `docs/design/previews/scrum1081_main_menu_bottom_corners/main_menu_bottom_corners_1920x1080.png`;
  annotated overlay:
  `docs/design/previews/scrum1081_main_menu_bottom_corners/main_menu_bottom_corners_1920x1080_debug.png`.
- Gratitude now sits in the bottom-right utility cluster immediately left of
  the version. Accepted hitbox tiers grow from 64/72/88 to 72/80/96 px; a
  bounded 6/8/10 px restrained glow reserve stays inside the frame-safe area.
- The action column returns to the unchanged SCRUM-1059 X=`inner.x`, preserving
  its accepted size, vertical rhythm and scenic-safe left position.
- Version is bottom-right, right/bottom aligned and dynamic from
  `ProjectSettings.application/config/version`; responsive font tiers are
  14/15/16/18 px, with no hardcoded release number or new badge art.
- Focus handoff: actions `Right -> Gratitude`; Gratitude `Left/Up -> Exit`,
  `Down -> Start`, with a closed trap-free graph documented in the spec.

## QA Evidence

- `validate_ui_layout_plan.py`: all five reports `decision: ready_for_image`,
  `ok: true`.
- `render_content_zones.py --guide-output`: all five layout reports `ok: true`.
- Visual inspection: 1280×720 and 1920×1080 source-reuse previews plus the
  annotated 1920×1080 overlay; no frame/grid/logo/version overlap.
- Production assets changed: none. Runtime/scripts/tests changed: none.
- Disk cleanup: none created outside committed design evidence; no `.godot`,
  cache, generated production asset or temporary checkout was created.

## QA PASSED

SCRUM-1083 confirmed the integrated runtime against this revised bottom-right
cluster spec on all five target resolutions and live resize, with no frame or
content overlap.
