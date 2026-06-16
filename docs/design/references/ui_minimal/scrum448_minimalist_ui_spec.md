# SCRUM-448 Minimalist UI Restyle Spec

Статус: Design-source handoff ready
Владелец: Designer 2 (Codex)
Дата: 2026-06-15

## Цель

Перерисовать non-button интерфейс FantasyDisk в аккуратный минимализм: спокойные
тёмные панели, тонкий aged-brass контур, редкие ruby pin accents, много воздуха и
строгие content-зоны. Текущий SCRUM-273 Red & Gold Dragon button kit остаётся
без изменений и становится единственным ярким акцентом поверх спокойных рамок.

## Source / Preview

- OpenAI UI mockup/style board:
  `docs/design/references/ui_minimal/scrum448_minimalist_ui_style_board.png`
- UI-director mirror mockup:
  `docs/design/mockups/scrum448_ui_minimalist/scrum448_minimalist_ui_style_board.png`
- OpenAI frame source sheet:
  `docs/design/references/ui_minimal/scrum448_minimalist_frame_kit_source_sheet.png`
- Frame metadata / margins:
  `docs/design/references/ui_minimal/scrum448_minimal_ui_frame_metadata.json`
- Back-end mirror metadata:
  `docs/design/mockups/scrum448_ui_minimalist/frames_spec.json`
- Contact preview:
  `docs/design/previews/scrum448_minimal_ui_frame_contact.png`
- Alpha audit:
  `build/qa/scrum448_ui_minimalist/alpha_audit.md`

## Non-Negotiable Rules

1. Do not modify or regenerate `assets/sprites/ui/frames/red_gold/`.
2. Do not change `_make_button()` red-button routing except to keep existing
   SCRUM-273 mappings working with the new quieter surrounding panels.
3. Runtime content uses only `content_rect_xywh` from the metadata; text, icons,
   portraits, controls, focus rings and click/hit areas must not sit on brass
   lines, bevels, ruby pins or frame corners.
4. Keep the style minimal. Remove heavy dragon curls, large gems and busy
   ornamental overlays from generic panels/cards/tooltips/HUD surfaces.
5. Generated frame PNGs are transparent RGBA and audit at `white_opaque_pixels=0`,
   `pale_visible_pixels_after_cleanup=0`.

## Production Candidates

| ID | Path | Size | Texture margins LTRB | Content rect XYWH | Primary use |
| --- | --- | ---: | ---: | ---: | --- |
| `ui_frame_minimal_modal` | `assets/sprites/ui/frames/minimal/ui_frame_minimal_modal.png` | `986x900` | `[51,70,51,63]` | `[74,94,838,720]` | Main menu window, settings/codex/pause/result modal shell |
| `ui_frame_minimal_panel` | `assets/sprites/ui/frames/minimal/ui_frame_minimal_panel.png` | `782x716` | `[41,56,41,50]` | `[59,75,664,573]` | Generic large content panel / section |
| `ui_frame_minimal_card` | `assets/sprites/ui/frames/minimal/ui_frame_minimal_card.png` | `426x486` | `[34,45,34,44]` | `[45,58,336,372]` | Reward/event/upgrade/weapon/hero cards |
| `ui_frame_minimal_tooltip` | `assets/sprites/ui/frames/minimal/ui_frame_minimal_tooltip.png` | `760x242` | `[49,31,49,29]` | `[68,46,624,155]` | Tooltips and small dialogs |
| `ui_frame_minimal_hud_strip` | `assets/sprites/ui/frames/minimal/ui_frame_minimal_hud_strip.png` | `1122x288` | `[81,46,81,42]` | `[107,65,908,164]` | Combat HUD resource strips / long status panels |
| `ui_frame_minimal_field` | `assets/sprites/ui/frames/minimal/ui_frame_minimal_field.png` | `616x286` | `[44,39,44,37]` | `[59,53,498,183]` | Inputs, compact fields, tab switchers, short section frames |

Use `StyleBoxTexture` / `NinePatchRect` with tiled center stretch for generic
panels whose runtime aspect may change. Use whole-image proportional scaling only
for screen-authored layouts with explicit source coordinates.

## Screen Mapping

| Screen / Surface | Minimal frame family | Notes |
| --- | --- | --- |
| Main menu | `modal` + `panel` | Keep current main-menu background and SCRUM-273 red buttons. Remove ornate side frames/extra decoration. |
| Settings | `modal`, `field`, `panel` | Preserve three tabs (`Экран`, `Звук`, `Управление`), toggles, sliders, dropdowns, rebind rows, reset/apply/back semantics. |
| Hero Select | Keep SCRUM-447 layout zones, restyle non-button frames with `panel`/`card`/`field` where Back-end can preserve source rects. Do not regress radar square/content containment. |
| Codex | `modal` + `panel` + `card` + `tooltip` | Preserve lazy section building, glossary tooltips, character portrait routing and compact back button. |
| Shop / Attribute Shop / Rest / Events / Upgrade | `panel`, `card`, `tooltip`, optional `field` for wide choice rows | Long option text goes inside card content rect; price badges/choice buttons stay off border. |
| Level-up / Battle Reward / Elite Reward | `modal`/`panel` + `card` | Three options remain readable; click/focus areas stay inside card content rect. |
| Pause / Victory / Death dialogs | `modal` + SCRUM-273 pause/back buttons | Reduce result ornament to minimal shell; keep semantics and escape/back flow. |
| Combat HUD | `hud_strip`, compact `field`/`card` chips | HP/XP/money/ULT/timer/artifact rows stay compact and non-overlapping. |
| Tooltips / Glossary / Stat details | `tooltip` | Clamp width before text layout so tooltip stays inside viewport at 1280x720. |

## Responsive Rules

- Base design resolution: `1920x1080`.
- Required checks: `1280x720`, `1920x1080`, `2560x1440`.
- For large windows/modals, compute `ui_scale = min(viewport_width / 1920,
  viewport_height / 1080)` and clamp modal width to:
  - 1280x720: max `1120`, horizontal gutter `>= 32`
  - 1920x1080: max `1500`, horizontal gutter `>= 56`
  - 2560x1440: max `1860`, horizontal gutter `>= 80`
- Scale source content margins proportionally to the drawn frame size:
  `drawn_margin = source_margin * drawn_size / source_size`.
- For card grids, keep a minimum `16px` visual gap at 720p and `24px` at 1080p+.
- For combat HUD, reserve the top row before artifact wrapping; if resource
  strip/timer/artifact row collide, artifact row wraps below the strip.
- Never shrink red buttons below their existing SCRUM-273 authored dimensions.

## Back-End Handoff

Runtime integration belongs to
`docs/tasks/backend_ui_minimalist_restyle_keep_red_buttons_integration_task.md`.
Back-end should replace old non-button ornate/unified/economy/reward/codex/HUD
frame routing with the minimal kit where safe, archive superseded ornamental
assets outside build scope, update no-overlap assertions and capture QA evidence.
