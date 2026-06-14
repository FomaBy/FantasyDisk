# Back-end/UI: Integrate SCRUM-356 unified Hero Select portrait+description frame

Статус: new
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-14
Автор: Design Codex handoff from SCRUM-356
Jira: pending sync
Связано: SCRUM-356, SCRUM-346, SCRUM-354, SCRUM-355

## Context

Design SCRUM-356 produced the requested single frame that combines the Hero
Select portrait and hero description areas. Runtime integration is Back-end UI
scope because it requires replacing the current separate `HeroSelectPortraitPanel`
and `HeroSelectDossierPanel` layout in `scripts/ui_screens.gd`.

## Assets

- Unified frame:
  `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_unified_panel.png`
  (`1536x1024`, RGBA)
- Small ascension stepper button:
  `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_asc_button_small.png`
  (`256x256`, RGBA)
- Metadata:
  `docs/design/references/hero_select_unified_panel/scrum356_unified_panel_metadata.json`
- Preview:
  `docs/design/previews/scrum356_hero_select_unified_panel_content_zones.png`

## Required Layout

1. Replace the separate portrait+dossier visual structure with one unified
   proportional `TextureRect` layer using `ui_frame_hero_select_unified_panel.png`.
   Do not 9-slice it and do not stretch it on one axis.
2. Keep the radar as the separate top-right widget from SCRUM-322.
3. Keep the bottom carousel as the separate frame from SCRUM-320/SCRUM-355.
4. Move the ascension row (`- / label / +`) and `HeroSelectChooseButton` to the
   lower safe zone inside the unified frame.
5. Use `ui_frame_hero_select_asc_button_small.png` for both plus and minus
   buttons; center runtime `-`/`+` glyphs inside its content zone.

## Source-Space Safe Zones

The unified frame source size is `1536x1024`. Scale all rects proportionally with
the whole image:

| Zone | Rect |
| --- | --- |
| portrait | `Rect2(130, 145, 420, 560)` |
| description | `Rect2(610, 145, 786, 500)` |
| bottom_controls | `Rect2(570, 705, 660, 178)` |

Small ascension button content margins:

```text
left=76, top=74, right=76, bottom=76
```

## Global Rule

No UI content may overlap decorative frame borders: hero portraits, labels,
description text, ascension controls, choose button, focus/hover states and
clickable zones must sit only inside the listed safe zones.

## Acceptance Criteria

- [ ] Hero Select shows portrait and description inside one unified frame.
- [ ] Unified frame is whole-image proportional at 1280x720, 1920x1080 and
      2560x1440; no one-axis stretching.
- [ ] Radar remains separate top-right; carousel remains separate bottom strip.
- [ ] Ascension controls and choose button are bottom-aligned inside
      `bottom_controls`, centered and non-overlapping.
- [ ] Plus/minus buttons use `ui_frame_hero_select_asc_button_small.png`.
- [ ] Runtime smoke and UI no-overlap matrix pass; QA rect dump proves all
      Hero Select content is inside the safe zones.
