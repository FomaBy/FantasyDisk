# SCRUM-1060 UI Mockup Spec — Settings tab font parity

Status: implemented
Role owner: Back-end/Codex (`/root/scrum1060_settings_font`)
Task: `docs/tasks/backend_settings_tab_font_parity_task.md`
Jira: SCRUM-1060
Base resolution: 2560x1440
Responsive targets: 1152x648, 1280x720, 1920x1080, 2560x1440
Mockup PNGs (accepted PixelLab source reuse):
- `docs/design/previews/scrum975_settings_game_tab/settings_game_1280x720.png`
- `docs/design/previews/scrum975_settings_game_tab/settings_game_1920x1080.png`
- `docs/design/previews/scrum975_settings_game_tab/settings_game_2560x1440.png`
Generated with: PixelLab MCP upstream package `SCRUM-975`, UI asset IDs
`4c7ff5a3-1655-456b-ba16-2d724a0e7525` (compact) and
`105dd091-3096-41c5-a1e5-bc3277cfaef0` (wide), reused unchanged.

## Source Request

Raise the effective font of all four Settings tab labels to match
`SettingsBackButton` at every responsive tier. The plate geometry, state family,
active tint, input behavior and accepted Settings shell remain unchanged.

This is a typography/layout correction, not a new-art task. The accepted
PixelLab Settings package and live global `back_260x104` five-state plate are
the visual source. No generic image generation, manual replacement frame or
new production art is permitted. The four tab icons are removed consistently
because `Управление` plus the icon cannot retain the Back font inside the
measured flat field at compact width.

## Screen Elements

Coordinates below are local to `SettingsTabSwitcher`. The switcher remains
centered by its existing `SettingsSwitcherRow`.

| ID | Runtime content | Rect @ 2560x1440 | 1920x1080 | 1280x720 / 1152x648 | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- |
| `SettingsTabButton_0` | `Экран` | `0,0,260,104` | `0,0,260,88` | `0,0,260,72` | normal/hover/pressed/focus/selected | own plate |
| `SettingsTabButton_1` | `Звук` | `284,0,260,104` | `284,0,260,88` | `284,0,260,72` | same | own plate |
| `SettingsTabButton_2` | `Управление` | `568,0,260,104` | `568,0,260,88` | `0,84,260,72` | same | own plate |
| `SettingsTabButton_3` | `Игра` | `852,0,260,104` | `852,0,260,88` | `284,84,260,72` | same | own plate |

## Frames And Safe Zones

| Frame ID | Asset | Texture margins | Content margins | Flat label zone | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- | --- |
| tab plate, all states | global `back_260x104` family, resolved by `UIButtonFamily` | metadata-backed existing family | L/R `48`; vertical centered reserve `>=4` and `<=16` | local `x=48..212`; vertical field is the centered font line inside the 72/88/104 plate | dragon heads, rails, gems, bevels outside the flat field | yes on compact tiers; native at 104 |

The label contract is text-only. Icon width is exactly zero on every tier, so
the longest label receives the full `164 px` flat interior. Runtime text must
remain centered and fully contained in that interior; clip, ellipsis, wrap and
font-fit downscaling are forbidden.

## Responsive Typography Contract

| Viewport | Grid | Plate | Back font | Required tab font | Tolerance |
| --- | --- | --- | ---: | ---: | ---: |
| 1152x648 | centered 2x2, gaps 24x12 | 260x72 | 21 | 21 | <=1 |
| 1280x720 | centered 2x2, gaps 24x12 | 260x72 | 22 | 22 | <=1 |
| 1920x1080 | centered 4x1, gap 24 | 260x88 | 23 | 23 | <=1 |
| 2560x1440 | centered 4x1, gap 24 | 260x104 | 23 | 23 | <=1 |

The font comes from the same `_readable_font_size(16)` contract as Back. The
tab row fit helper may still calculate vertical content margins, but it must
not reduce this fixed font. All five visual styles must preserve identical
content margins, minimum size and text geometry.

## Interaction States

- normal/hover/pressed/focus use the current global Back plate family;
- selected state remains the current warm-gold modulate; inactive remains the
  current cool graphite/brass tint;
- no state changes plate rect, font, label bounds or content margins;
- mouse, keyboard/D-pad focus, LB/RB cycle and wrap remain unchanged.

## Acceptance Checks

- [x] Upstream mockups were generated through PixelLab MCP and are reused
  without editing their art layer.
- [x] Four exact 260 px plates and responsive 2x2/4x1 geometry are specified.
- [x] Flat content field and forbidden ornament zones are explicit.
- [x] New runtime icon art is unnecessary; all four icons are intentionally
  absent to protect font parity.
- [x] Focused runtime oracle verifies effective font parity, complete labels,
  rendered glyph containment, five-state geometry and responsive grid.
- [x] Metal screenshots are inspected at all four target sizes.
- [x] Settings responsive/seamless/no-overlap/gamepad/full runtime gates pass.

## Deviations

No geometry or art deviation from the accepted SCRUM-975/SCRUM-1025 package.
The only intended visual change is removing all four tab icons and promoting
the labels to the existing Back typography tier.

Independent read-only review: PASS. The reviewer inspected all four Metal
captures and reran the focused, Settings, no-overlap, gamepad, UI and full
runtime gates without finding actionable issues.
