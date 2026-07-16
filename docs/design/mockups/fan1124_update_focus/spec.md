# UI Mockup Spec — Updater Neutral Focus

Status: implemented

Role owner: Back-end

Task: Multica `FAN-1124`; geometry regression follow-up `FAN-1131`

Base resolution: 1920x1080

Responsive targets: 1280x720, 1920x1080, 2560x1440

Mockup package: exact accepted focus-state assets plus the geometry tables below

Source capture: `build/qa/FAN-1124/source/update_prompt_1280x720.png` (Multica attachment `019f66b4-2f98-71d9-b23b-47abd77f6cc8`)

Generators: background=existing; non-background UI=existing accepted exact-size text-button assets

Source metadata: `docs/design/references/ui_text_buttons_unique_size_redraw/button_family_metadata.json`

Runtime focused captures:

- `build/qa/FAN-1124/captures/update_prompt_1280x720.png` — SHA-256 `a0f4292ca4ad18be31b355c8a1ca7929370dddaf55e52913effb5c746a86246c`;
- `build/qa/FAN-1124/captures/update_prompt_1920x1080.png` — SHA-256 `461fb10515cdc7cde268ba1d0fe97ac3724112ed284c52497b91303b110ea886`;
- `build/qa/FAN-1124/captures/update_prompt_2560x1440.png` — SHA-256 `1cdaf5dfbb8e4e951e1e843a32e1568a10659898bf1dcc1f56802d7668220d7f`.

Canonical geometry evidence: macOS unsigned-disclosure probe from Multica
`FAN-1130` (`FAN-1130_interaction_geometry_probe.txt`). The values below are
the authored-pixel form of live `get_global_rect()` measurements; the regression
allows at most 1 px for container rounding.

## Source Request

Replace the updater prompt's bright yellow/gold fallback focus border with the
accepted neutral-bright text-action focus treatment. Preserve all copy,
geometry, initial focus, cyclic navigation, activation, close behavior and
Settings escape-action restoration.

This is an existing-asset reuse pass. It creates no background, underlay, frame,
button or icon art, so no generator invocation is required. The accepted
per-size source provenance remains recorded in the shared button metadata.

## Screen Elements

| ID | Type | Runtime content | Rect @ 1920x1080 | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `GameUpdatePanel` | PanelContainer | prompt shell | `400,230,1120,620` | center | `560x500` | 520 | static | viewport |
| `GameUpdateTitle` | Label lane | localized mode title | `434,254,1052,46` | fill width | content-driven | 521 | static | `GameUpdatePanel` |
| `GameUpdateVersions` | Label lane | current/latest versions | `434,316,1052,27` | fill width | content-driven | 521 | visible/hidden | `GameUpdatePanel` |
| `GameUpdateBody` | Label lane | download and trust guidance | `434,359,1052,338` | expand/fill | `0x112` | 521 | wrapped | `GameUpdatePanel` |
| `GameUpdateStatus` | Label lane | result/status copy | `434,713,1052,25` | fill width | content-driven | 521 | visible/hidden | `GameUpdatePanel` |
| `GameUpdateButtons` | HBoxContainer | action row | `434,760,1052,72` | fill width, centered | `0x72` | 521 | static | `GameUpdatePanel` |
| `GameUpdatePrimaryButton` | Button | `Скачать и установить` | `621,760,420,72` | centered row | `420x72` | 522 | normal/hover/pressed/focus/disabled | primary button content rect |
| `GameUpdateCloseButton` | Button | `Позже` | `1059,760,240,72` | centered row | `240x72` | 522 | normal/hover/pressed/focus/disabled | close button content rect |

The unaffected label lanes are enclosing layout lanes from the existing VBox
contract. The implementation must not change them; this task changes only the
two resolved button families.

## Frames And Safe Zones

| Frame ID | Asset path | Asset size | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- | --- | --- |
| primary text action | `assets/sprites/ui/frames/text_buttons_unique/ui_btn_text_unique_continue_run_long_420x72_<state>.png` | 420x72 | L/R 37, T/B 14 | L/R 54, T/B 14 | fixed ornate end caps and top/bottom rails | yes; center rail only |
| close text action | `assets/sprites/ui/frames/text_buttons_unique/ui_btn_text_unique_continue_240x72_<state>.png` | 240x72 | L/R 37, T/B 14 | L/R 47, T/B 14 | fixed ornate end caps and top/bottom rails | yes; center rail only |

Runtime labels remain inside source content rectangles `54,14,312,44` and
`47,14,146,44`. Focus must not resize either control or move either label.

## Accepted Focus Preview Assets

| Control | Family | Focus preview | Rejected fallback |
| --- | --- | --- | --- |
| primary | `text/continue_run_long_420x72` | `assets/sprites/ui/frames/text_buttons_unique/ui_btn_text_unique_continue_run_long_420x72_focus.png` | `minimal/standard` / `ui_btn_minimal_metal_standard_focus.png` |
| close | `text/continue_240x72` | `assets/sprites/ui/frames/text_buttons_unique/ui_btn_text_unique_continue_240x72_focus.png` | any `minimal/*` fallback |

## Responsive Rules

- macOS unsigned-disclosure case (canonical `get_global_rect()` source):
  - 1280x720: panel `80,50,1120,620`; primary `301,580,420,72`; close `739,580,240,72`.
  - 1920x1080: panel `400,230,1120,620`; primary `621,760,420,72`; close `1059,760,240,72`.
  - 2560x1440: panel `720,410,1120,620`; primary `941,934,420,72`; close `1379,934,240,72`.
- The macOS disclosure adds wrapped trust guidance, so the action row is 6 px
  lower at 1280x720 and 1920x1080. The non-macOS dialog does not render that
  notice and is intentionally not the exact-rect source for this specification.
- The regression checks live panel and button rects in the macOS
  unsigned-disclosure case with a per-edge tolerance of at most 1 px.
- Exact action-row rects apply to a dialog freshly opened at each target. During
  a live resize, the panel must resolve to its target rect while the existing
  action row remains contained, non-overlapping and keeps its 18 px gap; its
  wrapped-text vertical reflow is not an authored-coordinate source.
- The panel remains at its current maximum size for all three targets. The
  centered action row keeps an 18px gap and exact button geometry.

## Interaction States

- Initial focus: primary when enabled; close when the primary is disabled.
- Navigation: left/right/up/down are cyclic between the two actions.
- Activation: A/Enter presses the focused action.
- Close: B/Escape and the close action dismiss the dialog and restore the prior
  Settings escape action.
- Focus: use the dedicated neutral-bright text-button focus PNG. Yellow/gold
  fallback focus paths are forbidden.

## Implementation Notes

- Godot script: `scripts/ui/update_dialog.gd`.
- Shared family resolver/style: `scripts/ui/ui_button_family.gd` via
  `UIScreens._apply_fantasy_button_theme`.
- Tag both updater buttons with explicit text families after their final name
  and size are assigned, preventing a later size-based minimal fallback.
- Regression oracle: `tests/update_settings_ui_test.gd` must assert both family
  IDs and focus descriptor paths in addition to the existing responsive copy and
  lifecycle checks.

## Acceptance Checks

- [x] Existing routed assets are accepted; no generated layer is introduced.
- [x] Every affected visible element and state is listed.
- [x] Texture/content margins and forbidden cap/rail zones are documented.
- [x] Both updater buttons resolve to the specified `text/*` families.
- [x] No updater focus descriptor uses `minimal_metal_buttons`.
- [x] Live panel and button rects match the macOS unsigned-disclosure responsive
  matrix within 1 px per edge.
- [x] Live resize checks the target panel rect plus the 18 px action gap and
  containment without overlap.
- [x] Focus/navigation/activation/close/restoration regressions pass.
- [x] Runtime screenshots confirm the neutral-bright focus treatment.

## Deviations

No runtime-layout change is needed. The initial table documented the action row
6 px too high at 1280x720 and 1920x1080 because it omitted the wrapped macOS
unsigned-disclosure case; the canonical live geometry above corrects that
documentation and its regression oracle. Copy, controls, panel geometry and
content zones remain unchanged.
