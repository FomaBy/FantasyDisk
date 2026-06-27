# SCRUM-542: Hero Select carousel arrows select heroes cyclically

Jira: SCRUM-542
Status: done
Role: backend
Lane: codex
Owner: backend/codex-background-backend-agent
Locked paths: `scripts/ui_screens.gd`, `docs/design/systems/menus_ui.md`, `docs/tasks/SCRUM-542_hero_select_carousel_arrows.md`

## Scope

Runtime-only Hero Select behavior. No art, frame textures, layout redesign, or
safe-zone changes.

## Result

2026-06-27, backend/codex-background-backend-agent:

- Updated live HS4 carousel arrow callbacks in `scripts/ui_screens.gd`.
- `HS4CarouselNextButton` selects the next character in
  `ProgressionData.character_ids()` relative to `game.selected_character_id`.
- `HS4CarouselPrevButton` selects the previous character.
- Navigation wraps cyclically: last -> first and first -> last.
- Arrow selection uses the same `select_hero` refresh path as visible slot
  clicks, preserving portrait, dossier, radar, ascension label, and selected
  carousel highlight refresh.
- The selected hero is kept visible in the carousel slot window after arrow
  navigation. Existing slot click behavior is preserved.

## Validation

- PASS: `/tmp/scrum542_hero_carousel_check.gd`
  - right arrow selects next hero;
  - right arrow wraps last -> first;
  - left arrow wraps first -> last;
  - visible carousel slot click still selects the corresponding hero;
  - portrait, ascension label, and radar nodes are present after selection.
- PASS: `runtime_smoke_ui_test.gd`.

## QA-Вердикт 2026-06-27
Статус: PASSED

Проверено:
- Static code check: `HS4CarouselNextButton` and `HS4CarouselPrevButton` are
  named and call `select_relative_hero(+/-1)`, which indexes
  `ProgressionData.character_ids()` relative to `game.selected_character_id` and
  wraps with `posmod`.
- Arrow navigation and visible carousel slot clicks use the same `select_hero`
  -> `refresh` path. That path updates `selected_character_id`, selected
  ascension level, portrait, name/dossier/stat labels, `AscensionLevelLabel`,
  radar setup, visible carousel slots and selected slot highlight.
- `keep_selected_visible` keeps the arrow-selected hero inside the visible slot
  window.
- PASS: `/tmp/scrum542_hero_carousel_check.gd` verified next, previous, cyclic
  wrap last -> first and first -> last, existing visible slot click, portrait
  refresh, ascension label and radar presence.
- PASS: `tests/runtime_smoke_ui_test.gd`.
- No visual/layout restyle found in the SCRUM-542 diff: carousel geometry, frame
  art, texture/style paths and safe-zone constants were not changed.

Caveat: local worktree contained unrelated dirty WIP during QA, including a
SCRUM-516 ascension-cap label hunk in `scripts/ui_screens.gd` outside the HS4
carousel block and unrelated balance/runtime files. Full runtime smoke was not
rerun as QA evidence because those dirty files would make the signal ambiguous.
