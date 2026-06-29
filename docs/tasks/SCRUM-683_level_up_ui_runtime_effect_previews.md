# SCRUM-683 - Level Up UI Runtime: readable cards with effective change previews

Jira: SCRUM-683
Статус: new
Role: Back-end / UI runtime
Контур: Codex
Owner: unassigned
Thread: n/a
Priority: P1
Labels: backend, codex, fantasydisk, level-up, ui

## Source Request

User feedback on 2026-06-29: the current Level Up window is too compact and the
three choice cards are visually empty. The modal should be a bit larger, the
hero portrait and reward icons should be larger, and every card should clearly
explain what the option changes and why the player might choose it.

Evidence screenshot:
`docs/design/references/level_up_scrum683/current_level_up_empty_cards_user_feedback.png`

Related work:
- SCRUM-682 provides the completed Design handoff for the larger Level Up window.
- SCRUM-525 already added formula-driven attribute influence / delta preview
  helpers; reuse those ideas instead of hardcoding balance text.

## Required Change

Integrate the SCRUM-682 Level Up design package in runtime:

- Use the larger modal, larger hero portrait, larger reward cards, larger reward
  icons, and explicit card content zones from
  `docs/design/mockups/level_up_scrum682/spec.md`.
- Each Level Up option must show, inside the card safe area, a readable title,
  icon, short description, and an effect-preview block below the description.
- The effect-preview block must describe the practical result of the pick:
  - for base stat / attribute changes: show what the attribute affects and the
    concrete delta where available, for example `Урон: 41 -> 44` or
    `Скорость атаки: 1.25 -> 1.32`;
  - for direct modifier changes: show the changed modifier amount and, when
    available, the resulting derived effect;
  - for weapon / special rewards: show the concise gameplay effect rather than
    only an icon or internal id.
- Preview values must come from current progression data, stat formulas,
  `derived_parameters`, and the active hero/weapon state. Do not hardcode
  balance numbers in UI copy.
- Keep full details in tooltip only as overflow/backstop; the card itself must
  be understandable without hover.
- Preserve the existing Level Up behavior: exactly three options, one selection
  per pending level, stable offer after `Позже`, current keyboard/controller/mouse
  navigation, and existing reward application semantics.

## Hard UI Rule

Content may not overlap decorative frame art. Title, icon, description,
effect-preview text, portrait, and `Позже` label must stay inside the safe
rectangles declared by SCRUM-682 at 1280x720, 1920x1080, 2560x1440, and
3840x2160. If the effect text is too long at 1280x720, shorten/truncate inside
the field and expose the longer detail via tooltip.

## Locked Paths / Scope

- `scripts/ui_screens.gd`
- `scripts/ui/ui_theme_paths.gd`
- `tests/ui_no_overlap_matrix_test.gd`
- Level Up focused UI/runtime smoke tests, if present or added
- `assets/sprites/ui/frames/level_up_scrum682/`
- `docs/design/mockups/level_up_scrum682/spec.md`
- `docs/design/references/level_up_scrum683/`
- `docs/design/systems/menus_ui.md`
- `docs/design/systems/progression_balance.md`
- `docs/design/current_game_state.md`

Do not redesign the art source in this task unless SCRUM-682 assets are missing
or fail runtime safe-zone integration. If art is missing, block with an exact
Design handoff request instead of inventing a new visual pass in Back-end.

## Acceptance Criteria

- The runtime Level Up screen uses the SCRUM-682 larger layout and no longer
  presents mostly empty icon-only cards.
- The hero portrait and reward icons are visibly larger than the current
  screenshot baseline while remaining inside frame interiors.
- Every card has readable visible copy: title, short description, and effect
  preview. Tooltip-only explanation is not sufficient.
- Attribute/stat options explain what the attribute affects and show concrete
  before/after deltas for relevant derived values when data is available.
- Direct modifiers and special rewards show concise effective changes or a clear
  fallback if no derived preview can be computed.
- Preview text is localized consistently with the current Russian UI and does
  not expose raw internal ids to the player.
- Choice count, pending-level behavior, `Позже`, input/focus order, and reward
  application remain unchanged.
- UI no-overlap checks cover Level Up at supported responsive resolutions and
  verify panel/card content against frame safe zones.
- Documentation for the Level Up screen and progression preview behavior is
  updated in the same task.
- Final Jira comment includes branch/commit, test commands, screenshot/evidence
  paths, and `Disk cleanup: ...`.

## Suggested Verification

- `python3 tools/build_ui_2k_frame_kit.py --verify`
- `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd`
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd`
