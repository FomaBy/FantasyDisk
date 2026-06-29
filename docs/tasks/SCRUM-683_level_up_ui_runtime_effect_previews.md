# SCRUM-683 - Level Up UI Runtime: readable cards with effective change previews

Jira: SCRUM-683
Статус: done
Role: Back-end / UI runtime
Контур: Codex
Owner: Back-end / UI runtime Codex
Thread: codex-main-scrum-683 + subagents Lorentz/Franklin/Kant
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

## Implementation Notes

- Runtime now uses the SCRUM-682 Level Up frame family from
  `assets/sprites/ui/frames/level_up_scrum682/` for the modal, reward cards,
  portrait frame, effect-preview field, and `Позже` button states.
- `_show_level_up_screen()` lays out the modal in scaled 2K coordinates from the
  SCRUM-682 handoff and keeps hero header, portrait, title, subtitle, cards, and
  the later button inside the panel safe rect. The later button is raised inside
  the runtime safe area because the original handoff placed it too low for the
  declared panel content zone.
- Reward cards remain full-card clickable buttons, but their visible content is
  an explicit safe-zone layout: large icon, one-line title, short description,
  and framed `LevelUpRewardEffectPreview`.
- Effect previews are formula-driven. Base-stat rewards reuse active stat
  snapshots and derived preview helpers; direct modifier rewards compute
  before/after `ProgressionData.derived_parameters()` from active stats,
  active modifiers, active hero, and active weapon. Tooltip/detail behavior stays
  as overflow/backstop.
- `tests/ui_no_overlap_matrix_test.gd` now seeds deterministic Level Up rewards,
  verifies SCRUM-682 texture paths, checks card safe-zone containment, and writes
  `build/qa/scrum683/level_up_no_overlap_matrix.md`.

## Result / QA Evidence

Status 2026-06-29: implemented, pushed, and ready for QA on branch
`codex/scrum-683-level-up-runtime`.

- Commit: recorded in Jira/final report after rebase/amend.
- Evidence: `build/qa/scrum683/level_up_no_overlap_matrix.md` contains Level Up
  sections for 1152x648, 1280x720, 1600x900, 1920x1080, 2560x1440, and
  3840x2160.
- Passed: `git diff --check -- ...`.
- Passed: `python3 tools/build_ui_2k_frame_kit.py --verify`.
- Passed before rebase: `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`.
- Passed before rebase: `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd`.
- After rebase to `origin/dev@afc7d892`, broad UI matrix and UI smoke are blocked
  by upstream SCRUM-684/PixelLab/Codex issues outside SCRUM-683 scope:
  `CodexBackButton`/`CodexMainPanel` assertions and missing
  `assets/sprites/characters/full_frame/berserk_pixellab/*` resource imports.
  The SCRUM-683 Level Up matrix dump is still produced and shows Level Up
  controls contained across all required viewport sizes.
- Full `runtime_smoke_test.gd` before rebase passed SCRUM-683 assertions, then
  stopped on unrelated existing weapon-orbit assertion
  `Expected SCRUM-455 right attack weapon socket...`.
- Disk cleanup: generated `.import` / `.uid` sidecars from this worktree were
  removed/restored; `.godot/` cache is transient and must be removed before
  final handoff/push report.

## QA-Вердикт
Статус: PASSED

Проверено в чистом worktree от origin/dev (commits 6619b579 + aac518b4, оба is-ancestor origin/dev).
Интеграция: 682-ассеты (level_up_scrum682/*) + 525-хелперы (_attribute_influence_text /
_attribute_upgrade_preview_lines / STAT_DERIVED_PREVIEW) + formula-driven effect-preview
(LevelUpRewardEffectPreview, derived_parameters before/after) реализованы, имена узлов сохранены.
Гейты: runtime_smoke_ui_test PASS; ui_no_overlap_matrix_test — 0 level_up-ошибок (12 codex-фейлов
= посторонний SCRUM-684); runtime_smoke_test — level-up ассерты прошли, стоп на чужом codex back-button
(SCRUM-438/684, line 6957), не на 683. Matrix-дамп: level_up contained @1152/1280/1600/1920/2560/3840.
