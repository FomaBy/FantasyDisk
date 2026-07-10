# SCRUM-975 UI Mockup Spec — Settings / Game sandbox

Status: ready_for_reqa after SCRUM-1030 correction
Role owner: Design/Codex (`/root/scrum1030_design` for the correction)
Jira: SCRUM-975; QA-found Design correction: SCRUM-1030
Dependency: SCRUM-976 (Back-end sandbox data/runtime layer)
Base resolution: 2560x1440
Responsive targets: 1280x720, 1920x1080, 2560x1440
Generated with: PixelLab MCP `create_ui_asset`; original and SCRUM-1030
bottom-scroll provenance are recorded in
`manifest.json` after export.

## Source request

Extend the live three-tab Settings v6 screen with a clean fourth tab, `Игра`,
without stretching the obsolete three-slot switcher. The new page presents the
five SCRUM-976 sandbox multipliers and reset-to-neutral behavior while retaining
the current D&D / dark-fantasy dragon visual family.

## Screen elements @ 2560x1440

| ID | Type | Runtime content | Rect | Anchors / state | Safe-zone parent |
| --- | --- | --- | --- | --- | --- |
| `SettingsTitleChip` | header chip | `Настройки` | `224,124,620,88` | top-left | fullscreen safe area |
| `SettingsBackButton` | action button | `Назад` | `2076,124,260,104` | top-right | own plate interior |
| `SettingsTabButton_0` | tab plate | `Экран` | `724,250,260,104` | centered row, inactive | own plate interior |
| `SettingsTabButton_1` | tab plate | `Звук` | `1008,250,260,104` | centered row, inactive | own plate interior |
| `SettingsTabButton_2` | tab plate | `Управление` | `1292,250,260,104` | centered row, inactive | own plate interior |
| `SettingsTabButton_3` | tab plate | `Игра` | `1576,250,260,104` | centered row, active | own plate interior |
| `SettingsContentPanel` | panel | current tab page | `508,382,1544,858` | centered, expand vertically | panel frame |
| `SettingsContentSafe` | safe container | page content | `556,426,1448,770` | all live controls inside | content panel |
| `SettingsGameScroll` | scroll container | sandbox page | `568,438,1424,746` | auto; not needed at 1080p/2K | content safe |
| `SettingsGameStatus` | value/status chip | neutral/custom state | `1532,450,428,60` | green neutral / amber custom | game scroll |
| modifier rows ×5 | slider row | label + slider + value | `584,654..1014,1384,76` | fixed order | game scroll |
| row label field ×5 | label/hit field | localized setting label | `680,664..1024,580,56` | left | modifier row |
| row value field ×5 | value/hit field | `1.0×` / live value | `1320,664..1024,170,56` | after label | modifier row |
| row slider field ×5 | slider/hit field | track + handle | `1520,664..1024,420,56` | right | modifier row |
| `SettingsResetGameButton` | action button | reset all to 1.0× | `1320,1106,640,64` | lower-right | game scroll |

All coordinates and text-fit ranges are also machine-readable in
`ui_plan.json` and `layout.json`.

## Frames and safe zones

| Frame / plate | Visual source | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- |
| Fullscreen shell | existing unified `frame_border` | existing runtime metadata | existing safe area | complete outer gold/dragon border | existing contract |
| Tab plate | existing global `back_260x104` family | existing runtime 9-slice | 48px left/right at 260px width; 16px vertical reserve | dragon heads, corner gems, bevels | yes |
| Game content panel | current Atlas chip / PixelLab mockup reference | 28px reference border | 48px L/R, 44px T/B @2K | border, corner claws, seams | yes for runtime shell |
| Modifier row | current v6 field/slider/value-chip family | preserve existing metadata | labels/sliders/value chips stay within row rect | separators and field ends | yes where already supported |
| Game tab icon | PixelLab source-sheet selection | n/a | 8px transparent reserve on 44×44 | no label in icon bitmap | no; square icon |

The PixelLab full-page output is a proportional mockup/reference layer, not a
runtime texture to stretch. Runtime integration should reuse the established
shell and plates, plus promote only the isolated 44×44 Game icon if accepted.

## Game page data/control contract

| Row | Proposed settings key | Range | Step | Neutral | Display |
| --- | --- | ---: | ---: | ---: | --- |
| monster HP | `sandbox_monster_hp_multiplier` | 0.5–3.0 | 0.1 | 1.0 | `%.1f×` |
| monster damage | `sandbox_monster_damage_multiplier` | 0.5–3.0 | 0.1 | 1.0 | `%.1f×` |
| player damage | `sandbox_player_damage_multiplier` | 0.5–2.0 | 0.1 | 1.0 | `%.1f×` |
| player attack speed | `sandbox_player_attack_speed_multiplier` | 0.5–2.0 | 0.1 | 1.0 | `%.1f×` |
| monster attack speed | `sandbox_monster_attack_speed_multiplier` | 0.5–3.0 | 0.1 | 1.0 | `%.1f×` |

Each row is keyboard/gamepad focusable. Left/right changes by one step; Page
Left/Page Right or shoulder acceleration is optional Back-end polish. Changes
persist immediately but affect only the next run snapshot. All-neutral state
shows `Обычный режим · 1.0×`; any non-neutral value shows
`Песочница активна` and the progression restriction warning. Reset sets all
five values to 1.0× in one atomic save and refreshes the status.

## Responsive rules

- **2560x1440:** one row of four 260×104 tab plates with 24px gaps; all five
  modifier rows and reset visible; no scrollbar thumb required.
- **1920x1080:** one row of four 260×88 tab plates with 24px gaps; all five
  rows and reset visible in `1086×558` safe content; no scrollbar thumb.
- **1280x720:** reflow tabs to a centered 2×2 grid of 260×72 plates with
  24px horizontal / 12px vertical gaps. Never squeeze four labels into 130px
  plates. Content uses `SettingsGameScroll` (`892×306`, `content_h=520`,
  scrollbar 14px) and `follow_focus=true`; header/back/tab grid never scroll.

### SCRUM-1030 compact scroll geometry contract

The compact screen viewport is `Rect2(194,332,892,306)`. The final 14px inside
the viewport is reserved exclusively for the scrollbar lane
`Rect2(1072,332,14,306)`, leaving an `878×520` logical scroll-content canvas.
The logical canvas uses screen-space x coordinates and local y coordinates;
rendered screen y is `332 + logical_y - scroll_y`.

| Logical element | Rect in scroll content | Child fields |
| --- | --- | --- |
| title / status | `208,8,400,34` / `730,8,328,34` | text only |
| description / warning | `208,52,850,30` / `208,92,850,42` | text only |
| monster HP row | `204,142,842,56` | label `220,150,310,40`; slider `546,150,346,40`; value `906,150,126,40` |
| monster damage row | `204,206,842,56` | label `220,214,310,40`; slider `546,214,346,40`; value `906,214,126,40` |
| player damage row | `204,270,842,56` | label `220,278,310,40`; slider `546,278,346,40`; value `906,278,126,40` |
| player attack speed row | `204,334,842,56` | label `220,342,310,40`; slider `546,342,346,40`; value `906,342,126,40` |
| monster attack speed row | `204,398,842,56` | label `220,406,310,40`; slider `546,406,346,40`; value `906,406,126,40` |
| reset action / label | `640,462,392,50` / `664,468,344,38` | last focusable item |

Top evidence uses `scroll_y=0` and proves rows 1–2. Bottom evidence uses the
maximum `scroll_y=214` and proves rows 3–5 plus reset. In both states the title,
Back button and 2×2 tab grid are pixel-identical and outside the scroll viewport.
The focused machine gate is `validate_scrum1030_geometry.py`; it compares the
plan with both compact compositor layouts and the 2K/1080 layouts.

At every target, plate hitboxes equal the declared plate rectangles, while
label/icon content remains inside the inset safe field. Focus/hover/pressed/
disabled art must not resize or move the hitbox.

## Interaction states

- Tabs: inactive graphite/brass; active warm gold/amber; hover is a restrained
  brightness lift; pressed does not move geometry; focus ring stays inside the
  plate interior.
- Sliders: gold track/fill, blue-steel or amber handle, numeric value chip.
- Status: green-gold when neutral; amber when custom.
- Reset: disabled when all five values are neutral; otherwise enabled.
- No loading/error state is needed; invalid persisted values are clamped by
  Back-end before the page is built.

## Acceptance checks

- Planning gates: `ui_plan.report.json` and `ui_plan_1280x720.report.json` must
  both say `ready_for_image`.
- `scrum1030_geometry.report.json` must say `ok: true` and enumerate five
  complete compact rows, their three child hit fields, reset, top/bottom scroll
  transforms, fixed UI and the scrollbar-lane exclusion.
- PixelLab source and isolated icon must be textless in accepted content.
- Composite fit report must be `ok: true`; every label/value stays inside its
  declared zone.
- 1080p/2K show all controls without scrolling; 720p has a dedicated scroll lane.
- Compact top and bottom final/debug previews together show all five controls
  and reset inside the true empty panel interior.
- No content touches frame ornament, dragon heads, gems, bevels or separators.
- Runtime implementation/behavior is a separate Back-end Jira issue.
