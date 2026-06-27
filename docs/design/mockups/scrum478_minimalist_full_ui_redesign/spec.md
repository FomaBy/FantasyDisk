# SCRUM-478 Minimalist Full UI Redesign Spec

Status: design_source_ready_for_review
Role owner: Design
Task: `docs/tasks/design_minimalist_full_ui_redesign_exact_size_anchor_task.md`
Jira: SCRUM-478
Target resolutions: `1280x720`, `1600x900`, `1920x1080`

## Source Packages

- Button anchor source:
  `docs/design/references/minimalist_full_ui_redesign/scrum478_bright_minimal_button_anchor_sheet_transparent.png`
- Frame source:
  `docs/design/references/minimalist_full_ui_redesign/scrum478_exact_size_frame_source_sheet_transparent.png`
- Full-screen mockup board:
  `docs/design/references/minimalist_full_ui_redesign/scrum478_full_screen_mockup_board.png`
- Exact-size matrix:
  `docs/design/references/minimalist_full_ui_redesign/scrum478_minimalist_full_ui_metadata.json`
- Self-QA evidence:
  `docs/design/references/minimalist_full_ui_redesign/scrum478_self_qa_evidence.md`

## Visual Direction

The new UI direction is bright minimalist dark fantasy:

- obsidian/charcoal interiors;
- thin silver frame edges;
- cyan primary accent, magenta danger/secondary accent, restrained gold corner
  ticks;
- no parchment, beige, one-note brown/orange, heavy dragon ornament or old
  metal-heavy frame treatment;
- buttons are the visual anchor and should remain the brightest repeated UI
  element.

The generated source keeps empty interiors for runtime labels/icons. Runtime
text is never baked into the PNG.

## Hard Frame Rule

Every runtime surface has two zones:

- Texture zone: the full PNG, including rails, bevels, accent diamonds, corner
  ticks and glow caps.
- Content zone: the exact `content_rect_xywh` in
  `scrum478_minimalist_full_ui_metadata.json`.

Only content zones may contain labels, icons, portraits, stats, meters,
thumbnails, hover/focus rings and click targets. Outer texture zones are
forbidden.

If Back-end must use 9-slice for a surface, `content_margins_ltrb` must be
greater than `texture_margins_ltrb` and only the plain center may stretch. For
screen-specific exact-size frames, prefer whole-image draw at 1:1.

## Screen Coverage

| Screen | Required family set |
| --- | --- |
| Main menu | `shell_full`, `button_primary`, `button_standard`, `dialog`, `tooltip` |
| Hero select | `shell_full`, `side_panel`, `card_large`, `button_primary`, `tooltip` |
| Weapon select | `shell_compact`, `card_medium`, `button_primary`, `tooltip` |
| Combat HUD | `hud_strip`, `hud_chip`, `button_icon`, `tooltip` |
| Level-up | `shell_compact`, `card_large`, `button_primary`, `badge`, `tooltip` |
| Rewards | `shell_compact`, `card_large`, `button_primary`, `badge`, `tooltip` |
| Shop | `shell_full`, `side_panel`, `card_medium`, `field`, `button_standard`, `tooltip` |
| Attribute shop | `shell_compact`, `card_medium`, `field`, `button_standard`, `tooltip` |
| Event | `shell_compact`, `content_panel`, `card_medium`, `button_standard`, `tooltip` |
| Codex | `shell_full`, `side_panel`, `content_panel`, `card_medium`, `field`, `tooltip` |
| Settings | `shell_full`, `side_panel`, `content_panel`, `field`, `button_standard`, `tooltip` |
| What is new / patch notes | `shell_compact`, `content_panel`, `button_standard`, `tooltip` |
| Feedback | `dialog`, `content_panel`, `button_standard`, `tooltip` |
| Pause | `shell_compact`, `content_panel`, `button_standard`, `tooltip` |
| Results / death / victory | `shell_full`, `content_panel`, `card_medium`, `button_primary`, `badge` |
| Global tooltips and badges | `tooltip`, `badge`, `hud_chip` |

## Layout Rules By Resolution

`1280x720`:

- Use one major shell and scroll inner content before shrinking margins.
- Maximum card columns: 3 for choices, 4 for compact inventory cells.
- Main menu buttons use `primary` or `standard`; do not scale below matrix size.
- Combat HUD uses one `hud_strip` plus separate exact `hud_chip` assets.

`1600x900`:

- Base authoring target for dense non-combat screens.
- Use the matrix sizes directly; avoid fractional scaling.
- Settings/Codex can use a left `side_panel` plus one `content_panel`.

`1920x1080`:

- Use `shell_full` for large screens and preserve larger empty gutters.
- Hero select may show four large cards if text remains inside each card
  content rect; otherwise use carousel/scroll within the content zone.
- Results and rewards should use larger cards, not stretched medium cards.

## Back-end Handoff

Runtime integration is out of Design scope for SCRUM-478. Back-end handoff:

`docs/tasks/backend_minimalist_full_ui_redesign_runtime_handoff_task.md`

Back-end must wire the exact-size matrix, create/import final runtime PNG slices
or equivalent source-sheet cuts, and add screenshot/no-overlap/text-overflow
verification. Design does not edit `scripts/ui_screens.gd`, theme paths,
gameplay logic or tests in SCRUM-478.
