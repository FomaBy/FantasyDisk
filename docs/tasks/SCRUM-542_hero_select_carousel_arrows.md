# SCRUM-542: Hero Select carousel arrows select heroes cyclically

Jira: SCRUM-542
Status: review
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
