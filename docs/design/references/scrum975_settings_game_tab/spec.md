# SCRUM-975 UI Mockup Spec — Settings / Game sandbox

Status: ready_for_qa
Role owner: Design/Codex (`/root/design_scrum975`)
Jira: SCRUM-975
Dependency: SCRUM-976 (Back-end sandbox data/runtime layer)
Base resolution: 2560x1440
Responsive targets: 1280x720, 1920x1080, 2560x1440
Generated with: PixelLab MCP `create_ui_asset`; provenance is recorded in
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
- PixelLab source and isolated icon must be textless in accepted content.
- Composite fit report must be `ok: true`; every label/value stays inside its
  declared zone.
- 1080p/2K show all controls without scrolling; 720p has a dedicated scroll lane.
- No content touches frame ornament, dragon heads, gems, bevels or separators.
- Runtime implementation/behavior is a separate Back-end Jira issue.
